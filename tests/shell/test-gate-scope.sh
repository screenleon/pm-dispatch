#!/usr/bin/env bash
# Regression tests for _gate_scope_paired_tests_collect in runtime/lib/gate-scope.sh
# -- the language-convention "adjacent test file" detector that feeds the
# "adjacent test files added: N" brief line.
#
# These permutations used to run as end-to-end cases in test-pr-gate.sh, each
# spawning a real pr-gate.sh (~8s) just to observe one detected pair in the
# composed brief. The detector is a pure function: given a JSON array of changed
# paths plus files on disk under $WORK_DIR, it emits the {source_path,test_path,
# reason} pairs. That belongs at ~0.1s/case. No production change -- gate-scope.sh
# is only sourced and called.
#
# The de-duplication behaviour ("a test file already in the diff is not
# re-reported as adjacent") lives in pr-gate.sh's manifest jq, NOT in this
# function, so it stays end-to-end. test-pr-gate.sh keeps two wiring guards:
# test_adjacent_go_test_included (a detected pair reaches the brief text + the
# stdout count) and test_adjacent_test_not_duplicated_when_in_diff (the dedup
# filter).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=tests/lib/test-harness.sh
# shellcheck disable=SC1091
. "$SCRIPT_DIR/../lib/test-harness.sh"
th_init "$@"

# shellcheck source=runtime/lib/gate-scope.sh
# shellcheck disable=SC1091
. "$REPO_ROOT/runtime/lib/gate-scope.sh"

# _gate_scope_path_exists reads these in the non-fixed-head branch (the working
# -tree path this suite exercises). Same shell -- no export needed; the reads are
# inside the sourced function, so ShellCheck flags the assignments as unused
# (see shellcheck-ignores.tsv).
POLICY_DIFF_KIND="working-tree"
WORK_DIR=""

# _scope_tree <slug> [file ...]
# Create $tmp_root/<slug> as an on-disk work tree containing each listed file
# (parent dirs auto-created, one-line stub content). Points $WORK_DIR at it and
# prints the path.
_scope_tree() {
  # shellcheck disable=SC2154  # tmp_root is initialized by th_init.
  local d="$tmp_root/$1"; shift
  local f
  mkdir -p "$d"
  for f in "$@"; do
    mkdir -p "$d/$(dirname "$f")"
    printf 'stub for %s\n' "$f" > "$d/$f"
  done
  WORK_DIR="$d"
  printf '%s' "$d"
}

# json_array <path> [path ...] -> a compact JSON array literal
json_array() { printf '%s\n' "$@" | jq -Rnc '[inputs]'; }

# collect <changed-json> -> sets $out (pretty JSON) and $rc
collect() {
  out="$(_gate_scope_paired_tests_collect "$1")"; rc=$?
}

# assert_pair <name> <source> <test>  -- $out must contain exactly this pair
assert_pair() {
  local name="$1" src="$2" tst="$3" got
  got="$(printf '%s' "$out" | jq -c --arg s "$src" --arg t "$tst" \
    '[.[] | select(.source_path==$s and .test_path==$t)] | length')"
  [[ "$got" == "1" ]] || { fail "$name" "expected pair $src -> $tst in: $out"; return 1; }
  return 0
}

# assert_count <name> <n>
assert_count() {
  local name="$1" want="$2" got
  got="$(printf '%s' "$out" | jq 'length')"
  [[ "$got" == "$want" ]] || { fail "$name" "expected $want pair(s), got $got: $out"; return 1; }
  return 0
}

# --- migrated: Go companion --------------------------------------------------

name="go: a _test.go companion to a changed .go source is detected"
if should_run "$name"; then
  _scope_tree "$name" app.go app_test.go >/dev/null
  collect "$(json_array app.go)"
  [[ "$rc" -eq 0 ]] || fail "$name" "rc=$rc"
  assert_count "$name" 1 && assert_pair "$name" app.go app_test.go && pass "$name"
fi

name="go: a changed *_test.go source is not paired with itself"
if should_run "$name"; then
  _scope_tree "$name" app.go app_test.go >/dev/null
  collect "$(json_array app_test.go)"
  assert_count "$name" 0 && pass "$name"
fi

# --- migrated: TypeScript __tests__/ and sibling variants ------------------

for variant in \
  "ts-tests-dir-test-ts:src/__tests__/format.test.ts" \
  "ts-tests-dir-test-tsx:src/__tests__/format.test.tsx" \
  "ts-tests-dir-spec-ts:src/__tests__/format.spec.ts" \
  "ts-tests-dir-spec-tsx:src/__tests__/format.spec.tsx" \
  "ts-sibling-test-ts:src/format.test.ts"; do
  slug="${variant%%:*}"; testpath="${variant#*:}"
  name="ts: $slug is detected as an adjacent test of src/format.ts"
  if should_run "$name"; then
    _scope_tree "$name" src/format.ts "$testpath" >/dev/null
    collect "$(json_array src/format.ts)"
    [[ "$rc" -eq 0 ]] || fail "$name" "rc=$rc"
    assert_count "$name" 1 && assert_pair "$name" src/format.ts "$testpath" && pass "$name"
  fi
done

name="ts: a changed *.test.ts source is not paired with itself"
if should_run "$name"; then
  _scope_tree "$name" src/format.ts src/format.test.ts >/dev/null
  collect "$(json_array src/format.test.ts)"
  assert_count "$name" 0 && pass "$name"
