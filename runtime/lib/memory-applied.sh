#!/usr/bin/env bash
# memory-applied.sh — CC-567 applied/outcome sidecar: closes the
# matched/injected → selected → applied → outcome gap in `pmctl memory
# stats`. Source this file; do not execute directly.
#
# Design (see docs/memory-system.md "Applied/outcome funnel"):
#   - "selected" is not recorded separately — it is read directly from the
#     existing usage sidecar (memory_usage_sidecar_path / MEMORY_USAGE_ACC):
#     any card with access_count > 0 counts as selected. No new instrumentation.
#   - "applied" is recorded here, automatically, by scanning a dispatch brief's
#     content for any selected card's basename right after the brief has
#     passed brief-validate (see memory_applied_scan_brief, called from
#     pmctl_dispatch_run). This deliberately does NOT require the PM or any
#     host to actively call a new command — a prior design that would have
#     repeated this repo's own 8-12% skeleton-field fill-rate failure
#     (docs/memory-system.md "episode_fill_rate_pct").
#   - "outcome" is not recorded at all — pmctl_memory_stats joins applied
#     records to each run's own terminal state file, read-only
#     (_pmctl_memory_outcome_for_run in pmctl-memory.sh).
#
# Card relpaths reuse the CC-559 lossless TSV escaping from memory.sh
# (_memory_usage_tsv_escape / _memory_usage_tsv_unescape) — no second encoding
# scheme. Plain TSV only: this is an append-only event log with no frecency
# decay/update semantics, so the usage sidecar's sqlite backend does not apply.

# shellcheck source=runtime/lib/memory.sh
# shellcheck disable=SC1091
. "${BASH_SOURCE[0]%/*}/memory.sh"

# Path to the applied sidecar for a given memory dir. Same .pm-dispatch plane
# as the usage sidecar (memory_usage_sidecar_path), excluded from memory
# indexing.
memory_applied_sidecar_path() {
  local memory_dir="$1"
  printf '%s/.pm-dispatch/applied-usage.tsv' "${memory_dir%/}"
}

# Parsed applied sidecar, as parallel indexed arrays (one entry per record —
# unlike the usage sidecar this is an append-only log, not a keyed table, so
# there is no single card_relpath key to index by). Output globals rather
# than caller-named arrays, matching memory_usage_load's convention.
declare -a MEMORY_APPLIED_DAY=()
declare -a MEMORY_APPLIED_TASK=()
declare -a MEMORY_APPLIED_RUN=()
declare -a MEMORY_APPLIED_CARD=()

# Set to 1 when the sidecar exists but a row failed to parse (e.g. a
# corrupted day field). Callers must distinguish that from an absent
# sidecar/empty file: both yield zero rows, but only one means "no activity".
MEMORY_APPLIED_READ_FAILED=0

# security-reviewer-F001 (gate-20260825-150734-c20c52): refuse a symlinked
# .pm-dispatch parent directory or a symlinked/hardlinked applied-usage.tsv
# target BEFORE either write site below ever mkdir's or opens it. This write
# is automatic (fires on every `pmctl dispatch run`, no user confirmation),
# so a local attacker able to plant a symlink under the memory dir must not
# be able to redirect it onto an arbitrary attacker-chosen writable file.
# Modeled on pmctl-memory-config.sh's _pm_memory_config_write_guard — same
# threat shape, same accepted limitation: this is a check-then-write guard,
# not a claim of atomicity against a concurrent attacker who swaps the
# target between this check and the mkdir/append that follows it.
#   memory_applied_write_guard <sidecar>
memory_applied_write_guard() {
  local sidecar="$1" dir nlink
  [[ -n "$sidecar" ]] || return 1
  dir="$(dirname "$sidecar")"
  if [[ -L "$dir" || ( -e "$dir" && ! -d "$dir" ) ]]; then
    return 1
  fi
  if [[ -e "$sidecar" ]]; then
    [[ -f "$sidecar" && ! -L "$sidecar" ]] || return 1
    nlink="$(stat -c '%h' "$sidecar" 2>/dev/null || stat -f '%l' "$sidecar" 2>/dev/null || printf '1')"
    [[ "$nlink" == "1" ]] || return 1
  fi
  return 0
}

