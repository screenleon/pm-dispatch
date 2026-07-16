#!/usr/bin/env bash
# Regression suite for the codex-host install write path:
# scripts/lib/host-manifest.sh, scripts/install-guards-codex.sh,
# scripts/uninstall-guards-codex.sh, scripts/hook-codex-command-guard.sh, and
# the install.sh/uninstall.sh integration points that call them.
#
# Every case runs against a throwaway $CODEX_HOME under $tmp_root — never the
# real ~/.codex. CODEX_HOME is exported per-case (not left set across cases)
# so a bug that reads a stale global never silently passes.
#
# Runs via: scripts/test-host-write-codex.sh
# Filter:   scripts/test-host-write-codex.sh --filter <pattern>
# List:     scripts/test-host-write-codex.sh --list

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=scripts/lib/test-harness.sh
. "$SCRIPT_DIR/lib/test-harness.sh"
th_init "test-host-write-codex" "$@"

# shellcheck source=scripts/lib/host-manifest.sh
. "$SCRIPT_DIR/lib/host-manifest.sh"
# shellcheck source=scripts/lib/host-write.sh
. "$SCRIPT_DIR/lib/host-write.sh"

# th_init already created $tmp_root with its own EXIT trap; reuse it.

# --- host-manifest.sh reader --------------------------------------------

test_host_manifest_reads_codex_install_targets() {
  local name="host-manifest-reads-codex-install-targets"
  should_run "$name" || return 0
  local manifest found=0
  manifest="$(host_manifest_file "$REPO_ROOT" codex)"
  while IFS=$'\t' read -r id path fmt managed; do
    if [[ "$id" == "hooks" && "$fmt" == "codex-hooks-json" && "$managed" == "true" ]]; then
      found=1
    fi
  done < <(host_manifest_install_targets "$manifest")
  [[ "$found" -eq 1 ]] && pass "$name" || fail "$name" "expected a managed hooks/codex-hooks-json install_target row"
}

test_host_manifest_names_lists_only_dirs_with_host_yaml() {
  local name="host-manifest-names-lists-only-dirs-with-host-yaml"
  should_run "$name" || return 0
  local fake_root="$tmp_root/hmn-fake-repo"
  mkdir -p "$fake_root/hosts/foo" "$fake_root/hosts/bar" "$fake_root/hosts/baz"
  printf 'schema_version: 1\nhost_name: foo\n' > "$fake_root/hosts/foo/host.yaml"
  printf 'schema_version: 1\nhost_name: baz\n' > "$fake_root/hosts/baz/host.yaml"
  # hosts/bar/ deliberately has NO host.yaml — must not be listed.
  local names
  names="$(host_manifest_names "$fake_root" | sort | tr '\n' ',')"
  [[ "$names" == "baz,foo," ]] && pass "$name" || fail "$name" "expected 'baz,foo,' (bar excluded), got: $names"
}

test_host_manifest_scalar_reads_present_value() {
  local name="host-manifest-scalar-reads-present-value"
  should_run "$name" || return 0
  local manifest="$tmp_root/hms-present.yaml"
  printf 'schema_version: 1\nhost_binary: opencode\n' > "$manifest"
  local v
  v="$(host_manifest_scalar "$manifest" host_binary)"
  [[ "$v" == "opencode" ]] && pass "$name" || fail "$name" "got: $v"
}

test_host_manifest_scalar_strips_quotes() {
  local name="host-manifest-scalar-strips-quotes"
  should_run "$name" || return 0
  local manifest="$tmp_root/hms-quoted.yaml"
  printf 'schema_version: 1\nhost_name: "codex"\n' > "$manifest"
  local v
  v="$(host_manifest_scalar "$manifest" host_name)"
  [[ "$v" == "codex" ]] && pass "$name" || fail "$name" "got: $v"
}

test_host_manifest_scalar_strips_trailing_comment() {
  local name="host-manifest-scalar-strips-trailing-comment"
  should_run "$name" || return 0
  local manifest="$tmp_root/hms-comment.yaml"
  printf 'schema_version: 1\ndoctor_module: doctor-host-codex.sh  # wired by doctor.sh loader\n' > "$manifest"
  local v
  v="$(host_manifest_scalar "$manifest" doctor_module)"
  [[ "$v" == "doctor-host-codex.sh" ]] && pass "$name" || fail "$name" "got: $v"
}

test_host_manifest_scalar_missing_key_returns_empty() {
  local name="host-manifest-scalar-missing-key-returns-empty"
  should_run "$name" || return 0
  local manifest="$tmp_root/hms-missingkey.yaml"
  printf 'schema_version: 1\nhost_binary: opencode\n' > "$manifest"
  local v rc=0
  v="$(host_manifest_scalar "$manifest" nonexistent_key)" || rc=$?
  [[ -z "$v" && "$rc" -eq 0 ]] && pass "$name" || fail "$name" "expected empty output and rc=0 for a missing key, got v='$v' rc=$rc"
}

test_host_manifest_scalar_missing_file_errors() {
  local name="host-manifest-scalar-missing-file-errors"
  should_run "$name" || return 0
  local rc=0
  host_manifest_scalar "$tmp_root/hms-does-not-exist.yaml" host_binary >/dev/null 2>&1 || rc=$?
  [[ "$rc" -ne 0 ]] && pass "$name" || fail "$name" "expected non-zero exit for a missing manifest file, got rc=$rc"
}

test_host_manifest_scalar_ignores_list_map_field() {
  local name="host-manifest-scalar-ignores-list-map-field"
  should_run "$name" || return 0
  local manifest="$tmp_root/hms-listfield.yaml"
  printf 'schema_version: 1\ninstall_targets:\n  - id: hooks\n    path: "$CODEX_HOME/hooks.json"\n' > "$manifest"
  local v
  v="$(host_manifest_scalar "$manifest" install_targets)"
  [[ -z "$v" ]] && pass "$name" || fail "$name" "expected empty scalar for a list/map field header, got: $v"
}

