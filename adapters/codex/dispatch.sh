#!/usr/bin/env bash
# codex-dispatch.sh
#
# Wrapper for invoking `codex exec` from Claude (PM → worker dispatch).
# Captures the final agent message and a full JSONL trace for later review.
# Bounds runtime with a timeout so a silent codex hang cannot block the caller
# indefinitely; logs wrapper start/end + codex stderr to a sibling .stderr file
# so failed dispatches leave forensic evidence; maintains a stable
# .agent-trace/latest.{jsonl,last,stderr} symlink set so observers can tail
# the most recent run without knowing the timestamp.
#
# Usage:
#   codex-dispatch.sh --cd <dir> [--model <m>] [--effort <low|medium|high>]
#                     [--sandbox <mode>]
#                     [--isolation <level>]
#                     [--approval <mode>] [--skip-git-check]
#                     [--timeout <seconds>] [--print-cmd]
#                     --brief-file <path>
#   codex-dispatch.sh --cd <dir> [--model <m>] [--effort <low|medium|high>]
#                     [--sandbox <mode>]
#                     [--isolation <level>]
#                     [--approval <mode>] [--skip-git-check]
#                     [--timeout <seconds>] [--print-cmd] -- <brief...>
#
# --print-cmd prints the final CMD array (`CMD=${CMD[*]}`) and exits 0
# before invoking codex.
#
# Prefer --brief-file for all real dispatches. The inline -- <brief...> form is
# retained only for trivial smoke checks; shell quoting, hook validation, and
# multiline briefs are much easier to get wrong inline.
#
# Defaults:
#   --sandbox  workspace-write   (read-only | workspace-write; danger-full-access
#                                 is REJECTED — codex full access is retired)
#   --isolation empty            (read-only | workspace-write | workspace-network |
#                                 sandboxed; `none` is REJECTED for codex)
#   --approval never             (never | on-failure | on-request | untrusted)
#   --effort   medium global default (low | medium | high; overrides the resolved
#              model alias's own effort column; see scripts/lib/reasoning-effort.sh)
#   --timeout  precedence (via pmctl): --timeout flag (wins) > CODEX_DISPATCH_TIMEOUT env >
#              PM_CFG_TIMEOUT (exported by pmctl from config) > 1200 default.
#              Direct adapter invocations: CODEX_DISPATCH_TIMEOUT env > 1200 default.
#
# Outputs:
#   .agent-trace/codex-<ts>.jsonl   full event stream (codex stdout)
#   .agent-trace/codex-<ts>.last    final agent message (--output-last-message)
#   .agent-trace/codex-<ts>.stderr  wrapper banner + codex stderr (forensic log)
#   .agent-trace/latest.jsonl       symlink → most recent .jsonl
#   .agent-trace/latest.last        symlink → most recent .last
#   .agent-trace/latest.stderr      symlink → most recent .stderr
#   stdout: brief summary + paths

set -euo pipefail

