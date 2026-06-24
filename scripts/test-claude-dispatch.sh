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
# stream-json JSONL events matching --output-format stream-json --verbose.
# $1 overrides is_error, $2 overrides exit code.
_install_fake_claude() {
  local bindir="$1" is_error="${2:-false}" code="${3:-0}"
  cat > "$bindir/claude" <<FAKEOF
#!/usr/bin/env bash
cat >/dev/null   # drain the prompt on stdin
printf '%s\n' '{"type":"system","subtype":"init","session_id":"fake","model":"claude-test"}'
printf '%s\n' '{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"work done"}]},"session_id":"fake"}'
printf '%s\n' '{"type":"result","subtype":"success","result":"work done\ntest -f x: pass","is_error":$is_error,"usage":{"input_tokens":100,"output_tokens":50},"session_id":"fake","num_turns":1}'
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
  if [[ "$out" == *"--permission-mode acceptEdits"* && "$out" == *"--output-format stream-json"* && "$out" == *"--verbose"* ]]; then
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
# ---- 15: CLAUDE_DISPATCH_TIMEOUT env sets adapter timeout (highest priority) ----
# Config loading moved to pmctl layer (CC-293); adapter uses PM_CFG_TIMEOUT
# exported by pmctl, or falls back to 1200. CLAUDE_DISPATCH_TIMEOUT env remains
# adapter-specific and is the highest-priority override for direct invocations.
case_config_timeout_env_overrides() {
  local name="config/CLAUDE_DISPATCH_TIMEOUT env sets adapter timeout"; should_run "$name" || return 0
  local work brief stderr code
  work="$(mktemp -d)"; git init -q "$work"; brief="$(_mk_brief "$work")"
  stderr="$(mktemp)"
  set +e
  CLAUDE_DISPATCH_TIMEOUT=900 \
    "$DISPATCH" --cd "$work" --brief-file "$brief" --print-cmd >/dev/null 2>"$stderr"; code=$?
  set -e
  if [[ "$code" -eq 0 ]] && grep -q 'timeout:.*900s' "$stderr"; then
    pass "$name"
  else
    fail "$name" "code=$code timeout_line=$(grep 'timeout:' "$stderr" || true)"
  fi
  rm -rf "$work"; rm -f "$brief" "$stderr"
}

# ---- 17: direct claude adapter does not write Run rows (pmctl owns state) ----
case_state_store_no_direct_run_row_claude() {
  local name="state-store/claude adapter direct invocation does not write Run row"; should_run "$name" || return 0
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
  if [[ "$code" -eq 0 && -z "$runs_file" ]]; then
    pass "$name"
  else
    fail "$name" "code=$code unexpected runs=${runs_file:-none} content=$(cat "${runs_file:-/dev/null}" 2>/dev/null | head -c 200)"
  fi
  rm -rf "$bin" "$home" "$store" "$work"; rm -f "$brief"
}

# ---- 18: latest.* symlink failure is tolerated (Windows MSYS, CC-308) ----
# On Windows MSYS, `ln -sfn` fails when refreshing the latest.* convenience
# symlinks because the target trace file does not yet exist. The adapter guards
# each `ln` with `2>/dev/null || true`; under `set -e` an unguarded failure would
# abort the whole dispatch before the executor runs. This forces `ln` to fail for
# latest.* and asserts dispatch still completes and writes its output contract.
case_latest_symlink_failure_tolerated() {
  local name="dispatch/latest.* symlink failure does not abort dispatch"; should_run "$name" || return 0
  local bin work brief code last
  bin="$(mktemp -d)"; _install_fake_claude "$bin"
  # Fake ln: fail for latest.* (simulate MSYS), delegate everything else to real ln.
  cat > "$bin/ln" <<'FAKELN'
#!/usr/bin/env bash
for a in "$@"; do
  case "$a" in *latest.*) exit 1 ;; esac
done
for real in /usr/bin/ln /bin/ln; do [[ -x "$real" ]] && exec "$real" "$@"; done
exit 1
FAKELN
  chmod +x "$bin/ln"
  work="$(mktemp -d)"; git init -q "$work"; brief="$(_mk_brief "$work")"
  set +e; PATH="$bin:$PATH" "$DISPATCH" --cd "$work" --brief-file "$brief" >/dev/null 2>&1; code=$?; set -e
  # The load-bearing .last is the real claude-<TS>.last file; latest.last is only
  # a convenience symlink. Dispatch must still succeed and write the real output
  # contract even though the latest.* symlinks could not be created.
  last="$(ls "$work"/.agent-trace/claude-*.last 2>/dev/null | head -1)"
  if [[ "$code" -eq 0 && -n "$last" && -s "$last" ]] \
     && grep -q 'test -f x: pass' "$last" \
     && [[ ! -e "$work/.agent-trace/latest.last" ]]; then
    pass "$name"
  else
    fail "$name" "code=$code real_last=${last:-missing} latest_symlink=$([[ -e "$work/.agent-trace/latest.last" ]] && echo present || echo absent)"
  fi
  rm -rf "$bin" "$work"; rm -f "$brief"
}

