# Decides, for one index refresh, which files of the scan are unchanged and which must be indexed again
# (CC-690, issue #741). It replaces three loops in bash that put every file of the scan through an
# associative array (the stored rows, the current stat records, the current hashes): about half a
# millisecond a file each, which is most of a refresh that changes nothing. POSIX awk only (mawk, gawk and
# BSD awk all run it). Used through _ctx_index_plan in pmctl-context.sh, which writes the input files and
# reads the output; nothing else should call it.
#
# Every input is a file path read in BEGIN with getline, so an empty input is simply empty (no input-file
# counting to get wrong). Fields are separated by the unit separator \037, which cannot be in a path the scan
# produced. Paths reach this program through the ENVIRONMENT, never through -v: awk -v decodes backslash
# escapes in the value, so a root directory named with a literal backslash and a "t" would arrive with a tab
# in it, fail the prefix comparison below, and the refresh would report success while deleting every stored row.
#
#   phase=candidates  writes to $candfile the paths whose mtime matches the stored row and that have a
#                     stored hash (the only files that need hashing to decide "unchanged"), and to
#                     $verifyfile the paths that need a second look in bash: anything not plainly a regular
#                     file (a symbolic link, a path stat gave no record for, a type word it does not know).
#                     Prints one `P` line when it ran to the end.
#   phase=decide      appends one `INSERT OR IGNORE INTO _cur_paths` statement per file of the scan to
#                     $sqlfile (the reconciliation set), and prints one `R <scan line number> <mtime> <size>` line per
#                     file to index again, then one `S <found> <skipped> <stored_rows>` line.
#
# -v (plain values): phase, force (1: every file is indexed again), cap (longest path stored).
# Environment (paths): PMCTL_PLAN_ROOT (scan root), PMCTL_PLAN_KNOWN (stored rows: path, mtime, sha1),
# PMCTL_PLAN_STATS (current records: mtime, size, type, path), PMCTL_PLAN_SCAN (the scan's absolute paths, in
# order), for candidates PMCTL_PLAN_CANDS and PMCTL_PLAN_VERIFY, for decide PMCTL_PLAN_SHA1S (sha1sum output of
# the candidates), PMCTL_PLAN_DROPS (paths bash found not to be regular files after all), PMCTL_PLAN_SQL and
# PMCTL_PLAN_LONG (the relative paths too long to write here, one per line: bash writes their statements).
#
# A scan path that is not under the root cannot be turned into the relative path its row is stored under, and
# reconciliation would then delete that row: decide prints `E <count>` instead of the summary, and bash stops.

function relpath(abs) {
  if (index(abs, prefix) == 1) return substr(abs, length(prefix) + 1)
  outside++
  return abs
}

# What a path is, from the type stat printed (the producer pins LC_ALL=C, so the wording is English):
#   file     "regular file", "regular empty file" (GNU) or "Regular File" (BSD): a file, no check needed;
#   other    "directory", for example a submodule: not a file, left out of the scan;
#   unknown  anything else -- a symbolic link (judged by what it points to, which stat did not follow), a
#            device, a path stat gave no record for, or wording this program does not know (a stat that
#            ignored LC_ALL): passed back for a `[[ -f ]]` in bash. Never dropped on a guess: dropping a file
#            that is there would delete its row from the index.
function kind(abs,    t) {
  if (!(abs in ctype)) return "unknown"
  t = ctype[abs]
  if (t ~ /^regular/) return "file"
  if (t == "directory") return "other"
  return "unknown"
}

function unchanged_candidate(abs, rel) {
  return (!force && (rel in smtime) && cmtime[abs] != "" && smtime[rel] == cmtime[abs] && ssha[rel] != "")
}

# The name as sha1sum escapes it: a doubled backslash is one backslash, a backslash and an n is a newline.
function unescape(s,    out, i, c, d) {
  out = ""
  for (i = 1; i <= length(s); i++) {
    c = substr(s, i, 1)
    d = substr(s, i + 1, 1)
    if (c == "\\" && d == "\\") { out = out "\\"; i++ }
    else if (c == "\\" && d == "n") { out = out "\n"; i++ }
    else out = out c
  }
  return out
}

