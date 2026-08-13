#!/usr/bin/env bash

_PMCTL_TASK_LIB_DIR="${BASH_SOURCE[0]%/*}"
[[ "$_PMCTL_TASK_LIB_DIR" == "${BASH_SOURCE[0]}" ]] && _PMCTL_TASK_LIB_DIR=.
# shellcheck source=runtime/lib/pmctl-policy.sh
if ! declare -F pmctl_policy_contains >/dev/null 2>&1; then
  . "$_PMCTL_TASK_LIB_DIR/pmctl-policy.sh"
fi
_PMCTL_TASK_STATES_FILE="${_PMCTL_TASK_STATES_FILE:-$_PMCTL_TASK_LIB_DIR/../../core/policy/task-states.yaml}"
# shellcheck source=runtime/lib/state-writer.sh
# shellcheck disable=SC1091
. "$_PMCTL_TASK_LIB_DIR/state-writer.sh"
unset _PMCTL_TASK_LIB_DIR

pmctl_task_usage_list() {
  printf 'usage: pmctl task list [--state <STATE>] [--json]\n' >&2
}

pmctl_task_usage_show() {
  printf 'usage: pmctl task show <ID> [--json]\n' >&2
}

pmctl_task_usage_create() {
  printf 'usage: pmctl task create <ID> --title <TITLE> [--priority P1|P2|P3] [--epic <EPIC>] [--area <AREA>] [--backlog-ref <REF>] [--behavioral-units <N>] [--size-tier trivial|small|substantial]\n' >&2
}

pmctl_task_usage_update() {
  printf 'usage: pmctl task update <ID> [--title <TITLE>] [--state <STATE>] [--priority P1|P2|P3] [--epic <EPIC>] [--area <AREA>] [--backlog-ref <REF>] [--behavioral-units <N>] [--size-tier trivial|small|substantial]\n' >&2
}

pmctl_task_require_jq() {
  if ! command -v jq >/dev/null 2>&1; then
    printf 'pmctl task %s: jq is required\n' "${1:-}" >&2
    return 2
  fi
}

pmctl_task_valid_id() {
  [[ "${1:-}" =~ ^[A-Z]{1,4}-[0-9]+[a-z]?$ ]]
}

pmctl_task_valid_state() {
  pmctl_policy_contains "$_PMCTL_TASK_STATES_FILE" "${1:-}" states
}

pmctl_task_valid_priority() {
  case "${1:-}" in
    P1|P2|P3|"") return 0 ;;
    *) return 1 ;;
  esac
}

pmctl_task_valid_size_tier() {
  case "${1:-}" in
    trivial|small|substantial|"") return 0 ;;
    *) return 1 ;;
  esac
}

# Validate a task JSON line against core/schema/task.schema.json field rules.
pmctl_task_validate_json() {
  local json="$1"
  local result states_json
  states_json="$(pmctl_policy_values "$_PMCTL_TASK_STATES_FILE" states | jq -Rsc 'split("\n") | map(select(length > 0))')" || return 2
  result="$(printf '%s\n' "$json" | jq -r --argjson valid_states "$states_json" '
    if (.id | type != "string" or length == 0) then "missing required field: id"
    elif (.schema_version != 1) then "invalid schema_version: must be 1"
    elif (.title | type != "string" or length == 0 or length > 200) then "invalid title: must be non-empty string <= 200 chars"
    elif (.state | . as $s | $valid_states | index($s) == null) then "invalid state"
    elif (.created_ts | type != "string" or length == 0) then "missing required field: created_ts"
    elif (.priority != null and (.priority | . as $p | ["P1","P2","P3"] | index($p) == null)) then "invalid priority: must be P1, P2, P3, or absent"
    elif (.behavioral_units != null and (.behavioral_units | type != "number" or . < 0 or floor != .)) then "invalid behavioral_units: must be non-negative integer"
    elif (.size_tier != null and (.size_tier | . as $t | ["trivial","small","substantial"] | index($t) == null)) then "invalid size_tier: must be trivial, small, or substantial"
    else "ok"
    end' 2>/dev/null || true)"
  if [[ "$result" != "ok" ]]; then
    printf 'pmctl task: schema validation failed: %s\n' "${result:-unknown}" >&2
    return 2
  fi
}

pmctl_task_project_dir() {
  local repo_root="${1:-}"
  _SW_REPO_ROOT="$repo_root" state_store_init || return $?
  _SW_REPO_ROOT="$repo_root" _sw_project_dir
}

pmctl_task_human_line() {
  jq -r '[.id // "", .state // "", .title // ""] | @tsv' |
    while IFS=$'\t' read -r id state title; do
      printf '%s  %s  %s\n' "$id" "$state" "$title"
    done
}

