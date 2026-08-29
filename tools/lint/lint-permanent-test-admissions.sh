#!/usr/bin/env bash
# Fail a PR that adds new permanent test-case functions to a pre-existing test
# file but whose body omits (or leaves as `none`) the Step 4 template line:
#
#   - Permanent test admissions: <one line per finding whose remedy was a new
#     permanent blocking test>
#
# commands/ship.md Step 3 requires this record at the point each gate finding is
# remediated; the prose reminder is not enough (three consecutive PRs omitted
# it). This is the mechanical floor: it checks that the line is present and is
# not `none` whenever the diff actually grew an existing suite. It does NOT
# judge the *content* of the line -- which of the six criteria, which
# alternative -- that stays a human call.
#
# Pure function of --pr-body + --base + the git tree: no network, no `gh`, no
# `pmctl`. CI fetches the PR body and passes it in; the meta-test passes
# hand-written bodies.
#
#   tools/lint/lint-permanent-test-admissions.sh --pr-body <path|-> [--base <ref>] [--repo-root <dir>]
#
# The git tree is the current working directory's repo unless --repo-root is
# given (CI runs it at the checkout root; the meta-test points it at a fixture).
#
# Exit: 0 ok, 1 policy violation, 2 usage / environment error.
set -euo pipefail

self="$(basename "$0")"

usage() {
  printf 'usage: %s --pr-body <path|-> [--base <ref>] [--repo-root <dir>]\n' "$self" >&2
}

die_usage() { printf '%s: %s\n' "$self" "$1" >&2; usage; exit 2; }

