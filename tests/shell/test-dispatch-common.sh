#!/usr/bin/env bash
# Unit tests for runtime/lib/dispatch-common.sh — shared adapter dispatch helpers.
# Covers: dc_validate_args, dc_setup_trace_dir, dc_refresh_latest_pointers,
#         dc_print_footer, dc_snapshot_copy_libs, dc_snapshot_copy_extras,
#         dc_run_timestamp, dc_resolve_sibling_file, dc_parse_common_flags.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=tests/lib/test-harness.sh
. "$SCRIPT_DIR/../lib/test-harness.sh"
# shellcheck disable=SC1091
. "$REPO_ROOT/runtime/lib/dispatch-common.sh"
th_init "$@"

# ── dc_validate_args ──────────────────────────────────────────────────────────

case_validate_missing_workdir() {
  local name="dc_validate_args/missing --cd"; should_run "$name" || return 0
  # Arrange: empty work_dir, no brief, print_cmd=0, valid timeout
  # Act: call dc_validate_args
  # Assert: returns non-zero (error message emitted to stderr)
  if ! dc_validate_args "" "" "0" "60" 2>/dev/null; then
    pass "$name"
  else
    fail "$name" "expected non-zero return for missing work_dir"
  fi
}

case_validate_workdir_not_a_dir() {
  local name="dc_validate_args/work_dir not a directory"; should_run "$name" || return 0
  # Arrange: work_dir path that does not exist on disk
  # Act: call dc_validate_args
  # Assert: returns non-zero
  if ! dc_validate_args "/nonexistent/path/xyz" "" "0" "60" 2>/dev/null; then
    pass "$name"
  else
    fail "$name" "expected non-zero return for non-existent dir"
  fi
}

case_validate_brief_file_missing() {
  local name="dc_validate_args/brief_file not found"; should_run "$name" || return 0
  # Arrange: valid work_dir, brief_file path that does not exist
  local work_dir="$tmp_root/wdir_missing_brief"
  mkdir -p "$work_dir"
  # Act: call dc_validate_args with non-existent brief_file
  # Assert: returns non-zero
  if ! dc_validate_args "$work_dir" "/nonexistent/brief.md" "0" "60" 2>/dev/null; then
    pass "$name"
  else
    fail "$name" "expected non-zero return for missing brief_file"
  fi
}

case_validate_brief_file_sets_dc_brief() {
  local name="dc_validate_args/brief_file is read into DC_BRIEF"; should_run "$name" || return 0
  # Arrange: valid work_dir and a readable brief file containing known content
  local work_dir="$tmp_root/wdir_brief_set"
  local bf="$tmp_root/brief_ok.md"
  mkdir -p "$work_dir"
  printf 'goal: test\n' > "$bf"
  # Act: call dc_validate_args with a real brief_file
  dc_validate_args "$work_dir" "$bf" "0" "60"
  # Assert: DC_BRIEF matches the file contents
  if [[ "$DC_BRIEF" == "goal: test" ]]; then
    pass "$name"
  else
    fail "$name" "DC_BRIEF='$DC_BRIEF' expected 'goal: test'"
  fi
}

case_validate_empty_brief_print_cmd_ok() {
  local name="dc_validate_args/empty brief with print_cmd=1 is ok"; should_run "$name" || return 0
  # Arrange: valid work_dir, no brief_file, print_cmd=1 (brief not required)
  local work_dir="$tmp_root/wdir_print_cmd"
  mkdir -p "$work_dir"
  # Act: call dc_validate_args with print_cmd=1 and no brief
  # Assert: returns 0 (print-cmd mode does not require a brief)
  if dc_validate_args "$work_dir" "" "1" "60" 2>/dev/null; then
    pass "$name"
  else
    fail "$name" "expected success when print_cmd=1 and no brief"
  fi
}

