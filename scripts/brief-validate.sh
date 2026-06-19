#!/usr/bin/env bash
# Validate dispatch brief fields before spawning an executor.

set -euo pipefail

usage() {
  printf 'usage: brief-validate.sh <brief-file>\n'
}

reject() {
  printf 'REJECT: %s\n' "$1"
  exit 1
}

warn() {
  printf 'WARN: %s\n' "$1"
}

has_required_field() {
  local brief="$1" field="$2"
  grep -Eq "^${field}:[[:space:]]*[^[:space:]]" "$brief"
}

has_files_section() {
  local brief="$1"
  grep -Eq '^files:' "$brief"
}

has_files_entries() {
  local brief="$1"
  awk '
    /^[a-z_]+:[[:space:]]*/ {
      if ($0 ~ /^files:/) {
        in_files = 1
        next
      }
      if (in_files) {
        in_files = 0
      }
    }
    in_files && /^[[:space:]]*-[[:space:]]+[^[:space:]]/ {
      found = 1
    }
    END {
      exit found ? 0 : 1
    }
  ' "$brief"
}

has_acceptance_entries() {
  local brief="$1"
  awk '
    /^[a-z_]+:[[:space:]]*/ {
      if ($0 ~ /^acceptance:/) {
        in_acceptance = 1
        next
      }
      if (in_acceptance) {
        in_acceptance = 0
      }
    }
    in_acceptance && /^[[:space:]]*-[[:space:]]+[^[:space:]]/ {
      found = 1
    }
    END {
      exit found ? 0 : 1
    }
  ' "$brief"
}

has_file_writing_entry() {
  local brief="$1"
  awk '
    /^[a-z_]+:[[:space:]]*/ {
      if ($0 ~ /^files:/) {
        in_files = 1
        next
      }
      if (in_files) {
        in_files = 0
      }
    }
    in_files && /^[[:space:]]*-[[:space:]]+/ {
      if ($0 !~ /^[[:space:]]*-[[:space:]]*read:/) {
        writing = 1
      }
    }
    END {
      exit writing ? 0 : 1
    }
  ' "$brief"
}

has_self_verify_entry() {
  local brief="$1"
  awk '
    /^[a-z_]+:[[:space:]]*/ {
      if ($0 ~ /^self_verify:/) {
        in_self_verify = 1
        next
      }
      if (in_self_verify) {
        in_self_verify = 0
      }
    }
    in_self_verify && /^[[:space:]]*-[[:space:]]+[^[:space:]]/ {
      found = 1
    }
    END {
      exit found ? 0 : 1
    }
  ' "$brief"
}

working_dir_value() {
  local brief="$1"
  awk '
    /^working_dir:[[:space:]]*/ {
      sub(/^working_dir:[[:space:]]*/, "", $0)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", $0)
      print
      exit
    }
  ' "$brief"
}

schema_version_value() {
  local brief="$1"
  awk '
    /^schema_version:[[:space:]]*/ {
      sub(/^schema_version:[[:space:]]*/, "", $0)
      gsub(/[[:space:]]/, "", $0)
      print
      exit
    }
  ' "$brief"
}

architecture_impact_value() {
  local brief="$1"
  awk '
    /^architecture_impact:[[:space:]]*/ {
      sub(/^architecture_impact:[[:space:]]*/, "", $0)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", $0)
      print
      exit
    }
  ' "$brief"
}

has_conceptual_map() {
  local brief="$1"
  awk '
    /^conceptual_map:[[:space:]]*/ {
      rest = $0
      sub(/^conceptual_map:[[:space:]]*/, "", rest)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", rest)
      if (rest != "" && rest != "|" && rest != ">" && rest != "|-" && rest != ">-") {
        found = 1
        exit
      }
      in_map = 1
      next
    }
    in_map {
      if (/^[a-z_]+:[[:space:]]*/) { in_map = 0; next }
      if (/^[[:space:]]+[^[:space:]]/) { found = 1; exit }
    }
    END { exit found ? 0 : 1 }
  ' "$brief"
}

