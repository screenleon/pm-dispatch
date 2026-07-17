#!/usr/bin/env bash
# Validate that no subagent declares the `Agent` tool in its frontmatter.
# Claude Code strips Agent from subagent runtime schemas regardless of
# declaration, so leaving it in frontmatter is misleading drift.
# See README.md "Design notes" for the rule.

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
agents_dir="$repo_root/agents"

if [ ! -d "$agents_dir" ]; then
  echo "lint-agents: $agents_dir not found" >&2
  exit 2
fi

violations=0
checked=0
for f in "$agents_dir"/*.md; do
  [ -e "$f" ] || continue
  checked=$((checked + 1))

  # Require well-formed frontmatter (>=2 `---` markers)
  fence_count=$(tr -d '\r' < "$f" | grep -c '^---$' || true)
  if [ "$fence_count" -lt 2 ]; then
    echo "WARN: $(basename "$f") has no YAML frontmatter; skipping" >&2
    continue
  fi

  # Extract content between the first two `---` lines
  fm=$(awk '/^---$/{c++; next} c==1' "$f")

  # Capture the tools: block — the inline scalar form OR a block-list
  # spanning indented `- ` lines until the next non-indented key.
  tools_block=$(printf '%s\n' "$fm" | awk '
    /^tools:/ { print; in_block=1; next }
    in_block {
      if ($0 ~ /^[[:space:]]/) { print; next }
      else { in_block=0 }
    }
  ')

  if [ -z "$tools_block" ]; then
    continue
  fi

  # Match Agent as a whole token. Separators in YAML scalar/flow:
  # `,` ` ` `[` `]` `:` and start/end of line. In block-list, `-` precedes.
  if printf '%s' "$tools_block" | grep -qE '(^|[][, :-])Agent([][, :]|$)'; then
    echo "FAIL: $(basename "$f") declares Agent in tools" >&2
    printf '%s\n' "$tools_block" | sed 's/^/  /' >&2
    violations=$((violations + 1))
  fi
done

if [ "$violations" -gt 0 ]; then
  echo "lint-agents: $violations violation(s). Subagents cannot spawn subagents — remove Agent from tools." >&2
  exit 1
fi

if [ "$checked" -eq 0 ]; then
  echo "lint-agents: no agent files found in $agents_dir" >&2
  exit 1
fi

echo "lint-agents: OK ($checked agent files checked)"
