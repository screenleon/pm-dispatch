#!/usr/bin/env bash
# Internal suite executor shared by run-tests.sh and the run-all-tests.sh compatibility wrapper.
# Usage: scripts/lib/test-suite-runner.sh [--suite <name>] [--skip <name>] [--list] [--jobs N] [--suite-timeout N]
# Requires a complete developer checkout: registered suites that are missing or
# non-executable fail loudly (exit 1). Use --skip <name> to opt out of a specific suite.
# Use --jobs N (or -j N) to set parallelism (default: nproc; falls back to 1 if nproc unavailable).
# Each suite has a 15-minute deadline by default. Use --suite-timeout N (seconds) or
# PM_DISPATCH_TEST_SUITE_TIMEOUT_SECS to tune it for an intentionally slow environment.
set -euo pipefail
export LC_ALL=C.UTF-8

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

SUITE_NAMES=(
  lint-agents
  lint-scripts
  lint-script-domain-inventory
  lint-test-docstrings
  test-guards
  test-guard-framework
  test-migrate
  test-migrate-to-events
  test-install
  test-uninstall
  test-usage-weekly
  test-usage-tracker
  test-pm-scripts
  test-codex-dispatch
  test-pmctl-dispatch
  test-pmctl-pm
  test-dispatch-record
  test-dispatch-lifecycle
  test-gate-lifecycle
  test-claude-dispatch
  test-opencode-dispatch
  test-layer-boundaries
  test-executor-router
  test-runner-kind
  test-pmctl-adapter-generate
  test-pr-gate
  test-setup-project
  test-patch-gitignore
  test-portable
  test-doctor
  test-hook-profile-parity
  test-lint-frontmatter
  test-lint-test-docstrings
  test-test-harness
  test-commands
  test-commands-runner
  test-dispatch-handover
  test-handover-validate
  test-dispatch-post-verify
  test-check-docs-freshness
  test-skill-refine
  test-pr-gate-profile
  test-run-all-tests
  test-run-tests
  test-timeout-resolve
  test-dispatch-common
  test-detached-launch
  test-lint-model-aliases
  test-reasoning-effort
  test-core-schemas
  test-host-manifest
  test-host-write-codex
  test-host-write-opencode
  test-host-write-parity
  test-pm-prep-snapshot
  test-schema-task-mirrors-backlog
  test-state-store
  test-state-paths
  test-pmctl-artifacts
  test-state-layout-parity
  test-state-store-rotation
  test-pmctl-trace
  test-pmctl-task
  test-pmctl-decision
  test-pmctl-gate
  test-pmctl-safe
  test-pmctl-validate
  test-brief-validate
  test-archive-closed-backlog
  test-script-domain-inventory
  test-pmctl-context
  test-pmctl-memory
  test-pmctl-backlog
  test-pmctl-guard
  test-pmctl-ship
  test-pmctl-worktree
  test-pre-release
  test-release-verify
  test-e2e-script
)