case_validate_empty_brief_no_print_cmd_fails() {
  local name="dc_validate_args/empty brief without print_cmd fails"; should_run "$name" || return 0
  # Arrange: valid work_dir, no brief_file, print_cmd=0
  local work_dir="$tmp_root/wdir_no_brief"
  mkdir -p "$work_dir"
  # Act: call dc_validate_args with no brief and no print_cmd bypass
  # Assert: returns non-zero
  if ! dc_validate_args "$work_dir" "" "0" "60" 2>/dev/null; then
    pass "$name"
  else
    fail "$name" "expected non-zero for empty brief and print_cmd=0"
  fi
}

case_validate_invalid_timeout() {
  local name="dc_validate_args/non-integer timeout fails"; should_run "$name" || return 0
  # Arrange: valid work_dir and brief_file, timeout is a non-integer string
  local work_dir="$tmp_root/wdir_timeout"
  local bf="$tmp_root/brief_timeout.md"
  mkdir -p "$work_dir"
  printf 'goal: x\n' > "$bf"
  # Act: call dc_validate_args with timeout="abc"
  # Assert: returns non-zero
  if ! dc_validate_args "$work_dir" "$bf" "0" "abc" 2>/dev/null; then
    pass "$name"
  else
    fail "$name" "expected non-zero for non-integer timeout"
  fi
}

case_validate_zero_timeout_ok() {
  local name="dc_validate_args/timeout=0 is valid"; should_run "$name" || return 0
  # Arrange: valid work_dir and brief_file, timeout=0 (no-limit sentinel)
  local work_dir="$tmp_root/wdir_zero_to"
  local bf="$tmp_root/brief_zero_to.md"
  mkdir -p "$work_dir"
  printf 'goal: x\n' > "$bf"
  # Act: call dc_validate_args with timeout=0
  # Assert: returns 0 (zero is a valid non-negative integer meaning no limit)
  if dc_validate_args "$work_dir" "$bf" "0" "0" 2>/dev/null; then
    pass "$name"
  else
    fail "$name" "expected success for timeout=0"
  fi
}

# ── dc_setup_trace_dir ────────────────────────────────────────────────────────

# Stub sw_resolve_trace_dir for isolation — the real function lives in state-paths.sh
# sourced via state-writer.sh in adapters. Tests here do not load state-paths.sh.
_stub_sw_resolve() {
  # shellcheck disable=SC2329
  sw_resolve_trace_dir() { printf '%s\n' "${2:-/tmp/fallback-trace}"; }
}
_unstub_sw_resolve() {
  unset -f sw_resolve_trace_dir 2>/dev/null || true
}

case_setup_trace_dir_missing_helper() {
  local name="dc_setup_trace_dir/fails when sw_resolve_trace_dir absent"; should_run "$name" || return 0
  # Arrange: sw_resolve_trace_dir is not defined
  _unstub_sw_resolve
  unset -f sw_resolve_trace_dir 2>/dev/null || true
  local work_dir="$tmp_root/wdir_no_helper"
  mkdir -p "$work_dir"
  # Act: call dc_setup_trace_dir without the helper present
  # Assert: returns non-zero (helper unavailable guard triggers)
  if ! dc_setup_trace_dir "" "$work_dir" "test" "20260630" 2>/dev/null; then
    pass "$name"
  else
    fail "$name" "expected non-zero when sw_resolve_trace_dir missing"
  fi
}