pmctl_task_emit_files() {
  local tasks_dir="$1" state_filter="$2" json="$3" path
  [[ -d "$tasks_dir" ]] || return 0
  while IFS= read -r -d '' path; do
    if [[ -n "$state_filter" ]]; then
      if ! jq -e --arg state "$state_filter" '.state == $state' "$path" >/dev/null 2>&1; then
        continue
      fi
    fi
    if [[ "$json" -eq 1 ]]; then
      jq -c . "$path" || return $?
    else
      pmctl_task_human_line < "$path" || return $?
    fi
  done < <(find "$tasks_dir" -maxdepth 1 -type f -name '*.json' -print0 2>/dev/null | sort -z)
}

# Generate an event ID matching ^evt-[0-9]{8}T[0-9]{6}Z-[a-f0-9]{6}$.
_pmctl_gen_event_id() {
  local ts hex
  ts="$(date -u +%Y%m%dT%H%M%SZ 2>/dev/null || date +%Y%m%dT%H%M%SZ)"
  hex="$(od -An -N3 -tx1 /dev/urandom 2>/dev/null | tr -d ' \n' | head -c6)"
  [[ -z "$hex" ]] && hex="000000"
  printf 'evt-%s-%s\n' "$ts" "$hex"
}

# Emit a task event to events.jsonl. Fail-loud per state-first contract:
# projection write implies event write; caller fails if event cannot be appended.
_pmctl_emit_task_event() {
  local repo_root="$1" kind="$2" task_id="$3" from_state="${4:-}" to_state="${5:-}"
  local evt_id ts event_json
  evt_id="$(_pmctl_gen_event_id)"
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date +%Y-%m-%dT%H:%M:%SZ)"
  event_json="$(jq -cn \
    --arg id "$evt_id" \
    --arg ts "$ts" \
    --arg kind "$kind" \
    --arg subject_id "$task_id" \
    --arg from_state "$from_state" \
    --arg to_state "$to_state" \
    '{schema_version:1,id:$id,ts:$ts,kind:$kind,subject_type:"task",subject_id:$subject_id,actor:"pmctl"}
     | if ($from_state != "" and $to_state != "") then . + {payload:{from_state:$from_state,to_state:$to_state}} else . end')" || return $?
  _SW_REPO_ROOT="$repo_root" events_append "$event_json" || {
    printf 'pmctl task: event %s for %s failed to append to events.jsonl\n' "$kind" "$task_id" >&2
    return 1
  }
}

pmctl_task_list() {
  local repo_root="${1:-}" state_filter="" json=0 proj_dir
  shift || true

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --state)
        if [[ $# -lt 2 ]]; then
          printf 'pmctl task list: missing value for --state\n' >&2
          pmctl_task_usage_list
          return 2
        fi
        state_filter="$2"
        shift 2
        ;;
      --json)
        json=1
        shift
        ;;
      *)
        printf 'pmctl task list: unknown flag: %s\n' "$1" >&2
        pmctl_task_usage_list
        return 2
        ;;
    esac
  done

  pmctl_task_require_jq list || return $?
  if [[ -n "$state_filter" ]] && ! pmctl_task_valid_state "$state_filter"; then
    printf 'pmctl task list: invalid state: %s\n' "$state_filter" >&2
    return 2
  fi
  proj_dir="$(pmctl_task_project_dir "$repo_root")" || return $?
  pmctl_task_emit_files "$proj_dir/tasks" "$state_filter" "$json"
}

pmctl_task_show() {
  local repo_root="${1:-}" task_id="${2:-}" json=0 proj_dir task_file
  shift 2 || true

  if [[ -z "$task_id" ]]; then
    printf 'pmctl task show: missing task id\n' >&2
    pmctl_task_usage_show
    return 2
  fi
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --json)
        json=1
        shift
        ;;
      *)
        printf 'pmctl task show: unknown flag: %s\n' "$1" >&2
        pmctl_task_usage_show
        return 2
        ;;
    esac
  done

  pmctl_task_require_jq show || return $?
  if ! pmctl_task_valid_id "$task_id"; then
    printf 'pmctl task show: invalid task id: %s\n' "$task_id" >&2
    return 2
  fi
  proj_dir="$(pmctl_task_project_dir "$repo_root")" || return $?
  task_file="$proj_dir/tasks/${task_id}.json"
  if [[ ! -f "$task_file" ]]; then
    printf 'pmctl task show: task not found: %s\n' "$task_id" >&2
    return 2
  fi
  if [[ "$json" -eq 1 ]]; then
    jq -c . "$task_file"
  else
    pmctl_task_human_line < "$task_file"
  fi
}

