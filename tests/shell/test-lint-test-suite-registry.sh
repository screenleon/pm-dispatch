#!/usr/bin/env bash
# Regression tests for tools/lint/lint-test-suite-registry.sh.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LINTER="$REPO_ROOT/tools/lint/lint-test-suite-registry.sh"
tmp_root=""
# shellcheck disable=SC1091
# shellcheck source=tests/lib/test-harness.sh
. "$SCRIPT_DIR/../lib/test-harness.sh"
th_init "$@"

should_run() {
  if $LIST; then ALL_CASES+=("$1"); return 1; fi
  [[ -z "$FILTER" || "$1" == *"$FILTER"* ]]
}

make_fixture() {
  local root="$1"
  mkdir -p "$root/tests/lib" "$root/tests/shell" "$root/.github/workflows" "$root/tests"
  cat > "$root/tests/lib/test-suite-runner.sh" <<'EOF'
SUITE_NAMES=(
  test-alpha
)
declare -A SUITE_PATHS=(
  [test-alpha]="tests/shell/test-alpha.sh"
)
EOF
  printf '#!/usr/bin/env bash\nexit 0\n' > "$root/tests/shell/test-alpha.sh"
  printf '%s\n' 'name: test' 'run: bash tests/shell/test-alpha.sh' > "$root/.github/workflows/lint.yml"
  printf '%s\n' '# test path\treason' > "$root/tests/test-suite-exclusions.tsv"
  printf '%s\n' '# suite\treason' > "$root/tests/ci-suite-exemptions.tsv"
}

run_linter() {
  bash "$LINTER" --repo-root "$1" 2>&1
}

has_output_line() {
  local output="$1" expected="$2"
  grep -Fqx "$expected" <<< "$output"
}

test_real_registry_passes() {
  local name="lint-test-suite-registry/real-registry-passes" output status
  should_run "$name" || return 0
  output="$(run_linter "$REPO_ROOT")"; status=$?
  if [[ "$status" -eq 0 ]]; then pass "$name"; else fail "$name" "status=$status output=$output"; fi
}

test_unregistered_test_file_fails() {
  local name="lint-test-suite-registry/unregistered-test-file-fails" root output status
  should_run "$name" || return 0
  root="$(mktemp -d "$tmp_root/registry-XXXXXX")"; make_fixture "$root"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$root/tests/shell/test-orphan.sh"
  output="$(run_linter "$root")"; status=$?
  if [[ "$status" -ne 0 ]] && has_output_line "$output" 'lint-test-suite-registry: unregistered test file: tests/shell/test-orphan.sh'; then pass "$name"; else fail "$name" "status=$status output=$output"; fi
}

test_missing_ci_coverage_fails_without_exemption() {
  local name="lint-test-suite-registry/missing-ci-coverage-fails" root output status
  should_run "$name" || return 0
  root="$(mktemp -d "$tmp_root/registry-XXXXXX")"; make_fixture "$root"
  printf '%s\n' 'name: test' > "$root/.github/workflows/lint.yml"
  output="$(run_linter "$root")"; status=$?
  if [[ "$status" -ne 0 ]] && has_output_line "$output" 'lint-test-suite-registry: registered suite is absent from CI without exemption: test-alpha (tests/shell/test-alpha.sh)'; then pass "$name"; else fail "$name" "status=$status output=$output"; fi
}

test_ci_comment_does_not_count_as_coverage() {
  local name="lint-test-suite-registry/ci-comment-does-not-count-as-coverage" root output status
  should_run "$name" || return 0
  root="$(mktemp -d "$tmp_root/registry-XXXXXX")"; make_fixture "$root"
  printf '%s\n' '# bash tests/shell/test-alpha.sh' > "$root/.github/workflows/lint.yml"
  output="$(run_linter "$root")"; status=$?
  if [[ "$status" -ne 0 ]] && has_output_line "$output" 'lint-test-suite-registry: registered suite is absent from CI without exemption: test-alpha (tests/shell/test-alpha.sh)'; then pass "$name"; else fail "$name" "status=$status output=$output"; fi
}

