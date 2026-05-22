#!/usr/bin/env bash
# Idempotently splice the pm-dispatch hooks into
# ~/.claude/settings.json.
#
# Wires:
#   - matcher "Edit|Write" → scripts/hook-pm-write-guard.sh
#   - matcher "Edit|Write" → scripts/hook-codex-write-guard.sh
#   - matcher "Bash"       → scripts/hook-codex-bash-guard.sh
#   - matcher "*"          → scripts/hook-tool-trace.sh
#   - matcher "Bash|Agent" → scripts/hook-routing-log.sh
#   - Stop                 → scripts/hook-log-claude-usage.sh
#   - Stop                 → scripts/hook-session-summary.sh
#   - UserPromptSubmit     → scripts/hook-inject-memory.sh
#   - StatusLine           → scripts/hook-save-rate-limits.sh (chains previous if present)
#   - one-shot routing_log.md legacy bullet migrator before settings write
#
# Safe to re-run: detects existing entries (matched by command path) and skips
# them. Backs up settings.json once per run if any change is staged.
#
# Usage:
#   scripts/install-hooks.sh                       # apply, profile auto-detected
#   scripts/install-hooks.sh --dry-run             # show what would change
#   scripts/install-hooks.sh --profile minimal     # claude-only profile; skip codex hooks
#   scripts/install-hooks.sh --profile full        # explicit full profile (all hooks)
#
# Profile auto-detection (when --profile omitted):
#   `command -v codex` succeeds  → profile=full
#   otherwise                     → profile=minimal
# Minimal profile skips registering hook-codex-bash-guard.sh and
# hook-codex-write-guard.sh in settings.json. Other hooks (pm-write-guard,
# tool-trace, routing-log, session-summary, inject-memory, save-rate-limits)
# stay wired in both profiles.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"

# shellcheck source=scripts/lib/portable.sh
. "$SCRIPT_DIR/lib/portable.sh"

DRY_RUN=0
PROFILE=""
PLATFORM="auto"
ROUTE_LOG_ENABLED=1
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --profile)
      [[ $# -ge 2 ]] || { echo "install-hooks: --profile requires a value" >&2; exit 2; }
      PROFILE="$2"
      shift 2
      ;;
    --profile=*) PROFILE="${1#--profile=}"; shift ;;
    --platform)
      [[ $# -ge 2 ]] || { echo "install-hooks: --platform requires a value" >&2; exit 2; }
      PLATFORM="$2"
      shift 2
      ;;
    --platform=*) PLATFORM="${1#--platform=}"; shift ;;
    *) echo "install-hooks: unknown flag $1" >&2; exit 2 ;;
  esac
done

case "$PROFILE" in
  ""|minimal|full) ;;
  *) echo "install-hooks: --profile must be minimal or full (got: $PROFILE)" >&2; exit 2 ;;
esac

case "$PLATFORM" in
  ""|auto|linux|macos|windows) ;;
  *) echo "install-hooks: --platform must be auto|linux|macos|windows (got: $PLATFORM)" >&2; exit 2 ;;
esac

if [[ -z "$PROFILE" ]]; then
  PROFILE="$(detect_executor_profile)"
fi

if [[ "$PLATFORM" == "auto" ]]; then
  PLATFORM="$(detect_platform)"
fi

if [[ "$PLATFORM" == "windows" && "$PROFILE" == "full" ]]; then
  echo "install-hooks: platform=windows, --profile full requested; codex hooks unsupported on Windows yet, falling back to minimal" >&2
  PROFILE=minimal
fi

repo_root="${PM_DISPATCH_REPO:-$(cd "$(dirname "$0")/.." && pwd)}"
settings="$HOME/.claude/settings.json"
# shellcheck source=scripts/lib/memory-dir.sh
. "$repo_root/scripts/lib/memory-dir.sh"

if [[ "$PLATFORM" == "windows" ]] && ! command -v jq >/dev/null 2>&1; then
  ROUTE_LOG_ENABLED=0
fi

if ! command -v jq >/dev/null 2>&1; then
  cat >&2 <<EOF
install-hooks: jq is required but not found on PATH.

