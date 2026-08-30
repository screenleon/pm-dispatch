#!/usr/bin/env bash
# Regression tests for tools/lint/lint-doc-wikilinks.sh -- one fixture per
# accept/reject class.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LINTER="$REPO_ROOT/tools/lint/lint-doc-wikilinks.sh"

# shellcheck source=tests/lib/test-harness.sh
# shellcheck disable=SC1091
. "$SCRIPT_DIR/../lib/test-harness.sh"
th_init "$@"

# fixture <slug> -- a minimal repo with the five root files + docs/; prints root.
fixture() {
  # shellcheck disable=SC2154  # tmp_root from th_init
  local root="$tmp_root/$1"
  mkdir -p "$root/docs" "$root/docs/spikes"
  : > "$root/BACKLOG.md" ; : > "$root/MILESTONES.md" ; : > "$root/DECISIONS.md"
  : > "$root/README.md"  ; : > "$root/CONTRIBUTING.md"
  printf '%s\n' "$root"
}
run_linter() { bash "$LINTER" --repo-root "$1" 2>&1; }
want_pass() {
  local name="$1" root="$2" out rc=0
  out="$(run_linter "$root")" || rc=$?
  if [[ "$rc" -eq 0 ]]; then pass "$name"; else fail "$name" "expected exit 0, got $rc :: $out"; fi
}
want_fail() {
  local name="$1" root="$2" needle="$3" out rc=0
  out="$(run_linter "$root")" || rc=$?
  if [[ "$rc" -ne 0 && "$out" == *"$needle"* ]]; then pass "$name"
  else fail "$name" "expected non-zero + '$needle', got rc=$rc :: $out"; fi
}

test_clean_repo_passes() {
  local name="the real repo tree passes"
  should_run "$name" || return 0
  want_pass "$name" "$REPO_ROOT"
}

test_bare_wikilink_in_backlog_fails() {
  local name="a bare [[slug]] in BACKLOG.md is a finding"
  should_run "$name" || return 0
  local root; root="$(fixture "$name")"
  printf '# B\n\nsee [[suite-registry-mirror]] for context\n' > "$root/BACKLOG.md"
  want_fail "$name" "$root" "BACKLOG.md:3: bare wikilink [[suite-registry-mirror]]"
}

test_bare_wikilink_in_docs_fails() {
  local name="a bare [[slug]] in a top-level docs/*.md is a finding"
  should_run "$name" || return 0
  local root; root="$(fixture "$name")"
  printf '# D\n\navoids the bug from [[env-var-ambient-leak-into-fixtures]].\n' \
    > "$root/docs/memory-system.md"
  want_fail "$name" "$root" "docs/memory-system.md:3"
}

test_ticket_ref_passes() {
  local name="[[CC-1234]] and [[CC-1234a]] ticket refs pass"
  should_run "$name" || return 0
  local root; root="$(fixture "$name")"
  printf '# B\n\nsee [[CC-1234]] and its follow-up [[CC-1234a]].\n' > "$root/BACKLOG.md"
  want_pass "$name" "$root"
}

test_markdown_link_passes() {
  local name="a proper [text](path.md) link passes"
  should_run "$name" || return 0
  local root; root="$(fixture "$name")"
  printf '# B\n\nsee [platform support](docs/platform-support.md).\n' > "$root/BACKLOG.md"
  want_pass "$name" "$root"
}

test_wikilink_inside_inline_code_passes() {
  local name="a [[slug]] inside an inline code span is ignored"
  should_run "$name" || return 0
  local root; root="$(fixture "$name")"
  # shellcheck disable=SC2016  # literal backticks are markdown fixture content
  printf '# B\n\nthe old `[[suite-registry-mirror]]` note was renamed.\n' > "$root/BACKLOG.md"
  want_pass "$name" "$root"
}

test_wikilink_inside_double_backtick_span_passes() {
  local name="a [[slug]] inside a double-backtick inline span is ignored"
  should_run "$name" || return 0
  local root; root="$(fixture "$name")"
  # shellcheck disable=SC2016  # literal backticks are markdown fixture content
  printf '# B\n\nthe old ``[[suite-registry-mirror]]`` note was renamed.\n' > "$root/BACKLOG.md"
  want_pass "$name" "$root"
}

