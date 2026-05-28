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

if should_run "isolation-map covers all levels"; then
  name="isolation-map covers all levels"
  repo="$tmp_root/$name"
  make_fixture_repo "$repo"
  run_pmctl "$repo" adapter generate codex >/dev/null
  ok=1
  while IFS= read -r level; do
    if ! grep -Fq "  $level:" "$repo/adapters/codex/isolation-map.yaml"; then
      ok=0
      fail "$name" "missing isolation level: $level"
      break
    fi
  done < <(awk '$1 == "-" { print $2 }' "$repo/core/policy/isolation-level.yaml")
  if [[ "$ok" -eq 1 ]]; then
    pass "$name"
  fi
fi

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

th_summary
