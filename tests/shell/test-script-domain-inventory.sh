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
  if [[ ! -e "$marker" ]]; then
    pass "$name"
  else
    fail "$name" "repository path executed shell syntax, status=$status output=$output"
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

th_summary
