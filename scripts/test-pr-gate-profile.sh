#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ORIGINAL_PATH="$PATH"

# shellcheck source=scripts/lib/test-harness.sh
. "$SCRIPT_DIR/lib/test-harness.sh"
# shellcheck source=scripts/lib/portable.sh
. "$SCRIPT_DIR/lib/portable.sh"
th_init "$@"

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

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

create_runner() {
  local dir="$1"
  mkdir -p "$dir"
  cp "$REPO_ROOT/scripts/pr-gate.sh" "$dir/pr-gate.sh"
  chmod +x "$dir/pr-gate.sh"
  local cmd
  for cmd in bash git date readlink dirname basename cp mkdir touch ln cat grep sort wc awk sed mktemp rm head tail tr true false sha256sum shasum; do
    src="$(command -v "$cmd" 2>/dev/null || true)"
    if [[ -n "$src" ]]; then
      ln -sf "$src" "$dir/$cmd"
    fi
  done

  mkdir -p "$dir/.claude"
  mkdir -p "$dir/adapters/codex"
  cat > "$dir/adapters/codex/dispatch.sh" <<'STUB_EOF'
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
    printf -- '---\ngate_result_version: pr_gate_result_v1\nfinal: GO\ntier: standard\nmode: sequential\nmost_severe: advise\nreviewers:\n  critic: advise\nescalation:\n  recommended: false\n  reviewers: []\n  reason: []\n---\n\n# PR-Gate Result — stub tier\n**Date**: 2026-05-17\n**Reviewers**: stub\n**Not reviewed**: none\n\n## cross-check\nnone\n\n## Gate Conclusion\n**Overall verdict**: advise\n**Most severe individual verdict**: advise\nFinal: GO\n' > "$output_path"
  else
    printf -- '---\ngate_result_version: pr_gate_result_v1\nfinal: GO\ntier: standard\nmode: sequential\nmost_severe: advise\nreviewers:\n  critic: advise\nescalation:\n  recommended: false\n  reviewers: []\n  reason: []\n---\n\n## stub-reviewer — advise\nVerdict: advise. Stub output.\nFinal: GO\n' > "$output_path"
  fi
fi

exit 0
STUB_EOF
  chmod +x "$dir/adapters/codex/dispatch.sh"

  # claude adapter stub (CC-383): claude now dispatches a real subprocess too.
  # Same result-writing behavior as the codex stub, but keyed on a SEPARATE
  # called-marker (CLAUDE_GATE_STUB_CALLED_MARKER) so a test can assert the
  # claude route does NOT invoke the codex adapter.
  mkdir -p "$dir/adapters/claude"
  cat > "$dir/adapters/claude/dispatch.sh" <<'CLAUDE_STUB_EOF'
#!/usr/bin/env bash
set -euo pipefail

brief_file=""
MODE="${CLAUDE_GATE_STUB_MODE:-success}"
MARKER="${CLAUDE_GATE_STUB_CALLED_MARKER:-}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --brief-file) brief_file="$2"; shift 2 ;;
    --cd|--timeout|--model|--isolation) shift 2 ;;
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
    printf -- '---\ngate_result_version: pr_gate_result_v1\nfinal: GO\ntier: standard\nmode: sequential\nmost_severe: advise\nreviewers:\n  critic: advise\nescalation:\n  recommended: false\n  reviewers: []\n  reason: []\n---\n\n# PR-Gate Result — stub tier\n**Date**: 2026-05-17\n**Reviewers**: stub\n**Not reviewed**: none\n\n## cross-check\nnone\n\n## Gate Conclusion\n**Overall verdict**: advise\n**Most severe individual verdict**: advise\nFinal: GO\n' > "$output_path"
  else
    printf -- '---\ngate_result_version: pr_gate_result_v1\nfinal: GO\ntier: standard\nmode: sequential\nmost_severe: advise\nreviewers:\n  critic: advise\nescalation:\n  recommended: false\n  reviewers: []\n  reason: []\n---\n\n## stub-reviewer — advise\nVerdict: advise. Stub output.\nFinal: GO\n' > "$output_path"
  fi
