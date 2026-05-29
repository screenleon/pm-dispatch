#!/usr/bin/env bash
# Regression tests for scripts/pm-prep-snapshot.sh.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_PATH="$REPO_ROOT/scripts/pm-prep-snapshot.sh"
HUB="$REPO_ROOT/scripts/lib/test-harness.sh"

source "$HUB"
th_init "$@"

FAKE_GH_DIR="$tmp_root/fake-gh"
mkdir -p "$FAKE_GH_DIR"
cat > "$FAKE_GH_DIR/gh" <<'EOF'
#!/usr/bin/env bash
if [ "${1:-}" != "pr" ] || [ "${2:-}" != "list" ]; then
  exit 0
fi
if printf '%s\n' "$*" | grep -q -- "--jq"; then
  cat <<'OUT'
#130 fake merged pr one
#129 fake merged pr two
#128 fake merged pr three
#127 fake merged pr four
#126 fake merged pr five
OUT
  exit 0
fi
if printf '%s\n' "$*" | grep -q -- "--json"; then
  cat <<'OUT'
[{"number":130,"title":"fake merged pr one"},{"number":129,"title":"fake merged pr two"},{"number":128,"title":"fake merged pr three"},{"number":127,"title":"fake merged pr four"},{"number":126,"title":"fake merged pr five"}]
OUT
  exit 0
fi
exit 0
EOF
chmod +x "$FAKE_GH_DIR/gh"

run_snapshot() {
  local out_path=$1
  shift
  PATH="$FAKE_GH_DIR:$PATH" "$SCRIPT_PATH" --out "$out_path" "$@"
}

run_snapshot_default() {
  PATH="$FAKE_GH_DIR:$PATH" "$SCRIPT_PATH" "$@"
}

require_file_contains() {
  local path=$1
  local pattern=$2
  local name=$3
  if grep -qE "$pattern" "$path"; then
    pass "$name"
  else
    fail "$name" "missing pattern: $pattern"
  fi
}

require_file_contains_fixed() {
  local path=$1
  local pattern=$2
  local name=$3
  if grep -qF "$pattern" "$path"; then
    pass "$name"
  else
    fail "$name" "missing literal: $pattern"
  fi
}

require_no_match() {
  local path=$1
  local pattern=$2
  local name=$3
  if grep -qE "$pattern" "$path"; then
    fail "$name" "unexpected match: $pattern"
  else
    pass "$name"
  fi
}

# Verifies that pm-prep-snapshot.sh creates a snapshot file under /tmp
# when run with no --out argument (default output path).
#
# Steps:
#   1. Record a filesystem marker timestamp.
#   2. Run pm-prep-snapshot.sh with no --out flag.
#   3. Assert a new pm-snapshot-*.md file appears under /tmp newer than the marker.
if should_run "cli-default-output"; then
  marker="$tmp_root/default-marker"
  touch "$marker"
  if run_snapshot_default >/dev/null; then
    snapshot_path="$(find /tmp -maxdepth 1 -name 'pm-snapshot-*.md' -type f -newer "$marker" -print | head -n 1)"
    if [ -n "$snapshot_path" ]; then
      pass "cli-default-output"
      rm -f "$snapshot_path"
    else
      fail "cli-default-output" "default snapshot file not created under /tmp"
    fi
  else
    fail "cli-default-output" "script failed"
  fi
fi

# Verifies that pm-prep-snapshot.sh writes the snapshot to the path
# specified by the --out flag instead of the default /tmp location.
#
# Steps:
#   1. Specify a custom output path via --out.
#   2. Run pm-prep-snapshot.sh --out <custom-path>.
#   3. Assert the snapshot file exists at the custom path.
if should_run "cli-out-override"; then
  out="$tmp_root/pm-snapshot-override.md"
  if run_snapshot "$out" >/dev/null && [ -f "$out" ]; then
    pass "cli-out-override"
  else
    fail "cli-out-override" "output not at path: $out"
  fi
fi

