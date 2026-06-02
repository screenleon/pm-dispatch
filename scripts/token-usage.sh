#!/usr/bin/env bash
#
# token-usage.sh — multi-pool token usage estimator (Claude / Codex / Spark)
# Pure bash+jq implementation (CC-104t) — no python3 dependency.
#
# Usage:
#   bash ~/.claude/scripts/token-usage.sh               # last 5 hours
#   bash ~/.claude/scripts/token-usage.sh --today       # today only
#   bash ~/.claude/scripts/token-usage.sh --all         # all time
#   bash ~/.claude/scripts/token-usage.sh --remaining    # auto-populate from rate-limits.json
#   bash ~/.claude/scripts/token-usage.sh --remaining N # estimate time left (N = % remaining from dashboard)

set -euo pipefail

LOGFILE="$HOME/.claude/usage-tracker.jsonl"
CALIB_FILE="$HOME/.claude/usage-calibration.json"
MODE="--5h"
REMAINING_PCT_ARG=""
RATE_LIMITS_FILE="${CLAUDE_CONFIG_DIR:-${HOME}/.claude}/rate-limits.json"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --today|--all|--[0-9]*h) MODE="$1"; shift ;;
    --remaining)
      if [[ $# -ge 2 && "$2" != --* ]]; then
        REMAINING_PCT_ARG="$2"; shift 2
      else
        REMAINING_PCT_ARG="auto"; shift
      fi ;;
    *) echo "token-usage: unknown argument: $1" >&2; exit 2 ;;
  esac
done

if [[ "$MODE" != "--today" && "$MODE" != "--all" && ! "$MODE" =~ ^--[0-9]+h$ ]]; then
  printf 'token-usage: unknown mode: %s\n' "$MODE" >&2
  printf 'Usage: token-usage.sh [--today|--all|--Nh]  (default: --5h)\n' >&2
  exit 2
fi

if [[ ! -f "$LOGFILE" ]]; then
  echo "No usage log at $LOGFILE"
  echo "Use: bash ~/.claude/scripts/log-usage.sh <type> <tokens> [note]"
  exit 0
fi

NOW_EPOCH=$(date +%s)

# Compute label and cutoff epoch
case "$MODE" in
  --today)
    LABEL="today (UTC)"
    # Start of today UTC: strip time portion from UTC date, reparse as epoch
    _today_date=$(date -u +"%Y-%m-%d")
    CUTOFF_EPOCH=$(date -u -d "${_today_date}T00:00:00Z" +%s 2>/dev/null || \
                   date -u -j -f "%Y-%m-%dT%H:%M:%SZ" "${_today_date}T00:00:00Z" +%s 2>/dev/null || \
                   echo $((NOW_EPOCH - (NOW_EPOCH % 86400))))
    ;;
  --all)
    LABEL="all time"
    CUTOFF_EPOCH=0
    ;;
  *)
    _hours="${MODE#--}"; _hours="${_hours%h}"
    LABEL="last ${_hours}h"
    CUTOFF_EPOCH=$((NOW_EPOCH - _hours * 3600))
    ;;
esac

# Handle --remaining: resolve "auto" from rate-limits.json
REMAINING_PCT=""
REMAINING_NOTE=""
if [[ "$REMAINING_PCT_ARG" == "auto" ]]; then
  if [[ ! -f "$RATE_LIMITS_FILE" ]]; then
    REMAINING_NOTE="  (note: $RATE_LIMITS_FILE not found — install StatusLine hook or use --remaining N)"
  else
    _rl=$(jq -r --argjson now "$NOW_EPOCH" '
      (.five_hour.used_percentage) as $used |
      (($now - (.updated_at // 0)) / 60 | floor) as $age |
      if $used == null then
        "no_five_hour|\($age)"
      elif ($used | type) != "number" then
        "not_number|\($used)|\($age)"
      elif $used < 0 or $used > 100 then
        "out_of_range|\($used)|\($age)"
      else
        "ok|\(100 - $used)|\($age)"
      end
    ' "$RATE_LIMITS_FILE" 2>/dev/null || echo "error|0|0")
    IFS='|' read -r _rl_status _rl_val _rl_age <<< "$_rl"
    case "$_rl_status" in
      ok)
        REMAINING_PCT="$_rl_val"
        [[ "${_rl_age:-0}" -gt 30 ]] && \
          REMAINING_NOTE="  (note: rate-limits.json is ${_rl_age}min old — may be stale)" ;;
      no_five_hour)
        REMAINING_NOTE="  (note: rate-limits.json has no five_hour.used_percentage)" ;;
      not_number)
        REMAINING_NOTE="  (note: rate-limits.json five_hour.used_percentage=${_rl_val} is not a number — ignoring)" ;;
      out_of_range)
        REMAINING_NOTE="  (note: rate-limits.json five_hour.used_percentage=${_rl_val} is out of range 0–100 — ignoring)" ;;
      *)
        REMAINING_NOTE="  (note: could not read rate-limits.json)" ;;
    esac
  fi
