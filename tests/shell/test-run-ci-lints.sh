#!/usr/bin/env bash
# Regression tests for ops/diagnostics/run-ci-lints.sh: which workflow steps it
# selects, what it skips, that it runs every step after a failure, and that the
# list is read from the real .github/workflows/lint.yml.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TOOL="$REPO_ROOT/ops/diagnostics/run-ci-lints.sh"

# shellcheck source=tests/lib/test-harness.sh
# shellcheck disable=SC1091
. "$SCRIPT_DIR/../lib/test-harness.sh"
th_init "$@"

# fixture <slug> -- a root with three tiny linters and a workflow that mixes the step shapes.
# Prints the root; the workflow is <root>/wf.yml.
fixture() {
  # shellcheck disable=SC2154  # tmp_root from th_init
  local root="$tmp_root/$1"
  mkdir -p "$root/tools/lint" "$root/pm/scripts"
  printf '#!/usr/bin/env bash\necho "fine: $*"\n' > "$root/tools/lint/ok.sh"
  printf '#!/usr/bin/env bash\necho "broken: thing"\nexit 3\n' > "$root/tools/lint/bad.sh"
  printf '#!/usr/bin/env bash\necho "validated"\n' > "$root/pm/scripts/validate.sh"
  # The workflow runs them as `./tools/lint/ok.sh`; native Windows ignores the mode, Linux does not.
  chmod +x "$root/tools/lint/ok.sh" "$root/tools/lint/bad.sh" "$root/pm/scripts/validate.sh"
  cat > "$root/wf.yml" <<'YAML'
name: fixture
jobs:
  one:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6
      - name: Inline lint
        run: ./tools/lint/ok.sh inline
      - name: Block lint
        run: |
          set +e
          out=$(bash pm/scripts/validate.sh BACKLOG.md 2>&1)
          printf '%s\n' "$out"
          exit 0
      - name: CI only lint
        env:
          X: ${{ github.token }}
        run: bash tools/lint/ok.sh "$GITHUB_REPOSITORY"
      - name: An ordinary suite
        run: bash tests/shell/test-something.sh
      - run: bash tools/lint/ok.sh nameless
YAML
  printf '%s\n' "$root"
}

run_tool() { bash "$TOOL" "$@" 2>&1; }

test_list_selects_lint_steps_and_skips_ci_only() {
  local name="--list shows the lint steps, marks CI-only ones skipped and ignores suites"
  should_run "$name" || return 0
  local root out rc=0
  root="$(fixture list)"
  out="$(run_tool --list --root "$root" --workflow "$root/wf.yml")" || rc=$?
  if [[ "$rc" -eq 0 && "$out" == *"run   Inline lint"* && "$out" == *"run   Block lint"* \
        && "$out" == *"skip  CI only lint (uses CI-only variables)"* \
        && "$out" == *"bash tools/lint/ok.sh nameless"* && "$out" != *"ordinary suite"* \
        && "$out" == *"\$ ./tools/lint/ok.sh inline"* && "$out" == *"\$ out=\$(bash pm/scripts/validate.sh BACKLOG.md 2>&1)"* ]]; then
    pass "$name"
  else
    fail "$name" "rc=$rc out=$out"
  fi
}

test_run_all_pass() {
  local name="a run where every step passes exits 0 with a summary"
  should_run "$name" || return 0
  local root out rc=0
  root="$(fixture pass)"
  out="$(run_tool --root "$root" --workflow "$root/wf.yml")" || rc=$?
  if [[ "$rc" -eq 0 && "$out" == *"ok    Inline lint"* && "$out" == *"ok    Block lint"* \
        && "$out" == *"3 passed, 0 failed, 1 skipped"* ]]; then
    pass "$name"
  else
    fail "$name" "rc=$rc out=$out"
  fi
}

test_failure_is_reported_and_later_steps_still_run() {
  local name="a failing step exits 1, shows its output and does not stop the later steps"
  should_run "$name" || return 0
  local root out rc=0
  root="$(fixture fail)"
  cat >> "$root/wf.yml" <<'YAML'
      - name: Bad lint
        run: ./tools/lint/bad.sh
      - name: Last lint
        run: ./tools/lint/ok.sh last
YAML
  out="$(run_tool --root "$root" --workflow "$root/wf.yml")" || rc=$?
  # The step after the failing one must run, and the failure's own output is shown.
  if [[ "$rc" -eq 1 && "$out" == *"FAIL  Bad lint"* && "$out" == *"| broken: thing"* \
        && "$out" == *"ok    Last lint"* && "$out" == *"4 passed, 1 failed, 1 skipped"* \
        && "$out" == *"failed: Bad lint"* ]]; then
    pass "$name"
  else
    fail "$name" "rc=$rc out=$out"
  fi
}

