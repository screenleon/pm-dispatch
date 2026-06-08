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
  local name="gate/run: missing pr-gate.sh exits 2"
  should_run "$name" || return 0

  local fixture="$tmp_root/f4" wrapper="$tmp_root/b4/wrapper"
  mkdir -p "$(dirname "$wrapper")" "$fixture/scripts/lib"
  # No pr-gate.sh installed in this fixture.
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
  local name="gate/run: pmctl cli routes gate/run subcommand"
  should_run "$name" || return 0

  # --help reaches pr-gate.sh and exits 0; verifies the routing path works.
  local out code
  set +e; out="$("$PMCTL" gate run --help 2>&1)"; code=$?; set -e

  # pr-gate.sh --help prints usage and exits 0.
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
