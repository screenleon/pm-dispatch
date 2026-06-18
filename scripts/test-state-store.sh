#!/usr/bin/env bash
# Regression tests for the pm-dispatch state-store writer.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PMCTL="$REPO_ROOT/cli/pmctl"

# shellcheck source=scripts/lib/test-harness.sh
. "$SCRIPT_DIR/lib/test-harness.sh"
th_init "$@"

# shellcheck source=scripts/lib/state-writer.sh
. "$SCRIPT_DIR/lib/state-writer.sh"

reset_state_env() {
  unset PM_DISPATCH_STATE_ROOT XDG_DATA_HOME
}

state_store_mode() {
  local path="$1" mode
  if mode="$(stat -c %a -- "$path" 2>/dev/null)"; then
    printf '%s\n' "$mode"
    return 0
  fi
  if mode="$(stat -f %Lp -- "$path" 2>/dev/null)"; then
    printf '%s\n' "$mode"
    return 0
  fi
  return 1
}

mk_pmctl_brief() {
  local work="$1" brief
  brief="/tmp/brief-state-store-$$-$(date +%s%N).md"
  cat > "$brief" <<EOF
schema_version: 1
working_dir: $work
goal: exercise pmctl-owned state writes
files:
  - read: $work/README
acceptance:
  - dispatch exits with expected state rows
EOF
  printf '%s\n' "$brief"
}

install_fake_codex() {
  local bindir="$1" code="${2:-0}" probe_file="${3:-}"
  cat > "$bindir/codex" <<FAKEOF
#!/usr/bin/env bash
_last=""
while [[ \$# -gt 0 ]]; do
  case "\$1" in
    --output-last-message) _last="\$2"; shift 2;;
    *) shift;;
  esac
done
if [[ -n "$probe_file" && -n "\${PM_DISPATCH_STATE_ROOT:-}" ]]; then
  if find "\$PM_DISPATCH_STATE_ROOT" -name events.jsonl -type f -exec grep -q '"kind":"run.dispatched"' {} \\; -print -quit 2>/dev/null | grep -q .; then
    printf 'seen\n' > "$probe_file"
  fi
fi
[[ -n "\$_last" ]] && printf 'dispatch complete (fake codex)\n' > "\$_last"
printf '%s\n' '{"type":"turn.completed","usage":{"input_tokens":1,"output_tokens":1}}'
exit $code
FAKEOF
  chmod +x "$bindir/codex"
}

# Probing codex: unconditionally writes to probe_file on invocation.
# Used to verify whether the adapter (and therefore the underlying codex binary)
# was actually called by pmctl.
install_probing_codex() {
  local bindir="$1" code="${2:-0}" probe_file="$3"
  cat > "$bindir/codex" <<FAKEOF
#!/usr/bin/env bash
_last=""
while [[ \$# -gt 0 ]]; do
  case "\$1" in
    --output-last-message) _last="\$2"; shift 2;;
    *) shift;;
  esac
done
printf 'invoked\n' > "$probe_file"
[[ -n "\$_last" ]] && printf 'dispatch complete (probing codex)\n' > "\$_last"
printf '%s\n' '{"type":"turn.completed","usage":{"input_tokens":1,"output_tokens":1}}'
exit $code
FAKEOF
  chmod +x "$bindir/codex"
}

# Poison codex: makes events.jsonl unwritable (chmod 000) after the adapter
# runs so a post-adapter transition Event append fails while the paired Run
# append still succeeds.
install_poison_codex() {
  local bindir="$1" code="${2:-0}"
  cat > "$bindir/codex" <<FAKEOF
#!/usr/bin/env bash
_last=""
while [[ \$# -gt 0 ]]; do
  case "\$1" in
    --output-last-message) _last="\$2"; shift 2;;
    *) shift;;
  esac
done
if [[ -n "\${PM_DISPATCH_STATE_ROOT:-}" ]]; then
  while IFS= read -r -d '' _ef; do
    chmod 000 "\$_ef"
  done < <(find "\${PM_DISPATCH_STATE_ROOT}" -name events.jsonl -type f -print0 2>/dev/null)
fi
[[ -n "\$_last" ]] && printf 'dispatch complete (poison codex)\n' > "\$_last"
printf '%s\n' '{"type":"turn.completed","usage":{"input_tokens":1,"output_tokens":1}}'
exit $code
FAKEOF
  chmod +x "$bindir/codex"
}

case_store_root_override() {
  # Verifies that PM_DISPATCH_STATE_ROOT env var overrides the default state store root path.
  #
  # Steps:
  #   1. Unset all store-root env vars.
  #   2. Call _sw_store_root with PM_DISPATCH_STATE_ROOT=/tmp/test-state-override.
  #   3. Assert the printed path equals the override value.
  local name="state_store_root: PM_DISPATCH_STATE_ROOT override"
  should_run "$name" || return 0
  local out
  reset_state_env
  out="$(PM_DISPATCH_STATE_ROOT=/tmp/test-state-override _sw_store_root)"
  if [[ "$out" == "/tmp/test-state-override" ]]; then
    pass "$name"
  else
    fail "$name" "got: $out"
  fi
}

case_store_root_xdg() {
  # Verifies that XDG_DATA_HOME is used as a fallback store root when PM_DISPATCH_STATE_ROOT is unset.
  #
  # Steps:
  #   1. Unset PM_DISPATCH_STATE_ROOT; set XDG_DATA_HOME=/tmp/test-xdg.
  #   2. Call _sw_store_root.
  #   3. Assert the printed path equals /tmp/test-xdg/pm-dispatch/state.
  local name="state_store_root: XDG_DATA_HOME fallback"
  should_run "$name" || return 0
  local out
  reset_state_env
  out="$(XDG_DATA_HOME=/tmp/test-xdg _sw_store_root)"
  if [[ "$out" == "/tmp/test-xdg/pm-dispatch/state" ]]; then
    pass "$name"
  else
    fail "$name" "got: $out"
  fi
}

case_store_root_default() {
  # Verifies that the default store root ~/.local/share/pm-dispatch/state is used when no env override is set.
  #
  # Steps:
  #   1. Unset PM_DISPATCH_STATE_ROOT and XDG_DATA_HOME; set HOME=/tmp/test-home.
  #   2. Call _sw_store_root.
  #   3. Assert the printed path equals /tmp/test-home/.local/share/pm-dispatch/state.
  local name="state_store_root: default path"
  should_run "$name" || return 0
  local out
  reset_state_env
  out="$(HOME=/tmp/test-home _sw_store_root)"
  if [[ "$out" == "/tmp/test-home/.local/share/pm-dispatch/state" ]]; then
    pass "$name"
  else
    fail "$name" "got: $out"
  fi
}

case_state_store_init_structure() {
  # Verifies that state_store_init creates all required project subdirs and a VERSION=1 file.
  #
  # Steps:
  #   1. Set PM_DISPATCH_STATE_ROOT to a fresh tmpdir.
  #   2. Call state_store_init.
  #   3. Assert tasks/, reviews/, decisions/, context-packs/, and archive/ all exist.
  #   4. Assert $STORE/VERSION contains exactly "1".
  local name="state_store_init: creates directory structure"
  should_run "$name" || return 0
  local store proj_dir missing=()
  store="$tmp_root/state-init"
  PM_DISPATCH_STATE_ROOT="$store" state_store_init
  proj_dir="$(PM_DISPATCH_STATE_ROOT="$store" _sw_project_dir)"
  for d in tasks reviews decisions context-packs archive; do
    [[ -d "$proj_dir/$d" ]] || missing+=("$d")
  done
  if [[ "${#missing[@]}" -eq 0 && -f "$store/VERSION" && "$(cat "$store/VERSION")" == "1" ]]; then
    pass "$name"
  else
    fail "$name" "missing=${missing[*]} version=$(cat "$store/VERSION" 2>/dev/null || true)"
  fi
}

case_state_store_init_store_root_mode() {
  # Verifies that state_store_init creates a fresh store root with private permissions.
  #
  # Steps:
  #   1. Set PM_DISPATCH_STATE_ROOT to a fresh tmpdir path.
  #   2. Call state_store_init with the global partition explicitly allowed.
  #   3. Assert the store root and project dir exist with mode 0700.
  local name="state_store_init: store root and project dir are mode 0700"
  should_run "$name" || return 0
  local store proj_dir root_mode proj_mode probe
  # NTFS/MSYS chmod is a no-op — Unix permission bits cannot be enforced there.
  # Probe the filesystem once; if 0700 does not stick, skip rather than fail.
  probe="$tmp_root/.perm-probe"
  mkdir -p "$probe" 2>/dev/null && chmod 0700 "$probe" 2>/dev/null
  if [[ "$(state_store_mode "$probe" 2>/dev/null || true)" != "700" ]]; then
    printf 'SKIP: %s (filesystem cannot enforce Unix permissions)\n' "$name"
    rm -rf "$probe" 2>/dev/null || true
    return 0
  fi
  rm -rf "$probe" 2>/dev/null || true
  store="$tmp_root/root-mode"
  PM_DISPATCH_STATE_ROOT="$store" _SW_ALLOW_GLOBAL_PARTITION=1 state_store_init >/dev/null 2>&1
  proj_dir="$(PM_DISPATCH_STATE_ROOT="$store" _SW_ALLOW_GLOBAL_PARTITION=1 _sw_project_dir)"
  root_mode="$(state_store_mode "$store" 2>/dev/null || true)"
  proj_mode="$(state_store_mode "$proj_dir" 2>/dev/null || true)"
  if [[ "$root_mode" == "700" && "$proj_mode" == "700" ]]; then
    pass "$name"
  else
    fail "$name" "root_mode=${root_mode:-empty} proj_mode=${proj_mode:-empty}"
  fi
}

case_state_store_init_symlink_leaf_rejected() {
  # Verifies that a symlinked store-root leaf is rejected before layout creation.
  #
  # Steps:
  #   1. Create a real target directory (mode 0755) and a symlink pointing at it.
  #   2. Call state_store_init with PM_DISPATCH_STATE_ROOT set to the symlink.
  #   3. Assert the call fails loudly, no VERSION is written through the symlink,
  #      AND the target's mode is unmodified (rejection must not chmod the target).
  local name="state_store_init: symlinked store-root leaf is rejected"
  should_run "$name" || return 0
  local target link rc=0 stderr_out before after
  target="$tmp_root/root-symlink-target"
  link="$tmp_root/root-symlink"
  mkdir -p "$target"
  chmod 0755 "$target"
  ln -s "$target" "$link"
  if [[ ! -L "$link" ]]; then
    pass "$name (skip: symlinks unavailable)"
    return 0
  fi
  before="$(_sw_path_mode_octal "$target")"
  stderr_out="$(PM_DISPATCH_STATE_ROOT="$link" _SW_ALLOW_GLOBAL_PARTITION=1 state_store_init 2>&1 >/dev/null)" || rc=$?
  after="$(_sw_path_mode_octal "$target")"
  if [[ "$rc" -ne 0 && "$stderr_out" == *"symlink"* && ! -e "$target/VERSION" && "$before" == "$after" ]]; then
    pass "$name"
  else
    fail "$name" "rc=$rc stderr=${stderr_out:-empty} version_exists=$([[ -e "$target/VERSION" ]] && printf yes || printf no) before=$before after=$after"
  fi
}

case_state_store_init_symlink_leaf_escape_hatch() {
  # Verifies that the unsafe-root escape hatch downgrades a symlinked leaf rejection to a warning.
  #
  # Steps:
  #   1. Create a real target directory and a symlink pointing at it.
  #   2. Call state_store_init with PM_DISPATCH_ALLOW_UNSAFE_STATE_ROOT=1.
  #   3. Assert the call succeeds, warns, and writes VERSION through the configured root.
  local name="state_store_init: unsafe-root escape hatch allows symlinked leaf"
  should_run "$name" || return 0
  local target link rc=0 stderr_out
  target="$tmp_root/root-symlink-allowed-target"
  link="$tmp_root/root-symlink-allowed"
  mkdir -p "$target"
  ln -s "$target" "$link"
  if [[ ! -L "$link" ]]; then
    pass "$name (skip: symlinks unavailable)"
    return 0
  fi
  stderr_out="$(PM_DISPATCH_STATE_ROOT="$link" PM_DISPATCH_ALLOW_UNSAFE_STATE_ROOT=1 \
    _SW_ALLOW_GLOBAL_PARTITION=1 state_store_init 2>&1 >/dev/null)" || rc=$?
  if [[ "$rc" -eq 0 && "$stderr_out" == *"warning: unsafe state root"* && "$(cat "$target/VERSION" 2>/dev/null)" == "1" ]]; then
    pass "$name"
  else
    fail "$name" "rc=$rc stderr=${stderr_out:-empty}"
  fi
}