# ---- model alias resolution tests ----
case_model_alias_light() {
  local name="dispatch/--model light resolves to claude-haiku wire id"; should_run "$name" || return 0
  local work brief out
  work="$(mktemp -d)"; git init -q "$work"; brief="$(_mk_brief "$work")"
  out="$("$DISPATCH" --cd "$work" --brief-file "$brief" --model light --print-cmd 2>/dev/null)"
  if printf '%s' "$out" | grep -q 'claude-haiku-4-5-20251001'; then
    pass "$name"
  else
    fail "$name" "expected claude-haiku-4-5-20251001 in CMD, got: $(printf '%s' "$out" | tail -1)"
  fi
  rm -rf "$work"; rm -f "$brief"
}

case_model_alias_default() {
  local name="dispatch/--model default resolves to claude-sonnet wire id"; should_run "$name" || return 0
  local work brief out
  work="$(mktemp -d)"; git init -q "$work"; brief="$(_mk_brief "$work")"
  out="$("$DISPATCH" --cd "$work" --brief-file "$brief" --model default --print-cmd 2>/dev/null)"
  if printf '%s' "$out" | grep -q 'claude-sonnet-4-6'; then
    pass "$name"
  else
    fail "$name" "expected claude-sonnet-4-6 in CMD, got: $(printf '%s' "$out" | tail -1)"
  fi
  rm -rf "$work"; rm -f "$brief"
}

case_model_alias_haiku() {
  local name="dispatch/--model haiku resolves to claude-haiku wire id"; should_run "$name" || return 0
  local work brief out
  work="$(mktemp -d)"; git init -q "$work"; brief="$(_mk_brief "$work")"
  out="$("$DISPATCH" --cd "$work" --brief-file "$brief" --model haiku --print-cmd 2>/dev/null)"
  if printf '%s' "$out" | grep -q 'claude-haiku-4-5-20251001'; then
    pass "$name"
  else
    fail "$name" "expected claude-haiku-4-5-20251001 in CMD, got: $(printf '%s' "$out" | tail -1)"
  fi
  rm -rf "$work"; rm -f "$brief"
}

case_model_alias_sonnet() {
  local name="dispatch/--model sonnet resolves to claude-sonnet wire id"; should_run "$name" || return 0
  local work brief out
  work="$(mktemp -d)"; git init -q "$work"; brief="$(_mk_brief "$work")"
  out="$("$DISPATCH" --cd "$work" --brief-file "$brief" --model sonnet --print-cmd 2>/dev/null)"
  if printf '%s' "$out" | grep -q 'claude-sonnet-4-6'; then
    pass "$name"
  else
    fail "$name" "expected claude-sonnet-4-6 in CMD, got: $(printf '%s' "$out" | tail -1)"
  fi
  rm -rf "$work"; rm -f "$brief"
}

case_model_alias_opus() {
  local name="dispatch/--model opus resolves to claude-opus wire id"; should_run "$name" || return 0
  local work brief out
  work="$(mktemp -d)"; git init -q "$work"; brief="$(_mk_brief "$work")"
  out="$("$DISPATCH" --cd "$work" --brief-file "$brief" --model opus --print-cmd 2>/dev/null)"
  if printf '%s' "$out" | grep -q 'claude-opus-4-8'; then
    pass "$name"
  else
    fail "$name" "expected claude-opus-4-8 in CMD, got: $(printf '%s' "$out" | tail -1)"
  fi
  rm -rf "$work"; rm -f "$brief"
}

