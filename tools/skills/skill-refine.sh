#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

usage() {
  printf 'Usage: %s <skill-name>\n' "$(basename "$0")" >&2
}

if [[ $# -ne 1 ]]; then
  usage
  exit 2
fi

SKILL_NAME="$1"
if [[ ! "$SKILL_NAME" =~ ^[A-Za-z0-9_-]+$ ]]; then
  printf 'Error: invalid skill name: %s\n' "$SKILL_NAME" >&2
  exit 2
fi

COMMAND_PATH="$REPO_ROOT/commands/${SKILL_NAME}.md"

if [[ ! -f "$COMMAND_PATH" ]]; then
  printf 'Error: skill command file not found: %s\n' "$COMMAND_PATH" >&2
  exit 2
fi

ENV_MEMORY_DIR="${CLAUDE_MEMORY_DIR:-}"
MEMORY_DIR=""

if [[ -n "$ENV_MEMORY_DIR" && -d "$ENV_MEMORY_DIR" ]]; then
  MEMORY_DIR="$(cd "$ENV_MEMORY_DIR" && pwd -P)"
else
  printf 'Error: CLAUDE_MEMORY_DIR must be exported pointing at your memory dir; got %s\n' "${ENV_MEMORY_DIR:-<unset>}" >&2
  exit 2
fi

SCAN_TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

candidate_names=()
candidate_descriptions=()
candidate_whys=()
candidate_hows=()
candidate_files=()

parse_feedback() {
  local file="$1"
  awk -v token="$SKILL_NAME" '
    function has_token(text, needle, start, pos, before, after, before_ok, after_ok) {
      start = 1
      while (start <= length(text)) {
        pos = index(substr(text, start), needle)
        if (pos == 0) {
          return 0
        }
        pos = start + pos - 1
        before = pos == 1 ? "" : substr(text, pos - 1, 1)
        after = pos + length(needle) > length(text) ? "" : substr(text, pos + length(needle), 1)
        before_ok = before !~ /[[:alnum:]_-]/
        after_ok = after !~ /[[:alnum:]_-]/
        if (before_ok && after_ok) {
          return 1
        }
        start = pos + 1
      }
      return 0
    }
    BEGIN {
      in_frontmatter = 0
      body_started = 0
      desc = "_(not present)_"
      why = "_(not present)_"
      how = "_(not present)_"
      matched = 0
    }
    NR == 1 && $0 == "---" {
      in_frontmatter = 1
      next
    }
    in_frontmatter && $0 == "---" {
      in_frontmatter = 0
      body_started = 1
      next
    }
    in_frontmatter {
      if ($0 ~ /^[[:space:]]*description:[[:space:]]*/ && desc == "_(not present)_") {
        desc = $0
        sub(/^[[:space:]]*description:[[:space:]]*/, "", desc)
        if (has_token(desc, token)) {
          matched = 1
        }
      }
      next
    }
    {
      if (NR == 1) {
        body_started = 1
      }
      if (body_started && has_token($0, token)) {
        matched = 1
      }
      if (body_started && $0 ~ /^[[:space:]]*Why:[[:space:]]*/ && why == "_(not present)_") {
        why = $0
        sub(/^[[:space:]]*Why:[[:space:]]*/, "", why)
      }
      if (body_started && $0 ~ /^[[:space:]]*How to apply:[[:space:]]*/ && how == "_(not present)_") {
        how = $0
        sub(/^[[:space:]]*How to apply:[[:space:]]*/, "", how)
      }
    }
    END {
      print matched
      print desc
      print why
      print how
    }
  ' "$file"
}

while IFS= read -r feedback_file; do
  parsed=()
  mapfile -t parsed < <(parse_feedback "$feedback_file")
  if [[ "${parsed[0]:-0}" == "1" ]]; then
    candidate_names+=("$(basename "$feedback_file" .md)")
    candidate_descriptions+=("${parsed[1]:-_(not present)_}")
    candidate_whys+=("${parsed[2]:-_(not present)_}")
    candidate_hows+=("${parsed[3]:-_(not present)_}")
    candidate_files+=("$feedback_file")
  fi
done < <(find "$MEMORY_DIR" -maxdepth 1 -type f -name 'feedback_*.md' | LC_ALL=C sort)

printf '# Skill refine signals: %s\n\n' "$SKILL_NAME"
printf 'Found %s candidate(s). Scanned %s at %s.\n\n' "${#candidate_names[@]}" "$MEMORY_DIR" "$SCAN_TS"

if [[ "${#candidate_names[@]}" -eq 0 ]]; then
  # shellcheck disable=SC2016  # backticks are literal markdown, not command substitution
  printf 'No matching feedback entries found for `%s`.\n\n' "$SKILL_NAME"
else
  for i in "${!candidate_names[@]}"; do
    printf '## %s\n' "${candidate_names[$i]}"
    printf -- '- description: %s\n' "${candidate_descriptions[$i]}"
    printf -- '- Why: %s\n' "${candidate_whys[$i]}"
    printf -- '- How to apply: %s\n' "${candidate_hows[$i]}"
    printf -- '- file: %s\n\n' "${candidate_files[$i]}"
  done
fi

printf '_M1 spike: read-only signal bundling. No diff generation yet (M2)._\n'
