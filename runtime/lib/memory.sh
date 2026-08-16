#!/usr/bin/env bash
# memory.sh - shared helpers for locating project memory directory.
# Source this file; do not execute directly.
# Requires: CLAUDE_CONFIG_DIR env var or ~/.claude default.

encode_path() {
  local p="$1"
  printf '%s' "-${p#/}" | tr '/' '-'
}

# Cross-tool memory-dir override, checked by both this function and
# memory-dir.sh's installer/migrator variant. PM_MEMORY_DIR (env) always wins
# over PM_CFG_MEMORY_DIR (~/.pm-dispatch/config `dispatch.memory_dir`, only
# populated when a caller has already run pm_config_load — hooks never do,
# so this stays a plain variable read with zero file I/O on the hook path).
# This low-level selector ignores unavailable targets. Canonical CLI callers
# first use _pm_memory_explicit_selection_invalid so an explicit selection
# cannot fall through; legacy-only callers retain their discovery convention.
_pm_memory_dir_override() {
  local d="${PM_MEMORY_DIR:-}"
  if [[ -n "$d" && -d "$d" ]]; then printf '%s' "$d"; return 0; fi
  d="${PM_CFG_MEMORY_DIR:-}"
  if [[ -n "$d" && -d "$d" ]]; then printf '%s' "$d"; return 0; fi
  return 1
}

