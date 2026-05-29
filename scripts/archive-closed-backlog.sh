#!/usr/bin/env bash
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
trap 'rm -f "$TMP_BACKLOG" "$TMP_COUNT"' EXIT

awk -v archive_file="$ARCHIVE" -v dry_run="$DRY_RUN" -v count_file="$TMP_COUNT" '
function flush_section(    i, has_see) {
  has_see = 0
  for (i = 1; i <= body_n; i++) {
    if (body[i] ~ /\*\*See\*\*:.*BACKLOG-ARCHIVE/) {
      has_see = 1
      break
    }
  }

  if (is_terminal && !has_see) {
    if (!dry_run) {
      printf "%s\n", section_hdr >> archive_file
      for (i = 1; i <= body_n; i++) {
        printf "%s\n", body[i] >> archive_file
      }
    }
    archived++
    print section_hdr
    print ""
    print "**See**: BACKLOG-ARCHIVE.md"
    print ""
  } else {
    print section_hdr
    for (i = 1; i <= body_n; i++) {
      print body[i]
    }
  }

  body_n = 0
  delete body
  is_terminal = 0
  section_hdr = ""
}

BEGIN {
  in_section = 0
  is_terminal = 0
  body_n = 0
  archived = 0
  section_hdr = ""
}

/^## / {
  if (in_section) {
    flush_section()
  }
  section_hdr = $0
  in_section = 1
  is_terminal = (index(section_hdr, "\xe2\x9c\x85") > 0 || index(section_hdr, "\xf0\x9f\x9a\xab") > 0)
  next
}

in_section {
  body_n++
  body[body_n] = $0
  next
}

{
  print
}

END {
  if (in_section) {
    flush_section()
  }
  printf "%d\n", archived > count_file
}
' "$BACKLOG" > "$TMP_BACKLOG"

archived_count="$(cat "$TMP_COUNT")"

if [[ "$DRY_RUN" -eq 1 ]]; then
  printf 'Would archive %d section(s)\n' "$archived_count"
  exit 0
fi

if [[ "$archived_count" -gt 0 ]]; then
  mv "$TMP_BACKLOG" "$BACKLOG"
  sed -i "s/^Last archived: .*/Last archived: $TODAY/" "$ARCHIVE"
  sed -i "s/^<!-- pm-dispatch: backlog-archive [0-9-]* -->/<!-- pm-dispatch: backlog-archive $TODAY -->/" "$ARCHIVE"
fi

printf 'Archived %d section(s)\n' "$archived_count"
