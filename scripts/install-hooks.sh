#!/usr/bin/env bash
# Idempotently splice the pm-dispatch hooks into
# ~/.claude/settings.json.
#
# Wires:
#   - matcher "Edit|Write" → scripts/hook-pm-write-guard.sh
#   - matcher "Edit|Write" → scripts/hook-codex-write-guard.sh
#   - matcher "Bash"       → scripts/hook-codex-bash-guard.sh
#   - matcher "*"          → scripts/hook-tool-trace.sh
#   - matcher "Bash|Agent" → scripts/hook-routing-log.sh (deprecated; disabled by default)
#   - Stop                 → scripts/hook-log-claude-usage.sh
#   - Stop                 → scripts/hook-session-summary.sh
#   - UserPromptSubmit     → scripts/hook-inject-memory.sh
#   - StatusLine           → scripts/hook-save-rate-limits.sh (chains previous if present)
#
# Note: hook-reviewer-write-guard.sh is NOT wired as a PreToolUse hook.
# It is a policy-backing script called exclusively by `pmctl guard check
# --role reviewer`. Both codex and claude reviewer paths use explicit
# pmctl guard check (CC-297 uniform explicit-guard design).
#
# Note: routing_log.md migration is NOT run automatically (CC-314).
# Run scripts/migrate-routing-to-events.sh manually to move legacy routing
# records into state-store events.jsonl.
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
# tool-trace, session-summary, inject-memory, save-rate-limits)
# stay wired in both profiles.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"

# Honor an explicit CLAUDE_HOME override (inherited from install.sh, or set when
# running standalone), so hook wiring lands in the same dir as the rest of the
# install. Defaults to ~/.claude.
CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"

# shellcheck source=scripts/lib/portable.sh
. "$SCRIPT_DIR/lib/portable.sh"

DRY_RUN=0
PROFILE=""
PLATFORM="auto"
ROUTE_LOG_ENABLED=0
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
settings="$CLAUDE_HOME/settings.json"
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
stop_cmd="$repo_root/scripts/hook-log-claude-usage.sh"
old_stop_cmd="$repo_root/hooks/hook-log-claude-usage.sh"
session_cmd="$repo_root/scripts/hook-session-summary.sh"
inject_cmd="$repo_root/scripts/hook-inject-memory.sh"
statusline_cmd="$repo_root/scripts/hook-save-rate-limits.sh"
statusline_chain_conf="$CLAUDE_HOME/statusline-chain.conf"

write_statusline_chain() {
  local first_cmd="$1"
  local chain_tmp chain_entry
  chain_tmp="$(mktemp)"
  {
    printf '%s\n' "$first_cmd"
    if [[ -f "$statusline_chain_conf" ]]; then
      while IFS= read -r chain_entry || [[ -n "$chain_entry" ]]; do
        [[ -n "$chain_entry" ]] || continue
        [[ "$chain_entry" == "$statusline_cmd" ]] && continue
        [[ "$chain_entry" == "$first_cmd" ]] && continue
        printf '%s\n' "$chain_entry"
      done < "$statusline_chain_conf"
    fi
  } > "$chain_tmp"
  mv "$chain_tmp" "$statusline_chain_conf"
}

if [ ! -x "$pm_cmd" ] || [ ! -x "$cx_cmd" ] || [ ! -x "$cxw_cmd" ] || [ ! -x "$trace_cmd" ] || [ ! -x "$routing_cmd" ] || [ ! -x "$stop_cmd" ] || [ ! -x "$session_cmd" ] || [ ! -x "$inject_cmd" ] || [ ! -x "$statusline_cmd" ]; then
  echo "install-hooks: hook scripts missing or not executable" >&2
  echo "  $pm_cmd" >&2
  echo "  $cx_cmd" >&2
  echo "  $cxw_cmd" >&2
  echo "  $trace_cmd" >&2
  echo "  $routing_cmd" >&2
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
if [[ "${_current_statusline:-}" == "$statusline_cmd" ]]; then
    _statusline_already_wired=1
