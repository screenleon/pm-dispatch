#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C.UTF-8

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
REAL_HOME="$(getent passwd "$(id -un)" | cut -d: -f6)"

# --filter <pattern>  run only cases whose name contains <pattern>
# --list              print all case names and exit
FILTER=""
LIST=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --filter) FILTER="${2:-}"; shift 2 ;;
    --list)   LIST=true; shift ;;
    *) shift ;;
  esac
done

ALL_CASES=()
# Returns 0 (run) or 1 (skip). In --list mode, registers name and skips.
should_run() {
  if $LIST; then
    ALL_CASES+=("$1")
    return 1
  fi
  [[ -z "$FILTER" || "$1" == *"$FILTER"* ]]
}

tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

PASS=0
FAIL=0
FAILED_CASES=()

pass() {
  printf 'PASS: %s\n' "$1"
  PASS=$((PASS + 1))
}

fail() {
  printf 'FAIL: %s: %s\n' "$1" "$2"
  FAIL=$((FAIL + 1))
  FAILED_CASES+=("$1")
}

assert_contains() {
  local name="$1" file="$2" needle="$3"
  if ! grep -Fq -- "$needle" "$file"; then
    fail "$name" "missing output: $needle"
    return 1
  fi
}

assert_not_contains() {
  local name="$1" file="$2" needle="$3"
  if grep -Fq -- "$needle" "$file"; then
    fail "$name" "unexpected output: $needle"
    return 1
  fi
}

assert_symlink_target() {
  local name="$1" path="$2" want="$3"
  if [ ! -L "$path" ]; then
    fail "$name" "$path is not a symlink"
    return 1
  fi
  local got
  got="$(readlink "$path")"
  if [ "$got" != "$want" ]; then
    fail "$name" "symlink target $got, expected $want"
    return 1
  fi
}

assert_dir_not_symlink() {
  local name="$1" path="$2"
  if [ ! -d "$path" ] || [ -L "$path" ]; then
    fail "$name" "$path is not a real directory"
    return 1
  fi
}

assert_file_content() {
  local name="$1" path="$2" want="$3"
  if [ ! -f "$path" ]; then
    fail "$name" "$path is not a file"
    return 1
  fi
  local got
  got="$(cat "$path")"
  if [ "$got" != "$want" ]; then
    fail "$name" "$path content changed"
    return 1
  fi
}

run_install_case() {
  local name="$1" mode="$2" want_code="$3"
  should_run "$name" || return 0
  local home="$tmp_root/fakehome-$name"
  local out="$tmp_root/$name.stdout"
  local err="$tmp_root/$name.stderr"
  local decoy="$tmp_root/decoy-$name"
  mkdir -p "$home/.claude" "$decoy"

  case "$mode" in
    absent) ;;
    correct-symlink)
      ln -s "$REPO_ROOT/pm" "$home/.claude/.pm"
      ;;
    wrong-symlink)
      ln -s "$decoy" "$home/.claude/.pm"
      ;;
    real-dir)
      mkdir -p "$home/.claude/.pm/some-content"
      ;;
    script-absent) ;;
    script-correct-symlink)
      mkdir -p "$home/.claude/scripts"
      ln -s "$REPO_ROOT/scripts/pr-gate.sh" "$home/.claude/scripts/pr-gate.sh"
      ;;
    script-wrong-symlink)
      mkdir -p "$home/.claude/scripts"
      printf '#!/usr/bin/env bash\n' > "$decoy/pr-gate.sh"
      ln -s "$decoy/pr-gate.sh" "$home/.claude/scripts/pr-gate.sh"
      ;;
    *)
      fail "$name" "unknown setup mode: $mode"
      return
      ;;
  esac

  shift 3
  set +e
  HOME="$home" \
    CLAUDE_CONFIG_TEST_INSTALL_RUNNING=1 \
    CLAUDE_CONFIG_TEST_PREFLIGHT_HOME="$REAL_HOME" \
    bash "$REPO_ROOT/install.sh" "$@" >"$out" 2>"$err"
  local got_code=$?
  set -e

  if [ "$got_code" -ne "$want_code" ]; then
    fail "$name" "exit $got_code, expected $want_code"
    return
  fi

  case "$name" in
    pm-absent-real-run)
      assert_contains "$name" "$out" "link   $home/.claude/.pm -> $REPO_ROOT/pm" || return
      assert_symlink_target "$name" "$home/.claude/.pm" "$REPO_ROOT/pm" || return
      ;;
    pm-absent-dry-run)
      assert_contains "$name" "$out" "would  $home/.claude/.pm -> $REPO_ROOT/pm" || return
      if [ -e "$home/.claude/.pm" ] || [ -L "$home/.claude/.pm" ]; then
        fail "$name" "$home/.claude/.pm should not exist"
        return
      fi
      ;;
    pm-correct-symlink-idempotent)
      assert_contains "$name" "$out" "ok    $home/.claude/.pm" || return
      assert_symlink_target "$name" "$home/.claude/.pm" "$REPO_ROOT/pm" || return
      ;;
    pm-wrong-symlink-real-run)
      assert_contains "$name" "$err" "CONFLICT" || return
      assert_contains "$name" "$err" "expected $REPO_ROOT/pm" || return
      assert_symlink_target "$name" "$home/.claude/.pm" "$decoy" || return
      ;;
    pm-real-dir-real-run)
      assert_contains "$name" "$err" "CONFLICT" || return
      assert_contains "$name" "$err" "is not a symlink" || return
      assert_dir_not_symlink "$name" "$home/.claude/.pm" || return
      ;;
    pm-real-dir-dry-run)
      assert_contains "$name" "$err" "CONFLICT" || return
      assert_contains "$name" "$err" "is not a symlink" || return
      assert_not_contains "$name" "$out" "would  $home/.claude/.pm" || return
      assert_dir_not_symlink "$name" "$home/.claude/.pm" || return
      ;;
    scripts-absent-real-run)
      assert_contains "$name" "$out" "link   $home/.claude/scripts/pr-gate.sh -> $REPO_ROOT/scripts/pr-gate.sh" || return
      assert_symlink_target "$name" "$home/.claude/scripts/pr-gate.sh" "$REPO_ROOT/scripts/pr-gate.sh" || return
      ;;
    scripts-correct-symlink-idempotent)
      assert_contains "$name" "$out" "ok    $home/.claude/scripts/pr-gate.sh" || return
      assert_symlink_target "$name" "$home/.claude/scripts/pr-gate.sh" "$REPO_ROOT/scripts/pr-gate.sh" || return
      ;;
    scripts-wrong-symlink-real-run)
      assert_contains "$name" "$err" "CONFLICT" || return
      assert_contains "$name" "$err" "expected $REPO_ROOT/scripts/pr-gate.sh" || return
      assert_symlink_target "$name" "$home/.claude/scripts/pr-gate.sh" "$decoy/pr-gate.sh" || return
      ;;
  esac

  pass "$name"
}

