#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C.UTF-8

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ORIGINAL_PATH="$PATH"

# shellcheck source=tests/lib/test-harness.sh
. "$SCRIPT_DIR/../lib/test-harness.sh"
th_init "test-executor-router" "$@"

# shellcheck source=runtime/lib/executor-router.sh
. "$REPO_ROOT/runtime/lib/executor-router.sh"
# shellcheck source=runtime/lib/allowlist.sh
. "$REPO_ROOT/runtime/lib/allowlist.sh"

ORIGINAL_ROUTER_REPO_ROOT="$EXECUTOR_ROUTER_REPO_ROOT"

# Build an isolated repo-shaped tree so router functions read FIXTURE manifests
# (<root>/adapters/<name>/adapter.yaml) instead of the real adapters/. Sets the
# global FIXTURE_ROOT and points EXECUTOR_ROUTER_REPO_ROOT at <root>
# Must be called
# as a statement (not in $(...)) so the global assignments propagate. Caller must
# restore EXECUTOR_ROUTER_REPO_ROOT afterward.
with_fixture_root() {
  FIXTURE_ROOT="$tmp_root/$1"
  mkdir -p "$FIXTURE_ROOT" "$FIXTURE_ROOT/adapters"
  EXECUTOR_ROUTER_REPO_ROOT="$FIXTURE_ROOT"
}

