#!/usr/bin/env bash
# shellcheck disable=SC2034  # jq-fragment constants read by host doctor modules after sourcing
# Host-agnostic mechanical helpers shared by the per-host doctor modules
# (hosts/*/lib/doctor.sh). Pure transforms only — no host-name branching, no
# policy. Each host module keeps ownership of which events it scans, its
# basename allow-lists, its parent-directory structure rules and its messages.
#
# Sourced by runtime/bin/doctor.sh core before the host modules load, so
# emit_check/emit_capability and these primitives are all in scope together.
#
# Provides:
#   $HOST_DOCTOR_JQ_NORMALIZE_PATH
#     jq `def normalize_path:` — strips printf %q shell-escape backslashes
#     (a backslash before any non-alphanumeric char) BEFORE converting native
#     Windows `\` separators to `/`, and lower-cases a `C:\`-style drive letter
#     into `/c/...`. Non-drive paths still get `\`->`/`. Consumed by string
#     concatenation: "$HOST_DOCTOR_JQ_NORMALIZE_PATH"$'\n'"<rest of program>".
#   $HOST_DOCTOR_JQ_STRIP_HOST_SUFFIX
#     jq fragment: strips a trailing ` --host <name>` (claude|codex|opencode|
#     grok|generic) from a command string before basename classification.
#   host_doctor_filter_non_executable  (stdin: paths, one per line)
#     echoes back only the non-empty paths that are not executable.

# NOTE: hosts/claude/lib/doctor.sh keeps one deliberately DIFFERENT local copy
# (`else . end` — non-drive paths untouched) for its settings-hooks digest
# comparison; that variant has a single consumer and is not extracted here.
HOST_DOCTOR_JQ_NORMALIZE_PATH='def normalize_path:
  gsub("\\\\(?<c>[^A-Za-z0-9])"; .c)
  | if test("^[A-Za-z]:[/\\\\]") then
      "/" + (.[0:1] | ascii_downcase) + "/" + (.[3:] | gsub("\\\\"; "/"))
    else gsub("\\\\"; "/") end;'

HOST_DOCTOR_JQ_STRIP_HOST_SUFFIX='sub(" --host (claude|codex|opencode|grok|generic)$"; "")'

host_doctor_filter_non_executable() {
  local command_path
  while IFS= read -r command_path; do
    [[ -n "$command_path" && ! -x "$command_path" ]] && printf '%s\n' "$command_path"
  done
  return 0
}
