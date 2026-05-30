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
  err="$("$PMCTL" dispatch run --cd /tmp 2>&1)"; code=$?
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
  err="$("$PMCTL" dispatch run --adapter nope --cd /tmp --brief-file /tmp/x.md 2>&1)"; code=$?
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
  out="$("$PMCTL" dispatch run --adapter codex --cd "$work" --brief-file "$brief" --print-cmd 2>/tmp/_t3.$$)"; code=$?
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
  err="$("$PMCTL" dispatch run --adapter codex --cd "$work" --brief-file "$brief" --print-cmd 2>&1)"; code=$?
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
  err="$("$PMCTL" dispatch run --adapter codex --cd "$work" --brief-file "$brief" --print-cmd 2>&1)"; code=$?
  set -e
  if [[ "$code" -eq 2 ]] && grep -qi 'guard denied' <<<"$err"; then
    pass "$name"
  else
    fail "$name" "code=$code err=$(head -1 <<<"$err")"
  fi
  rm -rf "$work"
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
  out="$(PATH="$bindir:$PATH" "$PMCTL" dispatch run --adapter codex --cd "$work" --brief-file "$brief" 2>&1)"; code=$?
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
  PATH="$bindir:$PATH" "$PMCTL" dispatch run --adapter codex --cd "$work" --brief-file "$brief" >/dev/null 2>&1; code=$?
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
  PATH="$bindir:$PATH" "$PMCTL" dispatch run --adapter codex --cd "$work" --brief-file "$brief" >/dev/null 2>&1; code=$?
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
  err="$("$PMCTL" dispatch run --adapter ../codex --cd /tmp --brief-file /tmp/x.md 2>&1)"; code=$?
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
  err="$("$PMCTL" dispatch run --adapter codex --cd "$work" -- do a thing 2>&1)"; code=$?
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
  err="$("$PMCTL" dispatch run --adapter codex --brief-file /tmp/x.md 2>&1)"; code=$?
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
  err="$("$PMCTL" dispatch run --adapter codex --cd "$work" 2>&1)"; code=$?
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

case_missing_adapter
case_unknown_adapter
case_adapter_resolution_and_route
case_brief_validation_blocks
case_guard_denies_dispatch
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

th_summary