# write_fixture_adapter <root> <name> <runner_kind> [extra_yaml_line]
write_fixture_adapter() {
  local root="$1" name="$2" runner_kind="$3" extra="${4-}"
  mkdir -p "$root/adapters/$name"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$root/adapters/$name/dispatch.sh"
  chmod +x "$root/adapters/$name/dispatch.sh"
  {
    printf 'schema_version: 1\n'
    printf 'adapter_name: %s\n' "$name"
    printf 'runner_kind: %s\n' "$runner_kind"
    printf 'dispatch_entrypoint: ./dispatch.sh\n'
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

# Behavior: Explicit-root executor resolution uses that Adapter registry without
# changing the router's default repository root.
# Steps:
#   1. Arrange an explicit root with a routable opencode Adapter and restore the default root.
#   2. Act by resolving opencode through resolve_executor_at with the explicit root.
#   3. Assert opencode is returned and the default repository root is unchanged.
if should_run "resolve_executor_at: uses explicit Adapter root without global mutation"; then
  with_fixture_root explicit-resolve-fixture
  write_fixture_adapter "$FIXTURE_ROOT" opencode cli-subprocess
  explicit_root="$FIXTURE_ROOT"
  EXECUTOR_ROUTER_REPO_ROOT="$ORIGINAL_ROUTER_REPO_ROOT"
  result="$(resolve_executor_at "$explicit_root" opencode)"
  if [[ "$result" == opencode \
      && "$EXECUTOR_ROUTER_REPO_ROOT" == "$ORIGINAL_ROUTER_REPO_ROOT" ]]; then
    pass "resolve_executor_at: uses explicit Adapter root without global mutation"
  else
    fail "resolve_executor_at: uses explicit Adapter root without global mutation" \
      "result=$result default_root=$EXECUTOR_ROUTER_REPO_ROOT"
  fi
fi

# Behavior: Auto resolution rejects a PATH-detected executor that is absent from
# the explicit Adapter registry.
# Steps:
#   1. Arrange an explicit root containing only claude and a PATH that exposes fake codex.
#   2. Act by auto-resolving an executor against the explicit root.
#   3. Assert resolution fails closed with exit 2 instead of accepting PATH codex.
if should_run "resolve_executor_at: auto candidate must be routable in explicit root"; then
  with_fixture_root explicit-auto-fixture
  write_fixture_adapter "$FIXTURE_ROOT" claude cli-subprocess
  explicit_root="$FIXTURE_ROOT"
  EXECUTOR_ROUTER_REPO_ROOT="$ORIGINAL_ROUTER_REPO_ROOT"
  with_fake_codex_path
  rc=0
  resolve_executor_at "$explicit_root" auto >/dev/null 2>&1 || rc=$?
  PATH="$ORIGINAL_PATH"
  if [[ "$rc" -eq 2 ]]; then
    pass "resolve_executor_at: auto candidate must be routable in explicit root"
  else
    fail "resolve_executor_at: auto candidate must be routable in explicit root" \
      "auto accepted PATH codex without a codex manifest (rc=$rc)"
  fi
fi

# Behavior: Sourcing the router fails closed when adapter-manifest.sh is absent,
# even when inherited shell functions have the expected manifest-helper names.
# Steps:
#   1. Arrange an isolated router library tree without adapter-manifest.sh and export poisoned helpers.
#   2. Act by sourcing the isolated router and attempting explicit-root codex resolution.
#   3. Assert exit 2 and an error naming the missing adapter-manifest.sh dependency.
if should_run "router source: inherited manifest functions cannot replace missing library"; then
  poison_root="$tmp_root/router-poison-fixture"
  mkdir -p "$poison_root/lib"
  cp "$REPO_ROOT/runtime/lib/executor-router.sh" \
    "$REPO_ROOT/runtime/lib/identifier-policy.sh" \
    "$REPO_ROOT/runtime/lib/runner-kind.sh" "$poison_root/lib/"
  rc=0
  result="$(bash -c '
    adapter_manifest_dispatch_path() { printf "/bin/true\\n"; }
    adapter_manifest_runner_kind() { printf "cli-subprocess\\n"; }
    adapter_manifest_effective_route() { printf "main_thread_bash_background\\n"; }
    export -f adapter_manifest_dispatch_path adapter_manifest_runner_kind \
      adapter_manifest_effective_route
    . "$1/executor-router.sh" || exit $?
    resolve_executor_at "$2" codex
  ' _ "$poison_root/lib" "$poison_root" 2>&1)" || rc=$?
  if [[ "$rc" -eq 2 && "$result" == *"required library unavailable:"* \
      && "$result" == *"/adapter-manifest.sh"* ]]; then
    pass "router source: inherited manifest functions cannot replace missing library"
  else
    fail "router source: inherited manifest functions cannot replace missing library" \
      "rc=$rc result=$result"
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
  # Both shipped adapters are cli-subprocess (canonical headless route), so both
  # resolve to main_thread_bash_background; claude reaches cli-only / no-bash-guard
  # via per-flag overrides, not a distinct route.
  if [[ "$codex_route" == "main_thread_bash_background" && "$claude_route" == "main_thread_bash_background" ]]; then
    pass "dispatch_route_for: codex and claude routes"
  else
    fail "dispatch_route_for: codex and claude routes" "codex=$codex_route claude=$claude_route"
  fi
fi

if should_run "router source: repository-relative path preserves checkout root"; then
  result="$(cd "$REPO_ROOT" && bash -c '. runtime/lib/executor-router.sh && dispatch_route_for codex' 2>&1)"
  if [[ "$result" == "main_thread_bash_background" ]]; then
    pass "router source: repository-relative path preserves checkout root"
  else
    fail "router source: repository-relative path preserves checkout root" "result=$result"
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
  EXECUTOR_ROUTER_REPO_ROOT="$ORIGINAL_ROUTER_REPO_ROOT"
  if [[ "$rc" -eq 0 && "$route" == "main_thread_bash_background" ]]; then
    pass "dispatch_route_for: new fixture adapter routable with zero core edit"
  else
    fail "dispatch_route_for: new fixture adapter routable with zero core edit" "rc=$rc route=$route"
  fi
fi

# Behavior: A host-native Adapter cannot route an executable shell entrypoint.
# Steps:
#   1. Arrange a host-native fixture Adapter with an executable dispatch.sh entrypoint.
#   2. Act by asking dispatch_route_for to derive its route.
#   3. Assert route derivation fails closed with exit 2.
if should_run "dispatch_route_for: host-native shell entrypoint is rejected"; then
  with_fixture_root host-native-fixture
  write_fixture_adapter "$FIXTURE_ROOT" hostlike host-native
  rc=0
  dispatch_route_for hostlike >/dev/null 2>&1 || rc=$?
  EXECUTOR_ROUTER_REPO_ROOT="$ORIGINAL_ROUTER_REPO_ROOT"
  [[ "$rc" -eq 2 ]] && pass "dispatch_route_for: host-native shell entrypoint is rejected" || fail "dispatch_route_for: host-native shell entrypoint is rejected" "rc=$rc"
fi

# Behavior: An agent_executor route override cannot make a cli-subprocess shell
# entrypoint executable through the incompatible agent route.
# Steps:
#   1. Arrange a cli-subprocess fixture with dispatch_route set to agent_executor.
#   2. Act by asking dispatch_route_for to derive its route.
#   3. Assert route derivation fails closed with exit 2.
if should_run "dispatch_route_for: agent route override cannot execute shell entrypoint"; then
  with_fixture_root override-fixture
  write_fixture_adapter "$FIXTURE_ROOT" overridden cli-subprocess "dispatch_route: agent_executor"
  rc=0
  dispatch_route_for overridden >/dev/null 2>&1 || rc=$?
  EXECUTOR_ROUTER_REPO_ROOT="$ORIGINAL_ROUTER_REPO_ROOT"
  [[ "$rc" -eq 2 ]] && pass "dispatch_route_for: agent route override cannot execute shell entrypoint" || fail "dispatch_route_for: agent route override cannot execute shell entrypoint" "rc=$rc"
fi

if should_run "dispatch_route_for: missing manifest is not routable (fail-closed)"; then
  with_fixture_root missing-fixture
  rc=0
  dispatch_route_for ghost >/dev/null 2>&1 || rc=$?
  EXECUTOR_ROUTER_REPO_ROOT="$ORIGINAL_ROUTER_REPO_ROOT"
  [[ "$rc" -ne 0 ]] && pass "dispatch_route_for: missing manifest is not routable (fail-closed)" || fail "dispatch_route_for: missing manifest is not routable (fail-closed)" "expected non-zero"
fi

if should_run "dispatch_route_for: invalid runner_kind is rejected (fail-closed)"; then
  with_fixture_root invalid-rk-fixture
  write_fixture_adapter "$FIXTURE_ROOT" bogus not-a-kind
  rc=0
  dispatch_route_for bogus >/dev/null 2>&1 || rc=$?
  EXECUTOR_ROUTER_REPO_ROOT="$ORIGINAL_ROUTER_REPO_ROOT"
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
  EXECUTOR_ROUTER_REPO_ROOT="$ORIGINAL_ROUTER_REPO_ROOT"
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
  EXECUTOR_ROUTER_REPO_ROOT="$ORIGINAL_ROUTER_REPO_ROOT"
  [[ "$rc" -eq 0 && "$result" == "opencode" ]] && pass "resolve_executor: accepts newly registered fixture adapter" || fail "resolve_executor: accepts newly registered fixture adapter" "rc=$rc result=$result"
fi

if should_run "dispatch_via: generic resolves adapter dispatch.sh and forwards sandbox for cli-subprocess"; then
  with_fixture_root via-cli-fixture
  write_fixture_adapter "$FIXTURE_ROOT" opencode cli-subprocess
  result="$(dispatch_via opencode "/tmp/brief.md" "/repo" default workspace-write never 1200)"
  EXECUTOR_ROUTER_REPO_ROOT="$ORIGINAL_ROUTER_REPO_ROOT"
  if printf '%s\n' "$result" | grep -q -- 'adapters/opencode/dispatch.sh' && printf '%s\n' "$result" | grep -q -- '--sandbox workspace-write --approval never'; then
    pass "dispatch_via: generic resolves adapter dispatch.sh and forwards sandbox for cli-subprocess"
  else
    fail "dispatch_via: generic resolves adapter dispatch.sh and forwards sandbox for cli-subprocess" "$result"
  fi
fi

# Behavior: Explicit-root dispatch builds a safely quoted command from the
# manifest-owned entrypoint without mutating the router's default root.
# Steps:
#   1. Arrange an explicit Adapter root whose manifest selects worker.sh and paths containing spaces.
#   2. Act by building the command with dispatch_via_at and parsing its quoted argv.
#   3. Assert bash targets worker.sh, preserves cd and brief paths, and leaves the default root unchanged.
if should_run "dispatch_via_at: routes manifest entrypoint from explicit root"; then
  with_fixture_root explicit-via-fixture
  write_fixture_adapter "$FIXTURE_ROOT" worker cli-subprocess
  mv "$FIXTURE_ROOT/adapters/worker/dispatch.sh" \
    "$FIXTURE_ROOT/adapters/worker/worker.sh"
  printf '%s\n' \
    'schema_version: 1' 'adapter_name: worker' 'runner_kind: cli-subprocess' \
    'dispatch_entrypoint: ./worker.sh' \
    > "$FIXTURE_ROOT/adapters/worker/adapter.yaml"
  explicit_root="$FIXTURE_ROOT"
  EXECUTOR_ROUTER_REPO_ROOT="$ORIGINAL_ROUTER_REPO_ROOT"
  result="$(dispatch_via_at "$explicit_root" worker \
    "/tmp/brief file.md" "/repo with space" default workspace-write never 1200)"
  eval "set -- $result"
  if [[ "$1" == bash \
      && "$2" == "$explicit_root/adapters/worker/worker.sh" \
      && "$4" == "/repo with space" \
      && "${12}" == "/tmp/brief file.md" \
      && "$EXECUTOR_ROUTER_REPO_ROOT" == "$ORIGINAL_ROUTER_REPO_ROOT" ]]; then
    pass "dispatch_via_at: routes manifest entrypoint from explicit root"
  else
    fail "dispatch_via_at: routes manifest entrypoint from explicit root" "$result"
  fi
fi

# Behavior: Generic dispatch refuses a host-native Adapter backed by a shell
# entrypoint.
# Steps:
#   1. Arrange a host-native fixture Adapter with an executable dispatch.sh entrypoint.
#   2. Act by invoking dispatch_via for that Adapter.
#   3. Assert command construction fails closed with exit 2.
if should_run "dispatch_via: host-native shell entrypoint fails closed"; then
  with_fixture_root via-host-fixture
  write_fixture_adapter "$FIXTURE_ROOT" hostlike host-native
  rc=0
  dispatch_via hostlike "/tmp/brief.md" "/repo" default workspace-write never 1200 >/dev/null 2>&1 || rc=$?
  EXECUTOR_ROUTER_REPO_ROOT="$ORIGINAL_ROUTER_REPO_ROOT"
  [[ "$rc" -eq 2 ]] && pass "dispatch_via: host-native shell entrypoint fails closed" || fail "dispatch_via: host-native shell entrypoint fails closed" "rc=$rc"
fi

# --- CC-531: manifest-owned dispatch entrypoint -----------------------------

# Behavior: Renaming an Adapter executable requires only a manifest update for
# generic dispatch to execute the renamed worker.
# Steps:
#   1. Arrange a cli-subprocess Adapter whose manifest selects a marker-writing worker.sh.
#   2. Act by building and executing the command returned by dispatch_via.
#   3. Assert the marker exists and the command names worker.sh but never dispatch.sh.
if should_run "dispatch_entrypoint: manifest-only rename to worker.sh executes worker"; then
  with_fixture_root manifest-worker-fixture
  write_fixture_adapter "$FIXTURE_ROOT" worker cli-subprocess
  marker="$FIXTURE_ROOT/worker.marker"
  printf '#!/usr/bin/env bash\nprintf worker > %q\n' "$marker" > "$FIXTURE_ROOT/adapters/worker/worker.sh"
  chmod +x "$FIXTURE_ROOT/adapters/worker/worker.sh"
  printf '%s\n' \
    'schema_version: 1' 'adapter_name: worker' 'runner_kind: cli-subprocess' \
    'dispatch_entrypoint: ./worker.sh' > "$FIXTURE_ROOT/adapters/worker/adapter.yaml"
  cmd="$(dispatch_via worker /tmp/brief.md /repo default workspace-write never 1200)"
  eval "$cmd"
  EXECUTOR_ROUTER_REPO_ROOT="$ORIGINAL_ROUTER_REPO_ROOT"
  if [[ -f "$marker" && "$cmd" == *'/adapters/worker/worker.sh'* \
      && "$cmd" != *'/adapters/worker/dispatch.sh'* ]]; then
    pass "dispatch_entrypoint: manifest-only rename to worker.sh executes worker"
  else
    fail "dispatch_entrypoint: manifest-only rename to worker.sh executes worker" "cmd=$cmd marker=$([[ -f "$marker" ]] && echo yes || echo no)"
  fi
fi

# Behavior: dispatch_entrypoint remains authoritative when a schema-v1 manifest
# also contains a stale deprecated runner_ref.
# Steps:
#   1. Arrange a manifest selecting worker.sh while runner_ref names run.sh.
#   2. Act by resolving the Adapter's dispatch path and capturing diagnostics.
#   3. Assert worker.sh is returned and a runner_ref deprecation warning is emitted.
if should_run "dispatch_entrypoint: canonical wins over stale runner_ref"; then
  with_fixture_root canonical-wins-fixture
  write_fixture_adapter "$FIXTURE_ROOT" worker cli-subprocess
  cp "$FIXTURE_ROOT/adapters/worker/dispatch.sh" "$FIXTURE_ROOT/adapters/worker/worker.sh"
  chmod +x "$FIXTURE_ROOT/adapters/worker/worker.sh"
  printf '%s\n' \
    'schema_version: 1' 'adapter_name: worker' 'runner_kind: cli-subprocess' \
    'dispatch_entrypoint: ./worker.sh' 'runner_ref: ./run.sh' \
    > "$FIXTURE_ROOT/adapters/worker/adapter.yaml"
  result="$(adapter_manifest_dispatch_path "$FIXTURE_ROOT" worker 2>"$FIXTURE_ROOT/warn")"
  EXECUTOR_ROUTER_REPO_ROOT="$ORIGINAL_ROUTER_REPO_ROOT"
  if [[ "$result" == "$FIXTURE_ROOT/adapters/worker/worker.sh" ]] \
      && grep -q 'runner_ref is deprecated' "$FIXTURE_ROOT/warn"; then
    pass "dispatch_entrypoint: canonical wins over stale runner_ref"
  else
    fail "dispatch_entrypoint: canonical wins over stale runner_ref" "result=$result"
  fi
fi

# Behavior: A schema-v1 manifest lacking dispatch_entrypoint uses dispatch.sh
# compatibility even when legacy runner_ref names a different executable.
# Steps:
#   1. Arrange a legacy manifest with runner_ref ./run.sh plus executable run.sh and dispatch.sh files.
#   2. Act by resolving the Adapter's dispatch path and capturing diagnostics.
#   3. Assert dispatch.sh is returned and the compatibility-default warning is emitted.
if should_run "dispatch_entrypoint: schema-v1 legacy runner_ref run uses dispatch compatibility"; then
  with_fixture_root legacy-runner-ref-fixture
  write_fixture_adapter "$FIXTURE_ROOT" legacy cli-subprocess
  printf '%s\n' \
    'schema_version: 1' 'adapter_name: legacy' 'runner_kind: cli-subprocess' \
    'runner_ref: ./run.sh' > "$FIXTURE_ROOT/adapters/legacy/adapter.yaml"
  printf '#!/usr/bin/env bash\nexit 99\n' > "$FIXTURE_ROOT/adapters/legacy/run.sh"
  chmod +x "$FIXTURE_ROOT/adapters/legacy/run.sh"
  result="$(adapter_manifest_dispatch_path "$FIXTURE_ROOT" legacy 2>"$FIXTURE_ROOT/warn")"
  EXECUTOR_ROUTER_REPO_ROOT="$ORIGINAL_ROUTER_REPO_ROOT"
  if [[ "$result" == "$FIXTURE_ROOT/adapters/legacy/dispatch.sh" ]] \
      && grep -q 'compatibility default' "$FIXTURE_ROOT/warn"; then
    pass "dispatch_entrypoint: schema-v1 legacy runner_ref run uses dispatch compatibility"
  else
    fail "dispatch_entrypoint: schema-v1 legacy runner_ref run uses dispatch compatibility" "result=$result"
  fi
fi

# Behavior: Every supported schema-v1 manifest without dispatch_entrypoint falls
# back to dispatch.sh and reports the compatibility path.
# Steps:
#   1. Arrange manifests with no runner_ref and with runner_ref ./dispatch.sh.
#   2. Act by resolving each Adapter dispatch path while capturing diagnostics.
#   3. Assert both return dispatch.sh, warn about the missing canonical field, and produce no failures.
if should_run "dispatch_entrypoint: schema-v1 missing canonical fallback matrix"; then
  failed=""
  for spec in no_runner_ref dispatch_runner_ref; do
    result=""
    with_fixture_root "legacy-fallback-$spec"
    write_fixture_adapter "$FIXTURE_ROOT" legacy cli-subprocess
    case "$spec" in
      no_runner_ref)
        printf '%s\n' \
          'schema_version: 1' 'adapter_name: legacy' \
          'runner_kind: cli-subprocess' \
          > "$FIXTURE_ROOT/adapters/legacy/adapter.yaml"
        ;;
      dispatch_runner_ref)
        printf '%s\n' \
          'schema_version: 1' 'adapter_name: legacy' \
          'runner_kind: cli-subprocess' 'runner_ref: ./dispatch.sh' \
          > "$FIXTURE_ROOT/adapters/legacy/adapter.yaml"
        ;;
    esac
    result="$(adapter_manifest_dispatch_path "$FIXTURE_ROOT" legacy \
      2>"$FIXTURE_ROOT/warn")" || failed="$failed $spec:rc=$?"
    [[ "$result" == "$FIXTURE_ROOT/adapters/legacy/dispatch.sh" ]] \
      || failed="$failed $spec:path=$result"
    grep -q 'schema v1 manifest lacks dispatch_entrypoint' "$FIXTURE_ROOT/warn" \
      || failed="$failed $spec:no-warning"
  done
  EXECUTOR_ROUTER_REPO_ROOT="$ORIGINAL_ROUTER_REPO_ROOT"
  [[ -z "$failed" ]] \
    && pass "dispatch_entrypoint: schema-v1 missing canonical fallback matrix" \
    || fail "dispatch_entrypoint: schema-v1 missing canonical fallback matrix" "$failed"