test_host_manifest_expand_path_uses_env_override() {
  local name="host-manifest-expand-path-uses-env-override"
  should_run "$name" || return 0
  local expanded
  expanded="$(CODEX_HOME=/tmp/fake-codex-home host_manifest_expand_path "$REPO_ROOT" codex '$CODEX_HOME/hooks.json')"
  [[ "$expanded" == "/tmp/fake-codex-home/hooks.json" ]] && pass "$name" || fail "$name" "got: $expanded"
}

test_host_manifest_expand_path_default_when_unset() {
  local name="host-manifest-expand-path-default-when-unset"
  should_run "$name" || return 0
  local expanded
  expanded="$(unset CODEX_HOME; host_manifest_expand_path "$REPO_ROOT" codex '$CODEX_HOME/hooks.json')"
  [[ "$expanded" == "$HOME/.codex/hooks.json" ]] && pass "$name" || fail "$name" "got: $expanded"
}

test_host_manifest_declares_codex_write_modules() {
  local name="host-manifest-declares-codex-write-modules"
  should_run "$name" || return 0
  local manifest install_module uninstall_module
  manifest="$(host_manifest_file "$REPO_ROOT" codex)"
  install_module="$(host_manifest_scalar "$manifest" install_module)"
  uninstall_module="$(host_manifest_scalar "$manifest" uninstall_module)"
  [[ "$install_module" == "scripts/install-guards-codex.sh" && "$uninstall_module" == "scripts/uninstall-guards-codex.sh" ]] \
    && pass "$name" || fail "$name" "unexpected modules: install=$install_module uninstall=$uninstall_module"
}

test_host_manifest_declares_codex_memory_update_module() {
  local name="host-manifest-declares-codex-memory-update-module"
  should_run "$name" || return 0
  local manifest module
  manifest="$(host_manifest_file "$REPO_ROOT" codex)"
  module="$(host_manifest_scalar "$manifest" memory_update_module)"
  [[ "$module" == "hosts/codex/bin/memory-update.sh" && -x "$REPO_ROOT/$module" ]] \
    && pass "$name" || fail "$name" "unexpected or non-executable module: $module"
}

test_host_write_dispatches_codex_from_manifest() {
  local name="host-write-dispatches-codex-from-manifest"
  should_run "$name" || return 0
  local codex_home="$tmp_root/hwd-codex/.codex"
  CODEX_HOME="$codex_home" host_write_install "$REPO_ROOT" codex 0 >/dev/null 2>&1
  if [[ ! -f "$codex_home/hooks.json" ]]; then
    fail "$name" "generic dispatcher did not create hooks.json"
    return
  fi
  CODEX_HOME="$codex_home" host_write_uninstall_all "$REPO_ROOT" 0 >/dev/null 2>&1
  [[ "$(jq -c . "$codex_home/hooks.json")" == "{}" ]] \
    && pass "$name" || fail "$name" "generic teardown did not remove managed hook"
}

test_host_write_dispatches_opencode_stage3() {
  local name="host-write-dispatches-opencode-stage3"
  should_run "$name" || return 0
  local xdg="$tmp_root/hwd-opencode" codex="$tmp_root/hwd-opencode-codex"
  XDG_CONFIG_HOME="$xdg" host_write_install "$REPO_ROOT" opencode 0 >/dev/null 2>&1
  if [[ ! -f "$xdg/opencode/commands/pm.md" ]]; then
    fail "$name" "generic dispatcher did not wire OpenCode"
    return
  fi
  XDG_CONFIG_HOME="$xdg" CODEX_HOME="$codex" host_write_uninstall_all "$REPO_ROOT" 0 >/dev/null 2>&1
  [[ ! -e "$xdg/opencode/opencode.json" ]] \
    && pass "$name" || fail "$name" "generic teardown did not remove OpenCode wiring"
}

test_install_generic_host_selector_wires_codex() {
  local name="install-generic-host-selector-wires-codex"
  should_run "$name" || return 0
  local home="$tmp_root/int-generic-home" claude_home="$tmp_root/int-generic-claude"
  local codex_home="$tmp_root/int-generic-codex" bin_dir="$tmp_root/int-generic-bin"
  HOME="$home" CLAUDE_HOME="$claude_home" CODEX_HOME="$codex_home" PMCTL_BIN_DIR="$bin_dir" \
    bash "$REPO_ROOT/install.sh" --profile minimal --enable-host codex >/dev/null 2>&1
  if jq -e '.hooks.PreToolUse[]? | select(.matcher == "Bash")' "$codex_home/hooks.json" >/dev/null 2>&1; then
    pass "$name"
  else
    fail "$name" "--enable-host codex did not dispatch the declared install module"
  fi
}

test_install_unknown_host_fails_before_mutation() {
  local name="install-unknown-host-fails-before-mutation"
  should_run "$name" || return 0
  local home="$tmp_root/int-unwired-home" claude_home="$tmp_root/int-unwired-claude" rc=0
  HOME="$home" CLAUDE_HOME="$claude_home" PMCTL_BIN_DIR="$tmp_root/int-unwired-bin" \
    XDG_CONFIG_HOME="$tmp_root/int-unwired-xdg" \
    bash "$REPO_ROOT/install.sh" --profile minimal --enable-host not-a-host >/dev/null 2>&1 || rc=$?
  [[ "$rc" -eq 2 && ! -e "$claude_home" && ! -e "$tmp_root/int-unwired-xdg" ]] \
    && pass "$name" || fail "$name" "expected unknown host to fail before mutation, got rc=$rc"
}

