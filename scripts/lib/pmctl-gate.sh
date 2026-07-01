#!/usr/bin/env bash
# pmctl gate subcommand — routes gate runs through pmctl instead of directly
# calling scripts/pr-gate.sh.  The gate script remains the implementation;
# this shim adds --cd defaulting, run-dir partitioning, and (CC-423) an
# opt-in detached lifecycle mirroring `pmctl dispatch run --lifecycle detached`.

# 6 random hex chars, used to make generated gate ids unguessable/unique.
# Deliberately self-contained (not reused from pmctl-dispatch.sh) so
# scripts/test-pmctl-gate.sh and scripts/test-gate-lifecycle.sh can source
# pmctl-gate.sh standalone, as the existing test fixtures already do.
_pmctl_gate_hex6() {
  local hex
  hex="$(dd if=/dev/urandom bs=3 count=1 2>/dev/null | od -An -tx1 | tr -d ' \n')"
  printf '%s\n' "${hex:0:6}"
}

# Per-user private key-file directory for the detached-gate sentinel nonce,
# mirroring _pmctl_sentinel_key_file in pmctl-dispatch.sh but rooted at a
# separate /tmp namespace so gate and dispatch sentinels never collide.
_pmctl_gate_sentinel_key_file() {
  local _gate_id="${1:-}" _uid _key_dir
  _uid="$(id -u 2>/dev/null)" || _uid="0"
  if [[ -n "${XDG_RUNTIME_DIR:-}" && -d "${XDG_RUNTIME_DIR}" ]]; then
    _key_dir="${XDG_RUNTIME_DIR}/pm-gate-dispatch"
  else
    _key_dir="/tmp/pm-gate-dispatch-${_uid}"
  fi
  printf '%s/%s' "$_key_dir" "$_gate_id"
}

pmctl_gate_run() {
  local repo_root="$1"; shift

  local gate_script="$repo_root/scripts/pr-gate.sh"
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
      exec "$gate_script" "$@"
    fi
  done

  # Extract --cd value first so the run dir is keyed to the TARGET repo's partition,
  # not the caller's cwd. Fall back to $PWD when --cd is absent.
  local effective_cd="$PWD"
  local has_cd=false
  local _i=0
  local _args=("$@")
  while [[ "$_i" -lt "${#_args[@]}" ]]; do
    if [[ "${_args[$_i]}" == "--cd" ]]; then
      has_cd=true
      _i=$((_i + 1))
      [[ "$_i" -lt "${#_args[@]}" ]] && effective_cd="${_args[$_i]}"
      break
    fi
    _i=$((_i + 1))
  done

  if [[ "$lifecycle" == "detached" ]]; then
    # Native forward args for the supervisor exclude --cd: the supervisor
    # receives effective_cd as a trusted scalar and forwards it to
    # pr-gate.sh itself (mirrors dispatch's cd_arg/native split).
    local -a _native=()
    local _j=0
    local _cargs=("$@")
    while [[ "$_j" -lt "${#_cargs[@]}" ]]; do
      if [[ "${_cargs[$_j]}" == "--cd" ]]; then
        _j=$((_j + 2))
      else
        _native+=("${_cargs[$_j]}")
        _j=$((_j + 1))
      fi
    done
    pmctl_gate_run_detached "$repo_root" "$effective_cd" ${_native[@]+"${_native[@]}"}
    return $?
  fi

  # Compute an out-of-repo run dir via sw_project_run_dir (state-paths seam).
  # Partition key is derived from effective_cd so artifacts land under the target
  # repo's partition even when pmctl is invoked from a different directory.
  # Guarded source: load only if sw_project_run_dir is not already declared.
  local gate_run_dir=""
  local _sp_lib="$repo_root/scripts/lib/state-paths.sh"
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

  if [[ "$has_cd" == false ]]; then
    exec "$gate_script" "${run_dir_args[@]}" --cd "$PWD" "$@"
  else
    exec "$gate_script" "${run_dir_args[@]}" "$@"
  fi
}

