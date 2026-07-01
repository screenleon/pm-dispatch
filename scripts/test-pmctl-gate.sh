#!/usr/bin/env bash
# Regression tests for `pmctl gate run` — routing shim that delegates to
# scripts/pr-gate.sh with --cd defaulting.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PMCTL="$REPO_ROOT/cli/pmctl"

# shellcheck source=scripts/lib/test-harness.sh
. "$SCRIPT_DIR/lib/test-harness.sh"
th_init "$@"

# Isolate the detached-gate sentinel key dir for this suite's cli/pmctl fixture
# cases, mirroring scripts/test-gate-lifecycle.sh's isolation, so they are
# deterministic and never collide with a real gate run on this host.
_GATE_CLI_XDG_RUNTIME_DIR="$tmp_root/gate-cli-xdg-runtime"
mkdir -p "$_GATE_CLI_XDG_RUNTIME_DIR" && chmod 700 "$_GATE_CLI_XDG_RUNTIME_DIR"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Install a fake pr-gate.sh into fixture/scripts/ that writes a structurally
# valid gate result under --run-dir (so gate_result_verify accepts it -- the
# detached wait path now requires this, per CC-423's result-integrity fix)
# and prints `result: <path>`, then exits with the given code.
_mk_fake_gate_with_result() {
  local fixture="$1" code="$2"
  mkdir -p "$fixture/scripts"
  cat > "$fixture/scripts/pr-gate.sh" <<FAKEGATE
#!/usr/bin/env bash
rd=""
while [[ \$# -gt 0 ]]; do
  case "\$1" in
    --run-dir) rd="\$2"; shift 2 ;;
    *) shift ;;
  esac
done
if [[ -n "\$rd" ]]; then
  mkdir -p "\$rd"
  cat > "\$rd/result.md" <<RESULT
---
gate_result_version: pr_gate_result_v1
final: $([[ $code -eq 0 ]] && printf GO || printf NO-GO)
tier: express
mode: sequential
most_severe: approve
---

# PR-Gate Result

## Gate Conclusion
Final: $([[ $code -eq 0 ]] && printf GO || printf NO-GO)
RESULT
  printf 'result: %s\n' "\$rd/result.md"
fi
exit $code
FAKEGATE
  chmod +x "$fixture/scripts/pr-gate.sh"
}

# Install a fake pr-gate.sh into fixture/scripts/ that echoes its args and
# exits with the given code.
_mk_fake_gate() {
  local fixture="$1" code="$2"
  mkdir -p "$fixture/scripts"
  cat > "$fixture/scripts/pr-gate.sh" <<FAKEGATE
#!/usr/bin/env bash
printf 'fake-gate-args: %s\n' "\$*"
exit $code
FAKEGATE
  chmod +x "$fixture/scripts/pr-gate.sh"
}

# Copy the real pmctl-gate.sh lib into a fixture so we can drive it with a
# controlled REPO_ROOT that points at a fake gate script.
_mk_gate_wrapper() {
  local fixture="$1" out="$2"
  mkdir -p "$fixture/scripts/lib"
  cp "$REPO_ROOT/scripts/lib/pmctl-gate.sh" "$fixture/scripts/lib/pmctl-gate.sh"
  cat > "$out" <<WRAPPER
#!/usr/bin/env bash
set -euo pipefail
. "$fixture/scripts/lib/pmctl-gate.sh"
pmctl_gate_run "$fixture" "\$@"
WRAPPER
  chmod +x "$out"
}

# Build a fixture repo that carries the REAL cli/pmctl binary (so its own
# gate/run + gate/wait routing-table entries are exercised, not a hand-rolled
# wrapper) plus the minimal lib set gate/run and gate/wait need. cli/pmctl
# resolves REPO_ROOT from its own script location, so copying it into the
# fixture makes it treat the fixture as REPO_ROOT.
_mk_gate_cli_fixture() {
  local fixture="$1"
  mkdir -p "$fixture/cli" "$fixture/scripts/lib"
  cp "$REPO_ROOT/cli/pmctl" "$fixture/cli/pmctl"
  chmod +x "$fixture/cli/pmctl"
  for _lib in pmctl-gate gate-result-verify state-paths portable; do
    cp "$REPO_ROOT/scripts/lib/$_lib.sh" "$fixture/scripts/lib/$_lib.sh"
  done
  cp "$REPO_ROOT/scripts/gate-supervisor.sh" "$fixture/scripts/gate-supervisor.sh"
  chmod +x "$fixture/scripts/gate-supervisor.sh"
}

