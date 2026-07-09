#!/usr/bin/env bash
# Regression tests for adapters/opencode/dispatch.sh
# Uses a FAKE `opencode` binary so the suite never depends on a real opencode CLI.
# Covers: arg validation, alias resolution, isolation mapping, fallback chain,
# session.error detection, per-attempt .last scoping, and legacy flag warnings.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DISPATCH="$REPO_ROOT/adapters/opencode/dispatch.sh"
PMCTL="$REPO_ROOT/cli/pmctl"

# shellcheck source=scripts/lib/test-harness.sh
. "$SCRIPT_DIR/lib/test-harness.sh"
th_init "$@"

# ── Fake opencode helpers ─────────────────────────────────────────────────────

# Install a fake opencode that emits text + step_finish and exits 0.
_fake_opencode_success() {
  local bindir="$1" text="${2:-dispatch complete}"
  cat > "$bindir/opencode" <<FAKEOF
#!/usr/bin/env bash
printf '%s\n' '{"type":"text","part":{"text":"$text"}}'
printf '%s\n' '{"type":"step_finish","part":{"reason":"stop","tokens":{}}}'
exit 0
FAKEOF
  chmod +x "$bindir/opencode"
}

# Install a fake opencode: first call → session.error, subsequent calls → success.
# Counter file path is embedded at install time.
_fake_opencode_fallback() {
  local bindir="$1" counter="$2" success_text="${3:-fallback success}"
  cat > "$bindir/opencode" <<FAKEOF
#!/usr/bin/env bash
_n=0
[[ -f "$counter" ]] && _n=\$(cat "$counter")
_n=\$(( _n + 1 ))
printf '%d' "\$_n" > "$counter"
if [[ "\$_n" -eq 1 ]]; then
  printf '%s\n' '{"type":"session.error","content":"quota"}'
  exit 0
fi
printf '%s\n' '{"type":"text","part":{"text":"$success_text"}}'
printf '%s\n' '{"type":"step_finish","part":{"reason":"stop","tokens":{}}}'
exit 0
FAKEOF
  chmod +x "$bindir/opencode"
}

# Install a fake opencode: first call emits text THEN session.error (tests .last scoping),
# second call emits different text + step_finish.
_fake_opencode_scope_test() {
  local bindir="$1" counter="$2"
  cat > "$bindir/opencode" <<FAKEOF
#!/usr/bin/env bash
_n=0
[[ -f "$counter" ]] && _n=\$(cat "$counter")
_n=\$(( _n + 1 ))
printf '%d' "\$_n" > "$counter"
if [[ "\$_n" -eq 1 ]]; then
  printf '%s\n' '{"type":"text","part":{"text":"SHOULD NOT APPEAR"}}'
  printf '%s\n' '{"type":"session.error","content":"fail"}'
  exit 0
fi
printf '%s\n' '{"type":"text","part":{"text":"CORRECT ANSWER"}}'
printf '%s\n' '{"type":"step_finish","part":{"reason":"stop","tokens":{}}}'
exit 0
FAKEOF
  chmod +x "$bindir/opencode"
}

# Install a fake opencode: first call → exits non-zero (no JSONL), second call → success.
_fake_opencode_nonzero_fallback() {
  local bindir="$1" counter="$2" success_text="${3:-nonzero fallback success}"
  cat > "$bindir/opencode" <<FAKEOF
#!/usr/bin/env bash
_n=0
[[ -f "$counter" ]] && _n=\$(cat "$counter")
_n=\$(( _n + 1 ))
printf '%d' "\$_n" > "$counter"
if [[ "\$_n" -eq 1 ]]; then
  exit 1
fi
printf '%s\n' '{"type":"text","part":{"text":"$success_text"}}'
printf '%s\n' '{"type":"step_finish","part":{"reason":"stop","tokens":{}}}'
exit 0
FAKEOF
  chmod +x "$bindir/opencode"
}

