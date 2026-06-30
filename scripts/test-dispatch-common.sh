#!/usr/bin/env bash
# Unit tests for scripts/lib/dispatch-common.sh — shared adapter dispatch helpers.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=scripts/lib/test-harness.sh
. "$SCRIPT_DIR/lib/test-harness.sh"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib/dispatch-common.sh"
th_init "$@"

# ── dc_validate_args ──────────────────────────────────────────────────────────

case_validate_missing_workdir() {
  local name="dc_validate_args/missing --cd"; should_run "$name" || return 0
  if ! dc_validate_args "" "" "0" "60" 2>/dev/null; then
    pass "$name"
  else
    fail "$name" "expected non-zero return for missing work_dir"
  fi
}

case_validate_workdir_not_a_dir() {
  local name="dc_validate_args/work_dir not a directory"; should_run "$name" || return 0
  if ! dc_validate_args "/nonexistent/path/xyz" "" "0" "60" 2>/dev/null; then
    pass "$name"
  else
    fail "$name" "expected non-zero return for non-existent dir"
  fi
}

case_validate_brief_file_missing() {
  local name="dc_validate_args/brief_file not found"; should_run "$name" || return 0
  local work_dir="$tmp_root/wdir_missing_brief"
  mkdir -p "$work_dir"
  if ! dc_validate_args "$work_dir" "/nonexistent/brief.md" "0" "60" 2>/dev/null; then
    pass "$name"
  else
    fail "$name" "expected non-zero return for missing brief_file"
  fi
}

case_validate_brief_file_sets_dc_brief() {
  local name="dc_validate_args/brief_file is read into DC_BRIEF"; should_run "$name" || return 0
  local work_dir="$tmp_root/wdir_brief_set"
  local bf="$tmp_root/brief_ok.md"
  mkdir -p "$work_dir"
  printf 'goal: test\n' > "$bf"
  dc_validate_args "$work_dir" "$bf" "0" "60"
  if [[ "$DC_BRIEF" == "goal: test" ]]; then
    pass "$name"
  else
    fail "$name" "DC_BRIEF='$DC_BRIEF' expected 'goal: test'"
  fi
}

case_validate_empty_brief_print_cmd_ok() {
  local name="dc_validate_args/empty brief with print_cmd=1 is ok"; should_run "$name" || return 0
  local work_dir="$tmp_root/wdir_print_cmd"
  mkdir -p "$work_dir"
  if dc_validate_args "$work_dir" "" "1" "60" 2>/dev/null; then
    pass "$name"
  else
    fail "$name" "expected success when print_cmd=1 and no brief"
  fi
}

case_validate_empty_brief_no_print_cmd_fails() {
  local name="dc_validate_args/empty brief without print_cmd fails"; should_run "$name" || return 0
  local work_dir="$tmp_root/wdir_no_brief"
  mkdir -p "$work_dir"
  if ! dc_validate_args "$work_dir" "" "0" "60" 2>/dev/null; then
    pass "$name"
  else
    fail "$name" "expected non-zero for empty brief and print_cmd=0"
  fi
}

case_validate_invalid_timeout() {
  local name="dc_validate_args/non-integer timeout fails"; should_run "$name" || return 0
  local work_dir="$tmp_root/wdir_timeout"
  local bf="$tmp_root/brief_timeout.md"
  mkdir -p "$work_dir"
  printf 'goal: x\n' > "$bf"
  if ! dc_validate_args "$work_dir" "$bf" "0" "abc" 2>/dev/null; then
    pass "$name"
  else
    fail "$name" "expected non-zero for non-integer timeout"
  fi
}

case_validate_zero_timeout_ok() {
  local name="dc_validate_args/timeout=0 is valid"; should_run "$name" || return 0
  local work_dir="$tmp_root/wdir_zero_to"
  local bf="$tmp_root/brief_zero_to.md"
  mkdir -p "$work_dir"
  printf 'goal: x\n' > "$bf"
  if dc_validate_args "$work_dir" "$bf" "0" "0" 2>/dev/null; then
    pass "$name"
  else
    fail "$name" "expected success for timeout=0"
  fi
}

# ── dc_setup_trace_dir ────────────────────────────────────────────────────────

# Stub sw_resolve_trace_dir for isolation — real function lives in state-paths.sh
# which is sourced via state-writer.sh in adapters. Tests here don't need state-paths.sh.
_stub_sw_resolve() {
  sw_resolve_trace_dir() { printf '%s\n' "${2:-/tmp/fallback-trace}"; }
}
_unstub_sw_resolve() {
  unset -f sw_resolve_trace_dir 2>/dev/null || true
}

