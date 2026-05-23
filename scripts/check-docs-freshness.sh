#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C.UTF-8

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
# Resolve symlink to find actual repo scripts/ directory.
if [[ -L "${BASH_SOURCE[0]}" ]]; then
  _real="$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || readlink "${BASH_SOURCE[0]}" 2>/dev/null || printf '%s' "${BASH_SOURCE[0]}")"
  SCRIPT_DIR="$(cd "$(dirname "$_real")" 2>/dev/null && pwd || printf '%s' "$SCRIPT_DIR")"
  unset _real
fi

# Source libs with graceful fallback for copy-mode (Windows) where lib/ is absent.
if [[ -f "$SCRIPT_DIR/lib/portable.sh" ]]; then
  # shellcheck source=scripts/lib/portable.sh
  . "$SCRIPT_DIR/lib/portable.sh"
  _PORTABLE_AVAILABLE=1
else
  _PORTABLE_AVAILABLE=0
  detect_platform() {
    case "${OSTYPE:-}" in
      linux*) printf 'linux\n' ;;
      darwin*) printf 'macos\n' ;;
      msys*|cygwin*) printf 'windows\n' ;;
      *)
        case "$(uname -s 2>/dev/null)" in
          Linux*) printf 'linux\n' ;;
          Darwin*) printf 'macos\n' ;;
          MINGW*|MSYS*) printf 'windows\n' ;;
          *) printf 'unknown\n' ;;
        esac
        ;;
    esac
  }
fi

JSON=0
QUIET=0
REPO_ROOT=""

OK_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0

usage() {
  cat <<'HELP'
Usage: check-docs-freshness.sh [--json] [--quiet] [--repo <path>] [--help]

Check pre-milestone doc freshness.

Options:
  --json        Emit JSON Lines output.
  --quiet       Suppress OK lines in human output.
  --repo PATH   Repository root to check (default: script directory parent).
  --help        Show this help.
HELP
}

_json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  s="${s//$'\t'/\\t}"
  printf '%s' "$s"
}

version_compare() {
  local left="${1#v}"
  local right="${2#v}"
  local l1 l2 l3 r1 r2 r3

  IFS='.' read -r l1 l2 l3 <<< "$left"
  IFS='.' read -r r1 r2 r3 <<< "$right"

  l1=${l1:-0}
  l2=${l2:-0}
  l3=${l3:-0}
  r1=${r1:-0}
  r2=${r2:-0}
  r3=${r3:-0}

  if (( l1 > r1 )); then
    printf '%s\n' 1
  elif (( l1 < r1 )); then
    printf '%s\n' -1
  elif (( l2 > r2 )); then
    printf '%s\n' 1
  elif (( l2 < r2 )); then
    printf '%s\n' -1
  elif (( l3 > r3 )); then
    printf '%s\n' 1
  elif (( l3 < r3 )); then
    printf '%s\n' -1
  else
    printf '%s\n' 0
  fi
}

max_version() {
  local max=""
  local v

  for v in "$@"; do
    [[ -z "$v" ]] && continue
    if [[ -z "$max" ]]; then
      max="$v"
    elif (( $(version_compare "$v" "$max") > 0 )); then
      max="$v"
    fi
  done
  printf '%s' "$max"
}

emit_unit_header() {
  local unit="$1"
  if [[ "$JSON" -eq 1 ]]; then
    return
  fi
  printf '\n[%s]\n' "$unit"
}