case_state_store_init_world_writable_rejected_when_chmod_cannot_secure() {
  # Verifies that a store root left group/world-writable after chmod is rejected.
  #
  # Steps:
  #   1. Create a 0777 store root.
  #   2. Simulate a chmod that reports success but leaves the root writable.
  #   3. Assert state_store_init fails loudly before writing VERSION.
  local name="state_store_init: world-writable root rejected when chmod cannot secure"
  should_run "$name" || return 0
  local store rc=0 stderr_out
  store="$tmp_root/root-world-writable"
  mkdir -p "$store"
  chmod 0777 "$store"
  stderr_out="$({
    chmod() {
      if [[ "${1:-}" == "0700" ]]; then
        return 0
      fi
      command chmod "$@"
    }
    PM_DISPATCH_STATE_ROOT="$store" _SW_ALLOW_GLOBAL_PARTITION=1 state_store_init
  } 2>&1 >/dev/null)" || rc=$?
  command chmod 0700 "$store"
  if [[ "$rc" -ne 0 && "$stderr_out" == *"group/world writable"* && ! -e "$store/VERSION" ]]; then
    pass "$name"
  else
    fail "$name" "rc=$rc stderr=${stderr_out:-empty}"
  fi
}

case_state_store_init_world_writable_escape_hatch() {
  # Verifies that the unsafe-root escape hatch permits a root that remains writable after chmod.
  #
  # Steps:
  #   1. Create a 0777 store root.
  #   2. Simulate a chmod that reports success but leaves the root writable.
  #   3. Assert state_store_init succeeds with a warning.
  local name="state_store_init: unsafe-root escape hatch allows world-writable root"
  should_run "$name" || return 0
  local store rc=0 stderr_out
  store="$tmp_root/root-world-writable-allowed"
  mkdir -p "$store"
  chmod 0777 "$store"
  stderr_out="$({
    chmod() {
      if [[ "${1:-}" == "0700" ]]; then
        return 0
      fi
      command chmod "$@"
    }
    PM_DISPATCH_STATE_ROOT="$store" PM_DISPATCH_ALLOW_UNSAFE_STATE_ROOT=1 \
      _SW_ALLOW_GLOBAL_PARTITION=1 state_store_init
  } 2>&1 >/dev/null)" || rc=$?
  command chmod 0700 "$store"
  if [[ "$rc" -eq 0 && "$stderr_out" == *"warning: unsafe state root"* && "$(cat "$store/VERSION" 2>/dev/null)" == "1" ]]; then
    pass "$name"
  else
    fail "$name" "rc=$rc stderr=${stderr_out:-empty}"
  fi
}

case_state_store_init_group_only_writable_rejected() {
  # Verifies a store root left GROUP-writable only (0720) after an ineffective chmod
  # is rejected — the either-bit permission check must catch a single write bit.
  #
  # Steps:
  #   1. Create a 0720 store root.
  #   2. Simulate a chmod that reports success but leaves the root group-writable.
  #   3. Assert state_store_init fails loudly before writing VERSION.
  local name="state_store_init: group-only-writable root rejected"
  should_run "$name" || return 0
  local store rc=0 stderr_out
  store="$tmp_root/root-group-writable"
  mkdir -p "$store"
  chmod 0720 "$store"
  stderr_out="$({
    chmod() {
      if [[ "${1:-}" == "0700" ]]; then
        return 0
      fi
      command chmod "$@"
    }
    PM_DISPATCH_STATE_ROOT="$store" _SW_ALLOW_GLOBAL_PARTITION=1 state_store_init
  } 2>&1 >/dev/null)" || rc=$?
  command chmod 0700 "$store"
  if [[ "$rc" -ne 0 && "$stderr_out" == *"group/world writable"* && ! -e "$store/VERSION" ]]; then
    pass "$name"
  else
    fail "$name" "rc=$rc stderr=${stderr_out:-empty}"
  fi
}

case_state_store_init_world_only_writable_rejected() {
  # Verifies a store root left WORLD-writable only (0702) after an ineffective chmod
  # is rejected — the either-bit permission check must catch a single write bit.
  #
  # Steps:
  #   1. Create a 0702 store root.
  #   2. Simulate a chmod that reports success but leaves the root world-writable.
  #   3. Assert state_store_init fails loudly before writing VERSION.
  local name="state_store_init: world-only-writable root rejected"
  should_run "$name" || return 0
  local store rc=0 stderr_out
  store="$tmp_root/root-other-writable"
  mkdir -p "$store"
  chmod 0702 "$store"
  stderr_out="$({
    chmod() {
      if [[ "${1:-}" == "0700" ]]; then
        return 0
      fi
      command chmod "$@"
    }
    PM_DISPATCH_STATE_ROOT="$store" _SW_ALLOW_GLOBAL_PARTITION=1 state_store_init
  } 2>&1 >/dev/null)" || rc=$?
  command chmod 0700 "$store"
  if [[ "$rc" -ne 0 && "$stderr_out" == *"group/world writable"* && ! -e "$store/VERSION" ]]; then
    pass "$name"
  else
    fail "$name" "rc=$rc stderr=${stderr_out:-empty}"
  fi
}

case_state_store_init_non_owner_rejected_when_simulatable() {
  # Verifies that an existing store root not owned by the effective user is rejected.
  #
  # Steps:
  #   1. Skip unless running with permission to change ownership.
  #   2. Create a store root and chown it away from the effective user.
  #   3. Assert state_store_init fails loudly without writing VERSION.
  local name="state_store_init: non-owned store root is rejected"
  should_run "$name" || return 0
  if [[ "$(id -u)" -ne 0 ]]; then
    pass "$name (skip: ownership change requires root)"
    return 0
  fi
  local store rc=0 stderr_out
  store="$tmp_root/root-non-owner"
  mkdir -p "$store"
  if ! chown 65534:65534 "$store" 2>/dev/null; then
    pass "$name (skip: could not assign alternate owner)"
    return 0
  fi
  stderr_out="$(PM_DISPATCH_STATE_ROOT="$store" _SW_ALLOW_GLOBAL_PARTITION=1 state_store_init 2>&1 >/dev/null)" || rc=$?
  chown "$(id -u):$(id -g)" "$store" 2>/dev/null || true
  if [[ "$rc" -ne 0 && "$stderr_out" == *"not owned"* && ! -e "$store/VERSION" ]]; then
    pass "$name"
  else
    fail "$name" "rc=$rc stderr=${stderr_out:-empty}"
  fi
}

case_state_store_init_version1_noop() {
  # Verifies that state_store_init is idempotent when VERSION=1 already exists.
  #
  # Steps:
  #   1. Create a store root with a pre-existing VERSION=1 file.
  #   2. Call state_store_init; assert it returns 0.
  #   3. Assert VERSION content is still "1" (file not rewritten).
  local name="state_store_init: VERSION=1 existing -> noop (file unchanged)"
  should_run "$name" || return 0
  local store before after
  store="$tmp_root/init-v1-noop"
  mkdir -p "$store"
  printf '1\n' > "$store/VERSION"
  before="$(cat "$store/VERSION")"
  PM_DISPATCH_STATE_ROOT="$store" state_store_init
  after="$(cat "$store/VERSION")"
  if [[ "$before" == "$after" && "$after" == "1" ]]; then
    pass "$name"
  else
    fail "$name" "VERSION changed: before=$before after=$after"
  fi
}

case_state_store_init_version2_fails() {
  # Verifies that state_store_init rejects VERSION=2 with a non-zero exit and an
  # "unsupported" stderr message, and does NOT create any new layout entries.
  #
  # Steps:
  #   1. Create a store root containing only a VERSION=2 file.
  #   2. Call state_store_init; assert it returns non-zero.
  #   3. Assert stderr contains "unsupported".
  #   4. Assert no new entries were created beyond VERSION (no tasks/, no project dirs).
  local name="state_store_init: VERSION=2 -> fail loud (unsupported)"
  should_run "$name" || return 0
  local store rc=0 stderr_out new_entries
  store="$tmp_root/init-v2-fail"
  mkdir -p "$store"
  printf '2\n' > "$store/VERSION"
  stderr_out="$(PM_DISPATCH_STATE_ROOT="$store" state_store_init 2>&1 >/dev/null)" || rc=$?
  # Count everything in the store except the VERSION file itself.
  new_entries="$(find "$store" -mindepth 1 ! -name VERSION 2>/dev/null | wc -l)"
  if [[ "$rc" -ne 0 ]] && printf '%s' "$stderr_out" | grep -q "unsupported" \
      && [[ "$new_entries" -eq 0 ]]; then
    pass "$name"
  else
    fail "$name" "rc=$rc stderr=$stderr_out new_entries=$new_entries"
  fi
}

case_state_store_init_version2_does_not_mutate_mode() {
  # Verifies that rejecting an unsupported VERSION=2 store does NOT mutate the
  # store root — the mutating safety preflight (chmod 0700) must run only after
  # the version gate passes, so a future store's mode is preserved.
  #
  # Steps:
  #   1. Create a 0755 store root containing only a VERSION=2 file.
  #   2. Capture the pre-call mode; call state_store_init (expect non-zero).
  #   3. Assert the mode is unchanged and was not reset to 0700.
  local name="state_store_init: VERSION=2 store mode is not mutated"
  should_run "$name" || return 0
  local store rc=0 before after
  store="$tmp_root/init-v2-immutable"
  mkdir -p "$store"
  chmod 0755 "$store"
  printf '2\n' > "$store/VERSION"
  before="$(_sw_path_mode_octal "$store")"
  PM_DISPATCH_STATE_ROOT="$store" state_store_init >/dev/null 2>&1 || rc=$?
  after="$(_sw_path_mode_octal "$store")"
  command chmod 0700 "$store" 2>/dev/null || true
  if [[ "$rc" -ne 0 && "$before" == "$after" && "$before" != "700" ]]; then
    pass "$name"
  else
    fail "$name" "rc=$rc before=$before after=$after"
  fi
}

case_runs_append_fails_on_version2() {
  # Verifies that runs_append propagates state_store_init failure when VERSION=2.
  #
  # Steps:
  #   1. Create a store root with VERSION=2.
  #   2. Call runs_append with a valid Run JSON.
  #   3. Assert runs_append returns non-zero (VERSION gate propagated).
  local name="state_store_init: runs_append returns non-zero when VERSION=2"
  should_run "$name" || return 0
  local store rc=0
  store="$tmp_root/runs-v2-fail"
  mkdir -p "$store"
  printf '2\n' > "$store/VERSION"
  PM_DISPATCH_STATE_ROOT="$store" runs_append \
    '{"schema_version":1,"id":"run-20260101T000000Z-abcdef","task_id":"CC-230","executor":"codex","state":"ok","working_dir":"/tmp/test","trace_path":"/tmp/test.jsonl","exit_code":0,"created_ts":"2026-01-01T00:00:00Z"}' \
    >/dev/null 2>&1 || rc=$?
  if [[ "$rc" -ne 0 ]]; then
    pass "$name"
  else
    fail "$name" "expected non-zero, got rc=$rc"
  fi
}

case_runs_append_valid_jsonl() {
  # Verifies that runs_append creates runs.jsonl with exactly one valid JSON line.
  #
  # Steps:
  #   1. Call runs_append with a minimal valid Run JSON object.
  #   2. Resolve the project dir for the store root.
  #   3. Assert runs.jsonl exists and has exactly one line.
  #   4. Assert that line parses as valid JSON via jq.
  local name="runs_append: creates runs.jsonl with valid JSONL"
  should_run "$name" || return 0
  local store proj_dir line
  store="$tmp_root/runs-one"
  PM_DISPATCH_STATE_ROOT="$store" runs_append '{"schema_version":2,"id":"run-20260101T000000Z-abcdef","task_id":"CC-230","executor":"codex","state":"ok","working_dir":"/tmp/test","trace_path":"/tmp/test.jsonl","exit_code":0,"created_ts":"2026-01-01T00:00:00Z"}'
  proj_dir="$(PM_DISPATCH_STATE_ROOT="$store" _sw_project_dir)"
  line="$(cat "$proj_dir/runs.jsonl" 2>/dev/null || true)"
  if [[ -f "$proj_dir/runs.jsonl" && "$(wc -l < "$proj_dir/runs.jsonl")" == "1" ]] &&
    jq . >/dev/null 2>&1 <<< "$line"; then
    pass "$name"
  else
    fail "$name" "runs.jsonl not one valid JSON line"
  fi
}

