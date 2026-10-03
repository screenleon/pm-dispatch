#!/usr/bin/env bash
# Regression tests for runtime/lib/gate-scope.sh: _gate_scope_paired_tests_collect (below) and, at the end,
# the git-failure behaviour of _gate_policy_scope_content_digest and _gate_scope_changes_collect (CC-629).
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

# --- CC-629 (a): a failing git must fail the scope inputs, not shrink them ---------------------
# _gate_policy_scope_content_digest binds an approved policy override to the exact content of the
# diff (and of the untracked files in a working-tree scope); _gate_scope_changes_collect builds the
# change set the reviewers are shown. Both read git through process substitutions or a streamed
# brace group, so a git that failed (a dubious-ownership error, a damaged index, a killed git) just
# looked like an empty listing: the digest silently lost those parts and the change set lost those
# files. The helpers below set up a repo with a committed change, a dirty edit and an untracked
# file, and a git wrapper first on PATH that fails when its arguments contain a chosen token.

# _scope_git_repo <slug> -> prints the repo path (base commit, one commit on top, a dirty edit
# and an untracked file); the wrapper dir is "<repo>.stub"
_scope_git_repo() {
  # the test name is not a path: it has colons and spaces, which would split PATH below
  local slug="${1//[^A-Za-z0-9]/_}" d stub
  d="$tmp_root/scope-repo-${slug:0:40}-$$-$RANDOM"
  stub="$d.stub"
  mkdir -p "$d" "$stub"
  (
    cd "$d" || exit 1
    git init -q .
    git config user.email test@example.com
    git config user.name test
    git config core.autocrlf false
    printf 'one\n' > a.txt
    git add a.txt
    git commit -qm base
    git tag base
    printf 'two\n' > a.txt
    git commit -qam head
    printf 'dirty\n' >> a.txt
    printf 'new\n' > untracked.txt
  ) || return 1
  cat > "$stub/git" <<'STUBEOF'
#!/usr/bin/env bash
if [[ -n "${SCOPE_STUB_FAIL_ON:-}" && " $* " == *" ${SCOPE_STUB_FAIL_ON} "* ]]; then
  if [[ -n "${SCOPE_STUB_PARTIAL:-}" ]]; then
    "$SCOPE_STUB_REAL_GIT" "$@" || :
  fi
  printf 'fatal: stub failure on %s\n' "$SCOPE_STUB_FAIL_ON" >&2
  exit 1
fi
exec "$SCOPE_STUB_REAL_GIT" "$@"
STUBEOF
  chmod +x "$stub/git"
  printf '%s' "$d"
}

# _scope_digest_in <repo> <kind> <include-untracked> [fail-token [partial]]
# Runs _gate_policy_scope_content_digest in the repo WITHOUT pipefail (the library must not depend
# on its caller's options); sets $out, $err (stderr text) and $rc.
_scope_digest_in() {
  local repo="$1" kind="$2" inc="$3" token="${4:-}" partial="${5:-}"
  local errf="$repo.err" tmpd="$repo.tmp"
  # resolved BEFORE PATH is changed: the wrapper must exec the real git, not itself
  local real_git
  real_git="$(command -v git)"
  mkdir -p "$tmpd"
  out="$(
    set +o pipefail
    cd "$repo" || exit 1
    WORK_DIR="$repo"
    TMPDIR="$tmpd" PATH="$repo.stub:$PATH" SCOPE_STUB_REAL_GIT="$real_git" \
      SCOPE_STUB_FAIL_ON="$token" SCOPE_STUB_PARTIAL="$partial" \
      _gate_policy_scope_content_digest "$kind" base HEAD "$inc" 2>"$errf"
  )"; rc=$?
  err="$(cat "$errf" 2>/dev/null)"
}

name="policy scope content digest: the digest is the sha256 of the header and the diff, unchanged"
if should_run "$name"; then
  repo="$(_scope_git_repo "$name")"
  expected="$( cd "$repo" && { printf 'gate-policy-scope-content-v1\0'; git diff --binary --full-index HEAD --; } | sha256sum | awk '{print $1}')"
  _scope_digest_in "$repo" working-tree false
  if [[ "$rc" -eq 0 && "$out" == "$expected" ]]; then
    pass "$name"
  else
    fail "$name" "rc=$rc got=[$out] expected=[$expected] err=[$err]"
  fi
fi