fi

exit 0
CLAUDE_STUB_EOF
  chmod +x "$dir/adapters/claude/dispatch.sh"
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
    printf '.agent-trace/\n.gate-briefs/\n.gate-results/\n' > .gitignore
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
  for cmd in bash git date readlink dirname basename cp mkdir touch ln cat grep sort wc awk sed mktemp rm cat sort head tail tr wc awk date sha256sum shasum git; do
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
  # CC-350: codex dispatch chatter now lands on stderr, not stdout.
  assert_contains "$name" "$err" "DISPATCH_STUB:success" || return
  assert_not_contains "$name" "$out" '```pr-gate-handover_v1' || return
  local result
  result=$(extract_result_path "$out")
  if [[ -z "$result" || ! -s "$result" ]]; then
    fail "$name" "result file not produced or not found"
    return
  fi
  pass "$name"
}

test_executor_claude_sequential_dispatches_subprocess() {
  # CC-383: --executor claude dispatches an independent subprocess (headless
  # `claude --print` via the claude adapter), writes the result in-process, and
  # emits NO pr-gate-handover_v1 block. Single-session dispatch chatter lands on
  # stderr (CC-350), like codex.
  local name="executor-claude-sequential-dispatches-subprocess"
  local dir="$TMP_ROOT/$name"
  local home="$dir/home" repo="$dir/repo" runner="$dir/runner"
  local out="$dir/out" err="$dir/err"
  local result
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
  assert_not_contains "$name" "$out" '```pr-gate-handover_v1' || return
  assert_contains "$name" "$err" "DISPATCH_STUB:success" || return

  result=$(extract_result_path "$out")
  if [[ -z "$result" || ! -s "$result" ]]; then
    fail "$name" "claude route did not materialize the result file"
    return
  fi
  assert_contains "$name" "$result" "Final: GO" || return
  pass "$name"
}

test_executor_claude_parallel_dispatches_subprocess() {
  # CC-383: parallel --executor claude dispatches one subprocess per reviewer
  # plus a synthesis subprocess, materializes the consolidated result, and emits
  # NO handover block.
  local name="executor-claude-parallel-dispatches-subprocess"
  local dir="$TMP_ROOT/$name"
  local home="$dir/home" repo="$dir/repo" runner="$dir/runner"
  local out="$dir/out" err="$dir/err"
  local result
  mkdir -p "$dir"

  create_runner "$runner"
  create_agents "$home" critic qa-tester architecture-reviewer security-reviewer risk-reviewer
  create_repo "$repo"

  set +e
  run_gate "$home" "$runner" "$repo" "$out" "$err" "$runner" --executor claude --reviewers critic,qa-tester --parallel --base main
  local code=$?
  set -e
  if [[ "$code" -ne 0 ]]; then
    fail "$name" "exit $code, expected 0; stderr: $(tail -3 "$err" 2>/dev/null)"
    return
  fi
  assert_not_contains "$name" "$out" '```pr-gate-handover_v1' || return

  result=$(extract_result_path "$out")
  if [[ -z "$result" || ! -s "$result" ]]; then
    fail "$name" "claude parallel route did not materialize the consolidated result"
    return
  fi
  assert_contains "$name" "$result" "Final: GO" || return
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
  # CC-350: codex dispatch chatter now lands on stderr, not stdout.
  assert_contains "$name" "$err" "DISPATCH_STUB:success" || return
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
  # auto-detect picks claude when no codex binary is on PATH; claude now
  # dispatches a subprocess (no handover) and materializes the result.
  assert_not_contains "$name" "$out" '```pr-gate-handover_v1' || return
  assert_contains "$name" "$err" "DISPATCH_STUB:success" || return
  pass "$name"
}