fi

# Behavior: Generated dispatch allowlist entries follow the manifest-owned
# executable rather than a conventional dispatch.sh filename.
# Steps:
#   1. Arrange an Adapter whose manifest selects worker.sh and has no dispatch.sh.
#   2. Act by generating dispatch allowlist entries for the fixture repository.
#   3. Assert the worker.sh Bash rule is present and no dispatch.sh rule is present.
if should_run "dispatch_entrypoint: allowlist follows worker manifest path"; then
  with_fixture_root allowlist-worker-fixture
  write_fixture_adapter "$FIXTURE_ROOT" worker cli-subprocess
  mv "$FIXTURE_ROOT/adapters/worker/dispatch.sh" "$FIXTURE_ROOT/adapters/worker/worker.sh"
  printf '%s\n' \
    'schema_version: 1' 'adapter_name: worker' 'runner_kind: cli-subprocess' \
    'dispatch_entrypoint: ./worker.sh' > "$FIXTURE_ROOT/adapters/worker/adapter.yaml"
  result="$(REPO_ROOT="$FIXTURE_ROOT" HOME="$tmp_root" dispatch_allowlist_entries)"
  EXECUTOR_ROUTER_REPO_ROOT="$ORIGINAL_ROUTER_REPO_ROOT"
  if [[ "$result" == *"Bash($FIXTURE_ROOT/adapters/worker/worker.sh:*)"* \
      && "$result" != *'/adapters/worker/dispatch.sh'* ]]; then
    pass "dispatch_entrypoint: allowlist follows worker manifest path"
  else
    fail "dispatch_entrypoint: allowlist follows worker manifest path" "$result"
  fi
