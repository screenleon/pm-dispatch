#!/usr/bin/env bash
set -euo pipefail
trap '' PIPE

GATE_CANCELLED=false
GATE_ACTIVE_PREFLIGHT_PID=""
GATE_ACTIVE_PREFLIGHT_PGID=""

gate_stop_active_preflight() {
  local pid="${GATE_ACTIVE_PREFLIGHT_PID:-}" pgid="${GATE_ACTIVE_PREFLIGHT_PGID:-}"
  [[ "$pid" =~ ^[1-9][0-9]*$ && "$pgid" =~ ^[1-9][0-9]*$ ]] || return 0

  # Operation-owned preflight runs in its own session so timeout and its
  # managed command share one killable group during cancellation. Stop and
  # reap that group before pr-gate exits; the parent operation only
  # reaches `cancelled` after this producer process is gone.
  detached_launch_kill_process_group "$pgid" 1 || true
  wait "$pid" 2>/dev/null || true
  GATE_ACTIVE_PREFLIGHT_PID=""
  GATE_ACTIVE_PREFLIGHT_PGID=""
}

gate_cancel_signal() {
  GATE_CANCELLED=true
  gate_stop_active_preflight
  exit 130
}
trap gate_cancel_signal TERM INT

# say -- emit a progress/diagnostic line on stdout that tolerates a closed pipe.
#
# A consumer that reads a prefix of our stdout and closes the pipe early
# (`pmctl gate run | head`, `| grep -q`, ...) makes the next stdout write fail
# with EPIPE. `trap '' PIPE` keeps the SIGPIPE from killing us, but under
# `set -e` the EPIPE write still makes printf return nonzero and aborts the
# script BEFORE dispatch -- leaving a 0-byte result file while the pipeline
# reports the consumer's exit 0 (silent false-success). The `|| true` here
# absorbs that nonzero so the gate always runs to completion and the per-route
# result-integrity checks remain the authority on the exit code. All human
# progress output must go through say(); only the result file and the
# machine-read handover block are gate "data".
# shellcheck disable=SC2059  # printf passthrough wrapper: the caller owns the format string
say() { printf "$@" 2>/dev/null || true; }

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
# Gate policy signals. Reviewer requirements apply to initial discovery; targeted passes retain tier/mode signals but use requested remediation coverage.
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
  local filename candidate
  filename="$(_gate_assurance_policy_filename "${1:-}")" || return 2
  for candidate in \
    "$SCRIPT_DIR/../../core/policy/$filename" \
    "$SCRIPT_DIR/core/policy/$filename"
  do
    if [[ -r "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
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

_gate_sha256_stream() {
  if command -v sha256sum >/dev/null 2>&1 \
      && printf '' | sha256sum >/dev/null 2>&1; then
    sha256sum | awk '{print $1}'
    return
  fi
  if command -v shasum >/dev/null 2>&1 \
      && printf '' | shasum -a 256 >/dev/null 2>&1; then
    shasum -a 256 | awk '{print $1}'
    return
  fi
  printf 'Error: no sha256sum or shasum found -- cannot fingerprint gate inputs.\n' >&2
  return 2
}

# Emit a deterministic, content-addressed representation of the exact diff
# covered by policy resolution. The outer scope fingerprint also binds the
# requested policy/pass/brief coordinates; this digest prevents an approved
# downgrade from being replayed against a shape-identical but content-different
# patch. Working-tree scopes additionally bind every non-ignored untracked
# file's path, kind, executable bit, and content (or symlink target).
_gate_policy_scope_content_digest() {
  local diff_kind="${1:-}" base="${2:-}" head_ref="${3:-HEAD}"
  local include_untracked="${4:-false}" path quoted kind executable digest
  {
    printf 'gate-policy-scope-content-v1\0'
    case "$diff_kind" in
      fixed-head)
        git diff --binary --full-index "$base"..."$head_ref" --
        ;;
      allow-dirty)
        git diff --binary --full-index "$base" --
        ;;
      committed)
        git diff --binary --full-index "$base"...HEAD --
        ;;
      working-tree)
        git diff --binary --full-index HEAD --
        ;;
      *)
        printf 'Error: unknown gate policy diff kind: %s\n' "$diff_kind" >&2
        return 2
        ;;
    esac || return 2

    if [[ "$include_untracked" == true ]]; then
      while IFS= read -r -d '' path; do
        quoted="$(printf '%q' "$path")"
        if [[ -L "$WORK_DIR/$path" ]]; then
          kind=symlink
          executable=false
          digest="$(printf '%s' "$(readlink "$WORK_DIR/$path")" \
            | _gate_sha256_stream)" || return 2
        elif [[ -f "$WORK_DIR/$path" ]]; then
          kind=file
          [[ -x "$WORK_DIR/$path" ]] && executable=true || executable=false
          digest="$(_gate_result_sha256_file "$WORK_DIR/$path")" || return 2
        else
          printf 'Error: unsupported untracked gate policy input: %s\n' \
            "$path" >&2
          return 2
        fi
        printf 'untracked\0path=%s\0kind=%s\0executable=%s\0sha256=%s\0' \
          "$quoted" "$kind" "$executable" "$digest"
      done < <(git ls-files --others --exclude-standard -z)
    fi
  } | _gate_sha256_stream
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
    effective_signal_reviewers="$normalized_signal_reviewers"
    # A targeted pass is an explicit remediation-delta confirmation, not a
    # second comprehensive discovery pass. Preserve every matched risk signal
    # and its tier/mode implications, but let the requested targeted reviewers
    # own coverage. Initial-pass evidence/closure is verified by its consumer.
    if [[ "$pass_kind" == targeted ]]; then
      effective_signal_reviewers=""
    fi
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
    override_sha="$(_gate_result_sha256_file "$policy_override")" || {
      rm -f "$signals_file"
      return 2
    }
    if ! jq -e '
      (keys | sort) ==
        (["allow","approver","kind","reason","schema_version","scope_fingerprint"] | sort) and
      .kind == "gate_policy_override_v1" and .schema_version == 1 and
      (.scope_fingerprint | type == "string" and test("^[a-f0-9]{64}$")) and
      (.allow | type == "object" and
        (keys | sort) == (["omit_reviewers","tier"] | sort)) and
      (.allow.tier == null or (.allow.tier | IN("express","standard","full"))) and
      (.allow.omit_reviewers | type == "array" and
        all(.[]; type == "string" and test("^[a-z0-9][a-z0-9-]*$")) and
        length == (unique | length)) and
      (.reason | type == "string" and length > 0) and
      (.approver | type == "object" and
        (keys | sort) == (["approval_ref","identity","kind"] | sort)) and
      .approver.kind == "user" and
      (.approver.identity | type == "string" and length > 0) and
      (.approver.approval_ref | type == "string" and length > 0)
    ' "$policy_override" >/dev/null 2>&1; then
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

_gate_set_mode_requested() {
  local candidate="$1" spelling="$2"
  if [[ "$MODE_OPTION_SEEN" == false ]]; then
    MODE_REQUESTED="$candidate"
    MODE_OPTION_SEEN=true
    MODE_OPTION_SPELLING="$spelling"
    return 0
  fi
  if [[ "$MODE_REQUESTED" != "$candidate" ]]; then
    printf 'Error: conflicting gate mode options: %s requested %s, but %s requested %s\n' \
      "$MODE_OPTION_SPELLING" "$MODE_REQUESTED" "$spelling" "$candidate" >&2
    return 2
  fi
  return 0
}

# verify_reviewer_artifact_hashes <hash_cmd> <name> <path> <baseline> [...]
# Print every reviewer whose artifact differs from its captured baseline.
verify_reviewer_artifact_hashes() {
  local hash_cmd="$1" name path baseline current
  shift
  while [[ $# -ge 3 ]]; do
    name="$1" path="$2" baseline="$3"; shift 3
    [[ "$baseline" == "none" ]] && continue
    current="$(cat "$path" 2>/dev/null | $hash_cmd || echo 'missing')"
    [[ "$current" != "$baseline" ]] && printf '%s\n' "$name"
  done
}

# _gate_reviewer_verdict_extract <reviewer> <artifact>
#
# Parallel reviewer briefs already require a canonical heading. Base-pinned
# reviewer definitions additionally use a lower-case, narrative `verdict:`
# field, so requiring a second upper-case Verdict line creates two competing
# output contracts. Treat the unique, reviewer-matched heading as authoritative.
# An optional legacy `Verdict:` marker remains accepted only when it is itself
# unique, valid, and agrees with the heading.
_gate_reviewer_verdict_extract() {
  local reviewer="${1:-}" artifact="${2:-}"
  local heading_count valid_heading_count explicit_count valid_explicit_count
  local heading_verdict explicit_verdict
  [[ $# -eq 2 && -n "$reviewer" && -s "$artifact" ]] || return 1

  heading_count="$(grep -cE "^## ${reviewer} -- " "$artifact" || true)"
  valid_heading_count="$(
    grep -cE "^## ${reviewer} -- (approve|advise|block-soft|block)$" \
      "$artifact" || true
  )"
  [[ "$heading_count" -eq 1 && "$valid_heading_count" -eq 1 ]] || return 1
  heading_verdict="$(
    grep -oE "^## ${reviewer} -- (approve|advise|block-soft|block)$" \
      "$artifact" | awk '{print $4}'
  )"

  explicit_count="$(grep -cE '^Verdict:' "$artifact" || true)"
  if [[ "$explicit_count" -gt 0 ]]; then
    valid_explicit_count="$(
      grep -cE '^Verdict: (approve|advise|block-soft|block)([. ]|$)' \
        "$artifact" || true
    )"
    [[ "$explicit_count" -eq 1 && "$valid_explicit_count" -eq 1 ]] || return 1
    explicit_verdict="$(
      grep -oE '^Verdict: (approve|advise|block-soft|block)([. ]|$)' \
        "$artifact" | awk '{print $2}' | tr -d '. '
    )"
    [[ "$explicit_verdict" == "$heading_verdict" ]] || return 1
  fi

  printf '%s\n' "$heading_verdict"
}

# _kill_process_tree <pid> [signal] -- signal a process AND all its descendants.
# A plain `kill <pid>` only reaches the `eval` subshell / dispatch.sh wrapper we
# backgrounded; the grandchild executor (`codex exec`, or a test `sleep` stub)
# lives in the same call chain but survives as an orphan reparented to init. The
# parallel reviewer/synthesis watchdogs must reap the whole tree or a timed-out
# gate leaks live executor processes. Walk children depth-first via `pgrep -P`
# (leaves before parents) so each layer is signaled before its parent disappears.
_kill_process_tree() {
  local _pid="$1" _sig="${2:-TERM}" _child
  for _child in $(pgrep -P "$_pid" 2>/dev/null || true); do
    _kill_process_tree "$_child" "$_sig"
  done
  kill -"$_sig" "$_pid" 2>/dev/null || true
}

# pr-gate-help:start
# pr-gate.sh -- PR-gate review via a dispatched session
#
# SINGLE-SESSION (--mode sequential; --sequential is compatible):
#   All reviewers run in order inside ONE combined dispatch session.
#   Lower token cost. All reviewer findings appear in a single output file.
#   Use this for most routine changes.
#
# MULTI-SESSION (--mode parallel; --parallel is compatible):
#   Each reviewer runs in its own INDEPENDENT dispatch session, followed by a
#   separate PM synthesis session. Reviewers share no context window, which
#   eliminates anchoring bias across reviewers.
#   Higher token cost. Use for auth/payment/migration paths or when reviewer
#   independence is worth the extra cost.
#
# Explicit user mode always wins. When mode is omitted, policy automatically
# selects its recommendation from the consumer and matched risk signals.
#
# Adjacent test files (not in the diff but directly paired to a changed source
# file) are automatically added to every reviewer brief so coverage gaps in
# unchanged test files are visible to the gate.
#
# Usage:
#   pr-gate.sh --cd <dir> [options]
#
# Options:
#   --cd <dir>           working directory (required)
#   --tier <tier>        express|standard|full -- overrides auto-detection
#   --mode <mode>        sequential|parallel; omitted mode follows the policy recommendation
#   --brief <file>       dispatch brief; trusted architecture_impact contributes to policy resolution
#   --policy <name>      generic|maintainer consumer policy (default: generic)
#   --reviewers <list>   comma-separated requested coverage; does not change tier or pass kind
#   --targeted <list>    remediation-delta pass over these reviewers; requires --initial-result
#   --initial-result <f> initial gate result referenced by a --targeted pass; relative to --cd
#   --reviewer-dir <dir> explicit reviewer-definition source; defaults to the repo-owned agents/ directory
#   --scope <text>       context hint passed into the review brief
#   --base <branch>      base branch for diff (default: origin/HEAD → main)
#   --head <ref>         head ref for diff (default: HEAD / working tree); pass a fixed ref
#                        (branch, tag, commit) to review it without a PR or working tree
#                        involved -- e.g. review a branch before opening a PR, or diff one
#                        tag against another (v0.6.0..v0.7.0). Uses the SAME merge-base
#                        (three-dot) semantics as the default HEAD path: reviews what
#                        changed on head since it diverged from base, not a literal
#                        two-dot tree diff. Incompatible with --allow-dirty.
#   --run-dir <abs>      out-of-repo dir for gate artifacts (briefs/results/trace); optional,
#                        defaults to in-repo paths under --cd when absent (backward compat)
#   --output <path>      result file (default: .gate-results/gate-<ts>.md)
#   --executor <mode>    codex|claude|auto (default: auto; auto uses `command -v codex`)
#   --model <id>         dispatch model (default: "default" → adapter's pinned default,
#                        e.g. codex gpt-5.6-terra / claude sonnet; pass a concrete id to override)
#   --effort <level>     low|medium|high (default: omit → adapter resolves medium unless
#                        the model alias carries its own valid value; see
#                        runtime/lib/reasoning-effort.sh). Independent of --model — use
#                        this to dial reasoning depth up/down without switching models.
#   --isolation <level>  isolation level: none|read-only|workspace-write|workspace-network|sandboxed
#   --timeout <secs>     dispatch timeout per session (default: 1200)
#   --parallel           compatibility spelling for --mode parallel
#   --sequential         compatibility spelling for --mode sequential
#   --allow-hooks        execute repo-local .pm-dispatch hook scripts (trusted branches only)
#   --allow-dirty        review the working tree as-is instead of failing on a dirty tree atop committed changes
#   --override-file <f>  inject accepted-risk overrides into every reviewer brief; auto-discovered
#                        from .gate-overrides.md at repo root when this flag is omitted. A relative
#                        <f> is resolved against the working dir (--cd), not the caller's CWD, since
#                        the file is loaded after the gate cd's into the work dir. The loaded source
#                        and content are recorded in the gate result (## Gate Overrides Applied).
#   --policy-override <f> explicit gate_policy_override_v1 JSON for a scope-bound policy
#                        downgrade. It is never auto-discovered and requires recorded user approval.
#   --test-cmd <cmd>     pre-flight test command run in plain bash BEFORE dispatch, independent of
#                        --timeout; pass/fail is recorded mechanically (frontmatter test_suite: field)
#                        and a FAIL forces Final: NO-GO regardless of what any reviewer LLM writes.
#                        Any command works unchanged and receives basic opaque/advisory evidence.
#                        A compatible runner may write structured suite evidence to the result path
#                        exposed in PM_DISPATCH_PREFLIGHT_TEST_RESULT; only current structured PASS
#                        suites receive the no-duplicate reuse policy.
#                        No auto-detection -- pr-gate.sh is copy-mode portable (see header) and must
#                        not assume any repo-specific test command or path convention; the caller
#                        supplies one explicitly (e.g. `bash scripts/test.sh`). Long-running full
#                        suites should run outside the gate lifecycle; --test-cmd is best suited to
#                        a bounded iteration check chosen by the target repo's caller. Omitting
#                        this flag skips the pre-flight check entirely (reviewers judge test status
#                        themselves, as before this feature existed).
#   --test-timeout <s>   timeout for --test-cmd (default: 1800), decoupled from --timeout so a slow
#                        test suite can never cause a reviewer dispatch session to time out.
#   --skip-preflight-tests   force-disable the pre-flight test check even if --test-cmd is passed.
# pr-gate-help:end

