#!/usr/bin/env bash
# pmctl gate subcommand — routes gate runs through pmctl instead of directly
# calling runtime/bin/pr-gate.sh.  The gate script remains the implementation;
# this shim adds --cd defaulting, run-dir partitioning, and (CC-423) an
# opt-in detached lifecycle mirroring `pmctl dispatch run --lifecycle detached`.

# 6 random hex chars, used to make generated gate ids unguessable/unique.
# Deliberately self-contained (not reused from pmctl-dispatch.sh) so
# tests/shell/test-pmctl-gate.sh and tests/shell/test-gate-lifecycle.sh can source
# pmctl-gate.sh standalone, as the existing test fixtures already do.
_pmctl_gate_hex6() {
  local hex
  hex="$(dd if=/dev/urandom bs=3 count=1 2>/dev/null | od -An -tx1 | tr -d ' \n')"
  printf '%s\n' "${hex:0:6}"
}

# Default work dir for gate run/wait when --cd is omitted: the git toplevel
# of the caller's CWD, falling back to $PWD outside any git worktree. Both
# ends MUST use this same derivation — `pmctl gate wait` independently
# recomputes the run dir partition from its --cd, so run and wait defaulting
# differently (e.g. run from a subdir, wait from the repo root) would make the
# recompute diverge and fail the result-path ownership check.
_pmctl_gate_default_cd() {
  local toplevel
  toplevel="$(git rev-parse --show-toplevel 2>/dev/null)"
  if [[ -n "$toplevel" ]]; then
    printf '%s\n' "$toplevel"
  else
    printf '%s\n' "$PWD"
  fi
}

# Per-user private key-file directory for the detached-gate sentinel nonce,
# mirroring _pmctl_sentinel_key_file in pmctl-dispatch.sh but rooted at a
# separate /tmp namespace so gate and dispatch sentinels never collide.
_pmctl_gate_sentinel_key_file() {
  local _gate_id="${1:-}"
  detached_launch_key_file "pm-gate-dispatch" "$_gate_id"
}

# Load the single canonical run-dir resolver for both detached launch and wait.
_pmctl_gate_ensure_run_dir_fn() {
  local repo_root="${1:?repo root required}" _sp_lib
  [[ "$(type -t sw_project_run_dir 2>/dev/null)" == function ]] && return 0
  _sp_lib="$repo_root/runtime/lib/state-paths.sh"
  if [[ -r "$_sp_lib" ]]; then
    # shellcheck disable=SC1090,SC1091
    . "$_sp_lib" 2>/dev/null || true
  fi
  [[ "$(type -t sw_project_run_dir 2>/dev/null)" == function ]]
}

# Gate's standalone/copy-mode fixtures source only this shim.  Keep that
# compatibility import in one place, then delegate readiness checks to the
# operation layer rather than duplicating variants at each call site.
_pmctl_gate_operation_ensure_loaded() {
  local repo_root="$1" _operation_lib
  if ! declare -F _pmctl_operation_ensure_loaded >/dev/null 2>&1; then
    _operation_lib="$repo_root/runtime/lib/pmctl-operation.sh"
    # shellcheck disable=SC1090,SC1091 # repo-root-relative optional library
    [[ -r "$_operation_lib" ]] && . "$_operation_lib"
  fi
  declare -F _pmctl_operation_ensure_loaded >/dev/null 2>&1 \
    && _pmctl_operation_ensure_loaded "$repo_root"
}

# Load the verifier from the selected pmctl repository even when the caller
# exported a function with the same name. Bash function exports do not carry a
# dependency manifest, so trusting an inherited gate_result_verify can leave
# its private helpers missing or mix functions from different revisions.
_pmctl_gate_result_verifier_load() {
  local repo_root="$1" verifier_lib
  verifier_lib="$repo_root/runtime/lib/gate-result-verify.sh"
  [[ -r "$verifier_lib" ]] || return 1
  # shellcheck disable=SC1090,SC1091
  . "$verifier_lib" || return 1
  declare -F gate_result_verify >/dev/null 2>&1 \
    && declare -F gate_result_verdict_verify >/dev/null 2>&1 \
    && declare -F _gate_result_frontmatter_value >/dev/null 2>&1 \
    && declare -F _gate_result_sha256_file >/dev/null 2>&1
}

# A v2 result and its bound sidecar cannot be renamed into place as one
# filesystem operation. If a verifier races the producer between those
# renames, wait briefly for the sidecar (and, for verified independence,
# its protected attestation) instead of turning a valid in-flight
# finalization into a permanent false negative.
_pmctl_gate_wait_for_assurance_publication() {
  local result_file="$1" version pointer result_parent assurance_file
  local assurance_kind evidence_status attestation_pointer run_root
  local attempt=0 max_attempts=20

  version="$(_gate_result_frontmatter_value "$result_file" gate_result_version)"
  [[ "$version" == pr_gate_result_v2 ]] || return 0
  result_parent="$(cd "$(dirname "$result_file")" 2>/dev/null && pwd -P)" || return 0
  # Only canonical run-layout results have an asynchronous producer
  # finalization lifecycle. Ad-hoc and copy-mode results fail immediately.
  [[ "$(basename "$result_parent")" == ".gate-results" ]] || return 0
  pointer="$(_gate_result_frontmatter_value "$result_file" gate_assurance)"
  if [[ -z "$pointer" || "$pointer" == */* || "$pointer" == "." || "$pointer" == ".." \
      || ! "$pointer" =~ ^[A-Za-z0-9._-]+\.json$ ]]; then
    return 0
  fi
  assurance_file="$result_parent/$pointer"
  run_root="$(dirname "$result_parent")"

  while (( attempt < max_attempts )); do
    if [[ -s "$assurance_file" ]]; then
      assurance_kind="$(jq -r '.kind // empty' "$assurance_file" 2>/dev/null)"
      evidence_status="$(jq -r \
        '.coordinates.independence.evidence_status // "unavailable"' \
        "$assurance_file" 2>/dev/null || printf 'unavailable')"
      if [[ "$assurance_kind" != gate_assurance_v2 || "$evidence_status" != verified ]]; then
        return 0
      fi
      attestation_pointer="$(jq -r '.provenance.attestation // empty' \
        "$assurance_file" 2>/dev/null)"
      if [[ -n "$attestation_pointer" && "$attestation_pointer" != */* \
          && -s "$run_root/$attestation_pointer" ]]; then
        return 0
      fi
    fi
    attempt=$((attempt + 1))
    sleep 0.1
  done
}

