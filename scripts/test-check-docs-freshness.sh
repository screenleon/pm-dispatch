#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CHECK_SCRIPT="$SCRIPT_DIR/check-docs-freshness.sh"

# shellcheck source=scripts/lib/test-harness.sh
. "$SCRIPT_DIR/lib/test-harness.sh"
th_init "$@"

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT
LAST_EXIT=0
LAST_OUTPUT=""

run_check() {
  local repo="$1"
  shift
  LAST_EXIT=0
  LAST_OUTPUT="$(bash "$CHECK_SCRIPT" "$@" --repo "$repo" 2>&1)" || LAST_EXIT=$?
}

finalize_repo() {
  local repo="$1"
  shift
  local tag
  git -C "$repo" add README.md MILESTONES.md BACKLOG.md
  git -C "$repo" -c user.name=ci-bot -c user.email=ci-bot@example.com commit -qm "fixture" >/dev/null
  for tag in "$@"; do
    git -C "$repo" tag "$tag"
  done
}

run_test_u1_readme_clean() {
  local name="u1-readme-clean-exit-0"
  local repo="$TMP_ROOT/$name"
  mkdir -p "$repo"
  git -C "$repo" init -q

  cat > "$repo/README.md" <<'DOC'
# pm-dispatch
Release: v1.2.3
DOC
  cat > "$repo/MILESTONES.md" <<'DOC'
## v1.2.3 — done section
| CC | status |
|---|---|
| CC-999 | ✅ done |
DOC
  cat > "$repo/BACKLOG.md" <<'DOC'
## Index

| #  | Status | 主題 | 影響面 | 首次記錄 | Refs |
|----|--------|------|--------|----------|------|
| CC-001 | ✅ closed 2026-05-23 | clean test | ops | 2026-05-23 | pr:#999 |
DOC

  finalize_repo "$repo" v1.2.3

  run_check "$repo"
  assert_exit "$name" "$LAST_EXIT" 0 || return
  assert_string_contains "$name" "$LAST_OUTPUT" "OK]"
  pass "$name"
}

run_test_u1_readme_stale() {
  local name="u1-readme-stale-exit-2"
  local repo="$TMP_ROOT/$name"
  mkdir -p "$repo"
  git -C "$repo" init -q

  cat > "$repo/README.md" <<'DOC'
# pm-dispatch
Release: v1.2.2
DOC
  cat > "$repo/MILESTONES.md" <<'DOC'
## v1.2.3 — closed
| CC | status |
|---|---|
| CC-999 | ✅ done |
DOC
  cat > "$repo/BACKLOG.md" <<'DOC'
## Index

| #  | Status | 主題 | 影響面 | 首次記錄 | Refs |
|----|--------|------|--------|----------|------|
| CC-001 | ✅ closed 2026-05-23 | clean test | ops | 2026-05-23 | pr:#999 |
DOC

  finalize_repo "$repo" v1.2.3

  run_check "$repo"
  assert_exit "$name" "$LAST_EXIT" 2 || return
  assert_string_contains "$name" "$LAST_OUTPUT" "FAIL]"
  pass "$name"
}

run_test_u1_readme_absent() {
  local name="u1-readme-absent-exit-1"
  local repo="$TMP_ROOT/$name"
  mkdir -p "$repo"
  git -C "$repo" init -q

  cat > "$repo/README.md" <<'DOC'
# pm-dispatch
No version marker here.
DOC
  cat > "$repo/MILESTONES.md" <<'DOC'
## v1.2.3 — closed
| CC | status |
|---|---|
| CC-999 | ✅ done |
DOC
  cat > "$repo/BACKLOG.md" <<'DOC'
## Index

| #  | Status | 主題 | 影響面 | 首次記錄 | Refs |
|----|--------|------|--------|----------|------|
| CC-001 | ✅ closed 2026-05-23 | clean test | ops | 2026-05-23 | pr:#999 |
DOC

  finalize_repo "$repo" v1.2.3

  run_check "$repo"
  assert_exit "$name" "$LAST_EXIT" 1 || return
  assert_string_contains "$name" "$LAST_OUTPUT" "WARN]"
  pass "$name"
}