# Retrieval evidence via a context block: either a hand-authored `context:` block
# or the `auto_context:` block that `pmctl dispatch run --auto-pack` appends to the
# augmented brief. A bare key with only a block-scalar indicator (| > |- >-), an
# inline comment, or an indented body of only comment/blank lines is not evidence —
# real refs or prior-art anchors are required. (The auto-pack block leads with a
# comment line but follows it with real pointer entries, so it still counts.)
has_context_evidence() {
  local brief="$1"
  awk '
    /^(auto_)?context:[[:space:]]*/ {
      rest = $0
      sub(/^(auto_)?context:[[:space:]]*/, "", rest)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", rest)
      # Strip a trailing inline YAML comment (whitespace + #...) before classifying,
      # so empty forms with a trailing comment (context: [] # TODO) are still empty.
      sub(/[[:space:]]+#.*$/, "", rest)
      # Block-scalar header (| or >, optional chomp +/-, optional trailing # comment):
      # the evidence is in the indented body, checked below.
      is_block = (rest ~ /^[|>][+-]?([[:space:]]+#.*)?$/)
      # Structurally-empty inline forms carry no evidence.
      is_empty = (rest == "" || rest == "\"\"" || rest == "\047\047" || rest == "[]" || rest == "{}" || rest == "~" || rest == "null")
      if (!is_block && !is_empty && rest !~ /^#/) { found = 1; exit }
      in_context = 1
      next
    }
    in_context {
      if (/^[a-z_]+:[[:space:]]*/) { in_context = 0; next }
      if (/^[[:space:]]*#/ || /^[[:space:]]*$/) next
      if (/^[[:space:]]+[^[:space:]]/) { found = 1; exit }
    }
    END { exit found ? 0 : 1 }
  ' "$brief"
}

has_retrieval_skip_reason() {
  local brief="$1"
  awk '
    /^retrieval_skip_reason:[[:space:]]*/ {
      rest = $0
      sub(/^retrieval_skip_reason:[[:space:]]*/, "", rest)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", rest)
      sub(/[[:space:]]+#.*$/, "", rest)
      is_block = (rest ~ /^[|>][+-]?([[:space:]]+#.*)?$/)
      is_empty = (rest == "" || rest == "\"\"" || rest == "\047\047" || rest == "[]" || rest == "{}" || rest == "~" || rest == "null")
      if (!is_block && !is_empty && rest !~ /^#/) {
        found = 1
        exit
      }
      in_reason = 1
      next
    }
    in_reason {
      if (/^[a-z_]+:[[:space:]]*/) { in_reason = 0; next }
      if (/^[[:space:]]*#/ || /^[[:space:]]*$/) next
      if (/^[[:space:]]+[^[:space:]]/) { found = 1; exit }
    }
    END { exit found ? 0 : 1 }
  ' "$brief"
}

has_cmd_self_verify() {
  local brief="$1"
  awk '
    /^[a-z_]+:[[:space:]]*/ {
      if ($0 ~ /^self_verify:/) {
        in_self_verify = 1
        next
      }
      if (in_self_verify) {
        in_self_verify = 0
      }
    }
    in_self_verify && /^[[:space:]]*-[[:space:]]*cmd:/ {
      found = 1
    }
    END {
      exit found ? 0 : 1
    }
  ' "$brief"
}

has_vague_acceptance() {
  local brief="$1"
  awk '
    /^[a-z_]+:[[:space:]]*/ {
      if ($0 ~ /^acceptance:/) {
        in_acceptance = 1
        next
      }
      if (in_acceptance) {
        in_acceptance = 0
      }
    }
    in_acceptance && /^[[:space:]]*-[[:space:]]+/ {
      lowered = tolower($0)
      if (lowered ~ /works as expected|passes tests|no errors|everything works|looks good/) {
        found = 1
      }
    }
    END {
      exit found ? 0 : 1
    }
  ' "$brief"
}

has_behavioral_units_field() {
  local brief="$1"
  grep -Eq '^behavioral_units:[[:space:]]*[0-9]' "$brief"
}

behavioral_units_value() {
  local brief="$1"
  awk '
    /^behavioral_units:[[:space:]]*/ {
      sub(/^behavioral_units:[[:space:]]*/, "", $0)
      gsub(/[[:space:]]/, "", $0)
      print
      exit
    }
  ' "$brief"
}

has_qa_checklist() {
  local brief="$1"
  grep -Eq '^qa_checklist:' "$brief"
}

if [[ "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ "$#" -ne 1 ]]; then
  usage >&2
  exit 2
fi

brief="$1"

if [[ ! -f "$brief" ]]; then
  reject "brief file not found: $brief"
fi

has_required_field "$brief" "schema_version" || reject "missing field 'schema_version'"
schema_ver="$(schema_version_value "$brief")"
if [[ "$schema_ver" != "1" ]]; then
  reject "invalid field 'schema_version': expected 1"
fi

has_required_field "$brief" "working_dir" || reject "missing field 'working_dir'"
has_required_field "$brief" "goal" || reject "missing field 'goal'"
has_files_section "$brief" || reject "missing field 'files'"
has_files_entries "$brief" || reject "missing field 'files'"
grep -Eq '^acceptance:' "$brief" || reject "missing field 'acceptance'"
has_acceptance_entries "$brief" || reject "missing field 'acceptance'"

if has_file_writing_entry "$brief" && ! has_self_verify_entry "$brief"; then
  reject "missing field 'self_verify'"
fi

workdir="$(working_dir_value "$brief")"
if [[ -n "$workdir" && "$workdir" != /* ]]; then
  reject "working_dir must be an absolute path"
fi

if [[ -n "$workdir" && ! -d "$workdir" ]]; then
  reject "working_dir not found on disk: $workdir"
fi

arch_impact="$(architecture_impact_value "$brief")"
if [[ -n "$arch_impact" ]]; then
  case "$arch_impact" in
    none|minor|major) ;;
    *) reject "invalid field 'architecture_impact': expected none|minor|major, got '${arch_impact}'";;
  esac
fi

if [[ "$arch_impact" == "major" ]] && ! has_conceptual_map "$brief"; then
  reject "architecture_impact:major requires 'conceptual_map' field"
fi

if [[ "$arch_impact" == "minor" ]] && ! has_conceptual_map "$brief"; then
  warn "architecture_impact:minor without 'conceptual_map' — architecture-reviewer will fall back to diff inspection (slower, noisier)"
fi

if has_file_writing_entry "$brief" && has_self_verify_entry "$brief" && ! has_cmd_self_verify "$brief"; then
  reject "file-writing brief self_verify has no 'cmd:' entry — at least one machine-executable check is required"
fi

if has_vague_acceptance "$brief"; then
  warn "acceptance contains vague phrase (e.g. 'works as expected', 'passes tests') — replace with specific, testable conditions"
fi

if has_behavioral_units_field "$brief"; then
  bu="$(behavioral_units_value "$brief")"
  if [[ "$bu" =~ ^[0-9]+$ ]] && [[ "$bu" -ge 3 ]] && ! has_qa_checklist "$brief"; then
    warn "behavioral_units:${bu} >= 3 but no 'qa_checklist' field — qa-tester will block without per-unit coverage"
  fi
fi

retrieval_mode="${BRIEF_VALIDATE_RETRIEVAL:-warn}"
case "$retrieval_mode" in
  warn|fail) ;;
  *) reject "invalid BRIEF_VALIDATE_RETRIEVAL: expected warn|fail, got '${retrieval_mode}'";;
esac

if has_file_writing_entry "$brief" \
  && ! has_context_evidence "$brief" \
  && ! has_retrieval_skip_reason "$brief"; then
  retrieval_message="file-writing brief lacks retrieval evidence: add a non-empty 'context:' block (or dispatch with --auto-pack so an 'auto_context:' block is appended), or a non-empty 'retrieval_skip_reason:'"
  if [[ "$retrieval_mode" == "fail" ]]; then
    reject "$retrieval_message"
  fi
  warn "$retrieval_message"
fi

printf 'VALID\n'