# Self-snapshot to avoid mid-flight modification when a dispatched Codex session
# edits this script (e.g. when the dispatch target is pm-dispatch itself).
# Bash reads scripts incrementally; rewriting the on-disk file under a running
# interpreter can corrupt the next read. We re-exec from a /tmp copy so the
# on-disk file is decoupled from the running process.
#
# Trigger: snapshot only when BASH_SOURCE looks like an on-disk script path,
# not when it already matches the mktemp snapshot pattern. Avoids relying on
# inherited env (which would let a polluted environment bypass the protection
# or trick a cleanup trap into deleting an arbitrary file).
if ! [[ "${BASH_SOURCE[0]}" =~ /codex-dispatch\.[A-Za-z0-9]{6}/codex-dispatch\.sh$ ]]; then
  __codex_dispatch_snapshot_dir="$(mktemp -d -t codex-dispatch.XXXXXX)"
  __codex_dispatch_snapshot="$__codex_dispatch_snapshot_dir/codex-dispatch.sh"
  # Resolve through symlinks (this adapter is also reachable via the
  # scripts/codex-dispatch.sh compatibility shim) to the real file, then ascend
  # two levels (adapters/codex → repo root) to locate repo-relative sources.
  __codex_dispatch_real="${BASH_SOURCE[0]}"
  while [[ -L "$__codex_dispatch_real" ]]; do
    __codex_dispatch_link_dir="$(cd -P -- "$(dirname "$__codex_dispatch_real")" && pwd)"
    __codex_dispatch_real="$(readlink "$__codex_dispatch_real")"
    [[ "$__codex_dispatch_real" == /* ]] || __codex_dispatch_real="$__codex_dispatch_link_dir/$__codex_dispatch_real"
  done
  __codex_dispatch_source_repo="$(cd -P -- "$(dirname "$__codex_dispatch_real")/../.." && pwd)"
  __codex_dispatch_alias_source="$__codex_dispatch_source_repo/share/model-aliases.tsv"
  __codex_dispatch_isolation_source="$__codex_dispatch_source_repo/adapters/codex/isolation-map.yaml"
  cp -- "${BASH_SOURCE[0]}" "$__codex_dispatch_snapshot"
  [[ -r "$__codex_dispatch_alias_source" ]] && cp -- "$__codex_dispatch_alias_source" "$__codex_dispatch_snapshot_dir/model-aliases.tsv" || true
  if [[ -r "$__codex_dispatch_isolation_source" ]]; then
    mkdir -p -- "$__codex_dispatch_snapshot_dir/adapters/codex"
    cp -- "$__codex_dispatch_isolation_source" "$__codex_dispatch_snapshot_dir/adapters/codex/isolation-map.yaml"
  fi
  # shellcheck disable=SC1091
  . "$__codex_dispatch_source_repo/scripts/lib/dispatch-common.sh"
  dc_snapshot_copy_libs "$__codex_dispatch_snapshot_dir" "$__codex_dispatch_source_repo"
  chmod +x -- "$__codex_dispatch_snapshot"
  exec "$__codex_dispatch_snapshot" "$@"
fi
# Running from the snapshot copy — we own the directory, clean it up on exit.
__codex_dispatch_snapshot_dir="$(dirname "${BASH_SOURCE[0]}")"
trap 'rm -rf -- "$__codex_dispatch_snapshot_dir"' EXIT

WORK_DIR=""
MODEL=""
EFFORT=""
SANDBOX="workspace-write"
ISOLATION=""   # isolation_level from brief; expanded to --sandbox + -c flags
APPROVAL="never"
SKIP_GIT_CHECK=0
SCRIPT_DIR="$(cd -P -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PM_DISPATCH_ALIAS_FILE="${SCRIPT_DIR}/model-aliases.tsv"
# Fallbacks, in order: snapshot-flat (`../share`, the installed-helper layout)
# then repo-source layout from adapters/codex/ (`../../share`). The latter keeps
# alias resolution working if the self-snapshot bootstrap is ever bypassed.
[[ -f "$PM_DISPATCH_ALIAS_FILE" ]] || PM_DISPATCH_ALIAS_FILE="${SCRIPT_DIR}/../share/model-aliases.tsv"
[[ -f "$PM_DISPATCH_ALIAS_FILE" ]] || PM_DISPATCH_ALIAS_FILE="${SCRIPT_DIR}/../../share/model-aliases.tsv"
TIMEOUT=""
BRIEF=""
BRIEF_FILE=""
BRIEF_FROM_ARGV=0
PRINT_CMD=0
TRACE_DIR_OVERRIDE=""
# pm-dispatch's OWN default model, decoupled from the user's interactive
# ~/.codex/config.toml `model` setting (which may be a spark/other variant).
# This is the `default` ALIAS — its wire id (gpt-5.6-terra) lives only in
# share/model-aliases.tsv (single source of truth), so a model bump edits the
# TSV alone. Override via the PM_CFG_DEFAULT_MODEL env var, which `pmctl dispatch
# run` exports from ~/.pm-dispatch/config `dispatch.default_model` (see line ~235).
# The adapter no longer reads that config file directly: direct shim callers must
# either dispatch through `pmctl dispatch run` or set PM_CFG_DEFAULT_MODEL themselves.
DEFAULT_DISPATCH_MODEL="default"

# shellcheck source=scripts/lib/state-writer.sh  # sourced for snapshot support only; pmctl owns state writes.
. "$SCRIPT_DIR/lib/state-writer.sh" 2>/dev/null || true
# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib/model-aliases.sh"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib/reasoning-effort.sh"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib/timeout-resolve.sh"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib/dispatch-common.sh"

_resolve_model_alias() {
  local query_model="$1"
  ma_resolve_alias_strict "$PM_DISPATCH_ALIAS_FILE" "$query_model" "codex-dispatch" || return 1
  if [[ "$MA_RESOLVE_MATCH" == "1" ]]; then
    MODEL_RESOLVED="$MA_RESOLVE_MODEL"
    MODEL_RESOLVED_EFFORT="$MA_RESOLVE_EFFORT"
    MODEL_ALIAS_MATCH=1
  fi
}

tr_resolve_timeout "" "CODEX_DISPATCH_TIMEOUT" "PM_CFG_TIMEOUT" "1200"
TIMEOUT="$TR_RESOLVED_TIMEOUT"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cd) WORK_DIR="$2"; shift 2;;
    --model) MODEL="$2"; shift 2;;
    --effort) EFFORT="$2"; shift 2;;
    --sandbox) SANDBOX="$2"; shift 2;;
    --isolation) ISOLATION="$2"; shift 2;;
    --approval) APPROVAL="$2"; shift 2;;
    --skip-git-check) SKIP_GIT_CHECK=1; shift;;
    --timeout) TIMEOUT="$2"; shift 2;;
    --print-cmd) PRINT_CMD=1; shift;;
    --brief-file) BRIEF_FILE="$2"; shift 2;;
    --trace-dir) TRACE_DIR_OVERRIDE="$2"; shift 2;;
    --) shift; BRIEF="$*"; BRIEF_FROM_ARGV=1; break;;
    -h|--help)
      sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'
      exit 0;;
    *) echo "Unknown arg: $1" >&2; exit 2;;
  esac
done

if [[ -n "$BRIEF_FILE" && "$BRIEF_FROM_ARGV" -eq 1 ]]; then
  echo "Error: --brief-file and -- <brief...> are mutually exclusive" >&2
  exit 2
fi
if [[ "$BRIEF_FROM_ARGV" -eq 0 ]]; then
  dc_validate_args "$WORK_DIR" "$BRIEF_FILE" "$PRINT_CMD" "$TIMEOUT" || exit 2
  BRIEF="$DC_BRIEF"
else
  [[ -z "$WORK_DIR" ]] && { echo "Error: --cd <dir> is required" >&2; exit 2; }
  [[ ! -d "$WORK_DIR" ]] && { echo "Error: working dir not found: $WORK_DIR" >&2; exit 2; }
  [[ -z "$BRIEF" && "$PRINT_CMD" -ne 1 ]] && { echo "Error: brief is required; prefer --brief-file <path> (inline form after -- is only for trivial smoke checks)" >&2; exit 2; }
  ! [[ "$TIMEOUT" =~ ^[0-9]+$ ]] && { echo "Error: --timeout must be a non-negative integer (got: $TIMEOUT)" >&2; exit 2; }
fi

# Default model resolution. pm-dispatch pins its OWN default (the `default` alias,
# which resolves to gpt-5.6-terra via share/model-aliases.tsv), decoupled from the user's
# interactive ~/.codex/config.toml — so omitting --model dispatches on gpt-5.6-terra, NOT
# whatever the local codex config defaults to. Precedence: --model flag > config
# dispatch.default_model > built-in `default` alias. The chosen value flows through
# _resolve_model_alias below, attaching reasoning effort.
# Spark is never the default; opt in explicitly with --model codex-spark.
if [[ -z "$MODEL" ]]; then
  MODEL="${PM_CFG_DEFAULT_MODEL:-$DEFAULT_DISPATCH_MODEL}"
fi

MODEL_RESOLVED="$MODEL"
MODEL_RESOLVED_EFFORT=""
MODEL_ALIAS_MATCH=0
if [[ -n "$MODEL" ]]; then
  _resolve_model_alias "$MODEL" || exit 2
fi

# --effort overrides the alias's own effort column; --effort > alias effort >
# global default (medium). re_resolve_effort validates $EFFORT itself (returns
# 1 on an invalid flag value), so there is no separate pre-check here. See
# scripts/lib/reasoning-effort.sh for the fixed low/medium/high vocabulary and
# why it's narrower than codex's raw model_reasoning_effort surface.
re_resolve_effort "$EFFORT" "$MODEL_RESOLVED_EFFORT" || {
  printf 'codex-dispatch: error: --effort must be one of: %s (got: %s)\n' "$RE_VALID_EFFORTS" "$EFFORT" >&2
  exit 2
}
MODEL_RESOLVED_EFFORT="$RE_RESOLVED_EFFORT"

MODEL_DISPLAY="$MODEL"
if [[ -z "$MODEL_DISPLAY" ]]; then
  MODEL_DISPLAY="<default>"
elif [[ "$MODEL_ALIAS_MATCH" -eq 1 ]]; then
  MODEL_DISPLAY="$MODEL → $MODEL_RESOLVED (effort=$MODEL_RESOLVED_EFFORT)"
fi

TS=$(date +%Y%m%d-%H%M%S)-$$
LAST="/dev/null"
STDERR_LOG="/dev/null"
TRACE="<print-only>"

if [[ "$PRINT_CMD" -ne 1 ]]; then
  # Trace output location: --trace-dir flag > PM_DISPATCH_TRACE_DIR env > legacy
  # in-repo $WORK_DIR/.agent-trace (default UNCHANGED). Precedence + absolute-path
  # validation live in sw_resolve_trace_dir (scripts/lib/state-paths.sh), sourced
  # via state-writer.sh above and copied into the snapshot lib dir. Resolved only
  # when trace is actually written (--print-cmd writes none, so it needs no lib).
  dc_setup_trace_dir "$TRACE_DIR_OVERRIDE" "$WORK_DIR" "codex" "$TS" || exit 2
  TRACE_DIR="$DC_TRACE_DIR"; TRACE="$DC_TRACE"; LAST="$DC_LAST"; STDERR_LOG="$DC_STDERR_LOG"
fi

# ── Isolation-level expansion ─────────────────────────────────────────────
# Reads adapters/codex/isolation-map.yaml and expands ISOLATION into SANDBOX
# and CONFIG_OVERRIDES. Snapshot executions read the copied adapter file.
CONFIG_OVERRIDES=()
if [[ -n "$ISOLATION" ]]; then
  _ADAPTER_FILE="$SCRIPT_DIR/adapters/codex/isolation-map.yaml"
  # Snapshot-flat layout first, then repo-source layout from adapters/codex/.
  [[ -f "$_ADAPTER_FILE" ]] || _ADAPTER_FILE="$SCRIPT_DIR/../adapters/codex/isolation-map.yaml"
  [[ -f "$_ADAPTER_FILE" ]] || _ADAPTER_FILE="$SCRIPT_DIR/isolation-map.yaml"
  if [[ ! -f "$_ADAPTER_FILE" ]]; then
    printf 'codex-dispatch: error: adapters/codex/isolation-map.yaml not found (expected at %s)\n' "$_ADAPTER_FILE" >&2
    exit 2
  fi
  # Parse the sandbox value for the requested isolation level.
  # YAML structure: mappings:\n  <level>:\n    sandbox: <value>
  _ISO_SANDBOX=""
  _IN_LEVEL=0
  while IFS= read -r _line || [[ -n "$_line" ]]; do
    _line="${_line%$'\r'}"
    # Detect entry start: "  <level>:" (2-space indent)
    if [[ "$_line" =~ ^[[:space:]]{2}([a-z-]+):[[:space:]]*$ ]]; then
      _cur="${BASH_REMATCH[1]}"
      [[ "$_cur" == "$ISOLATION" ]] && _IN_LEVEL=1 || _IN_LEVEL=0
      continue
    fi
    [[ "$_IN_LEVEL" -eq 0 ]] && continue
    # sandbox: value
    if [[ "$_line" =~ ^[[:space:]]{4}sandbox:[[:space:]]*(.+)$ ]]; then
      _ISO_SANDBOX="${BASH_REMATCH[1]}"
      _ISO_SANDBOX="${_ISO_SANDBOX#\'}" ; _ISO_SANDBOX="${_ISO_SANDBOX%\'}"
    fi
    # config_overrides list items: "      - 'key=value'"
    if [[ "$_line" =~ ^[[:space:]]{6}-[[:space:]]+\'(.+)\'$ ]]; then
      CONFIG_OVERRIDES+=("${BASH_REMATCH[1]}")
    fi
    if [[ "$_line" =~ ^[[:space:]]{6}-[[:space:]]+\"(.+)\"$ ]]; then
      CONFIG_OVERRIDES+=("${BASH_REMATCH[1]}")
    fi
  done < "$_ADAPTER_FILE"
  if [[ -z "$_ISO_SANDBOX" ]]; then
    printf 'codex-dispatch: error: unknown isolation_level %q (not in adapters/codex/isolation-map.yaml)\n' "$ISOLATION" >&2
    exit 2
  fi
  SANDBOX="$_ISO_SANDBOX"
fi

# Codex full machine access (--sandbox danger-full-access) is retired: codex's
# max isolation is workspace-write. isolation_level:none no longer maps here, but
# a caller can still pass --sandbox danger-full-access directly, or reach it via
# `pmctl dispatch run` native-flag passthrough. Reject it fail-loud at this single
# chokepoint that every dispatch path crosses before `codex exec` is built, so the
# policy cannot be bypassed by the raw native flag.
if [[ "$SANDBOX" == "danger-full-access" ]]; then
  printf 'codex-dispatch: error: --sandbox danger-full-access is not supported (codex full machine access is retired; max isolation is workspace-write)\n' >&2
  exit 2
fi

CMD=(codex exec
  --cd "$WORK_DIR"
  --sandbox "$SANDBOX"
  -c "approval_policy=\"$APPROVAL\""
  --json
  --output-last-message "$LAST"
)
for _override in "${CONFIG_OVERRIDES[@]:-}"; do
  [[ -n "$_override" ]] && CMD+=(-c "$_override")
done
[[ -n "$MODEL" ]] && CMD+=(-m "$MODEL_RESOLVED")
[[ -n "$MODEL_RESOLVED_EFFORT" ]] && CMD+=(-c "model_reasoning_effort=\"$MODEL_RESOLVED_EFFORT\"")
[[ "$SKIP_GIT_CHECK" -eq 1 ]] && CMD+=(--skip-git-repo-check)
# Pass brief via stdin ("-") to avoid codex treating a multi-line positional
# argument as an incomplete prompt and blocking on stdin.
CMD+=("-")

# Wrapper banner — also written to console so the caller can see what's happening.
{
  echo "[$(date -Is)] codex-dispatch starting"
  echo "  cwd:      $WORK_DIR"
  echo "  model:    $MODEL_DISPLAY"
  echo "  sandbox:  $SANDBOX"
  [[ -n "$ISOLATION" ]] && echo "  isolation: $ISOLATION"
  echo "  approval: $APPROVAL"
  echo "  timeout:  ${TIMEOUT}s"
  echo "  trace:    $TRACE"
  if [[ -n "$BRIEF_FILE" ]]; then
    echo "  brief:    $BRIEF_FILE (file)"
  else
    echo "  brief:    $BRIEF"
  fi
} | tee -a "$STDERR_LOG" >&2

if [[ "$PRINT_CMD" -eq 1 ]]; then
  echo "CMD=${CMD[*]}"
  exit 0
fi

# Point latest.* convenience pointers at this run's files. Best-effort: on
# symlink-less hosts (Windows Git Bash) `ln -s` copy-falls-back, and a missing
# pointer must never abort dispatch — post-verify reads the per-run footer path,
# not latest.*. Called before launch (Unix observers attach immediately) and again
# after the run (symlink-less hosts get a usable copy once the targets exist).
dc_refresh_latest_pointers "codex" "$TRACE_DIR" "$TS"

set +e
if [[ "$TIMEOUT" -gt 0 ]]; then
  printf '%s\n' "$BRIEF" | timeout --foreground --kill-after=15 "$TIMEOUT" "${CMD[@]}" >"$TRACE" 2>>"$STDERR_LOG"
else
  printf '%s\n' "$BRIEF" | "${CMD[@]}" >"$TRACE" 2>>"$STDERR_LOG"
fi
EXIT=$?
set -e

# Re-point latest.* now that the per-run files exist (usable copies on
# symlink-less hosts; idempotent symlink refresh on Unix).
dc_refresh_latest_pointers "codex" "$TRACE_DIR" "$TS"

# --- auto-log token usage to usage-tracker.jsonl ---
if [[ "$EXIT" -eq 0 && -f "$TRACE" ]]; then
  _CODEX_TOKENS=$(jq -rs '
    first(.[] | select(.type == "turn.completed")
              | (.usage.input_tokens // 0) + (.usage.output_tokens // 0)) // 0
  ' "$TRACE" 2>/dev/null || echo 0)
  _CODEX_TOKENS="${_CODEX_TOKENS:-0}"
  if [[ "$_CODEX_TOKENS" -gt 0 ]]; then
    _POOL="codex"
    # Pooling uses the user-facing MODEL token (pre-resolution) to preserve
    # existing routing semantics in the PM dispatch contract and existing tests.
    [[ "${MODEL:-}" == *spark* ]] && _POOL="spark"
    _NOTE="auto: $(basename "$WORK_DIR")"
    # PM_CFG_USAGE_LOG_PATH (dispatch.usage_log_path in ~/.pm-dispatch/config,
    # exported by pmctl-dispatch.sh) overrides the claude-host-assumed default
    # path below — set it when the PM's own host is not claude
    # (docs/host-contract.md).
    bash "${PM_CFG_USAGE_LOG_PATH:-${HOME}/.claude/scripts/log-usage.sh}" "codex_dispatch" "$_CODEX_TOKENS" "$_NOTE" "" "$_POOL" 2>>"$STDERR_LOG" || \
      echo "[$(date -Is)] codex-dispatch: usage log failed (pool=$_POOL tokens=$_CODEX_TOKENS)" \
        >> "$STDERR_LOG"
  fi
fi

# Closing banner — captures exit code so post-mortem can spot timeouts (124).
{
  echo "[$(date -Is)] codex-dispatch finished"
  echo "  exit:     $EXIT"
  if [[ "$EXIT" -eq 124 ]]; then
    echo "  note:     hit ${TIMEOUT}s timeout (silent hang likely; rerun or extend --timeout)"
  fi
} | tee -a "$STDERR_LOG" >&2

dc_print_footer "$TRACE" "$LAST" "$STDERR_LOG" "$EXIT" "$MODEL"

exit $EXIT
