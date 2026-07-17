#!/usr/bin/env bash
# Regression tests for canonical ShellCheck domain coverage and ignore ratchets.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LINTER="$REPO_ROOT/tools/lint/lint-shellcheck.sh"

# shellcheck source=tests/lib/test-harness.sh
# Resolved from SCRIPT_DIR at runtime.
# shellcheck disable=SC1091
. "$SCRIPT_DIR/../lib/test-harness.sh"
th_init "$@"

fixture_repo() {
  local name="$1" root
  # shellcheck disable=SC2154  # tmp_root is initialized by th_init.
  root="$tmp_root/$name"
  mkdir -p "$root/tools/lint" "$root/runtime" "$root/tests" "$root/ops" \
    "$root/hosts" "$root/scripts"
  cp "$LINTER" "$root/tools/lint/lint-shellcheck.sh"
  cp "$REPO_ROOT/tools/lint/shellcheck-domains.tsv" "$root/tools/lint/"
  printf 'path\tcodes\treason\n' > "$root/tools/lint/shellcheck-ignores.tsv"
  printf '#!/usr/bin/env bash\nset -euo pipefail\nprintf "ok\\n"\n' > "$root/runtime/pass.sh"
  printf '%s\n' "$root"
}

expect_fail() {
  local name="$1" root="$2" needle="$3" output status=0
  output="$(bash "$root/tools/lint/lint-shellcheck.sh" --repo "$root" 2>&1)" || status=$?
  if [[ "$status" -ne 0 && "$output" == *"$needle"* ]]; then
    pass "$name"
  else
    fail "$name" "status=$status expected=$needle output=$output"
  fi
}

# Behavior: the checked-in inventory covers every canonical implementation and compatibility shim.
# Steps: list the shared linter input; require every migrated shell target and retained shim.
test_moved_path_parity() {
  local name="lint-shellcheck/moved-path-parity" listed path target disposition missing=""
  should_run "$name" || return 0
  listed="$(bash "$LINTER" --list)"
  while IFS=$'\t' read -r path _ _ target disposition _; do
    [[ "$path" != current_path ]] || continue
    if [[ "$target" == *.sh ]] && ! grep -Fxq "$target" <<< "$listed"; then
      missing+="target:$target "
    fi
    if [[ "$disposition" == move-with-shim && "$path" == *.sh ]] \
        && ! grep -Fxq "$path" <<< "$listed"; then
      missing+="shim:$path "
    fi
  done < "$REPO_ROOT/docs/architecture/script-domain-inventory.tsv"
  if [[ -z "$missing" ]]; then
    pass "$name"
  else
    fail "$name" "missing from ShellCheck input: $missing"
  fi
}

# Behavior: a new violation in any canonical domain or the shim domain is checked by default.
# Steps: inject one SC2034 violation under every inventory root; require one run to report all paths.
test_domain_injection_fails() {
  local name="lint-shellcheck/domain-injection-fails" root domain output status=0 missing=""
  should_run "$name" || return 0
  root="$(fixture_repo injection)"
  for domain in runtime tests tools ops hosts scripts; do
    mkdir -p "$root/$domain/nested"
    printf '#!/usr/bin/env bash\nunused_value=1\n' > "$root/$domain/nested/injected.sh"
  done
  output="$(bash "$root/tools/lint/lint-shellcheck.sh" --repo "$root" 2>&1)" || status=$?
  for domain in runtime tests tools ops hosts scripts; do
    [[ "$output" == *"$domain/nested/injected.sh"* ]] || missing+="$domain "
  done
  if [[ "$status" -ne 0 && -z "$missing" ]]; then
    pass "$name"
  else
    fail "$name" "status=$status missing=$missing output=$output"
  fi
}

# Behavior: migration-era basename ignores cannot silently survive after a move.
# Steps: add a nonexistent canonical ignore path; require the stale-path diagnostic.
test_stale_ignore_fails() {
  local name="lint-shellcheck/stale-ignore-fails" root
  should_run "$name" || return 0
  root="$(fixture_repo stale-ignore)"
  printf 'runtime/lib/moved-away.sh\tSC2034\tlegacy-warning\n' >> "$root/tools/lint/shellcheck-ignores.tsv"
  expect_fail "$name" "$root" "stale ignore path does not exist"
}

# Behavior: every explicit exception carries reviewable provenance and applies only to canonical code.
# Steps: add a reasonless row and a compatibility-shim row; require both forms to fail.
test_ignore_contract_fails_closed() {
  local name="lint-shellcheck/ignore-contract-fails-closed" root output status=0
  should_run "$name" || return 0
  root="$(fixture_repo ignore-contract)"
  printf 'runtime/pass.sh\tSC2034\t\n' >> "$root/tools/lint/shellcheck-ignores.tsv"
  output="$(bash "$root/tools/lint/lint-shellcheck.sh" --repo "$root" 2>&1)" || status=$?
  if [[ "$status" -eq 0 || "$output" != *"exact path with codes and one reason"* ]]; then
    fail "$name" "reasonless row was accepted: status=$status output=$output"
    return
  fi
  printf 'path\tcodes\treason\n' > "$root/tools/lint/shellcheck-ignores.tsv"
  printf '#!/usr/bin/env bash\nunused_value=1\n' > "$root/scripts/shim.sh"
  printf 'scripts/shim.sh\tSC2034\tlegacy-warning\n' >> "$root/tools/lint/shellcheck-ignores.tsv"
  expect_fail "$name" "$root" "ignore is not a canonical shell path"
}

