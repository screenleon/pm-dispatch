#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ORIGINAL_PATH="$PATH"

# shellcheck source=tests/lib/test-harness.sh
. "$SCRIPT_DIR/../lib/test-harness.sh"
# shellcheck source=tests/lib/test-pr-gate-fixture.sh
. "$SCRIPT_DIR/../lib/test-pr-gate-fixture.sh"
# shellcheck source=runtime/lib/portable.sh
. "$REPO_ROOT/runtime/lib/portable.sh"
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
  cp "$REPO_ROOT/runtime/bin/pr-gate.sh" "$dir/pr-gate.sh"
  chmod +x "$dir/pr-gate.sh"
  cp -R "$REPO_ROOT/agents" "$dir/agents"
  mkdir -p "$dir/lib"
  cp -R "$REPO_ROOT/runtime/lib/." "$dir/lib/"
  cp "$REPO_ROOT/tests/lib/test-pr-gate-fixture.sh" \
    "$dir/lib/test-pr-gate-fixture.sh"
  local cmd
  for cmd in bash git date readlink dirname basename cp mkdir touch ln cat grep sort wc awk sed mktemp rm mv find head tail tr true false sha256sum shasum jq; do
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
runner_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=tests/lib/test-pr-gate-fixture.sh
if [[ -f "$runner_root/lib/test-pr-gate-fixture.sh" ]]; then
  . "$runner_root/lib/test-pr-gate-fixture.sh"
else
  . "$runner_root/runtime/lib/test-pr-gate-fixture.sh"
fi
pr_gate_fixture_profile_dispatch codex "$@"
STUB_EOF
  chmod +x "$dir/adapters/codex/dispatch.sh"
  printf '%s\n' \
    'schema_version: 1' 'adapter_name: codex' \
    'runner_kind: cli-subprocess' 'dispatch_entrypoint: ./dispatch.sh' \
    > "$dir/adapters/codex/adapter.yaml"

  mkdir -p "$dir/adapters/claude"
  cat > "$dir/adapters/claude/dispatch.sh" <<'CLAUDE_STUB_EOF'
#!/usr/bin/env bash
set -euo pipefail
runner_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=tests/lib/test-pr-gate-fixture.sh
if [[ -f "$runner_root/lib/test-pr-gate-fixture.sh" ]]; then
  . "$runner_root/lib/test-pr-gate-fixture.sh"
else
  . "$runner_root/runtime/lib/test-pr-gate-fixture.sh"
fi
pr_gate_fixture_profile_dispatch claude "$@"
CLAUDE_STUB_EOF
  chmod +x "$dir/adapters/claude/dispatch.sh"
  printf '%s\n' \
    'schema_version: 1' 'adapter_name: claude' \
    'runner_kind: cli-subprocess' 'dispatch_entrypoint: ./dispatch.sh' \
    > "$dir/adapters/claude/adapter.yaml"
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
  for cmd in bash git date readlink dirname basename cp mkdir touch ln cat grep sort wc awk sed mktemp rm mv find cat sort head tail tr wc awk date sha256sum shasum git jq; do
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
  run_gate "$home" "$runner" "$repo" "$out" "$err" "$runner" \
    --executor claude \
    --reviewers critic,qa-tester,architecture-reviewer \
    --parallel --base main
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