pr_body_arg=""
base_ref="origin/main"
repo_root=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --pr-body)
      [[ $# -ge 2 && -n "${2:-}" ]] || die_usage "--pr-body requires a path or -"
      pr_body_arg="$2"; shift 2 ;;
    --base)
      [[ $# -ge 2 && -n "${2:-}" ]] || die_usage "--base requires a ref"
      base_ref="$2"; shift 2 ;;
    --repo-root)
      [[ $# -ge 2 && -n "${2:-}" ]] || die_usage "--repo-root requires a dir"
      repo_root="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) die_usage "unknown argument: $1" ;;
  esac
done
[[ -n "$pr_body_arg" ]] || die_usage "--pr-body is required"

# --- read the PR body BEFORE any cd, so a relative --pr-body still resolves ---
body=""
if [[ "$pr_body_arg" == "-" ]]; then
  body="$(cat)"
else
  [[ -r "$pr_body_arg" ]] || die_usage "PR body file is not readable: $pr_body_arg"
  body="$(cat -- "$pr_body_arg")"
fi

# git pathspecs resolve against CWD, not `git -C <dir>`'s dir, so operate from
# inside the repo root rather than passing -C to every call.
if [[ -z "$repo_root" ]]; then
  repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" \
    || die_usage "not inside a git repository (pass --repo-root)"
fi
[[ -d "$repo_root/.git" || -f "$repo_root/.git" ]] || die_usage "not a git repo: $repo_root"
cd "$repo_root" || die_usage "cannot enter repo root: $repo_root"

# --- resolve the base -----------------------------------------------------------
# Never treat a missing base as "no new tests": that would silently disable the
# check on any shallow checkout.
git rev-parse --verify --quiet "$base_ref^{commit}" >/dev/null \
  || die_usage "base ref not found (fetch history / --base): $base_ref"

# --- extract the admissions line + its indented continuation ------------------
# Matches the Step 4 template bullet in any leading-whitespace form. The claim
# is everything after the first colon on that line plus any following lines that
# are more-indented than the bullet, up to the next bullet or a blank line.
admissions_claim=""
have_line=0
admissions_claim="$(
  printf '%s\n' "$body" | awk '
    BEGIN { found = 0 }
    !found && tolower($0) ~ /^[[:space:]]*[-*]?[[:space:]]*permanent test admissions[[:space:]]*:/ {
      found = 1
      line = $0
      sub(/^[^:]*:[[:space:]]*/, "", line)
      print line
      # capture indented continuation
      indent = match($0, /[^[:space:]]/) - 1
      next
    }
    found {
      if ($0 ~ /^[[:space:]]*$/) exit
      here = match($0, /[^[:space:]]/) - 1
      # Stop at a sibling line at or left of the header bullet (e.g. the next
      # "- Full suite:" template field). A more-indented line -- including a
      # sub-bullet that enumerates findings -- belongs to this record.
      if (here <= indent) exit
      cont = $0
      sub(/^[[:space:]]+/, "", cont)
      print cont
    }
  '
)"
if printf '%s\n' "$body" | grep -qiE '^[[:space:]]*[-*]?[[:space:]]*permanent test admissions[[:space:]]*:'; then
  have_line=1
fi

fail() { printf '%s: %s\n' "$self" "$1" >&2; }

if [[ "$have_line" -ne 1 ]]; then
  fail "PR body is missing the 'Permanent test admissions:' line."
  fail "  Add it from the commands/ship.md Step 4 template: one line per finding"
  fail "  whose remedy was a new permanent blocking test, or 'none' if this PR"
  fail "  added no permanent test to a pre-existing suite."
  exit 1
fi

# --- classify the claim ------------------------------------------------------
# NO-CLAIM = the PR asserts it added no gate-driven permanent test to an
# existing suite. Everything else is treated as a real record and passes the
# mechanical floor (its content is a human call).
claim_norm="$(printf '%s' "$admissions_claim" | tr '[:upper:]' '[:lower:]' \
  | tr -d '[:space:]' | sed 's/[.[:punct:]]*$//')"
no_claim=0
case "$claim_norm" in
  ""|none|na|"n/a"|"-"|nil) no_claim=1 ;;
esac

# --- net-new permanent test functions in pre-existing test files ------------
# Seam: the test-file glob and the function-definition shape live only here.
#
# The trigger is a net-new test/case *function identity*, not an added patch
# line: comparing the set of function names defined in each pre-existing test
# file at <base> against the set at HEAD. This is deliberately not a
# `git diff | grep '^+...'` count -- that mistakes a moved or reformatted
# declaration for a new test, and (with --diff-filter=M) lets a renamed suite
# smuggle new functions past the check. Renames are followed (old content at
# <base> vs new content at HEAD); a brand-new file (status A) is a feature's
# own contract and never contributes.

# Read a test file on stdin, print the bare name of every test_/case_ function
# it defines (one per line, unsorted).
_test_fn_names() {
  grep -oE '^[[:space:]]*(test_|case_)[A-Za-z0-9_]+[[:space:]]*\(\)' \
    | sed -E 's/^[[:space:]]*//; s/[[:space:]]*\(\)$//'
}

# For each pre-existing test file that gained >=1 net-new test/case function
# between <base> and HEAD, print "<count>\t<head-path>".
_net_new_by_file() {
  local base="$1" status old new base_path added
  git diff --name-status -M --diff-filter=MR "${base}...HEAD" -- 'tests/' 2>/dev/null \
    | while IFS=$'\t' read -r status old new; do
        case "$status" in
          M*) base_path="$old"; new="$old" ;;
          R*) base_path="$old" ;;              # old@base -> new@HEAD
          *)  continue ;;
        esac
        git cat-file -e "${base}:${base_path}" 2>/dev/null || continue
        added="$(comm -13 \
          <(git show "${base}:${base_path}" 2>/dev/null | _test_fn_names | LC_ALL=C sort -u) \
          <(git show "HEAD:${new}"          2>/dev/null | _test_fn_names | LC_ALL=C sort -u) \
          | grep -c . || true)"
        [[ "$added" -gt 0 ]] && printf '%s\t%s\n' "$added" "$new"
      done || true
}

new_fn_count=0
changed_test_files=()
while IFS=$'\t' read -r _count _path; do
  [[ "$_count" =~ ^[0-9]+$ && -n "$_path" ]] || continue
  new_fn_count=$((new_fn_count + _count))
  changed_test_files+=("$_path")
done < <(_net_new_by_file "$base_ref")

if [[ "$no_claim" -eq 1 && "$new_fn_count" -gt 0 ]]; then
  fail "the admission record is '${admissions_claim:-<empty>}' but this PR adds ${new_fn_count} net-new"
  fail "  permanent test function(s) to pre-existing test file(s):"
  printf '    %s\n' "${changed_test_files[@]}" >&2
  fail "  commands/ship.md Step 3 requires one line per finding whose remedy was a new"
  fail "  permanent blocking test -- naming the criteria met, or the alternative taken."
  fail "  (A brand-new test file is a feature's own contract and is exempt.)"
  exit 1
fi

printf '%s: OK (%s net-new permanent test fn(s) in pre-existing suites; admission record %s)\n' \
  "$self" "$new_fn_count" \
  "$([[ "$no_claim" -eq 1 ]] && printf 'is none' || printf 'present')"
