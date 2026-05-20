#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C.UTF-8

# Bootstrap warning: detect pre-cutover state where ~/.claude/.pm is still a
# real directory. Warn but do not abort; canonical-path invocation still works.
if [ -e "$HOME/.claude/.pm" ] && [ ! -L "$HOME/.claude/.pm" ] && ! ps -o args= -p "${PPID:-0}" 2>/dev/null | grep -Fq 'pm/scripts/test/run-tests.sh'; then
  printf 'warn: %s is a real directory, not a symlink. Run %s/install.sh to complete pm-schema cutover.\n' \
    "$HOME/.claude/.pm" \
    "$HOME/github/pm-dispatch" >&2
fi

usage() {
  printf 'Usage: validate.sh <BACKLOG.md> [DECISIONS.md] [CHANGELOG.md]\n' >&2
}

if [ "$#" -lt 1 ] || [ "$#" -gt 3 ]; then
  usage
  exit 1
fi

backlog=$1
decisions=${2:-}
changelog=${3:-}

if [ ! -f "$backlog" ]; then
  printf 'E-SCHEMA-HEADER: file not found: %s\n' "$backlog" >&2
  exit 2
fi

if [ -n "$decisions" ] && [ ! -f "$decisions" ]; then
  printf 'E-SCHEMA-HEADER: decisions file not found: %s\n' "$decisions" >&2
  exit 2
fi

if [ -n "$changelog" ] && [ ! -f "$changelog" ]; then
  printf 'E-SCHEMA-HEADER: changelog file not found: %s\n' "$changelog" >&2
  exit 2
fi

if [ -z "$changelog" ]; then
  candidate_changelog=$(CDPATH= cd -- "$(dirname -- "$backlog")" && pwd)/CHANGELOG.md
  if [ -f "$candidate_changelog" ]; then
    changelog=$candidate_changelog
  fi
fi

# schema 宣告是解析前提，缺少時立即停止。
schema_ver=""
if sed -n '1,5p' "$backlog" | grep -Fxq '<!-- pm-schema: v1.2 -->'; then
  schema_ver="v1.2"
elif sed -n '1,5p' "$backlog" | grep -Fxq '<!-- pm-schema: v1.1 -->'; then
  schema_ver="v1.1"
elif sed -n '1,5p' "$backlog" | grep -Fxq '<!-- pm-schema: v1 -->'; then
  schema_ver="v1"
else
  printf 'E-SCHEMA-HEADER: missing pm-schema v1/v1.1/v1.2 marker in first 5 lines: %s\n' "$backlog" >&2
  exit 2
fi

set +e
awk -v backlog_file="$backlog" \
    -v changelog_file="${changelog:-}" \
    -v schema_ver="$schema_ver" \
    '
function trim(s) {
  gsub(/^[ \t\r\n]+/, "", s)
  gsub(/[ \t\r\n]+$/, "", s)
  return s
}

function split_md_row(line, f, i, c, prev, n) {
  delete f
  n = 1
  f[n] = ""
  prev = ""
  for (i = 1; i <= length(line); i++) {
    c = substr(line, i, 1)
    if (c == "|" && prev != "\\") {
      n++
      f[n] = ""
    } else {
      f[n] = f[n] c
    }
    prev = c
  }
  return n
}

function valid_date(s) {
  return s ~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$/
}

function valid_priority(s) {
  return (s == "P1" || s == "P2" || s == "P3" || s == "—")
}

function valid_epic(s) {
  return (s == "oss" || s == "reuse-debt" || s == "hygiene" || s == "design" || s == "—")
}

function norm_area(s) {
  if (s == "architecture") return "arch"
  if (s == "operations") return "ops"
  if (s == "con") return "connector"
  return s
}

function valid_area_token(s) {
  s = norm_area(s)
  return (s == "arch" || s == "backend" || s == "frontend" || s == "content" || s == "ops" || s == "connector" || s == "DX" || s == "product" || s == "ux" || s == "process" || s == "memory" || s == "token" || s == "test" || s == "gate")
}

function emit(code, ctx) {
  print code ": " ctx > "/dev/stderr"
  bad = 1
}

function warn(code, ctx) {
  print code ": " ctx > "/dev/stderr"
}

BEGIN {
  pr_token_re = "pr:([A-Za-z0-9._-]+/[A-Za-z0-9._-]+)?#[0-9][0-9]*"
}

