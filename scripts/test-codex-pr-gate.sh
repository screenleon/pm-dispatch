#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

PASS=0
FAIL=0
FAILED_CASES=()

pass() {
  PASS=$((PASS + 1))
  printf 'PASS: %s\n' "$1"
}

fail() {
  FAIL=$((FAIL + 1))
  FAILED_CASES+=("$1")
  printf 'FAIL: %s: %s\n' "$1" "$2"
}

assert_contains() {
  local name="$1" file="$2" needle="$3"
  if ! grep -Fq -- "$needle" "$file"; then
    fail "$name" "missing output: $needle"
    return 1
  fi
}

assert_not_contains() {
  local name="$1" file="$2" needle="$3"
  if grep -Fq -- "$needle" "$file"; then
    fail "$name" "unexpected output: $needle"
    return 1
  fi
}

create_runner() {
  local dir="$1"
  mkdir -p "$dir"
  cp "$REPO_ROOT/scripts/codex-pr-gate.sh" "$dir/codex-pr-gate.sh"
  chmod +x "$dir/codex-pr-gate.sh"
  cat > "$dir/codex-dispatch.sh" <<'STUB_EOF'
#!/usr/bin/env bash
set -euo pipefail

brief_file=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --brief-file) brief_file="$2"; shift 2;;
    --cd|--timeout) shift 2;;
    *) shift;;
  esac
done

printf 'DISPATCH_STUB:%s\n' "${CODEX_GATE_STUB_MODE:-success}"

if [[ -n "${CODEX_GATE_BRIEF_EXISTS_MARKER:-}" ]]; then
  if [[ -f "$brief_file" && "$brief_file" == */.codex-briefs/pr-gate-*.md ]]; then
    printf 'brief-present\n' > "$CODEX_GATE_BRIEF_EXISTS_MARKER"
  else
    printf 'brief-missing-or-wrong-path: %s\n' "$brief_file" >&2
    exit 3
  fi
fi

if [[ -n "${CODEX_GATE_CAPTURE_BRIEF:-}" ]]; then
  cp "$brief_file" "$CODEX_GATE_CAPTURE_BRIEF"
fi

# Simulate injection: modify a tracked file if CODEX_GATE_STUB_INJECT_FILE is set.
if [[ -n "${CODEX_GATE_STUB_INJECT_FILE:-}" && "$brief_file" != *-synthesis.md ]]; then
  printf 'injected\n' >> "$CODEX_GATE_STUB_INJECT_FILE"
fi

# Determine effective mode: synthesis briefs can have their own mode override.
if [[ "$brief_file" == *-synthesis.md ]]; then
  effective_mode="${CODEX_GATE_STUB_SYNTHESIS_MODE:-${CODEX_GATE_STUB_MODE:-success}}"
else
  effective_mode="${CODEX_GATE_STUB_MODE:-success}"
fi

case "$effective_mode" in
  fail)
    # Non-zero exit — caught by FAILED_REVIEWERS check.
    exit 1
    ;;
  no-output)
    # Exits 0 without writing output file — simulates a session that silently
    # failed its task (caught by missing-output or synthesis-output check).
    exit 0
    ;;
  no-verdict)
    # Writes a non-empty output file but omits the Verdict line — simulates
    # malformed reviewer output (caught by reviewer structure validation).
    output_path=$(grep -o '\- new:.*' "$brief_file" | head -1 | awk '{print $NF}')
    if [[ -n "$output_path" ]]; then
      mkdir -p "$(dirname "$output_path")"
      printf '## stub-reviewer\nSome content without a verdict line.\n' > "$output_path"
    fi
    exit 0
    ;;
  *)
    # Success: write a stub output file so the gate's output validation passes.
    output_path=$(grep -o '\- new:.*' "$brief_file" | head -1 | awk '{print $NF}')
    if [[ -n "$output_path" ]]; then
      mkdir -p "$(dirname "$output_path")"
      if [[ "$brief_file" == *-synthesis.md ]]; then
        # Synthesis brief: write a minimal but structurally valid gate result.
        printf '# PR-Gate Result — stub tier (parallel codex mode)\n**Date**: 2026-01-01\n**Reviewers**: stub\n**Not reviewed**: none\n\n## stub-reviewer — advise\n- stub finding\n\nVerdict: advise. Stub output.\n\n## Cross-Reviewer Overlaps\nnone\n\n## Coverage Notes\n**Dimensions not covered**: none\n\n## Gate Conclusion\n**Overall verdict**: advise\n**Most severe individual verdict**: advise\nFinal: GO\n\nRequired fixes before GO: none\n\nRecommended follow-ups:\n- none\n\nRationale: Stub synthesis output.\n' > "$output_path"
      else
        printf '## stub-reviewer — advise\nVerdict: advise. Stub output.\n' > "$output_path"
      fi
    fi
    exit 0
    ;;
esac
STUB_EOF
  chmod +x "$dir/codex-dispatch.sh"
}

create_agents() {
  local home="$1"
  shift
  mkdir -p "$home/.claude/agents"
  local reviewer
  for reviewer in "$@"; do
    printf '# %s\n\nReviewer fixture.\n' "$reviewer" > "$home/.claude/agents/$reviewer.md"
  done
}

