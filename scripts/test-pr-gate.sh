#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

# CC-103b introduced `--executor codex|claude|auto` on pr-gate.sh with
# auto-detect via `command -v codex`. Existing tests in this file
# assume the codex execution path (brief file written, dispatch stub
# invoked). On CI runners codex is absent, so auto-detect picks claude
# mode → emits handover instead of brief.md → tests fail. Prepend a
# stub `codex` bin to PATH so auto-detect picks codex for legacy
# tests. test-pr-gate-profile.sh remains the canonical coverage for
# claude / auto-detect / explicit --executor behaviors.
_codex_stub_bin="$TMP_ROOT/.codex-stub-bin"
mkdir -p "$_codex_stub_bin"
printf '#!/usr/bin/env bash\nexit 0\n' > "$_codex_stub_bin/codex"
chmod +x "$_codex_stub_bin/codex"
export PATH="$_codex_stub_bin:$PATH"

# shellcheck source=scripts/lib/test-harness.sh
. "$SCRIPT_DIR/lib/test-harness.sh"
legacy_tmp_root="$TMP_ROOT"
th_init "$@"
TMP_ROOT="$tmp_root"
trap 'rm -rf "$tmp_root" "$legacy_tmp_root"' EXIT

assert_not_contains() {
  local name="$1" file="$2" needle="$3"
  if grep -Fq -- "$needle" "$file"; then
    fail "$name" "unexpected output: $needle"
    return 1
  fi
}

create_runner() {
  local dir="$1"
  mkdir -p "$dir"
  cp "$REPO_ROOT/scripts/pr-gate.sh" "$dir/pr-gate.sh"
  chmod +x "$dir/pr-gate.sh"
  cat > "$dir/codex-dispatch.sh" <<'STUB_EOF'
#!/usr/bin/env bash
set -euo pipefail

brief_file=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --brief-file) brief_file="$2"; shift 2;;
    --cd|--timeout) shift 2;;
    *) shift;;
  esac
done

printf 'DISPATCH_STUB:%s\n' "${CODEX_GATE_STUB_MODE:-success}"

if [[ -n "${CODEX_GATE_BRIEF_EXISTS_MARKER:-}" ]]; then
  if [[ -f "$brief_file" && "$brief_file" == */.codex-briefs/pr-gate-*.md ]]; then
    printf 'brief-present\n' > "$CODEX_GATE_BRIEF_EXISTS_MARKER"
  else
    printf 'brief-missing-or-wrong-path: %s\n' "$brief_file" >&2
    exit 3
  fi
fi

if [[ -n "${CODEX_GATE_CAPTURE_BRIEF:-}" ]]; then
  cp "$brief_file" "$CODEX_GATE_CAPTURE_BRIEF"
fi

# Simulate reviewer-side injection (tracked file modification during reviewer dispatch).
if [[ -n "${CODEX_GATE_STUB_INJECT_FILE:-}" && "$brief_file" != *-synthesis.md ]]; then
  printf 'injected\n' >> "$CODEX_GATE_STUB_INJECT_FILE"
fi

# Simulate synthesis-side injection (tracked file modification during synthesis dispatch).
if [[ -n "${CODEX_GATE_STUB_SYNTHESIS_INJECT_FILE:-}" && "$brief_file" == *-synthesis.md ]]; then
  printf 'injected-by-synthesis\n' >> "$CODEX_GATE_STUB_SYNTHESIS_INJECT_FILE"
fi

# Simulate synthesis-side artifact tampering: synthesis modifies a reviewer output file.
# CODEX_GATE_STUB_SYNTHESIS_TAMPER_ARTIFACT: path to the reviewer artifact to tamper with.
if [[ -n "${CODEX_GATE_STUB_SYNTHESIS_TAMPER_ARTIFACT:-}" && "$brief_file" == *-synthesis.md ]]; then
  printf 'tampered-by-synthesis\n' >> "$CODEX_GATE_STUB_SYNTHESIS_TAMPER_ARTIFACT"
fi

# Simulate prefix-only verdict (loose regex bypass): writes "Verdict: approved" (invalid token
# with the right prefix) to verify the anchored regex rejects it.
# CODEX_GATE_STUB_VERDICT_PREFIX_ONLY=1: write an invalid prefix verdict instead of a valid one.
if [[ "${CODEX_GATE_STUB_VERDICT_PREFIX_ONLY:-}" == "1" && "$brief_file" != *-synthesis.md ]]; then
  output_path=$(grep -o '\- new:.*' "$brief_file" | head -1 | awk '{print $NF}')
  if [[ -n "$output_path" ]]; then
    mkdir -p "$(dirname "$output_path")"
    printf '## stub-reviewer — approved\nVerdict: approved. Prefix-only bypass attempt.\n' > "$output_path"
  fi
  exit 0
fi

# Simulate multiple valid verdict lines in a reviewer artifact: first "approve", then "block".
# Verifies the gate rejects ambiguous output rather than silently taking the first match.
# CODEX_GATE_STUB_MULTIPLE_VERDICTS=1: write two valid verdict lines to the reviewer output.
if [[ "${CODEX_GATE_STUB_MULTIPLE_VERDICTS:-}" == "1" && "$brief_file" != *-synthesis.md ]]; then
  output_path=$(grep -o '\- new:.*' "$brief_file" | head -1 | awk '{print $NF}')
  if [[ -n "$output_path" ]]; then
    mkdir -p "$(dirname "$output_path")"
    printf '## stub-reviewer — approve\nVerdict: approve. First verdict line.\nSome additional content.\nVerdict: block. Second verdict line.\n' > "$output_path"
  fi
  exit 0
fi

write_frontmatter_stub_gate_result() {
  local output_path="$1"
  local final_verdict="${2:-GO}"
  local final_line="Final: ${final_verdict}"

  # CC-252 regression seam: when CODEX_GATE_STUB_BOLD_FINAL=1, emit the Final
  # line wrapped in markdown bold (simulates codex applying prose emphasis).
  # The parser MUST reject this — Final line is contract-locked to plain text.
  if [[ "${CODEX_GATE_STUB_BOLD_FINAL:-}" == "1" ]]; then
    final_line="**Final: ${final_verdict}**"
  fi

  cat > "$output_path" << STUB_GATE_EOF
---
gate_result_version: pr_gate_result_v1
final: ${final_verdict}
tier: express
mode: parallel
most_severe: approve
reviewers:
  critic: approve
  qa-tester: pass
  architecture-reviewer: approve
  security-reviewer: pass
  risk-reviewer: pass
escalation:
  recommended: false
  reviewers: []
  reason: []
---

# PR-Gate Result — stub tier (parallel codex mode)
**Date**: 2026-01-01
**Reviewers**: stub
**Not reviewed**: none

## stub-reviewer — advise
- stub finding

## Cross-Reviewer Overlaps
none

## Coverage Notes
**Dimensions not covered**: none

## Gate Conclusion
**Overall verdict**: pass
**Most severe individual verdict**: pass
${final_line}
Required fixes before GO: none

## Escalation
**Recommended**: false
**Reviewers**: none
**Reason**:
- none

Rationale: Stub gate output.
STUB_GATE_EOF
}

# Determine effective mode: synthesis briefs can have their own mode override.
if [[ "$brief_file" == *-synthesis.md ]]; then
  effective_mode="${CODEX_GATE_STUB_SYNTHESIS_MODE:-${CODEX_GATE_STUB_MODE:-success}}"
else
  effective_mode="${CODEX_GATE_STUB_MODE:-success}"
fi

case "$effective_mode" in
  fail)
    # Non-zero exit — caught by FAILED_REVIEWERS check.
    exit 1
    ;;
  no-output)
    # Exits 0 without writing output file — simulates a session that silently
    # failed its task (caught by missing-output or synthesis-output check).
    exit 0
    ;;
  no-verdict)
    # Writes a non-empty output file but omits the Verdict line — simulates
    # malformed reviewer output (caught by reviewer structure validation).
    output_path=$(grep -o '\- new:.*' "$brief_file" | head -1 | awk '{print $NF}')
    if [[ -n "$output_path" ]]; then
      mkdir -p "$(dirname "$output_path")"
      printf '## stub-reviewer\nSome content without a verdict line.\n' > "$output_path"
    fi
    exit 0
    ;;
  *)
    # Success: write a stub output file so the gate's output validation passes.
    output_path=$(grep -o '\- new:.*' "$brief_file" | head -1 | awk '{print $NF}')
    if [[ -n "$output_path" ]]; then
      mkdir -p "$(dirname "$output_path")"
      if [[ "$brief_file" == *-synthesis.md ]]; then
        # Synthesis brief: write a minimal but structurally valid gate result.
        # CODEX_GATE_STUB_SYNTHESIS_FINAL controls the Final: line (default GO).
        # CODEX_GATE_STUB_SYNTHESIS_EXTRA_FINAL: if set, appends a second Final: line
        # to simulate a duplicate/contradictory conclusion artifact.
        final_verdict="${CODEX_GATE_STUB_SYNTHESIS_FINAL:-GO}"
        extra_final_line=""
        if [[ -n "${CODEX_GATE_STUB_SYNTHESIS_EXTRA_FINAL:-}" ]]; then
          extra_final_line="Final: ${CODEX_GATE_STUB_SYNTHESIS_EXTRA_FINAL}"$'\n'
        fi
        write_frontmatter_stub_gate_result "$output_path" "$final_verdict"
        if [[ -n "$extra_final_line" ]]; then
          printf '%s' "$extra_final_line" >> "$output_path"
        fi
      else
        # Sequential result file should include frontmatter blocks and escalation section.
        if [[ "$brief_file" =~ ^.*/pr-gate-[0-9]{8}-[0-9]{6}\.md$ || \
              "$brief_file" =~ ^.*/pr-gate-claude-[0-9]{8}-[0-9]{6}-combined\.md$ ]]; then
          final_verdict="${CODEX_GATE_STUB_SYNTHESIS_FINAL:-GO}"
          write_frontmatter_stub_gate_result "$output_path" "$final_verdict"
          exit 0
        fi
        # Reviewer brief: CODEX_GATE_STUB_VERDICT controls the verdict line (default advise).
        stub_verdict="${CODEX_GATE_STUB_VERDICT:-advise}"
        printf '## stub-reviewer — %s\nVerdict: %s. Stub output.\n' "$stub_verdict" "$stub_verdict" > "$output_path"
        if [[ "$(basename "$output_path")" == pr-gate-result-* || "$(basename "$output_path")" == gate-* ]]; then
          printf 'Final: GO\n' >> "$output_path"
        fi
      fi
    fi
    # Simulate cross-reviewer artifact tampering in --parallel mode (reviewer brief only).
    # CODEX_GATE_STUB_CROSS_TAMPER_REVIEWER: reviewer name that performs the tamper.
    # CODEX_GATE_STUB_CROSS_TAMPER_VICTIM: reviewer name whose artifact gets tampered.
    # After writing own output the tamper reviewer waits until the victim's
    # artifact exists, then overwrites it. The bounded poll makes the handshake
    # deterministic without relying on a fixed scheduler delay.
    if [[ -n "${CODEX_GATE_STUB_CROSS_TAMPER_REVIEWER:-}" && \
          -n "${CODEX_GATE_STUB_CROSS_TAMPER_VICTIM:-}" && \
          "$brief_file" == *"-${CODEX_GATE_STUB_CROSS_TAMPER_REVIEWER}.md" ]]; then
      brief_basename="$(basename "$brief_file" .md)"
      ts_and_rev="${brief_basename#pr-gate-}"
      ts="${ts_and_rev%-*}"
      work_dir="$(cd "$(dirname "$(dirname "$brief_file")")" && pwd)"
      victim_output="$work_dir/.gate-results/reviewer-${CODEX_GATE_STUB_CROSS_TAMPER_VICTIM}-${ts}.md"
      wait_start=$SECONDS
      while [[ ! -s "$victim_output" ]]; do
        if (( SECONDS - wait_start >= 5 )); then
          printf 'timed out waiting for cross-tamper victim artifact: %s\n' "$victim_output" >&2
          exit 1
        fi
        sleep 0.01
      done
      printf 'tampered-by-cross-reviewer\n' >> "$victim_output"
    fi
    exit 0
    ;;
