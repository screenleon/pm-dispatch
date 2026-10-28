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
# event was appended. The emitter's exit status goes to "$tmp_root/emit.rc" (the helper runs in a command
# substitution, so a variable would not survive).
emit_event() {
  local out="$tmp_root/emitted.$$.$RANDOM" rc=0
  : > "$out"
  bash -c '
    . "$1/runtime/lib/pmctl-context.sh"
    state_store_init() { :; }
    sink="$5"
    events_append() { printf "%s\n" "$1" > "$sink"; }
    _ctx_emit_warn() { :; }
    _ctx_emit_usage_event "$2" x "$3" "$4"
  ' _ "$REPO_ROOT" "$1" "$2" "$3" "$out" 2>/dev/null || rc=$?
  printf '%s
' "$rc" > "$tmp_root/emit.rc"
  cat "$out"
  rm -f "$out"
}

# reference_event <line> <kind> <query> <hits>: the event the jq program of the previous implementation builds
# for the REQUESTED kind, query and count. Only the generated id and timestamp are taken from the emitted line,
# so a corrupted kind or count in the code under test cannot leak into its own expected value.
reference_event() {
  local line="$1" id ts
  id="$(jq -r .id <<< "$line")"; ts="$(jq -r .ts <<< "$line")"
  jq -cn --arg id "$id" --arg ts "$ts" --arg kind "$2" --arg query "$3" --argjson hits "$4" \
    '{schema_version:1,id:$id,ts:$ts,kind:$kind,
      subject_type:"context",subject_id:("ctx-"+ $id),
      actor:"pmctl",
      payload:{query:$query,hits:$hits}}'
}

case_usage_event_bytes_match_the_jq_program() {
  local name="usage event: the directly formatted event is byte-identical to the jq program's for the requested kind and count"
  should_run "$name" || return 0
  local line ref bad="" kind hits
  for kind in context.prompt_scanned context.queried; do
    for hits in 0 3 12; do
      line="$(emit_event "$kind" "" "$hits")"
      ref="$(reference_event "$line" "$kind" "" "$hits")"
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
  local padded junk padded_rc junk_rc
  # "07" is not the plain integer the direct path accepts, so the jq program decides, as it always did.
  padded="$(emit_event context.queried "" "07")"; padded_rc="$(cat "$tmp_root/emit.rc")"
  junk="$(emit_event context.queried "" "abc")"; junk_rc="$(cat "$tmp_root/emit.rc")"
  # Telemetry is best effort: a rejected count appends nothing and still returns 0, it does not crash.
  if [[ "$(jq -r '.payload.hits' <<< "$padded" 2>/dev/null || true)" == 7 && -z "$junk"         && "$padded_rc" == 0 && "$junk_rc" == 0 ]]; then
    pass "$name"
  else
    fail "$name" "padded=$padded rc=$padded_rc junk=$junk rc=$junk_rc"
  fi
}

case_usage_event_timestamp_is_utc_in_any_zone() {
  local name="usage event: ts and the id stamp are UTC, whatever TZ the process runs in"
  should_run "$name" || return 0
  local line ts id stamp before after ts_epoch stamp_epoch
  before="$(date -u +%s)"
  line="$(TZ=JST-9 emit_event context.prompt_scanned "" 1)"
  after="$(date -u +%s)"
  ts="$(jq -r .ts <<< "$line")"; id="$(jq -r .id <<< "$line")"
  stamp="${id#evt-}"; stamp="${stamp%-*}"
  ts_epoch="$(date -u -d "$ts" +%s 2>/dev/null || true)"
  stamp_epoch="$(date -u -d "${stamp:0:4}-${stamp:4:2}-${stamp:6:2}T${stamp:9:2}:${stamp:11:2}:${stamp:13:2}Z" +%s 2>/dev/null || true)"
  # The event was stamped between the two clock reads (any minute, hour or day rollover included); a
  # zone offset such as JST's nine hours would fall far outside that interval.
  if [[ "$ts_epoch" =~ ^[0-9]+$ && "$stamp_epoch" =~ ^[0-9]+$ \
        && "$ts_epoch" -ge "$before" && "$ts_epoch" -le "$after" \
        && "$stamp_epoch" -ge "$before" && "$stamp_epoch" -le "$after" \
        && "$ts" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ \
        && "$id" =~ ^evt-[0-9]{8}T[0-9]{6}Z-[0-9a-f]{6}$ ]]; then
    pass "$name"
  else
    fail "$name" "ts=$ts id=$id window=$before..$after"
  fi
}