run_test_u2_section_missing() {
  local name="u2-section-missing-exit-2"
  local repo="$TMP_ROOT/$name"
  mkdir -p "$repo"
  git -C "$repo" init -q

  cat > "$repo/README.md" <<'DOC'
# pm-dispatch
Release: v0.1.0
DOC
  cat > "$repo/MILESTONES.md" <<'DOC'
## v0.2.0 — Cross-platform ops
| CC | status |
|---|---|
| CC-999 | ✅ done |
DOC
  cat > "$repo/BACKLOG.md" <<'DOC'
## Index

| #  | Status | 主題 | 影響面 | 首次記錄 | Refs |
|----|--------|------|--------|----------|------|
| CC-001 | ✅ closed 2026-05-23 | clean test | ops | 2026-05-23 | pr:#999 |
DOC

  finalize_repo "$repo" v0.1.0

  run_check "$repo"
  assert_exit "$name" "$LAST_EXIT" 2 || return
  assert_string_contains "$name" "$LAST_OUTPUT" "tag v0.1.0 exists but no section"
  pass "$name"
}

run_test_u2_status_stale() {
  local name="u2-status-stale-exit-2"
  local repo="$TMP_ROOT/$name"
  mkdir -p "$repo"
  git -C "$repo" init -q

  cat > "$repo/README.md" <<'DOC'
# pm-dispatch
Release: v0.2.0
DOC
  cat > "$repo/MILESTONES.md" <<'DOC'
## v0.2.0 — scheduled

| 票號 | 說明 | 狀態 |
|---|---|---|
| CC-001 | do staged work | 規劃中 |
DOC
  cat > "$repo/BACKLOG.md" <<'DOC'
## Index

| #  | Status | 主題 | 影響面 | 首次記錄 | Refs |
|----|--------|------|--------|----------|------|
| CC-001 | ✅ closed 2026-05-23 | clean test | ops | 2026-05-23 | pr:#999 |
DOC

  finalize_repo "$repo" v0.2.0

  run_check "$repo"
  assert_exit "$name" "$LAST_EXIT" 2 || return
  assert_string_contains "$name" "$LAST_OUTPUT" "marked planned"
  pass "$name"
}

run_test_u2_clean() {
  local name="u2-clean-exit-0"
  local repo="$TMP_ROOT/$name"
  mkdir -p "$repo"
  git -C "$repo" init -q

  cat > "$repo/README.md" <<'DOC'
# pm-dispatch
Release: v0.2.0
DOC
  cat > "$repo/MILESTONES.md" <<'DOC'
## v0.2.0 — Cross-platform ops
| CC | status |
|---|---|
| CC-999 | ✅ done |
DOC
  cat > "$repo/BACKLOG.md" <<'DOC'
## Index

| #  | Status | 主題 | 影響面 | 首次記錄 | Refs |
|----|--------|------|--------|----------|------|
| CC-001 | ✅ closed 2026-05-23 | clean test | ops | 2026-05-23 | pr:#999 |
DOC

  finalize_repo "$repo" v0.2.0

  run_check "$repo"
  assert_exit "$name" "$LAST_EXIT" 0 || return
  if grep -Fq "[WARN]" <<< "$LAST_OUTPUT"; then
    fail "$name" "unexpected output: [WARN]"
    return 1
  fi
  pass "$name"
}