fi

# Behavior: Invalid canonical dispatch_entrypoint values fail closed instead of
# falling back to a valid-looking deprecated runner_ref.
# Steps:
#   1. Arrange manifests covering empty, absolute, traversal, backslash, and space-containing values.
#   2. Act by resolving each path while runner_ref points at dispatch.sh.
#   3. Assert every canonical-value variant is rejected with exit 2.
if should_run "dispatch_entrypoint: invalid canonical values do not legacy-fallback"; then
  failed=""
  for spec in empty absolute traversal nested_traversal backslash space; do
    with_fixture_root "invalid-entrypoint-$spec"
    write_fixture_adapter "$FIXTURE_ROOT" bad cli-subprocess
    case "$spec" in
      empty) value='' ;;
      absolute) value='/tmp/worker.sh' ;;
      traversal) value='../worker.sh' ;;
      nested_traversal) value='./bin/../../worker.sh' ;;
      backslash) value='./bin\\worker.sh' ;;
      space) value='./worker script.sh' ;;
    esac
    printf '%s\n' \
      'schema_version: 1' 'adapter_name: bad' 'runner_kind: cli-subprocess' \
      "dispatch_entrypoint: $value" 'runner_ref: ./dispatch.sh' \
      > "$FIXTURE_ROOT/adapters/bad/adapter.yaml"
    rc=0
    adapter_manifest_dispatch_path "$FIXTURE_ROOT" bad >/dev/null 2>&1 || rc=$?
    [[ "$rc" -eq 2 ]] || failed="$failed $spec:$rc"
  done
  EXECUTOR_ROUTER_REPO_ROOT="$ORIGINAL_ROUTER_REPO_ROOT"
  [[ -z "$failed" ]] && pass "dispatch_entrypoint: invalid canonical values do not legacy-fallback" || fail "dispatch_entrypoint: invalid canonical values do not legacy-fallback" "$failed"
