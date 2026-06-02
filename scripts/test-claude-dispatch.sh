#!/usr/bin/env bash
# Regression tests for adapters/claude/dispatch.sh — the thin claude executor
# adapter (CC-266). Uses a FAKE `claude` on PATH so the suite never depends on a
# real claude CLI. Covers: self-snapshot crash-safety, isolation→permission-mode
# mapping, the output contract (.result → latest.last), is_error handling,
# usage logging, and arg validation.
set -euo pipefail

# Legacy env from earlier designs must not influence tests.
unset CLAUDE_DISPATCH_SNAPSHOT_ACTIVE CLAUDE_DISPATCH_SNAPSHOT_PATH

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DISPATCH="$REPO_ROOT/adapters/claude/dispatch.sh"

# shellcheck source=scripts/lib/test-harness.sh
. "$SCRIPT_DIR/lib/test-harness.sh"
th_init "$@"

SNAP_DIR="$(dirname "$(mktemp -u -t claude-dispatch.XXXXXX)")"
SNAP_RE="exec [^ ]*claude-dispatch\.[A-Za-z0-9]+/claude-dispatch\.sh"

# Fake claude honoring the output contract: drains the prompt on stdin and emits
# one --output-format json object. $1 overrides is_error, $2 overrides exit code.
_install_fake_claude() {
  local bindir="$1" is_error="${2:-false}" code="${3:-0}"
  cat > "$bindir/claude" <<FAKEOF
#!/usr/bin/env bash
cat >/dev/null   # drain the prompt on stdin
printf '%s\n' '{"result":"work done\ntest -f x: pass","is_error":$is_error,"usage":{"input_tokens":100,"output_tokens":50},"session_id":"fake","num_turns":1}'
exit $code
FAKEOF
  chmod +x "$bindir/claude"
}

_mk_brief() {
  local work="$1" bf
  bf="$(mktemp --suffix=.md)"
  printf 'schema_version: 1\nworking_dir: %s\ngoal: t\nfiles:\n  - read: x\nacceptance:\n  - y\n' "$work" > "$bf"
  printf '%s\n' "$bf"
}

# ---- 1: --help exits 0 ----
case_help() {
  local name="snapshot/--help exits 0"; should_run "$name" || return 0
  if "$DISPATCH" --help >/dev/null 2>&1; then pass "$name"; else fail "$name" ""; fi
}

# ---- 2: fresh invocation re-execs from a snapshot copy ----
case_reexec() {
  local name="snapshot/fresh invocation re-execs from snapshot copy"; should_run "$name" || return 0
  local trace_out
  trace_out="$(bash -x "$DISPATCH" --help 2>&1 1>/dev/null || true)"
  if grep -E "$SNAP_RE" <<<"$trace_out" >/dev/null; then pass "$name"; else fail "$name" ""; fi
}

# ---- 3: snapshot block structural constructs present ----
case_snapshot_structural() {
  local name="snapshot/structural — constructs present"; should_run "$name" || return 0
  local missing=()
  grep -q 'mktemp -d -t claude-dispatch'          "$DISPATCH" || missing+=("mktemp template")
  grep -q 'cp -- "\${BASH_SOURCE\[0\]}"'          "$DISPATCH" || missing+=("cp from BASH_SOURCE")
  grep -q 'chmod +x'                               "$DISPATCH" || missing+=("chmod +x")
  grep -qE 'exec "\$__claude_dispatch_snapshot"'  "$DISPATCH" || missing+=("exec snapshot")
  grep -qE "trap.*rm -rf.*__claude_dispatch_snapshot_dir" "$DISPATCH" || missing+=("cleanup trap")
  [[ "${#missing[@]}" -eq 0 ]] && pass "$name" || fail "$name" "${missing[*]}"
}

# ---- 4: cleanup leaves no snapshot dir behind ----
case_cleanup() {
  local name="snapshot/cleanup — no leak"; should_run "$name" || return 0
  local before after
  before=$(find "$SNAP_DIR" -maxdepth 1 -type d -name 'claude-dispatch.*' 2>/dev/null | wc -l)
  "$DISPATCH" --help >/dev/null 2>&1
  after=$(find "$SNAP_DIR" -maxdepth 1 -type d -name 'claude-dispatch.*' 2>/dev/null | wc -l)
  [[ "$after" -le "$before" ]] && pass "$name" || fail "$name" ""
}

