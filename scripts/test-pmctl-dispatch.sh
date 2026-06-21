#!/usr/bin/env bash
# Regression tests for `pmctl dispatch run` — the executor-agnostic dispatch
# orchestrator (CC-289, approach B).
#
# Scope: the SHARED flow pmctl owns — adapter resolution by convention, route,
# brief-validate, guard, adapter invocation, output-contract read, post-verify,
# and exit-code semantics. Executor-specific behaviour is covered by the adapter
# suite (test-codex-dispatch.sh); these tests drive a FAKE codex on PATH so they
# never depend on a real executor.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PMCTL="$REPO_ROOT/cli/pmctl"

# shellcheck source=scripts/lib/test-harness.sh
. "$SCRIPT_DIR/lib/test-harness.sh"
# Sourced for the route-failure branch test, which drives pmctl_dispatch_run
# directly against a fixture repo_root (see case_route_failure_branch).
# shellcheck source=scripts/lib/executor-router.sh
. "$SCRIPT_DIR/lib/executor-router.sh"
# shellcheck source=scripts/lib/pmctl-dispatch.sh
. "$SCRIPT_DIR/lib/pmctl-dispatch.sh"
th_init "$@"
export PM_DISPATCH_STATE_ROOT="$tmp_root/pmctl-dispatch-state"

# A guard-allowed brief path is /tmp/brief-<...>.md (codex pre-write allow-list).
# Track created brief files so we always clean /tmp.
_BRIEFS=()
_mk_guard_brief() {
  # $1 = work_dir; echoes a valid brief at a guard-allowed /tmp path.
  local work="$1" bf
  bf="/tmp/brief-pmctl-dispatch-$$-${#_BRIEFS[@]}.md"
  cat > "$bf" <<EOF
schema_version: 1
working_dir: $work
goal: exercise the pmctl dispatch orchestrator shared flow
files:
  - read: $work/README
acceptance:
  - dispatch exits 0
EOF
  _BRIEFS+=("$bf")
  printf '%s\n' "$bf"
}
_cleanup() { rm -f "${_BRIEFS[@]}" 2>/dev/null || true; }
trap _cleanup EXIT

# A fake codex that honours the output contract: writes the --output-last-message
# file (so latest.last is non-empty) and emits a turn.completed event on stdout.
_install_fake_codex() {
  # $1 = bin dir, $2 = exit code the fake should return
  local bindir="$1" code="$2"
  cat > "$bindir/codex" <<FAKEOF
#!/usr/bin/env bash
_last=""
while [[ \$# -gt 0 ]]; do
  case "\$1" in
    --output-last-message) _last="\$2"; shift 2;;
    *) shift;;
  esac
done
[[ -n "\$_last" ]] && printf 'dispatch complete (fake codex)\n' > "\$_last"
printf '%s\n' '{"type":"turn.completed","usage":{"input_tokens":10,"output_tokens":5}}'
exit $code
FAKEOF
  chmod +x "$bindir/codex"
}

# ---- 1: missing --adapter → exit 2 ----
case_missing_adapter() {
  local name="dispatch/missing --adapter exits 2"
  should_run "$name" || return 0
  local err code
  set +e
  err="$("$PMCTL" dispatch run --lifecycle foreground --cd /tmp 2>&1)"; code=$?
  set -e
  if [[ "$code" -eq 2 ]] && grep -qi 'adapter.*required' <<<"$err"; then
    pass "$name"
  else
    fail "$name" "code=$code err=$(head -1 <<<"$err")"
  fi
}

# ---- 2: unknown adapter (no adapters/<name>/dispatch.sh) → exit 2 ----
case_unknown_adapter() {
  local name="dispatch/unknown adapter exits 2"
  should_run "$name" || return 0
  local err code
  set +e
  err="$("$PMCTL" dispatch run --lifecycle foreground --adapter nope --cd /tmp --brief-file /tmp/x.md 2>&1)"; code=$?
  set -e
  if [[ "$code" -eq 2 ]] && grep -qi 'unknown adapter' <<<"$err"; then
    pass "$name"
  else
    fail "$name" "code=$code err=$(head -1 <<<"$err")"
  fi
}

# ---- 3: adapter resolved by convention + route logged (dry-run) ----
case_adapter_resolution_and_route() {
  local name="dispatch/adapter resolved by convention + route logged"
  should_run "$name" || return 0
  local work brief out err code
  work="$(mktemp -d)"; git init -q "$work"
  brief="$(_mk_guard_brief "$work")"
  set +e
  out="$("$PMCTL" dispatch run --lifecycle foreground --adapter codex --cd "$work" --brief-file "$brief" --print-cmd 2>/tmp/_t3.$$)"; code=$?
  err="$(cat /tmp/_t3.$$)"; rm -f /tmp/_t3.$$
  set -e
  if [[ "$code" -eq 0 ]] \
     && grep -q 'CMD=codex exec' <<<"$out" \
     && grep -q 'adapter=codex route=main_thread_bash_background' <<<"$err"; then
    pass "$name"
  else
    fail "$name" "code=$code"
  fi
  rm -rf "$work"
}

# ---- 4: brief fails validation → exit 2 (before any adapter invocation) ----
case_brief_validation_blocks() {
  local name="dispatch/invalid brief blocks with exit 2"
  should_run "$name" || return 0
  local work brief err code
  work="$(mktemp -d)"; git init -q "$work"
  # Missing required fields (no schema_version/files/acceptance).
  brief="/tmp/brief-pmctl-dispatch-$$-bad.md"
  printf 'goal: incomplete brief\n' > "$brief"
  _BRIEFS+=("$brief")
  set +e
  err="$("$PMCTL" dispatch run --lifecycle foreground --adapter codex --cd "$work" --brief-file "$brief" --print-cmd 2>&1)"; code=$?
  set -e
  if [[ "$code" -eq 2 ]] && grep -qi 'failed validation' <<<"$err"; then
    pass "$name"
  else
    fail "$name" "code=$code err=$(head -1 <<<"$err")"
  fi
  rm -rf "$work"
}

# ---- 5: guard denies a brief outside the allowed path → exit 2 ----
case_guard_denies_dispatch() {
  local name="dispatch/guard denies brief outside allowed path"
  should_run "$name" || return 0
  local work brief err code
  work="$(mktemp -d)"; git init -q "$work"
  # Valid brief content, but located OUTSIDE /tmp/brief-*.md → codex write-guard denies.
  brief="$work/brief.md"
  cat > "$brief" <<EOF
schema_version: 1
working_dir: $work
goal: brief at a guard-denied location
files:
  - read: $work/README
acceptance:
  - dispatch exits 0
EOF
  set +e
  err="$("$PMCTL" dispatch run --lifecycle foreground --adapter codex --cd "$work" --brief-file "$brief" --print-cmd 2>&1)"; code=$?
  set -e
  if [[ "$code" -eq 2 ]] && grep -qi 'guard denied' <<<"$err"; then
    pass "$name"
  else
    fail "$name" "code=$code err=$(head -1 <<<"$err")"
  fi
  rm -rf "$work"
}