# ---- 1: explicit --cd is passed through unchanged ----------------------------
case_explicit_cd_passthrough() {
  # Verifies that pmctl_gate_run passes an explicit --cd value through to
  # pr-gate.sh without modification.
  #
  # Steps:
  #   1. Install a fake pr-gate.sh that echoes its argv.
  #   2. Call pmctl_gate_run with --cd /tmp and --tier express.
  #   3. Assert both flags appear in the echoed output.
  local name="gate/run: explicit --cd passed through to pr-gate.sh"
  should_run "$name" || return 0

  local fixture="$tmp_root/f1" wrapper="$tmp_root/b1/wrapper"
  mkdir -p "$(dirname "$wrapper")"
  _mk_fake_gate "$fixture" 0
  _mk_gate_wrapper "$fixture" "$wrapper"

  local out code
  set +e; out="$("$wrapper" --cd /tmp --lifecycle foreground --tier express 2>&1)"; code=$?; set -e

  if [[ "$code" -eq 0 ]] \
     && [[ "$out" == *"--cd /tmp"* ]] \
     && [[ "$out" == *"--tier express"* ]]; then
    pass "$name"
  else
    fail "$name" "code=$code out=$out"
  fi
}

# ---- 2: missing --cd defaults to $PWD ----------------------------------------
case_default_cd_injected() {
  # Verifies that pmctl_gate_run injects --cd $PWD when the caller omits it,
  # so pr-gate.sh always receives a working directory without forcing callers
  # to spell it out.
  #
  # Steps:
  #   1. Install a fake pr-gate.sh that echoes its argv.
  #   2. Call pmctl_gate_run without --cd.
  #   3. Assert the echoed output contains --cd <current working directory>.
  local name="gate/run: --cd defaults to \$PWD when omitted"
  should_run "$name" || return 0

  local fixture="$tmp_root/f2" wrapper="$tmp_root/b2/wrapper"
  mkdir -p "$(dirname "$wrapper")"
  _mk_fake_gate "$fixture" 0
  _mk_gate_wrapper "$fixture" "$wrapper"

  local expected_cd out code
  expected_cd="$PWD"
  set +e; out="$("$wrapper" --lifecycle foreground --tier express 2>&1)"; code=$?; set -e

  if [[ "$code" -eq 0 ]] && [[ "$out" == *"--cd $expected_cd"* ]]; then
    pass "$name"
  else
    fail "$name" "code=$code out=$out (expected --cd $expected_cd)"
  fi
}

# ---- 3: non-zero exit from pr-gate.sh is propagated --------------------------
case_exit_propagated() {
  # Verifies that pmctl_gate_run propagates the exit code from pr-gate.sh
  # so callers can detect gate failures without parsing output.
  #
  # Steps:
  #   1. Install a fake pr-gate.sh that exits 2.
  #   2. Call pmctl_gate_run with --cd /tmp.
  #   3. Assert the wrapper exits with the same code (2).
  local name="gate/run: non-zero exit from pr-gate.sh is propagated"
  should_run "$name" || return 0

  local fixture="$tmp_root/f3" wrapper="$tmp_root/b3/wrapper"
  mkdir -p "$(dirname "$wrapper")"
  _mk_fake_gate "$fixture" 2
  _mk_gate_wrapper "$fixture" "$wrapper"

  local code
  set +e; "$wrapper" --cd /tmp --lifecycle foreground >/dev/null 2>&1; code=$?; set -e

  if [[ "$code" -eq 2 ]]; then
    pass "$name"
  else
    fail "$name" "expected exit 2, got $code"
  fi
}

