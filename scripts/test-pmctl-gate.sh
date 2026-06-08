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

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

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
  set +e; out="$("$wrapper" --cd /tmp --tier express 2>&1)"; code=$?; set -e

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
  set +e; out="$("$wrapper" --tier express 2>&1)"; code=$?; set -e

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
  set +e; "$wrapper" --cd /tmp >/dev/null 2>&1; code=$?; set -e

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

# ---- 5: pmctl binary routes gate/run without error ---------------------------
case_pmctl_routing() {
  # Verifies that the top-level cli/pmctl binary recognises the gate/run
  # subcommand and delegates to scripts/pr-gate.sh, confirming the routing
  # table entry and lib load are both present.
  #
  # Steps:
  #   1. Call pmctl gate run --help against the real repo binary.
  #   2. Assert exit code is 0 (pr-gate.sh --help exits 0).
  #   3. Assert stdout contains "--cd" (confirming pr-gate.sh usage was reached).
  local name="gate/run: pmctl cli routes gate/run subcommand"
  should_run "$name" || return 0

  local out code
  set +e; out="$("$PMCTL" gate run --help 2>&1)"; code=$?; set -e

  if [[ "$code" -eq 0 ]] && [[ "$out" == *"--cd"* ]]; then
    pass "$name"
  else
    fail "$name" "code=$code out=$(printf '%s' "$out" | head -3)"
  fi
}

case_explicit_cd_passthrough
case_default_cd_injected
case_exit_propagated
case_missing_gate_script
case_pmctl_routing

th_summary