# Inner function called under serialize_with_lock for task create.
# Performs duplicate check, JSON build, schema validation, upsert, event emit,
# and rollback atomically — all inside the per-task lock.
_pmctl_task_create_locked() {
  local task_id="$1" title="$2" created_ts="$3" priority="$4" \
        epic="$5" area="$6" backlog_ref="$7" repo_root="$8" \
        behavioral_units="${9:-}" size_tier="${10:-}"
  local task_file json_line
  task_file="$(_SW_REPO_ROOT="$repo_root" _sw_project_dir)/tasks/${task_id}.json"
  # Duplicate check inside the lock so concurrent creates are serialized.
  if [[ -f "$task_file" ]]; then
    printf 'pmctl task create: task already exists: %s (use task update to modify)\n' "$task_id" >&2
    return 2
  fi
  json_line="$(jq -cn \
    --arg id "$task_id" \
    --arg title "$title" \
    --arg created_ts "$created_ts" \
    --arg priority "$priority" \
    --arg epic "$epic" \
    --arg area "$area" \
    --arg backlog_ref "$backlog_ref" \
    --arg bu "$behavioral_units" \
    --arg st "$size_tier" \
    '{schema_version:1,id:$id,title:$title,state:"open",ticket_origin:"ad_hoc",created_ts:$created_ts}
     | if $priority == "" then . else . + {priority:$priority} end
     | if $epic == "" then . else . + {epic:$epic} end
     | if $area == "" then . else . + {area:$area} end
     | if $backlog_ref == "" then . else . + {backlog_ref:$backlog_ref} end
     | if $bu == "" then . else . + {behavioral_units:($bu | tonumber)} end
     | if $st == "" then . else . + {size_tier:$st} end')" || return $?
  pmctl_task_validate_json "$json_line" || return $?
  _SW_REPO_ROOT="$repo_root" task_upsert "$task_id" "$json_line" || return $?
  # Emit event inside the lock — keeps dup-check, projection write, event append,
  # and rollback in one serialized section, preventing create/update interleaving.
  _pmctl_emit_task_event "$repo_root" "task.created" "$task_id" || {
    if ! _SW_REPO_ROOT="$repo_root" task_delete "$task_id" 2>/dev/null; then
      printf 'pmctl task create: cleanup FAILED for %s — projection exists without task.created; repair manually\n' "$task_id" >&2
    else
      printf 'pmctl task create: rolled back %s after event append failure\n' "$task_id" >&2
    fi
    return 1
  }
}

pmctl_task_create() {
  local repo_root="${1:-}" task_id="${2:-}" title="" priority="" epic="" area="" backlog_ref=""
  local behavioral_units="" size_tier=""
  local created_ts proj_dir
  shift 2 || true

  if [[ -z "$task_id" ]]; then
    printf 'pmctl task create: missing task id\n' >&2
    pmctl_task_usage_create
    return 2
  fi
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --title|--priority|--epic|--area|--backlog-ref|--behavioral-units|--size-tier)
        if [[ $# -lt 2 ]]; then
          printf 'pmctl task create: missing value for %s\n' "$1" >&2
          pmctl_task_usage_create
          return 2
        fi
        case "$1" in
          --title) title="$2" ;;
          --priority) priority="$2" ;;
          --epic) epic="$2" ;;
          --area) area="$2" ;;
          --backlog-ref) backlog_ref="$2" ;;
          --behavioral-units) behavioral_units="$2" ;;
          --size-tier) size_tier="$2" ;;
        esac
        shift 2
        ;;
      *)
        printf 'pmctl task create: unknown flag: %s\n' "$1" >&2
        pmctl_task_usage_create
        return 2
        ;;
    esac
  done

  pmctl_task_require_jq create || return $?
  if ! pmctl_task_valid_id "$task_id"; then
    printf 'pmctl task create: invalid task id: %s\n' "$task_id" >&2
    return 2
  fi
  if [[ -z "$title" ]]; then
    printf 'pmctl task create: missing --title\n' >&2
    return 2
  fi
  if ! pmctl_task_valid_priority "$priority"; then
    printf 'pmctl task create: invalid --priority: %s (must be P1, P2, or P3)\n' "$priority" >&2
    return 2
  fi
  if [[ -n "$behavioral_units" ]] && ! [[ "$behavioral_units" =~ ^[0-9]+$ ]]; then
    printf 'pmctl task create: invalid --behavioral-units: %s (must be non-negative integer)\n' "$behavioral_units" >&2
    return 2
  fi
  if ! pmctl_task_valid_size_tier "$size_tier"; then
    printf 'pmctl task create: invalid --size-tier: %s (must be trivial, small, or substantial)\n' "$size_tier" >&2
    return 2
  fi
  proj_dir="$(pmctl_task_project_dir "$repo_root")" || return $?
  created_ts="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date +%Y-%m-%dT%H:%M:%SZ)"
  # Serialize dup-check + projection write + event emit + rollback under per-task lock.
  serialize_with_lock "$proj_dir/tasks/${task_id}" \
    _pmctl_task_create_locked \
    "$task_id" "$title" "$created_ts" "$priority" "$epic" "$area" "$backlog_ref" "$repo_root" \
    "$behavioral_units" "$size_tier" || return $?
  printf '%s\n' "$task_id"
}

