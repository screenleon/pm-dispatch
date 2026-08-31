#!/usr/bin/env bash
# Measure where a pr-gate run actually spends its time.
#
# A gate run against a stub reviewer does no model work at all, so every second
# it burns is the gate's own shell work. Counting forks alone is misleading: a
# run forks roughly a thousand children yet spends almost none of its time on
# the forking. What matters is the time spent *inside* those children, which is
# what `--mode time` reports.
#
# Three views, all over the same subject (one pr-gate suite case):
#
#   time  (default)  per-binary call count, total seconds, mean milliseconds
#   exec             per-binary counts plus the leading argv of each call, so
#                    calls can be clustered back to their call sites
#   bash             executed-simple-command counts per source:line, for the
#                    work that never leaves bash
#
# Measurement fidelity
# --------------------
# The PATH wrappers preserve argv, stdin/stdout/stderr, and exit code, so the
# subject's behaviour is unchanged and the *counts* are exact. Each wrapper
# still costs an extra fork, so an instrumented run takes longer than a bare
# one: read durations from `--mode time`'s per-binary totals, never from the
# wall time of an instrumented run.
#
# This is an operator diagnostic, not a regression oracle. The repository
# already locks a specific optimisation in place with a counting PATH shim --
# see tests/shell/test-pmctl-trace.sh, case_trace_tail_single_jq_pass -- and a
# slice that reduces the gate's jq invocations should add a lock of that shape
# rather than depend on this script running in CI.
#
# A previous census that was interrupted without tearing down its children will
# keep forking into the shared log and silently inflate the next run's numbers.
# This script therefore runs its subject in a fresh session, kills that whole
# process group on exit, and refuses to start while another census is alive.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
case_filter="tier-detection"
mode="time"
deadline=900
out_dir=""
suite="tests/shell/test-pr-gate.sh"

