#!/usr/bin/env bash
# Install or validate the repository-pinned ShellCheck toolchain.

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../.." && pwd)"
cache_root="${PM_DISPATCH_TOOL_CACHE:-}"
check_only=0
resolve_only=0

usage() {
  printf 'usage: %s [--repo <path>] [--cache-dir <path>] [--check|--resolve]\n' "$0"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)
      [[ $# -ge 2 && -n "$2" ]] || { usage >&2; exit 2; }
      repo_root="$2"
      shift 2
      ;;
    --cache-dir)
      [[ $# -ge 2 && -n "$2" ]] || { usage >&2; exit 2; }
      cache_root="$2"
      shift 2
      ;;
    --check)
      check_only=1
      shift
      ;;
    --resolve)
      resolve_only=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'bootstrap-shellcheck: unknown argument: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "$cache_root" ]]; then
  if [[ -n "${XDG_CACHE_HOME:-}" ]]; then
    cache_root="$XDG_CACHE_HOME/pm-dispatch/tools"
  elif [[ -n "${HOME:-}" ]]; then
    cache_root="$HOME/.cache/pm-dispatch/tools"
  elif [[ "$check_only" -ne 1 && "$resolve_only" -ne 1 ]]; then
    printf 'bootstrap-shellcheck: HOME, XDG_CACHE_HOME, --cache-dir, or PM_DISPATCH_TOOL_CACHE is required\n' >&2
    exit 2
  fi
fi

if [[ "$check_only" -eq 1 && "$resolve_only" -eq 1 ]]; then
  printf 'bootstrap-shellcheck: --check and --resolve are mutually exclusive\n' >&2
  exit 2
fi

pin_file="$repo_root/.shellcheck-version"
assets_file="$repo_root/tools/lint/shellcheck-assets.tsv"
declare -a pin_lines=()
[[ -f "$pin_file" ]] || {
  printf 'bootstrap-shellcheck: missing repository version pin: %s\n' "$pin_file" >&2
  exit 2
}
mapfile -t pin_lines < "$pin_file"
if [[ "${#pin_lines[@]}" -ne 1 \
    || ! "${pin_lines[0]}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  printf 'bootstrap-shellcheck: .shellcheck-version must contain exactly one semantic version\n' >&2
  exit 2
fi
expected_version="${pin_lines[0]}"

shellcheck_version() {
  local binary="$1" output actual
  output="$("$binary" --version 2>&1)" || return 1
  actual="$(awk -F ':[[:space:]]*' '$1 == "version" { print $2; exit }' <<< "$output")"
  [[ -n "$actual" ]] || return 1
  printf '%s\n' "$actual"
}

check_binary() {
  local binary="$1" actual
  actual="$(shellcheck_version "$binary")" || {
    printf 'bootstrap-shellcheck: could not read ShellCheck version from %s\n' "$binary" >&2
    return 2
  }
  if [[ "$actual" != "$expected_version" ]]; then
    printf 'bootstrap-shellcheck: ShellCheck version mismatch: expected %s, got %s (%s)\n' \
      "$expected_version" "$actual" "$binary" >&2
    return 2
  fi
}

detect_platform() {
  case "$(uname -s):$(uname -m)" in
    Linux:x86_64) printf 'linux.x86_64\n' ;;
    Linux:aarch64|Linux:arm64) printf 'linux.aarch64\n' ;;
    Darwin:x86_64) printf 'darwin.x86_64\n' ;;
    Darwin:arm64|Darwin:aarch64) printf 'darwin.aarch64\n' ;;
    *) return 1 ;;
  esac
}

# Directory holding the pinned binary for this platform, or empty when the
# platform has no published asset. Says nothing about whether it exists.
cached_bin_dir() {
  local platform
  [[ -n "$cache_root" ]] || return 0
  platform="$(detect_platform)" || return 0
  printf '%s/shellcheck/%s/%s/bin\n' "$cache_root" "$expected_version" "$platform"
}

# --resolve: report a bin directory holding the pinned ShellCheck, WITHOUT
# touching the network. Callers that need a working toolchain use this instead
# of requiring the pin to already sit on PATH: a gate reviewer or CI sandbox
# inherits a PATH nobody in this repo controls, but it does reach the cache a
# previous bootstrap already populated. Downloading here is deliberately still
# off the table — lint must not become an implicit installer.
if [[ "$resolve_only" -eq 1 ]]; then
  path_diagnostic='ShellCheck is not on PATH'
  shellcheck_path="$(command -v shellcheck || true)"
  if [[ -n "$shellcheck_path" ]]; then
    if check_binary "$shellcheck_path" 2>/dev/null; then
      resolved_dir="$(cd "$(dirname "$shellcheck_path")" && pwd)" || {
        printf 'bootstrap-shellcheck: cannot resolve the directory of %s\n' \
          "$shellcheck_path" >&2
        exit 2
      }
      printf '%s\n' "$resolved_dir"
      exit 0
    fi
    path_diagnostic="$(check_binary "$shellcheck_path" 2>&1 >/dev/null || true)"
    path_diagnostic="${path_diagnostic#bootstrap-shellcheck: }"
  fi

  resolve_cache_dir="$(cached_bin_dir)"
  if [[ -n "$resolve_cache_dir" && -x "$resolve_cache_dir/shellcheck" ]] \
      && check_binary "$resolve_cache_dir/shellcheck" 2>/dev/null; then
    printf '%s\n' "$resolve_cache_dir"
    exit 0
  fi

  printf 'bootstrap-shellcheck: no ShellCheck %s available\n' "$expected_version" >&2
  printf 'bootstrap-shellcheck: PATH: %s\n' "$path_diagnostic" >&2
  if [[ -n "$resolve_cache_dir" ]]; then
    printf 'bootstrap-shellcheck: cache: no pinned binary at %s/shellcheck\n' \
      "$resolve_cache_dir" >&2
  else
    printf 'bootstrap-shellcheck: cache: no cache root for this platform\n' >&2
  fi
  printf '%s\n' \
    'bootstrap-shellcheck: populate the cache with:' \
    '  bash tools/lint/bootstrap-shellcheck.sh' >&2
  exit 2