pmctl_gate_run() {
  local repo_root="$1"; shift

  local gate_script="$repo_root/runtime/bin/pr-gate.sh"
  if [[ ! -x "$gate_script" ]]; then
    printf 'pmctl gate run: gate script not found or not executable: %s\n' "$gate_script" >&2
    return 2
  fi

  # Extract --lifecycle first. It is a pmctl-level dispatch choice, not a
  # pr-gate.sh flag, so it is always stripped from the args forwarded below
  # regardless of lifecycle. Default is detached (mirrors dispatch's default;
  # CC-423): callers that need the old synchronous exec behavior pass
  # --lifecycle foreground explicitly.
  local lifecycle="detached"
  local -a args=()
  local _li=0
  local -a _lin=("$@")
  while [[ "$_li" -lt "${#_lin[@]}" ]]; do
    if [[ "${_lin[$_li]}" == "--lifecycle" ]]; then
      _li=$((_li + 1))
      if [[ "$_li" -ge "${#_lin[@]}" ]]; then
        printf 'pmctl gate run: missing value for --lifecycle\n' >&2
        return 2
      fi
      lifecycle="${_lin[$_li]}"
      case "$lifecycle" in
        foreground | detached) : ;;
        *)
          printf 'pmctl gate run: invalid --lifecycle %q (expected foreground or detached)\n' "$lifecycle" >&2
          return 2
          ;;
      esac
      _li=$((_li + 1))
    else
      args+=("${_lin[$_li]}")
      _li=$((_li + 1))
    fi
  done
  set -- "${args[@]}"

  # -h/--help always forwards synchronously to pr-gate.sh's own usage output,
  # regardless of lifecycle (checked after --lifecycle is stripped above, so
  # `--lifecycle detached --help` and bare `--help` -- default lifecycle is
  # detached -- both still print usage instead of forking a supervisor for a
  # no-op run): a caller asking for help wants text on stdout immediately,
  # not a detached gate_id that reflects nothing about the requested run.
  local _arg
  for _arg in "$@"; do
    if [[ "$_arg" == "-h" || "$_arg" == "--help" ]]; then
      gate_rc=0
      "$gate_script" "$@" || gate_rc=$?
      exit "$gate_rc"
    fi
  done

  # Extract --cd value first so the run dir is keyed to the TARGET repo's partition,
  # not the caller's cwd. Fall back to the CWD git toplevel (then $PWD) when
  # --cd is absent, matching `pmctl gate wait`'s default. A bare
  # trailing --cd (no value follows) is a usage error, not "use $PWD" --
  # matching pmctl_dispatch_run's --cd validation (pmctl-dispatch.sh:1161-1165)
  # -- otherwise the detached path would silently launch a supervisor against
  # the wrong directory and still return a "successful" gate_id.
  #
  # Single pass also builds _passthrough (args with the --cd pair removed):
  # the detached path's native forward args need --cd excluded (the
  # supervisor receives effective_cd as a trusted scalar and forwards it to
  # pr-gate.sh itself, mirroring dispatch's cd_arg/native split), so
  # validation and stripping share one parse instead of two separate loops
  # that could diverge on where --cd is found.
  local effective_cd
  effective_cd="$(_pmctl_gate_default_cd)"
  local has_cd=false
  local -a _passthrough=()
  local _i=0
  local _args=("$@")
  while [[ "$_i" -lt "${#_args[@]}" ]]; do
    if [[ "${_args[$_i]}" == "--cd" ]]; then
      has_cd=true
      _i=$((_i + 1))
      if [[ "$_i" -ge "${#_args[@]}" ]]; then
        printf 'pmctl gate run: missing value for --cd\n' >&2
        return 2
      fi
      effective_cd="${_args[$_i]}"
      _i=$((_i + 1))
    else
      _passthrough+=("${_args[$_i]}")
      _i=$((_i + 1))
    fi
  done
  effective_cd="$(cd "$effective_cd" 2>/dev/null && pwd -P)" || {
    printf 'pmctl gate run: --cd is not an accessible directory: %s\n' "$effective_cd" >&2
    return 2
  }

  # pmctl-owned workflow boundary: refresh the generic repo context cache
  # before dispatch. pr-gate.sh remains repo-agnostic and knows nothing about
  # sqlite, context DB paths, or repository-specific content.
  if declare -F pmctl_context_workflow_refresh >/dev/null 2>&1; then
    local _ctx_status _ctx_refresh _ctx_db
    _ctx_status="$(pmctl_context_workflow_refresh "$effective_cd" --json 2>/dev/null)" || _ctx_status=""
    if [[ -n "$_ctx_status" ]]; then
      _ctx_refresh="$(jq -r '.refresh_status // .freshness // "unknown"' <<<"$_ctx_status" 2>/dev/null || printf unknown)"
      _ctx_db="$(jq -r '.db_path // ""' <<<"$_ctx_status" 2>/dev/null || true)"
      printf 'pmctl gate context: status=%s repo=%s db=%s\n' "$_ctx_refresh" "$effective_cd" "$_ctx_db" >&2
    else
      printf 'pmctl gate context: status=error repo=%s (gate continues; context is optional)\n' "$effective_cd" >&2
    fi
  fi

  # The gate itself is a producer: reviewer/synthesis executor sessions below
  # are launched as detached pmctl dispatch children.  Create the parent before
  # either lifecycle path starts so no child can exist without durable owner
  # evidence.  The exported value survives the detached supervisor boundary.
  if _pmctl_gate_operation_ensure_loaded "$repo_root"; then
    local _gate_parent_operation
    _gate_parent_operation="$(pmctl_operation_create "$repo_root" "$effective_cd" gate)" || {
      printf 'pmctl gate run: failed to create parent operation record\n' >&2
      return 2
    }
    export PM_GATE_PARENT_OPERATION="$_gate_parent_operation"
    if ! pmctl_operation_expect_producer "$repo_root" gate "$_gate_parent_operation" "$effective_cd"; then
      printf 'pmctl gate run: failed to reserve producer ownership under %s\n' \
        "$_gate_parent_operation" >&2
      pmctl_operation_fail_if_childless "$repo_root" gate "$_gate_parent_operation" "$effective_cd" >&2 || true
      return 2
    fi
    printf 'pmctl gate run: parent operation: %s\n' "$_gate_parent_operation" >&2
  else
    # Standalone/copy-mode test fixtures deliberately carry only the gate shim.
    # They cannot launch real reviewer children; preserve their synchronous
    # delegation contract while the installed CLI always loads this library.
    unset PM_GATE_PARENT_OPERATION
  fi

  if [[ "$lifecycle" == "detached" ]]; then
    local _detached_rc=0
    pmctl_gate_run_detached "$repo_root" "$effective_cd" ${_passthrough[@]+"${_passthrough[@]}"} || _detached_rc=$?
    if [[ "$_detached_rc" -ne 0 && -n "${PM_GATE_PARENT_OPERATION:-}" ]]; then
      # The launcher can fail before the supervisor starts — missing gate
      # script, unresolvable run dir, readiness timeout — so the parent created
      # above may own no child at all.  That is a known producer failure, not an
      # abandoned operation: terminalize it here, exactly as the foreground path
      # does, instead of leaving a `running` record for doctor to report.
      pmctl_operation_fail_if_childless "$repo_root" gate "$PM_GATE_PARENT_OPERATION" "$effective_cd" >&2 || true
    fi
    return "$_detached_rc"
  fi

  # Compute an out-of-repo run dir via sw_project_run_dir (state-paths seam).
  # Partition key is derived from effective_cd so artifacts land under the target
  # repo's partition even when pmctl is invoked from a different directory.
  # Guarded source: load only if sw_project_run_dir is not already declared.
  local gate_run_dir=""
  local _sp_lib="$repo_root/runtime/lib/state-paths.sh"
  if [[ "$(type -t sw_project_run_dir 2>/dev/null)" != function && -r "$_sp_lib" ]]; then
    # shellcheck disable=SC1090,SC1091
    . "$_sp_lib" 2>/dev/null || true
  fi
  if [[ "$(type -t sw_project_run_dir 2>/dev/null)" == function ]]; then
    local _gate_ts; _gate_ts="$(date +%Y%m%d-%H%M%S)"
    local _gate_run_id="gate-${_gate_ts}-$$"
    gate_run_dir="$(cd "$effective_cd" 2>/dev/null && sw_project_run_dir "$_gate_run_id" 2>/dev/null)" || gate_run_dir=""
  fi

  local run_dir_args=()
  if [[ -n "$gate_run_dir" ]]; then
    run_dir_args=(--run-dir "$gate_run_dir")
  fi

  # Keep the producer process alive after the synchronous gate returns so the
  # parent operation is converged from trusted child terminal claims.  `exec`
  # here used to strand every foreground gate in `running` forever.
  local _gate_rc=0 _reconcile_rc=0
  local -a _foreground_args=("${run_dir_args[@]}")
  if [[ "$has_cd" == false ]]; then
    _foreground_args+=(--cd "$effective_cd" "$@")
  else
    _foreground_args+=("$@")
  fi
  if [[ -n "${PM_GATE_PARENT_OPERATION:-}" ]]; then
    if ! command -v setsid >/dev/null 2>&1; then
      printf 'pmctl gate run: foreground producer isolation requires setsid; gate was not started\n' >&2
      pmctl_operation_fail_if_childless "$repo_root" gate "$PM_GATE_PARENT_OPERATION" "$effective_cd" >&2 || true
      return 2
    fi
    # Keep the synchronous user experience while isolating the complete gate
    # producer tree from the invoking shell.  The new session registers its
    # own kernel identity before execing pr-gate.sh; cancellation can therefore
    # stop preflight/timeout descendants without accepting a caller-supplied PID.
    # shellcheck disable=SC2016 # variables are expanded by the spawned bash, not this shell.
    setsid bash -c '
      repo_root="$1"; work_dir="$2"; operation_id="$3"; gate_script="$4"
      shift 4
      # shellcheck source=/dev/null
      . "$repo_root/runtime/lib/pmctl-operation.sh"
      register_rc=0
      pmctl_operation_register_producer "$repo_root" gate "$operation_id" "$work_dir" "$BASHPID" \
        || register_rc=$?
      if [[ "$register_rc" -eq 130 ]]; then
        exit 130
      fi
      if [[ "$register_rc" -ne 0 ]]; then
        printf "pmctl gate run: failed to register foreground producer identity for %s\n" \
          "$operation_id" >&2
        exit 2
      fi
      exec "$gate_script" "$@"
    ' _ "$repo_root" "$effective_cd" "$PM_GATE_PARENT_OPERATION" "$gate_script" \
      "${_foreground_args[@]}" &
    local _producer_pid=$!
    wait "$_producer_pid" || _gate_rc=$?
  else
    "$gate_script" "${_foreground_args[@]}" || _gate_rc=$?
  fi
  if [[ -n "${PM_GATE_PARENT_OPERATION:-}" ]]; then
    if pmctl_operation_cancellation_requested "$repo_root" gate \
      "$PM_GATE_PARENT_OPERATION" "$effective_cd"; then
      if [[ "${PMCTL_OPERATION_CANCELLATION_STATE:-}" == indeterminate ]]; then
        printf 'pmctl gate run: operation %s cancellation is indeterminate; inspect operation evidence (exit 2)\n' \
          "$PM_GATE_PARENT_OPERATION" >&2
        return 2
      fi
      printf 'pmctl gate run: operation %s cancelled; foreground producer stopped (exit 130)\n' \
        "$PM_GATE_PARENT_OPERATION" >&2
      return 130
    fi
    pmctl_operation_reconcile "$repo_root" gate "$PM_GATE_PARENT_OPERATION" --cd "$effective_cd" >&2 || _reconcile_rc=$?
    if [[ "$_reconcile_rc" -ne 0 ]]; then
      # A pre-flight failure can legitimately have no reviewer child.  It is a
      # known producer failure, not an ambiguous abandoned operation.
      pmctl_operation_fail_if_childless "$repo_root" gate "$PM_GATE_PARENT_OPERATION" "$effective_cd" >&2 || true
      _reconcile_rc=0
      pmctl_operation_reconcile "$repo_root" gate "$PM_GATE_PARENT_OPERATION" --cd "$effective_cd" >&2 || _reconcile_rc=$?
    fi
    if [[ "$_reconcile_rc" -ne 0 ]]; then
      printf 'pmctl gate run: warning: parent operation %s could not be reconciled; preserving gate verdict exit %s\n' "$PM_GATE_PARENT_OPERATION" "$_gate_rc" >&2
      return "$_gate_rc"
    fi
  fi
  return "$_gate_rc"
}

