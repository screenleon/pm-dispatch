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
#     files/dirs, only .yaml/.json/.md, no CLI product name as a field-name KEY.
#     (CLI names MAY appear as enum VALUES / schema descriptions / prose — those
#      are data, not structure; the rules check structure, ignore prose.)
#   - `adapters/**/*.sh` must NOT call the shared FLOW (brief-validate, guard,
#     route, post-verify, or pmctl itself) in non-comment lines. Executor-specific
#     invocation + output-contract glue + best-effort state/usage logging are
#     ALLOWED (they parse executor-native formats and cannot live in pmctl).
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

# C3: core/ holds only declarative file types (.yaml/.yml/.json/.md).
check_core_only_declarative() {
  local root="$1"
  [[ -d "$root/core" ]] || return 0
  find "$root/core" -type f \
    ! \( -name '*.yaml' -o -name '*.yml' -o -name '*.json' -o -name '*.md' \) 2>/dev/null
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

ALL_CHECKS=(
  check_core_no_executables
  check_core_no_cli_named_paths
  check_core_only_declarative
  check_core_no_cli_field_keys
  check_adapters_no_shared_flow
  check_adapters_no_state_writes
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
_fixture() { FIX="$(mktemp -d)"; mkdir -p "$FIX/core/policy" "$FIX/adapters/demo"; }
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

th_summary
