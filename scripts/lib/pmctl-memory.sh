#!/usr/bin/env bash
# pmctl-memory.sh — project-memory health reporting (`pmctl memory doctor`).
#
# Source this file; do not execute directly. Provides pmctl_memory_doctor(): a
# read-only reporter over the project memory directory. It MUTATES nothing — no
# card writes, no enforce. Enforce + live-card backfill are sequenced follow-ups.
#
# Reuses find_memory_dir() from memory.sh (the base, non-routing variant) to
# locate the memory dir — it never re-walks paths itself and never sources
# memory-dir.sh (that variant adds the installer-only CLAUDE_ROUTING_LOG_DIR
# override that doctor must not inherit).

# shellcheck source=scripts/lib/memory.sh
# shellcheck disable=SC1091
. "$(dirname "${BASH_SOURCE[0]}")/memory.sh"

# Explicitly own the dispatch.memory_dir config dependency (not pmctl-dispatch.sh
# or an adapter module, so the "MUST NOT source adapters" rule does not apply)
# instead of relying on cli/pmctl's lib-load ordering having already sourced it.
if [[ "$(type -t pm_config_load 2>/dev/null)" != function ]]; then
  # shellcheck source=scripts/lib/pmctl-config.sh
  # shellcheck disable=SC1091
  . "$(dirname "${BASH_SOURCE[0]}")/pmctl-config.sh" 2>/dev/null || true
fi

# Stable project identity shared with the state substrate. The worktree-aware
# key keeps a main checkout and its linked worktrees in one project partition.
if [[ "$(type -t _sw_worktree_project_key 2>/dev/null)" != function ]]; then
  # shellcheck source=scripts/lib/state-paths.sh
  # shellcheck disable=SC1091
  . "$(dirname "${BASH_SOURCE[0]}")/state-paths.sh" 2>/dev/null || true
fi

# Loads ~/.pm-dispatch/config's dispatch.memory_dir into PM_CFG_MEMORY_DIR
# when no caller has already populated it.
_pmctl_memory_load_config_override() {
  declare -F pm_config_load >/dev/null 2>&1 && [[ -z "${PM_CFG_MEMORY_DIR:-}" ]] && pm_config_load
  return 0
}

# Print the memory directory for the given working directory (default: $PWD).
# Exit 1 (no output) if no memory directory is found.
pmctl_memory_dir() {
  local cwd="${1:-$PWD}"
  local mem_dir
  _pmctl_memory_load_config_override
  mem_dir="$(find_memory_dir "$cwd")" || return 1
  printf '%s\n' "$mem_dir"
}

_pmctl_memory_resolve_usage() {
  cat <<'EOF'
Usage: pmctl memory resolve [--repo-root <path>] [--json]

Resolve the canonical project-memory directory without silently falling back
from an explicitly configured but unavailable path.

Exit codes: 0 resolved, 1 unavailable, 2 usage error, 3 invalid explicit path.
EOF
}

_pmctl_memory_project_key() {
  local repo_root="$1"
  if declare -F _sw_worktree_project_key >/dev/null 2>&1; then
    _SW_REPO_ROOT="$repo_root" _sw_worktree_project_key
  else
    # Defensive fallback for standalone sourcing on a host missing the shared
    # state helpers. The canonical path remains deterministic and inspectable.
    printf '%s\n' "$repo_root"
  fi
}

_pmctl_memory_emit_resolution() {
  local json="$1" status="$2" repo_root="$3" project_key="$4" memory_dir="$5" source="$6" reason="$7"
  local readable=false writable=false
  [[ -n "$memory_dir" && -r "$memory_dir" ]] && readable=true
  [[ -n "$memory_dir" && -w "$memory_dir" ]] && writable=true
  if [[ "$json" -eq 1 ]]; then
    jq -cn \
      --arg status "$status" --arg repo_root "$repo_root" --arg project_key "$project_key" \
      --arg memory_dir "$memory_dir" --arg source "$source" --arg reason "$reason" \
      --argjson readable "$readable" --argjson writable "$writable" \
      '{schema_version:1,status:$status,repo_root:$repo_root,project_key:$project_key,memory_dir:(if $memory_dir == "" then null else $memory_dir end),resolution_source:$source,readable:$readable,writable:$writable,reason:(if $reason == "" then null else $reason end)}'
  else
    printf 'status: %s\nrepo_root: %s\nproject_key: %s\nresolution_source: %s\n' "$status" "$repo_root" "$project_key" "$source"
    [[ -n "$memory_dir" ]] && printf 'memory_dir: %s\nreadable: %s\nwritable: %s\n' "$memory_dir" "$readable" "$writable"
    [[ -n "$reason" ]] && printf 'reason: %s\n' "$reason"
  fi
}

