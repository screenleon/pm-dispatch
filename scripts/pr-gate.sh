#!/usr/bin/env bash
set -euo pipefail

# pr-gate.sh — PR-gate review via a dispatched session
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
#   --tier <tier>        express|standard|full — overrides auto-detection
#   --reviewers <list>   comma-separated names — overrides tier default (targeted re-gate)
#   --scope <text>       context hint passed into the review brief
#   --base <branch>      base branch for diff (default: origin/HEAD → main)
#   --output <path>      result file (default: .gate-results/gate-<ts>.md)
#   --executor <mode>    codex|claude|auto (default: auto; auto uses `command -v codex`)
#   --timeout <secs>     dispatch timeout per session (default: 1200)
#   --parallel           multi-session: one dispatch per reviewer + synthesis (higher token cost)
#   --sequential         alias for default single-session mode (kept for backward compatibility)
#   --allow-hooks        execute repo-local .pm-dispatch hook scripts (trusted branches only)

WORK_DIR=""
TIER_OVERRIDE=""
REVIEWERS_OVERRIDE=""
SCOPE=""
BASE_OVERRIDE=""
OUTPUT_OVERRIDE=""
TIMEOUT="1200"
SEQUENTIAL=true   # default: sequential (lower token cost)
EXECUTOR_OPTION="auto"
ALLOW_HOOKS=false   # hooks require explicit --allow-hooks opt-in (security)
DISPATCH_MODEL="default"
DISPATCH_SANDBOX="workspace-write"
DISPATCH_APPROVAL="never"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cd)         WORK_DIR="$2";           shift 2;;
    --tier)       TIER_OVERRIDE="$2";      shift 2;;
    --reviewers)  REVIEWERS_OVERRIDE="$2"; shift 2;;
    --scope)      SCOPE="$2";              shift 2;;
    --base)       BASE_OVERRIDE="$2";      shift 2;;
    --output)     OUTPUT_OVERRIDE="$2";    shift 2;;
    --executor)   EXECUTOR_OPTION="$2";    shift 2;;
    --timeout)    TIMEOUT="$2";            shift 2;;
    --parallel)   SEQUENTIAL=false;        shift;;
    --sequential) SEQUENTIAL=true;         shift;;   # backward compat
    --allow-hooks) ALLOW_HOOKS=true;       shift;;
    -h|--help)
      sed -n '2,35p' "$0" | sed 's/^# \{0,1\}//'
      exit 0;;
    *) printf 'Unknown arg: %s\n' "$1" >&2; exit 2;;
  esac
done

if [[ -z "$WORK_DIR" ]]; then
  printf 'Error: --cd <dir> is required\n' >&2; exit 2
fi
if [[ ! -d "$WORK_DIR" ]]; then
  printf 'Error: working dir not found: %s\n' "$WORK_DIR" >&2; exit 2
fi

case "$EXECUTOR_OPTION" in
  auto|codex|claude) ;;
  *)
    printf "Error: --executor must be one of: codex | claude | auto (got: %s)\n" "$EXECUTOR_OPTION" >&2
    exit 2
    ;;
esac

