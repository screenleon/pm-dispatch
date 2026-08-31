#!/usr/bin/env bash
# Regression tests for ops/diagnostics/gate-subprocess-census.sh.
#
# The census exists to decide where an optimisation slice should spend effort,
# so a silent regression in it would misdirect that work with false evidence.
# Every case therefore points the census at a synthetic subject whose subprocess
# behaviour is known exactly, and asserts the reported numbers against it --
# rather than at the real gate suite, which takes minutes and whose call counts
# are what the tool is supposed to discover.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CENSUS="$REPO_ROOT/ops/diagnostics/gate-subprocess-census.sh"

# shellcheck source=tests/lib/test-harness.sh
# shellcheck disable=SC1091
. "$SCRIPT_DIR/../lib/test-harness.sh"
th_init "$@"

# fake_suite <slug> <body> -- a stand-in for the gate suite. The census invokes
# it as `bash <path> --filter <case>`; the body decides what subprocesses run
# and what exit code the subject reports.
fake_suite() {
  # shellcheck disable=SC2154  # tmp_root from th_init
  local path="$tmp_root/$1.sh"
  mkdir -p "$tmp_root"
  {
    printf '#!/usr/bin/env bash\n'
    printf '%s\n' "$2"
  } > "$path"
  chmod +x "$path"
  printf '%s\n' "$path"
}

# run_census <suite-path> [extra args...] -- leaves the combined output in
# CENSUS_OUT and the exit code in CENSUS_RC, so a case can assert on both
# without a command substitution swallowing the status.
CENSUS_RC=0
CENSUS_OUT=""
run_census() {
  local suite="$1"; shift
  CENSUS_RC=0
  CENSUS_OUT="$(bash "$CENSUS" --suite "$suite" --case any --timeout 30 "$@" 2>&1)" \
    || CENSUS_RC=$?
}

# ---------------------------------------------------------------- option parsing

test_unknown_flag_is_usage_error() {
  local name="an unknown flag exits 2 without running a subject"
  should_run "$name" || return 0
  local out rc=0
  out="$(bash "$CENSUS" --nope 2>&1)" || rc=$?
  if [[ "$rc" -eq 2 && "$out" == *usage* ]]; then pass "$name"
  else fail "$name" "expected exit 2 + usage, got rc=$rc :: $out"; fi
}

test_invalid_mode_is_usage_error() {
  local name="an unsupported --mode exits 2"
  should_run "$name" || return 0
  local out rc=0
  out="$(bash "$CENSUS" --mode sideways 2>&1)" || rc=$?
  if [[ "$rc" -eq 2 ]]; then pass "$name"
  else fail "$name" "expected exit 2, got rc=$rc :: $out"; fi
}

test_non_numeric_timeout_is_usage_error() {
  local name="a non-numeric --timeout exits 2"
  should_run "$name" || return 0
  local out rc=0
  out="$(bash "$CENSUS" --timeout soon 2>&1)" || rc=$?
  if [[ "$rc" -eq 2 ]]; then pass "$name"
  else fail "$name" "expected exit 2, got rc=$rc :: $out"; fi
}

test_unreadable_suite_is_rejected_before_setup() {
  local name="an unreadable --suite exits 2 and names the path"
  should_run "$name" || return 0
  local out rc=0
  out="$(bash "$CENSUS" --suite "$tmp_root/definitely-absent.sh" 2>&1)" || rc=$?
  if [[ "$rc" -eq 2 && "$out" == *"not readable"* ]]; then pass "$name"
  else fail "$name" "expected exit 2 + 'not readable', got rc=$rc :: $out"; fi
}

# ------------------------------------------------------------- wrapper accounting

test_time_mode_counts_every_call_of_a_known_subject() {
  local name="time mode counts exactly the calls a known subject makes"
  should_run "$name" || return 0
  local suite
  suite="$(fake_suite time-known '
for i in 1 2 3 4 5; do jq -n 1 >/dev/null; done
for i in 1 2 3; do awk "BEGIN{}" </dev/null; done
exit 0')"
  run_census "$suite" --mode time
  if [[ "$CENSUS_RC" -ne 0 ]]; then
    fail "$name" "expected exit 0, got $CENSUS_RC :: $CENSUS_OUT"; return
  fi
  local jq_calls awk_calls
  jq_calls="$(awk '$1 == "jq" { print $2 }' <<< "$CENSUS_OUT")"
  awk_calls="$(awk '$1 == "awk" { print $2 }' <<< "$CENSUS_OUT")"
  if [[ "$jq_calls" == "5" && "$awk_calls" == "3" ]]; then pass "$name"
  else fail "$name" "expected jq=5 awk=3, got jq=$jq_calls awk=$awk_calls :: $CENSUS_OUT"; fi
}