# Verifies that pm-prep-snapshot.sh prints the output file path to stdout
# so callers can capture the path of the generated snapshot.
#
# Steps:
#   1. Run pm-prep-snapshot.sh --out <path>.
#   2. Capture stdout.
#   3. Assert stdout equals the specified output path.
if should_run "cli-stdout-echoes-out-path"; then
  out="$tmp_root/pm-snapshot-echo.md"
  captured="$(run_snapshot "$out" 2>/dev/null)"
  if [ "$captured" = "$out" ]; then
    pass "cli-stdout-echoes-out-path"
  else
    fail "cli-stdout-echoes-out-path" "stdout='$captured' expected='$out'"
  fi
fi

# Verifies that pm-prep-snapshot.sh prints the default /tmp snapshot path
# to stdout even when --out is not specified.
#
# Steps:
#   1. Run pm-prep-snapshot.sh with no --out flag.
#   2. Capture stdout.
#   3. Assert stdout is a non-empty path that resolves to an existing file.
if should_run "cli-stdout-echoes-default-path"; then
  marker="$tmp_root/echo-default-marker"
  : > "$marker"
  captured="$(PATH="$FAKE_GH_DIR:$PATH" "$SCRIPT_PATH" 2>/dev/null)"
  if [ -n "$captured" ] && [ -f "$captured" ]; then
    pass "cli-stdout-echoes-default-path"
    rm -f "$captured"
  else
    fail "cli-stdout-echoes-default-path" "stdout='$captured' (file missing or empty)"
  fi
fi

# Verifies that the generated snapshot contains all required YAML frontmatter
# fields: snapshot_ts, repo, branch_base, current_branch, ahead_by,
# recently_merged, backlog_next_id, and project_tooling.
#
# Steps:
#   1. Run pm-prep-snapshot.sh and write output to a temp file.
#   2. Assert each required frontmatter key is present with the expected regex pattern.
#   3. Pass only if all assertions succeed.
if should_run "frontmatter-core-fields"; then
  out="$tmp_root/frontmatter.md"
  run_snapshot "$out" >/dev/null
  require_file_contains "$out" '^snapshot_ts:' "frontmatter-core-fields: snapshot_ts"
  require_file_contains "$out" '^repo: pm-dispatch$' "frontmatter-core-fields: repo"
  require_file_contains "$out" '^branch_base: origin/main@[0-9a-f]{7,}$' "frontmatter-core-fields: branch_base"
  require_file_contains "$out" '^current_branch: [^[:space:]]+@[0-9a-f]{7,}$' "frontmatter-core-fields: current_branch"
  require_file_contains "$out" '^ahead_by: [0-9]+$' "frontmatter-core-fields: ahead_by"
  require_file_contains "$out" '^recently_merged:' "frontmatter-core-fields: recently_merged"
  require_file_contains "$out" '^backlog_next_id: CC-[0-9]+$' "frontmatter-core-fields: backlog_next_id"
  require_file_contains "$out" '^project_tooling:$' "frontmatter-core-fields: project_tooling"
fi

# Verifies that the project_tooling section in the snapshot reports the
# correct boolean values for makefile, backlog_render_target, and has_validate_sh.
#
# Steps:
#   1. Run pm-prep-snapshot.sh and write output to a temp file.
#   2. Assert project_tooling contains "makefile: false".
#   3. Assert project_tooling contains "has_validate_sh: true".
if should_run "frontmatter-project-tooling-values"; then
  out="$tmp_root/project-tooling.md"
  run_snapshot "$out" >/dev/null
  require_file_contains "$out" '^  makefile: false$' "frontmatter-project-tooling-values: makefile"
  require_file_contains "$out" '^  backlog_render_target: false$' "frontmatter-project-tooling-values: backlog_render_target"
  require_file_contains "$out" '^  has_validate_sh: true$' "frontmatter-project-tooling-values: has_validate_sh"
fi

