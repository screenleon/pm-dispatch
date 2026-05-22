#!/usr/bin/env bash
# Validate YAML frontmatter in agent and command markdown files.

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
single_file=""

usage() {
  echo "usage: $(basename "$0") [--file <path>] [--repo-root <path>]" >&2
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --file)
      if [ "$#" -lt 2 ]; then
        usage
        exit 2
      fi
      single_file="$2"
      shift 2
      ;;
    --repo-root)
      if [ "$#" -lt 2 ]; then
        usage
        exit 2
      fi
      repo_root="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage
      exit 2
      ;;
  esac
done

files=()
if [ -n "$single_file" ]; then
  files=("$single_file")
else
  for dir in "$repo_root/agents" "$repo_root/commands"; do
    if [ ! -d "$dir" ]; then
      echo "WARN: $dir not found; skipping" >&2
      continue
    fi

    found=0
    for file in "$dir"/*.md; do
      [ -e "$file" ] || continue
      files+=("$file")
      found=1
    done

    if [ "$found" -eq 0 ]; then
      echo "WARN: no markdown files found in $dir" >&2
    fi
  done
fi

extract_frontmatter() {
  awk '
    /^---[[:space:]]*$/ {
      marker += 1
      if (marker == 1) {
        next
      }
      if (marker == 2) {
        exit
      }
    }
    marker == 1 {
      print
    }
  ' "$1"
}

# Validate frontmatter lines — restricted YAML subset (no full YAML parser).
# Accepts: blank lines, list items, simple key: value pairs, quoted values.
# Rejects: unclosed brackets/braces, unterminated quoted scalars, nested mappings.
# argument-hint must be a double-quoted string.
check_frontmatter() {
  local line
  local trailing_after_quoted_re='^[A-Za-z_-]+:[[:space:]]*"([^"\\]|\\.)*"[[:space:]]*[^[:space:]]'
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    if [[ "$line" =~ ^[[:space:]]*-[[:space:]] ]]; then
      local _item="${line#*- }"
      if [[ "$_item" =~ ^\[ ]]; then
        if [[ ! "$_item" =~ \][[:space:]]*$ ]]; then
          printf 'invalid YAML list item: %s\n' "$line"; return 1
        fi
        local _si _sinq _sinsq
        _si="${_item#*\[}"; _si="${_si%\]*}"
        _sinq="${_si//\"/}"
        if (( (${#_si} - ${#_sinq}) % 2 != 0 )); then
          printf 'invalid YAML list item: %s\n' "$line"; return 1
        fi
        _sinsq="${_si//\'/}"
        if (( (${#_si} - ${#_sinsq}) % 2 != 0 )); then
          printf 'invalid YAML list item: %s\n' "$line"; return 1
        fi
        if [[ "$_si" == *"{"* ]] || [[ "$_si" == *"["* ]]; then
          printf 'invalid YAML list item: %s\n' "$line"; return 1
        fi
      elif [[ "$_item" =~ ^\{ ]]; then
        if [[ ! "$_item" =~ \}[[:space:]]*$ ]]; then
          printf 'invalid YAML list item: %s\n' "$line"; return 1
        fi
        local _mi _minq _mi_nob _mi_ncb
        _mi="${_item#*\{}"; _mi="${_mi%\}*}"
        _minq="${_mi//\"/}"
        if (( (${#_mi} - ${#_minq}) % 2 != 0 )); then
          printf 'invalid YAML list item: %s\n' "$line"; return 1
        fi
        _mi_nob="${_mi//\[/}"; _mi_ncb="${_mi//\]/}"
        if (( (${#_mi} - ${#_mi_nob}) != (${#_mi} - ${#_mi_ncb}) )); then
          printf 'invalid YAML list item: %s\n' "$line"; return 1
        fi
      elif [[ "$_item" =~ ^\" ]]; then
        local _idq_re='^"([^"\\]|\\[0abtnvfre"\\/NLP_]|\\x[0-9a-fA-F]{2}|\\u[0-9a-fA-F]{4}|\\U[0-9a-fA-F]{8})*"[[:space:]]*$'
        if [[ ! "$_item" =~ $_idq_re ]]; then
          printf 'invalid YAML list item: %s\n' "$line"; return 1
        fi
      elif [[ "$_item" =~ ^\' ]]; then
        local _isq_re="^'([^']|'')*'[[:space:]]*$"
        if [[ ! "$_item" =~ $_isq_re ]]; then
          printf 'invalid YAML list item: %s\n' "$line"; return 1
        fi
      elif [[ "$_item" =~ ^[@\`\*\&\!] ]]; then
        printf 'invalid YAML list item: %s\n' "$line"; return 1
      fi
      continue
    fi
    if [[ ! "$line" =~ ^[A-Za-z_-]+:[[:space:]] ]] && [[ ! "$line" =~ ^[A-Za-z_-]+:$ ]]; then
      printf 'unexpected frontmatter syntax: %s\n' "$line"
      return 1
    fi
    if [[ "$line" =~ ^[A-Za-z_-]+:[[:space:]]*\[ ]]; then
      if [[ ! "$line" =~ \][[:space:]]*$ ]]; then
        printf 'invalid YAML flow sequence: %s\n' "$line"
        return 1
      fi
      local _seq_inner _seq_nq
      _seq_inner="${line#*\[}"
      _seq_inner="${_seq_inner%\]*}"
      _seq_nq="${_seq_inner//\"/}"
      if (( (${#_seq_inner} - ${#_seq_nq}) % 2 != 0 )); then
        printf 'invalid YAML flow sequence: %s\n' "$line"
        return 1
      fi
      local _seq_nsq="${_seq_inner//\'/}"
      if (( (${#_seq_inner} - ${#_seq_nsq}) % 2 != 0 )); then
        printf 'invalid YAML flow sequence: %s\n' "$line"
        return 1
      fi
      if [[ "$_seq_inner" == *"{"* ]] || [[ "$_seq_inner" == *"["* ]]; then
        printf 'invalid YAML flow sequence: %s\n' "$line"
        return 1
      fi
    fi
    local _closed_dq_re='^[A-Za-z_-]+:[[:space:]]*"([^"\\]|\\[0abtnvfre"\\/NLP_]|\\x[0-9a-fA-F]{2}|\\u[0-9a-fA-F]{4}|\\U[0-9a-fA-F]{8})*"[[:space:]]*$'
    if [[ "$line" =~ ^[A-Za-z_-]+:[[:space:]]*\" ]] && [[ ! "$line" =~ $_closed_dq_re ]]; then
      printf 'unterminated quoted value: %s\n' "$line"
      return 1
    fi
    if [[ "$line" =~ $trailing_after_quoted_re ]]; then
      printf 'trailing content after quoted value: %s\n' "$line"
      return 1
    fi
    if [[ "$line" =~ ^[A-Za-z_-]+:[[:space:]]*\{ ]]; then
      if [[ ! "$line" =~ \}[[:space:]]*$ ]]; then
        printf 'invalid YAML flow mapping: %s\n' "$line"
        return 1
      fi
      local _map_inner _map_nq _map_no_ob _map_no_cb
      _map_inner="${line#*\{}"
      _map_inner="${_map_inner%\}*}"
      _map_nq="${_map_inner//\"/}"
      if (( (${#_map_inner} - ${#_map_nq}) % 2 != 0 )); then
        printf 'invalid YAML flow mapping: %s\n' "$line"
        return 1
      fi
      _map_no_ob="${_map_inner//\[/}"
      _map_no_cb="${_map_inner//\]/}"
      if (( (${#_map_inner} - ${#_map_no_ob}) != (${#_map_inner} - ${#_map_no_cb}) )); then
        printf 'invalid YAML flow mapping: %s\n' "$line"
        return 1
      fi
    fi
    local _closed_sq_re="^[A-Za-z_-]+:[[:space:]]*'([^']|'')*'[[:space:]]*$"
    if [[ "$line" =~ ^[A-Za-z_-]+:[[:space:]]*\' ]] && [[ ! "$line" =~ $_closed_sq_re ]]; then
      printf 'unterminated single-quoted value: %s\n' "$line"
      return 1
    fi
    # Reject unquoted values that look like nested YAML mappings (word: rest).
    if [[ ! "$line" =~ ^[A-Za-z_-]+:[[:space:]]*\" ]]; then
      local _val="${line#*: }"
      if [[ "$_val" =~ ^[A-Za-z_][A-Za-z_-]*:[[:space:]] ]]; then
        printf 'value looks like a nested YAML mapping: %s\n' "$line"
        return 1
      fi
    fi
    if [[ "$line" =~ ^argument-hint: ]] && [[ ! "$line" =~ ^argument-hint:[[:space:]]*\" ]]; then
      printf 'argument-hint must be quoted as a YAML string\n'
      return 1
    fi
    local _sv="${line#*: }"
    if [[ "$_sv" =~ ^[@\`\*\&\!] ]]; then
      printf 'invalid YAML plain scalar start: %s\n' "$line"
      return 1
    fi
  done
}

failures=0
checked=0

for file in "${files[@]}"; do
  if [ ! -f "$file" ]; then
    echo "FAIL: $file: file not found" >&2
    failures=$((failures + 1))
    continue
  fi

  first_line="$(sed -n '1p' "$file")"
  if [ "$first_line" != "---" ]; then
    echo "WARN: $file has no YAML frontmatter; skipping" >&2
    continue
  fi

  fence_count="$(grep -c '^---[[:space:]]*$' "$file" || true)"
  if [ "$fence_count" -lt 2 ]; then
    echo "FAIL: $file: unterminated YAML frontmatter" >&2
    failures=$((failures + 1))
    continue
  fi

  frontmatter="$(extract_frontmatter "$file")"
  if error="$(printf '%s\n' "$frontmatter" | check_frontmatter 2>&1)"; then
    echo "OK: $file"
    checked=$((checked + 1))
  else
    echo "FAIL: $file: $error" >&2
    failures=$((failures + 1))
  fi
done

if [ "$failures" -gt 0 ]; then
  echo "lint-frontmatter: $failures failure(s)" >&2
  exit 1
fi

echo "lint-frontmatter: OK ($checked file(s) checked)"
