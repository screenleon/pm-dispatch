#!/usr/bin/env bash
# Regression tests for the policy-doc GENERATED-block drift checker.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CHECKER="$REPO_ROOT/tools/lint/check-policy-doc-sync.sh"

# shellcheck source=tests/lib/test-harness.sh
# shellcheck disable=SC1091
. "$SCRIPT_DIR/../lib/test-harness.sh"
th_init "$@"

# A minimal git-tracked fixture: one doc with two GENERATED blocks (one TSV
# source, one the reviewer-policy.yaml special case) plus their sources.
# Tests mutate copies of these files in place -- git ls-files still finds
# them (tracked, not staged-clean) without needing a re-commit per case.
fixture_repo() {
  local name="$1" root
  # shellcheck disable=SC2154  # tmp_root is initialized by th_init.
  root="$tmp_root/$name"
  mkdir -p "$root/docs" "$root/core/policy"
  git -C "$root" init -q
  printf 'tier\tdefault_reviewers\n' > "$root/core/policy/gate-tiers.tsv"
  printf 'express\tcritic,qa-tester\n' >> "$root/core/policy/gate-tiers.tsv"
  printf 'standard\tcritic,qa-tester,architecture-reviewer\n' >> "$root/core/policy/gate-tiers.tsv"
  cat > "$root/core/policy/reviewer-policy.yaml" <<'YAML'
reviewers:
  critic:
    kind: advisory
    phase: all
  qa-tester:
    kind: hard-gate
    phase: test-phase
verdicts:
  - approve
  - block
YAML
  cat > "$root/docs/map.md" <<'DOC'
# Map

<!-- BEGIN GENERATED: core/policy/gate-tiers.tsv -->
| tier | default_reviewers |
|---|---|
| express | critic,qa-tester |
| standard | critic,qa-tester,architecture-reviewer |
<!-- END GENERATED -->

<!-- BEGIN GENERATED: core/policy/reviewer-policy.yaml -->
| reviewer | kind | phase |
|---|---|---|
| critic | advisory | all |
| qa-tester | hard-gate | test-phase |

| verdict |
|---|
| approve |
| block |
<!-- END GENERATED -->
DOC
  ( cd "$root" && git add -A && git -c user.email=t@t -c user.name=t commit -q -m fixture )
  printf '%s\n' "$root"
}

# Run the checker against a fixture root, capturing stdout+stderr and exit
# status into $output/$status for the assert_* helpers below.
run_checker() {
  output="$(bash "$CHECKER" --repo-root "$1" 2>&1)"
  status=$?
}

# Assert the checker exits 0 and its output contains $3 (used for the
# clean-pass and no-op-mutation cases).
assert_ok() {
  local name="$1" root="$2" needle="$3"
  run_checker "$root"
  if [[ "$status" -eq 0 && "$output" == *"$needle"* ]]; then
    pass "$name"
  else
    fail "$name" "status=$status output=$output"
  fi
}

# Assert the checker exits non-zero and its output contains $3 (used for
# every drift/malformed-input detection case).
assert_drift() {
  local name="$1" root="$2" needle="$3"
  run_checker "$root"
  if [[ "$status" -ne 0 && "$output" == *"$needle"* ]]; then
    pass "$name"
  else
    fail "$name" "status=$status output=$output"
  fi
}

# Behavior: a clean fixture with matching TSV and YAML GENERATED blocks passes.
test_clean_fixture_passes() {
  local name="check-policy-doc-sync/clean-fixture-passes" root output status
  should_run "$name" || return 0
  root="$(fixture_repo clean)"
  assert_ok "$name" "$root" "OK ("
}

# Behavior: a mutated doc-side TSV table row is detected as drift.
test_doc_side_tsv_mutation_detected() {
  local name="check-policy-doc-sync/doc-side-tsv-mutation-detected" root output status
  should_run "$name" || return 0
  root="$(fixture_repo doc-tsv-mutation)"
  sed -i.bak 's/| express | critic,qa-tester |/| express | MUTATED |/' "$root/docs/map.md"
  assert_drift "$name" "$root" "drift"
}

# Behavior: a mutated source-side TSV row is detected from the other
# direction (not just doc-side edits).
test_source_side_tsv_mutation_detected() {
  local name="check-policy-doc-sync/source-side-tsv-mutation-detected" root output status
  should_run "$name" || return 0
  root="$(fixture_repo source-tsv-mutation)"
  sed -i.bak 's/^express\t/express-mutated\t/' "$root/core/policy/gate-tiers.tsv"
  assert_drift "$name" "$root" "drift"
}