# Verifies that pm-prep-snapshot.sh --focus includes a focus_tickets section
# containing the specified CC ticket rows and body headings.
#
# Steps:
#   1. Run pm-prep-snapshot.sh --focus CC-243,CC-244.
#   2. Assert output contains "## focus_tickets" section heading.
#   3. Assert output contains table rows and body headings for both CC-243 and CC-244.
if should_run "focus-tickets-section"; then
  out="$tmp_root/focus.md"
  run_snapshot "$out" --focus CC-243,CC-244 >/dev/null
  require_file_contains_fixed "$out" "## focus_tickets" "focus-tickets-section: heading"
  require_file_contains_fixed "$out" "| CC-243 |" "focus-tickets-section: CC-243 row"
  require_file_contains_fixed "$out" "## CC-243 —" "focus-tickets-section: CC-243 body heading"
  require_file_contains_fixed "$out" "| CC-244 |" "focus-tickets-section: CC-244 row"
  require_file_contains_fixed "$out" "## CC-244 —" "focus-tickets-section: CC-244 body heading"
fi

# Verifies that pm-prep-snapshot.sh --focus emits a warning comment when
# a specified CC ticket is not found in BACKLOG.md, and omits the focus section.
#
# Steps:
#   1. Run pm-prep-snapshot.sh --focus CC-999 (non-existent ticket).
#   2. Assert output contains "# warn: CC-999 not found in BACKLOG.md".
#   3. Assert no "## focus_tickets" section is emitted.
if should_run "focus-missing-ticket-warn"; then
  out="$tmp_root/focus-missing.md"
  run_snapshot "$out" --focus CC-999 >/dev/null
  require_file_contains_fixed "$out" '# warn: CC-999 not found in BACKLOG.md' "focus-missing-ticket-warn: warning"
  require_no_match "$out" '^## focus_tickets' "focus-missing-ticket-warn: no focus section"
fi

# Verifies that pm-prep-snapshot.sh omits the focus_tickets section entirely
# when --focus is not specified.
#
# Steps:
#   1. Run pm-prep-snapshot.sh without --focus.
#   2. Assert output does not contain "## focus_tickets".
if should_run "focus-omitted-no-section"; then
  out="$tmp_root/focus-omitted.md"
  run_snapshot "$out" >/dev/null
  require_no_match "$out" '^## focus_tickets' "focus-omitted-no-section"
fi

# Verifies that the recently_merged section is populated from gh pr list when
# gh is available, and only warns when gh is genuinely absent.
#
# Steps:
#   1. Run pm-prep-snapshot.sh with a fake gh on PATH that returns stub PRs.
#   2. Assert no "gh not found" warning appears in output.
#   3. Assert output contains expected stub merged PR items.
if should_run "recently-merged-gh-fallback-warns-only-when-needed"; then
  out="$tmp_root/recently-merged.md"
  run_snapshot "$out" >/dev/null
  if ! grep -q '# warn: gh not found' "$out"; then
    pass "recently-merged-gh-fallback-warns-only-when-needed"
  else
    fail "recently-merged-gh-fallback-warns-only-when-needed" "unexpected gh missing warning when fake gh available"
  fi
  require_file_contains_fixed "$out" '  - "#130 fake merged pr one"' "recently-merged-gh-fallback-warns-only-when-needed: item one"
  require_file_contains_fixed "$out" '  - "#129 fake merged pr two"' "recently-merged-gh-fallback-warns-only-when-needed: item two"
fi

# Verifies that pm-prep-snapshot.sh does not emit "command not found" errors
# in the snapshot output (all required commands are present or gracefully absent).
#
# Steps:
#   1. Run pm-prep-snapshot.sh and capture the snapshot output.
#   2. Assert the snapshot file does not contain the string "command not found".
if should_run "no-command-not-found-warnings"; then
  out="$tmp_root/no-command-not-found.md"
  run_snapshot "$out" >/dev/null
  if grep -q "command not found" "$out"; then
    fail "no-command-not-found-warnings" "found command not found in snapshot"
  else
    pass "no-command-not-found-warnings"
  fi
