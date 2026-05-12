#!/usr/bin/env bash
set -euo pipefail

# codex-pr-gate.sh — sequential PR-gate review via codex
#
# All reviewer work runs inside a single codex session, keeping main-thread
# token cost to ~5k (dispatch overhead + reading result) vs ~40–80k for the
# multi-agent /pr-gate.
#
# Trade-off: reviewers run sequentially (not in parallel) and share the same
# context window, so for sensitive-path or >1000-line diffs prefer /pr-gate.
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
#   --timeout <secs>     codex-dispatch timeout (default: 1200)

WORK_DIR=""
TIER_OVERRIDE=""
REVIEWERS_OVERRIDE=""
SCOPE=""
BASE_OVERRIDE=""
OUTPUT_OVERRIDE=""
TIMEOUT="1200"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cd)        WORK_DIR="$2";        shift 2;;
    --tier)      TIER_OVERRIDE="$2";   shift 2;;
    --reviewers) REVIEWERS_OVERRIDE="$2"; shift 2;;
    --scope)     SCOPE="$2";           shift 2;;
    --base)      BASE_OVERRIDE="$2";   shift 2;;
    --output)    OUTPUT_OVERRIDE="$2"; shift 2;;
    --timeout)   TIMEOUT="$2";         shift 2;;
    -h|--help)
      sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'
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

REVIEWER_DISPLAY=$(printf '%s' "$REVIEWERS" | tr ' ' ', ')
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

# ── Prepare output paths ─────────────────────────────────────────────────────
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BRIEF_DIR="$WORK_DIR/.codex-briefs"
# Auto-patch .gitignore so .codex-briefs/ is not tracked
_PATCH_GI="$(cd "$(dirname "$0")" && pwd)/patch-gitignore.sh"
[[ -x "$_PATCH_GI" ]] && bash "$_PATCH_GI" "$WORK_DIR" ".codex-briefs/" ".gate-results/" ".agents/"
mkdir -p "$BRIEF_DIR"
BRIEF_FILE="$BRIEF_DIR/pr-gate-${TIMESTAMP}.md"
trap 'rm -f "${BRIEF_FILE:-}"' EXIT

OUTPUT_FILE="${OUTPUT_OVERRIDE:-$WORK_DIR/.gate-results/gate-${TIMESTAMP}.md}"
mkdir -p "$(dirname "$OUTPUT_FILE")"

# ── Build file entries for the brief ─────────────────────────────────────────
AGENT_FILE_ENTRIES=""
for r in $REVIEWERS; do
  AGENT_PATH="$AGENT_DIR/${r}.md"
  if [[ -f "$AGENT_PATH" ]]; then
    AGENT_FILE_ENTRIES="${AGENT_FILE_ENTRIES}  - read: ${AGENT_PATH}
"
  else
    printf 'Error: reviewer agent file not found: %s\n' "$AGENT_PATH" >&2
    exit 1
  fi
done

DIFF_FILE_ENTRIES=""
while IFS= read -r f; do
  fp="$WORK_DIR/$f"
  [[ -f "$fp" ]] && DIFF_FILE_ENTRIES="${DIFF_FILE_ENTRIES}  - read: ${fp}
"
done <<< "$DIFF_FILES"

DIFF_STAT_INDENTED=$(printf '%s\n' "$DIFF_STAT" | sed 's/^/    /')

# ── Generate the brief ────────────────────────────────────────────────────────
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

  ## Gate Conclusion
  **Final**: GO | NO-GO
  {required fixes if NO-GO; override path if any block-soft}

self_verify:
  - file-exists: ${OUTPUT_FILE}
  - has-conclusion: grep -c 'Final' ${OUTPUT_FILE} should be >= 1

acceptance:
  - ${OUTPUT_FILE} exists with a verdict section for each of the ${NUM_REVIEWERS} reviewers
  - "Final: GO" or "Final: NO-GO" is present in Gate Conclusion
BRIEF_EOF

# ── Dispatch ─────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
printf 'codex-pr-gate: %s tier — %s\n' "$TIER" "$REVIEWER_DISPLAY"
printf 'result will be written to: %s\n\n' "$OUTPUT_FILE"

bash "$SCRIPT_DIR/codex-dispatch.sh" \
  --cd "$WORK_DIR" \
  --timeout "$TIMEOUT" \
  --brief-file "$BRIEF_FILE"

rm -f "$BRIEF_FILE"

# ── Print result path for caller ─────────────────────────────────────────────
printf '\nresult: %s\n' "$OUTPUT_FILE"
