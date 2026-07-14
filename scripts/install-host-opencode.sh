#!/usr/bin/env bash
# Install the OpenCode host permission fragment and /pm custom command.
# Ownership is receipt-based: an existing Bash policy or pm command is never
# overwritten, and uninstall restores the exact pre-install config bytes.
# shellcheck disable=SC1091
# Repo-local manifest/portable libraries are resolved dynamically below.

set -euo pipefail

DRY_RUN=0
case "${1:-}" in
  --dry-run) DRY_RUN=1 ;;
  "") : ;;
  *) printf 'install-host-opencode: usage: install-host-opencode.sh [--dry-run]\n' >&2; exit 2 ;;
esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=scripts/lib/host-manifest.sh
. "$SCRIPT_DIR/lib/host-manifest.sh"
# shellcheck source=scripts/lib/portable.sh
. "$SCRIPT_DIR/lib/portable.sh"

command -v jq >/dev/null 2>&1 || { printf 'install-host-opencode: jq is required\n' >&2; exit 2; }

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
[[ -n "$config_template" && -n "$commands_template" && -n "$tools_template" ]] || {
  printf 'install-host-opencode: manifest lacks managed config/commands/tools targets\n' >&2
  exit 2
}

config_file="$(host_manifest_expand_path "$config_template")"
commands_dir="$(host_manifest_expand_path "$commands_template")"
tools_dir="$(host_manifest_expand_path "$tools_template")"
command_file="$commands_dir/pm.md"
tool_file="$tools_dir/pm_prepare.ts"
receipt="$config_file.pm-dispatch-receipt.json"
pmctl="$REPO_ROOT/cli/pmctl"
pmctl_pattern="$pmctl *"
# JSON string syntax is also a valid JavaScript/TypeScript string literal.
# Never interpolate a filesystem path directly into generated executable code:
# POSIX checkout paths may legally contain quotes, backslashes, or newlines.
pmctl_literal="$(jq -Rn --arg v "$pmctl" '$v')"

if [[ -e "$receipt" || -L "$receipt" ]]; then
  [[ -f "$receipt" && ! -L "$receipt" ]] || { printf 'install-host-opencode: receipt path is not a regular file: %s\n' "$receipt" >&2; exit 1; }
  jq empty "$receipt" >/dev/null 2>&1 || { printf 'install-host-opencode: invalid receipt: %s\n' "$receipt" >&2; exit 1; }
  owner="$(jq -r '.repo_root // empty' "$receipt")"
  [[ "$owner" == "$REPO_ROOT" ]] || {
    printf 'install-host-opencode: receipt belongs to another checkout: %s\n' "$owner" >&2
    exit 1
  }
  expected_config_semantic="$(jq -r '.installed.config_semantic_sha256 // empty' "$receipt")"
  expected_command="$(jq -r '.installed.command_sha256' "$receipt")"
  expected_tool="$(jq -r '.installed.tool_sha256 // empty' "$receipt")"
  [[ -n "$expected_tool" ]] || {
    printf 'install-host-opencode: legacy receipt requires uninstall/reinstall upgrade\n' >&2
    exit 1
  }
  current_config_semantic="$(config_semantic_sha256 "$config_file" 2>/dev/null || true)"
  current_command="$(_portable_sha256_path "$command_file" 2>/dev/null || true)"
  current_tool="$(_portable_sha256_path "$tool_file" 2>/dev/null || true)"
  [[ -n "$expected_config_semantic" && "$current_config_semantic" == "$expected_config_semantic" \
      && "$current_command" == "$expected_command" && "$current_tool" == "$expected_tool" ]] || {
    printf 'install-host-opencode: managed files changed since install; refusing to overwrite\n' >&2
    exit 1
  }
  printf 'install-host-opencode: already wired, nothing to do\n'
  exit 0
fi

if [[ -e "$command_file" || -L "$command_file" ]]; then
  printf 'install-host-opencode: command already exists and is not owned by this checkout: %s\n' "$command_file" >&2
  exit 1
fi
if [[ -e "$tool_file" || -L "$tool_file" ]]; then
  printf 'install-host-opencode: tool already exists and is not owned by this checkout: %s\n' "$tool_file" >&2
  exit 1
fi

config_existed=false
if [[ -L "$config_file" ]]; then
  printf 'install-host-opencode: symlinked config requires manual integration: %s\n' "$config_file" >&2
  exit 1
fi
if [[ -f "$config_file" ]]; then
  config_existed=true
  jq empty "$config_file" >/dev/null 2>&1 || {
    printf 'install-host-opencode: existing config is not valid JSON: %s\n' "$config_file" >&2
    exit 1
  }
  if ! jq -e '.permission == null or (.permission | type == "object")' "$config_file" >/dev/null 2>&1; then
    printf 'install-host-opencode: existing permission shorthand is user-owned; refusing to replace it\n' >&2
    exit 1
  fi
  if jq -e '.permission.bash != null' "$config_file" >/dev/null 2>&1; then
    printf 'install-host-opencode: existing permission.bash policy is user-owned; refusing to merge ordering-sensitive rules\n' >&2
    exit 1
  fi
  if jq -e '.permission.pm_prepare != null' "$config_file" >/dev/null 2>&1; then
    printf 'install-host-opencode: existing pm_prepare permission is user-owned; refusing to overwrite\n' >&2
    exit 1
  fi
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
  printf 'install-host-opencode: would manage %s\n' "$config_file"
  printf 'install-host-opencode: would create %s\n' "$command_file"
  printf 'install-host-opencode: would create %s\n' "$tool_file"
  printf 'install-host-opencode: would allow only %s after catch-all Bash deny\n' "$pmctl_pattern"
  exit 0
