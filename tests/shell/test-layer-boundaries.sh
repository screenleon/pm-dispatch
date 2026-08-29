#!/usr/bin/env bash
# Layer-boundary enforcer (CC-233).
#
# The domain architecture (core/ policy/schema; runtime/ shared execution;
# hosts/ host-owned integration; adapters/ thin executors; ops/ maintenance;
# tools/ authoring checks; tests/ verification) is only a discipline unless
# something enforces the dependency direction. This test is that enforcer: it
# keeps `core/` declarative and CLI-agnostic and keeps thin adapters from
# re-absorbing the shared dispatch flow that pmctl owns.
#
# Each rule is a function that scans a given ROOT and prints offending paths/
# lines (empty output = clean). The suite asserts the REAL repo is clean, then
# plants violations in a fixture to prove every rule actually fires (an enforcer
# that can't catch a violation is worse than none).
#
# Boundary the rules encode (calibrated against the real tree, CC-233):
#   - `core/` is definitions only: no shell/executables, no CLI-product-named
#     files/dirs, only .yaml/.json/.md/.tsv, no CLI product name as a field-name KEY.
#     (CLI names MAY appear as enum VALUES / schema descriptions / prose — those
#      are data, not structure; the rules check structure, ignore prose.)
#   - `adapters/**/*.sh` must NOT call the shared FLOW (brief-validate, guard,
#     route, post-verify, or pmctl itself) in non-comment lines. Executor-specific
#     invocation + output-contract glue + best-effort state/usage logging are
#     ALLOWED (they parse executor-native formats and cannot live in pmctl).
#   - Production shell domains must not write state-store entities directly.
#     The designated writer module owns those mutations; the pure state-path
#     resolver and layout-declared rebuildable SQLite caches are bounded
#     exemptions.
set -euo pipefail
export LC_ALL=C.UTF-8

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=tests/lib/test-harness.sh
. "$SCRIPT_DIR/../lib/test-harness.sh"
th_init "$@"

CLI_NAMES='codex|claude|antigravity|opencode'

# ── Rule checkers (print violations; empty = clean) ───────────────────────────

# C1: core/ contains no shell scripts or executable files.
check_core_no_executables() {
  local root="$1"
  [[ -d "$root/core" ]] || return 0
  find "$root/core" -type f \( -name '*.sh' -o -perm -u+x \) 2>/dev/null
}

# C2: no file or directory under core/ is named after a CLI product.
check_core_no_cli_named_paths() {
  local root="$1"
  [[ -d "$root/core" ]] || return 0
  find "$root/core" \( -iname '*codex*' -o -iname '*claude*' \
    -o -iname '*antigravity*' -o -iname '*opencode*' \) 2>/dev/null
}

# C3: core/ holds only declarative file types (.yaml/.yml/.json/.md/.tsv).
check_core_only_declarative() {
  local root="$1"
  [[ -d "$root/core" ]] || return 0
  find "$root/core" -type f \
    ! \( -name '*.yaml' -o -name '*.yml' -o -name '*.json' -o -name '*.md' \
      -o -name '*.tsv' \) 2>/dev/null
}

# C4: no CLI product name appears as a field-name KEY (YAML/JSON) in core/.
# Matches `  codex:` / `  "claude":` (key position) — NOT `- codex` (list value)
# or `["codex","claude"]` (array value) or prose.
check_core_no_cli_field_keys() {
  local root="$1"
  [[ -d "$root/core" ]] || return 0
  grep -rnE "^[[:space:]]*\"?($CLI_NAMES)\"?[[:space:]]*:" "$root/core" 2>/dev/null || true
}

# A1: adapters/**/*.sh must not call the shared dispatch FLOW (non-comment lines).
check_adapters_no_shared_flow() {
  local root="$1" f line
  [[ -d "$root/adapters" ]] || return 0
  local pattern='pmctl_guard_check|pmctl-guard|pmctl-dispatch|executor-router|dispatch_route_for|resolve_executor|handover-validate|brief-validate|dispatch-post-verify|cli/pmctl|pmctl (dispatch|guard|backlog)'
  while IFS= read -r f; do
    # Strip full-line comments before matching so doc-headers that DESCRIBE the
    # shared flow ("# brief-validate / guard / route / post-verify") don't trip.
    if line="$(grep -vE '^[[:space:]]*#' "$f" | grep -nE "$pattern")"; then
      printf '%s: %s\n' "${f#"$root"/}" "$line"
    fi
  done < <(find "$root/adapters" -type f -name '*.sh' 2>/dev/null)
}

