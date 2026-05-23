#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RUN_STATUS=0
# shellcheck source=scripts/lib/test-harness.sh
. "$SCRIPT_DIR/lib/test-harness.sh"
th_init "$@"

fail() {
  local name="$1" detail="${2:-}"
  printf '  FAIL  %s\n' "$name"
  if [[ -n "$detail" ]]; then
    printf '        %s\n' "$detail"
  fi
  FAIL=$((FAIL + 1))
  FAILED_CASES+=("$name")
  th_summary
  exit 1
}

assert_exit() {
  local name="$1" actual="$2" expected="$3"
  if [[ "$actual" != "$expected" ]]; then
    fail "$name" "expected exit=$expected, got exit=$actual"
  fi
}

assert_contains() {
  local name="$1" file="$2" needle="$3"
  if ! grep -Fq -- "$needle" "$file"; then
    fail "$name" "missing substring: $needle"
  fi
}

assert_not_contains() {
  local name="$1" file="$2" needle="$3"
  if grep -Fq -- "$needle" "$file"; then
    fail "$name" "unexpected substring: $needle"
  fi
}

make_repo() {
  local name repo
  name="$1"
  repo="$tmp_root/$name"
  mkdir -p "$repo/scripts" "$repo/commands"
  cp "$REPO_ROOT/scripts/skill-refine.sh" "$repo/scripts/skill-refine.sh"
  printf '# testskill\n' > "$repo/commands/testskill.md"
  printf '# otherskill\n' > "$repo/commands/otherskill.md"
  printf '%s\n' "$repo"
}

run_skill_refine() {
  local repo="$1" skill="$2" memory_dir="$3" home_dir="$4" out="$5" err="$6"
  set +e
  CLAUDE_MEMORY_DIR="$memory_dir" HOME="$home_dir" bash "$repo/scripts/skill-refine.sh" "$skill" > "$out" 2> "$err"
  RUN_STATUS=$?
  set -e
}

run_skill_refine_unset_env() {
  local repo="$1" skill="$2" home_dir="$3" out="$4" err="$5"
  set +e
  env -u CLAUDE_MEMORY_DIR HOME="$home_dir" bash "$repo/scripts/skill-refine.sh" "$skill" > "$out" 2> "$err"
  RUN_STATUS=$?
  set -e
}

# Behavior: Matching feedback files under a valid memory dir yield candidate entries with correct headings.
# Steps:
#   1. Stage the fixture repo with a valid command file and matching feedback files.
#   2. Invoke skill-refine with CLAUDE_MEMORY_DIR pointing at the fixture memory dir.
#   3. Assert the output reports the expected candidates and renders their headings.
case_happy_path() {
  local name="happy_path_multi_candidate" repo out err status
  should_run "$name" || return 0
  repo="$(make_repo "$name")"
  out="$tmp_root/$name.out"
  err="$tmp_root/$name.err"

  run_skill_refine "$repo" testskill "$REPO_ROOT/scripts/fixtures/skill-refine" "$tmp_root/no-home" "$out" "$err"
  status=$RUN_STATUS

  assert_exit "$name" "$status" 0
  assert_contains "$name" "$out" "# Skill refine signals: testskill"
  assert_contains "$name" "$out" "Found 2 candidate(s). Scanned $REPO_ROOT/scripts/fixtures/skill-refine at "
  assert_contains "$name" "$out" "## feedback_alpha"
  assert_contains "$name" "$out" "## feedback_beta"
  assert_contains "$name" "$out" "- description: Frontmatter mentions testskill for a frontmatter-only match."
  assert_contains "$name" "$out" "- description: Beta covers a different command."
  assert_contains "$name" "$out" "- Why: testskill should learn from explicit user corrections."
  assert_contains "$name" "$out" "- How to apply: Add a focused checklist before running testskill."
  assert_contains "$name" "$out" "- file: $REPO_ROOT/scripts/fixtures/skill-refine/feedback_alpha.md"
  assert_contains "$name" "$out" "_M1 spike: read-only signal bundling. No diff generation yet (M2)._"
  assert_not_contains "$name" "$out" "feedback_gamma"
  if [[ -s "$err" ]]; then
    fail "$name" "unexpected stderr: $(sed -n '1p' "$err")"
  fi
  pass "$name"
}

# Behavior: Multiple matching feedback files appear in LC_ALL=C lexicographic order.
# Steps:
#   1. Stage two matching fixture feedback files in the fixture memory dir.
#   2. Invoke skill-refine with the fixture memory dir.
#   3. Assert the feedback_alpha heading appears before feedback_beta.
case_deterministic_order() {
  local name="deterministic_order" repo out err status alpha_line beta_line
  should_run "$name" || return 0
  repo="$(make_repo "$name")"
  out="$tmp_root/$name.out"
  err="$tmp_root/$name.err"

  run_skill_refine "$repo" testskill "$REPO_ROOT/scripts/fixtures/skill-refine" "$tmp_root/no-home" "$out" "$err"
  status=$RUN_STATUS

  assert_exit "$name" "$status" 0
  alpha_line="$(grep -n '^## feedback_alpha$' "$out" | sed 's/:.*//')"
  beta_line="$(grep -n '^## feedback_beta$' "$out" | sed 's/:.*//')"
  if [[ -z "$alpha_line" || -z "$beta_line" || "$alpha_line" -ge "$beta_line" ]]; then
    fail "$name" "expected feedback_alpha before feedback_beta"
  fi
  pass "$name"
}

