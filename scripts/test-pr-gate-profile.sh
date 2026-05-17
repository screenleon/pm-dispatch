#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ORIGINAL_PATH="$PATH"

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

extract_result_path() {
  awk -F'result: ' '/^result: /{path=$2} END{print path}' "$1"
}

extract_handover_block() {
  local out="$1"
  awk '
    /^```pr-gate-handover_v1$/ {in_block=1; next}
    in_block && /^```$/ {in_block=0; exit}
    in_block {print}
  ' "$out"
}

assert_fence_shape() {
  local name="$1" file="$2"
  local open_line close_line
  open_line=$(awk '/^```pr-gate-handover_v1$/ {print NR; exit}' "$file" || true)
  if [[ -z "$open_line" ]]; then
    fail "$name" "missing opening fence"
    return 1
  fi
  close_line=$(awk -v open="$open_line" 'NR>open && $0 == "```" {print NR; exit}' "$file" || true)
  if [[ -z "$close_line" ]]; then
    fail "$name" "missing closing fence"
    return 1
  fi
  if (( close_line <= open_line )); then
    fail "$name" "closing fence before opening"
    return 1
  fi
}

create_runner() {
  local dir="$1"
  mkdir -p "$dir"
  cp "$REPO_ROOT/scripts/pr-gate.sh" "$dir/pr-gate.sh"
  chmod +x "$dir/pr-gate.sh"
  local cmd
  for cmd in bash git date readlink dirname basename cp mkdir ln cat grep sort wc awk sed mktemp rm head tail tr true false sha256sum shasum; do
    src="$(command -v "$cmd" 2>/dev/null || true)"
    if [[ -n "$src" ]]; then
      ln -sf "$src" "$dir/$cmd"
    fi
  done

  mkdir -p "$dir/.claude"
  cat > "$dir/codex-dispatch.sh" <<'STUB_EOF'
#!/usr/bin/env bash
set -euo pipefail

brief_file=""
MODE="${CODEX_GATE_STUB_MODE:-success}"
MARKER="${CODEX_GATE_STUB_CALLED_MARKER:-}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --brief-file) brief_file="$2"; shift 2 ;;
    --cd|--timeout) shift 2 ;;
    *) shift ;;
  esac
  :
done

[[ -n "$MARKER" ]] && printf 'called\n' > "$MARKER"
printf 'DISPATCH_STUB:%s\n' "$MODE"

if [[ "$MODE" == "exit99" ]]; then
  exit 99
fi

if [[ -z "$brief_file" ]]; then
  exit 0
fi

output_path=""
if [[ -f "$brief_file" ]]; then
output_path=$(grep -o '\- new:.*' "$brief_file" | head -1 | awk '{print $NF}' || true)
fi

if [[ -n "$output_path" ]]; then
  mkdir -p "$(dirname "$output_path")"
  if [[ "$brief_file" == *-synthesis.md ]]; then
    printf '# PR-Gate Result — stub tier\n**Date**: 2026-05-17\n**Reviewers**: stub\n**Not reviewed**: none\n\n## cross-check\nnone\n\n## Gate Conclusion\n**Overall verdict**: advise\n**Most severe individual verdict**: advise\nFinal: GO\n' > "$output_path"
  else
    printf '## stub-reviewer — advise\nVerdict: advise. Stub output.\nFinal: GO\n' > "$output_path"
  fi
fi

exit 0
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
  local repo="$1"
  git init -q -b main "$repo"
  (
    cd "$repo"
    git config user.email test@example.com
    git config user.name 'Gate Test'
    printf 'initial\n' > README.md
    printf '.agent-trace/\n.codex-briefs/\n.gate-results/\n' > .gitignore
    git add README.md .gitignore
    git commit -q -m initial

    cat > app.go <<'EOF_FILE'
package main

func main() {}
EOF_FILE
  )
}