case_setup_trace_dir_sets_vars() {
  local name="dc_setup_trace_dir/sets DC_TRACE_DIR DC_TRACE DC_LAST DC_STDERR_LOG"; should_run "$name" || return 0
  # Arrange: stub sw_resolve_trace_dir to return work_dir/.agent-trace
  _stub_sw_resolve
  local work_dir="$tmp_root/wdir_trace_vars"
  mkdir -p "$work_dir"
  local ts="20260630-120000-99999"
  local expected_tdir="$work_dir/.agent-trace"
  # Act: call dc_setup_trace_dir with prefix "myprefix"
  dc_setup_trace_dir "" "$work_dir" "myprefix" "$ts"
  # Assert: all four DC_* variables carry the expected paths
  local ok=1
  [[ "$DC_TRACE_DIR"  == "$expected_tdir" ]]                            || ok=0
  [[ "$DC_TRACE"      == "$expected_tdir/myprefix-$ts.jsonl" ]]         || ok=0
  [[ "$DC_LAST"       == "$expected_tdir/myprefix-$ts.last" ]]          || ok=0
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
  # Arrange: stub returns a non-existent directory path; work_dir exists
  local trace_dir="$tmp_root/trace_dir_create"
  # shellcheck disable=SC2329
  sw_resolve_trace_dir() { printf '%s\n' "$trace_dir"; }
  local work_dir="$tmp_root/wdir_create"
  mkdir -p "$work_dir"
  rm -rf "$trace_dir"
  # Act: call dc_setup_trace_dir
  dc_setup_trace_dir "" "$work_dir" "pfx" "ts123"
  unset -f sw_resolve_trace_dir
  # Assert: the trace directory now exists on disk
  if [[ -d "$trace_dir" ]]; then
    pass "$name"
  else
    fail "$name" "trace dir not created at $trace_dir"
  fi
}

# ── dc_refresh_latest_pointers ────────────────────────────────────────────────

case_refresh_pointers_creates_symlinks() {
  local name="dc_refresh_latest_pointers/creates latest.* symlinks"; should_run "$name" || return 0
  # Arrange: trace dir with dummy per-run target files
  local tdir="$tmp_root/refresh_syms"
  mkdir -p "$tdir"
  local ts="20260630-010101-1" prefix="testadapter"
  touch "$tdir/$prefix-$ts.jsonl" "$tdir/$prefix-$ts.last" "$tdir/$prefix-$ts.stderr"
  # Act: call dc_refresh_latest_pointers
  dc_refresh_latest_pointers "$prefix" "$tdir" "$ts"
  # Assert: latest.{jsonl,last,stderr} symlinks exist and point to the correct targets
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
  # Arrange: trace dir does not exist
  # Act: call dc_refresh_latest_pointers with a nonexistent dir
  # Assert: returns 0 (best-effort, ln failure is suppressed)
  if dc_refresh_latest_pointers "pfx" "/nonexistent/dir/xyz" "ts" 2>/dev/null; then
    pass "$name"
  else
    fail "$name" "should not fail on missing dir (best-effort)"
  fi
}

# ── dc_print_footer ───────────────────────────────────────────────────────────

case_print_footer_structure() {
  local name="dc_print_footer/prints standard footer fields"; should_run "$name" || return 0
  # Arrange: an empty .last file so the final-message block is not triggered
  local last="$tmp_root/empty.last"
  printf '' > "$last"
  # Act: call dc_print_footer with known argument values
  local out
  out="$(dc_print_footer "/t/trace.jsonl" "$last" "/t/trace.stderr" "0" "test-model")"
  # Assert: output contains all five expected footer lines
  local ok=1
  grep -q '^trace:.*trace\.jsonl'   <<<"$out" || ok=0
  grep -q '^last:.*empty\.last'     <<<"$out" || ok=0
  grep -q '^stderr:.*trace\.stderr' <<<"$out" || ok=0
  grep -q '^exit:.*0'               <<<"$out" || ok=0
  grep -q '^model:.*test-model'     <<<"$out" || ok=0
  if [[ "$ok" -eq 1 ]]; then
    pass "$name"
  else
    fail "$name" "missing fields in footer: $out"
  fi
}

case_print_footer_cats_last() {
  local name="dc_print_footer/cats last file when non-empty"; should_run "$name" || return 0
  # Arrange: a .last file containing known content
  local last="$tmp_root/nonempty.last"
  printf 'work done\n' > "$last"
  # Act: call dc_print_footer
  local out
  out="$(dc_print_footer "/t/trace.jsonl" "$last" "/t/stderr" "0" "m")"
  # Assert: footer output includes the file content under the final-message header
  if grep -q 'work done' <<<"$out"; then
    pass "$name"
  else
    fail "$name" "expected 'work done' in footer output"
  fi
}

