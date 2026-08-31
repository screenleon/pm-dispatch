#!/usr/bin/env bash
# Keep README.md's user-facing surface lists in sync with the repository.
# The lists drifted (2 of 14 commands, no Skills section) because nothing
# guarded them; this lint asserts set-equality between each README section and
# the corresponding directory.
#
#   README "### Commands"  <->  commands/*.md      (bullet name, optional leading /)
#   README "### Agents"    <->  agents/*.md        (bullet name)
#   README "### Skills"    <->  skills/*/          (bullet name)
#
# A bullet is a line matching  ^- **[/]<name>** <space>  ; group headers like
# **Orchestration** are not bullets and are ignored. Findings: a directory
# entry with no README bullet (drift-in), a README bullet naming nothing on
# disk (stale), or a missing section heading (README restructured past the
# anchor). This lint does not generate, reorder, or reword README content.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
case "${1:-}" in
  --repo-root)
    [[ $# -eq 2 ]] || { printf 'lint-readme-surface-lists: --repo-root requires one path\n' >&2; exit 2; }
    repo_root="$2" ;;
  "") ;;
  *) printf 'lint-readme-surface-lists: usage: %s [--repo-root <path>]\n' "$0" >&2; exit 2 ;;
esac

readme="$repo_root/README.md"
failures=0
fail() { printf 'lint-readme-surface-lists: %s\n' "$*" >&2; failures=$((failures + 1)); }

[[ -f "$readme" ]] || { fail "missing README.md"; exit 1; }

# bullets_in_section <heading> -> the bullet names under "### <heading>", in
# document order, NOT de-duplicated (one entry per surface is part of the
# contract, so a repeated bullet must be visible to the caller).
bullets_in_section() {
  awk -v want="### $1" '
    $0 == want { inside = 1; next }
    inside && /^#{2,3} / { exit }
    inside && /^- \*\*\/?[a-z][a-z0-9-]*\*\* / {
      line = $0
      sub(/^- \*\*\/?/, "", line)
      sub(/\*\*.*$/, "", line)
      print line
    }
  ' "$readme"
}

section_present() {
  grep -qE "^### $1( |$)" "$readme"
}

# compare <label> <heading> <newline-separated inventory>
compare() {
  local label="$1" heading="$2" inventory="$3"
  local listed_raw dupes listed missing extra d m e
  if ! section_present "$heading"; then
    fail "README.md has no '### $heading' section"
    return
  fi
  listed_raw="$(bullets_in_section "$heading")"
  dupes="$(printf '%s\n' "$listed_raw" | grep -v '^$' | LC_ALL=C sort | uniq -d)"
  while IFS= read -r d; do
    [[ -n "$d" ]] || continue
    fail "README '### $heading' lists '$d' more than once (one bullet per $label)"
  done <<< "$dupes"
  listed="$(printf '%s\n' "$listed_raw" | LC_ALL=C sort -u)"
  missing="$(comm -23 <(printf '%s\n' "$inventory" | LC_ALL=C sort -u) <(printf '%s\n' "$listed"))"
  extra="$(comm -13 <(printf '%s\n' "$inventory" | LC_ALL=C sort -u) <(printf '%s\n' "$listed"))"
  while IFS= read -r m; do
    [[ -n "$m" ]] || continue
    fail "$label '$m' exists on disk but has no bullet under README '### $heading'"
  done <<< "$missing"
  while IFS= read -r e; do
    [[ -n "$e" ]] || continue
    fail "README '### $heading' lists '$e' but no such $label exists on disk"
  done <<< "$extra"
}

commands_inv="$(find "$repo_root/commands" -maxdepth 1 -type f -name '*.md' -printf '%f\n' 2>/dev/null | sed 's/\.md$//')"
agents_inv="$(find "$repo_root/agents" -maxdepth 1 -type f -name '*.md' -printf '%f\n' 2>/dev/null | sed 's/\.md$//')"
skills_inv="$(find "$repo_root/skills" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null)"

compare command Commands "$commands_inv"
compare agent   Agents   "$agents_inv"
compare skill   Skills   "$skills_inv"

if [[ "$failures" -gt 0 ]]; then
  printf 'lint-readme-surface-lists: %d finding(s)\n' "$failures" >&2
  exit 1
fi
printf 'lint-readme-surface-lists: OK (%d commands, %d agents, %d skills)\n' \
  "$(printf '%s\n' "$commands_inv" | grep -c .)" \
  "$(printf '%s\n' "$agents_inv" | grep -c .)" \
  "$(printf '%s\n' "$skills_inv" | grep -c .)"
