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
#     jq `def unwrap_bash:` and `def normalize_path:`. unwrap_bash takes the path out of a native Windows
#     bash '<path>' hook command (CC-653; doubled quotes undone, a trailing ` --host x` kept) and normalize_path
#     applies it first, then strips printf %q shell-escape backslashes
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
# shellcheck disable=SC2016  # jq variables ($m, $q), not shell expansions
HOST_DOCTOR_JQ_NORMALIZE_PATH='# unwrap_bash: on native Windows the installers write a hook as the PowerShell-safe bash '\''<path>'\'' (CC-589;
# a quote inside the path is doubled). Take the path out of the wrapper and keep whatever follows the closing
# quote (the ` --host claude` argument), so the rest of the program sees the same string a POSIX install wrote.
# The quote character is written \u0027 because this text lives in a bash single-quoted string.
def unwrap_bash:
  if startswith("bash \u0027") then
    ((capture("^bash \u0027(?<p>(?:[^\u0027]|\u0027\u0027)*)\u0027(?<rest>.*)$")) // null) as $m
    | if $m == null then .
      else
        (reduce ("\u0027", "\u2018", "\u2019", "\u201a", "\u201b") as $q ($m.p; gsub($q + $q; $q))) + $m.rest
      end
  else . end;
def normalize_path:
  unwrap_bash
  | gsub("\\\\(?<c>[^A-Za-z0-9])"; .c)
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