elif [[ "$(basename "${_current_statusline:-}")" == "$(basename "$statusline_cmd")" ]]; then
    _current_statusline_path="${_current_statusline%%[[:space:]]*}"
    if [[ ! -e "$_current_statusline_path" ]]; then
        _statusline_already_wired=1
    elif [[ "$DRY_RUN" -eq 0 ]]; then
        # Existing same-basename hooks from other tools are real chain targets,
        # not stale managed paths.
        write_statusline_chain "$_current_statusline"
    fi
elif [[ -n "$_current_statusline" && "$DRY_RUN" -eq 0 ]]; then
    # Save previous command so the hook can chain to it. Preserve any existing
    # chain entries because several local tools may share the statusLine slot.
    write_statusline_chain "$_current_statusline"
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
    else
      .hooks.PostToolUse |= map(
        .hooks |= map(select(
          ((.command | split("/") | last) == ($routing | split("/") | last) and (.command | split("/") | .[-2]) == "scripts") | not
        ))
      ) |
      .hooks.PostToolUse |= map(select((.hooks | length) > 0))
    end
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

# --- Permissions merge for reviewer subagents (CC-334) ---
# Reviewer subagents spawned by pr-gate need Write(.gate-results) and Bash(pmctl guard check)
# to write results and run guard checks. Detect workspace root from the pm-dispatch repo's parent.
# PM_DISPATCH_GATE_WORKSPACE overrides auto-detection (use when pm-dispatch is installed from a
# central/tooling checkout that doesn't share a parent with the repos being gated).
if [[ -n "${PM_DISPATCH_GATE_WORKSPACE:-}" ]]; then
  _workspace_root="$PM_DISPATCH_GATE_WORKSPACE"
else
  _pm_repo_git_root="$(git -C "$repo_root" rev-parse --show-toplevel 2>/dev/null || echo "$repo_root")"
  _workspace_root="$(dirname "$_pm_repo_git_root")"
  if [[ "$_workspace_root" == "$HOME" || "$_workspace_root" == "/" ]]; then
    _workspace_root="$HOME"
  fi
fi
_gate_glob="${_workspace_root}/**/.gate-results/**"

_tmp_perms="$(mktemp)"
trap 'rm -f "$tmp_new" "$_tmp_perms"' EXIT
if ! jq \
  --arg write_perm "Write(${_gate_glob})" \
  --arg bash_guard "Bash(pmctl guard check:*)" \
  --arg bash_mkdir "Bash(mkdir -p:*)" \
  '
  .permissions //= {} |
  .permissions.allow //= [] |
  ([$write_perm, $bash_guard, $bash_mkdir]) as $required |
  .permissions.allow |= (
    . as $existing |
    . + ($required | map(select(. as $p | ($existing | map(select(. == $p)) | length) == 0)))
  )
  ' "$tmp_new" > "$_tmp_perms"; then
  echo "install-hooks: ERROR: failed to merge permissions.allow — check that $settings is valid JSON" >&2
  exit 2
fi
mv "$_tmp_perms" "$tmp_new"
trap 'rm -f "$tmp_new"' EXIT

echo "install-hooks: profile=$PROFILE"
echo "install-hooks: platform=$PLATFORM"
echo "install-hooks: gate-results glob: $_gate_glob"

if cmp -s "$settings" "$tmp_new"; then
  echo "install-hooks: already wired, nothing to do (profile=$PROFILE)"
  exit 0
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "install-hooks: would apply the following change:"
  diff -u "$settings" "$tmp_new" || true
  exit 0
fi

# Routing-log migration is manual (CC-314): run scripts/migrate-routing-to-events.sh
# to move legacy routing_log.md records into state-store events.jsonl.

backup="$settings.bak.$(date +%Y%m%d-%H%M%S)"
cp "$settings" "$backup"
mv "$tmp_new" "$settings"
trap - EXIT
echo "install-hooks: wrote $settings"
echo "install-hooks: backup at $backup"
