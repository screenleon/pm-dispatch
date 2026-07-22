#!/usr/bin/env bash
# Regression tests for adapters/grok/dispatch.sh — the thin grok executor
# adapter. Uses a FAKE `grok` on PATH so the suite never depends on a real
# grok CLI. Covers: self-snapshot crash-safety, dual isolation mapping
# (sandbox + permission-mode), the output contract (text chunks → latest.last),
# error-event handling, usage logging, and arg validation.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DISPATCH="$REPO_ROOT/adapters/grok/dispatch.sh"
PMCTL="$REPO_ROOT/cli/pmctl"

# shellcheck source=tests/lib/test-harness.sh
. "$SCRIPT_DIR/../lib/test-harness.sh"
# shellcheck source=runtime/lib/handover-validate.sh
. "$REPO_ROOT/runtime/lib/handover-validate.sh"
th_init "$@"

SNAP_RE="exec [^ ]*grok-dispatch\.[A-Za-z0-9]+/grok-dispatch\.sh"

# Fake grok honoring the output contract: emits streaming-json JSONL events
# matching --output-format streaming-json. $1 selects mode: success|error|nonzero.
# $2 overrides exit code for nonzero mode.
_install_fake_grok() {
  local bindir="$1" mode="${2:-success}" code="${3:-0}"
  cat > "$bindir/grok" <<FAKEOF
#!/usr/bin/env bash
# Consume flags silently; optional --prompt-file just needs to exist.
while [[ \$# -gt 0 ]]; do
  case "\$1" in
    --prompt-file|--cwd|--output-format|--sandbox|--permission-mode|--model|--reasoning-effort)
      shift 2 ;;
    *) shift ;;
  esac
done
case "$mode" in
  error)
    printf '%s\n' '{"type":"error","message":"auth failed"}'
    exit 0
    ;;
  nonzero)
    printf '%s\n' '{"type":"text","data":"partial"}'
    exit $code
    ;;
  # Structurally valid stream (text events) but missing the terminal type=end
  # marker — post-verify must fail closed when adapter.yaml declares end.
  no_end)
    printf '%s\n' '{"type":"thought","data":"planning"}'
    printf '%s\n' '{"type":"text","data":"incomplete without end"}'
    exit 0
    ;;
  *)
    printf '%s\n' '{"type":"thought","data":"planning"}'
    printf '%s\n' '{"type":"text","data":"work "}'
    printf '%s\n' '{"type":"text","data":"done\\ntest -f x: pass"}'
    printf '%s\n' '{"type":"end","stopReason":"EndTurn","sessionId":"fake","usage":{"input_tokens":100,"output_tokens":50},"num_turns":1}'
    exit 0
    ;;
esac
FAKEOF
  chmod +x "$bindir/grok"
}

_mk_brief() {
  local work="$1" bf
  bf="$(mktemp --suffix=.md)"
  printf 'schema_version: 1\nworking_dir: %s\ngoal: t\nfiles:\n  - read: x\nacceptance:\n  - y\n' "$work" > "$bf"
  printf '%s\n' "$bf"
}

case_help() {
  local name="snapshot/--help exits 0"; should_run "$name" || return 0
  if "$DISPATCH" --help >/dev/null 2>&1; then pass "$name"; else fail "$name" ""; fi
}

case_reexec() {
  local name="snapshot/fresh invocation re-execs from snapshot copy"; should_run "$name" || return 0
  local trace_out
  trace_out="$(bash -x "$DISPATCH" --help 2>&1 1>/dev/null || true)"
  if grep -E "$SNAP_RE" <<<"$trace_out" >/dev/null; then pass "$name"; else fail "$name" ""; fi
}

case_snapshot_structural() {
  local name="snapshot/structural — constructs present"; should_run "$name" || return 0
  local missing=()
  grep -q 'mktemp -d -t grok-dispatch'               "$DISPATCH" || missing+=("mktemp template")
  grep -q 'cp -- "\${BASH_SOURCE\[0\]}"'              "$DISPATCH" || missing+=("cp from BASH_SOURCE")
  grep -q 'chmod +x'                                   "$DISPATCH" || missing+=("chmod +x")
  grep -qE 'exec "\$__grok_dispatch_snapshot"'        "$DISPATCH" || missing+=("exec snapshot")
  grep -qE "trap.*rm -rf.*__grok_dispatch_snapshot_dir" "$DISPATCH" || missing+=("cleanup trap")
  [[ "${#missing[@]}" -eq 0 ]] && pass "$name" || fail "$name" "${missing[*]}"
}

