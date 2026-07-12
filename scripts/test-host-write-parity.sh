#!/usr/bin/env bash
# Cross-host regression: optional Codex/OpenCode dispatch must leave Claude's
# existing install/uninstall surface byte-compatible.
# shellcheck disable=SC1091,SC2154
# The sourced test harness/portable library provide tmp_root and hash helpers.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=scripts/lib/test-harness.sh
. "$SCRIPT_DIR/lib/test-harness.sh"
# shellcheck source=scripts/lib/portable.sh
. "$SCRIPT_DIR/lib/portable.sh"
th_init "test-host-write-parity" "$@"

claude_fingerprint() {
  local root="$1" path rel digest
  [[ -d "$root" ]] || { printf 'ABSENT\n'; return; }
  while IFS= read -r path; do
    rel=".${path#"$root"}"
    case "$rel" in
      ./.pm-dispatch|./.pm-dispatch/*|*.bak.*) continue ;;
    esac
    if [[ -L "$path" ]]; then
      printf 'L|%s|%s\n' "$rel" "$(readlink "$path")"
    elif [[ -d "$path" ]]; then
      printf 'D|%s\n' "$rel"
    elif [[ -f "$path" ]]; then
      digest="$(_portable_sha256_path "$path")"
      printf 'F|%s|%s\n' "$rel" "$digest"
    fi
  done < <(find "$root" -mindepth 1 -print | LC_ALL=C sort)
}

run_install() {
  local lane="$1" mode="$2"
  local home="$tmp_root/$lane/home" claude="$tmp_root/$lane/claude"
  local codex="$tmp_root/$lane/codex" xdg="$tmp_root/$lane/config" bin="$tmp_root/shared-bin"
  local -a args=(--profile minimal)
  if [[ "$mode" == "all-hosts" ]]; then
    args+=(--enable-host codex --enable-host opencode)
  fi
  HOME="$home" CLAUDE_HOME="$claude" CODEX_HOME="$codex" XDG_CONFIG_HOME="$xdg" PMCTL_BIN_DIR="$bin" \
    bash "$REPO_ROOT/install.sh" "${args[@]}" >/dev/null 2>&1
}

run_uninstall() {
  local lane="$1"
  HOME="$tmp_root/$lane/home" CLAUDE_HOME="$tmp_root/$lane/claude" \
    CODEX_HOME="$tmp_root/$lane/codex" XDG_CONFIG_HOME="$tmp_root/$lane/config" \
    PMCTL_BIN_DIR="$tmp_root/shared-bin" bash "$REPO_ROOT/uninstall.sh" >/dev/null 2>&1
}

test_claude_surface_byte_compatible_with_optional_hosts() {
  local name="host-dispatcher-preserves-claude-install-surface"
  should_run "$name" || return 0
  local baseline combined
  run_install baseline claude-only
  run_install combined all-hosts
  baseline="$(claude_fingerprint "$tmp_root/baseline/claude")"
  combined="$(claude_fingerprint "$tmp_root/combined/claude")"
  if [[ "$baseline" == "$combined" ]]; then
    pass "$name"
  else
    diff -u <(printf '%s\n' "$baseline") <(printf '%s\n' "$combined") >&2 || true
    fail "$name" "Claude managed surface differs when optional hosts are enabled"
  fi
}

test_claude_uninstall_surface_stays_symmetric() {
  local name="host-dispatcher-preserves-claude-uninstall-symmetry"
  should_run "$name" || return 0
  local baseline combined
  # Each test is independently filterable; ensure setup exists when this case
  # runs without the install-parity case.
  [[ -d "$tmp_root/baseline/claude" ]] || run_install baseline claude-only
  [[ -d "$tmp_root/combined/claude" ]] || run_install combined all-hosts
  run_uninstall baseline
  run_uninstall combined
  baseline="$(claude_fingerprint "$tmp_root/baseline/claude")"
  combined="$(claude_fingerprint "$tmp_root/combined/claude")"
  if [[ "$baseline" == "$combined" ]]; then
    pass "$name"
  else
    fail "$name" "Claude post-uninstall surface differs when optional hosts were enabled"
  fi
}

test_claude_surface_byte_compatible_with_optional_hosts
test_claude_uninstall_surface_stays_symmetric
th_summary
