#!/usr/bin/env bash
# Remove the pm-dispatch managed hooks from ~/.claude/settings.json.
# Idempotent: skips entries that aren't present.
#
# Usage:
#   scripts/uninstall-hooks.sh           # apply
#   scripts/uninstall-hooks.sh --dry-run # show what would change

set -euo pipefail

DRY_RUN=0
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=1

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
settings="$HOME/.claude/settings.json"

if ! command -v jq >/dev/null 2>&1; then
  echo "uninstall-hooks: jq is required" >&2
  exit 2
fi

if [ ! -f "$settings" ]; then
  echo "uninstall-hooks: $settings not found — nothing to do"
  exit 0
fi

pm_cmd="$repo_root/scripts/hook-pm-write-guard.sh"
cx_cmd="$repo_root/scripts/hook-codex-bash-guard.sh"
cxw_cmd="$repo_root/scripts/hook-codex-write-guard.sh"
stop_cmd="$repo_root/scripts/hook-log-claude-usage.sh"
old_stop_cmd="$repo_root/hooks/hook-log-claude-usage.sh"
session_cmd="$repo_root/scripts/hook-session-summary.sh"
inject_cmd="$repo_root/scripts/hook-inject-memory.sh"
statusline_cmd="$repo_root/scripts/hook-save-rate-limits.sh"
statusline_chain_conf="$HOME/.claude/statusline-chain.conf"

tmp_new="$(mktemp)"
trap 'rm -f "$tmp_new"' EXIT

_chain_target=""
[[ -f "$statusline_chain_conf" ]] && _chain_target=$(head -1 "$statusline_chain_conf")

jq \
  --arg pm "$pm_cmd" \
  --arg cx "$cx_cmd" \
  --arg cxw "$cxw_cmd" \
  --arg stop "$stop_cmd" \
  --arg old_stop "$old_stop_cmd" \
  --arg session "$session_cmd" \
  --arg inject "$inject_cmd" \
  --arg statusline "$statusline_cmd" \
  --arg chain_target "$_chain_target" \
  '
  (if (.hooks // {}).PreToolUse then
    # Remove individual hook entries matching any managed command.
    .hooks.PreToolUse |= map(
      .hooks |= map(select(
        ([
          ((.command | split("/") | last) == ($pm  | split("/") | last) and (.command | split("/") | .[-2]) == "scripts"),
          ((.command | split("/") | last) == ($cx  | split("/") | last) and (.command | split("/") | .[-2]) == "scripts"),
          ((.command | split("/") | last) == ($cxw | split("/") | last) and (.command | split("/") | .[-2]) == "scripts")
        ] | any) | not
      ))
    ) |
    # Drop matcher blocks whose hooks list is now empty.
    .hooks.PreToolUse |= map(select((.hooks | length) > 0)) |
    # Drop PreToolUse if empty.
    if (.hooks.PreToolUse | length) == 0 then del(.hooks.PreToolUse) else . end
  else . end) |
  (if (.hooks // {}).Stop then
    .hooks.Stop |= map(
      .hooks |= map(select(
        ([
          ((.command | split("/") | last) == ($stop    | split("/") | last) and (.command | split("/") | .[-2]) == "scripts"),
          ((.command | split("/") | last) == ($session | split("/") | last) and (.command | split("/") | .[-2]) == "scripts"),
          (.command == $old_stop)
        ] | any) | not
      ))
    ) |
    .hooks.Stop |= map(select((.hooks | length) > 0)) |
    if (.hooks.Stop | length) == 0 then del(.hooks.Stop) else . end
  else . end) |
  (if (.hooks // {}).UserPromptSubmit then
    .hooks.UserPromptSubmit |= map(
      .hooks |= map(select(
        ((.command | split("/") | last) == ($inject | split("/") | last) and (.command | split("/") | .[-2]) == "scripts") | not
      ))
    ) |
    .hooks.UserPromptSubmit |= map(select((.hooks | length) > 0)) |
    if (.hooks.UserPromptSubmit | length) == 0 then del(.hooks.UserPromptSubmit) else . end
  else . end) |
  (if ( ((.statusLine.command // "") | split("/") | last) == ($statusline | split("/") | last)
        and ((.statusLine.command // "") | split("/") | .[-2]) == "scripts" ) then
    if $chain_target != "" then
      .statusLine = {"type": "command", "command": $chain_target}
    else
      del(.statusLine)
    end
  else . end) |
  if (.hooks // {} | length) == 0 then del(.hooks) else . end
  ' "$settings" > "$tmp_new"

if cmp -s "$settings" "$tmp_new"; then
  echo "uninstall-hooks: not wired, nothing to do"
  exit 0
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "uninstall-hooks: would apply the following change:"
  diff -u "$settings" "$tmp_new" || true
  exit 0
fi

backup="$settings.bak.$(date +%Y%m%d-%H%M%S)"
cp "$settings" "$backup"
mv "$tmp_new" "$settings"
trap - EXIT
if [[ "$DRY_RUN" -eq 0 ]]; then
    rm -f "$statusline_chain_conf"
fi
echo "uninstall-hooks: wrote $settings"
echo "uninstall-hooks: backup at $backup"
