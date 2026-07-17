#!/usr/bin/env bash
# guard-inject-context.sh — UserPromptSubmit hook: inject knowledge-index hits.
#
# Behavior: extracts cwd + prompt from the Claude Code UserPromptSubmit JSON
# payload, resolves the git toplevel of cwd, and runs
# `pmctl context prompt-scan` against it. When the scan finds knowledge-domain
# hits (BACKLOG/DECISIONS/MILESTONES/docs), a pointer-only auto-context block is
# printed to stdout for injection; zero hits stay silent. This makes the
# "query before Read/Grep on knowledge docs" retrieval step deterministic
# instead of relying on a prose reflex (see docs/context-retrieval.md).
#
# Never blocks the prompt: every failure path exits 0 with no output.
#
# Kill-switch: PM_DISPATCH_DISABLE_PROMPT_CONTEXT=1 skips the scan entirely —
# use it when the live context DB must not be touched (e.g. while the full
# test suite is running against this repo).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
# shellcheck source=hosts/claude/lib/prompt-context-timeouts.sh
. "$SCRIPT_DIR/../../hosts/claude/lib/prompt-context-timeouts.sh"

if [[ "${PM_DISPATCH_DISABLE_PROMPT_CONTEXT:-0}" == "1" ]]; then
  exit 0
fi

payload=$(cat)
if [[ -z "$payload" ]]; then
  exit 0
fi

_tmp=$(mktemp)
trap 'rm -f "$_tmp"' EXIT
printf '%s' "$payload" > "$_tmp"

cwd=$(jq -r 'if (.cwd | type) == "string" then .cwd else empty end' "$_tmp" 2>/dev/null) || cwd=""
if [[ -z "$cwd" || ! -d "$cwd" ]]; then
  exit 0
fi

prompt=$(jq -r 'if (.prompt | type) == "string" then .prompt else empty end' "$_tmp" 2>/dev/null) || prompt=""
# Trivially short prompts carry no extractable terms — stay silent.
if [[ "${#prompt}" -lt 12 ]]; then
  exit 0
fi

repo_root=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null) || exit 0
if [[ -z "$repo_root" ]]; then
  exit 0
fi

# PM_DISPATCH_PROMPT_CONTEXT_PMCTL overrides the pmctl entrypoint (non-standard
# install layouts; also the seam the timeout regression test drives).
pmctl_cli="${PM_DISPATCH_PROMPT_CONTEXT_PMCTL:-$(cd "$(dirname "$0")/../.." && pwd)/cli/pmctl}"
if [[ ! -f "$pmctl_cli" ]]; then
  exit 0
fi

# Context is an optional sqlite-backed capability. Without sqlite3, stay silent
# and do not attempt pmctl; with sqlite3, the first real prompt auto-bootstraps
# the repo-local DB. Initial builds get a larger budget than incremental scans.
command -v sqlite3 >/dev/null 2>&1 || exit 0
_context_db="$repo_root/.pm-dispatch/ctx/context.db"
_initial_build=0
if [[ ! -f "$_context_db" ]]; then
  _initial_build=1
else
  # An interrupted initial build can leave a SQLite schema without committed
  # file rows. Only a confirmed numeric zero is treated as incomplete; a locked
  # or unreadable DB stays on the non-destructive incremental path.
  _indexed_files="$(sqlite3 "$_context_db" 'SELECT count(*) FROM files;' 2>/dev/null || true)"
  if [[ "$_indexed_files" == "0" ]]; then
    _initial_build=1
  fi
fi
if [[ "$_initial_build" -eq 1 ]]; then
  _timeout_secs="${PM_DISPATCH_PROMPT_CONTEXT_INITIAL_TIMEOUT:-$PROMPT_CONTEXT_INITIAL_TIMEOUT_DEFAULT}"
else
  _timeout_secs="${PM_DISPATCH_PROMPT_CONTEXT_TIMEOUT:-$PROMPT_CONTEXT_REFRESH_TIMEOUT_DEFAULT}"
fi
if [[ ! "$_timeout_secs" =~ ^[0-9]+$ ]]; then
  if [[ "$_initial_build" -eq 1 ]]; then
    _timeout_secs="$PROMPT_CONTEXT_INITIAL_TIMEOUT_DEFAULT"
  else
    _timeout_secs="$PROMPT_CONTEXT_REFRESH_TIMEOUT_DEFAULT"
  fi
fi
_runner=(bash "$pmctl_cli")
if command -v timeout >/dev/null 2>&1; then
  _runner=(timeout "$_timeout_secs" bash "$pmctl_cli")
fi
_scan_rc=0
out=$(PM_DISPATCH_CONTEXT_AUTOBUILD=1 "${_runner[@]}" \
  context prompt-scan "$repo_root" "$prompt" 2>/dev/null) || _scan_rc=$?
if [[ "$_scan_rc" -ne 0 ]]; then
  # A timeout during first build can leave an initialized-but-empty derived DB.
  # Remove only that cache so the next prompt still receives the initial-build
  # budget instead of misclassifying it as an existing index forever.
  if [[ "$_initial_build" -eq 1 ]]; then
    _indexed_files="$(sqlite3 "$_context_db" 'SELECT count(*) FROM files;' 2>/dev/null || true)"
    # This is a derived cache and the initial build did not complete. Preserve
    # it only when SQLite can positively confirm committed file rows; a missing
    # schema, unreadable/locked shell, or zero rows is not a usable index and
    # must not make the next prompt take the shorter refresh path.
    if [[ ! "$_indexed_files" =~ ^[1-9][0-9]*$ ]]; then
      rm -f -- "$_context_db" "${_context_db}-wal" "${_context_db}-shm" 2>/dev/null || true
    fi
  fi
  exit 0
fi

if [[ -z "$out" || "$out" == "knowledge_hits: []" ]]; then
  exit 0
fi
if ! grep -q '^knowledge_hits:' <<<"$out"; then
  exit 0
fi

printf '=== auto-context: knowledge index hits ===\n'
printf 'Repo: %s | pointer-only; cite refs instead of re-deriving from full-file reads\n' "$repo_root"
printf '%s\n' "$out"
printf 'More: pmctl context query %s --domain knowledge <term>\n' "$repo_root"
printf '=== end auto-context ===\n'
exit 0
