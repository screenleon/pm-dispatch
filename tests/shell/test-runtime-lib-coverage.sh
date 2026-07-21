#!/usr/bin/env bash
# Direct regression coverage for runtime/lib helpers that are otherwise only sourced by callers.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/../lib/test-harness.sh"
th_init "$@"

# Behavior: An explicit gate workspace override takes precedence over git discovery.
# Steps: Source the helper and verify that the environment override is returned unchanged.
test_gate_workspace_override() {
  local name="runtime-lib-coverage/gate-workspace-override" output
  should_run "$name" || return 0
  output="$(PM_DISPATCH_GATE_WORKSPACE=/tmp/declared-workspace bash -c '. "$1/runtime/lib/gate-workspace.sh"; gate_workspace_root /not-used /home/example' _ "$REPO_ROOT")"
  if [[ "$output" == /tmp/declared-workspace ]]; then pass "$name"; else fail "$name" "output=$output"; fi
}

# Behavior: Config parsing accepts valid dispatch defaults and project-scoped memory paths.
# Steps: Source the helper against a temporary config and assert the exported globals.
test_pmctl_config_loads_valid_values() {
  local name="runtime-lib-coverage/pmctl-config-loads-valid-values" cfg output key
  should_run "$name" || return 0; # shellcheck disable=SC2154
  cfg="$tmp_root/config"; key="0123456789abcdef0123456789abcdef01234567"
  printf '%s\n' 'dispatch.default_timeout = 42' 'dispatch.auto_pack = on' "memory.projects.$key.dir = /tmp/project-memory" > "$cfg"
  output="$(PM_DISPATCH_CONFIG_FILE="$cfg" bash -c '. "$1/runtime/lib/pmctl-config.sh"; pm_config_load "$2"; printf "%s|%s|%s|%s" "$PM_CFG_TIMEOUT" "$PM_CFG_AUTO_PACK" "$PM_CFG_MEMORY_DIR" "$PM_CFG_MEMORY_CONFIG_STATUS"' _ "$REPO_ROOT" "$key")"
  if [[ "$output" == '42|on|/tmp/project-memory|matched' ]]; then pass "$name"; else fail "$name" "output=$output"; fi
}

# Behavior: Unsafe legacy global memory settings are rejected for project-scoped callers.
# Steps: Load a temporary legacy-only config and assert its invalid status.
test_pmctl_config_rejects_legacy_global_memory() {
  local name="runtime-lib-coverage/pmctl-config-rejects-legacy-global-memory" cfg output key
  should_run "$name" || return 0; # shellcheck disable=SC2154
  cfg="$tmp_root/config"; key="0123456789abcdef0123456789abcdef01234567"
  printf '%s\n' 'dispatch.memory_dir = /tmp/legacy-memory' > "$cfg"
  output="$(PM_DISPATCH_CONFIG_FILE="$cfg" bash -c '. "$1/runtime/lib/pmctl-config.sh"; pm_config_load "$2" 2>/dev/null; printf "%s|%s" "$PM_CFG_MEMORY_DIR_INVALID" "$PM_CFG_MEMORY_CONFIG_STATUS"' _ "$REPO_ROOT" "$key")"
  if [[ "$output" == '1|legacy-global' ]]; then pass "$name"; else fail "$name" "output=$output"; fi
}

test_gate_workspace_override
test_pmctl_config_loads_valid_values
test_pmctl_config_rejects_legacy_global_memory
th_summary
