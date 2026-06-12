#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C.UTF-8

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DOCTOR="$REPO_ROOT/scripts/doctor.sh"
# shellcheck source=scripts/lib/test-harness.sh
. "$SCRIPT_DIR/lib/test-harness.sh"
th_init "$@"

# Whether this platform can create real symlinks. MSYS/Git-Bash without Developer
# Mode copies on `ln -s`, so a pmctl symlink to cli/pmctl becomes a copy that
# doctor (correctly) cannot verify — making an all-OK scenario unreachable.
# Tests that depend on a real pmctl symlink skip there. Probed once.
_TD_CAN_SYMLINK=0
printf 'x' > "$tmp_root/.symlink-probe-target"
if ln -s "$tmp_root/.symlink-probe-target" "$tmp_root/.symlink-probe" 2>/dev/null \
   && [[ -L "$tmp_root/.symlink-probe" ]]; then
  _TD_CAN_SYMLINK=1
fi
rm -f "$tmp_root/.symlink-probe" "$tmp_root/.symlink-probe-target" 2>/dev/null || true

_td_needs_symlink() {
  local name="$1"
  [[ "$_TD_CAN_SYMLINK" == "1" ]] && return 0
  $LIST || printf 'SKIP: %s (no real symlink support; pmctl symlink unavailable)\n' "$name"
  return 1
}

# Whether `chmod -x` actually clears the executable bit. On Windows/MSYS the
# permission is not enforced, so a "non-executable script" scenario can't be set
# up and exec-bit checks don't apply. Probed once.
_TD_CHMOD_X_WORKS=0
printf '#!/bin/sh\n' > "$tmp_root/.chmodx-probe"
chmod +x "$tmp_root/.chmodx-probe" 2>/dev/null || true
chmod -x "$tmp_root/.chmodx-probe" 2>/dev/null || true
[[ ! -x "$tmp_root/.chmodx-probe" ]] && _TD_CHMOD_X_WORKS=1
rm -f "$tmp_root/.chmodx-probe" 2>/dev/null || true

_td_needs_chmod_x() {
  local name="$1"
  [[ "$_TD_CHMOD_X_WORKS" == "1" ]] && return 0
  $LIST || printf 'SKIP: %s (chmod -x not enforced on this platform)\n' "$name"
  return 1
}