_self="$0"
while [[ -L "$_self" ]]; do
  _self_dir="$(cd "$(dirname "$_self")" && pwd)"
  _self="$(readlink "$_self")"
  [[ "$_self" == /* ]] || _self="$_self_dir/$_self"
done
SCRIPT_DIR="$(cd "$(dirname "$_self")" && pwd)"
EXECUTOR_ROUTER_PATH="$SCRIPT_DIR/lib/executor-router.sh"
if [[ -r "$EXECUTOR_ROUTER_PATH" ]]; then
  # shellcheck source=scripts/lib/executor-router.sh
  . "$EXECUTOR_ROUTER_PATH"
  EXECUTOR_ROUTER_SCRIPT_DIR="$SCRIPT_DIR"
else
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

    case "$executor" in
      codex) printf 'main_thread_bash_background\n' ;;
      claude) printf 'agent_executor\n' ;;
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

  dispatch_via_codex() {
    local brief_file=${1-}
    local working_dir=${2-}
    local model=${3-}
    local sandbox=${4-}
    local approval=${5-}
    local timeout=${6-}
    local dispatch_script="$EXECUTOR_ROUTER_SCRIPT_DIR/codex-dispatch.sh"
    local -a cmd
    local arg
    local first=1

    [[ $# -eq 6 ]] || {
      printf 'executor-router: dispatch_via_codex expects brief_file, working_dir, model, sandbox, approval, timeout\n' >&2
      return 2
    }

    cmd=(bash "$dispatch_script" --cd "$working_dir" --sandbox "$sandbox" --approval "$approval" --timeout "$timeout" --brief-file "$brief_file")
    if [[ -n "$model" && "$model" != "default" ]]; then
      cmd=(bash "$dispatch_script" --cd "$working_dir" --model "$model" --sandbox "$sandbox" --approval "$approval" --timeout "$timeout" --brief-file "$brief_file")
    fi

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

EXECUTOR="$(resolve_executor "$EXECUTOR_OPTION")" || exit 2

unset _self _self_dir EXECUTOR_ROUTER_PATH

cd "$WORK_DIR"

# ── Detect base branch ────────────────────────────────────────────────────────
if [[ -n "$BASE_OVERRIDE" ]]; then
  BASE="$BASE_OVERRIDE"
else
  if command -v gh >/dev/null 2>&1; then
    if GH_BASE=$(gh pr view --json baseRefName -q .baseRefName 2>/dev/null); then
      if [[ -n "$GH_BASE" ]]; then
        BASE="$GH_BASE"
        printf 'pr-gate: base detected from gh pr view: %s\n' "$BASE"
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

# ── Collect diff ──────────────────────────────────────────────────────────────
# Use --name-status so renames expose BOTH old and new paths for sensitive matching.
# Use --numstat to detect binary files (shown as -\t-\t<file>).
if ! git diff "$BASE"...HEAD --quiet 2>/dev/null; then
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
  # No branch commits — fall back to working tree changes
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
    # Binary files have no line count but represent real changes — treat as standard+
    TIER=express
  else
    TIER=standard
  fi
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
BRIEF_DIR="$WORK_DIR/.codex-briefs"
mkdir -p "$BRIEF_DIR"

OUTPUT_FILE="${OUTPUT_OVERRIDE:-$WORK_DIR/.gate-results/gate-${TIMESTAMP}.md}"
mkdir -p "$(dirname "$OUTPUT_FILE")"
touch "$OUTPUT_FILE"

# Track all brief files for EXIT cleanup
BRIEF_FILES=()
cleanup_briefs() {
  [[ "${EXECUTOR:-}" == "codex" ]] || return 0
  for bf in "${BRIEF_FILES[@]:-}"; do
    rm -f "$bf"
  done
}
trap cleanup_briefs EXIT

SYNTHESIS_BRIEF="$BRIEF_DIR/pr-gate-${TIMESTAMP}-synthesis.md"
[[ "$EXECUTOR" == "codex" ]] && BRIEF_FILES+=("$SYNTHESIS_BRIEF")

PR_GATE_HANDOVER_ENTRIES=()
add_pr_gate_handover_entry() {
  local role="$1" reviewer_name="$2" brief_file="$3" output_file="$4"
  PR_GATE_HANDOVER_ENTRIES+=("- role: $role")
  [[ -n "$reviewer_name" ]] && PR_GATE_HANDOVER_ENTRIES+=("  reviewer_name: $reviewer_name")
  PR_GATE_HANDOVER_ENTRIES+=("  brief_file: $brief_file")
  PR_GATE_HANDOVER_ENTRIES+=("  output_file: $output_file")
}

emit_pr_gate_handover_block() {
  local out
  if [[ "${EXECUTOR:-}" != "claude" || "${#PR_GATE_HANDOVER_ENTRIES[@]}" -eq 0 ]]; then
    return
  fi
  printf '```pr-gate-handover_v1\n'
  for out in "${PR_GATE_HANDOVER_ENTRIES[@]}"; do
    printf '%s\n' "$out"
  done
  printf '```\n'
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
ADJ_COUNT=$(printf '%s\n' "$ADJACENT_TEST_FILES" | grep -c '[^[:space:]]' 2>/dev/null || true)

printf 'pr-gate: %s tier — %s\n' "$TIER" "$REVIEWER_DISPLAY"
[[ "${ADJ_COUNT:-0}" -gt 0 ]] && printf '  adjacent test files added: %d\n' "$ADJ_COUNT"
printf 'result will be written to: %s\n\n' "$OUTPUT_FILE"

# ── Pre-gate hook ──────────────────────────────────────────────────────────
_PRE_GATE_HOOK="$WORK_DIR/.pm-dispatch/pre-gate.sh"
if [[ "$ALLOW_HOOKS" != "true" ]]; then
  if [[ -f "$_PRE_GATE_HOOK" ]]; then
    printf 'Warning: .pm-dispatch/pre-gate.sh present but skipped — pass --allow-hooks to execute repo-local hook scripts\n' >&2
  fi
elif [[ -f "$_PRE_GATE_HOOK" && ! -x "$_PRE_GATE_HOOK" ]]; then
  printf 'Warning: .pm-dispatch/pre-gate.sh exists but is not executable — skipping\n' >&2
elif [[ -x "$_PRE_GATE_HOOK" ]]; then
  printf 'Running pre-gate hook: .pm-dispatch/pre-gate.sh\n'
  if ! (cd "$WORK_DIR" && bash "$_PRE_GATE_HOOK"); then
    printf 'Error: pre-gate hook failed — gate aborted\n' >&2
    exit 1
  fi
  printf 'pre-gate hook completed.\n\n'
fi

# ── Dispatch ─────────────────────────────────────────────────────────────────
if [[ "$SEQUENTIAL" == "true" ]]; then

  # ── Sequential mode (default: all reviewers in one combined codex session) ──
  AGENT_FILE_ENTRIES=""
  for r in $REVIEWERS; do
    AGENT_PATH="$AGENT_DIR/${r}.md"
    AGENT_FILE_ENTRIES="${AGENT_FILE_ENTRIES}  - read: ${AGENT_PATH}"$'\n'
  done

  if [[ "$EXECUTOR" == "codex" ]]; then
    BRIEF_FILE="$BRIEF_DIR/pr-gate-${TIMESTAMP}.md"
    BRIEF_FILES+=("$BRIEF_FILE")
  else
    BRIEF_FILE="$BRIEF_DIR/pr-gate-claude-${TIMESTAMP}-combined.md"
  fi

  cat > "$BRIEF_FILE" << BRIEF_EOF
schema_version: 1
working_dir: ${WORK_DIR}

goal: Sequential ${TIER}-tier PR-gate review. Apply each reviewer's criteria to the changed files and write a structured verdict to ${OUTPUT_FILE}.

files:
${AGENT_FILE_ENTRIES}${DIFF_FILE_ENTRIES}  - new:  ${OUTPUT_FILE}

constraints:
  - Do NOT modify any source file.
  - Only write ${OUTPUT_FILE}.
  - Create parent directories for ${OUTPUT_FILE} if needed (mkdir -p).

context:
  Tier: ${TIER}
  Reviewers: ${REVIEWER_DISPLAY}
  Not reviewed: ${SKIPPED_DISPLAY}
  Base: ${BASE}
  Scope: ${SCOPE:-none}
  Date: $(date '+%Y-%m-%d')

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

  # PR-Gate Result — ${TIER} tier (codex mode)
  **Date**: $(date '+%Y-%m-%d')
  **Reviewers**: ${REVIEWER_DISPLAY}
  **Not reviewed**: ${SKIPPED_DISPLAY}

  ## {reviewer-name} — {verdict}
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

  CRITICAL — the Final: line above MUST be emitted EXACTLY in this shape:
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
  - file-exists: ${OUTPUT_FILE}
  - has-conclusion: grep -cE '^Final: (GO|NO-GO)\$' ${OUTPUT_FILE} should be exactly 1
  - frontmatter-final-parity: the value after \`final:\` in the YAML frontmatter MUST equal the value after \`Final:\` in Gate Conclusion (case-sensitive)

  acceptance:
  - ${OUTPUT_FILE} exists with a verdict section for each of the ${NUM_REVIEWERS} reviewers
  - "Final: GO" or "Final: NO-GO" is present in Gate Conclusion (plain text, no markdown emphasis)
BRIEF_EOF

  if [[ "$EXECUTOR" == "codex" ]]; then
    CODEX_DISPATCH_CMD="$(dispatch_via_codex "$BRIEF_FILE" "$WORK_DIR" "$DISPATCH_MODEL" "$DISPATCH_SANDBOX" "$DISPATCH_APPROVAL" "$TIMEOUT")" || exit 2
    eval "$CODEX_DISPATCH_CMD"

    # Validate sequential output: must exist, be non-empty, contain exactly one
    # Final: GO|NO-GO line. Mirrors the parallel synthesis validation.
    if [[ ! -s "$OUTPUT_FILE" ]]; then
      printf 'Error: sequential gate did not produce the result file: %s\n' "$OUTPUT_FILE" >&2
      printf 'Gate aborted — codex session may have exited 0 without completing.\n' >&2
      exit 1
    fi
    SEQ_FINAL_COUNT=$(grep -cE '^Final: (GO|NO-GO)$' "$OUTPUT_FILE" || true)
    if [[ "$SEQ_FINAL_COUNT" -ne 1 ]]; then
      printf 'Error: gate result file must contain exactly one %s: GO/NO-GO line (found %d).\n' "Final" "$SEQ_FINAL_COUNT" >&2
      exit 1
    fi
    SEQ_FRONTMATTER_FINAL=$(awk 'BEGIN{s=0} /^---$/ { if (s == 0) { s=1; next } else if (s == 1) { exit } } s && $1 == "final:" { print $2; exit }' "$OUTPUT_FILE")
    if [[ -z "$SEQ_FRONTMATTER_FINAL" ]]; then
      printf 'Error: gate result YAML frontmatter missing required field: final:\n' >&2
      exit 1
    fi
    SEQ_BODY_FINAL=$(grep -E '^Final: (GO|NO-GO)$' "$OUTPUT_FILE" | awk '{print $2}')
    if [[ "$SEQ_FRONTMATTER_FINAL" != "$SEQ_BODY_FINAL" ]]; then
      printf 'Error: frontmatter final: (%s) does not match body Final: (%s) in sequential gate result.\n' \
        "$SEQ_FRONTMATTER_FINAL" "$SEQ_BODY_FINAL" >&2
      exit 1
    fi
  else
    add_pr_gate_handover_entry reviewer combined "$BRIEF_FILE" "$OUTPUT_FILE"
  fi

else

  # ── Multi-session mode (--parallel): one independent dispatch per reviewer + synthesis ──
  # Each reviewer runs in its own session with no shared context — eliminates
  # anchoring bias that can occur when all reviewers share one session window.
  # Followed by a PM synthesis session that consolidates all individual results.
  # Higher token cost vs single-session; suitable for auth/payment/migration paths.

  REVIEWER_OUTPUT_FILES=()
  DISPATCH_PIDS=()
  REVIEWER_NAMES=()

  mkdir -p "$WORK_DIR/.agent-trace"

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
    printf 'Error: no sha256sum or shasum found — cannot fingerprint worktree for injection detection.\n' >&2
    exit 1
  fi

  # Capture working-tree content fingerprints before dispatch.
  # git diff HEAD: content-level changes to tracked files (catches already-dirty mutations).
  # git status --porcelain: new untracked source files (gate artifacts are gitignored
  # by the patch above and excluded from this snapshot).
  _PRE_DISPATCH_DIFF=$(git diff HEAD 2>/dev/null | $_HASH_CMD)
  _PRE_DISPATCH_STATUS=$(git status --porcelain 2>/dev/null | $_HASH_CMD)

  for r in $REVIEWERS; do
    AGENT_PATH="$AGENT_DIR/${r}.md"
    REVIEWER_OUTPUT="$WORK_DIR/.gate-results/reviewer-${r}-${TIMESTAMP}.md"
    if [[ "$EXECUTOR" == "codex" ]]; then
      REVIEWER_BRIEF="$BRIEF_DIR/pr-gate-${TIMESTAMP}-${r}.md"
    else
      REVIEWER_BRIEF="$BRIEF_DIR/pr-gate-claude-${TIMESTAMP}-${r}.md"
    fi
    DISPATCH_LOG="$WORK_DIR/.agent-trace/gate-${TIMESTAMP}-${r}.log"

    [[ "$EXECUTOR" == "codex" ]] && BRIEF_FILES+=("$REVIEWER_BRIEF")
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
  - Create parent directories if needed (mkdir -p).

context:
  Tier: ${TIER}
  Reviewer: ${r}
  Base: ${BASE}
  Scope: ${SCOPE:-none}
  Date: $(date '+%Y-%m-%d')

  Diff (${LINES} changed lines):
${DIFF_STAT_INDENTED}

task:
  1. Read your agent definition (${AGENT_PATH}). Follow its boot instructions
     and internalize your specific review criteria and verdict scale.
  2. Review the changed files strictly from the ${r} perspective only.
     Do not attempt to cover other reviewer dimensions.
  3. Write a structured findings block with:
     - Findings: [severity] file:line — description (low/medium/high)
     - Explicit verdict: approve | advise | block-soft | block
     - One-sentence rationale for your verdict

  Write your complete review to ${REVIEWER_OUTPUT}.

output_format: |
  ## ${r} — {verdict}
  - [{severity}] {file:line} — {finding description}

  Verdict: {approve | advise | block-soft | block}. {One-sentence rationale.}

self_verify:
  - file-exists: ${REVIEWER_OUTPUT}

acceptance:
  - ${REVIEWER_OUTPUT} exists with at least one findings line and an explicit Verdict line
RBRIEF_EOF

    if [[ "$EXECUTOR" == "codex" ]]; then
      CODEX_DISPATCH_CMD="$(dispatch_via_codex "$REVIEWER_BRIEF" "$WORK_DIR" "$DISPATCH_MODEL" "$DISPATCH_SANDBOX" "$DISPATCH_APPROVAL" "$TIMEOUT")" || exit 2
      eval "$CODEX_DISPATCH_CMD" > "$DISPATCH_LOG" 2>&1 &
      DISPATCH_PIDS+=($!)
      printf '  [parallel] launched %s (pid %d)\n' "$r" "$!"
    else
      add_pr_gate_handover_entry reviewer "$r" "$REVIEWER_BRIEF" "$REVIEWER_OUTPUT"
      printf '  [parallel] queued reviewer %s (claude handover)\n' "$r"
    fi
  done

  if [[ "$EXECUTOR" == "codex" ]]; then
    printf '\n  waiting for %d reviewer session(s)...\n' "${#DISPATCH_PIDS[@]}"

    # Wait for all reviewer sessions. Any non-zero exit aborts the gate — an
    # incomplete review cannot certify a valid gate result.
    # Hash each reviewer output immediately after its PID exits so we capture
    # the content before any concurrently-running reviewer session can modify it.
    FAILED_REVIEWERS=()
    REVIEWER_POST_WAIT_HASHES=()
    for i in "${!DISPATCH_PIDS[@]}"; do
      pid="${DISPATCH_PIDS[$i]}"
      r="${REVIEWER_NAMES[$i]}"
      rf="${REVIEWER_OUTPUT_FILES[$i]}"
      if ! wait "$pid"; then
        FAILED_REVIEWERS+=("$r")
        REVIEWER_POST_WAIT_HASHES+=("none")
      else
        REVIEWER_POST_WAIT_HASHES+=("$(cat "$rf" 2>/dev/null | $_HASH_CMD || echo 'missing')")
      fi
    done

    if [[ "${#FAILED_REVIEWERS[@]}" -gt 0 ]]; then
      printf 'Error: %d reviewer session(s) failed: %s\n' \
        "${#FAILED_REVIEWERS[@]}" "${FAILED_REVIEWERS[*]}" >&2
      printf 'Gate aborted — fix the failing session or use --sequential to diagnose.\n' >&2
      exit 1
    fi

    # Verify every reviewer wrote a non-empty output file — a codex session can
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
      printf 'Gate aborted — use --sequential to diagnose.\n' >&2
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
      printf 'Gate aborted — use --sequential to diagnose.\n' >&2
      exit 1
    fi

    # Cross-reviewer artifact tamper detection: re-hash every reviewer output and
    # compare with the hash captured immediately after that reviewer's PID exited.
    # A mismatch means a concurrently-running reviewer session modified this file
    # after it was completed — fail closed before synthesis can run on tainted data.
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

  # Worktree integrity check — detect prompt-injected tracked-file modifications.
  # Content-hash catches mutations to already-dirty tracked files; status hash
  # catches new untracked source files (gate artifacts are gitignored, excluded).
  _POST_DISPATCH_DIFF=$(git diff HEAD 2>/dev/null | $_HASH_CMD)
  _POST_DISPATCH_STATUS=$(git status --porcelain 2>/dev/null | $_HASH_CMD)
  if [[ "$_PRE_DISPATCH_DIFF" != "$_POST_DISPATCH_DIFF" || "$_PRE_DISPATCH_STATUS" != "$_POST_DISPATCH_STATUS" ]]; then
    printf 'Error: reviewer sessions modified working tree — possible prompt injection.\n' >&2
    printf 'Gate aborted. Inspect the reviewer dispatch logs under .agent-trace/ for details.\n' >&2
    exit 1
  fi

  # Reviewer artifact integrity — snapshot each reviewer output file content now,
  # before synthesis, to detect synthesis-side tampering of reviewer artifacts.
  # Reviewer outputs are gitignored and not covered by the worktree hash above.
  REVIEWER_ARTIFACT_HASHES=()
  for rf in "${REVIEWER_OUTPUT_FILES[@]}"; do
    REVIEWER_ARTIFACT_HASHES+=("$(cat "$rf" | $_HASH_CMD)")
  done

  printf '  all reviewer sessions done.\n\n'

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

context:
  Tier: ${TIER}
  Reviewers: ${REVIEWER_DISPLAY}
  Not reviewed: ${SKIPPED_DISPLAY}
  Base: ${BASE}
  Scope: ${SCOPE:-none}
  Date: $(date '+%Y-%m-%d')

  Reviewer findings (embedded — do NOT attempt to read any external reviewer output file):
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

  # PR-Gate Result — ${TIER} tier (parallel codex mode)
  **Date**: $(date '+%Y-%m-%d')
  **Reviewers**: ${REVIEWER_DISPLAY}
  **Not reviewed**: ${SKIPPED_DISPLAY}

  ## {reviewer-name} — {verdict}
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

  CRITICAL — the Final: line above MUST be emitted EXACTLY in this shape:
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
  - file-exists: ${OUTPUT_FILE}
  - has-final: grep -cE '^Final: (GO|NO-GO)\$' ${OUTPUT_FILE} should be exactly 1
  - frontmatter-final-parity: the value after \`final:\` in the YAML frontmatter MUST equal the value after \`Final:\` in Gate Conclusion (case-sensitive)
  - all-reviewers-present: output must contain a section header for each of: ${REVIEWER_DISPLAY}

acceptance:
  - ${OUTPUT_FILE} exists with a section for each of the ${NUM_REVIEWERS} reviewers
  - Cross-Reviewer Overlaps section is present
  - "Final: GO" or "Final: NO-GO" is present in Gate Conclusion (plain text, no markdown emphasis)
SBRIEF_P2

  printf '  [synthesis] running PM consolidation...\n'
  CODEX_DISPATCH_CMD="$(dispatch_via_codex "$SYNTHESIS_BRIEF" "$WORK_DIR" "$DISPATCH_MODEL" "$DISPATCH_SANDBOX" "$DISPATCH_APPROVAL" "$TIMEOUT")" || exit 2
  eval "$CODEX_DISPATCH_CMD"

  # Validate synthesis output: must exist, be non-empty, contain exactly one
  # Final: GO|NO-GO line, and match the shell-computed verdict.
  # Multiple or conflicting Final: lines indicate a manipulated/corrupt artifact.
  if [[ ! -s "$OUTPUT_FILE" ]]; then
    printf 'Error: PM synthesis did not produce the gate result file: %s\n' "$OUTPUT_FILE" >&2
    printf 'Gate aborted — synthesis session may have exited 0 without completing.\n' >&2
    exit 1
  fi
  FINAL_COUNT=$(grep -cE '^Final: (GO|NO-GO)$' "$OUTPUT_FILE" || true)
  if [[ "$FINAL_COUNT" -ne 1 ]]; then
    printf 'Error: gate result file must contain exactly one Final: GO/NO-GO line (found %d).\n' "$FINAL_COUNT" >&2
    exit 1
  fi
  SYNTHESIS_FINAL=$(grep -E '^Final: (GO|NO-GO)$' "$OUTPUT_FILE" | awk '{print $2}')
  if [[ "$SYNTHESIS_FINAL" != "$SHELL_FINAL" ]]; then
    printf 'Error: synthesis verdict (%s) contradicts shell-computed verdict (%s) — gate result may have been manipulated.\n' \
      "$SYNTHESIS_FINAL" "$SHELL_FINAL" >&2
    exit 1
  fi
  FRONTMATTER_FINAL=$(awk 'BEGIN{s=0} /^---$/ { if (s == 0) { s=1; next } else if (s == 1) { exit } } s && $1 == "final:" { print $2; exit }' "$OUTPUT_FILE")
  if [[ -z "$FRONTMATTER_FINAL" ]]; then
    printf 'Error: gate result frontmatter final missing: cannot verify shell/Synthesis parity.\n' >&2
    exit 1
  fi
  if [[ "$FRONTMATTER_FINAL" != "$SHELL_FINAL" ]]; then
    printf 'Error: frontmatter final (%s) does not match shell-computed verdict (%s).\n' \
      "$FRONTMATTER_FINAL" "$SHELL_FINAL" >&2
    exit 1
  fi

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
    printf 'Error: reviewer artifact(s) modified after review phase — synthesis-side tampering detected: %s\n' \
      "${TAMPERED_ARTIFACTS[*]}" >&2
    exit 1
  fi

  # Post-synthesis integrity check — same dual-hash guard for tracked files.
  _POST_SYNTHESIS_DIFF=$(git diff HEAD 2>/dev/null | $_HASH_CMD)
  _POST_SYNTHESIS_STATUS=$(git status --porcelain 2>/dev/null | $_HASH_CMD)
  if [[ "$_POST_DISPATCH_DIFF" != "$_POST_SYNTHESIS_DIFF" || "$_POST_DISPATCH_STATUS" != "$_POST_SYNTHESIS_STATUS" ]]; then
    printf 'Error: synthesis session modified working tree — possible prompt injection.\n' >&2
    exit 1
  fi
  else
    add_pr_gate_handover_entry synthesis "" "$SYNTHESIS_BRIEF" "$OUTPUT_FILE"
  fi

fi

# ── Post-gate hook ─────────────────────────────────────────────────────────
# On the claude executor route this script is a handover producer only; reviewers
# run outside this script, so post-gate cannot fire at true gate completion here.
# On the codex route, post-gate runs only when --allow-hooks is set AND the
# gate result is GO — it is a success-only side-effect hook, not a teardown hook.
_POST_GATE_HOOK="$WORK_DIR/.pm-dispatch/post-gate.sh"
if [[ "$EXECUTOR" == "claude" ]]; then
  if [[ -f "$_POST_GATE_HOOK" ]]; then
    printf 'Notice: .pm-dispatch/post-gate.sh is present but will not run on --executor claude — reviewers execute outside this script on that route\n' >&2
  fi
elif [[ "$ALLOW_HOOKS" != "true" ]]; then
  if [[ -f "$_POST_GATE_HOOK" ]]; then
    printf 'Warning: .pm-dispatch/post-gate.sh present but skipped — pass --allow-hooks to execute repo-local hook scripts\n' >&2
  fi
elif [[ -f "$_POST_GATE_HOOK" && ! -x "$_POST_GATE_HOOK" ]]; then
  printf 'Warning: .pm-dispatch/post-gate.sh exists but is not executable — skipping\n' >&2
elif [[ -x "$_POST_GATE_HOOK" ]]; then
  _GATE_FINAL=$(grep -m1 '^Final: ' "$OUTPUT_FILE" 2>/dev/null | awk '{print $2}')
  if [[ "$_GATE_FINAL" != "GO" ]]; then
    printf '\nSkipping post-gate hook: gate result is %s (post-gate runs only on GO)\n' "${_GATE_FINAL:-unknown}"
  else
    printf '\nRunning post-gate hook: .pm-dispatch/post-gate.sh\n'
    if ! (cd "$WORK_DIR" && bash "$_POST_GATE_HOOK"); then
      printf 'Error: post-gate hook failed\n' >&2
      exit 1
    fi
    printf 'post-gate hook completed.\n'
  fi
fi

# ── Print result path for caller ─────────────────────────────────────────────
emit_pr_gate_handover_block
printf '\nresult: %s\n' "$OUTPUT_FILE"
