#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C.UTF-8

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# QA category matrix for scripts/lib/pmctl-guard.sh + cli/pmctl guard dispatch.
# 1. Happy path: codex-prewrite-allow, pm-prewrite-allow, codex-prebash-allow (all driven through `cli/pmctl guard check`)
# 2. Boundary values: post-task-fail-closed (reserved event → exit 3), pm-prebash-fail-closed (no policy cell → exit 3), prewrite-empty-file-passthrough-deny
# 3. Negative inputs (usage errors, exit 2): unknown-profile, unknown-event, missing-event, missing-profile, unknown-flag, missing-event-value, prewrite-missing-file-flag, prebash-missing-command-flag, prewrite-rejects-command-flag, prebash-rejects-file-flag, hook-not-executable, missing-repo-root, jq-missing
# 4. Error paths (policy deny, exit 2): codex-prewrite-deny, pm-prewrite-deny, codex-prebash-deny-verb, codex-prebash-deny-metachar
# 5. State transitions: N/A - guard check is a stateless per-call decision; no persisted state machine in the SUT
# 6. Concurrency / race conditions: N/A - each invocation is an isolated subprocess synthesizing its own JSON; no shared mutable state
# 7. Side effects: prewrite-no-mutation - a pre-write check never creates the target file
# 8. Resource lifecycle: N/A - no persistent handles beyond process-scoped jq/hook subprocesses
# 9. Security: this IS the security surface - fail-closed cells (post-task-fail-closed, pm-prebash-fail-closed) assert no silent allow; deny cases (codex-prewrite-deny, pm-prewrite-deny, codex-prebash-deny-verb/metachar) assert the policy blocks; r2-equiv-* asserts the CLI is the same code path as the proven hooks
# 10. Performance / scale boundaries: N/A - no published performance contract for the guard surface; this suite is behavioral
# 11. Contract / interface compatibility: cli-unknown-sub - the cli/pmctl dispatch contract; the happy/deny cases above also exercise the real `cli/pmctl guard check` entry point
# 12. Backward compatibility / migration: r2-equiv-* - the CLI must produce identical allow/deny to the existing hooks (R2: equivalence-before-thinning)

# shellcheck source=scripts/lib/test-harness.sh
. "$SCRIPT_DIR/lib/test-harness.sh"
# shellcheck source=scripts/lib/pmctl-guard.sh
. "$SCRIPT_DIR/lib/pmctl-guard.sh"
th_init "$@"

PMCTL="$REPO_ROOT/cli/pmctl"
PMHOOK="$SCRIPT_DIR/hook-pm-write-guard.sh"
CXWHOOK="$SCRIPT_DIR/hook-codex-write-guard.sh"
CXBHOOK="$SCRIPT_DIR/hook-codex-bash-guard.sh"

# Sandbox audit logs + pin codex read roots so path-based cases are deterministic
# regardless of the host's $HOME (mirrors scripts/test-hooks.sh).
CLAUDE_HOOK_LOG_DIR="$(mktemp -d)"
export CLAUDE_HOOK_LOG_DIR
export CLAUDE_HOOK_CODEX_READ_ROOTS="$HOME/github:/tmp"
trap 'rm -rf "$CLAUDE_HOOK_LOG_DIR"' EXIT

MEM_PATH="$HOME/.claude/projects/test-guard-proj/memory/note.md"

# run_guard <args...> -> sets GUARD_EXIT and GUARD_OUT
run_guard() {
  set +e
  GUARD_OUT="$(bash "$PMCTL" guard check "$@" 2>&1)"
  GUARD_EXIT=$?
  set -e
}

# ---------------------------------------------------------------------------
# 1. Happy path
# ---------------------------------------------------------------------------

if should_run "codex-prewrite-allow"; then
  name="codex-prewrite-allow"
  run_guard --event pre-write --profile codex --file /tmp/brief-task.md
  assert_exit "$name" "$GUARD_EXIT" "0" && pass "$name"
fi

