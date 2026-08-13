#!/usr/bin/env bash
# Tests for runtime/lib/state-paths.sh — the shared store-root / project-key /
# run-dir resolvers extracted from state-writer.sh.
#
# Why this suite exists: the resolvers became a load-bearing seam for routing
# gate/dispatch artifacts out of the repo. Their path composition (especially
# sw_project_run_dir) and the env-precedence of the store root must stay exact;
# a regression here silently relocates every run's artifacts. The suite also
# pins the extraction itself: sourcing state-writer.sh must still expose the
# moved functions, so a broken source wiring fails loudly instead of degrading.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
STATE_PATHS="$REPO_ROOT/runtime/lib/state-paths.sh"

# shellcheck source=tests/lib/test-harness.sh
# shellcheck disable=SC1091
. "$SCRIPT_DIR/../lib/test-harness.sh"
th_init "$@"

# Source the unit under test directly. portable.sh is pulled in by state-paths.
# shellcheck source=runtime/lib/state-paths.sh
# shellcheck disable=SC1091
. "$STATE_PATHS"

# ---- 1: store root honors PM_DISPATCH_STATE_ROOT ----
case_store_root_explicit() {
  # Behavior: PM_DISPATCH_STATE_ROOT wins over every other source.
  # Steps: set the env var; assert _sw_store_root echoes it verbatim.
  local name="store-root/PM_DISPATCH_STATE_ROOT wins"
  should_run "$name" || return 0
  local got
  got="$(PM_DISPATCH_STATE_ROOT=/srv/pm-state _sw_store_root)"
  if [[ "$got" == "/srv/pm-state" ]]; then pass "$name"; else fail "$name" "got=$got"; fi
}

# ---- 2: store root falls back to XDG_DATA_HOME ----
case_store_root_xdg() {
  # Behavior: with no explicit root, XDG_DATA_HOME/pm-dispatch/state is used.
  # Steps: unset the explicit root, set XDG_DATA_HOME, assert composed path.
  local name="store-root/XDG_DATA_HOME fallback"
  should_run "$name" || return 0
  local got
  got="$(unset PM_DISPATCH_STATE_ROOT; XDG_DATA_HOME=/x/data _sw_store_root)"
  if [[ "$got" == "/x/data/pm-dispatch/state" ]]; then pass "$name"; else fail "$name" "got=$got"; fi
}

# ---- 3: store root final fallback to HOME/.local/share ----
case_store_root_home() {
  # Behavior: with neither explicit root nor XDG set, HOME/.local/share is used.
  # Steps: unset both higher-precedence vars, set HOME, assert composed path.
  local name="store-root/HOME default fallback"
  should_run "$name" || return 0
  local got
  got="$(unset PM_DISPATCH_STATE_ROOT XDG_DATA_HOME; HOME=/home/u _sw_store_root)"
  if [[ "$got" == "/home/u/.local/share/pm-dispatch/state" ]]; then pass "$name"; else fail "$name" "got=$got"; fi
}

# ---- 4: run dir composes store_root/projects/<key>/runs/<run_id> ----
case_run_dir_composition() {
  # Behavior: sw_project_run_dir builds <store_root>/projects/<key>/runs/<id>
  # with NO trailing slash (distinct from _sw_project_dir which is trailing-slashed).
  # Steps: pin store root + a git repo for a stable key; assert exact composition.
  local name="run-dir/composes store_root/projects/key/runs/id"
  should_run "$name" || return 0
  local repo root key got expected
  repo="$(mktemp -d)"; git init -q "$repo"
  root="/srv/pm-state"
  key="$(PM_DISPATCH_STATE_ROOT="$root" _SW_REPO_ROOT="$repo" _sw_project_key)"
  expected="$root/projects/$key/runs/run-20260812T000000Z-abc123"
  got="$(PM_DISPATCH_STATE_ROOT="$root" _SW_REPO_ROOT="$repo" sw_project_run_dir run-20260812T000000Z-abc123)"
  rm -rf "$repo"
  if [[ "$got" == "$expected" && "$got" != */ && "$got" == *"/runs/run-20260812T000000Z-abc123" ]]; then
    pass "$name"
  else
    fail "$name" "got=$got expected=$expected"
  fi
}

# Shared assertion: invoking <fn> <arg> must fail (non-zero) AND print nothing on
# stdout (so a rejected input can never be mistaken for a usable path). Factored
# out because every reject case differs only in the input and label.
assert_call_rejects() {
  local name="$1" fn="$2" arg="$3"
  should_run "$name" || return 0
  local out rc
  set +e; out="$("$fn" "$arg" 2>/dev/null)"; rc=$?; set -e
  if [[ "$rc" -ne 0 && -z "$out" ]]; then pass "$name"; else fail "$name" "rc=$rc out=$out"; fi
}