# ---- 4: gate script not found exits 2 ----------------------------------------
case_missing_gate_script() {
  # Verifies that pmctl_gate_run exits 2 with an error message when
  # scripts/pr-gate.sh is absent from the fixture repo root, so the failure
  # is explicit rather than a confusing exec error.
  #
  # Steps:
  #   1. Create a fixture with the pmctl-gate.sh lib but no pr-gate.sh.
  #   2. Call the wrapper with --cd /tmp.
  #   3. Assert exit code is 2 and stderr contains "not found" or "not executable".
  local name="gate/run: missing pr-gate.sh exits 2"
  should_run "$name" || return 0

  local fixture="$tmp_root/f4" wrapper="$tmp_root/b4/wrapper"
  mkdir -p "$(dirname "$wrapper")" "$fixture/scripts/lib"
  cp "$REPO_ROOT/scripts/lib/pmctl-gate.sh" "$fixture/scripts/lib/pmctl-gate.sh"
  cat > "$wrapper" <<WRAPPER
#!/usr/bin/env bash
set -euo pipefail
. "$fixture/scripts/lib/pmctl-gate.sh"
pmctl_gate_run "$fixture" "\$@"
WRAPPER
  chmod +x "$wrapper"

  local err code
  set +e; err="$("$wrapper" --cd /tmp 2>&1)"; code=$?; set -e

  if [[ "$code" -eq 2 ]] && [[ "$err" == *"not found"* || "$err" == *"not executable"* ]]; then
    pass "$name"
  else
    fail "$name" "code=$code err=$err"
  fi
}

# ---- 4b: --cd with no value is a usage error, not "use $PWD" ----------------
case_cd_missing_value_rejected() {
  # CC-423 pr-gate finding (critic/qa-tester, high): the --cd extraction loop
  # only checked array bounds, not whether --cd actually had a following
  # value, so a trailing `--cd` (or `--cd` immediately followed by another
  # flag, which is what remains after --lifecycle is stripped) silently fell
  # back to $PWD instead of erroring. Under the default (detached) lifecycle
  # this meant a malformed `pmctl gate run --cd --lifecycle detached` still
  # returned a "successful" gate_id for a supervisor launched against the
  # wrong directory. Both lifecycles must reject it explicitly.
  local name="gate/run: --cd with no value is rejected (exit 2)"
  should_run "$name" || return 0

  local fixture="$tmp_root/f4b"
  _mk_fake_gate "$fixture" 0

  local wrapper="$tmp_root/b4b/wrapper"
  mkdir -p "$(dirname "$wrapper")"
  _mk_gate_wrapper "$fixture" "$wrapper"

  local err code
  set +e; err="$("$wrapper" --cd 2>&1)"; code=$?; set -e
  if [[ "$code" -ne 2 ]] || [[ "$err" != *"missing value for --cd"* ]]; then
    fail "$name" "foreground (default detached, bare --cd): code=$code err=$err"
    return
  fi

  set +e; err="$("$wrapper" --lifecycle foreground --cd 2>&1)"; code=$?; set -e
  if [[ "$code" -ne 2 ]] || [[ "$err" != *"missing value for --cd"* ]]; then
    fail "$name" "explicit foreground, bare --cd: code=$code err=$err"
    return
  fi

  set +e; err="$("$wrapper" --lifecycle detached --cd 2>&1)"; code=$?; set -e
  if [[ "$code" -ne 2 ]] || [[ "$err" != *"missing value for --cd"* ]]; then
    fail "$name" "explicit detached, bare --cd: code=$code err=$err"
    return
  fi

  pass "$name"
}

# ---- 5: pmctl binary routes gate/run without error ---------------------------
case_pmctl_routing() {
  # Verifies that the top-level cli/pmctl binary recognises the gate/run
  # subcommand and delegates to scripts/pr-gate.sh, confirming the routing
  # table entry and lib load are both present.
  #
  # Steps:
  #   1. Call pmctl gate run --lifecycle foreground --help against the real
  #      repo binary (foreground forced explicitly: default lifecycle is
  #      detached (CC-423), which would fork a real background supervisor
  #      instead of forwarding --help synchronously).
  #   2. Assert exit code is 0 (pr-gate.sh --help exits 0).
  #   3. Assert stdout contains "--cd" (confirming pr-gate.sh usage was reached).
  local name="gate/run: pmctl cli routes gate/run subcommand"
  should_run "$name" || return 0

  local out code
  set +e; out="$("$PMCTL" gate run --lifecycle foreground --help 2>&1)"; code=$?; set -e

  if [[ "$code" -eq 0 ]] && [[ "$out" == *"--cd"* ]]; then
    pass "$name"
  else
    fail "$name" "code=$code out=$(printf '%s' "$out" | head -3)"
  fi
}

