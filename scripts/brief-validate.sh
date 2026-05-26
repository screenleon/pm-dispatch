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
if [[ -n "$workdir" && ! -d "$workdir" ]]; then
  reject "working_dir not found on disk: $workdir"
fi

printf 'VALID\n'
