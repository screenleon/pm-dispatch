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

# Behavior: all shared runtime identifiers accept their documented boundary
# values and reject traversal, malformed, and cross-domain values.
# Steps: source the canonical policy and exercise each grammar directly.
test_identifier_policy_domains() {
  local name="runtime-lib-coverage/identifier-policy-domains" output
  should_run "$name" || return 0
  output="$(bash -c '
    . "$1/runtime/lib/identifier-policy.sh"
    pm_identifier_adapter_is_valid codex && ! pm_identifier_adapter_is_valid ../codex &&
    pm_identifier_host_is_valid generic && ! pm_identifier_host_is_valid custom &&
    pm_identifier_run_is_valid run-Ab9-z0 && ! pm_identifier_run_is_valid run-a_b-c &&
    pm_identifier_operation_is_valid op-20260811T092500Z-a1b2c3 && ! pm_identifier_operation_is_valid op-20260811-a1b2c3 &&
    pm_identifier_gate_is_valid gate-20260811-092500-Ab9def && ! pm_identifier_gate_is_valid gate-20260811-092500-short
  ' _ "$REPO_ROOT" 2>&1)" || true
  if [[ -z "$output" ]]; then pass "$name"; else fail "$name" "$output"; fi
}

# Behavior: every runtime library is safe to import into a caller that owns its
# own shell policy. Steps: source every library under each strict-mode variant
# and require shell flags, cwd, traps, watched files, and background jobs to
# remain unchanged.
test_all_runtime_libraries_are_source_safe() {
  local name="runtime-lib-coverage/all-runtime-libraries-source-safe" watched lib mode
  should_run "$name" || return 0
  watched="$tmp_root/source-contract"
  mkdir -p "$watched"
  printf 'sentinel\n' > "$watched/sentinel"
  for mode in none errexit nounset pipefail all; do
    for lib in "$REPO_ROOT"/runtime/lib/*.sh; do
      if ! bash -c '
        mode="$1"; lib="$2"; watched="$3"
        case "$mode" in none) ;; errexit) set -e ;; nounset) set -u ;; pipefail) set -o pipefail ;; all) set -euo pipefail ;; esac
        trap "printf trapped >&2" USR1
        before_flags="$-"; before_pipefail="$(set -o | awk '\''$1 == "pipefail" { print $2 }'\'')"; before_cwd="$PWD"; before_trap="$(trap -p USR1)"; before_files="$(find "$watched" -mindepth 1 -printf "%P\\n" | sort)"; before_jobs="$(jobs -p)"
        . "$lib"
        after_pipefail="$(set -o | awk '\''$1 == "pipefail" { print $2 }'\'')"; after_trap="$(trap -p USR1)"; after_files="$(find "$watched" -mindepth 1 -printf "%P\\n" | sort)"; after_jobs="$(jobs -p)"
        [[ "$before_flags" == "$-" && "$before_pipefail" == "$after_pipefail" && "$before_cwd" == "$PWD" && "$before_trap" == "$after_trap" && "$before_files" == "$after_files" && "$before_jobs" == "$after_jobs" ]]
      ' _ "$mode" "$lib" "$watched"; then
        fail "$name" "source contract failed: mode=$mode lib=${lib#"$REPO_ROOT"/}"
        return
      fi
    done
  done
  pass "$name"
}

test_gate_workspace_override
test_pmctl_config_loads_valid_values
test_pmctl_config_rejects_legacy_global_memory
test_identifier_policy_domains
test_all_runtime_libraries_are_source_safe
th_summary
