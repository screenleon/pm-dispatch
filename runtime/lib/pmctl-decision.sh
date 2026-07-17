#!/usr/bin/env bash

_PMCTL_DECISION_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=runtime/lib/state-writer.sh
# shellcheck disable=SC1091
. "$_PMCTL_DECISION_LIB_DIR/state-writer.sh"
unset _PMCTL_DECISION_LIB_DIR

pmctl_decision_usage_add() {
  printf 'usage: pmctl decision add --date <YYYY-MM-DD> --title <TITLE> --path <PATH> [--closes <ID,ID>] [--tags <TAG,TAG>] [--evidence <REF,REF>] [--json]\n' >&2
}

pmctl_decision_require_jq() {
  if ! command -v jq >/dev/null 2>&1; then
    printf 'pmctl decision add: jq is required\n' >&2
    return 2
  fi
}

pmctl_decision_slug() {
  local title="${1:-}" slug
  slug="$(printf '%s' "$title" |
    tr '[:upper:]' '[:lower:]' |
    sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//' |
    cut -c1-40 |
    sed -E 's/-+$//')"
  printf '%s\n' "$slug"
}

pmctl_decision_project_dir() {
  local repo_root="${1:-}"
  _SW_REPO_ROOT="$repo_root" state_store_init || return $?
  _SW_REPO_ROOT="$repo_root" _sw_project_dir
}

# Validate a decision JSON line against core/schema/decision field rules.
pmctl_decision_validate_json() {
  local json="$1"
  local result
  result="$(printf '%s\n' "$json" | jq -r '
    if (.id | type != "string" or length == 0) then "missing required field: id"
    elif (.schema_version != 1) then "invalid schema_version: must be 1"
    elif (.title | type != "string" or length == 0) then "missing required field: title"
    elif (.date | type != "string" or test("^[0-9]{4}-[0-9]{2}-[0-9]{2}$") | not) then "invalid date format"
    elif (.decision_md_path | type != "string" or length == 0) then "missing required field: decision_md_path"
    else "ok"
    end' 2>/dev/null || true)"
  if [[ "$result" != "ok" ]]; then
    printf 'pmctl decision: schema validation failed: %s\n' "${result:-unknown}" >&2
    return 2
  fi
}

# Generate an event ID matching ^evt-[0-9]{8}T[0-9]{6}Z-[a-f0-9]{6}$.
_pmctl_decision_gen_event_id() {
  local ts hex
  ts="$(date -u +%Y%m%dT%H%M%SZ 2>/dev/null || date +%Y%m%dT%H%M%SZ)"
  hex="$(od -An -N3 -tx1 /dev/urandom 2>/dev/null | tr -d ' \n' | head -c6)"
  [[ -z "$hex" ]] && hex="000000"
  printf 'evt-%s-%s\n' "$ts" "$hex"
}

# Emit a decision.recorded event. Fail-loud per state-first contract.
_pmctl_emit_decision_event() {
  local repo_root="$1" decision_id="$2"
  local evt_id ts event_json
  evt_id="$(_pmctl_decision_gen_event_id)"
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date +%Y-%m-%dT%H:%M:%SZ)"
  event_json="$(jq -cn \
    --arg id "$evt_id" \
    --arg ts "$ts" \
    --arg subject_id "$decision_id" \
    '{schema_version:1,id:$id,ts:$ts,kind:"decision.recorded",subject_type:"decision",subject_id:$subject_id,actor:"pmctl"}')" || return $?
  _SW_REPO_ROOT="$repo_root" events_append "$event_json" || {
    printf 'pmctl decision: event decision.recorded for %s failed to append to events.jsonl\n' "$decision_id" >&2
    return 1
  }
}

