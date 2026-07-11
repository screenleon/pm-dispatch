#!/usr/bin/env bash
# Regression tests for the batch-only pmctl pm coordinator.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PMCTL="$REPO_ROOT/cli/pmctl"

# shellcheck source=scripts/lib/test-harness.sh
. "$SCRIPT_DIR/lib/test-harness.sh"
th_init "$@"

# Behavior: prepare creates a snapshot and reports the non-interactive contract as JSON.
# Steps: run prepare against this checkout with a ticket in the request; assert its snapshot and policy fields.
case_prepare_emits_batch_contract() {
  local name="pmctl pm prepare: emits batch-only contract with snapshot"
  should_run "$name" || return 0
  local out code=0 snapshot
  out="$("$PMCTL" pm prepare --cd "$REPO_ROOT" --request 'implement CC-473' --json 2>/dev/null)" || code=$?
  if [[ "$code" -eq 0 ]] \
    && jq -e --arg wd "$REPO_ROOT" '.mode == "batch-only" and .working_dir == $wd and .focus_tickets == ["CC-473"] and .snapshot_status == "created" and .handover_required == true' <<<"$out" >/dev/null; then
    snapshot="$(jq -r '.snapshot_file' <<<"$out")"
    [[ -f "$snapshot" ]] && rm -f "$snapshot" && pass "$name" || fail "$name" "snapshot_file was not created"
  else
    fail "$name" "code=$code out=$out"
  fi
}

# Behavior: prepare's human mode exposes the batch contract and snapshot handoff.
# Steps: invoke prepare without --json; assert its required lines and remove the created snapshot.
case_prepare_emits_human_contract() {
  local name="pmctl pm prepare: emits human batch contract"
  should_run "$name" || return 0
  local out code=0 snapshot
  out="$("$PMCTL" pm prepare --cd "$REPO_ROOT" --request 'human contract CC-473' 2>/dev/null)" || code=$?
  snapshot="$(printf '%s\n' "$out" | sed -n 's/^snapshot_file: //p')"
  if [[ "$code" -eq 0 ]] \
    && [[ "$out" == *$'mode: batch-only\n'* ]] \
    && [[ "$out" == *"working_dir: $REPO_ROOT"* ]] \
    && [[ "$out" == *"focus_tickets: CC-473"* ]] \
    && [[ "$out" == *"snapshot_status: created"* ]] \
    && [[ "$out" == *"next: author a complete dispatch_handover_v1 brief, then run pmctl pm run"* ]] \
    && [[ -f "$snapshot" ]]; then
    rm -f "$snapshot"
    pass "$name"
  else
    fail "$name" "code=$code snapshot=$snapshot out=$out"
  fi
}

# Behavior: prepare defaults its work directory to the caller's git toplevel.
# Steps: invoke prepare from this checkout without --cd; assert its JSON work directory resolves to the checkout root.
case_prepare_defaults_to_caller_git_root() {
  local name="pmctl pm prepare: defaults to caller git root"
  should_run "$name" || return 0
  local out code=0 snapshot
  out="$(cd "$REPO_ROOT" && "$PMCTL" pm prepare --request 'default cwd CC-473' --json 2>/dev/null)" || code=$?
  if [[ "$code" -eq 0 ]] && jq -e --arg wd "$REPO_ROOT" '.working_dir == $wd' <<<"$out" >/dev/null; then
    snapshot="$(jq -r '.snapshot_file' <<<"$out")"
    [[ -f "$snapshot" ]] && rm -f "$snapshot"
    pass "$name"
  else
    fail "$name" "code=$code out=$out"
  fi
}

# Behavior: prepare succeeds without a snapshot when a target git repo has no BACKLOG.md.
# Steps: create a minimal git repo without a backlog; invoke prepare; assert unavailable snapshot status and null file.
case_prepare_degrades_without_backlog() {
  local name="pmctl pm prepare: degrades when backlog is absent"
  should_run "$name" || return 0
  local work="$tmp_root/no-backlog" out code=0
  mkdir -p "$work"
  git -C "$work" init -q
  out="$("$PMCTL" pm prepare --cd "$work" --request 'external repository request' --json 2>/dev/null)" || code=$?
  if [[ "$code" -eq 0 ]] && jq -e '.snapshot_status == "unavailable" and .snapshot_file == null' <<<"$out" >/dev/null; then
    pass "$name"
  else
    fail "$name" "code=$code out=$out"
  fi
}