esac
STUB_EOF
  chmod +x "$dir/codex-dispatch.sh"
}

create_agents() {
  local home="$1"
  shift
  mkdir -p "$home/.claude/agents"
  local reviewer
  for reviewer in "$@"; do
    printf '# %s\n\nReviewer fixture.\n' "$reviewer" > "$home/.claude/agents/$reviewer.md"
  done
}

write_managed_gitignore() {
  printf '.agent-trace/\n.codex-briefs/\n.gate-results/\n.agents/\n' > .gitignore
}

create_repo() {
  local repo="$1" mode="${2:-clean}"
  git init -q -b main "$repo"
  (
    cd "$repo"
    git config user.email test@example.com
    git config user.name 'Gate Test'
    printf 'initial\n' > README.md
    write_managed_gitignore
    git add README.md .gitignore
    git commit -q -m initial
    case "$mode" in
      clean) ;;
      docs)
        printf 'docs change\n' >> README.md
        ;;
      many)
        for n in $(seq 1 130); do
          printf 'line %s\n' "$n" >> app.txt
        done
        ;;
      *)
        printf 'unknown repo mode: %s\n' "$mode" >&2
        exit 2
        ;;
    esac
  )
}

# create_repo_with_branch: initial commit on main + feature branch with committed changes.
# Used to test tier detection via git diff BASE...HEAD (not working-tree fallback).
create_repo_with_branch() {
  local repo="$1" mode="${2:-standard}"
  git init -q -b main "$repo"
  (
    cd "$repo"
    git config user.email test@example.com
    git config user.name 'Gate Test'
    printf 'initial\n' > README.md
    write_managed_gitignore
    git add README.md .gitignore
    git commit -q -m initial
    git checkout -q -b feature
    case "$mode" in
      standard)
        # ~150 non-doc lines → standard tier (100 ≤ LINES < 500)
        for n in $(seq 1 150); do printf 'func Fn%s() {}\n' "$n"; done > app.go
        git add app.go
        git commit -q -m "add code"
        ;;
      full-lines)
        # ~600 non-doc lines → full tier (LINES > 500)
        for n in $(seq 1 600); do printf 'func Fn%s() {}\n' "$n"; done > app.go
        git add app.go
        git commit -q -m "add large code"
        ;;
      full-sensitive)
        # sensitive filename → full tier regardless of line count
        printf 'package main\n' > auth-handler.go
        git add auth-handler.go
        git commit -q -m "add auth handler"
        ;;
      *)
        printf 'unknown mode: %s\n' "$mode" >&2; exit 2 ;;
    esac
  )
}

run_gate() {
  local home="$1" runner="$2" repo="$3" out="$4" err="$5"
  shift 5
  set +e
  HOME="$home" "$runner/pr-gate.sh" --cd "$repo" "$@" > "$out" 2> "$err"
  local code=$?
  return "$code"
}

test_tier_detection() {
  local name="tier-detection"
  should_run "$name" || return 0
  local dir="$TMP_ROOT/$name"
  local home="$dir/home" repo="$dir/repo" runner="$dir/runner"
  local out="$dir/out" err="$dir/err" brief="$dir/brief.md"
  mkdir -p "$dir"
  create_runner "$runner"
  create_agents "$home" critic qa-tester architecture-reviewer security-reviewer risk-reviewer
  create_repo "$repo" docs

  set +e
  CODEX_GATE_CAPTURE_BRIEF="$brief" run_gate "$home" "$runner" "$repo" "$out" "$err" --base main
  local code=$?
  set -e
  if [[ "$code" -ne 0 ]]; then
    fail "$name" "exit $code, expected 0"
    return
  fi
  assert_file_contains "$name" "$out" "DISPATCH_STUB:success" || return
  assert_file_contains "$name" "$brief" "Tier: express" || return
  assert_file_contains "$name" "$brief" "Reviewers: critic,qa-tester" || return
  pass "$name"
}

test_pr_gate_does_not_mutate_gitignore() {
  local name="pr-gate-does-not-mutate-gitignore"
  should_run "$name" || return 0
  local dir="$TMP_ROOT/$name"
  local home="$dir/home" repo="$dir/repo" runner="$dir/runner"
  local out="$dir/out" err="$dir/err"
  mkdir -p "$dir"
  create_runner "$runner"
  create_agents "$home" critic qa-tester architecture-reviewer security-reviewer risk-reviewer
  git init -q -b main "$repo"
  (
    cd "$repo"
    git config user.email test@example.com
    git config user.name 'Gate Test'
    printf 'initial\n' > README.md
    printf '*.log\n' > .gitignore
    git add README.md .gitignore
    git commit -q -m initial
    printf 'docs change\n' >> README.md
  )
  local before after
  before="$(sha256sum "$repo/.gitignore" | awk '{print $1}')"

  set +e
  run_gate "$home" "$runner" "$repo" "$out" "$err" --base main
  local code=$?
  set -e
  if [[ "$code" -ne 0 ]]; then
    fail "$name" "exit $code, expected 0"
    return
  fi
  after="$(sha256sum "$repo/.gitignore" | awk '{print $1}')"
  if [[ "$after" != "$before" ]]; then
    fail "$name" ".gitignore checksum changed"
    return
  fi
  assert_not_contains "$name" "$repo/.gitignore" "Claude agent" || return
  assert_not_contains "$name" "$repo/.gitignore" "codex" || return
  pass "$name"
}

test_missing_reviewer_agent() {
  local name="missing-reviewer-agent"
  should_run "$name" || return 0
  local dir="$TMP_ROOT/$name"
  local home="$dir/home" repo="$dir/repo" runner="$dir/runner"
  local out="$dir/out" err="$dir/err"
  mkdir -p "$dir"
  create_runner "$runner"
  create_agents "$home" critic
  create_repo "$repo" docs

  set +e
  run_gate "$home" "$runner" "$repo" "$out" "$err" --base main
  local code=$?
  set -e
  if [[ "$code" -eq 0 ]]; then
    fail "$name" "expected non-zero exit"
    return
  fi
  assert_file_contains "$name" "$err" "Error: reviewer agent file not found:" || return
  assert_not_contains "$name" "$out" "DISPATCH_STUB" || return
  pass "$name"
}

test_invalid_base_ref() {
  local name="invalid-base-ref"
  should_run "$name" || return 0
  local dir="$TMP_ROOT/$name"
  local home="$dir/home" repo="$dir/repo" runner="$dir/runner"
  local out="$dir/out" err="$dir/err"
  mkdir -p "$dir"
  create_runner "$runner"
  create_agents "$home" critic qa-tester architecture-reviewer security-reviewer risk-reviewer
  create_repo "$repo" docs

  set +e
  run_gate "$home" "$runner" "$repo" "$out" "$err" --base nonexistent-branch-12345
  local code=$?
  set -e
  if [[ "$code" -eq 0 ]]; then
    fail "$name" "expected non-zero exit"
    return
  fi
  assert_file_contains "$name" "$err" "Error: base ref not found: nonexistent-branch-12345" || return
  assert_not_contains "$name" "$out" "DISPATCH_STUB" || return
  pass "$name"
}

test_no_changed_files() {
  local name="no-changed-files"
  should_run "$name" || return 0
  local dir="$TMP_ROOT/$name"
  local home="$dir/home" repo="$dir/repo" runner="$dir/runner"
  local out="$dir/out" err="$dir/err"
  mkdir -p "$dir"
  create_runner "$runner"
  create_agents "$home" critic qa-tester architecture-reviewer security-reviewer risk-reviewer
  create_repo "$repo" clean

  set +e
  run_gate "$home" "$runner" "$repo" "$out" "$err" --base main
  local code=$?
  set -e
  if [[ "$code" -eq 0 ]]; then
    fail "$name" "expected non-zero exit"
    return
  fi
  assert_file_contains "$name" "$err" "Error: no changed files detected against main" || return
  assert_not_contains "$name" "$out" "DISPATCH_STUB" || return
  pass "$name"
}

test_reviewers_override_skips_tier_detection() {
  local name="reviewers-override"
  should_run "$name" || return 0
  local dir="$TMP_ROOT/$name"
  local home="$dir/home" repo="$dir/repo" runner="$dir/runner"
  local out="$dir/out" err="$dir/err" brief="$dir/brief.md"
  mkdir -p "$dir"
  create_runner "$runner"
  create_agents "$home" critic
  create_repo "$repo" many

  set +e
  CODEX_GATE_CAPTURE_BRIEF="$brief" run_gate "$home" "$runner" "$repo" "$out" "$err" --base main --reviewers critic --parallel
  local code=$?
  set -e
  if [[ "$code" -ne 0 ]]; then
    fail "$name" "exit $code, expected 0"
    return
  fi
  # Parallel mode: CAPTURE_BRIEF receives the synthesis brief (last dispatch)
  assert_file_contains "$name" "$brief" "Tier: targeted" || return
  assert_file_contains "$name" "$brief" "Reviewers: critic" || return
  # Synthesis brief embeds reviewer findings inline — no read: paths to reviewer output files
  assert_file_contains "$name" "$brief" "--- critic findings ---" || return
  assert_not_contains "$name" "$brief" "reviewer-critic-" || return
  assert_not_contains "$name" "$brief" "read: $home/.claude/agents/qa-tester.md" || return
  pass "$name"
}

