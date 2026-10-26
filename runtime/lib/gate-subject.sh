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

# The gate's own artifact directories are kept out of the fingerprint
# (runtime/lib/artifact-paths.sh owns the list).
if ! declare -F artifact_path_is_artifact >/dev/null 2>&1; then
  _gate_subject_artifacts_dir="${BASH_SOURCE[0]%/*}"
  [[ "$_gate_subject_artifacts_dir" == "${BASH_SOURCE[0]}" ]] && _gate_subject_artifacts_dir=.
  # shellcheck source=runtime/lib/artifact-paths.sh
  # shellcheck disable=SC1091  # dependency path is resolved beside this module
  . "$_gate_subject_artifacts_dir/artifact-paths.sh"
  unset _gate_subject_artifacts_dir
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
# fails, so a failure cannot be mistaken for an empty listing. On failure one line with git's
# own first message (a dubious-ownership or safe.directory error, a damaged index) goes to
# stderr, so the operator can tell why the fingerprint failed.
_gate_subject_git_listing() {
  local out="$1" repo_root="$2" err first
  shift 2
  err="$out.err"
  if git -C "$repo_root" "$@" > "$out" 2> "$err"; then
    # truncated, not removed: `rm` is a process per call and fixed_ref makes one call per tracked
    # file (~40 ms each on native Windows); the caller removes the whole private directory
    : > "$err" || :
    return 0
  fi
  first="$(head -n 1 "$err" 2>/dev/null | cut -c1-300 | tr -d '\000-\010\013-\037\177')"
  printf 'gate subject fingerprint: git %s failed in %s%s\n' "$*" "$repo_root" "${first:+: $first}" >&2
  return 1
}

# Digests of the regular files of a working tree, taken in ONE sha256sum call (CC-685, issue #736).
# On native Windows every process costs tens of milliseconds, and one gate_digest_file per tracked
# file was about 85% of a fingerprint (about two minutes for 564 files, several times per gate); one
# call takes about a second. The digests are the same bytes either way, so the fingerprint does not
# change. This is only a cache of what gate_digest_file would return: a file that is not in it (an odd
# name, a failed batch, a sha256sum without -z) is hashed one at a time exactly as before, and a failure
# is still reported by that path. PM_GATE_SUBJECT_BATCH_DIGESTS=0 turns it off; it is an escape hatch
# and the oracle the tests compare against, not a tuning knob.
#
# git hash-object would be one call too, but it is SHA-1: it cannot stand in for the SHA-256 digests
# the manifest records without changing every stored fingerprint.
#
# Counters, for tests and for noticing a silent slow path (a changed sha256sum output format once made
# every lookup miss with no visible error): _GATE_SUBJECT_BATCH_HITS / _GATE_SUBJECT_BATCH_MISSES.
declare -gA _GATE_SUBJECT_FILE_DIGESTS=()
_GATE_SUBJECT_BATCH_HITS=0
_GATE_SUBJECT_BATCH_MISSES=0

# _gate_subject_prefetch_fill <repo> <scratch dir>: the work of the prefetch; every early return leaves
# the cache as it is and the caller removes the scratch directory.
_gate_subject_prefetch_fill() {
  local repo_root="$1" dir="$2" path line rest hash nl=$'\n' bs=$'\\'
  _gate_subject_git_listing "$dir/list" "$repo_root" ls-files --cached --others --exclude-standard -z \
    2>/dev/null || return 0
  while IFS= read -r -d '' path; do
    if artifact_path_is_artifact "$path" || [[ "$path" == .pm-dispatch-ship-finish.json ]]; then continue; fi
    # names the output or an associative-array key could not carry faithfully stay on the per-file path
    case "$path" in *"$nl"*|*"$bs"*|*'['*|*']'*|'@'|'*') continue ;; esac
    [[ ! -L "$repo_root/$path" && -f "$repo_root/$path" ]] || continue
    printf '%s\0' "$path"
  done < "$dir/list" > "$dir/in"
  [[ -s "$dir/in" ]] || return 0
  # xargs runs under a minimal environment (`env -i PATH`): it sizes each call as the argument limit
  # minus the environment, and gives up ("environment is too large for exec") when that leaves no
  # room. A detached gate's environment is that large (found when the batch silently did not engage
  # in a real gate while a standalone run took 6 s instead of 80); sha256sum needs nothing from it.
  # `--` so a file named like an option is a name. The output line is "<hash> <space or *><name>" (the
  # star is how a Windows sha256sum marks binary mode) ended by NUL. The exit status is ignored on
  # purpose: one unreadable file fails the run, yet the lines of the others are complete and valid, and
  # the unreadable one is hashed (and reported) by the per-file path. A sha256sum without -z fails
  # outright and leaves nothing to read, which is the same fallback.
  (cd "$repo_root" && env -i PATH="$PATH" xargs -0 sha256sum -z -- < "$dir/in") > "$dir/sums" 2>/dev/null || :
  while IFS= read -r -d '' line; do
    hash="${line%% *}"
    rest="${line#* }"
    [[ "$hash" =~ ^[0-9a-f]{64}$ ]] && _GATE_SUBJECT_FILE_DIGESTS["${rest:1}"]="$hash"
  done < "$dir/sums"
  return 0
}

