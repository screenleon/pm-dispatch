#!/usr/bin/env bash
# Verify that the canonical suite runner, shell test inventory, and CI agree.
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"

usage() {
  printf 'usage: %s [--repo-root <path>]\n' "$(basename "$0")" >&2
}

if [[ $# -gt 0 ]]; then
  [[ $# -eq 2 && "$1" == "--repo-root" && -n "$2" ]] || { usage; exit 2; }
  repo_root="$(cd "$2" && pwd)"
fi

runner="$repo_root/tests/lib/test-suite-runner.sh"
workflow="$repo_root/.github/workflows/lint.yml"
exclusions="$repo_root/tests/test-suite-exclusions.tsv"
ci_exemptions="$repo_root/tests/ci-suite-exemptions.tsv"
failures=0

fail() {
  printf 'lint-test-suite-registry: %s\n' "$*" >&2
  failures=$((failures + 1))
}

for required in "$runner" "$workflow" "$exclusions" "$ci_exemptions"; do
  [[ -r "$required" ]] || fail "missing required file: ${required#"$repo_root"/}"
done
[[ "$failures" -eq 0 ]] || exit 1

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT
names="$tmp_dir/names"
paths="$tmp_dir/paths"

awk '
  /^SUITE_NAMES=\(/ { inside=1; next }
  inside && /^\)/ { exit }
  inside {
    gsub(/^[[:space:]]+|[[:space:]]+$/, "")
    if ($0 != "") print $0
  }
' "$runner" > "$names"
awk '
  /^declare -A SUITE_PATHS=\(/ { inside=1; next }
  inside && /^\)/ { exit }
  inside && match($0, /\[([^]]+)\]="([^"]+)"/, parts) { print parts[1] "\t" parts[2] }
' "$runner" > "$paths"

[[ -s "$names" ]] || fail "could not parse SUITE_NAMES from tests/lib/test-suite-runner.sh"
[[ -s "$paths" ]] || fail "could not parse SUITE_PATHS from tests/lib/test-suite-runner.sh"
if [[ "$failures" -eq 0 ]] && ! diff -u <(LC_ALL=C sort "$names") <(cut -f1 "$paths" | LC_ALL=C sort) > "$tmp_dir/registry.diff"; then
  fail "SUITE_NAMES and SUITE_PATHS differ: $(tr '\n' ' ' < "$tmp_dir/registry.diff")"
fi

declare -A registered=() excluded=() ci_exempt=()
while IFS=$'\t' read -r name path; do
  [[ -n "$name" && -n "$path" ]] || { fail "malformed suite mapping"; continue; }
  [[ -z "${registered[$path]:-}" ]] || fail "duplicate registered path: $path"
  registered[$path]="$name"
done < "$paths"

while IFS= read -r line; do
  line="${line//\\t/$'\t'}"
  IFS=$'\t' read -r path reason extra <<< "$line"
  [[ -z "$path" || "$path" == \#* ]] && continue
  [[ -n "$reason" && -z "$extra" ]] || { fail "malformed test exclusion: $path"; continue; }
  [[ -z "${excluded[$path]:-}" ]] || fail "duplicate test exclusion: $path"
  excluded[$path]="$reason"
done < "$exclusions"

while IFS= read -r line; do
  line="${line//\\t/$'\t'}"
  IFS=$'\t' read -r name reason extra <<< "$line"
  [[ -z "$name" || "$name" == \#* ]] && continue
  [[ -n "$reason" && -z "$extra" ]] || { fail "malformed CI suite exemption: $name"; continue; }
  [[ -z "${ci_exempt[$name]:-}" ]] || fail "duplicate CI suite exemption: $name"
  ci_exempt[$name]="$reason"
done < "$ci_exemptions"

while IFS= read -r path; do
  [[ -n "${registered[$path]:-}" || -n "${excluded[$path]:-}" ]] || fail "unregistered test file: $path"
done < <(cd "$repo_root" && find tests/shell -maxdepth 1 -type f -name 'test-*.sh' -printf '%p\n' | LC_ALL=C sort)

for path in "${!excluded[@]}"; do
  [[ -f "$repo_root/$path" ]] || fail "excluded test file does not exist: $path"
  [[ -z "${registered[$path]:-}" ]] || fail "test cannot be both registered and excluded: $path"
done

while IFS=$'\t' read -r name path; do
  if grep -Fq "$path" "$workflow"; then
    [[ -z "${ci_exempt[$name]:-}" ]] || fail "CI suite exemption is unused: $name"
  elif [[ -z "${ci_exempt[$name]:-}" ]]; then
    fail "registered suite is absent from CI without exemption: $name ($path)"
  fi
done < "$paths"

for name in "${!ci_exempt[@]}"; do
  grep -Fxq "$name" "$names" || fail "CI suite exemption names no registered suite: $name"
done

if [[ "$failures" -gt 0 ]]; then
  printf 'lint-test-suite-registry: %d failure(s)\n' "$failures" >&2
  exit 1
fi
printf 'lint-test-suite-registry: OK (%s registered suites, %s explicit CI exemption(s))\n' \
  "$(wc -l < "$names")" "${#ci_exempt[@]}"