case_print_footer_skips_empty_last() {
  local name="dc_print_footer/does not cat empty last file"; should_run "$name" || return 0
  # Arrange: an empty .last file (zero bytes)
  local last="$tmp_root/empty2.last"
  printf '' > "$last"
  # Act: call dc_print_footer
  local out
  out="$(dc_print_footer "/t/trace.jsonl" "$last" "/t/stderr" "1" "m")"
  # Assert: the "=== final message ===" header is absent when .last is empty
  if ! grep -q 'final message' <<<"$out"; then
    pass "$name"
  else
    fail "$name" "should not print '=== final message ===' for empty last"
  fi
}

# ── dc_snapshot_copy_libs ─────────────────────────────────────────────────────

case_snapshot_copy_libs_copies_dispatch_common() {
  local name="dc_snapshot_copy_libs/copies dispatch-common.sh"; should_run "$name" || return 0
  # Arrange: an empty snapshot dir and the real repo root
  local snap="$tmp_root/snap_copy"
  mkdir -p "$snap"
  # Act: call dc_snapshot_copy_libs
  dc_snapshot_copy_libs "$snap" "$REPO_ROOT"
  # Assert: dispatch-common.sh is present in the snapshot lib dir
  if [[ -f "$snap/lib/dispatch-common.sh" ]]; then
    pass "$name"
  else
    fail "$name" "dispatch-common.sh not found in snapshot lib dir"
  fi
}

# Behavior: snapshot creation copies every library declared by the canonical
# dispatch snapshot inventory.
# Steps: Arrange an empty snapshot; Act by copying the shared libraries; Assert
# every canonical inventory entry exists in the resulting lib directory.
case_snapshot_copy_libs_copies_all_core_libs() {
  local name="dc_snapshot_copy_libs/copies all core shared libs"; should_run "$name" || return 0
  # Arrange: an empty snapshot dir and the real repo root
  local snap="$tmp_root/snap_all_libs"
  mkdir -p "$snap"
  # Act: call dc_snapshot_copy_libs
  dc_snapshot_copy_libs "$snap" "$REPO_ROOT"
  # Assert: every item in the canonical snapshot inventory is present.
  local missing=()
  while IFS= read -r lib; do
    [[ -n "$lib" ]] || continue
    [[ -f "$snap/lib/$lib" ]] || missing+=("$lib")
  done < <(dc_snapshot_lib_names)
  if [[ "${#missing[@]}" -eq 0 ]]; then
    pass "$name"
  else
    fail "$name" "missing: ${missing[*]}"
  fi
}

# Behavior: the installed Adapter bootstrap inventory extends the canonical
# dispatch snapshot with runner and manifest readers exactly once.
# Steps: Arrange the expected snapshot-plus-bootstrap list; Act by reading the
# installed inventory; Assert exact ordering and the absence of duplicate names.
case_installed_adapter_inventory_extends_snapshot_once() {
  local name="dc_installed_adapter_lib_names/extends canonical snapshot"; should_run "$name" || return 0
  local expected actual
  expected="$(dc_snapshot_lib_names)"$'\n''runner-kind.sh'$'\n''adapter-manifest.sh'
  actual="$(dc_installed_adapter_lib_names)"
  if [[ "$actual" == "$expected" \
      && "$(printf '%s\n' "$actual" | sort | uniq -d)" == "" ]]; then
    pass "$name"
  else
    fail "$name" "installed Adapter inventory drifted or contains duplicates"
  fi
}

case_snapshot_copy_libs_creates_lib_dir() {
  local name="dc_snapshot_copy_libs/creates lib/ subdir"; should_run "$name" || return 0
  # Arrange: snapshot dir without a lib/ subdirectory
  local snap="$tmp_root/snap_mkdir"
  mkdir -p "$snap"
  rm -rf "${snap:?}/lib"
  # Act: call dc_snapshot_copy_libs
  dc_snapshot_copy_libs "$snap" "$REPO_ROOT"
  # Assert: lib/ directory was created
  if [[ -d "$snap/lib" ]]; then
    pass "$name"
  else
    fail "$name" "lib/ not created"
  fi
}

# ── dc_snapshot_copy_extras ───────────────────────────────────────────────────

