#!/usr/bin/env bash
# pmctl-context.sh — builtin repo-index commands: index / update / query.
# Sources state-writer.sh for path resolution (_sw_store_root / _sw_project_key) only.
# Does NOT call serialize_with_lock; index DB is a derived cache — SQLite WAL provides concurrency guarantees.
# MUST NOT source pmctl-dispatch.sh or any adapter module.

_CTX_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source state-writer.sh (which pulls in portable.sh) for path helpers.
if [[ "$(type -t _sw_store_root 2>/dev/null)" != function ]]; then
  # shellcheck source=scripts/lib/state-writer.sh
  # shellcheck disable=SC1091
  . "$_CTX_LIB_DIR/state-writer.sh" 2>/dev/null || true
fi

# ── Path resolution ────────────────────────────────────────────────────────────

_ctx_db_path() {
  local repo_root="$1"
  local store_root proj_key
  store_root="$(_sw_store_root)"
  # Subshell export avoids polluting the caller's environment.
  proj_key="$(export _SW_REPO_ROOT="$repo_root"; _sw_project_key)"
  printf '%s/projects/%s/repo-index.db\n' "$store_root" "$proj_key"
}

# ── SQLite availability ────────────────────────────────────────────────────────

_ctx_sqlite3_check() {
  command -v sqlite3 >/dev/null 2>&1
}

# Probe FTS5 support by creating and immediately dropping a test virtual table.
# Returns 0 if FTS5 is available, 1 otherwise.
_ctx_fts5_available() {
  local db="$1"
  if sqlite3 "$db" "CREATE VIRTUAL TABLE IF NOT EXISTS _fts5_probe USING fts5(x);" 2>/dev/null; then
    sqlite3 "$db" "DROP TABLE IF EXISTS _fts5_probe;" 2>/dev/null || true
    return 0
  fi
  return 1
}

# ── Database schema ────────────────────────────────────────────────────────────

