#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C.UTF-8

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ORIGINAL_PATH="$PATH"

# shellcheck source=scripts/lib/test-harness.sh
. "$SCRIPT_DIR/lib/test-harness.sh"
th_init "test-executor-router" "$@"

# shellcheck source=scripts/lib/executor-router.sh
. "$SCRIPT_DIR/lib/executor-router.sh"

with_fake_codex_path() {
  local bin="$tmp_root/fake-codex-bin"
  mkdir -p "$bin"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$bin/codex"
  chmod +x "$bin/codex"
  PATH="$bin:$ORIGINAL_PATH"
}

with_no_codex_path() {
  local bin="$tmp_root/no-codex-bin"
  mkdir -p "$bin"
  ln -s "$(command -v bash)" "$bin/bash"
  ln -s "$(command -v dirname)" "$bin/dirname"
  PATH="$bin"
}

if should_run "resolve_executor: auto detects codex on PATH"; then
  with_fake_codex_path
  result="$(resolve_executor auto)"
  PATH="$ORIGINAL_PATH"
  [[ "$result" == "codex" ]] && pass "resolve_executor: auto detects codex on PATH" || fail "resolve_executor: auto detects codex on PATH" "expected codex, got: $result"
fi

if should_run "resolve_executor: explicit codex override"; then
  result="$(resolve_executor codex)"
  [[ "$result" == "codex" ]] && pass "resolve_executor: explicit codex override" || fail "resolve_executor: explicit codex override" "expected codex, got: $result"
fi

if should_run "resolve_executor: explicit claude override"; then
  result="$(resolve_executor claude)"
  [[ "$result" == "claude" ]] && pass "resolve_executor: explicit claude override" || fail "resolve_executor: explicit claude override" "expected claude, got: $result"
fi

if should_run "resolve_executor: rejects unknown executor"; then
  if ! resolve_executor gemini >/dev/null 2>&1; then
    pass "resolve_executor: rejects unknown executor"
  else
    fail "resolve_executor: rejects unknown executor" "unknown executor should fail"
  fi
fi

if should_run "detect_executor_auto: falls back to claude without codex"; then
  with_no_codex_path
  result="$(detect_executor_auto)"
  PATH="$ORIGINAL_PATH"
  [[ "$result" == "claude" ]] && pass "detect_executor_auto: falls back to claude without codex" || fail "detect_executor_auto: falls back to claude without codex" "expected claude, got: $result"
fi

if should_run "dispatch_route_for: codex and claude routes"; then
  codex_route="$(dispatch_route_for codex)"
  claude_route="$(dispatch_route_for claude)"
  if [[ "$codex_route" == "main_thread_bash_background" && "$claude_route" == "agent_executor" ]]; then
    pass "dispatch_route_for: codex and claude routes"
  else
    fail "dispatch_route_for: codex and claude routes" "codex=$codex_route claude=$claude_route"
  fi
fi

if should_run "dispatch_via_codex: safe argv passthrough"; then
  work_dir="$tmp_root/work dir"
  brief_file="$tmp_root/brief file.md"
  mkdir -p "$work_dir"
  : > "$brief_file"
  cmd="$(dispatch_via_codex "$brief_file" "$work_dir" default workspace-write never 1200)"
  eval "set -- $cmd"
  if [[ "$1" == "bash" &&
        "$2" == "$REPO_ROOT/scripts/codex-dispatch.sh" &&
        "$3" == "--cd" &&
        "$4" == "$work_dir" &&
        "${11}" == "--brief-file" &&
        "${12}" == "$brief_file" ]]; then
    pass "dispatch_via_codex: safe argv passthrough"
  else
    fail "dispatch_via_codex: safe argv passthrough" "argv did not round-trip: $cmd"
  fi
fi

if should_run "dispatch_via_codex: non-default model"; then
  result="$(dispatch_via_codex "/tmp/brief.md" "/repo" "sonnet" "workspace-write" "never" "1200")"
  printf '%s\n' "$result" | grep -q -- '--model sonnet' && pass "dispatch_via_codex: non-default model" || fail "dispatch_via_codex: non-default model" "expected --model sonnet in: $result"
fi

th_summary
