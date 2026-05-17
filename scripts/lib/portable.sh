#!/usr/bin/env bash
# Cross-platform path and locking helpers for PM Dispatch shell scripts.

set -euo pipefail

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

  [[ -n "$lockdir" ]] || return 1

  if ! [[ "$timeout_sec" =~ ^[0-9]+$ ]]; then
    timeout_sec=2
  fi

  attempts=$(( timeout_sec * 20 ))
  (( attempts > 0 )) || attempts=1

  for ((i = 0; i < attempts; i++)); do
    if mkdir "$lockdir" 2>/dev/null; then
      return 0
    fi
    sleep 0.05
  done

  printf 'portable: mkdir_lock timeout after %s seconds for %s\n' "$timeout_sec" "$lockdir" >&2
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
