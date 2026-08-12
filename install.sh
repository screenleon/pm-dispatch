#!/usr/bin/env bash
# install.sh — symlink pm-dispatch contents into ~/.claude/
#
# Idempotent: re-running is safe.
# Per-file symlinks: ~/.claude/agents/ may contain agents from other sources alongside.
#
# Usage:
#   ./install.sh [--dry-run] [--profile minimal|full] [--verify]
#
# --profile is forwarded to install-guards.sh and selects whether to wire adapter
# bash guards (adapters/<name>/bash-guard.sh, manifest-driven via needs_bash_guard).
# No adapter ships a bash guard today, so both profiles currently wire the same
# hook set; the flag is retained for forward compatibility with future adapters.
#   full     wire all hooks including any adapter bash guards (none ship today)
#   minimal  skip adapter bash guards
#   (omit)   auto-detect: codex on PATH → full, else minimal
#
# --verify runs all preflight test suites before installing.
#   Skipped by default; recommended when contributing or after updating.
#
# --host <name> selects the host modules to install. It may be repeated. With
# no --host flag, Claude remains the compatibility default. --enable-host
# augments that default/explicit selection for backwards compatibility.
# --enable-codex-command-guard remains a backward-compatible alias for
# --enable-host codex.
#
# --enable-codex-command-guard opts into the manifest-declared Codex hook.
#   into $CODEX_HOME/hooks.json (see hosts/codex/host.yaml). OFF BY DEFAULT and NOT
#   auto-detected from codex-on-PATH the way --profile is: unlike claude's
#   settings.json, hooks.json is GLOBAL to every codex session on the machine,
#   not scoped to pm-dispatch. The guard policy (runtime/hooks/guard-pm-bash.sh) is a
#   curated denylist of destructive/hard-to-reverse commands (rm -rf, force
#   push, sudo, ...) applied to EVERY Bash call in EVERY codex session on this
#   machine once wired — not just pm-dispatch ones. Auto-wiring it from mere
#   codex-on-PATH would silently change behavior for the user's unrelated
#   codex usage without their opt-in, so this stays an explicit flag. This
#   mirrors hosts/claude/host.yaml's own command_guard, which stays undeclared
#   for the analogous reason (no host-level Bash guard for claude's own
#   session either).

set -euo pipefail

DRY_RUN=0
VERIFY=0
PROFILE=""
ENABLED_HOSTS=()
SELECTED_HOSTS=(claude)
HOST_SELECTION_EXPLICIT=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --verify) VERIFY=1; shift ;;
    --enable-codex-command-guard) ENABLED_HOSTS+=(codex); shift ;;
    --enable-host)
      [[ $# -ge 2 ]] || { echo "install: --enable-host requires a value" >&2; exit 2; }
      [[ "$2" =~ ^[a-z0-9_-]+$ ]] || { echo "install: invalid host name: $2" >&2; exit 2; }
      ENABLED_HOSTS+=("$2"); shift 2 ;;
    --enable-host=*)
      _enable_host="${1#--enable-host=}"
      [[ "$_enable_host" =~ ^[a-z0-9_-]+$ ]] || { echo "install: invalid host name: $_enable_host" >&2; exit 2; }
      ENABLED_HOSTS+=("$_enable_host"); shift ;;
    --host)
      [[ $# -ge 2 ]] || { echo "install: --host requires a value" >&2; exit 2; }
      [[ "$2" =~ ^[a-z0-9_-]+$ ]] || { echo "install: invalid host name: $2" >&2; exit 2; }
      if [[ "$HOST_SELECTION_EXPLICIT" -eq 0 ]]; then
        SELECTED_HOSTS=()
        HOST_SELECTION_EXPLICIT=1
      fi
      SELECTED_HOSTS+=("$2"); shift 2 ;;
    --host=*)
      _selected_host="${1#--host=}"
      [[ "$_selected_host" =~ ^[a-z0-9_-]+$ ]] || { echo "install: invalid host name: $_selected_host" >&2; exit 2; }
      if [[ "$HOST_SELECTION_EXPLICIT" -eq 0 ]]; then
        SELECTED_HOSTS=()
        HOST_SELECTION_EXPLICIT=1
      fi
      SELECTED_HOSTS+=("$_selected_host"); shift ;;
    --profile)
      [[ $# -ge 2 ]] || { echo "install: --profile requires a value" >&2; exit 2; }
      PROFILE="$2"
      shift 2
      ;;
    --profile=*) PROFILE="${1#--profile=}"; shift ;;
    *) echo "install: unknown flag $1" >&2; exit 2 ;;
  esac
done

if [[ "$HOST_SELECTION_EXPLICIT" -eq 1 && "${#ENABLED_HOSTS[@]}" -gt 0 ]]; then
  echo "install: --host cannot be combined with --enable-host or --enable-codex-command-guard" >&2
  exit 2
fi

case "$PROFILE" in
  ""|minimal|full) ;;
  *) echo "install: --profile must be minimal or full (got: $PROFILE)" >&2; exit 2 ;;
esac

# jq is required by hooks and install-guards.sh; fail early with actionable hint.
if ! command -v jq >/dev/null 2>&1; then
  echo "install: jq not found — install it first:" >&2
  echo "  Linux/WSL2: sudo apt install jq" >&2
  echo "  macOS:      brew install jq" >&2
  echo "  Windows:    winget install jqlang.jq" >&2
  echo "  See docs/platform-support.md for details." >&2
  exit 1
fi

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
_COPY_FALLBACK_COUNT=0

# shellcheck disable=SC1091
. "$REPO_ROOT/runtime/lib/portable.sh"
if [[ ! -f "$REPO_ROOT/runtime/lib/install-receipt.sh" ]]; then
  # Keep the established fail-loud contract for incomplete checkout layouts:
  # receipt ownership is part of the host lifecycle, never an optional source.
  echo "install: host write libraries unavailable in this install layout" >&2
  exit 2
