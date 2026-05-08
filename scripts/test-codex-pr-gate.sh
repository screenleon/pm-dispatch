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

case "${CODEX_GATE_STUB_MODE:-success}" in
  fail) exit 1;;
  *) exit 0;;
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
      code)
        printf 'package main\n\nfunc main() {}\n' > main.go
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
  assert_contains "$name" "$brief" "Tier: targeted" || return
  assert_contains "$name" "$brief" "Reviewers: critic" || return
  assert_contains "$name" "$brief" "Process each reviewer IN ORDER: critic" || return
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

run_test() {
  "$@" || true
}

run_test test_tier_detection
run_test test_missing_reviewer_agent
run_test test_invalid_base_ref
run_test test_no_changed_files
run_test test_reviewers_override_skips_tier_detection
run_test test_brief_file_inside_workdir
run_test test_brief_cleanup_on_dispatch_failure
run_test test_output_directory_created

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
if [[ "$FAIL" -gt 0 ]]; then
  printf 'failed cases: %s\n' "${FAILED_CASES[*]}" >&2
  exit 1
fi