add_dispatch_allowlist() {
  # Mirrors dispatch_allowlist_entries() using an explicit home arg for path stripping.
  local home_dir="$1"
  local settings="$home_dir/.claude/settings.json"
  local f rel allow_json
  allow_json="$(
    {
      f="$REPO_ROOT/scripts/codex-dispatch.sh"
      if [[ -f "$f" ]]; then
        rel="${f#"$home_dir/"}"
        printf 'Bash(%s:*)\nBash(~/%s:*)\n' "$f" "$rel"
      fi
      for f in "$REPO_ROOT/adapters"/*/dispatch.sh; do
        [[ -f "$f" ]] || continue
        rel="${f#"$home_dir/"}"
        printf 'Bash(%s:*)\nBash(~/%s:*)\n' "$f" "$rel"
      done
    } | jq -Rn '[inputs]'
  )"
  jq --argjson allow "$allow_json" '.permissions.allow = $allow' \
    "$settings" > "${settings}.tmp"
  mv "${settings}.tmp" "$settings"
}

write_minimal_settings() {
  local home_dir="$1"
  mkdir -p "$home_dir/.claude"
  cat > "$home_dir/.claude/settings.json" <<EOF
{
  "hooks": {
    "PreToolUse": [
      {"matcher": "Edit|Write", "hooks": [{"type": "command", "command": "${REPO_ROOT}/scripts/hook-pm-write-guard.sh"}]}
    ],
    "PostToolUse": [],
    "Stop": [
      {"hooks": [{"type": "command", "command": "${REPO_ROOT}/scripts/hook-log-claude-usage.sh"}]},
      {"hooks": [{"type": "command", "command": "${REPO_ROOT}/scripts/hook-session-summary.sh"}]}
    ],
    "UserPromptSubmit": [
      {"hooks": [{"type": "command", "command": "${REPO_ROOT}/scripts/hook-inject-memory.sh"}]}
    ]
  },
  "statusLine": {"command": "${REPO_ROOT}/scripts/hook-save-rate-limits.sh"}
}
EOF
  add_dispatch_allowlist "$home_dir"
}

write_stale_path_settings() {
  local home_dir="$1"
  mkdir -p "$home_dir/.claude"
  cat > "$home_dir/.claude/settings.json" <<EOF
{
  "hooks": {
    "PreToolUse": [
      {"matcher": "Edit|Write", "hooks": [{"type": "command", "command": "/fake/old-repo/scripts/hook-pm-write-guard.sh"}]},
      {"matcher": "Bash",       "hooks": [{"type": "command", "command": "/fake/old-repo/scripts/hook-codex-bash-guard.sh"}]},
      {"matcher": "Edit|Write", "hooks": [{"type": "command", "command": "/fake/old-repo/scripts/hook-codex-write-guard.sh"}]}
    ],
    "PostToolUse": [],
    "Stop": [
      {"hooks": [{"type": "command", "command": "/fake/old-repo/scripts/hook-log-claude-usage.sh"}]},
      {"hooks": [{"type": "command", "command": "/fake/old-repo/scripts/hook-session-summary.sh"}]}
    ],
    "UserPromptSubmit": [
      {"hooks": [{"type": "command", "command": "/fake/old-repo/scripts/hook-inject-memory.sh"}]}
    ]
  },
  "statusLine": {"command": "/fake/old-repo/scripts/hook-save-rate-limits.sh"}
}
EOF
  add_dispatch_allowlist "$home_dir"
}

write_sibling_prefix_settings() {
  local home_dir="$1" sibling="$2"
  mkdir -p "$home_dir/.claude"
  cat > "$home_dir/.claude/settings.json" <<EOF
{
  "hooks": {
    "PreToolUse": [
      {"matcher": "Edit|Write", "hooks": [{"type": "command", "command": "${sibling}/scripts/hook-pm-write-guard.sh"}]},
      {"matcher": "Bash",       "hooks": [{"type": "command", "command": "${sibling}/scripts/hook-codex-bash-guard.sh"}]},
      {"matcher": "Edit|Write", "hooks": [{"type": "command", "command": "${sibling}/scripts/hook-codex-write-guard.sh"}]}
    ],
    "PostToolUse": [],
    "Stop": [
      {"hooks": [{"type": "command", "command": "${sibling}/scripts/hook-log-claude-usage.sh"}]},
      {"hooks": [{"type": "command", "command": "${sibling}/scripts/hook-session-summary.sh"}]}
    ],
    "UserPromptSubmit": [
      {"hooks": [{"type": "command", "command": "${sibling}/scripts/hook-inject-memory.sh"}]}
    ]
  },
  "statusLine": {"command": "${sibling}/scripts/hook-save-rate-limits.sh"}
}
EOF
  add_dispatch_allowlist "$home_dir"
}

write_full_settings() {
  local home_dir="$1"
  mkdir -p "$home_dir/.claude"
  cat > "$home_dir/.claude/settings.json" <<EOF
{
  "hooks": {
    "PreToolUse": [
      {"matcher": "Edit|Write", "hooks": [{"type": "command", "command": "${REPO_ROOT}/scripts/hook-pm-write-guard.sh"}]},
      {"matcher": "Bash",       "hooks": [{"type": "command", "command": "${REPO_ROOT}/scripts/hook-codex-bash-guard.sh"}]},
      {"matcher": "Edit|Write", "hooks": [{"type": "command", "command": "${REPO_ROOT}/scripts/hook-codex-write-guard.sh"}]}
    ],
    "PostToolUse": [],
    "Stop": [
      {"hooks": [{"type": "command", "command": "${REPO_ROOT}/scripts/hook-log-claude-usage.sh"}]},
      {"hooks": [{"type": "command", "command": "${REPO_ROOT}/scripts/hook-session-summary.sh"}]}
    ],
    "UserPromptSubmit": [
      {"hooks": [{"type": "command", "command": "${REPO_ROOT}/scripts/hook-inject-memory.sh"}]}
    ]
  },
  "statusLine": {"command": "${REPO_ROOT}/scripts/hook-save-rate-limits.sh"}
}
EOF
  add_dispatch_allowlist "$home_dir"
}

create_memory_dir_for_pwd() {
  local home_dir="$1"
  # shellcheck source=scripts/lib/memory.sh
  . "$REPO_ROOT/scripts/lib/memory.sh"
  local encoded
  encoded="$(encode_path "$REPO_ROOT")"
  mkdir -p "$home_dir/.claude/projects/$encoded/memory"
}

write_manifest() {
  local home_dir="$1"
  mkdir -p "$home_dir/.claude/.pm-dispatch"
  printf '{"manifest_version":1}\n' > "$home_dir/.claude/.pm-dispatch/install-manifest.json"
}

make_stub_bin() {
  local bin="$1"
  shift
  mkdir -p "$bin"
  local cmd
  for cmd in "$@"; do
    printf '#!/usr/bin/env bash\nexit 0\n' > "$bin/$cmd"
    chmod +x "$bin/$cmd"
  done
  printf '%s:%s\n' "$bin" "$PATH"
}

link_cmd() {
  local bin="$1" cmd="$2" real
  real="$(command -v "$cmd" 2>/dev/null || true)"
  # Skip shell builtins (command -v returns the bare name, not a path) and
  # non-files — ln -s to a non-file target fails on MSYS. Builtins stay available
  # via bash regardless of PATH. Copy where symlinks are unavailable.
  [[ -n "$real" && -f "$real" ]] || return 0
  ln -sf "$real" "$bin/$cmd" 2>/dev/null || cp "$real" "$bin/$cmd"
}

make_path_without_jq() {
  local bin="$1"
  mkdir -p "$bin"
  link_cmd "$bin" bash
  link_cmd "$bin" dirname
  link_cmd "$bin" pwd
  link_cmd "$bin" readlink
  link_cmd "$bin" uname
  printf '%s\n' "$bin"
}

case_doctor_all_ok_exits_0() {
  # Verifies that doctor exits 0 with 0 FAIL / 0 WARN when all dependencies,
  # hooks (full profile), memory dir, manifest, and frontmatter are healthy.
  #
  # Steps:
  #   1. Write full settings.json (all hooks), memory dir, and manifest.
  #   2. Run doctor --no-color --repo <repo> with claude+codex stubs and a
  #      pmctl symlink resolving to this checkout's cli/pmctl in PATH.
  #   3. Assert exit 0, output contains "0 FAIL" and "0 WARN".
  local name="doctor-all-ok-exits-0"
  should_run "$name" || return 0
  # Needs a real pmctl symlink so doctor reports 0 WARN; on MSYS the symlink is a
  # copy doctor flags, so the all-OK state is unreachable.
  if ! _td_needs_symlink "$name"; then return 0; fi
  local home="$tmp_root/home-all-ok" out status=0 path
  write_full_settings "$home"
  create_memory_dir_for_pwd "$home"
  write_manifest "$home"
  path="$(make_stub_bin "$tmp_root/bin-all-ok" claude codex)"
  # pmctl must resolve to THIS checkout (check_pmctl rejects a foreign pmctl), so
  # install it as a symlink to cli/pmctl rather than a generic stub.
  ln -sf "$REPO_ROOT/cli/pmctl" "$tmp_root/bin-all-ok/pmctl"

  out="$(HOME="$home" CLAUDE_CONFIG_DIR="$home/.claude" PATH="$path" bash "$DOCTOR" --no-color --repo "$REPO_ROOT" 2>&1)" || status=$?
  if [[ "$status" -eq 0 && "$out" == *"0 FAIL"* && "$out" == *"0 WARN"* ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$out"
  fi
}

case_doctor_pmctl_foreign_warns() {
  # Verifies that a foreign pmctl on PATH (one that does NOT resolve to this
  # checkout's cli/pmctl) is reported as a WARN with remediation, even when the
  # rest of the environment is healthy — closing the silent-misconfiguration
  # gap where an unrelated pmctl shadows the installed CLI.
  #
  # Steps:
  #   1. Write full settings.json, memory dir, and manifest (otherwise healthy).
  #   2. Stub claude+codex+pmctl, where pmctl is a plain (foreign) stub, NOT a
  #      symlink to this checkout, and place it FIRST on PATH so it wins.
  #   3. Run doctor --no-color --repo <repo>.
  #   4. Assert exit 0 (warn is non-fatal) and output flags pmctl as not
  #      belonging to this checkout (so the run is not "0 WARN").
  local name="doctor-pmctl-foreign-warns"
  should_run "$name" || return 0
  local home="$tmp_root/home-pmctl-foreign" out status=0 path
  write_full_settings "$home"
  create_memory_dir_for_pwd "$home"
  write_manifest "$home"
  path="$(make_stub_bin "$tmp_root/bin-pmctl-foreign" claude codex pmctl)"

  out="$(HOME="$home" CLAUDE_CONFIG_DIR="$home/.claude" PATH="$path" bash "$DOCTOR" --no-color --repo "$REPO_ROOT" 2>&1)" || status=$?
  if [[ "$status" -eq 0 && "$out" == *"does not belong to this checkout"* && "$out" != *"0 WARN"* ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$out"
  fi
}

case_doctor_hooks_missing_exits_1() {
  # Verifies that doctor exits 1 with [FAIL] when settings.json has no hooks at all.
  #
  # Steps:
  #   1. Write settings.json with an empty hooks object.
  #   2. Run doctor --no-color --repo <repo>.
  #   3. Assert exit 1 and output contains "[FAIL]" and "hooks".
  local name="doctor-hooks-missing-exits-1"
  should_run "$name" || return 0
  local home="$tmp_root/home-no-hooks" out status=0
  mkdir -p "$home/.claude"
  printf '{"hooks":{}}\n' > "$home/.claude/settings.json"

  out="$(HOME="$home" CLAUDE_CONFIG_DIR="$home/.claude" bash "$DOCTOR" --no-color --repo "$REPO_ROOT" 2>&1)" || status=$?
  if [[ "$status" -eq 1 && "$out" == *"[FAIL]"* && "$out" == *"hooks"* ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$out"
  fi
}

case_doctor_settings_missing_exits_1() {
  # Verifies that doctor exits 1 with [FAIL] when settings.json is absent.
  #
  # Steps:
  #   1. Create home with ~/.claude/ directory but no settings.json.
  #   2. Run doctor --no-color --repo <repo>.
  #   3. Assert exit 1 and output contains "[FAIL]" and "settings".
  local name="doctor-settings-missing-exits-1"
  should_run "$name" || return 0
  local home="$tmp_root/home-no-settings" out status=0
  mkdir -p "$home/.claude"

  out="$(HOME="$home" CLAUDE_CONFIG_DIR="$home/.claude" bash "$DOCTOR" --no-color --repo "$REPO_ROOT" 2>&1)" || status=$?
  if [[ "$status" -eq 1 && "$out" == *"[FAIL]"* && "$out" == *"settings"* ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$out"
  fi
}

case_doctor_json_output_valid() {
  # Verifies that --json mode emits only valid JSON Lines with no human-readable tags.
  #
  # Steps:
  #   1. Write settings.json with empty hooks; run doctor --json --repo <repo>.
  #   2. Parse every non-empty output line through jq.
  #   3. Assert no line is invalid JSON and none contains "[OK]"; last line has "summary":true.
  local name="doctor-json-output-valid"
  should_run "$name" || return 0
  if ! command -v jq >/dev/null 2>&1; then
    pass "$name (jq not on PATH - validation skipped)"
    return
  fi

  local home="$tmp_root/home-json-test" out line last_line="" status=0
  mkdir -p "$home/.claude"
  printf '{"hooks":{}}\n' > "$home/.claude/settings.json"
  out="$(HOME="$home" CLAUDE_CONFIG_DIR="$home/.claude" bash "$DOCTOR" --json --repo "$REPO_ROOT" 2>/dev/null)" || status=$?

  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    if ! jq . >/dev/null 2>&1 <<< "$line"; then
      fail "$name" "invalid JSON line: $line"
      return
    fi
    if [[ "$line" == *"[OK]"* ]]; then
      fail "$name" "human tag leaked into JSON: $line"
      return
    fi
    last_line="$line"
  done <<< "$out"

  if [[ "$status" -eq 1 && "$last_line" == *'"summary":true'* ]]; then
    pass "$name"
  else
    fail "$name" "status=$status last_line=$last_line out=$out"
  fi
}

case_doctor_quiet_no_ok_lines() {
  # Verifies that --quiet suppresses OK lines while still printing the Summary.
  #
  # Steps:
  #   1. Write minimal settings.json.
  #   2. Run doctor --quiet --no-color --repo <repo>.
  #   3. Assert output has no "[OK]" and contains "Summary:".
  local name="doctor-quiet-no-ok-lines"
  should_run "$name" || return 0
  local home="$tmp_root/home-quiet" out status=0
  write_minimal_settings "$home"

  out="$(HOME="$home" CLAUDE_CONFIG_DIR="$home/.claude" bash "$DOCTOR" --quiet --no-color --repo "$REPO_ROOT" 2>/dev/null)" || status=$?
  if [[ "$out" != *"[OK]"* && "$out" == *"Summary:"* ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$out"
  fi
}

case_doctor_jq_missing_exits_1() {
  # Verifies that doctor exits 1 with [FAIL] when jq is not on PATH.
  #
  # Steps:
  #   1. Build a PATH that contains core tools but not jq.
  #   2. Run doctor --no-color --repo <repo>.
  #   3. Assert exit 1 and output contains "[FAIL]" and "jq".
  local name="doctor-jq-missing-exits-1"
  should_run "$name" || return 0
  if ! command -v jq >/dev/null 2>&1; then
    pass "$name (jq not on PATH - test trivially satisfied)"
    return
  fi

  local path home="$tmp_root/home-jq-missing" out status=0 bash_real
  bash_real="$(command -v bash)"
  path="$(make_path_without_jq "$tmp_root/bin-no-jq")"
  mkdir -p "$home/.claude"
  printf '{}\n' > "$home/.claude/settings.json"

  out="$(HOME="$home" CLAUDE_CONFIG_DIR="$home/.claude" PATH="$path" "$bash_real" "$DOCTOR" --no-color --repo "$REPO_ROOT" 2>&1)" || status=$?
  if [[ "$status" -eq 1 && "$out" == *"[FAIL]"* && "$out" == *"jq"* ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$out"
  fi
}

case_doctor_warn_only_exits_0() {
  # Verifies that doctor exits 0 when all checks are WARN or better (no FAIL).
  #
  # Steps:
  #   1. Write minimal settings and manifest; build a PATH with no claude/codex
  #      (those checks emit WARN, not FAIL).
  #   2. Run doctor --no-color --repo <repo>.
  #   3. Assert exit 0 and output contains "0 FAIL".
  local name="doctor-warn-only-exits-0"
  should_run "$name" || return 0
  # Runs doctor under an isolated PATH of linked coreutils; on MSYS those are
  # copies and a copied bash/binary can't launch (missing DLLs), so the isolated
  # invocation can't run. Needs real symlinks.
  if ! _td_needs_symlink "$name"; then return 0; fi
  local home="$tmp_root/home-warn-only" out status=0 path bin cmd
  write_minimal_settings "$home"
  write_manifest "$home"
  # PATH without claude or codex -> those checks return WARN, not FAIL.
  bin="$tmp_root/bin-warn-only"
  mkdir -p "$bin"
  for cmd in bash dirname pwd readlink uname jq sed grep awk python3 tr; do
    link_cmd "$bin" "$cmd"
  done
  [[ -x "$bin/jq" ]] || { pass "$name (jq not available - skip)"; return; }
  [[ -x "$bin/python3" ]] || { pass "$name (python3 not available - skip)"; return; }
  path="$bin"

  out="$(HOME="$home" CLAUDE_CONFIG_DIR="$home/.claude" PATH="$path" bash "$DOCTOR" --no-color --repo "$REPO_ROOT" 2>&1)" || status=$?
  if [[ "$status" -eq 0 && "$out" == *"0 FAIL"* ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$out"
  fi
}

case_doctor_repo_from_different_cwd() {
  # Verifies that --repo resolves memory dir relative to REPO_ROOT, not CWD.
  #
  # Steps:
  #   1. Write full settings and create memory dir encoded from REPO_ROOT path.
  #   2. cd to an unrelated directory; run doctor --no-color --repo <REPO_ROOT>.
  #   3. Assert output contains "memory directory exists".
  local name="doctor-repo-from-different-cwd"
  should_run "$name" || return 0
  local home="$tmp_root/home-repo-cwd" out status=0
  write_full_settings "$home"
  write_manifest "$home"
  # Create memory dir for REPO_ROOT path, not for tmp_root.
  # shellcheck source=scripts/lib/memory.sh
  . "$REPO_ROOT/scripts/lib/memory.sh"
  local encoded
  encoded="$(encode_path "$REPO_ROOT")"
  mkdir -p "$home/.claude/projects/$encoded/memory"

  local other_cwd="$tmp_root/other-cwd"
  mkdir -p "$other_cwd"
  local path
  path="$(make_stub_bin "$tmp_root/bin-repo-cwd" claude codex)"

  out="$(cd "$other_cwd" && HOME="$home" CLAUDE_CONFIG_DIR="$home/.claude" PATH="$path" bash "$DOCTOR" --no-color --repo "$REPO_ROOT" 2>&1)" || status=$?
  if [[ "$out" == *"memory directory exists"* ]]; then
    pass "$name"
  else
    fail "$name" "expected memory-dir ok for REPO_ROOT; status=$status out=$out"
  fi
}

case_doctor_frontmatter_lint_ok() {
  # Verifies that the frontmatter-lint check passes on the real repo's agents/.
  #
  # Steps:
  #   1. Write full settings and manifest; run doctor --no-color --repo <repo>.
  #   2. Assert exit 0 and output contains "frontmatter lint passed".
  local name="doctor-frontmatter-lint-ok"
  should_run "$name" || return 0
  local home="$tmp_root/home-frontmatter" out status=0 path
  write_full_settings "$home"
  write_manifest "$home"
  path="$(make_stub_bin "$tmp_root/bin-frontmatter" claude codex)"

  out="$(HOME="$home" CLAUDE_CONFIG_DIR="$home/.claude" PATH="$path" bash "$DOCTOR" --no-color --repo "$REPO_ROOT" 2>&1)" || status=$?
  if [[ "$status" -eq 0 && "$out" == *"frontmatter lint passed"* ]]; then
    pass "$name"
  else
    fail "$name" "expected frontmatter-lint check in output; status=$status out=$out"
  fi
}

case_doctor_help_exits_0() {
  # Verifies that --help exits 0 and prints Usage.
  #
  # Steps:
  #   1. Run doctor --help.
  #   2. Assert exit 0 and output contains "Usage:".
  local name="doctor-help-exits-0"
  should_run "$name" || return 0
  local out status=0
  out="$(bash "$DOCTOR" --help 2>&1)" || status=$?
  if [[ "$status" -eq 0 && "$out" == *"Usage:"* ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$out"
  fi
}

case_doctor_unknown_flag() {
  # Verifies that an unrecognised flag exits 2 with an "unknown flag" message.
  #
  # Steps:
  #   1. Run doctor --unknown-flag-xyz.
  #   2. Assert exit 2 and output contains "unknown flag".
  local name="doctor-unknown-flag"
  should_run "$name" || return 0
  local out status=0
  out="$(bash "$DOCTOR" --unknown-flag-xyz 2>&1)" || status=$?
  if [[ "$status" -eq 2 && "$out" == *"unknown flag"* ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$out"
  fi
}

case_doctor_repo_missing_arg() {
  # Verifies that --repo with no path argument exits 2.
  #
  # Steps:
  #   1. Run doctor --repo (no following argument).
  #   2. Assert exit 2.
  local name="doctor-repo-missing-arg"
  should_run "$name" || return 0
  local out status=0
  out="$(bash "$DOCTOR" --repo 2>&1)" || status=$?
  if [[ "$status" -eq 2 ]]; then
    pass "$name"
  else
    fail "$name" "expected exit 2 for --repo with no arg; status=$status out=$out"
  fi
}

case_doctor_scripts_not_executable_fail() {
  # Verifies that doctor reports [FAIL] when a managed script is not executable.
  #
  # Steps:
  #   1. Copy repo scripts to a temp dir; chmod -x hook-pm-write-guard.sh.
  #   2. Run doctor --no-color --repo <temp-dir>.
  #   3. Assert exit 1 and output contains "[FAIL]" and "non-executable".
  local name="doctor-scripts-not-executable-fail"
  should_run "$name" || return 0
  # Can't stage a non-executable script where chmod -x is a no-op (Windows/MSYS).
  if ! _td_needs_chmod_x "$name"; then return 0; fi
  local home="$tmp_root/home-no-exec" out status=0

  # Create a writable copy of the repo scripts dir to safely toggle perms.
  local fake_repo="$tmp_root/fake-repo-no-exec"
  mkdir -p "$fake_repo/scripts"
  cp -r "$REPO_ROOT/scripts/lib" "$fake_repo/scripts/" 2>/dev/null || true
  for f in "$REPO_ROOT/scripts/"*.sh; do
    cp "$f" "$fake_repo/scripts/$(basename "$f")"
    chmod +x "$fake_repo/scripts/$(basename "$f")"
  done
  chmod -x "$fake_repo/scripts/hook-pm-write-guard.sh"

  write_minimal_settings "$home"
  write_manifest "$home"

  out="$(HOME="$home" CLAUDE_CONFIG_DIR="$home/.claude" bash "$DOCTOR" --no-color --repo "$fake_repo" 2>&1)" || status=$?
  if [[ "$status" -eq 1 && "$out" == *"[FAIL]"* && "$out" == *"non-executable"* ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$out"
  fi
}

case_doctor_manifest_missing_warn() {
  # Verifies that a missing install-manifest.json emits [WARN] but not [FAIL].
  #
  # Steps:
  #   1. Write full settings; omit the install-manifest.json file.
  #   2. Run doctor --no-color --repo <repo>.
  #   3. Assert exit 0, output contains "[WARN]" and "manifest".
  local name="doctor-manifest-missing-warn"
  should_run "$name" || return 0
  local home="$tmp_root/home-no-manifest" out status=0 path
  write_full_settings "$home"
  path="$(make_stub_bin "$tmp_root/bin-no-manifest" claude codex)"

  out="$(HOME="$home" CLAUDE_CONFIG_DIR="$home/.claude" PATH="$path" bash "$DOCTOR" --no-color --repo "$REPO_ROOT" 2>&1)" || status=$?
  if [[ "$out" == *"manifest"* && "$out" == *"[WARN]"* && "$status" -eq 0 ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$out"
  fi
}

case_doctor_manifest_bad_version_warn() {
  # Verifies that an install-manifest with an unrecognised manifest_version emits [WARN].
  #
  # Steps:
  #   1. Write full settings and manifest with manifest_version: 99.
  #   2. Run doctor --no-color --repo <repo>.
  #   3. Assert exit 0, output contains "[WARN]" and "manifest".
  local name="doctor-manifest-bad-version-warn"
  should_run "$name" || return 0
  if ! command -v jq >/dev/null 2>&1; then
    pass "$name (jq not available - skip)"
    return
  fi
  local home="$tmp_root/home-bad-manifest" out status=0 path
  write_full_settings "$home"
  mkdir -p "$home/.claude/.pm-dispatch"
  printf '{"manifest_version":99}\n' > "$home/.claude/.pm-dispatch/install-manifest.json"
  path="$(make_stub_bin "$tmp_root/bin-bad-manifest" claude codex)"

  out="$(HOME="$home" CLAUDE_CONFIG_DIR="$home/.claude" PATH="$path" bash "$DOCTOR" --no-color --repo "$REPO_ROOT" 2>&1)" || status=$?
  if [[ "$out" == *"manifest"* && "$out" == *"[WARN]"* && "$status" -eq 0 ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$out"
  fi
}

case_doctor_malformed_settings_fail() {
  # Verifies that non-JSON settings.json causes [FAIL] (not just [WARN]),
  # non-zero exit, and that hook checks are also reported as failed.
  #
  # Steps:
  #   1. Write "not json at all" to settings.json.
  #   2. Run doctor --no-color --repo <repo>.
  #   3. Assert exit 1, output has [FAIL] with "settings" and "cannot check hooks".
  local name="doctor-malformed-settings-fail"
  should_run "$name" || return 0
  if ! command -v jq >/dev/null 2>&1; then
    pass "$name (jq not available - skip)"
    return
  fi
  local home="$tmp_root/home-bad-settings" out status=0 path
  mkdir -p "$home/.claude"
  printf 'not json at all\n' > "$home/.claude/settings.json"
  write_manifest "$home"
  path="$(make_stub_bin "$tmp_root/bin-bad-settings" claude codex)"

  out="$(HOME="$home" CLAUDE_CONFIG_DIR="$home/.claude" PATH="$path" bash "$DOCTOR" --no-color --repo "$REPO_ROOT" 2>&1)" || status=$?
  if [[ "$status" -eq 1 && "$out" == *"[FAIL]"* && "$out" == *"settings"* && "$out" == *"cannot check hooks"* && "$out" == *"Summary:"* ]]; then
    pass "$name"
  else
    fail "$name" "expected exit 1 with [FAIL] and 'cannot check hooks'; status=$status out=$out"
  fi
}

case_doctor_malformed_settings_json() {
  # Verifies that --json mode reports settings-file as "fail" and summary
  # exit_code as 1 when settings.json is not valid JSON.
  #
  # Steps:
  #   1. Write malformed settings.json.
  #   2. Run doctor --json --repo <repo>.
  #   3. Assert settings-file JSON line has "status":"fail" and summary has "exit_code":1.
  local name="doctor-malformed-settings-json"
  should_run "$name" || return 0
  if ! command -v jq >/dev/null 2>&1; then
    pass "$name (jq not available - skip)"
    return
  fi
  local home="$tmp_root/home-bad-settings-json" out status=0 path
  mkdir -p "$home/.claude"
  printf 'not json at all\n' > "$home/.claude/settings.json"
  write_manifest "$home"
  path="$(make_stub_bin "$tmp_root/bin-bad-settings-json" claude codex)"

  out="$(HOME="$home" CLAUDE_CONFIG_DIR="$home/.claude" PATH="$path" bash "$DOCTOR" --json --repo "$REPO_ROOT" 2>&1)" || status=$?
  local settings_status exit_code
  settings_status="$(printf '%s\n' "$out" | jq -r 'select(.check == "settings-file") | .status' 2>/dev/null || true)"
  exit_code="$(printf '%s\n' "$out" | jq -r 'select(.summary == true) | .exit_code' 2>/dev/null || true)"
  if [[ "$settings_status" == "fail" && "$exit_code" == "1" ]]; then
    pass "$name"
  else
    fail "$name" "expected settings-file=fail exit_code=1; got settings_status=$settings_status exit_code=$exit_code status=$status"
  fi
}

case_doctor_profile_minimal_skip_codex_hooks() {
  # Verifies that --profile minimal skips codex-only hooks even when codex is in PATH.
  #
  # Steps:
  #   1. Write minimal settings (no codex hooks); add codex stub to PATH so
  #      auto-detection would otherwise select full profile.
  #   2. Run doctor --no-color --repo <repo> --profile minimal.
  #   3. Assert exit 0 and no [FAIL].
  local name="doctor-profile-minimal-skip-codex-hooks"
  should_run "$name" || return 0
  if ! command -v jq >/dev/null 2>&1; then
    pass "$name (jq not available - skip)"
    return
  fi
  # Settings only has minimal hooks (no codex hooks). PATH includes a codex stub
  # so that auto-detection would pick up full profile and produce a FAIL.
  # With --profile minimal, doctor must not check codex hooks -> exit 0, no FAIL.
  local home="$tmp_root/home-profile-minimal" out status=0 path
  write_minimal_settings "$home"
  create_memory_dir_for_pwd "$home"
  write_manifest "$home"
  path="$(make_stub_bin "$tmp_root/bin-profile-minimal" claude codex)"

  out="$(HOME="$home" CLAUDE_CONFIG_DIR="$home/.claude" PATH="$path" bash "$DOCTOR" --no-color --repo "$REPO_ROOT" --profile minimal 2>&1)" || status=$?
  if [[ "$status" -eq 0 && "$out" != *"[FAIL]"* && "$out" == *"Summary:"* ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$out"
  fi
}

case_doctor_windows_auto_profile_codex_on_path() {
  # Verifies that PROFILE=auto selects minimal on Windows even when codex is in PATH.
  # Without the Windows platform check, codex_available()=true → _want_full=1 →
  # doctor checks codex hooks → FAIL (minimal settings has none). The fix in
  # detect_hook_profile() must force _want_full=0 when detect_platform==windows.
  #
  # Steps:
  #   1. Write minimal settings (no codex hooks); create memory dir and manifest.
  #   2. Put a codex stub on PATH (auto-detection would pick full without Windows check).
  #   3. Run doctor --no-color --repo <repo> with PM_DISPATCH_PLATFORM=windows (no --profile).
  #   4. Assert exit 0 and no [FAIL] — codex hooks must not be required on Windows auto.
  local name="doctor-windows-auto-profile-codex-on-path"
  should_run "$name" || return 0
  if ! command -v jq >/dev/null 2>&1; then
    pass "$name (jq not available - skip)"
    return
  fi
  local home="$tmp_root/home-win-auto-profile" out status=0 path
  write_minimal_settings "$home"
  create_memory_dir_for_pwd "$home"
  write_manifest "$home"
  path="$(make_stub_bin "$tmp_root/bin-win-auto-profile" claude codex)"

  out="$(HOME="$home" CLAUDE_CONFIG_DIR="$home/.claude" PATH="$path" \
    PM_DISPATCH_PLATFORM=windows \
    bash "$DOCTOR" --no-color --repo "$REPO_ROOT" 2>&1)" || status=$?
  if [[ "$status" -eq 0 && "$out" != *"[FAIL]"* && "$out" == *"Summary:"* ]]; then
    pass "$name"
  else
    fail "$name" "expected exit 0 with no FAIL (Windows auto=minimal); status=$status out=$out"
  fi
}

test_dispatch_allowlist_ok() {
  local name="test_dispatch_allowlist_ok"
  should_run "$name" || return 0
  # Verifies that doctor.sh reports pass when all four dispatch allowlist entries
  # (shim abs/tilde + adapter abs/tilde) are present in settings.json.
  #
  # Steps:
  #   1. Create a home dir with write_minimal_settings (adds all 4 entries via add_dispatch_allowlist).
  #   2. Run doctor --profile minimal.
  #   3. Assert exit 0 and "dispatch allowlist present" in output.
  if ! command -v jq >/dev/null 2>&1; then
    pass "$name (jq not available - skip)"
    return
  fi
  local home="$tmp_root/home-dispatch-allowlist-ok" out status=0 path
  write_minimal_settings "$home"
  create_memory_dir_for_pwd "$home"
  write_manifest "$home"
  path="$(make_stub_bin "$tmp_root/bin-dispatch-allowlist-ok" claude)"

  out="$(HOME="$home" CLAUDE_CONFIG_DIR="$home/.claude" PATH="$path" \
    bash "$DOCTOR" --no-color --repo "$REPO_ROOT" --profile minimal 2>&1)" || status=$?
  if [[ "$status" -eq 0 && "$out" == *"dispatch allowlist present"* && "$out" != *"dispatch allowlist incomplete or missing"* ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$out"
  fi
}

test_dispatch_allowlist_missing() {
  local name="test_dispatch_allowlist_missing"
  should_run "$name" || return 0
  # Verifies that doctor.sh reports fail when all dispatch allowlist entries are absent.
  #
  # Steps:
  #   1. Create a home dir with write_minimal_settings then remove permissions.allow entirely.
  #   2. Run doctor --profile minimal.
  #   3. Assert exit 1 and "[FAIL]" + "dispatch allowlist incomplete or missing" + install.sh hint.
  if ! command -v jq >/dev/null 2>&1; then
    pass "$name (jq not available - skip)"
    return
  fi
  local home="$tmp_root/home-dispatch-allowlist-missing" out status=0 path
  write_minimal_settings "$home"
  jq 'del(.permissions.allow)' "$home/.claude/settings.json" > "$home/.claude/settings.json.tmp"
  mv "$home/.claude/settings.json.tmp" "$home/.claude/settings.json"
  create_memory_dir_for_pwd "$home"
  write_manifest "$home"
  path="$(make_stub_bin "$tmp_root/bin-dispatch-allowlist-missing" claude)"

  out="$(HOME="$home" CLAUDE_CONFIG_DIR="$home/.claude" PATH="$path" \
    bash "$DOCTOR" --no-color --repo "$REPO_ROOT" --profile minimal 2>&1)" || status=$?
  if [[ "$status" -eq 1 && "$out" == *"[FAIL]"* && "$out" == *"dispatch allowlist incomplete or missing"* && "$out" == *"bash '${REPO_ROOT}/install.sh'"* ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$out"
  fi
}

test_dispatch_allowlist_adapter_absent() {
  local name="test_dispatch_allowlist_adapter_absent"
  should_run "$name" || return 0
  # Verifies that doctor.sh reports fail when shim entries are present but adapter entries absent.
  #
  # Steps:
  #   1. Create a home dir with write_minimal_settings (all 4 entries), then remove
  #      only the adapters/codex entries via jq del.
  #   2. Run doctor --profile minimal.
  #   3. Assert exit 1 and "[FAIL]" + "dispatch allowlist" in output.
  if ! command -v jq >/dev/null 2>&1; then
    pass "$name (jq not available - skip)"
    return
  fi
  local home="$tmp_root/home-dispatch-allowlist-adapter-absent" out status=0 path
  write_minimal_settings "$home"
  jq 'del(.permissions.allow[] | select(contains("adapters/codex")))' \
    "$home/.claude/settings.json" > "$home/.claude/settings.json.tmp"
  mv "$home/.claude/settings.json.tmp" "$home/.claude/settings.json"
  create_memory_dir_for_pwd "$home"
  write_manifest "$home"
  path="$(make_stub_bin "$tmp_root/bin-dispatch-allowlist-adapter-absent" claude)"

  out="$(HOME="$home" CLAUDE_CONFIG_DIR="$home/.claude" PATH="$path" \
    bash "$DOCTOR" --no-color --repo "$REPO_ROOT" --profile minimal 2>&1)" || status=$?
  if [[ "$status" -eq 1 && "$out" == *"[FAIL]"* && "$out" == *"dispatch allowlist"* ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$out"
  fi
}

test_dispatch_allowlist_claude_adapter_absent() {
  local name="test_dispatch_allowlist_claude_adapter_absent"
  should_run "$name" || return 0
  # Proves doctor derives entries from dispatch_allowlist_entries() and therefore
  # checks all adapters, not just the codex shim: when settings.json has shim +
  # codex entries but is missing the claude adapter entries, doctor must report
  # [FAIL].
  #
  # Steps:
  #   1. write_minimal_settings (populates all entries via add_dispatch_allowlist).
  #   2. Remove only adapters/claude entries from permissions.allow via jq.
  #   3. Run doctor --profile minimal.
  #   4. Assert exit 1 + "[FAIL]" + "dispatch allowlist".
  if ! command -v jq >/dev/null 2>&1; then
    pass "$name (jq not available - skip)"; return
  fi
  # Skip if adapters/claude/dispatch.sh does not exist in this tree.
  if [[ ! -f "$REPO_ROOT/adapters/claude/dispatch.sh" ]]; then
    pass "$name (adapters/claude/dispatch.sh absent - skip)"; return
  fi
  local home="$tmp_root/home-claude-adapter-absent" out status=0 path
  write_minimal_settings "$home"
  jq 'del(.permissions.allow[] | select(contains("adapters/claude")))' \
    "$home/.claude/settings.json" > "$home/.claude/settings.json.tmp"
  mv "$home/.claude/settings.json.tmp" "$home/.claude/settings.json"
  create_memory_dir_for_pwd "$home"
  write_manifest "$home"
  path="$(make_stub_bin "$tmp_root/bin-claude-adapter-absent" claude)"

  out="$(HOME="$home" CLAUDE_CONFIG_DIR="$home/.claude" PATH="$path" \
    bash "$DOCTOR" --no-color --repo "$REPO_ROOT" --profile minimal 2>&1)" || status=$?
  if [[ "$status" -eq 1 && "$out" == *"[FAIL]"* && "$out" == *"dispatch allowlist"* ]]; then
    pass "$name"
  else
    fail "$name" "expected [FAIL] for missing claude adapter entries; status=$status out=$out"
  fi
}

test_dispatch_allowlist_copymode_no_lib_fail() {
  local name="test_dispatch_allowlist_copymode_no_lib_fail"
  should_run "$name" || return 0
  # Verifies that in copy-mode (lib/ absent), doctor still reports [FAIL] for
  # a missing dispatch allowlist — not [WARN]. The inline fallback must keep
  # the check concrete.
  #
  # Steps:
  #   1. Copy doctor.sh to a temp dir with NO lib/ subdirectory.
  #   2. Create a home with settings.json that has NO permissions.allow.
  #   3. Run the copied doctor.sh.
  #   4. Assert exit 1 and "[FAIL]" + "dispatch allowlist" (not "[WARN]").
  if ! command -v jq >/dev/null 2>&1; then
    pass "$name (jq not available - skip)"
    return
  fi
  local copydir="$tmp_root/copy-scripts-allowlist-fail"
  mkdir -p "$copydir"
  cp "$DOCTOR" "$copydir/doctor.sh"

  local home="$tmp_root/home-copymode-allowlist-fail" out status=0 path
  write_minimal_settings "$home"
  jq 'del(.permissions.allow)' "$home/.claude/settings.json" > "$home/.claude/settings.json.tmp"
  mv "$home/.claude/settings.json.tmp" "$home/.claude/settings.json"
  create_memory_dir_for_pwd "$home"
  write_manifest "$home"
  path="$(make_stub_bin "$tmp_root/bin-copymode-allowlist-fail" claude)"

  out="$(HOME="$home" CLAUDE_CONFIG_DIR="$home/.claude" PATH="$path" \
    bash "$copydir/doctor.sh" --no-color --repo "$REPO_ROOT" 2>&1)" || status=$?

  # Check that dispatch allowlist produced [FAIL] (not skipped or warned).
  # Avoid pattern *"[WARN]"*"dispatch allowlist"* because * matches newlines —
  # other [WARN] lines (e.g. "codex not found") would falsely trigger it.
  if [[ "$status" -eq 1 && "$out" == *"[FAIL]"*"dispatch allowlist"* ]]; then
    pass "$name"
  else
    fail "$name" "expected exit 1 with [FAIL] dispatch allowlist in copy-mode; status=$status out=$out"
  fi
}

case_doctor_profile_missing_arg_exits_2() {
  # Verifies that --profile with no following argument exits 2 with an error message.
  #
  # Steps:
  #   1. Run doctor --profile (no value follows).
  #   2. Assert exit 2.
  local name="doctor-profile-missing-arg-exits-2"
  should_run "$name" || return 0
  local out status=0
  out="$(bash "$DOCTOR" --profile 2>&1)" || status=$?
  if [[ "$status" -eq 2 ]]; then
    pass "$name"
  else
    fail "$name" "expected exit 2 for --profile with no arg; status=$status out=$out"
  fi
}

case_doctor_profile_invalid_value_exits_2() {
  # Verifies that --profile with an unrecognised value exits 2 with an error message.
  #
  # Steps:
  #   1. Run doctor --profile bogus.
  #   2. Assert exit 2 and output contains "auto, minimal, or full".
  local name="doctor-profile-invalid-value-exits-2"
  should_run "$name" || return 0
  local out status=0
  out="$(bash "$DOCTOR" --profile bogus 2>&1)" || status=$?
  if [[ "$status" -eq 2 && "$out" == *"auto, minimal, or full"* ]]; then
    pass "$name"
  else
    fail "$name" "expected exit 2 + usage message; status=$status out=$out"
  fi
}

case_doctor_hook_inventory_parity() {
  # CC-224 parity guard: managed hook basenames in doctor.sh must match those
  # in install-hooks.sh. Also asserts codex-only hooks appear only in the
  # full-profile section of doctor.sh, not the base hooks array.
  local name="doctor-hook-inventory-parity"
  should_run "$name" || return 0
  local doctor_hooks install_hooks
  doctor_hooks="$(grep -oE 'hook-[a-z-]+\.sh' "$DOCTOR" | sort -u)"
  install_hooks="$(grep -oE 'hook-[a-z-]+\.sh' "$REPO_ROOT/scripts/install-hooks.sh" | sort -u)"
  if [[ "$doctor_hooks" != "$install_hooks" ]]; then
    fail "$name" "hook inventory mismatch between doctor.sh and install-hooks.sh:
doctor.sh:     $(printf '%s' "$doctor_hooks" | tr '\n' ' ')
install-hooks: $(printf '%s' "$install_hooks" | tr '\n' ' ')"
    return
  fi
  # Codex-only hooks must appear in the full-profile section of doctor.sh,
  # not in the base hooks array (lines before the full) branch).
  local codex_in_base
  codex_in_base="$(awk '/^  local -a hooks=\(/,/^  \)/' "$DOCTOR" | grep -oE 'hook-codex-[a-z-]+\.sh' || true)"
  if [[ -n "$codex_in_base" ]]; then
    fail "$name" "codex-only hooks found in base hooks array (should be full-profile only): $codex_in_base"
    return
  fi
  pass "$name"
}

case_doctor_windows_path_hooks_present() {
  # Verifies that hook commands stored in Windows backslash form
  # (e.g. C:\path\scripts\hook-pm-write-guard.sh) are correctly identified
  # as present by hook_present(). Without normalize_path in hook_present(),
  # split("/") fails and all hooks are reported missing.
  #
  # Steps:
  #   1. Write settings.json with a minimal full-profile hook set using
  #      Windows backslash paths pointing at a fake "C:\pm-dispatch\scripts\" root.
  #   2. Run doctor --no-color --repo <repo>.
  #   3. Assert exit 0 (hooks pass, not fail for missing).
  local name="doctor-windows-path-hooks-present"
  should_run "$name" || return 0
  if ! command -v jq >/dev/null 2>&1; then
    pass "$name (jq not available - skip)"
    return
  fi
  local home="$tmp_root/home-win-present"
  local win_root="C:\\pm-dispatch"
  mkdir -p "$home/.claude/.pm-dispatch"
  # Write settings with Windows backslash paths for minimal hook set
  cat > "$home/.claude/settings.json" <<'EOSETTINGS'
{
  "hooks": {
    "PreToolUse": [
      {"matcher": "Edit|Write", "hooks": [{"type": "command", "command": "C:\\pm-dispatch\\scripts\\hook-pm-write-guard.sh"}]}
    ],
    "PostToolUse": [],
    "Stop": [
      {"hooks": [{"type": "command", "command": "C:\\pm-dispatch\\scripts\\hook-log-claude-usage.sh"}]},
      {"hooks": [{"type": "command", "command": "C:\\pm-dispatch\\scripts\\hook-session-summary.sh"}]}
    ],
    "UserPromptSubmit": [
      {"hooks": [{"type": "command", "command": "C:\\pm-dispatch\\scripts\\hook-inject-memory.sh"}]}
    ]
  },
  "statusLine": {"command": "C:\\pm-dispatch\\scripts\\hook-save-rate-limits.sh"}
}
EOSETTINGS
  add_dispatch_allowlist "$home"
  printf '{"manifest_version":1}\n' > "$home/.claude/.pm-dispatch/install-manifest.json"
  local path out status=0
  path="$(make_stub_bin "$tmp_root/bin-win-present" claude)"
  out="$(HOME="$home" CLAUDE_CONFIG_DIR="$home/.claude" PATH="$path" \
    bash "$DOCTOR" --no-color --profile minimal --repo "$REPO_ROOT" 2>&1)" || status=$?
  if [[ "$status" -eq 0 && "$out" != *"missing hooks"* && "$out" != *"[FAIL]"* ]]; then
    pass "$name"
  else
    fail "$name" "expected exit 0 with no missing-hooks FAIL; status=$status out=$out"
  fi
}

case_doctor_windows_path_hooks_stale() {
  # Verifies that hook commands in Windows backslash form pointing at a
  # DIFFERENT checkout root are detected as stale by stale_hook_commands().
  # Without normalize_path applied before split("/"), the parent-directory
  # check fails and the stale path is silently ignored.
  #
  # Steps:
  #   1. Write settings.json with Windows paths pointing at "C:\other-repo\".
  #   2. Run doctor --no-color --repo <this-repo>.
  #   3. Assert output contains stale-path warning.
  local name="doctor-windows-path-hooks-stale"
  should_run "$name" || return 0
  if ! command -v jq >/dev/null 2>&1; then
    pass "$name (jq not available - skip)"
    return
  fi
  local home="$tmp_root/home-win-stale"
  mkdir -p "$home/.claude/.pm-dispatch"
  cat > "$home/.claude/settings.json" <<'EOSETTINGS'
{
  "hooks": {
    "PreToolUse": [
      {"matcher": "Edit|Write", "hooks": [{"type": "command", "command": "C:\\other-repo\\scripts\\hook-pm-write-guard.sh"}]}
    ],
    "PostToolUse": [],
    "Stop": [
      {"hooks": [{"type": "command", "command": "C:\\other-repo\\scripts\\hook-log-claude-usage.sh"}]},
      {"hooks": [{"type": "command", "command": "C:\\other-repo\\scripts\\hook-session-summary.sh"}]}
    ],
    "UserPromptSubmit": [
      {"hooks": [{"type": "command", "command": "C:\\other-repo\\scripts\\hook-inject-memory.sh"}]}
    ]
  },
  "statusLine": {"command": "C:\\other-repo\\scripts\\hook-save-rate-limits.sh"}
}
EOSETTINGS
  add_dispatch_allowlist "$home"
  printf '{"manifest_version":1}\n' > "$home/.claude/.pm-dispatch/install-manifest.json"
  local path out status=0
  path="$(make_stub_bin "$tmp_root/bin-win-stale" claude)"
  out="$(HOME="$home" CLAUDE_CONFIG_DIR="$home/.claude" PATH="$path" \
    bash "$DOCTOR" --no-color --profile minimal --repo "$REPO_ROOT" 2>&1)" || status=$?
  if [[ "$out" == *"hook(s) wired from a different checkout"* ]]; then
    pass "$name"
  else
    fail "$name" "expected stale-path warning for Windows backslash hooks; status=$status out=$out"
  fi
}

case_doctor_stale_hook_path_warns() {
  # Verifies that doctor emits [WARN] when hook commands point at a different
  # checkout (basename matches but path prefix != REPO_ROOT).
  #
  # Steps:
  #   1. Write settings.json with all managed hooks wired from /fake/old-repo/scripts/.
  #   2. Run doctor --no-color --repo <REPO_ROOT> (current checkout).
  #   3. Assert exit 0 (hooks technically present), output contains [WARN] and
  #      "different checkout".
  local name="doctor-stale-hook-path-warns"
  should_run "$name" || return 0
  if ! command -v jq >/dev/null 2>&1; then
    pass "$name (jq not available - skip)"
    return
  fi
  local home="$tmp_root/home-stale-hooks" out status=0 path
  write_stale_path_settings "$home"
  create_memory_dir_for_pwd "$home"
  write_manifest "$home"
  path="$(make_stub_bin "$tmp_root/bin-stale-hooks" claude)"

  out="$(HOME="$home" CLAUDE_CONFIG_DIR="$home/.claude" PATH="$path" bash "$DOCTOR" --no-color --repo "$REPO_ROOT" 2>&1)" || status=$?
  if [[ "$status" -eq 0 && "$out" == *"[WARN]"* && "$out" == *"different checkout"* ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$out"
  fi
}

case_doctor_symlink_invocation() {
  # Verifies that doctor.sh resolves symlinks to find its lib/ directory when
  # invoked through a symlink under a directory without lib/.
  #
  # Steps:
  #   1. Create a symlink to doctor.sh in a temp dir that has no lib/ subdirectory.
  #   2. Run doctor via the symlink with --no-color --repo REPO_ROOT.
  #   3. Assert output contains "frontmatter lint" (requires lib/portable.sh,
  #      confirming symlink was resolved to the real scripts/ dir).
  local name="doctor-symlink-invocation"
  should_run "$name" || return 0
  # Invokes doctor through a symlink to verify lib/ resolution; ln -s copies on
  # MSYS so the symlink-resolution path can't be exercised.
  if ! _td_needs_symlink "$name"; then return 0; fi
  local symdir="$tmp_root/sym-scripts"
  mkdir -p "$symdir"
  ln -sf "$DOCTOR" "$symdir/doctor.sh"
  local home="$tmp_root/home-symlink" out status=0
  mkdir -p "$home/.claude"
  write_minimal_settings "$home"
  create_memory_dir_for_pwd "$home"
  write_manifest "$home"
  local path
  path="$(make_stub_bin "$tmp_root/bin-symlink" claude codex)"
  out="$(HOME="$home" CLAUDE_CONFIG_DIR="$home/.claude" PATH="$path" bash "$symdir/doctor.sh" --no-color --repo "$REPO_ROOT" 2>&1)" || status=$?
  if [[ "$out" == *"frontmatter lint"* ]]; then
    pass "$name"
  else
    fail "$name" "expected frontmatter lint in output (lib/ resolved via symlink); status=$status out=$out"
  fi
}

case_doctor_copy_mode_no_lib() {
  # Verifies that doctor.sh runs gracefully when lib/ is absent (copy-mode
  # install on Windows), emitting WARN for degraded checks rather than crashing.
  #
  # Steps:
  #   1. Copy doctor.sh to a temp dir with no lib/ subdirectory.
  #   2. Run the copy with --no-color --repo REPO_ROOT.
  #   3. Assert exit code is 0 or 1 (no crash) and output contains "Summary:".
  local name="doctor-copy-mode-no-lib"
  should_run "$name" || return 0
  local copydir="$tmp_root/copy-scripts"
  mkdir -p "$copydir"
  cp "$DOCTOR" "$copydir/doctor.sh"
  local home="$tmp_root/home-copy" out status=0
  mkdir -p "$home/.claude"
  write_minimal_settings "$home"
  write_manifest "$home"
  local path
  path="$(make_stub_bin "$tmp_root/bin-copy" claude codex)"
  out="$(HOME="$home" CLAUDE_CONFIG_DIR="$home/.claude" PATH="$path" bash "$copydir/doctor.sh" --no-color --repo "$REPO_ROOT" 2>&1)" || status=$?
  if [[ ( "$status" -eq 0 || "$status" -eq 1 ) && "$out" == *"Summary:"* ]]; then
    pass "$name"
  else
    fail "$name" "expected exit 0 or 1 with Summary:; status=$status out=$out"
  fi
}

case_doctor_copy_mode_no_lib_no_codex() {
  # CC-201 regression: in copy-mode (no lib/portable.sh) codex_available()
  # comes from doctor.sh's own fallback block, not portable.sh. Verify
  # doctor.sh still runs gracefully when codex is ALSO absent from PATH —
  # the fallback codex_available must be defined so check_codex() and the
  # hook-profile case degrade to a warning rather than hitting an undefined
  # function.
  #
  # Steps:
  #   1. Copy doctor.sh to a temp dir with no lib/ subdirectory.
  #   2. Run it with a PATH containing claude but NOT codex.
  #   3. Assert exit 0 or 1 (no crash) and output contains "Summary:".
  local name="doctor-copy-mode-no-lib-no-codex"
  should_run "$name" || return 0
  local copydir="$tmp_root/copy-scripts-nocodex"
  mkdir -p "$copydir"
  cp "$DOCTOR" "$copydir/doctor.sh"
  local home="$tmp_root/home-copy-nocodex" out status=0
  mkdir -p "$home/.claude"
  write_minimal_settings "$home"
  write_manifest "$home"
  local path
  path="$(make_stub_bin "$tmp_root/bin-copy-nocodex" claude)"
  out="$(HOME="$home" CLAUDE_CONFIG_DIR="$home/.claude" PATH="$path" bash "$copydir/doctor.sh" --no-color --repo "$REPO_ROOT" 2>&1)" || status=$?
  if [[ ( "$status" -eq 0 || "$status" -eq 1 ) && "$out" == *"Summary:"* ]]; then
    pass "$name"
  else
    fail "$name" "expected exit 0 or 1 with Summary: (no crash when codex absent in copy-mode); status=$status out=$out"
  fi
}

case_doctor_installed_copy_no_repo() {
  # Verifies that doctor.sh emits [FAIL] with a helpful message when invoked
  # in copy-mode (no lib/) without --repo, so the user is not misled by
  # checks that silently fail against ~/.claude instead of the checkout.
  #
  # Steps:
  #   1. Copy doctor.sh to a temp dir that has no lib/ subdirectory.
  #   2. Run the copy WITHOUT --repo (auto-infers parent = tmpdir/..).
  #   3. Assert exit code 1 and output contains [FAIL] with "copy-mode" or "--repo".
  local name="doctor-installed-copy-no-repo"
  should_run "$name" || return 0
  local copydir="$tmp_root/copy-norepo"
  mkdir -p "$copydir"
  cp "$DOCTOR" "$copydir/doctor.sh"
  local home="$tmp_root/home-copy-norepo" out status=0
  mkdir -p "$home/.claude"
  write_minimal_settings "$home"
  write_manifest "$home"
  local path
  path="$(make_stub_bin "$tmp_root/bin-copy-norepo" claude codex)"
  out="$(HOME="$home" CLAUDE_CONFIG_DIR="$home/.claude" PATH="$path" bash "$copydir/doctor.sh" --no-color 2>&1)" || status=$?
  if [[ "$status" -eq 1 && "$out" == *"[FAIL]"* && ( "$out" == *"copy-mode"* || "$out" == *"--repo"* ) ]]; then
    pass "$name"
  else
    fail "$name" "expected exit 1 with [FAIL] copy-mode/--repo message; status=$status out=$out"
  fi
}

case_doctor_installed_copy_no_repo_json() {
  # Verifies that --json mode in copy-mode without --repo produces only valid
  # JSON Lines output (no human-readable Summary: line mixed in).
  #
  # Steps:
  #   1. Copy doctor.sh to a temp dir with no lib/.
  #   2. Run with --json (no --repo); expect exit 1.
  #   3. Assert every non-empty output line parses as valid JSON.
  local name="doctor-installed-copy-no-repo-json"
  should_run "$name" || return 0
  if ! command -v jq >/dev/null 2>&1; then
    pass "$name (jq not available - skip)"
    return
  fi
  local copydir="$tmp_root/copy-norepo-json"
  mkdir -p "$copydir"
  cp "$DOCTOR" "$copydir/doctor.sh"
  local home="$tmp_root/home-copy-norepo-json" out status=0 path
  mkdir -p "$home/.claude"
  write_minimal_settings "$home"
  write_manifest "$home"
  path="$(make_stub_bin "$tmp_root/bin-copy-norepo-json" claude codex)"
  out="$(HOME="$home" CLAUDE_CONFIG_DIR="$home/.claude" PATH="$path" bash "$copydir/doctor.sh" --json 2>&1)" || status=$?
  local invalid_line=0
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    printf '%s\n' "$line" | jq . >/dev/null 2>&1 || { invalid_line=1; break; }
  done <<< "$out"
  if [[ "$status" -eq 1 && "$invalid_line" -eq 0 ]]; then
    pass "$name"
  else
    fail "$name" "expected exit 1 with all-JSON output; status=$status invalid_line=$invalid_line out=$out"
  fi
}

case_doctor_claude_config_dir() {
  # Verifies that CLAUDE_CONFIG_DIR overrides HOME/.claude for settings and
  # manifest lookups: when HOME/.claude has no valid config but CLAUDE_CONFIG_DIR
  # points to a directory with valid settings and manifest, doctor must not FAIL
  # for missing settings or manifest.
  #
  # Steps:
  #   1. Create home_bare with no .claude/ directory.
  #   2. Create config_dir with valid settings.json and pm-dispatch manifest.
  #   3. Run doctor --no-color --repo <repo> with HOME=home_bare, CLAUDE_CONFIG_DIR=config_dir.
  #   4. Assert exit 0 and no "settings-file" FAIL line.
  local name="doctor-claude-config-dir"
  should_run "$name" || return 0
  local home_bare="$tmp_root/home-bare-noconfig"
  local config_dir="$tmp_root/config-dir-valid"
  mkdir -p "$home_bare"
  mkdir -p "$config_dir/.pm-dispatch"
  printf '{\n  "hooks": {\n    "PreToolUse": [\n      {"matcher": "Edit|Write", "hooks": [{"type": "command", "command": "%s/scripts/hook-pm-write-guard.sh"}]},\n      {"matcher": "Bash",       "hooks": [{"type": "command", "command": "%s/scripts/hook-codex-bash-guard.sh"}]},\n      {"matcher": "Edit|Write", "hooks": [{"type": "command", "command": "%s/scripts/hook-codex-write-guard.sh"}]}\n    ],\n    "PostToolUse": [],\n    "Stop": [\n      {"hooks": [{"type": "command", "command": "%s/scripts/hook-log-claude-usage.sh"}]},\n      {"hooks": [{"type": "command", "command": "%s/scripts/hook-session-summary.sh"}]}\n    ],\n    "UserPromptSubmit": [\n      {"hooks": [{"type": "command", "command": "%s/scripts/hook-inject-memory.sh"}]}\n    ]\n  },\n  "statusLine": {"command": "%s/scripts/hook-save-rate-limits.sh"}\n}\n' \
    "$REPO_ROOT" "$REPO_ROOT" "$REPO_ROOT" \
    "$REPO_ROOT" "$REPO_ROOT" "$REPO_ROOT" "$REPO_ROOT" > "$config_dir/settings.json"
  # Add abs-path allowlist entries for all dispatch scripts directly into config_dir.
  local _allow_json _f
  _allow_json="$(
    {
      _f="$REPO_ROOT/scripts/codex-dispatch.sh"
      [[ -f "$_f" ]] && printf 'Bash(%s:*)\n' "$_f"
      for _f in "$REPO_ROOT/adapters"/*/dispatch.sh; do
        [[ -f "$_f" ]] && printf 'Bash(%s:*)\n' "$_f"
      done
    } | jq -Rn '[inputs]'
  )"
  jq --argjson allow "$_allow_json" '.permissions.allow = $allow' \
    "$config_dir/settings.json" > "$config_dir/settings.json.tmp"
  mv "$config_dir/settings.json.tmp" "$config_dir/settings.json"
  printf '{"manifest_version":1}\n' > "$config_dir/.pm-dispatch/install-manifest.json"
  local path out status=0
  path="$(make_stub_bin "$tmp_root/bin-config-dir" claude codex)"
  out="$(HOME="$home_bare" CLAUDE_CONFIG_DIR="$config_dir" PATH="$path" \
    bash "$DOCTOR" --no-color --repo "$REPO_ROOT" 2>&1)" || status=$?
  if [[ "$status" -eq 0 && "$out" != *"[FAIL]"* ]]; then
    pass "$name"
  else
    fail "$name" "expected exit 0 with no [FAIL]; status=$status out=$out"
  fi
}

