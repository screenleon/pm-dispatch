#!/usr/bin/env bash
# Ratchet the script-domain path, variable, and consumer inventories.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
case "${1:-}" in
  --repo)
    [[ $# -eq 2 ]] || { printf 'lint-script-domain-inventory: --repo requires one path\n' >&2; exit 2; }
    repo_root="$2"
    ;;
  "") ;;
  *) printf 'lint-script-domain-inventory: usage: %s [--repo <path>]\n' "$0" >&2; exit 2 ;;
esac

inventory="$repo_root/docs/architecture/script-domain-inventory.tsv"
variables="$repo_root/docs/architecture/script-variable-inventory.tsv"
consumers="$repo_root/docs/architecture/script-variable-consumers.tsv"
reference_allowlist="$repo_root/docs/architecture/script-domain-reference-allowlist.tsv"
contract="$repo_root/docs/architecture/script-domain-ownership.md"
failures=0

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  failures=$((failures + 1))
}

for required in "$inventory" "$variables" "$consumers" "$reference_allowlist" "$contract"; do
  [[ -f "$required" ]] || fail "missing ${required#"$repo_root"/}"
done
[[ "$failures" -eq 0 ]] || exit 1

expected_path_header=$'current_path\tartifact_kind\towner_domain\tproposed_target\tdisposition\tstability'
expected_variable_header=$'name_or_pattern\towner_domain\tinput_class\tdefault_source\tprecedence\tpropagation\trisk_or_side_effect\ttest_isolation'
expected_consumer_header=$'declared_name_or_pattern\tactual_name\tconsumer_path\treference_scope'
expected_reference_allowlist_header=$'historical_path\tconsumer_path\treason'
[[ "$(head -n1 "$inventory")" == "$expected_path_header" ]] || fail "path inventory header mismatch"
[[ "$(head -n1 "$variables")" == "$expected_variable_header" ]] || fail "variable inventory header mismatch"
[[ "$(head -n1 "$consumers")" == "$expected_consumer_header" ]] || fail "variable consumer header mismatch"
[[ "$(head -n1 "$reference_allowlist")" == "$expected_reference_allowlist_header" ]] || fail "reference allowlist header mismatch"

path_errors="$(awk -F '\t' '
  BEGIN {
    kind["executable"]; kind["sourced-lib"]; kind["fixture"]
    owner["shared-runtime"]; owner["host-claude"]; owner["host-codex"]
    owner["host-opencode"]; owner["test-harness"]; owner["ops-backlog"]
    owner["ops-diagnostics"]; owner["ops-migration"]; owner["ops-release"]
    owner["ops-setup"]; owner["ops-usage"]; owner["tooling-lint"]; owner["tooling-skill"]
    disposition["move-then-remove"]; disposition["move-with-shim"]
    stability["internal"]; stability["installed"]; stability["maintainer"]; stability["compatibility"]
  }
  NR == 1 { next }
  NF != 6 { print "line " NR " has " NF " fields"; next }
  $1 !~ /^scripts\// { print "line " NR " current path is outside scripts/: " $1 }
  !($2 in kind) { print "line " NR " unknown artifact kind: " $2 }
  !($3 in owner) { print "line " NR " unknown owner: " $3 }
  !($5 in disposition) { print "line " NR " unknown disposition: " $5 }
  !($6 in stability) { print "line " NR " unknown stability: " $6 }
  $4 ~ /^scripts\// || $4 ~ /(^|\/)\.\.(\/|$)/ { print "line " NR " unsafe proposed target: " $4 }
  $3 == "shared-runtime" && $4 !~ /^runtime\// { print "line " NR " shared runtime target mismatch: " $4 }
  $3 == "host-claude" && $4 !~ /^hosts\/claude\// { print "line " NR " Claude target mismatch: " $4 }
  $3 == "host-codex" && $4 !~ /^hosts\/codex\// { print "line " NR " Codex target mismatch: " $4 }
  $3 == "host-opencode" && $4 !~ /^hosts\/opencode\// { print "line " NR " OpenCode target mismatch: " $4 }
  $3 == "test-harness" && $4 !~ /^tests\// { print "line " NR " test target mismatch: " $4 }
  $3 ~ /^ops-/ && $4 !~ /^ops\// { print "line " NR " ops target mismatch: " $4 }
  $3 == "tooling-lint" && $4 !~ /^tools\/lint\// { print "line " NR " lint target mismatch: " $4 }
  $3 == "tooling-skill" && $4 !~ /^tools\/skills\// { print "line " NR " skill target mismatch: " $4 }
  $6 != "internal" && $5 != "move-with-shim" { print "line " NR " stable path lacks shim: " $1 }
