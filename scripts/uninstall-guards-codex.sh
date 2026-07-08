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
case "${1:-}" in
  --dry-run) DRY_RUN=1 ;;
  "") : ;;
  *)
    echo "uninstall-guards-codex: unknown argument: $1 (usage: uninstall-guards-codex.sh [--dry-run])" >&2
    exit 2
    ;;
esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=scripts/lib/host-manifest.sh
. "$SCRIPT_DIR/lib/host-manifest.sh"

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
while IFS=$'\t' read -r id path fmt managed; do
  [[ "$id" == "hooks" ]] || continue
  [[ "$fmt" == "codex-hooks-json" ]] || continue
  [[ "$managed" == "true" ]] || continue
  hooks_path_template="$path"
done < <(host_manifest_install_targets "$manifest")

[[ -n "$hooks_path_template" ]] || { echo "uninstall-guards-codex: no managed codex-hooks-json target declared — nothing to do"; exit 0; }

hooks_file="$(host_manifest_expand_path "$hooks_path_template")"

if [[ ! -f "$hooks_file" ]]; then
  echo "uninstall-guards-codex: $hooks_file not found — nothing to do"
  exit 0
fi

hook_cmd="$REPO_ROOT/scripts/hook-codex-command-guard.sh"
hook_cmd_q="$(printf '%q' "$hook_cmd")"

tmp_new="$(mktemp)"
trap 'rm -f "$tmp_new"' EXIT

# Match only the exact managed command identity THIS checkout's installer
# writes (install-guards-codex.sh:59) — not a basename+parent-dir heuristic,
# which would also strip a same-named hook-codex-command-guard.sh belonging
# to a different checkout or tool. Compare both the escaped form (current
# installer output) and the raw unescaped form (installs written before the
# shell-escape fix), so an older install still uninstalls cleanly.
jq --arg cmd "$hook_cmd" --arg cmd_q "$hook_cmd_q" '
  def is_managed: (. // "") | (. == $cmd or . == $cmd_q);
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

if cmp -s "$hooks_file" "$tmp_new"; then
  echo "uninstall-guards-codex: not wired, nothing to do"
  exit 0
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "uninstall-guards-codex: would apply the following change:"
  diff -u "$hooks_file" "$tmp_new" || true
  exit 0
fi

backup="$hooks_file.bak.$(date +%Y%m%d-%H%M%S)"
cp "$hooks_file" "$backup"
mv "$tmp_new" "$hooks_file"
trap - EXIT
echo "uninstall-guards-codex: wrote $hooks_file"
echo "uninstall-guards-codex: backup at $backup"
