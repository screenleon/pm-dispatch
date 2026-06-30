#!/usr/bin/env bash
# Unit tests for scripts/lib/model-aliases.sh — ma_resolve_alias (soft) and
# ma_resolve_alias_strict (hard-fail).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=scripts/lib/test-harness.sh
. "$SCRIPT_DIR/lib/test-harness.sh"
th_init "$@"

# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib/model-aliases.sh"

TMPDIR="${TMPDIR:-/tmp}"
WORK="$(mktemp -d -t test-model-aliases.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

_mk_tsv() {
  local path="$WORK/$1"
  printf '%s\t%s\t%s\n' "sonnet" "claude-sonnet-4-6" "medium" > "$path"
  printf '%s\t%s\t%s\n' "haiku"  "claude-haiku-4-5"  "low"    >> "$path"
  echo "$path"
}

_mk_bad_tsv() {
  local path="$WORK/$1"
  printf '%s\t%s\n' "bad-alias" "only-two-cols" > "$path"
  echo "$path"
}

# ── ma_resolve_alias (soft) ───────────────────────────────────────────────────

case_ma_resolve_alias_match() {
  local name="ma_resolve_alias: known alias returns match"
  should_run "$name" || return 0
  local tsv; tsv="$(_mk_tsv aliases1.tsv)"
  MA_RESOLVE_MATCH=0; MA_RESOLVE_MODEL=""; MA_RESOLVE_EFFORT=""
  ma_resolve_alias "$tsv" "sonnet" "test"
  if [[ "$MA_RESOLVE_MATCH" == "1" && "$MA_RESOLVE_MODEL" == "claude-sonnet-4-6" && "$MA_RESOLVE_EFFORT" == "medium" ]]; then
    pass "$name"
  else
    fail "$name" "expected MATCH=1 MODEL=claude-sonnet-4-6 EFFORT=medium, got MATCH=$MA_RESOLVE_MATCH MODEL=$MA_RESOLVE_MODEL EFFORT=$MA_RESOLVE_EFFORT"
  fi
}

case_ma_resolve_alias_no_match() {
  local name="ma_resolve_alias: unknown alias returns no match"
  should_run "$name" || return 0
  local tsv; tsv="$(_mk_tsv aliases2.tsv)"
  MA_RESOLVE_MATCH=0; MA_RESOLVE_MODEL=""; MA_RESOLVE_EFFORT=""
  ma_resolve_alias "$tsv" "nonexistent" "test"
  if [[ "$MA_RESOLVE_MATCH" == "0" && -z "$MA_RESOLVE_MODEL" ]]; then
    pass "$name"
  else
    fail "$name" "expected MATCH=0 MODEL empty, got MATCH=$MA_RESOLVE_MATCH MODEL=$MA_RESOLVE_MODEL"
  fi
}

case_ma_resolve_alias_missing_file() {
  local name="ma_resolve_alias: missing TSV returns 0 (pass-through)"
  should_run "$name" || return 0
  MA_RESOLVE_MATCH=0; MA_RESOLVE_MODEL=""; MA_RESOLVE_EFFORT=""
  local rc=0
  ma_resolve_alias "$WORK/does-not-exist.tsv" "sonnet" "test" || rc=$?
  if [[ "$rc" == "0" && "$MA_RESOLVE_MATCH" == "0" ]]; then
    pass "$name"
  else
    fail "$name" "expected rc=0 MATCH=0, got rc=$rc MATCH=$MA_RESOLVE_MATCH"
  fi
}

case_ma_resolve_alias_malformed_warns_continues() {
  local name="ma_resolve_alias: malformed line emits warning and continues"
  should_run "$name" || return 0
  local tsv; tsv="$(_mk_bad_tsv bad1.tsv)"
  # append a valid line after the bad one
  printf '%s\t%s\t%s\n' "haiku" "claude-haiku-4-5" "low" >> "$tsv"
  MA_RESOLVE_MATCH=0; MA_RESOLVE_MODEL=""; MA_RESOLVE_EFFORT=""
  local stderr_file; stderr_file="$(mktemp -p "$WORK")"
  ma_resolve_alias "$tsv" "haiku" "test" 2>"$stderr_file"
  local stderr_out; stderr_out="$(cat "$stderr_file")"
  if [[ "$MA_RESOLVE_MATCH" == "1" && "$MA_RESOLVE_MODEL" == "claude-haiku-4-5" && "$stderr_out" == *"warning"* ]]; then
    pass "$name"
  else
    fail "$name" "expected MATCH=1 MODEL=claude-haiku-4-5 and warning in stderr; got MATCH=$MA_RESOLVE_MATCH MODEL=$MA_RESOLVE_MODEL stderr=$stderr_out"
  fi
}