create_repo() {
  local repo="$1" mode="${2:-clean}"
  git init -q -b main "$repo"
  (
    cd "$repo"
    git config user.email test@example.com
    git config user.name 'Gate Test'
    printf 'initial\n' > README.md
    git add README.md
    git commit -q -m initial
    case "$mode" in
      clean) ;;
      docs)
        printf 'docs change\n' >> README.md
        ;;
      many)
        for n in $(seq 1 130); do
          printf 'line %s\n' "$n" >> app.txt
        done
        ;;
      *)
        printf 'unknown repo mode: %s\n' "$mode" >&2
        exit 2
        ;;
    esac
  )
}

# create_repo_with_branch: initial commit on main + feature branch with committed changes.
# Used to test tier detection via git diff BASE...HEAD (not working-tree fallback).
create_repo_with_branch() {
  local repo="$1" mode="${2:-standard}"
  git init -q -b main "$repo"
  (
    cd "$repo"
    git config user.email test@example.com
    git config user.name 'Gate Test'
    printf 'initial\n' > README.md
    git add README.md
    git commit -q -m initial
    git checkout -q -b feature
    case "$mode" in
      standard)
        # ~150 non-doc lines → standard tier (100 ≤ LINES < 500)
        for n in $(seq 1 150); do printf 'func Fn%s() {}\n' "$n"; done > app.go
        git add app.go
        git commit -q -m "add code"
        ;;
      full-lines)
        # ~600 non-doc lines → full tier (LINES > 500)
        for n in $(seq 1 600); do printf 'func Fn%s() {}\n' "$n"; done > app.go
        git add app.go
        git commit -q -m "add large code"
        ;;
      full-sensitive)
        # sensitive filename → full tier regardless of line count
        printf 'package main\n' > auth-handler.go
        git add auth-handler.go
        git commit -q -m "add auth handler"
        ;;
      *)
        printf 'unknown mode: %s\n' "$mode" >&2; exit 2 ;;
    esac
  )
}

run_gate() {
  local home="$1" runner="$2" repo="$3" out="$4" err="$5"
  shift 5
  set +e
  HOME="$home" "$runner/codex-pr-gate.sh" --cd "$repo" "$@" > "$out" 2> "$err"
  local code=$?
  return "$code"
}

test_tier_detection() {
  local name="tier-detection"
  local dir="$TMP_ROOT/$name"
  local home="$dir/home" repo="$dir/repo" runner="$dir/runner"
  local out="$dir/out" err="$dir/err" brief="$dir/brief.md"
  mkdir -p "$dir"
  create_runner "$runner"
  create_agents "$home" critic qa-tester architecture-reviewer security-reviewer risk-reviewer
  create_repo "$repo" docs

  set +e
  CODEX_GATE_CAPTURE_BRIEF="$brief" run_gate "$home" "$runner" "$repo" "$out" "$err" --base main
  local code=$?
  set -e
  if [[ "$code" -ne 0 ]]; then
    fail "$name" "exit $code, expected 0"
    return
  fi
  assert_contains "$name" "$out" "DISPATCH_STUB:success" || return
  assert_contains "$name" "$brief" "Tier: express" || return
  assert_contains "$name" "$brief" "Reviewers: critic,qa-tester" || return
  pass "$name"
}

test_missing_reviewer_agent() {
  local name="missing-reviewer-agent"
  local dir="$TMP_ROOT/$name"
  local home="$dir/home" repo="$dir/repo" runner="$dir/runner"
  local out="$dir/out" err="$dir/err"
  mkdir -p "$dir"
  create_runner "$runner"
  create_agents "$home" critic
  create_repo "$repo" docs

  set +e
  run_gate "$home" "$runner" "$repo" "$out" "$err" --base main
  local code=$?
  set -e
  if [[ "$code" -eq 0 ]]; then
    fail "$name" "expected non-zero exit"
    return
  fi
  assert_contains "$name" "$err" "Error: reviewer agent file not found:" || return
  assert_not_contains "$name" "$out" "DISPATCH_STUB" || return
  pass "$name"
}

test_invalid_base_ref() {
  local name="invalid-base-ref"
  local dir="$TMP_ROOT/$name"
  local home="$dir/home" repo="$dir/repo" runner="$dir/runner"
  local out="$dir/out" err="$dir/err"
  mkdir -p "$dir"
  create_runner "$runner"
  create_agents "$home" critic qa-tester architecture-reviewer security-reviewer risk-reviewer
  create_repo "$repo" docs

  set +e
  run_gate "$home" "$runner" "$repo" "$out" "$err" --base nonexistent-branch-12345
  local code=$?
  set -e
  if [[ "$code" -eq 0 ]]; then
    fail "$name" "expected non-zero exit"
    return
  fi
  assert_contains "$name" "$err" "Error: base ref not found: nonexistent-branch-12345" || return
  assert_not_contains "$name" "$out" "DISPATCH_STUB" || return
  pass "$name"
}

test_no_changed_files() {
  local name="no-changed-files"
  local dir="$TMP_ROOT/$name"
  local home="$dir/home" repo="$dir/repo" runner="$dir/runner"
  local out="$dir/out" err="$dir/err"
  mkdir -p "$dir"
  create_runner "$runner"
  create_agents "$home" critic qa-tester architecture-reviewer security-reviewer risk-reviewer
  create_repo "$repo" clean

  set +e
  run_gate "$home" "$runner" "$repo" "$out" "$err" --base main
  local code=$?
  set -e
  if [[ "$code" -eq 0 ]]; then
    fail "$name" "expected non-zero exit"
    return
  fi
  assert_contains "$name" "$err" "Error: no changed files detected against main" || return
  assert_not_contains "$name" "$out" "DISPATCH_STUB" || return
  pass "$name"
}

