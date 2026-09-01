#!/usr/bin/env bash
# shellcheck disable=SC1091
# Idempotently splice the pm-dispatch codex-host command guard into
# $CODEX_HOME/hooks.json (default ~/.codex/hooks.json).
#
# Host-generic counterpart of install-guards.sh (claude host), driven by
# hosts/codex/host.yaml's install_targets (id: hooks) and guard_bindings
# (command_guard) instead of hardcoding the path/format here — see
# runtime/lib/host-manifest.sh and docs/host-contract.md. Wires exactly one
# command guard plus the host-neutral canonical-memory UserPromptSubmit adapter.
#
# Usage:
#   hosts/codex/bin/install.sh --repo-root <checkout>           # apply
#   hosts/codex/bin/install.sh --repo-root <checkout> --dry-run # preview

set -euo pipefail

DRY_RUN=0
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT=""
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --repo-root)
      [[ "$#" -ge 2 ]] || { echo "install-guards-codex: --repo-root requires a value" >&2; exit 2; }
      REPO_ROOT="$2"; shift 2 ;;
    *) echo "install-guards-codex: unknown argument: $1 (usage: install-guards-codex.sh [--repo-root <absolute-path>] [--dry-run])" >&2; exit 2 ;;
  esac
done
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd -P)"
else
  case "$REPO_ROOT" in
    /*) ;;
    *) echo "install-guards-codex: --repo-root must be absolute" >&2; exit 2 ;;
  esac
  REPO_ROOT="$(cd "$REPO_ROOT" 2>/dev/null && pwd -P)" || {
    echo "install-guards-codex: --repo-root does not exist" >&2
    exit 2
  }
fi
[[ -f "$REPO_ROOT/hosts/codex/host.yaml" && -f "$REPO_ROOT/runtime/lib/host-manifest.sh" ]] || {
  echo "install-guards-codex: --repo-root is not a compatible pm-dispatch checkout: $REPO_ROOT" >&2
  exit 2
}

# shellcheck source=runtime/lib/host-manifest.sh
. "$REPO_ROOT/runtime/lib/host-manifest.sh"
# shellcheck source=runtime/lib/portable.sh
. "$REPO_ROOT/runtime/lib/portable.sh"
# shellcheck source=hosts/codex/lib/hook-paths.sh
. "$REPO_ROOT/hosts/codex/lib/hook-paths.sh"
# shellcheck source=hosts/codex/lib/memory-contract.sh
. "$REPO_ROOT/hosts/codex/lib/memory-contract.sh"

if ! command -v jq >/dev/null 2>&1; then
  echo "install-guards-codex: jq is required but not found on PATH" >&2
  exit 2
fi

manifest="$(host_manifest_file "$REPO_ROOT" codex)"
if [[ ! -f "$manifest" ]]; then
  echo "install-guards-codex: missing hosts/codex/host.yaml — nothing to wire" >&2
  exit 2
fi

hooks_path_template=""
instructions_path_template=""
while IFS=$'\t' read -r id path fmt managed; do
  [[ "$managed" == "true" ]] || continue
  if [[ "$id" == "hooks" && "$fmt" == "codex-hooks-json" ]]; then
    hooks_path_template="$path"
  elif [[ "$id" == "instructions" && "$fmt" == "codex-agents-md" ]]; then
    instructions_path_template="$path"
  fi
done < <(host_manifest_install_targets "$manifest")

if [[ -z "$hooks_path_template" ]]; then
  echo "install-guards-codex: hosts/codex/host.yaml has no managed codex-hooks-json install_target — nothing to wire" >&2
  exit 2
fi
if [[ -z "$instructions_path_template" ]]; then
  echo "install-guards-codex: hosts/codex/host.yaml has no managed codex-agents-md install_target — nothing to wire" >&2
  exit 2
fi

hooks_file="$(host_manifest_expand_path "$REPO_ROOT" codex "$hooks_path_template")"
instructions_file="$(host_manifest_expand_path "$REPO_ROOT" codex "$instructions_path_template")"
hook_cmd="$(codex_host_command_guard_path "$REPO_ROOT")"
legacy_hook_cmd="$(codex_host_command_guard_legacy_path "$REPO_ROOT")"
memory_hook_cmd="$REPO_ROOT/runtime/hooks/guard-inject-memory.sh"
legacy_memory_hook_cmd="$REPO_ROOT/scripts/guard-inject-memory.sh"
# session_lifecycle is retired (the Stop skeleton writer stayed empty). This
# path string is kept only so the jq transform below can still prune a
# previously wired session hook from an existing hooks.json — no new
# registration is written. The scripts/-prefixed pre-rename form is not
# tracked here: session_lifecycle was only ever wired at the current
# runtime/hooks/ path, so there is no pre-rename install to migrate away from.
session_hook_cmd="$REPO_ROOT/runtime/hooks/guard-session-summary.sh"
memory_update_module="$(host_manifest_scalar "$manifest" memory_update_module)"
if [[ -z "$memory_update_module" || "$memory_update_module" == "null" ]]; then
  echo "install-guards-codex: hosts/codex/host.yaml has no memory_update_module" >&2
  exit 2
fi
memory_update_cmd="$REPO_ROOT/$memory_update_module"

if [[ ! -x "$hook_cmd" || ! -x "$memory_hook_cmd" || ! -x "$memory_update_cmd" ]]; then
  echo "install-guards-codex: managed hook missing or not executable" >&2
  exit 2
fi

# Codex invokes hook commands through PowerShell on native Windows. Route the
# POSIX script path through Git Bash as one quoted argument; a bare /c/... path
# or Bash backslash escaping is not executable by PowerShell.
codex_hook_command() {
  local path="$1"
  if [[ "$(detect_platform)" == "windows" ]]; then
    portable_bash_wrapped_command "$path"
  else
    printf '%q' "$path"
  fi
}

hook_cmd_q="$(codex_hook_command "$hook_cmd")"
legacy_hook_cmd_q="$(codex_hook_command "$legacy_hook_cmd")"
memory_hook_cmd_q="$(codex_hook_command "$memory_hook_cmd")"
session_hook_cmd_q="$(printf '%q' "$session_hook_cmd") --host codex"
legacy_memory_hook_cmd_q="$(codex_hook_command "$legacy_memory_hook_cmd")"
memory_update_cmd_q="$(printf '%q' "$memory_update_cmd")"

tmp_new="$(mktemp)"
tmp_current="$(mktemp)"
tmp_instructions_new="$(mktemp)"
tmp_instructions_current="$(mktemp)"
trap 'rm -f "$tmp_new" "$tmp_current" "$tmp_instructions_new" "$tmp_instructions_current"' EXIT

if [[ -f "$hooks_file" ]]; then
  cp "$hooks_file" "$tmp_current"
else
  printf '{}\n' > "$tmp_current"
  [[ "$DRY_RUN" -eq 1 ]] && echo "install-guards-codex: would create $hooks_file"
fi

# A cross-checkout refresh needs stronger evidence than a basename match: only
# treat a command as managed when its former root is still a compatible
# pm-dispatch checkout. Foreign lookalikes at arbitrary paths remain untouched.
# Commands written by this installer use `printf %q`; decode only that simple
# backslash-escaped first word here.  This deliberately is not `eval`: hook
# configuration is user-controlled, so discovery must never execute it.  Bash
# switches `%q` to ANSI-C `$'...'` syntax for control characters; reject that
# uncommon form fail-closed rather than growing a shell parser.
codex_hook_command_word() {
  local input="$1" output="" char escaped=0 i
  [[ "$input" != \$\'* ]] || return 1
  for ((i = 0; i < ${#input}; i++)); do
    char="${input:i:1}"
    if [[ "$escaped" -eq 1 ]]; then
      output+="$char"
      escaped=0
    elif [[ "$char" == "\\" ]]; then
      escaped=1
    elif [[ "$char" == " " || "$char" == $'\t' || "$char" == $'\n' ]]; then
      break
    elif [[ "$char" == "'" || "$char" == '"' ]]; then
      return 1
    else
      output+="$char"
    fi
  done
  [[ "$escaped" -eq 0 && -n "$output" ]] || return 1
  printf '%s\n' "$output"
}

# codex_hook_command_exact <command>
# Like codex_hook_command_word, but fail-closed unless the WHOLE command is one
# decodable word: a composite command (`<path> && ...`, `<path> --flag`) is
# rejected, never partially matched. Used by the Windows broken-path adoption
# below, where matching a prefix of a foreign composite command would delete
# user configuration.
codex_hook_command_exact() {
  local input="$1" output="" char escaped=0 i
  [[ "$input" != \$\'* ]] || return 1
  for ((i = 0; i < ${#input}; i++)); do
    char="${input:i:1}"
    if [[ "$escaped" -eq 1 ]]; then
      output+="$char"
      escaped=0
    elif [[ "$char" == "\\" ]]; then
      escaped=1
    elif [[ "$char" == " " || "$char" == $'\t' || "$char" == $'\n' || "$char" == "'" || "$char" == '"' ]]; then
      return 1
    else
      output+="$char"
    fi
  done
  [[ "$escaped" -eq 0 && -n "$output" ]] || return 1
  printf '%s\n' "$output"
}

previous_repo_root=""
while IFS= read -r previous_command; do
  # Our own Windows representation is `bash '<literal path>'`; unwrap it before
  # the %q decoder (which rejects quotes fail-closed) so a moved Windows
  # checkout is still recognized as the compatible previous root.
  previous_unwrapped="$(portable_bash_unwrap_command "$previous_command")"
  if [[ "$previous_unwrapped" != "$previous_command" ]]; then
    previous_word="$previous_unwrapped"
  else
    previous_word="$(codex_hook_command_word "$previous_command")" || continue
  fi
  case "$previous_word" in
    */hosts/codex/hooks/command-guard.sh) previous_root="${previous_word%/hosts/codex/hooks/command-guard.sh}" ;;
    */scripts/hook-codex-command-guard.sh) previous_root="${previous_word%/scripts/hook-codex-command-guard.sh}" ;;
    */runtime/hooks/guard-inject-memory.sh) previous_root="${previous_word%/runtime/hooks/guard-inject-memory.sh}" ;;
    */scripts/guard-inject-memory.sh) previous_root="${previous_word%/scripts/guard-inject-memory.sh}" ;;
    */runtime/hooks/guard-session-summary.sh) previous_root="${previous_word%/runtime/hooks/guard-session-summary.sh}" ;;
    *) continue ;;
  esac
  if [[ "$previous_root" != "$REPO_ROOT" && -f "$previous_root/install.sh" \
      && -f "$previous_root/uninstall.sh" && -x "$previous_root/cli/pmctl" ]]; then
    previous_repo_root="$previous_root"
    break
  fi