test_no_lib_copy_mode_uses_inline_executor_fallback() {
  local name="no-lib-copy-mode-uses-inline-executor-fallback"
  local dir="$TMP_ROOT/$name"
  local home="$dir/home" repo="$dir/repo" runner="$dir/runner" isolated_cwd="$dir/isolated-cwd"
  local out="$dir/out" err="$dir/err"
  local no_codex_path
  mkdir -p "$dir" "$isolated_cwd"

  create_runner "$runner"
  create_repo "$repo"
  no_codex_path="$(build_no_codex_path "$dir")"

  if [[ -e "$runner/lib" ]]; then
    fail "$name" "copy-mode fixture unexpectedly contains lib/"
    return
  fi

  set +e
  (
    cd "$isolated_cwd"
    HOME="$home" PATH="$no_codex_path" "$runner/pr-gate.sh" --cd "$repo" --executor auto --base __missing_base__
  ) > "$out" 2> "$err"
  local code=$?
  set -e

  if [[ "$code" -eq 0 ]]; then
    fail "$name" "expected non-zero exit from missing base ref"
    return
  fi
  assert_contains "$name" "$err" "Error: base ref not found: __missing_base__" || return
  assert_not_contains "$name" "$err" "executor router not found" || return
  assert_not_contains "$name" "$err" "executor-router.sh" || return
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
  # Validation is delegated to resolve_executor (CC-373): unknown names are
  # rejected fail-closed. The "unknown executor: <name>" substring is emitted by
  # both the data-driven lib and the copy-mode inline fallback.
  assert_contains "$name" "$err" "unknown executor: invalid" || return
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

  cat > "$runner/adapters/codex/dispatch.sh" <<'STUB_EOF'
#!/usr/bin/env bash
set -euo pipefail
marker="${CODEX_GATE_STUB_CALLED_MARKER:-}"
[[ -n "$marker" ]] && printf 'called\n' > "$marker"
exit 99
STUB_EOF
  chmod +x "$runner/adapters/codex/dispatch.sh"

  set +e
  CODEX_GATE_STUB_CALLED_MARKER="$marker" run_gate "$home" "$runner" "$repo" "$out" "$err" "$runner" --executor claude --base main
  local code=$?
  set -e
  if [[ "$code" -ne 0 ]]; then
    fail "$name" "exit $code, expected 0"
    return
  fi
  if [[ -f "$marker" ]]; then
    fail "$name" "codex adapter was invoked on the claude route"
    return
  fi
  local result
  result=$(extract_result_path "$out")
  if [[ -z "$result" || ! -s "$result" ]]; then
    fail "$name" "claude route did not materialize the result file"
    return
  fi
  assert_not_contains "$name" "$out" '```pr-gate-handover_v1' || return
  pass "$name"
}

test_executor_claude_post_gate_hook_skipped_without_allow_hooks() {
  # CC-383: claude now completes the gate in-process like codex, so post-gate is
  # the SAME success-only hook for both executors -- skipped (with a warning)
  # unless --allow-hooks is passed. Verifies the hook body does NOT run on the
  # claude route without --allow-hooks.
  local name="executor-claude-post-gate-hook-skipped-without-allow-hooks"
  local dir="$TMP_ROOT/$name"
  local home="$dir/home" repo="$dir/repo" runner="$dir/runner"
  local out="$dir/out" err="$dir/err" hook_marker="$dir/hook.marker"
  mkdir -p "$dir"

  create_runner "$runner"
  create_agents "$home" critic qa-tester architecture-reviewer security-reviewer risk-reviewer
  create_repo "$repo"
  mkdir -p "$repo/.pm-dispatch"
  {
    printf '#!/usr/bin/env bash\n'
    printf 'touch "%s"\n' "$hook_marker"
  } > "$repo/.pm-dispatch/post-gate.sh"
  chmod +x "$repo/.pm-dispatch/post-gate.sh"

  set +e
  run_gate "$home" "$runner" "$repo" "$out" "$err" "$runner" --executor claude --base main
  local code=$?
  set -e
  if [[ "$code" -ne 0 ]]; then
    fail "$name" "exit $code, expected 0"
    return
  fi
  if [[ -f "$hook_marker" ]]; then
    fail "$name" "post-gate hook ran without --allow-hooks"
    return
  fi
  assert_contains "$name" "$err" "pass --allow-hooks" || return
  pass "$name"
}