# Append one applied record: append-only, best-effort. mkdir -p + lock via
# serialize_with_lock when available, else a plain append (whole-line writes
# from a low-frequency caller make unlocked interleaving an acceptable worst
# case). Every error path returns 0 — the dispatch pipeline calling this must
# never be blocked or failed by a telemetry write failing.
#   memory_applied_record <sidecar> <card_relpath> <task_id> <run_id>
memory_applied_record() {
  local sidecar="$1" card_relpath="$2" task_id="$3" run_id="$4"
  [[ -n "$sidecar" && -n "$card_relpath" ]] || return 0
  memory_applied_write_guard "$sidecar" || return 0
  local day dir escaped_rel escaped_task escaped_run line
  day="$(( $(date +%s) / 86400 ))"
  dir="$(dirname "$sidecar")"
  mkdir -p "$dir" 2>/dev/null || return 0
  _memory_usage_tsv_escape escaped_rel "$card_relpath"
  _memory_usage_tsv_escape escaped_task "$task_id"
  _memory_usage_tsv_escape escaped_run "$run_id"
  line="$(printf '%s\t%s\t%s\t%s' "$day" "$escaped_task" "$escaped_run" "$escaped_rel")"
  if declare -F serialize_with_lock >/dev/null 2>&1; then
    serialize_with_lock "$sidecar" _memory_applied_append_line "$sidecar" "$line" 2>/dev/null || return 0
  else
    _memory_applied_append_line "$sidecar" "$line" 2>/dev/null || return 0
  fi
  return 0
}

# Inner function run under serialize_with_lock's subshell (or called
# directly when flock/mkdir-lock is unavailable). Not part of the public API.
_memory_applied_append_line() {
  local sidecar="$1" line="$2"
  printf '%s\n' "$line" >> "$sidecar"
}

# Batch form: append every already-formatted "day\ttask\trun\trel" line under
# ONE lock acquisition, for memory_applied_scan_brief's multi-match case.
# Not part of the public API.
_memory_applied_append_lines() {
  local sidecar="$1"; shift
  local line
  for line in "$@"; do
    printf '%s\n' "$line"
  done >> "$sidecar"
}

# Load the applied sidecar into MEMORY_APPLIED_DAY/TASK/RUN/CARD. Absent file
# is a valid empty result (MEMORY_APPLIED_READ_FAILED stays 0); a malformed
# row degrades that row's read (see caller-facing note above) without
# aborting the rest of the file.
#   memory_applied_load <sidecar>
memory_applied_load() {
  local sidecar="$1"
  MEMORY_APPLIED_DAY=()
  MEMORY_APPLIED_TASK=()
  MEMORY_APPLIED_RUN=()
  MEMORY_APPLIED_CARD=()
  MEMORY_APPLIED_READ_FAILED=0
  [[ -f "$sidecar" ]] || return 0

  local line rest day task_esc run_esc card_esc task_unesc run_unesc card_unesc tabs_only
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    # critic-F001: `read -r day task run card` alone can't tell a truncated
    # row (e.g. an interrupted append leaving only "day" or "day\ttask") from
    # a complete row whose task field is legitimately empty (task_id="" is a
    # valid value — see memory_applied_record) — `read` silently backfills
    # missing trailing variables as empty strings either way. Count tabs in
    # the raw line first: a complete row has exactly 3 (4 fields). Pure bash
    # (no awk/grep fork) since this runs once per row on every `pmctl memory
    # stats` call.
    tabs_only="${line//[^$'\t']/}"
    if [[ "${#tabs_only}" -ne 3 ]]; then
      MEMORY_APPLIED_READ_FAILED=1
      continue
    fi
    # security-reviewer round 3 / critic-F001 round 4: do NOT use
    # `IFS=$'\t' read ... <<<"$line"` here. Tab is one of POSIX's three "IFS
    # white space" characters, so bash collapses consecutive tab delimiters
    # and drops the resulting empty field regardless of what IFS is set to
    # — a row with a legitimately empty task_id (`day\t\trun\tcard`) would
    # silently shift task_esc/run_esc/card_esc left by one position,
    # corrupting run_esc and losing card_esc entirely, not just "losing"
    # the empty task field. Substring stripping has no such collapsing
    # behavior, so it is the only correct way to split on tab here.
    day="${line%%$'\t'*}"
    rest="${line#*$'\t'}"
    task_esc="${rest%%$'\t'*}"
    rest="${rest#*$'\t'}"
    run_esc="${rest%%$'\t'*}"
    card_esc="${rest#*$'\t'}"
    if [[ ! "$day" =~ ^[0-9]{1,10}$ ]]; then
      MEMORY_APPLIED_READ_FAILED=1
      continue
    fi
    # run/card are never legitimately empty (memory_applied_record refuses to
    # write a row without both); an empty one here means a corrupted field,
    # not a valid row with an empty value in it.
    if [[ -z "$run_esc" || -z "$card_esc" ]]; then
      MEMORY_APPLIED_READ_FAILED=1
      continue
    fi
    _memory_usage_tsv_unescape task_unesc "$task_esc"
    _memory_usage_tsv_unescape run_unesc "$run_esc"
    _memory_usage_tsv_unescape card_unesc "$card_esc"
    MEMORY_APPLIED_DAY+=("$day")
    MEMORY_APPLIED_TASK+=("$task_unesc")
    MEMORY_APPLIED_RUN+=("$run_unesc")
    MEMORY_APPLIED_CARD+=("$card_unesc")
  done < "$sidecar" || { MEMORY_APPLIED_READ_FAILED=1; return 1; }
  return 0
}

