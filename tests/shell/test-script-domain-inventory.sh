#!/usr/bin/env bash
# Regression tests for the script-domain inventory ratchet.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LINTER="$REPO_ROOT/tools/lint/lint-script-domain-inventory.sh"
# shellcheck source=tests/lib/test-harness.sh
# Resolved from SCRIPT_DIR at runtime.
# shellcheck disable=SC1091
. "$SCRIPT_DIR/../lib/test-harness.sh"
th_init "$@"

fixture_repo() {
  local root
  # Initialized by th_init in test-harness.sh.
  # shellcheck disable=SC2154
  root="$(mktemp -d "$tmp_root/script-domain-inventory-XXXXXX")"
  mkdir -p "$root/docs/architecture" "$root/scripts"
  cp "$REPO_ROOT/docs/architecture/script-domain-ownership.md" "$root/docs/architecture/"
  cp "$REPO_ROOT/docs/architecture/script-domain-inventory.tsv" "$root/docs/architecture/"
  cp "$REPO_ROOT/docs/architecture/script-variable-inventory.tsv" "$root/docs/architecture/"
  cp "$REPO_ROOT/docs/architecture/script-variable-consumers.tsv" "$root/docs/architecture/"
  cp "$REPO_ROOT/docs/architecture/script-domain-reference-allowlist.tsv" "$root/docs/architecture/"
  : > "$root/README.md"
  mkdir -p "$root/core"
  : > "$root/core/README.md"
  : > "$root/BACKLOG.md"
  : > "$root/MILESTONES.md"
  while IFS=$'\t' read -r current_path _ _ target_path disposition _; do
    [[ "$current_path" == "current_path" ]] && continue
    mkdir -p "$root/$(dirname "$target_path")"
    : > "$root/$target_path"
    if [[ "$disposition" == "move-with-shim" ]]; then
      mkdir -p "$root/$(dirname "$current_path")"
      printf '#!/usr/bin/env bash\n# forwards to %s\n' "$target_path" > "$root/$current_path"
      chmod +x "$root/$current_path"
    fi
  done < "$root/docs/architecture/script-domain-inventory.tsv"
  while IFS=$'\t' read -r _ _ consumer_path _; do
    [[ "$consumer_path" == "consumer_path" ]] && continue
    mkdir -p "$root/$(dirname "$consumer_path")"
    [[ -e "$root/$consumer_path" ]] || : > "$root/$consumer_path"
  done < "$root/docs/architecture/script-variable-consumers.tsv"
  # Seed the declared static variable graph so pass fixtures exercise only the
  # path-reference mutation introduced by each case.
  while IFS=$'\t' read -r _ actual_name consumer_path _; do
    [[ "$actual_name" == "actual_name" ]] && continue
    printf '\n# %s\n' "$actual_name" >> "$root/$consumer_path"
  done < "$root/docs/architecture/script-variable-consumers.tsv"
  printf '%s\n' "$root"
}

expect_pass() {
  local name="$1" root="$2" output status
  output="$(bash "$LINTER" --repo "$root" 2>&1)"; status=$?
  if [[ "$status" -eq 0 ]]; then
    pass "$name"
  else
    fail "$name" "expected pass, status=$status output=$output"
  fi
}

expect_fail() {
  local name="$1" root="$2" needle="$3" output status
  output="$(bash "$LINTER" --repo "$root" 2>&1)"; status=$?
  if [[ "$status" -ne 0 && "$output" == *"$needle"* ]]; then
    pass "$name"
  else
    fail "$name" "expected failure containing '$needle', status=$status output=$output"
  fi
}

# Behavior: the checked-in path, variable, consumer, and architecture artifacts agree.
# Steps: run the inventory linter against the real repository and require success.
test_real_repository_passes() {
  local name="script-domain-inventory/real-repository-passes"
  should_run "$name" || return 0
  expect_pass "$name" "$REPO_ROOT"
}

# Behavior: an untracked file under scripts is rejected by the inventory ratchet.
# Steps: build a complete fixture, add one extra script, and assert the file-set diagnostic.
test_untracked_script_fails() {
  local name="script-domain-inventory/untracked-script-fails" root
  should_run "$name" || return 0
  root="$(fixture_repo)"
  : > "$root/scripts/new-untracked.sh"
  expect_fail "$name" "$root" "compatibility file set differs"
}

# Behavior: a declared migrated target that no longer exists is rejected.
# Steps: build a complete fixture, remove one migrated file, and assert the target diagnostic.
test_missing_script_fails() {
  local name="script-domain-inventory/missing-script-fails" root
  should_run "$name" || return 0
  root="$(fixture_repo)"
  rm -f "$root/runtime/bin/brief-validate.sh"
  expect_fail "$name" "$root" "missing migrated target: runtime/bin/brief-validate.sh"
}