WORK_DIR=""
GATE_RUN_DIR_OVERRIDE=""   # out-of-repo artifact root; set via --run-dir from pmctl-gate
TIER_OVERRIDE=""
TIER_REQUESTED="auto"
REVIEWERS_OVERRIDE=""
REVIEWERS_OPTION_SOURCE=""
MODE_REQUESTED="default"
MODE_OPTION_SEEN=false
MODE_OPTION_SPELLING=""
PASS_KIND_REQUESTED="initial"
INITIAL_RESULT_INPUT=""
INITIAL_RESULT_OPTION_SEEN=false
POLICY_CONSUMER="generic"
POLICY_OVERRIDE_FILE=""
REVIEWER_DIR_OVERRIDE=""
SCOPE=""
BASE_OVERRIDE=""
HEAD_OVERRIDE=""
OUTPUT_OVERRIDE=""
TIMEOUT="1200"
EXECUTOR_OPTION="auto"
ALLOW_HOOKS=false   # hooks require explicit --allow-hooks opt-in (security)
ALLOW_DIRTY=false   # gate refuses a dirty tree atop committed changes unless this opt-in
OVERRIDE_FILE=""
# "default" → omit --model → the executor adapter applies its own pinned default
# (for codex, resolved via share/codex-model-aliases.tsv; decoupled from ~/.codex/config.toml).
# The gate is analysis-heavy and must run on a full model, never the spark variant;
# spark is opt-in only.
DISPATCH_MODEL="default"
DISPATCH_SANDBOX="workspace-write"
DISPATCH_ISOLATION=""   # isolation_level; empty = use codex default (workspace-write)
DISPATCH_APPROVAL="never"
# "" → omit --effort → the adapter resolves its own default (medium unless the
# model alias carries its own valid low/medium/high value; see
# runtime/lib/reasoning-effort.sh). Validated inline (not sourced from the lib)
# so copy-mode pr-gate.sh has no extra file dependency for this flag.
DISPATCH_EFFORT=""
INPUT_BRIEF_FILE=""
TEST_CMD_OVERRIDE=""   # --test-cmd: explicit pre-flight test command (see CC-470 Part 3)
TEST_TIMEOUT="1800"    # --test-timeout: independent of --timeout (dispatch budget)
SKIP_PREFLIGHT_TESTS=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cd)
      [[ $# -ge 2 && -n "$2" && "$2" != --* ]] || { printf 'Error: --cd requires a directory\n' >&2; exit 2; }
      WORK_DIR="$2"; shift 2;;
    --run-dir)
      [[ $# -ge 2 && -n "$2" && "$2" != --* ]] || { printf 'Error: --run-dir requires a directory\n' >&2; exit 2; }
      GATE_RUN_DIR_OVERRIDE="$2"; shift 2;;
    --tier)
      [[ $# -ge 2 && -n "$2" && "$2" != --* ]] || { printf 'Error: --tier requires a value\n' >&2; exit 2; }
      TIER_OVERRIDE="$2"; TIER_REQUESTED="$2"; shift 2;;
    --mode)
      [[ $# -ge 2 && -n "$2" && "$2" != --* ]] || { printf 'Error: --mode requires sequential or parallel\n' >&2; exit 2; }
      _gate_set_mode_requested "$2" "--mode" || exit 2
      shift 2;;
    --brief)
      [[ $# -ge 2 && -n "$2" && "$2" != --* ]] || { printf 'Error: --brief requires a file path\n' >&2; exit 2; }
      INPUT_BRIEF_FILE="$2"; shift 2;;
    --policy)
      [[ $# -ge 2 && -n "$2" && "$2" != --* ]] || { printf 'Error: --policy requires generic or maintainer\n' >&2; exit 2; }
      case "$2" in
        generic|maintainer) POLICY_CONSUMER="$2" ;;
        *) printf 'Error: --policy must be generic or maintainer (got: %s)\n' "$2" >&2; exit 2 ;;
      esac
      shift 2;;
    --reviewers)
      [[ $# -ge 2 && -n "$2" && "$2" != --* ]] || { printf 'Error: --reviewers requires a reviewer list\n' >&2; exit 2; }
      [[ -z "$REVIEWERS_OPTION_SOURCE" ]] || {
        printf 'Error: --reviewers and --targeted may not be combined or repeated\n' >&2
        exit 2
      }
      REVIEWERS_OVERRIDE="$2"; REVIEWERS_OPTION_SOURCE="--reviewers"; shift 2;;
    --targeted)
      [[ $# -ge 2 && -n "$2" && "$2" != --* ]] || { printf 'Error: --targeted requires a reviewer list\n' >&2; exit 2; }
      [[ -z "$REVIEWERS_OPTION_SOURCE" ]] || {
        printf 'Error: --reviewers and --targeted may not be combined or repeated\n' >&2
        exit 2
      }
      REVIEWERS_OVERRIDE="$2"; REVIEWERS_OPTION_SOURCE="--targeted"
      PASS_KIND_REQUESTED="targeted"; shift 2;;
    --initial-result)
      [[ $# -ge 2 && -n "$2" && "$2" != --* ]] || { printf 'Error: --initial-result requires a result path\n' >&2; exit 2; }
      [[ "$INITIAL_RESULT_OPTION_SEEN" == false ]] || {
        printf 'Error: --initial-result may only be provided once\n' >&2
        exit 2
      }
      INITIAL_RESULT_INPUT="$2"; INITIAL_RESULT_OPTION_SEEN=true; shift 2;;
    --reviewer-dir)
      [[ $# -ge 2 ]] || { printf 'Error: --reviewer-dir requires a directory\n' >&2; exit 2; }
      REVIEWER_DIR_OVERRIDE="$2"; shift 2;;
    --scope)      SCOPE="$2";              shift 2;;
    --base)       BASE_OVERRIDE="$2";      shift 2;;
    --head)
      # Guard the operand explicitly: under `set -u` a bare `--head` with no
      # following arg would abort with a raw "unbound variable" instead of the
      # script's controlled CLI error style (mirrors --override-file below).
      [[ $# -ge 2 ]] || { printf 'Error: --head requires a ref\n' >&2; exit 2; }
      HEAD_OVERRIDE="$2";      shift 2;;
    --output)     OUTPUT_OVERRIDE="$2";    shift 2;;
    --executor)   EXECUTOR_OPTION="$2";    shift 2;;
    --model)      DISPATCH_MODEL="$2";     shift 2;;
    --effort)
      case "$2" in
        low|medium|high) ;;
        *) printf 'Error: --effort must be one of: low medium high (got: %s)\n' "$2" >&2; exit 2;;
      esac
      DISPATCH_EFFORT="$2"; shift 2;;
    --isolation)  DISPATCH_ISOLATION="$2"; shift 2;;
    --timeout)    TIMEOUT="$2";            shift 2;;
    --parallel)
      _gate_set_mode_requested "parallel" "--parallel" || exit 2
      shift;;
    --sequential)
      _gate_set_mode_requested "sequential" "--sequential" || exit 2
      shift;;
    --allow-hooks) ALLOW_HOOKS=true;       shift;;
    --allow-dirty) ALLOW_DIRTY=true;       shift;;
    --override-file)
      # Guard the operand explicitly: under `set -u` a bare `--override-file` with
      # no following arg would abort with a raw "unbound variable" instead of the
      # script's controlled CLI error style.
      [[ $# -ge 2 ]] || { printf 'Error: --override-file requires a file path\n' >&2; exit 2; }
      OVERRIDE_FILE="$2";  shift 2;;
    --policy-override)
      [[ $# -ge 2 && -n "$2" && "$2" != --* ]] || { printf 'Error: --policy-override requires a JSON file path\n' >&2; exit 2; }
      POLICY_OVERRIDE_FILE="$2"; shift 2;;
    --test-cmd)
      [[ $# -ge 2 ]] || { printf 'Error: --test-cmd requires a shell command\n' >&2; exit 2; }
      TEST_CMD_OVERRIDE="$2"; shift 2;;
    --test-timeout)
      [[ $# -ge 2 ]] || { printf 'Error: --test-timeout requires a number of seconds\n' >&2; exit 2; }
      TEST_TIMEOUT="$2";   shift 2;;
    --skip-preflight-tests) SKIP_PREFLIGHT_TESTS=true; shift;;
    -h|--help)
      awk '
        /^# pr-gate-help:start$/ { help=1; next }
        /^# pr-gate-help:end$/ { exit }
        help {
          line=$0
          sub(/^# ?/, "", line)
          print line
        }
      ' "$0"
      exit 0;;
    *)
      printf 'Unknown arg: %s\n' "$1" >&2
      printf 'Accepted: --cd --run-dir --tier --mode --brief --policy --reviewers --targeted --initial-result --reviewer-dir --scope --base --head --output --executor --model --effort --isolation --timeout --parallel --sequential --allow-hooks --allow-dirty --override-file --policy-override --test-cmd --test-timeout --skip-preflight-tests (-h for help)\n' >&2
      exit 2;;
  esac
done

if [[ -z "$WORK_DIR" ]]; then
  printf 'Error: --cd <dir> is required\n' >&2; exit 2
fi
if [[ ! -d "$WORK_DIR" ]]; then
  printf 'Error: working dir not found: %s\n' "$WORK_DIR" >&2; exit 2
fi
# Trust-boundary comparisons and every derived artifact path must use the same
# physical workspace identity. A raw relative or symlink-bearing --cd value can
# otherwise make an in-workspace reviewer directory look external and trusted.
WORK_DIR="$(cd "$WORK_DIR" && pwd -P)"
if [[ -n "$GATE_RUN_DIR_OVERRIDE" && "$GATE_RUN_DIR_OVERRIDE" != /* ]]; then
  printf 'Error: --run-dir must be an absolute path: %s\n' "$GATE_RUN_DIR_OVERRIDE" >&2; exit 2
fi

_self="$0"
while [[ -L "$_self" ]]; do
  _self_dir="$(cd "$(dirname "$_self")" && pwd)"
  _self="$(readlink "$_self")"
  [[ "$_self" == /* ]] || _self="$_self_dir/$_self"
done
SCRIPT_DIR="$(cd "$(dirname "$_self")" && pwd)"
GATE_RESULT_VERIFY_PATH="$SCRIPT_DIR/../lib/gate-result-verify.sh"
if [[ -r "$GATE_RESULT_VERIFY_PATH" ]]; then
  # shellcheck source=runtime/lib/gate-result-verify.sh
  . "$GATE_RESULT_VERIFY_PATH"
else
  # Inline fallback for copy-mode (pr-gate.sh run standalone without runtime/lib/).
  # Generated from runtime/lib/gate-result-verify.sh by
  # scripts/sync-gate-result-verifier-fallback.sh. Do not edit this block by hand.
  # gate-result-verifier-fallback:start
  gate_result_verdict_verify() {
    local result_file=${1-} expected_final=${2-} route_label=${3-gate}
    local final_count frontmatter_final body_final

    [[ $# -ge 1 && $# -le 3 ]] || {
      printf 'gate-result-verify: gate_result_verdict_verify expects <result_file> [expected_final] [route_label]\n' >&2
      return 2
    }
    if [[ ! -s "$result_file" ]]; then
      printf 'Error: %s did not produce the result file: %s\n' "$route_label" "$result_file" >&2
      printf 'Gate aborted -- the executor session may have exited 0 without writing a verdict.\n' >&2
      return 1
    fi
    final_count=$(grep -cE '^Final: (GO|NO-GO)$' "$result_file" || true)
    if [[ "$final_count" -ne 1 ]]; then
      printf 'Error: gate result file must contain exactly one Final: GO/NO-GO line (found %d): %s\n' \
        "$final_count" "$result_file" >&2
      return 1
    fi
    frontmatter_final=$(awk 'BEGIN{s=0} /^---$/ { if (s == 0) { s=1; next } else if (s == 1) { exit } } s && $1 == "final:" { print $2; exit }' "$result_file")
    if [[ -z "$frontmatter_final" ]]; then
      printf 'Error: gate result YAML frontmatter missing required field: final: (%s)\n' "$result_file" >&2
      return 1
    fi
    body_final=$(grep -E '^Final: (GO|NO-GO)$' "$result_file" | awk '{print $2}')
    if [[ "$frontmatter_final" != "$body_final" ]]; then
      printf 'Error: frontmatter final: (%s) does not match body Final: (%s) in gate result: %s\n' \
        "$frontmatter_final" "$body_final" "$result_file" >&2
      return 1
    fi
    if [[ -n "$expected_final" && "$body_final" != "$expected_final" ]]; then
      printf 'Error: %s verdict (%s) contradicts shell-computed verdict (%s) -- gate result may have been manipulated: %s\n' \
        "$route_label" "$body_final" "$expected_final" "$result_file" >&2
      return 1
    fi
  }

  _gate_result_frontmatter_value() {
    local result_file="$1" key="$2"
    awk -v wanted="$key" '
      BEGIN{s=0}
      /^---$/ { if (s == 0) { s=1; next } else if (s == 1) { exit } }
      s && $1 == wanted ":" { print $2; exit }
    ' "$result_file"
  }

  _gate_result_sha256_file() {
    local file="$1" digest=""
    if command -v sha256sum >/dev/null 2>&1 \
        && digest="$(sha256sum -- "$file" 2>/dev/null | awk '{print $1}')" \
        && [[ -n "$digest" ]]; then
      printf '%s\n' "$digest"
      return 0
    fi
    if command -v shasum >/dev/null 2>&1 \
        && digest="$(shasum -a 256 -- "$file" 2>/dev/null | awk '{print $1}')" \
        && [[ -n "$digest" ]]; then
      printf '%s\n' "$digest"
      return 0
    fi
    printf 'Error: no sha256sum or shasum found -- cannot verify gate assurance binding\n' >&2
    return 2
  }

  gate_assurance_verify() {
    local result_file="$1" assurance_file="$2" body_final="$3"
    local markdown_tier markdown_mode result_sha assurance_kind
    command -v jq >/dev/null 2>&1 || {
      printf 'Error: gate assurance verification requires jq\n' >&2
      return 2
    }
    if [[ ! -s "$assurance_file" ]]; then
      printf 'Error: gate assurance sidecar missing or empty: %s\n' "$assurance_file" >&2
      return 1
    fi
    markdown_tier="$(_gate_result_frontmatter_value "$result_file" tier)"
    markdown_mode="$(_gate_result_frontmatter_value "$result_file" mode)"
    assurance_kind="$(jq -r '.kind // empty' "$assurance_file" 2>/dev/null)"
    if [[ "$assurance_kind" == gate_assurance_v1 ]]; then
      jq -e --arg final "$body_final" --arg markdown_tier "$markdown_tier" \
        --arg markdown_mode "$markdown_mode" '
          .kind == "gate_assurance_v1" and .schema_version == 1 and
          .result.final == $final and
          .coordinates.tier.resolved == $markdown_tier and
          .coordinates.mode.resolved == $markdown_mode
        ' "$assurance_file" >/dev/null || {
        printf 'Error: legacy gate assurance sidecar failed claim verification: %s\n' \
          "$assurance_file" >&2
        return 1
      }
      GATE_ASSURANCE_BOUND=false
      export GATE_ASSURANCE_BOUND
      return 0
    fi
    result_sha="$(_gate_result_sha256_file "$result_file")" || return $?
    jq -e --arg final "$body_final" --arg result_sha "$result_sha" \
      --arg markdown_tier "$markdown_tier" \
      --arg markdown_mode "$markdown_mode" '
      def only_keys($allowed):
        type == "object" and ((keys_unsorted - $allowed) | length) == 0;
      def strings_unique:
        type == "array" and all(.[]; type == "string" and length > 0) and
        (length == (unique | length));
      def same_set($a; $b): ($a | sort) == ($b | sort);
      only_keys(["kind","schema_version","result","bindings","coordinates",
        "policy","dispatch","provenance"]) and
      (.result | only_keys(["final"])) and
      (.bindings | only_keys(["result_sha256","repo_root","repo_identity",
        "base_commit","head_commit","subject_fingerprint"])) and
      (.coordinates | only_keys(["tier","mode","pass","coverage","independence"])) and
      (.coordinates.tier | only_keys(["requested","resolved","evidence_floor"])) and
      (.coordinates.mode | only_keys(["requested","resolved","topology","synthesis"])) and
      (.coordinates.pass | only_keys(["requested","resolved","scope","initial_result"])) and
      (.coordinates.coverage |
        only_keys(["requested","selected","skipped","vocabulary"])) and
      (.coordinates.independence |
        only_keys(["implementation_context_isolated","reviewer_topology",
          "per_reviewer_independent","evidence_status"])) and
      (if has("policy") then
        (.policy |
          only_keys(["kind","schema_version","consumer_policy","policy_source",
            "scope_fingerprint","request","classification","resolution",
            "matched_signals","resolved","enforcement","override",
            "reviewer_override"])) and
        (.policy.request |
          only_keys(["tier","mode","pass_kind","reviewers"])) and
        (.policy.classification |
          only_keys(["architecture_impact","line_changes",
            "binary_or_unknown_count","layer_roots"])) and
        (.policy.resolution |
          only_keys(["minimum_tier","required_reviewers","recommended_mode",
            "mode_selection_source","mode_recommendation_overridden",
            "downgrade_requested","downgrade_allowed"])) and
        (.policy.resolved | only_keys(["tier","mode","reviewers"])) and
        (.policy.enforcement | only_keys(["status","violations"])) and
        (.policy.override |
          only_keys(["status","source","sha256","reason","approver"])) and
        (.policy.reviewer_override |
          only_keys(["status","source","sha256"])) and
        .policy.kind == "gate_policy_resolution_v1" and
        .policy.schema_version == 1 and
        (.policy.consumer_policy | IN("generic","maintainer")) and
        .policy.policy_source == .provenance.policy_source and
        (.policy.scope_fingerprint | test("^[a-f0-9]{64}$")) and
        .policy.request.tier == .coordinates.tier.requested and
        .policy.request.mode == .coordinates.mode.requested and
        .policy.request.pass_kind == .coordinates.pass.resolved and
        ((.policy.request.reviewers == null and
          .coordinates.coverage.requested == null) or
         (same_set(.policy.request.reviewers;
           .coordinates.coverage.requested))) and
        (.policy.classification.architecture_impact |
          IN("unknown","none","minor","major")) and
        (.policy.classification.line_changes |
          type == "number" and . >= 0 and floor == .) and
        (.policy.classification.binary_or_unknown_count |
          type == "number" and . >= 0 and floor == .) and
        (.policy.classification.layer_roots | strings_unique) and
        (.policy.resolution.minimum_tier |
          IN("express","standard","full")) and
        (.policy.resolution.required_reviewers | strings_unique) and
        (.policy as $policy |
          all($policy.resolution.required_reviewers[];
            . as $reviewer |
            ($policy.resolved.reviewers | index($reviewer)) != null or
            $policy.resolution.downgrade_allowed)) and
        (.policy.resolution.recommended_mode |
          IN("sequential","parallel")) and
        (.policy.resolution.mode_selection_source | IN("user","policy")) and
        (.policy.resolution.mode_recommendation_overridden | type == "boolean") and
        (if .policy.request.mode == "default"
         then
           .policy.resolution.mode_selection_source == "policy" and
           .policy.resolved.mode == .policy.resolution.recommended_mode and
           .policy.resolution.mode_recommendation_overridden == false
         else
           .policy.resolution.mode_selection_source == "user" and
           .policy.resolved.mode == .policy.request.mode and
           .policy.resolution.mode_recommendation_overridden ==
             (.policy.request.mode != .policy.resolution.recommended_mode)
         end) and
        (.policy.resolution.downgrade_requested | type == "boolean") and
        (.policy.resolution.downgrade_allowed | type == "boolean") and
        (.policy.matched_signals | type == "array" and length > 0) and
        ([.policy.matched_signals[].id] | strings_unique) and
        (all(.policy.matched_signals[];
          only_keys(["id","source","matches","minimum_tier",
            "required_reviewers","recommended_mode"]) and
          (.id | type == "string" and length > 0) and
          (.source |
            IN("consumer-policy","classification","path-regex","brief-value")) and
          (.matches | strings_unique and length > 0) and
          (.minimum_tier | IN("express","standard","full")) and
          (.required_reviewers | strings_unique) and
          (.recommended_mode | IN("sequential","parallel")))) and
        .policy.resolved.tier == .coordinates.tier.resolved and
        .policy.resolved.mode == .coordinates.mode.resolved and
        same_set(.policy.resolved.reviewers;
          .coordinates.coverage.selected) and
        .policy.enforcement.status == "pass" and
        (.policy.enforcement.violations | type == "array") and
        (all(.policy.enforcement.violations[];
          only_keys(["coordinate","requested","required"]) and
          (.coordinate | IN("tier","coverage")))) and
        (.policy.override.status |
          IN("not_provided","not_needed","applied","scope_mismatch",
            "allowance_mismatch")) and
        (if .policy.resolution.downgrade_requested
         then
           .policy.resolution.downgrade_allowed == true and
           .policy.override.status == "applied" and
           (.policy.override.source |
             type == "string" and startswith("/")) and
           (.policy.override.sha256 | test("^[a-f0-9]{64}$")) and
           (.policy.override.reason | type == "string" and length > 0) and
           (.policy.override.approver |
             only_keys(["kind","identity","approval_ref"])) and
           .policy.override.approver.kind == "user" and
           (.policy.override.approver.identity |
             type == "string" and length > 0) and
           (.policy.override.approver.approval_ref |
             type == "string" and length > 0)
         else
           .policy.resolution.downgrade_allowed == false and
           (.policy.override.status |
             IN("not_provided","not_needed"))
         end) and
        (.policy.reviewer_override.status |
          IN("not_provided","provided")) and
        (if .policy.reviewer_override.status == "provided"
         then
           (.policy.reviewer_override.source |
             type == "string" and startswith("/")) and
           (.policy.reviewer_override.sha256 | test("^[a-f0-9]{64}$"))
         else
           .policy.reviewer_override.source == null and
           .policy.reviewer_override.sha256 == null
         end)
      else true end) and
      (.dispatch | only_keys(["outcomes"])) and
      (all(.dispatch.outcomes[];
        only_keys(["role","reviewer","status","run_id","evidence_status"]))) and
      (.provenance | only_keys(["producer","policy_source","attestation"])) and
      .kind == "gate_assurance_v2" and .schema_version == 2 and
      .result.final == $final and
      .bindings.result_sha256 == $result_sha and
      (.bindings.repo_root | type == "string" and startswith("/")) and
      (.bindings.repo_identity | test("^[a-f0-9]{64}$")) and
      (.bindings.base_commit | test("^[a-f0-9]{40}$")) and
      (.bindings.head_commit | test("^[a-f0-9]{40}$")) and
      (.bindings.subject_fingerprint | test("^[a-f0-9]{64}$")) and
      .coordinates.tier.resolved == $markdown_tier and
      .coordinates.mode.resolved == $markdown_mode and
      .provenance.producer == "pr-gate.sh" and
      (.provenance.policy_source |
        IN("canonical","generated-snapshot","mixed")) and
      (.coordinates.tier.evidence_floor | type == "string" and length > 0) and
      (.coordinates.tier.requested == "auto" or
        (.coordinates.tier.requested == .coordinates.tier.resolved and
         (.coordinates.tier.requested | IN("express","standard","full")))) and
      (.coordinates.tier.resolved | IN("express","standard","full")) and
      (.coordinates.mode.requested | IN("default","sequential","parallel")) and
      (.coordinates.mode.resolved | IN("sequential","parallel")) and
      (.coordinates.mode.requested == "default" or
        .coordinates.mode.requested == .coordinates.mode.resolved) and
      ((.coordinates.mode.resolved == "sequential" and
         .coordinates.mode.topology == "combined-session" and
         .coordinates.mode.synthesis == "inline") or
       (.coordinates.mode.resolved == "parallel" and
         .coordinates.mode.topology == "per-reviewer-sessions" and
         .coordinates.mode.synthesis == "separate-session")) and
      (.coordinates.pass.requested | IN("initial","targeted")) and
      (.coordinates.pass.resolved | IN("initial","targeted")) and
      .coordinates.pass.requested == .coordinates.pass.resolved and
      ((.coordinates.pass.resolved == "initial" and
         .coordinates.pass.scope == "comprehensive" and
         .coordinates.pass.initial_result == null) or
       (.coordinates.pass.resolved == "targeted" and
         .coordinates.pass.scope == "remediation-delta" and
         (.coordinates.pass.initial_result | type == "string" and length > 0))) and
      (.coordinates.coverage.vocabulary | strings_unique) and
      (.coordinates.coverage.selected | strings_unique) and
      (.coordinates.coverage.skipped | strings_unique) and
      ((.coordinates.coverage.selected + .coordinates.coverage.skipped) | strings_unique) and
      same_set(.coordinates.coverage.selected + .coordinates.coverage.skipped;
        .coordinates.coverage.vocabulary) and
      (.coordinates.coverage.requested == null or
        ((.coordinates.coverage.requested | strings_unique) and
         same_set(.coordinates.coverage.requested;
           .coordinates.coverage.selected))) and
      (.dispatch.outcomes | type == "array") and
      (all(.dispatch.outcomes[];
        (.role | IN("combined","reviewer","synthesis","preflight")) and
        (if .role == "reviewer"
         then (.reviewer | type == "string" and length > 0)
         else .reviewer == null
         end) and
        (.status | IN("passed","failed","skipped")) and
        (.evidence_status | IN("verified","unavailable","unverified")) and
        (.run_id == null or
          (.run_id | type == "string" and test("^run-[A-Za-z0-9]+-[A-Za-z0-9]+$"))))) and
      (if .coordinates.mode.resolved == "parallel" and
          ([.dispatch.outcomes[] | select(.role == "preflight")] | length) == 0
       then
         (.dispatch.outcomes | length) ==
           ((.coordinates.coverage.selected | length) + 1) and
         (all(.dispatch.outcomes[];
           (.role == "reviewer" or .role == "synthesis"))) and
         ([.dispatch.outcomes[] | select(.role == "reviewer") | .reviewer] | sort) ==
           (.coordinates.coverage.selected | sort) and
         ([.dispatch.outcomes[] | select(.role == "synthesis")] | length) == 1
       elif .coordinates.mode.resolved == "sequential" and
            ([.dispatch.outcomes[] | select(.role == "preflight")] | length) == 0
       then
         (.dispatch.outcomes | length) == 1 and
         .dispatch.outcomes[0].role == "combined"
       else
         (.dispatch.outcomes | length) == 1 and
         .dispatch.outcomes[0].role == "preflight" and
         .dispatch.outcomes[0].status == "failed"
       end) and
      (.coordinates.independence.evidence_status |
        IN("verified","unavailable","unverified")) and
      (if .coordinates.independence.evidence_status == "verified"
       then (.provenance.attestation |
         type == "string" and
         test("^gate-assurance-[0-9]{8}-[0-9]{6}\\.attestation\\.json$"))
       else .provenance.attestation == null
       end) and
      .coordinates.independence.reviewer_topology ==
        .coordinates.mode.topology and
      (if .coordinates.independence.evidence_status == "verified"
       then
         .coordinates.independence.implementation_context_isolated == true and
         (all(.dispatch.outcomes[]; .evidence_status == "verified" and .run_id != null)) and
         ([.dispatch.outcomes[].run_id] | length == (unique | length)) and
         (if .coordinates.mode.resolved == "parallel"
          then .coordinates.independence.per_reviewer_independent == true
          else .coordinates.independence.per_reviewer_independent == false
          end)
       else
         .coordinates.independence.implementation_context_isolated != true and
         .coordinates.independence.per_reviewer_independent != true and
         (all(.dispatch.outcomes[]; .evidence_status != "verified"))
       end)
    ' "$assurance_file" >/dev/null || {
      printf 'Error: gate assurance sidecar failed structural/claim verification: %s\n' \
        "$assurance_file" >&2
      return 1
    }
    GATE_ASSURANCE_BOUND=true
    export GATE_ASSURANCE_BOUND
  }

  gate_result_verify() {
    local result_file=${1-} expected_final=${2-} route_label=${3-gate}
    local version pointer result_parent assurance_file body_final
    [[ $# -ge 1 && $# -le 3 ]] || {
      printf 'gate-result-verify: gate_result_verify expects <result_file> [expected_final] [route_label]\n' >&2
      return 2
    }
    gate_result_verdict_verify "$result_file" "$expected_final" "$route_label" || return $?
    version="$(_gate_result_frontmatter_value "$result_file" gate_result_version)"
    case "$version" in
      pr_gate_result_v1)
        GATE_RESULT_ASSURANCE=unavailable
        unset GATE_RESULT_ASSURANCE_FILE
        export GATE_RESULT_ASSURANCE
        return 0
        ;;
      pr_gate_result_v2)
        pointer="$(_gate_result_frontmatter_value "$result_file" gate_assurance)"
        if [[ -z "$pointer" || "$pointer" == */* || "$pointer" == "." || "$pointer" == ".." \
            || ! "$pointer" =~ ^[A-Za-z0-9._-]+\.json$ ]]; then
          printf 'Error: pr_gate_result_v2 requires a bounded sibling gate_assurance pointer: %s\n' \
            "$result_file" >&2
          return 1
        fi
        result_parent="$(cd "$(dirname "$result_file")" && pwd -P)" || return 1
        assurance_file="$result_parent/$pointer"
        body_final=$(grep -E '^Final: (GO|NO-GO)$' "$result_file" | awk '{print $2}')
        gate_assurance_verify "$result_file" "$assurance_file" "$body_final" || return $?
        if [[ "${GATE_ASSURANCE_BOUND:-false}" == true ]]; then
          GATE_RESULT_ASSURANCE=verified
        else
          GATE_RESULT_ASSURANCE=unavailable
        fi
        GATE_RESULT_ASSURANCE_FILE="$assurance_file"
        export GATE_RESULT_ASSURANCE GATE_RESULT_ASSURANCE_FILE
        ;;
      *)
        printf 'Error: unsupported or missing gate_result_version in gate result: %s\n' \
          "$result_file" >&2
        return 1
        ;;
    esac
  }

  # gate-result-verifier-fallback:end
fi

if ! command -v jq >/dev/null 2>&1; then
  printf 'Error: pr-gate requires jq on PATH to produce and verify gate assurance\n' >&2
  exit 2
fi

# ── Resolve assurance policy coordinates ─────────────────────────────────────
# These are resolved before any executor routing or dispatch. The LLM receives
# the resolved values as read-only context; it does not choose or infer them.
if ! GATE_TIER_VALUES="$(_gate_assurance_policy_values tiers tier)"; then
  printf 'Error: invalid gate tier policy source\n' >&2
  exit 2
fi
if ! GATE_MODE_VALUES="$(_gate_assurance_policy_values modes mode)"; then
  printf 'Error: invalid gate mode policy source\n' >&2
  exit 2
fi
if ! GATE_PASS_KIND_VALUES="$(_gate_assurance_policy_values pass-kinds pass_kind)"; then
  printf 'Error: invalid gate pass-kind policy source\n' >&2
  exit 2
fi

if ! GATE_PASS_KIND_DEFAULT="$(_gate_assurance_policy_lookup pass-kinds is_default true pass_kind)"; then
  printf 'Error: gate pass-kind policy must declare exactly one default\n' >&2
  exit 2
fi
if [[ "$GATE_PASS_KIND_DEFAULT" != "initial" ]]; then
  printf 'Error: gate pass-kind policy default must remain initial\n' >&2
  exit 2
fi

if [[ -n "$TIER_OVERRIDE" ]] \
    && ! _gate_assurance_policy_lookup tiers tier "$TIER_OVERRIDE" default_reviewers >/dev/null; then
  printf 'Error: --tier must be one of: %s (got: %s)\n' \
    "$(printf '%s\n' "$GATE_TIER_VALUES" | awk 'BEGIN{ORS=" "} {print} END{print "\n"}' | sed 's/[[:space:]]*$//')" \
    "$TIER_OVERRIDE" >&2
  exit 2
fi

if [[ "$MODE_OPTION_SEEN" == true ]] \
    && ! _gate_assurance_policy_lookup modes mode "$MODE_REQUESTED" topology >/dev/null; then
  printf 'Error: --mode must be one of: %s (got: %s)\n' \
    "$(printf '%s\n' "$GATE_MODE_VALUES" | awk 'BEGIN{ORS=" "} {print} END{print "\n"}' | sed 's/[[:space:]]*$//')" \
    "$MODE_REQUESTED" >&2
  exit 2
fi

PASS_KIND_RESOLVED="$PASS_KIND_REQUESTED"
if ! PASS_SCOPE="$(_gate_assurance_policy_lookup pass-kinds pass_kind "$PASS_KIND_RESOLVED" scope)" \
    || ! PASS_REQUIRES_INITIAL="$(_gate_assurance_policy_lookup pass-kinds pass_kind "$PASS_KIND_RESOLVED" requires_initial_result)"; then
  printf 'Error: gate pass kind must be one of: %s (got: %s)\n' \
    "$(printf '%s\n' "$GATE_PASS_KIND_VALUES" | awk 'BEGIN{ORS=" "} {print} END{print "\n"}' | sed 's/[[:space:]]*$//')" \
    "$PASS_KIND_RESOLVED" >&2
  exit 2
fi
case "$PASS_REQUIRES_INITIAL" in
  true)
    if [[ -z "$INITIAL_RESULT_INPUT" ]]; then
      printf 'Error: --targeted requires --initial-result <path>\n' >&2
      exit 2
    fi
    ;;
  false)
    if [[ -n "$INITIAL_RESULT_INPUT" ]]; then
      printf 'Error: --initial-result is only valid with --targeted\n' >&2
      exit 2
    fi
    ;;
  *)
    printf 'Error: invalid requires_initial_result value for pass kind %s: %s\n' \
      "$PASS_KIND_RESOLVED" "$PASS_REQUIRES_INITIAL" >&2
    exit 2
    ;;
esac

