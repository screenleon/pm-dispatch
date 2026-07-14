#!/usr/bin/env bash
# Canonical project-memory write seam for Codex host instructions.
# Never accepts or derives a Codex-native memory path: pmctl resolves the
# project-owned canonical store and fails closed on invalid explicit config.
set -euo pipefail

HOST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "$HOST_DIR/../.." && pwd)"
PMCTL="$REPO_ROOT/cli/pmctl"

repo_root=""
summary=""
session_id=""
json=0

usage() {
  cat <<'EOF'
Usage: memory-update.sh --repo-root <path> --summary <text>
       [--session-id <id>] [--json]

Append a Codex-authored episode through the strict canonical pmctl writer.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo-root)
      [[ $# -ge 2 ]] || { printf 'codex-memory-update: --repo-root requires a value\n' >&2; exit 2; }
      repo_root="$2"; shift 2 ;;
    --summary)
      [[ $# -ge 2 ]] || { printf 'codex-memory-update: --summary requires a value\n' >&2; exit 2; }
      summary="$2"; shift 2 ;;
    --session-id)
      [[ $# -ge 2 ]] || { printf 'codex-memory-update: --session-id requires a value\n' >&2; exit 2; }
      session_id="$2"; shift 2 ;;
    --json) json=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'codex-memory-update: unknown argument: %s\n' "$1" >&2; exit 2 ;;
  esac
done

[[ -n "$repo_root" ]] || { printf 'codex-memory-update: --repo-root is required\n' >&2; exit 2; }
[[ -n "${summary//[[:space:]]/}" ]] || { printf 'codex-memory-update: --summary must not be empty\n' >&2; exit 2; }
[[ -x "$PMCTL" ]] || { printf 'codex-memory-update: pmctl is unavailable: %s\n' "$PMCTL" >&2; exit 1; }

args=(memory append-episode --repo-root "$repo_root" --host codex --session-id "$session_id" --summary "$summary")
[[ "$json" -eq 1 ]] && args+=(--json)
exec "$PMCTL" "${args[@]}"
