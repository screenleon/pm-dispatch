#!/usr/bin/env bash
set -euo pipefail
trap '' PIPE

# say -- emit a progress/diagnostic line on stdout that tolerates a closed pipe.
#
# A consumer that reads a prefix of our stdout and closes the pipe early
# (`pmctl gate run | head`, `| grep -q`, ...) makes the next stdout write fail
# with EPIPE. `trap '' PIPE` keeps the SIGPIPE from killing us, but under
# `set -e` the EPIPE write still makes printf return nonzero and aborts the
# script BEFORE dispatch -- leaving a 0-byte result file while the pipeline
# reports the consumer's exit 0 (silent false-success). The `|| true` here
# absorbs that nonzero so the gate always runs to completion and the per-route
# result-integrity checks remain the authority on the exit code. All human
# progress output must go through say(); only the result file and the
# machine-read handover block are gate "data".
# shellcheck disable=SC2059  # printf passthrough wrapper: the caller owns the format string
say() { printf "$@" 2>/dev/null || true; }

# _kill_process_tree <pid> [signal] -- signal a process AND all its descendants.
# A plain `kill <pid>` only reaches the `eval` subshell / dispatch.sh wrapper we
# backgrounded; the grandchild executor (`codex exec`, or a test `sleep` stub)
# lives in the same call chain but survives as an orphan reparented to init. The
# parallel reviewer/synthesis watchdogs must reap the whole tree or a timed-out
# gate leaks live executor processes. Walk children depth-first via `pgrep -P`
# (leaves before parents) so each layer is signaled before its parent disappears.
_kill_process_tree() {
  local _pid="$1" _sig="${2:-TERM}" _child
  for _child in $(pgrep -P "$_pid" 2>/dev/null || true); do
    _kill_process_tree "$_child" "$_sig"
  done
  kill -"$_sig" "$_pid" 2>/dev/null || true
}

# pr-gate.sh -- PR-gate review via a dispatched session
#
# DEFAULT (single-session / sequential):
#   All reviewers run in order inside ONE combined dispatch session.
#   Lower token cost. All reviewer findings appear in a single output file.
#   Use this for most routine changes.
#
# MULTI-SESSION (--parallel):
#   Each reviewer runs in its own INDEPENDENT dispatch session, followed by a
#   separate PM synthesis session. Reviewers share no context window, which
#   eliminates anchoring bias across reviewers.
#   Higher token cost. Use for auth/payment/migration paths or when reviewer
#   independence is worth the extra cost.
#
# Adjacent test files (not in the diff but directly paired to a changed source
# file) are automatically added to every reviewer brief so coverage gaps in
# unchanged test files are visible to the gate.
#
# Usage:
#   pr-gate.sh --cd <dir> [options]
#
# Options:
#   --cd <dir>           working directory (required)
#   --tier <tier>        express|standard|full -- overrides auto-detection
#   --brief <file>       dispatch brief for this change; architecture_impact field informs tier suggestion
#   --reviewers <list>   comma-separated names -- overrides tier default (targeted re-gate)
#   --targeted <list>    alias for --reviewers (matches /pr-gate skill vocabulary)
#   --scope <text>       context hint passed into the review brief
#   --base <branch>      base branch for diff (default: origin/HEAD → main)
#   --run-dir <abs>      out-of-repo dir for gate artifacts (briefs/results/trace); optional,
#                        defaults to in-repo paths under --cd when absent (backward compat)
#   --output <path>      result file (default: .gate-results/gate-<ts>.md)
#   --executor <mode>    codex|claude|auto (default: auto; auto uses `command -v codex`)
#   --model <id>         dispatch model (default: "default" → adapter's pinned default,
#                        e.g. codex gpt-5.5 / claude sonnet; pass a concrete id to override)
#   --isolation <level>  isolation level: none|read-only|workspace-write|workspace-network|sandboxed
#   --timeout <secs>     dispatch timeout per session (default: 1200)
#   --parallel           multi-session: one dispatch per reviewer + synthesis (higher token cost)
#   --sequential         alias for default single-session mode (kept for backward compatibility)
#   --allow-hooks        execute repo-local .pm-dispatch hook scripts (trusted branches only)
#   --allow-dirty        review the working tree as-is instead of failing on a dirty tree atop committed changes
#   --override-file <f>  inject accepted-risk overrides into every reviewer brief; auto-discovered
#                        from .gate-overrides.md at repo root when this flag is omitted. A relative
#                        <f> is resolved against the working dir (--cd), not the caller's CWD, since
#                        the file is loaded after the gate cd's into the work dir. The loaded source
#                        and content are recorded in the gate result (## Gate Overrides Applied).

WORK_DIR=""
GATE_RUN_DIR_OVERRIDE=""   # out-of-repo artifact root; set via --run-dir from pmctl-gate
TIER_OVERRIDE=""
REVIEWERS_OVERRIDE=""
SCOPE=""
BASE_OVERRIDE=""
OUTPUT_OVERRIDE=""
TIMEOUT="1200"
SEQUENTIAL=true   # default: sequential (lower token cost)
EXECUTOR_OPTION="auto"
ALLOW_HOOKS=false   # hooks require explicit --allow-hooks opt-in (security)
ALLOW_DIRTY=false   # gate refuses a dirty tree atop committed changes unless this opt-in
OVERRIDE_FILE=""
# "default" → omit --model → the executor adapter applies its own pinned default
# (for codex, resolved via share/model-aliases.tsv; decoupled from ~/.codex/config.toml).
# The gate is analysis-heavy and must run on a full model, never the spark variant;
# spark is opt-in only.
DISPATCH_MODEL="default"
DISPATCH_SANDBOX="workspace-write"
DISPATCH_ISOLATION=""   # isolation_level; empty = use codex default (workspace-write)
DISPATCH_APPROVAL="never"
BRIEF_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cd)         WORK_DIR="$2";           shift 2;;
    --run-dir)    GATE_RUN_DIR_OVERRIDE="$2"; shift 2;;
    --tier)       TIER_OVERRIDE="$2";      shift 2;;
    --brief)      BRIEF_FILE="$2";         shift 2;;
    --reviewers)  REVIEWERS_OVERRIDE="$2"; shift 2;;
    --targeted)   REVIEWERS_OVERRIDE="$2"; shift 2;;   # alias: /pr-gate skill + script comments say "targeted"
    --scope)      SCOPE="$2";              shift 2;;
    --base)       BASE_OVERRIDE="$2";      shift 2;;
    --output)     OUTPUT_OVERRIDE="$2";    shift 2;;
    --executor)   EXECUTOR_OPTION="$2";    shift 2;;
    --model)      DISPATCH_MODEL="$2";     shift 2;;
    --isolation)  DISPATCH_ISOLATION="$2"; shift 2;;
    --timeout)    TIMEOUT="$2";            shift 2;;
    --parallel)   SEQUENTIAL=false;        shift;;
    --sequential) SEQUENTIAL=true;         shift;;   # backward compat
    --allow-hooks) ALLOW_HOOKS=true;       shift;;
    --allow-dirty) ALLOW_DIRTY=true;       shift;;
    --override-file)
      # Guard the operand explicitly: under `set -u` a bare `--override-file` with
      # no following arg would abort with a raw "unbound variable" instead of the
      # script's controlled CLI error style.
      [[ $# -ge 2 ]] || { printf 'Error: --override-file requires a file path\n' >&2; exit 2; }
      OVERRIDE_FILE="$2";  shift 2;;
    -h|--help)
      sed -n '2,63p' "$0" | sed 's/^# \{0,1\}//'
      exit 0;;
    *)
      printf 'Unknown arg: %s\n' "$1" >&2
      printf 'Accepted: --cd --run-dir --tier --brief --reviewers|--targeted --scope --base --output --executor --model --isolation --timeout --parallel --sequential --allow-hooks --allow-dirty --override-file (-h for help)\n' >&2
      exit 2;;
  esac
done

if [[ -z "$WORK_DIR" ]]; then
  printf 'Error: --cd <dir> is required\n' >&2; exit 2
fi
if [[ ! -d "$WORK_DIR" ]]; then
  printf 'Error: working dir not found: %s\n' "$WORK_DIR" >&2; exit 2
