#!/usr/bin/env bash
# pmctl-context.sh — builtin repo-index commands: index / update / query.
# Sources state-writer.sh for path resolution (_sw_store_root / _sw_project_key) only.
# Does NOT call serialize_with_lock; index DB is a derived cache — SQLite WAL provides concurrency guarantees.
# MUST NOT source pmctl-dispatch.sh or any adapter module.

_CTX_LIB_DIR="${BASH_SOURCE[0]%/*}"
[[ "$_CTX_LIB_DIR" == "${BASH_SOURCE[0]}" ]] && _CTX_LIB_DIR=.

# Source state-writer.sh (which pulls in portable.sh) for path helpers.
if ! declare -F _sw_store_root >/dev/null 2>&1; then
  # shellcheck source=runtime/lib/state-writer.sh
  # shellcheck disable=SC1091
  . "$_CTX_LIB_DIR/state-writer.sh" 2>/dev/null || true
fi

# Source memory.sh (leaf helper: find_memory_dir / encode_path, no side effects)
# for the memory retrieval plane (--source memory). It is a pure path resolver,
# not an adapter module, so the "MUST NOT source adapters" rule does not apply.
if ! declare -F find_memory_dir >/dev/null 2>&1; then
  # shellcheck source=runtime/lib/memory.sh
  # shellcheck disable=SC1091
  . "$_CTX_LIB_DIR/memory.sh" 2>/dev/null || true
fi

# Source pmctl-config.sh explicitly (not pmctl-dispatch.sh or an adapter module,
# so the "MUST NOT source adapters" rule does not apply) so project-scoped memory
# resolution does not depend on cli/pmctl's lib-load ordering happening to have
# already sourced it via pmctl-dispatch.sh.
if ! declare -F pm_config_load >/dev/null 2>&1; then
  # shellcheck source=runtime/lib/pmctl-config.sh
  # shellcheck disable=SC1091
  . "$_CTX_LIB_DIR/pmctl-config.sh" 2>/dev/null || true
fi

# Shared ASCII + CJK term extraction (CC-465). Sourced as a leaf helper so
# prompt-scan / reuse-scan and the memory inject hook cannot drift.
if ! declare -F retrieval_extract_terms >/dev/null 2>&1; then
  # shellcheck source=runtime/lib/retrieval-terms.sh
  # shellcheck disable=SC1091
  . "$_CTX_LIB_DIR/retrieval-terms.sh"
fi

# ── Path resolution ────────────────────────────────────────────────────────────

_ctx_db_path() {
  local repo_root="$1"
  printf '%s/.pm-dispatch/ctx/context.db\n' "$repo_root"
}

# Default repo_root for context-family subcommands invoked without an explicit
# path argument: the git toplevel of the CALLER'S CWD, not cli/pmctl's own
# REPO_ROOT (which resolves to the pmctl install repo, not the target repo).
# Falls back to REPO_ROOT with a one-line stderr warning only when the CWD is
# not inside any git worktree. Echoes nothing (returns 1) when neither is
# available.
_ctx_default_repo_root() {
  local toplevel
  toplevel="$(git rev-parse --show-toplevel 2>/dev/null)"
  if [[ -n "$toplevel" ]]; then
    printf '%s\n' "$toplevel"
    return 0
  fi
  if [[ -n "${REPO_ROOT:-}" ]]; then
    printf 'pmctl context: CWD is not inside a git worktree; falling back to REPO_ROOT (%s)\n' \
      "$REPO_ROOT" >&2
    printf '%s\n' "$REPO_ROOT"
    return 0
  fi
  return 1
}

# Memory-plane DB path. PRIVACY (load-bearing): the memory index lives UNDER the
# memory directory (out-of-repo `~/.claude/projects/<id>/memory/`), never under
# the repo checkout — even gitignored, a repo-local copy of private memory could
# be carried out by tooling or an archive. The derived `.pm-dispatch/context.db`
# sits beside the source cards it was built from.
_ctx_memory_db_path() {
  local memory_dir="$1"
  printf '%s/.pm-dispatch/context.db\n' "$memory_dir"
}

# Resolve the project-memory directory for a given working dir, reusing the
# shared find_memory_dir walker. Echoes the dir on success; returns 1 (no output)
# when memory.sh is unavailable or no memory dir exists up the tree.
_ctx_resolve_memory_dir() {
  local cwd="$1"
  local project_key=""
  declare -F find_memory_dir >/dev/null 2>&1 || return 1
  declare -F pm_config_project_key >/dev/null 2>&1 && project_key="$(pm_config_project_key "$cwd" 2>/dev/null || true)"
  declare -F pm_config_load >/dev/null 2>&1 && pm_config_load "$project_key"
  # Never let direct context commands turn an invalid explicit selector into a
  # write beside another repository's legacy memory. Host entrypoints already
  # use the strict resolver; this closes the standalone context path as well.
  _pm_memory_explicit_selection_invalid && return 3
  find_memory_dir "$cwd" 2>/dev/null
}

# Memory trust tier: curated cards (and the MEMORY.md index) outrank raw
# episodes. Path-based so it works uniformly across symbol/fts/like hits.
_ctx_memory_trust() {
  case "$1" in
    *episodes*.jsonl) printf 'medium' ;;
    *)                printf 'high' ;;
  esac
}

# VCS hygiene side effect: called during indexing to keep the derived cache
# out of version control. Testable independently via the case_context_index_gitignore_* suite.
_ctx_ensure_gitignore() {
  local repo_root="$1"
  local gitignore="$repo_root/.gitignore"
  # Path safety: only ever read/write a real, single-linked regular file. A symlink
  # or special file is not ours to follow, and a hardlinked file (link count > 1)
  # shares its inode with another path — appending through any of these could
  # clobber or write into an out-of-tree / shared target. Skip with a warning; the
  # DB still works (just untracked).
  if [[ -L "$gitignore" || ( -e "$gitignore" && ! -f "$gitignore" ) ]]; then
    printf 'context index: .gitignore is not a regular file; skipping auto-patch\n' >&2
    return 0
  fi
  if [[ -f "$gitignore" ]]; then
    local nlink
    nlink="$(stat -c '%h' "$gitignore" 2>/dev/null || stat -f '%l' "$gitignore" 2>/dev/null || printf '1')"
    if [[ "$nlink" =~ ^[0-9]+$ && "$nlink" -gt 1 ]]; then
      printf 'context index: .gitignore is hardlinked (shared inode); skipping auto-patch\n' >&2
      return 0
    fi
  fi
  if [[ ! -e "$gitignore" ]]; then
    printf '.pm-dispatch\n' > "$gitignore"
    printf 'context index: created .gitignore with .pm-dispatch\n' >&2
    return 0
  fi
  grep -qxF '.pm-dispatch'  "$gitignore" 2>/dev/null && return 0
  grep -qxF '.pm-dispatch/' "$gitignore" 2>/dev/null && return 0
  printf '\n.pm-dispatch\n' >> "$gitignore"
  printf 'context index: added .pm-dispatch to .gitignore\n' >&2
}

# ── SQLite availability ────────────────────────────────────────────────────────

_ctx_sqlite3_check() {
  command -v sqlite3 >/dev/null 2>&1
}

# Probe FTS5 support by creating and immediately dropping a test virtual table.
# Returns 0 if FTS5 is available, 1 otherwise.
#
# Cached per db path: FTS5 support is a property of the sqlite3 binary, static
# for the lifetime of this process, but this call sits on the query hot path
# (called on every `pmctl context query`) — forking 2 sqlite3 subprocesses per
# call was pure repeated cost for an answer that never changes. Keyed by $db
# (not a single global) so nothing changes if a caller ever queries multiple
# db paths in one process.
declare -gA _CTX_FTS5_CACHE 2>/dev/null || true

_ctx_fts5_available() {
  local db="$1"
  if [[ -n "${_CTX_FTS5_CACHE[$db]+set}" ]]; then
    [[ "${_CTX_FTS5_CACHE[$db]}" == "0" ]]
    return
  fi
  local result=1
  if sqlite3 "$db" "CREATE VIRTUAL TABLE IF NOT EXISTS _fts5_probe USING fts5(x);" 2>/dev/null; then
    sqlite3 "$db" "DROP TABLE IF EXISTS _fts5_probe;" 2>/dev/null || true
    result=0
  fi
  _CTX_FTS5_CACHE[$db]="$result"
  [[ "$result" == "0" ]]
}

# ── Database schema ────────────────────────────────────────────────────────────

_ctx_db_init() {
  local db="$1"
  # Redirect stdout: `PRAGMA journal_mode=WAL` echoes the resulting mode ("wal")
  # which would otherwise leak into `pmctl context index` output.
  sqlite3 "$db" >/dev/null <<'SQLINIT'
PRAGMA busy_timeout=5000;
PRAGMA journal_mode=WAL;
CREATE TABLE IF NOT EXISTS files (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  path TEXT NOT NULL UNIQUE,
  language TEXT,
  size_bytes INTEGER,
  mtime INTEGER,
  sha1 TEXT,
  indexed_at INTEGER
);
CREATE TABLE IF NOT EXISTS symbols (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  file_id INTEGER NOT NULL REFERENCES files(id),
  name TEXT NOT NULL,
  kind TEXT NOT NULL,
  language TEXT,
  line_start INTEGER,
  line_end INTEGER,
  signature TEXT,
  backend TEXT DEFAULT 'regex',
  confidence REAL DEFAULT 0.8
);
CREATE TABLE IF NOT EXISTS file_chunks (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  file_id INTEGER NOT NULL REFERENCES files(id),
  heading TEXT,
  line_start INTEGER,
  line_end INTEGER,
  text TEXT,
  sha1 TEXT
);
CREATE TABLE IF NOT EXISTS index_meta (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  schema_version INTEGER NOT NULL,
  extractor_version INTEGER NOT NULL,
  built_at INTEGER
);
CREATE INDEX IF NOT EXISTS idx_symbols_name ON symbols(name);
CREATE INDEX IF NOT EXISTS idx_files_path ON files(path);
SQLINIT
}

# ── Language detection ─────────────────────────────────────────────────────────

_ctx_detect_language() {
  local path="$1"
  local ext="${path##*.}"
  case "$ext" in
    sh|bash)   printf 'shell' ;;
    go)        printf 'go' ;;
    py)        printf 'python' ;;
    ts|tsx)    printf 'typescript' ;;
    js|jsx)    printf 'javascript' ;;
    md)        printf 'markdown' ;;
    json)      printf 'json' ;;
    yaml|yml)  printf 'yaml' ;;
    *)         printf 'text' ;;
  esac
}

# ── Symbol extraction (isolated helper — highest-volatility seam) ──────────────
#
# Outputs TSV lines: name<TAB>kind<TAB>line_start<TAB>signature
# Pure grep/sed; no SQL calls, no side effects, no globals written.
# Called by _ctx_index_file only.

_ctx_extract_symbols() {
  local file="$1" lang="$2"
  [[ -f "$file" ]] || return 0

  case "$lang" in
    shell)
      # ^[[:alpha:]_][[:alnum:]_]*()\s*\{  → kind=function
      grep -n '^[[:alpha:]_][[:alnum:]_]*()\s*{' "$file" 2>/dev/null \
        | sed 's/^\([0-9]*\):\([[:alpha:]_][[:alnum:]_]*\)().*/\2\tfunction\t\1\t\2()/' \
        || true
      ;;
    go)
      # ^func\s → function, ^type\s → type
      grep -n '^\(func\|type\) ' "$file" 2>/dev/null | while IFS=: read -r lineno rest; do
        case "$rest" in
          func\ *)
            name="$(printf '%s' "$rest" \
              | sed 's/^func[[:space:]]*([^)]*)[[:space:]]*\([[:alnum:]_]*\).*/\1/; t done
                     s/^func[[:space:]]*\([[:alnum:]_]*\).*/\1/; :done')"
            [[ -n "$name" && "$name" != "$rest" ]] && printf '%s\tfunction\t%s\t%s\n' "$name" "$lineno" "$rest"
            ;;
          type\ *)
            name="$(printf '%s' "$rest" | sed 's/^type[[:space:]]*\([[:alnum:]_]*\).*/\1/')"
            [[ -n "$name" && "$name" != "$rest" ]] && printf '%s\ttype\t%s\t%s\n' "$name" "$lineno" "$rest"
            ;;
        esac
      done
      ;;
    python)
      # ^def\s → function, ^class\s → class
      grep -n '^\(def\|class\) ' "$file" 2>/dev/null | while IFS=: read -r lineno rest; do
        case "$rest" in
          def\ *)
            name="$(printf '%s' "$rest" | sed 's/^def[[:space:]]*\([[:alnum:]_]*\).*/\1/')"
            [[ -n "$name" && "$name" != "$rest" ]] && printf '%s\tfunction\t%s\t%s\n' "$name" "$lineno" "$rest"
            ;;
          class\ *)
            name="$(printf '%s' "$rest" | sed 's/^class[[:space:]]*\([[:alnum:]_]*\).*/\1/')"
            [[ -n "$name" && "$name" != "$rest" ]] && printf '%s\tclass\t%s\t%s\n' "$name" "$lineno" "$rest"
            ;;
        esac
      done
      ;;
    typescript|javascript)
      # ^function\s → function, ^class\s → class, ^const\s.*=> → arrow
      grep -n '^\(function\|class\|const\) ' "$file" 2>/dev/null | while IFS=: read -r lineno rest; do
        case "$rest" in
          function\ *)
            name="$(printf '%s' "$rest" | sed 's/^function[[:space:]]*\([[:alnum:]_]*\).*/\1/')"
            [[ -n "$name" && "$name" != "$rest" ]] && printf '%s\tfunction\t%s\t%s\n' "$name" "$lineno" "$rest"
            ;;
          class\ *)
            name="$(printf '%s' "$rest" | sed 's/^class[[:space:]]*\([[:alnum:]_]*\).*/\1/')"
            [[ -n "$name" && "$name" != "$rest" ]] && printf '%s\tclass\t%s\t%s\n' "$name" "$lineno" "$rest"
            ;;
          const\ *)
            if printf '%s' "$rest" | grep -q '=>'; then
              name="$(printf '%s' "$rest" | sed 's/^const[[:space:]]*\([[:alnum:]_]*\).*/\1/')"
              [[ -n "$name" && "$name" != "$rest" ]] && printf '%s\tarrow\t%s\t%s\n' "$name" "$lineno" "$rest"
            fi
            ;;
        esac
      done
      ;;
  esac
  # markdown/yaml/json/text: no symbol extraction — headings are document
  # structure, not reusable code symbols. These file types contribute to
  # file_chunks (FTS/LIKE text search) only.
}

