#!/usr/bin/env bash
# Regression tests for durable dispatch result records.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PMCTL="$REPO_ROOT/cli/pmctl"

# shellcheck source=scripts/lib/test-harness.sh
. "$SCRIPT_DIR/lib/test-harness.sh"
# shellcheck source=scripts/lib/executor-router.sh
. "$SCRIPT_DIR/lib/executor-router.sh"
# shellcheck source=scripts/lib/pmctl-guard.sh
. "$SCRIPT_DIR/lib/pmctl-guard.sh"
# shellcheck source=scripts/lib/pmctl-dispatch.sh
. "$SCRIPT_DIR/lib/pmctl-dispatch.sh"
th_init "$@"
export PM_DISPATCH_STATE_ROOT="$tmp_root/dispatch-record-state"

_BRIEFS=()
_mk_guard_brief() {
  local work="$1" bf
  bf="/tmp/brief-dispatch-record-$$-${#_BRIEFS[@]}.md"
  cat > "$bf" <<EOF
schema_version: 1
working_dir: $work
goal: exercise durable dispatch records
files:
  - read: $work/README
acceptance:
  - durable record is written
self_verify:
  - cmd: "test -d .git"
EOF
  _BRIEFS+=("$bf")
  printf '%s\n' "$bf"
}

# shellcheck disable=SC2317  # invoked by the EXIT trap.
_cleanup() { rm -f "${_BRIEFS[@]}" 2>/dev/null || true; }
trap _cleanup EXIT

_install_fake_codex() {
  local bindir="$1" code="$2" mode="${3:-ok}"
  cat > "$bindir/codex" <<FAKEOF
#!/usr/bin/env bash
_last=""
while [[ \$# -gt 0 ]]; do
  case "\$1" in
    --output-last-message) _last="\$2"; shift 2 ;;
    *) shift ;;
  esac
done
if [[ -n "\$_last" && "$mode" != "empty-last" ]]; then
  printf 'dispatch complete (fake codex)\n' > "\$_last"
fi
printf '%s\n' '{"type":"turn.completed","usage":{"input_tokens":1,"output_tokens":1}}'
exit $code
FAKEOF
  chmod +x "$bindir/codex"
}

_first_record() {
  local work="$1"
  find "$work/.dispatch-results" -type f -name 'run-*.md' 2>/dev/null | sort | head -1
}

case_ok_record_written() {
  local name="dispatch-record/ok run writes result record"
  should_run "$name" || return 0
  local work brief bindir out code record
  work="$(mktemp -d)"; git init -q "$work"
  brief="$(_mk_guard_brief "$work")"
  bindir="$(mktemp -d)"; _install_fake_codex "$bindir" 0
  set +e
  out="$(PATH="$bindir:$PATH" "$PMCTL" dispatch run --adapter codex --cd "$work" --brief-file "$brief" 2>&1)"; code=$?
  set -e
  record="$(_first_record "$work")"
  if [[ "$code" -eq 0 ]] \
    && [[ "$record" == "$work/.dispatch-results/"run-*.md ]] \
    && grep -q '^run_id: "run-' "$record" \
    && grep -q '^executor: "codex"$' "$record" \
    && grep -q '^exit_code: 0$' "$record" \
    && grep -q '^final_state: "ok"$' "$record" \
    && grep -q 'PASS: trace structurally complete' "$record" \
    && grep -q '^OK$' <<<"$out"; then
    pass "$name"
  else
    fail "$name" "code=$code record=${record:-missing} tail=$(tail -4 <<<"$out" | tr '\n' '|')"
  fi
  rm -rf "$work" "$bindir"
}

case_failed_record_written() {
  local name="dispatch-record/adapter failure writes failed record"
  should_run "$name" || return 0
  local work brief bindir code record
  work="$(mktemp -d)"; git init -q "$work"
  brief="$(_mk_guard_brief "$work")"
  bindir="$(mktemp -d)"; _install_fake_codex "$bindir" 7
  set +e
  PATH="$bindir:$PATH" "$PMCTL" dispatch run --adapter codex --cd "$work" --brief-file "$brief" >/dev/null 2>&1; code=$?
  set -e
  record="$(_first_record "$work")"
  if [[ "$code" -eq 7 ]] \
    && [[ "$record" == "$work/.dispatch-results/"run-*.md ]] \
    && grep -q '^executor: "codex"$' "$record" \
    && grep -q '^exit_code: 7$' "$record" \
    && grep -q '^final_state: "failed"$' "$record" \
    && grep -q 'adapter exited before post-verify' "$record"; then
    pass "$name"
  else
    fail "$name" "code=$code record=${record:-missing}"
  fi
  rm -rf "$work" "$bindir"
}

