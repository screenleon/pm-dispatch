#!/usr/bin/env bash
# Regression tests for the dispatch lifecycle axis (CC-391 Phase 7c-2a):
# --lifecycle foreground|detached, detach-eligibility gating, the run-spec, and
# the supervisor's re-run security preflight. In 7c-2a the supervisor runs
# synchronously, so detached must be behavior-equivalent to foreground.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PMCTL="$REPO_ROOT/cli/pmctl"
SUPERVISOR="$REPO_ROOT/scripts/dispatch-supervisor.sh"

# shellcheck source=scripts/lib/test-harness.sh
. "$SCRIPT_DIR/lib/test-harness.sh"
# shellcheck source=scripts/lib/runner-kind.sh
. "$SCRIPT_DIR/lib/runner-kind.sh"
# shellcheck source=scripts/lib/executor-router.sh
. "$SCRIPT_DIR/lib/executor-router.sh"
# shellcheck source=scripts/lib/pmctl-guard.sh
. "$SCRIPT_DIR/lib/pmctl-guard.sh"
# shellcheck source=scripts/lib/pmctl-dispatch.sh
. "$SCRIPT_DIR/lib/pmctl-dispatch.sh"
th_init "$@"
export PM_DISPATCH_STATE_ROOT="$tmp_root/lifecycle-state"

