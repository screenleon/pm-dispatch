#!/usr/bin/env bash
# Regression tests for the per-prompt hot path of a state write (CC-690, issue #741): the project-key memo
# in state-paths.sh and the process-light usage event in pmctl-context.sh. Both must give the same bytes and
# the same keys as the code they replaced, and neither may serve a stale answer.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=tests/lib/test-harness.sh
. "$SCRIPT_DIR/../lib/test-harness.sh"
th_init "$@"

# git_repo <dir>: a fresh repository with one commit.
git_repo() {
  mkdir -p "$1"
  git -C "$1" init -q .
  git -C "$1" -c user.name=t -c user.email=t@example.invalid commit -q --allow-empty -m init
}

case_key_memo_matches_the_uncached_key() {
  local name="project key: the memoised key equals the computed key, in the parent shell and in a subshell"
  should_run "$name" || return 0
  local got
  got="$(bash -c '
    export _SW_REPO_ROOT="$1"
    . "$2/runtime/lib/state-writer.sh"
    fresh="$(_sw_project_key)"
    _sw_project_key_var filled
    cached="$(_sw_project_key)"
    [[ -n "$fresh" && "$fresh" == "$filled" && "$filled" == "$cached" ]] && echo equal || echo "differ: $fresh $filled $cached"
  ' _ "$REPO_ROOT" "$REPO_ROOT" 2>&1)" || true
  if [[ "$got" == equal ]]; then
    pass "$name"
  else
    fail "$name" "$got"
  fi
}

case_key_memo_starts_no_process() {
  local name="project key: once filled, a later call starts no git process"
  should_run "$name" || return 0
  local stubs="$tmp_root/stubs-nogit" marker="$tmp_root/git-was-called" got
  mkdir -p "$stubs"
  printf '#!/bin/sh\necho called >> "%s"\nexit 1\n' "$marker" > "$stubs/git"
  chmod +x "$stubs/git"
  rm -f "$marker"
  got="$(bash -c '
    export _SW_REPO_ROOT="$1"
    . "$2/runtime/lib/state-writer.sh"
    _sw_project_key_var filled
    PATH="$3:$PATH"
    again="$(_sw_project_key)"
    [[ "$again" == "$filled" ]] && echo same || echo "changed: $again"
  ' _ "$REPO_ROOT" "$REPO_ROOT" "$stubs" 2>&1)" || true
  if [[ "$got" == same && ! -e "$marker" ]]; then
    pass "$name"
  else
    fail "$name" "got=$got git-called=$([[ -e "$marker" ]] && echo yes || echo no)"
  fi
}

case_key_memo_follows_repo_root_and_cwd() {
  local name="project key: the memo is dropped when _SW_REPO_ROOT or the working directory changes"
  should_run "$name" || return 0
  local repo_a="$tmp_root/key-repo-a" repo_b="$tmp_root/key-repo-b" got
  git_repo "$repo_a"
  git_repo "$repo_b"
  got="$(bash -c '
    . "$1/runtime/lib/state-writer.sh"
    export _SW_REPO_ROOT="$2"
    _sw_project_key_var ka
    export _SW_REPO_ROOT="$3"
    kb="$(_sw_project_key)"
    unset _SW_REPO_ROOT
    cd "$2"; _sw_project_key_var kc
    cd "$3"; kd="$(_sw_project_key)"
    [[ "$ka" != "$kb" && "$kc" == "$ka" && "$kd" == "$kb" ]] && echo ok || echo "ka=$ka kb=$kb kc=$kc kd=$kd"
  ' _ "$REPO_ROOT" "$repo_a" "$repo_b" 2>&1)" || true
  if [[ "$got" == ok ]]; then
    pass "$name"
  else
    fail "$name" "$got"
  fi
}

case_key_memo_never_stores_the_global_fallback() {
  local name="project key: the global fallback is not memoised, so a directory that becomes a repository is re-read"
  should_run "$name" || return 0
  local dir="$tmp_root/key-later-repo" got
  mkdir -p "$dir"
  got="$(bash -c '
    . "$1/runtime/lib/state-writer.sh"
    unset _SW_REPO_ROOT
    cd "$2"
    _sw_project_key_var before
    git init -q .
    git -c user.name=t -c user.email=t@example.invalid commit -q --allow-empty -m init
    after="$(_sw_project_key)"
    [[ "$before" == global && "$after" != global && -n "$after" ]] && echo ok || echo "before=$before after=$after"
  ' _ "$REPO_ROOT" "$dir" 2>&1)" || true
  if [[ "$got" == ok ]]; then
    pass "$name"
  else
    fail "$name" "$got"
  fi
}

