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

# _gate_subject_git_listing <out-file> <repo> <git-args...>
# Runs git in <repo> and writes its (NUL-separated) output to <out-file>; non-zero when git
# fails, so a failure cannot be mistaken for an empty listing.
_gate_subject_git_listing() {
  local out="$1" repo_root="$2"
  shift 2
  git -C "$repo_root" "$@" > "$out" 2>/dev/null
}

# _gate_subject_working_tree_line <repo> <path> <executable|""> <manifest>
# Appends one working-tree manifest line. An empty executable argument means "ask the
# filesystem" (`-x`); `true` / `false` is the mode git records for a tracked file.
_gate_subject_working_tree_line() {
  local repo_root="$1" path="$2" executable_hint="$3" manifest="$4"
  local quoted kind executable digest
  case "$path" in
    .agent-trace|.agent-trace/*|.gate-briefs|.gate-briefs/*|.gate-results|.gate-results/*|.pm-dispatch-ship-finish.json)
      return 0
      ;;
  esac
  quoted="$(printf '%q' "$path")"
  if [[ -L "$repo_root/$path" ]]; then
    kind=symlink
    executable=false
    digest="$(printf '%s' "$(readlink "$repo_root/$path")" | gate_digest_stream)" || return 2
  elif [[ -f "$repo_root/$path" ]]; then
    kind="file"
    if [[ -n "$executable_hint" ]]; then
      executable="$executable_hint"
    else
      [[ -x "$repo_root/$path" ]] && executable=true || executable=false
    fi
    digest="$(gate_digest_file "$repo_root/$path")" || return 2
  else
    kind=missing
    executable=false
    digest=-
  fi
  printf '%s\t%s\t%s\t%s\n' "$quoted" "$kind" "$executable" "$digest" >> "$manifest"
}

# _gate_subject_tree_fingerprint <repo> <subject-kind> <head-commit>
# Builds the same immutable subject manifest used by Gate assurance. Keep this
# in the small source-safe subject module so ship can reuse it without loading
# the larger result verifier or overriding isolated test seams.
_gate_subject_tree_fingerprint() {
  local repo_root="$1" subject_kind="$2" head_commit="$3"
  local manifest manifest_dir path quoted kind executable digest
  local entry metadata mode object target
  manifest_dir="$(mktemp -d "${TMPDIR:-/tmp}/gate-subject-tree.XXXXXX")" || return 2
  manifest="$manifest_dir/manifest"
  case "$subject_kind" in
    fixed_ref)
      # A failed git must fail the fingerprint: read through a file, not a process
      # substitution (which would swallow the status and leave an empty manifest whose
      # digest is a constant that binds nothing).
      _gate_subject_git_listing "$manifest_dir/list" "$repo_root" \
        ls-tree -r -z --full-tree "$head_commit" \
        || { rm -rf -- "$manifest_dir"; return 2; }
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
              rm -rf -- "$manifest_dir"
              return 2
            }
            digest="$(printf '%s' "$target" | gate_digest_stream)" || {
              rm -rf -- "$manifest_dir"
              return 2
            }
            ;;
          100644|100755)
            kind="file"
            [[ "$mode" == 100755 ]] && executable=true || executable=false
            digest="$(git -C "$repo_root" cat-file blob "$object" 2>/dev/null \
              | gate_digest_stream)" || {
              rm -rf -- "$manifest_dir"
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
      done < "$manifest_dir/list"
      ;;
    committed_head|working_tree)
      # The execute bit of a TRACKED file is read from the filesystem only where git
      # itself trusts it (core.filemode=true, the default on Linux and macOS: a chmod
      # after the gate must change the subject). Where git has switched filemode off
      # (native Windows, where MSYS reports every file with a shebang as executable)
      # the filesystem bit is noise, and the mode git records in the index -- the one
      # a commit would carry, and the one `fixed_ref` hashes -- is used instead, and an
      # untracked file counts as non-executable (what a plain `git add` records). With
      # filemode on, an untracked file uses the filesystem bit like any other.
      local trust_fs_mode=true
      [[ "$(git -C "$repo_root" config --bool core.filemode 2>/dev/null)" == false ]] \
        && trust_fs_mode=false
      if [[ "$trust_fs_mode" == true ]]; then
        _gate_subject_git_listing "$manifest_dir/list" "$repo_root" \
          ls-files --cached --others --exclude-standard -z \
          || { rm -rf -- "$manifest_dir"; return 2; }
        while IFS= read -r -d '' path; do
          _gate_subject_working_tree_line "$repo_root" "$path" "" "$manifest" \
            || { rm -rf -- "$manifest_dir"; return 2; }
        done < "$manifest_dir/list"
      else
        _gate_subject_git_listing "$manifest_dir/list" "$repo_root" ls-files --stage -z \
          || { rm -rf -- "$manifest_dir"; return 2; }
        _gate_subject_git_listing "$manifest_dir/others" "$repo_root" \
          ls-files --others --exclude-standard -z \
          || { rm -rf -- "$manifest_dir"; return 2; }
        while IFS= read -r -d '' entry; do
          metadata="${entry%%$'\t'*}"
          path="${entry#*$'\t'}"
          mode="${metadata%% *}"
          [[ "$mode" == 100755 ]] && executable=true || executable=false
          _gate_subject_working_tree_line "$repo_root" "$path" "$executable" "$manifest" \
            || { rm -rf -- "$manifest_dir"; return 2; }
        done < "$manifest_dir/list"
        # An untracked file has no recorded mode yet, and a plain `git add` records a
        # regular file with filemode off, so it is non-executable here too: the MSYS
        # shebang noise must not make the fingerprint change across `git add`.
        while IFS= read -r -d '' path; do
          _gate_subject_working_tree_line "$repo_root" "$path" false "$manifest" \
            || { rm -rf -- "$manifest_dir"; return 2; }
        done < "$manifest_dir/others"
      fi
      ;;
    *)
      printf 'Error: unsupported gate subject kind: %s\n' "$subject_kind" >&2
      rm -rf -- "$manifest_dir"
      return 2
      ;;
  esac
  LC_ALL=C sort "$manifest" | gate_digest_stream
  local rc=$?
  rm -rf -- "$manifest_dir"
  return "$rc"
}