# Inner function called under serialize_with_lock for task update.
# Reads existing JSON, applies patch, validates, and writes atomically.
_pmctl_task_update_locked() {
  local task_file="$1" updated_ts="$2" \
        set_title="$3" title="$4" \
        set_state="$5" state="$6" \
        set_priority="$7" priority="$8" \
        set_epic="$9" epic="${10}" \
        set_area="${11}" area="${12}" \
        set_backlog_ref="${13}" backlog_ref="${14}" \
        task_id="${15}" repo_root="${16}" \
        set_behavioral_units="${17:-0}" behavioral_units="${18:-}" \
        set_size_tier="${19:-0}" size_tier="${20:-}"
  local json_line old_state old_json
  # Capture old state and full JSON before patch for event emission and rollback.
  old_state="$(jq -r '.state // ""' "$task_file" 2>/dev/null || true)"
  old_json="$(cat "$task_file" 2>/dev/null)" || return $?
  json_line="$(jq -c \
    --arg title "$title" \
    --arg state "$state" \
    --arg priority "$priority" \
    --arg epic "$epic" \
    --arg area "$area" \
    --arg backlog_ref "$backlog_ref" \
    --argjson set_title "$set_title" \
    --argjson set_state "$set_state" \
    --argjson set_priority "$set_priority" \
    --argjson set_epic "$set_epic" \
    --argjson set_area "$set_area" \
    --argjson set_backlog_ref "$set_backlog_ref" \
    --argjson set_behavioral_units "$set_behavioral_units" \
    --arg behavioral_units "$behavioral_units" \
    --argjson set_size_tier "$set_size_tier" \
    --arg size_tier "$size_tier" \
    --arg updated_ts "$updated_ts" \
    '. | if $set_title == 1 then .title = $title else . end
       | if $set_state == 1 then .state = $state else . end
       | if $set_priority == 1 then (if $priority == "" then del(.priority) else .priority = $priority end) else . end
       | if $set_epic == 1 then .epic = $epic else . end
       | if $set_area == 1 then .area = $area else . end
       | if $set_backlog_ref == 1 then .backlog_ref = $backlog_ref else . end
       | if $set_behavioral_units == 1 then (if $behavioral_units == "" then del(.behavioral_units) else .behavioral_units = ($behavioral_units | tonumber) end) else . end
       | if $set_size_tier == 1 then (if $size_tier == "" then del(.size_tier) else .size_tier = $size_tier end) else . end
       | .updated_ts = $updated_ts' "$task_file")" || return $?
  # Validate patched JSON before writing — same boundary as create.
  pmctl_task_validate_json "$json_line" || return $?
  _SW_REPO_ROOT="$repo_root" task_upsert "$task_id" "$json_line" || return $?
  # Emit task.state_changed event when state actually changes. Rollback on failure.
  if [[ "$set_state" -eq 1 && "$state" != "$old_state" ]]; then
    _pmctl_emit_task_event "$repo_root" "task.state_changed" "$task_id" "$old_state" "$state" || {
      if ! _SW_REPO_ROOT="$repo_root" task_upsert "$task_id" "$old_json" 2>/dev/null; then
        printf 'pmctl task update: rollback FAILED for %s — projection is ahead of events.jsonl; repair manually\n' "$task_id" >&2
      else
        printf 'pmctl task update: rolled back state for %s after event append failure\n' "$task_id" >&2
      fi
      return 1
    }
  fi
}

# ---------------------------------------------------------------------------
# claim / dispatch / status / review — semantic lifecycle operations
# ---------------------------------------------------------------------------

# Emit a task event with an arbitrary pre-built payload JSON object.
# Complements _pmctl_emit_task_event (from_state/to_state pairs only) for
# richer events (task.dispatched, task.reviewed) that carry domain-specific fields.
_pmctl_emit_task_event_payload() {
  local repo_root="$1" kind="$2" task_id="$3" payload_json="${4:-null}"
  local evt_id ts event_json
  evt_id="$(_pmctl_gen_event_id)"
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date +%Y-%m-%dT%H:%M:%SZ)"
  event_json="$(jq -cn \
    --arg id "$evt_id" --arg ts "$ts" --arg kind "$kind" \
    --arg subject_id "$task_id" --argjson payload "$payload_json" \
    '{schema_version:1,id:$id,ts:$ts,kind:$kind,subject_type:"task",subject_id:$subject_id,actor:"pmctl",payload:$payload}')" || return $?
  _SW_REPO_ROOT="$repo_root" events_append "$event_json" || {
    printf 'pmctl task: event %s for %s failed to append to events.jsonl\n' "$kind" "$task_id" >&2
    return 1
  }
}

