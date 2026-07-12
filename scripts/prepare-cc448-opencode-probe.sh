#!/usr/bin/env bash
# Prepare a throwaway OpenCode stage-3 probe without touching the user's real
# OpenCode config. The generated package tests custom-command shell expansion,
# per-pattern Bash permissions, and pmctl availability as separate facts.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUT="${1:-/tmp/cc448-opencode-probe}"

if [[ -e "$OUT" ]]; then
  printf 'prepare-cc448-opencode-probe: output already exists: %s\n' "$OUT" >&2
  printf 'pass a new empty path as the first argument\n' >&2
  exit 2
fi

PROJECT="$OUT/project"
mkdir -p "$PROJECT/.opencode/commands"
mkdir -p "$OUT/config-control/opencode" "$OUT/config-deny-all/opencode" "$OUT/config-allow-pmctl/opencode"

cat > "$PROJECT/.opencode/commands/cc448-pm-probe.md" <<EOF
---
description: Probe deterministic pmctl access from an OpenCode custom command
---

The JSON below must be produced before the model answers. Do not call any
additional tool. State whether the JSON is present and whether
snapshot_status is created.

!\`$REPO_ROOT/cli/pmctl pm prepare --cd $REPO_ROOT --request 'CC-448 OpenCode stage-3 PM command probe' --focus CC-448,CC-445 --json\`
EOF

cat > "$PROJECT/.opencode/commands/cc448-guard-probe.md" <<EOF
---
description: Verify that non-pmctl Bash remains blocked
---

Attempt exactly one Bash tool call with this exact command:

printf blocked-check > $OUT/guard-should-not-exist

Do not use edit, write, apply_patch, or another command. Report whether the
Bash call was allowed or denied.
EOF

cat > "$OUT/config-control/opencode/opencode.json" <<'EOF'
{
  "$schema": "https://opencode.ai/config.json",
  "permission": {
    "bash": "allow",
    "edit": "deny",
    "external_directory": "allow"
  }
}
EOF

cat > "$OUT/config-deny-all/opencode/opencode.json" <<'EOF'
{
  "$schema": "https://opencode.ai/config.json",
  "permission": {
    "bash": {
      "*": "deny"
    },
    "edit": "deny",
    "external_directory": "allow"
  }
}
EOF

cat > "$OUT/config-allow-pmctl/opencode/opencode.json" <<EOF
{
  "\$schema": "https://opencode.ai/config.json",
  "permission": {
    "bash": {
      "*": "deny",
      "$REPO_ROOT/cli/pmctl *": "allow",
      "pmctl *": "allow"
    },
    "edit": "deny",
    "external_directory": "allow"
  }
}
EOF

cat > "$OUT/run.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
profile="${1:-}"
probe="${2:-}"
shift 2 2>/dev/null || true
case "$profile" in
  control|deny-all|allow-pmctl) ;;
  *) printf 'usage: %s <control|deny-all|allow-pmctl> <pm|guard> [opencode args...]\n' "$0" >&2; exit 2 ;;
esac
case "$probe" in
  pm) command_name=cc448-pm-probe ;;
  guard) command_name=cc448-guard-probe ;;
  *) printf 'usage: %s <control|deny-all|allow-pmctl> <pm|guard> [opencode args...]\n' "$0" >&2; exit 2 ;;
esac
XDG_CONFIG_HOME="$ROOT/config-$profile" \
  opencode run --dir "$ROOT/project" --command "$command_name" --format json "$@"
EOF
chmod +x "$OUT/run.sh"

cat > "$OUT/README.md" <<EOF
# CC-448 OpenCode stage-3 live probe

This package is isolated under \`$OUT\`. It does not read or write the normal
\`~/.config/opencode/opencode.json\` because every run sets its own
\`XDG_CONFIG_HOME\`.

Run these one at a time:

1. \`$OUT/run.sh control pm\`
   Expected: the command contains parseable \`pmctl pm prepare\` JSON and reports
   \`snapshot_status=created\`.
2. \`$OUT/run.sh deny-all pm\`
   Decides whether custom-command shell output is evaluated outside the model's
   Bash permission. Record whether JSON is present or execution is denied.
3. \`$OUT/run.sh allow-pmctl pm\`
   Expected candidate design: pmctl JSON is present while catch-all Bash remains
   denied. OpenCode uses the last matching permission rule, so the two pmctl
   allow patterns follow the catch-all deny.
4. \`$OUT/run.sh allow-pmctl guard\`
   Expected: Bash is denied and \`$OUT/guard-should-not-exist\` does not exist.

After each run, preserve stdout. Do not add
\`--dangerously-skip-permissions\`; it would invalidate the permission probe.
The package does not modify the repository, except that \`pmctl pm prepare\`
creates its normal snapshot under \`/tmp\`.
EOF

printf '%s\n' "$OUT"
