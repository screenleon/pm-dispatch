#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C.UTF-8

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ORIGINAL_PATH="$PATH"

# shellcheck source=scripts/lib/test-harness.sh
. "$SCRIPT_DIR/lib/test-harness.sh"
th_init "test-executor-router" "$@"

# shellcheck source=scripts/lib/executor-router.sh
. "$SCRIPT_DIR/lib/executor-router.sh"

ORIGINAL_ROUTER_SCRIPT_DIR="$EXECUTOR_ROUTER_SCRIPT_DIR"

# Build an isolated repo-shaped tree so router functions read FIXTURE manifests
# (<root>/adapters/<name>/adapter.yaml) instead of the real adapters/. Sets the
# global FIXTURE_ROOT and points EXECUTOR_ROUTER_SCRIPT_DIR at <root>/scripts
# (functions strip the trailing /scripts to reach <root>/adapters). Must be called
# as a statement (not in $(...)) so the global assignments propagate. Caller must
# restore EXECUTOR_ROUTER_SCRIPT_DIR afterward.
with_fixture_root() {
  FIXTURE_ROOT="$tmp_root/$1"
  mkdir -p "$FIXTURE_ROOT/scripts" "$FIXTURE_ROOT/adapters"
  EXECUTOR_ROUTER_SCRIPT_DIR="$FIXTURE_ROOT/scripts"
}

# write_fixture_adapter <root> <name> <runner_kind> [extra_yaml_line]
write_fixture_adapter() {
  local root="$1" name="$2" runner_kind="$3" extra="${4-}"
  mkdir -p "$root/adapters/$name"
  {
    printf 'schema_version: 1\n'
    printf 'adapter_name: %s\n' "$name"
    printf 'runner_kind: %s\n' "$runner_kind"
    if [[ -n "$extra" ]]; then printf '%s\n' "$extra"; fi
  } > "$root/adapters/$name/adapter.yaml"
}

with_fake_codex_path() {
  local bin="$tmp_root/fake-codex-bin"
  mkdir -p "$bin"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$bin/codex"
  chmod +x "$bin/codex"
  PATH="$bin:$ORIGINAL_PATH"
}

with_no_codex_path() {
  local bin="$tmp_root/no-codex-bin"
  mkdir -p "$bin"
  ln -s "$(command -v bash)" "$bin/bash"
  ln -s "$(command -v dirname)" "$bin/dirname"
  PATH="$bin"
}

if should_run "resolve_executor: auto detects codex on PATH"; then
  with_fake_codex_path
  result="$(resolve_executor auto)"
  PATH="$ORIGINAL_PATH"
  [[ "$result" == "codex" ]] && pass "resolve_executor: auto detects codex on PATH" || fail "resolve_executor: auto detects codex on PATH" "expected codex, got: $result"
fi

if should_run "resolve_executor: explicit codex override"; then
  result="$(resolve_executor codex)"
  [[ "$result" == "codex" ]] && pass "resolve_executor: explicit codex override" || fail "resolve_executor: explicit codex override" "expected codex, got: $result"
fi

if should_run "resolve_executor: explicit claude override"; then
  result="$(resolve_executor claude)"
  [[ "$result" == "claude" ]] && pass "resolve_executor: explicit claude override" || fail "resolve_executor: explicit claude override" "expected claude, got: $result"
fi

if should_run "resolve_executor: rejects unknown executor"; then
  if ! resolve_executor gemini >/dev/null 2>&1; then
    pass "resolve_executor: rejects unknown executor"
  else
    fail "resolve_executor: rejects unknown executor" "unknown executor should fail"
  fi
fi

if should_run "detect_executor_auto: falls back to claude without codex"; then
  with_no_codex_path
  result="$(detect_executor_auto)"
  PATH="$ORIGINAL_PATH"
  [[ "$result" == "claude" ]] && pass "detect_executor_auto: falls back to claude without codex" || fail "detect_executor_auto: falls back to claude without codex" "expected claude, got: $result"
fi

if should_run "dispatch_route_for: codex and claude routes"; then
  # Integration check: reads the REAL adapters/{codex,claude}/adapter.yaml manifests
  # (routing is data-driven since CC-373), so it asserts the shipped manifests resolve
  # to the expected routes — not a pure unit test of the case logic.
  codex_route="$(dispatch_route_for codex)"
  claude_route="$(dispatch_route_for claude)"
  if [[ "$codex_route" == "main_thread_bash_background" && "$claude_route" == "agent_executor" ]]; then
    pass "dispatch_route_for: codex and claude routes"
  else
    fail "dispatch_route_for: codex and claude routes" "codex=$codex_route claude=$claude_route"
  fi
fi

