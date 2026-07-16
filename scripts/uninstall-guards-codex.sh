#!/usr/bin/env bash
# Remove the pm-dispatch managed hook from $CODEX_HOME/hooks.json.
# Idempotent: skips entries that aren't present. Host-generic counterpart of
# uninstall-guards.sh (claude host); driven by hosts/codex/host.yaml the same
# way install-guards-codex.sh is.
#
# Usage:
#   scripts/uninstall-guards-codex.sh           # apply
#   scripts/uninstall-guards-codex.sh --dry-run # show what would change

set -euo pipefail

DRY_RUN=0
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT=""
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --repo-root)
      [[ "$#" -ge 2 ]] || { echo "uninstall-guards-codex: --repo-root requires a value" >&2; exit 2; }
      REPO_ROOT="$2"; shift 2 ;;
    *) echo "uninstall-guards-codex: unknown argument: $1 (usage: uninstall-guards-codex.sh [--repo-root <absolute-path>] [--dry-run])" >&2; exit 2 ;;
  esac
done
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
else
  case "$REPO_ROOT" in
    /*) ;;
    *) echo "uninstall-guards-codex: --repo-root must be absolute" >&2; exit 2 ;;
  esac
  REPO_ROOT="$(cd "$REPO_ROOT" 2>/dev/null && pwd -P)" || {
    echo "uninstall-guards-codex: --repo-root does not exist" >&2
    exit 2
  }
fi
[[ -f "$REPO_ROOT/hosts/codex/host.yaml" && -f "$REPO_ROOT/scripts/lib/host-manifest.sh" ]] || {
  echo "uninstall-guards-codex: --repo-root is not a compatible pm-dispatch checkout: $REPO_ROOT" >&2
  exit 2
}

# shellcheck source=scripts/lib/host-manifest.sh
. "$REPO_ROOT/scripts/lib/host-manifest.sh"
# shellcheck source=hosts/codex/lib/memory-contract.sh
. "$REPO_ROOT/hosts/codex/lib/memory-contract.sh"

if ! command -v jq >/dev/null 2>&1; then
  echo "uninstall-guards-codex: jq is required" >&2
  exit 2
fi

manifest="$(host_manifest_file "$REPO_ROOT" codex)"
if [[ ! -f "$manifest" ]]; then
  echo "uninstall-guards-codex: missing hosts/codex/host.yaml — nothing to do"
  exit 0
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

[[ -n "$hooks_path_template" ]] || { echo "uninstall-guards-codex: no managed codex-hooks-json target declared — nothing to do"; exit 0; }

hooks_file="$(host_manifest_expand_path "$REPO_ROOT" codex "$hooks_path_template")"
instructions_file=""
[[ -n "$instructions_path_template" ]] && instructions_file="$(host_manifest_expand_path "$REPO_ROOT" codex "$instructions_path_template")"

if [[ ! -f "$hooks_file" && ( -z "$instructions_file" || ! -f "$instructions_file" ) ]]; then
  echo "uninstall-guards-codex: $hooks_file not found — nothing to do"
  exit 0
fi

# uninstall.sh invokes this script unconditionally (symmetric teardown even
# when this checkout never opted into --enable-codex-command-guard), so
# $hooks_file may be user-owned Codex state pm-dispatch never wrote and never
# validated. A malformed/unrelated hooks.json must not abort a normal
# pm-dispatch uninstall under `set -e` — warn and skip instead of erroring,
# same as the "not wired, nothing to do" no-op path below.
if [[ -f "$hooks_file" ]] && ! jq empty "$hooks_file" 2>/dev/null; then
  echo "uninstall-guards-codex: $hooks_file is not valid JSON — skipping (unrelated/unmanaged Codex state, not modified)" >&2
  exit 0
fi

hook_cmd="$REPO_ROOT/scripts/hook-codex-command-guard.sh"
hook_cmd_q="$(printf '%q' "$hook_cmd")"
memory_hook_cmd="$REPO_ROOT/scripts/guard-inject-memory.sh"
memory_hook_cmd_q="$(printf '%q' "$memory_hook_cmd")"
session_hook_cmd="$REPO_ROOT/scripts/guard-session-summary.sh --host codex"
session_hook_cmd_q="$(printf '%q' "$REPO_ROOT/scripts/guard-session-summary.sh") --host codex"

tmp_new="$(mktemp)"
tmp_instructions_new="$(mktemp)"
trap 'rm -f "$tmp_new" "$tmp_instructions_new"' EXIT

# Match only the exact managed command identity THIS checkout's installer
# writes (install-guards-codex.sh:59) — not a basename+parent-dir heuristic,
# which would also strip a same-named hook-codex-command-guard.sh belonging
# to a different checkout or tool. Compare both the escaped form (current
# installer output) and the raw unescaped form (installs written before the
# shell-escape fix), so an older install still uninstalls cleanly.
if [[ -f "$hooks_file" ]]; then
  jq --arg cmd "$hook_cmd" --arg cmd_q "$hook_cmd_q" --arg memory_cmd "$memory_hook_cmd" --arg memory_cmd_q "$memory_hook_cmd_q" \
    --arg session_cmd "$session_hook_cmd" --arg session_cmd_q "$session_hook_cmd_q" '
    def is_managed: (. // "") | (. == $cmd or . == $cmd_q or . == $memory_cmd or . == $memory_cmd_q or . == $session_cmd or . == $session_cmd_q);
    ( [.hooks // {} | keys[]] ) as $event_types |
    reduce $event_types[] as $et (
      .;
      if (.hooks[$et] | type) == "array" then
        .hooks[$et] |= map(
          if (.hooks | type) == "array" then
            .hooks |= map(select((.command | is_managed) | not))
          else . end
        ) |
        .hooks[$et] |= map(select((.hooks // [] | length) > 0)) |
        if (.hooks[$et] | length) == 0 then del(.hooks[$et]) else . end
      else . end
    ) |
    if (.hooks // {} | length) == 0 then del(.hooks) else . end
    ' "$hooks_file" > "$tmp_new"
else
  printf '{}\n' > "$tmp_new"
fi

instructions_changed=0
instructions_remove=0
if [[ -n "$instructions_file" && -f "$instructions_file" ]]; then
  if ! codex_memory_contract_strip "$instructions_file" "$tmp_instructions_new"; then
    echo "uninstall-guards-codex: malformed managed markers in $instructions_file — preserving file" >&2
    cp "$instructions_file" "$tmp_instructions_new"
  fi
  cmp -s "$instructions_file" "$tmp_instructions_new" || instructions_changed=1
  [[ "$instructions_changed" -eq 1 && ! -s "$tmp_instructions_new" ]] && instructions_remove=1
fi

hooks_changed=0
[[ -f "$hooks_file" ]] && ! cmp -s "$hooks_file" "$tmp_new" && hooks_changed=1
if [[ "$hooks_changed" -eq 0 && "$instructions_changed" -eq 0 ]]; then
  echo "uninstall-guards-codex: not wired, nothing to do"
  exit 0
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
  if [[ "$hooks_changed" -eq 1 ]]; then
    echo "uninstall-guards-codex: would apply the following change to $hooks_file:"
    diff -u "$hooks_file" "$tmp_new" || true
  fi
  if [[ "$instructions_changed" -eq 1 ]]; then
    echo "uninstall-guards-codex: would apply the following change to $instructions_file:"
    if [[ "$instructions_remove" -eq 1 ]]; then
      diff -u "$instructions_file" /dev/null || true
    else
      diff -u "$instructions_file" "$tmp_instructions_new" || true
    fi
  fi
  exit 0
fi

timestamp="$(date +%Y%m%d-%H%M%S)"
if [[ "$hooks_changed" -eq 1 ]]; then
  backup="$hooks_file.bak.$timestamp"
  cp "$hooks_file" "$backup"
  mv "$tmp_new" "$hooks_file"
  echo "uninstall-guards-codex: wrote $hooks_file"
  echo "uninstall-guards-codex: backup at $backup"
fi
if [[ "$instructions_changed" -eq 1 ]]; then
  instructions_backup="$instructions_file.bak.$timestamp"
  cp "$instructions_file" "$instructions_backup"
  if [[ "$instructions_remove" -eq 1 ]]; then
    rm -f "$instructions_file"
    echo "uninstall-guards-codex: removed empty managed $instructions_file"
  else
    mv "$tmp_instructions_new" "$instructions_file"
    echo "uninstall-guards-codex: wrote $instructions_file"
  fi
  echo "uninstall-guards-codex: backup at $instructions_backup"
fi
trap - EXIT
