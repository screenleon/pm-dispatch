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

# Receipt JSON is parsed in one place so install refresh, doctor, and uninstall
# all agree on escaping and schema failures.  The arrays are intentionally
# global: callers can inspect a successfully validated snapshot without piping
# through a line-oriented format that cannot represent newlines in paths.
PM_DISPATCH_RECEIPT_SELECTED_HOSTS=()
PM_DISPATCH_RECEIPT_ENTRY_SRCS=()
PM_DISPATCH_RECEIPT_ENTRY_DSTS=()
PM_DISPATCH_RECEIPT_ENTRY_MODES=()
PM_DISPATCH_RECEIPT_ENTRY_SHA256S=()
PM_DISPATCH_RECEIPT_ENTRY_DIGEST_SCHEMES=()
PM_DISPATCH_RECEIPT_MANIFEST_VERSION_STATUS="missing"

pm_dispatch_receipt_require_jq() {
  if command -v jq >/dev/null 2>&1; then
    return 0
  fi
  printf 'install receipt: jq is required to read install-manifest.json safely\n' >&2
  return 2
}

# Parse and fully validate one receipt snapshot. Every product-receipt reader
# delegates here; fixed-width NUL records preserve all legal pathname bytes.
# A missing manifest_version remains readable as legacy uninstall ownership;
# doctor can distinguish that compatibility state from the supported v1 schema.
pm_dispatch_receipt_load() {
  local path="${1-}" tmp kind f1 f2 f3 f4 f5 f6
  PM_DISPATCH_RECEIPT_SELECTED_HOSTS=()
  PM_DISPATCH_RECEIPT_ENTRY_SRCS=()
  PM_DISPATCH_RECEIPT_ENTRY_DSTS=()
  PM_DISPATCH_RECEIPT_ENTRY_MODES=()
  PM_DISPATCH_RECEIPT_ENTRY_SHA256S=()
  PM_DISPATCH_RECEIPT_ENTRY_DIGEST_SCHEMES=()
  PM_DISPATCH_RECEIPT_MANIFEST_VERSION_STATUS="missing"
  [[ -f "$path" ]] || return 0
  pm_dispatch_receipt_require_jq || return $?

  tmp="$(command -p mktemp "${TMPDIR:-/tmp}/pm-dispatch-receipt-entries.XXXXXX")" || {
    printf 'install receipt: could not create a temporary receipt snapshot\n' >&2
    return 2
  }
  if ! jq -j '
      def has_nul:
        # jq 1.6 contains(NUL) is true for every string; scan code points.
        any(explode[]; . == 0);
      def required_string($key):
        if (has($key) | not) or (.[$key] | type) != "string" then
          error("receipt entry " + $key + " must be a string")
        elif .[$key] | has_nul then
          error("receipt entry " + $key + " must not contain a NUL")
        else .[$key]
        end;
      def optional_string($key):
        if has($key) | not then
          ""
        elif (.[$key] | type) != "string" then
          error("receipt entry " + $key + " must be a string")
        elif .[$key] | has_nul then
          error("receipt entry " + $key + " must not contain a NUL")
        else .[$key]
        end;
      def version_status:
        if has("manifest_version") then
          if (.manifest_version | type) == "number" and .manifest_version == 1
          then "supported"
          else "unsupported"
          end
        else "legacy"
        end;
      if type != "object" then error("receipt root must be an object")
      elif has("selected_hosts") and (.selected_hosts | type) != "array"
        then error("selected_hosts must be an array")
      elif has("entries") and (.entries | type) != "array" then error("entries must be an array")
      elif ([.entries[]? | select(type == "object" and (.dst | type) == "string") | .dst]
          | group_by(.) | map(select(length > 1)) | length) > 0
        then error("receipt entries contain a duplicate destination")
      else
        "meta", "\u0000", version_status, "\u0000",
          "", "\u0000", "", "\u0000", "", "\u0000", "", "\u0000", "", "\u0000",
        ((.selected_hosts // [])[] |
          if (type == "string" and test("^[a-z0-9_-]+$")) then
            "host", "\u0000", ., "\u0000",
              "", "\u0000", "", "\u0000", "", "\u0000", "", "\u0000", "", "\u0000"
          else error("selected_hosts entries must be valid host names")
          end),
        ((.entries // [])[] |
          if type != "object" then error("receipt entries must be objects")
          else
            "entry", "\u0000",
            required_string("src"), "\u0000",
            required_string("dst"), "\u0000",
            required_string("mode"), "\u0000",
            optional_string("sha256"), "\u0000",
            optional_string("digest_scheme"), "\u0000",
            optional_string("fallback_reason"), "\u0000"
          end)
      end
    ' "$path" > "$tmp"; then
    printf 'install receipt: invalid receipt JSON or schema in %s\n' "$path" >&2
    command -p rm -f "$tmp"
    return 2
  fi

  while IFS= read -r -d '' kind \
      && IFS= read -r -d '' f1 \
      && IFS= read -r -d '' f2 \
      && IFS= read -r -d '' f3 \
      && IFS= read -r -d '' f4 \
      && IFS= read -r -d '' f5 \
      && IFS= read -r -d '' f6; do
    : "$f6" # fallback_reason is validated but not needed by ownership consumers.
    case "$kind" in
      meta)
        PM_DISPATCH_RECEIPT_MANIFEST_VERSION_STATUS="$f1"
        ;;
      host)
        PM_DISPATCH_RECEIPT_SELECTED_HOSTS+=("$f1")
        ;;
      entry)
        PM_DISPATCH_RECEIPT_ENTRY_SRCS+=("$f1")
        PM_DISPATCH_RECEIPT_ENTRY_DSTS+=("$f2")
        PM_DISPATCH_RECEIPT_ENTRY_MODES+=("$f3")
        PM_DISPATCH_RECEIPT_ENTRY_SHA256S+=("$f4")
        PM_DISPATCH_RECEIPT_ENTRY_DIGEST_SCHEMES+=("$f5")
        ;;
    esac
  done < "$tmp"
  command -p rm -f "$tmp"
  if [[ "$PM_DISPATCH_RECEIPT_MANIFEST_VERSION_STATUS" == unsupported ]]; then
    # Keep only the version result for diagnostics. Unknown schemas must never
    # lend ownership authority to refresh or uninstall consumers.
    PM_DISPATCH_RECEIPT_SELECTED_HOSTS=()
    PM_DISPATCH_RECEIPT_ENTRY_SRCS=()
    PM_DISPATCH_RECEIPT_ENTRY_DSTS=()
    PM_DISPATCH_RECEIPT_ENTRY_MODES=()
    PM_DISPATCH_RECEIPT_ENTRY_SHA256S=()
    PM_DISPATCH_RECEIPT_ENTRY_DIGEST_SCHEMES=()
    return 4
  fi
}

