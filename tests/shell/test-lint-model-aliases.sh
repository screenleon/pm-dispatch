#!/usr/bin/env bash
# Regression tests for tools/lint/lint-model-aliases.sh.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LINTER="$REPO_ROOT/tools/lint/lint-model-aliases.sh"

# shellcheck source=tests/lib/test-harness.sh
. "$SCRIPT_DIR/../lib/test-harness.sh"
th_init "$@"

VALID_CODEX_TSV=$'codex-spark\tgpt-5.3-codex-spark\thigh\n'
VALID_CLAUDE_TSV=$'light\tclaude-haiku\tnormal\n'
VALID_TSV="$VALID_CODEX_TSV"
VALID_DOC=$'## Model aliases\n\n| PM-facing alias | Wire model id | Reasoning effort |\n|---|---|---|\n| `codex-spark` | `gpt-5.3-codex-spark` | high |\n\n## Claude model aliases\n\n| PM-facing alias | Wire-format model ID | reasoning effort |\n|---|---|---|\n| `light` | `claude-haiku` | normal |\n'

_make_fake_repo() {
  local root="$1" tsv_content="$2" doc_content="$3"
  local claude_tsv_content="${4:-$VALID_CLAUDE_TSV}"
  mkdir -p "$root/tools/lint" "$root/share" "$root/docs" "$root/agents" "$root/tests/shell" \
           "$root/adapters/codex" "$root/adapters/claude"
  cp "$REPO_ROOT/tools/lint/lint-model-aliases.sh" "$root/tools/lint/"
  [[ -n "$tsv_content" ]] && printf '%s' "$tsv_content" > "$root/share/codex-model-aliases.tsv"
  printf '%s' "$claude_tsv_content" > "$root/share/claude-model-aliases.tsv"
  printf '%s' "$doc_content" > "$root/docs/dispatch-brief.md"
  # codex adapter stub
  printf 'PM_DISPATCH_ALIAS_FILE=x\nma_resolve_alias_strict() { :; }\n_resolve_model_alias() { ma_resolve_alias_strict "$@"; }\n' \
    > "$root/adapters/codex/dispatch.sh"
  printf '# stub\n# --model codex-spark\n' > "$root/tests/shell/test-codex-dispatch.sh"
  # claude adapter stub
  printf 'PM_CLAUDE_ALIAS_FILE=x\nma_resolve_alias() { :; }\n_resolve_claude_model_alias() { ma_resolve_alias "$@"; }\n' \
    > "$root/adapters/claude/dispatch.sh"
  printf '# stub\n# --model light\n' > "$root/tests/shell/test-claude-dispatch.sh"
  printf '' > "$root/agents/project-pm.md"
}

_run_linter_expect() {
  local name="$1" root="$2" expected_exit="$3" expected_stderr="$4"
  local out exit_code

  set +e
  out="$(bash "$root/tools/lint/lint-model-aliases.sh" 2>&1)"
  exit_code=$?
  set -e

  if [[ "$expected_exit" == "0" ]]; then
    if [[ "$exit_code" -eq 0 ]]; then
      pass "$name"
    else
      fail "$name" "exit=$exit_code out=$(head -1 <<<"$out")"
    fi
    return 0
  fi

  if [[ "$exit_code" -ne 0 ]] && grep -Fqi -- "$expected_stderr" <<<"$out"; then
    pass "$name"
  else
    fail "$name" "exit=$exit_code out=$(head -1 <<<"$out")"
  fi
}

case_happy_path_repo_passes() {
  local name="lint-model-aliases/happy path repo passes"
  local out exit_code
  should_run "$name" || return 0

  set +e
  out="$(bash "$LINTER" 2>&1)"
  exit_code=$?
  set -e

  if [[ "$exit_code" -eq 0 ]]; then
    pass "$name"
  else
    fail "$name" "exit=$exit_code out=$(head -1 <<<"$out")"
  fi
}

case_missing_tsv_fails() {
  local name="lint-model-aliases/missing TSV fails"
  local root
  should_run "$name" || return 0
  root="$(mktemp -d)"
  _make_fake_repo "$root" "" ""
  _run_linter_expect "$name" "$root" "nonzero" "missing model alias source file"
  rm -rf "$root"
}

case_malformed_row_fails() {
  local name="lint-model-aliases/malformed row fails"
  local root
  should_run "$name" || return 0
  root="$(mktemp -d)"
  _make_fake_repo "$root" $'bad-alias\tgpt-5.3\n' ""
  _run_linter_expect "$name" "$root" "nonzero" "malformed model-alias line"
  rm -rf "$root"
}

case_doc_drift_fails() {
  local name="lint-model-aliases/doc drift fails"
  local root doc
  should_run "$name" || return 0
  root="$(mktemp -d)"
  doc=$'## Model aliases\n\n| PM-facing alias | Wire model id | Reasoning effort |\n|---|---|---|\n| `different-alias` | `gpt-5.3-codex-spark` | high |\n'
  _make_fake_repo "$root" $'codex-spark\tgpt-5.3\thigh\n' "$doc"
  _run_linter_expect "$name" "$root" "nonzero" "out of sync"
  rm -rf "$root"
}

case_empty_tsv_fails() {
  local name="lint-model-aliases/empty TSV fails"
  local root
  should_run "$name" || return 0
  root="$(mktemp -d)"
  _make_fake_repo "$root" "placeholder" ""
  : > "$root/share/codex-model-aliases.tsv"
  _run_linter_expect "$name" "$root" "nonzero" "no aliases defined"
  rm -rf "$root"
}

