#!/usr/bin/env bash
# Validate YAML frontmatter in agent and command markdown files.

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
single_file=""

usage() {
  echo "usage: $(basename "$0") [--file <path>]" >&2
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
  if error="$(
    printf '%s\n' "$frontmatter" | python3 -c '
import sys

try:
    import yaml
except ImportError as exc:
    print(f"PyYAML is required: {exc}", file=sys.stderr)
    sys.exit(2)

try:
    data = yaml.safe_load(sys.stdin)
except yaml.YAMLError as exc:
    print(exc, file=sys.stderr)
    sys.exit(1)

if isinstance(data, dict) and "argument-hint" in data and not isinstance(data["argument-hint"], str):
    print("argument-hint must be quoted as a YAML string", file=sys.stderr)
    sys.exit(1)
' 2>&1
  )"; then
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