fi
if [[ -n "$GATE_RUN_DIR_OVERRIDE" && "$GATE_RUN_DIR_OVERRIDE" != /* ]]; then
  printf 'Error: --run-dir must be an absolute path: %s\n' "$GATE_RUN_DIR_OVERRIDE" >&2; exit 2
fi

_self="$0"
while [[ -L "$_self" ]]; do
  _self_dir="$(cd "$(dirname "$_self")" && pwd)"
  _self="$(readlink "$_self")"
  [[ "$_self" == /* ]] || _self="$_self_dir/$_self"
done
SCRIPT_DIR="$(cd "$(dirname "$_self")" && pwd)"
GATE_RESULT_VERIFY_PATH="$SCRIPT_DIR/lib/gate-result-verify.sh"
if [[ -r "$GATE_RESULT_VERIFY_PATH" ]]; then
  # shellcheck source=scripts/lib/gate-result-verify.sh
  . "$GATE_RESULT_VERIFY_PATH"
else
  # Inline fallback for copy-mode (pr-gate.sh run standalone without scripts/lib/).
  # MUST stay in sync with scripts/lib/gate-result-verify.sh; the copy-mode
  # regression test exercises this path.
  gate_result_verify() {
    local result_file=${1-} expected_final=${2-} route_label=${3-gate}
    local final_count frontmatter_final body_final

    [[ $# -ge 1 && $# -le 3 ]] || {
      printf 'gate-result-verify: gate_result_verify expects <result_file> [expected_final] [route_label]\n' >&2
      return 2
    }

    if [[ ! -s "$result_file" ]]; then
      printf 'Error: %s did not produce the result file: %s\n' "$route_label" "$result_file" >&2
      printf 'Gate aborted -- the executor session may have exited 0 without writing a verdict.\n' >&2
      return 1
    fi

    final_count=$(grep -cE '^Final: (GO|NO-GO)$' "$result_file" || true)
    if [[ "$final_count" -ne 1 ]]; then
      printf 'Error: gate result file must contain exactly one Final: GO/NO-GO line (found %d): %s\n' \
        "$final_count" "$result_file" >&2
      return 1
    fi

    frontmatter_final=$(awk 'BEGIN{s=0} /^---$/ { if (s == 0) { s=1; next } else if (s == 1) { exit } } s && $1 == "final:" { print $2; exit }' "$result_file")
    if [[ -z "$frontmatter_final" ]]; then
      printf 'Error: gate result YAML frontmatter missing required field: final: (%s)\n' "$result_file" >&2
      return 1
    fi

    body_final=$(grep -E '^Final: (GO|NO-GO)$' "$result_file" | awk '{print $2}')
    if [[ "$frontmatter_final" != "$body_final" ]]; then
      printf 'Error: frontmatter final: (%s) does not match body Final: (%s) in gate result: %s\n' \
        "$frontmatter_final" "$body_final" "$result_file" >&2
      return 1
    fi

    if [[ -n "$expected_final" && "$body_final" != "$expected_final" ]]; then
      printf 'Error: %s verdict (%s) contradicts shell-computed verdict (%s) -- gate result may have been manipulated: %s\n' \
        "$route_label" "$body_final" "$expected_final" "$result_file" >&2
      return 1
    fi

    return 0
  }
fi
EXECUTOR_ROUTER_PATH="$SCRIPT_DIR/lib/executor-router.sh"
if [[ -r "$EXECUTOR_ROUTER_PATH" ]]; then
  # shellcheck source=scripts/lib/executor-router.sh
  . "$EXECUTOR_ROUTER_PATH"
  EXECUTOR_ROUTER_SCRIPT_DIR="$SCRIPT_DIR"
else
  # DEGRADED copy-mode fallback (no scripts/lib/ alongside this script). It
  # INTENTIONALLY diverges from the data-driven lib (scripts/lib/executor-router.sh):
  # copy-mode has no adapters/ manifest tree to read, so routing is hardcoded to the
  # two built-in executors (codex|claude). The lib is the data-driven authority; this
  # block only needs to keep the gate runnable standalone for those two.
  EXECUTOR_ROUTER_SCRIPT_DIR="$SCRIPT_DIR"

  detect_executor_auto() {
    if command -v codex >/dev/null 2>&1; then
      printf 'codex\n'
    else
      printf 'claude\n'
    fi
  }

  resolve_executor() {
    local option=${1-}

    [[ $# -eq 1 ]] || {
      printf 'executor-router: resolve_executor expects exactly one argument\n' >&2
      return 2
    }

    case "$option" in
      auto) detect_executor_auto ;;
      codex|claude) printf '%s\n' "$option" ;;
      *)
        printf 'executor-router: unknown executor: %s (expected codex, claude, or auto)\n' "$option" >&2
        return 2
        ;;
    esac
  }

  dispatch_route_for() {
    local executor=${1-}

    [[ $# -eq 1 ]] || {
      printf 'executor-router: dispatch_route_for expects exactly one argument\n' >&2
      return 2
    }

    # Both built-in executors run as headless CLI subprocesses (cli-subprocess);
    # claude's canonical route is `claude --print` driven by pmctl dispatch run,
    # not Agent-spawn. Mirrors the data-driven lib resolving both to this route.
    case "$executor" in
      codex) printf 'main_thread_bash_background\n' ;;
      claude) printf 'main_thread_bash_background\n' ;;
      *)
        printf 'executor-router: unknown executor: %s (expected codex or claude)\n' "$executor" >&2
        return 2
        ;;
    esac
  }

  executor_router_safe_argv() {
    local value=${1-}
    printf '%q' "$value"
  }

  # Generic dispatcher mirroring the lib's dispatch_via, hardcoded to the two
  # built-in executors. Only codex is sent --sandbox/--approval; claude (headless
  # `claude --print`) accepts but ignores them as no-ops, so copy-mode omits them
  # — a deliberate simplification of the lib's per-runner-kind rule.
  dispatch_via() {
    local executor=${1-}
    local brief_file=${2-}
    local working_dir=${3-}
    local model=${4-}
    local sandbox=${5-}
    local approval=${6-}
    local timeout=${7-}
    local isolation_level=${8-}
    local -a cmd
    local arg
    local first=1

    [[ $# -eq 7 || $# -eq 8 ]] || {
      printf 'executor-router: dispatch_via expects executor, brief_file, working_dir, model, sandbox, approval, timeout[, isolation_level]\n' >&2
      return 2
    }

    case "$executor" in
      codex|claude) ;;
      *)
        printf 'executor-router: %s is not a routable executor (copy-mode supports codex|claude only)\n' "$executor" >&2
        return 2
        ;;
    esac

    local dispatch_script="${EXECUTOR_ROUTER_SCRIPT_DIR%/scripts}/adapters/$executor/dispatch.sh"
    cmd=(bash "$dispatch_script" --cd "$working_dir")
    [[ -n "$model" && "$model" != "default" ]] && cmd+=(--model "$model")
    if [[ "$executor" == "codex" ]]; then
      cmd+=(--sandbox "$sandbox" --approval "$approval")
    fi
    cmd+=(--timeout "$timeout" --brief-file "$brief_file")
    [[ -n "$isolation_level" ]] && cmd+=(--isolation "$isolation_level")
    [[ -n "${PM_DISPATCH_TRACE_DIR:-}" ]] && cmd+=(--trace-dir "$PM_DISPATCH_TRACE_DIR")

    for arg in "${cmd[@]}"; do
      if [[ "$first" -eq 1 ]]; then
        first=0
      else
        printf ' '
      fi
      executor_router_safe_argv "$arg"
    done
    printf '\n'
  }
fi

ARTIFACT_PATHS_PATH="$SCRIPT_DIR/lib/artifact-paths.sh"
if [[ -r "$ARTIFACT_PATHS_PATH" ]]; then
  # shellcheck source=scripts/lib/artifact-paths.sh
  . "$ARTIFACT_PATHS_PATH"
else
  # Inline fallback for copy-mode (pr-gate.sh run standalone without scripts/lib/).
  # MUST stay in sync with scripts/lib/artifact-paths.sh -- the canonical
  # artifact-leaf source of truth. See that file for the full rationale.
  PM_ARTIFACT_LEAVES=(.agent-trace .gate-briefs .gate-results)

  artifact_filter_porcelain() {
    local rec path code leaf drop expect_orig=0
    while IFS= read -r -d '' rec; do
      if [[ "$expect_orig" -eq 1 ]]; then
        expect_orig=0
        path="$rec"
      else
        code="${rec:0:2}"
        path="${rec:3}"
        [[ "$code" == R* || "$code" == C* ]] && expect_orig=1
      fi

      drop=0
      for leaf in "${PM_ARTIFACT_LEAVES[@]}"; do
        if [[ "$path" == "$leaf" || "$path" == "$leaf/"* ]]; then
          drop=1
          break
        fi
      done

      [[ "$drop" -eq 0 ]] && printf '%s\0' "$rec"
    done
    return 0
  }
fi

# Executor-name validation is delegated to resolve_executor (below): it is the
# single, data-driven authority — `auto` autodetects and any other value must be a
# routable adapter (a valid on-disk manifest), fail-closed on unknown. A hardcoded
# auto|codex|claude pre-check here would re-introduce the very enum the router refactoring removed,
# silently rejecting a manifest-only adapter before resolve_executor is reached.

_validate_isolation_level() {
  local level="$1" policy_file="$2"
  if [[ -r "$policy_file" ]]; then
    if ! grep -qE "^  - ${level}$" "$policy_file"; then
      local valid_levels
      valid_levels="$(grep -E "^  - " "$policy_file" | sed 's/^  - //' | tr '\n' ' ' | sed 's/ $//')"
      printf "Error: --isolation must be one of: %s (got: %s)\n" "$valid_levels" "$level" >&2
      return 2
    fi
  else
    case "$level" in
      none|read-only|workspace-write|workspace-network|sandboxed) ;;
      *)
        printf "Error: --isolation must be one of: none | read-only | workspace-write | workspace-network | sandboxed (got: %s)\n" "$level" >&2
        return 2
        ;;
    esac
  fi
}

if [[ -n "$DISPATCH_ISOLATION" ]]; then
  _validate_isolation_level "$DISPATCH_ISOLATION" "$SCRIPT_DIR/../core/policy/isolation-level.yaml" || exit 2
fi

EXECUTOR="$(resolve_executor "$EXECUTOR_OPTION")" || exit 2

# Every supported executor now dispatches an INDEPENDENT subprocess (codex `codex
# exec`, claude headless `claude --print`) and writes the result in-process, which
# the gate then integrity-checks. This flag is the seam where a future
# non-subprocess (e.g. host-handover) executor would branch; both current
# executors take the subprocess path.
EXECUTOR_IS_SUBPROCESS=true

unset _self _self_dir EXECUTOR_ROUTER_PATH

cd "$WORK_DIR"

# ── Load gate overrides ───────────────────────────────────────────────────────
# Auto-discover .gate-overrides.md when --override-file is not specified.
# Overrides are injected into every reviewer brief so accepted-risk items are
# not re-blocked across rounds without a material change to the reviewed code.
if [[ -z "$OVERRIDE_FILE" && -f "$WORK_DIR/.gate-overrides.md" ]]; then
  OVERRIDE_FILE="$WORK_DIR/.gate-overrides.md"
  say 'pr-gate: discovered override file: .gate-overrides.md\n'
fi
GATE_OVERRIDES_CONTENT=""
if [[ -n "$OVERRIDE_FILE" ]]; then
  if [[ ! -f "$OVERRIDE_FILE" ]]; then
    printf 'Error: override file not found: %s\n' "$OVERRIDE_FILE" >&2
    exit 2
  fi
  GATE_OVERRIDES_CONTENT=$(cat "$OVERRIDE_FILE")
  say 'pr-gate: override file loaded: %s (%d bytes)\n' "$OVERRIDE_FILE" "${#GATE_OVERRIDES_CONTENT}"
fi

# ── Detect base branch ────────────────────────────────────────────────────────
if [[ -n "$BASE_OVERRIDE" ]]; then
  BASE="$BASE_OVERRIDE"
else
  if command -v gh >/dev/null 2>&1; then
    if GH_BASE=$(gh pr view --json baseRefName -q .baseRefName 2>/dev/null); then
      if [[ -n "$GH_BASE" ]]; then
        BASE="$GH_BASE"
        say 'pr-gate: base detected from gh pr view: %s\n' "$BASE"
      else
        BASE=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || true)
        : "${BASE:=main}"
      fi
    else
      BASE=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || true)
      : "${BASE:=main}"
    fi
  else
    BASE=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || true)
    : "${BASE:=main}"
  fi
fi
if ! git rev-parse --verify "$BASE" > /dev/null 2>&1; then
  printf 'Error: base ref not found: %s\n' "$BASE" >&2
  exit 1
fi

_worktree_is_dirty() {
  # uncommitted tracked changes (staged or unstaged) ...
  if ! git diff --quiet HEAD 2>/dev/null; then return 0; fi
  # ... or any non-gitignored untracked file
  [[ -n "$(git ls-files --others --exclude-standard)" ]]
}

# ── dirty-worktree preflight ─────────────────────────────────────────────────
# When the branch has committed changes, the brief below is built from
# "$BASE"...HEAD and silently omits uncommitted tracked + untracked files
# (a prior gate missed install.sh this exact way). Fail loud so the user
# commits first for a complete, reproducible review -- unless they explicitly
# opt into reviewing the working tree as-is. A dirty-only tree with NO
# committed changes is handled by the working-tree fallback below and is NOT
# failed here (nothing is omitted in that case).
if ! git diff "$BASE"...HEAD --quiet 2>/dev/null && _worktree_is_dirty; then
  if [[ "$ALLOW_DIRTY" != true ]]; then
    _dt=$(git diff HEAD --name-only 2>/dev/null | { grep -c . || true; })
    _du=$(git ls-files --others --exclude-standard | { grep -c . || true; })
    {
      printf 'Error: working tree is dirty while the branch has committed changes against %s.\n' "$BASE"
      printf '  The review brief is built from %s...HEAD and would silently omit:\n' "$BASE"
      printf '    %s uncommitted tracked file(s), %s untracked file(s).\n' "$_dt" "$_du"
      printf '  Commit them first for a complete, reproducible review,\n'
      printf '  or pass --allow-dirty to fold the working tree into the review scope.\n'
    } >&2
    exit 3
  fi
  printf 'pr-gate: --allow-dirty set -- folding uncommitted working-tree changes into review scope\n' >&2
fi

# ── Collect diff ──────────────────────────────────────────────────────────────
# Use --name-status so renames expose BOTH old and new paths for sensitive matching.
# Use --numstat to detect binary files (shown as -\t-\t<file>).
if [[ "$ALLOW_DIRTY" == true ]] && _worktree_is_dirty; then
  # --allow-dirty: fold the working tree into scope. Two-dot diff vs BASE
  # captures committed + uncommitted tracked changes; untracked listed separately.
  DIFF_FILES=$( { git diff "$BASE" --name-status | awk '
      /^R/ { print $2; print $3; next }
      /^[AMDCT]/ { print $2 }
    '; git ls-files --others --exclude-standard; } )
  DIFF_STAT=$(git diff "$BASE" --stat)
  BINARY_HIT=$(git diff "$BASE" --numstat | { grep -c $'^-\t-\t' || true; })
  LINES=$(git diff "$BASE" --numstat | awk '
    /^-\t-\t/ { next }
    { s += $1 + $2 }
    END { print s+0 }
  ')
  UNTRACKED_NONDOC=$(git ls-files --others --exclude-standard | \
    { grep -cvE '\.(md|jsonl|txt)$|^\.gitignore$|^audits/|^docs/' || true; })
  BINARY_HIT=$((BINARY_HIT + UNTRACKED_NONDOC))
elif ! git diff "$BASE"...HEAD --quiet 2>/dev/null; then
  # For renames (R* status lines), emit both old and new path so sensitive
  # keywords in the old name (e.g. auth.ts → login.ts) are not lost.
  DIFF_FILES=$(git diff "$BASE"...HEAD --name-status | awk '
    /^R/ { print $2; print $3; next }
    /^[AMDCT]/ { print $2 }
  ')
  DIFF_STAT=$(git diff "$BASE"...HEAD --stat)
  BINARY_HIT=$(git diff "$BASE"...HEAD --numstat | { grep -c $'^-\t-\t' || true; })
  LINES=$(git diff "$BASE"...HEAD --numstat | awk '
    /^-\t-\t/ { next }
    { s += $1 + $2 }
    END { print s+0 }
  ')
else
  # No branch commits -- fall back to working tree changes
  DIFF_FILES=$(git diff HEAD --name-only; git ls-files --others --exclude-standard)
  DIFF_STAT=$(git diff HEAD --stat)
  BINARY_HIT=$(git diff HEAD --numstat | { grep -c $'^-\t-\t' || true; })
  LINES=$(git diff HEAD --numstat | awk '
    /^-\t-\t/ { next }
    { s += $1 + $2 }
    END { print s+0 }
  ')
  # Untracked non-doc files are not included in git diff HEAD --numstat, so
  # BINARY_HIT and LINES would both be 0, silently routing to express.
  # Treat each untracked non-doc file as a binary (unknown size) to prevent
  # under-tiering.
  UNTRACKED_NONDOC=$(git ls-files --others --exclude-standard | \
    { grep -cvE '\.(md|jsonl|txt)$|^\.gitignore$|^audits/|^docs/' || true; })
  BINARY_HIT=$((BINARY_HIT + UNTRACKED_NONDOC))
fi

if [[ -z "$DIFF_FILES" ]]; then
  printf 'Error: no changed files detected against %s\n' "$BASE" >&2; exit 1
fi

# ── Detect tier ───────────────────────────────────────────────────────────────
if [[ -n "$TIER_OVERRIDE" ]]; then
  TIER="$TIER_OVERRIDE"
elif [[ -n "$REVIEWERS_OVERRIDE" ]]; then
  TIER="targeted"
else
  NON_DOCS=$(printf '%s\n' "$DIFF_FILES" | grep -vE '\.(md|jsonl|txt)$|^\.gitignore$|^audits/|^docs/' || true)
  SENSITIVE_HIT=$(printf '%s\n' "$DIFF_FILES" | { grep -iE '(^|[/_.-])(auth|oauth|jwt|session|secret|password|token|credential|cors|csrf|webhook|sudo|ssh|payment|billing)([/_.-]|$)|(^|/)migrations?/|^\.github/' || true; } | wc -l)

  if [[ -z "$NON_DOCS" ]]; then
    TIER=express
  elif [[ "$SENSITIVE_HIT" -gt 0 || "$LINES" -gt 500 ]]; then
    TIER=full
  elif [[ "$LINES" -lt 100 && "${BINARY_HIT:-0}" -eq 0 ]]; then
    # Binary files have no line count but represent real changes -- treat as standard+
    TIER=express
  else
    TIER=standard
  fi
fi

# ── Brief-based tier suggestion (advisory; never overrides --tier) ────────────
if [[ -n "$BRIEF_FILE" && -f "$BRIEF_FILE" && -z "$TIER_OVERRIDE" ]]; then
  _brief_arch_impact="$(awk '/^architecture_impact:[[:space:]]*/{sub(/^architecture_impact:[[:space:]]*/,""); gsub(/[[:space:]]/,""); print; exit}' "$BRIEF_FILE")"
  case "$_brief_arch_impact" in
    major)
      if [[ "$TIER" != "full" ]]; then
        printf 'pr-gate: brief architecture_impact:major — suggested tier: full (detected: %s). Override with --tier full or continue with current tier.\n' "$TIER" >&2
      fi
      ;;
    minor)
      if [[ "$TIER" == "express" ]]; then
        printf 'pr-gate: brief architecture_impact:minor — suggested tier: standard (detected: %s). Override with --tier standard or continue with current tier.\n' "$TIER" >&2
      fi
      ;;
  esac
