#!/usr/bin/env bash
# Cross-host regression: optional Codex/OpenCode dispatch must leave Claude's
# existing install/uninstall surface byte-compatible.
# shellcheck disable=SC1091,SC2154
# The sourced test harness/portable library provide tmp_root and hash helpers.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=tests/lib/test-harness.sh
. "$SCRIPT_DIR/../lib/test-harness.sh"
# shellcheck source=runtime/lib/portable.sh
. "$REPO_ROOT/runtime/lib/portable.sh"
# shellcheck source=runtime/lib/host-manifest.sh
. "$REPO_ROOT/runtime/lib/host-manifest.sh"
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

make_relocated_opencode_fixture() {
  local root="$1"
  mkdir -p "$root/hosts/opencode/bin" "$root/hosts/opencode/lib" \
    "$root/runtime/lib" "$root/runtime/hooks" "$root/cli"
  cp "$REPO_ROOT/hosts/opencode/host.yaml" "$root/hosts/opencode/host.yaml"
  cp "$REPO_ROOT/hosts/opencode/lib/path-resolver.sh" "$root/hosts/opencode/lib/path-resolver.sh"
  cp "$REPO_ROOT/runtime/lib/host-manifest.sh" "$root/runtime/lib/host-manifest.sh"
  cp "$REPO_ROOT/runtime/lib/host-resolver.sh" "$root/runtime/lib/host-resolver.sh"
  cp "$REPO_ROOT/runtime/lib/host-write.sh" "$root/runtime/lib/host-write.sh"
  cp "$REPO_ROOT/runtime/lib/portable.sh" "$root/runtime/lib/portable.sh"
  cp "$REPO_ROOT/hosts/opencode/bin/install.sh" "$root/hosts/opencode/bin/install.sh"
  cp "$REPO_ROOT/hosts/opencode/bin/uninstall.sh" "$root/hosts/opencode/bin/uninstall.sh"
}