run_install_case "pm-absent-real-run" absent 0
run_install_case "pm-absent-dry-run" absent 0 --dry-run
run_install_case "pm-correct-symlink-idempotent" correct-symlink 0
run_install_case "pm-wrong-symlink-real-run" wrong-symlink 1
run_install_case "pm-real-dir-real-run" real-dir 1
run_install_case "pm-real-dir-dry-run" real-dir 1 --dry-run
run_install_case "scripts-absent-real-run" script-absent 0
run_install_case "scripts-correct-symlink-idempotent" script-correct-symlink 0
run_install_case "scripts-wrong-symlink-real-run" script-wrong-symlink 0

test_legacy_pm_left_untouched() {
  local name="legacy-github-pm-left-untouched"
  should_run "$name" || return 0

  local dir_home="$tmp_root/$name-dir-home"
  local dir_out="$tmp_root/$name-dir.stdout"
  local dir_err="$tmp_root/$name-dir.stderr"
  mkdir -p "$dir_home/.claude" "$dir_home/github/.pm/nested"
  printf 'legacy dir sentinel\n' > "$dir_home/github/.pm/nested/sentinel.txt"

  set +e
  HOME="$dir_home" \
    CLAUDE_CONFIG_TEST_INSTALL_RUNNING=1 \
    CLAUDE_CONFIG_TEST_PREFLIGHT_HOME="$REAL_HOME" \
    bash "$REPO_ROOT/install.sh" >"$dir_out" 2>"$dir_err"
  local dir_code=$?
  set -e

  if [ "$dir_code" -ne 0 ]; then
    fail "$name" "legacy real-dir install exit $dir_code, expected 0"
    return
  fi
  assert_dir_not_symlink "$name" "$dir_home/github/.pm" || return
  assert_file_content "$name" "$dir_home/github/.pm/nested/sentinel.txt" "legacy dir sentinel" || return
  assert_not_contains "$name" "$dir_err" "$dir_home/github/.pm" || return

  local link_home="$tmp_root/$name-link-home"
  local link_out="$tmp_root/$name-link.stdout"
  local link_err="$tmp_root/$name-link.stderr"
  local legacy_target="$tmp_root/$name-legacy-target"
  mkdir -p "$link_home/.claude" "$link_home/github" "$legacy_target"
  printf 'legacy symlink sentinel\n' > "$legacy_target/sentinel.txt"
  ln -s "$legacy_target" "$link_home/github/.pm"

  set +e
  HOME="$link_home" \
    CLAUDE_CONFIG_TEST_INSTALL_RUNNING=1 \
    CLAUDE_CONFIG_TEST_PREFLIGHT_HOME="$REAL_HOME" \
    bash "$REPO_ROOT/install.sh" >"$link_out" 2>"$link_err"
  local link_code=$?
  set -e

  if [ "$link_code" -ne 0 ]; then
    fail "$name" "legacy symlink install exit $link_code, expected 0"
    return
  fi
  assert_symlink_target "$name" "$link_home/github/.pm" "$legacy_target" || return
  assert_file_content "$name" "$legacy_target/sentinel.txt" "legacy symlink sentinel" || return
  assert_not_contains "$name" "$link_err" "$link_home/github/.pm" || return

  pass "$name"
}

