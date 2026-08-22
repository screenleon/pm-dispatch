#!/usr/bin/env bash

if ! declare -F serialize_with_lock >/dev/null 2>&1; then
  # shellcheck source=runtime/lib/portable.sh
  # shellcheck disable=SC1091
  . "${BASH_SOURCE[0]%/*}/portable.sh" 2>/dev/null || true
fi

pmctl_artifacts_usage() {
  printf 'usage: pmctl artifacts list [--cd <work_dir>]\n' >&2
  printf '       pmctl artifacts show <run_id> [--cd <work_dir>]\n' >&2
  printf '       pmctl artifacts gc [--dry-run] [--keep-last N] [--max-age-days D]\n' >&2
  printf '                          [--grace-days D] [--cd <work_dir>] [--all-repos]\n' >&2
  printf '                          [--repos-root <dir>]\n' >&2
  printf '       pmctl artifacts migrate [--cd <work_dir>]\n' >&2
}

pmctl_artifacts_ensure_state_paths() {
  local repo_root="${1:-}"
  if [[ "$(type -t sw_project_run_dir 2>/dev/null)" != function ]]; then
    # ${repo_root:-} so a caller without repo_root in scope degrades to the legacy
    # fallback instead of tripping set -u; the dispatch core always binds it.
    local _sp_lib="${repo_root:-}/runtime/lib/state-paths.sh"
    if [[ -r "$_sp_lib" ]]; then
      # shellcheck disable=SC1090,SC1091  # dynamic repo-root path.
      . "$_sp_lib" 2>/dev/null || true
    fi
  fi
  if [[ "$(type -t sw_project_run_dir 2>/dev/null)" != function ]]; then
    printf 'pmctl artifacts: state-paths.sh unavailable; cannot resolve artifact run dirs\n' >&2
    return 2
  fi
}

pmctl_artifacts_parse_cd() {
  _PMCTL_ARTIFACTS_PARSE_HELP=0
  _PMCTL_ARTIFACTS_WORK_DIR="${1:-}"
  shift || true
  _PMCTL_ARTIFACTS_ARGS=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --cd)
        if [[ $# -lt 2 || -z "${2:-}" ]]; then
          printf 'pmctl artifacts: --cd requires a work dir\n' >&2
          return 2
        fi
        _PMCTL_ARTIFACTS_WORK_DIR="$2"
        shift 2
        ;;
      -h|--help)
        pmctl_artifacts_usage
        _PMCTL_ARTIFACTS_PARSE_HELP=1
        return 0
        ;;
      *)
        _PMCTL_ARTIFACTS_ARGS+=("$1")
        shift
        ;;
    esac
  done
}

pmctl_artifacts_runs_dir() {
  local work_dir="${1:-}" run_dir
  run_dir="$(cd "$work_dir" 2>/dev/null && sw_project_run_dir "__pmctl_artifacts_probe__" 2>/dev/null)" || return 1
  dirname "$run_dir"
}

pmctl_artifacts_file_mtime() {
  local path="${1:-}"
  stat -c '%Y' "$path" 2>/dev/null && return 0
  stat -f '%m' "$path" 2>/dev/null && return 0
  printf '0\n'
}

pmctl_artifacts_file_size() {
  local path="${1:-}"
  stat -c '%s' "$path" 2>/dev/null && return 0
  stat -f '%z' "$path" 2>/dev/null && return 0
  wc -c < "$path" | tr -d ' '
}

pmctl_artifacts_epoch_to_ts() {
  local epoch="${1:-0}"
  date -u -d "@$epoch" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null && return 0
  date -u -r "$epoch" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null && return 0
  printf '%s\n' "$epoch"
}

