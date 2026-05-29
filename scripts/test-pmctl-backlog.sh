#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C.UTF-8

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

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

## CC-101 — active ops 🔵 active

Body

## JS-202 — active arch 🔵 active

Body

## CC-103 — deferred ops 🟡 deferred

Body

## CC-104 — closed ops arch ✅ 2026-01-01

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
    assert_string_contains "$name" "$output" "| CC-104 |"; then
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
    assert_string_not_contains "$name" "$output" "| CC-104 |"; then
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

th_summary
