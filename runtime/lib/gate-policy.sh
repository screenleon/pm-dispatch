#!/usr/bin/env bash
# Source-safe Gate policy and assurance resolver.

# Portable policy reader for the gate assurance coordinates.
#
# Repo-layout runs read the canonical TSV files under core/policy/. A copied
# gate may not carry that tree, so it falls back to the bounded generated
# snapshot below. tests/shell/test-pr-gate.sh compares each heredoc byte-for-
# byte with its canonical source so this fallback cannot drift silently.
_gate_assurance_policy_snapshot() {
  case "${1:-}" in
    tiers)
      # BEGIN GENERATED from core/policy/gate-tiers.tsv
      cat <<'GATE_ASSURANCE_TIERS_TSV'
# Gate rigor presets. Defaults do not assert actual coverage or execution topology.
tier	default_reviewers	evidence_floor
express	critic,qa-tester	reviewer-verdicts
standard	critic,qa-tester,architecture-reviewer	reviewer-verdicts
full	critic,qa-tester,architecture-reviewer,security-reviewer,risk-reviewer	reviewer-verdicts
GATE_ASSURANCE_TIERS_TSV
      # END GENERATED from core/policy/gate-tiers.tsv
      ;;
    modes)
      # BEGIN GENERATED from core/policy/gate-modes.tsv
      cat <<'GATE_ASSURANCE_MODES_TSV'
# Gate execution topology. Mode does not imply tier or reviewer coverage.
# Omitted mode is resolved from policy recommendations, not from this table.
mode	topology	synthesis
sequential	combined-session	inline
parallel	per-reviewer-sessions	separate-session
GATE_ASSURANCE_MODES_TSV
      # END GENERATED from core/policy/gate-modes.tsv
      ;;
    pass-kinds)
      # BEGIN GENERATED from core/policy/gate-pass-kinds.tsv
      cat <<'GATE_ASSURANCE_PASS_KINDS_TSV'
# Gate review-pass semantics. Pass kind does not imply tier or execution mode.
pass_kind	scope	requires_initial_result	is_default
initial	comprehensive	false	true
targeted	remediation-delta	true	false
GATE_ASSURANCE_PASS_KINDS_TSV
      # END GENERATED from core/policy/gate-pass-kinds.tsv
      ;;
    consumers)
      # BEGIN GENERATED from core/policy/gate-policy-consumers.tsv
      cat <<'GATE_POLICY_CONSUMERS_TSV'
# Gate policy consumers. Mode is inferred from recommended_mode only when the user does not select one explicitly.
policy_pass	policy	pass_kind	minimum_tier	required_reviewers	recommended_mode
generic:initial	generic	initial	express	critic,qa-tester	sequential
generic:targeted	generic	targeted	express	none	sequential
maintainer:initial	maintainer	initial	express	critic,qa-tester,architecture-reviewer,security-reviewer,risk-reviewer	parallel
maintainer:targeted	maintainer	targeted	express	none	parallel
GATE_POLICY_CONSUMERS_TSV
      # END GENERATED from core/policy/gate-policy-consumers.tsv
      ;;
    signals)
      # BEGIN GENERATED from core/policy/gate-policy-signals.tsv
      cat <<'GATE_POLICY_SIGNALS_TSV'
# Gate policy signals. Reviewer requirements apply whenever the current subject matches; targeted passes narrow remediation coverage but cannot omit a matched risk reviewer without a scope-bound override.
signal	match_source	pattern	minimum_tier	required_reviewers	recommended_mode
docs-only	classification	docs-only	express	none	sequential
bounded-runtime	classification	bounded-runtime	express	none	sequential
medium-change	classification	medium-change	standard	architecture-reviewer	parallel
large-change	classification	large-change	full	critic,qa-tester,architecture-reviewer,security-reviewer,risk-reviewer	parallel
binary-change	classification	binary-change	standard	architecture-reviewer	parallel
renamed-input	classification	renamed	express	none	sequential
untracked-input	classification	untracked	express	none	sequential
generated-input	classification	generated	express	none	sequential
cross-boundary	classification	cross-boundary	standard	architecture-reviewer	parallel
security-sensitive-path	path-regex	(^|[/_.-])(auth|oauth|jwt|sessions?|secrets?|passwords?|tokens?|credentials?|cors|csrf|webhooks?|sudo|ssh|payments?|billing)([/_.-]|$)	express	security-reviewer	parallel
input-execution-path	path-regex	(^|[/_.-])(eval|exec|execute|command|shell|hook|guard|allowlist)([/_.-]|$)|(^|/)(\.github|workflows?|ci)(/|$)	standard	security-reviewer	parallel
risk-sensitive-path	path-regex	(^|[/_.-])(migrations?|migrate|destructive|deletions?|delete|removals?|remove|rollback|concurrency|concurrent|race|locks?|cancel|reconcile)([/_.-]|$)	express	risk-reviewer	parallel
public-contract-path	path-regex	(^|/)(cli|commands|skills|core/schema)(/|$)|(^|[/_.-])(apis?|schemas?|contracts?)([/_.-]|$)	standard	architecture-reviewer	parallel
policy-source-path	path-regex	(^|/)core/policy(/|$)	full	architecture-reviewer,security-reviewer,risk-reviewer	parallel
brief-architecture-minor	brief-value	minor	standard	architecture-reviewer	parallel
brief-architecture-major	brief-value	major	full	critic,qa-tester,architecture-reviewer,security-reviewer,risk-reviewer	parallel
GATE_POLICY_SIGNALS_TSV
      # END GENERATED from core/policy/gate-policy-signals.tsv
      ;;
    *)
      printf 'pr-gate: unknown assurance policy table: %s\n' "${1:-empty}" >&2
      return 2
      ;;
  esac
}