# Behavior: Missing commands/<name>.md exits 2 with a clear error.
# Steps:
#   1. Stage a fixture repo without commands/missing.md.
#   2. Invoke skill-refine for the missing skill name.
#   3. Assert exit 2 and stderr names the missing command file.
case_missing_command_file() {
  local name="missing_command_file" repo out err status
  should_run "$name" || return 0
  repo="$(make_repo "$name")"
  out="$tmp_root/$name.out"
  err="$tmp_root/$name.err"

  run_skill_refine "$repo" missing "$REPO_ROOT/scripts/fixtures/skill-refine" "$tmp_root/no-home" "$out" "$err"
  status=$RUN_STATUS

  assert_exit "$name" "$status" 2
  assert_contains "$name" "$err" "Error: skill command file not found: $repo/commands/missing.md"
  pass "$name"
}

# Behavior: CLAUDE_MEMORY_DIR unset OR pointing at a nonexistent dir both exit 2.
# Steps:
#   1. Unset CLAUDE_MEMORY_DIR, invoke skill-refine, and assert exit 2 plus CLAUDE_MEMORY_DIR in stderr.
#   2. Set CLAUDE_MEMORY_DIR to a nonexistent dir, invoke skill-refine, and assert exit 2 plus CLAUDE_MEMORY_DIR in stderr.
case_bad_memory_dir() {
  local name="bad_memory_dir" repo home out err status unset_out unset_err unset_status
  should_run "$name" || return 0
  repo="$(make_repo "$name")"
  home="$tmp_root/$name-home"
  out="$tmp_root/$name.out"
  err="$tmp_root/$name.err"
  unset_out="$tmp_root/$name-unset.out"
  unset_err="$tmp_root/$name-unset.err"
  mkdir -p "$home"

  run_skill_refine_unset_env "$repo" testskill "$home" "$unset_out" "$unset_err"
  unset_status=$RUN_STATUS

  assert_exit "$name" "$unset_status" 2
  assert_contains "$name" "$unset_err" "CLAUDE_MEMORY_DIR"
  assert_contains "$name" "$unset_err" "exported pointing at your memory dir"

  run_skill_refine "$repo" testskill "$tmp_root/definitely-not-a-dir" "$home" "$out" "$err"
  status=$RUN_STATUS

  assert_exit "$name" "$status" 2
  assert_contains "$name" "$err" "CLAUDE_MEMORY_DIR"
  assert_contains "$name" "$err" "$tmp_root/definitely-not-a-dir"
  pass "$name"
}

# Behavior: A valid memory dir with no matching tokens prints zero-candidate notice and exits 0.
# Steps:
#   1. Stage an empty writable memory dir for a valid fixture repo.
#   2. Invoke skill-refine for a command with no matching feedback tokens.
#   3. Assert the zero-candidate count and No matching notice are printed.
case_zero_candidates() {
  local name="zero_candidates" repo memory out err status
  should_run "$name" || return 0
  repo="$(make_repo "$name")"
  memory="$tmp_root/$name-memory"
  out="$tmp_root/$name.out"
  err="$tmp_root/$name.err"
  mkdir -p "$memory"

  run_skill_refine "$repo" otherskill "$memory" "$tmp_root/no-home" "$out" "$err"
  status=$RUN_STATUS

  assert_exit "$name" "$status" 0
  assert_contains "$name" "$out" "Found 0 candidate(s). Scanned $memory at "
  assert_contains "$name" "$out" "No matching feedback entries found for \`otherskill\`."
  assert_contains "$name" "$out" "_M1 spike: read-only signal bundling. No diff generation yet (M2)._"
  pass "$name"
}

# Behavior: A feedback file lacking Why/How fields still renders with _(not present)_ placeholders.
# Steps:
#   1. Stage a matching feedback fixture without Why or How to apply fields.
#   2. Invoke skill-refine with CLAUDE_MEMORY_DIR pointing at that fixture.
#   3. Assert the missing fields render as _(not present)_ placeholders.
case_missing_fields() {
  local name="missing_fields" repo memory out err status
  should_run "$name" || return 0
  repo="$(make_repo "$name")"
  memory="$tmp_root/$name-memory"
  out="$tmp_root/$name.out"
  err="$tmp_root/$name.err"
  mkdir -p "$memory"
  printf '%s\n' '---' 'description: testskill missing body fields' '---' '' 'Body references testskill only.' > "$memory/feedback_missing.md"

  run_skill_refine "$repo" testskill "$memory" "$tmp_root/no-home" "$out" "$err"
  status=$RUN_STATUS

  assert_exit "$name" "$status" 0
  assert_contains "$name" "$out" "## feedback_missing"
  assert_contains "$name" "$out" "- Why: _(not present)_"
  assert_contains "$name" "$out" "- How to apply: _(not present)_"
  pass "$name"
}