INITIAL_RESULT_RESOLVED=""
if [[ -n "$INITIAL_RESULT_INPUT" ]]; then
  _initial_result_candidate="$INITIAL_RESULT_INPUT"
  [[ "$_initial_result_candidate" == /* ]] \
    || _initial_result_candidate="$WORK_DIR/$_initial_result_candidate"
  if [[ ! -f "$_initial_result_candidate" || ! -r "$_initial_result_candidate" \
      || ! -s "$_initial_result_candidate" ]]; then
    printf 'Error: --initial-result must name a readable, non-empty file: %s\n' \
      "$INITIAL_RESULT_INPUT" >&2
    exit 2
  fi
  _initial_result_parent="$(cd "$(dirname "$_initial_result_candidate")" && pwd -P)" || {
    printf 'Error: cannot resolve --initial-result parent: %s\n' "$INITIAL_RESULT_INPUT" >&2
    exit 2
  }
  INITIAL_RESULT_RESOLVED="$_initial_result_parent/$(basename "$_initial_result_candidate")"
  if ! gate_result_verify "$INITIAL_RESULT_RESOLVED" "" "targeted initial result"; then
    printf 'Error: --initial-result is not a structurally valid gate result: %s\n' \
      "$INITIAL_RESULT_INPUT" >&2
    exit 2
  fi
  unset _initial_result_candidate _initial_result_parent
fi

# Build the closed reviewer vocabulary from tier defaults in source order.
# This is a vocabulary only: a tier default is not actual selected coverage.
ALL_REVIEWERS=""
while IFS= read -r _policy_tier; do
  _policy_reviewers="$(_gate_assurance_policy_lookup tiers tier "$_policy_tier" default_reviewers)" || {
    printf 'Error: invalid default_reviewers for gate tier: %s\n' "$_policy_tier" >&2
    exit 2
  }
  _gate_assurance_policy_lookup tiers tier "$_policy_tier" evidence_floor >/dev/null || {
    printf 'Error: missing evidence_floor for gate tier: %s\n' "$_policy_tier" >&2
    exit 2
  }
  for _policy_reviewer in $(printf '%s' "$_policy_reviewers" | tr ',' ' '); do
    if [[ ! "$_policy_reviewer" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
      printf 'Error: invalid reviewer name in gate tier policy: %s\n' "$_policy_reviewer" >&2
      exit 2
    fi
    if [[ " $ALL_REVIEWERS " != *" $_policy_reviewer "* ]]; then
      ALL_REVIEWERS="${ALL_REVIEWERS:+$ALL_REVIEWERS }$_policy_reviewer"
    fi
  done
done <<< "$GATE_TIER_VALUES"
unset _policy_tier _policy_reviewers _policy_reviewer
if [[ -z "$ALL_REVIEWERS" ]]; then
  printf 'Error: gate tier policy did not declare any reviewers\n' >&2
  exit 2
fi
_gate_policy_validate_sources "$ALL_REVIEWERS" || exit 2

_gate_normalize_reviewer_list() {
  local raw="$1" source_label="$2" normalized="" reviewer
  if [[ -z "${raw//[[:space:]]/}" || "$raw" == ,* || "$raw" == *, || "$raw" == *,,* ]]; then
    printf 'Error: %s requires a non-empty comma-separated reviewer list\n' "$source_label" >&2
    return 2
  fi
  raw="${raw//,/ }"
  for reviewer in $raw; do
    if [[ " $ALL_REVIEWERS " != *" $reviewer "* ]]; then
      printf 'Error: %s contains unknown reviewer %s (allowed: %s)\n' \
        "$source_label" "$reviewer" "$ALL_REVIEWERS" >&2
      return 2
    fi
    if [[ " $normalized " == *" $reviewer "* ]]; then
      printf 'Error: %s contains duplicate reviewer: %s\n' "$source_label" "$reviewer" >&2
      return 2
    fi
    normalized="${normalized:+$normalized }$reviewer"
  done
  [[ -n "$normalized" ]] || return 2
  printf '%s\n' "$normalized"
}

_gate_policy_source_count=0
for _gate_policy_table in tiers modes pass-kinds consumers signals; do
  if _gate_assurance_policy_path "$_gate_policy_table" >/dev/null; then
    _gate_policy_source_count=$((_gate_policy_source_count + 1))
  fi
done
case "$_gate_policy_source_count" in
  5) GATE_ASSURANCE_POLICY_SOURCE="canonical" ;;
  0) GATE_ASSURANCE_POLICY_SOURCE="generated-snapshot" ;;
  *) GATE_ASSURANCE_POLICY_SOURCE="mixed" ;;
esac
unset _gate_policy_source_count _gate_policy_table

EXECUTOR_ROUTER_PATH="$SCRIPT_DIR/../lib/executor-router.sh"
if [[ -r "$EXECUTOR_ROUTER_PATH" ]]; then
  # shellcheck source=runtime/lib/executor-router.sh
  . "$EXECUTOR_ROUTER_PATH"
  EXECUTOR_ROUTER_SCRIPT_DIR="$SCRIPT_DIR"
else
  # DEGRADED copy-mode fallback (no runtime/lib/ alongside this script). It
  # INTENTIONALLY diverges from the data-driven lib (runtime/lib/executor-router.sh):
  # copy-mode has no adapters/ manifest tree to read, so routing is hardcoded to the
  # two built-in executors (codex|claude). The lib is the data-driven authority; this
  # block only needs to keep the gate runnable standalone for those two.
  EXECUTOR_ROUTER_SCRIPT_DIR="$SCRIPT_DIR"

  detect_executor_auto() {
    if command -v codex >/dev/null 2>&1; then
      printf 'codex\n'
    else
      printf 'claude\n'
    fi
  }

  resolve_executor() {
    local option=${1-}

    [[ $# -eq 1 ]] || {
      printf 'executor-router: resolve_executor expects exactly one argument\n' >&2
      return 2
    }

    case "$option" in
      auto) detect_executor_auto ;;
      codex|claude) printf '%s\n' "$option" ;;
      *)
        printf 'executor-router: unknown executor: %s (expected codex, claude, or auto)\n' "$option" >&2
        return 2
        ;;
    esac
  }

  dispatch_route_for() {
    local executor=${1-}

    [[ $# -eq 1 ]] || {
      printf 'executor-router: dispatch_route_for expects exactly one argument\n' >&2
      return 2
    }

    # Both built-in executors run as headless CLI subprocesses (cli-subprocess);
    # claude's canonical route is `claude --print` driven by pmctl dispatch run,
    # not Agent-spawn. Mirrors the data-driven lib resolving both to this route.
    case "$executor" in
      codex) printf 'main_thread_bash_background\n' ;;
      claude) printf 'main_thread_bash_background\n' ;;
      *)
        printf 'executor-router: unknown executor: %s (expected codex or claude)\n' "$executor" >&2
        return 2
        ;;
    esac
  }

  executor_router_safe_argv() {
    local value=${1-}
    printf '%q' "$value"
  }

  # Generic dispatcher mirroring the lib's dispatch_via, hardcoded to the two
  # built-in executors. Only codex is sent --sandbox/--approval; claude (headless
  # `claude --print`) accepts but ignores them as no-ops, so copy-mode omits them
  # — a deliberate simplification of the lib's per-runner-kind rule.
  # shellcheck disable=SC2317 # copy-mode entry is selected dynamically below.
  dispatch_via() {
    local executor=${1-}
    local brief_file=${2-}
    local working_dir=${3-}
    local model=${4-}
    local sandbox=${5-}
    local approval=${6-}
    local timeout=${7-}
    local isolation_level=${8-}
    local effort=${9-}
    local -a cmd
    local arg
    local first=1

    [[ $# -ge 7 && $# -le 9 ]] || {
      printf 'executor-router: dispatch_via expects executor, brief_file, working_dir, model, sandbox, approval, timeout[, isolation_level[, effort]]\n' >&2
      return 2
    }

    case "$executor" in
      codex|claude) ;;
      *)
        printf 'executor-router: %s is not a routable executor (copy-mode supports codex|claude only)\n' "$executor" >&2
        return 2
        ;;
    esac

    local dispatch_script="${EXECUTOR_ROUTER_SCRIPT_DIR%/scripts}/adapters/$executor/dispatch.sh"
    cmd=(bash "$dispatch_script" --cd "$working_dir")
    [[ -n "$model" && "$model" != "default" ]] && cmd+=(--model "$model")
    if [[ "$executor" == "codex" ]]; then
      cmd+=(--sandbox "$sandbox" --approval "$approval")
    fi
    cmd+=(--timeout "$timeout" --brief-file "$brief_file")
    [[ -n "$isolation_level" ]] && cmd+=(--isolation "$isolation_level")
    [[ -n "$effort" ]] && cmd+=(--effort "$effort")
    [[ -n "${PM_DISPATCH_TRACE_DIR:-}" ]] && cmd+=(--trace-dir "$PM_DISPATCH_TRACE_DIR")

    for arg in "${cmd[@]}"; do
      if [[ "$first" -eq 1 ]]; then
        first=0
      else
        printf ' '
      fi
      executor_router_safe_argv "$arg"
    done
    printf '\n'
  }
fi

ARTIFACT_PATHS_PATH="$SCRIPT_DIR/../lib/artifact-paths.sh"
if [[ -r "$ARTIFACT_PATHS_PATH" ]]; then
  # shellcheck source=runtime/lib/artifact-paths.sh
  . "$ARTIFACT_PATHS_PATH"
else
  # Inline fallback for copy-mode (pr-gate.sh run standalone without runtime/lib/).
  # MUST stay in sync with runtime/lib/artifact-paths.sh -- the canonical
  # artifact-leaf source of truth. See that file for the full rationale.
  PM_ARTIFACT_LEAVES=(.agent-trace .gate-briefs .gate-results)

  artifact_filter_porcelain() {
    local rec path code leaf drop expect_orig=0
    while IFS= read -r -d '' rec; do
      if [[ "$expect_orig" -eq 1 ]]; then
        expect_orig=0
        path="$rec"
      else
        code="${rec:0:2}"
        path="${rec:3}"
        [[ "$code" == R* || "$code" == C* ]] && expect_orig=1
      fi

      drop=0
      for leaf in "${PM_ARTIFACT_LEAVES[@]}"; do
        if [[ "$path" == "$leaf" || "$path" == "$leaf/"* ]]; then
          drop=1
          break
        fi
      done

      [[ "$drop" -eq 0 ]] && printf '%s\0' "$rec"
    done
    return 0
  }
fi

# Executor-name validation is delegated to resolve_executor (below): it is the
# single, data-driven authority — `auto` autodetects and any other value must be a
# routable adapter (a valid on-disk manifest), fail-closed on unknown. A hardcoded
# auto|codex|claude pre-check here would re-introduce the very enum the router refactoring removed,
# silently rejecting a manifest-only adapter before resolve_executor is reached.

_validate_isolation_level() {
  local level="$1" policy_file="$2"
  local policy_lib="$SCRIPT_DIR/../lib/pmctl-policy.sh"
  if ! declare -F pmctl_policy_contains >/dev/null 2>&1; then
    if [[ ! -r "$policy_lib" && -r "$SCRIPT_DIR/lib/pmctl-policy.sh" ]]; then
      policy_lib="$SCRIPT_DIR/lib/pmctl-policy.sh"
    fi
    if [[ ! -r "$policy_lib" ]]; then
      printf 'Error: policy reader is unavailable: %s\n' "$policy_lib" >&2
      return 2
    fi
    # shellcheck source=runtime/lib/pmctl-policy.sh
    . "$policy_lib"
  fi
  if [[ -r "$policy_file" ]]; then
    if ! pmctl_policy_contains "$policy_file" "$level" values; then
      local valid_levels
      valid_levels="$(pmctl_policy_values "$policy_file" values | tr '\n' ' ' | sed 's/ $//')"
      printf "Error: --isolation must be one of: %s (got: %s)\n" "$valid_levels" "$level" >&2
      return 2
    fi
  else
    printf "Error: isolation policy source is unavailable: %s\n" "$policy_file" >&2
    return 2
  fi
}

if [[ -n "$DISPATCH_ISOLATION" ]]; then
  ISOLATION_POLICY_FILE="$SCRIPT_DIR/../../core/policy/isolation-level.yaml"
  if [[ ! -r "$ISOLATION_POLICY_FILE" && -r "$SCRIPT_DIR/core/policy/isolation-level.yaml" ]]; then
    ISOLATION_POLICY_FILE="$SCRIPT_DIR/core/policy/isolation-level.yaml"
  fi
  _validate_isolation_level "$DISPATCH_ISOLATION" "$ISOLATION_POLICY_FILE" || exit 2
fi

EXECUTOR="$(resolve_executor "$EXECUTOR_OPTION")" || exit 2

# Reviewer briefs instruct the dispatched session to call `pmctl guard check`
# before writing its output file. For a claude reviewer, that instruction must
# stay a bare `pmctl` invocation -- claude's own PreToolUse permission-allow
# list matches the literal `Bash(pmctl ...)` prefix, and any wrapping (command
# substitution, absolute-path rewrite) breaks that match and stalls headless
# dispatch on an unanswerable permission prompt (see feedback_pmctl_bare_invocation).
# A codex reviewer has no such prefix-allowlist (approval_policy=never governs
# it instead), and has been observed twice (2026-07-07) failing to resolve the
# bare `pmctl` command inside its sandboxed exec environment (CC-469) -- cause
# unconfirmed, but codex's own PATH resolution for the command is not reliable.
# Resolve the absolute path once, in pr-gate's own environment, and embed
# that instead of the bare word for codex reviewer briefs specifically.
# Best-effort: PATH lookup first (the normal install), falling back to the
# sibling cli/pmctl next to this script (source checkouts without a PATH
# symlink). If neither resolves -- e.g. a test fixture that copies pr-gate.sh
# standalone without cli/pmctl alongside it -- fall back to the bare word so
# behavior is unchanged rather than fail-closing the whole gate on it.
GUARD_PMCTL_CMD="pmctl"
if [[ "$EXECUTOR" == "codex" ]]; then
  # Prefer an explicit transport bundled beside a copy-mode gate before the
  # host PATH.  A standalone copied gate must not accidentally bind to an
  # unrelated installed pmctl when its fixture/deployment provides bin/pmctl.
  _guard_pmctl_abs=""
  if [[ -x "$SCRIPT_DIR/cli/pmctl" ]]; then
    _guard_pmctl_abs="$SCRIPT_DIR/cli/pmctl"
  elif [[ -x "$SCRIPT_DIR/bin/pmctl" ]]; then
    _guard_pmctl_abs="$SCRIPT_DIR/bin/pmctl"
  elif [[ -x "$SCRIPT_DIR/../../cli/pmctl" ]]; then
    _guard_pmctl_abs="$SCRIPT_DIR/../../cli/pmctl"
  else
    _guard_pmctl_abs="$(command -v pmctl 2>/dev/null || true)"
  fi
  [[ -n "$_guard_pmctl_abs" ]] && GUARD_PMCTL_CMD="$_guard_pmctl_abs"
  unset _guard_pmctl_abs
fi

# Gate reviewers are producer children, not opaque adapter processes.  Resolve
# the dispatch lifecycle as a SHARED RUNTIME dependency, not as a callback into
# the public CLI: docs/architecture/script-domain-ownership.md requires
# dependencies to flow cli/pmctl -> shared runtime -> adapter, so a producer
# entrypoint under runtime/bin must reach `pmctl_dispatch_run` through
# runtime/lib rather than by re-entering `cli/pmctl`.
#
# Only the repo layout can take this route.  The shared libraries derive their
# own root as `<lib>/../..` (executor-router.sh), which holds for
# `<root>/runtime/lib` but not for a copy-mode bundle that carries `lib/`
# directly beside the gate — there the derived root lands one level above the
# bundle and its `adapters/` tree is invisible.  A copy-mode bundle therefore
# keeps the pre-existing degraded path (direct adapter dispatch, no parent
# operation) rather than loading libraries under a root they cannot resolve.
PMCTL_DISPATCH_LIB_DIR=""
PMCTL_DISPATCH_ROOT=""
if [[ -r "$SCRIPT_DIR/../lib/pmctl-dispatch.sh" && -d "$SCRIPT_DIR/../../adapters" ]]; then
  PMCTL_DISPATCH_LIB_DIR="$SCRIPT_DIR/../lib"
  PMCTL_DISPATCH_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
fi
if [[ -z "$PMCTL_DISPATCH_LIB_DIR" && ( "$EXECUTOR" == codex || "$EXECUTOR" == claude ) ]]; then
  printf 'pr-gate: parent-operation tracking unavailable for this deployment layout; using compatible direct reviewer dispatch\n' >&2
fi

# Libraries are sourced per dispatch inside a subshell rather than at this
# script's top level.  The gate's own shell is long-lived: it evaluates reviewer
# commands, runs a parallel watchdog, and parses results, so importing pmctl's
# whole global namespace into it would trade one coupling problem for a worse
# one.  A subshell keeps the previous process-level isolation while the
# dependency direction stays runtime -> runtime.
pmctl_gate_dispatch_lib_load() {
  local _lib
  for _lib in repo-layout detached-launch pmctl-policy pmctl-fs pmctl-adapter \
    pmctl-guard executor-router pmctl-dispatch pmctl-operation; do
    # shellcheck disable=SC1090
    [[ -r "$PMCTL_DISPATCH_LIB_DIR/$_lib.sh" ]] && . "$PMCTL_DISPATCH_LIB_DIR/$_lib.sh"
  done
  declare -F pmctl_dispatch_run >/dev/null || return 1
  return 0
}

_gate_dispatch_capture() {
  local brief_file="$1" run_id="$2" status="$3"
  local brief_base role=combined reviewer="" capture_file capture_tmp r
  [[ -n "${GATE_ASSURANCE_CAPTURE_DIR:-}" ]] || return 0
  brief_base="$(basename "$brief_file")"
  if [[ "$brief_base" == *-synthesis.md ]]; then
    role=synthesis
  else
    for r in ${REVIEWERS:-}; do
      if [[ "$brief_base" == *-"$r".md ]]; then
        role=reviewer
        reviewer="$r"
        break
      fi
    done
  fi
  capture_file="$GATE_ASSURANCE_CAPTURE_DIR/${role}${reviewer:+-$reviewer}.json"
  capture_tmp="$(mktemp "$GATE_ASSURANCE_CAPTURE_DIR/.capture.XXXXXX")" || {
    printf 'Error: unable to create private gate dispatch capture\n' >&2
    return 1
  }
  if ! jq -n --arg role "$role" --arg reviewer "$reviewer" --arg status "$status" \
    --arg run_id "$run_id" \
    '{role:$role,reviewer:(if $reviewer == "" then null else $reviewer end),
      status:$status,run_id:$run_id,evidence_status:"verified"}' > "$capture_tmp"; then
    rm -f -- "$capture_tmp"
    return 1
  fi
  _gate_assurance_destination_check "$capture_file" || {
    rm -f -- "$capture_tmp"
    return 1
  }
  mv -- "$capture_tmp" "$capture_file" || {
    rm -f -- "$capture_tmp"
    return 1
  }
}

# Gate reviewers are producer children, not opaque adapter processes.  Route
# each invocation through pmctl's detached dispatch lifecycle, then wait for
# its authenticated terminal sentinel.  The optional parent id is injected by
# `pmctl gate run`; without it this remains a compatible standalone gate path.
pmctl_gate_dispatch_and_wait() {
  local executor="$1" brief_file="$2" working_dir="$3" model="$4" sandbox="$5" approval="$6" timeout="$7" isolation_level="${8:-}" effort="${9:-}"
  # pmctl dispatch enforces the executor write boundary at `/tmp/brief-*.md`.
  # Gate briefs are intentionally retained under the private run directory, so
  # copy each one to a one-shot guardable snapshot before handing it to pmctl.
  # Detached dispatch snapshots that input again before its supervisor starts;
  # removing this intermediate copy after `dispatch run` returns is therefore
  # safe and keeps the gate's durable source of truth inside the run directory.
  local dispatch_brief dispatch_brief_name rc
  dispatch_brief="$(mktemp -p /tmp "brief-gate-XXXXXX.md")" || {
    printf 'pr-gate: failed to create guardable dispatch brief\n' >&2
    return 1
  }
  # Preserve the source basename (notably the `-synthesis.md` role suffix)
  # across the guarded /tmp snapshot.  Adapters may use the brief role to
  # select their result contract; a generic mktemp basename erased it.
  dispatch_brief_name="${dispatch_brief%.md}-$(basename "$brief_file")"
  if ! command -p mv "$dispatch_brief" "$dispatch_brief_name"; then
    rm -f "$dispatch_brief"
    printf 'pr-gate: failed to name guardable dispatch brief\n' >&2
    return 1
  fi
  dispatch_brief="$dispatch_brief_name"
  if ! cp "$brief_file" "$dispatch_brief"; then
    rm -f "$dispatch_brief"
    printf 'pr-gate: failed to snapshot reviewer brief for dispatch\n' >&2
    return 1
  fi
  local -a args=(--adapter "$executor" --cd "$working_dir" --brief-file "$dispatch_brief" --lifecycle detached --timeout "$timeout")
  [[ -n "$model" && "$model" != default ]] && args+=(--model "$model")
  [[ -n "$isolation_level" ]] && args+=(--isolation "$isolation_level")
  [[ -n "$effort" ]] && args+=(--effort "$effort")
  [[ -n "${PM_DISPATCH_TRACE_DIR:-}" ]] && args+=(--trace-dir "$PM_DISPATCH_TRACE_DIR")
  [[ "$executor" == codex ]] && args+=(--sandbox "$sandbox" --approval "$approval")
  [[ -n "${PM_GATE_PARENT_OPERATION:-}" ]] && args+=(--parent-operation "$PM_GATE_PARENT_OPERATION")
  local run_id
  run_id="$(
    pmctl_gate_dispatch_lib_load || exit 2
    pmctl_dispatch_run "$PMCTL_DISPATCH_ROOT" "${args[@]}"
  )" || {
    rc=$?
    rm -f "$dispatch_brief"
    return "$rc"
  }
  run_id="$(printf '%s\n' "$run_id" | tail -1 | tr -d '[:space:]')"
  if ! [[ "$run_id" =~ ^run-[A-Za-z0-9]+-[A-Za-z0-9]+$ ]]; then
    rm -f "$dispatch_brief"
    printf 'pr-gate: dispatch returned invalid run id\n' >&2
    return 2
  fi
  local dispatch_status=passed
  rc=0
  (
    pmctl_gate_dispatch_lib_load || exit 2
    pmctl_dispatch_wait "$PMCTL_DISPATCH_ROOT" "$run_id" --cd "$working_dir" --timeout "$timeout"
  ) || {
    rc=$?
    dispatch_status=failed
  }
  _gate_dispatch_capture "$brief_file" "$run_id" "$dispatch_status" || {
    rm -f "$dispatch_brief"
    return 1
  }
  rm -f "$dispatch_brief"
  return "$rc"
}

# Override the adapter-command formatter loaded above for gate execution only.
# Call sites still receive a safely-quoted command string, preserving the
# parallel watchdog/eval structure while moving lifecycle ownership to pmctl.
if [[ -n "$PMCTL_DISPATCH_LIB_DIR" ]]; then
dispatch_via() {
  local first=1 arg
  for arg in pmctl_gate_dispatch_and_wait "$@"; do
    if [[ "$first" -eq 1 ]]; then first=0; else printf ' '; fi
    printf '%q' "$arg"
  done
  printf '\n'
}
fi

# Every supported executor now dispatches an INDEPENDENT subprocess (codex `codex
# exec`, claude headless `claude --print`) and writes the result in-process, which
# the gate then integrity-checks. This flag is the seam where a future
# non-subprocess (e.g. host-handover) executor would branch; both current
# executors take the subprocess path.
EXECUTOR_IS_SUBPROCESS=true

unset _self _self_dir EXECUTOR_ROUTER_PATH

cd "$WORK_DIR"

# ── Load gate overrides ───────────────────────────────────────────────────────
# Auto-discover .gate-overrides.md when --override-file is not specified.
# Overrides are injected into every reviewer brief so accepted-risk items are
# not re-blocked across rounds without a material change to the reviewed code.
if [[ -z "$OVERRIDE_FILE" && -f "$WORK_DIR/.gate-overrides.md" ]]; then
  OVERRIDE_FILE="$WORK_DIR/.gate-overrides.md"
  say 'pr-gate: discovered override file: .gate-overrides.md\n'
fi
GATE_OVERRIDES_CONTENT=""
REVIEWER_OVERRIDE_PROVENANCE_JSON='{"status":"not_provided","source":null,"sha256":null}'
if [[ -n "$OVERRIDE_FILE" ]]; then
  if [[ ! -f "$OVERRIDE_FILE" ]]; then
    printf 'Error: override file not found: %s\n' "$OVERRIDE_FILE" >&2
    exit 2
  fi
  _override_parent="$(cd "$(dirname "$OVERRIDE_FILE")" && pwd -P)" || exit 2
  OVERRIDE_FILE="$_override_parent/$(basename "$OVERRIDE_FILE")"
  unset _override_parent
  GATE_OVERRIDES_CONTENT=$(cat "$OVERRIDE_FILE")
  _reviewer_override_sha="$(_gate_result_sha256_file "$OVERRIDE_FILE")" || exit 2
  REVIEWER_OVERRIDE_PROVENANCE_JSON="$(jq -nc \
    --arg source "$OVERRIDE_FILE" --arg sha256 "$_reviewer_override_sha" \
    '{status:"provided",source:$source,sha256:$sha256}')"
  unset _reviewer_override_sha
  say 'pr-gate: override file loaded: %s (%d bytes)\n' "$OVERRIDE_FILE" "${#GATE_OVERRIDES_CONTENT}"
fi
if [[ -n "$POLICY_OVERRIDE_FILE" ]]; then
  _policy_override_candidate="$POLICY_OVERRIDE_FILE"
  [[ "$_policy_override_candidate" == /* ]] \
    || _policy_override_candidate="$WORK_DIR/$_policy_override_candidate"
  if [[ ! -f "$_policy_override_candidate" || ! -r "$_policy_override_candidate" \
      || ! -s "$_policy_override_candidate" || -L "$_policy_override_candidate" ]]; then
    printf 'Error: --policy-override must name a readable, non-empty, regular non-symlink JSON file: %s\n' \
      "$POLICY_OVERRIDE_FILE" >&2
    exit 2
  fi
  _policy_override_parent="$(cd "$(dirname "$_policy_override_candidate")" && pwd -P)" \
    || exit 2
  POLICY_OVERRIDE_FILE="$_policy_override_parent/$(basename "$_policy_override_candidate")"
  unset _policy_override_candidate _policy_override_parent
fi

# ── Detect base branch ────────────────────────────────────────────────────────
if [[ -n "$BASE_OVERRIDE" ]]; then
  BASE="$BASE_OVERRIDE"
else
  if command -v gh >/dev/null 2>&1; then
    if GH_BASE=$(gh pr view --json baseRefName -q .baseRefName 2>/dev/null); then
      if [[ -n "$GH_BASE" ]]; then
        BASE="$GH_BASE"
        say 'pr-gate: base detected from gh pr view: %s\n' "$BASE"
      else
        BASE=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || true)
        : "${BASE:=main}"
      fi
    else
      BASE=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || true)
      : "${BASE:=main}"
    fi
  else
    BASE=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || true)
    : "${BASE:=main}"
  fi
fi
if ! git rev-parse --verify "$BASE" > /dev/null 2>&1; then
  printf 'Error: base ref not found: %s\n' "$BASE" >&2
  exit 1
fi

# ── Detect head ref ────────────────────────────────────────────────────────
# Default HEAD keeps the existing working-tree/branch-diff behavior below.
# A fixed --head ref (branch, tag, commit) diffs base..head_ref directly with
# no working tree involved, so it is incompatible with --allow-dirty (which
# exists specifically to fold uncommitted working-tree state into scope).
HEAD_REF="HEAD"
if [[ -n "$HEAD_OVERRIDE" ]]; then
  if [[ "$ALLOW_DIRTY" == true ]]; then
    printf 'Error: --head and --allow-dirty are incompatible (--head diffs a fixed ref pair; --allow-dirty folds in local working-tree changes)\n' >&2
    exit 2
  fi
  HEAD_REF="$HEAD_OVERRIDE"
  if ! git rev-parse --verify "$HEAD_REF" > /dev/null 2>&1; then
    printf 'Error: head ref not found: %s\n' "$HEAD_REF" >&2
    exit 1
  fi
fi
# Surfaced in reviewer brief context blocks (Base: ${BASE}${HEAD_METADATA_LINE})
# only when a fixed --head ref is in play; a plain HEAD comparison omits the
# line entirely since it would just say "Head: HEAD" (no information).
HEAD_METADATA_LINE=""
if [[ "$HEAD_REF" != "HEAD" ]]; then
  HEAD_METADATA_LINE=$'\n  Head: '"${HEAD_REF}"
fi

# Resolve canonical memory once through the shared runtime boundary and pass
# the resulting provenance/context to every reviewer. Ref/argument validation
# intentionally precedes runtime loading so malformed invocations remain
# diagnosable even for a deliberately minimal copied gate.
_gate_memory_lib="$SCRIPT_DIR/lib/gate-memory-context.sh"
[[ -r "$_gate_memory_lib" ]] || _gate_memory_lib="$SCRIPT_DIR/../lib/gate-memory-context.sh"
if [[ ! -r "$_gate_memory_lib" ]]; then
  printf 'Error: shared gate memory runtime not found: %s\n' "$_gate_memory_lib" >&2
  exit 1
fi
# shellcheck source=runtime/lib/gate-memory-context.sh
# shellcheck disable=SC1090
. "$_gate_memory_lib"
gate_memory_context_hydrate "$WORK_DIR" "${SCOPE:-PR gate review}" || exit 1
printf -v MEMORY_CONTEXT_BLOCK \
  '  Canonical memory provenance:\n    provider: pmctl\n    authority: canonical\n    resolution_status: %s\n    resolution_source: %s\n    project_key: %s\n    context_status: %s\n' \
  "$GATE_MEMORY_STATUS" "$GATE_MEMORY_SOURCE" "${GATE_MEMORY_PROJECT_KEY:-none}" "$GATE_MEMORY_CONTEXT_STATUS"
if [[ -n "$GATE_MEMORY_CONTEXT" ]]; then
  printf -v _gate_memory_context_rendered \
    '  Canonical memory context (read-only JSON; do not infer another path):\n    %s\n' \
    "${GATE_MEMORY_CONTEXT//$'\n'/$'\n    '}"
  MEMORY_CONTEXT_BLOCK+="$_gate_memory_context_rendered"
fi
unset _gate_memory_lib _gate_memory_context_rendered

_worktree_is_dirty() {
  # uncommitted tracked changes (staged or unstaged) ...
  if ! git diff --quiet HEAD 2>/dev/null; then return 0; fi
  # ... or any non-gitignored untracked file
  [[ -n "$(git ls-files --others --exclude-standard)" ]]
}

# ── dirty-worktree preflight ─────────────────────────────────────────────────
# When the branch has committed changes, the brief below is built from
# "$BASE"...HEAD and silently omits uncommitted tracked + untracked files
# (a prior gate missed install.sh this exact way). Fail loud so the user
# commits first for a complete, reproducible review -- unless they explicitly
# opt into reviewing the working tree as-is. A dirty-only tree with NO
# committed changes is handled by the working-tree fallback below and is NOT
# failed here (nothing is omitted in that case). Skipped entirely for a fixed
# --head ref: that path never reads the working tree.
if [[ "$HEAD_REF" == "HEAD" ]] && ! git diff "$BASE"...HEAD --quiet 2>/dev/null && _worktree_is_dirty; then
  if [[ "$ALLOW_DIRTY" != true ]]; then
    _dt=$(git diff HEAD --name-only 2>/dev/null | { grep -c . || true; })
    _du=$(git ls-files --others --exclude-standard | { grep -c . || true; })
    {
      printf 'Error: working tree is dirty while the branch has committed changes against %s.\n' "$BASE"
      printf '  The review brief is built from %s...HEAD and would silently omit:\n' "$BASE"
      printf '    %s uncommitted tracked file(s), %s untracked file(s).\n' "$_dt" "$_du"
      printf '  Commit them first for a complete, reproducible review,\n'
      printf '  or pass --allow-dirty to fold the working tree into the review scope.\n'
    } >&2
    exit 3
  fi
  printf 'pr-gate: --allow-dirty set -- folding uncommitted working-tree changes into review scope\n' >&2
fi

# ── Collect diff and policy inputs ────────────────────────────────────────────
# Keep the status-bearing form until policy resolution so renamed and untracked
# inputs remain machine-visible. Use --numstat to detect binary files
# (shown as -\t-\t<file>).
UNTRACKED_PATHS=""
if [[ "$HEAD_REF" != "HEAD" ]]; then
  # Fixed head ref (e.g. tag-to-tag, or a branch reviewed before a PR exists)
  # -- no working tree involved, so no dirty/fallback branches apply. Three-dot
  # (merge-base) diff, matching the default HEAD path below: reviews what
  # changed on HEAD_REF since it diverged from BASE, not a literal two-dot
  # tree diff -- so BASE moving forward independently does not appear here.
  DIFF_NAME_STATUS="$(git diff "$BASE"..."$HEAD_REF" --name-status)"
  DIFF_STAT=$(git diff "$BASE"..."$HEAD_REF" --stat)
  BINARY_HIT=$(git diff "$BASE"..."$HEAD_REF" --numstat | { grep -c $'^-\t-\t' || true; })
  POLICY_DIFF_KIND="fixed-head"
  POLICY_SCOPE_INCLUDE_UNTRACKED=false
  LINES=$(git diff "$BASE"..."$HEAD_REF" --numstat | awk '
    /^-\t-\t/ { next }
    { s += $1 + $2 }
    END { print s+0 }
  ')
elif [[ "$ALLOW_DIRTY" == true ]] && _worktree_is_dirty; then
  # --allow-dirty: fold the working tree into scope. Two-dot diff vs BASE
  # captures committed + uncommitted tracked changes; untracked listed separately.
  UNTRACKED_PATHS="$(git ls-files --others --exclude-standard)"
  DIFF_NAME_STATUS="$(
    git diff "$BASE" --name-status
    printf '%s\n' "$UNTRACKED_PATHS" | awk 'NF { print "?\t" $0 }'
  )"
  DIFF_STAT=$(git diff "$BASE" --stat)
  BINARY_HIT=$(git diff "$BASE" --numstat | { grep -c $'^-\t-\t' || true; })
  POLICY_DIFF_KIND="allow-dirty"
  POLICY_SCOPE_INCLUDE_UNTRACKED=true
  LINES=$(git diff "$BASE" --numstat | awk '
    /^-\t-\t/ { next }
    { s += $1 + $2 }
    END { print s+0 }
  ')
  UNTRACKED_NONDOC=$(git ls-files --others --exclude-standard | \
    { grep -cvE '\.(md|jsonl|txt)$|^\.gitignore$|^audits/|^docs/' || true; })
  BINARY_HIT=$((BINARY_HIT + UNTRACKED_NONDOC))
elif ! git diff "$BASE"...HEAD --quiet 2>/dev/null; then
  # For renames (R* status lines), emit both old and new path so sensitive
  # keywords in the old name (e.g. auth.ts → login.ts) are not lost.
  DIFF_NAME_STATUS="$(git diff "$BASE"...HEAD --name-status)"
  DIFF_STAT=$(git diff "$BASE"...HEAD --stat)
  BINARY_HIT=$(git diff "$BASE"...HEAD --numstat | { grep -c $'^-\t-\t' || true; })
  POLICY_DIFF_KIND="committed"
  POLICY_SCOPE_INCLUDE_UNTRACKED=false
  LINES=$(git diff "$BASE"...HEAD --numstat | awk '
    /^-\t-\t/ { next }
    { s += $1 + $2 }
    END { print s+0 }
  ')
else
  # No branch commits -- fall back to working tree changes
  UNTRACKED_PATHS="$(git ls-files --others --exclude-standard)"
  DIFF_NAME_STATUS="$(
    git diff HEAD --name-status
    printf '%s\n' "$UNTRACKED_PATHS" | awk 'NF { print "?\t" $0 }'
  )"
  DIFF_STAT=$(git diff HEAD --stat)
  BINARY_HIT=$(git diff HEAD --numstat | { grep -c $'^-\t-\t' || true; })
  POLICY_DIFF_KIND="working-tree"
  POLICY_SCOPE_INCLUDE_UNTRACKED=true
  LINES=$(git diff HEAD --numstat | awk '
    /^-\t-\t/ { next }
    { s += $1 + $2 }
    END { print s+0 }
  ')
  # Untracked non-doc files are not included in git diff HEAD --numstat, so
  # BINARY_HIT and LINES would both be 0, silently routing to express.
  # Treat each untracked non-doc file as a binary (unknown size) to prevent
  # under-tiering.
  UNTRACKED_NONDOC=$(git ls-files --others --exclude-standard | \
    { grep -cvE '\.(md|jsonl|txt)$|^\.gitignore$|^audits/|^docs/' || true; })
  BINARY_HIT=$((BINARY_HIT + UNTRACKED_NONDOC))
fi

DIFF_FILES="$(printf '%s\n' "$DIFF_NAME_STATUS" | awk -F '\t' '
  $1 ~ /^[RC]/ { print $2; print $3; next }
  $1 ~ /^[AMDCT?]/ { print $2 }
' | awk 'NF && !seen[$0]++')"
if [[ -z "$DIFF_FILES" ]]; then
  printf 'Error: no changed files detected against %s\n' "$BASE" >&2; exit 1
fi

# Preserve the complete status-derived policy inputs. Scope-manifest expansion
# remains a later concern; this resolver records only deterministic facts it
# owns and a fingerprint over the complete status stream.
RENAMED_PATHS="$(printf '%s\n' "$DIFF_NAME_STATUS" | awk -F '\t' '
  $1 ~ /^R/ { print $2; print $3 }
' | awk 'NF && !seen[$0]++')"
[[ -n "$UNTRACKED_PATHS" ]] || UNTRACKED_PATHS="$(printf '%s\n' "$DIFF_NAME_STATUS" \
  | awk -F '\t' '$1 == "?" { print $2 }')"
GENERATED_PATHS=""
while IFS= read -r _policy_path; do
  [[ -n "$_policy_path" ]] || continue
  case "$_policy_path" in
    generated/*|*/generated/*|dist/*|*/dist/*|vendor/*|*/vendor/*|*.generated.*)
      GENERATED_PATHS="${GENERATED_PATHS:+$GENERATED_PATHS$'\n'}$_policy_path"
      continue
      ;;
  esac
  if [[ -f "$WORK_DIR/$_policy_path" ]] \
      && head -n 8 "$WORK_DIR/$_policy_path" 2>/dev/null \
        | grep -qiE 'do not edit.*generated|generated.*do not edit'; then
    GENERATED_PATHS="${GENERATED_PATHS:+$GENERATED_PATHS$'\n'}$_policy_path"
  fi
done <<< "$DIFF_FILES"

NON_DOCS="$(printf '%s\n' "$DIFF_FILES" \
  | grep -vE '\.(md|jsonl|txt)$|^\.gitignore$|^audits/|^docs/' || true)"
LAYER_ROOTS="$(printf '%s\n' "$NON_DOCS" | awk -F/ '
  $1 ~ /^(core|runtime|cli|adapters|hosts|commands|skills)$/ { print $1; next }
  $1 ~ /^(install|uninstall)\.sh$/ { print $1 }
' | LC_ALL=C sort -u)"
LAYER_ROOT_COUNT="$(printf '%s\n' "$LAYER_ROOTS" | grep -c '[^[:space:]]' || true)"

ARCHITECTURE_IMPACT="unknown"
if [[ -n "$INPUT_BRIEF_FILE" ]]; then
  _input_brief_candidate="$INPUT_BRIEF_FILE"
  [[ "$_input_brief_candidate" == /* ]] \
    || _input_brief_candidate="$WORK_DIR/$_input_brief_candidate"
  if [[ ! -f "$_input_brief_candidate" || ! -r "$_input_brief_candidate" ]]; then
    printf 'Error: --brief must name a readable file: %s\n' "$INPUT_BRIEF_FILE" >&2
    exit 2
  fi
  _input_brief_parent="$(cd "$(dirname "$_input_brief_candidate")" && pwd -P)" || exit 2
  INPUT_BRIEF_FILE="$_input_brief_parent/$(basename "$_input_brief_candidate")"
  ARCHITECTURE_IMPACT="$(awk '
    /^architecture_impact:[[:space:]]*/ {
      sub(/^architecture_impact:[[:space:]]*/, "")
      gsub(/[[:space:]]/, "")
      print
      exit
    }
  ' "$INPUT_BRIEF_FILE")"
  : "${ARCHITECTURE_IMPACT:=unknown}"
  case "$ARCHITECTURE_IMPACT" in
    none|minor|major|unknown) ;;
    *)
      printf 'Error: --brief has invalid architecture_impact: %s\n' \
        "$ARCHITECTURE_IMPACT" >&2
      exit 2
      ;;
  esac
  unset _input_brief_candidate _input_brief_parent