# Detached lifecycle launcher for `pmctl gate run --lifecycle detached`,
# mirroring pmctl_dispatch_run_detached: generate a gate_id, compute its run
# dir the SAME way `pmctl gate wait <gate_id>` will independently recompute it
# later (via sw_project_run_dir), launch scripts/gate-supervisor.sh under
# setsid/nohup, and return the gate_id immediately.
#
# scripts/pr-gate.sh is a trusted in-repo script (not an arbitrary untrusted
# executor/brief), so unlike dispatch this path skips adapter/guard preflight
# — the supervisor is a thin detach+sentinel wrapper around the same
# scripts/pr-gate.sh invocation the foreground path already execs.
pmctl_gate_run_detached() {
  local repo_root="$1" effective_cd="$2"; shift 2
  local -a forward=("$@")

  local gate_script="$repo_root/scripts/gate-supervisor.sh"
  if [[ ! -x "$gate_script" ]]; then
    printf 'pmctl gate run: gate-supervisor.sh not found or not executable: %s\n' "$gate_script" >&2
    return 2
  fi

  # sw_project_run_dir is required in detached mode (no in-repo fallback):
  # `pmctl gate wait` must independently recompute the identical run dir
  # later with no separate record store, so a silent fallback here would make
  # that recompute diverge.
  local _sp_lib="$repo_root/scripts/lib/state-paths.sh"
  if [[ "$(type -t sw_project_run_dir 2>/dev/null)" != function && -r "$_sp_lib" ]]; then
    # shellcheck disable=SC1090,SC1091
    . "$_sp_lib" 2>/dev/null || true
  fi
  if [[ "$(type -t sw_project_run_dir 2>/dev/null)" != function ]]; then
    printf 'pmctl gate run: --lifecycle detached requires scripts/lib/state-paths.sh (sw_project_run_dir unavailable)\n' >&2
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
  _nonce="$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom 2>/dev/null | head -c 32 2>/dev/null)" \
    || _nonce="${RANDOM}${RANDOM}${RANDOM}"
  [[ -n "$_nonce" ]] || _nonce="${RANDOM}${RANDOM}${RANDOM}"
  _key_file="$(_pmctl_gate_sentinel_key_file "$gate_id")"
  _key_dir="$(dirname "$_key_file")"
  mkdir -p "$_key_dir" 2>/dev/null || {
    printf 'pmctl gate run: failed to create private key directory: %s\n' "$_key_dir" >&2
    return 2
  }
  chmod 700 "$_key_dir" 2>/dev/null || {
    printf 'pmctl gate run: failed to secure private key directory (not owner?): %s\n' "$_key_dir" >&2
    return 2
  }
  local _key_dir_owner
  _key_dir_owner="$(stat -c '%u' "$_key_dir" 2>/dev/null || stat -f '%u' "$_key_dir" 2>/dev/null || true)"
  if [[ -n "$_key_dir_owner" && "$_key_dir_owner" != "$(id -u)" ]]; then
    printf 'pmctl gate run: refusing key directory not owned by current user (owner uid=%s): %s\n' "$_key_dir_owner" "$_key_dir" >&2
    return 2
  fi
  printf '%s' "$_nonce" > "$_key_file" 2>/dev/null || {
    printf 'pmctl gate run: failed to write sentinel key file\n' >&2
    return 2
  }

  local supervisor_log="$gate_run_dir/supervisor.log"
  if command -v setsid >/dev/null 2>&1; then
    PM_GATE_SUPERVISOR_NONCE="$_nonce" setsid nohup bash "$gate_script" \
      --gate-id "$gate_id" --cd "$effective_cd" --run-dir "$gate_run_dir" -- ${forward[@]+"${forward[@]}"} \
      </dev/null >"$supervisor_log" 2>&1 &
  else
    PM_GATE_SUPERVISOR_NONCE="$_nonce" nohup bash "$gate_script" \
      --gate-id "$gate_id" --cd "$effective_cd" --run-dir "$gate_run_dir" -- ${forward[@]+"${forward[@]}"} \
      </dev/null >"$supervisor_log" 2>&1 &
    disown $! 2>/dev/null || true
  fi

  printf '%s\n' "$gate_id"
  return 0
}