if should_run "pm-prewrite-allow"; then
  name="pm-prewrite-allow"
  run_guard --event pre-write --profile pm --file "$MEM_PATH"
  assert_exit "$name" "$GUARD_EXIT" "0" && pass "$name"
fi

if should_run "codex-prebash-allow"; then
  name="codex-prebash-allow"
  run_guard --event pre-bash --profile codex --command "git status"
  assert_exit "$name" "$GUARD_EXIT" "0" && pass "$name"
fi

if should_run "post-task-fail-closed"; then
  # post-task is reserved but unimplemented → fail closed (exit 3), never a
  # silent allow.
  name="post-task-fail-closed"
  run_guard --event post-task --profile codex
  if assert_exit "$name" "$GUARD_EXIT" "3" &&
    assert_string_contains "$name" "$GUARD_OUT" "post-task is reserved but not yet implemented"; then
    pass "$name"
  fi
fi

# ---------------------------------------------------------------------------
# 2. Boundary values
# ---------------------------------------------------------------------------

if should_run "pm-prebash-fail-closed"; then
  # pm/pre-bash has no policy (project-pm never runs Bash) → fail closed (exit 3).
  name="pm-prebash-fail-closed"
  run_guard --event pre-bash --profile pm --command "ls"
  if assert_exit "$name" "$GUARD_EXIT" "3" &&
    assert_string_contains "$name" "$GUARD_OUT" "no guard policy registered for profile=pm event=pre-bash"; then
    pass "$name"
  fi
fi

if should_run "prewrite-empty-file-passthrough-deny"; then
  # --file "" is passed THROUGH to the hook, which denies empty paths itself.
  name="prewrite-empty-file-passthrough-deny"
  run_guard --event pre-write --profile codex --file ""
  assert_exit "$name" "$GUARD_EXIT" "2" && pass "$name"
fi

# ---------------------------------------------------------------------------
# 3. Negative inputs — usage errors (exit 2 from the CLI layer)
# ---------------------------------------------------------------------------

if should_run "unknown-profile"; then
  name="unknown-profile"
  run_guard --event pre-write --profile bogus --file /tmp/brief-x.md
  if assert_exit "$name" "$GUARD_EXIT" "2" &&
    assert_string_contains "$name" "$GUARD_OUT" "unknown profile"; then
    pass "$name"
  fi
fi

if should_run "unknown-event"; then
  name="unknown-event"
  run_guard --event pre-frobnicate --profile codex --file /tmp/brief-x.md
  if assert_exit "$name" "$GUARD_EXIT" "2" &&
    assert_string_contains "$name" "$GUARD_OUT" "unknown event"; then
    pass "$name"
  fi
fi

if should_run "missing-event"; then
  name="missing-event"
  run_guard --profile codex --file /tmp/brief-x.md
  if assert_exit "$name" "$GUARD_EXIT" "2" &&
    assert_string_contains "$name" "$GUARD_OUT" "missing --event"; then
    pass "$name"
  fi
fi

if should_run "missing-profile"; then
  name="missing-profile"
  run_guard --event pre-write --file /tmp/brief-x.md
  if assert_exit "$name" "$GUARD_EXIT" "2" &&
    assert_string_contains "$name" "$GUARD_OUT" "missing --profile"; then
    pass "$name"
  fi
fi

if should_run "unknown-flag"; then
  name="unknown-flag"
  run_guard --event pre-write --profile codex --bogus x
  if assert_exit "$name" "$GUARD_EXIT" "2" &&
    assert_string_contains "$name" "$GUARD_OUT" "unknown flag"; then
    pass "$name"
  fi
fi

if should_run "missing-event-value"; then
  name="missing-event-value"
  run_guard --event
  if assert_exit "$name" "$GUARD_EXIT" "2" &&
    assert_string_contains "$name" "$GUARD_OUT" "missing value for --event"; then
    pass "$name"
  fi
fi

if should_run "prewrite-missing-file-flag"; then
  name="prewrite-missing-file-flag"
  run_guard --event pre-write --profile codex
  if assert_exit "$name" "$GUARD_EXIT" "2" &&
    assert_string_contains "$name" "$GUARD_OUT" "--file required for event pre-write"; then
    pass "$name"
  fi