test_brief_file_inside_workdir() {
  local name="brief-file-inside-workdir"
  should_run "$name" || return 0
  local dir="$TMP_ROOT/$name"
  local home="$dir/home" repo="$dir/repo" runner="$dir/runner"
  local out="$dir/out" err="$dir/err" marker="$dir/marker"
  mkdir -p "$dir"
  create_runner "$runner"
  create_agents "$home" critic qa-tester architecture-reviewer security-reviewer risk-reviewer
  create_repo "$repo" docs

  set +e
  CODEX_GATE_BRIEF_EXISTS_MARKER="$marker" run_gate "$home" "$runner" "$repo" "$out" "$err" --base main
  local code=$?
  set -e
  if [[ "$code" -ne 0 ]]; then
    fail "$name" "exit $code, expected 0"
    return
  fi
  assert_file_contains "$name" "$marker" "brief-present" || return
  pass "$name"
}

test_brief_cleanup_on_dispatch_failure() {
  local name="brief-cleanup-on-failure"
  should_run "$name" || return 0
  local dir="$TMP_ROOT/$name"
  local home="$dir/home" repo="$dir/repo" runner="$dir/runner"
  local out="$dir/out" err="$dir/err"
  mkdir -p "$dir"
  create_runner "$runner"
  create_agents "$home" critic qa-tester architecture-reviewer security-reviewer risk-reviewer
  create_repo "$repo" docs

  set +e
  CODEX_GATE_STUB_MODE=fail run_gate "$home" "$runner" "$repo" "$out" "$err" --base main
  local code=$?
  set -e
  if [[ "$code" -eq 0 ]]; then
    fail "$name" "expected non-zero exit"
    return
  fi
  if compgen -G "$repo/.codex-briefs/pr-gate-*.md" > /dev/null; then
    fail "$name" "brief file remained after dispatch failure"
    return
  fi
  pass "$name"
}

test_output_directory_created() {
  local name="output-directory-created"
  should_run "$name" || return 0
  local dir="$TMP_ROOT/$name"
  local home="$dir/home" repo="$dir/repo" runner="$dir/runner"
  local out="$dir/out" err="$dir/err" result="$dir/output/subdir/result.md"
  mkdir -p "$dir"
  create_runner "$runner"
  create_agents "$home" critic qa-tester architecture-reviewer security-reviewer risk-reviewer
  create_repo "$repo" docs

  set +e
  CODEX_GATE_STUB_MODE=fail run_gate "$home" "$runner" "$repo" "$out" "$err" --base main --output "$result"
  local code=$?
  set -e
  if [[ "$code" -eq 0 ]]; then
    fail "$name" "expected non-zero exit"
    return
  fi
  if [[ ! -d "$(dirname "$result")" ]]; then
    fail "$name" "output directory was not created"
    return
  fi
  pass "$name"
}

test_parallel_launches_per_reviewer() {
  # Verifies --parallel mode launches one dispatch per reviewer and a synthesis.
  local name="parallel-launches-per-reviewer"
  should_run "$name" || return 0
  local dir="$TMP_ROOT/$name"
  local home="$dir/home" repo="$dir/repo" runner="$dir/runner"
  local out="$dir/out" err="$dir/err"
  mkdir -p "$dir"
  create_runner "$runner"
  create_agents "$home" critic qa-tester
  create_repo "$repo" docs

  set +e
  run_gate "$home" "$runner" "$repo" "$out" "$err" --base main --tier express --parallel
  local code=$?
  set -e
  if [[ "$code" -ne 0 ]]; then
    fail "$name" "exit $code, expected 0"
    return
  fi
  assert_file_contains "$name" "$out" "[parallel] launched critic" || return
  assert_file_contains "$name" "$out" "[parallel] launched qa-tester" || return
  assert_file_contains "$name" "$out" "[synthesis] running PM consolidation" || return
  pass "$name"
}

test_sequential_flag_produces_combined_brief() {
  # Verifies --sequential produces the combined reviewer brief with the
  # "Process each reviewer IN ORDER" instruction.
  local name="sequential-flag-combined-brief"
  should_run "$name" || return 0
  local dir="$TMP_ROOT/$name"
  local home="$dir/home" repo="$dir/repo" runner="$dir/runner"
  local out="$dir/out" err="$dir/err" brief="$dir/brief.md"
  mkdir -p "$dir"
  create_runner "$runner"
  create_agents "$home" critic qa-tester architecture-reviewer security-reviewer risk-reviewer
  create_repo "$repo" docs

  set +e
  CODEX_GATE_CAPTURE_BRIEF="$brief" run_gate "$home" "$runner" "$repo" "$out" "$err" --base main --sequential
  local code=$?
  set -e
  if [[ "$code" -ne 0 ]]; then
    fail "$name" "exit $code, expected 0"
    return
  fi
  assert_file_contains "$name" "$brief" "Process each reviewer IN ORDER" || return
  assert_not_contains "$name" "$out" "[parallel]" || return
  assert_not_contains "$name" "$out" "[synthesis]" || return
  pass "$name"
}

test_failed_reviewer_aborts_gate() {
  # Verifies that when reviewer dispatches fail the gate exits non-zero and
  # prints an error — synthesis must not run on incomplete reviewer data.
  local name="failed-reviewer-aborts-gate"
  should_run "$name" || return 0
  local dir="$TMP_ROOT/$name"
  local home="$dir/home" repo="$dir/repo" runner="$dir/runner"
  local out="$dir/out" err="$dir/err"
  mkdir -p "$dir"
  create_runner "$runner"
  create_agents "$home" critic qa-tester architecture-reviewer security-reviewer risk-reviewer
  create_repo "$repo" docs

  set +e
  CODEX_GATE_STUB_MODE=fail run_gate "$home" "$runner" "$repo" "$out" "$err" --base main --parallel
  local code=$?
  set -e
  if [[ "$code" -eq 0 ]]; then
    fail "$name" "expected non-zero exit when reviewers fail"
    return
  fi
  assert_file_contains "$name" "$err" "reviewer session(s) failed:" || return
  # Synthesis must not run after reviewer failure
  assert_not_contains "$name" "$out" "[synthesis]" || return
  pass "$name"
}

_make_go_repo_with_test() {
  # Helper: init a repo with app.go + app_test.go on main; feature branch changes app.go only.
  local repo="$1"
  git init -q -b main "$repo"
  (
    cd "$repo"
    git config user.email test@example.com
    git config user.name 'Gate Test'
    printf 'package main\nfunc Add(a, b int) int { return a + b }\n' > app.go
    printf 'package main\nimport "testing"\nfunc TestAdd(t *testing.T) {}\n' > app_test.go
    write_managed_gitignore
    git add app.go app_test.go .gitignore
    git commit -q -m initial
    git checkout -q -b feature
    printf 'package main\nfunc Add(a, b int) int { return a + b + 0 }\n' > app.go
    git add app.go
    git commit -q -m "change app.go only"
  )
}

_make_ts_repo_with_test() {
  # Helper: init a repo with src/format.ts + a test file; feature branch changes format.ts only.
  # Args: repo-path  test-path  test-content
  local repo="$1" test_path="$2" test_content="$3"
  git init -q -b main "$repo"
  (
    cd "$repo"
    git config user.email test@example.com
    git config user.name 'Gate Test'
    mkdir -p "$(dirname "$test_path")"
    printf 'export function fmt(s: string) { return s; }\n' > src/format.ts
    printf '%s\n' "$test_content" > "$test_path"
    write_managed_gitignore
    git add src/format.ts "$test_path" .gitignore
    git commit -q -m initial
    git checkout -q -b feature
    printf 'export function fmt(s: string) { return s.trim(); }\n' > src/format.ts
    git add src/format.ts
    git commit -q -m "change format.ts only"
  )
}

test_adjacent_go_test_included() {
  # Verifies that a *_test.go companion to a changed .go source file is
  # automatically included in the reviewer brief even when not in the diff.
  # Uses --sequential so CAPTURE_BRIEF holds the combined brief that lists all
  # review files, directly proving inclusion (not just the stdout counter).
  local name="adjacent-go-test-included"
  should_run "$name" || return 0
  local dir="$TMP_ROOT/$name"
  local home="$dir/home" repo="$dir/repo" runner="$dir/runner"
  local out="$dir/out" err="$dir/err" brief="$dir/brief.md"
  mkdir -p "$dir"
  create_runner "$runner"
  create_agents "$home" critic qa-tester architecture-reviewer security-reviewer risk-reviewer
  _make_go_repo_with_test "$repo"

  set +e
  CODEX_GATE_CAPTURE_BRIEF="$brief" run_gate "$home" "$runner" "$repo" "$out" "$err" --base main --sequential
  local code=$?
  set -e
  if [[ "$code" -ne 0 ]]; then
    fail "$name" "exit $code, expected 0"
    return
  fi
  assert_file_contains "$name" "$out" "adjacent test files added: 1" || return
  assert_file_contains "$name" "$brief" "app_test.go" || return
  pass "$name"
}

test_adjacent_ts_test_in_tests_dir() {
  # Verifies that __tests__/<name>.test.ts adjacent to a changed .ts source
  # file is included in the reviewer brief.
  local name="adjacent-ts-test-tests-dir"
  should_run "$name" || return 0
  local dir="$TMP_ROOT/$name"
  local home="$dir/home" repo="$dir/repo" runner="$dir/runner"
  local out="$dir/out" err="$dir/err" brief="$dir/brief.md"
  mkdir -p "$dir" "$dir/repo/src"
  create_runner "$runner"
  create_agents "$home" critic qa-tester architecture-reviewer security-reviewer risk-reviewer
  _make_ts_repo_with_test "$repo" "src/__tests__/format.test.ts" \
    "import { fmt } from '../format'; test('fmt', () => {});"

  set +e
  CODEX_GATE_CAPTURE_BRIEF="$brief" run_gate "$home" "$runner" "$repo" "$out" "$err" --base main --sequential
  local code=$?
  set -e
  if [[ "$code" -ne 0 ]]; then
    fail "$name" "exit $code, expected 0"
    return
  fi
  assert_file_contains "$name" "$out" "adjacent test files added: 1" || return
  assert_file_contains "$name" "$brief" "format.test.ts" || return
  pass "$name"
}

test_adjacent_ts_test_tsx_variant() {
  # Verifies that __tests__/<name>.test.tsx is recognised as an adjacent test.
  local name="adjacent-ts-test-tsx-variant"
  should_run "$name" || return 0
  local dir="$TMP_ROOT/$name"
  local home="$dir/home" repo="$dir/repo" runner="$dir/runner"
  local out="$dir/out" err="$dir/err" brief="$dir/brief.md"
  mkdir -p "$dir"
  create_runner "$runner"
  create_agents "$home" critic qa-tester architecture-reviewer security-reviewer risk-reviewer
  _make_ts_repo_with_test "$repo" "src/__tests__/format.test.tsx" \
    "import { fmt } from '../format'; test('fmt', () => {});"

  set +e
  CODEX_GATE_CAPTURE_BRIEF="$brief" run_gate "$home" "$runner" "$repo" "$out" "$err" --base main --sequential
  local code=$?
  set -e
  if [[ "$code" -ne 0 ]]; then
    fail "$name" "exit $code, expected 0"
    return
  fi
  assert_file_contains "$name" "$out" "adjacent test files added: 1" || return
  assert_file_contains "$name" "$brief" "format.test.tsx" || return
  pass "$name"
}