test_legacy_stale_symlinks_removed() {
  local name="legacy-stale-symlinks-removed"
  should_run "$name" || return 0

  local script_home="$tmp_root/$name-script-home"
  local script_out="$tmp_root/$name-script.stdout"
  local script_err="$tmp_root/$name-script.stderr"
  mkdir -p "$script_home/.claude/scripts"
  ln -s "$REPO_ROOT/scripts/codex-pr-gate.sh" "$script_home/.claude/scripts/codex-pr-gate.sh"

  set +e
  HOME="$script_home" \
    CLAUDE_CONFIG_TEST_INSTALL_RUNNING=1 \
    CLAUDE_CONFIG_TEST_PREFLIGHT_HOME="$REAL_HOME" \
    bash "$REPO_ROOT/install.sh" >"$script_out" 2>"$script_err"
  local script_code=$?
  set -e

  if [ "$script_code" -ne 0 ]; then
    fail "$name" "legacy script install exit $script_code, expected 0"
    return
  fi
  if [ -e "$script_home/.claude/scripts/codex-pr-gate.sh" ] || [ -L "$script_home/.claude/scripts/codex-pr-gate.sh" ]; then
    fail "$name" "$script_home/.claude/scripts/codex-pr-gate.sh should not exist"
    return
  fi
  assert_contains "$name" "$script_out" "remove (legacy)" || return

  local command_home="$tmp_root/$name-command-home"
  local command_out="$tmp_root/$name-command.stdout"
  local command_err="$tmp_root/$name-command.stderr"
  mkdir -p "$command_home/.claude/commands"
  ln -s "$REPO_ROOT/commands/codex-pr-gate.md" "$command_home/.claude/commands/codex-pr-gate.md"

  set +e
  HOME="$command_home" \
    CLAUDE_CONFIG_TEST_INSTALL_RUNNING=1 \
    CLAUDE_CONFIG_TEST_PREFLIGHT_HOME="$REAL_HOME" \
    bash "$REPO_ROOT/install.sh" >"$command_out" 2>"$command_err"
  local command_code=$?
  set -e

  if [ "$command_code" -ne 0 ]; then
    fail "$name" "legacy command install exit $command_code, expected 0"
    return
  fi
  if [ -e "$command_home/.claude/commands/codex-pr-gate.md" ] || [ -L "$command_home/.claude/commands/codex-pr-gate.md" ]; then
    fail "$name" "$command_home/.claude/commands/codex-pr-gate.md should not exist"
    return
  fi

  # claude-usage.sh → token-usage.sh rename: stale helper symlink must be removed.
  local usage_home="$tmp_root/$name-usage-home"
  local usage_out="$tmp_root/$name-usage.stdout"
  mkdir -p "$usage_home/.claude/scripts"
  ln -s "$REPO_ROOT/scripts/claude-usage.sh" "$usage_home/.claude/scripts/claude-usage.sh" 2>/dev/null || \
    ln -s "/dev/null" "$usage_home/.claude/scripts/claude-usage.sh"

  set +e
  HOME="$usage_home" \
    CLAUDE_CONFIG_TEST_INSTALL_RUNNING=1 \
    CLAUDE_CONFIG_TEST_PREFLIGHT_HOME="$REAL_HOME" \
    bash "$REPO_ROOT/install.sh" >"$usage_out" 2>/dev/null
  local usage_code=$?
  set -e

  if [ "$usage_code" -ne 0 ]; then
    fail "$name" "claude-usage legacy install exit $usage_code, expected 0"
    return
  fi
  if [ -e "$usage_home/.claude/scripts/claude-usage.sh" ] || [ -L "$usage_home/.claude/scripts/claude-usage.sh" ]; then
    fail "$name" "$usage_home/.claude/scripts/claude-usage.sh should have been removed"
    return
  fi
  assert_contains "$name" "$usage_out" "remove (legacy)" || return

  pass "$name"
}

# ── install-hooks / uninstall-hooks lifecycle ─────────────────────────────────
# Proves that install-hooks.sh wires all six managed hooks and that
# uninstall-hooks.sh removes each of them completely, leaving no orphaned entries.

test_install_sh_wires_hooks() {
  # Proves that the primary install.sh path wires all six managed hooks
  # into settings.json automatically — no manual install-hooks.sh step needed.
  local name="install-sh-wires-hooks"
  should_run "$name" || return 0
  local home="$tmp_root/$name"
  mkdir -p "$home/.claude"
  printf '{"permissions":{}}\n' > "$home/.claude/settings.json"

  HOME="$home" \
    CLAUDE_CONFIG_TEST_INSTALL_RUNNING=1 \
    CLAUDE_CONFIG_TEST_PREFLIGHT_HOME="$REAL_HOME" \
    bash "$REPO_ROOT/install.sh" > /dev/null 2>&1

  assert_contains "$name" "$home/.claude/settings.json" "hook-pm-write-guard.sh" || return
  assert_contains "$name" "$home/.claude/settings.json" "hook-codex-bash-guard.sh" || return
  assert_contains "$name" "$home/.claude/settings.json" "hook-codex-write-guard.sh" || return
  assert_contains "$name" "$home/.claude/settings.json" "hook-log-claude-usage.sh" || return
  assert_contains "$name" "$home/.claude/settings.json" "hook-inject-memory.sh" || return
  assert_contains "$name" "$home/.claude/settings.json" "hook-save-rate-limits.sh" || return
  if [[ -f "$home/.claude/statusline-chain.conf" ]]; then
    fail "$name" "statusline-chain.conf should not exist without previous statusLine"
    return
  fi
  pass "$name"
}

test_install_sh_wires_hooks_no_settings() {
  # First-time install with no pre-existing settings.json — install.sh must
  # create a minimal settings.json and wire all hooks before the Write-enabled
  # codex-executor agent is accessible.
  local name="install-sh-wires-hooks-no-settings"
  should_run "$name" || return 0
  local home="$tmp_root/$name"
  mkdir -p "$home/.claude"
  # Deliberately no settings.json

  HOME="$home" \
    CLAUDE_CONFIG_TEST_INSTALL_RUNNING=1 \
    CLAUDE_CONFIG_TEST_PREFLIGHT_HOME="$REAL_HOME" \
    bash "$REPO_ROOT/install.sh" > /dev/null 2>&1

  if [[ ! -f "$home/.claude/settings.json" ]]; then
    fail "$name" "settings.json was not created during first-time install"
    return
  fi
  assert_contains "$name" "$home/.claude/settings.json" "hook-pm-write-guard.sh" || return
  assert_contains "$name" "$home/.claude/settings.json" "hook-codex-bash-guard.sh" || return
  assert_contains "$name" "$home/.claude/settings.json" "hook-codex-write-guard.sh" || return
  assert_contains "$name" "$home/.claude/settings.json" "hook-log-claude-usage.sh" || return
  assert_contains "$name" "$home/.claude/settings.json" "hook-inject-memory.sh" || return
  assert_contains "$name" "$home/.claude/settings.json" "hook-save-rate-limits.sh" || return
  pass "$name"
}

