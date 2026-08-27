#!/usr/bin/env bash
# gate-result-read.sh — read-only extraction helpers over a published PR-gate
# result file (`.gate-results/gate-*.md`). Shared by the pmctl-artifacts.sh gc
# summariser and pmctl-gate-stats.sh so the two never maintain divergent
# parsers for the same artifact family (frontmatter `reviewers:` map,
# ```reviewer_result_v1``` finding blocks).
#
# Pure reads: no state writes, no mutation of the run directory. Sourcing this
# file only defines functions.

# Newest published result file in a run directory, or empty string when the
# run has no `.gate-results/gate-*.md` yet (in flight, or a non-gate run).
gate_result_locate_file() {
  local run_dir="${1:-}"
  find "$run_dir/.gate-results" -maxdepth 1 -name 'gate-*.md' -type f 2>/dev/null | sort | tail -1
}

# Prints "reviewer: verdict" lines from the frontmatter `reviewers:` block.
# Walks the one nested map that _gate_result_frontmatter_value (scalar-only)
# does not cover; stops at the first top-level key after the block.
gate_result_reviewer_lines() {
  local gate_file="${1:-}"
  awk '
    BEGIN { s = 0; in_reviewers = 0 }
    /^---$/ { if (s == 0) { s = 1; next } else if (s == 1) { exit } }
    s && /^reviewers:/ { in_reviewers = 1; next }
    s && in_reviewers && /^[a-zA-Z_]/ { in_reviewers = 0 }
    s && in_reviewers && /^[[:space:]]+[a-zA-Z0-9_-]+:/ {
      line = $0
      sub(/^[[:space:]]+/, "", line)
      print line
    }
  ' "$gate_file"
}

# Best-effort finding-count-by-severity, grouped by reviewer. Degrades to the
# JSON string "unavailable" (never an empty/zero object, which would read as
# "no findings" instead of "could not extract") when no reviewer_result_v1
# block is present or a block fails to parse -- the schema has drifted across
# gate_result_version v1-v5 and old runs may carry unparseable blocks.
gate_result_findings_by_severity() {
  local gate_file="${1:-}" blocks
  blocks="$(awk '
    /^```reviewer_result_v1$/ { grab = 1; next }
    grab && /^```$/ { grab = 0; next }
    grab { print }
  ' "$gate_file")"
  if [[ -z "$blocks" ]]; then
    printf '"unavailable"'
    return 0
  fi
  if ! printf '%s' "$blocks" | jq -s -c '
      [ .[] | {reviewer, findings: (.findings // [])} ]
      | map({reviewer, counts: ((.findings | group_by(.severity)
          | map({(.[0].severity): length}) | add) // {})})
    ' 2>/dev/null; then
    printf '"unavailable"'
  fi
}