# Behavior: prepare extracts each CC ticket once even when it occurs repeatedly in the request.
# Steps: prepare a request containing duplicate IDs; assert focus_tickets preserves first-seen unique order.
case_prepare_deduplicates_focus_tickets() {
  local name="pmctl pm prepare: deduplicates extracted focus tickets"
  should_run "$name" || return 0
  local out code=0 snapshot
  out="$("$PMCTL" pm prepare --cd "$REPO_ROOT" --request 'CC-473 then CC-473 and CC-474 then CC-473' --json 2>/dev/null)" || code=$?
  if [[ "$code" -eq 0 ]] && jq -e '.focus_tickets == ["CC-473", "CC-474"]' <<<"$out" >/dev/null; then
    snapshot="$(jq -r '.snapshot_file' <<<"$out")"
    [[ -f "$snapshot" ]] && rm -f "$snapshot"
    pass "$name"
  else
    fail "$name" "code=$code out=$out"
  fi
}

# Behavior: prepare rejects an empty request before creating any snapshot.
# Steps: invoke prepare with whitespace-only request text and assert usage exit 2.
case_prepare_rejects_empty_request() {
  local name="pmctl pm prepare: rejects empty request"
  should_run "$name" || return 0
  local code=0
  "$PMCTL" pm prepare --cd "$REPO_ROOT" --request '   ' >/dev/null 2>&1 || code=$?
  [[ "$code" -eq 2 ]] && pass "$name" || fail "$name" "expected exit 2, got $code"
}

# Behavior: prepare rejects a work directory outside a git worktree before creating a snapshot.
# Steps: pass a non-git directory with a valid request; assert usage exit 2 and the worktree error.
case_prepare_rejects_non_git_workdir() {
  local name="pmctl pm prepare: rejects non-git workdir"
  should_run "$name" || return 0
  local out="$tmp_root/non-git-prepare.out" code=0
  "$PMCTL" pm prepare --cd "$tmp_root" --request 'CC-473' > "$out" 2>&1 || code=$?
  if [[ "$code" -eq 2 ]] && grep -q 'must be inside a git worktree' "$out"; then
    pass "$name"
  else
    fail "$name" "expected worktree error, got $code out=$(<"$out")"
  fi
}

# Behavior: an unknown pm subcommand fails with the pm command usage contract.
# Steps: invoke pmctl pm with an unsupported subcommand; assert usage exit 2 and the prepare usage line.
case_unknown_subcommand_shows_usage() {
  local name="pmctl pm: unknown subcommand shows usage"
  should_run "$name" || return 0
  local out="$tmp_root/unknown.out" code=0
  "$PMCTL" pm not-a-real-subcommand > "$out" 2>&1 || code=$?
  if [[ "$code" -eq 2 ]] && grep -q '^usage: pmctl pm prepare' "$out"; then
    pass "$name"
  else
    fail "$name" "expected exit 2 with pm usage, got $code out=$(<"$out")"
  fi
}

# Behavior: run validates first, then uses the existing detached dispatch and wait primitives.
# Steps: source the coordinator with fake primitives; assert launch/wait arguments and JSON result.
case_run_uses_validate_detached_wait() {
  local name="pmctl pm run: validates then dispatches detached and waits"
  should_run "$name" || return 0
  # shellcheck source=scripts/lib/pmctl-pm.sh
  . "$REPO_ROOT/scripts/lib/pmctl-pm.sh"
  local trace="$tmp_root/run-trace" out="$tmp_root/run.out" seen_validate seen_launch seen_wait code=0
  pmctl_validate_brief() { printf 'validate:%s\n' "$*" >> "$trace"; return 0; }
  pmctl_dispatch_run() { printf 'launch:%s\n' "$*" >> "$trace"; printf 'run-test-473\n'; }
  pmctl_dispatch_wait() {
    [[ "${1:-}" == "$REPO_ROOT" ]] || return 97
    shift
    printf 'wait:%s\n' "$*" >> "$trace"
    return 0
  }
  pmctl_pm_run "$REPO_ROOT" --adapter codex --brief-file /tmp/brief-test.md --cd "$REPO_ROOT" --timeout 61 --json > "$out" || code=$?
  seen_validate="$(grep '^validate:' "$trace" || true)"
  seen_launch="$(grep '^launch:' "$trace" || true)"
  seen_wait="$(grep '^wait:' "$trace" || true)"
  if [[ "$code" -eq 0 ]] \
    && [[ "$seen_validate" == *"/tmp/brief-test.md"* ]] \
    && [[ "$seen_launch" == *"--lifecycle detached"* ]] \
    && [[ "$seen_wait" == "wait:run-test-473 --cd $REPO_ROOT --timeout 61" ]] \
    && jq -e '.run_id == "run-test-473" and .wait_exit_code == 0' "$out" >/dev/null; then
    pass "$name"
  else
    fail "$name" "code=$code validate=$seen_validate launch=$seen_launch wait=$seen_wait out=$(<"$out")"
  fi
}

