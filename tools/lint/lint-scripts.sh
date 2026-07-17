#!/usr/bin/env bash
# Validate basic hygiene of shell entrypoints and host-owned shell modules,
# then invoke the canonical ShellCheck domain inventory used by CI:
#   - entrypoints are executable (mode +x)
#   - first line is a shebang (#!...)
#   - parses cleanly under `bash -n`
#   - entrypoints declare `set -uo pipefail` or `set -euo pipefail` near the top
#
# Stable scan roots:
#   scripts/*.sh             shared entrypoints
#   hosts/*/bin/*.sh         host-owned entrypoints
#   hosts/*/lib/*.sh         sourced host modules (not required to be +x or
#                            change their caller's shell options)
#
# Exit 0 if all clean; 1 if any violation.

set -euo pipefail

run_shellcheck=1
case "${1:-}" in
  --hygiene-only) run_shellcheck=0 ;;
  "") ;;
  *) printf 'lint-scripts: usage: %s [--hygiene-only]\n' "$0" >&2; exit 2 ;;
esac

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
if [ ! -d "$repo_root/scripts" ] || [ ! -d "$repo_root/hosts" ]; then
  echo "lint-scripts: expected scripts/ and hosts/ under $repo_root" >&2
  exit 2
fi

violations=0
checked=0
shopt -s nullglob
files=(
  "$repo_root"/scripts/*.sh
  "$repo_root"/hosts/*/bin/*.sh
  "$repo_root"/hosts/*/lib/*.sh
)
shopt -u nullglob

for f in "${files[@]}"; do
  [ -e "$f" ] || continue
  checked=$((checked + 1))
  name="${f#"$repo_root"/}"

  if [[ "$name" != hosts/*/lib/*.sh ]] && [ ! -x "$f" ]; then
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

  # Sourced libraries inherit their caller's strict mode and must not mutate it.
  if [[ "$name" != hosts/*/lib/*.sh ]]; then
    set_line="$(head -n50 "$f" | grep -E '^set -[a-z]+( pipefail)?$' || true)"
    if [ -z "$set_line" ]; then
      echo "WARN: $name has no \`set -uo pipefail\`-style line in first 50 lines" >&2
    fi
  fi
done

if [ "$violations" -gt 0 ]; then
  echo "lint-scripts: $violations violation(s)" >&2
  exit 1
fi

if [ "$checked" -eq 0 ]; then
  echo "lint-scripts: no script files found in configured roots" >&2
  exit 1
fi

echo "lint-scripts: OK ($checked shell files checked)"
if [[ "$run_shellcheck" -eq 1 ]]; then
  "$repo_root/tools/lint/lint-shellcheck.sh"
fi