test_commands_pr_gate_md_documents_executors() {
  local name="commands-pr-gate-md-documents-executors"
  local target="$REPO_ROOT/commands/pr-gate.md"
  assert_contains "$name" "$target" "codex" || return
  assert_contains "$name" "$target" "claude" || return
  pass "$name"
}

test_commands_pr_gate_md_uses_detached_lifecycle() {
  # CC-423: /pr-gate launches via `gate run --lifecycle detached` (inline,
  # fast) then hands off to `gate wait` under run_in_background, replacing
  # the prior single-call `gate run` under run_in_background.
  local name="commands-pr-gate-md-uses-detached-lifecycle"
  local target="$REPO_ROOT/commands/pr-gate.md"
  assert_contains "$name" "$target" "gate run" || return
  assert_contains "$name" "$target" "--lifecycle detached" || return
  assert_contains "$name" "$target" "gate wait" || return
  pass "$name"
}

test_commands_pr_gate_md_does_not_reuse_shell_var_across_bash_calls() {
  # CC-423 pr-gate finding (critic/qa-tester/architecture-reviewer/
  # risk-reviewer, high): an earlier draft captured `GATE_ID="$(...)"` in the
  # run call's code block and reused `"$GATE_ID"` in the wait call's separate
  # code block. Each Bash tool call is an independent subprocess -- shell
  # variables never survive across calls -- so the wait would receive an
  # empty gate_id. The doc must show the wait command receiving a literal
  # gate_id token (the `<gate_id>` placeholder convention commands/pm.md
  # already uses for `run_id`/`gate_id`), never a `$GATE_ID`/`${GATE_ID}`
  # shell-variable reference. scripts/test-pmctl-gate.sh's
  # case_run_wait_handoff_survives_separate_process proves the corrected
  # literal-substitution handoff actually works end to end; this case is the
  # regression lock on the doc text itself so the broken pattern can't creep
  # back in silently.
  local name="commands-pr-gate-md-no-shell-var-reuse-across-bash-calls"
  local target="$REPO_ROOT/commands/pr-gate.md"
  assert_not_contains "$name" "$target" '$GATE_ID' || return
  assert_not_contains "$name" "$target" '${GATE_ID}' || return
  assert_contains "$name" "$target" '<gate_id>' || return
  pass "$name"
}

run_case() {
  local name="$1" fn="$2"
  should_run "$name" || return 0
  if "$fn"; then
    :
  else
    fail "$name" "case function returned non-zero"
  fi
}

_PGP_PLATFORM="$(detect_platform)"
if [[ "$_PGP_PLATFORM" == "windows" ]]; then
  printf 'SKIP: test-pr-gate-profile (Windows: ln -sf system binary stubs not supported on MSYS)\n'
  th_summary
  exit 0
fi

run_case "executor-codex-flag-explicit-keeps-behavior" test_executor_codex_flag_explicit_keeps_behavior
run_case "executor-claude-sequential-dispatches-subprocess" test_executor_claude_sequential_dispatches_subprocess
run_case "executor-claude-parallel-dispatches-subprocess" test_executor_claude_parallel_dispatches_subprocess
run_case "executor-auto-with-codex" test_executor_auto_with_codex
run_case "executor-auto-without-codex" test_executor_auto_without_codex
run_case "no-lib-copy-mode-uses-inline-executor-fallback" test_no_lib_copy_mode_uses_inline_executor_fallback
run_case "executor-claude-post-gate-hook-skipped-without-allow-hooks" test_executor_claude_post_gate_hook_skipped_without_allow_hooks
run_case "executor-claude-never-calls-codex" test_executor_claude_never_calls_codex
run_case "executor-invalid-value-rejected" test_executor_invalid_value_rejected
run_case "commands-pr-gate-md-documents-executors" test_commands_pr_gate_md_documents_executors
run_case "commands-pr-gate-md-uses-detached-lifecycle" test_commands_pr_gate_md_uses_detached_lifecycle
run_case "commands-pr-gate-md-no-shell-var-reuse-across-bash-calls" test_commands_pr_gate_md_does_not_reuse_shell_var_across_bash_calls

th_summary