# Behavior: a baseline suppresses only named legacy codes, not future findings in that file.
# Steps: suppress SC2034, inject SC2086 in the same path, and require the new code to fail.
test_suppression_is_code_scoped() {
  local name="lint-shellcheck/suppression-is-code-scoped" root
  should_run "$name" || return 0
  root="$(fixture_repo code-scope)"
  printf 'runtime/pass.sh\tSC2034\tlegacy-unused-value\n' >> \
    "$root/tools/lint/shellcheck-ignores.tsv"
  cat > "$root/runtime/pass.sh" <<'SCRIPT'
#!/usr/bin/env bash
value="$*"
echo $value
SCRIPT
  expect_fail "$name" "$root" "SC2086"
}

# Behavior: CI and the local hygiene command delegate to the same ShellCheck executable contract.
# Steps: inspect both operational entrypoints and reject the retired action ignore_names surface.
test_ci_local_entrypoint_parity() {
  local name="lint-shellcheck/ci-local-entrypoint-parity" output status=0
  should_run "$name" || return 0
  output="$(PM_DISPATCH_SHELLCHECK_JOBS=9 \
    bash "$REPO_ROOT/tools/lint/lint-scripts.sh" --hygiene-only 2>&1)" || status=$?
  if [[ "$status" -eq 0 && "$output" != *"lint-shellcheck: OK"* ]] \
      && grep -Fq './tools/lint/lint-shellcheck.sh' "$REPO_ROOT/.github/workflows/lint.yml" \
      && grep -Fq 'tools/lint/lint-shellcheck.sh' "$REPO_ROOT/tools/lint/lint-scripts.sh" \
      && grep -Fq 'run: ./tools/lint/lint-scripts.sh --hygiene-only' "$REPO_ROOT/.github/workflows/lint.yml" \
      && ! grep -Fq 'ignore_names:' "$REPO_ROOT/.github/workflows/lint.yml" \
      && ! grep -Fq 'action-shellcheck' "$REPO_ROOT/.github/workflows/lint.yml"; then
    pass "$name"
  else
    fail "$name" "CI/local ShellCheck entrypoints diverged or legacy action config remains"
  fi
}

# Behavior: explicit concurrency tuning cannot exceed the supported eight-worker ceiling.
# Steps: request nine workers in a fixture and require the range validation to fail before execution.
test_worker_override_ceiling() {
  local name="lint-shellcheck/worker-override-ceiling" root output status=0
  should_run "$name" || return 0
  root="$(fixture_repo worker-ceiling)"
  output="$(PM_DISPATCH_SHELLCHECK_JOBS=9 \
    bash "$root/tools/lint/lint-shellcheck.sh" --repo "$root" 2>&1)" || status=$?
  if [[ "$status" -eq 2 && "$output" == *"integer from 1 to 8"* ]]; then
    pass "$name"
  else
    fail "$name" "status=$status output=$output"
  fi
}

# Behavior: the local linter does not turn host CPU count into unbounded parallelism.
# Steps: use an instrumented ShellCheck stub; assert the default never exceeds two workers.
test_default_worker_cap() {
  local name="lint-shellcheck/default-worker-cap" root events output status=0 max_active
  should_run "$name" || return 0
  root="$(fixture_repo worker-cap)"
  events="$root/events.log"
  mkdir -p "$root/bin"
  for n in 1 2 3 4; do
    printf '#!/usr/bin/env bash\nset -euo pipefail\n' > "$root/tests/worker-$n.sh"
  done
  cat > "$root/bin/shellcheck" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
printf 'start %s\n' "$$" >> "${SHELLCHECK_EVENTS:?}"
sleep 0.1
printf 'end %s\n' "$$" >> "$SHELLCHECK_EVENTS"
STUB
  chmod +x "$root/bin/shellcheck"
  output="$(PATH="$root/bin:$PATH" SHELLCHECK_EVENTS="$events" \
    bash "$root/tools/lint/lint-shellcheck.sh" --repo "$root" 2>&1)" || status=$?
  max_active="$(awk '
    $1 == "start" { active++; if (active > max) max = active }
    $1 == "end" { active-- }
    END { print max + 0 }
  ' "$events")"
  if [[ "$status" -eq 0 && "$max_active" -le 2 && "$max_active" -ge 1 ]]; then
    pass "$name"
  else
    fail "$name" "status=$status max_active=$max_active output=$output"
  fi
}

test_moved_path_parity
test_domain_injection_fails
test_stale_ignore_fails
test_ignore_contract_fails_closed
test_suppression_is_code_scoped
test_ci_local_entrypoint_parity
test_default_worker_cap
test_worker_override_ceiling
th_summary
