#!/usr/bin/env bash
# Product-owned install receipt helpers. The receipt is independent of every
# host config root; the Claude-local manifest is migration-only compatibility.

pm_dispatch_install_root() {
  if [[ -n "${PM_DISPATCH_INSTALL_ROOT:-}" ]]; then
    printf '%s\n' "$PM_DISPATCH_INSTALL_ROOT"
  elif [[ -n "${HOME:-}" ]]; then
    printf '%s/.pm-dispatch\n' "$HOME"
  else
    printf 'install receipt: HOME is required (or set PM_DISPATCH_INSTALL_ROOT)\n' >&2
    return 1
  fi
}

pm_dispatch_receipt_path() {
  local root
  root="$(pm_dispatch_install_root)" || return $?
  printf '%s/install-manifest.json\n' "$root"
}

pm_dispatch_legacy_receipt_path() {
  local claude_root="${CLAUDE_CONFIG_DIR:-${CLAUDE_HOME:-${HOME:-}/.claude}}"
  [[ -n "$claude_root" ]] || return 1
  printf '%s/.pm-dispatch/install-manifest.json\n' "$claude_root"
}

pm_dispatch_receipt_existing_path() {
  local path legacy
  path="$(pm_dispatch_receipt_path)" || return $?
  if [[ -f "$path" ]]; then printf '%s\n' "$path"; return 0; fi
  legacy="$(pm_dispatch_legacy_receipt_path)" || return $?
  [[ -f "$legacy" ]] && printf '%s\n' "$legacy"
}

# A receipt without selected_hosts is a legacy Claude-base receipt and returns
# no hosts, allowing callers to preserve the legacy compatibility default.
pm_dispatch_receipt_selected_hosts() {
  local path="$1" raw host
  [[ -f "$path" ]] || return 0
  raw="$(sed -n 's/.*"selected_hosts"[[:space:]]*:[[:space:]]*\[\([^]]*\)\].*/\1/p' "$path")"
  [[ -n "$raw" ]] || return 0
  while IFS= read -r host; do
    [[ "$host" =~ ^[a-z0-9_-]+$ ]] && printf '%s\n' "$host"
  done < <(printf '%s\n' "$raw" | tr ',' '\n' | tr -d ' "')
}

# Remove the named hosts from a v2 receipt.  jq is already an install
# prerequisite; refusing to edit a receipt without it is safer than a lossy
# text rewrite.  Prints the remaining selected-host count.
pm_dispatch_receipt_remove_hosts() {
  local path="$1"
  shift
  [[ -f "$path" ]] || { printf '0\n'; return 0; }
  command -v jq >/dev/null 2>&1 || {
    printf 'install receipt: jq is required to update selected hosts\n' >&2
    return 2
  }
  local remove_json='[]' host tmp remaining
  for host in "$@"; do
    remove_json="$(printf '%s' "$remove_json" | jq --arg host "$host" '. + [$host]')" || return 2
  done
  tmp="$(mktemp "${path%/*}/.install-manifest.XXXXXX")" || return 2
  jq -c --argjson remove "$remove_json" \
    '.selected_hosts = ((.selected_hosts // []) | map(select(. as $host | ($remove | index($host) | not))))' \
    "$path" > "$tmp" || { rm -f "$tmp"; return 2; }
  remaining="$(jq -r '.selected_hosts | length' "$tmp")" || { rm -f "$tmp"; return 2; }
  mv "$tmp" "$path" || { rm -f "$tmp"; return 2; }
  printf '%s\n' "$remaining"
}
