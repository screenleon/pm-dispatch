#!/usr/bin/env bash
# Verify every "<!-- BEGIN GENERATED: <source> -->" markdown table in a doc
# still matches the source file it claims to mirror.
#
# Blocks are discovered dynamically (git ls-files, including untracked-but-
# not-ignored files, plus a marker scan), not from a fixed list -- a new
# GENERATED block in any doc is checked the moment it exists, with no
# separate registration step (and no need to `git add` it first). This is
# what makes the check a ratchet against future drift rather than a
# one-time audit.
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
if [[ $# -gt 0 ]]; then
  [[ $# -eq 2 && "$1" == "--repo-root" && -n "$2" ]] || {
    printf 'usage: %s [--repo-root <path>]\n' "$(basename "$0")" >&2
    exit 2
  }
  repo_root="$(cd "$2" && pwd)"
fi

fail() { printf 'check-policy-doc-sync: %s\n' "$*" >&2; }

failures=0
blocks_checked=0
files_with_blocks=0

# Trim leading/trailing whitespace from a value.
trim() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

# Render a headered TSV (skipping leading `#` comment lines) as full
# "| a | b | c |" markdown row lines -- the exact text the doc block is
# expected to contain, so the comparison never needs to split a doc row
# whose cell values may themselves contain literal "|" characters (regex
# alternation in the policy-signals patterns is the concrete case that
# forced this design).
render_tsv_as_md_rows() {
  local file="$1"
  awk -F '\t' '
    /^[[:space:]]*#/ { next }
    /^[[:space:]]*$/ { next }
    {
      line = "|"
      for (i = 1; i <= NF; i++) {
        v = $i
        gsub(/\r$/, "", v)
        line = line " " v " |"
      }
      print line
    }
  ' "$file"
}

# Compare a doc block's raw table-row lines against a TSV source's rendered
# rows. Returns 0 and prints nothing on match; returns 1 and prints the
# mismatch otherwise.
compare_tsv_block() {
  local doc="$1" source="$2" block_content="$3"
  local doc_rows expected_rows
  # A table row line starts with "|"; the separator row ("|---|---|") is the
  # only such line made up of just dashes/colons/spaces/pipes, so excluding
  # it does not risk dropping a real data row (every real row here has at
  # least one alphanumeric cell).
  doc_rows="$(printf '%s\n' "$block_content" | grep -E '^\|' | grep -Ev '^\|[-: |]+\|$' || true)"
  expected_rows="$(render_tsv_as_md_rows "$source")"
  if [[ "$doc_rows" != "$expected_rows" ]]; then
    fail "drift: $doc block for $source no longer matches the source file"
    diff <(printf '%s\n' "$expected_rows") <(printf '%s\n' "$doc_rows") \
      | sed 's/^/check-policy-doc-sync:   /' >&2 || true
    return 1
  fi
  return 0
}

# core/policy/reviewer-policy.yaml is a one-off structure (a `reviewers:` map
# of {kind, phase} plus a `verdicts:` list), not a plain TSV -- a dedicated
# comparator, not a general YAML-to-table renderer. Extending this to a
# second YAML source is deliberately left for whenever that need actually
# arises rather than guessed at now. Builds both expected tables in one pass
# over the source (a `section` state carries across the reviewers/verdicts
# boundary) and compares them as whole rendered "| a | b |" lines, the same
# strategy compare_tsv_block uses -- these values are plain words with no
# literal "|", so nothing here needs cell-splitting either.
compare_reviewer_policy_yaml_block() {
  local doc="$1" source="$2" block_content="$3"
  local expected_reviewers="" expected_verdicts="" section="" reviewer="" kind="" phase="" line
  while IFS= read -r line; do
    case "$line" in
      reviewers:) section=reviewers; continue ;;
      verdicts:) section=verdicts; continue ;;
      '') continue ;;
    esac
    if [[ "$section" == reviewers ]]; then
      case "$line" in
        '  '*:)
          reviewer="${line#  }"
          reviewer="${reviewer%:}"
          kind="" phase=""
          ;;
        '    kind: '*) kind="${line#*kind: }" ;;
        '    phase: '*)
          phase="${line#*phase: }"
          expected_reviewers+="| ${reviewer} | ${kind} | ${phase} |"$'\n'
          ;;
      esac
    elif [[ "$section" == verdicts ]]; then
      case "$line" in
        '  - '*)
          local v="${line#  - }"
          v="${v%%[[:space:]]#*}"
          v="$(trim "$v")"
          expected_verdicts+="| ${v} |"$'\n'
          ;;
      esac
    fi
  done < "$source"

  local doc_reviewer_rows doc_verdict_rows
  doc_reviewer_rows="$(printf '%s\n' "$block_content" | awk '
    /^\| reviewer \|/ { header=1; next }
    header && /^\|---/ { next }
    header && /^\|/ {
      if ($0 ~ /^\| verdict \|$/) { exit }
      print
    }
  ')"$'\n'
  doc_verdict_rows="$(printf '%s\n' "$block_content" | awk '
    /^\| verdict \|/ { header=1; next }
    header && /^\|---/ { next }
    header && /^\|/ { print }
  ')"$'\n'

  if [[ "$doc_reviewer_rows" != "$expected_reviewers" ]]; then
    fail "drift: $doc reviewer table no longer matches $source"
    diff <(printf '%s' "$expected_reviewers") <(printf '%s' "$doc_reviewer_rows") \
      | sed 's/^/check-policy-doc-sync:   /' >&2 || true
    return 1
  fi
  if [[ "$doc_verdict_rows" != "$expected_verdicts" ]]; then
    fail "drift: $doc verdict table no longer matches $source"
    diff <(printf '%s' "$expected_verdicts") <(printf '%s' "$doc_verdict_rows") \
      | sed 's/^/check-policy-doc-sync:   /' >&2 || true
    return 1
  fi
  return 0
}