case_guard_denied_brief_creates_no_pack_artifact() {
  # Security regression (CC-402): the authored --brief-file is guarded for path policy
  # BEFORE auto-pack reads/copies it, so a guard-denied brief must leave NO derived
  # artifact — no pack under .pm-dispatch/ctx/packs/ and no context.auto_packed event —
  # even when reuse hits are available. Fails if auto-pack runs ahead of the guard.
  # Steps:
  # 1. Seed src/alpha.sh + `pmctl context index` (reuse hits available).
  # 2. Place a valid brief OUTSIDE /tmp (guard-denied) with a goal matching the hits;
  #    run `pmctl dispatch run --auto-pack`.
  # 3. Assert exit 2 + "guard denied", zero pack files, and zero context.auto_packed
  #    events (the authored brief is guarded before any auto-pack read/copy).
  local name="dispatch/guard-denied brief with reuse hits creates no pack artifact"
  should_run "$name" || return 0
  local work brief state_root err code packs autopacked
  work="$(mktemp -d)"; git init -q "$work"
  mkdir -p "$work/src"
  cat > "$work/src/alpha.sh" <<'EOF'
#!/usr/bin/env bash
alpha_beta_dispatch_helper() {
  printf 'alpha beta dispatch helper\n'
}
EOF
  "$PMCTL" context index "$work" >/dev/null 2>/dev/null
  # Valid content but OUTSIDE /tmp/brief-*.md (guard denies); goal matches the indexed
  # content so auto-pack WOULD find hits if it wrongly ran before the guard.
  brief="$work/brief.md"
  cat > "$brief" <<EOF
schema_version: 1
working_dir: $work
goal: exercise the pmctl dispatch orchestrator shared flow
files:
  - read: $work/README
acceptance:
  - dispatch exits 0
EOF
  state_root="$(mktemp -d)"
  set +e
  err="$(PM_DISPATCH_STATE_ROOT="$state_root" \
    "$PMCTL" dispatch run --lifecycle foreground --adapter codex --cd "$work" --brief-file "$brief" --auto-pack 2>&1)"; code=$?
  set -e
  # Guard the dir test: the packs/ dir is created by auto-pack, which (correctly) never
  # ran here — find on a missing dir exits non-zero and would trip set -o pipefail.
  packs=0
  [[ -d "$work/.pm-dispatch/ctx/packs" ]] && packs="$(find "$work/.pm-dispatch/ctx/packs" -type f -name '*.md' 2>/dev/null | wc -l | tr -d ' ')"
  autopacked="$(PM_DISPATCH_STATE_ROOT="$state_root" "$PMCTL" trace tail --kind context.auto_packed --all --json 2>/dev/null | wc -l | tr -d ' ')"
  if [[ "$code" -eq 2 ]] && grep -qi 'guard denied' <<<"$err" \
     && [[ "$packs" -eq 0 ]] \
     && [[ "$autopacked" -eq 0 ]]; then
    pass "$name"
  else
    fail "$name" "code=$code packs=$packs autopacked=$autopacked err=$(head -1 <<<"$err")"
  fi
  rm -rf "$work" "$state_root"
}

# ---- 6: happy path — adapter runs, output contract read, post-verify OK ----
case_happy_path_post_verify_ok() {
  local name="dispatch/happy path runs adapter + post-verify OK"
  should_run "$name" || return 0
  local work brief bindir out code
  work="$(mktemp -d)"; git init -q "$work"
  brief="$(_mk_guard_brief "$work")"
  bindir="$(mktemp -d)"; _install_fake_codex "$bindir" 0
  set +e
  out="$(PATH="$bindir:$PATH" "$PMCTL" dispatch run --lifecycle foreground --adapter codex --cd "$work" --brief-file "$brief" 2>&1)"; code=$?
  set -e
  if [[ "$code" -eq 0 ]] \
     && grep -q '^OK$' <<<"$out" \
     && [[ -s "$work/.agent-trace/latest.last" ]]; then
    pass "$name"
  else
    fail "$name" "code=$code tail=$(tail -2 <<<"$out" | tr '\n' '|')"
  fi
  rm -rf "$work" "$bindir"
}

# ---- 7: adapter non-zero exit is propagated verbatim (no post-verify) ----
case_adapter_exit_propagated() {
  local name="dispatch/adapter failure exit propagated"
  should_run "$name" || return 0
  local work brief bindir code
  work="$(mktemp -d)"; git init -q "$work"
  brief="$(_mk_guard_brief "$work")"
  bindir="$(mktemp -d)"; _install_fake_codex "$bindir" 7
  set +e
  PATH="$bindir:$PATH" "$PMCTL" dispatch run --lifecycle foreground --adapter codex --cd "$work" --brief-file "$brief" >/dev/null 2>&1; code=$?
  set -e
  if [[ "$code" -eq 7 ]]; then
    pass "$name"
  else
    fail "$name" "expected 7, got $code"
  fi
  rm -rf "$work" "$bindir"
}

# ---- 8: clean adapter exit but broken output contract → post-verify fails (1) ----
case_post_verify_failure() {
  local name="dispatch/post-verify failure returns 1"
  should_run "$name" || return 0
  local work brief bindir code
  work="$(mktemp -d)"; git init -q "$work"
  brief="$(_mk_guard_brief "$work")"
  bindir="$(mktemp -d)"
  # Fake codex exits 0 but writes NOTHING to --output-last-message → latest.last
  # ends up empty → post-verify must fail.
  cat > "$bindir/codex" <<'FAKEOF'
#!/usr/bin/env bash
printf '%s\n' '{"type":"turn.completed","usage":{"input_tokens":1,"output_tokens":1}}'
exit 0
FAKEOF
  chmod +x "$bindir/codex"
  set +e
  PATH="$bindir:$PATH" "$PMCTL" dispatch run --lifecycle foreground --adapter codex --cd "$work" --brief-file "$brief" >/dev/null 2>&1; code=$?
  set -e
  if [[ "$code" -eq 1 ]]; then
    pass "$name"
  else
    fail "$name" "expected 1 (post-verify fail), got $code"
  fi
  rm -rf "$work" "$bindir"
}

# ---- 9: invalid adapter name (path-like) is rejected before path resolution ----
case_invalid_adapter_name() {
  local name="dispatch/invalid adapter name rejected (no path traversal)"
  should_run "$name" || return 0
  local err code
  set +e
  err="$("$PMCTL" dispatch run --lifecycle foreground --adapter ../codex --cd /tmp --brief-file /tmp/x.md 2>&1)"; code=$?
  set -e
  if [[ "$code" -eq 2 ]] && grep -qi 'invalid adapter name' <<<"$err"; then
    pass "$name"
  else
    fail "$name" "code=$code err=$(head -1 <<<"$err")"
  fi
}

# ---- 10: inline brief form (--) is refused (no policy bypass) ----
case_inline_brief_rejected() {
  local name="dispatch/inline brief form refused (policy bypass closed)"
  should_run "$name" || return 0
  local work err code
  work="$(mktemp -d)"; git init -q "$work"
  set +e
  err="$("$PMCTL" dispatch run --lifecycle foreground --adapter codex --cd "$work" -- do a thing 2>&1)"; code=$?
  set -e
  if [[ "$code" -eq 2 ]] && grep -qi 'inline brief form' <<<"$err"; then
    pass "$name"
  else
    fail "$name" "code=$code err=$(head -1 <<<"$err")"
  fi
  rm -rf "$work"
}

# ---- 11: present-but-non-routable adapter is blocked by the allowlist ----
# Drives pmctl_dispatch_run directly against a fixture repo whose adapter dir
# exists but whose name is not a registered route — exercising the route-failure
# branch (the dispatch allowlist) before brief-validate/guard are reached.
case_route_failure_branch() {
  local name="dispatch/non-routable adapter blocked by allowlist"
  should_run "$name" || return 0
  local fixture brief code err
  fixture="$(mktemp -d)"
  mkdir -p "$fixture/adapters/faketest"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$fixture/adapters/faketest/dispatch.sh"
  chmod +x "$fixture/adapters/faketest/dispatch.sh"
  brief="/tmp/brief-pmctl-dispatch-$$-route.md"
  printf 'schema_version: 1\n' > "$brief"; _BRIEFS+=("$brief")
  set +e
  err="$(pmctl_dispatch_run "$fixture" --adapter faketest --cd "$fixture" --brief-file "$brief" 2>&1)"; code=$?
  set -e
  if [[ "$code" -eq 2 ]] && grep -qi 'not a routable executor' <<<"$err"; then
    pass "$name"
  else
    fail "$name" "code=$code err=$(head -1 <<<"$err")"
  fi
  rm -rf "$fixture"
}

