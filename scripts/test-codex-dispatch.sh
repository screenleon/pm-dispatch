#!/usr/bin/env bash
# Regression tests for codex-dispatch.sh self-snapshot mechanism.
#
# Threat model: dispatching Codex against claude-config can rewrite
# codex-dispatch.sh while bash is still reading it line-by-line, corrupting
# execution. The snapshot block at the top of the script mitigates this by
# re-exec'ing from a /tmp copy decoupled from the on-disk file.
#
# Design: the snapshot trigger is BASH_SOURCE[0]'s shape, NOT an env var.
# Path verification (must look like `<dir>/codex-dispatch.XXXXXX.sh`) means
# polluted ambient environment cannot bypass the snapshot or trick the
# cleanup trap into removing an arbitrary file.
set -euo pipefail

# Clean baseline: even legacy env vars from earlier designs must not influence
# tests. (Defensive — current implementation ignores them entirely.)
unset CODEX_DISPATCH_SNAPSHOT_ACTIVE CODEX_DISPATCH_SNAPSHOT_PATH

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DISPATCH="$REPO_ROOT/scripts/codex-dispatch.sh"

PASS=0
FAIL=0

t_pass() { printf 'PASS: %s\n' "$1"; PASS=$((PASS+1)); }
t_fail() { printf 'FAIL: %s\n' "$1" >&2; FAIL=$((FAIL+1)); }

# Resolve the actual tmp dir mktemp -t uses (respects TMPDIR if set).
SNAP_DIR="$(dirname "$(mktemp -u -t codex-dispatch.XXXXXX.sh)")"
SNAP_RE="exec [^ ]*codex-dispatch\.[A-Za-z0-9]+\.sh"

# ---- 1: --help exits 0 ----
if "$DISPATCH" --help >/dev/null 2>&1; then
  t_pass "snapshot/--help exits 0"
else
  t_fail "snapshot/--help non-zero exit"
fi

# ---- 2: --help output preserved through re-exec ----
out="$("$DISPATCH" --help 2>&1)"
if grep -q "Wrapper for invoking" <<<"$out"; then
  t_pass "snapshot/--help output preserved"
else
  t_fail "snapshot/--help output corrupted"
fi

# ---- 3: fresh invocation re-execs from a snapshot copy ----
trace_out="$(bash -x "$DISPATCH" --help 2>&1 1>/dev/null || true)"
if grep -E "$SNAP_RE" <<<"$trace_out" >/dev/null; then
  t_pass "snapshot/fresh invocation re-execs from snapshot copy"
else
  t_fail "snapshot/fresh invocation did NOT re-exec from a snapshot copy"
  printf '  trace tail:\n%s\n' "$(printf '%s\n' "$trace_out" | tail -10 | sed 's/^/    /')" >&2
fi

# ---- 4: SECURITY — ambient env vars do NOT bypass the snapshot ----
# Inherited CODEX_DISPATCH_SNAPSHOT_ACTIVE=1 used to skip the snapshot block.
# The new design is env-agnostic: trigger is BASH_SOURCE shape, not env.
trace_out="$(CODEX_DISPATCH_SNAPSHOT_ACTIVE=1 \
  CODEX_DISPATCH_SNAPSHOT_PATH=/tmp/this-must-be-ignored \
  bash -x "$DISPATCH" --help 2>&1 1>/dev/null || true)"
if grep -E "$SNAP_RE" <<<"$trace_out" >/dev/null; then
  t_pass "snapshot/ambient-env-defense — fresh snapshot taken regardless of env vars"
else
  t_fail "snapshot/ambient-env-defense — env=1 bypassed snapshot; security regression"
fi

# ---- 5: SECURITY — ambient env path is NOT removed by cleanup trap ----
# An attacker who can pollute CODEX_DISPATCH_SNAPSHOT_PATH used to be able to
# trick the trap into rm-ing arbitrary user-writable files. Verify any inherited
# path is ignored — the cleanup trap targets only the freshly-created snapshot.
victim="$(mktemp)"
echo "do-not-delete" > "$victim"
CODEX_DISPATCH_SNAPSHOT_ACTIVE=1 CODEX_DISPATCH_SNAPSHOT_PATH="$victim" \
  "$DISPATCH" --help >/dev/null 2>&1
if [[ -f "$victim" && "$(cat "$victim")" == "do-not-delete" ]]; then
  t_pass "snapshot/ambient-path-defense — arbitrary inherited path NOT deleted"
  rm -f "$victim"
else
  t_fail "snapshot/ambient-path-defense — inherited path was deleted; security regression"
fi

# ---- 6: cleanup on normal exit (no leak in resolved tmp dir) ----
before=$(find "$SNAP_DIR" -maxdepth 1 -name 'codex-dispatch.*.sh' 2>/dev/null | wc -l)
"$DISPATCH" --help >/dev/null 2>&1
after=$(find "$SNAP_DIR" -maxdepth 1 -name 'codex-dispatch.*.sh' 2>/dev/null | wc -l)
if [[ "$after" -le "$before" ]]; then
  t_pass "snapshot/cleanup — no leak in $SNAP_DIR (before=$before after=$after)"
else
  t_fail "snapshot/cleanup — file count grew from $before to $after in $SNAP_DIR"
fi

# ---- 7: structural — snapshot block has all required constructs ----
# Stronger than just one keyword; guards against a partial-revert that
# silently breaks the mechanism while keeping a token of the original block.
missing=()
grep -qE 'BASH_SOURCE\[0\].*codex-dispatch\\\.\[A-Za-z0-9\]\{6\}\\\.sh' "$DISPATCH" \
  || missing+=("BASH_SOURCE path-pattern check")
grep -q 'mktemp -t codex-dispatch'                 "$DISPATCH" || missing+=("mktemp template")
grep -q 'cp -- "\${BASH_SOURCE\[0\]}"'             "$DISPATCH" || missing+=("cp from BASH_SOURCE")
grep -q 'chmod +x'                                  "$DISPATCH" || missing+=("chmod +x")
grep -qE 'exec "\$__codex_dispatch_snapshot"'      "$DISPATCH" || missing+=("exec snapshot")
grep -qE "trap.*rm -f.*\\\$__codex_dispatch_snapshot" "$DISPATCH" || missing+=("cleanup trap")
if [[ "${#missing[@]}" -eq 0 ]]; then
  t_pass "snapshot/structural — all snapshot-block constructs present"
else
  t_fail "snapshot/structural — missing: ${missing[*]}"
fi

echo "----"
echo "$PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
