#!/usr/bin/env bash
# Regression tests for adapters/opencode/dispatch.sh
# Uses a FAKE `opencode` binary so the suite never depends on a real opencode CLI.
# Covers: arg validation, alias resolution, isolation mapping, fallback chain,
# session.error detection, per-attempt .last scoping, and legacy flag warnings.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DISPATCH="$REPO_ROOT/adapters/opencode/dispatch.sh"

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

# Install a fake opencode that emits session.error and exits 0 (opencode bug pattern).
_fake_opencode_session_error() {
  local bindir="$1"
  cat > "$bindir/opencode" <<'FAKEOF'
#!/usr/bin/env bash
printf '%s\n' '{"type":"session.error","content":"API quota exceeded"}'
exit 0
FAKEOF
  chmod +x "$bindir/opencode"
}

# Install a fake opencode that uses a counter file: first call → session.error,
# subsequent calls → success. Counter file path is embedded at install time.
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

# Install a fake opencode: first call emits text THEN session.error (tests scoping),
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

_mk_brief() {
  local bf; bf="$(mktemp /tmp/brief-oc-test-XXXXXX.md)"
  printf 'Do the task.\n' > "$bf"
  printf '%s\n' "$bf"
}

# ── Test cases ────────────────────────────────────────────────────────────────

case_help() {
  local name="arg/--help exits 0"; should_run "$name" || return 0
  if "$DISPATCH" --help >/dev/null 2>&1; then pass "$name"
  else fail "$name" "expected exit 0"; fi
}

case_missing_cd() {
  local name="arg/missing --cd exits non-zero"; should_run "$name" || return 0
  local bf; bf="$(_mk_brief)"
  if "$DISPATCH" --brief-file "$bf" >/dev/null 2>&1; then
    fail "$name" "expected non-zero exit without --cd"
  else pass "$name"; fi
  rm -f "$bf"
}

case_missing_brief_file() {
  local name="arg/missing --brief-file exits non-zero"; should_run "$name" || return 0
  local work; work="$(mktemp -d)"
  if "$DISPATCH" --cd "$work" >/dev/null 2>&1; then
    fail "$name" "expected non-zero exit without --brief-file"
  else pass "$name"; fi
  rm -rf "$work"
}

case_happy_path() {
  local name="dispatch/happy path — latest.last contains response"; should_run "$name" || return 0
  local bindir work bf last
  bindir="$(mktemp -d)"; work="$(mktemp -d)"; bf="$(_mk_brief)"
  _fake_opencode_success "$bindir" "hello from opencode"
  set +e
  PATH="$bindir:$PATH" "$DISPATCH" \
    --cd "$work" --brief-file "$bf" \
    --model opencode/nemotron-3-ultra-free \
    --timeout 60 >/dev/null 2>&1
  set -e
  last="$(cat "$work/.agent-trace/latest.last" 2>/dev/null || true)"
  if [[ "$last" == "hello from opencode" ]]; then pass "$name"
  else fail "$name" "got: $(printf '%s' "$last" | head -c 80)"; fi
  rm -rf "$bindir" "$work"; rm -f "$bf"
}

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

case_isolation_workspace_write_no_flags() {
  local name="isolation/workspace-write maps to empty native flags"; should_run "$name" || return 0
  local work bf out
  work="$(mktemp -d)"; bf="$(_mk_brief)"
  out="$("$DISPATCH" \
    --cd "$work" --brief-file "$bf" \
    --model opencode/nemotron-3-ultra-free \
    --isolation workspace-write --print-cmd 2>&1 || true)"
  # NATIVE_FLAGS should be empty (no --dangerously-skip-permissions)
  if echo "$out" | grep -q "dangerously-skip-permissions"; then
    fail "$name" "workspace-write should not add --dangerously-skip-permissions"
  else pass "$name"; fi
  rm -rf "$work"; rm -f "$bf"
}

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

case_latest_symlinks_created() {
  local name="artifact/latest.last and latest.jsonl symlinks created on success"; should_run "$name" || return 0
  local bindir work bf
  bindir="$(mktemp -d)"; work="$(mktemp -d)"; bf="$(_mk_brief)"
  _fake_opencode_success "$bindir" "ok"
  set +e
  PATH="$bindir:$PATH" "$DISPATCH" \
    --cd "$work" --brief-file "$bf" \
    --model opencode/nemotron-3-ultra-free \
    --timeout 60 >/dev/null 2>&1
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
case_isolation_workspace_write_no_flags
case_unknown_isolation
case_alias_light
case_alias_default
case_alias_unknown_passthrough
case_session_error_fallback
case_last_scoped_to_winning_attempt
case_legacy_flags_warn
case_latest_symlinks_created

th_summary