emit_check() {
  local unit="$1"
  local severity="$2"
  local message="$3"
  local location="$4"

  case "$severity" in
    ok) OK_COUNT=$((OK_COUNT + 1)) ;;
    warn) WARN_COUNT=$((WARN_COUNT + 1)) ;;
    fail) FAIL_COUNT=$((FAIL_COUNT + 1)) ;;
  esac

  if [[ "$JSON" -eq 1 ]]; then
    printf '{"unit":"%s","severity":"%s","message":"%s","location":"%s"}\n' \
      "$unit" "$severity" "$(_json_escape "$message")" "$(_json_escape "$location")"
    return
  fi

  if [[ "$QUIET" -eq 1 && "$severity" == ok ]]; then
    return
  fi

  case "$severity" in
    ok) printf '[OK]   ' ;;
    warn) printf '[WARN] ' ;;
    fail) printf '[FAIL] ' ;;
    *) printf '[INFO] ' ;;
  esac

  if [[ -n "$location" ]]; then
    printf '%s (%s)\n' "$message" "$location"
  else
    printf '%s\n' "$message"
  fi
}

run_unit_readme() {
  local unit="U1-README"
  local readme="$REPO_ROOT/README.md"
  local latest_tag=""
  local latest_readme
  local readme_versions
  local readme_match

  emit_unit_header "$unit"

  if [[ ! -f "$readme" ]]; then
    emit_check "$unit" fail "README.md is missing" "$readme"
    return
  fi

  latest_tag="$(git -C "$REPO_ROOT" tag --sort=-creatordate --list 'v[0-9]*.[0-9]*.[0-9]*' | head -1 || true)"
  readme_match="$(grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' "$readme" 2>/dev/null || true)"

  if [[ -z "$readme_match" ]]; then
    emit_check "$unit" warn "README.md has no vN.N.N version reference" "$readme"
    return
  fi

  readme_versions=()
  while IFS= read -r version; do
    readme_versions+=("$version")
  done <<< "$readme_match"

  latest_readme="$(max_version "${readme_versions[@]}")"

  if [[ -z "$latest_tag" ]]; then
    emit_check "$unit" warn "No git tags found to compare README version" "$REPO_ROOT/.git"
    return
  fi

  local cmp
  cmp="$(version_compare "$latest_readme" "$latest_tag")"
  if (( cmp < 0 )); then
    emit_check "$unit" fail "README references ${latest_readme}, older than latest tag ${latest_tag}" "$readme"
  elif (( cmp == 0 )); then
    emit_check "$unit" ok "README references latest tag ${latest_readme}" "$readme"
  else
    emit_check "$unit" warn "README references ${latest_readme} newer than latest tag ${latest_tag}; check tag list" "$readme"
  fi
}