# Strict, diagnostic resolver used at cross-host boundaries. Unlike the legacy
# find_memory_dir API, an explicit but unavailable override is an error: host
# switching must never appear successful while silently selecting other memory.
pmctl_memory_resolve() {
  # Use the caller's cwd, not cli/pmctl's install-root REPO_ROOT. An explicit
  # --repo-root still wins and is recommended for automation.
  local repo_root="$PWD" json=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --repo-root)
        [[ $# -ge 2 ]] || { printf 'pmctl memory resolve: --repo-root requires a value\n' >&2; return 2; }
        repo_root="$2"; shift 2 ;;
      --json) json=1; shift ;;
      -h|--help) _pmctl_memory_resolve_usage; return 0 ;;
      *) printf 'pmctl memory resolve: unknown argument: %s\n' "$1" >&2; return 2 ;;
    esac
  done

  repo_root="$(cd "$repo_root" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null)" || {
    printf 'pmctl memory resolve: --repo-root must be inside a git worktree\n' >&2
    return 2
  }
  local project_key memory_dir="" source="none" status="unavailable" reason="" rc=1
  project_key="$(_pmctl_memory_project_key "$repo_root")"
  _pmctl_memory_load_config_override

  if [[ -n "${PM_MEMORY_DIR:-}" ]]; then
    source="env"
    if [[ "${PM_MEMORY_DIR}" != /* ]]; then
      status="invalid-explicit"; reason="PM_MEMORY_DIR must be an absolute path"; rc=3
    elif [[ ! -d "${PM_MEMORY_DIR}" ]]; then
      status="invalid-explicit"; reason="PM_MEMORY_DIR does not exist or is not a directory"; rc=3
    else
      memory_dir="$(cd "${PM_MEMORY_DIR}" && pwd -P)"; status="resolved"; rc=0
    fi
  elif [[ "${PM_CFG_MEMORY_DIR_INVALID:-0}" -eq 1 ]]; then
    source="config"; status="invalid-explicit"; reason="dispatch.memory_dir must be an absolute path"; rc=3
  elif [[ -n "${PM_CFG_MEMORY_DIR:-}" ]]; then
    source="config"
    if [[ "${PM_CFG_MEMORY_DIR}" != /* ]]; then
      status="invalid-explicit"; reason="dispatch.memory_dir must be an absolute path"; rc=3
    elif [[ ! -d "${PM_CFG_MEMORY_DIR}" ]]; then
      status="invalid-explicit"; reason="dispatch.memory_dir does not exist or is not a directory"; rc=3
    else
      memory_dir="$(cd "${PM_CFG_MEMORY_DIR}" && pwd -P)"; status="resolved"; rc=0
    fi
  else
    # With no explicit override, retain the established Claude project-path
    # discovery as the compatibility default.
    if memory_dir="$(find_memory_dir "$repo_root")"; then
      memory_dir="$(cd "$memory_dir" && pwd -P)"
      source="legacy"; status="resolved"; rc=0
    fi
  fi

  _pmctl_memory_emit_resolution "$json" "$status" "$repo_root" "$project_key" "$memory_dir" "$source" "$reason"
  return "$rc"
}

_mem_json_esc() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  printf '%s' "$s"
}

# Portable byte size of a single file (0 if absent).
_mem_file_bytes() {
  local f="$1"
  [[ -f "$f" ]] || { printf '0'; return 0; }
  stat -c '%s' "$f" 2>/dev/null || stat -f '%z' "$f" 2>/dev/null || printf '0'
}

# Extract the repo_refs list items from a card's YAML frontmatter, one per line.
# Scoped to the `repo_refs:` block inside the first --- … --- fence only, so
# sibling list keys (e.g. topics:) are never captured.
_mem_card_repo_refs() {
  local card="$1"
  awk '
    /^---[[:space:]]*$/ { fm++; if (fm >= 2) exit; next }
    fm == 1 {
      # flow-style: repo_refs: [a, b] (also empty []). Split on commas; a
      # flag-ref may contain spaces but never a comma, so this is safe.
      if ($0 ~ /^repo_refs:[[:space:]]*\[.*\]/) {
        line = $0
        sub(/^repo_refs:[[:space:]]*\[/, "", line)
        sub(/\][[:space:]]*$/, "", line)
        n = split(line, items, ",")
        for (i = 1; i <= n; i++) {
          gsub(/^[[:space:]]+|[[:space:]]+$/, "", items[i])
          gsub(/^"|"$/, "", items[i])
          if (items[i] != "") print items[i]
        }
        inref = 0
        next
      }
      # block-style: repo_refs: then one "  - item" per line.
      if ($0 ~ /^repo_refs:[[:space:]]*$/) { inref = 1; next }
      if (inref && $0 ~ /^[[:space:]]+-[[:space:]]/) {
        sub(/^[[:space:]]+-[[:space:]]*/, "")
        sub(/[[:space:]]+$/, "")
        print
        next
      }
      if (inref && $0 ~ /^[^[:space:]]/) { inref = 0 }
    }
  ' "$card"
}

