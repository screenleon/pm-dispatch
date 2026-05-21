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

case_doctor_hooks_missing_exits_2() {
  local name="doctor-hooks-missing-exits-2"
  should_run "$name" || return 0
  local home="$tmp_root/home-no-hooks" out status=0
  mkdir -p "$home/.claude"
  printf '{"hooks":{}}\n' > "$home/.claude/settings.json"

  out="$(HOME="$home" CLAUDE_CONFIG_DIR="$home/.claude" bash "$DOCTOR" --no-color --repo "$REPO_ROOT" 2>&1)" || status=$?
  if [[ "$status" -eq 2 && "$out" == *"[FAIL]"* && "$out" == *"hooks"* ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$out"
  fi
}

case_doctor_settings_missing_exits_2() {
  local name="doctor-settings-missing-exits-2"
  should_run "$name" || return 0
  local home="$tmp_root/home-no-settings" out status=0
  mkdir -p "$home/.claude"

  out="$(HOME="$home" CLAUDE_CONFIG_DIR="$home/.claude" bash "$DOCTOR" --no-color --repo "$REPO_ROOT" 2>&1)" || status=$?
  if [[ "$status" -eq 2 && "$out" == *"[FAIL]"* && "$out" == *"settings"* ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$out"
  fi
}

case_doctor_json_output_valid() {
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
    if [[ "$line" == *"[OK]"* || "$line" == *"[FAIL]"* ]]; then
      fail "$name" "human tag leaked into JSON: $line"
      return
    fi
    last_line="$line"
  done <<< "$out"

  if [[ "$status" -eq 2 && "$last_line" == *'"summary":true'* ]]; then
    pass "$name"
  else
    fail "$name" "status=$status last_line=$last_line out=$out"
  fi
}

case_doctor_quiet_no_ok_lines() {
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

case_doctor_jq_missing_exits_2() {
  local name="doctor-jq-missing-exits-2"
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
  if [[ "$status" -eq 2 && "$out" == *"[FAIL]"* && "$out" == *"jq"* ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$out"
  fi
}

case_doctor_all_ok_exits_0
case_doctor_hooks_missing_exits_2
case_doctor_settings_missing_exits_2
case_doctor_json_output_valid
case_doctor_quiet_no_ok_lines
case_doctor_jq_missing_exits_2

if $LIST; then
  printf '%s\n' "${ALL_CASES[@]}"
  exit 0
fi

printf '%s passed, %s failed\n' "$PASS" "$FAIL"
if [[ "$FAIL" -gt 0 ]]; then
  printf 'failed cases: %s\n' "${FAILED_CASES[*]}" >&2
  exit 1
fi
