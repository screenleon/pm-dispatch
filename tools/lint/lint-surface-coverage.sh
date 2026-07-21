#!/usr/bin/env bash
# Verify every user-facing command, agent, and skill has an explicit coverage tier.
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
if [[ $# -gt 0 ]]; then
  [[ $# -eq 2 && "$1" == "--repo-root" && -n "$2" ]] || {
    printf 'usage: %s [--repo-root <path>]\n' "$(basename "$0")" >&2; exit 2;
  }
  repo_root="$(cd "$2" && pwd)"
fi

registry="$repo_root/tests/surface-coverage.tsv"
failures=0
fail() { printf 'lint-surface-coverage: %s\n' "$*" >&2; failures=$((failures + 1)); }

[[ -r "$registry" ]] || { fail "missing required file: tests/surface-coverage.tsv"; exit 1; }

declare -A expected=() declared=()
while IFS= read -r path; do expected["command:${path##*/}"]=1; done < <(find "$repo_root/commands" -maxdepth 1 -type f -name '*.md' -printf '%f\n' | sed 's/\.md$//' | LC_ALL=C sort)
while IFS= read -r path; do expected["agent:${path##*/}"]=1; done < <(find "$repo_root/agents" -maxdepth 1 -type f -name '*.md' -printf '%f\n' | sed 's/\.md$//' | LC_ALL=C sort)
while IFS= read -r path; do expected["skill:${path##*/}"]=1; done < <(find "$repo_root/skills" -mindepth 2 -maxdepth 2 -type f -name SKILL.md -printf '%h\n' | sed 's#.*/##' | LC_ALL=C sort)

while IFS= read -r line || [[ -n "$line" ]]; do
  line="${line%$'\r'}"
  [[ -z "$line" || "$line" == \#* ]] && continue
  IFS=$'\t' read -r surface coverage reason extra <<< "$line"
  if [[ -z "$surface" || -z "$coverage" || -z "$reason" || -n "$extra" ]]; then
    fail "malformed declaration: $line"; continue
  fi
  [[ "$surface" =~ ^(command|agent|skill):[a-z0-9][a-z0-9-]*$ ]] || { fail "invalid surface name: $surface"; continue; }
  case "$coverage" in e2e|unit|opt-in|manual-only|deprecated) ;; *) fail "invalid coverage tier for $surface: $coverage"; continue;; esac
  [[ "$reason" == reason:\ * && ${#reason} -gt 8 ]] || { fail "coverage declaration needs one-line reason: $surface"; continue; }
  [[ -z "${declared[$surface]:-}" ]] || { fail "duplicate coverage declaration: $surface"; continue; }
  declared["$surface"]=1
done < "$registry"

for surface in "${!expected[@]}"; do [[ -n "${declared[$surface]:-}" ]] || fail "surface missing coverage declaration: $surface"; done
for surface in "${!declared[@]}"; do [[ -n "${expected[$surface]:-}" ]] || fail "coverage declaration names no current surface: $surface"; done

if [[ "$failures" -gt 0 ]]; then
  printf 'lint-surface-coverage: %d failure(s)\n' "$failures" >&2; exit 1
fi
printf 'lint-surface-coverage: OK (%s declared surfaces)\n' "${#declared[@]}"
