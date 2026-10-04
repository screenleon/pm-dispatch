#!/usr/bin/env bash
# Native Windows (Git Bash) acceptance run for the experimental local-use
# platform exception and bounded Windows CI smoke. Exercises native behavior:
# it installs both hosts into throwaway config roots, launches every wired
# hook command through the real PowerShell hook runner, and reports whether
# link_or_copy produced a native symlink or fell back to copy.
#
# Run ON the Windows machine, from the checkout root, in Git Bash:
#   bash ops/diagnostics/windows-acceptance.sh
# Exit 0 = all acceptance checks passed; 1 = at least one failed;
# 2 = not a native Windows Git Bash environment (nothing was run).
#
# Nothing outside mktemp-created config roots is touched — the user's real
# ~/.claude and ~/.codex are never read or written.
set -uo pipefail

# CC-594: native Windows jq writes CRLF to a pipe/file; -b keeps LF (see runtime/lib/jq-lf.sh)
case "${OSTYPE:-}" in msys*|cygwin*) if type -P jq >/dev/null 2>&1; then jq() { command jq -b "$@"; }; fi ;; esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
# shellcheck source=runtime/lib/portable.sh
# shellcheck disable=SC1091 # CI shellcheck runs without -x; path resolved from this entrypoint.
. "$REPO_ROOT/runtime/lib/portable.sh"

if [[ "$(detect_platform)" != "windows" ]]; then
  echo "windows-acceptance: not a native Windows Git Bash environment (detect_platform=$(detect_platform)); nothing to do" >&2
  exit 2
fi
if ! command -v powershell.exe >/dev/null 2>&1; then
  echo "windows-acceptance: powershell.exe not on PATH — cannot exercise the hook runner" >&2
  exit 2
fi

pass_count=0
fail_count=0
skip_count=0
report() {
  local status="$1" name="$2" detail="${3:-}"
  if [[ "$status" == PASS ]]; then
    pass_count=$((pass_count + 1))
    printf 'PASS: %s%s\n' "$name" "${detail:+ ($detail)}"
  elif [[ "$status" == SKIP ]]; then
    skip_count=$((skip_count + 1))
    printf 'SKIP: %s%s\n' "$name" "${detail:+ ($detail)}"
  else
    fail_count=$((fail_count + 1))
    printf 'FAIL: %s%s\n' "$name" "${detail:+ — $detail}"
  fi
}

work_base="$(mktemp -d)" || exit 1
work="$work_base/native smoke"
mkdir -p "$work/home" "$work/tmp" "$work/state"
trap 'rm -rf -- "$work_base"' EXIT
# Every child (including PowerShell-launched hooks) gets disposable roots.
export HOME="$work/home"
export CLAUDE_CONFIG_DIR="$work/claude-home/.claude"
export CLAUDE_HOME="$CLAUDE_CONFIG_DIR"
export CODEX_HOME="$work/codex-home"
export XDG_CONFIG_HOME="$work/xdg"
export XDG_DATA_HOME="$work/data"
export PM_MEMORY_DIR="$work/memory"
export PM_DISPATCH_STATE_ROOT="$work/state"
export TMPDIR="$work/tmp"
unset OPENAI_API_KEY ANTHROPIC_API_KEY CLAUDE_CODE_OAUTH_TOKEN XAI_API_KEY GROK_API_KEY GROK_HOME
unset PM_DISPATCH_PLATFORM PM_DISPATCH_ALLOW_UNSAFE_STATE_ROOT

for tool in bash git jq sqlite3 powershell.exe; do
  type -P "$tool" || { report FAIL "prerequisite-$tool" "not on PATH"; exit 1; }
done
bash --version | head -1
git --version
jq --version
sqlite3 --version
if [[ "$(sqlite3 :memory: "CREATE VIRTUAL TABLE smoke USING fts5(body); INSERT INTO smoke VALUES ('native smoke'); SELECT count(*) FROM smoke WHERE smoke MATCH 'native';" | tr -d '\r')" == 1 ]]; then
  report PASS "sqlite-fts5"
else
  report FAIL "sqlite-fts5"
