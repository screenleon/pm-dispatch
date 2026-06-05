#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C.UTF-8

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# getent is NSS-only (Linux); absent on macOS and Windows/Git-Bash. Fall back to
# $HOME there. On Linux getent succeeds, so the resolved value is unchanged.
REAL_HOME="$(getent passwd "$(id -un)" 2>/dev/null | cut -d: -f6 || true)"
[[ -n "$REAL_HOME" ]] || REAL_HOME="$HOME"
# shellcheck source=scripts/lib/test-harness.sh
. "$SCRIPT_DIR/lib/test-harness.sh"
# portable.sh provides detect_platform + make_junction_windows, used below to
# branch install-mode assertions: Linux/macOS install via symlink; Windows
# (MSYS) installs directories via junction and files via copy.
# shellcheck source=scripts/lib/portable.sh
. "$SCRIPT_DIR/lib/portable.sh"
th_init "$@"

# --group core|hooks — run only one subset so CI can fan out two parallel jobs
# while run-all-tests.sh (no --group) still runs the full suite unchanged.
# th_init silently ignores unknown flags, so --group passes through without error.
GROUP=""
_ti_prev=""
_ti_group_seen=0
for _ti_a in "$@"; do
  if [[ "$_ti_prev" == "--group" ]]; then GROUP="$_ti_a"; _ti_group_seen=1
  elif [[ "$_ti_a" == "--group="* ]]; then GROUP="${_ti_a#--group=}"; _ti_group_seen=1
  elif [[ "$_ti_a" == "--group" ]]; then _ti_group_seen=1
  fi
  _ti_prev="$_ti_a"
done
if [[ "$_ti_group_seen" -eq 1 && -z "$GROUP" ]]; then
  printf 'test-install: --group requires a value (core or hooks)\n' >&2
  exit 2
fi
unset _ti_a _ti_prev _ti_group_seen
case "$GROUP" in
  ""|core|hooks) ;;
  *) printf 'test-install: --group must be core or hooks (got: %s)\n' "$GROUP" >&2; exit 2 ;;
esac

_TI_PLATFORM="$(detect_platform)"
_ti_is_windows() { [[ "$_TI_PLATFORM" == "windows" ]]; }

# Directory containing jq. Tests that constrain PATH (e.g. to inject a fake
# powershell.exe) must keep jq reachable so install.sh's jq preflight passes;
# on Windows jq lives outside the standard bin dirs (the WinGet dir). Append
# ${_TI_JQ_DIR:+:$_TI_JQ_DIR} to such PATHs — a no-op when jq is already on the
# standard path (Linux/macOS).
_TI_JQ_DIR="$(dirname "$(command -v jq 2>/dev/null)" 2>/dev/null || true)"

# Skip a test on Windows with a visible note. Used for tests that assert
# Linux/codex-platform semantics the Windows install path intentionally omits
# (e.g. codex-executor guard wiring — on Windows `--profile full` downgrades to
# minimal; see install-hooks-windows-full-downgraded-to-minimal). Usage:
#   if _ti_skip_win "$name" "reason"; then return 0; fi
_ti_skip_win() {
  local name="$1" reason="$2"
  _ti_is_windows || return 1
  $LIST || printf 'SKIP: %s (%s)\n' "$name" "$reason"
  return 0
}

# The path form install-hooks.sh writes into settings.json commands: on Windows
# it stores the native form (C:/...) via cygpath, which is what uninstall-hooks.sh
# matches against; on POSIX it stores the path unchanged. Fixtures that hand-write
# hook commands must use this form so removal matching behaves like a real install.
_ti_hook_cmd_path() {
  local p="$1"
  if _ti_is_windows && command -v cygpath >/dev/null 2>&1; then
    cygpath -m -- "$p"
  else
    printf '%s' "$p"
  fi
}

# CC-102 introduced install-hooks.sh profile auto-detection via
# `command -v codex`. Tests in this file written before that change
# expect "full" profile (all six hooks wired). On CI runners codex is
# absent, so without a stub auto-detect picks "minimal" and the
# all-six-hooks assertions fail. Prepend a stub `codex` bin to PATH so
# auto-detect picks "full" for legacy tests; new profile-specific
# tests still pass explicit --profile flags and are unaffected.
_codex_stub_bin="$tmp_root/.codex-stub-bin"
mkdir -p "$_codex_stub_bin"
printf '#!/usr/bin/env bash\nexit 0\n' > "$_codex_stub_bin/codex"
chmod +x "$_codex_stub_bin/codex"
export PATH="$_codex_stub_bin:$PATH"

# Group-aware should_run: when --group is set, skip tests that belong to the
# other group. Hooks-group tests are identified by well-known name prefixes;
# everything else is considered core. Without --group all tests run normally.
_ti_should_run_base() {
  if $LIST; then
    ALL_CASES+=("$1")
    return 1
  fi
  [[ -z "$FILTER" || "$1" == *"$FILTER"* ]]
}

should_run() {
  local _ti_name="$1"
  if [[ -n "$GROUP" ]]; then
    case "$_ti_name" in
      install-sh-wires-hooks*|install-sh-profile-*|\
      install-hooks-*|hooks-*|uninstall-hooks-*|\
      dispatch-allowlist-*|\
      test_install_adds_dispatch_allowlist|\
      test_install_dispatch_allowlist_*|\
      test_dispatch_allowlist_*|\
      userpromptsubmit-*|session-stop-*|statusline-*)
        [[ "$GROUP" == "hooks" ]] || return 1 ;;
      *)
        [[ "$GROUP" == "core" ]] || return 1 ;;
    esac
  fi
  _ti_should_run_base "$@"
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

# Windows installs files via copy fallback (symlink unavailable). Assert that
# path is a real file (not a symlink) whose bytes match src.
assert_copy_of() {
  local name="$1" path="$2" src="$3"
  if [ -L "$path" ] || [ ! -f "$path" ]; then
    fail "$name" "$path is not a real (copied) file"
    return 1
  fi
  if ! cmp -s "$path" "$src"; then
    fail "$name" "$path content does not match $src"
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

link_existing_cmd() {
  local bin="$1" cmd="$2" real
  real="$(command -v "$cmd" 2>/dev/null || true)"
  # Skip shell builtins (command -v returns the bare name, not a path) and
  # non-files — ln -s to a non-file target fails on MSYS. Builtins remain
  # available via bash regardless of PATH. Copy where symlinks are unavailable.
  [[ -n "$real" && -f "$real" ]] || return 0
  ln -sf "$real" "$bin/$cmd" 2>/dev/null || cp "$real" "$bin/$cmd"
}

run_install_case() {
  local name="$1" mode="$2" want_code="$3"
  should_run "$name" || return 0
  local home="$tmp_root/fakehome-$name"
  local out="$tmp_root/$name.stdout"
  local err="$tmp_root/$name.stderr"
  local decoy="$tmp_root/decoy-$name"
  mkdir -p "$home/.claude" "$decoy"

  case "$mode" in
    absent) ;;
    correct-symlink)
      # The "already correctly installed" fixture: a symlink on POSIX, an
      # equivalent junction on Windows (install treats either as idempotent).
      if _ti_is_windows; then
        make_junction_windows "$REPO_ROOT/pm" "$home/.claude/.pm"
      else
        ln -s "$REPO_ROOT/pm" "$home/.claude/.pm"
      fi
      ;;
    wrong-symlink)
      if _ti_is_windows; then
        make_junction_windows "$decoy" "$home/.claude/.pm"
      else
        ln -s "$decoy" "$home/.claude/.pm"
      fi
      ;;
    real-dir)
      mkdir -p "$home/.claude/.pm/some-content"
      ;;
    script-absent) ;;
    script-correct-symlink)
      mkdir -p "$home/.claude/scripts"
      if _ti_is_windows; then
        cp "$REPO_ROOT/scripts/pr-gate.sh" "$home/.claude/scripts/pr-gate.sh"
      else
        ln -s "$REPO_ROOT/scripts/pr-gate.sh" "$home/.claude/scripts/pr-gate.sh"
      fi
      ;;
    script-wrong-symlink)
      mkdir -p "$home/.claude/scripts"
      printf '#!/usr/bin/env bash\n' > "$decoy/pr-gate.sh"
      if _ti_is_windows; then
        cp "$decoy/pr-gate.sh" "$home/.claude/scripts/pr-gate.sh"
      else
        ln -s "$decoy/pr-gate.sh" "$home/.claude/scripts/pr-gate.sh"
      fi
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
      if _ti_is_windows; then
        assert_file_contains "$name" "$out" "junction $home/.claude/.pm -> $REPO_ROOT/pm" || return
      else
        assert_file_contains "$name" "$out" "link   $home/.claude/.pm -> $REPO_ROOT/pm" || return
      fi
      # A junction satisfies -L and readlink returns the target on MSYS, so the
      # same assertion verifies both symlink (POSIX) and junction (Windows).
      assert_symlink_target "$name" "$home/.claude/.pm" "$REPO_ROOT/pm" || return
      ;;
    pm-absent-dry-run)
      if _ti_is_windows; then
        assert_file_contains "$name" "$out" "would junction $home/.claude/.pm -> $REPO_ROOT/pm" || return
      else
        assert_file_contains "$name" "$out" "would  $home/.claude/.pm -> $REPO_ROOT/pm" || return
      fi
      if [ -e "$home/.claude/.pm" ] || [ -L "$home/.claude/.pm" ]; then
        fail "$name" "$home/.claude/.pm should not exist"
        return
      fi
      ;;
    pm-correct-symlink-idempotent)
      assert_file_contains "$name" "$out" "ok    $home/.claude/.pm" || return
      assert_symlink_target "$name" "$home/.claude/.pm" "$REPO_ROOT/pm" || return
      ;;
    pm-wrong-symlink-real-run)
      assert_file_contains "$name" "$err" "CONFLICT" || return
      assert_file_contains "$name" "$err" "expected $REPO_ROOT/pm" || return
      assert_symlink_target "$name" "$home/.claude/.pm" "$decoy" || return
      ;;
    pm-real-dir-real-run)
      assert_file_contains "$name" "$err" "CONFLICT" || return
      assert_file_contains "$name" "$err" "is a real directory" || return
      assert_dir_not_symlink "$name" "$home/.claude/.pm" || return
      ;;
    pm-real-dir-dry-run)
      assert_file_contains "$name" "$err" "CONFLICT" || return
      assert_file_contains "$name" "$err" "is a real directory" || return
      assert_not_contains "$name" "$out" "would  $home/.claude/.pm" || return
      assert_dir_not_symlink "$name" "$home/.claude/.pm" || return
      ;;
    scripts-absent-real-run)
      if _ti_is_windows; then
        assert_file_contains "$name" "$out" "copy   $home/.claude/scripts/pr-gate.sh -> $REPO_ROOT/scripts/pr-gate.sh" || return
        assert_copy_of "$name" "$home/.claude/scripts/pr-gate.sh" "$REPO_ROOT/scripts/pr-gate.sh" || return
      else
        assert_file_contains "$name" "$out" "link   $home/.claude/scripts/pr-gate.sh -> $REPO_ROOT/scripts/pr-gate.sh" || return
        assert_symlink_target "$name" "$home/.claude/scripts/pr-gate.sh" "$REPO_ROOT/scripts/pr-gate.sh" || return
      fi
      ;;
    scripts-correct-symlink-idempotent)
      assert_file_contains "$name" "$out" "ok    $home/.claude/scripts/pr-gate.sh" || return
      assert_symlink_target "$name" "$home/.claude/scripts/pr-gate.sh" "$REPO_ROOT/scripts/pr-gate.sh" || return
      ;;
    scripts-wrong-symlink-real-run)
      assert_file_contains "$name" "$err" "CONFLICT" || return
      assert_file_contains "$name" "$err" "expected $REPO_ROOT/scripts/pr-gate.sh" || return
      assert_symlink_target "$name" "$home/.claude/scripts/pr-gate.sh" "$decoy/pr-gate.sh" || return
      ;;
  esac

  pass "$name"
}

run_install_case "pm-absent-real-run" absent 0
run_install_case "pm-absent-dry-run" absent 0 --dry-run
run_install_case "pm-correct-symlink-idempotent" correct-symlink 0
run_install_case "pm-real-dir-real-run" real-dir 1
run_install_case "scripts-absent-real-run" script-absent 0
# These three assert symlink-specific conflict semantics: replace-on-wrong-
# target (.pm) and symlink idempotency / wrong-target conflict (scripts). On
# Windows, directories install as junctions and files as copies, where a
# pre-existing foreign file is a "not a symlink — skipping" conflict rather than
# these symlink outcomes. Skip on Windows rather than assert behavior the
# platform does not implement; junction/copy paths are exercised by the
# absent/correct/real-dir cases above and the manifest mode tests below.
if _ti_is_windows; then
  $LIST || printf 'SKIP: pm-wrong-symlink-real-run (POSIX symlink semantics; Windows uses junctions)\n'
  $LIST || printf 'SKIP: pm-real-dir-dry-run (POSIX detects real-dir conflict in dry-run; Windows junction dry-run does not)\n'
  $LIST || printf 'SKIP: scripts-correct-symlink-idempotent (POSIX symlink semantics; Windows uses copy)\n'
  $LIST || printf 'SKIP: scripts-wrong-symlink-real-run (POSIX symlink semantics; Windows uses copy)\n'
else
  run_install_case "pm-wrong-symlink-real-run" wrong-symlink 1
  run_install_case "pm-real-dir-dry-run" real-dir 1 --dry-run
  run_install_case "scripts-correct-symlink-idempotent" script-correct-symlink 0
  run_install_case "scripts-wrong-symlink-real-run" script-wrong-symlink 0
fi

test_pmctl_symlink_install_idempotent() {
  # Verifies install symlinks cli/pmctl into ~/.local/bin and is idempotent.
  #
  # Steps:
  #   1. Run install.sh twice with a sandbox HOME.
  #   2. Assert both runs exit 0.
  #   3. Assert ~/.local/bin/pmctl -> <repo>/cli/pmctl, first run prints "link"
  #      + the PATH-remediation note, second run prints "ok" (no clobber).
  local name="pmctl-symlink-install-idempotent"
  should_run "$name" || return 0
  if _ti_skip_win "$name" "Windows uses manual PATH for pmctl, never copy/symlink"; then return 0; fi

  local home="$tmp_root/$name"
  local out1="$tmp_root/$name-1.out"
  local out2="$tmp_root/$name-2.out"
  local err1="$tmp_root/$name-1.err"
  local err2="$tmp_root/$name-2.err"
  local dest="$home/.local/bin/pmctl"
  mkdir -p "$home/.claude"

  set +e
  HOME="$home" \
    CLAUDE_CONFIG_TEST_INSTALL_RUNNING=1 \
    CLAUDE_CONFIG_TEST_PREFLIGHT_HOME="$REAL_HOME" \
    bash "$REPO_ROOT/install.sh" >"$out1" 2>"$err1"
  local code1=$?
  HOME="$home" \
    CLAUDE_CONFIG_TEST_INSTALL_RUNNING=1 \
    CLAUDE_CONFIG_TEST_PREFLIGHT_HOME="$REAL_HOME" \
    bash "$REPO_ROOT/install.sh" >"$out2" 2>"$err2"
  local code2=$?
  set -e

  if [[ "$code1" -ne 0 || "$code2" -ne 0 ]]; then
    fail "$name" "install exits were $code1 and $code2, expected 0"
    return
  fi
  assert_symlink_target "$name" "$dest" "$REPO_ROOT/cli/pmctl" || return
  assert_file_contains "$name" "$out1" "link   $dest -> $REPO_ROOT/cli/pmctl" || return
  assert_file_contains "$name" "$out1" "export PATH=\"$home/.local/bin:\$PATH\"" || return
  assert_file_contains "$name" "$out2" "ok    $dest" || return
  pass "$name"
}