# A2: adapters/**/*.sh must not write machine state directly (non-comment lines).
check_adapters_no_state_writes() {
  local root="$1" f line
  [[ -d "$root/adapters" ]] || return 0
  local pattern='sw_append_dispatch_run|runs_append|events_append|PM_DISPATCH_STATE_ROOT'
  while IFS= read -r f; do
    if line="$(grep -vE '^[[:space:]]*#' "$f" | grep -nE "$pattern")"; then
      printf '%s: %s\n' "${f#"$root"/}" "$line"
    fi
  done < <(find "$root/adapters" -type f -name '*.sh' 2>/dev/null)
}

# L1: shared runtime libraries and the prompt hook must not declare bash-4.3
# namerefs (`local -n` / `declare -n` / `typeset -n`). memory_usage_load once
# took caller-named arrays this way, which would have been the repo's only 4.3
# dependency — in a library the prompt hook sources. A whole-tree scan replaces
# the old three-hardcoded-file pin so a new lib cannot reintroduce it unseen.
#
# Matches a declaration whose option sequence contains an `-n`-bearing flag,
# including split options (`local -r -n ref`) and clusters (`local -An`); a
# `declare -A` / `local -r` decl carries no `n` and does not match. Like the
# adapter/state sibling rules this scans non-comment lines, so the spelling
# inside a diagnostic string also trips it — intentional: a shared lib has no
# reason to print `local -n` either. Comments are stripped first.
check_shared_lib_no_namerefs() {
  local root="$1" d f line
  local decl='(local|declare|typeset)[[:space:]]+(-[A-Za-z]+[[:space:]]+)*-[A-Za-z]*n[A-Za-z]*([[:space:]]|=|$)'
  for d in runtime/lib runtime/hooks; do
    [[ -d "$root/$d" ]] || continue
    while IFS= read -r f; do
      if line="$(grep -vE '^[[:space:]]*#' "$f" | grep -nE "$decl")"; then
        printf '%s: %s\n' "${f#"$root"/}" "$line"
      fi
    done < <(find "$root/$d" -type f -name '*.sh' 2>/dev/null)
  done
}

# L2: shared libraries declared adapter-agnostic must not name a concrete
# adapter anywhere in non-comment code — branches (`case … in codex)`), helper
# names, OR string literals (`"dispatched via codex"`). A file on this list
# receives its per-adapter data from the caller; naming an adapter in its own
# body, even in a message, means it is not actually adapter-agnostic. Comments
# are stripped first (they may describe the contract). Extend the contract by
# adding a path to this array.
ADAPTER_AGNOSTIC_LIBS=(runtime/lib/dispatch-common.sh)
check_shared_lib_adapter_agnostic() {
  local root="$1" rel f line
  for rel in "${ADAPTER_AGNOSTIC_LIBS[@]}"; do
    f="$root/$rel"
    [[ -f "$f" ]] || continue
    if line="$(grep -vE '^[[:space:]]*#' "$f" | grep -nE '\b(codex|claude|opencode|grok)\b')"; then
      printf '%s: %s\n' "$rel" "$line"
    fi
  done
}

