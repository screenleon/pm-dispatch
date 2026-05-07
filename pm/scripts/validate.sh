#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C.UTF-8

# Bootstrap warning: detect pre-cutover state where ~/github/.pm is still a
# real directory. Warn but do not abort; canonical-path invocation still works.
if [ -e "$HOME/github/.pm" ] && [ ! -L "$HOME/github/.pm" ] && ! ps -o args= -p "${PPID:-0}" 2>/dev/null | grep -Fq 'pm/scripts/test/run-tests.sh'; then
  printf 'warn: %s is a real directory, not a symlink. Run %s/install.sh to complete pm-schema cutover.\n' \
    "$HOME/github/.pm" \
    "$HOME/github/claude-config" >&2
fi

usage() {
  printf 'Usage: validate.sh <BACKLOG.md> [DECISIONS.md]\n' >&2
}

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
  usage
  exit 1
fi

backlog=$1
decisions=${2:-}

if [ ! -f "$backlog" ]; then
  printf 'E-SCHEMA-HEADER: file not found: %s\n' "$backlog" >&2
  exit 2
fi

if [ -n "$decisions" ] && [ ! -f "$decisions" ]; then
  printf 'E-SCHEMA-HEADER: decisions file not found: %s\n' "$decisions" >&2
  exit 2
fi

# schema 宣告是解析前提，缺少時立即停止。
if ! sed -n '1,5p' "$backlog" | grep -Fxq '<!-- pm-schema: v1 -->'; then
  printf 'E-SCHEMA-HEADER: missing pm-schema v1 marker in first 5 lines: %s\n' "$backlog" >&2
  exit 2
fi

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
  return (s == "arch" || s == "backend" || s == "frontend" || s == "content" || s == "ops" || s == "connector" || s == "DX" || s == "product")
}

function emit(code, ctx) {
  print code ": " ctx > "/dev/stderr"
  bad = 1
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
      if (!valid_date(done_date)) emit("E-DATE-FORMAT", id " invalid body marker date: " done_date)
    }
    if (line ~ /🚫/) {
      body_stub[id] = 1
      done_date = line
      sub(/^.*🚫[ \t]*/, "", done_date)
      if (!valid_date(done_date)) emit("E-DATE-FORMAT", id " invalid body marker date: " done_date)
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
}

END {
  for (id in index_seen) {
    if (!(id in body_seen)) emit("E-INDEX-MISMATCH", id " present in index but missing from body")
    if ((row_kind[id] == "closed" || row_kind[id] == "dropped" || body_stub[id]) && !body_see[id]) {
      emit("E-CLOSURE-NO-SEE", id " closed/dropped stub missing See")
    }
  }
  for (id in body_seen) {
    if (!(id in index_seen)) emit("E-INDEX-MISMATCH", id " present in body but missing from index")
  }
  exit bad ? 1 : 0
}
' "$backlog"