case_post_verify_summary_captured() {
  local name="dispatch-record/post-verify failure captures verify summary"
  should_run "$name" || return 0
  local work brief bindir code record out
  work="$(mktemp -d)"; git init -q "$work"
  brief="$(_mk_guard_brief "$work")"
  bindir="$(mktemp -d)"; _install_fake_codex "$bindir" 0 empty-last
  set +e
  out="$(PATH="$bindir:$PATH" "$PMCTL" dispatch run --adapter codex --cd "$work" --brief-file "$brief" 2>&1)"; code=$?
  set -e
  record="$(_first_record "$work")"
  if [[ "$code" -eq 1 ]] \
    && [[ "$record" == "$work/.dispatch-results/"run-*.md ]] \
    && grep -q '^final_state: "failed"$' "$record" \
    && grep -q 'FAILED: latest.last not found' "$record" \
    && grep -q 'post-verify failed' <<<"$out"; then
    pass "$name"
  else
    fail "$name" "code=$code record=${record:-missing}"
  fi
  rm -rf "$work" "$bindir"
}

case_print_cmd_writes_no_record() {
  local name="dispatch-record/print-cmd writes no record"
  should_run "$name" || return 0
  local work brief code count
  work="$(mktemp -d)"; git init -q "$work"
  brief="$(_mk_guard_brief "$work")"
  set +e
  "$PMCTL" dispatch run --adapter codex --cd "$work" --brief-file "$brief" --print-cmd >/dev/null 2>&1; code=$?
  set -e
  if [[ -d "$work/.dispatch-results" ]]; then
    count="$(find "$work/.dispatch-results" -type f | wc -l | tr -d ' ')"
  else
    count=0
  fi
  if [[ "$code" -eq 0 && "$count" -eq 0 ]]; then
    pass "$name"
  else
    fail "$name" "code=$code record_count=$count"
  fi
  rm -rf "$work"
}

case_record_failure_is_soft() {
  local name="dispatch-record/write failure preserves dispatch exit"
  should_run "$name" || return 0
  local work brief bindir out code
  work="$(mktemp -d)"; git init -q "$work"
  brief="$(_mk_guard_brief "$work")"
  bindir="$(mktemp -d)"; _install_fake_codex "$bindir" 0
  dispatch_record_write() { return 42; }
  set +e
  out="$(PATH="$bindir:$PATH" pmctl_dispatch_run "$REPO_ROOT" --adapter codex --cd "$work" --brief-file "$brief" 2>&1)"; code=$?
  set -e
  unset -f dispatch_record_write
  # shellcheck source=scripts/lib/dispatch-record.sh
  . "$SCRIPT_DIR/lib/dispatch-record.sh"
  if [[ "$code" -eq 0 ]] \
    && grep -q '^OK$' <<<"$out" \
    && grep -q 'failed to write dispatch record' <<<"$out"; then
    pass "$name"
  else
    fail "$name" "code=$code tail=$(tail -5 <<<"$out" | tr '\n' '|')"
  fi
  rm -rf "$work" "$bindir"
}

case_read_state_terminal_record() {
  local name="dispatch-record/read_state returns terminal frontmatter"
  should_run "$name" || return 0
  local work run_id code
  work="$(mktemp -d)"
  run_id="run-20260618T000000Z-abcdef"
  dispatch_record_write "$run_id" "CC-399" "codex" "default" "/tmp/brief-dispatch-record.md" \
    "$work" 0 "ok" "PASS: example summary" "/tmp/last" "/tmp/trace" "/tmp/stderr" \
    "2026-06-18T00:00:00Z" "2026-06-18T00:00:01Z"
  set +e
  dispatch_record_read_state "$work" "$run_id"; code=$?
  set -e
  if [[ "$code" -eq 0 ]] \
    && [[ "$DISPATCH_RECORD_STATE" == "ok" ]] \
    && [[ "$DISPATCH_RECORD_EXIT" == "0" ]] \
    && [[ "$DISPATCH_RECORD_SUMMARY" == "PASS: example summary" ]]; then
    pass "$name"
  else
    fail "$name" "code=$code state=${DISPATCH_RECORD_STATE:-} exit=${DISPATCH_RECORD_EXIT:-} summary=${DISPATCH_RECORD_SUMMARY:-}"
  fi
  rm -rf "$work"
}

case_read_state_absent_is_nonterminal() {
  local name="dispatch-record/read_state absent record is non-terminal"
  should_run "$name" || return 0
  local work code
  work="$(mktemp -d)"
  set +e
  dispatch_record_read_state "$work" "run-20260618T000000Z-abcdef"; code=$?
  set -e
  if [[ "$code" -eq 1 ]]; then
    pass "$name"
  else
    fail "$name" "code=$code"
  fi
  rm -rf "$work"
}

case_ok_record_written
case_failed_record_written
case_post_verify_summary_captured
case_print_cmd_writes_no_record
case_record_failure_is_soft
case_read_state_terminal_record
case_read_state_absent_is_nonterminal
th_summary