test_adjacent_ts_spec_ts_variant() {
  # Verifies that __tests__/<name>.spec.ts is recognised as an adjacent test.
  local name="adjacent-ts-spec-ts-variant"
  should_run "$name" || return 0
  local dir="$TMP_ROOT/$name"
  local home="$dir/home" repo="$dir/repo" runner="$dir/runner"
  local out="$dir/out" err="$dir/err" brief="$dir/brief.md"
  mkdir -p "$dir"
  create_runner "$runner"
  create_agents "$home" critic qa-tester architecture-reviewer security-reviewer risk-reviewer
  _make_ts_repo_with_test "$repo" "src/__tests__/format.spec.ts" \
    "import { fmt } from '../format'; test('fmt', () => {});"

  set +e
  CODEX_GATE_CAPTURE_BRIEF="$brief" run_gate "$home" "$runner" "$repo" "$out" "$err" --base main --sequential
  local code=$?
  set -e
  if [[ "$code" -ne 0 ]]; then
    fail "$name" "exit $code, expected 0"
    return
  fi
  assert_file_contains "$name" "$out" "adjacent test files added: 1" || return
  assert_file_contains "$name" "$brief" "format.spec.ts" || return
  pass "$name"
}

test_adjacent_ts_spec_tsx_variant() {
  # Verifies that a sibling <name>.spec.tsx file is recognised as an adjacent test.
  local name="adjacent-ts-spec-tsx-variant"
  should_run "$name" || return 0
  local dir="$TMP_ROOT/$name"
  local home="$dir/home" repo="$dir/repo" runner="$dir/runner"
  local out="$dir/out" err="$dir/err" brief="$dir/brief.md"
  mkdir -p "$dir"
  create_runner "$runner"
  create_agents "$home" critic qa-tester architecture-reviewer security-reviewer risk-reviewer
  _make_ts_repo_with_test "$repo" "src/format.spec.tsx" \
    "import { fmt } from './format'; test('fmt', () => {});"

  set +e
  CODEX_GATE_CAPTURE_BRIEF="$brief" run_gate "$home" "$runner" "$repo" "$out" "$err" --base main --sequential
  local code=$?
  set -e
  if [[ "$code" -ne 0 ]]; then
    fail "$name" "exit $code, expected 0"
    return
  fi
  assert_file_contains "$name" "$out" "adjacent test files added: 1" || return
  assert_file_contains "$name" "$brief" "format.spec.tsx" || return
  pass "$name"
}

test_adjacent_ts_sibling_test() {
  # Verifies that a sibling <name>.test.ts file (not in __tests__/) is
  # included in the reviewer brief.
  local name="adjacent-ts-sibling-test"
  should_run "$name" || return 0
  local dir="$TMP_ROOT/$name"
  local home="$dir/home" repo="$dir/repo" runner="$dir/runner"
  local out="$dir/out" err="$dir/err" brief="$dir/brief.md"
  mkdir -p "$dir"
  create_runner "$runner"
  create_agents "$home" critic qa-tester architecture-reviewer security-reviewer risk-reviewer
  _make_ts_repo_with_test "$repo" "src/format.test.ts" \
    "import { fmt } from './format'; test('fmt', () => {});"

  set +e
  CODEX_GATE_CAPTURE_BRIEF="$brief" run_gate "$home" "$runner" "$repo" "$out" "$err" --base main --sequential
  local code=$?
  set -e
  if [[ "$code" -ne 0 ]]; then
    fail "$name" "exit $code, expected 0"
    return
  fi
  assert_file_contains "$name" "$out" "adjacent test files added: 1" || return
  assert_file_contains "$name" "$brief" "format.test.ts" || return
  pass "$name"
}

test_adjacent_test_not_duplicated_when_in_diff() {
  # Verifies that a test file already in the diff is not re-appended as an
  # adjacent file (de-duplication).
  local name="adjacent-test-not-duplicated"
  should_run "$name" || return 0
  local dir="$TMP_ROOT/$name"
  local home="$dir/home" repo="$dir/repo" runner="$dir/runner"
  local out="$dir/out" err="$dir/err"
  mkdir -p "$dir"
  create_runner "$runner"
  create_agents "$home" critic qa-tester architecture-reviewer security-reviewer risk-reviewer
  git init -q -b main "$repo"
  (
    cd "$repo"
    git config user.email test@example.com
    git config user.name 'Gate Test'
    printf 'package main\nfunc Add(a, b int) int { return a + b }\n' > app.go
    printf 'package main\nimport "testing"\nfunc TestAdd(t *testing.T) {}\n' > app_test.go
    write_managed_gitignore
    git add app.go app_test.go .gitignore
    git commit -q -m initial
    git checkout -q -b feature
    printf 'package main\nfunc Add(a, b int) int { return a + b + 0 }\n' > app.go
    printf 'package main\nimport "testing"\nfunc TestAdd(t *testing.T) {}\nfunc TestSub(t *testing.T) {}\n' > app_test.go
    git add app.go app_test.go
    git commit -q -m "change both app.go and app_test.go"
  )

  set +e
  run_gate "$home" "$runner" "$repo" "$out" "$err" --base main
  local code=$?
  set -e
  if [[ "$code" -ne 0 ]]; then
    fail "$name" "exit $code, expected 0"
    return
  fi
  assert_not_contains "$name" "$out" "adjacent test files added:" || return
  pass "$name"
}

test_synthesis_verdict_mismatch_aborts_gate() {
  # Verifies that when synthesis writes Final: GO but the shell-computed verdict
  # from reviewer outputs is NO-GO (block), the gate aborts before reporting success.
  # Steps:
  #   1. Create a minimal repo (express tier, docs change)
  #   2. CODEX_GATE_STUB_VERDICT=block: reviewers write Verdict: block → SHELL_FINAL=NO-GO
  #      CODEX_GATE_STUB_SYNTHESIS_FINAL=GO: synthesis stub writes Final: GO
  #   3. Run gate in parallel mode (default)
  #   4. Assert non-zero exit and "contradicts shell-computed" in stderr
  local name="synthesis-verdict-mismatch-aborts-gate"
  should_run "$name" || return 0
  local dir="$TMP_ROOT/$name"
  local home="$dir/home" repo="$dir/repo" runner="$dir/runner"
  local out="$dir/out" err="$dir/err"
  mkdir -p "$dir"
  create_runner "$runner"
  create_agents "$home" critic qa-tester architecture-reviewer security-reviewer risk-reviewer
  create_repo "$repo" docs

  set +e
  CODEX_GATE_STUB_VERDICT=block CODEX_GATE_STUB_SYNTHESIS_FINAL=GO \
    run_gate "$home" "$runner" "$repo" "$out" "$err" --base main --parallel
  local code=$?
  set -e
  if [[ "$code" -eq 0 ]]; then
    fail "$name" "expected non-zero exit when synthesis verdict contradicts shell verdict"
    return
  fi
  assert_file_contains "$name" "$err" "contradicts shell-computed" || return
  pass "$name"
}

test_post_synthesis_injection_detected() {
  # Verifies that a synthesis session modifying a tracked source file is detected
  # and the gate aborts after synthesis (guards against synthesis-side injection).
  # Steps:
  #   1. Create a repo with a committed service.go (clean tracked file)
  #   2. CODEX_GATE_STUB_SYNTHESIS_INJECT_FILE=service.go: synthesis stub appends to service.go
  #   3. Run gate in parallel mode (default)
  #   4. Assert non-zero exit, "synthesis session modified" in stderr
  local name="post-synthesis-injection-detected"
  should_run "$name" || return 0
  local dir="$TMP_ROOT/$name"
  local home="$dir/home" repo="$dir/repo" runner="$dir/runner"
  local out="$dir/out" err="$dir/err"
  mkdir -p "$dir"
  create_runner "$runner"
  create_agents "$home" critic qa-tester architecture-reviewer security-reviewer risk-reviewer
  create_repo "$repo" docs
  printf 'package main\n' > "$repo/service.go"
  git -C "$repo" add service.go
  git -C "$repo" commit -q -m "add service.go"

  set +e
  CODEX_GATE_STUB_SYNTHESIS_INJECT_FILE="$repo/service.go" run_gate \
    "$home" "$runner" "$repo" "$out" "$err" --base main --parallel
  local code=$?
  set -e
  if [[ "$code" -eq 0 ]]; then
    fail "$name" "expected non-zero exit when synthesis modifies tracked file"
    return
  fi
  assert_file_contains "$name" "$err" "synthesis session modified" || return
  pass "$name"
}

test_synthesis_no_output_aborts_gate() {
  # Verifies that PM synthesis exiting 0 without writing the gate result file
  # fails the gate — reviewers succeed but synthesis silently omits its output.
  # Steps:
  #   1. Create a minimal repo (express tier, docs change)
  #   2. CODEX_GATE_STUB_SYNTHESIS_MODE=no-output: reviewers write output; synthesis does not
  #   3. Run gate in parallel mode (default)
  #   4. Assert non-zero exit and "synthesis did not produce" in stderr
  local name="synthesis-no-output-aborts-gate"
  should_run "$name" || return 0
  local dir="$TMP_ROOT/$name"
  local home="$dir/home" repo="$dir/repo" runner="$dir/runner"
  local out="$dir/out" err="$dir/err"
  mkdir -p "$dir"
  create_runner "$runner"
  create_agents "$home" critic qa-tester architecture-reviewer security-reviewer risk-reviewer
  create_repo "$repo" docs

  set +e
  CODEX_GATE_STUB_SYNTHESIS_MODE=no-output run_gate "$home" "$runner" "$repo" "$out" "$err" --base main --parallel
  local code=$?
  set -e
  if [[ "$code" -eq 0 ]]; then
    fail "$name" "expected non-zero exit when synthesis produces no output"
    return
  fi
  assert_file_contains "$name" "$err" "synthesis did not produce" || return
  pass "$name"
}

test_reviewer_invalid_verdict_aborts_gate() {
  # Verifies that a reviewer output file without a valid Verdict line fails
  # the gate before synthesis (guards against malformed or manipulated output).
  # Steps:
  #   1. Create a minimal repo (express tier, docs change)
  #   2. CODEX_GATE_STUB_MODE=no-verdict: reviewer writes output but no Verdict line
  #   3. Run gate in parallel mode (default)
  #   4. Assert non-zero exit and "exactly one valid Verdict line" in stderr
  local name="reviewer-invalid-verdict-aborts-gate"
  should_run "$name" || return 0
  local dir="$TMP_ROOT/$name"
  local home="$dir/home" repo="$dir/repo" runner="$dir/runner"
  local out="$dir/out" err="$dir/err"
  mkdir -p "$dir"
  create_runner "$runner"
  create_agents "$home" critic qa-tester architecture-reviewer security-reviewer risk-reviewer
  create_repo "$repo" docs

  set +e
  CODEX_GATE_STUB_MODE=no-verdict run_gate "$home" "$runner" "$repo" "$out" "$err" --base main --parallel
  local code=$?
  set -e
  if [[ "$code" -eq 0 ]]; then
    fail "$name" "expected non-zero exit when reviewer output has no valid Verdict line"
    return
  fi
  assert_file_contains "$name" "$err" "exactly one valid Verdict line" || return
  pass "$name"
}

