#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CHECK_SCRIPT="$REPO_ROOT/tools/lint/check-docs-freshness.sh"

# shellcheck source=tests/lib/test-harness.sh
. "$SCRIPT_DIR/../lib/test-harness.sh"
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
  # Verifies that check-docs-freshness.sh exits 0 and shows [OK] when
  # README.md version matches the current git tag and MILESTONES.md is clean.
  #
  # Steps:
  #   1. Create a repo with README.md version matching the v1.2.3 tag.
  #   2. Run check-docs-freshness.sh on the repo.
  #   3. Assert exit code is 0 and output contains "[OK]".
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

run_test_u4_cc532_scope_boundary() {
  # Verifies that the CC-532 milestone, backlog, and decision contracts retain
  # the same Linux/WSL2 boundary and explicitly authorize the closure handoff.
  #
  # Steps:
  #   1. Read the CC-532 summary, scope section, and superseding decision.
  #   2. Compare repo-layout, ownership, rollout, and deferred-distribution markers.
  #   3. Fail if the records disagree about closure producer/consumer ownership.
  local name="u4-cc532-scope-boundary-is-consistent"
  local milestone backlog_scope decision
  milestone="$(awk -F'|' '/^[[:space:]]*\|[[:space:]]*CC-532[[:space:]]*\|/ {
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", $3)
    print $3
    exit
  }' "$REPO_ROOT/MILESTONES.md")"
  backlog_scope="$(awk '
    /^## CC-532([[:space:]]|$)/ { in_scope=1; next }
    in_scope && /^## / { exit }
    in_scope { print }
  ' "$REPO_ROOT/BACKLOG.md")"
  decision="$(awk '
    /^## 2026-08-18: cc-532-supersedes-closure-scope-exclusion/ { in_scope=1 }
    in_scope && /^## / && !/2026-08-18: cc-532-supersedes-closure-scope-exclusion/ { exit }
    in_scope { print }
  ' "$REPO_ROOT/DECISIONS.md")"
  if [[ "$milestone" == *"Linux/WSL2"* &&
        "$milestone" == *"standalone distribution"* &&
        "$milestone" == *"defer"* &&
        "$milestone" == *"closure"* &&
        "$milestone" == *"CC-517"* &&
        "$milestone" == *"CC-511 Phase B"* &&
        "$backlog_scope" == *"Linux/WSL2"* &&
        "$backlog_scope" == *"Standalone distribution"* &&
        "$backlog_scope" == *"deferred"* &&
        "$backlog_scope" == *"CC-517"* &&
        "$backlog_scope" == *"CC-511 Phase B"* &&
        "$backlog_scope" == *"producer"* &&
        "$backlog_scope" == *"consumer"* &&
        "$decision" == *"Supersede"* &&
        "$decision" == *"CC-517"* &&
        "$decision" == *"CC-511 Phase B"* &&
        "$decision" == *"Rollout"* &&
        "$decision" == *"Parity evidence"* ]]; then
    pass "$name"
  else
    fail "$name" "CC-532 milestone/backlog scope boundary drifted"
  fi
}

