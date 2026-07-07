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
pmctl_cli="${PM_DISPATCH_PROMPT_CONTEXT_PMCTL:-$(cd "$(dirname "$0")/.." && pwd)/cli/pmctl}"
if [[ ! -f "$pmctl_cli" ]]; then
  exit 0
fi

# AUTOBUILD=0: never trigger a first full index build on the interactive prompt
# path (repos without an index stay silent); incremental refresh of an existing
# DB stays on. The timeout bounds prompt latency on slow repos; override via
# PM_DISPATCH_PROMPT_CONTEXT_TIMEOUT (seconds) when a slower bound is needed
# (e.g. tests on a CPU-saturated machine).
_timeout_secs="${PM_DISPATCH_PROMPT_CONTEXT_TIMEOUT:-10}"
[[ "$_timeout_secs" =~ ^[0-9]+$ ]] || _timeout_secs=10
_runner=(bash "$pmctl_cli")
if command -v timeout >/dev/null 2>&1; then
  _runner=(timeout "$_timeout_secs" bash "$pmctl_cli")
fi
out=$(PM_DISPATCH_CONTEXT_AUTOBUILD=0 "${_runner[@]}" \
  context prompt-scan "$repo_root" "$prompt" 2>/dev/null) || exit 0

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