done < <(jq -r '.. | objects | .command? // empty' < "$tmp_current")

previous_hook_cmd_q=""
previous_legacy_hook_cmd_q=""
previous_memory_hook_cmd_q=""
previous_legacy_memory_hook_cmd_q=""
previous_session_hook_cmd_q=""
previous_hook_cmd_w=""
previous_legacy_hook_cmd_w=""
previous_memory_hook_cmd_w=""
previous_legacy_memory_hook_cmd_w=""
if [[ -n "$previous_repo_root" ]]; then
  previous_hook_cmd_q="$(printf '%q' "$previous_repo_root/hosts/codex/hooks/command-guard.sh")"
  previous_legacy_hook_cmd_q="$(printf '%q' "$previous_repo_root/scripts/hook-codex-command-guard.sh")"
  previous_memory_hook_cmd_q="$(printf '%q' "$previous_repo_root/runtime/hooks/guard-inject-memory.sh")"
  previous_legacy_memory_hook_cmd_q="$(printf '%q' "$previous_repo_root/scripts/guard-inject-memory.sh")"
  previous_session_hook_cmd_q="$(printf '%q' "$previous_repo_root/runtime/hooks/guard-session-summary.sh") --host codex"
  # A previous Windows install stored the wrapped representation; recognize it
  # too so a moved checkout is replaced, never duplicated.
  previous_hook_cmd_w="$(portable_bash_wrapped_command "$previous_repo_root/hosts/codex/hooks/command-guard.sh")"
  previous_legacy_hook_cmd_w="$(portable_bash_wrapped_command "$previous_repo_root/scripts/hook-codex-command-guard.sh")"
  previous_memory_hook_cmd_w="$(portable_bash_wrapped_command "$previous_repo_root/runtime/hooks/guard-inject-memory.sh")"
  previous_legacy_memory_hook_cmd_w="$(portable_bash_wrapped_command "$previous_repo_root/scripts/guard-inject-memory.sh")"
