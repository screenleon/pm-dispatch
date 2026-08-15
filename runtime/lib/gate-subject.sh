#!/usr/bin/env bash
# Source-safe Gate subject coordinate helpers.

if ! declare -F gate_digest_stream >/dev/null 2>&1; then
  _gate_subject_dir="${BASH_SOURCE[0]%/*}"
  [[ "$_gate_subject_dir" == "${BASH_SOURCE[0]}" ]] && _gate_subject_dir=.
  # shellcheck source=runtime/lib/gate-digest.sh
  # shellcheck disable=SC1091
  . "$_gate_subject_dir/gate-digest.sh"
  unset _gate_subject_dir
fi

# Read the trusted architecture impact from a validated dispatch brief. The
# brief path itself remains owned by the entrypoint's workspace-boundary checks;
# this module owns only the subject field and its closed enum.
gate_subject_architecture_impact() {
  local brief="${1:-}" values value count
  [[ -n "$brief" && -r "$brief" ]] || return 2
  values="$(awk '
    /^[[:space:]]*architecture_impact[[:space:]]*:/ {
      sub(/^[^:]*:[[:space:]]*/, "")
      gsub(/[[:space:]]+$/, "")
      print
    }
  ' "$brief")" || return 2
  count="$(printf '%s\n' "$values" | grep -c '[^[:space:]]' || true)"
  if (( count > 1 )); then
    printf 'Error: --brief has duplicate architecture_impact declarations\n' >&2
    return 2
  fi
  value="$(printf '%s\n' "$values" | sed -n '1p')"
  : "${value:=unknown}"
  case "$value" in
    none|minor|major|unknown) printf '%s\n' "$value" ;;
    *)
      printf 'Error: --brief has invalid architecture_impact: %s\n' \
        "$value" >&2
      return 2
      ;;
  esac
}

# _gate_subject_tree_fingerprint <repo> <subject-kind> <head-commit>
# Builds the same immutable subject manifest used by Gate assurance. Keep this
# in the small source-safe subject module so ship can reuse it without loading
# the larger result verifier or overriding isolated test seams.
_gate_subject_tree_fingerprint() {
  local repo_root="$1" subject_kind="$2" head_commit="$3"
  local manifest path quoted kind executable digest
  local entry metadata mode object target
  manifest="$(mktemp "${TMPDIR:-/tmp}/gate-subject-tree.XXXXXX")" || return 2
  case "$subject_kind" in
    fixed_ref)
      while IFS= read -r -d '' entry; do
        metadata="${entry%%$'\t'*}"
        path="${entry#*$'\t'}"
        mode="${metadata%% *}"
        object="${metadata##* }"
        quoted="$(printf '%q' "$path")"
        case "$mode" in
          120000)
            kind=symlink
            executable=false
            target="$(git -C "$repo_root" cat-file blob "$object" 2>/dev/null)" || {
              rm -f -- "$manifest"
              return 2
            }
            digest="$(printf '%s' "$target" | gate_digest_stream)" || {
              rm -f -- "$manifest"
              return 2
            }
            ;;
          100644|100755)
            kind="file"
            [[ "$mode" == 100755 ]] && executable=true || executable=false
            digest="$(git -C "$repo_root" cat-file blob "$object" 2>/dev/null \
              | gate_digest_stream)" || {
              rm -f -- "$manifest"
              return 2
            }
            ;;
          *)
            kind=missing
            executable=false
            digest=-
            ;;
        esac
        printf '%s\t%s\t%s\t%s\n' "$quoted" "$kind" "$executable" "$digest" \
          >> "$manifest"
      done < <(git -C "$repo_root" ls-tree -r -z --full-tree "$head_commit" 2>/dev/null)
      ;;
    committed_head|working_tree)
      while IFS= read -r -d '' path; do
        case "$path" in
          .agent-trace|.agent-trace/*|.gate-briefs|.gate-briefs/*|.gate-results|.gate-results/*|.pm-dispatch-ship-finish.json)
            continue
            ;;
        esac
        quoted="$(printf '%q' "$path")"
        if [[ -L "$repo_root/$path" ]]; then
          kind=symlink
          executable=false
          digest="$(printf '%s' "$(readlink "$repo_root/$path")" \
            | gate_digest_stream)" || {
            rm -f -- "$manifest"
            return 2
          }
        elif [[ -f "$repo_root/$path" ]]; then
          kind="file"
          [[ -x "$repo_root/$path" ]] && executable=true || executable=false
          digest="$(gate_digest_file "$repo_root/$path")" || {
            rm -f -- "$manifest"
            return 2
          }
        else
          kind=missing
          executable=false
          digest=-
        fi
        printf '%s\t%s\t%s\t%s\n' "$quoted" "$kind" "$executable" "$digest" \
          >> "$manifest"
      done < <(git -C "$repo_root" ls-files --cached --others --exclude-standard -z)
      ;;
    *)
      printf 'Error: unsupported gate subject kind: %s\n' "$subject_kind" >&2
      rm -f -- "$manifest"
      return 2
      ;;
  esac
  LC_ALL=C sort "$manifest" | gate_digest_stream
  local rc=$?
  rm -f -- "$manifest"
  return "$rc"
}
