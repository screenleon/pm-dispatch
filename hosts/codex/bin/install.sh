#!/usr/bin/env bash
# shellcheck disable=SC1091
# Idempotently splice the pm-dispatch codex-host command guard into
# $CODEX_HOME/hooks.json (default ~/.codex/hooks.json).
#
# Host-generic counterpart of install-guards.sh (claude host), driven by
# hosts/codex/host.yaml's install_targets (id: hooks) and guard_bindings
# (command_guard) instead of hardcoding the path/format here — see
# runtime/lib/host-manifest.sh and docs/host-contract.md. Wires exactly one
# command guard plus the host-neutral canonical-memory UserPromptSubmit adapter.
#
# Usage:
#   hosts/codex/bin/install.sh --repo-root <checkout>           # apply
#   hosts/codex/bin/install.sh --repo-root <checkout> --dry-run # preview

set -euo pipefail

DRY_RUN=0
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT=""
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --repo-root)
      [[ "$#" -ge 2 ]] || { echo "install-guards-codex: --repo-root requires a value" >&2; exit 2; }
      REPO_ROOT="$2"; shift 2 ;;
    *) echo "install-guards-codex: unknown argument: $1 (usage: install-guards-codex.sh [--repo-root <absolute-path>] [--dry-run])" >&2; exit 2 ;;
  esac
