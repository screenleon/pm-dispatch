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

# state_root_is_interactive — true when a person can answer a prompt. A function so a test can stand in for a terminal.
state_root_is_interactive() { [[ -t 0 && -t 1 ]]; }

# state_root_private_dir — where the repair puts the state root.
state_root_private_dir() { printf '%s\n' "${PM_DISPATCH_PRIVATE_STATE_ROOT:-$HOME/.pm-dispatch-state}"; }

# state_root_create_private_windows <dir>
#   Native Windows only. Creates <dir> with its protected owner/SYSTEM/Administrators DACL supplied at creation
#   (Win32 CreateDirectoryW with a security descriptor), in one step. A mkdir followed by icacls would leave a window in
#   which the directory carries whatever its parent grants (a Codex sandbox group, for example) and another principal
#   could plant files in it that the later ACL change does not remove. CreateDirectoryW also fails when the leaf already
#   exists, as a directory or a junction, so permissions only ever apply to a directory this call made. Fails closed:
#   without a working PowerShell nothing is created.
#   The grant goes to the SID of the account this process actually runs as (whoami /user), not the $USERNAME profile
#   name: a sandboxed or service session can run as a different account than its profile's, and the canonical guard
#   rejects a grant to anyone but the owner. SYSTEM and Administrators are by SID, so this works on a localized Windows.
state_root_create_private_windows() {
  local dir="$1" sysdir me ps
  sysdir="$(cygpath -u "${SYSTEMROOT:-C:\\Windows}")/System32"
  me="$(MSYS2_ARG_CONV_EXCL='*' "$sysdir/whoami.exe" /user /fo csv /nh 2>/dev/null | cut -d, -f2 | tr -d '"\r')"
  ps="$sysdir/WindowsPowerShell/v1.0/powershell.exe"
  if [[ "$me" != S-1-* || ! -x "$ps" ]]; then
    printf 'install: cannot create a protected directory here (account SID or PowerShell not found); nothing was changed\n' >&2
    return 1
  fi
  local script
  read -r -d '' script <<'PWSH' || true
$ErrorActionPreference = 'Stop'
Add-Type -TypeDefinition @"
using System; using System.Runtime.InteropServices;
public static class PmDir {
  [StructLayout(LayoutKind.Sequential)] public struct SA { public int n; public IntPtr d; public int inh; }
  [DllImport("advapi32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
  static extern bool ConvertStringSecurityDescriptorToSecurityDescriptorW(string s, uint rev, out IntPtr sd, IntPtr len);
  [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
  static extern bool CreateDirectoryW(string p, ref SA sa);
  public static int Make(string path, string sddl) {
    IntPtr sd;
    if (!ConvertStringSecurityDescriptorToSecurityDescriptorW(sddl, 1, out sd, IntPtr.Zero)) return Marshal.GetLastWin32Error();
    SA sa = new SA(); sa.n = Marshal.SizeOf(typeof(SA)); sa.d = sd; sa.inh = 0;
    return CreateDirectoryW(path, ref sa) ? 0 : Marshal.GetLastWin32Error();
  }
}
"@
$sid = $env:PM_MKDIR_SID
if ($sid -notmatch '^S-1-[0-9-]+$') { throw 'bad SID' }
$rc = [PmDir]::Make($env:PM_MKDIR_PATH, "D:P(A;OICI;FA;;;$sid)(A;OICI;FA;;;SY)(A;OICI;FA;;;BA)")
if ($rc -ne 0) { throw "CreateDirectoryW failed: win32 error $rc" }
PWSH
  # The script travels in an environment variable and failure is an exception (exit status 1), not a script exit code,
  # which a piped PowerShell does not report reliably. The directory is then checked to exist before it is trusted.
  PM_MKDIR_SCRIPT="$script" PM_MKDIR_PATH="$(cygpath -w "$dir")" PM_MKDIR_SID="$me" "$ps" -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command '& ([scriptblock]::Create($env:PM_MKDIR_SCRIPT))' >/dev/null || return 1
  [[ -d "$dir" ]] || return 1
}

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
    # Exclusive creation: mkdir without -p fails if another actor made the leaf (or a link to some directory) after the
    # check above, so permissions are only ever applied to a directory this call created. Owner-only from creation.
    mkdir -p "$(dirname "$dir")" || return 1
    case "${OSTYPE:-}" in
      # A new directory only: an existing one is checked, never re-permissioned.
      msys*|cygwin*) state_root_create_private_windows "$dir" || return 1 ;;
      *) ( umask 077; mkdir "$dir" ) || return 1; chmod 700 "$dir" || return 1 ;;
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
  if [[ "$fix" -ne 1 ]] && state_root_is_interactive; then
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