test_time_mode_reports_a_passing_subject_as_usable() {
  local name="time mode labels a passing subject's numbers usable"
  should_run "$name" || return 0
  local suite
  suite="$(fake_suite time-pass 'jq -n 1 >/dev/null; exit 0')"
  run_census "$suite" --mode time
  if [[ "$CENSUS_RC" -eq 0 && "$CENSUS_OUT" == *"subject outcome: passed"* ]]; then pass "$name"
  else fail "$name" "expected exit 0 + 'subject outcome: passed', got rc=$CENSUS_RC :: $CENSUS_OUT"; fi
}

test_exec_mode_clusters_flags_without_program_spill() {
  local name="exec mode counts binaries and never counts a jq program's keywords"
  should_run "$name" || return 0
  local suite out
  # The program spans lines and contains bare words, and sits in the leading
  # argv where a naive log format would capture it -- which is how 'if' and
  # 'then' end up tallied as if they were invoked binaries.
  suite="$(fake_suite exec-spill '
jq -n "
if 1 == 1
then 1
else 2
end" >/dev/null
jq -r -n 2 >/dev/null
exit 0')"
  out="$(bash "$CENSUS" --suite "$suite" --case any --timeout 30 --mode exec 2>&1)"
  local jq_count spill
  jq_count="$(awk '$2 == "jq" { print $1 }' <<< "$(sed -n '/call count by binary/,/flag shape/p' <<< "$out")")"
  spill="$(grep -cE '^[[:space:]]+[0-9]+[[:space:]]+(if|then|else|end)$' <<< "$out")"
  if [[ "$jq_count" == "2" && "$spill" == "0" ]]; then pass "$name"
  else fail "$name" "expected jq=2 and no keyword rows, got jq=$jq_count spill=$spill :: $out"; fi
}

test_bash_mode_traces_the_gate_not_the_suite_driver() {
  local name="bash mode traces pr-gate.sh and not the suite that invokes it"
  should_run "$name" || return 0
  local gate suite out
  gate="$tmp_root/fake-runner/pr-gate.sh"
  mkdir -p "$tmp_root/fake-runner"
  # shellcheck disable=SC2016  # the arithmetic is the fake gate's own source, not this shell's.
  printf '#!/usr/bin/env bash\nx=1\ny=2\nprintf "%%s\\n" "$((x+y))" >/dev/null\n' > "$gate"
  chmod +x "$gate"
  # The driver is deliberately named test-pr-gate.sh, exactly like the real
  # suite: its basename *ends* in pr-gate.sh, so a suffix match would trace the
  # whole harness and swamp the gate's own counts. Only an exact-basename match
  # separates them.
  suite="$(fake_suite test-pr-gate "bash '$gate'; exit 0")"
  out="$(bash "$CENSUS" --suite "$suite" --case any --timeout 30 --mode bash 2>&1)"
  local traced driver_lines
  traced="$(awk '/traced simple commands:/ { print $4 }' <<< "$out")"
  driver_lines="$(grep -c 'test-pr-gate\.sh:' <<< "$out")"
  if [[ "${traced:-0}" -gt 0 && "$driver_lines" == "0" ]]; then pass "$name"
  else fail "$name" "expected gate traced and driver untraced, got traced=$traced driver=$driver_lines :: $out"; fi
}

