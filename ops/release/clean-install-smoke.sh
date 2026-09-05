#!/usr/bin/env bash
# CC-447 offline single-checkout clean-install acceptance smoke.
set -euo pipefail
export LC_ALL=C.UTF-8

usage() {
  cat <<'EOF'
Usage: clean-install-smoke.sh [options]

Run an isolated clean-install smoke against one checkout. The five stages are:
dry-run install, real install, doctor, uninstall, and no-residue verification.

Options:
  --repo-dir PATH      checkout under test (default: current checkout)
  --artifact-dir PATH  evidence destination (default: sandbox/artifacts)
  --keep-sandbox       preserve the isolated HOME sandbox
  --help               show this help

Exit 0 is release acceptance. Invalid options exit 2.
EOF
}

REPO_DIR="$(pwd -P)"
ARTIFACT_DIR=""
KEEP_SANDBOX=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo-dir) [[ $# -ge 2 ]] || { usage >&2; exit 2; }; REPO_DIR="$2"; shift 2 ;;
    --artifact-dir) [[ $# -ge 2 ]] || { usage >&2; exit 2; }; ARTIFACT_DIR="$2"; shift 2 ;;
    --keep-sandbox) KEEP_SANDBOX=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'clean-install-smoke: unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
done

REPO_DIR="$(cd "$REPO_DIR" 2>/dev/null && pwd -P)" || {
  printf 'clean-install-smoke: invalid checkout\n' >&2; exit 2;
}
[[ -f "$REPO_DIR/install.sh" && -f "$REPO_DIR/uninstall.sh" && -f "$REPO_DIR/runtime/bin/doctor.sh" ]] || {
  printf 'clean-install-smoke: checkout is missing required entrypoints\n' >&2; exit 2;
}
CANDIDATE_SHA="$(git -C "$REPO_DIR" rev-parse HEAD 2>/dev/null)" || {
  printf 'clean-install-smoke: checkout is not a git repository\n' >&2; exit 2;
}

SANDBOX="$(mktemp -d /tmp/cc447-clean-install.XXXXXX)"
if [[ -z "$ARTIFACT_DIR" ]]; then
  ARTIFACT_DIR="$SANDBOX/artifacts"
  # Default evidence lives in the sandbox, so retain it for inspection.
  KEEP_SANDBOX=1
fi
mkdir -p "$ARTIFACT_DIR"
ARTIFACT_DIR="$(cd "$ARTIFACT_DIR" && pwd -P)"
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

# Pre-create all evidence files before snapshots: only installer-created paths
# are relevant to the dry-run and uninstall residue contracts.
for name in dry-run install doctor uninstall; do : > "$ARTIFACT_DIR/$name.log"; done
: > "$ARTIFACT_DIR/summary.json"

run_stage() {
  local name="$1"; shift
  local log="$ARTIFACT_DIR/${name}.log" rc=0
  "$@" >"$log" 2>&1 || rc=$?
  printf '%s\t%d\t%s\n' "$name" "$rc" "$(basename "$log")" >> "$STAGES"
  if [[ "$rc" -ne 0 ]]; then
    printf 'clean-install-smoke: stage %s failed (exit %d); see %s\n' "$name" "$rc" "$log" >&2
    return "$rc"
  fi
}

assert_ok() { printf '%s\tPASS\t%s\n' "$1" "$2" >> "$ASSERTIONS"; }
assert_fail() {
  printf '%s\tFAIL\t%s\n' "$1" "$2" >> "$ASSERTIONS"
  printf 'clean-install-smoke: assertion failed: %s (%s)\n' "$1" "$2" >&2
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
snapshot_tree() { find "$SANDBOX" -mindepth 1 -printf '%P\n' | sort; }

DRY_BEFORE="$ARTIFACT_DIR/dry-before.tsv"
DRY_AFTER="$ARTIFACT_DIR/dry-after.tsv"
PRE_INSTALL="$ARTIFACT_DIR/pre-install.tsv"
POST_UNINSTALL="$ARTIFACT_DIR/post-uninstall.tsv"
# These snapshot filenames are evidence paths too, and must predate snapshots.
: > "$DRY_BEFORE"; : > "$DRY_AFTER"; : > "$PRE_INSTALL"; : > "$POST_UNINSTALL"

snapshot_tree > "$DRY_BEFORE"
run_stage dry-run bash "$REPO_DIR/install.sh" --dry-run --profile minimal --enable-host codex --enable-host opencode
if grep -Fq '(no changes made — re-run without --dry-run to apply)' "$ARTIFACT_DIR/dry-run.log"; then
  assert_ok dry-run-no-changes-marker 'install output declared no changes'
else
  assert_fail dry-run-no-changes-marker 'dry-run output omitted no-changes marker'
fi
snapshot_tree > "$DRY_AFTER"
if cmp -s "$DRY_BEFORE" "$DRY_AFTER"; then
  assert_ok dry-run-tree-unchanged 'sandbox path snapshot unchanged'
else
  diff -u "$DRY_BEFORE" "$DRY_AFTER" > "$ARTIFACT_DIR/dry-run-tree.diff" || true
  assert_fail dry-run-tree-unchanged "sandbox changed; see $ARTIFACT_DIR/dry-run-tree.diff"
fi

snapshot_tree > "$PRE_INSTALL"
run_stage install bash "$REPO_DIR/install.sh" --profile minimal --enable-host codex --enable-host opencode
run_stage doctor bash "$REPO_DIR/runtime/bin/doctor.sh" --json --repo "$REPO_DIR"
DOCTOR_FAIL="$(jq -s '[.[] | select(.summary == true)][-1].fail // -1' "$ARTIFACT_DIR/doctor.log")"
assert_equal doctor-zero-fail 0 "$DOCTOR_FAIL" "fail=$DOCTOR_FAIL"
run_stage uninstall bash "$REPO_DIR/uninstall.sh"

snapshot_tree > "$POST_UNINSTALL"
diff -u "$PRE_INSTALL" "$POST_UNINSTALL" > "$ARTIFACT_DIR/residue.diff" || true
# CC-580 Requirement 2 (someday): timestamped .bak.* backups and the empty
# settings.json/hooks.json skeletons and empty xdg/opencode dir are an
# intentional "never delete something we don't provably fully own" safety net
# (see install.sh backup-before-overwrite and opencode uninstall's
# changed-since-install guard), not cleanup bugs -- allowlist them here.
# Anything else (e.g. leaked tmp/* scratch files, CC-580 Requirement 1) still
# fails this assertion.
RESIDUE_ALLOWLIST='\.bak\.[0-9]{8}-[0-9]{6}$|^claude/settings\.json$|^codex/hooks\.json$|^xdg/opencode$'
UNEXPECTED_RESIDUE="$(awk '/^\+[^+]/ { print substr($0, 2) }' "$ARTIFACT_DIR/residue.diff" | grep -vE "$RESIDUE_ALLOWLIST" || true)"
if [[ -z "$UNEXPECTED_RESIDUE" ]]; then
  assert_ok no-residue 'post-uninstall sandbox paths match pre-install snapshot (known safety artifacts allowlisted)'
else
  printf 'clean-install-smoke: residue found after uninstall:\n' >&2
  printf '%s\n' "$UNEXPECTED_RESIDUE" >&2
  assert_fail no-residue "unexpected paths remain; see $ARTIFACT_DIR/residue.diff"
fi

jq -n \
  --arg ticket CC-447 --arg candidate_sha "$CANDIDATE_SHA" --arg doctor_fail "$DOCTOR_FAIL" \
  --arg stages "$(basename "$STAGES")" --arg assertions "$(basename "$ASSERTIONS")" \
  '{schema_version:1,ticket:$ticket,verdict:"GO",candidate:{sha:$candidate_sha},doctor:{fail:($doctor_fail|tonumber)},artifacts:{stages:$stages,assertions:$assertions}}' \
  > "$ARTIFACT_DIR/summary.json"

printf 'CC-447 clean-install smoke: GO\n'
printf 'candidate: %s\n' "$CANDIDATE_SHA"
printf 'artifact:  %s\n' "$ARTIFACT_DIR"