# Detached lifecycle launcher for `pmctl gate run --lifecycle detached`,
# mirroring pmctl_dispatch_run_detached: generate a gate_id, compute its run
# dir the SAME way `pmctl gate wait <gate_id>` will independently recompute it
# later (via sw_project_run_dir), launch runtime/bin/gate-supervisor.sh under
# setsid/nohup, prove supervisor readiness, and only then return the gate_id.
#
# runtime/bin/pr-gate.sh is a trusted in-repo script (not an arbitrary untrusted
# executor/brief), so unlike dispatch this path skips adapter/guard preflight
# — the supervisor is a thin detach+sentinel wrapper around the same
# runtime/bin/pr-gate.sh invocation the foreground path already execs.
pmctl_gate_run_detached() {
  local repo_root="$1" effective_cd="$2"; shift 2
  local -a forward=("$@")
  local _ready_timeout="${PM_GATE_READY_TIMEOUT:-5}"

  if ! [[ "$_ready_timeout" =~ ^[1-9][0-9]*$ ]]; then
    printf 'pmctl gate run: invalid PM_GATE_READY_TIMEOUT %q (expected positive seconds)\n' "$_ready_timeout" >&2
    return 2
  fi

  if [[ "$(type -t detached_launch_generate_nonce 2>/dev/null)" != function ]]; then
    local _dl_lib="$repo_root/runtime/lib/detached-launch.sh"
    if [[ -r "$_dl_lib" ]]; then
      # shellcheck disable=SC1090,SC1091
      . "$_dl_lib" 2>/dev/null || true
    fi
  fi

  local gate_script="$repo_root/runtime/bin/gate-supervisor.sh"
  if [[ ! -x "$gate_script" ]]; then
    printf 'pmctl gate run: gate-supervisor.sh not found or not executable: %s\n' "$gate_script" >&2
    return 2
  fi

  # sw_project_run_dir is required in detached mode (no in-repo fallback):
  # `pmctl gate wait` must independently recompute the identical run dir
  # later with no separate record store, so a silent fallback here would make
  # that recompute diverge.
  if ! _pmctl_gate_ensure_run_dir_fn "$repo_root"; then
    printf 'pmctl gate run: --lifecycle detached requires runtime/lib/state-paths.sh (sw_project_run_dir unavailable)\n' >&2
    return 2
  fi

  local gate_id
  gate_id="gate-$(date -u +%Y%m%d-%H%M%S 2>/dev/null || date +%Y%m%d-%H%M%S)-$(_pmctl_gate_hex6)"

  local gate_run_dir
  gate_run_dir="$(cd "$effective_cd" 2>/dev/null && sw_project_run_dir "$gate_id" 2>/dev/null)" || gate_run_dir=""
  if [[ -z "$gate_run_dir" ]]; then
    printf 'pmctl gate run: failed to resolve run dir for %s (--cd %s)\n' "$gate_id" "$effective_cd" >&2
    return 2
  fi
  if ! mkdir -p "$gate_run_dir"; then
    printf 'pmctl gate run: mkdir failed: %s\n' "$gate_run_dir" >&2
    return 2
  fi

  # Nonce-authenticated sentinel: the key file lives in a per-user private
  # directory (mode 700) so only the owning user can read the nonce, and the
  # nonce is passed to the supervisor via env (never written to a
  # workspace-readable file), mirroring pmctl_dispatch_run_detached.
  local _nonce _key_file _key_dir
  _nonce="$(detached_launch_generate_nonce)"
  _key_file="$(_pmctl_gate_sentinel_key_file "$gate_id")"
  _key_dir="$(dirname "$_key_file")"
  detached_launch_secure_key_dir "$_key_dir"
  case "$?" in
    0) : ;;
    1) printf 'pmctl gate run: failed to create private key directory: %s\n' "$_key_dir" >&2; return 2 ;;
    2) printf 'pmctl gate run: failed to secure private key directory (not owner?): %s\n' "$_key_dir" >&2; return 2 ;;
    3) printf 'pmctl gate run: refusing key directory not owned by current user: %s\n' "$_key_dir" >&2; return 2 ;;
  esac
  detached_launch_write_key_file "$_key_file" "$_nonce" || {
    printf 'pmctl gate run: failed to write sentinel key file\n' >&2
    return 2
  }

  local supervisor_log="$gate_run_dir/supervisor.log" supervisor_pid_file="$gate_run_dir/supervisor.pid"
  local supervisor_identity="$gate_run_dir/supervisor.identity"
  local ready_sentinel terminal_sentinel
  ready_sentinel="$(detached_launch_sentinel_path "pm-gate-ready" "$gate_id" "$_nonce")"
  terminal_sentinel="$(detached_launch_sentinel_path "pm-gate" "$gate_id" "$_nonce")"
  if ! PM_GATE_SUPERVISOR_NONCE="$_nonce" detached_launch_under_setsid \
    "$gate_script" "$supervisor_log" "$supervisor_pid_file" \
    -- --gate-id "$gate_id" --cd "$effective_cd" --run-dir "$gate_run_dir" -- ${forward[@]+"${forward[@]}"}; then
    printf 'pmctl gate run: failed to launch detached supervisor for %s\n' "$gate_id" >&2
    return 2
  fi

  # A command sandbox with parent-death semantics can allow setsid/nohup to
  # fork and then immediately reap the descendant as this launcher exits.
  # Capture the launched process and require a nonce-authenticated ready
  # record before claiming success, rather than misleading the caller with a
  # gate ID that can only time out.
  local _sup_pid _isolated="${DETACHED_LAUNCH_ISOLATED:-0}"
  _sup_pid="$(tr -d ' \n' <"$supervisor_pid_file" 2>/dev/null || true)"
  if ! [[ "$_sup_pid" =~ ^[0-9]+$ ]]; then
    printf 'pmctl gate run: detached supervisor failed before PID capture for %s; inspect %s and retry with --lifecycle foreground (sandbox parent-death may prevent detached runs)\n' \
      "$gate_id" "$supervisor_log" >&2
    return 2
  fi
  # A short gate can publish ready + terminal evidence before the launcher gets
  # its first /proc snapshot. Capture identity eagerly when possible, but do
  # not reject that already-complete, authenticated lifecycle solely because
  # the supervisor has exited in the intervening scheduling window.
  detached_launch_capture_identity "$_sup_pid" "$_isolated" >"$supervisor_identity" 2>/dev/null || true

  local _ready_start _ready_state _ready_pid _ready_starttime _ready_rc
  _ready_start=$SECONDS
  while true; do
    if [[ -f "$ready_sentinel" ]]; then
      _ready_state="$(grep -m1 '^state=' "$ready_sentinel" 2>/dev/null | cut -d= -f2-)" || _ready_state=""
      _ready_pid="$(grep -m1 '^pid=' "$ready_sentinel" 2>/dev/null | cut -d= -f2-)" || _ready_pid=""
      _ready_starttime="$(grep -m1 '^starttime=' "$ready_sentinel" 2>/dev/null | cut -d= -f2-)" || _ready_starttime=""
      if [[ ! -f "$supervisor_identity" ]]; then
        detached_launch_capture_identity "$_sup_pid" "$_isolated" >"$supervisor_identity" 2>/dev/null || true
      fi
      if detached_launch_load_identity_file "$supervisor_identity" \
        && [[ "$_ready_state" == "ready" && "$_ready_pid" == "$DL_ID_PID" && "$_ready_starttime" == "$DL_ID_STARTTIME" ]]; then
        # A very fast gate can already be terminal by the time the launcher
        # observes readiness. Its captured PID/starttime still proves the
        # ready supervisor was the one we launched; requiring it to remain
        # alive would reject a valid completed gate.
        break
      fi
      # The readiness path is nonce-authenticated and must name the launched
      # PID. If the supervisor already terminalized, that pair is durable
      # proof of a completed, waitable gate even when no parent-side /proc
      # snapshot could survive the scheduling race.
      if [[ "$_ready_state" == "ready" && "$_ready_pid" == "$_sup_pid" \
        && "$_ready_starttime" =~ ^[0-9]+$ && -f "$terminal_sentinel" ]]; then
        break
      fi
      if [[ "$_ready_state" == "ready" && "$_ready_pid" == "$_sup_pid" \
        && "$_ready_starttime" =~ ^[0-9]+$ ]] && kill -0 "$_sup_pid" 2>/dev/null; then
        # A live supervisor may be between ready publication and terminal
        # publication while the parent-side snapshot is unavailable; keep the
        # bounded readiness poll rather than treating that valid transition as
        # an identity mismatch.
        sleep 0.05
        continue
      fi
      printf 'pmctl gate run: invalid supervisor readiness evidence for %s; inspect %s and retry with --lifecycle foreground\n' \
        "$gate_id" "$supervisor_log" >&2
      return 2
    fi
    if [[ -f "$supervisor_identity" ]] \
      && detached_launch_verify_identity "$_sup_pid" "$supervisor_identity"; then
      _ready_rc=0
    else
      # The child can publish ready + terminal after the parent's first
      # identity snapshot, then exit before this liveness check. A loaded host
      # can also delay the separately scheduled supervisor after the launch
      # PID stops being observable. The configured readiness timeout owns that
      # whole evidence window; a fixed sub-second poll count would turn normal
      # scheduler latency into a false early-death result.
      _ready_rc=1
    fi
    if (( SECONDS - _ready_start >= _ready_timeout )); then
      if [[ "$_ready_rc" -ne 0 ]]; then
        printf 'pmctl gate run: detached supervisor exited before readiness for %s; inspect %s and retry with --lifecycle foreground (sandbox parent-death may prevent detached runs)\n' \
          "$gate_id" "$supervisor_log" >&2
      else
        printf 'pmctl gate run: detached supervisor did not become ready within %ss for %s; inspect %s and retry with --lifecycle foreground\n' \
          "$_ready_timeout" "$gate_id" "$supervisor_log" >&2
      fi
      return 2
    fi
    sleep 0.05
  done

  # stdout stays a single gate_id line — existing callers capture it with
  # command substitution. The ready-to-paste wait command goes to stderr so
  # a human never has to assemble id + --cd by hand.
  printf 'pmctl gate run: detached; check the verdict with: pmctl gate wait %s --cd %q\n' \
    "$gate_id" "$effective_cd" >&2
  printf '%s\n' "$gate_id"
  return 0
}