# Install a fake opencode: first call → exits 0 but emits no step_finish, second call → success.
_fake_opencode_no_terminal() {
  local bindir="$1" counter="$2" success_text="${3:-terminal fallback success}"
  cat > "$bindir/opencode" <<FAKEOF
#!/usr/bin/env bash
_n=0
[[ -f "$counter" ]] && _n=\$(cat "$counter")
_n=\$(( _n + 1 ))
printf '%d' "\$_n" > "$counter"
if [[ "\$_n" -eq 1 ]]; then
  printf '%s\n' '{"type":"text","part":{"text":"no terminal"}}'
  exit 0
fi
printf '%s\n' '{"type":"text","part":{"text":"$success_text"}}'
printf '%s\n' '{"type":"step_finish","part":{"reason":"stop","tokens":{}}}'
exit 0
FAKEOF
  chmod +x "$bindir/opencode"
}

# Install a fake opencode that always exits non-zero (all attempts fail).
_fake_opencode_always_fail() {
  local bindir="$1"
  cat > "$bindir/opencode" <<FAKEOF
#!/usr/bin/env bash
exit 1
FAKEOF
  chmod +x "$bindir/opencode"
}

_mk_brief() {
  local bf; bf="$(mktemp /tmp/brief-oc-test-XXXXXX.md)"
  printf 'Do the task.\n' > "$bf"
  printf '%s\n' "$bf"
}

# ── Test cases ────────────────────────────────────────────────────────────────

# Behavior: --help exits 0 without invoking opencode.
# Steps:
#   1. Run dispatch.sh --help.
#   2. Assert exit code 0.
case_help() {
  local name="arg/--help exits 0"; should_run "$name" || return 0
  if "$DISPATCH" --help >/dev/null 2>&1; then pass "$name"
  else fail "$name" "expected exit 0"; fi
}

# Behavior: Missing --cd causes an immediate exit 2 before any opencode invocation.
# Steps:
#   1. Run dispatch.sh with --brief-file but no --cd.
#   2. Assert non-zero exit.
case_missing_cd() {
  local name="arg/missing --cd exits non-zero"; should_run "$name" || return 0
  local bf; bf="$(_mk_brief)"
  if "$DISPATCH" --brief-file "$bf" >/dev/null 2>&1; then
    fail "$name" "expected non-zero exit without --cd"
  else pass "$name"; fi
  rm -f "$bf"
}

# Behavior: Missing --brief-file causes an immediate exit 2.
# Steps:
#   1. Run dispatch.sh with --cd but no --brief-file.
#   2. Assert non-zero exit.
case_missing_brief_file() {
  local name="arg/missing --brief-file exits non-zero"; should_run "$name" || return 0
  local work; work="$(mktemp -d)"
  if "$DISPATCH" --cd "$work" >/dev/null 2>&1; then
    fail "$name" "expected non-zero exit without --brief-file"
  else pass "$name"; fi
  rm -rf "$work"
}

# Behavior: Successful dispatch writes response text to latest.last.
# Steps:
#   1. Install fake opencode that emits text + step_finish.
#   2. Run dispatch.sh with --model and --brief-file.
#   3. Assert latest.last contains the expected response text.
case_happy_path() {
  local name="dispatch/happy path — latest.last contains response"; should_run "$name" || return 0
  local bindir work bf last
  bindir="$(mktemp -d)"; work="$(mktemp -d)"; bf="$(_mk_brief)"
  _fake_opencode_success "$bindir" "hello from opencode"
  set +e
  PATH="$bindir:$PATH" "$DISPATCH" \
    --cd "$work" --brief-file "$bf" \
    --model opencode/nemotron-3-ultra-free \
    --timeout 120 >/dev/null 2>&1
  set -e
  last="$(cat "$work/.agent-trace/latest.last" 2>/dev/null || true)"
  if [[ "$last" == "hello from opencode" ]]; then pass "$name"
  else fail "$name" "got: $(printf '%s' "$last" | head -c 80)"; fi
  rm -rf "$bindir" "$work"; rm -f "$bf"
}