test_reviewer_no_output_aborts_gate() {
  # Verifies that a reviewer session exiting 0 without writing its output file
  # fails the gate (fail-closed on silent reviewer failure).
  # Steps:
  #   1. Create a minimal repo (express tier, docs change)
  #   2. CODEX_GATE_STUB_MODE=no-output: all dispatches (reviewers + synthesis) omit output
  #   3. Run gate in parallel mode (default)
  #   4. Assert non-zero exit and "reviewer output missing or empty" in stderr
  local name="reviewer-no-output-aborts-gate"
  should_run "$name" || return 0
  local dir="$TMP_ROOT/$name"
  local home="$dir/home" repo="$dir/repo" runner="$dir/runner"
  local out="$dir/out" err="$dir/err"
  mkdir -p "$dir"
  create_runner "$runner"
  create_agents "$home" critic qa-tester architecture-reviewer security-reviewer risk-reviewer
  create_repo "$repo" docs

  set +e
  CODEX_GATE_STUB_MODE=no-output run_gate "$home" "$runner" "$repo" "$out" "$err" --base main --parallel
  local code=$?
  set -e
  if [[ "$code" -eq 0 ]]; then
    fail "$name" "expected non-zero exit when reviewer produces no output"
    return
  fi
  assert_file_contains "$name" "$err" "reviewer output missing or empty" || return
  pass "$name"
}

test_sequential_no_output_aborts_gate() {
  # Verifies that sequential mode exiting 0 without writing the gate result file
  # fails the gate before reporting a result.
  # Steps:
  #   1. Create a minimal repo (express tier, docs change)
  #   2. CODEX_GATE_STUB_MODE=no-output: dispatch exits 0 without output
  #   3. Run gate in sequential mode (default)
  #   4. Assert non-zero exit and "sequential gate did not produce" in stderr
  local name="sequential-no-output-aborts-gate"
  should_run "$name" || return 0
  local dir="$TMP_ROOT/$name"
  local home="$dir/home" repo="$dir/repo" runner="$dir/runner"
  local out="$dir/out" err="$dir/err"
  mkdir -p "$dir"
  create_runner "$runner"
  create_agents "$home" critic qa-tester architecture-reviewer security-reviewer risk-reviewer
  create_repo "$repo" docs

  set +e
  CODEX_GATE_STUB_MODE=no-output run_gate "$home" "$runner" "$repo" "$out" "$err" --base main
  local code=$?
  set -e
  if [[ "$code" -eq 0 ]]; then
    fail "$name" "expected non-zero exit when sequential dispatch produces no output"
    return
  fi
  assert_file_contains "$name" "$err" "sequential gate did not produce" || return
  pass "$name"
}

test_sequential_no_final_line_aborts_gate() {
  # Verifies that sequential mode output without a valid Final line fails
  # the gate before reporting a result.
  # Steps:
  #   1. Create a minimal repo (express tier, docs change)
  #   2. CODEX_GATE_STUB_MODE=no-verdict: dispatch writes output but no Final line
  #   3. Run gate in sequential mode (default)
  #   4. Assert non-zero exit and "must contain exactly one Final" in stderr
  local name="sequential-no-final-line-aborts-gate"
  should_run "$name" || return 0
  local dir="$TMP_ROOT/$name"
  local home="$dir/home" repo="$dir/repo" runner="$dir/runner"
  local out="$dir/out" err="$dir/err"
  mkdir -p "$dir"
  create_runner "$runner"
  create_agents "$home" critic qa-tester architecture-reviewer security-reviewer risk-reviewer
  create_repo "$repo" docs

  set +e
  CODEX_GATE_STUB_MODE=no-verdict run_gate "$home" "$runner" "$repo" "$out" "$err" --base main
  local code=$?
  set -e
  if [[ "$code" -eq 0 ]]; then
    fail "$name" "expected non-zero exit when sequential output has no valid Final line"
    return
  fi
  assert_file_contains "$name" "$err" "must contain exactly one Final" || return
  pass "$name"
}

test_prompt_injection_detected() {
  # Verifies that a reviewer session modifying a tracked source file (simulated
  # prompt injection) causes the gate to abort before synthesis.
  # Steps:
  #   1. Create a repo with a committed service.go (clean tracked file)
  #   2. CODEX_GATE_STUB_INJECT_FILE=service.go: reviewer stub appends to service.go
  #   3. Run gate in parallel mode (default)
  #   4. Assert non-zero exit, "prompt injection" in stderr, and no "[synthesis]" in stdout
  local name="prompt-injection-detected"
  should_run "$name" || return 0
  local dir="$TMP_ROOT/$name"
  local home="$dir/home" repo="$dir/repo" runner="$dir/runner"
  local out="$dir/out" err="$dir/err"
  mkdir -p "$dir"
  create_runner "$runner"
  create_agents "$home" critic qa-tester architecture-reviewer security-reviewer risk-reviewer
  create_repo "$repo" docs
  # Add a committed tracked source file the stub can modify
  printf 'package main\n' > "$repo/service.go"
  git -C "$repo" add service.go
  git -C "$repo" commit -q -m "add service.go"

  set +e
  CODEX_GATE_STUB_INJECT_FILE="$repo/service.go" run_gate \
    "$home" "$runner" "$repo" "$out" "$err" --base main --parallel
  local code=$?
  set -e
  if [[ "$code" -eq 0 ]]; then
    fail "$name" "expected non-zero exit when reviewer modifies tracked file"
    return
  fi
  assert_file_contains "$name" "$err" "prompt injection" || return
  assert_not_contains "$name" "$out" "[synthesis]" || return
  pass "$name"
}

test_block_soft_verdict_is_no_go() {
  # Verifies that block-soft (the mildest blocking verdict) causes SHELL_FINAL=NO-GO
  # and the gate exits with a contradiction error when synthesis writes Final: GO.
  # Steps:
  #   1. Create a minimal repo (express tier, docs change)
  #   2. CODEX_GATE_STUB_VERDICT=block-soft: reviewers write Verdict: block-soft → SHELL_FINAL=NO-GO
  #      CODEX_GATE_STUB_SYNTHESIS_FINAL=GO: synthesis stub writes Final: GO
  #   3. Run gate in --parallel mode
  #   4. Assert non-zero exit and "contradicts shell-computed" in stderr
  local name="block-soft-verdict-is-no-go"
  should_run "$name" || return 0
  local dir="$TMP_ROOT/$name"
  local home="$dir/home" repo="$dir/repo" runner="$dir/runner"
  local out="$dir/out" err="$dir/err"
  mkdir -p "$dir"
  create_runner "$runner"
  create_agents "$home" critic qa-tester architecture-reviewer security-reviewer risk-reviewer
  create_repo "$repo" docs

  set +e
  CODEX_GATE_STUB_VERDICT=block-soft CODEX_GATE_STUB_SYNTHESIS_FINAL=GO \
    run_gate "$home" "$runner" "$repo" "$out" "$err" --base main --parallel
  local code=$?
  set -e
  if [[ "$code" -eq 0 ]]; then
    fail "$name" "expected non-zero exit when block-soft verdict triggers NO-GO"
    return
  fi
  assert_file_contains "$name" "$err" "contradicts shell-computed" || return
  pass "$name"
}

test_synthesis_artifact_tamper_detected() {
  # Verifies that synthesis modifying a reviewer output artifact (gitignored) is detected
  # before the final verdict is accepted. This guards against a synthesis session
  # writing forged findings into an already-validated reviewer file.
  # Steps:
  #   1. Create a minimal repo (express tier, docs change) with a committed tracked file
  #   2. Run gate in --parallel mode; synthesis stub appends to the first reviewer output
  #   3. Assert non-zero exit and "artifact" or "tampering" in stderr
  local name="synthesis-artifact-tamper-detected"
  should_run "$name" || return 0
  local dir="$TMP_ROOT/$name"
  local home="$dir/home" repo="$dir/repo" runner="$dir/runner"
  local out="$dir/out" err="$dir/err"
  mkdir -p "$dir"
  create_runner "$runner"
  create_agents "$home" critic qa-tester architecture-reviewer security-reviewer risk-reviewer
  create_repo "$repo" docs

  # Reviewer artifact paths are dynamic (timestamped). runner2 uses a custom dispatch
  # wrapper that, on synthesis dispatch, finds the most recently written reviewer-*.md
  # in .gate-results/ and appends to it — simulating synthesis-side artifact tampering
  # of a gitignored file that the worktree hash cannot detect.
  local runner2="$dir/runner2"
  mkdir -p "$runner2"
  cp "$runner/pr-gate.sh" "$runner2/pr-gate.sh"
  chmod +x "$runner2/pr-gate.sh"

  # Wrapper dispatch: on synthesis brief, tamper with the most recently written reviewer artifact.
  cat > "$runner2/codex-dispatch.sh" <<'TWRAP_EOF'
#!/usr/bin/env bash
set -euo pipefail
brief_file=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --brief-file) brief_file="$2"; shift 2;;
    --cd|--timeout) shift 2;;
    *) shift;;
  esac
done

printf 'DISPATCH_STUB:success\n'

output_path=$(grep -o '\- new:.*' "$brief_file" | head -1 | awk '{print $NF}')
[[ -n "$output_path" ]] && mkdir -p "$(dirname "$output_path")"

if [[ "$brief_file" == *-synthesis.md ]]; then
  # Synthesis: tamper with the most recently written reviewer artifact before writing output
  gate_dir="$(dirname "$output_path")"
  reviewer_artifact=$(ls -t "$gate_dir"/reviewer-*.md 2>/dev/null | head -1 || true)
  if [[ -n "$reviewer_artifact" ]]; then
    printf 'tampered-by-synthesis\n' >> "$reviewer_artifact"
  fi
  # Write valid synthesis output so other checks pass (frontmatter required by CC-250 parity check)
  printf -- '---\ngate_result_version: pr_gate_result_v1\nfinal: GO\ntier: full\nmode: parallel\nmost_severe: advise\nreviewers:\n  critic: skipped\n  qa-tester: skipped\n  architecture-reviewer: skipped\n  security-reviewer: skipped\n  risk-reviewer: skipped\nescalation:\n  recommended: false\n  reviewers: []\n  reason: []\n---\n# PR-Gate Result\n**Date**: 2026-01-01\n**Reviewers**: stub\n**Not reviewed**: none\n\n## stub-reviewer — advise\n- stub finding\n\nVerdict: advise. Stub.\n\n## Cross-Reviewer Overlaps\nnone\n\n## Coverage Notes\n**Dimensions not covered**: none\n\n## Gate Conclusion\n**Overall verdict**: advise\n**Most severe individual verdict**: advise\nFinal: GO\n\n## Escalation\n**Recommended**: false\n**Reviewers**: none\n**Reason**:\n- none\n\nRequired fixes before GO: none\n\nRecommended follow-ups:\n- none\n\nRationale: Stub.\n' > "$output_path"
