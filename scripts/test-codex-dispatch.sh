#!/usr/bin/env bash
# Regression tests for codex-dispatch.sh self-snapshot mechanism.
#
# Threat model: dispatching Codex against claude-config can rewrite
# codex-dispatch.sh while bash is still reading it line-by-line, corrupting
# execution. The snapshot block at the top of the script mitigates this by
# re-exec'ing from a /tmp copy decoupled from the on-disk file.
#
# Design: the snapshot trigger is BASH_SOURCE[0]'s shape, NOT an env var.
# Path verification (must look like `<tmp>/codex-dispatch.XXXXXX/codex-dispatch.sh`) means
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
SNAP_DIR="$(dirname "$(mktemp -u -t codex-dispatch.XXXXXX)")"
SNAP_RE="exec [^ ]*codex-dispatch\.[A-Za-z0-9]+/codex-dispatch\.sh"

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
before=$(find "$SNAP_DIR" -maxdepth 1 -type d -name 'codex-dispatch.*' 2>/dev/null | wc -l)
"$DISPATCH" --help >/dev/null 2>&1
after=$(find "$SNAP_DIR" -maxdepth 1 -type d -name 'codex-dispatch.*' 2>/dev/null | wc -l)
if [[ "$after" -le "$before" ]]; then
  t_pass "snapshot/cleanup — no leak in $SNAP_DIR (before=$before after=$after)"
else
  t_fail "snapshot/cleanup — file count grew from $before to $after in $SNAP_DIR"
fi

# ---- 7: structural — snapshot block has all required constructs ----
# Stronger than just one keyword; guards against a partial-revert that
# silently breaks the mechanism while keeping a token of the original block.
missing=()
grep -qE 'BASH_SOURCE\[0\].*codex-dispatch\\\.\[A-Za-z0-9\]\{6\}/codex-dispatch\\\.sh' "$DISPATCH" \
  || missing+=("BASH_SOURCE path-pattern check")
grep -q 'mktemp -d -t codex-dispatch'              "$DISPATCH" || missing+=("mktemp template")
grep -q 'cp -- "\${BASH_SOURCE\[0\]}"'             "$DISPATCH" || missing+=("cp from BASH_SOURCE")
grep -q 'chmod +x'                                  "$DISPATCH" || missing+=("chmod +x")
grep -qE 'exec "\$__codex_dispatch_snapshot"'      "$DISPATCH" || missing+=("exec snapshot")
grep -qE "trap.*rm -rf.*\\\$__codex_dispatch_snapshot_dir" "$DISPATCH" || missing+=("cleanup trap")
if [[ "${#missing[@]}" -eq 0 ]]; then
  t_pass "snapshot/structural — all snapshot-block constructs present"
else
  t_fail "snapshot/structural — missing: ${missing[*]}"
fi

# ---- 8: dispatch startup does not mutate .gitignore ----
tmp_repo="$(mktemp -d)"
git init -q "$tmp_repo"
printf '*.log\n' > "$tmp_repo/.gitignore"
before="$(sha256sum "$tmp_repo/.gitignore" | awk '{print $1}')"
"$DISPATCH" --help >/dev/null 2>&1
"$DISPATCH" --cd "$tmp_repo" --brief-file "$tmp_repo/missing-brief.md" >/dev/null 2>&1 || true
after="$(sha256sum "$tmp_repo/.gitignore" | awk '{print $1}')"
if [[ "$after" == "$before" ]]; then
  t_pass "dispatch/does-not-mutate-gitignore"
else
  t_fail "dispatch/does-not-mutate-gitignore — checksum changed"
fi
rm -rf "$tmp_repo"

# ---- 9: auto-log/parser emits exactly one integer ----
tmp_trace9="$(mktemp)"
printf '%s\n' \
  '{"type":"turn.started"}' \
  '{"type":"turn.completed","usage":{"input_tokens":100000,"output_tokens":5000,"cached_input_tokens":0}}' \
  > "$tmp_trace9"
_result9=$(python3 - "$tmp_trace9" << 'PYEOF'
import json, sys
for line in open(sys.argv[1]):
    try:
        e = json.loads(line.strip())
        if e.get('type') == 'turn.completed':
            u = e.get('usage', {})
            print(u.get('input_tokens',0) + u.get('output_tokens',0))
            sys.exit(0)
    except Exception: pass
print(0)
PYEOF
)
rm -f "$tmp_trace9"
# Must be exactly "105000" — one line, one integer
if [[ "$_result9" == "105000" ]]; then
  t_pass "auto-log/parser-single-integer"
else
  t_fail "auto-log/parser-single-integer — got: $(printf '%q' "$_result9")"
fi

# ---- 10: auto-log/successful-dispatch-logs-codex ----
_fake_bin10="$(mktemp -d)"
cat > "$_fake_bin10/codex" << 'FAKEOF'
#!/usr/bin/env bash
# Fake codex: write a minimal trace to stdout (captured to TRACE by dispatch)
printf '%s\n' \
  '{"type":"turn.started"}' \
  '{"type":"turn.completed","usage":{"input_tokens":100000,"output_tokens":5000,"cached_input_tokens":0,"reasoning_output_tokens":0}}'
exit 0
FAKEOF
chmod +x "$_fake_bin10/codex"

_home10="$(mktemp -d)"
mkdir -p "$_home10/.claude/scripts"
ln -s "$REPO_ROOT/scripts/log-usage.sh" "$_home10/.claude/scripts/log-usage.sh"

_work10="$(mktemp -d)"
git init -q "$_work10"

_brief10="$(mktemp --suffix=.md)"
printf 'working_dir: %s\ngoal: test auto-log\n' "$_work10" > "$_brief10"