case_runs_append_appends() {
  # Verifies that a second runs_append call appends a new row rather than overwriting.
  #
  # Steps:
  #   1. Call runs_append twice with distinct run IDs into the same store.
  #   2. Assert runs.jsonl contains exactly two lines.
  local name="runs_append: second call appends (not overwrites)"
  should_run "$name" || return 0
  local store proj_dir
  store="$tmp_root/runs-two"
  PM_DISPATCH_STATE_ROOT="$store" runs_append '{"schema_version":2,"id":"run-20260101T000000Z-abcdef","task_id":"CC-230","executor":"codex","state":"ok","working_dir":"/tmp/test","trace_path":"/tmp/test.jsonl","exit_code":0,"created_ts":"2026-01-01T00:00:00Z"}'
  PM_DISPATCH_STATE_ROOT="$store" runs_append '{"schema_version":2,"id":"run-20260101T000001Z-123456","task_id":"CC-230","executor":"codex","state":"failed","working_dir":"/tmp/test","trace_path":"/tmp/test.jsonl","exit_code":1,"created_ts":"2026-01-01T00:00:01Z"}'
  proj_dir="$(PM_DISPATCH_STATE_ROOT="$store" _sw_project_dir)"
  if [[ -f "$proj_dir/runs.jsonl" && "$(wc -l < "$proj_dir/runs.jsonl")" == "2" ]]; then
    pass "$name"
  else
    fail "$name" "line_count=$(wc -l < "$proj_dir/runs.jsonl" 2>/dev/null || true)"
  fi
}

case_events_append() {
  # Verifies that events_append creates events.jsonl with exactly one valid JSON line.
  #
  # Steps:
  #   1. Call events_append with a schema-valid Event JSON object.
  #   2. Resolve the project dir for the store root.
  #   3. Assert events.jsonl exists and has exactly one line.
  #   4. Assert that line parses as valid JSON via jq.
  local name="events_append: creates events.jsonl"
  should_run "$name" || return 0
  local store proj_dir line
  store="$tmp_root/events-one"
  PM_DISPATCH_STATE_ROOT="$store" events_append '{"schema_version":1,"id":"evt-20260101T000000Z-abcdef","kind":"run.completed","subject_type":"run","subject_id":"run-20260101T000000Z-abcdef","ts":"2026-01-01T00:00:00Z","payload":{"run_id":"run-20260101T000000Z-abcdef","state":"ok","from_state":"verifying","to_state":"ok"}}'
  proj_dir="$(PM_DISPATCH_STATE_ROOT="$store" _sw_project_dir)"
  line="$(cat "$proj_dir/events.jsonl" 2>/dev/null || true)"
  if [[ -f "$proj_dir/events.jsonl" && "$(wc -l < "$proj_dir/events.jsonl")" == "1" ]] &&
    jq . >/dev/null 2>&1 <<< "$line"; then
    pass "$name"
  else
    fail "$name" "events.jsonl not one valid JSON line"
  fi
}

case_runs_append_rejects_newline() {
  local name="state-store: runs_append rejects json_line with embedded newline"
  should_run "$name" || return 0
  local store rc=0
  store="$tmp_root/runs-newline"
  PM_DISPATCH_STATE_ROOT="$store" runs_append $'{"schema_version":1,\n"id":"run-20260101T000000Z-abcdef"}' >/dev/null 2>&1 || rc=$?
  if [[ "$rc" -ne 0 ]] && ! find "$store" -name runs.jsonl -type f 2>/dev/null | grep -q .; then
    pass "$name"
  else
    fail "$name" "expected non-zero and no runs.jsonl, rc=$rc"
  fi
}

case_runs_append_rejects_nul() {
  local name="state-store: runs_append rejects json_line with embedded NUL"
  should_run "$name" || return 0
  local store rc=0
  store="$tmp_root/runs-nul"
  PM_DISPATCH_STATE_ROOT="$store" runs_append $'{"schema_version":1\0' >/dev/null 2>&1 || rc=$?
  if [[ "$rc" -ne 0 ]] && ! find "$store" -name runs.jsonl -type f 2>/dev/null | grep -q .; then
    pass "$name"
  else
    fail "$name" "expected non-zero and no runs.jsonl, rc=$rc"
  fi
}

case_events_append_rejects_newline() {
  local name="state-store: events_append rejects json_line with embedded newline"
  should_run "$name" || return 0
  local store rc=0
  store="$tmp_root/events-newline"
  PM_DISPATCH_STATE_ROOT="$store" events_append $'{"schema_version":1,\n"id":"evt-20260101T000000Z-abcdef"}' >/dev/null 2>&1 || rc=$?
  if [[ "$rc" -ne 0 ]] && ! find "$store" -name events.jsonl -type f 2>/dev/null | grep -q .; then
    pass "$name"
  else
    fail "$name" "expected non-zero and no events.jsonl, rc=$rc"
  fi
}

case_events_append_rejects_nul() {
  local name="state-store: events_append rejects json_line with embedded NUL"
  should_run "$name" || return 0
  local store rc=0
  store="$tmp_root/events-nul"
  PM_DISPATCH_STATE_ROOT="$store" events_append $'{"schema_version":1\0' >/dev/null 2>&1 || rc=$?
  if [[ "$rc" -ne 0 ]] && ! find "$store" -name events.jsonl -type f 2>/dev/null | grep -q .; then
    pass "$name"
  else
    fail "$name" "expected non-zero and no events.jsonl, rc=$rc"
  fi
}

case_events_append_rejects_run_event_without_payload() {
  # Verifies that events_append rejects a run.* event that is missing the
  # required payload field enforced by core/schema/event.schema.json if/then.
  #
  # Steps:
  #   1. Call events_append with a run.completed event that has no payload field.
  #   2. Assert events_append returns non-zero (schema rejects missing payload).
  local name="state-store: events_append rejects run.completed event missing payload"
  should_run "$name" || return 0
  if ! command -v jsonschema >/dev/null 2>&1; then
    pass "$name (skip: jsonschema not available)"
    return 0
  fi
  local store rc=0
  store="$tmp_root/events-no-payload"
  PM_DISPATCH_STATE_ROOT="$store" events_append \
    '{"schema_version":1,"id":"evt-20260101T000000Z-abcdef","ts":"2026-01-01T00:00:00Z","kind":"run.completed","subject_type":"run","subject_id":"run-20260101T000000Z-abcdef"}' \
    >/dev/null 2>&1 || rc=$?
  if [[ "$rc" -ne 0 ]]; then
    pass "$name"
  else
    fail "$name" "expected non-zero for run.completed event without payload, got rc=$rc"
  fi
}

case_events_append_rejects_run_event_wrong_payload_type() {
  # Verifies that events_append rejects a run.* event whose payload fields have
  # wrong types (numeric run_id instead of string), per the type constraints in
  # core/schema/event.schema.json if/then.
  #
  # Steps:
  #   1. Call events_append with a run.completed event where run_id is an integer.
  #   2. Assert events_append returns non-zero (schema rejects numeric run_id).
  local name="state-store: events_append rejects run.completed event with wrong-typed payload"
  should_run "$name" || return 0
  if ! command -v jsonschema >/dev/null 2>&1; then
    pass "$name (skip: jsonschema not available)"
    return 0
  fi
  local store rc=0
  store="$tmp_root/events-wrong-type-payload"
  PM_DISPATCH_STATE_ROOT="$store" events_append \
    '{"schema_version":1,"id":"evt-20260101T000000Z-abcdef","ts":"2026-01-01T00:00:00Z","kind":"run.completed","subject_type":"run","subject_id":"run-20260101T000000Z-abcdef","payload":{"run_id":123,"state":"ok","from_state":"verifying","to_state":"ok"}}' \
    >/dev/null 2>&1 || rc=$?
  if [[ "$rc" -ne 0 ]]; then
    pass "$name"
  else
    fail "$name" "expected non-zero for run.completed event with numeric run_id, got rc=$rc"
  fi
}

case_runs_append_compacts_json() {
  local name="state-store: runs_append compacts JSON through jq -c"
  should_run "$name" || return 0
  local store proj_dir line expected
  store="$tmp_root/runs-compact"
  PM_DISPATCH_STATE_ROOT="$store" runs_append '{ "schema_version" : 2, "id" : "run-20260101T000000Z-abcdef", "task_id" : "CC-230", "executor" : "codex", "state" : "ok", "working_dir" : "/tmp/test", "trace_path" : "/tmp/test.jsonl", "exit_code" : 0, "created_ts" : "2026-01-01T00:00:00Z" }'
  proj_dir="$(PM_DISPATCH_STATE_ROOT="$store" _sw_project_dir)"
  line="$(cat "$proj_dir/runs.jsonl" 2>/dev/null || true)"
  expected='{"schema_version":2,"id":"run-20260101T000000Z-abcdef","task_id":"CC-230","executor":"codex","state":"ok","working_dir":"/tmp/test","trace_path":"/tmp/test.jsonl","exit_code":0,"created_ts":"2026-01-01T00:00:00Z"}'
  if [[ "$line" == "$expected" ]]; then
    pass "$name"
  else
    fail "$name" "got: $line"
  fi
}

case_runs_append_rejects_malformed_json() {
  local name="state-store: runs_append rejects malformed JSON (jq -c fails)"
  should_run "$name" || return 0
  local store rc=0
  store="$tmp_root/runs-malformed"
  PM_DISPATCH_STATE_ROOT="$store" runs_append '{"schema_version":1' >/dev/null 2>&1 || rc=$?
  if [[ "$rc" -ne 0 ]] && ! find "$store" -name runs.jsonl -type f 2>/dev/null | grep -q .; then
    pass "$name"
  else
    fail "$name" "expected non-zero and no runs.jsonl, rc=$rc"
  fi
}

case_runs_append_rejects_schema_invalid() {
  local name="state-store: runs_append rejects schema-invalid Run JSON"
  should_run "$name" || return 0
  if ! command -v jsonschema >/dev/null 2>&1; then
    pass "$name (skip: jsonschema not available)"
    return 0
  fi
  local store rc=0
  store="$tmp_root/runs-schema-invalid"
  PM_DISPATCH_STATE_ROOT="$store" runs_append '{"schema_version":1,"id":"not-a-run"}' >/dev/null 2>&1 || rc=$?
  if [[ "$rc" -ne 0 ]] && ! find "$store" -name runs.jsonl -type f 2>/dev/null | grep -q .; then
    pass "$name"
  else
    fail "$name" "expected non-zero schema failure, rc=$rc"
  fi
}

case_task_upsert() {
  # Verifies that task_upsert atomically writes the task file using write-temp-then-rename.
  #
  # Steps:
  #   1. Call task_upsert with task_id "TASK-230" and a JSON body.
  #   2. Resolve tasks/TASK-230.json under the project dir.
  #   3. Assert the file exists and its content matches the input JSON exactly.
  local name="task_upsert: write-temp-then-rename"
  should_run "$name" || return 0
  local store proj_dir task_file expected
  store="$tmp_root/task-upsert"
  expected='{"schema_version":1,"id":"TASK-230","title":"test","state":"planned","created_ts":"2026-01-01T00:00:00Z"}'
  PM_DISPATCH_STATE_ROOT="$store" task_upsert "TASK-230" "$expected"
  proj_dir="$(PM_DISPATCH_STATE_ROOT="$store" _sw_project_dir)"
  task_file="$proj_dir/tasks/TASK-230.json"
  if [[ -f "$task_file" && "$(cat "$task_file")" == "$expected" ]]; then
    pass "$name"
  else
    fail "$name" "task file mismatch"
  fi
}