test_hooks_install_uninstall_lifecycle() {
  local name="hooks-install-uninstall-lifecycle"
  should_run "$name" || return 0
  local home="$tmp_root/$name"
  mkdir -p "$home/.claude"
  printf '{"permissions":{}}\n' > "$home/.claude/settings.json"

  HOME="$home" bash "$REPO_ROOT/scripts/install-hooks.sh" > /dev/null
  assert_contains "$name" "$home/.claude/settings.json" "hook-pm-write-guard.sh" || return
  assert_contains "$name" "$home/.claude/settings.json" "hook-codex-bash-guard.sh" || return
  assert_contains "$name" "$home/.claude/settings.json" "hook-codex-write-guard.sh" || return
  assert_contains "$name" "$home/.claude/settings.json" "hook-log-claude-usage.sh" || return
  assert_contains "$name" "$home/.claude/settings.json" "hook-inject-memory.sh" || return
  assert_contains "$name" "$home/.claude/settings.json" "hook-save-rate-limits.sh" || return

  HOME="$home" bash "$REPO_ROOT/scripts/uninstall-hooks.sh" > /dev/null
  assert_not_contains "$name" "$home/.claude/settings.json" "hook-pm-write-guard.sh" || return
  assert_not_contains "$name" "$home/.claude/settings.json" "hook-codex-bash-guard.sh" || return
  assert_not_contains "$name" "$home/.claude/settings.json" "hook-codex-write-guard.sh" || return
  assert_not_contains "$name" "$home/.claude/settings.json" "hook-log-claude-usage.sh" || return
  assert_not_contains "$name" "$home/.claude/settings.json" "hook-inject-memory.sh" || return
  assert_not_contains "$name" "$home/.claude/settings.json" "hook-save-rate-limits.sh" || return
  if jq -e 'has("statusLine")' "$home/.claude/settings.json" >/dev/null; then
    fail "$name" "statusLine should be deleted when no chain target exists"
    return
  fi

  pass "$name"
}

test_install_hooks_updates_stale_paths_after_rename() {
  # Verifies that install-hooks.sh updates stale full-paths (e.g. from a repo
  # rename claude-config -> pm-dispatch) without creating duplicate entries.
  #
  # Steps:
  #   1. Create settings.json pre-populated with hooks pointing at /fake/old-repo/scripts/
  #   2. Run install-hooks.sh (current repo_root)
  #   3. Assert each hook appears exactly once and with the current path
  local name="install-hooks-updates-stale-paths-after-rename"
  should_run "$name" || return 0
  local home="$tmp_root/$name"
  mkdir -p "$home/.claude"

  # Simulate settings.json left over from old repo path
  cat > "$home/.claude/settings.json" <<'JSON'
{
  "permissions": {},
  "hooks": {
    "PreToolUse": [
      {"matcher": "Edit|Write", "hooks": [{"type": "command", "command": "/fake/old-repo/scripts/hook-pm-write-guard.sh"}]},
      {"matcher": "Edit|Write", "hooks": [{"type": "command", "command": "/fake/old-repo/scripts/hook-codex-write-guard.sh"}]},
      {"matcher": "Bash",       "hooks": [{"type": "command", "command": "/fake/old-repo/scripts/hook-codex-bash-guard.sh"}]}
    ],
    "Stop": [
      {"hooks": [{"type": "command", "command": "/fake/old-repo/scripts/hook-log-claude-usage.sh"}]},
      {"hooks": [{"type": "command", "command": "/fake/old-repo/scripts/hook-session-summary.sh"}]}
    ],
    "UserPromptSubmit": [
      {"hooks": [{"type": "command", "command": "/fake/old-repo/scripts/hook-inject-memory.sh"}]}
    ]
  },
  "statusLine": {"type": "command", "command": "/fake/old-repo/scripts/hook-save-rate-limits.sh"}
}
JSON

  HOME="$home" bash "$REPO_ROOT/scripts/install-hooks.sh" > /dev/null

  # Each hook basename must appear exactly once (no duplicates)
  local settings="$home/.claude/settings.json"
  for hook in hook-pm-write-guard.sh hook-codex-write-guard.sh hook-codex-bash-guard.sh \
              hook-log-claude-usage.sh hook-session-summary.sh \
              hook-inject-memory.sh hook-save-rate-limits.sh; do
    local count
    count=$(grep -o "$hook" "$settings" | wc -l | tr -d ' ')
    if [[ "$count" -ne 1 ]]; then
      fail "$name" "$hook appears $count times in settings.json (want 1)"
      return
    fi
  done

  # Old path must be gone; current repo path must be present
  if grep -q "/fake/old-repo/" "$settings"; then
    fail "$name" "stale /fake/old-repo/ path still present after re-install"
    return
  fi
  assert_contains "$name" "$settings" "$REPO_ROOT/scripts/hook-pm-write-guard.sh" || return

  pass "$name"
}

test_install_hooks_preserves_unrelated_same_basename_hook() {
  # Verifies that install-hooks.sh does NOT overwrite hooks from unrelated tools
  # that share a managed hook basename but live at a non-standard path (parent
  # directory is not "scripts/"). Such entries must be preserved unchanged.
  #
  # Steps:
  #   1. Create settings.json with an unrelated Stop hook at /some/tool/hook-log-claude-usage.sh
  #      (basename matches managed hook; parent dir is "tool", not "scripts")
  #   2. Run install-hooks.sh
  #   3. Assert the unrelated hook is still present at its original path (not overwritten)
  #   4. Assert our managed hook was appended as a separate entry (not collapsed into the unrelated one)
  local name="install-hooks-preserves-unrelated-same-basename-hook"
  should_run "$name" || return 0
  local home="$tmp_root/$name"
  mkdir -p "$home/.claude"

  local unrelated_path="/some/unrelated/tool/hook-log-claude-usage.sh"

  cat > "$home/.claude/settings.json" <<JSON
{
  "permissions": {},
  "hooks": {
    "Stop": [
      {"hooks": [{"type": "command", "command": "$unrelated_path"}]}
    ]
  }
}
JSON

  HOME="$home" bash "$REPO_ROOT/scripts/install-hooks.sh" > /dev/null

  local settings="$home/.claude/settings.json"

  # Unrelated hook must still be present at original path
  assert_contains "$name" "$settings" "$unrelated_path" || return

  # Our managed hook must also be present (appended, not merged)
  assert_contains "$name" "$settings" "hook-log-claude-usage.sh" || return

  # Count occurrences of the basename — must be exactly 2
  # (unrelated path + our managed path)
  local count
  count=$(grep -o "hook-log-claude-usage.sh" "$settings" | wc -l | tr -d ' ')
  if [[ "$count" -ne 2 ]]; then
    fail "$name" "hook-log-claude-usage.sh appears $count times (want 2: unrelated + managed)"
    return
  fi

  pass "$name"
}