_ctx_db_init() {
  local db="$1"
  # Redirect stdout: `PRAGMA journal_mode=WAL` echoes the resulting mode ("wal")
  # which would otherwise leak into `pmctl context index` output.
  sqlite3 "$db" >/dev/null <<'SQLINIT'
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
# Truncates to 2000 chars to keep SQL statements manageable.
_ctx_sql_str() {
  local s="${1:0:2000}"
  printf '%s' "${s//\'/\'\'}"
}

# ── context_hit_v1 YAML emitter ───────────────────────────────────────────────
#
# Single entry point for emitting context_hit_v1 YAML blocks.
# Sanitizes why_relevant to produce valid YAML single-quoted scalars:
# strips newlines/CRs, escapes single quotes by doubling.

_ctx_emit_hit() {
  local ref="$1" source_domain="$2" why_relevant="$3" confidence="$4" trust_level="$5"
  local safe_why="${why_relevant//$'\n'/ }"
  safe_why="${safe_why//$'\r'/ }"
  safe_why="${safe_why//\'/\'\'}"
  printf -- '- ref: %s\n'         "$ref"
  printf    '  source: builtin-index\n'
  printf    '  source_domain: %s\n'  "$source_domain"
  printf    "  why_relevant: '%s'\n" "$safe_why"
  printf    '  confidence: %s\n'     "$confidence"
  printf    '  trust_level: %s\n'    "$trust_level"
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
# Each outputs TSV rows: heading<TAB>line_start<TAB>line_end<TAB>lead
# lead is the first non-empty body content after the heading, capped at 200 chars.

_ctx_chunk_markdown() {
  local abs_path="$1"
  local line lineno=1 in_fence=0 saw_heading=0
  local cur_heading="" cur_start=0 cur_lead="" lead_done=0

  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" =~ ^\`\`\` ]]; then
      in_fence=$((1 - in_fence))
    fi

    if [[ "$in_fence" -eq 0 && "$line" =~ ^(#{1,6})[[:space:]](.+) ]]; then
      if [[ "$cur_start" -gt 0 ]]; then
        printf '%s\t%s\t%s\t%s\n' "$cur_heading" "$cur_start" "$((lineno - 1))" "$cur_lead"
      fi
      saw_heading=1
      cur_heading="${BASH_REMATCH[2]}"
      cur_start="$lineno"
      cur_lead=""
      lead_done=0
    elif [[ "$cur_start" -gt 0 && "$lead_done" -eq 0 && -n "$line" ]]; then
      cur_lead="${cur_lead:+$cur_lead }${line:0:200}"
      cur_lead="${cur_lead:0:200}"
      [[ "${#cur_lead}" -ge 200 ]] && lead_done=1
    fi

    lineno=$((lineno + 1))
  done < "$abs_path"

  if [[ "$cur_start" -gt 0 ]]; then
    printf '%s\t%s\t%s\t%s\n' "$cur_heading" "$cur_start" "$((lineno - 1))" "$cur_lead"
  fi

  if [[ "$saw_heading" -eq 0 ]]; then
    local total lead
    total="$(wc -l < "$abs_path" 2>/dev/null | tr -d ' ' || printf '0')"
    lead="$(head -c 200 "$abs_path" 2>/dev/null | tr '\n' ' ' | cut -c1-200 || true)"
    printf '%s\t%s\t%s\t%s\n' "" 1 "$total" "$lead"
  fi
}

_ctx_chunk_window() {
  local abs_path="$1" window_size="${2:-40}"
  local total line lineno=1 win_start=1 win_lead="" lead_done=0

  total="$(wc -l < "$abs_path" 2>/dev/null | tr -d ' ' || printf '0')"
  [[ "$total" -eq 0 ]] && return 0

  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$lead_done" -eq 0 && -n "$line" ]]; then
      win_lead="${win_lead:+$win_lead }${line:0:200}"
      win_lead="${win_lead:0:200}"
      [[ "${#win_lead}" -ge 200 ]] && lead_done=1
    fi

    if [[ $((lineno - win_start + 1)) -ge "$window_size" || "$lineno" -ge "$total" ]]; then
      printf '%s\t%s\t%s\t%s\n' "" "$win_start" "$lineno" "$win_lead"
      win_start=$((lineno + 1))
      win_lead=""
      lead_done=0
    fi
    lineno=$((lineno + 1))
  done < "$abs_path"
}

_ctx_chunk_file() {
  local abs_path="$1" lang="$2"
  case "$lang" in
    markdown)
      _ctx_chunk_markdown "$abs_path"
      ;;
    text|json|yaml)
      _ctx_chunk_window "$abs_path" 40
      ;;
    *)
      local total lead
      total="$(wc -l < "$abs_path" 2>/dev/null | tr -d ' ' || printf '0')"
      lead="$(head -c 200 "$abs_path" 2>/dev/null | tr '\n' ' ' | cut -c1-200 || true)"
      printf '%s\t%s\t%s\t%s\n' "" 1 "$total" "$lead"
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
    en="$(_ctx_sql_str "$sym_name")"
    ek="$(_ctx_sql_str "$sym_kind")"
    esig="$(_ctx_sql_str "${sym_sig:-}")"
    printf "INSERT INTO symbols(file_id,name,kind,language,line_start,line_end,signature,backend,confidence)\n"
    printf "  VALUES((SELECT id FROM files WHERE path='%s'),'%s','%s','%s',%s,%s,'%s','regex',0.8);\n" \
      "$ep" "$en" "$ek" "$lang" "$sym_line" "$sym_line" "$esig"
  done < <(_ctx_extract_symbols "$abs_path" "$lang")

  local chunk_row tab=$'\t'
  local ch_heading ch_start ch_end ch_lead rest eh el chunk_sha1
  while IFS= read -r chunk_row; do
    ch_heading="${chunk_row%%"$tab"*}"
    rest="${chunk_row#*"$tab"}"
    ch_start="${rest%%"$tab"*}"
    rest="${rest#*"$tab"}"
    ch_end="${rest%%"$tab"*}"
    ch_lead="${rest#*"$tab"}"
    eh="$(_ctx_sql_str "$ch_heading")"
    el="$(_ctx_sql_str "$ch_lead")"
    chunk_sha1="$(printf '%s\t%s' "$ch_heading" "$ch_lead" \
      | _portable_sha1 2>/dev/null || printf 'unknown')"
    printf "INSERT INTO file_chunks(file_id,heading,line_start,line_end,text,sha1)\n"
    printf "  VALUES((SELECT id FROM files WHERE path='%s'),'%s',%s,%s,'%s','%s');\n" \
      "$ep" "$eh" "$ch_start" "$ch_end" "$el" "$chunk_sha1"
  done < <(_ctx_chunk_file "$abs_path" "$lang")
}

# ── Single-file index (used by pmctl_context_update) ──────────────────────────

_ctx_index_file() {
  local db="$1" abs_path="$2" rel_path="$3"
  local tmpf
  tmpf="$(mktemp /tmp/ctx-XXXXXX.sql)"
  {
    printf 'BEGIN;\n'
    _ctx_generate_file_sql "$abs_path" "$rel_path"
    printf 'COMMIT;\n'
  } > "$tmpf"
  sqlite3 "$db" < "$tmpf"
  rm -f "$tmpf"
}

# ── FTS5 index rebuild ─────────────────────────────────────────────────────────

_ctx_fts_rebuild() {
  local db="$1"
  _ctx_fts5_available "$db" || return 0

  sqlite3 "$db" <<'SQLFTS'
DROP TABLE IF EXISTS content_fts;
CREATE VIRTUAL TABLE content_fts USING fts5(ref, text);
INSERT INTO content_fts(ref, text)
  SELECT f.path || ':' || s.line_start, s.name
  FROM symbols s JOIN files f ON s.file_id = f.id;
INSERT INTO content_fts(ref, text)
  SELECT f.path || ':' || fc.line_start, TRIM(COALESCE(fc.heading, '') || ' ' || COALESCE(fc.text, ''))
  FROM file_chunks fc JOIN files f ON fc.file_id = f.id
  WHERE TRIM(COALESCE(fc.heading, '') || ' ' || COALESCE(fc.text, '')) != '';
SQLFTS
}

# ── pmctl_context_index ────────────────────────────────────────────────────────

pmctl_context_index() {
  local repo_root
  if [[ $# -gt 0 && -d "${1:-}" ]]; then
    repo_root="$1"; shift
  else
    repo_root="${REPO_ROOT:-}"
  fi
  if [[ -z "$repo_root" ]]; then
    printf 'pmctl context index: repo root required\n' >&2
    return 2
  fi

  local source_flag="repo"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --source)
        source_flag="${2:-}"
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

  if [[ "$source_flag" != "repo" ]]; then
    printf 'pmctl context index: unsupported --source value: %s (only "repo" supported)\n' \
      "$source_flag" >&2
    return 2
  fi

  if ! _ctx_sqlite3_check; then
    printf 'pmctl context index: sqlite3 not found on PATH\n' >&2
    return 1
  fi

  local db
  db="$(_ctx_db_path "$repo_root")"
  mkdir -p "$(dirname "$db")"
  _ctx_db_init "$db"

  # Batch-load all known mtimes in one query to avoid one sqlite3 subprocess per file.
  declare -A _ctx_db_mtimes=()
  local _p _m
  while IFS='|' read -r _p _m; do
    [[ -n "$_p" ]] && _ctx_db_mtimes["$_p"]="$_m"
  done < <(sqlite3 "$db" "SELECT path, mtime FROM files;" 2>/dev/null | tr -d '\r' || true)

  # Batch SQL for all changed files into one transaction (1 sqlite3 call vs. N).
  # A temp table _cur_paths tracks every path present in the current scan so that
  # rows for deleted files can be removed in the same transaction (reconciliation).
  local batch_sql
  batch_sql="$(mktemp /tmp/ctx-XXXXXX.sql)"
  printf 'BEGIN;\n' > "$batch_sql"
  printf 'CREATE TEMP TABLE _cur_paths(path TEXT PRIMARY KEY);\n' >> "$batch_sql"

  local indexed=0 skipped=0
  while IFS= read -r abs_path; do
    [[ -f "$abs_path" ]] || continue
    local rel_path="${abs_path#"$repo_root/"}"
    local ep
    ep="$(_ctx_sql_str "$rel_path")"

    # Track every found path for stale-row reconciliation (before mtime skip).
    printf "INSERT OR IGNORE INTO _cur_paths(path) VALUES('%s');\n" "$ep" >> "$batch_sql"

    # Incremental contract: mtime-only skip. sha1 is stored for debugging but
    # is NOT used for change detection; content changes with a preserved mtime
    # will not trigger a re-index. This is the documented, tested semantics.
    local cur_mtime
    cur_mtime="$(_ctx_file_mtime "$abs_path")"
    if [[ "${_ctx_db_mtimes[$rel_path]+_}" == '_' && "${_ctx_db_mtimes[$rel_path]}" == "$cur_mtime" ]]; then
      skipped=$((skipped + 1))
      continue
    fi

    _ctx_generate_file_sql "$abs_path" "$rel_path" >> "$batch_sql"
    indexed=$((indexed + 1))
  done < <(find "$repo_root" \
      -not -path '*/.git/*' \
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
      \) 2>/dev/null | sort)

  # Reconcile deletions: remove rows for files no longer in the repo.
  {
    printf 'DELETE FROM symbols WHERE file_id IN (SELECT id FROM files WHERE path NOT IN (SELECT path FROM _cur_paths));\n'
    printf 'DELETE FROM file_chunks WHERE file_id IN (SELECT id FROM files WHERE path NOT IN (SELECT path FROM _cur_paths));\n'
    printf 'DELETE FROM files WHERE path NOT IN (SELECT path FROM _cur_paths);\n'
    printf 'COMMIT;\n'
  } >> "$batch_sql"

  # Always execute: even if nothing was indexed, reconciliation must run.
  sqlite3 "$db" < "$batch_sql"
  rm -f "$batch_sql"

  _ctx_fts_rebuild "$db"

  printf 'context index: %d indexed, %d skipped\n' "$indexed" "$skipped"
  printf 'db: %s\n' "$db"
}

# ── pmctl_context_update ───────────────────────────────────────────────────────

pmctl_context_update() {
  local repo_root
  if [[ $# -gt 0 && -d "${1:-}" ]]; then
    repo_root="$1"; shift
  else
    repo_root="${REPO_ROOT:-}"
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
# events.jsonl via the already-sourced state-writer.  Any failure is silent —
# the main query/reuse-scan operation must not be affected.

_ctx_emit_usage_event() {
  local kind="$1" query_term="$3" hit_count="${4:-0}"
  declare -F events_append >/dev/null 2>&1 || return 0
  declare -F state_store_init >/dev/null 2>&1 || return 0
  # Events are written to the pmctl installation partition (same as pmctl trace
  # tail reads from), not the indexed target-repo partition.
  local pmctl_root ts stamp hex6 evt_id event_json
  pmctl_root="$(cd "$_CTX_LIB_DIR/../.." && pwd)"
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date +%Y-%m-%dT%H:%M:%SZ)"
  stamp="$(date -u +%Y%m%dT%H%M%SZ 2>/dev/null || date +%Y%m%dT%H%M%SZ)"
  hex6="$(dd if=/dev/urandom bs=3 count=1 2>/dev/null | od -An -tx1 | tr -d ' \n')"
  hex6="${hex6:0:6}"
  [[ -n "$hex6" ]] || return 0
  evt_id="evt-${stamp}-${hex6}"
  event_json="$(jq -cn \
    --arg id     "$evt_id" \
    --arg ts     "$ts" \
    --arg kind   "$kind" \
    --arg query  "$query_term" \
    --argjson hits "$hit_count" \
    '{schema_version:1,id:$id,ts:$ts,kind:$kind,
      subject_type:"context",subject_id:("ctx-"+ $id),
      actor:"pmctl",
      payload:{query:$query,hits:$hits}}')" 2>/dev/null || return 0
  _SW_REPO_ROOT="$pmctl_root" events_append "$event_json" 2>/dev/null || true
}

# ── Term extraction from free-text description ────────────────────────────────
# Outputs unique lower-case terms (≥ 3 chars, not stop words), one per line.
# Isolated change seam — pmctl_context_pack and pmctl_context_reuse_scan
# must not inline this logic.

_ctx_extract_terms() {
  local desc="$1"
  local stopwords=" a an and are as at be been by do for from has have he in is it its of on or that the to was were will with "
  printf '%s\n' "$desc" \
    | tr '[:upper:]' '[:lower:]' \
    | tr -cs 'a-z0-9_' '\n' \
    | awk -v sw="$stopwords" 'length($0) >= 3 && index(sw, " " $0 " ") == 0' \
    | sort -u
}

# ── Raw query result emitter (internal only) ───────────────────────────────────
# Outputs TSV rows: ref<TAB>domain<TAB>why<TAB>conf<TAB>trust
# No deduplication — callers handle dedup and formatting.
# Single query-execution path shared by pmctl_context_query (YAML output)
# and _ctx_parse_query_tsv (pack / reuse-scan TSV accumulation).

_ctx_query_hits_raw() {
  local repo_root="$1" query="$2" domain="${3:-}"
  local db eq domain_sql=""
  db="$(_ctx_db_path "$repo_root")"
  eq="$(_ctx_sql_str "$query")"

  case "$domain" in
    knowledge)
      domain_sql=" AND (f.path IN ('BACKLOG.md','DECISIONS.md','MILESTONES.md') OR f.path LIKE 'docs/%')"
      ;;
    repo)
      domain_sql=" AND NOT (f.path IN ('BACKLOG.md','DECISIONS.md','MILESTONES.md') OR f.path LIKE 'docs/%')"
      ;;
  esac

  while IFS=$'\t' read -r path name kind line_start; do
    [[ -n "$path" ]] || continue
    local hit_domain
    hit_domain="$(_ctx_classify_domain "$path")"
    printf '%s\t%s\t%s\t%s\t%s\n' \
      "$path:$line_start" "$hit_domain" "symbol: $name ($kind)" "0.85" "high"
  done < <(sqlite3 -separator $'\t' "$db" \
    "SELECT f.path, s.name, s.kind, s.line_start
     FROM symbols s JOIN files f ON s.file_id=f.id
     WHERE s.name LIKE '%${eq}%'${domain_sql}
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
    printf "SELECT ref, replace(replace(text, char(10), ' '), char(13), ' ') FROM content_fts WHERE content_fts MATCH '\"%s\"' LIMIT 20;\n" \
      "$fts_query" > "$fts_tmpf"
    while IFS=$'\t' read -r ref text; do
      [[ -n "$ref" ]] || continue
      local fts_path fts_domain
      fts_path="${ref%:*}"
      fts_domain="$(_ctx_classify_domain "$fts_path")"
      if [[ -n "$domain" && "$fts_domain" != "$domain" ]]; then
        continue
      fi
      local snippet
      snippet="${text:0:80}"
      snippet="${snippet//$'\t'/ }"
      printf '%s\t%s\t%s\t%s\t%s\n' \
        "$ref" "$fts_domain" "fts5 match: $snippet" "0.75" "medium"
    done < <(sqlite3 -separator $'\t' "$db" < "$fts_tmpf" 2>/dev/null | tr -d '\r' || true)
    rm -f "$fts_tmpf"
  else
    while IFS=$'\t' read -r path line_start; do
      [[ -n "$path" ]] || continue
      local hit_domain
      hit_domain="$(_ctx_classify_domain "$path")"
      printf '%s\t%s\t%s\t%s\t%s\n' \
        "$path:$line_start" "$hit_domain" "text match in chunk" "0.7" "medium"
    done < <(sqlite3 -separator $'\t' "$db" \
      "SELECT f.path, fc.line_start
       FROM file_chunks fc JOIN files f ON fc.file_id=f.id
       WHERE (fc.text LIKE '%${eq}%' OR fc.heading LIKE '%${eq}%')${domain_sql}
       LIMIT 20;" 2>/dev/null | tr -d '\r' || true)
  fi
}

# ── Per-term query parser ──────────────────────────────────────────────────────
# Uses _ctx_query_hits_raw for structured TSV input; deduplicates by ref
# (appending to seen_file) and routes hits:
#   why starts with "symbol:" → sym_tsv
#   all others                → files_tsv

_ctx_parse_query_tsv() {
  local repo_root="$1" term="$2" seen_file="$3" sym_tsv="$4" files_tsv="$5"
  local domain="${6:-}"
  while IFS=$'\t' read -r ref hit_domain why conf trust; do
    [[ -n "$ref" ]] || continue
    grep -qxF "$ref" "$seen_file" 2>/dev/null && continue
    printf '%s\n' "$ref" >> "$seen_file"
    if [[ "$why" == "symbol:"* ]]; then
      printf '%s\t%s\t%s\t%s\t%s\n' "$ref" "$hit_domain" "$why" "$conf" "$trust" >> "$sym_tsv"
    else
      printf '%s\t%s\t%s\t%s\t%s\n' "$ref" "$hit_domain" "$why" "$conf" "$trust" >> "$files_tsv"
    fi
  done < <(_ctx_query_hits_raw "$repo_root" "$term" "$domain" 2>/dev/null)
}

# ── TSV-to-JSON array assembler ────────────────────────────────────────────────
# Reads ref<TAB>domain<TAB>why<TAB>conf<TAB>trust rows and emits a JSON array
# of context_hit_v1 objects. Missing or empty file → "[]".

_ctx_tsv_to_json_array() {
  local tsv_file="$1"
  if [[ ! -f "$tsv_file" || ! -s "$tsv_file" ]]; then
    printf '[]'
    return
  fi
  local first=1
  printf '['
  while IFS=$'\t' read -r ref domain why conf trust; do
    [[ "$first" -eq 0 ]] && printf ','
    first=0
    printf '{"ref":%s,"source":"builtin-index","confidence":%s,"source_domain":%s,"why_relevant":%s,"trust_level":%s}' \
      "$(_ctx_json_str "$ref")" "$conf" \
      "$(_ctx_json_str "$domain")" \
      "$(_ctx_json_str "$why")" \
      "$(_ctx_json_str "$trust")"
  done < "$tsv_file"
  printf ']'
}

# ── pmctl_context_query ────────────────────────────────────────────────────────
#
# Searches the repo index and outputs context_hit_v1 YAML blocks.
# FTS5 path: uses content_fts virtual table (MATCH) for full-text search.
# LIKE fallback: searches symbols.name and file_chunks.text with LIKE.
# Either path also searches symbols.name with LIKE for reliable symbol lookup.

pmctl_context_query() {
  local repo_root
  if [[ $# -gt 0 && -d "${1:-}" ]]; then
    repo_root="$1"; shift
  else
    repo_root="${REPO_ROOT:-}"
  fi
  if [[ -z "$repo_root" ]]; then
    printf 'pmctl context query: repo root required\n' >&2
    return 2
  fi

  local query="" domain=""
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

  if [[ -z "$query" ]]; then
    printf 'pmctl context query: query string required\n' >&2
    return 2
  fi

  if ! _ctx_sqlite3_check; then
    printf 'pmctl context query: sqlite3 not found on PATH\n' >&2
    return 1
  fi

  local db
  db="$(_ctx_db_path "$repo_root")"
  if [[ ! -f "$db" ]]; then
    printf 'pmctl context query: index not found; run pmctl context index first\n' >&2
    return 1
  fi

  local hits=0 first=1
  while IFS=$'\t' read -r ref hit_domain why conf trust; do
    [[ -n "$ref" ]] || continue
    [[ "$first" -eq 0 ]] && printf '\n'
    first=0
    _ctx_emit_hit "$ref" "$hit_domain" "$why" "$conf" "$trust"
    hits=$((hits + 1))
  done < <(_ctx_query_hits_raw "$repo_root" "$query" "$domain" 2>/dev/null)

  if [[ "$hits" -eq 0 ]]; then
    printf '# no hits for: %s\n' "$query"
  fi
  _ctx_emit_usage_event "context.queried" "$repo_root" "$query" "$hits"
  return 0
}

# ── pmctl_context_pack ────────────────────────────────────────────────────────
#
# Assembles multiple repo-index queries into a JSON context-pack (schema v2).
# Symbol-name hits (why_relevant starts "symbol:") go into symbols[];
# chunk/FTS hits go into files[]. Refs are deduplicated across all queries.
#
# CLI: pmctl context pack [<repo_root>] --task-id <id> [--query <term>] ...

pmctl_context_pack() {
  local repo_root="${REPO_ROOT:-}"
  local task_id=""
  local terms=()

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

  if [[ -z "$task_id" ]] || [[ "$task_id" =~ ^[[:space:]]+$ ]]; then
    printf 'pmctl context pack: --task-id is required\n' >&2
    return 2
  fi
  if [[ ${#terms[@]} -eq 0 ]]; then
    printf 'pmctl context pack: at least one --query is required\n' >&2
    return 2
  fi
  if ! _ctx_sqlite3_check; then
    printf 'pmctl context pack: sqlite3 not found on PATH\n' >&2
    return 1
  fi

  local db
  db="$(_ctx_db_path "$repo_root")"
  if [[ ! -f "$db" ]]; then
    printf 'pmctl context pack: index not found; run pmctl context index first\n' >&2
    return 1
  fi

  local seen_file sym_tsv files_tsv
  seen_file="$(mktemp /tmp/ctx-pack-seen-XXXXXX)"
  sym_tsv="$(mktemp /tmp/ctx-pack-sym-XXXXXX)"
  files_tsv="$(mktemp /tmp/ctx-pack-files-XXXXXX)"
  # shellcheck disable=SC2064
  trap "rm -f '$seen_file' '$sym_tsv' '$files_tsv'" EXIT

  for term in "${terms[@]}"; do
    _ctx_parse_query_tsv "$repo_root" "$term" "$seen_file" "$sym_tsv" "$files_tsv"
  done

  local ts sym_arr files_arr
  ts="$(_ctx_now_iso8601)"
  sym_arr="$(_ctx_tsv_to_json_array "$sym_tsv")"
  files_arr="$(_ctx_tsv_to_json_array "$files_tsv")"

  printf '{"schema_version":2,"task_id":%s,"built_ts":%s,"sources":[{"name":"builtin-index","version":"1"}],"files":%s,"symbols":%s,"memories":[],"risks":[]}\n' \
    "$(_ctx_json_str "$task_id")" "$(_ctx_json_str "$ts")" "$files_arr" "$sym_arr"
}

# ── pmctl_context_reuse_scan ──────────────────────────────────────────────────
#
# Takes a free-text description, extracts search terms via _ctx_extract_terms,
# queries the repo index for each term, and emits a reuse_candidates: YAML block
# suitable for pasting into a dispatch brief's context: field.
#
# CLI: pmctl context reuse-scan [<repo_root>] "<description>"

pmctl_context_reuse_scan() {
  local repo_root="${REPO_ROOT:-}"
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

  if [[ -z "$desc" ]]; then
    printf 'pmctl context reuse-scan: description required\n' >&2
    return 2
  fi
  if ! _ctx_sqlite3_check; then
    printf 'pmctl context reuse-scan: sqlite3 not found on PATH\n' >&2
    return 1
  fi

  local db
  db="$(_ctx_db_path "$repo_root")"
  if [[ ! -f "$db" ]]; then
    printf 'pmctl context reuse-scan: index not found; run pmctl context index first\n' >&2
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

  local seen_file sym_tsv files_tsv hits_tsv
  seen_file="$(mktemp /tmp/ctx-reuse-seen-XXXXXX)"
  sym_tsv="$(mktemp /tmp/ctx-reuse-sym-XXXXXX)"
  files_tsv="$(mktemp /tmp/ctx-reuse-files-XXXXXX)"
  hits_tsv="$(mktemp /tmp/ctx-reuse-hits-XXXXXX)"
  # shellcheck disable=SC2064
  trap "rm -f '$seen_file' '$sym_tsv' '$files_tsv' '$hits_tsv'" EXIT

  for term in "${terms[@]}"; do
    _ctx_parse_query_tsv "$repo_root" "$term" "$seen_file" "$sym_tsv" "$files_tsv"
  done
  cat "$sym_tsv" "$files_tsv" > "$hits_tsv"

  printf 'reuse_candidates:\n'
  printf '  queried_at: %s\n' "$(_ctx_now_iso8601)"
  printf '  terms: %s\n' "$terms_yaml"

  local total_hits=0
  [[ -s "$hits_tsv" ]] && total_hits="$(wc -l < "$hits_tsv" | tr -d ' ')"

  if [[ "$total_hits" -eq 0 ]]; then
    printf '  hits: []\n'
  else
    printf '  hits:\n'
    local first_hit=1 emitted=0
    while IFS=$'\t' read -r ref domain why conf trust; do
      [[ "$emitted" -ge 5 ]] && break
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
      emitted=$((emitted + 1))
    done < "$hits_tsv"
  fi

  local reported_hits="$total_hits"
  [[ "$reported_hits" -gt 5 ]] && reported_hits=5
  _ctx_emit_usage_event "context.reuse_scanned" "$repo_root" "$desc" "$reported_hits"
}