case_task_upsert_invalid_id() {
  # Verifies that task_upsert with an invalid task_id returns non-zero (fail-loud)
  # and does not create any file, preventing path traversal or unexpected file creation.
  # Contract change: invalid IDs now fail loudly (return 1) so callers can propagate errors.
  #
  # Steps:
  #   1. Call task_upsert with "../evil" as task_id and any JSON body.
  #   2. Assert the return code is non-zero.
  #   3. Assert no file was created at or near the tasks/ dir.
  local name="task_upsert: invalid task_id is rejected with non-zero exit, no file created"
  should_run "$name" || return 0
  local store rc=0
  store="$tmp_root/task-invalid"
  PM_DISPATCH_STATE_ROOT="$store" task_upsert "../evil" '{"id":"evil"}' || rc=$?
  # Check: exit code is non-zero AND no evil file was written anywhere in the store
  if [[ "$rc" -ne 0 ]] && ! find "$store" -name "evil.json" -o -name "evil" 2>/dev/null | grep -q .; then
    pass "$name"
  else
    fail "$name" "rc=$rc or unexpected file exists under $store"
  fi
}

case_task_upsert_version2_blocked() {
  # Verifies that task_upsert does not write a task file when the state store has
  # an unsupported VERSION=2, even when the tasks/ directory already exists.
  #
  # Steps:
  #   1. Create a store root with VERSION=2 and a pre-existing tasks/ directory.
  #   2. Call task_upsert with a valid task_id and JSON body.
  #   3. Assert no task file was written inside tasks/.
  local name="task_upsert: VERSION=2 store blocks write (no task file created)"
  should_run "$name" || return 0
  local store proj_dir written rc=0
  store="$tmp_root/task-v2-block"
  proj_dir="$(PM_DISPATCH_STATE_ROOT="$store" _sw_project_dir)"
  mkdir -p "$proj_dir/tasks"
  printf '2\n' > "$store/VERSION"
  PM_DISPATCH_STATE_ROOT="$store" task_upsert "CC-999" '{"id":"CC-999"}' >/dev/null 2>&1 || rc=$?
  written="$(find "$proj_dir/tasks" -name 'CC-999.json' 2>/dev/null | wc -l)"
  if [[ "$written" -ne 0 ]]; then
    fail "$name" "task file was written despite VERSION=2 (rc=$rc written=$written)"
  elif [[ "$rc" -eq 0 ]]; then
    fail "$name" "task_upsert returned rc=0 but expected non-zero for VERSION=2 rejection"
  else
    pass "$name"
  fi
}

case_decision_upsert() {
  # Verifies that decision_upsert atomically writes the decision file using write-temp-then-rename.
  #
  # Steps:
  #   1. Call decision_upsert with a valid decision_id and a JSON body.
  #   2. Resolve decisions/<decision_id>.json under the project dir.
  #   3. Assert the file exists and its content matches the input JSON exactly.
  local name="decision_upsert: write-temp-then-rename"
  should_run "$name" || return 0
  local store proj_dir dec_file expected
  store="$tmp_root/decision-upsert"
  expected='{"schema_version":1,"id":"dec-2026-06-07-test-decision","date":"2026-06-07","title":"Test Decision","decision_md_path":"DECISIONS.md"}'
  PM_DISPATCH_STATE_ROOT="$store" decision_upsert "dec-2026-06-07-test-decision" "$expected"
  proj_dir="$(PM_DISPATCH_STATE_ROOT="$store" _sw_project_dir)"
  dec_file="$proj_dir/decisions/dec-2026-06-07-test-decision.json"
  if [[ -f "$dec_file" && "$(cat "$dec_file")" == "$expected" ]]; then
    pass "$name"
  else
    fail "$name" "decision file mismatch"
  fi
}

case_decision_upsert_invalid_id() {
  # Verifies that decision_upsert with an invalid decision_id returns non-zero (fail-loud)
  # and does not create any file, preventing path traversal or unexpected file creation.
  #
  # Steps:
  #   1. Call decision_upsert with "../evil-dec" as decision_id and any JSON body.
  #   2. Assert the return code is non-zero.
  #   3. Assert no file was created at or near the decisions/ dir.
  local name="decision_upsert: invalid decision_id is rejected with non-zero exit, no file created"
  should_run "$name" || return 0
  local store rc=0
  store="$tmp_root/decision-invalid"
  PM_DISPATCH_STATE_ROOT="$store" decision_upsert "../evil-dec" '{"id":"evil"}' || rc=$?
  if [[ "$rc" -ne 0 ]] && ! find "$store" -name "evil-dec.json" -o -name "evil-dec" 2>/dev/null | grep -q .; then
    pass "$name"
  else
    fail "$name" "rc=$rc or unexpected file exists under $store"
  fi
}

case_decision_upsert_version2_blocked() {
  # Verifies that decision_upsert does not write a decision file when the state store has
  # an unsupported VERSION=2, even when the decisions/ directory already exists.
  #
  # Steps:
  #   1. Create a store root with VERSION=2 and a pre-existing decisions/ directory.
  #   2. Call decision_upsert with a valid decision_id and JSON body.
  #   3. Assert no decision file was written inside decisions/.
  local name="decision_upsert: VERSION=2 store blocks write (no decision file created)"
  should_run "$name" || return 0
  local store proj_dir written rc=0
  store="$tmp_root/decision-v2-block"
  proj_dir="$(PM_DISPATCH_STATE_ROOT="$store" _sw_project_dir)"
  mkdir -p "$proj_dir/decisions"
  printf '2\n' > "$store/VERSION"
  PM_DISPATCH_STATE_ROOT="$store" decision_upsert "dec-2026-06-07-blocked" '{"id":"dec-2026-06-07-blocked"}' >/dev/null 2>&1 || rc=$?
  written="$(find "$proj_dir/decisions" -name 'dec-2026-06-07-blocked.json' 2>/dev/null | wc -l)"
  if [[ "$written" -ne 0 ]]; then
    fail "$name" "decision file was written despite VERSION=2 (rc=$rc written=$written)"
  elif [[ "$rc" -eq 0 ]]; then
    fail "$name" "decision_upsert returned rc=0 but expected non-zero for VERSION=2 rejection"
  else
    pass "$name"
  fi
}

case_runs_append_read_only_fails_loudly() {
  # Verifies that runs_append returns non-zero when the canonical write path fails.
  #
  # Steps:
  #   1. Initialize a store and replace runs.jsonl with a directory at the append path.
  #   2. Call runs_append against that store; capture its exit code.
  #   3. Assert the append failure propagates as a non-zero exit.
  local name="state-store: runs_append propagates non-zero when inner append fails"
  should_run "$name" || return 0
  local store proj_dir rc=0
  store="$tmp_root/runs-path-collision-store"
  PM_DISPATCH_STATE_ROOT="$store" state_store_init
  proj_dir="$(PM_DISPATCH_STATE_ROOT="$store" _sw_project_dir)"
  mkdir "$proj_dir/runs.jsonl"
  PM_DISPATCH_STATE_ROOT="$store" runs_append '{"schema_version":1,"id":"run-20260101T000000Z-abcdef","task_id":"CC-230","executor":"codex","state":"ok","working_dir":"/tmp/test","trace_path":"/tmp/test.jsonl","exit_code":0,"created_ts":"2026-01-01T00:00:00Z"}' >/dev/null 2>&1 || rc=$?
  if [[ "$rc" -ne 0 ]]; then
    pass "$name"
  else
    fail "$name" "exit=$rc"
  fi
}

case_codex_dispatch_state_store_self_contained() {
  # Verifies that the state-writer source guard in the adapter uses 2>/dev/null || true
  # so dispatch is functional even when state-writer.sh is absent.
  # The state-store block lives in adapters/codex/dispatch.sh (the legacy
  # scripts/codex-dispatch.sh shim was removed in the v0.3.0 sunset).
  #
  # Steps:
  #   1. Run bash -n on adapters/codex/dispatch.sh to verify syntax.
  #   2. Grep for the '. ... 2>/dev/null || true' source guard line.
  #   3. Assert both checks pass.
  local name="codex-dispatch.sh: state store block is self-contained"
  should_run "$name" || return 0
  if bash -n "$REPO_ROOT/adapters/codex/dispatch.sh" &&
    grep -Fq '. "$SCRIPT_DIR/lib/state-writer.sh" 2>/dev/null || true' "$REPO_ROOT/adapters/codex/dispatch.sh"; then
    pass "$name"
  else
    fail "$name" "syntax check or source guard missing"
  fi
}

case_pmctl_dispatch_creates_run_row() {
  # Verifies that pmctl dispatch owns the dispatch-to-state-store Run write and
  # that the row contains the expected load-bearing fields.
  local name="pmctl-dispatch: creates runs.jsonl row with correct schema/executor/state/exit fields"
  should_run "$name" || return 0
  local store fake_bin_dir brief_file work_dir
  store="$tmp_root/dispatch-run"
  fake_bin_dir="$tmp_root/dispatch-bin"
  work_dir="$tmp_root/dispatch-workdir"
  mkdir -p "$fake_bin_dir" "$work_dir"
  git -C "$work_dir" init -q
  install_fake_codex "$fake_bin_dir" 0
  brief_file="$(mk_pmctl_brief "$work_dir")"
  PM_DISPATCH_STATE_ROOT="$store" PATH="$fake_bin_dir:$PATH" \
    "$PMCTL" dispatch run --adapter codex --lifecycle foreground \\
    --cd "$work_dir" --brief-file "$brief_file" >/dev/null 2>&1 || true
  local runs_file schema_v executor state exit_code events_file event_kinds
  runs_file="$(find "$store" -name "runs.jsonl" -type f 2>/dev/null | head -1 || true)"
  schema_v="$(jq -r '.schema_version' "$runs_file" 2>/dev/null | tail -1 || true)"
  executor="$(jq -r '.executor' "$runs_file" 2>/dev/null | tail -1 || true)"
  state="$(jq -r '.state' "$runs_file" 2>/dev/null | tail -1 || true)"
  exit_code="$(jq -r '.exit_code' "$runs_file" 2>/dev/null | tail -1 || true)"
  events_file="$(find "$store" -name "events.jsonl" -type f 2>/dev/null | head -1 || true)"
  event_kinds="$(jq -r '.kind' "$events_file" 2>/dev/null | paste -sd, - || true)"
  if [[ "$schema_v" == "2" && "$executor" == "codex" && "$state" == "ok" && \
        "$exit_code" == "0" && "$event_kinds" == "run.pending,run.dispatched,run.verifying,run.completed" ]]; then
    pass "$name"
  else
    fail "$name" "schema=$schema_v executor=$executor state=$state exit=$exit_code events=${event_kinds:-none}"
  fi
}

case_pmctl_dispatch_correct_partition() {
  # Verifies that pmctl writes the run row into the target repo's
  # project partition (derived from WORK_DIR's git root), not the caller's cwd.
  #
  # Steps:
  #   1. git init a fresh tmpdir (work_dir) so it has its own git root.
  #   2. Compute the expected sha1 partition key for work_dir.
  #   3. Run codex-dispatch.sh --cd <work_dir>.
  #   4. Assert runs.jsonl appears under projects/<expected_key>/, not elsewhere.
  local name="pmctl-dispatch: run written to target project partition"
  should_run "$name" || return 0
  local store fake_bin_dir brief_file work_dir work_dir_key expected_partition
  store="$tmp_root/partition-store"
  fake_bin_dir="$tmp_root/partition-bin"
  work_dir="$tmp_root/partition-workdir"
  mkdir -p "$fake_bin_dir" "$work_dir"
  ( cd "$work_dir" && git init -q && git commit --allow-empty -m "init" -q ) 2>/dev/null || true
  work_dir_key="$(printf '%s\n' "$work_dir" | _portable_sha1 2>/dev/null || true)"
  install_fake_codex "$fake_bin_dir" 0
  brief_file="$(mk_pmctl_brief "$work_dir")"
  PM_DISPATCH_STATE_ROOT="$store" PATH="$fake_bin_dir:$PATH" \
    "$PMCTL" dispatch run --adapter codex --lifecycle foreground \\
    --cd "$work_dir" --brief-file "$brief_file" >/dev/null 2>&1 || true
  expected_partition="$store/projects/$work_dir_key"
  if [[ -f "$expected_partition/runs.jsonl" ]]; then
    pass "$name"
  else
    local actual
    actual="$(find "$store/projects" -name "runs.jsonl" 2>/dev/null | tr '\n' ' ' || true)"
    fail "$name" "expected $expected_partition/runs.jsonl; found: ${actual:-none}"
  fi
}