declare -A SUITE_PATHS=(
  [lint-agents]="scripts/lint-agents.sh"
  [lint-scripts]="scripts/lint-scripts.sh"
  [lint-script-domain-inventory]="scripts/lint-script-domain-inventory.sh"
  [lint-test-docstrings]="scripts/lint-test-docstrings.sh"
  [test-guards]="scripts/test-guards.sh"
  [test-guard-framework]="scripts/test-guard-framework.sh"
  [test-migrate]="scripts/test-migrate-routing-log.sh"
  [test-migrate-to-events]="scripts/test-migrate-routing-to-events.sh"
  [test-install]="scripts/test-install.sh"
  [test-uninstall]="scripts/test-uninstall.sh"
  [test-usage-weekly]="scripts/test-usage-weekly.sh"
  [test-usage-tracker]="scripts/test-usage-tracker.sh"
  [test-pm-scripts]="pm/scripts/test/run-tests.sh"
  [test-codex-dispatch]="scripts/test-codex-dispatch.sh"
  [test-pmctl-dispatch]="scripts/test-pmctl-dispatch.sh"
  [test-pmctl-pm]="scripts/test-pmctl-pm.sh"
  [test-dispatch-record]="scripts/test-dispatch-record.sh"
  [test-dispatch-lifecycle]="scripts/test-dispatch-lifecycle.sh"
  [test-gate-lifecycle]="scripts/test-gate-lifecycle.sh"
  [test-claude-dispatch]="scripts/test-claude-dispatch.sh"
  [test-opencode-dispatch]="scripts/test-opencode-dispatch.sh"
  [test-layer-boundaries]="scripts/test-layer-boundaries.sh"
  [test-executor-router]="scripts/test-executor-router.sh"
  [test-runner-kind]="scripts/test-runner-kind.sh"
  [test-pmctl-adapter-generate]="scripts/test-pmctl-adapter-generate.sh"
  [test-pr-gate]="scripts/test-pr-gate.sh"
  [test-setup-project]="scripts/test-setup-project.sh"
  [test-patch-gitignore]="scripts/test-patch-gitignore.sh"
  [test-portable]="scripts/test-portable.sh"
  [test-doctor]="scripts/test-doctor.sh"
  [test-hook-profile-parity]="scripts/test-hook-profile-parity.sh"
  [test-lint-frontmatter]="scripts/test-lint-frontmatter.sh"
  [test-lint-test-docstrings]="scripts/test-lint-test-docstrings.sh"
  [test-test-harness]="scripts/test-test-harness.sh"
  [test-commands]="scripts/test-commands.sh"
  [test-commands-runner]="scripts/test-commands-runner.sh"
  [test-dispatch-handover]="scripts/test-dispatch-handover.sh"
  [test-handover-validate]="scripts/test-handover-validate.sh"
  [test-dispatch-post-verify]="scripts/test-dispatch-post-verify.sh"
  [test-check-docs-freshness]="scripts/test-check-docs-freshness.sh"
  [test-skill-refine]="scripts/test-skill-refine.sh"
  [test-pr-gate-profile]="scripts/test-pr-gate-profile.sh"
  [test-run-all-tests]="scripts/test-run-all-tests.sh"
  [test-run-tests]="scripts/test-run-tests.sh"
  [test-timeout-resolve]="scripts/test-timeout-resolve.sh"
  [test-dispatch-common]="scripts/test-dispatch-common.sh"
  [test-detached-launch]="scripts/test-detached-launch.sh"
  [test-lint-model-aliases]="scripts/test-lint-model-aliases.sh"
  [test-reasoning-effort]="scripts/test-reasoning-effort.sh"
  [test-core-schemas]="scripts/test-core-schemas.sh"
  [test-host-manifest]="scripts/test-host-manifest.sh"
  [test-host-write-codex]="scripts/test-host-write-codex.sh"
  [test-host-write-opencode]="scripts/test-host-write-opencode.sh"
  [test-host-write-parity]="scripts/test-host-write-parity.sh"
  [test-pm-prep-snapshot]="scripts/test-pm-prep-snapshot.sh"
  [test-schema-task-mirrors-backlog]="scripts/test-schema-task-mirrors-backlog.sh"
  [test-state-store]="scripts/test-state-store.sh"
  [test-state-paths]="scripts/test-state-paths.sh"
  [test-pmctl-artifacts]="scripts/test-pmctl-artifacts.sh"
  [test-state-layout-parity]="scripts/test-state-layout-parity.sh"
  [test-state-store-rotation]="scripts/test-state-store-rotation.sh"
  [test-pmctl-trace]="scripts/test-pmctl-trace.sh"
  [test-pmctl-task]="scripts/test-pmctl-task.sh"
  [test-pmctl-decision]="scripts/test-pmctl-decision.sh"
  [test-pmctl-gate]="scripts/test-pmctl-gate.sh"
  [test-pmctl-safe]="scripts/test-pmctl-safe.sh"
  [test-pmctl-validate]="scripts/test-pmctl-validate.sh"
  [test-brief-validate]="scripts/test-brief-validate.sh"
  [test-archive-closed-backlog]="scripts/test-archive-closed-backlog.sh"
  [test-script-domain-inventory]="scripts/test-script-domain-inventory.sh"
  [test-pmctl-context]="scripts/test-pmctl-context.sh"
  [test-pmctl-memory]="scripts/test-pmctl-memory.sh"
  [test-pmctl-backlog]="scripts/test-pmctl-backlog.sh"
  [test-pmctl-guard]="scripts/test-pmctl-guard.sh"
  [test-pmctl-ship]="scripts/test-pmctl-ship.sh"
  [test-pmctl-worktree]="scripts/test-pmctl-worktree.sh"
  [test-pre-release]="scripts/test-pre-release.sh"
  [test-release-verify]="scripts/test-release-verify.sh"
  [test-e2e-script]="scripts/test-e2e-script.sh"
)