# Behavior: run's human mode prints the authenticated dispatch handoff result.
# Steps: stub validation, launch, and wait; assert the complete four-line human contract.
case_run_emits_human_contract() {
  local name="pmctl pm run: emits human batch contract"
  should_run "$name" || return 0
  # shellcheck source=scripts/lib/pmctl-pm.sh
  . "$REPO_ROOT/scripts/lib/pmctl-pm.sh"
  local out="$tmp_root/run-human.out" code=0
  pmctl_validate_brief() { return 0; }
  pmctl_dispatch_run() { printf 'run-test-human-output\n'; }
  pmctl_dispatch_wait() { return 0; }
  pmctl_pm_run "$REPO_ROOT" --adapter codex --brief-file /tmp/brief-test.md --cd "$REPO_ROOT" > "$out" || code=$?
  if [[ "$code" -eq 0 ]] && [[ "$(<"$out")" == $'run_id: run-test-human-output\nworking_dir: '"$REPO_ROOT"$'\nadapter: codex\nwait_exit_code: 0' ]]; then
    pass "$name"
  else
    fail "$name" "code=$code out=$(<"$out")"
  fi
}

# Behavior: run rejects an invalid handover before it can launch a dispatch.
# Steps: invoke the CLI with a malformed brief and assert usage exit 2 and no executor requirement.
case_run_rejects_invalid_brief() {
  local name="pmctl pm run: rejects invalid brief before dispatch"
  should_run "$name" || return 0
  local brief="$tmp_root/invalid.md" code=0
  printf 'not a handover\n' > "$brief"
  "$PMCTL" pm run --adapter codex --brief-file "$brief" --cd "$REPO_ROOT" >/dev/null 2>&1 || code=$?
  [[ "$code" -eq 2 ]] && pass "$name" || fail "$name" "expected exit 2, got $code"
}

# Behavior: run rejects incomplete invocations before validating or dispatching a brief.
# Steps: omit required adapter and brief arguments; assert usage exit 2 and the complete required-field error.
case_run_requires_adapter_brief_and_workdir() {
  local name="pmctl pm run: requires adapter brief and workdir"
  should_run "$name" || return 0
  local out="$tmp_root/missing-run-fields.out" code=0
  "$PMCTL" pm run --cd "$REPO_ROOT" > "$out" 2>&1 || code=$?
  if [[ "$code" -eq 2 ]] && grep -q -- '--adapter, --brief-file, and --cd are required' "$out"; then
    pass "$name"
  else
    fail "$name" "expected required-field error, got $code out=$(<"$out")"
  fi
}

# Behavior: run rejects a work directory outside a git worktree before dispatch.
# Steps: supply all required flags with a non-git directory; assert usage exit 2 and the worktree error.
case_run_rejects_non_git_workdir() {
  local name="pmctl pm run: rejects non-git workdir"
  should_run "$name" || return 0
  local out="$tmp_root/non-git-run.out" code=0
  "$PMCTL" pm run --adapter codex --brief-file /tmp/brief-test.md --cd "$tmp_root" > "$out" 2>&1 || code=$?
  if [[ "$code" -eq 2 ]] && grep -q 'must be inside a git worktree' "$out"; then
    pass "$name"
  else
    fail "$name" "expected worktree error, got $code out=$(<"$out")"
  fi
}

# Behavior: run rejects a malformed dispatch identifier and does not enter its wait path.
# Steps: stub validation and launch with an invalid identifier; assert exit 1, diagnostic, and no wait trace.
case_run_rejects_invalid_dispatch_id() {
  local name="pmctl pm run: rejects invalid dispatch id before wait"
  should_run "$name" || return 0
  # shellcheck source=scripts/lib/pmctl-pm.sh
  . "$REPO_ROOT/scripts/lib/pmctl-pm.sh"
  local trace="$tmp_root/invalid-id-trace" out="$tmp_root/invalid-id.out" code=0
  pmctl_validate_brief() { return 0; }
  pmctl_dispatch_run() { printf 'not-a-run-id\n'; }
  pmctl_dispatch_wait() { printf 'wait-called\n' >> "$trace"; return 0; }
  pmctl_pm_run "$REPO_ROOT" --adapter codex --brief-file /tmp/brief-test.md --cd "$REPO_ROOT" > "$out" 2>&1 || code=$?
  if [[ "$code" -eq 1 ]] && grep -q 'dispatch returned invalid run id' "$out" && [[ ! -e "$trace" ]]; then
    pass "$name"
  else
    fail "$name" "expected invalid-id rejection, got $code out=$(<"$out") trace=$(cat "$trace" 2>/dev/null || true)"
  fi
}

