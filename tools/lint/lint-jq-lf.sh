#!/usr/bin/env bash
# lint-jq-lf.sh -- every executable shell entry that can call jq must load the
# CC-594 jq LF shim (runtime/lib/jq-lf.sh), so a native Windows jq does not write
# CRLF into its output.
#
# A bash function reaches only the shell that defines it, so each process that
# runs jq needs its own copy: the entry script sources jq-lf.sh, or carries the
# two-line standalone snippet quoted in jq-lf.sh's header (a hook may be copied by
# install.sh and cannot rely on a repo-relative source). This lint finds the
# entries (tracked files with mode 100755: *.sh and cli/pmctl) and checks:
#   - an entry whose static `source` closure calls jq (at a command position) must
#     load the shim itself: a `. .../jq-lf.sh` line, the snippet, or `th_init`
#     (tests/lib/test-harness.sh loads it);
#   - an entry (outside tests/) with a `source` whose target is not a literal
#     `name.sh` (a dynamic load, e.g. cli/pmctl's module loader) must load it too,
#     because its closure cannot be known statically;
#   - the snippet lines must be exactly the ones in jq-lf.sh's header; a near-copy
#     fails, so the copies cannot drift from the library;
#   - tools/lint/jq-lf-exemptions.tsv (path<TAB>reason) lists entries that
#     legitimately do not load it; a row whose file is gone or no longer needs it
#     fails, so the list does not rot.
# Libraries (mode 100644) are checked through the entries that source them.
#
# Usage: lint-jq-lf.sh [--repo-root <path>]
# Exit: 0 ok, 1 violations, 2 usage / environment error.
set -euo pipefail

