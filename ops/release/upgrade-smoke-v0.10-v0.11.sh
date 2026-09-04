#!/usr/bin/env bash
# CC-447 one-shot v0.10.0 -> v0.11 candidate upgrade acceptance smoke.
set -euo pipefail
export LC_ALL=C.UTF-8

usage() {
  cat <<'EOF'
Usage: upgrade-smoke-v0.10-v0.11.sh --baseline-dir PATH --candidate-dir PATH [options]

Required paths must be independent git checkouts/worktrees.

Options:
  --baseline-dir PATH  checkout at v0.10.0
  --candidate-dir PATH checkout containing the v0.11 candidate
  --artifact-dir PATH  evidence destination (default: .gate-results/cc447-<UTC>)
  --keep-sandbox       preserve the isolated HOME beside the artifact
  --help               show this help

Exit 0 is release acceptance. Any failed stage or assertion exits 1.
EOF
}

BASELINE_DIR=""
CANDIDATE_DIR=""
ARTIFACT_DIR=""
KEEP_SANDBOX=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --baseline-dir) [[ $# -ge 2 ]] || { usage >&2; exit 2; }; BASELINE_DIR="$2"; shift 2 ;;
    --candidate-dir) [[ $# -ge 2 ]] || { usage >&2; exit 2; }; CANDIDATE_DIR="$2"; shift 2 ;;
    --artifact-dir) [[ $# -ge 2 ]] || { usage >&2; exit 2; }; ARTIFACT_DIR="$2"; shift 2 ;;
    --keep-sandbox) KEEP_SANDBOX=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'upgrade-smoke: unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
done

[[ -n "$BASELINE_DIR" && -n "$CANDIDATE_DIR" ]] || { usage >&2; exit 2; }
BASELINE_DIR="$(cd "$BASELINE_DIR" 2>/dev/null && pwd -P)" || { printf 'upgrade-smoke: invalid baseline checkout\n' >&2; exit 2; }
CANDIDATE_DIR="$(cd "$CANDIDATE_DIR" 2>/dev/null && pwd -P)" || { printf 'upgrade-smoke: invalid candidate checkout\n' >&2; exit 2; }
[[ "$BASELINE_DIR" != "$CANDIDATE_DIR" ]] || { printf 'upgrade-smoke: baseline and candidate must be independent checkouts\n' >&2; exit 2; }
[[ -f "$BASELINE_DIR/install.sh" && -f "$CANDIDATE_DIR/install.sh" ]] || { printf 'upgrade-smoke: checkout is missing install.sh\n' >&2; exit 2; }

BASELINE_SHA="$(git -C "$BASELINE_DIR" rev-parse HEAD)"
CANDIDATE_SHA="$(git -C "$CANDIDATE_DIR" rev-parse HEAD)"
EXPECTED_BASELINE_SHA="$(git -C "$BASELINE_DIR" rev-list -n 1 v0.10.0 2>/dev/null || true)"
[[ -n "$EXPECTED_BASELINE_SHA" && "$BASELINE_SHA" == "$EXPECTED_BASELINE_SHA" ]] || {
  printf 'upgrade-smoke: baseline is not tag v0.10.0 (%s)\n' "$BASELINE_SHA" >&2
  exit 2
}

if [[ -z "$ARTIFACT_DIR" ]]; then
  ARTIFACT_DIR="$CANDIDATE_DIR/.gate-results/cc447-$(date -u +%Y%m%dT%H%M%SZ)"
fi
mkdir -p "$ARTIFACT_DIR"
ARTIFACT_DIR="$(cd "$ARTIFACT_DIR" && pwd -P)"
SANDBOX="$(mktemp -d /tmp/cc447-upgrade.XXXXXX)"
if [[ "$KEEP_SANDBOX" -eq 1 ]]; then
  printf '%s\n' "$SANDBOX" > "$ARTIFACT_DIR/sandbox-path.txt"
else
  trap 'rm -rf "$SANDBOX"' EXIT
fi

ISO_HOME="$SANDBOX/home"
CLAUDE_ROOT="$SANDBOX/claude"
CODEX_ROOT="$SANDBOX/codex"
XDG_ROOT="$SANDBOX/xdg"
BIN_ROOT="$SANDBOX/bin"
STATE_ROOT="$SANDBOX/state"
MEMORY_ROOT="$SANDBOX/canonical-memory"
TMP_ROOT="$SANDBOX/tmp"
USER_DATA="$ISO_HOME/user-data.txt"
mkdir -p "$ISO_HOME" "$CLAUDE_ROOT" "$CODEX_ROOT" "$XDG_ROOT" "$BIN_ROOT" \
  "$STATE_ROOT" "$MEMORY_ROOT" "$TMP_ROOT"

export HOME="$ISO_HOME"
export CLAUDE_HOME="$CLAUDE_ROOT"
export CLAUDE_CONFIG_DIR="$CLAUDE_ROOT"
export CODEX_HOME="$CODEX_ROOT"
export XDG_CONFIG_HOME="$XDG_ROOT"
export PMCTL_BIN_DIR="$BIN_ROOT"
export PM_DISPATCH_STATE_ROOT="$STATE_ROOT"
export PM_MEMORY_DIR="$MEMORY_ROOT"
export TMPDIR="$TMP_ROOT"
export PATH="$BIN_ROOT:/usr/bin:/bin"

STAGES="$ARTIFACT_DIR/stages.tsv"
ASSERTIONS="$ARTIFACT_DIR/assertions.tsv"
printf 'stage\texit_status\tlog\n' > "$STAGES"
printf 'assertion\tstatus\tdetail\n' > "$ASSERTIONS"

run_stage() {
  local name="$1"; shift
  local log="$ARTIFACT_DIR/${name}.log" rc=0
  "$@" >"$log" 2>&1 || rc=$?
  printf '%s\t%d\t%s\n' "$name" "$rc" "$(basename "$log")" >> "$STAGES"
  if [[ "$rc" -ne 0 ]]; then
    printf 'upgrade-smoke: stage %s failed (exit %d); see %s\n' "$name" "$rc" "$log" >&2
    return "$rc"
  fi
}

assert_ok() {
  local name="$1" detail="$2"
  printf '%s\tPASS\t%s\n' "$name" "$detail" >> "$ASSERTIONS"
}

assert_fail() {
  local name="$1" detail="$2"
  printf '%s\tFAIL\t%s\n' "$name" "$detail" >> "$ASSERTIONS"
  printf 'upgrade-smoke: assertion failed: %s (%s)\n' "$name" "$detail" >&2
  return 1
}

assert_equal() {
  local name="$1" expected="$2" actual="$3" detail="$4"
  if [[ "$actual" == "$expected" ]]; then
    assert_ok "$name" "$detail"
  else
    assert_fail "$name" "expected=$expected actual=$actual"
  fi
}

config_foreign_digest() {
  local file="$1"
  if [[ ! -f "$file" ]]; then printf 'missing\n'; return; fi
  jq -cS '{foreignMarker,foreignHooks:[.. | objects | select(.command? == "/foreign/hook.sh")]}' "$file" \
    | sha256sum | awk '{print $1}'
}

write_fixtures() {
  local tmp old_guard old_memory old_session legacy_memory_name legacy_session_name
  printf '# CC-447 canonical memory\n\nbyte-preserved-memory-fixture\n' > "$MEMORY_ROOT/MEMORY.md"
  printf 'byte-preserved-user-data\n' > "$USER_DATA"

  tmp="$(mktemp "$TMP_ROOT/claude-settings.XXXXXX")"
  jq '.foreignMarker="claude-foreign" |
      .hooks.PreToolUse = ((.hooks.PreToolUse // []) + [{matcher:"Read",hooks:[{type:"command",command:"/foreign/hook.sh"}]}])' \
    "$CLAUDE_ROOT/settings.json" > "$tmp"
  mv "$tmp" "$CLAUDE_ROOT/settings.json"

  mkdir -p "$CODEX_ROOT"
  old_guard="$BASELINE_DIR/scripts/hook-codex-command-guard.sh"
  legacy_memory_name="guard-inject-memory.sh"
  legacy_session_name="guard-session-summary.sh"
  old_memory="$BASELINE_DIR/scripts/$legacy_memory_name"
  old_session="$BASELINE_DIR/scripts/$legacy_session_name --host codex"
  jq -n --arg guard "$old_guard" --arg memory "$old_memory" --arg session "$old_session" '{
    foreignMarker:"codex-foreign",
    hooks:{
      PreToolUse:[
        {matcher:"Bash",hooks:[{type:"command",command:$guard}]},
        {matcher:"Read",hooks:[{type:"command",command:"/foreign/hook.sh"}]}
      ],
      UserPromptSubmit:[{hooks:[{type:"command",command:$memory}]}],
      Stop:[{hooks:[{type:"command",command:$session}]}]
    }
  }' > "$CODEX_ROOT/hooks.json"
  printf 'codex foreign instructions\n' > "$CODEX_ROOT/AGENTS.md"

  mkdir -p "$XDG_ROOT/opencode"
  printf '{"foreignMarker":"opencode-foreign","theme":"night"}\n' > "$XDG_ROOT/opencode/opencode.json"
  cp "$XDG_ROOT/opencode/opencode.json" "$SANDBOX/opencode-before.json"

}

run_stage baseline-install bash "$BASELINE_DIR/install.sh" --profile minimal
write_fixtures

CLAUDE_FOREIGN_BEFORE="$(config_foreign_digest "$CLAUDE_ROOT/settings.json")"
CODEX_FOREIGN_BEFORE="$(config_foreign_digest "$CODEX_ROOT/hooks.json")"
OPENCODE_BEFORE="$(sha256sum "$SANDBOX/opencode-before.json" | awk '{print $1}')"
CODEX_AGENTS_BEFORE="$(sha256sum "$CODEX_ROOT/AGENTS.md" | awk '{print $1}')"
MEMORY_BEFORE="$(sha256sum "$MEMORY_ROOT/MEMORY.md" | awk '{print $1}')"
USER_BEFORE="$(sha256sum "$USER_DATA" | awk '{print $1}')"

run_stage candidate-install bash "$CANDIDATE_DIR/install.sh" --profile minimal --enable-host codex --enable-host opencode --enable-host grok
run_stage candidate-doctor bash "$CANDIDATE_DIR/runtime/bin/doctor.sh" --json --repo "$CANDIDATE_DIR"
DOCTOR_FAIL="$(jq -s '[.[] | select(.summary == true)][-1].fail // -1' "$ARTIFACT_DIR/candidate-doctor.log")"
assert_equal doctor-zero-fail 0 "$DOCTOR_FAIL" "fail=$DOCTOR_FAIL"

if grep -RFn -- "$BASELINE_DIR" "$CLAUDE_ROOT/settings.json" "$CODEX_ROOT/hooks.json" \
    "$XDG_ROOT/opencode/opencode.json" "$XDG_ROOT/opencode/commands" "$XDG_ROOT/opencode/tools" \
    > "$ARTIFACT_DIR/stale-baseline-targets.txt" 2>&1; then
  assert_fail old-to-new-targets "active config still references baseline checkout"
else
  assert_ok old-to-new-targets "$BASELINE_SHA -> $CANDIDATE_SHA"
fi
if grep -RFnE '/scripts/[^" ]+\.sh' "$CLAUDE_ROOT/settings.json" "$CODEX_ROOT/hooks.json" \
    "$XDG_ROOT/opencode/opencode.json" "$XDG_ROOT/opencode/commands" "$XDG_ROOT/opencode/tools" \
    > "$ARTIFACT_DIR/retired-script-targets.txt" 2>&1; then
  assert_fail retired-targets "active config references retired scripts implementation"
else
  assert_ok retired-targets "no active /scripts/*.sh command target"
fi

run_stage candidate-dry-run bash "$CANDIDATE_DIR/install.sh" --dry-run --profile minimal --enable-host codex --enable-host opencode --enable-host grok

assert_equal claude-foreign-upgrade-preserved "$CLAUDE_FOREIGN_BEFORE" \
  "$(config_foreign_digest "$CLAUDE_ROOT/settings.json")" checksum
assert_equal codex-foreign-upgrade-preserved "$CODEX_FOREIGN_BEFORE" \
  "$(config_foreign_digest "$CODEX_ROOT/hooks.json")" checksum

run_stage candidate-uninstall bash "$CANDIDATE_DIR/uninstall.sh"

assert_equal claude-foreign-uninstall-preserved "$CLAUDE_FOREIGN_BEFORE" \
  "$(config_foreign_digest "$CLAUDE_ROOT/settings.json")" checksum
assert_equal codex-foreign-uninstall-preserved "$CODEX_FOREIGN_BEFORE" \
  "$(config_foreign_digest "$CODEX_ROOT/hooks.json")" checksum
assert_equal opencode-config-byte-preserved "$OPENCODE_BEFORE" \
  "$(sha256sum "$XDG_ROOT/opencode/opencode.json" | awk '{print $1}')" "$OPENCODE_BEFORE"
assert_equal codex-foreign-block-byte-preserved "$CODEX_AGENTS_BEFORE" \
  "$(sha256sum "$CODEX_ROOT/AGENTS.md" | awk '{print $1}')" "$CODEX_AGENTS_BEFORE"
assert_equal canonical-memory-byte-preserved "$MEMORY_BEFORE" \
  "$(sha256sum "$MEMORY_ROOT/MEMORY.md" | awk '{print $1}')" "$MEMORY_BEFORE"
assert_equal user-data-byte-preserved "$USER_BEFORE" \
  "$(sha256sum "$USER_DATA" | awk '{print $1}')" "$USER_BEFORE"

jq -n \
  --arg ticket CC-447 --arg baseline_ref v0.10.0 --arg baseline_sha "$BASELINE_SHA" \
  --arg candidate_sha "$CANDIDATE_SHA" --arg doctor_fail "$DOCTOR_FAIL" \
  --arg stages "$(basename "$STAGES")" --arg assertions "$(basename "$ASSERTIONS")" \
  '{schema_version:1,ticket:$ticket,verdict:"GO",baseline:{ref:$baseline_ref,sha:$baseline_sha},candidate:{sha:$candidate_sha},doctor:{fail:($doctor_fail|tonumber)},artifacts:{stages:$stages,assertions:$assertions}}' \
  > "$ARTIFACT_DIR/summary.json"

printf 'CC-447 upgrade smoke: GO\n'
printf 'baseline:  %s\n' "$BASELINE_SHA"
printf 'candidate: %s\n' "$CANDIDATE_SHA"
printf 'artifact:  %s\n' "$ARTIFACT_DIR"