case_model_alias_unknown_passthrough() {
  local name="dispatch/--model unknown-alias passes through unchanged"; should_run "$name" || return 0
  local work brief out
  work="$(mktemp -d)"; git init -q "$work"; brief="$(_mk_brief "$work")"
  out="$("$DISPATCH" --cd "$work" --brief-file "$brief" --model gpt-99-unknown --print-cmd 2>/dev/null)"
  if printf '%s' "$out" | grep -q 'gpt-99-unknown'; then
    pass "$name"
  else
    fail "$name" "expected gpt-99-unknown passed through, got: $(printf '%s' "$out" | tail -1)"
  fi
  rm -rf "$work"; rm -f "$brief"
}

case_model_no_flag_resolves_default() {
  local name="dispatch/omit --model resolves to claude-sonnet-4-6 via alias table (not CLI built-in)"; should_run "$name" || return 0
  local work brief out
  work="$(mktemp -d)"; git init -q "$work"; brief="$(_mk_brief "$work")"
  out="$(unset PM_CFG_DEFAULT_MODEL; "$DISPATCH" --cd "$work" --brief-file "$brief" --print-cmd 2>/dev/null)"
  if printf '%s' "$out" | grep -q -- '--model claude-sonnet-4-6'; then
    pass "$name"
  else
    fail "$name" "expected --model claude-sonnet-4-6 in CMD (default alias resolved), got: $(printf '%s' "$out" | tail -1)"
  fi
  rm -rf "$work"; rm -f "$brief"
}

case_model_pm_cfg_default_model() {
  local name="dispatch/PM_CFG_DEFAULT_MODEL applied when --model omitted"; should_run "$name" || return 0
  local work brief out
  work="$(mktemp -d)"; git init -q "$work"; brief="$(_mk_brief "$work")"
  out="$(PM_CFG_DEFAULT_MODEL=sonnet "$DISPATCH" --cd "$work" --brief-file "$brief" --print-cmd 2>/dev/null)"
  if printf '%s' "$out" | grep -q 'claude-sonnet-4-6'; then
    pass "$name"
  else
    fail "$name" "expected claude-sonnet-4-6 from PM_CFG_DEFAULT_MODEL=sonnet, got: $(printf '%s' "$out" | tail -1)"
  fi
  rm -rf "$work"; rm -f "$brief"
}

case_model_alias_malformed_tsv_warns() {
  local name="dispatch/malformed alias TSV entry emits warning and passes model through"; should_run "$name" || return 0
  local bad_tsv out
  bad_tsv="$(mktemp --suffix=.tsv)"
  printf 'bad\tonly-two-columns\n' > "$bad_tsv"
  # Test _resolve_claude_model_alias in isolation: extract the function from the
  # adapter via awk and run it in a subshell with PM_CLAUDE_ALIAS_FILE set to the
  # malformed TSV. Verifies the malformed-entry warning branch in dispatch.sh.
  set +e
  out="$(bash -s -- "$bad_tsv" "$DISPATCH" 2>&1 <<'RESOLVER_TEST'
set -euo pipefail
bad_tsv="$1"; dispatch_sh="$2"
PM_CLAUDE_ALIAS_FILE="$bad_tsv"
MODEL="light"
eval "$(awk '/^_resolve_claude_model_alias\(\)/,/^}$/' "$dispatch_sh")"
_resolve_claude_model_alias "light" 2>&1
printf 'MODEL_AFTER=%s\n' "$MODEL"
RESOLVER_TEST
  )"
  set -e
  rm -f "$bad_tsv"
  if printf '%s' "$out" | grep -q 'malformed entry'; then
    pass "$name"
  else
    fail "$name" "expected malformed entry warning, got: $out"
  fi
}