# ── File metadata helpers ──────────────────────────────────────────────────────

_ctx_file_mtime() {
  local f="$1"
  stat -c '%Y' "$f" 2>/dev/null && return
  stat -f '%m' "$f" 2>/dev/null && return
  printf '0'
}

_ctx_file_sha1() {
  local f="$1"
  _portable_sha1 < "$f" 2>/dev/null || printf 'unknown'
}

_ctx_now_epoch() {
  date +%s 2>/dev/null || printf '0'
}

# ── SQL escaping ───────────────────────────────────────────────────────────────

# Escape a value for use in SQL single-quoted string literals (doubles single-quotes).
# The bound keeps SQL statements manageable and is taken from the chunk body cap
# so it can never silently truncate a body the chunker considered whole: two
# independent literals that must agree are one edit away from disagreeing.
_ctx_sql_str() {
  local __ctx_sql_out
  _ctx_sql_str_var __ctx_sql_out "$1"
  printf '%s' "$__ctx_sql_out"
}

# Same escaping, assigned into a caller-named variable instead of returned on
# stdout. Command substitution forks a subshell for every call, which the
# per-symbol and per-chunk paths pay thousands of times on a full index -- the
# same per-item subprocess shape that dominated gate scope expansion. Callers on
# those paths use this form; the stdout form above stays for one-off uses.
_ctx_sql_str_var() {
  local __ctx_sql_dest="$1"
  local __ctx_sql_val="${2:0:${_CTX_CHUNK_BODY_CAP:-2000}}"
  printf -v "$__ctx_sql_dest" '%s' "${__ctx_sql_val//\'/\'\'}"
}

# ── context_hit_v1 YAML emitter ───────────────────────────────────────────────
#
# Single entry point for emitting context_hit_v1 YAML blocks.
# Sanitizes why_relevant to produce valid YAML single-quoted scalars:
# strips newlines/CRs, escapes single quotes by doubling.

_ctx_emit_hit() {
  local ref="$1" source_domain="$2" why_relevant="$3" confidence="$4" trust_level="$5"
  local rank="${6:-}" match_kind="${7:-}" line_end="${8:-}" ranking_score="${9:-}" score_components="${10:-}"
  local safe_why="${why_relevant//$'\n'/ }"
  safe_why="${safe_why//$'\r'/ }"
  safe_why="${safe_why//\'/\'\'}"
  # Source attribution tracks the plane: memory hits are `memory-index`
  # (per CC-403), repo hits stay `builtin-index`. Keeps source ⟺ source_domain
  # consistent and matches the pack's sources[] registry.
  local src="builtin-index"
  [[ "$source_domain" == "memory" ]] && src="memory-index"
  printf -- '- ref: %s\n'         "$ref"
  printf    '  source: %s\n'         "$src"
  printf    '  source_domain: %s\n'  "$source_domain"
  printf    "  why_relevant: '%s'\n" "$safe_why"
  printf    '  confidence: %s\n'     "$confidence"
  printf    '  trust_level: %s\n'    "$trust_level"
  # CC-505 Req 2-4: ranking_score/match_kind are additive fields distinct
  # from `confidence` above -- lexical relevance, not correctness confidence.
  # Optional: a caller that has not gone through _ctx_rank_hits (none should)
  # simply omits them.
  if [[ -n "$rank" ]]; then
    # line_start is derived from ref (path:line_start), same as
    # _ctx_tsv_to_json_array's pack projection -- gate finding
    # architecture-reviewer-F001: query's YAML previously emitted line_end
    # alone, forcing a caller to parse ref itself to recover the other half
    # of the same bounded-span contract the schema and pack both expose.
    local line_start="${ref##*:}"
    [[ "$line_start" =~ ^[0-9]+$ ]] || line_start=""
    printf '  rank: %s\n'             "$rank"
    printf '  match_kind: %s\n'       "$match_kind"
    printf '  line_start: %s\n'       "${line_start:-null}"
    printf '  line_end: %s\n'         "$line_end"
    printf '  ranking_score: %s\n'    "$ranking_score"
    printf "  score_components: '%s'\n" "$score_components"
  fi
}

# ── Domain classification (path-based, no DB column) ─────────────────────────