done
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd -P)"
else
  case "$REPO_ROOT" in
    /*) ;;
    *) echo "install-guards-codex: --repo-root must be absolute" >&2; exit 2 ;;
  esac
  REPO_ROOT="$(cd "$REPO_ROOT" 2>/dev/null && pwd -P)" || {
    echo "install-guards-codex: --repo-root does not exist" >&2
    exit 2
  }
fi
[[ -f "$REPO_ROOT/hosts/codex/host.yaml" && -f "$REPO_ROOT/runtime/lib/host-manifest.sh" ]] || {
  echo "install-guards-codex: --repo-root is not a compatible pm-dispatch checkout: $REPO_ROOT" >&2
  exit 2
}

# shellcheck source=runtime/lib/host-manifest.sh
. "$REPO_ROOT/runtime/lib/host-manifest.sh"
# shellcheck source=hosts/codex/lib/hook-paths.sh
. "$REPO_ROOT/hosts/codex/lib/hook-paths.sh"
# shellcheck source=hosts/codex/lib/memory-contract.sh
. "$REPO_ROOT/hosts/codex/lib/memory-contract.sh"

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
instructions_path_template=""
while IFS=$'\t' read -r id path fmt managed; do
  [[ "$managed" == "true" ]] || continue
  if [[ "$id" == "hooks" && "$fmt" == "codex-hooks-json" ]]; then
    hooks_path_template="$path"
  elif [[ "$id" == "instructions" && "$fmt" == "codex-agents-md" ]]; then
    instructions_path_template="$path"
  fi
done < <(host_manifest_install_targets "$manifest")

if [[ -z "$hooks_path_template" ]]; then
  echo "install-guards-codex: hosts/codex/host.yaml has no managed codex-hooks-json install_target — nothing to wire" >&2
  exit 2
fi
if [[ -z "$instructions_path_template" ]]; then
  echo "install-guards-codex: hosts/codex/host.yaml has no managed codex-agents-md install_target — nothing to wire" >&2
  exit 2
fi

hooks_file="$(host_manifest_expand_path "$REPO_ROOT" codex "$hooks_path_template")"
instructions_file="$(host_manifest_expand_path "$REPO_ROOT" codex "$instructions_path_template")"
hook_cmd="$(codex_host_command_guard_path "$REPO_ROOT")"
legacy_hook_cmd="$(codex_host_command_guard_legacy_path "$REPO_ROOT")"
memory_hook_cmd="$REPO_ROOT/runtime/hooks/guard-inject-memory.sh"
session_hook_cmd="$REPO_ROOT/runtime/hooks/guard-session-summary.sh"
legacy_memory_hook_cmd="$REPO_ROOT/scripts/guard-inject-memory.sh"
legacy_session_hook_cmd="$REPO_ROOT/scripts/guard-session-summary.sh --host codex"
memory_update_module="$(host_manifest_scalar "$manifest" memory_update_module)"
if [[ -z "$memory_update_module" || "$memory_update_module" == "null" ]]; then
  echo "install-guards-codex: hosts/codex/host.yaml has no memory_update_module" >&2
  exit 2
fi
memory_update_cmd="$REPO_ROOT/$memory_update_module"

if [[ ! -x "$hook_cmd" || ! -x "$memory_hook_cmd" || ! -x "$session_hook_cmd" || ! -x "$memory_update_cmd" ]]; then
  echo "install-guards-codex: managed hook missing or not executable" >&2
  exit 2
fi

# Codex runs each hook `command` string through the shell, same as Claude's
# hooks.json (see install-guards.sh). An unquoted path with a space is
# word-split and the hook fails to launch, so shell-escape it before writing
# — printf %q only adds backslashes when needed, so space-free paths are
# stored verbatim (no churn for existing installs).
hook_cmd_q="$(printf '%q' "$hook_cmd")"
legacy_hook_cmd_q="$(printf '%q' "$legacy_hook_cmd")"
memory_hook_cmd_q="$(printf '%q' "$memory_hook_cmd")"
session_hook_cmd_q="$(printf '%q' "$session_hook_cmd") --host codex"
legacy_memory_hook_cmd_q="$(printf '%q' "$legacy_memory_hook_cmd")"
legacy_session_hook_cmd_q="$(printf '%q' "$REPO_ROOT/scripts/guard-session-summary.sh") --host codex"
memory_update_cmd_q="$(printf '%q' "$memory_update_cmd")"

tmp_new="$(mktemp)"
tmp_current="$(mktemp)"
tmp_instructions_new="$(mktemp)"
tmp_instructions_current="$(mktemp)"
trap 'rm -f "$tmp_new" "$tmp_current" "$tmp_instructions_new" "$tmp_instructions_current"' EXIT

if [[ -f "$hooks_file" ]]; then
  cp "$hooks_file" "$tmp_current"
else
  printf '{}\n' > "$tmp_current"
  [[ "$DRY_RUN" -eq 1 ]] && echo "install-guards-codex: would create $hooks_file"
fi

# Merge idempotently: only append the managed hook entry if no existing
# PreToolUse/Bash entry already points at this repo's guard script.
jq --arg cmd "$hook_cmd_q" --arg legacy_cmd "$legacy_hook_cmd" --arg legacy_cmd_q "$legacy_hook_cmd_q" \
  --arg memory_cmd "$memory_hook_cmd_q" --arg session_cmd "$session_hook_cmd_q" \
  --arg legacy_memory_cmd "$legacy_memory_hook_cmd" --arg legacy_memory_cmd_q "$legacy_memory_hook_cmd_q" \
  --arg legacy_session_cmd "$legacy_session_hook_cmd" --arg legacy_session_cmd_q "$legacy_session_hook_cmd_q" '
  .hooks = (.hooks // {}) |
  .hooks.PreToolUse = (.hooks.PreToolUse // []) |
  .hooks.UserPromptSubmit = (.hooks.UserPromptSubmit // []) |
  .hooks.Stop = (.hooks.Stop // []) |
  .hooks.PreToolUse |= map(
    if (.hooks | type) == "array" then
      .hooks |= map(select(.command != $legacy_cmd and .command != $legacy_cmd_q))
    else . end
  ) |
  .hooks.PreToolUse |= map(select((.hooks // [] | length) > 0)) |
  .hooks.UserPromptSubmit |= map(
    if (.hooks | type) == "array" then
      .hooks |= map(select(.command != $legacy_memory_cmd and .command != $legacy_memory_cmd_q))
    else . end
  ) |
  .hooks.UserPromptSubmit |= map(select((.hooks // [] | length) > 0)) |
  .hooks.Stop |= map(
    if (.hooks | type) == "array" then
      .hooks |= map(select(.command != $legacy_session_cmd and .command != $legacy_session_cmd_q))
    else . end
  ) |
  .hooks.Stop |= map(select((.hooks // [] | length) > 0)) |
  ([.hooks.PreToolUse[]? | select(.matcher == "Bash") | .hooks[]?.command] | index($cmd)) as $already |
  (if $already != null then . else .hooks.PreToolUse += [{"matcher": "Bash", "hooks": [{"type": "command", "command": $cmd}]}] end) |
  ([.hooks.UserPromptSubmit[]? | .hooks[]?.command] | index($memory_cmd)) as $memory_already |
  (if $memory_already != null then . else .hooks.UserPromptSubmit += [{"hooks": [{"type": "command", "command": $memory_cmd}]}] end) |
  ([.hooks.Stop[]? | .hooks[]?.command] | index($session_cmd)) as $session_already |
  if $session_already != null then . else .hooks.Stop += [{"hooks": [{"type": "command", "command": $session_cmd}]}] end
' "$tmp_current" > "$tmp_new"

if [[ -f "$instructions_file" ]]; then
  cp "$instructions_file" "$tmp_instructions_current"
else
  : > "$tmp_instructions_current"
  [[ "$DRY_RUN" -eq 1 ]] && echo "install-guards-codex: would create $instructions_file"
fi

if ! codex_memory_contract_strip "$tmp_instructions_current" "$tmp_instructions_new"; then
  echo "install-guards-codex: malformed managed markers in $instructions_file — refusing to modify" >&2
  exit 2
fi
codex_memory_contract_append "$tmp_instructions_new" "$memory_update_cmd_q"

hooks_changed=0
instructions_changed=0
cmp -s "$tmp_current" "$tmp_new" || hooks_changed=1
cmp -s "$tmp_instructions_current" "$tmp_instructions_new" || instructions_changed=1
if [[ "$hooks_changed" -eq 0 && "$instructions_changed" -eq 0 ]]; then
  echo "install-guards-codex: already wired, nothing to do"
  exit 0
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
  if [[ "$hooks_changed" -eq 1 ]]; then
    echo "install-guards-codex: would apply the following change to $hooks_file:"
    diff -u "$tmp_current" "$tmp_new" || true
  fi
  if [[ "$instructions_changed" -eq 1 ]]; then
    echo "install-guards-codex: would apply the following change to $instructions_file:"
    diff -u "$tmp_instructions_current" "$tmp_instructions_new" || true
  fi
  exit 0
fi

mkdir -p "$(dirname "$hooks_file")"
mkdir -p "$(dirname "$instructions_file")"
[[ -f "$hooks_file" ]] || printf '{}\n' > "$hooks_file"

timestamp="$(date +%Y%m%d-%H%M%S)"
if [[ "$hooks_changed" -eq 1 ]]; then
  backup="$hooks_file.bak.$timestamp"
  cp "$hooks_file" "$backup"
  mv "$tmp_new" "$hooks_file"
  echo "install-guards-codex: wrote $hooks_file"
  echo "install-guards-codex: backup at $backup"
fi
if [[ "$instructions_changed" -eq 1 ]]; then
  if [[ -f "$instructions_file" ]]; then
    instructions_backup="$instructions_file.bak.$timestamp"
    cp "$instructions_file" "$instructions_backup"
    echo "install-guards-codex: backup at $instructions_backup"
  fi
  mv "$tmp_instructions_new" "$instructions_file"
  echo "install-guards-codex: wrote $instructions_file"
fi
trap - EXIT
