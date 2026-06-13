#!/usr/bin/env bash
# archive-closed-backlog.sh
#
# Applies the pm-schema §4 "working-set" bloat policy: a terminal ticket is
# moved OUT of BACKLOG.md entirely — both its index row and its body section —
# and its body is appended to BACKLOG-ARCHIVE.md. BACKLOG.md is left as a pure
# working set of non-terminal tickets; no `**See**:` stub remains.
#
# Terminal index statuses — single source of truth is pm/schema.md §2.3; this
# comment and the awk predicate below must track it (CC-378, 2026-06-14):
# `✅ done` (with or without date), `✅ closed YYYY-MM-DD`,
# `🟢 superseded YYYY-MM-DD`, `🚫 dropped YYYY-MM-DD`. `✅ done` is terminal (the
# soft-close-stays-active rule was retired — in practice `done`/`superseded`
# were the real close states while the archiver only swept the unused
# `closed`/`dropped`, so the policy never fired and finished tickets piled up).
# Non-terminal (`🔵 active`, `🟡`/`⏸ deferred`, `🟢 someday`, `⚠️ partial`) are
# left untouched.
#
# Status is read from the INDEX table (the schema §6.1 source of truth). A
# body section is archived when its ticket's index status is terminal; bodies
# already present in BACKLOG-ARCHIVE.md (matched by exact heading) are not
# re-appended, which also makes the run idempotent and immune to the CC-283
# sentinel false-negative (we no longer scan body prose for `**See**:`).
#
# Pre-existing `**See**:` stubs + their index rows (the legacy archive shape)
# are swept on the next run: the row is terminal so it is dropped, and the
# stub body's heading already lives in the archive so it is not duplicated.
#
# Usage:
#   archive-closed-backlog.sh [--dry-run]

set -euo pipefail
export LC_ALL=C.UTF-8

DRY_RUN=0
for arg in "$@"; do
  case "$arg" in
    --dry-run)
      DRY_RUN=1
      ;;
    *)
      printf 'unknown arg: %s\n' "$arg" >&2
      exit 1
      ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BACKLOG="$REPO_ROOT/BACKLOG.md"
ARCHIVE="$REPO_ROOT/BACKLOG-ARCHIVE.md"
TODAY="$(date +%Y-%m-%d)"

TMP_BACKLOG="$(mktemp)"
TMP_COUNT="$(mktemp)"
TMP_DETAIL_APPEND="$(mktemp)"
trap 'rm -f "$TMP_BACKLOG" "$TMP_COUNT" "$TMP_DETAIL_APPEND"' EXIT

