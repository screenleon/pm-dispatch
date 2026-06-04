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
#   codex-dispatch.sh --cd <dir> [--model <m>] [--sandbox <mode>]
#                     [--isolation <level>]
#                     [--approval <mode>] [--skip-git-check]
#                     [--timeout <seconds>] [--print-cmd]
#                     --brief-file <path>
#   codex-dispatch.sh --cd <dir> [--model <m>] [--sandbox <mode>]
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
#   --sandbox  workspace-write   (read-only | workspace-write | danger-full-access)
#   --isolation empty            (none | read-only | workspace-write | workspace-network | sandboxed)
#   --approval never             (never | on-failure | on-request | untrusted)
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
  mkdir -p -- "$__codex_dispatch_snapshot_dir/lib"
  [[ -r "$__codex_dispatch_source_repo/scripts/lib/state-writer.sh" ]] && \
    cp -- "$__codex_dispatch_source_repo/scripts/lib/state-writer.sh" "$__codex_dispatch_snapshot_dir/lib/state-writer.sh" || true
  [[ -r "$__codex_dispatch_source_repo/scripts/lib/portable.sh" ]] && \
    cp -- "$__codex_dispatch_source_repo/scripts/lib/portable.sh" "$__codex_dispatch_snapshot_dir/lib/portable.sh" || true
  chmod +x -- "$__codex_dispatch_snapshot"
  exec "$__codex_dispatch_snapshot" "$@"
fi
# Running from the snapshot copy — we own the directory, clean it up on exit.
__codex_dispatch_snapshot_dir="$(dirname "${BASH_SOURCE[0]}")"
trap 'rm -rf -- "$__codex_dispatch_snapshot_dir"' EXIT

WORK_DIR=""
MODEL=""
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
# pm-dispatch's OWN default model, decoupled from the user's interactive
# ~/.codex/config.toml `model` setting (which may be a spark/other variant).
# This is the `default` ALIAS — its wire id (gpt-5.5) lives only in
# share/model-aliases.tsv (single source of truth), so a model bump edits the
# TSV alone. Override via the PM_CFG_DEFAULT_MODEL env var, which `pmctl dispatch
# run` exports from ~/.pm-dispatch/config `dispatch.default_model` (see line ~235).
# The adapter no longer reads that config file directly: direct shim callers must
# either dispatch through `pmctl dispatch run` or set PM_CFG_DEFAULT_MODEL themselves.
DEFAULT_DISPATCH_MODEL="default"

# shellcheck source=scripts/lib/state-writer.sh
. "$SCRIPT_DIR/lib/state-writer.sh" 2>/dev/null || true

_resolve_model_alias() {
  local query_model="$1"
  local line_no=0
  local line
  local alias_value model_id reasoning_effort

  if [[ ! -f "$PM_DISPATCH_ALIAS_FILE" ]]; then
    echo "codex-dispatch: error: model alias source-of-truth not found: $PM_DISPATCH_ALIAS_FILE" >&2
    echo "Expected file path: share/model-aliases.tsv (copied to snapshot at runtime)." >&2
    return 1
  fi
  if ! [[ -r "$PM_DISPATCH_ALIAS_FILE" ]]; then
    echo "codex-dispatch: error: model alias source-of-truth unreadable: $PM_DISPATCH_ALIAS_FILE" >&2
    return 1
  fi

  while IFS= read -r line || [[ -n "$line" ]]; do
    ((line_no += 1))
    line="${line%$'\r'}"
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [[ -z "$line" ]] && continue
    [[ "${line:0:1}" == "#" ]] && continue

    IFS=$'\t' read -r alias_value model_id reasoning_effort rest <<< "$line"
    if [[ -z "$alias_value" || -z "$model_id" || -z "$reasoning_effort" || -n "$rest" ]]; then
      echo "codex-dispatch: error: malformed model-alias entry in ${PM_DISPATCH_ALIAS_FILE}:${line_no}" >&2
      echo "Expected one tab-separated line: <alias><TAB><model_id><TAB><reasoning_effort>" >&2
      return 1
    fi

    if [[ "$alias_value" == "$query_model" ]]; then
      MODEL_RESOLVED="$model_id"
      MODEL_RESOLVED_EFFORT="$reasoning_effort"
      MODEL_ALIAS_MATCH=1
      return 0
    fi
  done < "$PM_DISPATCH_ALIAS_FILE"

  return 0
}

# Timeout precedence: --timeout flag (parsed below, wins) > $CODEX_DISPATCH_TIMEOUT
# env > PM_CFG_TIMEOUT (exported by pmctl from config) > 1200 default.
# PM_CFG_TIMEOUT is set in this env by `pmctl dispatch run` (CC-293); direct
# adapter invocations fall back to 1200 when the var is absent.
if [[ -n "${CODEX_DISPATCH_TIMEOUT:-}" ]]; then
  TIMEOUT="$CODEX_DISPATCH_TIMEOUT"
elif [[ -n "${PM_CFG_TIMEOUT:-}" ]]; then
  TIMEOUT="$PM_CFG_TIMEOUT"
