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

test_step_shapes_match_what_ci_would_run() {
  local name="steps run with bash -e, comments do not select, names come from the step, odd shapes skip"
  should_run "$name" || return 0
  local root out list rc=0
  root="$(fixture shapes)"
  cat > "$root/wf-shapes.yml" <<'YAML'
jobs:
  one:
    steps:
      - name: Mid-block failure
        run: |
          ./tools/lint/bad.sh
          echo "the last command succeeds"
      - name: Comment only
        run: |
          # tools/lint/ok.sh would run here
          echo hello
      - name: Real name
        with:
          name: Nested name
        run: ./tools/lint/ok.sh nested
      - name: Env expression after run
        run: ./tools/lint/ok.sh env
        env:
          T: ${{ secrets.T }}
      - name: Folded block
        run: >
          ./tools/lint/ok.sh folded
      - name: Commented header
        run: | # explain
          ./tools/lint/ok.sh commented
      - name: Quoted scalar
        run: "./tools/lint/ok.sh quoted"
      - name: Echo only
        run: echo tools/lint/ok.sh
      - name: Argument only
        run: git add tools/lint/ok.sh
      - name: Keyword then linter
        run: |
          if bash tools/lint/ok.sh cond; then echo fine; fi
YAML
  list="$(run_tool --list --root "$root" --workflow "$root/wf-shapes.yml")" || rc=$?
  out="$(run_tool --root "$root" --workflow "$root/wf-shapes.yml")" || true
  # GitHub runs a script with `bash -e`, so the failing first command fails the step even though the
  # last one succeeds; a comment that mentions a linter selects nothing.
  if [[ "$rc" -eq 0 && "$out" == *"FAIL  Mid-block failure"* && "$list" != *"Comment only"* \
        && "$list" == *"run   Real name"* && "$list" != *"Nested name"* \
        && "$list" == *"skip  Env expression after run (uses CI-only variables)"* \
        && "$list" == *"skip  Folded block (uses a folded YAML block)"* \
        && "$list" == *"run   Commented header"* && "$out" == *"ok    Commented header"* \
        && "$list" == *"skip  Quoted scalar (uses a quoted YAML scalar)"* \
        && "$list" != *"Echo only"* && "$list" != *"Argument only"* \
        && "$list" == *"run   Keyword then linter"* ]]; then
    pass "$name"
  else
    fail "$name" "rc=$rc list=$list out=$out"
  fi
}

test_wsl_refuses_host_paths() {
  local name="--wsl cannot be combined with --root or --workflow"
  should_run "$name" || return 0
  local out rc=0
  out="$(run_tool --wsl --workflow "$tmp_root/x.yml")" || rc=$?
  if [[ "$rc" -eq 2 && "$out" == *"cannot be combined with --wsl"* ]]; then
    pass "$name"
  else
    fail "$name" "rc=$rc out=$out"
  fi
}

# wsl_fixture <slug> -- the external boundaries of --wsl, faked. Prints the base dir:
#   <base>/host    a repository root holding a copy of the tool and a fake run-tests-in-wsl.sh
#                  (--sync-only copies the fixture tree to FAKE_SCRATCH/host and reports it)
#   <base>/bin     a fake wsl.exe that logs its arguments and runs what follows `-e` for real
#   <base>/cache   a stand-in for the helper's cache; scratch trees inside .cache/pm-dispatch-wsl-tests/ may be removed
# The workflow tree the "WSL copy" is made from is $tmp_root/<slug>-tree.
wsl_fixture() {
  local base="$tmp_root/$1"
  fixture "$1-tree" > /dev/null
  mkdir -p "$base/host/ops/diagnostics" "$base/bin" "$base/cache/.cache/pm-dispatch-wsl-tests"
  cp "$TOOL" "$base/host/ops/diagnostics/run-ci-lints.sh"
  cat > "$base/host/ops/diagnostics/run-tests-in-wsl.sh" <<'SH'
#!/usr/bin/env bash
[[ "${1:-}" == "--sync-only" ]] || { echo "fake sync: unexpected arguments: $*" >&2; exit 9; }
case "$FAKE_SYNC_MODE" in
  fail) echo "fake sync: boom" >&2; echo "run-tests-in-wsl: scratch tree kept: $FAKE_SCRATCH"; exit 1 ;;
  nomarker) echo "synced, but no marker line"; exit 0 ;;