else
  stub_verdict="${CODEX_GATE_STUB_VERDICT:-advise}"
  printf '## stub-reviewer — %s\nVerdict: %s. Stub output.\n' "$stub_verdict" "$stub_verdict" > "$output_path"
fi
exit 0
TWRAP_EOF
  chmod +x "$runner2/codex-dispatch.sh"

  set +e
  HOME="$home" "$runner2/pr-gate.sh" --cd "$repo" --base main --parallel > "$out" 2> "$err"
  local code=$?
  set -e
  if [[ "$code" -eq 0 ]]; then
    fail "$name" "expected non-zero exit when synthesis tampers with reviewer artifact"
    return
  fi
  if ! grep -qiE "artifact|tamper" "$err"; then
    fail "$name" "expected 'artifact' or 'tamper' in stderr; got: $(cat "$err")"
    return
  fi
  pass "$name"
}

test_verdict_prefix_rejected() {
  # Verifies that a verdict line with a valid prefix but invalid suffix is rejected.
  # For example "Verdict: approved" must not be accepted as "Verdict: approve".
  # Steps:
  #   1. Create a minimal repo (express tier, docs change)
  #   2. CODEX_GATE_STUB_VERDICT_PREFIX_ONLY=1: stub writes "Verdict: approved" (not "approve")
  #   3. Run gate in --parallel mode
  #   4. Assert non-zero exit and "exactly one valid Verdict line" in stderr
  local name="verdict-prefix-rejected"
  should_run "$name" || return 0
  local dir="$TMP_ROOT/$name"
  local home="$dir/home" repo="$dir/repo" runner="$dir/runner"
  local out="$dir/out" err="$dir/err"
  mkdir -p "$dir"
  create_runner "$runner"
  create_agents "$home" critic qa-tester architecture-reviewer security-reviewer risk-reviewer
  create_repo "$repo" docs

  set +e
  CODEX_GATE_STUB_VERDICT_PREFIX_ONLY=1 run_gate \
    "$home" "$runner" "$repo" "$out" "$err" --base main --parallel
  local code=$?
  set -e
  if [[ "$code" -eq 0 ]]; then
    fail "$name" "expected non-zero exit when verdict uses invalid prefix-only token"
    return
  fi
  assert_file_contains "$name" "$err" "exactly one valid Verdict line" || return
  pass "$name"
}

test_hash_tool_missing_aborts_gate() {
  # Verifies that when neither sha256sum nor shasum is available the gate
  # exits non-zero immediately in --parallel mode rather than silently
  # degrading to empty-string fingerprints.
  # Steps:
  #   1. Create a minimal repo (express tier, docs change)
  #   2. Prepend a fakepath with failing sha256sum/shasum stubs to PATH
  #   3. Run gate with --parallel
  #   4. Assert non-zero exit and "no sha256sum or shasum" in stderr
  local name="hash-tool-missing-aborts-gate"
  should_run "$name" || return 0
  local dir="$TMP_ROOT/$name"
  local home="$dir/home" repo="$dir/repo" runner="$dir/runner"
  local out="$dir/out" err="$dir/err"
  local fakepath="$dir/fakepath"
  mkdir -p "$dir" "$fakepath"
  create_runner "$runner"
  create_agents "$home" critic qa-tester architecture-reviewer security-reviewer risk-reviewer
  create_repo "$repo" docs

  # Prepend stubs that fail so `command -v sha256sum/shasum` resolves but exits 127.
  printf '#!/bin/sh\nexit 127\n' > "$fakepath/sha256sum"
  printf '#!/bin/sh\nexit 127\n' > "$fakepath/shasum"
  chmod +x "$fakepath/sha256sum" "$fakepath/shasum"

  set +e
  HOME="$home" PATH="$fakepath:$PATH" "$runner/pr-gate.sh" \
    --cd "$repo" --base main --parallel > "$out" 2> "$err"
  local code=$?
  set -e
  if [[ "$code" -eq 0 ]]; then
    fail "$name" "expected non-zero exit when sha256sum/shasum unavailable"
    return
  fi
  assert_file_contains "$name" "$err" "no sha256sum or shasum" || return
  pass "$name"
}

test_bold_final_line_rejected() {
  # CC-252 regression: when synthesis emits the Final: line wrapped in markdown
  # bold (e.g., `**Final: GO**`) — as observed on CC-249 spike PR #146 where
  # codex applied prose emphasis — the parser MUST reject it. The Final line is
  # contract-locked to plain text via the `^Final: (GO|NO-GO)$` regex.
  # Loosening the parser to accept bold-Final would silently hide the brief-
  # template drift the CC-250 brief is supposed to prevent.
  # Steps:
  #   1. Create a minimal repo (express tier, docs change)
  #   2. CODEX_GATE_STUB_BOLD_FINAL=1: synthesis writes "**Final: GO**" instead of "Final: GO"
  #   3. Run gate in --parallel mode
  #   4. Assert non-zero exit and "exactly one Final" / "(found 0)" in stderr
  local name="bold-final-line-rejected"
  should_run "$name" || return 0
  local dir="$TMP_ROOT/$name"
  local home="$dir/home" repo="$dir/repo" runner="$dir/runner"
  local out="$dir/out" err="$dir/err"
  mkdir -p "$dir"
  create_runner "$runner"
  create_agents "$home" critic qa-tester architecture-reviewer security-reviewer risk-reviewer
  create_repo "$repo" docs

  set +e
  CODEX_GATE_STUB_BOLD_FINAL=1 run_gate \
    "$home" "$runner" "$repo" "$out" "$err" --base main --parallel
  local code=$?
  set -e
  if [[ "$code" -eq 0 ]]; then
    fail "$name" "expected non-zero exit when synthesis emits **Final: GO** (bold)"
    return
  fi
  assert_file_contains "$name" "$err" "exactly one Final" || return
  pass "$name"
}

test_brief_construction_emits_no_shell_errors() {
  # CC-257 regression: the codex-brief heredoc at scripts/pr-gate.sh:362
  # (BRIEF_EOF) and the synthesis-brief heredocs (SBRIEF_P1, SBRIEF_P2) are
  # unquoted, so bash performs command substitution on backtick pairs in the
  # body. CC-252 (#147) introduced cautionary `` `Final: ...` `` tokens that
  # bash then tried to execute, producing 7 `command not found` lines per
  # invocation. Fix: escape the backticks in the heredoc body (\`Final: ...\`)
  # so bash writes them literally.
  # Steps:
  #   1. Run gate against a minimal repo (express tier, docs change)
  #   2. Assert exit 0 (gate ran cleanly)
  #   3. Assert stderr file contains zero "command not found" lines
  #   4. Assert the captured brief still contains the cautionary tokens
  #      (`Final:`, `final:`, `**Final: GO**`) so codex still sees the warning
  local name="brief-construction-no-shell-errors"
  should_run "$name" || return 0
  local dir="$TMP_ROOT/$name"
  local home="$dir/home" repo="$dir/repo" runner="$dir/runner"
  local out="$dir/out" err="$dir/err" brief="$dir/brief.md"
  mkdir -p "$dir"
  create_runner "$runner"
  create_agents "$home" critic qa-tester architecture-reviewer security-reviewer risk-reviewer
  create_repo "$repo" docs

  set +e
  CODEX_GATE_CAPTURE_BRIEF="$brief" run_gate "$home" "$runner" "$repo" "$out" "$err" --base main --sequential
  local code=$?
  set -e
  if [[ "$code" -ne 0 ]]; then
    fail "$name" "exit $code, expected 0"
    return
  fi
  assert_not_contains "$name" "$err" "command not found" || return
  assert_file_contains "$name" "$brief" 'frontmatter `final:` field' || return
  assert_file_contains "$name" "$brief" '`**Final: GO**`' || return
  pass "$name"
}

test_synthesis_multiple_final_lines_aborts_gate() {
  # Verifies that a synthesis output with more than one Final: line causes the
  # gate to abort — duplicate or contradictory Final: lines indicate a
  # manipulated or corrupt gate artifact.
  # Steps:
  #   1. Create a minimal repo (express tier, docs change)
  #   2. CODEX_GATE_STUB_SYNTHESIS_EXTRA_FINAL=NO-GO: synthesis writes two Final: lines
  #   3. Run gate in --parallel mode
  #   4. Assert non-zero exit and "exactly one Final" in stderr
  local name="synthesis-multiple-final-lines-aborts-gate"
  should_run "$name" || return 0
  local dir="$TMP_ROOT/$name"
  local home="$dir/home" repo="$dir/repo" runner="$dir/runner"
  local out="$dir/out" err="$dir/err"
  mkdir -p "$dir"
  create_runner "$runner"
  create_agents "$home" critic qa-tester architecture-reviewer security-reviewer risk-reviewer
  create_repo "$repo" docs

  set +e
  CODEX_GATE_STUB_SYNTHESIS_EXTRA_FINAL=NO-GO run_gate \
    "$home" "$runner" "$repo" "$out" "$err" --base main --parallel
  local code=$?
  set -e
  if [[ "$code" -eq 0 ]]; then
    fail "$name" "expected non-zero exit when synthesis has multiple Final: lines"
    return
  fi
  assert_file_contains "$name" "$err" "exactly one Final" || return
  pass "$name"
}

test_multiple_verdict_lines_aborts_gate() {
  # Verifies that a reviewer artifact with more than one valid Verdict: line is rejected.
  # The gate must fail closed on ambiguous reviewer output — silently taking the first
  # match would allow a more-severe later verdict to be ignored.
  # Steps:
  #   1. Create a minimal repo (express tier, docs change)
  #   2. CODEX_GATE_STUB_MULTIPLE_VERDICTS=1: stub writes "Verdict: approve" then "Verdict: block"
  #   3. Run gate in --parallel mode
  #   4. Assert non-zero exit and "exactly one valid Verdict line" in stderr
  local name="multiple-verdict-lines-aborts-gate"
  should_run "$name" || return 0
  local dir="$TMP_ROOT/$name"
  local home="$dir/home" repo="$dir/repo" runner="$dir/runner"
  local out="$dir/out" err="$dir/err"
  mkdir -p "$dir"
  create_runner "$runner"
  create_agents "$home" critic qa-tester architecture-reviewer security-reviewer risk-reviewer
  create_repo "$repo" docs

  set +e
  CODEX_GATE_STUB_MULTIPLE_VERDICTS=1 run_gate \
    "$home" "$runner" "$repo" "$out" "$err" --base main --parallel
  local code=$?
  set -e
  if [[ "$code" -eq 0 ]]; then
    fail "$name" "expected non-zero exit when reviewer artifact has multiple valid Verdict lines"
    return
  fi
  assert_file_contains "$name" "$err" "exactly one valid Verdict line" || return
  pass "$name"
}

