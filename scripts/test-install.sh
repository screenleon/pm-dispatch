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
  mkdir -p "$home/github" "$home/.claude" "$decoy"

  case "$mode" in
    absent) ;;
    correct-symlink)
      ln -s "$REPO_ROOT/pm" "$home/github/.pm"
      ;;
    wrong-symlink)
      ln -s "$decoy" "$home/github/.pm"
      ;;
    real-dir)
      mkdir -p "$home/github/.pm/some-content"
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
      assert_contains "$name" "$out" "link   $home/github/.pm -> $REPO_ROOT/pm" || return
      assert_symlink_target "$name" "$home/github/.pm" "$REPO_ROOT/pm" || return
      ;;
    pm-absent-dry-run)
      assert_contains "$name" "$out" "would  $home/github/.pm -> $REPO_ROOT/pm" || return
      if [ -e "$home/github/.pm" ] || [ -L "$home/github/.pm" ]; then
        fail "$name" "$home/github/.pm should not exist"
        return
      fi
      ;;
    pm-correct-symlink-idempotent)
      assert_contains "$name" "$out" "ok    $home/github/.pm" || return
      assert_symlink_target "$name" "$home/github/.pm" "$REPO_ROOT/pm" || return
      ;;
    pm-wrong-symlink-real-run)
      assert_contains "$name" "$err" "CONFLICT" || return
      assert_contains "$name" "$err" "expected $REPO_ROOT/pm" || return
      assert_symlink_target "$name" "$home/github/.pm" "$decoy" || return
      ;;
    pm-real-dir-real-run)
      assert_contains "$name" "$err" "CONFLICT" || return
      assert_contains "$name" "$err" "is not a symlink" || return
      assert_dir_not_symlink "$name" "$home/github/.pm" || return
      ;;
    pm-real-dir-dry-run)
      assert_contains "$name" "$err" "CONFLICT" || return
      assert_contains "$name" "$err" "is not a symlink" || return
      assert_not_contains "$name" "$out" "would  $home/github/.pm" || return
      assert_dir_not_symlink "$name" "$home/github/.pm" || return
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

printf '%s passed, %s failed\n' "$PASS" "$FAIL"
if [ "$FAIL" -gt 0 ]; then
  printf 'failed cases: %s\n' "${FAILED_CASES[*]}" >&2
  exit 1
fi
