#!/usr/bin/env bash
# Cross-platform path and locking helpers for PM Dispatch shell scripts.

set -euo pipefail

# Public helper return-code contract:
#   link_or_copy:
#     0 = symlink installed / already correctly installed
#     1 = symlink failed, copy fallback succeeded
#     2 = conflict
#     3 = error
#   manifest_record:
#     0 = record appended
#     3 = invalid input / serialization failure
#   manifest_flush:
#     0 = flush succeeded
#     3 = no manifest path / write failure / serialization failure
#     In dry-run, manifest_flush is a no-op that prints to stderr and clears
#     in-memory records, then returns 0.
# Detect the active platform.
detect_platform() {
  local override="${PM_DISPATCH_PLATFORM:-}"
  case "$override" in
    linux|macos|windows|unknown)
      printf '%s\n' "$override"
      return 0
      ;;
  esac

  case "${OSTYPE:-}" in
    linux-gnu*)
      printf 'linux\n'
      return 0
      ;;
    darwin*)
      printf 'macos\n'
      return 0
      ;;
    msys*|cygwin*|mingw*)
      printf 'windows\n'
      return 0
      ;;
  esac

  local uname_s
  uname_s="$(uname -s 2>/dev/null || true)"
  case "$uname_s" in
    Linux)
      printf 'linux\n'
      return 0
      ;;
    Darwin)
      printf 'macos\n'
      return 0
      ;;
    MINGW*|MSYS*|CYGWIN*)
      printf 'windows\n'
      return 0
      ;;
  esac

  printf 'unknown\n'
}

# Return 0 if the `codex` CLI is on PATH, 1 otherwise.
codex_available() {
  command -v codex >/dev/null 2>&1
}

# Echo the auto-detected executor profile: "full" when codex is available,
# "minimal" otherwise.
detect_executor_profile() {
  if codex_available; then
    printf 'full\n'
  else
    printf 'minimal\n'
  fi
}

# Resolve a path with GNU-like normalization for use as a cross-platform shim.
realpath_m() {
  local path="${1:-}"

  [[ -n "$path" ]] || return 1
  local -a rp_opts=(-m --)

  case "$(detect_platform)" in
    linux|macos)
      realpath "${rp_opts[@]}" "$path"
      return $?
      ;;
    windows)
      _portable_realpath_windows "$path"
      return $?
      ;;
    unknown)
      if command -v realpath >/dev/null 2>&1; then
        realpath "${rp_opts[@]}" "$path"
        return $?
      fi
      _portable_realpath_windows "$path"
      return $?
      ;;
  esac
}