case_pmctl_dispatch_run_json_valid() {
  # Verifies that runs.jsonl row produced by pmctl dispatch is valid JSON
  # even when MODEL contains characters that would corrupt raw printf interpolation.
  #
  # Steps:
  #   1. Create a fake codex that exits 0.
  #   2. Run codex-dispatch.sh with --model set to a value with quotes/backslashes.
  #   3. Assert the runs.jsonl row parses with jq (exit 0).
  local name="pmctl-dispatch: run row is valid JSON with special chars in model"
  should_run "$name" || return 0
  local store fake_bin_dir brief_file work_dir runs_file
  store="$tmp_root/json-valid"
  fake_bin_dir="$tmp_root/json-valid-bin"
  work_dir="$tmp_root/json-valid-workdir"
  mkdir -p "$fake_bin_dir" "$work_dir"
  git -C "$work_dir" init -q
  install_fake_codex "$fake_bin_dir" 0
  brief_file="$(mk_pmctl_brief "$work_dir")"
  # Use a model name with characters that would corrupt printf-based JSON
  PM_DISPATCH_STATE_ROOT="$store" PATH="$fake_bin_dir:$PATH" \
    "$PMCTL" dispatch run --adapter codex --lifecycle foreground \\
    --cd "$work_dir" --model 'model-with-"quotes"' \
    --brief-file "$brief_file" >/dev/null 2>&1 || true
  runs_file="$(find "$store" -name "runs.jsonl" -type f 2>/dev/null | head -1 || true)"
  if [[ -n "$runs_file" ]] && jq -e . "$runs_file" >/dev/null 2>&1; then
    pass "$name"
  else
    fail "$name" "runs.jsonl missing or not valid JSON (file=${runs_file:-none})"
  fi
}

case_pmctl_dispatch_model_explicit() {
  # Verifies that an explicit --model flag is recorded in the Run row.
  local name="pmctl-dispatch: explicit --model stored in run row"
  should_run "$name" || return 0
  local store fake_bin_dir brief_file work_dir runs_file model_found
  store="$tmp_root/model-explicit-store"
  fake_bin_dir="$tmp_root/model-explicit-bin"
  work_dir="$tmp_root/model-explicit-workdir"
  mkdir -p "$fake_bin_dir" "$work_dir"
  git -C "$work_dir" init -q
  install_fake_codex "$fake_bin_dir" 0
  brief_file="$(mk_pmctl_brief "$work_dir")"
  PM_DISPATCH_STATE_ROOT="$store" PATH="$fake_bin_dir:$PATH" \
    "$PMCTL" dispatch run --adapter codex --lifecycle foreground \\
    --cd "$work_dir" --model "explicit-model-x" \
    --brief-file "$brief_file" >/dev/null 2>&1 || true
  runs_file="$(find "$store" -name "runs.jsonl" -type f 2>/dev/null | head -1 || true)"
  model_found="$(jq -r '.model' "$runs_file" 2>/dev/null | tail -1 || true)"
  if [[ "$model_found" == "explicit-model-x" ]]; then
    pass "$name"
  else
    fail "$name" "expected model=explicit-model-x got '${model_found:-none}' (runs_file=${runs_file:-none})"
  fi
}

case_pmctl_dispatch_model_config_default() {
  # Verifies that dispatch.default_model from the config file is stored in the
  # Run row when no explicit --model flag is given (uses PM_DISPATCH_CONFIG_FILE
  # to inject a fake config without touching ~/.pm-dispatch/config).
  local name="pmctl-dispatch: config dispatch.default_model stored in run row when no explicit --model"
  should_run "$name" || return 0
  local store fake_bin_dir brief_file work_dir runs_file model_found cfg_file
  store="$tmp_root/model-config-store"
  fake_bin_dir="$tmp_root/model-config-bin"
  work_dir="$tmp_root/model-config-workdir"
  mkdir -p "$fake_bin_dir" "$work_dir"
  git -C "$work_dir" init -q
  install_fake_codex "$fake_bin_dir" 0
  brief_file="$(mk_pmctl_brief "$work_dir")"
  cfg_file="$tmp_root/model-config.cfg"
  printf 'dispatch.default_model = config-default-model\n' > "$cfg_file"
  PM_DISPATCH_STATE_ROOT="$store" PM_DISPATCH_CONFIG_FILE="$cfg_file" \
    PATH="$fake_bin_dir:$PATH" \
    "$PMCTL" dispatch run --adapter codex --lifecycle foreground \\
    --cd "$work_dir" --brief-file "$brief_file" >/dev/null 2>&1 || true
  runs_file="$(find "$store" -name "runs.jsonl" -type f 2>/dev/null | head -1 || true)"
  model_found="$(jq -r '.model' "$runs_file" 2>/dev/null | tail -1 || true)"
  if [[ "$model_found" == "config-default-model" ]]; then
    pass "$name"
  else
    fail "$name" "expected model=config-default-model got '${model_found:-none}' (runs_file=${runs_file:-none})"
  fi
}

case_pmctl_dispatch_model_builtin_default() {
  # Verifies that when neither --model nor PM_CFG_DEFAULT_MODEL is set, the Run
  # row records the adapter's built-in default alias ("default" for codex),
  # extracted from the adapter footer's "model:" line.
  local name="pmctl-dispatch: no --model and no PM_CFG_DEFAULT_MODEL stores adapter built-in default"
  should_run "$name" || return 0
  local store fake_bin_dir brief_file work_dir runs_file model_found
  store="$tmp_root/model-builtin-store"
  fake_bin_dir="$tmp_root/model-builtin-bin"
  work_dir="$tmp_root/model-builtin-workdir"
  mkdir -p "$fake_bin_dir" "$work_dir"
  git -C "$work_dir" init -q
  install_fake_codex "$fake_bin_dir" 0
  brief_file="$(mk_pmctl_brief "$work_dir")"
  PM_DISPATCH_STATE_ROOT="$store" PATH="$fake_bin_dir:$PATH" \
    unset PM_CFG_DEFAULT_MODEL 2>/dev/null; \
    PM_DISPATCH_STATE_ROOT="$store" PM_CFG_DEFAULT_MODEL="" PATH="$fake_bin_dir:$PATH" \
    "$PMCTL" dispatch run --adapter codex --lifecycle foreground \\
    --cd "$work_dir" --brief-file "$brief_file" >/dev/null 2>&1 || true
  runs_file="$(find "$store" -name "runs.jsonl" -type f 2>/dev/null | head -1 || true)"
  model_found="$(jq -r '.model' "$runs_file" 2>/dev/null | tail -1 || true)"
  if [[ "$model_found" == "default" ]]; then
    pass "$name"
  else
    fail "$name" "expected 'default' (adapter built-in via footer) but got '${model_found}' (runs_file=${runs_file:-none})"
  fi
}

case_pmctl_dispatch_subdir_partition_key() {
  # Verifies that dispatching with --cd pointing to a repo subdirectory writes
  # the run row under the repo root's partition key, not the subdirectory's key.
  #
  # Steps:
  #   1. git init a fresh tmpdir (repo_root); create a subdir inside it.
  #   2. Compute the expected partition key for the repo root.
  #   3. Run codex-dispatch.sh --cd <repo_root>/subdir.
  #   4. Assert runs.jsonl appears under projects/<root_key>/, not subdir key.
  local name="pmctl-dispatch: subdirectory --cd resolves to repo root partition"
  should_run "$name" || return 0
  local store fake_bin_dir brief_file repo_root work_subdir root_key expected_partition git_top
  store="$tmp_root/subdir-store"
  fake_bin_dir="$tmp_root/subdir-bin"
  repo_root="$tmp_root/subdir-repo"
  work_subdir="$repo_root/sub/dir"
  mkdir -p "$fake_bin_dir" "$work_subdir"
  ( cd "$repo_root" && git init -q && git commit --allow-empty -m "init" -q ) 2>/dev/null || true
  git_top="$(git -C "$repo_root" rev-parse --show-toplevel 2>/dev/null || true)"
  root_key="$(printf '%s\n' "$git_top" | _portable_sha1 2>/dev/null || true)"
  install_fake_codex "$fake_bin_dir" 0
  brief_file="$(mk_pmctl_brief "$work_subdir")"
  PM_DISPATCH_STATE_ROOT="$store" PATH="$fake_bin_dir:$PATH" \
    "$PMCTL" dispatch run --adapter codex --lifecycle foreground \\
    --cd "$work_subdir" --brief-file "$brief_file" >/dev/null 2>&1 || true
  expected_partition="$store/projects/$root_key"
  if [[ -f "$expected_partition/runs.jsonl" ]]; then
    pass "$name"
  else
    local actual
    actual="$(find "$store/projects" -name "runs.jsonl" 2>/dev/null | tr '\n' ' ' || true)"
    fail "$name" "expected $expected_partition/runs.jsonl; found: ${actual:-none}"
  fi
}

case_sw_build_run_json_task_id_anchor() {
  # Verifies that prefixed keys like `parent_task_id:` are not mistaken for the
  # real `task_id:` line when extracting the task attribution for the run row.
  #
  # Steps:
  #   1. Write a brief with parent_task_id before task_id.
  #   2. Run fake-codex dispatch.
  #   3. Assert that runs.jsonl has the exact task_id line, not the parent_task_id or "UNKN-0".
  local name="sw_build_run_json: task_id extraction is anchored (ignores parent_task_id)"
  should_run "$name" || return 0
  local brief_file work_dir run_json task_id_found
  work_dir="$tmp_root/anchor-workdir"
  mkdir -p "$work_dir"
  brief_file="$tmp_root/anchor-brief.md"
  # parent_task_id: appears BEFORE task_id: - unanchored grep would pick the wrong value.
  printf 'parent_task_id: TASK-999\ntask_id: TASK-230\nDo nothing.\n' > "$brief_file"
  run_json="$(sw_build_run_json codex 0 ok model "$brief_file" "$work_dir" "")"
  task_id_found="$(jq -r '.task_id' <<< "$run_json" 2>/dev/null || true)"
  if [[ "$task_id_found" == "TASK-230" ]]; then
    pass "$name"
  else
    fail "$name" "expected task_id=TASK-230 but got task_id=${task_id_found:-none}"
  fi
}

case_sw_build_run_json_inline_brief_task_id() {
  # Verifies the backward-compatible builder still extracts task_id from inline brief text.
  local name="sw_build_run_json: inline brief task_id extraction"
  should_run "$name" || return 0
  local work_dir run_json task_id_found
  work_dir="$tmp_root/inline-brief-workdir"
  mkdir -p "$work_dir"
  run_json="$(sw_build_run_json codex 0 ok model "" "$work_dir" "" "task_id: TASK-230
Do nothing.")"
  task_id_found="$(jq -r '.task_id' <<< "$run_json" 2>/dev/null || true)"
  if [[ "$task_id_found" == "TASK-230" ]]; then
    pass "$name"
  else
    fail "$name" "expected task_id=TASK-230 but got '${task_id_found:-none}'"
  fi
}

case_pmctl_dispatch_failed_records_state() {
  # Verifies that when the dispatched codex process exits non-zero, the run row
  # records state:"failed" and the actual exit code, not "ok".
  #
  # Steps:
  #   1. Create a fake codex that exits with code 42.
  #   2. Write a brief file with a valid task_id.
  #   3. Run codex-dispatch.sh (it exits non-zero but the wrapper may still exit 0).
  #   4. Assert runs.jsonl row has state == "failed" and exit_code == 42.
  local name="pmctl-dispatch: failed dispatch records state:failed and exit code"
  should_run "$name" || return 0
  local store fake_bin_dir brief_file work_dir runs_file state_found exit_found
  store="$tmp_root/failed-dispatch-store"
  fake_bin_dir="$tmp_root/failed-dispatch-bin"
  work_dir="$tmp_root/failed-dispatch-workdir"
  mkdir -p "$fake_bin_dir" "$work_dir"
  git -C "$work_dir" init -q
  install_fake_codex "$fake_bin_dir" 42
  brief_file="$(mk_pmctl_brief "$work_dir")"
  PM_DISPATCH_STATE_ROOT="$store" PATH="$fake_bin_dir:$PATH" \
    "$PMCTL" dispatch run --adapter codex --lifecycle foreground \\
    --cd "$work_dir" --brief-file "$brief_file" >/dev/null 2>&1 || true
  runs_file="$(find "$store" -name "runs.jsonl" -type f 2>/dev/null | head -1 || true)"
  state_found=""
  exit_found=""
  if [[ -n "$runs_file" ]]; then
    state_found="$(jq -r '.state' "$runs_file" 2>/dev/null | tail -1 || true)"
    exit_found="$(jq -r '.exit_code' "$runs_file" 2>/dev/null | tail -1 || true)"
  fi
  if [[ "$state_found" == "failed" && "$exit_found" == "42" ]]; then
    pass "$name"
  else
    fail "$name" "expected state=failed exit_code=42 but got state=${state_found:-none} exit_code=${exit_found:-none} (file=${runs_file:-none})"
  fi
}