test_reviewers_override_skips_tier_detection() {
  local name="reviewers-override"
  local dir="$TMP_ROOT/$name"
  local home="$dir/home" repo="$dir/repo" runner="$dir/runner"
  local out="$dir/out" err="$dir/err" brief="$dir/brief.md"
  mkdir -p "$dir"
  create_runner "$runner"
  create_agents "$home" critic
  create_repo "$repo" many

  set +e
  CODEX_GATE_CAPTURE_BRIEF="$brief" run_gate "$home" "$runner" "$repo" "$out" "$err" --base main --reviewers critic
  local code=$?
  set -e
  if [[ "$code" -ne 0 ]]; then
    fail "$name" "exit $code, expected 0"
    return
  fi
  # Parallel mode: CAPTURE_BRIEF receives the synthesis brief (last dispatch)
  assert_contains "$name" "$brief" "Tier: targeted" || return
  assert_contains "$name" "$brief" "Reviewers: critic" || return
  # Synthesis brief references the reviewer output path (not the agent file)
  assert_contains "$name" "$brief" "reviewer-critic-" || return
  assert_not_contains "$name" "$brief" "read: $home/.claude/agents/qa-tester.md" || return
  pass "$name"
}

test_brief_file_inside_workdir() {
  local name="brief-file-inside-workdir"
  local dir="$TMP_ROOT/$name"
  local home="$dir/home" repo="$dir/repo" runner="$dir/runner"
  local out="$dir/out" err="$dir/err" marker="$dir/marker"
  mkdir -p "$dir"
  create_runner "$runner"
  create_agents "$home" critic qa-tester architecture-reviewer security-reviewer risk-reviewer
  create_repo "$repo" docs

  set +e
  CODEX_GATE_BRIEF_EXISTS_MARKER="$marker" run_gate "$home" "$runner" "$repo" "$out" "$err" --base main
  local code=$?
  set -e
  if [[ "$code" -ne 0 ]]; then
    fail "$name" "exit $code, expected 0"
    return
  fi
  assert_contains "$name" "$marker" "brief-present" || return
  pass "$name"
}

test_brief_cleanup_on_dispatch_failure() {
  local name="brief-cleanup-on-failure"
  local dir="$TMP_ROOT/$name"
  local home="$dir/home" repo="$dir/repo" runner="$dir/runner"
  local out="$dir/out" err="$dir/err"
  mkdir -p "$dir"
  create_runner "$runner"
  create_agents "$home" critic qa-tester architecture-reviewer security-reviewer risk-reviewer
  create_repo "$repo" docs

  set +e
  CODEX_GATE_STUB_MODE=fail run_gate "$home" "$runner" "$repo" "$out" "$err" --base main
  local code=$?
  set -e
  if [[ "$code" -eq 0 ]]; then
    fail "$name" "expected non-zero exit"
    return
  fi
  if compgen -G "$repo/.codex-briefs/pr-gate-*.md" > /dev/null; then
    fail "$name" "brief file remained after dispatch failure"
    return
  fi
  pass "$name"
}

test_output_directory_created() {
  local name="output-directory-created"
  local dir="$TMP_ROOT/$name"
  local home="$dir/home" repo="$dir/repo" runner="$dir/runner"
  local out="$dir/out" err="$dir/err" result="$dir/output/subdir/result.md"
  mkdir -p "$dir"
  create_runner "$runner"
  create_agents "$home" critic qa-tester architecture-reviewer security-reviewer risk-reviewer
  create_repo "$repo" docs

  set +e
  CODEX_GATE_STUB_MODE=fail run_gate "$home" "$runner" "$repo" "$out" "$err" --base main --output "$result"
  local code=$?
  set -e
  if [[ "$code" -eq 0 ]]; then
    fail "$name" "expected non-zero exit"
    return
  fi
  if [[ ! -d "$(dirname "$result")" ]]; then
    fail "$name" "output directory was not created"
    return
  fi
  pass "$name"
}

test_parallel_launches_per_reviewer() {
  # Verifies default parallel mode launches one dispatch per reviewer and a synthesis.
  local name="parallel-launches-per-reviewer"
  local dir="$TMP_ROOT/$name"
  local home="$dir/home" repo="$dir/repo" runner="$dir/runner"
  local out="$dir/out" err="$dir/err"
  mkdir -p "$dir"
  create_runner "$runner"
  create_agents "$home" critic qa-tester
  create_repo "$repo" docs

  set +e
  run_gate "$home" "$runner" "$repo" "$out" "$err" --base main --tier express
  local code=$?
  set -e
  if [[ "$code" -ne 0 ]]; then
    fail "$name" "exit $code, expected 0"
    return
  fi
  assert_contains "$name" "$out" "[parallel] launched critic" || return
  assert_contains "$name" "$out" "[parallel] launched qa-tester" || return
  assert_contains "$name" "$out" "[synthesis] running PM consolidation" || return
  pass "$name"
}

test_sequential_flag_produces_combined_brief() {
  # Verifies --sequential produces the combined reviewer brief with the
  # "Process each reviewer IN ORDER" instruction.
  local name="sequential-flag-combined-brief"
  local dir="$TMP_ROOT/$name"
  local home="$dir/home" repo="$dir/repo" runner="$dir/runner"
  local out="$dir/out" err="$dir/err" brief="$dir/brief.md"
  mkdir -p "$dir"
  create_runner "$runner"
  create_agents "$home" critic qa-tester architecture-reviewer security-reviewer risk-reviewer
  create_repo "$repo" docs

  set +e
  CODEX_GATE_CAPTURE_BRIEF="$brief" run_gate "$home" "$runner" "$repo" "$out" "$err" --base main --sequential
  local code=$?
  set -e
  if [[ "$code" -ne 0 ]]; then
    fail "$name" "exit $code, expected 0"
    return
  fi
  assert_contains "$name" "$brief" "Process each reviewer IN ORDER" || return
  assert_not_contains "$name" "$out" "[parallel]" || return
  assert_not_contains "$name" "$out" "[synthesis]" || return
  pass "$name"
}