test_pmctl_install_preserves_foreign_file() {
  # Verifies install never clobbers a pre-existing foreign ~/.local/bin/pmctl.
  #
  # Steps:
  #   1. Pre-create a plain (non-ours) ~/.local/bin/pmctl file.
  #   2. Run install.sh with a sandbox HOME.
  #   3. Assert the foreign file is preserved (not overwritten) and a conflict
  #      is reported (install remains non-fatal).
  local name="pmctl-install-preserves-foreign-file"
  should_run "$name" || return 0
  if _ti_skip_win "$name" "Windows uses manual PATH for pmctl, never copy/symlink"; then return 0; fi

  local home="$tmp_root/$name"
  local out="$tmp_root/$name.out"
  local err="$tmp_root/$name.err"
  local dest="$home/.local/bin/pmctl"
  mkdir -p "$home/.claude" "$(dirname "$dest")"
  printf 'foreign pmctl\n' > "$dest"

  set +e
  HOME="$home" \
    CLAUDE_CONFIG_TEST_INSTALL_RUNNING=1 \
    CLAUDE_CONFIG_TEST_PREFLIGHT_HOME="$REAL_HOME" \
    bash "$REPO_ROOT/install.sh" >"$out" 2>"$err"
  local code=$?
  set -e

  if [[ "$code" -ne 0 ]]; then
    fail "$name" "exit $code, expected 0"
    return
  fi
  assert_file_content "$name" "$dest" "foreign pmctl" || return
  assert_file_contains "$name" "$err" "CONFLICT $dest exists and is not our symlink" || return
  pass "$name"
}

test_pmctl_windows_manual_path_no_copy() {
  # Verifies that on Windows install prints manual-PATH guidance and does NOT
  # copy or symlink pmctl (a copied pmctl cannot resolve its repo libs).
  #
  # Steps:
  #   1. Run install.sh with PM_DISPATCH_PLATFORM=windows and a sandbox HOME.
  #   2. Assert exit 0 and the "add <repo>/cli to PATH manually" + no-copy note.
  #   3. Assert ~/.local/bin/pmctl is NOT created.
  local name="pmctl-windows-manual-path-no-copy"
  should_run "$name" || return 0

  local home="$tmp_root/$name"
  local out="$tmp_root/$name.out"
  local err="$tmp_root/$name.err"
  local dest="$home/.local/bin/pmctl"
  mkdir -p "$home/.claude"

  set +e
  HOME="$home" \
    PM_DISPATCH_PLATFORM=windows \
    CLAUDE_CONFIG_TEST_INSTALL_RUNNING=1 \
    CLAUDE_CONFIG_TEST_PREFLIGHT_HOME="$REAL_HOME" \
    bash "$REPO_ROOT/install.sh" >"$out" 2>"$err"
  local code=$?
  set -e

  if [[ "$code" -ne 0 ]]; then
    fail "$name" "exit $code, expected 0"
    return
  fi
  assert_file_contains "$name" "$out" "add $REPO_ROOT/cli to PATH manually" || return
  assert_file_contains "$name" "$out" "a copied pmctl cannot resolve repo libs" || return
  if [[ -e "$dest" || -L "$dest" ]]; then
    fail "$name" "$dest should not be created on Windows"
    return
  fi
  pass "$name"
}

