#!/usr/bin/env bash
# Assert one ticket id never maps to two different tickets across the active
# board and the archive.
#
# Invariant: the active BACKLOG and the archive partition the id space. A
# non-stub ticket lives in exactly one of them. A ✅/🚫 heading on the active
# board is a tombstone pointer to the archived copy of the SAME ticket and is
# legitimate. So a collision is an id that is OPEN (non-stub) on the active
# board while ALSO being a closed ticket in the archive — the fingerprint of a
# reused number (the id was shipped under one meaning, then handed to a second,
# unrelated forward ticket). Caught at lint time instead of by manual reading.
#
# Usage: lint-ticket-ids.sh <BACKLOG.md> <BACKLOG-ARCHIVE.md>
# Exit 0 clean; 1 on collision (E-ID-COLLISION); 2 on usage/file error.

set -euo pipefail
export LC_ALL=C.UTF-8

usage() {
  printf 'Usage: lint-ticket-ids.sh <BACKLOG.md> <BACKLOG-ARCHIVE.md>\n' >&2
}

if [ "$#" -ne 2 ]; then
  usage
  exit 2
fi

backlog=$1
archive=$2

for f in "$backlog" "$archive"; do
  if [ ! -f "$f" ]; then
    printf 'E-SCHEMA-HEADER: file not found: %s\n' "$f" >&2
    exit 2
  fi
done

# Ticket id shape mirrors pm/scripts/validate.sh (prefix-agnostic; sub-letter
# suffix allowed). Body headings look like: `## <ID> — <title>[ <status>]`.
id_re='[A-Z][A-Z0-9]*-[0-9][0-9]*[a-z]*'
heading_re="^## +${id_re} +—"

# A closed/dropped tombstone stub ends with a TERMINAL status marker:
# `## <id> — <title> ✅ YYYY-MM-DD` (or 🚫). Anchor on the trailing
# `(✅|🚫) <date>` so an open ticket whose *title* happens to contain ✅/🚫
# is not misread as a stub and allowed to evade a collision.
stub_re='(✅|🚫) +[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9] *$'

ids_in() {
  # Print one id per matching body heading on stdin, newline-separated.
  sed -nE "s/^## +(${id_re}) +—.*/\1/p"
}

# Open (non-stub) ids on the active board: body headings minus the ✅/🚫
# tombstone stubs (those legitimately mirror an archived copy of the same
# ticket). A superseded heading keeps the id occupied, so it stays "open" here.
# The trailing `|| true` keeps an empty result — a board with no open tickets
# (only tombstone stubs), or no headings at all — from tripping `pipefail` when
# a grep stage matches nothing; an empty id set is a valid, collision-free state.
active_open=$(grep -E "$heading_re" "$backlog" | grep -vE "$stub_re" \
  | ids_in | sort -u || true)

# Every archive body heading is, by construction, a closed ticket.
archive_ids=$(grep -E "$heading_re" "$archive" | ids_in | sort -u || true)

collisions=$(comm -12 <(printf '%s\n' "$active_open") <(printf '%s\n' "$archive_ids"))

bad=0
while IFS= read -r id; do
  [ -n "$id" ] || continue
  # `|| true` guards against `head` closing the pipe early (SIGPIPE on the
  # upstream grep) tripping pipefail inside the command substitution.
  active_title=$(grep -E "^## +${id} +—" "$backlog" | grep -vE "$stub_re" \
    | head -n1 | sed -E "s/^## +${id} +—[ ]*//" || true)
  archive_title=$(grep -E "^## +${id} +—" "$archive" \
    | head -n1 | sed -E "s/^## +${id} +—[ ]*//" || true)
  printf 'E-ID-COLLISION: %s is open on the active board but already closed in the archive (active="%s" | archive="%s")\n' \
    "$id" "$active_title" "$archive_title" >&2
  bad=1
done <<EOF
$collisions
EOF

exit "$bad"