# ---- 5b: --help stays synchronous even with the default (detached) lifecycle
case_help_bypasses_detached_default() {
  # CC-423 pr-gate finding (critic, medium): flipping the default lifecycle
  # to detached silently turned `pmctl gate run --help` (no --lifecycle flag)
  # into a detached launch instead of synchronous usage output. Verifies the
  # fix: -h/--help always forwards synchronously regardless of lifecycle.
  local name="gate/run: --help forwards synchronously under the default (detached) lifecycle"
  should_run "$name" || return 0

  local out code
  set +e; out="$("$PMCTL" gate run --help 2>&1)"; code=$?; set -e

  if [[ "$code" -eq 0 ]] && [[ "$out" == *"--cd"* ]] && [[ "$out" != gate-* ]]; then
    pass "$name"
  else
    fail "$name" "code=$code out=$(printf '%s' "$out" | head -3) (expected synchronous usage text, not a bare gate_id)"
  fi
}

# Write a structurally valid pr_gate_result_v1 file. Optional overrides:
#   $2 body Final: value (default GO)   $3 frontmatter final: value (default = $2)
_mk_gate_result() {
  local path="$1" body_final="${2:-GO}" fm_final="${3:-${2:-GO}}"
  mkdir -p "$(dirname "$path")"
  cat > "$path" <<RESULT
---
gate_result_version: pr_gate_result_v1
final: ${fm_final}
tier: express
mode: sequential
most_severe: approve
---

# PR-Gate Result

## stub-reviewer -- approve
- ok

## Gate Conclusion
Final: ${body_final}
RESULT
}

# ---- 6: gate verify accepts a structurally valid result ----------------------
case_verify_valid() {
  local name="gate/verify: valid result exits 0"
  should_run "$name" || return 0
  local result="$tmp_root/v6/result.md"
  _mk_gate_result "$result" GO
  local out code
  set +e; out="$("$PMCTL" gate verify "$result" 2>&1)"; code=$?; set -e
  if [[ "$code" -eq 0 ]] && [[ "$out" == *"gate result OK"* ]]; then
    pass "$name"
  else
    fail "$name" "code=$code out=$out"
  fi
}

# ---- 7: gate verify rejects an empty (0-byte) result -------------------------
case_verify_empty() {
  # The exact failure mode pmctl gate verify exists to catch: a session that
  # exited 0 without writing a verdict.
  local name="gate/verify: empty result exits 1"
  should_run "$name" || return 0
  local result="$tmp_root/v7/result.md"
  mkdir -p "$(dirname "$result")"; : > "$result"
  local out code
  set +e; out="$("$PMCTL" gate verify "$result" 2>&1)"; code=$?; set -e
  if [[ "$code" -eq 1 ]] && [[ "$out" == *"did not produce the result file"* ]]; then
    pass "$name"
  else
    fail "$name" "code=$code out=$out"
  fi
}

# ---- 8: gate verify rejects a result with no Final line ----------------------
case_verify_no_final() {
  local name="gate/verify: result without a Final line exits 1"
  should_run "$name" || return 0
  local result="$tmp_root/v8/result.md"
  mkdir -p "$(dirname "$result")"
  printf 'no verdict here\n' > "$result"
  local out code
  set +e; out="$("$PMCTL" gate verify "$result" 2>&1)"; code=$?; set -e
  if [[ "$code" -eq 1 ]] && [[ "$out" == *"must contain exactly one Final"* ]]; then
    pass "$name"
  else
    fail "$name" "code=$code out=$out"
  fi
}

# ---- 9: gate verify rejects frontmatter/body Final disagreement --------------
case_verify_parity_mismatch() {
  local name="gate/verify: frontmatter/body Final mismatch exits 1"
  should_run "$name" || return 0
  local result="$tmp_root/v9/result.md"
  _mk_gate_result "$result" GO NO-GO   # body GO, frontmatter NO-GO
  local out code
  set +e; out="$("$PMCTL" gate verify "$result" 2>&1)"; code=$?; set -e
  if [[ "$code" -eq 1 ]] && [[ "$out" == *"does not match body Final"* ]]; then
    pass "$name"
  else
    fail "$name" "code=$code out=$out"
  fi
}