# ---- 12: fail-closed when the routing registry (executor-router) is absent ----
# A missing allowlist must REFUSE the dispatch, never silently skip enforcement.
case_routing_unavailable_fails_closed() {
  local name="dispatch/routing registry unavailable fails closed"
  should_run "$name" || return 0
  local work code err
  work="$(mktemp -d)"; git init -q "$work"
  set +e
  # Drop dispatch_route_for in a subshell; codex adapter exists + name is valid,
  # so the function reaches the route step and must fail closed.
  err="$( unset -f dispatch_route_for
          pmctl_dispatch_run "$REPO_ROOT" --adapter codex --cd "$work" --brief-file /tmp/x.md 2>&1 )"; code=$?
  set -e
  if [[ "$code" -eq 2 ]] && grep -qi 'routing registry unavailable' <<<"$err"; then
    pass "$name"
  else
    fail "$name" "code=$code err=$(head -1 <<<"$err")"
  fi
  rm -rf "$work"
}

# ---- 13: fail-closed when the guard (pmctl-guard) is absent ----
case_guard_unavailable_fails_closed() {
  local name="dispatch/guard unavailable fails closed"
  should_run "$name" || return 0
  local work brief code err
  work="$(mktemp -d)"; git init -q "$work"
  brief="$(_mk_guard_brief "$work")"   # valid brief so route + brief-validate pass
  set +e
  # pmctl_guard_check is not sourced here; unset is belt-and-suspenders. The flow
  # passes route + brief-validate, then must fail closed at the guard step.
  err="$( unset -f pmctl_guard_check
          pmctl_dispatch_run "$REPO_ROOT" --adapter codex --cd "$work" --brief-file "$brief" 2>&1 )"; code=$?
  set -e
  if [[ "$code" -eq 2 ]] && grep -qi 'guard unavailable' <<<"$err"; then
    pass "$name"
  else
    fail "$name" "code=$code err=$(head -1 <<<"$err")"
  fi
  rm -rf "$work"
}

# ---- 14: missing --cd is rejected ----
case_missing_cd() {
  local name="dispatch/missing --cd rejected"
  should_run "$name" || return 0
  local err code
  set +e
  err="$("$PMCTL" dispatch run --lifecycle foreground --adapter codex --brief-file /tmp/x.md 2>&1)"; code=$?
  set -e
  if [[ "$code" -eq 2 ]] && grep -qi '\-\-cd <dir> is required' <<<"$err"; then
    pass "$name"
  else
    fail "$name" "code=$code err=$(head -1 <<<"$err")"
  fi
}

# ---- 15: missing --brief-file is rejected (no brief-less path) ----
case_missing_brief_file() {
  local name="dispatch/missing --brief-file rejected"
  should_run "$name" || return 0
  local work err code
  work="$(mktemp -d)"; git init -q "$work"
  set +e
  err="$("$PMCTL" dispatch run --lifecycle foreground --adapter codex --cd "$work" 2>&1)"; code=$?
  set -e
  if [[ "$code" -eq 2 ]] && grep -qi '\-\-brief-file <path> is required' <<<"$err"; then
    pass "$name"
  else
    fail "$name" "code=$code err=$(head -1 <<<"$err")"
  fi
  rm -rf "$work"
}

# ---- 16: a symlinked adapter dispatch.sh is rejected (trust-boundary escape) ----
case_symlinked_adapter_rejected() {
  local name="dispatch/symlinked adapter dispatch.sh rejected"
  should_run "$name" || return 0
  local fixture target work brief code err
  fixture="$(mktemp -d)"
  mkdir -p "$fixture/adapters/evil"
  target="$(mktemp)"; printf '#!/usr/bin/env bash\nexit 0\n' > "$target"; chmod +x "$target"
  ln -s "$target" "$fixture/adapters/evil/dispatch.sh"   # points OUTSIDE the repo
  # MSYS/Git-Bash without Developer Mode copies on `ln -s`; with no symlink to
  # reject this case has nothing to assert, so skip rather than fail.
  if [[ ! -L "$fixture/adapters/evil/dispatch.sh" ]]; then
    printf 'SKIP: %s (ln -s did not create a symlink on this platform)\n' "$name"
    rm -rf "$fixture"; rm -f "$target"
    return 0
  fi
  work="$(mktemp -d)"; git init -q "$work"
  brief="/tmp/brief-pmctl-dispatch-$$-evil.md"; printf 'schema_version: 1\n' > "$brief"; _BRIEFS+=("$brief")
  set +e
  err="$(pmctl_dispatch_run "$fixture" --adapter evil --cd "$work" --brief-file "$brief" 2>&1)"; code=$?
  set -e
  if [[ "$code" -eq 2 ]] && grep -qi 'must not be a symlink' <<<"$err"; then
    pass "$name"
  else
    fail "$name" "code=$code err=$(head -1 <<<"$err")"
  fi
  rm -rf "$fixture" "$work"; rm -f "$target"
}

# ---- 17: a non-core adapter-specific flag is forwarded unchanged ----
# pmctl consumes --adapter and peeks --cd/--brief-file; every other flag (here
# --approval, which pmctl does not interpret) must pass through to the adapter
# verbatim and in order.
case_arg_passthrough() {
  local name="dispatch/non-core flag forwarded to adapter unchanged"
  should_run "$name" || return 0
  local work brief out code
  work="$(mktemp -d)"; git init -q "$work"
  brief="$(_mk_guard_brief "$work")"
  set +e
  out="$("$PMCTL" dispatch run --lifecycle foreground --adapter codex --cd "$work" --brief-file "$brief" \
         --approval on-request --print-cmd 2>/dev/null)"; code=$?
  set -e
  # The codex adapter renders --approval into `approval_policy="<val>"`; seeing the
  # exact value proves the flag+value were forwarded unchanged and in order.
  if [[ "$code" -eq 0 ]] && grep -q 'approval_policy="on-request"' <<<"$out"; then
    pass "$name"
  else
    fail "$name" "code=$code"
  fi
  rm -rf "$work"
}

# ---- 17b: native-flag passthrough cannot bypass the codex full-access cut ----
# pmctl forwards non-core flags verbatim, so a caller could try to escalate the
# codex sandbox with the raw native `--sandbox danger-full-access` flag past the
# isolation_level:none rejection. The codex adapter rejects that value fail-loud,
# and pmctl must propagate the non-zero exit — full access stays unreachable.
case_sandbox_danger_full_access_denied() {
  local name="dispatch/codex --sandbox danger-full-access rejected (no native-flag bypass)"
  should_run "$name" || return 0
  local work brief out code
  work="$(mktemp -d)"; git init -q "$work"
  brief="$(_mk_guard_brief "$work")"
  set +e
  out="$("$PMCTL" dispatch run --lifecycle foreground --adapter codex --cd "$work" --brief-file "$brief" \
         --sandbox danger-full-access --print-cmd 2>&1)"; code=$?
  set -e
  if [[ "$code" -ne 0 ]] && grep -qi 'danger-full-access is not supported' <<<"$out"; then
    pass "$name"
  else
    fail "$name" "expected non-zero exit + rejection message; code=$code out=$(head -2 <<<"$out")"
  fi
  rm -rf "$work"
}

# Installs a fake codex that writes valid per-run output but then corrupts
# latest.last by relinking it to a file with "status: failed" — simulating a
# concurrent-dispatch race (CC-305).  If pmctl reads latest.last post-verify fails;
# if it uses the explicit per-run path from the footer, it passes.
_install_fake_codex_stale_symlink() {
  local bindir="$1"
  cat > "$bindir/codex" <<'FAKEOF'
#!/usr/bin/env bash
_last=""
while [[ $# -gt 0 ]]; do
  case "$1" in --output-last-message) _last="$2"; shift 2;; *) shift;; esac
done
[[ -n "$_last" ]] && printf 'dispatch complete (fake codex)\n' > "$_last"
if [[ -n "$_last" ]]; then
  _trace="$(dirname "$_last")"
  printf 'status: failed\n' > "$_trace/wrong.last"
  ln -sfn "wrong.last" "$_trace/latest.last"
fi
printf '%s\n' '{"type":"turn.completed","usage":{"input_tokens":10,"output_tokens":5}}'
exit 0
FAKEOF
  chmod +x "$bindir/codex"
}