fi
if bash "$REPO_ROOT/cli/pmctl" --help > "$work/pmctl-help.log" 2>&1 && [[ -s "$work/pmctl-help.log" ]]; then
  report PASS "pmctl-help"
else
  cat "$work/pmctl-help.log"
  report FAIL "pmctl-help"
fi

# powershell_launch <command-string> <stdin-payload>
# Runs the exact stored hook command through PowerShell the way the hosts do.
# Success = the command started and Bash ran the script (any exit code the
# script chooses); failure = PowerShell could not launch it at all.
powershell_launch() {
  local cmd="$1" payload="$2" out rc
  out="$(printf '%s' "$payload" | MSYS_NO_PATHCONV=1 powershell.exe -NoProfile -NonInteractive -Command "$cmd" 2>&1)"
  rc=$?
  # A command PowerShell cannot resolve or parse never reaches the script.
  if printf '%s' "$out" | grep -qiE 'is not recognized|CommandNotFoundException|ParserError'; then
    return 1
  fi
  return "$rc"
}

# --- 1. Claude host install into a throwaway CLAUDE_CONFIG_DIR ---------------
claude_home="$work/claude-home"
mkdir -p "$claude_home/.claude"
printf '{"permissions":{}}\n' > "$claude_home/.claude/settings.json"
if HOME="$claude_home" CLAUDE_CONFIG_TEST_INSTALL_RUNNING=1 \
    bash "$REPO_ROOT/hosts/claude/bin/install-guards.sh" --profile minimal > "$work/claude-install.log" 2>&1; then
  report PASS "claude-install"
else
  cat "$work/claude-install.log"
  report FAIL "claude-install" "install-guards.sh exited nonzero"
fi

# Launch every wired Claude hook command through PowerShell with a benign
# payload. Hook exit codes other than launch failure are acceptable here —
# acceptance proves PowerShell can start them at all.
if jq -er '[.hooks[]?[]?.hooks[]?.command] + [.statusLine.command // empty] | select(length > 0) | .[]' \
    "$claude_home/.claude/settings.json" > "$work/claude-commands"; then
  report PASS "claude-hook-commands-present"
else
  report FAIL "claude-hook-commands-present" "missing or unreadable hook configuration"
fi
while IFS= read -r cmd; do
  [[ -n "$cmd" ]] || continue
  if powershell_launch "$cmd" '{"tool_input":{"file_path":"/tmp/acceptance-probe"}}'; then
    report PASS "claude-hook-launch" "$cmd"
  else
    report FAIL "claude-hook-launch" "PowerShell could not launch: $cmd"
  fi
done < "$work/claude-commands"

# --- 2. Codex host install into a throwaway CODEX_HOME -----------------------
codex_home="$work/codex-home"
mkdir -p "$codex_home"
if CODEX_HOME="$codex_home" \
    bash "$REPO_ROOT/hosts/codex/bin/install.sh" --repo-root "$REPO_ROOT" > "$work/codex-install.log" 2>&1; then
  report PASS "codex-install"
else
  cat "$work/codex-install.log"
  report FAIL "codex-install" "hosts/codex/bin/install.sh exited nonzero"
fi

guard_cmd="$(jq -r '.hooks.PreToolUse[]? | select(.matcher=="Bash") | .hooks[]?.command' \
  "$codex_home/hooks.json" 2>/dev/null | head -1)"
if [[ -n "$guard_cmd" ]]; then
  if powershell_launch "$guard_cmd" '{"tool_input":{"command":"git status","cwd":"/tmp"}}'; then
    report PASS "codex-guard-launch" "$guard_cmd"
  else
    report FAIL "codex-guard-launch" "PowerShell could not launch: $guard_cmd"
  fi
  # The guard must still DENY a destructive command when launched this way.
  if printf '%s' '{"tool_input":{"command":"rm -rf /tmp/whatever","cwd":"/tmp"}}' \
      | MSYS_NO_PATHCONV=1 powershell.exe -NoProfile -NonInteractive -Command "$guard_cmd" >/dev/null 2>&1; then
    report FAIL "codex-guard-denies" "destructive command was allowed through PowerShell launch"
  else
    report PASS "codex-guard-denies"
  fi