build_no_codex_path() {
  local dir="$1/no-codex-bin"
  mkdir -p "$dir"
  local cmd
  for cmd in bash git date readlink dirname basename cp mkdir ln cat grep sort wc awk sed mktemp rm cat sort head tail tr wc awk date sha256sum shasum git; do
    src="$(command -v "$cmd" 2>/dev/null || true)"
    if [[ -n "$src" ]]; then
      ln -sf "$src" "$dir/$cmd"
    fi
  done
  printf '%s' "$dir"
}

run_gate() {
  local home="$1" runner="$2" repo="$3" out="$4" err="$5" path_override="$6"
  shift 6
  set +e
  HOME="$home" PATH="$path_override" "$runner/pr-gate.sh" --cd "$repo" "$@" > "$out" 2> "$err"
  local code=$?
  set -e
  return "$code"
}

test_executor_codex_flag_explicit_keeps_behavior() {
  local name="executor-codex-flag-explicit-keeps-behavior"
  local dir="$TMP_ROOT/$name"
  local home="$dir/home" repo="$dir/repo" runner="$dir/runner"
  local out="$dir/out" err="$dir/err"

  mkdir -p "$dir"
  create_runner "$runner"
  create_agents "$home" critic qa-tester architecture-reviewer security-reviewer risk-reviewer
  create_repo "$repo"

  set +e
  run_gate "$home" "$runner" "$repo" "$out" "$err" "$runner" --executor codex --base main
  local code=$?
  set -e
  if [[ "$code" -ne 0 ]]; then
    fail "$name" "exit $code, expected 0"
    return
  fi
  assert_contains "$name" "$out" "DISPATCH_STUB:success" || return
  assert_not_contains "$name" "$out" '```pr-gate-handover_v1' || return
  local result
  result=$(extract_result_path "$out")
  if [[ -z "$result" || ! -s "$result" ]]; then
    fail "$name" "result file not produced or not found"
    return
  fi
  pass "$name"
}

test_executor_claude_sequential_emits_single_brief_handover() {
  local name="executor-claude-sequential-emits-single-brief-handover"
  local dir="$TMP_ROOT/$name"
  local home="$dir/home" repo="$dir/repo" runner="$dir/runner"
  local out="$dir/out" err="$dir/err"
  local handover reviewers synthesis result
  mkdir -p "$dir"

  create_runner "$runner"
  create_agents "$home" critic qa-tester architecture-reviewer security-reviewer risk-reviewer
  create_repo "$repo"

  set +e
  run_gate "$home" "$runner" "$repo" "$out" "$err" "$runner" --executor claude --base main
  local code=$?
  set -e
  if [[ "$code" -ne 0 ]]; then
    fail "$name" "exit $code, expected 0"
    return
  fi
  assert_not_contains "$name" "$out" "DISPATCH_STUB" || return
  assert_contains "$name" "$out" '```pr-gate-handover_v1' || return
  assert_contains "$name" "$out" "reviewer_name: combined" || return
  assert_contains "$name" "$out" "-claude-" || return
  assert_contains "$name" "$out" "-combined.md" || return

  handover=$(extract_handover_block "$out")
  reviewers=$(printf '%s' "$handover" | grep -c '^- role: reviewer$')
  synthesis=$(printf '%s' "$handover" | grep -c '^- role: synthesis$')
  if [[ "$reviewers" -ne 1 ]]; then
    fail "$name" "expected 1 reviewer entry, got $reviewers"
    return
  fi
  if [[ "$synthesis" -ne 0 ]]; then
    fail "$name" "did not expect synthesis entry in sequential mode"
    return
  fi

  result=$(extract_result_path "$out")
  if [[ -z "$result" ]]; then
    fail "$name" "missing result path footer"
    return
  fi
  pass "$name"
}