declare -A SKIP_REQUESTED=()
declare -A SUITE_REQUESTED=()
SUITE_FILTER=0
LIST=0
_detected_jobs="$(nproc 2>/dev/null || echo 1)"
[[ "$_detected_jobs" =~ ^[1-9][0-9]*$ ]] || _detected_jobs=1
_default_job_cap="${PM_DISPATCH_TEST_MAX_JOBS:-8}"
[[ "$_default_job_cap" =~ ^[1-9][0-9]*$ ]] || _default_job_cap=8
if (( _detected_jobs > _default_job_cap )); then
  JOBS="$_default_job_cap"
else
  JOBS="$_detected_jobs"
fi
SUITE_TIMEOUT_SECS="${PM_DISPATCH_TEST_SUITE_TIMEOUT_SECS:-900}"
[[ "$SUITE_TIMEOUT_SECS" =~ ^[1-9][0-9]*$ ]] || SUITE_TIMEOUT_SECS=900
PROGRESS_INTERVAL_SECS="${PM_DISPATCH_TEST_PROGRESS_SECS:-60}"
[[ "$PROGRESS_INTERVAL_SECS" =~ ^[1-9][0-9]*$ ]] || PROGRESS_INTERVAL_SECS=60
SUITE_RESULTS_FILE="${PM_TEST_SUITE_RESULTS_FILE:-}"
SUITE_RESULTS_TMP=""
if [[ -n "$SUITE_RESULTS_FILE" ]]; then
  mkdir -p "$(dirname "$SUITE_RESULTS_FILE")"
  SUITE_RESULTS_TMP="$(mktemp "${TMPDIR:-/tmp}/pm-suite-results.XXXXXX")"
fi

record_suite_result() {
  local name="$1" status="$2" exit_code="$3" duration="$4" reason="${5:-}"
  [[ -n "$SUITE_RESULTS_TMP" ]] || return 0
  jq -nc --arg name "$name" --arg status "$status" --argjson exit_code "$exit_code" \
    --argjson duration_seconds "$duration" --arg reason "$reason" \
    '{name:$name,status:$status,exit_code:$exit_code,duration_seconds:$duration_seconds}
     + (if $reason == "" then {} else {reason:$reason} end)' >> "$SUITE_RESULTS_TMP"
}

