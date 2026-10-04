#!/usr/bin/env bash
# Source-safe digest primitives shared by the Gate entrypoint and verifiers.
# Sourcing only defines functions and one variable; it starts no process.
#
# Contract (CC-629 c): gate_digest_stream and gate_digest_file print exactly one SHA-256, 64
# lowercase hex digits and a newline, and return 0; if no digest can be produced (no tool, a tool that
# fails or prints something that is not a digest, an unreadable file) they print NOTHING and return 2.
# (A closed stdout does not change the status of gate_digest_stream, as before.) Before CC-629 a tool that
# failed mid-call gave an empty digest and status 0, which the many callers written as
# `digest="$(...)" || return` could not see, so an empty value could end up recorded as a content digest.

# The digest tool is chosen once per process by gate_digest_init, not on every
# call (CC-611).  Probing per call ran `printf '' | sha256sum` (two processes)
# before every digest, and a gate makes dozens of digests; on native Windows each
# process costs ~40 ms.  The choice lives in a plain variable that command
# substitutions and pipelines inherit.  A function cannot memoize it lazily:
# most callers run it inside `$(...)` or a pipeline, whose subshell discards
# anything the function sets.  So the entrypoint that digests a lot (pr-gate.sh)
# calls gate_digest_init once, in its main shell.  Sourcing does not probe: many
# processes source this file (every pmctl command loads the gate libraries) and
# never digest, and they must not pay for it.
#   sha256sum | shasum | "" (not initialised, or neither tool works)
# A process that does not call gate_digest_init takes the original per-call path
# below, at the same cost and with the same results as before.
_GATE_DIGEST_TOOL=""

# Probe for a working tool and remember it.  Call once, from the main shell.
# Keep the tool order and tests in step with _gate_digest_stream_probe below.
# A tool that works now but breaks later is not noticed by the choice itself, but each
# call then fails (prints nothing, returns 2: CC-629 c); one that disappears from PATH
# is noticed, and takes the original path.
gate_digest_init() {
  _GATE_DIGEST_TOOL=""
  if command -v sha256sum >/dev/null 2>&1 \
      && printf '' | sha256sum >/dev/null 2>&1; then
    _GATE_DIGEST_TOOL=sha256sum
  elif command -v shasum >/dev/null 2>&1 \
      && printf '' | shasum -a 256 >/dev/null 2>&1; then
    _GATE_DIGEST_TOOL=shasum
  fi
  return 0
}

# The original per-call path: used when gate_digest_init was not called or found no
# tool, or when the remembered one is no longer on PATH.  It re-probes, so a changed
# PATH and the "no tool" error keep working (it no longer pipes through awk and
# validates the digest like the fast path since CC-629 c).  Keep the tool order and
# tests in step with gate_digest_init above.
_gate_digest_stream_probe() {
  local _gdp_line=""
  if command -v sha256sum >/dev/null 2>&1 \
      && printf '' | sha256sum >/dev/null 2>&1; then
    _gdp_line="$(sha256sum)" || return 2
  elif command -v shasum >/dev/null 2>&1 \
      && printf '' | shasum -a 256 >/dev/null 2>&1; then
    _gdp_line="$(shasum -a 256)" || return 2
  else
    printf 'Error: no sha256sum or shasum found -- cannot fingerprint gate inputs.\n' >&2
    return 2
  fi
  # The tool prints "<hash>  -"; keep the first field and accept nothing but a digest.
  _gdp_line="${_gdp_line%% *}"
  [[ "$_gdp_line" =~ ^[0-9a-f]{64}$ ]] || return 2
  # A failed write (closed stdout) must not change the status.
  printf '%s\n' "$_gdp_line" || :
  return 0
}

# True when gate_digest_init found a tool and it is still on PATH.  `command -v`
# is a builtin, so this costs no process.
_gate_digest_fast_ok() {
  case "$_GATE_DIGEST_TOOL" in
    sha256sum) command -v sha256sum >/dev/null 2>&1 ;;
    shasum) command -v shasum >/dev/null 2>&1 ;;
    *) return 1 ;;
  esac
}

# Read stdin with the remembered tool and store its SHA-256 (64 hex characters,
# no newline) in the caller's variable <out-var>; it is EMPTY when the tool fails or exits
# non-zero, and the callers below validate it and fail.  Only call it when
# _gate_digest_fast_ok.  One process (the tool) per call, where the old code needed
# four: the probe's subshell and tool, the tool, and awk.  The local is
# _gds_-prefixed because printf -v writes through dynamic scope: do not pass an
# out-var named like it.
# usage: _gate_digest_run <out-var>
_gate_digest_run() {
  local _gds_line=""
  case "$_GATE_DIGEST_TOOL" in
    sha256sum) _gds_line="$(sha256sum)" || _gds_line="" ;;
    shasum) _gds_line="$(shasum -a 256)" || _gds_line="" ;;
  esac
  # The tool prints "<hash>  -"; keep the first field (what `awk '{print $1}'` did).
  printf -v "$1" '%s' "${_gds_line%% *}"
}

# Print the SHA-256 of stdin as 64 hex characters and a newline.
# Exit status: 0, or 2 when no digest tool exists or the tool did not produce a digest (nothing is
# printed then).
gate_digest_stream() {
  if ! _gate_digest_fast_ok; then
    _gate_digest_stream_probe
    return
  fi
  local _gdt_digest=""
  _gate_digest_run _gdt_digest
  [[ "$_gdt_digest" =~ ^[0-9a-f]{64}$ ]] || return 2
  # A failed write (closed stdout) must not change the status: the old code ended
  # `tool | awk; return 0`.
  printf '%s\n' "$_gdt_digest" || :
  return 0
}

gate_digest_file() {
  local file="${1:-}" _gdf_digest=""
  [[ -n "$file" ]] || return 2
  if _gate_digest_fast_ok; then
    _gate_digest_run _gdf_digest < "$file" || return 2
  else
    _gdf_digest="$(gate_digest_stream < "$file")" || return 2
  fi
  [[ "$_gdf_digest" =~ ^[0-9a-f]{64}$ ]] || return 2
  # a failed write (closed stdout) does not change the status, as for gate_digest_stream
  printf '%s\n' "$_gdf_digest" || :
}
