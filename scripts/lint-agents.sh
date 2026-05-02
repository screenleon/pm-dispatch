#!/usr/bin/env bash
# Validate that no subagent declares the `Agent` tool in its frontmatter.
# Claude Code strips Agent from subagent runtime schemas regardless of
# declaration, so leaving it in frontmatter is misleading drift.
# See README.md "Design notes" for the rule.

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
agents_dir="$repo_root/agents"

if [ ! -d "$agents_dir" ]; then
  echo "lint-agents: $agents_dir not found" >&2
  exit 2
fi

violations=0
for f in "$agents_dir"/*.md; do
  [ -e "$f" ] || continue
  # Extract content between the first two `---` lines (YAML frontmatter)
  fm=$(awk '/^---$/{c++; next} c==1' "$f")
  tools_line=$(printf '%s\n' "$fm" | grep -E '^tools:' || true)
  if [ -z "$tools_line" ]; then
    continue
  fi
  if printf '%s' "$tools_line" | grep -qE '(^|[, ])Agent([, ]|$)'; then
    echo "FAIL: $(basename "$f") declares Agent in tools: $tools_line" >&2
    violations=$((violations + 1))
  fi
done

if [ "$violations" -gt 0 ]; then
  echo "lint-agents: $violations violation(s). Subagents cannot spawn subagents — remove Agent from tools." >&2
  exit 1
fi

echo "lint-agents: OK ($(ls "$agents_dir"/*.md 2>/dev/null | wc -l) agent files checked)"