# --- install-guards-codex.sh ---------------------------------------------

test_install_guards_codex_dry_run_no_side_effect() {
  local name="install-guards-codex-dry-run-no-side-effect"
  should_run "$name" || return 0
  local codex_home="$tmp_root/ic-dryrun/.codex"
  CODEX_HOME="$codex_home" bash "$REPO_ROOT/scripts/install-guards-codex.sh" --dry-run >/dev/null 2>&1
  [[ ! -e "$codex_home" ]] && pass "$name" || fail "$name" "$codex_home should not exist after --dry-run"
}

test_install_guards_codex_wires_hook() {
  local name="install-guards-codex-wires-hook"
  should_run "$name" || return 0
  local codex_home="$tmp_root/ic-wire/.codex"
  CODEX_HOME="$codex_home" bash "$REPO_ROOT/scripts/install-guards-codex.sh" >/dev/null 2>&1
  if [[ ! -f "$codex_home/hooks.json" ]]; then
    fail "$name" "hooks.json not created"
    return
  fi
  if jq -e '.hooks.PreToolUse[] | select(.matcher=="Bash") | .hooks[] | select(.command | endswith("hook-codex-command-guard.sh"))' \
      "$codex_home/hooks.json" >/dev/null 2>&1 \
    && jq -e '.hooks.UserPromptSubmit[] | .hooks[] | select(.command | endswith("guard-inject-memory.sh"))' \
      "$codex_home/hooks.json" >/dev/null 2>&1 \
    && jq -e '.hooks.Stop[] | .hooks[] | select(.command | endswith("guard-session-summary.sh --host codex"))' \
      "$codex_home/hooks.json" >/dev/null 2>&1 \
    && grep -Fq 'pm-dispatch:codex-memory-contract:start' "$codex_home/AGENTS.md"; then
    pass "$name"
  else
    fail "$name" "expected command, prompt, Stop, and AGENTS memory wiring"
  fi
}

test_install_guards_codex_idempotent() {
  local name="install-guards-codex-idempotent"
  should_run "$name" || return 0
  local codex_home="$tmp_root/ic-idem/.codex"
  CODEX_HOME="$codex_home" bash "$REPO_ROOT/scripts/install-guards-codex.sh" >/dev/null 2>&1
  local before after
  before="$(jq -c '.hooks' "$codex_home/hooks.json")"
  CODEX_HOME="$codex_home" bash "$REPO_ROOT/scripts/install-guards-codex.sh" >/dev/null 2>&1
  after="$(jq -c '.hooks' "$codex_home/hooks.json")"
  [[ "$before" == "$after" ]] \
    && [[ "$(jq '.hooks.PreToolUse | length' "$codex_home/hooks.json")" == "1" ]] \
    && [[ "$(jq '.hooks.UserPromptSubmit | length' "$codex_home/hooks.json")" == "1" ]] \
    && [[ "$(jq '.hooks.Stop | length' "$codex_home/hooks.json")" == "1" ]] \
    && [[ "$(grep -Fc 'pm-dispatch:codex-memory-contract:start' "$codex_home/AGENTS.md")" == "1" ]] \
    && pass "$name" || fail "$name" "re-running should not duplicate the managed hook entry"
}

test_codex_memory_update_writes_only_canonical_episode() {
  local name="codex-memory-update-writes-only-canonical-episode"
  should_run "$name" || return 0
  local root="$tmp_root/memory-update" repo="$tmp_root/memory-update/repo"
  local memory="$tmp_root/memory-update/canonical" native="$tmp_root/memory-update/native"
  local marker="codex-canonical-marker-$RANDOM" native_before native_after out
  mkdir -p "$repo" "$memory" "$native"
  git -C "$repo" init -q
  printf 'native sentinel\n' > "$native/note.md"
  native_before="$(find "$native" -type f -exec sha256sum {} + | sort)"
  out="$(PM_MEMORY_DIR="$memory" CODEX_HOME="$native" "$REPO_ROOT/hosts/codex/bin/memory-update.sh" \
    --repo-root "$repo" --summary "$marker" --json)"
  native_after="$(find "$native" -type f -exec sha256sum {} + | sort)"
  if jq -e --arg marker "$marker" \
      '.writer_host == "codex" and .authority == "canonical" and .episode.summary == $marker' <<<"$out" >/dev/null \
    && jq -e --arg marker "$marker" 'select(.summary == $marker and .writer_host == "codex")' \
      "$memory/episodes.jsonl" >/dev/null \
    && [[ "$native_before" == "$native_after" ]]; then
    pass "$name"
  else
    fail "$name" "expected one canonical Codex write and no native-memory change"
  fi
}

test_codex_memory_update_invalid_explicit_fails_closed() {
  local name="codex-memory-update-invalid-explicit-fails-closed"
  should_run "$name" || return 0
  local root="$tmp_root/memory-update-invalid" repo="$tmp_root/memory-update-invalid/repo" rc=0
  mkdir -p "$repo"
  git -C "$repo" init -q
  PM_MEMORY_DIR="$root/missing" "$REPO_ROOT/hosts/codex/bin/memory-update.sh" \
    --repo-root "$repo" --summary "must not land" --json >/dev/null 2>&1 || rc=$?
  [[ "$rc" -eq 3 && ! -e "$root/missing" ]] \
    && pass "$name" || fail "$name" "expected invalid explicit path rc=3 and no write, got rc=$rc"
}