fi

# Verifies that pm-prep-snapshot.sh outputs a file ending with a newline
# so downstream tools that require POSIX-compliant text files work correctly.
#
# Steps:
#   1. Run pm-prep-snapshot.sh and write output to a temp file.
#   2. Read the last byte of the output file.
#   3. Assert the last byte is 0x0a (newline).
if should_run "output-ends-with-newline"; then
  out="$tmp_root/newline.md"
  run_snapshot "$out" >/dev/null
  last_byte="$(tail -c 1 "$out" | od -An -t x1 | tr -d ' \n')"
  if [ "$last_byte" = "0a" ]; then
    pass "output-ends-with-newline"
  else
    fail "output-ends-with-newline" "missing newline at EOF"
  fi
fi

# Verifies that pm-prep-snapshot.sh produces identical output across two runs
# except for the snapshot_ts timestamp field.
#
# Steps:
#   1. Run pm-prep-snapshot.sh twice, writing to two separate files.
#   2. Strip the snapshot_ts line from both files.
#   3. Assert the remaining content is byte-identical.
if should_run "deterministic-except-timestamp"; then
  first="$tmp_root/deterministic-a.md"
  second="$tmp_root/deterministic-b.md"
  run_snapshot "$first" >/dev/null
  run_snapshot "$second" >/dev/null
  grep -v '^snapshot_ts:' "$first" > "$tmp_root/deterministic-a-body.txt"
  grep -v '^snapshot_ts:' "$second" > "$tmp_root/deterministic-b-body.txt"
  if cmp -s "$tmp_root/deterministic-a-body.txt" "$tmp_root/deterministic-b-body.txt"; then
    pass "deterministic-except-timestamp"
  else
    fail "deterministic-except-timestamp" "non-timestamp diff present"
  fi
fi

# Verifies that pm-prep-snapshot.sh exits non-zero with a clear error message
# when run from a directory that is not inside a git repository.
#
# Steps:
#   1. Create a temporary non-git directory.
#   2. Run pm-prep-snapshot.sh from that directory.
#   3. Assert exit is non-zero and error output contains "not inside a git repository".
if should_run "error-hard-non-git"; then
  nongit="$tmp_root/non-git"
  mkdir -p "$nongit"
  if (cd "$nongit" && run_snapshot "$nongit/out.md" >/tmp/pm-prep-snapshot.err 2>&1); then
    fail "error-hard-non-git" "expected non-zero exit for non-git dir"
  else
    if grep -q "not inside a git repository" /tmp/pm-prep-snapshot.err; then
      pass "error-hard-non-git"
    else
      fail "error-hard-non-git" "missing clear non-git error"
    fi
  fi
fi

# Verifies that pm-prep-snapshot.sh exits non-zero with a clear error message
# when the --out path is inside a non-writable directory.
#
# Steps:
#   1. Create a directory with mode 500 (no write permission).
#   2. Run pm-prep-snapshot.sh --out <dir>/out.md.
#   3. Assert exit is non-zero and error output contains "cannot write to output path".
if should_run "error-hard-unwritable-output"; then
  ro="$tmp_root/unwritable"
  mkdir -p "$ro"
  chmod 500 "$ro"
  out="$ro/out.md"
  if (PATH="$FAKE_GH_DIR:$PATH" "$SCRIPT_PATH" --out "$out" >/tmp/pm-prep-snapshot.err 2>&1); then
    chmod 700 "$ro"
    fail "error-hard-unwritable-output" "expected non-zero exit"
  else
    if grep -q "cannot write to output path" /tmp/pm-prep-snapshot.err; then
      pass "error-hard-unwritable-output"
    else
      fail "error-hard-unwritable-output" "missing clear unwritable-output error"
    fi
  fi
  chmod 700 "$ro"
fi