test_only_filters_by_name_or_command() {
  local name="--only keeps the steps whose name or command contains the text, and fails when none match"
  should_run "$name" || return 0
  local root out rc=0 out2 rc2=0
  root="$(fixture only)"
  out="$(run_tool --only "Block" --root "$root" --workflow "$root/wf.yml")" || rc=$?
  out2="$(run_tool --only "no-such-step" --root "$root" --workflow "$root/wf.yml")" || rc2=$?
  if [[ "$rc" -eq 0 && "$out" == *"1 passed, 0 failed, 0 skipped"* && "$out" != *"Inline lint"* \
        && "$rc2" -eq 2 && "$out2" == *"no lint step selected"* ]]; then
    pass "$name"
  else
    fail "$name" "rc=$rc out=$out rc2=$rc2 out2=$out2"
  fi
}

test_crlf_workflow_is_read() {
  local name="a workflow with CRLF line endings yields the same steps"
  should_run "$name" || return 0
  local root out rc=0
  root="$(fixture crlf)"
  sed 's/$/\r/' "$root/wf.yml" > "$root/wf-crlf.yml"
  out="$(run_tool --root "$root" --workflow "$root/wf-crlf.yml")" || rc=$?
  # A carriage return left on a step name would sit before the " (0s)": the names must be clean.
  if [[ "$rc" -eq 0 && "$out" == *"3 passed, 0 failed, 1 skipped"* \
        && "$out" == *"ok    Inline lint ("* && -z "$(printf '%s' "$out" | tr -cd '\r')" ]]; then
    pass "$name"
  else
    fail "$name" "rc=$rc out=$out"
  fi
}

test_real_workflow_list_is_derived_from_lint_yml() {
  local name="the list for the real lint.yml carries the known linters, the BACKLOG validators and the CI-only skips"
  should_run "$name" || return 0
  local out rc=0 runs
  out="$(run_tool --list)" || rc=$?
  runs="$(printf '%s\n' "$out" | grep -c '^run ')"
  # A floor, not an exact count: a lint step added to CI appears by itself; the names below are
  # steps that exist today and would vanish if the extraction broke.
  if [[ "$rc" -eq 0 && "$runs" -ge 15 && "$out" == *"run   Validate agent frontmatter"* \
        && "$out" == *"run   Validate BACKLOG.md"* \
        && "$out" == *"run   Validate canonical shell domains and compatibility shims"* \
        && "$out" == *"skip  Install repository-pinned ShellCheck"* \
        && "$out" == *"skip  Enforce the Step 4 'Permanent test admissions:' record"* \
        && "$out" != *"host, adapter and tooling suites"* ]]; then
    pass "$name"
  else
    fail "$name" "rc=$rc runs=$runs out=$(printf '%s' "$out" | head -c 800)"
  fi
}

test_usage_errors() {
  local name="an unknown option or a missing operand is a usage error, --help exits 0"
  should_run "$name" || return 0
  local rc1=0 rc2=0 rc3=0 rc4=0
  run_tool --bogus >/dev/null || rc1=$?
  run_tool --only >/dev/null || rc2=$?
  run_tool --workflow "$tmp_root/no-such-workflow.yml" >/dev/null || rc3=$?
  run_tool --help >/dev/null || rc4=$?
  if [[ "$rc1" -eq 2 && "$rc2" -eq 2 && "$rc3" -eq 2 && "$rc4" -eq 0 ]]; then
    pass "$name"
  else
    fail "$name" "bogus=$rc1 only=$rc2 missing-workflow=$rc3 help=$rc4"
  fi
}

test_list_selects_lint_steps_and_skips_ci_only
test_run_all_pass
test_failure_is_reported_and_later_steps_still_run
test_only_filters_by_name_or_command
test_crlf_workflow_is_read
test_real_workflow_list_is_derived_from_lint_yml
test_usage_errors

th_summary