case_cleanup() {
  local name="snapshot/cleanup — no leak"; should_run "$name" || return 0
  local snapdir before after
  snapdir="$(mktemp -d)"
  before=$(find "$snapdir" -maxdepth 1 -type d -name 'grok-dispatch.*' 2>/dev/null | wc -l)
  TMPDIR="$snapdir" "$DISPATCH" --help >/dev/null 2>&1
  after=$(find "$snapdir" -maxdepth 1 -type d -name 'grok-dispatch.*' 2>/dev/null | wc -l)
  rm -rf "$snapdir"
  [[ "$after" -le "$before" ]] && pass "$name" || fail "$name" ""
}

case_print_cmd_default() {
  local name="print-cmd/default → workspace + acceptEdits + streaming-json"; should_run "$name" || return 0
  local work brief out stderr
  work="$(mktemp -d)"; git init -q "$work"; brief="$(_mk_brief "$work")"
  stderr="$(mktemp)"
  out="$("$DISPATCH" --cd "$work" --brief-file "$brief" --print-cmd 2>"$stderr")"
  if [[ "$out" == *"--permission-mode acceptEdits"* \
     && "$out" == *"--sandbox workspace"* \
     && "$out" == *"--output-format streaming-json"* \
     && "$out" == *"--prompt-file"* \
     && "$out" == *"--model grok-4.5"* \
     && "$(cat "$stderr")" == *"grok sandbox also allows writes under ~/.grok"* ]]; then
    pass "$name"; else fail "$name" "out=$out stderr=$(cat "$stderr")"; fi
  rm -rf "$work"; rm -f "$brief" "$stderr"
}

case_isolation_mapping() {
  local name="print-cmd/isolation → dual sandbox+permission mapping"; should_run "$name" || return 0
  local work brief lvl out sb mode ok=1
  work="$(mktemp -d)"; git init -q "$work"; brief="$(_mk_brief "$work")"
  # level → sandbox:permission
  declare -A expect=(
    [read-only]=read-only:dontAsk
    [workspace-write]=workspace:acceptEdits
    [workspace-network]=workspace:acceptEdits
    [sandboxed]=strict:acceptEdits
  )
  for lvl in "${!expect[@]}"; do
    out="$("$DISPATCH" --cd "$work" --brief-file "$brief" --isolation "$lvl" --print-cmd 2>/dev/null)"
    sb="$(grep -oE -- '--sandbox [^ ]+' <<<"$out" | awk '{print $2}')"
    mode="$(grep -oE -- '--permission-mode [^ ]+' <<<"$out" | awk '{print $2}')"
    [[ "$sb:$mode" == "${expect[$lvl]}" ]] || { ok=0; fail "$name" "$lvl → $sb:$mode (want ${expect[$lvl]})"; break; }
  done
  [[ "$ok" -eq 1 ]] && pass "$name"
  rm -rf "$work"; rm -f "$brief"
}

case_isolation_none_rejected() {
  local name="isolation/none rejected (exit 2)"; should_run "$name" || return 0
  local work brief code
  work="$(mktemp -d)"; git init -q "$work"; brief="$(_mk_brief "$work")"
  set +e; "$DISPATCH" --cd "$work" --brief-file "$brief" --isolation none --print-cmd >/dev/null 2>&1; code=$?; set -e
  [[ "$code" -eq 2 ]] && pass "$name" || fail "$name" "code=$code"
  rm -rf "$work"; rm -f "$brief"
}

case_isolation_unknown() {
  local name="isolation/unknown level exits 2"; should_run "$name" || return 0
  local work brief code
  work="$(mktemp -d)"; git init -q "$work"; brief="$(_mk_brief "$work")"
  set +e; "$DISPATCH" --cd "$work" --brief-file "$brief" --isolation bogus --print-cmd >/dev/null 2>&1; code=$?; set -e
  [[ "$code" -eq 2 ]] && pass "$name" || fail "$name" "code=$code"
  rm -rf "$work"; rm -f "$brief"
}

case_missing_cd() {
  local name="args/missing --cd exits 2"; should_run "$name" || return 0
  local code; set +e; "$DISPATCH" --brief-file /tmp/x.md >/dev/null 2>&1; code=$?; set -e
  [[ "$code" -eq 2 ]] && pass "$name" || fail "$name" "code=$code"
}