# ---- 10: gate verify with no file argument is a usage error ------------------
case_verify_usage() {
  local name="gate/verify: missing file argument exits 2"
  should_run "$name" || return 0
  local out code
  set +e; out="$("$PMCTL" gate verify 2>&1)"; code=$?; set -e
  if [[ "$code" -eq 2 ]] && [[ "$out" == *"usage: pmctl gate verify"* ]]; then
    pass "$name"
  else
    fail "$name" "code=$code out=$out"
  fi
}

# ---- 11: pmctl gate run forwards --run-dir to pr-gate.sh --------------------
case_run_dir_forwarded_to_gate() {
  # Verifies that pmctl_gate_run computes a run dir keyed to the --cd target repo
  # and passes it as --run-dir <abs> to pr-gate.sh, and that different --cd targets
  # produce different run dir partitions (proving the key is target-repo-specific).
  #
  # Steps:
  #   1. Install a fake pr-gate.sh that echoes its argv.
  #   2. Copy state-paths.sh and its dependencies into the fixture lib dir.
  #   3. Call pmctl_gate_run with --cd <dir1> and --cd <dir2> separately.
  #   4. Assert both echoed arg sets contain --run-dir <abs>.
  #   5. Assert the two --run-dir values differ (different partition keys).
  local name="gate/run: --run-dir forwarded keyed to target repo partition"
  should_run "$name" || return 0

  local fixture="$tmp_root/f11" wrapper="$tmp_root/b11/wrapper"
  mkdir -p "$(dirname "$wrapper")"
  _mk_fake_gate "$fixture" 0
  _mk_gate_wrapper "$fixture" "$wrapper"

  # Provide the real state-paths lib (and its dependencies) so sw_project_run_dir is available.
  mkdir -p "$fixture/scripts/lib"
  for _lib in state-paths.sh portable.sh; do
    if [[ -f "$REPO_ROOT/scripts/lib/$_lib" ]]; then
      cp "$REPO_ROOT/scripts/lib/$_lib" "$fixture/scripts/lib/$_lib"
    fi
  done

  local dir1 dir2; dir1="$(mktemp -d)"; dir2="$(mktemp -d)"
  local out1 out2 code1 code2
  set +e
  out1="$("$wrapper" --cd "$dir1" --lifecycle foreground 2>&1)"; code1=$?
  out2="$("$wrapper" --cd "$dir2" --lifecycle foreground 2>&1)"; code2=$?
  set -e
  rm -rf "$dir1" "$dir2"

  if [[ "$code1" -ne 0 || "$code2" -ne 0 ]]; then
    fail "$name" "wrapper failed (code1=$code1 code2=$code2)"
    return
  fi
  if [[ "$out1" != *"--run-dir /"* || "$out2" != *"--run-dir /"* ]]; then
    fail "$name" "expected --run-dir <abs> in both calls; out1=$out1 out2=$out2"
    return
  fi
  # Extract the --run-dir values and verify they differ (different partition keys).
  local rundir1 rundir2
  rundir1="$(printf '%s\n' "$out1" | grep -o -- '--run-dir [^ ]*' | awk '{print $2}' || true)"
  rundir2="$(printf '%s\n' "$out2" | grep -o -- '--run-dir [^ ]*' | awk '{print $2}' || true)"
  if [[ "$rundir1" == "$rundir2" ]]; then
    fail "$name" "--run-dir values are identical for different --cd targets: $rundir1"
    return
  fi
  pass "$name"
}

