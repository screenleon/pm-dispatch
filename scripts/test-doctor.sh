#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C.UTF-8

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DOCTOR="$REPO_ROOT/scripts/doctor.sh"

FILTER=""
LIST=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --filter)
      FILTER="${2:-}"
      shift 2
      ;;
    --list)
      LIST=true
      shift
      ;;
    *)
      shift
      ;;
  esac
done

ALL_CASES=()
PASS=0
FAIL=0
FAILED_CASES=()

should_run() {
  if $LIST; then
    ALL_CASES+=("$1")
    return 1
  fi
  [[ -z "$FILTER" || "$1" == *"$FILTER"* ]]
}

pass() {
  printf 'PASS: %s\n' "$1"
  PASS=$((PASS + 1))
}

fail() {
  printf 'FAIL: %s: %s\n' "$1" "$2"
  FAIL=$((FAIL + 1))
  FAILED_CASES+=("$1")
}

tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

write_minimal_settings() {
  local home_dir="$1"
  mkdir -p "$home_dir/.claude"
  cat > "$home_dir/.claude/settings.json" <<EOF
{
  "hooks": {
    "PreToolUse": [
      {"matcher": "Edit|Write", "hooks": [{"type": "command", "command": "${REPO_ROOT}/scripts/hook-pm-write-guard.sh"}]},
      {"matcher": "*",          "hooks": [{"type": "command", "command": "${REPO_ROOT}/scripts/hook-tool-trace.sh"}]}
    ],
    "PostToolUse": [
      {"matcher": "Bash|Agent", "hooks": [{"type": "command", "command": "${REPO_ROOT}/scripts/hook-routing-log.sh"}]}
    ],
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
}

write_minimal_settings_no_routing_log() {
  local home_dir="$1"
  mkdir -p "$home_dir/.claude"
  cat > "$home_dir/.claude/settings.json" <<EOF
{
  "hooks": {
    "PreToolUse": [
      {"matcher": "Edit|Write", "hooks": [{"type": "command", "command": "${REPO_ROOT}/scripts/hook-pm-write-guard.sh"}]},
      {"matcher": "*",          "hooks": [{"type": "command", "command": "${REPO_ROOT}/scripts/hook-tool-trace.sh"}]}
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
      {"matcher": "Edit|Write", "hooks": [{"type": "command", "command": "/fake/old-repo/scripts/hook-codex-write-guard.sh"}]},
      {"matcher": "*",          "hooks": [{"type": "command", "command": "/fake/old-repo/scripts/hook-tool-trace.sh"}]}
    ],
    "PostToolUse": [
      {"matcher": "Bash|Agent", "hooks": [{"type": "command", "command": "/fake/old-repo/scripts/hook-routing-log.sh"}]}
    ],
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
      {"matcher": "Edit|Write", "hooks": [{"type": "command", "command": "${sibling}/scripts/hook-codex-write-guard.sh"}]},
      {"matcher": "*",          "hooks": [{"type": "command", "command": "${sibling}/scripts/hook-tool-trace.sh"}]}
    ],
    "PostToolUse": [
      {"matcher": "Bash|Agent", "hooks": [{"type": "command", "command": "${sibling}/scripts/hook-routing-log.sh"}]}
    ],
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
      {"matcher": "Edit|Write", "hooks": [{"type": "command", "command": "${REPO_ROOT}/scripts/hook-codex-write-guard.sh"}]},
      {"matcher": "*",          "hooks": [{"type": "command", "command": "${REPO_ROOT}/scripts/hook-tool-trace.sh"}]}
    ],
    "PostToolUse": [
      {"matcher": "Bash|Agent", "hooks": [{"type": "command", "command": "${REPO_ROOT}/scripts/hook-routing-log.sh"}]}
    ],
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
}

create_memory_dir_for_pwd() {
  local home_dir="$1"
  # shellcheck source=scripts/lib/memory.sh
  . "$REPO_ROOT/scripts/lib/memory.sh"
  local encoded
  encoded="$(encode_path "$PWD")"
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
  [[ -n "$real" ]] || return 0
  ln -sf "$real" "$bin/$cmd"
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
  #   2. Run doctor --no-color --repo <repo> with claude+codex stubs in PATH.
  #   3. Assert exit 0, output contains "0 FAIL" and "0 WARN".
  local name="doctor-all-ok-exits-0"
  should_run "$name" || return 0
  local home="$tmp_root/home-all-ok" out status=0 path
  write_full_settings "$home"
  create_memory_dir_for_pwd "$home"
  write_manifest "$home"
  path="$(make_stub_bin "$tmp_root/bin-all-ok" claude codex)"

  out="$(HOME="$home" CLAUDE_CONFIG_DIR="$home/.claude" PATH="$path" bash "$DOCTOR" --no-color --repo "$REPO_ROOT" 2>&1)" || status=$?
  if [[ "$status" -eq 0 && "$out" == *"0 FAIL"* && "$out" == *"0 WARN"* ]]; then
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

case_doctor_minimal_missing_routing_log_fails() {
  # Verifies that --profile minimal fails when hook-routing-log.sh is absent from
  # settings.json, confirming routing-log is required in the minimal profile.
  #
  # Steps:
  #   1. Write minimal settings WITHOUT routing-log in PostToolUse; no codex in PATH.
  #   2. Run doctor --no-color --repo <repo> --profile minimal.
  #   3. Assert exit non-zero, output contains [FAIL] and "routing-log".
  local name="doctor-minimal-missing-routing-log-fails"
  should_run "$name" || return 0
  if ! command -v jq >/dev/null 2>&1; then
    pass "$name (jq not available - skip)"
    return
  fi
  # Settings has all minimal hooks EXCEPT routing-log; no codex stub in PATH.
  # With --profile minimal, doctor checks routing-log and must report FAIL.
  local home="$tmp_root/home-minimal-no-routing" out status=0 path
  write_minimal_settings_no_routing_log "$home"
  create_memory_dir_for_pwd "$home"
  write_manifest "$home"
  path="$(make_stub_bin "$tmp_root/bin-minimal-no-routing" claude)"

  out="$(HOME="$home" CLAUDE_CONFIG_DIR="$home/.claude" PATH="$path" bash "$DOCTOR" --no-color --repo "$REPO_ROOT" --profile minimal 2>&1)" || status=$?
  if [[ "$status" -ne 0 && "$out" == *"[FAIL]"* && "$out" == *"routing-log"* ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$out"
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
case_doctor_minimal_missing_routing_log_fails
case_doctor_profile_missing_arg_exits_2
case_doctor_profile_invalid_value_exits_2
case_doctor_stale_hook_path_warns
case_doctor_symlink_invocation
case_doctor_copy_mode_no_lib
case_doctor_installed_copy_no_repo
case_doctor_installed_copy_no_repo_json
case_doctor_repo_trusted_linter
case_doctor_stale_hook_sibling_prefix_warns

if $LIST; then
  printf '%s\n' "${ALL_CASES[@]}"
  exit 0
fi

printf '%s passed, %s failed\n' "$PASS" "$FAIL"
if [[ "$FAIL" -gt 0 ]]; then
  printf 'failed cases: %s\n' "${FAILED_CASES[*]}" >&2
  exit 1
fi