# Behavior: --print-cmd prints MODELS_TO_TRY and exits 0 without invoking opencode.
# Steps:
#   1. Run dispatch.sh with --print-cmd.
#   2. Assert output contains MODELS_TO_TRY.
#   3. Assert exit 0.
case_print_cmd() {
  local name="arg/--print-cmd prints MODELS_TO_TRY and exits 0"; should_run "$name" || return 0
  local work bf out
  work="$(mktemp -d)"; bf="$(_mk_brief)"
  out="$("$DISPATCH" \
    --cd "$work" --brief-file "$bf" \
    --model opencode/nemotron-3-ultra-free \
    --print-cmd 2>&1 || true)"
  if echo "$out" | grep -q "MODELS_TO_TRY"; then pass "$name"
  else fail "$name" "MODELS_TO_TRY not in output: $(printf '%s' "$out" | head -c 80)"; fi
  rm -rf "$work"; rm -f "$bf"
}

# Behavior: isolation:none maps to --dangerously-skip-permissions native flag.
# Steps:
#   1. Run dispatch.sh with --isolation none and --print-cmd.
#   2. Assert output contains --dangerously-skip-permissions.
case_isolation_none() {
  local name="isolation/none maps to --dangerously-skip-permissions"; should_run "$name" || return 0
  local work bf out
  work="$(mktemp -d)"; bf="$(_mk_brief)"
  out="$("$DISPATCH" \
    --cd "$work" --brief-file "$bf" \
    --model opencode/nemotron-3-ultra-free \
    --isolation none --print-cmd 2>&1 || true)"
  if echo "$out" | grep -q "dangerously-skip-permissions"; then pass "$name"
  else fail "$name" "flag not in NATIVE_FLAGS output: $(printf '%s' "$out" | head -c 80)"; fi
  rm -rf "$work"; rm -f "$bf"
}

# Behavior: isolation:workspace-write is rejected (not enforceable by opencode CLI).
# Steps:
#   1. Run dispatch.sh with --isolation workspace-write.
#   2. Assert non-zero exit (same as other unsupported levels).
case_isolation_workspace_write_rejected() {
  local name="isolation/workspace-write is rejected (not enforceable)"; should_run "$name" || return 0
  local work bf rc
  work="$(mktemp -d)"; bf="$(_mk_brief)"
  rc=0
  "$DISPATCH" \
    --cd "$work" --brief-file "$bf" \
    --model opencode/nemotron-3-ultra-free \
    --isolation workspace-write >/dev/null 2>&1 || rc=$?
  if [[ "$rc" -ne 0 ]]; then pass "$name"
  else fail "$name" "workspace-write should be rejected (unsupported by opencode adapter)"; fi
  rm -rf "$work"; rm -f "$bf"
}

# Behavior: Unknown isolation level causes exit 2 (fail-closed).
# Steps:
#   1. Run dispatch.sh with --isolation not-a-real-level.
#   2. Assert non-zero exit.
case_unknown_isolation() {
  local name="isolation/unknown level exits non-zero (fail-closed)"; should_run "$name" || return 0
  local work bf
  work="$(mktemp -d)"; bf="$(_mk_brief)"
  if "$DISPATCH" \
    --cd "$work" --brief-file "$bf" \
    --model opencode/nemotron-3-ultra-free \
    --isolation not-a-real-level >/dev/null 2>&1; then
    fail "$name" "expected non-zero exit for unknown isolation level"
  else pass "$name"; fi
  rm -rf "$work"; rm -f "$bf"
}

# Behavior: read-only isolation is rejected (not supported — no CLI enforcement).
# Steps:
#   1. Run dispatch.sh with --isolation read-only.
#   2. Assert non-zero exit.
case_isolation_read_only_rejected() {
  local name="isolation/read-only is rejected (unsupported by opencode adapter)"; should_run "$name" || return 0
  local work bf
  work="$(mktemp -d)"; bf="$(_mk_brief)"
  if "$DISPATCH" \
    --cd "$work" --brief-file "$bf" \
    --model opencode/nemotron-3-ultra-free \
    --isolation read-only >/dev/null 2>&1; then
    fail "$name" "expected non-zero exit for read-only isolation"
  else pass "$name"; fi
  rm -rf "$work"; rm -f "$bf"
}