case_fts_probe_runs_once_for_all_prompt_terms() {
  local name="prompt-scan: the FTS5 probe is made once for all terms, and the answer matches the per-term probe"
  should_run "$name" || return 0
  th_require_cmd "$name" sqlite3 || return 0
  local repo="$tmp_root/fts-probe-repo" db got
  mkdir -p "$repo/.pm-dispatch/ctx"
  db="$repo/.pm-dispatch/ctx/context.db"
  # A setup error in the plain tables is a broken test, not a missing capability.
  if ! sqlite3 "$db" "
    CREATE TABLE files(id INTEGER PRIMARY KEY, path TEXT);
    CREATE TABLE symbols(file_id INTEGER, name TEXT, kind TEXT, line_start INTEGER, line_end INTEGER);
    CREATE TABLE file_chunks(file_id INTEGER, heading TEXT, text TEXT, line_start INTEGER, line_end INTEGER);
    INSERT INTO files VALUES (1, 'docs/a.md');" >/dev/null 2>&1; then
    fail "$name" "setup: could not create the fixture tables"; return 0
  fi
  # Only the FTS5 module itself may be missing on a supported host; that is a skip with its reason.
  if ! sqlite3 "$db" "
    CREATE VIRTUAL TABLE content_fts USING fts5(ref, text, line_end UNINDEXED);
    INSERT INTO content_fts VALUES ('docs/a.md:1', 'alpha beta gamma', 3);" >/dev/null 2>&1; then
    skip "$name" "this sqlite3 build has no FTS5"; return 0
  fi
  got="$(bash -c '
    . "$1/runtime/lib/pmctl-context.sh"
    root="$2"; log="$3"; : > "$log"
    sqlite3() { case "$*" in *sqlite_master*) echo probe >> "$log";; esac; command sqlite3 "$@"; }
    run_terms() { local t; for t in alpha beta gamma; do _ctx_query_hits_raw "$root" "$t" knowledge 2>/dev/null; done; }
    db="$root/.pm-dispatch/ctx/context.db"
    per_term="$(run_terms)"; per_term_probes="$(grep -c probe "$log" || true)"
    : > "$log"
    if _ctx_fts_usable "$db"; then _CTX_FTS_USABLE[$db]=1; else _CTX_FTS_USABLE[$db]=0; fi
    once="$(run_terms)"; once_probes="$(grep -c probe "$log" || true)"
    # one probe for _ctx_fts_usable itself, none for the terms
    if [[ "$per_term" == "$once" && -n "$once" && "$per_term_probes" -eq 3 && "$once_probes" -eq 1 ]]; then
      echo ok
    else
      echo "per_term_probes=$per_term_probes once_probes=$once_probes same=$([[ "$per_term" == "$once" ]] && echo y || echo n)"
    fi
  ' _ "$REPO_ROOT" "$repo" "$tmp_root/fts-probe.log" 2>&1)" || true
  if [[ "$got" == ok ]]; then
    pass "$name"
  else
    fail "$name" "$got"
  fi
}