# ---- 12: omitting --lifecycle defaults to detached (CC-423) ------------------
case_default_lifecycle_is_detached() {
  # Verifies that pmctl_gate_run with no --lifecycle flag now takes the
  # detached path (returns a bare gate_id, does not synchronously exec
  # pr-gate.sh), mirroring dispatch's default. scripts/test-gate-lifecycle.sh
  # covers the detached mechanics (supervisor, wait, sentinel) in depth; this
  # case only proves the default routing decision.
  local name="gate/run: omitting --lifecycle defaults to detached"
  should_run "$name" || return 0

  local fixture="$tmp_root/f12" wrapper="$tmp_root/b12/wrapper" work="$tmp_root/f12-work"
  mkdir -p "$(dirname "$wrapper")" "$work"
  _mk_fake_gate "$fixture" 0
  _mk_gate_wrapper "$fixture" "$wrapper"
  cp "$REPO_ROOT/scripts/gate-supervisor.sh" "$fixture/scripts/gate-supervisor.sh"
  chmod +x "$fixture/scripts/gate-supervisor.sh"
  for _lib in state-paths.sh portable.sh; do
    cp "$REPO_ROOT/scripts/lib/$_lib" "$fixture/scripts/lib/$_lib"
  done

  local out code
  PM_DISPATCH_STATE_ROOT="$tmp_root/f12-state" XDG_RUNTIME_DIR="$tmp_root/f12-xdg"
  mkdir -p "$XDG_RUNTIME_DIR"; chmod 700 "$XDG_RUNTIME_DIR"
  set +e
  out="$(PM_DISPATCH_STATE_ROOT="$PM_DISPATCH_STATE_ROOT" XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" \
    "$wrapper" --cd "$work" 2>&1)"
  code=$?
  set -e

  if [[ "$code" -eq 0 ]] && [[ "$out" =~ ^gate-[0-9]{8}-[0-9]{6}-[A-Za-z0-9]{6,}$ ]]; then
    pass "$name"
  else
    fail "$name" "code=$code out=$out (expected a bare gate_id, not synchronous pr-gate.sh output)"
  fi
}

# ---- 13/14: gate/wait routed through the REAL cli/pmctl binary (GO/NO-GO) ----
# scripts/test-gate-lifecycle.sh drives pmctl_gate_run_detached/pmctl_gate_wait
# by sourcing pmctl-gate.sh directly, which never exercises cli/pmctl's own
# `case "$cmd/$sub" in gate/wait) ...` routing-table entry -- that entry could
# regress (typo, wrong function name) while the lifecycle-library tests still
# pass. These two cases copy the REAL cli/pmctl into a fixture (cli/pmctl
# resolves REPO_ROOT from its own script location, so this makes it treat the
# fixture as REPO_ROOT) and drive `gate run --lifecycle detached` +
# `gate wait` end to end through it for both a GO and a NO-GO outcome.
_run_gate_cli_route_case() {
  local name="$1" gate_code="$2" expect_state="$3" expect_exit="$4"
  should_run "$name" || return 0

  local fixture="$tmp_root/${name//[^A-Za-z0-9]/-}/fixture"
  local work="$tmp_root/${name//[^A-Za-z0-9]/-}/work"
  local state="$tmp_root/${name//[^A-Za-z0-9]/-}/state"
  mkdir -p "$work"
  _mk_gate_cli_fixture "$fixture"
  _mk_fake_gate_with_result "$fixture" "$gate_code"

  local cli_pmctl="$fixture/cli/pmctl"
  local gate_id out1 code1
  set +e
  gate_id="$(PM_DISPATCH_STATE_ROOT="$state" XDG_RUNTIME_DIR="$_GATE_CLI_XDG_RUNTIME_DIR" \
    PM_GATE_WAIT_POLL_INTERVAL=0.1 \
    "$cli_pmctl" gate run --cd "$work" --lifecycle detached 2>&1)"
  code1=$?
  set -e
  if [[ "$code1" -ne 0 ]] || ! [[ "$gate_id" =~ ^gate-[0-9]{8}-[0-9]{6}-[A-Za-z0-9]{6,}$ ]]; then
    fail "$name" "gate run --lifecycle detached via cli/pmctl failed: code=$code1 out=$gate_id"
    return
  fi

  local out2 code2
  set +e
  out2="$(PM_DISPATCH_STATE_ROOT="$state" XDG_RUNTIME_DIR="$_GATE_CLI_XDG_RUNTIME_DIR" \
    PM_GATE_WAIT_POLL_INTERVAL=0.1 \
    "$cli_pmctl" gate wait "$gate_id" --cd "$work" --timeout 30 2>&1)"
  code2=$?
  set -e

  if [[ "$code2" -eq "$expect_exit" ]] && [[ "$out2" == *"state: $expect_state"* ]]; then
    pass "$name"
  else
    fail "$name" "code1=$code1 gate_id=$gate_id code2=$code2 (expected $expect_exit) out2=$out2"
  fi
}

case_gate_wait_go_route_via_cli() {
  _run_gate_cli_route_case "gate/wait: GO routed through real cli/pmctl" 0 "GO" 0
}