# Behavior: sandboxed isolation is rejected (not supported — no ephemeral sandbox).
# Steps:
#   1. Run dispatch.sh with --isolation sandboxed.
#   2. Assert non-zero exit.
case_isolation_sandboxed_rejected() {
  local name="isolation/sandboxed is rejected (unsupported by opencode adapter)"; should_run "$name" || return 0
  local work bf
  work="$(mktemp -d)"; bf="$(_mk_brief)"
  if "$DISPATCH" \
    --cd "$work" --brief-file "$bf" \
    --model opencode/nemotron-3-ultra-free \
    --isolation sandboxed >/dev/null 2>&1; then
    fail "$name" "expected non-zero exit for sandboxed isolation"
  else pass "$name"; fi
  rm -rf "$work"; rm -f "$bf"
}

# Behavior: --model light resolves to the deepseek flash wire id via alias table.
# Steps:
#   1. Run dispatch.sh with --model light and --print-cmd.
#   2. Assert MODELS_TO_TRY contains a deepseek wire id.
case_alias_light() {
  local name="alias/light resolves to deepseek wire id"; should_run "$name" || return 0
  local work bf out
  work="$(mktemp -d)"; bf="$(_mk_brief)"
  out="$("$DISPATCH" \
    --cd "$work" --brief-file "$bf" \
    --model light --print-cmd 2>&1 || true)"
  if echo "$out" | grep -q "deepseek"; then pass "$name"
  else fail "$name" "light not resolved to deepseek; got: $(printf '%s' "$out" | head -c 80)"; fi
  rm -rf "$work"; rm -f "$bf"
}

# Behavior: --model default resolves to the nemotron wire id via alias table.
# Steps:
#   1. Run dispatch.sh with --model default and --print-cmd.
#   2. Assert MODELS_TO_TRY contains a nemotron wire id.
case_alias_default() {
  local name="alias/default resolves to nemotron wire id"; should_run "$name" || return 0
  local work bf out
  work="$(mktemp -d)"; bf="$(_mk_brief)"
  out="$("$DISPATCH" \
    --cd "$work" --brief-file "$bf" \
    --model default --print-cmd 2>&1 || true)"
  if echo "$out" | grep -q "nemotron"; then pass "$name"
  else fail "$name" "default not resolved to nemotron; got: $(printf '%s' "$out" | head -c 80)"; fi
  rm -rf "$work"; rm -f "$bf"
}

# Behavior: An unknown alias is passed through as-is to the opencode CLI.
# Steps:
#   1. Run dispatch.sh with --model set to a raw wire id not in the alias table.
#   2. Assert MODELS_TO_TRY contains that exact wire id unchanged.
case_alias_unknown_passthrough() {
  local name="alias/unknown alias passed through unchanged"; should_run "$name" || return 0
  local work bf out
  work="$(mktemp -d)"; bf="$(_mk_brief)"
  out="$("$DISPATCH" \
    --cd "$work" --brief-file "$bf" \
    --model openrouter/custom/model \
    --print-cmd 2>&1 || true)"
  if echo "$out" | grep -q "openrouter/custom/model"; then pass "$name"
  else fail "$name" "raw wire id not passed through; got: $(printf '%s' "$out" | head -c 80)"; fi
  rm -rf "$work"; rm -f "$bf"
}

# Behavior: session.error on attempt 1 causes fallback to attempt 2 which succeeds.
# Steps:
#   1. Install fake opencode with counter: attempt 1 → session.error, attempt 2 → success.
#   2. Run dispatch.sh without --model (uses fallback chain from adapter.yaml).
#   3. Assert exit 0 and latest.last contains the attempt 2 response.
case_session_error_fallback() {
  local name="fallback/session.error on attempt 1 → attempt 2 succeeds"; should_run "$name" || return 0
  local bindir work bf counter rc last
  bindir="$(mktemp -d)"; work="$(mktemp -d)"; bf="$(_mk_brief)"
  counter="$(mktemp)"
  _fake_opencode_fallback "$bindir" "$counter" "fallback success"
  rc=0
  PATH="$bindir:$PATH" "$DISPATCH" \
    --cd "$work" --brief-file "$bf" \
    --timeout 120 >/dev/null 2>&1 || rc=$?
  last="$(cat "$work/.agent-trace/latest.last" 2>/dev/null || true)"
  if [[ "$rc" -eq 0 ]] && [[ "$last" == "fallback success" ]]; then pass "$name"
  else fail "$name" "rc=$rc last=$(printf '%s' "$last" | head -c 60)"; fi
  rm -rf "$bindir" "$work"; rm -f "$bf" "$counter"
}