name="policy scope content digest: a failing git fails it instead of digesting a payload without that part"
if should_run "$name"; then
  repo="$(_scope_git_repo "$name")"
  good=""
  for leg in "working-tree true diff" "working-tree true ls-files" "fixed-head false diff" "committed false diff" "allow-dirty false diff"; do
    read -r kind inc token <<<"$leg"
    for partial in "" 1; do
      _scope_digest_in "$repo" "$kind" "$inc" "$token" "$partial"
      if [[ "$rc" -ne 2 || -n "$out" ]]; then
        good="$kind inc=$inc git failing on $token (partial=${partial:-0}): rc=$rc out=[$out]"
        break 2
      fi
      if [[ "$err" != *"gate scope: git"*"$token"* || "$err" != *"fatal: stub failure on $token"* ]]; then
        good="$kind failing on $token: stderr does not name the failed git call and its message: [$err]"
        break 2
      fi
      if [[ -n "$(find "$repo.tmp" -mindepth 1 -maxdepth 1 -name 'gate-scope-content.*' -print -quit)" ]]; then
        good="$kind failing on $token left a temp directory in $repo.tmp"
        break 2
      fi
    done
  done
  if [[ -z "$good" ]]; then
    pass "$name"
  else
    fail "$name" "$good"
  fi
fi

name="policy scope content digest: a passing wrapper changes nothing (control)"
if should_run "$name"; then
  repo="$(_scope_git_repo "$name")"
  direct="$( cd "$repo" && WORK_DIR="$repo" _gate_policy_scope_content_digest working-tree base HEAD true )"
  _scope_digest_in "$repo" working-tree true
  if [[ -n "$direct" && "$rc" -eq 0 && "$out" == "$direct" ]]; then
    pass "$name"
  else
    fail "$name" "direct=[$direct] wrapped=[$out] rc=$rc err=[$err]"
  fi
fi

# _scope_changes_in <repo> <kind> <include-untracked> [fail-token [partial]] -> $out, $err, $rc
_scope_changes_in() {
  local repo="$1" kind="$2" inc="$3" token="${4:-}" partial="${5:-}"
  local errf="$repo.err" tmpd="$repo.tmp"
  # resolved BEFORE PATH is changed: the wrapper must exec the real git, not itself
  local real_git
  real_git="$(command -v git)"
  mkdir -p "$tmpd"
  out="$(
    set +o pipefail
    cd "$repo" || exit 1
    WORK_DIR="$repo"
    POLICY_DIFF_KIND="$kind"
    POLICY_SCOPE_INCLUDE_UNTRACKED="$inc"
    BASE=base
    HEAD_REF=HEAD
    TMPDIR="$tmpd" PATH="$repo.stub:$PATH" SCOPE_STUB_REAL_GIT="$real_git" \
      SCOPE_STUB_FAIL_ON="$token" SCOPE_STUB_PARTIAL="$partial" \
      _gate_scope_changes_collect 2>"$errf"
  )"; rc=$?
  err="$(cat "$errf" 2>/dev/null)"
}

name="scope change set: the listed changes are unchanged, untracked files included on request"
if should_run "$name"; then
  repo="$(_scope_git_repo "$name")"
  _scope_changes_in "$repo" working-tree true
  paths="$(jq -r '[.[] | "\(.status):\(.new_path // .old_path)"] | join(",")' <<<"$out" 2>/dev/null)"
  if [[ "$rc" -eq 0 && "$paths" == "modified:a.txt,untracked:untracked.txt" ]]; then
    pass "$name"
  else
    fail "$name" "rc=$rc paths=[$paths] err=[$err]"
  fi
fi

name="scope change set: a failing git fails it instead of returning fewer changes"
if should_run "$name"; then
  repo="$(_scope_git_repo "$name")"
  good=""
  for leg in "working-tree true --name-status" "working-tree true ls-files" "fixed-head false --name-status" "committed false --name-status" "allow-dirty false --name-status"; do
    read -r kind inc token <<<"$leg"
    for partial in "" 1; do
      _scope_changes_in "$repo" "$kind" "$inc" "$token" "$partial"
      if [[ "$rc" -ne 2 || -n "$out" ]]; then
        good="$kind inc=$inc git failing on $token (partial=${partial:-0}): rc=$rc out=[$out]"
        break 2
      fi
      if [[ "$err" != *"gate scope: git"*"fatal: stub failure on $token"* ]]; then
        good="$kind failing on $token: stderr does not name the failed git call and its message: [$err]"
        break 2
      fi
      if [[ -n "$(find "$repo.tmp" -mindepth 1 -maxdepth 1 -name 'gate-scope-changes.*' -print -quit)" ]]; then
        good="$kind failing on $token left temp files in $repo.tmp"
        break 2
      fi
    done
  done
  if [[ -z "$good" ]]; then
    pass "$name"
  else
    fail "$name" "$good"
  fi
fi

name="scope change set: an unknown diff kind and an empty change set are told apart"
if should_run "$name"; then
  repo="$(_scope_git_repo "$name")"
  _scope_changes_in "$repo" bogus-kind false
  unknown_rc="$rc"
  ( cd "$repo" && git checkout -q -- a.txt && rm -f untracked.txt )
  _scope_changes_in "$repo" working-tree true
  if [[ "$unknown_rc" -eq 2 && "$rc" -eq 0 && "$out" == "[]" ]]; then
    pass "$name"
  else
    fail "$name" "unknown-kind rc=$unknown_rc; clean tree rc=$rc out=[$out] err=[$err]"
  fi
fi

name="policy scope content digest: the untracked record format is pinned (independent expected value)"
if should_run "$name"; then
  repo="$(_scope_git_repo "$name")"
  ( cd "$repo" && printf '#!/bin/sh\necho x\n' > tool.sh && chmod +x tool.sh )
  expected="$(
    cd "$repo" || exit 1
    {
      printf 'gate-policy-scope-content-v1\0'
      git diff --binary --full-index HEAD --
      while IFS= read -r -d '' p; do
        x=false
        [[ -x "$p" ]] && x=true
        printf 'untracked\0path=%s\0kind=file\0executable=%s\0sha256=%s\0' \
          "$(printf '%q' "$p")" "$x" "$(sha256sum "$p" | awk '{print $1}')"
      done < <(git ls-files --others --exclude-standard -z)
    } | sha256sum | awk '{print $1}'
  )"
  _scope_digest_in "$repo" working-tree true
  # the untracked set has two files, one of them executable on every platform (it has a shebang)
  if [[ "$rc" -eq 0 && -n "$expected" && "$out" == "$expected" ]]; then
    pass "$name"
  else
    fail "$name" "rc=$rc got=[$out] expected=[$expected] err=[$err]"
  fi