test_failed_reviewer_aborts_gate() {
  # Verifies that when reviewer dispatches fail the gate exits non-zero and
  # prints an error — synthesis must not run on incomplete reviewer data.
  local name="failed-reviewer-aborts-gate"
  local dir="$TMP_ROOT/$name"
  local home="$dir/home" repo="$dir/repo" runner="$dir/runner"
  local out="$dir/out" err="$dir/err"
  mkdir -p "$dir"
  create_runner "$runner"
  create_agents "$home" critic qa-tester architecture-reviewer security-reviewer risk-reviewer
  create_repo "$repo" docs

  set +e
  CODEX_GATE_STUB_MODE=fail run_gate "$home" "$runner" "$repo" "$out" "$err" --base main
  local code=$?
  set -e
  if [[ "$code" -eq 0 ]]; then
    fail "$name" "expected non-zero exit when reviewers fail"
    return
  fi
  assert_contains "$name" "$err" "reviewer session(s) failed:" || return
  # Synthesis must not run after reviewer failure
  assert_not_contains "$name" "$out" "[synthesis]" || return
  pass "$name"
}

_make_go_repo_with_test() {
  # Helper: init a repo with app.go + app_test.go on main; feature branch changes app.go only.
  local repo="$1"
  git init -q -b main "$repo"
  (
    cd "$repo"
    git config user.email test@example.com
    git config user.name 'Gate Test'
    printf 'package main\nfunc Add(a, b int) int { return a + b }\n' > app.go
    printf 'package main\nimport "testing"\nfunc TestAdd(t *testing.T) {}\n' > app_test.go
    git add app.go app_test.go
    git commit -q -m initial
    git checkout -q -b feature
    printf 'package main\nfunc Add(a, b int) int { return a + b + 0 }\n' > app.go
    git add app.go
    git commit -q -m "change app.go only"
  )
}

_make_ts_repo_with_test() {
  # Helper: init a repo with src/format.ts + a test file; feature branch changes format.ts only.
  # Args: repo-path  test-path  test-content
  local repo="$1" test_path="$2" test_content="$3"
  git init -q -b main "$repo"
  (
    cd "$repo"
    git config user.email test@example.com
    git config user.name 'Gate Test'
    mkdir -p "$(dirname "$test_path")"
    printf 'export function fmt(s: string) { return s; }\n' > src/format.ts
    printf '%s\n' "$test_content" > "$test_path"
    git add src/format.ts "$test_path"
    git commit -q -m initial
    git checkout -q -b feature
    printf 'export function fmt(s: string) { return s.trim(); }\n' > src/format.ts
    git add src/format.ts
    git commit -q -m "change format.ts only"
  )
}

test_adjacent_go_test_included() {
  # Verifies that a *_test.go companion to a changed .go source file is
  # automatically included in the reviewer brief even when not in the diff.
  # Uses --sequential so CAPTURE_BRIEF holds the combined brief that lists all
  # review files, directly proving inclusion (not just the stdout counter).
  local name="adjacent-go-test-included"
  local dir="$TMP_ROOT/$name"
  local home="$dir/home" repo="$dir/repo" runner="$dir/runner"
  local out="$dir/out" err="$dir/err" brief="$dir/brief.md"
  mkdir -p "$dir"
  create_runner "$runner"
  create_agents "$home" critic qa-tester architecture-reviewer security-reviewer risk-reviewer
  _make_go_repo_with_test "$repo"

  set +e
  CODEX_GATE_CAPTURE_BRIEF="$brief" run_gate "$home" "$runner" "$repo" "$out" "$err" --base main --sequential
  local code=$?
  set -e
  if [[ "$code" -ne 0 ]]; then
    fail "$name" "exit $code, expected 0"
    return
  fi
  assert_contains "$name" "$out" "adjacent test files added: 1" || return
  assert_contains "$name" "$brief" "app_test.go" || return
  pass "$name"
}

test_adjacent_ts_test_in_tests_dir() {
  # Verifies that __tests__/<name>.test.ts adjacent to a changed .ts source
  # file is included in the reviewer brief.
  local name="adjacent-ts-test-tests-dir"
  local dir="$TMP_ROOT/$name"
  local home="$dir/home" repo="$dir/repo" runner="$dir/runner"
  local out="$dir/out" err="$dir/err" brief="$dir/brief.md"
  mkdir -p "$dir" "$dir/repo/src"
  create_runner "$runner"
  create_agents "$home" critic qa-tester architecture-reviewer security-reviewer risk-reviewer
  _make_ts_repo_with_test "$repo" "src/__tests__/format.test.ts" \
    "import { fmt } from '../format'; test('fmt', () => {});"

  set +e
  CODEX_GATE_CAPTURE_BRIEF="$brief" run_gate "$home" "$runner" "$repo" "$out" "$err" --base main --sequential
  local code=$?
  set -e
  if [[ "$code" -ne 0 ]]; then
    fail "$name" "exit $code, expected 0"
    return
  fi
  assert_contains "$name" "$out" "adjacent test files added: 1" || return
  assert_contains "$name" "$brief" "format.test.ts" || return
  pass "$name"
}

