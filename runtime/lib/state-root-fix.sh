#!/usr/bin/env bash
# state-root-fix.sh — tell, at install time, that the state root will be refused, and offer to move it.
#
# The canonical writer refuses a state root another principal can write to (issue #592). On a host where the
# default location inherits such a grant (a native Windows profile with a Codex sandbox account, for example), every
# state-writing pmctl command would stop, so install says so and, when asked, points PM_DISPATCH_STATE_ROOT at a new
# directory only the user can write. It never changes the ACL of an existing directory and never turns the check off.
#
# Sourcing this file only defines functions.

# jq: install.sh loads runtime/lib/jq-lf.sh before it sources this library, and a definition here must never replace
# that fuller function (CC-648). Only a library sourced on its own (a test fixture) and without a jq function adds -b.
if ! declare -F jq >/dev/null 2>&1; then
  # CC-594: native Windows jq writes CRLF to a pipe/file; -b keeps LF (see runtime/lib/jq-lf.sh)
  case "${OSTYPE:-}" in msys*|cygwin*) if type -P jq >/dev/null 2>&1; then jq() { command jq -b "$@"; }; fi ;; esac
fi

# state_root_unsafe_reason <repo-root>
#   Prints "<store root>: <reasons>" and returns 0 when the effective state root is rejected; returns 1 when it is
#   safe or cannot be inspected. Read-only.
state_root_unsafe_reason() {
  local repo="$1" pmctl status
  pmctl="$repo/cli/pmctl"
  [[ -x "$pmctl" ]] || return 1
  status="$("$pmctl" state status --json --cd "$repo" 2>/dev/null)" || return 1
  [[ "$(jq -r 'if .safe_root == false then "false" else "true" end' <<<"$status" 2>/dev/null)" == "false" ]] || return 1
  jq -r '"\(.store_root): \((.safe_root_reasons // []) | join("; "))"' <<<"$status" 2>/dev/null
}

# state_root_private_dir — where the repair puts the state root.
state_root_private_dir() { printf '%s\n' "${PM_DISPATCH_PRIVATE_STATE_ROOT:-$HOME/.pm-dispatch-state}"; }

# state_root_fix <repo-root>
#   Creates the private directory (owner-only), checks the canonical guard accepts it, and on native Windows records
#   it as the user's PM_DISPATCH_STATE_ROOT. Elsewhere it prints the line to add to a shell profile. Returns 0 on
#   success, 1 when the directory could not be made safe (nothing is persisted then).
state_root_fix() {
  local repo="$1" dir check
  dir="$(state_root_private_dir)"
  if [[ -e "$dir" && ! -d "$dir" ]]; then
    printf 'install: %s exists and is not a directory; not touching it\n' "$dir" >&2; return 1
  fi
  if [[ ! -d "$dir" ]]; then
    mkdir -p "$dir" || return 1
    case "${OSTYPE:-}" in
      msys*|cygwin*)
        # SIDs for SYSTEM and Administrators, so this also works on a localized Windows. A new directory only:
        # an existing one is checked, never re-permissioned.
        icacls "$(cygpath -w "$dir")" /inheritance:r /grant:r "$USERNAME:(OI)(CI)F" "*S-1-5-18:(OI)(CI)F" "*S-1-5-32-544:(OI)(CI)F" >/dev/null || return 1 ;;
      *) chmod 700 "$dir" || return 1 ;;
    esac
  fi
  check="$(PM_DISPATCH_STATE_ROOT="$dir" "$repo/cli/pmctl" state status --json --cd "$repo" 2>/dev/null | jq -r 'if .safe_root == true then "safe" else (.safe_root_reasons // [] | join("; ")) end' 2>/dev/null)" || check="not inspected"
  if [[ "$check" != safe ]]; then
    printf 'install: %s is not accepted as a state root (%s); nothing was changed\n' "$dir" "$check" >&2; return 1
  fi
  case "${OSTYPE:-}" in
    msys*|cygwin*)
      # A user-level variable: every new terminal, Claude Code and Codex session picks it up. Written as a POSIX path
      # (docs/platform-support.md); MSYS must not rewrite it into a Windows path on the way to setx.
      MSYS2_ARG_CONV_EXCL='*' setx.exe PM_DISPATCH_STATE_ROOT "$dir" >/dev/null || return 1
      printf 'install: state root set to %s (user environment variable PM_DISPATCH_STATE_ROOT).\n' "$dir"
      printf '         Restart open terminals, Claude Code and Codex so they see it.\n' ;;
    *)
      printf 'install: %s is ready. Add to your shell profile, then open a new shell:\n' "$dir"
      printf '         export PM_DISPATCH_STATE_ROOT="%s"\n' "$dir" ;;
  esac
}

# state_root_install_preflight <repo-root> <fix: 1|0>
#   For install.sh, before it changes anything. Silent when the state root is fine. Otherwise prints what is wrong and
#   acts on the answer: --fix-state-root repairs it without asking; a person at a terminal chooses y (use the private
#   directory), n (install anyway, unchanged) or c (cancel). A scripted install only warns and goes on. Returns 1 only
#   when the person cancels.
state_root_install_preflight() {
  local repo="$1" fix="${2:-0}" reason answer=""
  reason="$(state_root_unsafe_reason "$repo")" || return 0
  printf '
WARNING: the pmctl state root is rejected, so pmctl task, dispatch, gate and the other state-writing
'
  printf '         commands will refuse to run until it is changed:
         %s
' "$reason"
  if [[ "$fix" -ne 1 && -t 0 && -t 1 ]]; then
    printf 'Use %s (writable only by you) as the state root?
' "$(state_root_private_dir)"
    printf '  y = yes, create it and install   n = install without changing it   c = cancel the install [y/n/c] '
    read -r answer || answer=c
    case "$answer" in
      [yY]*) fix=1 ;;
      [nN]*) ;;
      *) return 1 ;;
    esac
  fi
  if [[ "$fix" -eq 1 ]]; then
    state_root_fix "$repo" || printf 'install: the state root was not changed; see docs/platform-support.md
' >&2
  else
    printf 'Fix: re-run with --fix-state-root to use %s, or set PM_DISPATCH_STATE_ROOT to a directory only you can
' "$(state_root_private_dir)"
    printf '     write (docs/platform-support.md). The check is not turned off.
'
  fi
  return 0
}
