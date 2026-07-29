#!/usr/bin/env bash
# Generate pr-gate.sh's standalone verifier fallback from the shared library.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source_file="$repo_root/runtime/lib/gate-result-verify.sh"
target_file="$repo_root/runtime/bin/pr-gate.sh"
mode="${1:-sync}"

case "$mode" in
  sync | --check) ;;
  *)
    printf 'usage: %s [sync|--check]\n' "$0" >&2
    exit 2
    ;;
esac

block_file="$(mktemp)"
generated_file="$(mktemp)"
cleanup() {
  rm -f -- "$block_file" "$generated_file"
}
trap cleanup EXIT

functions=(
  gate_result_verdict_verify
  _gate_result_frontmatter_value
  _gate_result_sha256_stream
  _gate_result_sha256_file
  _gate_subject_common_dir
  _gate_subject_tree_fingerprint
  gate_subject_snapshot
  _gate_assurance_linked_evidence_verify
  gate_assurance_verify
  gate_result_verify
)

for function_name in "${functions[@]}"; do
  awk -v signature="$function_name() {" '
    $0 == signature { found = 1 }
    found {
      if ($0 == "") print ""
      else print "  " $0
    }
    found && $0 == "}" { exit }
  ' "$source_file" >> "$block_file"
  printf '\n' >> "$block_file"
done

awk -v block_file="$block_file" '
  BEGIN {
    start = "  # gate-result-verifier-fallback:start"
    finish = "  # gate-result-verifier-fallback:end"
  }
  $0 == start {
    print
    while ((getline generated < block_file) > 0) print generated
    close(block_file)
    replacing = 1
    next
  }
  replacing && $0 == finish {
    replacing = 0
    print
    next
  }
  !replacing { print }
  END {
    if (replacing) {
      print "generator: unterminated fallback marker" > "/dev/stderr"
      exit 1
    }
  }
' "$target_file" > "$generated_file"

if [[ "$mode" == --check ]]; then
  if ! cmp -s "$target_file" "$generated_file"; then
    printf 'generated verifier fallback is stale; run: %s sync\n' "$0" >&2
    exit 1
  fi
  exit 0
fi

if ! cmp -s "$target_file" "$generated_file"; then
  chmod --reference="$target_file" "$generated_file" 2>/dev/null || true
  mv -- "$generated_file" "$target_file"
fi