write_suite_results() {
  [[ -n "$SUITE_RESULTS_FILE" ]] || return 0
  local ordered_names
  ordered_names="$(printf '%s\n' "${ACTIVE_SUITE_NAMES[@]}" | jq -Rsc 'split("\n") | map(select(length > 0))')"
  jq -s --argjson order "$ordered_names" '[ $order[] as $name | .[] | select(.name == $name) ]' \
    "$SUITE_RESULTS_TMP" > "$SUITE_RESULTS_FILE"
  rm -f "$SUITE_RESULTS_TMP"
  SUITE_RESULTS_TMP=""
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --suite)
      if [[ -z "${2:-}" || "${2:-}" == --* ]]; then
        printf 'usage: %s [--suite <suite-name>] [--skip <suite-name>] [--list] [--jobs N] [--suite-timeout N]\n' "$0" >&2
        printf 'error: --suite requires a non-empty suite name (got: %q)\n' "${2:-}" >&2
        exit 2
      fi
      SUITE_REQUESTED["$2"]=1
      SUITE_FILTER=1
      shift 2
      ;;
    --skip)
      if [[ -z "${2:-}" || "${2:-}" == --* ]]; then
        printf 'usage: %s [--suite <suite-name>] [--skip <suite-name>] [--list] [--jobs N] [--suite-timeout N]\n' "$0" >&2
        printf 'error: --skip requires a non-empty suite name (got: %q)\n' "${2:-}" >&2
        exit 2
      fi
      SKIP_REQUESTED["$2"]=1
      shift 2
      ;;
    --list)
      LIST=1
      shift
      ;;
    --jobs|-j)
      if [[ -z "${2:-}" || ! "${2:-}" =~ ^[1-9][0-9]*$ ]]; then
        printf 'run-all-tests: --jobs requires a positive integer\n' >&2
        exit 2
      fi
      JOBS="$2"
      shift 2
      ;;
    --suite-timeout)
      if [[ -z "${2:-}" || ! "${2:-}" =~ ^[1-9][0-9]*$ ]]; then
        printf 'run-all-tests: --suite-timeout requires a positive integer (seconds)\n' >&2
        exit 2
      fi
      SUITE_TIMEOUT_SECS="$2"
      shift 2
      ;;
    *)
      echo "run-all-tests: unknown flag $1" >&2
      exit 2
      ;;
  esac
done

TIMEOUT_BIN=""
if command -v timeout >/dev/null 2>&1; then
  TIMEOUT_BIN="$(command -v timeout)"
elif command -v gtimeout >/dev/null 2>&1; then
  # Homebrew coreutils exposes GNU timeout as gtimeout on macOS.
  TIMEOUT_BIN="$(command -v gtimeout)"
else
  printf 'run-all-tests: requires GNU timeout (timeout or gtimeout) for per-suite deadlines\n' >&2
  exit 2
fi

# ── Registry-sync guard ──────────────────────────────────────────────────────
# SUITE_NAMES (ordered) and SUITE_PATHS (name→script) are two parallel registries.
# A name added to one but not the other previously surfaced only as a deep
# `SUITE_PATHS[$name]: unbound variable` crash mid-run. Assert both registries
# agree up front so any future drift fails loud and obvious at startup.
_registry_drift=()
for _name in "${SUITE_NAMES[@]}"; do
  [[ -n "${SUITE_PATHS[$_name]:-}" ]] || _registry_drift+=("name without path: $_name")
done
for _name in "${!SUITE_PATHS[@]}"; do
  _found=0
  for _n in "${SUITE_NAMES[@]}"; do [[ "$_n" == "$_name" ]] && { _found=1; break; }; done
  [[ "$_found" -eq 1 ]] || _registry_drift+=("path without name: $_name")
done
if [[ "${#_registry_drift[@]}" -gt 0 ]]; then
  printf 'run-all-tests: SUITE_NAMES/SUITE_PATHS registry drift:\n' >&2
  printf '  - %s\n' "${_registry_drift[@]}" >&2
  exit 2
fi
unset _name _n _found _registry_drift

# --suite is a positive selection contract used by the fast runner. Keep the
# registry order stable, reject typos before any suite starts, and do not count
# suites outside the selection as skipped. With no --suite flags this remains
# the authoritative full-suite runner.
ACTIVE_SUITE_NAMES=()
if [[ "$SUITE_FILTER" -eq 1 ]]; then
  for _name in "${!SUITE_REQUESTED[@]}"; do
    if [[ -z "${SUITE_PATHS[$_name]:-}" ]]; then
      printf 'run-all-tests: unknown suite requested by --suite: %s\n' "$_name" >&2
      exit 2
    fi
  done
  for _name in "${SUITE_NAMES[@]}"; do
    [[ -n "${SUITE_REQUESTED[$_name]:-}" ]] && ACTIVE_SUITE_NAMES+=("$_name")
  done