fi

if [[ "$check_only" -eq 1 ]]; then
  shellcheck_path="$(command -v shellcheck || true)"
  [[ -n "$shellcheck_path" ]] || {
    printf 'bootstrap-shellcheck: ShellCheck %s is required on PATH\n' "$expected_version" >&2
    # shellcheck disable=SC2016  # Print literal commands for the maintainer's shell.
    printf '%s\n' \
      'bootstrap-shellcheck: install it with:' \
      '  shellcheck_bin_dir="$(bash tools/lint/bootstrap-shellcheck.sh)" &&' \
      '    export PATH="$shellcheck_bin_dir:$PATH"' >&2
    exit 2
  }
  check_binary "$shellcheck_path"
  exit $?
fi

[[ -f "$assets_file" ]] || {
  printf 'bootstrap-shellcheck: missing asset manifest: %s\n' "$assets_file" >&2
  exit 2
}
[[ "$(head -n 1 "$assets_file")" == $'version\tplatform\turl\tsha256' ]] || {
  printf 'bootstrap-shellcheck: invalid asset manifest header\n' >&2
  exit 2
}

platform="$(detect_platform)" || {
  printf 'bootstrap-shellcheck: unsupported platform: %s %s\n' "$(uname -s)" "$(uname -m)" >&2
  exit 2
}

asset_url=""
asset_sha256=""
asset_matches=0
while IFS=$'\t' read -r version asset_platform url sha256 extra; do
  [[ "$version" != version ]] || continue
  if [[ "$version" == "$expected_version" && "$asset_platform" == "$platform" ]]; then
    [[ -z "${extra:-}" ]] || {
      printf 'bootstrap-shellcheck: malformed asset row for %s %s\n' "$version" "$asset_platform" >&2
      exit 2
    }
    asset_url="$url"
    asset_sha256="$sha256"
    asset_matches=$((asset_matches + 1))
  fi
done < "$assets_file"
if [[ "$asset_matches" -ne 1 || -z "$asset_url" \
    || ! "$asset_sha256" =~ ^[0-9a-f]{64}$ ]]; then
  printf 'bootstrap-shellcheck: expected exactly one valid asset for %s %s\n' \
    "$expected_version" "$platform" >&2
  exit 2
fi

# Same helper --resolve probes, so the install target and the offline lookup
# cannot drift apart.
target_dir="$(cached_bin_dir)"
target_bin="$target_dir/shellcheck"
if [[ -x "$target_bin" ]] && check_binary "$target_bin" 2>/dev/null; then
  printf '%s\n' "$target_dir"
  exit 0
fi

for required_tool in curl tar; do
  command -v "$required_tool" >/dev/null 2>&1 || {
    printf 'bootstrap-shellcheck: %s is required to install the pinned tool\n' "$required_tool" >&2
    exit 2
  }
done

sha256_file() {
  local file="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$file" | awk '{ print $1 }'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$file" | awk '{ print $1 }'
  else
    printf 'bootstrap-shellcheck: sha256sum or shasum is required\n' >&2
    return 2
  fi
}

mkdir -p "$cache_root"
tmp_dir="$(mktemp -d "$cache_root/.shellcheck-${expected_version}.XXXXXX")"
trap 'rm -rf -- "$tmp_dir"' EXIT
archive="$tmp_dir/${asset_url##*/}"
extract_dir="$tmp_dir/extract"
mkdir -p "$extract_dir"
printf 'bootstrap-shellcheck: downloading ShellCheck %s for %s\n' \
  "$expected_version" "$platform" >&2
curl --fail --location --silent --show-error "$asset_url" --output "$archive"
actual_sha256="$(sha256_file "$archive")" || exit $?
if [[ "$actual_sha256" != "$asset_sha256" ]]; then
  printf 'bootstrap-shellcheck: checksum mismatch for %s: expected %s, got %s\n' \
    "${asset_url##*/}" "$asset_sha256" "$actual_sha256" >&2
  exit 2
fi

tar -xzf "$archive" -C "$extract_dir"
extracted_bin="$extract_dir/shellcheck-v${expected_version}/shellcheck"
[[ -f "$extracted_bin" ]] || {
  printf 'bootstrap-shellcheck: archive is missing shellcheck-v%s/shellcheck\n' \
    "$expected_version" >&2
  exit 2
}
chmod +x "$extracted_bin"
check_binary "$extracted_bin"

mkdir -p "$target_dir"
staged_bin="$target_dir/.shellcheck.$$.$RANDOM"
cp "$extracted_bin" "$staged_bin"
chmod +x "$staged_bin"
mv -f "$staged_bin" "$target_bin"
printf '%s\n' "$target_dir"
