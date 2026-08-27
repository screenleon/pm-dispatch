#!/usr/bin/env bash
# pmctl run-stats — per-adapter success/failure/fallback analysis over
# events.jsonl (CC-358). Read-only consumer: never calls events_append or any
# state-writer write helper. Uses the same ISO-8601 lexicographic string
# comparison, archive-inclusive scan model, and single streaming jq pass as
# pmctl trace tail (runtime/lib/pmctl-trace.sh) rather than inventing a second
# parser for the same file format.
#
# The archive-glob + gzip-check + concat-then-one-jq-pass idiom is duplicated
# between this file and pmctl-trace.sh (~12 lines each). Extraction into a
# shared events-scan primitive was considered and deferred: the two jq
# programs and output consumers differ, and the gzip-unavailable signalling
# diverges (trace tail: read_archives=0; run-stats: archive_scanned=false +
# `_meta`). At two consumers the shared seam isn't clearly worth the callback
# indirection; revisit if a third consumer appears.
#
# Archive-inclusive by default, matching pmctl trace tail's read_archives=1:
# rotated archive/events-*.jsonl.gz files are scanned alongside the active
# events.jsonl so a --since window reaching past rotation still counts every
# matching run. Falls back to active-file-only (and says so in `_meta`) only
# when gzip is unavailable, same fallback pmctl trace tail uses.

pmctl_run_stats_usage() {
  printf 'usage: pmctl run-stats [--since <ISO8601-or-date>] [--by-adapter] [--json]\n' >&2
}

pmctl_run_stats_ensure_state_writer() {
  local repo_root="${1:-}"

  if declare -F _sw_project_dir >/dev/null 2>&1; then
    return 0
  fi
  if [[ -z "$repo_root" || ! -r "$repo_root/runtime/lib/state-writer.sh" ]]; then
    printf 'pmctl run-stats: state writer unavailable\n' >&2
    return 2
  fi
  # shellcheck disable=SC1091  # dynamic repo root path.
  . "$repo_root/runtime/lib/state-writer.sh"
}