# ---- 18: CC-305 regression — stale latest.last does not mislead post-verify ----
# latest.last is repointed to wrong content by a simulated concurrent dispatch;
# pmctl must pass the explicit per-run path (from the footer) to post-verify.
case_stale_latest_symlink_avoidance() {
  local name="dispatch/cc305 — stale latest.last does not mislead post-verify"
  should_run "$name" || return 0
  local work brief bindir out code
  work="$(mktemp -d)"; git init -q "$work"
  brief="$(_mk_guard_brief "$work")"
  bindir="$(mktemp -d)"; _install_fake_codex_stale_symlink "$bindir"
  set +e
  out="$(PATH="$bindir:$PATH" "$PMCTL" dispatch run --lifecycle foreground --adapter codex --cd "$work" --brief-file "$brief" 2>&1)"; code=$?
  set -e
  # latest.last → wrong.last contains "status: failed" — if pmctl read it,
  # post-verify would fail with code 1.  Explicit footer path has the real output.
  if [[ "$code" -eq 0 ]] && grep -q '^OK' <<<"$out"; then
    pass "$name"
  else
    fail "$name" "code=$code tail=$(tail -3 <<<"$out" | tr '\n' '|')"
  fi
  rm -rf "$work" "$bindir"
}

# ---- 18b: CC-386 — footer `trace:` is threaded to post-verify as --jsonl ----
# Proves pmctl parses the adapter footer `trace:` line and passes the per-run
# JSONL path to post-verify (not the shared latest.jsonl). Distinguishing signal:
# the trace-integrity PASS line names the per-run codex-<ts>.jsonl path; had pmctl
# not threaded it, post-verify would fall back to the latest.jsonl default. The
# fake codex re-points latest.jsonl mid-run (same race shape as case 18) so a
# latest.jsonl reader would not get this run's trace.
_install_fake_codex_stale_jsonl_symlink() {
  local bindir="$1"
  cat > "$bindir/codex" <<'FAKEOF'
#!/usr/bin/env bash
_last=""
while [[ $# -gt 0 ]]; do
  case "$1" in --output-last-message) _last="$2"; shift 2;; *) shift;; esac
done
[[ -n "$_last" ]] && printf 'dispatch complete (fake codex)\n' > "$_last"
if [[ -n "$_last" ]]; then
  _trace="$(dirname "$_last")"
  printf '{"type":"turn.compl\n' > "$_trace/wrong.jsonl"
  ln -sfn "wrong.jsonl" "$_trace/latest.jsonl"
fi
printf '%s\n' '{"type":"turn.completed","usage":{"input_tokens":10,"output_tokens":5}}'
exit 0
FAKEOF
  chmod +x "$bindir/codex"
}

case_footer_trace_threaded_to_post_verify() {
  local name="dispatch/cc386 — footer trace: threaded to post-verify as --jsonl"
  should_run "$name" || return 0
  local work brief bindir out code
  work="$(mktemp -d)"; git init -q "$work"
  brief="$(_mk_guard_brief "$work")"
  bindir="$(mktemp -d)"; _install_fake_codex_stale_jsonl_symlink "$bindir"
  set +e
  out="$(PATH="$bindir:$PATH" "$PMCTL" dispatch run --lifecycle foreground --adapter codex --cd "$work" --brief-file "$brief" 2>&1)"; code=$?
  set -e
  # The trace-integrity PASS line must reference the per-run codex-<ts>.jsonl
  # (from the footer), proving --jsonl was threaded; overall post-verify is OK.
  if [[ "$code" -eq 0 ]] \
     && grep -qE 'PASS: trace structurally complete.*codex-[0-9].*\.jsonl' <<<"$out" \
     && grep -q '^OK' <<<"$out"; then
    pass "$name"
  else
    fail "$name" "code=$code tail=$(tail -5 <<<"$out" | tr '\n' '|')"
  fi
  rm -rf "$work" "$bindir"
}

case_footer_persisted_and_paths_parse() {
  local name="dispatch/footer persists with per-run artifact paths"
  should_run "$name" || return 0
  local work brief bindir out code footer last_path trace_path stderr_path record
  work="$(mktemp -d)"; git init -q "$work"
  brief="$(_mk_guard_brief "$work")"
  bindir="$(mktemp -d)"; _install_fake_codex "$bindir" 0
  set +e
  out="$(PATH="$bindir:$PATH" "$PMCTL" dispatch run --lifecycle foreground --adapter codex --cd "$work" --brief-file "$brief" 2>&1)"; code=$?
  set -e
  footer="$(find "$work/.agent-trace" -maxdepth 1 -type f -name 'run-*.footer' 2>/dev/null | sort | head -1)"
  last_path="$(sed -n 's/^last:[[:space:]]*//p' "$footer" 2>/dev/null | head -1)"
  trace_path="$(sed -n 's/^trace:[[:space:]]*//p' "$footer" 2>/dev/null | head -1)"
  stderr_path="$(sed -n 's/^stderr:[[:space:]]*//p' "$footer" 2>/dev/null | head -1)"
  record="$(find "$work/.dispatch-results" -type f -name 'run-*.md' 2>/dev/null | sort | head -1)"
  if [[ "$code" -eq 0 ]] \
     && grep -q '^OK' <<<"$out" \
     && [[ "$footer" == "$work/.agent-trace/"run-*.footer ]] \
     && [[ -s "$footer" ]] \
     && [[ "$last_path" == "$work/.agent-trace/"codex-*.last ]] \
     && [[ "$trace_path" == "$work/.agent-trace/"codex-*.jsonl ]] \
     && [[ "$stderr_path" == "$work/.agent-trace/"codex-*.stderr ]] \
     && [[ -s "$last_path" ]] \
     && [[ -s "$trace_path" ]] \
     && [[ -e "$stderr_path" ]] \
     && grep -Fq "last_path: \"$last_path\"" "$record" \
     && grep -Fq "trace_path: \"$trace_path\"" "$record" \
     && grep -Fq "stderr_path: \"$stderr_path\"" "$record"; then
    pass "$name"
  else
    fail "$name" "code=$code footer=$footer last=$last_path trace=$trace_path stderr=$stderr_path"
  fi
  rm -rf "$work" "$bindir"
}

case_execute_tail_direct_lifecycle_identity() {
  local name="dispatch/extracted tail preserves foreground lifecycle"
  should_run "$name" || return 0
  local work brief bindir out code run_id created_ts footer record states
  local -a forward=()
  work="$(mktemp -d)"; git init -q "$work"
  brief="$(_mk_guard_brief "$work")"
  bindir="$(mktemp -d)"; _install_fake_codex "$bindir" 0
  run_id="run-$(pmctl_dispatch_stamp)-$(pmctl_dispatch_hex6)"
  created_ts="$(pmctl_dispatch_utc_ts)"
  forward=(--cd "$work" --brief-file "$brief")
  set +e
  out="$(PATH="$bindir:$PATH" pmctl_dispatch_execute_tail "$REPO_ROOT" "$work" codex \
    "$REPO_ROOT/adapters/codex/dispatch.sh" "$run_id" "" "$brief" "$created_ts" 0 \
    "${forward[@]}" 2>&1)"; code=$?
  set -e
  footer="$work/.agent-trace/$run_id.footer"
  record="$work/.dispatch-results/$run_id.md"
  states="$(find "$PM_DISPATCH_STATE_ROOT" -type f -name events.jsonl \
    -exec jq -r --arg run "$run_id" 'select(.subject_id == $run) | .payload.state' {} + 2>/dev/null \
    | paste -sd, -)"
  if [[ "$code" -eq 0 ]] \
     && grep -q '^OK' <<<"$out" \
     && [[ -s "$footer" ]] \
     && [[ -f "$record" ]] \
     && grep -q '^final_state: "ok"$' "$record" \
     && [[ "$states" == "pending,dispatched,verifying,ok" ]]; then
    pass "$name"
  else
    fail "$name" "code=$code states=$states footer=$footer"
  fi
  rm -rf "$work" "$bindir"
}