else
  ACTIVE_SUITE_NAMES=("${SUITE_NAMES[@]}")
fi
unset _name

# ── Live-context-db mutual exclusion ─────────────────────────────────────────
# These suites both contend on the developer's live $REPO_ROOT/.pm-dispatch/ctx/
# context.db: test-pmctl-context asserts it is unchanged for the suite's
# duration (its no-live-db-mutation guard), while test-release-verify runs
# release-verify.sh Phase 3 which indexes THIS repo and rebuilds that same db.
# Run concurrently, the writer trips the reader's guard (a false failure). The
# parallel scheduler below never lets two of these run at the same time.
declare -A LIVE_DB_EXCLUSIVE=(
  [test-pmctl-context]=1
  [test-release-verify]=1
)

if [[ "$LIST" -eq 1 ]]; then
  printf '%s\n' "${ACTIVE_SUITE_NAMES[@]}"
  exit 0
fi

passed=0
failed=0
skipped=0
FAILED_SUITE_NAMES=()
declare -A SUITE_DURATIONS=()

run_with_suite_timeout() {
  # The result sink belongs to this runner process. Do not leak it into a
  # suite that happens to launch another runner, or the nested process could
  # overwrite its parent's evidence artifact.
  ( unset PM_TEST_SUITE_RESULTS_FILE PM_DISPATCH_PREFLIGHT_TEST_RESULT
    "$TIMEOUT_BIN" --kill-after=15s "${SUITE_TIMEOUT_SECS}s" "$@"
  )
}

run_suite() {
  local name="$1"
  local script="$REPO_ROOT/${SUITE_PATHS[$name]}"
  local rc=0

  # A hung suite used to hold a parallel slot indefinitely while all of its
  # output stayed buffered. Keep the deadline per suite so one stalled child
  # cannot consume the gate's whole aggregate timeout.
  case "$name" in
    test-guards)
      HOME="${CLAUDE_CONFIG_TEST_PREFLIGHT_HOME:-$HOME}" \
        TEST_GUARDS_PROGRESS="${TEST_GUARDS_PROGRESS:-1}" \
        run_with_suite_timeout "$script"
      ;;
    test-install)
      CLAUDE_CONFIG_TEST_INSTALL_RUNNING=1 run_with_suite_timeout bash "$script"
      ;;
    test-pm-scripts)
      run_with_suite_timeout bash "$script"
      ;;
    *)
      run_with_suite_timeout "$script"
      ;;
  esac || rc=$?
  if [[ "$rc" -eq 124 ]]; then
    printf 'TIMEOUT %s (%ss)\n' "$name" "$SUITE_TIMEOUT_SECS" >&2
  fi
  return "$rc"
}

# ── Suite eligibility check (shared by sequential and parallel paths) ─────────
_suite_skip_reason() {
  local name="$1"
  if [[ -n "${SKIP_REQUESTED[$name]:-}" ]]; then
    printf 'requested'
    return 0
  fi
  if [[ "$name" == "test-codex-dispatch" ]] &&
    [[ "${CODEX_SKIP_IF_MISSING:-1}" != "0" ]] &&
    ! command -v codex >/dev/null 2>&1; then
    printf 'codex not on PATH'
    return 0
  fi
  return 1
}