test_double_backtick_span_with_inner_backtick_passes() {
  local name="a double-backtick span containing a literal backtick still suppresses a [[slug]]"
  should_run "$name" || return 0
  local root; root="$(fixture "$name")"
  # shellcheck disable=SC2016  # literal backticks are markdown fixture content
  printf '# B\n\nsee ``a `x` and [[example]]`` in one span.\n' > "$root/BACKLOG.md"
  want_pass "$name" "$root"
}

test_wikilink_inside_fenced_block_passes() {
  local name="a [[ ]] bash test inside a fenced block is ignored"
  should_run "$name" || return 0
  local root; root="$(fixture "$name")"
  # shellcheck disable=SC2016  # literal backticks are markdown fixture content
  printf '# D\n\n```\nif [[ -d "$x" ]]; then echo hi; fi\n```\n' > "$root/docs/x.md"
  want_pass "$name" "$root"
}

test_nested_shorter_fence_line_does_not_close_outer() {
  local name="a 3-backtick line inside a 4-backtick fence does not expose later content"
  should_run "$name" || return 0
  local root; root="$(fixture "$name")"
  # shellcheck disable=SC2016  # literal backticks are markdown fixture content
  printf '# D\n\n````markdown\n```\nsome nested code\n```\nif [[ -d x ]] && [[example]]; then :; fi\n````\n' \
    > "$root/docs/x.md"
  want_pass "$name" "$root"
}

test_bare_shorter_fence_does_not_close_longer_opener() {
  local name="a bare 3-backtick line does not close a 4-backtick fence"
  should_run "$name" || return 0
  local root; root="$(fixture "$name")"
  # shellcheck disable=SC2016  # literal backticks are markdown fixture content
  printf '# D\n\n````\n```\n[[still-code]]\n````\n' > "$root/docs/x.md"
  want_pass "$name" "$root"
}

test_indented_fence_is_recognised() {
  local name="an indented triple-backtick fence still suppresses its contents"
  should_run "$name" || return 0
  local root; root="$(fixture "$name")"
  # shellcheck disable=SC2016  # literal backticks are markdown fixture content
  printf '# D\n\n- example:\n  ```\n  bash -c "[[ $(id -u) == 0 ]]"\n  ```\n' > "$root/docs/x.md"
  want_pass "$name" "$root"
}

test_regex_class_inside_code_passes() {
  local name="a regex character class inside a code span is ignored"
  should_run "$name" || return 0
  local root; root="$(fixture "$name")"
  # shellcheck disable=SC2016  # literal backticks are markdown fixture content
  printf '# D\n\nbytes that a control-class code span does not match are kept: `[[:cntrl:]]`.\n' > "$root/docs/x.md"
  want_pass "$name" "$root"
}

test_spikes_dir_is_not_scanned() {
  local name="docs/spikes/*.md is outside the scanned set"
  should_run "$name" || return 0
  local root; root="$(fixture "$name")"
  printf '# S\n\nhistorical ref [[feedback_codex_brief_discipline]].\n' \
    > "$root/docs/spikes/CC-999.md"
  want_pass "$name" "$root"
}

test_bad_flag_is_usage_error() {
  local name="an unknown flag exits 2"
  should_run "$name" || return 0
  local out rc=0
  out="$(bash "$LINTER" --nonsense 2>&1)" || rc=$?
  if [[ "$rc" -eq 2 ]]; then pass "$name"; else fail "$name" "expected exit 2, got $rc :: $out"; fi
}

test_clean_repo_passes
test_bare_wikilink_in_backlog_fails
test_bare_wikilink_in_docs_fails
test_ticket_ref_passes
test_markdown_link_passes
test_wikilink_inside_inline_code_passes
test_wikilink_inside_double_backtick_span_passes
test_double_backtick_span_with_inner_backtick_passes
test_wikilink_inside_fenced_block_passes
test_nested_shorter_fence_line_does_not_close_outer
test_bare_shorter_fence_does_not_close_longer_opener
test_indented_fence_is_recognised
test_regex_class_inside_code_passes
test_spikes_dir_is_not_scanned
test_bad_flag_is_usage_error

th_summary