fi

if should_run "prebash-missing-command-flag"; then
  name="prebash-missing-command-flag"
  run_guard --event pre-bash --profile codex
  if assert_exit "$name" "$GUARD_EXIT" "2" &&
    assert_string_contains "$name" "$GUARD_OUT" "--command required for event pre-bash"; then
    pass "$name"
  fi
fi

if should_run "missing-repo-root"; then
  # Called via the sourced function directly: the CLI always passes REPO_ROOT,
  # so this precondition is only reachable at the library boundary.
  name="missing-repo-root"
  set +e
  out="$(pmctl_guard_check "" --event pre-write --profile codex --file /tmp/brief-x.md 2>&1)"
  st=$?
  set -e
  if assert_exit "$name" "$st" "2" &&
    assert_string_contains "$name" "$out" "missing repo root"; then
    pass "$name"
  fi
fi

if should_run "prewrite-rejects-command-flag"; then
  name="prewrite-rejects-command-flag"
  run_guard --event pre-write --profile codex --file /tmp/brief-x.md --command "ls"
  if assert_exit "$name" "$GUARD_EXIT" "2" &&
    assert_string_contains "$name" "$GUARD_OUT" "--command is not valid for event pre-write"; then
    pass "$name"
  fi
fi

if should_run "prebash-rejects-file-flag"; then
  name="prebash-rejects-file-flag"
  run_guard --event pre-bash --profile codex --command "git status" --file /tmp/x
  if assert_exit "$name" "$GUARD_EXIT" "2" &&
    assert_string_contains "$name" "$GUARD_OUT" "--file is not valid for event pre-bash"; then
    pass "$name"
  fi
fi

if should_run "hook-not-executable"; then
  # Point the function at a fake repo root whose guard hook is non-executable so
  # the fail-closed "hook not executable" usage-error branch (exit 2) is exercised.
  name="hook-not-executable"
  fake_root="$CLAUDE_HOOK_LOG_DIR/fake-root"
  mkdir -p "$fake_root/scripts"
  : > "$fake_root/scripts/hook-codex-write-guard.sh"
  chmod -x "$fake_root/scripts/hook-codex-write-guard.sh"
  set +e
  out="$(pmctl_guard_check "$fake_root" --event pre-write --profile codex --file /tmp/brief-x.md 2>&1)"
  st=$?
  set -e
  if assert_exit "$name" "$st" "2" &&
    assert_string_contains "$name" "$out" "guard hook not executable"; then
    pass "$name"
  fi
fi

if should_run "jq-missing"; then
  # Drive the sourced function with an emptied PATH so `command -v jq` fails.
  # The jq dependency is checked before any external binary is invoked (hook
  # resolution and -x test are bash builtins), so the branch is reachable.
  name="jq-missing"
  set +e
  out="$(PATH="" pmctl_guard_check "$REPO_ROOT" --event pre-write --profile codex --file /tmp/brief-x.md 2>&1)"
  st=$?
  set -e
  if assert_exit "$name" "$st" "2" &&
    assert_string_contains "$name" "$out" "jq missing on PATH"; then
    pass "$name"
  fi
fi

# ---------------------------------------------------------------------------
# 4. Error paths — policy deny (exit 2 from the underlying hook)
# ---------------------------------------------------------------------------

if should_run "codex-prewrite-deny"; then
  name="codex-prewrite-deny"
  run_guard --event pre-write --profile codex --file /etc/passwd
  if assert_exit "$name" "$GUARD_EXIT" "2" &&
    assert_string_contains "$name" "$GUARD_OUT" "hook-codex-write-guard"; then
    pass "$name"
  fi
fi

if should_run "pm-prewrite-deny"; then
  name="pm-prewrite-deny"
  run_guard --event pre-write --profile pm --file /tmp/oops.md
  if assert_exit "$name" "$GUARD_EXIT" "2" &&
    assert_string_contains "$name" "$GUARD_OUT" "hook-pm-write-guard"; then
    pass "$name"
  fi
fi

