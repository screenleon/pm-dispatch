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
# Usage-based injection ranking (frecency) — sidecar telemetry plane.
#
# MEMORY.md injection ranks normal (non-pinned) cards by a usage signal so the
# fixed injection budget admits the cards the user's prompts actually need.
# The signal is recency+frequency ("frecency"), stored OUT of the canonical
# markdown cards in a sidecar TSV so card frontmatter stays human-owned and the
# high-frequency telemetry writes never produce git diff noise.
#
# Sidecar format (TSV, integer-only, zero-LLM):
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
  printf '%s/.pm-dispatch/inject-usage.tsv' "${memory_dir%/}"
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

# Commit usage increments to the sidecar (read-modify-write; call under
# serialize_with_lock so concurrent hooks cannot lose updates). Re-reads the
# sidecar fresh, applies +1 access (and today's last_access) to each relpath
# argument, bumps the global event counter once per increment, then -- when the
# counter reaches the decay threshold -- halves every card's access_count
# (W-TinyLFU aging) and resets the counter. Writes atomically via tmp + mv.
#   memory_usage_commit <sidecar> <threshold> <today_day> [relpath ...]
memory_usage_commit() {
  local sidecar="$1" threshold="$2" today="$3"; shift 3
  local -a hits=("$@")
  [[ "${#hits[@]}" -gt 0 ]] || return 0

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