test_executor_claude_parallel_emits_multi_brief_handover() {
  local name="executor-claude-parallel-emits-multi-brief-handover"
  local dir="$TMP_ROOT/$name"
  local home="$dir/home" repo="$dir/repo" runner="$dir/runner"
  local out="$dir/out" err="$dir/err"
  local handover reviewers synthesis
  mkdir -p "$dir"

  create_runner "$runner"
  create_agents "$home" critic qa-tester architecture-reviewer security-reviewer risk-reviewer
  create_repo "$repo"

  set +e
  run_gate "$home" "$runner" "$repo" "$out" "$err" "$runner" --executor claude --reviewers critic,qa-tester --parallel --base main
  local code=$?
  set -e
  if [[ "$code" -ne 0 ]]; then
    fail "$name" "exit $code, expected 0"
    return
  fi

  handover=$(extract_handover_block "$out")
  reviewers=$(printf '%s' "$handover" | grep -c '^- role: reviewer$')
  synthesis=$(printf '%s' "$handover" | grep -c '^- role: synthesis$')
  if [[ "$reviewers" -ne 2 ]]; then
    fail "$name" "expected 2 reviewer entries, got $reviewers"
    return
  fi
  if [[ "$synthesis" -ne 1 ]]; then
    fail "$name" "expected 1 synthesis entry, got $synthesis"
    return
  fi
  assert_contains "$name" "$out" "reviewer_name: critic" || return
  assert_contains "$name" "$out" "reviewer_name: qa-tester" || return
  pass "$name"
}

test_executor_auto_with_codex() {
  local name="executor-auto-with-codex"
  local dir="$TMP_ROOT/$name"
  local home="$dir/home" repo="$dir/repo" runner="$dir/runner" codex_bin="$dir/codex-bin"
  local out="$dir/out" err="$dir/err"

  mkdir -p "$dir" "$codex_bin"
  cat > "$codex_bin/codex" <<'EOF_CODEx'
#!/usr/bin/env bash
echo fake codex
EOF_CODEx
  chmod +x "$codex_bin/codex"

  create_runner "$runner"
  create_agents "$home" critic qa-tester architecture-reviewer security-reviewer risk-reviewer
  create_repo "$repo"

  set +e
  run_gate "$home" "$runner" "$repo" "$out" "$err" "$runner:$codex_bin" --executor auto --base main
  local code=$?
  set -e
  if [[ "$code" -ne 0 ]]; then
    fail "$name" "exit $code, expected 0"
    return
  fi
  assert_contains "$name" "$out" "DISPATCH_STUB:success" || return
  assert_not_contains "$name" "$out" '```pr-gate-handover_v1' || return
  pass "$name"
}

test_executor_auto_without_codex() {
  local name="executor-auto-without-codex"
  local dir="$TMP_ROOT/$name"
  local home="$dir/home" repo="$dir/repo" runner="$dir/runner"
  local out="$dir/out" err="$dir/err"
  local no_codex_path
  mkdir -p "$dir"

  create_runner "$runner"
  create_agents "$home" critic qa-tester architecture-reviewer security-reviewer risk-reviewer
  create_repo "$repo"
  no_codex_path="$(build_no_codex_path "$home")"

  set +e
  run_gate "$home" "$runner" "$repo" "$out" "$err" "$no_codex_path" --executor auto --base main
  local code=$?
  set -e
  if [[ "$code" -ne 0 ]]; then
    fail "$name" "exit $code, expected 0"
    return
  fi
  assert_contains "$name" "$out" '```pr-gate-handover_v1' || return
  assert_not_contains "$name" "$out" "DISPATCH_STUB" || return
  pass "$name"
}

test_executor_invalid_value_rejected() {
  local name="executor-invalid-value-rejected"
  local dir="$TMP_ROOT/$name"
  local home="$dir/home" repo="$dir/repo" runner="$dir/runner"
  local out="$dir/out" err="$dir/err"
  mkdir -p "$dir"

  create_runner "$runner"
  create_agents "$home" critic qa-tester architecture-reviewer security-reviewer risk-reviewer
  create_repo "$repo"

  set +e
  run_gate "$home" "$runner" "$repo" "$out" "$err" "$runner" --executor invalid
  local code=$?
  set -e
  if [[ "$code" -eq 0 ]]; then
    fail "$name" "expected non-zero exit"
    return
  fi
  assert_contains "$name" "$err" "Error: --executor must be one of: codex | claude | auto" || return
  pass "$name"
}