run_test_u3_closed_tbd() {
  local name="u3-closed-tbd-exit-2"
  local repo="$TMP_ROOT/$name"
  mkdir -p "$repo"
  git -C "$repo" init -q

  cat > "$repo/README.md" <<'DOC'
# pm-dispatch
Release: v1.0.0
DOC
  cat > "$repo/MILESTONES.md" <<'DOC'
## v1.0.0 — initial
| CC | status |
|---|---|
| CC-999 | ✅ done |
DOC
  cat > "$repo/BACKLOG.md" <<'DOC'
## Index

| #  | Status | 主題 | 影響面 | 首次記錄 | Refs |
|----|--------|------|--------|----------|------|
| CC-111 | ✅ closed 2026-05-23 | stale pr ref | ops | 2026-05-23 | pr:TBD |
DOC

  finalize_repo "$repo" v1.0.0

  run_check "$repo"
  assert_exit "$name" "$LAST_EXIT" 2 || return
  assert_string_contains "$name" "$LAST_OUTPUT" "closed row with pr:TBD"
  pass "$name"
}

run_test_u3_open_tbd() {
  local name="u3-open-tbd-exit-1"
  local repo="$TMP_ROOT/$name"
  mkdir -p "$repo"
  git -C "$repo" init -q

  cat > "$repo/README.md" <<'DOC'
# pm-dispatch
Release: v1.0.0
DOC
  cat > "$repo/MILESTONES.md" <<'DOC'
## v1.0.0 — initial
| CC | status |
|---|---|
| CC-999 | ✅ done |
DOC
  cat > "$repo/BACKLOG.md" <<'DOC'
## Index

| #  | Status | 主題 | 影響面 | 首次記錄 | Refs |
|----|--------|------|--------|----------|------|
| CC-111 | ⏸ deferred | pending work | ops | 2026-05-23 | pr:TBD |
DOC

  finalize_repo "$repo" v1.0.0

  run_check "$repo"
  assert_exit "$name" "$LAST_EXIT" 1 || return
  assert_string_contains "$name" "$LAST_OUTPUT" "non-closed row with pr:TBD"
  pass "$name"
}

run_test_u3_clean() {
  local name="u3-clean-exit-0"
  local repo="$TMP_ROOT/$name"
  mkdir -p "$repo"
  git -C "$repo" init -q

  cat > "$repo/README.md" <<'DOC'
# pm-dispatch
Release: v1.0.0
DOC
  cat > "$repo/MILESTONES.md" <<'DOC'
## v1.0.0 — initial
| CC | status |
|---|---|
| CC-999 | ✅ done |
DOC
  cat > "$repo/BACKLOG.md" <<'DOC'
## Index

| #  | Status | 主題 | 影響面 | 首次記錄 | Refs |
|----|--------|------|--------|----------|------|
| CC-111 | ✅ closed 2026-05-23 | closed with real PR | ops | 2026-05-23 | pr:#999 |
DOC

  finalize_repo "$repo" v1.0.0

  run_check "$repo"
  assert_exit "$name" "$LAST_EXIT" 0 || return
  pass "$name"
}

run_test_aggregation_warning_only() {
  local name="aggregation-warning-only-exit-1"
  local repo="$TMP_ROOT/$name"
  mkdir -p "$repo"
  git -C "$repo" init -q

  cat > "$repo/README.md" <<'DOC'
# pm-dispatch
No version marker.
DOC
  cat > "$repo/MILESTONES.md" <<'DOC'
## v1.0.0 — initial
| CC | status |
|---|---|
| CC-999 | ✅ done |
DOC
  cat > "$repo/BACKLOG.md" <<'DOC'
## Index

| #  | Status | 主題 | 影響面 | 首次記錄 | Refs |
|----|--------|------|--------|----------|------|
| CC-111 | ⏸ deferred | pending work | ops | 2026-05-23 | pr:TBD |
DOC

  finalize_repo "$repo" v1.0.0

  run_check "$repo"
  assert_exit "$name" "$LAST_EXIT" 1 || return
  assert_string_contains "$name" "$LAST_OUTPUT" "Summary:"
  assert_string_contains "$name" "$LAST_OUTPUT" "WARN]"
  pass "$name"
}