case_snapshot_copy_extras_copies_present_makes_parents() {
  local name="dc_snapshot_copy_extras/copies present pairs and mkdir -p the parent"
  should_run "$name" || return 0
  local repo="$tmp_root/extras_repo" snap="$tmp_root/extras_snap"
  mkdir -p "$repo/share" "$repo/adapters/x" "$snap"
  printf 'A\n' > "$repo/share/a.tsv"
  printf 'B\n' > "$repo/adapters/x/isolation-map.yaml"
  dc_snapshot_copy_extras "$snap" "$repo" \
    share/a.tsv                    a.tsv \
    adapters/x/isolation-map.yaml  adapters/x/isolation-map.yaml
  if [[ "$(cat "$snap/a.tsv")" == "A" \
     && "$(cat "$snap/adapters/x/isolation-map.yaml")" == "B" ]]; then
    pass "$name"
  else
    fail "$name" "expected both assets copied into the snapshot with parents created"
  fi
}

case_snapshot_copy_extras_skips_absent_silently() {
  local name="dc_snapshot_copy_extras/absent source is skipped without error"
  should_run "$name" || return 0
  local repo="$tmp_root/extras_repo2" snap="$tmp_root/extras_snap2" rc=0
  mkdir -p "$repo" "$snap"
  dc_snapshot_copy_extras "$snap" "$repo" nope/missing.tsv missing.tsv 2>/dev/null || rc=$?
  if [[ "$rc" -eq 0 && ! -e "$snap/missing.tsv" ]]; then
    pass "$name"
  else
    fail "$name" "rc=$rc; an unreadable source must be skipped, not fail"
  fi
}

# ── dc_run_timestamp ──────────────────────────────────────────────────────────

case_run_timestamp_shape() {
  local name="dc_run_timestamp/sets DC_TS to YYYYMMDD-HHMMSS-<pid>"; should_run "$name" || return 0
  DC_TS=""
  dc_run_timestamp
  if [[ "$DC_TS" =~ ^[0-9]{8}-[0-9]{6}-[0-9]+$ ]]; then
    pass "$name"
  else
    fail "$name" "DC_TS=[$DC_TS] does not match the trace timestamp shape"
  fi
}

# ── dc_resolve_sibling_file ───────────────────────────────────────────────────

case_resolve_sibling_first_existing() {
  local name="dc_resolve_sibling_file/picks the first existing candidate"; should_run "$name" || return 0
  local d="$tmp_root/rsf1"; mkdir -p "$d"; : > "$d/second"
  local got=""
  dc_resolve_sibling_file got "$d/first" "$d/second" "$d/third"
  if [[ "$got" == "$d/second" ]]; then pass "$name"; else fail "$name" "got=[$got]"; fi
}

case_resolve_sibling_none_sets_last_returns_1() {
  local name="dc_resolve_sibling_file/none exist → last candidate, return 1, no output"; should_run "$name" || return 0
  local d="$tmp_root/rsf2"; mkdir -p "$d"
  local got="" rc=0 errfile="$tmp_root/rsf2.err"
  # Call directly (not in $()) so printf -v reaches this scope, like the adapters.
  dc_resolve_sibling_file got "$d/a" "$d/b" "$d/c" 2>"$errfile" || rc=$?
  if [[ "$rc" -eq 1 && "$got" == "$d/c" && ! -s "$errfile" ]]; then
    pass "$name"
  else
    fail "$name" "rc=$rc got=[$got] err=[$(cat "$errfile" 2>/dev/null)]"
  fi
}

# ── dc_parse_common_flags ─────────────────────────────────────────────────────

