#!/usr/bin/env bash
# Fixture environment isolation.
#
# A test that asserts a DEFAULT must run its subject with that default's
# override cleared. Inheriting the caller's environment silently changes what
# the test measures, and the failure then reads as "the default was violated"
# about a subject that was never at its default.
#
# The set comes from the canonical variable inventory's `fixture_scrub` column,
# not from a list kept here. A list kept next to the tests only grows after
# someone is bitten, so it is permanently one incident behind -- which is how
# this class recurred three times before the isolation became enforced.
#
# Usage: . tests/lib/test-env-isolation.sh; test_env_scrub_fixture_inputs "$REPO_ROOT"

# Clear every inventory-declared fixture input from the current environment.
# Fails closed: an unreadable inventory or an empty declared set would leave a
# suite believing it is isolated when it is not, which is the exact failure
# mode this function exists to remove.
test_env_scrub_fixture_inputs() {
  local repo_root="${1:?repo root required}"
  local inventory="$repo_root/docs/architecture/script-variable-inventory.tsv"
  local name prefix candidate declared=0

  [[ -r "$inventory" ]] || {
    printf 'test-env-isolation: canonical variable inventory is unreadable: %s\n' \
      "$inventory" >&2
    return 1
  }

  while IFS= read -r name; do
    [[ -n "$name" ]] || continue
    declared=$((declared + 1))
    if [[ "$name" == *'*' ]]; then
      # A pattern row covers a family of names sharing a prefix. Unsetting the
      # literal name with the asterisk would clear nothing and report success,
      # so expand it against what is actually set. Naming an example family
      # here would create a false consumer edge in the variable graph.
      prefix="${name%\*}"
      while IFS= read -r candidate; do
        [[ -n "$candidate" ]] || continue
        unset "$candidate"
      done < <(compgen -v | grep -E "^${prefix}" || true)
    else
      unset "$name"
    fi
  done < <(awk -F '\t' 'NR > 1 && $9 == "yes" { print $1 }' "$inventory")

  (( declared > 0 )) || {
    printf 'test-env-isolation: inventory declares no fixture_scrub entries; refusing to report isolation that was never applied\n' >&2
    return 1
  }
}

# Print the declared fixture-input names, one per line. Exposed so a ratchet
# can assert against the same source the scrub uses rather than restating it.
test_env_fixture_input_names() {
  local repo_root="${1:?repo root required}"
  local inventory="$repo_root/docs/architecture/script-variable-inventory.tsv"
  [[ -r "$inventory" ]] || return 1
  awk -F '\t' 'NR > 1 && $9 == "yes" { print $1 }' "$inventory"
}