# ---- 18c: manifest terminal_event is threaded to post-verify ----
# Proves pmctl reads `terminal_event` from adapters/codex/adapter.yaml and passes
# it to post-verify as --terminal-event. Distinguishing signal: the fake codex
# emits a structurally-valid but NON-terminal trace (turn.started only, no
# turn.completed). With the manifest value threaded, post-verify's semantic check
# fires and FAILS (dispatch returns 1, output names the missing turn.completed);
# had pmctl NOT threaded it, the trace would pass structure-only and dispatch
# would return 0. So a non-zero exit + the missing-terminal-event message is proof
# the manifest field was read and threaded.
_install_fake_codex_non_terminal() {
  local bindir="$1"
  cat > "$bindir/codex" <<'FAKEOF'
#!/usr/bin/env bash
_last=""
while [[ $# -gt 0 ]]; do
  case "$1" in --output-last-message) _last="$2"; shift 2;; *) shift;; esac
done
[[ -n "$_last" ]] && printf 'dispatch complete (fake codex)\n' > "$_last"
printf '%s\n' '{"type":"turn.started"}'
exit 0
FAKEOF
  chmod +x "$bindir/codex"
}

case_manifest_terminal_event_threaded() {
  local name="dispatch/cc389 — manifest terminal_event threaded to post-verify"
  should_run "$name" || return 0
  local work brief bindir out code
  work="$(mktemp -d)"; git init -q "$work"
  brief="$(_mk_guard_brief "$work")"
  bindir="$(mktemp -d)"; _install_fake_codex_non_terminal "$bindir"
  set +e
  out="$(PATH="$bindir:$PATH" "$PMCTL" dispatch run --lifecycle foreground --adapter codex --cd "$work" --brief-file "$brief" 2>&1)"; code=$?
  set -e
  # Non-terminal trace + threaded --terminal-event turn.completed → semantic FAIL.
  if [[ "$code" -eq 1 ]] \
     && grep -q 'no "turn.completed" terminal event' <<<"$out"; then
    pass "$name"
  else
    fail "$name" "code=$code tail=$(tail -5 <<<"$out" | tr '\n' '|')"
  fi
  rm -rf "$work" "$bindir"
}

# ---- 19: adapter exit code propagated through tee stdout capture (CC-305 path) ----
# pmctl now runs the adapter via `bash adapter | tee tmpfile` and reads exit code
# from PIPESTATUS[0].  Verify the non-zero exit still reaches the caller verbatim.
case_footer_exit_propagated_through_tee() {
  local name="dispatch/adapter exit propagated through tee stdout capture"
  should_run "$name" || return 0
  local work brief bindir code
  work="$(mktemp -d)"; git init -q "$work"
  brief="$(_mk_guard_brief "$work")"
  bindir="$(mktemp -d)"; _install_fake_codex "$bindir" 13
  set +e
  PATH="$bindir:$PATH" "$PMCTL" dispatch run --lifecycle foreground --adapter codex --cd "$work" --brief-file "$brief" >/dev/null 2>&1; code=$?
  set -e
  if [[ "$code" -eq 13 ]]; then
    pass "$name"
  else
    fail "$name" "expected 13 via PIPESTATUS[0], got $code"
  fi
  rm -rf "$work" "$bindir"
}

# ---- 20: pmctl exports config timeout to adapter subprocess (CC-293) ----
# pmctl calls pm_config_load and exports PM_CFG_TIMEOUT; the codex adapter
# reads the env var (not the config file) and reflects it in the banner.
case_config_timeout_exported_to_adapter() {
  local name="config/dispatch.default_timeout exported by pmctl to adapter"
  should_run "$name" || return 0
  local home work brief stderr code
  home="$(mktemp -d)"; mkdir -p "$home/.pm-dispatch"
  printf 'dispatch.default_timeout = 750\n' > "$home/.pm-dispatch/config"
  work="$(mktemp -d)"; git init -q "$work"
  brief="$(_mk_guard_brief "$work")"
  stderr="$(mktemp)"
  set +e
  HOME="$home" CODEX_DISPATCH_TIMEOUT= \
    "$PMCTL" dispatch run --lifecycle foreground --adapter codex --cd "$work" --brief-file "$brief" --print-cmd \
    >/dev/null 2>"$stderr"; code=$?
  set -e
  if [[ "$code" -eq 0 ]] && grep -q 'timeout:  750s' "$stderr"; then
    pass "$name"
  else
    fail "$name" "code=$code timeout_line=$(grep 'timeout:' "$stderr" 2>/dev/null || true)"
  fi
  rm -rf "$home" "$work"; rm -f "$stderr"
}

# ---- 21: pmctl exports config default_model to adapter subprocess (CC-293) ----
# PM_CFG_DEFAULT_MODEL is exported by pmctl; codex adapter uses it when --model
# is not explicitly passed by the caller.
case_config_model_exported_to_adapter() {
  local name="config/dispatch.default_model exported by pmctl to adapter"
  should_run "$name" || return 0
  local home work brief out code
  home="$(mktemp -d)"; mkdir -p "$home/.pm-dispatch"
  printf 'dispatch.default_model = gpt-5.4\n' > "$home/.pm-dispatch/config"
  work="$(mktemp -d)"; git init -q "$work"
  brief="$(_mk_guard_brief "$work")"
  set +e
  out="$(HOME="$home" "$PMCTL" dispatch run --lifecycle foreground --adapter codex --cd "$work" --brief-file "$brief" \
    --print-cmd 2>/dev/null)"; code=$?
  set -e
  if [[ "$code" -eq 0 ]] && [[ "$out" == *"-m gpt-5.4"* ]] && [[ "$out" != *"-m gpt-5.5"* ]]; then
    pass "$name"
  else
    fail "$name" "code=$code out=$(grep -- '-m ' <<<"$out" || true)"
  fi
  rm -rf "$home" "$work"
}

# ---- 22: caller --model flag beats config-exported PM_CFG_DEFAULT_MODEL ----
# pmctl exports config model but the adapter's --model flag (forwarded from
# the caller) is parsed later and wins over the env var default.
case_caller_model_beats_config() {
  local name="config/caller --model flag beats config-exported default_model"
  should_run "$name" || return 0
  local home work brief out code
  home="$(mktemp -d)"; mkdir -p "$home/.pm-dispatch"
  printf 'dispatch.default_model = gpt-5.4\n' > "$home/.pm-dispatch/config"
  work="$(mktemp -d)"; git init -q "$work"
  brief="$(_mk_guard_brief "$work")"
  set +e
  out="$(HOME="$home" "$PMCTL" dispatch run --lifecycle foreground --adapter codex --cd "$work" --brief-file "$brief" \
    --model gpt-5.5 --print-cmd 2>/dev/null)"; code=$?
  set -e
  if [[ "$code" -eq 0 ]] && [[ "$out" == *"-m gpt-5.5"* ]] && [[ "$out" != *"-m gpt-5.4"* ]]; then
    pass "$name"
  else
    fail "$name" "code=$code out=$(grep -- '-m ' <<<"$out" || true)"
  fi
  rm -rf "$home" "$work"
}

# ---- 23: malformed config model → pmctl warns + adapter falls back to built-in ----
# A malformed dispatch.default_model causes pm_config_load (in pmctl) to emit a
# warning and leave PM_CFG_DEFAULT_MODEL="". The adapter then falls back to its
# built-in default alias (→ gpt-5.5).
case_config_malformed_model_warns_and_fallback() {
  local name="config/malformed dispatch.default_model warns + pmctl falls back to built-in"
  should_run "$name" || return 0
  local home work brief out stderr code
  home="$(mktemp -d)"; mkdir -p "$home/.pm-dispatch"
  printf 'dispatch.default_model = Bad!Model\n' > "$home/.pm-dispatch/config"
  work="$(mktemp -d)"; git init -q "$work"
  brief="$(_mk_guard_brief "$work")"
  stderr="$(mktemp)"
  set +e
  out="$(HOME="$home" "$PMCTL" dispatch run --lifecycle foreground --adapter codex --cd "$work" --brief-file "$brief" \
    --print-cmd 2>"$stderr")"; code=$?
  set -e
  if [[ "$code" -eq 0 ]] \
    && grep -q 'malformed value for dispatch.default_model' "$stderr" \
    && [[ "$out" == *"-m gpt-5.5"* ]] \
    && [[ "$out" != *"Bad!Model"* ]]; then
    pass "$name"
  else
    fail "$name" "code=$code out=$(grep -- '-m ' <<<"$out" || true) stderr=$(grep 'malformed' "$stderr" || true)"
  fi
  rm -rf "$home" "$work"; rm -f "$stderr"
}