fi

DIFF_FILES_JSON="$(printf '%s\n' "$DIFF_FILES" | _gate_policy_lines_json)"
NON_DOCS_JSON="$(printf '%s\n' "$NON_DOCS" | _gate_policy_lines_json)"
RENAMED_PATHS_JSON="$(printf '%s\n' "$RENAMED_PATHS" | _gate_policy_lines_json)"
UNTRACKED_PATHS_JSON="$(printf '%s\n' "$UNTRACKED_PATHS" | _gate_policy_lines_json)"
GENERATED_PATHS_JSON="$(printf '%s\n' "$GENERATED_PATHS" | _gate_policy_lines_json)"
LAYER_ROOTS_JSON="$(printf '%s\n' "$LAYER_ROOTS" | _gate_policy_lines_json)"
_policy_docs_only=false
[[ -z "$NON_DOCS" ]] && _policy_docs_only=true
_policy_cross_boundary=false
[[ "$LAYER_ROOT_COUNT" -gt 1 ]] && _policy_cross_boundary=true
CLASSIFICATIONS_JSON="$(jq -nc \
  --argjson docs_only "$_policy_docs_only" \
  --argjson changed_paths "$DIFF_FILES_JSON" --argjson non_docs "$NON_DOCS_JSON" \
  --argjson renamed "$RENAMED_PATHS_JSON" --argjson untracked "$UNTRACKED_PATHS_JSON" \
  --argjson generated "$GENERATED_PATHS_JSON" --argjson layer_roots "$LAYER_ROOTS_JSON" \
  --argjson cross_boundary "$_policy_cross_boundary" \
  --argjson lines "$LINES" --argjson binary_or_unknown "${BINARY_HIT:-0}" '[
    if $docs_only then {id:"docs-only",matches:$changed_paths}
    else {id:"bounded-runtime",matches:$non_docs} end,
    if $lines > 500 then {id:"large-change",matches:[("changed-lines:" + ($lines|tostring))]}
    elif $lines >= 100 then {id:"medium-change",matches:[("changed-lines:" + ($lines|tostring))]}
    else empty end,
    if $binary_or_unknown > 0 then {
      id:"binary-change",matches:[("binary-or-unknown:" + ($binary_or_unknown|tostring))]
    } else empty end,
    if ($renamed|length) > 0 then {id:"renamed",matches:$renamed} else empty end,
    if ($untracked|length) > 0 then {id:"untracked",matches:$untracked} else empty end,
    if ($generated|length) > 0 then {id:"generated",matches:$generated} else empty end,
    if $cross_boundary then {id:"cross-boundary",matches:$layer_roots} else empty end
  ]')"
POLICY_SCOPE_CONTENT_DIGEST="$(
  _gate_policy_scope_content_digest \
    "$POLICY_DIFF_KIND" "$BASE" "$HEAD_REF" "$POLICY_SCOPE_INCLUDE_UNTRACKED"
)" || exit 2
POLICY_SCOPE_FINGERPRINT="$(
  {
    printf 'policy=%s\npass=%s\narchitecture_impact=%s\nlines=%s\nbinary_or_unknown=%s\ncontent=%s\n' \
      "$POLICY_CONSUMER" "$PASS_KIND_RESOLVED" "$ARCHITECTURE_IMPACT" \
      "$LINES" "${BINARY_HIT:-0}" "$POLICY_SCOPE_CONTENT_DIGEST"
    printf '%s\n' "$DIFF_NAME_STATUS"
  } | _gate_sha256_stream
)" || exit 2

REQUESTED_REVIEWERS_JSON=null
if [[ -n "$REVIEWERS_OVERRIDE" ]]; then
  _requested_reviewer_words="$(_gate_normalize_reviewer_list \
    "$REVIEWERS_OVERRIDE" "$REVIEWERS_OPTION_SOURCE")" || exit 2
  REQUESTED_REVIEWERS_JSON="$(_gate_policy_words_json "$_requested_reviewer_words")"
  COVERAGE_REQUESTED_DISPLAY="$(printf '%s' "$_requested_reviewer_words" | tr ' ' ',')"
  unset _requested_reviewer_words
else
  COVERAGE_REQUESTED_DISPLAY="default"
fi

GATE_POLICY_INPUT="$(jq -nc \
  --arg policy "$POLICY_CONSUMER" --arg policy_source "$GATE_ASSURANCE_POLICY_SOURCE" \
  --arg scope_fingerprint "$POLICY_SCOPE_FINGERPRINT" \
  --arg tier "$TIER_REQUESTED" --arg mode "$MODE_REQUESTED" \
  --arg pass_kind "$PASS_KIND_RESOLVED" \
  --argjson reviewers "$REQUESTED_REVIEWERS_JSON" \
  --argjson vocabulary "$(_gate_policy_words_json "$ALL_REVIEWERS")" \
  --arg architecture_impact "$ARCHITECTURE_IMPACT" \
  --argjson line_changes "$LINES" \
  --argjson binary_or_unknown "${BINARY_HIT:-0}" \
  --argjson layer_roots "$LAYER_ROOTS_JSON" \
  --argjson classifications "$CLASSIFICATIONS_JSON" \
  --argjson changed_paths "$DIFF_FILES_JSON" \
  --argjson reviewer_override "$REVIEWER_OVERRIDE_PROVENANCE_JSON" '{
    policy:$policy,
    policy_source:$policy_source,
    scope_fingerprint:$scope_fingerprint,
    requested:{tier:$tier,mode:$mode,pass_kind:$pass_kind,reviewers:$reviewers},
    reviewer_vocabulary:$vocabulary,
    changed_paths:$changed_paths,
    classifications:$classifications,
    classification:{
      architecture_impact:$architecture_impact,
      line_changes:$line_changes,
      binary_or_unknown_count:$binary_or_unknown,
      layer_roots:$layer_roots
    },
    reviewer_override:$reviewer_override
  }')"
GATE_POLICY_RESOLUTION="$(_gate_policy_resolve \
  "$GATE_POLICY_INPUT" "$POLICY_OVERRIDE_FILE")" || exit 2
if [[ "$(jq -r '.enforcement.status' <<<"$GATE_POLICY_RESOLUTION")" != pass ]]; then
  {
    printf 'Error: requested gate assurance is below the canonical %s policy floor.\n' \
      "$POLICY_CONSUMER"
    printf '  policy scope fingerprint: %s\n' "$POLICY_SCOPE_FINGERPRINT"
    jq -r '.enforcement.violations[] |
      "  - " + .coordinate + ": requested=" + (.requested|tostring) +
      " required=" + (.required|tostring)' <<<"$GATE_POLICY_RESOLUTION"
    printf '  A downgrade requires an explicit --policy-override gate_policy_override_v1 JSON\n'
    printf '  bound to this exact scope and carrying recorded user approval.\n'
    if [[ -n "$POLICY_OVERRIDE_FILE" ]]; then
      printf '  supplied override status: %s\n' \
        "$(jq -r '.override.status' <<<"$GATE_POLICY_RESOLUTION")"
    fi
  } >&2
  exit 3
fi

TIER_RESOLVED="$(jq -r '.resolved.tier' <<<"$GATE_POLICY_RESOLUTION")"
TIER="$TIER_RESOLVED"
TIER_EVIDENCE_FLOOR="$(_gate_assurance_policy_lookup tiers tier "$TIER" evidence_floor)" || {
  printf 'Error: gate tier policy has no evidence floor for: %s\n' "$TIER" >&2
  exit 2
}
MODE_RESOLVED="$(jq -r '.resolved.mode' <<<"$GATE_POLICY_RESOLUTION")"
MODE_TOPOLOGY="$(_gate_assurance_policy_lookup modes mode "$MODE_RESOLVED" topology)" \
  || exit 2
MODE_SYNTHESIS="$(_gate_assurance_policy_lookup modes mode "$MODE_RESOLVED" synthesis)" \
  || exit 2
case "$MODE_TOPOLOGY:$MODE_SYNTHESIS" in
  combined-session:inline) SEQUENTIAL=true ;;
  per-reviewer-sessions:separate-session) SEQUENTIAL=false ;;
  *)
    printf 'Error: unsupported gate mode topology for %s: %s + %s\n' \
      "$MODE_RESOLVED" "$MODE_TOPOLOGY" "$MODE_SYNTHESIS" >&2
    exit 2
    ;;
esac
REVIEWERS="$(jq -r '.resolved.reviewers | join(" ")' <<<"$GATE_POLICY_RESOLUTION")"
[[ -n "$REVIEWERS" ]] || {
  printf 'Error: gate policy resolved empty reviewer coverage\n' >&2
  exit 2
}

REVIEWER_DISPLAY=$(printf '%s' "$REVIEWERS" | tr ' ' ',')
NUM_REVIEWERS=$(printf '%s\n' "$REVIEWERS" | awk '{print NF}')

# Compute skipped dimensions
SKIPPED=""
SKIPPED_WORDS=""
for r in $ALL_REVIEWERS; do
  if ! printf '%s' "$REVIEWERS" | grep -qw "$r"; then
    SKIPPED="${SKIPPED:+$SKIPPED, }$r"
    SKIPPED_WORDS="${SKIPPED_WORDS:+$SKIPPED_WORDS }$r"
  fi
done
SKIPPED_DISPLAY="${SKIPPED:-none}"
COVERAGE_SELECTED_DISPLAY="$REVIEWER_DISPLAY"
COVERAGE_SKIPPED_DISPLAY="$SKIPPED_DISPLAY"

# ── Resolve reviewer definitions ─────────────────────────────────────────────
# Definitions outside the reviewed workspace are trusted installation assets.
# A definition directory inside the reviewed workspace is attacker-controlled,
# so read it from the trusted base revision rather than from the working tree.
AGENT_DIR="$REVIEWER_DIR_OVERRIDE"
if [[ -z "$AGENT_DIR" && -d "$SCRIPT_DIR/../../agents" ]]; then
  AGENT_DIR="$SCRIPT_DIR/../../agents"
elif [[ -z "$AGENT_DIR" && -d "$SCRIPT_DIR/agents" ]]; then
  AGENT_DIR="$SCRIPT_DIR/agents"
fi
if [[ ! -d "$AGENT_DIR" ]]; then
  printf 'Error: reviewer definition directory not found; use --reviewer-dir: %s\n' "${AGENT_DIR:-unset}" >&2; exit 1