fi

name="policy scope content digest: an unknown diff kind fails with status 2 and leaves nothing behind"
if should_run "$name"; then
  repo="$(_scope_git_repo "$name")"
  _scope_digest_in "$repo" bogus-kind false
  if [[ "$rc" -eq 2 && -z "$out" && "$err" == *"unknown gate policy diff kind"* ]] \
      && [[ -z "$(find "$repo.tmp" -mindepth 1 -maxdepth 1 -name 'gate-scope-*' -print -quit)" ]]; then
    pass "$name"
  else
    fail "$name" "rc=$rc out=[$out] err=[$err] leftovers=[$(ls "$repo.tmp")]"
  fi
fi

name="scope inputs: a successful call leaves no temp directory or file behind"
if should_run "$name"; then
  repo="$(_scope_git_repo "$name")"
  _scope_digest_in "$repo" working-tree true
  digest_rc="$rc"
  _scope_changes_in "$repo" working-tree true
  if [[ "$digest_rc" -eq 0 && "$rc" -eq 0 ]] \
      && [[ -z "$(find "$repo.tmp" -mindepth 1 -maxdepth 1 -name 'gate-scope-*' -print -quit)" ]]; then
    pass "$name"
  else
    fail "$name" "digest rc=$digest_rc changes rc=$rc leftovers=[$(ls "$repo.tmp")]"
  fi
fi

name="scope inputs: under the caller's real options (errexit, nounset, pipefail) success works and failure returns 2"
if should_run "$name"; then
  repo="$(_scope_git_repo "$name")"
  real_git="$(command -v git)"
  mkdir -p "$repo.tmp"
  strict="$(
    set -euo pipefail
    cd "$repo"
    WORK_DIR="$repo"
    POLICY_DIFF_KIND=working-tree
    POLICY_SCOPE_INCLUDE_UNTRACKED=true
    BASE=base
    HEAD_REF=HEAD
    export TMPDIR="$repo.tmp"
    ok_digest="$(_gate_policy_scope_content_digest working-tree base HEAD true)"
    ok_changes="$(_gate_scope_changes_collect | jq -c 'length')"
    d_rc=0
    PATH="$repo.stub:$PATH" SCOPE_STUB_REAL_GIT="$real_git" SCOPE_STUB_FAIL_ON=ls-files \
      _gate_policy_scope_content_digest working-tree base HEAD true >/dev/null 2>&1 || d_rc=$?
    c_rc=0
    PATH="$repo.stub:$PATH" SCOPE_STUB_REAL_GIT="$real_git" SCOPE_STUB_FAIL_ON=--name-status \
      _gate_scope_changes_collect >/dev/null 2>&1 || c_rc=$?
    printf '%s %s %s %s' "${#ok_digest}" "$ok_changes" "$d_rc" "$c_rc"
  )"
  if [[ "$strict" == "64 2 2 2" ]]; then
    pass "$name"
  else
    fail "$name" "expected '64 2 2 2' (digest length, change count, failure statuses), got [$strict]"
  fi
fi


th_summary
