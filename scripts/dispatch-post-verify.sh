#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C.UTF-8

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/portable.sh
source "$SCRIPT_DIR/lib/portable.sh"

usage() {
  printf 'usage: %s <work_dir> [brief_file] [--last <path>] [--jsonl <path>] [--stderr <path>] [--brief-file <path>] [--base <ref>] [--terminal-event <type>]\n' "$0" >&2
}

# Path resolution is the only thing the flags change: --last/--jsonl/--stderr
# override the default latest.* symlinks with per-run explicit paths (e.g. parsed
# from the dispatch footer by the /pm main-thread route, where latest.* would race
# across concurrent dispatches). Absent flags, behavior is identical to the
# positional <work_dir> [brief_file] form used by `pmctl dispatch run`.
BRIEF_FILE=""
LAST_OVERRIDE=""
JSONL_OVERRIDE=""
STDERR_OVERRIDE=""
BASE_OVERRIDE=""
TERMINAL_EVENT=""
positional=()

# A value-taking flag must be followed by a real value — not end-of-args and not
# another flag. Without this, `--last --stderr X` would silently treat `--stderr`
# as the --last path and fail later as a confusing not-found, instead of usage.
need_val() {
  local flag="$1" val="$2"
  if [[ -z "$val" || "$val" == -* ]]; then
    printf 'ERROR: %s requires a value\n' "$flag" >&2
    usage
    exit 2
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --last)       need_val --last "${2:-}";       LAST_OVERRIDE="$2";   shift 2 ;;
    --jsonl)      need_val --jsonl "${2:-}";      JSONL_OVERRIDE="$2";  shift 2 ;;
    --stderr)     need_val --stderr "${2:-}";     STDERR_OVERRIDE="$2"; shift 2 ;;
    --brief-file) need_val --brief-file "${2:-}"; BRIEF_FILE="$2";      shift 2 ;;
    --base)       need_val --base "${2:-}";       BASE_OVERRIDE="$2";   shift 2 ;;
    --terminal-event) need_val --terminal-event "${2:-}"; TERMINAL_EVENT="$2"; shift 2 ;;
    --)           shift; while [[ $# -gt 0 ]]; do positional+=("$1"); shift; done ;;
    -*)           usage; exit 2 ;;
    *)            positional+=("$1"); shift ;;
  esac
done

WORK_DIR="${positional[0]:-}"
# Second positional is brief_file, but only when --brief-file was not supplied
# (supplying both is ambiguous and rejected).
if [[ -z "$BRIEF_FILE" ]]; then
  BRIEF_FILE="${positional[1]:-}"
  POSITIONAL_MAX=2
else
  POSITIONAL_MAX=1
fi

