#!/usr/bin/env bash
# Shared guard audit-log location.  Host hooks may explicitly bind
# PM_GUARD_LOG_DIR; otherwise guards write under the product-owned state root,
# never under a host-specific configuration tree.

pm_guard_log_dir() {
  if [[ -n "${PM_GUARD_LOG_DIR:-}" ]]; then
    printf '%s\n' "$PM_GUARD_LOG_DIR"
  elif [[ -n "${PM_DISPATCH_STATE_ROOT:-}" ]]; then
    printf '%s\n' "$PM_DISPATCH_STATE_ROOT/logs"
  elif [[ -n "${XDG_DATA_HOME:-}" ]]; then
    printf '%s\n' "$XDG_DATA_HOME/pm-dispatch/state/logs"
  else
    printf '%s\n' "${HOME:-}/.local/share/pm-dispatch/state/logs"
  fi
}