if should_run "codex-prebash-deny-verb"; then
  name="codex-prebash-deny-verb"
  run_guard --event pre-bash --profile codex --command "rm -rf /tmp/x"
  if assert_exit "$name" "$GUARD_EXIT" "2" &&
    assert_string_contains "$name" "$GUARD_OUT" "hook-codex-bash-guard"; then
    pass "$name"
  fi
fi

if should_run "codex-prebash-deny-metachar"; then
  name="codex-prebash-deny-metachar"
  run_guard --event pre-bash --profile codex --command "git status; rm -rf /"
  assert_exit "$name" "$GUARD_EXIT" "2" && pass "$name"
fi

# ---------------------------------------------------------------------------
# 7. Side effects — a pre-write check never creates the target file
# ---------------------------------------------------------------------------

if should_run "prewrite-no-mutation"; then
  name="prewrite-no-mutation"
  target="$CLAUDE_HOOK_LOG_DIR/should-not-exist-brief-x.md"
  run_guard --event pre-write --profile codex --file "$target"
  if [[ ! -e "$target" ]]; then
    pass "$name"
  else
    fail "$name" "guard check created the target file: $target"
  fi
fi

# ---------------------------------------------------------------------------
# 11. Contract / interface — cli/pmctl dispatch
# ---------------------------------------------------------------------------

if should_run "cli-unknown-sub"; then
  name="cli-unknown-sub"
  set +e
  out="$(bash "$PMCTL" guard bogus 2>&1)"
  st=$?
  set -e
  if assert_exit "$name" "$st" "2" &&
    assert_string_contains "$name" "$out" "unknown command"; then
    pass "$name"
  fi
fi

# ---------------------------------------------------------------------------
# 12. R2 equivalence — the CLI must produce identical allow/deny to the proven
#     hooks. For each scenario, drive the hook DIRECTLY (the path test-hooks.sh
#     exercises) and via pmctl, then assert identical exit codes.
# ---------------------------------------------------------------------------

# r2_equiv <name> <hook_path> <hook_json> <pmctl args...>
r2_equiv() {
  local name="$1" hook="$2" json="$3"; shift 3
  should_run "$name" || return 0
  local direct_exit cli_exit
  set +e
  printf '%s' "$json" | "$hook" >/dev/null 2>&1
  direct_exit=$?
  bash "$PMCTL" guard check "$@" >/dev/null 2>&1
  cli_exit=$?
  set -e
  if [[ "$direct_exit" == "$cli_exit" ]]; then
    pass "$name"
  else
    fail "$name" "$(printf '        direct hook exit=%s, pmctl exit=%s (must match)' "$direct_exit" "$cli_exit")"
  fi
}

r2_equiv "r2-equiv-codex-write-allow" "$CXWHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Write","tool_input":{"file_path":"/tmp/brief-eq.md"}}' \
  --event pre-write --profile codex --file /tmp/brief-eq.md

r2_equiv "r2-equiv-codex-write-deny" "$CXWHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Write","tool_input":{"file_path":"/etc/passwd"}}' \
  --event pre-write --profile codex --file /etc/passwd

r2_equiv "r2-equiv-pm-write-allow" "$PMHOOK" \
  "{\"agent_type\":\"project-pm\",\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$MEM_PATH\"}}" \
  --event pre-write --profile pm --file "$MEM_PATH"

r2_equiv "r2-equiv-pm-write-deny" "$PMHOOK" \
  '{"agent_type":"project-pm","tool_name":"Write","tool_input":{"file_path":"/tmp/oops.md"}}' \
  --event pre-write --profile pm --file /tmp/oops.md

r2_equiv "r2-equiv-codex-bash-allow" "$CXBHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"git status"}}' \
  --event pre-bash --profile codex --command "git status"

r2_equiv "r2-equiv-codex-bash-deny" "$CXBHOOK" \
  '{"agent_type":"codex-executor","tool_name":"Bash","tool_input":{"command":"rm -rf /tmp/x"}}' \
  --event pre-bash --profile codex --command "rm -rf /tmp/x"

th_summary