if [[ ${#positional[@]} -gt $POSITIONAL_MAX || -z "$WORK_DIR" ]]; then
  usage
  exit 2
fi

if [[ -n "$BRIEF_FILE" && ! -f "$BRIEF_FILE" ]]; then
  printf 'ERROR: brief file not found: %s\n' "$BRIEF_FILE" >&2
  exit 1
fi

TRACE_DIR="$WORK_DIR/.agent-trace"
LATEST_LAST="${LAST_OVERRIDE:-$TRACE_DIR/latest.last}"
LATEST_JSONL="${JSONL_OVERRIDE:-$TRACE_DIR/latest.jsonl}"
LATEST_STDERR="${STDERR_OVERRIDE:-$TRACE_DIR/latest.stderr}"

if [[ ! -d "$TRACE_DIR" ]]; then
  printf 'FAILED: .agent-trace dir not found: %s\n' "$TRACE_DIR"
  exit 1
fi

if [[ -L "$TRACE_DIR" ]]; then
  TRACE_DIR_RESOLVED="$(realpath_m "$TRACE_DIR" 2>/dev/null || true)"
  WORK_ABS="$(realpath_m "$WORK_DIR" 2>/dev/null || echo "$WORK_DIR")"
  if [[ -z "$TRACE_DIR_RESOLVED" || "${TRACE_DIR_RESOLVED#"$WORK_ABS/"}" == "$TRACE_DIR_RESOLVED" ]]; then
    printf 'FAILED: .agent-trace symlink target is outside work dir: %s\n' "$TRACE_DIR_RESOLVED"
    exit 1
  fi
fi

TRACE_ABS="$(realpath_m "$TRACE_DIR" 2>/dev/null || echo "$TRACE_DIR")"

if [[ ! -e "$LATEST_LAST" && ! -L "$LATEST_LAST" ]]; then
  printf 'FAILED: latest.last not found: %s\n' "$LATEST_LAST"
  exit 1
fi

if [[ ! -s "$LATEST_LAST" ]]; then
  printf 'FAILED: latest.last is empty: %s\n' "$LATEST_LAST"
  exit 1
fi

# A flag-supplied --last gets the same containment guard as a latest.last
# symlink: its real path must stay inside this run's .agent-trace.
if [[ -L "$LATEST_LAST" || -n "$LAST_OVERRIDE" ]]; then
  LAST_RESOLVED="$(realpath_m "$LATEST_LAST" 2>/dev/null || true)"
  if [[ -z "$LAST_RESOLVED" || "${LAST_RESOLVED#"$TRACE_ABS/"}" == "$LAST_RESOLVED" ]]; then
    printf 'FAILED: latest.last path is outside .agent-trace: %s\n' "$LAST_RESOLVED"
    exit 1
  fi
fi

# Same containment guard for the JSONL trace when it is a symlink or a
# flag-supplied --jsonl override (applied only when the path exists; a missing
# supplied --jsonl is handled fail-closed in the integrity section below).
if [[ -e "$LATEST_JSONL" || -L "$LATEST_JSONL" ]]; then
  if [[ -L "$LATEST_JSONL" || -n "$JSONL_OVERRIDE" ]]; then
    JSONL_RESOLVED="$(realpath_m "$LATEST_JSONL" 2>/dev/null || true)"
    if [[ -z "$JSONL_RESOLVED" || "${JSONL_RESOLVED#"$TRACE_ABS/"}" == "$JSONL_RESOLVED" ]]; then
      printf 'FAILED: latest.jsonl path is outside .agent-trace: %s\n' "$JSONL_RESOLVED"
      exit 1
    fi
  fi
fi

printf '=== Agent trace (latest.last) ===\n'
tail -50 "$LATEST_LAST"
printf '\n'

# Same containment guard for a flag-supplied --stderr, applied only when the file
# exists (a missing supplied --stderr is handled fail-closed further below; the
# default latest.stderr path stays optional).
if [[ -L "$LATEST_STDERR" ]] || [[ -n "$STDERR_OVERRIDE" && -e "$LATEST_STDERR" ]]; then
  STDERR_RESOLVED="$(realpath_m "$LATEST_STDERR" 2>/dev/null || true)"
  if [[ -z "$STDERR_RESOLVED" || "${STDERR_RESOLVED#"$TRACE_ABS/"}" == "$STDERR_RESOLVED" ]]; then
    printf 'FAILED: latest.stderr path is outside .agent-trace: %s\n' "$STDERR_RESOLVED"
    exit 1
  fi
fi

if [[ -s "$LATEST_STDERR" ]]; then
  printf '=== Stderr (latest.stderr) ===\n'
  tail -20 "$LATEST_STDERR"
  printf '\n'
fi

printf '=== Git diff --stat ===\n'
# Honor the caller-selected integration base (--base) so /pm dispatches targeting
# a non-origin/main branch get base-correct diff evidence; default origin/main.
# Three-dot (merge-base) form: show only what HEAD added since diverging from the
# base, so an advanced integration branch does not surface unrelated upstream
# commits as spurious diff evidence (matches the prior /pm `<base>...HEAD`
# contract; uncommitted work is surfaced separately by `git status --short` below).
DIFF_BASE="${BASE_OVERRIDE:-origin/main}"
if git -C "$WORK_DIR" diff --stat "$DIFF_BASE...HEAD" 2>/dev/null; then
  printf '(base: %s...HEAD)\n' "$DIFF_BASE"
elif git -C "$WORK_DIR" diff --stat HEAD 2>/dev/null; then
  printf '(base: HEAD — %s unavailable)\n' "$DIFF_BASE"
else
  printf '(no git repo or no commits)\n'
fi
printf '\n'

printf '=== Untracked / modified files ===\n'
git -C "$WORK_DIR" status --short 2>/dev/null || echo '(no git repo)'
printf '\n'

FAILED=0

# Fail-closed on a flag-supplied --stderr whose file is absent: the footer claimed
# this per-run artifact exists, so a missing one signals a broken footer parse or a
# lost artifact and must not be reported as a clean post-verify. The default
# (positional) latest.stderr path stays optional — pmctl dispatch run passes no
# --stderr and relies on that tolerance.
if [[ -n "$STDERR_OVERRIDE" && ! -e "$LATEST_STDERR" ]]; then
  printf 'FAILED: supplied --stderr not found: %s\n' "$STDERR_OVERRIDE"
  FAILED=1
fi

EXECUTOR_STATUS="$(grep -iE '^status: (failed|partial|blocked)' "$LATEST_LAST" || true)"
if [[ -n "$EXECUTOR_STATUS" ]]; then
  while IFS= read -r status_line; do
    printf 'FAILED: executor reported non-success outcome: %s\n' "$status_line"
  done <<< "$EXECUTOR_STATUS"
  FAILED=1
fi

# CC-386: trace integrity. The executor's own .last/`status:` line is its
# self-report; the JSONL event stream is independent proof the run actually ran to
# completion. A run can exit 0 yet leave a truncated/orphaned trace (e.g. a
# background job SIGKILLed mid-write, leaving a partial trailing record as its
# orphan signature): the .last contract alone cannot tell that from a clean
# finish. So when a trace is present we require it to be structurally whole — fully
# parseable as a JSON stream — which catches a partial trailing record (the
# truncation signature). Semantic completion markers differ per adapter (codex's
# `turn.completed` event vs claude's single `result` object); those are checked
# separately below as the semantic terminal-event step (declared per adapter in
# adapter.yaml, threaded in via --terminal-event), layered on top of this
# adapter-agnostic structural keystone.
#
# Severity mirrors latest.stderr: an explicit --jsonl (parsed from the adapter
# footer by `pmctl dispatch run`, which every real dispatch supplies) is
# fail-closed — a missing one means a broken footer parse or a lost artifact. The
# positional default (latest.jsonl) stays optional, so legacy positional callers
# and trace-less fixtures are tolerated; when it exists it is still checked.
printf '=== Trace integrity (latest.jsonl) ===\n'
if [[ -n "$JSONL_OVERRIDE" && ! -e "$LATEST_JSONL" ]]; then
  printf '  FAIL: supplied --jsonl not found: %s\n' "$JSONL_OVERRIDE"
  FAILED=1
elif [[ -e "$LATEST_JSONL" ]]; then
  if [[ ! -s "$LATEST_JSONL" ]]; then
    printf '  FAIL: trace is empty: %s\n' "$LATEST_JSONL"
    FAILED=1
  else
    # Proof of completeness must be that at least one JSON value actually parsed —
    # NOT just a non-zero file plus a clean `jq empty`, which also succeeds on a
    # whitespace-only file (a silent false-success). Count values by streaming
    # `inputs` (no slurp, so a large trace is not held in memory): a truncated or
    # malformed trace aborts the parse mid-stream → no count emitted; a
    # whitespace-only trace yields 0; a real codex JSONL stream or claude single
    # object yields >= 1. jq is a hard adapter dependency, so its absence also
    # leaves the count empty and fails closed.
    _jsonl_count="$(jq -n 'reduce inputs as $i (0; . + 1)' "$LATEST_JSONL" 2>/dev/null || true)"
    if [[ "$_jsonl_count" =~ ^[0-9]+$ && "$_jsonl_count" -gt 0 ]]; then
      printf '  PASS: trace structurally complete (%s JSON record(s)): %s\n' "$_jsonl_count" "$LATEST_JSONL"
      # Semantic terminal-event check, layered ON TOP of the structural keystone
      # above. Structural integrity proves the trace is whole; it does
      # NOT prove the run reached a successful end (a structurally valid trace can
      # stop at turn.started, e.g. an auth-rejected or silently-killed run). Each
      # adapter DECLARES its semantic completion marker as `terminal_event` in
      # adapter.yaml (codex: turn.completed, claude: result); pmctl dispatch run
      # reads it and threads it here via --terminal-event. We assert at least one
      # record carries that `.type`. The marker is data-driven (no hard-coded
      # adapter knowledge here) but the predicate SHAPE is fixed to `.type == $ev`
      # with the value injected via --arg, so adapter.yaml can never inject an
      # arbitrary jq filter. Flag-gated: positional/legacy callers pass no
      # --terminal-event and stay structure-only (back-compat, mirrors the --jsonl
      # severity split). Counted by the same streaming `inputs` reduction as the
      # structural check, so jq absence / a parse abort leaves the count empty and
      # fails closed.
      if [[ -n "$TERMINAL_EVENT" ]]; then
        _term_count="$(jq -n --arg ev "$TERMINAL_EVENT" 'reduce inputs as $i (0; . + (if ($i.type? == $ev) then 1 else 0 end))' "$LATEST_JSONL" 2>/dev/null || true)"
        if [[ "$_term_count" =~ ^[0-9]+$ && "$_term_count" -gt 0 ]]; then
          printf '  PASS: trace semantically complete (%s "%s" terminal event(s)): %s\n' "$_term_count" "$TERMINAL_EVENT" "$LATEST_JSONL"
        else
          printf '  FAIL: trace has no "%s" terminal event (run did not signal completion): %s\n' "$TERMINAL_EVENT" "$LATEST_JSONL"
          FAILED=1
        fi
      fi
    else
      printf '  FAIL: trace truncated, malformed, or has no JSON value (incomplete run): %s\n' "$LATEST_JSONL"
      FAILED=1
    fi
  fi
else
  printf '  SKIP: no latest.jsonl (positional/legacy caller); .last contract governs\n'
fi
printf '\n'

# CC-318: a self_verify item is one of two kinds.
#   - Machine-executable check: the structured `- cmd: "<bash>"` form. post-verify
#     RUNS the command in $WORK_DIR under a timeout — exit 0 = PASS, non-zero or
#     timeout = FAIL. This replaces the old substring search of latest.last, so the
#     executor's prose style no longer matters. The command comes from the
#     PM-authored, brief-validated BRIEF_FILE (a trusted input).
#   - Semantic check: every other shape (macros like `git-status no-collateral-
#     damage: ...`, prose, bare scalars). These are judgment checks only the
#     executor (an LLM) — not a shell — can evaluate (e.g. "UI renders correctly",
#     "cross-checked against sources"). post-verify marks them SKIP rather than
#     forcing them through bash, which would fail valid judgment-only briefs.
# The optional `expect:` mapping key that may follow a `cmd:` item is informational
# (the only documented value is "exits 0", which is exactly the exit-0 PASS rule);
# the awk extractor only yields `- ` list items, so `expect:` lines are ignored.
SELF_VERIFY_TIMEOUT="${DISPATCH_SELF_VERIFY_TIMEOUT:-300}"

if [[ -n "$BRIEF_FILE" ]]; then
  printf '=== Self-verify checks ===\n'
  while IFS= read -r item; do
    if [[ "$item" != cmd:* ]]; then
      printf '  SKIP (executor-evaluated): %s\n' "$item"
      continue
    fi
    # Extract the command value from `cmd: <value>`, trimming leading space and a
    # single layer of matching surrounding quotes.
    cmd="${item#cmd:}"
    cmd="${cmd#"${cmd%%[![:space:]]*}"}"
    if   [[ "$cmd" == \"*\" ]]; then cmd="${cmd#\"}"; cmd="${cmd%\"}"
    elif [[ "$cmd" == \'*\' ]]; then cmd="${cmd#\'}"; cmd="${cmd%\'}"
    fi
    if ( cd "$WORK_DIR" && timeout --kill-after=15 "$SELF_VERIFY_TIMEOUT" bash -c "$cmd" ) >/dev/null 2>&1; then
      printf '  PASS: %s\n' "$item"
    else
      rc=$?
      if [[ "$rc" -eq 124 ]]; then
        printf '  FAIL (timeout %ss): %s\n' "$SELF_VERIFY_TIMEOUT" "$item"
      else
        printf '  FAIL (exit %s): %s\n' "$rc" "$item"
      fi
      FAILED=1
    fi
  done < <(
    awk '/^self_verify:/{in_sec=1; next} /^[a-z_]+:/{in_sec=0} in_sec && /^[[:space:]]*-[[:space:]]/{sub(/^[[:space:]]*-[[:space:]]*/,""); print}' "$BRIEF_FILE"
  )
  printf '\n'
fi

if [[ "$FAILED" -eq 0 ]]; then
  if [[ -z "$BRIEF_FILE" ]]; then
    printf 'OK-NOBRIEF: self_verify checks skipped\n'
  else
    printf 'OK\n'
  fi
  exit 0
fi

printf 'FAILED: one or more self_verify checks failed\n'
exit 1