# Enforce the documented lifecycle FSM (open → claimed → in-progress → done) for
# the semantic commands. Called inside the per-task lock so the from-state read
# and the rejection decision are atomic with the write that follows. Returns 2
# (usage-class) on a disallowed transition; `task update --state` remains the raw
# override for out-of-band corrections (blocked/dropped, re-open, etc.).
_pmctl_task_require_state() {
  local cmd="$1" task_id="$2" actual="$3" expected="$4"
  if [[ "$actual" != "$expected" ]]; then
    printf 'pmctl task %s: invalid transition: %s is in state %s, expected %s\n' \
      "$cmd" "$task_id" "${actual:-<none>}" "$expected" >&2
    return 2
  fi
}

# Derive size tier from task JSON file.
# Returns: trivial, small, substantial, or "" (unknown — no gate applied).
# Priority: explicit size_tier field > behavioral_units derivation.
_pmctl_task_derive_tier() {
  local task_file="$1"
  local tier units
  tier="$(jq -r '.size_tier // ""' "$task_file" 2>/dev/null || true)"
  if [[ -n "$tier" ]]; then printf '%s' "$tier"; return; fi
  units="$(jq -r 'if (.behavioral_units | type) == "number" then .behavioral_units else "" end' \
    "$task_file" 2>/dev/null || true)"
  [[ -z "$units" ]] && return
  if [[ "$units" -le 1 ]]; then printf 'trivial'
  elif [[ "$units" -eq 2 ]]; then printf 'small'
  else printf 'substantial'
  fi
}

# --- task claim ---

pmctl_task_usage_claim() {
  printf 'usage: pmctl task claim <ID>\n' >&2
}

_pmctl_task_claim_locked() {
  local task_file="$1" updated_ts="$2" task_id="$3" repo_root="$4"
  local old_state old_json json_line
  old_state="$(jq -r '.state // ""' "$task_file" 2>/dev/null || true)"
  _pmctl_task_require_state claim "$task_id" "$old_state" "open" || return $?
  old_json="$(cat "$task_file" 2>/dev/null)" || return $?
  json_line="$(jq -c --arg ts "$updated_ts" \
    '.state = "claimed" | .updated_ts = $ts' "$task_file")" || return $?
  pmctl_task_validate_json "$json_line" || return $?
  _SW_REPO_ROOT="$repo_root" task_upsert "$task_id" "$json_line" || return $?
  local payload
  payload="$(jq -cn --arg f "$old_state" --arg t "claimed" '{from_state:$f,to_state:$t}')"
  _pmctl_emit_task_event_payload "$repo_root" "task.claimed" "$task_id" "$payload" || {
    _SW_REPO_ROOT="$repo_root" task_upsert "$task_id" "$old_json" 2>/dev/null || \
      printf 'pmctl task claim: rollback FAILED for %s — repair manually\n' "$task_id" >&2
    return 1
  }
}