test_install_hooks_uninstall_stale_paths_after_rename() {
  # Verifies that uninstall-hooks.sh removes stale managed hook paths (e.g. from
  # a repo rename) by basename+scripts/ match, not by exact full path.
  #
  # Steps:
  #   1. Create settings.json with managed hooks at /fake/old-repo/scripts/
  #   2. Run uninstall-hooks.sh (current repo_root; paths differ from settings)
  #   3. Assert all managed hook basenames are gone from settings.json
  local name="install-hooks-uninstall-stale-paths-after-rename"
  should_run "$name" || return 0
  local home="$tmp_root/$name"
  mkdir -p "$home/.claude"

  cat > "$home/.claude/settings.json" <<'JSON'
{
  "permissions": {},
  "hooks": {
    "PreToolUse": [
      {"matcher": "Edit|Write", "hooks": [{"type": "command", "command": "/fake/old-repo/scripts/hook-pm-write-guard.sh"}]},
      {"matcher": "Edit|Write", "hooks": [{"type": "command", "command": "/fake/old-repo/scripts/hook-codex-write-guard.sh"}]},
      {"matcher": "Bash",       "hooks": [{"type": "command", "command": "/fake/old-repo/scripts/hook-codex-bash-guard.sh"}]}
    ],
    "Stop": [
      {"hooks": [{"type": "command", "command": "/fake/old-repo/scripts/hook-log-claude-usage.sh"}]},
      {"hooks": [{"type": "command", "command": "/fake/old-repo/scripts/hook-session-summary.sh"}]}
    ],
    "UserPromptSubmit": [
      {"hooks": [{"type": "command", "command": "/fake/old-repo/scripts/hook-inject-memory.sh"}]}
    ]
  },
  "statusLine": {"type": "command", "command": "/fake/old-repo/scripts/hook-save-rate-limits.sh"}
}
JSON

  HOME="$home" bash "$REPO_ROOT/scripts/uninstall-hooks.sh" > /dev/null

  local settings="$home/.claude/settings.json"

  # All managed hook basenames must be gone
  for hook in hook-pm-write-guard.sh hook-codex-write-guard.sh hook-codex-bash-guard.sh \
              hook-log-claude-usage.sh hook-session-summary.sh \
              hook-inject-memory.sh hook-save-rate-limits.sh; do
    if grep -q "$hook" "$settings"; then
      fail "$name" "$hook still present in settings.json after uninstall of stale paths"
      return
    fi
  done

  # No /fake/old-repo/ paths should remain
  if grep -q "/fake/old-repo/" "$settings"; then
    fail "$name" "stale /fake/old-repo/ path still present after uninstall"
    return
  fi

  pass "$name"
}

test_userpromptsubmit_install_wires_hook() {
  # Verifies install-hooks.sh wires hook-inject-memory.sh into UserPromptSubmit.
  # Steps:
  #   1. Create a sandbox settings.json with no hooks
  #   2. Run install-hooks.sh directly
  #   3. Assert UserPromptSubmit exists and contains the memory injection hook path
  local name="userpromptsubmit-install-wires-hook"
  should_run "$name" || return 0
  local home="$tmp_root/$name"
  local inject="$REPO_ROOT/scripts/hook-inject-memory.sh"
  mkdir -p "$home/.claude"
  printf '{"permissions":{}}\n' > "$home/.claude/settings.json"

  HOME="$home" bash "$REPO_ROOT/scripts/install-hooks.sh" > /dev/null

  assert_contains "$name" "$home/.claude/settings.json" "UserPromptSubmit" || return
  assert_contains "$name" "$home/.claude/settings.json" "$inject" || return
  if ! jq -e --arg inject "$inject" \
    '.hooks.UserPromptSubmit[]? | (.hooks // [])[]? | select(.command == $inject)' \
    "$home/.claude/settings.json" >/dev/null; then
    fail "$name" "UserPromptSubmit hook command not found"
    return
  fi
  pass "$name"
}

test_userpromptsubmit_uninstall_removes_hook() {
  # Verifies uninstall-hooks.sh removes the managed UserPromptSubmit hook cleanly.
  # Steps:
  #   1. Create a sandbox settings.json, then run install-hooks.sh
  #   2. Run uninstall-hooks.sh
  #   3. Assert hook-inject-memory.sh and the UserPromptSubmit key are gone
  local name="userpromptsubmit-uninstall-removes-hook"
  should_run "$name" || return 0
  local home="$tmp_root/$name"
  mkdir -p "$home/.claude"
  printf '{"permissions":{}}\n' > "$home/.claude/settings.json"

  HOME="$home" bash "$REPO_ROOT/scripts/install-hooks.sh" > /dev/null
  HOME="$home" bash "$REPO_ROOT/scripts/uninstall-hooks.sh" > /dev/null

  assert_not_contains "$name" "$home/.claude/settings.json" "hook-inject-memory.sh" || return
  if ! jq -e '((.hooks // {}) | has("UserPromptSubmit") | not) or ((.hooks.UserPromptSubmit // []) | length == 0)' \
    "$home/.claude/settings.json" >/dev/null; then
    fail "$name" "UserPromptSubmit should be absent or empty"
    return
  fi
  pass "$name"
}