# ---- 5: --print-cmd default → acceptEdits, no trace files ----
case_print_cmd_default() {
  local name="print-cmd/default → acceptEdits"; should_run "$name" || return 0
  local work brief out
  work="$(mktemp -d)"; git init -q "$work"; brief="$(_mk_brief "$work")"
  out="$("$DISPATCH" --cd "$work" --brief-file "$brief" --print-cmd 2>/dev/null)"
  if [[ "$out" == *"--permission-mode acceptEdits"* && "$out" == *"--output-format json"* ]]; then
    pass "$name"; else fail "$name" "out=$out"; fi
  rm -rf "$work"; rm -f "$brief"
}

# ---- 6: each isolation level maps to the documented permission-mode ----
case_isolation_mapping() {
  local name="print-cmd/isolation → permission-mode mapping"; should_run "$name" || return 0
  local work brief lvl out mode ok=1
  work="$(mktemp -d)"; git init -q "$work"; brief="$(_mk_brief "$work")"
  declare -A expect=([none]=bypassPermissions [read-only]=default [workspace-write]=acceptEdits [workspace-network]=acceptEdits [sandboxed]=acceptEdits)
  for lvl in "${!expect[@]}"; do
    out="$("$DISPATCH" --cd "$work" --brief-file "$brief" --isolation "$lvl" --print-cmd 2>/dev/null)"
    mode="$(grep -o 'permission-mode [a-zA-Z]*' <<<"$out" | awk '{print $2}')"
    [[ "$mode" == "${expect[$lvl]}" ]] || { ok=0; fail "$name" "$lvl → $mode (want ${expect[$lvl]})"; break; }
  done
  [[ "$ok" -eq 1 ]] && pass "$name"
  rm -rf "$work"; rm -f "$brief"
}

# ---- 7: unknown isolation level → exit 2 ----
case_isolation_unknown() {
  local name="isolation/unknown level exits 2"; should_run "$name" || return 0
  local work brief code
  work="$(mktemp -d)"; git init -q "$work"; brief="$(_mk_brief "$work")"
  set +e; "$DISPATCH" --cd "$work" --brief-file "$brief" --isolation bogus --print-cmd >/dev/null 2>&1; code=$?; set -e
  [[ "$code" -eq 2 ]] && pass "$name" || fail "$name" "code=$code"
  rm -rf "$work"; rm -f "$brief"
}

# ---- 8: missing --cd → exit 2 ----
case_missing_cd() {
  local name="args/missing --cd exits 2"; should_run "$name" || return 0
  local code; set +e; "$DISPATCH" --brief-file /tmp/x.md >/dev/null 2>&1; code=$?; set -e
  [[ "$code" -eq 2 ]] && pass "$name" || fail "$name" "code=$code"
}

# ---- 9: missing brief (non-print) → exit 2 ----
case_missing_brief() {
  local name="args/missing brief exits 2"; should_run "$name" || return 0
  local work code; work="$(mktemp -d)"; git init -q "$work"
  set +e; "$DISPATCH" --cd "$work" >/dev/null 2>&1; code=$?; set -e
  [[ "$code" -eq 2 ]] && pass "$name" || fail "$name" "code=$code"
  rm -rf "$work"
}

# ---- 10: happy path — .result extracted to latest.last, trace written, exit 0 ----
case_happy_path() {
  local name="dispatch/happy path writes output contract"; should_run "$name" || return 0
  local bin work brief code last
  bin="$(mktemp -d)"; _install_fake_claude "$bin"
  work="$(mktemp -d)"; git init -q "$work"; brief="$(_mk_brief "$work")"
  set +e; PATH="$bin:$PATH" "$DISPATCH" --cd "$work" --brief-file "$brief" >/dev/null 2>&1; code=$?; set -e
  last="$work/.agent-trace/latest.last"
  if [[ "$code" -eq 0 && -s "$last" ]] && grep -q 'test -f x: pass' "$last" \
     && [[ -s "$work/.agent-trace/latest.jsonl" ]]; then
    pass "$name"; else fail "$name" "code=$code"; fi
  rm -rf "$bin" "$work"; rm -f "$brief"
}

