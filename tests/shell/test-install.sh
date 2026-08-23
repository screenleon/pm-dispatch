#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C.UTF-8

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# getent is NSS-only (Linux); absent on macOS and Windows/Git-Bash. Fall back to
# $HOME there. On Linux getent succeeds, so the resolved value is unchanged.
REAL_HOME="$(getent passwd "$(id -un)" 2>/dev/null | cut -d: -f6 || true)"
[[ -n "$REAL_HOME" ]] || REAL_HOME="$HOME"
# shellcheck source=tests/lib/test-harness.sh
. "$SCRIPT_DIR/../lib/test-harness.sh"
# portable.sh provides detect_platform + make_junction_windows, used below to
# branch install-mode assertions: Linux/macOS install via symlink; Windows
# (MSYS) installs directories via junction and files via copy.
# shellcheck source=runtime/lib/portable.sh
. "$REPO_ROOT/runtime/lib/portable.sh"
# shellcheck source=runtime/lib/adapter-manifest.sh
. "$REPO_ROOT/runtime/lib/adapter-manifest.sh"
th_init "$@"

# --group core|guards — run only one subset so CI can fan out two parallel jobs
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
  printf 'test-install: --group requires a value (core or guards)\n' >&2
  exit 2
fi
unset _ti_a _ti_prev _ti_group_seen
case "$GROUP" in
  ""|core|guards) ;;
  *) printf 'test-install: --group must be core or guards (got: %s)\n' "$GROUP" >&2; exit 2 ;;
esac

_TI_PLATFORM="$(detect_platform)"
_ti_is_windows() { [[ "$_TI_PLATFORM" == "windows" ]]; }
_TI_RETIRED_TRACE="hook-tool-""trace.sh"
_TI_RETIRED_ROUTING="hook-routing-""log.sh"
# Retired by the CC-374 executor write-guard collapse (split with concat so the
# doctor hook-inventory parity scanner does not count it as a current managed hook).
_TI_RETIRED_CODEX_WRITE="hook-codex-write-""guard.sh"

# Directory containing jq. Tests that constrain PATH (e.g. to inject a fake
# powershell.exe) must keep jq reachable so install.sh's jq preflight passes;
# on Windows jq lives outside the standard bin dirs (the WinGet dir). Append
# ${_TI_JQ_DIR:+:$_TI_JQ_DIR} to such PATHs — a no-op when jq is already on the
# standard path (Linux/macOS).
_TI_JQ_DIR="$(dirname "$(command -v jq 2>/dev/null)" 2>/dev/null || true)"

# Skip a test on Windows with a visible note. Used for tests that assert
# POSIX-only semantics the Windows install path intentionally omits (e.g. pmctl
# copy/symlink behavior, or real-symlink fixtures that MSYS `ln -s` cannot
# create). Usage:
#   if _ti_skip_win "$name" "reason"; then return 0; fi
_ti_skip_win() {
  local name="$1" reason="$2"
  _ti_is_windows || return 1
  $LIST || printf 'SKIP: %s (%s)\n' "$name" "$reason"
  return 0
}

# The path form install-guards.sh writes into settings.json commands: on Windows
# it stores the native form (C:/...) via cygpath, which is what uninstall-guards.sh
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

# The full command install-guards.sh wires for the memory-injection hook on
# Claude (CC-566: `--host claude` selects the smaller Claude-only budget).
# Single source for the three fixtures that assert against this exact string,
# so a future path or suffix change only needs updating here.
_ti_claude_inject_hook_cmd() {
  printf '%s --host claude' "$(_ti_hook_cmd_path "$REPO_ROOT/runtime/hooks/guard-inject-memory.sh")"
}

# CC-102 introduced install-guards.sh profile auto-detection via
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
      install-guards-*|hooks-*|uninstall-guards-*|\
      dispatch-allowlist-*|\
      test_install_adds_dispatch_allowlist|\
      test_install_dispatch_allowlist_*|\
      test_dispatch_allowlist_*|\
      userpromptsubmit-*|session-stop-*|statusline-*)
        [[ "$GROUP" == "guards" ]] || return 1 ;;
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
        cp "$REPO_ROOT/runtime/bin/pr-gate.sh" "$home/.claude/scripts/pr-gate.sh"
      else
        ln -s "$REPO_ROOT/runtime/bin/pr-gate.sh" "$home/.claude/scripts/pr-gate.sh"
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
        assert_file_contains "$name" "$out" "copy   $home/.claude/scripts/pr-gate.sh -> $REPO_ROOT/runtime/bin/pr-gate.sh" || return
        assert_copy_of "$name" "$home/.claude/scripts/pr-gate.sh" "$REPO_ROOT/runtime/bin/pr-gate.sh" || return
      else
        assert_file_contains "$name" "$out" "link   $home/.claude/scripts/pr-gate.sh -> $REPO_ROOT/runtime/bin/pr-gate.sh" || return
        assert_symlink_target "$name" "$home/.claude/scripts/pr-gate.sh" "$REPO_ROOT/runtime/bin/pr-gate.sh" || return
      fi
      ;;
    scripts-correct-symlink-idempotent)
      assert_file_contains "$name" "$out" "ok    $home/.claude/scripts/pr-gate.sh" || return
      assert_symlink_target "$name" "$home/.claude/scripts/pr-gate.sh" "$REPO_ROOT/runtime/bin/pr-gate.sh" || return
      ;;
    scripts-wrong-symlink-real-run)
      assert_file_contains "$name" "$err" \
        "load-bearing copy bundle conflict: $home/.claude/scripts/pr-gate.sh" || return
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
  run_install_case "scripts-wrong-symlink-real-run" script-wrong-symlink 1
fi

# Behavior: a copy-fallback install publishes a self-contained, receipt-owned
# adapter/doctor/Gate topology and never falls through to foreign parent paths.
# Steps: Arrange an isolated home with decoys and a copy install; Act by running
# copied entrypoints then removing owned pieces; Assert owned routing and closed failure.
case_installed_copy_gate_reader_layout() {
  local name="installed-copy-gate-reader-layout"
  should_run "$name" || return 0
  local home="$tmp_root/$name-home" install_out="$tmp_root/$name-install.out"
  local err="$tmp_root/$name-install.err" gate_out="$tmp_root/$name-gate.out"
  local gate_err="$tmp_root/$name-gate.err" gate_repo="$tmp_root/$name-repo"
  local marker="$tmp_root/$name.marker" code=0 lib adapter adapter_out adapter_err assurance
  local doctor_out doctor_err foreign_pmctl dependency_line agents_line adapters_line entrypoint_line
  local foreign_router_marker="$tmp_root/$name-foreign-router.marker"
  local foreign_adapter_marker="$tmp_root/$name-foreign-adapter.marker"
  local foreign_lib_marker="$tmp_root/$name-foreign-lib.marker"
  # An unrelated legacy directory above ~/.claude must not shadow the
  # receipt-owned reviewer definitions in the installed copy layout.
  mkdir -p "$home/.claude" "$home/agents"

  set +e
  HOME="$home" PMCTL_BIN_DIR="$home/.local/bin" \
    FAKE_SYMLINK_UNSUPPORTED=1 \
    CLAUDE_CONFIG_TEST_INSTALL_RUNNING=1 \
    CLAUDE_CONFIG_TEST_PREFLIGHT_HOME="$REAL_HOME" \
    bash "$REPO_ROOT/install.sh" --profile minimal >"$install_out" 2>"$err"
  code=$?
  set -e
  if [[ "$code" -ne 0 ]]; then
    fail "$name" "copy-fallback install exited $code: $(tail -3 "$err" | tr '\n' '|')"
    return
  fi

  dependency_line="$(grep -nF '==> load-bearing dependency bundle' "$install_out" | head -1 | cut -d: -f1)"
  agents_line="$(grep -nF '==> agents' "$install_out" | head -1 | cut -d: -f1)"
  adapters_line="$(grep -nF '==> adapters' "$install_out" | head -1 | cut -d: -f1)"
  entrypoint_line="$(grep -nF '==> load-bearing entrypoints' "$install_out" | head -1 | cut -d: -f1)"
  if [[ -z "$dependency_line" || -z "$agents_line" || -z "$adapters_line" \
      || -z "$entrypoint_line" || "$dependency_line" -ge "$agents_line" \
      || "$dependency_line" -ge "$adapters_line" || "$agents_line" -ge "$entrypoint_line" \
      || "$adapters_line" -ge "$entrypoint_line" ]]; then
    fail "$name" "load-bearing apply order was not dependencies -> managed trees -> entrypoints"
    return
  fi

  for lib in identifier-policy runner-kind adapter-manifest dispatch-common \
      state-writer state-paths portable model-aliases reasoning-effort timeout-resolve; do
    assert_copy_of "$name" "$home/.claude/runtime/lib/$lib.sh" \
      "$REPO_ROOT/runtime/lib/$lib.sh" || return
  done
  assert_copy_of "$name" "$home/.claude/scripts/lib/adapter-manifest.sh" \
    "$REPO_ROOT/runtime/lib/adapter-manifest.sh" || return
  assert_copy_of "$name" "$home/.claude/scripts/lib/gate-memory-context.sh" \
    "$REPO_ROOT/runtime/lib/gate-memory-context.sh" || return
  assert_copy_of "$name" "$home/.claude/scripts/core/policy/isolation-level.yaml" \
    "$REPO_ROOT/core/policy/isolation-level.yaml" || return
  for adapter in codex claude opencode grok; do
    assert_copy_of "$name" "$home/.claude/share/$adapter-model-aliases.tsv" \
      "$REPO_ROOT/share/$adapter-model-aliases.tsv" || return
  done
  assert_copy_of "$name" "$home/.claude/ops/usage/log-usage.sh" \
    "$REPO_ROOT/ops/usage/log-usage.sh" || return
  assert_copy_of "$name" "$home/.claude/scripts/pr-gate.sh" \
    "$REPO_ROOT/runtime/bin/pr-gate.sh" || return

  # Every copied built-in must complete its bootstrap without reaching a live
  # executor. --print-cmd proves the copied entrypoint can snapshot the bundled
  # runtime/share dependencies and construct its command.
  for adapter in codex claude opencode grok; do
    adapter_out="$tmp_root/$name-$adapter.out"
    adapter_err="$tmp_root/$name-$adapter.err"
    set +e
    HOME="$home" bash "$home/.claude/adapters/$adapter/dispatch.sh" \
      --cd "$REPO_ROOT" --print-cmd >"$adapter_out" 2>"$adapter_err"
    code=$?
    set -e
    if [[ "$code" -ne 0 || ! -s "$adapter_out" ]]; then
      fail "$name" "$adapter copy bootstrap failed rc=$code err=$(tail -3 "$adapter_err" | tr '\n' '|')"
      return
    fi
  done

  # Replace the copied codex implementation with a deterministic Gate fixture,
  # leaving adapter.yaml unchanged. This proves the installed pr-gate reaches a
  # valid manifest entrypoint, not merely that invalid-name resolution works.
  cat > "$home/.claude/adapters/codex/dispatch.sh" <<'GATE_STUB'
#!/usr/bin/env bash
set -euo pipefail
: "${PM_INSTALL_COPY_MARKER:?}"
: "${PM_INSTALL_GATE_FIXTURE:?}"
touch "$PM_INSTALL_COPY_MARKER"
# shellcheck disable=SC1090
. "$PM_INSTALL_GATE_FIXTURE"
pr_gate_fixture_profile_dispatch codex "$@"
GATE_STUB
  chmod +x "$home/.claude/adapters/codex/dispatch.sh"

  # Foreign/stale paths that match older heuristic locations must not shadow
  # the receipt-owned installed root selected above.
  mkdir -p "$home/.claude/lib" "$home/.claude/scripts/adapters/codex"
  cat > "$home/.claude/lib/executor-router.sh" <<'FOREIGN_ROUTER'
#!/usr/bin/env bash
touch "${PM_INSTALL_FOREIGN_ROUTER_MARKER:?}"
FOREIGN_ROUTER
  for lib in portable repo-layout gate-result-verify artifact-paths pmctl-policy detached-launch; do
    cat > "$home/.claude/lib/$lib.sh" <<'FOREIGN_LIB'
#!/usr/bin/env bash
touch "${PM_INSTALL_FOREIGN_LIB_MARKER:?}"
FOREIGN_LIB
  done
  mkdir -p "$home/core/policy"
  for lib in gate-tiers gate-modes gate-pass-kinds gate-policy-consumers gate-policy-signals; do
    printf 'foreign-policy-must-not-be-read\n' > "$home/core/policy/$lib.tsv"
  done
  printf 'foreign-isolation-policy-must-not-be-read\n' \
    > "$home/core/policy/isolation-level.yaml"
  cat > "$home/.claude/scripts/adapters/codex/adapter.yaml" <<'FOREIGN_MANIFEST'
schema_version: 1
adapter_name: codex
runner_kind: cli-subprocess
dispatch_entrypoint: ./dispatch.sh
FOREIGN_MANIFEST
  cat > "$home/.claude/scripts/adapters/codex/dispatch.sh" <<'FOREIGN_ADAPTER'
#!/usr/bin/env bash
touch "${PM_INSTALL_FOREIGN_ADAPTER_MARKER:?}"
exit 99
FOREIGN_ADAPTER
  chmod +x "$home/.claude/scripts/adapters/codex/dispatch.sh"
  mkdir -p "$home/cli" "$home/.claude/scripts/cli" "$home/.claude/scripts/bin"
  for foreign_pmctl in "$home/cli/pmctl" \
      "$home/.claude/scripts/cli/pmctl" "$home/.claude/scripts/bin/pmctl"; do
    printf '#!/usr/bin/env bash\nexit 99\n' > "$foreign_pmctl"
    chmod +x "$foreign_pmctl"
  done

  doctor_out="$tmp_root/$name-doctor.out"
  doctor_err="$tmp_root/$name-doctor.err"
  code=0
  PM_INSTALL_FOREIGN_LIB_MARKER="$foreign_lib_marker" HOME="$home" \
    bash "$home/.claude/scripts/doctor.sh" --no-color --repo "$REPO_ROOT" \
    >"$doctor_out" 2>"$doctor_err" || code=$?
  if [[ "$code" -gt 1 || -e "$foreign_lib_marker" \
      || "$(<"$doctor_out")" != *"Summary:"* ]]; then
    fail "$name" "installed doctor did not use child bundle rc=$code err=$(tail -3 "$doctor_err" | tr '\n' '|')"
    return
  fi
  code=0
  HOME="$home" bash "$home/.claude/scripts/doctor.sh" --no-color \
    >"$doctor_out" 2>"$doctor_err" || code=$?
  if [[ "$code" -ne 1 || "$(<"$doctor_out")" != *"requires an explicit checkout via --repo"* \
      || -e "$foreign_lib_marker" ]]; then
    fail "$name" "installed doctor without --repo did not fail closed rc=$code"
    return
  fi
  mv "$home/.claude/scripts/lib/host-manifest.sh" \
    "$home/.claude/scripts/lib/host-manifest.sh.missing"
  code=0
  PM_INSTALL_FOREIGN_LIB_MARKER="$foreign_lib_marker" HOME="$home" \
    bash "$home/.claude/scripts/doctor.sh" --help \
    >"$doctor_out" 2>"$doctor_err" || code=$?
  mv "$home/.claude/scripts/lib/host-manifest.sh.missing" \
    "$home/.claude/scripts/lib/host-manifest.sh"
  if [[ "$code" -ne 0 || -e "$foreign_lib_marker" ]]; then
    fail "$name" "incomplete installed doctor bundle fell back to parent lib rc=$code"
    return
  fi
  git init -q -b main "$gate_repo"
  git -C "$gate_repo" config user.email test@example.com
  git -C "$gate_repo" config user.name 'Gate Test'
  printf 'initial\n' > "$gate_repo/README.md"
  printf '.agent-trace/\n.gate-briefs/\n.gate-results/\n' > "$gate_repo/.gitignore"
  git -C "$gate_repo" add README.md .gitignore
  git -C "$gate_repo" commit -q -m initial
  cat > "$gate_repo/app.go" <<'GATE_REPO_SOURCE'
package main

func main() {}
GATE_REPO_SOURCE

  set +e
  PM_INSTALL_COPY_MARKER="$marker" \
    PM_INSTALL_GATE_FIXTURE="$REPO_ROOT/tests/lib/test-pr-gate-fixture.sh" \
    PM_INSTALL_FOREIGN_ROUTER_MARKER="$foreign_router_marker" \
    PM_INSTALL_FOREIGN_ADAPTER_MARKER="$foreign_adapter_marker" \
    PM_INSTALL_FOREIGN_LIB_MARKER="$foreign_lib_marker" \
    HOME="$home" bash "$home/.claude/scripts/pr-gate.sh" \
    --cd "$gate_repo" --executor codex --base main --isolation workspace-write \
    >"$gate_out" 2>"$gate_err"
  code=$?
  set -e
  assurance="$(find "$gate_repo/.gate-results" -maxdepth 1 -type f \
    -name '*.assurance.json' -print -quit 2>/dev/null || true)"
  if [[ "$code" -eq 0 && -f "$marker" \
      && ! -e "$foreign_router_marker" && ! -e "$foreign_adapter_marker" \
      && ! -e "$foreign_lib_marker" \
      && -n "$assurance" \
      && "$(jq -r '.provenance.policy_source // empty' "$assurance")" == generated-snapshot \
      && "$(<"$gate_err")" != *"manifest reader/tree unavailable"* ]]; then
    :
  else
    fail "$name" "code=$code marker=$([[ -f "$marker" ]] && echo yes || echo no) err=$(tail -5 "$gate_err" | tr '\n' '|') out=$(tail -5 "$gate_out" | tr '\n' '|')"
    return
  fi
  for foreign_pmctl in "$home/cli/pmctl" \
      "$home/.claude/scripts/cli/pmctl" "$home/.claude/scripts/bin/pmctl"; do
    if grep -R -Fq -- "$foreign_pmctl" "$gate_repo/.gate-briefs" 2>/dev/null; then
      fail "$name" "installed Gate embedded foreign pmctl candidate: $foreign_pmctl"
      return
    fi
  done

  # Installed-topology classification must not depend on every receipt-owned
  # child still being present. Missing either an early manifest dependency or
  # a later Gate dependency must fail closed without sourcing adjacent parent
  # libraries prepared above.
  local missing_lib missing_diagnostic
  for missing_lib in adapter-manifest gate-memory-context; do
    case "$missing_lib" in
      adapter-manifest) missing_diagnostic="failed to load canonical executor router" ;;
      gate-memory-context) missing_diagnostic="shared gate memory runtime not found" ;;
    esac
    mv "$home/.claude/scripts/lib/$missing_lib.sh" \
      "$home/.claude/scripts/lib/$missing_lib.sh.missing"
    rm -f "$marker" "$foreign_router_marker" "$foreign_adapter_marker" \
      "$foreign_lib_marker"
    gate_out="$tmp_root/$name-missing-$missing_lib.out"
    gate_err="$tmp_root/$name-missing-$missing_lib.err"
    code=0
    (
      # This suite exports manifest functions to subprocesses. The copied Gate
      # must still reject a missing receipt-owned reader rather than trusting
      # those inherited definitions.
      PM_INSTALL_COPY_MARKER="$marker" \
        PM_INSTALL_GATE_FIXTURE="$REPO_ROOT/tests/lib/test-pr-gate-fixture.sh" \
        PM_INSTALL_FOREIGN_ROUTER_MARKER="$foreign_router_marker" \
        PM_INSTALL_FOREIGN_ADAPTER_MARKER="$foreign_adapter_marker" \
        PM_INSTALL_FOREIGN_LIB_MARKER="$foreign_lib_marker" \
        HOME="$home" bash "$home/.claude/scripts/pr-gate.sh" \
        --cd "$gate_repo" --executor codex --base main --isolation workspace-write \
        >"$gate_out" 2>"$gate_err"
    ) || code=$?
    mv "$home/.claude/scripts/lib/$missing_lib.sh.missing" \
      "$home/.claude/scripts/lib/$missing_lib.sh"
    if [[ "$code" -eq 0 || -e "$marker" \
        || -e "$foreign_router_marker" || -e "$foreign_adapter_marker" \
        || -e "$foreign_lib_marker" \
        || "$(<"$gate_err")" != *"$missing_diagnostic"* ]]; then
      fail "$name" "incomplete installed Gate bundle fell through for $missing_lib rc=$code err=$(tail -5 "$gate_err" | tr '\n' '|')"
      return
    fi
  done

  # Once the installed topology is selected, a missing receipt-owned reviewer
  # bundle must fail closed rather than falling through to the legacy ~/agents
  # directory prepared above.
  mv "$home/.claude/agents" "$home/.claude/agents.receipt-missing"
  rm -f "$marker"
  gate_out="$tmp_root/$name-missing-agents.out"
  gate_err="$tmp_root/$name-missing-agents.err"
  code=0
  PM_INSTALL_COPY_MARKER="$marker" \
    PM_INSTALL_GATE_FIXTURE="$REPO_ROOT/tests/lib/test-pr-gate-fixture.sh" \
    HOME="$home" bash "$home/.claude/scripts/pr-gate.sh" \
    --cd "$gate_repo" --executor codex --base main --isolation workspace-write \
    >"$gate_out" 2>"$gate_err" || code=$?
  if [[ "$code" -eq 0 || -e "$marker" \
      || "$(<"$gate_err")" != *"reviewer definition directory not found"* ]]; then
    fail "$name" "missing installed reviewer bundle did not fail closed rc=$code err=$(tail -5 "$gate_err" | tr '\n' '|')"
    return
  fi

  pass "$name"
}

