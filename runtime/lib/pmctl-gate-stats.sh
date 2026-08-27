#!/usr/bin/env bash
# pmctl gate stats — read-only operational-cost aggregation over PR-gate runs
# already on disk. It answers "is the gate's cost tracking its value?" with
# numbers: wall time, verdict / tier / mode mix, per-reviewer finding counts by
# severity, protocol-failure distribution, and a heuristic rounds-to-GO
# clustering.
#
# Read-only consumer, same discipline as pmctl run-stats: never calls a state
# writer, events_append, or anything that mutates the state store. Its only
# state-path dependency is locating the project's runs/ directory.
#
# Two sources are merged, mirroring run-stats' archive + active scan:
#   frozen  — rows in runs-summary.jsonl (kind == gate), written by the
#             `pmctl artifacts gc` summariser before a run dir is deleted.
#   live    — runs/gate-*/ directories not yet gc'd, parsed here from the
#             published gate-*.md frontmatter, its .assurance.json sidecar, and
#             the gate-protocol-attempts-*.jsonl log.
# A run present in both is counted once (frozen row wins; the live dir is the
# same data mid-summary).
#
# Derivability is labelled as data, never faked:
#   wall_time      exact      (assurance created/finished delta, or mtime span)
#   rounds_to_go   heuristic  (clusters live gates by repo key + base commit +
#                              time order; unrelated rounds sharing a base
#                              commit in one window can mis-merge)
#   tokens         deferred   (usage-tracker.jsonl entries carry no gate id;
#                              per-gate token attribution needs a capture step)
#
# Cost model: frozen rows (already summarised by `pmctl artifacts gc` into
# runs-summary.jsonl) are read in one jq pass and are effectively free. Only
# un-gc'd run dirs are parsed live, one jq fork each. `pmctl artifacts gc` is
# the mechanism that keeps the live set small; on a machine that gc's
# regularly it stays in the tens. This is an on-demand report, never a hot
# path or a loop body, so per-gate parsing of the live tail is acceptable --
# unlike run-stats / trace tail, whose unbounded events.jsonl forced a single
# streaming pass.

PMCTL_GATE_STATS_SCHEMA_VERSION=1

pmctl_gate_stats_usage() {
  printf 'usage: pmctl gate stats [--since <ISO8601-or-date>] [--json] [--cd <dir>]\n' >&2
}

# Resolve the runs/ directory for the target work dir. Reuses the same probe
# pmctl artifacts uses so both commands agree on the partition layout.
pmctl_gate_stats_runs_dir() {
  local work_dir="${1:-}"
  if declare -F pmctl_artifacts_runs_dir >/dev/null 2>&1; then
    pmctl_artifacts_runs_dir "$work_dir"
    return $?
  fi
  return 2
}

