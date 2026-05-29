#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C.UTF-8

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# QA category matrix for scripts/lib/pmctl-backlog.sh + cli/pmctl backlog dispatch.
# 1. Happy path: view-all, view-status, view-area, view-combined, cli-view, cli-lint, cli-archive-dry
# 2. Boundary values: view-no-match (0 matching ticket rows, headers still emitted)
# 3. Negative inputs: view-unknown-flag, view-missing-status-value, view-missing-path, cli-unknown-sub
# 4. Error paths: lint-forwards-failure, archive-forwards-failure
# 5. State transitions: N/A - archive mutation semantics live in scripts/test-archive-closed-backlog.sh; this file only covers thin forwarding and read-only view behavior
# 6. Concurrency / race conditions: N/A - view is a stateless read-only filter and the wrappers keep no shared mutable state
# 7. Side effects: view-no-mutation, cli-archive-dry
# 8. Resource lifecycle: N/A - no persistent handles or long-lived resources beyond process-scoped awk/bash execution
# 9. Security: N/A - filters are passed via awk -v vars, paths are fixed or explicit fixture files, and there is no auth/authz boundary in this SUT
# 10. Performance / scale boundaries: N/A - no published performance contract for this wrapper layer; this suite is behavioral rather than benchmark-oriented
# 11. Contract / interface compatibility: cli-view, cli-lint, cli-archive-dry, cli-unknown-sub
# 12. Backward compatibility / migration: N/A - no migration path or versioned client/data compatibility surface in these wrappers

# shellcheck source=scripts/lib/test-harness.sh
. "$SCRIPT_DIR/lib/test-harness.sh"
# shellcheck source=scripts/lib/pmctl-backlog.sh
. "$SCRIPT_DIR/lib/pmctl-backlog.sh"
th_init "$@"

write_view_backlog() {
  local backlog_path="$1"

  cat > "$backlog_path" <<'EOF'
<!-- pm-schema: v1.2 -->
# Backlog

## Index

| # | Status | 主題 | 影響面 | 首次記錄 | Refs | Priority | Epic |
|---|---|---|---|---|---|---|---|
| CC-101 | 🔵 active | active ops | ops | 2026-01-01 | — | P1 | — |
| JS-202 | 🔵 active | active arch | arch | 2026-01-02 | — | P2 | — |
| CC-103 | 🟡 deferred | deferred ops | ops | 2026-01-03 | — | — | — |
| CC-104 | ✅ closed 2026-01-01 | closed ops arch | ops/arch | 2026-01-04 | pr:#1 | P3 | — |
| CC-105 | 🔵 inactive | inactive devops | devops | 2026-01-05 | — | P2 | — |

## CC-101 — active ops 🔵 active

Body

## JS-202 — active arch 🔵 active

Body

## CC-103 — deferred ops 🟡 deferred

Body

## CC-104 — closed ops arch ✅ 2026-01-01

Body

## CC-105 — inactive devops 🔵 inactive

Body
EOF
}

count_ticket_rows() {
  local text="$1"

  printf '%s\n' "$text" | grep -Ec '^\| [A-Z]+-[0-9]' || true
}

assert_string_not_contains() {
  local name="$1" haystack="$2" needle="$3"

  if [[ "$haystack" == *"$needle"* ]]; then
    fail "$name" "unexpected substring present: $needle"
    return 1
  fi
  return 0
}

setup_lint_repo() {
  local repo="$1"

  mkdir -p "$repo/pm/scripts"
  cat > "$repo/BACKLOG.md" <<'EOF'
<!-- pm-schema: v1.2 -->
# Backlog
EOF
  cat > "$repo/pm/scripts/validate.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
printf '%s\n' "$1" > "$repo_root/validate-arg.txt"

if [[ -f "$repo_root/validate.rc" ]]; then
  exit "$(cat "$repo_root/validate.rc")"
fi

exit 0
EOF
  chmod +x "$repo/pm/scripts/validate.sh"
}