test_install_guards_codex_missing_manifest_target_errors() {
  local name="install-guards-codex-missing-managed-target-errors"
  should_run "$name" || return 0
  local codex_home="$tmp_root/ic-nomanifest/.codex"
  local mock_repo="$tmp_root/ic-nomanifest-repo"
  mkdir -p "$mock_repo/hosts/codex" "$mock_repo/scripts/lib"
  printf 'schema_version: 1\nhost_name: codex\ninstall_targets:\n  - id: config\n    path: "$CODEX_HOME/config.toml"\n    format: codex-config-toml\n    managed: false\n' \
    > "$mock_repo/hosts/codex/host.yaml"
  cp "$SCRIPT_DIR/lib/host-manifest.sh" "$mock_repo/scripts/lib/host-manifest.sh"
  cp "$SCRIPT_DIR/install-guards-codex.sh" "$mock_repo/scripts/install-guards-codex.sh"
  cp "$SCRIPT_DIR/hook-codex-command-guard.sh" "$mock_repo/scripts/hook-codex-command-guard.sh"
  local rc=0
  CODEX_HOME="$codex_home" bash "$mock_repo/scripts/install-guards-codex.sh" >/dev/null 2>&1 || rc=$?
  [[ "$rc" -ne 0 ]] && pass "$name" || fail "$name" "expected non-zero exit when no managed hooks install_target is declared"
}

test_install_guards_codex_unknown_flag_rejected() {
  local name="install-guards-codex-unknown-flag-rejected"
  should_run "$name" || return 0
  local codex_home="$tmp_root/ic-badflag/.codex"
  local rc=0
  CODEX_HOME="$codex_home" bash "$REPO_ROOT/scripts/install-guards-codex.sh" --bogus >/dev/null 2>&1 || rc=$?
  [[ "$rc" -ne 0 ]] && [[ ! -e "$codex_home" ]] \
    && pass "$name" \
    || fail "$name" "expected non-zero exit and no $codex_home mutation for an unknown flag, got rc=$rc"
}

test_install_guards_codex_spaced_repo_root() {
  # Regression: a repo checked out under a path containing a space (e.g. a
  # Windows home like C:/Users/First Last/) must still produce a RUNNABLE
  # hook. Codex runs each hook `command` through the shell; an unquoted
  # spaced path is word-split and fails ("No such file or directory").
  # install-guards-codex.sh shell-escapes the command path so it survives,
  # and uninstall-guards-codex.sh must still recognise and remove it.
  local name="install-guards-codex-spaced-repo-root"
  should_run "$name" || return 0
  local codex_home="$tmp_root/ic-spaced/.codex"
  local spaced="$tmp_root/repo with space"
  if ! ln -s "$REPO_ROOT" "$spaced" 2>/dev/null; then
    printf '  (skip) %s — no directory symlink support here\n' "$name"
    return 0
  fi

  CODEX_HOME="$codex_home" bash "$spaced/scripts/install-guards-codex.sh" >/dev/null 2>&1
  if [[ ! -f "$codex_home/hooks.json" ]]; then
    fail "$name" "hooks.json not created via spaced repo root"
    return
  fi

  local cmd
  cmd="$(jq -r '.hooks.PreToolUse[]? | select(.matcher=="Bash") | .hooks[]?.command' "$codex_home/hooks.json")"
  if [[ -z "$cmd" ]]; then
    fail "$name" "expected PreToolUse Bash hook not found in $codex_home/hooks.json"
    return
  fi
  local out
  out="$(bash -c "$cmd" </dev/null 2>&1 || true)"
  if printf '%s' "$out" | grep -q "No such file or directory"; then
    fail "$name" "hook command word-split on space: [$cmd]"
    return
  fi

  # Prove the escaped hook path still ENFORCES real allow/deny decisions, not
  # just that it launches without word-splitting — feed representative Codex
  # hook payloads through it.
  local allow_rc=0 deny_rc=0
  printf '{"tool_input":{"command":"git status","cwd":"/tmp"}}' \
    | PM_GUARD_LOG_DIR="$tmp_root/spaced-guard-logs" bash -c "$cmd" >/dev/null 2>&1 || allow_rc=$?
  if [[ "$allow_rc" -ne 0 ]]; then
    fail "$name" "spaced-path hook denied a benign command (rc=$allow_rc): [$cmd]"
    return
  fi
  printf '{"tool_input":{"command":"rm -rf /tmp/whatever","cwd":"/tmp"}}' \
    | PM_GUARD_LOG_DIR="$tmp_root/spaced-guard-logs" bash -c "$cmd" >/dev/null 2>&1 || deny_rc=$?
  if [[ "$deny_rc" -eq 0 ]]; then
    fail "$name" "spaced-path hook allowed a destructive command that should be denied: [$cmd]"
    return
  fi

  CODEX_HOME="$codex_home" bash "$spaced/scripts/uninstall-guards-codex.sh" >/dev/null 2>&1
  local content
  content="$(jq -c . "$codex_home/hooks.json")"
  [[ "$content" == "{}" ]] && pass "$name" || fail "$name" "uninstall left the escaped spaced-repo hook behind, got: $content"
}

# --- uninstall-guards-codex.sh --------------------------------------------

test_uninstall_guards_codex_removes_hook() {
  local name="uninstall-guards-codex-removes-hook"
  should_run "$name" || return 0
  local codex_home="$tmp_root/uc-remove/.codex"
  CODEX_HOME="$codex_home" bash "$REPO_ROOT/scripts/install-guards-codex.sh" >/dev/null 2>&1
  CODEX_HOME="$codex_home" bash "$REPO_ROOT/scripts/uninstall-guards-codex.sh" >/dev/null 2>&1
  local content
  content="$(jq -c . "$codex_home/hooks.json")"
  [[ "$content" == "{}" ]] && pass "$name" || fail "$name" "expected empty hooks.json, got: $content"
}