pmctl_artifacts_run_created_epoch() {
  local run_dir="${1:-}" footer newest=0 candidate
  for footer in "$run_dir"/*.footer; do
    [[ -e "$footer" ]] || continue
    candidate="$(pmctl_artifacts_file_mtime "$footer")"
    [[ "$candidate" =~ ^[0-9]+$ ]] || candidate=0
    (( candidate > newest )) && newest="$candidate"
  done
  if [[ "$newest" -eq 0 ]]; then
    newest="$(pmctl_artifacts_file_mtime "$run_dir")"
  fi
  printf '%s\n' "$newest"
}

pmctl_artifacts_list() {
  local repo_root="${1:-}" work_dir="${2:-}"
  shift 2 || true
  local runs_dir run_dir run_id epoch tmp_file any=0

  if [[ -z "$work_dir" ]]; then
    work_dir="$repo_root"
  fi
  if ! pmctl_artifacts_parse_cd "$work_dir" "$@"; then
    return 2
  fi
  if [[ "${_PMCTL_ARTIFACTS_PARSE_HELP:-0}" -eq 1 ]]; then
    return 0
  fi
  if [[ "${#_PMCTL_ARTIFACTS_ARGS[@]}" -ne 0 ]]; then
    printf 'pmctl artifacts list: unexpected argument: %s\n' "${_PMCTL_ARTIFACTS_ARGS[0]}" >&2
    pmctl_artifacts_usage
    return 2
  fi
  work_dir="$_PMCTL_ARTIFACTS_WORK_DIR"

  pmctl_artifacts_ensure_state_paths "$repo_root" || return $?
  runs_dir="$(pmctl_artifacts_runs_dir "$work_dir" 2>/dev/null)" || {
    printf 'pmctl artifacts list: cannot resolve project run directory for %s\n' "$work_dir" >&2
    return 2
  }
  if [[ ! -d "$runs_dir" ]]; then
    printf '(no runs found)\n'
    return 0
  fi

  tmp_file="$(mktemp "${TMPDIR:-/tmp}/pmctl-artifacts-list.XXXXXX")" || return 2
  for run_dir in "$runs_dir"/*; do
    [[ -d "$run_dir" ]] || continue
    run_id="$(basename "$run_dir")"
    epoch="$(pmctl_artifacts_run_created_epoch "$run_dir")"
    printf '%s\t%s\t%s\n' "$epoch" "$run_id" "$(pmctl_artifacts_epoch_to_ts "$epoch")" >> "$tmp_file"
    any=1
  done
  if [[ "$any" -eq 0 ]]; then
    rm -f "$tmp_file"
    printf '(no runs found)\n'
    return 0
  fi
  sort -rn "$tmp_file" | awk -F '\t' '{print $2 "\t" $3}'
  rm -f "$tmp_file"
}

pmctl_artifacts_show() {
  local repo_root="${1:-}" run_id="${2:-}" work_dir="${3:-}"
  shift 3 || true
  local run_dir file rel size tmp_file

  if [[ -z "$work_dir" ]]; then
    work_dir="$repo_root"
  fi
  if ! pmctl_artifacts_parse_cd "$work_dir" "$@"; then
    return 2
  fi
  if [[ "${_PMCTL_ARTIFACTS_PARSE_HELP:-0}" -eq 1 ]]; then
    return 0
  fi
  if [[ "${#_PMCTL_ARTIFACTS_ARGS[@]}" -gt 0 ]]; then
    if [[ -n "$run_id" ]]; then
      printf 'pmctl artifacts show: unexpected argument: %s\n' "${_PMCTL_ARTIFACTS_ARGS[0]}" >&2
      pmctl_artifacts_usage
      return 2
    fi
    run_id="${_PMCTL_ARTIFACTS_ARGS[0]}"
  fi
  work_dir="$_PMCTL_ARTIFACTS_WORK_DIR"
  if [[ -z "$run_id" ]]; then
    printf 'pmctl artifacts show: missing run_id\n' >&2
    pmctl_artifacts_usage
    return 2
  fi

  pmctl_artifacts_ensure_state_paths "$repo_root" || return $?
  run_dir="$(cd "$work_dir" 2>/dev/null && sw_project_run_dir "$run_id" 2>/dev/null)" || {
    printf 'pmctl artifacts show: cannot resolve run dir for %s under %s\n' "$run_id" "$work_dir" >&2
    return 2
  }
  if [[ ! -d "$run_dir" ]]; then
    printf 'pmctl artifacts show: run dir not found for %s: %s\n' "$run_id" "$run_dir" >&2
    printf 'pmctl artifacts show: run pmctl artifacts list --cd %q to see available runs\n' "$work_dir" >&2
    return 1
  fi

  tmp_file="$(mktemp "${TMPDIR:-/tmp}/pmctl-artifacts-show.XXXXXX")" || return 2
  while IFS= read -r file; do
    [[ -f "$file" ]] || continue
    rel="${file#"$run_dir"/}"
    size="$(pmctl_artifacts_file_size "$file")"
    printf '%s\t%s\n' "$size" "$rel" >> "$tmp_file"
  done < <(find "$run_dir" -type f | sort)
  if [[ ! -s "$tmp_file" ]]; then
    rm -f "$tmp_file"
    return 0
  fi
  cat "$tmp_file"
  rm -f "$tmp_file"
}

# _pmctl_artifacts_safe_rm_check <path> [leaf_registry...]
# Returns 0 if it is safe to rm -rf <path>, 1 if any safety assertion fails.
# Safety rules:
#   1. path must be absolute
#   2. path must NOT contain .pm-dispatch as a path component
#   3. path must end with one of the known artifact leaves, OR be a runs/<run_id>
#      directory where run_id contains no slashes or ..
_pmctl_artifacts_safe_rm_check() {
  local target="${1:-}"
  shift || true
  local known_leaves=("$@")

  if [[ -z "$target" || "$target" != /* ]]; then
    printf 'pmctl artifacts: safety check: path is not absolute: %s\n' "$target" >&2
    return 1
  fi
  # Component check: split by / and look for .pm-dispatch
  local part
  local IFS_SAVE="$IFS"
  IFS='/'
  # shellcheck disable=SC2206
  local parts=($target)
  IFS="$IFS_SAVE"
  for part in "${parts[@]}"; do
    if [[ "$part" == ".pm-dispatch" ]]; then
      printf 'pmctl artifacts: safety check: path contains .pm-dispatch — refusing: %s\n' "$target" >&2
      return 1
    fi
  done

  # Check if path ends with a known artifact leaf
  local base
  base="$(basename "$target")"
  local leaf found_leaf=0
  for leaf in "${known_leaves[@]}"; do
    if [[ "$base" == "$leaf" ]]; then
      found_leaf=1
      break
    fi
  done
  if [[ "$found_leaf" -eq 1 ]]; then
    return 0
  fi

  # Check if path looks like runs/<run_id> (run_id has no slashes or ..)
  local parent_base
  parent_base="$(basename "$(dirname "$target")")"
  if [[ "$parent_base" == "runs" && "$base" != */* && "$base" != *..*  ]]; then
    return 0
  fi

  printf 'pmctl artifacts: safety check: path does not match a known artifact pattern: %s\n' "$target" >&2
  return 1
}

