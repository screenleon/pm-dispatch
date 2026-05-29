#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C.UTF-8

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=scripts/lib/test-harness.sh
. "$SCRIPT_DIR/lib/test-harness.sh"
th_init "test-pmctl-adapter-generate" "$@"

make_fixture_repo() {
  local repo="$1" enum_values="${2:-codex claude}"
  local value

  mkdir -p "$repo/cli" "$repo/scripts/lib" "$repo/core/policy" "$repo/adapters"
  cp "$REPO_ROOT/cli/pmctl" "$repo/cli/pmctl"
  cp "$REPO_ROOT/scripts/lib/pmctl-adapter.sh" "$repo/scripts/lib/pmctl-adapter.sh"
  cp "$REPO_ROOT/scripts/lib/pmctl-fs.sh" "$repo/scripts/lib/pmctl-fs.sh"
  cp "$REPO_ROOT/scripts/lib/pmctl-policy.sh" "$repo/scripts/lib/pmctl-policy.sh"
  chmod +x "$repo/cli/pmctl"

  {
    printf 'values:\n'
    for value in $enum_values; do
      printf '  - %s\n' "$value"
    done
  } >"$repo/core/policy/executor-enum.yaml"

  cp "$REPO_ROOT/core/policy/isolation-level.yaml" "$repo/core/policy/isolation-level.yaml"
}

run_pmctl() {
  local repo="$1"
  shift
  "$repo/cli/pmctl" "$@"
}

assert_exists() {
  local name="$1" path="$2"
  if [[ -e "$path" ]]; then
    return 0
  fi
  fail "$name" "missing path: $path"
  return 1
}

assert_isolation_native_flags() {
  local name="$1" isomap="$2" level="$3" expected="$4"
  local actual

  actual="$(awk -v level="$level" '
    $0 == "  " level ":" {
      getline
      sub(/[[:space:]]+$/, "", $0)
      print
      exit
    }
  ' "$isomap")"

  if [[ "$actual" == "$expected" ]]; then
    return 0
  fi
  fail "$name" "expected '$expected', got '$actual'"
  return 1
}