test_bash_mode_counts_invocations_not_mentions() {
  local name="bash mode counts jq invocations, not variables that merely contain 'jq'"
  should_run "$name" || return 0
  local gate suite out
  gate="$tmp_root/mentions-runner/pr-gate.sh"
  mkdir -p "$tmp_root/mentions-runner"
  # Exactly two real invocations, surrounded by the shapes the real gate is
  # full of: a `jq_rc` status variable, a `jq_display_def` program held in a
  # variable, and an availability probe. A matcher that looks for the word
  # anywhere would report five and send an optimisation slice at call sites
  # that do not exist.
  {
    printf '#!/usr/bin/env bash\n'
    printf 'jq_rc=0\n'
    printf 'jq_display_def="def display: .;"\n'
    printf 'command -v jq >/dev/null\n'
    printf 'jq -n 1 >/dev/null\n'
    printf 'jq_rc=$?\n'
    printf 'jq -n "\n'
    printf 'if 1 == 1 then 1 else 2 end" >/dev/null\n'
  } > "$gate"
  chmod +x "$gate"
  suite="$(fake_suite mentions-driver "bash '$gate'; exit 0")"
  out="$(bash "$CENSUS" --suite "$suite" --case any --timeout 30 --mode bash 2>&1)"
  local attributed
  attributed="$(awk '/TOTAL attributed/ { print $1 }' <<< "$out")"
  if [[ "${attributed:-0}" -eq 2 ]]; then pass "$name"
  else fail "$name" "expected exactly 2 invocations attributed, got ${attributed:-0} :: $out"; fi
}

test_attribute_selects_the_binary() {
  local name="--attribute counts the named binary instead of jq"
  should_run "$name" || return 0
  local gate suite out attributed
  gate="$tmp_root/attr-runner/pr-gate.sh"
  mkdir -p "$tmp_root/attr-runner"
  printf '#!/usr/bin/env bash\njq -n 1 >/dev/null\nawk "BEGIN{}" </dev/null\nawk "BEGIN{}" </dev/null\n' > "$gate"
  chmod +x "$gate"
  suite="$(fake_suite attr-driver "bash '$gate'; exit 0")"
  out="$(bash "$CENSUS" --suite "$suite" --case any --timeout 30 --mode bash --attribute awk 2>&1)"
  attributed="$(awk '/TOTAL attributed/ { print $1 }' <<< "$out")"
  if [[ "$out" == *"awk invocations per source:line"* && "${attributed:-0}" -eq 2 ]]; then
    pass "$name"
  else fail "$name" "expected 2 awk attributed, got ${attributed:-0} :: $out"; fi
}

test_bad_attribute_value_is_usage_error() {
  local name="a malformed --attribute value exits 2"
  should_run "$name" || return 0
  local out rc=0
  out="$(bash "$CENSUS" --attribute 'jq; rm -rf /' 2>&1)" || rc=$?
  if [[ "$rc" -eq 2 ]]; then pass "$name"
  else fail "$name" "expected exit 2, got $rc :: $out"; fi
}

# ------------------------------------------------------------- subject outcomes

test_failed_subject_is_labelled_unusable_and_exits_nonzero() {
  local name="a failing subject is labelled unusable and the census exits non-zero"
  should_run "$name" || return 0
  local suite out rc=0
  suite="$(fake_suite subject-fails 'jq -n 1 >/dev/null; exit 3')"
  out="$(bash "$CENSUS" --suite "$suite" --case any --timeout 30 --mode time 2>&1)" || rc=$?
  if [[ "$rc" -ne 0 && "$out" == *"FAILED rc=3"* && "$out" == *"do not publish"* ]]; then pass "$name"
  else fail "$name" "expected non-zero + unusable label, got rc=$rc :: $out"; fi
}

test_timed_out_subject_is_labelled_unusable() {
  local name="a subject that outlives --timeout is reported partial, not clean"
  should_run "$name" || return 0
  local suite out rc=0
  suite="$(fake_suite subject-hangs 'sleep 30')"
  out="$(bash "$CENSUS" --suite "$suite" --case any --timeout 1 --mode time 2>&1)" || rc=$?
  if [[ "$rc" -ne 0 && "$out" == *"still running after 1s"* && "$out" == *"FAILED rc=124"* ]]; then
    pass "$name"
  else fail "$name" "expected non-zero + partial label, got rc=$rc :: $out"; fi
}

test_timed_out_subject_process_group_is_torn_down() {
  local name="a timed-out subject leaves no surviving child"
  should_run "$name" || return 0
  local suite marker
  marker="$tmp_root/still-alive.marker"
  # The child outlives the parent unless the whole group is killed; it writes
  # the marker only if it is still running well after the census returned.
  suite="$(fake_suite subject-spawns "( sleep 4; : > '$marker' ) & sleep 30")"
  local rc=0
  bash "$CENSUS" --suite "$suite" --case any --timeout 1 --mode time >/dev/null 2>&1 || rc=$?
  # A timed-out subject must report unusable; anything else means this case
  # exercised a different path than the teardown it claims to cover.
  if [[ "$rc" -eq 0 ]]; then
    fail "$name" "expected the timed-out census to exit non-zero, got 0"; return
  fi
  sleep 6
  if [[ ! -e "$marker" ]]; then pass "$name"
  else fail "$name" "orphan survived the census teardown ($marker exists)"; fi
}