fi
# shellcheck disable=SC1091
. "$REPO_ROOT/runtime/lib/install-receipt.sh"
# shellcheck disable=SC1091
. "$REPO_ROOT/runtime/lib/allowlist.sh"
# shellcheck disable=SC1091
. "$REPO_ROOT/runtime/lib/dispatch-common.sh"
_HOST_WRITE_AVAILABLE=0
if [[ -f "$REPO_ROOT/runtime/lib/host-manifest.sh" && -f "$REPO_ROOT/runtime/lib/host-write.sh" ]]; then
  # shellcheck disable=SC1091
  . "$REPO_ROOT/runtime/lib/host-manifest.sh"
  # shellcheck disable=SC1091
  . "$REPO_ROOT/runtime/lib/host-write.sh"
  _HOST_WRITE_AVAILABLE=1
else
  echo "install: host write libraries unavailable in this install layout" >&2
  exit 2
fi

RECEIPT_PATH="$(pm_dispatch_receipt_path)" || { echo "install: cannot resolve product receipt path" >&2; exit 2; }
LEGACY_RECEIPT_PATH="$(pm_dispatch_legacy_receipt_path)" || LEGACY_RECEIPT_PATH=""
PM_DISPATCH_MANIFEST_PATH="$RECEIPT_PATH"
export PM_DISPATCH_MANIFEST_PATH

# --enable-host predates --host and augments only the compatibility-default
# path. Explicit selection rejects mixing it with the legacy opt-in flags, so
# an explicit non-Claude lifecycle cannot silently reactivate Claude.
# Normalize through the shared host lifecycle helper before any module executes.
for _host in "${ENABLED_HOSTS[@]}"; do
  SELECTED_HOSTS+=("$_host")
done
mapfile -t SELECTED_HOSTS < <(host_selection_unique "${SELECTED_HOSTS[@]}")
unset _host

# Validate every selected host before any host configuration mutates. A manifest
# without an install module must fail before another selected host is changed.
for _host in "${SELECTED_HOSTS[@]}"; do
  _host_write_module "$REPO_ROOT" "$_host" install_module >/dev/null
done
unset _host

# Claude's root resolver is intentionally lazy. A Codex/OpenCode-only install
# must neither require a valid Claude configuration nor create a .claude tree.
_INSTALL_CLAUDE=0
for _host in "${SELECTED_HOSTS[@]}"; do
  [[ "$_host" == "claude" ]] && _INSTALL_CLAUDE=1
done
unset _host
if [[ "$_INSTALL_CLAUDE" -eq 1 ]]; then
  # Link/copy refresh uses the prior receipt for ownership evidence. Read an old
  # Claude-local receipt in place when the canonical receipt does not yet exist;
  # preflight must stay mutation-free. A successful final manifest_flush writes
  # the canonical receipt and refreshes the compatibility mirror below.
  if [[ ! -f "$RECEIPT_PATH" && -n "$LEGACY_RECEIPT_PATH" && -f "$LEGACY_RECEIPT_PATH" ]]; then
    PM_DISPATCH_MANIFEST_PATH="$LEGACY_RECEIPT_PATH"
    export PM_DISPATCH_MANIFEST_PATH
  fi
  # shellcheck source=hosts/claude/lib/path-resolver.sh
  . "$REPO_ROOT/hosts/claude/lib/path-resolver.sh"
  _claude_root="$(claude_host_config_root 2>&1)" || {
    printf 'install: %s\n' "$_claude_root" >&2
    exit 2
  }
  CLAUDE_CONFIG_DIR="$_claude_root"
  CLAUDE_HOME="$CLAUDE_CONFIG_DIR"
  unset _claude_root
fi

_INSTALL_PLATFORM="$(detect_platform)"

link() {
  local src="$1" dest="$2" legacy_src="${3:-}"
  local rc
  # A domain relocation changes the source path without changing the installed
  # helper ABI. Refresh only an exact symlink owned by this checkout; foreign
  # symlinks and real files continue through link_or_copy's conflict policy.
  if [[ -n "$legacy_src" && -L "$dest" ]] \
      && _install_symlink_target_resolves_to "$dest" "$legacy_src"; then
    if [[ "$DRY_RUN" -eq 1 ]]; then
      echo "  would refresh $dest -> $src"
      manifest_record "$src" "$dest" symlink || return 1
      return 0
    fi
    rm "$dest"
  fi
  link_or_copy "$src" "$dest"
  rc=$?
  case "$rc" in
    0) return 0 ;;
    1) _COPY_FALLBACK_COUNT=$((_COPY_FALLBACK_COUNT + 1)); return 0 ;;
    2|3) return 1 ;;
    *) return 1 ;;
  esac
}

# Read-only ownership probe for runtime paths that an installed copied
# entrypoint will source. Reuse link_or_copy's exact symlink/receipt/SHA policy
# under dry-run, while restoring this transaction's pending receipt records.
_install_load_bearing_path_ready() {
  local src="$1" dst="$2" old_dry_run="$DRY_RUN" rc=0
  local -a saved_records=("${_PORTABLE_MANIFEST_RECORDS[@]}")
  DRY_RUN=1
  if ! link "$src" "$dst" >/dev/null 2>&1; then
    rc=1
  fi
  DRY_RUN="$old_dry_run"
  _PORTABLE_MANIFEST_RECORDS=("${saved_records[@]}")
  return "$rc"
}