usage() { printf 'usage: %s [--repo-root <path>]\n' "$(basename "$0")" >&2; }

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
if [[ $# -gt 0 ]]; then
  [[ $# -eq 2 && "$1" == "--repo-root" && -n "$2" ]] || { usage; exit 2; }
  repo_root="$(cd "$2" && pwd)"
fi

[[ -r "$repo_root/runtime/lib/jq-lf.sh" ]] || {
  printf 'lint-jq-lf: missing runtime/lib/jq-lf.sh under %s\n' "$repo_root" >&2
  exit 2
}

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
list="$work/list"
exemptions="$repo_root/tools/lint/jq-lf-exemptions.tsv"
[[ -r "$exemptions" ]] || exemptions="$work/no-exemptions"
: > "$work/no-exemptions"

# "<mode>\t<path>" for every tracked shell file.
git -C "$repo_root" ls-files -s -- '*.sh' cli/pmctl \
  | awk -F'\t' '{ split($1, a, " "); print a[1] "\t" $2 }' > "$list"

cat > "$work/lint.awk" <<'AWK'
function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }

# Read one file, filling calls[], loads[], s1[], s2[], bad[], srcs[], dyn[].
function scan(p,    f, line, t, rest, m, last, b, prev, prev2) {
  f = ROOT "/" p
  prev = ""; prev2 = ""
  while ((getline line < f) > 0) {
    t = trim(line)
    # `# jq-lf: dynamic-ok: <reason>` within the two lines before (or on the same
    # line as) a non-literal `source` says it is known not to reach jq for the
    # entries that use it; the reason is mandatory
    annotated = (prev ~ /jq-lf: dynamic-ok: [^ ]/ || prev2 ~ /jq-lf: dynamic-ok: [^ ]/ || t ~ /jq-lf: dynamic-ok: [^ ]/)
    prev2 = prev; prev = t
    if (t == c1) { s1[p] = 1 }
    else if (t == c2) { s2[p] = 1 }
    else if (p != "runtime/lib/jq-lf.sh" && (t ~ /^# CC-594: native Windows jq/ || (t ~ /^case "\$\{OSTYPE:-\}" in msys/ && t ~ /jq\(\)/))) {
      # a line that starts like one of the two snippet lines but is not the
      # canonical text: a drifted copy
      bad[p] = 1
    }
    if (t ~ /^#/ || t == "") continue
    if (t ~ /(^|[|;&({`!]|then|do|else|\$\()[ \t]*jq[ \t]+[-\047"$.[]/) calls[p] = 1
    if (t ~ /(^|[;&|{(]|then[ \t]|do[ \t]|else[ \t])[ \t]*(\.|source)[ \t]+.*jq-lf\.sh/) loads[p] = 1
    if (t ~ /(^|[ \t;&|(])th_init([ \t]|$)/ && t !~ /th_init[ \t]*\(\)/) loads[p] = 1
    # `source = $0` in an awk program is an assignment, not a source command
    if (match(t, /(^|[;&|{(]|then[ \t]|do[ \t]|else[ \t])[ \t]*(\.|source)[ \t]+[^ \t=]/)) {
      rest = substr(t, RSTART + RLENGTH - 1)
      if (rest ~ /jq-lf\.sh/) continue
      last = ""
      while (match(rest, /[A-Za-z0-9_.-]+\.sh/)) {
        last = substr(rest, RSTART, RLENGTH)
        rest = substr(rest, RSTART + RLENGTH)
      }
      if (last == "") { if (!annotated) dyn[p] = 1 }
      else srcs[p] = srcs[p] " " last
    }
  }
  close(f)
}

# Static closure of entry e over `source` edges (by file name; every tracked file
# of that name counts, which is the conservative reading).
function closure(e,    stack, sp, cur, n, bl, i, k, c, b) {
  delete seen
  hit = ""; hitdyn = ""
  sp = 0; stack[++sp] = e; seen[e] = 1
  while (sp > 0) {
    cur = stack[sp--]
    if (calls[cur] && hit == "") hit = cur
    if (dyn[cur] && hitdyn == "") hitdyn = cur
    n = split(srcs[cur], bl, " ")
    for (i = 1; i <= n; i++) {
      b = bl[i]
      for (k = 1; k <= nb[b]; k++) {
        c = bpath[b, k]
        if (!(c in seen)) { seen[c] = 1; stack[++sp] = c }
      }
    }
  }
}

BEGIN {
  while ((getline line < LIST) > 0) {
    split(line, a, "\t")
    np++; paths[np] = a[2]; mode[a[2]] = a[1]
    b = a[2]; sub(/.*\//, "", b)
    nb[b]++; bpath[b, nb[b]] = a[2]
  }
  close(LIST)
  while ((getline line < EXEMPT) > 0) {
    if (line ~ /^#/ || line == "") continue
    split(line, e, "\t")
    exempt[e[1]] = 1; exreason[e[1]] = e[2]
  }
  close(EXEMPT)
  while ((getline line < (ROOT "/runtime/lib/jq-lf.sh")) > 0) {
    if (line ~ /^#   # CC-594:/) c1 = substr(line, 5)
    if (line ~ /^#   case "\$\{OSTYPE:-\}" in msys/) c2 = substr(line, 5)
  }
  close(ROOT "/runtime/lib/jq-lf.sh")
  if (c1 == "" || c2 == "") { print "lint-jq-lf: cannot read the standalone snippet from runtime/lib/jq-lf.sh" > "/dev/stderr"; exit 2 }

  for (i = 1; i <= np; i++) scan(paths[i])

  fails = 0; checked = 0; callers = 0; loaders = 0
  for (i = 1; i <= np; i++) {
    p = paths[i]
    snippet = (s1[p] && s2[p])
    if (bad[p] || (s1[p] != s2[p])) {
      printf "lint-jq-lf: %s: the standalone snippet differs from the one in runtime/lib/jq-lf.sh (copy both lines exactly)\n", p > "/dev/stderr"
      fails++
      continue
    }
    if (snippet) loads[p] = 1
    if (mode[p] != "100755") continue
    checked++
    istest = (p ~ /^tests\//)
    closure(p)
    needs = (hit != "") || (hitdyn != "" && !istest)
    if (needs) callers++
    if (loads[p]) loaders++
    if (p in exempt) {
      used_exempt[p] = 1
      if (!needs || loads[p]) {
        printf "lint-jq-lf: %s: exempted in jq-lf-exemptions.tsv but it %s; remove the row\n", p, (loads[p] ? "loads the shim" : "does not need it") > "/dev/stderr"
        fails++
      }
      continue
    }
    if (needs && !loads[p]) {
      why = (hit != "") ? ("calls jq" (hit == p ? "" : " through " hit)) : ("has a dynamic source (" hitdyn ") whose closure is unknown")
      printf "lint-jq-lf: %s: %s but does not load the jq LF shim (source runtime/lib/jq-lf.sh or carry the standalone snippet from its header)\n", p, why > "/dev/stderr"
      fails++
    }
  }
  for (p in exempt) {
    if (!(p in mode)) {
      printf "lint-jq-lf: %s: listed in jq-lf-exemptions.tsv but not a tracked shell file; remove the row\n", p > "/dev/stderr"
      fails++
    }
  }
  if (fails > 0) exit 1
  printf "lint-jq-lf: OK (%d entry scripts checked, %d reach jq, %d load the shim, %d exempt)\n", checked, callers, loaders, length(used_exempt)
}
AWK

awk -v ROOT="$repo_root" -v LIST="$list" -v EXEMPT="$exemptions" -f "$work/lint.awk"