# ── ma_resolve_alias_strict ───────────────────────────────────────────────────

case_ma_resolve_alias_strict_match() {
  local name="ma_resolve_alias_strict: known alias returns match"
  should_run "$name" || return 0
  local tsv; tsv="$(_mk_tsv aliases3.tsv)"
  MA_RESOLVE_MATCH=0; MA_RESOLVE_MODEL=""; MA_RESOLVE_EFFORT=""
  ma_resolve_alias_strict "$tsv" "haiku" "test"
  if [[ "$MA_RESOLVE_MATCH" == "1" && "$MA_RESOLVE_MODEL" == "claude-haiku-4-5" && "$MA_RESOLVE_EFFORT" == "low" ]]; then
    pass "$name"
  else
    fail "$name" "expected MATCH=1 MODEL=claude-haiku-4-5 EFFORT=low, got MATCH=$MA_RESOLVE_MATCH MODEL=$MA_RESOLVE_MODEL EFFORT=$MA_RESOLVE_EFFORT"
  fi
}

case_ma_resolve_alias_strict_no_match() {
  local name="ma_resolve_alias_strict: unknown alias returns 0 no match"
  should_run "$name" || return 0
  local tsv; tsv="$(_mk_tsv aliases4.tsv)"
  MA_RESOLVE_MATCH=0; MA_RESOLVE_MODEL=""; MA_RESOLVE_EFFORT=""
  local rc=0
  ma_resolve_alias_strict "$tsv" "nonexistent" "test" || rc=$?
  if [[ "$rc" == "0" && "$MA_RESOLVE_MATCH" == "0" ]]; then
    pass "$name"
  else
    fail "$name" "expected rc=0 MATCH=0, got rc=$rc MATCH=$MA_RESOLVE_MATCH"
  fi
}

case_ma_resolve_alias_strict_missing_file() {
  local name="ma_resolve_alias_strict: missing TSV returns 1 with stderr"
  should_run "$name" || return 0
  MA_RESOLVE_MATCH=0; MA_RESOLVE_MODEL=""; MA_RESOLVE_EFFORT=""
  local rc=0 stderr_out
  stderr_out="$(ma_resolve_alias_strict "$WORK/no-such.tsv" "sonnet" "test" 2>&1)" || rc=$?
  if [[ "$rc" != "0" && "$stderr_out" == *"error"* ]]; then
    pass "$name"
  else
    fail "$name" "expected rc!=0 and error in stderr; got rc=$rc stderr=$stderr_out"
  fi
}

case_ma_resolve_alias_strict_malformed() {
  local name="ma_resolve_alias_strict: malformed line returns 1 with stderr"
  should_run "$name" || return 0
  local tsv; tsv="$(_mk_bad_tsv bad2.tsv)"
  MA_RESOLVE_MATCH=0; MA_RESOLVE_MODEL=""; MA_RESOLVE_EFFORT=""
  local rc=0 stderr_out
  stderr_out="$(ma_resolve_alias_strict "$tsv" "bad-alias" "test" 2>&1)" || rc=$?
  if [[ "$rc" != "0" && "$stderr_out" == *"error"* ]]; then
    pass "$name"
  else
    fail "$name" "expected rc!=0 and error in stderr; got rc=$rc stderr=$stderr_out"
  fi
}

# ── run all ──────────────────────────────────────────────────────────────────

case_ma_resolve_alias_match
case_ma_resolve_alias_no_match
case_ma_resolve_alias_missing_file
case_ma_resolve_alias_malformed_warns_continues
case_ma_resolve_alias_strict_match
case_ma_resolve_alias_strict_no_match
case_ma_resolve_alias_strict_missing_file
case_ma_resolve_alias_strict_malformed

th_summary