_BRIEFS=()
_mk_brief() {
  local work="$1" bf
  bf="/tmp/brief-lifecycle-$$-${#_BRIEFS[@]}.md"
  cat > "$bf" <<EOF
schema_version: 1
working_dir: $work
goal: exercise dispatch lifecycle
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

_cleanup() { rm -f "${_BRIEFS[@]}" 2>/dev/null || true; }
trap _cleanup EXIT

_install_fake_codex() {
  local bindir="$1" code="${2:-0}"
  cat > "$bindir/codex" <<FAKEOF
#!/usr/bin/env bash
_last=""
while [[ \$# -gt 0 ]]; do
  case "\$1" in
    --output-last-message) _last="\$2"; shift 2 ;;
    *) shift ;;
  esac
done
[[ -n "\$_last" ]] && printf 'dispatch complete (fake codex)\n' > "\$_last"
printf '%s\n' '{"type":"turn.completed","usage":{"input_tokens":1,"output_tokens":1}}'
exit $code
FAKEOF
  chmod +x "$bindir/codex"
}

_first_record() { find "$1/.dispatch-results" -type f -name 'run-*.md' 2>/dev/null | sort | head -1; }
_first_runspec() { find "$1/.agent-trace" -type f -name 'run-*.runspec' 2>/dev/null | sort | head -1; }

# ── foreground default writes no run-spec (supervisor not involved) ──────────
case_foreground_default_no_runspec() {
  local name="lifecycle/foreground default writes no run-spec"
  should_run "$name" || return 0
  local work brief bindir out code
  work="$(mktemp -d)"; git init -q "$work"
  brief="$(_mk_brief "$work")"
  bindir="$(mktemp -d)"; _install_fake_codex "$bindir" 0
  set +e
  out="$(PATH="$bindir:$PATH" "$PMCTL" dispatch run --adapter codex --cd "$work" --brief-file "$brief" 2>&1)"; code=$?
  set -e
  if [[ "$code" -eq 0 ]] \
    && grep -q '^OK$' <<<"$out" \
    && [[ -n "$(_first_record "$work")" ]] \
    && [[ -z "$(_first_runspec "$work")" ]]; then
    pass "$name"
  else
    fail "$name" "code=$code runspec=$(_first_runspec "$work") tail=$(tail -3 <<<"$out" | tr '\n' '|')"
  fi
  rm -rf "$work" "$bindir"
}

# ── detached is behavior-equivalent and persists a run-spec ──────────────────
case_detached_equivalent() {
  local name="lifecycle/detached behaves like foreground + writes run-spec"
  should_run "$name" || return 0
  local work brief bindir out code record runspec
  work="$(mktemp -d)"; git init -q "$work"
  brief="$(_mk_brief "$work")"
  bindir="$(mktemp -d)"; _install_fake_codex "$bindir" 0
  set +e
  out="$(PATH="$bindir:$PATH" "$PMCTL" dispatch run --adapter codex --cd "$work" --brief-file "$brief" --lifecycle detached 2>&1)"; code=$?
  set -e
  record="$(_first_record "$work")"; runspec="$(_first_runspec "$work")"
  if [[ "$code" -eq 0 ]] \
    && grep -q '^OK$' <<<"$out" \
    && grep -q 'PASS: trace structurally complete' <<<"$out" \
    && [[ -n "$record" ]] && grep -q '^final_state: "ok"$' "$record" \
    && [[ -n "$runspec" ]] && grep -q '^schema_version=2$' "$runspec" \
    && grep -q '^adapter=codex$' "$runspec" \
    && grep -q '^cd_arg=' "$runspec" \
    && grep -q "^brief_file=$brief\$" "$runspec" \
    && grep -q '^native_b64:$' "$runspec"; then
    pass "$name"
  else
    fail "$name" "code=$code record=${record:-missing} runspec=${runspec:-missing} tail=$(tail -3 <<<"$out" | tr '\n' '|')"
  fi
  rm -rf "$work" "$bindir"
}

# ── adapter failure under detached propagates verbatim ───────────────────────
case_detached_failure_propagates() {
  local name="lifecycle/detached adapter failure propagates exit"
  should_run "$name" || return 0
  local work brief bindir code record
  work="$(mktemp -d)"; git init -q "$work"
  brief="$(_mk_brief "$work")"
  bindir="$(mktemp -d)"; _install_fake_codex "$bindir" 7
  set +e
  PATH="$bindir:$PATH" "$PMCTL" dispatch run --adapter codex --cd "$work" --brief-file "$brief" --lifecycle detached >/dev/null 2>&1; code=$?
  set -e
  record="$(_first_record "$work")"
  if [[ "$code" -eq 7 ]] \
    && [[ -n "$record" ]] && grep -q '^final_state: "failed"$' "$record"; then
    pass "$name"
  else
    fail "$name" "code=$code record=${record:-missing}"
  fi
  rm -rf "$work" "$bindir"
}

# ── invalid --lifecycle value is rejected ────────────────────────────────────
case_invalid_lifecycle_value() {
  local name="lifecycle/invalid --lifecycle value rejected"
  should_run "$name" || return 0
  local work brief code err
  work="$(mktemp -d)"; git init -q "$work"
  brief="$(_mk_brief "$work")"
  set +e
  err="$("$PMCTL" dispatch run --adapter codex --cd "$work" --brief-file "$brief" --lifecycle bogus 2>&1 >/dev/null)"; code=$?
  set -e
  if [[ "$code" -eq 2 ]] && grep -qi 'invalid --lifecycle' <<<"$err"; then
    pass "$name"
  else
    fail "$name" "code=$code err=$(tail -2 <<<"$err" | tr '\n' '|')"
  fi
  rm -rf "$work"
}

# ── detached + --print-cmd is incompatible ───────────────────────────────────
case_detached_print_cmd_incompatible() {
  local name="lifecycle/detached + --print-cmd rejected"
  should_run "$name" || return 0
  local work brief code err
  work="$(mktemp -d)"; git init -q "$work"
  brief="$(_mk_brief "$work")"
  set +e
  err="$("$PMCTL" dispatch run --adapter codex --cd "$work" --brief-file "$brief" --lifecycle detached --print-cmd 2>&1 >/dev/null)"; code=$?
  set -e
  if [[ "$code" -eq 2 ]] && grep -qi 'incompatible with --print-cmd' <<<"$err"; then
    pass "$name"
  else
    fail "$name" "code=$code err=$(tail -2 <<<"$err" | tr '\n' '|')"
  fi
  rm -rf "$work"
}

# ── detached rejects an ineligible adapter BEFORE launching the executor ──────
case_detached_ineligible_rejected() {
  local name="lifecycle/detached ineligible adapter rejected pre-launch"
  should_run "$name" || return 0
  local work brief bindir code out
  work="$(mktemp -d)"; git init -q "$work"
  brief="$(_mk_brief "$work")"
  bindir="$(mktemp -d)"; _install_fake_codex "$bindir" 0
  # Simulate a host-native (non-detachable) adapter via override; codex is a real
  # cli-subprocess adapter, so the override is the only way to exercise the gate.
  pmctl_dispatch_detach_eligible() { printf 'fake: not detach-eligible\n' >&2; return 1; }
  set +e
  out="$(PATH="$bindir:$PATH" pmctl_dispatch_run "$REPO_ROOT" --adapter codex --cd "$work" --brief-file "$brief" --lifecycle detached 2>&1)"; code=$?
  set -e
  unset -f pmctl_dispatch_detach_eligible
  # shellcheck source=scripts/lib/pmctl-dispatch.sh
  . "$SCRIPT_DIR/lib/pmctl-dispatch.sh"
  if [[ "$code" -eq 2 ]] \
    && [[ -z "$(_first_record "$work")" ]] \
    && [[ -z "$(_first_runspec "$work")" ]]; then
    pass "$name"
  else
    fail "$name" "code=$code record=$(_first_record "$work") runspec=$(_first_runspec "$work")"
  fi
  rm -rf "$work" "$bindir"
}

# ── detach-eligibility gate derives from runner_kind (unit) ──────────────────
case_detach_eligible_unit() {
  local name="lifecycle/detach-eligibility derives from runner_kind"
  should_run "$name" || return 0
  local root code_cli code_host code_missing code_unknown
  root="$(mktemp -d)"
  mkdir -p "$root/adapters/acli" "$root/adapters/ahost" "$root/adapters/anone" "$root/adapters/abad"
  printf 'runner_kind: cli-subprocess\n' > "$root/adapters/acli/adapter.yaml"
  printf 'runner_kind: host-native\n'    > "$root/adapters/ahost/adapter.yaml"
  printf 'name: anone\n'                 > "$root/adapters/anone/adapter.yaml"
  printf 'runner_kind: nonsense\n'       > "$root/adapters/abad/adapter.yaml"
  set +e
  pmctl_dispatch_detach_eligible "$root" acli  >/dev/null 2>&1; code_cli=$?
  pmctl_dispatch_detach_eligible "$root" ahost >/dev/null 2>&1; code_host=$?
  pmctl_dispatch_detach_eligible "$root" anone >/dev/null 2>&1; code_missing=$?
  pmctl_dispatch_detach_eligible "$root" abad  >/dev/null 2>&1; code_unknown=$?
  set -e
  if [[ "$code_cli" -eq 0 && "$code_host" -eq 1 && "$code_missing" -eq 2 && "$code_unknown" -eq 2 ]]; then
    pass "$name"
  else
    fail "$name" "cli=$code_cli host=$code_host missing=$code_missing unknown=$code_unknown"
  fi
  rm -rf "$root"
}

# ── config dispatch.lifecycle = detached activates detached ──────────────────
case_config_lifecycle_detached() {
  local name="lifecycle/config dispatch.lifecycle=detached activates detached"
  should_run "$name" || return 0
  local work brief bindir cfg code
  work="$(mktemp -d)"; git init -q "$work"
  brief="$(_mk_brief "$work")"
  bindir="$(mktemp -d)"; _install_fake_codex "$bindir" 0
  cfg="$(mktemp)"; printf 'dispatch.lifecycle = detached\n' > "$cfg"
  set +e
  PM_DISPATCH_CONFIG_FILE="$cfg" PATH="$bindir:$PATH" "$PMCTL" dispatch run --adapter codex --cd "$work" --brief-file "$brief" >/dev/null 2>&1; code=$?
  set -e
  if [[ "$code" -eq 0 ]] && [[ -n "$(_first_runspec "$work")" ]]; then
    pass "$name"
  else
    fail "$name" "code=$code runspec=$(_first_runspec "$work")"
  fi
  rm -rf "$work" "$bindir"; rm -f "$cfg"
}

# ── config --lifecycle flag beats config default ─────────────────────────────
case_flag_beats_config() {
  local name="lifecycle/--lifecycle foreground overrides config detached"
  should_run "$name" || return 0
  local work brief bindir cfg code
  work="$(mktemp -d)"; git init -q "$work"
  brief="$(_mk_brief "$work")"
  bindir="$(mktemp -d)"; _install_fake_codex "$bindir" 0
  cfg="$(mktemp)"; printf 'dispatch.lifecycle = detached\n' > "$cfg"
  set +e
  PM_DISPATCH_CONFIG_FILE="$cfg" PATH="$bindir:$PATH" "$PMCTL" dispatch run --adapter codex --cd "$work" --brief-file "$brief" --lifecycle foreground >/dev/null 2>&1; code=$?
  set -e
  if [[ "$code" -eq 0 ]] && [[ -z "$(_first_runspec "$work")" ]]; then
    pass "$name"
  else
    fail "$name" "code=$code runspec=$(_first_runspec "$work")"
  fi
  rm -rf "$work" "$bindir"; rm -f "$cfg"
}

# ── supervisor is not a bypass: a tampered run-spec is re-validated ───────────
# Writes a schema-v2 run-spec. Extra base64-encoded native args may be appended.
_write_runspec() {
  local path="$1" adapter="$2" work="$3" brief="$4"; shift 4
  {
    printf 'schema_version=2\n'
    printf 'run_id=run-20260617T000000Z-aaaaaa\n'
    printf 'adapter=%s\n' "$adapter"
    printf 'work_dir=%s\n' "$work"
    printf 'cd_arg=%s\n' "$work"
    printf 'brief_file=%s\n' "$brief"
    printf 'model=\n'
    printf 'created_ts=2026-06-17T00:00:00Z\n'
    printf 'print_cmd=0\n'
    printf 'native_b64:\n'
    local a
    for a in "$@"; do
      printf '%s\n' "$(printf '%s' "$a" | base64 | tr -d '\n')"
    done
  } > "$path"
}

case_supervisor_rejects_unroutable() {
  local name="supervisor/run-spec with non-routable adapter rejected"
  should_run "$name" || return 0
  local work brief spec code err
  work="$(mktemp -d)"; git init -q "$work"
  brief="$(_mk_brief "$work")"
  spec="$work/.agent-trace/tamper.runspec"; mkdir -p "$work/.agent-trace"
  _write_runspec "$spec" "definitelynotanadapter" "$work" "$brief"
  set +e
  err="$(bash "$SUPERVISOR" --run-spec "$spec" 2>&1 >/dev/null)"; code=$?
  set -e
  # The adapter is refused by the shared security preflight (file-existence check
  # fires before the route check; either refusal is correct) and no executor runs.
  if [[ "$code" -eq 2 ]] \
    && grep -qiE 'unknown adapter|not a routable executor' <<<"$err" \
    && [[ -z "$(_first_record "$work")" ]]; then
    pass "$name"
  else
    fail "$name" "code=$code record=$(_first_record "$work") err=$(tail -2 <<<"$err" | tr '\n' '|')"
  fi
  rm -rf "$work"
}

case_supervisor_rejects_traversal_name() {
  local name="supervisor/run-spec with path-traversal adapter name rejected"
  should_run "$name" || return 0
  local work brief spec code err
  work="$(mktemp -d)"; git init -q "$work"
  brief="$(_mk_brief "$work")"
  spec="$work/.agent-trace/tamper.runspec"; mkdir -p "$work/.agent-trace"
  _write_runspec "$spec" "../../etc" "$work" "$brief"
  set +e
  err="$(bash "$SUPERVISOR" --run-spec "$spec" 2>&1 >/dev/null)"; code=$?
  set -e
  if [[ "$code" -eq 2 ]] && grep -qi 'invalid adapter name' <<<"$err"; then
    pass "$name"
  else
    fail "$name" "code=$code err=$(tail -2 <<<"$err" | tr '\n' '|')"
  fi
  rm -rf "$work"
}

case_supervisor_missing_spec() {
  local name="supervisor/missing run-spec rejected"
  should_run "$name" || return 0
  local code err
  set +e
  err="$(bash "$SUPERVISOR" --run-spec /no/such/runspec 2>&1 >/dev/null)"; code=$?
  set -e
  if [[ "$code" -eq 2 ]] && grep -qi 'run-spec not found' <<<"$err"; then
    pass "$name"
  else
    fail "$name" "code=$code err=$(tail -2 <<<"$err" | tr '\n' '|')"
  fi
}

# ── supervisor rejects a malformed brief BEFORE launching the executor ────────
case_supervisor_rejects_malformed_brief() {
  local name="supervisor/run-spec with malformed brief rejected before launch"
  should_run "$name" || return 0
  local work bad bindir spec code err
  work="$(mktemp -d)"; git init -q "$work"
  bindir="$(mktemp -d)"; _install_fake_codex "$bindir" 0
  # A guard-allowed /tmp/brief-*.md path that fails brief-validate (missing
  # required schema fields). pmctl dispatch run would reject it; so must the
  # supervisor, before any executor runs.
  bad="/tmp/brief-lifecycle-malformed-$$.md"; printf 'not: a valid brief\n' > "$bad"
  spec="$work/.agent-trace/t.runspec"; mkdir -p "$work/.agent-trace"
  _write_runspec "$spec" "codex" "$work" "$bad"
  set +e
  err="$(PATH="$bindir:$PATH" bash "$SUPERVISOR" --run-spec "$spec" 2>&1 >/dev/null)"; code=$?
  set -e
  if [[ "$code" -eq 2 ]] \
    && grep -qi 'brief failed validation' <<<"$err" \
    && [[ -z "$(_first_record "$work")" ]]; then
    pass "$name"
  else
    fail "$name" "code=$code record=$(_first_record "$work") err=$(tail -2 <<<"$err" | tr '\n' '|')"
  fi
  rm -rf "$work" "$bindir"; rm -f "$bad"
}

# ── supervisor rejects native args that smuggle in --brief-file ──────────────
case_supervisor_rejects_native_brief_smuggle() {
  local name="supervisor/run-spec native args carrying --brief-file rejected"
  should_run "$name" || return 0
  local work brief evil bindir spec code err
  work="$(mktemp -d)"; git init -q "$work"
  brief="$(_mk_brief "$work")"
  evil="/tmp/brief-lifecycle-evil-$$.md"; cp "$brief" "$evil"
  bindir="$(mktemp -d)"; _install_fake_codex "$bindir" 0
  spec="$work/.agent-trace/t.runspec"; mkdir -p "$work/.agent-trace"
  # The trusted scalars name $brief, but native args try to override the brief the
  # adapter receives with $evil — the supervisor must refuse the split.
  _write_runspec "$spec" "codex" "$work" "$brief" "--brief-file" "$evil"
  set +e
  err="$(PATH="$bindir:$PATH" bash "$SUPERVISOR" --run-spec "$spec" 2>&1 >/dev/null)"; code=$?
  set -e
  if [[ "$code" -eq 2 ]] \
    && grep -qi 'native args must not contain --brief-file' <<<"$err" \
    && [[ -z "$(_first_record "$work")" ]]; then
    pass "$name"
  else
    fail "$name" "code=$code record=$(_first_record "$work") err=$(tail -2 <<<"$err" | tr '\n' '|')"
  fi
  rm -rf "$work" "$bindir"; rm -f "$evil"
}

# ── detached + auto-pack is rejected (deferred combination) ───────────────────
case_detached_autopack_rejected() {
  local name="lifecycle/detached + auto-pack rejected"
  should_run "$name" || return 0
  local work brief code err
  work="$(mktemp -d)"; git init -q "$work"
  brief="$(_mk_brief "$work")"
  set +e
  err="$("$PMCTL" dispatch run --adapter codex --cd "$work" --brief-file "$brief" --lifecycle detached --auto-pack 2>&1 >/dev/null)"; code=$?
  set -e
  if [[ "$code" -eq 2 ]] \
    && grep -qi 'does not yet support auto-pack' <<<"$err" \
    && [[ -z "$(_first_runspec "$work")" ]]; then
    pass "$name"
  else
    fail "$name" "code=$code runspec=$(_first_runspec "$work") err=$(tail -2 <<<"$err" | tr '\n' '|')"
  fi
  rm -rf "$work"
}

case_foreground_default_no_runspec
case_detached_equivalent
case_detached_failure_propagates
case_invalid_lifecycle_value
case_detached_print_cmd_incompatible
case_detached_ineligible_rejected
case_detach_eligible_unit
case_config_lifecycle_detached
case_flag_beats_config
case_supervisor_rejects_unroutable
case_supervisor_rejects_traversal_name
case_supervisor_missing_spec
case_supervisor_rejects_malformed_brief
case_supervisor_rejects_native_brief_smuggle
case_detached_autopack_rejected
th_summary