fi

name="jsx: a .jsx source pairs with a sibling .test.js companion"
if should_run "$name"; then
  _scope_tree "$name" src/widget.jsx src/widget.test.js >/dev/null
  collect "$(json_array src/widget.jsx)"
  [[ "$rc" -eq 0 ]] || fail "$name" "rc=$rc"
  assert_count "$name" 1 && assert_pair "$name" src/widget.jsx src/widget.test.js && pass "$name"
fi

# --- net-new: Python and shell conventions --------------------------------

name="py: a sibling test_<base>.py companion is detected"
if should_run "$name"; then
  _scope_tree "$name" pkg/util.py pkg/test_util.py >/dev/null
  collect "$(json_array pkg/util.py)"
  assert_count "$name" 1 && assert_pair "$name" pkg/util.py pkg/test_util.py && pass "$name"
fi

name="py: a tests/test_<base>.py companion is detected"
if should_run "$name"; then
  _scope_tree "$name" util.py tests/test_util.py >/dev/null
  collect "$(json_array util.py)"
  assert_count "$name" 1 && assert_pair "$name" util.py tests/test_util.py && pass "$name"
fi

name="py: a changed test_*.py source is not paired with itself"
if should_run "$name"; then
  _scope_tree "$name" pkg/util.py pkg/test_util.py >/dev/null
  collect "$(json_array pkg/test_util.py)"
  assert_count "$name" 0 && pass "$name"
fi

name="sh: a sibling test-<base>.sh companion is detected"
if should_run "$name"; then
  _scope_tree "$name" lib/foo.sh lib/test-foo.sh >/dev/null
  collect "$(json_array lib/foo.sh)"
  assert_count "$name" 1 && assert_pair "$name" lib/foo.sh lib/test-foo.sh && pass "$name"
fi

name="sh: a tests/shell/test-<base>.sh companion is detected"
if should_run "$name"; then
  _scope_tree "$name" runtime/foo.sh tests/shell/test-foo.sh >/dev/null
  collect "$(json_array runtime/foo.sh)"
  assert_count "$name" 1 && assert_pair "$name" runtime/foo.sh tests/shell/test-foo.sh && pass "$name"
fi

name="sh: a changed test-*.sh source is not paired with itself"
if should_run "$name"; then
  _scope_tree "$name" lib/foo.sh lib/test-foo.sh >/dev/null
  collect "$(json_array lib/test-foo.sh)"
  assert_count "$name" 0 && pass "$name"
fi

# --- shape / edge contracts ----------------------------------------------

name="no companion on disk yields an empty array"
if should_run "$name"; then
  _scope_tree "$name" src/lonely.ts >/dev/null
  collect "$(json_array src/lonely.ts)"
  [[ "$rc" -eq 0 ]] || fail "$name" "rc=$rc"
  if assert_count "$name" 0 && [[ "$(printf '%s' "$out" | jq -c .)" == "[]" ]]; then
    pass "$name"
  else
    fail "$name" "want []: $out"
  fi
fi

name="a changed path that does not exist on disk is skipped, not an error"
if should_run "$name"; then
  _scope_tree "$name" app.go app_test.go >/dev/null
  collect "$(json_array app.go missing/ghost.go)"
  [[ "$rc" -eq 0 ]] || fail "$name" "rc=$rc"
  assert_count "$name" 1 && assert_pair "$name" app.go app_test.go && pass "$name"
fi

name="multiple changed sources produce every pair, unique and sorted"
if should_run "$name"; then
  _scope_tree "$name" \
    z/svc.go z/svc_test.go \
    a/util.py a/test_util.py \
    src/format.ts src/format.test.ts >/dev/null
  collect "$(json_array src/format.ts z/svc.go a/util.py)"
  [[ "$rc" -eq 0 ]] || fail "$name" "rc=$rc"
  order="$(printf '%s' "$out" | jq -r '[.[].source_path] | join(",")')"
  if assert_count "$name" 3 \
    && assert_pair "$name" a/util.py a/test_util.py \
    && assert_pair "$name" src/format.ts src/format.test.ts \
    && assert_pair "$name" z/svc.go z/svc_test.go \
    && [[ "$order" == "a/util.py,src/format.ts,z/svc.go" ]]; then
    pass "$name"
  else
    fail "$name" "sort order was: $order"
  fi
fi

name="every emitted pair carries reason=language-convention"
if should_run "$name"; then
  _scope_tree "$name" app.go app_test.go src/format.ts src/format.test.ts >/dev/null
  collect "$(json_array app.go src/format.ts)"
  bad="$(printf '%s' "$out" | jq -c '[.[] | select(.reason != "language-convention")]')"
  if [[ "$bad" == "[]" ]]; then
    pass "$name"
  else
    fail "$name" "non-convention reason: $bad"
  fi
fi

name="a source with both a __tests__ and a sibling companion reports both"
if should_run "$name"; then
  _scope_tree "$name" src/format.ts src/__tests__/format.test.ts src/format.spec.ts >/dev/null
  collect "$(json_array src/format.ts)"
  [[ "$rc" -eq 0 ]] || fail "$name" "rc=$rc"
  assert_count "$name" 2 \
    && assert_pair "$name" src/format.ts src/__tests__/format.test.ts \
    && assert_pair "$name" src/format.ts src/format.spec.ts \
    && pass "$name"
fi

th_summary
