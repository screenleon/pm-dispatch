#!/usr/bin/env bash
# Enforce that every deprecation marker in the scanned surface set names a
# removal or retirement version -- so docs/stability-contract.md's "the
# repository holds no surface marked deprecated without a named removal version"
# is a checked fact, not a hope.
#
# Scanned surfaces (this list IS the contract -- widen it only by editing here,
# never with a tree-wide wildcard):
#   1. docs/*.md and docs/architecture/*.md
#        blockquote banner lines beginning  "> **DEPRECATED"  or  "> **RETIRED"
#   2. core/schema/*.schema.json
#        any  "deprecated": true  (JSON Schema keyword)
#   3. cli/commands.tsv
#        rows whose stability column is  "deprecated"
#
# A marker is SATISFIED when either:
#   - a version token  v<major>.<minor>[.<patch>]  appears on the marker's own
#     line (surface 1 and 3) or within three lines of it (surface 2), OR
#   - the surface path is listed in tools/lint/deprecation-sunset-allowlist.tsv
#     (path <TAB> reason) -- for a compat surface deliberately retained with no
#     planned removal date.
# An allowlist entry for a path whose marker already names a version is itself
# an error: the allowlist covers only the undated case.
#
# NOT in the scanned set: the scripts/*.sh path shims. They are governed by
# docs/architecture/script-domain-inventory.tsv + lint-script-domain-inventory.sh
# (the CC-489 ratchet), which supply their owner and drift check.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
case "${1:-}" in
  --repo-root)
    [[ $# -eq 2 ]] || { printf 'lint-deprecation-sunset: --repo-root requires one path\n' >&2; exit 2; }
    repo_root="$2" ;;
  "") ;;
  *) printf 'lint-deprecation-sunset: usage: %s [--repo-root <path>]\n' "$0" >&2; exit 2 ;;
esac

allowlist="$repo_root/tools/lint/deprecation-sunset-allowlist.tsv"
version_re='v[0-9]+\.[0-9]+(\.[0-9]+)?'
failures=0
fail() { printf 'lint-deprecation-sunset: %s\n' "$*" >&2; failures=$((failures + 1)); }

[[ -f "$allowlist" ]] || { fail "missing tools/lint/deprecation-sunset-allowlist.tsv"; exit 1; }
[[ "$(head -n1 "$allowlist")" == $'path\treason' ]] || fail "allowlist header must be: path<TAB>reason"

# --- load the allowlist -----------------------------------------------------
declare -A allow_reason=()
allow_order=()
while IFS=$'\t' read -r path reason extra || [[ -n "$path" ]]; do
  [[ -z "$path" || "$path" == '#'* || "$path" == 'path' ]] && continue
  if [[ -z "$reason" || -n "$extra" ]]; then
    fail "malformed allowlist row (want path<TAB>reason): $path"
    continue
  fi
  [[ -e "$repo_root/$path" ]] || fail "allowlist path does not exist: $path"
  [[ -z "${allow_reason[$path]:-}" ]] || fail "duplicate allowlist path: $path"
  allow_reason[$path]="$reason"
  allow_order+=("$path")
done < "$allowlist"

# markers[<path>]=1 for every scanned path that carries a deprecation marker;
# versioned[<path>]=1 when at least one of its markers names a version.
declare -A markers=() versioned=()
note_marker() { markers[$1]=1; }
note_versioned() { versioned[$1]=1; }

# --- surface 1: docs banners ---------------------------------------------------
while IFS= read -r hit; do
  [[ -n "$hit" ]] || continue
  file="${hit%%:*}"; rest="${hit#*:}"; lineno="${rest%%:*}"; text="${rest#*:}"
  rel="${file#"$repo_root"/}"
  note_marker "$rel"
  if [[ "$text" =~ $version_re ]]; then
    note_versioned "$rel"
  elif [[ -z "${allow_reason[$rel]:-}" ]]; then
    fail "deprecation banner names no removal version and is not allowlisted: $rel:$lineno"
  fi
done < <(grep -rnE '^> \*\*(DEPRECATED|RETIRED)' "$repo_root/docs" --include='*.md' 2>/dev/null || true)

# --- surface 2: JSON Schema deprecated keyword -------------------------------
while IFS= read -r file; do
  [[ -n "$file" ]] || continue
  rel="${file#"$repo_root"/}"
  note_marker "$rel"
  # version token within three lines of any "deprecated" occurrence
  if grep -nE '"deprecated"' "$file" | while IFS=: read -r ln _; do
       sed -n "${ln},$((ln + 3))p" "$file" | grep -Eq "$version_re" && { echo hit; break; }
     done | grep -q hit; then
    note_versioned "$rel"
  elif [[ -z "${allow_reason[$rel]:-}" ]]; then
    fail "schema marks a field deprecated with no version within 3 lines and is not allowlisted: $rel"
  fi
done < <(grep -rlE '"deprecated"' "$repo_root/core/schema" --include='*.schema.json' 2>/dev/null || true)

# --- surface 3: cli/commands.tsv stability=deprecated ------------------------
commands_tsv="$repo_root/cli/commands.tsv"
if [[ -f "$commands_tsv" ]]; then
  rel="cli/commands.tsv"
  while IFS=$'\t' read -r path _summary _usage stability _rest; do
    [[ "$stability" == "deprecated" ]] || continue
    note_marker "$rel"
    if grep -F "	deprecated	" "$commands_tsv" | grep -Eq "$version_re"; then
      note_versioned "$rel"
    elif [[ -z "${allow_reason[$rel]:-}" ]]; then
      fail "cli/commands.tsv row '$path' is stability=deprecated with no version and is not allowlisted"
    fi
  done < <(tail -n +2 "$commands_tsv")
fi

# --- allowlist hygiene ------------------------------------------------------
for path in "${allow_order[@]}"; do
  if [[ -z "${markers[$path]:-}" ]]; then
    fail "allowlist entry names no deprecated surface: $path"
  elif [[ -n "${versioned[$path]:-}" ]]; then
    fail "allowlist entry is unnecessary (surface already names a version): $path"
  fi
done

if [[ "$failures" -gt 0 ]]; then
  printf 'lint-deprecation-sunset: %d failure(s)\n' "$failures" >&2
  exit 1
fi
printf 'lint-deprecation-sunset: OK (%d marked surface(s), %d allowlisted)\n' \
  "${#markers[@]}" "${#allow_order[@]}"
