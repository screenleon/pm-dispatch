#!/usr/bin/env bash
# uninstall.sh — remove pm-dispatch symlinks/copies from ~/.claude/
#
# Idempotent: safe to re-run.
#
# Usage:
#   ./uninstall.sh [--dry-run] [--host <name>]

set -euo pipefail

usage() {
  cat <<'EOF'
uninstall.sh — remove pm-dispatch symlinks/junctions/copies and hooks from ~/.claude/

Usage:
  ./uninstall.sh            apply (idempotent; manifest-driven, safe to re-run)
  ./uninstall.sh --dry-run  preview what would be removed, change nothing
  ./uninstall.sh --host NAME  remove only one or more explicitly selected hosts
  ./uninstall.sh --help     show this help

Honors canonical $CLAUDE_CONFIG_DIR (or legacy $CLAUDE_HOME) to target a
sandbox install. Reads the install manifest below that root; entries modified
since install, or resolving outside the managed root, are skipped for safety.
EOF
}

DRY_RUN=0
SELECTED_HOSTS=(claude)
HOST_SELECTION_EXPLICIT=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --host)
      [[ $# -ge 2 ]] || { echo "uninstall: --host requires a value" >&2; exit 2; }
      [[ "$2" =~ ^[a-z0-9_-]+$ ]] || { echo "uninstall: invalid host name: $2" >&2; exit 2; }
      if [[ "$HOST_SELECTION_EXPLICIT" -eq 0 ]]; then SELECTED_HOSTS=(); HOST_SELECTION_EXPLICIT=1; fi
      SELECTED_HOSTS+=("$2"); shift 2 ;;
    --host=*)
      _selected_host="${1#--host=}"
      [[ "$_selected_host" =~ ^[a-z0-9_-]+$ ]] || { echo "uninstall: invalid host name: $_selected_host" >&2; exit 2; }
      if [[ "$HOST_SELECTION_EXPLICIT" -eq 0 ]]; then SELECTED_HOSTS=(); HOST_SELECTION_EXPLICIT=1; fi
      SELECTED_HOSTS+=("$_selected_host"); shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "uninstall: unknown flag $1" >&2; usage >&2; exit 2 ;;
  esac
done

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"

# shellcheck disable=SC1091
. "$REPO_ROOT/runtime/lib/portable.sh"
_HOST_WRITE_AVAILABLE=0
if [[ -f "$REPO_ROOT/runtime/lib/host-manifest.sh" && -f "$REPO_ROOT/runtime/lib/host-write.sh" ]]; then
  # shellcheck disable=SC1091
  . "$REPO_ROOT/runtime/lib/host-manifest.sh"
  # shellcheck disable=SC1091
  . "$REPO_ROOT/runtime/lib/host-write.sh"
  _HOST_WRITE_AVAILABLE=1
else
  echo "uninstall: warning: host write libraries unavailable; Claude and optional-host hooks will not be removed" >&2
fi

_UNINSTALL_CLAUDE=0
if [[ "$_HOST_WRITE_AVAILABLE" -eq 1 ]]; then
  mapfile -t SELECTED_HOSTS < <(host_selection_unique "${SELECTED_HOSTS[@]}")
  for _host in "${SELECTED_HOSTS[@]}"; do
    _host_write_module "$REPO_ROOT" "$_host" uninstall_module >/dev/null
    [[ "$_host" == "claude" ]] && _UNINSTALL_CLAUDE=1
  done
  unset _host
else
  # The legacy manifest teardown does not depend on host modules. Preserve it
  # for a default Claude uninstall; explicit host selection cannot be resolved
  # safely without the manifest dispatcher and therefore fails loudly.
  if [[ "$HOST_SELECTION_EXPLICIT" -eq 1 ]]; then
    echo "uninstall: host write libraries unavailable; cannot resolve --host selection" >&2
    exit 2
  fi
  _UNINSTALL_CLAUDE=1
fi

if [[ "$_UNINSTALL_CLAUDE" -eq 0 ]]; then
  echo "pm-dispatch uninstaller"
  echo "  repo:  $REPO_ROOT"
  echo "  hosts: ${SELECTED_HOSTS[*]}"
  [[ "$DRY_RUN" -eq 1 ]] && echo "  mode:  DRY RUN"
  echo
  for _host in "${SELECTED_HOSTS[@]}"; do
    host_write_uninstall "$REPO_ROOT" "$_host" "$DRY_RUN"
  done
  unset _host
  echo "Done."
  [[ "$DRY_RUN" -eq 1 ]] && echo "(no changes made — re-run without --dry-run to apply)"
  exit 0
fi

# Mirror install.sh through the same host-owned resolver, but only when the
# selected lifecycle includes Claude.
# shellcheck source=hosts/claude/lib/path-resolver.sh
. "$REPO_ROOT/hosts/claude/lib/path-resolver.sh"
_claude_root="$(claude_host_config_root 2>&1)" || {
  printf 'uninstall: %s\n' "$_claude_root" >&2
  exit 2
}
CLAUDE_CONFIG_DIR="$_claude_root"
CLAUDE_HOME="$CLAUDE_CONFIG_DIR"
unset _claude_root

_UNINSTALL_PLATFORM="$(detect_platform)"

MANIFEST="$CLAUDE_HOME/.pm-dispatch/install-manifest.json"

removed=0
skipped=0
safety_skipped=0

resolve_symlink_target() {
  local dst="$1"
  local link_target="$2"

  case "$link_target" in
    /*|[A-Za-z]:/*)
      _portable_normalize_path "$link_target"
      ;;
    *)
      _portable_normalize_path "$(dirname "$dst")/$link_target"
      ;;
  esac
}

is_manifest_symlink_target() {
  local src="$1"
  local dst="$2"
  local link_target="$3"
  local normalized_target

  if [[ "$link_target" == "$src" ]]; then
    return 0
  fi

  normalized_target="$(resolve_symlink_target "$dst" "$link_target")"

  [[ "$normalized_target" == "$src" ]]
}

uninstall_pmctl_cli() {
  local src="$REPO_ROOT/cli/pmctl"
  local bin_dir="${PMCTL_BIN_DIR:-$HOME/.local/bin}"
  local dest="$bin_dir/pmctl"
  local link_target
  local normalized_target

  echo "==> pmctl CLI"

  if [[ "$_UNINSTALL_PLATFORM" == "windows" ]]; then
    echo "  skip $dest (not installed on Windows)"
    return 0
  fi

  if [[ ! -L "$dest" ]]; then
    if [[ -e "$dest" ]]; then
      skipped=$((skipped + 1))
      echo "  skip $dest (not a symlink — skipping)"
    else
      skipped=$((skipped + 1))
      echo "  skip $dest (already gone)"
    fi
    return 0
  fi

  link_target="$(readlink "$dest")"
  normalized_target="$(resolve_symlink_target "$dest" "$link_target")"
  if [[ "$normalized_target" != "$src" ]]; then
    skipped=$((skipped + 1))
    echo "  skip $dest (not our symlink — skipping)"
    return 0
  fi

  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "  would remove $dest"
  else
    rm "$dest"
    echo "  remove $dest"
  fi
  removed=$((removed + 1))
}

remove_item() {
  local dst="$1"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "  would remove $dst"
  else
    if [[ -d "$dst" && ! -L "$dst" ]]; then
      rm -rf "$dst"
    else
      rm "$dst"
    fi
    echo "  remove $dst"
  fi
  removed=$((removed + 1))
}

is_under_managed_root() {
  local path="$1"
  local normalized resolved real_claude_home parent real_parent

  # Handle relative paths: prepend PWD if not absolute.
  case "$path" in
    /*) ;;
    *) path="$PWD/$path" ;;
  esac

  # Step 1: lexical normalization (resolves .. without requiring existence or symlink follow)
  normalized="$(_portable_normalize_path "$path" 2>/dev/null)"
  if [[ -z "$normalized" ]]; then
    return 1
  fi

  # Step 2: symlink resolution — physically resolve to prevent symlinked-parent traversal.
  # A dst such as $HOME/.claude/linkdir/file passes the lexical check but resolves
  # outside the managed root when linkdir is a symlink to an outside directory.
  if resolved="$(realpath -- "$normalized" 2>/dev/null)" && [[ -n "$resolved" ]]; then
    # realpath succeeded: use the physically-resolved location
    normalized="$resolved"
  elif [[ -e "$normalized" ]]; then
    # Path EXISTS on the filesystem but realpath failed or is unavailable.
    # We cannot safely verify ownership without physical resolution — fail closed.
    return 1
  else
    # Path does NOT exist (e.g. already removed in a prior run).
    # Attempt to resolve the nearest existing parent to catch symlinked ancestor dirs.
    parent="$(dirname "$normalized")"
    if real_parent="$(realpath -- "$parent" 2>/dev/null)" && [[ -n "$real_parent" ]]; then
      normalized="$real_parent/$(basename "$normalized")"
    fi
    # If parent is also unresolvable: path truly does not exist yet, so there is no
    # symlinked directory to traverse through — lexical normalization is safe.
  fi

  # Resolve CLAUDE_HOME itself in case ~/.claude is a symlink
  real_claude_home="$(realpath -- "$CLAUDE_HOME" 2>/dev/null || printf '%s' "$CLAUDE_HOME")"

  # Fail closed: if normalization yields empty after resolution, deny
  if [[ -z "$normalized" ]]; then
    return 1
  fi

  case "$normalized" in
    "$real_claude_home"/*)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

is_symlink_dst_under_managed_root() {
  local dst="$1"
  local parent basename

  parent="$(dirname "$dst")"
  basename="$(basename "$dst")"

  # For symlink entries, the final path may itself be a legitimate symlink to
  # repo content outside ~/.claude. Check a non-existing sibling path so
  # symlinked parent directories are resolved without following the final link.
  is_under_managed_root "$parent/.pm-dispatch-uninstall-parent-check-$basename"
}

echo "pm-dispatch uninstaller"
echo "  repo:     $REPO_ROOT"
echo "  manifest: $MANIFEST"
if [[ "$DRY_RUN" -eq 1 ]]; then echo "  mode:     DRY RUN"; fi
echo

uninstall_pmctl_cli
echo

if [[ ! -f "$MANIFEST" ]]; then
  echo "uninstall: no manifest found at $MANIFEST — no managed-root manifest entries to remove"
  exit 0
fi

echo "==> manifest entries"
parsed_any=0
while IFS= read -r line; do
  [[ "$line" == *'"src"'* ]] || continue
  [[ "$line" == *'"dst"'* ]] || continue
  parsed_any=1

  src="$(_portable_json_unescape "$(_portable_extract_json_field "$line" "src")")"
  dst="$(_portable_json_unescape "$(_portable_extract_json_field "$line" "dst")")"
  mode="$(_portable_json_unescape "$(_portable_extract_json_field "$line" "mode")")"
  sha256="$(_portable_json_unescape "$(_portable_extract_json_field "$line" "sha256")")"

  if [[ -z "$dst" ]]; then
    skipped=$((skipped + 1))
    echo "  skip <empty dst> (invalid manifest entry)"
    continue
  fi

  # A prior teardown step may already have removed an entry that is also
  # recorded in the manifest. The pmctl CLI is the canonical example: it lives
  # outside CLAUDE_HOME, is ownership-checked and removed by
  # uninstall_pmctl_cli(), then appears again in the manifest loop. Absence is
  # not a blast-radius concern, so do not turn that idempotent state into a
  # safety skip that preserves the manifest forever. Broken symlinks still pass
  # through the ownership/root checks because `-L` remains true.
  case "$mode" in
    symlink|copy|junction)
      if [[ ! -e "$dst" && ! -L "$dst" ]]; then
        skipped=$((skipped + 1))
        echo "  skip $dst (already gone)"
        continue
      fi
      ;;
  esac

  case "$mode" in
    symlink)
      if ! is_symlink_dst_under_managed_root "$dst"; then
        skipped=$((skipped + 1))
        safety_skipped=$((safety_skipped + 1))
        echo "  skip $dst (dst outside managed root — skipping for safety)"
        continue
      fi
      if [[ -L "$dst" ]]; then
        link_target="$(readlink "$dst")"
        if is_manifest_symlink_target "$src" "$dst" "$link_target"; then
          remove_item "$dst"
        else
          skipped=$((skipped + 1))
          safety_skipped=$((safety_skipped + 1))
          echo "  skip $dst (not our symlink — skipping)"
        fi
      elif [[ -e "$dst" ]]; then
        # Path exists but is not a symlink — unexpected state
        skipped=$((skipped + 1))
        safety_skipped=$((safety_skipped + 1))
        echo "  skip $dst (not our symlink — skipping)"
      else
        # Path is gone entirely — not a safety concern
        skipped=$((skipped + 1))
        echo "  skip $dst (already gone)"
      fi
      ;;
    copy)
      if ! is_under_managed_root "$dst"; then
        skipped=$((skipped + 1))
        safety_skipped=$((safety_skipped + 1))
        echo "  skip $dst (dst outside managed root — skipping for safety)"
        continue
      fi
      if [[ -f "$dst" || ( -d "$dst" && ! -L "$dst" ) ]]; then
        curr_sha="$(_portable_sha256_path "$dst")"
        if [[ "$curr_sha" == "$sha256" ]]; then
          remove_item "$dst"
        else
          skipped=$((skipped + 1))
          safety_skipped=$((safety_skipped + 1))
          echo "  skip $dst (modified since install — skipping)"
        fi
      else
        # Path not found — not a safety concern (normal after partial rerun)
        skipped=$((skipped + 1))
        echo "  skip $dst (already gone)"
      fi
      ;;
    junction)
      if ! is_symlink_dst_under_managed_root "$dst"; then
        skipped=$((skipped + 1))
        safety_skipped=$((safety_skipped + 1))
        echo "  skip $dst (dst outside managed root — skipping for safety)"
        continue
      fi
      # Use rmdir to remove junction without following it into source contents.
      # On Linux/macOS -L catches symlinks; on Windows junctions may not pass -L.
      if [[ -d "$dst" ]]; then
        if [[ "$DRY_RUN" -eq 1 ]]; then
          echo "  would remove junction $dst"
        else
          if [[ "$_UNINSTALL_PLATFORM" == "windows" ]]; then
            remove_junction_windows "$dst" || {
              printf '  skip %s (powershell Remove-Item failed)\n' "$dst" >&2
              skipped=$((skipped + 1))
              safety_skipped=$((safety_skipped + 1))
              continue
            }
          else
            rmdir "$dst" 2>/dev/null || {
              printf '  skip %s (rmdir failed — may not be a junction or not empty)\n' "$dst" >&2
              skipped=$((skipped + 1))
              safety_skipped=$((safety_skipped + 1))
              continue
            }
          fi
          echo "  remove junction $dst"
          removed=$((removed + 1))
        fi
      else
        skipped=$((skipped + 1))
        echo "  skip $dst (already gone)"
      fi
      ;;
    *)
      if ! is_under_managed_root "$dst"; then
        skipped=$((skipped + 1))
        safety_skipped=$((safety_skipped + 1))
        echo "  skip $dst (dst outside managed root — skipping for safety)"
        continue
      fi
      skipped=$((skipped + 1))
      safety_skipped=$((safety_skipped + 1))
      echo "  skip $dst (unknown mode: $mode)"
      ;;
  esac
done < <(grep '"src"' "$MANIFEST" | grep '"dst"' || true)

# Fail closed: manifest has entries but nothing matched the grep-based parser
if [[ "$parsed_any" -eq 0 ]] && grep -q '"mode"' "$MANIFEST" 2>/dev/null; then
  echo "  warning: manifest entries could not be parsed (check format — expected compact JSON)"
  skipped=$((skipped + 1))
  safety_skipped=$((safety_skipped + 1))
fi

# Explicit selection tears down only the named host modules. The no-selector
# compatibility path retains the historic all-module cleanup for existing
# mixed installs created before host selection was available.
if [[ "$_HOST_WRITE_AVAILABLE" -eq 1 ]]; then
  echo
  echo "==> hooks"
  if [[ "$HOST_SELECTION_EXPLICIT" -eq 1 ]]; then
    for _host in "${SELECTED_HOSTS[@]}"; do
      host_write_uninstall "$REPO_ROOT" "$_host" "$DRY_RUN"
    done
    unset _host
  else
    host_write_uninstall_all "$REPO_ROOT" "$DRY_RUN"
  fi
fi

if [[ "$DRY_RUN" -ne 1 ]]; then
  if [[ "$safety_skipped" -eq 0 ]]; then
    rm -rf "$CLAUDE_HOME/.pm-dispatch"
  else
    echo "  note: $safety_skipped item(s) require manual attention — manifest preserved for re-run"
    echo "  resolve conflicts manually, then re-run uninstall.sh"
  fi
  for d in "$CLAUDE_HOME/agents" "$CLAUDE_HOME/commands" "$CLAUDE_HOME/skills" "$CLAUDE_HOME/scripts" "$CLAUDE_HOME/share" "$CLAUDE_HOME/adapters"; do
    [[ -d "$d" ]] || continue
    if rmdir "$d" 2>/dev/null; then
      echo "  pruned $d"
    fi
  done
fi

echo
if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "Done. (no changes made — re-run without --dry-run to apply)"
else
  echo "Done. Removed $removed items, skipped $skipped items ($safety_skipped safety-skip)."
fi