case_pmctl_dispatch_pre_event_before_adapter() {
  local name="pmctl-dispatch: run.pending/run.dispatched Events emitted before adapter invocation"
  should_run "$name" || return 0
  local store fake_bin_dir brief_file work_dir probe_file events_file first_two_kinds
  store="$tmp_root/pre-event-store"
  fake_bin_dir="$tmp_root/pre-event-bin"
  work_dir="$tmp_root/pre-event-workdir"
  probe_file="$tmp_root/pre-event-seen"
  mkdir -p "$fake_bin_dir" "$work_dir"
  git -C "$work_dir" init -q
  install_fake_codex "$fake_bin_dir" 0 "$probe_file"
  brief_file="$(mk_pmctl_brief "$work_dir")"
  PM_DISPATCH_STATE_ROOT="$store" PATH="$fake_bin_dir:$PATH" \
    "$PMCTL" dispatch run --adapter codex --lifecycle foreground \\
    --cd "$work_dir" --brief-file "$brief_file" >/dev/null 2>&1 || true
  events_file="$(find "$store" -name events.jsonl -type f 2>/dev/null | head -1 || true)"
  first_two_kinds=""
  [[ -n "$events_file" ]] && first_two_kinds="$(jq -r '.kind' "$events_file" 2>/dev/null | head -2 | paste -sd, - || true)"
  if [[ -s "$probe_file" && "$first_two_kinds" == "run.pending,run.dispatched" ]]; then
    pass "$name"
  else
    fail "$name" "probe=$([[ -s "$probe_file" ]] && echo seen || echo missing) first_two_kinds=${first_two_kinds:-none}"
  fi
}

case_pmctl_dispatch_completed_event() {
  local name="pmctl-dispatch: run.completed Event in events.jsonl after successful dispatch"
  should_run "$name" || return 0
  local store fake_bin_dir brief_file work_dir events_file kinds run_ids
  store="$tmp_root/completed-event-store"
  fake_bin_dir="$tmp_root/completed-event-bin"
  work_dir="$tmp_root/completed-event-workdir"
  mkdir -p "$fake_bin_dir" "$work_dir"
  git -C "$work_dir" init -q
  install_fake_codex "$fake_bin_dir" 0
  brief_file="$(mk_pmctl_brief "$work_dir")"
  PM_DISPATCH_STATE_ROOT="$store" PATH="$fake_bin_dir:$PATH" \
    "$PMCTL" dispatch run --adapter codex --lifecycle foreground \\
    --cd "$work_dir" --brief-file "$brief_file" >/dev/null 2>&1 || true
  events_file="$(find "$store" -name events.jsonl -type f 2>/dev/null | head -1 || true)"
  kinds=""
  run_ids=""
  if [[ -n "$events_file" ]]; then
    kinds="$(jq -r '.kind' "$events_file" 2>/dev/null | paste -sd, - || true)"
    run_ids="$(jq -r '.payload.run_id' "$events_file" 2>/dev/null | sort -u | wc -l | tr -d ' ')"
  fi
  if [[ "$kinds" == "run.pending,run.dispatched,run.verifying,run.completed" && "$run_ids" == "1" ]]; then
    pass "$name"
  else
    fail "$name" "kinds=${kinds:-none} unique_run_ids=${run_ids:-none}"
  fi
}

case_pmctl_dispatch_full_fsm_sequence() {
  local name="pmctl-dispatch: full Run FSM event sequence after successful dispatch"
  should_run "$name" || return 0
  local store fake_bin_dir brief_file work_dir events_file runs_file kinds states
  store="$tmp_root/full-fsm-store"
  fake_bin_dir="$tmp_root/full-fsm-bin"
  work_dir="$tmp_root/full-fsm-workdir"
  mkdir -p "$fake_bin_dir" "$work_dir"
  git -C "$work_dir" init -q
  install_fake_codex "$fake_bin_dir" 0
  brief_file="$(mk_pmctl_brief "$work_dir")"
  PM_DISPATCH_STATE_ROOT="$store" PATH="$fake_bin_dir:$PATH" \
    "$PMCTL" dispatch run --adapter codex --lifecycle foreground \\
    --cd "$work_dir" --brief-file "$brief_file" >/dev/null 2>&1 || true
  events_file="$(find "$store" -name events.jsonl -type f 2>/dev/null | head -1 || true)"
  runs_file="$(find "$store" -name runs.jsonl -type f 2>/dev/null | head -1 || true)"
  kinds=""
  states=""
  [[ -n "$events_file" ]] && kinds="$(jq -r '.kind' "$events_file" 2>/dev/null | paste -sd, - || true)"
  [[ -n "$runs_file" ]] && states="$(jq -r '.state' "$runs_file" 2>/dev/null | paste -sd, - || true)"
  if [[ "$kinds" == "run.pending,run.dispatched,run.verifying,run.completed" && \
        "$states" == "pending,dispatched,verifying,ok" ]]; then
    pass "$name"
  else
    fail "$name" "kinds=${kinds:-none} states=${states:-none}"
  fi
}