# Behavior: latest.last contains only text from the winning attempt, not from failed attempts.
# Steps:
#   1. Install fake opencode: attempt 1 emits text then session.error, attempt 2 emits different text.
#   2. Run dispatch.sh without --model.
#   3. Assert latest.last equals attempt 2 text and does not contain attempt 1 text.
case_last_scoped_to_winning_attempt() {
  local name="fallback/latest.last contains only winning attempt text"; should_run "$name" || return 0
  local bindir work bf counter last
  bindir="$(mktemp -d)"; work="$(mktemp -d)"; bf="$(_mk_brief)"
  counter="$(mktemp)"
  _fake_opencode_scope_test "$bindir" "$counter"
  PATH="$bindir:$PATH" "$DISPATCH" \
    --cd "$work" --brief-file "$bf" \
    --timeout 120 >/dev/null 2>&1 || true
  last="$(cat "$work/.agent-trace/latest.last" 2>/dev/null || true)"
  if [[ "$last" == "CORRECT ANSWER" ]] && ! echo "$last" | grep -q "SHOULD NOT APPEAR"; then
    pass "$name"
  else fail "$name" "got: $(printf '%s' "$last" | head -c 80)"; fi
  rm -rf "$bindir" "$work"; rm -f "$bf" "$counter"
}

# Behavior: --timeout 0 means no timeout; dispatch completes normally.
# Steps:
#   1. Install fake opencode that succeeds.
#   2. Run dispatch.sh with --timeout 0.
#   3. Assert exit 0 and latest.last contains response.
case_timeout_zero_no_limit() {
  local name="arg/--timeout 0 is unlimited (no floor applied)"; should_run "$name" || return 0
  local bindir work bf last rc
  bindir="$(mktemp -d)"; work="$(mktemp -d)"; bf="$(_mk_brief)"
  _fake_opencode_success "$bindir" "timeout zero ok"
  rc=0
  PATH="$bindir:$PATH" "$DISPATCH" \
    --cd "$work" --brief-file "$bf" \
    --model opencode/nemotron-3-ultra-free \
    --timeout 0 >/dev/null 2>&1 || rc=$?
  last="$(cat "$work/.agent-trace/latest.last" 2>/dev/null || true)"
  if [[ "$rc" -eq 0 ]] && [[ "$last" == "timeout zero ok" ]]; then pass "$name"
  else fail "$name" "rc=$rc last=$(printf '%s' "$last" | head -c 40)"; fi
  rm -rf "$bindir" "$work"; rm -f "$bf"
}

# Behavior: --timeout below 120s (and non-zero) is rejected with exit 2.
# Steps:
#   1. Run dispatch.sh with --model and --timeout 60.
#   2. Assert non-zero exit.
case_timeout_too_low_rejected() {
  local name="arg/--timeout below 120s is rejected"; should_run "$name" || return 0
  local work bf rc
  work="$(mktemp -d)"; bf="$(_mk_brief)"
  rc=0
  "$DISPATCH" \
    --cd "$work" --brief-file "$bf" \
    --model opencode/nemotron-3-ultra-free \
    --timeout 60 >/dev/null 2>&1 || rc=$?
  if [[ "$rc" -ne 0 ]]; then pass "$name"
  else fail "$name" "expected non-zero exit for --timeout 60, got 0"; fi
  rm -rf "$work"; rm -f "$bf"
}

# Behavior: --sandbox and --approval emit a deprecation warning but do not crash.
# Steps:
#   1. Run dispatch.sh with --sandbox and --approval flags plus --print-cmd.
#   2. Assert stderr contains "warning".
#   3. Assert no crash (command exits non-fatal).
case_legacy_flags_warn() {
  local name="compat/--sandbox and --approval warn but don't crash"; should_run "$name" || return 0
  local work bf err
  work="$(mktemp -d)"; bf="$(_mk_brief)"
  err="$("$DISPATCH" \
    --cd "$work" --brief-file "$bf" \
    --model opencode/nemotron-3-ultra-free \
    --sandbox workspace-write --approval never \
    --print-cmd 2>&1 || true)"
  if echo "$err" | grep -qi "warning"; then pass "$name"
  else fail "$name" "no warning emitted for legacy flags"; fi
  rm -rf "$work"; rm -f "$bf"
}