case_doctor_repo_trusted_linter() {
  # Verifies that doctor.sh runs the INSTALLED linter, not the target repo's
  # scripts/lint-frontmatter.sh, preventing arbitrary code execution via --repo.
  #
  # Steps:
  #   1. Create a fake target repo with a malicious lint-frontmatter.sh that
  #      writes a sentinel file when executed.
  #   2. Run doctor --repo <fake-repo>.
  #   3. Assert the sentinel file was NOT created.
  local name="doctor-repo-trusted-linter"
  should_run "$name" || return 0
  local fake_repo="$tmp_root/fake-repo-trusted"
  local sentinel="$tmp_root/sentinel-trusted"
  mkdir -p "$fake_repo/scripts" "$fake_repo/agents" "$fake_repo/commands"
  cat > "$fake_repo/scripts/lint-frontmatter.sh" <<EOLINT
#!/usr/bin/env bash
touch "$sentinel"
exit 0
EOLINT
  chmod +x "$fake_repo/scripts/lint-frontmatter.sh"
  touch "$fake_repo/install.sh"
  local home="$tmp_root/home-trusted" path
  mkdir -p "$home/.claude"
  write_minimal_settings "$home"
  create_memory_dir_for_pwd "$home"
  write_manifest "$home"
  path="$(make_stub_bin "$tmp_root/bin-trusted" claude codex)"
  HOME="$home" CLAUDE_CONFIG_DIR="$home/.claude" PATH="$path" \
    bash "$DOCTOR" --no-color --repo "$fake_repo" >/dev/null 2>&1 || true
  if [[ ! -f "$sentinel" ]]; then
    pass "$name"
  else
    fail "$name" "doctor.sh executed the target repo's lint-frontmatter.sh (sentinel created)"
  fi
}