# ---- 24: pmctl exports config timeout to claude adapter subprocess (CC-293) ----
# Symmetric to case_config_timeout_exported_to_adapter (case 20) but through the
# claude adapter, covering the path removed from test-claude-dispatch.sh.
case_config_timeout_exported_to_claude_adapter() {
  local name="config/dispatch.default_timeout exported by pmctl to claude adapter"
  should_run "$name" || return 0
  local home work brief stderr code
  home="$(mktemp -d)"; mkdir -p "$home/.pm-dispatch"
  printf 'dispatch.default_timeout = 820\n' > "$home/.pm-dispatch/config"
  work="$(mktemp -d)"; git init -q "$work"
  brief="$(_mk_guard_brief "$work")"
  stderr="$(mktemp)"
  set +e
  HOME="$home" CLAUDE_DISPATCH_TIMEOUT= \
    "$PMCTL" dispatch run --lifecycle foreground --adapter claude --cd "$work" --brief-file "$brief" --print-cmd \
    >/dev/null 2>"$stderr"; code=$?
  set -e
  if [[ "$code" -eq 0 ]] && grep -q 'timeout:.*820s' "$stderr"; then
    pass "$name"
  else
    fail "$name" "code=$code timeout_line=$(grep 'timeout:' "$stderr" 2>/dev/null || true)"
  fi
  rm -rf "$home" "$work"; rm -f "$stderr"
}

# ---- 25: --timeout flag forwarded by pmctl beats config-exported PM_CFG_TIMEOUT ----
# The flag is parsed last in the adapter, so it wins over env/config.
# Validates the full precedence chain: flag > env > config > 1200 default.
case_timeout_flag_beats_config_via_pmctl() {
  local name="config/--timeout flag forwarded by pmctl beats config-exported timeout"
  should_run "$name" || return 0
  local home work brief stderr code
  home="$(mktemp -d)"; mkdir -p "$home/.pm-dispatch"
  printf 'dispatch.default_timeout = 820\n' > "$home/.pm-dispatch/config"
  work="$(mktemp -d)"; git init -q "$work"
  brief="$(_mk_guard_brief "$work")"
  stderr="$(mktemp)"
  set +e
  HOME="$home" CODEX_DISPATCH_TIMEOUT= \
    "$PMCTL" dispatch run --lifecycle foreground --adapter codex --cd "$work" --brief-file "$brief" \
    --timeout 999 --print-cmd >/dev/null 2>"$stderr"; code=$?
  set -e
  if [[ "$code" -eq 0 ]] && grep -q 'timeout:  999s' "$stderr" \
     && ! grep -q 'timeout:  820s' "$stderr"; then
    pass "$name"
  else
    fail "$name" "code=$code timeout_line=$(grep 'timeout:' "$stderr" 2>/dev/null || true)"
  fi
  rm -rf "$home" "$work"; rm -f "$stderr"
}

case_auto_pack_default_on_emits_event() {
  # Built-in default flipped off -> on (CC-402): a dispatch with no --auto-pack /
  # --no-auto-pack flag and no config now auto-packs, emitting a context.auto_packed
  # event (hits may be 0 on an unindexed work dir, but the event always fires).
  # Steps:
  # 1. Create a git work dir + read-only guard brief; set no auto-pack/lifecycle flag.
  # 2. Run `pmctl dispatch run --lifecycle foreground --print-cmd` (no --auto-pack).
  # 3. Assert exit 0 and >=1 context.auto_packed event (built-in default is on).
  local name="dispatch/auto-pack default on emits event"
  should_run "$name" || return 0
  local work brief state_root count code
  work="$(mktemp -d)"; git init -q "$work"
  brief="$(_mk_guard_brief "$work")"
  state_root="$(mktemp -d)"
  set +e
  PM_DISPATCH_STATE_ROOT="$state_root" \
    "$PMCTL" dispatch run --lifecycle foreground --adapter codex --cd "$work" --brief-file "$brief" --print-cmd \
    >/dev/null 2>/dev/null; code=$?
  set -e
  count="$(PM_DISPATCH_STATE_ROOT="$state_root" "$PMCTL" trace tail --kind context.auto_packed --all --json 2>/dev/null | wc -l | tr -d ' ')"
  if [[ "$code" -eq 0 && "$count" -ge 1 ]]; then
    pass "$name"
  else
    fail "$name" "code=$code context.auto_packed_count=$count"
  fi
  rm -rf "$work" "$state_root"
}

case_no_auto_pack_overrides_default_on() {
  # --no-auto-pack disables the new built-in default-on (no config needed).
  # Steps:
  # 1. Create a git work dir + read-only guard brief; write no config.
  # 2. Run `pmctl dispatch run --no-auto-pack --print-cmd`.
  # 3. Assert exit 0 and zero context.auto_packed events.
  local name="dispatch/--no-auto-pack overrides built-in default on"
  should_run "$name" || return 0
  local work brief state_root count code
  work="$(mktemp -d)"; git init -q "$work"
  brief="$(_mk_guard_brief "$work")"
  state_root="$(mktemp -d)"
  set +e
  PM_DISPATCH_STATE_ROOT="$state_root" \
    "$PMCTL" dispatch run --lifecycle foreground --adapter codex --cd "$work" --brief-file "$brief" --no-auto-pack --print-cmd \
    >/dev/null 2>/dev/null; code=$?
  set -e
  count="$(PM_DISPATCH_STATE_ROOT="$state_root" "$PMCTL" trace tail --kind context.auto_packed --all --json 2>/dev/null | wc -l | tr -d ' ')"
  if [[ "$code" -eq 0 && "$count" -eq 0 ]]; then
    pass "$name"
  else
    fail "$name" "code=$code context.auto_packed_count=$count"
  fi
  rm -rf "$work" "$state_root"
}

case_auto_pack_zero_hits_event_original_brief() {
  # Auto-pack with zero reuse hits emits a hits=0 event and keeps the original brief.
  # Steps:
  # 1. Create a git work dir + read-only guard brief (no indexed content -> no hits).
  # 2. Run `pmctl dispatch run --auto-pack --print-cmd`.
  # 3. Assert exit 0, event hits=0 with empty pack, the original brief is forwarded,
  #    and no pack file was written under .pm-dispatch/ctx/packs/.
  local name="dispatch/--auto-pack zero hits emits event and keeps original brief"
  should_run "$name" || return 0
  local work brief state_root stderr evt code hits pack cmd_brief
  work="$(mktemp -d)"; git init -q "$work"
  brief="$(_mk_guard_brief "$work")"
  state_root="$(mktemp -d)"
  stderr="$(mktemp)"
  set +e
  PM_DISPATCH_CONTEXT_AUTOBUILD=0 PM_DISPATCH_STATE_ROOT="$state_root" \
    "$PMCTL" dispatch run --lifecycle foreground --adapter codex --cd "$work" --brief-file "$brief" --auto-pack --print-cmd \
    >/dev/null 2>"$stderr"; code=$?
  set -e
  evt="$(PM_DISPATCH_STATE_ROOT="$state_root" "$PMCTL" trace tail --kind context.auto_packed --all --json 2>/dev/null | tail -1)"
  hits="$(printf '%s\n' "$evt" | jq -r '.payload.hits // -1' 2>/dev/null || printf '-1')"
  pack="$(printf '%s\n' "$evt" | jq -r '.payload.pack // "missing"' 2>/dev/null || printf 'missing')"
  cmd_brief="$(awk '/brief:[[:space:]]/ { print $2; exit }' "$stderr")"
  if [[ "$code" -eq 0 && "$hits" -eq 0 && "$pack" == "" && "$cmd_brief" == "$brief" ]] \
     && [[ ! -d "$work/.pm-dispatch/ctx/packs" || -z "$(find "$work/.pm-dispatch/ctx/packs" -type f -name '*.md' -print -quit 2>/dev/null)" ]]; then
    pass "$name"
  else
    fail "$name" "code=$code hits=$hits pack=$pack cmd_brief=$cmd_brief brief=$brief"
  fi
  rm -rf "$work" "$state_root"; rm -f "$stderr"
}