usage() {
  printf 'usage: %s [--suite <path>] [--case <filter>] [--mode time|exec|bash] [--timeout <seconds>] [--out <dir>]\n' "$0" >&2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --suite)
      [[ $# -ge 2 && -n "$2" ]] || { usage; exit 2; }
      suite="$2"; shift 2 ;;
    --case)
      [[ $# -ge 2 && -n "$2" ]] || { usage; exit 2; }
      case_filter="$2"; shift 2 ;;
    --mode)
      [[ $# -ge 2 ]] || { usage; exit 2; }
      case "$2" in time|exec|bash) mode="$2" ;; *) usage; exit 2 ;; esac
      shift 2 ;;
    --timeout)
      [[ $# -ge 2 && "$2" =~ ^[1-9][0-9]*$ ]] || { usage; exit 2; }
      deadline="$2"; shift 2 ;;
    --out)
      [[ $# -ge 2 && -n "$2" ]] || { usage; exit 2; }
      out_dir="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) usage; exit 2 ;;
  esac
done

# Resolve the subject before doing any setup, so a typo fails immediately
# rather than after a lock and a temporary tree have been created.
case "$suite" in
  /*) suite_path="$suite" ;;
  *)  suite_path="$repo_root/$suite" ;;
esac
if [[ ! -r "$suite_path" ]]; then
  printf 'gate-subprocess-census: subject suite is not readable: %s\n' "$suite_path" >&2
  exit 2
fi

work_dir="$(mktemp -d "${TMPDIR:-/tmp}/gate-census.XXXXXX")"
lock_file="${TMPDIR:-/tmp}/gate-subprocess-census.lock"
census_log="$work_dir/census.log"
suite_log="$work_dir/suite.out"
bin_dir="$work_dir/bin"
mkdir -p "$bin_dir"

# Refuse to run while another census holds the lock: two overlapping censuses
# fork into each other's measurements and each one's cleanup can tear down the
# other's subject. A pid file read-then-written is not enough -- two launches
# can both observe it absent -- so ownership is an flock held on a descriptor
# for the whole run and released by the kernel when this process exits.
if ! command -v flock >/dev/null 2>&1; then
  printf 'gate-subprocess-census: flock is required to guarantee single-census exclusion\n' >&2
  rm -rf -- "$work_dir"
  exit 1
fi
exec 8>>"$lock_file"
if ! flock -n 8; then
  printf 'gate-subprocess-census: another census holds %s; wait for it to finish\n' \
    "$lock_file" >&2
  rm -rf -- "$work_dir"
  exit 1
fi

subject_pgid=""
# shellcheck disable=SC2329  # invoked indirectly by the EXIT/INT/TERM trap below.
cleanup() {
  # Killing an already-reaped group fails, and an `&&` list ending in that
  # failure would abort this function under `set -e` before `return 0` -- which
  # replaces the script's real exit status with 1 even on a clean measurement.
  if [[ -n "$subject_pgid" ]]; then
    kill -9 -- "-$subject_pgid" 2>/dev/null || true
  fi
  # The lock is released when fd 8 closes at exit; dropping it here as well
  # would open a window where a second census starts before the subject's
  # process group has been reaped.
  return 0
}
trap cleanup EXIT INT TERM

WRAPPED_BINARIES=(jq git awk grep sed sha256sum cat mktemp)

write_wrappers() {
  local tool real
  for tool in "${WRAPPED_BINARIES[@]}"; do
    real="$(command -v "$tool" 2>/dev/null)" || continue
    case "$mode" in
      time)
        # bash's EPOCHREALTIME times the child without forking a clock.
        cat > "$bin_dir/$tool" <<EOF
#!/bin/bash
__started=\$EPOCHREALTIME
"$real" "\$@"
__rc=\$?
{ printf '%s %s %s\n' "$tool" "\$__started" "\$EPOCHREALTIME" >> "$census_log" ; } 2>/dev/null
exit "\$__rc"
EOF
        ;;
      exec)
        # dash starts faster than bash and exec keeps the process count honest.
        # Record only the flags: a jq or awk program is a multi-line argument
        # and would spill its own source across the log, so its keywords would
        # then be counted as if they were invoked binaries. Flags are always
        # single-line, and they are what distinguishes one call site from
        # another. The CENSUS marker lets the tally ignore anything that is not
        # a record this wrapper wrote.
        cat > "$bin_dir/$tool" <<EOF
#!/bin/dash
__flags=""
for __arg in "\$@"; do
  case "\$__arg" in -*) __flags="\$__flags \$__arg" ;; esac
done
{ printf 'CENSUS\t%s\t%s\n' "$tool" "\$__flags" >> "$census_log" ; } 2>/dev/null
exec "$real" "\$@"
EOF
        ;;
    esac
    chmod +x "$bin_dir/$tool"
  done
}

write_bash_wrapper() {
  # Trace only the gate itself, and send xtrace to its own descriptor so the
  # gate's stderr -- which the gate's own result verification reads -- stays
  # byte-for-byte what it would be without instrumentation.
  # Match the gate by exact basename: a substring match also catches the
  # suite driver (tests/shell/test-pr-gate.sh) and would trace the harness
  # instead of the subject.
  cat > "$bin_dir/bash" <<EOF
#!/bin/bash
case "\${1:-}" in
  */pr-gate.sh|pr-gate.sh)
    if [ -f "\$1" ]; then
      exec 9>>"$census_log"
      export BASH_XTRACEFD=9
      export PS4='+\${BASH_SOURCE##*/}:\${LINENO}: '
      exec /bin/bash -x "\$@"
    fi
    ;;
esac
exec /bin/bash "\$@"
EOF
  chmod +x "$bin_dir/bash"
}

if [[ "$mode" == bash ]]; then
  write_bash_wrapper
else
  write_wrappers
fi

: > "$census_log"
cd "$repo_root"
setsid env PATH="$bin_dir:$PATH" \
  bash "$suite_path" --filter "$case_filter" > "$suite_log" 2>&1 &
subject_pgid=$!
# Record the owning group in the locked file so a blocked launch can name it.
printf '%s\n' "$subject_pgid" >&8

waited=0
while (( waited < deadline )); do
  kill -0 "$subject_pgid" 2>/dev/null || break
  sleep 1
  waited=$((waited + 1))
done

subject_rc=0
if kill -0 "$subject_pgid" 2>/dev/null; then
  printf 'gate-subprocess-census: subject still running after %ss; results are partial\n' \
    "$deadline" >&2
  subject_rc=124
else
  wait "$subject_pgid" 2>/dev/null || subject_rc=$?
fi

# A subject that failed under instrumentation measured something other than the
# behaviour under test, so say so rather than presenting the numbers as clean.
printf 'subject: %s --filter %s\n' "$suite" "$case_filter"
printf 'subject outcome: '
if [[ "$subject_rc" -eq 0 ]]; then
  printf 'passed (numbers describe a run that behaved normally)\n'
else
  printf 'FAILED rc=%s -- numbers below describe a divergent run, do not publish them as a baseline\n' \
    "$subject_rc"
fi
tail -3 "$suite_log" | sed 's/^/  /'
printf '\n'

case "$mode" in
  time)
    printf '=== child time by binary (counts exact; per-call means include wrapper fork) ===\n'
    awk '
      NF == 3 && $2 ~ /^[0-9.]+$/ && $3 ~ /^[0-9.]+$/ {
        elapsed = $3 - $2
        calls[$1]++
        seconds[$1] += elapsed
        total += elapsed
      }
      END {
        printf "%-12s %8s %11s %11s\n", "binary", "calls", "total_s", "mean_ms"
        for (binary in calls)
          printf "%-12s %8d %11.2f %11.2f\n", \
            binary, calls[binary], seconds[binary], (seconds[binary] / calls[binary]) * 1000
        printf "%-12s %8s %11.2f\n", "ALL", "", total
      }' "$census_log" | { read -r header; printf '%s\n' "$header"; sort -k3 -rn; }
    ;;
  exec)
    printf '=== call count by binary ===\n'
    awk -F '\t' '$1 == "CENSUS" { print $2 }' "$census_log" | sort | uniq -c | sort -rn
    printf '\n=== flag shape, most frequent first (cluster back to call sites) ===\n'
    awk -F '\t' '$1 == "CENSUS" { printf "%s%s\n", $2, $3 }' "$census_log" \
      | sort | uniq -c | sort -rn | head -25
    ;;
  bash)
    printf 'traced simple commands: %s\n\n' "$(wc -l < "$census_log")"
    printf '=== bash work by source file ===\n'
    { grep -oE '^\+[a-zA-Z0-9._-]+\.sh:' "$census_log" || true; } \
      | sort | uniq -c | sort -rn | head -12
    printf '\n=== hottest source:line ===\n'
    { grep -oE '^\+[a-zA-Z0-9._-]+\.sh:[0-9]+' "$census_log" || true; } \
      | sort | uniq -c | sort -rn | head -15
    ;;
esac

if [[ -n "$out_dir" ]]; then
  mkdir -p "$out_dir"
  cp "$census_log" "$out_dir/census-$mode.log"
  cp "$suite_log" "$out_dir/suite-$mode.out"
  printf '\nraw: %s/census-%s.log\n' "$out_dir" "$mode"
fi

# The exit code reports whether the measurement is usable, not whatever the
# last reporting pipeline happened to return.
[[ "$subject_rc" -eq 0 ]] || exit 1
exit 0