# _gate_subject_prefetch_digests <repo>: fill _GATE_SUBJECT_FILE_DIGESTS for the repository's regular
# files, or leave it empty. Never fails: whatever it cannot do, the per-file path does later.
_gate_subject_prefetch_digests() {
  local dir
  _GATE_SUBJECT_FILE_DIGESTS=()
  _GATE_SUBJECT_BATCH_HITS=0
  _GATE_SUBJECT_BATCH_MISSES=0
  [[ "${PM_GATE_SUBJECT_BATCH_DIGESTS:-1}" != 0 ]] || return 0
  command -v xargs >/dev/null 2>&1 && command -v sha256sum >/dev/null 2>&1 || return 0
  dir="$(mktemp -d "${TMPDIR:-/tmp}/gate-subject-batch.XXXXXX")" || return 0
  _gate_subject_prefetch_fill "$1" "$dir"
  rm -rf -- "$dir"
  return 0
}

# _gate_subject_working_tree_line <repo> <path> <executable|""> <manifest>
# Appends one working-tree manifest line. An empty executable argument means "ask the
# filesystem" (`-x`); `true` / `false` is the mode git records for a tracked file.
_gate_subject_working_tree_line() {
  local repo_root="$1" path="$2" executable_hint="$3" manifest="$4"
  local quoted kind executable digest
  # The gate's own output (artifact-paths.sh owns the list) and the ship-finish
  # marker are not part of the reviewed tree.
  if artifact_path_is_artifact "$path" || [[ "$path" == .pm-dispatch-ship-finish.json ]]; then
    return 0
  fi
  printf -v quoted '%q' "$path"
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
    digest="${_GATE_SUBJECT_FILE_DIGESTS[$path]:-}"
    if [[ -n "$digest" ]]; then
      _GATE_SUBJECT_BATCH_HITS=$((_GATE_SUBJECT_BATCH_HITS + 1))
    else
      _GATE_SUBJECT_BATCH_MISSES=$((_GATE_SUBJECT_BATCH_MISSES + 1))
      digest="$(gate_digest_file "$repo_root/$path")" || return 2
    fi
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
# Contract: on success the SHA-256 hex digest is the only thing on stdout and the status is 0
# (an empty listing is valid and has the digest of an empty manifest); on ANY git, file or
# digest failure nothing is printed on stdout and the status is 2. Callers must propagate it.
# (The public entry point below fills the digest cache around this, then empties it.)
_gate_subject_tree_fingerprint_manifest() {
  local repo_root="$1" subject_kind="$2" head_commit="$3"
  local manifest manifest_dir path quoted kind executable digest
  local entry metadata mode object target
  manifest_dir="$(mktemp -d "${TMPDIR:-/tmp}/gate-subject-tree.XXXXXX")" || return 2
  manifest="$manifest_dir/manifest"
  # create it now: a legitimately empty listing never appends a line
  : > "$manifest" || { rm -rf -- "$manifest_dir"; return 2; }
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
            # through a file, not `cat-file | digest`: a pipeline without pipefail hides a failing
            # cat-file behind the digest of whatever it printed before dying
            _gate_subject_git_listing "$manifest_dir/blob" "$repo_root" cat-file blob "$object" || {
              rm -rf -- "$manifest_dir"
              return 2
            }
            digest="$(gate_digest_file "$manifest_dir/blob")" || {
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
          >> "$manifest" || { rm -rf -- "$manifest_dir"; return 2; }
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
  # No pipeline here: this library cannot rely on the caller's pipefail, and a digest tool
  # that fails prints nothing (gate_digest_stream), which must not pass for a fingerprint.
  LC_ALL=C sort -o "$manifest_dir/sorted" "$manifest" \
    || { rm -rf -- "$manifest_dir"; return 2; }
  # belt and braces: gate_digest_stream already guarantees a digest or a failure (CC-629 c); the
  # check stays for an older gate-digest.sh and because a fingerprint must never be empty
  digest="$(gate_digest_stream < "$manifest_dir/sorted")" || { rm -rf -- "$manifest_dir"; return 2; }
  rm -rf -- "$manifest_dir"
  [[ "$digest" =~ ^[0-9a-f]{64}$ ]] || return 2
  printf '%s\n' "$digest"
}

# _gate_subject_tree_fingerprint <repo> <subject-kind> <head-commit>
# The entry point: the contract above, with the digests of a working tree taken in one call first. The
# cache lives only for the call (a later fingerprint must see a changed file), and what it holds never
# changes a result: see _gate_subject_prefetch_digests.
_gate_subject_tree_fingerprint() {
  local rc=0
  case "${2:-}" in
    committed_head|working_tree) _gate_subject_prefetch_digests "$1" ;;
  esac
  _gate_subject_tree_fingerprint_manifest "$@" || rc=$?
  _GATE_SUBJECT_FILE_DIGESTS=()
  # Say which path the digests took where a gate records its phases (runtime/lib/gate-phase.sh): a batch
  # that silently fell back to one process per file is otherwise visible only as a slow gate.
  case "${2:-}" in
    committed_head|working_tree)
      if [[ "$(type -t gate_phase_emit 2>/dev/null)" == function ]]; then
        gate_phase_emit fingerprint info "digests batched=$_GATE_SUBJECT_BATCH_HITS per-file=$_GATE_SUBJECT_BATCH_MISSES kind=$2"
      fi ;;
  esac
  return "$rc"
}
