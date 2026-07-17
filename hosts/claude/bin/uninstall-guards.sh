#!/usr/bin/env bash
# shellcheck disable=SC1091
# Remove the pm-dispatch managed hooks from ~/.claude/settings.json.
# Idempotent: skips entries that aren't present.
#
# Usage:
#   hosts/claude/bin/uninstall-guards.sh --repo-root <checkout>
#   hosts/claude/bin/uninstall-guards.sh --repo-root <checkout> --dry-run

set -euo pipefail

DRY_RUN=0
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --repo-root)
      [[ $# -ge 2 ]] || { echo "uninstall-guards: --repo-root requires a value" >&2; exit 2; }
      REPO_ROOT="$2"; shift 2 ;;
    *) echo "uninstall-guards: unknown flag $1" >&2; exit 2 ;;
  esac
done
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd -P)"
else
  case "$REPO_ROOT" in
    /*) ;;
    *) echo "uninstall-guards: --repo-root must be absolute" >&2; exit 2 ;;
  esac
  (cd "$REPO_ROOT" 2>/dev/null) || {
    echo "uninstall-guards: --repo-root does not exist" >&2
    exit 2
  }
fi
[[ -f "$REPO_ROOT/hosts/claude/host.yaml" ]] || {
  echo "uninstall-guards: --repo-root is not a compatible pm-dispatch checkout: $REPO_ROOT" >&2
  exit 2
}
repo_root="$REPO_ROOT"
REPO_ROOT="$repo_root"
# shellcheck disable=SC1091
[[ -f "$repo_root/runtime/lib/gate-workspace.sh" ]] && . "$repo_root/runtime/lib/gate-workspace.sh"
if [[ -f "$repo_root/runtime/lib/allowlist.sh" ]]; then
  # shellcheck disable=SC1091
  . "$repo_root/runtime/lib/allowlist.sh"
else
  # copy-mode fallback: scan adapters dynamically so removal stays concrete
  dispatch_allowlist_entries() {
    local f rel
    for f in "$REPO_ROOT/adapters"/*/dispatch.sh; do
      [[ -f "$f" ]] || continue
      rel="${f#"$HOME/"}"
      printf 'Bash(%s:*)\nBash(~/%s:*)\n' "$f" "$rel"
    done
  }
fi
# Use the same host-owned canonical/default/legacy contract as base uninstall.
# shellcheck source=hosts/claude/lib/path-resolver.sh
. "$repo_root/hosts/claude/lib/path-resolver.sh"
_claude_root="$(claude_host_config_root 2>&1)" || {
  printf 'uninstall-guards: %s\n' "$_claude_root" >&2
  exit 2
}
CLAUDE_CONFIG_DIR="$_claude_root"
CLAUDE_HOME="$CLAUDE_CONFIG_DIR"
unset _claude_root
settings="$CLAUDE_HOME/settings.json"

if ! command -v jq >/dev/null 2>&1; then
  echo "uninstall-guards: jq is required" >&2
  exit 2
fi

if [ ! -f "$settings" ]; then
  echo "uninstall-guards: $settings not found — nothing to do"
  exit 0
fi

statusline_chain_conf="$CLAUDE_HOME/statusline-chain.conf"

tmp_new="$(mktemp)"
trap 'rm -f "$tmp_new"' EXIT

_chain_target=""
[[ -f "$statusline_chain_conf" ]] && _chain_target=$(head -1 "$statusline_chain_conf")

# Compute the reviewer Edit glob to include in managed removal.
# gate_workspace_root is sourced from runtime/lib/gate-workspace.sh;
# falls back to inline detection if the lib is absent (copy-mode installs).
if command -v gate_workspace_root >/dev/null 2>&1; then
  _gate_ws="$(gate_workspace_root "$repo_root" "$HOME")"
else
  _gate_ws="${PM_DISPATCH_GATE_WORKSPACE:-$HOME}"
fi
# The reviewer permission entries are managed install artifacts: they are added
# by install-guards.sh and removed here. Edit(.gate-results), the historical
# Write(.gate-results) spelling, Bash(mkdir -p:*), and the pmctl guard-check
# forms are treated as pm-dispatch-owned; re-add
# manually if needed for other tools after uninstall. The guard check is
# allow-listed in bare, absolute, and tilde forms (mirror install-guards.sh: an
# in-session reviewer subagent may invoke pmctl by absolute path when its PATH
# lacks the bin dir) — remove all three.
_pmctl_bin_dir="${PMCTL_BIN_DIR:-$HOME/.local/bin}"
_managed_json="$({
  dispatch_allowlist_entries
  printf 'Edit(%s/**/.gate-results/**)\n' "$_gate_ws"
  # Upgrade compatibility: old installers wrote a permission kind Claude does
  # not accept. Uninstall must still remove that historical managed artifact.
  printf 'Write(%s/**/.gate-results/**)\n' "$_gate_ws"
  printf 'Bash(pmctl guard check:*)\n'
  printf 'Bash(%s/pmctl guard check:*)\n' "$_pmctl_bin_dir"
  [[ "${_pmctl_bin_dir#"$HOME/"}" != "$_pmctl_bin_dir" ]] && \
    printf 'Bash(~/%s/pmctl guard check:*)\n' "${_pmctl_bin_dir#"$HOME/"}"
  printf 'Bash(mkdir -p:*)\n'
} | jq -Rn '[inputs]')"

# install-guards.sh shell-escapes managed command paths (printf %q) so a repo
# checked out under a path with a space still produces a runnable hook. Match
# BOTH forms here: $repo_root (legacy unescaped installs) and its escaped prefix
# (current installs). printf %q escapes each char identically regardless of
# position, so the escaped command's prefix equals the escaped repo_root.
repo_root_q="$(printf '%q' "$repo_root")"

# MSYS2/Git-Bash rewrites `\` → `/` when passing args to a native jq.exe, which
# corrupts the printf %q escaping above so the prefix match misses managed
# entries. Disabling path conversion keeps repo_root_q verbatim — but it would
# also stop the native jq from opening a POSIX-path positional input file, so the
# settings is fed via stdin (bash opens it) rather than as a positional argument.
# Both env vars are no-ops on Linux/macOS.
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
  ' > "$tmp_new" < "$settings"

if cmp -s "$settings" "$tmp_new"; then
  echo "uninstall-guards: not wired, nothing to do"
  exit 0
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "uninstall-guards: would apply the following change:"
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
echo "uninstall-guards: wrote $settings"
echo "uninstall-guards: backup at $backup"