# Print the top-level frontmatter keys of a card (one per line), scoped to the
# first --- … --- fence. Nested map keys (indented) are not top-level and are
# excluded, so `metadata:` is reported but `metadata.node_type` is not.
_mem_card_top_keys() {
  local card="$1"
  awk '
    /^---[[:space:]]*$/ { fm++; if (fm >= 2) exit; next }
    fm == 1 && /^[A-Za-z_][A-Za-z0-9_-]*:/ {
      key = $0; sub(/:.*/, "", key); print key
    }
  ' "$card"
}

# True (0) when a repo-relative path is unsafe: absolute, or contains a `..`
# segment that could escape the repo root. The grammar is repo-root-relative
# only, so such a ref is invalid — callers treat it as stale, never fresh.
_mem_ref_path_unsafe() {
  local p="$1"
  [[ "$p" == /* ]] && return 0
  [[ "$p" =~ (^|/)\.\.(/|$) ]] && return 0
  return 1
}

# Verdict on a single repo_ref. Returns 0 when STALE, 1 when fresh.
# Grammar (see docs/memory-system.md → repo_refs grammar):
#   file   → path:<repo-root-relative>           stale when path absent/invalid
#   symbol → fn:<rel-path>#<symbol>              stale when file missing OR def absent (shell symbols)
#   flag   → flag:<invocation> <--flag-token>    stale when token absent under scripts/
# An out-of-grammar ref (path escape, non-identifier symbol) is treated as STALE
# rather than silently fresh, so the report never green-lights an invalid ref.
_mem_ref_is_stale() {
  local ref="$1" root="$2"
  local kind="${ref%%:*}" rest="${ref#*:}"
  case "$kind" in
    path)
      _mem_ref_path_unsafe "$rest" && return 0
      [[ -f "$root/$rest" ]] && return 1 || return 0
      ;;
    fn)
      local relpath="${rest%%#*}" symbol="${rest#*#}"
      [[ -n "$symbol" && "$symbol" != "$rest" ]] || return 0
      _mem_ref_path_unsafe "$relpath" && return 0
      # Restrict to shell-identifier symbols so a metacharacter-laden ref cannot
      # turn the grep -E pattern into a wildcard that matches an absent symbol.
      [[ "$symbol" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || return 0
      [[ -f "$root/$relpath" ]] || return 0
      # Match `name()` / `name ()` or `function name` with an exact symbol
      # boundary. The trailing class/anchor is load-bearing: without it
      # `^function g_audit` would prefix-match `function g_audit_renamed` and
      # falsely report a renamed (stale) symbol as fresh.
      grep -qE "^${symbol}[[:space:]]*\(\)|^function[[:space:]]+${symbol}([^A-Za-z0-9_]|\$)" "$root/$relpath" 2>/dev/null && return 1 || return 0
      ;;
    flag)
      local tok token=""
      for tok in $rest; do
        [[ "$tok" == --* ]] && token="$tok"
      done
      [[ -n "$token" ]] || return 0
      grep -qrF -- "$token" "$root/scripts" 2>/dev/null && return 1 || return 0
      ;;
    *)
      return 0
      ;;
  esac
}

_mem_doctor_usage() {
  cat <<'EOF'
Usage: pmctl memory doctor [--json] [--repo-root <path>]

Read-only health report over the project memory directory.

Options:
  --json             Emit a single JSON object (schema_version: 1)
  --repo-root PATH   Repo root used to locate the memory dir and verify
                     repo_refs (default: $REPO_ROOT or current directory)
  --help             Show this help

Exit codes: 0 healthy, 1 issues found, 2 usage error.
EOF
}

pmctl_memory_doctor() {
  local json=0
  local repo_root="${REPO_ROOT:-$PWD}"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --json) json=1; shift ;;
      --repo-root)
        if [[ -z "${2:-}" ]]; then
          printf 'pmctl memory doctor: --repo-root requires a value\n' >&2
          return 2
        fi
        repo_root="$2"; shift 2 ;;
      --help|-h) _mem_doctor_usage; return 0 ;;
      *)
        printf 'pmctl memory doctor: unknown argument: %s\n' "$1" >&2
        return 2 ;;
    esac
  done

  local mem_dir=""
  _pmctl_memory_load_config_override
  if ! mem_dir="$(find_memory_dir "$repo_root")"; then
    mem_dir=""
  fi

  # No memory dir → nothing to check; report an empty, healthy result.
  if [[ -z "$mem_dir" || ! -d "$mem_dir" ]]; then
    if [[ "$json" -eq 1 ]]; then
      printf '{"schema_version":1,"memory_dir":"","entry_count":0,"memory_bytes":0,"episodes_bytes":0,"dead_links":[],"orphan_cards":[],"duplicate_hooks":[],"stale_repo_refs":[],"cards_missing_fields":[],"issues_count":0}\n'
    else
      printf 'memory_dir:      (none found for %s)\n' "$repo_root"
      printf 'issues_count:    0\n'
    fi
    return 0
  fi

  local index="$mem_dir/MEMORY.md"
  local episodes="$mem_dir/episodes.jsonl"

  # ── entry_count + index-derived link/hook data ────────────────────────────
  local entry_count=0
  local -a dead_links=() orphan_cards=() duplicate_hooks=()
  local -a referenced=() hooks=()

  if [[ -f "$index" ]]; then
    local line file hook
    while IFS= read -r line; do
      [[ "$line" =~ ^-\ \[ ]] || continue
      entry_count=$((entry_count + 1))
      file="$(printf '%s' "$line" | sed -E 's/^- \[[^]]*\]\(([^)]+)\).*/\1/')"
      referenced+=("$file")
      if [[ -n "$file" && ! -f "$mem_dir/$file" ]]; then
        dead_links+=("$file")
      fi
      # Hook text follows the " — " (space em-dash space) delimiter.
      if [[ "$line" == *" — "* ]]; then
        hook="${line#* — }"
        [[ -n "$hook" ]] && hooks+=("$hook")
      fi
    done < "$index"
  fi

  # ── duplicate_hooks: hook text appearing on ≥2 index lines ─────────────────
  if [[ "${#hooks[@]}" -gt 0 ]]; then
    local dup
    while IFS= read -r dup; do
      [[ -n "$dup" ]] && duplicate_hooks+=("$dup")
    done < <(printf '%s\n' "${hooks[@]}" | sort | uniq -d)
  fi

  # ── orphan_cards: *.md present but not referenced by MEMORY.md (excl index) ─
  # Derived episode artifacts (episodes.summary.md, episodes.*.md) are not cards
  # and must be excluded from orphan and frontmatter checks.
  local card base is_ref ref
  for card in "$mem_dir"/*.md; do
    [[ -e "$card" ]] || continue
    base="$(basename "$card")"
    [[ "$base" == "MEMORY.md" ]] && continue
    [[ "$base" == episodes.*.md ]] && continue
    is_ref=0
    for ref in ${referenced[@]+"${referenced[@]}"}; do
      if [[ "$ref" == "$base" ]]; then is_ref=1; break; fi
    done
    [[ "$is_ref" -eq 0 ]] && orphan_cards+=("$base")
  done

  # ── per-card checks: stale_repo_refs + missing required frontmatter fields ──
  # Required fields (additive schema): topics/priority/status/updated_at/repo_refs.
  # A card lacking any is flagged in cards_missing_fields (warn-phase surface for
  # the pre-enforce backfill); repo_refs may be empty [] but the key must exist.
  local -a stale_cards=() stale_refs=()
  local -a missing_field_cards=() missing_field_lists=()
  local -a required_fields=(topics priority status updated_at repo_refs)
  for card in "$mem_dir"/*.md; do
    [[ -e "$card" ]] || continue
    base="$(basename "$card")"
    [[ "$base" == "MEMORY.md" ]] && continue
    [[ "$base" == episodes.*.md ]] && continue

    local r
    while IFS= read -r r; do
      [[ -n "$r" ]] || continue
      if _mem_ref_is_stale "$r" "$repo_root"; then
        stale_cards+=("$base")
        stale_refs+=("$r")
      fi
    done < <(_mem_card_repo_refs "$card")

    local keys req missing=""
    keys="$(_mem_card_top_keys "$card")"
    for req in "${required_fields[@]}"; do
      printf '%s\n' "$keys" | grep -qx "$req" || missing+="${missing:+,}$req"
    done
    if [[ -n "$missing" ]]; then
      missing_field_cards+=("$base")
      missing_field_lists+=("$missing")
    fi
  done

  # ── aggregate ─────────────────────────────────────────────────────────────
  local memory_bytes=0 episodes_bytes=0 f
  for f in "$mem_dir"/*.md; do
    [[ -e "$f" ]] || continue
    memory_bytes=$((memory_bytes + $(_mem_file_bytes "$f")))
  done
  episodes_bytes="$(_mem_file_bytes "$episodes")"

  # Count shard files: episodes.YYYY-MM.jsonl pattern in the memory dir.
  local shard_count=0
  for f in "$mem_dir"/episodes.????-??.jsonl; do
    [[ -e "$f" ]] && shard_count=$((shard_count + 1))
  done

  local issues_count=$(( ${#dead_links[@]} + ${#orphan_cards[@]} + ${#duplicate_hooks[@]} + ${#stale_refs[@]} + ${#missing_field_cards[@]} ))

  if [[ "$json" -eq 1 ]]; then
    _mem_doctor_emit_json
  else
    _mem_doctor_emit_human
  fi

  [[ "$issues_count" -gt 0 ]] && return 1
  return 0
}

# Emit the frozen JSON object. Reads the doctor locals from its caller's scope.
_mem_doctor_emit_json() {
  local out="{\"schema_version\":1"
  out+=",\"memory_dir\":\"$(_mem_json_esc "$mem_dir")\""
  out+=",\"entry_count\":$entry_count"
  out+=",\"memory_bytes\":$memory_bytes"
  out+=",\"episodes_bytes\":$episodes_bytes"
  out+=",\"shard_count\":$shard_count"
  out+=",\"dead_links\":$(_mem_json_str_array ${dead_links[@]+"${dead_links[@]}"})"
  out+=",\"orphan_cards\":$(_mem_json_str_array ${orphan_cards[@]+"${orphan_cards[@]}"})"
  out+=",\"duplicate_hooks\":$(_mem_json_str_array ${duplicate_hooks[@]+"${duplicate_hooks[@]}"})"
  out+=",\"stale_repo_refs\":$(_mem_json_stale_array)"
  out+=",\"cards_missing_fields\":$(_mem_json_missing_array)"
  out+=",\"issues_count\":$issues_count}"
  printf '%s\n' "$out"
}

# Build a JSON array of strings from the positional args.
_mem_json_str_array() {
  local first=1 item out="["
  for item in "$@"; do
    [[ "$first" -eq 1 ]] || out+=","
    out+="\"$(_mem_json_esc "$item")\""
    first=0
  done
  out+="]"
  printf '%s' "$out"
}

# Build the stale_repo_refs array of {card,ref} objects from caller's scope.
_mem_json_stale_array() {
  local i first=1 out="["
  for ((i = 0; i < ${#stale_refs[@]}; i++)); do
    [[ "$first" -eq 1 ]] || out+=","
    out+="{\"card\":\"$(_mem_json_esc "${stale_cards[$i]}")\",\"ref\":\"$(_mem_json_esc "${stale_refs[$i]}")\"}"
    first=0
  done
  out+="]"
  printf '%s' "$out"
}

# Build the cards_missing_fields array of {card, missing:[...]} from caller's scope.
_mem_json_missing_array() {
  local i first=1 out="[" field flist farr
  for ((i = 0; i < ${#missing_field_cards[@]}; i++)); do
    [[ "$first" -eq 1 ]] || out+=","
    # missing_field_lists[i] is a comma-joined list → emit as a JSON string array.
    farr="["
    local ffirst=1
    IFS=',' read -ra flist <<< "${missing_field_lists[$i]}"
    for field in "${flist[@]}"; do
      [[ "$ffirst" -eq 1 ]] || farr+=","
      farr+="\"$(_mem_json_esc "$field")\""
      ffirst=0
    done
    farr+="]"
    out+="{\"card\":\"$(_mem_json_esc "${missing_field_cards[$i]}")\",\"missing\":$farr}"
    first=0
  done
  out+="]"
  printf '%s' "$out"
}

# Emit the label-aligned human report. Reads doctor locals from caller's scope.
_mem_doctor_emit_human() {
  printf 'memory_dir:      %s\n' "$mem_dir"
  printf 'entry_count:     %s\n' "$entry_count"
  printf 'memory_bytes:    %s\n' "$memory_bytes"
  printf 'episodes_bytes:  %s\n' "$episodes_bytes"
  printf 'shard_count:     %s\n' "$shard_count"
  _mem_doctor_human_list 'dead_links' ${dead_links[@]+"${dead_links[@]}"}
  _mem_doctor_human_list 'orphan_cards' ${orphan_cards[@]+"${orphan_cards[@]}"}
  _mem_doctor_human_list 'duplicate_hooks' ${duplicate_hooks[@]+"${duplicate_hooks[@]}"}
  if [[ "${#stale_refs[@]}" -eq 0 ]]; then
    printf 'stale_repo_refs: (none)\n'
  else
    printf 'stale_repo_refs:\n'
    local i
    for ((i = 0; i < ${#stale_refs[@]}; i++)); do
      printf '  - %s: %s\n' "${stale_cards[$i]}" "${stale_refs[$i]}"
    done
  fi
  if [[ "${#missing_field_cards[@]}" -eq 0 ]]; then
    printf 'cards_missing_fields: (none)\n'
  else
    printf 'cards_missing_fields:\n'
    local j
    for ((j = 0; j < ${#missing_field_cards[@]}; j++)); do
      printf '  - %s: %s\n' "${missing_field_cards[$j]}" "${missing_field_lists[$j]}"
    done
  fi
  printf 'issues_count:    %s\n' "$issues_count"
}

_mem_doctor_human_list() {
  local label="$1"; shift
  if [[ "$#" -eq 0 ]]; then
    printf '%s: (none)\n' "$label"
    return 0
  fi
  printf '%s:\n' "$label"
  local item
  for item in "$@"; do
    printf '  - %s\n' "$item"
  done
}

# ── Episode shard + summary ───────────────────────────────────────────────────

# Maximum lines in episodes.jsonl before shard is triggered.
EP_SHARD_LINE_LIMIT=1000

# Archive entries from months prior to the current month into
# episodes.YYYY-MM.jsonl shard files when episodes.jsonl exceeds EP_SHARD_LINE_LIMIT.
# Entries for the current month remain in episodes.jsonl.
# Usage: pmctl_memory_shard [--repo-root <path>]
pmctl_memory_shard() {
  local repo_root="${REPO_ROOT:-$PWD}"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --repo-root)
        if [[ -z "${2:-}" ]]; then
          printf 'pmctl memory shard: --repo-root requires a value\n' >&2
          return 2
        fi
        repo_root="$2"; shift 2 ;;
      --help|-h)
        printf 'Usage: pmctl memory shard [--repo-root <path>]\n'
        printf 'Archive old episodes to shard files when episodes.jsonl exceeds %d lines.\n' "$EP_SHARD_LINE_LIMIT"
        return 0 ;;
      *)
        printf 'pmctl memory shard: unknown argument: %s\n' "$1" >&2
        return 2 ;;
    esac
  done

  local mem_dir=""
  _pmctl_memory_load_config_override
  mem_dir="$(find_memory_dir "$repo_root")" || { printf 'pmctl memory shard: no memory directory found\n' >&2; return 1; }

  local ep="$mem_dir/episodes.jsonl"
  [[ -f "$ep" ]] || { printf 'pmctl memory shard: no episodes.jsonl found\n'; return 0; }

  local line_count
  line_count="$(wc -l < "$ep")"
  if [[ "$line_count" -le "$EP_SHARD_LINE_LIMIT" ]]; then
    printf 'pmctl memory shard: %d lines (limit %d) — no shard needed\n' "$line_count" "$EP_SHARD_LINE_LIMIT"
    return 0
  fi

  # Copy-only archive: episodes.jsonl is NEVER modified (append-only invariant preserved).
  # Old-month entries are COPIED into episodes.YYYY-MM.jsonl via awk, which truncates
  # each shard file at the start of the run (awk ">" semantics), so re-running always
  # produces the same shard files — the operation is idempotent.
  local current_ym
  current_ym="$(date -u +%Y-%m 2>/dev/null || date +%Y-%m)"

  # awk ">" truncates each output file on first write within the run, so repeated
  # runs overwrite shard files with identical content (idempotent).
  # Accepts both compact ("date":"YYYY-MM") and spaced ("date": "YYYY-MM") JSON.
  local archived
  archived="$(awk -v mem_dir="$mem_dir" -v cur="$current_ym" '
    {
      match($0, /"date"[[:space:]]*:[[:space:]]*"([^"]+)"/, d)
      if (!d[1]) next
      ym = substr(d[1], 1, 7)
      if (ym == cur || ym == "") next
      print > (mem_dir "/episodes." ym ".jsonl")
      count++
    }
    END { print count+0 }
  ' "$ep")"

  printf 'pmctl memory shard: copied %s old entries to shard files (episodes.jsonl unchanged)\n' "$archived"
}

# Rebuild episodes.summary.md from episodes.jsonl and any shard files.
# Groups entries by year-month, newest month first.
# Usage: pmctl_memory_rebuild_summary [--repo-root <path>]
pmctl_memory_rebuild_summary() {
  local repo_root="${REPO_ROOT:-$PWD}"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --repo-root)
        if [[ -z "${2:-}" ]]; then
          printf 'pmctl memory rebuild-summary: --repo-root requires a value\n' >&2
          return 2
        fi
        repo_root="$2"; shift 2 ;;
      --help|-h)
        printf 'Usage: pmctl memory rebuild-summary [--repo-root <path>]\n'
        printf 'Regenerate episodes.summary.md from episodes.jsonl and shard files.\n'
        return 0 ;;
      *)
        printf 'pmctl memory rebuild-summary: unknown argument: %s\n' "$1" >&2
        return 2 ;;
    esac
  done

  local mem_dir=""
  _pmctl_memory_load_config_override
  mem_dir="$(find_memory_dir "$repo_root")" || { printf 'pmctl memory rebuild-summary: no memory directory found\n' >&2; return 1; }

  local ep="$mem_dir/episodes.jsonl"
  [[ -f "$ep" ]] || { printf 'pmctl memory rebuild-summary: no episodes.jsonl found\n'; return 0; }

  local summary="$mem_dir/episodes.summary.md"

  # Build summary from episodes.jsonl only (NOT from shard files).
  # Shard files are archive snapshots for operator visibility; reading them here
  # would double-count entries already present in the append-only main file.
  # Build summary grouped by year-month using awk.
  # Each group: "## YYYY-MM (N entries)\n- YYYY-MM-DD: <first line of summary>\n..."
  awk '
    BEGIN { ORS="" }
    {
      # Extract date field (handles compact and spaced JSON)
      match($0, /"date"[[:space:]]*:[[:space:]]*"([^"]+)"/, d)
      if (!d[1]) next
      date = d[1]
      ym = substr(date, 1, 7)

      # Extract summary field (first line only; handles compact and spaced JSON)
      match($0, /"summary"[[:space:]]*:[[:space:]]*"([^"]*)"/, s)
      summary = s[1]
      if (!summary || summary == "") next

      # Truncate to first logical line
      n = split(summary, lines, "\\\\n")
      first_line = lines[1]
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", first_line)

      # Store: group[ym] += "- DATE: SUMMARY\n"; count[ym]++
      groups[ym] = groups[ym] "- " date ": " first_line "\n"
      counts[ym]++
      if (!(ym in order_seen)) {
        order[++order_n] = ym
        order_seen[ym] = 1
      }
    }
    END {
      # Sort months descending (newest first)
      n = order_n
      for (i = 1; i <= n; i++) {
        for (j = i+1; j <= n; j++) {
          if (order[i] < order[j]) {
            tmp = order[i]; order[i] = order[j]; order[j] = tmp
          }
        }
      }
      for (i = 1; i <= n; i++) {
        ym = order[i]
        printf "## %s (%d %s)\n%s\n", ym, counts[ym], (counts[ym]==1?"entry":"entries"), groups[ym]
      }
    }
  ' "$ep" > "$summary"

  local month_count
  month_count="$(grep -c '^## ' "$summary" 2>/dev/null || printf '0')"
  printf 'pmctl memory rebuild-summary: wrote %s (%d month(s))\n' "$summary" "$month_count"
}