if should_run "dispatch_via_codex: safe argv passthrough"; then
  work_dir="$tmp_root/work dir"
  brief_file="$tmp_root/brief file.md"
  mkdir -p "$work_dir"
  : > "$brief_file"
  cmd="$(dispatch_via_codex "$brief_file" "$work_dir" default workspace-write never 1200)"
  eval "set -- $cmd"
  if [[ "$1" == "bash" &&
        "$2" == "$REPO_ROOT/adapters/codex/dispatch.sh" &&
        "$3" == "--cd" &&
        "$4" == "$work_dir" &&
        "${11}" == "--brief-file" &&
        "${12}" == "$brief_file" ]]; then
    pass "dispatch_via_codex: safe argv passthrough"
  else
    fail "dispatch_via_codex: safe argv passthrough" "argv did not round-trip: $cmd"
  fi
fi

if should_run "dispatch_via_codex: non-default model"; then
  result="$(dispatch_via_codex "/tmp/brief.md" "/repo" "gpt-5.5" "workspace-write" "never" "1200")"
  printf '%s\n' "$result" | grep -q -- '--model gpt-5.5' && pass "dispatch_via_codex: non-default model" || fail "dispatch_via_codex: non-default model" "expected --model gpt-5.5 in: $result"
fi

if should_run "dispatch_via_codex: isolation passthrough"; then
  result="$(dispatch_via_codex "/tmp/brief.md" "/repo" "default" "workspace-write" "never" "1200" "workspace-network")"
  printf '%s\n' "$result" | grep -q -- '--isolation workspace-network' && pass "dispatch_via_codex: isolation passthrough" || fail "dispatch_via_codex: isolation passthrough" "expected --isolation workspace-network in: $result"
fi

# --- CC-373: data-driven routing from on-disk manifests ---------------------

# Acceptance proof for the executor abstraction: a brand-new adapter becomes
# routable by DROPPING adapters/<name>/adapter.yaml — no edit to executor-router.sh.
if should_run "dispatch_route_for: new fixture adapter routable with zero core edit"; then
  with_fixture_root route-fixture
  write_fixture_adapter "$FIXTURE_ROOT" opencode cli-subprocess
  route="$(dispatch_route_for opencode)"
  rc=$?
  EXECUTOR_ROUTER_SCRIPT_DIR="$ORIGINAL_ROUTER_SCRIPT_DIR"
  if [[ "$rc" -eq 0 && "$route" == "main_thread_bash_background" ]]; then
    pass "dispatch_route_for: new fixture adapter routable with zero core edit"
  else
    fail "dispatch_route_for: new fixture adapter routable with zero core edit" "rc=$rc route=$route"
  fi
fi

if should_run "dispatch_route_for: host-native fixture derives agent_executor"; then
  with_fixture_root host-native-fixture
  write_fixture_adapter "$FIXTURE_ROOT" hostlike host-native
  route="$(dispatch_route_for hostlike)"
  EXECUTOR_ROUTER_SCRIPT_DIR="$ORIGINAL_ROUTER_SCRIPT_DIR"
  [[ "$route" == "agent_executor" ]] && pass "dispatch_route_for: host-native fixture derives agent_executor" || fail "dispatch_route_for: host-native fixture derives agent_executor" "route=$route"
fi

if should_run "dispatch_route_for: manifest dispatch_route override honored"; then
  with_fixture_root override-fixture
  write_fixture_adapter "$FIXTURE_ROOT" overridden cli-subprocess "dispatch_route: agent_executor"
  route="$(dispatch_route_for overridden)"
  EXECUTOR_ROUTER_SCRIPT_DIR="$ORIGINAL_ROUTER_SCRIPT_DIR"
  [[ "$route" == "agent_executor" ]] && pass "dispatch_route_for: manifest dispatch_route override honored" || fail "dispatch_route_for: manifest dispatch_route override honored" "route=$route"
fi

if should_run "dispatch_route_for: missing manifest is not routable (fail-closed)"; then
  with_fixture_root missing-fixture
  rc=0
  dispatch_route_for ghost >/dev/null 2>&1 || rc=$?
  EXECUTOR_ROUTER_SCRIPT_DIR="$ORIGINAL_ROUTER_SCRIPT_DIR"
  [[ "$rc" -ne 0 ]] && pass "dispatch_route_for: missing manifest is not routable (fail-closed)" || fail "dispatch_route_for: missing manifest is not routable (fail-closed)" "expected non-zero"
fi

if should_run "dispatch_route_for: invalid runner_kind is rejected (fail-closed)"; then
  with_fixture_root invalid-rk-fixture
  write_fixture_adapter "$FIXTURE_ROOT" bogus not-a-kind
  rc=0
  dispatch_route_for bogus >/dev/null 2>&1 || rc=$?
  EXECUTOR_ROUTER_SCRIPT_DIR="$ORIGINAL_ROUTER_SCRIPT_DIR"
  [[ "$rc" -ne 0 ]] && pass "dispatch_route_for: invalid runner_kind is rejected (fail-closed)" || fail "dispatch_route_for: invalid runner_kind is rejected (fail-closed)" "expected non-zero"
fi

