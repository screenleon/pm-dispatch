#!/usr/bin/env bash
# shellcheck disable=SC1091
# Idempotently splice the pm-dispatch hooks into
# ~/.claude/settings.json.
#
# Wires:
#   - matcher "Edit|Write" → runtime/hooks/guard-pm-write.sh
#   - matcher "Bash"       → adapters/<name>/bash-guard.sh  (manifest-derived; needs_bash_guard=true)
#   - Stop                 → hosts/claude/hooks/log-usage.sh
#   - Stop                 → runtime/hooks/guard-session-summary.sh
#   - UserPromptSubmit     → runtime/hooks/guard-inject-memory.sh
#   - UserPromptSubmit     → runtime/hooks/guard-inject-context.sh
#   - StatusLine           → hosts/claude/hooks/save-rate-limits.sh (chains previous if present)
#
# Note: guard-reviewer-write.sh is NOT wired as a PreToolUse hook.
# It is a policy-backing script called exclusively by `pmctl guard check
# --role reviewer`. Both codex and claude reviewer paths use explicit
# pmctl guard check (uniform explicit-guard design).
#
# Note: routing_log.md migration is NOT run automatically.
# Run ops/migrations/migrate-routing-to-events.sh manually to move legacy routing
# records into state-store events.jsonl.
# Safe to re-run: detects existing entries (matched by command path) and skips
# them. Backs up settings.json once per run if any change is staged.
#
# Usage:
#   hosts/claude/bin/install-guards.sh --repo-root <checkout>
#   hosts/claude/bin/install-guards.sh --repo-root <checkout> --dry-run
#   hosts/claude/bin/install-guards.sh --repo-root <checkout> --profile minimal
#   hosts/claude/bin/install-guards.sh --repo-root <checkout> --profile full
#
# Profile auto-detection (when --profile omitted):
#   `command -v codex` succeeds  → profile=full
#   otherwise                     → profile=minimal
# Minimal profile skips registering adapter bash guards (adapters/<name>/bash-guard.sh
# derived from adapter manifests with needs_bash_guard=true). Other hooks
# (pm-write-guard, session-summary, inject-memory, save-rate-limits) stay wired in
# both profiles.

set -euo pipefail