case_missing_brief() {
  local name="args/missing brief exits 2"; should_run "$name" || return 0
  local work code; work="$(mktemp -d)"; git init -q "$work"
  set +e; "$DISPATCH" --cd "$work" >/dev/null 2>&1; code=$?; set -e
  [[ "$code" -eq 2 ]] && pass "$name" || fail "$name" "code=$code"
  rm -rf "$work"
}

case_happy_path() {
  local name="dispatch/happy path writes output contract"; should_run "$name" || return 0
  local bin work brief code last
  bin="$(mktemp -d)"; _install_fake_grok "$bin"
  work="$(mktemp -d)"; git init -q "$work"; brief="$(_mk_brief "$work")"
  set +e; PATH="$bin:$PATH" "$DISPATCH" --cd "$work" --brief-file "$brief" >/dev/null 2>&1; code=$?; set -e
  last="$work/.agent-trace/latest.last"
  if [[ "$code" -eq 0 && -s "$last" ]] && grep -q 'test -f x: pass' "$last" \
     && [[ -s "$work/.agent-trace/latest.jsonl" ]]; then
    pass "$name"; else fail "$name" "code=$code last=$(cat "$last" 2>/dev/null | head -c 200)"; fi
  rm -rf "$bin" "$work"; rm -f "$brief"
}

case_error_event() {
  local name="dispatch/type=error downgrades exit 0 to 1"; should_run "$name" || return 0
  local bin work brief code
  bin="$(mktemp -d)"; _install_fake_grok "$bin" "error"
  work="$(mktemp -d)"; git init -q "$work"; brief="$(_mk_brief "$work")"
  set +e; PATH="$bin:$PATH" "$DISPATCH" --cd "$work" --brief-file "$brief" >/dev/null 2>&1; code=$?; set -e
  [[ "$code" -eq 1 ]] && pass "$name" || fail "$name" "expected 1, got $code"
  rm -rf "$bin" "$work"; rm -f "$brief"
}

case_exit_propagated() {
  local name="dispatch/grok failure exit propagated"; should_run "$name" || return 0
  local bin work brief code
  bin="$(mktemp -d)"; _install_fake_grok "$bin" "nonzero" 5
  work="$(mktemp -d)"; git init -q "$work"; brief="$(_mk_brief "$work")"
  set +e; PATH="$bin:$PATH" "$DISPATCH" --cd "$work" --brief-file "$brief" >/dev/null 2>&1; code=$?; set -e
  [[ "$code" -eq 5 ]] && pass "$name" || fail "$name" "expected 5, got $code"
  rm -rf "$bin" "$work"; rm -f "$brief"
}

case_usage_log() {
  local name="auto-log/repo-local default logs grok pool"; should_run "$name" || return 0
  local bin home work brief tracker code
  bin="$(mktemp -d)"; _install_fake_grok "$bin"
  home="$(mktemp -d)"
  work="$(mktemp -d)"; git init -q "$work"; brief="$(_mk_brief "$work")"
  set +e; PATH="$bin:$PATH" HOME="$home" "$DISPATCH" --cd "$work" --brief-file "$brief" >/dev/null 2>&1; code=$?; set -e
  # log-usage.sh defaults under ~/.claude/usage-tracker.jsonl historically;
  # pool field should still be grok.
  tracker="$home/.claude/usage-tracker.jsonl"
  if [[ "$code" -eq 0 && -f "$tracker" ]] && grep -q '"type":"grok_dispatch"' "$tracker" \
     && grep -q '"pool":"grok"' "$tracker" && grep -q '"tokens":150' "$tracker"; then
    pass "$name"; else fail "$name" "code=$code tracker=$(cat "$tracker" 2>/dev/null | head -c 300)"; fi
  rm -rf "$bin" "$home" "$work"; rm -f "$brief"
}

case_codex_flags_noop() {
  local name="args/codex-only flags accepted as no-ops"; should_run "$name" || return 0
  local work brief out code
  work="$(mktemp -d)"; git init -q "$work"; brief="$(_mk_brief "$work")"
  set +e
  out="$("$DISPATCH" --cd "$work" --brief-file "$brief" --sandbox workspace-write --approval never --skip-git-check --print-cmd 2>/dev/null)"; code=$?
  set -e
  # Isolation map still owns native sandbox (workspace), not the codex flag value.
  if [[ "$code" -eq 0 && "$out" == *"grok"* && "$out" == *"--sandbox workspace"* ]]; then
    pass "$name"; else fail "$name" "code=$code out=$out"; fi
  rm -rf "$work"; rm -f "$brief"
}