test_userpromptsubmit_install_idempotent() {
  # Verifies repeated install-hooks.sh runs do not duplicate UserPromptSubmit hooks.
  # Steps:
  #   1. Create a sandbox settings.json with no hooks
  #   2. Run install-hooks.sh twice
  #   3. Assert exactly one hook-inject-memory.sh command is present
  local name="userpromptsubmit-install-idempotent"
  should_run "$name" || return 0
  local home="$tmp_root/$name"
  local inject="$REPO_ROOT/scripts/hook-inject-memory.sh"
  local count
  mkdir -p "$home/.claude"
  printf '{"permissions":{}}\n' > "$home/.claude/settings.json"

  HOME="$home" bash "$REPO_ROOT/scripts/install-hooks.sh" > /dev/null
  HOME="$home" bash "$REPO_ROOT/scripts/install-hooks.sh" > /dev/null

  count="$(jq --arg inject "$inject" \
    '[.hooks.UserPromptSubmit[]? | (.hooks // [])[]? | select(.command == $inject)] | length' \
    "$home/.claude/settings.json")"
  if [[ "$count" != "1" ]]; then
    fail "$name" "expected one UserPromptSubmit memory hook, got $count"
    return
  fi
  pass "$name"
}

test_userpromptsubmit_uninstall_preserves_unrelated() {
  # Verifies uninstall-hooks.sh removes only the managed UserPromptSubmit hook.
  # Steps:
  #   1. Create settings.json with an unrelated UserPromptSubmit hook
  #   2. Run install-hooks.sh, then uninstall-hooks.sh
  #   3. Assert the unrelated hook remains and hook-inject-memory.sh is gone
  local name="userpromptsubmit-uninstall-preserves-unrelated"
  should_run "$name" || return 0
  local home="$tmp_root/$name"
  local unrelated="/home/testuser/project/custom-userpromptsubmit.sh"
  mkdir -p "$home/.claude"
  printf '{"permissions":{},"hooks":{"UserPromptSubmit":[{"hooks":[{"type":"command","command":"%s"}]}]}}\n' \
    "$unrelated" > "$home/.claude/settings.json"

  HOME="$home" bash "$REPO_ROOT/scripts/install-hooks.sh" > /dev/null
  HOME="$home" bash "$REPO_ROOT/scripts/uninstall-hooks.sh" > /dev/null

  assert_contains "$name" "$home/.claude/settings.json" "$unrelated" || return
  assert_not_contains "$name" "$home/.claude/settings.json" "hook-inject-memory.sh" || return
  pass "$name"
}

test_stop_hook_migration() {
  local name="hooks-stop-migration"
  should_run "$name" || return 0
  local home="$tmp_root/$name"
  mkdir -p "$home/.claude"
  local old_stop="$REPO_ROOT/hooks/hook-log-claude-usage.sh"
  printf '{"permissions":{},"hooks":{"Stop":[{"hooks":[{"type":"command","command":"%s"}]}]}}\n' \
    "$old_stop" > "$home/.claude/settings.json"

  HOME="$home" bash "$REPO_ROOT/scripts/install-hooks.sh" > /dev/null
  assert_not_contains "$name" "$home/.claude/settings.json" \
    "hooks/hook-log-claude-usage.sh" || return
  assert_contains "$name" "$home/.claude/settings.json" \
    "scripts/hook-log-claude-usage.sh" || return
  pass "$name"
}

test_stop_hook_preservation() {
  local name="hooks-stop-preservation"
  should_run "$name" || return 0
  local home="$tmp_root/$name"
  mkdir -p "$home/.claude"
  # Unrelated hook at a completely different path.
  local unrelated="/home/testuser/myproject/custom-stop-hook.sh"
  printf '{"permissions":{},"hooks":{"Stop":[{"hooks":[{"type":"command","command":"%s"}]}]}}\n' \
    "$unrelated" > "$home/.claude/settings.json"

  # After install: unrelated hook preserved, managed hook added
  HOME="$home" bash "$REPO_ROOT/scripts/install-hooks.sh" > /dev/null
  assert_contains "$name" "$home/.claude/settings.json" "$unrelated" || return
  assert_contains "$name" "$home/.claude/settings.json" "scripts/hook-log-claude-usage.sh" || return

  # After uninstall: managed hook removed, unrelated hook still present
  HOME="$home" bash "$REPO_ROOT/scripts/uninstall-hooks.sh" > /dev/null
  assert_not_contains "$name" "$home/.claude/settings.json" "scripts/hook-log-claude-usage.sh" || return
  assert_contains "$name" "$home/.claude/settings.json" "$unrelated" || return
  pass "$name"
}

test_statusline_install_chains_previous() {
  # Verifies that when a previous statusLine.command exists, install saves it to
  # statusline-chain.conf and replaces it with hook-save-rate-limits.sh; a second
  # install run is idempotent and preserves the chain conf.
  # Steps:
  #   1. Write settings.json with a bare-path statusLine.command
  #   2. Run install; assert statusLine.command is now hook-save-rate-limits.sh
  #   3. Assert statusline-chain.conf contains the previous command path
  #   4. Run install again; assert "already wired" and chain conf unchanged
  local name="statusline-install-chains-previous"
  should_run "$name" || return 0
  local home="$tmp_root/$name"
  local previous="$tmp_root/$name-prev-statusline.sh"
  local out="$tmp_root/$name-second-install.out"
  mkdir -p "$home/.claude"
  printf '#!/usr/bin/env bash\ncat >/dev/null\n' > "$previous"
  chmod +x "$previous"
  printf '{"permissions":{},"statusLine":{"type":"command","command":"%s"}}\n' \
    "$previous" > "$home/.claude/settings.json"

  HOME="$home" bash "$REPO_ROOT/scripts/install-hooks.sh" > /dev/null
  local got
  got="$(jq -r '.statusLine.command // empty' "$home/.claude/settings.json")"
  if [[ "$got" != "$REPO_ROOT/scripts/hook-save-rate-limits.sh" ]]; then
    fail "$name" "statusLine.command was $got"
    return
  fi
  assert_file_content "$name" "$home/.claude/statusline-chain.conf" "$previous" || return

  HOME="$home" bash "$REPO_ROOT/scripts/install-hooks.sh" > "$out"
  assert_contains "$name" "$out" "already wired, nothing to do" || return
  assert_file_content "$name" "$home/.claude/statusline-chain.conf" "$previous" || return
  pass "$name"
}