run_unit_milestones() {
  local unit="U2-MILESTONES"
  local milestones="$REPO_ROOT/MILESTONES.md"
  local -a tags=()
  local -A section_planned=()
  local -A tags_seen=()
  local current=""
  local planned=0
  local unit_fail=0
  local line

  emit_unit_header "$unit"

  if [[ ! -f "$milestones" ]]; then
    emit_check "$unit" fail "MILESTONES.md is missing" "$milestones"
    return
  fi

  mapfile -t tags < <(git -C "$REPO_ROOT" tag --sort=-creatordate --list 'v[0-9]*.[0-9]*.[0-9]*' || true)

  while IFS= read -r line; do
    if [[ "$line" =~ ^##[[:space:]]+(v[0-9]+\.[0-9]+\.[0-9]+) ]]; then
      if [[ -n "$current" ]]; then
        section_planned["$current"]="$planned"
      fi
      current="${BASH_REMATCH[1]}"
      planned=0
      if [[ "$line" == *"規劃中"* || "${line,,}" == *"planned"* || "$line" == *"⏳"* ]]; then
        planned=1
      fi
      continue
    elif [[ -n "$current" && "$line" == "## "* ]]; then
      section_planned["$current"]="$planned"
      current=""
      planned=0
      continue
    fi

    if [[ -n "$current" && ( "$line" == *"規劃中"* || "${line,,}" == *"planned"* || "$line" == *"⏳"* ) ]]; then
      planned=1
    fi
  done < "$milestones"

  if [[ -n "$current" ]]; then
    section_planned["$current"]="$planned"
  fi

  if (( ${#tags[@]} == 0 )); then
    emit_check "$unit" warn "No git tags found; skipped milestone/tag parity check" "$REPO_ROOT/.git"
    return
  fi

  for line in "${tags[@]}"; do
    tags_seen["$line"]=1
    if [[ -z "${section_planned[$line]+x}" ]]; then
      emit_check "$unit" fail "tag $line exists but no section ## $line in MILESTONES.md" "$milestones"
      unit_fail=1
    elif [[ "${section_planned[$line]}" == 1 ]]; then
      emit_check "$unit" fail "section ## $line is marked planned but tag $line already exists" "$milestones"
      unit_fail=1
    fi
  done

  if (( unit_fail == 0 )); then
    emit_check "$unit" ok "All shipped tags have matching milestone sections with completed status" "$milestones"
  fi
}

run_unit_backlog() {
  local unit="U3-BACKLOG"
  local backlog="$REPO_ROOT/BACKLOG.md"
  local found=0
  local line_no status refs

  emit_unit_header "$unit"

  if [[ ! -f "$backlog" ]]; then
    emit_check "$unit" fail "BACKLOG.md is missing" "$backlog"
    return
  fi

  while IFS='|' read -r line_no status refs; do
    found=1
    if [[ "$status" == *"✅"* && "$status" == *"closed"* ]]; then
      emit_check "$unit" fail "closed row with pr:TBD" "${backlog}:${line_no}"
    else
      emit_check "$unit" warn "non-closed row with pr:TBD" "${backlog}:${line_no}"
    fi
  done < <(awk -F'|' '/^\|[[:space:]]*CC-[0-9]+[a-zA-Z]?/ && $0 ~ /pr:TBD/ {
    status=$3
    refs=$7
    gsub(/^[[:space:]]+/, "", status)
    gsub(/[[:space:]]+$/, "", status)
    gsub(/^[[:space:]]+/, "", refs)
    gsub(/[[:space:]]+$/, "", refs)
    if (refs ~ /pr:TBD/) {
      print NR "|" status "|" refs
    }
  }' "$backlog")

  if [[ "$found" -eq 0 ]]; then
    emit_check "$unit" ok "No backlog rows with pr:TBD" "$backlog"
  fi
}

emit_summary() {
  local msg
  local total
  total=$((OK_COUNT + WARN_COUNT + FAIL_COUNT))
  msg="Summary: ${total} checks, ${OK_COUNT} ok, ${WARN_COUNT} warnings, ${FAIL_COUNT} blocking"

  if [[ "$JSON" -eq 1 ]]; then
    printf '{"unit":"summary","severity":"summary","message":"%s","location":"overall"}\n' "$(_json_escape "$msg")"
  else
    printf '\n%s\n' "$msg"
  fi
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --json)
        JSON=1
        shift
        ;;
      --quiet)
        QUIET=1
        shift
        ;;
      --repo)
        if [[ $# -lt 2 ]]; then
          printf 'error: --repo requires a path argument\n' >&2
          usage >&2
          exit 2
        fi
        REPO_ROOT="$2"
        shift 2
        ;;
      --help)
        usage
        exit 0
        ;;
      *)
        printf 'error: unknown argument: %s\n' "$1" >&2
        usage >&2
        exit 2
        ;;
    esac
  done
}

main() {
  REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
  parse_args "$@"

  if [[ -z "$REPO_ROOT" || ! -d "$REPO_ROOT" ]]; then
    printf 'error: repository path is not a directory: %s\n' "$REPO_ROOT" >&2
    exit 2
  fi

  if ! git -C "$REPO_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
    printf 'error: repository root is not a git repository: %s\n' "$REPO_ROOT" >&2
    exit 2
  fi

  run_unit_readme
  run_unit_milestones
  run_unit_backlog
  emit_summary

  if [[ "$FAIL_COUNT" -gt 0 ]]; then
    exit 2
  fi
  if [[ "$WARN_COUNT" -gt 0 ]]; then
    exit 1
  fi
  exit 0
}

main "$@"