make_relocated_codex_fixture() {
  local root="$1"
  mkdir -p "$root/hosts/codex/bin" "$root/hosts/codex/hooks" \
    "$root/runtime/lib" "$root/runtime/hooks" "$root/scripts"
  cp -R "$REPO_ROOT/hosts/codex/lib" "$root/hosts/codex/lib"
  cp "$REPO_ROOT/hosts/codex/host.yaml" "$root/hosts/codex/host.yaml"
  cp "$REPO_ROOT/hosts/codex/bin/memory-update.sh" "$root/hosts/codex/bin/memory-update.sh"
  cp "$REPO_ROOT/runtime/lib/host-manifest.sh" "$root/runtime/lib/host-manifest.sh"
  cp "$REPO_ROOT/runtime/lib/host-resolver.sh" "$root/runtime/lib/host-resolver.sh"
  cp "$REPO_ROOT/runtime/lib/host-write.sh" "$root/runtime/lib/host-write.sh"
  cp "$REPO_ROOT/runtime/lib/portable.sh" "$root/runtime/lib/portable.sh"
  cp "$REPO_ROOT/hosts/codex/bin/install.sh" "$root/hosts/codex/bin/install.sh"
  cp "$REPO_ROOT/hosts/codex/bin/uninstall.sh" "$root/hosts/codex/bin/uninstall.sh"
  cp "$REPO_ROOT/hosts/codex/hooks/command-guard.sh" "$root/hosts/codex/hooks/command-guard.sh"
  cp "$REPO_ROOT/scripts/hook-codex-command-guard.sh" "$root/scripts/hook-codex-command-guard.sh"
  cp "$REPO_ROOT/runtime/hooks/guard-inject-memory.sh" "$root/runtime/hooks/guard-inject-memory.sh"
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

# Behavior: manifest modules remain runnable after their directory depth changes.
# Steps: relocate both OpenCode modules in a fixture, dispatch install/uninstall,
# and verify the explicit repository ABI owns and removes the resulting receipt.
test_relocated_module_uses_explicit_repo_root() {
  local name="host-dispatcher-relocated-module-uses-explicit-repo-root"
  should_run "$name" || return 0
  local fixture="$tmp_root/relocated/repo" xdg="$tmp_root/relocated/config"
  local config receipt
  config="$xdg/opencode/opencode.json"
  receipt="$config.pm-dispatch-receipt.json"
  make_relocated_opencode_fixture "$fixture"
  (
    # shellcheck disable=SC1090
    . "$fixture/runtime/lib/host-manifest.sh"
    # shellcheck disable=SC1090
    . "$fixture/runtime/lib/host-write.sh"
    HOME="$tmp_root/relocated/home" XDG_CONFIG_HOME="$xdg" TMPDIR="$tmp_root/relocated" \
      host_write_install "$fixture" opencode 0 >/dev/null
  )
  if [[ ! -f "$receipt" ]] || [[ "$(jq -r '.repo_root' "$receipt")" != "$fixture" ]]; then
    fail "$name" "relocated install did not record the dispatcher-supplied repository root"
    return
  fi
  (
    # shellcheck disable=SC1090
    . "$fixture/runtime/lib/host-manifest.sh"
    # shellcheck disable=SC1090
    . "$fixture/runtime/lib/host-write.sh"
    HOME="$tmp_root/relocated/home" XDG_CONFIG_HOME="$xdg" TMPDIR="$tmp_root/relocated" \
      host_write_uninstall_all "$fixture" 0 >/dev/null
  )
  if [[ ! -e "$config" && ! -e "$receipt" ]]; then
    pass "$name"
  else
    fail "$name" "relocated uninstall left managed OpenCode state"
  fi
}

# Behavior: Codex write modules consume the same explicit-root ABI after moving.
# Steps: relocate both modules in a fixture, dispatch their lifecycle, verify all
# generated commands use that fixture, then reject a direct relative-root call.
test_relocated_codex_module_uses_explicit_repo_root() {
  local name="host-dispatcher-relocated-codex-module-uses-explicit-repo-root"
  should_run "$name" || return 0
  local fixture="$tmp_root/relocated-codex/repo" codex="$tmp_root/relocated-codex/home"
  local rejected="$tmp_root/relocated-codex/rejected" hooks="$codex/hooks.json" rc=0
  make_relocated_codex_fixture "$fixture"
  (
    # shellcheck disable=SC1090
    . "$fixture/runtime/lib/host-manifest.sh"
    # shellcheck disable=SC1090
    . "$fixture/runtime/lib/host-write.sh"
    HOME="$tmp_root/relocated-codex/operator-home" CODEX_HOME="$codex" TMPDIR="$tmp_root/relocated-codex" \
      host_write_install "$fixture" codex 0 >/dev/null
  )
  if ! jq -e --arg root "$fixture" '
      [.hooks[][]?.hooks[]?.command] |
      any(startswith($root + "/hosts/codex/") or startswith($root + "/runtime/hooks/"))
    ' "$hooks" >/dev/null \
      || ! grep -Fq "$fixture/hosts/codex/bin/memory-update.sh" "$codex/AGENTS.md"; then
    fail "$name" "relocated Codex install did not use the dispatcher-supplied repository root"
    return
  fi
  (
    # shellcheck disable=SC1090
    . "$fixture/runtime/lib/host-manifest.sh"
    # shellcheck disable=SC1090
    . "$fixture/runtime/lib/host-write.sh"
    HOME="$tmp_root/relocated-codex/operator-home" CODEX_HOME="$codex" TMPDIR="$tmp_root/relocated-codex" \
      host_write_uninstall_all "$fixture" 0 >/dev/null
  )
  if [[ "$(jq -c . "$hooks")" != "{}" || -e "$codex/AGENTS.md" ]]; then
    fail "$name" "relocated Codex uninstall left managed hooks or instructions"
    return
  fi
  (
    cd "$tmp_root" || exit 1
    HOME="$tmp_root/relocated-codex/operator-home" CODEX_HOME="$rejected" \
      bash "$fixture/hosts/codex/bin/install.sh" --repo-root relocated-codex/repo
  ) >/dev/null 2>&1 || rc=$?
  if [[ "$rc" -eq 2 && ! -e "$rejected" ]]; then
    pass "$name"
  else
    fail "$name" "relative root reached relocated Codex module state or returned rc=$rc"
  fi
}

# Behavior: the dispatcher refuses a relative repository root before execution.
# Steps: install a sentinel module in a fixture, call with a relative root, and
# assert exit 2 without allowing the sentinel side effect.
test_relative_repo_root_fails_before_module_execution() {
  local name="host-dispatcher-relative-repo-root-fails-before-module-execution"
  should_run "$name" || return 0
  local fixture="$tmp_root/relative-root" marker="$tmp_root/relative-root-ran" rc=0
  mkdir -p "$fixture/hosts/fake" "$fixture/module"
  printf 'install_module: module/install.sh\n' > "$fixture/hosts/fake/host.yaml"
  printf '#!/usr/bin/env bash\ntouch %q\n' "$marker" > "$fixture/module/install.sh"
  (
    cd "$tmp_root" || exit 1
    # These callbacks are invoked indirectly by the sourced dispatcher.
    # shellcheck disable=SC2317,SC2329
    host_manifest_file() { printf '%s/hosts/%s/host.yaml\n' "$1" "$2"; }
    # shellcheck disable=SC2317,SC2329
    host_manifest_scalar() { awk -v key="$2" '$1 == key ":" { print $2; exit }' "$1"; }
    # shellcheck disable=SC1090
    . "$REPO_ROOT/runtime/lib/host-write.sh"
    host_write_install relative-root fake 0
  ) >/dev/null 2>&1 || rc=$?
  if [[ "$rc" -eq 2 && ! -e "$marker" ]]; then
    pass "$name"
  else
    fail "$name" "relative root reached the module or returned rc=$rc"
  fi
}

# Behavior: every host owns its path environment/default contract and preserves
# whitespace while treating an empty explicit root like an unset root.
# Steps: invoke the manifest-driven shared entry for all three hosts with
# isolated hostile HOME values, then compare exact paths.
test_host_resolvers_handle_unset_empty_spaces_and_hostile_home() {
  local name="host-resolvers-handle-unset-empty-spaces-and-hostile-home"
  should_run "$name" || return 0
  local home="$tmp_root/hostile home [literal]" claude codex opencode grok
  mkdir -p "$home"
  claude="$(HOME="$home" CLAUDE_CONFIG_DIR='' CLAUDE_HOME='' \
    host_manifest_expand_path "$REPO_ROOT" claude "\$CLAUDE_CONFIG_DIR/settings.json")"
  codex="$(HOME="$home" CODEX_HOME='' \
    host_manifest_expand_path "$REPO_ROOT" codex "\$CODEX_HOME/hooks.json")"
  opencode="$(HOME="$home" XDG_CONFIG_HOME='' \
    host_manifest_expand_path "$REPO_ROOT" opencode "\$XDG_CONFIG_HOME/opencode/opencode.json")"
  grok="$(HOME="$home" GROK_HOME='' \
    host_manifest_expand_path "$REPO_ROOT" grok "\$GROK_HOME/config.toml")"
  if [[ "$claude" == "$home/.claude/settings.json" \
      && "$codex" == "$home/.codex/hooks.json" \
      && "$opencode" == "$home/.config/opencode/opencode.json" \
      && "$grok" == "$home/.grok/config.toml" ]]; then
    pass "$name"
  else
    fail "$name" "unexpected defaults: claude=$claude codex=$codex opencode=$opencode grok=$grok"
  fi
}

# Behavior: Grok path resolver honors explicit GROK_HOME and fails closed without HOME.
# Steps: expand with an explicit root containing spaces, then with HOME unset and no GROK_HOME.
test_grok_resolver_explicit_root_and_missing_home() {
  local name="grok-resolver-explicit-root-and-missing-home"
  should_run "$name" || return 0
  local root="$tmp_root/grok root [x]" expanded out rc=0
  expanded="$(HOME="$tmp_root/operator" GROK_HOME="$root" \
    host_manifest_expand_path "$REPO_ROOT" grok "\$GROK_HOME/config.toml")"
  out="$(HOME='' GROK_HOME='' \
    host_manifest_expand_path "$REPO_ROOT" grok "\$GROK_HOME/config.toml" 2>&1)" || rc=$?
  if [[ "$expanded" == "$root/config.toml" \
      && "$rc" -eq 2 \
      && "$out" == *"HOME is required when GROK_HOME is unset or empty"* ]]; then
    pass "$name"
  else
    fail "$name" "expanded=$expanded rc=$rc out=$out"
  fi
}

# Behavior: Claude's canonical root and legacy alias have one fail-closed
# conflict rule, while equal values and legacy-only callers remain compatible.
# Steps: exercise conflict/equal/legacy-only combinations through the shared
# manifest entry and assert no conflicting path is returned.
test_claude_resolver_legacy_conflict_contract() {
  local name="claude-resolver-legacy-conflict-contract"
  should_run "$name" || return 0
  local canonical="$tmp_root/claude canonical" legacy="$tmp_root/claude legacy"
  local out rc=0 equal legacy_only
  out="$(HOME="$tmp_root/operator" CLAUDE_CONFIG_DIR="$canonical" CLAUDE_HOME="$legacy" \
    host_manifest_expand_path "$REPO_ROOT" claude "\$CLAUDE_CONFIG_DIR/settings.json" 2>&1)" || rc=$?
  equal="$(HOME="$tmp_root/operator" CLAUDE_CONFIG_DIR="$canonical" CLAUDE_HOME="$canonical" \
    host_manifest_expand_path "$REPO_ROOT" claude "\$CLAUDE_CONFIG_DIR/settings.json")"
  legacy_only="$(HOME="$tmp_root/operator" CLAUDE_CONFIG_DIR='' CLAUDE_HOME="$legacy" \
    host_manifest_expand_path "$REPO_ROOT" claude "\$CLAUDE_CONFIG_DIR/settings.json")"
  if [[ "$rc" -eq 2 && "$out" == *"CLAUDE_CONFIG_DIR and legacy CLAUDE_HOME disagree"* \
      && "$equal" == "$canonical/settings.json" \
      && "$legacy_only" == "$legacy/settings.json" ]]; then
    pass "$name"
  else
    fail "$name" "conflict contract mismatch: rc=$rc out=$out equal=$equal legacy=$legacy_only"
  fi
}

# Behavior: shared rooted-template expansion replaces only the declared leading
# token and never rewrites a token-shaped string later in the path.
# Steps: resolve a Codex path containing a repeated literal token, then assert
# the prefix is expanded once and an unsupported prefix still fails closed.
test_shared_root_template_expands_prefix_only() {
  local name="shared-root-template-expands-prefix-only"
  should_run "$name" || return 0
  local root="$tmp_root/codex root" expanded out rc=0
  expanded="$(HOME="$tmp_root/operator" CODEX_HOME="$root" \
    host_manifest_expand_path "$REPO_ROOT" codex '$CODEX_HOME/archive/$CODEX_HOME.json')"
  out="$(HOME="$tmp_root/operator" CODEX_HOME="$root" \
    host_manifest_expand_path "$REPO_ROOT" codex 'prefix/$CODEX_HOME.json' 2>&1)" || rc=$?
  if [[ "$expanded" == "$root/archive/\$CODEX_HOME.json" \
      && "$rc" -eq 2 && "$out" == *"unsupported manifest path template"* ]]; then
    pass "$name"
  else
    fail "$name" "prefix-only expansion mismatch: expanded=$expanded rc=$rc out=$out"
  fi
}

# Behavior: the shared reader contains no host environment names or defaults.
# Steps: inspect the function's source file and require all three manifest
# declarations to point at existing host-owned resolver modules/functions.
test_shared_expander_is_host_agnostic() {
  local name="shared-expander-is-host-agnostic"
  should_run "$name" || return 0
  local host manifest module resolver failures=""
  if grep -Eq 'CODEX_HOME|CLAUDE_CONFIG_DIR|CLAUDE_HOME|XDG_CONFIG_HOME' "$REPO_ROOT/runtime/lib/host-manifest.sh"; then
    fail "$name" "shared manifest reader still names a host environment variable"
    return
  fi
  if declare -f host_manifest_expand_path | grep -Eq '(^|[^[:alnum:]_])eval([[:space:]]|$)'; then
    fail "$name" "shared manifest expander delegates through eval"
    return
  fi
  for host in claude codex opencode grok; do
    manifest="$REPO_ROOT/hosts/$host/host.yaml"
    module="$(host_manifest_scalar "$manifest" path_resolver_module)"
    resolver="$(host_manifest_scalar "$manifest" path_resolver_function)"
    [[ -f "$REPO_ROOT/$module" ]] || failures+="$host:missing-module;"
    # shellcheck disable=SC1090
    . "$REPO_ROOT/$module"
    declare -F "$resolver" >/dev/null 2>&1 || failures+="$host:missing-function;"
  done
  if [[ -z "$failures" ]]; then
    pass "$name"
  else
    fail "$name" "$failures"
  fi
}

test_claude_surface_byte_compatible_with_optional_hosts
test_claude_uninstall_surface_stays_symmetric
test_relocated_module_uses_explicit_repo_root
test_relocated_codex_module_uses_explicit_repo_root
test_relative_repo_root_fails_before_module_execution
test_host_resolvers_handle_unset_empty_spaces_and_hostile_home
test_grok_resolver_explicit_root_and_missing_home
test_claude_resolver_legacy_conflict_contract
test_shared_root_template_expands_prefix_only
test_shared_expander_is_host_agnostic
th_summary