function note_body_closure_date(id, raw, date) {
  date = raw
  if (date ~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9][ \t]*$/) {
    body_marker_date[id] = substr(date, 1, 10)
    return
  }
  # A body heading marker must end after the date; trailing junk is stub shape, not a date mismatch.
  body_marker_date[id] = raw
  body_marker_invalid[id] = 1
  if (!valid_date(raw)) emit("E-DATE-FORMAT", id " invalid body marker date: " raw)
}

function parse_refs(id, refs, raw, n, i, tok, p) {
  refs = trim(refs)
  if (refs == "" || refs == "—") return
  raw = refs
  n = split(raw, parts, ",")
  for (i = 1; i <= n; i++) {
    tok = trim(parts[i])
    if (tok == "") continue
    p = tok
    sub(/:.*/, "", p)
    if (tok !~ /:/ || !(p == "decisions" || p == "roadmap" || p == "pr" || p == "commit" || p == "feedback")) {
      emit("E-REFS-PREFIX", id " invalid ref: " tok)
    }
  }
}

function note_outcome_date(id, line, s, d) {
  if (line ~ /^\*\*Outcome\*\*: [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]([ \t]|$)/) {
    d = line
    sub(/^\*\*Outcome\*\*: /, "", d)
    d = substr(d, 1, 10)
    body_outcome_dates[id] = body_outcome_dates[id] " " d
  }
}

function parse_area(id, area, n, i, tok) {
  area = trim(area)
  n = split(area, bits, "/")
  if (n < 1 || n > 2) {
    emit("E-AREA-ENUM", id " invalid area: " area)
    return
  }
  for (i = 1; i <= n; i++) {
    tok = trim(bits[i])
    if (!valid_area_token(tok)) {
      emit("E-AREA-ENUM", id " invalid area: " area)
      return
    }
  }
}

function parse_status(id, status, d) {
  status = trim(status)
  if (status == "🔵 active") {
    row_kind[id] = "active"
    return
  }
  if (status == "✅ done") {
    row_kind[id] = "done"
    return
  }
  if (status == "⏸ deferred") {
    row_kind[id] = "deferred"
    return
  }
  if (status == "🟡 deferred") {
    row_kind[id] = "deferred"
    return
  }
  if (status == "🟢 someday") {
    row_kind[id] = "deferred"
    return
  }
  if (status ~ /^⚠️ partial /) {
    d = status
    sub(/^⚠️ partial /, "", d)
    row_kind[id] = "active"
    if (!valid_date(d)) emit("E-DATE-FORMAT", id " invalid partial date: " d)
    return
  }
  if (status ~ /^✅ closed /) {
    d = status
    sub(/^✅ closed /, "", d)
    row_kind[id] = "closed"
    row_done_date[id] = d
    if (!valid_date(d)) emit("E-DATE-FORMAT", id " invalid closure date: " d)
    return
  }
  if (status ~ /^🚫 dropped /) {
    d = status
    sub(/^🚫 dropped /, "", d)
    row_kind[id] = "dropped"
    row_done_date[id] = d
    if (!valid_date(d)) emit("E-DATE-FORMAT", id " invalid closure date: " d)
    return
  }
  emit("E-STATUS-ENUM", id " invalid status: " status)
}

function parse_tags(id, text, n, i, tok) {
  sub(/^\*\*Tags\*\*:[ \t]*/, "", text)
  sub(/[ \t]*<!--.*/, "", text)
  n = split(text, tags, ",")
  for (i = 1; i <= n; i++) {
    tok = trim(tags[i])
    if (!(tok ~ /^P[1-3]$/ || tok ~ /^M[0-9][0-9]*$/)) {
      emit("E-TAGS-FORMAT", id " invalid tag: " tok)
    }
  }
}

