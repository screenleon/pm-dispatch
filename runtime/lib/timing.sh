#!/usr/bin/env bash
# Phase markers for `pmctl time` (CC-689, issue #742).
#
# pm_timing_phase <name> says "phase <name> begins now". With PM_DISPATCH_TIMING_FILE unset it is a
# no-op that starts no process, so call sites can stay in hooks and hot paths. With it set, one tab-separated
# line (name, time) goes to that file, never to stdout or stderr: a hook's stdout is injected into the prompt and
# must stay byte-identical whether or not timing is on.
#
# A phase lasts until the next marker, or until the measured command exits. The file only describes
# time; nothing here may fail the caller, so every path returns 0.
#
#   ensure_fresh<TAB>1792979208.123456
#
# `t` is $EPOCHREALTIME (bash 5, no process). On a bash without it the marker falls back to whole
# seconds, which `pmctl time` still accepts; the locale's decimal comma is normalised to a point.

pm_timing_phase() {
  [[ -n "${PM_DISPATCH_TIMING_FILE:-}" ]] || return 0
  local name="${1:-}" now
  [[ "$name" =~ ^[a-z0-9_.-]+$ ]] || return 0
  now="${EPOCHREALTIME:-}"
  if [[ -z "$now" ]]; then
    printf -v now '%(%s)T' -1 2>/dev/null || return 0
  fi
  now="${now/,/.}"
  # The braces matter: a failed `>>` open is reported by the shell before a trailing 2>/dev/null applies.
  { printf '%s\t%s\n' "$name" "$now" >> "$PM_DISPATCH_TIMING_FILE"; } 2>/dev/null || true
  return 0
}
