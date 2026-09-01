#!/usr/bin/env bash
# Native Windows (Git Bash) acceptance run for the experimental local-use
# platform exception. Produces the on-platform evidence that Linux CI cannot:
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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
# shellcheck source=runtime/lib/portable.sh
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
report() {
  local status="$1" name="$2" detail="${3:-}"
  if [[ "$status" == PASS ]]; then
    pass_count=$((pass_count + 1))
    printf 'PASS: %s%s\n' "$name" "${detail:+ ($detail)}"
  else
    fail_count=$((fail_count + 1))
    printf 'FAIL: %s%s\n' "$name" "${detail:+ — $detail}"
  fi
}

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

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
    bash "$REPO_ROOT/hosts/claude/bin/install-guards.sh" --profile minimal >/dev/null 2>&1; then
  report PASS "claude-install"
else
  report FAIL "claude-install" "install-guards.sh exited nonzero"
fi

# Launch every wired Claude hook command through PowerShell with a benign
# payload. Hook exit codes other than launch failure are acceptable here —
# acceptance proves PowerShell can start them at all.
while IFS= read -r cmd; do
  [[ -n "$cmd" ]] || continue
  if powershell_launch "$cmd" '{"tool_input":{"file_path":"/tmp/acceptance-probe"}}'; then
    report PASS "claude-hook-launch" "$cmd"
  else
    report FAIL "claude-hook-launch" "PowerShell could not launch: $cmd"
  fi
done < <(jq -r '[.hooks[]?[]?.hooks[]?.command] + [.statusLine.command // empty] | .[]' \
  "$claude_home/.claude/settings.json" 2>/dev/null)

# --- 2. Codex host install into a throwaway CODEX_HOME -----------------------
codex_home="$work/codex-home"
mkdir -p "$codex_home"
if CODEX_HOME="$codex_home" \
    bash "$REPO_ROOT/hosts/codex/bin/install.sh" --repo-root "$REPO_ROOT" >/dev/null 2>&1; then
  report PASS "codex-install"
else
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
  if cp "$link_src" "$link_dst" 2>/dev/null && cmp -s "$link_src" "$link_dst"; then
    report PASS "copy-fallback" "no native symlink (Developer Mode off?); copy fallback intact"
  else
    report FAIL "symlink-and-fallback" "neither a native symlink nor a copy could be produced"
  fi
fi

printf '\nwindows-acceptance: %d passed, %d failed (repo %s, %s)\n' \
  "$pass_count" "$fail_count" "$REPO_ROOT" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
[[ "$fail_count" -eq 0 ]]