fi
AGENT_DIR="$(cd "$AGENT_DIR" && pwd -P)"
REVIEWER_SOURCE_MODE="trusted-directory"
REVIEWER_BASE_REL=""
case "$AGENT_DIR" in
  "$WORK_DIR"/*)
    REVIEWER_SOURCE_MODE="base-pinned"
    REVIEWER_BASE_REL="${AGENT_DIR#"$WORK_DIR"/}"
    ;;
esac
say 'pr-gate: reviewer definition source: %s (%s)\n' "$REVIEWER_SOURCE_MODE" "$AGENT_DIR"

# Validate all reviewer agent files exist before doing any work
for r in $REVIEWERS; do
  if [[ "$REVIEWER_SOURCE_MODE" == "base-pinned" ]]; then
    if ! git cat-file -e "$BASE:$REVIEWER_BASE_REL/${r}.md" 2>/dev/null; then
      printf 'Error: reviewer agent file not found in trusted base %s: %s/%s.md\n' \
        "$BASE" "$REVIEWER_BASE_REL" "$r" >&2
      exit 1
    fi
  else
    AGENT_PATH="$AGENT_DIR/${r}.md"
    if [[ ! -f "$AGENT_PATH" ]]; then
      printf 'Error: reviewer agent file not found: %s\n' "$AGENT_PATH" >&2
      exit 1
    fi
  fi
done

# ── Prepare output paths ─────────────────────────────────────────────────────
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
_ARTIFACT_ROOT="${GATE_RUN_DIR_OVERRIDE:-$WORK_DIR}"
BRIEF_DIR="$_ARTIFACT_ROOT/.gate-briefs"
mkdir -p "$BRIEF_DIR"
GATE_ASSURANCE_CAPTURE_DIR="$(mktemp -d "/tmp/pm-gate-assurance-${TIMESTAMP}.XXXXXX")" || {
  printf 'Error: unable to create private gate assurance capture directory\n' >&2
  exit 1
}
command -p chmod 700 "$GATE_ASSURANCE_CAPTURE_DIR" || exit 1
# Route executor traces (adapter JSONL/last/stderr) to the run dir when provided.
# PM_DISPATCH_TRACE_DIR is read by dispatch_via (lib and copy-mode) to forward
# --trace-dir to the adapter, so the adapter's own trace files follow the run dir.
if [[ -n "$GATE_RUN_DIR_OVERRIDE" ]]; then
  export PM_DISPATCH_TRACE_DIR="$GATE_RUN_DIR_OVERRIDE/.agent-trace"
fi

# OUTPUT_FILE must be in WORK_DIR so the executor (codex/claude, workspace-write sandbox)
# can write it. After final verification the gate moves it to _ARTIFACT_ROOT if a run dir
# was supplied. --output explicit override is always used verbatim, no move.
OUTPUT_FILE="${OUTPUT_OVERRIDE:-$WORK_DIR/.gate-results/gate-${TIMESTAMP}.md}"
# Normalize to an absolute path. The reviewer write-guard (guard-reviewer-write.sh)
# requires an absolute file_path, and the pr-gate-handover_v1 schema mandates an absolute
# output_file. A relative --output (or a relative --cd default) would otherwise be embedded
# verbatim into the reviewer brief's `pmctl guard check` constraint, making the guard exit
# nonzero and the reviewer abort the write -- the 0-byte-result failure mode, for any executor.
# Ordering dependency: this relies on the earlier `cd "$WORK_DIR"` having already run, so $PWD
# here IS the absolute working dir and a relative OUTPUT_FILE resolves to an absolute path under it.
[[ "$OUTPUT_FILE" = /* ]] || OUTPUT_FILE="$PWD/$OUTPUT_FILE"
mkdir -p "$(dirname "$OUTPUT_FILE")"
_output_parent="$(cd "$(dirname "$OUTPUT_FILE")" && pwd -P)"
OUTPUT_FILE="$_output_parent/$(basename "$OUTPUT_FILE")"
unset _output_parent
ASSURANCE_FILE="${OUTPUT_FILE}.assurance.json"
ASSURANCE_POINTER="$(basename "$ASSURANCE_FILE")"
ASSURANCE_ATTESTATION_FILE=""
ASSURANCE_ATTESTATION_POINTER=""
GATE_ASSURANCE_RUNS_FILE=""
if [[ -n "$GATE_RUN_DIR_OVERRIDE" && -n "$PMCTL_DISPATCH_LIB_DIR" ]]; then
  ASSURANCE_ATTESTATION_POINTER="gate-assurance-${TIMESTAMP}.attestation.json"
  ASSURANCE_ATTESTATION_FILE="$GATE_RUN_DIR_OVERRIDE/$ASSURANCE_ATTESTATION_POINTER"
  GATE_ASSURANCE_RUNS_FILE="$(
    # shellcheck source=runtime/lib/state-paths.sh
    . "$PMCTL_DISPATCH_LIB_DIR/state-paths.sh"
    cd "$WORK_DIR" || exit 1
    _SW_REPO_ROOT="$WORK_DIR" _sw_project_dir
  )runs.jsonl"
fi

_gate_assurance_destination_check() {
  local path="$1" nlink
  if [[ -L "$path" ]]; then
    printf 'Error: gate assurance destination must not be a symlink: %s\n' "$path" >&2
    return 1
  fi
  if [[ -e "$path" ]]; then
    if [[ ! -f "$path" ]]; then
      printf 'Error: gate assurance destination must be a regular file: %s\n' "$path" >&2
      return 1
    fi
    if nlink="$(stat -c '%h' "$path" 2>/dev/null)"; then
      :
    elif nlink="$(stat -f '%l' "$path" 2>/dev/null)"; then
      :
    else
      printf 'Error: unable to inspect gate assurance destination link count: %s\n' \
        "$path" >&2
      return 1
    fi
    if [[ ! "$nlink" =~ ^[0-9]+$ || "$nlink" -ne 1 ]]; then
      printf 'Error: gate assurance destination must not be hardlinked: %s\n' \
        "$path" >&2
      return 1
    fi
  fi
}

if [[ -n "$INITIAL_RESULT_RESOLVED" \
    && ( "$OUTPUT_FILE" == "$INITIAL_RESULT_RESOLVED" \
      || ( -e "$OUTPUT_FILE" && "$OUTPUT_FILE" -ef "$INITIAL_RESULT_RESOLVED" ) ) ]]; then
  printf 'Error: --output must not overwrite the referenced --initial-result: %s\n' \
    "$INITIAL_RESULT_RESOLVED" >&2
  exit 2
fi
if [[ -n "$INITIAL_RESULT_RESOLVED" \
    && ( "$ASSURANCE_FILE" == "$INITIAL_RESULT_RESOLVED" \
      || ( -e "$ASSURANCE_FILE" && "$ASSURANCE_FILE" -ef "$INITIAL_RESULT_RESOLVED" ) ) ]]; then
  printf 'Error: the assurance sidecar must not overwrite the referenced --initial-result: %s\n' \
    "$INITIAL_RESULT_RESOLVED" >&2
  exit 2
fi
_gate_assurance_destination_check "$ASSURANCE_FILE" || exit 2
GATE_OUTPUT_EXISTED=false
[[ -e "$OUTPUT_FILE" ]] && GATE_OUTPUT_EXISTED=true
touch "$OUTPUT_FILE"

# Track all brief files for EXIT cleanup
BRIEF_FILES=()
REVIEWER_DEFINITION_DIR=""
cleanup_briefs() {
  # Every executor now dispatches a subprocess (codex `codex exec`, claude headless
  # `claude --print`), so generated briefs are always transient and cleaned on exit.
  for bf in "${BRIEF_FILES[@]:-}"; do
    rm -f "$bf"
  done
  if [[ -n "${REVIEWER_DEFINITION_DIR:-}" ]]; then
    rm -rf -- "$REVIEWER_DEFINITION_DIR"
    rmdir "$WORK_DIR/.gate-briefs" 2>/dev/null || true
  fi
  rm -rf -- "${GATE_ASSURANCE_CAPTURE_DIR:-}"
}

# Relocate gate result artifacts out of the repo when a run dir was supplied.
# OUTPUT_FILE (and parallel reviewer outputs) must be written under WORK_DIR for the
# executor's workspace-write sandbox, so they start repo-local. This helper moves them
# to $GATE_RUN_DIR_OVERRIDE/.gate-results and drops the now-empty in-repo dir.
# Idempotent and safe to call repeatedly:
#   - no-op in legacy mode (no --run-dir) or with an explicit --output override, so the
#     in-repo default path and verbatim --output behavior are preserved (backward compat);
#   - no-op once WORK_DIR/.gate-results has been drained.
# Called BOTH on the success path (before the result: print, so the printed path and the
# NO-GO grep read the relocated copy) AND from the EXIT trap (so every failure path that
# already created the in-repo result relocates it out instead of leaking repo artifacts).
relocate_gate_artifacts() {
  [[ -n "$GATE_RUN_DIR_OVERRIDE" && -z "$OUTPUT_OVERRIDE" ]] || return 0
  [[ -d "$WORK_DIR/.gate-results" ]] || return 0
  local _result_dest_dir="$GATE_RUN_DIR_OVERRIDE/.gate-results" _rf
  mkdir -p "$_result_dest_dir"
  # Move only this run's artifacts (all carry $TIMESTAMP in the filename) so a concurrent
  # gate run sharing WORK_DIR/.gate-results keeps its own in-flight files.
  for _rf in "$WORK_DIR/.gate-results/"*"${TIMESTAMP}"*; do
    [[ -e "$_rf" ]] || continue
    mv "$_rf" "$_result_dest_dir/"
  done
  # Repoint OUTPUT_FILE to the relocated primary result so later reads (result: print,
  # NO-GO grep) follow it out of the repo.
  if [[ "$OUTPUT_FILE" == "$WORK_DIR/.gate-results/"* ]]; then
    OUTPUT_FILE="$_result_dest_dir/$(basename "$OUTPUT_FILE")"
  fi
  # Drop the in-repo dir only if now empty (tolerate a concurrent run's files).
  rmdir "$WORK_DIR/.gate-results" 2>/dev/null || true
}

gate_exit_cleanup() {
  # Relocate first (preserves the result artifact out-of-repo for post-mortem on failure
  # paths), then drop transient briefs. Both are idempotent / no-ops on the success path
  # where relocation already ran inline.
  if [[ "$GATE_CANCELLED" == true ]]; then
    # Cancellation is an operation terminal, not a reviewer verdict.  Do not
    # publish an empty/partial result that a later consumer could mistake for a
    # late gate outcome; operation state remains the cancellation evidence.
    rm -f -- "$WORK_DIR/.gate-results/"*"${TIMESTAMP}"* 2>/dev/null || true
    if [[ "$GATE_OUTPUT_EXISTED" != true ]]; then
      rm -f -- "$OUTPUT_FILE"
    fi
    rmdir "$WORK_DIR/.gate-results" 2>/dev/null || true
  else
    relocate_gate_artifacts
  fi
  cleanup_briefs
}
trap gate_exit_cleanup EXIT

gate_finalize_assurance() {
  local result_file="$1" assurance_file="$2"
  local final requested_json outcomes_json independence_status implementation_isolated
  local per_reviewer_independent expected_count capture_count assurance_tmp result_tmp
  local result_sha assurance_sha attestation_tmp run_ids_json attestation_pointer
  local -a capture_files=()

  final="$(grep -E '^Final: (GO|NO-GO)$' "$result_file" | awk '{print $2}')"
  [[ -n "$final" ]] || {
    printf 'Error: cannot finalize gate assurance without a unique final verdict\n' >&2
    return 1
  }
  if [[ -n "$REVIEWERS_OVERRIDE" ]]; then
    requested_json="$(jq -nc --arg reviewers "$REVIEWERS" \
      '$reviewers | split(" ") | map(select(length > 0))')"
  else
    requested_json=null
  fi

  while IFS= read -r _capture_file; do
    capture_files+=("$_capture_file")
  done < <(find "$GATE_ASSURANCE_CAPTURE_DIR" -maxdepth 1 -type f -name '*.json' -print | LC_ALL=C sort)
  capture_count="${#capture_files[@]}"

  if [[ "$PREFLIGHT_STATUS" == fail ]]; then
    outcomes_json='[{"role":"preflight","reviewer":null,"status":"failed","run_id":null,"evidence_status":"unavailable"}]'
    independence_status=unavailable
    implementation_isolated=null
    per_reviewer_independent=null
  elif [[ -n "$PMCTL_DISPATCH_LIB_DIR" \
      && -n "$ASSURANCE_ATTESTATION_FILE" \
      && -n "$GATE_ASSURANCE_RUNS_FILE" ]]; then
    if [[ "$SEQUENTIAL" == true ]]; then expected_count=1; else expected_count=$((NUM_REVIEWERS + 1)); fi
    if [[ "$capture_count" -ne "$expected_count" ]]; then
      printf 'Error: gate dispatch evidence incomplete (expected %d capture(s), found %d)\n' \
        "$expected_count" "$capture_count" >&2
      return 1
    fi
    outcomes_json="$(jq -s '.' "${capture_files[@]}")" || return 1
    independence_status=verified
    implementation_isolated=true
    if [[ "$SEQUENTIAL" == true ]]; then
      per_reviewer_independent=false
    else
      per_reviewer_independent=true
    fi
  else
    independence_status=unavailable
    implementation_isolated=null
    per_reviewer_independent=null
    if [[ "$SEQUENTIAL" == true ]]; then
      outcomes_json='[{"role":"combined","reviewer":null,"status":"passed","run_id":null,"evidence_status":"unavailable"}]'
    else
      outcomes_json="$(jq -nc --arg reviewers "$REVIEWERS" '
        ($reviewers | split(" ") | map(select(length > 0))) as $selected |
        ([$selected[] | {role:"reviewer",reviewer:.,status:"passed",run_id:null,
          evidence_status:"unavailable"}] +
         [{role:"synthesis",reviewer:null,status:"passed",run_id:null,
          evidence_status:"unavailable"}])')"
    fi
  fi
  attestation_pointer=""
  if [[ "$independence_status" == verified ]]; then
    attestation_pointer="$ASSURANCE_ATTESTATION_POINTER"
  fi

  result_tmp="$(mktemp "${result_file}.assurance-tmp.XXXXXX")" || {
    printf 'Error: unable to create gate result temporary file beside: %s\n' \
      "$result_file" >&2
    return 1
  }
  awk -v pointer="$ASSURANCE_POINTER" '
    /^---$/ {
      fence++
      print
      next
    }
    fence == 1 && /^gate_result_version:/ {
      print "gate_result_version: pr_gate_result_v2"
      print "gate_assurance: " pointer
      next
    }
    fence == 1 && /^gate_assurance:/ { next }
    { print }
  ' "$result_file" > "$result_tmp" || {
    rm -f -- "$result_tmp"
    return 1
  }
  result_sha="$(_gate_result_sha256_file "$result_tmp")" || {
    rm -f -- "$result_tmp"
    return 1
  }

  assurance_tmp="$(mktemp "${assurance_file}.tmp.XXXXXX")" || {
    rm -f -- "$result_tmp"
    printf 'Error: unable to create gate assurance temporary file beside: %s\n' \
      "$assurance_file" >&2
    return 1
  }
  if ! jq -n \
    --arg final "$final" \
    --arg result_sha "$result_sha" \
    --arg repo_root "$WORK_DIR" --arg repo_identity "$GATE_BINDING_REPO_IDENTITY" \
    --arg base_commit "$GATE_BINDING_BASE_COMMIT" \
    --arg head_commit "$GATE_BINDING_HEAD_COMMIT" \
    --arg subject_fingerprint "$GATE_BINDING_SUBJECT_FINGERPRINT" \
    --arg tier_requested "$TIER_REQUESTED" --arg tier_resolved "$TIER_RESOLVED" \
    --arg evidence_floor "$TIER_EVIDENCE_FLOOR" \
    --arg mode_requested "$MODE_REQUESTED" --arg mode_resolved "$MODE_RESOLVED" \
    --arg topology "$MODE_TOPOLOGY" --arg synthesis "$MODE_SYNTHESIS" \
    --arg pass_requested "$PASS_KIND_REQUESTED" --arg pass_resolved "$PASS_KIND_RESOLVED" \
    --arg pass_scope "$PASS_SCOPE" --arg initial_result "$INITIAL_RESULT_RESOLVED" \
    --arg selected "$REVIEWERS" --arg skipped "$SKIPPED_WORDS" \
    --arg vocabulary "$ALL_REVIEWERS" \
    --arg reviewer_topology "$MODE_TOPOLOGY" \
    --arg independence_status "$independence_status" \
    --arg policy_source "$GATE_ASSURANCE_POLICY_SOURCE" \
    --arg attestation "$attestation_pointer" \
    --argjson requested "$requested_json" --argjson outcomes "$outcomes_json" \
    --argjson policy_resolution "$GATE_POLICY_RESOLUTION" \
    --argjson implementation_isolated "$implementation_isolated" \
    --argjson per_reviewer_independent "$per_reviewer_independent" '
      {
        kind:"gate_assurance_v2",schema_version:2,
        result:{final:$final},
        bindings:{
          result_sha256:$result_sha,
          repo_root:$repo_root,
          repo_identity:$repo_identity,
          base_commit:$base_commit,
          head_commit:$head_commit,
          subject_fingerprint:$subject_fingerprint
        },
        coordinates:{
          tier:{requested:$tier_requested,resolved:$tier_resolved,
            evidence_floor:$evidence_floor},
          mode:{requested:$mode_requested,resolved:$mode_resolved,
            topology:$topology,synthesis:$synthesis},
          pass:{requested:$pass_requested,resolved:$pass_resolved,scope:$pass_scope,
            initial_result:(if $initial_result == "" then null else $initial_result end)},
          coverage:{
            requested:$requested,
            selected:($selected | split(" ") | map(select(length > 0))),
            skipped:($skipped | split(" ") | map(select(length > 0))),
            vocabulary:($vocabulary | split(" ") | map(select(length > 0)))
          },
          independence:{
            implementation_context_isolated:$implementation_isolated,
            reviewer_topology:$reviewer_topology,
            per_reviewer_independent:$per_reviewer_independent,
            evidence_status:$independence_status
          }
        },
        policy:$policy_resolution,
        dispatch:{outcomes:$outcomes},
        provenance:{
          producer:"pr-gate.sh",
          policy_source:$policy_source,
          attestation:(if $attestation == "" then null else $attestation end)
        }
      }' > "$assurance_tmp"; then
    rm -f -- "$assurance_tmp" "$result_tmp"
    return 1
  fi

  _gate_assurance_destination_check "$assurance_file" || {
    rm -f -- "$assurance_tmp" "$result_tmp"
    return 1
  }
  # Publish the sidecar before the v2 result that references it. A verifier
  # racing this boundary sees either the original self-contained v1 result or
  # the complete v2 pair; a host failure cannot strand a v2 result with a
  # permanently missing sidecar.
  mv -- "$assurance_tmp" "$assurance_file" || {
    rm -f -- "$assurance_tmp" "$result_tmp"
    return 1
  }
  mv -- "$result_tmp" "$result_file" || {
    rm -f -- "$result_tmp"
    return 1
  }
  gate_result_verify "$result_file" "" "machine assurance finalization" || return $?

  if [[ "$independence_status" == verified ]]; then
    assurance_sha="$(_gate_result_sha256_file "$assurance_file")" || return $?
    run_ids_json="$(jq -c '[.[].run_id]' <<<"$outcomes_json")" || return 1
    _gate_assurance_destination_check "$ASSURANCE_ATTESTATION_FILE" || return 1
    attestation_tmp="$(mktemp "${ASSURANCE_ATTESTATION_FILE}.tmp.XXXXXX")" || {
      printf 'Error: unable to create protected gate assurance attestation\n' >&2
      return 1
    }
    if ! jq -n \
      --arg result_sha "$result_sha" --arg assurance_sha "$assurance_sha" \
      --arg repo_root "$WORK_DIR" --arg repo_identity "$GATE_BINDING_REPO_IDENTITY" \
      --arg base_commit "$GATE_BINDING_BASE_COMMIT" \
      --arg head_commit "$GATE_BINDING_HEAD_COMMIT" \
      --arg subject_fingerprint "$GATE_BINDING_SUBJECT_FINGERPRINT" \
      --argjson run_ids "$run_ids_json" '{
        kind:"gate_assurance_attestation_v1",
        schema_version:1,
        result_sha256:$result_sha,
        assurance_sha256:$assurance_sha,
        repo_root:$repo_root,
        repo_identity:$repo_identity,
        base_commit:$base_commit,
        head_commit:$head_commit,
        subject_fingerprint:$subject_fingerprint,
        run_ids:$run_ids
      }' > "$attestation_tmp"; then
      rm -f -- "$attestation_tmp"
      return 1
    fi
    mv -- "$attestation_tmp" "$ASSURANCE_ATTESTATION_FILE" || {
      rm -f -- "$attestation_tmp"
      return 1
    }
    gate_assurance_authorization_verify "$result_file" "$assurance_file" \
      "$ASSURANCE_ATTESTATION_FILE" "$GATE_ASSURANCE_RUNS_FILE"
  fi
}

SYNTHESIS_BRIEF="$BRIEF_DIR/pr-gate-${TIMESTAMP}-synthesis.md"
BRIEF_FILES+=("$SYNTHESIS_BRIEF")

# Build a compact index of verified reference files (agents/, commands/, docs/, skills/)
# for injection into gate brief preambles. Reviewers may cite docs/sections
# that don't exist; the index provides ground truth so they can verify before citing.
_build_repo_ref_index() {
  local work_dir="$1" out=""
  for d in agents commands docs skills; do
    [[ -d "$work_dir/$d" ]] || continue
    while IFS= read -r f; do
      out="${out}    ${f#"$work_dir/"}"$'\n'
    done < <(find "$work_dir/$d" -maxdepth 2 -name "*.md" 2>/dev/null | sort)
  done
  printf '%s' "$out"
}


# ── Find adjacent test files not in the diff ─────────────────────────────────
# For each changed source file, locate its companion test file if it exists and
# is not already included in the diff. Including adjacent tests allows reviewers
# to detect coverage gaps in unchanged test files alongside changed source.
#
# Go:         <pkg>/<name>.go       → <pkg>/<name>_test.go
# TypeScript: <dir>/<name>.ts(x)    → <dir>/__tests__/<name>.test.ts(x)
#                                   → <dir>/<name>.test.ts(x)
ADJACENT_TEST_FILES=""
while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  case "$f" in
    *.go)
      base="$(basename "$f")"
      if [[ "$base" != *_test.go ]]; then
        testfile="${f%.go}_test.go"
        if [[ -f "$WORK_DIR/$testfile" ]] && ! printf '%s\n' "$DIFF_FILES" | grep -qxF "$testfile"; then
          ADJACENT_TEST_FILES="${ADJACENT_TEST_FILES}${testfile}"$'\n'
        fi
      fi
      ;;
    *.ts|*.tsx)
      base="$(basename "$f")"
      case "$base" in *.test.ts|*.test.tsx|*.spec.ts|*.spec.tsx) continue ;; esac
      bname="${base%.*}"
      dname="$(dirname "$f")"
      for candidate in \
          "${dname}/__tests__/${bname}.test.ts" \
          "${dname}/__tests__/${bname}.test.tsx" \
          "${dname}/__tests__/${bname}.spec.ts" \
          "${dname}/__tests__/${bname}.spec.tsx" \
          "${dname}/${bname}.test.ts" \
          "${dname}/${bname}.test.tsx" \
          "${dname}/${bname}.spec.ts" \
          "${dname}/${bname}.spec.tsx"; do
        if [[ -f "$WORK_DIR/$candidate" ]] && ! printf '%s\n' "$DIFF_FILES" | grep -qxF "$candidate"; then
          ADJACENT_TEST_FILES="${ADJACENT_TEST_FILES}${candidate}"$'\n'
        fi
      done
      ;;
  esac
done <<< "$DIFF_FILES"

# ── Build combined review file list ──────────────────────────────────────────
ALL_REVIEW_FILES="$DIFF_FILES"
if [[ -n "$ADJACENT_TEST_FILES" ]]; then
  ALL_REVIEW_FILES="$(printf '%s\n%s' "$ALL_REVIEW_FILES" "$ADJACENT_TEST_FILES" | sort -u | grep -v '^$')"
fi

DIFF_FILE_ENTRIES=""
while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  fp="$WORK_DIR/$f"
  [[ -f "$fp" ]] && DIFF_FILE_ENTRIES="${DIFF_FILE_ENTRIES}  - read: ${fp}"$'\n'
done <<< "$ALL_REVIEW_FILES"

DIFF_STAT_INDENTED=$(printf '%s\n' "$DIFF_STAT" | sed 's/^/    /')
REPO_REF_INDEX="$(_build_repo_ref_index "$WORK_DIR")"
ADJ_COUNT=$(printf '%s\n' "$ADJACENT_TEST_FILES" | grep -c '[^[:space:]]' 2>/dev/null || true)

# Render the accepted-risk override context block injected into EVERY reviewer
# and synthesis brief. Single source of truth: all three brief templates
# (sequential, parallel reviewer, parallel synthesis) reference the one
# ${GATE_OVERRIDES_CONTEXT_BLOCK} this produces, so an override-rendering change
# lands in exactly one place. Emits the empty string when there are no overrides.
# (render_test_evidence_block() below follows this same single-source-of-truth
# shape for the pre-flight test evidence block -- see CC-470 Part 3.)
render_gate_overrides_block() {
  local content="$1" indented
  [[ -z "$content" ]] && return 0
  indented=$(printf '%s\n' "$content" | sed 's/^/  /')
  printf '  Accepted-risk overrides (do NOT re-block these unless the diff materially\n  changes the accepted risk -- re-raising an already-accepted override when the\n  code has not changed is a false-positive that must be suppressed):\n%s\n' "$indented"
}

# Pre-format the override block for heredoc injection (empty when no overrides).
GATE_OVERRIDES_CONTEXT_BLOCK="$(render_gate_overrides_block "$GATE_OVERRIDES_CONTENT")"

INITIAL_RESULT_DISPLAY="${INITIAL_RESULT_RESOLVED:-none}"
POLICY_REQUIRED_REVIEWERS_DISPLAY="$(jq -r \
  '.resolution.required_reviewers | if length == 0 then "none" else join(",") end' \
  <<<"$GATE_POLICY_RESOLUTION")"
POLICY_MODE_SELECTION_SOURCE="$(jq -r '.resolution.mode_selection_source' \
  <<<"$GATE_POLICY_RESOLUTION")"
POLICY_MODE_RECOMMENDATION_OVERRIDDEN="$(jq -r \
  '.resolution.mode_recommendation_overridden' <<<"$GATE_POLICY_RESOLUTION")"
POLICY_ESCALATION_SIGNALS_DISPLAY="$(jq -c '[
  .matched_signals[]
  | select(.source != "consumer-policy")
  | select((.required_reviewers | length) > 0 or .recommended_mode == "parallel")
  | {
      id,
      required_reviewers,
      recommended_mode
    }
]' <<<"$GATE_POLICY_RESOLUTION")"
printf -v GATE_ASSURANCE_CONTEXT_BLOCK \
  '  Assurance coordinates (resolved by the gate shell; do not reinterpret):\n    tier.requested: %s\n    tier.resolved: %s\n    tier.evidence_floor: %s\n    mode.requested: %s\n    mode.resolved: %s\n    mode.topology: %s\n    mode.synthesis: %s\n    mode.selection_source: %s\n    mode.recommendation_overridden: %s\n    pass.requested: %s\n    pass.resolved: %s\n    pass.scope: %s\n    pass.initial_result: %s\n    coverage.requested: %s\n    coverage.selected: %s\n    coverage.skipped: %s\n    policy.consumer: %s\n    policy.minimum_tier: %s\n    policy.required_reviewers: %s\n    policy.recommended_mode: %s\n    policy.escalation_signals: %s\n    policy.scope_fingerprint: %s\n    policy.source: %s\n' \
  "$TIER_REQUESTED" "$TIER_RESOLVED" "$TIER_EVIDENCE_FLOOR" \
  "$MODE_REQUESTED" "$MODE_RESOLVED" "$MODE_TOPOLOGY" "$MODE_SYNTHESIS" \
  "$POLICY_MODE_SELECTION_SOURCE" "$POLICY_MODE_RECOMMENDATION_OVERRIDDEN" \
  "$PASS_KIND_REQUESTED" "$PASS_KIND_RESOLVED" "$PASS_SCOPE" "$INITIAL_RESULT_DISPLAY" \
  "$COVERAGE_REQUESTED_DISPLAY" \
  "$COVERAGE_SELECTED_DISPLAY" "$COVERAGE_SKIPPED_DISPLAY" \
  "$POLICY_CONSUMER" "$(jq -r '.resolution.minimum_tier' <<<"$GATE_POLICY_RESOLUTION")" \
  "$POLICY_REQUIRED_REVIEWERS_DISPLAY" \
  "$(jq -r '.resolution.recommended_mode' <<<"$GATE_POLICY_RESOLUTION")" \
  "$POLICY_ESCALATION_SIGNALS_DISPLAY" \
  "$POLICY_SCOPE_FINGERPRINT" \
  "$GATE_ASSURANCE_POLICY_SOURCE"

say 'pr-gate: tier %s -> %s; mode %s -> %s; pass %s -> %s\n' \
  "$TIER_REQUESTED" "$TIER_RESOLVED" "$MODE_REQUESTED" "$MODE_RESOLVED" \
  "$PASS_KIND_REQUESTED" "$PASS_KIND_RESOLVED"
say 'pr-gate: coverage requested=%s selected=%s skipped=%s; policy=%s/%s\n' \
  "$COVERAGE_REQUESTED_DISPLAY" "$COVERAGE_SELECTED_DISPLAY" \
  "$COVERAGE_SKIPPED_DISPLAY" "$POLICY_CONSUMER" "$GATE_ASSURANCE_POLICY_SOURCE"
say 'pr-gate: policy minimum-tier=%s required-reviewers=%s recommended-mode=%s mode-source=%s recommendation-overridden=%s scope=%s\n' \
  "$(jq -r '.resolution.minimum_tier' <<<"$GATE_POLICY_RESOLUTION")" \
  "$POLICY_REQUIRED_REVIEWERS_DISPLAY" \
  "$(jq -r '.resolution.recommended_mode' <<<"$GATE_POLICY_RESOLUTION")" \
  "$POLICY_MODE_SELECTION_SOURCE" "$POLICY_MODE_RECOMMENDATION_OVERRIDDEN" \
  "$POLICY_SCOPE_FINGERPRINT"
[[ "${ADJ_COUNT:-0}" -gt 0 ]] && say '  adjacent test files added: %d\n' "$ADJ_COUNT"
say 'result will be written to: %s\n\n' "$OUTPUT_FILE"

# ── Pre-gate hook ──────────────────────────────────────────────────────────
_PRE_GATE_HOOK="$WORK_DIR/.pm-dispatch/pre-gate.sh"
if [[ "$ALLOW_HOOKS" != "true" ]]; then
  if [[ -f "$_PRE_GATE_HOOK" ]]; then
    printf 'Warning: .pm-dispatch/pre-gate.sh present but skipped -- pass --allow-hooks to execute repo-local hook scripts\n' >&2
  fi
elif [[ -f "$_PRE_GATE_HOOK" && ! -x "$_PRE_GATE_HOOK" ]]; then
  printf 'Warning: .pm-dispatch/pre-gate.sh exists but is not executable -- skipping\n' >&2
elif [[ -x "$_PRE_GATE_HOOK" ]]; then
  say 'Running pre-gate hook: .pm-dispatch/pre-gate.sh\n'
  if ! (cd "$WORK_DIR" && bash "$_PRE_GATE_HOOK"); then
    printf 'Error: pre-gate hook failed -- gate aborted\n' >&2
    exit 1
  fi
  say 'pre-gate hook completed.\n\n'
fi

# ── Pre-flight test suite (mechanical, decoupled from reviewer --timeout budget) ──
# Runs BEFORE any dispatch, in plain bash, with its own independent timeout
# (--test-timeout, default 1800s) -- however long the target repo's test suite
# takes, it can never cause a reviewer session to hit --timeout, because it has
# already finished by the time dispatch starts. Shared by both sequential and
# --parallel modes (computed once here, injected into whichever brief(s) follow).
# A FAIL short-circuits dispatch entirely (see the fail-fast branch below) --
# reviewing code that is already guaranteed NO-GO wastes reviewer tokens for
# no benefit. A PASS is tagged onto the real dispatch result afterward
# (gate_apply_preflight_pass_tag). Either way this is enforced mechanically,
# NOT by asking a reviewer LLM to correctly interpret and relay it. See
# CC-470 Part 3.
PREFLIGHT_STATUS="skipped"
PREFLIGHT_LOG_PATH=""
PREFLIGHT_EVIDENCE_PATH=""
PREFLIGHT_EVIDENCE_DIGEST=""
PREFLIGHT_RICH_RESULT_PATH=""

# relocate_gate_artifacts() (below) moves everything under $WORK_DIR/.gate-results
# carrying $TIMESTAMP -- including the pre-flight log -- out to $GATE_RUN_DIR_OVERRIDE
# AFTER dispatch completes. Any log path baked into persisted text (the brief's
# evidence block, the mechanical override note in the result body) must point at
# where the file will actually BE by the time a human reads it, not where it
# started -- otherwise --run-dir runs leave a stale pointer into a directory the
# EXIT trap already emptied. This mirrors relocate_gate_artifacts' own
# OUTPUT_FILE-repointing logic (same condition) without needing to relocate the
# log file itself any earlier than dispatch allows.
_preflight_log_display_path() {
  local path="$1"
  if [[ -n "$path" && -n "$GATE_RUN_DIR_OVERRIDE" && -z "$OUTPUT_OVERRIDE" ]]; then
    printf '%s/.gate-results/%s' "$GATE_RUN_DIR_OVERRIDE" "$(basename "$path")"
  else
    printf '%s' "$path"
  fi
}

_preflight_sha256_file() {
  local file="$1" digest=""
  if command -v sha256sum >/dev/null 2>&1 \
      && digest="$(sha256sum -- "$file" 2>/dev/null | awk '{print $1}')" \
      && [[ -n "$digest" ]]; then
    printf '%s\n' "$digest"
    return 0
  fi
  if command -v shasum >/dev/null 2>&1 \
      && digest="$(shasum -a 256 -- "$file" 2>/dev/null | awk '{print $1}')" \
      && [[ -n "$digest" ]]; then
    printf '%s\n' "$digest"
    return 0
  fi
  printf 'Error: no sha256sum or shasum found -- cannot fingerprint gate inputs.\n' >&2
  return 2
}

# Copy-mode portable content identity. It binds tracked and non-ignored
# untracked content (including executable bits and symlink targets), while
# excluding only gate-owned runtime artifacts created by this invocation.
_preflight_tree_fingerprint() {
  local manifest path quoted kind executable digest
  manifest="$(mktemp "${TMPDIR:-/tmp}/pr-gate-tree.XXXXXX")" || return 2
  while IFS= read -r -d '' path; do
    case "$path" in
      .agent-trace|.agent-trace/*|.gate-briefs|.gate-briefs/*|.gate-results|.gate-results/*) continue ;;
    esac
    quoted="$(printf '%q' "$path")"
    if [[ -L "$WORK_DIR/$path" ]]; then
      kind=symlink; executable=false
      digest="$(printf '%s' "$(readlink "$WORK_DIR/$path")" | _gate_sha256_stream)" || { rm -f "$manifest"; return 2; }
    elif [[ -f "$WORK_DIR/$path" ]]; then
      kind=file; [[ -x "$WORK_DIR/$path" ]] && executable=true || executable=false
      digest="$(_preflight_sha256_file "$WORK_DIR/$path")" || { rm -f "$manifest"; return 2; }
    else
      kind=missing; executable=false; digest=-
    fi
    printf '%s\t%s\t%s\t%s\n' "$quoted" "$kind" "$executable" "$digest" >> "$manifest"
  done < <(git -C "$WORK_DIR" ls-files --cached --others --exclude-standard -z)
  LC_ALL=C sort "$manifest" | _gate_sha256_stream
  local rc=$?
  rm -f "$manifest"
  return "$rc"
}

_preflight_repo_identity() {
  local remote
  remote="$(git -C "$WORK_DIR" config --get remote.origin.url 2>/dev/null || true)"
  printf '%s\n%s\n' "$WORK_DIR" "$remote" | _gate_sha256_stream
}

GATE_BINDING_SUBJECT_FINGERPRINT="$(_preflight_tree_fingerprint)" || exit 2
GATE_BINDING_REPO_IDENTITY="$(_preflight_repo_identity)" || exit 2
GATE_BINDING_BASE_COMMIT="$(git rev-parse "${BASE}^{commit}")" || exit 2
GATE_BINDING_HEAD_COMMIT="$(git rev-parse "${HEAD_REF}^{commit}")" || exit 2

if [[ "$SKIP_PREFLIGHT_TESTS" != "true" && -n "$TEST_CMD_OVERRIDE" ]]; then
  # pr-gate.sh is designed to be copied standalone into any repo (copy-mode --
  # see the file header), so it must not hardcode any repo-specific test
  # command or path convention. --test-cmd is the ONLY way to opt in: the
  # caller (a human, or the /pr-gate skill, which already knows this repo's
  # own convention) supplies it explicitly for this invocation -- that
  # explicit act IS the consent, so no additional --allow-hooks gate applies
  # (contrast with .pm-dispatch/pre-gate.sh above, whose content is arbitrary
  # and repo-supplied, not operator-supplied).
  mkdir -p "$WORK_DIR/.gate-results"
  PREFLIGHT_LOG_PATH="$WORK_DIR/.gate-results/preflight-tests-${TIMESTAMP}.log"
  PREFLIGHT_EVIDENCE_PATH="$WORK_DIR/.gate-results/preflight-evidence-${TIMESTAMP}.json"
  PREFLIGHT_RICH_RESULT_PATH="$WORK_DIR/.gate-results/preflight-rich-result-${TIMESTAMP}.json"
  _preflight_command_digest="$(printf '%s' "$TEST_CMD_OVERRIDE" | _gate_sha256_stream)" || exit 2
  _preflight_before="$GATE_BINDING_SUBJECT_FINGERPRINT"
  _preflight_repo_id="$GATE_BINDING_REPO_IDENTITY"
  _preflight_base_commit="$GATE_BINDING_BASE_COMMIT"
  _preflight_head_commit="$GATE_BINDING_HEAD_COMMIT"
  _preflight_started="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
  say 'pr-gate: running pre-flight test suite (timeout %ss, command sha256:%s)\n' \
    "$TEST_TIMEOUT" "${_preflight_command_digest:0:12}"
  _preflight_rc=0
  if [[ -n "${PM_GATE_PARENT_OPERATION:-}" ]]; then
    _detached_launch_lib="$SCRIPT_DIR/../lib/detached-launch.sh"
    if ! declare -F detached_launch_kill_process_group >/dev/null 2>&1; then
      # shellcheck disable=SC1090,SC1091 # resolved repo-relative runtime library.
      [[ -r "$_detached_launch_lib" ]] && . "$_detached_launch_lib"
    fi
    declare -F detached_launch_kill_process_group >/dev/null 2>&1 || {
      printf 'Error: operation-owned pre-flight cleanup helper is unavailable\n' >&2
      exit 2
    }
    command -v setsid >/dev/null 2>&1 || {
      printf 'Error: operation-owned pre-flight isolation requires setsid\n' >&2
      exit 2
    }
    (
      cd "$WORK_DIR"
      export PM_DISPATCH_PREFLIGHT_TEST_RESULT="$PREFLIGHT_RICH_RESULT_PATH"
      export PM_DISPATCH_PREFLIGHT_SUBJECT_FINGERPRINT="$_preflight_before"
      export PM_DISPATCH_PREFLIGHT_BASE_COMMIT="$_preflight_base_commit"
      export PM_DISPATCH_PREFLIGHT_HEAD_COMMIT="$_preflight_head_commit"
      # The test command is a subject of this gate, not another producer owned
      # by the same parent operation.  Do not let nested pmctl/pr-gate fixtures
      # attach themselves to or infer ownership from the outer gate.
      unset PM_GATE_PARENT_OPERATION
      exec setsid timeout --kill-after=15 "$TEST_TIMEOUT" bash -c "$TEST_CMD_OVERRIDE"
    ) > "$PREFLIGHT_LOG_PATH" 2>&1 &
    GATE_ACTIVE_PREFLIGHT_PID=$!
    GATE_ACTIVE_PREFLIGHT_PGID=$!
    wait "$GATE_ACTIVE_PREFLIGHT_PID" || _preflight_rc=$?
    GATE_ACTIVE_PREFLIGHT_PID=""
    GATE_ACTIVE_PREFLIGHT_PGID=""
  else
    ( cd "$WORK_DIR" && PM_DISPATCH_PREFLIGHT_TEST_RESULT="$PREFLIGHT_RICH_RESULT_PATH" \
        PM_DISPATCH_PREFLIGHT_SUBJECT_FINGERPRINT="$_preflight_before" \
        PM_DISPATCH_PREFLIGHT_BASE_COMMIT="$_preflight_base_commit" \
        PM_DISPATCH_PREFLIGHT_HEAD_COMMIT="$_preflight_head_commit" \
        timeout --kill-after=15 "$TEST_TIMEOUT" bash -c "$TEST_CMD_OVERRIDE" ) \
      > "$PREFLIGHT_LOG_PATH" 2>&1 || _preflight_rc=$?
  fi
  _preflight_finished="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
  _preflight_after="$(_preflight_tree_fingerprint)" || exit 2
  _preflight_log_digest="$(_preflight_sha256_file "$PREFLIGHT_LOG_PATH")" || exit 2
  _preflight_status=fail
  [[ "$_preflight_rc" -eq 0 ]] && _preflight_status=pass
  [[ "$_preflight_rc" -eq 124 || "$_preflight_rc" -eq 137 ]] && _preflight_status=timeout
  if [[ "$_preflight_before" != "$_preflight_after" ]]; then
    _preflight_status=stale
  fi
  _preflight_coverage='{"type":"opaque","reuse_policy":"advisory"}'
  _preflight_rich_digest=""
  if [[ -s "$PREFLIGHT_RICH_RESULT_PATH" ]]; then
    _preflight_rich_digest="$(_preflight_sha256_file "$PREFLIGHT_RICH_RESULT_PATH")" || exit 2
    if jq -e --arg repo "$WORK_DIR" --arg repo_id "$_preflight_repo_id" \
      --arg tree_before "$_preflight_before" --arg tree_after "$_preflight_after" \
      --arg head "$_preflight_head_commit" --argjson rc "$_preflight_rc" '
        .kind == "pm_test_result_v2" and .schema_version == 2 and
        .repo_root == $repo and .repo_identity == $repo_id and
        .tree_fingerprint == $tree_before and .observed_tree_fingerprint_after == $tree_after and
        .head_commit == $head and .exit_code == $rc and
        (.runner_contract_hash | type == "string" and test("^[a-f0-9]{64}$")) and
        (.selection_mode | type == "string" and length > 0) and
        ((.changed_paths | type) == "array") and
        (.suite_set | type == "array" and length > 0) and
        ((.suite_results | type) == "array") and
        ((.suite_results | length) == (.suite_set | length)) and
        ([.suite_results[].name] == .suite_set) and
        (all(.suite_results[];
          (.name | type == "string" and length > 0) and
          (.status == "pass" or .status == "fail" or .status == "timeout" or .status == "skip") and
          (.exit_code | type == "number" and . >= 0 and floor == .) and
          (.duration_seconds | type == "number" and . >= 0 and floor == .))) and
        (.aggregate.status == .status) and
        (.aggregate.selected == (.suite_results | length)) and
        (.aggregate.passed == ([.suite_results[] | select(.status == "pass")] | length)) and
        (.aggregate.failed == ([.suite_results[] | select(.status == "fail")] | length)) and
        (.aggregate.timed_out == ([.suite_results[] | select(.status == "timeout")] | length)) and
        (.aggregate.skipped == ([.suite_results[] | select(.status == "skip")] | length)) and
        (($rc == 0 and .status == "pass") or ($rc != 0 and (.status == "fail" or .status == "stale")))
      ' "$PREFLIGHT_RICH_RESULT_PATH" >/dev/null 2>&1; then
      _preflight_coverage="$(jq -c --arg path "$(_preflight_log_display_path "$PREFLIGHT_RICH_RESULT_PATH")" \
        --arg digest "$_preflight_rich_digest" \
        '{type:"structured",reuse_policy:"no-duplicate-current-pass",
          artifact_path:$path,artifact_sha256:$digest,selection_mode,
          changed_paths,suite_set,suite_results,aggregate}' "$PREFLIGHT_RICH_RESULT_PATH")" || exit 2
    else
      _preflight_status=invalid
      _preflight_coverage="$(jq -nc --arg path "$(_preflight_log_display_path "$PREFLIGHT_RICH_RESULT_PATH")" \
        --arg digest "$_preflight_rich_digest" \
        '{type:"invalid",reuse_policy:"none",artifact_path:$path,artifact_sha256:$digest}')"
    fi
  fi
  _preflight_log_display="$(_preflight_log_display_path "$PREFLIGHT_LOG_PATH")"
  _preflight_evidence_display="$(_preflight_log_display_path "$PREFLIGHT_EVIDENCE_PATH")"
  jq -n --arg kind pr_gate_preflight_v1 --argjson schema_version 1 \
    --arg command_identity "sha256:${_preflight_command_digest}" --arg status "$_preflight_status" \
    --argjson exit_status "$_preflight_rc" --argjson timeout_seconds "$TEST_TIMEOUT" \
    --arg started_at "$_preflight_started" --arg finished_at "$_preflight_finished" \
    --arg repo_root "$WORK_DIR" --arg repo_identity "$_preflight_repo_id" \
    --arg base_ref "$BASE" --arg base_commit "$_preflight_base_commit" \
    --arg head_ref "$HEAD_REF" --arg head_commit "$_preflight_head_commit" \
    --arg tree_before "$_preflight_before" --arg tree_after "$_preflight_after" \
    --arg log_path "$_preflight_log_display" --arg log_sha256 "$_preflight_log_digest" \
    --argjson coverage "$_preflight_coverage" \
    '{kind:$kind,schema_version:$schema_version,command_identity:$command_identity,
      status:$status,exit_status:$exit_status,timeout_seconds:$timeout_seconds,
      started_at:$started_at,finished_at:$finished_at,
      subject:{kind:"workspace",reusable:true,
        fingerprint_before:$tree_before,fingerprint_after:$tree_after},
      provenance:{repo_root:$repo_root,repo_identity:$repo_identity,base_ref:$base_ref,
        base_commit:$base_commit,head_ref:$head_ref,head_commit:$head_commit,
        provider:"git"},
      log:{path:$log_path,sha256:$log_sha256},coverage:$coverage}' > "$PREFLIGHT_EVIDENCE_PATH" || exit 2
  jq -e '.kind == "pr_gate_preflight_v1" and .schema_version == 1 and
    (.command_identity | test("^sha256:[a-f0-9]{64}$")) and
    .subject.reusable == true and
    (.subject.fingerprint_before | test("^[a-f0-9]{64}$")) and
    (.subject.fingerprint_after | test("^[a-f0-9]{64}$")) and
    (.log.sha256 | test("^[a-f0-9]{64}$")) and
    (.coverage.type == "opaque" or .coverage.type == "structured" or .coverage.type == "invalid")' \
    "$PREFLIGHT_EVIDENCE_PATH" >/dev/null || { printf 'Error: invalid pre-flight evidence envelope\n' >&2; exit 2; }
  PREFLIGHT_EVIDENCE_DIGEST="$(_preflight_sha256_file "$PREFLIGHT_EVIDENCE_PATH")" || exit 2
  if [[ "$_preflight_status" == pass ]]; then PREFLIGHT_STATUS=pass; else PREFLIGHT_STATUS=fail; fi
  say 'pr-gate: pre-flight test suite: %s (evidence: %s)\n\n' "$_preflight_status" "$PREFLIGHT_EVIDENCE_PATH"
fi

# Best-effort redaction of common secret shapes before a failed pre-flight
# log excerpt is copied into a reviewer brief -- a non-hermetic test suite's
# stdout/stderr can legitimately contain API keys, bearer tokens, or
# password/token values from the environment it ran in. Mirrors the proven
# pattern in runtime/hooks/guard-pm-bash.sh's _redact_secrets (same threat: don't
# let secret-shaped substrings reach a place they get displayed/persisted).
# Not a complete secret scanner -- closes the common cases, not every one.
_preflight_redact_secrets() {
  # Reads from stdin (used as a pipe filter: `tail ... | _preflight_redact_secrets`),
  # not an argument -- an earlier version took "$1" here, which meant the
  # piped log content was silently discarded and the function only ever
  # processed an empty string. Caught by shellcheck (SC2119/SC2120) before ship.
  sed -E \
    -e 's/sk-[A-Za-z0-9_-]{16,}/***REDACTED***/g' \
    -e 's/gh[ps]_[A-Za-z0-9]{20,}/***REDACTED***/g' \
    -e 's/AKIA[0-9A-Z]{16}/***REDACTED***/g' \
    -e 's/([Bb]earer[[:space:]]+)[A-Za-z0-9._-]+/\1***REDACTED***/g' \
    -e 's/(-{0,2}[A-Za-z0-9][A-Za-z0-9_-]*)?([Pp]assword|[Tt]oken|[Ss]ecret|[Cc]redential|[Aa][Pp][Ii]_?[Kk][Ee][Yy])([A-Za-z0-9_-]*)([=:[:space:]])[^[:space:]]+/\1\2\3\4***REDACTED***/g'
}