run_test_aggregation_blocking_plus_warning() {
  local name="aggregation-blocking-warning-exit-2"
  local repo="$TMP_ROOT/$name"
  mkdir -p "$repo"
  git -C "$repo" init -q

  cat > "$repo/README.md" <<'DOC'
# pm-dispatch
Release: v0.1.0
DOC
  cat > "$repo/MILESTONES.md" <<'DOC'
## v1.0.0 — initial
| CC | status |
|---|---|
| CC-999 | ✅ done |
DOC
  cat > "$repo/BACKLOG.md" <<'DOC'
## Index

| #  | Status | 主題 | 影響面 | 首次記錄 | Refs |
|----|--------|------|--------|----------|------|
| CC-111 | ⏸ deferred | pending work | ops | 2026-05-23 | pr:TBD |
DOC

  finalize_repo "$repo" v1.0.0

  run_check "$repo"
  assert_exit "$name" "$LAST_EXIT" 2 || return
  assert_string_contains "$name" "$LAST_OUTPUT" "FAIL]"
  pass "$name"
}

run_test_json_output() {
  local name="json-output-valid"
  local repo="$TMP_ROOT/$name"
  mkdir -p "$repo"
  git -C "$repo" init -q

  cat > "$repo/README.md" <<'DOC'
# pm-dispatch
Release: v1.0.0
DOC
  cat > "$repo/MILESTONES.md" <<'DOC'
## v1.0.0 — initial
| CC | status |
|---|---|
| CC-999 | ✅ done |
DOC
  cat > "$repo/BACKLOG.md" <<'DOC'
## Index

| #  | Status | 主題 | 影響面 | 首次記錄 | Refs |
|----|--------|------|--------|----------|------|
| CC-111 | ⏸ deferred | pending work | ops | 2026-05-23 | pr:TBD |
DOC

  finalize_repo "$repo" v1.0.0

  run_check "$repo" --json
  assert_exit "$name" "$LAST_EXIT" 1 || return
  if ! python3 -c 'import sys, json; [json.loads(l) for l in sys.stdin if l.strip()]' <<< "$LAST_OUTPUT"; then
    fail "$name" "JSON parse failed"
    return
  fi
  assert_string_contains "$name" "$LAST_OUTPUT" '"unit":"summary"'
  assert_string_contains "$name" "$LAST_OUTPUT" '"unit":"U3-BACKLOG"'
  pass "$name"
}

run_test_quiet_keeps_findings() {
  local name="quiet-keeps-findings"
  local repo="$TMP_ROOT/$name"
  mkdir -p "$repo"
  git -C "$repo" init -q

  cat > "$repo/README.md" <<'DOC'
# pm-dispatch
No version marker.
DOC
  cat > "$repo/MILESTONES.md" <<'DOC'
## v1.0.0 — initial
| CC | status |
|---|---|
| CC-999 | ✅ done |
DOC
  cat > "$repo/BACKLOG.md" <<'DOC'
## Index

| #  | Status | 主題 | 影響面 | 首次記錄 | Refs |
|----|--------|------|--------|----------|------|
| CC-111 | ✅ closed 2026-05-23 | closed with real PR | ops | 2026-05-23 | pr:#999 |
DOC

  finalize_repo "$repo" v1.0.0

  run_check "$repo" --quiet
  assert_exit "$name" "$LAST_EXIT" 1 || return
  assert_string_contains "$name" "$LAST_OUTPUT" "WARN]"
  if grep -Fq "[OK]" <<< "$LAST_OUTPUT"; then
    fail "$name" "unexpected output: [OK]"
    return 1
  fi
  pass "$name"
}

