#!/usr/bin/env bash
# Regression tests for scripts/lint-model-aliases.sh.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LINTER="$REPO_ROOT/scripts/lint-model-aliases.sh"

# shellcheck source=scripts/lib/test-harness.sh
. "$SCRIPT_DIR/lib/test-harness.sh"
th_init "$@"

VALID_TSV=$'codex-spark\tgpt-5.3-codex-spark\thigh\n'
VALID_DOC=$'## Model aliases\n\n| PM-facing alias | Wire model id | Reasoning effort |\n|---|---|---|\n| `codex-spark` | `gpt-5.3-codex-spark` | high |\n'

_make_fake_repo() {
  local root="$1" tsv_content="$2" doc_content="$3"
  mkdir -p "$root/scripts" "$root/share" "$root/docs" "$root/agents" "$root/adapters/codex"
  cp "$REPO_ROOT/scripts/lint-model-aliases.sh" "$root/scripts/"
  [[ -n "$tsv_content" ]] && printf '%s' "$tsv_content" > "$root/share/model-aliases.tsv"
  printf '%s' "$doc_content" > "$root/docs/dispatch-brief.md"
  # lint-model-aliases.sh checks adapters/codex/dispatch.sh (CC-308: shim migration)
  printf 'PM_DISPATCH_ALIAS_FILE=x\n_resolve_model_alias() { :; }\n' \
    > "$root/adapters/codex/dispatch.sh"
  printf '# stub\n# --model codex-spark\n' > "$root/scripts/test-codex-dispatch.sh"
  printf '' > "$root/agents/project-pm.md"
}

_run_linter_expect() {
  local name="$1" root="$2" expected_exit="$3" expected_stderr="$4"
  local out exit_code

  set +e
  out="$(bash "$root/scripts/lint-model-aliases.sh" 2>&1)"
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
  : > "$root/share/model-aliases.tsv"
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

case_happy_path_repo_passes
case_missing_tsv_fails
case_malformed_row_fails
case_doc_drift_fails
case_empty_tsv_fails
case_template_alias_missing_from_tsv_fails

th_summary
