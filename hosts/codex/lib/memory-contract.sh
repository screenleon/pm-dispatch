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
  local output="$1" memory_update_cmd_q="$2" repo_root="$3"
  [[ ! -s "$output" ]] || printf '\n' >> "$output"
  cat >> "$output" <<EOF
$CODEX_MEMORY_CONTRACT_START
## pm-dispatch canonical project memory

- When the user explicitly asks to update, save, or record project memory, do not write a project record under \`.codex/memories\` or another host-private store.
- Resolve the repository root, summarize the durable facts, and run \`$memory_update_cmd_q --repo-root <absolute-repo-root> --summary <summary> --json\`.
- Treat pmctl output as the write confirmation. If canonical resolution fails, stop and report the error; never fall through to native or legacy memory.

## pm-dispatch detached execution continuation

- For a delegated Codex dispatch, launch \`$repo_root/cli/pmctl dispatch run --lifecycle detached ...\` inline and retain its \`run_id\` plus working directory in the conversation state.
- **Default for Codex CLI:** run \`$repo_root/hosts/codex/bin/wait-dispatch.sh --repo-root $repo_root --run-id <run_id> --cd <working_dir>\` in the foreground. Codex's sandbox does not promise a persistent App Server control socket, and a completed background terminal alone cannot resume this conversation.
- Use background automatic continuation only in an explicitly integrated App Server session that exposes both the originating thread id and a reachable control socket. In that case start \`$repo_root/hosts/codex/bin/continue-dispatch.sh --repo-root $repo_root --run-id <run_id> --cd <working_dir> --thread-id <codex-thread-id> [--app-server-socket <absolute-socket>]\` in a host-owned background terminal. It injects a new verified continuation turn when the run completes. Never use shell \`&\` as a substitute for a host-owned background terminal.
- If that optional bridge is unavailable, state that background continuation is unsupported and retain the foreground wait. For a **new** attempt on a host where detached children cannot survive, use \`--lifecycle foreground\`; do not silently re-dispatch a timed-out or indeterminate run.
- Trust the wait exit code and its nonce-authenticated sentinel, not a bare \`run_id\`, a workspace record, or \`.agent-trace/latest.*\`. On a timeout retry the same wait once; on indeterminate or failure inspect the printed \`artifacts\` command before any repair.

## pm-dispatch gate lifecycle continuation

- **Default for Codex CLI:** run \`$repo_root/cli/pmctl gate run ... --lifecycle foreground\` (via \`/pr-gate\` or directly) and wait on it inline. Codex's sandbox does not promise a persistent App Server control socket, and the tool call that launches \`--lifecycle detached\` can have its own process/job tree torn down by the host the instant that tool call returns -- \`disown\` does not protect the detached supervisor from that teardown.
- Use \`--lifecycle detached\` plus a separate \`$repo_root/cli/pmctl gate wait <gate_id> --cd <working_dir>\` only in an explicitly integrated App Server session that exposes both the originating thread id and a reachable control socket -- the same bridge criterion the dispatch continuation section above uses. Without that confirmed bridge, a detached gate's supervisor can die before \`pr-gate.sh\` even starts, and the launcher has no way to observe that from inside the same tool call that would be torn down.
- If \`pmctl gate wait\` reports indeterminate (exit 3), read which case the message names: a sentinel that went missing after runtime/session cleanup, a supervisor the kernel no longer reports (its message now also suggests \`--lifecycle foreground\`), or a supervisor identity that could not be re-verified (not evidence of death -- re-attach with a longer \`--timeout\` instead of re-dispatching). For a **new** attempt after any of these, prefer \`--lifecycle foreground\`; do not silently re-dispatch a timed-out or indeterminate gate.
$CODEX_MEMORY_CONTRACT_END
EOF
}