case_setup_trace_dir_missing_helper() {
  local name="dc_setup_trace_dir/fails when sw_resolve_trace_dir absent"; should_run "$name" || return 0
  _unstub_sw_resolve
  unset -f sw_resolve_trace_dir 2>/dev/null || true
  local work_dir="$tmp_root/wdir_no_helper"
  mkdir -p "$work_dir"
  if ! dc_setup_trace_dir "" "$work_dir" "test" "20260630" 2>/dev/null; then
    pass "$name"
  else
    fail "$name" "expected non-zero when sw_resolve_trace_dir missing"
  fi
}

case_setup_trace_dir_sets_vars() {
  local name="dc_setup_trace_dir/sets DC_TRACE_DIR DC_TRACE DC_LAST DC_STDERR_LOG"; should_run "$name" || return 0
  _stub_sw_resolve
  local work_dir="$tmp_root/wdir_trace_vars"
  mkdir -p "$work_dir"
  local ts="20260630-120000-99999"
  local expected_tdir="$work_dir/.agent-trace"
  dc_setup_trace_dir "" "$work_dir" "myprefix" "$ts"
  local ok=1
  [[ "$DC_TRACE_DIR" == "$expected_tdir" ]]                             || ok=0
  [[ "$DC_TRACE"     == "$expected_tdir/myprefix-$ts.jsonl" ]]          || ok=0
  [[ "$DC_LAST"      == "$expected_tdir/myprefix-$ts.last" ]]           || ok=0
  [[ "$DC_STDERR_LOG" == "$expected_tdir/myprefix-$ts.stderr" ]]        || ok=0
  _unstub_sw_resolve
  if [[ "$ok" -eq 1 ]]; then
    pass "$name"
  else
    fail "$name" "TRACE_DIR=$DC_TRACE_DIR TRACE=$DC_TRACE LAST=$DC_LAST STDERR=$DC_STDERR_LOG"
  fi
}

case_setup_trace_dir_creates_dir() {
  local name="dc_setup_trace_dir/creates trace dir on disk"; should_run "$name" || return 0
  local trace_dir="$tmp_root/trace_dir_create"
  sw_resolve_trace_dir() { printf '%s\n' "$trace_dir"; }
  local work_dir="$tmp_root/wdir_create"
  mkdir -p "$work_dir"
  rm -rf "$trace_dir"
  dc_setup_trace_dir "" "$work_dir" "pfx" "ts123"
  unset -f sw_resolve_trace_dir
  if [[ -d "$trace_dir" ]]; then
    pass "$name"
  else
    fail "$name" "trace dir not created at $trace_dir"
  fi
}

# ── dc_refresh_latest_pointers ────────────────────────────────────────────────

case_refresh_pointers_creates_symlinks() {
  local name="dc_refresh_latest_pointers/creates latest.* symlinks"; should_run "$name" || return 0
  local tdir="$tmp_root/refresh_syms"
  mkdir -p "$tdir"
  local ts="20260630-010101-1"
  local prefix="testadapter"
  # Create dummy targets so symlinks are valid
  touch "$tdir/$prefix-$ts.jsonl" "$tdir/$prefix-$ts.last" "$tdir/$prefix-$ts.stderr"
  dc_refresh_latest_pointers "$prefix" "$tdir" "$ts"
  local ok=1
  [[ -L "$tdir/latest.jsonl"  ]] || ok=0
  [[ -L "$tdir/latest.last"   ]] || ok=0
  [[ -L "$tdir/latest.stderr" ]] || ok=0
  [[ "$(readlink "$tdir/latest.jsonl")"  == "$prefix-$ts.jsonl"  ]] || ok=0
  [[ "$(readlink "$tdir/latest.last")"   == "$prefix-$ts.last"   ]] || ok=0
  [[ "$(readlink "$tdir/latest.stderr")" == "$prefix-$ts.stderr" ]] || ok=0
  if [[ "$ok" -eq 1 ]]; then
    pass "$name"
  else
    fail "$name" "symlink targets wrong or missing"
  fi
}

case_refresh_pointers_best_effort() {
  local name="dc_refresh_latest_pointers/no error when dir absent"; should_run "$name" || return 0
  if dc_refresh_latest_pointers "pfx" "/nonexistent/dir/xyz" "ts" 2>/dev/null; then
    pass "$name"
  else
    fail "$name" "should not fail on missing dir (best-effort)"
  fi
}

# ── dc_print_footer ───────────────────────────────────────────────────────────