_gate_assurance_policy_filename() {
  case "${1:-}" in
    tiers) printf 'gate-tiers.tsv\n' ;;
    modes) printf 'gate-modes.tsv\n' ;;
    pass-kinds) printf 'gate-pass-kinds.tsv\n' ;;
    consumers) printf 'gate-policy-consumers.tsv\n' ;;
    signals) printf 'gate-policy-signals.tsv\n' ;;
    *) return 2 ;;
  esac
}

_gate_assurance_policy_path() {
  local filename
  filename="$(_gate_assurance_policy_filename "${1:-}")" || return 2
  # Installed copy-mode carries the generated policy snapshot in this script;
  # never treat an unrelated ~/core tree as canonical policy.
  [[ -z "${PR_GATE_INSTALLED_COPY_ROOT:-}" ]] || return 1
  [[ -n "${PR_GATE_POLICY_DIR:-}" \
      && -r "$PR_GATE_POLICY_DIR/$filename" ]] || return 1
  printf '%s/%s\n' "$PR_GATE_POLICY_DIR" "$filename"
}

_gate_assurance_policy_emit() {
  local path
  if path="$(_gate_assurance_policy_path "${1:-}")"; then
    cat "$path"
  else
    _gate_assurance_policy_snapshot "${1:-}"
  fi
}

# _gate_assurance_policy_lookup <table> <key-column> <key> <value-column>
# Requires exactly one matching row and rejects malformed/duplicate tables.
_gate_assurance_policy_lookup() {
  local table="${1:-}" key_column="${2:-}" key="${3:-}" value_column="${4:-}"
  [[ $# -eq 4 ]] || return 2
  _gate_assurance_policy_emit "$table" | awk -F '\t' \
    -v key_name="$key_column" -v wanted="$key" -v value_name="$value_column" '
      /^[[:space:]]*#/ || /^[[:space:]]*$/ { next }
      !header_seen {
        header_seen=1
        header_width=NF
        for (i=1; i<=NF; i++) {
          sub(/\r$/, "", $i)
          if ($i == key_name) key_index=i
          if ($i == value_name) value_index=i
        }
        if (!key_index || !value_index) { malformed=1; exit }
        next
      }
      {
        sub(/\r$/, "", $NF)
        if (NF != header_width) { malformed=1; exit }
        if ($(key_index) == wanted) {
          matches++
          result=$(value_index)
        }
      }
      END {
        if (malformed || !header_seen || matches != 1 || result == "") exit 2
        print result
      }
    '
}

# _gate_assurance_policy_values <table> <key-column>
# Emits a unique, non-empty closed enum in source order.
_gate_assurance_policy_values() {
  local table="${1:-}" key_column="${2:-}"
  [[ $# -eq 2 ]] || return 2
  _gate_assurance_policy_emit "$table" | awk -F '\t' -v key_name="$key_column" '
    /^[[:space:]]*#/ || /^[[:space:]]*$/ { next }
    !header_seen {
      header_seen=1
      header_width=NF
      for (i=1; i<=NF; i++) {
        sub(/\r$/, "", $i)
        if ($i == key_name) key_index=i
      }
      if (!key_index) { malformed=1; exit }
      next
    }
    {
      sub(/\r$/, "", $NF)
      value=$(key_index)
      if (NF != header_width || value == "" || seen[value]++) {
        malformed=1
        exit
      }
      values[++count]=value
    }
    END {
      if (malformed || !header_seen || count == 0) exit 2
      for (i=1; i<=count; i++) print values[i]
    }
  '
}

_gate_policy_tier_rank() {
  case "${1:-}" in
    express) printf '1\n' ;;
    standard) printf '2\n' ;;
    full) printf '3\n' ;;
    *) return 2 ;;
  esac
}

