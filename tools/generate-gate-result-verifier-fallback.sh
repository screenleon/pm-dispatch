#!/usr/bin/env bash
# Generate pr-gate.sh's standalone verifier fallback from the shared library.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source_file="$repo_root/runtime/lib/gate-result-verify.sh"
identifier_policy_file="$repo_root/runtime/lib/identifier-policy.sh"
target_file="$repo_root/runtime/bin/pr-gate.sh"
generator_relpath="tools/generate-gate-result-verifier-fallback.sh"
generator_file="$repo_root/$generator_relpath"
mode="${1:-sync}"

die() {
  printf 'generator: %s\n' "$1" >&2
  exit 1
}

resolve_path() {
  local path="$1"
  readlink -f -- "$path" 2>/dev/null ||
    (cd "$(dirname "$path")" && printf '%s/%s\n' "$(pwd -P)" "$(basename "$path")")
}

[[ -f "$generator_file" ]] || die "canonical generator is missing: $generator_relpath"
[[ -x "$generator_file" ]] || die "canonical generator is not executable: $generator_relpath"
[[ "$(resolve_path "${BASH_SOURCE[0]}")" == "$(resolve_path "$generator_file")" ]] ||
  die "invocation is not the canonical generator: $generator_relpath"
[[ -r "$source_file" ]] || die "canonical verifier source is missing or unreadable: runtime/lib/gate-result-verify.sh"
[[ -r "$identifier_policy_file" ]] || die "canonical identifier policy is missing or unreadable: runtime/lib/identifier-policy.sh"
[[ -r "$target_file" ]] || die "fallback target is missing or unreadable: runtime/bin/pr-gate.sh"

case "$mode" in
  sync | --check) ;;
  *)
    printf 'usage: %s [sync|--check]\n' "$0" >&2
    exit 2
    ;;
esac

start_marker='  # gate-result-verifier-fallback:start'
finish_marker='  # gate-result-verifier-fallback:end'
provenance_header='  # Generated from runtime/lib/gate-result-verify.sh by'
provenance_line="  # $generator_relpath. Do not edit this block by hand."

validate_markers() {
  local file="$1" start_count finish_count start_line finish_line
  start_count="$(grep -Fxc -- "$start_marker" "$file" || true)"
  finish_count="$(grep -Fxc -- "$finish_marker" "$file" || true)"
  [[ "$start_count" -eq 1 && "$finish_count" -eq 1 ]] ||
    die "fallback markers must each occur exactly once in $file"
  start_line="$(grep -Fnx -- "$start_marker" "$file" | cut -d: -f1)"
  finish_line="$(grep -Fnx -- "$finish_marker" "$file" | cut -d: -f1)"
  (( start_line < finish_line )) || die "fallback markers are out of order in $file"
}

validate_provenance() {
  local file="$1" header_count path_count adjacent_count
  header_count="$(grep -Fxc -- "$provenance_header" "$file" || true)"
  path_count="$(grep -Fxc -- "$provenance_line" "$file" || true)"
  adjacent_count="$(awk -v header="$provenance_header" -v path="$provenance_line" '
    $0 == header {
      if ((getline following) > 0 && following == path) count++
    }
    END { print count + 0 }
  ' "$file")"
  [[ "$header_count" -eq 1 ]] ||
    die "generated fallback provenance header is missing or duplicated in $file"
  [[ "$path_count" -eq 1 && "$adjacent_count" -eq 1 ]] ||
    die "generated fallback provenance must directly and uniquely name $generator_relpath in $file"
}

validate_markers "$target_file"
if [[ "$mode" == "--check" ]]; then
  validate_provenance "$target_file"
fi

block_file="$(mktemp)"
generated_file="$(mktemp)"
cleanup() {
  rm -f -- "$block_file" "$generated_file"
}
trap cleanup EXIT

functions=(
  gate_result_verdict_verify
  _gate_result_frontmatter_value
  _gate_reviewer_protocol_surfaces
  _gate_reviewer_protocol_reference_index_json
  _gate_reviewer_protocol_document_verify
  _gate_reviewer_protocol_documents
  _gate_reviewer_protocol_verdict_extract
  _gate_reviewer_protocol_final_extract
  gate_reviewer_protocol_verify
  _gate_synthesis_protocol_documents
  gate_synthesis_protocol_verify
  _gate_result_sha256_stream
  _gate_result_sha256_file
  _gate_subject_common_dir
  _gate_subject_tree_fingerprint
  gate_subject_snapshot
  gate_scope_manifest_verify
  _gate_assurance_linked_evidence_verify
  gate_assurance_verify
  gate_result_verify
)

extract_function() {
  local function_name="$1"
  awk -v signature="$function_name() {" '
    $0 == signature { found = 1 }
    found {
      if ($0 == "") print ""
      else print "  " $0
    }
    found && $0 == "}" { exit }
  ' "$source_file"
}

# Copy-mode has no sibling runtime/lib to source. Embed only the policy helper
# needed by the verifier, generated from the canonical policy source alongside
# the verifier functions below.
identifier_policy_body="$(awk '
  $0 == "pm_identifier_run_ere_pattern() {" { found = 1 }
  found {
    if ($0 == "") print ""
    else print "  " $0
  }
  found && $0 == "}" { exit }
' "$identifier_policy_file")"
[[ -n "$identifier_policy_body" ]] || die "canonical identifier policy function is missing"
printf '%s\n' "$identifier_policy_body" >> "$block_file"
printf '\n' >> "$block_file"

for function_name in "${functions[@]}"; do
  function_body="$(extract_function "$function_name")"
  [[ -n "$function_body" ]] || die "canonical verifier function is missing: $function_name"
  printf '%s\n' "$function_body" >> "$block_file"
  printf '\n' >> "$block_file"
done

awk -v block_file="$block_file" -v start="$start_marker" -v finish="$finish_marker" \
  -v provenance_header="$provenance_header" -v provenance_line="$provenance_line" '
  $0 == start {
    print
    while ((getline generated < block_file) > 0) print generated
    close(block_file)
    replacing = 1
    next
  }
  $0 == provenance_header { print; provenance_header_seen = 1; next }
  provenance_header_seen && $0 ~ /^  # .*\.sh\. Do not edit this block by hand\.$/ {
    print provenance_line
    provenance_header_seen = 0
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

validate_markers "$generated_file"
validate_provenance "$generated_file"

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
