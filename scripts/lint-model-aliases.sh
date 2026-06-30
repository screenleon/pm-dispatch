#!/usr/bin/env bash
# Ensure PM-facing model alias data stays single-source-of-truth.
# Verifies:
#   - share/model-aliases.tsv is well-formed and non-empty
#   - docs/dispatch-brief.md ## Model aliases table is byte-equal to the codex TSV
#   - docs/dispatch-brief.md ## Claude model aliases table is byte-equal to the claude TSV
#   - PM template hardcoded model aliases (if any) appear in the codex TSV
#   - model alias fixtures mention those aliases in tests
#   - runtime loader in adapters/codex/dispatch.sh still reads from share/model-aliases.tsv
#   - claude adapter references PM_CLAUDE_ALIAS_FILE and _resolve_claude_model_alias
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
alias_tsv="$repo_root/share/model-aliases.tsv"
claude_alias_tsv="$repo_root/share/claude-model-aliases.tsv"
dispatch_brief="$repo_root/docs/dispatch-brief.md"
pm_template="$repo_root/agents/project-pm.md"
dispatch_script="$repo_root/adapters/codex/dispatch.sh"
claude_dispatch_script="$repo_root/adapters/claude/dispatch.sh"
test_script="$repo_root/scripts/test-codex-dispatch.sh"
claude_test_script="$repo_root/scripts/test-claude-dispatch.sh"

work_dir="$(mktemp -d)"
sot_file="$work_dir/sot.tsv"
doc_file="$work_dir/doc.tsv"
template_file="$work_dir/template.tsv"

# shellcheck disable=SC2329  # invoked indirectly via trap below
cleanup() {
  rm -rf "$work_dir"
}
trap cleanup EXIT

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

strip_code_ticks() {
  local value="$1"
  value="$(trim "$value")"
  value="${value//\`/}"
  printf '%s' "$value"
}

