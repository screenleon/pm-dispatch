#!/usr/bin/env bash
# Generate the runtime Gate schema bundle from the canonical JSON Schemas.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
OUTPUT="$REPO_ROOT/runtime/lib/gate-structural-schemas.json"
CHECK=false

usage() { printf 'Usage: %s [--check]\n' "${0##*/}"; }
while [[ $# -gt 0 ]]; do
  case "$1" in
    --check) CHECK=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
done

command -v jq >/dev/null 2>&1 || {
  printf 'gate-structural-validator: jq is required\n' >&2
  exit 2
}
mapfile -t schemas < <(find "$REPO_ROOT/core/schema" -maxdepth 1 -type f \
  -name 'gate-*.schema.json' -print | LC_ALL=C sort)
[[ "${#schemas[@]}" -gt 0 ]] || {
  printf 'gate-structural-validator: no Gate schemas found\n' >&2
  exit 1
}

tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/gate-structural-schemas.XXXXXX")"
trap 'rm -rf -- "$tmp_dir"' EXIT
bundle="$tmp_dir/bundle.json"
printf '{}\n' > "$bundle"
for schema_file in "${schemas[@]}"; do
  schema_name="$(basename "$schema_file" .schema.json)"
  next="$tmp_dir/next.json"
  jq --arg name "$schema_name" --slurpfile schema "$schema_file" \
    '.[$name] = $schema[0]' "$bundle" > "$next"
  mv -- "$next" "$bundle"
done
generated="$tmp_dir/generated.json"
jq -S . "$bundle" > "$generated"

if [[ "$CHECK" == true ]]; then
  [[ -f "$OUTPUT" ]] || {
    printf 'gate-structural-validator: generated bundle is missing: %s\n' "$OUTPUT" >&2
    exit 1
  }
  cmp -s "$generated" "$OUTPUT" || {
    printf 'gate-structural-validator: generated bundle is stale; run %s\n' \
      "${BASH_SOURCE[0]}" >&2
    exit 1
  }
  exit 0
fi
mkdir -p -- "$(dirname "$OUTPUT")"
mv -- "$generated" "$OUTPUT"
printf 'generated %s\n' "$OUTPUT"