case_doctor_stale_hook_sibling_prefix_warns() {
  # Verifies that hook paths under a sibling checkout sharing the repo-root
  # prefix (e.g. /path/pm-dispatch-sibling/scripts/) emit [WARN] "different checkout".
  # Regression test for CC-223 path-boundary fix.
  #
  # Steps:
  #   1. Write settings.json with hooks pointing to ${REPO_ROOT}-sibling/scripts/.
  #   2. Run doctor --no-color --repo REPO_ROOT.
  #   3. Assert exit 0 and output contains [WARN] and "different checkout".
  local name="doctor-stale-hook-sibling-prefix-warns"
  should_run "$name" || return 0
  if ! command -v jq >/dev/null 2>&1; then
    pass "$name (jq not available - skip)"
    return
  fi
  local sibling="${REPO_ROOT}-sibling"
  local home="$tmp_root/home-sibling-prefix" out status=0 path
  mkdir -p "$home/.claude"
  write_sibling_prefix_settings "$home" "$sibling"
  create_memory_dir_for_pwd "$home"
  write_manifest "$home"
  path="$(make_stub_bin "$tmp_root/bin-sibling-prefix" claude)"
  out="$(HOME="$home" CLAUDE_CONFIG_DIR="$home/.claude" PATH="$path" bash "$DOCTOR" --no-color --repo "$REPO_ROOT" 2>&1)" || status=$?
  if [[ "$status" -eq 0 && "$out" == *"[WARN]"* && "$out" == *"different checkout"* ]]; then
    pass "$name"
  else
    fail "$name" "expected WARN 'different checkout' for sibling-prefix hooks; status=$status out=$out"
  fi
}