# Behavior: a TSV value containing a literal "|" (e.g. a regex-alternation
# pattern) must not be misparsed as an extra table column -- the checker
# renders and compares whole lines instead of splitting the doc's cells.
test_tsv_value_with_literal_pipe_not_misparsed() {
  local name="check-policy-doc-sync/tsv-value-with-literal-pipe-not-misparsed" root output status
  should_run "$name" || return 0
  root="$(fixture_repo literal-pipe)"
  printf 'binary-change\t(^|/)(bin|assets)(/|$)\n' >> "$root/core/policy/gate-tiers.tsv"
  # Insert the matching doc row right after the existing tiers table's last row.
  awk '
    { print }
    /^\| standard \| critic,qa-tester,architecture-reviewer \|$/ && !done {
      print "| binary-change | (^|/)(bin|assets)(/|$) |"
      done = 1
    }
  ' "$root/docs/map.md" > "$root/docs/map.md.new"
  mv "$root/docs/map.md.new" "$root/docs/map.md"
  assert_ok "$name" "$root" "OK ("
}

# Behavior: a mutated reviewer kind/phase value in the YAML special-case
# table is detected.
test_yaml_reviewer_table_mutation_detected() {
  local name="check-policy-doc-sync/yaml-reviewer-table-mutation-detected" root output status
  should_run "$name" || return 0
  root="$(fixture_repo yaml-reviewer-mutation)"
  sed -i.bak 's/kind: advisory/kind: MUTATED/' "$root/core/policy/reviewer-policy.yaml"
  assert_drift "$name" "$root" "reviewer table"
}

# Behavior: a mutated verdict list entry in the YAML special-case table is
# detected independently of the reviewer table.
test_yaml_verdict_list_mutation_detected() {
  local name="check-policy-doc-sync/yaml-verdict-list-mutation-detected" root output status
  should_run "$name" || return 0
  root="$(fixture_repo yaml-verdict-mutation)"
  sed -i.bak 's/^  - approve$/  - MUTATED/' "$root/core/policy/reviewer-policy.yaml"
  assert_drift "$name" "$root" "verdict table"
}

# Behavior: a GENERATED block whose named source file does not exist fails
# loudly, rather than being silently skipped or crashing uninformatively.
test_missing_source_fails_loudly() {
  local name="check-policy-doc-sync/missing-source-fails-loudly" root output status
  should_run "$name" || return 0
  root="$(fixture_repo missing-source)"
  sed -i.bak 's#core/policy/gate-tiers.tsv#core/policy/does-not-exist.tsv#g' "$root/docs/map.md"
  assert_drift "$name" "$root" "missing source: core/policy/does-not-exist.tsv"
}

# Behavior: an unclosed BEGIN GENERATED marker (no matching END) fails
# loudly instead of silently treating the rest of the file as the block.
test_unmatched_marker_fails_loudly() {
  local name="check-policy-doc-sync/unmatched-marker-fails-loudly" root output status
  should_run "$name" || return 0
  root="$(fixture_repo unmatched-marker)"
  # Delete the LAST END marker line, leaving its BEGIN unclosed at EOF with
  # no following BEGIN -- deleting the first END instead would leave that
  # BEGIN open when the fixture's second BEGIN is reached, which is the
  # (also rejected, separately tested) nested-marker case, not this one.
  awk '
    /<!-- END GENERATED -->/ { last_end = NR }
    { lines[NR] = $0 }
    END {
      for (i = 1; i <= NR; i++) if (i != last_end) print lines[i]
    }
  ' "$root/docs/map.md" > "$root/docs/map.md.new"
  mv "$root/docs/map.md.new" "$root/docs/map.md"
  assert_drift "$name" "$root" "unmatched BEGIN/END GENERATED marker pair"
}

# Behavior: a stray END GENERATED marker with no preceding BEGIN also fails
# loudly, not just the unclosed-BEGIN direction.
test_stray_end_marker_fails_loudly() {
  local name="check-policy-doc-sync/stray-end-marker-fails-loudly" root output status
  should_run "$name" || return 0
  root="$(fixture_repo stray-end-marker)"
  printf '\n<!-- END GENERATED -->\n' >> "$root/docs/map.md"
  assert_drift "$name" "$root" "unmatched BEGIN/END GENERATED marker pair"
}

# Behavior: a BEGIN GENERATED marker opened while a block is already open
# fails loudly instead of silently overwriting the outer block's own
# source/start and leaving it unverified (a gate reviewer's concrete
# concern: a false pass here defeats the whole drift-detection property).
test_nested_marker_fails_loudly() {
  local name="check-policy-doc-sync/nested-marker-fails-loudly" root output status
  should_run "$name" || return 0
  root="$(fixture_repo nested-marker)"
  cat > "$root/docs/map.md" <<'DOC'
# Map

<!-- BEGIN GENERATED: core/policy/gate-tiers.tsv -->
| tier | default_reviewers |
|---|---|
<!-- BEGIN GENERATED: core/policy/reviewer-policy.yaml -->
| express | critic,qa-tester |
| standard | critic,qa-tester,architecture-reviewer |
<!-- END GENERATED -->
<!-- END GENERATED -->
DOC
  assert_drift "$name" "$root" "nested BEGIN GENERATED markers are not supported"
}

