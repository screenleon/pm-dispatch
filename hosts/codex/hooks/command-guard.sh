#!/usr/bin/env bash
# codex PreToolUse Bash hook — wired into $CODEX_HOME/hooks.json by
# hosts/codex/bin/install.sh, driven by hosts/codex/host.yaml's
# command_guard guard_bindings entry (binding_form: hook-script,
# provider: host_hook).
#
# Reads the canonical PreToolUse stdin JSON codex fires for a Bash tool call
# (tool_input.command, cwd — hosts/codex/host.yaml payload_fields) and defers
# to `pmctl guard check`, the same executor-agnostic guard front-end a
# non-Claude host must call explicitly (runtime/lib/pmctl-guard.sh). This
# script does not implement its own allow/deny policy — the policy is
# whatever `pmctl guard check --role pm --runtime codex --event pre-bash`
# resolves to: runtime/hooks/guard-pm-bash.sh, a curated denylist of destructive /
# hard-to-reverse commands (rm -rf, force push, git reset --hard, sudo, ...),
# allowing everything else. See that script's header for the full list and
# rationale.
#
# Exit-code contract (same as every other guard-*.sh in this repo): 0 = ALLOW
# (no stdout needed), non-zero = DENY (codex blocks the tool call and reports
# it as blocked by a PreToolUse hook).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd -P)"

if ! command -v jq >/dev/null 2>&1; then
  echo "hook-codex-command-guard: jq not found on PATH — denying (fail-closed)" >&2
  exit 2
fi

payload="$(cat)"
command_str="$(printf '%s' "$payload" | jq -r '.tool_input.command // empty' 2>/dev/null || true)"

if [[ -z "$command_str" ]]; then
  echo "hook-codex-command-guard: no tool_input.command in payload — denying (fail-closed)" >&2
  exit 2
fi

# Codex evaluates PreToolUse hooks before Bash interprets command-local
# assignments. Promote the documented, exact leading assignment into this
# hook invocation so `PM_GUARD_PM_BASH=off command...` is a genuine one-call
# bypass. Keep the match anchored and case-sensitive: an assignment later in
# the command, or any value other than lowercase `off`, must not bypass.
if [[ "$command_str" =~ ^[[:space:]]*PM_GUARD_PM_BASH=off([[:space:]]|$) ]]; then
  export PM_GUARD_PM_BASH=off
fi

exec "$REPO_ROOT/cli/pmctl" guard check \
  --event pre-bash --role pm --runtime codex --command "$command_str"
