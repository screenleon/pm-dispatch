#!/usr/bin/env bash
# Source-safe digest primitives shared by the Gate entrypoint and verifiers.

gate_digest_stream() {
  if command -v sha256sum >/dev/null 2>&1 \
      && printf '' | sha256sum >/dev/null 2>&1; then
    sha256sum | awk '{print $1}'
    return 0
  fi
  if command -v shasum >/dev/null 2>&1 \
      && printf '' | shasum -a 256 >/dev/null 2>&1; then
    shasum -a 256 | awk '{print $1}'
    return 0
  fi
  printf 'Error: no sha256sum or shasum found -- cannot fingerprint gate inputs.\n' >&2
  return 2
}

gate_digest_file() {
  local file="${1:-}" digest
  [[ -n "$file" ]] || return 2
  digest="$(gate_digest_stream < "$file")" || return 2
  printf '%s\n' "$digest"
}