_gate_policy_order_reviewers() {
  local selected="${1:-}" vocabulary="${2:-}" reviewer ordered=""
  for reviewer in $vocabulary; do
    if [[ " $selected " == *" $reviewer "* ]]; then
      ordered="${ordered:+$ordered }$reviewer"
    fi
  done
  printf '%s\n' "$ordered"
}

_gate_policy_add_reviewers() {
  local selected="${1:-}" csv="${2:-}" vocabulary="${3:-}" reviewer
  [[ "$csv" != none ]] || {
    _gate_policy_order_reviewers "$selected" "$vocabulary"
    return
  }
  for reviewer in $(printf '%s' "$csv" | tr ',' ' '); do
    if [[ " $vocabulary " != *" $reviewer "* ]]; then
      printf 'Error: gate policy names unknown reviewer %s (allowed: %s)\n' \
        "$reviewer" "$vocabulary" >&2
      return 2
    fi
    if [[ " $selected " != *" $reviewer "* ]]; then
      selected="${selected:+$selected }$reviewer"
    fi
  done
  _gate_policy_order_reviewers "$selected" "$vocabulary"
}

_gate_policy_words_json() {
  jq -nc --arg words "${1:-}" '$words | split(" ") | map(select(length > 0))'
}

_gate_policy_lines_json() {
  jq -Rsc 'split("\n") | map(select(length > 0))'
}