test_adjacent_ts_test_tsx_variant() {
  # Verifies that __tests__/<name>.test.tsx is recognised as an adjacent test.
  local name="adjacent-ts-test-tsx-variant"
  local dir="$TMP_ROOT/$name"
  local home="$dir/home" repo="$dir/repo" runner="$dir/runner"
  local out="$dir/out" err="$dir/err" brief="$dir/brief.md"
  mkdir -p "$dir"
  create_runner "$runner"
  create_agents "$home" critic qa-tester architecture-reviewer security-reviewer risk-reviewer
  _make_ts_repo_with_test "$repo" "src/__tests__/format.test.tsx" \
    "import { fmt } from '../format'; test('fmt', () => {});"

  set +e
  CODEX_GATE_CAPTURE_BRIEF="$brief" run_gate "$home" "$runner" "$repo" "$out" "$err" --base main --sequential
  local code=$?
  set -e
  if [[ "$code" -ne 0 ]]; then
    fail "$name" "exit $code, expected 0"
    return
  fi
  assert_contains "$name" "$out" "adjacent test files added: 1" || return
  assert_contains "$name" "$brief" "format.test.tsx" || return
  pass "$name"
}

test_adjacent_ts_spec_ts_variant() {
  # Verifies that __tests__/<name>.spec.ts is recognised as an adjacent test.
  local name="adjacent-ts-spec-ts-variant"
  local dir="$TMP_ROOT/$name"
  local home="$dir/home" repo="$dir/repo" runner="$dir/runner"
  local out="$dir/out" err="$dir/err" brief="$dir/brief.md"
  mkdir -p "$dir"
  create_runner "$runner"
  create_agents "$home" critic qa-tester architecture-reviewer security-reviewer risk-reviewer
  _make_ts_repo_with_test "$repo" "src/__tests__/format.spec.ts" \
    "import { fmt } from '../format'; test('fmt', () => {});"

  set +e
  CODEX_GATE_CAPTURE_BRIEF="$brief" run_gate "$home" "$runner" "$repo" "$out" "$err" --base main --sequential
  local code=$?
  set -e
  if [[ "$code" -ne 0 ]]; then
    fail "$name" "exit $code, expected 0"
    return
  fi
  assert_contains "$name" "$out" "adjacent test files added: 1" || return
  assert_contains "$name" "$brief" "format.spec.ts" || return
  pass "$name"
}

test_adjacent_ts_spec_tsx_variant() {
  # Verifies that a sibling <name>.spec.tsx file is recognised as an adjacent test.
  local name="adjacent-ts-spec-tsx-variant"
  local dir="$TMP_ROOT/$name"
  local home="$dir/home" repo="$dir/repo" runner="$dir/runner"
  local out="$dir/out" err="$dir/err" brief="$dir/brief.md"
  mkdir -p "$dir"
  create_runner "$runner"
  create_agents "$home" critic qa-tester architecture-reviewer security-reviewer risk-reviewer
  _make_ts_repo_with_test "$repo" "src/format.spec.tsx" \
    "import { fmt } from './format'; test('fmt', () => {});"

  set +e
  CODEX_GATE_CAPTURE_BRIEF="$brief" run_gate "$home" "$runner" "$repo" "$out" "$err" --base main --sequential
  local code=$?
  set -e
  if [[ "$code" -ne 0 ]]; then
    fail "$name" "exit $code, expected 0"
    return
  fi
  assert_contains "$name" "$out" "adjacent test files added: 1" || return
  assert_contains "$name" "$brief" "format.spec.tsx" || return
  pass "$name"
}

test_adjacent_ts_sibling_test() {
  # Verifies that a sibling <name>.test.ts file (not in __tests__/) is
  # included in the reviewer brief.
  local name="adjacent-ts-sibling-test"
  local dir="$TMP_ROOT/$name"
  local home="$dir/home" repo="$dir/repo" runner="$dir/runner"
  local out="$dir/out" err="$dir/err" brief="$dir/brief.md"
  mkdir -p "$dir"
  create_runner "$runner"
  create_agents "$home" critic qa-tester architecture-reviewer security-reviewer risk-reviewer
  _make_ts_repo_with_test "$repo" "src/format.test.ts" \
    "import { fmt } from './format'; test('fmt', () => {});"

  set +e
  CODEX_GATE_CAPTURE_BRIEF="$brief" run_gate "$home" "$runner" "$repo" "$out" "$err" --base main --sequential
  local code=$?
  set -e
  if [[ "$code" -ne 0 ]]; then
    fail "$name" "exit $code, expected 0"
    return
  fi
  assert_contains "$name" "$out" "adjacent test files added: 1" || return
  assert_contains "$name" "$brief" "format.test.ts" || return
  pass "$name"
}

