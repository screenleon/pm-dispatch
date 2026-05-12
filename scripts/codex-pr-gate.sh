#!/usr/bin/env bash
set -euo pipefail

# codex-pr-gate.sh — PR-gate review via codex
#
# Default mode (parallel): one independent codex session per reviewer so that
# no shared context window anchors or limits any single reviewer; a project-pm
# synthesis session consolidates all findings into the final gate result.
#
# Use --sequential to fall back to the original single-session approach where
# all reviewers run in order inside one combined codex session.
#
# Adjacent test files (not in the diff but directly paired to a changed source
# file) are automatically added to every reviewer brief so coverage gaps in
# unchanged test files are visible to the gate.
#
# Usage:
#   codex-pr-gate.sh --cd <dir> [options]
#
# Options:
#   --cd <dir>           working directory (required)
#   --tier <tier>        express|standard|full — overrides auto-detection
#   --reviewers <list>   comma-separated names — overrides tier default (targeted re-gate)
#   --scope <text>       context hint passed into the review brief
#   --base <branch>      base branch for diff (default: origin/HEAD → main)
#   --output <path>      result file (default: .gate-results/gate-<ts>.md)
#   --timeout <secs>     codex-dispatch timeout per session (default: 1200)
#   --sequential         run all reviewers in one codex session (original behavior)

WORK_DIR=""
TIER_OVERRIDE=""
REVIEWERS_OVERRIDE=""
SCOPE=""
BASE_OVERRIDE=""
OUTPUT_OVERRIDE=""
TIMEOUT="1200"
SEQUENTIAL=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cd)         WORK_DIR="$2";           shift 2;;
    --tier)       TIER_OVERRIDE="$2";      shift 2;;
    --reviewers)  REVIEWERS_OVERRIDE="$2"; shift 2;;
    --scope)      SCOPE="$2";              shift 2;;
    --base)       BASE_OVERRIDE="$2";      shift 2;;
    --output)     OUTPUT_OVERRIDE="$2";    shift 2;;
    --timeout)    TIMEOUT="$2";            shift 2;;
    --sequential) SEQUENTIAL=true;         shift;;
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

cd "$WORK_DIR"

# ── Detect base branch ────────────────────────────────────────────────────────
if [[ -n "$BASE_OVERRIDE" ]]; then
  BASE="$BASE_OVERRIDE"
else
  BASE=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || true)
  : "${BASE:=main}"
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
# Auto-patch .gitignore so .codex-briefs/ is not tracked
_PATCH_GI="$(cd "$(dirname "$0")" && pwd)/patch-gitignore.sh"
[[ -x "$_PATCH_GI" ]] && bash "$_PATCH_GI" "$WORK_DIR" ".codex-briefs/" ".gate-results/" ".agents/" ".agent-trace/"
mkdir -p "$BRIEF_DIR"

OUTPUT_FILE="${OUTPUT_OVERRIDE:-$WORK_DIR/.gate-results/gate-${TIMESTAMP}.md}"
mkdir -p "$(dirname "$OUTPUT_FILE")"

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"

# Track all brief files for EXIT cleanup
BRIEF_FILES=()
cleanup_briefs() {
  for bf in "${BRIEF_FILES[@]:-}"; do
    rm -f "$bf"
  done
}
trap cleanup_briefs EXIT

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

printf 'codex-pr-gate: %s tier — %s\n' "$TIER" "$REVIEWER_DISPLAY"
[[ "${ADJ_COUNT:-0}" -gt 0 ]] && printf '  adjacent test files added: %d\n' "$ADJ_COUNT"
printf 'result will be written to: %s\n\n' "$OUTPUT_FILE"

