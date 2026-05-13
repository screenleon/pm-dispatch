#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C.UTF-8

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
REAL_HOME="$(getent passwd "$(id -un)" | cut -d: -f6)"

tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

PASS=0
FAIL=0
FAILED_CASES=()

pass() {
  printf 'PASS: %s\n' "$1"
  PASS=$((PASS + 1))
}

fail() {
  printf 'FAIL: %s: %s\n' "$1" "$2"
  FAIL=$((FAIL + 1))
  FAILED_CASES+=("$1")
}

assert_contains() {
  local name="$1" file="$2" needle="$3"
  if ! grep -Fq -- "$needle" "$file"; then
    fail "$name" "missing output: $needle"
    return 1
  fi
}

assert_not_contains() {
  local name="$1" file="$2" needle="$3"
  if grep -Fq -- "$needle" "$file"; then
    fail "$name" "unexpected output: $needle"
    return 1
  fi
}

assert_symlink_target() {
  local name="$1" path="$2" want="$3"
  if [ ! -L "$path" ]; then
    fail "$name" "$path is not a symlink"
    return 1
  fi
  local got
  got="$(readlink "$path")"
  if [ "$got" != "$want" ]; then
    fail "$name" "symlink target $got, expected $want"
    return 1
  fi
}

assert_dir_not_symlink() {
  local name="$1" path="$2"
  if [ ! -d "$path" ] || [ -L "$path" ]; then
    fail "$name" "$path is not a real directory"
    return 1
  fi
}

assert_file_content() {
  local name="$1" path="$2" want="$3"
  if [ ! -f "$path" ]; then
    fail "$name" "$path is not a file"
    return 1
  fi
  local got
  got="$(cat "$path")"
  if [ "$got" != "$want" ]; then
    fail "$name" "$path content changed"
    return 1
  fi
}

run_install_case() {
  local name="$1" mode="$2" want_code="$3"
  local home="$tmp_root/fakehome-$name"
  local out="$tmp_root/$name.stdout"
  local err="$tmp_root/$name.stderr"
  local decoy="$tmp_root/decoy-$name"
  mkdir -p "$home/.claude" "$decoy"

  case "$mode" in
    absent) ;;
    correct-symlink)
      ln -s "$REPO_ROOT/pm" "$home/.claude/.pm"
      ;;
    wrong-symlink)
      ln -s "$decoy" "$home/.claude/.pm"
      ;;
    real-dir)
      mkdir -p "$home/.claude/.pm/some-content"
      ;;
    script-absent) ;;
    script-correct-symlink)
      mkdir -p "$home/.claude/scripts"
      ln -s "$REPO_ROOT/scripts/pr-gate.sh" "$home/.claude/scripts/pr-gate.sh"
      ;;
    script-wrong-symlink)
      mkdir -p "$home/.claude/scripts"
      printf '#!/usr/bin/env bash\n' > "$decoy/pr-gate.sh"
      ln -s "$decoy/pr-gate.sh" "$home/.claude/scripts/pr-gate.sh"
      ;;
    *)
      fail "$name" "unknown setup mode: $mode"
      return
      ;;
  esac

  shift 3
  set +e
  HOME="$home" \
    CLAUDE_CONFIG_TEST_INSTALL_RUNNING=1 \
    CLAUDE_CONFIG_TEST_PREFLIGHT_HOME="$REAL_HOME" \
    bash "$REPO_ROOT/install.sh" "$@" >"$out" 2>"$err"
  local got_code=$?
  set -e

  if [ "$got_code" -ne "$want_code" ]; then
    fail "$name" "exit $got_code, expected $want_code"
    return
  fi

  case "$name" in
    pm-absent-real-run)
      assert_contains "$name" "$out" "link   $home/.claude/.pm -> $REPO_ROOT/pm" || return
      assert_symlink_target "$name" "$home/.claude/.pm" "$REPO_ROOT/pm" || return
      ;;
    pm-absent-dry-run)
      assert_contains "$name" "$out" "would  $home/.claude/.pm -> $REPO_ROOT/pm" || return
      if [ -e "$home/.claude/.pm" ] || [ -L "$home/.claude/.pm" ]; then
        fail "$name" "$home/.claude/.pm should not exist"
        return
      fi
      ;;
    pm-correct-symlink-idempotent)
      assert_contains "$name" "$out" "ok    $home/.claude/.pm" || return
      assert_symlink_target "$name" "$home/.claude/.pm" "$REPO_ROOT/pm" || return
      ;;
    pm-wrong-symlink-real-run)
      assert_contains "$name" "$err" "CONFLICT" || return
      assert_contains "$name" "$err" "expected $REPO_ROOT/pm" || return
      assert_symlink_target "$name" "$home/.claude/.pm" "$decoy" || return
      ;;
    pm-real-dir-real-run)
      assert_contains "$name" "$err" "CONFLICT" || return
      assert_contains "$name" "$err" "is not a symlink" || return
      assert_dir_not_symlink "$name" "$home/.claude/.pm" || return
      ;;
    pm-real-dir-dry-run)
      assert_contains "$name" "$err" "CONFLICT" || return
      assert_contains "$name" "$err" "is not a symlink" || return
      assert_not_contains "$name" "$out" "would  $home/.claude/.pm" || return
      assert_dir_not_symlink "$name" "$home/.claude/.pm" || return
      ;;
    scripts-absent-real-run)
      assert_contains "$name" "$out" "link   $home/.claude/scripts/pr-gate.sh -> $REPO_ROOT/scripts/pr-gate.sh" || return
      assert_symlink_target "$name" "$home/.claude/scripts/pr-gate.sh" "$REPO_ROOT/scripts/pr-gate.sh" || return
      ;;
    scripts-correct-symlink-idempotent)
      assert_contains "$name" "$out" "ok    $home/.claude/scripts/pr-gate.sh" || return
      assert_symlink_target "$name" "$home/.claude/scripts/pr-gate.sh" "$REPO_ROOT/scripts/pr-gate.sh" || return
      ;;
    scripts-wrong-symlink-real-run)
      assert_contains "$name" "$err" "CONFLICT" || return
      assert_contains "$name" "$err" "expected $REPO_ROOT/scripts/pr-gate.sh" || return
      assert_symlink_target "$name" "$home/.claude/scripts/pr-gate.sh" "$decoy/pr-gate.sh" || return
      ;;
  esac

  pass "$name"
}