# Behavior: owner domains cannot point at a target root owned by another layer.
# Steps: change one shared-runtime target to a host path and assert the owner-target diagnostic.
test_owner_target_mismatch_fails() {
  local name="script-domain-inventory/owner-target-mismatch-fails" root file
  should_run "$name" || return 0
  root="$(fixture_repo)"
  file="$root/docs/architecture/script-domain-inventory.tsv"
  sed -i 's#runtime/bin/brief-validate.sh#hosts/codex/bin/brief-validate.sh#' "$file"
  expect_fail "$name" "$root" "shared runtime target mismatch"
}

# Behavior: every stable or compatibility path requires a forwarding shim disposition.
# Steps: remove the shim disposition from an installed path and assert the stability diagnostic.
test_stable_path_without_shim_fails() {
  local name="script-domain-inventory/stable-path-without-shim-fails" root file
  should_run "$name" || return 0
  root="$(fixture_repo)"
  file="$root/docs/architecture/script-domain-inventory.tsv"
  sed -i '/scripts\/doctor.sh/s/move-with-shim/move-then-remove/' "$file"
  expect_fail "$name" "$root" "stable path lacks shim"
}

# Behavior: a compatibility file must name the exact owner target declared by
# its inventory row; mere file existence is not sufficient.
# Steps: replace one seeded shim target with a different owner path and assert
# the target-mismatch diagnostic.
test_compatibility_shim_target_mismatch_fails() {
  local name="script-domain-inventory/compatibility-shim-target-mismatch-fails" root
  should_run "$name" || return 0
  root="$(fixture_repo)"
  sed -i 's#runtime/bin/doctor.sh#runtime/bin/pr-gate.sh#' "$root/scripts/doctor.sh"
  expect_fail "$name" "$root" "compatibility shim target mismatch"
}

# Behavior: every variable declaration has at least one static consumer reference.
# Steps: remove all rows for one declaration and assert the no-consumer diagnostic.
test_variable_without_consumer_fails() {
  local name="script-domain-inventory/variable-without-consumer-fails" root file
  should_run "$name" || return 0
  root="$(fixture_repo)"
  file="$root/docs/architecture/script-variable-consumers.tsv"
  sed -i '/^PMCTL_BIN_DIR\t/d' "$file"
  expect_fail "$name" "$root" "variable has no consumer reference: PMCTL_BIN_DIR"
}

# Behavior: an exact variable declaration cannot point at a different actual variable.
# Steps: corrupt one consumer row and assert the exact-name diagnostic.
test_exact_variable_mismatch_fails() {
  local name="script-domain-inventory/exact-variable-mismatch-fails" root file
  should_run "$name" || return 0
  root="$(fixture_repo)"
  file="$root/docs/architecture/script-variable-consumers.tsv"
  sed -i '0,/^HOME\tHOME\t/s//HOME\tPATH\t/' "$file"
  expect_fail "$name" "$root" "exact variable mismatch"
}

# Behavior: the checked-in consumer graph cannot omit a real static reference.
# Steps: remove one of several HOME references and assert the graph-freshness diagnostic.
test_stale_consumer_graph_fails() {
  local name="script-domain-inventory/stale-consumer-graph-fails" root file
  should_run "$name" || return 0
  root="$(fixture_repo)"
  file="$root/docs/architecture/script-variable-consumers.tsv"
  sed -i '/^HOME\tHOME\tinstall.sh\tproduction$/d' "$file"
  expect_fail "$name" "$root" "variable consumer graph is stale"
}

# Behavior: a repository path containing shell metacharacters is handled as data.
# Steps: move a fixture under a hostile quoted path, run the linter, and prove no marker executes.
test_repository_path_metacharacters_are_safe() {
  local name="script-domain-inventory/repository-path-metacharacters-are-safe"
  local root hostile_root marker output status=0
  should_run "$name" || return 0
  root="$(fixture_repo)"
  marker="$tmp_root/injection-marker"
  hostile_root="$tmp_root/repo-\"; touch injection-marker; #"
  if ! mv "$root" "$hostile_root"; then
    fail "$name" "could not construct hostile repository path"
    return 0
  fi
  output="$(cd "$tmp_root" && bash "$LINTER" --repo "$hostile_root" 2>&1)" || status=$?
  if [[ "$status" -eq 0 && ! -e "$marker" ]]; then
    pass "$name"
  else
    fail "$name" "hostile repository path was rejected or executed shell syntax, status=$status output=$output"
  fi
}

# Behavior: operational architecture inventory cannot carry a concrete ticket identifier.
# Steps: construct a ticket-like identifier in the fixture document and assert rejection.
test_ticket_identifier_fails() {
  local name="script-domain-inventory/ticket-identifier-fails" root
  should_run "$name" || return 0
  root="$(fixture_repo)"
  printf '\n%s%s\n' 'CC' '-999' >> "$root/docs/architecture/script-domain-ownership.md"
  expect_fail "$name" "$root" "contains a ticket identifier"
}