# ── Dispatch ─────────────────────────────────────────────────────────────────
if [[ "$SEQUENTIAL" == "true" ]]; then

  # ── Sequential mode (original: all reviewers in one combined codex session) ──
  AGENT_FILE_ENTRIES=""
  for r in $REVIEWERS; do
    AGENT_PATH="$AGENT_DIR/${r}.md"
    AGENT_FILE_ENTRIES="${AGENT_FILE_ENTRIES}  - read: ${AGENT_PATH}"$'\n'
  done

  BRIEF_FILE="$BRIEF_DIR/pr-gate-${TIMESTAMP}.md"
  BRIEF_FILES+=("$BRIEF_FILE")

  cat > "$BRIEF_FILE" << BRIEF_EOF
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
  **Final**: GO | NO-GO
  {required fixes if NO-GO; override path if any block-soft}

self_verify:
  - file-exists: ${OUTPUT_FILE}
  - has-conclusion: grep -c 'Final' ${OUTPUT_FILE} should be >= 1

acceptance:
  - ${OUTPUT_FILE} exists with a verdict section for each of the ${NUM_REVIEWERS} reviewers
  - "Final: GO" or "Final: NO-GO" is present in Gate Conclusion
BRIEF_EOF

  bash "$SCRIPT_DIR/codex-dispatch.sh" \
    --cd "$WORK_DIR" \
    --timeout "$TIMEOUT" \
    --brief-file "$BRIEF_FILE"

else

  # ── Parallel mode (default): one codex session per reviewer + PM synthesis ──
  # Each reviewer runs independently — no shared context window means no
  # anchoring bias or token pressure from earlier reviewers bleeding through.
  # PM synthesis reads all reviewer output files and consolidates.

  REVIEWER_OUTPUT_FILES=()
  DISPATCH_PIDS=()
  REVIEWER_NAMES=()

  mkdir -p "$WORK_DIR/.agent-trace"

  # Capture working-tree content fingerprint before dispatch so the integrity
  # check can detect changes to already-dirty tracked files (git diff HEAD
  # compares content, not just filenames — catches mutations the filename-only
  # approach would miss; untracked gate artifacts are gitignored and excluded).
  _PRE_DISPATCH_DIFF=$(git diff HEAD 2>/dev/null | sha256sum 2>/dev/null || true)

  for r in $REVIEWERS; do
    AGENT_PATH="$AGENT_DIR/${r}.md"
    REVIEWER_OUTPUT="$WORK_DIR/.gate-results/reviewer-${r}-${TIMESTAMP}.md"
    REVIEWER_BRIEF="$BRIEF_DIR/pr-gate-${TIMESTAMP}-${r}.md"
    DISPATCH_LOG="$WORK_DIR/.agent-trace/gate-${TIMESTAMP}-${r}.log"

    BRIEF_FILES+=("$REVIEWER_BRIEF")
    REVIEWER_OUTPUT_FILES+=("$REVIEWER_OUTPUT")
    REVIEWER_NAMES+=("$r")

    cat > "$REVIEWER_BRIEF" << RBRIEF_EOF
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

    bash "$SCRIPT_DIR/codex-dispatch.sh" \
      --cd "$WORK_DIR" \
      --timeout "$TIMEOUT" \
      --brief-file "$REVIEWER_BRIEF" \
      > "$DISPATCH_LOG" 2>&1 &
    DISPATCH_PIDS+=($!)
    printf '  [parallel] launched %s (pid %d)\n' "$r" "$!"
  done

  printf '\n  waiting for %d reviewer session(s)...\n' "${#DISPATCH_PIDS[@]}"

  # Wait for all reviewer sessions. Any non-zero exit aborts the gate — an
  # incomplete review cannot certify a valid gate result.
  FAILED_REVIEWERS=()
  for i in "${!DISPATCH_PIDS[@]}"; do
    pid="${DISPATCH_PIDS[$i]}"
    r="${REVIEWER_NAMES[$i]}"
    if ! wait "$pid"; then
      FAILED_REVIEWERS+=("$r")
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

  # Verify every reviewer output contains a parseable verdict line before synthesis.
  # A non-empty but malformed reviewer file could steer synthesis to a false GO.
  INVALID_OUTPUTS=()
  for i in "${!REVIEWER_OUTPUT_FILES[@]}"; do
    rf="${REVIEWER_OUTPUT_FILES[$i]}"
    r="${REVIEWER_NAMES[$i]}"
    if ! grep -qE '^Verdict: (approve|advise|block-soft|block)' "$rf"; then
      INVALID_OUTPUTS+=("$r")
    fi
  done
  if [[ "${#INVALID_OUTPUTS[@]}" -gt 0 ]]; then
    printf 'Error: reviewer output missing valid Verdict line for: %s\n' "${INVALID_OUTPUTS[*]}" >&2
    printf 'Expected: Verdict: approve|advise|block-soft|block\n' >&2
    printf 'Gate aborted — use --sequential to diagnose.\n' >&2
    exit 1
  fi

  # Worktree integrity check — detect prompt-injected modifications to tracked files.
  # Content-hash comparison catches mutations to already-dirty files; filename-only
  # comparison would miss those because the filename was already in the dirty set.
  _POST_DISPATCH_DIFF=$(git diff HEAD 2>/dev/null | sha256sum 2>/dev/null || true)
  if [[ "$_PRE_DISPATCH_DIFF" != "$_POST_DISPATCH_DIFF" ]]; then
    printf 'Error: reviewer sessions modified tracked source files — possible prompt injection.\n' >&2
    printf 'Gate aborted. Inspect the reviewer dispatch logs under .agent-trace/ for details.\n' >&2
    exit 1
  fi

  printf '  all reviewer sessions done.\n\n'

  # Compute the final verdict deterministically in shell before synthesis.
  # Synthesis is treated as prose-only; the shell verdict is the authoritative gate result.
  SHELL_VERDICT="approve"
  for rf in "${REVIEWER_OUTPUT_FILES[@]}"; do
    rv=$(grep -oE '^Verdict: (approve|advise|block-soft|block)' "$rf" | head -1 | awk '{print $2}' || true)
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
  SYNTHESIS_BRIEF="$BRIEF_DIR/pr-gate-${TIMESTAMP}-synthesis.md"
  BRIEF_FILES+=("$SYNTHESIS_BRIEF")

  REVIEWER_FILE_ENTRIES=""
  for rf in "${REVIEWER_OUTPUT_FILES[@]}"; do
    REVIEWER_FILE_ENTRIES="${REVIEWER_FILE_ENTRIES}  - read: ${rf}"$'\n'
  done

  FAILED_NOTE=""

  cat > "$SYNTHESIS_BRIEF" << SBRIEF_EOF