setup_archive_repo() {
  local repo="$1"

  mkdir -p "$repo/scripts"
  cp "$REPO_ROOT/scripts/archive-closed-backlog.sh" "$repo/scripts/archive-closed-backlog.sh"
  chmod +x "$repo/scripts/archive-closed-backlog.sh"
  cat > "$repo/BACKLOG-ARCHIVE.md" <<'EOF'
<!-- pm-dispatch: backlog-archive 2026-01-01 -->
# archive

Last archived: 2026-01-01

---
EOF
  cat > "$repo/BACKLOG.md" <<'EOF'
<!-- pm-schema: v1.2 -->
# Backlog

| ID | Status | Desc | area | Created | Refs | Pri | Epic |
|---|---|---|---|---|---|---|---|
| CC-301 | ✅ closed 2026-01-01 | archived ticket | ops | 2026-01-01 | pr:#9 | P3 | — |
| CC-302 | 🔵 active | active ticket | arch | 2026-01-02 | — | P2 | — |

## CC-301 — archived ticket ✅ 2026-01-01

Body

## CC-302 — active ticket 🔵 active

Body
EOF
}

setup_lint_failure_repo() {
  local repo="$1"

  mkdir -p "$repo/pm/scripts"
  cat > "$repo/pm/scripts/validate.sh" <<'EOF'
#!/usr/bin/env bash
exit 7
EOF
  chmod +x "$repo/pm/scripts/validate.sh"
}

setup_archive_failure_repo() {
  local repo="$1"

  mkdir -p "$repo/scripts"
  cat > "$repo/scripts/archive-closed-backlog.sh" <<'EOF'
#!/usr/bin/env bash
exit 5
EOF
  chmod +x "$repo/scripts/archive-closed-backlog.sh"
}

if should_run "view-all"; then
  name="view-all"
  backlog="$tmp_root/view-all/BACKLOG.md"
  mkdir -p "$(dirname "$backlog")"
  write_view_backlog "$backlog"
  output="$(pmctl_backlog_view "$backlog")"

  if assert_string_contains "$name" "$output" "|---|---|---|---|---|---|---|---|" &&
    assert_string_contains "$name" "$output" "| CC-101 |" &&
    assert_string_contains "$name" "$output" "| JS-202 |" &&
    assert_string_contains "$name" "$output" "| CC-103 |" &&
    assert_string_contains "$name" "$output" "| CC-104 |" &&
    assert_string_contains "$name" "$output" "| CC-105 |"; then
    pass "$name"
  fi
fi

if should_run "view-status"; then
  name="view-status"
  backlog="$tmp_root/view-status/BACKLOG.md"
  mkdir -p "$(dirname "$backlog")"
  write_view_backlog "$backlog"
  output="$(pmctl_backlog_view "$backlog" --status active)"

  if assert_string_contains "$name" "$output" "| CC-101 |" &&
    assert_string_contains "$name" "$output" "| JS-202 |" &&
    assert_string_not_contains "$name" "$output" "| CC-105 |" &&
    assert_string_not_contains "$name" "$output" "| CC-103 |" &&
    assert_string_not_contains "$name" "$output" "| CC-104 |"; then
    pass "$name"
  fi
fi

if should_run "view-area"; then
  name="view-area"
  backlog="$tmp_root/view-area/BACKLOG.md"
  mkdir -p "$(dirname "$backlog")"
  write_view_backlog "$backlog"
  output="$(pmctl_backlog_view "$backlog" --area ops)"

  if assert_string_contains "$name" "$output" "| CC-101 |" &&
    assert_string_contains "$name" "$output" "| CC-103 |" &&
    assert_string_contains "$name" "$output" "| CC-104 |" &&
    assert_string_not_contains "$name" "$output" "| CC-105 |" &&
    assert_string_not_contains "$name" "$output" "| JS-202 |"; then
    pass "$name"
  fi
fi