run_test_repo_override() {
  local name="repo-override"
  local repo="$TMP_ROOT/$name"
  mkdir -p "$repo"
  git -C "$repo" init -q

  cat > "$repo/README.md" <<'DOC'
# pm-dispatch
Release: v1.0.0
DOC
  cat > "$repo/MILESTONES.md" <<'DOC'
## v1.0.0 — initial
| CC | status |
|---|---|
| CC-999 | ✅ done |
DOC
  cat > "$repo/BACKLOG.md" <<'DOC'
## Index

| #  | Status | 主題 | 影響面 | 首次記錄 | Refs |
|----|--------|------|--------|----------|------|
| CC-111 | ✅ closed 2026-05-23 | closed with real PR | ops | 2026-05-23 | pr:#999 |
DOC

  finalize_repo "$repo" v1.0.0

  run_check "$repo" --repo "$repo"
  assert_exit "$name" "$LAST_EXIT" 0 || return
  pass "$name"
}

run_test_copy_mode_parity() {
  local name="copy-mode-parity"
  local repo="$TMP_ROOT/$name"
  local copy_dir="/tmp/cdf-copy-$$"
  mkdir -p "$repo"
  git -C "$repo" init -q

  cat > "$repo/README.md" <<'DOC'
# pm-dispatch
Release: v1.0.0
DOC
  cat > "$repo/MILESTONES.md" <<'DOC'
## v1.0.0 — initial
| CC | status |
|---|---|
| CC-999 | ✅ done |
DOC
  cat > "$repo/BACKLOG.md" <<'DOC'
## Index

| #  | Status | 主題 | 影響面 | 首次記錄 | Refs |
|----|--------|------|--------|----------|------|
| CC-111 | ✅ closed 2026-05-23 | closed with real PR | ops | 2026-05-23 | pr:#999 |
DOC

  finalize_repo "$repo" v1.0.0

  rm -rf "$copy_dir"
  mkdir -p "$copy_dir"
  cp "$CHECK_SCRIPT" "$copy_dir/check-docs-freshness.sh"
  chmod +x "$copy_dir/check-docs-freshness.sh"

  bash "$CHECK_SCRIPT" --repo "$repo" >/dev/null
  local in_repo_exit="$?"
  (cd "$copy_dir" && bash ./check-docs-freshness.sh --repo "$repo") >/dev/null
  local in_copy_exit="$?"

  if [[ "$in_repo_exit" -ne "$in_copy_exit" ]]; then
    fail "$name" "copy-mode exit $in_copy_exit != in-repo exit $in_repo_exit"
    return
  fi

  pass "$name"
}

run_test_help() {
  local name="help-flag"
  local out
  out="$(bash "$CHECK_SCRIPT" --help 2>&1)"
  if [[ "$out" != *"Usage: check-docs-freshness.sh"* || "$out" != *"--repo"* ]]; then
    fail "$name" "help output missing expected usage"
    return
  fi
  pass "$name"
}

run_case() {
  local name="$1" fn="$2"
  should_run "$name" || return 0
  "$fn" || true
}

run_case "u1-readme-clean-exit-0" run_test_u1_readme_clean
run_case "u1-readme-stale-exit-2" run_test_u1_readme_stale
run_case "u1-readme-absent-exit-1" run_test_u1_readme_absent
run_case "u2-section-missing-exit-2" run_test_u2_section_missing
run_case "u2-status-stale-exit-2" run_test_u2_status_stale
run_case "u2-clean-exit-0" run_test_u2_clean
run_case "u3-closed-tbd-exit-2" run_test_u3_closed_tbd
run_case "u3-open-tbd-exit-1" run_test_u3_open_tbd
run_case "u3-clean-exit-0" run_test_u3_clean
run_case "aggregation-warning-only-exit-1" run_test_aggregation_warning_only
run_case "aggregation-blocking-warning-exit-2" run_test_aggregation_blocking_plus_warning
run_case "json-output-valid" run_test_json_output
run_case "quiet-keeps-findings" run_test_quiet_keeps_findings
run_case "repo-override" run_test_repo_override
run_case "copy-mode-parity" run_test_copy_mode_parity
run_case "help-flag" run_test_help

th_summary