case_prompt_scan_probes_fts_once_end_to_end() {
  local name="prompt-scan: a six-term prompt probes for content_fts fewer times than it has terms"
  should_run "$name" || return 0
  th_require_cmd "$name" sqlite3 || return 0
  local repo="$tmp_root/fts-e2e-repo" real probes warm_rc=0 scan_rc=0 scan_out
  mkdir -p "$repo/docs" "$tmp_root/fts-e2e-stub"
  git_repo "$repo"
  printf '# Alpha\nalpha beta gamma delta epsilon zeta\n' > "$repo/docs/a.md"
  git -C "$repo" add -A >/dev/null 2>&1
  git -C "$repo" -c user.name=t -c user.email=t@example.invalid commit -q -m docs
  real="$(command -v sqlite3)"
  printf '#!/bin/sh\ncase "$*" in *sqlite_master*) echo probe >> "%s/probes";; esac\nexec "%s" "$@"\n' "$tmp_root" "$real" \
    > "$tmp_root/fts-e2e-stub/sqlite3"
  chmod +x "$tmp_root/fts-e2e-stub/sqlite3"
  # The first scan builds the index; count only the second, which finds it fresh.
  PATH="$tmp_root/fts-e2e-stub:$PATH" PM_DISPATCH_STATE_ROOT="$tmp_root/fts-e2e-state" \
    bash "$REPO_ROOT/cli/pmctl" context prompt-scan "$repo" "alpha beta gamma delta epsilon zeta" >/dev/null 2>&1 || warm_rc=$?
  rm -f "$tmp_root/probes"
  scan_out="$(PATH="$tmp_root/fts-e2e-stub:$PATH" PM_DISPATCH_STATE_ROOT="$tmp_root/fts-e2e-state" \
    bash "$REPO_ROOT/cli/pmctl" context prompt-scan "$repo" "alpha beta gamma delta epsilon zeta" 2>/dev/null)" || scan_rc=$?
  probes="$(grep -c probe "$tmp_root/probes" 2>/dev/null || true)"
  # The scan has to succeed and still find the document, or a probe count from a broken run means nothing.
  if [[ "$warm_rc" -eq 0 && "$scan_rc" -eq 0 && "$scan_out" == *"ref: docs/a.md"* \
        && "$probes" =~ ^[0-9]+$ && "$probes" -ge 1 && "$probes" -lt 6 ]]; then
    pass "$name"
  else
    fail "$name" "warm_rc=$warm_rc scan_rc=$scan_rc probes=${probes:-none} out=${scan_out:0:200}"
  fi
}

case_cached_fts_unavailable_keeps_the_like_fallback() {
  local name="prompt-scan: when the warm-up says content_fts is unusable, terms still find their LIKE fallback hit"
  should_run "$name" || return 0
  th_require_cmd "$name" sqlite3 || return 0
  local repo="$tmp_root/fts-like-repo" db got
  mkdir -p "$repo/.pm-dispatch/ctx"
  db="$repo/.pm-dispatch/ctx/context.db"
  # No content_fts table at all: the only way to a hit is the file_chunks LIKE query.
  if ! sqlite3 "$db" "
    CREATE TABLE files(id INTEGER PRIMARY KEY, path TEXT);
    CREATE TABLE symbols(file_id INTEGER, name TEXT, kind TEXT, line_start INTEGER, line_end INTEGER);
    CREATE TABLE file_chunks(file_id INTEGER, heading TEXT, text TEXT, line_start INTEGER, line_end INTEGER);
    INSERT INTO files VALUES (1, 'docs/a.md');
    INSERT INTO file_chunks VALUES (1, 'Alpha', 'alpha beta gamma', 4, 9);" >/dev/null 2>&1; then
    fail "$name" "setup: could not create the fixture tables"; return 0
  fi
  got="$(bash -c '
    . "$1/runtime/lib/pmctl-context.sh"
    db="$2/.pm-dispatch/ctx/context.db"
    run_terms() { local t; for t in alpha beta; do _ctx_query_hits_raw "$2" "$t" knowledge 2>/dev/null; done; }
    per_term="$(run_terms _ "$2")"
    if _ctx_fts_usable "$db"; then _CTX_FTS_USABLE[$db]=1; else _CTX_FTS_USABLE[$db]=0; fi
    cached_value="${_CTX_FTS_USABLE[$db]}"
    once="$(run_terms _ "$2")"
    hits="$(grep -c "like_fallback" <<< "$once" || true)"
    if [[ "$cached_value" == 0 && "$per_term" == "$once" && "$hits" -eq 2 && "$once" == *"docs/a.md:4"* ]]; then
      echo ok
    else
      echo "cached=$cached_value same=$([[ "$per_term" == "$once" ]] && echo y || echo n) like_hits=$hits out=$once"
    fi
  ' _ "$REPO_ROOT" "$repo" 2>&1)" || true
  if [[ "$got" == ok ]]; then
    pass "$name"
  else
    fail "$name" "$got"
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
case_fts_probe_runs_once_for_all_prompt_terms
case_prompt_scan_probes_fts_once_end_to_end
case_cached_fts_unavailable_keeps_the_like_fallback

th_summary