esac
dest="$FAKE_SCRATCH/$(basename "$(cd "$(dirname "$0")/../.." && pwd)")"
mkdir -p "$dest/.github/workflows" "$dest/ops/diagnostics"
cp -r "$FAKE_TREE/tools" "$FAKE_TREE/pm" "$dest/"
cp "$FAKE_TREE/wf.yml" "$dest/.github/workflows/lint.yml"
cp "$(dirname "$0")/run-ci-lints.sh" "$dest/ops/diagnostics/"
echo "run-tests-in-wsl: scratch tree kept: $FAKE_SCRATCH"
SH
  cat > "$base/bin/wsl.exe" <<'SH'
#!/usr/bin/env bash
echo "wsl $*" >> "$FAKE_WSL_LOG"
[[ "${1:-}" == "-e" ]] || exit 9
shift
exec "$@"
SH
  chmod +x "$base/host/ops/diagnostics/run-tests-in-wsl.sh" "$base/bin/wsl.exe"
  printf '%s\n' "$base"
}

# run_wsl <base> <sync mode> <scratch dir> <tool args...> -- runs the copied tool with --wsl as if on native Windows.
run_wsl() {
  local base="$1" mode="$2" scratch="$3"; shift 3
  env OSTYPE=msys PATH="$base/bin:$PATH" FAKE_SYNC_MODE="$mode" FAKE_SCRATCH="$scratch" \
      FAKE_TREE="$tmp_root/$(basename "$base")-tree" FAKE_WSL_LOG="$base/wsl.log" \
      bash "$base/host/ops/diagnostics/run-ci-lints.sh" --wsl "$@" 2>&1
}

test_wsl_forwards_arguments_runs_the_copy_and_removes_it() {
  local name="--wsl runs the synced copy with the same arguments, returns its result and removes only that copy"
  should_run "$name" || return 0
  local base scratch out listing rc=0 rc2=0
  base="$(wsl_fixture wsl-ok)"
  scratch="$base/cache/.cache/pm-dispatch-wsl-tests/s1"
  out="$(run_wsl "$base" ok "$scratch" --only Block)" || rc=$?
  listing="$(run_wsl "$base" ok "$scratch" --list)" || rc2=$?
  # The dispatch line carries the scratch tree, the repository directory name and the forwarded arguments;
  # the second wsl.exe call is the cleanup, which really ran (the directory is gone).
  if [[ "$rc" -eq 0 && "$out" == *"1 passed, 0 failed, 0 skipped"* && "$out" != *"Inline lint"* \
        && "$rc2" -eq 0 && "$listing" == *"run   Inline lint"* && "$listing" != *"passed"* \
        && "$(grep -c '^wsl ' "$base/wsl.log")" -eq 4 \
        && "$(grep -cF "$scratch host --only Block" "$base/wsl.log")" -eq 1 \
        && "$(grep -cF "$scratch host --list" "$base/wsl.log")" -eq 1 \
        && ! -e "$scratch" ]]; then
    pass "$name"
  else
    fail "$name" "rc=$rc rc2=$rc2 out=$out listing=$listing log=$(cat "$base/wsl.log" 2>/dev/null) left=$(ls "$scratch" 2>&1)"
  fi
}

test_wsl_propagates_a_failing_lint_and_still_cleans_up() {
  local name="--wsl returns the failing lint's status and still removes the copy"
  should_run "$name" || return 0
  local base scratch out rc=0
  base="$(wsl_fixture wsl-fail)"
  scratch="$base/cache/.cache/pm-dispatch-wsl-tests/s1"
  cat >> "$tmp_root/wsl-fail-tree/wf.yml" <<'YAML'
      - name: Bad lint
        run: ./tools/lint/bad.sh
YAML
  out="$(run_wsl "$base" ok "$scratch")" || rc=$?
  if [[ "$rc" -eq 1 && "$out" == *"FAIL  Bad lint"* && ! -e "$scratch" ]]; then
    pass "$name"
  else
    fail "$name" "rc=$rc out=$out left=$(ls "$scratch" 2>&1)"
  fi
}

test_wsl_dispatches_nothing_when_the_sync_is_unusable() {
  local name="--wsl exits 2 and starts nothing when the sync fails or does not report a scratch tree"
  should_run "$name" || return 0
  local base1 base2 out1 out2 rc1=0 rc2=0
  base1="$(wsl_fixture wsl-syncfail)"
  base2="$(wsl_fixture wsl-nomarker)"
  out1="$(run_wsl "$base1" fail "$base1/cache/.cache/pm-dispatch-wsl-tests/s1")" || rc1=$?
  out2="$(run_wsl "$base2" nomarker "$base2/cache/.cache/pm-dispatch-wsl-tests/s1")" || rc2=$?
  if [[ "$rc1" -eq 2 && "$out1" == *"fake sync: boom"* && ! -e "$base1/wsl.log" \
        && "$rc2" -eq 2 && "$out2" == *"could not read the WSL scratch tree"* && ! -e "$base2/wsl.log" ]]; then
    pass "$name"
  else
    fail "$name" "rc1=$rc1 out1=$out1 rc2=$rc2 out2=$out2"
  fi
}

