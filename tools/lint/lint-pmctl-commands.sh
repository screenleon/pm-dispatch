#!/usr/bin/env bash
# Verify router, command metadata, help, JSON discovery, and README parity.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
if [[ $# -gt 0 ]]; then
  [[ $# -eq 2 && "$1" == "--repo" && -n "$2" ]] || {
    printf 'usage: %s [--repo <path>]\n' "$0" >&2
    exit 2
  }
  repo_root="$(cd "$2" && pwd)"
fi

registry="$repo_root/cli/commands.tsv"
router="$repo_root/cli/pmctl"
readme="$repo_root/README.md"
pmctl="$repo_root/cli/pmctl"
failures=0

fail() {
  printf 'lint-pmctl-commands: %s\n' "$*" >&2
  failures=$((failures + 1))
}

[[ -r "$registry" ]] || { fail "missing registry: $registry"; exit 1; }
[[ -r "$router" ]] || { fail "missing router: $router"; exit 1; }
[[ -r "$readme" ]] || { fail "missing README: $readme"; exit 1; }

expected_header=$'path\tsummary\tusage\tstability\tjson\tmutating\toptions\texample'
[[ "$(sed -n '1p' "$registry")" == "$expected_header" ]] || fail "registry header does not match the eight-column contract"

registry_errors="$(awk -F '\t' '
  NR == 1 { next }
  NF != 8 { print "line " NR ": expected 8 tab-separated fields"; next }
  $1 == "" || $2 == "" || $3 == "" || $4 == "" || $5 == "" || $6 == "" || $7 == "" || $8 == "" { print "line " NR ": empty field" }
  seen[$1]++ { print "line " NR ": duplicate path " $1 }
  $3 !~ /^pmctl / { print "line " NR ": usage must start with pmctl" }
  $4 !~ /^(stable|experimental|deprecated)$/ { print "line " NR ": invalid stability " $4 }
  $5 !~ /^(true|false)$/ { print "line " NR ": invalid json flag " $5 }
  $6 !~ /^(true|false)$/ { print "line " NR ": invalid mutating flag " $6 }
  $8 !~ /^pmctl / { print "line " NR ": example must start with pmctl" }
' "$registry")"
[[ -z "$registry_errors" ]] || fail "malformed registry:\n$registry_errors"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT
router_paths="$tmp_dir/router.paths"
registry_paths="$tmp_dir/registry.paths"

awk '
  /^  [a-z][a-z-]*\/[^)]*\)/ {
    route=$0
    sub(/^  /, "", route)
    sub(/\).*/, "", route)
    if (route == "pm/*") next
    if (route == "ship/*") { print "ship"; next }
    if (route == "commands/--json") { print "commands"; next }
    gsub(/\//, " ", route)
    print route
  }
' "$router" | LC_ALL=C sort -u > "$router_paths"
awk -F '\t' 'NR > 1 { print $1 }' "$registry" | LC_ALL=C sort -u > "$registry_paths"
if ! diff -u "$router_paths" "$registry_paths" > "$tmp_dir/router-registry.diff"; then
  fail "router and registry command paths differ:\n$(<"$tmp_dir/router-registry.diff")"
fi

json_paths="$tmp_dir/json.paths"
if ! "$pmctl" commands --json > "$tmp_dir/commands.json" 2> "$tmp_dir/commands.err"; then
  fail "pmctl commands --json failed: $(<"$tmp_dir/commands.err")"
elif ! jq -e '.commands | type == "array" and all(.[]; (.path|type)=="string" and (.summary|type)=="string" and (.usage|type)=="string" and (.stability|type)=="string" and (.json|type)=="boolean" and (.mutating|type)=="boolean")' "$tmp_dir/commands.json" >/dev/null; then
  fail "pmctl commands --json does not satisfy the discovery schema"
else
  jq -r '.commands[].path' "$tmp_dir/commands.json" | LC_ALL=C sort -u > "$json_paths"
  if ! diff -u "$registry_paths" "$json_paths" > "$tmp_dir/registry-json.diff"; then
    fail "registry and commands JSON paths differ:\n$(<"$tmp_dir/registry-json.diff")"
  fi
fi

expected_readme="$tmp_dir/readme.expected"
actual_readme="$tmp_dir/readme.actual"
awk -F '\t' 'NR > 1 { printf "- `%s` — %s [%s; JSON: %s; mutating: %s]\n", $1, $2, $4, $5, $6 }' "$registry" > "$expected_readme"
awk '
  /<!-- pmctl-command-index:start -->/ { if (inside || seen_start++) exit 3; inside=1; next }
  /<!-- pmctl-command-index:end -->/ { if (!inside || seen_end++) exit 4; inside=0; next }
  inside { print }
  END { if (inside || seen_start != 1 || seen_end != 1) exit 5 }
' "$readme" > "$actual_readme" || fail "README must contain exactly one complete pmctl command index block"
if ! diff -u "$expected_readme" "$actual_readme" > "$tmp_dir/readme.diff"; then
  fail "README command index differs from registry:\n$(<"$tmp_dir/readme.diff")"
fi

while IFS=$'\t' read -r path _summary usage stability _json _mutating _options _example; do
  [[ "$path" == "path" ]] && continue
  read -r -a parts <<< "$path"
  if ! "$pmctl" help "${parts[@]}" > "$tmp_dir/help.out" 2> "$tmp_dir/help.err"; then
    fail "help failed for $path: $(<"$tmp_dir/help.err")"
    continue
  fi
  grep -Fq "$usage" "$tmp_dir/help.out" || fail "help for $path omits canonical usage"
  grep -Fq "Stability: $stability" "$tmp_dir/help.out" || fail "help for $path omits stability"
  grep -Fq 'Main options:' "$tmp_dir/help.out" || fail "help for $path omits options"
  grep -Fq 'Example:' "$tmp_dir/help.out" || fail "help for $path omits example"
done < "$registry"

help_home="$tmp_dir/empty-home"
mkdir -p "$help_home"
if ! HOME="$help_home" "$pmctl" --help > "$tmp_dir/root-help.out" 2> "$tmp_dir/root-help.err"; then
  fail "root help failed: $(<"$tmp_dir/root-help.err")"
elif find "$help_home" -mindepth 1 -print -quit | grep -q .; then
  fail "root help wrote into HOME"
fi

if [[ "$failures" -gt 0 ]]; then
  printf 'lint-pmctl-commands: %d failure(s)\n' "$failures" >&2
  exit 1
fi
printf 'lint-pmctl-commands: OK (%s commands checked)\n' "$(( $(wc -l < "$registry") - 1 ))"