# ---- 19: no result event in JSONL → fallback to raw trace copy ----
# stream-json output with no type==result event (e.g. truncated run or non-standard
# executor output) must fall back to copying the raw TRACE to .last so post-verify
# has some input rather than an empty file. Verifies the jq -re fallback path.
case_no_result_event_fallback() {
  local name="dispatch/no result event in JSONL falls back to raw trace"; should_run "$name" || return 0
  local bin work brief code last
  bin="$(mktemp -d)"
  cat > "$bin/claude" <<'FAKEOF'
#!/usr/bin/env bash
cat >/dev/null
printf '%s\n' '{"type":"system","subtype":"init","session_id":"fake"}'
printf '%s\n' '{"type":"assistant","message":{"role":"assistant"},"session_id":"fake"}'
exit 0
FAKEOF
  chmod +x "$bin/claude"
  work="$(mktemp -d)"; git init -q "$work"; brief="$(_mk_brief "$work")"
  set +e; PATH="$bin:$PATH" "$DISPATCH" --cd "$work" --brief-file "$brief" >/dev/null 2>&1; code=$?; set -e
  last="$work/.agent-trace/latest.last"
  # Fallback: .last should contain the raw trace (JSONL lines), not be empty.
  if [[ "$code" -eq 0 && -s "$last" ]] && grep -q '"type":"system"' "$last"; then
    pass "$name"
  else
    fail "$name" "code=$code last_size=$(wc -c < "$last" 2>/dev/null || echo missing)"
  fi
  rm -rf "$bin" "$work"; rm -f "$brief"
}

case_codex_flags_noop
case_config_timeout_env_overrides
case_state_store_no_direct_run_row_claude
case_latest_symlink_failure_tolerated
case_model_alias_light
case_model_alias_default
case_model_alias_haiku
case_model_alias_sonnet
case_model_alias_opus
case_model_alias_unknown_passthrough
case_model_no_flag_resolves_default
case_model_pm_cfg_default_model
case_model_alias_malformed_tsv_warns
case_no_result_event_fallback

# ---- trace-dir/--trace-dir routes trace out of repo ----
case_trace_dir_flag_routes_out_of_repo() {
  # Behavior: --trace-dir <abs> writes trace to that dir and leaves the repo's
  # in-repo .agent-trace untouched (relocation seam, parity with codex adapter).
  local name="trace-dir/--trace-dir routes trace out of repo"; should_run "$name" || return 0
  local bin work brief tdir
  bin="$(mktemp -d)"; _install_fake_claude "$bin"
  work="$(mktemp -d)"; git init -q "$work"; brief="$(_mk_brief "$work")"
  tdir="$(mktemp -d)/explicit-trace"
  set +e; PATH="$bin:$PATH" "$DISPATCH" --cd "$work" --brief-file "$brief" --trace-dir "$tdir" >/dev/null 2>&1; set -e
  if compgen -G "$tdir/claude-*.jsonl" >/dev/null && [[ ! -d "$work/.agent-trace" ]]; then
    pass "$name"; else fail "$name" "override=$(ls "$tdir" 2>/dev/null) inrepo=$(ls "$work/.agent-trace" 2>/dev/null)"; fi
  rm -rf "$bin" "$work" "$tdir"; rm -f "$brief"
}

# ---- trace-dir/relative --trace-dir rejected ----
case_trace_dir_relative_rejected() {
  # Behavior: a relative --trace-dir is rejected (exit 2) — parity with codex adapter.
  local name="trace-dir/relative --trace-dir rejected"; should_run "$name" || return 0
  local bin work brief rc
  bin="$(mktemp -d)"; _install_fake_claude "$bin"
  work="$(mktemp -d)"; git init -q "$work"; brief="$(_mk_brief "$work")"
  set +e; PATH="$bin:$PATH" "$DISPATCH" --cd "$work" --brief-file "$brief" --trace-dir "rel/trace" >/dev/null 2>&1; rc=$?; set -e
  if [[ "$rc" -eq 2 ]]; then pass "$name"; else fail "$name" "rc=$rc"; fi
  rm -rf "$bin" "$work"; rm -f "$brief"
}

case_trace_dir_flag_routes_out_of_repo
case_trace_dir_relative_rejected

th_summary