case_pmctl_dispatch_terminal_run_event_invariant() {
  local name="pmctl-dispatch: every terminal Run has exactly one matching terminal Event"
  should_run "$name" || return 0
  local store fake_bin_dir brief_file work_dir runs_file events_file terminal_count violations
  store="$tmp_root/terminal-invariant-store"
  fake_bin_dir="$tmp_root/terminal-invariant-bin"
  work_dir="$tmp_root/terminal-invariant-workdir"
  mkdir -p "$fake_bin_dir" "$work_dir"
  git -C "$work_dir" init -q
  install_fake_codex "$fake_bin_dir" 0
  brief_file="$(mk_pmctl_brief "$work_dir")"
  PM_DISPATCH_STATE_ROOT="$store" PATH="$fake_bin_dir:$PATH" \
    "$PMCTL" dispatch run --adapter codex --lifecycle foreground \\
    --cd "$work_dir" --brief-file "$brief_file" >/dev/null 2>&1 || true
  runs_file="$(find "$store" -name runs.jsonl -type f 2>/dev/null | head -1 || true)"
  events_file="$(find "$store" -name events.jsonl -type f 2>/dev/null | head -1 || true)"
  terminal_count="0"
  violations=""
  if [[ -n "$runs_file" && -n "$events_file" ]]; then
    terminal_count="$(jq -s '[.[] | select(.state == "ok" or .state == "partial" or .state == "failed")] | length' "$runs_file" 2>/dev/null || true)"
    violations="$(jq -nr --slurpfile runs "$runs_file" --slurpfile events "$events_file" '
      def terminal_run: .state == "ok" or .state == "partial" or .state == "failed";
      def terminal_event: .kind == "run.completed" or .kind == "run.failed";
      [
        $runs[] | select(terminal_run) as $run |
        {
          run_id: $run.id,
          run_op: ($run.operation_id // ""),
          events: [$events[] | select(terminal_event and .subject_id == $run.id)]
        } |
        select((.events | length) != 1 or .run_op == "" or (.events[0].operation_id // "") != .run_op)
      ] |
      map("\(.run_id):events=\(.events | length):run_op=\(.run_op):event_op=\(.events[0].operation_id // "")") |
      join(";")
    ' 2>/dev/null || true)"
  fi
  if [[ "$terminal_count" == "1" && -z "$violations" ]]; then
    pass "$name"
  else
    fail "$name" "terminal_count=${terminal_count:-none} violations=${violations:-missing-files}"
  fi
}

case_pmctl_dispatch_failed_event() {
  local name="pmctl-dispatch: run.failed Event in events.jsonl after failed adapter exit"
  should_run "$name" || return 0
  local store fake_bin_dir brief_file work_dir events_file failed_exit
  store="$tmp_root/failed-event-store"
  fake_bin_dir="$tmp_root/failed-event-bin"
  work_dir="$tmp_root/failed-event-workdir"
  mkdir -p "$fake_bin_dir" "$work_dir"
  git -C "$work_dir" init -q
  install_fake_codex "$fake_bin_dir" 42
  brief_file="$(mk_pmctl_brief "$work_dir")"
  PM_DISPATCH_STATE_ROOT="$store" PATH="$fake_bin_dir:$PATH" \
    "$PMCTL" dispatch run --adapter codex --lifecycle foreground \\
    --cd "$work_dir" --brief-file "$brief_file" >/dev/null 2>&1 || true
  events_file="$(find "$store" -name events.jsonl -type f 2>/dev/null | head -1 || true)"
  failed_exit=""
  [[ -n "$events_file" ]] && failed_exit="$(jq -r 'select(.kind=="run.failed") | .payload.exit_code' "$events_file" 2>/dev/null || true)"
  if [[ "$failed_exit" == "42" ]]; then
    pass "$name"
  else
    fail "$name" "failed_exit=${failed_exit:-none}"
  fi
}

case_pmctl_dispatch_pre_event_fail_blocks_adapter() {
  # Verifies that a run.pending Event write failure causes pmctl to return
  # non-zero and NOT invoke the adapter (adapter binary not called).
  #
  # Strategy: place a directory at events.jsonl before dispatch so the
  # run.pending append returns non-zero and pmctl returns early. A probing codex
  # writes a probe file on any invocation; its absence proves the adapter was not called.
  local name="pmctl-dispatch: run.pending Event write failure blocks adapter invocation"
  should_run "$name" || return 0
  local store fake_bin_dir brief_file work_dir probe_file proj_dir rc=0
  store="$tmp_root/pre-event-fail-store"
  fake_bin_dir="$tmp_root/pre-event-fail-bin"
  work_dir="$tmp_root/pre-event-fail-workdir"
  probe_file="$tmp_root/pre-event-fail-probe"
  mkdir -p "$fake_bin_dir" "$work_dir"
  git -C "$work_dir" init -q
  install_probing_codex "$fake_bin_dir" 0 "$probe_file"
  brief_file="$(mk_pmctl_brief "$work_dir")"
  PM_DISPATCH_STATE_ROOT="$store" _SW_REPO_ROOT="$work_dir" state_store_init
  proj_dir="$(PM_DISPATCH_STATE_ROOT="$store" _SW_REPO_ROOT="$work_dir" _sw_project_dir)"
  mkdir "$proj_dir/events.jsonl"
  PM_DISPATCH_STATE_ROOT="$store" PATH="$fake_bin_dir:$PATH" \
    "$PMCTL" dispatch run --adapter codex --lifecycle foreground \\
    --cd "$work_dir" --brief-file "$brief_file" >/dev/null 2>&1 || rc=$?
  if [[ "$rc" -ne 0 && ! -f "$probe_file" ]]; then
    pass "$name"
  else
    fail "$name" "rc=$rc probe=$([[ -f "$probe_file" ]] && echo invoked || echo not-invoked)"
  fi
}

case_pmctl_dispatch_terminal_event_append_fail() {
  # Verifies that when events_append fails for a transition after runs_append
  # succeeds, pmctl_dispatch_write_transition propagates non-zero.
  #
  # Strategy: use a poison codex that chmod 000s events.jsonl after the pre-adapter
  # transitions have been written, so the post-adapter Run append still succeeds
  # but the subsequent Event append fails.
  local name="pmctl-dispatch: write_transition returns non-zero when events_append fails after runs_append succeeds"
  should_run "$name" || return 0
  local store fake_bin_dir brief_file work_dir runs_file events_files rc=0
  store="$tmp_root/terminal-event-fail-store"
  fake_bin_dir="$tmp_root/terminal-event-fail-bin"
  work_dir="$tmp_root/terminal-event-fail-workdir"
  mkdir -p "$fake_bin_dir" "$work_dir"
  git -C "$work_dir" init -q
  install_poison_codex "$fake_bin_dir" 0
  brief_file="$(mk_pmctl_brief "$work_dir")"
  rc=0
  PM_DISPATCH_STATE_ROOT="$store" PATH="$fake_bin_dir:$PATH" \
    "$PMCTL" dispatch run --adapter codex --lifecycle foreground \\
    --cd "$work_dir" --brief-file "$brief_file" >/dev/null 2>&1 || rc=$?
  # Restore events.jsonl permissions so the temp dir can be cleaned up.
  find "$store" -name events.jsonl | xargs chmod 600 2>/dev/null || true
  runs_file="$(find "$store" -name runs.jsonl -type f 2>/dev/null | head -1 || true)"
  if [[ "$rc" -ne 0 && -s "$runs_file" ]]; then
    pass "$name"
  else
    fail "$name" "rc=$rc runs_file=${runs_file:-none}"
  fi
}

if ! type -t pmctl_dispatch_write_transition >/dev/null 2>&1; then
  # shellcheck source=scripts/lib/pmctl-dispatch.sh
  . "$SCRIPT_DIR/lib/pmctl-dispatch.sh"
fi

case_fsm_valid_pending_to_dispatched() {
  # Verifies that pmctl_dispatch_write_transition accepts a valid FSM edge.
  #
  # Steps:
  #   1. Write a pending transition (from_state="").
  #   2. Write a dispatched transition (from_state=pending).
  #   3. Assert both calls return 0.
  local name="FSM: valid transition pending->dispatched succeeds"
  should_run "$name" || return 0
  local store work rc=0
  store="$tmp_root/fsm-valid-store"
  work="$tmp_root/fsm-valid-work"
  mkdir -p "$work"; git -C "$work" init -q
  PM_DISPATCH_STATE_ROOT="$store" \
    pmctl_dispatch_write_transition "$REPO_ROOT" "$work" "codex" \
    "run-20260101T000000Z-aaaaaa" "pending" 0 "default" "/tmp/brief.md" "" "2026-01-01T00:00:00Z" "" \
    >/dev/null 2>&1 || rc=$?
  [[ "$rc" -ne 0 ]] && { fail "$name" "pending write rc=$rc"; return; }
  PM_DISPATCH_STATE_ROOT="$store" \
    pmctl_dispatch_write_transition "$REPO_ROOT" "$work" "codex" \
    "run-20260101T000000Z-aaaaaa" "dispatched" 0 "default" "/tmp/brief.md" "" "2026-01-01T00:00:00Z" "pending" \
    >/dev/null 2>&1 || rc=$?
  if [[ "$rc" -eq 0 ]]; then pass "$name"; else fail "$name" "dispatched rc=$rc"; fi
}

case_fsm_valid_verifying_to_ok() {
  # Verifies that the terminal ok edge (verifying->ok) is accepted by the FSM guard.
  #
  # Steps:
  #   1. Write pending, dispatched, verifying transitions to establish FSM state.
  #   2. Write ok transition (from_state=verifying).
  #   3. Assert all calls return 0.
  local name="FSM: valid transition verifying->ok succeeds"
  should_run "$name" || return 0
  local store work rc=0
  store="$tmp_root/fsm-ok-store"
  work="$tmp_root/fsm-ok-work"
  mkdir -p "$work"; git -C "$work" init -q
  for _t in "pending::" "dispatched::pending" "verifying::dispatched" "ok::verifying"; do
    _state="${_t%%::*}"; _from="${_t##*::}"
    PM_DISPATCH_STATE_ROOT="$store" \
      pmctl_dispatch_write_transition "$REPO_ROOT" "$work" "codex" \
      "run-20260101T000000Z-dddddd" "$_state" 0 "default" "/tmp/brief.md" "" "2026-01-01T00:00:00Z" "$_from" \
      >/dev/null 2>&1 || rc=$?
    [[ "$rc" -ne 0 ]] && { fail "$name" "transition $_from->$_state rc=$rc"; return; }
  done
  pass "$name"
}

case_fsm_valid_verifying_to_partial() {
  # Verifies that the partial terminal edge (verifying->partial) is accepted.
  #
  # Steps:
  #   1. Write pending, dispatched, verifying transitions.
  #   2. Write partial transition (from_state=verifying).
  #   3. Assert all calls return 0.
  local name="FSM: valid transition verifying->partial succeeds"
  should_run "$name" || return 0
  local store work rc=0
  store="$tmp_root/fsm-partial-store"
  work="$tmp_root/fsm-partial-work"
  mkdir -p "$work"; git -C "$work" init -q
  PM_DISPATCH_STATE_ROOT="$store" \
    pmctl_dispatch_write_transition "$REPO_ROOT" "$work" "codex" \
    "run-20260101T000000Z-eeeeee" "pending" 0 "default" "/tmp/brief.md" "" "2026-01-01T00:00:00Z" "" \
    >/dev/null 2>&1 || rc=$?
  PM_DISPATCH_STATE_ROOT="$store" \
    pmctl_dispatch_write_transition "$REPO_ROOT" "$work" "codex" \
    "run-20260101T000000Z-eeeeee" "dispatched" 0 "default" "/tmp/brief.md" "" "2026-01-01T00:00:00Z" "pending" \
    >/dev/null 2>&1 || rc=$?
  PM_DISPATCH_STATE_ROOT="$store" \
    pmctl_dispatch_write_transition "$REPO_ROOT" "$work" "codex" \
    "run-20260101T000000Z-eeeeee" "verifying" 0 "default" "/tmp/brief.md" "" "2026-01-01T00:00:00Z" "dispatched" \
    >/dev/null 2>&1 || rc=$?
  PM_DISPATCH_STATE_ROOT="$store" \
    pmctl_dispatch_write_transition "$REPO_ROOT" "$work" "codex" \
    "run-20260101T000000Z-eeeeee" "partial" 1 "default" "/tmp/brief.md" "" "2026-01-01T00:00:00Z" "verifying" \
    >/dev/null 2>&1 || rc=$?
  if [[ "$rc" -eq 0 ]]; then pass "$name"; else fail "$name" "rc=$rc"; fi
}

case_fsm_valid_verifying_to_failed() {
  # Verifies that the failed terminal edge (verifying->failed) is accepted.
  #
  # Steps:
  #   1. Write pending, dispatched, verifying transitions.
  #   2. Write failed transition (from_state=verifying).
  #   3. Assert all calls return 0.
  local name="FSM: valid transition verifying->failed succeeds"
  should_run "$name" || return 0
  local store work rc=0
  store="$tmp_root/fsm-failed-store"
  work="$tmp_root/fsm-failed-work"
  mkdir -p "$work"; git -C "$work" init -q
  PM_DISPATCH_STATE_ROOT="$store" \
    pmctl_dispatch_write_transition "$REPO_ROOT" "$work" "codex" \
    "run-20260101T000000Z-ffffff" "pending" 0 "default" "/tmp/brief.md" "" "2026-01-01T00:00:00Z" "" \
    >/dev/null 2>&1 || rc=$?
  PM_DISPATCH_STATE_ROOT="$store" \
    pmctl_dispatch_write_transition "$REPO_ROOT" "$work" "codex" \
    "run-20260101T000000Z-ffffff" "dispatched" 0 "default" "/tmp/brief.md" "" "2026-01-01T00:00:00Z" "pending" \
    >/dev/null 2>&1 || rc=$?
  PM_DISPATCH_STATE_ROOT="$store" \
    pmctl_dispatch_write_transition "$REPO_ROOT" "$work" "codex" \
    "run-20260101T000000Z-ffffff" "verifying" 0 "default" "/tmp/brief.md" "" "2026-01-01T00:00:00Z" "dispatched" \
    >/dev/null 2>&1 || rc=$?
  PM_DISPATCH_STATE_ROOT="$store" \
    pmctl_dispatch_write_transition "$REPO_ROOT" "$work" "codex" \
    "run-20260101T000000Z-ffffff" "failed" 1 "default" "/tmp/brief.md" "" "2026-01-01T00:00:00Z" "verifying" \
    >/dev/null 2>&1 || rc=$?
  if [[ "$rc" -eq 0 ]]; then pass "$name"; else fail "$name" "rc=$rc"; fi
}

case_fsm_invalid_ok_to_dispatched() {
  # Verifies that pmctl_dispatch_write_transition rejects a backward FSM edge.
  #
  # Steps:
  #   1. Attempt dispatched transition from_state=ok (terminal state has no outgoing edges).
  #   2. Assert non-zero exit and stderr contains "invalid transition".
  local name="FSM: invalid transition ok->dispatched returns non-zero"
  should_run "$name" || return 0
  local store work rc=0 stderr_out
  store="$tmp_root/fsm-ok-dispatched-store"
  work="$tmp_root/fsm-ok-dispatched-work"
  mkdir -p "$work"; git -C "$work" init -q
  stderr_out="$(PM_DISPATCH_STATE_ROOT="$store" \
    pmctl_dispatch_write_transition "$REPO_ROOT" "$work" "codex" \
    "run-20260101T000000Z-bbbbbb" "dispatched" 0 "default" "/tmp/brief.md" "" "2026-01-01T00:00:00Z" "ok" \
    2>&1 >/dev/null)" || rc=$?
  if [[ "$rc" -ne 0 ]] && printf '%s' "$stderr_out" | grep -q "invalid transition"; then
    pass "$name"
  else
    fail "$name" "rc=$rc stderr=$stderr_out"
  fi
}

case_fsm_invalid_verifying_to_pending() {
  # Verifies that pmctl_dispatch_write_transition rejects a backward FSM edge.
  #
  # Steps:
  #   1. Attempt pending transition from_state=verifying (backward jump).
  #   2. Assert non-zero exit and stderr contains "invalid transition".
  local name="FSM: invalid transition verifying->pending returns non-zero"
  should_run "$name" || return 0
  local store work rc=0 stderr_out
  store="$tmp_root/fsm-vp-store"
  work="$tmp_root/fsm-vp-work"
  mkdir -p "$work"; git -C "$work" init -q
  stderr_out="$(PM_DISPATCH_STATE_ROOT="$store" \
    pmctl_dispatch_write_transition "$REPO_ROOT" "$work" "codex" \
    "run-20260101T000000Z-cccccc" "pending" 0 "default" "/tmp/brief.md" "" "2026-01-01T00:00:00Z" "verifying" \
    2>&1 >/dev/null)" || rc=$?
  if [[ "$rc" -ne 0 ]] && printf '%s' "$stderr_out" | grep -q "invalid transition"; then
    pass "$name"
  else
    fail "$name" "rc=$rc stderr=$stderr_out"
  fi
}

case_project_key_shasum_fallback() {
  local name="project_key: sha1sum missing but shasum available produces hash (not global)"
  should_run "$name" || return 0

  local tmp_git fake_bin result
  tmp_git="$(mktemp -d)"
  fake_bin="$(mktemp -d)"
  git -C "$tmp_git" init -q

  # shasum shim that ignores -a 1 args and delegates stdin to openssl
  printf '#!/bin/sh\nopenssl dgst -sha1 < /dev/stdin | awk '"'"'{print $NF}'"'"'\n' > "$fake_bin/shasum"
  chmod +x "$fake_bin/shasum"

  # FAKE_SHA1SUM_MISSING=1 blocks the direct sha1sum branch in _portable_sha1;
  # the shasum shim in fake_bin provides a working fallback via openssl internally.
  result="$(
    FAKE_SHA1SUM_MISSING=1 PATH="$fake_bin:$PATH" _SW_REPO_ROOT="$tmp_git" \
      bash -c "source '$REPO_ROOT/scripts/lib/state-writer.sh' 2>/dev/null
               _sw_project_key"
  )" || true
  rm -rf "$tmp_git" "$fake_bin"

  # Must be a 40-char hex string, NOT "global" - proves shasum fallback was used
  if [[ "$result" =~ ^[0-9a-f]{40}$ ]]; then
    pass "$name"
  else
    fail "$name" "expected 40-char hex via shasum fallback, got '${result:-empty}'"
  fi
}

case_project_key_no_sha1sum() {
  local name="project_key: no sha1sum or shasum falls back to global"
  # Create a minimal repo so _sw_project_key has a git root to hash.
  local tmp_root
  tmp_root="$(mktemp -d)"
  git -C "$tmp_root" init -q
  # Force both sha1sum and shasum unavailable via FAKE_SHA1_MISSING=1.
  # Source state-writer.sh (which sources portable.sh) and call _sw_project_key.
  local result
  result="$(
    FAKE_SHA1_MISSING=1 _SW_REPO_ROOT="$tmp_root" \
      bash -c "source '$REPO_ROOT/scripts/lib/state-writer.sh' 2>/dev/null; _sw_project_key"
  )" || true
  rm -rf "$tmp_root"
  if [[ "$result" == "global" ]]; then
    pass "$name"
  else
    fail "$name" "expected 'global' but got '${result:-empty}'"
  fi
}

case_project_key_windows_spellings_same_partition() {
  local name="project_key: equivalent Windows path spellings collapse to one partition"
  should_run "$name" || return 0

  local stub key_cslash key_drive_up key_drive_lo key_posix1 key_posix2
  # cygpath shim mimicking `cygpath -m` so the MSYS dialect branch of
  # _portable_canonical_path runs on this POSIX host. Non-git repo roots make
  # _sw_project_key fall back to hashing the canonicalized path verbatim, which
  # isolates the canonicalization behavior from git resolution.
  stub="$(mktemp -d)"
  cat > "$stub/cygpath" <<'CYG'
#!/usr/bin/env bash
p="${@: -1}"
case "$p" in
  /[A-Za-z]/*) printf '%s:/%s\n' "${p:1:1}" "${p:3}" ;;
  [A-Za-z]:/*) printf '%s\n' "$p" ;;
  *)           printf '%s\n' "$p" ;;
esac
CYG
  chmod +x "$stub/cygpath"

  key_cslash="$(PATH="$stub:$PATH" _SW_REPO_ROOT="/c/proj/app" _sw_project_key)"
  key_drive_up="$(PATH="$stub:$PATH" _SW_REPO_ROOT="C:/proj/app" _sw_project_key)"
  key_drive_lo="$(PATH="$stub:$PATH" _SW_REPO_ROOT="c:/proj/app" _sw_project_key)"
  # POSIX stability: the same POSIX path hashes identically with or without
  # cygpath present, so existing partition keys are unaffected.
  key_posix1="$(_SW_REPO_ROOT="/home/u/proj" _sw_project_key)"
  key_posix2="$(PATH="$stub:$PATH" _SW_REPO_ROOT="/home/u/proj" _sw_project_key)"
  rm -rf "$stub"

  if [[ "$key_cslash" =~ ^[0-9a-f]{40}$ \
        && "$key_cslash" == "$key_drive_up" \
        && "$key_cslash" == "$key_drive_lo" \
        && "$key_posix1" =~ ^[0-9a-f]{40}$ \
        && "$key_posix1" == "$key_posix2" \
        && "$key_cslash" != "$key_posix1" ]]; then
    pass "$name"
  else
    fail "$name" "cslash=$key_cslash up=$key_drive_up lo=$key_drive_lo posix1=$key_posix1 posix2=$key_posix2"
  fi
}

case_state_store_init_mkdir_fail_loud() {
  # Verifies that layout mkdir failure propagates as non-zero rather than being silently swallowed.
  #
  # Steps:
  #   1. Create store root with a pre-existing projects/ dir; chmod it to 500 (no write).
  #   2. Call state_store_init; assert non-zero exit and stderr contains "mkdir failed".
  local name="state_store_init: layout mkdir failure propagates loud"
  should_run "$name" || return 0
  local store projects_dir rc=0 stderr_out
  store="$tmp_root/mkdir-fail-loud"
  projects_dir="$store/projects"
  mkdir -p "$projects_dir"
  chmod 500 "$projects_dir"
  stderr_out="$(PM_DISPATCH_STATE_ROOT="$store" state_store_init 2>&1 >/dev/null)" || rc=$?
  chmod 700 "$projects_dir"
  if [[ "$rc" -ne 0 ]] && printf '%s' "$stderr_out" | grep -q "mkdir failed"; then
    pass "$name"
  else
    fail "$name" "rc=$rc stderr=${stderr_out:-empty}"
  fi
}

case_state_store_init_global_key_refused() {
  # Verifies that state_store_init refuses the global partition for load-bearing writes.
  # _sw_project_key returns "global" when run from a non-git CWD with no _SW_REPO_ROOT.
  #
  # Steps:
  #   1. Create a non-git tmpdir; run state_store_init from that CWD (subshell).
  #   2. Assert non-zero exit and stderr mentions partition.
  local name="state_store_init: global partition refused without _SW_ALLOW_GLOBAL_PARTITION"
  should_run "$name" || return 0
  local store non_git rc=0 stderr_out
  store="$tmp_root/global-refused"
  non_git="$tmp_root/not-a-git-repo"
  mkdir -p "$non_git"
  # Run from non-git CWD without _SW_REPO_ROOT so _sw_project_key returns "global".
  stderr_out="$( (
    cd "$non_git"
    unset _SW_REPO_ROOT 2>/dev/null || true
    PM_DISPATCH_STATE_ROOT="$store" state_store_init 2>&1 >/dev/null
  ) )" || rc=$?
  if [[ "$rc" -ne 0 ]] && printf '%s' "$stderr_out" | grep -q "partition"; then
    pass "$name"
  else
    fail "$name" "rc=$rc stderr=${stderr_out:-empty}"
  fi
}

case_state_store_init_global_key_allowed_explicit() {
  # Verifies that _SW_ALLOW_GLOBAL_PARTITION=1 bypasses the global-partition guard.
  #
  # Steps:
  #   1. Create a non-git tmpdir; run state_store_init from that CWD with the override.
  #   2. Assert exit 0 and the global partition dir was created.
  local name="state_store_init: _SW_ALLOW_GLOBAL_PARTITION=1 allows global partition"
  should_run "$name" || return 0
  local store non_git rc=0
  store="$tmp_root/global-allowed"
  non_git="$tmp_root/not-a-git-repo-allowed"
  mkdir -p "$non_git"
  (
    cd "$non_git"
    unset _SW_REPO_ROOT 2>/dev/null || true
    export _SW_ALLOW_GLOBAL_PARTITION=1
    PM_DISPATCH_STATE_ROOT="$store" state_store_init >/dev/null 2>&1
  ) || rc=$?
  if [[ "$rc" -eq 0 && -d "$store/projects/global/tasks" ]]; then
    pass "$name"
  else
    fail "$name" "rc=$rc global_tasks_exists=$([[ -d "$store/projects/global/tasks" ]] && echo yes || echo no)"
  fi
}

case_state_store_init_writes_repo_json() {
  # Verifies that state_store_init writes repo.json on first use with required fields.
  #
  # Steps:
  #   1. git init a fresh tmpdir; call state_store_init with _SW_REPO_ROOT set.
  #   2. Find repo.json under the project partition.
  #   3. Assert it contains repo_path, repo_name, and first_seen_ts.
  local name="state_store_init: writes repo.json on first use"
  should_run "$name" || return 0
  local store git_repo rc=0 repo_json repo_path repo_name first_seen_ts
  store="$tmp_root/repo-json-write"
  git_repo="$tmp_root/repo-json-repo"
  mkdir -p "$git_repo"
  git -C "$git_repo" init -q
  PM_DISPATCH_STATE_ROOT="$store" _SW_REPO_ROOT="$git_repo" state_store_init >/dev/null 2>&1 || rc=$?
  repo_json="$(find "$store" -name "repo.json" -type f 2>/dev/null | head -1 || true)"
  repo_path="$(jq -r '.repo_path' "$repo_json" 2>/dev/null || true)"
  repo_name="$(jq -r '.repo_name' "$repo_json" 2>/dev/null || true)"
  first_seen_ts="$(jq -r '.first_seen_ts' "$repo_json" 2>/dev/null || true)"
  if [[ "$rc" -eq 0 && -n "$repo_json" && -n "$repo_path" && \
        "$repo_name" == "$(basename "$git_repo")" && -n "$first_seen_ts" ]]; then
    pass "$name"
  else
    fail "$name" "rc=$rc repo_json=${repo_json:-none} repo_name=${repo_name:-empty} first_seen_ts=${first_seen_ts:-empty}"
  fi
}

case_state_store_init_repo_json_idempotent() {
  # Verifies that a second call to state_store_init does not overwrite an existing repo.json.
  #
  # Steps:
  #   1. Call state_store_init once; record the first_seen_ts from repo.json.
  #   2. Call state_store_init a second time.
  #   3. Assert first_seen_ts is unchanged (file not overwritten).
  local name="state_store_init: repo.json not overwritten on subsequent calls"
  should_run "$name" || return 0
  local store git_repo ts_first ts_second repo_json
  store="$tmp_root/repo-json-idem"
  git_repo="$tmp_root/repo-json-idem-repo"
  mkdir -p "$git_repo"
  git -C "$git_repo" init -q
  _SW_CREATED_TS_OVERRIDE="2026-01-01T00:00:00Z" \
    PM_DISPATCH_STATE_ROOT="$store" _SW_REPO_ROOT="$git_repo" \
    state_store_init >/dev/null 2>&1 || true
  repo_json="$(find "$store" -name "repo.json" -type f 2>/dev/null | head -1 || true)"
  ts_first="$(jq -r '.first_seen_ts' "$repo_json" 2>/dev/null || true)"
  _SW_CREATED_TS_OVERRIDE="2026-06-01T00:00:00Z" \
    PM_DISPATCH_STATE_ROOT="$store" _SW_REPO_ROOT="$git_repo" \
    state_store_init >/dev/null 2>&1 || true
  ts_second="$(jq -r '.first_seen_ts' "$repo_json" 2>/dev/null || true)"
  if [[ "$ts_first" == "2026-01-01T00:00:00Z" && "$ts_second" == "2026-01-01T00:00:00Z" ]]; then
    pass "$name"
  else
    fail "$name" "ts_first=$ts_first ts_second=$ts_second"
  fi
}

case_store_root_override
case_store_root_xdg
case_store_root_default
case_state_store_init_structure
case_state_store_init_store_root_mode
case_state_store_init_symlink_leaf_rejected
case_state_store_init_symlink_leaf_escape_hatch
case_state_store_init_world_writable_rejected_when_chmod_cannot_secure
case_state_store_init_world_writable_escape_hatch
case_state_store_init_group_only_writable_rejected
case_state_store_init_world_only_writable_rejected
case_state_store_init_non_owner_rejected_when_simulatable
case_state_store_init_version1_noop
case_state_store_init_version2_fails
case_state_store_init_version2_does_not_mutate_mode
case_runs_append_fails_on_version2
case_runs_append_valid_jsonl
case_runs_append_appends
case_events_append
case_runs_append_rejects_newline
case_runs_append_rejects_nul
case_events_append_rejects_newline
case_events_append_rejects_nul
case_events_append_rejects_run_event_without_payload
case_events_append_rejects_run_event_wrong_payload_type
case_runs_append_compacts_json
case_runs_append_rejects_malformed_json
case_runs_append_rejects_schema_invalid
case_task_upsert
case_task_upsert_invalid_id
case_task_upsert_version2_blocked
case_decision_upsert
case_decision_upsert_invalid_id
case_decision_upsert_version2_blocked
case_runs_append_read_only_fails_loudly
case_codex_dispatch_state_store_self_contained
case_pmctl_dispatch_creates_run_row
case_pmctl_dispatch_correct_partition
case_pmctl_dispatch_run_json_valid
case_pmctl_dispatch_model_explicit
case_pmctl_dispatch_model_config_default
case_pmctl_dispatch_model_builtin_default
case_pmctl_dispatch_subdir_partition_key
case_sw_build_run_json_task_id_anchor
case_sw_build_run_json_inline_brief_task_id
case_pmctl_dispatch_failed_records_state
case_pmctl_dispatch_pre_event_before_adapter
case_pmctl_dispatch_completed_event
case_pmctl_dispatch_full_fsm_sequence
case_pmctl_dispatch_terminal_run_event_invariant
case_pmctl_dispatch_failed_event
case_pmctl_dispatch_pre_event_fail_blocks_adapter
case_pmctl_dispatch_terminal_event_append_fail
case_fsm_valid_pending_to_dispatched
case_fsm_valid_verifying_to_ok
case_fsm_valid_verifying_to_partial
case_fsm_valid_verifying_to_failed
case_fsm_invalid_ok_to_dispatched
case_fsm_invalid_verifying_to_pending
case_project_key_shasum_fallback
case_project_key_no_sha1sum
case_project_key_windows_spellings_same_partition
case_state_store_init_mkdir_fail_loud
case_state_store_init_global_key_refused
case_state_store_init_global_key_allowed_explicit
case_state_store_init_writes_repo_json
case_state_store_init_repo_json_idempotent

th_summary