else
  report FAIL "codex-guard-launch" "no PreToolUse Bash guard found in $codex_home/hooks.json"
fi

# --- 3. Native symlink vs copy fallback --------------------------------------
link_src="$work/link-src"
link_dst="$work/link-dst"
printf 'probe\n' > "$link_src"
if _portable_make_symlink "$link_src" "$link_dst" 2>/dev/null && [[ -L "$link_dst" ]]; then
  report PASS "native-symlink" "Developer Mode active, native reparse point created"
else
  rm -f "$link_dst"
  report SKIP "native-symlink" "native symlink creation unavailable; copy mode is tested separately"
fi
# Exercise the product fallback even on runners that support native symlinks.
copy_rc=0
FAKE_SYMLINK_UNSUPPORTED=1 link_or_copy "$link_src" "$work/copy-dst" || copy_rc=$?
# link_or_copy returns 1 for a successful copy, 0 for a link, 3 for failure.
if [[ "$copy_rc" -eq 1 && ! -L "$work/copy-dst" ]] && cmp -s "$link_src" "$work/copy-dst"; then
  report PASS "copy-fallback"
else
  report FAIL "copy-fallback"
fi

# --- 4. A real Windows ACL, state writer and directory-lock round trip -------
# Use a private ACL; never bypass the state writer's unsafe-root check.
# shellcheck disable=SC2016 # PowerShell expands the environment reference.
if PM_DISPATCH_ACL_PATH="$(cygpath -w "$PM_DISPATCH_STATE_ROOT")" \
    powershell.exe -NoProfile -NonInteractive -Command '
      $ErrorActionPreference = "Stop"
      $sid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User
      $acl = New-Object System.Security.AccessControl.DirectorySecurity
      $acl.SetOwner($sid)
      $acl.SetAccessRuleProtection($true, $false)
      $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($sid, "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
      $acl.AddAccessRule($rule)
      Set-Acl -LiteralPath $env:PM_DISPATCH_ACL_PATH -AclObject $acl
    '; then
  # shellcheck source=runtime/lib/state-writer.sh
  # shellcheck disable=SC1091 # CI checks each file without following dynamic sources.
  . "$REPO_ROOT/runtime/lib/state-writer.sh"
  event='{"id":"evt-20261004T000000Z-abcdef","schema_version":1,"ts":"2026-10-04T00:00:00Z","kind":"context.queried","subject_type":"context","subject_id":"native-smoke"}'
  if (cd "$REPO_ROOT" && events_append "$event" && \
      jq -e '.subject_id == "native-smoke"' "$(_sw_project_dir)/events.jsonl"); then
    report PASS "state-event-round-trip"
  else
    report FAIL "state-event-round-trip"
  fi
else
  report FAIL "state-private-acl"
fi
if mkdir_lock "$work/round-trip.lock" 2; then
  if [[ -s "$work/round-trip.lock/owner" ]] && mkdir_unlock "$work/round-trip.lock" \
      && [[ ! -e "$work/round-trip.lock" ]]; then
    report PASS "directory-lock-round-trip"
  else
    report FAIL "directory-lock-round-trip"
  fi
else
  report FAIL "directory-lock-round-trip"
fi

# --- 5. Doctor diagnostics must remain readable without live credentials ----
doctor_rc=0
bash "$REPO_ROOT/runtime/bin/doctor.sh" --json --repo "$REPO_ROOT" > "$work/doctor.jsonl" || doctor_rc=$?
# Missing optional executors/configuration can make doctor exit 1. Validate its
# diagnostic contract here, rather than claim a healthy authenticated install.
if [[ "$doctor_rc" -le 1 ]] && jq -se 'any(.[]; .summary == true and (.fail | type == "number"))' "$work/doctor.jsonl"; then
  report PASS "doctor-json-diagnostics" "exit=$doctor_rc; no live executor credentials"
else
  cat "$work/doctor.jsonl"
  report FAIL "doctor-json-diagnostics" "exit=$doctor_rc"
fi

printf '\nwindows-acceptance: %d passed, %d failed, %d skipped (repo %s, %s)\n' \
  "$pass_count" "$fail_count" "$skip_count" "$REPO_ROOT" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
[[ "$fail_count" -eq 0 ]]