# Verifies that pm-prep-snapshot.sh --help exits 0 and prints "Usage:" to stderr.
#
# Steps:
#   1. Run pm-prep-snapshot.sh --help.
#   2. Assert exit code is 0.
#   3. Assert stderr contains "Usage:".
if should_run "cli-help"; then
  if (PATH="$FAKE_GH_DIR:$PATH" "$SCRIPT_PATH" --help >/tmp/pm-prep-snapshot.out 2>/tmp/pm-prep-snapshot.err); then
    if grep -q "^Usage:" /tmp/pm-prep-snapshot.err; then
      pass "cli-help: prints usage on stderr"
    else
      fail "cli-help" "missing 'Usage:' on stderr"
    fi
  else
    fail "cli-help" "expected exit 0 from --help"
  fi
fi

# Verifies that pm-prep-snapshot.sh exits non-zero with an "unknown argument"
# error message when given an unrecognized flag.
#
# Steps:
#   1. Run pm-prep-snapshot.sh --not-a-real-flag.
#   2. Assert exit is non-zero.
#   3. Assert stderr contains "unknown argument".
if should_run "cli-unknown-flag"; then
  if (PATH="$FAKE_GH_DIR:$PATH" "$SCRIPT_PATH" --not-a-real-flag >/tmp/pm-prep-snapshot.out 2>/tmp/pm-prep-snapshot.err); then
    fail "cli-unknown-flag" "expected non-zero exit for unknown flag"
  else
    if grep -q "unknown argument" /tmp/pm-prep-snapshot.err; then
      pass "cli-unknown-flag: clear error message"
    else
      fail "cli-unknown-flag" "missing 'unknown argument' error"
    fi
  fi
fi

# Verifies that pm-prep-snapshot.sh emits a branch_base warning and uses the
# local main branch as fallback when origin/main remote is absent.
#
# Steps:
#   1. Create a local git repo with a main branch but no origin remote.
#   2. Run pm-prep-snapshot.sh pointing at that repo.
#   3. Assert snapshot output contains "warn: origin/main unresolved" and
#      branch_base references the local main commit SHA.
if should_run "branch-base-warn-on-missing-origin-main"; then
  local_repo="$tmp_root/local-only-repo"
  mkdir -p "$local_repo"
  git -C "$local_repo" init -q -b main
  git -C "$local_repo" -c user.email=t@t -c user.name=T commit --allow-empty -q -m init
  # No origin remote — origin/main cannot resolve.
  # Use the real BACKLOG.md so the snapshot script can compute backlog_next_id.
  cp "$REPO_ROOT/BACKLOG.md" "$local_repo/"
  _snap_out="$tmp_root/local-only-snap.md"
  _snap_exit=0
  (cd "$local_repo" && PATH="$FAKE_GH_DIR:$PATH" "$SCRIPT_PATH" --out "$_snap_out") \
    >/tmp/pm-prep-snapshot.err 2>&1 || _snap_exit=$?
  if [[ "$_snap_exit" -eq 0 ]]; then
    if grep -qE "^# warn: origin/main unresolved" "$_snap_out" && \
       grep -qE "^branch_base: main@[0-9a-f]+" "$_snap_out"; then
      pass "branch-base-warn-on-missing-origin-main"
    else
      fail "branch-base-warn-on-missing-origin-main" "missing warn line or wrong branch_base"
    fi
  else
    fail "branch-base-warn-on-missing-origin-main" "snapshot script must not hard-fail when origin/main unresolved"
  fi
fi