if should_run "view-combined"; then
  name="view-combined"
  backlog="$tmp_root/view-combined/BACKLOG.md"
  mkdir -p "$(dirname "$backlog")"
  write_view_backlog "$backlog"
  output="$(pmctl_backlog_view "$backlog" --status active --area ops)"

  if assert_string_contains "$name" "$output" "| CC-101 |" &&
    assert_string_not_contains "$name" "$output" "| JS-202 |" &&
    assert_string_not_contains "$name" "$output" "| CC-103 |" &&
    assert_string_not_contains "$name" "$output" "| CC-104 |" &&
    assert_string_not_contains "$name" "$output" "| CC-105 |"; then
    pass "$name"
  fi
fi

if should_run "view-no-match"; then
  name="view-no-match"
  backlog="$tmp_root/view-no-match/BACKLOG.md"
  mkdir -p "$(dirname "$backlog")"
  write_view_backlog "$backlog"
  output="$(pmctl_backlog_view "$backlog" --status active --area nonexistent)"
  row_count="$(count_ticket_rows "$output")"

  if assert_string_contains "$name" "$output" "| # | Status | 主題 | 影響面 | 首次記錄 | Refs | Priority | Epic |" &&
    assert_string_contains "$name" "$output" "|---|---|---|---|---|---|---|---|" &&
    assert_exit "$name" "$row_count" "0"; then
    pass "$name"
  fi
fi

if should_run "lint-pass"; then
  name="lint-pass"
  repo="$tmp_root/lint-pass"
  setup_lint_repo "$repo"

  if ! declare -F pmctl_backlog_lint >/dev/null; then
    fail "$name" "pmctl_backlog_lint is not defined"
  else
    status=0
    pmctl_backlog_lint "$repo" || status=$?
    printf '7\n' > "$repo/validate.rc"
    status_fail=0
    pmctl_backlog_lint "$repo" || status_fail=$?
    arg_path="$(cat "$repo/validate-arg.txt")"

    if assert_exit "$name" "$status" "0" &&
      assert_exit "$name" "$status_fail" "7" &&
      assert_string_contains "$name" "$arg_path" "$repo/BACKLOG.md"; then
      pass "$name"
    fi
  fi
fi

if should_run "archive-dry-run"; then
  name="archive-dry-run"
  repo="$tmp_root/archive-dry-run"
  setup_archive_repo "$repo"

  status=0
  output="$(pmctl_backlog_archive "$repo" --dry-run 2>&1)" || status=$?

  if assert_exit "$name" "$status" "0" &&
    assert_string_contains "$name" "$output" "Would archive" &&
    assert_string_contains "$name" "$output" "Would archive 1 ticket(s)"; then
    pass "$name"
  fi
fi

if should_run "cli-view"; then
  name="cli-view"
  set +e
  output="$(bash "$REPO_ROOT/cli/pmctl" backlog view --status active 2>&1)"
  status=$?
  set -e
  row_count="$(count_ticket_rows "$output")"

  if assert_exit "$name" "$status" "0" &&
    assert_string_contains "$name" "$output" "| #  | Status | 主題 | 影響面 | 首次記錄 | Refs | Priority | Epic |" &&
    assert_string_contains "$name" "$output" "|----|--------|------|--------|----------|------|----------|------|" &&
    assert_string_contains "$name" "$output" "🔵 active"; then
    if [[ "$row_count" -gt 0 ]]; then
      pass "$name"
    else
      fail "$name" "expected at least one active backlog row from real CLI output"
    fi
  fi
fi

if should_run "cli-lint"; then
  name="cli-lint"
  set +e
  bash "$REPO_ROOT/cli/pmctl" backlog lint >/dev/null 2>&1
  status=$?
  set -e

  if assert_exit "$name" "$status" "0"; then
    pass "$name"
  fi
fi

if should_run "cli-archive-dry"; then
  name="cli-archive-dry"
  set +e
  output="$(bash "$REPO_ROOT/cli/pmctl" backlog archive --dry-run 2>&1)"
  status=$?
  set -e

  if assert_exit "$name" "$status" "0" &&
    assert_string_contains "$name" "$output" "Would archive"; then
    pass "$name"
  fi
