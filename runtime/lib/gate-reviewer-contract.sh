#!/usr/bin/env bash
# Source-safe reviewer artifact contract helpers.

if ! declare -F gate_digest_file >/dev/null 2>&1; then
  _gate_reviewer_contract_dir="${BASH_SOURCE[0]%/*}"
  [[ "$_gate_reviewer_contract_dir" == "${BASH_SOURCE[0]}" ]] && _gate_reviewer_contract_dir=.
  # shellcheck source=runtime/lib/gate-digest.sh
  # shellcheck disable=SC1091
  . "$_gate_reviewer_contract_dir/gate-digest.sh"
  unset _gate_reviewer_contract_dir
fi

# verify_reviewer_artifact_hashes <hash_cmd> <name> <path> <baseline> [...]
# Print every reviewer whose artifact differs from its captured baseline.
verify_reviewer_artifact_hashes() {
  local hash_cmd="$1" name path baseline current
  shift
  while [[ $# -ge 3 ]]; do
    name="$1" path="$2" baseline="$3"; shift 3
    [[ "$baseline" == "none" ]] && continue
    current="$(cat "$path" 2>/dev/null | $hash_cmd || echo 'missing')"
    [[ "$current" != "$baseline" ]] && printf '%s\n' "$name"
  done
}

_gate_reviewer_protocol_append_blocks() {
  local destination="$1" artifact reviewer verdict
  shift
  if grep -q '^```reviewer_result_v1$' "$destination"; then
    printf 'Error: reviewer protocol INCOMPLETE: synthesis emitted machine-owned reviewer blocks\n' >&2
    return 1
  fi
  {
    printf '\n## Reviewer Protocol Evidence\n'
    printf 'Validated selected-reviewer reports are preserved verbatim below.\n\n'
    for artifact in "$@"; do
      reviewer="$(
        _gate_reviewer_protocol_documents "$artifact" |
          jq -sr '.[0].reviewer // empty'
      )" || return 1
      verdict="$(
        _gate_reviewer_protocol_verdict_extract "$artifact" "$reviewer"
      )" || return 1
      printf '## %s -- %s\n' "$reviewer" "$verdict"
      # shellcheck disable=SC2016 # Literal Markdown fence delimiters.
      sed -n '/^```reviewer_result_v1$/,/^```$/p' "$artifact"
      printf '\n'
    done
  } >> "$destination"
}