pmctl_task_claim() {
  local repo_root="${1:-}" task_id="${2:-}"
  shift 2 || true
  pmctl_task_require_jq claim || return $?
  if [[ -z "$task_id" ]]; then
    printf 'pmctl task claim: missing task id\n' >&2
    pmctl_task_usage_claim; return 2
  fi
  while [[ $# -gt 0 ]]; do
    printf 'pmctl task claim: unexpected argument: %s\n' "$1" >&2
    pmctl_task_usage_claim; return 2
  done
  if ! pmctl_task_valid_id "$task_id"; then
    printf 'pmctl task claim: invalid task id: %s\n' "$task_id" >&2; return 2
  fi
  local proj_dir task_file updated_ts
  proj_dir="$(pmctl_task_project_dir "$repo_root")" || return $?
  task_file="${proj_dir%/}/tasks/${task_id}.json"
  if [[ ! -f "$task_file" ]]; then
    printf 'pmctl task claim: task not found: %s\n' "$task_id" >&2; return 2
  fi
  updated_ts="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date +%Y-%m-%dT%H:%M:%SZ)"
  serialize_with_lock "${proj_dir%/}/tasks/${task_id}" \
    _pmctl_task_claim_locked "$task_file" "$updated_ts" "$task_id" "$repo_root" || return $?
  printf '%s\n' "$task_id"
}

# --- task dispatch ---

pmctl_task_usage_dispatch_sub() {
  printf 'usage: pmctl task dispatch <ID> --agent <AGENT> [--brief-file <PATH>]\n' >&2
}

_pmctl_task_dispatch_sub_locked() {
  local task_file="$1" updated_ts="$2" task_id="$3" repo_root="$4" \
        agent="$5" brief_file="$6"
  local old_state old_json json_line tier
  old_state="$(jq -r '.state // ""' "$task_file" 2>/dev/null || true)"
  _pmctl_task_require_state dispatch "$task_id" "$old_state" "claimed" || return $?
  # Lifecycle gate (warning mode): warn on substantial tasks; non-blocking.
  tier="$(_pmctl_task_derive_tier "$task_file")"
  if [[ "$tier" == "substantial" ]]; then
    printf 'WARNING: %s is a substantial task — /pre-impl design artifact recommended before dispatch\n' \
      "$task_id" >&2
    _pmctl_emit_task_event_payload "$repo_root" "task.lifecycle.warn" "$task_id" \
      "$(jq -cn --arg r "substantial_task" --arg t "substantial" '{reason:$r,size_tier:$t}')" \
      2>/dev/null || true
  fi
  old_json="$(cat "$task_file" 2>/dev/null)" || return $?
  json_line="$(jq -c \
    --arg ts "$updated_ts" --arg agent "$agent" --arg brief "$brief_file" \
    '.state = "in-progress" | .updated_ts = $ts | .dispatched_to = $agent
     | if $brief != "" then .brief_file = $brief else . end' "$task_file")" || return $?
  pmctl_task_validate_json "$json_line" || return $?
  _SW_REPO_ROOT="$repo_root" task_upsert "$task_id" "$json_line" || return $?
  local payload
  payload="$(jq -cn --arg f "$old_state" --arg t "in-progress" --arg a "$agent" \
    '{from_state:$f,to_state:$t,agent:$a}')"
  _pmctl_emit_task_event_payload "$repo_root" "task.dispatched" "$task_id" "$payload" || {
    _SW_REPO_ROOT="$repo_root" task_upsert "$task_id" "$old_json" 2>/dev/null || \
      printf 'pmctl task dispatch: rollback FAILED for %s — repair manually\n' "$task_id" >&2
    return 1
  }
}

pmctl_task_dispatch_sub() {
  local repo_root="${1:-}" task_id="${2:-}" agent="" brief_file=""
  shift 2 || true
  pmctl_task_require_jq dispatch || return $?
  if [[ -z "$task_id" ]]; then
    printf 'pmctl task dispatch: missing task id\n' >&2
    pmctl_task_usage_dispatch_sub; return 2
  fi
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --agent)
        [[ $# -lt 2 ]] && { printf 'pmctl task dispatch: missing value for --agent\n' >&2; return 2; }
        agent="$2"; shift 2 ;;
      --brief-file)
        [[ $# -lt 2 ]] && { printf 'pmctl task dispatch: missing value for --brief-file\n' >&2; return 2; }
        brief_file="$2"; shift 2 ;;
      *)
        printf 'pmctl task dispatch: unknown flag: %s\n' "$1" >&2
        pmctl_task_usage_dispatch_sub; return 2 ;;
    esac
  done
  if ! pmctl_task_valid_id "$task_id"; then
    printf 'pmctl task dispatch: invalid task id: %s\n' "$task_id" >&2; return 2
  fi
  if [[ -z "$agent" ]]; then
    printf 'pmctl task dispatch: missing --agent\n' >&2
    pmctl_task_usage_dispatch_sub; return 2
  fi
  local proj_dir task_file updated_ts
  proj_dir="$(pmctl_task_project_dir "$repo_root")" || return $?
  task_file="${proj_dir%/}/tasks/${task_id}.json"
  if [[ ! -f "$task_file" ]]; then
    printf 'pmctl task dispatch: task not found: %s\n' "$task_id" >&2; return 2
  fi
  updated_ts="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date +%Y-%m-%dT%H:%M:%SZ)"
  serialize_with_lock "${proj_dir%/}/tasks/${task_id}" \
    _pmctl_task_dispatch_sub_locked "$task_file" "$updated_ts" "$task_id" "$repo_root" \
    "$agent" "$brief_file" || return $?
  printf '%s\n' "$task_id"
}

# --- task status ---

pmctl_task_usage_status() {
  printf 'usage: pmctl task status <ID> [--json]\n' >&2
}

pmctl_task_status() {
  local repo_root="${1:-}" task_id="${2:-}" json=0
  shift 2 || true
  pmctl_task_require_jq status || return $?
  if [[ -z "$task_id" ]]; then
    printf 'pmctl task status: missing task id\n' >&2
    pmctl_task_usage_status; return 2
  fi
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --json) json=1; shift ;;
      *)
        printf 'pmctl task status: unknown flag: %s\n' "$1" >&2
        pmctl_task_usage_status; return 2 ;;
    esac
  done
  if ! pmctl_task_valid_id "$task_id"; then
    printf 'pmctl task status: invalid task id: %s\n' "$task_id" >&2; return 2
  fi
  local proj_dir task_file events_file
  proj_dir="$(pmctl_task_project_dir "$repo_root")" || return $?
  task_file="${proj_dir%/}/tasks/${task_id}.json"
  if [[ ! -f "$task_file" ]]; then
    printf 'pmctl task status: task not found: %s\n' "$task_id" >&2; return 2
  fi
  events_file="${proj_dir%/}/events.jsonl"
  if [[ "$json" -eq 1 ]]; then
    local task_json events_arr
    task_json="$(jq -c . "$task_file")"
    if [[ -f "$events_file" ]]; then
      events_arr="$(jq -c --arg id "$task_id" \
        'select(.subject_id == $id)' "$events_file" | tail -5 | jq -sc '.')"
    else
      events_arr="[]"
    fi
    jq -cn --argjson task "$task_json" --argjson events "$events_arr" \
      '{task:$task,recent_events:$events}'
  else
    pmctl_task_human_line < "$task_file"
    if [[ -f "$events_file" ]]; then
      local evts
      evts="$(jq -r --arg id "$task_id" \
        'select(.subject_id == $id) | "\(.ts)  \(.kind)"' "$events_file" | tail -5)"
      if [[ -n "$evts" ]]; then
        printf 'recent events:\n'
        while IFS= read -r line; do
          printf '  %s\n' "$line"
        done <<< "$evts"
      fi
    fi
  fi
}

# --- task review ---

pmctl_task_usage_review() {
  printf 'usage: pmctl task review <ID> [--result pass|fail|partial] [--note <TEXT>]\n' >&2
}

_pmctl_task_valid_review_result() {
  case "${1:-}" in
    pass|fail|partial|"") return 0 ;;
    *) return 1 ;;
  esac
}

