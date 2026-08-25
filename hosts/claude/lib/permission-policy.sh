#!/usr/bin/env bash
# Claude-owned permissions.allow policy for install-guards.sh /
# uninstall-guards.sh. Kept out of runtime/lib (shared cross-host layer)
# because these globs and the Edit(...)/Write(...) spelling rule are
# Claude-settings-specific, not portable policy.

# managed_permission_globs <gate_glob>
#   Prints, one per line, every filesystem glob pm-dispatch manages as an
#   Edit(...) / Write(...) permission entry in Claude settings.json. Callers
#   (install-guards.sh, uninstall-guards.sh) build the Edit(...) form (current)
#   and the Write(...) form (legacy spelling to migrate/remove) from these.
managed_permission_globs() {
  local gate_glob="$1"
  printf '%s\n' "$gate_glob" "/tmp/brief-*" "/tmp/handover-*"
}