# ------------------------------------------------------------------- exclusion

test_second_census_is_refused_while_the_lock_is_held() {
  local name="a census is refused while another holds the lock"
  should_run "$name" || return 0
  local suite out rc=0
  suite="$(fake_suite lock-probe 'exit 0')"
  # Hold the same lock the census uses, from an independent descriptor.
  exec 7>>"${TMPDIR:-/tmp}/gate-subprocess-census.lock"
  if ! flock -n 7; then
    exec 7>&-
    skip "$name" "another census already holds the lock on this machine"
    return 0
  fi
  out="$(bash "$CENSUS" --suite "$suite" --case any --timeout 10 2>&1)" || rc=$?
  exec 7>&-
  if [[ "$rc" -ne 0 && "$out" == *"another census holds"* ]]; then pass "$name"
  else fail "$name" "expected refusal, got rc=$rc :: $out"; fi
}

test_lock_is_released_after_a_run() {
  local name="the lock is free again once a census completes successfully"
  should_run "$name" || return 0
  local suite
  suite="$(fake_suite lock-release 'jq -n 1 >/dev/null; exit 0')"
  # Suppressing the census's status here would let this case pass on a census
  # that crashed before it ever took the lock -- which proves nothing about
  # release. Require the run to have succeeded first.
  run_census "$suite" --mode time
  if [[ "$CENSUS_RC" -ne 0 ]]; then
    fail "$name" "census did not complete, so release proves nothing: rc=$CENSUS_RC :: $CENSUS_OUT"
    return
  fi
  exec 7>>"${TMPDIR:-/tmp}/gate-subprocess-census.lock"
  if flock -n 7; then
    exec 7>&-
    pass "$name"
  else
    exec 7>&-
    fail "$name" "lock still held after a completed census exited"
  fi
}

# ----------------------------------------------------------------------- output

test_out_dir_receives_the_raw_log() {
  local name="--out preserves the raw census log for later inspection"
  should_run "$name" || return 0
  local suite dest out
  suite="$(fake_suite out-dir 'jq -n 1 >/dev/null; exit 0')"
  dest="$tmp_root/out-dir-dest"
  out="$(bash "$CENSUS" --suite "$suite" --case any --timeout 30 --mode time --out "$dest" 2>&1)"
  if [[ -s "$dest/census-time.log" && -f "$dest/suite-time.out" && "$out" == *"raw: $dest/census-time.log"* ]]; then
    pass "$name"
  else fail "$name" "expected raw logs under $dest, got :: $out"; fi
}

test_unreadable_flags_reported_subject_command() {
  local name="the report names the subject it actually measured"
  should_run "$name" || return 0
  local suite out
  suite="$(fake_suite subject-echo 'exit 0')"
  out="$(bash "$CENSUS" --suite "$suite" --case tier-detection --timeout 10 2>&1)"
  if [[ "$out" == *"subject: $suite --filter tier-detection"* ]]; then pass "$name"
  else fail "$name" "expected the subject line to name $suite, got :: $out"; fi
}

test_unknown_flag_is_usage_error
test_invalid_mode_is_usage_error
test_non_numeric_timeout_is_usage_error
test_unreadable_suite_is_rejected_before_setup
test_time_mode_counts_every_call_of_a_known_subject
test_time_mode_reports_a_passing_subject_as_usable
test_exec_mode_clusters_flags_without_program_spill
test_bash_mode_traces_the_gate_not_the_suite_driver
test_bash_mode_counts_invocations_not_mentions
test_attribute_selects_the_binary
test_bad_attribute_value_is_usage_error
test_failed_subject_is_labelled_unusable_and_exits_nonzero
test_timed_out_subject_is_labelled_unusable
test_timed_out_subject_process_group_is_torn_down
test_second_census_is_refused_while_the_lock_is_held
test_lock_is_released_after_a_run
test_out_dir_receives_the_raw_log
test_unreadable_flags_reported_subject_command

th_summary