# Resolve a path lexically — normalizes . and .. but does NOT follow symlinks.
# Safe even when the path does not exist on disk.
realpath_m_lex() {
  local path="${1:-}"
  [[ -n "$path" ]] || return 1

  # GNU realpath -m -s: allow missing components (-m) + no-symlinks (-s).
  if realpath -m -s -- "$path" 2>/dev/null; then
    return 0
  fi

  # Bash-native fallback: collapse . and .. segments without touching the
  # filesystem. Caller must pass an absolute path (g_validate_path guarantees
  # this for all guard callers); no tilde expansion is needed.
  local IFS='/' seg
  local -a parts=()
  read -ra segs <<< "$path"
  for seg in "${segs[@]}"; do
    case "$seg" in
      ''|.) ;;
      ..)   [[ ${#parts[@]} -gt 0 ]] && unset 'parts[-1]' ;;
      *)    parts+=("$seg") ;;
    esac
  done
  local out="/" i
  for ((i=0; i<${#parts[@]}; i++)); do
    [[ $i -gt 0 ]] && out+="/"
    out+="${parts[$i]}"
  done
  printf '%s\n' "$out"
}

# Return a writable temp directory.
safe_tmpdir() {
  local platform
  local tmpdir

  platform="$(detect_platform)"

  if [[ "$platform" == "windows" ]]; then
    tmpdir="${TMPDIR:-${TEMP:-/tmp}}"
  else
    tmpdir="${TMPDIR:-/tmp}"
  fi

  if [[ -z "$tmpdir" || ! -d "$tmpdir" || ! -w "$tmpdir" ]]; then
    printf 'portable: safe_tmpdir unusable: %s\n' "${tmpdir:-<empty>}" >&2
    return 1
  fi

  printf '%s\n' "$tmpdir"
}

# Acquire an atomic directory lock.
mkdir_lock() {
  local lockdir="$1"
  local timeout_sec="${2:-2}"
  local attempts
  local i
  local stale_owner owner_now stale_reclaims=0 max_reclaims=2

  [[ -n "$lockdir" ]] || return 1

  if ! [[ "$timeout_sec" =~ ^[0-9]+$ ]]; then
    timeout_sec=2
  fi

  _portable_lock_preflight_warn "$lockdir"

  attempts=$(( timeout_sec * 20 ))
  (( attempts > 0 )) || attempts=1

  for ((i = 0; i < attempts; i++)); do
    if mkdir "$lockdir" 2>/dev/null; then
      _portable_lock_write_owner "$lockdir"
      return 0
    fi
    if (( stale_reclaims < max_reclaims )) && stale_owner="$(_portable_lock_stale_owner "$lockdir")"; then
      owner_now="$(_portable_lock_read_owner "$lockdir" 2>/dev/null || true)"
      if [[ "$owner_now" == "$stale_owner" ]]; then
        rm -f -- "$lockdir/owner" 2>/dev/null || true
        if rmdir "$lockdir" 2>/dev/null; then
          stale_reclaims=$((stale_reclaims + 1))
          continue
        fi
      fi
    fi
    sleep 0.05
  done

  printf 'portable: mkdir_lock timeout after %s seconds for %s\n' "$timeout_sec" "$lockdir" >&2
  return 1
}

# mkdir_unlock <lockdir>
# Release a lock acquired with mkdir_lock. Because mkdir_lock now leaves an
# `owner` metadata file inside the lockdir, a bare `rmdir` no longer suffices —
# callers MUST release through this helper (it removes the owner file then the
# directory). Always succeeds (best-effort).
mkdir_unlock() {
  local lockdir="$1"
  [[ -n "$lockdir" ]] || return 0
  rm -f -- "$lockdir/owner" 2>/dev/null || true
  rmdir "$lockdir" 2>/dev/null || true
  return 0
}

# serialize_with_lock <lockbase> <fn_name> [args...]
# Run <fn_name> [args...] with exclusive lock. Prefers flock when available
# (kernel-level, stale-lock-safe); falls back to mkdir_lock otherwise.
# Lockfile paths managed internally:
#   flock path  : <lockbase>.lock    (regular file)
#   mkdir path  : <lockbase>.lockdir (directory, same as mkdir_lock convention)
# Test shim: set FAKE_FLOCK_MISSING=1 to force the mkdir_lock path in tests.
# Returns the wrapped function's exit code, or 1 on lock failure.
serialize_with_lock() {
  local lockbase="$1"; shift
  if command -v flock >/dev/null 2>&1 && [[ "${FAKE_FLOCK_MISSING:-}" != "1" ]]; then
    local _slw_rc=0
    (
      flock -x -w 2 9 || exit 1
      "$@"
    ) 9>"${lockbase}.lock"
    _slw_rc=$?
    return $_slw_rc
  else
    local lockdir="${lockbase}.lockdir"
    if ! mkdir_lock "$lockdir" 2; then
      return 1
    fi
    local _slw_rc=0
    (
      trap 'mkdir_unlock "$lockdir"' EXIT
      "$@"
    ) || _slw_rc=$?
    mkdir_unlock "$lockdir"
    return $_slw_rc
  fi
}

# _portable_sha1
# Read stdin and print a 40-character lowercase hex SHA-1 digest on stdout.
# Tries sha1sum (GNU coreutils / Linux), then shasum -a 1 (macOS/BSD).
# Returns 1 and logs a warning if neither is available.
# Test shims: FAKE_SHA1_MISSING=1 forces both tools missing (tests failure path);
# FAKE_SHA1SUM_MISSING=1 skips only sha1sum so the shasum fallback can be tested.
_portable_sha1() {
  if command -v sha1sum >/dev/null 2>&1 && [[ "${FAKE_SHA1_MISSING:-}" != "1" ]] && [[ "${FAKE_SHA1SUM_MISSING:-}" != "1" ]]; then
    sha1sum | cut -c1-40
    return
  fi
  if command -v shasum >/dev/null 2>&1 && [[ "${FAKE_SHA1_MISSING:-}" != "1" ]]; then
    shasum -a 1 | cut -c1-40
    return
  fi
  printf '[portable.sh] _portable_sha1: neither sha1sum nor shasum available\n' >&2
  return 1
}

# file_size_bytes <file>
# Print file size in bytes on stdout. Portable across GNU stat (linux),
# BSD stat (macos), and wc -c fallback (any). Returns 1 (and prints
# nothing) if file does not exist or all three methods fail.
file_size_bytes() {
  local f="$1"
  [[ -n "$f" && -f "$f" ]] || return 1

  local n
  if n=$(stat -c %s -- "$f" 2>/dev/null); then
    printf '%s\n' "$n"
    return 0
  fi
  if n=$(stat -f %z -- "$f" 2>/dev/null); then
    printf '%s\n' "$n"
    return 0
  fi
  if n=$(wc -c < "$f" 2>/dev/null); then
    # wc may emit leading whitespace on some platforms; trim.
    n="${n#"${n%%[![:space:]]*}"}"
    n="${n%"${n##*[![:space:]]}"}"
    printf '%s\n' "$n"
    return 0
  fi
  return 1
}

# Helpers below are private.

_portable_lock_host() {
  local h=""
  h="$(hostname 2>/dev/null || true)"
  [[ -n "$h" ]] || h="${HOSTNAME:-unknown}"
  [[ -n "$h" ]] || h="unknown"
  printf '%s\n' "$h"
}

_portable_lock_now() {
  local n
  n="$(date +%s 2>/dev/null || true)"
  if [[ "$n" =~ ^[0-9]+$ ]]; then
    printf '%s\n' "$n"
  else
    printf '0\n'
  fi
}

_portable_lock_stale_secs() {
  local raw="${PM_DISPATCH_LOCK_STALE_SECS:-60}"
  if [[ "$raw" =~ ^[0-9]+$ ]] && (( 10#$raw > 0 )); then
    printf '%s\n' "$((10#$raw))"
  else
    printf '60\n'
  fi
}

_portable_lock_write_owner() {
  local lockdir="$1" host epoch
  host="$(_portable_lock_host)"
  epoch="$(_portable_lock_now)"
  printf '%s %s %s\n' "$$" "$host" "$epoch" > "$lockdir/owner" 2>/dev/null || true
}

_portable_lock_read_owner() {
  local lockdir="$1"
  [[ -f "$lockdir/owner" ]] || return 1
  IFS= read -r _portable_owner_line < "$lockdir/owner" || return 1
  printf '%s\n' "$_portable_owner_line"
}

_portable_lock_mtime() {
  local path="$1" n
  if n="$(stat -c %Y -- "$path" 2>/dev/null)"; then
    printf '%s\n' "$n"
    return 0
  fi
  if n="$(stat -f %m -- "$path" 2>/dev/null)"; then
    printf '%s\n' "$n"
    return 0
  fi
  return 1
}

_portable_lock_owner_line_stale() {
  local lockdir="$1" owner_line="$2"
  local pid host epoch extra our_host now stale_secs mtime
  read -r pid host epoch extra <<< "$owner_line"
  now="$(_portable_lock_now)"
  stale_secs="$(_portable_lock_stale_secs)"

  if [[ "$pid" =~ ^[0-9]+$ && -n "$host" && "$epoch" =~ ^[0-9]+$ && -z "${extra:-}" ]]; then
    our_host="$(_portable_lock_host)"
    if [[ "$host" == "$our_host" ]]; then
      # Same host: PID liveness is authoritative. A live holder is never stale,
      # regardless of how old its lock is — age alone must not steal a live lock.
      if kill -0 "$pid" 2>/dev/null; then
        return 1
      fi
      return 0
    fi
    # Different host: PID liveness is not checkable here, so fall back to the
    # age ceiling for a remote owner only.
    if (( epoch > 0 && now > epoch && now - epoch > stale_secs )); then
      return 0
    fi
    return 1
  fi

  mtime="$(_portable_lock_mtime "$lockdir" 2>/dev/null || true)"
  if [[ "$mtime" =~ ^[0-9]+$ ]] && (( now > mtime && now - mtime > stale_secs )); then
    return 0
  fi
  return 1
}

_portable_lock_stale_owner() {
  local lockdir="$1" owner_line
  [[ -d "$lockdir" ]] || return 1
  owner_line="$(_portable_lock_read_owner "$lockdir" 2>/dev/null || true)"
  if [[ -n "$owner_line" ]]; then
    if _portable_lock_owner_line_stale "$lockdir" "$owner_line"; then
      printf '%s\n' "$owner_line"
      return 0
    fi
    return 1
  fi

  if _portable_lock_owner_line_stale "$lockdir" ""; then
    printf '\n'
    return 0
  fi
  return 1
}

_portable_lock_fs_type() {
  local path="$1" probe="$1" fs_type=""
  if [[ ! -e "$probe" ]]; then
    probe="$(dirname "$probe")"
  fi
  fs_type="$(stat -f -c %T -- "$probe" 2>/dev/null || true)"
  [[ -n "$fs_type" ]] || fs_type="$(df -T "$probe" 2>/dev/null | awk 'NR==2 {print $2}' || true)"
  [[ -n "$fs_type" ]] || fs_type="$(stat -f %T "$probe" 2>/dev/null || true)"
  printf '%s\n' "$fs_type"
}

_portable_lock_preflight_warn() {
  local path="$1" fs_type warn=0
  [[ -z "${_PORTABLE_LOCK_PREFLIGHT_WARNED:-}" ]] || return 0
  case "$path" in
    //*|\\\\*) warn=1 ;;
  esac
  if [[ "$warn" -eq 0 ]]; then
    fs_type="$(_portable_lock_fs_type "$path")"
    case "$fs_type" in
      9p|nfs|nfs4|cifs|smb|smbfs) warn=1 ;;
    esac
  fi
  if [[ "$warn" -eq 1 ]]; then
    _PORTABLE_LOCK_PREFLIGHT_WARNED=1
    printf 'portable: warning: lock path may be on a network filesystem with unreliable advisory locking: %s\n' "$path" >&2
  fi
  return 0
}

# shellcheck disable=SC2155
_portable_normalize_path() {
  local path="$1"
  local root="" relative=1
  local -a parts out
  local -i i
  local part

  path="${path//\\//}"

  case "$path" in
    [A-Za-z]:/*)
      root="${path%%/*}"
      root="${root}/"
      path="${path#"$root"}"
      relative=0
      ;;
    /*)
      root="/"
      path="${path#"/"}"
      relative=0
      ;;
  esac

  IFS='/' read -r -a parts <<< "$path"
  for ((i = 0; i < ${#parts[@]}; i++)); do
    part="${parts[i]}"
    case "$part" in
      ""|.)
        continue
        ;;
      ..)
        if (( ${#out[@]} > 0 )); then
          unset 'out[-1]'
        elif (( relative == 1 )); then
          out+=("..")
        fi
        ;;
      *)
        out+=("$part")
        ;;
    esac
  done

  if (( relative == 0 )); then
    if (( ${#out[@]} == 0 )); then
      printf '%s\n' "$root"
      return 0
    fi
    local out_path="$root"
    for ((i = 0; i < ${#out[@]}; i++)); do
      if [[ "$out_path" == "/" || "$out_path" == [A-Za-z]:/ ]]; then
        out_path+="${out[i]}"
      else
        out_path+="/${out[i]}"
      fi
    done
    printf '%s\n' "$out_path"
    return 0
  fi

  if (( ${#out[@]} == 0 )); then
    printf '.\n'
    return 0
  fi

  local out_path="${out[0]}"
  for ((i = 1; i < ${#out[@]}; i++)); do
    out_path+="/${out[i]}"
  done
  printf '%s\n' "$out_path"
}

# Collapse a path to one stable spelling so the same location always produces the
# same identity (e.g. a partition hash) regardless of how the path was reached.
# On POSIX this is a no-op beyond slash/dot-segment normalization: there is no
# cygpath, and a POSIX absolute path has no drive letter to fold. On MSYS/Cygwin
# the same repo can surface as C:/foo, c:/foo, or /c/foo; cygpath -m maps them to
# one mixed form and the drive letter is lowercased so they hash identically.
_portable_canonical_path() {
  local path
  path="$(_portable_normalize_path "$1")"
  if command -v cygpath >/dev/null 2>&1; then
    path="$(cygpath -m -- "$path" 2>/dev/null || printf '%s' "$path")"
  fi
  if [[ "$path" =~ ^[A-Za-z]: ]]; then
    local drive="${path:0:1}"
    path="${drive,,}${path:1}"
  fi
  printf '%s\n' "$path"
}

_portable_resolve_symlink() {
  local path="$1"
  local target

  if ! command -v readlink >/dev/null 2>&1; then
    printf '%s\n' "$path"
    return 0
  fi

  target="$(readlink -- "$path" 2>/dev/null || true)"
  [[ -n "$target" ]] || { printf '%s\n' "$path"; return 0; }

  target="${target//\\//}"
  case "$target" in
    [A-Za-z]:/*|/*)
      printf '%s\n' "$(_portable_normalize_path "$target")"
      return 0
      ;;
  esac

  printf '%s\n' "$(_portable_normalize_path "$(dirname "$path")/$target")"
}

_portable_realpath_windows() {
  local path="${1:-}"
  local -a parts
  local -i step i j
  local root
  local body
  local seg
  local current
  local candidate
  local changed=0
  local symlink_target
  local next
  local -i max_steps=64

  path="${path//\\//}"
  if [[ "$path" != /* && ! "$path" =~ ^[A-Za-z]:/ ]]; then
    path="$PWD/$path"
  fi
  path="$(_portable_normalize_path "$path")"

  for ((step = 0; step < max_steps; step++)); do
    changed=0
    case "$path" in
      [A-Za-z]:/*)
        root="${path%%/*}/"
        body="${path#"$root"}"
        ;;
      /*)
        root="/"
        body="${path#/}"
        ;;
      *)
        printf '%s\n' "$path"
        return 1
        ;;
    esac

    IFS='/' read -r -a parts <<< "$body"
    current="$root"

    for ((i = 0; i < ${#parts[@]}; i++)); do
      seg="${parts[i]}"
      case "$seg" in
        ""|.)
          continue
          ;;
        ..)
      if [[ "$current" != "$root" ]]; then
            current="${current%/*}"
            [[ "$current" != "$root" && -z "$current" ]] && current="$root"
          fi
          continue
          ;;
        *)
          if [[ "$current" == "/" || "$current" == [A-Za-z]:/ ]]; then
            candidate="${current%/}/$seg"
          else
            candidate="$current/$seg"
          fi
          if [[ -L "$candidate" ]]; then
            symlink_target="$(_portable_resolve_symlink "$candidate")"
            if [[ -z "$symlink_target" ]]; then
              continue
            fi
            next="$symlink_target"
            if (( i + 1 < ${#parts[@]} )); then
              for ((j = i + 1; j < ${#parts[@]}; j++)); do
                next+="/${parts[j]}"
              done
            fi
            path="$(_portable_normalize_path "$next")"
            changed=1
            break
          fi
          if [[ "$current" == "/" || "$current" == [A-Za-z]:/ ]]; then
            current="${current%/}/$seg"
          else
            current="$current/$seg"
          fi
          ;;
      esac
    done

    if (( changed == 1 )); then
      continue
    fi

    [[ -n "$current" ]] || current="$root"
    printf '%s\n' "$current"
    return 0
  done

  return 1
}

_PORTABLE_MANIFEST_RECORDS=()
_PORTABLE_MANIFEST_PREV_DSTS=()
_PORTABLE_MANIFEST_PREV_MODES=()
_PORTABLE_MANIFEST_PREV_SHA256S=()
_PORTABLE_MANIFEST_PREV_INITIALIZED=0
_PORTABLE_SHA256_TOOL=""

_portable_manifest_path() {
  local home_root="${HOME:-}"
  if [[ -z "$home_root" ]]; then
    printf '' 2>/dev/null
    return 1
  fi
  printf '%s/.claude/.pm-dispatch/install-manifest.json' "$home_root"
}

_portable_json_escape() {
  local value="${1-}"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\n'/\\n}"
  value="${value//$'\r'/\\r}"
  value="${value//$'\t'/\\t}"
  value="${value//$'\b'/\\b}"
  value="${value//$'\f'/\\f}"
  printf '%s\n' "$value"
}

_portable_json_unescape() {
  local value="${1-}"
  value="${value//\\n/$'\n'}"
  value="${value//\\r/$'\r'}"
  value="${value//\\t/$'\t'}"
  value="${value//\\b/$'\b'}"
  value="${value//\\f/$'\f'}"
  value="${value//\\\\/\\}"
  value="${value//\\\"/\"}"
  printf '%s\n' "$value"
}

_portable_extract_json_field() {
  local line="${1-}"
  local field="${2-}"
  local extracted
  extracted="$(printf '%s\n' "$line" | sed -n "s/.*\"${field}\"[[:space:]]*:[[:space:]]*\"\\([^\"]*\\)\".*/\\1/p")"
  printf '%s\n' "$extracted"
}

# Test-only shims for deterministic link/copy branching when
# FAKE_SYMLINK_UNSUPPORTED=1 (force ln copy fallback) or
# FAKE_SYMLINK_BOGUS=1 (ln succeeds but leaves no symlink).

_portable_sha_tool() {
  if [[ -n "$_PORTABLE_SHA256_TOOL" ]]; then
    return 0
  fi

  if command -v sha256sum >/dev/null 2>&1; then
    _PORTABLE_SHA256_TOOL=sha256sum
    return 0
  fi
  if command -v shasum >/dev/null 2>&1; then
    _PORTABLE_SHA256_TOOL=shasum
    return 0
  fi

  printf 'portable: missing sha256 utility; install coreutils (sha256sum) or core_perl (shasum -a 256) before running install.sh\n' >&2
  return 1
}

_portable_sha256_stream() {
  if ! _portable_sha_tool; then
    return 1
  fi

  case "$_PORTABLE_SHA256_TOOL" in
    sha256sum)
      sha256sum | awk '{print $1}'
      ;;
    shasum)
      shasum -a 256 | awk '{print $1}'
      ;;
  esac
}

_portable_sha256_path() {
  local path="${1-}"
  local digest

  if ! _portable_sha_tool; then
    return 3
  fi
  if [[ -f "$path" ]]; then
    case "$_PORTABLE_SHA256_TOOL" in
      sha256sum)
        digest="$(sha256sum "$path" | awk '{print $1}')"
        ;;
      shasum)
        digest="$(shasum -a 256 "$path" | awk '{print $1}')"
        ;;
    esac
    printf '%s\n' "$digest"
    return 0
  fi
  if [[ -d "$path" ]]; then
    if command -v tar >/dev/null 2>&1; then
      digest="$(tar -cf - -C "$path" . | _portable_sha256_stream)"
      printf '%s\n' "$digest"
      return 0
    fi
  fi
  return 1
}

_portable_manifest_prev_load() {
  local path="${1-}"
  local line src dst mode sha

  if [[ "$_PORTABLE_MANIFEST_PREV_INITIALIZED" -eq 1 ]]; then
    return 0
  fi

  _PORTABLE_MANIFEST_PREV_INITIALIZED=1
  _PORTABLE_MANIFEST_PREV_DSTS=()
  _PORTABLE_MANIFEST_PREV_MODES=()
  _PORTABLE_MANIFEST_PREV_SHA256S=()

  [[ -f "$path" ]] || return 0

  while IFS= read -r line; do
    [[ "$line" == *'"src"'* ]] || continue
    [[ "$line" == *'"dst"'* ]] || continue
    src="$(_portable_extract_json_field "$line" "src")"
    dst="$(_portable_extract_json_field "$line" "dst")"
    mode="$(_portable_extract_json_field "$line" "mode")"
    sha="$(_portable_extract_json_field "$line" "sha256")"
    src="$(_portable_json_unescape "${src-}")"
    dst="$(_portable_json_unescape "${dst-}")"
    mode="$(_portable_json_unescape "${mode-}")"
    sha="$(_portable_json_unescape "${sha-}")"
    if [[ -z "$dst" ]]; then
      continue
    fi
    _PORTABLE_MANIFEST_PREV_DSTS+=("$dst")
    _PORTABLE_MANIFEST_PREV_MODES+=("$mode")
    _PORTABLE_MANIFEST_PREV_SHA256S+=("$sha")
  done < "$path"
}

_portable_manifest_prev_sha256() {
  local dst="${1-}"
  local i
  local path
  path="$(_portable_manifest_path)" || return 1

  _portable_manifest_prev_load "$path"

  for ((i = 0; i < ${#_PORTABLE_MANIFEST_PREV_DSTS[@]}; i++)); do
    if [[ "${_PORTABLE_MANIFEST_PREV_DSTS[i]}" == "$dst" ]]; then
      [[ "${_PORTABLE_MANIFEST_PREV_MODES[i]:-}" == "copy" ]] || return 1
      printf '%s\n' "${_PORTABLE_MANIFEST_PREV_SHA256S[i]:-}"
      return 0
    fi
  done
  return 1
}

manifest_record() {
  local src="${1-}"
  local dst="${2-}"
  local mode="${3-}"
  local sha256="${4-}"
  local fallback_reason="${5-}"
  local src_abs
  local dst_abs
  local dst_parent
  local escaped_src
  local escaped_dst
  local entry

  if [[ -z "$src" || -z "$dst" || -z "$mode" ]]; then
    printf 'portable: manifest_record requires src, dst, mode\n' >&2
    return 3
  fi

  case "$mode" in
    symlink)
      ;;
    junction)
      ;;
    copy)
      [[ -n "$sha256" ]] || {
        printf 'portable: manifest_record copy entry missing sha256\n' >&2
        return 3
      }
      [[ -n "$fallback_reason" ]] || {
        printf 'portable: manifest_record copy entry missing fallback_reason\n' >&2
        return 3
      }
      ;;
    *)
      printf 'portable: manifest_record unsupported mode: %s\n' "$mode" >&2
      return 3
      ;;
  esac

  src_abs="$(realpath_m "$src" 2>/dev/null || printf '%s' "$src")"
  dst_parent="$(realpath -- "$(dirname "$dst")" 2>/dev/null || { cd "$(dirname "$dst")" 2>/dev/null && pwd -P; } || printf '%s' "$(dirname "$dst")")"
  dst_abs="$dst_parent/$(basename "$dst")"
  escaped_src="$(_portable_json_escape "$src_abs")"
  escaped_dst="$(_portable_json_escape "$dst_abs")"

  if [[ "$mode" == "symlink" || "$mode" == "junction" ]]; then
    entry="{\"src\":\"$escaped_src\",\"dst\":\"$escaped_dst\",\"mode\":\"$mode\"}"
  else
    entry="{\"src\":\"$escaped_src\",\"dst\":\"$escaped_dst\",\"mode\":\"copy\",\"sha256\":\"$sha256\",\"fallback_reason\":\"$(_portable_json_escape "$fallback_reason")\"}"
  fi

  _PORTABLE_MANIFEST_RECORDS+=("$entry")
  return 0
}

_portable_manifest_version() {
  local repo_root="${1-}"
  local version=""

  if [[ -n "$repo_root" && -f "$repo_root/VERSION" ]]; then
    version="$(tr -d '\r\n' < "$repo_root/VERSION")"
  elif [[ -n "$repo_root" && -d "$repo_root/.git" ]] && command -v git >/dev/null 2>&1; then
    version="$(git -C "$repo_root" describe --tags --always --dirty 2>/dev/null || git -C "$repo_root" rev-parse --short HEAD 2>/dev/null || true)"
  fi

  if [[ -z "$version" ]]; then
    version="unknown"
  fi
  printf '%s\n' "$version"
}

manifest_flush() {
  local manifest_path="${1-}"
  local repo_root="${2-}"
  local tmpfile
  local installed_at
  local pm_dispatch_version
  local count
  local i
  local entry

  if [[ -z "$manifest_path" ]]; then
    manifest_path="$(_portable_manifest_path)" || manifest_path=""
  fi
  [[ -n "$manifest_path" ]] || {
    printf 'portable: manifest path is empty; cannot flush manifest\n' >&2
    return 3
  }

  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    printf 'portable: manifest write skipped in dry-run for %s\n' "$manifest_path"
    _PORTABLE_MANIFEST_RECORDS=()
    return 0
  fi

  mkdir -p "${manifest_path%/*}"
  tmpfile="$(mktemp "${manifest_path%/*}/.install-manifest.XXXXXX")" || return 3

  installed_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  pm_dispatch_version="$(_portable_manifest_version "$repo_root")"

  {
    printf '{\n'
    printf '  "manifest_version": 1,\n'
    printf '  "installed_at": "%s",\n' "$installed_at"
    printf '  "pm_dispatch_version": "%s",\n' "$(_portable_json_escape "$pm_dispatch_version")"
    printf '  "entries": [\n'
    count="${#_PORTABLE_MANIFEST_RECORDS[@]}"
    for ((i = 0; i < count; i++)); do
      entry="${_PORTABLE_MANIFEST_RECORDS[i]}"
      if (( i + 1 < count )); then
        printf '    %s,\n' "$entry"
      else
        printf '    %s\n' "$entry"
      fi
    done
    printf '  ]\n'
    printf '}\n'
  } > "$tmpfile" || {
    rm -f "$tmpfile"
    return 3
  }

  if ! mv "$tmpfile" "$manifest_path"; then
    rm -f "$tmpfile"
    return 3
  fi

  _PORTABLE_MANIFEST_RECORDS=()
  return 0
}

_portable_copy_path() {
  local src="${1-}"
  local dst="${2-}"

  if [[ -z "$src" || -z "$dst" ]]; then
    return 1
  fi
  if [[ -e "$dst" ]]; then
    rm -rf "$dst"
  fi
  cp -a "$src" "$dst"
}

# make_junction_windows <src_dir> <dst_dir>
# Create a Windows directory junction dst_dir -> src_dir via PowerShell.
# Returns 0 on success, 1 if powershell.exe is unavailable or junction fails.
# Only safe to call when src_dir is a directory.
make_junction_windows() {
  local src="$1" dst="$2"
  if ! command -v powershell.exe >/dev/null 2>&1; then
    printf 'portable: powershell.exe not found — junction unavailable\n' >&2
    return 1
  fi
  local win_src win_dst
  if command -v cygpath >/dev/null 2>&1; then
    win_src="$(cygpath -w "$src")"
    win_dst="$(cygpath -w "$dst")"
  else
    win_src="${src//\//\\}"
    win_dst="${dst//\//\\}"
  fi
  powershell.exe -NoProfile -NonInteractive -Command \
    "New-Item -ItemType Junction -Path '$win_dst' -Target '$win_src' -Force | Out-Null" \
    >/dev/null 2>&1
}

# remove_junction_windows <dst>
# Remove a Windows directory junction at dst via PowerShell Remove-Item.
# Returns 0 on success, 1 if powershell.exe is unavailable or removal fails.
# Remove-Item -Force removes the junction reparse point without following it
# or deleting the junction's target directory contents.
remove_junction_windows() {
  local dst="$1"
  if ! command -v powershell.exe >/dev/null 2>&1; then
    printf 'portable: powershell.exe not found — junction removal unavailable\n' >&2
    return 1
  fi
  local win_dst
  if command -v cygpath >/dev/null 2>&1; then
    win_dst="$(cygpath -w "$dst")"
  else
    win_dst="${dst//\//\\}"
  fi
  # shellcheck disable=SC2016
  PM_DISPATCH_RM_DST="$win_dst" \
    powershell.exe -NoProfile -NonInteractive -Command \
    '[System.IO.Directory]::Delete($env:PM_DISPATCH_RM_DST, $false)' \
    >/dev/null 2>&1
}

link_or_copy() {
  local src="${1-}"
  local dst="${2-}"
  local src_abs
  local dst_abs
  local existing_symlink_target
  local prev_sha
  local curr_sha
  local src_sha
  local fallback_reason
  local sha256
  local ln_rc=0
  local current

  if [[ -z "$src" || -z "$dst" ]]; then
    printf 'portable: link_or_copy requires src and dst\n' >&2
    return 3
  fi

  src_abs="$(realpath_m "$src" 2>/dev/null || printf '%s' "$src")"
  dst_abs="$(realpath_m "$dst" 2>/dev/null || printf '%s' "$dst")"

  if [[ -L "$dst" ]]; then
    existing_symlink_target="$(_portable_resolve_symlink "$dst")"
    if [[ "$existing_symlink_target" == "$src" || "$existing_symlink_target" == "$src_abs" ]]; then
      echo "  ok    $dst"
      manifest_record "$src" "$dst" symlink || return 3
      return 0
    fi
    current="$(readlink "$dst")"
    printf '  CONFLICT %s -> %s (expected %s)\n' "$dst" "$current" "$src" >&2
    return 2
  fi

  prev_sha="$(_portable_manifest_prev_sha256 "$dst_abs" || true)"

  # Guard: dst is a real directory (not a symlink) — ln would create a link inside it.
  # Exempt manifest-managed destinations: if prev_sha is set, we installed it; fall
  # through to the SHA idempotency check below.
  if [[ -d "$dst" && ! -L "$dst" && -z "$prev_sha" ]]; then
    printf '  CONFLICT %s is a real directory — expected a file or symlink target\n' "$dst" >&2
    return 2
  fi

  if [[ -e "$dst" ]]; then
    if [[ -n "$prev_sha" ]] && _portable_sha256_path "$dst" >/dev/null 2>&1; then
      src_sha="$(_portable_sha256_path "$src")"
      curr_sha="$(_portable_sha256_path "$dst")"
      if [[ "$curr_sha" == "$src_sha" ]]; then
        echo "  ok    $dst"
        manifest_record "$src" "$dst" copy "$src_sha" "already up to date (sha256 match)" || return 3
        return 0
      fi
      if [[ "$curr_sha" == "$prev_sha" ]]; then
        if [[ "${DRY_RUN:-0}" == "1" ]]; then
          echo "  would refresh $dst -> $src"
          manifest_record "$src" "$dst" copy "$src_sha" "dry-run refresh" || return 3
          return 0
        fi
        if ! _portable_copy_path "$src" "$dst"; then
          printf 'portable: copy refresh failed for %s -> %s\n' "$src" "$dst" >&2
          return 3
        fi
        manifest_record "$src" "$dst" copy "$src_sha" "refreshed (src updated since last install)" || return 3
        echo "  refresh $dst -> $src"
        return 1
      fi
      printf '  CONFLICT %s exists and does not match manifest entry\n' "$dst" >&2
      return 2
    fi
    printf '  CONFLICT %s exists and is not a symlink — skipping\n' "$dst" >&2
    return 2
  fi

  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    echo "  would  $dst -> $src"
    manifest_record "$src" "$dst" symlink || return 3
    return 0
  fi

  if [[ "${FAKE_SYMLINK_UNSUPPORTED:-0}" == "1" ]]; then
    ln_rc=1
  else
    ln -s "$src" "$dst"; ln_rc=$?
  fi

  if [[ "${FAKE_SYMLINK_BOGUS:-0}" == "1" && "$ln_rc" -eq 0 ]]; then
    rm -rf "$dst"
    if [[ -d "$src" ]]; then
      mkdir -p "$dst"
    else
      : > "$dst"
    fi
  fi

  if [[ "$ln_rc" -eq 0 ]] && [[ -L "$dst" ]]; then
    echo "  link   $dst -> $src"
    manifest_record "$src" "$dst" symlink || return 3
    return 0
  fi

  if [[ "${FAKE_SYMLINK_UNSUPPORTED:-0}" == "1" ]]; then
    fallback_reason="symlink unsupported on host"
  else
    fallback_reason="symlink post-check failed"
  fi

  printf 'portable: fallback copy path for %s: %s\n' "$dst" "$fallback_reason" >&2

  if ! _portable_copy_path "$src" "$dst"; then
    printf 'portable: copy fallback failed for %s -> %s\n' "$src" "$dst" >&2
    return 3
  fi

  sha256="$(_portable_sha256_path "$src")"
  if [[ -z "$sha256" ]]; then
    printf 'portable: unable to compute sha256 for copy source %s\n' "$src" >&2
    return 3
  fi

  manifest_record "$src" "$dst" copy "$sha256" "$fallback_reason" || return 3
  echo "  copy   $dst -> $src"
  return 1
}
