#!/usr/bin/env bash
# Forbid bare `[[...]]` wikilinks in maintained, reader-facing docs. A `[[slug]]`
# that is not a ticket reference points at the maintainer's private memory
# (~/.claude/.../memory/) and is a dead link for anyone reading the repo.
#
# Allowed inside the scanned files:
#   - `[[CC-1234]]` / `[[CC-1234a]]`  -- backlog ticket cross-references
#   - anything inside a fenced ``` block or an inline `code span` (bash `[[ ]]`
#     tests, regex `[[:class:]]`, and deliberate `[[...]]` examples all live there)
#
# Anything else is a finding: use `[text](relative/path.md)` for a repo file, or
# plain text for a concept that has no repo home.
#
# Scanned set (this list IS the contract; widen it by editing here):
#   BACKLOG.md  MILESTONES.md  DECISIONS.md  README.md  CONTRIBUTING.md
#   docs/*.md   (top level only)
# NOT scanned: docs/spikes/  docs/audits/  docs/architecture/  docs/notes/
#   -- point-in-time records, not maintained reader docs.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
case "${1:-}" in
  --repo-root)
    [[ $# -eq 2 ]] || { printf 'lint-doc-wikilinks: --repo-root requires one path\n' >&2; exit 2; }
    repo_root="$2" ;;
  "") ;;
  *) printf 'lint-doc-wikilinks: usage: %s [--repo-root <path>]\n' "$0" >&2; exit 2 ;;
esac

failures=0
fail() { printf 'lint-doc-wikilinks: %s\n' "$*" >&2; failures=$((failures + 1)); }

files=(BACKLOG.md MILESTONES.md DECISIONS.md README.md CONTRIBUTING.md)
while IFS= read -r f; do files+=("${f#"$repo_root"/}"); done \
  < <(find "$repo_root/docs" -maxdepth 1 -type f -name '*.md' 2>/dev/null | LC_ALL=C sort)

ticket_re='^CC-[0-9]+[a-z]?$'
scanned=0
for rel in "${files[@]}"; do
  file="$repo_root/$rel"
  [[ -f "$file" ]] || continue
  scanned=$((scanned + 1))
  in_fence=0
  fence_ch=''
  fence_len=0
  lineno=0
  while IFS= read -r line || [[ -n "$line" ]]; do
    lineno=$((lineno + 1))
    trimmed="${line#"${line%%[![:space:]]*}"}"
    # A fence marker line: 3+ of the same ` or ~ at the start. CommonMark closes
    # a fence only with a *bare* run of the same char at least as long as the
    # opener; anything else on the line (an info string, a shorter/other run) is
    # literal code content.
    if [[ "$trimmed" =~ ^(\`{3,}|~{3,}) ]]; then
      marker="${BASH_REMATCH[1]}"
      mch="${marker:0:1}"
      mlen="${#marker}"
      rest="${trimmed:mlen}"
      if [[ "$in_fence" -eq 0 ]]; then
        in_fence=1; fence_ch="$mch"; fence_len="$mlen"; continue
      fi
      # inside a fence: close only on a bare, same-char, long-enough run
      if [[ "$mch" == "$fence_ch" && "$mlen" -ge "$fence_len" && "$rest" =~ ^[[:space:]]*$ ]]; then
        in_fence=0; fence_ch=''; fence_len=0
      fi
      continue
    fi
    [[ "$in_fence" -eq 1 ]] && continue
    # drop inline code spans before scanning, longest delimiter first: a span
    # opened with N backticks closes on the next run of exactly N, and its
    # content may itself contain shorter backtick runs (```a``b``` is one span).
    # shellcheck disable=SC2016  # the backticks in the sed pattern are literal
    stripped="$(printf '%s' "$line" | sed -E '
      s/```([^`]|`{1,2}[^`])*```//g
      s/``([^`]|`[^`])*``//g
      s/`[^`]*`//g')"
    [[ "$stripped" == *'[['* ]] || continue
    while [[ "$stripped" =~ \[\[([^][]+)\]\] ]]; do
      target="${BASH_REMATCH[1]}"
      if [[ ! "$target" =~ $ticket_re ]]; then
        fail "$rel:$lineno: bare wikilink [[${target}]] — use [text](path.md) for a repo file, or plain text; [[...]] to private memory is a dead link for a reader"
      fi
      stripped="${stripped/"[[${target}]]"/}"
    done
  done < "$file"
done

if [[ "$failures" -gt 0 ]]; then
  printf 'lint-doc-wikilinks: %d finding(s)\n' "$failures" >&2
  exit 1
fi
printf 'lint-doc-wikilinks: OK (%d file(s) scanned)\n' "$scanned"