# Behavior: run preserves a non-zero authenticated wait result after emitting its batch result.
# Steps: stub a valid launch and a failing wait; assert the returned exit code and JSON wait_exit_code match.
case_run_propagates_wait_failure() {
  local name="pmctl pm run: propagates wait failure exit code"
  should_run "$name" || return 0
  # shellcheck source=scripts/lib/pmctl-pm.sh
  . "$REPO_ROOT/scripts/lib/pmctl-pm.sh"
  local out="$tmp_root/wait-failure.out" code=0
  pmctl_validate_brief() { return 0; }
  pmctl_dispatch_run() { printf 'run-test-wait-failure\n'; }
  pmctl_dispatch_wait() { [[ "${1:-}" == "$REPO_ROOT" ]] || return 97; return 42; }
  pmctl_pm_run "$REPO_ROOT" --adapter codex --brief-file /tmp/brief-test.md --cd "$REPO_ROOT" --json > "$out" || code=$?
  if [[ "$code" -eq 42 ]] && jq -e '.run_id == "run-test-wait-failure" and .wait_exit_code == 42' "$out" >/dev/null; then
    pass "$name"
  else
    fail "$name" "expected wait exit 42, got $code out=$(<"$out")"
  fi
}

# Behavior: JSON mode owns stdout even when the shared wait primitive emits an advisory record.
# Steps: stub wait stdout; invoke JSON mode; assert the complete output remains parseable JSON.
case_run_json_suppresses_wait_stdout() {
  local name="pmctl pm run: JSON output suppresses wait stdout"
  should_run "$name" || return 0
  # shellcheck source=scripts/lib/pmctl-pm.sh
  . "$REPO_ROOT/scripts/lib/pmctl-pm.sh"
  local out="$tmp_root/json-wait-stdout.out" code=0
  pmctl_validate_brief() { return 0; }
  pmctl_dispatch_run() { printf 'run-test-json-output\n'; }
  pmctl_dispatch_wait() { printf 'advisory wait output\n'; return 0; }
  pmctl_pm_run "$REPO_ROOT" --adapter codex --brief-file /tmp/brief-test.md --cd "$REPO_ROOT" --json > "$out" || code=$?
  if [[ "$code" -eq 0 ]] && jq -e '.run_id == "run-test-json-output" and .wait_exit_code == 0' "$out" >/dev/null; then
    pass "$name"
  else
    fail "$name" "expected parseable JSON, got $code out=$(<"$out")"
  fi
}

# Behavior: run forwards optional adapter flags unchanged into the shared detached dispatcher.
# Steps: stub launch and wait; invoke model, isolation, and no-auto-pack options; assert all appear in launch argv.
case_run_forwards_optional_dispatch_flags() {
  local name="pmctl pm run: forwards model isolation and no-auto-pack"
  should_run "$name" || return 0
  # shellcheck source=scripts/lib/pmctl-pm.sh
  . "$REPO_ROOT/scripts/lib/pmctl-pm.sh"
  local trace="$tmp_root/optional-flags-trace" code=0
  pmctl_validate_brief() { return 0; }
  pmctl_dispatch_run() { printf '%s\n' "$*" > "$trace"; printf 'run-test-optional-flags\n'; }
  pmctl_dispatch_wait() { [[ "${1:-}" == "$REPO_ROOT" ]] || return 97; return 0; }
  pmctl_pm_run "$REPO_ROOT" --adapter codex --brief-file /tmp/brief-test.md --cd "$REPO_ROOT" \
    --model gpt-5.5 --isolation read-only --no-auto-pack >/dev/null || code=$?
  local args="$(<"$trace")"
  if [[ "$code" -eq 0 ]] \
    && [[ "$args" == *"--model gpt-5.5"* ]] \
    && [[ "$args" == *"--isolation read-only"* ]] \
    && [[ "$args" == *"--no-auto-pack"* ]]; then
    pass "$name"
  else
    fail "$name" "code=$code launch_args=$args"
  fi
}

case_prepare_emits_batch_contract
case_prepare_emits_human_contract
case_prepare_defaults_to_caller_git_root
case_prepare_degrades_without_backlog
case_prepare_deduplicates_focus_tickets
case_prepare_rejects_empty_request
case_prepare_rejects_non_git_workdir
case_unknown_subcommand_shows_usage
case_run_uses_validate_detached_wait
case_run_emits_human_contract
case_run_rejects_invalid_brief
case_run_requires_adapter_brief_and_workdir
case_run_rejects_non_git_workdir
case_run_rejects_invalid_dispatch_id
case_run_propagates_wait_failure
case_run_json_suppresses_wait_stdout
case_run_forwards_optional_dispatch_flags
th_summary