case_parse_common_flags_shared_set() {
  local name="dc_parse_common_flags/sets each shared flag and clears the rest"; should_run "$name" || return 0
  dc_parse_common_flags --cd /w --model m1 --isolation read-only --timeout 42 \
    --brief-file /b.md --trace-dir /t --print-cmd
  if [[ "$DC_WORK_DIR" == /w && "$DC_MODEL" == m1 && "$DC_ISOLATION" == read-only \
     && "$DC_TIMEOUT" == 42 && "$DC_BRIEF_FILE" == /b.md && "$DC_TRACE_DIR_OVERRIDE" == /t \
     && "$DC_PRINT_CMD" -eq 1 && "$DC_HELP" -eq 0 && "${#DC_RESIDUAL_ARGS[@]}" -eq 0 ]]; then
    pass "$name"
  else
    fail "$name" "work=$DC_WORK_DIR model=$DC_MODEL iso=$DC_ISOLATION to=$DC_TIMEOUT bf=$DC_BRIEF_FILE td=$DC_TRACE_DIR_OVERRIDE pc=$DC_PRINT_CMD help=$DC_HELP residual=${DC_RESIDUAL_ARGS[*]:-}"
  fi
}

case_parse_common_flags_residual_preserves_order() {
  local name="dc_parse_common_flags/unrecognised tokens go to DC_RESIDUAL_ARGS in order, no error"; should_run "$name" || return 0
  local rc=0
  dc_parse_common_flags --effort high --cd /w --sandbox ro --skip-git-check || rc=$?
  if [[ "$rc" -eq 0 && "$DC_WORK_DIR" == /w \
     && "${DC_RESIDUAL_ARGS[*]}" == "--effort high --sandbox ro --skip-git-check" ]]; then
    pass "$name"
  else
    fail "$name" "rc=$rc work=$DC_WORK_DIR residual=[${DC_RESIDUAL_ARGS[*]:-}]"
  fi
}

case_parse_common_flags_double_dash_kept_for_tail() {
  local name="dc_parse_common_flags/-- and everything after it stays in DC_RESIDUAL_ARGS"; should_run "$name" || return 0
  dc_parse_common_flags --cd /w -- an inline brief here
  if [[ "${DC_RESIDUAL_ARGS[*]}" == "-- an inline brief here" ]]; then
    pass "$name"
  else
    fail "$name" "residual=[${DC_RESIDUAL_ARGS[*]:-}]"
  fi
}

case_parse_common_flags_help_stops() {
  local name="dc_parse_common_flags/-h sets DC_HELP and stops consuming"; should_run "$name" || return 0
  dc_parse_common_flags --cd /w -h --model ignored
  if [[ "$DC_HELP" -eq 1 && "$DC_WORK_DIR" == /w ]]; then pass "$name"; else fail "$name" "help=$DC_HELP work=$DC_WORK_DIR"; fi
}

case_parse_common_flags_missing_value_fails() {
  local name="dc_parse_common_flags/value-flag missing its value returns 2"; should_run "$name" || return 0
  local rc=0
  dc_parse_common_flags --model 2>/dev/null || rc=$?
  if [[ "$rc" -eq 2 ]]; then pass "$name"; else fail "$name" "rc=$rc (expected 2)"; fi
}

# ── Structural: shared lib stays adapter-agnostic ─────────────────────────────

case_dispatch_common_no_adapter_name_in_code() {
  local name="dispatch-common.sh/no adapter name branches in code"; should_run "$name" || return 0
  # Strip comments, then look for an adapter literal or a per-adapter case.
  local code
  code="$(grep -vE '^\s*#' "$REPO_ROOT/runtime/lib/dispatch-common.sh")"
  if grep -qE '\b(codex|claude|opencode|grok)\b' <<<"$code"; then
    fail "$name" "dispatch-common.sh names an adapter in code; the per-adapter data must be passed in by the caller"
  else
    pass "$name"
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
case_installed_adapter_inventory_extends_snapshot_once
case_snapshot_copy_libs_creates_lib_dir

case_snapshot_copy_extras_copies_present_makes_parents
case_snapshot_copy_extras_skips_absent_silently
case_run_timestamp_shape
case_resolve_sibling_first_existing
case_resolve_sibling_none_sets_last_returns_1
case_parse_common_flags_shared_set
case_parse_common_flags_residual_preserves_order
case_parse_common_flags_double_dash_kept_for_tail
case_parse_common_flags_help_stops
case_parse_common_flags_missing_value_fails
case_dispatch_common_no_adapter_name_in_code

th_summary