' "$inventory")"
[[ -z "$path_errors" ]] || fail "invalid path inventory rows:\n$path_errors"

duplicate_current="$(tail -n +2 "$inventory" | cut -f1 | sort | uniq -d)"
duplicate_target="$(tail -n +2 "$inventory" | cut -f4 | sort | uniq -d)"
[[ -z "$duplicate_current" ]] || fail "duplicate current paths:\n$duplicate_current"
[[ -z "$duplicate_target" ]] || fail "duplicate proposed targets:\n$duplicate_target"

actual_paths="$(mktemp)"
declared_paths="$(mktemp)"
raw_refs="$(mktemp)"
expected_consumers="$(mktemp)"
declared_consumers="$(mktemp)"
stale_reference_hits="$(mktemp)"
stale_patterns="$(mktemp)"
cleanup() {
  rm -f "$actual_paths" "$declared_paths" "$raw_refs" \
    "$expected_consumers" "$declared_consumers" "$stale_reference_hits" \
    "$stale_patterns"
}
trap cleanup EXIT
awk -F '\t' 'NR > 1 { print $1 }' "$inventory" > "$stale_patterns"
(cd "$repo_root" && find scripts -type f -print | sort) > "$actual_paths"
awk -F '\t' 'NR > 1 && $5 == "move-with-shim" { print $1 }' "$inventory" | sort > "$declared_paths"
if ! cmp -s "$actual_paths" "$declared_paths"; then
  diff -u "$declared_paths" "$actual_paths" >&2 || true
  fail "scripts/ compatibility file set differs from path inventory"
fi

path_state_errors=""
while IFS=$'\t' read -r current_path artifact_kind _ target_path disposition _; do
  [[ "$current_path" != "current_path" ]] || continue
  if [[ ! -f "$repo_root/$target_path" ]]; then
    path_state_errors+="missing migrated target: $target_path"$'\n'
  fi
  if [[ "$disposition" == "move-then-remove" && -e "$repo_root/$current_path" ]]; then
    path_state_errors+="retired implementation path still exists: $current_path"$'\n'
  elif [[ "$disposition" == "move-with-shim" ]]; then
    if [[ ! -f "$repo_root/$current_path" ]]; then
      path_state_errors+="missing compatibility shim: $current_path"$'\n'
    elif ! grep -Fq -- "$target_path" "$repo_root/$current_path"; then
      path_state_errors+="compatibility shim target mismatch: $current_path -> $target_path"$'\n'
    elif [[ "$artifact_kind" == "executable" && ! -x "$repo_root/$current_path" ]]; then
      path_state_errors+="compatibility shim is not executable: $current_path"$'\n'
    fi
  fi
done < "$inventory"
[[ -z "$path_state_errors" ]] || fail "invalid migrated path state:\n${path_state_errors%$'\n'}"

# Current operational surfaces must name canonical owner paths. Historical
# records, migration design evidence, installed ~/.claude helper ABIs, and
# compatibility tests are intentionally outside this ratchet. Production code
# may retain a retired path only for the two explicit Codex legacy-config
# probes below; adding another exception requires a reviewed compatibility
# contract rather than weakening this scan.
is_installed_helper_reference() {
  local line="$1" old_path="$2"
  line="${line//~\/.claude\/${old_path}/}"
  [[ "$line" != *"$old_path"* ]]
}

is_legacy_code_reference_allowed() {
  local old_path="$1" relative="$2" disposition="$3"
  [[ "$disposition" == "move-with-shim" ]] && return 0
  awk -F '\t' -v old="$old_path" -v consumer="$relative" '
    NR > 1 && $1 == old && $2 == consumer { found = 1 }
    END { exit(found ? 0 : 1) }
  ' "$reference_allowlist"
}

reference_allowlist_errors="$(awk -F '\t' '
  NR == FNR {
    if (FNR > 1) disposition[$1] = $5
    next
  }
  FNR == 1 { next }
  NF != 3 { print "line " FNR " has " NF " fields"; next }
  !($1 in disposition) { print "line " FNR " path is absent from migration inventory: " $1 }
  ($1 in disposition) && disposition[$1] != "move-then-remove" {
    print "line " FNR " allowlist is unnecessary for shim path: " $1
  }
  $2 ~ /^\// || $2 ~ /(^|\/)\.\.(\/|$)/ { print "line " FNR " unsafe consumer path: " $2 }
  $3 !~ /^[a-z0-9][a-z0-9-]*$/ { print "line " FNR " invalid reason slug: " $3 }