run_test_u1_readme_stale() {
  # Verifies that check-docs-freshness.sh exits 2 and shows [FAIL] when
  # README.md declares an older version than the latest git tag.
  #
  # Steps:
  #   1. Create a repo where README.md has v1.2.2 but the tag is v1.2.3.
  #   2. Run check-docs-freshness.sh on the repo.
  #   3. Assert exit code is 2 and output contains "[FAIL]".
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
  # Verifies that check-docs-freshness.sh exits 1 and shows [WARN] when
  # README.md exists but contains no "Release: vX.Y.Z" version marker.
  #
  # Steps:
  #   1. Create a repo with README.md that has no version marker.
  #   2. Run check-docs-freshness.sh on the repo.
  #   3. Assert exit code is 1 and output contains "[WARN]".
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
  # Verifies that check-docs-freshness.sh exits 2 when the current git tag
  # exists but no corresponding section appears in MILESTONES.md.
  #
  # Steps:
  #   1. Create a repo tagged v0.1.0 with MILESTONES.md referencing v0.2.0.
  #   2. Run check-docs-freshness.sh on the repo.
  #   3. Assert exit code is 2 and output mentions the missing section for v0.1.0.
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
  # Verifies that check-docs-freshness.sh exits 2 when the MILESTONES.md
  # section for the current tag still shows planned/scheduled status.
  #
  # Steps:
  #   1. Create a repo tagged v0.2.0 whose MILESTONES.md section heading
  #      still carries the planned marker (status lives on the heading line).
  #   2. Run check-docs-freshness.sh on the repo.
  #   3. Assert exit code is 2 and output mentions "marked planned".
  local name="u2-status-stale-exit-2"
  local repo="$TMP_ROOT/$name"
  mkdir -p "$repo"
  git -C "$repo" init -q

  cat > "$repo/README.md" <<'DOC'
# pm-dispatch
Release: v0.2.0
DOC
  cat > "$repo/MILESTONES.md" <<'DOC'
## v0.2.0 — scheduled（規劃中 2026-05-20）

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

run_test_u2_body_quote_ok() {
  # Verifies that check-docs-freshness.sh does not flag a released section
  # whose body merely quotes historical planned-status text — the planned
  # marker is meaningful only on the "## vX.Y.Z" heading line itself.
  #
  # Steps:
  #   1. Create a repo tagged v0.2.0 whose MILESTONES.md heading is marked
  #      released but whose body quotes 「規劃中」 in a historical note.
  #   2. Run check-docs-freshness.sh on the repo.
  #   3. Assert exit code is 0 and no "marked planned" finding is emitted.
  local name="u2-body-quote-exit-0"
  local repo="$TMP_ROOT/$name"
  mkdir -p "$repo"
  git -C "$repo" init -q

  cat > "$repo/README.md" <<'DOC'
# pm-dispatch
Release: v0.2.0
DOC
  cat > "$repo/MILESTONES.md" <<'DOC'
## v0.2.0 — Cross-platform ops（✅ released 2026-05-22）

- 修正舊標頭殘留：「規劃中 2026-05-20」→ 標記已 released
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
  if grep -Fq "marked planned" <<< "$LAST_OUTPUT"; then
    fail "$name" "unexpected output: marked planned"
    return 1
  fi
  pass "$name"
}

run_test_u2_clean() {
  # Verifies that check-docs-freshness.sh exits 0 with no warnings when
  # README.md version, git tag, and MILESTONES.md section all agree.
  #
  # Steps:
  #   1. Create a fully consistent repo (README v0.2.0 = tag = MILESTONES section).
  #   2. Run check-docs-freshness.sh on the repo.
  #   3. Assert exit code is 0 and output contains no "[WARN]".
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
  # Verifies that check-docs-freshness.sh exits 2 when a closed BACKLOG row
  # still has pr:TBD instead of a real PR reference.
  #
  # Steps:
  #   1. Create a repo with a BACKLOG row marked closed but with pr:TBD.
  #   2. Run check-docs-freshness.sh on the repo.
  #   3. Assert exit code is 2 and output mentions "closed row with pr:TBD".
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
  # Verifies that check-docs-freshness.sh exits 1 (warning) when a non-closed
  # BACKLOG row still has pr:TBD as a placeholder reference.
  #
  # Steps:
  #   1. Create a repo with a deferred BACKLOG row with pr:TBD.
  #   2. Run check-docs-freshness.sh on the repo.
  #   3. Assert exit code is 1 and output mentions "non-closed row with pr:TBD".
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
  # Verifies that check-docs-freshness.sh exits 0 when a closed BACKLOG row
  # has a real PR reference (pr:#NNN, not pr:TBD).
  #
  # Steps:
  #   1. Create a repo with a closed BACKLOG row referencing pr:#999.
  #   2. Run check-docs-freshness.sh on the repo.
  #   3. Assert exit code is 0.
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
  # Verifies that check-docs-freshness.sh exits 1 when the only findings are
  # warnings (no blocking errors), and that the Summary: section is present.
  #
  # Steps:
  #   1. Create a repo with only warning-level issues (missing version marker).
  #   2. Run check-docs-freshness.sh on the repo.
  #   3. Assert exit code is 1, output contains "Summary:" and "[WARN]".
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
  # Verifies that check-docs-freshness.sh exits 2 when there are both
  # blocking errors and warnings, with blocking taking precedence.
  #
  # Steps:
  #   1. Create a repo with a stale README.md version (blocking) and pr:TBD (warning).
  #   2. Run check-docs-freshness.sh on the repo.
  #   3. Assert exit code is 2 and output contains "[FAIL]".
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
  # Verifies that check-docs-freshness.sh --json emits valid JSON lines
  # containing the expected unit keys (summary, U3-BACKLOG).
  #
  # Steps:
  #   1. Create a repo with a warning-level issue.
  #   2. Run check-docs-freshness.sh --json on the repo.
  #   3. Assert exit code is 1 and each output line is valid JSON containing expected keys.
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
  if ! printf '%s\n' "$LAST_OUTPUT" | jq -rs '.' > /dev/null 2>&1; then
    fail "$name" "JSON parse failed"
    return
  fi
  assert_string_contains "$name" "$LAST_OUTPUT" '"unit":"summary"'
  assert_string_contains "$name" "$LAST_OUTPUT" '"unit":"U3-BACKLOG"'
  pass "$name"
}

run_test_quiet_keeps_findings() {
  # Verifies that --quiet mode suppresses [OK] lines but still outputs
  # [WARN] findings so warnings are not silently hidden.
  #
  # Steps:
  #   1. Create a repo with a warning-level issue (absent README version marker).
  #   2. Run check-docs-freshness.sh --quiet on the repo.
  #   3. Assert exit code is 1, output contains "[WARN]", and no "[OK]" is present.
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
  # Verifies that --repo <path> overrides the default repo detection so
  # the check targets the specified directory instead of the current working dir.
  #
  # Steps:
  #   1. Create a clean repo at a custom path.
  #   2. Run check-docs-freshness.sh --repo <custom-path>.
  #   3. Assert exit code is 0 (clean repo = no issues).
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
  # Verifies that check-docs-freshness.sh produces the same exit code when
  # run from a copied location as when run from the original scripts/ directory.
  #
  # Steps:
  #   1. Create a clean repo; record the in-repo exit code.
  #   2. Copy check-docs-freshness.sh to a temp dir and run it from there.
  #   3. Assert both exit codes are equal (copy-mode parity preserved).
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
  # Verifies that check-docs-freshness.sh --help prints usage information
  # including the script name and --repo flag.
  #
  # Steps:
  #   1. Run check-docs-freshness.sh --help.
  #   2. Assert output contains "Usage: check-docs-freshness.sh".
  #   3. Assert output contains "--repo".
  local name="help-flag"
  local out
  out="$(bash "$CHECK_SCRIPT" --help 2>&1)"
  if [[ "$out" != *"Usage: check-docs-freshness.sh"* || "$out" != *"--repo"* ]]; then
    fail "$name" "help output missing expected usage"
    return
  fi
  pass "$name"
}

run_test_cli_missing_repo_arg() {
  # Verifies that check-docs-freshness.sh exits 2 with a usage error when
  # --repo is given without a path argument.
  #
  # Steps:
  #   1. Run check-docs-freshness.sh --repo (no value following).
  #   2. Assert exit code is 2.
  #   3. Assert output contains "--repo requires a path argument".
  local name="cli-missing-repo-arg"
  local out exit_code=0
  out="$(bash "$CHECK_SCRIPT" --repo 2>&1)" || exit_code=$?
  if [[ "$exit_code" -ne 2 ]]; then
    fail "$name" "expected exit 2, got $exit_code"
    return
  fi
  if [[ "$out" != *"--repo requires a path argument"* ]]; then
    fail "$name" "missing expected error in output: $out"
    return
  fi
  pass "$name"
}

run_test_cli_unknown_arg() {
  # Verifies that check-docs-freshness.sh exits 2 when given an unrecognized flag.
  #
  # Steps:
  #   1. Run check-docs-freshness.sh --bad-flag.
  #   2. Assert exit code is 2.
  #   3. Assert output contains "unknown argument".
  local name="cli-unknown-arg"
  local out exit_code=0
  out="$(bash "$CHECK_SCRIPT" --bad-flag 2>&1)" || exit_code=$?
  if [[ "$exit_code" -ne 2 ]]; then
    fail "$name" "expected exit 2, got $exit_code"
    return
  fi
  if [[ "$out" != *"unknown argument"* ]]; then
    fail "$name" "missing 'unknown argument' error in output: $out"
    return
  fi
  pass "$name"
}

run_test_cli_non_git_dir() {
  # Verifies that check-docs-freshness.sh exits 2 when the --repo path is not
  # a git repository.
  #
  # Steps:
  #   1. Create a temporary non-git directory.
  #   2. Run check-docs-freshness.sh --repo <tmpdir>.
  #   3. Assert exit code is 2 and output contains "not a git repository".
  local name="cli-non-git-dir"
  local tmpdir out exit_code=0
  tmpdir="$(mktemp -d)"
  out="$(bash "$CHECK_SCRIPT" --repo "$tmpdir" 2>&1)" || exit_code=$?
  rm -rf "$tmpdir"
  if [[ "$exit_code" -ne 2 ]]; then
    fail "$name" "expected exit 2, got $exit_code"
    return
  fi
  if [[ "$out" != *"not a git repository"* ]]; then
    fail "$name" "missing 'not a git repository' error in output: $out"
    return
  fi
  pass "$name"
}

run_test_u1_readme_tag_semver_order() {
  # Verifies that check-docs-freshness.sh selects the semantically latest tag even
  # when tag creation date order disagrees with semantic version order.
  # Regression guard: --sort=-creatordate would pick v1.2.3 if it was tagged after v1.3.0.
  #
  # Steps:
  #   1. Create a repo with README.md referencing v1.3.0.
  #   2. Tag v1.3.0 with an older GIT_COMMITTER_DATE, then v1.2.3 with a newer date.
  #      (creatordate order: v1.2.3 newest; semantic order: v1.3.0 is highest)
  #   3. Run check-docs-freshness.sh.
  #   4. Assert exit 0 and output contains [OK] - v1.3.0 correctly chosen as latest.
  local name="u1-readme-tag-semver-order"
  local repo="$TMP_ROOT/$name"
  mkdir -p "$repo"
  git -C "$repo" init -q

  cat > "$repo/README.md" <<'DOC'
# pm-dispatch
Release: v1.3.0
DOC
  cat > "$repo/MILESTONES.md" <<'DOC'
## v1.3.0 - done section
| CC | status |
|---|---|
| CC-001 | ✅ done |

## v1.2.3 - done section
| CC | status |
|---|---|
| CC-001 | ✅ done |
DOC
  cat > "$repo/BACKLOG.md" <<'DOC'
## Index

| #  | Status | 主題 | 影響面 | 首次記錄 | Refs |
|----|--------|------|--------|----------|------|
| CC-001 | ✅ closed 2026-05-23 | test | ops | 2026-05-23 | pr:#001 |
DOC

  git -C "$repo" add README.md MILESTONES.md BACKLOG.md
  git -C "$repo" -c user.name=ci-bot -c user.email=ci-bot@example.com commit -qm "fixture" >/dev/null

  # Create v1.3.0 with older date, v1.2.3 with newer date.
  # --sort=-creatordate would incorrectly pick v1.2.3; max_version correctly picks v1.3.0.
  GIT_COMMITTER_DATE="2026-01-01T00:00:00+0000" git -C "$repo" tag v1.3.0
  GIT_COMMITTER_DATE="2026-06-01T00:00:00+0000" git -C "$repo" tag v1.2.3

  run_check "$repo"
  assert_exit "$name" "$LAST_EXIT" 0 || return
  assert_string_contains "$name" "$LAST_OUTPUT" "OK]"
  pass "$name"
}

run_case() {
  local name="$1" fn="$2"
  should_run "$name" || return 0
  "$fn" || true
}

run_case "u1-readme-tag-semver-order" run_test_u1_readme_tag_semver_order
run_case "u4-cc532-scope-boundary-is-consistent" run_test_u4_cc532_scope_boundary
run_case "u1-readme-clean-exit-0" run_test_u1_readme_clean
run_case "u1-readme-stale-exit-2" run_test_u1_readme_stale
run_case "u1-readme-absent-exit-1" run_test_u1_readme_absent
run_case "u2-section-missing-exit-2" run_test_u2_section_missing
run_case "u2-status-stale-exit-2" run_test_u2_status_stale
run_case "u2-body-quote-exit-0" run_test_u2_body_quote_ok
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
run_case "cli-missing-repo-arg" run_test_cli_missing_repo_arg
run_case "cli-unknown-arg" run_test_cli_unknown_arg
run_case "cli-non-git-dir" run_test_cli_non_git_dir

th_summary