Install it for your platform, then re-run ./install.sh:

  Linux (Debian/Ubuntu):  sudo apt install jq
  Linux (Fedora/RHEL):    sudo dnf install jq
  Linux (Arch):           sudo pacman -S jq
  macOS (Homebrew):       brew install jq
  Windows (winget):       winget install jqlang.jq
  Windows (Chocolatey):   choco install jq -y

Detected platform: $PLATFORM
EOF
  exit 2
fi

if [ ! -f "$settings" ]; then
  echo "install-hooks: $settings not found — create it first" >&2
  exit 2
fi

pm_cmd="$repo_root/scripts/hook-pm-write-guard.sh"
cx_cmd="$repo_root/scripts/hook-codex-bash-guard.sh"
cxw_cmd="$repo_root/scripts/hook-codex-write-guard.sh"
trace_cmd="$repo_root/scripts/hook-tool-trace.sh"
routing_cmd="$repo_root/scripts/hook-routing-log.sh"
migrate_routing_cmd="$repo_root/scripts/migrate-routing-log.sh"
stop_cmd="$repo_root/scripts/hook-log-claude-usage.sh"
old_stop_cmd="$repo_root/hooks/hook-log-claude-usage.sh"
session_cmd="$repo_root/scripts/hook-session-summary.sh"
inject_cmd="$repo_root/scripts/hook-inject-memory.sh"
statusline_cmd="$repo_root/scripts/hook-save-rate-limits.sh"
statusline_chain_conf="$HOME/.claude/statusline-chain.conf"

if [ ! -x "$pm_cmd" ] || [ ! -x "$cx_cmd" ] || [ ! -x "$cxw_cmd" ] || [ ! -x "$trace_cmd" ] || [ ! -x "$routing_cmd" ] || [ ! -x "$migrate_routing_cmd" ] || [ ! -x "$stop_cmd" ] || [ ! -x "$session_cmd" ] || [ ! -x "$inject_cmd" ] || [ ! -x "$statusline_cmd" ]; then
  echo "install-hooks: hook scripts missing or not executable" >&2
  echo "  $pm_cmd" >&2
  echo "  $cx_cmd" >&2
  echo "  $cxw_cmd" >&2
  echo "  $trace_cmd" >&2
  echo "  $routing_cmd" >&2
  echo "  $migrate_routing_cmd" >&2
  echo "  $stop_cmd" >&2
  echo "  $session_cmd" >&2
  echo "  $inject_cmd" >&2
  echo "  $statusline_cmd" >&2
  exit 2
fi

# Build a temp file holding the new settings.json. jq does the work; we then
# diff against the original and apply only if it actually changed.
tmp_new="$(mktemp)"
trap 'rm -f "$tmp_new"' EXIT

# Read current statusLine.command to determine if chaining is needed.
_current_statusline=$(jq -r '.statusLine.command // empty' "$settings" 2>/dev/null || true)
_statusline_already_wired=0
if [[ "$(basename "${_current_statusline:-}")" == "$(basename "$statusline_cmd")" ]]; then
    _statusline_already_wired=1
elif [[ -n "$_current_statusline" && "$DRY_RUN" -eq 0 ]]; then
    # Save previous command so the hook can chain to it.
    printf '%s\n' "$_current_statusline" > "$statusline_chain_conf"
fi