# memory_applied_scan_brief <repo_root> <brief_file> <run_id> [<task_id>]
#
# Best-effort, non-blocking (CC-567 design constraint 2/3): called from
# pmctl_dispatch_run right after the effective brief has passed
# brief-validate. Scans the brief's content for the basename of any card the
# usage sidecar has ever recorded a hit for (access_count > 0, i.e.
# "selected"), and records an applied event for each match. Purely additive
# side effect — every error path returns 0, and nothing here can change
# brief-validate's or dispatch's own exit status.
#
# The basename match is a plain substring test (grep -F), not a semantic
# citation check: this is an accepted approximation (see docs/memory-system.md
# and pre-impl "Assumptions / Open Questions"), not a claim that the brief's
# author actually reasoned about the card.
memory_applied_scan_brief() {
  local repo_root="$1" brief_file="$2" run_id="$3" task_id="${4:-}"
  [[ -f "$brief_file" ]] || return 0
  declare -F pmctl_memory_resolve >/dev/null 2>&1 || return 0

  command -v jq >/dev/null 2>&1 || return 0
  local resolution mem_dir
  resolution="$(pmctl_memory_resolve --repo-root "$repo_root" --allow-non-git --json 2>/dev/null)" || return 0
  mem_dir="$(jq -r '.memory_dir // empty' <<<"$resolution" 2>/dev/null)"
  [[ -n "$mem_dir" && -d "$mem_dir" ]] || return 0

  local usage_sidecar applied_sidecar rel base brief_content
  usage_sidecar="$(memory_usage_sidecar_path "$mem_dir")"
  memory_usage_load "$usage_sidecar" >/dev/null 2>&1 || true
  applied_sidecar="$(memory_applied_sidecar_path "$mem_dir")"

  # Read the brief once and match in-process (bash substring test, not a
  # `grep -F` fork per selected card): this runs on every `pmctl dispatch
  # run`, so N selected cards must not cost N forks + N file reads. Quoting
  # $base inside the glob keeps the match literal (grep -F equivalent), not
  # glob-special.
  brief_content="$(cat "$brief_file" 2>/dev/null)" || return 0

  local day escaped_task escaped_run escaped_rel line
  local -a matched_lines=()
  day="$(( $(date +%s) / 86400 ))"
  _memory_usage_tsv_escape escaped_task "$task_id"
  _memory_usage_tsv_escape escaped_run "$run_id"
  for rel in "${!MEMORY_USAGE_ACC[@]}"; do
    [[ "${MEMORY_USAGE_ACC[$rel]:-0}" -gt 0 ]] || continue
    base="${rel##*/}"
    base="${base%.md}"
    [[ -n "$base" ]] || continue
    if [[ "$brief_content" == *"$base"* ]]; then
      _memory_usage_tsv_escape escaped_rel "$rel"
      matched_lines+=("$(printf '%s\t%s\t%s\t%s' "$day" "$escaped_task" "$escaped_run" "$escaped_rel")")
    fi
  done
  [[ "${#matched_lines[@]}" -gt 0 ]] || return 0

  # One locked append for every match this scan found, instead of one
  # lock+open+write cycle per matched card.
  memory_applied_write_guard "$applied_sidecar" || return 0
  local dir; dir="$(dirname "$applied_sidecar")"
  mkdir -p "$dir" 2>/dev/null || return 0
  if declare -F serialize_with_lock >/dev/null 2>&1; then
    serialize_with_lock "$applied_sidecar" _memory_applied_append_lines "$applied_sidecar" "${matched_lines[@]}" 2>/dev/null || return 0
  else
    _memory_applied_append_lines "$applied_sidecar" "${matched_lines[@]}" 2>/dev/null || return 0
  fi
  return 0
}