case_doctor_all_ok_exits_0
case_doctor_pmctl_foreign_warns
case_doctor_hooks_missing_exits_1
case_doctor_settings_missing_exits_1
case_doctor_json_output_valid
case_doctor_quiet_no_ok_lines
case_doctor_jq_missing_exits_1
case_doctor_warn_only_exits_0
case_doctor_repo_from_different_cwd
case_doctor_frontmatter_lint_ok
case_doctor_help_exits_0
case_doctor_unknown_flag
case_doctor_repo_missing_arg
case_doctor_scripts_not_executable_fail
case_doctor_manifest_missing_warn
case_doctor_manifest_bad_version_warn
case_doctor_malformed_settings_fail
case_doctor_malformed_settings_json
case_doctor_profile_minimal_skip_codex_hooks
case_doctor_windows_auto_profile_codex_on_path
test_dispatch_allowlist_ok
test_dispatch_allowlist_missing
test_dispatch_allowlist_adapter_absent
test_dispatch_allowlist_claude_adapter_absent
test_dispatch_allowlist_copymode_no_lib_fail
case_doctor_profile_missing_arg_exits_2
case_doctor_profile_invalid_value_exits_2
case_doctor_hook_inventory_parity
case_doctor_windows_path_hooks_present
case_doctor_windows_path_hooks_stale
case_doctor_stale_hook_path_warns
case_doctor_symlink_invocation
case_doctor_copy_mode_no_lib
case_doctor_copy_mode_no_lib_no_codex
case_doctor_installed_copy_no_repo
case_doctor_installed_copy_no_repo_json
case_doctor_claude_config_dir
case_doctor_repo_trusted_linter
case_doctor_stale_hook_sibling_prefix_warns

th_summary