function note_body_id(line, id) {
  if (line ~ /^## +[A-Z][A-Z0-9]*-[0-9][0-9][0-9][a-z]* +—/) {
    id = line
    sub(/^## +/, "", id)
    sub(/ +—.*/, "", id)
    body_seen[id]++
    if (body_seen[id] == 2) emit("E-INDEX-MISMATCH", id " appears more than once in body")
    current_id = id
    if (line ~ /✅/) {
      body_stub[id] = 1
      done_date = line
      sub(/^.*✅[ \t]*/, "", done_date)
      note_body_closure_date(id, done_date)
    }
    if (line ~ /🚫/) {
      body_stub[id] = 1
      done_date = line
      sub(/^.*🚫[ \t]*/, "", done_date)
      note_body_closure_date(id, done_date)
    }
  } else if (line ~ /^## /) {
    current_id = ""
  }
}

function note_pr_status(tok, status) {
  if (!(tok in pr_status) || pr_status[tok] != "closed") pr_status[tok] = status
}

function note_changelog_prs(line, s, tok) {
  s = line
  while (match(s, pr_token_re)) {
    tok = substr(s, RSTART, RLENGTH)
    changelog_pr[tok] = 1
    s = substr(s, RSTART + RLENGTH)
  }
}

function parse_index_row(line, n, f, id, status, first_date, area, refs, priority, epic, kind, s, tok) {
  n = split_md_row(line, f)
  if (n < 7) return
  id = trim(f[2])
  if (id !~ /^[A-Z][A-Z0-9]*-[0-9][0-9][0-9][a-z]*$/) return

  index_seen[id]++
  if (index_seen[id] == 2) emit("E-DUP-ID", id " appears more than once in index")

  status = trim(f[3])
  area = trim(f[5])
  first_date = trim(f[6])
  refs = trim(f[7])

  parse_status(id, status)
  parse_area(id, area)
  if (!valid_date(first_date)) emit("E-DATE-FORMAT", id " invalid first-record date: " first_date)
  parse_refs(id, refs)

  kind = (row_kind[id] != "" ? row_kind[id] : "unknown")
  s = refs
  while (match(s, pr_token_re)) {
    tok = substr(s, RSTART, RLENGTH)
    note_pr_status(tok, kind)
    s = substr(s, RSTART + RLENGTH)
  }

  if (schema_ver == "v1.1" || schema_ver == "v1.2") {
    if (n < 10) {
      warn("W-MISSING-COLS", id " missing priority and/or epic columns (v1.1/v1.2 file)")
    } else {
      priority = trim(f[8])
      epic     = trim(f[9])
      if (!valid_priority(priority)) emit("E-PRIORITY-ENUM", id " invalid priority: " priority)
      if (!valid_epic(epic))         emit("E-EPIC-ENUM",     id " invalid epic: " epic)
    }
  }
}

FILENAME == backlog_file {
  line = $0
  parse_index_row(line)
  note_body_id(line)
  if (current_id != "" && line ~ /^\*\*Tags\*\*:/) parse_tags(current_id, line)
  if (current_id != "" && line ~ /^\*\*See\*\*:/) body_see[current_id] = 1
  if (current_id != "" && line ~ /^\*\*Outcome\*\*:/) note_outcome_date(current_id, line)
  next
}

FILENAME == changelog_file {
  if ($0 ~ /^## +\[Unreleased\]/) {
    in_unreleased = 1
    found_unreleased = 1
    next
  }
  if (in_unreleased && $0 ~ /^## +/) {
    in_unreleased = 0
  }
  if (in_unreleased) note_changelog_prs($0)
}

END {
  for (id in index_seen) {
    if (!(id in body_seen)) emit("E-INDEX-MISMATCH", id " present in index but missing from body")
    if ((row_kind[id] == "closed" || row_kind[id] == "dropped" || body_stub[id]) && !body_see[id]) {
      emit("E-CLOSURE-NO-SEE", id " closed/dropped stub missing See")
    }
    if (row_kind[id] == "closed" || row_kind[id] == "dropped") {
      body_done_date = "missing"
      if (id in body_marker_date) {
        if (!(id in body_marker_invalid)) {
          body_done_date = body_marker_date[id]
        }
        if (!(id in body_marker_invalid) && body_done_date != row_done_date[id]) {
          emit("E-CLOSURE-DATE-MISMATCH", id " index=" row_done_date[id] " body=" body_done_date)
        }
      } else if (id in body_outcome_dates) {
        if (index(body_outcome_dates[id] " ", " " row_done_date[id] " ") == 0) {
          emit("E-CLOSURE-DATE-MISMATCH", id " index=" row_done_date[id] " body=" trim(body_outcome_dates[id]))
        }
      } else {
        emit("E-CLOSURE-DATE-MISMATCH", id " index=" row_done_date[id] " body=" body_done_date)
      }
    }
  }
  for (id in body_seen) {
    if (!(id in index_seen)) emit("E-INDEX-MISMATCH", id " present in body but missing from index")
  }

  if (!found_unreleased) exit bad ? 1 : 0
  for (tok in changelog_pr) {
    if (!(tok in pr_status)) {
      emit("E-CHANGELOG-DRIFT", tok " referenced in [Unreleased] but no backlog row references it")
    } else if (pr_status[tok] != "closed") {
      emit("E-CHANGELOG-DRIFT", tok " referenced in [Unreleased] but backlog row status is " pr_status[tok])
    }
  }
  exit bad ? 1 : 0
}
' "$backlog" ${changelog:+"$changelog"}
rc=$?
set -e

if [ "$rc" -ne 0 ]; then
  exit 1
fi
exit 0