test_uninstall_guards_codex_preserves_unrelated_hook() {
  local name="uninstall-guards-codex-preserves-unrelated-hook"
  should_run "$name" || return 0
  local codex_home="$tmp_root/uc-preserve/.codex"
  CODEX_HOME="$codex_home" bash "$REPO_ROOT/scripts/install-guards-codex.sh" >/dev/null 2>&1
  jq '.hooks.PreToolUse += [{"matcher":"Bash","hooks":[{"type":"command","command":"/some/other/tool/hook.sh"}]}]' \
    "$codex_home/hooks.json" > "$codex_home/hooks.json.tmp" && mv "$codex_home/hooks.json.tmp" "$codex_home/hooks.json"
  CODEX_HOME="$codex_home" bash "$REPO_ROOT/scripts/uninstall-guards-codex.sh" >/dev/null 2>&1
  if jq -e '.hooks.PreToolUse[] | select(.matcher=="Bash") | .hooks[] | select(.command=="/some/other/tool/hook.sh")' \
      "$codex_home/hooks.json" >/dev/null 2>&1; then
    pass "$name"
  else
    fail "$name" "unrelated hook entry should survive uninstall"
  fi
}

test_codex_agents_managed_block_preserves_foreign_content() {
  local name="codex-agents-managed-block-preserves-foreign-content"
  should_run "$name" || return 0
  local codex_home="$tmp_root/agents-preserve/.codex"
  mkdir -p "$codex_home"
  printf '# Personal guidance\n\n- Keep this exact rule.\n' > "$codex_home/AGENTS.md"
  CODEX_HOME="$codex_home" bash "$REPO_ROOT/scripts/install-guards-codex.sh" >/dev/null 2>&1
  CODEX_HOME="$codex_home" bash "$REPO_ROOT/scripts/install-guards-codex.sh" >/dev/null 2>&1
  CODEX_HOME="$codex_home" bash "$REPO_ROOT/scripts/uninstall-guards-codex.sh" >/dev/null 2>&1
  if [[ "$(cat "$codex_home/AGENTS.md")" == $'# Personal guidance\n\n- Keep this exact rule.' ]]; then
    pass "$name"
  else
    fail "$name" "foreign AGENTS.md content changed during install/uninstall"
  fi
}

test_codex_agents_malformed_markers_fail_closed() {
  local name="codex-agents-malformed-markers-fail-closed"
  should_run "$name" || return 0
  local codex_home="$tmp_root/agents-malformed/.codex"
  local before="$tmp_root/agents-malformed.before"
  local rc=0
  mkdir -p "$codex_home"
  printf '%s\n%s\n' \
    '# Personal guidance' \
    '<!-- pm-dispatch:codex-memory-contract:start -->' \
    > "$codex_home/AGENTS.md"
  cp "$codex_home/AGENTS.md" "$before"

  CODEX_HOME="$codex_home" bash "$REPO_ROOT/scripts/install-guards-codex.sh" >/dev/null 2>&1 || rc=$?
  if [[ "$rc" -eq 2 ]] \
    && cmp -s "$before" "$codex_home/AGENTS.md" \
    && [[ ! -e "$codex_home/hooks.json" ]]; then
    pass "$name"
  else
    fail "$name" "malformed managed markers must fail before modifying AGENTS.md or hooks.json (rc=$rc)"
  fi
}

test_uninstall_guards_codex_preserves_in_repo_user_hook() {
  # Regression: uninstall must remove only the exact managed guard entry, not
  # every hook command that happens to live under this repo checkout — a
  # user-maintained hook stored alongside pm-dispatch's own scripts (e.g. a
  # personal scripts/my-own-hook.sh) must survive.
  local name="uninstall-guards-codex-preserves-in-repo-user-hook"
  should_run "$name" || return 0
  local codex_home="$tmp_root/uc-inrepo/.codex"
  local user_hook="$REPO_ROOT/scripts/my-own-hook.sh"
  CODEX_HOME="$codex_home" bash "$REPO_ROOT/scripts/install-guards-codex.sh" >/dev/null 2>&1
  jq --arg cmd "$user_hook" \
    '.hooks.PreToolUse += [{"matcher":"Bash","hooks":[{"type":"command","command":$cmd}]}]' \
    "$codex_home/hooks.json" > "$codex_home/hooks.json.tmp" && mv "$codex_home/hooks.json.tmp" "$codex_home/hooks.json"
  CODEX_HOME="$codex_home" bash "$REPO_ROOT/scripts/uninstall-guards-codex.sh" >/dev/null 2>&1
  if jq -e --arg cmd "$user_hook" '.hooks.PreToolUse[]? | select(.matcher=="Bash") | .hooks[]? | select(.command==$cmd)' \
      "$codex_home/hooks.json" >/dev/null 2>&1; then
    pass "$name"
  else
    fail "$name" "in-repo user hook should survive uninstall, was removed"
  fi
}

