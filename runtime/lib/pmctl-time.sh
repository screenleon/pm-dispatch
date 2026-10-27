#!/usr/bin/env bash
# pmctl time -- measure how long any command takes and where the time goes (CC-689, issue #742).
#
#   pmctl time [--runs N] [--json] [--show-output] [--baseline] -- <command> [args...]
#
# Runs the command N times (default 1) with its output discarded and prints wall time per run: the
# first run is "cold", the rest give p50 / p95 / max. A command whose first word is `pmctl` runs this
# checkout's cli/pmctl, so the number belongs to the code under measurement, not to whatever is on
# PATH. Each run gets its own PM_DISPATCH_TIMING_FILE; code that calls pm_timing_phase (timing.sh)
# shows up as per-phase milliseconds (median across the runs, and the cold run's own value).
#
# Time is read from $EPOCHREALTIME so the clock itself starts no process. The report holds durations,
# counts and tool versions only: never the command's output, its arguments, or file contents.
# Exit status: 0 when every run succeeded, 1 when any run failed, 2 on a usage error.

pmctl_time_usage() {
  printf 'usage: pmctl time [--runs N] [--json] [--show-output] [--baseline] -- <command> [args...]\n' >&2
}

# _pmctl_time_us: set PMCTL_TIME_US to the current time in microseconds (integer), with no process.
_pmctl_time_us() {
  local t="${EPOCHREALTIME:-}"
  if [[ -z "$t" ]]; then
    printf -v t '%(%s)T' -1 || return 1
  fi
  t="${t/,/.}"
  if [[ "$t" == *.* ]]; then
    local frac="${t#*.}000000"
    PMCTL_TIME_US=$(( 10#${t%%.*} * 1000000 + 10#${frac:0:6} ))
  else
    PMCTL_TIME_US=$(( 10#$t * 1000000 ))
  fi
}

# _pmctl_time_run <show-output> <timing-file> <argv...>: one measured run.
# Sets PMCTL_TIME_WALL_US, PMCTL_TIME_RC and PMCTL_TIME_END_US.
_pmctl_time_run() {
  local show="$1" file="$2"
  shift 2
  local start end rc=0
  : > "$file"
  _pmctl_time_us; start=$PMCTL_TIME_US
  if [[ "$show" == 1 ]]; then
    PM_DISPATCH_TIMING_FILE="$file" "$@" || rc=$?
  else
    PM_DISPATCH_TIMING_FILE="$file" "$@" >/dev/null 2>&1 || rc=$?
  fi
  _pmctl_time_us; end=$PMCTL_TIME_US
  # The clock can step backwards (NTP); a negative wall time would poison every percentile.
  PMCTL_TIME_WALL_US=$(( end > start ? end - start : 0 ))
  PMCTL_TIME_RC=$rc
  PMCTL_TIME_END_US=$end
}

# _pmctl_time_baseline: PMCTL_TIME_PROC_MS (one external program) and PMCTL_TIME_SUBSHELL_MS (one $(...)),
# the cost the same report has to be read against. Windows makes the first one large.
_pmctl_time_baseline() {
  local n=10 i start end ext
  ext="$(type -P true 2>/dev/null || true)"
  PMCTL_TIME_PROC_MS="" PMCTL_TIME_SUBSHELL_MS=""
  if [[ -n "$ext" ]]; then
    _pmctl_time_us; start=$PMCTL_TIME_US
    for ((i = 0; i < n; i++)); do "$ext" >/dev/null 2>&1 || true; done
    _pmctl_time_us; end=$PMCTL_TIME_US
    PMCTL_TIME_PROC_MS="$(( (end - start) / n / 1000 ))"
  fi
  _pmctl_time_us; start=$PMCTL_TIME_US
  for ((i = 0; i < n; i++)); do : "$(:)"; done
  _pmctl_time_us; end=$PMCTL_TIME_US
  PMCTL_TIME_SUBSHELL_MS="$(( (end - start) / n / 1000 ))"
}

# _pmctl_time_phase_rows <timing file...>: "phase<TAB>median_ms<TAB>cold_ms<TAB>runs" per phase, first-seen
# order, from one timing file per run (in run order, each closed by an "@end<TAB>end-us" line). A phase
# lasts until the next marker, the last one until the command exited. Malformed lines are skipped.
_pmctl_time_phase_rows() {
  LC_ALL=C awk -F'\t' '
    function us(t,   i, f) {
      i = index(t, ".")
      if (i == 0) return t * 1000000
      f = substr(t, i + 1) "000000"
      return substr(t, 1, i - 1) * 1000000 + substr(f, 1, 6)
    }
    function close_run(end_us,   i, stop, d, p, j) {
      # A phase named more than once in a run (a marker inside a loop) counts once, as its total.
      for (i = 1; i <= n; i++) {
        stop = (i < n) ? at[i + 1] : end_us
        d = stop - at[i]; if (d < 0) d = 0
        p = names[i]
        if (!(p in seen)) { seen[p] = 1; order[++k] = p }
        if (!(p in rs)) touched[++t] = p
        rs[p] += d / 1000
      }
      for (j = 1; j <= t; j++) {
        p = touched[j]
        c[p]++; v[p, c[p]] = rs[p]
        if (run == 1) cold[p] = rs[p]
        delete rs[p]
      }
      t = 0; n = 0
    }
    FNR == 1 { run++ }
    $1 == "@end" { close_run($2 + 0); next }
    NF == 2 && $1 ~ /^[a-z0-9_.-]+$/ && $2 ~ /^[0-9]+(\.[0-9]+)?$/ { n++; names[n] = $1; at[n] = us($2) }
    END {
      for (j = 1; j <= k; j++) {
        p = order[j]; m = c[p]
        for (a = 2; a <= m; a++) {
          x = v[p, a]; b = a - 1
          while (b >= 1 && v[p, b] > x) { v[p, b + 1] = v[p, b]; b-- }
          v[p, b + 1] = x
        }
        med = (m % 2) ? v[p, (m + 1) / 2] : (v[p, m / 2] + v[p, m / 2 + 1]) / 2
        printf "%s\t%.1f\t%s\t%d\n", p, med, (p in cold) ? sprintf("%.1f", cold[p]) : "-", m
      }
    }' "$@"
}

pmctl_time() {
  local repo_root="${1:-}"
  shift || true
  local runs=1 json=0 show=0 baseline=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --runs)
        if ! [[ $# -ge 2 && "$2" =~ ^[0-9]+$ ]] || (( 10#$2 < 1 || 10#$2 > 1000 )); then
          printf 'pmctl time: --runs needs an integer from 1 to 1000\n' >&2
          return 2
        fi
        runs=$((10#$2)); shift 2 ;;
      --json) json=1; shift ;;
      --show-output) show=1; shift ;;
      --baseline) baseline=1; shift ;;
      --) shift; break ;;
      -h|--help) pmctl_time_usage; return 0 ;;
      *) printf 'pmctl time: unknown option %s (the command goes after --)\n' "$1" >&2
         pmctl_time_usage; return 2 ;;
    esac
  done
  [[ $# -gt 0 ]] || { printf 'pmctl time: a command is required after --\n' >&2; pmctl_time_usage; return 2; }
  if [[ "$json" -eq 1 && "$show" -eq 1 ]]; then
    printf 'pmctl time: --json and --show-output cannot be combined (the command output would corrupt the JSON)\n' >&2
    return 2
  fi

  local -a argv=("$@")
  if [[ "${argv[0]}" == pmctl ]]; then
    argv=(bash "$repo_root/cli/pmctl" "${argv[@]:1}")
  fi

  local work
  work="$(mktemp -d "${TMPDIR:-/tmp}/pmctl-time-XXXXXX")" \
    || { printf 'pmctl time: cannot create a work directory\n' >&2; return 2; }
  trap 'rm -rf "$work"; exit 130' INT TERM

  local i failed=0 tfile
  local -a wall_list=()
  for ((i = 1; i <= runs; i++)); do
    printf -v tfile '%s/timing.%04d.tsv' "$work" "$i"
    _pmctl_time_run "$show" "$tfile" "${argv[@]}"
    wall_list+=("$PMCTL_TIME_WALL_US")
    [[ "$PMCTL_TIME_RC" -eq 0 ]] || failed=$((failed + 1))
    # Closes the run for the aggregator: the last phase lasts until the command exited.
    printf '@end\t%s\n' "$PMCTL_TIME_END_US" >> "$tfile"
  done
  # One awk over every run, after the loop: no process starts between two measured runs.
  local phase_rows
  phase_rows="$(_pmctl_time_phase_rows "$work"/timing.*.tsv)"
  rm -rf "$work"
  trap - INT TERM
  [[ "$baseline" -eq 0 ]] || _pmctl_time_baseline

  # warm = every run but the first; with one run there is nothing to call warm. Nearest-rank percentiles.
  local cold_ms stats="" p50="" p95="" max="" warm_n=0
  printf -v cold_ms '%d.%d' $((wall_list[0] / 1000)) $(((wall_list[0] % 1000) / 100))
  if [[ ${#wall_list[@]} -gt 1 ]]; then
    stats="$(printf '%s\n' "${wall_list[@]:1}" | LC_ALL=C sort -n | LC_ALL=C awk '
      { v[NR] = $1 }
      END {
        r50 = int(0.50 * NR); if (r50 < 0.50 * NR) r50++; if (r50 < 1) r50 = 1
        r95 = int(0.95 * NR); if (r95 < 0.95 * NR) r95++; if (r95 < 1) r95 = 1
        printf "%.1f %.1f %.1f %d\n", v[r50] / 1000, v[r95] / 1000, v[NR] / 1000, NR
      }')"
    read -r p50 p95 max warm_n <<< "$stats"
  fi

  local os bash_v rev
  os="$(uname -s 2>/dev/null || echo unknown)"
  bash_v="${BASH_VERSION:-unknown}"
  rev="$(git -C "$repo_root" rev-parse --short HEAD 2>/dev/null || echo unknown)"

  local pn pmed pcold pcount first=1
  if [[ "$json" -eq 1 ]]; then
    printf '{"kind":"pmctl_time_v1","runs":%d,"failed_runs":%d,"cold_ms":%s' "$runs" "$failed" "$cold_ms"
    if [[ -n "$stats" ]]; then
      printf ',"warm":{"runs":%d,"p50_ms":%s,"p95_ms":%s,"max_ms":%s}' "$warm_n" "$p50" "$p95" "$max"
    fi
    printf ',"phases":['
    while IFS=$'\t' read -r pn pmed pcold pcount; do
      [[ -n "$pn" ]] || continue
      [[ "$first" -eq 1 ]] || printf ','
      first=0
      printf '{"phase":"%s","median_ms":%s,"cold_ms":%s,"runs":%d}' "$pn" "$pmed" "${pcold/#-/null}" "$pcount"
    done <<< "$phase_rows"
    printf ']'
    if [[ "$baseline" -eq 1 ]]; then
      printf ',"baseline":{"process_start_ms":%s,"subshell_ms":%s}' "${PMCTL_TIME_PROC_MS:-null}" "${PMCTL_TIME_SUBSHELL_MS:-null}"
    fi
    printf ',"env":{"os":"%s","bash":"%s","revision":"%s"}}\n' "$os" "$bash_v" "$rev"
  else
    printf 'pmctl time: %d run(s), %d failed\n' "$runs" "$failed"
    printf '  cold  %s ms\n' "$cold_ms"
    if [[ -n "$stats" ]]; then
      printf '  warm  p50 %s ms   p95 %s ms   max %s ms   (%d runs)\n' "$p50" "$p95" "$max" "$warm_n"
    fi
    if [[ -n "$phase_rows" ]]; then
      printf '  phases (median ms across runs; cold run in brackets):\n'
      while IFS=$'\t' read -r pn pmed pcold pcount; do
        [[ -n "$pn" ]] || continue
        printf '    %-28s %10s   [%s]\n' "$pn" "$pmed" "${pcold:--}"
      done <<< "$phase_rows"
    else
      printf '  phases: none reported (the command does not call pm_timing_phase)\n'
    fi
    if [[ "$baseline" -eq 1 ]]; then
      printf '  baseline: external program start %s ms, command-substitution subshell %s ms\n' \
        "${PMCTL_TIME_PROC_MS:--}" "${PMCTL_TIME_SUBSHELL_MS:--}"
    fi
    printf '  env: %s, bash %s, revision %s\n' "$os" "$bash_v" "$rev"
  fi

  [[ "$failed" -eq 0 ]]
}
