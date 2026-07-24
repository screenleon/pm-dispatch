#!/usr/bin/env bash
# Shared prompt-context scan primitive.
#
# Host adapters normalize their native event payload into
# PM_PROMPT_CONTEXT_CWD and PM_PROMPT_CONTEXT_PROMPT, then call
# pm_prompt_context_scan.  This layer intentionally knows nothing about a
# host's JSON shape, hook timeout, or configuration home.

pm_prompt_context_scan() {
  local cwd="${PM_PROMPT_CONTEXT_CWD:-}" prompt="${PM_PROMPT_CONTEXT_PROMPT:-}"
  local repo_root pmctl_cli context_db indexed_files initial_build timeout_secs scan_rc=0 out

  [[ -n "$cwd" && -d "$cwd" && ${#prompt} -ge 12 ]] || return 0
  repo_root="$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null)" || return 0
  [[ -n "$repo_root" ]] || return 0

  pmctl_cli="${PM_DISPATCH_PROMPT_CONTEXT_PMCTL:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/cli/pmctl}"
  [[ -f "$pmctl_cli" ]] || return 0
  command -v sqlite3 >/dev/null 2>&1 || return 0

  context_db="$repo_root/.pm-dispatch/ctx/context.db"
  initial_build=0
  if [[ ! -f "$context_db" ]]; then
    initial_build=1
  else
    indexed_files="$(sqlite3 "$context_db" 'SELECT count(*) FROM files;' 2>/dev/null || true)"
    if [[ "$indexed_files" == "0" ]]; then
      initial_build=1
    fi
  fi
  if [[ "$initial_build" -eq 1 ]]; then
    timeout_secs="${PM_PROMPT_CONTEXT_INITIAL_TIMEOUT:-120}"
  else
    timeout_secs="${PM_PROMPT_CONTEXT_TIMEOUT:-45}"
  fi
  if [[ ! "$timeout_secs" =~ ^[0-9]+$ ]]; then
    if [[ "$initial_build" -eq 1 ]]; then
      timeout_secs=120
    else
      timeout_secs=45
    fi
  fi

  if command -v timeout >/dev/null 2>&1; then
    out="$(PM_DISPATCH_CONTEXT_AUTOBUILD=1 timeout "$timeout_secs" bash "$pmctl_cli" context prompt-scan "$repo_root" "$prompt" 2>/dev/null)" || scan_rc=$?
  else
    out="$(PM_DISPATCH_CONTEXT_AUTOBUILD=1 bash "$pmctl_cli" context prompt-scan "$repo_root" "$prompt" 2>/dev/null)" || scan_rc=$?
  fi
  if [[ "$scan_rc" -ne 0 ]]; then
    if [[ "$initial_build" -eq 1 ]]; then
      indexed_files="$(sqlite3 "$context_db" 'SELECT count(*) FROM files;' 2>/dev/null || true)"
      if [[ ! "$indexed_files" =~ ^[1-9][0-9]*$ ]]; then
        rm -f -- "$context_db" "${context_db}-wal" "${context_db}-shm" 2>/dev/null || true
      fi
    fi
    return 0
  fi
  [[ -n "$out" && "$out" != "knowledge_hits: []" ]] || return 0
  grep -q '^knowledge_hits:' <<<"$out" || return 0
  printf '=== auto-context: knowledge index hits ===\n'
  printf 'Repo: %s | pointer-only; cite refs instead of re-deriving from full-file reads\n' "$repo_root"
  printf '%s\n' "$out"
  printf 'More: pmctl context query %s --domain knowledge <term>\n' "$repo_root"
  printf '=== end auto-context ===\n'
}