# pmctl gate wait <gate_id> --cd <work_dir> [--timeout N]
# Polls for the nonce-authenticated sentinel scripts/gate-supervisor.sh writes
# on completion, mirroring pmctl_dispatch_wait. Absent sentinel key => exit 3
# (indeterminate) — never silently reports success. Returns the gate's real
# exit code (0=GO, 1=NO-GO, other=failed) on completion, 124 on timeout.
pmctl_gate_wait() {
  local repo_root="${1:-}"
  shift || true
  local gate_id="" work_dir="" timeout="${PM_GATE_WAIT_DEFAULT_TIMEOUT:-1200}"

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
    printf 'pmctl gate wait: --cd <work_dir> is required\n' >&2
    return 2
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

  local _sentinel="/tmp/pm-gate-sentinel-${gate_id}-${_key_nonce}"
  local start elapsed
  start="$SECONDS"
  while true; do
    if [[ -f "$_sentinel" ]]; then
      local _state _exit _result
      _state="$(grep -m1 '^final_state=' "$_sentinel" 2>/dev/null | cut -d= -f2-)" || true
      _exit="$(grep -m1 '^exit_code=' "$_sentinel" 2>/dev/null | cut -d= -f2-)" || true
      _result="$(grep -m1 '^result_file=' "$_sentinel" 2>/dev/null | cut -d= -f2-)" || true
      rm -f "$_sentinel" "$_key_file" 2>/dev/null || true
      [[ "$_exit" =~ ^-?[0-9]+$ ]] || _exit="1"
      printf 'gate: %s  state: %s  exit: %s\n' "$gate_id" "${_state:-unknown}" "$_exit"
      if [[ -n "$_result" ]]; then
        printf 'result: %s\n' "$_result"
      fi
      # A GO/NO-GO sentinel is only trustworthy if its result file exists and
      # passes the SAME structural check the synchronous route enforces
      # in-process (gate_result_verify). Without this, a wait that completes
      # while the result is missing/corrupt/unparsable would report success
      # (exit 0/1) on an outcome nobody can actually confirm -- fail-closed
      # instead: treat integrity failure as a failed wait (exit 2), distinct
      # from a genuine NO-GO (exit 1).
      if [[ "${_state:-}" == "GO" || "${_state:-}" == "NO-GO" ]]; then
        if [[ -z "$_result" ]]; then
          printf 'pmctl gate wait: FAIL: state %s reported but the sentinel recorded no result file -- treating as failed wait (result integrity cannot be confirmed)\n' "$_state" >&2
          return 2
        fi
        if ! declare -F gate_result_verify >/dev/null 2>&1; then
          local _gr_lib="$repo_root/scripts/lib/gate-result-verify.sh"
          if [[ -r "$_gr_lib" ]]; then
            # shellcheck disable=SC1090,SC1091
            . "$_gr_lib" 2>/dev/null || true
          fi
        fi
        if ! declare -F gate_result_verify >/dev/null 2>&1; then
          printf 'pmctl gate wait: FAIL: gate_result_verify unavailable -- cannot confirm result integrity for %s, treating as failed wait\n' "$_result" >&2
          return 2
        fi
        if ! gate_result_verify "$_result" >/dev/null 2>&1; then
          printf 'pmctl gate wait: FAIL: gate_result_verify rejected %s -- result is missing/corrupt/unparsable, treating as failed wait\n' "$_result" >&2
          return 2
        fi
      fi
      return "$_exit"
    fi
    elapsed=$((SECONDS - start))
    if (( elapsed >= timeout )); then
      printf 'pmctl gate wait: timed out after %ss waiting for %s in %s\n' "$timeout" "$gate_id" "$work_dir" >&2
      # shellcheck disable=SC2016  # literal markdown backticks in the format string, not a command substitution
      printf 'pmctl gate wait: the gate may still be running detached; retry `pmctl gate wait %s --cd %s`, or inspect `pmctl artifacts show %s --cd %s` for the supervisor log\n' \
        "$gate_id" "$work_dir" "$gate_id" "$work_dir" >&2
      return 124
    fi
    sleep "${PM_GATE_WAIT_POLL_INTERVAL:-2}"
  done
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

  if ! declare -F gate_result_verify >/dev/null; then
    local lib="$repo_root/scripts/lib/gate-result-verify.sh"
    if [[ ! -r "$lib" ]]; then
      printf 'pmctl gate verify: required library not found: %s\n' "$lib" >&2
      return 2
    fi
    # shellcheck source=scripts/lib/gate-result-verify.sh
    . "$lib"
  fi

  if gate_result_verify "$result_file"; then
    printf 'gate result OK: %s\n' "$result_file"
    return 0
  fi
  return 1
}
