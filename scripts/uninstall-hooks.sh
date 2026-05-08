#!/usr/bin/env bash
# Remove the claude-config PreToolUse hooks from ~/.claude/settings.json.
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

tmp_new="$(mktemp)"
trap 'rm -f "$tmp_new"' EXIT

jq \
  --arg pm "$pm_cmd" \
  --arg cx "$cx_cmd" \
  --arg cxw "$cxw_cmd" \
  '
  if (.hooks // {}).PreToolUse then
    # Remove individual hook entries matching any managed command.
    .hooks.PreToolUse |= map(
      .hooks |= map(select(.command != $pm and .command != $cx and .command != $cxw))
    ) |
    # Drop matcher blocks whose hooks list is now empty.
    .hooks.PreToolUse |= map(select((.hooks | length) > 0)) |
    # Drop PreToolUse if empty.
    if (.hooks.PreToolUse | length) == 0 then del(.hooks.PreToolUse) else . end |
    # Drop hooks if empty.
    if (.hooks | length) == 0 then del(.hooks) else . end
  else . end
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
echo "uninstall-hooks: wrote $settings"
echo "uninstall-hooks: backup at $backup"