# Behavior: A standalone runner without its canonical executor router fails
# closed before executor auto-detection can proceed to base-ref validation.
# Steps:
#   1. Arrange: create an isolated standalone runner and repository, remove only
#      the router while retaining earlier canonical libraries, and build a PATH
#      without Codex.
#   2. Act: run the Gate with executor auto and a deliberately missing base ref.
#   3. Assert: require exit 2 and the standalone canonical-router diagnostic,
#      with no missing-base diagnostic.
test_missing_router_copy_mode_fails_closed() {
  local name="missing-router-copy-mode-fails-closed"
  local dir="$TMP_ROOT/$name"
  local home="$dir/home" repo="$dir/repo" runner="$dir/runner" isolated_cwd="$dir/isolated-cwd"
  local out="$dir/out" err="$dir/err"
  local no_codex_path
  mkdir -p "$dir" "$isolated_cwd"

  create_runner "$runner"
  create_repo "$repo"
  no_codex_path="$(build_no_codex_path "$dir")"
  rm -f "${runner:?}/lib/executor-router.sh"

  if [[ ! -d "$runner/lib" || -e "$runner/lib/executor-router.sh" ]]; then
    fail "$name" "copy-mode fixture did not retain all libraries except router"
    return
  fi

  set +e
  (
    cd "$isolated_cwd"
    HOME="$home" PATH="$no_codex_path" "$runner/pr-gate.sh" --cd "$repo" --executor auto --base __missing_base__
  ) > "$out" 2> "$err"
  local code=$?
  set -e

  if [[ "$code" -ne 2 ]]; then
    fail "$name" "expected exit 2 without canonical router, got $code"
    return
  fi
  assert_contains "$name" "$err" \
    "canonical executor router unavailable for standalone-copy layout" || return
  assert_not_contains "$name" "$err" "Error: base ref not found" || return
  pass "$name"
}

