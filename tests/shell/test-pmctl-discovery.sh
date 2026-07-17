#!/usr/bin/env bash
# Regression tests for pmctl help, command discovery, and parity lint.
# shellcheck disable=SC2154  # tmp_root is supplied by the sourced test harness.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PMCTL="$REPO_ROOT/cli/pmctl"
LINT="$REPO_ROOT/tools/lint/lint-pmctl-commands.sh"

# shellcheck source=tests/lib/test-harness.sh
# shellcheck disable=SC1091
. "$SCRIPT_DIR/../lib/test-harness.sh"
# shellcheck source=tests/lib/test-pmctl-fixture.sh
# shellcheck disable=SC1091
. "$SCRIPT_DIR/../lib/test-pmctl-fixture.sh"
th_init "$@"

run_capture() {
  local out="$1" err="$2"
  shift 2
  "$@" > "$out" 2> "$err"
}

copy_parity_fixture() {
  local target="$1"
  pmctl_fixture_copy_spine "$REPO_ROOT" "$target"
  cp "$REPO_ROOT/README.md" "$target/README.md"
}

case_root_help_variants() {
  local name="pmctl discovery: root help variants exit 0"
  should_run "$name" || return 0
  local out="$tmp_root/root.out" err="$tmp_root/root.err" args
  for args in "" "--help" "help"; do
    if [[ -z "$args" ]]; then
      run_capture "$out" "$err" "$PMCTL" || { fail "$name" "no-arg help failed"; return; }
    else
      run_capture "$out" "$err" "$PMCTL" "$args" || { fail "$name" "$args failed"; return; }
    fi
    assert_file_contains "$name" "$out" "pmctl commands --json" || return
    assert_file_contains "$name" "$out" "Stability: experimental" || return
  done
  pass "$name"
}

case_area_and_leaf_help() {
  local name="pmctl discovery: area and leaf help expose workflow metadata"
  should_run "$name" || return 0
  local out="$tmp_root/help.out" err="$tmp_root/help.err"
  run_capture "$out" "$err" "$PMCTL" task --help || { fail "$name" "area help failed"; return; }
  assert_file_contains "$name" "$out" "list" || return
  assert_file_contains "$name" "$out" "review" || return
  run_capture "$out" "$err" "$PMCTL" help task list || { fail "$name" "help area leaf failed"; return; }
  assert_file_contains "$name" "$out" "pmctl task list" || return
  assert_file_contains "$name" "$out" "Main options:" || return
  assert_file_contains "$name" "$out" "Example:" || return
  run_capture "$out" "$err" "$PMCTL" task list --help || { fail "$name" "leaf --help failed"; return; }
  assert_file_contains "$name" "$out" "JSON output: true" || return
  pass "$name"
}

case_help_has_no_home_side_effects() {
  local name="pmctl discovery: help does not initialize or write HOME"
  should_run "$name" || return 0
  local home="$tmp_root/empty-home" out="$tmp_root/no-side.out" err="$tmp_root/no-side.err"
  mkdir -p "$home"
  HOME="$home" run_capture "$out" "$err" "$PMCTL" help memory doctor || {
    fail "$name" "help failed: $(<"$err")"; return
  }
  if find "$home" -mindepth 1 -print -quit | grep -q .; then
    fail "$name" "help wrote into isolated HOME"
    return
  fi
  pass "$name"
}

case_commands_json_contract() {
  local name="pmctl discovery: commands JSON covers registry with typed flags"
  should_run "$name" || return 0
  local out="$tmp_root/commands.json" err="$tmp_root/commands.err"
  run_capture "$out" "$err" "$PMCTL" commands --json || { fail "$name" "commands failed"; return; }
  if jq -e --argjson count "$(( $(wc -l < "$REPO_ROOT/cli/commands.tsv") - 1 ))" \
    '.commands | length == $count and all(.[]; (.path|type)=="string" and (.json|type)=="boolean" and (.mutating|type)=="boolean")' "$out" >/dev/null; then
    pass "$name"
  else
    fail "$name" "invalid commands JSON"
  fi
}

