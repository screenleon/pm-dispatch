#!/usr/bin/env bash
# Canonical and compatibility hook identities owned by the Codex host.

codex_host_command_guard_path() {
  local repo_root="$1"
  printf '%s/hosts/codex/hooks/command-guard.sh\n' "$repo_root"
}

codex_host_command_guard_legacy_path() {
  local repo_root="$1"
  printf '%s/scripts/hook-codex-command-guard.sh\n' "$repo_root"
}

# codex_host_managed_hook_forms <repo_root>
# Every command string that this checkout's installer can have written to Codex's hooks.json, as one JSON
# object {"guard":[...],"memory":[...],"session":[...]}: the canonical and the pre-rename legacy script of each
# hook, each in the three spellings the installer has used -- the plain path, the `printf %q` shell-escaped one
# (POSIX) and the PowerShell-safe `bash '<path>'` one (native Windows). The session summary hook is retired
# and only ever recognised for removal; it carries the ` --host codex` argument.
#
# The installer (to find the entries of a previous checkout it replaces) and the uninstaller (to remove what
# was installed) both take their lists from here, so a spelling added in one place is known to the other.
# Needs runtime/lib/portable.sh (portable_bash_wrapped_command) loaded by the caller. Matching against the
# result is by exact equality, never by prefix or substring.
codex_host_managed_hook_forms() {
  local repo_root="$1" p
  local -a guard=() memory=() session=()
  for p in "$repo_root/hosts/codex/hooks/command-guard.sh" "$repo_root/scripts/hook-codex-command-guard.sh"; do
    guard+=("$p" "$(printf '%q' "$p")" "$(portable_bash_wrapped_command "$p")")
  done
  for p in "$repo_root/runtime/hooks/guard-inject-memory.sh" "$repo_root/scripts/guard-inject-memory.sh"; do
    memory+=("$p" "$(printf '%q' "$p")" "$(portable_bash_wrapped_command "$p")")
  done
  p="$repo_root/runtime/hooks/guard-session-summary.sh"
  session+=("$p --host codex" "$(printf '%q' "$p") --host codex" "$(portable_bash_wrapped_command "$p") --host codex")
  jq -nc --argjson g "$(jq -nc '$ARGS.positional' --args "${guard[@]}")" \
    --argjson m "$(jq -nc '$ARGS.positional' --args "${memory[@]}")" \
    --argjson s "$(jq -nc '$ARGS.positional' --args "${session[@]}")" \
    '{guard:$g,memory:$m,session:$s}'
}