_pmctl_artifacts_dir_size() {
  local path="${1:-}"
  du -sb "$path" 2>/dev/null | cut -f1 || du -sk "$path" 2>/dev/null | awk '{print $1 * 1024}' || printf '0'
}

# A run directory is prunable, but its analytical value (gate verdicts,
# reviewer findings, timing) is not -- once deleted it cannot be rebuilt. The
# functions below extract that value into a permanent runs-summary.jsonl
# sibling of runs/ (so summaries survive pruning) before any run directory is
# ever removed, and the summarizer is verified by reading its own write back
# before the source is allowed to be deleted.

_pmctl_artifacts_run_kind() {
  local run_dir="${1:-}"
  if [[ -d "$run_dir/.gate-results" ]]; then
    printf 'gate'
  else
    printf 'dispatch'
  fi
}

# Duration is the spread between the earliest and latest file mtime inside
# the run directory, not anything embedded in a filename -- run/gate id
# timestamps are known to drift from actual file mtimes (see CC-540 Problem).
# Batches into one `stat` invocation for every file (`+`, not `\;`) to avoid
# the per-item subprocess cost this repo has hit before (CC-557/CC-560).
_pmctl_artifacts_run_duration_seconds() {
  local run_dir="${1:-}" min="" max="" t
  while IFS= read -r t; do
    [[ "$t" =~ ^[0-9]+$ ]] || continue
    if [[ -z "$min" || "$t" -lt "$min" ]]; then min="$t"; fi
    if [[ -z "$max" || "$t" -gt "$max" ]]; then max="$t"; fi
  done < <(find "$run_dir" -type f -exec stat -c '%Y' {} + 2>/dev/null \
    || find "$run_dir" -type f -exec stat -f '%m' {} + 2>/dev/null)
  if [[ -z "$min" || -z "$max" ]]; then
    printf '0'
  else
    printf '%s' $(( max - min ))
  fi
}

_pmctl_artifacts_gate_result_file() {
  local run_dir="${1:-}"
  find "$run_dir/.gate-results" -maxdepth 1 -name 'gate-*.md' -type f 2>/dev/null | sort | tail -1
}

# Prints "reviewer: verdict" lines from the frontmatter `reviewers:` block.
# Reuses the fenced-frontmatter convention gate-result-verify.sh already
# parses with _gate_result_frontmatter_value; this walks the one nested map
# that helper doesn't cover.
_pmctl_artifacts_gate_reviewers_lines() {
  local gate_file="${1:-}"
  awk '
    BEGIN { s = 0; in_reviewers = 0 }
    /^---$/ { if (s == 0) { s = 1; next } else if (s == 1) { exit } }
    s && /^reviewers:/ { in_reviewers = 1; next }
    s && in_reviewers && /^[a-zA-Z_]/ { in_reviewers = 0 }
    s && in_reviewers && /^[[:space:]]+[a-zA-Z0-9_-]+:/ {
      line = $0
      sub(/^[[:space:]]+/, "", line)
      print line
    }
  ' "$gate_file"
}