elif [[ -n "$REMAINING_PCT_ARG" ]]; then
  if ! [[ "$REMAINING_PCT_ARG" =~ ^-?[0-9]+(\.[0-9]+)?$ ]]; then
    printf 'token-usage: --remaining must be a number, got: %s\n' "$REMAINING_PCT_ARG" >&2; exit 2
  fi
  if ! jq -en --argjson v "$REMAINING_PCT_ARG" '$v >= 0 and $v <= 100' >/dev/null 2>&1; then
    printf 'token-usage: --remaining must be 0–100, got: %s\n' "$REMAINING_PCT_ARG" >&2; exit 2
  fi
  REMAINING_PCT="$REMAINING_PCT_ARG"
fi

# Parse JSONL, filter by time window, aggregate
# --raw-input: read each line as a string so malformed JSON doesn't abort
_data=$(jq -Rs --argjson cutoff "$CUTOFF_EPOCH" '
  # Split lines, try to parse each as JSON; drop non-parseable lines
  split("\n") | map(select(length > 0 and ltrimstr(" ") != "")) |
  (map(try fromjson catch null) | map(select(. != null))) as $all |
  # Count skipped: malformed (failed parse) + missing ts
  (length - ($all | length)
   + ($all | map(select(.ts == null)) | length)) as $skipped |
  ($all | map(select(.ts != null)) |
   map(. + {_ep: (.ts | fromdateiso8601? // 0)}) |
   map(select(._ep >= $cutoff))) as $e |

  ($e | map(select(.pool == "codex")))                                   as $co |
  ($e | map(select(.pool == "spark")))                                   as $sp |
  ($e | map(select(.pool != "codex" and .pool != "spark")))              as $cl |

  {
    total:            ($e  | length),
    claude_tokens:    ($cl | map(.tokens // 0) | add // 0),
    codex_tokens:     ($co | map(.tokens // 0) | add // 0),
    spark_tokens:     ($sp | map(.tokens // 0) | add // 0),
    codex_dispatches: ($co | length),
    claude_first_ep:  (if ($cl | length) > 1 then ($cl | map(._ep) | min) else 0 end),
    by_type: ($e | group_by(.type // "unknown") |
      map({key:(.[0].type // "unknown"), value:{count:length, tokens:(map(.tokens//0)|add//0)}}) |
      from_entries),
    by_session: ($e | group_by(.session // "?") |
      map({key:(.[0].session//"?"|.[0:10]), value:{count:length, tokens:(map(.tokens//0)|add//0)}}) |
      from_entries),
    skipped: $skipped
  }
' "$LOGFILE" 2>/dev/null ||
  echo '{"total":0,"claude_tokens":0,"codex_tokens":0,"spark_tokens":0,"codex_dispatches":0,"claude_first_ep":0,"by_type":{},"by_session":{},"skipped":0}')

_get() { printf '%s' "$_data" | jq -r ".$1"; }

_skipped=$(_get skipped)
_skipped="${_skipped:-0}"; [[ "$_skipped" == "null" ]] && _skipped=0
[[ "$_skipped" -gt 0 ]] && \
  printf '  (warning: %d malformed/incomplete line(s) skipped)\n' "$_skipped" >&2

_total=$(_get total)
_claude=$(_get claude_tokens)
_codex=$(_get codex_tokens)
_spark=$(_get spark_tokens)
_codex_dis=$(_get codex_dispatches)
_claude_first=$(_get claude_first_ep)
_total_tok=$((_claude + _codex + _spark))

# Load calibration
_known_limit=0
_rl_event_count=0
if [[ -f "$CALIB_FILE" ]]; then
  _calib_result=$(jq -r '{l:(.known_limit_tokens//0),e:(.rate_limit_events//[]|length)}' "$CALIB_FILE" 2>/dev/null || echo "")
  if [[ -z "$_calib_result" ]]; then
    printf '  (warning: calibration file malformed)\n' >&2
  else
    _known_limit=$(printf '%s' "$_calib_result" | jq -r '.l')
    _rl_event_count=$(printf '%s' "$_calib_result" | jq -r '.e')
  fi
fi

# Number formatting: insert commas every 3 digits (pure bash, no locale dependency)
_fmt() {
  local n="${1:-0}" result="" neg=""
  [[ "$n" =~ ^-(.*)$ ]] && neg="-" && n="${BASH_REMATCH[1]}"
  local len=${#n}
  for (( i=0; i<len; i++ )); do
    result="${result}${n:$i:1}"
    local rem=$(( (len - i - 1) % 3 ))
    [[ $rem -eq 0 && $i -lt $((len - 1)) ]] && result="${result},"
  done
  printf '%s' "${neg}${result}"
}

# ── Output ──────────────────────────────────────────────────────────────
echo '═══════════════════════════════════════════════'
echo ' Claude Code Usage Estimator'
echo '═══════════════════════════════════════════════'
printf ' Window : %s\n' "$LABEL"
printf ' Entries: %d\n' "$_total"
printf ' Claude  : %s tokens  (~%sk)\n' "$(_fmt "$_claude")" "$((_claude / 1000))"
printf ' Codex   : %s tokens  (%d logged)  [separate quota]\n' "$(_fmt "$_codex")" "$_codex_dis"
[[ "$_spark" -gt 0 ]] && printf ' Spark   : %s tokens  [separate quota]\n' "$(_fmt "$_spark")"
printf ' Total   : %s tokens  (~%sk)\n' "$(_fmt "$_total_tok")" "$((_total_tok / 1000))"

if [[ "$_known_limit" -gt 0 ]]; then
  _pct=$((_claude * 100 / _known_limit))
  _remaining=$((_known_limit > _claude ? _known_limit - _claude : 0))
  _bar=""
  _bar_filled=$((_pct / 5)); [[ $_bar_filled -gt 20 ]] && _bar_filled=20
  for ((i=0; i<20; i++)); do
    [[ $i -lt $_bar_filled ]] && _bar="${_bar}█" || _bar="${_bar}░"
  done
  printf ' Limit  : %s tokens (calibrated)\n' "$(_fmt "$_known_limit")"
  printf ' Used   : [%s] %d%%\n' "$_bar" "$_pct"
  printf ' Remain : ~%s tokens\n' "$(_fmt "$_remaining")"
  if [[ "$_claude" -gt 0 && "$_claude_first" -gt 0 ]]; then
    _elapsed_s=$((NOW_EPOCH - _claude_first)); [[ $_elapsed_s -le 0 ]] && _elapsed_s=1
    _rate_ph=$((_claude * 3600 / _elapsed_s))
    _rem_min=0
    [[ $_rate_ph -gt 0 ]] && _rem_min=$((_remaining * 60 / _rate_ph))
    printf ' Rate   : ~%dk tokens/hour at current pace\n' "$((_rate_ph / 1000))"
    printf ' Est.   : ~%d min remaining at this rate\n' "$_rem_min"
  fi
else
  printf ' Limit  : not yet calibrated\n'
  if [[ "$_claude" -gt 0 ]]; then
    echo '  -> Edit ~/.claude/usage-calibration.json and set:'
    printf '       "known_limit_tokens": %d\n' "$_claude"
    echo '  -> Then re-run to see % used and estimated time remaining'
  else
    echo '  -> No Claude-pool log data in this window; calibrate after Claude usage is logged'
  fi
fi

# ── --remaining section ─────────────────────────────────────────────────
if [[ -n "$REMAINING_PCT" ]]; then
  [[ -n "$REMAINING_NOTE" ]] && printf '%s\n' "$REMAINING_NOTE" >&2
  echo
  echo '───────────────────────────────────────────────'
  echo ' Remaining Capacity Estimate'
  echo '───────────────────────────────────────────────'
  printf ' Remaining (from dashboard): %.1f%%\n' "$REMAINING_PCT"
  printf ' Tokens used (Claude pool) : %s\n' "$(_fmt "$_claude")"
  [[ "$_codex" -gt 0 || "$_spark" -gt 0 ]] && \
    printf ' Separate quota tokens     : Codex %s  Spark %s\n' "$(_fmt "$_codex")" "$(_fmt "$_spark")"

  _used_pct=$(jq -n --argjson r "$REMAINING_PCT" '100 - $r')
  _inferred_total=0
  _calib_total=$_known_limit
  _remaining_tokens=0
  _remaining_computed=0   # 1 = we have a value (may be 0); 0 = couldn't compute
  _method=""

  if [[ "$_calib_total" -gt 0 ]]; then
    _remaining_tokens=$(jq -n --argjson l "$_calib_total" --argjson p "$REMAINING_PCT" \
      '($l * $p / 100) | floor | tostring' | tr -d '"')
    _method="from calibration"
    _remaining_computed=1
  fi

  if [[ "$_claude" -gt 0 ]]; then
    _inferred_total=$(jq -n --argjson tok "$_claude" --argjson used "$_used_pct" \
      'if $used > 0 then ($tok / ($used / 100)) | floor else 0 end')
    if [[ "$_calib_total" -eq 0 && "$_inferred_total" -gt 0 ]]; then
      _remaining_tokens=$(jq -n --argjson tot "$_inferred_total" --argjson p "$REMAINING_PCT" \
        '($tot * $p / 100) | floor')
      _method="inferred from log"
      _remaining_computed=1
    fi
  fi

  [[ "$_inferred_total" -gt 0 ]] && \
    printf ' Inferred total limit      : %s tokens\n' "$(_fmt "$_inferred_total")"
  [[ "$_calib_total" -gt 0 ]] && \
    printf ' Calibrated limit          : %s tokens\n' "$(_fmt "$_calib_total")"

  # Warn when inferred and calibrated totals diverge by >10%
  if [[ "$_inferred_total" -gt 0 && "$_calib_total" -gt 0 ]]; then
    _diff_pct=$(jq -n --argjson inf "$_inferred_total" --argjson cal "$_calib_total" \
      '(($inf - $cal | fabs) / $cal * 100) | floor')
    if [[ "$_diff_pct" -gt 10 ]]; then
      printf '  (note: inferred %s differs from calibrated %s by %d%% — consider recalibrating)\n' \
        "$(_fmt "$_inferred_total")" "$(_fmt "$_calib_total")" "$_diff_pct" >&2
    fi
  fi

  if [[ "$_remaining_computed" -eq 1 ]]; then
    printf ' Remaining tokens          : ~%s  [%s]\n' "$(_fmt "$_remaining_tokens")" "$_method"
    if [[ "$_remaining_tokens" -gt 0 && "$_claude" -gt 0 && "$_claude_first" -gt 0 ]]; then
      _elapsed_s=$((NOW_EPOCH - _claude_first)); [[ $_elapsed_s -le 0 ]] && _elapsed_s=1
      _rate_ph=$((_claude * 3600 / _elapsed_s))
      if [[ $_rate_ph -gt 0 ]]; then
        _rem_h_s=$((_remaining_tokens * 3600 / _rate_ph))
        _eta_epoch=$((NOW_EPOCH + _rem_h_s))
        _eta_str=$(date -u -d "@$_eta_epoch" +"%H:%M UTC" 2>/dev/null || \
                   date -u -r "$_eta_epoch" +"%H:%M UTC" 2>/dev/null || \
                   printf "~%dh" "$((_rem_h_s / 3600))")
        _rate_k=$(jq -n --argjson r "$_rate_ph" '$r / 1000 * 10 | round / 10')
        _rem_h_f=$(jq -n --argjson s "$_rem_h_s" '$s / 3600 * 10 | round / 10')
        printf ' Current rate              : ~%sk tokens/hr  (Claude only)\n' "$_rate_k"
        printf ' Estimated time remaining  : ~%s hrs  (until ~%s)\n' "$_rem_h_f" "$_eta_str"
      fi
    elif [[ "$_claude" -eq 0 ]]; then
      echo ' Estimated time remaining  : no Claude log data — rate unknown'
    else
      echo ' Estimated time remaining  : cannot estimate (need ≥2 data points for rate)'
    fi
  else
    printf ' Remaining tokens          : cannot estimate (0%% used and no calibration)\n'
    [[ "$_claude" -eq 0 ]] && echo ' Estimated time remaining  : no Claude log data — rate unknown'
  fi
fi

[[ -n "$REMAINING_NOTE" && -z "$REMAINING_PCT" ]] && printf '%s\n' "$REMAINING_NOTE" >&2

# ── By type ─────────────────────────────────────────────────────────────
_by_type=$(printf '%s' "$_data" | jq -r '
  .by_type | to_entries | sort_by(-.value.tokens)[] |
  "\(.key)\t\(.value.tokens)\t\(.value.count)"')
if [[ -n "$_by_type" ]]; then
  echo
  echo ' By operation type:'
  while IFS=$'\t' read -r _t _tok _cnt; do
    printf '   %-32s %9s  (%sx)\n' "$_t" "$(_fmt "$_tok")" "$_cnt"
  done <<< "$_by_type"
fi

# ── By session ──────────────────────────────────────────────────────────
_by_session=$(printf '%s' "$_data" | jq -r '
  .by_session | to_entries | sort_by(-.value.tokens)[] |
  "\(.key)\t\(.value.tokens)\t\(.value.count)"')
if [[ -n "$_by_session" ]]; then
  echo
  echo ' By session:'
  while IFS=$'\t' read -r _s _tok _cnt; do
    printf '   %-14s %9s  (%s ops)\n' "$_s" "$(_fmt "$_tok")" "$_cnt"
  done <<< "$_by_session"
fi

if [[ "$_rl_event_count" -gt 0 ]]; then
  echo
  printf ' Rate-limit events: %d\n' "$_rl_event_count"
fi

echo '═══════════════════════════════════════════════'
