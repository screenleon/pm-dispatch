#!/usr/bin/env bash
# Verify MILESTONES.md never disagrees with BACKLOG.md about whether a ticket is
# done.
#
# BACKLOG.md's index is the single authority for ticket status. MILESTONES.md
# mixes frozen delivery history (rows for tickets that have left the live index —
# left untouched here) with live planning rows whose status cell repeats the
# BACKLOG state and, in practice, lags it: a PR closes the ticket in BACKLOG but
# the MILESTONES cell keeps saying "partial" / "active" for weeks. This check is
# a ratchet against that drift.
#
# Rule: for every MILESTONES row `| CC-NNN | <summary> | <status> |` whose CC-NNN
# still appears in the BACKLOG index, the row's done-ness must match BACKLOG's.
#   BACKLOG terminal (✅ done / ✅ closed / 🚫 dropped / 🟢 superseded)
#           <-> MILESTONES cell is a "done" marker (✅… / 🚫 dropped…)
#   BACKLOG non-terminal (🔵 active / ⏸|🟡 deferred / 🟢 someday)
#           <-> MILESTONES cell is an "open" marker (🔵 / ⚠️ partial… / ⏸… / 🟡… / ✅ slice…)
# Both sides fail closed on a status token outside pm/schema.md's vocabulary.
# Rows for tickets no longer in the BACKLOG index are delivery history and are
# skipped.
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
if [[ $# -gt 0 ]]; then
  [[ $# -eq 2 && "$1" == "--repo-root" && -n "$2" ]] || {
    printf 'usage: %s [--repo-root <path>]\n' "$(basename "$0")" >&2
    exit 2
  }
  repo_root="$(cd "$2" && pwd)"
fi

backlog="$repo_root/BACKLOG.md"
milestones="$repo_root/MILESTONES.md"
for f in "$backlog" "$milestones"; do
  [[ -r "$f" ]] || { printf 'check-planning-status-consistency: missing %s\n' "${f#"$repo_root"/}" >&2; exit 1; }
done

failures=0
checked=0
fail() { printf 'check-planning-status-consistency: %s\n' "$*" >&2; failures=$((failures + 1)); }

# BACKLOG index authority: CC-NNN -> "done" | "open".
# Status vocabulary is pm/schema.md §"可接受 status token": terminal forms
# (✅ done / ✅ closed / 🚫 dropped / 🟢 superseded) collapse to "done"; the
# non-terminal forms (🔵 active / ⏸|🟡 deferred / 🟢 someday) to "open". Note
# 🟢 is used by both `someday` (open) and `superseded` (terminal) — disambiguate
# by the word. An unrecognised BACKLOG status is a schema break -> fail closed.
declare -A backlog_done=()
backlog_bad=""
while IFS= read -r line; do
  [[ "$line" =~ ^\|\ (CC-[0-9]+)\ \|\ ([^|]+)\| ]] || continue
  cc="${BASH_REMATCH[1]}"
  status="${BASH_REMATCH[2]}"
  status="${status#"${status%%[![:space:]]*}"}"
  status="${status%"${status##*[![:space:]]}"}"
  case "$status" in
    "✅ done"*|"✅ closed"*|"🚫 dropped"*|"🟢 superseded"*) backlog_done["$cc"]="done" ;;
    "🔵 active"*|"⏸ deferred"*|"🟡 deferred"*|"🟢 someday"*) backlog_done["$cc"]="open" ;;
    *) backlog_bad="$cc [$status]" ;;
  esac
done < "$backlog"

[[ -z "$backlog_bad" ]] || { fail "unrecognised BACKLOG.md index status for $backlog_bad — not in pm/schema.md status vocabulary"; exit 1; }
[[ "${#backlog_done[@]}" -gt 0 ]] || { fail "parsed no CC rows from BACKLOG.md index — format changed"; exit 1; }

# MILESTONES live rows: `| CC-NNN | <summary> | <status cell> |`
while IFS= read -r line; do
  [[ "$line" =~ ^\|\ (CC-[0-9]+)\ \|.*\|\ ([^|]*)\|\ *$ ]] || continue
  cc="${BASH_REMATCH[1]}"
  cell="${BASH_REMATCH[2]}"
  # trim
  cell="${cell#"${cell%%[![:space:]]*}"}"
  cell="${cell%"${cell##*[![:space:]]}"}"

  # Not in the live BACKLOG index -> frozen delivery history, skip.
  [[ -n "${backlog_done[$cc]:-}" ]] || continue
  checked=$((checked + 1))

  # Classify the cell into done / open, failing on any marker outside the set
  # DECISIONS.md 2026-08-28 documents — otherwise a typo like `pending` on an
  # open ticket rides through as "open" and the ratchet never catches it.
  milestone_done=""
  case "$cell" in
    # `✅ slice ...` is deliberate slice-level tracking under an umbrella ticket
    # that legitimately stays open in BACKLOG — not a completion claim.
    "✅ slice"*)                                milestone_done="open" ;;
    "✅"*|"🚫 dropped"*)                        milestone_done="done" ;;
    "🔵"*|"⚠️ partial"*|"⏸ deferred"*|"🟡"*)   milestone_done="open" ;;
  esac
  if [[ -z "$milestone_done" ]]; then
    fail "$cc has an unrecognised MILESTONES status marker [$cell] — use one of ✅… / 🚫 dropped… / ✅ slice… / 🔵 / ⚠️ partial… / ⏸ deferred… / 🟡… (DECISIONS.md 2026-08-28)"
    continue
  fi

  if [[ "${backlog_done[$cc]}" == "done" && "$milestone_done" != "done" ]]; then
    fail "$cc is terminal (done/closed/dropped/superseded) in BACKLOG.md but MILESTONES.md still shows [$cell] — reconcile the MILESTONES status cell (BACKLOG is the authority)"
  elif [[ "${backlog_done[$cc]}" == "open" && "$milestone_done" == "done" ]]; then
    fail "$cc shows [$cell] in MILESTONES.md but is not a terminal status in BACKLOG.md — MILESTONES claims completion the authority does not"
  fi
done < "$milestones"

if [[ "$failures" -eq 0 ]]; then
  printf 'check-planning-status-consistency: OK (%s live MILESTONES ticket rows agree with BACKLOG.md)\n' "$checked"
  exit 0
fi
exit 1