# Load a free-form reviewer override into memory only after its final path
# component and the bytes copied to a private snapshot agree.  Bash has no
# O_NOFOLLOW open primitive, so this is deliberately a bounded Linux/WSL2
# check/use protocol rather than a claim of protection from a same-uid writer.
# It protects the reviewer channel from ordinary symlink redirects and from a
# replacement observed while this loader is running; dispatches consume only
# GATE_OVERRIDES_CONTENT, never the source path again.
#
# Snapshot cleanup stays on the composition root's EXIT trap so a mid-load
# abort still unlinks the private copy. This loader calls that helper by name.
# shellcheck disable=SC2034 # caller-facing globals consumed by pr-gate.sh
gate_load_reviewer_override() {
  local caller_input="$1" candidate="$2" parent source snapshot
  local identity_before identity_after identity_final snapshot_sha source_sha
  local mode permissions snapshot_size nul_stripped_size

  _gate_reviewer_override_error() {
    printf 'Error: reviewer override must name a readable, non-empty, NUL-free regular non-symlink file: %s (%s)\n' \
      "$caller_input" "$1" >&2
  }

  if [[ -L "$candidate" ]]; then
    _gate_reviewer_override_error 'final path component is a symlink'
    return 2
  fi
  if [[ ! -e "$candidate" ]]; then
    _gate_reviewer_override_error 'file does not exist'
    return 2
  fi
  if [[ ! -f "$candidate" ]]; then
    _gate_reviewer_override_error 'not a regular file'
    return 2
  fi
  if [[ ! -r "$candidate" ]]; then
    _gate_reviewer_override_error 'file is not readable'
    return 2
  fi
  if [[ ! -s "$candidate" ]]; then
    _gate_reviewer_override_error 'file is empty'
    return 2
  fi
  if ! command -v stat >/dev/null 2>&1; then
    _gate_reviewer_override_error 'required file identity primitive (stat) is unavailable'
    return 2
  fi
  # `-c` is the supported GNU stat interface on Linux and WSL2.  Checking a
  # readable permission bit avoids root making a chmod 000 fixture look usable.
  mode="$(stat -Lc '%a' -- "$candidate" 2>/dev/null)" || {
    _gate_reviewer_override_error 'cannot inspect file identity'
    return 2
  }
  if [[ ! "$mode" =~ ^[0-7]{1,4}$ ]]; then
    _gate_reviewer_override_error 'cannot interpret file permission bits'
    return 2
  fi
  permissions="00$mode"
  permissions="${permissions: -3}"
  if [[ "$permissions" != *[4567]* ]]; then
    _gate_reviewer_override_error 'file is not readable'
    return 2
  fi
  parent="$(cd "$(dirname "$candidate")" && pwd -P)" || {
    _gate_reviewer_override_error 'parent directory cannot be resolved'
    return 2
  }
  source="$parent/$(basename "$candidate")"
  identity_before="$(stat -Lc '%d:%i:%s:%Y:%Z:%f' -- "$source" 2>/dev/null)" || {
    _gate_reviewer_override_error 'cannot capture file identity'
    return 2
  }
  snapshot="$(mktemp "${TMPDIR:-/tmp}/pr-gate-reviewer-override.XXXXXX")" || {
    _gate_reviewer_override_error 'cannot create private content snapshot'
    return 2
  }
  GATE_REVIEWER_OVERRIDE_SNAPSHOT="$snapshot"
  if ! cat -- "$source" > "$snapshot"; then
    gate_cleanup_reviewer_override_snapshot
    _gate_reviewer_override_error 'file could not be read into a private snapshot'
    return 2
  fi
  if [[ -L "$candidate" || ! -f "$candidate" || ! -r "$candidate" || ! -s "$candidate" ]]; then
    gate_cleanup_reviewer_override_snapshot
    _gate_reviewer_override_error 'file changed or was redirected while being read'
    return 2
  fi
  identity_after="$(stat -Lc '%d:%i:%s:%Y:%Z:%f' -- "$source" 2>/dev/null)" || {
    gate_cleanup_reviewer_override_snapshot
    _gate_reviewer_override_error 'file identity disappeared while being read'
    return 2
  }
  if [[ "$identity_before" != "$identity_after" ]]; then
    gate_cleanup_reviewer_override_snapshot
    _gate_reviewer_override_error 'file identity changed while being read'
    return 2
  fi
  snapshot_size="$(stat -Lc '%s' -- "$snapshot" 2>/dev/null)" || {
    gate_cleanup_reviewer_override_snapshot
    _gate_reviewer_override_error 'cannot inspect private content snapshot'
    return 2
  }
  nul_stripped_size="$(LC_ALL=C tr -d '\000' < "$snapshot" | wc -c)" || {
    gate_cleanup_reviewer_override_snapshot
    _gate_reviewer_override_error 'cannot validate override text bytes'
    return 2
  }
  nul_stripped_size="${nul_stripped_size//[[:space:]]/}"
  if [[ "$snapshot_size" != "$nul_stripped_size" ]]; then
    gate_cleanup_reviewer_override_snapshot
    _gate_reviewer_override_error 'file contains a NUL byte'
    return 2
  fi
  snapshot_sha="$(gate_digest_file "$snapshot")" || {
    gate_cleanup_reviewer_override_snapshot
    return 2
  }
  source_sha="$(gate_digest_file "$source")" || {
    gate_cleanup_reviewer_override_snapshot
    _gate_reviewer_override_error 'file could not be rechecked after snapshot'
    return 2
  }
  if [[ "$snapshot_sha" != "$source_sha" ]]; then
    gate_cleanup_reviewer_override_snapshot
    _gate_reviewer_override_error 'file content changed while being read'
    return 2
  fi
  if [[ -L "$candidate" || -L "$source" ]]; then
    gate_cleanup_reviewer_override_snapshot
    _gate_reviewer_override_error 'file was redirected after its content was checked'
    return 2
  fi
  identity_final="$(stat -Lc '%d:%i:%s:%Y:%Z:%f' -- "$source" 2>/dev/null)" || {
    gate_cleanup_reviewer_override_snapshot
    _gate_reviewer_override_error 'file identity disappeared after content validation'
    return 2
  }
  if [[ "$identity_before" != "$identity_final" ]]; then
    gate_cleanup_reviewer_override_snapshot
    _gate_reviewer_override_error 'file identity changed after content validation'
    return 2
  fi

  OVERRIDE_FILE="$source"
  # Keep the legacy content-normalization contract: Bash command substitution
  # strips trailing newlines.  The source is never reread; both normalized
  # prompt content and the full-byte provenance digest come from this snapshot.
  if ! GATE_OVERRIDES_CONTENT="$(cat -- "$snapshot")"; then
    gate_cleanup_reviewer_override_snapshot
    _gate_reviewer_override_error 'private content snapshot could not be loaded'
    return 2
  fi
  if ! REVIEWER_OVERRIDE_PROVENANCE_JSON="$(jq -nc \
    --arg source "$source" --arg sha256 "$snapshot_sha" \
    '{status:"provided",source:$source,sha256:$sha256}')"; then
    gate_cleanup_reviewer_override_snapshot
    printf 'Error: cannot record accepted reviewer override provenance\n' >&2
    return 2
  fi
  gate_cleanup_reviewer_override_snapshot
}