# Behavior: --effort is not supported by the opencode adapter (no native
# equivalent) — accepted as a no-op with a warning, not a hard error.
# Steps:
#   1. Run dispatch.sh with --effort plus --print-cmd.
#   2. Assert stderr contains "warning" and exit is non-fatal.
case_effort_flag_noop_warns() {
  local name="compat/--effort warns but is a no-op, not a crash"; should_run "$name" || return 0
  local work bf err
  work="$(mktemp -d)"; bf="$(_mk_brief)"
  err="$("$DISPATCH" \
    --cd "$work" --brief-file "$bf" \
    --model opencode/nemotron-3-ultra-free \
    --effort low \
    --print-cmd 2>&1 || true)"
  if echo "$err" | grep -qi "warning"; then pass "$name"
  else fail "$name" "no warning emitted for --effort"; fi
  rm -rf "$work"; rm -f "$bf"
}

# Behavior: Non-zero exit on attempt 1 causes fallback to attempt 2 which succeeds.
# Steps:
#   1. Install fake opencode: attempt 1 exits 1 (no JSONL), attempt 2 emits text + step_finish.
#   2. Run dispatch.sh without --model (uses fallback chain).
#   3. Assert exit 0 and latest.last contains the attempt 2 response.
case_nonzero_exit_fallback() {
  local name="fallback/non-zero exit on attempt 1 → attempt 2 succeeds"; should_run "$name" || return 0
  local bindir work bf counter rc last
  bindir="$(mktemp -d)"; work="$(mktemp -d)"; bf="$(_mk_brief)"
  counter="$(mktemp)"
  _fake_opencode_nonzero_fallback "$bindir" "$counter" "nonzero fallback success"
  rc=0
  PATH="$bindir:$PATH" "$DISPATCH" \
    --cd "$work" --brief-file "$bf" \
    --timeout 120 >/dev/null 2>&1 || rc=$?
  last="$(cat "$work/.agent-trace/latest.last" 2>/dev/null || true)"
  if [[ "$rc" -eq 0 ]] && [[ "$last" == "nonzero fallback success" ]]; then pass "$name"
  else fail "$name" "rc=$rc last=$(printf '%s' "$last" | head -c 60)"; fi
  rm -rf "$bindir" "$work"; rm -f "$bf" "$counter"
}

# Behavior: Missing step_finish on attempt 1 causes fallback to attempt 2 which succeeds.
# Steps:
#   1. Install fake opencode: attempt 1 exits 0 but emits no step_finish, attempt 2 succeeds.
#   2. Run dispatch.sh without --model (uses fallback chain).
#   3. Assert exit 0 and latest.last contains the attempt 2 response.
case_missing_terminal_fallback() {
  local name="fallback/missing step_finish on attempt 1 → attempt 2 succeeds"; should_run "$name" || return 0
  local bindir work bf counter rc last
  bindir="$(mktemp -d)"; work="$(mktemp -d)"; bf="$(_mk_brief)"
  counter="$(mktemp)"
  _fake_opencode_no_terminal "$bindir" "$counter" "terminal fallback success"
  rc=0
  PATH="$bindir:$PATH" "$DISPATCH" \
    --cd "$work" --brief-file "$bf" \
    --timeout 120 >/dev/null 2>&1 || rc=$?
  last="$(cat "$work/.agent-trace/latest.last" 2>/dev/null || true)"
  if [[ "$rc" -eq 0 ]] && [[ "$last" == "terminal fallback success" ]]; then pass "$name"
  else fail "$name" "rc=$rc last=$(printf '%s' "$last" | head -c 60)"; fi
  rm -rf "$bindir" "$work"; rm -f "$bf" "$counter"
}