case_auto_pack_hits_creates_pack_and_forwards_copy() {
  # Foreground auto-pack writes the augmented pack under .pm-dispatch/ctx/packs/ AND
  # snapshots it to the guardable /tmp/brief-<run_id>.md, forwarding the snapshot so a
  # single effective brief is guarded == executed == recorded (CC-402). Assert both
  # the work-repo pack content and that the forwarded brief is the equal /tmp snapshot.
  # Steps:
  # 1. Seed src/alpha.sh + `pmctl context index` so reuse-scan finds hits.
  # 2. Run `pmctl dispatch run --auto-pack --print-cmd` against a read-only guard brief.
  # 3. Assert the work-repo pack has auto_context + <=5 refs and its head equals the
  #    original brief, and the forwarded brief is the equal guardable /tmp snapshot.
  local name="dispatch/--auto-pack hits create pack and forward /tmp snapshot"
  should_run "$name" || return 0
  local work brief state_root stderr evt code hits pack cmd_brief refs original_part brief_lines
  work="$(mktemp -d)"; git init -q "$work"
  mkdir -p "$work/src"
  cat > "$work/src/alpha.sh" <<'EOF'
#!/usr/bin/env bash
alpha_beta_dispatch_helper() {
  printf 'alpha beta dispatch helper\n'
}
EOF
  "$PMCTL" context index "$work" >/dev/null 2>/dev/null
  brief="$(_mk_guard_brief "$work")"
  state_root="$(mktemp -d)"
  stderr="$(mktemp)"
  set +e
  PM_DISPATCH_STATE_ROOT="$state_root" \
    "$PMCTL" dispatch run --lifecycle foreground --adapter codex --cd "$work" --brief-file "$brief" --auto-pack --print-cmd \
    >/dev/null 2>"$stderr"; code=$?
  set -e
  evt="$(PM_DISPATCH_STATE_ROOT="$state_root" "$PMCTL" trace tail --kind context.auto_packed --all --json 2>/dev/null | tail -1)"
  hits="$(printf '%s\n' "$evt" | jq -r '.payload.hits // -1' 2>/dev/null || printf '-1')"
  pack="$(printf '%s\n' "$evt" | jq -r '.payload.pack // ""' 2>/dev/null || printf '')"
  cmd_brief="$(awk '/brief:[[:space:]]/ { print $2; exit }' "$stderr")"
  refs=0
  [[ -f "$pack" ]] && refs="$(grep -c '^  - ref:' "$pack" 2>/dev/null || true)"
  original_part="$(mktemp)"
  brief_lines="$(wc -l < "$brief" | tr -d ' ')"
  [[ -f "$pack" ]] && head -n "$brief_lines" "$pack" > "$original_part"
  if [[ "$code" -eq 0 && "$hits" -ge 1 && "$hits" -le 5 && "$pack" == "$work/.pm-dispatch/ctx/packs/"*.md ]] \
     && [[ -f "$pack" ]] \
     && grep -q '^auto_context:' "$pack" \
     && grep -q '^  # appended by pmctl dispatch run (auto-pack); pointers only - read on demand$' "$pack" \
     && grep -q '^  - ref: ' "$pack" \
     && grep -q '^    why_relevant: "' "$pack" \
     && grep -q '^    confidence: ' "$pack" \
     && [[ "$refs" -le 5 ]] \
     && cmp -s "$brief" "$original_part" \
     && [[ "$cmd_brief" == /tmp/brief-run-*.md ]] \
     && [[ -f "$cmd_brief" ]] \
     && cmp -s "$cmd_brief" "$pack"; then
    pass "$name"
  else
    fail "$name" "code=$code hits=$hits pack=$pack cmd_brief=$cmd_brief refs=$refs"
  fi
  rm -rf "$work" "$state_root"; rm -f "$stderr" "$original_part" "$cmd_brief" 2>/dev/null || true
}

case_auto_pack_foreground_records_executed_snapshot() {
  # CC-402 / QA: a NON-dry-run foreground auto-pack run. The brief recorded in
  # runs.jsonl must be the SAME augmented effective brief the adapter executed —
  # the guardable /tmp/brief-<run_id>.md snapshot carrying auto_context, NOT the
  # original brief. Fails under the mutation where execute_tail/records receive the
  # original brief while the adapter argv receives the pack (guarded/executed/recorded
  # divergence). Exercises execute_tail + post-verify + durable record, not --print-cmd.
  # Steps:
  # 1. Seed src/alpha.sh + `pmctl context index`; install a fake codex (exit 0).
  # 2. Run a non-dry-run foreground `pmctl dispatch run --auto-pack`.
  # 3. Assert exit 0/OK, runs.jsonl brief_file == the forwarded /tmp snapshot, and the
  #    snapshot carries auto_context (executed == recorded augmented brief).
  local name="dispatch/foreground auto-pack records the executed augmented snapshot"
  should_run "$name" || return 0
  local work brief bindir state_root out code runs_file rec_brief fwd_brief
  work="$(mktemp -d)"; git init -q "$work"
  mkdir -p "$work/src"
  cat > "$work/src/alpha.sh" <<'EOF'
#!/usr/bin/env bash
alpha_beta_dispatch_helper() {
  printf 'alpha beta dispatch helper\n'
}
EOF
  "$PMCTL" context index "$work" >/dev/null 2>/dev/null
  brief="$(_mk_guard_brief "$work")"
  bindir="$(mktemp -d)"; _install_fake_codex "$bindir" 0
  state_root="$(mktemp -d)"
  set +e
  out="$(PM_DISPATCH_STATE_ROOT="$state_root" PATH="$bindir:$PATH" \
    "$PMCTL" dispatch run --lifecycle foreground --adapter codex --cd "$work" --brief-file "$brief" --auto-pack 2>&1)"; code=$?
  set -e
  # runs.jsonl lives only in the work-dir partition (context telemetry writes only
  # events.jsonl), so head -1 deterministically finds the dispatch run rows.
  runs_file="$(find "$state_root" -name runs.jsonl -type f 2>/dev/null | head -1)"
  rec_brief=""
  [[ -n "$runs_file" ]] && rec_brief="$(jq -r 'select(.brief_file)|.brief_file' "$runs_file" 2>/dev/null | tail -1)"
  fwd_brief="$(awk '/brief:[[:space:]]/ { print $2; exit }' <<<"$out")"
  if [[ "$code" -eq 0 ]] \
     && grep -q '^OK' <<<"$out" \
     && [[ "$rec_brief" == /tmp/brief-run-*.md ]] \
     && [[ "$rec_brief" == "$fwd_brief" ]] \
     && [[ -f "$rec_brief" ]] \
     && grep -q '^auto_context:' "$rec_brief"; then
    pass "$name"
  else
    fail "$name" "code=$code rec_brief=$rec_brief fwd_brief=$fwd_brief tail=$(tail -3 <<<"$out" | tr '\n' '|')"
  fi
  rm -rf "$work" "$bindir" "$state_root"; rm -f "$rec_brief" 2>/dev/null || true
}