case_template_alias_missing_from_tsv_fails() {
  local name="lint-model-aliases/template alias missing from TSV fails"
  local root
  should_run "$name" || return 0
  root="$(mktemp -d)"
  _make_fake_repo "$root" "$VALID_TSV" "$VALID_DOC"
  printf 'codex exec --model unknown-alias\n' > "$root/agents/project-pm.md"
  _run_linter_expect "$name" "$root" "nonzero" "template alias"
  rm -rf "$root"
}

# --- claude alias lint failure cases ---

case_claude_missing_tsv_fails() {
  local name="lint-model-aliases/claude missing TSV fails"
  local root
  should_run "$name" || return 0
  root="$(mktemp -d)"
  _make_fake_repo "$root" "$VALID_TSV" "$VALID_DOC"
  rm -f "$root/share/claude-model-aliases.tsv"
  _run_linter_expect "$name" "$root" "nonzero" "missing claude model alias source file"
  rm -rf "$root"
}

case_claude_malformed_row_fails() {
  local name="lint-model-aliases/claude malformed TSV row fails"
  local root
  should_run "$name" || return 0
  root="$(mktemp -d)"
  _make_fake_repo "$root" "$VALID_TSV" "$VALID_DOC" $'bad\tonly-two\n'
  _run_linter_expect "$name" "$root" "nonzero" "malformed model-alias line"
  rm -rf "$root"
}

case_claude_empty_tsv_fails() {
  local name="lint-model-aliases/claude empty TSV fails"
  local root doc_no_claude_rows
  should_run "$name" || return 0
  root="$(mktemp -d)"
  # Doc has Claude section but no data rows; TSV is also empty → "no aliases defined"
  doc_no_claude_rows=$'## Model aliases\n\n| PM-facing alias | Wire model id | Reasoning effort |\n|---|---|---|\n| `codex-spark` | `gpt-5.3-codex-spark` | high |\n\n## Claude model aliases\n\n(none)\n'
  _make_fake_repo "$root" "$VALID_TSV" "$doc_no_claude_rows" ""
  : > "$root/share/claude-model-aliases.tsv"
  _run_linter_expect "$name" "$root" "nonzero" "no aliases defined"
  rm -rf "$root"
}

case_claude_doc_drift_fails() {
  local name="lint-model-aliases/claude doc drift fails"
  local root doc
  should_run "$name" || return 0
  root="$(mktemp -d)"
  # TSV has 'light', doc has 'different-alias' — drift
  doc=$'## Model aliases\n\n| PM-facing alias | Wire model id | Reasoning effort |\n|---|---|---|\n| `codex-spark` | `gpt-5.3-codex-spark` | high |\n\n## Claude model aliases\n\n| PM-facing alias | Wire-format model ID | reasoning effort |\n|---|---|---|\n| `different-alias` | `claude-haiku` | normal |\n'
  _make_fake_repo "$root" "$VALID_TSV" "$doc"
  _run_linter_expect "$name" "$root" "nonzero" "out of sync"
  rm -rf "$root"
}

case_claude_adapter_missing_reference_fails() {
  local name="lint-model-aliases/claude adapter missing PM_CLAUDE_ALIAS_FILE fails"
  local root
  should_run "$name" || return 0
  root="$(mktemp -d)"
  _make_fake_repo "$root" "$VALID_TSV" "$VALID_DOC"
  printf '# stub without alias file reference\nma_resolve_alias() { :; }\n_resolve_claude_model_alias() { ma_resolve_alias "$@"; }\n' \
    > "$root/adapters/claude/dispatch.sh"
  _run_linter_expect "$name" "$root" "nonzero" "PM_CLAUDE_ALIAS_FILE"
  rm -rf "$root"
}

case_claude_adapter_missing_resolver_fails() {
  local name="lint-model-aliases/claude adapter missing _resolve_claude_model_alias fails"
  local root
  should_run "$name" || return 0
  root="$(mktemp -d)"
  _make_fake_repo "$root" "$VALID_TSV" "$VALID_DOC"
  # Keep PM_CLAUDE_ALIAS_FILE but omit the shared lib call
  printf 'PM_CLAUDE_ALIAS_FILE=x\n# resolver deliberately absent\n' \
    > "$root/adapters/claude/dispatch.sh"
  _run_linter_expect "$name" "$root" "nonzero" "ma_resolve_alias"
  rm -rf "$root"
}

case_claude_fixture_alias_missing_fails() {
  local name="lint-model-aliases/claude alias not covered by test fixture fails"
  local root
  should_run "$name" || return 0
  root="$(mktemp -d)"
  _make_fake_repo "$root" "$VALID_TSV" "$VALID_DOC"
  # test-claude-dispatch.sh stub has no --model light fixture
  printf '# stub — no model alias fixtures\n' > "$root/tests/shell/test-claude-dispatch.sh"
  _run_linter_expect "$name" "$root" "nonzero" "not covered by test fixtures"
  rm -rf "$root"
}

case_happy_path_repo_passes
case_missing_tsv_fails
case_malformed_row_fails
case_doc_drift_fails
case_empty_tsv_fails
case_template_alias_missing_from_tsv_fails
case_claude_missing_tsv_fails
case_claude_malformed_row_fails
case_claude_empty_tsv_fails
case_claude_doc_drift_fails
case_claude_adapter_missing_reference_fails
case_claude_adapter_missing_resolver_fails
case_claude_fixture_alias_missing_fails

th_summary