# ---- 11: is_error:true downgrades a 0 exit to failure (1) ----
case_is_error() {
  local name="dispatch/is_error:true downgrades exit to 1"; should_run "$name" || return 0
  local bin work brief code
  bin="$(mktemp -d)"; _install_fake_claude "$bin" "true" 0
  work="$(mktemp -d)"; git init -q "$work"; brief="$(_mk_brief "$work")"
  set +e; PATH="$bin:$PATH" "$DISPATCH" --cd "$work" --brief-file "$brief" >/dev/null 2>&1; code=$?; set -e
  [[ "$code" -eq 1 ]] && pass "$name" || fail "$name" "expected 1, got $code"
  rm -rf "$bin" "$work"; rm -f "$brief"
}

# ---- 12: claude non-zero exit propagated ----
case_exit_propagated() {
  local name="dispatch/claude failure exit propagated"; should_run "$name" || return 0
  local bin work brief code
  bin="$(mktemp -d)"; _install_fake_claude "$bin" "false" 5
  work="$(mktemp -d)"; git init -q "$work"; brief="$(_mk_brief "$work")"
  set +e; PATH="$bin:$PATH" "$DISPATCH" --cd "$work" --brief-file "$brief" >/dev/null 2>&1; code=$?; set -e
  [[ "$code" -eq 5 ]] && pass "$name" || fail "$name" "expected 5, got $code"
  rm -rf "$bin" "$work"; rm -f "$brief"
}

# ---- 13: successful dispatch logs claude-pool token usage ----
case_usage_log() {
  local name="auto-log/successful dispatch logs claude pool"; should_run "$name" || return 0
  local bin home work brief tracker code
  bin="$(mktemp -d)"; _install_fake_claude "$bin"
  home="$(mktemp -d)"; mkdir -p "$home/.claude/scripts"
  ln -s "$REPO_ROOT/scripts/log-usage.sh" "$home/.claude/scripts/log-usage.sh"
  work="$(mktemp -d)"; git init -q "$work"; brief="$(_mk_brief "$work")"
  set +e; PATH="$bin:$PATH" HOME="$home" "$DISPATCH" --cd "$work" --brief-file "$brief" >/dev/null 2>&1; code=$?; set -e
  tracker="$home/.claude/usage-tracker.jsonl"
  if [[ "$code" -eq 0 && -f "$tracker" ]] && grep -q '"type":"claude_dispatch"' "$tracker" \
     && grep -q '"pool":"claude"' "$tracker" && grep -q '"tokens":150' "$tracker"; then
    pass "$name"; else fail "$name" "code=$code"; fi
  rm -rf "$bin" "$home" "$work"; rm -f "$brief"
}

# ---- 14: codex-only flags accepted as no-ops ----
case_codex_flags_noop() {
  local name="args/codex-only flags accepted as no-ops"; should_run "$name" || return 0
  local work brief out code
  work="$(mktemp -d)"; git init -q "$work"; brief="$(_mk_brief "$work")"
  set +e
  out="$("$DISPATCH" --cd "$work" --brief-file "$brief" --sandbox workspace-write --approval never --skip-git-check --print-cmd 2>/dev/null)"; code=$?
  set -e
  if [[ "$code" -eq 0 && "$out" == *"claude -p"* ]]; then pass "$name"; else fail "$name" "code=$code"; fi
  rm -rf "$work"; rm -f "$brief"
}