# Behavior: a symlinked source path is refused outright rather than
# followed -- the marker's source text is attacker-controlled (it comes
# from whatever a PR writes inside the doc), so it must not be trusted to
# stay inside the repository.
test_symlinked_source_refused() {
  local name="check-policy-doc-sync/symlinked-source-refused" root output status
  should_run "$name" || return 0
  root="$(fixture_repo symlinked-source)"
  printf 'outside content\n' > "$tmp_root/outside-target.tsv"
  rm -f "$root/core/policy/gate-tiers.tsv"
  ln -s "$tmp_root/outside-target.tsv" "$root/core/policy/gate-tiers.tsv"
  assert_drift "$name" "$root" "is a symlink, refusing to follow: core/policy/gate-tiers.tsv"
}

# Behavior: a GENERATED block containing a non-table line (injected prose or
# markup alongside otherwise-correct table rows) fails loudly instead of
# silently passing because the table rows it did check happened to match.
test_stray_non_table_content_fails_loudly() {
  local name="check-policy-doc-sync/stray-non-table-content-fails-loudly" root output status
  should_run "$name" || return 0
  root="$(fixture_repo stray-non-table-content)"
  sed -i.bak '/^| express | critic,qa-tester |$/a\
Injected prose that is not a table row.' "$root/docs/map.md"
  assert_drift "$name" "$root" "contains non-table content"
}

# Behavior: a GENERATED block naming a source type with no registered
# comparator fails explicitly instead of passing vacuously.
test_unsupported_source_type_fails_loudly() {
  local name="check-policy-doc-sync/unsupported-source-type-fails-loudly" root output status
  should_run "$name" || return 0
  root="$(fixture_repo unsupported-source-type)"
  printf '{}\n' > "$root/core/policy/unsupported.json"
  ( cd "$root" && git add core/policy/unsupported.json && git -c user.email=t@t -c user.name=t commit -q -m fixture2 )
  cat >> "$root/docs/map.md" <<'DOC'

<!-- BEGIN GENERATED: core/policy/unsupported.json -->
| x |
|---|
| y |
<!-- END GENERATED -->
DOC
  assert_drift "$name" "$root" "no comparator registered for source type: core/policy/unsupported.json"
}

# Behavior: a brand-new GENERATED block in a brand-new doc file is checked
# without any change to the checker itself -- this dynamic discovery is
# what makes the check a ratchet rather than a fixed one-time audit.
test_new_block_in_new_file_discovered_without_checker_change() {
  local name="check-policy-doc-sync/new-block-in-new-file-discovered" root output status
  should_run "$name" || return 0
  root="$(fixture_repo new-file-discovery)"
  cat > "$root/docs/another.md" <<'DOC'
# Another doc

<!-- BEGIN GENERATED: core/policy/does-not-exist-either.tsv -->
| a |
|---|
| b |
<!-- END GENERATED -->
DOC
  ( cd "$root" && git add docs/another.md && git -c user.email=t@t -c user.name=t commit -q -m fixture3 )
  assert_drift "$name" "$root" "another.md"
}

# Behavior: a brand-new doc file with a bad GENERATED block is still caught
# even before it has ever been `git add`ed -- the checker's own "no
# separate registration step" claim would otherwise be false for a
# contributor who lints before staging.
test_new_block_in_untracked_file_discovered() {
  local name="check-policy-doc-sync/new-block-in-untracked-file-discovered" root output status
  should_run "$name" || return 0
  root="$(fixture_repo untracked-file-discovery)"
  cat > "$root/docs/untracked.md" <<'DOC'
# Untracked doc

<!-- BEGIN GENERATED: core/policy/does-not-exist-untracked.tsv -->
| a |
|---|
| b |
<!-- END GENERATED -->
DOC
  # Deliberately not `git add`ed.
  assert_drift "$name" "$root" "untracked.md"
}

test_clean_fixture_passes
test_doc_side_tsv_mutation_detected
test_source_side_tsv_mutation_detected
test_tsv_value_with_literal_pipe_not_misparsed
test_yaml_reviewer_table_mutation_detected
test_yaml_verdict_list_mutation_detected
test_missing_source_fails_loudly
test_unmatched_marker_fails_loudly
test_stray_end_marker_fails_loudly
test_nested_marker_fails_loudly
test_symlinked_source_refused
test_stray_non_table_content_fails_loudly
test_unsupported_source_type_fails_loudly
test_new_block_in_new_file_discovered_without_checker_change
test_new_block_in_untracked_file_discovered

th_summary
