# Decides, for one index refresh, which files of the scan are unchanged and which must be indexed again
# (CC-690, issue #741). It replaces three loops in bash that put every file of the scan through an
# associative array (the stored rows, the current stat records, the current hashes): about half a
# millisecond a file each, which is most of a refresh that changes nothing. POSIX awk only (mawk, gawk and
# BSD awk all run it). Used through _ctx_index_plan in pmctl-context.sh, which writes the input files and
# reads the output; nothing else should call it.
#
# Every input is a file path passed with -v, read in BEGIN with getline, so an empty input is simply empty
# (no input-file counting to get wrong). Fields are separated by the unit separator \037, which cannot be
# in a path the scan produced.
#
#   phase=candidates  prints  N, then N paths whose mtime matches the stored row and have a stored hash
#                     (the only files that need hashing to decide "unchanged"), then the paths that need
#                     a second look in bash: symbolic links and files stat gave no record for.
#   phase=decide      appends one `INSERT OR IGNORE INTO _cur_paths` statement per file of the scan to
#                     $sqlfile (the reconciliation set), and prints one `R <abs> <rel> <mtime> <size>` line
#                     per file to index again, then one `S <found> <skipped> <stored_rows>` line.
#
# Variables: root (scan root), force (1: every file is indexed again), cap (longest path stored),
# known (stored rows: path, mtime, sha1), stats (current records: mtime, size, type, path),
# scan (the scan's absolute paths, in order), and for decide: sha1s (sha1sum output of the candidates),
# drops (paths bash found not to be regular files after all), sqlfile.

function relpath(abs) {
  return (index(abs, prefix) == 1) ? substr(abs, length(prefix) + 1) : abs
}

# The scan only holds files: "regular file", "regular empty file" (GNU) or "Regular File" (BSD). A symbolic
# link is judged by what it points to, which stat did not follow, so it is passed back for a check in bash;
# a path without a record is too. Anything else (a directory such as a submodule, a fifo, ...) is not a file.
function kind(abs,    t) {
  if (!(abs in ctype)) return "unknown"
  t = ctype[abs]
  if (t ~ /^regular/) return "file"
  if (t ~ /symbolic/) return "link"
  return "other"
}

function unchanged_candidate(abs, rel) {
  return (!force && (rel in smtime) && cmtime[abs] != "" && smtime[rel] == cmtime[abs] && ssha[rel] != "")
}

function sql_str(s) {
  gsub(/'/, "''", s)
  return s
}

BEGIN {
  FS = "\037"
  prefix = root "/"
  nstored = 0

  while ((getline line < known) > 0) {
    gsub(/\r/, "", line)
    split(line, f, "\037")
    if (f[1] == "") continue
    if (!(f[1] in smtime)) nstored++
    smtime[f[1]] = f[2]
    ssha[f[1]] = f[3]
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

  nscan = 0
  while ((getline line < scan) > 0) {
    if (line == "") continue
    scanned[++nscan] = line
  }
  close(scan)

  if (phase == "candidates") {
    ncand = 0
    nlink = 0
    for (i = 1; i <= nscan; i++) {
      abs = scanned[i]
      k = kind(abs)
      if (k == "other") continue
      rel = relpath(abs)
      if (unchanged_candidate(abs, rel)) cand[++ncand] = abs
      if (k != "file") links[++nlink] = abs
    }
    print ncand
    for (i = 1; i <= ncand; i++) print cand[i]
    for (i = 1; i <= nlink; i++) print links[i]
    exit 0
  }

  while ((getline line < sha1s) > 0) {
    sub(/\r$/, "", line)
    if (line == "") continue
    hash[substr(line, 43)] = substr(line, 1, 40)
  }
  close(sha1s)

  while ((getline line < drops) > 0) {
    if (line != "") dropped[line] = 1
  }
  close(drops)

  found = 0
  skipped = 0
  for (i = 1; i <= nscan; i++) {
    abs = scanned[i]
    if (abs in dropped) continue
    if (kind(abs) == "other") continue
    found++
    rel = relpath(abs)
    print "INSERT OR IGNORE INTO _cur_paths(path) VALUES('" sql_str(substr(rel, 1, cap)) "');" >> sqlfile
    if (unchanged_candidate(abs, rel) && (abs in hash) && hash[abs] == ssha[rel]) {
      skipped++
    } else {
      print "R\037" abs "\037" rel "\037" cmtime[abs] "\037" csize[abs]
    }
  }
  close(sqlfile)
  print "S\037" found "\037" skipped "\037" nstored
  exit 0
}