fi

# Behavior: Manifest dispatch resolution rejects unsafe executable targets and
# duplicate dispatch_entrypoint declarations at the Adapter trust boundary.
# Steps:
#   1. Arrange missing, non-executable, directory, leaf/parent symlink, boundary-prefix, and duplicate-key fixtures.
#   2. Act by resolving the dispatch path for each fixture.
#   3. Assert every unsafe-target or duplicate-key variant is rejected with exit 2.
if should_run "dispatch_entrypoint: missing nonexec directory and symlinks rejected"; then
  failed=""
  for spec in missing nonexec directory leaf_symlink parent_symlink boundary_prefix duplicate; do
    with_fixture_root "unsafe-entrypoint-$spec"
    write_fixture_adapter "$FIXTURE_ROOT" bad cli-subprocess
    case "$spec" in
      missing) value='./missing.sh' ;;
      nonexec)
        value='./worker.sh'; printf '#!/usr/bin/env bash\n' > "$FIXTURE_ROOT/adapters/bad/worker.sh"
        ;;
      directory)
        value='./worker'; mkdir "$FIXTURE_ROOT/adapters/bad/worker"
        ;;
      leaf_symlink)
        value='./worker.sh'; ln -s "$FIXTURE_ROOT/adapters/bad/dispatch.sh" "$FIXTURE_ROOT/adapters/bad/worker.sh"
        ;;
      parent_symlink)
        value='./bin/worker.sh'; mkdir -p "$FIXTURE_ROOT/outside"; printf '#!/usr/bin/env bash\n' > "$FIXTURE_ROOT/outside/worker.sh"; chmod +x "$FIXTURE_ROOT/outside/worker.sh"; ln -s "$FIXTURE_ROOT/outside" "$FIXTURE_ROOT/adapters/bad/bin"
        ;;
      boundary_prefix)
        value='./bin/worker.sh'; mkdir -p "$FIXTURE_ROOT/adapters/bad-evil"; printf '#!/usr/bin/env bash\n' > "$FIXTURE_ROOT/adapters/bad-evil/worker.sh"; chmod +x "$FIXTURE_ROOT/adapters/bad-evil/worker.sh"; ln -s ../bad-evil "$FIXTURE_ROOT/adapters/bad/bin"
        ;;
      duplicate)
        value='./dispatch.sh'
        ;;
    esac
    printf '%s\n' \
      'schema_version: 1' 'adapter_name: bad' 'runner_kind: cli-subprocess' \
      "dispatch_entrypoint: $value" > "$FIXTURE_ROOT/adapters/bad/adapter.yaml"
    if [[ "$spec" == duplicate ]]; then
      printf 'dispatch_entrypoint: ./dispatch.sh\n' >> "$FIXTURE_ROOT/adapters/bad/adapter.yaml"
    fi
    rc=0
    adapter_manifest_dispatch_path "$FIXTURE_ROOT" bad >/dev/null 2>&1 || rc=$?
    [[ "$rc" -eq 2 ]] || failed="$failed $spec:$rc"
  done
  EXECUTOR_ROUTER_REPO_ROOT="$ORIGINAL_ROUTER_REPO_ROOT"
  [[ -z "$failed" ]] && pass "dispatch_entrypoint: missing nonexec directory and symlinks rejected" || fail "dispatch_entrypoint: missing nonexec directory and symlinks rejected" "$failed"