case_installed_copy_gate_reader_layout

# Behavior: copy-fallback receipts describe exact installed bytes, permit an
# idempotent reinstall, and let uninstall remove every untouched managed bundle.
# Steps: Arrange a copy install and its receipt; Act by reinstalling then
# uninstalling; Assert exact digests, no conflict, and complete managed removal.
case_copy_install_receipt_lifecycle() {
  local name="copy-install-receipt-lifecycle"
  should_run "$name" || return 0
  local home="$tmp_root/$name-home" bin="$tmp_root/$name-bin"
  local first_out="$tmp_root/$name-first.out" first_err="$tmp_root/$name-first.err"
  local second_out="$tmp_root/$name-second.out" second_err="$tmp_root/$name-second.err"
  local uninstall_out="$tmp_root/$name-uninstall.out"
  local receipt="$home/.pm-dispatch/install-manifest.json"
  local config_root="$tmp_root/$name-config-root"
  local dst expected actual code=0
  mkdir -p "$home" "$bin"
  if _ti_is_windows; then
    mkdir -p "$home/.claude"
  else
    mkdir -p "$config_root"
    ln -s "$config_root" "$home/.claude"
  fi

  HOME="$home" PMCTL_BIN_DIR="$bin" FAKE_SYMLINK_UNSUPPORTED=1 \
    CLAUDE_CONFIG_TEST_INSTALL_RUNNING=1 \
    CLAUDE_CONFIG_TEST_PREFLIGHT_HOME="$REAL_HOME" \
    bash "$REPO_ROOT/install.sh" --profile minimal >"$first_out" 2>"$first_err" || code=$?
  if [[ "$code" -ne 0 || ! -f "$receipt" ]]; then
    fail "$name" "first copy install failed rc=$code err=$(tail -3 "$first_err" | tr '\n' '|')"
    return
  fi

  while IFS=$'\t' read -r dst expected; do
    [[ -n "$dst" && -n "$expected" ]] || continue
    actual="$(_portable_sha256_path "$dst")" || {
      fail "$name" "cannot hash copied receipt destination: $dst"; return; }
    if [[ "$actual" != "$expected" ]]; then
      fail "$name" "fresh copy digest mismatch: $dst"
      return
    fi
  done < <(jq -r '.entries[] | select(.mode == "copy") | [.dst,.sha256] | @tsv' "$receipt")

  code=0
  HOME="$home" PMCTL_BIN_DIR="$bin" FAKE_SYMLINK_UNSUPPORTED=1 \
    CLAUDE_CONFIG_TEST_INSTALL_RUNNING=1 \
    CLAUDE_CONFIG_TEST_PREFLIGHT_HOME="$REAL_HOME" \
    bash "$REPO_ROOT/install.sh" --profile minimal >"$second_out" 2>"$second_err" || code=$?
  if [[ "$code" -ne 0 ]] || grep -q 'CONFLICT' "$second_out" "$second_err"; then
    fail "$name" "second copy install was not idempotent rc=$code err=$(tail -3 "$second_err" | tr '\n' '|')"
    return
  fi

  code=0
  HOME="$home" PMCTL_BIN_DIR="$bin" \
    bash "$REPO_ROOT/uninstall.sh" >"$uninstall_out" 2>&1 || code=$?
  if [[ "$code" -ne 0 || -e "$receipt" \
      || -e "$home/.claude/.pm-dispatch/install-manifest.json" \
      || -e "$home/.claude/runtime" || -e "$home/.claude/ops" \
      || -e "$home/.claude/scripts/core" \
      || "$(<"$uninstall_out")" == *"modified since install"* ]]; then
    fail "$name" "untouched copy uninstall was incomplete rc=$code out=$(tail -8 "$uninstall_out" | tr '\n' '|')"
    return
  fi

  pass "$name"
}

case_copy_install_receipt_lifecycle

# Behavior: foreign load-bearing files or trees, including stale claimed Windows
# junctions, stop installation before any managed state is published or overwritten.
# Steps: Arrange each protected destination with a sentinel; Act by installing;
# Assert exit 1, the exact conflict, unchanged bytes, and no pmctl or receipt.
case_load_bearing_bundle_conflicts_fail() {
  local name="load-bearing-copy-bundle-conflicts-fail"
  should_run "$name" || return 0
  local variant home bin out err target sentinel code

  for variant in doctor-entrypoint gate-entrypoint gate-runtime adapter-runtime adapter-tree reviewer-tree alias-asset usage-helper; do
    home="$tmp_root/$name-$variant-home"
    bin="$tmp_root/$name-$variant-bin"
    out="$tmp_root/$name-$variant.out"
    err="$tmp_root/$name-$variant.err"
    mkdir -p "$home/.claude" "$bin"
    case "$variant" in
      doctor-entrypoint)
        target="$home/.claude/scripts/doctor.sh"
        mkdir -p "${target%/*}"
        sentinel="$target"
        printf 'foreign\n' > "$sentinel"
        ;;
      gate-entrypoint)
        target="$home/.claude/scripts/pr-gate.sh"
        mkdir -p "${target%/*}"
        sentinel="$target"
        printf 'foreign\n' > "$sentinel"
        ;;
      gate-runtime)
        target="$home/.claude/scripts/lib"
        mkdir -p "$target"
        sentinel="$target/foreign.txt"
        printf 'foreign\n' > "$sentinel"
        ;;
      adapter-runtime)
        target="$home/.claude/runtime/lib/adapter-manifest.sh"
        mkdir -p "${target%/*}"
        sentinel="$target"
        printf 'foreign\n' > "$sentinel"
        ;;
      adapter-tree)
        target="$home/.claude/adapters/codex"
        mkdir -p "$target"
        sentinel="$target/foreign.txt"
        printf 'foreign\n' > "$sentinel"
        ;;
      reviewer-tree)
        target="$home/.claude/agents/critic.md"
        mkdir -p "${target%/*}"
        sentinel="$target"
        printf 'foreign\n' > "$sentinel"
        ;;
      alias-asset)
        target="$home/.claude/share/codex-model-aliases.tsv"
        mkdir -p "${target%/*}"
        sentinel="$target"
        printf 'foreign\n' > "$sentinel"
        ;;
      usage-helper)
        target="$home/.claude/ops/usage/log-usage.sh"
        mkdir -p "${target%/*}"
        sentinel="$target"
        printf 'foreign\n' > "$sentinel"
        ;;
    esac

    code=0
    HOME="$home" PMCTL_BIN_DIR="$bin" \
      CLAUDE_CONFIG_TEST_INSTALL_RUNNING=1 \
      CLAUDE_CONFIG_TEST_PREFLIGHT_HOME="$REAL_HOME" \
      bash "$REPO_ROOT/install.sh" --profile minimal >"$out" 2>"$err" || code=$?
    if [[ "$code" -ne 1 || "$(<"$err")" != *"load-bearing copy bundle conflict: $target"* \
        || "$(<"$sentinel")" != foreign || -e "$bin/pmctl" \
        || -e "$home/.pm-dispatch/install-manifest.json" ]]; then
      fail "$name" "$variant did not fail closed rc=$code err=$(tail -3 "$err" | tr '\n' '|')"
      return
    fi
  done

  # A stale receipt claiming a Windows junction is not proof that an existing
  # real directory is still that junction. Probe its shipped children and
  # reject foreign bytes before any mutation.
  home="$tmp_root/$name-windows-stale-junction-home"
  bin="$tmp_root/$name-windows-stale-junction-bin"
  out="$tmp_root/$name-windows-stale-junction.out"
  err="$tmp_root/$name-windows-stale-junction.err"
  target="$home/.claude/adapters/codex"
  sentinel="$target/dispatch.sh"
  mkdir -p "$target" "$home/.pm-dispatch" "$bin"
  printf 'foreign\n' > "$sentinel"
  printf '{"manifest_version":1,"entries":[{"src":"%s","dst":"%s","mode":"junction"}]}\n' \
    "$REPO_ROOT/adapters" "$home/.claude/adapters" \
    > "$home/.pm-dispatch/install-manifest.json"
  code=0
  HOME="$home" PMCTL_BIN_DIR="$bin" PM_DISPATCH_PLATFORM=windows \
    CLAUDE_CONFIG_TEST_INSTALL_RUNNING=1 \
    CLAUDE_CONFIG_TEST_PREFLIGHT_HOME="$REAL_HOME" \
    bash "$REPO_ROOT/install.sh" --profile minimal >"$out" 2>"$err" || code=$?
  if [[ "$code" -ne 1 || "$(<"$err")" != *"load-bearing copy bundle conflict: $target"* \
      || "$(<"$sentinel")" != foreign || -e "$bin/pmctl" ]]; then
    fail "$name" "stale Windows junction receipt bypassed preflight rc=$code err=$(tail -3 "$err" | tr '\n' '|')"
    return
  fi

  pass "$name"
}