# ── Sequential path (JOBS=1, used when nproc unavailable or --jobs 1) ─────────
if [[ "$JOBS" -eq 1 ]]; then
  for name in "${ACTIVE_SUITE_NAMES[@]}"; do
    if reason="$(_suite_skip_reason "$name")"; then
      printf 'SKIP %s (%s)\n' "$name" "$reason"
      record_suite_result "$name" skip 0 0 "$reason"
      skipped=$((skipped + 1))
      continue
    fi

    script="$REPO_ROOT/${SUITE_PATHS[$name]}"
    if [[ ! -x "$script" ]]; then
      printf 'FAIL %s (not found or not executable)\n' "$name"
      record_suite_result "$name" fail 126 0 "not found or not executable"
      failed=$((failed + 1))
      FAILED_SUITE_NAMES+=("$name")
      continue
    fi

    suite_started="$SECONDS"
    printf 'START %s\n' "$name"
    set +e
    run_suite "$name"
    rc=$?
    set -e
    SUITE_DURATIONS["$name"]="$(( SECONDS - suite_started ))"

    if [[ "$rc" -eq 0 ]]; then
      printf 'PASS %s\n' "$name"
      record_suite_result "$name" pass 0 "${SUITE_DURATIONS[$name]}"
      passed=$((passed + 1))
    else
      printf 'FAIL %s\n' "$name"
      if [[ "$rc" -eq 124 ]]; then
        record_suite_result "$name" timeout "$rc" "${SUITE_DURATIONS[$name]}"
      else
        record_suite_result "$name" fail "$rc" "${SUITE_DURATIONS[$name]}"
      fi
      failed=$((failed + 1))
      FAILED_SUITE_NAMES+=("$name")
    fi
  done