while IFS= read -r doc; do
  doc_path="$repo_root/$doc"
  [[ -f "$doc_path" ]] || continue

  # Discover BEGIN/END marker pairs by line number, in one pass, so the block
  # content can be re-extracted with sed rather than threaded through awk's
  # own buffer. Unbalanced-marker detection rides along in the same pass
  # (an "open" counter that must return to zero) instead of re-scanning the
  # file a second time just to recount the same two patterns.
  scan="$(awk '
    /^<!-- BEGIN GENERATED: .* -->$/ {
      source = $0
      sub(/^<!-- BEGIN GENERATED: /, "", source)
      sub(/ -->$/, "", source)
      start = FNR
      open++
      next
    }
    /^<!-- END GENERATED -->$/ {
      if (open > 0) { printf "BLOCK\t%s\t%s\t%s\n", source, start, FNR }
      open--
      next
    }
    END { if (open != 0) print "UNBALANCED" }
  ' "$doc_path")"
  [[ -n "$scan" ]] || continue

  if [[ "$scan" == *$'\n'UNBALANCED || "$scan" == UNBALANCED ]]; then
    fail "$doc: unmatched BEGIN/END GENERATED marker pair"
    failures=$((failures + 1))
    continue
  fi
  markers="$(printf '%s\n' "$scan" | sed -n 's/^BLOCK\t//p')"

  files_with_blocks=$((files_with_blocks + 1))
  while IFS=$'\t' read -r source start end; do
    blocks_checked=$((blocks_checked + 1))
    source_path="$repo_root/$source"
    if [[ ! -f "$source_path" ]]; then
      fail "$doc: GENERATED block references missing source: $source"
      failures=$((failures + 1))
      continue
    fi
    block_content="$(sed -n "$((start + 1)),$((end - 1))p" "$doc_path")"
    case "$source" in
      *.tsv)
        compare_tsv_block "$doc" "$source_path" "$block_content" || failures=$((failures + 1))
        ;;
      core/policy/reviewer-policy.yaml)
        compare_reviewer_policy_yaml_block "$doc" "$source_path" "$block_content" || failures=$((failures + 1))
        ;;
      *)
        fail "$doc: no comparator registered for source type: $source"
        failures=$((failures + 1))
        ;;
    esac
  done <<< "$markers"
done < <(git -C "$repo_root" ls-files --cached --others --exclude-standard -- '*.md')

if [[ "$failures" -gt 0 ]]; then
  fail "$failures drifted or invalid GENERATED block(s) found"
  exit 1
fi
printf 'check-policy-doc-sync: OK (%s GENERATED block(s) verified across %s file(s))\n' \
  "$blocks_checked" "$files_with_blocks"