# Behavior: Executor auto-detection rejects a PATH-visible Codex binary when the
# standalone runner has no registered Codex adapter manifest.
# Steps:
#   1. Arrange: add an executable Codex stub to PATH, create the runner and repo,
#      and remove the runner's Codex adapter directory.
#   2. Act: run the Gate with executor auto and a deliberately missing base ref.
#   3. Assert: require exit 2 and the unregistered-or-unroutable diagnostic,
#      with no missing-base diagnostic.
test_executor_auto_rejects_unregistered_path_candidate() {
  local name="executor-auto-rejects-unregistered-path-candidate"
  local dir="$TMP_ROOT/$name"
  local home="$dir/home" repo="$dir/repo" runner="$dir/runner" codex_bin="$dir/codex-bin"
  local out="$dir/out" err="$dir/err"
  mkdir -p "$dir" "$codex_bin"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$codex_bin/codex"
  chmod +x "$codex_bin/codex"

  create_runner "$runner"
  create_repo "$repo"
  rm -rf "${runner:?}/adapters/codex"

  set +e
  run_gate "$home" "$runner" "$repo" "$out" "$err" \
    "$runner:$codex_bin" --executor auto --base __missing_base__
  local code=$?
  set -e
  if [[ "$code" -ne 2 ]]; then
    fail "$name" "expected exit 2 for PATH candidate without manifest, got $code"
    return
  fi
  assert_contains "$name" "$err" \
    "auto-detected executor is not registered or routable: codex" || return
  assert_not_contains "$name" "$err" "Error: base ref not found" || return
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
  # Validation is delegated to the same canonical explicit-root resolver in
  # repo, installed-copy, and standalone-copy layouts.
  if [[ "$(<"$err")" != *"unknown executor: invalid"* ]]; then
    fail "$name" "missing unknown/invalid manifest executor diagnostic"
    return
  fi
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
  # shell-variable reference. tests/shell/test-pmctl-gate.sh's
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

test_commands_pr_gate_md_wait_block_self_resolves_pmctl() {
  # The wait command block must invoke `pmctl` bare -- no PMCTL=... resolution
  # preamble, no dependency on a variable assigned by an earlier, separate
  # Bash call. A resolution preamble (or any `$PMCTL` reference) means the
  # submitted command text never literally starts with `pmctl`, so it can
  # never match a `Bash(pmctl:*)`-style permission allowlist rule and forces
  # a manual approval on every wait call even when pmctl is already on PATH.
  # Extract the fenced code block that actually invokes `gate wait <gate_id>`
  # and require it to be a bare `pmctl ...` invocation with no PMCTL variable
  # anywhere in the block.
  local name="commands-pr-gate-md-wait-block-self-resolves-pmctl"
  local target="$REPO_ROOT/commands/pr-gate.md"
  local wait_block
  wait_block="$(awk '
    /^```bash$/ { buf=""; in_block=1; next }
    /^```$/ {
      if (in_block && buf ~ /gate wait <gate_id>/) { printf "%s", buf; found=1; exit }
      in_block=0; next
    }
    in_block { buf = buf $0 "\n" }
    END { if (!found) exit 1 }
  ' "$target")"
  if [[ -z "$wait_block" ]]; then
    fail "$name" "could not locate a fenced bash block invoking gate wait <gate_id> in $target"
    return
  fi
  if [[ "$wait_block" == *'PMCTL'* ]]; then
    fail "$name" "wait code block still depends on a PMCTL variable instead of a bare pmctl call: $wait_block"
    return
  fi
  if [[ "$wait_block" != 'pmctl gate wait <gate_id>'* ]]; then
    fail "$name" "wait code block does not open with a bare pmctl invocation: $wait_block"
    return
  fi
  pass "$name"
}

test_canonical_domain_functions_have_single_source_owner() {
  local name="canonical-domain-functions-have-single-source-owner"
  local entrypoint="$REPO_ROOT/runtime/bin/pr-gate.sh"
  local module function
  for module in \
    "$REPO_ROOT/runtime/lib/gate-assurance.sh" \
    "$REPO_ROOT/runtime/lib/gate-digest.sh" \
    "$REPO_ROOT/runtime/lib/gate-layout.sh" \
    "$REPO_ROOT/runtime/lib/gate-options.sh" \
    "$REPO_ROOT/runtime/lib/gate-policy.sh" \
    "$REPO_ROOT/runtime/lib/gate-scope.sh" \
    "$REPO_ROOT/runtime/lib/gate-reviewer-contract.sh"; do
    while IFS= read -r function; do
      [[ -n "$function" ]] || continue
      if rg -q "^${function}[[:space:]]*\\(\\)[[:space:]]*\\{" "$entrypoint"; then
        fail "$name" "${function} is duplicated in $entrypoint and $module"
        return
      fi
    done < <(rg -o '^[A-Za-z_][A-Za-z0-9_]*\(\)[[:space:]]*\{' "$module" \
      | sed -E 's/\(.*$//')
  done
  if rg -q '^SCRIPT_DIR[[:space:]]*=' "$entrypoint" \
      || rg -q '^PR_GATE_(LAYOUT|LIB_DIR|BUNDLE_ROOT|SCRIPT_DIR)[[:space:]]*=' "$entrypoint"; then
    fail "$name" 'entrypoint still owns deployment-layout classification'
    return
  fi
  if ! rg -q '^gate_layout_resolve[[:space:]]+' "$entrypoint"; then
    fail "$name" 'entrypoint does not resolve layout through the canonical module'
    return
  fi
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
run_case "executor-auto-rejects-unregistered-path-candidate" test_executor_auto_rejects_unregistered_path_candidate
run_case "missing-router-copy-mode-fails-closed" test_missing_router_copy_mode_fails_closed
run_case "executor-claude-post-gate-hook-skipped-without-allow-hooks" test_executor_claude_post_gate_hook_skipped_without_allow_hooks
run_case "executor-claude-never-calls-codex" test_executor_claude_never_calls_codex
run_case "executor-invalid-value-rejected" test_executor_invalid_value_rejected
run_case "commands-pr-gate-md-documents-executors" test_commands_pr_gate_md_documents_executors
run_case "commands-pr-gate-md-uses-detached-lifecycle" test_commands_pr_gate_md_uses_detached_lifecycle
run_case "commands-pr-gate-md-no-shell-var-reuse-across-bash-calls" test_commands_pr_gate_md_does_not_reuse_shell_var_across_bash_calls
run_case "commands-pr-gate-md-wait-block-self-resolves-pmctl" test_commands_pr_gate_md_wait_block_self_resolves_pmctl
run_case "canonical-domain-functions-have-single-source-owner" test_canonical_domain_functions_have_single_source_owner

th_summary