read_sot() {
  local line_no=0
  local line alias model effort rest

  if [[ ! -f "$alias_tsv" ]]; then
    echo "lint-model-aliases: ERROR: missing model alias source file: $alias_tsv" >&2
    return 1
  fi

  while IFS= read -r line || [[ -n "$line" ]]; do
    line_no=$((line_no + 1))
    line="${line%$'\r'}"
    line="$(trim "$line")"
    [[ -z "$line" || ${line:0:1} == \# ]] && continue

    IFS=$'\t' read -r alias model effort rest <<< "$line"
    if [[ -z "$alias" || -z "$model" || -z "$effort" || -n "$rest" ]]; then
      echo "lint-model-aliases: ERROR: malformed model-alias line in $alias_tsv:$line_no" >&2
      echo "Expected exactly three tab-separated columns: <alias> <model> <reasoning effort>." >&2
      return 1
    fi

    printf '%s\t%s\t%s\n' "$alias" "$model" "$effort"
  done < "$alias_tsv"
}

read_claude_sot() {
  local line_no=0
  local line alias model effort rest

  if [[ ! -f "$claude_alias_tsv" ]]; then
    echo "lint-model-aliases: ERROR: missing claude model alias source file: $claude_alias_tsv" >&2
    return 1
  fi

  while IFS= read -r line || [[ -n "$line" ]]; do
    line_no=$((line_no + 1))
    line="${line%$'\r'}"
    line="$(trim "$line")"
    [[ -z "$line" || ${line:0:1} == \# ]] && continue

    IFS=$'\t' read -r alias model effort rest <<< "$line"
    if [[ -z "$alias" || -z "$model" || -z "$effort" || -n "$rest" ]]; then
      echo "lint-model-aliases: ERROR: malformed model-alias line in $claude_alias_tsv:$line_no" >&2
      echo "Expected exactly three tab-separated columns: <alias> <model> <reasoning effort>." >&2
      return 1
    fi

    printf '%s\t%s\t%s\n' "$alias" "$model" "$effort"
  done < "$claude_alias_tsv"
}

# Read a named section (## <heading>) from docs/dispatch-brief.md until next ## heading.
read_dispatch_table_section() {
  local target_heading="$1"
  local line alias model effort
  local in_section=0

  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$(trim "$line")" == "## ${target_heading}" ]]; then
      in_section=1
      continue
    fi
    if [[ "$in_section" -eq 1 && "$line" == "## "* ]]; then
      break
    fi
    [[ "$in_section" -ne 1 ]] && continue
    [[ "$line" != '|'* || "$line" == *'---'* ]] && continue

    IFS='|' read -r _ alias model effort _ <<< "$(trim "$line")"
    [[ -z "$alias" || -z "$model" || -z "$effort" ]] && continue
    alias="$(strip_code_ticks "$alias")"
    model="$(strip_code_ticks "$model")"
    effort="$(strip_code_ticks "$effort")"
    [[ "$alias" == "PM-facing alias" || "$alias" == '---' ]] && continue

    printf '%s\t%s\t%s\n' "$alias" "$model" "$effort"
  done < "$dispatch_brief"
}

read_dispatch_table() {
  read_dispatch_table_section "Model aliases"
}

read_pm_template_aliases() {
  local line
  local token

  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" =~ --model[[:space:]]+([^[:space:]]+) ]]; then
      token="${BASH_REMATCH[1]}"
      token="$(strip_code_ticks "$token")"
      case "$token" in
        default|\`default\`|'')
          continue
          ;;
        *)
          printf '%s\n' "$token"
          ;;
      esac
    fi
  done < "$pm_template"
}

cat > "$sot_file" < <(read_sot)
cat > "$doc_file" < <(read_dispatch_table)
cat > "$template_file" < <(read_pm_template_aliases)

sort -u "$sot_file" -o "$sot_file"
sort -u "$doc_file" -o "$doc_file"
sort -u "$template_file" -o "$template_file"

sot_aliases="$work_dir/sot_aliases.txt"
template_aliases="$work_dir/template_aliases.txt"

cut -f1 "$sot_file" | sort -u > "$sot_aliases"
cp "$template_file" "$template_aliases"

# --- codex alias checks ---

if ! diff -u "$sot_file" "$doc_file" >/dev/null; then
  echo "lint-model-aliases: ERROR: model alias TSV and docs/dispatch-brief.md ## Model aliases table are out of sync." >&2
  diff -u "$sot_file" "$doc_file" >&2
  exit 1
fi

if [[ -s "$template_aliases" ]]; then
  while IFS= read -r alias || [[ -n "$alias" ]]; do
    if ! grep -Fqx -- "$alias" "$sot_aliases"; then
      echo "lint-model-aliases: ERROR: template alias '$alias' not present in $alias_tsv" >&2
      exit 1
    fi
  done < "$template_aliases"
fi

if ! grep -q "PM_DISPATCH_ALIAS_FILE" "$dispatch_script"; then
  echo "lint-model-aliases: ERROR: runtime dispatcher no longer references PM_DISPATCH_ALIAS_FILE" >&2
  exit 1
fi

if ! grep -q "ma_resolve_alias" "$dispatch_script"; then
  echo "lint-model-aliases: ERROR: runtime dispatcher no longer uses ma_resolve_alias()" >&2
  exit 1
fi

while IFS= read -r alias || [[ -n "$alias" ]]; do
  if [[ -z "$alias" ]]; then
    continue
  fi
  if ! grep -Fq -- "--model $alias" "$test_script" && ! grep -Fq -- "--model=$alias" "$test_script"; then
    echo "lint-model-aliases: ERROR: alias '$alias' from model-aliases.tsv is not covered by test fixtures." >&2
    exit 1
  fi
done < "$sot_aliases"

if ! [[ -s "$sot_file" ]]; then
  echo "lint-model-aliases: ERROR: no aliases defined in $alias_tsv" >&2
  exit 1
fi

# --- claude alias checks ---

claude_sot_file="$work_dir/claude_sot.tsv"
claude_doc_file="$work_dir/claude_doc.tsv"

cat > "$claude_sot_file" < <(read_claude_sot)
cat > "$claude_doc_file" < <(read_dispatch_table_section "Claude model aliases")

sort -u "$claude_sot_file" -o "$claude_sot_file"
sort -u "$claude_doc_file" -o "$claude_doc_file"

if ! diff -u "$claude_sot_file" "$claude_doc_file" >/dev/null; then
  echo "lint-model-aliases: ERROR: claude alias TSV and docs/dispatch-brief.md ## Claude model aliases table are out of sync." >&2
  diff -u "$claude_sot_file" "$claude_doc_file" >&2
  exit 1
fi

if ! [[ -s "$claude_sot_file" ]]; then
  echo "lint-model-aliases: ERROR: no aliases defined in $claude_alias_tsv" >&2
  exit 1
fi

if ! grep -q "PM_CLAUDE_ALIAS_FILE" "$claude_dispatch_script"; then
  echo "lint-model-aliases: ERROR: claude adapter no longer references PM_CLAUDE_ALIAS_FILE" >&2
  exit 1
fi

if ! grep -q "ma_resolve_alias" "$claude_dispatch_script"; then
  echo "lint-model-aliases: ERROR: claude adapter no longer uses ma_resolve_alias()" >&2
  exit 1
fi

claude_sot_aliases="$work_dir/claude_sot_aliases.txt"
cut -f1 "$claude_sot_file" | sort -u > "$claude_sot_aliases"

while IFS= read -r alias || [[ -n "$alias" ]]; do
  [[ -z "$alias" ]] && continue
  if ! grep -Fq -- "--model $alias" "$claude_test_script" && ! grep -Fq -- "--model=$alias" "$claude_test_script"; then
    echo "lint-model-aliases: ERROR: claude alias '$alias' from $claude_alias_tsv is not covered by test fixtures in $claude_test_script." >&2
    exit 1
  fi
done < "$claude_sot_aliases"

exit 0