# emit_event <kind> <query> <hits>: run _ctx_emit_usage_event with events_append replaced by a function that
# saves its argument (the real one's output is swallowed by the caller). Prints the line, or nothing when no
# event was appended.
emit_event() {
  local out="$tmp_root/emitted.$$.$RANDOM"
  : > "$out"
  bash -c '
    . "$1/runtime/lib/pmctl-context.sh"
    state_store_init() { :; }
    sink="$5"
    events_append() { printf "%s\n" "$1" > "$sink"; }
    _ctx_emit_warn() { :; }
    _ctx_emit_usage_event "$2" x "$3" "$4"
  ' _ "$REPO_ROOT" "$1" "$2" "$3" "$out" 2>/dev/null || true
  cat "$out"
  rm -f "$out"
}

# reference_event <line>: the event the jq program of the previous implementation builds for the same id,
# timestamp, kind, query and count.
reference_event() {
  local line="$1" id ts kind query hits
  id="$(jq -r .id <<< "$line")"; ts="$(jq -r .ts <<< "$line")"; kind="$(jq -r .kind <<< "$line")"
  query="$(jq -r .payload.query <<< "$line")"; hits="$(jq -r .payload.hits <<< "$line")"
  jq -cn --arg id "$id" --arg ts "$ts" --arg kind "$kind" --arg query "$query" --argjson hits "$hits" \
    '{schema_version:1,id:$id,ts:$ts,kind:$kind,
      subject_type:"context",subject_id:("ctx-"+ $id),
      actor:"pmctl",
      payload:{query:$query,hits:$hits}}'
}

case_usage_event_bytes_match_the_jq_program() {
  local name="usage event: the directly formatted event is byte-identical to the jq program's"
  should_run "$name" || return 0
  local line ref bad="" kind hits
  for kind in context.prompt_scanned context.queried; do
    for hits in 0 3 12; do
      line="$(emit_event "$kind" "" "$hits")"
      ref="$(reference_event "$line")"
      [[ -n "$line" && "$line" == "$ref" ]] || bad="$bad [$kind/$hits: got=$line ref=$ref]"
    done
  done
  if [[ -z "$bad" ]]; then
    pass "$name"
  else
    fail "$name" "$bad"
  fi
}

case_usage_event_query_text_still_goes_through_jq() {
  local name="usage event: query text with quotes and backslashes is escaped, not interpolated"
  should_run "$name" || return 0
  local line got query='say "hi" \ and é'
  line="$(emit_event context.queried "$query" 2)"
  got="$(jq -r '.payload.query' <<< "$line" 2>/dev/null || true)"
  if [[ -n "$line" && "$got" == "$query" ]]; then
    pass "$name"
  else
    fail "$name" "line=$line got=$got"
  fi
}

case_usage_event_odd_counts_behave_as_before() {
  local name="usage event: a count jq reads as a number is kept, one it rejects appends nothing"
  should_run "$name" || return 0
  local padded junk
  # "07" is not the plain integer the direct path accepts, so the jq program decides, as it always did.
  padded="$(emit_event context.queried "" "07")"
  junk="$(emit_event context.queried "" "abc")"
  if [[ "$(jq -r '.payload.hits' <<< "$padded" 2>/dev/null || true)" == 7 && -z "$junk" ]]; then
    pass "$name"
  else
    fail "$name" "padded=$padded junk=$junk"
  fi
}

case_usage_event_timestamp_is_utc_in_any_zone() {
  local name="usage event: ts and the id stamp are UTC, whatever TZ the process runs in"
  should_run "$name" || return 0
  local line ts id stamp want_ts want_stamp epoch
  line="$(TZ=JST-9 emit_event context.prompt_scanned "" 1)"
  ts="$(jq -r .ts <<< "$line")"; id="$(jq -r .id <<< "$line")"
  stamp="${id#evt-}"; stamp="${stamp%-*}"
  epoch="$(date -u +%s)"
  want_ts="$(date -u -d "@$epoch" +%Y-%m-%dT%H:%M:%SZ)"
  want_stamp="$(date -u -d "@$epoch" +%Y%m%dT%H%M%SZ)"
  # The two clocks are read a moment apart: accept the same second or the one before.
  if [[ "${ts:0:16}" == "${want_ts:0:16}" && "${stamp:0:13}" == "${want_stamp:0:13}" \
        && "$ts" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ \
        && "$id" =~ ^evt-[0-9]{8}T[0-9]{6}Z-[0-9a-f]{6}$ ]]; then
    pass "$name"
  else
    fail "$name" "ts=$ts id=$id want=$want_ts"
  fi
}

case_key_memo_matches_the_uncached_key
case_key_memo_starts_no_process
case_key_memo_follows_repo_root_and_cwd
case_key_memo_never_stores_the_global_fallback
case_usage_event_bytes_match_the_jq_program
case_usage_event_query_text_still_goes_through_jq
case_usage_event_odd_counts_behave_as_before
case_usage_event_timestamp_is_utc_in_any_zone

th_summary