working_dir: ${WORK_DIR}

goal: You are project-pm. Read each reviewer's individual findings file and synthesize a final consolidated PR-gate result at ${OUTPUT_FILE}.

files:
${REVIEWER_FILE_ENTRIES}  - new:  ${OUTPUT_FILE}

constraints:
  - Do NOT modify any source file or reviewer output file.
  - Only write ${OUTPUT_FILE}.
  - Create parent directories if needed (mkdir -p).
  - If a reviewer output file is absent or empty, record "reviewer output unavailable" in that section.
  - The Gate Conclusion MUST contain exactly: Final: ${SHELL_FINAL}
    This is pre-computed from the reviewer verdicts and must not be overridden.

context:
  Tier: ${TIER}
  Reviewers: ${REVIEWER_DISPLAY}
  Not reviewed: ${SKIPPED_DISPLAY}
  Base: ${BASE}
  Scope: ${SCOPE:-none}
  Date: $(date '+%Y-%m-%d')
${FAILED_NOTE}

task:
  1. Read each reviewer output file listed above.
  2. Identify cross-reviewer overlaps: issues raised by more than one reviewer.
  3. Determine the overall verdict: most severe individual verdict across all reviewers
     (approve < advise < block-soft < block).
  4. State Final: GO or NO-GO.
     - GO:    no reviewer returned block or block-soft.
     - NO-GO: any reviewer returned block or block-soft. List required fixes and
              any applicable override path.
  5. Write the complete consolidated result to ${OUTPUT_FILE}.