# Render the pre-flight evidence block for brief injection. Informational
# context only for reviewers -- NOT the enforcement mechanism (see above).
render_test_evidence_block() {
  local status="$1" log_path="$2" tail display_path evidence_display coverage_type
  [[ "$status" == "skipped" ]] && return 0
  evidence_display="$(_preflight_log_display_path "$PREFLIGHT_EVIDENCE_PATH")"
  coverage_type="$(jq -r '.coverage.type' "$PREFLIGHT_EVIDENCE_PATH")"
  printf '  Pre-flight evidence (machine-verified pr_gate_preflight_v1):\n'
  printf '    Status: %s\n    Artifact: %s\n    Artifact sha256: %s\n' "$status" "$evidence_display" "$PREFLIGHT_EVIDENCE_DIGEST"
  printf '    Subject fingerprint: %s\n    Coverage: %s (%s)\n' \
    "$(jq -r '.subject.fingerprint_before' "$PREFLIGHT_EVIDENCE_PATH")" "$coverage_type" \
    "$(jq -r '.coverage.reuse_policy' "$PREFLIGHT_EVIDENCE_PATH")"
  if [[ "$coverage_type" == structured ]]; then
    printf '    Selection mode: %s\n' "$(jq -r '.coverage.selection_mode' "$PREFLIGHT_EVIDENCE_PATH")"
    printf '    Changed paths: %s\n' "$(jq -r '.coverage.changed_paths | join(", ")' "$PREFLIGHT_EVIDENCE_PATH")"
    printf '    Selected suite results:\n'
    jq -r '.coverage.suite_results[] | "      - \(.name): \(.status) (exit=\(.exit_code), duration=\(.duration_seconds)s)"' "$PREFLIGHT_EVIDENCE_PATH"
  else
    printf '    Selected suites: unavailable (generic command coverage is opaque)\n'
    printf '    QA may run the minimum repo-native validation needed when behavioral coverage\n'
    printf '    cannot be established; record the gap, reason, command, and new evidence.\n'
  fi
  if [[ "$status" == "fail" && -n "$log_path" ]]; then
    # Read from the CURRENT (still in-repo) path -- relocation hasn't happened
    # yet at this point in the script -- but DISPLAY the path it will live at
    # once relocate_gate_artifacts moves it, so any reviewer that quotes this
    # verbatim into the persisted result doesn't leave a stale pointer.
    display_path="$(_preflight_log_display_path "$log_path")"
    printf '    Log: %s\n  Last ~40 lines (secret-shaped substrings redacted):\n' "$display_path"
    tail=$(tail -n 40 "$log_path" 2>/dev/null | _preflight_redact_secrets | sed 's/^/    /')
    printf '%s\n' "$tail"
  fi
  printf '  Evidence reuse contract:\n'
  printf '    - First map each behavioral unit in the diff to existing suite evidence above.\n'
  printf '    - Do not rerun a suite with current PASS evidence. Supplemental execution is allowed only\n'
  printf '      for an uncovered behavioral gap, stale/invalid evidence, or a concrete flake suspicion.\n'
  printf '    - Record every supplemental command, gap/reason, new artifact, and duplicate-suite count.\n'
  printf '      Use the repo runner selection/parallelism contract; do not use handwritten for/&& suite\n'
  printf '      lists and do not create test output in the source working tree.\n'
  printf '    - The qa-tester written section must include an Evidence Accounting block with: reused\n'
  printf '      artifact/suites, supplemental executions (gap, reason, command, artifact), and an exact\n'
  printf '      Duplicate suite count. Preserve this block even when the gate later becomes partial/timeout.\n'
}
TEST_EVIDENCE_CONTEXT_BLOCK="$(render_test_evidence_block "$PREFLIGHT_STATUS" "$PREFLIGHT_LOG_PATH")"

