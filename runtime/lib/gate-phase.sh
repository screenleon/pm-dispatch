#!/usr/bin/env bash
# Phase events of a detached gate: what it is doing now and when it last moved (CC-685, issue #736).
#
# pr-gate.sh appends one JSON line per event to <run dir>/gate-phase-events.jsonl; `pmctl gate status`
# and the `gate wait` timeout line read it back. The file only describes progress: it never decides a
# verdict, and nothing here may make a gate fail, so every writer path returns 0 even when the run
# directory is missing or not writable (a foreground gate has no run directory and records nothing).
#
# One event:
#   {"kind":"gate_phase_event_v1","ts":"2026-10-26T10:46:48+09:00","epoch":1792979208,
#    "phase":"scope_manifest","event":"start|end|info","detail":"changed_paths=9"}
# `ts` carries the zone, `epoch` is what the reader subtracts. A phase is open from its `start` until a
# later `end` of the same phase, or until the `gate` phase ends (a gate that stopped mid-phase leaves
# nothing running); `info` events (phase `context`, reviewer launches) leave no state. The `gate` phase
# itself spans the whole run and is never reported as the phase being worked on.
#
# Detail strings are for people: key=value words, never secrets. Control characters are folded to spaces.

GATE_PHASE_EVENTS_NAME=gate-phase-events.jsonl

# gate_phase_now: set GATE_PHASE_NOW (epoch) and GATE_PHASE_TS (ISO with zone, +09:00) without a process
# where the shell can format time itself (bash 4.2+), else from one `date`.
gate_phase_now() {
  if printf -v GATE_PHASE_NOW '%(%s)T' -1 2>/dev/null \
      && printf -v GATE_PHASE_TS '%(%Y-%m-%dT%H:%M:%S%z)T' -1 2>/dev/null; then
    :
  else
    read -r GATE_PHASE_NOW GATE_PHASE_TS < <(date '+%s %Y-%m-%dT%H:%M:%S%z' 2>/dev/null) || return 1
  fi
  [[ "$GATE_PHASE_NOW" =~ ^[0-9]+$ ]] || return 1
  # +0900 -> +09:00
  if [[ "$GATE_PHASE_TS" =~ ^(.*[+-][0-9][0-9])([0-9][0-9])$ ]]; then
    GATE_PHASE_TS="${BASH_REMATCH[1]}:${BASH_REMATCH[2]}"
  fi
}

# gate_phase_emit <phase> <start|end|info> [detail]
gate_phase_emit() {
  local phase="${1:-}" event="${2:-}" detail="${3:-}"
  [[ -n "${GATE_RUN_DIR_OVERRIDE:-}" && -d "$GATE_RUN_DIR_OVERRIDE" ]] || return 0
  [[ "$phase" =~ ^[a-z_]+$ && "$event" =~ ^(start|end|info)$ ]] || return 0
  gate_phase_now || return 0
  detail="${detail//\\/\\\\}"
  detail="${detail//\"/\\\"}"
  detail="${detail//[[:cntrl:]]/ }"
  printf '{"kind":"gate_phase_event_v1","ts":"%s","epoch":%s,"phase":"%s","event":"%s","detail":"%s"}\n' \
    "$GATE_PHASE_TS" "$GATE_PHASE_NOW" "$phase" "$event" "$detail" \
    >> "$GATE_RUN_DIR_OVERRIDE/$GATE_PHASE_EVENTS_NAME" 2>/dev/null || true
  return 0
}

# gate_phase_read <events file>: KEY=VALUE lines describing the file, nothing when it has no event.
#   count, first_epoch, first_ts, last_epoch, last_ts, last_phase, last_event, last_detail,
#   open_phase, open_epoch, open_detail   (the open_* keys are empty between phases and after `gate end`)
# Unreadable or foreign lines are skipped rather than failing the read: a line cut short by a crash
# must not hide the events before it. A native Windows jq writes CRLF, so every reader strips the CR.
gate_phase_read() {
  local file="$1"
  [[ -r "$file" ]] || return 0
  jq -Rrn '
    [inputs | fromjson? | select(type == "object" and .kind == "gate_phase_event_v1")] as $e
    | if ($e | length) == 0 then empty else
        ($e | first) as $first | ($e | last) as $last
        | (if any($e[]; .phase == "gate" and .event == "end") then null else
             ([range(0; $e | length) as $i | $e[$i]
               | select(.event == "start" and .phase != "gate")
               | . as $s
               | select([$e[($i + 1):][] | select(.event == "end" and .phase == $s.phase)] | length == 0)]
              | last)
           end) as $open
        | "count=\($e | length)",
          "first_epoch=\($first.epoch)",
          "first_ts=\($first.ts)",
          "last_epoch=\($last.epoch)",
          "last_ts=\($last.ts)",
          "last_phase=\($last.phase)",
          "last_event=\($last.event)",
          "last_detail=\($last.detail | gsub("[\\n\\t]"; " "))",
          "open_phase=\($open.phase // "")",
          "open_epoch=\($open.epoch // "")",
          "open_detail=\(($open.detail // "") | gsub("[\\n\\t]"; " "))"
      end' "$file" 2>/dev/null | tr -d '\r' || true
}

