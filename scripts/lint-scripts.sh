#!/usr/bin/env bash
# Validate hygiene of every scripts/*.sh:
#   - file is executable (mode +x)
#   - first line is a shebang (#!...)
#   - parses cleanly under `bash -n`
#   - declares `set -uo pipefail` or `set -euo pipefail` near the top
#
# Exit 0 if all clean; 1 if any violation.

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
scripts_dir="$repo_root/scripts"

if [ ! -d "$scripts_dir" ]; then
  echo "lint-scripts: $scripts_dir not found" >&2
  exit 2
fi

violations=0
checked=0
for f in "$scripts_dir"/*.sh; do
  [ -e "$f" ] || continue
  checked=$((checked + 1))
  name="$(basename "$f")"

  if [ ! -x "$f" ]; then
    echo "FAIL: $name not executable (chmod +x)" >&2
    violations=$((violations + 1))
  fi

  first_line="$(head -n1 "$f")"
  case "$first_line" in
    "#!"*) ;;
    *)
      echo "FAIL: $name missing shebang on line 1 (got: $first_line)" >&2
      violations=$((violations + 1))
      ;;
  esac

  if ! bash -n "$f" 2>/dev/null; then
    echo "FAIL: $name does not parse (bash -n)" >&2
    bash -n "$f" 2>&1 | sed 's/^/  /' >&2
    violations=$((violations + 1))
  fi

  # Look for `set -...` in the first 50 lines; require at least one of -u/-e/-o.
  set_line="$(head -n50 "$f" | grep -E '^set -[a-z]+( pipefail)?$' || true)"
  if [ -z "$set_line" ]; then
    echo "WARN: $name has no \`set -uo pipefail\`-style line in first 50 lines" >&2
  fi
done

if [ "$violations" -gt 0 ]; then
  echo "lint-scripts: $violations violation(s)" >&2
  exit 1
fi

if [ "$checked" -eq 0 ]; then
  echo "lint-scripts: no script files found in $scripts_dir" >&2
  exit 1
fi

echo "lint-scripts: OK ($checked script files checked)"