fi

# Pre-fix Windows installs wrote raw or %q POSIX paths that PowerShell could
# never launch. Collect the EXACT command strings to adopt-and-rewrite:
# Windows only, the whole command must decode to a single word with the managed
# suffix, and the path must either belong to this checkout or no longer exist
# on disk (a dead entry). A foreign composite command, or a foreign checkout
# whose script still exists, is never adopted — exact strings, no substring
# matching, so user configuration cannot be silently deleted.
broken_guard_cmds_json='[]'
broken_memory_cmds_json='[]'
if [[ "$(detect_platform)" == "windows" ]]; then
  while IFS= read -r broken_candidate; do
    broken_word="$(portable_bash_unwrap_command "$broken_candidate")"
    if [[ "$broken_word" == "$broken_candidate" ]]; then
      broken_word="$(codex_hook_command_exact "$broken_candidate")" || continue
    fi
    case "$broken_word" in
      */hosts/codex/hooks/command-guard.sh)
        broken_root="${broken_word%/hosts/codex/hooks/command-guard.sh}"
        [[ "$broken_root" == "$REPO_ROOT" || ! -e "$broken_word" ]] || continue
        broken_guard_cmds_json="$(jq -c --arg c "$broken_candidate" '. + [$c]' <<< "$broken_guard_cmds_json")"
        ;;
      */runtime/hooks/guard-inject-memory.sh)
        broken_root="${broken_word%/runtime/hooks/guard-inject-memory.sh}"
        [[ "$broken_root" == "$REPO_ROOT" || ! -e "$broken_word" ]] || continue
        broken_memory_cmds_json="$(jq -c --arg c "$broken_candidate" '. + [$c]' <<< "$broken_memory_cmds_json")"
        ;;
    esac
  done < <(jq -r '.. | objects | .command? // empty' < "$tmp_current")