# Single streaming jq program over the concatenated archive+active event
# stream (raw input, one JSON object per line). Replaces the former per-line
# jq spawn: it runs once for the whole partition regardless of event count.
# Emits one TSV row per run.* event that passes the --since bound -- ts,
# kind, run_id, adapter, note, exit_code, fallback_used(true/false) -- and
# nothing for non-run, filtered-out, malformed, or non-object lines
# (run-stats has never counted malformed rows; that silent skip is kept).
# The --since predicate matches the former shell check exactly: an event is
# dropped only when a bound is set AND its ts is non-empty AND ts < bound,
# so an empty ts is always kept.
pmctl_run_stats_filter_program() {
  cat <<'JQ'
    (try fromjson catch null) as $o
    | if ($o | type) != "object" then empty
      elif (($o.kind // "") | test("^run\\.")) | not then empty
      else
        ($o.ts // "") as $ts
        | if ($since != "" and $ts != "" and $ts < $since) then empty
          else
            [ $ts,
              ($o.kind // ""),
              ($o.payload.run_id // $o.subject_id // ""),
              ($o.payload.adapter // ""),
              ($o.payload.note // ""),
              ($o.payload.exit_code // 0),
              (($o.payload.fallback_used // false) | tostring)
            ] | @tsv
          end
      end
JQ
}

# Consumes the concatenated event stream on stdin (one jq pass, wired in by
# the caller), folding every emitted TSV row into the caller's _rs_* assoc
# arrays. Relies on bash dynamic scoping -- only ever called from within
# pmctl_run_stats, so the _rs_* arrays are visible here -- and on a redirect
# rather than a pipe at the call site so those arrays survive the loop.
pmctl_run_stats_scan_stream() {
  local _rs_rec kind run_id adapter note exit_code fallback
  local -a _rs_f=()
  while IFS= read -r _rs_rec; do
    # NOT `IFS=$'\t' read -r ... <<<`: bash's word-splitting treats tab as
    # "IFS whitespace" and collapses runs of it / trims it at the edges even
    # when IFS is set to tab alone, silently eating the empty `note` field
    # and shifting every field after it. `mapfile -d` splits on the literal
    # byte with no such collapsing.
    mapfile -d $'\t' -t _rs_f <<< "$_rs_rec"
    kind="${_rs_f[1]:-}"; run_id="${_rs_f[2]:-}"
    adapter="${_rs_f[3]:-}"; note="${_rs_f[4]:-}"; exit_code="${_rs_f[5]:-}"
    fallback="${_rs_f[6]:-}"; fallback="${fallback%$'\n'}"
    [[ -n "$run_id" ]] || continue
    _rs_seen["$run_id"]=1
    [[ -n "$adapter" ]] && _rs_adapter["$run_id"]="$adapter"
    [[ "$fallback" == "true" ]] && _rs_fallback["$run_id"]=1
    case "$kind" in
      run.completed|run.failed|run.cancelled)
        _rs_terminal_kind["$run_id"]="$kind"
        _rs_terminal_note["$run_id"]="$note"
        _rs_terminal_exit["$run_id"]="$exit_code"
        ;;
    esac
  done
}

pmctl_run_stats() {
  local repo_root="${1:-}"
  shift || true

  if [[ -z "$repo_root" ]]; then
    printf 'pmctl run-stats: missing repo root\n' >&2
    pmctl_run_stats_usage
    return 2
  fi

  local since="" json=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --since)
        if [[ $# -lt 2 ]]; then
          printf 'pmctl run-stats: --since requires a value\n' >&2
          return 2
        fi
        since="$2"
        # Bare string comparison against event ts below only behaves
        # correctly for values that sort the same lexically as chronologically
        # (ISO-8601 date or date-time). Anything else (e.g. "yesterday",
        # "08/01/2026") would silently compare wrong instead of erroring, so
        # reject it up front rather than producing a misleading report.
        # The T<time> form REQUIRES the trailing Z: event ts values are always
        # UTC/Z-suffixed (see event.schema.json), so a bare local-looking
        # timestamp would silently compare against Z-suffixed data as if it
        # were the same timezone, undercounting or overcounting near the
        # cutoff instead of erroring.
        if [[ ! "$since" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}(T[0-9]{2}:[0-9]{2}:[0-9]{2}Z)?$ ]]; then
          printf 'pmctl run-stats: --since must be YYYY-MM-DD or YYYY-MM-DDTHH:MM:SSZ, got: %s\n' "$since" >&2
          return 2
        fi
        # Shape alone accepts calendar-impossible values (2026-13-99,
        # 2026-02-30): date -d resolves the actual calendar, so this rejects
        # what shape validation cannot, instead of silently producing a
        # successful but meaningless cutoff report.
        if ! date -u -d "$since" >/dev/null 2>&1; then
          printf 'pmctl run-stats: --since is not a valid calendar date/time: %s\n' "$since" >&2
          return 2
        fi
        shift 2
        ;;
      --by-adapter)
        # Adapter breakdown is the only mode this command produces; the flag
        # is accepted for DoD-wording compatibility and is a no-op.
        shift
        ;;
      --json)
        json=1
        shift
        ;;
      -h|--help)
        pmctl_run_stats_usage
        return 0
        ;;
      *)
        printf 'pmctl run-stats: unknown argument: %s\n' "$1" >&2
        pmctl_run_stats_usage
        return 2
        ;;
    esac
  done

  pmctl_run_stats_ensure_state_writer "$repo_root" || return $?

  local proj_dir events_file archive_dir
  proj_dir="$(_sw_project_dir)" || return $?
  events_file="$proj_dir/events.jsonl"
  archive_dir="$proj_dir/archive"

  # Per-run_id state, built from every run.* event seen (bash 5 assoc arrays;
  # this repo is Linux/WSL2-only, see platform-linux-wsl2-only memory).
  declare -A _rs_adapter=() _rs_terminal_kind=() _rs_terminal_note=()
  declare -A _rs_terminal_exit=() _rs_fallback=() _rs_seen=()

  local -a _rs_archives=()
  local _rs_archive_path _rs_program
  if [[ -d "$archive_dir" ]]; then
    while IFS= read -r -d '' _rs_archive_path; do
      _rs_archives+=("$_rs_archive_path")
    done < <(find "$archive_dir" -maxdepth 1 -type f -name 'events-*.jsonl.gz' -print0 2>/dev/null | sort -z)
    unset _rs_archive_path
  fi

  local archive_scanned=true
  if [[ "${#_rs_archives[@]}" -gt 0 ]] && ! command -v gzip >/dev/null 2>&1; then
    printf 'pmctl run-stats: gzip unavailable; reading active events.jsonl only, rotated archives are excluded from this report\n' >&2
    archive_scanned=false
  fi

  # One jq pass over the whole partition: archives first (in the same
  # filename-sorted order find/sort produced), then the active file. A
  # redirect (not a pipe) keeps pmctl_run_stats_scan_stream in this shell so
  # its _rs_* writes survive.
  _rs_program="$(pmctl_run_stats_filter_program)"
  pmctl_run_stats_scan_stream < <(
    {
      if [[ "$archive_scanned" == true ]]; then
        for _rs_archive_path in "${_rs_archives[@]}"; do
          [[ -f "$_rs_archive_path" ]] && gzip -dc "$_rs_archive_path" 2>/dev/null
        done
      fi
      [[ -f "$events_file" ]] && cat "$events_file"
    } | jq -R -r --arg since "$since" "$_rs_program"
  )

  local tmp_dir agg_file
  tmp_dir="$(mktemp -d)" || return 2
  agg_file="$tmp_dir/agg.jsonl"
  # NOT `trap ... RETURN`: bash RETURN traps aren't function-scoped by
  # default (no `shopt -s localtraps` here), so it would still be armed when
  # THIS function's caller later returns, referencing an out-of-scope
  # tmp_dir under `set -u`. Both branches below are this function's only
  # remaining exit paths, so an explicit rm -rf at the end is sufficient.

  declare -A _rs_total=() _rs_ok=() _rs_failed=() _rs_cancelled=()
  declare -A _rs_pv_fail=() _rs_nonzero=() _rs_missing=() _rs_fb_count=()

  local rid a k n e
  for rid in "${!_rs_seen[@]}"; do
    a="${_rs_adapter[$rid]:-unknown}"
    _rs_total["$a"]=$(( ${_rs_total["$a"]:-0} + 1 ))
    k="${_rs_terminal_kind[$rid]:-}"
    if [[ -z "$k" ]]; then
      _rs_missing["$a"]=$(( ${_rs_missing["$a"]:-0} + 1 ))
    else
      n="${_rs_terminal_note[$rid]:-}"
      e="${_rs_terminal_exit[$rid]:-0}"
      case "$k" in
        run.completed)
          if [[ "$n" == "partial" ]]; then
            _rs_pv_fail["$a"]=$(( ${_rs_pv_fail["$a"]:-0} + 1 ))
          else
            _rs_ok["$a"]=$(( ${_rs_ok["$a"]:-0} + 1 ))
          fi
          ;;
        run.failed) _rs_failed["$a"]=$(( ${_rs_failed["$a"]:-0} + 1 )) ;;
        run.cancelled) _rs_cancelled["$a"]=$(( ${_rs_cancelled["$a"]:-0} + 1 )) ;;
      esac
      [[ "$e" != "0" ]] && _rs_nonzero["$a"]=$(( ${_rs_nonzero["$a"]:-0} + 1 ))
    fi
    [[ -n "${_rs_fallback[$rid]:-}" ]] && _rs_fb_count["$a"]=$(( ${_rs_fb_count["$a"]:-0} + 1 ))
  done

  declare -A _rs_adapters_seen=()
  for a in "${!_rs_total[@]}"; do _rs_adapters_seen["$a"]=1; done
  for a in "${!_rs_missing[@]}"; do _rs_adapters_seen["$a"]=1; done

  : > "$agg_file"
  for a in "${!_rs_adapters_seen[@]}"; do
    jq -cn \
      --arg adapter "$a" \
      --argjson total "${_rs_total[$a]:-0}" \
      --argjson ok "${_rs_ok[$a]:-0}" \
      --argjson failed "${_rs_failed[$a]:-0}" \
      --argjson cancelled "${_rs_cancelled[$a]:-0}" \
      --argjson post_verify_fail "${_rs_pv_fail[$a]:-0}" \
      --argjson nonzero_exit "${_rs_nonzero[$a]:-0}" \
      --argjson missing_terminal "${_rs_missing[$a]:-0}" \
      --argjson fallback_used "${_rs_fb_count[$a]:-0}" \
      '{adapter:$adapter,total:$total,ok:$ok,failed:$failed,cancelled:$cancelled,post_verify_fail:$post_verify_fail,nonzero_exit:$nonzero_exit,missing_terminal:$missing_terminal,fallback_used:$fallback_used}' \
      >> "$agg_file"
  done

  local meta_note
  if [[ "$archive_scanned" == true ]]; then
    meta_note="active events.jsonl plus ${#_rs_archives[@]} rotated archive(s) were scanned"
  else
    meta_note="gzip unavailable: only the active events.jsonl was scanned; rotated/archived events are excluded from these counts"
  fi

  if [[ "$json" -eq 1 ]]; then
    # `_meta` carries the archive-scope outcome as data, not just a stderr
    # line — a `--json` report saved as release evidence (see
    # docs/RELEASE_CHECKLIST.md) must not silently look like complete history
    # coverage once separated from the invocation that produced it.
    jq -cs --argjson archive_scanned "$archive_scanned" --arg note "$meta_note" '{
      _meta: {
        schema_version: 1,
        archive_scanned: $archive_scanned,
        note: $note
      },
      adapters: (map({(.adapter): (. | del(.adapter))}) | add // {})
    }' "$agg_file"
  else
    printf 'note: %s\n\n' "$meta_note"
    printf '%-12s %6s %6s %6s %10s %10s %10s %14s %10s\n' \
      adapter total ok failed cancelled pv_fail nonzero missing_term fallback
    jq -r '[.adapter,.total,.ok,.failed,.cancelled,.post_verify_fail,.nonzero_exit,.missing_terminal,.fallback_used] | @tsv' "$agg_file" \
      | sort \
      | while IFS=$'\t' read -r a total ok failed cancelled pv nz missing fb; do
          printf '%-12s %6s %6s %6s %10s %10s %10s %14s %10s\n' \
            "$a" "$total" "$ok" "$failed" "$cancelled" "$pv" "$nz" "$missing" "$fb"
        done
  fi
  rm -rf "$tmp_dir"
}