fi

# ── Determine reviewer list ───────────────────────────────────────────────────
ALL_REVIEWERS="critic qa-tester architecture-reviewer security-reviewer risk-reviewer"

if [[ -n "$REVIEWERS_OVERRIDE" ]]; then
  REVIEWERS=$(printf '%s' "$REVIEWERS_OVERRIDE" | tr ',' ' ')
else
  case "$TIER" in
    express)  REVIEWERS="critic qa-tester";;
    standard) REVIEWERS="critic qa-tester architecture-reviewer";;
    full)     REVIEWERS="$ALL_REVIEWERS";;
    *)        REVIEWERS="$ALL_REVIEWERS";;
  esac
fi

REVIEWER_DISPLAY=$(printf '%s' "$REVIEWERS" | tr ' ' ',')
NUM_REVIEWERS=$(printf '%s\n' $REVIEWERS | wc -l | tr -d ' ')

# Compute skipped dimensions
SKIPPED=""
for r in $ALL_REVIEWERS; do
  if ! printf '%s' "$REVIEWERS" | grep -qw "$r"; then
    SKIPPED="${SKIPPED:+$SKIPPED, }$r"
  fi
done
SKIPPED_DISPLAY="${SKIPPED:-none}"

# ── Resolve agent definitions dir ────────────────────────────────────────────
AGENT_DIR="${HOME}/.claude/agents"
if [[ ! -d "$AGENT_DIR" ]]; then
  printf 'Error: agent dir not found: %s\n' "$AGENT_DIR" >&2; exit 1
fi