run_install_case "pm-absent-real-run" absent 0
run_install_case "pm-absent-dry-run" absent 0 --dry-run
run_install_case "pm-correct-symlink-idempotent" correct-symlink 0
run_install_case "pm-wrong-symlink-real-run" wrong-symlink 1
run_install_case "pm-real-dir-real-run" real-dir 1
run_install_case "pm-real-dir-dry-run" real-dir 1 --dry-run
run_install_case "scripts-absent-real-run" script-absent 0
run_install_case "scripts-correct-symlink-idempotent" script-correct-symlink 0
run_install_case "scripts-wrong-symlink-real-run" script-wrong-symlink 0

test_legacy_pm_left_untouched() {
  local name="legacy-github-pm-left-untouched"

  local dir_home="$tmp_root/$name-dir-home"
  local dir_out="$tmp_root/$name-dir.stdout"
  local dir_err="$tmp_root/$name-dir.stderr"
  mkdir -p "$dir_home/.claude" "$dir_home/github/.pm/nested"
  printf 'legacy dir sentinel\n' > "$dir_home/github/.pm/nested/sentinel.txt"

  set +e
  HOME="$dir_home" \
    CLAUDE_CONFIG_TEST_INSTALL_RUNNING=1 \
    CLAUDE_CONFIG_TEST_PREFLIGHT_HOME="$REAL_HOME" \
    bash "$REPO_ROOT/install.sh" >"$dir_out" 2>"$dir_err"
  local dir_code=$?
  set -e

  if [ "$dir_code" -ne 0 ]; then
    fail "$name" "legacy real-dir install exit $dir_code, expected 0"
    return
  fi
  assert_dir_not_symlink "$name" "$dir_home/github/.pm" || return
  assert_file_content "$name" "$dir_home/github/.pm/nested/sentinel.txt" "legacy dir sentinel" || return
  assert_not_contains "$name" "$dir_err" "$dir_home/github/.pm" || return

  local link_home="$tmp_root/$name-link-home"
  local link_out="$tmp_root/$name-link.stdout"
  local link_err="$tmp_root/$name-link.stderr"
  local legacy_target="$tmp_root/$name-legacy-target"
  mkdir -p "$link_home/.claude" "$link_home/github" "$legacy_target"
  printf 'legacy symlink sentinel\n' > "$legacy_target/sentinel.txt"
  ln -s "$legacy_target" "$link_home/github/.pm"

  set +e
  HOME="$link_home" \
    CLAUDE_CONFIG_TEST_INSTALL_RUNNING=1 \
    CLAUDE_CONFIG_TEST_PREFLIGHT_HOME="$REAL_HOME" \
    bash "$REPO_ROOT/install.sh" >"$link_out" 2>"$link_err"
  local link_code=$?
  set -e

  if [ "$link_code" -ne 0 ]; then
    fail "$name" "legacy symlink install exit $link_code, expected 0"
    return
  fi
  assert_symlink_target "$name" "$link_home/github/.pm" "$legacy_target" || return
  assert_file_content "$name" "$legacy_target/sentinel.txt" "legacy symlink sentinel" || return
  assert_not_contains "$name" "$link_err" "$link_home/github/.pm" || return

  pass "$name"
}