# Behavior: rejects missing adapter name with non-zero exit
# Steps: invoke adapter generate without a name and check the usage error
if should_run "rejects missing name"; then
  name="rejects missing name"
  repo="$tmp_root/$name"
  make_fixture_repo "$repo"
  status=0
  out="$(run_pmctl "$repo" adapter generate 2>&1)" || status=$?
  if [[ "$status" -ne 0 && "$out" == *"adapter generate requires <name>"* ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$out"
  fi
fi

# Behavior: rejects unsafe adapter names before writing files
# Steps: invoke adapter generate with uppercase input and check validation
if should_run "rejects unsafe name"; then
  name="rejects unsafe name"
  repo="$tmp_root/$name"
  make_fixture_repo "$repo"
  status=0
  out="$(run_pmctl "$repo" adapter generate BadName 2>&1)" || status=$?
  if [[ "$status" -ne 0 && "$out" == *"invalid adapter name"* ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$out"
  fi
fi

# Behavior: rejects adapter names absent from the executor enum
# Steps: build an enum without codex and check the policy error
if should_run "rejects unknown executor"; then
  name="rejects unknown executor"
  repo="$tmp_root/$name"
  make_fixture_repo "$repo" "claude"
  status=0
  out="$(run_pmctl "$repo" adapter generate codex 2>&1)" || status=$?
  if [[ "$status" -ne 0 && "$out" == *"not in executor enum: codex"* ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$out"
  fi
fi

# Behavior: creates exactly the four generated adapter files
# Steps: generate codex and count/check the expected files
if should_run "creates all four files"; then
  name="creates all four files"
  repo="$tmp_root/$name"
  make_fixture_repo "$repo"
  run_pmctl "$repo" adapter generate codex >/dev/null
  count="$(find "$repo/adapters/codex" -maxdepth 1 -type f | wc -l | tr -d ' ')"
  if [[ "$count" == "4" ]] &&
    assert_exists "$name" "$repo/adapters/codex/adapter.yaml" &&
    assert_exists "$name" "$repo/adapters/codex/isolation-map.yaml" &&
    assert_exists "$name" "$repo/adapters/codex/run.sh" &&
    assert_exists "$name" "$repo/adapters/codex/README.md"; then
    pass "$name"
  else
    fail "$name" "expected exactly 4 generated files, got $count"
  fi
fi

# Behavior: generated run.sh has executable permission and mode 755
# Steps: generate codex and inspect run.sh mode and executable bit
if should_run "run.sh is executable"; then
  name="run.sh is executable"
  repo="$tmp_root/$name"
  make_fixture_repo "$repo"
  run_pmctl "$repo" adapter generate codex >/dev/null
  mode="$(stat -c '%a' "$repo/adapters/codex/run.sh")"
  if [[ -x "$repo/adapters/codex/run.sh" && "$mode" == "755" ]]; then
    pass "$name"
  else
    fail "$name" "mode=$mode"
  fi
fi

# Behavior: adapter.yaml contains the expected top-level contract fields
# Steps: generate codex and compare adapter.yaml field order and count
if should_run "adapter.yaml has 8 fields"; then
  name="adapter.yaml has 8 fields"
  repo="$tmp_root/$name"
  make_fixture_repo "$repo"
  run_pmctl "$repo" adapter generate codex >/dev/null
  fields="$(awk -F: '/^[a-z_]+:/ { print $1 }' "$repo/adapters/codex/adapter.yaml")"
  expected=$'schema_version\nadapter_name\nexecutor\ncli_binary\nisolation_map_ref\nrunner_ref\ndispatch_contract\ngenerated_files'
  count="$(printf '%s\n' "$fields" | wc -l | tr -d ' ')"
  if [[ "$count" == "8" && "$fields" == "$expected" ]]; then
    pass "$name"
  else
    fail "$name" "count=$count fields=$fields"
  fi
fi

# Behavior: generated isolation-map.yaml has correct exact native flag values
# Steps: generate codex and compare all isolation level mappings against expected values
if should_run "isolation-map exact flag values"; then
  name="isolation-map exact flag values"
  repo="$tmp_root/$name"
  make_fixture_repo "$repo"
  run_pmctl "$repo" adapter generate codex >/dev/null
  isomap="$repo/adapters/codex/isolation-map.yaml"
  if assert_isolation_native_flags "$name (none)" "$isomap" "none" '    native_flags: {}'; then
    pass "$name (none)"
  fi
  if assert_isolation_native_flags "$name (read-only)" "$isomap" "read-only" '    native_flags: { "--sandbox": "read-only" }'; then
    pass "$name (read-only)"
  fi
  if assert_isolation_native_flags "$name (workspace-write)" "$isomap" "workspace-write" '    native_flags: { "--sandbox": "workspace-write" }'; then
    pass "$name (workspace-write)"
  fi
  if assert_isolation_native_flags "$name (sandboxed)" "$isomap" "sandboxed" '    native_flags: { "--sandbox": "workspace-write" }  # best-effort: Codex has no full-isolation equivalent; treated as workspace-write'; then
    pass "$name (sandboxed)"
  fi
  if assert_isolation_native_flags "$name (workspace-network)" "$isomap" "workspace-network" '    native_flags: { "--sandbox": "workspace-write", "-c": "sandbox_workspace_write.network_access=true" }'; then
    pass "$name (workspace-network)"
  fi
fi

# Behavior: refuses to overwrite an existing generated adapter
# Steps: generate codex twice and check the overwrite error
if should_run "refuses overwrite"; then
  name="refuses overwrite"
  repo="$tmp_root/$name"
  make_fixture_repo "$repo"
  run_pmctl "$repo" adapter generate codex >/dev/null
  status=0
  out="$(run_pmctl "$repo" adapter generate codex 2>&1)" || status=$?
  if [[ "$status" -ne 0 && "$out" == *"adapter already exists: adapters/codex"* ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$out"
  fi
fi

# Behavior: unknown pmctl subcommands still route to the generic error
# Steps: invoke an unsupported adapter subcommand and check the error
if should_run "unknown command routes to error"; then
  name="unknown command routes to error"
  repo="$tmp_root/$name"
  make_fixture_repo "$repo"
  status=0
  out="$(run_pmctl "$repo" adapter nope 2>&1)" || status=$?
  if [[ "$status" -ne 0 && "$out" == *"unknown command: adapter nope"* ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$out"
  fi
fi

# Behavior: generated run.sh points at pmctl dispatch run
# Steps: generate codex and grep run.sh for the dispatch exec path
if should_run "run.sh points at pmctl dispatch run"; then
  name="run.sh points at pmctl dispatch run"
  repo="$tmp_root/$name"
  make_fixture_repo "$repo"
  run_pmctl "$repo" adapter generate codex >/dev/null
  if grep -Fq 'exec "$REPO_ROOT/cli/pmctl" dispatch run --adapter "$(basename "$ADAPTER_DIR")" "$@"' "$repo/adapters/codex/run.sh"; then
    pass "$name"
  else
    fail "$name" "run.sh did not contain pmctl dispatch run exec"
  fi
fi

# Behavior: generated run.sh reaches the dispatch/run route without unknown command
# Steps: generate testrouter, invoke run.sh, and inspect stub output
if should_run "run.sh reaches dispatch route"; then
  name="run.sh reaches dispatch route"
  repo="$tmp_root/$name"
  make_fixture_repo "$repo" "testrouter"
  run_pmctl "$repo" adapter generate testrouter >/dev/null
  status=0
  out="$(REPO_ROOT="$repo" bash "$repo/adapters/testrouter/run.sh" --help 2>&1)" || status=$?
  if [[ "$status" -eq 0 && "$out" == *"pmctl dispatch run: adapter dispatch stub"* && "$out" == *"adapter: testrouter"* && "$out" != *"unknown command"* ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$out"
  fi
fi

th_summary