# Behavior: All models fail → dispatch exits non-zero.
# Steps:
#   1. Install fake opencode that always exits 1.
#   2. Run dispatch.sh with a single explicit --model (1-model chain, no fallback).
#   3. Assert non-zero exit.
case_all_attempts_failed() {
  local name="fallback/all attempts fail → dispatch exits non-zero"; should_run "$name" || return 0
  local bindir work bf rc
  bindir="$(mktemp -d)"; work="$(mktemp -d)"; bf="$(_mk_brief)"
  _fake_opencode_always_fail "$bindir"
  rc=0
  PATH="$bindir:$PATH" "$DISPATCH" \
    --cd "$work" --brief-file "$bf" \
    --model opencode/nemotron-3-ultra-free \
    --timeout 120 >/dev/null 2>&1 || rc=$?
  if [[ "$rc" -ne 0 ]]; then pass "$name"
  else fail "$name" "expected non-zero exit when all attempts fail, got 0"; fi
  rm -rf "$bindir" "$work"; rm -f "$bf"
}

# Behavior: pmctl dispatch run --lifecycle foreground --adapter opencode routes through the opencode adapter,
# records executor:"opencode" in the Run state row, and creates latest.last.
# Steps:
#   1. git-init a workdir; install fake opencode that succeeds.
#   2. Run pmctl dispatch run --lifecycle foreground --adapter opencode with a fresh state store.
#   3. Assert runs.jsonl row has executor:"opencode", state:"ok", and latest.last exists.
case_pmctl_route() {
  local name="pmctl-route/pmctl dispatch run --lifecycle foreground --adapter opencode records Run row"; should_run "$name" || return 0
  local store bindir work bf runs_file executor state exit_code
  store="$(mktemp -d)"; bindir="$(mktemp -d)"; work="$(mktemp -d)"
  bf="$(mktemp /tmp/brief-oc-pmctl-XXXXXX.md)"
  git -C "$work" init -q
  printf 'schema_version: 1\nworking_dir: %s\ngoal: pmctl opencode route test\nfiles:\n  - read: %s/README\nacceptance:\n  - dispatch exits 0\n' \
    "$work" "$work" > "$bf"
  _fake_opencode_success "$bindir" "pmctl route ok"
  PM_DISPATCH_STATE_ROOT="$store" PATH="$bindir:$PATH" \
    "$PMCTL" dispatch run --lifecycle foreground --adapter opencode \
    --cd "$work" --brief-file "$bf" >/dev/null 2>&1 || true
  runs_file="$(find "$store" -name "runs.jsonl" -type f 2>/dev/null | head -1 || true)"
  executor="$(jq -r '.executor' "$runs_file" 2>/dev/null | tail -1 || true)"
  state="$(jq -r '.state' "$runs_file" 2>/dev/null | tail -1 || true)"
  exit_code="$(jq -r '.exit_code' "$runs_file" 2>/dev/null | tail -1 || true)"
  # CC-417: latest.last lands in the out-of-repo run dir under the work's project
  # partition, not $work/.agent-trace; the repo stays clean.
  local trace_last="$work/.agent-trace/latest.last"
  if [[ "$(type -t sw_project_run_dir 2>/dev/null)" != function ]]; then
    # shellcheck source=scripts/lib/state-paths.sh
    . "$REPO_ROOT/scripts/lib/state-paths.sh" 2>/dev/null || true
  fi
  if [[ "$(type -t sw_project_run_dir 2>/dev/null)" == function ]]; then
    local _part _rl
    _part="$(cd "$work" && dirname "$(PM_DISPATCH_STATE_ROOT="$store" sw_project_run_dir __probe__)")"
    _rl="$(find "$_part" \( -type f -o -type l \) -name latest.last 2>/dev/null | head -1)"
    [[ -n "$_rl" ]] && trace_last="$_rl"
  fi
  if [[ "$executor" == "opencode" && "$state" == "ok" && "$exit_code" == "0" ]] \
     && [[ -s "$trace_last" ]] \
     && [[ ! -e "$work/.agent-trace" ]]; then
    pass "$name"
  else
    fail "$name" "executor=$executor state=$state exit=$exit_code last=$trace_last present=$([[ -s "$trace_last" ]] && echo yes || echo no) repo_trace=$([[ -e "$work/.agent-trace" ]] && echo present || echo clean)"
  fi
  rm -rf "$store" "$bindir" "$work"; rm -f "$bf"
}