# Best-effort finding-count-by-severity, grouped by reviewer. Degrades to the
# JSON string "unavailable" (never to an empty/zero result, which would read
# as "no findings" instead of "could not extract") when no reviewer_result_v1
# block is present or a block fails to parse -- schema has drifted across
# gate_result_version v1-v5 and old runs may not have parseable blocks.
_pmctl_artifacts_gate_findings_by_severity() {
  local gate_file="${1:-}" blocks
  blocks="$(awk '
    /^```reviewer_result_v1$/ { grab = 1; next }
    grab && /^```$/ { grab = 0; next }
    grab { print }
  ' "$gate_file")"
  if [[ -z "$blocks" ]]; then
    printf '"unavailable"'
    return 0
  fi
  if ! printf '%s' "$blocks" | jq -s -c '
      [ .[] | {reviewer, findings: (.findings // [])} ]
      | map({reviewer, counts: ((.findings | group_by(.severity)
          | map({(.[0].severity): length}) | add) // {})})
    ' 2>/dev/null; then
    printf '"unavailable"'
  fi
}

# Extracts one run's summary as a single JSON line. Never touches the run
# directory itself -- pure read, safe to call from --dry-run.
_pmctl_artifacts_run_summarize_json() {
  local run_dir="${1:-}" run_id="${2:-}" now_epoch="${3:-}"
  local kind status="complete" duration gate_file gate_json="null"
  local final tier most_severe reviewers_json findings_json
  kind="$(_pmctl_artifacts_run_kind "$run_dir")"
  duration="$(_pmctl_artifacts_run_duration_seconds "$run_dir")"
  if [[ "$kind" == gate ]]; then
    gate_file="$(_pmctl_artifacts_gate_result_file "$run_dir")"
    final=""
    if [[ -n "$gate_file" && -s "$gate_file" ]] \
        && declare -F _gate_result_frontmatter_value >/dev/null 2>&1; then
      final="$(_gate_result_frontmatter_value "$gate_file" final)"
    fi
    if [[ -z "$final" ]]; then
      status="incomplete_source"
    else
      tier="$(_gate_result_frontmatter_value "$gate_file" tier)"
      most_severe="$(_gate_result_frontmatter_value "$gate_file" most_severe)"
      reviewers_json="$(_pmctl_artifacts_gate_reviewers_lines "$gate_file" | jq -Rs '
        split("\n") | map(select(length > 0) | split(": ")) | map({(.[0]): .[1]}) | add // {}
      ')"
      findings_json="$(_pmctl_artifacts_gate_findings_by_severity "$gate_file")"
      gate_json="$(jq -nc \
        --arg final "$final" \
        --arg tier "${tier:-}" \
        --arg most_severe "${most_severe:-}" \
        --argjson reviewers "$reviewers_json" \
        --argjson findings_by_severity "$findings_json" '{
          final: $final,
          tier: (if $tier == "" then null else $tier end),
          most_severe: (if $most_severe == "" then null else $most_severe end),
          reviewers: $reviewers,
          findings_by_severity: $findings_by_severity
        }')"
    fi
  fi
  jq -nc \
    --arg run_id "$run_id" \
    --argjson summarized_at "$now_epoch" \
    --arg kind "$kind" \
    --arg status "$status" \
    --argjson duration_seconds "$duration" \
    --argjson gate "$gate_json" '{
      run_id: $run_id,
      summarized_at: $summarized_at,
      kind: $kind,
      status: $status,
      duration_seconds: $duration_seconds,
      gate: $gate
    }'
}

# Appends one summary line and reads it back to verify required fields
# survived the write before treating the run as safe to delete. A failed
# verification rolls the append back (so the summary file never carries a
# line that didn't pass its own check) and records why to prune-skipped.log
# -- the source run directory is left untouched either way.
# Looks up the most recent summarized_at for one run_id. Called fresh inside
# the per-project lock at decision time (see pmctl_artifacts_gc), never from
# a snapshot taken before the lock was acquired -- a snapshot loaded once per
# gc invocation is exactly the stale state a concurrent second gc process
# could act on (architecture-reviewer's finding).
_pmctl_artifacts_run_summary_lookup() {
  local summary_file="${1:-}" run_id="${2:-}"
  [[ -f "$summary_file" ]] || return 0
  # Apply the same structural contract _pmctl_artifacts_run_summary_append_verified
  # enforces at write time, again here at read time. Append-verification only
  # guards records THIS code path wrote; it says nothing about a line that
  # reached the file some other way (a manual edit, a future/older schema
  # version, on-disk corruption). Trusting "a matching run_id with a non-null
  # summarized_at exists" without re-checking that record's own validity
  # would let deletion proceed on a record that never actually met the
  # durability bar -- critic's finding. A record failing this check is
  # treated as "not yet validly summarized," forcing a fresh
  # summarize-and-verify for that run rather than trusting it.
  jq -r --arg run_id "$run_id" '
    select(.run_id == $run_id and .summarized_at != null and
      .kind != null and .status != null and
      (if .status == "complete" and .kind == "gate"
       then .gate.final != null
       else true end)) | .summarized_at
  ' "$summary_file" 2>/dev/null | tail -n 1
}

# Removes one line by exact content match rather than by position (`sed -i
# '$d'`). A rollback must never assume "the last line" is the one this call
# appended -- a concurrent writer holding a different lock generation could
# have appended after it, and deleting positionally would destroy that
# writer's valid record instead of the failed one.
_pmctl_artifacts_run_summary_prune_line() {
  local summary_file="${1:-}" line_to_remove="${2:-}"
  [[ -f "$summary_file" ]] || return 0
  local tmp
  tmp="$(mktemp "${summary_file}.XXXXXX")" || return 1
  grep -vF -- "$line_to_remove" "$summary_file" > "$tmp" 2>/dev/null || true
  mv -- "$tmp" "$summary_file"
}

_pmctl_artifacts_run_summary_append_verified() {
  local summary_json="${1:-}" summary_file="${2:-}" skip_log="${3:-}" run_id="${4:-}"
  local append_status=0
  printf '%s\n' "$summary_json" >> "$summary_file" || append_status=$?
  local last_line
  last_line="$(tail -n 1 "$summary_file")"
  # Require the read-back last line to actually be THIS run's record, not
  # merely well-formed -- an append that silently fails partway (or a
  # concurrent writer's append landing in between) would otherwise let
  # tail -n 1 read a prior, unrelated valid line and report false success,
  # which is exactly the fail-open path risk-reviewer flagged: the retained
  # summary is the only permanent record once the source run is deleted, so
  # "some valid-looking line exists" is not the same claim as "this run's
  # line was durably written." Only .gate.final is required when
  # status=complete: tier/most_severe are legitimately absent on older
  # gate_result_version schemas, so requiring them here would misclassify
  # honest historical data as an extraction failure and block those runs
  # from ever being pruned.
  if [[ "$append_status" -eq 0 ]] && printf '%s' "$last_line" | jq -e --arg run_id "$run_id" '
      (.run_id == $run_id) and (.summarized_at != null) and
      (.kind != null) and (.status != null) and
      (if .status == "complete" and .kind == "gate"
       then .gate.final != null
       else true end)
    ' >/dev/null 2>&1; then
    # An in-process read-back only proves the write reached the OS page
    # cache, not persistent storage -- a crash between here and the caller's
    # subsequent rm -rf (immediate under --grace-days 0) could lose the
    # summary while the source run directory is already gone, the exact
    # unrecoverable case this whole ticket exists to prevent (risk-reviewer's
    # finding). fsync the summary file before telling the caller this run is
    # safe to delete; a sync failure is treated the same as a verification
    # failure -- retain the run rather than claim a durability guarantee we
    # could not confirm.
    if sync -- "$summary_file" 2>/dev/null; then
      return 0
    fi
    printf '%s\trun=%s\tsummary fsync failed, durability unconfirmed, run directory retained\n' \
      "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$run_id" >> "$skip_log"
    return 1
  fi
  # Do not blindly delete "the last line" here: if a concurrent writer's
  # append landed after ours, the last line may not be ours to remove.
  # _pmctl_artifacts_run_summary_prune_line strips by exact JSON match
  # instead of by position.
  _pmctl_artifacts_run_summary_prune_line "$summary_file" "$summary_json"
  printf '%s\trun=%s\tverification failed, run directory retained: %s\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$run_id" "$last_line" >> "$skip_log"
  return 1
}

# Runs the full summarize/append-verify/grace/delete decision for one run
# under the caller's per-project lock (see serialize_with_lock in
# pmctl_artifacts_gc). Prints human-readable progress lines to stdout as it
# goes, then exactly one final line "RESULT<TAB>{deleted|would-delete|
# deferred|would-defer|skipped}<TAB>{bytes|0}" that the caller parses to
# update its counters -- this call runs in serialize_with_lock's subshell, so
# shell variables/arrays cannot cross back to the caller; stdout is the only
# channel.
_pmctl_artifacts_gc_process_run() {
  local run_dir="${1:-}" run_id="${2:-}" now_epoch="${3:-}" grace_seconds="${4:-}"
  local runs_summary_file="${5:-}" prune_skipped_log="${6:-}" dry_run="${7:-}"
  local run_size summarized_at summary_json remaining_seconds

  run_size="$(_pmctl_artifacts_dir_size "$run_dir")"
  # Fresh lookup, taken only after the lock is held -- never a value carried
  # in from before acquiring it.
  summarized_at="$(_pmctl_artifacts_run_summary_lookup "$runs_summary_file" "$run_id")"

  if [[ "$dry_run" -eq 1 ]]; then
    if [[ -z "$summarized_at" ]]; then
      summary_json="$(_pmctl_artifacts_run_summarize_json "$run_dir" "$run_id" "$now_epoch")"
      printf 'would summarize: %s  %s\n' "$run_id" "$summary_json"
      summarized_at="$now_epoch"
    fi
    remaining_seconds=$(( grace_seconds - (now_epoch - summarized_at) ))
    if (( remaining_seconds <= 0 )); then
      printf 'would delete: %s  (%s bytes)\n' "$run_id" "$run_size"
      printf 'RESULT\twould-delete\t%s\n' "$run_size"
    else
      printf 'would defer: %s  (grace period, %ds remaining)\n' "$run_id" "$remaining_seconds"
      printf 'RESULT\twould-defer\t0\n'
    fi
    return 0
  fi

  if [[ -z "$summarized_at" ]]; then
    summary_json="$(_pmctl_artifacts_run_summarize_json "$run_dir" "$run_id" "$now_epoch")"
    if ! _pmctl_artifacts_run_summary_append_verified \
        "$summary_json" "$runs_summary_file" "$prune_skipped_log" "$run_id"; then
      printf 'skipped (summary verification failed, see prune-skipped.log): %s\n' "$run_id"
      printf 'RESULT\tskipped\t0\n'
      return 0
    fi
    summarized_at="$now_epoch"
  fi

  remaining_seconds=$(( grace_seconds - (now_epoch - summarized_at) ))
  if (( remaining_seconds > 0 )); then
    printf 'summarized, deletion deferred (%ds remaining): %s\n' "$remaining_seconds" "$run_id"
    printf 'RESULT\tdeferred\t0\n'
    return 0
  fi

  if _pmctl_artifacts_safe_rm_check "$run_dir"; then
    printf 'deleted: %s  (%s bytes)\n' "$run_id" "$run_size"
    rm -rf "$run_dir"
    printf 'RESULT\tdeleted\t%s\n' "$run_size"
  else
    printf 'RESULT\tskipped\t0\n'
  fi
}

pmctl_artifacts_gc() {
  local repo_root="${1:-}" work_dir="${2:-}"
  shift 2 || true

  local dry_run=0 keep_last all_repos=0 repos_root max_age_days grace_days
  keep_last="${PM_DISPATCH_GC_KEEP_LAST:-10}"
  max_age_days="${PM_DISPATCH_GC_MAX_AGE_DAYS:-30}"
  grace_days="${PM_DISPATCH_GC_GRACE_DAYS:-3}"
  repos_root=""

  if [[ -z "$work_dir" ]]; then
    work_dir="$repo_root"
  fi

  local extra_args=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run) dry_run=1; shift ;;
      --keep-last)
        if [[ $# -lt 2 || ! "${2:-}" =~ ^[0-9]+$ || "${2:-}" -lt 1 ]]; then
          printf 'pmctl artifacts gc: --keep-last requires an integer >= 1\n' >&2; return 2
        fi
        keep_last="$2"; shift 2 ;;
      --max-age-days)
        if [[ $# -lt 2 || ! "${2:-}" =~ ^[0-9]+$ ]]; then
          printf 'pmctl artifacts gc: --max-age-days requires an integer >= 0\n' >&2; return 2
        fi
        max_age_days="$2"; shift 2 ;;
      --grace-days)
        if [[ $# -lt 2 || ! "${2:-}" =~ ^[0-9]+$ ]]; then
          printf 'pmctl artifacts gc: --grace-days requires an integer >= 0\n' >&2; return 2
        fi
        grace_days="$2"; shift 2 ;;
      --all-repos) all_repos=1; shift ;;
      --repos-root)
        if [[ $# -lt 2 || -z "${2:-}" ]]; then
          printf 'pmctl artifacts gc: --repos-root requires a directory\n' >&2; return 2
        fi
        repos_root="$2"; shift 2 ;;
      --cd)
        if [[ $# -lt 2 || -z "${2:-}" ]]; then
          printf 'pmctl artifacts gc: --cd requires a work dir\n' >&2; return 2
        fi
        work_dir="$2"; shift 2 ;;
      -h|--help) pmctl_artifacts_usage; return 0 ;;
      *) extra_args+=("$1"); shift ;;
    esac
  done
  if [[ "${#extra_args[@]}" -gt 0 ]]; then
    printf 'pmctl artifacts gc: unexpected argument: %s\n' "${extra_args[0]}" >&2
    pmctl_artifacts_usage; return 2
  fi

  if [[ -z "$repos_root" ]]; then
    if [[ "$(type -t pm_dispatch_repos_root 2>/dev/null)" != function ]]; then
      local repo_layout_sh="${repo_root}/runtime/lib/repo-layout.sh"
      if [[ -r "$repo_layout_sh" ]]; then
        # shellcheck disable=SC1090,SC1091
        . "$repo_layout_sh"
      fi
    fi
    repos_root="$(pm_dispatch_repos_root "$repo_root")" || return $?
  fi

  # Load PM_ARTIFACT_LEAVES from artifact-paths.sh
  local artifact_paths_sh
  artifact_paths_sh="${repo_root}/runtime/lib/artifact-paths.sh"
  if [[ -r "$artifact_paths_sh" ]]; then
    # shellcheck disable=SC1090,SC1091
    . "$artifact_paths_sh" 2>/dev/null || true
  fi
  local leaves=("${PM_ARTIFACT_LEAVES[@]-.agent-trace .gate-briefs .gate-results}")

  # --all-repos: scan repos-root for in-repo remnant leaves
  if [[ "$all_repos" -eq 1 ]]; then
    local total_found=0 total_removed=0 repo leaf_path leaf_size
    if [[ ! -d "$repos_root" ]]; then
      printf 'pmctl artifacts gc: --repos-root does not exist: %s\n' "$repos_root" >&2
      return 2
    fi
    for repo in "$repos_root"/*/; do
      [[ -d "$repo/.git" ]] || continue
      repo="${repo%/}"
      for leaf in "${leaves[@]}"; do
        leaf_path="$repo/$leaf"
        [[ -d "$leaf_path" ]] || continue
        # Skip empty dirs
        if [[ -z "$(ls -A "$leaf_path" 2>/dev/null)" ]]; then
          continue
        fi
        leaf_size="$(_pmctl_artifacts_dir_size "$leaf_path")"
        printf 'found: %s  (approx %s bytes)\n' "$leaf_path" "$leaf_size"
        (( total_found++ )) || true
        if [[ "$dry_run" -eq 0 ]]; then
          if _pmctl_artifacts_safe_rm_check "$leaf_path" "${leaves[@]}"; then
            rm -rf "$leaf_path"
            (( total_removed++ )) || true
          fi
        fi
      done
    done
    if [[ "$dry_run" -eq 1 ]]; then
      printf 'gc --all-repos: dry-run, found %d in-repo remnant directories\n' "$total_found"
    else
      printf 'gc --all-repos: removed %d in-repo remnant directories\n' "$total_removed"
    fi
    return 0
  fi

  # Per-partition GC
  pmctl_artifacts_ensure_state_paths "$repo_root" || return $?
  local runs_dir
  runs_dir="$(pmctl_artifacts_runs_dir "$work_dir" 2>/dev/null)" || {
    printf 'pmctl artifacts gc: cannot resolve project run directory for %s\n' "$work_dir" >&2
    return 2
  }
  if [[ ! -d "$runs_dir" ]]; then
    printf 'gc: deleted 0 runs, freed 0 bytes\n'
    return 0
  fi

  # Build sorted list of run dirs by mtime (newest first)
  local tmp_sort
  tmp_sort="$(mktemp "${TMPDIR:-/tmp}/pmctl-artifacts-gc.XXXXXX")" || return 2
  local run_dir mtime
  for run_dir in "$runs_dir"/*/; do
    [[ -d "$run_dir" ]] || continue
    run_dir="${run_dir%/}"
    mtime="$(pmctl_artifacts_file_mtime "$run_dir")"
    printf '%s\t%s\n' "$mtime" "$run_dir" >> "$tmp_sort"
  done

  # Sort newest-first
  local sorted_runs
  sorted_runs="$(sort -rn "$tmp_sort")"
  rm -f "$tmp_sort"

  local now_epoch
  now_epoch="$(date +%s 2>/dev/null || printf '0')"
  local max_age_seconds=$(( max_age_days * 86400 ))
  # A non-numeric PM_DISPATCH_GC_GRACE_DAYS reaching the arithmetic context
  # below would fail evaluation (or coerce unpredictably) rather than being
  # rejected -- validate it here the same way an explicit --grace-days flag
  # value already is, so a malformed override cannot silently collapse the
  # retention safety window this variable exists to provide. Deferred to
  # this point (not alongside the other GC_* defaults) so --all-repos, which
  # never consumes grace_days, is not blocked by an unrelated bad override.
  if ! [[ "$grace_days" =~ ^[0-9]+$ ]]; then
    printf 'pmctl artifacts gc: PM_DISPATCH_GC_GRACE_DAYS must be an integer >= 0: %s\n' \
      "$grace_days" >&2
    return 2
  fi
  local grace_seconds=$(( grace_days * 86400 ))

  # Every run directory is summarized (gate verdict, tier, reviewer findings
  # by severity, actual mtime-derived duration) before it is ever deleted --
  # never the reverse. Summaries persist outside runs/ so they survive
  # pruning; a run only physically deletes once its summary has existed for
  # at least --grace-days, so a bug in the summarizer itself is discoverable
  # (and re-runnable against the still-present source) before data is lost.
  local runs_summary_file prune_skipped_log
  runs_summary_file="$(dirname "$runs_dir")/runs-summary.jsonl"
  prune_skipped_log="$(dirname "$runs_dir")/prune-skipped.log"
  if ! declare -F _gate_result_frontmatter_value >/dev/null 2>&1; then
    local gate_verify_sh="${repo_root}/runtime/lib/gate-result-verify.sh"
    if [[ -r "$gate_verify_sh" ]]; then
      # shellcheck disable=SC1090,SC1091
      . "$gate_verify_sh" 2>/dev/null || true
    fi
  fi

  local rank=0 deleted=0 freed=0 pending=0 lock_failures=0
  local run_id run_mtime age_seconds
  local raw lock_status outcome_line outcome_kind outcome_size
  while IFS=$'\t' read -r run_mtime run_dir; do
    (( rank++ )) || true
    run_id="$(basename "$run_dir")"

    # Always keep the youngest keep_last runs
    if (( rank <= keep_last )); then
      continue
    fi

    # Check age filter (skip age check if max_age_days=0)
    if [[ "$max_age_days" -gt 0 ]]; then
      age_seconds=$(( now_epoch - run_mtime ))
      if (( age_seconds < max_age_seconds )); then
        continue
      fi
    fi

    # The entire summarize/append/verify/grace/delete decision for this run
    # happens atomically under one per-project lock so a concurrent second
    # gc invocation cannot act on a stale "is this summarized yet" snapshot
    # (architecture-reviewer's finding) -- the lookup inside
    # _pmctl_artifacts_gc_process_run is always fresh, taken after the lock
    # is held, never before. All human-readable progress lines the wrapped
    # call prints are passed straight through; the final RESULT-prefixed
    # line is this call's only structured output, parsed below.
    lock_status=0
    raw="$(serialize_with_lock "$runs_summary_file" _pmctl_artifacts_gc_process_run \
      "$run_dir" "$run_id" "$now_epoch" "$grace_seconds" \
      "$runs_summary_file" "$prune_skipped_log" "$dry_run")" || lock_status=$?
    printf '%s\n' "$raw" | grep -v $'^RESULT\t' || true
    # A lock timeout leaves $raw empty, so grep here legitimately finds no
    # match -- under `set -o pipefail` (this module is sourced by cli/pmctl,
    # which runs under `set -euo pipefail`) that makes the pipeline exit
    # nonzero, and without `|| true` this bare assignment would itself abort
    # the whole script via errexit before the lock-failure handling below
    # ever runs, well before its own `return 2` could ever fire.
    outcome_line="$(printf '%s\n' "$raw" | grep $'^RESULT\t' | tail -n 1 || true)"
    # A lock-acquisition failure (timeout, or the wrapped call erroring
    # before it could print its RESULT line) must not read as an ordinary
    # "nothing to do" outcome -- architecture-reviewer/risk-reviewer both
    # flagged that treating absent serialized output as zero-length success
    # lets an eligible run silently go unprocessed while gc still reports a
    # clean run. Surface it as a per-run error and make the whole invocation
    # exit nonzero so automation can detect it instead of trusting a summary
    # count that may have skipped runs.
    if [[ "$lock_status" -ne 0 || -z "$outcome_line" ]]; then
      printf 'pmctl artifacts gc: lock acquisition or processing failed for %s (exit %s); run left untouched\n' \
        "$run_id" "$lock_status" >&2
      (( lock_failures++ )) || true
      continue
    fi
    outcome_kind="$(printf '%s' "$outcome_line" | cut -f2)"
    outcome_size="$(printf '%s' "$outcome_line" | cut -f3)"
    case "$outcome_kind" in
      deleted) (( deleted++ )) || true; (( freed += outcome_size )) || true ;;
      would-delete) (( deleted++ )) || true ;;
      deferred|would-defer) (( pending++ )) || true ;;
      *) : ;;
    esac
  done <<< "$sorted_runs"

  if [[ "$dry_run" -eq 1 ]]; then
    printf 'gc: dry-run, would delete %d runs, %d deferred by grace period\n' "$deleted" "$pending"
  else
    printf 'gc: deleted %d runs, freed %d bytes, %d deferred by grace period\n' "$deleted" "$freed" "$pending"
  fi
  if (( lock_failures > 0 )); then
    printf 'gc: %d run(s) could not be processed due to lock acquisition failure -- see stderr above\n' \
      "$lock_failures" >&2
    return 2
  fi
}

pmctl_artifacts_migrate() {
  local repo_root="${1:-}" work_dir="${2:-}"
  shift 2 || true

  if [[ -z "$work_dir" ]]; then
    work_dir="$repo_root"
  fi

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --cd)
        if [[ $# -lt 2 || -z "${2:-}" ]]; then
          printf 'pmctl artifacts migrate: --cd requires a work dir\n' >&2; return 2
        fi
        work_dir="$2"; shift 2 ;;
      -h|--help) pmctl_artifacts_usage; return 0 ;;
      *)
        printf 'pmctl artifacts migrate: unexpected argument: %s\n' "$1" >&2
        pmctl_artifacts_usage; return 2 ;;
    esac
  done

  # Load PM_ARTIFACT_LEAVES
  local artifact_paths_sh
  artifact_paths_sh="${repo_root}/runtime/lib/artifact-paths.sh"
  if [[ -r "$artifact_paths_sh" ]]; then
    # shellcheck disable=SC1090,SC1091
    . "$artifact_paths_sh" 2>/dev/null || true
  fi
  local leaves=("${PM_ARTIFACT_LEAVES[@]-.agent-trace .gate-briefs .gate-results}")

  pmctl_artifacts_ensure_state_paths "$repo_root" || return $?

  local moved=0 leaf_path run_id dest mtime
  for leaf in "${leaves[@]}"; do
    leaf_path="${work_dir}/${leaf}"
    [[ -d "$leaf_path" ]] || continue

    # Generate synthetic run_id from leaf name + dir mtime
    mtime="$(pmctl_artifacts_file_mtime "$leaf_path")"
    run_id="migrate-${leaf#.}-${mtime}"

    dest="$(cd "$work_dir" 2>/dev/null && sw_project_run_dir "$run_id" 2>/dev/null)" || {
      printf 'pmctl artifacts migrate: cannot resolve destination for %s\n' "$leaf" >&2
      continue
    }

    if [[ -e "$dest" ]]; then
      printf 'skip (already migrated): %s -> %s\n' "$leaf_path" "$dest"
      continue
    fi

    mkdir -p "$(dirname "$dest")"
    if cp -a "$leaf_path" "$dest"; then
      printf 'migrated: %s -> %s\n' "$leaf_path" "$dest"
      (( moved++ )) || true
    else
      printf 'pmctl artifacts migrate: cp failed for %s\n' "$leaf_path" >&2
    fi
  done

  printf 'migrate: moved %d directories (originals preserved; verify then remove manually)\n' "$moved"
}