test_uninstall_guards_codex_preserves_same_basename_other_checkout() {
  # Regression: uninstall must match the EXACT command identity this
  # checkout's installer writes, not "basename == hook-codex-command-guard.sh
  # under a scripts/ parent" — a same-named hook installed by a DIFFERENT
  # checkout (or vendored copy of this tool) must survive uninstall.
  local name="uninstall-guards-codex-preserves-same-basename-other-checkout"
  should_run "$name" || return 0
  local codex_home="$tmp_root/uc-samebasename/.codex"
  local other_hook="/other/repo/scripts/hook-codex-command-guard.sh"
  CODEX_HOME="$codex_home" bash "$REPO_ROOT/scripts/install-guards-codex.sh" >/dev/null 2>&1
  jq --arg cmd "$other_hook" \
    '.hooks.PreToolUse += [{"matcher":"Bash","hooks":[{"type":"command","command":$cmd}]}]' \
    "$codex_home/hooks.json" > "$codex_home/hooks.json.tmp" && mv "$codex_home/hooks.json.tmp" "$codex_home/hooks.json"
  CODEX_HOME="$codex_home" bash "$REPO_ROOT/scripts/uninstall-guards-codex.sh" >/dev/null 2>&1
  if jq -e --arg cmd "$other_hook" '.hooks.PreToolUse[]? | select(.matcher=="Bash") | .hooks[]? | select(.command==$cmd)' \
      "$codex_home/hooks.json" >/dev/null 2>&1; then
    pass "$name"
  else
    fail "$name" "same-basename hook from a different checkout should survive uninstall, was removed"
  fi
}

test_uninstall_guards_codex_idempotent_when_absent() {
  local name="uninstall-guards-codex-idempotent-when-absent"
  should_run "$name" || return 0
  local codex_home="$tmp_root/uc-absent/.codex"
  local rc=0
  CODEX_HOME="$codex_home" bash "$REPO_ROOT/scripts/uninstall-guards-codex.sh" >/dev/null 2>&1 || rc=$?
  [[ "$rc" -eq 0 ]] && pass "$name" || fail "$name" "expected exit 0 when nothing is wired"
}

test_uninstall_guards_codex_unknown_flag_rejected() {
  local name="uninstall-guards-codex-unknown-flag-rejected"
  should_run "$name" || return 0
  local codex_home="$tmp_root/uc-badflag/.codex"
  CODEX_HOME="$codex_home" bash "$REPO_ROOT/scripts/install-guards-codex.sh" >/dev/null 2>&1
  local before after rc=0
  before="$(jq -c . "$codex_home/hooks.json")"
  CODEX_HOME="$codex_home" bash "$REPO_ROOT/scripts/uninstall-guards-codex.sh" --bogus >/dev/null 2>&1 || rc=$?
  after="$(jq -c . "$codex_home/hooks.json")"
  [[ "$rc" -ne 0 ]] && [[ "$before" == "$after" ]] \
    && pass "$name" \
    || fail "$name" "expected non-zero exit and unchanged hooks.json for an unknown flag, got rc=$rc"
}

test_uninstall_guards_codex_malformed_hooks_json_skips_not_errors() {
  # Regression: uninstall.sh invokes this script UNCONDITIONALLY (symmetric
  # teardown even when this checkout never opted into
  # --enable-codex-command-guard), so $CODEX_HOME/hooks.json may be
  # user-owned Codex state pm-dispatch never wrote and never validated. A
  # malformed/unrelated hooks.json must degrade to a warned skip, not abort
  # under `set -e` and not mutate the file.
  local name="uninstall-guards-codex-malformed-hooks-json-skips-not-errors"
  should_run "$name" || return 0
  local codex_home="$tmp_root/uc-malformed/.codex"
  mkdir -p "$codex_home"
  printf '{ this is not valid json' > "$codex_home/hooks.json"
  local before after rc=0
  before="$(cat "$codex_home/hooks.json")"
  CODEX_HOME="$codex_home" bash "$REPO_ROOT/scripts/uninstall-guards-codex.sh" >/dev/null 2>/dev/null || rc=$?
  after="$(cat "$codex_home/hooks.json")"
  [[ "$rc" -eq 0 ]] && [[ "$before" == "$after" ]] \
    && pass "$name" \
    || fail "$name" "expected exit 0 and unchanged file for malformed hooks.json, got rc=$rc"
}

# --- hook-codex-command-guard.sh ------------------------------------------

test_hook_codex_command_guard_allows_benign_command() {
  local name="hook-codex-command-guard-allows-benign-command"
  should_run "$name" || return 0
  local rc=0
  printf '{"tool_input":{"command":"git status","cwd":"/tmp"}}' \
    | PM_GUARD_LOG_DIR="$tmp_root/guard-logs" "$SCRIPT_DIR/hook-codex-command-guard.sh" >/dev/null 2>&1 || rc=$?
  [[ "$rc" -eq 0 ]] && pass "$name" || fail "$name" "expected exit 0 for a benign command, got rc=$rc"
}

test_hook_codex_command_guard_denies_destructive_command() {
  local name="hook-codex-command-guard-denies-destructive-command"
  should_run "$name" || return 0
  local stderr_file rc
  stderr_file="$(mktemp)"
  printf '{"tool_input":{"command":"rm -rf /tmp/whatever","cwd":"/tmp"}}' \
    | PM_GUARD_LOG_DIR="$tmp_root/guard-logs" "$SCRIPT_DIR/hook-codex-command-guard.sh" 2>"$stderr_file" 1>/dev/null
  rc=$?
  if [[ "$rc" -ne 0 ]] && grep -q "denylisted pattern" "$stderr_file"; then
    pass "$name"
  else
    fail "$name" "expected non-zero exit + denylist message, got rc=$rc stderr=$(cat "$stderr_file")"
  fi
  rm -f "$stderr_file"
}

test_hook_codex_command_guard_denies_prefixed_option_bypass() {
  local name="hook-codex-command-guard-denies-prefixed-option-bypass"
  should_run "$name" || return 0
  local stderr_file rc
  stderr_file="$(mktemp)"
  printf '{"tool_input":{"command":"rm -v -rf /tmp/whatever","cwd":"/tmp"}}' \
    | PM_GUARD_LOG_DIR="$tmp_root/guard-logs" "$SCRIPT_DIR/hook-codex-command-guard.sh" 2>"$stderr_file" 1>/dev/null
  rc=$?
  if [[ "$rc" -ne 0 ]] && grep -q "denylisted pattern" "$stderr_file"; then
    pass "$name"
  else
    fail "$name" "expected non-zero exit + denylist message, got rc=$rc stderr=$(cat "$stderr_file")"
  fi
  rm -f "$stderr_file"
}