# Behavior: a retired implementation path cannot return to current operational documentation.
# Steps: inject a scripts/lib path from the inventory into README and assert the canonical-path diagnostic.
test_stale_operational_reference_fails() {
  local name="script-domain-inventory/stale-operational-reference-fails" root
  should_run "$name" || return 0
  root="$(fixture_repo)"
  printf 'Run scripts/lib/state-writer.sh directly.\n' >> "$root/README.md"
  expect_fail "$name" "$root" "stale scripts/lib/state-writer.sh (use runtime/lib/state-writer.sh)"
}

# Behavior: historical migration evidence may preserve the path that existed at the time.
# Steps: put a retired path under docs/spikes and require the complete inventory lint to pass.
test_historical_reference_passes() {
  local name="script-domain-inventory/historical-reference-passes" root
  should_run "$name" || return 0
  root="$(fixture_repo)"
  mkdir -p "$root/docs/spikes"
  printf 'Historical location: scripts/lib/state-writer.sh\n' > "$root/docs/spikes/history.md"
  expect_pass "$name" "$root"
}

# Behavior: completed milestone phases and released versions preserve the path
# wording that was true when they shipped.
# Steps: place retired paths in both historical milestone shapes and require
# the current-reference ratchet to ignore them.
test_completed_milestone_history_passes() {
  local name="script-domain-inventory/completed-milestone-history-passes" root
  should_run "$name" || return 0
  root="$(fixture_repo)"
  printf '%s\n' \
    '## v0.9.0 — current' \
    '### Phase 1 — delivered（✅ 已交付）' \
    '- shipped from scripts/lib/state-writer.sh' \
    '### Phase 2 — planned' \
    '- planned canonical path: runtime/lib/state-writer.sh' \
    '## v0.8.0 — previous（✅ released 2026-07-04）' \
    '- shipped from scripts/lib/state-writer.sh' > "$root/MILESTONES.md"
  expect_pass "$name" "$root"
}

# Behavior: an unimplemented milestone section must use the canonical owner path.
# Steps: put a retired path in a planned phase and assert the milestone diagnostic.
test_unimplemented_milestone_reference_fails() {
  local name="script-domain-inventory/unimplemented-milestone-reference-fails" root
  should_run "$name" || return 0
  root="$(fixture_repo)"
  printf '%s\n' \
    '## v0.9.0 — current' \
    '### Phase 1 — planned' \
    '- implement scripts/lib/state-writer.sh' > "$root/MILESTONES.md"
  expect_fail "$name" "$root" "MILESTONES.md:3: stale scripts/lib/state-writer.sh"
}

# Behavior: the installed ~/.claude helper path is a stable external ABI, not a repository implementation path.
# Steps: document an installed helper path in README and require no stale-reference false positive.
test_installed_helper_reference_passes() {
  local name="script-domain-inventory/installed-helper-reference-passes" root
  should_run "$name" || return 0
  root="$(fixture_repo)"
  printf 'Run bash ~/.claude/scripts/doctor.sh after installation.\n' >> "$root/README.md"
  expect_pass "$name" "$root"
}

# Behavior: a retired implementation path in production code needs an explicit compatibility contract.
# Steps: inject an unallowlisted scripts/lib reference into a runtime file and assert rejection.
test_unallowlisted_production_reference_fails() {
  local name="script-domain-inventory/unallowlisted-production-reference-fails" root
  should_run "$name" || return 0
  root="$(fixture_repo)"
  printf '\n# loads scripts/lib/state-writer.sh\n' >> "$root/runtime/bin/brief-validate.sh"
  expect_fail "$name" "$root" "stale scripts/lib/state-writer.sh (use runtime/lib/state-writer.sh)"
}

# Behavior: every declared legacy-config exception remains accepted in its exact consumer.
# Steps: add both allowlisted historical paths to the Codex installer fixture and require success.
test_allowlisted_legacy_references_pass() {
  local name="script-domain-inventory/allowlisted-legacy-references-pass" root
  should_run "$name" || return 0
  root="$(fixture_repo)"
  printf '\n# detects scripts/guard-inject-memory.sh\n# detects scripts/guard-session-summary.sh\n' \
    >> "$root/hosts/codex/bin/install.sh"
  expect_pass "$name" "$root"
}