test_adjacent_test_not_duplicated_when_in_diff() {
  # Verifies that a test file already in the diff is not re-appended as an
  # adjacent file (de-duplication).
  local name="adjacent-test-not-duplicated"
  local dir="$TMP_ROOT/$name"
  local home="$dir/home" repo="$dir/repo" runner="$dir/runner"
  local out="$dir/out" err="$dir/err"
  mkdir -p "$dir"
  create_runner "$runner"
  create_agents "$home" critic qa-tester architecture-reviewer security-reviewer risk-reviewer
  git init -q -b main "$repo"
  (
    cd "$repo"
    git config user.email test@example.com
    git config user.name 'Gate Test'
    printf 'package main\nfunc Add(a, b int) int { return a + b }\n' > app.go
    printf 'package main\nimport "testing"\nfunc TestAdd(t *testing.T) {}\n' > app_test.go
    git add app.go app_test.go
    git commit -q -m initial
    git checkout -q -b feature
    printf 'package main\nfunc Add(a, b int) int { return a + b + 0 }\n' > app.go
    printf 'package main\nimport "testing"\nfunc TestAdd(t *testing.T) {}\nfunc TestSub(t *testing.T) {}\n' > app_test.go
    git add app.go app_test.go
    git commit -q -m "change both app.go and app_test.go"
  )

  set +e
  run_gate "$home" "$runner" "$repo" "$out" "$err" --base main
  local code=$?
  set -e
  if [[ "$code" -ne 0 ]]; then
    fail "$name" "exit $code, expected 0"
    return
  fi
  assert_not_contains "$name" "$out" "adjacent test files added:" || return
  pass "$name"
}

test_synthesis_no_output_aborts_gate() {
  # Verifies that PM synthesis exiting 0 without writing the gate result file
  # fails the gate — reviewers succeed but synthesis silently omits its output.
  # Steps:
  #   1. Create a minimal repo (express tier, docs change)
  #   2. CODEX_GATE_STUB_SYNTHESIS_MODE=no-output: reviewers write output; synthesis does not
  #   3. Run gate in parallel mode (default)
  #   4. Assert non-zero exit and "synthesis did not produce" in stderr
  local name="synthesis-no-output-aborts-gate"
  local dir="$TMP_ROOT/$name"
  local home="$dir/home" repo="$dir/repo" runner="$dir/runner"
  local out="$dir/out" err="$dir/err"
  mkdir -p "$dir"
  create_runner "$runner"
  create_agents "$home" critic qa-tester architecture-reviewer security-reviewer risk-reviewer
  create_repo "$repo" docs

  set +e
  CODEX_GATE_STUB_SYNTHESIS_MODE=no-output run_gate "$home" "$runner" "$repo" "$out" "$err" --base main
  local code=$?
  set -e
  if [[ "$code" -eq 0 ]]; then
    fail "$name" "expected non-zero exit when synthesis produces no output"
    return
  fi
  assert_contains "$name" "$err" "synthesis did not produce" || return
  pass "$name"
}

test_reviewer_invalid_verdict_aborts_gate() {
  # Verifies that a reviewer output file without a valid Verdict line fails
  # the gate before synthesis (guards against malformed or manipulated output).
  # Steps:
  #   1. Create a minimal repo (express tier, docs change)
  #   2. CODEX_GATE_STUB_MODE=no-verdict: reviewer writes output but no Verdict line
  #   3. Run gate in parallel mode (default)
  #   4. Assert non-zero exit and "missing valid Verdict line" in stderr
  local name="reviewer-invalid-verdict-aborts-gate"
  local dir="$TMP_ROOT/$name"
  local home="$dir/home" repo="$dir/repo" runner="$dir/runner"
  local out="$dir/out" err="$dir/err"
  mkdir -p "$dir"
  create_runner "$runner"
  create_agents "$home" critic qa-tester architecture-reviewer security-reviewer risk-reviewer
  create_repo "$repo" docs

  set +e
  CODEX_GATE_STUB_MODE=no-verdict run_gate "$home" "$runner" "$repo" "$out" "$err" --base main
  local code=$?
  set -e
  if [[ "$code" -eq 0 ]]; then
    fail "$name" "expected non-zero exit when reviewer output has no valid Verdict line"
    return
  fi
  assert_contains "$name" "$err" "missing valid Verdict line" || return
  pass "$name"
}

test_reviewer_no_output_aborts_gate() {
  # Verifies that a reviewer session exiting 0 without writing its output file
  # fails the gate (fail-closed on silent reviewer failure).
  # Steps:
  #   1. Create a minimal repo (express tier, docs change)
  #   2. CODEX_GATE_STUB_MODE=no-output: all dispatches (reviewers + synthesis) omit output
  #   3. Run gate in parallel mode (default)
  #   4. Assert non-zero exit and "reviewer output missing or empty" in stderr
  local name="reviewer-no-output-aborts-gate"
  local dir="$TMP_ROOT/$name"
  local home="$dir/home" repo="$dir/repo" runner="$dir/runner"
  local out="$dir/out" err="$dir/err"
  mkdir -p "$dir"
  create_runner "$runner"
  create_agents "$home" critic qa-tester architecture-reviewer security-reviewer risk-reviewer
  create_repo "$repo" docs

  set +e
  CODEX_GATE_STUB_MODE=no-output run_gate "$home" "$runner" "$repo" "$out" "$err" --base main
  local code=$?
  set -e
  if [[ "$code" -eq 0 ]]; then
    fail "$name" "expected non-zero exit when reviewer produces no output"
    return
  fi
  assert_contains "$name" "$err" "reviewer output missing or empty" || return
  pass "$name"
}

