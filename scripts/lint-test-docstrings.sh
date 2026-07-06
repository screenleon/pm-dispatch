#!/usr/bin/env bash
# Enforce the `# Behavior:` test docstring convention (documented at the
# top of scripts/lib/test-harness.sh) on an explicit allowlist of
# scripts/test-*.sh files that have already been converted to it.
#
# Every test_* function in an allowlisted file must have a `# Behavior:`
# marker inside the contiguous comment block directly above its
# declaration (not split across the `{`, not separated by a blank line).
# A `# Steps:` follow-on is the documented convention but is checked as
# part of code review, not mechanically here, since existing allowlisted
# files use it inconsistently (single-line Behavior-only docstrings are
# already accepted practice in some of them) -- this is a known, narrower
# gate than the two-part convention documented in test-harness.sh. This
# is a ratchet, not a repo-wide rule: files not yet converted (tracked by
# CC-450) are simply not in ALLOWLIST, so adding a test to one of them
# does not fail this check. Add a file to ALLOWLIST only once every
# test_* function in it already has a Behavior: marker -- from that point
# this lint blocks both regressions and new undocumented tests in that
# file.
#
# Exit 0 if all allowlisted files are clean; 1 if any violation.

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
custom_allow=()

usage() {
  echo "usage: $(basename "$0") [--repo-root <path>] [--allow <relative-path>]..." >&2
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --repo-root)
      [ "$#" -ge 2 ] || { usage; exit 2; }
      repo_root="$2"
      shift 2
      ;;
    --allow)
      [ "$#" -ge 2 ] || { usage; exit 2; }
      custom_allow+=("$2")
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

if [ "${#custom_allow[@]}" -gt 0 ]; then
  ALLOWLIST=("${custom_allow[@]}")
else
  # scripts/test-lint-test-docstrings.sh is deliberately NOT in this list:
  # its regression tests build fixtures from literal, column-0 heredoc-style
  # strings like "test_ok() {" that this line-oriented awk matcher cannot
  # distinguish from a real declaration, so self-linting it produces false
  # FAILs on fixture text rather than real code. See
  # test_self_cannot_be_allowlisted in scripts/test-lint-test-docstrings.sh
  # for the regression test that pins this known limitation.
  ALLOWLIST=(
    scripts/test-guard-framework.sh
    scripts/test-migrate-routing-log.sh
    scripts/test-migrate-routing-to-events.sh
    scripts/test-pr-gate.sh
  )
fi

violations=0
checked=0

for rel in "${ALLOWLIST[@]}"; do
  f="$repo_root/$rel"
  if [[ ! -f "$f" ]]; then
    echo "lint-test-docstrings: allowlisted file not found: $rel" >&2
    exit 2
  fi
  checked=$((checked + 1))

  bad_lines="$(awk '
    function reset() { has_behavior = 0; pending_line = 0 }
    BEGIN { reset() }
    pending_line && /^\{[[:space:]]*$/ {
      if (!has_behavior) print pending_line
      reset()
      next
    }
    pending_line {
      # Declaration line was not immediately followed by an opening
      # brace -- stop treating it as pending and fall through to the
      # normal comment/reset handling below for this line.
      pending_line = 0
    }
    /^test_[A-Za-z0-9_]+\(\)[[:space:]]*\{[[:space:]]*$/ {
      if (!has_behavior) print NR
      reset()
      next
    }
    /^test_[A-Za-z0-9_]+\(\)[[:space:]]*$/ {
      pending_line = NR
      next
    }
    /^#/ {
      if ($0 ~ /Behavior:/) has_behavior = 1
      next
    }
    { reset() }
  ' "$f")"

  if [[ -n "$bad_lines" ]]; then
    while IFS= read -r ln; do
      echo "FAIL: $rel:$ln test_* function missing a '# Behavior:' docstring directly above its declaration" >&2
      violations=$((violations + 1))
    done <<< "$bad_lines"
  fi
done

if [[ "$violations" -gt 0 ]]; then
  echo "lint-test-docstrings: $violations violation(s) across $checked allowlisted file(s)" >&2
  exit 1
fi

echo "lint-test-docstrings: OK ($checked file(s) checked)"