' "$inventory" "$reference_allowlist")"
[[ -z "$reference_allowlist_errors" ]] || fail "invalid stale-reference allowlist rows:\n$reference_allowlist_errors"
duplicate_reference_allowlist="$(tail -n +2 "$reference_allowlist" | cut -f1,2 | sort | uniq -d)"
[[ -z "$duplicate_reference_allowlist" ]] || fail "duplicate stale-reference allowlist rows:\n$duplicate_reference_allowlist"
while IFS=$'\t' read -r _ allowed_consumer _; do
  [[ "$allowed_consumer" != "consumer_path" ]] || continue
  [[ -f "$repo_root/$allowed_consumer" ]] || fail "missing stale-reference allowlist consumer: $allowed_consumer"
done < "$reference_allowlist"

scan_stale_reference_file() {
  local file="$1" mode="$2" relative old_path target_path disposition
  local line_number line
  [[ -f "$file" ]] || return 0
  relative="${file#"$repo_root"/}"
  while IFS=: read -r line_number line; do
    [[ -n "$line_number" ]] || continue
    while IFS=$'\t' read -r old_path _ _ target_path disposition _; do
      [[ "$old_path" != "current_path" && "$line" == *"$old_path"* ]] || continue
      is_installed_helper_reference "$line" "$old_path" && continue
      if [[ "$mode" == "code" ]] \
          && is_legacy_code_reference_allowed "$old_path" "$relative" "$disposition"; then
        continue
      fi
      printf '%s:%s: stale %s (use %s)\n' \
        "$relative" "$line_number" "$old_path" "$target_path" >> "$stale_reference_hits"
    done < "$inventory"
  done < <(grep -nF -f "$stale_patterns" -- "$file" || true)
}

for operational_doc in README.md core/README.md BACKLOG.md MILESTONES.md; do
  scan_stale_reference_file "$repo_root/$operational_doc" docs
done
while IFS= read -r -d '' operational_doc; do
  case "${operational_doc#"$repo_root"/}" in
    docs/spikes/*|docs/architecture/script-domain-inventory.tsv|\
    docs/architecture/script-domain-reference-allowlist.tsv|\
    docs/architecture/script-domain-ownership.md|\
    docs/architecture/v0.3.0-synthesis.md) continue ;;
  esac
  scan_stale_reference_file "$operational_doc" docs
done < <(find "$repo_root/docs" -type f -print0 2>/dev/null)
for code_root in install.sh uninstall.sh cli runtime hosts ops tools .github; do
  if [[ -f "$repo_root/$code_root" ]]; then
    scan_stale_reference_file "$repo_root/$code_root" code
  elif [[ -d "$repo_root/$code_root" ]]; then
    while IFS= read -r -d '' code_file; do
      scan_stale_reference_file "$code_file" code
    done < <(find "$repo_root/$code_root" -type f -print0)
  fi
done
if [[ -s "$stale_reference_hits" ]]; then
  fail "stale migrated implementation references:\n$(cat "$stale_reference_hits")"
fi

variable_errors="$(awk -F '\t' '
  BEGIN {
    class["internal-derived"]; class["argv-derived"]; class["ambient-public"]
    class["child-control"]; class["host-root"]; class["legacy-alias"]
    class["public-override"]; class["compatibility-input"]; class["resolved-config"]
    class["emergency-override"]; class["internal-injection"]; class["hook-control"]
    class["hook-injection"]; class["test-config"]; class["test-injection"]
    class["secret-passthrough"]
  }
  NR == 1 { next }
  NF != 8 { print "line " NR " has " NF " fields"; next }
  $1 !~ /^_?[A-Z][A-Z0-9_]*\*?$/ { print "line " NR " invalid variable name or pattern: " $1 }
  !($3 in class) { print "line " NR " unknown input class: " $3 }
  $3 == "secret-passthrough" && $4 != "none" { print "line " NR " secret must not declare a default: " $1 }
' "$variables")"
[[ -z "$variable_errors" ]] || fail "invalid variable inventory rows:\n$variable_errors"

duplicate_variables="$(tail -n +2 "$variables" | cut -f1 | sort | uniq -d)"
[[ -z "$duplicate_variables" ]] || fail "duplicate variable declarations:\n$duplicate_variables"

consumer_errors="$(awk -F '\t' '
  NR == FNR {
    if (FNR > 1) declared[$1] = 1
    next
  }
  FNR == 1 { next }
  NF == 0 { next }
  NF != 4 { print "line " FNR " has " NF " fields"; next }
  !($1 in declared) { print "line " FNR " undeclared variable pattern: " $1 }
  $4 != "production" && $4 != "test" { print "line " FNR " invalid reference scope: " $4 }
  $3 ~ /^\// || $3 ~ /(^|\/)\.\.(\/|$)/ { print "line " FNR " unsafe consumer path: " $3 }
  {
    pattern = $1
    if (pattern ~ /\*$/) {
      sub(/\*$/, "", pattern)
      if (index($2, pattern) != 1) print "line " FNR " actual variable does not match pattern: " $1 " -> " $2
    } else if ($1 != $2) {
      print "line " FNR " exact variable mismatch: " $1 " -> " $2
    }
    seen[$1] = 1
  }
  END {
    for (name in declared) if (!(name in seen)) print "variable has no consumer reference: " name
  }
' "$variables" "$consumers")"
[[ -z "$consumer_errors" ]] || fail "invalid variable consumer rows:\n$consumer_errors"

consumer_path_errors=""
while IFS=$'\t' read -r _ _ consumer_path _; do
  [[ -n "$consumer_path" && "$consumer_path" != "consumer_path" ]] || continue
  case "$consumer_path" in
    /*|../*|*/../*|*/..) continue ;;
  esac
  if [[ ! -e "$repo_root/$consumer_path" ]]; then
    consumer_path_errors+="missing consumer path: $consumer_path"$'\n'
  fi