test_legacy_stale_symlinks_removed() {
  local name="legacy-stale-symlinks-removed"

  local script_home="$tmp_root/$name-script-home"
  local script_out="$tmp_root/$name-script.stdout"
  local script_err="$tmp_root/$name-script.stderr"
  mkdir -p "$script_home/.claude/scripts"
  ln -s "$REPO_ROOT/scripts/codex-pr-gate.sh" "$script_home/.claude/scripts/codex-pr-gate.sh"

  set +e
  HOME="$script_home" \
    CLAUDE_CONFIG_TEST_INSTALL_RUNNING=1 \
    CLAUDE_CONFIG_TEST_PREFLIGHT_HOME="$REAL_HOME" \
    bash "$REPO_ROOT/install.sh" >"$script_out" 2>"$script_err"
  local script_code=$?
  set -e

  if [ "$script_code" -ne 0 ]; then
    fail "$name" "legacy script install exit $script_code, expected 0"
    return
  fi
  if [ -e "$script_home/.claude/scripts/codex-pr-gate.sh" ] || [ -L "$script_home/.claude/scripts/codex-pr-gate.sh" ]; then
    fail "$name" "$script_home/.claude/scripts/codex-pr-gate.sh should not exist"
    return
  fi
  assert_contains "$name" "$script_out" "remove (legacy)" || return

  local command_home="$tmp_root/$name-command-home"
  local command_out="$tmp_root/$name-command.stdout"
  local command_err="$tmp_root/$name-command.stderr"
  mkdir -p "$command_home/.claude/commands"
  ln -s "$REPO_ROOT/commands/codex-pr-gate.md" "$command_home/.claude/commands/codex-pr-gate.md"

  set +e
  HOME="$command_home" \
    CLAUDE_CONFIG_TEST_INSTALL_RUNNING=1 \
    CLAUDE_CONFIG_TEST_PREFLIGHT_HOME="$REAL_HOME" \
    bash "$REPO_ROOT/install.sh" >"$command_out" 2>"$command_err"
  local command_code=$?
  set -e

  if [ "$command_code" -ne 0 ]; then
    fail "$name" "legacy command install exit $command_code, expected 0"
    return
  fi
  if [ -e "$command_home/.claude/commands/codex-pr-gate.md" ] || [ -L "$command_home/.claude/commands/codex-pr-gate.md" ]; then
    fail "$name" "$command_home/.claude/commands/codex-pr-gate.md should not exist"
    return
  fi

  pass "$name"
}

# ── install-hooks / uninstall-hooks lifecycle ─────────────────────────────────
# Proves that install-hooks.sh wires all three managed hooks and that
# uninstall-hooks.sh removes each of them completely, leaving no orphaned entries.

test_install_sh_wires_hooks() {
  # Proves that the primary install.sh path wires all three managed hooks
  # into settings.json automatically — no manual install-hooks.sh step needed.
  local name="install-sh-wires-hooks"
  local home="$tmp_root/$name"
  mkdir -p "$home/.claude"
  printf '{"permissions":{}}\n' > "$home/.claude/settings.json"

  HOME="$home" \
    CLAUDE_CONFIG_TEST_INSTALL_RUNNING=1 \
    CLAUDE_CONFIG_TEST_PREFLIGHT_HOME="$REAL_HOME" \
    bash "$REPO_ROOT/install.sh" > /dev/null 2>&1

  assert_contains "$name" "$home/.claude/settings.json" "hook-pm-write-guard.sh" || return
  assert_contains "$name" "$home/.claude/settings.json" "hook-codex-bash-guard.sh" || return
  assert_contains "$name" "$home/.claude/settings.json" "hook-codex-write-guard.sh" || return
  pass "$name"
}