case_unknown_command_suggests_nearest() {
  local name="pmctl discovery: unknown command suggests nearest path"
  should_run "$name" || return 0
  local out="$tmp_root/unknown.out" err="$tmp_root/unknown.err" status=0
  run_capture "$out" "$err" "$PMCTL" task statsu && status=$? || status=$?
  if [[ "$status" -eq 2 ]] \
    && grep -Fq 'Did you mean "task status"?' "$err" \
    && grep -Fq 'pmctl --help' "$err"; then
    pass "$name"
  else
    fail "$name" "status=$status stderr=$(<"$err")"
  fi
}

case_parity_lint_accepts_canonical_tree() {
  local name="pmctl discovery: parity lint accepts canonical tree"
  should_run "$name" || return 0
  local out="$tmp_root/lint.out" err="$tmp_root/lint.err"
  run_capture "$out" "$err" "$LINT" || { fail "$name" "$(<"$err")"; return; }
  assert_file_contains "$name" "$out" "OK" || return
  pass "$name"
}

case_parity_lint_rejects_router_only_command() {
  local name="pmctl discovery: parity lint rejects router-only command"
  should_run "$name" || return 0
  local fixture="$tmp_root/router-only" out="$tmp_root/router-only.out" err="$tmp_root/router-only.err" status=0
  copy_parity_fixture "$fixture"
  sed -i '/^  adapter\/generate)/i\  probe/check)\n    :\n    ;;' "$fixture/cli/pmctl"
  run_capture "$out" "$err" "$LINT" --repo "$fixture" && status=$? || status=$?
  if [[ "$status" -ne 0 ]] && grep -Fq "router and registry" "$err"; then pass "$name"; else fail "$name" "lint unexpectedly accepted injection"; fi
}

case_parity_lint_rejects_registry_only_command() {
  local name="pmctl discovery: parity lint rejects registry-only command"
  should_run "$name" || return 0
  local fixture="$tmp_root/registry-only" out="$tmp_root/registry-only.out" err="$tmp_root/registry-only.err" status=0
  copy_parity_fixture "$fixture"
  printf 'probe check\tInjected path.\tpmctl probe check\texperimental\tfalse\tfalse\tnone\tpmctl probe check\n' >> "$fixture/cli/commands.tsv"
  run_capture "$out" "$err" "$LINT" --repo "$fixture" && status=$? || status=$?
  if [[ "$status" -ne 0 ]] && grep -Fq "router and registry" "$err"; then pass "$name"; else fail "$name" "lint unexpectedly accepted injection"; fi
}

case_parity_lint_rejects_stale_readme() {
  local name="pmctl discovery: parity lint rejects stale README entry"
  should_run "$name" || return 0
  local fixture="$tmp_root/stale-readme" out="$tmp_root/stale-readme.out" err="$tmp_root/stale-readme.err" status=0
  copy_parity_fixture "$fixture"
  # shellcheck disable=SC2016  # Markdown backticks are literal fixture data.
  sed -i '/`task list`/d' "$fixture/README.md"
  run_capture "$out" "$err" "$LINT" --repo "$fixture" && status=$? || status=$?
  if [[ "$status" -ne 0 ]] && grep -Fq "README command index differs" "$err"; then pass "$name"; else fail "$name" "lint unexpectedly accepted stale README"; fi
}

case_parity_lint_rejects_incomplete_help_metadata() {
  local name="pmctl discovery: parity lint rejects incomplete help metadata"
  should_run "$name" || return 0
  local fixture="$tmp_root/incomplete-metadata" out="$tmp_root/incomplete.out" err="$tmp_root/incomplete.err" status=0
  copy_parity_fixture "$fixture"
  sed -i 's/^task list\tList tasks\.\t/task list\t\t/' "$fixture/cli/commands.tsv"
  run_capture "$out" "$err" "$LINT" --repo "$fixture" && status=$? || status=$?
  if [[ "$status" -ne 0 ]] && grep -Fq "malformed registry" "$err"; then pass "$name"; else fail "$name" "lint unexpectedly accepted incomplete metadata"; fi
}

case_root_help_variants
case_area_and_leaf_help
case_help_has_no_home_side_effects
case_commands_json_contract
case_unknown_command_suggests_nearest
case_parity_lint_accepts_canonical_tree
case_parity_lint_rejects_router_only_command
case_parity_lint_rejects_registry_only_command
case_parity_lint_rejects_stale_readme
case_parity_lint_rejects_incomplete_help_metadata

th_summary