fi

if should_run "cli-unknown-sub"; then
  name="cli-unknown-sub"
  set +e
  output="$(bash "$REPO_ROOT/cli/pmctl" backlog bogus 2>&1)"
  status=$?
  set -e

  if assert_exit "$name" "$status" "2" &&
    assert_string_contains "$name" "$output" "unknown command"; then
    pass "$name"
  fi
fi

if should_run "view-unknown-flag"; then
  name="view-unknown-flag"
  backlog="$tmp_root/view-unknown-flag/BACKLOG.md"
  mkdir -p "$(dirname "$backlog")"
  write_view_backlog "$backlog"

  set +e
  output="$(pmctl_backlog_view "$backlog" --bogus 2>&1)"
  status=$?
  set -e

  if assert_exit "$name" "$status" "2" &&
    assert_string_contains "$name" "$output" "unknown flag"; then
    pass "$name"
  fi
fi

if should_run "view-missing-status-value"; then
  name="view-missing-status-value"
  backlog="$tmp_root/view-missing-status-value/BACKLOG.md"
  mkdir -p "$(dirname "$backlog")"
  write_view_backlog "$backlog"

  set +e
  output="$(pmctl_backlog_view "$backlog" --status 2>&1)"
  status=$?
  set -e

  if assert_exit "$name" "$status" "2" &&
    assert_string_contains "$name" "$output" "missing value for --status"; then
    pass "$name"
  fi
fi

if should_run "view-missing-path"; then
  name="view-missing-path"
  set +e
  output="$(pmctl_backlog_view 2>&1)"
  status=$?
  set -e

  if assert_exit "$name" "$status" "2" &&
    assert_string_contains "$name" "$output" "missing backlog path"; then
    pass "$name"
  fi
fi

if should_run "view-precision"; then
  name="view-precision"
  backlog="$tmp_root/view-precision/BACKLOG.md"
  mkdir -p "$(dirname "$backlog")"
  write_view_backlog "$backlog"
  all_output="$(pmctl_backlog_view "$backlog")"
  status_output="$(pmctl_backlog_view "$backlog" --status active)"
  area_output="$(pmctl_backlog_view "$backlog" --area ops)"

  if assert_string_contains "$name" "$all_output" "| CC-105 |" &&
    assert_string_not_contains "$name" "$status_output" "| CC-105 |" &&
    assert_string_not_contains "$name" "$area_output" "| CC-105 |"; then
    pass "$name"
  fi
fi

if should_run "lint-forwards-failure"; then
  name="lint-forwards-failure"
  repo="$tmp_root/lint-forwards-failure"
  setup_lint_failure_repo "$repo"

  set +e
  pmctl_backlog_lint "$repo"
  status=$?
  set -e

  if assert_exit "$name" "$status" "7"; then
    pass "$name"
  fi
fi

if should_run "archive-forwards-failure"; then
  name="archive-forwards-failure"
  repo="$tmp_root/archive-forwards-failure"
  setup_archive_failure_repo "$repo"

  set +e
  pmctl_backlog_archive "$repo"
  status=$?
  set -e

  if assert_exit "$name" "$status" "5"; then
    pass "$name"
  fi
fi

if should_run "view-no-mutation"; then
  name="view-no-mutation"
  backlog="$tmp_root/view-no-mutation/BACKLOG.md"
  snapshot="$tmp_root/view-no-mutation/BACKLOG.snapshot.md"
  mkdir -p "$(dirname "$backlog")"
  write_view_backlog "$backlog"
  cp "$backlog" "$snapshot"
  output="$(pmctl_backlog_view "$backlog" --status active --area ops)"

  if assert_string_contains "$name" "$output" "| CC-101 |"; then
    if cmp -s "$backlog" "$snapshot"; then
      pass "$name"
    else
      fail "$name" "BACKLOG.md mutated during read-only view"
    fi
  fi
fi

th_summary