test_hook_codex_command_guard_denies_git_global_option_bypass() {
  local name="hook-codex-command-guard-denies-git-global-option-bypass"
  should_run "$name" || return 0
  local stderr_file rc
  stderr_file="$(mktemp)"
  printf '{"tool_input":{"command":"git -C /tmp reset --hard","cwd":"/tmp"}}' \
    | PM_GUARD_LOG_DIR="$tmp_root/guard-logs" "$SCRIPT_DIR/hook-codex-command-guard.sh" 2>"$stderr_file" 1>/dev/null
  rc=$?
  if [[ "$rc" -ne 0 ]] && grep -q "denylisted pattern" "$stderr_file"; then
    pass "$name"
  else
    fail "$name" "expected non-zero exit + denylist message, got rc=$rc stderr=$(cat "$stderr_file")"
  fi
  rm -f "$stderr_file"
}

# Behavior: Codex command-local PM guard bypass applies to exactly one hook call.
# Steps:
#   1. Send a destructive command with an exact leading PM_GUARD_PM_BASH=off assignment.
#   2. Assert the hook allows and audits the bypass.
#   3. Send the same destructive command without the assignment and assert it is denied.
test_hook_codex_command_guard_command_local_bypass_is_one_call() {
  local name="hook-codex-command-guard-command-local-bypass-is-one-call"
  should_run "$name" || return 0
  local log_dir="$tmp_root/guard-command-local" log_file rc=0 second_rc=0
  log_file="$log_dir/hooks.log"
  printf '{"tool_input":{"command":"PM_GUARD_PM_BASH=off git branch -D merged-branch","cwd":"/tmp"}}' \
    | env -u PM_GUARD_PM_BASH PM_GUARD_LOG_DIR="$log_dir" \
      "$SCRIPT_DIR/hook-codex-command-guard.sh" >/dev/null 2>&1 || rc=$?
  printf '{"tool_input":{"command":"git branch -D merged-branch","cwd":"/tmp"}}' \
    | env -u PM_GUARD_PM_BASH PM_GUARD_LOG_DIR="$log_dir" \
      "$SCRIPT_DIR/hook-codex-command-guard.sh" >/dev/null 2>&1 || second_rc=$?
  if [[ "$rc" -eq 0 && "$second_rc" -ne 0 ]] \
      && grep -Fq 'decision=bypass' "$log_file"; then
    pass "$name"
  else
    fail "$name" "expected one-call audited bypass; first=$rc second=$second_rc"
  fi
}

# Behavior: Codex command-local bypass syntax is anchored and case-sensitive.
# Steps:
#   1. Put PM_GUARD_PM_BASH=off after another shell command and assert denial.
#   2. Use the leading value Off instead of off and assert denial.
#   3. Confirm neither malformed form produces a bypass audit entry.
test_hook_codex_command_guard_rejects_malformed_command_local_bypass() {
  local name="hook-codex-command-guard-rejects-malformed-command-local-bypass"
  should_run "$name" || return 0
  local log_dir="$tmp_root/guard-command-local-invalid" log_file middle_rc=0 case_rc=0
  log_file="$log_dir/hooks.log"
  printf '{"tool_input":{"command":"echo ok; PM_GUARD_PM_BASH=off git branch -D merged-branch","cwd":"/tmp"}}' \
    | env -u PM_GUARD_PM_BASH PM_GUARD_LOG_DIR="$log_dir" \
      "$SCRIPT_DIR/hook-codex-command-guard.sh" >/dev/null 2>&1 || middle_rc=$?
  printf '{"tool_input":{"command":"PM_GUARD_PM_BASH=Off git branch -D merged-branch","cwd":"/tmp"}}' \
    | env -u PM_GUARD_PM_BASH PM_GUARD_LOG_DIR="$log_dir" \
      "$SCRIPT_DIR/hook-codex-command-guard.sh" >/dev/null 2>&1 || case_rc=$?
  if [[ "$middle_rc" -ne 0 && "$case_rc" -ne 0 ]] \
      && ! grep -Fq 'decision=bypass' "$log_file"; then
    pass "$name"
  else
    fail "$name" "expected malformed bypass forms to deny; middle=$middle_rc case=$case_rc"
  fi
}

test_hook_codex_command_guard_missing_command_denies() {
  local name="hook-codex-command-guard-missing-command-denies"
  should_run "$name" || return 0
  local rc=0
  printf '{"tool_input":{"cwd":"/tmp"}}' \
    | PM_GUARD_LOG_DIR="$tmp_root/guard-logs" "$SCRIPT_DIR/hook-codex-command-guard.sh" >/dev/null 2>&1 || rc=$?
  [[ "$rc" -ne 0 ]] && pass "$name" || fail "$name" "expected non-zero exit for missing tool_input.command"
}

# --- install.sh / uninstall.sh integration --------------------------------

test_install_default_never_touches_codex_home() {
  local name="install-default-never-touches-codex-home"
  should_run "$name" || return 0
  local claude_home="$tmp_root/int-default/.claude"
  local codex_home="$tmp_root/int-default/.codex"
  local pmctl_bin_dir="$tmp_root/int-default/pmctl-bin"
  CLAUDE_HOME="$claude_home" CODEX_HOME="$codex_home" PMCTL_BIN_DIR="$pmctl_bin_dir" \
    bash "$REPO_ROOT/install.sh" --profile minimal >/dev/null 2>&1
  [[ ! -e "$codex_home" ]] && pass "$name" || fail "$name" "\$CODEX_HOME should stay untouched without --enable-codex-command-guard"
}