case_gate_wait_nogo_route_via_cli() {
  _run_gate_cli_route_case "gate/wait: NO-GO routed through real cli/pmctl" 1 "NO-GO" 1
}

# ---- 15: /pr-gate's documented run/wait handoff survives a REAL process boundary
# CC-423 pr-gate finding (critic/qa-tester/architecture-reviewer/risk-reviewer,
# high, all four converged on the same root cause): commands/pr-gate.md's
# worked example captured `GATE_ID="$(...)"` in one Bash code block and reused
# `"$GATE_ID"` in a separate one, but each Bash tool call is an independent
# subprocess -- shell variables do not survive across calls, so the wait would
# receive an empty gate_id. The fix: read the captured stdout, substitute the
# LITERAL value into the next command (matching commands/pm.md's <run_id>
# convention). This case proves that literal-substitution handoff actually
# works by launching `gate run` and `gate wait` as two genuinely separate
# `bash -c` processes -- run's stdout is captured to a FILE (never a shell
# variable), and wait receives the id only via a substituted argv token, with
# no environment or variable inheritance connecting the two processes.
case_run_wait_handoff_survives_separate_process() {
  local name="gate/run+wait: documented literal-gate_id handoff survives a real process boundary"
  should_run "$name" || return 0

  local fixture="$tmp_root/f15/fixture" work="$tmp_root/f15/work" state="$tmp_root/f15/state"
  mkdir -p "$work"
  _mk_gate_cli_fixture "$fixture"
  _mk_fake_gate_with_result "$fixture" 0
  local cli_pmctl="$fixture/cli/pmctl"

  # "Bash call 1": run detached, capture stdout to a file only (the harness's
  # equivalent -- never assign to a variable this test could accidentally
  # smuggle into the next process).
  local id_file="$tmp_root/f15/gate_id.txt"
  env -i PATH="$PATH" HOME="$HOME" \
    PM_DISPATCH_STATE_ROOT="$state" XDG_RUNTIME_DIR="$_GATE_CLI_XDG_RUNTIME_DIR" \
    PM_GATE_WAIT_POLL_INTERVAL=0.1 \
    bash -c '"$1" gate run --cd "$2" --lifecycle detached' _ "$cli_pmctl" "$work" \
    > "$id_file" 2>"$tmp_root/f15/run.err"
  local run_code=$?
  local gate_id; gate_id="$(cat "$id_file" 2>/dev/null)"
  if [[ "$run_code" -ne 0 ]] || ! [[ "$gate_id" =~ ^gate-[0-9]{8}-[0-9]{6}-[A-Za-z0-9]{6,}$ ]]; then
    fail "$name" "run failed or produced no gate_id: code=$run_code gate_id=$gate_id err=$(cat "$tmp_root/f15/run.err" 2>/dev/null)"
    return
  fi

  # "Bash call 2": a BRAND NEW process (env -i: no inherited variables at
  # all) that only knows the gate_id because it was substituted into the
  # command string as a literal argv token -- exactly what the agent does
  # when it reads call 1's stdout and writes call 2's command.
  local out code
  set +e
  out="$(env -i PATH="$PATH" HOME="$HOME" \
    PM_DISPATCH_STATE_ROOT="$state" XDG_RUNTIME_DIR="$_GATE_CLI_XDG_RUNTIME_DIR" \
    PM_GATE_WAIT_POLL_INTERVAL=0.1 \
    bash -c "\"$cli_pmctl\" gate wait $gate_id --cd \"$work\" --timeout 30" 2>&1)"
  code=$?
  set -e

  if [[ "$code" -eq 0 ]] && [[ "$out" == *"state: GO"* ]]; then
    pass "$name"
  else
    fail "$name" "gate_id=$gate_id code=$code out=$out"
  fi
}

case_explicit_cd_passthrough
case_default_cd_injected
case_exit_propagated
case_missing_gate_script
case_cd_missing_value_rejected
case_pmctl_routing
case_help_bypasses_detached_default
case_verify_valid
case_verify_empty
case_verify_no_final
case_verify_parity_mismatch
case_verify_usage
case_run_dir_forwarded_to_gate
case_default_lifecycle_is_detached
case_gate_wait_go_route_via_cli
case_gate_wait_nogo_route_via_cli
case_run_wait_handoff_survives_separate_process

th_summary