case_print_footer_structure() {
  local name="dc_print_footer/prints standard footer fields"; should_run "$name" || return 0
  local last="$tmp_root/empty.last"
  printf '' > "$last"   # empty file
  local out
  out="$(dc_print_footer "/t/trace.jsonl" "$last" "/t/trace.stderr" "0" "test-model")"
  local ok=1
  grep -q '^trace:.*trace\.jsonl'  <<<"$out" || ok=0
  grep -q '^last:.*empty\.last'    <<<"$out" || ok=0
  grep -q '^stderr:.*trace\.stderr' <<<"$out" || ok=0
  grep -q '^exit:.*0'              <<<"$out" || ok=0
  grep -q '^model:.*test-model'    <<<"$out" || ok=0
  if [[ "$ok" -eq 1 ]]; then
    pass "$name"
  else
    fail "$name" "missing fields in footer: $out"
  fi
}

case_print_footer_cats_last() {
  local name="dc_print_footer/cats last file when non-empty"; should_run "$name" || return 0
  local last="$tmp_root/nonempty.last"
  printf 'work done\n' > "$last"
  local out
  out="$(dc_print_footer "/t/trace.jsonl" "$last" "/t/stderr" "0" "m")"
  if grep -q 'work done' <<<"$out"; then
    pass "$name"
  else
    fail "$name" "expected 'work done' in footer output"
  fi
}

case_print_footer_skips_empty_last() {
  local name="dc_print_footer/does not cat empty last file"; should_run "$name" || return 0
  local last="$tmp_root/empty2.last"
  printf '' > "$last"
  local out
  out="$(dc_print_footer "/t/trace.jsonl" "$last" "/t/stderr" "1" "m")"
  if ! grep -q 'final message' <<<"$out"; then
    pass "$name"
  else
    fail "$name" "should not print '=== final message ===' for empty last"
  fi
}

# ── dc_snapshot_copy_libs ─────────────────────────────────────────────────────

case_snapshot_copy_libs_copies_dispatch_common() {
  local name="dc_snapshot_copy_libs/copies dispatch-common.sh"; should_run "$name" || return 0
  local snap="$tmp_root/snap_copy"
  mkdir -p "$snap"
  dc_snapshot_copy_libs "$snap" "$REPO_ROOT"
  if [[ -f "$snap/lib/dispatch-common.sh" ]]; then
    pass "$name"
  else
    fail "$name" "dispatch-common.sh not found in snapshot lib dir"
  fi
}

case_snapshot_copy_libs_copies_all_core_libs() {
  local name="dc_snapshot_copy_libs/copies all core shared libs"; should_run "$name" || return 0
  local snap="$tmp_root/snap_all_libs"
  mkdir -p "$snap"
  dc_snapshot_copy_libs "$snap" "$REPO_ROOT"
  local missing=()
  for lib in state-writer.sh state-paths.sh portable.sh model-aliases.sh \
             timeout-resolve.sh dispatch-common.sh; do
    [[ -f "$snap/lib/$lib" ]] || missing+=("$lib")
  done
  if [[ "${#missing[@]}" -eq 0 ]]; then
    pass "$name"
  else
    fail "$name" "missing: ${missing[*]}"
  fi
}

case_snapshot_copy_libs_creates_lib_dir() {
  local name="dc_snapshot_copy_libs/creates lib/ subdir"; should_run "$name" || return 0
  local snap="$tmp_root/snap_mkdir"
  mkdir -p "$snap"
  rm -rf "$snap/lib"
  dc_snapshot_copy_libs "$snap" "$REPO_ROOT"
  if [[ -d "$snap/lib" ]]; then
    pass "$name"
  else
    fail "$name" "lib/ not created"
  fi
}

# ── Run ───────────────────────────────────────────────────────────────────────

case_validate_missing_workdir
case_validate_workdir_not_a_dir
case_validate_brief_file_missing
case_validate_brief_file_sets_dc_brief
case_validate_empty_brief_print_cmd_ok
case_validate_empty_brief_no_print_cmd_fails
case_validate_invalid_timeout
case_validate_zero_timeout_ok

case_setup_trace_dir_missing_helper
case_setup_trace_dir_sets_vars
case_setup_trace_dir_creates_dir

case_refresh_pointers_creates_symlinks
case_refresh_pointers_best_effort

case_print_footer_structure
case_print_footer_cats_last
case_print_footer_skips_empty_last

case_snapshot_copy_libs_copies_dispatch_common
case_snapshot_copy_libs_copies_all_core_libs
case_snapshot_copy_libs_creates_lib_dir

th_summary