else
  # ── Parallel path (--jobs N) ───────────────────────────────────────────────
  # Each in-flight suite gets a temp dir: <tmpdir>/out (stdout+stderr) and
  # <tmpdir>/rc (exit code written on completion). We poll at ~50ms intervals
  # and drain finished jobs to keep at most JOBS running concurrently. Output
  # is buffered per suite and printed atomically when the suite completes.

  _tmpbase="$(mktemp -d)"
  trap 'rm -rf "$_tmpbase"' EXIT

  # In-flight tracking arrays (indexed together by position)
  _if_names=()
  _if_pids=()
  _if_dirs=()
  declare -A _progress_reported=()

  _launch() {
    local name="$1" script="$2" d
    d="$_tmpbase/$name"
    mkdir -p "$d"
    printf '255\n' > "$d/rc"
    printf '%s\n' "$SECONDS" > "$d/started"
    printf 'START %s\n' "$name"
    (
      set +e
      run_suite "$name" > "$d/out" 2>&1
      printf '%s\n' "$?" > "$d/rc"
    ) &
    _if_names+=("$name")
    _if_pids+=($!)
    _if_dirs+=("$d")
  }

  # True while any live-db-exclusive suite is currently in-flight.
  _exclusive_inflight() {
    local i
    for ((i = 0; i < ${#_if_names[@]}; i++)); do
      [[ -n "${LIVE_DB_EXCLUSIVE[${_if_names[$i]}]:-}" ]] && return 0
    done
    return 1
  }

  _drain() {
    local i new_names=() new_pids=() new_dirs=()
    for ((i = 0; i < ${#_if_pids[@]}; i++)); do
      local pid="${_if_pids[$i]}" name="${_if_names[$i]}" d="${_if_dirs[$i]}"
      if ! kill -0 "$pid" 2>/dev/null; then
        wait "$pid" 2>/dev/null || true
        local rc
        rc="$(cat "$d/rc" 2>/dev/null || printf '1')"
        [[ "$rc" =~ ^[0-9]+$ ]] || rc=1
        local started finished
        started="$(cat "$d/started" 2>/dev/null || printf '%s' "$SECONDS")"
        finished="$SECONDS"
        SUITE_DURATIONS["$name"]="$((finished - started))"
        # Print buffered suite output then its result line
        [[ -s "$d/out" ]] && cat "$d/out"
        if [[ "$rc" -eq 0 ]]; then
          printf 'PASS %s\n' "$name"
          record_suite_result "$name" pass 0 "${SUITE_DURATIONS[$name]}"
          passed=$((passed + 1))
        else
          printf 'FAIL %s\n' "$name"
          if [[ "$rc" -eq 124 ]]; then
            record_suite_result "$name" timeout "$rc" "${SUITE_DURATIONS[$name]}"
          else
            record_suite_result "$name" fail "$rc" "${SUITE_DURATIONS[$name]}"
          fi
          failed=$((failed + 1))
          FAILED_SUITE_NAMES+=("$name")
        fi
      else
        local elapsed=$(( SECONDS - $(cat "$d/started" 2>/dev/null || printf '%s' "$SECONDS") ))
        if [[ -z "${_progress_reported[$name]:-}" ]] && (( elapsed >= PROGRESS_INTERVAL_SECS )); then
          printf 'RUNNING %s (%ss)\n' "$name" "$elapsed"
          _progress_reported["$name"]=1
        fi
        new_names+=("$name")
        new_pids+=("$pid")
        new_dirs+=("$d")
      fi
    done
    _if_names=("${new_names[@]+"${new_names[@]}"}")
    _if_pids=("${new_pids[@]+"${new_pids[@]}"}")
    _if_dirs=("${new_dirs[@]+"${new_dirs[@]}"}")
  }

  for name in "${ACTIVE_SUITE_NAMES[@]}"; do
    if reason="$(_suite_skip_reason "$name")"; then
      printf 'SKIP %s (%s)\n' "$name" "$reason"
      record_suite_result "$name" skip 0 0 "$reason"
      skipped=$((skipped + 1))
      continue
    fi

    script="$REPO_ROOT/${SUITE_PATHS[$name]}"
    if [[ ! -x "$script" ]]; then
      printf 'FAIL %s (not found or not executable)\n' "$name"
      record_suite_result "$name" fail 126 0 "not found or not executable"
      failed=$((failed + 1))
      FAILED_SUITE_NAMES+=("$name")
      continue
    fi

    # Wait for an open slot
    while [[ ${#_if_pids[@]} -ge "$JOBS" ]]; do
      _drain
      [[ ${#_if_pids[@]} -ge "$JOBS" ]] && sleep 0.05
    done

    # Suites that access the shared repo/memory context index may overlap
    # ordinary isolated suites, but never each other. This prevents context.db
    # collisions without serializing the entire test run behind two long suites.
    if [[ -n "${LIVE_DB_EXCLUSIVE[$name]:-}" ]]; then
      while _exclusive_inflight; do
        _drain
        _exclusive_inflight && sleep 0.05
      done
    fi

    _launch "$name" "$script"
  done

  # Drain remaining in-flight suites
  while [[ ${#_if_pids[@]} -gt 0 ]]; do
    _drain
    [[ ${#_if_pids[@]} -gt 0 ]] && sleep 0.05
  done
fi

printf '%s passed, %s failed, %s skipped\n' "$passed" "$failed" "$skipped"
if [[ "${#SUITE_DURATIONS[@]}" -gt 0 ]]; then
  printf 'slowest suites:\n'
  declare -A _duration_reported=()
  for ((_rank = 0; _rank < 10; _rank++)); do
    _slow_name=""
    _slow_seconds=-1
    for name in "${!SUITE_DURATIONS[@]}"; do
      [[ -n "${_duration_reported[$name]:-}" ]] && continue
      if (( SUITE_DURATIONS[$name] > _slow_seconds )); then
        _slow_name="$name"
        _slow_seconds="${SUITE_DURATIONS[$name]}"
      fi
    done
    [[ -n "$_slow_name" ]] || break
    printf '  %ss %s\n' "$_slow_seconds" "$_slow_name"
    _duration_reported["$_slow_name"]=1
  done
fi
if [[ "${#FAILED_SUITE_NAMES[@]}" -gt 0 ]]; then
  printf 'failed suites:'
  printf ' %s' "${FAILED_SUITE_NAMES[@]}"
  printf '\n'
  write_suite_results
  exit 1
fi
write_suite_results