test_wsl_never_removes_a_tree_outside_the_helper_cache() {
  local name="--wsl leaves a scratch tree alone when it is not under the helper's cache directory"
  should_run "$name" || return 0
  local base scratch out rc=0
  base="$(wsl_fixture wsl-guard)"
  scratch="$base/elsewhere/s1"
  out="$(run_wsl "$base" ok "$scratch" --only Block)" || rc=$?
  if [[ "$rc" -eq 0 && "$out" == *"1 passed"* && -d "$scratch/host" ]]; then
    pass "$name"
  else
    fail "$name" "rc=$rc out=$out left=$(ls "$scratch" 2>&1)"
  fi
}

test_pinned_shellcheck_wins_over_the_ambient_one() {
  local name="an executed step sees the repository-pinned ShellCheck first, and the ambient one when no pin is usable"
  should_run "$name" || return 0
  local root amb seen_pinned seen_unusable seen_absent
  root="$(fixture pin)"
  amb="$tmp_root/pin-ambient"
  mkdir -p "$amb" "$root/pinned"
  printf '#!/usr/bin/env bash\necho ambient\n' > "$amb/shellcheck"
  printf '#!/usr/bin/env bash\necho pinned\n' > "$root/pinned/shellcheck"
  # The step records which ShellCheck it resolved; the stub bootstrap answers --resolve with $PIN_PATH.
  printf '#!/usr/bin/env bash\nshellcheck > probe.out\n' > "$root/tools/lint/probe.sh"
  # shellcheck disable=SC2016  # the $ must reach the generated script unexpanded
  printf '#!/usr/bin/env bash\n[ "${1:-}" = --resolve ] && echo "$PIN_PATH"\nexit 0\n' > "$root/tools/lint/bootstrap-shellcheck.sh"
  chmod +x "$amb/shellcheck" "$root/pinned/shellcheck" "$root/tools/lint/probe.sh" "$root/tools/lint/bootstrap-shellcheck.sh"
  printf 'jobs:\n  one:\n    steps:\n      - name: Probe\n        run: ./tools/lint/probe.sh\n' > "$root/wf-pin.yml"

  PATH="$amb:$PATH" PIN_PATH="$root/pinned/shellcheck" bash "$TOOL" --root "$root" --workflow "$root/wf-pin.yml" > /dev/null 2>&1
  seen_pinned="$(cat "$root/probe.out" 2>/dev/null)"
  rm -f "$root/probe.out"
  PATH="$amb:$PATH" PIN_PATH="$root/pinned/not-installed" bash "$TOOL" --root "$root" --workflow "$root/wf-pin.yml" > /dev/null 2>&1
  seen_unusable="$(cat "$root/probe.out" 2>/dev/null)"
  rm -f "$root/probe.out" "$root/tools/lint/bootstrap-shellcheck.sh"
  PATH="$amb:$PATH" bash "$TOOL" --root "$root" --workflow "$root/wf-pin.yml" > /dev/null 2>&1
  seen_absent="$(cat "$root/probe.out" 2>/dev/null)"
  if [[ "$seen_pinned" == "pinned" && "$seen_unusable" == "ambient" && "$seen_absent" == "ambient" ]]; then
    pass "$name"
  else
    fail "$name" "pinned=$seen_pinned unusable=$seen_unusable absent=$seen_absent"
  fi
}

test_list_selects_lint_steps_and_skips_ci_only
test_step_shapes_match_what_ci_would_run
test_pinned_shellcheck_wins_over_the_ambient_one
test_wsl_refuses_host_paths
test_wsl_forwards_arguments_runs_the_copy_and_removes_it
test_wsl_propagates_a_failing_lint_and_still_cleans_up
test_wsl_dispatches_nothing_when_the_sync_is_unusable
test_wsl_never_removes_a_tree_outside_the_helper_cache
test_run_all_pass
test_failure_is_reported_and_later_steps_still_run
test_only_filters_by_name_or_command
test_crlf_workflow_is_read
test_real_workflow_list_is_derived_from_lint_yml
test_usage_errors

th_summary