# Fail-fast: a failed pre-flight test run already determines Final: NO-GO
# mechanically (see _write_preflight_failure_result below) regardless of what
# any reviewer would say -- so dispatching 5 reviewer LLM sessions to review code that
# is guaranteed to be rejected anyway is pure wasted cost (token spend + wall
# clock) for a result that changes nothing. Skip dispatch entirely and
# synthesize the NO-GO result directly. If the pre-flight fix later turns out
# to also need a code-review pass, that happens on the NEXT gate run after the
# tests are fixed, not blocked from ever happening.
_write_preflight_failure_result() {
  local result_file="$1" log_path="$2" display_path reviewer_lines=""
  display_path="$(_preflight_log_display_path "$log_path")"
  local r
  for r in $REVIEWERS; do
    reviewer_lines="${reviewer_lines}  ${r}: skipped"$'\n'
  done
  local excerpt
  excerpt=$(tail -n 40 "$log_path" 2>/dev/null | _preflight_redact_secrets | sed 's/^/    /')
  cat > "$result_file" << PREFLIGHT_FAIL_EOF
---
gate_result_version: pr_gate_result_v1
final: NO-GO
tier: ${TIER}
mode: ${MODE_RESOLVED}
most_severe: block
reviewers:
${reviewer_lines}escalation:
  recommended: false
  reviewers: []
  reason: []
test_suite: fail
test_evidence: $(_preflight_log_display_path "$PREFLIGHT_EVIDENCE_PATH")
test_evidence_sha256: ${PREFLIGHT_EVIDENCE_DIGEST}
---

# PR-Gate Result -- pre-flight fail-fast (${EXECUTOR} mode)
**Date**: $(date '+%Y-%m-%d')
**Reviewers**: ${REVIEWER_DISPLAY}
**Not reviewed**: all (pre-flight test suite failed; reviewer dispatch was skipped)

## Pre-flight Test Failure
The pre-flight test command failed before any reviewer was dispatched.
Full log: ${display_path}
Evidence artifact: $(_preflight_log_display_path "$PREFLIGHT_EVIDENCE_PATH")
Evidence sha256: ${PREFLIGHT_EVIDENCE_DIGEST}
Last ~40 lines (secret-shaped substrings redacted):
${excerpt}

Reviewer dispatch was skipped because a failing test suite already
determines this gate's outcome -- fixing the tests is required before code
review has anything to add. Fix the test suite and re-run pr-gate; reviewers
will run normally once the pre-flight check passes.

## Gate Conclusion
**Overall verdict**: block
**Most severe individual verdict**: block
Final: NO-GO
Required fixes: the pre-flight test command failed. Fix the test suite (see log above), then re-run pr-gate.

## Escalation
**Recommended**: false
**Reviewers**: none
**Reason**:
- none
PREFLIGHT_FAIL_EOF
}

if [[ "$PREFLIGHT_STATUS" == "fail" ]]; then
  say 'pr-gate: pre-flight test suite failed -- skipping reviewer dispatch entirely (fail-fast)\n'
  _write_preflight_failure_result "$OUTPUT_FILE" "$PREFLIGHT_LOG_PATH"
  gate_result_verify "$OUTPUT_FILE" "" "preflight-fail-fast" || exit 1
else

# Snapshot only the selected repo-owned definitions into an artifact-only
# directory inside the reviewed workspace. Both Claude and Codex can read these
# immutable local copies without broad host-home access; cleanup_briefs removes
# them on every success/failure path.
REVIEWER_DEFINITION_DIR="$WORK_DIR/.gate-briefs/reviewer-definitions-${TIMESTAMP}"
mkdir -m 700 -p -- "$REVIEWER_DEFINITION_DIR"
for r in $REVIEWERS; do
  _reviewer_source="$AGENT_DIR/${r}.md"
  _reviewer_snapshot="$REVIEWER_DEFINITION_DIR/${r}.md"
  # umask makes a newly copied definition owner-read-only without depending on
  # chmod being present in the executor test PATH (some gate portability tests
  # deliberately expose only the commands pr-gate strictly needs).
  if [[ "$REVIEWER_SOURCE_MODE" == "base-pinned" ]]; then
    _reviewer_source="$BASE:$REVIEWER_BASE_REL/${r}.md"
    (umask 0377; git show "$_reviewer_source" > "$_reviewer_snapshot") || {
      printf 'Error: failed to snapshot base-pinned reviewer definition: %s\n' "$_reviewer_source" >&2
      exit 1
    }
  else
    if [[ ! -f "$_reviewer_source" || -L "$_reviewer_source" ]]; then
      printf 'Error: trusted reviewer agent file must be a regular non-symlink: %s\n' "$_reviewer_source" >&2
      exit 1
    fi
    _reviewer_nlink="$(stat -c '%h' "$_reviewer_source" 2>/dev/null || stat -f '%l' "$_reviewer_source" 2>/dev/null || printf '1')"
    if [[ "$_reviewer_nlink" =~ ^[0-9]+$ ]] && (( _reviewer_nlink > 1 )); then
      printf 'Error: trusted reviewer agent file must not be hardlinked: %s\n' "$_reviewer_source" >&2
      exit 1
    fi
    _reviewer_source_hash="$(_preflight_sha256_file "$_reviewer_source")" || exit 1
    if ! (umask 0377; cp -P -- "$_reviewer_source" "$_reviewer_snapshot"); then
      printf 'Error: failed to snapshot reviewer definition: %s\n' "$_reviewer_source" >&2
      exit 1
    fi
    _reviewer_nlink="$(stat -c '%h' "$_reviewer_source" 2>/dev/null || stat -f '%l' "$_reviewer_source" 2>/dev/null || printf '1')"
    if [[ -L "$_reviewer_source" || -L "$_reviewer_snapshot" || ! -f "$_reviewer_source" \
        || ( "$_reviewer_nlink" =~ ^[0-9]+$ && "$_reviewer_nlink" -gt 1 ) \
        || "$(_preflight_sha256_file "$_reviewer_source")" != "$_reviewer_source_hash" ]]; then
      printf 'Error: trusted reviewer agent changed during snapshot: %s\n' "$_reviewer_source" >&2
      exit 1
    fi
  fi
  [[ -s "$_reviewer_snapshot" ]] || {
    printf 'Error: reviewer definition snapshot is empty: %s\n' "$_reviewer_snapshot" >&2
    exit 1
  }
done
unset _reviewer_source _reviewer_snapshot _reviewer_nlink _reviewer_source_hash

# ── Dispatch ─────────────────────────────────────────────────────────────────
if [[ "$SEQUENTIAL" == "true" ]]; then

  # ── Sequential mode (default: all reviewers in one combined codex session) ──
  AGENT_FILE_ENTRIES=""
  for r in $REVIEWERS; do
    AGENT_PATH="$REVIEWER_DEFINITION_DIR/${r}.md"
    AGENT_FILE_ENTRIES="${AGENT_FILE_ENTRIES}  - read: ${AGENT_PATH}"$'\n'
  done

  BRIEF_FILE="$BRIEF_DIR/pr-gate-${TIMESTAMP}.md"
  BRIEF_FILES+=("$BRIEF_FILE")

  cat > "$BRIEF_FILE" << BRIEF_EOF
schema_version: 1
working_dir: ${WORK_DIR}

goal: Sequential ${TIER}-tier PR-gate review. Apply each reviewer's criteria to the changed files and write a structured verdict to ${OUTPUT_FILE}.

files:
${AGENT_FILE_ENTRIES}${DIFF_FILE_ENTRIES}  - new:  ${OUTPUT_FILE}

constraints:
  - Do NOT modify any source file.
  - Only write ${OUTPUT_FILE}.
  - Before your FIRST write to ${OUTPUT_FILE} in this session, call: ${GUARD_PMCTL_CMD} guard check --role reviewer --runtime ${EXECUTOR} --event pre-write --file ${OUTPUT_FILE}
    If that call exits nonzero, abort and report the guard denial -- do NOT write the file.
    You will write to this same file multiple times in this session (once per reviewer, then once for synthesis) -- that is expected. Do not create or write any other file.
  - Create parent directories for ${OUTPUT_FILE} if needed (mkdir -p).
  - Only cite files in the verified reference index or the diff list. Read a file before citing its sections; do not invent citations.

context:
  Tier: ${TIER}
  Executor: ${EXECUTOR}
  Reviewers: ${REVIEWER_DISPLAY}
  Not reviewed: ${SKIPPED_DISPLAY}
  Base: ${BASE}${HEAD_METADATA_LINE}
  Scope: ${SCOPE:-none}
  Date: $(date '+%Y-%m-%d')
${GATE_ASSURANCE_CONTEXT_BLOCK}${GATE_OVERRIDES_CONTEXT_BLOCK}${TEST_EVIDENCE_CONTEXT_BLOCK}
${MEMORY_CONTEXT_BLOCK}
  Verified reference files (exist in working tree -- check before citing):
${REPO_REF_INDEX}
  Diff (${LINES} changed lines):
${DIFF_STAT_INDENTED}

