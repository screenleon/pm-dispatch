#!/usr/bin/env bash
# Source-safe digest primitives shared by the Gate entrypoint and verifiers.
# Sourcing only defines functions and one variable; it starts no process.

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
# Without gate_digest_init every call takes the slow path below, which is the
# original per-call behavior: correct, just not faster.
_GATE_DIGEST_TOOL=""

# Probe for a working tool and remember it.  Call once, from the main shell.
# A tool that works now but breaks later is not noticed (a call then yields an
# empty digest, like a tool failing mid-call always did); one that disappears
# from PATH is, and takes the slow path.
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

# The original per-call behavior, kept verbatim as the slow path: used when
# gate_digest_init was not called or found no tool, or when the remembered one is
# no longer on PATH.  It re-probes, so a changed PATH and the "no tool" error
# keep working.
_gate_digest_stream_probe() {
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

# Read stdin and store its SHA-256 (64 hex characters, no newline) in the
# caller's variable <out-var>; it is empty when the tool itself fails, as the
# old `tool | awk` printed nothing then.  Returns 2 when no digest tool exists.
# After gate_digest_init this is one process (the tool) per call, where the old
# code needed four: the probe's subshell and tool, the tool, and awk.  The
# locals are _gds_-prefixed because printf -v writes through dynamic scope: do
# not pass an out-var named like one.
# usage: _gate_digest_stream_var <out-var>
_gate_digest_stream_var() {
  local _gds_line=""
  # `command -v` is a builtin, so confirming the remembered tool costs no process.
  if [[ "$_GATE_DIGEST_TOOL" == sha256sum ]] && command -v sha256sum >/dev/null 2>&1; then
    _gds_line="$(sha256sum)" || :
  elif [[ "$_GATE_DIGEST_TOOL" == shasum ]] && command -v shasum >/dev/null 2>&1; then
    _gds_line="$(shasum -a 256)" || :
  else
    _gds_line="$(_gate_digest_stream_probe)" || return
  fi
  # The tool prints "<hash>  -"; keep the first field (what `awk '{print $1}'` did).
  printf -v "$1" '%s' "${_gds_line%% *}"
}

# Print the SHA-256 of stdin as 64 hex characters and a newline.
# Exit status: 0, or 2 when no digest tool exists.
gate_digest_stream() {
  local _gdt_digest=""
  _gate_digest_stream_var _gdt_digest || return
  [[ -z "$_gdt_digest" ]] || printf '%s\n' "$_gdt_digest"
}

gate_digest_file() {
  local file="${1:-}" _gdf_digest=""
  [[ -n "$file" ]] || return 2
  _gate_digest_stream_var _gdf_digest < "$file" || return 2
  printf '%s\n' "$_gdf_digest"
}