done < "$consumers"
[[ -z "$consumer_path_errors" ]] || fail "invalid variable consumer paths:\n${consumer_path_errors%$'\n'}"

duplicate_consumers="$(tail -n +2 "$consumers" | sort | uniq -d)"
[[ -z "$duplicate_consumers" ]] || fail "duplicate variable consumer rows:\n$duplicate_consumers"

collect_refs() {
  local file="$1" relative scope token
  [[ -f "$file" ]] || return 0
  relative="${file#"$repo_root"/}"
  scope="production"
  case "$relative" in
    tests/shell/test-*.sh|tests/lib/test-*.sh|*/fixtures/*) scope="test" ;;
  esac
  while IFS= read -r token; do
    [[ -n "$token" ]] || continue
    printf '%s\t%s\t%s\n' "$token" "$relative" "$scope" >> "$raw_refs"
  done < <(grep -Eo '_?[A-Z][A-Z0-9_]*' "$file" | sort -u || true)
}

collect_refs "$repo_root/install.sh"
collect_refs "$repo_root/uninstall.sh"
collect_refs "$repo_root/cli/pmctl"
while IFS= read -r -d '' candidate; do
  collect_refs "$candidate"
done < <(find "$repo_root/scripts" "$repo_root/runtime" "$repo_root/tests" \
  "$repo_root/ops" "$repo_root/tools" "$repo_root/adapters" "$repo_root/hosts" \
  -type f -name '*.sh' -print0)

awk -F '\t' '
  NR == FNR {
    if (FNR > 1) owner[$1] = $2
    next
  }
  {
    token = $1
    for (declared in owner) {
      prefix = declared
      wildcard = sub(/\*$/, "", prefix)
      matches = wildcard ? index(token, prefix) == 1 : token == declared
      if (matches && (owner[declared] == "test-harness" || $3 != "test"))
        print declared "\t" token "\t" $2 "\t" $3
    }
  }
' "$variables" "$raw_refs" | sort -u > "$expected_consumers"
tail -n +2 "$consumers" | sed '/^[[:space:]]*$/d' | sort -u > "$declared_consumers"
if ! cmp -s "$expected_consumers" "$declared_consumers"; then
  diff -u "$declared_consumers" "$expected_consumers" >&2 || true
  fail "variable consumer graph is stale"
fi

if grep -Eq 'CC-[0-9]+' "$contract" "$inventory" "$reference_allowlist" "$variables" "$consumers"; then
  fail "operational architecture inventory contains a ticket identifier"
fi

[[ "$failures" -eq 0 ]] || exit 1
printf 'lint-script-domain-inventory: OK (%s paths, %s variables, %s consumer refs)\n' \
  "$(( $(wc -l < "$inventory") - 1 ))" \
  "$(( $(wc -l < "$variables") - 1 ))" \
  "$(tail -n +2 "$consumers" | sed '/^[[:space:]]*$/d' | wc -l)"