test_prompt_injection_detected() {
  # Verifies that a reviewer session modifying a tracked source file (simulated
  # prompt injection) causes the gate to abort before synthesis.
  # Steps:
  #   1. Create a repo with a committed service.go (clean tracked file)
  #   2. CODEX_GATE_STUB_INJECT_FILE=service.go: reviewer stub appends to service.go
  #   3. Run gate in parallel mode (default)
  #   4. Assert non-zero exit, "prompt injection" in stderr, and no "[synthesis]" in stdout
  local name="prompt-injection-detected"
  local dir="$TMP_ROOT/$name"
  local home="$dir/home" repo="$dir/repo" runner="$dir/runner"
  local out="$dir/out" err="$dir/err"
  mkdir -p "$dir"
  create_runner "$runner"
  create_agents "$home" critic qa-tester architecture-reviewer security-reviewer risk-reviewer
  create_repo "$repo" docs
  # Add a committed tracked source file the stub can modify
  printf 'package main\n' > "$repo/service.go"
  git -C "$repo" add service.go
  git -C "$repo" commit -q -m "add service.go"

  set +e
  CODEX_GATE_STUB_INJECT_FILE="$repo/service.go" run_gate \
    "$home" "$runner" "$repo" "$out" "$err" --base main
  local code=$?
  set -e
  if [[ "$code" -eq 0 ]]; then
    fail "$name" "expected non-zero exit when reviewer modifies tracked file"
    return
  fi
  assert_contains "$name" "$err" "prompt injection" || return
  assert_not_contains "$name" "$out" "[synthesis]" || return
  pass "$name"
}

run_test() {
  "$@" || true
}

test_standard_tier_detection() {
  # Verifies 100-500 non-doc lines on a feature branch triggers standard tier.
  local name="standard-tier-detection"
  local dir="$TMP_ROOT/$name"
  local home="$dir/home" repo="$dir/repo" runner="$dir/runner"
  local out="$dir/out" err="$dir/err" brief="$dir/brief.md"
  mkdir -p "$dir"
  create_runner "$runner"
  create_agents "$home" critic qa-tester architecture-reviewer security-reviewer risk-reviewer
  create_repo_with_branch "$repo" standard

  set +e
  CODEX_GATE_CAPTURE_BRIEF="$brief" run_gate "$home" "$runner" "$repo" "$out" "$err" --base main
  local code=$?
  set -e
  if [[ "$code" -ne 0 ]]; then
    fail "$name" "exit $code, expected 0"
    return
  fi
  assert_contains "$name" "$brief" "Tier: standard" || return
  assert_contains "$name" "$brief" "Reviewers: critic,qa-tester,architecture-reviewer" || return
  pass "$name"
}

test_full_tier_line_count() {
  # Verifies >500 non-doc lines on a feature branch triggers full tier.
  local name="full-tier-line-count"
  local dir="$TMP_ROOT/$name"
  local home="$dir/home" repo="$dir/repo" runner="$dir/runner"
  local out="$dir/out" err="$dir/err" brief="$dir/brief.md"
  mkdir -p "$dir"
  create_runner "$runner"
  create_agents "$home" critic qa-tester architecture-reviewer security-reviewer risk-reviewer
  create_repo_with_branch "$repo" full-lines

  set +e
  CODEX_GATE_CAPTURE_BRIEF="$brief" run_gate "$home" "$runner" "$repo" "$out" "$err" --base main
  local code=$?
  set -e
  if [[ "$code" -ne 0 ]]; then
    fail "$name" "exit $code, expected 0"
    return
  fi
  assert_contains "$name" "$brief" "Tier: full" || return
  pass "$name"
}

test_full_tier_sensitive_file() {
  # Verifies a sensitive filename (auth-*) triggers full tier regardless of line count.
  local name="full-tier-sensitive-file"
  local dir="$TMP_ROOT/$name"
  local home="$dir/home" repo="$dir/repo" runner="$dir/runner"
  local out="$dir/out" err="$dir/err" brief="$dir/brief.md"
  mkdir -p "$dir"
  create_runner "$runner"
  create_agents "$home" critic qa-tester architecture-reviewer security-reviewer risk-reviewer
  create_repo_with_branch "$repo" full-sensitive

  set +e
  CODEX_GATE_CAPTURE_BRIEF="$brief" run_gate "$home" "$runner" "$repo" "$out" "$err" --base main
  local code=$?
  set -e
  if [[ "$code" -ne 0 ]]; then
    fail "$name" "exit $code, expected 0"
    return
  fi
  assert_contains "$name" "$brief" "Tier: full" || return
  pass "$name"
}

test_via_symlink() {
  # Verifies readlink -f fix: gate dispatches correctly when run as a symlink.
  local name="via-symlink"
  local dir="$TMP_ROOT/$name"
  local home="$dir/home" repo="$dir/repo" runner="$dir/runner" symdir="$dir/symdir"
  local out="$dir/out" err="$dir/err"
  mkdir -p "$dir" "$symdir"
  create_runner "$runner"
  create_agents "$home" critic qa-tester architecture-reviewer security-reviewer risk-reviewer
  create_repo "$repo" docs

  # Simulate ~/.claude/scripts/codex-pr-gate.sh → real script in runner dir
  ln -s "$runner/codex-pr-gate.sh" "$symdir/codex-pr-gate.sh"

  set +e
  HOME="$home" "$symdir/codex-pr-gate.sh" --cd "$repo" --base main > "$out" 2> "$err"
  local code=$?
  set -e
  if [[ "$code" -ne 0 ]]; then
    fail "$name" "exit $code — readlink -f fix may be broken"
    return
  fi
  assert_contains "$name" "$out" "DISPATCH_STUB:success" || return
  pass "$name"
}