# Verifies that when jq is absent from PATH, collect_recently_merged sets a warning
# and pm-prep-snapshot.sh still exits 0 with recently_merged: [].
#
# Steps:
#   1. Find the directory containing the real jq binary.
#   2. Build a shadow dir with symlinks to all tools in that directory except jq.
#   3. Run pm-prep-snapshot.sh with PATH="$FAKE_GH_DIR:$shadow_dir:remaining_path".
#   4. Assert exit 0, output contains "# warn: jq command not found", recently_merged: [].
if should_run "recently-merged-no-jq-warns"; then
  _jq_real="$(command -v jq 2>/dev/null || true)"
  _out="$tmp_root/no-jq.md"
  if [[ -z "$_jq_real" ]]; then
    # jq already absent - run directly without PATH manipulation
    _exit=0
    PATH="$FAKE_GH_DIR:$PATH" "$SCRIPT_PATH" --out "$_out" >/dev/null 2>&1 || _exit=$?
  else
    _jq_dir="$(dirname "$_jq_real")"
    _shadow="$tmp_root/shadow-no-jq"
    _jq_dirs=()
    while IFS= read -r _jq_path; do
      _jq_dirs+=("$(dirname "$_jq_path")")
    done < <(type -P -a jq 2>/dev/null || true)
    mkdir -p "$_shadow"
    for _f in "$_jq_dir"/*; do
      [[ "$(basename "$_f")" == "jq" ]] && continue
      [[ -x "$_f" ]] || continue
      ln -sf "$_f" "$_shadow/$(basename "$_f")" 2>/dev/null || true
    done
    _nojq_path="$FAKE_GH_DIR:$_shadow"
    IFS=: read -ra _path_dirs <<< "$PATH"
    for _pd in "${_path_dirs[@]}"; do
      _skip=0
      for _jq_pd in "${_jq_dirs[@]}"; do
        [[ "$_pd" == "$_jq_pd" ]] && _skip=1
      done
      [[ "$_skip" -eq 1 ]] && continue
      _nojq_path="$_nojq_path:$_pd"
    done
    _exit=0
    PATH="$_nojq_path" "$SCRIPT_PATH" --out "$_out" >/dev/null 2>&1 || _exit=$?
  fi
  if [[ "$_exit" -ne 0 ]]; then
    fail "recently-merged-no-jq-warns" "exit $_exit, expected 0 - snapshot must not hard-fail when jq absent"
  else
    require_file_contains "$_out" '# warn: jq command not found' "recently-merged-no-jq-warns: warn line"
    require_file_contains "$_out" 'recently_merged: \[\]' "recently-merged-no-jq-warns: empty list"
    pass "recently-merged-no-jq-warns"
  fi
fi

# Verifies that pm-prep-snapshot.sh derives repo name from the origin remote
# URL basename when available, not from the working directory name.
#
# Steps:
#   1. Create a local git repo in a dir named "my-local-dir".
#   2. Add an origin remote whose URL basename differs: canonical-repo-name.git.
#   3. Run pm-prep-snapshot.sh pointing at that repo.
#   4. Assert repo: canonical-repo-name (from remote), not my-local-dir.
if should_run "repo-name-from-remote-url"; then
  _wt_root="$tmp_root/my-local-dir"
  mkdir -p "$_wt_root"
  git -C "$_wt_root" init -q -b main
  git -C "$_wt_root" -c user.email=t@t -c user.name=T commit --allow-empty -q -m init
  git -C "$_wt_root" remote add origin "git@github.com:org/canonical-repo-name.git"
  cp "$REPO_ROOT/BACKLOG.md" "$_wt_root/"
  _rn_out="$tmp_root/remote-repo-name-snap.md"
  _rn_exit=0
  (cd "$_wt_root" && PATH="$FAKE_GH_DIR:$PATH" "$SCRIPT_PATH" --out "$_rn_out") \
    >/tmp/pm-prep-snapshot-remote.err 2>&1 || _rn_exit=$?
  if [[ "$_rn_exit" -eq 0 ]]; then
    require_file_contains "$_rn_out" '^repo: canonical-repo-name$' "repo-name-from-remote-url: repo field uses remote basename"
    require_no_match "$_rn_out" '^repo: my-local-dir$' "repo-name-from-remote-url: must not use directory name"
    pass "repo-name-from-remote-url"
  else
    fail "repo-name-from-remote-url" "snapshot exited $_rn_exit, expected 0 - see /tmp/pm-prep-snapshot-remote.err"
  fi
fi

th_summary