test_statusline_install_chains_previous_with_args() {
  # Verifies that a statusLine.command containing arguments (e.g. "/path/cmd --flag")
  # is stored verbatim in statusline-chain.conf so bash -c can invoke it correctly.
  # Steps:
  #   1. Write settings.json with a statusLine.command that includes a flag argument
  #   2. Run install; assert statusLine.command is replaced with hook-save-rate-limits.sh
  #   3. Assert statusline-chain.conf contains the full original command string with args
  local name="statusline-install-chains-previous-with-args"
  should_run "$name" || return 0
  local home="$tmp_root/$name"
  local previous="$tmp_root/$name-prev-statusline.sh"
  mkdir -p "$home/.claude"
  printf '#!/usr/bin/env bash\ncat >/dev/null\n' > "$previous"
  chmod +x "$previous"
  # Command string with arguments — the full value must be preserved in chain conf.
  local previous_with_args="$previous --some-flag"
  printf '{"permissions":{},"statusLine":{"type":"command","command":"%s"}}\n' \
    "$previous_with_args" > "$home/.claude/settings.json"

  HOME="$home" bash "$REPO_ROOT/scripts/install-hooks.sh" > /dev/null
  local got
  got="$(jq -r '.statusLine.command // empty' "$home/.claude/settings.json")"
  if [[ "$got" != "$REPO_ROOT/scripts/hook-save-rate-limits.sh" ]]; then
    fail "$name" "statusLine.command was $got"
    return
  fi
  assert_file_content "$name" "$home/.claude/statusline-chain.conf" "$previous_with_args" || return
  pass "$name"
}

test_statusline_uninstall_restores() {
  # Verifies that uninstall restores the previous statusLine.command from
  # statusline-chain.conf and removes the chain conf file.
  # Steps:
  #   1. Write settings.json with a previous statusLine.command and run install
  #   2. Run uninstall
  #   3. Assert statusLine.command is restored to the original value
  #   4. Assert statusline-chain.conf no longer exists
  local name="statusline-uninstall-restores"
  should_run "$name" || return 0
  local home="$tmp_root/$name"
  local previous="$tmp_root/$name-prev-statusline.sh"
  mkdir -p "$home/.claude"
  printf '#!/usr/bin/env bash\ncat >/dev/null\n' > "$previous"
  chmod +x "$previous"
  printf '{"permissions":{},"statusLine":{"type":"command","command":"%s"}}\n' \
    "$previous" > "$home/.claude/settings.json"

  HOME="$home" bash "$REPO_ROOT/scripts/install-hooks.sh" > /dev/null
  HOME="$home" bash "$REPO_ROOT/scripts/uninstall-hooks.sh" > /dev/null
  local got
  got="$(jq -r '.statusLine.command // empty' "$home/.claude/settings.json")"
  if [[ "$got" != "$previous" ]]; then
    fail "$name" "statusLine.command was $got"
    return
  fi
  if [[ -f "$home/.claude/statusline-chain.conf" ]]; then
    fail "$name" "statusline-chain.conf should be deleted"
    return
  fi
  pass "$name"
}

test_session_stop_install_wires_hook() {
  # Verifies install-hooks.sh wires hook-session-summary.sh into the Stop event.
  # Steps:
  #   1. Create a sandbox settings.json with no hooks
  #   2. Run install-hooks.sh
  #   3. Assert Stop exists and contains the session summary hook path
  local name="session-stop-install-wires-hook"
  should_run "$name" || return 0
  local home="$tmp_root/$name"
  local session="$REPO_ROOT/scripts/hook-session-summary.sh"
  mkdir -p "$home/.claude"
  printf '{"permissions":{}}\n' > "$home/.claude/settings.json"

  HOME="$home" bash "$REPO_ROOT/scripts/install-hooks.sh" > /dev/null

  assert_contains "$name" "$home/.claude/settings.json" "$session" || return
  if ! jq -e --arg session "$session" \
    '.hooks.Stop[]? | (.hooks // [])[]? | select(.command == $session)' \
    "$home/.claude/settings.json" >/dev/null; then
    fail "$name" "Stop session-summary hook command not found"
    return
  fi
  pass "$name"
}

test_session_stop_uninstall_removes_hook() {
  # Verifies uninstall-hooks.sh removes the managed session-summary Stop hook.
  # Steps:
  #   1. Create a sandbox settings.json, run install-hooks.sh
  #   2. Run uninstall-hooks.sh
  #   3. Assert hook-session-summary.sh is gone from settings.json
  local name="session-stop-uninstall-removes-hook"
  should_run "$name" || return 0
  local home="$tmp_root/$name"
  local session="$REPO_ROOT/scripts/hook-session-summary.sh"
  mkdir -p "$home/.claude"
  printf '{"permissions":{}}\n' > "$home/.claude/settings.json"

  HOME="$home" bash "$REPO_ROOT/scripts/install-hooks.sh" > /dev/null
  HOME="$home" bash "$REPO_ROOT/scripts/uninstall-hooks.sh" > /dev/null

  assert_not_contains "$name" "$home/.claude/settings.json" "hook-session-summary.sh" || return
  pass "$name"
}

