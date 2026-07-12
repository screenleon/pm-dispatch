#!/usr/bin/env bash
# Shared model-alias TSV parser for adapter dispatch scripts.
# Provides ma_resolve_alias (soft) and ma_resolve_alias_strict (hard-fail).
# Both functions set MA_RESOLVE_MODEL, MA_RESOLVE_EFFORT, MA_RESOLVE_MATCH.

# shellcheck disable=SC2034  # output variables read by callers after sourcing this lib
MA_RESOLVE_MODEL=""
MA_RESOLVE_EFFORT=""
MA_RESOLVE_MATCH=0

# ma_resolve_alias <tsv_file> <query_alias> [<caller_prefix>]
# Soft mode: missing/unreadable file → return 0 (pass-through); malformed line → warn + continue.
ma_resolve_alias() {
  local tsv_file="$1" query_alias="$2" caller="${3:-model-aliases}"
  MA_RESOLVE_MODEL=""; MA_RESOLVE_EFFORT=""; MA_RESOLVE_MATCH=0

  [[ -f "$tsv_file" ]] || return 0
  [[ -r "$tsv_file" ]] || return 0

  local line alias_value model_id effort rest
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%$'\r'}"
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [[ -z "$line" || "${line:0:1}" == "#" ]] && continue
    IFS=$'\t' read -r alias_value model_id effort rest <<< "$line"
    if [[ -z "$alias_value" || -z "$model_id" || -z "$effort" || -n "$rest" ]]; then
      printf '%s: warning: malformed entry in %s, skipping\n' "$caller" "$tsv_file" >&2
      continue
    fi
    if [[ "$alias_value" == "$query_alias" ]]; then
      # shellcheck disable=SC2034
      MA_RESOLVE_MODEL="$model_id"
      # shellcheck disable=SC2034
      MA_RESOLVE_EFFORT="$effort"
      # shellcheck disable=SC2034
      MA_RESOLVE_MATCH=1
      return 0
    fi
  done < "$tsv_file"
  return 0
}

# ma_resolve_alias_strict <tsv_file> <query_alias> [<caller_prefix>]
# Strict mode: missing/unreadable file → return 1; malformed line → return 1.
ma_resolve_alias_strict() {
  local tsv_file="$1" query_alias="$2" caller="${3:-model-aliases}"
  MA_RESOLVE_MODEL=""; MA_RESOLVE_EFFORT=""; MA_RESOLVE_MATCH=0

  if [[ ! -f "$tsv_file" ]]; then
    printf '%s: error: model alias source-of-truth not found: %s\n' "$caller" "$tsv_file" >&2
    printf 'Expected file path: share/codex-model-aliases.tsv or share/claude-model-aliases.tsv (copied to snapshot at runtime).\n' >&2
    return 1
  fi
  if [[ ! -r "$tsv_file" ]]; then
    printf '%s: error: model alias source-of-truth unreadable: %s\n' "$caller" "$tsv_file" >&2
    return 1
  fi

  local line alias_value model_id effort rest line_no=0
  while IFS= read -r line || [[ -n "$line" ]]; do
    (( line_no += 1 ))
    line="${line%$'\r'}"
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [[ -z "$line" || "${line:0:1}" == "#" ]] && continue
    IFS=$'\t' read -r alias_value model_id effort rest <<< "$line"
    if [[ -z "$alias_value" || -z "$model_id" || -z "$effort" || -n "$rest" ]]; then
      printf '%s: error: malformed model-alias entry in %s:%d\n' "$caller" "$tsv_file" "$line_no" >&2
      printf 'Expected one tab-separated line: <alias><TAB><model_id><TAB><reasoning_effort>\n' >&2
      return 1
    fi
    if [[ "$alias_value" == "$query_alias" ]]; then
      # shellcheck disable=SC2034
      MA_RESOLVE_MODEL="$model_id"
      # shellcheck disable=SC2034
      MA_RESOLVE_EFFORT="$effort"
      # shellcheck disable=SC2034
      MA_RESOLVE_MATCH=1
      return 0
    fi
  done < "$tsv_file"
  return 0
}
