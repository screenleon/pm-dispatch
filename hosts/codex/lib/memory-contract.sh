#!/usr/bin/env bash
# Codex-owned AGENTS.md memory-contract block helpers.
#
# Install and uninstall both need byte-consistent marker parsing and whitespace
# normalization. Keep that host-format policy beside hosts/codex instead of
# duplicating it in the generic scripts/ entrypoints.

CODEX_MEMORY_CONTRACT_START='<!-- pm-dispatch:codex-memory-contract:start -->'
CODEX_MEMORY_CONTRACT_END='<!-- pm-dispatch:codex-memory-contract:end -->'

codex_memory_contract_strip() {
  local input="$1" output="$2" start_count end_count
  start_count="$(grep -Fxc "$CODEX_MEMORY_CONTRACT_START" "$input" || true)"
  end_count="$(grep -Fxc "$CODEX_MEMORY_CONTRACT_END" "$input" || true)"
  [[ "$start_count" -eq "$end_count" && "$start_count" -le 1 ]] || return 2

  awk -v start="$CODEX_MEMORY_CONTRACT_START" -v end="$CODEX_MEMORY_CONTRACT_END" '
    $0 == start { managed=1; next }
    $0 == end { managed=0; next }
    !managed { print }
  ' "$input" \
    | awk 'NF { while (blanks > 0) { print ""; blanks-- } print; next } { blanks++ }' \
    > "$output"
}

codex_memory_contract_append() {
  local output="$1" memory_update_cmd_q="$2"
  [[ ! -s "$output" ]] || printf '\n' >> "$output"
  cat >> "$output" <<EOF
$CODEX_MEMORY_CONTRACT_START
## pm-dispatch canonical project memory

- When the user explicitly asks to update, save, or record project memory, do not write a project record under \`.codex/memories\` or another host-private store.
- Resolve the repository root, summarize the durable facts, and run \`$memory_update_cmd_q --repo-root <absolute-repo-root> --summary <summary> --json\`.
- Treat pmctl output as the write confirmation. If canonical resolution fails, stop and report the error; never fall through to native or legacy memory.
$CODEX_MEMORY_CONTRACT_END
EOF
}
