#!/usr/bin/env bash
# [CC-244] Typed snapshot output aligns with future spike_v1 schema.
# This script is the PM pre-spawn snapshot writer used by CC-243.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKING_DIR="$(pwd)"

if ! git -C "$WORKING_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "error: not inside a git repository: $WORKING_DIR" >&2
  exit 1
fi

REPO_ROOT="$(git -C "$WORKING_DIR" rev-parse --show-toplevel)"
BACKLOG_FILE="$REPO_ROOT/BACKLOG.md"
if [ ! -f "$BACKLOG_FILE" ]; then
  echo "error: BACKLOG.md not found at $BACKLOG_FILE" >&2
  exit 1
fi

OUT_PATH="/tmp/pm-snapshot-$(date -u '+%Y%m%dT%H%M%SZ')-$$.$RANDOM.md"
FOCUS_ARG=""

print_usage() {
  printf 'Usage: %s [--focus CC-243,CC-244] [--out /tmp/path.md]\n' "$0" >&2
  exit 0
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --focus)
      if [ $# -lt 2 ]; then
        echo "error: --focus requires a comma-separated list" >&2
        exit 1
      fi
      FOCUS_ARG="${2:-}"
      shift 2
      ;;
    --out)
      if [ $# -lt 2 ]; then
        echo "error: --out requires a path" >&2
        exit 1
      fi
      OUT_PATH="${2:-}"
      shift 2
      ;;
    --help|-h)
      print_usage
      ;;
    *)
      echo "error: unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

if [ -z "$OUT_PATH" ]; then
  echo "error: --out path must not be empty" >&2
  exit 1
fi

OUT_DIR="$(dirname "$OUT_PATH")"
if [ ! -d "$OUT_DIR" ]; then
  echo "error: output directory not found: $OUT_DIR" >&2
  exit 1
fi

if [ -f "$OUT_PATH" ] && [ ! -w "$OUT_PATH" ]; then
  echo "error: output file is not writable: $OUT_PATH" >&2
  exit 1
fi

CHECK_PATH="${OUT_PATH}.pm-prep-snapshot-check.$$"
if ! : > "$CHECK_PATH" 2>/dev/null; then
  echo "error: cannot write to output path: $OUT_PATH" >&2
  exit 1
fi
rm -f "$CHECK_PATH"

trim() {
  local value="$1"
  printf '%s' "$value" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
}

yaml_quote() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  printf '"%s"' "$value"
}

SNAPSHOT_TS="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
REPO_NAME="$(basename "$REPO_ROOT")"

CURRENT_BRANCH_NAME="$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo HEAD)"
CURRENT_SHA="$(git -C "$REPO_ROOT" rev-parse --short=12 HEAD)"
CURRENT_BRANCH="${CURRENT_BRANCH_NAME}@${CURRENT_SHA}"

BRANCH_BASE_WARN=""
if BRANCH_BASE_SHA="$(git -C "$REPO_ROOT" rev-parse --short=12 origin/main 2>/dev/null)"; then
  BRANCH_BASE="origin/main@$BRANCH_BASE_SHA"
elif BRANCH_BASE_SHA="$(git -C "$REPO_ROOT" rev-parse --short=12 main 2>/dev/null)"; then
  BRANCH_BASE="main@$BRANCH_BASE_SHA"
  BRANCH_BASE_WARN="origin/main unresolved; falling back to local main"
else
  BRANCH_BASE="unresolved"
  BRANCH_BASE_WARN="origin/main and main both unresolved; PM should treat branch context as untrusted"
fi

if [ -n "$BRANCH_BASE_SHA" ] && AHEAD_BY="$(git -C "$REPO_ROOT" rev-list --count "$BRANCH_BASE_SHA..$CURRENT_SHA" 2>/dev/null)"; then
  :
else
  AHEAD_BY=0
  if [ -z "$BRANCH_BASE_WARN" ]; then
    BRANCH_BASE_WARN="ahead_by could not be computed; defaulted to 0"
  fi
fi

MAX_CC_ID=0
in_index=0
while IFS= read -r backlog_line; do
  if [ "$backlog_line" = "## Index" ]; then
    in_index=1
    continue
  fi
  if [ "$in_index" -eq 1 ] && [ "${backlog_line#\#\# }" != "$backlog_line" ]; then
    break
  fi
  if [ "$in_index" -eq 1 ] && [ "${backlog_line#\|}" != "$backlog_line" ]; then
    id_num="$(printf '%s\n' "$backlog_line" | awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/,"",$2); if ($2 ~ /^CC-[0-9]/) { sub(/^CC-0*/, "", $2); print $2; }}')"
    case "$id_num" in
      ''|*[!0-9]*)
        ;;
      *)
        if [ "$id_num" -gt "$MAX_CC_ID" ]; then
          MAX_CC_ID="$id_num"
        fi
        ;;
    esac
  fi
done < "$BACKLOG_FILE"
BACKLOG_NEXT_ID="$((MAX_CC_ID + 1))"
NEXT_TICKET_ID=$(printf 'CC-%03d' "$BACKLOG_NEXT_ID")

collect_backlog_row() {
  local ticket="$1"
  awk -v t="$ticket" -F'|' '
    /^## Index/ { in_index=1; next }
    in_index && $0 ~ /^## / { exit }
    in_index && $0 ~ /^\|/ {
      candidate=$2
      gsub(/^[[:space:]]+|[[:space:]]+$/,"",candidate)
      if (candidate == t) { print; exit }
    }
  ' "$BACKLOG_FILE"
}

collect_backlog_body() {
  local ticket="$1"
  awk -v t="$ticket" '
    $0 ~ "^##[[:space:]]*" t "([[:space:]]|—|$)" { found=1; print; next }
    found {
      if ($0 ~ "^## ") { exit }
      print
    }
  ' "$BACKLOG_FILE"
}