case_model_alias_light() {
  local name="alias/light resolves with low effort"; should_run "$name" || return 0
  local work brief out
  work="$(mktemp -d)"; git init -q "$work"; brief="$(_mk_brief "$work")"
  out="$("$DISPATCH" --cd "$work" --brief-file "$brief" --model light --print-cmd 2>/dev/null)"
  if [[ "$out" == *"--model grok-4.5"* && "$out" == *"--reasoning-effort low"* ]]; then
    pass "$name"; else fail "$name" "out=$out"; fi
  rm -rf "$work"; rm -f "$brief"
}

case_footer() {
  local name="dispatch/stdout footer contract"; should_run "$name" || return 0
  local bin work brief out
  bin="$(mktemp -d)"; _install_fake_grok "$bin"
  work="$(mktemp -d)"; git init -q "$work"; brief="$(_mk_brief "$work")"
  out="$(PATH="$bin:$PATH" "$DISPATCH" --cd "$work" --brief-file "$brief" 2>/dev/null)"
  if grep -q '^trace:' <<<"$out" && grep -q '^last:' <<<"$out" \
     && grep -q '^stderr:' <<<"$out" && grep -q '^exit:[[:space:]]*0' <<<"$out"; then
    pass "$name"; else fail "$name" "out=$out"; fi
  rm -rf "$bin" "$work"; rm -f "$brief"
}

# Behavior: handover accepts executor:grok + workspace-write, rejects isolation none.
case_handover_executor_grok() {
  local name="handover/executor grok accepted; isolation none rejected"; should_run "$name" || return 0
  local meta ok_rc=0 none_rc=0
  meta=$'handover_version: 4\nexecutor: grok\ndispatch_route: main_thread_bash_background\nworking_dir: /tmp\nbrief_file: /tmp/brief-x.md\ntimeout: 600\nmodel: default\nfallback_allowed: false\nisolation_level: workspace-write\n'
  handover_validate_all_metadata "$meta" || ok_rc=$?
  meta=$'handover_version: 4\nexecutor: grok\ndispatch_route: main_thread_bash_background\nworking_dir: /tmp\nbrief_file: /tmp/brief-x.md\ntimeout: 600\nmodel: default\nfallback_allowed: false\nisolation_level: none\n'
  handover_validate_all_metadata "$meta" 2>/dev/null || none_rc=$?
  if [[ "$ok_rc" -eq 0 && "$none_rc" -ne 0 ]]; then
    pass "$name"
  else
    fail "$name" "ok_rc=$ok_rc none_rc=$none_rc"
  fi
}

# Behavior: pmctl dispatch run --lifecycle foreground --adapter grok routes through
# the grok adapter, records executor:"grok" in the Run state row, and creates latest.last.
# Steps:
#   1. git-init a workdir; install fake grok that succeeds.
#   2. Run pmctl dispatch run --lifecycle foreground --adapter grok with a fresh state store.
#   3. Assert runs.jsonl row has executor:"grok", state:"ok", and latest.last exists.
case_pmctl_route() {
  local name="pmctl-route/pmctl dispatch run --lifecycle foreground --adapter grok records Run row"
  should_run "$name" || return 0
  local store bindir work bf runs_file executor state exit_code
  store="$(mktemp -d)"; bindir="$(mktemp -d)"; work="$(mktemp -d)"
  bf="$(mktemp /tmp/brief-grok-pmctl-XXXXXX.md)"
  git -C "$work" init -q
  printf 'schema_version: 1\nworking_dir: %s\ngoal: pmctl grok route test\nfiles:\n  - read: %s/README\nacceptance:\n  - dispatch exits 0\n' \
    "$work" "$work" > "$bf"
  _install_fake_grok "$bindir"
  PM_DISPATCH_STATE_ROOT="$store" PATH="$bindir:$PATH" \
    PM_DISPATCH_WAIT_POLL_INTERVAL=0.1 \
    "$PMCTL" dispatch run --lifecycle foreground --adapter grok \
    --cd "$work" --brief-file "$bf" >/dev/null 2>&1 || true
  runs_file="$(find "$store" -name "runs.jsonl" -type f 2>/dev/null | head -1 || true)"
  executor="$(jq -r '.executor' "$runs_file" 2>/dev/null | tail -1 || true)"
  state="$(jq -r '.state' "$runs_file" 2>/dev/null | tail -1 || true)"
  exit_code="$(jq -r '.exit_code' "$runs_file" 2>/dev/null | tail -1 || true)"
  local trace_last="$work/.agent-trace/latest.last"
  if [[ "$(type -t sw_project_run_dir 2>/dev/null)" != function ]]; then
    # shellcheck source=runtime/lib/state-paths.sh
    . "$REPO_ROOT/runtime/lib/state-paths.sh" 2>/dev/null || true
  fi
  if [[ "$(type -t sw_project_run_dir 2>/dev/null)" == function ]]; then
    local _part _rl
    _part="$(cd "$work" && dirname "$(PM_DISPATCH_STATE_ROOT="$store" sw_project_run_dir __probe__)")"
    _rl="$(find "$_part" \( -type f -o -type l \) -name latest.last 2>/dev/null | head -1)"
    [[ -n "$_rl" ]] && trace_last="$_rl"
  fi
  if [[ "$executor" == "grok" && "$state" == "ok" && "$exit_code" == "0" ]] \
     && [[ -s "$trace_last" ]] \
     && [[ ! -e "$work/.agent-trace" ]]; then
    pass "$name"
  else
    fail "$name" "executor=$executor state=$state exit=$exit_code last=$trace_last present=$([[ -s "$trace_last" ]] && echo yes || echo no) repo_trace=$([[ -e "$work/.agent-trace" ]] && echo present || echo clean) runs=$(cat "${runs_file:-/dev/null}" 2>/dev/null | head -c 400)"
  fi
  rm -rf "$store" "$bindir" "$work"; rm -f "$bf"
}