# Return success when an explicitly selected canonical-memory target is invalid.
# Callers that have loaded project config use this before compatibility discovery
# so one shared rule prevents fallback into another store.
_pm_memory_explicit_selection_invalid() {
  if [[ -n "${PM_MEMORY_DIR:-}" && ( "${PM_MEMORY_DIR}" != /* || ! -d "${PM_MEMORY_DIR}" ) ]]; then
    return 0
  fi
  [[ "${PM_CFG_MEMORY_DIR_INVALID:-0}" -eq 0 ]] || return 0
  if [[ "${PM_CFG_MEMORY_CONFIG_STATUS:-none}" == "matched" && ! -d "${PM_CFG_MEMORY_DIR:-}" ]]; then
    return 0
  fi
  return 1
}

find_memory_dir() {
  local override
  if override="$(_pm_memory_dir_override)"; then
    printf '%s' "$override"; return 0
  fi
  local cwd="$1"
  local config_dir="${2:-${CLAUDE_CONFIG_DIR:-${HOME}/.claude}}"
  local projects_dir current candidate parent
  projects_dir="$config_dir/projects"
  current="${cwd%/}"
  while true; do
    candidate="$projects_dir/$(encode_path "$current")/memory"
    if [[ -d "$candidate" ]]; then
      printf '%s' "$candidate"
      return 0
    fi
    parent="$(dirname "$current")"
    [[ "$parent" != "$current" ]] || return 1
    current="$parent"
  done
}

# ---------------------------------------------------------------------------
# Injection budget — the caps guard-inject-memory.sh enforces per prompt.
# They live here rather than in the hook so `pmctl memory stats` reports the
# budget the hook actually applies instead of a second copy that can drift.
# Deliberately plain constants, not env-overridable: the hook path must stay
# identical across hosts, and an ambient override would leak into fixtures.
# ---------------------------------------------------------------------------
# shellcheck disable=SC2034  # read by guard-inject-memory.sh and pmctl memory stats after sourcing this lib
MEMORY_MAX_INJECT_ENTRIES=20
# shellcheck disable=SC2034  # read by guard-inject-memory.sh and pmctl memory stats after sourcing this lib
MEMORY_MAX_INJECT_BYTES=3000

# ---------------------------------------------------------------------------
# Usage-based injection ranking (frecency) — sidecar telemetry plane.
#
# MEMORY.md injection ranks normal (non-pinned) cards by a usage signal so the
# fixed injection budget admits the cards the user's prompts actually need.
# The signal is recency+frequency ("frecency"), stored OUT of the canonical
# markdown cards in a sidecar TSV so card frontmatter stays human-owned and the
# high-frequency telemetry writes never produce git diff noise.
#
# Primary store (when sqlite3 is available):
#   .pm-dispatch/inject-usage.sqlite3
# Writers use a single BEGIN IMMEDIATE transaction with WAL, a bounded SQLite
# busy timeout, and whole-transaction retry, so increments remain atomic across
# prompt-hook processes without a shell lock.  The CLI runs with `-bail`: a
# failed BEGIN or WAL bootstrap must stop before later statements can escape
# into autocommit and make a retry double-count the access.
#
# Compatibility fallback (sqlite3 unavailable): TSV, integer-only, zero-LLM:
#   # total_events=<N>            <- global W-TinyLFU decay counter (header line)
#   <card_relpath>\t<access_count>\t<last_access_day>
#   ...
# card_relpath is the `file.md` target of the MEMORY.md index link (stable key,
# relative to memory_dir). last_access_day is epoch-day ($(date +%s)/86400).
# ---------------------------------------------------------------------------

# Path to the usage sidecar for a given memory dir. Lives on the same
# out-of-repo-friendly .pm-dispatch plane as the context DB and is excluded
# from memory indexing.
memory_usage_sidecar_path() {
  local memory_dir="$1"
  if command -v sqlite3 >/dev/null 2>&1; then
    printf '%s/.pm-dispatch/inject-usage.sqlite3' "${memory_dir%/}"
  else
    printf '%s/.pm-dispatch/inject-usage.tsv' "${memory_dir%/}"
  fi
}

# Emit either store in the legacy TSV read shape used by the ranking hook.
# Before the first SQLite write, an existing TSV remains readable so upgrades
# do not temporarily lose ranking history.
memory_usage_read() {
  local store="$1" legacy total
  if [[ "$store" == *.sqlite3 ]]; then
    if [[ -f "$store" ]]; then
      total="$(sqlite3 -cmd '.timeout 10000' "$store" \
        "SELECT value FROM metadata WHERE key='total_events';" 2>/dev/null || true)"
      printf '# total_events=%s\n' "${total:-0}"
      sqlite3 -cmd '.timeout 10000' -separator $'\t' "$store" \
        'SELECT card_relpath, access_count, last_access_day FROM card_usage ORDER BY card_relpath;' \
        2>/dev/null || return 1
      return 0
    fi
    legacy="${store%.sqlite3}.tsv"
    [[ -f "$legacy" ]] && cat "$legacy"
    return 0
  fi
  [[ -f "$store" ]] && cat "$store"
}

# Load the usage sidecar into two caller-supplied associative arrays, keyed by
# card_relpath. Every reader needs the same parse (skip comments, coerce
# non-integers to 0) and the same tolerance for an absent store, so the loop
# lives here rather than being copied into each caller.
#   declare -A acc=() last=(); memory_usage_load "$store" acc last
memory_usage_load() {
  local _mu_store="$1"
  local -n _mu_acc_ref="$2"
  local -n _mu_last_ref="$3"
  local _mu_rel _mu_acc _mu_last
  while IFS=$'\t' read -r _mu_rel _mu_acc _mu_last; do
    [[ -z "$_mu_rel" || "$_mu_rel" == \#* ]] && continue
    [[ "$_mu_acc"  =~ ^[0-9]+$ ]] || _mu_acc=0
    [[ "$_mu_last" =~ ^[0-9]+$ ]] || _mu_last=0
    _mu_acc_ref["$_mu_rel"]="$_mu_acc"
    _mu_last_ref["$_mu_rel"]="$_mu_last"
  done < <(memory_usage_read "$_mu_store")
  return 0
}

_memory_usage_sql_quote() {
  local value="$1"
  value="${value//\'/\'\'}"
  printf "'%s'" "$value"
}

# Retry only SQLite's lock-contention class.  Schema, permission, I/O, and
# corruption errors are permanent for this call and must remain immediately
# visible to the caller.  SQLite can spell SQLITE_LOCKED as either "database
# table is locked" or "database schema is locked" depending on the statement.
_memory_usage_sqlite_error_is_retryable() {
  local error_file="${1:-}"
  [[ -s "$error_file" ]] || return 1
  LC_ALL=C grep -Eiq \
    'database( table| schema)? is (locked|busy)([[:space:](:]|$)' "$error_file"
}

# Give cold-start WAL contenders different retry slots.  BASHPID separates
# sibling hook processes while RANDOM prevents repeated collisions within one
# process.  Tests override this private seam so retry semantics are proven
# without timing assertions or real sleeps.
_memory_usage_sqlite_retry_pause() {
  local retry_index="${1:-1}" delay_ms delay
  [[ "$retry_index" =~ ^[1-9][0-9]*$ ]] || retry_index=1
  delay_ms=$(( retry_index * 50 + (BASHPID + RANDOM) % 101 ))
  printf -v delay '0.%03d' "$delay_ms"
  sleep "$delay"
}

_memory_usage_commit_sqlite() {
  local store="$1" threshold="$2" today="$3"; shift 3
  local dir legacy sql error_file rel acc last total_events=0 quoted
  local attempt rc=0 max_attempts=4
  dir="$(dirname "$store")"
  mkdir -p "$dir" 2>/dev/null || return 1
  legacy="${store%.sqlite3}.tsv"
  sql="$(mktemp "${TMPDIR:-/tmp}/memory-usage.XXXXXX.sql")" || return 1
  error_file="$(mktemp "${TMPDIR:-/tmp}/memory-usage.XXXXXX.err")" || {
    rm -f "$sql"
    return 1
  }
  {
    printf '%s\n' 'PRAGMA journal_mode=WAL;' 'PRAGMA synchronous=NORMAL;' 'BEGIN IMMEDIATE;'
    printf '%s\n' \
      'CREATE TABLE IF NOT EXISTS metadata (key TEXT PRIMARY KEY, value INTEGER NOT NULL);' \
      'CREATE TABLE IF NOT EXISTS card_usage (card_relpath TEXT PRIMARY KEY, access_count INTEGER NOT NULL CHECK(access_count >= 0), last_access_day INTEGER NOT NULL);' \
      "INSERT OR IGNORE INTO metadata(key,value) VALUES('schema_version',1);" \
      "INSERT OR IGNORE INTO metadata(key,value) VALUES('total_events',0);"
    if [[ -f "$legacy" ]]; then
      while IFS=$'\t' read -r rel acc last; do
        [[ -z "$rel" ]] && continue
        if [[ "$rel" == '# total_events='* ]]; then
          total_events="${rel#\# total_events=}"
          [[ "$total_events" =~ ^[0-9]+$ ]] || total_events=0
          continue
        fi
        [[ "$rel" == \#* || "$rel" == *$'\n'* || "$rel" == *$'\t'* ]] && continue
        [[ "$acc" =~ ^[0-9]+$ ]] || acc=0
        [[ "$last" =~ ^[0-9]+$ ]] || last=0
        quoted="$(_memory_usage_sql_quote "$rel")"
        printf "INSERT INTO card_usage(card_relpath,access_count,last_access_day) SELECT %s,%s,%s WHERE NOT EXISTS (SELECT 1 FROM metadata WHERE key='legacy_imported') ON CONFLICT(card_relpath) DO NOTHING;\n" "$quoted" "$acc" "$last"
      done < "$legacy"
      printf "UPDATE metadata SET value=%s WHERE key='total_events' AND NOT EXISTS (SELECT 1 FROM metadata WHERE key='legacy_imported');\n" "$total_events"
      printf "INSERT OR IGNORE INTO metadata(key,value) VALUES('legacy_imported',1);\n"
    fi
    for rel in "$@"; do
      [[ -n "$rel" && "$rel" != *$'\n'* && "$rel" != *$'\t'* ]] || continue
      quoted="$(_memory_usage_sql_quote "$rel")"
      printf "INSERT INTO card_usage(card_relpath,access_count,last_access_day) VALUES(%s,1,%s) ON CONFLICT(card_relpath) DO UPDATE SET access_count=access_count+1,last_access_day=excluded.last_access_day;\n" "$quoted" "$today"
      printf "UPDATE metadata SET value=value+1 WHERE key='total_events';\n"
    done
    printf "UPDATE card_usage SET access_count=access_count >> 1 WHERE (SELECT value FROM metadata WHERE key='total_events') >= %s;\n" "$threshold"
    printf "UPDATE metadata SET value=0 WHERE key='total_events' AND value >= %s;\n" "$threshold"
    printf '%s\n' 'COMMIT;'
  } > "$sql" || {
    rm -f "$sql" "$error_file"
    return 1
  }

  # Retrying the complete script is exactly-once only because `-bail` stops at
  # the first failed statement.  If BEGIN IMMEDIATE has started, closing the
  # failed CLI connection rolls it back; if only journal_mode=WAL succeeded,
  # repeating that persistent idempotent PRAGMA is harmless.
  for ((attempt = 1; attempt <= max_attempts; attempt += 1)); do
    : > "$error_file"
    rc=0
    sqlite3 -batch -bail -cmd '.timeout 1500' "$store" < "$sql" \
      >/dev/null 2>"$error_file" || rc=$?
    if (( rc == 0 )); then
      rm -f "$sql" "$error_file"
      return 0
    fi
    if ! _memory_usage_sqlite_error_is_retryable "$error_file" \
      || (( attempt == max_attempts )); then
      cat "$error_file" >&2
      rm -f "$sql" "$error_file"
      return "$rc"
    fi
    _memory_usage_sqlite_retry_pause "$attempt" || true
  done

  # The bounded loop always returns above; retain a fail-closed guard against
  # future edits that accidentally make max_attempts empty or non-positive.
  rm -f "$sql" "$error_file"
  return 1
}

# Firefox bucketed frecency age weight. Maps the day-distance between today and
# a card's last access to an integer bucket: more recent -> higher weight.
# Negative diffs (clock skew / future stamp) are treated as most-recent.
memory_age_bucket() {
  local today="$1" last="$2" diff
  diff=$(( today - last ))
  if   (( diff <= 4  )); then printf '100'
  elif (( diff <= 14 )); then printf '70'
  elif (( diff <= 31 )); then printf '50'
  elif (( diff <= 90 )); then printf '30'
  else                        printf '10'
  fi
}

# Commit usage increments to the selected sidecar. SQLite stores perform the
# complete increment/decay operation in one BEGIN IMMEDIATE transaction and do
# not need an external shell lock. TSV fallback stores still require callers to
# serialize the read-modify-write operation. Both paths apply +1 access (and
# today's last_access) to each relpath argument, bump the global event counter,
# then halve every count and reset the counter at the decay threshold.
#   memory_usage_commit <sidecar> <threshold> <today_day> [relpath ...]
memory_usage_commit() {
  local sidecar="$1" threshold="$2" today="$3"; shift 3
  local -a hits=("$@")
  [[ "${#hits[@]}" -gt 0 ]] || return 0
  [[ "$threshold" =~ ^[0-9]+$ ]] || return 1
  [[ "$today" =~ ^[0-9]+$ ]] || return 1
  threshold="$((10#$threshold))"
  today="$((10#$today))"
  (( threshold > 0 )) || return 1

  if [[ "$sidecar" == *.sqlite3 ]]; then
    command -v sqlite3 >/dev/null 2>&1 || return 1
    _memory_usage_commit_sqlite "$sidecar" "$threshold" "$today" "${hits[@]}"
    return $?
  fi

  local dir tmp total_events=0 rel acc last
  dir="$(dirname "$sidecar")"
  mkdir -p "$dir" 2>/dev/null || return 1

  local -A ACC=() LAST=()
  if [[ -f "$sidecar" ]]; then
    while IFS=$'\t' read -r rel acc last; do
      [[ -z "$rel" ]] && continue
      if [[ "$rel" == '# total_events='* ]]; then
        total_events="${rel#\# total_events=}"
        [[ "$total_events" =~ ^[0-9]+$ ]] || total_events=0
        continue
      fi
      [[ "$rel" == \#* ]] && continue
      [[ "$acc"  =~ ^[0-9]+$ ]] || acc=0
      [[ "$last" =~ ^[0-9]+$ ]] || last=0
      ACC["$rel"]="$acc"
      LAST["$rel"]="$last"
    done < "$sidecar"
  fi

  # Apply this run's accesses.
  for rel in "${hits[@]}"; do
    ACC["$rel"]=$(( ${ACC["$rel"]:-0} + 1 ))
    LAST["$rel"]="$today"
    total_events=$(( total_events + 1 ))
  done

  # Global W-TinyLFU aging: halve every counter once the budget of events is hit.
  if (( total_events >= threshold )); then
    for rel in "${!ACC[@]}"; do
      ACC["$rel"]=$(( ACC["$rel"] >> 1 ))
    done
    total_events=0
  fi

  tmp="$(mktemp "${sidecar}.XXXXXX")" || return 1
  {
    printf '# total_events=%d\n' "$total_events"
    for rel in "${!ACC[@]}"; do
      printf '%s\t%d\t%d\n' "$rel" "${ACC["$rel"]}" "${LAST["$rel"]:-0}"
    done
  } > "$tmp" || { rm -f "$tmp"; return 1; }
  mv -f "$tmp" "$sidecar" || { rm -f "$tmp"; return 1; }
  return 0
}

# ---------------------------------------------------------------------------
# ISO8601 timestamp normalization — shared by guard-inject-memory.sh and
# guard-session-summary.sh episode-age checks (both compute "hours since last
# episode" from a stored `date` field).
# ---------------------------------------------------------------------------

# Normalize an episode `date` field (bare "...Z", fractional seconds, and/or a
# trailing +HH:MM/-HH:MM offset, in any combination) into a jq-safe UTC base
# plus its offset in seconds. Prints "<base>\t<offset_seconds>" (base has no
# trailing Z or offset suffix — callers append "Z" before feeding it to jq's
# fromdateiso8601, which requires exactly that form).
#   IFS=$'\t' read -r base offset < <(memory_iso8601_normalize "$date")
memory_iso8601_normalize() {
  local date="$1" d_norm d_base d_offset=0 d_suffix d_clean d_frac_suffix
  d_norm="$date"
  if [[ "$date" == *.*[+-][0-9][0-9]:[0-9][0-9] ]]; then
    d_clean="${date%%.*}"
    d_frac_suffix="${date#*.}"
    if [[ "$d_frac_suffix" == *+* ]]; then
      d_norm="${d_clean}+${d_frac_suffix##*+}"
    else
      d_norm="${d_clean}-${d_frac_suffix##*-}"
    fi
  elif [[ "$date" == *.* ]]; then
    # covers both bare fractional ("...56.123") and fractional-Z ("...56.123Z")
    d_norm="${date%%.*}Z"
  elif [[ "$date" != *Z && ! "$date" =~ [+-][0-9][0-9]:[0-9][0-9]$ ]]; then
    d_norm="${date}Z"
  fi

  if [[ "$d_norm" == *[+-][0-9][0-9]:[0-9][0-9] ]]; then
    d_suffix="${d_norm: -6}"
    d_base="${d_norm:0:${#d_norm}-6}"
    d_offset=$((10#${d_suffix:1:2} * 3600 + 10#${d_suffix:4:2} * 60))
    [[ "${d_suffix:0:1}" == "-" ]] && d_offset=$((-d_offset))
  else
    d_base="${d_norm%Z}"
  fi

  printf '%s\t%d\n' "$d_base" "$d_offset"
}