# Inner function called under serialize_with_lock for decision add.
# Performs duplicate check, JSON build, schema validation, upsert, and event emit atomically.
_pmctl_decision_add_locked() {
  local decision_id="$1" date="$2" title="$3" path="$4" \
        closes="$5" tags="$6" evidence="$7" repo_root="$8"
  local decision_file json_line
  decision_file="$(_SW_REPO_ROOT="$repo_root" _sw_project_dir)/decisions/${decision_id}.json"
  # Duplicate check inside the lock so concurrent adds are serialized.
  if [[ -f "$decision_file" ]]; then
    printf 'pmctl decision add: decision already exists: %s\n' "$decision_id" >&2
    return 2
  fi
  json_line="$(jq -cn \
    --arg id "$decision_id" \
    --arg date "$date" \
    --arg title "$title" \
    --arg path "$path" \
    --arg closes "$closes" \
    --arg tags "$tags" \
    --arg evidence "$evidence" \
    'def csv_array($s): ($s | split(",") | map(select(. != "")));
     {schema_version:1,id:$id,date:$date,title:$title,decision_md_path:$path}
     | if $closes == "" then . else . + {closes:csv_array($closes)} end
     | if $tags == "" then . else . + {tags:csv_array($tags)} end
     | if $evidence == "" then . else . + {evidence:csv_array($evidence)} end')" || return $?
  pmctl_decision_validate_json "$json_line" || return $?
  _SW_REPO_ROOT="$repo_root" decision_upsert "$decision_id" "$json_line" || return $?
  # Rollback: if event append fails, remove the projection so retry can succeed.
  _pmctl_emit_decision_event "$repo_root" "$decision_id" || {
    if ! rm -f "$decision_file" 2>/dev/null; then
      printf 'pmctl decision add: cleanup FAILED for %s — projection row exists without decision.recorded; repair manually\n' "$decision_id" >&2
    else
      printf 'pmctl decision add: rolled back %s after event append failure\n' "$decision_id" >&2
    fi
    return 1
  }
}

pmctl_decision_add() {
  local repo_root="${1:-}" date="" title="" path="" closes="" tags="" evidence="" json=0
  local slug decision_id json_line proj_dir
  shift || true

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --date|--title|--path|--closes|--tags|--evidence)
        if [[ $# -lt 2 ]]; then
          printf 'pmctl decision add: missing value for %s\n' "$1" >&2
          pmctl_decision_usage_add
          return 2
        fi
        case "$1" in
          --date) date="$2" ;;
          --title) title="$2" ;;
          --path) path="$2" ;;
          --closes) closes="$2" ;;
          --tags) tags="$2" ;;
          --evidence) evidence="$2" ;;
        esac
        shift 2
        ;;
      --json)
        json=1
        shift
        ;;
      *)
        printf 'pmctl decision add: unknown flag: %s\n' "$1" >&2
        pmctl_decision_usage_add
        return 2
        ;;
    esac
  done

  pmctl_decision_require_jq || return $?
  if [[ -z "$date" || ! "$date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    printf 'pmctl decision add: missing or invalid --date\n' >&2
    return 2
  fi
  if [[ -z "$title" ]]; then
    printf 'pmctl decision add: missing --title\n' >&2
    return 2
  fi
  if [[ -z "$path" ]]; then
    printf 'pmctl decision add: missing --path\n' >&2
    return 2
  fi
  slug="$(pmctl_decision_slug "$title")"
  if [[ -z "$slug" ]]; then
    printf 'pmctl decision add: title does not produce a valid slug\n' >&2
    return 2
  fi
  decision_id="dec-${date}-${slug}"
  proj_dir="$(pmctl_decision_project_dir "$repo_root")" || return $?
  # Serialize duplicate check + write + event emit under the per-decision lock.
  serialize_with_lock "$proj_dir/decisions/${decision_id}" \
    _pmctl_decision_add_locked \
    "$decision_id" "$date" "$title" "$path" "$closes" "$tags" "$evidence" "$repo_root" || return $?
  # Re-read the written JSON for --json output (avoids rebuilding from args).
  if [[ "$json" -eq 1 ]]; then
    json_line="$(jq -c . "$proj_dir/decisions/${decision_id}.json")" || return $?
    printf '%s\n' "$json_line"
  else
    printf '%s  %s  %s\n' "$decision_id" "$title" "$path"
  fi
}