test_session_stop_install_idempotent() {
  # Verifies repeated install-hooks.sh runs do not duplicate the session-summary hook.
  # Steps:
  #   1. Create a sandbox settings.json with no hooks
  #   2. Run install-hooks.sh twice
  #   3. Assert exactly one hook-session-summary.sh command is present
  local name="session-stop-install-idempotent"
  should_run "$name" || return 0
  local home="$tmp_root/$name"
  local session="$REPO_ROOT/scripts/hook-session-summary.sh"
  local count
  mkdir -p "$home/.claude"
  printf '{"permissions":{}}\n' > "$home/.claude/settings.json"

  HOME="$home" bash "$REPO_ROOT/scripts/install-hooks.sh" > /dev/null
  HOME="$home" bash "$REPO_ROOT/scripts/install-hooks.sh" > /dev/null

  count="$(jq --arg session "$session" \
    '[.hooks.Stop[]? | (.hooks // [])[]? | select(.command == $session)] | length' \
    "$home/.claude/settings.json")"
  if [[ "$count" != "1" ]]; then
    fail "$name" "expected one Stop session-summary hook, got $count"
    return
  fi
  pass "$name"
}

test_session_stop_uninstall_preserves_stop() {
  # Verifies uninstall-hooks.sh removes only the managed session-summary hook,
  # leaving unrelated Stop hooks intact.
  # Steps:
  #   1. Create settings.json with an unrelated Stop hook
  #   2. Run install-hooks.sh, then uninstall-hooks.sh
  #   3. Assert the unrelated hook remains and hook-session-summary.sh is gone
  local name="session-stop-uninstall-preserves-stop"
  should_run "$name" || return 0
  local home="$tmp_root/$name"
  local unrelated="/home/testuser/project/custom-stop-hook.sh"
  mkdir -p "$home/.claude"
  printf '{"permissions":{},"hooks":{"Stop":[{"hooks":[{"type":"command","command":"%s"}]}]}}\n' \
    "$unrelated" > "$home/.claude/settings.json"

  HOME="$home" bash "$REPO_ROOT/scripts/install-hooks.sh" > /dev/null
  HOME="$home" bash "$REPO_ROOT/scripts/uninstall-hooks.sh" > /dev/null

  assert_contains "$name" "$home/.claude/settings.json" "$unrelated" || return
  assert_not_contains "$name" "$home/.claude/settings.json" "hook-session-summary.sh" || return
  pass "$name"
}

test_skip_preflight_skips_all_tests() {
  # Verifies that CLAUDE_CONFIG_TEST_INSTALL_RUNNING=1 causes install.sh to
  # skip all preflight test suites (no test output headers produced).
  # Steps:
  #   1. Create a sandbox settings.json
  #   2. Run install.sh with CLAUDE_CONFIG_TEST_INSTALL_RUNNING=1
  #   3. Assert output contains NO "==>" preflight section headers for any test suite
  local name="skip-preflight-skips-all-tests"
  should_run "$name" || return 0
  local home out
  home="$tmp_root/$name"
  mkdir -p "$home/.claude"
  printf '{"permissions":{}}\n' > "$home/.claude/settings.json"

  out=$(HOME="$home" CLAUDE_CONFIG_TEST_INSTALL_RUNNING=1 bash "$REPO_ROOT/install.sh" 2>&1)

  local ok=true
  for label in "test hooks" "test install" "test usage" "test pm" "test codex" \
               "test pr-gate" "test setup-project" "test patch-gitignore" \
               "lint agents" "lint scripts"; do
    if [[ "$out" == *"==> $label"* ]]; then
      ok=false
      printf '  FAIL  %s — unexpected preflight section: "==> %s"\n' "$name" "$label" >&2
    fi
  done

  $ok && pass "$name" || { FAIL=$((FAIL+1)); FAILED_CASES+=("$name"); }
}

test_install_sh_wires_hooks
test_install_sh_wires_hooks_no_settings
test_hooks_install_uninstall_lifecycle
test_install_hooks_updates_stale_paths_after_rename
test_install_hooks_preserves_unrelated_same_basename_hook
test_install_hooks_uninstall_stale_paths_after_rename
test_userpromptsubmit_install_wires_hook
test_userpromptsubmit_uninstall_removes_hook
test_userpromptsubmit_install_idempotent
test_userpromptsubmit_uninstall_preserves_unrelated
test_stop_hook_migration
test_stop_hook_preservation
test_session_stop_install_wires_hook
test_session_stop_uninstall_removes_hook
test_session_stop_install_idempotent
test_session_stop_uninstall_preserves_stop
test_statusline_install_chains_previous
test_statusline_install_chains_previous_with_args
test_statusline_uninstall_restores
test_legacy_pm_left_untouched
test_legacy_stale_symlinks_removed
test_filter_no_match_exits_nonzero() {
  # Verifies --filter with a pattern that matches no cases exits nonzero
  # and emits a diagnostic rather than silently reporting 0 passed.
  # Steps:
  #   1. Invoke test-install.sh --filter with a pattern known to match nothing
  #   2. Assert exit status is nonzero
  #   3. Assert output contains "no tests matched"
  local name="meta/filter-no-match-exits-nonzero"
  should_run "$name" || return 0
  local out status
  out=$(bash "$SCRIPT_DIR/test-install.sh" --filter "__no_such_case_xyz__" 2>&1) && status=$? || status=$?
  if [[ "$status" -ne 0 && "$out" == *"no tests matched"* ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$out"
  fi
}

test_skip_preflight_skips_all_tests
test_filter_no_match_exits_nonzero

if $LIST; then
  printf '%s\n' "${ALL_CASES[@]}"
  exit 0
fi

if [[ -n "$FILTER" && $((PASS + FAIL)) -eq 0 ]]; then
  printf 'no tests matched filter %q — check --list for available case names\n' "$FILTER" >&2
  exit 1
fi

printf '%s passed, %s failed\n' "$PASS" "$FAIL"
if [ "$FAIL" -gt 0 ]; then
  printf 'failed cases: %s\n' "${FAILED_CASES[*]}" >&2
  exit 1
fi