# Validate the complete policy sources before resolving any one consumer or
# signal. Looking up only the rows that happen to match this invocation can
# leave a dormant typo or duplicate signal undiscovered until final artifact
# verification, after reviewer dispatch has already spent work.
_gate_policy_source_shape_validate() {
  local table="${1:-}" expected_header="${2:-}"
  [[ $# -eq 2 ]] || return 2
  if ! _gate_assurance_policy_emit "$table" | awk -F '\t' \
      -v expected_header="$expected_header" '
        /^[[:space:]]*#/ || /^[[:space:]]*$/ { next }
        !header_seen {
          sub(/\r$/, "")
          if ($0 != expected_header) exit 2
          header_seen=1
          width=NF
          next
        }
        {
          sub(/\r$/, "", $NF)
          if (NF != width) exit 2
          for (i=1; i<=NF; i++) if ($i == "") exit 2
          if (seen[$1]++) exit 2
          rows++
        }
        END {
          if (!header_seen || rows == 0) exit 2
        }
      '; then
    printf 'Error: invalid gate policy %s source (header, row width, non-empty cells, and unique IDs are required)\n' \
      "$table" >&2
    return 2
  fi
}

_gate_policy_normalize_reviewer_list() {
  local raw="${1:-}" vocabulary="${2:-}" source_label="${3:-reviewer list}"
  local normalized="" reviewer
  if [[ -z "${raw//[[:space:]]/}" || "$raw" == ,* || "$raw" == *, || "$raw" == *,,* ]]; then
    printf 'Error: %s requires a non-empty comma-separated reviewer list\n' \
      "$source_label" >&2
    return 2
  fi
  raw="${raw//,/ }"
  for reviewer in $raw; do
    if [[ ! "$reviewer" =~ ^[a-z0-9][a-z0-9-]*$ \
        || " $vocabulary " != *" $reviewer "* ]]; then
      printf 'Error: %s contains unknown reviewer %s (allowed: %s)\n' \
        "$source_label" "$reviewer" "$vocabulary" >&2
      return 2
    fi
    if [[ " $normalized " == *" $reviewer "* ]]; then
      printf 'Error: %s contains duplicate reviewer: %s\n' \
        "$source_label" "$reviewer" >&2
      return 2
    fi
    normalized="${normalized:+$normalized }$reviewer"
  done
  [[ -n "$normalized" ]] || return 2
  printf '%s\n' "$normalized"
}

_gate_policy_validate_reviewer_csv() {
  local csv="${1:-}" vocabulary="${2:-}" source_label="${3:-policy}"
  local reviewer seen=""
  [[ "$csv" != none ]] || return 0
  if [[ -z "$csv" || "$csv" == ,* || "$csv" == *, || "$csv" == *,,* ]]; then
    printf 'Error: gate policy %s has an invalid reviewer list: %s\n' \
      "$source_label" "$csv" >&2
    return 2
  fi
  for reviewer in $(printf '%s' "$csv" | tr ',' ' '); do
    if [[ ! "$reviewer" =~ ^[a-z0-9][a-z0-9-]*$ \
        || " $vocabulary " != *" $reviewer "* ]]; then
      printf 'Error: gate policy %s names unknown reviewer %s (allowed: %s)\n' \
        "$source_label" "$reviewer" "$vocabulary" >&2
      return 2
    fi
    if [[ " $seen " == *" $reviewer "* ]]; then
      printf 'Error: gate policy %s repeats reviewer %s\n' \
        "$source_label" "$reviewer" >&2
      return 2
    fi
    seen="${seen:+$seen }$reviewer"
  done
}

_gate_policy_validate_sources() {
  local vocabulary="${1:-}" policy_pass policy pass_kind minimum_tier
  local required_reviewers recommended_mode consumer_keys=""
  local signal match_source pattern signal_tier signal_reviewers
  local signal_recommended grep_status
  [[ $# -eq 1 && -n "$vocabulary" ]] || return 2

  _gate_policy_source_shape_validate consumers \
    $'policy_pass\tpolicy\tpass_kind\tminimum_tier\trequired_reviewers\trecommended_mode' \
    || return 2
  _gate_policy_source_shape_validate signals \
    $'signal\tmatch_source\tpattern\tminimum_tier\trequired_reviewers\trecommended_mode' \
    || return 2

  while IFS=$'\t' read -r policy_pass policy pass_kind minimum_tier \
      required_reviewers recommended_mode; do
    [[ -n "$policy_pass" && "$policy_pass" != \#* \
        && "$policy_pass" != policy_pass ]] || continue
    case "$policy" in generic|maintainer) ;; *)
      printf 'Error: gate policy consumer %s has invalid policy: %s\n' \
        "$policy_pass" "$policy" >&2
      return 2
      ;;
    esac
    case "$pass_kind" in initial|targeted) ;; *)
      printf 'Error: gate policy consumer %s has invalid pass kind: %s\n' \
        "$policy_pass" "$pass_kind" >&2
      return 2
      ;;
    esac
    if [[ "$policy_pass" != "${policy}:${pass_kind}" ]]; then
      printf 'Error: gate policy consumer key %s does not match %s:%s\n' \
        "$policy_pass" "$policy" "$pass_kind" >&2
      return 2
    fi
    _gate_assurance_policy_lookup tiers tier "$minimum_tier" evidence_floor >/dev/null \
      || {
        printf 'Error: gate policy consumer %s has invalid minimum tier: %s\n' \
          "$policy_pass" "$minimum_tier" >&2
        return 2
      }
    _gate_policy_validate_reviewer_csv "$required_reviewers" "$vocabulary" \
      "consumer $policy_pass" || return 2
    _gate_assurance_policy_lookup modes mode "$recommended_mode" topology >/dev/null \
      || {
        printf 'Error: gate policy consumer %s has invalid recommended mode: %s\n' \
          "$policy_pass" "$recommended_mode" >&2
        return 2
      }
    consumer_keys="${consumer_keys:+$consumer_keys }$policy_pass"
  done < <(_gate_assurance_policy_emit consumers)

  for policy_pass in generic:initial generic:targeted \
      maintainer:initial maintainer:targeted; do
    if [[ " $consumer_keys " != *" $policy_pass "* ]]; then
      printf 'Error: gate policy consumers source is missing %s\n' \
        "$policy_pass" >&2
      return 2
    fi
  done
  if [[ "$(printf '%s\n' "$consumer_keys" | awk '{print NF}')" -ne 4 ]]; then
    printf 'Error: gate policy consumers source contains unsupported rows: %s\n' \
      "$consumer_keys" >&2
    return 2
  fi

  while IFS=$'\t' read -r signal match_source pattern signal_tier \
      signal_reviewers signal_recommended; do
    [[ -n "$signal" && "$signal" != \#* && "$signal" != signal ]] || continue
    if [[ ! "$signal" =~ ^[a-z0-9][a-z0-9-]*$ \
        || "$signal" == consumer-policy ]]; then
      printf 'Error: gate policy signal has invalid or reserved ID: %s\n' \
        "$signal" >&2
      return 2
    fi
    case "$match_source" in
      classification)
        case "$pattern" in
          docs-only|bounded-runtime|medium-change|large-change|binary-change|\
          renamed|untracked|generated|cross-boundary) ;;
          *)
            printf 'Error: gate policy signal %s names unknown classification: %s\n' \
              "$signal" "$pattern" >&2
            return 2
            ;;
        esac
        ;;
      path-regex)
        grep_status=0
        LC_ALL=C grep -E -- "$pattern" </dev/null >/dev/null 2>&1 \
          || grep_status=$?
        if [[ "$grep_status" -gt 1 ]]; then
          printf 'Error: gate policy signal %s has invalid path regex: %s\n' \
            "$signal" "$pattern" >&2
          return 2
        fi
        ;;
      brief-value)
        case "$pattern" in unknown|none|minor|major) ;;
          *)
            printf 'Error: gate policy signal %s has invalid brief value: %s\n' \
              "$signal" "$pattern" >&2
            return 2
            ;;
        esac
        ;;
      *)
        printf 'Error: gate policy signal %s has invalid match source: %s\n' \
          "$signal" "$match_source" >&2
        return 2
        ;;
    esac
    _gate_assurance_policy_lookup tiers tier "$signal_tier" evidence_floor >/dev/null \
      || {
        printf 'Error: gate policy signal %s has invalid minimum tier: %s\n' \
          "$signal" "$signal_tier" >&2
        return 2
      }
    _gate_policy_validate_reviewer_csv "$signal_reviewers" "$vocabulary" \
      "signal $signal" || return 2
    _gate_assurance_policy_lookup modes mode "$signal_recommended" topology >/dev/null \
      || {
        printf 'Error: gate policy signal %s has invalid recommended mode: %s\n' \
          "$signal" "$signal_recommended" >&2
        return 2
      }
  done < <(_gate_assurance_policy_emit signals)
}