_ctx_classify_domain() {
  local rel_path="$1"
  case "$rel_path" in
    BACKLOG.md|DECISIONS.md|MILESTONES.md|docs/*)
      printf 'knowledge'
      ;;
    *)
      printf 'repo'
      ;;
  esac
}

# ── Per-format file chunkers ─────────────────────────────────────────────────
#
# Each outputs TSV rows: heading<TAB>line_start<TAB>line_end<TAB>body
#
# body is the chunk's own content, bounded by _CTX_CHUNK_BODY_CAP. Content that
# would exceed the cap continues in the next chunk rather than being dropped, so
# a long section stays searchable to its end.
#
# The cap and the window size are chosen together from measured body lengths in
# this repository, so that the cap guards outliers instead of truncating
# routinely: at a 20-line window the 95th-percentile body is ~1.2K against a 2K
# cap (99.3% of content retained), while a 40-line window puts the 95th
# percentile above the cap and loses content on more than one window in twenty.
# Deliberately plain constants, not env-overridable, for the reason lib/memory.sh
# states about its own budgets: an ambient override leaks into fixtures. Here it
# also matters for safety -- the extractor version is written into SQL, and an
# environment-supplied value would be attacker-controlled SQL text.
_CTX_CHUNK_BODY_CAP=2000

# Bumping this forces every indexed file to be re-extracted: a chunker change
# alters what "already indexed" means, and without it existing databases keep
# serving chunks the current extractor would never produce -- a stale index that
# looks healthy. Bump on any change to the chunkers or to the cap/window above.
# Also covers the content_fts DDL itself (CC-505 gate findings critic-F001 /
# risk-reviewer-F001): _ctx_index_tree's _force_reextract check (below) is
# what makes _ctx_fts_rebuild run unconditionally on a version mismatch, so
# adding line_end to content_fts's schema is exactly the class of change this
# constant exists to force-migrate -- an index built before this change would
# otherwise keep its old 2-column content_fts table forever (no query ever
# rebuilds it on its own), and the new SELECT ... line_end FROM content_fts
# would fail against it with "no such column".
_CTX_EXTRACTOR_VERSION=3

# Emit one chunk row, splitting a body longer than the cap across rows instead
# of letting it overflow. An over-cap body reaches _ctx_sql_str, which truncates
# to the same bound and drops the excess without a word -- so a single physical
# line longer than the cap (a minified bundle, a generated data file) would lose
# its tail from the index while everything reported success. Split rows repeat
# the line span they came from, which is truthful: the content really is there.
_ctx_chunk_emit() {
  local heading="$1" start="$2" end="$3" body="$4"
  while [[ "${#body}" -gt "$_CTX_CHUNK_BODY_CAP" ]]; do
    printf '%s\t%s\t%s\t%s\n' "$heading" "$start" "$end" "${body:0:$_CTX_CHUNK_BODY_CAP}"
    body="${body:$_CTX_CHUNK_BODY_CAP}"
  done
  [[ -n "$body" ]] && printf '%s\t%s\t%s\t%s\n' "$heading" "$start" "$end" "$body"
  return 0
}

_ctx_chunk_markdown() {
  local abs_path="$1"
  local line lineno=1 in_fence=0 saw_heading=0
  local cur_heading="" cur_start=0 cur_body=""

  # Emit the accumulated chunk and start a continuation at the given line.
  _ctx_chunk_md_flush() {
    _ctx_chunk_emit "$cur_heading" "$cur_start" "$1" "$cur_body"
    cur_body=""
    cur_start=$(( $1 + 1 ))
  }

  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" =~ ^\`\`\` ]]; then
      in_fence=$((1 - in_fence))
    fi

    if [[ "$in_fence" -eq 0 && "$line" =~ ^(#{1,6})[[:space:]](.+) ]]; then
      [[ "$cur_start" -gt 0 ]] && _ctx_chunk_md_flush "$((lineno - 1))"
      saw_heading=1
      cur_heading="${BASH_REMATCH[2]}"
      cur_start="$lineno"
      cur_body=""
    elif [[ "$cur_start" -gt 0 && -n "$line" ]]; then
      cur_body="${cur_body:+$cur_body }$line"
      # A section longer than the cap is split, not truncated: the remainder
      # continues under the same heading so its tail stays searchable.
      if [[ "${#cur_body}" -ge "$_CTX_CHUNK_BODY_CAP" ]]; then
        _ctx_chunk_md_flush "$lineno"
      fi
    fi

    lineno=$((lineno + 1))
  done < "$abs_path"

  [[ "$cur_start" -gt 0 && -n "$cur_body" ]] && _ctx_chunk_md_flush "$((lineno - 1))"
  unset -f _ctx_chunk_md_flush

  if [[ "$saw_heading" -eq 0 ]]; then
    _ctx_chunk_window "$abs_path"
  fi
}

_ctx_chunk_window() {
  local abs_path="$1" window_size="${2:-20}"
  local total line lineno=1 win_start=1 win_body=""

  total="$(wc -l < "$abs_path" 2>/dev/null | tr -d ' ' || printf '0')"
  [[ "$total" -eq 0 ]] && return 0

  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -n "$line" ]] && win_body="${win_body:+$win_body }$line"

    if [[ $((lineno - win_start + 1)) -ge "$window_size" \
       || "${#win_body}" -ge "$_CTX_CHUNK_BODY_CAP" || "$lineno" -ge "$total" ]]; then
      _ctx_chunk_emit "" "$win_start" "$lineno" "$win_body"
      win_start=$((lineno + 1))
      win_body=""
    fi
    lineno=$((lineno + 1))
  done < "$abs_path"

  [[ -n "$win_body" ]] && \
    _ctx_chunk_emit "" "$win_start" "$((lineno - 1))" "$win_body"
  return 0
}

_ctx_chunk_file() {
  local abs_path="$1" lang="$2"
  case "$lang" in
    markdown)
      _ctx_chunk_markdown "$abs_path"
      ;;
    *)
      # Every other language, shell included, was one chunk holding the first
      # 200 characters of the file -- so a function body below the header was
      # not in the index at all. Windowing them is the point of the change.
      _ctx_chunk_window "$abs_path"
      ;;
  esac
}

# ── SQL generation for one file (no BEGIN/COMMIT, no sqlite3 call) ────────────
#
# Outputs the SQL statements for one file to stdout.
# Caller is responsible for wrapping in BEGIN/COMMIT and executing via sqlite3.

_ctx_generate_file_sql() {
  local abs_path="$1" rel_path="$2"
  local lang mtime sha1 size_bytes indexed_at ep

  lang="$(_ctx_detect_language "$rel_path")"
  mtime="$(_ctx_file_mtime "$abs_path")"
  sha1="$(_ctx_file_sha1 "$abs_path")"
  size_bytes="$(wc -c < "$abs_path" 2>/dev/null | tr -d ' ' || printf '0')"
  indexed_at="$(_ctx_now_epoch)"
  ep="$(_ctx_sql_str "$rel_path")"

  printf "INSERT INTO files(path,language,size_bytes,mtime,sha1,indexed_at)\n"
  printf "  VALUES('%s','%s',%s,%s,'%s',%s)\n" \
    "$ep" "$lang" "$size_bytes" "$mtime" "$sha1" "$indexed_at"
  printf "  ON CONFLICT(path) DO UPDATE SET\n"
  printf "    language=excluded.language,size_bytes=excluded.size_bytes,\n"
  printf "    mtime=excluded.mtime,sha1=excluded.sha1,indexed_at=excluded.indexed_at;\n"

  printf "DELETE FROM symbols     WHERE file_id=(SELECT id FROM files WHERE path='%s');\n" "$ep"
  printf "DELETE FROM file_chunks WHERE file_id=(SELECT id FROM files WHERE path='%s');\n" "$ep"

  local sym_name sym_kind sym_line sym_sig en ek esig
  while IFS=$'\t' read -r sym_name sym_kind sym_line sym_sig; do
    [[ -n "$sym_name" ]] || continue
    _ctx_sql_str_var en "$sym_name"
    _ctx_sql_str_var ek "$sym_kind"
    _ctx_sql_str_var esig "${sym_sig:-}"
    printf "INSERT INTO symbols(file_id,name,kind,language,line_start,line_end,signature,backend,confidence)\n"
    printf "  VALUES((SELECT id FROM files WHERE path='%s'),'%s','%s','%s',%s,%s,'%s','regex',0.8);\n" \
      "$ep" "$en" "$ek" "$lang" "$sym_line" "$sym_line" "$esig"
  done < <(_ctx_extract_symbols "$abs_path" "$lang")

  local chunk_row tab=$'\t'
  local ch_heading ch_start ch_end ch_lead rest eh el
  while IFS= read -r chunk_row; do
    ch_heading="${chunk_row%%"$tab"*}"
    rest="${chunk_row#*"$tab"}"
    ch_start="${rest%%"$tab"*}"
    rest="${rest#*"$tab"}"
    ch_end="${rest%%"$tab"*}"
    ch_lead="${rest#*"$tab"}"
    _ctx_sql_str_var eh "$ch_heading"
    _ctx_sql_str_var el "$ch_lead"
    # No chunk-level digest is computed: nothing in the repository reads
    # file_chunks.sha1, and change detection is decided by files.sha1 above.
    # Computing it cost one hashing subprocess per chunk -- measurably a
    # quarter of index time -- to fill a column with no consumer.
    printf "INSERT INTO file_chunks(file_id,heading,line_start,line_end,text)\n"
    printf "  VALUES((SELECT id FROM files WHERE path='%s'),'%s',%s,%s,'%s');\n" \
      "$ep" "$eh" "$ch_start" "$ch_end" "$el"
  done < <(_ctx_chunk_file "$abs_path" "$lang")
}

# ── Single-file index (used by pmctl_context_update) ──────────────────────────

_ctx_index_file() {
  local db="$1" abs_path="$2" rel_path="$3"
  local tmpf
  tmpf="$(mktemp /tmp/ctx-XXXXXX.sql)"
  {
    printf 'PRAGMA busy_timeout=5000;\n'
    printf 'BEGIN;\n'
    _ctx_generate_file_sql "$abs_path" "$rel_path"
    printf 'COMMIT;\n'
  } > "$tmpf"
  sqlite3 "$db" < "$tmpf" >/dev/null
  rm -f "$tmpf"
}

# ── FTS5 index rebuild ─────────────────────────────────────────────────────────

_ctx_fts_rebuild() {
  local db="$1"
  _ctx_fts5_available "$db" || return 0

  # line_end is UNINDEXED (not searched, just carried) so a query can report
  # each hit's real bounded span instead of faking line_end=line_start (the
  # pack/query contract advertises line_start/line_end as the actual chunk or
  # symbol extent -- CC-505 Req 3 gate finding critic-F001).
  sqlite3 "$db" >/dev/null <<'SQLFTS'
PRAGMA busy_timeout=5000;
DROP TABLE IF EXISTS content_fts;
CREATE VIRTUAL TABLE content_fts USING fts5(ref, text, line_end UNINDEXED);
INSERT INTO content_fts(ref, text, line_end)
  SELECT f.path || ':' || s.line_start, s.name, s.line_end
  FROM symbols s JOIN files f ON s.file_id = f.id;
INSERT INTO content_fts(ref, text, line_end)
  SELECT f.path || ':' || fc.line_start, TRIM(COALESCE(fc.heading, '') || ' ' || COALESCE(fc.text, '')), fc.line_end
  FROM file_chunks fc JOIN files f ON fc.file_id = f.id
  WHERE TRIM(COALESCE(fc.heading, '') || ' ' || COALESCE(fc.text, '')) != '';
SQLFTS
}

# ── Index file discovery (per-plane find expression) ──────────────────────────
# repo plane: code + knowledge docs (the established glob). memory plane: cards
# + MEMORY.md + episodes, excluding the derived .pm-dispatch cache dir itself.

_ctx_find_index_files() {
  local root="$1" mode="$2"
  case "$mode" in
    memory)
      find "$root" \
        -not -path '*/.pm-dispatch/*' \
        -type f \( -name '*.md' -o -name '*.jsonl' \) 2>/dev/null | sort
      ;;
    *)
      find "$root" \
        -not -path '*/.git/*' \
        -not -path '*/.pm-dispatch/*' \
        -not -path '*/node_modules/*' \
        -not -path '*/vendor/*' \
        -not -path '*/.cache/*' \
        -type f \( \
          -name '*.sh'   -o -name '*.bash' -o \
          -name '*.go'   -o \
          -name '*.py'   -o \
          -name '*.ts'   -o -name '*.tsx'  -o \
          -name '*.js'   -o -name '*.jsx'  -o \
          -name '*.md'   -o \
          -name '*.yaml' -o -name '*.yml'  -o \
          -name '*.json' -o \
          -name '*.txt' \
        \) 2>/dev/null | sort
      ;;
  esac
}

# ── Shared index core (plane-agnostic) ────────────────────────────────────────
# Indexes a tree ($root) into $db. Used by both the repo plane (pmctl_context_index)
# and the memory plane (--source memory / _ctx_ensure_fresh_memory). Assumes the
# caller has already confirmed sqlite3 is available.
#   do_gitignore=1 → patch <root>/.gitignore (repo plane only; memory must never
#   touch its source tree's VCS hygiene). mode selects the find expression.

_ctx_index_tree() {
  local root="$1" db="$2" do_gitignore="$3" mode="$4"

  local db_dir
  db_dir="$(dirname "$db")"
  if ! mkdir -p "$db_dir" 2>/dev/null; then
    printf 'pmctl context index: cannot create %s\n' "$db_dir" >&2
    return 1
  fi
  # Run every index, not just first cache-dir creation: _ctx_ensure_gitignore is
  # idempotent (it no-ops when the entry already exists), so a repo with a
  # pre-existing .pm-dispatch/ctx but no .gitignore entry still gets patched.
  [[ "$do_gitignore" == "1" ]] && _ctx_ensure_gitignore "$root"
  _ctx_db_init "$db"

  # A database built by a different extractor holds chunks the current one would
  # never produce. Re-extract everything rather than serving them: an index that
  # silently disagrees with its extractor still answers queries, so the failure
  # would look exactly like success.
  local _db_extractor
  _db_extractor="$(sqlite3 "$db" "SELECT extractor_version FROM index_meta WHERE id=1;" 2>/dev/null | tr -d '\r' || true)"
  local _force_reextract=0
  [[ "$_db_extractor" != "$_CTX_EXTRACTOR_VERSION" ]] && _force_reextract=1

  # Batch-load all known mtimes and sha1s in one query to avoid one sqlite3
  # subprocess per file.
  declare -A _ctx_db_mtimes=() _ctx_db_sha1s=()
  local _p _m _s
  while IFS='|' read -r _p _m _s; do
    [[ -n "$_p" ]] || continue
    _ctx_db_mtimes["$_p"]="$_m"
    _ctx_db_sha1s["$_p"]="$_s"
  done < <(sqlite3 "$db" "SELECT path, mtime, COALESCE(sha1,'') FROM files;" 2>/dev/null | tr -d '\r' || true)

  # Batch SQL for all changed files into one transaction (1 sqlite3 call vs. N).
  # A temp table _cur_paths tracks every path present in the current scan so that
  # rows for deleted files can be removed in the same transaction (reconciliation).
  local batch_sql
  batch_sql="$(mktemp /tmp/ctx-XXXXXX.sql)"
  printf 'PRAGMA busy_timeout=5000;\n' > "$batch_sql"
  printf 'BEGIN;\n' >> "$batch_sql"
  printf 'CREATE TEMP TABLE _cur_paths(path TEXT PRIMARY KEY);\n' >> "$batch_sql"

  local indexed=0 skipped=0 found=0
  while IFS= read -r abs_path; do
    [[ -f "$abs_path" ]] || continue
    found=$((found + 1))
    local rel_path="${abs_path#"$root/"}"
    local ep
    ep="$(_ctx_sql_str "$rel_path")"

    # Track every found path for stale-row reconciliation (before mtime skip).
    printf "INSERT OR IGNORE INTO _cur_paths(path) VALUES('%s');\n" "$ep" >> "$batch_sql"

    # Incremental contract: an unchanged mtime is a fast path, not the answer.
    # An edit that preserves mtime leaves the file looking untouched, so the
    # stored sha1 is what actually decides. Hashing every candidate costs well
    # under a second across this repository, which is worth paying to avoid an
    # index that is silently stale.
    local cur_mtime
    cur_mtime="$(_ctx_file_mtime "$abs_path")"
    if [[ "$_force_reextract" -eq 0 \
       && "${_ctx_db_mtimes[$rel_path]+_}" == '_' \
       && "${_ctx_db_mtimes[$rel_path]}" == "$cur_mtime" \
       && -n "${_ctx_db_sha1s[$rel_path]:-}" \
       && "${_ctx_db_sha1s[$rel_path]}" == "$(_ctx_file_sha1 "$abs_path")" ]]; then
      skipped=$((skipped + 1))
      continue
    fi

    _ctx_generate_file_sql "$abs_path" "$rel_path" >> "$batch_sql"
    indexed=$((indexed + 1))
  done < <(_ctx_find_index_files "$root" "$mode")

  # Reconcile deletions: remove rows for files no longer in the tree.
  {
    printf 'DELETE FROM symbols WHERE file_id IN (SELECT id FROM files WHERE path NOT IN (SELECT path FROM _cur_paths));\n'
    printf 'DELETE FROM file_chunks WHERE file_id IN (SELECT id FROM files WHERE path NOT IN (SELECT path FROM _cur_paths));\n'
    printf 'DELETE FROM files WHERE path NOT IN (SELECT path FROM _cur_paths);\n'
    printf 'COMMIT;\n'
    # Stamped in the same transaction as the content it describes, so a run
    # that fails partway never leaves the version claiming more than was built.
    printf "INSERT INTO index_meta(id,schema_version,extractor_version,built_at)\n"
    printf "  VALUES(1,1,%s,%s)\n" "$_CTX_EXTRACTOR_VERSION" "$(_ctx_now_epoch)"
    printf "  ON CONFLICT(id) DO UPDATE SET schema_version=excluded.schema_version,\n"
    printf "    extractor_version=excluded.extractor_version,built_at=excluded.built_at;\n"
  } >> "$batch_sql"

  # Always execute: even if nothing was indexed, reconciliation must run.
  sqlite3 "$db" < "$batch_sql" >/dev/null
  rm -f "$batch_sql"

  # Rebuilding FTS5 is the dominant cost on large repos. An unchanged mtime
  # scan does not alter symbols/chunks, so preserve the existing FTS table.
  # Rebuild only for changed files or a path-count change (pure deletions).
  local _fts_present
  _fts_present="$(sqlite3 "$db" "SELECT count(*) FROM sqlite_master WHERE type='table' AND name='content_fts';" 2>/dev/null || printf '0')"
  if (( indexed > 0 || found != ${#_ctx_db_mtimes[@]} )) || [[ "$_fts_present" != "1" ]] \
     || [[ "$_force_reextract" -eq 1 ]]; then
    _ctx_fts_rebuild "$db"
  fi

  printf 'context index: %d indexed, %d skipped\n' "$indexed" "$skipped"
  printf 'db: %s\n' "$db"
}

# ── pmctl_context_index ────────────────────────────────────────────────────────

pmctl_context_index() {
  local repo_root
  if [[ $# -gt 0 && -d "${1:-}" ]]; then
    repo_root="$1"; shift
  else
    repo_root="$(_ctx_default_repo_root)" || repo_root=""
  fi
  if [[ -z "$repo_root" ]]; then
    printf 'pmctl context index: repo root required\n' >&2
    return 2
  fi

  local source_flag="repo"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --source)
        if [[ $# -lt 2 ]]; then
          printf 'pmctl context index: --source requires a value\n' >&2
          return 2
        fi
        source_flag="$2"
        shift 2
        ;;
      --source=*)
        source_flag="${1#--source=}"
        shift
        ;;
      --)
        shift
        break
        ;;
      -*)
        printf 'pmctl context index: unknown flag %s\n' "$1" >&2
        return 2
        ;;
      *)
        break
        ;;
    esac
  done

  local root db do_gitignore mode
  case "$source_flag" in
    repo)
      root="$repo_root"
      db="$(_ctx_db_path "$repo_root")"
      do_gitignore=1
      mode=repo
      ;;
    memory)
      local mdir
      mdir="$(_ctx_resolve_memory_dir "$repo_root")" || mdir=""
      if [[ -z "$mdir" ]]; then
        printf 'pmctl context index: no memory directory found for %s\n' "$repo_root" >&2
        return 1
      fi
      root="$mdir"
      db="$(_ctx_memory_db_path "$mdir")"
      do_gitignore=0
      mode=memory
      ;;
    *)
      printf 'pmctl context index: unsupported --source value: %s (expected repo|memory)\n' \
        "$source_flag" >&2
      return 2
      ;;
  esac

  if ! _ctx_sqlite3_check; then
    printf 'pmctl context index: sqlite3 not found on PATH\n' >&2
    return 1
  fi

  _ctx_index_tree "$root" "$db" "$do_gitignore" "$mode"
}

# ── Memory-plane freshness (auto-build / auto-refresh) ────────────────────────
# Mirror of _ctx_ensure_fresh for the memory plane. Honors the same opt-out env
# vars. Returns non-zero (no output) when memory is unavailable so read-side
# callers degrade to "# no hits".

_ctx_ensure_fresh_memory() {
  local memory_dir="$1"
  local mdb
  mdb="$(_ctx_memory_db_path "$memory_dir")"

  if [[ ! -f "$mdb" ]]; then
    [[ "${PM_DISPATCH_CONTEXT_AUTOBUILD:-1}" == "0" ]] && return 1
    _ctx_sqlite3_check || return 1
    _ctx_index_tree "$memory_dir" "$mdb" 0 memory >/dev/null 2>&1 || return 1
    return 0
  fi

  [[ "${PM_DISPATCH_CONTEXT_AUTOREFRESH:-1}" == "0" ]] && return 0
  _ctx_sqlite3_check || return 1
  _ctx_index_tree "$memory_dir" "$mdb" 0 memory >/dev/null 2>&1 || return 1
}

# Ensure read-side context commands do not depend on a prior manual index step.
# Index stdout is suppressed because query/pack/reuse-scan stdout is parsed.
_ctx_ensure_fresh() {
  local repo_root="$1"
  local db
  db="$(_ctx_db_path "$repo_root")"

  if [[ ! -f "$db" ]]; then
    [[ "${PM_DISPATCH_CONTEXT_AUTOBUILD:-1}" == "0" ]] && return 1
    _ctx_sqlite3_check || return 1

    printf 'context: no index found — building %s\n' "$db" >&2
    if ! pmctl_context_index "$repo_root" > /dev/null; then
      printf 'context: auto-build failed for %s\n' "$db" >&2
      return 1
    fi
    return 0
  fi

  [[ "${PM_DISPATCH_CONTEXT_AUTOREFRESH:-1}" == "0" ]] && return 0
  _ctx_sqlite3_check || return 1

  if ! pmctl_context_index "$repo_root" > /dev/null; then
    printf 'context: auto-refresh failed for %s\n' "$db" >&2
    return 1
  fi
}

# Read-only diagnostic for repo-root/DB resolution and freshness. It never
# creates or refreshes an index; callers can inspect the result before deciding
# whether to run a workflow refresh.
pmctl_context_status() {
  local repo_root="" json=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --json) json=1; shift ;;
      -*) printf 'pmctl context status: unknown flag %s\n' "$1" >&2; return 2 ;;
      *)
        [[ -z "$repo_root" && -d "$1" ]] || { printf 'pmctl context status: expected one repo directory\n' >&2; return 2; }
        repo_root="$1"; shift ;;
    esac
  done
  if [[ -z "$repo_root" ]]; then
    repo_root="$(_ctx_default_repo_root)" || repo_root=""
  fi
  repo_root="$(cd "$repo_root" 2>/dev/null && { git rev-parse --show-toplevel 2>/dev/null || pwd -P; })" || {
    printf 'pmctl context status: repo directory is not readable\n' >&2
    return 2
  }

  local db sqlite_available=false db_exists=false freshness=missing
  local indexed_files=0 new_files=0 changed_files=0 deleted_files=0 matched_files=0
  local db_mtime="" latest_indexed_at=""
  db="$(_ctx_db_path "$repo_root")"
  _ctx_sqlite3_check && sqlite_available=true
  if [[ -f "$db" ]]; then
    db_exists=true
    db_mtime="$(_ctx_file_mtime "$db")"
  fi

  if [[ "$sqlite_available" == true && "$db_exists" == true ]]; then
    declare -A _status_mtimes=()
    local p m abs rel
    while IFS='|' read -r p m; do
      [[ -n "$p" ]] && _status_mtimes["$p"]="$m"
    done < <(sqlite3 "$db" 'SELECT path, mtime FROM files;' 2>/dev/null | tr -d '\r' || true)
    indexed_files="${#_status_mtimes[@]}"
    latest_indexed_at="$(sqlite3 "$db" 'SELECT COALESCE(MAX(indexed_at), "") FROM files;' 2>/dev/null || true)"
    while IFS= read -r abs; do
      [[ -f "$abs" ]] || continue
      rel="${abs#"$repo_root/"}"
      if [[ -z "${_status_mtimes[$rel]+_}" ]]; then
        new_files=$((new_files + 1))
      else
        matched_files=$((matched_files + 1))
        [[ "${_status_mtimes[$rel]}" == "$(_ctx_file_mtime "$abs")" ]] || changed_files=$((changed_files + 1))
      fi
    done < <(_ctx_find_index_files "$repo_root" repo)
    deleted_files=$((indexed_files - matched_files))
    (( deleted_files < 0 )) && deleted_files=0
    if (( new_files == 0 && changed_files == 0 && deleted_files == 0 )); then
      freshness=fresh
    else
      freshness=stale
    fi
  elif [[ "$sqlite_available" == false ]]; then
    freshness=unavailable
  fi

  if [[ "$json" -eq 1 ]]; then
    jq -cn \
      --arg repo_root "$repo_root" --arg db_path "$db" \
      --argjson sqlite_available "$sqlite_available" --argjson db_exists "$db_exists" \
      --arg freshness "$freshness" --argjson indexed_files "$indexed_files" \
      --argjson new_files "$new_files" --argjson changed_files "$changed_files" \
      --argjson deleted_files "$deleted_files" --arg db_mtime "$db_mtime" \
      --arg latest_indexed_at "$latest_indexed_at" \
      '{schema_version:1,resolved_repo_root:$repo_root,db_path:$db_path,
        sqlite_available:$sqlite_available,db_exists:$db_exists,freshness:$freshness,
        indexed_files:$indexed_files,new_files:$new_files,changed_files:$changed_files,
        deleted_files:$deleted_files,db_mtime:(if $db_mtime == "" then null else ($db_mtime|tonumber) end),
        latest_indexed_at:(if $latest_indexed_at == "" then null else $latest_indexed_at end)}'
  else
    printf 'resolved_repo_root: %s\ndb: %s\nsqlite_available: %s\ndb_exists: %s\nfreshness: %s\n' \
      "$repo_root" "$db" "$sqlite_available" "$db_exists" "$freshness"
    printf 'indexed_files: %s\nnew_files: %s\nchanged_files: %s\ndeleted_files: %s\n' \
      "$indexed_files" "$new_files" "$changed_files" "$deleted_files"
  fi
}

# Best-effort workflow boundary used by prompt/session, PM preparation, and the
# pmctl gate wrapper. Missing sqlite is an explicit non-error capability state.
pmctl_context_workflow_refresh() {
  local repo_root="${1:-}" json=0
  [[ $# -gt 0 ]] && shift
  [[ "${1:-}" == "--json" ]] && { json=1; shift; }
  [[ $# -eq 0 ]] || { printf 'pmctl context workflow-refresh: unexpected argument %s\n' "$1" >&2; return 2; }
  repo_root="$(cd "$repo_root" 2>/dev/null && { git rev-parse --show-toplevel 2>/dev/null || pwd -P; })" || {
    printf 'pmctl context workflow-refresh: repo directory is not readable\n' >&2
    return 2
  }
  local db refresh_status status_json
  db="$(_ctx_db_path "$repo_root")"
  if ! _ctx_sqlite3_check; then
    refresh_status=unavailable
  elif [[ -f "$db" && "${PM_DISPATCH_CONTEXT_AUTOREFRESH:-1}" == "0" ]]; then
    # AUTOREFRESH=0 is a real caller policy, not a successful refresh. Report
    # the skipped boundary accurately while preserving the read-only freshness
    # diagnosis (which may be stale).
    refresh_status=skipped
  else
    refresh_status=refreshed
    [[ -f "$db" ]] || refresh_status=built
    if ! _ctx_ensure_fresh "$repo_root"; then
      refresh_status=error
    fi
  fi
  status_json="$(pmctl_context_status "$repo_root" --json)" || return $?
  if [[ "$json" -eq 1 ]]; then
    jq -c --arg refresh_status "$refresh_status" '. + {refresh_status:$refresh_status}' <<<"$status_json"
  else
    pmctl_context_status "$repo_root"
    printf 'refresh_status: %s\n' "$refresh_status"
  fi
}

# ── pmctl_context_update ───────────────────────────────────────────────────────

pmctl_context_update() {
  local repo_root
  if [[ $# -gt 0 && -d "${1:-}" ]]; then
    repo_root="$1"; shift
  else
    repo_root="$(_ctx_default_repo_root)" || repo_root=""
  fi
  if [[ -z "$repo_root" ]]; then
    printf 'pmctl context update: repo root required\n' >&2
    return 2
  fi

  local target_path=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --)
        shift
        break
        ;;
      -*)
        printf 'pmctl context update: unknown flag %s\n' "$1" >&2
        return 2
        ;;
      *)
        target_path="$1"
        shift
        break
        ;;
    esac
  done

  if ! _ctx_sqlite3_check; then
    printf 'pmctl context update: sqlite3 not found on PATH\n' >&2
    return 1
  fi

  local db
  db="$(_ctx_db_path "$repo_root")"
  if [[ ! -f "$db" ]]; then
    printf 'pmctl context update: index not found; run pmctl context index first\n' >&2
    return 1
  fi

  if [[ -n "$target_path" ]]; then
    # Re-index a specific file — path must resolve within repo_root.
    # Canonicalize repo_root (follow symlinks) for a reliable prefix check.
    local canon_root
    canon_root="$(cd "$repo_root" 2>/dev/null && pwd -P 2>/dev/null || printf '%s' "$repo_root")"

    # Build absolute candidate: absolute paths stay as-is, relative join to canon_root.
    local candidate
    if [[ "${target_path:0:1}" == "/" ]]; then
      candidate="$target_path"
    else
      candidate="$canon_root/$target_path"
    fi

    # Resolve .. (does not require file to exist); realpath_m from portable.sh.
    local real_path
    real_path="$(realpath_m "$candidate" 2>/dev/null || printf '%s' "$candidate")"

    # Enforce repo-root containment.
    case "$real_path" in
      "$canon_root"/*) ;;
      *)
        printf 'pmctl context update: path outside repo: %s\n' "$target_path" >&2
        return 2
        ;;
    esac

    if [[ ! -f "$real_path" ]]; then
      printf 'pmctl context update: file not found: %s\n' "$target_path" >&2
      return 1
    fi
    local rel_path="${real_path#"$canon_root/"}"
    _ctx_index_file "$db" "$real_path" "$rel_path"
    _ctx_fts_rebuild "$db"
    printf 'context update: re-indexed %s\n' "$rel_path"
  else
    # No path given: full incremental scan (same as index with mtime check)
    pmctl_context_index "$repo_root"
  fi
}

# ── ISO-8601 UTC timestamp ────────────────────────────────────────────────────

_ctx_now_iso8601() {
  date -u +%Y-%m-%dT%H:%M:%SZ
}

# ── JSON string escaping ───────────────────────────────────────────────────────
# Returns a JSON-escaped string WITH surrounding double-quotes.
# Escape order: \ → " → newline → CR → tab.
# Pure bash parameter expansion — no subshell, no external tool.

_ctx_json_str() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  s="${s//$'\t'/\\t}"
  printf '"%s"' "$s"
}

# ── Usage event emission ──────────────────────────────────────────────────────
# Best-effort: emits a context.queried or context.reuse_scanned event to
# events.jsonl via the already-sourced state-writer.  A dropped event must never
# change the caller's exit status or pollute stdout — but the failure is made
# OBSERVABLE (one-line stderr warning + state-writer error log) rather than
# swallowed silently, so an undelivered telemetry event is diagnosable instead
# of surfacing later as an unexplained "no event" readback.

_ctx_emit_warn() {
  local kind="$1" reason="$2"
  printf 'context: warning: %s telemetry not recorded (%s)\n' "$kind" "$reason" >&2
  declare -F _sw_log_error >/dev/null 2>&1 \
    && _sw_log_error "context: $kind event not recorded: $reason"
  return 0
}

_ctx_emit_usage_event() {
  local kind="$1" query_term="$3" hit_count="${4:-0}"
  if ! declare -F events_append >/dev/null 2>&1 \
     || ! declare -F state_store_init >/dev/null 2>&1; then
    _ctx_emit_warn "$kind" "state-writer not loaded"; return 0
  fi
  # Telemetry is keyed to the pmctl installation repo partition (via _SW_REPO_ROOT),
  # NOT the indexed target-repo partition — so `pmctl trace` run from the pmctl repo
  # shows context usage aggregated across every repo it indexes. The store *root* is
  # NOT forced: PM_DISPATCH_STATE_ROOT is honored like every other state write, so a
  # user (or test) that redirects state also redirects this telemetry.
  local pmctl_root ts stamp hex6 evt_id event_json
  pmctl_root="$(cd "$_CTX_LIB_DIR/../.." && pwd)"
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date +%Y-%m-%dT%H:%M:%SZ)"
  stamp="$(date -u +%Y%m%dT%H%M%SZ 2>/dev/null || date +%Y%m%dT%H%M%SZ)"
  hex6="$(dd if=/dev/urandom bs=3 count=1 2>/dev/null | od -An -tx1 | tr -d ' \n')"
  hex6="${hex6:0:6}"
  if [[ -z "$hex6" ]]; then
    _ctx_emit_warn "$kind" "could not generate event id (urandom unavailable)"; return 0
  fi
  evt_id="evt-${stamp}-${hex6}"
  if ! event_json="$(jq -cn \
    --arg id     "$evt_id" \
    --arg ts     "$ts" \
    --arg kind   "$kind" \
    --arg query  "$query_term" \
    --argjson hits "$hit_count" \
    '{schema_version:1,id:$id,ts:$ts,kind:$kind,
      subject_type:"context",subject_id:("ctx-"+ $id),
      actor:"pmctl",
      payload:{query:$query,hits:$hits}}' 2>/dev/null)"; then
    _ctx_emit_warn "$kind" "jq failed to build event json"; return 0
  fi
  local append_err append_status=0
  append_err="$(_SW_REPO_ROOT="$pmctl_root" \
    events_append "$event_json" 2>&1)" || append_status=$?
  if [[ "$append_status" -ne 0 ]]; then
    _ctx_emit_warn "$kind" "events_append exited $append_status: ${append_err:-no detail}"
    return 0
  fi
  return 0
}

# ── Term extraction from free-text description ────────────────────────────────
# Outputs unique lower-case terms (ASCII ≥ 3 chars, not stop words; CJK
# overlapping 2-grams), one per line. Isolated change seam — callers must
# not inline this logic; implementation lives in retrieval-terms.sh.

_ctx_extract_terms() {
  retrieval_extract_terms "${1-}"
}

# ── Raw query result emitter (internal only) ───────────────────────────────────
# Outputs TSV rows: ref<TAB>domain<TAB>why<TAB>conf<TAB>trust
# No deduplication — callers handle dedup and formatting.
# Single query-execution path shared by pmctl_context_query (YAML output)
# and _ctx_parse_query_tsv (pack / reuse-scan TSV accumulation).

# Args: repo_root query [domain] [db_override] [domain_label]
#   db_override   — query this DB instead of <repo_root>/.pm-dispatch/ctx/context.db
#                   (used for the out-of-repo memory plane).
#   domain_label  — when set (e.g. "memory"), every hit's source_domain is forced
#                   to this label and trust is derived via _ctx_memory_trust; the
#                   knowledge/repo path classifier and domain filter are bypassed
#                   (the memory plane has no knowledge/repo subclasses).
# Ranking tier bases (large, well-separated integers so a trust/domain boost
# can only reorder hits WITHIN a match_kind tier, never across tiers -- an
# exact symbol match must always outrank a text match regardless of boosts).
# All arithmetic here is bash integer math or done inside the SQL SELECT
# itself; no per-row subprocess (awk/bc) is spawned -- this repo's indexer
# has repeatedly hit the same per-item-subprocess cost shape (CC-563 et al).
_CTX_RANK_BASE_SYMBOL_EXACT=1000000
_CTX_RANK_BASE_SYMBOL_PARTIAL=500000
_CTX_RANK_BASE_FTS5=100000
_CTX_RANK_BASE_LIKE_FALLBACK=10000

# _ctx_compose_score <tier_base> <trust> <domain> [bm25_scaled]
# The one place tier base + trust/domain boosts (+ an optional bm25 term for
# the FTS5 branch) are combined into a final ranking_score and its
# human-readable score_components breakdown. Prints "<score>\t<components>".
_ctx_compose_score() {
  local base="$1" trust="$2" domain="$3" bm25_scaled="${4:-}"
  local tb=0 db_boost=0 score components
  case "$trust" in
    high) tb=2000 ;;
    medium) tb=1000 ;;
  esac
  [[ "$domain" == knowledge ]] && db_boost=500
  if [[ -n "$bm25_scaled" ]]; then
    score=$(( base + bm25_scaled + tb + db_boost ))
    components="base:${base},bm25:${bm25_scaled},trust:${tb},domain:${db_boost}"
  else
    score=$(( base + tb + db_boost ))
    components="base:${base},trust:${tb},domain:${db_boost}"
  fi
  printf '%s\t%s\n' "$score" "$components"
}

_ctx_query_hits_raw() {
  local repo_root="$1" query="$2" domain="${3:-}" db_override="${4:-}" domain_label="${5:-}"
  local db eq domain_sql=""
  if [[ -n "$db_override" ]]; then
    db="$db_override"
  else
    db="$(_ctx_db_path "$repo_root")"
  fi
  eq="$(_ctx_sql_str "$query")"

  # domain filter only applies on the repo plane; memory mode passes domain="".
  case "$domain" in
    knowledge)
      domain_sql=" AND (f.path IN ('BACKLOG.md','DECISIONS.md','MILESTONES.md') OR f.path LIKE 'docs/%')"
      ;;
    repo)
      domain_sql=" AND NOT (f.path IN ('BACKLOG.md','DECISIONS.md','MILESTONES.md') OR f.path LIKE 'docs/%')"
      ;;
  esac

  # Symbol match: exact (case-insensitive name equality) vs partial (LIKE).
  # match_kind and the tier base are computed in SQL so the exact/partial
  # split costs nothing extra per row.
  while IFS=$'\t' read -r path name kind line_start line_end match_kind; do
    [[ -n "$path" ]] || continue
    local hit_domain hit_trust score components tier_base
    if [[ -n "$domain_label" ]]; then
      hit_domain="$domain_label"; hit_trust="$(_ctx_memory_trust "$path")"
    else
      hit_domain="$(_ctx_classify_domain "$path")"; hit_trust="high"
    fi
    if [[ "$match_kind" == symbol_exact ]]; then
      tier_base="$_CTX_RANK_BASE_SYMBOL_EXACT"
    else
      tier_base="$_CTX_RANK_BASE_SYMBOL_PARTIAL"
    fi
    IFS=$'\t' read -r score components < <(_ctx_compose_score "$tier_base" "$hit_trust" "$hit_domain")
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$path:$line_start" "$hit_domain" "symbol: $name ($kind)" "0.85" "$hit_trust" \
      "$match_kind" "${line_end:-$line_start}" "$score" "$components"
  done < <(sqlite3 -separator $'\t' "$db" \
    "SELECT f.path, s.name, s.kind, s.line_start, s.line_end,
       (CASE WHEN lower(s.name) = lower('${eq}') THEN 'symbol_exact' ELSE 'symbol_partial' END)
     FROM symbols s JOIN files f ON s.file_id=f.id
     WHERE s.name LIKE '%${eq}%'${domain_sql}
     ORDER BY (lower(s.name) = lower('${eq}')) DESC, f.path, s.line_start
     LIMIT 20;" 2>/dev/null | tr -d '\r' || true)

  local use_fts5=0
  if _ctx_fts5_available "$db" \
    && sqlite3 "$db" "SELECT name FROM sqlite_master WHERE type='table' AND name='content_fts';" \
       2>/dev/null | grep -q 'content_fts'; then
    use_fts5=1
  fi

  if [[ "$use_fts5" -eq 1 ]]; then
    local fts_tmpf fts_query
    fts_query="${query//\"/\"\"}"
    fts_query="$(_ctx_sql_str "$fts_query")"
    fts_tmpf="$(mktemp /tmp/ctx-XXXXXX.sql)"
    # bm25() is smaller-is-better (best matches are most negative); scale and
    # negate entirely in SQL so bash only ever adds pre-computed integers.
    printf "SELECT ref, replace(replace(text, char(10), ' '), char(13), ' '), CAST(ROUND(-bm25(content_fts)*100) AS INTEGER), line_end FROM content_fts WHERE content_fts MATCH '\"%s\"' ORDER BY bm25(content_fts) LIMIT 20;\n" \
      "$fts_query" > "$fts_tmpf"
    while IFS=$'\t' read -r ref text bm25_scaled fts_line_end_col; do
      [[ -n "$ref" ]] || continue
      local fts_path fts_domain fts_trust fts_line_start fts_line_end score components
      fts_path="${ref%:*}"
      fts_line_start="${ref##*:}"
      # The rebuilt content_fts table carries the real chunk/symbol line_end
      # (see _ctx_fts_rebuild); fall back to line_start only if it is somehow
      # absent, rather than silently claiming a one-line span.
      if [[ "$fts_line_end_col" =~ ^[0-9]+$ ]]; then
        fts_line_end="$fts_line_end_col"
      else
        fts_line_end="$fts_line_start"
      fi
      if [[ -n "$domain_label" ]]; then
        fts_domain="$domain_label"; fts_trust="$(_ctx_memory_trust "$fts_path")"
      else
        fts_domain="$(_ctx_classify_domain "$fts_path")"; fts_trust="medium"
      fi
      if [[ -n "$domain" && "$fts_domain" != "$domain" ]]; then
        continue
      fi
      [[ "$bm25_scaled" =~ ^-?[0-9]+$ ]] || bm25_scaled=0
      IFS=$'\t' read -r score components < <(_ctx_compose_score "$_CTX_RANK_BASE_FTS5" "$fts_trust" "$fts_domain" "$bm25_scaled")
      local snippet
      snippet="${text:0:80}"
      snippet="${snippet//$'\t'/ }"
      printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$ref" "$fts_domain" "fts5 match: $snippet" "0.75" "$fts_trust" \
        "fts5_content" "$fts_line_end" "$score" "$components"
    done < <(sqlite3 -separator $'\t' "$db" < "$fts_tmpf" 2>/dev/null | tr -d '\r' || true)
    rm -f "$fts_tmpf"
  else
    # No relevance signal is computable without FTS5; ORDER BY here (and the
    # uniform tier-base score, tie-broken on ref by the shared ranker) is
    # what makes this path's ordering deterministic run-to-run, per Req 2 --
    # it is not, and does not claim to be, relevance-ranked.
    while IFS=$'\t' read -r path line_start line_end; do
      [[ -n "$path" ]] || continue
      local hit_domain hit_trust score components
      if [[ -n "$domain_label" ]]; then
        hit_domain="$domain_label"; hit_trust="$(_ctx_memory_trust "$path")"
      else
        hit_domain="$(_ctx_classify_domain "$path")"; hit_trust="medium"
      fi
      IFS=$'\t' read -r score components < <(_ctx_compose_score "$_CTX_RANK_BASE_LIKE_FALLBACK" "$hit_trust" "$hit_domain")
      printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$path:$line_start" "$hit_domain" "text match in chunk" "0.7" "$hit_trust" \
        "like_fallback" "${line_end:-$line_start}" "$score" "$components"
    done < <(sqlite3 -separator $'\t' "$db" \
      "SELECT f.path, fc.line_start, fc.line_end
       FROM file_chunks fc JOIN files f ON fc.file_id=f.id
       WHERE (fc.text LIKE '%${eq}%' OR fc.heading LIKE '%${eq}%')${domain_sql}
       ORDER BY f.path, fc.line_start
       LIMIT 20;" 2>/dev/null | tr -d '\r' || true)
  fi
}

# _ctx_rank_hits <9-col-raw-tsv> [limit] [dedup_by_ref]
# THE single ranking + truncation path (CC-505 Req 3): every consumer
# (query/pack/reuse-scan/prompt-scan) must merge its candidate hits into one
# TSV file (ref, domain, why, conf, trust, match_kind, line_end,
# ranking_score, score_components) and call this function rather than
# re-sorting or re-truncating by its own heuristic. Sorts by ranking_score
# descending, ties broken by ref ascending for full run-to-run determinism,
# assigns a 1-based rank, and truncates to <limit> (0 or omitted = no
# truncation). Output is 10 columns: rank, then the 9 input columns in order.
#
# dedup_by_ref (0/1, default 0): when a multi-term caller (pack/reuse-scan/
# prompt-scan) has accumulated candidates from several --query terms into one
# input file, the SAME ref can appear more than once with different scores
# (e.g. a weak fts5 match from one term, a symbol_exact match from another).
# With dedup_by_ref=1, only the highest-scoring occurrence of each ref
# survives -- safe to do AFTER sorting (the first occurrence of a ref in
# score-descending order is its best one), never before, which is exactly
# the gate finding this fixes (critic-F001): eager dedup during accumulation
# discarded a later, better-scoring candidate before ranking ever saw it.
# pmctl_context_query passes dedup_by_ref=0 (default) because it
# deliberately keeps both a symbol hit and a text hit for the same ref from
# a single query -- see its own comment.
_ctx_rank_hits() {
  local input="$1" limit="${2:-0}" dedup_by_ref="${3:-0}"
  [[ -s "$input" ]] || return 0
  local rank=0 seen_refs=$'\x02'
  while IFS=$'\t' read -r ref rdomain why conf trust match_kind line_end score components; do
    [[ -n "$ref" ]] || continue
    if [[ "$dedup_by_ref" == 1 ]]; then
      [[ "$seen_refs" == *$'\x02'"$ref"$'\x02'* ]] && continue
      seen_refs+="$ref"$'\x02'
    fi
    rank=$((rank + 1))
    if [[ "$limit" -gt 0 && "$rank" -gt "$limit" ]]; then
      break
    fi
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$rank" "$ref" "$rdomain" "$why" "$conf" "$trust" "$match_kind" "$line_end" "$score" "$components"
  done < <(sort -t $'\t' -k8,8gr -k1,1 "$input")
}

# _ctx_pack_top_n <pack-json> <n>
# Keeps the <n> globally highest-ranking items across files[]+symbols[]+
# memories[] combined (their ranking_score values share one scale, since
# every array was ranked through _ctx_rank_hits), tie-broken by ref, and
# drops the rest -- each item's origin array is preserved. Used by
# _ctx_apply_pack_budget for CC-505 Req 5's global item/byte budget; never
# call directly, since it does not compute or attach the `truncation`
# disclosure field.
_ctx_pack_top_n() {
  local pack="$1" n="$2"
  jq -c --argjson n "$n" '
    . as $pack
    | ([$pack.files[]?    | . + {_arr:"files"}]
       + [$pack.symbols[]?  | . + {_arr:"symbols"}]
       + [$pack.memories[]? | . + {_arr:"memories"}]) as $all
    | ($all | sort_by(-(.ranking_score // 0), .ref)) as $sorted
    | ($sorted[:$n]) as $kept
    | ($pack
        | .files    = [$kept[] | select(._arr=="files")    | del(._arr)]
        | .symbols  = [$kept[] | select(._arr=="symbols")  | del(._arr)]
        | .memories = [$kept[] | select(._arr=="memories") | del(._arr)])
  ' <<<"$pack"
}

# _ctx_pack_with_truncation <original-pack-json> <total_before> <n>
#   <max_items> <max_bytes> <applied> <reason>
# Builds the fully-assembled candidate pack (top-<n> items across all
# arrays PLUS the truncation disclosure object) so its caller can measure
# the real final byte size, not just the bare item-bounded pack -- the
# truncation object's own bytes must count toward the budget it describes.
_ctx_pack_with_truncation() {
  local pack="$1" total="$2" n="$3" max_items="$4" max_bytes="$5" applied="$6" reason="$7"
  local bounded kept
  bounded="$(_ctx_pack_top_n "$pack" "$n")"
  kept="$(jq '(.files|length)+(.symbols|length)+(.memories|length)' <<<"$bounded")"
  jq -c \
    --argjson applied "$applied" --arg reason "$reason" \
    --argjson max_items "$max_items" --argjson max_bytes "$max_bytes" \
    --argjson total "$total" --argjson kept "$kept" --argjson dropped "$((total - kept))" \
    '. + {truncation:{applied:$applied,reason:$reason,budget:{max_items:$max_items,max_bytes:$max_bytes},total_before:$total,kept:$kept,dropped:$dropped}}' \
    <<<"$bounded"
}

# _ctx_apply_pack_budget <pack-json-without-truncation> <max_items> <max_bytes>
# CC-505 Req 5: the ONE place the global item + byte budget is enforced and
# disclosed. Applies the item cap first (drop lowest-ranked overall down to
# max_items), then iteratively drops the next-lowest-ranked survivor while
# the serialized pack exceeds max_bytes (same "remove whole entries and
# re-serialize, never raw-slice JSON" approach pmctl_pm_bound_memory_pack
# already established for its own downstream memory-only budget). Always
# attaches a `truncation` object -- disclosed even when nothing was
# dropped, so a caller never has to infer budget status from array lengths.
# The byte check measures the FINAL output including the truncation object
# itself (via _ctx_pack_with_truncation), not just the bounded item arrays
# -- a pack that "just barely fits" before that object is attached could
# otherwise still exceed max_bytes once it is, silently violating the very
# budget being enforced.
_ctx_apply_pack_budget() {
  local pack="$1" max_items="$2" max_bytes="$3"
  local total keep_n final bytes applied=false reason=none

  total="$(jq '(.files|length)+(.symbols|length)+(.memories|length)' <<<"$pack")"
  keep_n="$total"
  if (( total > max_items )); then
    keep_n="$max_items"
    applied=true
    reason=item_budget
  fi

  # Measure the EXACT bytes this function emits -- printf '%s\n' below adds a
  # trailing newline, so the check here must include it too. Measuring the
  # bare $final (no newline) undercounts by one byte and can let an
  # over-budget pack through at an exact boundary.
  final="$(_ctx_pack_with_truncation "$pack" "$total" "$keep_n" "$max_items" "$max_bytes" "$applied" "$reason")"
  bytes="$(printf '%s\n' "$final" | wc -c | tr -d '[:space:]')"
  while (( bytes > max_bytes && keep_n > 0 )); do
    keep_n=$((keep_n - 1))
    applied=true
    reason=byte_budget
    final="$(_ctx_pack_with_truncation "$pack" "$total" "$keep_n" "$max_items" "$max_bytes" "$applied" "$reason")"
    bytes="$(printf '%s\n' "$final" | wc -c | tr -d '[:space:]')"
  done

  # Impossible cap: even the 0-item envelope (truncation object + newline)
  # cannot fit under max_bytes. Silently emitting an over-budget result would
  # violate the very budget this function exists to enforce -- fail closed
  # instead so a caller can raise max_bytes rather than trust a broken disclosure.
  if (( bytes > max_bytes )); then
    printf 'pmctl context pack: max_bytes=%s is too small to fit even an empty pack (%s bytes required)\n' \
      "$max_bytes" "$bytes" >&2
    return 2
  fi

  printf '%s\n' "$final"
}

# ── Per-term query parser ──────────────────────────────────────────────────────
# Uses _ctx_query_hits_raw for structured TSV input and routes hits by
# match_kind:
#   symbol_exact / symbol_partial → sym_tsv
#   fts5_content / like_fallback  → files_tsv
# Each output row carries the full 9-column raw shape (ref, domain, why,
# conf, trust, match_kind, line_end, ranking_score, score_components).
#
# Deliberately does NOT deduplicate by ref here (gate finding critic-F001,
# CC-505): a multi-term caller accumulates candidates from several --query
# terms into the same sym_tsv/files_tsv, and the same ref can legitimately
# get a weak match from one term and a strong one from another. Deduping
# eagerly during accumulation -- by first-seen, not best-scored -- silently
# discarded a later, better-scoring candidate before _ctx_rank_hits ever saw
# it. Callers that want deduplication ask _ctx_rank_hits for it (dedup_by_ref
# arg), which is safe only AFTER sorting by score.

_ctx_parse_query_tsv() {
  local repo_root="$1" term="$2" sym_tsv="$3" files_tsv="$4"
  local domain="${5:-}"
  while IFS=$'\t' read -r ref hit_domain why conf trust match_kind line_end score components; do
    [[ -n "$ref" ]] || continue
    if [[ "$match_kind" == symbol_* ]]; then
      printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$ref" "$hit_domain" "$why" "$conf" "$trust" "$match_kind" "$line_end" "$score" "$components" >> "$sym_tsv"
    else
      printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$ref" "$hit_domain" "$why" "$conf" "$trust" "$match_kind" "$line_end" "$score" "$components" >> "$files_tsv"
    fi
  done < <(_ctx_query_hits_raw "$repo_root" "$term" "$domain" 2>/dev/null)
}

# ── TSV-to-JSON array assembler ────────────────────────────────────────────────
# Reads a _ctx_rank_hits-ranked TSV (rank, ref, domain, why, conf, trust,
# match_kind, line_end, ranking_score, score_components) and emits a JSON
# array of context_hit_v1 objects, additively carrying the CC-505 Req 2-4
# ranking fields alongside the pre-existing, schema-required `confidence`
# field (whose value and meaning are unchanged by this ranking work -- see
# design constraint 2). Missing or empty file → "[]".

_ctx_tsv_to_json_array() {
  local tsv_file="$1"
  if [[ ! -f "$tsv_file" || ! -s "$tsv_file" ]]; then
    printf '[]'
    return
  fi
  local first=1
  printf '['
  while IFS=$'\t' read -r rank ref domain why conf trust match_kind line_end score components; do
    [[ "$first" -eq 0 ]] && printf ','
    first=0
    # Source attribution tracks the plane (CC-403): memory items are
    # `memory-index`, repo items stay `builtin-index`.
    local src="builtin-index" line_start="${ref##*:}"
    [[ "$domain" == "memory" ]] && src="memory-index"
    [[ "$line_start" =~ ^[0-9]+$ ]] || line_start=null
    printf '{"ref":%s,"source":%s,"confidence":%s,"source_domain":%s,"why_relevant":%s,"trust_level":%s,"rank":%s,"match_kind":%s,"line_start":%s,"line_end":%s,"ranking_score":%s,"score_components":%s}' \
      "$(_ctx_json_str "$ref")" \
      "$(_ctx_json_str "$src")" "$conf" \
      "$(_ctx_json_str "$domain")" \
      "$(_ctx_json_str "$why")" \
      "$(_ctx_json_str "$trust")" \
      "$rank" \
      "$(_ctx_json_str "$match_kind")" \
      "$line_start" \
      "${line_end:-null}" \
      "$score" \
      "$(_ctx_json_str "$components")"
  done < "$tsv_file"
  printf ']'
}

# ── Multi-source raw query (plane fan-out) ────────────────────────────────────
# Emits raw TSV hits for the requested source plane(s). repo_root is the cwd used
# both as the repo-DB anchor and to resolve the memory dir. No dedup is performed
# (matching the single-source path, which can already emit a symbol + text hit
# for one ref). Memory-plane freshness is ensured here so a memory-only query is
# independent of the repo DB; a missing memory dir or DB yields no rows (the
# caller renders that as "# no hits").

_ctx_query_sources_raw() {
  local repo_root="$1" query="$2" domain="$3" source="$4"

  if [[ "$source" == "repo" || "$source" == "all" ]]; then
    _ctx_query_hits_raw "$repo_root" "$query" "$domain" "" ""
  fi

  if [[ "$source" == "memory" || "$source" == "all" ]]; then
    local mdir mdb
    mdir="$(_ctx_resolve_memory_dir "$repo_root")" || mdir=""
    if [[ -n "$mdir" ]]; then
      _ctx_ensure_fresh_memory "$mdir" || true
      mdb="$(_ctx_memory_db_path "$mdir")"
      if [[ -f "$mdb" ]]; then
        _ctx_query_hits_raw "$repo_root" "$query" "" "$mdb" "memory"
      fi
    fi
  fi
}

# ── pmctl_context_query ────────────────────────────────────────────────────────
#
# Searches the repo and/or memory index and outputs context_hit_v1 YAML blocks.
# --source repo|memory|all selects the plane(s); --domain (repo-plane only)
# narrows by knowledge/repo path class.
# FTS5 path: uses content_fts virtual table (MATCH) for full-text search.
# LIKE fallback: searches symbols.name and file_chunks.text with LIKE.
# Either path also searches symbols.name with LIKE for reliable symbol lookup.

pmctl_context_query() {
  local repo_root
  if [[ $# -gt 0 && -d "${1:-}" ]]; then
    repo_root="$1"; shift
  else
    repo_root="$(_ctx_default_repo_root)" || repo_root=""
  fi
  if [[ -z "$repo_root" ]]; then
    printf 'pmctl context query: repo root required\n' >&2
    return 2
  fi

  local query="" domain="" source="repo"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --domain)
        if [[ $# -lt 2 ]]; then
          printf 'pmctl context query: --domain requires a value\n' >&2
          return 2
        fi
        domain="$2"
        shift 2
        ;;
      --domain=*)
        domain="${1#--domain=}"
        shift
        ;;
      --source)
        if [[ $# -lt 2 ]]; then
          printf 'pmctl context query: --source requires a value\n' >&2
          return 2
        fi
        source="$2"
        shift 2
        ;;
      --source=*)
        source="${1#--source=}"
        shift
        ;;
      --)
        shift
        if [[ $# -gt 0 ]]; then
          query="$1"
          shift
        fi
        break
        ;;
      -*)
        printf 'pmctl context query: unknown flag %s\n' "$1" >&2
        return 2
        ;;
      *)
        query="$1"
        shift
        break
        ;;
    esac
  done

  if [[ -n "$domain" && "$domain" != "knowledge" && "$domain" != "repo" ]]; then
    printf 'pmctl context query: --domain must be "knowledge" or "repo" (got: %s)\n' "$domain" >&2
    return 2
  fi

  case "$source" in
    repo|memory|all) ;;
    *)
      printf 'pmctl context query: --source must be "repo", "memory", or "all" (got: %s)\n' "$source" >&2
      return 2
      ;;
  esac

  # --domain is a repo-plane path classifier; the memory plane has no
  # knowledge/repo subclasses, so the two flags are mutually exclusive there.
  if [[ -n "$domain" && "$source" != "repo" ]]; then
    printf 'pmctl context query: --domain is only valid with --source repo (got --source %s)\n' "$source" >&2
    return 2
  fi

  if [[ -z "$query" ]]; then
    printf 'pmctl context query: query string required\n' >&2
    return 2
  fi

  local db
  db="$(_ctx_db_path "$repo_root")"
  # Repo-plane freshness (repo & all). Memory-plane freshness is handled inside
  # _ctx_query_sources_raw so a memory-only query never depends on the repo DB.
  if [[ "$source" == "repo" || "$source" == "all" ]]; then
    _ctx_ensure_fresh "$repo_root" || true
  fi

  # Pure-repo source keeps its exact legacy short-circuit: no index yet is a
  # graceful zero-hit, NOT a sqlite error.
  if [[ "$source" == "repo" && ! -f "$db" ]]; then
    printf '# no hits for: %s\n' "$query"
    # No index yet is still a query: emit a zero-hit event so usage telemetry
    # captures it and the "emits after each call" contract holds uniformly.
    _ctx_emit_usage_event "context.queried" "$repo_root" "$query" 0
    return 0
  fi

  if ! _ctx_sqlite3_check; then
    # Repo source with an existing DB but no sqlite is a hard error (legacy).
    # memory/all degrade to graceful empty: no plane can be searched without it.
    if [[ "$source" == "repo" ]]; then
      printf 'pmctl context query: sqlite3 not found on PATH\n' >&2
      return 1
    fi
    printf '# no hits for: %s\n' "$query"
    _ctx_emit_usage_event "context.queried" "$repo_root" "$query" 0
    return 0
  fi

  # CC-505 Req 2/3: collect the raw candidate set into one file and rank it
  # through the single shared path (_ctx_rank_hits) instead of emitting hits
  # in whatever order _ctx_query_sources_raw's plane fan-out happened to
  # produce them. No dedup here (unchanged from before this ranking work) --
  # a ref can legitimately appear twice, once as a symbol hit and once as a
  # text hit.
  local raw_tsv ranked_tsv
  raw_tsv="$(mktemp /tmp/ctx-query-raw-XXXXXX)"
  ranked_tsv="$(mktemp /tmp/ctx-query-ranked-XXXXXX)"
  # shellcheck disable=SC2064
  trap "rm -f '$raw_tsv' '$ranked_tsv'" EXIT
  _ctx_query_sources_raw "$repo_root" "$query" "$domain" "$source" 2>/dev/null > "$raw_tsv"
  _ctx_rank_hits "$raw_tsv" 0 > "$ranked_tsv"

  local hits=0 first=1
  while IFS=$'\t' read -r rank ref hit_domain why conf trust match_kind line_end score components; do
    [[ -n "$ref" ]] || continue
    [[ "$first" -eq 0 ]] && printf '\n'
    first=0
    _ctx_emit_hit "$ref" "$hit_domain" "$why" "$conf" "$trust" \
      "$rank" "$match_kind" "$line_end" "$score" "$components"
    hits=$((hits + 1))
  done < "$ranked_tsv"

  if [[ "$hits" -eq 0 ]]; then
    printf '# no hits for: %s\n' "$query"
  fi
  _ctx_emit_usage_event "context.queried" "$repo_root" "$query" "$hits"
  return 0
}

# ── Memory-plane pack accumulator (pointer-only) ──────────────────────────────
# Appends memory hits to mem_tsv. PRIVACY (load-bearing): pointer-only — the
# matched card body / snippet is NEVER copied into the pack (which is
# repo-bound and may be archived). Only the ref + trust tier travel.
# Does not dedup by ref here -- see _ctx_parse_query_tsv's comment
# (critic-F001): dedup happens post-sort in _ctx_rank_hits, not here.
_ctx_pack_memory_tsv() {
  local repo_root="$1" memory_db="$2" term="$3" mem_tsv="$4"
  while IFS=$'\t' read -r ref hit_domain why conf trust match_kind line_end score components; do
    [[ -n "$ref" ]] || continue
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$ref" "memory" "memory match" "$conf" "$trust" "$match_kind" "$line_end" "$score" "$components" >> "$mem_tsv"
  done < <(_ctx_query_hits_raw "$repo_root" "$term" "" "$memory_db" "memory" 2>/dev/null)
}

# ── pmctl_context_pack ────────────────────────────────────────────────────────
#
# Assembles multiple index queries into a JSON context-pack (schema v2).
# Symbol-name hits (why_relevant starts "symbol:") go into symbols[];
# chunk/FTS hits go into files[]; memory-plane hits go into memories[]
# (pointer-only). Refs are deduplicated across all queries.
# --source repo|memory|all selects the plane(s); default repo (memories[] = []).
#
# CLI: pmctl context pack [<repo_root>] --task-id <id> [--query <term>] ... [--source repo|memory|all]

pmctl_context_pack() {
  local repo_root=""
  local task_id=""
  local source="repo"
  local terms=()
  # CC-505 Req 5: a global item + byte budget across every --query term,
  # with truncation disclosed in the pack's own output (never a silent
  # shrink a caller has to notice by diffing byte counts). Defaults are a
  # generous safety ceiling, not a tight practical limit -- callers that
  # want a tighter budget for their own use (e.g. pmctl-pm.sh's 6000-byte
  # memory-context cap) still apply that themselves; this is the ceiling
  # that stops an unbounded multi-term query from growing without limit.
  local max_items="${PM_DISPATCH_CONTEXT_PACK_MAX_ITEMS:-200}"
  local max_bytes="${PM_DISPATCH_CONTEXT_PACK_MAX_BYTES:-200000}"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --task-id)
        if [[ $# -lt 2 ]]; then
          printf 'pmctl context pack: --task-id requires a value\n' >&2
          return 2
        fi
        task_id="$2"
        shift 2
        ;;
      --query)
        if [[ $# -lt 2 ]]; then
          printf 'pmctl context pack: --query requires a value\n' >&2
          return 2
        fi
        if [[ -z "$2" ]] || [[ "$2" =~ ^[[:space:]]+$ ]]; then
          printf 'pmctl context pack: --query value must not be empty\n' >&2
          return 2
        fi
        terms+=("$2")
        shift 2
        ;;
      --source)
        if [[ $# -lt 2 ]]; then
          printf 'pmctl context pack: --source requires a value\n' >&2
          return 2
        fi
        source="$2"
        shift 2
        ;;
      --source=*)
        source="${1#--source=}"
        shift
        ;;
      --max-items)
        if [[ $# -lt 2 || ! "$2" =~ ^[1-9][0-9]{0,14}$ ]]; then
          printf 'pmctl context pack: --max-items requires a positive integer (up to 15 digits)\n' >&2
          return 2
        fi
        max_items="$2"
        shift 2
        ;;
      --max-bytes)
        if [[ $# -lt 2 || ! "$2" =~ ^[1-9][0-9]{0,14}$ ]]; then
          printf 'pmctl context pack: --max-bytes requires a positive integer (up to 15 digits)\n' >&2
          return 2
        fi
        max_bytes="$2"
        shift 2
        ;;
      -*)
        printf 'pmctl context pack: unknown flag %s\n' "$1" >&2
        return 2
        ;;
      *)
        if [[ -d "$1" ]]; then
          repo_root="$1"
        else
          printf 'pmctl context pack: %s: not a directory\n' "$1" >&2
          return 2
        fi
        shift
        ;;
    esac
  done
  # The env-var defaults above are not re-validated -- an ambient override
  # must not silently degrade this budget's shape. Fail closed instead of
  # feeding a malformed value into the jq/arithmetic below.
  # Bound the digit count (not just "positive integer") to a width that
  # never overflows Bash's signed 64-bit arithmetic used later in this
  # function's comparisons and loops (risk-reviewer-F001: an unbounded
  # digit string can wrap negative and produce misleading budget behavior).
  if [[ ! "$max_items" =~ ^[1-9][0-9]{0,14}$ ]]; then
    printf 'pmctl context pack: PM_DISPATCH_CONTEXT_PACK_MAX_ITEMS must be a positive integer up to 15 digits (got: %s)\n' "$max_items" >&2
    return 2
  fi
  if [[ ! "$max_bytes" =~ ^[1-9][0-9]{0,14}$ ]]; then
    printf 'pmctl context pack: PM_DISPATCH_CONTEXT_PACK_MAX_BYTES must be a positive integer up to 15 digits (got: %s)\n' "$max_bytes" >&2
    return 2
  fi

  if [[ -z "$repo_root" ]]; then
    repo_root="$(_ctx_default_repo_root)" || repo_root=""
  fi
  if [[ -z "$repo_root" ]]; then
    printf 'pmctl context pack: repo root required\n' >&2
    return 2
  fi
  if [[ -z "$task_id" ]] || [[ "$task_id" =~ ^[[:space:]]+$ ]]; then
    printf 'pmctl context pack: --task-id is required\n' >&2
    return 2
  fi
  if [[ ${#terms[@]} -eq 0 ]]; then
    printf 'pmctl context pack: at least one --query is required\n' >&2
    return 2
  fi
  case "$source" in
    repo|memory|all) ;;
    *)
      printf 'pmctl context pack: --source must be "repo", "memory", or "all" (got: %s)\n' "$source" >&2
      return 2
      ;;
  esac

  local db
  db="$(_ctx_db_path "$repo_root")"
  if [[ "$source" == "repo" || "$source" == "all" ]]; then
    _ctx_ensure_fresh "$repo_root" || true
  fi

  # Pure-repo source with no index keeps its legacy empty-pack shape, but
  # still routes through _ctx_apply_pack_budget -- the ONE place --max-bytes
  # is enforced/disclosed (critic-F001/architecture-reviewer-F001: an
  # impossible cap must fail closed here too, not just on the indexed path).
  if [[ "$source" == "repo" && ! -f "$db" ]]; then
    local ts empty_pack
    ts="$(_ctx_now_iso8601)"
    empty_pack="$(printf '{"schema_version":4,"task_id":%s,"built_ts":%s,"sources":[{"name":"builtin-index","version":"1"}],"files":[],"symbols":[],"memories":[],"risks":[]}' \
      "$(_ctx_json_str "$task_id")" "$(_ctx_json_str "$ts")")"
    _ctx_apply_pack_budget "$empty_pack" "$max_items" "$max_bytes"
    return $?
  fi

  if ! _ctx_sqlite3_check; then
    # Repo source is a hard error (legacy); memory/all degrade to an empty pack.
    if [[ "$source" == "repo" ]]; then
      printf 'pmctl context pack: sqlite3 not found on PATH\n' >&2
      return 1
    fi
    local ts empty_pack
    ts="$(_ctx_now_iso8601)"
    empty_pack="$(printf '{"schema_version":4,"task_id":%s,"built_ts":%s,"sources":[{"name":"builtin-index","version":"1"}],"files":[],"symbols":[],"memories":[],"risks":[]}' \
      "$(_ctx_json_str "$task_id")" "$(_ctx_json_str "$ts")")"
    _ctx_apply_pack_budget "$empty_pack" "$max_items" "$max_bytes"
    return $?
  fi

  local sym_tsv files_tsv mem_tsv repo_tsv repo_ranked sym_ranked files_ranked mem_ranked
  sym_tsv="$(mktemp /tmp/ctx-pack-sym-XXXXXX)"
  files_tsv="$(mktemp /tmp/ctx-pack-files-XXXXXX)"
  mem_tsv="$(mktemp /tmp/ctx-pack-mem-XXXXXX)"
  repo_tsv="$(mktemp /tmp/ctx-pack-repo-XXXXXX)"
  repo_ranked="$(mktemp /tmp/ctx-pack-repo-ranked-XXXXXX)"
  sym_ranked="$(mktemp /tmp/ctx-pack-sym-ranked-XXXXXX)"
  files_ranked="$(mktemp /tmp/ctx-pack-files-ranked-XXXXXX)"
  mem_ranked="$(mktemp /tmp/ctx-pack-mem-ranked-XXXXXX)"
  # shellcheck disable=SC2064
  trap "rm -f '$sym_tsv' '$files_tsv' '$mem_tsv' '$repo_tsv' '$repo_ranked' '$sym_ranked' '$files_ranked' '$mem_ranked'" EXIT

  if [[ "$source" == "repo" || "$source" == "all" ]]; then
    if [[ -f "$db" ]]; then
      for term in "${terms[@]}"; do
        _ctx_parse_query_tsv "$repo_root" "$term" "$sym_tsv" "$files_tsv"
      done
    fi
  fi

  if [[ "$source" == "memory" || "$source" == "all" ]]; then
    local mdir mdb
    mdir="$(_ctx_resolve_memory_dir "$repo_root")" || mdir=""
    if [[ -n "$mdir" ]]; then
      _ctx_ensure_fresh_memory "$mdir" || true
      mdb="$(_ctx_memory_db_path "$mdir")"
      if [[ -f "$mdb" ]]; then
        for term in "${terms[@]}"; do
          _ctx_pack_memory_tsv "$repo_root" "$mdb" "$term" "$mem_tsv"
        done
      fi
    fi
  fi

  # CC-505 Req 3: rank each accumulated set through the shared path before
  # converting to JSON, so item order reflects ranking_score rather than
  # per-term insertion order. dedup_by_ref=1: each set was accumulated
  # across every --query term, so the same ref can appear more than once;
  # keep only its highest-scoring occurrence (critic-F001). No truncation
  # here (item/byte budget is CC-505 Req 5, not this slice).
  #
  # symbols[] and files[] must dedup by ref against EACH OTHER too: the same
  # "path:line" ref can score as a symbol_exact/partial hit AND a fts5_content
  # hit (content_fts indexes symbol names alongside chunk text), and a caller
  # must never see the same ref counted in both arrays. Rank the merged repo
  # set once (so the winner is whichever match_kind actually scored higher),
  # then split by each surviving row's own match_kind -- never rank the two
  # arrays independently, which would let the same ref win a slot in both.
  cat "$sym_tsv" "$files_tsv" > "$repo_tsv"
  _ctx_rank_hits "$repo_tsv" 0 1 > "$repo_ranked"
  awk -F'\t' '$7 ~ /^symbol_/' "$repo_ranked" > "$sym_ranked"
  awk -F'\t' '$7 !~ /^symbol_/' "$repo_ranked" > "$files_ranked"
  _ctx_rank_hits "$mem_tsv" 0 1 > "$mem_ranked"

  local ts sym_arr files_arr mem_arr sources_arr
  ts="$(_ctx_now_iso8601)"
  sym_arr="$(_ctx_tsv_to_json_array "$sym_ranked")"
  files_arr="$(_ctx_tsv_to_json_array "$files_ranked")"
  mem_arr="$(_ctx_tsv_to_json_array "$mem_ranked")"

  # sources[] registers every producer cited by an item's `source` field. Add the
  # memory-index producer only when the pack actually carries memory hits, so the
  # registry stays consistent with item attribution (CC-403).
  sources_arr='[{"name":"builtin-index","version":"1"}]'
  if [[ "$mem_arr" != "[]" ]]; then
    sources_arr='[{"name":"builtin-index","version":"1"},{"name":"memory-index","version":"1"}]'
  fi

  local pack
  pack="$(printf '{"schema_version":4,"task_id":%s,"built_ts":%s,"sources":%s,"files":%s,"symbols":%s,"memories":%s,"risks":[]}' \
    "$(_ctx_json_str "$task_id")" "$(_ctx_json_str "$ts")" "$sources_arr" "$files_arr" "$sym_arr" "$mem_arr")"
  # CC-505 Req 5: global item + byte budget across every --query term,
  # applied once at the very end so it sees the fully merged, deduped,
  # ranked result -- never per-term or per-array, which would let each
  # term/array claim its own share of the budget instead of a true global
  # ceiling.
  _ctx_apply_pack_budget "$pack" "$max_items" "$max_bytes"
}

# ── pmctl_context_reuse_scan ──────────────────────────────────────────────────
#
# Takes a free-text description, extracts search terms via _ctx_extract_terms,
# queries the repo index for each term, and emits a reuse_candidates: YAML block
# suitable for pasting into a dispatch brief's context: field.
#
# CLI: pmctl context reuse-scan [<repo_root>] "<description>"

pmctl_context_reuse_scan() {
  local repo_root=""
  local desc=""
  local repo_root_set=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -*)
        printf 'pmctl context reuse-scan: unknown flag %s\n' "$1" >&2
        return 2
        ;;
      *)
        if [[ "$repo_root_set" -eq 0 && -d "$1" ]]; then
          repo_root="$1"
          repo_root_set=1
        elif [[ -z "$desc" ]]; then
          desc="$1"
        fi
        shift
        ;;
    esac
  done

  if [[ -z "$repo_root" ]]; then
    repo_root="$(_ctx_default_repo_root)" || repo_root=""
  fi
  if [[ -z "$repo_root" ]]; then
    printf 'pmctl context reuse-scan: repo root required\n' >&2
    return 2
  fi
  if [[ -z "$desc" ]]; then
    printf 'pmctl context reuse-scan: description required\n' >&2
    return 2
  fi
  local db
  db="$(_ctx_db_path "$repo_root")"
  _ctx_ensure_fresh "$repo_root" || true
  if [[ ! -f "$db" ]]; then
    printf 'reuse_candidates:\n'
    printf '  queried_at: %s\n' "$(_ctx_now_iso8601)"
    printf '  terms: []\n'
    printf '  hits: []\n'
    # Mirror the query path: a no-index reuse-scan still emits a zero-hit event.
    _ctx_emit_usage_event "context.reuse_scanned" "$repo_root" "$desc" 0
    return 0
  fi

  if ! _ctx_sqlite3_check; then
    printf 'pmctl context reuse-scan: sqlite3 not found on PATH\n' >&2
    return 1
  fi

  local terms=()
  while IFS= read -r term; do
    [[ -n "$term" ]] && terms+=("$term")
  done < <(_ctx_extract_terms "$desc")

  local terms_yaml
  if [[ ${#terms[@]} -eq 0 ]]; then
    terms_yaml="[]"
  else
    local _t=""
    for term in "${terms[@]}"; do
      [[ -n "$_t" ]] && _t="$_t, "
      _t="$_t$term"
    done
    terms_yaml="[$_t]"
  fi

  local sym_tsv files_tsv hits_tsv ranked_tsv
  sym_tsv="$(mktemp /tmp/ctx-reuse-sym-XXXXXX)"
  files_tsv="$(mktemp /tmp/ctx-reuse-files-XXXXXX)"
  hits_tsv="$(mktemp /tmp/ctx-reuse-hits-XXXXXX)"
  ranked_tsv="$(mktemp /tmp/ctx-reuse-ranked-XXXXXX)"
  # shellcheck disable=SC2064
  trap "rm -f '$sym_tsv' '$files_tsv' '$hits_tsv' '$ranked_tsv'" EXIT

  for term in "${terms[@]}"; do
    _ctx_parse_query_tsv "$repo_root" "$term" "$sym_tsv" "$files_tsv"
  done
  cat "$sym_tsv" "$files_tsv" > "$hits_tsv"
  # CC-505 Req 2/3: the merged candidate set is ranked by ranking_score
  # through the one shared path and truncated there -- this used to be
  # "symbol hits first, then text hits, take the first 5", which reflected
  # insertion order, not relevance. dedup_by_ref=1: accumulated across every
  # term, so keep only each ref's highest-scoring occurrence (critic-F001).
  _ctx_rank_hits "$hits_tsv" 5 1 > "$ranked_tsv"

  printf 'reuse_candidates:\n'
  printf '  queried_at: %s\n' "$(_ctx_now_iso8601)"
  printf '  terms: %s\n' "$terms_yaml"

  local total_hits=0
  [[ -s "$hits_tsv" ]] && total_hits="$(wc -l < "$hits_tsv" | tr -d ' ')"

  if [[ "$total_hits" -eq 0 ]]; then
    printf '  hits: []\n'
  else
    printf '  hits:\n'
    local first_hit=1
    while IFS=$'\t' read -r rank ref domain why conf trust match_kind line_end score components; do
      [[ "$first_hit" -eq 0 ]] && printf '\n'
      first_hit=0
      local safe_why="${why//$'\n'/ }"
      safe_why="${safe_why//\'/\'\'}"
      printf '    - ref: %s\n'              "$ref"
      printf '      source: builtin-index\n'
      printf '      source_domain: %s\n'    "$domain"
      printf "      why_relevant: '%s'\n"   "$safe_why"
      printf '      confidence: %s\n'       "$conf"
      printf '      trust_level: %s\n'      "$trust"
      printf '      rank: %s\n'             "$rank"
      printf '      match_kind: %s\n'       "$match_kind"
      printf '      ranking_score: %s\n'    "$score"
    done < "$ranked_tsv"
  fi

  local reported_hits="$total_hits"
  [[ "$reported_hits" -gt 5 ]] && reported_hits=5
  _ctx_emit_usage_event "context.reuse_scanned" "$repo_root" "$desc" "$reported_hits"
}

# ── pmctl_context_prompt_scan ─────────────────────────────────────────────────
#
# Takes a free-text prompt, extracts search terms via _ctx_extract_terms,
# queries the repo index knowledge domain (BACKLOG/DECISIONS/MILESTONES/docs)
# for each term, and emits a compact pointer-only knowledge_hits: YAML block
# for prompt-time injection (consumed by hosts/claude/hooks/inject-context.sh).
#
# Emits a context.prompt_scanned usage event — deliberately distinct from
# context.queried, so automated prompt-time scans never pollute the telemetry
# signal for whether an agent queried the index on its own.
#
# Terms are ranked longest-first (longer terms are more distinctive) and capped
# at PM_DISPATCH_PROMPT_SCAN_MAX_TERMS (default 8) to bound per-prompt latency.
#
# CLI: pmctl context prompt-scan [<repo_root>] "<prompt text>"

pmctl_context_prompt_scan() {
  local repo_root=""
  local prompt=""
  local repo_root_set=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -*)
        printf 'pmctl context prompt-scan: unknown flag %s\n' "$1" >&2
        return 2
        ;;
      *)
        if [[ "$repo_root_set" -eq 0 && -d "$1" ]]; then
          repo_root="$1"
          repo_root_set=1
        elif [[ -z "$prompt" ]]; then
          prompt="$1"
        fi
        shift
        ;;
    esac
  done

  if [[ -z "$repo_root" ]]; then
    repo_root="$(_ctx_default_repo_root)" || repo_root=""
  fi
  if [[ -z "$repo_root" ]]; then
    printf 'pmctl context prompt-scan: repo root required\n' >&2
    return 2
  fi
  if [[ -z "$prompt" ]]; then
    printf 'pmctl context prompt-scan: prompt text required\n' >&2
    return 2
  fi

  local max_terms="${PM_DISPATCH_PROMPT_SCAN_MAX_TERMS:-8}"
  [[ "$max_terms" =~ ^[0-9]+$ ]] || max_terms=8

  # PRIVACY (load-bearing): prompts arrive from an automated hook and can carry
  # secrets or PII — and even derived terms can reproduce a secret-shaped token
  # verbatim. Every context.prompt_scanned event below therefore persists an
  # EMPTY query payload: no raw prompt, no derived terms, nothing prompt-derived
  # reaches the durable state store. Only the hit count is recorded.
  local terms=()
  while IFS= read -r term; do
    [[ -n "$term" ]] && terms+=("$term")
  done < <(_ctx_extract_terms "$prompt" \
    | awk '{ printf "%05d\t%s\n", length($0), $0 }' \
    | sort -t$'\t' -k1,1r -k2,2 \
    | cut -f2 \
    | head -n "$max_terms")

  local db
  db="$(_ctx_db_path "$repo_root")"
  _ctx_ensure_fresh "$repo_root" || true
  if [[ ! -f "$db" ]]; then
    printf 'knowledge_hits: []\n'
    # Mirror the query/reuse-scan paths: a no-index scan still emits a zero-hit
    # event so the "emits after each call" contract holds uniformly.
    _ctx_emit_usage_event "context.prompt_scanned" "$repo_root" "" 0
    return 0
  fi

  if ! _ctx_sqlite3_check; then
    # Graceful degradation, NOT a hard error: this command is driven by an
    # automated prompt hook, so a missing sqlite3 must degrade to an empty
    # scan (plus the uniform zero-hit event) rather than surfacing a failure
    # on every prompt.
    printf 'knowledge_hits: []\n'
    _ctx_emit_usage_event "context.prompt_scanned" "$repo_root" "" 0
    return 0
  fi

  local sym_tsv files_tsv hits_tsv ranked_tsv
  sym_tsv="$(mktemp /tmp/ctx-prompt-sym-XXXXXX)"
  files_tsv="$(mktemp /tmp/ctx-prompt-files-XXXXXX)"
  hits_tsv="$(mktemp /tmp/ctx-prompt-hits-XXXXXX)"
  ranked_tsv="$(mktemp /tmp/ctx-prompt-ranked-XXXXXX)"
  # shellcheck disable=SC2064
  trap "rm -f '$sym_tsv' '$files_tsv' '$hits_tsv' '$ranked_tsv'" EXIT

  for term in "${terms[@]+"${terms[@]}"}"; do
    _ctx_parse_query_tsv "$repo_root" "$term" "$sym_tsv" "$files_tsv" "knowledge"
  done
  cat "$files_tsv" "$sym_tsv" > "$hits_tsv"
  # CC-505 Req 2/3: same shared ranking path as query/pack/reuse-scan --
  # previously "text hits first, then symbol hits, take the first 5".
  # dedup_by_ref=1: accumulated across every term (critic-F001).
  _ctx_rank_hits "$hits_tsv" 5 1 > "$ranked_tsv"

  local total_hits=0
  [[ -s "$hits_tsv" ]] && total_hits="$(wc -l < "$hits_tsv" | tr -d ' ')"

  if [[ "$total_hits" -eq 0 ]]; then
    printf 'knowledge_hits: []\n'
  else
    printf 'knowledge_hits:\n'
    while IFS=$'\t' read -r _rank ref _domain why _conf _trust _match_kind _line_end _score _components; do
      local safe_why="${why//$'\n'/ }"
      safe_why="${safe_why//\'/\'\'}"
      printf '  - ref: %s\n'            "$ref"
      printf "    why_relevant: '%s'\n" "$safe_why"
    done < "$ranked_tsv"
  fi

  local reported_hits="$total_hits"
  [[ "$reported_hits" -gt 5 ]] && reported_hits=5
  # Empty query payload — see the privacy note above; nothing prompt-derived.
  _ctx_emit_usage_event "context.prompt_scanned" "$repo_root" "" "$reported_hits"
}
