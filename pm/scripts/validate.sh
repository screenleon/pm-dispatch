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

if [ -z "$decisions" ] && [ -z "$changelog" ]; then
  candidate_changelog=$(CDPATH= cd -- "$(dirname -- "$backlog")" && pwd)/CHANGELOG.md
  if [ -f "$candidate_changelog" ]; then
    changelog=$candidate_changelog
  fi
fi

# schema 宣告是解析前提，缺少時立即停止。
if ! sed -n '1,5p' "$backlog" | grep -Fxq '<!-- pm-schema: v1 -->'; then
  printf 'E-SCHEMA-HEADER: missing pm-schema v1 marker in first 5 lines: %s\n' "$backlog" >&2
  exit 2
fi

set +e
awk '
function trim(s) {
  gsub(/^[ \t\r\n]+/, "", s)
  gsub(/[ \t\r\n]+$/, "", s)
  return s
}

function valid_date(s) {
  return s ~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$/
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

function date_token(line) {
  if (match(line, /[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]/)) {
    return substr(line, RSTART, RLENGTH)
  }
  return ""
}

function note_body_closure_date(id, raw, date) {
  date = raw
  if (date ~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]/) {
    body_marker_date[id] = substr(date, 1, 10)
    return
  }
  body_marker_date[id] = raw
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
  s = line
  while (match(s, /[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]/)) {
    d = substr(s, RSTART, RLENGTH)
    body_outcome_dates[id] = body_outcome_dates[id] " " d
    s = substr(s, RSTART + RLENGTH)
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
  if (line ~ /^## +[A-Z][A-Z0-9]*-[0-9][0-9][0-9] +—/) {
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

function parse_index_row(line, n, f, id, status, first_date, area, refs) {
  n = split(line, f, "|")
  if (n < 7) return
  id = trim(f[2])
  if (id !~ /^[A-Z][A-Z0-9]*-[0-9][0-9][0-9]$/) return

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
}

{
  line = $0
  parse_index_row(line)
  note_body_id(line)
  if (current_id != "" && line ~ /^\*\*Tags\*\*:/) parse_tags(current_id, line)
  if (current_id != "" && line ~ /^\*\*See\*\*:/) body_see[current_id] = 1
  if (current_id != "" && line ~ /^\*\*Outcome\*\*:/) note_outcome_date(current_id, line)
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
        body_done_date = body_marker_date[id]
        if (body_done_date != row_done_date[id]) {
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
  exit bad ? 1 : 0
}
' "$backlog"
backlog_rc=$?
set -e

drift_rc=0
if [ -n "$changelog" ]; then
  set +e
  awk -v backlog_file="$backlog" -v changelog_file="$changelog" '
function trim(s) {
  gsub(/^[ \t\r\n]+/, "", s)
  gsub(/[ \t\r\n]+$/, "", s)
  return s
}

function emit(code, ctx) {
  print code ": " ctx > "/dev/stderr"
  bad = 1
}

function note_pr_status(tok, status) {
  if (!(tok in pr_status) || pr_status[tok] != "closed") pr_status[tok] = status
}

function note_index_refs(line, n, f, id, refs, status, s, tok) {
  n = split(line, f, "|")
  if (n < 7) return
  id = trim(f[2])
  if (id !~ /^[A-Z][A-Z0-9]*-[0-9][0-9][0-9]$/) return
  status = trim(f[3])
  if (status ~ /^✅ closed /) {
    status = "closed"
  } else if (status == "🔵 active") {
    status = "active"
  } else if (status == "✅ done") {
    status = "done"
  } else if (status == "⏸ deferred" || status == "🟡 deferred") {
    status = "deferred"
  } else if (status ~ /^🚫 dropped /) {
    status = "dropped"
  } else {
    status = "unknown"
  }
  refs = trim(f[7])
  s = refs
  while (match(s, /pr:#[0-9][0-9]*/)) {
    tok = substr(s, RSTART, RLENGTH)
    note_pr_status(tok, status)
    s = substr(s, RSTART + RLENGTH)
  }
}

function note_changelog_prs(line, s, tok) {
  s = line
  while (match(s, /pr:#[0-9][0-9]*/)) {
    tok = substr(s, RSTART, RLENGTH)
    changelog_pr[tok] = 1
    s = substr(s, RSTART + RLENGTH)
  }
}

FILENAME == backlog_file {
  note_index_refs($0)
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
  if (!found_unreleased) exit 0
  for (tok in changelog_pr) {
    if (!(tok in pr_status)) {
      emit("E-CHANGELOG-DRIFT", tok " referenced in [Unreleased] but no backlog row references it")
    } else if (pr_status[tok] != "closed") {
      emit("E-CHANGELOG-DRIFT", tok " referenced in [Unreleased] but backlog row status is " pr_status[tok])
    }
  }
  exit bad ? 1 : 0
}
' "$backlog" "$changelog"
  drift_rc=$?
  set -e
fi

if [ "$backlog_rc" -eq 2 ] || [ "$drift_rc" -eq 2 ]; then
  exit 2
fi
if [ "$backlog_rc" -ne 0 ] || [ "$drift_rc" -ne 0 ]; then
  exit 1
fi
exit 0