# Resolve risk/policy once for every gate consumer. The function owns the
# relationship between change signals and assurance coordinates; caller paths
# consume its JSON result instead of copying path regexes or policy floors.
#
# _gate_policy_resolve <input-json> [structured-policy-override]
_gate_policy_resolve() {
  local input_json="${1:-}" policy_override="${2:-}"
  local policy pass_kind policy_pass scope_fingerprint vocabulary
  local minimum_tier required_reviewers recommended_mode
  local signal match_source pattern signal_tier signal_reviewers
  local normalized_signal_reviewers effective_signal_reviewers
  local signal_recommended matches_json matches_text
  local current_rank candidate_rank signal_json signals_file
  local requested_tier requested_mode requested_reviewers_json
  local resolved_tier resolved_mode mode_selection_source
  local mode_recommendation_overridden=false tier_defaults selected_reviewers
  local missing_reviewers="" reviewer tier_violation=false
  local violations_json downgrade_requested=false downgrade_allowed=false
  local enforcement_status=pass override_status=not_provided
  local override_sha="" override_reason="" override_approver_json=null
  local expected_tier=null missing_json override_json=null
  local reviewer_override_json classification_json policy_source

  [[ $# -ge 1 && $# -le 2 ]] || return 2
  jq -e . >/dev/null 2>&1 <<<"$input_json" || {
    printf 'Error: invalid gate policy resolver input\n' >&2
    return 2
  }

  policy="$(jq -r '.policy' <<<"$input_json")"
  pass_kind="$(jq -r '.requested.pass_kind' <<<"$input_json")"
  policy_pass="${policy}:${pass_kind}"
  scope_fingerprint="$(jq -r '.scope_fingerprint' <<<"$input_json")"
  vocabulary="$(jq -r '.reviewer_vocabulary | join(" ")' <<<"$input_json")"
  requested_tier="$(jq -r '.requested.tier' <<<"$input_json")"
  requested_mode="$(jq -r '.requested.mode' <<<"$input_json")"
  requested_reviewers_json="$(jq -c '.requested.reviewers' <<<"$input_json")"
  reviewer_override_json="$(jq -c '.reviewer_override' <<<"$input_json")"
  classification_json="$(jq -c '.classification' <<<"$input_json")"
  policy_source="$(jq -r '.policy_source' <<<"$input_json")"

  case "$policy" in generic|maintainer) ;; *)
    printf 'Error: --policy must be generic or maintainer (got: %s)\n' "$policy" >&2
    return 2
  esac
  [[ "$scope_fingerprint" =~ ^[a-f0-9]{64}$ ]] || {
    printf 'Error: gate policy scope fingerprint is invalid\n' >&2
    return 2
  }
  [[ -n "$vocabulary" ]] || {
    printf 'Error: gate policy reviewer vocabulary is empty\n' >&2
    return 2
  }

  minimum_tier="$(_gate_assurance_policy_lookup consumers policy_pass "$policy_pass" minimum_tier)" \
    || {
      printf 'Error: gate policy consumer source has no unique row for %s\n' \
        "$policy_pass" >&2
      return 2
    }
  required_reviewers="$(_gate_assurance_policy_lookup consumers policy_pass "$policy_pass" required_reviewers)" \
    || return 2
  recommended_mode="$(_gate_assurance_policy_lookup consumers policy_pass "$policy_pass" recommended_mode)" \
    || return 2
  required_reviewers="$(_gate_policy_add_reviewers "" "$required_reviewers" "$vocabulary")" \
    || return 2

  _gate_assurance_policy_lookup tiers tier "$minimum_tier" evidence_floor >/dev/null \
    || {
      printf 'Error: gate policy consumer has invalid minimum tier: %s\n' \
        "$minimum_tier" >&2
      return 2
    }
  _gate_assurance_policy_lookup modes mode "$recommended_mode" topology >/dev/null \
    || {
      printf 'Error: gate policy consumer has invalid recommended mode: %s\n' \
        "$recommended_mode" >&2
      return 2
    }
  signals_file="$(mktemp "${TMPDIR:-/tmp}/gate-policy-signals.XXXXXX")" || return 2
  signal_json="$(jq -nc \
    --arg id "consumer-policy" --arg source "consumer-policy" \
    --arg match "$policy_pass" --arg minimum_tier "$minimum_tier" \
    --argjson required_reviewers "$(_gate_policy_words_json "$required_reviewers")" \
    --arg recommended_mode "$recommended_mode" '{
      id:$id,source:$source,matches:[$match],minimum_tier:$minimum_tier,
      required_reviewers:$required_reviewers,recommended_mode:$recommended_mode
    }')" || {
      rm -f "$signals_file"
      return 2
    }
  printf '%s\n' "$signal_json" > "$signals_file"

  while IFS=$'\t' read -r signal match_source pattern signal_tier \
      signal_reviewers signal_recommended; do
    [[ -n "$signal" && "$signal" != \#* && "$signal" != signal ]] || continue
    if [[ -z "$match_source" || -z "$pattern" || -z "$signal_tier" \
        || -z "$signal_reviewers" || -z "$signal_recommended" ]]; then
      printf 'Error: malformed gate policy signal row: %s\n' "$signal" >&2
      rm -f "$signals_file"
      return 2
    fi

    matches_json='[]'
    case "$match_source" in
      classification)
        matches_json="$(jq -c --arg pattern "$pattern" \
          '[.classifications[] | select(.id == $pattern) | .matches[]]' \
          <<<"$input_json")" || {
            rm -f "$signals_file"
            return 2
          }
        ;;
      path-regex)
        matches_text="$(jq -r '.changed_paths[]' <<<"$input_json" \
          | { grep -iE -- "$pattern" || true; })"
        matches_json="$(printf '%s\n' "$matches_text" | _gate_policy_lines_json)" \
          || {
            rm -f "$signals_file"
            return 2
          }
        ;;
      brief-value)
        if [[ "$(jq -r '.classification.architecture_impact' <<<"$input_json")" == "$pattern" ]]; then
          matches_json="$(jq -nc --arg value "$pattern" '[$value]')"
        fi
        ;;
      *)
        printf 'Error: unsupported gate policy match source: %s\n' "$match_source" >&2
        rm -f "$signals_file"
        return 2
        ;;
    esac
    [[ "$(jq -r 'length' <<<"$matches_json")" -gt 0 ]] || continue

    current_rank="$(_gate_policy_tier_rank "$minimum_tier")" || {
      rm -f "$signals_file"
      return 2
    }
    candidate_rank="$(_gate_policy_tier_rank "$signal_tier")" || {
      printf 'Error: gate policy signal %s has invalid minimum tier: %s\n' \
        "$signal" "$signal_tier" >&2
      rm -f "$signals_file"
      return 2
    }
    if (( candidate_rank > current_rank )); then
      minimum_tier="$signal_tier"
    fi
    normalized_signal_reviewers="$(_gate_policy_add_reviewers "" \
      "$signal_reviewers" "$vocabulary")" || {
        rm -f "$signals_file"
        return 2
      }
    # A targeted pass narrows remediation coverage, but it does not weaken
    # reviewers required by risks present in this current subject.  The initial
    # artifact supplies context only; current signals remain independently
    # enforceable and may be omitted solely by a scope-bound user override.
    effective_signal_reviewers="$normalized_signal_reviewers"
    required_reviewers="$(_gate_policy_add_reviewers "$required_reviewers" \
      "$(printf '%s' "$effective_signal_reviewers" | tr ' ' ',')" \
      "$vocabulary")" || {
        rm -f "$signals_file"
        return 2
      }
    case "$signal_recommended" in
      parallel) recommended_mode=parallel ;;
      sequential) : ;;
      *)
        printf 'Error: gate policy signal %s has invalid recommended mode: %s\n' \
          "$signal" "$signal_recommended" >&2
        rm -f "$signals_file"
        return 2
        ;;
    esac
    signal_json="$(jq -nc \
      --arg id "$signal" --arg source "$match_source" \
      --argjson matches "$matches_json" --arg minimum_tier "$signal_tier" \
      --argjson required_reviewers \
        "$(_gate_policy_words_json "$effective_signal_reviewers")" \
      --arg recommended_mode "$signal_recommended" '{
        id:$id,source:$source,matches:$matches,minimum_tier:$minimum_tier,
        required_reviewers:$required_reviewers,recommended_mode:$recommended_mode
      }')" || {
        rm -f "$signals_file"
        return 2
      }
    printf '%s\n' "$signal_json" >> "$signals_file"
  done < <(_gate_assurance_policy_emit signals)

  required_reviewers="$(_gate_policy_order_reviewers "$required_reviewers" "$vocabulary")"
  if [[ "$requested_tier" == auto ]]; then
    resolved_tier="$minimum_tier"
  else
    resolved_tier="$requested_tier"
    current_rank="$(_gate_policy_tier_rank "$minimum_tier")" || {
      rm -f "$signals_file"
      return 2
    }
    candidate_rank="$(_gate_policy_tier_rank "$resolved_tier")" || {
      rm -f "$signals_file"
      return 2
    }
    if (( candidate_rank < current_rank )); then
      tier_violation=true
    fi
  fi

  if [[ "$requested_mode" == default ]]; then
    resolved_mode="$recommended_mode"
    mode_selection_source=policy
  else
    resolved_mode="$requested_mode"
    mode_selection_source=user
    [[ "$resolved_mode" == "$recommended_mode" ]] \
      || mode_recommendation_overridden=true
  fi

  if [[ "$requested_reviewers_json" == null ]]; then
    tier_defaults="$(_gate_assurance_policy_lookup tiers tier "$resolved_tier" default_reviewers)" \
      || {
        rm -f "$signals_file"
        return 2
      }
    selected_reviewers="$(_gate_policy_add_reviewers "" "$tier_defaults" "$vocabulary")" \
      || {
        rm -f "$signals_file"
        return 2
      }
    selected_reviewers="$(_gate_policy_add_reviewers "$selected_reviewers" \
      "$(printf '%s' "$required_reviewers" | tr ' ' ',')" "$vocabulary")" || {
        rm -f "$signals_file"
        return 2
      }
  else
    selected_reviewers="$(jq -r 'join(" ")' <<<"$requested_reviewers_json")"
    selected_reviewers="$(_gate_policy_order_reviewers "$selected_reviewers" "$vocabulary")"
  fi

  # Tier defaults never expand an explicit reviewer choice.  Risk-derived
  # required reviewers remain an independent security boundary for every
  # consumer and may only be omitted through a scope-bound policy override.
  for reviewer in $required_reviewers; do
    if [[ " $selected_reviewers " != *" $reviewer "* ]]; then
      missing_reviewers="${missing_reviewers:+$missing_reviewers }$reviewer"
    fi
  done
  missing_json="$(_gate_policy_words_json "$missing_reviewers")"
  violations_json="$(jq -nc \
    --argjson tier_violation "$tier_violation" \
    --arg requested_tier "$requested_tier" --arg minimum_tier "$minimum_tier" \
    --argjson missing_reviewers "$missing_json" '[
      if $tier_violation then {
        coordinate:"tier",requested:$requested_tier,required:$minimum_tier
      } else empty end,
      if ($missing_reviewers | length) > 0 then {
        coordinate:"coverage",requested:"explicit",required:$missing_reviewers
      } else empty end
    ]')"
  if [[ "$(jq -r 'length' <<<"$violations_json")" -gt 0 ]]; then
    downgrade_requested=true
    enforcement_status=fail
  fi

  if [[ -n "$policy_override" ]]; then
    if [[ ! -r "$policy_override" || ! -s "$policy_override" ]]; then
      printf 'Error: --policy-override must name a readable, non-empty JSON file: %s\n' \
        "$policy_override" >&2
      rm -f "$signals_file"
      return 2
    fi
    override_sha="$(gate_digest_file "$policy_override")" || {
      rm -f "$signals_file"
      return 2
    }
    if ! declare -F gate_structural_schema_verify >/dev/null 2>&1; then
      printf 'Error: canonical gate policy override verifier is unavailable: %s\n' \
        "$policy_override" >&2
      rm -f "$signals_file"
      return 2
    fi
    if ! gate_structural_schema_verify \
        gate-policy-override "$policy_override" "gate policy override"; then
      printf 'Error: invalid gate policy override contract: %s\n' "$policy_override" >&2
      rm -f "$signals_file"
      return 2
    fi
    override_reason="$(jq -r '.reason' "$policy_override")"
    override_approver_json="$(jq -c '.approver' "$policy_override")"
    if [[ "$downgrade_requested" == false ]]; then
      override_status=not_needed
    elif [[ "$(jq -r '.scope_fingerprint' "$policy_override")" != "$scope_fingerprint" ]]; then
      override_status=scope_mismatch
    else
      [[ "$tier_violation" == true ]] && expected_tier="$(jq -nc --arg value "$requested_tier" '$value')"
      if jq -e --argjson expected_tier "$expected_tier" \
          --argjson expected_reviewers "$missing_json" '
          .allow.tier == $expected_tier and
          (.allow.omit_reviewers | sort) == ($expected_reviewers | sort)
        ' "$policy_override" >/dev/null; then
        override_status=applied
        downgrade_allowed=true
        enforcement_status=pass
      else
        override_status=allowance_mismatch
      fi
    fi
    override_json="$(jq -nc --arg status "$override_status" \
      --arg source "$policy_override" --arg sha256 "$override_sha" \
      --arg reason "$override_reason" --argjson approver "$override_approver_json" '{
        status:$status,source:$source,sha256:$sha256,reason:$reason,approver:$approver
      }')"
  else
    override_json='{"status":"not_provided","source":null,"sha256":null,"reason":null,"approver":null}'
  fi

  signal_json="$(jq -s '.' "$signals_file")" || {
    rm -f "$signals_file"
    return 2
  }
  rm -f "$signals_file"

  jq -nc \
    --arg policy "$policy" --arg policy_source "$policy_source" \
    --arg scope_fingerprint "$scope_fingerprint" \
    --arg requested_tier "$requested_tier" --arg requested_mode "$requested_mode" \
    --arg pass_kind "$pass_kind" --argjson requested_reviewers "$requested_reviewers_json" \
    --argjson classification "$classification_json" \
    --arg minimum_tier "$minimum_tier" \
    --argjson required_reviewers "$(_gate_policy_words_json "$required_reviewers")" \
    --arg recommended_mode "$recommended_mode" \
    --arg mode_selection_source "$mode_selection_source" \
    --argjson mode_recommendation_overridden "$mode_recommendation_overridden" \
    --argjson downgrade_requested "$downgrade_requested" \
    --argjson downgrade_allowed "$downgrade_allowed" \
    --argjson matched_signals "$signal_json" \
    --arg resolved_tier "$resolved_tier" --arg resolved_mode "$resolved_mode" \
    --argjson selected_reviewers "$(_gate_policy_words_json "$selected_reviewers")" \
    --arg enforcement_status "$enforcement_status" \
    --argjson violations "$violations_json" --argjson override "$override_json" \
    --argjson reviewer_override "$reviewer_override_json" '{
      kind:"gate_policy_resolution_v1",
      schema_version:1,
      consumer_policy:$policy,
      policy_source:$policy_source,
      scope_fingerprint:$scope_fingerprint,
      request:{
        tier:$requested_tier,
        mode:$requested_mode,
        pass_kind:$pass_kind,
        reviewers:$requested_reviewers
      },
      classification:$classification,
      resolution:{
        minimum_tier:$minimum_tier,
        required_reviewers:$required_reviewers,
        recommended_mode:$recommended_mode,
        mode_selection_source:$mode_selection_source,
        mode_recommendation_overridden:$mode_recommendation_overridden,
        downgrade_requested:$downgrade_requested,
        downgrade_allowed:$downgrade_allowed
      },
      matched_signals:$matched_signals,
      resolved:{
        tier:$resolved_tier,
        mode:$resolved_mode,
        reviewers:$selected_reviewers
      },
      enforcement:{status:$enforcement_status,violations:$violations},
      override:$override,
      reviewer_override:$reviewer_override
    }'
}