PATH="$_fake_bin10:$PATH" HOME="$_home10" \
  "$DISPATCH" --cd "$_work10" --brief-file "$_brief10" >/dev/null 2>&1
_exit10=$?

_tracker10="$_home10/.claude/usage-tracker.jsonl"
if [[ -f "$_tracker10" ]] && grep -q '"type":"codex_dispatch"' "$_tracker10" \
   && grep -q '"pool":"codex"' "$_tracker10" \
   && grep -q '"tokens":105000' "$_tracker10"; then
  t_pass "auto-log/successful-dispatch-logs-codex"
else
  t_fail "auto-log/successful-dispatch-logs-codex — exit=$_exit10 tracker=$(cat "$_tracker10" 2>/dev/null || echo MISSING)"
fi
rm -rf "$_fake_bin10" "$_home10" "$_work10"
rm -f "$_brief10"

# ---- 11: auto-log/failed-dispatch-no-log ----
_fake_bin11="$(mktemp -d)"
cat > "$_fake_bin11/codex" << 'FAKEOF'
#!/usr/bin/env bash
exit 1
FAKEOF
chmod +x "$_fake_bin11/codex"

_home11="$(mktemp -d)"
mkdir -p "$_home11/.claude/scripts"
ln -s "$REPO_ROOT/scripts/log-usage.sh" "$_home11/.claude/scripts/log-usage.sh"

_work11="$(mktemp -d)"
git init -q "$_work11"

_brief11="$(mktemp --suffix=.md)"
printf 'goal: test\n' > "$_brief11"

PATH="$_fake_bin11:$PATH" HOME="$_home11" \
  "$DISPATCH" --cd "$_work11" --brief-file "$_brief11" >/dev/null 2>&1 || true

if [[ ! -f "$_home11/.claude/usage-tracker.jsonl" ]]; then
  t_pass "auto-log/failed-dispatch-no-log"
else
  t_fail "auto-log/failed-dispatch-no-log — tracker was created despite failure"
fi
rm -rf "$_fake_bin11" "$_home11" "$_work11"
rm -f "$_brief11"

# ---- 12: auto-log/spark-model-logs-spark-pool ----
_fake_bin12="$(mktemp -d)"
cat > "$_fake_bin12/codex" << 'FAKEOF'
#!/usr/bin/env bash
printf '%s\n' \
  '{"type":"turn.started"}' \
  '{"type":"turn.completed","usage":{"input_tokens":50000,"output_tokens":2000,"cached_input_tokens":0,"reasoning_output_tokens":0}}'
exit 0
FAKEOF
chmod +x "$_fake_bin12/codex"

_home12="$(mktemp -d)"
mkdir -p "$_home12/.claude/scripts"
ln -s "$REPO_ROOT/scripts/log-usage.sh" "$_home12/.claude/scripts/log-usage.sh"

_work12="$(mktemp -d)"
git init -q "$_work12"

_brief12="$(mktemp --suffix=.md)"
printf 'goal: spark test\n' > "$_brief12"

PATH="$_fake_bin12:$PATH" HOME="$_home12" \
  "$DISPATCH" --cd "$_work12" --brief-file "$_brief12" --model codex-spark >/dev/null 2>&1
_exit12=$?

_tracker12="$_home12/.claude/usage-tracker.jsonl"
if [[ -f "$_tracker12" ]] && grep -q '"type":"codex_dispatch"' "$_tracker12" \
   && grep -q '"pool":"spark"' "$_tracker12" \
   && grep -q '"tokens":52000' "$_tracker12"; then
  t_pass "auto-log/spark-model-logs-spark-pool"
else
  t_fail "auto-log/spark-model-logs-spark-pool — exit=$_exit12 tracker=$(cat "$_tracker12" 2>/dev/null || echo MISSING)"
fi
rm -rf "$_fake_bin12" "$_home12" "$_work12"
rm -f "$_brief12"

# ---- 13: auto-log/log-failure-preserves-dispatch-exit ----
_fake_bin13="$(mktemp -d)"
cat > "$_fake_bin13/codex" << 'FAKEOF'
#!/usr/bin/env bash
printf '%s\n' \
  '{"type":"turn.started"}' \
  '{"type":"turn.completed","usage":{"input_tokens":10000,"output_tokens":500}}'
exit 0
FAKEOF
chmod +x "$_fake_bin13/codex"

_home13="$(mktemp -d)"
mkdir -p "$_home13/.claude/scripts"
# Deliberately no log-usage.sh so the auto-log call fails

_work13="$(mktemp -d)"
git init -q "$_work13"

_brief13="$(mktemp --suffix=.md)"
printf 'goal: test logging failure\n' > "$_brief13"

PATH="$_fake_bin13:$PATH" HOME="$_home13" \
  "$DISPATCH" --cd "$_work13" --brief-file "$_brief13" >/dev/null 2>&1
_exit13=$?

# Find the stderr trace file written by dispatch
_stderr13="$(ls "$_work13/.agent-trace/"*.stderr 2>/dev/null | head -1)"
if [[ "$_exit13" -eq 0 && -n "$_stderr13" ]] && grep -q "usage log failed" "$_stderr13"; then
  t_pass "auto-log/log-failure-preserves-dispatch-exit"
else
  t_fail "auto-log/log-failure-preserves-dispatch-exit — exit=$_exit13 stderr=$(cat "$_stderr13" 2>/dev/null | tail -5 || echo MISSING)"
fi
rm -rf "$_fake_bin13" "$_home13" "$_work13"
rm -f "$_brief13"

echo "----"
echo "$PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