task:
  Process each reviewer IN ORDER: ${REVIEWER_DISPLAY}

  For EACH reviewer:
  1. Read their agent definition file (listed above). Follow any boot instructions
     and internalize their specific review criteria and verdict scale.
  2. Review the changed files from that reviewer's perspective only.
  3. Produce a structured findings block:
     - Findings with severity (low/medium/high) and location
     - Explicit verdict: approve | advise | block-soft | block
  4. IMMEDIATELY write/append that reviewer's "## {reviewer} -- {verdict}" section to
     ${OUTPUT_FILE} before moving to the next reviewer. On the FIRST reviewer, create the
     file starting with the "# PR-Gate Result" header block (date/reviewers/not-reviewed
     lines -- these do not depend on any reviewer's findings), then that reviewer's
     section. On subsequent reviewers, append only that reviewer's section. Do NOT write
     the YAML frontmatter yet -- its fields (final, most_severe, per-reviewer verdicts)
     are only known after synthesis; it is added in step 9 below. Do NOT hold all reviewer
     content in-context until the end -- write each section as soon as it is done, so a
     later reviewer's slowness (e.g. a long test run) cannot destroy earlier reviewers'
     already-completed verdicts if this session is later interrupted or times out.

  After all reviewers, synthesize as project-pm would:
  5. Identify cross-reviewer overlaps (same issue raised by multiple reviewers)
  6. Overall verdict = most severe individual verdict
  7. State which dimensions were NOT covered (not-reviewed list above)
  8. Final GO (no blocks) / NO-GO (any block or block-soft) with rationale and override path if applicable
  9. Now that the final verdict is known: PREPEND the YAML frontmatter block to the very
     top of ${OUTPUT_FILE} (before the header already written in step 4), then APPEND the
     synthesis sections (Cross-Reviewer Overlaps / Coverage Notes / Gate Conclusion /
     Escalation) to the bottom. Do not rewrite the reviewer sections already written in
     step 4 -- only prepend the frontmatter and append the synthesis sections.

output_format: |
  ---
  gate_result_version: pr_gate_result_v1
  final: GO|NO-GO
  tier: ${TIER}
  mode: ${MODE_RESOLVED}
  most_severe: approve|advise|block-soft|block
  reviewers:
    critic: approve|advise|block-soft|skipped
    qa-tester: pass|needs-tests|block|skipped
    architecture-reviewer: approve|advise|block-soft|skipped
    security-reviewer: pass|block|pass-not-applicable|skipped
    risk-reviewer: pass|block|pass-not-applicable|skipped
  escalation:
    recommended: true|false
    reviewers: []
    reason: []
  ---

  # PR-Gate Result -- ${TIER} tier (${EXECUTOR} mode)
  **Date**: $(date '+%Y-%m-%d')
  **Reviewers**: ${REVIEWER_DISPLAY}
  **Not reviewed**: ${SKIPPED_DISPLAY}

  ## {reviewer-name} -- {verdict}
  {findings, one per bullet, with [severity] and file:line}

  (repeat for each reviewer in order)

  ## Cross-Reviewer Overlaps
  {list issues raised by >1 reviewer; "none" if clean}

  ## Coverage Notes
  **Dimensions not covered**: ${SKIPPED_DISPLAY}

  ## Gate Conclusion
  **Overall verdict**: {most severe}
  **Most severe individual verdict**: {most severe}
  Final: GO|NO-GO
  {required fixes if NO-GO; override path if any block-soft}

  CRITICAL -- the Final: line above MUST be emitted EXACTLY in this shape:
  - plain text, no markdown emphasis (NO surrounding **, NO backticks, NO italic)
  - at start of line (no leading whitespace)
  - literal token GO or NO-GO (uppercase, hyphen for NO-GO)
  - matched by the regex ^Final: (GO|NO-GO)\$
  - the value MUST equal the frontmatter \`final:\` field (case-sensitive)
  Examples that BREAK the parser and MUST NOT be emitted: \`**Final: GO**\`, \`Final: **GO**\`, \` Final: GO\`, \`Final: Go\`.

  ## Escalation
  **Recommended**: true|false
  **Reviewers**: <comma-list or "none">
  **Reason**:
  - <bullet> (or "none" when recommended=false)

  Escalation is recommended when:
  (a) policy.escalation_signals above is non-empty; use this canonical resolver
      output and do not re-match paths with a separate regex
  (b) at least one reviewer returned advise|block-soft.

self_verify:
  - cmd: "test -f ${OUTPUT_FILE}"
  - has-conclusion: grep -cE '^Final: (GO|NO-GO)\$' ${OUTPUT_FILE} should be exactly 1
  - frontmatter-final-parity: the value after \`final:\` in the YAML frontmatter MUST equal the value after \`Final:\` in Gate Conclusion (case-sensitive)

acceptance:
  - ${OUTPUT_FILE} exists with a verdict section for each of the ${NUM_REVIEWERS} reviewers
  - "Final: GO" or "Final: NO-GO" is present in Gate Conclusion (plain text, no markdown emphasis)
BRIEF_EOF

  # Every executor dispatches an independent subprocess (codex `codex exec`, claude
  # headless `claude --print`). The generic dispatch_via takes the executor name as
  # its first arg, so the call site is uniform; sandbox/approval are forwarded only
  # to adapters whose runner_kind accepts them.
  DISPATCH_CMD="$(dispatch_via "$EXECUTOR" "$BRIEF_FILE" "$WORK_DIR" "$DISPATCH_MODEL" "$DISPATCH_SANDBOX" "$DISPATCH_APPROVAL" "$TIMEOUT" "$DISPATCH_ISOLATION" "$DISPATCH_EFFORT")" || exit 2
  # Send the dispatch child's stdout to our stderr: it is diagnostic chatter,
  # not gate data (the verdict lands in the result file). If it inherited our
  # stdout and a consumer closed that pipe (`gate run | head`), the child's
  # first write would hit EPIPE and -- with SIGPIPE ignored + set -e -- exit
  # nonzero before writing the result, killing the gate before its integrity
  # checks could fire. Parallel reviewers already redirect to a log.
  #
  # Capture the exit code instead of letting `set -e` abort here: a sequential
  # session that times out partway through (e.g. qa-tester stuck running a
  # long test suite) must not discard whatever earlier reviewers already
  # wrote to ${OUTPUT_FILE} per the brief's per-reviewer append instruction
  # (task step 4 above) -- see the partial-result branch below.
  SEQ_DISPATCH_EXIT=0
  eval "$DISPATCH_CMD" >&2 || SEQ_DISPATCH_EXIT=$?

  if [[ "$SEQ_DISPATCH_EXIT" -ne 0 ]]; then
    if [[ "$SEQ_DISPATCH_EXIT" -eq 124 ]]; then
      printf 'Timeout: sequential dispatch did not complete within %ss.\n' "$TIMEOUT" >&2
    else
      printf 'Error: sequential dispatch exited %d.\n' "$SEQ_DISPATCH_EXIT" >&2
    fi
    if [[ -s "$OUTPUT_FILE" ]]; then
      _SEQ_COMPLETED=() _SEQ_INCOMPLETE=()
      for r in $REVIEWERS; do
        if grep -qE "^## ${r} -- " "$OUTPUT_FILE"; then
          _SEQ_COMPLETED+=("$r")
        else
          _SEQ_INCOMPLETE+=("$r")
        fi
      done
      printf 'Partial result: %d of %d reviewer(s) completed before the session stopped: %s\n' \
        "${#_SEQ_COMPLETED[@]}" "$NUM_REVIEWERS" "${_SEQ_COMPLETED[*]:-none}" >&2
      printf 'Not completed: %s\n' "${_SEQ_INCOMPLETE[*]:-none}" >&2
      printf 'Partial artifact (no Final: verdict -- inconclusive, do NOT treat as GO) preserved at: %s\n' "$OUTPUT_FILE" >&2
      printf 'Raw session trace (for post-mortem): %s\n' "${PM_DISPATCH_TRACE_DIR:-$WORK_DIR/.agent-trace}" >&2
    else
      printf 'Gate aborted -- no reviewer sections were written before the session stopped: %s\n' "$OUTPUT_FILE" >&2
    fi
    exit 1
  fi

  # Validate single-session output via the shared contract (must exist, be
  # non-empty, carry exactly one Final: GO|NO-GO line that agrees with the
  # frontmatter final: field). Same checks the parallel synthesis route and
  # `pmctl gate verify` enforce.
  gate_result_verify "$OUTPUT_FILE" "" "sequential gate" || exit 1

else

  # ── Multi-session mode (--parallel): one independent dispatch per reviewer + synthesis ──
  # Each reviewer runs in its own session with no shared context -- eliminates
  # anchoring bias that can occur when all reviewers share one session window.
  # Followed by a PM synthesis session that consolidates all individual results.
  # Higher token cost vs single-session; suitable for auth/payment/migration paths.

  REVIEWER_OUTPUT_FILES=()
  DISPATCH_PIDS=()
  REVIEWER_NAMES=()

  mkdir -p "$_ARTIFACT_ROOT/.agent-trace"

  # Resolve a portable hash command; fail-closed if none is available or usable.
  # sha256sum (GNU coreutils) is preferred; shasum -a 256 covers macOS/BSD.
  # Both presence (command -v) AND usability (echo | cmd) are verified so a
  # broken stub or wrong-architecture binary is caught before the integrity guard.
  _HASH_CMD=""
  if command -v sha256sum > /dev/null 2>&1 && printf '' | sha256sum > /dev/null 2>&1; then
    _HASH_CMD="sha256sum"
  elif command -v shasum > /dev/null 2>&1 && printf '' | shasum -a 256 > /dev/null 2>&1; then
    _HASH_CMD="shasum -a 256"
  fi
  if [[ -z "$_HASH_CMD" ]]; then
    printf 'Error: no sha256sum or shasum found -- cannot fingerprint worktree for injection detection.\n' >&2
    exit 1
  fi

  # Capture working-tree content fingerprints before dispatch.
  # git diff HEAD: content-level changes to tracked files (catches already-dirty mutations).
  # git status --porcelain -z: new untracked source files. The gate's own artifacts
  # (.agent-trace/ .gate-briefs/ .gate-results/) are excluded explicitly via
  # artifact_filter_porcelain -- the canonical artifact-leaf source of truth in
  # runtime/lib/artifact-paths.sh -- so a repo that has NOT had these paths gitignored
  # is not misread as prompt-injected. NUL-delimited (-z) so special filenames survive.
  _PRE_DISPATCH_DIFF=$(git diff HEAD 2>/dev/null | $_HASH_CMD)
  _PRE_DISPATCH_STATUS=$(git status --porcelain -z 2>/dev/null | artifact_filter_porcelain | $_HASH_CMD)

  for r in $REVIEWERS; do
    AGENT_PATH="$REVIEWER_DEFINITION_DIR/${r}.md"
    REVIEWER_OUTPUT="$WORK_DIR/.gate-results/reviewer-${r}-${TIMESTAMP}.md"
    REVIEWER_BRIEF="$BRIEF_DIR/pr-gate-${TIMESTAMP}-${r}.md"
    DISPATCH_LOG="$_ARTIFACT_ROOT/.agent-trace/gate-${TIMESTAMP}-${r}.log"

    BRIEF_FILES+=("$REVIEWER_BRIEF")
    REVIEWER_OUTPUT_FILES+=("$REVIEWER_OUTPUT")
    REVIEWER_NAMES+=("$r")

    cat > "$REVIEWER_BRIEF" << RBRIEF_EOF
schema_version: 1
working_dir: ${WORK_DIR}

goal: You are acting as the ${r} reviewer. Read your agent definition, apply your specific review criteria to the changed files, and write your structured findings to ${REVIEWER_OUTPUT}.

files:
  - read: ${AGENT_PATH}
${DIFF_FILE_ENTRIES}  - new:  ${REVIEWER_OUTPUT}

constraints:
  - Do NOT modify any source file.
  - Only write ${REVIEWER_OUTPUT}.
  - Before writing ${REVIEWER_OUTPUT}, call: ${GUARD_PMCTL_CMD} guard check --role reviewer --runtime ${EXECUTOR} --event pre-write --file ${REVIEWER_OUTPUT}
    If that call exits nonzero, abort and report the guard denial -- do NOT write the file.
  - Create parent directories if needed (mkdir -p).
  - Only cite files in the verified reference index or the diff list. Read a file before citing its sections; do not invent citations.

context:
  Tier: ${TIER}
  Executor: ${EXECUTOR}
  Reviewer: ${r}
  Base: ${BASE}${HEAD_METADATA_LINE}
  Scope: ${SCOPE:-none}
  Date: $(date '+%Y-%m-%d')
${GATE_ASSURANCE_CONTEXT_BLOCK}${GATE_OVERRIDES_CONTEXT_BLOCK}${TEST_EVIDENCE_CONTEXT_BLOCK}
${MEMORY_CONTEXT_BLOCK}
  Verified reference files (exist in working tree -- check before citing):
${REPO_REF_INDEX}
  Diff (${LINES} changed lines):
${DIFF_STAT_INDENTED}

task:
  1. Read your agent definition (${AGENT_PATH}). Follow its boot instructions
     and internalize your specific review criteria and verdict scale.
  2. Review the changed files strictly from the ${r} perspective only.
     Do not attempt to cover other reviewer dimensions.
  3. Write a structured findings block with:
     - Findings: [severity] file:line -- description (low/medium/high)
     - Exactly one heading with the canonical verdict:
       ## ${r} -- approve | advise | block-soft | block
     - One-sentence rationale for your verdict

  Write your complete review to ${REVIEWER_OUTPUT}.

output_format: |
  ## ${r} -- {verdict}
  {structured findings that follow the agent definition}

  The heading is the machine verdict. If you also emit an upper-case
  Verdict: line, it must appear exactly once and match the heading.

self_verify:
  - cmd: "test -f ${REVIEWER_OUTPUT}"

acceptance:
  - ${REVIEWER_OUTPUT} exists with exactly one canonical ${r} verdict heading
RBRIEF_EOF

    REVIEWER_DISPATCH_CMD="$(dispatch_via "$EXECUTOR" "$REVIEWER_BRIEF" "$WORK_DIR" "$DISPATCH_MODEL" "$DISPATCH_SANDBOX" "$DISPATCH_APPROVAL" "$TIMEOUT" "$DISPATCH_ISOLATION" "$DISPATCH_EFFORT")" || exit 2
    eval "$REVIEWER_DISPATCH_CMD" > "$DISPATCH_LOG" 2>&1 &
    DISPATCH_PIDS+=($!)
    say '  [parallel] launched %s (pid %d)\n' "$r" "$!"
  done

  # Subprocess executors launched the reviewers as background children above;
  # wait for them, validate each output, then synthesize (all in-process).
  if [[ "$EXECUTOR_IS_SUBPROCESS" == true ]]; then
    say '\n  waiting for %d reviewer session(s)...\n' "${#DISPATCH_PIDS[@]}"

    # Watchdog: kill any reviewer subprocess that hasn't exited after the fan-out
    # timeout. Defense-in-depth: pmctl already passes --timeout to the executor,
    # but if pmctl itself hangs the inner timeout never fires. Watchdog timeout =
    # per-reviewer TIMEOUT + 60s overhead; override via _PM_DISPATCH_GATE_WATCHDOG_TIMEOUT.
    _GATE_WATCHDOG_TIMEOUT="${_PM_DISPATCH_GATE_WATCHDOG_TIMEOUT:-$((TIMEOUT + 60))}"
    (
      command -p sleep "$_GATE_WATCHDOG_TIMEOUT"
      for _wpid in "${DISPATCH_PIDS[@]}"; do
        _kill_process_tree "$_wpid" TERM
      done
    ) &
    _GATE_WATCHDOG_PID=$!

    # Wait for all reviewer sessions. Any non-zero exit aborts the gate -- an
    # incomplete review cannot certify a valid gate result.
    # Hash each reviewer output immediately after its PID exits so we capture
    # the content before any concurrently-running reviewer session can modify it.
    # Exit code > 128 means killed by signal (SIGTERM=143); attribute these as
    # timeouts (watchdog fired) rather than clean executor failures.
    FAILED_REVIEWERS=()
    TIMED_OUT_REVIEWERS=()
    REVIEWER_POST_WAIT_HASHES=()
    for i in "${!DISPATCH_PIDS[@]}"; do
      pid="${DISPATCH_PIDS[$i]}"
      r="${REVIEWER_NAMES[$i]}"
      rf="${REVIEWER_OUTPUT_FILES[$i]}"
      _wait_exit=0
      wait "$pid" || _wait_exit=$?
      if [[ "$_wait_exit" -ne 0 ]]; then
        [[ "$_wait_exit" -gt 128 ]] && TIMED_OUT_REVIEWERS+=("$r")
        FAILED_REVIEWERS+=("$r")
        REVIEWER_POST_WAIT_HASHES+=("none")
      else
        REVIEWER_POST_WAIT_HASHES+=("$(cat "$rf" 2>/dev/null | $_HASH_CMD || echo 'missing')")
      fi
    done

    # Kill watchdog if reviewers finished before the deadline.
    kill "$_GATE_WATCHDOG_PID" 2>/dev/null || true
    wait "$_GATE_WATCHDOG_PID" 2>/dev/null || true

    if [[ "${#TIMED_OUT_REVIEWERS[@]}" -gt 0 ]]; then
      printf 'Timeout: %d reviewer session(s) did not complete within %ds: %s\n' \
        "${#TIMED_OUT_REVIEWERS[@]}" "$_GATE_WATCHDOG_TIMEOUT" "${TIMED_OUT_REVIEWERS[*]}" >&2
    fi
    if [[ "${#FAILED_REVIEWERS[@]}" -gt 0 ]]; then
      printf 'Error: %d reviewer session(s) failed: %s\n' \
        "${#FAILED_REVIEWERS[@]}" "${FAILED_REVIEWERS[*]}" >&2
      printf 'Gate aborted -- fix the failing session or use --sequential to diagnose.\n' >&2
      exit 1
    fi

    # Verify every reviewer wrote a non-empty output file -- a codex session can
    # exit 0 without completing its task, which would leave the synthesis brief
    # with nothing to consolidate and could produce a spurious GO.
    MISSING_OUTPUTS=()
    for i in "${!REVIEWER_OUTPUT_FILES[@]}"; do
      rf="${REVIEWER_OUTPUT_FILES[$i]}"
      r="${REVIEWER_NAMES[$i]}"
      if [[ ! -s "$rf" ]]; then
        MISSING_OUTPUTS+=("$r")
      fi
    done
    if [[ "${#MISSING_OUTPUTS[@]}" -gt 0 ]]; then
      printf 'Error: reviewer output missing or empty for: %s\n' "${MISSING_OUTPUTS[*]}" >&2
      printf 'A reviewer session may have exited 0 without writing its findings file.\n' >&2
      printf 'Gate aborted -- use --sequential to diagnose.\n' >&2
      exit 1
    fi

    # Verify every reviewer output contains one unambiguous canonical verdict
    # before synthesis. The role-matched heading is authoritative; an optional
    # upper-case Verdict marker must be unique and agree with it.
    INVALID_OUTPUTS=()
    REVIEWER_VERDICTS=()
    for i in "${!REVIEWER_OUTPUT_FILES[@]}"; do
      rf="${REVIEWER_OUTPUT_FILES[$i]}"
      r="${REVIEWER_NAMES[$i]}"
      if reviewer_verdict="$(_gate_reviewer_verdict_extract "$r" "$rf")"; then
        REVIEWER_VERDICTS+=("$reviewer_verdict")
      else
        INVALID_OUTPUTS+=("$r")
      fi
    done
    if [[ "${#INVALID_OUTPUTS[@]}" -gt 0 ]]; then
      printf 'Error: reviewer output has an invalid or ambiguous canonical verdict for: %s\n' \
        "${INVALID_OUTPUTS[*]}" >&2
      printf 'Expected: exactly one matching heading: ## <reviewer> -- approve|advise|block-soft|block\n' >&2
      printf 'Any upper-case Verdict: marker must be unique and match that heading.\n' >&2
      printf 'Gate aborted -- use --sequential to diagnose.\n' >&2
      exit 1
    fi

    # Cross-reviewer artifact tamper detection: re-hash every reviewer output and
    # compare with the hash captured immediately after that reviewer's PID exited.
    # A mismatch means a concurrently-running reviewer session modified this file
    # after it was completed -- fail closed before synthesis can run on tainted data.
    _artifact_check_args=()
    for i in "${!REVIEWER_OUTPUT_FILES[@]}"; do
      rf="${REVIEWER_OUTPUT_FILES[$i]}"
      r="${REVIEWER_NAMES[$i]}"
      expected="${REVIEWER_POST_WAIT_HASHES[$i]}"
      _artifact_check_args+=("$r" "$rf" "$expected")
    done
    mapfile -t CROSS_TAMPERED < <(verify_reviewer_artifact_hashes "$_HASH_CMD" "${_artifact_check_args[@]}")
    if [[ "${#CROSS_TAMPERED[@]}" -gt 0 ]]; then
      printf 'Error: reviewer artifact modified after that reviewer session completed: %s\n' "${CROSS_TAMPERED[*]}" >&2
      printf 'Possible cross-reviewer artifact tampering in --parallel mode. Gate aborted.\n' >&2
      exit 1
    fi

  # Worktree integrity check -- detect prompt-injected tracked-file modifications.
  # Content-hash catches mutations to already-dirty tracked files; status hash
  # catches new untracked source files. Gate artifacts are excluded explicitly via
  # artifact_filter_porcelain (runtime/lib/artifact-paths.sh) -- the pre/post sides
  # MUST use the same filter or the hashes can never match. -z keeps special filenames intact.
  _POST_DISPATCH_DIFF=$(git diff HEAD 2>/dev/null | $_HASH_CMD)
  _POST_DISPATCH_STATUS=$(git status --porcelain -z 2>/dev/null | artifact_filter_porcelain | $_HASH_CMD)
  if [[ "$_PRE_DISPATCH_DIFF" != "$_POST_DISPATCH_DIFF" || "$_PRE_DISPATCH_STATUS" != "$_POST_DISPATCH_STATUS" ]]; then
    printf 'Error: reviewer sessions modified working tree -- possible prompt injection.\n' >&2
    printf 'Gate aborted. Inspect the reviewer dispatch logs under .agent-trace/ for details.\n' >&2
    exit 1
  fi

  # Reviewer artifact integrity -- snapshot each reviewer output file content now,
  # before synthesis, to detect synthesis-side tampering of reviewer artifacts.
  # Reviewer outputs are gitignored and not covered by the worktree hash above.
  REVIEWER_ARTIFACT_HASHES=()
  for rf in "${REVIEWER_OUTPUT_FILES[@]}"; do
    REVIEWER_ARTIFACT_HASHES+=("$(cat "$rf" | $_HASH_CMD)")
  done

  say '  all reviewer sessions done.\n\n'

  # Compute the final verdict deterministically in shell before synthesis.
  # Synthesis is treated as prose-only; the shell verdict is the authoritative gate result.
  SHELL_VERDICT="approve"
  for rv in "${REVIEWER_VERDICTS[@]}"; do
    case "$rv" in
      block) SHELL_VERDICT="block" ;;
      block-soft) [[ "$SHELL_VERDICT" != "block" ]] && SHELL_VERDICT="block-soft" ;;
      advise) [[ "$SHELL_VERDICT" == "approve" ]] && SHELL_VERDICT="advise" ;;
    esac
  done
  if [[ "$SHELL_VERDICT" == "approve" || "$SHELL_VERDICT" == "advise" ]]; then
    SHELL_FINAL="GO"
  else
    SHELL_FINAL="NO-GO"
  fi

  # ── PM synthesis ─────────────────────────────────────────────────────────────

  # Write synthesis brief in segments so reviewer content is appended with `cat`
  # (no heredoc expansion) rather than embedded in an unquoted heredoc.
  # This also removes `read:` file paths from the brief, preventing the synthesis
  # session from discovering or targeting reviewer output file locations.

  cat > "$SYNTHESIS_BRIEF" << SBRIEF_P1
schema_version: 1
working_dir: ${WORK_DIR}

goal: You are project-pm. Synthesize the reviewer findings provided in the context below and write a final consolidated PR-gate result at ${OUTPUT_FILE}.

files:
  - new:  ${OUTPUT_FILE}

constraints:
  - Do NOT modify any source file.
  - Only write ${OUTPUT_FILE}.
  - Create parent directories if needed (mkdir -p).
  - The Gate Conclusion MUST contain exactly: Final: ${SHELL_FINAL}
    This is pre-computed from the reviewer verdicts and must not be overridden.
  - Only cite files in the verified reference index or reviewer findings; do not invent citations.

context:
  Tier: ${TIER}
  Executor: ${EXECUTOR}
  Reviewers: ${REVIEWER_DISPLAY}
  Not reviewed: ${SKIPPED_DISPLAY}
  Base: ${BASE}${HEAD_METADATA_LINE}
  Scope: ${SCOPE:-none}
  Date: $(date '+%Y-%m-%d')
${GATE_ASSURANCE_CONTEXT_BLOCK}${GATE_OVERRIDES_CONTEXT_BLOCK}${TEST_EVIDENCE_CONTEXT_BLOCK}
  Verified reference files (exist in working tree -- check before citing):
${REPO_REF_INDEX}
  Reviewer findings (embedded -- do NOT attempt to read any external reviewer output file):
SBRIEF_P1

  for i in "${!REVIEWER_OUTPUT_FILES[@]}"; do
    rf="${REVIEWER_OUTPUT_FILES[$i]}"
    r="${REVIEWER_NAMES[$i]}"
    printf '  --- %s findings ---\n' "$r" >> "$SYNTHESIS_BRIEF"
    if [[ -s "$rf" ]]; then
      cat "$rf" >> "$SYNTHESIS_BRIEF"
    else
      printf '  (reviewer output unavailable)\n' >> "$SYNTHESIS_BRIEF"
    fi
    printf '\n' >> "$SYNTHESIS_BRIEF"
  done

  cat >> "$SYNTHESIS_BRIEF" << SBRIEF_P2

task:
  1. Use the reviewer findings embedded in the context above.
  2. Identify cross-reviewer overlaps: issues raised by more than one reviewer.
  3. Determine the overall verdict: most severe individual verdict across all reviewers
     (approve < advise < block-soft < block).
  4. State Final: GO or NO-GO.
     - GO:    no reviewer returned block or block-soft.
     - NO-GO: any reviewer returned block or block-soft. List required fixes and
              any applicable override path.
  5. Write the complete consolidated result to ${OUTPUT_FILE}.

output_format: |
  ---
  gate_result_version: pr_gate_result_v1
  final: GO|NO-GO
  tier: ${TIER}
  mode: ${MODE_RESOLVED}
  most_severe: approve|advise|block-soft|block
  reviewers:
    critic: approve|advise|block-soft|skipped
    qa-tester: pass|needs-tests|block|skipped
    architecture-reviewer: approve|advise|block-soft|skipped
    security-reviewer: pass|block|pass-not-applicable|skipped
    risk-reviewer: pass|block|pass-not-applicable|skipped
  escalation:
    recommended: true|false
    reviewers: []
    reason: []
  ---

  # PR-Gate Result -- ${TIER} tier (parallel ${EXECUTOR} mode)
  **Date**: $(date '+%Y-%m-%d')
  **Reviewers**: ${REVIEWER_DISPLAY}
  **Not reviewed**: ${SKIPPED_DISPLAY}

  ## {reviewer-name} -- {verdict}
  {Copy findings from that reviewer's findings block above, one bullet per finding with [severity] and file:line}

  Verdict: {verdict from reviewer findings}. {rationale}

  (repeat for each reviewer in order)

  ## Cross-Reviewer Overlaps
  {list issues raised by more than one reviewer; "none" if clean}

  ## Coverage Notes
  **Dimensions not covered**: ${SKIPPED_DISPLAY}

  ## Gate Conclusion
  **Overall verdict**: {most severe across all reviewers}
  **Most severe individual verdict**: {most severe}
  Final: GO|NO-GO
  {required fixes if NO-GO; override path if any block or block-soft}

  CRITICAL -- the Final: line above MUST be emitted EXACTLY in this shape:
  - plain text, no markdown emphasis (NO surrounding **, NO backticks, NO italic)
  - at start of line (no leading whitespace)
  - literal token GO or NO-GO (uppercase, hyphen for NO-GO)
  - matched by the regex ^Final: (GO|NO-GO)\$
  - the value MUST equal the frontmatter \`final:\` field (case-sensitive)
  Examples that BREAK the parser and MUST NOT be emitted: \`**Final: GO**\`, \`Final: **GO**\`, \` Final: GO\`, \`Final: Go\`.

  ## Escalation
  **Recommended**: true|false
  **Reviewers**: <comma-list or "none">
  **Reason**:
  - <bullet> (or "none" when recommended=false)

  Escalation is recommended when:
  (a) policy.escalation_signals above is non-empty; use this canonical resolver
      output and do not re-match paths with a separate regex
  (b) at least one reviewer returned advise|block-soft.

  Recommended follow-ups:
  {non-blocking improvements from advise-level findings, if any}

  Rationale: {1-2 sentences explaining the final verdict}

self_verify:
  - cmd: "test -f ${OUTPUT_FILE}"
  - has-final: grep -cE '^Final: (GO|NO-GO)\$' ${OUTPUT_FILE} should be exactly 1
  - frontmatter-final-parity: the value after \`final:\` in the YAML frontmatter MUST equal the value after \`Final:\` in Gate Conclusion (case-sensitive)
  - all-reviewers-present: output must contain a section header for each of: ${REVIEWER_DISPLAY}

acceptance:
  - ${OUTPUT_FILE} exists with a section for each of the ${NUM_REVIEWERS} reviewers
  - Cross-Reviewer Overlaps section is present
  - "Final: GO" or "Final: NO-GO" is present in Gate Conclusion (plain text, no markdown emphasis)
SBRIEF_P2

  say '  [synthesis] running PM consolidation...\n'
  SYNTHESIS_DISPATCH_CMD="$(dispatch_via "$EXECUTOR" "$SYNTHESIS_BRIEF" "$WORK_DIR" "$DISPATCH_MODEL" "$DISPATCH_SANDBOX" "$DISPATCH_APPROVAL" "$TIMEOUT" "$DISPATCH_ISOLATION" "$DISPATCH_EFFORT")" || exit 2
  # Diagnostic chatter to stderr -- see sequential dispatch note above.
  # Synthesis runs in background so a watchdog can kill it if it hangs indefinitely.
  eval "$SYNTHESIS_DISPATCH_CMD" >&2 &
  _SYNTHESIS_PID=$!
  _GATE_SYNTHESIS_WATCHDOG_TIMEOUT="${_PM_DISPATCH_GATE_SYNTHESIS_WATCHDOG_TIMEOUT:-$((TIMEOUT + 60))}"
  (
    command -p sleep "$_GATE_SYNTHESIS_WATCHDOG_TIMEOUT"
    _kill_process_tree "$_SYNTHESIS_PID" TERM
  ) &
  _SYNTHESIS_WATCHDOG_PID=$!
  _synthesis_exit=0
  wait "$_SYNTHESIS_PID" || _synthesis_exit=$?
  kill "$_SYNTHESIS_WATCHDOG_PID" 2>/dev/null || true
  wait "$_SYNTHESIS_WATCHDOG_PID" 2>/dev/null || true
  if [[ "$_synthesis_exit" -gt 128 ]]; then
    printf 'Timeout: synthesis session did not complete within %ds\n' "$_GATE_SYNTHESIS_WATCHDOG_TIMEOUT" >&2
    exit 1
  elif [[ "$_synthesis_exit" -ne 0 ]]; then
    printf 'Error: synthesis session failed (exit %d)\n' "$_synthesis_exit" >&2
    exit 1
  fi

  # Validate synthesis output via the shared contract, pinned to the
  # shell-computed verdict: a synthesis that contradicts SHELL_FINAL (in either
  # the body Final: line or the frontmatter final: field) indicates a
  # manipulated/corrupt artifact and aborts the gate.
  gate_result_verify "$OUTPUT_FILE" "$SHELL_FINAL" "PM synthesis" || exit 1

  # Verify reviewer artifact files were not modified by synthesis.
  # These are gitignored and not covered by the tracked-file hash above.
  TAMPERED_ARTIFACTS=()
  for i in "${!REVIEWER_OUTPUT_FILES[@]}"; do
    rf="${REVIEWER_OUTPUT_FILES[$i]}"
    r="${REVIEWER_NAMES[$i]}"
    current_hash="$(cat "$rf" | $_HASH_CMD)"
    if [[ "${REVIEWER_ARTIFACT_HASHES[$i]}" != "$current_hash" ]]; then
      TAMPERED_ARTIFACTS+=("$r")
    fi
  done
  if [[ "${#TAMPERED_ARTIFACTS[@]}" -gt 0 ]]; then
    printf 'Error: reviewer artifact(s) modified after review phase -- synthesis-side tampering detected: %s\n' \
      "${TAMPERED_ARTIFACTS[*]}" >&2
    exit 1
  fi

  # Post-synthesis integrity check -- same dual-hash guard for tracked files.
  # Same artifact_filter_porcelain exclusion as the pre/post-dispatch snapshots so
  # this hash stays comparable with _POST_DISPATCH_STATUS below.
  _POST_SYNTHESIS_DIFF=$(git diff HEAD 2>/dev/null | $_HASH_CMD)
  _POST_SYNTHESIS_STATUS=$(git status --porcelain -z 2>/dev/null | artifact_filter_porcelain | $_HASH_CMD)
  if [[ "$_POST_DISPATCH_DIFF" != "$_POST_SYNTHESIS_DIFF" || "$_POST_DISPATCH_STATUS" != "$_POST_SYNTHESIS_STATUS" ]]; then
    printf 'Error: synthesis session modified working tree -- possible prompt injection.\n' >&2
    exit 1
  fi
  fi

fi

fi

# ── Pre-flight test result: mechanical override (CC-470 Part 3) ────────────────
# Applies AFTER dispatch (sequential or parallel) and its own gate_result_verify
# have already succeeded -- this is the single point where both routes converge,
# so the tagging logic lives here once instead of duplicated per route (same
# shape as the override provenance block immediately below, which is the
# established precedent for "shared post-dispatch bash processing of OUTPUT_FILE").
# Only ever called with status=pass: a FAIL never reaches dispatch at all (see
# the fail-fast short-circuit above, which synthesizes its own NO-GO result and
# never invokes any reviewer) -- this just tags the mechanical fact "pre-flight
# already confirmed the suite passes" onto whatever the reviewers produced,
# without touching final:/Final: (reviewers' own verdict stands).
verify_preflight_artifacts_current() {
  local current_evidence current_log expected_log coverage_type current_tree rich_path expected_rich current_rich
  current_evidence="$(_preflight_sha256_file "$PREFLIGHT_EVIDENCE_PATH")" || return 1
  [[ "$current_evidence" == "$PREFLIGHT_EVIDENCE_DIGEST" ]] || {
    printf 'Error: pre-flight evidence artifact was modified after verification\n' >&2; return 1;
  }
  expected_log="$(jq -r '.log.sha256' "$PREFLIGHT_EVIDENCE_PATH")"
  current_log="$(_preflight_sha256_file "$PREFLIGHT_LOG_PATH")" || return 1
  [[ "$current_log" == "$expected_log" ]] || {
    printf 'Error: pre-flight log artifact was modified after verification\n' >&2; return 1;
  }
  coverage_type="$(jq -r '.coverage.type' "$PREFLIGHT_EVIDENCE_PATH")"
  if [[ "$coverage_type" == structured ]]; then
    rich_path="$PREFLIGHT_RICH_RESULT_PATH"
    expected_rich="$(jq -r '.coverage.artifact_sha256' "$PREFLIGHT_EVIDENCE_PATH")"
    current_rich="$(_preflight_sha256_file "$rich_path")" || return 1
    [[ "$current_rich" == "$expected_rich" ]] || {
      printf 'Error: structured pre-flight result was modified after verification\n' >&2; return 1;
    }
  fi
  current_tree="$(_preflight_tree_fingerprint)" || return 1
  [[ "$current_tree" == "$(jq -r '.subject.fingerprint_before' "$PREFLIGHT_EVIDENCE_PATH")" ]] || {
    printf 'Error: pre-flight evidence is stale for the current subject\n' >&2; return 1;
  }
}

gate_apply_preflight_pass_tag() {
  local result_file="$1" evidence_path
  evidence_path="$(_preflight_log_display_path "$PREFLIGHT_EVIDENCE_PATH")"
  awk -v evidence_path="$evidence_path" -v evidence_digest="$PREFLIGHT_EVIDENCE_DIGEST" '
    /^---$/ {
      if (fence < 2) fence++
      if (fence == 2 && !ts_done) {
        print "test_suite: pass"
        print "test_evidence: " evidence_path
        print "test_evidence_sha256: " evidence_digest
        ts_done=1
      }
      print; next
    }
    { print }
  ' "$result_file" > "${result_file}.preflight-tmp"
  mv "${result_file}.preflight-tmp" "$result_file"

  # Self-check: if this rewrite corrupted frontmatter/body parity, fail closed
  # rather than let a broken result file out the door.
  gate_result_verify "$result_file" "" "preflight-pass-tag" || {
    printf 'Error: internal -- gate_apply_preflight_pass_tag corrupted frontmatter/body parity\n' >&2
    exit 1
  }
}

if [[ "$PREFLIGHT_STATUS" == "pass" ]]; then
  verify_preflight_artifacts_current || exit 1
  gate_apply_preflight_pass_tag "$OUTPUT_FILE"
fi

# ── Override provenance (audit record) ─────────────────────────────────────────
# When accepted-risk overrides were injected, the gate result must say so: which
# file they came from and exactly what was suppressed. Without this, an override
# silently turns a would-be block into a GO with no trace in the result. The block
# is appended deterministically by the gate (not the executor) so the audit record
# is independent of what the reviewer chose to echo. It is written on both GO and
# NO-GO -- the audit is about what was offered for suppression, not the outcome.
# Lines are indented (markdown code block) so this section can never introduce a
# spurious top-level `Final:` line or a frontmatter `---` fence that would trip
# gate_result_verify / `pmctl gate verify`.
if [[ -n "$GATE_OVERRIDES_CONTENT" ]]; then
  # shellcheck disable=SC2016  # literal markdown backticks in the format string, not a command substitution
  {
    printf '\n## Gate Overrides Applied\n'
    printf 'Accepted-risk overrides were loaded from `%s` and injected into every\n' "$OVERRIDE_FILE"
    printf 'reviewer and synthesis brief for this run. Reviewers were instructed not to\n'
    printf 're-block these items unless the diff materially changed the accepted risk.\n'
    printf 'This block is the audit record of what was offered for suppression.\n\n'
    printf '%s\n' "$GATE_OVERRIDES_CONTENT" | sed 's/^/    /'
  } >> "$OUTPUT_FILE"
  say 'pr-gate: override provenance recorded in result\n'
  # Re-verify after appending: the provenance block is written post-verification,
  # so re-run the same integrity contract to prove the appended (indented) content
  # did not introduce a second Final: line or break frontmatter parity -- a
  # parser-hostile override file (containing `Final: GO` / `---`) must stay neutralized.
  gate_result_verify "$OUTPUT_FILE" "" "post-provenance-append" || exit 1
fi

# ── Post-gate hook ─────────────────────────────────────────────────────────
# Both executors complete the gate in-process now, so post-gate fires at true
# gate completion regardless of executor. It runs only when --allow-hooks is set
# AND the gate result is GO -- a success-only side-effect hook, not a teardown hook.
_POST_GATE_HOOK="$WORK_DIR/.pm-dispatch/post-gate.sh"
if [[ "$ALLOW_HOOKS" != "true" ]]; then
  if [[ -f "$_POST_GATE_HOOK" ]]; then
    printf 'Warning: .pm-dispatch/post-gate.sh present but skipped -- pass --allow-hooks to execute repo-local hook scripts\n' >&2
  fi
elif [[ -f "$_POST_GATE_HOOK" && ! -x "$_POST_GATE_HOOK" ]]; then
  printf 'Warning: .pm-dispatch/post-gate.sh exists but is not executable -- skipping\n' >&2
elif [[ -x "$_POST_GATE_HOOK" ]]; then
  _GATE_FINAL=$(grep -m1 '^Final: ' "$OUTPUT_FILE" 2>/dev/null | awk '{print $2}' || true)
  if [[ "$_GATE_FINAL" != "GO" ]]; then
    say '\nSkipping post-gate hook: gate result is %s (post-gate runs only on GO)\n' "${_GATE_FINAL:-unknown}"
  else
    say '\nRunning post-gate hook: .pm-dispatch/post-gate.sh\n'
    # Keep this teardown path free of a subshell conditional.  Some deployed
    # gate copies reached this branch through an incompatible parser and
    # reported a syntax error after a valid GO artifact had already been
    # written.  Save/restore explicitly so the hook still runs in WORK_DIR.
    _POST_GATE_HOOK_RC=0
    _POST_GATE_PREV_DIR="$PWD"
    cd "$WORK_DIR" || _POST_GATE_HOOK_RC=$?
    if [[ "$_POST_GATE_HOOK_RC" -eq 0 ]]; then
      bash "$_POST_GATE_HOOK" || _POST_GATE_HOOK_RC=$?
    fi
    cd "$_POST_GATE_PREV_DIR" || exit 2
    if [[ "$_POST_GATE_HOOK_RC" -ne 0 ]]; then
      printf '\n## Post-Gate Hook Failure\n**post-gate.sh exited nonzero -- this gate run is INCOMPLETE despite Final: GO above. Re-run after fixing the hook.**\n' >> "$OUTPUT_FILE"
      printf 'Error: post-gate hook failed\n' >&2
      exit 1
    fi
    say 'post-gate hook completed.\n'
  fi
fi

# Replace the executor-authored staging frontmatter with a v2 pointer and write
# the machine-owned assurance sidecar only after every deterministic rewrite
# and explicitly enabled post-gate hook is complete. The shared verifier then
# checks result/pointer/envelope parity before publication or relocation.
gate_finalize_assurance "$OUTPUT_FILE" "$ASSURANCE_FILE" || exit 2

# ── Relocate result to run dir (post-verification) ───────────────────────────
# OUTPUT_FILE was written by the executor in WORK_DIR (workspace-write sandbox
# constraint). Now that it is verified, move it (and any parallel reviewer outputs,
# already read by synthesis) to _ARTIFACT_ROOT/.gate-results/ if a run dir was supplied.
# Relocation is centralized in relocate_gate_artifacts(), which the EXIT trap also calls
# so failure paths relocate too; calling it here updates OUTPUT_FILE before the prints
# below, and the trap's later call is then a no-op. --output overrides are never moved.
relocate_gate_artifacts

# ── Print result path for caller ─────────────────────────────────────────────
# The result was written by the dispatched subprocess and already integrity-checked
# in-process (gate_result_verify above). `pmctl gate verify "$OUTPUT_FILE"` re-runs
# the same contract on demand for callers that want to re-confirm out of band.
say '\nresult: %s\n' "$OUTPUT_FILE"
if [[ -n "${GATE_RUN_DIR_OVERRIDE:-}" ]]; then
  say 'run-dir: %s\n' "${GATE_RUN_DIR_OVERRIDE:-}"
fi

_FINAL_EXIT_VERDICT=$(grep -m1 '^Final: ' "$OUTPUT_FILE" 2>/dev/null | awk '{print $2}' || true)
if [[ "$_FINAL_EXIT_VERDICT" == "NO-GO" ]]; then
  exit 1
fi