# Canonical receipt-owned copy bundle. Preflight and apply intentionally consume
# these same parallel arrays: adding a runtime dependency, asset, or installed
# entrypoint cannot update one phase while silently skipping the other.
_INSTALL_BUNDLE_PHASES=()
_INSTALL_BUNDLE_LABELS=()
_INSTALL_BUNDLE_SRCS=()
_INSTALL_BUNDLE_DSTS=()
_INSTALL_MANAGED_TREES=(agents adapters)

_install_bundle_add() {
  _INSTALL_BUNDLE_PHASES+=("$1")
  _INSTALL_BUNDLE_LABELS+=("$2")
  _INSTALL_BUNDLE_SRCS+=("$3")
  _INSTALL_BUNDLE_DSTS+=("$4")
}

_install_bundle_init() {
  local _lib _adapter
  [[ "${#_INSTALL_BUNDLE_SRCS[@]}" -eq 0 ]] || return 0

  _install_bundle_add dependency gate-runtime \
    "$REPO_ROOT/runtime/lib" "$CLAUDE_HOME/scripts/lib"
  _install_bundle_add dependency gate-isolation-policy \
    "$REPO_ROOT/core/policy/isolation-level.yaml" \
    "$CLAUDE_HOME/scripts/core/policy/isolation-level.yaml"
  _install_bundle_add dependency adapter-usage \
    "$REPO_ROOT/ops/usage/log-usage.sh" \
    "$CLAUDE_HOME/ops/usage/log-usage.sh"

  # Built-in Adapter bootstrap and installed dispatch resolution share one
  # canonical dependency inventory with Adapter self-snapshots.
  while IFS= read -r _lib; do
    [[ -n "$_lib" ]] || continue
    _install_bundle_add dependency "adapter-runtime:${_lib%.sh}" \
      "$REPO_ROOT/runtime/lib/$_lib" "$CLAUDE_HOME/runtime/lib/$_lib"
  done < <(dc_installed_adapter_lib_names)

  for _adapter in codex claude opencode grok; do
    _install_bundle_add dependency "adapter-alias:$_adapter" \
      "$REPO_ROOT/share/$_adapter-model-aliases.tsv" \
      "$CLAUDE_HOME/share/$_adapter-model-aliases.tsv"
  done

  # Load-bearing helpers are published only after every dependency and managed
  # reviewer/Adapter tree has been installed successfully.
  _install_bundle_add entrypoint pr-gate \
    "$REPO_ROOT/runtime/bin/pr-gate.sh" "$CLAUDE_HOME/scripts/pr-gate.sh"
  _install_bundle_add entrypoint doctor \
    "$REPO_ROOT/runtime/bin/doctor.sh" "$CLAUDE_HOME/scripts/doctor.sh"
}