test_install_opt_in_wires_codex_and_uninstall_removes_it() {
  local name="install-opt-in-wires-codex-and-uninstall-removes-it"
  should_run "$name" || return 0
  local claude_home="$tmp_root/int-optin/.claude"
  local codex_home="$tmp_root/int-optin/.codex"
  local pmctl_bin_dir="$tmp_root/int-optin/pmctl-bin"
  CLAUDE_HOME="$claude_home" CODEX_HOME="$codex_home" PMCTL_BIN_DIR="$pmctl_bin_dir" \
    bash "$REPO_ROOT/install.sh" --profile minimal --enable-codex-command-guard >/dev/null 2>&1
  if [[ ! -f "$codex_home/hooks.json" ]] || ! jq -e '.hooks.PreToolUse[]? | select(.matcher=="Bash")' "$codex_home/hooks.json" >/dev/null 2>&1; then
    fail "$name" "install.sh --enable-codex-command-guard should wire the codex hook"
    return
  fi
  CLAUDE_HOME="$claude_home" CODEX_HOME="$codex_home" PMCTL_BIN_DIR="$pmctl_bin_dir" \
    bash "$REPO_ROOT/uninstall.sh" >/dev/null 2>&1
  local content
  content="$(jq -c . "$codex_home/hooks.json" 2>/dev/null)"
  [[ "$content" == "{}" ]] && pass "$name" || fail "$name" "uninstall.sh should symmetrically remove the codex hook, got: $content"
}

test_uninstall_removes_codex_hook_when_codex_not_on_path() {
  # Regression lock: uninstall.sh must not gate codex-host teardown on
  # codex_available — a codex uninstall/reinstall or PATH change between
  # install and uninstall must not leave a stale global hook behind.
  local name="uninstall-removes-codex-hook-when-codex-not-on-path"
  should_run "$name" || return 0
  local claude_home="$tmp_root/int-nopath/.claude"
  local codex_home="$tmp_root/int-nopath/.codex"
  local pmctl_bin_dir="$tmp_root/int-nopath/pmctl-bin"
  local minimal_path="/usr/bin:/bin"
  PATH="$minimal_path" CLAUDE_HOME="$claude_home" CODEX_HOME="$codex_home" PMCTL_BIN_DIR="$pmctl_bin_dir" \
    bash "$REPO_ROOT/install.sh" --profile minimal --enable-codex-command-guard >/dev/null 2>&1
  if [[ ! -f "$codex_home/hooks.json" ]]; then
    fail "$name" "setup: install --enable-codex-command-guard should wire the hook even without codex on PATH"
    return
  fi
  PATH="$minimal_path" CLAUDE_HOME="$claude_home" CODEX_HOME="$codex_home" PMCTL_BIN_DIR="$pmctl_bin_dir" \
    bash "$REPO_ROOT/uninstall.sh" >/dev/null 2>&1
  local content
  content="$(jq -c . "$codex_home/hooks.json" 2>/dev/null)"
  [[ "$content" == "{}" ]] && pass "$name" || fail "$name" "uninstall.sh left the codex hook behind when codex was not on PATH, got: $content"
}

test_host_manifest_reads_codex_install_targets
test_host_manifest_names_lists_only_dirs_with_host_yaml
test_host_manifest_scalar_reads_present_value
test_host_manifest_scalar_strips_quotes
test_host_manifest_scalar_strips_trailing_comment
test_host_manifest_scalar_missing_key_returns_empty
test_host_manifest_scalar_missing_file_errors
test_host_manifest_scalar_ignores_list_map_field
test_host_manifest_expand_path_uses_env_override
test_host_manifest_expand_path_default_when_unset
test_host_manifest_declares_codex_write_modules
test_host_manifest_declares_codex_memory_update_module
test_host_write_dispatches_codex_from_manifest
test_host_write_dispatches_opencode_stage3
test_install_generic_host_selector_wires_codex
test_install_unknown_host_fails_before_mutation
test_install_guards_codex_dry_run_no_side_effect
test_install_guards_codex_wires_hook
test_install_guards_codex_idempotent
test_codex_memory_update_writes_only_canonical_episode
test_codex_memory_update_invalid_explicit_fails_closed
test_install_guards_codex_missing_manifest_target_errors
test_install_guards_codex_unknown_flag_rejected
test_install_guards_codex_spaced_repo_root
test_uninstall_guards_codex_removes_hook
test_uninstall_guards_codex_preserves_unrelated_hook
test_codex_agents_managed_block_preserves_foreign_content
test_codex_agents_malformed_markers_fail_closed
test_uninstall_guards_codex_preserves_in_repo_user_hook
test_uninstall_guards_codex_preserves_same_basename_other_checkout
test_uninstall_guards_codex_idempotent_when_absent
test_uninstall_guards_codex_unknown_flag_rejected
test_uninstall_guards_codex_malformed_hooks_json_skips_not_errors
test_hook_codex_command_guard_allows_benign_command
test_hook_codex_command_guard_denies_destructive_command
test_hook_codex_command_guard_denies_prefixed_option_bypass
test_hook_codex_command_guard_denies_git_global_option_bypass
test_hook_codex_command_guard_command_local_bypass_is_one_call
test_hook_codex_command_guard_rejects_malformed_command_local_bypass
test_hook_codex_command_guard_missing_command_denies
test_install_default_never_touches_codex_home
test_install_opt_in_wires_codex_and_uninstall_removes_it
test_uninstall_removes_codex_hook_when_codex_not_on_path

th_summary
