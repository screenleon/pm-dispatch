#!/usr/bin/env bash
# Regression tests for codex-dispatch.sh self-snapshot mechanism.
#
# Threat model: dispatching Codex against claude-config can rewrite
# codex-dispatch.sh while bash is still reading it line-by-line, corrupting
# execution. The snapshot block at the top of the script mitigates this by
# re-exec'ing from a /tmp copy decoupled from the on-disk file.
#
# These tests verify the mechanism without invoking `codex` (no external
# dependency, no network).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DISPATCH="$REPO_ROOT/scripts/codex-dispatch.sh"

PASS=0
FAIL=0

t_pass() { printf 'PASS: %s\n' "$1"; PASS=$((PASS+1)); }
t_fail() { printf 'FAIL: %s\n' "$1" >&2; FAIL=$((FAIL+1)); }

# ---- 1: --help exits 0 (snapshot block does not break basic flow) ----
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
  printf '  got: %s\n' "$out" >&2
fi

# Resolve the actual tmp dir mktemp -t uses (respects TMPDIR if set, else /tmp).
SNAP_DIR="$(dirname "$(mktemp -u -t codex-dispatch.XXXXXX.sh)")"
SNAP_RE="exec [^ ]*codex-dispatch\.[A-Za-z0-9_]+\.sh"

# ---- 3: fresh invocation re-execs from a snapshot copy ----
# Trace via bash -x; assert exec line names a codex-dispatch.* snapshot
# regardless of the resolved TMPDIR (sandboxed envs can override it).
trace_out="$(bash -x "$DISPATCH" --help 2>&1 1>/dev/null || true)"
if grep -E "$SNAP_RE" <<<"$trace_out" >/dev/null; then
  t_pass "snapshot/fresh invocation re-execs from snapshot copy"
else
  t_fail "snapshot/fresh invocation did NOT re-exec from a snapshot copy"
  printf '  trace tail:\n%s\n' "$(printf '%s\n' "$trace_out" | tail -10 | sed 's/^/    /')" >&2
fi

# ---- 4: idempotent — CODEX_DISPATCH_SNAPSHOT_ACTIVE=1 skips snapshot block ----
trace_out="$(CODEX_DISPATCH_SNAPSHOT_ACTIVE=1 bash -x "$DISPATCH" --help 2>&1 1>/dev/null || true)"
if grep -E "$SNAP_RE" <<<"$trace_out" >/dev/null; then
  t_fail "snapshot/idempotent — re-exec fired even with CODEX_DISPATCH_SNAPSHOT_ACTIVE=1"
else
  t_pass "snapshot/idempotent — re-exec skipped when env var set"
fi

# ---- 5: snapshot file cleaned up on exit (no leak in resolved tmp dir) ----
before=$(find "$SNAP_DIR" -maxdepth 1 -name 'codex-dispatch.*.sh' 2>/dev/null | wc -l)
"$DISPATCH" --help >/dev/null 2>&1
after=$(find "$SNAP_DIR" -maxdepth 1 -name 'codex-dispatch.*.sh' 2>/dev/null | wc -l)
if [[ "$after" -le "$before" ]]; then
  t_pass "snapshot/cleanup — no leaked codex-dispatch.*.sh in $SNAP_DIR"
else
  t_fail "snapshot/cleanup — file count grew from $before to $after in $SNAP_DIR"
fi

# ---- 6: structural — snapshot block has all required constructs ----
# Stronger than just grepping the env-var name; verifies the mechanism is
# wired together (mktemp + cp + chmod + exec + cleanup trap).
missing=()
grep -q 'CODEX_DISPATCH_SNAPSHOT_ACTIVE' "$DISPATCH" || missing+=("guard env var")
grep -q 'mktemp -t codex-dispatch'        "$DISPATCH" || missing+=("mktemp template")
grep -q 'cp -- "\${BASH_SOURCE\[0\]}"'    "$DISPATCH" || missing+=("cp from BASH_SOURCE")
grep -q 'chmod +x'                        "$DISPATCH" || missing+=("chmod +x")
grep -qE 'exec "\$__codex_dispatch_snapshot"' "$DISPATCH" || missing+=("exec snapshot")
grep -q "trap.*rm -f.*CODEX_DISPATCH_SNAPSHOT_PATH" "$DISPATCH" || missing+=("cleanup trap")
if [[ "${#missing[@]}" -eq 0 ]]; then
  t_pass "snapshot/structural — all snapshot-block constructs present"
else
  t_fail "snapshot/structural — missing: ${missing[*]}"
fi

echo "----"
echo "$PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