# Full-validation API for consumers that only need a yes/no schema result.
pm_dispatch_receipt_validate() {
  pm_dispatch_receipt_load "${1-}"
}

# Version API keeps the exact supported/unsupported decision inside this
# canonical reader. It performs full validation before producing a status.
pm_dispatch_receipt_version_status() {
  local rc=0
  pm_dispatch_receipt_load "${1-}" || rc=$?
  [[ "$rc" -eq 0 || "$rc" -eq 4 ]] || return "$rc"
  printf '%s\n' "$PM_DISPATCH_RECEIPT_MANIFEST_VERSION_STATUS"
  return "$rc"
}

# Compatibility accessors delegate to the full reader; no field has a second
# JSON parser. A missing selected_hosts remains the legacy Claude default.
pm_dispatch_receipt_load_selected_hosts() {
  pm_dispatch_receipt_load "${1-}"
}

pm_dispatch_receipt_selected_hosts() {
  local path="${1-}" host
  pm_dispatch_receipt_load "$path" || return $?
  for host in "${PM_DISPATCH_RECEIPT_SELECTED_HOSTS[@]}"; do
    printf '%s\n' "$host"
  done
}

pm_dispatch_receipt_load_entries() {
  pm_dispatch_receipt_load "${1-}"
}

# Remove the named hosts from a v2 receipt.  jq is already an install
# prerequisite; refusing to edit a receipt without it is safer than a lossy
# text rewrite.  Prints the remaining selected-host count.
pm_dispatch_receipt_remove_hosts() {
  local path="$1"
  shift
  [[ -f "$path" ]] || { printf '0\n'; return 0; }
  pm_dispatch_receipt_require_jq || return $?
  pm_dispatch_receipt_validate "$path" || return $?
  local remove_json='[]' host tmp remaining
  for host in "$@"; do
    remove_json="$(printf '%s' "$remove_json" | jq --arg host "$host" '. + [$host]')" || return 2
  done
  tmp="$(command -p mktemp "${path%/*}/.install-manifest.XXXXXX")" || return 2
  jq -c --argjson remove "$remove_json" \
    '.selected_hosts = ((.selected_hosts // []) | map(select(. as $host | ($remove | index($host) | not))))' \
    "$path" > "$tmp" || { command -p rm -f "$tmp"; return 2; }
  remaining="$(jq -r '.selected_hosts | length' "$tmp")" || { command -p rm -f "$tmp"; return 2; }
  command -p mv "$tmp" "$path" || { command -p rm -f "$tmp"; return 2; }
  printf '%s\n' "$remaining"
}