# S1: all production shell domains must route state-entity mutations through
# runtime/lib/state-writer.sh. This is deliberately a content ratchet rather
# than a path-only convention: a new direct redirect, jq redirect, mv/cp, or
# equivalent mutator aimed at the state root or a known state entity fails.
#
# The resolver is exempt because it computes paths without mutating the store.
# Rebuildable SQLite caches are derived dynamically from layout.yaml and are
# exempt only when written through sqlite3; mentioning a derived cache cannot
# hide a write to a load-bearing entity on the same line.
check_production_no_direct_state_writes() {
  local root="$1" layout f relative
  local rebuildable_names=""
  layout="$root/core/state/layout.yaml"
  [[ -f "$layout" ]] || {
    printf 'core/state/layout.yaml: missing state layout contract\n'
    return 0
  }

  rebuildable_names="$(awk '
    /^[[:space:]]*- path:[[:space:]]*/ {
      path = $0
      sub(/^[[:space:]]*- path:[[:space:]]*["'\'' ]*/, "", path)
      sub(/["'\'' ]*[[:space:]]*$/, "", path)
      next
    }
    /^[[:space:]]*rebuildable:[[:space:]]*true([[:space:]]*#.*)?$/ && path != "" {
      n = split(path, parts, "/")
      print parts[n]
      path = ""
    }
  ' "$layout" | paste -sd '|' -)"

  while IFS= read -r -d '' f; do
    relative="${f#"$root"/}"
    case "$relative" in
      runtime/lib/state-writer.sh|runtime/lib/state-paths.sh) continue ;;
    esac
    awk -v relative="$relative" -v rebuildable_names="$rebuildable_names" '
      function direct_mutation(s) {
        return s ~ /^[[:space:]]*(if[[:space:]]+!?[[:space:]]*)?(cp|mv|install|tee|touch|truncate|mkdir|rm|ln|sqlite3)([[:space:]]|$)/ \
          || s ~ /[;&|][[:space:]]*(cp|mv|install|tee|touch|truncate|mkdir|rm|ln|sqlite3)([[:space:]]|$)/ \
          || s ~ /(^|[^<])>>?/
      }
      function load_bearing_target(s) {
        return s ~ /(runs[.]jsonl|events[.]jsonl|children[.](jsonl|lock|lockdir)|repo[.]json|runs[.]lock|events[.]lock)/ \
          || s ~ /(op-[0-9]{8}T[0-9]{6}Z-[a-f0-9]{6}|[$]operation_id|[$][{]operation_id[}])[.]json/ \
          || s ~ /(^|[\/"'\''[:space:]])(tasks|reviews|decisions|operations|context-packs|archive)(\/|["'\''${}[:space:]])/ \
          || s ~ /\/VERSION(["'\''${}[:space:]]|$)/
      }
      function state_scope(s) {
        return s ~ /(PM_DISPATCH_STATE_ROOT|_sw_store_root|_sw_project_dir|\/projects\/)/ \
          || s ~ /[$][{](store_root|proj_dir|version_file|runs_file|events_file|task_file|review_file|decision_file|operation_file|operation_dir|op_dir|operation_children_file|context_pack[A-Za-z0-9_]*)([^A-Za-z0-9_]|$)/ \
          || s ~ /[$](store_root|proj_dir|version_file|runs_file|events_file|task_file|review_file|decision_file|operation_file|operation_dir|op_dir|operation_children_file|context_pack[A-Za-z0-9_]*)([^A-Za-z0-9_]|$)/
      }
      function inspect_line(raw, line_number, line, load_bearing, scoped) {
        line = raw
        if (line ~ /^[[:space:]]*#/) return
        # Diagnostic-only redirects are not filesystem mutations. Remove them
        # before looking for a real output redirect on the same logical line.
        gsub(/[0-9]*>[[:space:]]*\/dev\/null/, "", line)
        gsub(/[0-9]*>[&][0-9]+/, "", line)
        if (!direct_mutation(line)) return

        load_bearing = load_bearing_target(line)
        scoped = state_scope(line)
        if (!load_bearing && !scoped) return

        # Only sqlite3 may write a layout-declared rebuildable cache. A line
        # naming any load-bearing target remains a violation.
        if (!load_bearing && rebuildable_names != "" \
            && (line ~ /^[[:space:]]*(if[[:space:]]+!?[[:space:]]*)?sqlite3([[:space:]]|$)/ \
                || line ~ /[;&|][[:space:]]*sqlite3([[:space:]]|$)/) \
            && line ~ ("(" rebuildable_names ")")) return

        printf "%s:%d: direct state-store mutation: %s\n", relative, line_number, raw
      }
      {
        physical = $0
        if (logical == "") logical_start = FNR
        if (physical ~ /\\[[:space:]]*$/) {
          sub(/\\[[:space:]]*$/, "", physical)
          logical = logical physical " "
          next
        }
        logical = logical physical
        inspect_line(logical, logical_start)
        logical = ""
      }
      END {
        if (logical != "") inspect_line(logical, logical_start)
      }
    ' "$f"
  done < <(
    for production_path in install.sh uninstall.sh cli runtime hosts adapters ops tools scripts; do
      if [[ -f "$root/$production_path" ]]; then
        printf '%s\0' "$root/$production_path"
      elif [[ -d "$root/$production_path" ]]; then
        find "$root/$production_path" -type f \( -name '*.sh' -o -path "$root/cli/pmctl" \) -print0
      fi
    done
  )
}

ALL_CHECKS=(
  check_core_no_executables
  check_core_no_cli_named_paths
  check_core_only_declarative
  check_core_no_cli_field_keys
  check_adapters_no_shared_flow
  check_adapters_no_state_writes
  check_shared_lib_no_namerefs
  check_shared_lib_adapter_agnostic
  check_production_no_direct_state_writes
)

# ── Real-repo enforcement: every rule must be clean ───────────────────────────
for _chk in "${ALL_CHECKS[@]}"; do
  name="enforce/$_chk on real repo is clean"
  should_run "$name" || continue
  out="$("$_chk" "$REPO_ROOT")"
  if [[ -z "$out" ]]; then
    pass "$name"
  else
    fail "$name" "violations:"$'\n'"$out"
  fi
done

# ── Self-tests: plant a violation in a fixture; the rule MUST fire ────────────
_fixture() {
  FIX="$(mktemp -d)"
  mkdir -p "$FIX/core/policy" "$FIX/core/state" "$FIX/adapters/demo" \
    "$FIX/runtime/lib" "$FIX/hosts/demo/bin" "$FIX/ops/demo" "$FIX/tools/demo"
  cp "$REPO_ROOT/core/state/layout.yaml" "$FIX/core/state/layout.yaml"
}
# A rule MUST flag a planted violation (non-empty output).
_expect_fires() {
  local n="$1" out="$2"
  if [[ -n "$out" ]]; then pass "$n"; else fail "$n" "rule did not fire on a planted violation"; fi
}
# A rule must NOT flag a legal pattern (empty output) — guards against false positives.
_expect_clean() {
  local n="$1" out="$2"
  if [[ -z "$out" ]]; then pass "$n"; else fail "$n" "false positive:"$'\n'"$out"; fi
}

if should_run "selftest/core_no_executables fires on a .sh"; then
  name="selftest/core_no_executables fires on a .sh"
  _fixture; printf '#!/bin/sh\n' > "$FIX/core/policy/evil.sh"; chmod +x "$FIX/core/policy/evil.sh"
  _expect_fires "$name" "$(check_core_no_executables "$FIX")"
  rm -rf "$FIX"
fi

if should_run "selftest/core_no_cli_named_paths fires on a codex dir"; then
  name="selftest/core_no_cli_named_paths fires on a codex dir"
  _fixture; mkdir -p "$FIX/core/codex"
  _expect_fires "$name" "$(check_core_no_cli_named_paths "$FIX")"
  rm -rf "$FIX"
fi

if should_run "selftest/core_only_declarative fires on a .txt"; then
  name="selftest/core_only_declarative fires on a .txt"
  _fixture; printf 'x\n' > "$FIX/core/policy/data.txt"
  _expect_fires "$name" "$(check_core_only_declarative "$FIX")"
  rm -rf "$FIX"
fi

if should_run "selftest/core_no_cli_field_keys fires on a codex: key"; then
  name="selftest/core_no_cli_field_keys fires on a codex: key"
  _fixture; printf 'codex:\n  model: x\n' > "$FIX/core/policy/bad.yaml"
  _expect_fires "$name" "$(check_core_no_cli_field_keys "$FIX")"
  rm -rf "$FIX"
fi

if should_run "selftest/core_no_cli_field_keys does NOT fire on enum values"; then
  # Guards against false positives: codex/claude as list/array values are legal.
  name="selftest/core_no_cli_field_keys does NOT fire on enum values"
  _fixture; printf 'values:\n  - codex\n  - claude\n' > "$FIX/core/policy/enum.yaml"
  _expect_clean "$name" "$(check_core_no_cli_field_keys "$FIX")"
  rm -rf "$FIX"
fi

if should_run "selftest/adapters_no_shared_flow fires on a guard call"; then
  name="selftest/adapters_no_shared_flow fires on a guard call"
  _fixture
  printf '#!/usr/bin/env bash\npmctl_guard_check "$REPO" --event pre-write\n' > "$FIX/adapters/demo/dispatch.sh"
  _expect_fires "$name" "$(check_adapters_no_shared_flow "$FIX")"
  rm -rf "$FIX"
fi

if should_run "selftest/adapters_no_shared_flow ignores comments + allows usage logging"; then
  # The doc-header DESCRIBES the shared flow (comment) and the adapter logs usage
  # (allowed) — neither should trip the rule.
  name="selftest/adapters_no_shared_flow ignores comments + allows usage logging"
  _fixture
  {
    printf '#!/usr/bin/env bash\n'
    printf '# Driven by pmctl dispatch run; pmctl owns brief-validate / guard / route / post-verify.\n'
    printf 'bash "$HOME/.claude/scripts/log-usage.sh" claude_dispatch 100\n'
  } > "$FIX/adapters/demo/dispatch.sh"
  _expect_clean "$name" "$(check_adapters_no_shared_flow "$FIX")"
  rm -rf "$FIX"
fi

if should_run "selftest/adapters_no_state_writes fires on planted runs_append"; then
  name="selftest/adapters_no_state_writes fires on planted runs_append"
  _fixture
  printf '#!/usr/bin/env bash\nruns_append "$json"\n' > "$FIX/adapters/demo/dispatch.sh"
  _expect_fires "$name" "$(check_adapters_no_state_writes "$FIX")"
  rm -rf "$FIX"
fi

if should_run "selftest/adapters_no_state_writes does NOT fire on usage logging"; then
  name="selftest/adapters_no_state_writes does NOT fire on usage logging"
  _fixture
  printf '#!/usr/bin/env bash\nbash "$HOME/.claude/scripts/log-usage.sh" claude_dispatch 100\n' > "$FIX/adapters/demo/dispatch.sh"
  _expect_clean "$name" "$(check_adapters_no_state_writes "$FIX")"
  rm -rf "$FIX"
fi

if should_run "selftest/production_state_writer catches direct redirect"; then
  name="selftest/production_state_writer catches direct redirect"
  _fixture
  printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$json" >> "$proj_dir/events.jsonl"\n' \
    > "$FIX/hosts/demo/bin/direct-event.sh"
  _expect_fires "$name" "$(check_production_no_direct_state_writes "$FIX")"
  rm -rf "$FIX"
fi

if should_run "selftest/production_state_writer catches jq redirect"; then
  name="selftest/production_state_writer catches jq redirect"
  _fixture
  printf '#!/usr/bin/env bash\njq -c . "$src" > "$proj_dir/tasks/CC-1.json"\n' \
    > "$FIX/ops/demo/direct-task.sh"
  _expect_fires "$name" "$(check_production_no_direct_state_writes "$FIX")"
  rm -rf "$FIX"
fi

if should_run "selftest/production_state_writer catches mv destination"; then
  name="selftest/production_state_writer catches mv destination"
  _fixture
  printf '#!/usr/bin/env bash\nmv -f "$tmp" "$proj_dir/decisions/dec-2026-01-01-demo.json"\n' \
    > "$FIX/runtime/lib/direct-decision.sh"
  _expect_fires "$name" "$(check_production_no_direct_state_writes "$FIX")"
  rm -rf "$FIX"
fi

if should_run "selftest/production_state_writer catches operation projection variable"; then
  name="selftest/production_state_writer catches operation projection variable"
  _fixture
  printf '#!/usr/bin/env bash\nmv -f "$tmp" "$operation_file"\n' \
    > "$FIX/runtime/lib/direct-operation.sh"
  _expect_fires "$name" "$(check_production_no_direct_state_writes "$FIX")"
  rm -rf "$FIX"
fi

if should_run "selftest/production_state_writer catches operation child append"; then
  name="selftest/production_state_writer catches operation child append"
  _fixture
  printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$child" >> "$entity_root/operations/$operation_id/children.jsonl"\n' \
    > "$FIX/runtime/lib/direct-operation-child.sh"
  _expect_fires "$name" "$(check_production_no_direct_state_writes "$FIX")"
  rm -rf "$FIX"
fi

if should_run "selftest/production_state_writer catches split-line relative child append"; then
  name="selftest/production_state_writer catches split-line relative child append"
  _fixture
  printf '#!/usr/bin/env bash\ncd "$op_dir"\nprintf "%%s\\n" "$child" >> children.jsonl\n' \
    > "$FIX/runtime/lib/direct-relative-operation-child.sh"
  _expect_fires "$name" "$(check_production_no_direct_state_writes "$FIX")"
  rm -rf "$FIX"
fi

if should_run "selftest/production_state_writer catches relative operation projection"; then
  name="selftest/production_state_writer catches relative operation projection"
  _fixture
  printf '#!/usr/bin/env bash\nmv -f "$tmp" "operations/$operation_id.json"\n' \
    > "$FIX/runtime/lib/direct-relative-operation.sh"
  _expect_fires "$name" "$(check_production_no_direct_state_writes "$FIX")"
  rm -rf "$FIX"
fi

if should_run "selftest/production_state_writer catches split-line operation projection"; then
  name="selftest/production_state_writer catches split-line operation projection"
  _fixture
  printf '#!/usr/bin/env bash\ncd "$op_dir"\nmv -f "$tmp" "$operation_id.json"\n' \
    > "$FIX/runtime/lib/direct-split-operation.sh"
  _expect_fires "$name" "$(check_production_no_direct_state_writes "$FIX")"
  rm -rf "$FIX"
fi

if should_run "selftest/production_state_writer catches operation directory variable"; then
  name="selftest/production_state_writer catches operation directory variable"
  _fixture
  printf '#!/usr/bin/env bash\nmkdir -p "$op_dir"\n' \
    > "$FIX/runtime/lib/direct-operation-dir.sh"
  _expect_fires "$name" "$(check_production_no_direct_state_writes "$FIX")"
  rm -rf "$FIX"
fi

if should_run "selftest/production_state_writer does NOT match longer operation variable"; then
  name="selftest/production_state_writer does NOT match longer operation variable"
  _fixture
  printf '#!/usr/bin/env bash\nmkdir -p "$op_directory_cache"\n' \
    > "$FIX/runtime/lib/unrelated-operation-cache.sh"
  _expect_clean "$name" "$(check_production_no_direct_state_writes "$FIX")"
  rm -rf "$FIX"
fi

if should_run "selftest/production_state_writer catches multiline mv destination"; then
  name="selftest/production_state_writer catches multiline mv destination"
  _fixture
  printf '#!/usr/bin/env bash\nmv -f \\\n  "$tmp" \\\n  "$proj_dir/decisions/dec-2026-01-01-demo.json"\n' \
    > "$FIX/runtime/lib/direct-decision-multiline.sh"
  _expect_fires "$name" "$(check_production_no_direct_state_writes "$FIX")"
  rm -rf "$FIX"
fi

if should_run "selftest/production_state_writer catches cp into state root"; then
  name="selftest/production_state_writer catches cp into state root"
  _fixture
  printf '#!/usr/bin/env bash\ncp "$src" "$PM_DISPATCH_STATE_ROOT/projects/key/repo.json"\n' \
    > "$FIX/tools/demo/direct-copy.sh"
  _expect_fires "$name" "$(check_production_no_direct_state_writes "$FIX")"
  rm -rf "$FIX"
fi

if should_run "selftest/production_state_writer allows designated writer and resolver"; then
  name="selftest/production_state_writer allows designated writer and resolver"
  _fixture
  printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$json" >> "$proj_dir/events.jsonl"\n' \
    > "$FIX/runtime/lib/state-writer.sh"
  printf '#!/usr/bin/env bash\nprintf "%%s/projects/key/\\n" "$store_root"\n' \
    > "$FIX/runtime/lib/state-paths.sh"
  _expect_clean "$name" "$(check_production_no_direct_state_writes "$FIX")"
  rm -rf "$FIX"
fi

if should_run "selftest/production_state_writer allows rebuildable sqlite cache"; then
  name="selftest/production_state_writer allows rebuildable sqlite cache"
  _fixture
  printf '#!/usr/bin/env bash\nsqlite3 "$proj_dir/repo-index.db" "CREATE TABLE cache(k TEXT);"\n' \
    > "$FIX/runtime/lib/derived-cache.sh"
  _expect_clean "$name" "$(check_production_no_direct_state_writes "$FIX")"
  rm -rf "$FIX"
fi

if should_run "selftest/production_state_writer allows state readers"; then
  name="selftest/production_state_writer allows state readers"
  _fixture
  printf '#!/usr/bin/env bash\njq -c . "$operation_file"\n' \
    > "$FIX/runtime/lib/state-reader.sh"
  _expect_clean "$name" "$(check_production_no_direct_state_writes "$FIX")"
  rm -rf "$FIX"
fi

if should_run "selftest/shared_lib_no_namerefs fires on a declare -n in runtime/lib"; then
  name="selftest/shared_lib_no_namerefs fires on a declare -n in runtime/lib"
  _fixture
  printf '#!/usr/bin/env bash\nload_into() { local -n _ref="$1"; _ref=(a b); }\n' \
    > "$FIX/runtime/lib/nameref-lib.sh"
  _expect_fires "$name" "$(check_shared_lib_no_namerefs "$FIX")"
  rm -rf "$FIX"
fi

if should_run "selftest/shared_lib_no_namerefs fires on a nameref in the prompt hook"; then
  name="selftest/shared_lib_no_namerefs fires on a nameref in the prompt hook"
  _fixture
  mkdir -p "$FIX/runtime/hooks"
  printf '#!/usr/bin/env bash\ndeclare -n target="$1"\n' \
    > "$FIX/runtime/hooks/inject-demo.sh"
  _expect_fires "$name" "$(check_shared_lib_no_namerefs "$FIX")"
  rm -rf "$FIX"
fi

if should_run "selftest/shared_lib_no_namerefs fires on a split-option -r -n declaration"; then
  # `local -r -n ref` is a valid nameref decl with the -n as a separate option;
  # a first-cluster-only matcher would miss it and let a 4.3 dependency back in.
  name="selftest/shared_lib_no_namerefs fires on a split-option -r -n declaration"
  _fixture
  printf '#!/usr/bin/env bash\nbind() { local -r -n ref="$1"; }\n' \
    > "$FIX/runtime/lib/split-nameref.sh"
  _expect_fires "$name" "$(check_shared_lib_no_namerefs "$FIX")"
  rm -rf "$FIX"
fi

if should_run "selftest/shared_lib_no_namerefs does NOT fire on -A / -r / a comment"; then
  # Guards against false positives: assoc/readonly decls carry no `n`, and a
  # nameref mentioned only in a comment is not a declaration.
  name="selftest/shared_lib_no_namerefs does NOT fire on -A / -r / a comment"
  _fixture
  printf '#!/usr/bin/env bash\nload() { local -A map; local -r pinned=1; }\n# history: dropped a local -n ref here\n' \
    > "$FIX/runtime/lib/legal-decls.sh"
  _expect_clean "$name" "$(check_shared_lib_no_namerefs "$FIX")"
  rm -rf "$FIX"
fi

if should_run "selftest/shared_lib_no_namerefs also fires on the spelling inside a string"; then
  # Documents the accepted match surface: non-comment occurrence, same as the
  # adapter/state sibling rules. A shared lib printing `local -n` is still odd.
  name="selftest/shared_lib_no_namerefs also fires on the spelling inside a string"
  _fixture
  printf '#!/usr/bin/env bash\nprintf "avoid: local -n ref\\n"\n' \
    > "$FIX/runtime/lib/spelled-in-string.sh"
  _expect_fires "$name" "$(check_shared_lib_no_namerefs "$FIX")"
  rm -rf "$FIX"
fi

if should_run "selftest/shared_lib_adapter_agnostic fires on an adapter branch"; then
  name="selftest/shared_lib_adapter_agnostic fires on an adapter branch"
  _fixture
  printf '#!/usr/bin/env bash\ncase "$adapter" in codex) x=1 ;; esac\n' \
    > "$FIX/runtime/lib/dispatch-common.sh"
  _expect_fires "$name" "$(check_shared_lib_adapter_agnostic "$FIX")"
  rm -rf "$FIX"
fi

if should_run "selftest/shared_lib_adapter_agnostic fires on an adapter name in a string literal"; then
  # Contract: an adapter-agnostic lib names no adapter in its own body at all,
  # including in a message string — that is per-adapter knowledge the caller
  # should supply. This documents the accepted match surface.
  name="selftest/shared_lib_adapter_agnostic fires on an adapter name in a string literal"
  _fixture
  printf '#!/usr/bin/env bash\nprintf "dispatched via codex\\n"\n' \
    > "$FIX/runtime/lib/dispatch-common.sh"
  _expect_fires "$name" "$(check_shared_lib_adapter_agnostic "$FIX")"
  rm -rf "$FIX"
fi

if should_run "selftest/shared_lib_adapter_agnostic ignores an adapter name in a comment"; then
  name="selftest/shared_lib_adapter_agnostic ignores an adapter name in a comment"
  _fixture
  printf '#!/usr/bin/env bash\n# callers pass codex/claude/opencode/grok data in; this lib stays generic\nrun_with "$@"\n' \
    > "$FIX/runtime/lib/dispatch-common.sh"
  _expect_clean "$name" "$(check_shared_lib_adapter_agnostic "$FIX")"
  rm -rf "$FIX"
fi

th_summary
