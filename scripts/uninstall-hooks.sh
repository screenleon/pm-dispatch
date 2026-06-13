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
REPO_ROOT="$repo_root"
# shellcheck source=scripts/lib/gate-workspace.sh
[[ -f "$repo_root/scripts/lib/gate-workspace.sh" ]] && . "$repo_root/scripts/lib/gate-workspace.sh"
if [[ -f "$repo_root/scripts/lib/allowlist.sh" ]]; then
  # shellcheck source=scripts/lib/allowlist.sh
  . "$repo_root/scripts/lib/allowlist.sh"
else
  # copy-mode fallback: scan adapters dynamically so removal stays concrete
  dispatch_allowlist_entries() {
    local f rel
    f="$REPO_ROOT/scripts/codex-dispatch.sh"
    if [[ -f "$f" ]]; then
      rel="${f#"$HOME/"}"
      printf 'Bash(%s:*)\nBash(~/%s:*)\n' "$f" "$rel"
    fi
    for f in "$REPO_ROOT/adapters"/*/dispatch.sh; do
      [[ -f "$f" ]] || continue
      rel="${f#"$HOME/"}"
      printf 'Bash(%s:*)\nBash(~/%s:*)\n' "$f" "$rel"
    done
  }
fi
# Honor an explicit CLAUDE_HOME override (passed per-call by uninstall.sh, or set
# when running standalone) so hook removal targets the same dir the install used.
# Defaults to ~/.claude.
CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
settings="$CLAUDE_HOME/settings.json"

if ! command -v jq >/dev/null 2>&1; then
  echo "uninstall-hooks: jq is required" >&2
  exit 2
fi

if [ ! -f "$settings" ]; then
  echo "uninstall-hooks: $settings not found — nothing to do"
  exit 0
fi

statusline_chain_conf="$CLAUDE_HOME/statusline-chain.conf"

tmp_new="$(mktemp)"
trap 'rm -f "$tmp_new"' EXIT

_chain_target=""
[[ -f "$statusline_chain_conf" ]] && _chain_target=$(head -1 "$statusline_chain_conf")

# CC-334: compute the reviewer Write glob to include in managed removal.
# gate_workspace_root is sourced from scripts/lib/gate-workspace.sh;
# falls back to inline detection if the lib is absent (copy-mode installs).
if command -v gate_workspace_root >/dev/null 2>&1; then
  _gate_ws="$(gate_workspace_root "$repo_root" "$HOME")"
else
  _gate_ws="${PM_DISPATCH_GATE_WORKSPACE:-$HOME}"
fi
# The three reviewer permission entries are managed install artifacts: they are
# added by install-hooks.sh and removed here. Bash(pmctl guard check:*) and
# Bash(mkdir -p:*) are treated as pm-dispatch-owned; re-add manually if needed
# for other tools after uninstall.
_managed_json="$({ dispatch_allowlist_entries; printf 'Write(%s/**/.gate-results/**)\nBash(pmctl guard check:*)\nBash(mkdir -p:*)\n' "$_gate_ws"; } | jq -Rn '[inputs]')"

# install-hooks.sh shell-escapes managed command paths (printf %q) so a repo
# checked out under a path with a space still produces a runnable hook. Match
# BOTH forms here: $repo_root (legacy unescaped installs) and its escaped prefix
# (current installs). printf %q escapes each char identically regardless of
# position, so the escaped command's prefix equals the escaped repo_root.
repo_root_q="$(printf '%q' "$repo_root")"

# MSYS2/Git-Bash rewrites `\` → `/` when passing args to a native jq.exe, which
# corrupts the printf %q escaping above so the prefix match misses managed
# entries. Disable that path conversion; no-op on Linux/macOS.
MSYS2_ARG_CONV_EXCL='*' MSYS_NO_PATHCONV=1 jq \
  --arg repo_root "$repo_root" \
  --arg repo_root_q "$repo_root_q" \
  --arg chain_target "$_chain_target" \
  --argjson managed_allow "$_managed_json" \
  '
  # An entry belongs to this install if its command starts with the repo root in
  # either raw or shell-escaped form.
  def in_repo: (. // "") | (startswith($repo_root + "/") or startswith($repo_root_q + "/"));

  # Remove all hook entries whose .command path starts with this repo root.
  ( [.hooks // {} | keys[]] ) as $event_types |
  reduce $event_types[] as $et (
    .;
    if (.hooks[$et] | type) == "array" then
      .hooks[$et] |= map(
        if (.hooks | type) == "array" then
          .hooks |= map(select(
            (.command | in_repo) | not
          ))
        else . end
      ) |
      .hooks[$et] |= map(select((.hooks // [] | length) > 0)) |
      if (.hooks[$et] | length) == 0 then del(.hooks[$et]) else . end
    else . end
  ) |
  # Remove statusLine if it points into this repo.
  (if (.statusLine.command | in_repo) then
    if $chain_target != "" then
      .statusLine = {"type": "command", "command": $chain_target}
    else
      del(.statusLine)
    end
  else . end) |
  if (.hooks // {} | length) == 0 then del(.hooks) else . end
  | if (.permissions.allow // [] | length) > 0 then
      .permissions.allow |= map(select(. as $e | ($managed_allow | index($e)) == null))
    else . end
  | if (.permissions.allow // [] | length) == 0 then del(.permissions.allow) else . end
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