# The jq program that turns one live gate run's raw artifacts into a
# gate_stat_row. Everything -- frontmatter scalars, the nested `reviewers:`
# verdict map, reviewer_result_v1 finding blocks, the assurance sidecar, and
# the protocol-attempts log -- is parsed in this single pass so a run dir costs
# one jq fork, not six (see the per-item-subprocess note above).
pmctl_gate_stats_live_row_program() {
  cat <<'JQ'
    ($md | split("\n")) as $lines
    | ([ $lines | to_entries[] | select(.value == "---") | .key ]) as $dashes
    | (if ($dashes | length) >= 2 then $lines[($dashes[0] + 1):$dashes[1]] else [] end) as $fm
    | (reduce $fm[] as $l ({};
        ($l | [ capture("^(?<k>[a-z_]+):[ ]*(?<v>.*)$") ] | first) as $m
        | if $m then .[$m.k] = ($m.v | sub("[ \r]+$"; "")) else . end)) as $front
    # reviewers: is a nested map -- take the indented lines that follow it,
    # stopping at the first line that is not indented (e.g. escalation:).
    | ([ $fm | to_entries[] | select(.value == "reviewers:") | .key ] | first) as $rix
    | (if $rix == null then {}
       else (reduce ($fm[($rix + 1):][]) as $l ({stop: false, m: {}};
              if .stop then .
              elif ($l | test("^[ ]+[A-Za-z0-9_-]+:"))
              then ($l | capture("^[ ]+(?<k>[A-Za-z0-9_-]+):[ ]*(?<v>.+)$")) as $m
                   | if $m then .m[$m.k] = $m.v else . end
              else .stop = true end) | .m)
       end) as $reviewers
    # reviewer_result_v1 fenced blocks -> findings grouped by severity.
    # All-or-nothing on parse failure: if any block has no closing fence or is
    # not valid JSON, the whole result degrades to the string "unavailable"
    # rather than a partial tally that reads as complete. This matches
    # gate_result_findings_by_severity (jq -s, which fails the whole slurp on
    # one bad block); the inline form here must not silently skip a bad block.
    | ([ $lines | to_entries[] | select(.value == "```reviewer_result_v1") | .key ]) as $rstarts
    | ([ $rstarts[] as $s
         | ($lines[($s + 1):] | index("```")) as $rel
         | if $rel then ($lines[($s + 1):($s + 1 + $rel)] | join("\n")) else null end
       ]) as $rtexts
    | (if ($rtexts | length) == 0 then "unavailable"
       elif ($rtexts | any(. == null or (try (fromjson | false) catch true))) then "unavailable"
       else [ $rtexts[] | fromjson | {reviewer, counts: (((.findings // []) | group_by(.severity)
              | map({(.[0].severity): length}) | add) // {})} ]
       end) as $findings
    | ($assurance | (fromjson? // null)) as $a
    | ($a.subject.created_at // null) as $created
    | ($a.subject.finished_at // null) as $finished
    | (if ($created != null and $finished != null)
       then (($finished | fromdateiso8601) - ($created | fromdateiso8601))
            | (if . >= 0 then . else null end)
       else null end) as $dur_iso
    | (if $dur_iso != null then $dur_iso
       elif ($mtime_dur | type) == "number" and $mtime_dur > 0 then $mtime_dur
       else null end) as $duration
    | ([ ($protocol | split("\n")[] | select(length > 0) | (fromjson? // empty)) ]) as $pa
    | (reduce $pa[] as $x ({};
        ($x.outcome // "unknown") as $o
        | .[$o] = ((.[$o] // 0) + 1)
        | if ($o == "retryable-failure" and (($x.reason // "") != ""))
          then .reasons[$x.reason] = ((.reasons[$x.reason] // 0) + 1)
          else . end)) as $protocol_tally
    | ($front.final // "") as $final
    | {
        run_id: $run_id,
        source: "live",
        final: (if $final == "" then null else $final end),
        status: (if $final == "" then "incomplete_source" else "complete" end),
        tier: ($front.tier // null | if . == "" then null else . end),
        mode: ($front.mode // null | if . == "" then null else . end),
        most_severe: ($front.most_severe // null | if . == "" then null else . end),
        duration_seconds: $duration,
        reviewers: $reviewers,
        findings_by_severity: $findings,
        protocol: $protocol_tally,
        repo_key: ($a.subject.repository.key // null),
        base_commit: ($a.subject.base.commit // null),
        created_at: $created
      }
JQ
}

# Build one gate_stat_row JSON object for a live run directory. Prints nothing
# and returns 1 if the directory has no gate result file at all (not a gate
# run / no artifacts yet) so the caller can skip it.
pmctl_gate_stats_live_row() {
  local run_dir="${1:-}" run_id="${2:-}"
  local gate_file assurance_file protocol_file f
  gate_file=""
  protocol_file=""
  # One find over .gate-results for both the result file and the protocol log.
  while IFS= read -r f; do
    case "$f" in
      */gate-protocol-attempts-*.jsonl) protocol_file="$f" ;;
      */gate-*.md) [[ "$f" == *.assurance.json ]] || gate_file="$f" ;;
    esac
  done < <(find "$run_dir/.gate-results" -maxdepth 1 -type f \
    \( -name 'gate-*.md' -o -name 'gate-protocol-attempts-*.jsonl' \) 2>/dev/null | sort)
  [[ -n "$gate_file" ]] || return 1
  assurance_file="$gate_file.assurance.json"

  # Drift-tolerant mtime span, same helper the gc summariser uses. Computed
  # unconditionally (one find per run dir): the jq program only consults it
  # when the assurance sidecar has no created_at/finished_at pair, but an
  # assurance file can exist without those fields, so the presence of the file
  # is not a safe reason to skip it.
  local mtime_dur="null" d
  if declare -F _pmctl_artifacts_run_duration_seconds >/dev/null 2>&1; then
    d="$(_pmctl_artifacts_run_duration_seconds "$run_dir")"
    [[ "$d" =~ ^[0-9]+$ ]] && mtime_dur="$d"
  fi

  jq -cn \
    --arg run_id "$run_id" \
    --rawfile md "$gate_file" \
    --rawfile assurance <([[ -s "$assurance_file" ]] && cat "$assurance_file" || printf 'null') \
    --rawfile protocol <([[ -n "$protocol_file" && -s "$protocol_file" ]] && cat "$protocol_file" || printf '') \
    --argjson mtime_dur "$mtime_dur" \
    "$(pmctl_gate_stats_live_row_program)"
}

# Normalise one runs-summary.jsonl gate row (already summarised) into the same
# gate_stat_row shape. Frozen rows lack mode / protocol / base commit / created
# time, so those fields are null and the row cannot join a round cluster.
pmctl_gate_stats_frozen_row() {
  jq -c '
    select((.kind // "") == "gate")
    | {
        run_id: (.run_id // ""),
        source: "frozen",
        final: (.gate.final // null),
        status: (if (.gate.final // "") == "" then "incomplete_source" else "complete" end),
        tier: (.gate.tier // null),
        mode: null,
        most_severe: (.gate.most_severe // null),
        duration_seconds: (.duration_seconds // null),
        reviewers: (.gate.reviewers // {}),
        findings_by_severity: (
          if (.gate.findings_by_severity | type) == "array"
          then .gate.findings_by_severity else "unavailable" end),
        protocol: {},
        repo_key: null,
        base_commit: null,
        created_at: null
      }
  '
}

# The single jq program that folds every gate_stat_row into the report
# envelope. Kept as one -s pass so adding a metric touches one output key.
pmctl_gate_stats_aggregate_program() {
  cat <<'JQ'
    def verdict_bucket:
      if . == "GO" then "GO"
      elif . == "NO-GO" then "NO-GO"
      elif . == null then "incomplete_source"
      else "other" end;

    def wall_stats($xs):
      ($xs | sort) as $s
      | ($s | length) as $n
      | if $n == 0 then {count: 0, total_seconds: 0, mean_seconds: null, p50_seconds: null, max_seconds: null}
        else {
          count: $n,
          total_seconds: ($s | add),
          mean_seconds: (($s | add) / $n | floor),
          p50_seconds: $s[(($n - 1) / 2) | floor],
          max_seconds: $s[$n - 1]
        } end;

    # --since cutoff, applied before any counting. When a row carries a full
    # assurance created_at, the cutoff is time-aware: the row is kept iff
    # created_at >= the supplied bound (plain lexicographic compare -- both are
    # Z-normalised ISO-8601, and a date-only bound like "2026-08-10" correctly
    # sorts before every timestamp on that day). Rows with no timestamp (frozen
    # runs-summary rows; live runs whose assurance sidecar lacks the field)
    # fall back to the date embedded in the gate run id (gate-YYYYmmdd-...) and
    # are compared at day granularity only -- a sub-day bound cannot tell
    # whether such a row is before or after it, so it is kept rather than
    # silently dropped. A row whose date cannot be derived at all is kept.
    def keep_row($since):
      if $since == "" then true
      elif .created_at != null then (.created_at >= $since)
      else (.run_id | ltrimstr("gate-")) as $r
        | if ($r[0:8] | test("^[0-9]{8}$"))
          then ("\($r[0:4])-\($r[4:6])-\($r[6:8])") >= ($since[0:10])
          else true end
      end;

    ( . | map(select(keep_row($since))) ) as $rows
    | ($rows | map(select(.status == "complete"))) as $ok
    | {
        _meta: {
          schema_version: $schema_version,
          since: (if $since == "" then null else $since end),
          since_cutoff: (
            if $since == "" then null
            elif ($since | test("T")) then
              "time-aware for rows with an assurance created_at; rows without one (frozen summary rows, live runs missing the field) are filtered at day granularity"
            else "day granularity" end),
          scan: {
            frozen: ($rows | map(select(.source == "frozen")) | length),
            live: ($rows | map(select(.source == "live")) | length),
            incomplete_source: ($rows | map(select(.status == "incomplete_source")) | length)
          },
          derivability: {
            wall_time: "exact-or-mtime-span",
            rounds_to_go: "heuristic-base-commit",
            tokens: "deferred-no-gate-id-linkage"
          }
        },
        totals: {
          gates: ($rows | length),
          complete: ($ok | length),
          incomplete_source: ($rows | map(select(.status == "incomplete_source")) | length)
        },
        by_verdict: (
          reduce $ok[] as $r ({};
            ($r.final | verdict_bucket) as $b | .[$b] = ((.[$b] // 0) + 1))),
        by_tier: (
          reduce $ok[] as $r ({};
            ($r.tier // "unknown") as $t | .[$t] = ((.[$t] // 0) + 1))),
        by_mode: (
          reduce ($ok[] | select(.mode != null)) as $r ({};
            .[$r.mode] = ((.[$r.mode] // 0) + 1))),
        by_reviewer: (
          reduce $ok[] as $r ({};
            reduce ($r.reviewers | to_entries[]) as $rv (.;
              .[$rv.key].verdicts[$rv.value] = ((.[$rv.key].verdicts[$rv.value] // 0) + 1))
            | if ($r.findings_by_severity | type) == "array"
              then reduce $r.findings_by_severity[] as $f (.;
                reduce ($f.counts // {} | to_entries[]) as $c (.;
                  .[$f.reviewer].findings[$c.key] = ((.[$f.reviewer].findings[$c.key] // 0) + $c.value)))
              else . end)),
        protocol_failures: (
          reduce ($rows[] | select(.protocol != null and (.protocol | length) > 0)) as $r
            ({accepted: 0, "retryable-failure": 0, other: 0, reasons: {}};
              reduce ($r.protocol | to_entries[]) as $e (.;
                if $e.key == "reasons"
                then reduce ($e.value | to_entries[]) as $rn (.;
                  .reasons[$rn.key] = ((.reasons[$rn.key] // 0) + $rn.value))
                elif $e.key == "accepted" then .accepted += $e.value
                elif $e.key == "retryable-failure" then ."retryable-failure" += $e.value
                else .other += $e.value end))),
        wall_time: wall_stats([$rows[] | select(.duration_seconds != null) | .duration_seconds]),
        round_clusters: (
          [$rows[] | select(.source == "live" and .repo_key != null and .base_commit != null)]
          | group_by([.repo_key, .base_commit])
          | map(
              (sort_by(.created_at // "")) as $g
              | ($g | map(.final == "GO") | index(true)) as $go_ix
              | {
                  base_commit: ($g[0].base_commit[0:8]),
                  clustering: "heuristic-base-commit",
                  gate_ids: ($g | map(.run_id)),
                  rounds: (if $go_ix == null then ($g | length) else ($go_ix + 1) end),
                  reached_go: ($go_ix != null)
                })
          | sort_by(.base_commit))
      }
JQ
}

pmctl_gate_stats_render_text() {
  jq -r '
    def secs2h($s): if $s == null then "-"
      else ($s / 60 | floor) as $m
        | (if $m >= 60 then "\($m / 60 | floor)h\($m % 60)m" else "\($m)m\($s % 60)s" end) end;
    "gate stats — since \(._meta.since // "all")  (frozen: \(._meta.scan.frozen), live: \(._meta.scan.live), incomplete: \(._meta.scan.incomplete_source))",
    "",
    "verdicts   " + ([.by_verdict | to_entries[] | "\(.key) \(.value)"] | join("   ")),
    "tiers      " + ([.by_tier | to_entries[] | "\(.key) \(.value)"] | join("   ")),
    "modes      " + (([.by_mode | to_entries[] | "\(.key) \(.value)"] | join("   ")) + "   (live only)"),
    "",
    "reviewers",
    ([.by_reviewer | to_entries[]
      | ((.value.verdicts // {}) | to_entries | map("\(.key):\(.value)") | join(",")) as $v
      | ((.value.findings // {}) | to_entries | map("\(.key):\(.value)") | join(",")) as $f
      | "  \(.key)  verdicts=\($v)  findings=\(if $f == "" then "-" else $f end)"]
      | join("\n")),
    "",
    # Text mode caps the protocol-reason list to the five most common; --json
    # carries the full map.
    "protocol   accepted \(.protocol_failures.accepted)   retryable-failure \(.protocol_failures."retryable-failure")"
      + (([.protocol_failures.reasons | to_entries[]] | sort_by(-.value)) as $r
         | if ($r | length) > 0
           then "\n  top reasons: " + (($r[0:5] | map("\(.key) (\(.value))") | join("; "))
             + (if ($r | length) > 5 then "; …\(($r | length) - 5) more" else "" end))
           else "" end) + "   (live only)",
    "wall time  n=\(.wall_time.count)  mean \(secs2h(.wall_time.mean_seconds))  p50 \(secs2h(.wall_time.p50_seconds))  max \(secs2h(.wall_time.max_seconds))",
    "",
    "rounds to GO  (heuristic: base-commit + time clustering)",
    ( .round_clusters as $rc
      | if ($rc | length) == 0 then "  (none)"
        else
          ($rc | map(select(.reached_go))) as $reached
          | ($rc | map(select(.reached_go | not)) | length) as $open
          | ($reached | map(.rounds) | group_by(.)
             | map("\(.[0])->\(length)") | join("  ")) as $hist
          | "  distribution (rounds -> clusters): \($hist)\n  reached GO: \($reached | length) clusters   still open: \($open)"
        end )
  '
}

pmctl_gate_stats() {
  local repo_root="${1:-}"
  shift || true

  if [[ -z "$repo_root" ]]; then
    printf 'pmctl gate stats: missing repo root\n' >&2
    pmctl_gate_stats_usage
    return 2
  fi

  local since="" json=0 work_dir="."
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --since)
        if [[ $# -lt 2 ]]; then
          printf 'pmctl gate stats: --since requires a value\n' >&2
          return 2
        fi
        since="$2"
        # Same lexicographic-safe cutoff rule as pmctl run-stats
        # (runtime/lib/pmctl-run-stats.sh, which carries the full rationale):
        # only an ISO-8601 date or a Z-suffixed date-time sorts chronologically
        # as a string. Kept inline rather than extracted -- exactly two aligned
        # consumers (run-stats, gate stats) and `trace tail` deliberately
        # validates its --since differently, so a shared primitive would fit
        # none of the three cleanly.
        if [[ ! "$since" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}(T[0-9]{2}:[0-9]{2}:[0-9]{2}Z)?$ ]]; then
          printf 'pmctl gate stats: --since must be YYYY-MM-DD or YYYY-MM-DDTHH:MM:SSZ, got: %s\n' "$since" >&2
          return 2
        fi
        if ! date -u -d "$since" >/dev/null 2>&1; then
          printf 'pmctl gate stats: --since is not a valid calendar date/time: %s\n' "$since" >&2
          return 2
        fi
        shift 2
        ;;
      --json)
        json=1
        shift
        ;;
      --cd)
        if [[ $# -lt 2 || -z "${2:-}" ]]; then
          printf 'pmctl gate stats: --cd requires a work dir\n' >&2
          return 2
        fi
        work_dir="$2"
        shift 2
        ;;
      -h|--help)
        pmctl_gate_stats_usage
        return 0
        ;;
      *)
        printf 'pmctl gate stats: unknown argument: %s\n' "$1" >&2
        pmctl_gate_stats_usage
        return 2
        ;;
    esac
  done

  if [[ ! -d "$work_dir" ]]; then
    printf 'pmctl gate stats: work dir not found: %s\n' "$work_dir" >&2
    return 2
  fi

  if declare -F pmctl_artifacts_ensure_state_paths >/dev/null 2>&1; then
    pmctl_artifacts_ensure_state_paths "$repo_root" || return $?
  fi

  local runs_dir
  runs_dir="$(pmctl_gate_stats_runs_dir "$work_dir" 2>/dev/null)" || {
    printf 'pmctl gate stats: cannot resolve runs directory for %s\n' "$work_dir" >&2
    return 2
  }

  local summary_file=""
  [[ -n "$runs_dir" ]] && summary_file="$(dirname "$runs_dir")/runs-summary.jsonl"

  local tmp_dir rows_file frozen_file
  tmp_dir="$(mktemp -d)" || return 2
  rows_file="$tmp_dir/rows.jsonl"
  frozen_file="$tmp_dir/frozen.jsonl"
  : > "$rows_file"
  : > "$frozen_file"

  # --- frozen rows (runs-summary.jsonl; may not exist) ---
  # One jq pass normalises every gate row; the --since cutoff is applied later
  # in the aggregate program uniformly with the live rows.
  declare -A _gs_frozen_ids=()
  if [[ -n "$summary_file" && -s "$summary_file" ]]; then
    pmctl_gate_stats_frozen_row < "$summary_file" > "$frozen_file" 2>/dev/null || true
    if [[ -s "$frozen_file" ]]; then
      cat "$frozen_file" >> "$rows_file"
      local rid
      while IFS= read -r rid; do
        [[ -n "$rid" ]] && _gs_frozen_ids["$rid"]=1
      done < <(jq -r 'select(.run_id != "") | .run_id' "$frozen_file")
    fi
  fi

  # --- live rows (run dirs not already summarised) ---
  # The unit is the gate run dir (tens to low hundreds); a couple of jq calls
  # per dir is acceptable for an on-demand report. --since is not filtered here
  # -- the aggregate program does it for frozen and live alike.
  if [[ -d "$runs_dir" ]]; then
    local d run_id live_row
    for d in "$runs_dir"/gate-*/; do
      [[ -d "$d" ]] || continue
      run_id="$(basename "$d")"
      [[ -n "${_gs_frozen_ids[$run_id]:-}" ]] && continue
      live_row="$(pmctl_gate_stats_live_row "${d%/}" "$run_id" 2>/dev/null)" || continue
      [[ -n "$live_row" ]] || continue
      printf '%s\n' "$live_row" >> "$rows_file"
    done
  fi

  local envelope
  envelope="$(jq -s \
    --argjson schema_version "$PMCTL_GATE_STATS_SCHEMA_VERSION" \
    --arg since "$since" \
    "$(pmctl_gate_stats_aggregate_program)" "$rows_file")" || {
    rm -rf "$tmp_dir"
    printf 'pmctl gate stats: aggregation failed\n' >&2
    return 1
  }

  if [[ "$json" -eq 1 ]]; then
    printf '%s\n' "$envelope"
  else
    printf '%s\n' "$envelope" | pmctl_gate_stats_render_text
  fi
  rm -rf "$tmp_dir"
}