function sql_str(s) {
  gsub(/'/, "''", s)
  return s
}

BEGIN {
  FS = "\037"
  root = ENVIRON["PMCTL_PLAN_ROOT"]
  known = ENVIRON["PMCTL_PLAN_KNOWN"]
  stats = ENVIRON["PMCTL_PLAN_STATS"]
  scan = ENVIRON["PMCTL_PLAN_SCAN"]
  candfile = ENVIRON["PMCTL_PLAN_CANDS"]
  verifyfile = ENVIRON["PMCTL_PLAN_VERIFY"]
  sha1s = ENVIRON["PMCTL_PLAN_SHA1S"]
  drops = ENVIRON["PMCTL_PLAN_DROPS"]
  sqlfile = ENVIRON["PMCTL_PLAN_SQL"]
  longfile = ENVIRON["PMCTL_PLAN_LONG"]
  prefix = root "/"
  nstored = 0
  outside = 0

  while ((getline line < known) > 0) {
    # The first line of the file may be the extractor version bash asked for in the same query; it has no
    # separator in it, and a stored row always has two. It is not a stored row.
    if (index(line, "\037") == 0) continue
    gsub(/\r/, "", line)
    # path, mtime and sha1: the last two fields hold no separator, so everything before them is the path
    # (a path that holds the separator itself still comes out whole).
    n = split(line, f, "\037")
    path = f[1]
    for (i = 2; i <= n - 2; i++) path = path "\037" f[i]
    if (path == "") continue
    if (!(path in smtime)) nstored++
    smtime[path] = f[n - 1]
    ssha[path] = f[n]
  }
  close(known)

  while ((getline line < stats) > 0) {
    sub(/\r$/, "", line)
    n = split(line, f, "\037")
    path = f[4]
    for (i = 5; i <= n; i++) path = path "\037" f[i]
    if (path == "") continue
    cmtime[path] = f[1]
    csize[path] = f[2]
    ctype[path] = tolower(f[3])
  }
  close(stats)

  # The scan is numbered by its physical line, empty lines included: bash keeps the same list in an array and
  # takes a path back from it by this number (the decide phase hands out numbers, never paths).
  nscan = 0
  while ((getline line < scan) > 0) {
    scanned[++nscan] = line
  }
  close(scan)

  if (phase == "candidates") {
    printf "" > candfile
    printf "" > verifyfile
    for (i = 1; i <= nscan; i++) {
      abs = scanned[i]
      if (abs == "") continue
      k = kind(abs)
      if (k == "other") continue
      if (unchanged_candidate(abs, relpath(abs))) print abs >> candfile
      if (k != "file") print abs >> verifyfile
    }
    close(candfile)
    close(verifyfile)
    print "P"
    exit 0
  }

  while ((getline line < sha1s) > 0) {
    sub(/\r$/, "", line)
    if (line == "") continue
    if (substr(line, 1, 1) == "\\") {
      # GNU sha1sum marks a name it escaped (one with a backslash in it) with a leading backslash and
      # prints each backslash of the name doubled.
      hash[unescape(substr(line, 44))] = substr(line, 2, 40)
    } else {
      hash[substr(line, 43)] = substr(line, 1, 40)
    }
  }
  close(sha1s)

  while ((getline line < drops) > 0) {
    if (line != "") dropped[line] = 1
  }
  close(drops)

  printf "" > longfile
  found = 0
  skipped = 0
  for (i = 1; i <= nscan; i++) {
    abs = scanned[i]
    if (abs == "" || abs in dropped) continue
    if (kind(abs) == "other") continue
    found++
    rel = relpath(abs)
    # A path as long as the cap or longer is stored truncated, in the unit bash cuts in (characters), which
    # this awk may not share (mawk counts bytes): bash writes those statements itself, from PMCTL_PLAN_LONG,
    # with the same function that writes the file row, so the two keys cannot differ.
    if (length(rel) >= cap) {
      print rel >> longfile
    } else {
      print "INSERT OR IGNORE INTO _cur_paths(path) VALUES('" sql_str(rel) "');" >> sqlfile
    }
    if (unchanged_candidate(abs, rel) && (abs in hash) && hash[abs] == ssha[rel]) {
      skipped++
    } else {
      print "R\037" i "\037" cmtime[abs] "\037" csize[abs]
    }
  }
  close(sqlfile)
  close(longfile)
  if (outside > 0) {
    print "E\037" outside
    exit 0
  }
  print "S\037" found "\037" skipped "\037" nstored
  exit 0
}
