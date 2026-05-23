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

if should_run "cli-out-override"; then
  out="$tmp_root/pm-snapshot-override.md"
  if run_snapshot "$out" >/dev/null && [ -f "$out" ]; then
    pass "cli-out-override"
  else
    fail "cli-out-override" "output not at path: $out"
  fi
fi

if should_run "frontmatter-core-fields"; then
  out="$tmp_root/frontmatter.md"
  run_snapshot "$out" >/dev/null
  require_file_contains "$out" '^snapshot_ts:' "frontmatter-core-fields: snapshot_ts"
  require_file_contains "$out" '^repo: pm-dispatch$' "frontmatter-core-fields: repo"
  require_file_contains "$out" '^branch_base: origin/main@[0-9a-f]{7,}$' "frontmatter-core-fields: branch_base"
  require_file_contains "$out" '^current_branch: [^[:space:]]+@[0-9a-f]{7,}$' "frontmatter-core-fields: current_branch"
  require_file_contains "$out" '^ahead_by: [0-9]+$' "frontmatter-core-fields: ahead_by"
  require_file_contains "$out" '^recently_merged:' "frontmatter-core-fields: recently_merged"
  require_file_contains "$out" '^backlog_next_id: CC-245$' "frontmatter-core-fields: backlog_next_id"
  require_file_contains "$out" '^project_tooling:$' "frontmatter-core-fields: project_tooling"
fi

if should_run "frontmatter-project-tooling-values"; then
  out="$tmp_root/project-tooling.md"
  run_snapshot "$out" >/dev/null
  require_file_contains "$out" '^  makefile: false$' "frontmatter-project-tooling-values: makefile"
  require_file_contains "$out" '^  backlog_render_target: false$' "frontmatter-project-tooling-values: backlog_render_target"
  require_file_contains "$out" '^  has_validate_sh: true$' "frontmatter-project-tooling-values: has_validate_sh"
fi

if should_run "focus-tickets-section"; then
  out="$tmp_root/focus.md"
  run_snapshot "$out" --focus CC-243,CC-244 >/dev/null
  require_file_contains_fixed "$out" "## focus_tickets" "focus-tickets-section: heading"
  require_file_contains_fixed "$out" "| CC-243 |" "focus-tickets-section: CC-243 row"
  require_file_contains_fixed "$out" "## CC-243 —" "focus-tickets-section: CC-243 body heading"
  require_file_contains_fixed "$out" "| CC-244 |" "focus-tickets-section: CC-244 row"
  require_file_contains_fixed "$out" "## CC-244 —" "focus-tickets-section: CC-244 body heading"
fi

if should_run "focus-missing-ticket-warn"; then
  out="$tmp_root/focus-missing.md"
  run_snapshot "$out" --focus CC-999 >/dev/null
  require_file_contains_fixed "$out" '# warn: CC-999 not found in BACKLOG.md' "focus-missing-ticket-warn: warning"
  require_no_match "$out" '^## focus_tickets' "focus-missing-ticket-warn: no focus section"
fi

if should_run "focus-omitted-no-section"; then
  out="$tmp_root/focus-omitted.md"
  run_snapshot "$out" >/dev/null
  require_no_match "$out" '^## focus_tickets' "focus-omitted-no-section"
fi

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

if should_run "no-command-not-found-warnings"; then
  out="$tmp_root/no-command-not-found.md"
  run_snapshot "$out" >/dev/null
  if grep -q "command not found" "$out"; then
    fail "no-command-not-found-warnings" "found command not found in snapshot"
  else
    pass "no-command-not-found-warnings"
  fi
fi

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

if should_run "branch-base-warn-on-missing-origin-main"; then
  local_repo="$tmp_root/local-only-repo"
  mkdir -p "$local_repo"
  ( cd "$local_repo"
    git init -q -b main
    git -c user.email=t@t -c user.name=T commit --allow-empty -q -m init
    # No origin remote — origin/main cannot resolve.
    # Use the real BACKLOG.md so the snapshot script can compute backlog_next_id.
    cp "$REPO_ROOT/BACKLOG.md" .
    out="$tmp_root/local-only-snap.md"
    if PATH="$FAKE_GH_DIR:$PATH" "$SCRIPT_PATH" --out "$out" >/tmp/pm-prep-snapshot.err 2>&1; then
      if grep -qE "^# warn: origin/main unresolved" "$out" && grep -qE "^branch_base: main@[0-9a-f]+" "$out"; then
        pass "branch-base-warn-on-missing-origin-main"
      else
        fail "branch-base-warn-on-missing-origin-main" "missing warn line or wrong branch_base"
      fi
    else
      fail "branch-base-warn-on-missing-origin-main" "snapshot script must not hard-fail when origin/main unresolved"
    fi
  )
fi

th_summary