# pmctl gate wait <gate_id> [--cd <work_dir>] [--timeout N]
# Polls for the nonce-authenticated sentinel runtime/bin/gate-supervisor.sh writes
# on completion, mirroring pmctl_dispatch_wait. --cd defaults to the CWD git
# toplevel (then $PWD) via _pmctl_gate_default_cd — the same derivation
# `pmctl gate run` uses — so run/wait recompute the identical partition.
# On a verified GO/NO-GO the result file's `Final:` line is echoed to stdout.
# Exit codes are layered: 0 = GO, 1 = NO-GO (a gate verdict, not an execution
# error), 2 = usage/result-integrity error, 3 = indeterminate (sentinel key
# absent — never silently reports success), 124 = timeout.
pmctl_gate_wait() {
  local repo_root="${1:-}"
  shift || true
  local gate_id="" work_dir="" timeout="${PM_GATE_WAIT_DEFAULT_TIMEOUT:-1200}"

  if [[ "$(type -t detached_launch_wait_for_sentinel 2>/dev/null)" != function ]]; then
    local _dl_lib="$repo_root/runtime/lib/detached-launch.sh"
    if [[ -r "$_dl_lib" ]]; then
      # shellcheck disable=SC1090,SC1091
      . "$_dl_lib" 2>/dev/null || true
    fi
  fi

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --cd)
        if [[ $# -lt 2 ]]; then
          printf 'pmctl gate wait: missing value for --cd\n' >&2
          return 2
        fi
        if declare -F _portable_canonical_path >/dev/null 2>&1; then
          work_dir="$(_portable_canonical_path "$2")"
        else
          work_dir="$2"
        fi
        shift 2
        ;;
      --timeout)
        if [[ $# -lt 2 ]]; then
          printf 'pmctl gate wait: missing value for --timeout\n' >&2
          return 2
        fi
        if ! [[ "$2" =~ ^[0-9]+$ ]]; then
          printf 'pmctl gate wait: invalid --timeout %q (expected seconds)\n' "$2" >&2
          return 2
        fi
        timeout="$2"
        shift 2
        ;;
      --*)
        printf 'pmctl gate wait: unknown option %s\n' "$1" >&2
        return 2
        ;;
      *)
        if [[ -n "$gate_id" ]]; then
          printf 'pmctl gate wait: unexpected argument %s\n' "$1" >&2
          return 2
        fi
        gate_id="$1"
        shift
        ;;
    esac
  done

  if [[ -z "$gate_id" ]]; then
    printf 'pmctl gate wait: <gate_id> is required\n' >&2
    return 2
  fi
  if ! [[ "$gate_id" =~ ^gate-[0-9]{8}-[0-9]{6}-[A-Za-z0-9]{6,}$ ]]; then
    printf 'pmctl gate wait: invalid gate_id %q\n' "$gate_id" >&2
    return 2
  fi
  if [[ -z "$work_dir" ]]; then
    work_dir="$(_pmctl_gate_default_cd)"
    if declare -F _portable_canonical_path >/dev/null 2>&1; then
      work_dir="$(_portable_canonical_path "$work_dir")"
    fi
  fi

  local _key_file _key_nonce
  _key_file="$(_pmctl_gate_sentinel_key_file "$gate_id")"
  if [[ ! -f "$_key_file" ]]; then
    # Sentinel key absent: either already consumed by a prior wait, cleaned up
    # by reboot/tmpwatch, or never created. There is no authenticated
    # completion signal without it — never treat this as success.
    printf 'pmctl gate wait: indeterminate: sentinel key absent; completion is unverified for %s (exit=3)\n' "$gate_id" >&2
    return 3
  fi
  _key_nonce="$(cat "$_key_file" 2>/dev/null)" || _key_nonce=""
  if [[ -z "$_key_nonce" ]]; then
    printf 'pmctl gate wait: empty sentinel key for %s\n' "$gate_id" >&2
    return 2
  fi

  local _sentinel _ready_sentinel
  _sentinel="$(detached_launch_sentinel_path "pm-gate" "$gate_id" "$_key_nonce")"
  _ready_sentinel="$(detached_launch_sentinel_path "pm-gate-ready" "$gate_id" "$_key_nonce")"
  if detached_launch_wait_for_sentinel "$_sentinel" "$timeout" "${PM_GATE_WAIT_POLL_INTERVAL:-2}"; then
      local _state _exit _result
      _state="$(grep -m1 '^final_state=' "$_sentinel" 2>/dev/null | cut -d= -f2-)" || true
      _exit="$(grep -m1 '^exit_code=' "$_sentinel" 2>/dev/null | cut -d= -f2-)" || true
      _result="$(grep -m1 '^result_file=' "$_sentinel" 2>/dev/null | cut -d= -f2-)" || true
      _operation="$(grep -m1 '^parent_operation=' "$_sentinel" 2>/dev/null | cut -d= -f2-)" || true
      rm -f "$_sentinel" "$_ready_sentinel" "$_key_file" 2>/dev/null || true
      [[ "$_exit" =~ ^-?[0-9]+$ ]] || _exit="1"
      printf 'gate: %s  state: %s  exit: %s\n' "$gate_id" "${_state:-unknown}" "$_exit"
      if [[ -n "$_result" ]]; then
        printf 'result: %s\n' "$_result"
      fi
      # A GO/NO-GO sentinel is only trustworthy if its result file exists,
      # falls under the run dir --cd actually owns, and passes the SAME
      # structural check the synchronous route enforces in-process
      # (gate_result_verify). Without this, a wait that completes while the
      # result is missing/corrupt/unparsable/foreign would report success
      # (exit 0/1) on an outcome nobody can actually confirm -- fail-closed
      # instead: treat integrity failure as a failed wait (exit 2), distinct
      # from a genuine NO-GO (exit 1).
      if [[ "${_state:-}" == "GO" || "${_state:-}" == "NO-GO" ]]; then
        if [[ -z "$_result" ]]; then
          printf 'pmctl gate wait: FAIL: state %s reported but the sentinel recorded no result file -- treating as failed wait (result integrity cannot be confirmed)\n' "$_state" >&2
          return 2
        fi
        # --cd binds this wait to a specific project partition: recompute the
        # SAME gate_run_dir pmctl_gate_run_detached derived at launch time
        # (via sw_project_run_dir) and require the sentinel's result path to
        # fall under it. A gate_id is only reachable by someone who already
        # holds its sentinel key (per-user, mode 700), so this is not a
        # security boundary -- it is what makes --cd load-bearing rather than
        # cosmetic: a caller waiting under the wrong --cd gets a clear
        # mismatch error instead of a silently-trusted foreign-partition path.
        _pmctl_gate_ensure_run_dir_fn "$repo_root" || true
        if [[ "$(type -t sw_project_run_dir 2>/dev/null)" == function ]]; then
          local _expected_run_dir
          _expected_run_dir="$(cd "$work_dir" 2>/dev/null && sw_project_run_dir "$gate_id" 2>/dev/null)" || _expected_run_dir=""
          if [[ -n "$_expected_run_dir" && "$_result" != "$_expected_run_dir"/* ]]; then
            printf 'pmctl gate wait: FAIL: result %s does not fall under the run dir for %s under --cd %s (%s) -- wrong --cd for this gate_id?\n' \
              "$_result" "$gate_id" "$work_dir" "$_expected_run_dir" >&2
            return 2
          fi
        fi
        if ! _pmctl_gate_result_verifier_load "$repo_root"; then
          printf 'pmctl gate wait: FAIL: gate_result_verify unavailable -- cannot confirm result integrity for %s, treating as failed wait\n' "$_result" >&2
          return 2
        fi
        if ! gate_result_verify "$_result" >/dev/null 2>&1; then
          printf 'pmctl gate wait: FAIL: gate_result_verify rejected %s -- result is missing/corrupt/unparsable, treating as failed wait\n' "$_result" >&2
          return 2
        fi
        # Verdict summary: echo the result file's `Final:` line verbatim —
        # the source of truth callers should read instead of the exit code,
        # which background-task harnesses render as a bare "command failed".
        local _final_line
        _final_line="$(grep -m1 -E '^Final: (GO|NO-GO)$' "$_result" 2>/dev/null)" || _final_line=""
        if [[ -n "$_final_line" ]]; then
          printf '%s\n' "$_final_line"
        fi
        if [[ "$_state" == "NO-GO" ]]; then
          printf 'pmctl gate wait: NO-GO is the gate verdict (exit 1), not an execution error; findings are in the result file above\n' >&2
        fi
      fi
      if [[ -n "${_operation:-}" ]]; then
        local _reconcile_rc=0
        if ! _pmctl_gate_operation_ensure_loaded "$repo_root" \
          || ! pmctl_operation_reconcile "$repo_root" gate "$_operation" --cd "$work_dir" >&2; then
          _reconcile_rc=$?
          pmctl_operation_fail_if_childless "$repo_root" gate "$_operation" "$work_dir" >&2 || true
          _reconcile_rc=0
          pmctl_operation_reconcile "$repo_root" gate "$_operation" --cd "$work_dir" >&2 || _reconcile_rc=$?
        fi
        if [[ "$_reconcile_rc" -ne 0 ]]; then
          printf 'pmctl gate wait: parent operation %s could not be reconciled from trusted child evidence\n' "$_operation" >&2
          return "$_exit"
        fi
      fi
      return "$_exit"
  fi
  printf 'pmctl gate wait: timed out after %ss waiting for %s in %s\n' "$timeout" "$gate_id" "$work_dir" >&2
  # A timeout is only meaningful after authenticated startup evidence.  Without
  # it the supervisor never became ready; with it but a dead recorded identity,
  # it died after launch.  Keep those failures distinct from a live gate that
  # merely exceeded the caller's wait budget.
  local _wait_run_dir _wait_identity _wait_liveness
  if [[ ! -f "$_ready_sentinel" ]]; then
    printf 'pmctl gate wait: indeterminate: %s never reached supervisor readiness; detached launch did not start a waitable gate (exit=3)\n' "$gate_id" >&2
    return 3
  fi
  _pmctl_gate_ensure_run_dir_fn "$repo_root" || true
  if [[ "$(type -t sw_project_run_dir 2>/dev/null)" == function ]]; then
    _wait_run_dir="$(cd "$work_dir" 2>/dev/null && sw_project_run_dir "$gate_id" 2>/dev/null)" || _wait_run_dir=""
    _wait_identity="${_wait_run_dir:+$_wait_run_dir/supervisor.identity}"
    if [[ -n "$_wait_identity" && -f "$_wait_identity" ]]; then
      if detached_launch_load_identity_file "$_wait_identity" && detached_launch_verify_identity "$DL_ID_PID" "$_wait_identity"; then
        _wait_liveness="alive"
      else
        _wait_liveness="dead"
      fi
      if [[ "$_wait_liveness" == "dead" ]]; then
        printf 'pmctl gate wait: indeterminate: %s reached readiness but its supervisor died without terminal evidence (exit=3)\n' "$gate_id" >&2
        return 3
      fi
    fi
  fi
  # shellcheck disable=SC2016  # literal markdown backticks in the format string, not a command substitution
  printf 'pmctl gate wait: the gate may still be running detached; retry `pmctl gate wait %s --cd %s`, or inspect `pmctl artifacts show %s --cd %s` for the supervisor log\n' \
    "$gate_id" "$work_dir" "$gate_id" "$work_dir" >&2
  return 124
}

# pmctl gate verify <result_file>
# Confirm a gate result file is structurally complete using the SAME contract
# the synchronous gate route enforces in-process (gate_result_verify). This is
# how an out-of-process gate result -- one written outside pr-gate.sh's own
# in-process check -- becomes confirmable/trackable via pmctl, symmetric to the
# codex route's built-in post-dispatch check. Exit 0 = valid; 1 = invalid (diagnostic on stderr);
# 2 = usage/library error.
pmctl_gate_verify() {
  local repo_root="$1"; shift

  if [[ $# -ne 1 || -z "${1:-}" ]]; then
    printf 'pmctl gate verify: usage: pmctl gate verify <result_file>\n' >&2
    return 2
  fi
  local result_file="$1"
  local evidence_status attestation_pointer result_parent run_root run_id
  local attestation_file runs_file canonical_repo_root assurance_repo_root
  local canonical_run_root

  if ! _pmctl_gate_result_verifier_load "$repo_root"; then
    printf 'pmctl gate verify: required verifier library is missing or incomplete: %s\n' \
      "$repo_root/runtime/lib/gate-result-verify.sh" >&2
    return 2
  fi

  _pmctl_gate_wait_for_assurance_publication "$result_file"
  if gate_result_verify "$result_file"; then
    evidence_status="$(jq -r '.coordinates.independence.evidence_status // "unavailable"' \
      "${GATE_RESULT_ASSURANCE_FILE:-/dev/null}" 2>/dev/null || printf 'unavailable')"
    if [[ "${GATE_RESULT_ASSURANCE:-unavailable}" == verified \
        && "$evidence_status" == verified ]]; then
      attestation_pointer="$(jq -r '.provenance.attestation // empty' \
        "$GATE_RESULT_ASSURANCE_FILE" 2>/dev/null)"
      if [[ -z "$attestation_pointer" || "$attestation_pointer" == */* \
          || ! "$attestation_pointer" =~ ^gate-assurance-[0-9]{8}-[0-9]{6}\.attestation\.json$ ]]; then
        printf 'Error: verified gate assurance requires a bounded protected attestation pointer\n' >&2
        return 1
      fi
      result_parent="$(cd "$(dirname "$result_file")" && pwd -P)" || return 1
      if [[ "$(basename "$result_parent")" != ".gate-results" ]]; then
        printf 'Error: verified gate assurance result is outside a canonical gate run directory\n' >&2
        return 1
      fi
      run_root="$(dirname "$result_parent")"
      run_id="$(basename "$run_root")"
      canonical_repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" || {
        printf 'Error: verified gate assurance requires invocation from its repository\n' >&2
        return 1
      }
      canonical_repo_root="$(cd "$canonical_repo_root" && pwd -P)" || return 1
      assurance_repo_root="$(jq -r '.bindings.repo_root // empty' \
        "$GATE_RESULT_ASSURANCE_FILE" 2>/dev/null)"
      if [[ -z "$assurance_repo_root" || ! -d "$assurance_repo_root" \
          || "$(cd "$assurance_repo_root" && pwd -P)" != "$canonical_repo_root" ]]; then
        printf 'Error: verified gate assurance repository binding does not match the invoking repository\n' >&2
        return 1
      fi
      if ! _pmctl_gate_ensure_run_dir_fn "$repo_root"; then
        printf 'Error: verified gate assurance requires canonical state-path resolution\n' >&2
        return 2
      fi
      canonical_run_root="$(
        cd "$canonical_repo_root" || exit 1
        _SW_REPO_ROOT="$canonical_repo_root" sw_project_run_dir "$run_id"
      )" || return 1
      if [[ ! -d "$canonical_run_root" \
          || "$(cd "$canonical_run_root" && pwd -P)" != "$run_root" ]]; then
        printf 'Error: verified gate assurance result is outside the invoking repository canonical state partition\n' >&2
        return 1
      fi
      attestation_file="$run_root/$attestation_pointer"
      runs_file="$(dirname "$(dirname "$canonical_run_root")")/runs.jsonl"
      gate_assurance_authorization_verify "$result_file" "$GATE_RESULT_ASSURANCE_FILE" \
        "$attestation_file" "$runs_file" || return $?
    fi
    printf 'gate result OK: %s\n' "$result_file"
    printf 'assurance: %s\n' "${GATE_RESULT_ASSURANCE:-unavailable}"
    if [[ -n "${GATE_RESULT_ASSURANCE_FILE:-}" ]]; then
      printf 'assurance file: %s\n' "$GATE_RESULT_ASSURANCE_FILE"
    fi
    return 0
  fi
  return 1
}