test_rename_sensitive_old_name() {
  # Verifies that renaming auth.ts → login.ts still triggers full tier on the old name.
  local name="rename-sensitive-old-name"
  local dir="$TMP_ROOT/$name"
  local home="$dir/home" repo="$dir/repo" runner="$dir/runner"
  local out="$dir/out" err="$dir/err" brief="$dir/brief.md"
  mkdir -p "$dir"
  create_runner "$runner"
  create_agents "$home" critic qa-tester architecture-reviewer security-reviewer risk-reviewer
  git init -q -b main "$repo"
  (
    cd "$repo"
    git config user.email test@example.com
    git config user.name 'Gate Test'
    printf 'package auth\n' > auth.ts
    git add auth.ts
    git commit -q -m initial
    git checkout -q -b feature
    git mv auth.ts login.ts
    git commit -q -m "rename auth.ts to login.ts"
  )

  set +e
  CODEX_GATE_CAPTURE_BRIEF="$brief" run_gate "$home" "$runner" "$repo" "$out" "$err" --base main
  local code=$?
  set -e
  if [[ "$code" -ne 0 ]]; then
    fail "$name" "exit $code, expected 0"
    return
  fi
  assert_contains "$name" "$brief" "Tier: full" || return
  pass "$name"
}

test_binary_file_routes_to_standard() {
  # Verifies that a binary file change is not silently routed to express tier.
  local name="binary-file-routes-to-standard"
  local dir="$TMP_ROOT/$name"
  local home="$dir/home" repo="$dir/repo" runner="$dir/runner"
  local out="$dir/out" err="$dir/err" brief="$dir/brief.md"
  mkdir -p "$dir"
  create_runner "$runner"
  create_agents "$home" critic qa-tester architecture-reviewer security-reviewer risk-reviewer
  git init -q -b main "$repo"
  (
    cd "$repo"
    git config user.email test@example.com
    git config user.name 'Gate Test'
    printf 'initial\n' > README.md
    git add README.md
    git commit -q -m initial
    git checkout -q -b feature
    # Create a binary file (null bytes trigger git binary detection)
    printf '\x00\x01\x02\x03' > image.png
    git add image.png
    git commit -q -m "add binary asset"
  )

  set +e
  CODEX_GATE_CAPTURE_BRIEF="$brief" run_gate "$home" "$runner" "$repo" "$out" "$err" --base main
  local code=$?
  set -e
  if [[ "$code" -ne 0 ]]; then
    fail "$name" "exit $code, expected 0"
    return
  fi
  # Binary files must route to standard (not express, not over-routed to full)
  if ! grep -qF "Tier: standard" "$brief" 2>/dev/null; then
    fail "$name" "binary file did not route to standard tier (brief: $(cat "$brief" 2>/dev/null | grep Tier || echo 'no Tier line'))"
    return
  fi
  pass "$name"
}

test_untracked_binary_routes_to_standard() {
  # Verifies that an untracked binary in the working tree (no branch commits)
  # is not silently routed to express tier. The working-tree fallback must treat
  # untracked non-doc files as having unknown size.
  local name="untracked-binary-routes-to-standard"
  local dir="$TMP_ROOT/$name"
  local home="$dir/home" repo="$dir/repo" runner="$dir/runner"
  local out="$dir/out" err="$dir/err" brief="$dir/brief.md"
  mkdir -p "$dir"
  create_runner "$runner"
  create_agents "$home" critic qa-tester architecture-reviewer security-reviewer risk-reviewer
  git init -q -b main "$repo"
  (
    cd "$repo"
    git config user.email test@example.com
    git config user.name 'Gate Test'
    printf 'initial\n' > README.md
    git add README.md
    git commit -q -m initial
    # Add an untracked binary file to the working tree (no commit, no staging)
    printf '\x00\x01\x02\x03' > image.png
  )

  set +e
  CODEX_GATE_CAPTURE_BRIEF="$brief" run_gate "$home" "$runner" "$repo" "$out" "$err"
  local code=$?
  set -e
  if [[ "$code" -ne 0 ]]; then
    fail "$name" "exit $code, expected 0"
    return
  fi
  # Untracked binary must not silently route to express
  if grep -qF "Tier: express" "$brief" 2>/dev/null; then
    fail "$name" "untracked binary incorrectly routed to express tier"
    return
  fi
  pass "$name"
}

run_test test_tier_detection
run_test test_missing_reviewer_agent
run_test test_invalid_base_ref
run_test test_no_changed_files
run_test test_reviewers_override_skips_tier_detection
run_test test_brief_file_inside_workdir
run_test test_brief_cleanup_on_dispatch_failure
run_test test_output_directory_created
run_test test_standard_tier_detection
run_test test_full_tier_line_count
run_test test_full_tier_sensitive_file
run_test test_via_symlink
run_test test_rename_sensitive_old_name
run_test test_binary_file_routes_to_standard
run_test test_untracked_binary_routes_to_standard
run_test test_parallel_launches_per_reviewer
run_test test_sequential_flag_produces_combined_brief
run_test test_failed_reviewer_aborts_gate
run_test test_synthesis_no_output_aborts_gate
run_test test_reviewer_invalid_verdict_aborts_gate
run_test test_reviewer_no_output_aborts_gate
run_test test_prompt_injection_detected
run_test test_adjacent_go_test_included
run_test test_adjacent_ts_test_in_tests_dir
run_test test_adjacent_ts_test_tsx_variant
run_test test_adjacent_ts_spec_ts_variant
run_test test_adjacent_ts_spec_tsx_variant
run_test test_adjacent_ts_sibling_test
run_test test_adjacent_test_not_duplicated_when_in_diff

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
if [[ "$FAIL" -gt 0 ]]; then
  printf 'failed cases: %s\n' "${FAILED_CASES[*]}" >&2
  exit 1
fi