# ---- 5-7: run dir rejects missing / path-escaping run_ids ----
case_run_dir_rejections() {
# Behavior: sw_project_run_dir accepts only the canonical dispatch run-id grammar,
# including rejecting empty, path-escaping, and formerly tolerated loose values.
  assert_call_rejects "run-dir/empty run_id rejected"  sw_project_run_dir ""
  assert_call_rejects "run-dir/slash run_id rejected"  sw_project_run_dir "a/b"
  assert_call_rejects "run-dir/dotdot run_id rejected" sw_project_run_dir "x..y"
}

# ---- 8: resolve-trace-dir precedence: explicit override wins ----
case_trace_flag_wins() {
  # Behavior: a non-empty override (the --trace-dir value) beats env and legacy.
  # Steps: set env too; assert the override is returned, not the env or default.
  local name="trace-dir/flag override beats env and legacy"
  should_run "$name" || return 0
  local got
  got="$(PM_DISPATCH_TRACE_DIR=/env/trace sw_resolve_trace_dir /flag/trace /work/.agent-trace)"
  if [[ "$got" == "/flag/trace" ]]; then pass "$name"; else fail "$name" "got=$got"; fi
}

# ---- 9: resolve-trace-dir precedence: env wins when no override ----
case_trace_env_wins() {
  # Behavior: with no override, PM_DISPATCH_TRACE_DIR beats the legacy default.
  # Steps: empty override + env set; assert env value returned.
  local name="trace-dir/env beats legacy default"
  should_run "$name" || return 0
  local got
  got="$(PM_DISPATCH_TRACE_DIR=/env/trace sw_resolve_trace_dir "" /work/.agent-trace)"
  if [[ "$got" == "/env/trace" ]]; then pass "$name"; else fail "$name" "got=$got"; fi
}

# ---- 10: resolve-trace-dir falls back to legacy default ----
case_trace_legacy_default() {
  # Behavior: with neither override nor env, the legacy default is emitted
  # verbatim — and a RELATIVE legacy default is allowed (preserves in-repo behavior).
  # Steps: unset env, empty override, relative default; assert it round-trips.
  local name="trace-dir/legacy default used verbatim (relative allowed)"
  should_run "$name" || return 0
  local got
  got="$(unset PM_DISPATCH_TRACE_DIR; sw_resolve_trace_dir "" "work/.agent-trace")"
  if [[ "$got" == "work/.agent-trace" ]]; then pass "$name"; else fail "$name" "got=$got"; fi
}

# ---- 11-12: resolve-trace-dir rejects a RELATIVE explicit value ----
case_trace_relative_rejected() {
  # Behavior: an explicit override (flag or env) that is not absolute is rejected
  # (return 2, no stdout) so trace location never depends on cwd. The legacy
  # default's relative-ness is exempt (covered above).
  # Steps: relative flag, then relative env; assert each fails with empty stdout.
  local name out rc
  name="trace-dir/relative flag override rejected"
  if should_run "$name"; then
    set +e; out="$(sw_resolve_trace_dir "rel/trace" /work/.agent-trace 2>/dev/null)"; rc=$?; set -e
    if [[ "$rc" -eq 2 && -z "$out" ]]; then pass "$name"; else fail "$name" "rc=$rc out=$out"; fi
  fi
  name="trace-dir/relative env override rejected"
  if should_run "$name"; then
    set +e; out="$(PM_DISPATCH_TRACE_DIR=rel/trace sw_resolve_trace_dir "" /work/.agent-trace 2>/dev/null)"; rc=$?; set -e
    if [[ "$rc" -eq 2 && -z "$out" ]]; then pass "$name"; else fail "$name" "rc=$rc out=$out"; fi
  fi
}

# ---- 13: extraction parity — state-writer re-exports the moved resolvers ----
case_state_writer_sources_paths() {
  # Behavior: sourcing state-writer.sh (the mutating layer) must still expose
  # the resolvers now living in state-paths.sh, proving the source wiring works.
  # Steps: source state-writer.sh in a clean subshell; assert all four are functions.
  local name="extraction/state-writer re-exports resolvers"
  should_run "$name" || return 0
  local got
  got="$(bash -c '
    . "'"$REPO_ROOT"'/runtime/lib/state-writer.sh"
    for f in _sw_store_root _sw_project_key _sw_project_dir sw_project_run_dir sw_resolve_trace_dir; do
      [[ "$(type -t "$f")" == function ]] || { echo "MISSING:$f"; exit 1; }
    done
    echo OK
  ' 2>/dev/null)"
  if [[ "$got" == "OK" ]]; then pass "$name"; else fail "$name" "got=$got"; fi
}

case_store_root_explicit
case_store_root_xdg
case_store_root_home
case_run_dir_composition
case_run_dir_rejections
case_trace_flag_wins
case_trace_env_wins
case_trace_legacy_default
case_trace_relative_rejected
case_state_writer_sources_paths

th_summary