# gate_phase_load <events file>: gate_phase_read into GATE_PHASE_COUNT, GATE_PHASE_FIRST_EPOCH, ... (the
# upper-cased keys above). Every variable is reset first, so a file with no event leaves them all empty.
gate_phase_load() {
  local key value
  for key in count first_epoch first_ts last_epoch last_ts last_phase last_event last_detail \
      open_phase open_epoch open_detail; do
    printf -v "GATE_PHASE_${key^^}" '%s' ''
  done
  while IFS='=' read -r key value; do
    case "$key" in
      count|first_epoch|first_ts|last_epoch|last_ts|last_phase|last_event|last_detail|open_phase|open_epoch|open_detail)
        printf -v "GATE_PHASE_${key^^}" '%s' "$value" ;;
    esac
  done < <(gate_phase_read "$1")
  [[ -n "$GATE_PHASE_COUNT" && "$GATE_PHASE_LAST_EPOCH" =~ ^[0-9]+$ && "$GATE_PHASE_FIRST_EPOCH" =~ ^[0-9]+$ ]]
}

# gate_phase_context <events file>: the details of the `context` events, one per line, in order.
gate_phase_context() {
  local file="$1"
  [[ -r "$file" ]] || return 0
  jq -Rr 'fromjson? | select(type == "object" and .kind == "gate_phase_event_v1"
                             and .phase == "context" and .event == "info") | .detail' \
    "$file" 2>/dev/null | tr -d '\r' || true
}

# gate_phase_tail <events file> [count]: the last events as "ts phase event detail", oldest first.
gate_phase_tail() {
  local file="$1" count="${2:-6}"
  [[ -r "$file" ]] || return 0
  jq -Rr 'fromjson?
    | select(type == "object" and .kind == "gate_phase_event_v1")
    | "\(.ts) \(.phase) \(.event)" + (if .detail == "" then "" else " " + .detail end)' "$file" 2>/dev/null \
    | tr -d '\r' | tail -n "$count" || true
}

# gate_phase_format_seconds <n>: 75 -> 1m15s, 4000 -> 1h06m40s.
gate_phase_format_seconds() {
  local n="${1:-0}"
  [[ "$n" =~ ^[0-9]+$ ]] || { printf '?'; return 0; }
  if (( n >= 3600 )); then
    printf '%dh%02dm%02ds' $((n / 3600)) $((n % 3600 / 60)) $((n % 60))
  elif (( n >= 60 )); then
    printf '%dm%02ds' $((n / 60)) $((n % 60))
  else
    printf '%ds' "$n"
  fi
}

# gate_phase_brief <events file>: one line, "phase scope_manifest for 2m14s, last event 14s ago", or
# nothing when there is no event to report.
gate_phase_brief() {
  gate_phase_load "$1" || return 0
  gate_phase_now || return 0
  if [[ -n "$GATE_PHASE_OPEN_PHASE" && "$GATE_PHASE_OPEN_EPOCH" =~ ^[0-9]+$ ]]; then
    printf 'phase %s for %s, last event %s ago' "$GATE_PHASE_OPEN_PHASE" \
      "$(gate_phase_format_seconds $((GATE_PHASE_NOW - GATE_PHASE_OPEN_EPOCH)))" \
      "$(gate_phase_format_seconds $((GATE_PHASE_NOW - GATE_PHASE_LAST_EPOCH)))"
  else
    printf 'between phases (last: %s %s), last event %s ago' "$GATE_PHASE_LAST_PHASE" "$GATE_PHASE_LAST_EVENT" \
      "$(gate_phase_format_seconds $((GATE_PHASE_NOW - GATE_PHASE_LAST_EPOCH)))"
  fi
}