# Behavior: Explicit CLAUDE_MEMORY_DIR pointing at a writable directory with a matching fixture yields candidates.
# Steps:
#   1. Create a temp memory dir and fixture repo with commands/testskill.md.
#   2. Write a matching feedback_testskill.md fixture into the memory dir.
#   3. Export CLAUDE_MEMORY_DIR through the invocation and assert exit 0 plus at least one candidate.
case_env_set_success() {
  local name="env_set_success" repo memory out err status candidate_count
  should_run "$name" || return 0
  repo="$(make_repo "$name")"
  memory="$tmp_root/$name-memory"
  out="$tmp_root/$name.out"
  err="$tmp_root/$name.err"
  mkdir -p "$memory"
  printf '%s\n' '---' 'description: testskill from env-set memory dir' '---' '' 'Why: testskill should read explicit env memory.' 'How to apply: Keep CLAUDE_MEMORY_DIR exported for this run.' > "$memory/feedback_testskill.md"

  run_skill_refine "$repo" testskill "$memory" "$tmp_root/no-home" "$out" "$err"
  status=$RUN_STATUS

  assert_exit "$name" "$status" 0
  candidate_count="$(awk '/^Found [0-9]+ candidate/ { print $2; exit }' "$out")"
  if [[ -z "$candidate_count" || "$candidate_count" -lt 1 ]]; then
    fail "$name" "expected at least one candidate"
  fi
  assert_contains "$name" "$out" "## feedback_testskill"
  pass "$name"
}

# Behavior: SKILL_NAME values containing path separators or whitespace are rejected with exit 2.
# Steps:
#   1. For each bad input, invoke skill-refine with a valid CLAUDE_MEMORY_DIR.
#   2. Assert exit 2 for each invocation.
#   3. Assert stderr names the rejected invalid value.
case_invalid_skill_name() {
  local name="invalid_skill_name" repo memory out err status bad_input safe_name
  should_run "$name" || return 0
  repo="$(make_repo "$name")"
  memory="$tmp_root/$name-memory"
  mkdir -p "$memory"

  for bad_input in '../foo' 'foo bar'; do
    safe_name="${bad_input//[^A-Za-z0-9]/_}"
    out="$tmp_root/$name-$safe_name.out"
    err="$tmp_root/$name-$safe_name.err"

    run_skill_refine "$repo" "$bad_input" "$memory" "$tmp_root/no-home" "$out" "$err"
    status=$RUN_STATUS

    assert_exit "$name" "$status" 2
    assert_contains "$name" "$err" "invalid skill name: $bad_input"
  done
  pass "$name"
}

# Behavior: Invoking skill-refine with no arguments exits 2 and prints Usage: to stderr.
# Steps:
#   1. Stage a fixture repo with a valid command file.
#   2. Invoke skill-refine with no arguments.
#   3. Assert exit 2 and that stderr contains "Usage:".
case_no_args_exits_2_with_usage() {
  local name="no_args_exits_2_with_usage" repo out err
  should_run "$name" || return 0
  repo="$(make_repo "$name")"
  out="$tmp_root/$name.out"
  err="$tmp_root/$name.err"
  set +e
  bash "$repo/scripts/skill-refine.sh" > "$out" 2> "$err"
  local status=$?
  set -e
  assert_exit "$name" "$status" 2
  assert_contains "$name" "$err" "Usage:"
  pass "$name"
}

# Behavior: Invoking skill-refine with multiple arguments exits 2 and prints Usage: to stderr.
# Steps:
#   1. Stage a fixture repo with a valid command file.
#   2. Invoke skill-refine with two arguments (foo bar).
#   3. Assert exit 2 and that stderr contains "Usage:".
case_multi_args_exits_2_with_usage() {
  local name="multi_args_exits_2_with_usage" repo out err
  should_run "$name" || return 0
  repo="$(make_repo "$name")"
  out="$tmp_root/$name.out"
  err="$tmp_root/$name.err"
  set +e
  bash "$repo/scripts/skill-refine.sh" foo bar > "$out" 2> "$err"
  local status=$?
  set -e
  assert_exit "$name" "$status" 2
  assert_contains "$name" "$err" "Usage:"
  pass "$name"
}

case_happy_path
case_deterministic_order
case_missing_command_file
case_bad_memory_dir
case_zero_candidates
case_missing_fields
case_env_set_success
case_invalid_skill_name
case_no_args_exits_2_with_usage
case_multi_args_exits_2_with_usage

th_summary