else
  TIMEOUT="1200"
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cd) WORK_DIR="$2"; shift 2;;
    --model) MODEL="$2"; shift 2;;
    --sandbox) SANDBOX="$2"; shift 2;;
    --isolation) ISOLATION="$2"; shift 2;;
    --approval) APPROVAL="$2"; shift 2;;
    --skip-git-check) SKIP_GIT_CHECK=1; shift;;
    --timeout) TIMEOUT="$2"; shift 2;;
    --print-cmd) PRINT_CMD=1; shift;;
    --brief-file) BRIEF_FILE="$2"; shift 2;;
    --) shift; BRIEF="$*"; BRIEF_FROM_ARGV=1; break;;
    -h|--help)
      sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'
      exit 0;;
    *) echo "Unknown arg: $1" >&2; exit 2;;
  esac
done

if [[ -z "$WORK_DIR" ]]; then
  echo "Error: --cd <dir> is required" >&2
  exit 2
fi
if [[ ! -d "$WORK_DIR" ]]; then
  echo "Error: working dir not found: $WORK_DIR" >&2
  exit 2
fi
if [[ -n "$BRIEF_FILE" && "$BRIEF_FROM_ARGV" -eq 1 ]]; then
  echo "Error: --brief-file and -- <brief...> are mutually exclusive" >&2
  exit 2
fi
if [[ -n "$BRIEF_FILE" ]]; then
  if [[ ! -f "$BRIEF_FILE" || ! -r "$BRIEF_FILE" ]]; then
    echo "Error: brief file not found or not readable: $BRIEF_FILE" >&2
    exit 2
  fi
  BRIEF="$(<"$BRIEF_FILE")"
fi
if [[ -z "$BRIEF" ]]; then
  if [[ "$PRINT_CMD" -eq 1 ]]; then
    BRIEF=""
  elif [[ -n "$BRIEF_FILE" ]]; then
    echo "Error: brief file is empty: $BRIEF_FILE" >&2
  else
    echo "Error: brief is required; prefer --brief-file <path> (inline form after -- is only for trivial smoke checks)" >&2
  fi
  [[ "$PRINT_CMD" -eq 1 ]] || exit 2
fi
if ! [[ "$TIMEOUT" =~ ^[0-9]+$ ]]; then
  echo "Error: --timeout must be a non-negative integer (got: $TIMEOUT)" >&2
  exit 2
fi

# Default model resolution. pm-dispatch pins its OWN default (the `default` alias,
# which resolves to gpt-5.5 via share/model-aliases.tsv), decoupled from the user's
# interactive ~/.codex/config.toml — so omitting --model dispatches on gpt-5.5, NOT
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
  TRACE_DIR="$WORK_DIR/.agent-trace"
  mkdir -p "$TRACE_DIR"
  TRACE="$TRACE_DIR/codex-$TS.jsonl"
  LAST="$TRACE_DIR/codex-$TS.last"
  STDERR_LOG="$TRACE_DIR/codex-$TS.stderr"
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

# Expose the dispatch target's git root to the bash guard so codex can read
# from the target repo regardless of where it lives (CC-320). Prepend so any
# user-set CLAUDE_HOOK_CODEX_READ_ROOTS is preserved as additional fallback.
_CODEX_GIT_ROOT="$(git -C "$WORK_DIR" rev-parse --show-toplevel 2>/dev/null || printf '%s' "$WORK_DIR")"
export CLAUDE_HOOK_CODEX_READ_ROOTS="$_CODEX_GIT_ROOT:/tmp${CLAUDE_HOOK_CODEX_READ_ROOTS:+:$CLAUDE_HOOK_CODEX_READ_ROOTS}"
unset _CODEX_GIT_ROOT

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

# Refresh latest.* symlinks before launch so observers can attach immediately.
# 2>/dev/null || true: ln -sfn fails on Windows MSYS when target doesn't yet exist.
ln -sfn "codex-$TS.jsonl"   "$TRACE_DIR/latest.jsonl"  2>/dev/null || true
ln -sfn "codex-$TS.last"    "$TRACE_DIR/latest.last"   2>/dev/null || true
ln -sfn "codex-$TS.stderr"  "$TRACE_DIR/latest.stderr" 2>/dev/null || true

set +e
if [[ "$TIMEOUT" -gt 0 ]]; then
  printf '%s\n' "$BRIEF" | timeout --foreground --kill-after=15 "$TIMEOUT" "${CMD[@]}" >"$TRACE" 2>>"$STDERR_LOG"
else
  printf '%s\n' "$BRIEF" | "${CMD[@]}" >"$TRACE" 2>>"$STDERR_LOG"
fi
EXIT=$?
set -e

# --- state store: append Run row (best-effort; never fatal) ---
sw_append_dispatch_run "codex" "$EXIT" "${MODEL:-}" "${BRIEF_FILE:-}" "${WORK_DIR:-}" "${TRACE:-}" "${BRIEF:-}" 2>/dev/null || true

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
    bash "${HOME}/.claude/scripts/log-usage.sh" "codex_dispatch" "$_CODEX_TOKENS" "$_NOTE" "" "$_POOL" 2>>"$STDERR_LOG" || \
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

echo "---"
echo "trace:  $TRACE"
echo "last:   $LAST"
echo "stderr: $STDERR_LOG"
echo "exit:   $EXIT"
echo "---"
if [[ -s "$LAST" ]]; then
  echo "=== final message ==="
  cat "$LAST"
fi

exit $EXIT