test_reasoned_ci_exemption_passes() {
  local name="lint-test-suite-registry/reasoned-ci-exemption-passes" root output status
  should_run "$name" || return 0
  root="$(mktemp -d "$tmp_root/registry-XXXXXX")"; make_fixture "$root"
  printf '%s\n' 'name: test' > "$root/.github/workflows/lint.yml"
  printf '%s\t%s\n' 'test-alpha' 'constraint: CI shard not provisioned; promotion: add a dedicated CI job' >> "$root/tests/ci-suite-exemptions.tsv"
  output="$(run_linter "$root")"; status=$?
  if [[ "$status" -eq 0 ]]; then pass "$name"; else fail "$name" "status=$status output=$output"; fi
}

test_registered_exclusion_fails() {
  local name="lint-test-suite-registry/registered-exclusion-fails" root output status
  should_run "$name" || return 0
  root="$(mktemp -d "$tmp_root/registry-XXXXXX")"; make_fixture "$root"
  printf '%s\t%s\n' 'tests/shell/test-alpha.sh' 'invalid overlap' >> "$root/tests/test-suite-exclusions.tsv"
  output="$(run_linter "$root")"; status=$?
  if [[ "$status" -ne 0 ]] && has_output_line "$output" 'lint-test-suite-registry: test cannot be both registered and excluded: tests/shell/test-alpha.sh'; then pass "$name"; else fail "$name" "status=$status output=$output"; fi
}

test_duplicate_registered_path_fails() {
  local name="lint-test-suite-registry/duplicate-registered-path-fails" root output status
  should_run "$name" || return 0
  root="$(mktemp -d "$tmp_root/registry-XXXXXX")"; make_fixture "$root"
  sed -i 's/test-alpha\n)/test-alpha\n  test-beta\n)/' "$root/tests/lib/test-suite-runner.sh"
  sed -i 's|\[test-alpha\]="tests/shell/test-alpha.sh"|[test-alpha]="tests/shell/test-alpha.sh"\n  [test-beta]="tests/shell/test-alpha.sh"|' "$root/tests/lib/test-suite-runner.sh"
  output="$(run_linter "$root")"; status=$?
  if [[ "$status" -ne 0 ]] && has_output_line "$output" 'lint-test-suite-registry: duplicate registered path: tests/shell/test-alpha.sh'; then pass "$name"; else fail "$name" "status=$status output=$output"; fi
}

test_duplicate_ci_exemption_fails() {
  local name="lint-test-suite-registry/duplicate-ci-exemption-fails" root output status
  should_run "$name" || return 0
  root="$(mktemp -d "$tmp_root/registry-XXXXXX")"; make_fixture "$root"
  printf '%s\t%s\n%s\t%s\n' 'test-alpha' 'constraint: first fixture reason; promotion: first fixture promotion' 'test-alpha' 'constraint: second fixture reason; promotion: second fixture promotion' >> "$root/tests/ci-suite-exemptions.tsv"
  output="$(run_linter "$root")"; status=$?
  if [[ "$status" -ne 0 ]] && has_output_line "$output" 'lint-test-suite-registry: duplicate CI suite exemption: test-alpha'; then pass "$name"; else fail "$name" "status=$status output=$output"; fi
}

test_unreasoned_ci_exemption_fails() {
  local name="lint-test-suite-registry/unreasoned-ci-exemption-fails" root output status
  should_run "$name" || return 0
  root="$(mktemp -d "$tmp_root/registry-XXXXXX")"; make_fixture "$root"
  printf '%s\n' 'name: test' > "$root/.github/workflows/lint.yml"
  printf '%s\t%s\n' 'test-alpha' 'full-runner-only' >> "$root/tests/ci-suite-exemptions.tsv"
  output="$(run_linter "$root")"; status=$?
  if [[ "$status" -ne 0 ]] && has_output_line "$output" 'lint-test-suite-registry: CI suite exemption needs constraint and promotion: test-alpha'; then pass "$name"; else fail "$name" "status=$status output=$output"; fi
}

test_real_registry_passes
test_unregistered_test_file_fails
test_missing_ci_coverage_fails_without_exemption
test_ci_comment_does_not_count_as_coverage
test_reasoned_ci_exemption_passes
test_registered_exclusion_fails
test_duplicate_registered_path_fails
test_duplicate_ci_exemption_fails
test_unreasoned_ci_exemption_fails

th_summary