case_help
case_reexec
case_snapshot_structural
case_cleanup
case_print_cmd_default
case_isolation_mapping
case_isolation_unknown
case_missing_cd
case_missing_brief
case_happy_path
case_is_error
case_exit_propagated
case_usage_log
# ---- 15: dispatch.default_timeout from config file sets initial timeout ----
# Verifies that the shared config loader (pmctl-config.sh) correctly supplies
# dispatch.default_timeout to the claude adapter, comparable to the codex suite.
case_config_timeout_precedence() {
  local name="config/dispatch.default_timeout from config sets claude timeout"; should_run "$name" || return 0
  local home work brief stderr code
  home="$(mktemp -d)"; mkdir -p "$home/.pm-dispatch"
  printf 'dispatch.default_timeout = 600\n' > "$home/.pm-dispatch/config"
  work="$(mktemp -d)"; git init -q "$work"; brief="$(_mk_brief "$work")"
  stderr="$(mktemp)"
  set +e
  HOME="$home" "$DISPATCH" --cd "$work" --brief-file "$brief" --print-cmd >/dev/null 2>"$stderr"; code=$?
  set -e
  if [[ "$code" -eq 0 ]] && grep -q 'timeout:.*600s' "$stderr"; then
    pass "$name"
  else
    fail "$name" "code=$code timeout_line=$(grep 'timeout:' "$stderr" || true)"
  fi
  rm -rf "$home" "$work"; rm -f "$brief" "$stderr"
}

# ---- 16: CLAUDE_DISPATCH_TIMEOUT env beats config dispatch.default_timeout ----
case_config_timeout_env_overrides() {
  local name="config/CLAUDE_DISPATCH_TIMEOUT env overrides config timeout"; should_run "$name" || return 0
  local home work brief stderr code
  home="$(mktemp -d)"; mkdir -p "$home/.pm-dispatch"
  printf 'dispatch.default_timeout = 600\n' > "$home/.pm-dispatch/config"
  work="$(mktemp -d)"; git init -q "$work"; brief="$(_mk_brief "$work")"
  stderr="$(mktemp)"
  set +e
  HOME="$home" CLAUDE_DISPATCH_TIMEOUT=900 \
    "$DISPATCH" --cd "$work" --brief-file "$brief" --print-cmd >/dev/null 2>"$stderr"; code=$?
  set -e
  if [[ "$code" -eq 0 ]] && grep -q 'timeout:.*900s' "$stderr"; then
    pass "$name"
  else
    fail "$name" "code=$code timeout_line=$(grep 'timeout:' "$stderr" || true)"
  fi
  rm -rf "$home" "$work"; rm -f "$brief" "$stderr"
}

# ---- 17: successful claude dispatch writes executor=claude run row ----
# Verifies that the shared sw_append_dispatch_run helper records a run row with
# executor:"claude" and the correct task_id for the claude adapter path.
case_state_store_run_row_claude() {
  local name="state-store/claude dispatch writes executor=claude run row"; should_run "$name" || return 0
  local bin home work brief store runs_file code
  bin="$(mktemp -d)"; _install_fake_claude "$bin"
  home="$(mktemp -d)"; mkdir -p "$home/.claude/scripts"
  ln -s "$REPO_ROOT/scripts/log-usage.sh" "$home/.claude/scripts/log-usage.sh"
  store="$(mktemp -d)"
  work="$(mktemp -d)"; git init -q "$work"
  brief="$(mktemp --suffix=.md)"
  printf 'task_id: CC-305\ngoal: state store claude row test\n' > "$brief"
  set +e
  PATH="$bin:$PATH" HOME="$home" PM_DISPATCH_STATE_ROOT="$store" \
    "$DISPATCH" --cd "$work" --brief-file "$brief" >/dev/null 2>&1; code=$?
  set -e
  runs_file="$(find "$store" -name "runs.jsonl" -type f 2>/dev/null | head -1 || true)"
  if [[ -n "$runs_file" && -s "$runs_file" ]] \
     && jq -e 'select(.executor=="claude")' "$runs_file" >/dev/null 2>&1 \
     && jq -e 'select(.task_id=="CC-305")' "$runs_file" >/dev/null 2>&1; then
    pass "$name"
  else
    fail "$name" "code=$code runs=${runs_file:-none} content=$(cat "${runs_file:-/dev/null}" 2>/dev/null | head -c 200)"
  fi
  rm -rf "$bin" "$home" "$store" "$work"; rm -f "$brief"
}

case_codex_flags_noop
case_config_timeout_precedence
case_config_timeout_env_overrides
case_state_store_run_row_claude

th_summary