# Behavior: a structurally whole streaming-json trace that never emits type=end
# fails closed at post-verify (adapter.yaml terminal_event: end). Adapter exit
# may be 0; pmctl still records a non-ok Run state.
# Steps:
#   1. Fake grok emits text only (no_end mode), exits 0.
#   2. pmctl dispatch run --lifecycle foreground --adapter grok.
#   3. Assert Run state is not ok (failed/partial) and exit_code is non-zero
#      from the post-verify failure path.
case_pmctl_missing_end_fails() {
  local name="pmctl-route/missing type=end fails post-verify (non-ok Run)"
  should_run "$name" || return 0
  local store bindir work bf runs_file executor state exit_code code=0
  store="$(mktemp -d)"; bindir="$(mktemp -d)"; work="$(mktemp -d)"
  bf="$(mktemp /tmp/brief-grok-noend-XXXXXX.md)"
  git -C "$work" init -q
  printf 'schema_version: 1\nworking_dir: %s\ngoal: missing end terminal event\nfiles:\n  - read: %s/README\nacceptance:\n  - should fail verify\n' \
    "$work" "$work" > "$bf"
  _install_fake_grok "$bindir" "no_end"
  set +e
  PM_DISPATCH_STATE_ROOT="$store" PATH="$bindir:$PATH" \
    PM_DISPATCH_WAIT_POLL_INTERVAL=0.1 \
    "$PMCTL" dispatch run --lifecycle foreground --adapter grok \
    --cd "$work" --brief-file "$bf" >/dev/null 2>&1
  code=$?
  set -e
  runs_file="$(find "$store" -name "runs.jsonl" -type f 2>/dev/null | head -1 || true)"
  executor="$(jq -r '.executor' "$runs_file" 2>/dev/null | tail -1 || true)"
  state="$(jq -r '.state' "$runs_file" 2>/dev/null | tail -1 || true)"
  exit_code="$(jq -r '.exit_code' "$runs_file" 2>/dev/null | tail -1 || true)"
  # Adapter may exit 0; post-verify must still terminalize as non-ok.
  if [[ "$executor" == "grok" \
     && "$state" != "ok" && "$state" != "null" && -n "$state" \
     && "$code" -ne 0 ]]; then
    pass "$name"
  else
    fail "$name" "code=$code executor=$executor state=$state exit_code=$exit_code runs=$(head -c 400 "${runs_file:-/dev/null}" 2>/dev/null || true)"
  fi
  rm -rf "$store" "$bindir" "$work"; rm -f "$bf"
}

case_help
case_reexec
case_snapshot_structural
case_cleanup
case_print_cmd_default
case_isolation_mapping
case_isolation_none_rejected
case_isolation_unknown
case_missing_cd
case_missing_brief
case_happy_path
case_error_event
case_exit_propagated
case_usage_log
case_codex_flags_noop
case_model_alias_light
case_footer
case_handover_executor_grok
case_pmctl_route
case_pmctl_missing_end_fails

th_summary