case_load_bearing_bundle_conflicts_fail

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
  # Intentionally bundled with CC-465: CJK term extraction must not reintroduce
  # python3, and isolated PATH must not imply doctor still depends on it
  # (removed from runtime in CC-104t).
  for cmd in bash dirname pwd readlink uname jq sed grep awk tr basename; do
    link_existing_cmd "$bin" "$cmd"
  done
  bash_real="$(command -v bash)"

  out="$(HOME="$home" CLAUDE_CONFIG_DIR="$home/.claude" PATH="$bin" "$bash_real" "$REPO_ROOT/runtime/bin/doctor.sh" --no-color --repo "$REPO_ROOT" 2>&1)" || status=$?
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
    # Linux/macOS install records the checkout-owned pmctl symlink so a later
    # checkout can refresh it through the same manifest ownership proof.
    expected_entries=$((expected_entries + 1))
    for subdir in agents skills commands adapters; do
      [[ -d "$REPO_ROOT/$subdir" ]] || continue
      for _ in "$REPO_ROOT/$subdir"/*; do
        expected_entries=$((expected_entries + 1))
      done
    done
  fi
  for script in token-usage.sh log-usage.sh pr-gate.sh setup-project.sh patch-gitignore.sh doctor.sh; do
    [[ -e "$REPO_ROOT/scripts/$script" ]] && expected_entries=$((expected_entries + 1))
  done
  [[ -d "$REPO_ROOT/runtime/lib" ]] && expected_entries=$((expected_entries + 1))
  [[ -f "$REPO_ROOT/core/policy/isolation-level.yaml" ]] \
    && expected_entries=$((expected_entries + 1))
  [[ -d "$REPO_ROOT/pm" ]] && expected_entries=$((expected_entries + 1))
  for lib in identifier-policy runner-kind adapter-manifest dispatch-common \
      state-writer state-paths portable model-aliases reasoning-effort timeout-resolve; do
    [[ -f "$REPO_ROOT/runtime/lib/$lib.sh" ]] && expected_entries=$((expected_entries + 1))
  done
  [[ -f "$REPO_ROOT/ops/usage/log-usage.sh" ]] && expected_entries=$((expected_entries + 1))
  for adapter in codex claude opencode grok; do
    [[ -f "$REPO_ROOT/share/$adapter-model-aliases.tsv" ]] && expected_entries=$((expected_entries + 1))
  done
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
         and (has("digest_scheme") | not)
         and (has("fallback_reason") | not))
        or
        (.mode == "copy"
         and has("sha256")
         and (.sha256 | test("^[0-9a-f]{64}$"))
         and (.digest_scheme == "file-v1" or .digest_scheme == "logical-tree-v1")
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

# ── install-guards / uninstall-guards lifecycle ─────────────────────────────────
# Proves that install-guards.sh wires managed hooks and that
# uninstall-guards.sh removes each of them completely, leaving no orphaned entries.

test_install_sh_wires_hooks() {
  # Proves that the primary install.sh path wires managed hooks
  # into settings.json automatically — no manual install-guards.sh step needed.
  # Passes --profile full explicitly to assert the full managed hook set is
  # wired regardless of host codex availability. No adapter ships a bash guard
  # today (codex's was retired with the codex-executor agent), so the settings
  # must NOT contain any adapter bash-guard entry on either platform.
  local name="install-sh-wires-hooks"
  should_run "$name" || return 0
  local home="$tmp_root/$name"
  mkdir -p "$home/.claude"
  printf '{"permissions":{}}\n' > "$home/.claude/settings.json"

  HOME="$home" \
    CLAUDE_CONFIG_TEST_INSTALL_RUNNING=1 \
    CLAUDE_CONFIG_TEST_PREFLIGHT_HOME="$REAL_HOME" \
    bash "$REPO_ROOT/install.sh" --profile full > /dev/null 2>&1

  assert_file_contains "$name" "$home/.claude/settings.json" "guard-pm-write.sh" || return
  assert_not_contains "$name" "$home/.claude/settings.json" "adapters/codex/bash-guard.sh" || return
  assert_not_contains "$name" "$home/.claude/settings.json" "$_TI_RETIRED_TRACE" || return
  assert_file_contains "$name" "$home/.claude/settings.json" "hosts/claude/hooks/log-usage.sh" || return
  assert_not_contains "$name" "$home/.claude/settings.json" "$_TI_RETIRED_ROUTING" || return
  assert_file_contains "$name" "$home/.claude/settings.json" "guard-inject-memory.sh" || return
  assert_file_contains "$name" "$home/.claude/settings.json" "inject-context.sh" || return
  assert_file_contains "$name" "$home/.claude/settings.json" "hosts/claude/hooks/save-rate-limits.sh" || return
  if [[ -f "$home/.claude/statusline-chain.conf" ]]; then
    fail "$name" "statusline-chain.conf should not exist without previous statusLine"
    return
  fi
  pass "$name"
}

test_install_sh_profile_minimal_skips_codex_hooks() {
  # Proves --profile minimal does NOT wire adapter bash guards but keeps
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

  assert_file_contains "$name" "$home/.claude/settings.json" "guard-pm-write.sh" || return
  assert_not_contains "$name" "$home/.claude/settings.json" "hook-codex-bash-guard.sh" || return
  assert_not_contains "$name" "$home/.claude/settings.json" "adapters/codex/bash-guard.sh" || return
  assert_file_contains "$name" "$home/.claude/settings.json" "hosts/claude/hooks/log-usage.sh" || return
  assert_file_contains "$name" "$home/.claude/settings.json" "guard-inject-memory.sh" || return
  assert_file_contains "$name" "$home/.claude/settings.json" "inject-context.sh" || return
  pass "$name"
}

test_install_sh_profile_full_wires_no_adapter_bash_guard() {
  # Regression lock for the codex-executor retirement: --profile full wires the
  # managed hook set but NO adapter bash guard, because no adapter ships one
  # (codex's bash guard was retired with the codex-executor agent). Manifest-
  # driven wiring + orphan cleanup means the retired guard is never wired.
  local name="install-sh-profile-full-wires-no-adapter-bash-guard"
  should_run "$name" || return 0
  local home="$tmp_root/$name"
  mkdir -p "$home/.claude"
  printf '{"permissions":{}}\n' > "$home/.claude/settings.json"

  HOME="$home" \
    CLAUDE_CONFIG_TEST_INSTALL_RUNNING=1 \
    CLAUDE_CONFIG_TEST_PREFLIGHT_HOME="$REAL_HOME" \
    bash "$REPO_ROOT/install.sh" --profile full > /dev/null 2>&1

  assert_file_contains "$name" "$home/.claude/settings.json" "guard-pm-write.sh" || return
  assert_not_contains "$name" "$home/.claude/settings.json" "adapters/codex/bash-guard.sh" || return
  pass "$name"
}

dispatch_allowlist_entries_for_home() {
  # Mirrors dispatch_allowlist_entries() from runtime/lib/allowlist.sh but accepts
  # an explicit home arg (tests use a temp dir, not the real $HOME).
  local home="$1"
  local adapter f rel

  while IFS= read -r adapter; do
    [[ -n "$adapter" ]] || continue
    f="$(adapter_manifest_dispatch_path "$REPO_ROOT" "$adapter")" || continue
    rel="${f#"$home/"}"
    printf 'Bash(%s:*)\nBash(~/%s:*)\n' "$f" "$rel"
  done < <(adapter_manifest_names "$REPO_ROOT")

  printf 'Bash(pmctl:*)\n'
  printf 'Bash(bash cli/pmctl:*)\n'
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

# Behavior: a cross-checkout install retires both absolute and HOME-relative
# dispatch grants owned by the former checkout without touching foreign grants.
# Steps: seed the prior adapter symlink + manifest ownership record and both
# allowlist spellings, install the candidate, then inspect permissions.allow.
test_install_dispatch_allowlist_refreshes_other_checkout_paths() {
  local name="test_install_dispatch_allowlist_refreshes_other_checkout_paths"
  should_run "$name" || return 0
  if _ti_skip_win "$name" "symlink ownership fixture is POSIX-only"; then return 0; fi
  local home="$tmp_root/$name-home" claude_home old_root settings manifest foreign
  claude_home="$home/.claude"
  old_root="$home/old checkout"
  settings="$claude_home/settings.json"
  manifest="$claude_home/.pm-dispatch/install-manifest.json"
  foreign="Bash(~/foreign checkout/adapters/claude/dispatch.sh:*)"
  mkdir -p "$claude_home/adapters" "$claude_home/.pm-dispatch" \
    "$old_root/adapters/claude"
  ln -s "$old_root/adapters/claude" "$claude_home/adapters/claude"
  jq -cn --arg src "$old_root/adapters/claude" \
    --arg dst "$claude_home/adapters/claude" \
    '{manifest_version:1,entries:[{src:$src,dst:$dst,mode:"symlink"}]}' > "$manifest"
  jq -n --arg old "$old_root" --arg foreign "$foreign" '{permissions:{allow:[
    ("Bash("+$old+"/adapters/claude/dispatch.sh:*)"),
    "Bash(~/old checkout/adapters/claude/dispatch.sh:*)",
    $foreign,
    "Bash(echo:*)"
  ]}}' > "$settings"

  HOME="$home" CLAUDE_HOME="$claude_home" \
    CLAUDE_CONFIG_TEST_INSTALL_RUNNING=1 \
    CLAUDE_CONFIG_TEST_PREFLIGHT_HOME="$REAL_HOME" \
    bash "$REPO_ROOT/install.sh" >/dev/null 2>&1

  if jq -e --arg old "$old_root" --arg foreign "$foreign" --arg root "$REPO_ROOT" '
      ([.permissions.allow[]? | select(startswith("Bash("+$old+"/adapters/") or
        startswith("Bash(~/old checkout/adapters/"))] | length) == 0 and
      (.permissions.allow | index($foreign)) != null and
      (.permissions.allow | index("Bash(echo:*)")) != null and
      any(.permissions.allow[]?; startswith("Bash("+$root+"/adapters/"))
    ' "$settings" >/dev/null; then
    pass "$name"
  else
    fail "$name" "stale checkout grants survived or foreign/current grants changed: $(jq -c . "$settings")"
  fi
}

# Behavior: changing dispatch_entrypoint in the same checkout revokes the old
# Adapter Bash grant instead of accumulating a stale executable permission.
# Steps: Arrange a same-root obsolete entrypoint grant; Act by installing; Assert
# only current manifest-derived Adapter grants remain while unrelated grants survive.
test_install_dispatch_allowlist_prunes_same_checkout_old_entrypoint() {
  local name="test_install_dispatch_allowlist_prunes_same_checkout_old_entrypoint"
  should_run "$name" || return 0
  local home="$tmp_root/$name" settings="$tmp_root/$name/.claude/settings.json"
  local stale="Bash($REPO_ROOT/adapters/codex/old-dispatch.sh:*)"
  mkdir -p "$home/.claude"
  jq -n --arg stale "$stale" '{permissions:{allow:[$stale,"Bash(echo:*)"]}}' > "$settings"

  HOME="$home" CLAUDE_CONFIG_TEST_INSTALL_RUNNING=1 \
    CLAUDE_CONFIG_TEST_PREFLIGHT_HOME="$REAL_HOME" \
    bash "$REPO_ROOT/install.sh" >/dev/null 2>&1

  if jq -e --arg stale "$stale" --arg current "Bash($REPO_ROOT/adapters/codex/dispatch.sh:*)" '
      (.permissions.allow | index($stale)) == null and
      (.permissions.allow | index($current)) != null and
      (.permissions.allow | index("Bash(echo:*)")) != null
    ' "$settings" >/dev/null; then
    pass "$name"
  else
    fail "$name" "stale same-checkout entrypoint grant survived: $(jq -c . "$settings")"
  fi
}

test_dispatch_allowlist_lib_parity() {
  local name="test_dispatch_allowlist_lib_parity"
  should_run "$name" || return 0
  # Verifies that runtime/lib/allowlist.sh dispatch_allowlist_entries() produces
  # the same entries as the test helper dispatch_allowlist_entries_for_home()
  # for the same home directory, proving they share one source of truth.
  # Entry count is dynamic (pmctl entries + one pair per manifest entrypoint).
  local parity_home="$tmp_root/parity-home"
  mkdir -p "$parity_home"

  local from_lib from_helper
  from_lib="$(REPO_ROOT="$REPO_ROOT" HOME="$parity_home" bash -c \
    '. "$1/runtime/lib/allowlist.sh"; dispatch_allowlist_entries' \
    _ "$REPO_ROOT")"
  from_helper="$(dispatch_allowlist_entries_for_home "$parity_home")"

  if [[ "$from_lib" == "$from_helper" ]]; then
    pass "$name"
  else
    fail "$name" "lib output:\n$from_lib\nhelper output:\n$from_helper"
  fi
}

test_dispatch_allowlist_uninstall_removes_entries() {
  # Verifies uninstall-guards.sh removes all four dispatch Bash allowlist
  # entries while leaving unrelated permissions.allow entries intact.
  #
  # Steps:
  #   1. Run install.sh to populate the four allowlist entries.
  #   2. Manually inject an unrelated allow entry.
  #   3. Run uninstall-guards.sh.
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

  HOME="$home" bash "$REPO_ROOT/scripts/uninstall-guards.sh" > /dev/null

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
  #   3. Run uninstall-guards.sh --dry-run.
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

  HOME="$home" bash "$REPO_ROOT/scripts/uninstall-guards.sh" --dry-run > /dev/null

  after="$(md5sum "$settings" | awk '{print $1}')"
  if [[ "$before" != "$after" ]]; then
    fail "$name" "settings.json was modified by --dry-run"
    return
  fi
  pass "$name"
}

# ── CC-334: reviewer permissions merge ──────────────────────────────────────

test_install_hooks_gate_perms_fresh() {
  # Fresh settings gains the three CC-334 permissions.allow entries when
  # PM_DISPATCH_GATE_WORKSPACE is set to a known path.
  local name="install-guards-gate-perms-fresh"
  should_run "$name" || return 0
  local home="$tmp_root/$name"
  local settings="$home/.claude/settings.json"
  local ws="$tmp_root/$name-ws"
  mkdir -p "$home/.claude" "$ws"
  printf '{"hooks":{}}\n' > "$settings"

  HOME="$home" CLAUDE_HOME="$home/.claude" \
    PM_DISPATCH_GATE_WORKSPACE="$ws" \
    bash "$REPO_ROOT/scripts/install-guards.sh" >/dev/null 2>&1

  local edit_entry="Edit(${ws}/**/.gate-results/**)"
  for entry in "$edit_entry" "Bash(pmctl guard check:*)" \
      "Bash($home/.local/bin/pmctl guard check:*)" \
      "Bash(~/.local/bin/pmctl guard check:*)" "Bash(mkdir -p:*)"; do
    if ! jq -e --arg e "$entry" '(.permissions.allow // [] | index($e)) != null' "$settings" >/dev/null; then
      fail "$name" "missing permissions.allow entry: $entry"
      return
    fi
  done
  pass "$name"
}

test_install_hooks_gate_perms_idempotent() {
  # Re-running install-guards.sh does not duplicate the three CC-334 entries.
  local name="install-guards-gate-perms-idempotent"
  should_run "$name" || return 0
  local home="$tmp_root/$name"
  local settings="$home/.claude/settings.json"
  local ws="$tmp_root/$name-ws"
  mkdir -p "$home/.claude" "$ws"
  printf '{"hooks":{}}\n' > "$settings"

  HOME="$home" CLAUDE_HOME="$home/.claude" PM_DISPATCH_GATE_WORKSPACE="$ws" \
    bash "$REPO_ROOT/scripts/install-guards.sh" >/dev/null 2>&1
  HOME="$home" CLAUDE_HOME="$home/.claude" PM_DISPATCH_GATE_WORKSPACE="$ws" \
    bash "$REPO_ROOT/scripts/install-guards.sh" >/dev/null 2>&1

  local edit_entry="Edit(${ws}/**/.gate-results/**)"
  local count
  for entry in "$edit_entry" "Bash(pmctl guard check:*)" \
      "Bash($home/.local/bin/pmctl guard check:*)" \
      "Bash(~/.local/bin/pmctl guard check:*)" "Bash(mkdir -p:*)"; do
    count="$(jq -r --arg e "$entry" '[.permissions.allow[]? | select(. == $e)] | length' "$settings")"
    if [[ "$count" != "1" ]]; then
      fail "$name" "expected 1 copy of '$entry', got $count"
      return
    fi
  done
  pass "$name"
}

test_install_hooks_gate_perms_migrates_legacy_write() {
  # Verifies an upgrade replaces the historical managed Write spelling with
  # Edit while leaving non-managed /tmp permissions untouched.
  # Steps:
  #   1. Seed legacy Write(.gate-results), Edit(/tmp/*), and Write(/tmp/*)
  #   2. Run install-guards.sh once
  #   3. Assert only the managed gate permission is migrated
  local name="install-guards-gate-perms-migrates-legacy-write"
  should_run "$name" || return 0
  local home="$tmp_root/$name" settings="$tmp_root/$name/.claude/settings.json"
  local ws="$tmp_root/$name-ws"
  mkdir -p "$home/.claude" "$ws"
  jq -n --arg legacy "Write(${ws}/**/.gate-results/**)" '{
    hooks:{}, permissions:{allow:[$legacy,"Edit(/tmp/*)","Write(/tmp/*)"]}
  }' > "$settings"

  HOME="$home" CLAUDE_HOME="$home/.claude" PM_DISPATCH_GATE_WORKSPACE="$ws" \
    bash "$REPO_ROOT/scripts/install-guards.sh" >/dev/null 2>&1

  if ! jq -e --arg edit "Edit(${ws}/**/.gate-results/**)" \
      --arg legacy "Write(${ws}/**/.gate-results/**)" '
    (.permissions.allow | index($edit)) != null and
    (.permissions.allow | index($legacy)) == null and
    (.permissions.allow | index("Edit(/tmp/*)")) != null and
    (.permissions.allow | index("Write(/tmp/*)")) != null
  ' "$settings" >/dev/null; then
    fail "$name" "managed gate permission was not migrated without touching /tmp entries"
    return
  fi
  pass "$name"
}

test_install_hooks_gate_perms_dry_run() {
  # --dry-run shows a diff but does not mutate settings.json.
  local name="install-guards-gate-perms-dry-run"
  should_run "$name" || return 0
  local home="$tmp_root/$name"
  local settings="$home/.claude/settings.json"
  local ws="$tmp_root/$name-ws"
  mkdir -p "$home/.claude" "$ws"
  printf '{"hooks":{}}\n' > "$settings"
  local before after
  before="$(md5sum "$settings" | awk '{print $1}')"

  CLAUDE_HOME="$home/.claude" PM_DISPATCH_GATE_WORKSPACE="$ws" \
    bash "$REPO_ROOT/scripts/install-guards.sh" --dry-run >/dev/null 2>&1

  after="$(md5sum "$settings" | awk '{print $1}')"
  if [[ "$before" != "$after" ]]; then
    fail "$name" "settings.json was modified by --dry-run"
    return
  fi
  pass "$name"
}

test_install_hooks_gate_perms_preserves_existing() {
  # Existing unrelated permissions.allow entries survive the CC-334 merge.
  local name="install-guards-gate-perms-preserves-existing"
  should_run "$name" || return 0
  local home="$tmp_root/$name"
  local settings="$home/.claude/settings.json"
  local ws="$tmp_root/$name-ws"
  mkdir -p "$home/.claude" "$ws"
  printf '{"hooks":{},"permissions":{"allow":["Bash(git status:*)","Read(/tmp/*)"]}}\n' > "$settings"

  CLAUDE_HOME="$home/.claude" PM_DISPATCH_GATE_WORKSPACE="$ws" \
    bash "$REPO_ROOT/scripts/install-guards.sh" >/dev/null 2>&1

  for pre_entry in "Bash(git status:*)" "Read(/tmp/*)"; do
    if ! jq -e --arg e "$pre_entry" '(.permissions.allow // [] | index($e)) != null' "$settings" >/dev/null; then
      fail "$name" "pre-existing entry was removed: $pre_entry"
      return
    fi
  done
  pass "$name"
}

test_install_hooks_gate_perms_workspace_override() {
  # PM_DISPATCH_GATE_WORKSPACE is honoured verbatim — the Edit glob uses the
  # override path, not the auto-detected repo parent.
  local name="install-guards-gate-perms-workspace-override"
  should_run "$name" || return 0
  local home="$tmp_root/$name"
  local settings="$home/.claude/settings.json"
  local custom_ws="/custom/tooling/workspace"
  mkdir -p "$home/.claude"
  printf '{"hooks":{}}\n' > "$settings"

  CLAUDE_HOME="$home/.claude" PM_DISPATCH_GATE_WORKSPACE="$custom_ws" \
    bash "$REPO_ROOT/scripts/install-guards.sh" >/dev/null 2>&1

  local expected="Edit(${custom_ws}/**/.gate-results/**)"
  if ! jq -e --arg e "$expected" '(.permissions.allow // [] | index($e)) != null' "$settings" >/dev/null; then
    fail "$name" "Edit glob did not use PM_DISPATCH_GATE_WORKSPACE; expected: $expected"
    return
  fi
  pass "$name"
}

test_install_hooks_gate_perms_home_fallback() {
  # When the auto-detected git root's parent equals HOME, the Edit glob falls
  # back to $HOME/**/.gate-results/**. Uses PM_DISPATCH_GATE_GIT_ROOT to inject a
  # fake git root whose parent is the test HOME, exercising the real fallback branch.
  local name="install-guards-gate-perms-home-fallback"
  should_run "$name" || return 0
  local home="$tmp_root/$name"
  local settings="$home/.claude/settings.json"
  mkdir -p "$home/.claude"
  printf '{"hooks":{}}\n' > "$settings"

  # dirname("$home/fake-pm") == "$home" == $HOME → triggers HOME fallback
  HOME="$home" CLAUDE_HOME="$home/.claude" PM_DISPATCH_GATE_GIT_ROOT="$home/fake-pm" \
    bash "$REPO_ROOT/scripts/install-guards.sh" >/dev/null 2>&1

  local expected="Edit(${home}/**/.gate-results/**)"
  if ! jq -e --arg e "$expected" '(.permissions.allow // [] | index($e)) != null' "$settings" >/dev/null; then
    fail "$name" "Edit glob did not use HOME fallback; expected: $expected"
    return
  fi
  pass "$name"
}

test_install_hooks_gate_perms_git_failure_fallback() {
  # When git rev-parse fails (non-git install, tarball), workspace root falls
  # back to $HOME. Uses PM_DISPATCH_GATE_GIT_ROOT="" to simulate git failure.
  local name="install-guards-gate-perms-git-failure-fallback"
  should_run "$name" || return 0
  local home="$tmp_root/$name"
  local settings="$home/.claude/settings.json"
  mkdir -p "$home/.claude"
  printf '{"hooks":{}}\n' > "$settings"

  HOME="$home" CLAUDE_HOME="$home/.claude" PM_DISPATCH_GATE_GIT_ROOT="" \
    bash "$REPO_ROOT/scripts/install-guards.sh" >/dev/null 2>&1

  local expected="Edit(${home}/**/.gate-results/**)"
  if ! jq -e --arg e "$expected" '(.permissions.allow // [] | index($e)) != null' "$settings" >/dev/null; then
    fail "$name" "Edit glob did not fall back to HOME on git failure; expected: $expected"
    return
  fi
  pass "$name"
}

test_install_hooks_gate_perms_normal_git_parent() {
  # Normal path: git rev-parse succeeds, parent is not HOME → workspace root is
  # the parent directory. Uses PM_DISPATCH_GATE_GIT_ROOT to inject a fake git
  # root under a non-HOME subdirectory, exercising the main auto-detection branch.
  local name="install-guards-gate-perms-normal-git-parent"
  should_run "$name" || return 0
  local home="$tmp_root/$name"
  local settings="$home/.claude/settings.json"
  # Fake git root: "$home/projects/pm-dispatch" → parent = "$home/projects" (not HOME)
  local fake_ws="$home/projects"
  local fake_git_root="$fake_ws/pm-dispatch"
  mkdir -p "$home/.claude" "$fake_ws"
  printf '{"hooks":{}}\n' > "$settings"

  HOME="$home" CLAUDE_HOME="$home/.claude" PM_DISPATCH_GATE_GIT_ROOT="$fake_git_root" \
    bash "$REPO_ROOT/scripts/install-guards.sh" >/dev/null 2>&1

  local expected="Edit(${fake_ws}/**/.gate-results/**)"
  if ! jq -e --arg e "$expected" '(.permissions.allow // [] | index($e)) != null' "$settings" >/dev/null; then
    fail "$name" "Edit glob did not use git-parent workspace; expected: $expected"
    return
  fi
  pass "$name"
}

test_install_hooks_gate_perms_uninstall_removes() {
  # Lifecycle: uninstall-guards.sh removes the three CC-334 permissions entries
  # that install-guards.sh added, and leaves unrelated entries intact.
  local name="install-guards-gate-perms-uninstall-removes"
  should_run "$name" || return 0
  local home="$tmp_root/$name"
  local settings="$home/.claude/settings.json"
  local ws="$tmp_root/$name-ws"
  mkdir -p "$home/.claude" "$ws"
  printf '{"hooks":{},"permissions":{"allow":["Bash(git log:*)","Edit(/tmp/*)"]}}\n' > "$settings"

  # Install
  HOME="$home" CLAUDE_HOME="$home/.claude" PM_DISPATCH_GATE_WORKSPACE="$ws" \
    bash "$REPO_ROOT/scripts/install-guards.sh" >/dev/null 2>&1

  local edit_entry="Edit(${ws}/**/.gate-results/**)"
  if ! jq -e --arg e "$edit_entry" '(.permissions.allow // [] | index($e)) != null' "$settings" >/dev/null; then
    fail "$name" "install did not add Edit entry; cannot test lifecycle"
    return
  fi
  # Simulate an older install artifact coexisting with the current spelling;
  # uninstall must recognize and remove both.
  jq --arg legacy "Write(${ws}/**/.gate-results/**)" \
    '.permissions.allow += [$legacy]' "$settings" > "$settings.tmp"
  mv "$settings.tmp" "$settings"

  # Uninstall
  HOME="$home" CLAUDE_HOME="$home/.claude" PM_DISPATCH_GATE_WORKSPACE="$ws" \
    bash "$REPO_ROOT/scripts/uninstall-guards.sh" >/dev/null 2>&1

  for entry in "$edit_entry" "Write(${ws}/**/.gate-results/**)" "Bash(pmctl guard check:*)" \
      "Bash($home/.local/bin/pmctl guard check:*)" \
      "Bash(~/.local/bin/pmctl guard check:*)" "Bash(mkdir -p:*)"; do
    if jq -e --arg e "$entry" '(.permissions.allow // [] | index($e)) != null' "$settings" >/dev/null; then
      fail "$name" "entry should be removed after uninstall: $entry"
      return
    fi
  done
  # Unrelated entry must survive
  if ! jq -e --arg e "Bash(git log:*)" '(.permissions.allow // [] | index($e)) != null' "$settings" >/dev/null; then
    fail "$name" "unrelated permissions.allow entry was incorrectly removed"
    return
  fi
  if ! jq -e --arg e "Edit(/tmp/*)" '(.permissions.allow // [] | index($e)) != null' "$settings" >/dev/null; then
    fail "$name" "non-managed /tmp permission was incorrectly removed"
    return
  fi
  pass "$name"
}

test_install_hooks_windows_profile_full_downgrades_to_minimal() {
  # Proves PM_DISPATCH_PLATFORM=windows and --profile full downgrades to minimal.
  # Codex hooks are not wired; base managed hooks still are. The expected warning
  # about fallback to minimal is also required.
  local name="install-guards-windows-full-downgraded-to-minimal"
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
    bash "$REPO_ROOT/scripts/install-guards.sh" --profile full >"$out" 2>"$err"
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

  assert_file_contains "$name" "$home/.claude/settings.json" "guard-pm-write.sh" || return
  assert_not_contains "$name" "$home/.claude/settings.json" "$_TI_RETIRED_TRACE" || return
  assert_not_contains "$name" "$home/.claude/settings.json" "$_TI_RETIRED_ROUTING" || return
  assert_file_contains "$name" "$home/.claude/settings.json" "hosts/claude/hooks/log-usage.sh" || return
  assert_not_contains "$name" "$home/.claude/settings.json" "guard-session-summary.sh" || return
  assert_not_contains "$name" "$home/.claude/settings.json" "hook-codex-bash-guard.sh" || return
  assert_not_contains "$name" "$home/.claude/settings.json" "adapters/codex/bash-guard.sh" || return
  pass "$name"
}

test_install_hooks_windows_profile_minimal_silent() {
  # Proves PM_DISPATCH_PLATFORM=windows and --profile minimal does not emit the
  # full-profile downgrade warning and does not wire codex hooks.
  local name="install-guards-windows-minimal-silent"
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
    bash "$REPO_ROOT/scripts/install-guards.sh" --profile minimal >"$out" 2>"$err"
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

  assert_file_contains "$name" "$home/.claude/settings.json" "guard-pm-write.sh" || return
  assert_not_contains "$name" "$home/.claude/settings.json" "$_TI_RETIRED_TRACE" || return
  assert_not_contains "$name" "$home/.claude/settings.json" "$_TI_RETIRED_ROUTING" || return
  assert_file_contains "$name" "$home/.claude/settings.json" "hosts/claude/hooks/log-usage.sh" || return
  assert_not_contains "$name" "$home/.claude/settings.json" "guard-session-summary.sh" || return
  assert_not_contains "$name" "$home/.claude/settings.json" "hook-codex-bash-guard.sh" || return
  assert_not_contains "$name" "$home/.claude/settings.json" "guard-executor-write.sh" || return
  pass "$name"
}

test_install_hooks_orphan_cleanup_removes_retired_adapter_guard() {
  # Regression for the codex-executor retirement: a settings.json left over from
  # a prior install that still wires adapters/codex/bash-guard.sh (now a deleted
  # file) must have that orphaned PreToolUse Bash entry pruned on the next
  # install-guards run, regardless of profile — no adapter manifest declares a
  # bash guard anymore, so the manifest-driven orphan cleanup removes it. Other
  # managed hooks must survive.
  local name="install-guards-orphan-cleanup-removes-retired-adapter-guard"
  should_run "$name" || return 0
  local home="$tmp_root/$name"
  mkdir -p "$home/.claude"
  # Seed a settings.json that still wires a now-retired adapter bash guard.
  cat > "$home/.claude/settings.json" <<'EOF'
{
  "permissions": {},
  "hooks": {
    "PreToolUse": [
      {"matcher": "Bash", "hooks": [{"type": "command", "command": "/repo/adapters/codex/bash-guard.sh"}]}
    ]
  }
}
EOF

  HOME="$home" bash "$REPO_ROOT/scripts/install-guards.sh" --profile full > /dev/null
  assert_not_contains "$name" "$home/.claude/settings.json" "adapters/codex/bash-guard.sh" || return
  assert_not_contains "$name" "$home/.claude/settings.json" "hook-codex-bash-guard.sh" || return
  # The other managed hooks must still be present after cleanup.
  assert_file_contains "$name" "$home/.claude/settings.json" "guard-pm-write.sh" || return
  assert_file_contains "$name" "$home/.claude/settings.json" "guard-inject-memory.sh" || return
  assert_file_contains "$name" "$home/.claude/settings.json" "inject-context.sh" || return
  pass "$name"
}

test_install_hooks_auto_detect_with_codex_wires_full() {
  # Proves omitted --profile flag + codex on PATH resolves to the full profile
  # and installs cleanly. No adapter ships a bash guard (codex's was retired),
  # so full wires the managed hooks but no adapter bash guard. Uses a stub codex
  # binary so the test does not depend on the host having codex installed.
  local name="install-guards-auto-detect-codex-present-wires-full"
  should_run "$name" || return 0
  local home="$tmp_root/$name"
  mkdir -p "$home/.claude"
  printf '{"permissions":{}}\n' > "$home/.claude/settings.json"

  local stub_bin="$home/.stub-bin"
  mkdir -p "$stub_bin"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$stub_bin/codex"
  chmod +x "$stub_bin/codex"

  HOME="$home" PATH="$stub_bin:$PATH" \
    bash "$REPO_ROOT/scripts/install-guards.sh" > /dev/null

  assert_file_contains "$name" "$home/.claude/settings.json" "guard-pm-write.sh" || return
  assert_not_contains "$name" "$home/.claude/settings.json" "adapters/codex/bash-guard.sh" || return
  pass "$name"
}

test_install_hooks_auto_detect_without_codex_wires_minimal() {
  # Proves omitted --profile flag + codex absent from PATH resolves to
  # minimal (skips codex-* guards). Uses a minimal PATH that excludes
  # any user-local bin dirs where codex might live.
  local name="install-guards-auto-detect-codex-absent-wires-minimal"
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
    fail "$name" "precondition failed: jq missing from minimal PATH (install-guards.sh needs it)"
    return
  fi

  HOME="$home" PATH="$minimal_path" \
    bash "$REPO_ROOT/scripts/install-guards.sh" > /dev/null

  assert_not_contains "$name" "$home/.claude/settings.json" "hook-codex-bash-guard.sh" || return
  assert_not_contains "$name" "$home/.claude/settings.json" "adapters/codex/bash-guard.sh" || return
  assert_file_contains "$name" "$home/.claude/settings.json" "guard-pm-write.sh" || return
  pass "$name"
}

test_install_hooks_dry_run_does_not_modify() {
  # Proves --dry-run prints a diff but does not modify settings.json.
  local name="install-guards-dry-run-does-not-modify-settings"
  should_run "$name" || return 0
  local home="$tmp_root/$name"
  mkdir -p "$home/.claude"
  printf '{"permissions":{}}\n' > "$home/.claude/settings.json"
  local before_hash
  before_hash="$(sha256sum < "$home/.claude/settings.json" | awk '{print $1}')"

  HOME="$home" bash "$REPO_ROOT/scripts/install-guards.sh" --dry-run --profile minimal > /dev/null

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
  local name="install-guards-platform-linux-explicit-wires-normally"
  should_run "$name" || return 0
  local home="$tmp_root/$name"
  mkdir -p "$home/.claude"
  printf '{"permissions":{}}\n' > "$home/.claude/settings.json"

  HOME="$home" bash "$REPO_ROOT/scripts/install-guards.sh" --platform linux --profile full > /dev/null

  assert_file_contains "$name" "$home/.claude/settings.json" "guard-pm-write.sh" || return
  assert_not_contains "$name" "$home/.claude/settings.json" "adapters/codex/bash-guard.sh" || return
  pass "$name"
}

test_install_hooks_platform_invalid_value_rejected() {
  # Proves --platform with an unknown value is rejected with exit 2.
  local name="install-guards-platform-invalid-value-rejected"
  should_run "$name" || return 0
  local home="$tmp_root/$name"
  mkdir -p "$home/.claude"
  printf '{"permissions":{}}\n' > "$home/.claude/settings.json"

  local out rc
  out="$(HOME="$home" bash "$REPO_ROOT/scripts/install-guards.sh" --platform xtreme 2>&1)" && rc=0 || rc=$?
  if [[ $rc -ne 0 ]] && [[ "$out" == *"platform"* ]]; then
    pass "$name"
  else
    fail "$name" "expected non-zero exit and 'platform' in stderr; got rc=$rc, out=$out"
  fi
}

test_install_hooks_profile_invalid_value_rejected() {
  # Proves install-guards.sh rejects an unknown profile value with exit 2
  # and a clear stderr message.
  local name="install-guards-profile-invalid-value-rejected"
  should_run "$name" || return 0
  local home="$tmp_root/$name"
  mkdir -p "$home/.claude"
  printf '{"permissions":{}}\n' > "$home/.claude/settings.json"

  local out rc
  out="$(HOME="$home" bash "$REPO_ROOT/scripts/install-guards.sh" --profile bogus 2>&1)" && rc=0 || rc=$?
  if [[ $rc -ne 0 ]] && [[ "$out" == *"profile"* ]] && [[ "$out" == *"minimal or full"* ]]; then
    pass "$name"
  else
    fail "$name" "expected non-zero exit and 'minimal or full' in stderr; got rc=$rc, out=$out"
  fi
}

test_install_hooks_jq_missing_prints_platform_hints() {
  # Proves install-guards.sh exits non-zero with platform-aware install
  # hints (winget / brew / apt / etc.) when jq is missing on PATH.
  # Stub PATH must contain the small set of utilities the script uses
  # before its jq check (cd / dirname / uname / command / cat etc.); we
  # symlink them from the live PATH into stub_bin, excluding jq.
  local name="install-guards-jq-missing-prints-platform-hints"
  should_run "$name" || return 0
  # The artificial stub PATH (only a few coreutils, no jq) prevents install-guards.sh
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
  out="$(HOME="$home" PATH="$stub_bin" /bin/bash "$REPO_ROOT/scripts/install-guards.sh" 2>&1)" && rc=0 || rc=$?
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
  # create a minimal settings.json and wire the managed hooks. No adapter ships
  # a bash guard (codex's was retired), so none is wired.
  local name="install-sh-wires-hooks-no-settings"
  should_run "$name" || return 0
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
  assert_file_contains "$name" "$home/.claude/settings.json" "guard-pm-write.sh" || return
  assert_not_contains "$name" "$home/.claude/settings.json" "adapters/codex/bash-guard.sh" || return
  assert_not_contains "$name" "$home/.claude/settings.json" "$_TI_RETIRED_TRACE" || return
  assert_file_contains "$name" "$home/.claude/settings.json" "hosts/claude/hooks/log-usage.sh" || return
  assert_not_contains "$name" "$home/.claude/settings.json" "$_TI_RETIRED_ROUTING" || return
  assert_file_contains "$name" "$home/.claude/settings.json" "guard-inject-memory.sh" || return
  assert_file_contains "$name" "$home/.claude/settings.json" "inject-context.sh" || return
  assert_file_contains "$name" "$home/.claude/settings.json" "hosts/claude/hooks/save-rate-limits.sh" || return
  pass "$name"
}

test_hooks_install_uninstall_lifecycle() {
  local name="hooks-install-uninstall-lifecycle"
  should_run "$name" || return 0
  local home="$tmp_root/$name"
  mkdir -p "$home/.claude"
  printf '{"permissions":{}}\n' > "$home/.claude/settings.json"

  HOME="$home" bash "$REPO_ROOT/scripts/install-guards.sh" --profile full > /dev/null
  assert_file_contains "$name" "$home/.claude/settings.json" "guard-pm-write.sh" || return
  assert_not_contains "$name" "$home/.claude/settings.json" "adapters/codex/bash-guard.sh" || return
  assert_not_contains "$name" "$home/.claude/settings.json" "$_TI_RETIRED_TRACE" || return
  assert_file_contains "$name" "$home/.claude/settings.json" "hosts/claude/hooks/log-usage.sh" || return
  assert_not_contains "$name" "$home/.claude/settings.json" "$_TI_RETIRED_ROUTING" || return
  assert_file_contains "$name" "$home/.claude/settings.json" "guard-inject-memory.sh" || return
  assert_file_contains "$name" "$home/.claude/settings.json" "inject-context.sh" || return
  assert_file_contains "$name" "$home/.claude/settings.json" "hosts/claude/hooks/save-rate-limits.sh" || return

  HOME="$home" bash "$REPO_ROOT/scripts/uninstall-guards.sh" > /dev/null
  assert_not_contains "$name" "$home/.claude/settings.json" "guard-pm-write.sh" || return
  assert_not_contains "$name" "$home/.claude/settings.json" "adapters/codex/bash-guard.sh" || return
  assert_not_contains "$name" "$home/.claude/settings.json" "hook-codex-bash-guard.sh" || return
  assert_not_contains "$name" "$home/.claude/settings.json" "$_TI_RETIRED_TRACE" || return
  assert_not_contains "$name" "$home/.claude/settings.json" "hosts/claude/hooks/log-usage.sh" || return
  assert_not_contains "$name" "$home/.claude/settings.json" "$_TI_RETIRED_ROUTING" || return
  assert_not_contains "$name" "$home/.claude/settings.json" "guard-inject-memory.sh" || return
  assert_not_contains "$name" "$home/.claude/settings.json" "inject-context.sh" || return
  assert_not_contains "$name" "$home/.claude/settings.json" "hosts/claude/hooks/save-rate-limits.sh" || return
  if jq -e 'has("statusLine")' "$home/.claude/settings.json" >/dev/null; then
    fail "$name" "statusLine should be deleted when no chain target exists"
    return
  fi

  pass "$name"
}

test_uninstall_hooks_removes_unlisted_hooks() {
  # Verifies that uninstall-guards.sh removes hooks that were NOT in the old
  # hardcoded removal list.
  #
  # Steps:
  #   1. Write settings.json with retired PreToolUse and PostToolUse hooks.
  #   2. Run uninstall-guards.sh.
  #   3. Assert both hooks are gone and no hooks block remains.
  local name="uninstall-guards-removes-unlisted-hooks"
  should_run "$name" || return 0
  local home="$tmp_root/$name"
  mkdir -p "$home/.claude"
  local _tt_cmd _rl_cmd
  _tt_cmd="$(_ti_hook_cmd_path "$REPO_ROOT/scripts/$_TI_RETIRED_TRACE")"
  _rl_cmd="$(_ti_hook_cmd_path "$REPO_ROOT/scripts/$_TI_RETIRED_ROUTING")"
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

  HOME="$home" bash "$REPO_ROOT/scripts/uninstall-guards.sh" > /dev/null

  assert_not_contains "$name" "$home/.claude/settings.json" "$_TI_RETIRED_TRACE" || return
  assert_not_contains "$name" "$home/.claude/settings.json" "$_TI_RETIRED_ROUTING" || return
  if jq -e 'has("hooks")' "$home/.claude/settings.json" >/dev/null 2>&1; then
    fail "$name" "hooks block should be absent after full removal"
    return
  fi
  pass "$name"
}

test_install_hooks_prunes_retired_hooks() {
  # Verifies that re-running install-guards.sh on an existing install removes
  # retired hook registrations while preserving the rest of the managed hook set.
  #
  # Steps:
  #   1. Write settings.json with retired hooks plus active hook registrations.
  #   2. Run install-guards.sh.
  #   3. Assert retired hooks are absent and active hooks remain present.
  local name="install-guards-prunes-retired-hooks"
  should_run "$name" || return 0
  local home="$tmp_root/$name"
  mkdir -p "$home/.claude"
  local _tt_cmd _rl_cmd
  _tt_cmd="$(_ti_hook_cmd_path "$REPO_ROOT/scripts/$_TI_RETIRED_TRACE")"
  _rl_cmd="$(_ti_hook_cmd_path "$REPO_ROOT/scripts/$_TI_RETIRED_ROUTING")"
  cat > "$home/.claude/settings.json" <<JSON
{
  "hooks": {
    "PreToolUse": [
      {"matcher": "Edit|Write", "hooks": [{"type": "command", "command": "$REPO_ROOT/runtime/hooks/guard-pm-write.sh"}]},
      {"matcher": "Edit|Write", "hooks": [{"type": "command", "command": "$REPO_ROOT/scripts/$_TI_RETIRED_CODEX_WRITE"}]},
      {"matcher": "Bash", "hooks": [{"type": "command", "command": "$REPO_ROOT/scripts/hook-codex-bash-guard.sh"}]},
      {"matcher": "Bash", "hooks": [{"type": "command", "command": "$REPO_ROOT/adapters/codex/bash-guard.sh"}]},
      {"matcher": "*", "hooks": [{"type": "command", "command": "$_tt_cmd"}]}
    ],
    "PostToolUse": [
      {"matcher": "Bash|Agent", "hooks": [{"type": "command", "command": "$_rl_cmd"}]}
    ],
    "Stop": [
      {"hooks": [{"type": "command", "command": "$REPO_ROOT/scripts/guard-log-claude-usage.sh"}]},
      {"hooks": [{"type": "command", "command": "$REPO_ROOT/runtime/hooks/guard-session-summary.sh"}]}
    ],
    "UserPromptSubmit": [
      {"hooks": [{"type": "command", "command": "$REPO_ROOT/runtime/hooks/guard-inject-memory.sh"}]}
    ]
  },
  "statusLine": {"command": "$REPO_ROOT/scripts/guard-save-rate-limits.sh"}
}
JSON

  HOME="$home" bash "$REPO_ROOT/scripts/install-guards.sh" --profile full > /dev/null

  assert_not_contains "$name" "$home/.claude/settings.json" "$_TI_RETIRED_TRACE" || return
  assert_not_contains "$name" "$home/.claude/settings.json" "$_TI_RETIRED_ROUTING" || return
  assert_not_contains "$name" "$home/.claude/settings.json" "$_TI_RETIRED_CODEX_WRITE" || return
  # Both forms of the retired codex bash guard are pruned: the legacy scripts/
  # form, and the adapters/codex/ form orphaned by the codex-executor retirement
  # (no adapter manifest declares a bash guard anymore).
  assert_not_contains "$name" "$home/.claude/settings.json" "hook-codex-bash-guard.sh" || return
  assert_not_contains "$name" "$home/.claude/settings.json" "adapters/codex/bash-guard.sh" || return
  assert_file_contains "$name" "$home/.claude/settings.json" "guard-pm-write.sh" || return
  assert_file_contains "$name" "$home/.claude/settings.json" "hosts/claude/hooks/log-usage.sh" || return
  assert_not_contains "$name" "$home/.claude/settings.json" "guard-session-summary.sh" || return
  assert_file_contains "$name" "$home/.claude/settings.json" "guard-inject-memory.sh" || return
  # CC-566 (gate finding qa-tester-F001): the bare pre-existing memory hook
  # command seeded above must be rewritten to the exact `--host claude` form,
  # not left as the stale bare command or duplicated alongside it.
  local _cc566_inject_expect _cc566_mem_hooks
  _cc566_inject_expect="$(_ti_claude_inject_hook_cmd)"
  _cc566_mem_hooks="$(jq -c '[.hooks.UserPromptSubmit[]? | (.hooks // [])[]? | select((.command | type) == "string" and (.command | test("guard-inject-memory\\.sh")))]' "$home/.claude/settings.json" 2>/dev/null)"
  if ! jq -e --arg inject "$_cc566_inject_expect" \
    '(length == 1) and (.[0].command == $inject)' \
    <<<"$_cc566_mem_hooks" >/dev/null; then
    fail "$name" "expected exactly one memory hook rewritten to '$_cc566_inject_expect', got: $_cc566_mem_hooks"
    return
  fi
  assert_file_contains "$name" "$home/.claude/settings.json" "inject-context.sh" || return
  assert_file_contains "$name" "$home/.claude/settings.json" "hosts/claude/hooks/save-rate-limits.sh" || return
  pass "$name"
}

test_install_hooks_updates_stale_paths_after_rename() {
  # Verifies that install-guards.sh updates stale full-paths (e.g. from a repo
  # rename claude-config -> pm-dispatch) without creating duplicate entries.
  #
  # Steps:
  #   1. Create settings.json pre-populated with hooks pointing at /fake/old-repo/scripts/
  #   2. Run install-guards.sh (current repo_root)
  #   3. Assert each hook appears exactly once and with the current path
  local name="install-guards-updates-stale-paths-after-rename"
  should_run "$name" || return 0
  local home="$tmp_root/$name"
  mkdir -p "$home/.claude"

  # Simulate settings.json left over from old repo path. The managed hooks must
  # have their paths refreshed to the current repo root without duplication.
  cat > "$home/.claude/settings.json" <<'JSON'
{
  "permissions": {},
  "hooks": {
    "PreToolUse": [
      {"matcher": "Edit|Write", "hooks": [{"type": "command", "command": "/fake/old-repo/runtime/hooks/guard-pm-write.sh"}]}
    ],
    "Stop": [
      {"hooks": [{"type": "command", "command": "/fake/old-repo/scripts/guard-log-claude-usage.sh"}]},
      {"hooks": [{"type": "command", "command": "/fake/old-repo/runtime/hooks/guard-session-summary.sh"}]}
    ],
    "UserPromptSubmit": [
      {"hooks": [{"type": "command", "command": "/fake/old-repo/runtime/hooks/guard-inject-memory.sh"}]}
    ]
  },
  "statusLine": {"type": "command", "command": "/fake/old-repo/scripts/guard-save-rate-limits.sh"}
}
JSON

  HOME="$home" bash "$REPO_ROOT/scripts/install-guards.sh" > /dev/null

  # Each managed hook basename must appear exactly once (no duplicates)
  local settings="$home/.claude/settings.json"
  for hook in guard-pm-write.sh log-usage.sh \
              guard-inject-memory.sh inject-context.sh save-rate-limits.sh; do
    local count
    count=$(grep -o "$hook" "$settings" | wc -l | tr -d ' ')
    if [[ "$count" -ne 1 ]]; then
      fail "$name" "$hook appears $count times in settings.json (want 1)"
      return
    fi
  done
  # No adapter ships a bash guard, so none should be wired after refresh.
  if grep -q "bash-guard.sh" "$settings"; then
    fail "$name" "no adapter bash guard should be wired, but bash-guard.sh is present"
    return
  fi

  # Old path must be gone; current repo path must be present
  if grep -q "/fake/old-repo/" "$settings"; then
    fail "$name" "stale /fake/old-repo/ path still present after re-install"
    return
  fi
  assert_file_contains "$name" "$settings" "$REPO_ROOT/runtime/hooks/guard-pm-write.sh" || return

  pass "$name"
}

test_install_hooks_preserves_unrelated_same_basename_hook() {
  # Verifies that install-guards.sh does NOT overwrite hooks from unrelated tools
  # that share a managed hook basename but live at a non-standard path (parent
  # directory is not "scripts/"). Such entries must be preserved unchanged.
  #
  # Steps:
  #   1. Create settings.json with an unrelated Stop hook at /some/tool/guard-log-claude-usage.sh
  #      (basename matches managed hook; parent dir is "tool", not "scripts")
  #   2. Run install-guards.sh
  #   3. Assert the unrelated hook is still present at its original path (not overwritten)
  #   4. Assert our managed hook was appended as a separate entry (not collapsed into the unrelated one)
  local name="install-guards-preserves-unrelated-same-basename-hook"
  should_run "$name" || return 0
  local home="$tmp_root/$name"
  mkdir -p "$home/.claude"

  local unrelated_path="/some/unrelated/tool/guard-log-claude-usage.sh"

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

  HOME="$home" bash "$REPO_ROOT/scripts/install-guards.sh" > /dev/null

  local settings="$home/.claude/settings.json"

  # Unrelated hook must still be present at original path
  assert_file_contains "$name" "$settings" "$unrelated_path" || return

  # Our managed hook must also be present (appended, not merged)
  assert_file_contains "$name" "$settings" "hosts/claude/hooks/log-usage.sh" || return

  pass "$name"
}

test_install_hooks_uninstall_stale_paths_after_rename() {
  # Verifies the rename lifecycle: install-guards.sh first refreshes stale
  # managed hook paths, then uninstall-guards.sh removes the refreshed repo-local
  # hooks by repo-root prefix.
  #
  # Steps:
  #   1. Create settings.json with managed hooks at /fake/old-repo/scripts/
  #   2. Run install-guards.sh to refresh paths to the current repo_root
  #   3. Run uninstall-guards.sh
  #   4. Assert all managed hook basenames are gone from settings.json
  local name="install-guards-uninstall-stale-paths-after-rename"
  should_run "$name" || return 0
  local home="$tmp_root/$name"
  mkdir -p "$home/.claude"

  cat > "$home/.claude/settings.json" <<'JSON'
{
  "permissions": {},
  "hooks": {
    "PreToolUse": [
      {"matcher": "Edit|Write", "hooks": [{"type": "command", "command": "/fake/old-repo/runtime/hooks/guard-pm-write.sh"}]},
      {"matcher": "Bash",       "hooks": [{"type": "command", "command": "/fake/old-repo/adapters/codex/bash-guard.sh"}]}
    ],
    "Stop": [
      {"hooks": [{"type": "command", "command": "/fake/old-repo/scripts/guard-log-claude-usage.sh"}]},
      {"hooks": [{"type": "command", "command": "/fake/old-repo/runtime/hooks/guard-session-summary.sh"}]}
    ],
    "UserPromptSubmit": [
      {"hooks": [{"type": "command", "command": "/fake/old-repo/runtime/hooks/guard-inject-memory.sh"}]}
    ]
  },
  "statusLine": {"type": "command", "command": "/fake/old-repo/scripts/guard-save-rate-limits.sh"}
}
JSON

  HOME="$home" bash "$REPO_ROOT/scripts/install-guards.sh" --profile full > /dev/null
  if grep -q "/fake/old-repo/" "$home/.claude/settings.json"; then
    fail "$name" "stale /fake/old-repo/ path still present after re-install"
    return
  fi

  HOME="$home" bash "$REPO_ROOT/scripts/uninstall-guards.sh" > /dev/null

  local settings="$home/.claude/settings.json"

  # All managed hook basenames must be gone after uninstall
  for hook in guard-pm-write.sh log-usage.sh \
              guard-inject-memory.sh inject-context.sh save-rate-limits.sh; do
    if grep -q "$hook" "$settings"; then
      fail "$name" "$hook still present in settings.json after uninstall of stale paths"
      return
    fi
  done
  # adapter bash guard must also be gone
  if grep -q "bash-guard.sh" "$settings"; then
    fail "$name" "bash-guard.sh still present in settings.json after uninstall"
    return
  fi

  # No /fake/old-repo/ paths should remain
  if grep -q "/fake/old-repo/" "$settings"; then
    fail "$name" "stale /fake/old-repo/ path still present after uninstall"
    return
  fi

  pass "$name"
}

test_userpromptsubmit_install_wires_hook() {
  # Verifies install-guards.sh wires guard-inject-memory.sh into UserPromptSubmit.
  # Steps:
  #   1. Create a sandbox settings.json with no hooks
  #   2. Run install-guards.sh directly
  #   3. Assert UserPromptSubmit exists and contains the memory injection hook path
  local name="userpromptsubmit-install-wires-hook"
  should_run "$name" || return 0
  local home="$tmp_root/$name"
  # install-guards writes the native path form (C:/... on Windows); match it.
  # The wired command also carries an explicit `--host claude` (CC-566: gives
  # guard-inject-memory.sh a smaller per-turn budget on Claude, which already
  # gets an unbounded native full-file load once per session).
  local inject ctx_inject
  inject="$(_ti_claude_inject_hook_cmd)"
  ctx_inject="$(_ti_hook_cmd_path "$REPO_ROOT/hosts/claude/hooks/inject-context.sh")"
  mkdir -p "$home/.claude"
  printf '{"permissions":{}}\n' > "$home/.claude/settings.json"

  HOME="$home" bash "$REPO_ROOT/scripts/install-guards.sh" > /dev/null

  assert_file_contains "$name" "$home/.claude/settings.json" "UserPromptSubmit" || return
  assert_file_contains "$name" "$home/.claude/settings.json" "$inject" || return
  if ! jq -e --arg inject "$inject" \
    '.hooks.UserPromptSubmit[]? | (.hooks // [])[]? | select(.command == $inject)' \
    "$home/.claude/settings.json" >/dev/null; then
    fail "$name" "UserPromptSubmit hook command not found"
    return
  fi
  if ! jq -e --arg inject "$ctx_inject" \
    '.hooks.UserPromptSubmit[]? | (.hooks // [])[]? | select(.command == $inject and .timeout == 150)' \
    "$home/.claude/settings.json" >/dev/null; then
    fail "$name" "UserPromptSubmit context hook command/timeout contract not found"
    return
  fi
  pass "$name"
}

test_userpromptsubmit_uninstall_removes_hook() {
  # Verifies uninstall-guards.sh removes the managed UserPromptSubmit hook cleanly.
  # Steps:
  #   1. Create a sandbox settings.json, then run install-guards.sh
  #   2. Run uninstall-guards.sh
  #   3. Assert guard-inject-memory.sh and the UserPromptSubmit key are gone
  local name="userpromptsubmit-uninstall-removes-hook"
  should_run "$name" || return 0
  local home="$tmp_root/$name"
  mkdir -p "$home/.claude"
  printf '{"permissions":{}}\n' > "$home/.claude/settings.json"

  HOME="$home" bash "$REPO_ROOT/scripts/install-guards.sh" > /dev/null
  HOME="$home" bash "$REPO_ROOT/scripts/uninstall-guards.sh" > /dev/null

  assert_not_contains "$name" "$home/.claude/settings.json" "guard-inject-memory.sh" || return
  assert_not_contains "$name" "$home/.claude/settings.json" "inject-context.sh" || return
  if ! jq -e '((.hooks // {}) | has("UserPromptSubmit") | not) or ((.hooks.UserPromptSubmit // []) | length == 0)' \
    "$home/.claude/settings.json" >/dev/null; then
    fail "$name" "UserPromptSubmit should be absent or empty"
    return
  fi
  pass "$name"
}

test_userpromptsubmit_install_idempotent() {
  # Verifies repeated install-guards.sh runs do not duplicate UserPromptSubmit hooks.
  # Steps:
  #   1. Create a sandbox settings.json with no hooks
  #   2. Run install-guards.sh twice
  #   3. Assert exactly one guard-inject-memory.sh command is present
  local name="userpromptsubmit-install-idempotent"
  should_run "$name" || return 0
  local home="$tmp_root/$name"
  local inject ctx_inject
  # CC-566: wired command carries an explicit `--host claude` budget selector.
  inject="$(_ti_claude_inject_hook_cmd)"
  ctx_inject="$(_ti_hook_cmd_path "$REPO_ROOT/hosts/claude/hooks/inject-context.sh")"
  local count
  mkdir -p "$home/.claude"
  printf '{"permissions":{}}\n' > "$home/.claude/settings.json"

  HOME="$home" bash "$REPO_ROOT/scripts/install-guards.sh" > /dev/null
  HOME="$home" bash "$REPO_ROOT/scripts/install-guards.sh" > /dev/null

  count="$(jq --arg inject "$inject" \
    '[.hooks.UserPromptSubmit[]? | (.hooks // [])[]? | select(.command == $inject)] | length' \
    "$home/.claude/settings.json")"
  if [[ "$count" != "1" ]]; then
    fail "$name" "expected one UserPromptSubmit memory hook, got $count"
    return
  fi
  count="$(jq --arg inject "$ctx_inject" \
    '[.hooks.UserPromptSubmit[]? | (.hooks // [])[]? | select(.command == $inject)] | length' \
    "$home/.claude/settings.json")"
  if [[ "$count" != "1" ]]; then
    fail "$name" "expected one UserPromptSubmit context hook, got $count"
    return
  fi
  if ! jq -e --arg inject "$ctx_inject" \
    '.hooks.UserPromptSubmit[]? | (.hooks // [])[]? | select(.command == $inject and .timeout == 150)' \
    "$home/.claude/settings.json" >/dev/null; then
    fail "$name" "expected context hook timeout=150 after repeated install"
    return
  fi
  pass "$name"
}

test_userpromptsubmit_install_upgrades_context_timeout() {
  # Verifies an existing managed context hook is upgraded in place while an
  # unrelated UserPromptSubmit hook keeps its own timeout.
  # Steps:
  #   1. Seed the managed context hook with timeout=30 plus an unrelated hook
  #   2. Run install-guards.sh once
  #   3. Assert managed timeout=150 and unrelated timeout remains unchanged
  local name="userpromptsubmit-install-upgrades-context-timeout"
  should_run "$name" || return 0
  local home="$tmp_root/$name" ctx_inject unrelated
  ctx_inject="$(_ti_hook_cmd_path "$REPO_ROOT/hosts/claude/hooks/inject-context.sh")"
  unrelated="/home/testuser/custom-prompt-hook.sh"
  mkdir -p "$home/.claude"
  jq -n --arg ctx "$ctx_inject" --arg unrelated "$unrelated" '{
    permissions:{}, hooks:{UserPromptSubmit:[
      {hooks:[{type:"command",command:$ctx,timeout:30}]},
      {hooks:[{type:"command",command:$unrelated,timeout:7}]}
    ]}
  }' > "$home/.claude/settings.json"

  HOME="$home" bash "$REPO_ROOT/scripts/install-guards.sh" > /dev/null

  if ! jq -e --arg ctx "$ctx_inject" --arg unrelated "$unrelated" '
    ([.hooks.UserPromptSubmit[]?.hooks[]? | select(.command == $ctx and .timeout == 150)] | length) == 1 and
    ([.hooks.UserPromptSubmit[]?.hooks[]? | select(.command == $unrelated and .timeout == 7)] | length) == 1
  ' "$home/.claude/settings.json" >/dev/null; then
    fail "$name" "managed timeout was not upgraded without changing unrelated hook"
    return
  fi
  pass "$name"
}

test_userpromptsubmit_install_migrates_retired_context_hook() {
  # The context injector moved from the shared runtime directory into the
  # Claude host adapter. Existing settings must lose the retired command rather
  # than execute it alongside the replacement hook.
  local name="userpromptsubmit-install-migrates-retired-context-hook"
  should_run "$name" || return 0
  local home="$tmp_root/$name" retired ctx_inject unrelated
  retired="$(_ti_hook_cmd_path "$REPO_ROOT/runtime/hooks/guard-inject-context.sh")"
  ctx_inject="$(_ti_hook_cmd_path "$REPO_ROOT/hosts/claude/hooks/inject-context.sh")"
  unrelated="/home/testuser/custom-prompt-hook.sh"
  mkdir -p "$home/.claude"
  jq -n --arg retired "$retired" --arg unrelated "$unrelated" '{
    permissions:{}, hooks:{UserPromptSubmit:[
      {hooks:[{type:"command",command:$retired,timeout:30}]},
      {hooks:[{type:"command",command:$unrelated,timeout:7}]}
    ]}
  }' > "$home/.claude/settings.json"

  HOME="$home" bash "$REPO_ROOT/scripts/install-guards.sh" > /dev/null
  HOME="$home" bash "$REPO_ROOT/scripts/install-guards.sh" > /dev/null

  if ! jq -e --arg retired "$retired" --arg ctx "$ctx_inject" --arg unrelated "$unrelated" '
    ([.hooks.UserPromptSubmit[]?.hooks[]? | select(.command == $retired)] | length) == 0 and
    ([.hooks.UserPromptSubmit[]?.hooks[]? | select(.command == $ctx and .timeout == 150)] | length) == 1 and
    ([.hooks.UserPromptSubmit[]?.hooks[]? | select(.command == $unrelated and .timeout == 7)] | length) == 1
  ' "$home/.claude/settings.json" >/dev/null; then
    fail "$name" "retired context hook was not replaced cleanly"
    return
  fi
  pass "$name"
}

test_userpromptsubmit_uninstall_preserves_unrelated() {
  # Verifies uninstall-guards.sh removes only the managed UserPromptSubmit hook.
  # Steps:
  #   1. Create settings.json with an unrelated UserPromptSubmit hook
  #   2. Run install-guards.sh, then uninstall-guards.sh
  #   3. Assert the unrelated hook remains and guard-inject-memory.sh is gone
  local name="userpromptsubmit-uninstall-preserves-unrelated"
  should_run "$name" || return 0
  local home="$tmp_root/$name"
  local unrelated="/home/testuser/project/custom-userpromptsubmit.sh"
  mkdir -p "$home/.claude"
  printf '{"permissions":{},"hooks":{"UserPromptSubmit":[{"hooks":[{"type":"command","command":"%s"}]}]}}\n' \
    "$unrelated" > "$home/.claude/settings.json"

  HOME="$home" bash "$REPO_ROOT/scripts/install-guards.sh" > /dev/null
  HOME="$home" bash "$REPO_ROOT/scripts/uninstall-guards.sh" > /dev/null

  assert_file_contains "$name" "$home/.claude/settings.json" "$unrelated" || return
  assert_not_contains "$name" "$home/.claude/settings.json" "guard-inject-memory.sh" || return
  assert_not_contains "$name" "$home/.claude/settings.json" "inject-context.sh" || return
  pass "$name"
}

test_stop_hook_migration() {
  local name="hooks-stop-migration"
  should_run "$name" || return 0
  local home="$tmp_root/$name"
  mkdir -p "$home/.claude"
  # Write the stale entry in the same path form install-guards matches against
  # (native C:/... on Windows) so migration recognizes and rewrites it.
  local old_stop
  old_stop="$(_ti_hook_cmd_path "$REPO_ROOT/hooks/guard-log-claude-usage.sh")"
  printf '{"permissions":{},"hooks":{"Stop":[{"hooks":[{"type":"command","command":"%s"}]}]}}\n' \
    "$old_stop" > "$home/.claude/settings.json"

  HOME="$home" bash "$REPO_ROOT/scripts/install-guards.sh" > /dev/null
  assert_not_contains "$name" "$home/.claude/settings.json" \
    "hooks/guard-log-claude-usage.sh" || return
  assert_file_contains "$name" "$home/.claude/settings.json" \
    "hosts/claude/hooks/log-usage.sh" || return
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
  HOME="$home" bash "$REPO_ROOT/scripts/install-guards.sh" > /dev/null
  assert_file_contains "$name" "$home/.claude/settings.json" "$unrelated" || return
  assert_file_contains "$name" "$home/.claude/settings.json" "hosts/claude/hooks/log-usage.sh" || return

  # After uninstall: managed hook removed, unrelated hook still present
  HOME="$home" bash "$REPO_ROOT/scripts/uninstall-guards.sh" > /dev/null
  assert_not_contains "$name" "$home/.claude/settings.json" "hosts/claude/hooks/log-usage.sh" || return
  assert_file_contains "$name" "$home/.claude/settings.json" "$unrelated" || return
  pass "$name"
}

test_statusline_install_chains_previous() {
  # Verifies that when a previous statusLine.command exists, install saves it to
  # statusline-chain.conf and replaces it with guard-save-rate-limits.sh; a second
  # install run is idempotent and preserves the chain conf.
  # Steps:
  #   1. Write settings.json with a bare-path statusLine.command
  #   2. Run install; assert statusLine.command is now guard-save-rate-limits.sh
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

  HOME="$home" bash "$REPO_ROOT/scripts/install-guards.sh" > /dev/null
  local got
  got="$(jq -r '.statusLine.command // empty' "$home/.claude/settings.json")"
  if [[ "$got" != "$(_ti_hook_cmd_path "$REPO_ROOT/hosts/claude/hooks/save-rate-limits.sh")" ]]; then
    fail "$name" "statusLine.command was $got"
    return
  fi
  assert_file_content "$name" "$home/.claude/statusline-chain.conf" "$previous" || return

  HOME="$home" bash "$REPO_ROOT/scripts/install-guards.sh" > "$out"
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
  local other_hook="$other_dir/save-rate-limits.sh"
  local display_cmd="bash /home/screenleon/.claude/abtop-statusline.sh"
  mkdir -p "$home/.claude" "$other_dir"
  printf '#!/usr/bin/env bash\ncat >/dev/null\n' > "$other_hook"
  chmod +x "$other_hook"
  printf '{"permissions":{},"statusLine":{"type":"command","command":"%s"}}\n' \
    "$other_hook" > "$home/.claude/settings.json"
  printf '%s\n' "$display_cmd" > "$home/.claude/statusline-chain.conf"

  HOME="$home" bash "$REPO_ROOT/scripts/install-guards.sh" > /dev/null
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
  #   2. Run install; assert statusLine.command is replaced with guard-save-rate-limits.sh
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

  HOME="$home" bash "$REPO_ROOT/scripts/install-guards.sh" > /dev/null
  local got
  got="$(jq -r '.statusLine.command // empty' "$home/.claude/settings.json")"
  if [[ "$got" != "$(_ti_hook_cmd_path "$REPO_ROOT/hosts/claude/hooks/save-rate-limits.sh")" ]]; then
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

  HOME="$home" bash "$REPO_ROOT/scripts/install-guards.sh" > /dev/null
  HOME="$home" bash "$REPO_ROOT/scripts/uninstall-guards.sh" > /dev/null
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
  suite_list="$(bash "$REPO_ROOT/tests/bin/run-all-tests.sh" --list 2>/dev/null)"
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
test_install_sh_profile_full_wires_no_adapter_bash_guard
test_install_hooks_orphan_cleanup_removes_retired_adapter_guard
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
test_install_dispatch_allowlist_refreshes_other_checkout_paths
test_install_dispatch_allowlist_prunes_same_checkout_old_entrypoint
test_dispatch_allowlist_lib_parity
test_dispatch_allowlist_uninstall_removes_entries
test_dispatch_allowlist_uninstall_dryrun
test_install_hooks_gate_perms_fresh
test_install_hooks_gate_perms_idempotent
test_install_hooks_gate_perms_migrates_legacy_write
test_install_hooks_gate_perms_dry_run
test_install_hooks_gate_perms_preserves_existing
test_install_hooks_gate_perms_workspace_override
test_install_hooks_gate_perms_home_fallback
test_install_hooks_gate_perms_git_failure_fallback
test_install_hooks_gate_perms_normal_git_parent
test_install_hooks_gate_perms_uninstall_removes
test_hooks_install_uninstall_lifecycle
test_uninstall_hooks_removes_unlisted_hooks
test_install_hooks_prunes_retired_hooks
test_install_hooks_updates_stale_paths_after_rename
test_install_hooks_preserves_unrelated_same_basename_hook
test_install_hooks_uninstall_stale_paths_after_rename
test_userpromptsubmit_install_wires_hook
test_userpromptsubmit_uninstall_removes_hook
test_userpromptsubmit_install_idempotent
test_userpromptsubmit_install_upgrades_context_timeout
test_userpromptsubmit_install_migrates_retired_context_hook
test_userpromptsubmit_uninstall_preserves_unrelated
test_stop_hook_migration
test_stop_hook_preservation
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
  out=$(bash "$REPO_ROOT/tests/shell/test-install.sh" --filter "__no_such_case_xyz__" 2>&1) && status=$? || status=$?
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
  # Verifies install.sh installs share/codex-model-aliases.tsv to ~/.claude/share/
  # and records it in the install manifest (so uninstall can clean it up).
  #
  # Steps:
  #   1. Run install.sh in a temp HOME.
  #   2. Assert share/codex-model-aliases.tsv exists at ~/.claude/share/.
  #   3. Assert codex-model-aliases.tsv is referenced in the install manifest JSON.
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
  if [[ ! -e "$home/.claude/share/codex-model-aliases.tsv" ]]; then
    fail "$name" "share/codex-model-aliases.tsv not installed to ~/.claude/share/"
    return
  fi
  manifest="$home/.claude/.pm-dispatch/install-manifest.json"
  if ! grep -q "codex-model-aliases.tsv" "$manifest" 2>/dev/null; then
    fail "$name" "codex-model-aliases.tsv not found in install manifest"
    return
  fi
  pass "$name"
}

test_install_share_asset_conflict() {
  # A model-alias table is executable Adapter input in copy mode. A foreign
  # table must therefore stop install during the read-only load-bearing
  # preflight rather than leave a copied entrypoint wired to unowned policy.
  #
  # Steps:
  #   1. Pre-create ~/.claude/share/codex-model-aliases.tsv with existing content.
  #   2. Run install.sh in that same temp HOME.
  #   3. Assert install.sh exits 1, preserves the foreign bytes, and reports the
  #      load-bearing conflict.
  local name="install-share-asset-conflict"
  should_run "$name" || return 0
  local home err
  home="$tmp_root/$name"
  err="$tmp_root/$name.err"
  mkdir -p "$home/.claude/share"
  printf 'existing-content\n' > "$home/.claude/share/codex-model-aliases.tsv"
  set +e
  HOME="$home" \
    CLAUDE_CONFIG_TEST_INSTALL_RUNNING=1 \
    CLAUDE_CONFIG_TEST_PREFLIGHT_HOME="$REAL_HOME" \
    bash "$REPO_ROOT/install.sh" >/dev/null 2>"$err"
  local rc=$?
  set -e
  if [[ $rc -ne 1 \
      || "$(<"$home/.claude/share/codex-model-aliases.tsv")" != existing-content \
      || "$(<"$err")" != *"load-bearing copy bundle conflict"* ]]; then
    fail "$name" "share asset conflict did not fail closed rc=$rc err=$(tail -3 "$err" | tr '\n' '|')"
    return
  fi
  pass "$name"
}

test_install_share_asset_uninstall() {
  # Verifies uninstall.sh removes ~/.claude/share/codex-model-aliases.tsv when it
  # was installed by install.sh (manifest-driven removal).
  #
  # Steps:
  #   1. Run install.sh to install share/codex-model-aliases.tsv into temp HOME.
  #   2. Run uninstall.sh on that same temp HOME.
  #   3. Assert codex-model-aliases.tsv no longer exists at ~/.claude/share/.
  local name="install-share-asset-uninstall"
  should_run "$name" || return 0
  local home
  home="$tmp_root/$name"
  mkdir -p "$home/.claude"
  HOME="$home" \
    CLAUDE_CONFIG_TEST_INSTALL_RUNNING=1 \
    CLAUDE_CONFIG_TEST_PREFLIGHT_HOME="$REAL_HOME" \
    bash "$REPO_ROOT/install.sh" >/dev/null 2>&1 || true
  if [[ ! -e "$home/.claude/share/codex-model-aliases.tsv" ]]; then
    fail "$name" "precondition: codex-model-aliases.tsv not installed"
    return
  fi
  HOME="$home" bash "$REPO_ROOT/uninstall.sh" >/dev/null 2>&1 || true
  if [[ -e "$home/.claude/share/codex-model-aliases.tsv" ]]; then
    fail "$name" "codex-model-aliases.tsv still present after uninstall"
    return
  fi
  pass "$name"
}

test_install_claude_home_override() {
  # Verifies an explicit CLAUDE_HOME env override redirects the install to a
  # sandbox dir (NOT $HOME/.claude), so install changes can be rehearsed without
  # touching the real config. Covers the cross-script consistency: agents/commands
  # (install.sh), the manifest, AND the hook settings.json (install-guards.sh) must
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
  if ! grep -q "guard-pm-write.sh" "$override/settings.json" 2>/dev/null; then
    fail "$name" "hooks not wired into the override settings.json (install-guards ignored CLAUDE_HOME)"
    return
  fi
  if [[ -e "$home/.claude" ]]; then
    fail "$name" "\$HOME/.claude was created despite the CLAUDE_HOME override"
    return
  fi
  pass "$name"
}

test_install_claude_config_dir_canonical_override() {
  # Behavior: the runtime-standard CLAUDE_CONFIG_DIR controls every Claude
  # install surface, while HOME/.claude remains untouched.
  local name="install-claude-config-dir-canonical-override"
  should_run "$name" || return 0
  local home="$tmp_root/$name-home" config="$tmp_root/$name-config" rc=0
  mkdir -p "$home"
  HOME="$home" CLAUDE_CONFIG_DIR="$config" \
    CLAUDE_CONFIG_TEST_INSTALL_RUNNING=1 CLAUDE_CONFIG_TEST_PREFLIGHT_HOME="$REAL_HOME" \
    bash "$REPO_ROOT/install.sh" >/dev/null 2>&1 || rc=$?
  if [[ "$rc" -eq 0 && -e "$config/.pm-dispatch/install-manifest.json" ]] \
      && grep -q 'guard-pm-write.sh' "$config/settings.json" \
      && [[ ! -e "$home/.claude" ]]; then
    pass "$name"
  else
    fail "$name" "canonical config override was not applied consistently (rc=$rc)"
  fi
}

test_conflicting_claude_roots_fail_before_mutation() {
  # Behavior: explicitly divergent canonical/legacy roots are rejected by both
  # install and uninstall before either tree can be modified.
  local name="claude-config-root-conflict-fails-before-mutation"
  should_run "$name" || return 0
  local home="$tmp_root/$name-home" config="$tmp_root/$name-config"
  local legacy="$tmp_root/$name-legacy" install_rc=0 uninstall_rc=0
  mkdir -p "$home"
  HOME="$home" CLAUDE_CONFIG_DIR="$config" CLAUDE_HOME="$legacy" \
    bash "$REPO_ROOT/install.sh" >/dev/null 2>&1 || install_rc=$?
  HOME="$home" CLAUDE_CONFIG_DIR="$config" CLAUDE_HOME="$legacy" \
    bash "$REPO_ROOT/uninstall.sh" >/dev/null 2>&1 || uninstall_rc=$?
  if [[ "$install_rc" -eq 2 && "$uninstall_rc" -eq 2 \
      && ! -e "$config" && ! -e "$legacy" && ! -e "$home/.claude" ]]; then
    pass "$name"
  else
    fail "$name" "conflicting roots did not fail closed (install=$install_rc uninstall=$uninstall_rc)"
  fi
}

test_uninstall_claude_home_override() {
  # Verifies uninstall.sh honors the same CLAUDE_HOME override end-to-end: it
  # removes the sandbox install (including hook cleanup via uninstall-guards.sh)
  # while leaving a pre-existing REAL $HOME/.claude config completely untouched.
  # The real-home sentinel is the exact boundary CC-294 depends on — a regression
  # where uninstall-guards.sh edits $HOME/.claude/settings.json must fail this test.
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
  # removed. With the pre-CC-294 bug (uninstall-guards.sh resolving $HOME/.claude),
  # override hooks would survive while real home was edited instead.
  if grep -q "guard-pm-write.sh" "$override/settings.json" 2>/dev/null; then
    fail "$name" "override settings.json still has managed hooks (uninstall-guards ignored CLAUDE_HOME)"
    return
  fi
  # Real-home boundary: sentinel settings + marker must survive unchanged.
  if [[ ! -f "$sentinel_marker" ]]; then
    fail "$name" "real-home marker \$HOME/.claude/DO-NOT-TOUCH was removed by override uninstall"
    return
  fi
  if [[ "$(md5sum "$sentinel_settings" | awk '{print $1}')" != "$sentinel_sum" ]]; then
    fail "$name" "real-home \$HOME/.claude/settings.json was mutated by override uninstall (uninstall-guards ignored CLAUDE_HOME)"
    return
  fi
  pass "$name"
}

test_install_hooks_spaced_repo_root() {
  # Regression: a repo checked out under a path containing a space (e.g. a Windows
  # home like C:/Users/First Last/) must still produce RUNNABLE hooks. Claude Code
  # runs each hook `command` through the shell; an unquoted spaced path is word-
  # split and fails ("No such file or directory"). install-guards.sh shell-escapes
  # the command paths so they survive; doctor must recognise the escaped form as
  # the current checkout (not flag a spurious "different checkout").
  local name="install-guards-spaced-repo-root"
  should_run "$name" || return 0
  local home override spaced
  home="$tmp_root/$name-home"
  override="$tmp_root/$name-override"
  spaced="$tmp_root/repo with space"
  mkdir -p "$home"
  # Symlink the checkout under a spaced path and drive install/doctor/uninstall
  # THROUGH it, so every script self-derives the same spaced repo_root — exactly
  # how a real checkout under "C:/Users/First Last/" behaves. (Do not pass
  # PM_DISPATCH_REPO: install-guards honors it but uninstall-guards does not, so an
  # override here would make the two disagree and mask a removal failure.)
  if ! ln -s "$REPO_ROOT" "$spaced" 2>/dev/null; then
    printf '  (skip) %s — no directory symlink support here\n' "$name"
    return 0
  fi

  set +e
  HOME="$home" CLAUDE_HOME="$override" \
    CLAUDE_CONFIG_TEST_INSTALL_RUNNING=1 \
    CLAUDE_CONFIG_TEST_PREFLIGHT_HOME="$REAL_HOME" \
    bash "$spaced/install.sh" --profile full >/dev/null 2>&1
  local rc=$?
  set -e
  if [[ $rc -ne 0 ]]; then
    fail "$name" "install.sh exited $rc with a spaced repo root"
    return
  fi

  # Every managed hook command must be runnable through `bash -c` (the way Claude
  # Code invokes it) without word-splitting the spaced path.
  local cmd broken=0
  while IFS= read -r cmd; do
    [[ -n "$cmd" ]] || continue
    local out
    # The hook itself may exit non-zero (e.g. a write-guard deny); we only care
    # that the spaced command path was NOT word-split into a missing file.
    out="$(bash -c "$cmd" </dev/null 2>&1 || true)"
    if printf '%s' "$out" | grep -q "No such file or directory"; then
      broken=$((broken + 1))
      fail "$name" "hook command word-split on space: [$cmd]"
      return
    fi
  done < <(jq -r '
      [ (.hooks // {}) | (.PreToolUse,.PostToolUse,.Stop,.UserPromptSubmit) | .[]? | (.hooks // [])[]? | .command,
        .statusLine.command ]
      | map(select(. != null)) | .[]' "$override/settings.json")

  if [[ "$broken" -ne 0 ]]; then
    fail "$name" "$broken managed hook(s) unrunnable under a spaced repo root"
    return
  fi

  # doctor must not report the correctly-wired escaped hooks as a foreign checkout.
  local doc
  doc="$(CLAUDE_CONFIG_DIR="$override" \
        bash "$spaced/runtime/bin/doctor.sh" --repo "$spaced" 2>&1 || true)"
  if printf '%s' "$doc" | grep -qi "different checkout"; then
    fail "$name" "doctor flagged escaped spaced-repo hooks as a different checkout"
    return
  fi
  if ! printf '%s' "$doc" | grep -qE "hook\(s\) present|hooks present"; then
    fail "$name" "doctor did not recognise the managed hooks under a spaced repo root"
    return
  fi

  # Count managed hooks structurally (parent dir "scripts" + "hook-" basename) so
  # the assertion is immune to shell-escape backslashes in the command string —
  # a raw grep for the spaced path text would miss escaped leftovers.
  local managed_q='[ (.hooks // {}) | (.PreToolUse,.PostToolUse,.Stop,.UserPromptSubmit) | .[]? | (.hooks // [])[]? | .command, .statusLine.command ]
    | map(select(. != null))
    | map(select(
        ((split("/") | .[-2]) == "scripts" and ((split("/") | last) | test("^guard-"))) or
        ((split("/") | .[-2]) == "hooks" and (split("/") | .[-3]) == "claude" and (split("/") | .[-4]) == "hosts")
      ))
    | length'
  local managed_before
  managed_before="$(jq "$managed_q" "$override/settings.json")"
  if [[ "${managed_before:-0}" -lt 1 ]]; then
    fail "$name" "no managed hooks detected pre-uninstall (test fixture broken)"
    return
  fi

  # Uninstall (driven through the same spaced checkout) must remove every escaped
  # managed command, drop the escaped statusLine, and leave UNRELATED hooks alone.
  # Plant a foreign hook first so its survival proves the removal is scoped.
  local sentinel="/usr/bin/true"
  local planted
  planted="$(jq --arg s "$sentinel" '
      .hooks.PreToolUse += [{"matcher":"Edit|Write","hooks":[{"type":"command","command":$s}]}]
    ' "$override/settings.json")"
  printf '%s\n' "$planted" > "$override/settings.json"

  set +e
  HOME="$home" CLAUDE_HOME="$override" \
    bash "$spaced/scripts/uninstall-guards.sh" >/dev/null 2>&1
  local urc=$?
  set -e
  if [[ $urc -ne 0 ]]; then
    fail "$name" "uninstall-guards.sh exited $urc against a spaced-repo install"
    return
  fi
  # No managed (escaped) hook command or statusLine may survive.
  local managed_after
  managed_after="$(jq "$managed_q" "$override/settings.json")"
  if [[ "${managed_after:-1}" -ne 0 ]]; then
    fail "$name" "uninstall left $managed_after escaped managed hook(s) behind (in_repo did not match escaped prefix)"
    return
  fi
  # The unrelated hook must be preserved.
  if ! grep -q "$sentinel" "$override/settings.json" 2>/dev/null; then
    fail "$name" "uninstall removed an unrelated (foreign) hook — removal not scoped to managed paths"
    return
  fi
  pass "$name"
}

test_install_hooks_msys_native_jq_boundary() {
  # Regression for the MSYS/native-jq argument path-conversion bug: install-guards
  # passes printf %q-escaped command paths as jq --arg values, and uninstall-guards
  # passes the escaped repo root the same way. A native jq.exe on Git-Bash rewrites
  # the escape backslash (Lien\ Chen -> Lien/ Chen) unless the call disables MSYS
  # argument conversion. The existing spaced-repo test uses the real (Linux) jq,
  # which never mangles, so a mutation removing the env guards would survive it.
  # Here a fake jq emulates the rewrite UNLESS MSYS2_ARG_CONV_EXCL/MSYS_NO_PATHCONV
  # is set, making both guards load-bearing: install must store backslash-escaped
  # spaces, and uninstall must still match and remove the escaped entries.
  local name="install-guards-msys-native-jq-boundary"
  should_run "$name" || return 0
  local home override spaced fake_bin real_jq
  home="$tmp_root/$name-home"
  override="$tmp_root/$name-override"
  spaced="$tmp_root/jq boundary repo"
  fake_bin="$tmp_root/$name-bin"
  mkdir -p "$home" "$fake_bin"
  real_jq="$(command -v jq)"
  if ! ln -s "$REPO_ROOT" "$spaced" 2>/dev/null; then
    printf 'SKIP: %s (no directory symlink support here)\n' "$name"
    return 0
  fi
  # Fake jq: emulate a native (Windows) jq.exe under MSYS argument path conversion,
  # modeling BOTH failure modes of the conversion dilemma, then delegate to real jq.
  #  - conversion ON  (no guard): the printf %q escape backslash is rewritten to a
  #    slash (Lien\ Chen -> Lien/ Chen), corrupting --arg command paths.
  #  - conversion OFF (guard set): a POSIX-path positional INPUT FILE is not
  #    translated to a form the native binary can open -> "Could not open file".
  # The correct code keeps the guard (so --arg survives) AND feeds input via stdin
  # (so there is no positional file to fail). A regression to either shape fails.
  cat > "$fake_bin/jq" <<'FAKEJQ'
#!/usr/bin/env bash
conv_off=0
[[ -n "${MSYS2_ARG_CONV_EXCL:-}${MSYS_NO_PATHCONV:-}" ]] && conv_off=1
args=("$@")
n=${#args[@]}
if [[ "$conv_off" -eq 1 && "$n" -gt 0 ]]; then
  last="${args[n-1]}"
  if [[ "$last" == /* && -f "$last" ]]; then
    printf 'jq: error: Could not open %s\n' "$last" >&2
    exit 2
  fi
fi
out=()
for a in "${args[@]}"; do
  [[ "$conv_off" -eq 0 ]] && a="${a//\\//}"
  out+=("$a")
done
exec "$REAL_JQ" "${out[@]}"
FAKEJQ
  chmod +x "$fake_bin/jq"

  set +e
  HOME="$home" CLAUDE_HOME="$override" REAL_JQ="$real_jq" \
    CLAUDE_CONFIG_TEST_INSTALL_RUNNING=1 \
    CLAUDE_CONFIG_TEST_PREFLIGHT_HOME="$REAL_HOME" \
    PATH="$fake_bin:$PATH" \
    bash "$spaced/install.sh" --profile full >/dev/null 2>&1
  local rc=$?
  set -e
  if [[ $rc -ne 0 ]]; then
    fail "$name" "install.sh exited $rc under the fake native-jq boundary"
    return
  fi

  # install:211 guard — a managed command must keep backslash-escaped spaces and
  # must NOT be slash-mangled.
  local cmds
  cmds="$("$real_jq" -r '
    [ (.hooks // {}) | (.PreToolUse,.PostToolUse,.Stop,.UserPromptSubmit) | .[]? | (.hooks // [])[]? | .command,
      .statusLine.command ] | map(select(. != null)) | .[]' "$override/settings.json")"
  if printf '%s\n' "$cmds" | grep -qF 'jq boundary repo/ '; then
    fail "$name" "command path was slash-mangled (install jq guard not applied)"
    return
  fi
  if ! printf '%s\n' "$cmds" | grep -qF 'jq\ boundary\ repo'; then
    fail "$name" "no backslash-escaped spaced command path stored in settings.json"
    return
  fi

  # uninstall:85 guard — uninstall must match the escaped entries (via repo_root_q)
  # and remove every managed hook; a slash-mangled repo_root_q would miss them.
  local managed_q='[ (.hooks // {}) | (.PreToolUse,.PostToolUse,.Stop,.UserPromptSubmit) | .[]? | (.hooks // [])[]? | .command, .statusLine.command ]
    | map(select(. != null))
    | map(select(
        ((split("/") | .[-2]) == "scripts" and ((split("/") | last) | test("^guard-"))) or
        ((split("/") | .[-2]) == "hooks" and (split("/") | .[-3]) == "claude" and (split("/") | .[-4]) == "hosts")
      ))
    | length'
  if [[ "$("$real_jq" "$managed_q" "$override/settings.json")" -lt 1 ]]; then
    fail "$name" "no managed hooks detected pre-uninstall (fixture broken)"
    return
  fi
  set +e
  HOME="$home" CLAUDE_HOME="$override" REAL_JQ="$real_jq" \
    PATH="$fake_bin:$PATH" \
    bash "$spaced/scripts/uninstall-guards.sh" >/dev/null 2>&1
  local urc=$?
  set -e
  if [[ $urc -ne 0 ]]; then
    fail "$name" "uninstall-guards.sh exited $urc under the fake native-jq boundary"
    return
  fi
  if [[ "$("$real_jq" "$managed_q" "$override/settings.json")" -ne 0 ]]; then
    fail "$name" "uninstall left managed hook(s) behind (uninstall jq guard not applied — repo_root_q mismatch)"
    return
  fi
  pass "$name"
}

test_uninstall_prunes_empty_adapters_dir() {
  # Verifies uninstall.sh removes an empty ~/.claude/adapters/ directory so no
  # managed parent dirs are left behind after a clean uninstall.
  local name="uninstall-prunes-empty-adapters-dir"
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
  if [[ "$install_rc" -ne 0 ]]; then
    fail "$name" "precondition: install.sh exited $install_rc"
    return
  fi

  # Simulate the post-adapter-symlink-removal state: adapters/ exists but is empty.
  mkdir -p "$override/adapters"

  set +e
  HOME="$home" CLAUDE_HOME="$override" \
    bash "$REPO_ROOT/uninstall.sh" >/dev/null 2>&1
  local uninstall_rc=$?
  set -e
  if [[ "$uninstall_rc" -ne 0 ]]; then
    fail "$name" "uninstall.sh exited $uninstall_rc (expected 0)"
    return
  fi

  if [[ -d "$override/adapters" ]]; then
    fail "$name" "~/.claude/adapters/ still exists after uninstall (empty dir not pruned)"
    return
  fi
  pass "$name"
}

test_install_refreshes_relocated_helper_symlinks() {
  # Stable user-facing helper names must refresh from retired scripts/ sources
  # to their canonical domain owners without treating this checkout's prior
  # installation as a user conflict.
  local name="install-refreshes-relocated-helper-symlinks"
  should_run "$name" || return 0
  [[ "$(detect_platform)" != "windows" ]] || { pass "$name (symlink-only migration on POSIX)"; return; }
  local home="$tmp_root/$name-home" claude_home
  claude_home="$home/.claude"
  local out="$tmp_root/$name.out" err="$tmp_root/$name.err"
  local foreign="$tmp_root/$name-foreign.sh"
  mkdir -p "$claude_home/scripts"
  ln -s "$REPO_ROOT/scripts/token-usage.sh" "$claude_home/scripts/token-usage.sh"
  printf '#!/usr/bin/env bash\n' > "$foreign"
  ln -s "$foreign" "$claude_home/scripts/log-usage.sh"

  HOME="$home" CLAUDE_HOME="$claude_home" \
    CLAUDE_CONFIG_TEST_INSTALL_RUNNING=1 \
    CLAUDE_CONFIG_TEST_PREFLIGHT_HOME="$REAL_HOME" \
    bash "$REPO_ROOT/install.sh" >"$out" 2>"$err"

  assert_symlink_target "$name" "$claude_home/scripts/token-usage.sh" \
    "$REPO_ROOT/ops/usage/token-usage.sh" || return
  assert_symlink_target "$name" "$claude_home/scripts/log-usage.sh" "$foreign" || return
  assert_file_contains "$name" "$out" \
    "link   $claude_home/scripts/token-usage.sh -> $REPO_ROOT/ops/usage/token-usage.sh" || return
  assert_file_contains "$name" "$err" "CONFLICT $claude_home/scripts/log-usage.sh" || return
  pass "$name"
}

test_install_missing_host_write_library_fails_loudly() {
  # Claude settings writes are now manifest-dispatched and therefore require
  # both shared host-write libraries even when no optional host is requested.
  local name="install-missing-host-write-library-fails-loudly"
  should_run "$name" || return 0
  local mock_repo="$tmp_root/$name-repo" home="$tmp_root/$name-home"
  local out="$tmp_root/$name.out" rc=0
  mkdir -p "$mock_repo/scripts/lib" "$mock_repo/runtime/lib" "$mock_repo/hosts/claude/lib" "$home"
  cp "$REPO_ROOT/install.sh" "$mock_repo/install.sh"
  cp "$REPO_ROOT/runtime/lib/portable.sh" "$mock_repo/runtime/lib/portable.sh"
  cp "$REPO_ROOT/runtime/lib/allowlist.sh" "$mock_repo/runtime/lib/allowlist.sh"
  cp "$REPO_ROOT/runtime/lib/identifier-policy.sh" "$mock_repo/runtime/lib/identifier-policy.sh"
  cp "$REPO_ROOT/runtime/lib/runner-kind.sh" "$mock_repo/runtime/lib/runner-kind.sh"
  cp "$REPO_ROOT/runtime/lib/adapter-manifest.sh" "$mock_repo/runtime/lib/adapter-manifest.sh"
  cp "$REPO_ROOT/hosts/claude/lib/path-resolver.sh" "$mock_repo/hosts/claude/lib/path-resolver.sh"

  HOME="$home" bash "$mock_repo/install.sh" >"$out" 2>&1 || rc=$?
  if [[ "$rc" -ne 2 ]]; then
    fail "$name" "expected exit 2, got $rc: $(<"$out")"
    return
  fi
  assert_file_contains "$name" "$out" "host write libraries unavailable in this install layout" || return
  if [[ -e "$home/.claude/settings.json" ]]; then
    fail "$name" "install mutated Claude settings before rejecting the incomplete checkout"
    return
  fi
  pass "$name"
}

# Behavior: a missing load-bearing source aborts bundle preflight before the
# installer changes an existing receipt or publishes any destination.
# Steps: Arrange an installer-shaped tree missing model-aliases.sh; Act by
# installing; Assert the conflict and no pmctl, Gate, or receipt mutation.
test_install_missing_load_bearing_source_fails_before_mutation() {
  local name="install-missing-load-bearing-source-fails-before-mutation"
  should_run "$name" || return 0
  local mock_repo="$tmp_root/$name-repo" home="$tmp_root/$name-home"
  local out="$tmp_root/$name.out" rc=0
  local legacy="$home/.claude/.pm-dispatch/install-manifest.json"
  mkdir -p "$mock_repo" "${legacy%/*}"
  printf '%s\n' '{"manifest_version":1,"entries":[]}' > "$legacy"

  # Build a complete installer-shaped source tree, then remove a dependency that
  # install.sh itself does not source before bundle preflight. This distinguishes
  # the load-bearing inventory check from a generic shell source failure.
  cp "$REPO_ROOT/install.sh" "$mock_repo/install.sh"
  cp -R "$REPO_ROOT/agents" "$REPO_ROOT/adapters" "$REPO_ROOT/cli" \
    "$REPO_ROOT/commands" "$REPO_ROOT/core" "$REPO_ROOT/hosts" \
    "$REPO_ROOT/ops" "$REPO_ROOT/pm" "$REPO_ROOT/runtime" \
    "$REPO_ROOT/scripts" "$REPO_ROOT/share" "$REPO_ROOT/skills" \
    "$mock_repo/"
  rm "$mock_repo/runtime/lib/model-aliases.sh"

  HOME="$home" PMCTL_BIN_DIR="$tmp_root/$name-bin" \
    CLAUDE_CONFIG_TEST_INSTALL_RUNNING=1 \
    bash "$mock_repo/install.sh" >"$out" 2>&1 || rc=$?

  if [[ "$rc" -eq 0 ]] \
      || ! grep -Fq 'load-bearing copy bundle conflict' "$out" \
      || ! grep -Fq "$home/.claude/runtime/lib/model-aliases.sh" "$out"; then
    fail "$name" "missing required bundle source did not fail during preflight (rc=$rc)"
    return
  fi
  if [[ -e "$tmp_root/$name-bin/pmctl" \
      || -e "$home/.pm-dispatch/install-manifest.json" \
      || -e "$home/.claude/scripts/pr-gate.sh" \
      || "$(<"$legacy")" != '{"manifest_version":1,"entries":[]}' ]]; then
    fail "$name" "missing source failure left an unreceipted partial install"
    return
  fi
  pass "$name"
}

# Behavior: removing a managed source tree after preflight is detected before
# load-bearing doctor or Gate entrypoints can be published.
# Steps: Arrange ln to move the agents tree during apply; Act by installing;
# Assert exit 1 with the TOCTOU error and neither installed entrypoint present.
test_install_managed_tree_removed_after_preflight_blocks_entrypoints() {
  local name="install-managed-tree-removed-after-preflight-blocks-entrypoints"
  should_run "$name" || return 0
  _ti_is_windows && { pass "$name (POSIX ln interception only)"; return 0; }
  local mock_repo="$tmp_root/$name-repo" home="$tmp_root/$name-home"
  local shim_dir="$tmp_root/$name-bin-shim" pmctl_dir="$tmp_root/$name-pmctl"
  local out="$tmp_root/$name.out" rc=0
  mkdir -p "$mock_repo" "$home" "$shim_dir"
  cp "$REPO_ROOT/install.sh" "$mock_repo/install.sh"
  cp -R "$REPO_ROOT/agents" "$REPO_ROOT/adapters" "$REPO_ROOT/cli" \
    "$REPO_ROOT/commands" "$REPO_ROOT/core" "$REPO_ROOT/hosts" \
    "$REPO_ROOT/ops" "$REPO_ROOT/pm" "$REPO_ROOT/runtime" \
    "$REPO_ROOT/scripts" "$REPO_ROOT/share" "$REPO_ROOT/skills" \
    "$mock_repo/"
  cat > "$shim_dir/ln" <<'LN_SHIM'
#!/usr/bin/env bash
set -euo pipefail
if [[ -n "${PM_TEST_REMOVE_TREE:-}" && -d "$PM_TEST_REMOVE_TREE" ]]; then
  mv "$PM_TEST_REMOVE_TREE" "$PM_TEST_REMOVE_TREE.removed-after-preflight"
fi
exec /bin/ln "$@"
LN_SHIM
  chmod +x "$shim_dir/ln"

  HOME="$home" PMCTL_BIN_DIR="$pmctl_dir" \
    PM_TEST_REMOVE_TREE="$mock_repo/agents" PATH="$shim_dir:$PATH" \
    CLAUDE_CONFIG_TEST_INSTALL_RUNNING=1 \
    bash "$mock_repo/install.sh" >"$out" 2>&1 || rc=$?

  if [[ "$rc" -ne 1 \
      || "$(<"$out")" != *"load-bearing agents source tree changed after preflight"* \
      || -e "$home/.claude/scripts/pr-gate.sh" \
      || -e "$home/.claude/scripts/doctor.sh" ]]; then
    fail "$name" "managed-tree TOCTOU did not fail before entrypoint publication (rc=$rc)"
    return
  fi
  pass "$name"
}

test_host_selected_codex_lifecycle_skips_claude_tree() {
  # A host-selected lifecycle must not retain Claude as an implicit base
  # installer. Verify both install and matching uninstall leave HOME/.claude
  # untouched while the Codex-owned hooks are wired then removed.
  local name="host-selected-codex-lifecycle-skips-claude-tree"
  should_run "$name" || return 0
  local home="$tmp_root/$name-home" codex_home="$tmp_root/$name-codex"
  local out="$tmp_root/$name.out" uninstall_out="$tmp_root/$name-uninstall.out" rc=0

  HOME="$home" CODEX_HOME="$codex_home" PMCTL_BIN_DIR="$tmp_root/$name-bin" \
    CLAUDE_CONFIG_TEST_INSTALL_RUNNING=1 \
    bash "$REPO_ROOT/install.sh" --host codex >"$out" 2>&1 || rc=$?
  if [[ "$rc" -ne 0 ]]; then
    fail "$name" "host-selected install exited $rc: $(<"$out")"
    return
  fi
  if [[ -e "$home/.claude" ]]; then
    fail "$name" "Codex-only install created $home/.claude"
    return
  fi
  if ! grep -Fq 'hosts/codex/hooks/command-guard.sh' "$codex_home/hooks.json"; then
    fail "$name" "Codex-only install did not wire the Codex hook"
    return
  fi

  rc=0
  HOME="$home" CODEX_HOME="$codex_home" PMCTL_BIN_DIR="$tmp_root/$name-bin" \
    bash "$REPO_ROOT/uninstall.sh" --host codex >"$uninstall_out" 2>&1 || rc=$?
  if [[ "$rc" -ne 0 ]]; then
    fail "$name" "host-selected uninstall exited $rc: $(<"$uninstall_out")"
    return
  fi
  if [[ -e "$home/.claude" ]]; then
    fail "$name" "Codex-only uninstall created $home/.claude"
    return
  fi
  if grep -Fq 'hosts/codex/hooks/command-guard.sh' "$codex_home/hooks.json"; then
    fail "$name" "Codex hook remained after matching host-selected uninstall"
    return
  fi
  pass "$name"
}

test_host_selected_opencode_lifecycle_skips_claude_tree() {
  local name="host-selected-opencode-lifecycle-skips-claude-tree"
  should_run "$name" || return 0
  local home="$tmp_root/$name-home" xdg_home="$tmp_root/$name-xdg"
  local out="$tmp_root/$name.out" uninstall_out="$tmp_root/$name-uninstall.out" rc=0

  HOME="$home" XDG_CONFIG_HOME="$xdg_home" PMCTL_BIN_DIR="$tmp_root/$name-bin" \
    CLAUDE_CONFIG_TEST_INSTALL_RUNNING=1 \
    bash "$REPO_ROOT/install.sh" --host opencode >"$out" 2>&1 || rc=$?
  if [[ "$rc" -ne 0 ]]; then
    fail "$name" "host-selected install exited $rc: $(<"$out")"
    return
  fi
  if [[ -e "$home/.claude" || ! -f "$xdg_home/opencode/opencode.json" ]]; then
    fail "$name" "OpenCode-only install did not keep host ownership isolated"
    return
  fi

  rc=0
  HOME="$home" XDG_CONFIG_HOME="$xdg_home" PMCTL_BIN_DIR="$tmp_root/$name-bin" \
    bash "$REPO_ROOT/uninstall.sh" --host opencode >"$uninstall_out" 2>&1 || rc=$?
  if [[ "$rc" -ne 0 || -e "$home/.claude" ]]; then
    fail "$name" "OpenCode-only uninstall mutated the Claude tree or failed"
    return
  fi
  pass "$name"
}

test_host_equals_form_codex_lifecycle_skips_claude_tree() {
  local name="host-equals-form-codex-lifecycle-skips-claude-tree"
  should_run "$name" || return 0
  local home="$tmp_root/$name-home" codex_home="$tmp_root/$name-codex"
  local out="$tmp_root/$name.out" uninstall_out="$tmp_root/$name-uninstall.out" rc=0

  HOME="$home" CODEX_HOME="$codex_home" PMCTL_BIN_DIR="$tmp_root/$name-bin" \
    CLAUDE_CONFIG_TEST_INSTALL_RUNNING=1 \
    bash "$REPO_ROOT/install.sh" --host=codex --host=codex >"$out" 2>&1 || rc=$?
  if [[ "$rc" -ne 0 || -e "$home/.claude" ]] \
      || ! grep -Fq 'hosts/codex/hooks/command-guard.sh' "$codex_home/hooks.json" \
      || [[ "$(grep -c '^  codex$' "$out")" -ne 1 ]]; then
    fail "$name" "--host=codex install did not match isolated Codex lifecycle"
    return
  fi
  rc=0
  HOME="$home" CODEX_HOME="$codex_home" PMCTL_BIN_DIR="$tmp_root/$name-bin" \
    bash "$REPO_ROOT/uninstall.sh" --host=codex >"$uninstall_out" 2>&1 || rc=$?
  if [[ "$rc" -ne 0 || -e "$home/.claude" ]] \
      || grep -Fq 'hosts/codex/hooks/command-guard.sh' "$codex_home/hooks.json"; then
    fail "$name" "--host=codex uninstall did not match isolated Codex lifecycle"
    return
  fi
  pass "$name"
}

test_host_selected_claude_and_codex_lifecycle() {
  local name="host-selected-claude-and-codex-lifecycle"
  should_run "$name" || return 0
  local home="$tmp_root/$name-home" claude_home="$tmp_root/$name-claude"
  local codex_home="$tmp_root/$name-codex" out="$tmp_root/$name.out"
  local uninstall_out="$tmp_root/$name-uninstall.out" rc=0

  HOME="$home" CLAUDE_HOME="$claude_home" CODEX_HOME="$codex_home" PMCTL_BIN_DIR="$tmp_root/$name-bin" \
    CLAUDE_CONFIG_TEST_INSTALL_RUNNING=1 \
    bash "$REPO_ROOT/install.sh" --host claude --host codex >"$out" 2>&1 || rc=$?
  if [[ "$rc" -ne 0 || ! -e "$claude_home/.pm" ]] \
      || ! grep -Fq 'hosts/codex/hooks/command-guard.sh' "$codex_home/hooks.json"; then
    fail "$name" "explicit Claude+Codex install did not wire both selected hosts"
    return
  fi
  rc=0
  HOME="$home" CLAUDE_HOME="$claude_home" CODEX_HOME="$codex_home" PMCTL_BIN_DIR="$tmp_root/$name-bin" \
    bash "$REPO_ROOT/uninstall.sh" --host claude --host codex >"$uninstall_out" 2>&1 || rc=$?
  if [[ "$rc" -ne 0 || -e "$claude_home/.pm" ]] \
      || grep -Fq 'hosts/codex/hooks/command-guard.sh' "$codex_home/hooks.json"; then
    fail "$name" "explicit Claude+Codex uninstall did not remove both selected host artifacts"
    return
  fi
  pass "$name"
}

test_host_and_legacy_selector_conflict_fails_before_mutation() {
  local name="host-and-legacy-selector-conflict-fails-before-mutation"
  should_run "$name" || return 0
  local home="$tmp_root/$name-home" claude_home="$tmp_root/$name-claude"
  local codex_home="$tmp_root/$name-codex" out="$tmp_root/$name.out" rc=0
  HOME="$home" CLAUDE_HOME="$claude_home" CODEX_HOME="$codex_home" PMCTL_BIN_DIR="$tmp_root/$name-bin" \
    bash "$REPO_ROOT/install.sh" --host codex --enable-host claude >"$out" 2>&1 || rc=$?
  if [[ "$rc" -ne 2 ]] || ! grep -Fq -- '--host cannot be combined' "$out" \
      || [[ -e "$claude_home" || -e "$codex_home" ]]; then
    fail "$name" "mixed explicit and legacy selectors did not fail before mutation"
    return
  fi
  pass "$name"
}

test_host_selected_dry_run_reports_no_mutation() {
  local name="host-selected-dry-run-reports-no-mutation"
  should_run "$name" || return 0
  local home="$tmp_root/$name-home" codex_home="$tmp_root/$name-codex" out="$tmp_root/$name.out" rc=0
  HOME="$home" CODEX_HOME="$codex_home" bash "$REPO_ROOT/uninstall.sh" --host=codex --dry-run >"$out" 2>&1 || rc=$?
  if [[ "$rc" -ne 0 ]] || ! grep -Fq 'no changes made' "$out" \
      || [[ -e "$home/.claude" || -e "$codex_home" ]]; then
    fail "$name" "non-Claude dry-run did not report or preserve no-mutation state"
    return
  fi
  pass "$name"
}

test_uninstall_missing_host_write_library_preserves_manifest_teardown() {
  local name="uninstall-missing-host-write-library-preserves-manifest-teardown"
  should_run "$name" || return 0
  local mock_repo="$tmp_root/$name-repo" home="$tmp_root/$name-home"
  local claude_home="$home/.claude"
  local source="$mock_repo/pm"
  local destination="$claude_home/.pm"
  local out="$tmp_root/$name.out" rc=0
  mkdir -p "$mock_repo/runtime/lib" "$mock_repo/hosts/claude/lib" "$source" "$claude_home/.pm-dispatch"
  cp "$REPO_ROOT/uninstall.sh" "$mock_repo/uninstall.sh"
  cp "$REPO_ROOT/runtime/lib/portable.sh" "$mock_repo/runtime/lib/portable.sh"
  cp "$REPO_ROOT/runtime/lib/install-receipt.sh" \
    "$mock_repo/runtime/lib/install-receipt.sh"
  cp "$REPO_ROOT/hosts/claude/lib/path-resolver.sh" "$mock_repo/hosts/claude/lib/path-resolver.sh"
  ln -s "$source" "$destination"
  printf '{"manifest_version":1,"entries":[{"src":"%s","dst":"%s","mode":"symlink","sha256":""}]}\n' \
    "$source" "$destination" > "$claude_home/.pm-dispatch/install-manifest.json"

  HOME="$home" PMCTL_BIN_DIR="$tmp_root/$name-bin" bash "$mock_repo/uninstall.sh" >"$out" 2>&1 || rc=$?
  if [[ "$rc" -ne 0 || -e "$destination" ]] \
      || grep -Fq 'command not found' "$out"; then
    fail "$name" "missing host-write library did not preserve default manifest teardown"
    return
  fi
  pass "$name"
}

test_receipt_partial_host_uninstall_preserves_remaining_owner() {
  local name="receipt-partial-host-uninstall-preserves-remaining-owner"
  should_run "$name" || return 0
  local home="$tmp_root/$name-home" claude_home="$tmp_root/$name-claude"
  local codex_home="$tmp_root/$name-codex" receipt="$home/.pm-dispatch/install-manifest.json"
  local out="$tmp_root/$name.out" rc=0

  HOME="$home" CLAUDE_HOME="$claude_home" CODEX_HOME="$codex_home" PMCTL_BIN_DIR="$tmp_root/$name-bin" \
    CLAUDE_CONFIG_TEST_INSTALL_RUNNING=1 \
    bash "$REPO_ROOT/install.sh" --host claude --host codex >"$out" 2>&1 || rc=$?
  if [[ "$rc" -ne 0 || ! -f "$receipt" ]]; then
    fail "$name" "combined install did not create product receipt"
    return
  fi

  rc=0
  HOME="$home" CLAUDE_HOME="$claude_home" CODEX_HOME="$codex_home" PMCTL_BIN_DIR="$tmp_root/$name-bin" \
    bash "$REPO_ROOT/uninstall.sh" --host codex >>"$out" 2>&1 || rc=$?
  if [[ "$rc" -ne 0 || ! -e "$claude_home/.pm" ]] \
      || grep -Fq 'hosts/codex/hooks/command-guard.sh' "$codex_home/hooks.json" \
      || ! jq -e '.selected_hosts == ["claude"]' "$receipt" >/dev/null; then
    fail "$name" "partial uninstall did not retain only Claude ownership"
    return
  fi

  rc=0
  HOME="$home" CLAUDE_HOME="$claude_home" CODEX_HOME="$codex_home" PMCTL_BIN_DIR="$tmp_root/$name-bin" \
    bash "$REPO_ROOT/uninstall.sh" >>"$out" 2>&1 || rc=$?
  if [[ "$rc" -ne 0 || -e "$claude_home/.pm" || -e "$receipt" ]]; then
    fail "$name" "implicit uninstall did not finish remaining receipt ownership"
    return
  fi
  pass "$name"
}

test_legacy_claude_manifest_migrates_to_product_receipt() {
  local name="legacy-claude-manifest-migrates-to-product-receipt"
  should_run "$name" || return 0
  local home="$tmp_root/$name-home"
  local claude_home="$home/.claude"
  local legacy="$claude_home/.pm-dispatch/install-manifest.json"
  local receipt="$home/.pm-dispatch/install-manifest.json"
  local out="$tmp_root/$name.out" rc=0
  mkdir -p "${legacy%/*}"
  printf '{"manifest_version":1,"entries":[]}\n' > "$legacy"

  HOME="$home" PMCTL_BIN_DIR="$tmp_root/$name-bin" CLAUDE_CONFIG_TEST_INSTALL_RUNNING=1 \
    bash "$REPO_ROOT/install.sh" --host claude >"$out" 2>&1 || rc=$?
  if [[ "$rc" -ne 0 || ! -f "$receipt" || ! -f "$legacy" ]] \
      || ! jq -e '.selected_hosts == ["claude"]' "$receipt" >/dev/null; then
    fail "$name" "legacy Claude receipt was not migrated into the product receipt"
    return
  fi
  pass "$name"
}

test_product_receipt_root_override_isolated() {
  local name="product-receipt-root-override-isolated"
  should_run "$name" || return 0
  local home="$tmp_root/$name-home" root="$tmp_root/$name-receipt-root"
  local codex_home="$tmp_root/$name-codex" receipt="$root/install-manifest.json" out="$tmp_root/$name.out" rc=0
  HOME="$home" CODEX_HOME="$codex_home" PM_DISPATCH_INSTALL_ROOT="$root" PMCTL_BIN_DIR="$tmp_root/$name-bin" \
    CLAUDE_CONFIG_TEST_INSTALL_RUNNING=1 bash "$REPO_ROOT/install.sh" --host codex >"$out" 2>&1 || rc=$?
  if [[ "$rc" -ne 0 || ! -f "$receipt" || -e "$home/.pm-dispatch/install-manifest.json" ]] \
      || ! jq -e '.selected_hosts == ["codex"]' "$receipt" >/dev/null; then
    fail "$name" "product receipt override was not isolated from HOME"
    return
  fi
  HOME="$home" CODEX_HOME="$codex_home" PM_DISPATCH_INSTALL_ROOT="$root" PMCTL_BIN_DIR="$tmp_root/$name-bin" \
    bash "$REPO_ROOT/uninstall.sh" >"$out" 2>&1 || rc=$?
  if [[ "$rc" -ne 0 || -e "$receipt" ]]; then
    fail "$name" "implicit uninstall did not honor the product receipt override"
    return
  fi
  pass "$name"
}

test_install_share_asset_installed
test_install_share_asset_conflict
test_install_share_asset_uninstall
test_install_claude_home_override
test_install_claude_config_dir_canonical_override
test_conflicting_claude_roots_fail_before_mutation
test_uninstall_claude_home_override
test_install_hooks_spaced_repo_root
test_install_hooks_msys_native_jq_boundary
test_install_refreshes_relocated_helper_symlinks
test_uninstall_prunes_empty_adapters_dir
test_install_missing_host_write_library_fails_loudly
test_install_missing_load_bearing_source_fails_before_mutation
test_install_managed_tree_removed_after_preflight_blocks_entrypoints
test_host_selected_codex_lifecycle_skips_claude_tree
test_host_selected_opencode_lifecycle_skips_claude_tree
test_host_equals_form_codex_lifecycle_skips_claude_tree
test_host_selected_claude_and_codex_lifecycle
test_host_and_legacy_selector_conflict_fails_before_mutation
test_host_selected_dry_run_reports_no_mutation
test_uninstall_missing_host_write_library_preserves_manifest_teardown
test_receipt_partial_host_uninstall_preserves_remaining_owner
test_legacy_claude_manifest_migrates_to_product_receipt
test_product_receipt_root_override_isolated

th_summary