test_executor_claude_never_calls_codex() {
  local name="executor-claude-never-calls-codex"
  local dir="$TMP_ROOT/$name"
  local home="$dir/home" repo="$dir/repo" runner="$dir/runner"
  local out="$dir/out" err="$dir/err" marker="$dir/codex-called"
  mkdir -p "$dir"

  create_runner "$runner"
  create_agents "$home" critic qa-tester architecture-reviewer security-reviewer risk-reviewer
  create_repo "$repo"

  cat > "$runner/codex-dispatch.sh" <<'STUB_EOF'
#!/usr/bin/env bash
set -euo pipefail
marker="${CODEX_GATE_STUB_CALLED_MARKER:-}"
[[ -n "$marker" ]] && printf 'called\n' > "$marker"
exit 99
STUB_EOF
  chmod +x "$runner/codex-dispatch.sh"

  set +e
  CODEX_GATE_STUB_CALLED_MARKER="$marker" run_gate "$home" "$runner" "$repo" "$out" "$err" "$runner" --executor claude --base main
  local code=$?
  set -e
  if [[ "$code" -ne 0 ]]; then
    fail "$name" "exit $code, expected 0"
    return
  fi
  if [[ -f "$marker" ]]; then
    fail "$name" "codex-dispatch was called in claude mode"
    return
  fi
  assert_contains "$name" "$out" '```pr-gate-handover_v1' || return
  pass "$name"
}

test_pr_gate_handover_fence_shape() {
  local name="pr-gate-handover-fence-shape"
  local dir="$TMP_ROOT/$name"
  local home="$dir/home" repo="$dir/repo" runner="$dir/runner"
  local out="$dir/out" err="$dir/err"
  mkdir -p "$dir"

  create_runner "$runner"
  create_agents "$home" critic qa-tester architecture-reviewer security-reviewer risk-reviewer
  create_repo "$repo"

  set +e
  run_gate "$home" "$runner" "$repo" "$out" "$err" "$runner" --executor claude --base main
  local code=$?
  set -e
  if [[ "$code" -ne 0 ]]; then
    fail "$name" "exit $code, expected 0"
    return
  fi
  assert_fence_shape "$name" "$out" || return
  pass "$name"
}

test_commands_pr_gate_md_has_both_routes() {
  local name="commands-pr-gate-md-has-both-routes"
  local target="$REPO_ROOT/commands/pr-gate.md"
  assert_contains "$name" "$target" "## Route A" || return
  assert_contains "$name" "$target" "## Route B" || return
  assert_contains "$name" "$target" 'pr-gate-handover_v1' || return
  pass "$name"
}

run_case() {
  local name="$1" fn="$2"
  if "$fn"; then
    :
  else
    fail "$name" "case function returned non-zero"
  fi
}

run_case "executor-codex-flag-explicit-keeps-behavior" test_executor_codex_flag_explicit_keeps_behavior
run_case "executor-claude-sequential-emits-single-brief-handover" test_executor_claude_sequential_emits_single_brief_handover
run_case "executor-claude-parallel-emits-multi-brief-handover" test_executor_claude_parallel_emits_multi_brief_handover
run_case "executor-auto-with-codex" test_executor_auto_with_codex
run_case "executor-auto-without-codex" test_executor_auto_without_codex
run_case "executor-claude-never-calls-codex" test_executor_claude_never_calls_codex
run_case "executor-invalid-value-rejected" test_executor_invalid_value_rejected
run_case "pr-gate-handover-fence-shape" test_pr_gate_handover_fence_shape
run_case "commands-pr-gate-md-has-both-routes" test_commands_pr_gate_md_has_both_routes

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
if [[ "$FAIL" -gt 0 ]]; then
  printf 'failed cases: %s\n' "${FAILED_CASES[*]}" >&2
  exit 1
fi
