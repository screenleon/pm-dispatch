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
      ln -s "$REPO_ROOT/scripts/codex-pr-gate.sh" "$home/.claude/scripts/codex-pr-gate.sh"
      ;;
    script-wrong-symlink)
      mkdir -p "$home/.claude/scripts"
      printf '#!/usr/bin/env bash\n' > "$decoy/codex-pr-gate.sh"
      ln -s "$decoy/codex-pr-gate.sh" "$home/.claude/scripts/codex-pr-gate.sh"
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
      assert_contains "$name" "$out" "link   $home/.claude/scripts/codex-pr-gate.sh -> $REPO_ROOT/scripts/codex-pr-gate.sh" || return
      assert_symlink_target "$name" "$home/.claude/scripts/codex-pr-gate.sh" "$REPO_ROOT/scripts/codex-pr-gate.sh" || return
      ;;
    scripts-correct-symlink-idempotent)
      assert_contains "$name" "$out" "ok    $home/.claude/scripts/codex-pr-gate.sh" || return
      assert_symlink_target "$name" "$home/.claude/scripts/codex-pr-gate.sh" "$REPO_ROOT/scripts/codex-pr-gate.sh" || return
      ;;
    scripts-wrong-symlink-real-run)
      assert_contains "$name" "$err" "CONFLICT" || return
      assert_contains "$name" "$err" "expected $REPO_ROOT/scripts/codex-pr-gate.sh" || return
      assert_symlink_target "$name" "$home/.claude/scripts/codex-pr-gate.sh" "$decoy/codex-pr-gate.sh" || return
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

  HOME="$home" bash "$REPO_ROOT/scripts/uninstall-hooks.sh" > /dev/null
  assert_not_contains "$name" "$home/.claude/settings.json" "hook-pm-write-guard.sh" || return
  assert_not_contains "$name" "$home/.claude/settings.json" "hook-codex-bash-guard.sh" || return
  assert_not_contains "$name" "$home/.claude/settings.json" "hook-codex-write-guard.sh" || return

  pass "$name"
}

test_install_sh_wires_hooks
test_install_sh_wires_hooks_no_settings
test_hooks_install_uninstall_lifecycle

printf '%s passed, %s failed\n' "$PASS" "$FAIL"
if [ "$FAIL" -gt 0 ]; then
  printf 'failed cases: %s\n' "${FAILED_CASES[*]}" >&2
  exit 1
fi