test_reviewer_cross_artifact_tamper_detected() {
  # Verifies that cross-reviewer artifact tampering in --parallel mode is detected
  # and the gate aborts before synthesis runs on tainted data.
  #
  # Scenario:
  #   - qa-tester is at index 0: writes output quickly, exits.
  #   - critic is at index 1 (the tamper reviewer): writes its own output, sleeps
  #     0.3s, then appends to qa-tester's artifact before exiting.
  #
  # The wait loop captures qa-tester's post-wait hash immediately after qa-tester
  # exits (before critic's 0.3s sleep ends). After critic exits, the cross-tamper
  # check re-hashes qa-tester's artifact and detects the mismatch.
  local name="reviewer-cross-artifact-tamper-detected"
  should_run "$name" || return 0
  local dir="$TMP_ROOT/$name"
  local home="$dir/home" repo="$dir/repo" runner="$dir/runner"
  local out="$dir/out" err="$dir/err"
  mkdir -p "$dir"
  create_runner "$runner"
  create_agents "$home" critic qa-tester
  create_repo "$repo" docs

  set +e
  CODEX_GATE_STUB_CROSS_TAMPER_REVIEWER=critic \
  CODEX_GATE_STUB_CROSS_TAMPER_VICTIM=qa-tester \
    run_gate "$home" "$runner" "$repo" "$out" "$err" \
      --base main --reviewers qa-tester,critic --parallel
  local code=$?
  set -e
  if [[ "$code" -eq 0 ]]; then
    fail "$name" "expected non-zero exit when cross-reviewer tampers a reviewer artifact"
    return
  fi
  assert_file_contains "$name" "$err" "cross-reviewer artifact tampering" || return
  assert_not_contains "$name" "$out" "[synthesis]" || return
  pass "$name"
}

test_gate_result_frontmatter_and_escalation() {
  local name="gate-result-frontmatter-escalation"
  should_run "$name" || return 0
  local dir="$TMP_ROOT/$name"
  local home="$dir/home" repo="$dir/repo" runner="$dir/runner"
  local out="$dir/out" err="$dir/err" result="$dir/result.md"
  mkdir -p "$dir"
  create_runner "$runner"
  create_agents "$home" critic qa-tester architecture-reviewer security-reviewer risk-reviewer
  create_repo "$repo" docs

  set +e
  CODEX_GATE_STUB_SYNTHESIS_FINAL=GO run_gate \
    "$home" "$runner" "$repo" "$out" "$err" --base main --output "$result" \
    --sequential
  local code=$?
  set -e
  if [[ "$code" -ne 0 ]]; then
    fail "$name" "exit $code, expected 0"
    return
  fi
  if [[ "$(head -n 1 "$result")" != "---" ]]; then
    fail "$name" "frontmatter block must start with ---"
    return
  fi
  local frontmatter_end
  frontmatter_end="$(awk 'BEGIN{s=0} /^---$/ { s++; if (s == 2) { print NR; exit } }' "$result")"
  if [[ -z "$frontmatter_end" ]]; then
    fail "$name" "frontmatter block must have a closing ---"
    return
  fi
  local frontmatter
  frontmatter="$(sed -n "1,${frontmatter_end}p" "$result")"
  if ! printf '%s\n' "$frontmatter" | grep -q '^gate_result_version: pr_gate_result_v1$'; then
    fail "$name" "frontmatter missing gate_result_version: pr_gate_result_v1"
    return
  fi
  if ! printf '%s\n' "$frontmatter" | grep -Eq '^final: (GO|NO-GO)$'; then
    fail "$name" "missing frontmatter final in GO|NO-GO form"
    return
  fi
  if ! printf '%s\n' "$frontmatter" | grep -q '^reviewers:$'; then
    fail "$name" "frontmatter missing reviewers map"
    return
  fi
  if ! printf '%s\n' "$frontmatter" | grep -q '^[[:space:]]*critic:'; then
    fail "$name" "frontmatter missing critic verdict"
    return
  fi
  if ! printf '%s\n' "$frontmatter" | grep -q '^[[:space:]]*qa-tester:'; then
    fail "$name" "frontmatter missing qa-tester verdict"
    return
  fi
  if ! printf '%s\n' "$frontmatter" | grep -q '^[[:space:]]*architecture-reviewer:'; then
    fail "$name" "frontmatter missing architecture-reviewer verdict"
    return
  fi
  if ! printf '%s\n' "$frontmatter" | grep -q '^[[:space:]]*security-reviewer:'; then
    fail "$name" "frontmatter missing security-reviewer verdict"
    return
  fi
  if ! printf '%s\n' "$frontmatter" | grep -q '^[[:space:]]*risk-reviewer:'; then
    fail "$name" "frontmatter missing risk-reviewer verdict"
    return
  fi
  if ! printf '%s\n' "$frontmatter" | grep -q '^escalation:$'; then
    fail "$name" "frontmatter missing escalation block"
    return
  fi
  if ! printf '%s\n' "$frontmatter" | grep -q '^[[:space:]]*recommended: '; then
    fail "$name" "frontmatter missing escalation recommendation"
    return
  fi
  assert_file_contains "$name" "$result" "## Escalation" || return
  assert_file_contains "$name" "$result" "**Recommended**:" || return
  assert_file_contains "$name" "$result" "**Reviewers**:" || return
  assert_file_contains "$name" "$result" "**Reason**:" || return
  pass "$name"
}

test_gate_result_final_line_back_compat() {
  local name="gate-result-final-line-back-compat"
  should_run "$name" || return 0
  local dir="$TMP_ROOT/$name"
  local home="$dir/home" repo="$dir/repo" runner="$dir/runner"
  local out="$dir/out" err="$dir/err" result="$dir/result.md"
  mkdir -p "$dir"
  create_runner "$runner"
  create_agents "$home" critic qa-tester architecture-reviewer security-reviewer risk-reviewer
  create_repo "$repo" docs

  set +e
  CODEX_GATE_STUB_SYNTHESIS_FINAL=GO run_gate \
    "$home" "$runner" "$repo" "$out" "$err" --base main --output "$result" --parallel
  local code=$?
  set -e
  if [[ "$code" -ne 0 ]]; then
    fail "$name" "exit $code, expected 0"
    return
  fi
  local final_count
  final_count="$(awk '/^Final: (GO|NO-GO)$/{count++} END {print count+0}' "$result")"
  if [[ "$final_count" -ne 1 ]]; then
    fail "$name" "expected exactly one Final line, got $final_count"
    return
  fi
  pass "$name"
}

test_frontmatter_escalation_parity() {
  local name="frontmatter-escalation-parity"
  should_run "$name" || return 0
  local dir="$TMP_ROOT/$name"
  local home="$dir/home" repo="$dir/repo" runner="$dir/runner"
  local out="$dir/out" err="$dir/err" result="$dir/result.md"
  mkdir -p "$dir"
  create_runner "$runner"
  create_agents "$home" critic qa-tester architecture-reviewer security-reviewer risk-reviewer
  create_repo "$repo" docs

  set +e
  run_gate "$home" "$runner" "$repo" "$out" "$err" --base main --output "$result" --parallel
  local code=$?
  set -e
  if [[ "$code" -ne 0 ]]; then
    fail "$name" "exit $code, expected 0"
    return
  fi
  local fm
  local body
  fm="$(awk 'BEGIN{front=0} /^---$/ { if (front == 0) {front=1; next} else if (front == 1) {exit} } front && /^  recommended: / {print $2; exit}' "$result")"
  body="$(awk 'BEGIN{in_block=0} /^## Escalation/{in_block=1; next} in_block && /^\*\*Recommended\*\*:/ {print $2; exit}' "$result")"
  if [[ -z "$fm" || -z "$body" ]]; then
    fail "$name" "missing escalation recommendation in frontmatter or body"
    return
  fi
  if [[ "$fm" != "$body" ]]; then
    fail "$name" "frontmatter escalation ($fm) does not match body escalation ($body)"
    return
  fi
  pass "$name"
}

test_base_detection_via_gh_pr_view() {
  local name="base-detection-via-gh-pr-view"
  should_run "$name" || return 0
  local dir="$TMP_ROOT/$name"
  local home="$dir/home" repo="$dir/repo" runner="$dir/runner" fakegh="$dir/fake-gh"
  local out="$dir/out" err="$dir/err" result="$dir/result.md"
  mkdir -p "$dir" "$fakegh"
  create_runner "$runner"
  create_agents "$home" critic qa-tester architecture-reviewer security-reviewer risk-reviewer
  create_repo "$repo" docs

  cat > "$fakegh/gh" <<'FAKE_GH'
#!/usr/bin/env bash
echo "main"
exit 0
FAKE_GH
  chmod +x "$fakegh/gh"

  set +e
  PATH="$fakegh:$PATH" run_gate "$home" "$runner" "$repo" "$out" "$err" --output "$result" 2>/dev/null
  local code=$?
  set -e
  if [[ "$code" -ne 0 ]]; then
    fail "$name" "exit $code, expected 0"
    return
  fi
  assert_file_contains "$name" "$out" "pr-gate: base detected from gh pr view: main" || return
  if ! grep -Eq '^Final: (GO|NO-GO)$' "$result"; then
    fail "$name" "final line missing in gate output"
    return
  fi
  pass "$name"
}

test_base_detection_gh_fallback() {
  local name="base-detection-gh-fallback"
  should_run "$name" || return 0
  local dir="$TMP_ROOT/$name"
  local home="$dir/home" repo="$dir/repo" runner="$dir/runner" fakegh="$dir/fake-gh"
  local out="$dir/out" err="$dir/err" result="$dir/result.md"
  mkdir -p "$dir" "$fakegh"
  create_runner "$runner"
  create_agents "$home" critic qa-tester architecture-reviewer security-reviewer risk-reviewer
  create_repo "$repo" docs

  cat > "$fakegh/gh" <<'FAKE_GH'
#!/usr/bin/env bash
exit 1
FAKE_GH
  chmod +x "$fakegh/gh"

  set +e
  PATH="$fakegh:$PATH" run_gate "$home" "$runner" "$repo" "$out" "$err" --output "$result" 2>/dev/null
  local code=$?
  set -e
  if [[ "$code" -ne 0 ]]; then
    fail "$name" "exit $code, expected 0"
    return
  fi
  assert_not_contains "$name" "$out" "base detected from gh pr view" || return
  pass "$name"
}

run_test() {
  "$@" || true
}

