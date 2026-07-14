#!/usr/bin/env bash
# Idempotently splice the pm-dispatch codex-host command guard into
# $CODEX_HOME/hooks.json (default ~/.codex/hooks.json).
#
# Host-generic counterpart of install-guards.sh (claude host), driven by
# hosts/codex/host.yaml's install_targets (id: hooks) and guard_bindings
# (command_guard) instead of hardcoding the path/format here — see
# scripts/lib/host-manifest.sh and docs/host-contract.md. Wires exactly one
# command guard plus the host-neutral canonical-memory UserPromptSubmit adapter.
#
# Usage:
#   scripts/install-guards-codex.sh              # apply
#   scripts/install-guards-codex.sh --dry-run    # show what would change

set -euo pipefail

DRY_RUN=0
case "${1:-}" in
  --dry-run) DRY_RUN=1 ;;
  "") : ;;
  *)
    echo "install-guards-codex: unknown argument: $1 (usage: install-guards-codex.sh [--dry-run])" >&2
    exit 2
    ;;
esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=scripts/lib/host-manifest.sh
. "$SCRIPT_DIR/lib/host-manifest.sh"

if ! command -v jq >/dev/null 2>&1; then
  echo "install-guards-codex: jq is required but not found on PATH" >&2
  exit 2
fi

manifest="$(host_manifest_file "$REPO_ROOT" codex)"
if [[ ! -f "$manifest" ]]; then
  echo "install-guards-codex: missing hosts/codex/host.yaml — nothing to wire" >&2
  exit 2
fi

hooks_path_template=""
while IFS=$'\t' read -r id path fmt managed; do
  [[ "$id" == "hooks" ]] || continue
  [[ "$fmt" == "codex-hooks-json" ]] || continue
  [[ "$managed" == "true" ]] || continue
  hooks_path_template="$path"
done < <(host_manifest_install_targets "$manifest")

if [[ -z "$hooks_path_template" ]]; then
  echo "install-guards-codex: hosts/codex/host.yaml has no managed codex-hooks-json install_target — nothing to wire" >&2
  exit 2
fi

hooks_file="$(host_manifest_expand_path "$hooks_path_template")"
hook_cmd="$REPO_ROOT/scripts/hook-codex-command-guard.sh"
memory_hook_cmd="$REPO_ROOT/scripts/guard-inject-memory.sh"

if [[ ! -x "$hook_cmd" || ! -x "$memory_hook_cmd" ]]; then
  echo "install-guards-codex: managed hook missing or not executable" >&2
  exit 2
fi

# Codex runs each hook `command` string through the shell, same as Claude's
# hooks.json (see install-guards.sh). An unquoted path with a space is
# word-split and the hook fails to launch, so shell-escape it before writing
# — printf %q only adds backslashes when needed, so space-free paths are
# stored verbatim (no churn for existing installs).
hook_cmd_q="$(printf '%q' "$hook_cmd")"
memory_hook_cmd_q="$(printf '%q' "$memory_hook_cmd")"

tmp_new="$(mktemp)"
tmp_current="$(mktemp)"
trap 'rm -f "$tmp_new" "$tmp_current"' EXIT

if [[ -f "$hooks_file" ]]; then
  cp "$hooks_file" "$tmp_current"
else
  printf '{}\n' > "$tmp_current"
  [[ "$DRY_RUN" -eq 1 ]] && echo "install-guards-codex: would create $hooks_file"
fi

# Merge idempotently: only append the managed hook entry if no existing
# PreToolUse/Bash entry already points at this repo's guard script.
jq --arg cmd "$hook_cmd_q" --arg memory_cmd "$memory_hook_cmd_q" '
  .hooks = (.hooks // {}) |
  .hooks.PreToolUse = (.hooks.PreToolUse // []) |
  .hooks.UserPromptSubmit = (.hooks.UserPromptSubmit // []) |
  ([.hooks.PreToolUse[]? | select(.matcher == "Bash") | .hooks[]?.command] | index($cmd)) as $already |
  (if $already != null then . else .hooks.PreToolUse += [{"matcher": "Bash", "hooks": [{"type": "command", "command": $cmd}]}] end) |
  ([.hooks.UserPromptSubmit[]? | .hooks[]?.command] | index($memory_cmd)) as $memory_already |
  if $memory_already != null then .
  else .hooks.UserPromptSubmit += [{"hooks": [{"type": "command", "command": $memory_cmd}]}]
  end
' "$tmp_current" > "$tmp_new"

if cmp -s "$tmp_current" "$tmp_new"; then
  echo "install-guards-codex: already wired, nothing to do"
  exit 0
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "install-guards-codex: would apply the following change to $hooks_file:"
  diff -u "$tmp_current" "$tmp_new" || true
  exit 0
fi

mkdir -p "$(dirname "$hooks_file")"
[[ -f "$hooks_file" ]] || printf '{}\n' > "$hooks_file"

backup="$hooks_file.bak.$(date +%Y%m%d-%H%M%S)"
cp "$hooks_file" "$backup"
mv "$tmp_new" "$hooks_file"
trap - EXIT
echo "install-guards-codex: wrote $hooks_file"
echo "install-guards-codex: backup at $backup"