test_doctor_pmctl_missing_reports_remediation() {
  # Verifies doctor.sh reports a WARN with remediation when pmctl is absent.
  #
  # Steps:
  #   1. Build a PATH with only basic utilities (no pmctl).
  #   2. Run doctor.sh --repo <repo>.
  #   3. Assert output contains "[WARN] pmctl not found on PATH" and the
  #      install.sh remediation hint.
  local name="doctor-pmctl-missing-reports-remediation"
  should_run "$name" || return 0
  if ! command -v jq >/dev/null 2>&1; then
    pass "$name (jq not available - skip)"
    return
  fi

  local home="$tmp_root/$name"
  local bin="$tmp_root/$name-bin"
  local out status=0 bash_real
  mkdir -p "$home/.claude" "$bin"
  printf '{}\n' > "$home/.claude/settings.json"
  for cmd in bash dirname pwd readlink uname jq sed grep awk python3 tr basename; do
    link_existing_cmd "$bin" "$cmd"
  done
  bash_real="$(command -v bash)"

  out="$(HOME="$home" CLAUDE_CONFIG_DIR="$home/.claude" PATH="$bin" "$bash_real" "$REPO_ROOT/scripts/doctor.sh" --no-color --repo "$REPO_ROOT" 2>&1)" || status=$?
  if [[ "$out" == *"[WARN] pmctl not found on PATH"* && "$out" == *"bash '$REPO_ROOT/install.sh'"* ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$out"
  fi
}

test_pmctl_symlink_install_idempotent
test_pmctl_install_preserves_foreign_file
test_pmctl_windows_manual_path_no_copy
test_doctor_pmctl_missing_reports_remediation

test_install_manifest_atomic() {
  local name="install-manifest-atomic"
  should_run "$name" || return 0

  local home="$tmp_root/$name"
  local out="$tmp_root/$name.out"
  local err="$tmp_root/$name.err"
  local manifest
  local expected_entries=0
  local actual_entries

  mkdir -p "$home/.claude"

  set +e
  HOME="$home" \
    CLAUDE_CONFIG_TEST_INSTALL_RUNNING=1 \
    CLAUDE_CONFIG_TEST_PREFLIGHT_HOME="$REAL_HOME" \
    bash "$REPO_ROOT/install.sh" >"$out" 2>"$err"
  local got_code=$?
  set -e

  if [[ "$got_code" -ne 0 ]]; then
    fail "$name" "exit $got_code, expected 0"
    return
  fi

  shopt -s nullglob
  if _ti_is_windows; then
    # Windows installs each of agents/skills/commands/adapters as a single
    # directory junction (one manifest entry per subdir), not per-file.
    for subdir in agents skills commands adapters; do
      [[ -d "$REPO_ROOT/$subdir" ]] && expected_entries=$((expected_entries + 1))
    done
  else
    for subdir in agents skills commands adapters; do
      [[ -d "$REPO_ROOT/$subdir" ]] || continue
      for _ in "$REPO_ROOT/$subdir"/*; do
        expected_entries=$((expected_entries + 1))
      done
    done
  fi
  for script in token-usage.sh log-usage.sh pr-gate.sh codex-dispatch.sh setup-project.sh patch-gitignore.sh doctor.sh; do
    [[ -e "$REPO_ROOT/scripts/$script" ]] && expected_entries=$((expected_entries + 1))
  done
  [[ -d "$REPO_ROOT/pm" ]] && expected_entries=$((expected_entries + 1))
  [[ -f "$REPO_ROOT/share/model-aliases.tsv" ]] && expected_entries=$((expected_entries + 1))
  shopt -u nullglob

  manifest="$home/.claude/.pm-dispatch/install-manifest.json"
  if [[ ! -f "$manifest" ]]; then
    fail "$name" "missing manifest file $manifest"
    return
  fi
  if compgen -G "$home/.claude/.pm-dispatch/.install-manifest.*" >/dev/null 2>&1; then
    fail "$name" "temporary manifest file leak suggests non-atomic write"
    return
  fi
  if ! jq -e --argjson expected "$expected_entries" '
    .manifest_version == 1 and
    (.installed_at | test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$")) and
    ((.entries | type) == "array") and
    ((.entries | length) == $expected) and
    (.entries | all(
      has("src") and has("dst") and has("mode") and
      (.src != .dst) and
      (
        ((.mode == "symlink" or .mode == "junction")
         and (has("sha256") | not)
         and (has("fallback_reason") | not))
        or
        (.mode == "copy"
         and has("sha256")
         and (.sha256 | test("^[0-9a-f]{64}$"))
         and has("fallback_reason")
         and (.fallback_reason != ""))
      )
    )) and
    (.entries | all(.mode == "copy" or .mode == "symlink" or .mode == "junction"))
  ' "$manifest" >/dev/null 2>&1; then
    fail "$name" "manifest shape/content invalid"
    return
  fi

  actual_entries="$(jq -r '.entries | length' "$manifest")"
  if [[ "$actual_entries" != "$expected_entries" ]]; then
    fail "$name" "expected $expected_entries manifest entries, got $actual_entries"
    return
  fi
  pass "$name"
}

test_legacy_pm_left_untouched() {
  local name="legacy-github-pm-left-untouched"
  should_run "$name" || return 0
  if _ti_skip_win "$name" "exercises legacy symlink coexistence; ln -s has no real-symlink support on MSYS"; then return 0; fi

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
  should_run "$name" || return 0
  if _ti_skip_win "$name" "exercises legacy stale-symlink cleanup; ln -s has no real-symlink support on MSYS"; then return 0; fi

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
  assert_file_contains "$name" "$script_out" "remove (legacy)" || return

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

  # claude-usage.sh → token-usage.sh rename: stale helper symlink must be removed.
  local usage_home="$tmp_root/$name-usage-home"
  local usage_out="$tmp_root/$name-usage.stdout"
  mkdir -p "$usage_home/.claude/scripts"
  ln -s "$REPO_ROOT/scripts/claude-usage.sh" "$usage_home/.claude/scripts/claude-usage.sh" 2>/dev/null || \
    ln -s "/dev/null" "$usage_home/.claude/scripts/claude-usage.sh"

  set +e
  HOME="$usage_home" \
    CLAUDE_CONFIG_TEST_INSTALL_RUNNING=1 \
    CLAUDE_CONFIG_TEST_PREFLIGHT_HOME="$REAL_HOME" \
    bash "$REPO_ROOT/install.sh" >"$usage_out" 2>/dev/null
  local usage_code=$?
  set -e

  if [ "$usage_code" -ne 0 ]; then
    fail "$name" "claude-usage legacy install exit $usage_code, expected 0"
    return
  fi
  if [ -e "$usage_home/.claude/scripts/claude-usage.sh" ] || [ -L "$usage_home/.claude/scripts/claude-usage.sh" ]; then
    fail "$name" "$usage_home/.claude/scripts/claude-usage.sh should have been removed"
    return
  fi
  assert_file_contains "$name" "$usage_out" "remove (legacy)" || return

  pass "$name"
}

# ── install-hooks / uninstall-hooks lifecycle ─────────────────────────────────
# Proves that install-hooks.sh wires all six managed hooks and that
# uninstall-hooks.sh removes each of them completely, leaving no orphaned entries.

test_install_sh_wires_hooks() {
  # Proves that the primary install.sh path wires all six managed hooks
  # into settings.json automatically — no manual install-hooks.sh step needed.
  # Pre-CC-102 this test relied on the host having codex on PATH to pick
  # "full" profile auto-detection; on CI runners codex is absent, so the
  # test now passes --profile full explicitly to preserve its original
  # all-six-hooks assertion regardless of host codex availability.
  local name="install-sh-wires-hooks"
  should_run "$name" || return 0
  if _ti_skip_win "$name" "asserts codex guards wired; Windows downgrades --profile full to minimal"; then return 0; fi
  local home="$tmp_root/$name"
  mkdir -p "$home/.claude"
  printf '{"permissions":{}}\n' > "$home/.claude/settings.json"

  HOME="$home" \
    CLAUDE_CONFIG_TEST_INSTALL_RUNNING=1 \
    CLAUDE_CONFIG_TEST_PREFLIGHT_HOME="$REAL_HOME" \
    bash "$REPO_ROOT/install.sh" --profile full > /dev/null 2>&1

  assert_file_contains "$name" "$home/.claude/settings.json" "hook-pm-write-guard.sh" || return
  assert_file_contains "$name" "$home/.claude/settings.json" "hook-codex-bash-guard.sh" || return
  assert_file_contains "$name" "$home/.claude/settings.json" "hook-codex-write-guard.sh" || return
  assert_file_contains "$name" "$home/.claude/settings.json" "hook-tool-trace.sh" || return
  assert_file_contains "$name" "$home/.claude/settings.json" "hook-log-claude-usage.sh" || return
  assert_file_contains "$name" "$home/.claude/settings.json" "hook-routing-log.sh" || return
  assert_file_contains "$name" "$home/.claude/settings.json" "hook-inject-memory.sh" || return
  assert_file_contains "$name" "$home/.claude/settings.json" "hook-save-rate-limits.sh" || return
  if [[ -f "$home/.claude/statusline-chain.conf" ]]; then
    fail "$name" "statusline-chain.conf should not exist without previous statusLine"
    return
  fi
  pass "$name"
}

test_install_sh_profile_minimal_skips_codex_hooks() {
  # Proves --profile minimal does NOT wire the two codex-* guards but keeps
  # the other managed hooks (pm-write-guard, log-usage, inject-memory,
  # save-rate-limits).
  local name="install-sh-profile-minimal-skips-codex-hooks"
  should_run "$name" || return 0
  local home="$tmp_root/$name"
  mkdir -p "$home/.claude"
  printf '{"permissions":{}}\n' > "$home/.claude/settings.json"

  HOME="$home" \
    CLAUDE_CONFIG_TEST_INSTALL_RUNNING=1 \
    CLAUDE_CONFIG_TEST_PREFLIGHT_HOME="$REAL_HOME" \
    bash "$REPO_ROOT/install.sh" --profile minimal > /dev/null 2>&1

  assert_file_contains "$name" "$home/.claude/settings.json" "hook-pm-write-guard.sh" || return
  assert_not_contains "$name" "$home/.claude/settings.json" "hook-codex-bash-guard.sh" || return
  assert_not_contains "$name" "$home/.claude/settings.json" "hook-codex-write-guard.sh" || return
  assert_file_contains "$name" "$home/.claude/settings.json" "hook-log-claude-usage.sh" || return
  assert_file_contains "$name" "$home/.claude/settings.json" "hook-inject-memory.sh" || return
  pass "$name"
}

test_install_sh_profile_full_wires_codex_hooks() {
  # Proves --profile full explicitly wires every managed hook, including
  # the two codex-* guards (regardless of whether codex is on PATH).
  local name="install-sh-profile-full-wires-codex-hooks"
  should_run "$name" || return 0
  if _ti_skip_win "$name" "asserts codex guards wired; Windows downgrades --profile full to minimal"; then return 0; fi
  local home="$tmp_root/$name"
  mkdir -p "$home/.claude"
  printf '{"permissions":{}}\n' > "$home/.claude/settings.json"

  HOME="$home" \
    CLAUDE_CONFIG_TEST_INSTALL_RUNNING=1 \
    CLAUDE_CONFIG_TEST_PREFLIGHT_HOME="$REAL_HOME" \
    bash "$REPO_ROOT/install.sh" --profile full > /dev/null 2>&1

  assert_file_contains "$name" "$home/.claude/settings.json" "hook-pm-write-guard.sh" || return
  assert_file_contains "$name" "$home/.claude/settings.json" "hook-codex-bash-guard.sh" || return
  assert_file_contains "$name" "$home/.claude/settings.json" "hook-codex-write-guard.sh" || return
  pass "$name"
}

dispatch_allowlist_entries_for_home() {
  # Mirrors dispatch_allowlist_entries() from scripts/lib/allowlist.sh but accepts
  # an explicit home arg (tests use a temp dir, not the real $HOME).
  local home="$1"
  local f rel

  f="$REPO_ROOT/scripts/codex-dispatch.sh"
  if [[ -f "$f" ]]; then
    rel="${f#"$home/"}"
    printf 'Bash(%s:*)\nBash(~/%s:*)\n' "$f" "$rel"
  fi
  for f in "$REPO_ROOT/adapters"/*/dispatch.sh; do
    [[ -f "$f" ]] || continue
    rel="${f#"$home/"}"
    printf 'Bash(%s:*)\nBash(~/%s:*)\n' "$f" "$rel"
  done
}

test_install_adds_dispatch_allowlist() {
  local name="test_install_adds_dispatch_allowlist"
  should_run "$name" || return 0
  local home="$tmp_root/$name"
  local settings="$home/.claude/settings.json"
  local entry
  # Verifies that install.sh adds all four dispatch allowlist entries to a fresh settings.json.
  #
  # Steps:
  #   1. Create a temporary home with an empty settings.json (no permissions.allow).
  #   2. Run install.sh with that HOME.
  #   3. Assert all four Bash(...) entries appear in permissions.allow.
  mkdir -p "$home/.claude"
  printf '{}\n' > "$settings"

  HOME="$home" \
    CLAUDE_CONFIG_TEST_INSTALL_RUNNING=1 \
    CLAUDE_CONFIG_TEST_PREFLIGHT_HOME="$REAL_HOME" \
    bash "$REPO_ROOT/install.sh" >/dev/null 2>&1

  while IFS= read -r entry; do
    if ! jq -e --arg e "$entry" '(.permissions.allow // [] | index($e)) != null' "$settings" >/dev/null; then
      fail "$name" "missing allowlist entry: $entry"
      return
    fi
  done < <(dispatch_allowlist_entries_for_home "$home")
  pass "$name"
}

test_install_dispatch_allowlist_idempotent() {
  local name="test_install_dispatch_allowlist_idempotent"
  should_run "$name" || return 0
  local home="$tmp_root/$name"
  local settings="$home/.claude/settings.json"
  local entry count
  # Verifies that re-running install.sh does not duplicate dispatch allowlist entries.
  #
  # Steps:
  #   1. Run install.sh once to populate a fresh settings.json.
  #   2. Run install.sh a second time against the same settings.json.
  #   3. Assert each of the four entries appears exactly once.
  mkdir -p "$home/.claude"
  printf '{}\n' > "$settings"

  HOME="$home" \
    CLAUDE_CONFIG_TEST_INSTALL_RUNNING=1 \
    CLAUDE_CONFIG_TEST_PREFLIGHT_HOME="$REAL_HOME" \
    bash "$REPO_ROOT/install.sh" >/dev/null 2>&1
  HOME="$home" \
    CLAUDE_CONFIG_TEST_INSTALL_RUNNING=1 \
    CLAUDE_CONFIG_TEST_PREFLIGHT_HOME="$REAL_HOME" \
    bash "$REPO_ROOT/install.sh" >/dev/null 2>&1

  while IFS= read -r entry; do
    count="$(jq -r --arg e "$entry" '[.permissions.allow[]? | select(. == $e)] | length' "$settings")"
    if [[ "$count" != "1" ]]; then
      fail "$name" "entry count for $entry was $count, expected 1"
      return
    fi
  done < <(dispatch_allowlist_entries_for_home "$home")
  pass "$name"
}

test_install_dispatch_allowlist_backup_timestamped() {
  local name="test_install_dispatch_allowlist_backup_timestamped"
  should_run "$name" || return 0
  # Verifies that install.sh creates a timestamped backup of settings.json
  # before mutating it, and that the backup is byte-identical to the original.
  #
  # Steps:
  #   1. Create a fresh settings.json with known content.
  #   2. Capture its checksum.
  #   3. Run install.sh.
  #   4. Assert a settings.json.bak.* file exists (glob pattern).
  #   5. Assert the backup is byte-identical to the pre-install content.
  local home="$tmp_root/$name"
  local settings="$home/.claude/settings.json"
  mkdir -p "$home/.claude"
  printf '{}\n' > "$settings"
  local before
  before="$(md5sum "$settings" | awk '{print $1}')"

  HOME="$home" \
    CLAUDE_CONFIG_TEST_INSTALL_RUNNING=1 \
    CLAUDE_CONFIG_TEST_PREFLIGHT_HOME="$REAL_HOME" \
    bash "$REPO_ROOT/install.sh" >/dev/null 2>&1

  local bak
  bak="$(ls "$home/.claude/settings.json.bak."* 2>/dev/null | head -1)"
  if [[ -z "$bak" ]]; then
    fail "$name" "no timestamped backup found (settings.json.bak.*)"
    return
  fi
  local after
  after="$(md5sum "$bak" | awk '{print $1}')"
  if [[ "$before" == "$after" ]]; then
    pass "$name"
  else
    fail "$name" "backup $bak is not byte-identical to pre-install settings (before=$before after=$after)"
  fi
}

test_dispatch_allowlist_lib_parity() {
  local name="test_dispatch_allowlist_lib_parity"
  should_run "$name" || return 0
  # Verifies that scripts/lib/allowlist.sh dispatch_allowlist_entries() produces
  # the same entries as the test helper dispatch_allowlist_entries_for_home()
  # for the same home directory, proving they share one source of truth.
  # Entry count is dynamic (compat shim + one entry per adapters/*/dispatch.sh).
  local parity_home="$tmp_root/parity-home"
  mkdir -p "$parity_home"

  local from_lib from_helper
  from_lib="$(REPO_ROOT="$REPO_ROOT" HOME="$parity_home" bash -c \
    '. "$1/scripts/lib/allowlist.sh"; dispatch_allowlist_entries' \
    _ "$REPO_ROOT")"
  from_helper="$(dispatch_allowlist_entries_for_home "$parity_home")"

  if [[ "$from_lib" == "$from_helper" ]]; then
    pass "$name"
  else
    fail "$name" "lib output:\n$from_lib\nhelper output:\n$from_helper"
  fi
}

test_dispatch_allowlist_uninstall_removes_entries() {
  # Verifies uninstall-hooks.sh removes all four dispatch Bash allowlist
  # entries while leaving unrelated permissions.allow entries intact.
  #
  # Steps:
  #   1. Run install.sh to populate the four allowlist entries.
  #   2. Manually inject an unrelated allow entry.
  #   3. Run uninstall-hooks.sh.
  #   4. Assert the four managed entries are gone; unrelated entry remains.
  local name="dispatch-allowlist-uninstall-removes-entries"
  should_run "$name" || return 0
  local home="$tmp_root/$name"
  local settings="$home/.claude/settings.json"
  local unrelated="Bash(/usr/local/bin/safe-tool:*)"
  mkdir -p "$home/.claude"
  printf '{}\n' > "$settings"

  HOME="$home" \
    CLAUDE_CONFIG_TEST_INSTALL_RUNNING=1 \
    CLAUDE_CONFIG_TEST_PREFLIGHT_HOME="$REAL_HOME" \
    bash "$REPO_ROOT/install.sh" >/dev/null 2>&1
  jq --arg u "$unrelated" '.permissions.allow += [$u]' "$settings" > "${settings}.tmp" && mv "${settings}.tmp" "$settings"

  HOME="$home" bash "$REPO_ROOT/scripts/uninstall-hooks.sh" > /dev/null

  local entry
  while IFS= read -r entry; do
    if jq -e --arg e "$entry" '(.permissions.allow // [] | index($e)) != null' "$settings" >/dev/null 2>&1; then
      fail "$name" "allowlist entry should be gone: $entry"
      return
    fi
  done < <(dispatch_allowlist_entries_for_home "$home")
  assert_file_contains "$name" "$settings" "$unrelated" || return
  pass "$name"
}

test_dispatch_allowlist_uninstall_dryrun() {
  # Verifies that --dry-run does not modify settings.json.
  #
  # Steps:
  #   1. Run install.sh to populate the four allowlist entries.
  #   2. Capture the settings checksum.
  #   3. Run uninstall-hooks.sh --dry-run.
  #   4. Assert settings.json is byte-identical to before.
  local name="dispatch-allowlist-uninstall-dryrun"
  should_run "$name" || return 0
  local home="$tmp_root/$name"
  local settings="$home/.claude/settings.json"
  mkdir -p "$home/.claude"
  printf '{}\n' > "$settings"

  HOME="$home" \
    CLAUDE_CONFIG_TEST_INSTALL_RUNNING=1 \
    CLAUDE_CONFIG_TEST_PREFLIGHT_HOME="$REAL_HOME" \
    bash "$REPO_ROOT/install.sh" >/dev/null 2>&1
  local before after
  before="$(md5sum "$settings" | awk '{print $1}')"

  HOME="$home" bash "$REPO_ROOT/scripts/uninstall-hooks.sh" --dry-run > /dev/null

  after="$(md5sum "$settings" | awk '{print $1}')"
  if [[ "$before" != "$after" ]]; then
    fail "$name" "settings.json was modified by --dry-run"
    return
  fi
  pass "$name"
}

test_install_hooks_windows_profile_full_downgrades_to_minimal() {
  # Proves PM_DISPATCH_PLATFORM=windows and --profile full downgrades to minimal.
  # Codex hooks are not wired; base managed hooks still are. The expected warning
  # about fallback to minimal is also required.
  local name="install-hooks-windows-full-downgraded-to-minimal"
  should_run "$name" || return 0
  local home="$tmp_root/$name"
  local out err
  mkdir -p "$home/.claude"
  printf '{"permissions":{}}\n' > "$home/.claude/settings.json"

  out="$tmp_root/$name.out"
  err="$tmp_root/$name.err"
  set +e
  HOME="$home" \
    CLAUDE_CONFIG_TEST_INSTALL_RUNNING=1 \
    PM_DISPATCH_PLATFORM=windows \
    bash "$REPO_ROOT/scripts/install-hooks.sh" --profile full >"$out" 2>"$err"
  local code=$?
  set -e

  if [ "$code" -ne 0 ]; then
    fail "$name" "exit $code, expected 0"
    return
  fi

  if ! grep -q 'platform=windows, --profile full requested; codex hooks unsupported on Windows yet, falling back to minimal' "$err"; then
    fail "$name" "missing profile downgrade warning"
    return
  fi

  assert_file_contains "$name" "$home/.claude/settings.json" "hook-pm-write-guard.sh" || return
  assert_file_contains "$name" "$home/.claude/settings.json" "hook-tool-trace.sh" || return
  assert_file_contains "$name" "$home/.claude/settings.json" "hook-routing-log.sh" || return
  assert_file_contains "$name" "$home/.claude/settings.json" "hook-log-claude-usage.sh" || return
  assert_file_contains "$name" "$home/.claude/settings.json" "hook-session-summary.sh" || return
  assert_not_contains "$name" "$home/.claude/settings.json" "hook-codex-bash-guard.sh" || return
  assert_not_contains "$name" "$home/.claude/settings.json" "hook-codex-write-guard.sh" || return
  pass "$name"
}

test_install_hooks_windows_profile_minimal_silent() {
  # Proves PM_DISPATCH_PLATFORM=windows and --profile minimal does not emit the
  # full-profile downgrade warning and does not wire codex hooks.
  local name="install-hooks-windows-minimal-silent"
  should_run "$name" || return 0
  local home="$tmp_root/$name"
  local out err
  mkdir -p "$home/.claude"
  printf '{"permissions":{}}\n' > "$home/.claude/settings.json"

  out="$tmp_root/$name.out"
  err="$tmp_root/$name.err"
  set +e
  HOME="$home" \
    CLAUDE_CONFIG_TEST_INSTALL_RUNNING=1 \
    PM_DISPATCH_PLATFORM=windows \
    bash "$REPO_ROOT/scripts/install-hooks.sh" --profile minimal >"$out" 2>"$err"
  local code=$?
  set -e

  if [ "$code" -ne 0 ]; then
    fail "$name" "exit $code, expected 0"
    return
  fi

  if grep -q 'platform=windows, --profile full requested; codex hooks unsupported on Windows yet, falling back to minimal' "$err"; then
    fail "$name" "unexpected downgrade warning on minimal profile"
    return
  fi

  assert_file_contains "$name" "$home/.claude/settings.json" "hook-pm-write-guard.sh" || return
  assert_file_contains "$name" "$home/.claude/settings.json" "hook-tool-trace.sh" || return
  assert_file_contains "$name" "$home/.claude/settings.json" "hook-routing-log.sh" || return
  assert_file_contains "$name" "$home/.claude/settings.json" "hook-log-claude-usage.sh" || return
  assert_file_contains "$name" "$home/.claude/settings.json" "hook-session-summary.sh" || return
  assert_not_contains "$name" "$home/.claude/settings.json" "hook-codex-bash-guard.sh" || return
  assert_not_contains "$name" "$home/.claude/settings.json" "hook-codex-write-guard.sh" || return
  pass "$name"
}

test_install_hooks_profile_downgrade_removes_codex() {
  # Proves that running install-hooks.sh with --profile full and then again
  # with --profile minimal converges to the minimal hook set — codex guards
  # installed by the first run must be removed by the second run.
  local name="install-hooks-profile-downgrade-removes-codex"
  should_run "$name" || return 0
  if _ti_skip_win "$name" "asserts codex guards wired by --profile full; Windows downgrades to minimal"; then return 0; fi
  local home="$tmp_root/$name"
  mkdir -p "$home/.claude"
  printf '{"permissions":{}}\n' > "$home/.claude/settings.json"

  HOME="$home" bash "$REPO_ROOT/scripts/install-hooks.sh" --profile full > /dev/null
  assert_file_contains "$name" "$home/.claude/settings.json" "hook-codex-bash-guard.sh" || return
  assert_file_contains "$name" "$home/.claude/settings.json" "hook-codex-write-guard.sh" || return

  HOME="$home" bash "$REPO_ROOT/scripts/install-hooks.sh" --profile minimal > /dev/null
  assert_not_contains "$name" "$home/.claude/settings.json" "hook-codex-bash-guard.sh" || return
  assert_not_contains "$name" "$home/.claude/settings.json" "hook-codex-write-guard.sh" || return
  # The non-codex managed hooks must still be present after downgrade.
  assert_file_contains "$name" "$home/.claude/settings.json" "hook-pm-write-guard.sh" || return
  assert_file_contains "$name" "$home/.claude/settings.json" "hook-inject-memory.sh" || return
  pass "$name"
}

test_install_hooks_auto_detect_with_codex_wires_full() {
  # Proves omitted --profile flag + codex on PATH resolves to full
  # (wires the two codex-* guards). Uses a stub codex binary in a
  # tmp bin dir prepended to PATH so the test does not depend on the
  # host having codex installed.
  local name="install-hooks-auto-detect-codex-present-wires-full"
  should_run "$name" || return 0
  if _ti_skip_win "$name" "codex-present auto-detect wires full on POSIX; Windows downgrades to minimal"; then return 0; fi
  local home="$tmp_root/$name"
  mkdir -p "$home/.claude"
  printf '{"permissions":{}}\n' > "$home/.claude/settings.json"

  local stub_bin="$home/.stub-bin"
  mkdir -p "$stub_bin"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$stub_bin/codex"
  chmod +x "$stub_bin/codex"

  HOME="$home" PATH="$stub_bin:$PATH" \
    bash "$REPO_ROOT/scripts/install-hooks.sh" > /dev/null

  assert_file_contains "$name" "$home/.claude/settings.json" "hook-codex-bash-guard.sh" || return
  assert_file_contains "$name" "$home/.claude/settings.json" "hook-codex-write-guard.sh" || return
  pass "$name"
}

test_install_hooks_auto_detect_without_codex_wires_minimal() {
  # Proves omitted --profile flag + codex absent from PATH resolves to
  # minimal (skips codex-* guards). Uses a minimal PATH that excludes
  # any user-local bin dirs where codex might live.
  local name="install-hooks-auto-detect-codex-absent-wires-minimal"
  should_run "$name" || return 0
  local home="$tmp_root/$name"
  mkdir -p "$home/.claude"
  printf '{"permissions":{}}\n' > "$home/.claude/settings.json"

  local minimal_path="/usr/bin:/bin"
  # jq may live outside /usr/bin (e.g. the WinGet dir on Windows); append its
  # directory (computed once as $_TI_JQ_DIR) so the jq precondition holds
  # cross-platform. codex is still excluded (and is checked below). On Linux jq
  # is already in /usr/bin, so this is a no-op there.
  [[ -n "$_TI_JQ_DIR" ]] && minimal_path="$minimal_path:$_TI_JQ_DIR"
  if PATH="$minimal_path" command -v codex >/dev/null 2>&1; then
    fail "$name" "precondition failed: codex unexpectedly visible in minimal PATH"
    return
  fi
  if ! PATH="$minimal_path" command -v jq >/dev/null 2>&1; then
    fail "$name" "precondition failed: jq missing from minimal PATH (install-hooks.sh needs it)"
    return
  fi

  HOME="$home" PATH="$minimal_path" \
    bash "$REPO_ROOT/scripts/install-hooks.sh" > /dev/null

  assert_not_contains "$name" "$home/.claude/settings.json" "hook-codex-bash-guard.sh" || return
  assert_not_contains "$name" "$home/.claude/settings.json" "hook-codex-write-guard.sh" || return
  assert_file_contains "$name" "$home/.claude/settings.json" "hook-pm-write-guard.sh" || return
  pass "$name"
}

test_install_hooks_dry_run_does_not_modify() {
  # Proves --dry-run prints a diff but does not modify settings.json.
  local name="install-hooks-dry-run-does-not-modify-settings"
  should_run "$name" || return 0
  local home="$tmp_root/$name"
  mkdir -p "$home/.claude"
  printf '{"permissions":{}}\n' > "$home/.claude/settings.json"
  local before_hash
  before_hash="$(sha256sum < "$home/.claude/settings.json" | awk '{print $1}')"

  HOME="$home" bash "$REPO_ROOT/scripts/install-hooks.sh" --dry-run --profile minimal > /dev/null

  local after_hash
  after_hash="$(sha256sum < "$home/.claude/settings.json" | awk '{print $1}')"
  if [[ "$before_hash" == "$after_hash" ]]; then
    pass "$name"
  else
    fail "$name" "settings.json was modified despite --dry-run"
  fi
}

test_install_hooks_platform_linux_explicit() {
  # Proves --platform linux works (explicit, not auto) and wires hooks
  # the same way auto-detect on a Linux host would.
  local name="install-hooks-platform-linux-explicit-wires-normally"
  should_run "$name" || return 0
  local home="$tmp_root/$name"
  mkdir -p "$home/.claude"
  printf '{"permissions":{}}\n' > "$home/.claude/settings.json"

  HOME="$home" bash "$REPO_ROOT/scripts/install-hooks.sh" --platform linux --profile full > /dev/null

  assert_file_contains "$name" "$home/.claude/settings.json" "hook-pm-write-guard.sh" || return
  assert_file_contains "$name" "$home/.claude/settings.json" "hook-codex-bash-guard.sh" || return
  assert_file_contains "$name" "$home/.claude/settings.json" "hook-codex-write-guard.sh" || return
  pass "$name"
}

test_install_hooks_platform_invalid_value_rejected() {
  # Proves --platform with an unknown value is rejected with exit 2.
  local name="install-hooks-platform-invalid-value-rejected"
  should_run "$name" || return 0
  local home="$tmp_root/$name"
  mkdir -p "$home/.claude"
  printf '{"permissions":{}}\n' > "$home/.claude/settings.json"

  local out rc
  out="$(HOME="$home" bash "$REPO_ROOT/scripts/install-hooks.sh" --platform xtreme 2>&1)" && rc=0 || rc=$?
  if [[ $rc -ne 0 ]] && [[ "$out" == *"platform"* ]]; then
    pass "$name"
  else
    fail "$name" "expected non-zero exit and 'platform' in stderr; got rc=$rc, out=$out"
  fi
}

test_install_hooks_profile_invalid_value_rejected() {
  # Proves install-hooks.sh rejects an unknown profile value with exit 2
  # and a clear stderr message.
  local name="install-hooks-profile-invalid-value-rejected"
  should_run "$name" || return 0
  local home="$tmp_root/$name"
  mkdir -p "$home/.claude"
  printf '{"permissions":{}}\n' > "$home/.claude/settings.json"

  local out rc
  out="$(HOME="$home" bash "$REPO_ROOT/scripts/install-hooks.sh" --profile bogus 2>&1)" && rc=0 || rc=$?
  if [[ $rc -ne 0 ]] && [[ "$out" == *"profile"* ]] && [[ "$out" == *"minimal or full"* ]]; then
    pass "$name"
  else
    fail "$name" "expected non-zero exit and 'minimal or full' in stderr; got rc=$rc, out=$out"
  fi
}

test_install_hooks_jq_missing_prints_platform_hints() {
  # Proves install-hooks.sh exits non-zero with platform-aware install
  # hints (winget / brew / apt / etc.) when jq is missing on PATH.
  # Stub PATH must contain the small set of utilities the script uses
  # before its jq check (cd / dirname / uname / command / cat etc.); we
  # symlink them from the live PATH into stub_bin, excluding jq.
  local name="install-hooks-jq-missing-prints-platform-hints"
  should_run "$name" || return 0
  # The artificial stub PATH (only a few coreutils, no jq) prevents install-hooks.sh
  # from resolving its own SCRIPT_DIR on MSYS (readlink/realpath absent), so it fails
  # before reaching the jq check this test asserts. The jq-hint path is POSIX-CI-covered.
  if _ti_skip_win "$name" "stub PATH breaks MSYS SCRIPT_DIR resolution before the jq check"; then return 0; fi
  local home="$tmp_root/$name"
  mkdir -p "$home/.claude"
  printf '{"permissions":{}}\n' > "$home/.claude/settings.json"

  local stub_bin="$home/.stub-bin"
  mkdir -p "$stub_bin"
  local util
  for util in dirname uname cat sed awk grep cut tr basename; do
    local src
    src="$(command -v "$util" 2>/dev/null)" || continue
    ln -sf "$src" "$stub_bin/$util"
  done
  # Deliberately do NOT symlink jq into stub_bin.

  local out rc
  out="$(HOME="$home" PATH="$stub_bin" /bin/bash "$REPO_ROOT/scripts/install-hooks.sh" 2>&1)" && rc=0 || rc=$?
  if [[ $rc -ne 0 ]] \
    && [[ "$out" == *"jq is required"* ]] \
    && [[ "$out" == *"apt install jq"* ]] \
    && [[ "$out" == *"brew install jq"* ]] \
    && [[ "$out" == *"winget install"* ]]; then
    pass "$name"
  else
    fail "$name" "expected non-zero exit + jq install hints for apt/brew/winget; got rc=$rc, out=$out"
  fi
}

test_install_sh_wires_hooks_no_settings() {
  # First-time install with no pre-existing settings.json — install.sh must
  # create a minimal settings.json and wire all hooks before the Write-enabled
  # codex-executor agent is accessible.
  local name="install-sh-wires-hooks-no-settings"
  should_run "$name" || return 0
  if _ti_skip_win "$name" "asserts codex guards wired; Windows downgrades --profile full to minimal"; then return 0; fi
  local home="$tmp_root/$name"
  mkdir -p "$home/.claude"
  # Deliberately no settings.json

  HOME="$home" \
    CLAUDE_CONFIG_TEST_INSTALL_RUNNING=1 \
    CLAUDE_CONFIG_TEST_PREFLIGHT_HOME="$REAL_HOME" \
    bash "$REPO_ROOT/install.sh" --profile full > /dev/null 2>&1

  if [[ ! -f "$home/.claude/settings.json" ]]; then
    fail "$name" "settings.json was not created during first-time install"
    return
  fi
  assert_file_contains "$name" "$home/.claude/settings.json" "hook-pm-write-guard.sh" || return
  assert_file_contains "$name" "$home/.claude/settings.json" "hook-codex-bash-guard.sh" || return
  assert_file_contains "$name" "$home/.claude/settings.json" "hook-codex-write-guard.sh" || return
  assert_file_contains "$name" "$home/.claude/settings.json" "hook-tool-trace.sh" || return
  assert_file_contains "$name" "$home/.claude/settings.json" "hook-log-claude-usage.sh" || return
  assert_file_contains "$name" "$home/.claude/settings.json" "hook-routing-log.sh" || return
  assert_file_contains "$name" "$home/.claude/settings.json" "hook-inject-memory.sh" || return
  assert_file_contains "$name" "$home/.claude/settings.json" "hook-save-rate-limits.sh" || return
  pass "$name"
}

test_hooks_install_uninstall_lifecycle() {
  local name="hooks-install-uninstall-lifecycle"
  should_run "$name" || return 0
  if _ti_skip_win "$name" "asserts codex guards wired by --profile full; Windows downgrades to minimal"; then return 0; fi
  local home="$tmp_root/$name"
  mkdir -p "$home/.claude"
  printf '{"permissions":{}}\n' > "$home/.claude/settings.json"

  HOME="$home" bash "$REPO_ROOT/scripts/install-hooks.sh" --profile full > /dev/null
  assert_file_contains "$name" "$home/.claude/settings.json" "hook-pm-write-guard.sh" || return
  assert_file_contains "$name" "$home/.claude/settings.json" "hook-codex-bash-guard.sh" || return
  assert_file_contains "$name" "$home/.claude/settings.json" "hook-codex-write-guard.sh" || return
  assert_file_contains "$name" "$home/.claude/settings.json" "hook-tool-trace.sh" || return
  assert_file_contains "$name" "$home/.claude/settings.json" "hook-log-claude-usage.sh" || return
  assert_file_contains "$name" "$home/.claude/settings.json" "hook-routing-log.sh" || return
  assert_file_contains "$name" "$home/.claude/settings.json" "hook-inject-memory.sh" || return
  assert_file_contains "$name" "$home/.claude/settings.json" "hook-save-rate-limits.sh" || return

  HOME="$home" bash "$REPO_ROOT/scripts/uninstall-hooks.sh" > /dev/null
  assert_not_contains "$name" "$home/.claude/settings.json" "hook-pm-write-guard.sh" || return
  assert_not_contains "$name" "$home/.claude/settings.json" "hook-codex-bash-guard.sh" || return
  assert_not_contains "$name" "$home/.claude/settings.json" "hook-codex-write-guard.sh" || return
  assert_not_contains "$name" "$home/.claude/settings.json" "hook-tool-trace.sh" || return
  assert_not_contains "$name" "$home/.claude/settings.json" "hook-log-claude-usage.sh" || return
  assert_not_contains "$name" "$home/.claude/settings.json" "hook-routing-log.sh" || return
  assert_not_contains "$name" "$home/.claude/settings.json" "hook-inject-memory.sh" || return
  assert_not_contains "$name" "$home/.claude/settings.json" "hook-save-rate-limits.sh" || return
  if jq -e 'has("statusLine")' "$home/.claude/settings.json" >/dev/null; then
    fail "$name" "statusLine should be deleted when no chain target exists"
    return
  fi

  pass "$name"
}

test_uninstall_hooks_removes_unlisted_hooks() {
  # Verifies that uninstall-hooks.sh removes hooks that were NOT in the old
  # hardcoded removal list (hook-tool-trace, hook-routing-log under PostToolUse).
  #
  # Steps:
  #   1. Write settings.json with tool-trace (PreToolUse) and routing-log (PostToolUse).
  #   2. Run uninstall-hooks.sh.
  #   3. Assert both hooks are gone and no hooks block remains.
  local name="uninstall-hooks-removes-unlisted-hooks"
  should_run "$name" || return 0
  local home="$tmp_root/$name"
  mkdir -p "$home/.claude"
  local _tt_cmd _rl_cmd
  _tt_cmd="$(_ti_hook_cmd_path "$REPO_ROOT/scripts/hook-tool-trace.sh")"
  _rl_cmd="$(_ti_hook_cmd_path "$REPO_ROOT/scripts/hook-routing-log.sh")"
  cat > "$home/.claude/settings.json" <<JSON
{
  "hooks": {
    "PreToolUse": [
      {"matcher": "*", "hooks": [{"type": "command", "command": "$_tt_cmd"}]}
    ],
    "PostToolUse": [
      {"hooks": [{"type": "command", "command": "$_rl_cmd"}]}
    ]
  }
}
JSON

  HOME="$home" bash "$REPO_ROOT/scripts/uninstall-hooks.sh" > /dev/null

  assert_not_contains "$name" "$home/.claude/settings.json" "hook-tool-trace.sh" || return
  assert_not_contains "$name" "$home/.claude/settings.json" "hook-routing-log.sh" || return
  if jq -e 'has("hooks")' "$home/.claude/settings.json" >/dev/null 2>&1; then
    fail "$name" "hooks block should be absent after full removal"
    return
  fi
  pass "$name"
}

test_install_hooks_updates_stale_paths_after_rename() {
  # Verifies that install-hooks.sh updates stale full-paths (e.g. from a repo
  # rename claude-config -> pm-dispatch) without creating duplicate entries.
  #
  # Steps:
  #   1. Create settings.json pre-populated with hooks pointing at /fake/old-repo/scripts/
  #   2. Run install-hooks.sh (current repo_root)
  #   3. Assert each hook appears exactly once and with the current path
  local name="install-hooks-updates-stale-paths-after-rename"
  should_run "$name" || return 0
  if _ti_skip_win "$name" "iterates codex guards (count==1); Windows downgrades them out of the full profile"; then return 0; fi
  local home="$tmp_root/$name"
  mkdir -p "$home/.claude"

  # Simulate settings.json left over from old repo path
  cat > "$home/.claude/settings.json" <<'JSON'
{
  "permissions": {},
  "hooks": {
    "PreToolUse": [
      {"matcher": "Edit|Write", "hooks": [{"type": "command", "command": "/fake/old-repo/scripts/hook-pm-write-guard.sh"}]},
      {"matcher": "Edit|Write", "hooks": [{"type": "command", "command": "/fake/old-repo/scripts/hook-codex-write-guard.sh"}]},
      {"matcher": "Bash",       "hooks": [{"type": "command", "command": "/fake/old-repo/scripts/hook-codex-bash-guard.sh"}]}
    ],
    "Stop": [
      {"hooks": [{"type": "command", "command": "/fake/old-repo/scripts/hook-log-claude-usage.sh"}]},
      {"hooks": [{"type": "command", "command": "/fake/old-repo/scripts/hook-session-summary.sh"}]}
    ],
    "UserPromptSubmit": [
      {"hooks": [{"type": "command", "command": "/fake/old-repo/scripts/hook-inject-memory.sh"}]}
    ]
  },
  "statusLine": {"type": "command", "command": "/fake/old-repo/scripts/hook-save-rate-limits.sh"}
}
JSON

  HOME="$home" bash "$REPO_ROOT/scripts/install-hooks.sh" > /dev/null

  # Each hook basename must appear exactly once (no duplicates)
  local settings="$home/.claude/settings.json"
  for hook in hook-pm-write-guard.sh hook-codex-write-guard.sh hook-codex-bash-guard.sh \
              hook-log-claude-usage.sh hook-session-summary.sh \
              hook-inject-memory.sh hook-save-rate-limits.sh; do
    local count
    count=$(grep -o "$hook" "$settings" | wc -l | tr -d ' ')
    if [[ "$count" -ne 1 ]]; then
      fail "$name" "$hook appears $count times in settings.json (want 1)"
      return
    fi
  done

  # Old path must be gone; current repo path must be present
  if grep -q "/fake/old-repo/" "$settings"; then
    fail "$name" "stale /fake/old-repo/ path still present after re-install"
    return
  fi
  assert_file_contains "$name" "$settings" "$REPO_ROOT/scripts/hook-pm-write-guard.sh" || return

  pass "$name"
}

test_install_hooks_preserves_unrelated_same_basename_hook() {
  # Verifies that install-hooks.sh does NOT overwrite hooks from unrelated tools
  # that share a managed hook basename but live at a non-standard path (parent
  # directory is not "scripts/"). Such entries must be preserved unchanged.
  #
  # Steps:
  #   1. Create settings.json with an unrelated Stop hook at /some/tool/hook-log-claude-usage.sh
  #      (basename matches managed hook; parent dir is "tool", not "scripts")
  #   2. Run install-hooks.sh
  #   3. Assert the unrelated hook is still present at its original path (not overwritten)
  #   4. Assert our managed hook was appended as a separate entry (not collapsed into the unrelated one)
  local name="install-hooks-preserves-unrelated-same-basename-hook"
  should_run "$name" || return 0
  local home="$tmp_root/$name"
  mkdir -p "$home/.claude"

  local unrelated_path="/some/unrelated/tool/hook-log-claude-usage.sh"

  cat > "$home/.claude/settings.json" <<JSON
{
  "permissions": {},
  "hooks": {
    "Stop": [
      {"hooks": [{"type": "command", "command": "$unrelated_path"}]}
    ]
  }
}
JSON

  HOME="$home" bash "$REPO_ROOT/scripts/install-hooks.sh" > /dev/null

  local settings="$home/.claude/settings.json"

  # Unrelated hook must still be present at original path
  assert_file_contains "$name" "$settings" "$unrelated_path" || return

  # Our managed hook must also be present (appended, not merged)
  assert_file_contains "$name" "$settings" "hook-log-claude-usage.sh" || return

  # Count occurrences of the basename — must be exactly 2
  # (unrelated path + our managed path)
  local count
  count=$(grep -o "hook-log-claude-usage.sh" "$settings" | wc -l | tr -d ' ')
  if [[ "$count" -ne 2 ]]; then
    fail "$name" "hook-log-claude-usage.sh appears $count times (want 2: unrelated + managed)"
    return
  fi

  pass "$name"
}

test_install_hooks_uninstall_stale_paths_after_rename() {
  # Verifies the rename lifecycle: install-hooks.sh first refreshes stale
  # managed hook paths, then uninstall-hooks.sh removes the refreshed repo-local
  # hooks by repo-root prefix.
  #
  # Steps:
  #   1. Create settings.json with managed hooks at /fake/old-repo/scripts/
  #   2. Run install-hooks.sh to refresh paths to the current repo_root
  #   3. Run uninstall-hooks.sh
  #   4. Assert all managed hook basenames are gone from settings.json
  local name="install-hooks-uninstall-stale-paths-after-rename"
  should_run "$name" || return 0
  if _ti_skip_win "$name" "iterates codex guards; Windows downgrades them out of the full profile"; then return 0; fi
  local home="$tmp_root/$name"
  mkdir -p "$home/.claude"

  cat > "$home/.claude/settings.json" <<'JSON'
{
  "permissions": {},
  "hooks": {
    "PreToolUse": [
      {"matcher": "Edit|Write", "hooks": [{"type": "command", "command": "/fake/old-repo/scripts/hook-pm-write-guard.sh"}]},
      {"matcher": "Edit|Write", "hooks": [{"type": "command", "command": "/fake/old-repo/scripts/hook-codex-write-guard.sh"}]},
      {"matcher": "Bash",       "hooks": [{"type": "command", "command": "/fake/old-repo/scripts/hook-codex-bash-guard.sh"}]}
    ],
    "Stop": [
      {"hooks": [{"type": "command", "command": "/fake/old-repo/scripts/hook-log-claude-usage.sh"}]},
      {"hooks": [{"type": "command", "command": "/fake/old-repo/scripts/hook-session-summary.sh"}]}
    ],
    "UserPromptSubmit": [
      {"hooks": [{"type": "command", "command": "/fake/old-repo/scripts/hook-inject-memory.sh"}]}
    ]
  },
  "statusLine": {"type": "command", "command": "/fake/old-repo/scripts/hook-save-rate-limits.sh"}
}
JSON

  HOME="$home" bash "$REPO_ROOT/scripts/install-hooks.sh" --profile full > /dev/null
  if grep -q "/fake/old-repo/" "$home/.claude/settings.json"; then
    fail "$name" "stale /fake/old-repo/ path still present after re-install"
    return
  fi

  HOME="$home" bash "$REPO_ROOT/scripts/uninstall-hooks.sh" > /dev/null

  local settings="$home/.claude/settings.json"

  # All managed hook basenames must be gone
  for hook in hook-pm-write-guard.sh hook-codex-write-guard.sh hook-codex-bash-guard.sh \
              hook-tool-trace.sh hook-log-claude-usage.sh hook-session-summary.sh \
              hook-routing-log.sh \
              hook-inject-memory.sh hook-save-rate-limits.sh; do
    if grep -q "$hook" "$settings"; then
      fail "$name" "$hook still present in settings.json after uninstall of stale paths"
      return
    fi
  done

  # No /fake/old-repo/ paths should remain
  if grep -q "/fake/old-repo/" "$settings"; then
    fail "$name" "stale /fake/old-repo/ path still present after uninstall"
    return
  fi

  pass "$name"
}

test_userpromptsubmit_install_wires_hook() {
  # Verifies install-hooks.sh wires hook-inject-memory.sh into UserPromptSubmit.
  # Steps:
  #   1. Create a sandbox settings.json with no hooks
  #   2. Run install-hooks.sh directly
  #   3. Assert UserPromptSubmit exists and contains the memory injection hook path
  local name="userpromptsubmit-install-wires-hook"
  should_run "$name" || return 0
  local home="$tmp_root/$name"
  # install-hooks writes the native path form (C:/... on Windows); match it.
  local inject
  inject="$(_ti_hook_cmd_path "$REPO_ROOT/scripts/hook-inject-memory.sh")"
  mkdir -p "$home/.claude"
  printf '{"permissions":{}}\n' > "$home/.claude/settings.json"

  HOME="$home" bash "$REPO_ROOT/scripts/install-hooks.sh" > /dev/null

  assert_file_contains "$name" "$home/.claude/settings.json" "UserPromptSubmit" || return
  assert_file_contains "$name" "$home/.claude/settings.json" "$inject" || return
  if ! jq -e --arg inject "$inject" \
    '.hooks.UserPromptSubmit[]? | (.hooks // [])[]? | select(.command == $inject)' \
    "$home/.claude/settings.json" >/dev/null; then
    fail "$name" "UserPromptSubmit hook command not found"
    return
  fi
  pass "$name"
}

test_userpromptsubmit_uninstall_removes_hook() {
  # Verifies uninstall-hooks.sh removes the managed UserPromptSubmit hook cleanly.
  # Steps:
  #   1. Create a sandbox settings.json, then run install-hooks.sh
  #   2. Run uninstall-hooks.sh
  #   3. Assert hook-inject-memory.sh and the UserPromptSubmit key are gone
  local name="userpromptsubmit-uninstall-removes-hook"
  should_run "$name" || return 0
  local home="$tmp_root/$name"
  mkdir -p "$home/.claude"
  printf '{"permissions":{}}\n' > "$home/.claude/settings.json"

  HOME="$home" bash "$REPO_ROOT/scripts/install-hooks.sh" > /dev/null
  HOME="$home" bash "$REPO_ROOT/scripts/uninstall-hooks.sh" > /dev/null

  assert_not_contains "$name" "$home/.claude/settings.json" "hook-inject-memory.sh" || return
  if ! jq -e '((.hooks // {}) | has("UserPromptSubmit") | not) or ((.hooks.UserPromptSubmit // []) | length == 0)' \
    "$home/.claude/settings.json" >/dev/null; then
    fail "$name" "UserPromptSubmit should be absent or empty"
    return
  fi
  pass "$name"
}

test_userpromptsubmit_install_idempotent() {
  # Verifies repeated install-hooks.sh runs do not duplicate UserPromptSubmit hooks.
  # Steps:
  #   1. Create a sandbox settings.json with no hooks
  #   2. Run install-hooks.sh twice
  #   3. Assert exactly one hook-inject-memory.sh command is present
  local name="userpromptsubmit-install-idempotent"
  should_run "$name" || return 0
  local home="$tmp_root/$name"
  local inject
  inject="$(_ti_hook_cmd_path "$REPO_ROOT/scripts/hook-inject-memory.sh")"
  local count
  mkdir -p "$home/.claude"
  printf '{"permissions":{}}\n' > "$home/.claude/settings.json"

  HOME="$home" bash "$REPO_ROOT/scripts/install-hooks.sh" > /dev/null
  HOME="$home" bash "$REPO_ROOT/scripts/install-hooks.sh" > /dev/null

  count="$(jq --arg inject "$inject" \
    '[.hooks.UserPromptSubmit[]? | (.hooks // [])[]? | select(.command == $inject)] | length' \
    "$home/.claude/settings.json")"
  if [[ "$count" != "1" ]]; then
    fail "$name" "expected one UserPromptSubmit memory hook, got $count"
    return
  fi
  pass "$name"
}

test_userpromptsubmit_uninstall_preserves_unrelated() {
  # Verifies uninstall-hooks.sh removes only the managed UserPromptSubmit hook.
  # Steps:
  #   1. Create settings.json with an unrelated UserPromptSubmit hook
  #   2. Run install-hooks.sh, then uninstall-hooks.sh
  #   3. Assert the unrelated hook remains and hook-inject-memory.sh is gone
  local name="userpromptsubmit-uninstall-preserves-unrelated"
  should_run "$name" || return 0
  local home="$tmp_root/$name"
  local unrelated="/home/testuser/project/custom-userpromptsubmit.sh"
  mkdir -p "$home/.claude"
  printf '{"permissions":{},"hooks":{"UserPromptSubmit":[{"hooks":[{"type":"command","command":"%s"}]}]}}\n' \
    "$unrelated" > "$home/.claude/settings.json"

  HOME="$home" bash "$REPO_ROOT/scripts/install-hooks.sh" > /dev/null
  HOME="$home" bash "$REPO_ROOT/scripts/uninstall-hooks.sh" > /dev/null

  assert_file_contains "$name" "$home/.claude/settings.json" "$unrelated" || return
  assert_not_contains "$name" "$home/.claude/settings.json" "hook-inject-memory.sh" || return
  pass "$name"
}

test_stop_hook_migration() {
  local name="hooks-stop-migration"
  should_run "$name" || return 0
  local home="$tmp_root/$name"
  mkdir -p "$home/.claude"
  # Write the stale entry in the same path form install-hooks matches against
  # (native C:/... on Windows) so migration recognizes and rewrites it.
  local old_stop
  old_stop="$(_ti_hook_cmd_path "$REPO_ROOT/hooks/hook-log-claude-usage.sh")"
  printf '{"permissions":{},"hooks":{"Stop":[{"hooks":[{"type":"command","command":"%s"}]}]}}\n' \
    "$old_stop" > "$home/.claude/settings.json"

  HOME="$home" bash "$REPO_ROOT/scripts/install-hooks.sh" > /dev/null
  assert_not_contains "$name" "$home/.claude/settings.json" \
    "hooks/hook-log-claude-usage.sh" || return
  assert_file_contains "$name" "$home/.claude/settings.json" \
    "scripts/hook-log-claude-usage.sh" || return
  pass "$name"
}

test_stop_hook_preservation() {
  local name="hooks-stop-preservation"
  should_run "$name" || return 0
  local home="$tmp_root/$name"
  mkdir -p "$home/.claude"
  # Unrelated hook at a completely different path.
  local unrelated="/home/testuser/myproject/custom-stop-hook.sh"
  printf '{"permissions":{},"hooks":{"Stop":[{"hooks":[{"type":"command","command":"%s"}]}]}}\n' \
    "$unrelated" > "$home/.claude/settings.json"

  # After install: unrelated hook preserved, managed hook added
  HOME="$home" bash "$REPO_ROOT/scripts/install-hooks.sh" > /dev/null
  assert_file_contains "$name" "$home/.claude/settings.json" "$unrelated" || return
  assert_file_contains "$name" "$home/.claude/settings.json" "scripts/hook-log-claude-usage.sh" || return

  # After uninstall: managed hook removed, unrelated hook still present
  HOME="$home" bash "$REPO_ROOT/scripts/uninstall-hooks.sh" > /dev/null
  assert_not_contains "$name" "$home/.claude/settings.json" "scripts/hook-log-claude-usage.sh" || return
  assert_file_contains "$name" "$home/.claude/settings.json" "$unrelated" || return
  pass "$name"
}

test_statusline_install_chains_previous() {
  # Verifies that when a previous statusLine.command exists, install saves it to
  # statusline-chain.conf and replaces it with hook-save-rate-limits.sh; a second
  # install run is idempotent and preserves the chain conf.
  # Steps:
  #   1. Write settings.json with a bare-path statusLine.command
  #   2. Run install; assert statusLine.command is now hook-save-rate-limits.sh
  #   3. Assert statusline-chain.conf contains the previous command path
  #   4. Run install again; assert "already wired" and chain conf unchanged
  local name="statusline-install-chains-previous"
  should_run "$name" || return 0
  local home="$tmp_root/$name"
  local previous="$tmp_root/$name-prev-statusline.sh"
  local out="$tmp_root/$name-second-install.out"
  mkdir -p "$home/.claude"
  printf '#!/usr/bin/env bash\ncat >/dev/null\n' > "$previous"
  chmod +x "$previous"
  printf '{"permissions":{},"statusLine":{"type":"command","command":"%s"}}\n' \
    "$previous" > "$home/.claude/settings.json"

  HOME="$home" bash "$REPO_ROOT/scripts/install-hooks.sh" > /dev/null
  local got
  got="$(jq -r '.statusLine.command // empty' "$home/.claude/settings.json")"
  if [[ "$got" != "$(_ti_hook_cmd_path "$REPO_ROOT/scripts/hook-save-rate-limits.sh")" ]]; then
    fail "$name" "statusLine.command was $got"
    return
  fi
  assert_file_content "$name" "$home/.claude/statusline-chain.conf" "$previous" || return

  HOME="$home" bash "$REPO_ROOT/scripts/install-hooks.sh" > "$out"
  assert_file_contains "$name" "$out" "already wired, nothing to do" || return
  assert_file_content "$name" "$home/.claude/statusline-chain.conf" "$previous" || return
  pass "$name"
}

test_statusline_install_preserves_existing_chain() {
  # Verifies that installing over another live statusLine hook keeps both that
  # hook and an already chained display command.
  # Steps:
  #   1. Write settings.json with an existing same-basename hook from another tool
  #   2. Write statusline-chain.conf with an existing display command
  #   3. Run install
  #   4. Assert statusline-chain.conf keeps both commands in order
  local name="statusline-install-preserves-existing-chain"
  should_run "$name" || return 0
  local home="$tmp_root/$name"
  local other_dir="$tmp_root/$name-other/scripts"
  local other_hook="$other_dir/hook-save-rate-limits.sh"
  local display_cmd="bash /home/screenleon/.claude/abtop-statusline.sh"
  mkdir -p "$home/.claude" "$other_dir"
  printf '#!/usr/bin/env bash\ncat >/dev/null\n' > "$other_hook"
  chmod +x "$other_hook"
  printf '{"permissions":{},"statusLine":{"type":"command","command":"%s"}}\n' \
    "$other_hook" > "$home/.claude/settings.json"
  printf '%s\n' "$display_cmd" > "$home/.claude/statusline-chain.conf"

  HOME="$home" bash "$REPO_ROOT/scripts/install-hooks.sh" > /dev/null
  local got expected
  got="$(cat "$home/.claude/statusline-chain.conf")"
  expected="$(printf '%s\n%s' "$other_hook" "$display_cmd")"
  if [[ "$got" != "$expected" ]]; then
    fail "$name" "statusline-chain.conf was $got"
    return
  fi
  pass "$name"
}

test_statusline_install_chains_previous_with_args() {
  # Verifies that a statusLine.command containing arguments (e.g. "/path/cmd --flag")
  # is stored verbatim in statusline-chain.conf so bash -c can invoke it correctly.
  # Steps:
  #   1. Write settings.json with a statusLine.command that includes a flag argument
  #   2. Run install; assert statusLine.command is replaced with hook-save-rate-limits.sh
  #   3. Assert statusline-chain.conf contains the full original command string with args
  local name="statusline-install-chains-previous-with-args"
  should_run "$name" || return 0
  local home="$tmp_root/$name"
  local previous="$tmp_root/$name-prev-statusline.sh"
  mkdir -p "$home/.claude"
  printf '#!/usr/bin/env bash\ncat >/dev/null\n' > "$previous"
  chmod +x "$previous"
  # Command string with arguments — the full value must be preserved in chain conf.
  local previous_with_args="$previous --some-flag"
  printf '{"permissions":{},"statusLine":{"type":"command","command":"%s"}}\n' \
    "$previous_with_args" > "$home/.claude/settings.json"

  HOME="$home" bash "$REPO_ROOT/scripts/install-hooks.sh" > /dev/null
  local got
  got="$(jq -r '.statusLine.command // empty' "$home/.claude/settings.json")"
  if [[ "$got" != "$(_ti_hook_cmd_path "$REPO_ROOT/scripts/hook-save-rate-limits.sh")" ]]; then
    fail "$name" "statusLine.command was $got"
    return
  fi
  assert_file_content "$name" "$home/.claude/statusline-chain.conf" "$previous_with_args" || return
  pass "$name"
}

test_statusline_uninstall_restores() {
  # Verifies that uninstall restores the previous statusLine.command from
  # statusline-chain.conf and removes the chain conf file.
  # Steps:
  #   1. Write settings.json with a previous statusLine.command and run install
  #   2. Run uninstall
  #   3. Assert statusLine.command is restored to the original value
  #   4. Assert statusline-chain.conf no longer exists
  local name="statusline-uninstall-restores"
  should_run "$name" || return 0
  local home="$tmp_root/$name"
  local previous="$tmp_root/$name-prev-statusline.sh"
  mkdir -p "$home/.claude"
  printf '#!/usr/bin/env bash\ncat >/dev/null\n' > "$previous"
  chmod +x "$previous"
  printf '{"permissions":{},"statusLine":{"type":"command","command":"%s"}}\n' \
    "$previous" > "$home/.claude/settings.json"

  HOME="$home" bash "$REPO_ROOT/scripts/install-hooks.sh" > /dev/null
  HOME="$home" bash "$REPO_ROOT/scripts/uninstall-hooks.sh" > /dev/null
  local got
  got="$(jq -r '.statusLine.command // empty' "$home/.claude/settings.json")"
  if [[ "$got" != "$(_ti_hook_cmd_path "$previous")" ]]; then
    fail "$name" "statusLine.command was $got"
    return
  fi
  if [[ -f "$home/.claude/statusline-chain.conf" ]]; then
    fail "$name" "statusline-chain.conf should be deleted"
    return
  fi
  pass "$name"
}

test_session_stop_install_wires_hook() {
  # Verifies install-hooks.sh wires hook-session-summary.sh into the Stop event.
  # Steps:
  #   1. Create a sandbox settings.json with no hooks
  #   2. Run install-hooks.sh
  #   3. Assert Stop exists and contains the session summary hook path
  local name="session-stop-install-wires-hook"
  should_run "$name" || return 0
  local home="$tmp_root/$name"
  local session
  session="$(_ti_hook_cmd_path "$REPO_ROOT/scripts/hook-session-summary.sh")"
  mkdir -p "$home/.claude"
  printf '{"permissions":{}}\n' > "$home/.claude/settings.json"

  HOME="$home" bash "$REPO_ROOT/scripts/install-hooks.sh" > /dev/null

  assert_file_contains "$name" "$home/.claude/settings.json" "$session" || return
  if ! jq -e --arg session "$session" \
    '.hooks.Stop[]? | (.hooks // [])[]? | select(.command == $session)' \
    "$home/.claude/settings.json" >/dev/null; then
    fail "$name" "Stop session-summary hook command not found"
    return
  fi
  pass "$name"
}

test_session_stop_uninstall_removes_hook() {
  # Verifies uninstall-hooks.sh removes the managed session-summary Stop hook.
  # Steps:
  #   1. Create a sandbox settings.json, run install-hooks.sh
  #   2. Run uninstall-hooks.sh
  #   3. Assert hook-session-summary.sh is gone from settings.json
  local name="session-stop-uninstall-removes-hook"
  should_run "$name" || return 0
  local home="$tmp_root/$name"
  local session
  session="$(_ti_hook_cmd_path "$REPO_ROOT/scripts/hook-session-summary.sh")"
  mkdir -p "$home/.claude"
  printf '{"permissions":{}}\n' > "$home/.claude/settings.json"

  HOME="$home" bash "$REPO_ROOT/scripts/install-hooks.sh" > /dev/null
  HOME="$home" bash "$REPO_ROOT/scripts/uninstall-hooks.sh" > /dev/null

  assert_not_contains "$name" "$home/.claude/settings.json" "hook-session-summary.sh" || return
  pass "$name"
}

test_session_stop_install_idempotent() {
  # Verifies repeated install-hooks.sh runs do not duplicate the session-summary hook.
  # Steps:
  #   1. Create a sandbox settings.json with no hooks
  #   2. Run install-hooks.sh twice
  #   3. Assert exactly one hook-session-summary.sh command is present
  local name="session-stop-install-idempotent"
  should_run "$name" || return 0
  local home="$tmp_root/$name"
  local session
  session="$(_ti_hook_cmd_path "$REPO_ROOT/scripts/hook-session-summary.sh")"
  local count
  mkdir -p "$home/.claude"
  printf '{"permissions":{}}\n' > "$home/.claude/settings.json"

  HOME="$home" bash "$REPO_ROOT/scripts/install-hooks.sh" > /dev/null
  HOME="$home" bash "$REPO_ROOT/scripts/install-hooks.sh" > /dev/null

  count="$(jq --arg session "$session" \
    '[.hooks.Stop[]? | (.hooks // [])[]? | select(.command == $session)] | length' \
    "$home/.claude/settings.json")"
  if [[ "$count" != "1" ]]; then
    fail "$name" "expected one Stop session-summary hook, got $count"
    return
  fi
  pass "$name"
}

test_session_stop_uninstall_preserves_stop() {
  # Verifies uninstall-hooks.sh removes only the managed session-summary hook,
  # leaving unrelated Stop hooks intact.
  # Steps:
  #   1. Create settings.json with an unrelated Stop hook
  #   2. Run install-hooks.sh, then uninstall-hooks.sh
  #   3. Assert the unrelated hook remains and hook-session-summary.sh is gone
  local name="session-stop-uninstall-preserves-stop"
  should_run "$name" || return 0
  local home="$tmp_root/$name"
  local unrelated="/home/testuser/project/custom-stop-hook.sh"
  mkdir -p "$home/.claude"
  printf '{"permissions":{},"hooks":{"Stop":[{"hooks":[{"type":"command","command":"%s"}]}]}}\n' \
    "$unrelated" > "$home/.claude/settings.json"

  HOME="$home" bash "$REPO_ROOT/scripts/install-hooks.sh" > /dev/null
  HOME="$home" bash "$REPO_ROOT/scripts/uninstall-hooks.sh" > /dev/null

  assert_file_contains "$name" "$home/.claude/settings.json" "$unrelated" || return
  assert_not_contains "$name" "$home/.claude/settings.json" "hook-session-summary.sh" || return
  pass "$name"
}

test_skip_preflight_skips_all_tests() {
  # Verifies that CLAUDE_CONFIG_TEST_INSTALL_RUNNING=1 causes install.sh to
  # skip all preflight test suites (no test output headers produced).
  # Steps:
  #   1. Create a sandbox settings.json
  #   2. Run install.sh with CLAUDE_CONFIG_TEST_INSTALL_RUNNING=1
  #   3. Assert output contains NO "==>" preflight section headers for any test suite
  local name="skip-preflight-skips-all-tests"
  should_run "$name" || return 0
  local home out
  home="$tmp_root/$name"
  mkdir -p "$home/.claude"
  printf '{"permissions":{}}\n' > "$home/.claude/settings.json"

  out=$(HOME="$home" CLAUDE_CONFIG_TEST_INSTALL_RUNNING=1 bash "$REPO_ROOT/install.sh" 2>&1)

  local ok=true
  for label in "test hooks" "test install" "test usage" "test pm" "test codex" \
               "test pr-gate" "test setup-project" "test patch-gitignore" \
               "lint agents" "lint scripts"; do
    if [[ "$out" == *"==> $label"* ]]; then
      ok=false
      printf '  FAIL  %s — unexpected preflight section: "==> %s"\n' "$name" "$label" >&2
    fi
  done

  $ok && pass "$name" || { FAIL=$((FAIL+1)); FAILED_CASES+=("$name"); }
}

test_default_install_skips_preflights() {
  # Verifies that ./install.sh without --verify skips all preflights by default
  # and prints the new opt-in hint message.
  # Steps:
  #   1. Create a sandbox settings.json
  #   2. Run install.sh --dry-run (no CLAUDE_CONFIG_TEST_INSTALL_RUNNING, no --verify)
  #   3. Assert output contains the skip hint message
  #   4. Assert output contains NO "==>" preflight section headers
  local name="default-install-skips-preflights"
  should_run "$name" || return 0
  local home out
  home="$tmp_root/$name"
  mkdir -p "$home/.claude"
  printf '{"permissions":{}}\n' > "$home/.claude/settings.json"

  out=$(env -u CLAUDE_CONFIG_TEST_INSTALL_RUNNING HOME="$home" \
    bash "$REPO_ROOT/install.sh" --dry-run 2>&1)

  local ok=true
  if [[ "$out" != *"preflight tests skipped"* ]]; then
    ok=false
    printf '  FAIL  %s — expected skip hint message not found in output\n' "$name" >&2
  fi
  for label in "test hooks" "test migrate routing log" "test install" "test usage" \
               "test pm" "test codex" "test pr-gate" "test setup-project" \
               "test patch-gitignore" "lint agents" "lint scripts"; do
    if [[ "$out" == *"==> $label"* ]]; then
      ok=false
      printf '  FAIL  %s — unexpected preflight section with default flags: "==> %s"\n' "$name" "$label" >&2
    fi
  done
  $ok && pass "$name" || { FAIL=$((FAIL+1)); FAILED_CASES+=("$name"); }
}

test_verify_flag_runs_preflights() {
  # Verifies that ./install.sh --verify delegates to the preflight runner.
  # A lightweight stub is generated from run-all-tests.sh --list and injected
  # via _PM_DISPATCH_PREFLIGHT_RUNNER so the real suites never execute — the
  # test stays fast and free of recursive suite invocation regardless of how
  # it is called (directly, from run-all-tests.sh, or within CI).
  local name="verify-flag-runs-preflights"
  should_run "$name" || return 0
  if _ti_skip_win "$name" "stub subprocess overhead is impractically slow on MSYS"; then return 0; fi

  local home stub suite_list suite_count out exit_code=0
  home="$tmp_root/$name"
  stub="$tmp_root/${name}-stub.sh"
  mkdir -p "$home/.claude"
  printf '{"permissions":{}}\n' > "$home/.claude/settings.json"

  # Generate a stub that echoes "PASS <suite>" for every suite in the canonical
  # list. When suites are added or removed from run-all-tests.sh the stub (and
  # the assertions below) update automatically with no manual maintenance.
  suite_list="$(bash "$REPO_ROOT/scripts/run-all-tests.sh" --list 2>/dev/null)"
  suite_count="$(printf '%s\n' "$suite_list" | grep -c . || true)"
  {
    printf '#!/usr/bin/env bash\n'
    while IFS= read -r _suite; do
      [[ -n "$_suite" ]] || continue
      printf 'echo "PASS %s"\n' "$_suite"
    done <<< "$suite_list"
    printf 'echo "%d passed, 0 failed, 0 skipped"\n' "$suite_count"
  } > "$stub"
  chmod +x "$stub"

  # Reset CLAUDE_CONFIG_TEST_INSTALL_RUNNING so install.sh does not hit its
  # own escape hatch — run-all-tests.sh sets it to 1 when invoking test-install,
  # which would suppress the --verify block we are trying to exercise.
  out=$(HOME="$home" CLAUDE_CONFIG_TEST_PREFLIGHT_HOME="$HOME" \
    CLAUDE_CONFIG_TEST_INSTALL_RUNNING=0 \
    _PM_DISPATCH_PREFLIGHT_RUNNER="$stub" \
    bash "$REPO_ROOT/install.sh" --verify --dry-run 2>&1) || exit_code=$?

  local ok=true
  if [[ $exit_code -ne 0 ]]; then
    ok=false
    printf '  FAIL  %s — install.sh --verify exited %d\n' "$name" "$exit_code" >&2
  fi
  if [[ "$out" != *"==> preflight tests"* ]]; then
    ok=false
    printf '  FAIL  %s — expected "==> preflight tests" header not found\n' "$name" >&2
  fi
  # Verify every suite name from --list flowed through install.sh's output.
  while IFS= read -r _suite; do
    [[ -n "$_suite" ]] || continue
    if [[ "$out" != *"$_suite"* ]]; then
      ok=false
      printf '  FAIL  %s — expected suite "%s" not found in preflight output\n' "$name" "$_suite" >&2
    fi
  done <<< "$suite_list"
  if [[ "$out" == *"preflight tests skipped"* ]]; then
    ok=false
    printf '  FAIL  %s — skip message should not appear when --verify is passed\n' "$name" >&2
  fi
  $ok && pass "$name" || { FAIL=$((FAIL+1)); FAILED_CASES+=("$name"); }
}

test_escape_hatch_overrides_verify() {
  # Verifies CLAUDE_CONFIG_TEST_INSTALL_RUNNING=1 takes precedence over --verify;
  # preflights must be skipped even when --verify is passed.
  local name="escape-hatch-overrides-verify"
  should_run "$name" || return 0
  local home out exit_code=0
  home="$tmp_root/$name"
  mkdir -p "$home/.claude"
  printf '{"permissions":{}}\n' > "$home/.claude/settings.json"

  out=$(CLAUDE_CONFIG_TEST_INSTALL_RUNNING=1 HOME="$home" \
    bash "$REPO_ROOT/install.sh" --verify --dry-run 2>&1) || exit_code=$?

  local ok=true
  if [[ $exit_code -ne 0 ]]; then
    ok=false
    printf '  FAIL  %s — install.sh exited %d unexpectedly\n' "$name" "$exit_code" >&2
  fi
  if [[ "$out" != *"preflight skipped: CLAUDE_CONFIG_TEST_INSTALL_RUNNING=1"* ]]; then
    ok=false
    printf '  FAIL  %s — escape hatch skip message not found\n' "$name" >&2
  fi
  for label in "lint agents" "lint scripts" "test hooks" "test migrate routing log" \
               "test install" "test usage weekly" "test usage tracker" "test pm scripts" \
               "test codex-dispatch" "test pr-gate" "test setup-project" \
               "test patch-gitignore"; do
    if [[ "$out" == *"==> $label"* ]]; then
      ok=false
      printf '  FAIL  %s — unexpected preflight section "==> %s" ran despite escape hatch\n' "$name" "$label" >&2
    fi
  done
  $ok && pass "$name" || { FAIL=$((FAIL+1)); FAILED_CASES+=("$name"); }
}

test_install_dir_junction_windows_fallback() {
  local name="install-dir-junction-windows-fallback"
  should_run "$name" || return 0
  local home fake_bin
  home="$tmp_root/$name"
  fake_bin="$tmp_root/${name}-bin"
  mkdir -p "$home/.claude" "$fake_bin"
  printf '{"permissions":{}}\n' > "$home/.claude/settings.json"
  # Fake powershell.exe that always fails — simulates Git Bash without
  # real PowerShell or an environment where New-Item Junction is blocked.
  printf '#!/bin/bash\nexit 1\n' > "$fake_bin/powershell.exe"
  chmod +x "$fake_bin/powershell.exe"
  local install_exit=0
  HOME="$home" PM_DISPATCH_PLATFORM=windows \
    CLAUDE_CONFIG_TEST_INSTALL_RUNNING=1 \
    CLAUDE_CONFIG_TEST_PREFLIGHT_HOME="$REAL_HOME" \
    PATH="$fake_bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin${_TI_JQ_DIR:+:$_TI_JQ_DIR}" \
    bash "$REPO_ROOT/install.sh" >/dev/null 2>&1 || install_exit=$?
  local ok=true
  if [[ $install_exit -ne 0 ]]; then
    ok=false
    printf '  FAIL  %s — install.sh exited %d unexpectedly\n' "$name" "$install_exit" >&2
  fi
  # Fallback must have run install_dir() per-file copy — at least one agent
  # file (symlink or copy) should appear directly in ~/.claude/agents/.
  local agent_count=0
  [[ -d "$home/.claude/agents" ]] && \
    agent_count=$(find "$home/.claude/agents" -maxdepth 1 -name "*.md" | wc -l)
  if [[ "$agent_count" -eq 0 ]]; then
    ok=false
    printf '  FAIL  %s — no agent files under ~/.claude/agents/ after junction fallback\n' "$name" >&2
  fi
  $ok && pass "$name" || { FAIL=$((FAIL+1)); FAILED_CASES+=("$name"); }
}

test_install_dir_junction_manifest_entry() {
  local name="install-dir-junction-manifest-entry"
  should_run "$name" || return 0
  local home fake_bin
  home="$tmp_root/$name"
  fake_bin="$tmp_root/${name}-bin"
  mkdir -p "$home/.claude" "$fake_bin"
  printf '{"permissions":{}}\n' > "$home/.claude/settings.json"
  # Fake powershell.exe: parses -Path from -Command, converts Win-format path
  # to Unix, then mkdir -p to simulate junction creation side effect.
  cat > "$fake_bin/powershell.exe" <<'PWSH'
#!/bin/bash
for arg in "$@"; do
  if [[ "$arg" == *"New-Item"* && "$arg" == *"Junction"* ]]; then
    if [[ "$arg" =~ -Path[[:space:]]\'([^\']+)\' ]]; then
      dst="${BASH_REMATCH[1]//\\/\/}"
      mkdir -p "$dst" 2>/dev/null || true
    fi
  fi
done
exit 0
PWSH
  chmod +x "$fake_bin/powershell.exe"
  local install_exit=0
  HOME="$home" PM_DISPATCH_PLATFORM=windows \
    CLAUDE_CONFIG_TEST_INSTALL_RUNNING=1 \
    CLAUDE_CONFIG_TEST_PREFLIGHT_HOME="$REAL_HOME" \
    PATH="$fake_bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin${_TI_JQ_DIR:+:$_TI_JQ_DIR}" \
    bash "$REPO_ROOT/install.sh" >/dev/null 2>&1 || install_exit=$?
  local manifest="$home/.claude/.pm-dispatch/install-manifest.json"
  local ok=true
  if [[ $install_exit -ne 0 ]]; then
    ok=false
    printf '  FAIL  %s — install.sh exited %d\n' "$name" "$install_exit" >&2
  fi
  if ! grep -q '"mode":"junction"' "$manifest" 2>/dev/null; then
    ok=false
    printf '  FAIL  %s — no mode=junction in manifest\n' "$name" >&2
  fi
  if [[ ! -d "$home/.claude/agents" ]]; then
    ok=false
    printf '  FAIL  %s — ~/.claude/agents directory not created by fake junction\n' "$name" >&2
  fi
  $ok && pass "$name" || { FAIL=$((FAIL+1)); FAILED_CASES+=("$name"); }
}

test_install_dir_junction_existing_real_dir() {
  local name="install-dir-junction-existing-real-dir"
  should_run "$name" || return 0
  local home fake_bin unrelated_agent
  home="$tmp_root/$name"
  fake_bin="$tmp_root/${name}-bin"
  unrelated_agent="$home/.claude/agents/third-party-agent.md"
  mkdir -p "$home/.claude/agents" "$fake_bin"
  printf '{"permissions":{}}\n' > "$home/.claude/settings.json"
  # Pre-create an unrelated agent file in ~/.claude/agents/ to simulate
  # a user who already has other agents installed.
  printf '# Third-party agent\n' > "$unrelated_agent"
  # Fake powershell.exe that succeeds — if install.sh incorrectly calls junction
  # on the pre-existing real directory, the unrelated file would be lost.
  printf '#!/bin/bash\nexit 0\n' > "$fake_bin/powershell.exe"
  chmod +x "$fake_bin/powershell.exe"
  local install_exit=0
  HOME="$home" PM_DISPATCH_PLATFORM=windows \
    CLAUDE_CONFIG_TEST_INSTALL_RUNNING=1 \
    CLAUDE_CONFIG_TEST_PREFLIGHT_HOME="$REAL_HOME" \
    PATH="$fake_bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin${_TI_JQ_DIR:+:$_TI_JQ_DIR}" \
    bash "$REPO_ROOT/install.sh" >/dev/null 2>&1 || install_exit=$?
  local ok=true
  if [[ $install_exit -ne 0 ]]; then
    ok=false
    printf '  FAIL  %s — install.sh exited %d\n' "$name" "$install_exit" >&2
  fi
  # The unrelated agent must still be present (install_dir fallback preserves it).
  if [[ ! -f "$unrelated_agent" ]]; then
    ok=false
    printf '  FAIL  %s — unrelated agent was deleted (junction replaced real dir)\n' "$name" >&2
  fi
  # pm-dispatch agents must also be installed (per-file fallback ran).
  local pm_agent_count=0
  [[ -d "$home/.claude/agents" ]] && \
    pm_agent_count=$(find "$home/.claude/agents" -maxdepth 1 -name "*.md" \
      ! -name "third-party-agent.md" | wc -l)
  if [[ "$pm_agent_count" -eq 0 ]]; then
    ok=false
    printf '  FAIL  %s — no pm-dispatch agent files installed despite fallback\n' "$name" >&2
  fi
  $ok && pass "$name" || { FAIL=$((FAIL+1)); FAILED_CASES+=("$name"); }
}

test_uninstall_junction_windows_remove() {
  local name="uninstall-junction-windows-remove"
  should_run "$name" || return 0
  local home managed src dst fake_bin
  home="$tmp_root/$name"
  managed="$home/.claude"
  src="$home/fake-pm-dispatch/agents"
  dst="$managed/agents"
  fake_bin="$tmp_root/${name}-bin"
  mkdir -p "$managed/.pm-dispatch" "$src" "$dst" "$fake_bin"
  # Fake powershell.exe that simulates Remove-Item by removing the directory.
  # On Linux, the win_dst path has backslashes; convert them back before rmdir.
  cat > "$fake_bin/powershell.exe" <<'PWSH'
#!/bin/bash
# Simulate [System.IO.Directory]::Delete via PM_DISPATCH_RM_DST env var.
# Convert Win-format backslashes back to Unix forward slashes, then rm.
if [[ -n "${PM_DISPATCH_RM_DST-}" ]]; then
  p="${PM_DISPATCH_RM_DST//\\/\/}"
  rm -rf "$p" 2>/dev/null || true
fi
exit 0
PWSH
  chmod +x "$fake_bin/powershell.exe"
  # Write a real-format manifest with mode=junction.
  printf '{"manifest_version":1,"installed_at":"2026-01-01T00:00:00Z","pm_dispatch_version":"test","entries":[\n{"src":"%s","dst":"%s","mode":"junction"}\n]}\n' \
    "$src" "$dst" > "$managed/.pm-dispatch/install-manifest.json"
  HOME="$home" PM_DISPATCH_PLATFORM=windows \
    PATH="$fake_bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
    bash "$REPO_ROOT/uninstall.sh" >/dev/null 2>&1 || true
  if [[ ! -d "$dst" ]]; then
    pass "$name"
  else
    printf '  FAIL  %s — junction dir %s still exists after Windows uninstall\n' "$name" "$dst" >&2
    FAIL=$((FAIL+1)); FAILED_CASES+=("$name")
  fi
}

test_uninstall_junction_mode_removes_dir() {
  local name="uninstall-junction-mode-removes-dir"
  should_run "$name" || return 0
  local home managed src dst
  home="$tmp_root/$name"
  managed="$home/.claude"
  src="$home/fake-pm-dispatch/agents"
  dst="$managed/agents"
  mkdir -p "$managed/.pm-dispatch" "$src" "$dst"
  # Write a manifest entry with mode=junction pointing to dst (which is a real dir here).
  printf '{"manifest_version":1,"installed_at":"2026-01-01T00:00:00Z","pm_dispatch_version":"test","entries":[\n{"src":"%s","dst":"%s","mode":"junction"}\n]}\n' \
    "$src" "$dst" > "$managed/.pm-dispatch/install-manifest.json"
  HOME="$home" bash "$REPO_ROOT/uninstall.sh" >/dev/null 2>&1 || true
  if [[ ! -d "$dst" ]]; then
    pass "$name"
  else
    printf '  FAIL  %s — junction dir %s still exists after uninstall\n' "$name" "$dst" >&2
    FAIL=$((FAIL+1)); FAILED_CASES+=("$name")
  fi
}

test_install_sh_wires_hooks
test_install_sh_profile_minimal_skips_codex_hooks
test_install_sh_profile_full_wires_codex_hooks
test_install_hooks_profile_downgrade_removes_codex
test_install_hooks_auto_detect_with_codex_wires_full
test_install_hooks_auto_detect_without_codex_wires_minimal
test_install_hooks_windows_profile_full_downgrades_to_minimal
test_install_hooks_windows_profile_minimal_silent
test_install_hooks_dry_run_does_not_modify
test_install_hooks_platform_linux_explicit
test_install_hooks_platform_invalid_value_rejected
test_install_hooks_profile_invalid_value_rejected
test_install_hooks_jq_missing_prints_platform_hints
test_install_sh_wires_hooks_no_settings
test_install_adds_dispatch_allowlist
test_install_dispatch_allowlist_idempotent
test_install_dispatch_allowlist_backup_timestamped
test_dispatch_allowlist_lib_parity
test_dispatch_allowlist_uninstall_removes_entries
test_dispatch_allowlist_uninstall_dryrun
test_hooks_install_uninstall_lifecycle
test_uninstall_hooks_removes_unlisted_hooks
test_install_hooks_updates_stale_paths_after_rename
test_install_hooks_preserves_unrelated_same_basename_hook
test_install_hooks_uninstall_stale_paths_after_rename
test_userpromptsubmit_install_wires_hook
test_userpromptsubmit_uninstall_removes_hook
test_userpromptsubmit_install_idempotent
test_userpromptsubmit_uninstall_preserves_unrelated
test_stop_hook_migration
test_stop_hook_preservation
test_session_stop_install_wires_hook
test_session_stop_uninstall_removes_hook
test_session_stop_install_idempotent
test_session_stop_uninstall_preserves_stop
test_statusline_install_chains_previous
test_statusline_install_preserves_existing_chain
test_statusline_install_chains_previous_with_args
test_statusline_uninstall_restores
test_legacy_pm_left_untouched
test_legacy_stale_symlinks_removed
test_install_sh_jq_missing_exits_early() {
  # Verifies install.sh exits 1 with platform-specific install hints when jq
  # is absent from PATH, without running preflight, manifest, or hook operations.
  # Steps:
  #   1. Build a stub PATH containing basic shell utilities but NOT jq
  #   2. Run install.sh under that PATH
  #   3. Assert exit code is 1
  #   4. Assert output contains "jq not found" and Linux/macOS/Windows install hints
  #   5. Assert no settings.json side effect was produced
  local name="install-sh-jq-missing-exits-early"
  should_run "$name" || return 0
  # Relies on an isolated stub PATH with only a handful of binaries. On Windows
  # MSYS executables can't run outside their full install (missing DLLs), so a
  # copied bash/coreutils stub fails to launch. The jq-missing hint path is
  # POSIX-CI-covered; skip here.
  if _ti_skip_win "$name" "isolated stub PATH can't host MSYS binaries (missing DLLs)"; then return 0; fi

  local stub_bin="$tmp_root/$name-stub"
  mkdir -p "$stub_bin"
  local util
  for util in env bash sh dirname pwd uname id; do
    local src; src="$(command -v "$util" 2>/dev/null)" || continue
    # Skip shell builtins (command -v returns the bare name, not a path) and
    # non-files — ln -s to a non-file target fails on MSYS. Fall back to copy
    # where real symlinks are unavailable.
    [[ -f "$src" ]] || continue
    ln -sf "$src" "$stub_bin/$util" 2>/dev/null || cp "$src" "$stub_bin/$util"
  done
  # Deliberately do NOT symlink jq into stub_bin.

  local home="$tmp_root/$name"
  mkdir -p "$home/.claude"

  local out rc=0
  out="$(HOME="$home" PATH="$stub_bin" bash "$REPO_ROOT/install.sh" 2>&1)" || rc=$?

  if [[ $rc -ne 1 ]]; then
    fail "$name" "expected exit 1 with missing jq, got rc=$rc; out=$out"
    return
  fi
  if [[ "$out" != *"jq not found"* ]]; then
    fail "$name" "missing 'jq not found' in output: $out"
    return
  fi
  if [[ "$out" != *"apt install jq"* ]]; then
    fail "$name" "missing Linux install hint; out=$out"
    return
  fi
  if [[ "$out" != *"brew install jq"* ]]; then
    fail "$name" "missing macOS install hint; out=$out"
    return
  fi
  if [[ "$out" != *"winget install jqlang.jq"* ]]; then
    fail "$name" "missing Windows install hint; out=$out"
    return
  fi
  if [[ -f "$home/.claude/settings.json" ]]; then
    fail "$name" "settings.json should not exist after jq-missing abort"
    return
  fi
  pass "$name"
}

test_install_sh_copy_fallback_banner() {
  # Verifies that _COPY_FALLBACK_COUNT increments when link_or_copy returns rc=1
  # and the summary banner appears at the end of a real (non-dry-run) install.
  # Steps:
  #   1. Run install.sh with FAKE_SYMLINK_UNSUPPORTED=1 to force copy fallback for all files
  #   2. Assert exit code is 0
  #   3. Assert stdout contains the "installed via copy fallback" banner with count > 0
  #   4. Assert stdout contains the "re-run install.sh after updates" reminder
  local name="install-sh-copy-fallback-banner"
  should_run "$name" || return 0

  local home="$tmp_root/$name"
  mkdir -p "$home/.claude"

  local out rc=0
  out="$(HOME="$home" \
    CLAUDE_CONFIG_TEST_INSTALL_RUNNING=1 \
    FAKE_SYMLINK_UNSUPPORTED=1 \
    bash "$REPO_ROOT/install.sh" --profile full 2>&1)" || rc=$?

  if [[ $rc -ne 0 ]]; then
    fail "$name" "install failed rc=$rc; out=$out"
    return
  fi
  if [[ "$out" != *"installed or refreshed via copy"* ]]; then
    fail "$name" "expected copy fallback banner; out=$out"
    return
  fi
  if [[ "$out" != *"Re-run install.sh after pulling"* ]]; then
    fail "$name" "expected re-run hint in banner; out=$out"
    return
  fi
  pass "$name"
}

test_install_sh_no_banner_dry_run() {
  # Verifies the copy fallback banner is suppressed when --dry-run is active.
  # In dry-run mode link_or_copy returns 0 before the FAKE_SYMLINK_UNSUPPORTED branch,
  # so _COPY_FALLBACK_COUNT stays at 0 and the DRY_RUN guard never prints the banner.
  # Steps:
  #   1. Run install.sh with FAKE_SYMLINK_UNSUPPORTED=1 and --dry-run
  #   2. Assert exit code is 0
  #   3. Assert stdout does NOT contain the "installed via copy fallback" banner
  local name="install-sh-no-banner-dry-run"
  should_run "$name" || return 0

  local home="$tmp_root/$name"
  mkdir -p "$home/.claude"

  local out rc=0
  out="$(HOME="$home" \
    CLAUDE_CONFIG_TEST_INSTALL_RUNNING=1 \
    FAKE_SYMLINK_UNSUPPORTED=1 \
    bash "$REPO_ROOT/install.sh" --profile full --dry-run 2>&1)" || rc=$?

  if [[ $rc -ne 0 ]]; then
    fail "$name" "dry-run install failed rc=$rc; out=$out"
    return
  fi
  if [[ "$out" == *"installed or refreshed via copy"* ]]; then
    fail "$name" "banner must NOT appear in dry-run mode; out=$out"
    return
  fi
  pass "$name"
}

test_filter_no_match_exits_nonzero() {
  # Verifies --filter with a pattern that matches no cases exits nonzero
  # and emits a diagnostic rather than silently reporting 0 passed.
  # Steps:
  #   1. Invoke test-install.sh --filter with a pattern known to match nothing
  #   2. Assert exit status is nonzero
  #   3. Assert output contains "no tests matched"
  local name="meta/filter-no-match-exits-nonzero"
  should_run "$name" || return 0
  local out status
  out=$(bash "$SCRIPT_DIR/test-install.sh" --filter "__no_such_case_xyz__" 2>&1) && status=$? || status=$?
  if [[ "$status" -ne 0 && "$out" == *"no tests matched"* ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$out"
  fi
}

test_skip_preflight_skips_all_tests
test_default_install_skips_preflights
test_verify_flag_runs_preflights
test_escape_hatch_overrides_verify
test_install_dir_junction_manifest_entry
test_install_dir_junction_windows_fallback
test_install_dir_junction_existing_real_dir
test_uninstall_junction_windows_remove
test_uninstall_junction_mode_removes_dir
test_install_sh_jq_missing_exits_early
test_install_sh_copy_fallback_banner
test_install_sh_no_banner_dry_run
test_filter_no_match_exits_nonzero
test_install_manifest_atomic

test_install_share_asset_installed() {
  # Verifies install.sh installs share/model-aliases.tsv to ~/.claude/share/
  # and records it in the install manifest (so uninstall can clean it up).
  #
  # Steps:
  #   1. Run install.sh in a temp HOME.
  #   2. Assert share/model-aliases.tsv exists at ~/.claude/share/.
  #   3. Assert model-aliases.tsv is referenced in the install manifest JSON.
  local name="install-share-asset-installed"
  should_run "$name" || return 0
  local home manifest
  home="$tmp_root/$name"
  mkdir -p "$home/.claude"
  set +e
  HOME="$home" \
    CLAUDE_CONFIG_TEST_INSTALL_RUNNING=1 \
    CLAUDE_CONFIG_TEST_PREFLIGHT_HOME="$REAL_HOME" \
    bash "$REPO_ROOT/install.sh" >/dev/null 2>&1
  local rc=$?
  set -e
  if [[ $rc -ne 0 ]]; then
    fail "$name" "install.sh exited $rc"
    return
  fi
  if [[ ! -e "$home/.claude/share/model-aliases.tsv" ]]; then
    fail "$name" "share/model-aliases.tsv not installed to ~/.claude/share/"
    return
  fi
  manifest="$home/.claude/.pm-dispatch/install-manifest.json"
  if ! grep -q "model-aliases.tsv" "$manifest" 2>/dev/null; then
    fail "$name" "model-aliases.tsv not found in install manifest"
    return
  fi
  pass "$name"
}

test_install_share_asset_conflict() {
  # Verifies install.sh exits 0 when ~/.claude/share/model-aliases.tsv already
  # exists from another source (conflict path must be graceful, not fatal).
  #
  # Steps:
  #   1. Pre-create ~/.claude/share/model-aliases.tsv with existing content.
  #   2. Run install.sh in that same temp HOME.
  #   3. Assert install.sh exits 0 (graceful conflict handling, no fatal error).
  local name="install-share-asset-conflict"
  should_run "$name" || return 0
  local home
  home="$tmp_root/$name"
  mkdir -p "$home/.claude/share"
  printf 'existing-content\n' > "$home/.claude/share/model-aliases.tsv"
  set +e
  HOME="$home" \
    CLAUDE_CONFIG_TEST_INSTALL_RUNNING=1 \
    CLAUDE_CONFIG_TEST_PREFLIGHT_HOME="$REAL_HOME" \
    bash "$REPO_ROOT/install.sh" >/dev/null 2>&1
  local rc=$?
  set -e
  if [[ $rc -ne 0 ]]; then
    fail "$name" "install.sh exited $rc on share asset conflict (expected 0)"
    return
  fi
  pass "$name"
}

test_install_share_asset_uninstall() {
  # Verifies uninstall.sh removes ~/.claude/share/model-aliases.tsv when it
  # was installed by install.sh (manifest-driven removal).
  #
  # Steps:
  #   1. Run install.sh to install share/model-aliases.tsv into temp HOME.
  #   2. Run uninstall.sh on that same temp HOME.
  #   3. Assert model-aliases.tsv no longer exists at ~/.claude/share/.
  local name="install-share-asset-uninstall"
  should_run "$name" || return 0
  local home
  home="$tmp_root/$name"
  mkdir -p "$home/.claude"
  HOME="$home" \
    CLAUDE_CONFIG_TEST_INSTALL_RUNNING=1 \
    CLAUDE_CONFIG_TEST_PREFLIGHT_HOME="$REAL_HOME" \
    bash "$REPO_ROOT/install.sh" >/dev/null 2>&1 || true
  if [[ ! -e "$home/.claude/share/model-aliases.tsv" ]]; then
    fail "$name" "precondition: model-aliases.tsv not installed"
    return
  fi
  HOME="$home" bash "$REPO_ROOT/uninstall.sh" >/dev/null 2>&1 || true
  if [[ -e "$home/.claude/share/model-aliases.tsv" ]]; then
    fail "$name" "model-aliases.tsv still present after uninstall"
    return
  fi
  pass "$name"
}

test_install_claude_home_override() {
  # Verifies an explicit CLAUDE_HOME env override redirects the install to a
  # sandbox dir (NOT $HOME/.claude), so install changes can be rehearsed without
  # touching the real config. Covers the cross-script consistency: agents/commands
  # (install.sh), the manifest, AND the hook settings.json (install-hooks.sh) must
  # all land in the override.
  #
  # Steps:
  #   1. Run install.sh with CLAUDE_HOME pointed at a dir distinct from $HOME/.claude.
  #   2. Assert install artifacts (.pm symlink, manifest, hook-wired settings.json)
  #      land in the override.
  #   3. Assert $HOME/.claude was NOT created (the override fully diverted the install).
  local name="install-claude-home-override"
  should_run "$name" || return 0
  local home override
  home="$tmp_root/$name-home"
  override="$tmp_root/$name-override"
  mkdir -p "$home"
  set +e
  HOME="$home" \
    CLAUDE_HOME="$override" \
    CLAUDE_CONFIG_TEST_INSTALL_RUNNING=1 \
    CLAUDE_CONFIG_TEST_PREFLIGHT_HOME="$REAL_HOME" \
    bash "$REPO_ROOT/install.sh" >/dev/null 2>&1
  local rc=$?
  set -e
  if [[ $rc -ne 0 ]]; then
    fail "$name" "install.sh exited $rc"
    return
  fi
  if [[ ! -L "$override/.pm" && ! -e "$override/.pm" ]]; then
    fail "$name" ".pm not installed under CLAUDE_HOME override ($override)"
    return
  fi
  if [[ ! -e "$override/.pm-dispatch/install-manifest.json" ]]; then
    fail "$name" "manifest not written under CLAUDE_HOME override"
    return
  fi
  if ! grep -q "hook-tool-trace.sh" "$override/settings.json" 2>/dev/null; then
    fail "$name" "hooks not wired into the override settings.json (install-hooks ignored CLAUDE_HOME)"
    return
  fi
  if [[ -e "$home/.claude" ]]; then
    fail "$name" "\$HOME/.claude was created despite the CLAUDE_HOME override"
    return
  fi
  pass "$name"
}

test_uninstall_claude_home_override() {
  # Verifies uninstall.sh honors the same CLAUDE_HOME override end-to-end: it
  # removes the sandbox install (including hook cleanup via uninstall-hooks.sh)
  # while leaving a pre-existing REAL $HOME/.claude config completely untouched.
  # The real-home sentinel is the exact boundary CC-294 depends on — a regression
  # where uninstall-hooks.sh edits $HOME/.claude/settings.json must fail this test.
  #
  # Steps:
  #   1. Install into a CLAUDE_HOME override.
  #   2. Plant a sentinel real-home config ($HOME/.claude/settings.json + marker).
  #   3. Run uninstall.sh with the override; assert it exits 0 (no || true masking).
  #   4. Assert the override's .pm and hook wiring are removed.
  #   5. Assert the real-home sentinel survived byte-for-byte.
  local name="uninstall-claude-home-override"
  should_run "$name" || return 0
  local home override
  home="$tmp_root/$name-home"
  override="$tmp_root/$name-override"
  mkdir -p "$home"
  set +e
  HOME="$home" CLAUDE_HOME="$override" \
    CLAUDE_CONFIG_TEST_INSTALL_RUNNING=1 \
    CLAUDE_CONFIG_TEST_PREFLIGHT_HOME="$REAL_HOME" \
    bash "$REPO_ROOT/install.sh" >/dev/null 2>&1
  local install_rc=$?
  set -e
  if [[ $install_rc -ne 0 ]]; then
    fail "$name" "precondition: install.sh exited $install_rc"
    return
  fi
  if [[ ! -e "$override/.pm" && ! -L "$override/.pm" ]]; then
    fail "$name" "precondition: .pm not installed under override"
    return
  fi

  # Sentinel real-home config that uninstall must NOT touch.
  local sentinel_settings="$home/.claude/settings.json"
  local sentinel_marker="$home/.claude/DO-NOT-TOUCH"
  mkdir -p "$home/.claude"
  printf '{"sentinel":"real-home-must-survive","statusLine":{"command":"/real/user/statusline"}}\n' > "$sentinel_settings"
  printf 'real home marker\n' > "$sentinel_marker"
  local sentinel_sum
  sentinel_sum="$(md5sum "$sentinel_settings" | awk '{print $1}')"

  set +e
  HOME="$home" CLAUDE_HOME="$override" bash "$REPO_ROOT/uninstall.sh" >/dev/null 2>&1
  local uninstall_rc=$?
  set -e
  if [[ $uninstall_rc -ne 0 ]]; then
    fail "$name" "uninstall.sh exited $uninstall_rc (expected 0)"
    return
  fi
  if [[ -e "$override/.pm" || -L "$override/.pm" ]]; then
    fail "$name" ".pm still present under override after uninstall"
    return
  fi
  # Override hook cleanup: the override settings.json must have its managed hooks
  # removed. With the pre-CC-294 bug (uninstall-hooks.sh resolving $HOME/.claude),
  # this hook would survive in the override while real home was edited instead.
  if grep -q "hook-tool-trace.sh" "$override/settings.json" 2>/dev/null; then
    fail "$name" "override settings.json still has managed hooks (uninstall-hooks ignored CLAUDE_HOME)"
    return
  fi
  # Real-home boundary: sentinel settings + marker must survive unchanged.
  if [[ ! -f "$sentinel_marker" ]]; then
    fail "$name" "real-home marker \$HOME/.claude/DO-NOT-TOUCH was removed by override uninstall"
    return
  fi
  if [[ "$(md5sum "$sentinel_settings" | awk '{print $1}')" != "$sentinel_sum" ]]; then
    fail "$name" "real-home \$HOME/.claude/settings.json was mutated by override uninstall (uninstall-hooks ignored CLAUDE_HOME)"
    return
  fi
  pass "$name"
}

test_install_share_asset_installed
test_install_share_asset_conflict
test_install_share_asset_uninstall
test_install_claude_home_override
test_uninstall_claude_home_override

th_summary
