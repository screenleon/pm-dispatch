#!/usr/bin/env bash
# Shared guard: fingerprint the developer's live repo context.db (plus its
# WAL/SHM sidecars, when sqlite has them open) so test suites can prove a run
# never read/wrote it. Caller must set REPO_ROOT before sourcing this file,
# then capture a baseline at the point isolation is expected to begin:
#   LIVE_DB_BASELINE="$(_live_db_fingerprint)"
# and compare against a fresh fingerprint at the end of the run. Each entry
# combines a content digest with a nanosecond-precision mtime, so a content
# change, a same-second metadata-only touch, AND a same-second write that
# restores identical bytes are all detected — content digest alone would miss
# the latter two, and whole-second mtime would still miss a same-second one.

LIVE_DB="$REPO_ROOT/.pm-dispatch/ctx/context.db"

_live_db_file_digest() {
  local f="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum -- "$f" 2>/dev/null | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 -- "$f" 2>/dev/null | awk '{print $1}'
  else
    printf 'NOSHATOOL'
  fi
}

_live_db_file_mtime() {
  # Nanosecond precision (GNU stat's %.9Y) first — a same-second rewrite still
  # advances mtime at nanosecond granularity, which whole-second %Y cannot see.
  # Fall back to whole-second precision only where GNU stat/coreutils is absent.
  stat -c '%.9Y' "$1" 2>/dev/null || stat -c '%Y' "$1" 2>/dev/null || stat -f '%m' "$1" 2>/dev/null
}

_live_db_fingerprint() {
  local f digest mtime out=''
  for f in "$LIVE_DB" "$LIVE_DB-wal" "$LIVE_DB-shm"; do
    if [[ -e "$f" ]]; then
      digest="$(_live_db_file_digest "$f")"
      mtime="$(_live_db_file_mtime "$f")"
    else
      digest='ABSENT'
      mtime='-'
    fi
    out+="$f:$digest:$mtime;"
  done
  printf '%s' "$out"
}
