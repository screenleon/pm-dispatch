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

statusline_chain_conf="$HOME/.claude/statusline-chain.conf"

tmp_new="$(mktemp)"
trap 'rm -f "$tmp_new"' EXIT

_chain_target=""
[[ -f "$statusline_chain_conf" ]] && _chain_target=$(head -1 "$statusline_chain_conf")

jq \
  --arg repo_root "$repo_root" \
  --arg chain_target "$_chain_target" \
  '
  # Remove all hook entries whose .command path starts with this repo root.
  ( [.hooks // {} | keys[]] ) as $event_types |
  reduce $event_types[] as $et (
    .;
    if (.hooks[$et] | type) == "array" then
      .hooks[$et] |= map(
        if (.hooks | type) == "array" then
          .hooks |= map(select(
            ((.command // "") | startswith($repo_root + "/")) | not
          ))
        else . end
      ) |
      .hooks[$et] |= map(select((.hooks // [] | length) > 0)) |
      if (.hooks[$et] | length) == 0 then del(.hooks[$et]) else . end
    else . end
  ) |
  # Remove statusLine if it points into this repo.
  (if ((.statusLine.command // "") | startswith($repo_root + "/")) then
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