fi

# Merge idempotently: only append the managed hook entry if no existing
# PreToolUse/Bash entry already points at this repo's guard script.
MSYS2_ARG_CONV_EXCL='*' MSYS_NO_PATHCONV=1 jq --arg cmd "$hook_cmd_q" --arg legacy_cmd "$legacy_hook_cmd" --arg legacy_cmd_q "$legacy_hook_cmd_q" \
  --arg memory_cmd "$memory_hook_cmd_q" --arg session_cmd "$session_hook_cmd_q" \
  --arg legacy_memory_cmd "$legacy_memory_hook_cmd" --arg legacy_memory_cmd_q "$legacy_memory_hook_cmd_q" \
  --arg previous_hook_cmd_q "$previous_hook_cmd_q" --arg previous_legacy_hook_cmd_q "$previous_legacy_hook_cmd_q" \
  --arg previous_memory_hook_cmd_q "$previous_memory_hook_cmd_q" --arg previous_legacy_memory_hook_cmd_q "$previous_legacy_memory_hook_cmd_q" \
  --arg previous_session_hook_cmd_q "$previous_session_hook_cmd_q" \
  --arg previous_hook_cmd_w "$previous_hook_cmd_w" --arg previous_legacy_hook_cmd_w "$previous_legacy_hook_cmd_w" \
  --arg previous_memory_hook_cmd_w "$previous_memory_hook_cmd_w" --arg previous_legacy_memory_hook_cmd_w "$previous_legacy_memory_hook_cmd_w" \
  --argjson broken_guard_cmds "$broken_guard_cmds_json" \
  --argjson broken_memory_cmds "$broken_memory_cmds_json" '
  # Exact command strings the Windows adoption pre-pass verified as this
  # checkout'\''s own (or dead) pre-fix representations — membership only,
  # never substring matching.
  def broken_windows_guard:
    ($broken_guard_cmds | index(.)) != null;
  def broken_windows_memory:
    ($broken_memory_cmds | index(.)) != null;
  def managed_guard:
    . == $cmd or . == $legacy_cmd or . == $legacy_cmd_q or
    broken_windows_guard or
    ($previous_hook_cmd_q != "" and
      (. == $previous_hook_cmd_q or . == $previous_legacy_hook_cmd_q or
       . == $previous_hook_cmd_w or . == $previous_legacy_hook_cmd_w));
  def managed_memory:
    . == $memory_cmd or . == $legacy_memory_cmd or . == $legacy_memory_cmd_q or
    broken_windows_memory or
    ($previous_memory_hook_cmd_q != "" and
      (. == $previous_memory_hook_cmd_q or . == $previous_legacy_memory_hook_cmd_q or
       . == $previous_memory_hook_cmd_w or . == $previous_legacy_memory_hook_cmd_w));
  def managed_session:
    . == $session_cmd or
    ($previous_session_hook_cmd_q != "" and . == $previous_session_hook_cmd_q);
  .hooks = (.hooks // {}) |
  .hooks.PreToolUse = (.hooks.PreToolUse // []) |
  .hooks.UserPromptSubmit = (.hooks.UserPromptSubmit // []) |
  .hooks.Stop = (.hooks.Stop // []) |
  .hooks.PreToolUse |= map(
    if (.hooks | type) == "array" then
      .hooks |= map(select((.command | managed_guard) | not))
    else . end
  ) |
  .hooks.PreToolUse |= map(select((.hooks // [] | length) > 0)) |
  .hooks.UserPromptSubmit |= map(
    if (.hooks | type) == "array" then
      .hooks |= map(select((.command | managed_memory) | not))
    else . end
  ) |
  .hooks.UserPromptSubmit |= map(select((.hooks // [] | length) > 0)) |
  .hooks.Stop |= map(
    if (.hooks | type) == "array" then
      .hooks |= map(select((.command | managed_session) | not))
    else . end
  ) |
  .hooks.Stop |= map(select((.hooks // [] | length) > 0)) |
  ([.hooks.PreToolUse[]? | select(.matcher == "Bash") | .hooks[]?.command] | index($cmd)) as $already |
  (if $already != null then . else .hooks.PreToolUse += [{"matcher": "Bash", "hooks": [{"type": "command", "command": $cmd}]}] end) |
  ([.hooks.UserPromptSubmit[]? | .hooks[]?.command] | index($memory_cmd)) as $memory_already |
  if $memory_already != null then . else .hooks.UserPromptSubmit += [{"hooks": [{"type": "command", "command": $memory_cmd}]}] end
' < "$tmp_current" > "$tmp_new"

if [[ -f "$instructions_file" ]]; then
  cp "$instructions_file" "$tmp_instructions_current"
else
  : > "$tmp_instructions_current"
  [[ "$DRY_RUN" -eq 1 ]] && echo "install-guards-codex: would create $instructions_file"
fi

if ! codex_memory_contract_strip "$tmp_instructions_current" "$tmp_instructions_new"; then
  echo "install-guards-codex: malformed managed markers in $instructions_file — refusing to modify" >&2
  exit 2
fi
codex_memory_contract_append "$tmp_instructions_new" "$memory_update_cmd_q" "$REPO_ROOT"

hooks_changed=0
instructions_changed=0
cmp -s "$tmp_current" "$tmp_new" || hooks_changed=1
cmp -s "$tmp_instructions_current" "$tmp_instructions_new" || instructions_changed=1
if [[ "$hooks_changed" -eq 0 && "$instructions_changed" -eq 0 ]]; then
  echo "install-guards-codex: already wired, nothing to do"
  exit 0
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
  if [[ "$hooks_changed" -eq 1 ]]; then
    echo "install-guards-codex: would apply the following change to $hooks_file:"
    diff -u "$tmp_current" "$tmp_new" || true
  fi
  if [[ "$instructions_changed" -eq 1 ]]; then
    echo "install-guards-codex: would apply the following change to $instructions_file:"
    diff -u "$tmp_instructions_current" "$tmp_instructions_new" || true
  fi
  exit 0
fi

mkdir -p "$(dirname "$hooks_file")"
mkdir -p "$(dirname "$instructions_file")"
[[ -f "$hooks_file" ]] || printf '{}\n' > "$hooks_file"

timestamp="$(date +%Y%m%d-%H%M%S)"
if [[ "$hooks_changed" -eq 1 ]]; then
  backup="$hooks_file.bak.$timestamp"
  cp "$hooks_file" "$backup"
  mv "$tmp_new" "$hooks_file"
  echo "install-guards-codex: wrote $hooks_file"
  echo "install-guards-codex: backup at $backup"
fi
if [[ "$instructions_changed" -eq 1 ]]; then
  if [[ -f "$instructions_file" ]]; then
    instructions_backup="$instructions_file.bak.$timestamp"
    cp "$instructions_file" "$instructions_backup"
    echo "install-guards-codex: backup at $instructions_backup"
  fi
  mv "$tmp_instructions_new" "$instructions_file"
  echo "install-guards-codex: wrote $instructions_file"
fi
trap - EXIT