fi

if should_run "dispatch_via: rejects unroutable executor"; then
  rc=0
  dispatch_via ghost "/tmp/brief.md" "/repo" default workspace-write never 1200 >/dev/null 2>&1 || rc=$?
  [[ "$rc" -ne 0 ]] && pass "dispatch_via: rejects unroutable executor" || fail "dispatch_via: rejects unroutable executor" "expected non-zero"
fi

# Trace-dir seam: dispatch_via forwards PM_DISPATCH_TRACE_DIR as an EXPLICIT
# --trace-dir flag so the built command is self-documenting (and the adapter does
# not silently depend on inherited env). Default (env unset) appends nothing.
if should_run "dispatch_via: forwards --trace-dir when PM_DISPATCH_TRACE_DIR set"; then
  with_fixture_root via-trace-set-fixture
  write_fixture_adapter "$FIXTURE_ROOT" opencode cli-subprocess
  result="$(PM_DISPATCH_TRACE_DIR=/srv/trace dispatch_via opencode "/tmp/brief.md" "/repo" default workspace-write never 1200)"
  EXECUTOR_ROUTER_REPO_ROOT="$ORIGINAL_ROUTER_REPO_ROOT"
  if printf '%s\n' "$result" | grep -q -- '--trace-dir /srv/trace'; then
    pass "dispatch_via: forwards --trace-dir when PM_DISPATCH_TRACE_DIR set"
  else
    fail "dispatch_via: forwards --trace-dir when PM_DISPATCH_TRACE_DIR set" "$result"
  fi
fi

if should_run "dispatch_via: omits --trace-dir when PM_DISPATCH_TRACE_DIR unset"; then
  with_fixture_root via-trace-unset-fixture
  write_fixture_adapter "$FIXTURE_ROOT" opencode cli-subprocess
  result="$(unset PM_DISPATCH_TRACE_DIR; dispatch_via opencode "/tmp/brief.md" "/repo" default workspace-write never 1200)"
  EXECUTOR_ROUTER_REPO_ROOT="$ORIGINAL_ROUTER_REPO_ROOT"
  if ! printf '%s\n' "$result" | grep -q -- '--trace-dir'; then
    pass "dispatch_via: omits --trace-dir when PM_DISPATCH_TRACE_DIR unset"
  else
    fail "dispatch_via: omits --trace-dir when PM_DISPATCH_TRACE_DIR unset" "$result"
  fi
fi

th_summary