test_standard_tier_detection() {
  # Verifies 100-500 non-doc lines on a feature branch triggers standard tier.
  local name="standard-tier-detection"
  should_run "$name" || return 0
  local dir="$TMP_ROOT/$name"
  local home="$dir/home" repo="$dir/repo" runner="$dir/runner"
  local out="$dir/out" err="$dir/err" brief="$dir/brief.md"
  mkdir -p "$dir"
  create_runner "$runner"
  create_agents "$home" critic qa-tester architecture-reviewer security-reviewer risk-reviewer
  create_repo_with_branch "$repo" standard

  set +e
  CODEX_GATE_CAPTURE_BRIEF="$brief" run_gate "$home" "$runner" "$repo" "$out" "$err" --base main
  local code=$?
  set -e
  if [[ "$code" -ne 0 ]]; then
    fail "$name" "exit $code, expected 0"
    return
  fi
  assert_file_contains "$name" "$brief" "Tier: standard" || return
  assert_file_contains "$name" "$brief" "Reviewers: critic,qa-tester,architecture-reviewer" || return
  pass "$name"
}

test_full_tier_line_count() {
  # Verifies >500 non-doc lines on a feature branch triggers full tier.
  local name="full-tier-line-count"
  should_run "$name" || return 0
  local dir="$TMP_ROOT/$name"
  local home="$dir/home" repo="$dir/repo" runner="$dir/runner"
  local out="$dir/out" err="$dir/err" brief="$dir/brief.md"
  mkdir -p "$dir"
  create_runner "$runner"
  create_agents "$home" critic qa-tester architecture-reviewer security-reviewer risk-reviewer
  create_repo_with_branch "$repo" full-lines

  set +e
  CODEX_GATE_CAPTURE_BRIEF="$brief" run_gate "$home" "$runner" "$repo" "$out" "$err" --base main
  local code=$?
  set -e
  if [[ "$code" -ne 0 ]]; then
    fail "$name" "exit $code, expected 0"
    return
  fi
  assert_file_contains "$name" "$brief" "Tier: full" || return
  pass "$name"
}

test_full_tier_sensitive_file() {
  # Verifies a sensitive filename (auth-*) triggers full tier regardless of line count.
  local name="full-tier-sensitive-file"
  should_run "$name" || return 0
  local dir="$TMP_ROOT/$name"
  local home="$dir/home" repo="$dir/repo" runner="$dir/runner"
  local out="$dir/out" err="$dir/err" brief="$dir/brief.md"
  mkdir -p "$dir"
  create_runner "$runner"
  create_agents "$home" critic qa-tester architecture-reviewer security-reviewer risk-reviewer
  create_repo_with_branch "$repo" full-sensitive

  set +e
  CODEX_GATE_CAPTURE_BRIEF="$brief" run_gate "$home" "$runner" "$repo" "$out" "$err" --base main
  local code=$?
  set -e
  if [[ "$code" -ne 0 ]]; then
    fail "$name" "exit $code, expected 0"
    return
  fi
  assert_file_contains "$name" "$brief" "Tier: full" || return
  pass "$name"
}

test_via_symlink() {
  # Verifies readlink -f fix: gate dispatches correctly when run as a symlink.
  local name="via-symlink"
  should_run "$name" || return 0
  local dir="$TMP_ROOT/$name"
  local home="$dir/home" repo="$dir/repo" runner="$dir/runner" symdir="$dir/symdir"
  local out="$dir/out" err="$dir/err"
  mkdir -p "$dir" "$symdir"
  create_runner "$runner"
  create_agents "$home" critic qa-tester architecture-reviewer security-reviewer risk-reviewer
  create_repo "$repo" docs

  # Simulate ~/.claude/scripts/pr-gate.sh → real script in runner dir
  ln -s "$runner/pr-gate.sh" "$symdir/pr-gate.sh"

  set +e
  HOME="$home" "$symdir/pr-gate.sh" --cd "$repo" --base main > "$out" 2> "$err"
  local code=$?
  set -e
  if [[ "$code" -ne 0 ]]; then
    fail "$name" "exit $code — readlink -f fix may be broken"
    return
  fi
  assert_file_contains "$name" "$out" "DISPATCH_STUB:success" || return
  pass "$name"
}

test_rename_sensitive_old_name() {
  # Verifies that renaming auth.ts → login.ts still triggers full tier on the old name.
  local name="rename-sensitive-old-name"
  should_run "$name" || return 0
  local dir="$TMP_ROOT/$name"
  local home="$dir/home" repo="$dir/repo" runner="$dir/runner"
  local out="$dir/out" err="$dir/err" brief="$dir/brief.md"
  mkdir -p "$dir"
  create_runner "$runner"
  create_agents "$home" critic qa-tester architecture-reviewer security-reviewer risk-reviewer
  git init -q -b main "$repo"
  (
    cd "$repo"
    git config user.email test@example.com
    git config user.name 'Gate Test'
    printf 'package auth\n' > auth.ts
    write_managed_gitignore
    git add auth.ts .gitignore
    git commit -q -m initial
    git checkout -q -b feature
    git mv auth.ts login.ts
    git commit -q -m "rename auth.ts to login.ts"
  )

  set +e
  CODEX_GATE_CAPTURE_BRIEF="$brief" run_gate "$home" "$runner" "$repo" "$out" "$err" --base main
  local code=$?
  set -e
  if [[ "$code" -ne 0 ]]; then
    fail "$name" "exit $code, expected 0"
    return
  fi
  assert_file_contains "$name" "$brief" "Tier: full" || return
  pass "$name"
}

test_binary_file_routes_to_standard() {
  # Verifies that a binary file change is not silently routed to express tier.
  local name="binary-file-routes-to-standard"
  should_run "$name" || return 0
  local dir="$TMP_ROOT/$name"
  local home="$dir/home" repo="$dir/repo" runner="$dir/runner"
  local out="$dir/out" err="$dir/err" brief="$dir/brief.md"
  mkdir -p "$dir"
  create_runner "$runner"
  create_agents "$home" critic qa-tester architecture-reviewer security-reviewer risk-reviewer
  git init -q -b main "$repo"
  (
    cd "$repo"
    git config user.email test@example.com
    git config user.name 'Gate Test'
    printf 'initial\n' > README.md
    write_managed_gitignore
    git add README.md .gitignore
    git commit -q -m initial
    git checkout -q -b feature
    # Create a binary file (null bytes trigger git binary detection)
    printf '\x00\x01\x02\x03' > image.png
    git add image.png
    git commit -q -m "add binary asset"
  )

  set +e
  CODEX_GATE_CAPTURE_BRIEF="$brief" run_gate "$home" "$runner" "$repo" "$out" "$err" --base main
  local code=$?
  set -e
  if [[ "$code" -ne 0 ]]; then
    fail "$name" "exit $code, expected 0"
    return
  fi
  # Binary files must route to standard (not express, not over-routed to full)
  if ! grep -qF "Tier: standard" "$brief" 2>/dev/null; then
    fail "$name" "binary file did not route to standard tier (brief: $(cat "$brief" 2>/dev/null | grep Tier || echo 'no Tier line'))"
    return
  fi
  pass "$name"
}

test_untracked_binary_routes_to_standard() {
  # Verifies that an untracked binary in the working tree (no branch commits)
  # is not silently routed to express tier. The working-tree fallback must treat
  # untracked non-doc files as having unknown size.
  local name="untracked-binary-routes-to-standard"
  should_run "$name" || return 0
  local dir="$TMP_ROOT/$name"
  local home="$dir/home" repo="$dir/repo" runner="$dir/runner"
  local out="$dir/out" err="$dir/err" brief="$dir/brief.md"
  mkdir -p "$dir"
  create_runner "$runner"
  create_agents "$home" critic qa-tester architecture-reviewer security-reviewer risk-reviewer
  git init -q -b main "$repo"
  (
    cd "$repo"
    git config user.email test@example.com
    git config user.name 'Gate Test'
    printf 'initial\n' > README.md
    write_managed_gitignore
    git add README.md .gitignore
    git commit -q -m initial
    # Add an untracked binary file to the working tree (no commit, no staging)
    printf '\x00\x01\x02\x03' > image.png
  )

  set +e
  CODEX_GATE_CAPTURE_BRIEF="$brief" run_gate "$home" "$runner" "$repo" "$out" "$err"
  local code=$?
  set -e
  if [[ "$code" -ne 0 ]]; then
    fail "$name" "exit $code, expected 0"
    return
  fi
  # Untracked binary must not silently route to express
  if grep -qF "Tier: express" "$brief" 2>/dev/null; then
    fail "$name" "untracked binary incorrectly routed to express tier"
    return
  fi
  pass "$name"
}

run_test test_tier_detection
run_test test_pr_gate_does_not_mutate_gitignore
run_test test_missing_reviewer_agent
run_test test_invalid_base_ref
run_test test_no_changed_files
run_test test_reviewers_override_skips_tier_detection
run_test test_brief_file_inside_workdir
run_test test_brief_cleanup_on_dispatch_failure
run_test test_output_directory_created
run_test test_standard_tier_detection
run_test test_full_tier_line_count
run_test test_full_tier_sensitive_file
run_test test_via_symlink
run_test test_rename_sensitive_old_name
run_test test_binary_file_routes_to_standard
run_test test_untracked_binary_routes_to_standard
run_test test_parallel_launches_per_reviewer
run_test test_sequential_flag_produces_combined_brief
run_test test_gate_result_frontmatter_and_escalation
run_test test_gate_result_final_line_back_compat
run_test test_frontmatter_escalation_parity
run_test test_failed_reviewer_aborts_gate
run_test test_synthesis_verdict_mismatch_aborts_gate
run_test test_post_synthesis_injection_detected
run_test test_synthesis_no_output_aborts_gate
run_test test_reviewer_invalid_verdict_aborts_gate
run_test test_reviewer_no_output_aborts_gate
run_test test_sequential_no_output_aborts_gate
run_test test_sequential_no_final_line_aborts_gate
run_test test_prompt_injection_detected
run_test test_block_soft_verdict_is_no_go
run_test test_synthesis_artifact_tamper_detected
run_test test_verdict_prefix_rejected
run_test test_hash_tool_missing_aborts_gate
run_test test_bold_final_line_rejected
run_test test_brief_construction_emits_no_shell_errors
run_test test_synthesis_multiple_final_lines_aborts_gate
run_test test_multiple_verdict_lines_aborts_gate
run_test test_reviewer_cross_artifact_tamper_detected
run_test test_base_detection_via_gh_pr_view
run_test test_base_detection_gh_fallback
run_test test_adjacent_go_test_included
run_test test_adjacent_ts_test_in_tests_dir
run_test test_adjacent_ts_test_tsx_variant
run_test test_adjacent_ts_spec_ts_variant
run_test test_adjacent_ts_spec_tsx_variant
run_test test_adjacent_ts_sibling_test
run_test test_adjacent_test_not_duplicated_when_in_diff

th_summary