output_format: |
  # PR-Gate Result — ${TIER} tier (parallel codex mode)
  **Date**: $(date '+%Y-%m-%d')
  **Reviewers**: ${REVIEWER_DISPLAY}
  **Not reviewed**: ${SKIPPED_DISPLAY}

  ## {reviewer-name} — {verdict}
  {Copy findings from that reviewer's output file, one bullet per finding with [severity] and file:line}

  Verdict: {verdict from reviewer file}. {rationale}

  (repeat for each reviewer in order)

  ## Cross-Reviewer Overlaps
  {list issues raised by more than one reviewer; "none" if clean}

  ## Coverage Notes
  **Dimensions not covered**: ${SKIPPED_DISPLAY}

  ## Gate Conclusion
  **Overall verdict**: {most severe across all reviewers}
  **Most severe individual verdict**: {most severe}
  **Final**: GO | NO-GO

  Required fixes before GO: {bulleted list if NO-GO; "none" if GO}

  Recommended follow-ups:
  {non-blocking improvements from advise-level findings, if any}

  Rationale: {1-2 sentences explaining the final verdict}

self_verify:
  - file-exists: ${OUTPUT_FILE}
  - has-final: grep -c 'Final' ${OUTPUT_FILE} should be exactly 1
  - all-reviewers-present: output must contain a section header for each of: ${REVIEWER_DISPLAY}

acceptance:
  - ${OUTPUT_FILE} exists with a section for each of the ${NUM_REVIEWERS} reviewers
  - Cross-Reviewer Overlaps section is present
  - "Final: GO" or "Final: NO-GO" is present in Gate Conclusion
SBRIEF_EOF

  printf '  [synthesis] running PM consolidation...\n'
  bash "$SCRIPT_DIR/codex-dispatch.sh" \
    --cd "$WORK_DIR" \
    --timeout "$TIMEOUT" \
    --brief-file "$SYNTHESIS_BRIEF"

  # Validate synthesis output: must exist, be non-empty, contain Final: GO|NO-GO,
  # and match the shell-computed verdict (guards against synthesis manipulation).
  if [[ ! -s "$OUTPUT_FILE" ]]; then
    printf 'Error: PM synthesis did not produce the gate result file: %s\n' "$OUTPUT_FILE" >&2
    printf 'Gate aborted — synthesis session may have exited 0 without completing.\n' >&2
    exit 1
  fi
  if ! grep -qE '^Final: (GO|NO-GO)$' "$OUTPUT_FILE"; then
    printf 'Error: gate result file missing valid Final: GO/NO-GO conclusion.\n' >&2
    exit 1
  fi
  SYNTHESIS_FINAL=$(grep -oE '^Final: (GO|NO-GO)' "$OUTPUT_FILE" | head -1 | awk '{print $2}')
  if [[ "$SYNTHESIS_FINAL" != "$SHELL_FINAL" ]]; then
    printf 'Error: synthesis verdict (%s) contradicts shell-computed verdict (%s) — gate result may have been manipulated.\n' \
      "$SYNTHESIS_FINAL" "$SHELL_FINAL" >&2
    exit 1
  fi

  # Post-synthesis integrity check — same content-hash guard run again to catch
  # synthesis-side prompt injection that modifies tracked source files.
  _POST_SYNTHESIS_DIFF=$(git diff HEAD 2>/dev/null | sha256sum 2>/dev/null || true)
  if [[ "$_POST_DISPATCH_DIFF" != "$_POST_SYNTHESIS_DIFF" ]]; then
    printf 'Error: synthesis session modified tracked source files — possible prompt injection.\n' >&2
    exit 1
  fi

fi

# ── Print result path for caller ─────────────────────────────────────────────
printf '\nresult: %s\n' "$OUTPUT_FILE"