jq \
  --arg pm "$pm_cmd" \
  --arg cx "$cx_cmd" \
  --arg cxw "$cxw_cmd" \
  --arg trace "$trace_cmd" \
  --arg routing "$routing_cmd" \
  --arg stop "$stop_cmd" \
  --arg old_stop "$old_stop_cmd" \
  --arg session "$session_cmd" \
  --arg inject "$inject_cmd" \
  --arg statusline "$statusline_cmd" \
  --argjson sl_present "$_statusline_already_wired" \
  --argjson route_enabled "$ROUTE_LOG_ENABLED" \
  --arg profile "$PROFILE" \
  '
  # Ensure .hooks.PreToolUse exists as an array.
  .hooks //= {} |
  .hooks.PreToolUse //= [] |
  .hooks.PostToolUse //= [] |
  .hooks.Stop //= [] |
  .hooks.UserPromptSubmit //= [] |

  # Migrate the former unmanaged Stop hook path under hooks/ to scripts/.
  # Use exact-path match — do not remove Stop hooks from other sources.
  .hooks.Stop |= map(
    .hooks |= map(select(.command != $old_stop))
  ) |
  .hooks.Stop |= map(select((.hooks | length) > 0)) |

  # Helper: an entry already exists if any matcher block has a managed hook with the same command basename.
  ( [ .hooks.PreToolUse[]? | (.hooks // [])[]? | select((.command | split("/") | last) == ($pm  | split("/") | last) and (.command | split("/") | .[-2]) == "scripts") ] | length ) as $pm_present |
  ( [ .hooks.PreToolUse[]? | (.hooks // [])[]? | select((.command | split("/") | last) == ($cx  | split("/") | last) and (.command | split("/") | .[-2]) == "scripts") ] | length ) as $cx_present |
  ( [ .hooks.PreToolUse[]? | (.hooks // [])[]? | select((.command | split("/") | last) == ($cxw | split("/") | last) and (.command | split("/") | .[-2]) == "scripts") ] | length ) as $cxw_present |
  ( [ .hooks.PreToolUse[]? | (.hooks // [])[]? | select((.command | split("/") | last) == ($trace | split("/") | last) and (.command | split("/") | .[-2]) == "scripts") ] | length ) as $trace_present |
  ( if $route_enabled == 1 then ( [ .hooks.PostToolUse[]? | (.hooks // [])[]? | select((.command | split("/") | last) == ($routing | split("/") | last) and (.command | split("/") | .[-2]) == "scripts") ] | length ) else 0 end ) as $routing_present |
  ( [ .hooks.Stop[]? | (.hooks // [])[]? | select((.command | split("/") | last) == ($stop    | split("/") | last) and (.command | split("/") | .[-2]) == "scripts") ] | length ) as $stop_present |
  ( [ .hooks.Stop[]? | (.hooks // [])[]? | select((.command | split("/") | last) == ($session | split("/") | last) and (.command | split("/") | .[-2]) == "scripts") ] | length ) as $session_present |
  ( [ .hooks.UserPromptSubmit[]? | (.hooks // [])[]? | select((.command | split("/") | last) == ($inject | split("/") | last) and (.command | split("/") | .[-2]) == "scripts") ] | length ) as $inject_present |

  # Refresh stale command paths for managed hooks (scripts/<basename> path shape).
  .hooks.PreToolUse |= map(
    .hooks |= map(
      if   ((.command | split("/") | last) == ($pm  | split("/") | last) and (.command | split("/") | .[-2]) == "scripts") then .command = $pm
      elif ((.command | split("/") | last) == ($cx  | split("/") | last) and (.command | split("/") | .[-2]) == "scripts") then .command = $cx
      elif ((.command | split("/") | last) == ($cxw | split("/") | last) and (.command | split("/") | .[-2]) == "scripts") then .command = $cxw
      elif ((.command | split("/") | last) == ($trace | split("/") | last) and (.command | split("/") | .[-2]) == "scripts") then .command = $trace
      else . end
    )
  ) |
  ( if $route_enabled == 1 then
      .hooks.PostToolUse |= map(
        .hooks |= map(
          if ((.command | split("/") | last) == ($routing | split("/") | last) and (.command | split("/") | .[-2]) == "scripts") then .command = $routing
          else . end
        )
      )
    else . end
  ) |
  .hooks.Stop |= map(
    .hooks |= map(
      if   ((.command | split("/") | last) == ($stop    | split("/") | last) and (.command | split("/") | .[-2]) == "scripts") then .command = $stop
      elif ((.command | split("/") | last) == ($session | split("/") | last) and (.command | split("/") | .[-2]) == "scripts") then .command = $session
      else . end
    )
  ) |
  .hooks.UserPromptSubmit |= map(
    .hooks |= map(
      if ((.command | split("/") | last) == ($inject | split("/") | last) and (.command | split("/") | .[-2]) == "scripts") then .command = $inject
      else . end
    )
  ) |
  ( if (((.statusLine.command? // "") | split("/") | last) == ($statusline | split("/") | last)
        and ((.statusLine.command? // "") | split("/") | .[-2]) == "scripts") then
      .statusLine.command = $statusline
    else . end
  ) |

  # Profile downgrade: when --profile minimal, REMOVE managed codex guards
  # if they were previously installed. The basename + "scripts" parent
  # match is the same shape used elsewhere in this file to identify
  # managed entries; out-of-scope codex hooks installed via other means
  # are left untouched.
  ( if $profile == "minimal" then
      .hooks.PreToolUse |= map(
        .hooks |= map(select(
          (
            ((.command | split("/") | last) == ($cx  | split("/") | last) and (.command | split("/") | .[-2]) == "scripts") or
            ((.command | split("/") | last) == ($cxw | split("/") | last) and (.command | split("/") | .[-2]) == "scripts")
          ) | not
        ))
      ) |
      .hooks.PreToolUse |= map(select((.hooks | length) > 0))
    else . end
  ) |

  ( if $pm_present == 0 then
      .hooks.PreToolUse += [{
        "matcher": "Edit|Write",
        "hooks": [{"type": "command", "command": $pm}]
      }]
    else . end
  ) |
  ( if $cxw_present == 0 and $profile == "full" then
      .hooks.PreToolUse += [{
        "matcher": "Edit|Write",
        "hooks": [{"type": "command", "command": $cxw}]
      }]
    else . end
  ) |
  ( if $cx_present == 0 and $profile == "full" then
      .hooks.PreToolUse += [{
        "matcher": "Bash",
        "hooks": [{"type": "command", "command": $cx}]
      }]
    else . end
  ) |
  ( if $trace_present == 0 then
      .hooks.PreToolUse += [{
        "matcher": "*",
        "hooks": [{"type": "command", "command": $trace}]
      }]
    else . end
  ) |
  ( if $route_enabled == 1 and $routing_present == 0 then
      .hooks.PostToolUse += [{
        "matcher": "Bash|Agent",
        "hooks": [{"type": "command", "command": $routing}]
      }]
    else . end
  ) |
  ( if $stop_present == 0 then
      .hooks.Stop += [{"hooks": [{"type": "command", "command": $stop}]}]
    else . end
  ) |
  ( if $session_present == 0 then
      .hooks.Stop += [{"hooks": [{"type": "command", "command": $session}]}]
    else . end
  ) |
  ( if $inject_present == 0 then
      .hooks.UserPromptSubmit += [{"hooks": [{"type": "command", "command": $inject}]}]
    else . end
  ) |
  ( if $sl_present == 0 then
      .statusLine = {"type": "command", "command": $statusline}
    else . end
  )
  ' "$settings" > "$tmp_new"

echo "install-hooks: profile=$PROFILE"
echo "install-hooks: platform=$PLATFORM"

if cmp -s "$settings" "$tmp_new"; then
  echo "install-hooks: already wired, nothing to do (profile=$PROFILE)"
  exit 0
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "install-hooks: would apply the following change:"
  diff -u "$settings" "$tmp_new" || true
  exit 0
fi

routing_log=""
if routing_memory_dir="$(find_memory_dir "$repo_root")"; then
  routing_log="$routing_memory_dir/routing_log.md"
fi

if [[ "$ROUTE_LOG_ENABLED" == "1" && -n "$routing_log" && -f "$routing_log" ]]; then
  if grep -q -F '<!-- routing-log:auto-block:start -->' "$routing_log" 2>/dev/null; then
    echo "install-hooks: routing-log already migrated, skipping migrator"
  else
    if "$migrate_routing_cmd" --cwd "$repo_root"; then
      :
    else
      status=$?
      echo "install-hooks: routing-log migrator failed; settings.json not modified" >&2
      exit "$status"
    fi
  fi
fi

backup="$settings.bak.$(date +%Y%m%d-%H%M%S)"
cp "$settings" "$backup"
mv "$tmp_new" "$settings"
trap - EXIT
echo "install-hooks: wrote $settings"
echo "install-hooks: backup at $backup"