# Behavior: a legacy-config exception is scoped to its declared consumer, not path-only.
# Steps: inject each allowlisted historical path into another production file and require rejection.
test_allowlist_consumer_boundary_fails() {
  local name="script-domain-inventory/allowlist-consumer-boundary-fails"
  local old_path target_path root index=0
  should_run "$name" || return 0
  while IFS=$'\t' read -r old_path _ _ target_path _ _; do
    case "$old_path" in
      scripts/guard-inject-memory.sh|scripts/guard-session-summary.sh) ;;
      *) continue ;;
    esac
    index=$((index + 1))
    root="$(fixture_repo)"
    printf '\n# detects %s\n' "$old_path" >> "$root/runtime/bin/brief-validate.sh"
    expect_fail "$name/$index" "$root" "stale $old_path (use $target_path)"
  done < "$REPO_ROOT/docs/architecture/script-domain-inventory.tsv"
}

# Behavior: every reference-allowlist schema and integrity branch fails with its own diagnostic.
# Steps: mutate one TSV contract rule per fresh fixture and assert the corresponding error.
test_reference_allowlist_validation_fails() {
  local name="script-domain-inventory/reference-allowlist-validation-fails"
  local root file
  should_run "$name" || return 0

  root="$(fixture_repo)"; file="$root/docs/architecture/script-domain-reference-allowlist.tsv"
  printf 'scripts/unknown.sh\truntime/bin/brief-validate.sh\n' >> "$file"
  expect_fail "$name/malformed-fields" "$root" "has 2 fields"

  root="$(fixture_repo)"; file="$root/docs/architecture/script-domain-reference-allowlist.tsv"
  printf 'scripts/unknown.sh\truntime/bin/brief-validate.sh\tlegacy-detection\n' >> "$file"
  expect_fail "$name/unknown-path" "$root" "path is absent from migration inventory: scripts/unknown.sh"

  root="$(fixture_repo)"; file="$root/docs/architecture/script-domain-reference-allowlist.tsv"
  printf 'scripts/doctor.sh\truntime/bin/brief-validate.sh\tlegacy-detection\n' >> "$file"
  expect_fail "$name/shim-path" "$root" "allowlist is unnecessary for shim path: scripts/doctor.sh"

  root="$(fixture_repo)"; file="$root/docs/architecture/script-domain-reference-allowlist.tsv"
  printf 'scripts/guard-inject-memory.sh\t../escape.sh\tlegacy-detection\n' >> "$file"
  expect_fail "$name/unsafe-consumer" "$root" "unsafe consumer path: ../escape.sh"

  root="$(fixture_repo)"; file="$root/docs/architecture/script-domain-reference-allowlist.tsv"
  printf 'scripts/guard-inject-memory.sh\truntime/bin/brief-validate.sh\tBad reason\n' >> "$file"
  expect_fail "$name/invalid-reason" "$root" "invalid reason slug: Bad reason"

  root="$(fixture_repo)"; file="$root/docs/architecture/script-domain-reference-allowlist.tsv"
  sed -n '2p' "$file" >> "$file"
  expect_fail "$name/duplicate-row" "$root" "duplicate stale-reference allowlist rows"

  root="$(fixture_repo)"; file="$root/docs/architecture/script-domain-reference-allowlist.tsv"
  printf 'scripts/guard-inject-memory.sh\truntime/missing.sh\tlegacy-detection\n' >> "$file"
  expect_fail "$name/missing-consumer" "$root" "missing stale-reference allowlist consumer: runtime/missing.sh"
}

# Behavior: all newly scanned production roots reject retired implementation references.
# Steps: inject the same stale internal path into GitHub workflow, ops, and tools files.
test_production_root_stale_references_fail() {
  local name="script-domain-inventory/production-root-stale-references-fail"
  local root surface index=0
  should_run "$name" || return 0
  for surface in \
    .github/workflows/lint.yml \
    ops/backlog/archive-closed-backlog.sh \
    tools/lint/lint-agents.sh; do
    index=$((index + 1))
    root="$(fixture_repo)"
    mkdir -p "$root/$(dirname "$surface")"
    printf '\n# loads scripts/lib/state-writer.sh\n' >> "$root/$surface"
    expect_fail "$name/$index" "$root" "stale scripts/lib/state-writer.sh (use runtime/lib/state-writer.sh)"
  done
}

test_real_repository_passes
test_untracked_script_fails
test_missing_script_fails
test_owner_target_mismatch_fails
test_stable_path_without_shim_fails
test_compatibility_shim_target_mismatch_fails
test_variable_without_consumer_fails
test_exact_variable_mismatch_fails
test_stale_consumer_graph_fails
test_repository_path_metacharacters_are_safe
test_ticket_identifier_fails
test_stale_operational_reference_fails
test_historical_reference_passes
test_completed_milestone_history_passes
test_unimplemented_milestone_reference_fails
test_installed_helper_reference_passes
test_unallowlisted_production_reference_fails
test_allowlisted_legacy_references_pass
test_allowlist_consumer_boundary_fails
test_reference_allowlist_validation_fails
test_production_root_stale_references_fail

th_summary
