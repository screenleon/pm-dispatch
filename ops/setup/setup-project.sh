#!/usr/bin/env bash
# setup-project.sh — patch a project's .gitignore and .dockerignore with
# Claude agent / codex output ignore rules.
#
# Idempotent: safe to run multiple times. Only appends if entries are absent.
#
# Usage:
#   bash setup-project.sh [--dry-run] [project-dir]
#
# project-dir defaults to the current directory.
# Searches for Dockerfiles up to depth 3; patches every .dockerignore found
# (or creates one next to each Dockerfile if missing).

set -euo pipefail

DRY_RUN=0
PROJECT_DIR="."
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    *) PROJECT_DIR="$arg" ;;
  esac
done

PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"

HEADER="# Claude agent / codex output — not for VCS or Docker"
ENTRIES=(".agent-trace/" ".gate-briefs/" ".gate-results/" ".agents/")

# ── helpers ──────────────────────────────────────────────────────────────────

patch_file() {
  local file="$1"
  local created=0

  if [[ ! -f "$file" ]]; then
    if [[ "$DRY_RUN" -eq 1 ]]; then
      echo "  would create $file"
    else
      touch "$file"
      echo "  create $file"
    fi
    created=1
  fi

  local added=0
  for entry in "${ENTRIES[@]}"; do
    if grep -qxF "$entry" "$file" 2>/dev/null; then
      echo "  already present: $entry  ($file)"
    else
      if [[ "$DRY_RUN" -eq 1 ]]; then
        echo "  would add: $entry  ($file)"
      else
        # Add header block before first entry if file doesn't already contain it
        if [[ "$added" -eq 0 ]] && ! grep -qxF "$HEADER" "$file" 2>/dev/null; then
          printf '\n%s\n' "$HEADER" >> "$file"
        fi
        printf '%s\n' "$entry" >> "$file"
        echo "  added: $entry  ($file)"
      fi
      added=$((added + 1))
    fi
  done

  if [[ "$created" -eq 0 && "$added" -eq 0 ]]; then
    echo "  up-to-date: $file"
  fi
}

# ── main ─────────────────────────────────────────────────────────────────────

echo "setup-project: $PROJECT_DIR"
if [[ "$DRY_RUN" -eq 1 ]]; then echo "  mode: DRY RUN"; fi
echo

# 1. Patch root .gitignore
echo "==> .gitignore"
if [[ "$DRY_RUN" -eq 1 ]]; then
  bash "$REPO_ROOT/ops/setup/patch-gitignore.sh" --dry-run "$PROJECT_DIR" "${ENTRIES[@]}" 2>&1 || true
else
  bash "$REPO_ROOT/ops/setup/patch-gitignore.sh" "$PROJECT_DIR" "${ENTRIES[@]}"
fi
echo

# 2. Find Dockerfiles and patch the co-located .dockerignore
echo "==> .dockerignore"
mapfile -t dockerfiles < <(
  find "$PROJECT_DIR" \
    -maxdepth 3 \
    \( -name ".git" -o -name "node_modules" -o -name "vendor" \) -prune \
    -o -name "Dockerfile" -print \
    -o -name "Dockerfile.*" -print \
    2>/dev/null | sort
)

if [[ "${#dockerfiles[@]}" -eq 0 ]]; then
  echo "  no Dockerfiles found — skipping"
else
  declare -A seen_dirs
  for df in "${dockerfiles[@]}"; do
    dir="$(dirname "$df")"
    [[ -n "${seen_dirs[$dir]+x}" ]] && continue
    seen_dirs[$dir]=1
    patch_file "$dir/.dockerignore"
  done
fi

echo
echo "Done."
if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "(no changes made — re-run without --dry-run to apply)"
fi
