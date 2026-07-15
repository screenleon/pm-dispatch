#!/usr/bin/env bash
# Safely reverse install-host-opencode.sh using its ownership receipt.
# shellcheck disable=SC1091
# Repo-local manifest/portable libraries are resolved dynamically below.

set -euo pipefail

DRY_RUN=0
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT=""
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --repo-root)
      [[ "$#" -ge 2 ]] || { printf 'uninstall-host-opencode: --repo-root requires a value\n' >&2; exit 2; }
      REPO_ROOT="$2"; shift 2 ;;
    *) printf 'uninstall-host-opencode: usage: uninstall-host-opencode.sh [--repo-root <absolute-path>] [--dry-run]\n' >&2; exit 2 ;;
  esac
done
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
else
  case "$REPO_ROOT" in
    /*) ;;
    *) printf 'uninstall-host-opencode: --repo-root must be absolute\n' >&2; exit 2 ;;
  esac
  REPO_ROOT="$(cd "$REPO_ROOT" 2>/dev/null && pwd -P)" || {
    printf 'uninstall-host-opencode: --repo-root does not exist\n' >&2
    exit 2
  }
fi
[[ -f "$REPO_ROOT/hosts/opencode/host.yaml" && -f "$REPO_ROOT/scripts/lib/host-manifest.sh" ]] || {
  printf 'uninstall-host-opencode: --repo-root is not a compatible pm-dispatch checkout: %s\n' "$REPO_ROOT" >&2
  exit 2
}
# shellcheck source=scripts/lib/host-manifest.sh
. "$REPO_ROOT/scripts/lib/host-manifest.sh"
# shellcheck source=scripts/lib/portable.sh
. "$REPO_ROOT/scripts/lib/portable.sh"
command -v jq >/dev/null 2>&1 || { printf 'uninstall-host-opencode: jq is required\n' >&2; exit 2; }

config_semantic_sha256() {
  jq -cS 'del(."$schema")' "$1" | _portable_sha256_stream
}

manifest="$(host_manifest_file "$REPO_ROOT" opencode)"
config_template=""
commands_template=""
tools_template=""
while IFS=$'\t' read -r id path fmt managed; do
  [[ "$managed" == "true" ]] || continue
  case "$id:$fmt" in
    config:opencode-config-json) config_template="$path" ;;
    commands:copy-tree) commands_template="$path" ;;
    tools:copy-tree) tools_template="$path" ;;
  esac
done < <(host_manifest_install_targets "$manifest")
[[ -n "$config_template" && -n "$commands_template" && -n "$tools_template" ]] || { printf 'uninstall-host-opencode: managed targets incomplete\n' >&2; exit 2; }

config_file="$(host_manifest_expand_path "$config_template")"
commands_dir="$(host_manifest_expand_path "$commands_template")"
tools_dir="$(host_manifest_expand_path "$tools_template")"
receipt="$config_file.pm-dispatch-receipt.json"
if [[ ! -e "$receipt" && ! -L "$receipt" ]]; then
  printf 'uninstall-host-opencode: not wired, nothing to do\n'
  exit 0
fi
[[ -f "$receipt" && ! -L "$receipt" ]] || { printf 'uninstall-host-opencode: receipt path is not a regular file: %s\n' "$receipt" >&2; exit 1; }
jq empty "$receipt" >/dev/null 2>&1 || { printf 'uninstall-host-opencode: invalid receipt: %s\n' "$receipt" >&2; exit 1; }
owner="$(jq -r '.repo_root // empty' "$receipt")"
[[ "$owner" == "$REPO_ROOT" ]] || { printf 'uninstall-host-opencode: receipt belongs to another checkout: %s\n' "$owner" >&2; exit 1; }

command_file="$(jq -r '.installed.command_file' "$receipt")"
[[ "$command_file" == "$commands_dir/pm.md" ]] || {
  printf 'uninstall-host-opencode: unsafe command path in receipt: %s\n' "$command_file" >&2
  exit 1
}
tool_file="$(jq -r '.installed.tool_file // empty' "$receipt")"
if [[ -n "$tool_file" && "$tool_file" != "$tools_dir/pm_prepare.ts" ]]; then
  printf 'uninstall-host-opencode: unsafe tool path in receipt: %s\n' "$tool_file" >&2
  exit 1
fi
expected_config="$(jq -r '.installed.config_sha256' "$receipt")"
expected_config_semantic="$(jq -r '.installed.config_semantic_sha256 // empty' "$receipt")"
expected_command="$(jq -r '.installed.command_sha256' "$receipt")"
expected_tool="$(jq -r '.installed.tool_sha256 // empty' "$receipt")"
current_config="$(_portable_sha256_path "$config_file" 2>/dev/null || true)"
current_config_semantic="$(config_semantic_sha256 "$config_file" 2>/dev/null || true)"
current_command="$(_portable_sha256_path "$command_file" 2>/dev/null || true)"
current_tool=""
[[ -z "$tool_file" ]] || current_tool="$(_portable_sha256_path "$tool_file" 2>/dev/null || true)"
if [[ -n "$expected_config_semantic" ]]; then
  [[ "$current_config_semantic" == "$expected_config_semantic" ]] || {
    printf 'uninstall-host-opencode: config changed since install; refusing to restore over user changes: %s\n' "$config_file" >&2
    exit 1
  }
elif [[ "$current_config" != "$expected_config" ]]; then
  # Legacy stage-3 receipts predate semantic hashing. Accept only OpenCode's
  # observed addition of $schema when the remaining config is exactly the old
  # managed fragment; every other difference still fails closed.
  pmctl_pattern="$REPO_ROOT/cli/pmctl *"
  if ! jq -e --arg pattern "$pmctl_pattern" '
      del(."$schema") as $c |
      $c == ({permission:{bash:{"*":"deny"}}} | .permission.bash[$pattern] = "allow")
    ' "$config_file" >/dev/null 2>&1; then
    printf 'uninstall-host-opencode: config changed since install; refusing to restore over user changes: %s\n' "$config_file" >&2
    exit 1
  fi
fi
[[ "$current_command" == "$expected_command" ]] || {
  printf 'uninstall-host-opencode: command changed since install; refusing to remove user changes: %s\n' "$command_file" >&2
  exit 1
}
if [[ -n "$tool_file" && "$current_tool" != "$expected_tool" ]]; then
  printf 'uninstall-host-opencode: tool changed since install; refusing to remove user changes: %s\n' "$tool_file" >&2
  exit 1
fi

config_existed="$(jq -r '.before.config_existed' "$receipt")"
backup="$(jq -r '.before.backup // empty' "$receipt")"
if [[ -n "$backup" && "$backup" != "$config_file.pm-dispatch.bak."* ]]; then
  printf 'uninstall-host-opencode: unsafe backup path in receipt: %s\n' "$backup" >&2
  exit 1
fi
if [[ "$config_existed" == "true" && ! -f "$backup" ]]; then
  printf 'uninstall-host-opencode: original config backup missing: %s\n' "$backup" >&2
  exit 1
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
  printf 'uninstall-host-opencode: would remove %s\n' "$command_file"
  [[ -z "$tool_file" ]] || printf 'uninstall-host-opencode: would remove %s\n' "$tool_file"
  if [[ "$config_existed" == "true" ]]; then
    printf 'uninstall-host-opencode: would restore %s from %s\n' "$config_file" "$backup"
  else
    printf 'uninstall-host-opencode: would remove generated %s\n' "$config_file"
  fi
  exit 0
fi

rm -f "$command_file"
[[ -z "$tool_file" ]] || rm -f "$tool_file"
if [[ "$config_existed" == "true" ]]; then
  mv "$backup" "$config_file"
else
  rm -f "$config_file"
fi
rm -f "$receipt"
rmdir "$(dirname "$command_file")" 2>/dev/null || true
[[ -z "$tool_file" ]] || rmdir "$(dirname "$tool_file")" 2>/dev/null || true
printf 'uninstall-host-opencode: removed managed OpenCode host wiring\n'