test_install_sh_wires_hooks_no_settings() {
  # First-time install with no pre-existing settings.json — install.sh must
  # create a minimal settings.json and wire all hooks before the Write-enabled
  # codex-executor agent is accessible.
  local name="install-sh-wires-hooks-no-settings"
  local home="$tmp_root/$name"
  mkdir -p "$home/.claude"
  # Deliberately no settings.json

  HOME="$home" \
    CLAUDE_CONFIG_TEST_INSTALL_RUNNING=1 \
    CLAUDE_CONFIG_TEST_PREFLIGHT_HOME="$REAL_HOME" \
    bash "$REPO_ROOT/install.sh" > /dev/null 2>&1

  if [[ ! -f "$home/.claude/settings.json" ]]; then
    fail "$name" "settings.json was not created during first-time install"
    return
  fi
  assert_contains "$name" "$home/.claude/settings.json" "hook-pm-write-guard.sh" || return
  assert_contains "$name" "$home/.claude/settings.json" "hook-codex-bash-guard.sh" || return
  assert_contains "$name" "$home/.claude/settings.json" "hook-codex-write-guard.sh" || return
  pass "$name"
}

test_hooks_install_uninstall_lifecycle() {
  local name="hooks-install-uninstall-lifecycle"
  local home="$tmp_root/$name"
  mkdir -p "$home/.claude"
  printf '{"permissions":{}}\n' > "$home/.claude/settings.json"

  HOME="$home" bash "$REPO_ROOT/scripts/install-hooks.sh" > /dev/null
  assert_contains "$name" "$home/.claude/settings.json" "hook-pm-write-guard.sh" || return
  assert_contains "$name" "$home/.claude/settings.json" "hook-codex-bash-guard.sh" || return
  assert_contains "$name" "$home/.claude/settings.json" "hook-codex-write-guard.sh" || return
  assert_contains "$name" "$home/.claude/settings.json" "hook-log-claude-usage.sh" || return

  HOME="$home" bash "$REPO_ROOT/scripts/uninstall-hooks.sh" > /dev/null
  assert_not_contains "$name" "$home/.claude/settings.json" "hook-pm-write-guard.sh" || return
  assert_not_contains "$name" "$home/.claude/settings.json" "hook-codex-bash-guard.sh" || return
  assert_not_contains "$name" "$home/.claude/settings.json" "hook-codex-write-guard.sh" || return
  assert_not_contains "$name" "$home/.claude/settings.json" "hook-log-claude-usage.sh" || return

  pass "$name"
}

test_stop_hook_migration() {
  local name="hooks-stop-migration"
  local home="$tmp_root/$name"
  mkdir -p "$home/.claude"
  local old_stop="$REPO_ROOT/hooks/hook-log-claude-usage.sh"
  printf '{"permissions":{},"hooks":{"Stop":[{"hooks":[{"type":"command","command":"%s"}]}]}}\n' \
    "$old_stop" > "$home/.claude/settings.json"

  HOME="$home" bash "$REPO_ROOT/scripts/install-hooks.sh" > /dev/null
  assert_not_contains "$name" "$home/.claude/settings.json" \
    "hooks/hook-log-claude-usage.sh" || return
  assert_contains "$name" "$home/.claude/settings.json" \
    "scripts/hook-log-claude-usage.sh" || return
  pass "$name"
}

test_stop_hook_preservation() {
  local name="hooks-stop-preservation"
  local home="$tmp_root/$name"
  mkdir -p "$home/.claude"
  # Unrelated hook at a completely different path that happens to share the basename
  local unrelated="/home/testuser/myproject/hook-log-claude-usage.sh"
  printf '{"permissions":{},"hooks":{"Stop":[{"hooks":[{"type":"command","command":"%s"}]}]}}\n' \
    "$unrelated" > "$home/.claude/settings.json"

  # After install: unrelated hook preserved, managed hook added
  HOME="$home" bash "$REPO_ROOT/scripts/install-hooks.sh" > /dev/null
  assert_contains "$name" "$home/.claude/settings.json" "$unrelated" || return
  assert_contains "$name" "$home/.claude/settings.json" "scripts/hook-log-claude-usage.sh" || return

  # After uninstall: managed hook removed, unrelated hook still present
  HOME="$home" bash "$REPO_ROOT/scripts/uninstall-hooks.sh" > /dev/null
  assert_not_contains "$name" "$home/.claude/settings.json" "scripts/hook-log-claude-usage.sh" || return
  assert_contains "$name" "$home/.claude/settings.json" "$unrelated" || return
  pass "$name"
}

test_install_sh_wires_hooks
test_install_sh_wires_hooks_no_settings
test_hooks_install_uninstall_lifecycle
test_stop_hook_migration
test_stop_hook_preservation
test_legacy_pm_left_untouched
test_legacy_stale_symlinks_removed

printf '%s passed, %s failed\n' "$PASS" "$FAIL"
if [ "$FAIL" -gt 0 ]; then
  printf 'failed cases: %s\n' "${FAILED_CASES[*]}" >&2
  exit 1
fi