DRY_RUN=0
PROFILE=""
PLATFORM="auto"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
REPO_ROOT=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --repo-root)
      [[ $# -ge 2 ]] || { echo "install-guards: --repo-root requires a value" >&2; exit 2; }
      REPO_ROOT="$2"
      shift 2
      ;;
    --profile)
      [[ $# -ge 2 ]] || { echo "install-guards: --profile requires a value" >&2; exit 2; }
      PROFILE="$2"
      shift 2
      ;;
    --profile=*) PROFILE="${1#--profile=}"; shift ;;
    --platform)
      [[ $# -ge 2 ]] || { echo "install-guards: --platform requires a value" >&2; exit 2; }
      PLATFORM="$2"
      shift 2
      ;;
    --platform=*) PLATFORM="${1#--platform=}"; shift ;;
    *) echo "install-guards: unknown flag $1" >&2; exit 2 ;;
  esac
done

if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="${PM_DISPATCH_REPO:-$(cd "$SCRIPT_DIR/../../.." && pwd -P)}"
else
  case "$REPO_ROOT" in
    /*) ;;
    *) echo "install-guards: --repo-root must be absolute" >&2; exit 2 ;;
  esac
  (cd "$REPO_ROOT" 2>/dev/null) || {
    echo "install-guards: --repo-root does not exist" >&2
    exit 2
  }
fi
[[ -f "$REPO_ROOT/hosts/claude/host.yaml" && -f "$REPO_ROOT/runtime/lib/host-manifest.sh" ]] || {
  echo "install-guards: --repo-root is not a compatible pm-dispatch checkout: $REPO_ROOT" >&2
  exit 2
}

# shellcheck source=hosts/claude/lib/prompt-context-timeouts.sh
. "$REPO_ROOT/hosts/claude/lib/prompt-context-timeouts.sh"
# shellcheck source=hosts/claude/lib/path-resolver.sh
. "$REPO_ROOT/hosts/claude/lib/path-resolver.sh"
# shellcheck source=runtime/lib/portable.sh
. "$REPO_ROOT/runtime/lib/portable.sh"

_claude_root="$(claude_host_config_root 2>&1)" || {
  printf 'install-guards: %s\n' "$_claude_root" >&2
  exit 2
}
CLAUDE_CONFIG_DIR="$_claude_root"
CLAUDE_HOME="$CLAUDE_CONFIG_DIR"
unset _claude_root

case "$PROFILE" in
  ""|minimal|full) ;;
  *) echo "install-guards: --profile must be minimal or full (got: $PROFILE)" >&2; exit 2 ;;
esac

case "$PLATFORM" in
  ""|auto|linux|macos|windows) ;;
  *) echo "install-guards: --platform must be auto|linux|macos|windows (got: $PLATFORM)" >&2; exit 2 ;;
esac

if [[ -z "$PROFILE" ]]; then
  PROFILE="$(detect_executor_profile)"
fi

if [[ "$PLATFORM" == "auto" ]]; then
  PLATFORM="$(detect_platform)"
fi

if [[ "$PLATFORM" == "windows" && "$PROFILE" == "full" ]]; then
  echo "install-guards: platform=windows, --profile full requested; codex hooks unsupported on Windows yet, falling back to minimal" >&2
  PROFILE=minimal
fi

repo_root="$REPO_ROOT"
settings="$CLAUDE_HOME/settings.json"
# shellcheck source=runtime/lib/memory-dir.sh
. "$repo_root/runtime/lib/memory-dir.sh"
# shellcheck source=runtime/lib/gate-workspace.sh
. "$repo_root/runtime/lib/gate-workspace.sh"

if ! command -v jq >/dev/null 2>&1; then
  cat >&2 <<EOF
install-guards: jq is required but not found on PATH.

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
  echo "install-guards: $settings not found — create it first" >&2
  exit 2
fi

pm_cmd="$repo_root/runtime/hooks/guard-pm-write.sh"
stop_cmd="$repo_root/hosts/claude/hooks/log-usage.sh"
old_stop_cmd="$repo_root/hooks/guard-log-claude-usage.sh"
legacy_stop_cmd="$repo_root/scripts/guard-log-claude-usage.sh"
session_path="$repo_root/runtime/hooks/guard-session-summary.sh"
inject_cmd="$repo_root/runtime/hooks/guard-inject-memory.sh"
ctx_inject_cmd="$repo_root/runtime/hooks/guard-inject-context.sh"
statusline_cmd="$repo_root/hosts/claude/hooks/save-rate-limits.sh"
legacy_statusline_cmd="$repo_root/scripts/guard-save-rate-limits.sh"
statusline_chain_conf="$CLAUDE_HOME/statusline-chain.conf"

# shellcheck source=runtime/lib/runner-kind.sh
. "$repo_root/runtime/lib/runner-kind.sh"

# Scan adapters/ manifests and collect bash-guard command paths for adapters
# where needs_bash_guard resolves to true. Builds _bash_guard_cmds[] (absolute
# paths) and _bg_json (JSON array of printf-%q-escaped paths for jq).
_bash_guard_cmds=()
for _manifest in "$repo_root"/adapters/*/adapter.yaml; do
  [[ -f "$_manifest" ]] || continue
  _adapter_dir="$(dirname "$_manifest")"
  _adapter_name="$(basename "$_adapter_dir")"
  _rk="$(runner_kind_manifest_field "$_manifest" runner_kind)"
  [[ -n "$_rk" ]] || continue
  _nbg_override="$(runner_kind_manifest_field "$_manifest" needs_bash_guard)"
  _nbg="$(runner_kind_resolve_flag "$_rk" needs_bash_guard "$_nbg_override")"
  if [[ "$_nbg" == "true" ]]; then
    _guard_file="$_adapter_dir/bash-guard.sh"
    [[ -x "$_guard_file" ]] || {
      echo "install-guards: adapter '$_adapter_name' needs_bash_guard=true but bash-guard.sh missing or not executable: $_guard_file" >&2
      exit 2
    }
    _bash_guard_cmds+=("$_guard_file")
  fi
done
if [[ ${#_bash_guard_cmds[@]} -eq 0 ]]; then
  _bg_json='[]'
else
  _bg_json="$(
    for _bg_cmd in "${_bash_guard_cmds[@]}"; do printf '%q\n' "$_bg_cmd"; done \
    | jq -Rs 'split("\n") | map(select(. != ""))'
  )"
fi

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
        [[ "$chain_entry" == "$legacy_statusline_cmd" ]] && continue
        [[ "$chain_entry" == "$first_cmd" ]] && continue
        printf '%s\n' "$chain_entry"
      done < "$statusline_chain_conf"
    fi
  } > "$chain_tmp"
  mv "$chain_tmp" "$statusline_chain_conf"
}

if [ ! -x "$pm_cmd" ] || [ ! -x "$stop_cmd" ] || [ ! -x "$session_path" ] || [ ! -x "$inject_cmd" ] || [ ! -x "$ctx_inject_cmd" ] || [ ! -x "$statusline_cmd" ]; then
  echo "install-guards: hook scripts missing or not executable" >&2
  echo "  $pm_cmd" >&2
  echo "  $stop_cmd" >&2
  echo "  $session_path" >&2
  echo "  $inject_cmd" >&2
  echo "  $ctx_inject_cmd" >&2
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
if [[ "${_current_statusline:-}" == "$statusline_cmd" || "${_current_statusline:-}" == "$legacy_statusline_cmd" ]]; then
    _statusline_already_wired=1
elif [[ "$(basename "${_current_statusline:-}")" == "$(basename "$legacy_statusline_cmd")" \
    && "$(basename "$(dirname "${_current_statusline%%[[:space:]]*}")")" == "scripts" ]]; then
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

# Claude Code runs each hook `command` string through the shell. An unquoted
# path with a space (e.g. a Windows home like C:/Users/First Last/) is word-split
# and the hook fails ("No such file or directory"). Shell-escape every managed
# command path before it is written. printf %q only adds backslashes when needed,
# so space-free paths are stored verbatim (no churn for existing installs). The
# escaping is transparent to the split("/")|last basename matching below — a
# backslash-escaped space stays inside a path component, never a "/" boundary.
# old_stop is NOT escaped: it is matched verbatim against the legacy unmanaged
# path to remove it, so it must stay in raw (unescaped) form.
pm_cmd_q="$(printf '%q' "$pm_cmd")"
stop_cmd_q="$(printf '%q' "$stop_cmd")"
legacy_stop_cmd_q="$(printf '%q' "$legacy_stop_cmd")"
session_cmd_q="$(printf '%q' "$session_path") --host claude"
inject_cmd_q="$(printf '%q' "$inject_cmd")"
ctx_inject_cmd_q="$(printf '%q' "$ctx_inject_cmd")"
statusline_cmd_q="$(printf '%q' "$statusline_cmd")"
legacy_statusline_cmd_q="$(printf '%q' "$legacy_statusline_cmd")"

# MSYS2/Git-Bash rewrites `\` → `/` when passing args to a native jq.exe, which
# corrupts the printf %q escaping in a spaced path (Lien\ Chen → Lien/ Chen).
# Disabling that argument path conversion keeps the escaped --arg command paths
# verbatim — but it would also stop the native jq from opening a POSIX-path
# positional input file, so the input settings is fed via stdin (bash opens it,
# understanding /c/... paths) rather than as a positional argument. Both env vars
# are no-ops on Linux/macOS where MSYS is absent.
MSYS2_ARG_CONV_EXCL='*' MSYS_NO_PATHCONV=1 jq \
  --arg pm "$pm_cmd_q" \
  --arg stop "$stop_cmd_q" \
  --arg old_stop "$old_stop_cmd" \
  --arg legacy_stop "$legacy_stop_cmd" \
  --arg legacy_stop_q "$legacy_stop_cmd_q" \
  --arg session "$session_cmd_q" \
  --arg inject "$inject_cmd_q" \
  --arg ctx_inject "$ctx_inject_cmd_q" \
  --argjson ctx_inject_timeout "$CLAUDE_PROMPT_CONTEXT_HOOK_TIMEOUT" \
  --arg statusline "$statusline_cmd_q" \
  --arg legacy_statusline "$legacy_statusline_cmd" \
  --arg legacy_statusline_q "$legacy_statusline_cmd_q" \
  --argjson sl_present "$_statusline_already_wired" \
  --argjson bg_guards "$_bg_json" \
  --arg profile "$PROFILE" \
  '
  def without_host_arg: sub(" --host (claude|codex|opencode|grok|generic)$"; "");
  def managed_shared($cmd; $expected):
    ($cmd | without_host_arg | split("/")) as $parts |
    ($expected | without_host_arg | split("/")) as $wanted |
    ($parts[-1] == $wanted[-1] and
      ($parts[-2] == "scripts" or ($parts[-2] == "hooks" and $parts[-3] == "runtime")));

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

  # Prune retired managed hooks from existing installs. Includes the per-runtime
  # executor write-guards retired in the v0.6.0 collapse, the scripts/-based
  # bash guards now manifest-driven from adapters/, and the pre-rename hook-*
  # basenames superseded by guard-* in this release. Basenames are
  # split with string concat so the doctor guard-inventory parity scanner does not
  # count these retired names as current managed hooks.
  .hooks.PreToolUse |= map(
    .hooks |= map(select(
      ( ((.command | split("/") | last) == ("hook-tool-" + "trace.sh")) or
        ((.command | split("/") | last) == ("hook-codex-write" + "-guard.sh")) or
        ((.command | split("/") | last) == ("hook-claude-write" + "-guard.sh")) or
        ((.command | split("/") | last) == ("hook-executor-write-" + "guard.sh")) or
        ((.command | split("/") | last) == ("hook-codex-bash-" + "guard.sh")) or
        ((.command | split("/") | last) == ("hook-pm-write-" + "guard.sh")) or
        ((.command | split("/") | last) == ("hook-reviewer-write-" + "guard.sh")) )
      and ((.command | split("/") | .[-2]) == "scripts") | not
    ))
  ) |
  .hooks.PreToolUse |= map(select((.hooks | length) > 0)) |

  # Prune pre-rename hook-* Stop entries superseded by guard-*.
  .hooks.Stop |= map(
    .hooks |= map(select(
      ( ((.command | split("/") | last) == ("hook-log-claude-" + "usage.sh")) or
        ((.command | split("/") | last) == ("hook-session-" + "summary.sh")) )
      and ((.command | split("/") | .[-2]) == "scripts") | not
    ))
  ) |
  .hooks.Stop |= map(select((.hooks | length) > 0)) |

  # Prune pre-rename hook-inject-memory superseded by guard-inject-memory.
  .hooks.UserPromptSubmit |= map(
    .hooks |= map(select(
      ((.command | split("/") | last) == ("hook-inject-" + "memory.sh"))
      and ((.command | split("/") | .[-2]) == "scripts") | not
    ))
  ) |
  .hooks.UserPromptSubmit |= map(select((.hooks | length) > 0)) |

  # Prune orphaned adapter bash guards: any wired adapters/<name>/bash-guard.sh
  # whose path is not in the current manifest-derived $bg_guards set. This makes
  # the adapter manifests the single source of truth for which bash guards are
  # wired — when an adapter flips needs_bash_guard to false (or is removed), its
  # previously wired guard is cleaned from existing installs on the next run,
  # regardless of profile. ($bg_guards is [] when no adapter needs a guard.)
  .hooks.PreToolUse |= map(
    .hooks |= map(
      (.command) as $c |
      select(
        ( ($c | split("/") | last) == "bash-guard.sh"
          and ($c | split("/") | .[-3]) == "adapters"
          and ($bg_guards | index($c)) == null ) | not
      )
    )
  ) |
  .hooks.PreToolUse |= map(select((.hooks | length) > 0)) |
  .hooks.PostToolUse |= map(
    .hooks |= map(select(
      ((.command | split("/") | last) == ("hook-routing-" + "log.sh") and (.command | split("/") | .[-2]) == "scripts") | not
    ))
  ) |
  .hooks.PostToolUse |= map(select((.hooks | length) > 0)) |

  # Helper: an entry already exists if any matcher block has a managed hook with the same command basename.
  ( [ .hooks.PreToolUse[]? | (.hooks // [])[]? | select(managed_shared(.command; $pm)) ] | length ) as $pm_present |
  ( [ .hooks.Stop[]? | (.hooks // [])[]? | select(
      .command == $stop or .command == $legacy_stop or .command == $legacy_stop_q or
      (((.command | split("/") | last) == ($legacy_stop | split("/") | last)) and ((.command | split("/") | .[-2]) == "scripts"))
    ) ] | length ) as $stop_present |
  ( [ .hooks.Stop[]? | (.hooks // [])[]? | select(managed_shared(.command; $session)) ] | length ) as $session_present |
  ( [ .hooks.UserPromptSubmit[]? | (.hooks // [])[]? | select(managed_shared(.command; $inject)) ] | length ) as $inject_present |
  ( [ .hooks.UserPromptSubmit[]? | (.hooks // [])[]? | select(managed_shared(.command; $ctx_inject)) ] | length ) as $ctx_inject_present |

  # Refresh stale command paths for managed hooks (scripts/<basename> path shape).
  .hooks.PreToolUse |= map(
    .hooks |= map(
      if managed_shared(.command; $pm) then .command = $pm
      else . end
    )
  ) |
  # Refresh stale adapter bash-guard paths (adapters/<name>/bash-guard.sh shape).
  reduce $bg_guards[] as $bg_cmd (
    .;
    .hooks.PreToolUse |= map(
      .hooks |= map(
        if ((.command | split("/") | last) == ($bg_cmd | split("/") | last)
            and (.command | split("/") | .[-2]) == ($bg_cmd | split("/") | .[-2])
            and (.command | split("/") | .[-3]) == "adapters") then
          .command = $bg_cmd
        else . end
      )
    )
  ) |
  .hooks.Stop |= map(
    .hooks |= map(
      if   (.command == $legacy_stop or .command == $legacy_stop_q or .command == $stop
            or (((.command | split("/") | last) == ($legacy_stop | split("/") | last)) and ((.command | split("/") | .[-2]) == "scripts"))) then .command = $stop
      elif managed_shared(.command; $session) then .command = $session
      else . end
    )
  ) |
  .hooks.UserPromptSubmit |= map(
    .hooks |= map(
      if   managed_shared(.command; $inject) then .command = $inject
      elif managed_shared(.command; $ctx_inject) then
        .command = $ctx_inject | .timeout = $ctx_inject_timeout
      else . end
    )
  ) |
  ( if ((.statusLine.command? // "") == $legacy_statusline
        or (.statusLine.command? // "") == $legacy_statusline_q
        or (.statusLine.command? // "") == $statusline
        or ((((.statusLine.command? // "") | split("/") | last) == ($legacy_statusline | split("/") | last))
            and (((.statusLine.command? // "") | split("/") | .[-2]) == "scripts"))) then
      .statusLine.command = $statusline
    else . end
  ) |

  # Profile downgrade: when --profile minimal, REMOVE managed adapter bash guards
  # if they were previously installed. Identified by basename == "bash-guard.sh"
  # under an adapters/ tree (.[-3] == "adapters"); out-of-scope hooks are left
  # untouched.
  ( if $profile == "minimal" then
      .hooks.PreToolUse |= map(
        .hooks |= map(select(
          ((.command | split("/") | last) == "bash-guard.sh"
           and (.command | split("/") | .[-3]) == "adapters") | not
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
  # Wire adapter bash guards (full profile only). Each entry uses "Bash" matcher.
  ( if $profile == "full" then
      reduce $bg_guards[] as $bg_cmd (
        .;
        ( [ .hooks.PreToolUse[]? | (.hooks // [])[]? | select(.command == $bg_cmd) ] | length ) as $bg_present |
        if $bg_present == 0 then
          .hooks.PreToolUse += [{"matcher": "Bash", "hooks": [{"type": "command", "command": $bg_cmd}]}]
        else . end
      )
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
  ( if $ctx_inject_present == 0 then
      .hooks.UserPromptSubmit += [{"hooks": [{"type": "command", "command": $ctx_inject, "timeout": $ctx_inject_timeout}]}]
    else . end
  ) |
  ( if $sl_present == 0 then
      .statusLine = {"type": "command", "command": $statusline}
    else . end
  )
  ' > "$tmp_new" < "$settings"

# --- Permissions merge for reviewer subagents ---
# Reviewer subagents spawned by pr-gate need Edit(.gate-results) and Bash(pmctl guard check)
# to write results and run guard checks. Workspace root detection is shared with
# uninstall-guards.sh via runtime/lib/gate-workspace.sh.
_workspace_root="$(gate_workspace_root "$repo_root" "$HOME")"
_gate_glob="${_workspace_root}/**/.gate-results/**"

# pmctl is installed as a symlink under the bin dir; an in-session reviewer
# subagent whose PATH lacks that dir invokes pmctl by absolute path. Allow the
# bare, absolute, and tilde forms of the guard check so the call is permitted
# however pmctl resolves (mirrors the dispatch.sh abs+tilde discipline).
_pmctl_bin_dir="${PMCTL_BIN_DIR:-$HOME/.local/bin}"
_pmctl_guard_abs="Bash(${_pmctl_bin_dir}/pmctl guard check:*)"
_pmctl_guard_tilde=""
[[ "${_pmctl_bin_dir#"$HOME/"}" != "$_pmctl_bin_dir" ]] && \
  _pmctl_guard_tilde="Bash(~/${_pmctl_bin_dir#"$HOME/"}/pmctl guard check:*)"

_tmp_perms="$(mktemp)"
trap 'rm -f "$tmp_new" "$_tmp_perms"' EXIT
if ! jq \
  --arg edit_perm "Edit(${_gate_glob})" \
  --arg legacy_write_perm "Write(${_gate_glob})" \
  --arg bash_guard "Bash(pmctl guard check:*)" \
  --arg bash_guard_abs "$_pmctl_guard_abs" \
  --arg bash_guard_tilde "$_pmctl_guard_tilde" \
  --arg bash_mkdir "Bash(mkdir -p:*)" \
  '
  .permissions //= {} |
  .permissions.allow //= [] |
  # Claude settings accepts Edit path permissions. Remove the legacy Write
  # spelling during upgrade instead of preserving an invalid managed entry.
  .permissions.allow |= map(select(. != $legacy_write_perm)) |
  ([$edit_perm, $bash_guard, $bash_guard_abs, $bash_guard_tilde, $bash_mkdir]
    | map(select(. != ""))) as $required |
  .permissions.allow |= (
    . as $existing |
    . + ($required | map(select(. as $p | ($existing | map(select(. == $p)) | length) == 0)))
  )
  ' "$tmp_new" > "$_tmp_perms"; then
  echo "install-guards: ERROR: failed to merge permissions.allow — check that $settings is valid JSON" >&2
  exit 2
fi
mv "$_tmp_perms" "$tmp_new"
trap 'rm -f "$tmp_new"' EXIT

echo "install-guards: profile=$PROFILE"
echo "install-guards: platform=$PLATFORM"
echo "install-guards: gate-results glob: $_gate_glob"

if cmp -s "$settings" "$tmp_new"; then
  echo "install-guards: already wired, nothing to do (profile=$PROFILE)"
  exit 0
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "install-guards: would apply the following change:"
  diff -u "$settings" "$tmp_new" || true
  exit 0
fi

# Routing-log migration is manual: run ops/migrations/migrate-routing-to-events.sh
# to move legacy routing_log.md records into state-store events.jsonl.

backup="$settings.bak.$(date +%Y%m%d-%H%M%S)"
cp "$settings" "$backup"
mv "$tmp_new" "$settings"
trap - EXIT
echo "install-guards: wrote $settings"
echo "install-guards: backup at $backup"