case_dispatch_cd_canonicalized_for_pack_path() {
  # Auto-pack canonicalizes the --cd value for the internal pack path while still
  # forwarding the original --cd spelling to the adapter.
  # Steps:
  # 1. Seed indexed content; pass a non-canonical --cd ("$work/.").
  # 2. Run `pmctl dispatch run --auto-pack --print-cmd`.
  # 3. Assert the event pack path is canonical (no "/./") and the adapter cwd keeps "/.".
  local name="dispatch/--cd canonicalized for pack path; original spelling forwarded to adapter"
  should_run "$name" || return 0
  local work brief state_root stderr evt code pack cwd
  work="$(mktemp -d)"; git init -q "$work"
  mkdir -p "$work/src"
  cat > "$work/src/alpha.sh" <<'EOF'
#!/usr/bin/env bash
alpha_beta_dispatch_helper() {
  printf 'alpha beta dispatch helper\n'
}
EOF
  "$PMCTL" context index "$work" >/dev/null 2>/dev/null
  brief="$(_mk_guard_brief "$work")"
  state_root="$(mktemp -d)"
  stderr="$(mktemp)"
  set +e
  # A non-canonical --cd spelling (trailing /.): canonicalization must clean the
  # internal pack path while the adapter still receives the original spelling.
  PM_DISPATCH_STATE_ROOT="$state_root" \
    "$PMCTL" dispatch run --lifecycle foreground --adapter codex --cd "$work/." --brief-file "$brief" --auto-pack --print-cmd \
    >/dev/null 2>"$stderr"; code=$?
  set -e
  evt="$(PM_DISPATCH_STATE_ROOT="$state_root" "$PMCTL" trace tail --kind context.auto_packed --all --json 2>/dev/null | tail -1)"
  pack="$(printf '%s\n' "$evt" | jq -r '.payload.pack // ""' 2>/dev/null || printf '')"
  cwd="$(awk '/^  cwd:[[:space:]]/ { print $2; exit }' "$stderr")"
  # pack path is canonical (no /./, rooted at the cleaned work dir); cwd forwarded
  # to the adapter keeps the original /. spelling.
  if [[ "$code" -eq 0 \
        && "$pack" == "$work/.pm-dispatch/ctx/packs/"*.md \
        && "$pack" != *"/./"* \
        && "$cwd" == "$work/." ]]; then
    pass "$name"
  else
    fail "$name" "code=$code pack=$pack cwd=$cwd"
  fi
  rm -rf "$work" "$state_root"; rm -f "$stderr"
}

case_auto_pack_pack_failure_degrades_to_original_brief() {
  local name="dispatch/--auto-pack pack write failure keeps original brief"
  should_run "$name" || return 0
  local work brief state_root stderr evt code hits pack cmd_brief warn
  work="$(mktemp -d)"; git init -q "$work"
  mkdir -p "$work/src"
  cat > "$work/src/alpha.sh" <<'EOF'
#!/usr/bin/env bash
alpha_beta_dispatch_helper() {
  printf 'alpha beta dispatch helper\n'
}
EOF
  "$PMCTL" context index "$work" >/dev/null 2>/dev/null
  printf 'not a directory\n' > "$work/.pm-dispatch/ctx/packs"
  brief="$(_mk_guard_brief "$work")"
  state_root="$(mktemp -d)"
  stderr="$(mktemp)"
  set +e
  PM_DISPATCH_STATE_ROOT="$state_root" \
    "$PMCTL" dispatch run --lifecycle foreground --adapter codex --cd "$work" --brief-file "$brief" --auto-pack --print-cmd \
    >/dev/null 2>"$stderr"; code=$?
  set -e
  evt="$(PM_DISPATCH_STATE_ROOT="$state_root" "$PMCTL" trace tail --kind context.auto_packed --all --json 2>/dev/null | tail -1)"
  hits="$(printf '%s\n' "$evt" | jq -r '.payload.hits // -1' 2>/dev/null || printf '-1')"
  pack="$(printf '%s\n' "$evt" | jq -r '.payload.pack // "missing"' 2>/dev/null || printf 'missing')"
  cmd_brief="$(awk '/brief:[[:space:]]/ { print $2; exit }' "$stderr")"
  warn="$(grep -c 'auto-pack skipped' "$stderr" 2>/dev/null || true)"
  if [[ "$code" -eq 0 && "$hits" -eq 0 && "$pack" == "" && "$cmd_brief" == "$brief" && "$warn" -ge 1 ]] \
     && [[ -f "$work/.pm-dispatch/ctx/packs" ]]; then
    pass "$name"
  else
    fail "$name" "code=$code hits=$hits pack=$pack cmd_brief=$cmd_brief brief=$brief warnings=$warn"
  fi
  rm -rf "$work" "$state_root"; rm -f "$stderr"
}

case_config_auto_pack_on_activates_without_flag() {
  local name="config/dispatch.auto_pack on activates auto-pack"
  should_run "$name" || return 0
  local home work brief state_root evt code hits
  home="$(mktemp -d)"; mkdir -p "$home/.pm-dispatch"
  printf 'dispatch.auto_pack = on\n' > "$home/.pm-dispatch/config"
  work="$(mktemp -d)"; git init -q "$work"
  brief="$(_mk_guard_brief "$work")"
  state_root="$(mktemp -d)"
  set +e
  HOME="$home" PM_DISPATCH_CONTEXT_AUTOBUILD=0 PM_DISPATCH_STATE_ROOT="$state_root" \
    "$PMCTL" dispatch run --lifecycle foreground --adapter codex --cd "$work" --brief-file "$brief" --print-cmd \
    >/dev/null 2>/dev/null; code=$?
  set -e
  evt="$(PM_DISPATCH_STATE_ROOT="$state_root" "$PMCTL" trace tail --kind context.auto_packed --all --json 2>/dev/null | tail -1)"
  hits="$(printf '%s\n' "$evt" | jq -r '.payload.hits // -1' 2>/dev/null || printf '-1')"
  if [[ "$code" -eq 0 && "$hits" -eq 0 ]]; then
    pass "$name"
  else
    fail "$name" "code=$code hits=$hits"
  fi
  rm -rf "$home" "$work" "$state_root"
}

case_no_auto_pack_overrides_config_on() {
  local name="config/--no-auto-pack overrides dispatch.auto_pack on"
  should_run "$name" || return 0
  local home work brief state_root count code
  home="$(mktemp -d)"; mkdir -p "$home/.pm-dispatch"
  printf 'dispatch.auto_pack = on\n' > "$home/.pm-dispatch/config"
  work="$(mktemp -d)"; git init -q "$work"
  brief="$(_mk_guard_brief "$work")"
  state_root="$(mktemp -d)"
  set +e
  HOME="$home" PM_DISPATCH_STATE_ROOT="$state_root" \
    "$PMCTL" dispatch run --lifecycle foreground --adapter codex --cd "$work" --brief-file "$brief" --no-auto-pack --print-cmd \
    >/dev/null 2>/dev/null; code=$?
  set -e
  count="$(PM_DISPATCH_STATE_ROOT="$state_root" "$PMCTL" trace tail --kind context.auto_packed --all --json 2>/dev/null | wc -l | tr -d ' ')"
  if [[ "$code" -eq 0 && "$count" -eq 0 ]]; then
    pass "$name"
  else
    fail "$name" "code=$code context.auto_packed_count=$count"
  fi
  rm -rf "$home" "$work" "$state_root"
}

case_missing_adapter
case_unknown_adapter
case_arg_passthrough
case_sandbox_danger_full_access_denied
case_adapter_resolution_and_route
case_brief_validation_blocks
case_guard_denies_dispatch
case_guard_denied_brief_creates_no_pack_artifact
case_happy_path_post_verify_ok
case_adapter_exit_propagated
case_post_verify_failure
case_invalid_adapter_name
case_inline_brief_rejected
case_route_failure_branch
case_routing_unavailable_fails_closed
case_guard_unavailable_fails_closed
case_missing_cd
case_missing_brief_file
case_symlinked_adapter_rejected
case_stale_latest_symlink_avoidance
case_footer_trace_threaded_to_post_verify
case_footer_persisted_and_paths_parse
case_execute_tail_direct_lifecycle_identity
case_manifest_terminal_event_threaded
case_footer_exit_propagated_through_tee
case_config_timeout_exported_to_adapter
case_config_model_exported_to_adapter
case_caller_model_beats_config
case_config_malformed_model_warns_and_fallback
case_config_timeout_exported_to_claude_adapter
case_timeout_flag_beats_config_via_pmctl
case_auto_pack_default_on_emits_event
case_no_auto_pack_overrides_default_on
case_auto_pack_zero_hits_event_original_brief
case_auto_pack_hits_creates_pack_and_forwards_copy
case_auto_pack_foreground_records_executed_snapshot
case_dispatch_cd_canonicalized_for_pack_path
case_auto_pack_pack_failure_degrades_to_original_brief
case_config_auto_pack_on_activates_without_flag
case_no_auto_pack_overrides_config_on

th_summary