_install_bundle_preflight() {
  local i conflicts=0
  _install_bundle_init
  for ((i = 0; i < ${#_INSTALL_BUNDLE_SRCS[@]}; i++)); do
    if ! _install_load_bearing_path_ready \
        "${_INSTALL_BUNDLE_SRCS[i]}" "${_INSTALL_BUNDLE_DSTS[i]}"; then
      printf 'install: load-bearing copy bundle conflict: %s\n' \
        "${_INSTALL_BUNDLE_DSTS[i]}" >&2
      conflicts=$((conflicts + 1))
    fi
  done
  [[ "$conflicts" -eq 0 ]] || {
    printf 'install: refusing to wire copied entrypoints with %s unresolved load-bearing conflict(s)\n' \
      "$conflicts" >&2
    return 1
  }
}

_install_bundle_apply_phase() {
  local phase="$1" i attempted=0 conflicts=0 dst_parent
  printf '==> load-bearing %s bundle\n' "$phase"
  for ((i = 0; i < ${#_INSTALL_BUNDLE_SRCS[@]}; i++)); do
    [[ "${_INSTALL_BUNDLE_PHASES[i]}" == "$phase" ]] || continue
    attempted=$((attempted + 1))
    dst_parent="${_INSTALL_BUNDLE_DSTS[i]%/*}"
    if [[ ! -d "$dst_parent" ]]; then
      if [[ "$DRY_RUN" -eq 1 ]]; then
        printf '  would mkdir %s\n' "$dst_parent"
      else
        mkdir -p -- "$dst_parent"
      fi
    fi
    if ! link "${_INSTALL_BUNDLE_SRCS[i]}" "${_INSTALL_BUNDLE_DSTS[i]}"; then
      printf 'install: load-bearing bundle item changed after preflight: %s (%s)\n' \
        "${_INSTALL_BUNDLE_DSTS[i]}" "${_INSTALL_BUNDLE_LABELS[i]}" >&2
      conflicts=$((conflicts + 1))
    fi
  done
  printf '  (%s attempted, %s conflicts)\n' "$attempted" "$conflicts"
  [[ "$conflicts" -eq 0 ]]
}

_install_managed_tree_source_ready() {
  local tree="$1" entry found=0
  [[ -d "$REPO_ROOT/$tree" && -r "$REPO_ROOT/$tree" ]] || return 1
  for entry in "$REPO_ROOT/$tree"/*; do
    [[ -e "$entry" ]] || continue
    found=1
    break
  done
  [[ "$found" -eq 1 ]]
}

remove_legacy_symlink() {
  local path="$1" old_target="$2"
  [[ -L "$path" ]] || return 0
  local current
  current="$(readlink "$path")"
  [[ "$current" == "$old_target" ]] || return 0
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "  would remove (legacy) $path"
  else
    rm "$path"
    echo "  remove (legacy) $path"
  fi
}

install_dispatch_allowlist() {
  local settings="$CLAUDE_HOME/settings.json"
  local previous_adapter_src="" previous_repo_root="" previous_repo_rel=""
  local current_repo_rel=""

  previous_adapter_src="$(_portable_manifest_prev_symlink_src \
    "$(_portable_normalize_path "$CLAUDE_HOME/adapters/claude")" || true)"
  case "$previous_adapter_src" in
    */adapters/claude) previous_repo_root="${previous_adapter_src%/adapters/claude}" ;;
  esac
  if [[ -n "$previous_repo_root" && "$previous_repo_root" == "$HOME/"* ]]; then
    previous_repo_rel="${previous_repo_root#"$HOME/"}"
  fi
  if [[ "$REPO_ROOT" == "$HOME/"* ]]; then
    current_repo_rel="${REPO_ROOT#"$HOME/"}"
  fi

  # Collect all managed dispatch entries once (avoids re-running the generator
  # per iteration and lets us batch jq calls below).
  local -a _all_entries=()
  local _entry
  while IFS= read -r _entry; do
    _all_entries+=("$_entry")
  done < <(dispatch_allowlist_entries)
  [[ "${#_all_entries[@]}" -gt 0 ]] || return 0
  local _all_entries_json
  _all_entries_json="$(printf '%s\n' "${_all_entries[@]}" | jq -R . | jq -s .)"

  # One jq read to learn which entries are already present.
  local _present=""
  if [[ -f "$settings" ]]; then
    _present="$(jq -r '.permissions.allow // [] | .[]' "$settings" 2>/dev/null || true)"
  fi

  if [[ "$DRY_RUN" -eq 1 ]]; then
    if [[ -n "$previous_repo_root" && "$previous_repo_root" != "$REPO_ROOT" ]] \
        && { grep -Fq "$previous_repo_root/adapters/" "$settings" 2>/dev/null \
          || { [[ -n "$previous_repo_rel" ]] \
            && grep -Fq "~/$previous_repo_rel/adapters/" "$settings" 2>/dev/null; }; }; then
      printf '  permissions.allow: would remove stale managed entries for %s\n' "$previous_repo_root"
    fi
    if [[ -f "$settings" ]] && jq -e \
      --arg root "$REPO_ROOT" --arg rel "$current_repo_rel" \
      --argjson keep "$_all_entries_json" '
        any((.permissions.allow // [])[]?; . as $entry |
          ((startswith("Bash(" + $root + "/adapters/") or
            ($rel != "" and startswith("Bash(~/" + $rel + "/adapters/"))) and
           (($keep | index($entry)) == null)))
      ' "$settings" >/dev/null 2>&1; then
      printf '  permissions.allow: would remove stale manifest entrypoints for %s\n' "$REPO_ROOT"
    fi
    for _entry in "${_all_entries[@]}"; do
      if printf '%s\n' "$_present" | grep -qxF -- "$_entry" 2>/dev/null; then
        printf '  permissions.allow: would skip (present) %s\n' "$_entry"
      else
        printf '  permissions.allow: would add   %s\n' "$_entry"
      fi
    done
    return 0
  fi

  if [[ ! -f "$settings" ]]; then
    mkdir -p "$(dirname "$settings")"
    printf '{}\n' > "$settings"
    _present=""
  fi
  local _backup_ts
  _backup_ts="$(date +%Y%m%d-%H%M%S)"
  while [[ -e "${settings}.bak.${_backup_ts}" ]]; do
    sleep 1
    _backup_ts="$(date +%Y%m%d-%H%M%S)"
  done
  cp "$settings" "${settings}.bak.${_backup_ts}"
  printf '  settings.json: backup at %s.bak.%s\n' "$settings" "$_backup_ts"

  if [[ -n "$previous_repo_root" && "$previous_repo_root" != "$REPO_ROOT" ]]; then
    jq --arg old "$previous_repo_root" --arg old_rel "$previous_repo_rel" '
      .permissions.allow = ((.permissions.allow // []) | map(select(
        (startswith("Bash(" + $old + "/adapters/") or
         ($old_rel != "" and startswith("Bash(~/" + $old_rel + "/adapters/"))) | not
      )))
    ' "$settings" > "${settings}.tmp"
    mv "${settings}.tmp" "$settings"
    _present="$(jq -r '.permissions.allow // [] | .[]' "$settings" 2>/dev/null || true)"
  fi

  # A manifest-only executable rename must revoke the permission for the old
  # entrypoint in this same checkout. Entries below adapters/ are installer-
  # managed; keep only the exact current manifest-derived set.
  jq --arg root "$REPO_ROOT" --arg rel "$current_repo_rel" \
    --argjson keep "$_all_entries_json" '
      .permissions.allow = ((.permissions.allow // []) | map(
        . as $entry | select(
          (((startswith("Bash(" + $root + "/adapters/") or
             ($rel != "" and startswith("Bash(~/" + $rel + "/adapters/"))) and
            (($keep | index($entry)) == null))) | not
        )
      ))
    ' "$settings" > "${settings}.tmp"
  mv "${settings}.tmp" "$settings"
  _present="$(jq -r '.permissions.allow // [] | .[]' "$settings" 2>/dev/null || true)"

  # Identify missing entries and print status; then add all at once (one write).
  local -a _missing=()
  for _entry in "${_all_entries[@]}"; do
    if printf '%s\n' "$_present" | grep -qxF -- "$_entry" 2>/dev/null; then
      printf '  permissions.allow: present %s\n' "$_entry"
    else
      _missing+=("$_entry")
      printf '  permissions.allow: added   %s\n' "$_entry"
    fi
  done

  if [[ "${#_missing[@]}" -gt 0 ]]; then
    local _missing_json
    _missing_json="$(printf '%s\n' "${_missing[@]}" | jq -R . | jq -s .)"
    jq --argjson new "$_missing_json" \
       '.permissions.allow = ((.permissions.allow // []) + $new)' \
       "$settings" > "${settings}.tmp" && mv "${settings}.tmp" "$settings"
  fi
}

install_dir_junction() {
  local subdir="$1"
  local src_dir="$REPO_ROOT/$subdir"
  local dest_dir="$CLAUDE_HOME/$subdir"

  if [[ "$subdir" == agents || "$subdir" == adapters ]]; then
    if ! _install_managed_tree_source_ready "$subdir"; then
      printf 'install: load-bearing %s source tree changed after preflight\n' \
        "$subdir" >&2
      return 1
    fi
  fi
  [[ -d "$src_dir" ]] || { echo "skip $subdir (no source)"; return 0; }

  echo "==> $subdir (windows junction)"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "  would junction $dest_dir -> $src_dir"
    manifest_record "$src_dir" "$dest_dir" junction || true
    return 0
  fi

  # If dest is already a junction pointing to our src, treat as idempotent.
  if [[ -d "$dest_dir" && -L "$dest_dir" ]]; then
    local existing_target
    existing_target="$(readlink "$dest_dir" 2>/dev/null || true)"
    if [[ "$existing_target" == "$src_dir" ]]; then
      echo "  ok    $dest_dir (junction already correct)"
      manifest_record "$src_dir" "$dest_dir" junction || true
      return 0
    fi
  fi

  # If dest exists as a non-junction real directory, fall back to per-file copy
  # to preserve any unrelated entries (e.g. agents from other tools).
  if [[ -d "$dest_dir" && ! -L "$dest_dir" ]]; then
    printf 'install: %s is an existing real directory — per-file copy to preserve coexistence\n' "$subdir" >&2
    install_dir "$subdir"
    return
  fi

  if [[ ! -d "$CLAUDE_HOME" ]]; then
    mkdir -p "$CLAUDE_HOME"
  fi

  # Attempt junction creation.
  if make_junction_windows "$src_dir" "$dest_dir"; then
    echo "  junction $dest_dir -> $src_dir"
    manifest_record "$src_dir" "$dest_dir" junction || return 1
    return 0
  fi

  # Junction failed - fall back to per-file copy via install_dir().
  printf 'install: junction failed for %s - falling back to per-file copy\n' "$subdir" >&2
  install_dir "$subdir"
}

install_dir() {
  local subdir="$1"
  local src_dir="$REPO_ROOT/$subdir"
  local dest_dir="$CLAUDE_HOME/$subdir"

  if [[ "$subdir" == agents || "$subdir" == adapters ]]; then
    if ! _install_managed_tree_source_ready "$subdir"; then
      printf 'install: load-bearing %s source tree changed after preflight\n' \
        "$subdir" >&2
      return 1
    fi
  fi
  [[ -d "$src_dir" ]] || { echo "skip $subdir (no source)"; return 0; }

  echo "==> $subdir"
  if [[ ! -d "$dest_dir" ]]; then
    if [[ "$DRY_RUN" -eq 1 ]]; then
      echo "  would mkdir $dest_dir"
    else
      mkdir -p "$dest_dir"
      echo "  mkdir  $dest_dir"
    fi
  fi

  shopt -s nullglob
  local count=0 conflicts=0
  for src in "$src_dir"/*; do
    [[ -e "$src" ]] || continue
    local name
    name="$(basename "$src")"
    if link "$src" "$dest_dir/$name"; then
      count=$((count + 1))
    else
      conflicts=$((conflicts + 1))
    fi
  done
  shopt -u nullglob
  echo "  ($count linked, $conflicts conflicts)"
  if [[ ( "$conflicts" -gt 0 || "$count" -eq 0 ) \
      && ( "$subdir" == agents || "$subdir" == adapters ) ]]; then
    printf 'install: load-bearing %s tree changed after preflight\n' "$subdir" >&2
    return 1
  fi
}

_install_symlink_target_resolves_to() {
  local dst="$1"
  local want="$2"
  local link_target
  local normalized_target

  link_target="$(readlink "$dst")"
  if [[ "$link_target" == "$want" ]]; then
    return 0
  fi

  case "$link_target" in
    /*|[A-Za-z]:/*)
      normalized_target="$(_portable_normalize_path "$link_target")"
      ;;
    *)
      normalized_target="$(_portable_normalize_path "$(dirname "$dst")/$link_target")"
      ;;
  esac

  [[ "$normalized_target" == "$want" ]]
}

_install_path_contains_dir() {
  local dir="$1"
  case ":${PATH:-}:" in
    *":$dir:"*) return 0 ;;
    *) return 1 ;;
  esac
}

_install_pmctl_checkout_target() {
  local target="$1" old_root
  case "$target" in
    */cli/pmctl) old_root="${target%/cli/pmctl}" ;;
    *) return 1 ;;
  esac
  [[ -f "$old_root/install.sh" && -f "$old_root/uninstall.sh" \
      && -d "$old_root/adapters" && -x "$target" ]]
}

install_pmctl_cli() {
  local src="$REPO_ROOT/cli/pmctl"
  local bin_dir="${PMCTL_BIN_DIR:-$HOME/.local/bin}"
  local dest="$bin_dir/pmctl"

  echo "==> pmctl CLI"

  if [[ "$_INSTALL_PLATFORM" == "windows" ]]; then
    if [[ "$DRY_RUN" -eq 1 ]]; then
      echo "  would skip installing $dest"
    else
      echo "  skip  $dest"
    fi
    echo "  add $REPO_ROOT/cli to PATH manually"
    echo "  note: pmctl must run from the repo checkout; a copied pmctl cannot resolve repo libs"
    return 0
  fi

  if [[ ! -d "$bin_dir" ]]; then
    if [[ "$DRY_RUN" -eq 1 ]]; then
      echo "  would mkdir $bin_dir"
    else
      mkdir -p "$bin_dir"
      echo "  mkdir  $bin_dir"
    fi
  fi

  if [[ -L "$dest" ]]; then
    if _install_symlink_target_resolves_to "$dest" "$src"; then
      echo "  ok    $dest"
    elif _previous_src="$(_portable_manifest_prev_symlink_src "$(_portable_normalize_path "$dest")" || true)" \
        && [[ -n "$_previous_src" ]] \
        && _install_symlink_target_resolves_to "$dest" "$_previous_src"; then
      if [[ "$DRY_RUN" -eq 1 ]]; then
        echo "  would refresh $dest -> $src"
      else
        rm "$dest"
        ln -s "$src" "$dest"
        echo "  refresh $dest -> $src"
      fi
    elif _old_pmctl_target="$(_portable_resolve_symlink "$dest")" \
        && _install_pmctl_checkout_target "$_old_pmctl_target"; then
      if [[ "$DRY_RUN" -eq 1 ]]; then
        echo "  would refresh $dest -> $src"
      else
        rm "$dest"
        ln -s "$src" "$dest"
        echo "  refresh $dest -> $src"
      fi
    else
      printf '  CONFLICT %s -> %s (expected %s)\n' "$dest" "$(readlink "$dest")" "$src" >&2
    fi
  elif [[ -e "$dest" ]]; then
    printf '  CONFLICT %s exists and is not our symlink — skipping\n' "$dest" >&2
  elif [[ "$DRY_RUN" -eq 1 ]]; then
    echo "  would link $dest -> $src"
  else
    ln -s "$src" "$dest"
    echo "  link   $dest -> $src"
  fi

  if [[ -L "$dest" ]] && _install_symlink_target_resolves_to "$dest" "$src"; then
    manifest_record "$src" "$dest" symlink || return 1
  fi

  if ! _install_path_contains_dir "$bin_dir"; then
    echo "  note: $bin_dir is not on PATH; add: export PATH=\"$bin_dir:\$PATH\""
  fi
}

echo "pm-dispatch installer"
echo "  repo:        $REPO_ROOT"
if [[ "$_INSTALL_CLAUDE" -eq 1 ]]; then
  echo "  claude home: $CLAUDE_HOME"
else
  echo "  hosts:       ${SELECTED_HOSTS[*]}"
fi
if [[ "$DRY_RUN" -eq 1 ]]; then echo "  mode:        DRY RUN"; fi
echo

# Preflight tests run only when explicitly requested with --verify.
# Skipped when called from test-install.sh (CLAUDE_CONFIG_TEST_INSTALL_RUNNING=1).
if [[ "${CLAUDE_CONFIG_TEST_INSTALL_RUNNING:-0}" == "1" ]]; then
  _SKIP_PREFLIGHT=1
  echo "  [preflight skipped: CLAUDE_CONFIG_TEST_INSTALL_RUNNING=1]"
  echo
elif [[ "$VERIFY" -eq 1 ]]; then
  _SKIP_PREFLIGHT=0
else
  _SKIP_PREFLIGHT=1
  echo "  [preflight tests skipped — pass --verify to run them]"
  echo
fi

if [[ "$VERIFY" -eq 1 ]] && [[ "$_SKIP_PREFLIGHT" != "1" ]]; then
  echo "==> preflight tests"
  # _PM_DISPATCH_PREFLIGHT_RUNNER lets tests inject a stub without touching
  # the real run-all-tests.sh (default). Never set this in production use.
  bash "${_PM_DISPATCH_PREFLIGHT_RUNNER:-$REPO_ROOT/tests/bin/run-all-tests.sh}"
  echo
fi

# Validate every selected host before the Claude product install mutates
# anything. Host installers define --dry-run as a read-only ownership and
# conflict check, so a user-owned policy fails the whole multi-host operation
# at the transaction boundary instead of leaving a partial install behind.
_HAS_NON_CLAUDE_SELECTION=0
for _host in "${SELECTED_HOSTS[@]}"; do
  [[ "$_host" != "claude" ]] && _HAS_NON_CLAUDE_SELECTION=1
done
unset _host
if [[ "$DRY_RUN" -eq 0 && "$_HAS_NON_CLAUDE_SELECTION" -eq 1 ]]; then
  echo "==> selected host preflight"
  _preflighted_hosts=" "
  for _host in "${SELECTED_HOSTS[@]}"; do
    # The Claude compatibility installer creates its minimal settings file
    # later in this transaction; asking its hook module to dry-run first would
    # reject a clean Claude home before that documented bootstrap step.
    [[ "$_host" == "claude" ]] && continue
    [[ "$_preflighted_hosts" == *" $_host "* ]] && continue
    _preflighted_hosts+="$_host "
    host_write_install "$REPO_ROOT" "$_host" 1 >/dev/null
    echo "  ok    $_host"
  done
  unset _host _preflighted_hosts
  echo
fi
unset _HAS_NON_CLAUDE_SELECTION

# A selected non-Claude host owns only its manifest-declared configuration.
# Do not run the historical Claude product installer as a hidden base step:
# that would create ~/.claude in a Codex/OpenCode-only environment.
if [[ "$_INSTALL_CLAUDE" -eq 0 ]]; then
  echo "==> selected host modules"
  for _host in "${SELECTED_HOSTS[@]}"; do
    echo "  $_host"
    host_write_install "$REPO_ROOT" "$_host" "$DRY_RUN"
  done
  unset _host
  if ! manifest_flush "$RECEIPT_PATH" "$REPO_ROOT" "$(IFS=,; echo "${SELECTED_HOSTS[*]}")"; then
    echo "install: product receipt write failed" >&2
    exit 3
  fi
  echo "Done."
  [[ "$DRY_RUN" -eq 1 ]] && echo "(no changes made — re-run without --dry-run to apply)"
  exit 0
fi

# Fail before installing Adapter trees or helper entrypoints when any canonical
# copy-mode dependency is missing, foreign, or locally modified. Otherwise a
# successful install could leave trusted entrypoints sourcing non-receipt-owned
# bytes. Preflight and apply consume the same canonical bundle inventory above.
_install_bundle_preflight || exit 1

# Adapter implementations and reviewer definitions are load-bearing trusted
# inputs. They are per-entry on POSIX/copy fallback, but may each be one Windows
# junction. A receipt-owned junction is already canonical; an existing real
# coexistence directory is probed per shipped entry so unrelated custom names
# remain allowed while foreign built-ins/reviewers cannot shadow shipped code.
_load_bearing_conflicts=0
for _load_bearing_tree in "${_INSTALL_MANAGED_TREES[@]}"; do
  if ! _install_managed_tree_source_ready "$_load_bearing_tree"; then
    printf 'install: required load-bearing source tree is missing or empty: %s\n' \
      "$REPO_ROOT/$_load_bearing_tree" >&2
    _load_bearing_conflicts=$((_load_bearing_conflicts + 1))
    continue
  fi
  _load_bearing_root="$CLAUDE_HOME/$_load_bearing_tree"
  if [[ "$_INSTALL_PLATFORM" == windows \
      && ( ! -e "$_load_bearing_root" || -L "$_load_bearing_root" ) ]]; then
    if ! _install_load_bearing_path_ready \
        "$REPO_ROOT/$_load_bearing_tree" "$_load_bearing_root"; then
      printf 'install: load-bearing copy bundle conflict: %s\n' "$_load_bearing_root" >&2
      _load_bearing_conflicts=$((_load_bearing_conflicts + 1))
    fi
  else
    for _load_bearing_src in "$REPO_ROOT/$_load_bearing_tree"/*; do
      [[ -e "$_load_bearing_src" || -L "$_load_bearing_src" ]] || continue
      _load_bearing_dst="$_load_bearing_root/${_load_bearing_src##*/}"
      if ! _install_load_bearing_path_ready "$_load_bearing_src" "$_load_bearing_dst"; then
        printf 'install: load-bearing copy bundle conflict: %s\n' "$_load_bearing_dst" >&2
        _load_bearing_conflicts=$((_load_bearing_conflicts + 1))
      fi
    done
  fi
done
unset _load_bearing_tree _load_bearing_root _load_bearing_src _load_bearing_dst
if [[ "$_load_bearing_conflicts" -gt 0 ]]; then
  printf 'install: refusing to wire copied entrypoints with %s unresolved load-bearing conflict(s)\n' \
    "$_load_bearing_conflicts" >&2
  exit 1
fi
unset _load_bearing_conflicts

install_pmctl_cli
echo

SCRIPTS_DEST="$CLAUDE_HOME/scripts"
if [[ ! -d "$SCRIPTS_DEST" ]]; then
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "  would mkdir $SCRIPTS_DEST"
  else
    mkdir -p "$SCRIPTS_DEST"
    echo "  mkdir  $SCRIPTS_DEST"
  fi
fi

# Install every runtime/policy/asset dependency before publishing reviewer or
# Adapter entrypoints. A post-preflight failure therefore cannot expose a copied
# Adapter that is already visible but unable to bootstrap.
_install_bundle_apply_phase dependency || exit 1
echo

# Non-load-bearing coexistence trees retain their established install behavior.
if [[ "$_INSTALL_PLATFORM" == "windows" ]]; then
  install_dir_junction skills
  install_dir_junction commands
else
  install_dir skills
  install_dir commands
fi

# Reviewer definitions and Adapter implementations are trusted executable
# inputs. Their names come from the same managed-tree inventory as preflight.
for _managed_tree in "${_INSTALL_MANAGED_TREES[@]}"; do
  if [[ "$_INSTALL_PLATFORM" == "windows" ]]; then
    install_dir_junction "$_managed_tree" || exit 1
  else
    install_dir "$_managed_tree" || exit 1
  fi
done
unset _managed_tree

echo "==> legacy cleanup"
remove_legacy_symlink "$SCRIPTS_DEST/codex-pr-gate.sh" "$REPO_ROOT/scripts/codex-pr-gate.sh"
remove_legacy_symlink "$CLAUDE_HOME/commands/codex-pr-gate.md" "$REPO_ROOT/commands/codex-pr-gate.md"
remove_legacy_symlink "$CLAUDE_HOME/commands/caveman.md" "$REPO_ROOT/commands/caveman.md"
remove_legacy_symlink "$CLAUDE_HOME/commands/caveman-commit.md" "$REPO_ROOT/commands/caveman-commit.md"
remove_legacy_symlink "$SCRIPTS_DEST/claude-usage.sh" "$REPO_ROOT/scripts/claude-usage.sh"
remove_legacy_symlink "$SCRIPTS_DEST/codex-dispatch.sh" "$REPO_ROOT/scripts/codex-dispatch.sh"

echo "==> helper scripts"
us_count=0; us_conflicts=0
# Allowlist: user-facing scripts only. Excluded intentionally:
#   test-*.sh   — run as install preflights above, not user tools
#   hook-*.sh   — wired by install-guards.sh, not standalone user tools
#   lint-*.sh   — internal CI helpers
helper_specs=(
  $'token-usage.sh\tops/usage/token-usage.sh\tscripts/token-usage.sh'
  $'log-usage.sh\tops/usage/log-usage.sh\tscripts/log-usage.sh'
  $'setup-project.sh\tops/setup/setup-project.sh\tscripts/setup-project.sh'
  $'patch-gitignore.sh\tops/setup/patch-gitignore.sh\tscripts/patch-gitignore.sh'
)
for helper_spec in "${helper_specs[@]}"; do
  IFS=$'\t' read -r script source_path legacy_source_path <<< "$helper_spec"
  if link "$REPO_ROOT/$source_path" "$SCRIPTS_DEST/$script" "$REPO_ROOT/$legacy_source_path"; then
    us_count=$((us_count + 1))
  else
    us_conflicts=$((us_conflicts + 1))
  fi
done
echo "  ($us_count linked, $us_conflicts conflicts)"

echo

# pm-schema: symlink ~/.claude/.pm -> pm-dispatch/pm so cross-repo
# path references (rollup.sh default out, memory prose, schema.md
# consumers) keep working.
PM_SRC="$REPO_ROOT/pm"
PM_DEST="$CLAUDE_HOME/.pm"
if [[ -d "$PM_SRC" ]]; then
  echo "==> pm-schema"
  pm_conflicts=0
  if [[ "$_INSTALL_PLATFORM" == "windows" ]]; then
    if [[ "$DRY_RUN" -eq 1 ]]; then
      echo "  would junction $PM_DEST -> $PM_SRC"
      manifest_record "$PM_SRC" "$PM_DEST" junction || pm_conflicts=$((pm_conflicts + 1))
    elif ! make_junction_windows "$PM_SRC" "$PM_DEST"; then
      link "$PM_SRC" "$PM_DEST" || pm_conflicts=$((pm_conflicts + 1))
    else
      echo "  junction $PM_DEST -> $PM_SRC"
      manifest_record "$PM_SRC" "$PM_DEST" junction || pm_conflicts=$((pm_conflicts + 1))
    fi
  else
    link "$PM_SRC" "$PM_DEST" || pm_conflicts=$((pm_conflicts + 1))
  fi
  echo "  (1 attempted, $pm_conflicts conflicts)"
  if [[ "$pm_conflicts" -gt 0 ]]; then
    echo "install.sh: pm-schema symlink failed — resolve conflict before continuing" >&2
    exit 1
  fi
else
  echo "skip pm-schema (no source)"
fi

echo
echo "==> hooks"
if [[ "$DRY_RUN" -eq 1 ]]; then
  if [[ ! -f "$CLAUDE_HOME/settings.json" ]]; then
    echo "  would create $CLAUDE_HOME/settings.json (minimal, for hook wiring)"
    echo "  (hook wiring dry-run skipped — settings.json would be created first)"
  else
    # CLAUDE_HOME passed per-call (not exported) so it scopes to hook wiring only
    # and does NOT leak into --verify's run-all-tests preflight (which spawns
    # nested installs that must default CLAUDE_HOME to their own HOME).
    if [[ -n "$PROFILE" ]]; then
      CLAUDE_CONFIG_DIR="$CLAUDE_CONFIG_DIR" host_write_install "$REPO_ROOT" claude 1 --profile "$PROFILE"
    else
      CLAUDE_CONFIG_DIR="$CLAUDE_CONFIG_DIR" host_write_install "$REPO_ROOT" claude 1
    fi
  fi
else
  if [[ ! -f "$CLAUDE_HOME/settings.json" ]]; then
    mkdir -p "$CLAUDE_HOME"
    printf '{}\n' > "$CLAUDE_HOME/settings.json"
    echo "  created $CLAUDE_HOME/settings.json (minimal, for hook wiring)"
  fi
  # CLAUDE_HOME and PM_DISPATCH_REPO passed per-call (not exported) so they scope
  # to hook wiring only and do not leak into nested install runs.
  if [[ -n "$PROFILE" ]]; then
    CLAUDE_CONFIG_DIR="$CLAUDE_CONFIG_DIR" host_write_install "$REPO_ROOT" claude 0 --profile "$PROFILE"
  else
    CLAUDE_CONFIG_DIR="$CLAUDE_CONFIG_DIR" host_write_install "$REPO_ROOT" claude 0
  fi
fi
echo

echo "==> dispatch permissions.allow"
install_dispatch_allowlist
echo

# Selected host wiring is dispatched through manifest module paths. It is
# never auto-detected from a binary on PATH because these policies affect every
# session using the host's global config.
_installed_hosts=" claude "
for _host in "${SELECTED_HOSTS[@]}"; do
  [[ "$_installed_hosts" == *" $_host "* ]] && continue
  _installed_hosts+="$_host "
  echo "==> $_host host"
  host_write_install "$REPO_ROOT" "$_host" "$DRY_RUN"
  echo
done
unset _host _installed_hosts _enable_host _HOST_WRITE_AVAILABLE

# Publish trusted user-facing Gate/doctor entrypoints last. Every runtime,
# policy, asset, reviewer, Adapter, permission, and selected-host dependency is
# now installed; a failure above cannot leave a newly visible partial entrypoint.
echo "==> load-bearing entrypoints"
_install_bundle_apply_phase entrypoint || exit 1

if [[ "$_COPY_FALLBACK_COUNT" -gt 0 && "$DRY_RUN" -eq 0 ]]; then
  echo
  echo "Note: $_COPY_FALLBACK_COUNT file(s) installed or refreshed via copy (symlink unavailable)."
  echo "      Re-run install.sh after pulling to keep copied files up to date."
fi

echo "Done."
if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "(no changes made — re-run without --dry-run to apply)"
fi

if ! manifest_flush "$RECEIPT_PATH" "$REPO_ROOT" "$(IFS=,; echo "${SELECTED_HOSTS[*]}")"; then
  echo "install: product receipt write failed" >&2
  exit 3
fi
# Keep the old location as a bounded read-only compatibility mirror for
# installed helper versions that still look there.  New uninstall/doctor paths
# always prefer the product receipt above.
if [[ "$DRY_RUN" -eq 0 && -n "$LEGACY_RECEIPT_PATH" ]]; then
  mkdir -p "${LEGACY_RECEIPT_PATH%/*}"
  cp "$RECEIPT_PATH" "$LEGACY_RECEIPT_PATH"
fi
if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "dispatch allowlist dry-run complete"
fi