fi

mkdir -p "$(dirname "$config_file")" "$commands_dir" "$tools_dir"
tmp_config="$(mktemp "${TMPDIR:-/tmp}/opencode-config.XXXXXX")"
tmp_command="$(mktemp "${TMPDIR:-/tmp}/opencode-command.XXXXXX")"
tmp_tool="$(mktemp "${TMPDIR:-/tmp}/opencode-tool.XXXXXX")"
tmp_receipt="$(mktemp "${TMPDIR:-/tmp}/opencode-receipt.XXXXXX")"
backup=""
applied_config=0
applied_command=0
applied_tool=0
cleanup() {
  local rc=$?
  if [[ "$rc" -ne 0 ]]; then
    [[ "$applied_command" -eq 1 ]] && rm -f "$command_file"
    [[ "$applied_tool" -eq 1 ]] && rm -f "$tool_file"
    if [[ "$applied_config" -eq 1 ]]; then
      if [[ "$config_existed" == "true" && -n "$backup" && -f "$backup" ]]; then
        cp "$backup" "$config_file"
      else
        rm -f "$config_file"
      fi
    fi
  fi
  rm -f "$tmp_config" "$tmp_command" "$tmp_tool" "$tmp_receipt"
  return "$rc"
}
trap cleanup EXIT

if [[ "$config_existed" == "true" ]]; then
  backup="$config_file.pm-dispatch.bak.$(date +%Y%m%d-%H%M%S).$$"
  cp "$config_file" "$backup"
  jq --arg pattern "$pmctl_pattern" \
    '.permission = (.permission // {}) | .permission.bash = {"*":"deny"} | .permission.bash[$pattern] = "allow" | .permission.pm_prepare = "allow"' \
    "$config_file" > "$tmp_config"
else
  jq -n --arg pattern "$pmctl_pattern" \
    '{permission:{bash:{"*":"deny"},pm_prepare:"allow"}} | .permission.bash[$pattern] = "allow"' > "$tmp_config"
fi

cat > "$tmp_command" <<EOF
---
description: Prepare and coordinate a pm-dispatch request from OpenCode
---

You MUST call the custom \`pm_prepare\` tool exactly once before answering.
Pass the complete user request below as \`request\`, and extract every unique
CC-N ticket into \`focus_tickets\` in first-seen order. Do not substitute a
generic bootstrap request and do not use Bash for preparation.

User request:

\$ARGUMENTS

Use the tool result and the user request to plan the work. If more information
is required, ask the user in this host session. Any subsequent pm-dispatch
command must use this exact executable (JSON-quoted): $pmctl_literal. Do not claim interactive parity
with Claude; OpenCode is a host-native command surface over the batch pmctl
spine.
EOF

cat > "$tmp_tool" <<EOF
import { tool } from "@opencode-ai/plugin"

const PMCTL = $pmctl_literal

export default tool({
  description: "Safely run pmctl pm prepare with the exact OpenCode /pm request and focus tickets",
  args: {
    request: tool.schema.string().min(1).describe("Complete user request, unchanged"),
    focus_tickets: tool.schema.array(tool.schema.string().regex(/^CC-[0-9]+\$/)).default([]),
  },
  async execute(args, context) {
    const focus = [...new Set(args.focus_tickets)]
    const argv = [PMCTL, "pm", "prepare", "--cd", context.worktree, "--request", args.request, "--host", "opencode", "--json"]
    if (focus.length > 0) argv.push("--focus", focus.join(","))

    const proc = Bun.spawn(argv, {
      cwd: context.worktree,
      stdout: "pipe",
      stderr: "pipe",
    })
    const [stdout, stderr, exitCode] = await Promise.all([
      new Response(proc.stdout).text(),
      new Response(proc.stderr).text(),
      proc.exited,
    ])
    if (exitCode !== 0) {
      throw new Error(\`pmctl pm prepare failed (exit \${exitCode}): \${stderr.trim()}\`)
    }
    return stdout.trim()
  },
})
EOF

config_sha="$(_portable_sha256_path "$tmp_config")"
config_semantic_sha="$(config_semantic_sha256 "$tmp_config")"
command_sha="$(_portable_sha256_path "$tmp_command")"
tool_sha="$(_portable_sha256_path "$tmp_tool")"
jq -n \
  --arg repo_root "$REPO_ROOT" \
  --arg config_file "$config_file" \
  --arg command_file "$command_file" \
  --arg tool_file "$tool_file" \
  --arg backup "$backup" \
  --argjson config_existed "$config_existed" \
  --arg config_sha "$config_sha" \
  --arg config_semantic_sha "$config_semantic_sha" \
  --arg command_sha "$command_sha" \
  --arg tool_sha "$tool_sha" \
  '{schema_version:1,repo_root:$repo_root,before:{config_existed:$config_existed,backup:(if $backup=="" then null else $backup end)},installed:{config_file:$config_file,command_file:$command_file,tool_file:$tool_file,config_sha256:$config_sha,config_semantic_sha256:$config_semantic_sha,command_sha256:$command_sha,tool_sha256:$tool_sha}}' \
  > "$tmp_receipt"

mv "$tmp_config" "$config_file"
applied_config=1
mv "$tmp_command" "$command_file"
applied_command=1
mv "$tmp_tool" "$tool_file"
applied_tool=1
mv "$tmp_receipt" "$receipt"
trap - EXIT
printf 'install-host-opencode: wrote %s\n' "$config_file"
printf 'install-host-opencode: wrote %s\n' "$command_file"
printf 'install-host-opencode: wrote %s\n' "$tool_file"
printf 'install-host-opencode: receipt %s\n' "$receipt"