_pmctl_task_review_locked() {
  local task_file="$1" updated_ts="$2" task_id="$3" repo_root="$4" \
        result="$5" note="$6"
  local old_state old_json json_line
  old_state="$(jq -r '.state // ""' "$task_file" 2>/dev/null || true)"
  _pmctl_task_require_state review "$task_id" "$old_state" "in-progress" || return $?
  old_json="$(cat "$task_file" 2>/dev/null)" || return $?
  json_line="$(jq -c \
    --arg ts "$updated_ts" --arg result "$result" --arg note "$note" \
    '.state = "done" | .updated_ts = $ts
     | if $result != "" then .review_result = $result else . end
     | if $note != "" then .review_note = $note else . end' "$task_file")" || return $?
  pmctl_task_validate_json "$json_line" || return $?
  _SW_REPO_ROOT="$repo_root" task_upsert "$task_id" "$json_line" || return $?
  local payload
  payload="$(jq -cn --arg f "$old_state" --arg t "done" --arg r "$result" \
    '{from_state:$f,to_state:$t} | if $r != "" then . + {result:$r} else . end')"
  _pmctl_emit_task_event_payload "$repo_root" "task.reviewed" "$task_id" "$payload" || {
    _SW_REPO_ROOT="$repo_root" task_upsert "$task_id" "$old_json" 2>/dev/null || \
      printf 'pmctl task review: rollback FAILED for %s — repair manually\n' "$task_id" >&2
    return 1
  }
}