if should_run "dispatch_route_for: rejects path-traversal name"; then
  rc1=0; rc2=0
  dispatch_route_for '../codex' >/dev/null 2>&1 || rc1=$?
  dispatch_route_for 'a/b' >/dev/null 2>&1 || rc2=$?
  if [[ "$rc1" -ne 0 && "$rc2" -ne 0 ]]; then
    pass "dispatch_route_for: rejects path-traversal name"
  else
    fail "dispatch_route_for: rejects path-traversal name" "rc1=$rc1 rc2=$rc2"
  fi
fi

if should_run "dispatch_route_for: rejects symlinked manifest (trust-boundary escape)"; then
  with_fixture_root symlink-fixture
  mkdir -p "$FIXTURE_ROOT/adapters/symlinked"
  # A valid manifest body living elsewhere, reachable only via a symlinked
  # adapter.yaml — the guard must refuse it regardless of content validity.
  printf 'schema_version: 1\nadapter_name: symlinked\nrunner_kind: cli-subprocess\n' > "$FIXTURE_ROOT/elsewhere.yaml"
  ln -s "$FIXTURE_ROOT/elsewhere.yaml" "$FIXTURE_ROOT/adapters/symlinked/adapter.yaml"
  rc=0
  dispatch_route_for symlinked >/dev/null 2>&1 || rc=$?
  EXECUTOR_ROUTER_SCRIPT_DIR="$ORIGINAL_ROUTER_SCRIPT_DIR"
  [[ "$rc" -ne 0 ]] && pass "dispatch_route_for: rejects symlinked manifest (trust-boundary escape)" || fail "dispatch_route_for: rejects symlinked manifest (trust-boundary escape)" "expected non-zero (symlinked manifest must be refused)"
fi

if should_run "dispatch_route_for: rejects malformed names (strict-identifier)"; then
  failed=""
  for bad in Abc 1abc -abc ""; do
    rc=0
    dispatch_route_for "$bad" >/dev/null 2>&1 || rc=$?
    [[ "$rc" -ne 0 ]] || failed="$failed [${bad:-<empty>}]"
  done
  [[ -z "$failed" ]] && pass "dispatch_route_for: rejects malformed names (strict-identifier)" || fail "dispatch_route_for: rejects malformed names (strict-identifier)" "these were not rejected:$failed"
fi

if should_run "resolve_executor: accepts newly registered fixture adapter"; then
  with_fixture_root resolve-fixture
  write_fixture_adapter "$FIXTURE_ROOT" opencode cli-subprocess
  result="$(resolve_executor opencode)"
  rc=$?
  EXECUTOR_ROUTER_SCRIPT_DIR="$ORIGINAL_ROUTER_SCRIPT_DIR"
  [[ "$rc" -eq 0 && "$result" == "opencode" ]] && pass "resolve_executor: accepts newly registered fixture adapter" || fail "resolve_executor: accepts newly registered fixture adapter" "rc=$rc result=$result"
fi

if should_run "dispatch_via: generic resolves adapter dispatch.sh and forwards sandbox for cli-subprocess"; then
  with_fixture_root via-cli-fixture
  write_fixture_adapter "$FIXTURE_ROOT" opencode cli-subprocess
  result="$(dispatch_via opencode "/tmp/brief.md" "/repo" default workspace-write never 1200)"
  EXECUTOR_ROUTER_SCRIPT_DIR="$ORIGINAL_ROUTER_SCRIPT_DIR"
  if printf '%s\n' "$result" | grep -q -- 'adapters/opencode/dispatch.sh' && printf '%s\n' "$result" | grep -q -- '--sandbox workspace-write --approval never'; then
    pass "dispatch_via: generic resolves adapter dispatch.sh and forwards sandbox for cli-subprocess"
  else
    fail "dispatch_via: generic resolves adapter dispatch.sh and forwards sandbox for cli-subprocess" "$result"
  fi
fi

if should_run "dispatch_via: host-native fixture drops sandbox/approval"; then
  with_fixture_root via-host-fixture
  write_fixture_adapter "$FIXTURE_ROOT" hostlike host-native
  result="$(dispatch_via hostlike "/tmp/brief.md" "/repo" default workspace-write never 1200)"
  EXECUTOR_ROUTER_SCRIPT_DIR="$ORIGINAL_ROUTER_SCRIPT_DIR"
  if printf '%s\n' "$result" | grep -q -- 'adapters/hostlike/dispatch.sh' && ! printf '%s\n' "$result" | grep -q -- '--sandbox'; then
    pass "dispatch_via: host-native fixture drops sandbox/approval"
  else
    fail "dispatch_via: host-native fixture drops sandbox/approval" "$result"
  fi
fi

if should_run "dispatch_via: rejects unroutable executor"; then
  rc=0
  dispatch_via ghost "/tmp/brief.md" "/repo" default workspace-write never 1200 >/dev/null 2>&1 || rc=$?
  [[ "$rc" -ne 0 ]] && pass "dispatch_via: rejects unroutable executor" || fail "dispatch_via: rejects unroutable executor" "expected non-zero"
fi

th_summary