# Behavior: After a successful dispatch, latest.last and latest.jsonl symlinks are created.
# Steps:
#   1. Install fake opencode that succeeds.
#   2. Run dispatch.sh with --model.
#   3. Assert .agent-trace/latest.last and latest.jsonl are symbolic links.
case_latest_symlinks_created() {
  local name="artifact/latest.last and latest.jsonl symlinks created on success"; should_run "$name" || return 0
  local bindir work bf
  bindir="$(mktemp -d)"; work="$(mktemp -d)"; bf="$(_mk_brief)"
  _fake_opencode_success "$bindir" "ok"
  set +e
  PATH="$bindir:$PATH" "$DISPATCH" \
    --cd "$work" --brief-file "$bf" \
    --model opencode/nemotron-3-ultra-free \
    --timeout 120 >/dev/null 2>&1
  set -e
  if [[ -L "$work/.agent-trace/latest.last" ]] && [[ -L "$work/.agent-trace/latest.jsonl" ]]; then
    pass "$name"
  else fail "$name" "symlinks missing in .agent-trace/"; fi
  rm -rf "$bindir" "$work"; rm -f "$bf"
}

# ── Runner ────────────────────────────────────────────────────────────────────
case_help
case_missing_cd
case_missing_brief_file
case_happy_path
case_print_cmd
case_isolation_none
case_isolation_workspace_write_rejected
case_unknown_isolation
case_isolation_read_only_rejected
case_isolation_sandboxed_rejected
case_alias_light
case_alias_default
case_alias_unknown_passthrough
case_session_error_fallback
case_last_scoped_to_winning_attempt
case_nonzero_exit_fallback
case_missing_terminal_fallback
case_all_attempts_failed
case_pmctl_route
case_timeout_zero_no_limit
case_timeout_too_low_rejected
case_legacy_flags_warn
case_effort_flag_noop_warns
case_latest_symlinks_created

# ---- trace-dir/--trace-dir routes trace out of repo ----
case_trace_dir_flag_routes_out_of_repo() {
  # Behavior: --trace-dir <abs> writes trace to that dir and leaves the repo's
  # in-repo .agent-trace untouched (relocation seam, parity with codex/claude).
  local name="trace-dir/--trace-dir routes trace out of repo"; should_run "$name" || return 0
  local bindir work bf tdir
  bindir="$(mktemp -d)"; work="$(mktemp -d)"; bf="$(_mk_brief)"
  tdir="$(mktemp -d)/explicit-trace"
  _fake_opencode_success "$bindir" "hello"
  set +e
  PATH="$bindir:$PATH" "$DISPATCH" --cd "$work" --brief-file "$bf" \
    --model opencode/nemotron-3-ultra-free --timeout 120 --trace-dir "$tdir" >/dev/null 2>&1
  set -e
  if compgen -G "$tdir/opencode-*.jsonl" >/dev/null && [[ ! -d "$work/.agent-trace" ]]; then
    pass "$name"; else fail "$name" "override=$(ls "$tdir" 2>/dev/null) inrepo=$(ls "$work/.agent-trace" 2>/dev/null)"; fi
  rm -rf "$bindir" "$work" "$tdir"; rm -f "$bf"
}

# ---- trace-dir/relative --trace-dir rejected ----
case_trace_dir_relative_rejected() {
  # Behavior: a relative --trace-dir is rejected (exit 2) — parity with codex/claude.
  local name="trace-dir/relative --trace-dir rejected"; should_run "$name" || return 0
  local bindir work bf rc
  bindir="$(mktemp -d)"; work="$(mktemp -d)"; bf="$(_mk_brief)"
  _fake_opencode_success "$bindir" "hello"
  set +e
  PATH="$bindir:$PATH" "$DISPATCH" --cd "$work" --brief-file "$bf" \
    --model opencode/nemotron-3-ultra-free --timeout 120 --trace-dir "rel/trace" >/dev/null 2>&1
  rc=$?
  set -e
  if [[ "$rc" -eq 2 ]]; then pass "$name"; else fail "$name" "rc=$rc"; fi
  rm -rf "$bindir" "$work"; rm -f "$bf"
}

case_trace_dir_flag_routes_out_of_repo
case_trace_dir_relative_rejected

th_summary