RECENTLY_MERGED_WARN=""
RECENTLY_MERGED=()

collect_recently_merged() {
  local raw_output
  local parsed_objects
  local obj
  local count
  local num
  local title
  local line
  local used_template=0

  if ! command -v gh >/dev/null 2>&1; then
    RECENTLY_MERGED_WARN="gh command not found; recently_merged set to []"
    return 1
  fi

  if command -v jq >/dev/null 2>&1; then
    used_template=1
    raw_output="$(gh pr list --state merged --limit 5 --json number,title --jq '.[] | "#\(.number) \(.title)"' 2>/dev/null || true)"
  else
    raw_output="$(gh pr list --state merged --limit 5 --json number,title 2>/dev/null || true)"
    if [ -n "$raw_output" ]; then
      parsed_objects="$(printf '%s\n' "$raw_output" | tr -d '\n' | sed -E 's/^\\[//' | sed -E 's/\\]$//' | sed -E 's/\\},[[:space:]]*\\{/\\}\n\\{/g')"
      count=0
      while IFS= read -r obj; do
        [ -z "$obj" ] && continue
        num="$(printf '%s' "$obj" | sed -n 's/.*\"number\":[[:space:]]*\\([0-9][0-9]*\\).*/\\1/p')"
        title="$(printf '%s' "$obj" | sed -n 's/.*\"title\":[[:space:]]*\"\\([^\"]*\\)\".*/\\1/p')"
        if [ -n "$num" ] && [ -n "$title" ]; then
          RECENTLY_MERGED+=("#$num $title")
          count=$((count + 1))
          [ "$count" -ge 5 ] && break
        fi
      done <<EOF
$parsed_objects
EOF
      return 0
    fi
  fi

  if [ "$used_template" -eq 1 ] && [ -n "$raw_output" ]; then
    count=0
    while IFS= read -r line; do
      line="$(trim "$line")"
      [ -z "$line" ] && continue
      if [ "${line#\"}" != "$line" ] && [ "${line%\"}" != "$line" ]; then
        line="${line#\"}"
        line="${line%\"}"
      fi
      RECENTLY_MERGED+=("$line")
      count=$((count + 1))
      [ "$count" -ge 5 ] && break
    done <<EOF
$raw_output
EOF
    return 0
  fi

  RECENTLY_MERGED_WARN="gh merged PR query failed; recently_merged set to []"
  return 1
}

collect_recently_merged

HAS_MAKEFILE=false
[ -f "$REPO_ROOT/Makefile" ] && HAS_MAKEFILE=true

HAS_BACKLOG_RENDER_TARGET=false
if grep -q "^backlog-render:" "$REPO_ROOT/Makefile" 2>/dev/null; then
  HAS_BACKLOG_RENDER_TARGET=true
fi

HAS_VALIDATE_SH=false
if [ -x "$REPO_ROOT/pm/scripts/validate.sh" ]; then
  HAS_VALIDATE_SH=true
fi

FOCUS_IDS=()
if [ -n "$FOCUS_ARG" ]; then
  IFS=',' read -r -a FOCUS_IDS <<< "$FOCUS_ARG"
fi

TMP_OUT="$(mktemp "${OUT_PATH}.tmp.XXXXXX")"

{
  printf '%s\n' '---'
  printf 'snapshot_ts: %s\n' "$SNAPSHOT_TS"
  printf 'repo: %s\n' "$REPO_NAME"
  if [ -n "$BRANCH_BASE_WARN" ]; then
    printf '# warn: %s\n' "$BRANCH_BASE_WARN"
  fi
  printf 'branch_base: %s\n' "$BRANCH_BASE"
  printf 'current_branch: %s\n' "$CURRENT_BRANCH"
  printf 'ahead_by: %s\n' "$AHEAD_BY"

  if [ -n "$RECENTLY_MERGED_WARN" ]; then
    printf '# warn: %s\n' "$RECENTLY_MERGED_WARN"
    printf 'recently_merged: []\n'
  elif [ "${#RECENTLY_MERGED[@]}" -eq 0 ]; then
    printf 'recently_merged: []\n'
  else
    printf 'recently_merged:\n'
    for merged_line in "${RECENTLY_MERGED[@]}"; do
      printf '  - %s\n' "$(yaml_quote "$merged_line")"
    done
  fi

  printf 'backlog_next_id: %s\n' "$NEXT_TICKET_ID"
  printf '# Add new probe keys here as projects diverge.\n'
  printf 'project_tooling:\n'
  printf '  makefile: %s\n' "$HAS_MAKEFILE"
  printf '  backlog_render_target: %s\n' "$HAS_BACKLOG_RENDER_TARGET"
  printf '  has_validate_sh: %s\n' "$HAS_VALIDATE_SH"
  printf '%s\n' '---'
  printf '\n'

  if [ "${#FOCUS_IDS[@]}" -gt 0 ]; then
    focus_emitted=0
    for raw_id in "${FOCUS_IDS[@]}"; do
      ticket_id="$(trim "$raw_id")"
      [ -z "$ticket_id" ] && continue
      row="$(collect_backlog_row "$ticket_id")"
      body="$(collect_backlog_body "$ticket_id")"
      if [ -n "$row" ] && [ -n "$body" ]; then
        if [ "$focus_emitted" -eq 0 ]; then
          printf '## focus_tickets\n\n'
          focus_emitted=1
        fi
        printf '%s\n' "$row"
        printf '\n'
        printf '%s\n\n' "$body"
      else
        printf '# warn: %s not found in BACKLOG.md\n' "$ticket_id"
      fi
    done
  fi
} > "$TMP_OUT"

mv "$TMP_OUT" "$OUT_PATH"