awk -v detail_append="$TMP_DETAIL_APPEND" -v dry_run="$DRY_RUN" -v count_file="$TMP_COUNT" '
function id_from_row(line,    f) {
  # "| CC-123 | ..." / "| CC-104b | ..." -> "CC-123" / "CC-104b"
  f = line
  sub(/^\|[ \t]*/, "", f)
  sub(/[ \t]*\|.*/, "", f)
  return f
}
function id_from_header(line,    s) {
  # "## CC-104b — title ✅ 2026-..." -> "CC-104b"
  s = line
  sub(/^##[ \t]+/, "", s)
  sub(/[ \t].*/, "", s)
  return s
}
function flush_section(    i) {
  if (cur_terminal) {
    body_seen_for[cur_id] = 1
    if (!(section_hdr in known_archived)) {
      newly_archived++
      if (!dry_run) {
        printf "%s\n", section_hdr >> detail_append
        for (i = 1; i <= body_n; i++) printf "%s\n", body[i] >> detail_append
      }
    }
    # dropped from BACKLOG (no stub left behind)
  } else {
    print section_hdr
    for (i = 1; i <= body_n; i++) print body[i]
  }
  body_n = 0
  delete body
  in_section = 0
  cur_terminal = 0
  cur_id = ""
  section_hdr = ""
}

BEGIN { in_section = 0; cur_terminal = 0; body_n = 0 }

# ID grammar (pm-schema §2.2, prefix-agnostic for cross-repo use):
#   PREFIX-NNN with an optional lowercase sub-ticket suffix, e.g. CC-229,
#   JS-106, CC-104b. Heading form: "## <ID> — ...". Index row: "| <ID> | ...".

# ---- pass 1: existing archive — remember archived body headings for dedup ----
FNR == NR {
  if (/^## [A-Z][A-Z0-9]*-[0-9]+[a-z]* /) known_archived[$0] = 1
  next
}

# ---- pass 2: BACKLOG ----
# Body section boundary.
/^## [A-Z][A-Z0-9]*-[0-9]+[a-z]* / {
  if (in_section) flush_section()
  section_hdr = $0
  in_section = 1
  cur_id = id_from_header($0)
  cur_terminal = (cur_id in terminal_id)
  next
}

in_section {
  body[++body_n] = $0
  next
}

# Index rows live before the first body section. Drop terminal rows; the
# status column (field 3) is the schema §6.1 source of truth.
/^\|[ \t]*[A-Z][A-Z0-9]*-[0-9]+[a-z]*[ \t]*\|/ {
  split($0, cols, "|")
  status = cols[3]
  gsub(/^[ \t]+|[ \t]+$/, "", status)
  rid = id_from_row($0)
  # Terminal iff status is an EXACT token/date form (pm/schema.md §2.3). A loose
  # prefix match would archive malformed near-misses like "✅ done-ish" or
  # "🟢 supersededsoon" (CC-378 gate fix). `done` date is optional; closed /
  # superseded / dropped require YYYY-MM-DD.
  if (status ~ /^✅ done$/ ||
      status ~ /^✅ done [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$/ ||
      status ~ /^✅ closed [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$/ ||
      status ~ /^🟢 superseded [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$/ ||
      status ~ /^🚫 dropped [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$/) {
    terminal_id[rid] = 1
    removed_rows++
    next
  }
  print
  next
}

{ print }

END {
  if (in_section) flush_section()
  # Observability: a terminal index row with no body section in BACKLOG is just
  # a row drop — flag it so operators can reconcile (its body should already be
  # in the archive or in git history; a true orphan would otherwise be silent).
  for (id in terminal_id) {
    if (!(id in body_seen_for)) {
      printf "warning: %s — terminal index row dropped with no matching body section in BACKLOG.md (body already archived or orphaned)\n", id > "/dev/stderr"
    }
  }
  printf "%d %d\n", removed_rows, newly_archived > count_file
}
' "$ARCHIVE" "$BACKLOG" > "$TMP_BACKLOG"

read -r archived_count newly_count < "$TMP_COUNT"

if [[ "$DRY_RUN" -eq 1 ]]; then
  printf 'Would archive %d ticket(s) (%d body section(s) new to archive)\n' "$archived_count" "$newly_count"
  exit 0
fi

if [[ "$archived_count" -gt 0 ]]; then
  TMP_ARCHIVE="$(mktemp)"
  trap 'rm -f "$TMP_BACKLOG" "$TMP_COUNT" "$TMP_DETAIL_APPEND" "$TMP_ARCHIVE"' EXIT
  cat "$ARCHIVE" "$TMP_DETAIL_APPEND" > "$TMP_ARCHIVE"
  sed -i "s/^Last archived: .*/Last archived: $TODAY/" "$TMP_ARCHIVE"
  sed -i "s/^<!-- pm-dispatch: backlog-archive [0-9-]* -->/<!-- pm-dispatch: backlog-archive $TODAY -->/" "$TMP_ARCHIVE"
  # Write ARCHIVE first — if the BACKLOG write then fails, a re-run dedups the
  # already-appended bodies (heading match) and still drops the rows safely.
  mv "$TMP_ARCHIVE" "$ARCHIVE"
  mv "$TMP_BACKLOG" "$BACKLOG"
fi

printf 'Archived %d ticket(s) (%d body section(s) new to archive)\n' "$archived_count" "$newly_count"