pmctl_task_review() {
  local repo_root="${1:-}" task_id="${2:-}" result="" note=""
  shift 2 || true
  pmctl_task_require_jq review || return $?
  if [[ -z "$task_id" ]]; then
    printf 'pmctl task review: missing task id\n' >&2
    pmctl_task_usage_review; return 2
  fi
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --result)
        [[ $# -lt 2 ]] && { printf 'pmctl task review: missing value for --result\n' >&2; return 2; }
        result="$2"; shift 2 ;;
      --note)
        [[ $# -lt 2 ]] && { printf 'pmctl task review: missing value for --note\n' >&2; return 2; }
        note="$2"; shift 2 ;;
      *)
        printf 'pmctl task review: unknown flag: %s\n' "$1" >&2
        pmctl_task_usage_review; return 2 ;;
    esac
  done
  if ! pmctl_task_valid_id "$task_id"; then
    printf 'pmctl task review: invalid task id: %s\n' "$task_id" >&2; return 2
  fi
  if ! _pmctl_task_valid_review_result "$result"; then
    printf 'pmctl task review: invalid --result: %s (want pass|fail|partial)\n' "$result" >&2; return 2
  fi
  local proj_dir task_file updated_ts
  proj_dir="$(pmctl_task_project_dir "$repo_root")" || return $?
  task_file="${proj_dir%/}/tasks/${task_id}.json"
  if [[ ! -f "$task_file" ]]; then
    printf 'pmctl task review: task not found: %s\n' "$task_id" >&2; return 2
  fi
  updated_ts="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date +%Y-%m-%dT%H:%M:%SZ)"
  serialize_with_lock "${proj_dir%/}/tasks/${task_id}" \
    _pmctl_task_review_locked "$task_file" "$updated_ts" "$task_id" "$repo_root" \
    "$result" "$note" || return $?
  printf '%s\n' "$task_id"
}

pmctl_task_update() {
  local repo_root="${1:-}" task_id="${2:-}" title="" state="" priority="" epic="" area="" backlog_ref=""
  local behavioral_units="" size_tier=""
  local set_title=0 set_state=0 set_priority=0 set_epic=0 set_area=0 set_backlog_ref=0
  local set_behavioral_units=0 set_size_tier=0
  local proj_dir task_file updated_ts
  shift 2 || true

  if [[ -z "$task_id" ]]; then
    printf 'pmctl task update: missing task id\n' >&2
    pmctl_task_usage_update
    return 2
  fi
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --title|--state|--priority|--epic|--area|--backlog-ref|--behavioral-units|--size-tier)
        if [[ $# -lt 2 ]]; then
          printf 'pmctl task update: missing value for %s\n' "$1" >&2
          pmctl_task_usage_update
          return 2
        fi
        case "$1" in
          --title) title="$2"; set_title=1 ;;
          --state) state="$2"; set_state=1 ;;
          --priority) priority="$2"; set_priority=1 ;;
          --epic) epic="$2"; set_epic=1 ;;
          --area) area="$2"; set_area=1 ;;
          --backlog-ref) backlog_ref="$2"; set_backlog_ref=1 ;;
          --behavioral-units) behavioral_units="$2"; set_behavioral_units=1 ;;
          --size-tier) size_tier="$2"; set_size_tier=1 ;;
        esac
        shift 2
        ;;
      *)
        printf 'pmctl task update: unknown flag: %s\n' "$1" >&2
        pmctl_task_usage_update
        return 2
        ;;
    esac
  done

  pmctl_task_require_jq update || return $?
  if ! pmctl_task_valid_id "$task_id"; then
    printf 'pmctl task update: invalid task id: %s\n' "$task_id" >&2
    return 2
  fi
  # task update --state is a raw administrative edit: any valid enum value is accepted
  # regardless of current state. No FSM enforcement; lifecycle gates belong in the PM layer.
  if [[ "$set_state" -eq 1 ]] && ! pmctl_task_valid_state "$state"; then
    printf 'pmctl task update: invalid state: %s\n' "$state" >&2
    return 2
  fi
  if [[ "$set_priority" -eq 1 ]] && ! pmctl_task_valid_priority "$priority"; then
    printf 'pmctl task update: invalid --priority: %s (must be P1, P2, or P3)\n' "$priority" >&2
    return 2
  fi
  if [[ "$set_behavioral_units" -eq 1 && -n "$behavioral_units" ]] && ! [[ "$behavioral_units" =~ ^[0-9]+$ ]]; then
    printf 'pmctl task update: invalid --behavioral-units: %s (must be non-negative integer)\n' "$behavioral_units" >&2
    return 2
  fi
  if [[ "$set_size_tier" -eq 1 ]] && ! pmctl_task_valid_size_tier "$size_tier"; then
    printf 'pmctl task update: invalid --size-tier: %s (must be trivial, small, or substantial)\n' "$size_tier" >&2
    return 2
  fi
  if [[ "$set_title$set_state$set_priority$set_epic$set_area$set_backlog_ref$set_behavioral_units$set_size_tier" == "00000000" ]]; then
    printf 'pmctl task update: no fields to update\n' >&2
    return 2
  fi
  proj_dir="$(pmctl_task_project_dir "$repo_root")" || return $?
  task_file="$proj_dir/tasks/${task_id}.json"
  if [[ ! -f "$task_file" ]]; then
    printf 'pmctl task update: task not found: %s\n' "$task_id" >&2
    return 2
  fi
  updated_ts="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date +%Y-%m-%dT%H:%M:%SZ)"
  serialize_with_lock "$proj_dir/tasks/${task_id}" \
    _pmctl_task_update_locked \
    "$task_file" "$updated_ts" \
    "$set_title" "$title" "$set_state" "$state" \
    "$set_priority" "$priority" "$set_epic" "$epic" \
    "$set_area" "$area" "$set_backlog_ref" "$backlog_ref" \
    "$task_id" "$repo_root" \
    "$set_behavioral_units" "$behavioral_units" "$set_size_tier" "$size_tier" || return $?
  printf '%s\n' "$task_id"
}
