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

# ---- 3: fresh invocation re-execs from /tmp ----
# Trace via bash -x; assert exec line names a /tmp/codex-dispatch.* path.
trace_out="$(bash -x "$DISPATCH" --help 2>&1 1>/dev/null || true)"
if grep -E "exec /tmp/codex-dispatch\.[A-Za-z0-9]+\.sh" <<<"$trace_out" >/dev/null; then
  t_pass "snapshot/fresh invocation re-execs from /tmp"
else
  t_fail "snapshot/fresh invocation did NOT re-exec from /tmp"
  printf '  trace tail:\n%s\n' "$(printf '%s\n' "$trace_out" | tail -10 | sed 's/^/    /')" >&2
fi

# ---- 4: idempotent — CODEX_DISPATCH_SNAPSHOT_ACTIVE=1 skips snapshot block ----
trace_out="$(CODEX_DISPATCH_SNAPSHOT_ACTIVE=1 bash -x "$DISPATCH" --help 2>&1 1>/dev/null || true)"
if grep -E "exec /tmp/codex-dispatch\.[A-Za-z0-9]+\.sh" <<<"$trace_out" >/dev/null; then
  t_fail "snapshot/idempotent — re-exec fired even with CODEX_DISPATCH_SNAPSHOT_ACTIVE=1"
else
  t_pass "snapshot/idempotent — re-exec skipped when env var set"
fi

# ---- 5: snapshot file cleaned up on exit (no /tmp leak) ----
before=$(find /tmp -maxdepth 1 -name 'codex-dispatch.*.sh' 2>/dev/null | wc -l)
"$DISPATCH" --help >/dev/null 2>&1
after=$(find /tmp -maxdepth 1 -name 'codex-dispatch.*.sh' 2>/dev/null | wc -l)
if [[ "$after" -le "$before" ]]; then
  t_pass "snapshot/cleanup — no leaked /tmp/codex-dispatch.*.sh"
else
  t_fail "snapshot/cleanup — file count grew from $before to $after"
fi

# ---- 6: structural — snapshot block exists with expected guard env var ----
if grep -q 'CODEX_DISPATCH_SNAPSHOT_ACTIVE' "$DISPATCH"; then
  t_pass "snapshot/structural — guard env var present in source"
else
  t_fail "snapshot/structural — guard env var missing; snapshot block may have been removed"
fi

echo "----"
echo "$PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