# Validate all reviewer agent files exist before doing any work
for r in $REVIEWERS; do
  AGENT_PATH="$AGENT_DIR/${r}.md"
  if [[ ! -f "$AGENT_PATH" ]]; then
    printf 'Error: reviewer agent file not found: %s\n' "$AGENT_PATH" >&2
    exit 1
  fi
done

# ── Prepare output paths ─────────────────────────────────────────────────────
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
_ARTIFACT_ROOT="${GATE_RUN_DIR_OVERRIDE:-$WORK_DIR}"
BRIEF_DIR="$_ARTIFACT_ROOT/.gate-briefs"
mkdir -p "$BRIEF_DIR"
# Route executor traces (adapter JSONL/last/stderr) to the run dir when provided.
# PM_DISPATCH_TRACE_DIR is read by dispatch_via (lib and copy-mode) to forward
# --trace-dir to the adapter, so the adapter's own trace files follow the run dir.
if [[ -n "$GATE_RUN_DIR_OVERRIDE" ]]; then
  export PM_DISPATCH_TRACE_DIR="$GATE_RUN_DIR_OVERRIDE/.agent-trace"
fi

# OUTPUT_FILE must be in WORK_DIR so the executor (codex/claude, workspace-write sandbox)
# can write it. After final verification the gate moves it to _ARTIFACT_ROOT if a run dir
# was supplied. --output explicit override is always used verbatim, no move.
OUTPUT_FILE="${OUTPUT_OVERRIDE:-$WORK_DIR/.gate-results/gate-${TIMESTAMP}.md}"
# Normalize to an absolute path. The reviewer write-guard (guard-reviewer-write.sh)
# requires an absolute file_path, and the pr-gate-handover_v1 schema mandates an absolute
# output_file. A relative --output (or a relative --cd default) would otherwise be embedded
# verbatim into the reviewer brief's `pmctl guard check` constraint, making the guard exit
# nonzero and the reviewer abort the write -- the 0-byte-result failure mode, for any executor.
# Ordering dependency: this relies on the earlier `cd "$WORK_DIR"` having already run, so $PWD
# here IS the absolute working dir and a relative OUTPUT_FILE resolves to an absolute path under it.
[[ "$OUTPUT_FILE" = /* ]] || OUTPUT_FILE="$PWD/$OUTPUT_FILE"
mkdir -p "$(dirname "$OUTPUT_FILE")"
touch "$OUTPUT_FILE"

# Track all brief files for EXIT cleanup
BRIEF_FILES=()
cleanup_briefs() {
  # Every executor now dispatches a subprocess (codex `codex exec`, claude headless
  # `claude --print`), so generated briefs are always transient and cleaned on exit.
  for bf in "${BRIEF_FILES[@]:-}"; do
    rm -f "$bf"
  done
}

# Relocate gate result artifacts out of the repo when a run dir was supplied.
# OUTPUT_FILE (and parallel reviewer outputs) must be written under WORK_DIR for the
# executor's workspace-write sandbox, so they start repo-local. This helper moves them
# to $GATE_RUN_DIR_OVERRIDE/.gate-results and drops the now-empty in-repo dir.
# Idempotent and safe to call repeatedly:
#   - no-op in legacy mode (no --run-dir) or with an explicit --output override, so the
#     in-repo default path and verbatim --output behavior are preserved (backward compat);
#   - no-op once WORK_DIR/.gate-results has been drained.
# Called BOTH on the success path (before the result: print, so the printed path and the
# NO-GO grep read the relocated copy) AND from the EXIT trap (so every failure path that
# already created the in-repo result relocates it out instead of leaking repo artifacts).
relocate_gate_artifacts() {
  [[ -n "$GATE_RUN_DIR_OVERRIDE" && -z "$OUTPUT_OVERRIDE" ]] || return 0
  [[ -d "$WORK_DIR/.gate-results" ]] || return 0
  local _result_dest_dir="$GATE_RUN_DIR_OVERRIDE/.gate-results" _rf
  mkdir -p "$_result_dest_dir"
  # Move only this run's artifacts (all carry $TIMESTAMP in the filename) so a concurrent
  # gate run sharing WORK_DIR/.gate-results keeps its own in-flight files.
  for _rf in "$WORK_DIR/.gate-results/"*"${TIMESTAMP}"*; do
    [[ -e "$_rf" ]] || continue
    mv "$_rf" "$_result_dest_dir/"
  done
  # Repoint OUTPUT_FILE to the relocated primary result so later reads (result: print,
  # NO-GO grep) follow it out of the repo.
  if [[ "$OUTPUT_FILE" == "$WORK_DIR/.gate-results/"* ]]; then
    OUTPUT_FILE="$_result_dest_dir/$(basename "$OUTPUT_FILE")"
  fi
  # Drop the in-repo dir only if now empty (tolerate a concurrent run's files).
  rmdir "$WORK_DIR/.gate-results" 2>/dev/null || true
}

gate_exit_cleanup() {
  # Relocate first (preserves the result artifact out-of-repo for post-mortem on failure
  # paths), then drop transient briefs. Both are idempotent / no-ops on the success path
  # where relocation already ran inline.
  relocate_gate_artifacts
  cleanup_briefs
}
trap gate_exit_cleanup EXIT

SYNTHESIS_BRIEF="$BRIEF_DIR/pr-gate-${TIMESTAMP}-synthesis.md"
BRIEF_FILES+=("$SYNTHESIS_BRIEF")

# Build a compact index of verified reference files (agents/, commands/, docs/, skills/)
# for injection into gate brief preambles. Reviewers may cite docs/sections
# that don't exist; the index provides ground truth so they can verify before citing.
_build_repo_ref_index() {
  local work_dir="$1" out=""
  for d in agents commands docs skills; do
    [[ -d "$work_dir/$d" ]] || continue
    while IFS= read -r f; do
      out="${out}    ${f#"$work_dir/"}"$'\n'
    done < <(find "$work_dir/$d" -maxdepth 2 -name "*.md" 2>/dev/null | sort)
  done
  printf '%s' "$out"
}


# ── Find adjacent test files not in the diff ─────────────────────────────────
# For each changed source file, locate its companion test file if it exists and
# is not already included in the diff. Including adjacent tests allows reviewers
# to detect coverage gaps in unchanged test files alongside changed source.
#
# Go:         <pkg>/<name>.go       → <pkg>/<name>_test.go
# TypeScript: <dir>/<name>.ts(x)    → <dir>/__tests__/<name>.test.ts(x)
#                                   → <dir>/<name>.test.ts(x)
ADJACENT_TEST_FILES=""
while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  case "$f" in
    *.go)
      base="$(basename "$f")"
      if [[ "$base" != *_test.go ]]; then
        testfile="${f%.go}_test.go"
        if [[ -f "$WORK_DIR/$testfile" ]] && ! printf '%s\n' "$DIFF_FILES" | grep -qxF "$testfile"; then
          ADJACENT_TEST_FILES="${ADJACENT_TEST_FILES}${testfile}"$'\n'
        fi
      fi
      ;;
    *.ts|*.tsx)
      base="$(basename "$f")"
      case "$base" in *.test.ts|*.test.tsx|*.spec.ts|*.spec.tsx) continue ;; esac
      bname="${base%.*}"
      dname="$(dirname "$f")"
      for candidate in \
          "${dname}/__tests__/${bname}.test.ts" \
          "${dname}/__tests__/${bname}.test.tsx" \
          "${dname}/__tests__/${bname}.spec.ts" \
          "${dname}/__tests__/${bname}.spec.tsx" \
          "${dname}/${bname}.test.ts" \
          "${dname}/${bname}.test.tsx" \
          "${dname}/${bname}.spec.ts" \
          "${dname}/${bname}.spec.tsx"; do
        if [[ -f "$WORK_DIR/$candidate" ]] && ! printf '%s\n' "$DIFF_FILES" | grep -qxF "$candidate"; then
          ADJACENT_TEST_FILES="${ADJACENT_TEST_FILES}${candidate}"$'\n'
        fi
      done
      ;;
  esac
done <<< "$DIFF_FILES"

# ── Build combined review file list ──────────────────────────────────────────
ALL_REVIEW_FILES="$DIFF_FILES"
if [[ -n "$ADJACENT_TEST_FILES" ]]; then
  ALL_REVIEW_FILES="$(printf '%s\n%s' "$ALL_REVIEW_FILES" "$ADJACENT_TEST_FILES" | sort -u | grep -v '^$')"
fi

DIFF_FILE_ENTRIES=""
while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  fp="$WORK_DIR/$f"
  [[ -f "$fp" ]] && DIFF_FILE_ENTRIES="${DIFF_FILE_ENTRIES}  - read: ${fp}"$'\n'
done <<< "$ALL_REVIEW_FILES"

DIFF_STAT_INDENTED=$(printf '%s\n' "$DIFF_STAT" | sed 's/^/    /')
REPO_REF_INDEX="$(_build_repo_ref_index "$WORK_DIR")"
ADJ_COUNT=$(printf '%s\n' "$ADJACENT_TEST_FILES" | grep -c '[^[:space:]]' 2>/dev/null || true)

# Render the accepted-risk override context block injected into EVERY reviewer
# and synthesis brief. Single source of truth: all three brief templates
# (sequential, parallel reviewer, parallel synthesis) reference the one
# ${GATE_OVERRIDES_CONTEXT_BLOCK} this produces, so an override-rendering change
# lands in exactly one place. Emits the empty string when there are no overrides.
render_gate_overrides_block() {
  local content="$1" indented
  [[ -z "$content" ]] && return 0
  indented=$(printf '%s\n' "$content" | sed 's/^/  /')
  printf '  Accepted-risk overrides (do NOT re-block these unless the diff materially\n  changes the accepted risk -- re-raising an already-accepted override when the\n  code has not changed is a false-positive that must be suppressed):\n%s\n' "$indented"
}

# Pre-format the override block for heredoc injection (empty when no overrides).
GATE_OVERRIDES_CONTEXT_BLOCK="$(render_gate_overrides_block "$GATE_OVERRIDES_CONTENT")"

say 'pr-gate: %s tier -- %s\n' "$TIER" "$REVIEWER_DISPLAY"
[[ "${ADJ_COUNT:-0}" -gt 0 ]] && say '  adjacent test files added: %d\n' "$ADJ_COUNT"
say 'result will be written to: %s\n\n' "$OUTPUT_FILE"

# ── Pre-gate hook ──────────────────────────────────────────────────────────
_PRE_GATE_HOOK="$WORK_DIR/.pm-dispatch/pre-gate.sh"
if [[ "$ALLOW_HOOKS" != "true" ]]; then
  if [[ -f "$_PRE_GATE_HOOK" ]]; then
    printf 'Warning: .pm-dispatch/pre-gate.sh present but skipped -- pass --allow-hooks to execute repo-local hook scripts\n' >&2
  fi
elif [[ -f "$_PRE_GATE_HOOK" && ! -x "$_PRE_GATE_HOOK" ]]; then
  printf 'Warning: .pm-dispatch/pre-gate.sh exists but is not executable -- skipping\n' >&2
elif [[ -x "$_PRE_GATE_HOOK" ]]; then
  say 'Running pre-gate hook: .pm-dispatch/pre-gate.sh\n'
  if ! (cd "$WORK_DIR" && bash "$_PRE_GATE_HOOK"); then
    printf 'Error: pre-gate hook failed -- gate aborted\n' >&2
    exit 1
  fi
  say 'pre-gate hook completed.\n\n'
fi

# ── Dispatch ─────────────────────────────────────────────────────────────────
if [[ "$SEQUENTIAL" == "true" ]]; then

  # ── Sequential mode (default: all reviewers in one combined codex session) ──
  AGENT_FILE_ENTRIES=""
  for r in $REVIEWERS; do
    AGENT_PATH="$AGENT_DIR/${r}.md"
    AGENT_FILE_ENTRIES="${AGENT_FILE_ENTRIES}  - read: ${AGENT_PATH}"$'\n'
  done

  BRIEF_FILE="$BRIEF_DIR/pr-gate-${TIMESTAMP}.md"
  BRIEF_FILES+=("$BRIEF_FILE")

  cat > "$BRIEF_FILE" << BRIEF_EOF
schema_version: 1
working_dir: ${WORK_DIR}

goal: Sequential ${TIER}-tier PR-gate review. Apply each reviewer's criteria to the changed files and write a structured verdict to ${OUTPUT_FILE}.

files:
${AGENT_FILE_ENTRIES}${DIFF_FILE_ENTRIES}  - new:  ${OUTPUT_FILE}

constraints:
  - Do NOT modify any source file.
  - Only write ${OUTPUT_FILE}.
  - Before writing ${OUTPUT_FILE}, call: pmctl guard check --role reviewer --runtime ${EXECUTOR} --event pre-write --file ${OUTPUT_FILE}
    If that call exits nonzero, abort and report the guard denial -- do NOT write the file.
  - Create parent directories for ${OUTPUT_FILE} if needed (mkdir -p).
  - Only cite files in the verified reference index or the diff list. Read a file before citing its sections; do not invent citations.

context:
  Tier: ${TIER}
  Executor: ${EXECUTOR}
  Reviewers: ${REVIEWER_DISPLAY}
  Not reviewed: ${SKIPPED_DISPLAY}
  Base: ${BASE}
  Scope: ${SCOPE:-none}
  Date: $(date '+%Y-%m-%d')
${GATE_OVERRIDES_CONTEXT_BLOCK}
  Verified reference files (exist in working tree -- check before citing):
${REPO_REF_INDEX}
  Diff (${LINES} changed lines):
${DIFF_STAT_INDENTED}

task:
  Process each reviewer IN ORDER: ${REVIEWER_DISPLAY}

  For EACH reviewer:
  1. Read their agent definition file (listed above). Follow any boot instructions
     and internalize their specific review criteria and verdict scale.
  2. Review the changed files from that reviewer's perspective only.
  3. Produce a structured findings block:
     - Findings with severity (low/medium/high) and location
     - Explicit verdict: approve | advise | block-soft | block

  After all reviewers, synthesize as project-pm would:
  4. Identify cross-reviewer overlaps (same issue raised by multiple reviewers)
  5. Overall verdict = most severe individual verdict
  6. State which dimensions were NOT covered (not-reviewed list above)
  7. Final GO (no blocks) / NO-GO (any block or block-soft) with rationale and override path if applicable

  Write the complete result to ${OUTPUT_FILE}.

output_format: |
  ---
  gate_result_version: pr_gate_result_v1
  final: GO|NO-GO
  tier: express|standard|full|targeted
  mode: sequential
  most_severe: approve|advise|block-soft|block
  reviewers:
    critic: approve|advise|block-soft|skipped
    qa-tester: pass|needs-tests|block|skipped
    architecture-reviewer: approve|advise|block-soft|skipped
    security-reviewer: pass|block|pass-not-applicable|skipped
    risk-reviewer: pass|block|pass-not-applicable|skipped
  escalation:
    recommended: true|false
    reviewers: []
    reason: []
  ---

  # PR-Gate Result -- ${TIER} tier (${EXECUTOR} mode)
  **Date**: $(date '+%Y-%m-%d')
  **Reviewers**: ${REVIEWER_DISPLAY}
  **Not reviewed**: ${SKIPPED_DISPLAY}

  ## {reviewer-name} -- {verdict}
  {findings, one per bullet, with [severity] and file:line}

  (repeat for each reviewer in order)

  ## Cross-Reviewer Overlaps
  {list issues raised by >1 reviewer; "none" if clean}

  ## Coverage Notes
  **Dimensions not covered**: ${SKIPPED_DISPLAY}

  ## Gate Conclusion
  **Overall verdict**: {most severe}
  **Most severe individual verdict**: {most severe}
  Final: GO|NO-GO
  {required fixes if NO-GO; override path if any block-soft}

  CRITICAL -- the Final: line above MUST be emitted EXACTLY in this shape:
  - plain text, no markdown emphasis (NO surrounding **, NO backticks, NO italic)
  - at start of line (no leading whitespace)
  - literal token GO or NO-GO (uppercase, hyphen for NO-GO)
  - matched by the regex ^Final: (GO|NO-GO)\$
  - the value MUST equal the frontmatter \`final:\` field (case-sensitive)
  Examples that BREAK the parser and MUST NOT be emitted: \`**Final: GO**\`, \`Final: **GO**\`, \` Final: GO\`, \`Final: Go\`.

  ## Escalation
  **Recommended**: true|false
  **Reviewers**: <comma-list or "none">
  **Reason**:
  - <bullet> (or "none" when recommended=false)

  Escalation is recommended when:
  (a) any diff file matches (^|[/_.-])(auth|oauth|jwt|session|secret|password|token|credential|cors|csrf|webhook|sudo|ssh|payment|billing)([/_.-]|\$)|(^|/)migrations?/|^\.github/
  (b) at least one reviewer returned advise|block-soft.

self_verify:
  - cmd: "test -f ${OUTPUT_FILE}"
  - has-conclusion: grep -cE '^Final: (GO|NO-GO)\$' ${OUTPUT_FILE} should be exactly 1
  - frontmatter-final-parity: the value after \`final:\` in the YAML frontmatter MUST equal the value after \`Final:\` in Gate Conclusion (case-sensitive)

acceptance:
  - ${OUTPUT_FILE} exists with a verdict section for each of the ${NUM_REVIEWERS} reviewers
  - "Final: GO" or "Final: NO-GO" is present in Gate Conclusion (plain text, no markdown emphasis)
BRIEF_EOF

  # Every executor dispatches an independent subprocess (codex `codex exec`, claude
  # headless `claude --print`). The generic dispatch_via takes the executor name as
  # its first arg, so the call site is uniform; sandbox/approval are forwarded only
  # to adapters whose runner_kind accepts them.
  DISPATCH_CMD="$(dispatch_via "$EXECUTOR" "$BRIEF_FILE" "$WORK_DIR" "$DISPATCH_MODEL" "$DISPATCH_SANDBOX" "$DISPATCH_APPROVAL" "$TIMEOUT" "$DISPATCH_ISOLATION")" || exit 2
  # Send the dispatch child's stdout to our stderr: it is diagnostic chatter,
  # not gate data (the verdict lands in the result file). If it inherited our
  # stdout and a consumer closed that pipe (`gate run | head`), the child's
  # first write would hit EPIPE and -- with SIGPIPE ignored + set -e -- exit
  # nonzero before writing the result, killing the gate before its integrity
  # checks could fire. Parallel reviewers already redirect to a log.
  eval "$DISPATCH_CMD" >&2

  # Validate single-session output via the shared contract (must exist, be
  # non-empty, carry exactly one Final: GO|NO-GO line that agrees with the
  # frontmatter final: field). Same checks the parallel synthesis route and
  # `pmctl gate verify` enforce.
  gate_result_verify "$OUTPUT_FILE" "" "sequential gate" || exit 1

else

  # ── Multi-session mode (--parallel): one independent dispatch per reviewer + synthesis ──
  # Each reviewer runs in its own session with no shared context -- eliminates
  # anchoring bias that can occur when all reviewers share one session window.
  # Followed by a PM synthesis session that consolidates all individual results.
  # Higher token cost vs single-session; suitable for auth/payment/migration paths.

  REVIEWER_OUTPUT_FILES=()
  DISPATCH_PIDS=()
  REVIEWER_NAMES=()

  mkdir -p "$_ARTIFACT_ROOT/.agent-trace"

  # Resolve a portable hash command; fail-closed if none is available or usable.
  # sha256sum (GNU coreutils) is preferred; shasum -a 256 covers macOS/BSD.
  # Both presence (command -v) AND usability (echo | cmd) are verified so a
  # broken stub or wrong-architecture binary is caught before the integrity guard.
  _HASH_CMD=""
  if command -v sha256sum > /dev/null 2>&1 && printf '' | sha256sum > /dev/null 2>&1; then
    _HASH_CMD="sha256sum"
  elif command -v shasum > /dev/null 2>&1 && printf '' | shasum -a 256 > /dev/null 2>&1; then
    _HASH_CMD="shasum -a 256"
  fi
  if [[ -z "$_HASH_CMD" ]]; then
    printf 'Error: no sha256sum or shasum found -- cannot fingerprint worktree for injection detection.\n' >&2
    exit 1
  fi

  # Capture working-tree content fingerprints before dispatch.
  # git diff HEAD: content-level changes to tracked files (catches already-dirty mutations).
  # git status --porcelain -z: new untracked source files. The gate's own artifacts
  # (.agent-trace/ .gate-briefs/ .gate-results/) are excluded explicitly via
  # artifact_filter_porcelain -- the canonical artifact-leaf source of truth in
  # scripts/lib/artifact-paths.sh -- so a repo that has NOT had these paths gitignored
  # is not misread as prompt-injected. NUL-delimited (-z) so special filenames survive.
  _PRE_DISPATCH_DIFF=$(git diff HEAD 2>/dev/null | $_HASH_CMD)
  _PRE_DISPATCH_STATUS=$(git status --porcelain -z 2>/dev/null | artifact_filter_porcelain | $_HASH_CMD)

  for r in $REVIEWERS; do
    AGENT_PATH="$AGENT_DIR/${r}.md"
    REVIEWER_OUTPUT="$WORK_DIR/.gate-results/reviewer-${r}-${TIMESTAMP}.md"
    REVIEWER_BRIEF="$BRIEF_DIR/pr-gate-${TIMESTAMP}-${r}.md"
    DISPATCH_LOG="$_ARTIFACT_ROOT/.agent-trace/gate-${TIMESTAMP}-${r}.log"

    BRIEF_FILES+=("$REVIEWER_BRIEF")
    REVIEWER_OUTPUT_FILES+=("$REVIEWER_OUTPUT")
    REVIEWER_NAMES+=("$r")

    cat > "$REVIEWER_BRIEF" << RBRIEF_EOF
schema_version: 1
working_dir: ${WORK_DIR}

goal: You are acting as the ${r} reviewer. Read your agent definition, apply your specific review criteria to the changed files, and write your structured findings to ${REVIEWER_OUTPUT}.

files:
  - read: ${AGENT_PATH}
${DIFF_FILE_ENTRIES}  - new:  ${REVIEWER_OUTPUT}

constraints:
  - Do NOT modify any source file.
  - Only write ${REVIEWER_OUTPUT}.
  - Before writing ${REVIEWER_OUTPUT}, call: pmctl guard check --role reviewer --runtime ${EXECUTOR} --event pre-write --file ${REVIEWER_OUTPUT}
    If that call exits nonzero, abort and report the guard denial -- do NOT write the file.
  - Create parent directories if needed (mkdir -p).
  - Only cite files in the verified reference index or the diff list. Read a file before citing its sections; do not invent citations.

context:
  Tier: ${TIER}
  Executor: ${EXECUTOR}
  Reviewer: ${r}
  Base: ${BASE}
  Scope: ${SCOPE:-none}
  Date: $(date '+%Y-%m-%d')
${GATE_OVERRIDES_CONTEXT_BLOCK}
  Verified reference files (exist in working tree -- check before citing):
${REPO_REF_INDEX}
  Diff (${LINES} changed lines):
${DIFF_STAT_INDENTED}

task:
  1. Read your agent definition (${AGENT_PATH}). Follow its boot instructions
     and internalize your specific review criteria and verdict scale.
  2. Review the changed files strictly from the ${r} perspective only.
     Do not attempt to cover other reviewer dimensions.
  3. Write a structured findings block with:
     - Findings: [severity] file:line -- description (low/medium/high)
     - Explicit verdict: approve | advise | block-soft | block
     - One-sentence rationale for your verdict

  Write your complete review to ${REVIEWER_OUTPUT}.

output_format: |
  ## ${r} -- {verdict}
  - [{severity}] {file:line} -- {finding description}

  Verdict: {approve | advise | block-soft | block}. {One-sentence rationale.}

self_verify:
  - cmd: "test -f ${REVIEWER_OUTPUT}"

acceptance:
  - ${REVIEWER_OUTPUT} exists with at least one findings line and an explicit Verdict line
RBRIEF_EOF

    REVIEWER_DISPATCH_CMD="$(dispatch_via "$EXECUTOR" "$REVIEWER_BRIEF" "$WORK_DIR" "$DISPATCH_MODEL" "$DISPATCH_SANDBOX" "$DISPATCH_APPROVAL" "$TIMEOUT" "$DISPATCH_ISOLATION")" || exit 2
    eval "$REVIEWER_DISPATCH_CMD" > "$DISPATCH_LOG" 2>&1 &
    DISPATCH_PIDS+=($!)
    say '  [parallel] launched %s (pid %d)\n' "$r" "$!"
  done

  # Subprocess executors launched the reviewers as background children above;
  # wait for them, validate each output, then synthesize (all in-process).
  if [[ "$EXECUTOR_IS_SUBPROCESS" == true ]]; then
    say '\n  waiting for %d reviewer session(s)...\n' "${#DISPATCH_PIDS[@]}"

    # Watchdog: kill any reviewer subprocess that hasn't exited after the fan-out
    # timeout. Defense-in-depth: pmctl already passes --timeout to the executor,
    # but if pmctl itself hangs the inner timeout never fires. Watchdog timeout =
    # per-reviewer TIMEOUT + 60s overhead; override via _PM_DISPATCH_GATE_WATCHDOG_TIMEOUT.
    _GATE_WATCHDOG_TIMEOUT="${_PM_DISPATCH_GATE_WATCHDOG_TIMEOUT:-$((TIMEOUT + 60))}"
    (
      sleep "$_GATE_WATCHDOG_TIMEOUT"
      for _wpid in "${DISPATCH_PIDS[@]}"; do
        _kill_process_tree "$_wpid" TERM
      done
    ) &
    _GATE_WATCHDOG_PID=$!

    # Wait for all reviewer sessions. Any non-zero exit aborts the gate -- an
    # incomplete review cannot certify a valid gate result.
    # Hash each reviewer output immediately after its PID exits so we capture
    # the content before any concurrently-running reviewer session can modify it.
    # Exit code > 128 means killed by signal (SIGTERM=143); attribute these as
    # timeouts (watchdog fired) rather than clean executor failures.
    FAILED_REVIEWERS=()
    TIMED_OUT_REVIEWERS=()
    REVIEWER_POST_WAIT_HASHES=()
    for i in "${!DISPATCH_PIDS[@]}"; do
      pid="${DISPATCH_PIDS[$i]}"
      r="${REVIEWER_NAMES[$i]}"
      rf="${REVIEWER_OUTPUT_FILES[$i]}"
      _wait_exit=0
      wait "$pid" || _wait_exit=$?
      if [[ "$_wait_exit" -ne 0 ]]; then
        [[ "$_wait_exit" -gt 128 ]] && TIMED_OUT_REVIEWERS+=("$r")
        FAILED_REVIEWERS+=("$r")
        REVIEWER_POST_WAIT_HASHES+=("none")
      else
        REVIEWER_POST_WAIT_HASHES+=("$(cat "$rf" 2>/dev/null | $_HASH_CMD || echo 'missing')")
      fi
    done

    # Kill watchdog if reviewers finished before the deadline.
    kill "$_GATE_WATCHDOG_PID" 2>/dev/null || true
    wait "$_GATE_WATCHDOG_PID" 2>/dev/null || true

    if [[ "${#TIMED_OUT_REVIEWERS[@]}" -gt 0 ]]; then
      printf 'Timeout: %d reviewer session(s) did not complete within %ds: %s\n' \
        "${#TIMED_OUT_REVIEWERS[@]}" "$_GATE_WATCHDOG_TIMEOUT" "${TIMED_OUT_REVIEWERS[*]}" >&2
    fi
    if [[ "${#FAILED_REVIEWERS[@]}" -gt 0 ]]; then
      printf 'Error: %d reviewer session(s) failed: %s\n' \
        "${#FAILED_REVIEWERS[@]}" "${FAILED_REVIEWERS[*]}" >&2
      printf 'Gate aborted -- fix the failing session or use --sequential to diagnose.\n' >&2
      exit 1
    fi

    # Verify every reviewer wrote a non-empty output file -- a codex session can
    # exit 0 without completing its task, which would leave the synthesis brief
    # with nothing to consolidate and could produce a spurious GO.
    MISSING_OUTPUTS=()
    for i in "${!REVIEWER_OUTPUT_FILES[@]}"; do
      rf="${REVIEWER_OUTPUT_FILES[$i]}"
      r="${REVIEWER_NAMES[$i]}"
      if [[ ! -s "$rf" ]]; then
        MISSING_OUTPUTS+=("$r")
      fi
    done
    if [[ "${#MISSING_OUTPUTS[@]}" -gt 0 ]]; then
      printf 'Error: reviewer output missing or empty for: %s\n' "${MISSING_OUTPUTS[*]}" >&2
      printf 'A reviewer session may have exited 0 without writing its findings file.\n' >&2
      printf 'Gate aborted -- use --sequential to diagnose.\n' >&2
      exit 1
    fi

    # Verify every reviewer output contains exactly one parseable verdict line before synthesis.
    # Zero lines → malformed output; two or more lines → ambiguous (first-match would silently
    # ignore a later more-severe verdict). Both cases must be rejected fail-closed.
    INVALID_OUTPUTS=()
    for i in "${!REVIEWER_OUTPUT_FILES[@]}"; do
      rf="${REVIEWER_OUTPUT_FILES[$i]}"
      r="${REVIEWER_NAMES[$i]}"
      verdict_count=$(grep -cE '^Verdict: (approve|advise|block-soft|block)([. ]|$)' "$rf" || true)
      if [[ "$verdict_count" -ne 1 ]]; then
        INVALID_OUTPUTS+=("$r (found $verdict_count)")
      fi
    done
    if [[ "${#INVALID_OUTPUTS[@]}" -gt 0 ]]; then
      printf 'Error: reviewer output must contain exactly one valid Verdict line for: %s\n' "${INVALID_OUTPUTS[*]}" >&2
      printf 'Expected: exactly one of: Verdict: approve|advise|block-soft|block\n' >&2
      printf 'Gate aborted -- use --sequential to diagnose.\n' >&2
      exit 1
    fi

    # Cross-reviewer artifact tamper detection: re-hash every reviewer output and
    # compare with the hash captured immediately after that reviewer's PID exited.
    # A mismatch means a concurrently-running reviewer session modified this file
    # after it was completed -- fail closed before synthesis can run on tainted data.
    CROSS_TAMPERED=()
    for i in "${!REVIEWER_OUTPUT_FILES[@]}"; do
      rf="${REVIEWER_OUTPUT_FILES[$i]}"
      r="${REVIEWER_NAMES[$i]}"
      expected="${REVIEWER_POST_WAIT_HASHES[$i]}"
      [[ "$expected" == "none" ]] && continue
      current="$(cat "$rf" 2>/dev/null | $_HASH_CMD || echo 'missing')"
      if [[ "$current" != "$expected" ]]; then
        CROSS_TAMPERED+=("$r")
      fi
    done
    if [[ "${#CROSS_TAMPERED[@]}" -gt 0 ]]; then
      printf 'Error: reviewer artifact modified after that reviewer session completed: %s\n' "${CROSS_TAMPERED[*]}" >&2
      printf 'Possible cross-reviewer artifact tampering in --parallel mode. Gate aborted.\n' >&2
      exit 1
    fi

  # Worktree integrity check -- detect prompt-injected tracked-file modifications.
  # Content-hash catches mutations to already-dirty tracked files; status hash
  # catches new untracked source files. Gate artifacts are excluded explicitly via
  # artifact_filter_porcelain (scripts/lib/artifact-paths.sh) -- the pre/post sides
  # MUST use the same filter or the hashes can never match. -z keeps special filenames intact.
  _POST_DISPATCH_DIFF=$(git diff HEAD 2>/dev/null | $_HASH_CMD)
  _POST_DISPATCH_STATUS=$(git status --porcelain -z 2>/dev/null | artifact_filter_porcelain | $_HASH_CMD)
  if [[ "$_PRE_DISPATCH_DIFF" != "$_POST_DISPATCH_DIFF" || "$_PRE_DISPATCH_STATUS" != "$_POST_DISPATCH_STATUS" ]]; then
    printf 'Error: reviewer sessions modified working tree -- possible prompt injection.\n' >&2
    printf 'Gate aborted. Inspect the reviewer dispatch logs under .agent-trace/ for details.\n' >&2
    exit 1
  fi

  # Reviewer artifact integrity -- snapshot each reviewer output file content now,
  # before synthesis, to detect synthesis-side tampering of reviewer artifacts.
  # Reviewer outputs are gitignored and not covered by the worktree hash above.
  REVIEWER_ARTIFACT_HASHES=()
  for rf in "${REVIEWER_OUTPUT_FILES[@]}"; do
    REVIEWER_ARTIFACT_HASHES+=("$(cat "$rf" | $_HASH_CMD)")
  done

  say '  all reviewer sessions done.\n\n'

  # Compute the final verdict deterministically in shell before synthesis.
  # Synthesis is treated as prose-only; the shell verdict is the authoritative gate result.
  SHELL_VERDICT="approve"
  for rf in "${REVIEWER_OUTPUT_FILES[@]}"; do
    rv=$(grep -oE '^Verdict: (approve|advise|block-soft|block)([. ]|$)' "$rf" | awk '{print $2}' | tr -d '. ' || true)
    case "$rv" in
      block) SHELL_VERDICT="block" ;;
      block-soft) [[ "$SHELL_VERDICT" != "block" ]] && SHELL_VERDICT="block-soft" ;;
      advise) [[ "$SHELL_VERDICT" == "approve" ]] && SHELL_VERDICT="advise" ;;
    esac
  done
  if [[ "$SHELL_VERDICT" == "approve" || "$SHELL_VERDICT" == "advise" ]]; then
    SHELL_FINAL="GO"
  else
    SHELL_FINAL="NO-GO"
  fi

  # ── PM synthesis ─────────────────────────────────────────────────────────────

  # Write synthesis brief in segments so reviewer content is appended with `cat`
  # (no heredoc expansion) rather than embedded in an unquoted heredoc.
  # This also removes `read:` file paths from the brief, preventing the synthesis
  # session from discovering or targeting reviewer output file locations.

  cat > "$SYNTHESIS_BRIEF" << SBRIEF_P1
schema_version: 1
working_dir: ${WORK_DIR}

goal: You are project-pm. Synthesize the reviewer findings provided in the context below and write a final consolidated PR-gate result at ${OUTPUT_FILE}.

files:
  - new:  ${OUTPUT_FILE}

constraints:
  - Do NOT modify any source file.
  - Only write ${OUTPUT_FILE}.
  - Create parent directories if needed (mkdir -p).
  - The Gate Conclusion MUST contain exactly: Final: ${SHELL_FINAL}
    This is pre-computed from the reviewer verdicts and must not be overridden.
  - Only cite files in the verified reference index or reviewer findings; do not invent citations.

context:
  Tier: ${TIER}
  Executor: ${EXECUTOR}
  Reviewers: ${REVIEWER_DISPLAY}
  Not reviewed: ${SKIPPED_DISPLAY}
  Base: ${BASE}
  Scope: ${SCOPE:-none}
  Date: $(date '+%Y-%m-%d')
${GATE_OVERRIDES_CONTEXT_BLOCK}
  Verified reference files (exist in working tree -- check before citing):
${REPO_REF_INDEX}
  Reviewer findings (embedded -- do NOT attempt to read any external reviewer output file):
SBRIEF_P1

  for i in "${!REVIEWER_OUTPUT_FILES[@]}"; do
    rf="${REVIEWER_OUTPUT_FILES[$i]}"
    r="${REVIEWER_NAMES[$i]}"
    printf '  --- %s findings ---\n' "$r" >> "$SYNTHESIS_BRIEF"
    if [[ -s "$rf" ]]; then
      cat "$rf" >> "$SYNTHESIS_BRIEF"
    else
      printf '  (reviewer output unavailable)\n' >> "$SYNTHESIS_BRIEF"
    fi
    printf '\n' >> "$SYNTHESIS_BRIEF"
  done

  cat >> "$SYNTHESIS_BRIEF" << SBRIEF_P2

task:
  1. Use the reviewer findings embedded in the context above.
  2. Identify cross-reviewer overlaps: issues raised by more than one reviewer.
  3. Determine the overall verdict: most severe individual verdict across all reviewers
     (approve < advise < block-soft < block).
  4. State Final: GO or NO-GO.
     - GO:    no reviewer returned block or block-soft.
     - NO-GO: any reviewer returned block or block-soft. List required fixes and
              any applicable override path.
  5. Write the complete consolidated result to ${OUTPUT_FILE}.

output_format: |
  ---
  gate_result_version: pr_gate_result_v1
  final: GO|NO-GO
  tier: ${TIER}
  mode: parallel
  most_severe: approve|advise|block-soft|block
  reviewers:
    critic: approve|advise|block-soft|skipped
    qa-tester: pass|needs-tests|block|skipped
    architecture-reviewer: approve|advise|block-soft|skipped
    security-reviewer: pass|block|pass-not-applicable|skipped
    risk-reviewer: pass|block|pass-not-applicable|skipped
  escalation:
    recommended: true|false
    reviewers: []
    reason: []
  ---

  # PR-Gate Result -- ${TIER} tier (parallel ${EXECUTOR} mode)
  **Date**: $(date '+%Y-%m-%d')
  **Reviewers**: ${REVIEWER_DISPLAY}
  **Not reviewed**: ${SKIPPED_DISPLAY}

  ## {reviewer-name} -- {verdict}
  {Copy findings from that reviewer's findings block above, one bullet per finding with [severity] and file:line}

  Verdict: {verdict from reviewer findings}. {rationale}

  (repeat for each reviewer in order)

  ## Cross-Reviewer Overlaps
  {list issues raised by more than one reviewer; "none" if clean}

  ## Coverage Notes
  **Dimensions not covered**: ${SKIPPED_DISPLAY}

  ## Gate Conclusion
  **Overall verdict**: {most severe across all reviewers}
  **Most severe individual verdict**: {most severe}
  Final: GO|NO-GO
  {required fixes if NO-GO; override path if any block or block-soft}

  CRITICAL -- the Final: line above MUST be emitted EXACTLY in this shape:
  - plain text, no markdown emphasis (NO surrounding **, NO backticks, NO italic)
  - at start of line (no leading whitespace)
  - literal token GO or NO-GO (uppercase, hyphen for NO-GO)
  - matched by the regex ^Final: (GO|NO-GO)\$
  - the value MUST equal the frontmatter \`final:\` field (case-sensitive)
  Examples that BREAK the parser and MUST NOT be emitted: \`**Final: GO**\`, \`Final: **GO**\`, \` Final: GO\`, \`Final: Go\`.

  ## Escalation
  **Recommended**: true|false
  **Reviewers**: <comma-list or "none">
  **Reason**:
  - <bullet> (or "none" when recommended=false)

  Escalation is recommended when:
  (a) any diff file matches (^|[/_.-])(auth|oauth|jwt|session|secret|password|token|credential|cors|csrf|webhook|sudo|ssh|payment|billing)([/_.-]|\$)|(^|/)migrations?/|^\.github/
  (b) at least one reviewer returned advise|block-soft.

  Recommended follow-ups:
  {non-blocking improvements from advise-level findings, if any}

  Rationale: {1-2 sentences explaining the final verdict}

self_verify:
  - cmd: "test -f ${OUTPUT_FILE}"
  - has-final: grep -cE '^Final: (GO|NO-GO)\$' ${OUTPUT_FILE} should be exactly 1
  - frontmatter-final-parity: the value after \`final:\` in the YAML frontmatter MUST equal the value after \`Final:\` in Gate Conclusion (case-sensitive)
  - all-reviewers-present: output must contain a section header for each of: ${REVIEWER_DISPLAY}

acceptance:
  - ${OUTPUT_FILE} exists with a section for each of the ${NUM_REVIEWERS} reviewers
  - Cross-Reviewer Overlaps section is present
  - "Final: GO" or "Final: NO-GO" is present in Gate Conclusion (plain text, no markdown emphasis)
SBRIEF_P2

  say '  [synthesis] running PM consolidation...\n'
  SYNTHESIS_DISPATCH_CMD="$(dispatch_via "$EXECUTOR" "$SYNTHESIS_BRIEF" "$WORK_DIR" "$DISPATCH_MODEL" "$DISPATCH_SANDBOX" "$DISPATCH_APPROVAL" "$TIMEOUT" "$DISPATCH_ISOLATION")" || exit 2
  # Diagnostic chatter to stderr -- see sequential dispatch note above.
  # Synthesis runs in background so a watchdog can kill it if it hangs indefinitely.
  eval "$SYNTHESIS_DISPATCH_CMD" >&2 &
  _SYNTHESIS_PID=$!
  _GATE_SYNTHESIS_WATCHDOG_TIMEOUT="${_PM_DISPATCH_GATE_SYNTHESIS_WATCHDOG_TIMEOUT:-$((TIMEOUT + 60))}"
  (
    sleep "$_GATE_SYNTHESIS_WATCHDOG_TIMEOUT"
    _kill_process_tree "$_SYNTHESIS_PID" TERM
  ) &
  _SYNTHESIS_WATCHDOG_PID=$!
  _synthesis_exit=0
  wait "$_SYNTHESIS_PID" || _synthesis_exit=$?
  kill "$_SYNTHESIS_WATCHDOG_PID" 2>/dev/null || true
  wait "$_SYNTHESIS_WATCHDOG_PID" 2>/dev/null || true
  if [[ "$_synthesis_exit" -gt 128 ]]; then
    printf 'Timeout: synthesis session did not complete within %ds\n' "$_GATE_SYNTHESIS_WATCHDOG_TIMEOUT" >&2
    exit 1
  elif [[ "$_synthesis_exit" -ne 0 ]]; then
    printf 'Error: synthesis session failed (exit %d)\n' "$_synthesis_exit" >&2
    exit 1
  fi

  # Validate synthesis output via the shared contract, pinned to the
  # shell-computed verdict: a synthesis that contradicts SHELL_FINAL (in either
  # the body Final: line or the frontmatter final: field) indicates a
  # manipulated/corrupt artifact and aborts the gate.
  gate_result_verify "$OUTPUT_FILE" "$SHELL_FINAL" "PM synthesis" || exit 1

  # Verify reviewer artifact files were not modified by synthesis.
  # These are gitignored and not covered by the tracked-file hash above.
  TAMPERED_ARTIFACTS=()
  for i in "${!REVIEWER_OUTPUT_FILES[@]}"; do
    rf="${REVIEWER_OUTPUT_FILES[$i]}"
    r="${REVIEWER_NAMES[$i]}"
    current_hash="$(cat "$rf" | $_HASH_CMD)"
    if [[ "${REVIEWER_ARTIFACT_HASHES[$i]}" != "$current_hash" ]]; then
      TAMPERED_ARTIFACTS+=("$r")
    fi
  done
  if [[ "${#TAMPERED_ARTIFACTS[@]}" -gt 0 ]]; then
    printf 'Error: reviewer artifact(s) modified after review phase -- synthesis-side tampering detected: %s\n' \
      "${TAMPERED_ARTIFACTS[*]}" >&2
    exit 1
  fi

  # Post-synthesis integrity check -- same dual-hash guard for tracked files.
  # Same artifact_filter_porcelain exclusion as the pre/post-dispatch snapshots so
  # this hash stays comparable with _POST_DISPATCH_STATUS below.
  _POST_SYNTHESIS_DIFF=$(git diff HEAD 2>/dev/null | $_HASH_CMD)
  _POST_SYNTHESIS_STATUS=$(git status --porcelain -z 2>/dev/null | artifact_filter_porcelain | $_HASH_CMD)
  if [[ "$_POST_DISPATCH_DIFF" != "$_POST_SYNTHESIS_DIFF" || "$_POST_DISPATCH_STATUS" != "$_POST_SYNTHESIS_STATUS" ]]; then
    printf 'Error: synthesis session modified working tree -- possible prompt injection.\n' >&2
    exit 1
  fi
  fi

fi

# ── Override provenance (audit record) ─────────────────────────────────────────
# When accepted-risk overrides were injected, the gate result must say so: which
# file they came from and exactly what was suppressed. Without this, an override
# silently turns a would-be block into a GO with no trace in the result. The block
# is appended deterministically by the gate (not the executor) so the audit record
# is independent of what the reviewer chose to echo. It is written on both GO and
# NO-GO -- the audit is about what was offered for suppression, not the outcome.
# Lines are indented (markdown code block) so this section can never introduce a
# spurious top-level `Final:` line or a frontmatter `---` fence that would trip
# gate_result_verify / `pmctl gate verify`.
if [[ -n "$GATE_OVERRIDES_CONTENT" ]]; then
  # shellcheck disable=SC2016  # literal markdown backticks in the format string, not a command substitution
  {
    printf '\n## Gate Overrides Applied\n'
    printf 'Accepted-risk overrides were loaded from `%s` and injected into every\n' "$OVERRIDE_FILE"
    printf 'reviewer and synthesis brief for this run. Reviewers were instructed not to\n'
    printf 're-block these items unless the diff materially changed the accepted risk.\n'
    printf 'This block is the audit record of what was offered for suppression.\n\n'
    printf '%s\n' "$GATE_OVERRIDES_CONTENT" | sed 's/^/    /'
  } >> "$OUTPUT_FILE"
  say 'pr-gate: override provenance recorded in result\n'
  # Re-verify after appending: the provenance block is written post-verification,
  # so re-run the same integrity contract to prove the appended (indented) content
  # did not introduce a second Final: line or break frontmatter parity -- a
  # parser-hostile override file (containing `Final: GO` / `---`) must stay neutralized.
  gate_result_verify "$OUTPUT_FILE" "" "post-provenance-append" || exit 1
fi

# ── Post-gate hook ─────────────────────────────────────────────────────────
# Both executors complete the gate in-process now, so post-gate fires at true
# gate completion regardless of executor. It runs only when --allow-hooks is set
# AND the gate result is GO -- a success-only side-effect hook, not a teardown hook.
_POST_GATE_HOOK="$WORK_DIR/.pm-dispatch/post-gate.sh"
if [[ "$ALLOW_HOOKS" != "true" ]]; then
  if [[ -f "$_POST_GATE_HOOK" ]]; then
    printf 'Warning: .pm-dispatch/post-gate.sh present but skipped -- pass --allow-hooks to execute repo-local hook scripts\n' >&2
  fi
elif [[ -f "$_POST_GATE_HOOK" && ! -x "$_POST_GATE_HOOK" ]]; then
  printf 'Warning: .pm-dispatch/post-gate.sh exists but is not executable -- skipping\n' >&2
elif [[ -x "$_POST_GATE_HOOK" ]]; then
  _GATE_FINAL=$(grep -m1 '^Final: ' "$OUTPUT_FILE" 2>/dev/null | awk '{print $2}' || true)
  if [[ "$_GATE_FINAL" != "GO" ]]; then
    say '\nSkipping post-gate hook: gate result is %s (post-gate runs only on GO)\n' "${_GATE_FINAL:-unknown}"
  else
    say '\nRunning post-gate hook: .pm-dispatch/post-gate.sh\n'
    if ! (cd "$WORK_DIR" && bash "$_POST_GATE_HOOK"); then
      printf '\n## Post-Gate Hook Failure\n**post-gate.sh exited nonzero -- this gate run is INCOMPLETE despite Final: GO above. Re-run after fixing the hook.**\n' >> "$OUTPUT_FILE"
      printf 'Error: post-gate hook failed\n' >&2
      exit 1
    fi
    say 'post-gate hook completed.\n'
  fi
fi

# ── Relocate result to run dir (post-verification) ───────────────────────────
# OUTPUT_FILE was written by the executor in WORK_DIR (workspace-write sandbox
# constraint). Now that it is verified, move it (and any parallel reviewer outputs,
# already read by synthesis) to _ARTIFACT_ROOT/.gate-results/ if a run dir was supplied.
# Relocation is centralized in relocate_gate_artifacts(), which the EXIT trap also calls
# so failure paths relocate too; calling it here updates OUTPUT_FILE before the prints
# below, and the trap's later call is then a no-op. --output overrides are never moved.
relocate_gate_artifacts

# ── Print result path for caller ─────────────────────────────────────────────
# The result was written by the dispatched subprocess and already integrity-checked
# in-process (gate_result_verify above). `pmctl gate verify "$OUTPUT_FILE"` re-runs
# the same contract on demand for callers that want to re-confirm out of band.
say '\nresult: %s\n' "$OUTPUT_FILE"
if [[ -n "${GATE_RUN_DIR_OVERRIDE:-}" ]]; then
  say 'run-dir: %s\n' "${GATE_RUN_DIR_OVERRIDE:-}"
fi

_FINAL_EXIT_VERDICT=$(grep -m1 '^Final: ' "$OUTPUT_FILE" 2>/dev/null | awk '{print $2}' || true)
if [[ "$_FINAL_EXIT_VERDICT" == "NO-GO" ]]; then
  exit 1
fi
