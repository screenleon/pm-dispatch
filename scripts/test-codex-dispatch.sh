#!/usr/bin/env bash
# Regression tests for codex-dispatch.sh self-snapshot mechanism.
#
# Threat model: dispatching Codex against pm-dispatch can rewrite
# codex-dispatch.sh while bash is still reading it line-by-line, corrupting
# execution. The snapshot block at the top of the script mitigates this by
# re-exec'ing from a /tmp copy decoupled from the on-disk file.
#
# Design: the snapshot trigger is BASH_SOURCE[0]'s shape, NOT an env var.
# Path verification (must look like `<tmp>/codex-dispatch.XXXXXX/codex-dispatch.sh`) means
# polluted ambient environment cannot bypass the snapshot or trick the
# cleanup trap into removing an arbitrary file.
set -euo pipefail

# Clean baseline: even legacy env vars from earlier designs must not influence
# tests. (Defensive — current implementation ignores them entirely.)
unset CODEX_DISPATCH_SNAPSHOT_ACTIVE CODEX_DISPATCH_SNAPSHOT_PATH

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DISPATCH="$REPO_ROOT/adapters/codex/dispatch.sh"

# shellcheck source=scripts/lib/test-harness.sh
. "$SCRIPT_DIR/lib/test-harness.sh"
th_init "$@"

SNAP_RE="exec [^ ]*codex-dispatch\.[A-Za-z0-9]+/codex-dispatch\.sh"

# ---- 1: --help exits 0 ----
case_help_exits_0() {
  local name="snapshot/--help exits 0"
  should_run "$name" || return 0

  if "$DISPATCH" --help >/dev/null 2>&1; then
    pass "$name"
  else
    fail "$name" ""
  fi
}

# ---- 2: --help output preserved through re-exec ----
case_help_output_preserved() {
  local name="snapshot/--help output preserved"
  local out
  should_run "$name" || return 0

  out="$("$DISPATCH" --help 2>&1)"
  if grep -q "Wrapper for invoking" <<<"$out"; then
    pass "$name"
  else
    fail "$name" ""
  fi
}

# ---- 3: fresh invocation re-execs from a snapshot copy ----
case_fresh_invocation_reexecs_from_snapshot_copy() {
  local name="snapshot/fresh invocation re-execs from snapshot copy"
  local trace_out
  should_run "$name" || return 0

  trace_out="$(bash -x "$DISPATCH" --help 2>&1 1>/dev/null || true)"
  if grep -E "$SNAP_RE" <<<"$trace_out" >/dev/null; then
    pass "$name"
  else
    fail "$name" ""
    printf '  trace tail:\n%s\n' "$(printf '%s\n' "$trace_out" | tail -10 | sed 's/^/    /')" >&2
  fi
}

# ---- 4: SECURITY — ambient env vars do NOT bypass the snapshot ----
# Inherited CODEX_DISPATCH_SNAPSHOT_ACTIVE=1 used to skip the snapshot block.
# The new design is env-agnostic: trigger is BASH_SOURCE shape, not env.
case_ambient_env_defense() {
  local name="snapshot/ambient-env-defense — fresh snapshot taken regardless of env vars"
  local trace_out
  should_run "$name" || return 0

  trace_out="$(CODEX_DISPATCH_SNAPSHOT_ACTIVE=1 \
    CODEX_DISPATCH_SNAPSHOT_PATH=/tmp/this-must-be-ignored \
    bash -x "$DISPATCH" --help 2>&1 1>/dev/null || true)"
  if grep -E "$SNAP_RE" <<<"$trace_out" >/dev/null; then
    pass "$name"
  else
    fail "$name" ""
  fi
}

# ---- 5: SECURITY — ambient env path is NOT removed by cleanup trap ----
# An attacker who can pollute CODEX_DISPATCH_SNAPSHOT_PATH used to be able to
# trick the trap into rm-ing arbitrary user-writable files. Verify any inherited
# path is ignored — the cleanup trap targets only the freshly-created snapshot.
case_ambient_path_defense() {
  local name="snapshot/ambient-path-defense — arbitrary inherited path NOT deleted"
  local victim
  should_run "$name" || return 0

  victim="$(mktemp)"
  echo "do-not-delete" > "$victim"
  CODEX_DISPATCH_SNAPSHOT_ACTIVE=1 CODEX_DISPATCH_SNAPSHOT_PATH="$victim" \
    "$DISPATCH" --help >/dev/null 2>&1
  if [[ -f "$victim" && "$(cat "$victim")" == "do-not-delete" ]]; then
    pass "$name"
    rm -f "$victim"
  else
    fail "$name" ""
  fi
}

# ---- 6: cleanup on normal exit (no leak in resolved tmp dir) ----
case_cleanup_no_leak() {
  local before after name snapdir
  local name="snapshot/cleanup — no leak in resolved tmp dir"
  should_run "$name" || return 0
  # Hermetic count: a CONCURRENT suite's in-flight codex-dispatch.* snapshot in the
  # shared system tmp would otherwise inflate this count and false-fail under
  # parallel runs. Point TMPDIR at a private dir so only THIS invocation's snapshot
  # can appear in the counted dir; mktemp -t in the adapter honours TMPDIR.
  snapdir="$(mktemp -d)"
  before=$(find "$snapdir" -maxdepth 1 -type d -name 'codex-dispatch.*' 2>/dev/null | wc -l)
  TMPDIR="$snapdir" "$DISPATCH" --help >/dev/null 2>&1
  after=$(find "$snapdir" -maxdepth 1 -type d -name 'codex-dispatch.*' 2>/dev/null | wc -l)
  rm -rf "$snapdir"
  if [[ "$after" -le "$before" ]]; then
    pass "$name"
  else
    fail "$name" ""
  fi
}

# ---- 7: structural — snapshot block has all required constructs ----
# Stronger than just one keyword; guards against a partial-revert that
# silently breaks the mechanism while keeping a token of the original block.
case_structural_snapshot_block_intact() {
  local name="snapshot/structural — all snapshot-block constructs present"
  local missing=()
  should_run "$name" || return 0

  grep -qE 'BASH_SOURCE\[0\].*codex-dispatch\\\.\[A-Za-z0-9\]\{6\}/codex-dispatch\\\.sh' "$DISPATCH" \
    || missing+=("BASH_SOURCE path-pattern check")
  grep -q 'mktemp -d -t codex-dispatch'              "$DISPATCH" || missing+=("mktemp template")
  grep -q 'cp -- "\${BASH_SOURCE\[0\]}"'             "$DISPATCH" || missing+=("cp from BASH_SOURCE")
  grep -q 'chmod +x'                                  "$DISPATCH" || missing+=("chmod +x")
  grep -qE 'exec "\$__codex_dispatch_snapshot"'      "$DISPATCH" || missing+=("exec snapshot")
  grep -qE "trap.*rm -rf.*\\\$__codex_dispatch_snapshot_dir" "$DISPATCH" || missing+=("cleanup trap")
  if [[ "${#missing[@]}" -eq 0 ]]; then
    pass "$name"
  else
    fail "$name" ""
  fi
}

# ---- 8: dispatch startup does not mutate .gitignore ----
case_dispatch_does_not_mutate_gitignore() {
  local name="dispatch/does-not-mutate-gitignore"
  local tmp_repo before after
  should_run "$name" || return 0

  tmp_repo="$(mktemp -d)"
  git init -q "$tmp_repo"
  printf '*.log\n' > "$tmp_repo/.gitignore"
  before="$(sha256sum "$tmp_repo/.gitignore" | awk '{print $1}')"
  "$DISPATCH" --help >/dev/null 2>&1
  "$DISPATCH" --cd "$tmp_repo" --brief-file "$tmp_repo/missing-brief.md" >/dev/null 2>&1 || true
  after="$(sha256sum "$tmp_repo/.gitignore" | awk '{print $1}')"
  if [[ "$after" == "$before" ]]; then
    pass "$name"
  else
    fail "$name" ""
  fi
  rm -rf "$tmp_repo"
}

# ---- 9: auto-log/parser emits exactly one integer ----
case_auto_log_parser_single_integer() {
  local name="auto-log/parser-single-integer"
  local tmp_trace9 _result9
  should_run "$name" || return 0

  tmp_trace9="$(mktemp)"
  printf '%s\n' \
    '{"type":"turn.started"}' \
    '{"type":"turn.completed","usage":{"input_tokens":100000,"output_tokens":5000,"cached_input_tokens":0}}' \
    > "$tmp_trace9"
  _result9=$(jq -rs '
    first(.[] | select(.type == "turn.completed")
              | (.usage.input_tokens // 0) + (.usage.output_tokens // 0)) // 0
  ' "$tmp_trace9" 2>/dev/null || echo 0)
  rm -f "$tmp_trace9"
  # Must be exactly "105000" — one line, one integer
  if [[ "$_result9" == "105000" ]]; then
    pass "$name"
  else
    fail "$name" ""
  fi
}

# ---- 10: auto-log/successful-dispatch-logs-codex ----
case_auto_log_successful_dispatch_logs_codex() {
  local name="auto-log/successful-dispatch-logs-codex"
  local _fake_bin10 _home10 _work10 _brief10 _tracker10 _exit10
  local path
  should_run "$name" || return 0

  _fake_bin10="$(mktemp -d)"
  cat > "$_fake_bin10/codex" << 'FAKEOF'
#!/usr/bin/env bash
# Fake codex: write a minimal trace to stdout (captured to TRACE by dispatch)
printf '%s\n' \
  '{"type":"turn.started"}' \
  '{"type":"turn.completed","usage":{"input_tokens":100000,"output_tokens":5000,"cached_input_tokens":0,"reasoning_output_tokens":0}}'
exit 0
FAKEOF
  chmod +x "$_fake_bin10/codex"

  _home10="$(mktemp -d)"
  mkdir -p "$_home10/.claude/scripts"
  ln -s "$REPO_ROOT/scripts/log-usage.sh" "$_home10/.claude/scripts/log-usage.sh"

  _work10="$(mktemp -d)"
  git init -q "$_work10"

  _brief10="$(mktemp --suffix=.md)"
  printf 'working_dir: %s\ngoal: test auto-log\n' "$_work10" > "$_brief10"

  PATH="$_fake_bin10:$PATH" HOME="$_home10" \
    "$DISPATCH" --cd "$_work10" --brief-file "$_brief10" >/dev/null 2>&1
  _exit10=$?

  _tracker10="$_home10/.claude/usage-tracker.jsonl"
  if [[ "$_exit10" -eq 0 ]] \
     && [[ -f "$_tracker10" ]] && grep -q '"type":"codex_dispatch"' "$_tracker10" \
     && grep -q '"pool":"codex"' "$_tracker10" \
     && grep -q '"tokens":105000' "$_tracker10"; then
    pass "$name"
  else
    fail "$name" "exit=$_exit10"
  fi
  rm -rf "$_fake_bin10" "$_home10" "$_work10"
  rm -f "$_brief10"
}

# ---- 10b: PM_CFG_USAGE_LOG_PATH overrides the claude-host-assumed default path ----
case_auto_log_custom_path_codex() {
  local name="auto-log/PM_CFG_USAGE_LOG_PATH overrides default log-usage.sh path (codex)"
  local _fake_bin _home _work _brief _custom_log _marker _exit
  should_run "$name" || return 0

  _fake_bin="$(mktemp -d)"
  cat > "$_fake_bin/codex" << 'FAKEOF'
#!/usr/bin/env bash
printf '%s\n' \
  '{"type":"turn.started"}' \
  '{"type":"turn.completed","usage":{"input_tokens":100000,"output_tokens":5000,"cached_input_tokens":0,"reasoning_output_tokens":0}}'
exit 0
FAKEOF
  chmod +x "$_fake_bin/codex"

  _home="$(mktemp -d)"  # deliberately NO $_home/.claude/scripts/log-usage.sh —
                          # proves the default path is never consulted when the
                          # override is set.
  _custom_log="$(mktemp -d)/custom-log-usage.sh"
  _marker="$(mktemp -d)/marker"
  cat > "$_custom_log" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" > "$_marker"
EOF
  chmod +x "$_custom_log"

  _work="$(mktemp -d)"
  git init -q "$_work"
  _brief="$(mktemp --suffix=.md)"
  printf 'working_dir: %s\ngoal: test auto-log custom path\n' "$_work" > "$_brief"

  PATH="$_fake_bin:$PATH" HOME="$_home" PM_CFG_USAGE_LOG_PATH="$_custom_log" \
    "$DISPATCH" --cd "$_work" --brief-file "$_brief" >/dev/null 2>&1
  _exit=$?

  if [[ "$_exit" -eq 0 && -f "$_marker" ]] && grep -q "codex_dispatch" "$_marker" \
     && [[ ! -f "$_home/.claude/usage-tracker.jsonl" ]]; then
    pass "$name"
  else
    fail "$name" "exit=$_exit marker_exists=$([[ -f "$_marker" ]] && echo yes || echo no)"
  fi
  rm -rf "$_fake_bin" "$_home" "$_work" "$(dirname "$_custom_log")" "$(dirname "$_marker")"
  rm -f "$_brief"
}

# ---- 11: auto-log/failed-dispatch-no-log ----
case_auto_log_failed_dispatch_no_log() {
  local name="auto-log/failed-dispatch-no-log"
  local _fake_bin11 _home11 _work11 _brief11 _exit11
  should_run "$name" || return 0

  _fake_bin11="$(mktemp -d)"
  cat > "$_fake_bin11/codex" << 'FAKEOF'
#!/usr/bin/env bash
exit 1
FAKEOF
  chmod +x "$_fake_bin11/codex"

  _home11="$(mktemp -d)"
  mkdir -p "$_home11/.claude/scripts"
  ln -s "$REPO_ROOT/scripts/log-usage.sh" "$_home11/.claude/scripts/log-usage.sh"

  _work11="$(mktemp -d)"
  git init -q "$_work11"

  _brief11="$(mktemp --suffix=.md)"
  printf 'goal: test\n' > "$_brief11"

  PATH="$_fake_bin11:$PATH" HOME="$_home11" \
    "$DISPATCH" --cd "$_work11" --brief-file "$_brief11" >/dev/null 2>&1 || true

  if [[ ! -f "$_home11/.claude/usage-tracker.jsonl" ]]; then
    pass "$name"
  else
    fail "$name" ""
  fi
  rm -rf "$_fake_bin11" "$_home11" "$_work11"
  rm -f "$_brief11"
}

# ---- 12: auto-log/spark-model-logs-spark-pool ----
case_auto_log_spark_model_logs_pool() {
  local name="auto-log/spark-model-logs-spark-pool"
  local _fake_bin12 _home12 _work12 _brief12 _tracker12 _exit12
  should_run "$name" || return 0

  _fake_bin12="$(mktemp -d)"
  cat > "$_fake_bin12/codex" << 'FAKEOF'
#!/usr/bin/env bash
printf '%s\n' \
  '{"type":"turn.started"}' \
  '{"type":"turn.completed","usage":{"input_tokens":50000,"output_tokens":2000,"cached_input_tokens":0,"reasoning_output_tokens":0}}'
exit 0
FAKEOF
  chmod +x "$_fake_bin12/codex"

  _home12="$(mktemp -d)"
  mkdir -p "$_home12/.claude/scripts"
  ln -s "$REPO_ROOT/scripts/log-usage.sh" "$_home12/.claude/scripts/log-usage.sh"

  _work12="$(mktemp -d)"
  git init -q "$_work12"

  _brief12="$(mktemp --suffix=.md)"
  printf 'goal: spark test\n' > "$_brief12"

  PATH="$_fake_bin12:$PATH" HOME="$_home12" \
    "$DISPATCH" --cd "$_work12" --brief-file "$_brief12" --model codex-spark >/dev/null 2>&1
  _exit12=$?

  _tracker12="$_home12/.claude/usage-tracker.jsonl"
  if [[ "$_exit12" -eq 0 ]] \
     && [[ -f "$_tracker12" ]] && grep -q '"type":"codex_dispatch"' "$_tracker12" \
     && grep -q '"pool":"spark"' "$_tracker12" \
     && grep -q '"tokens":52000' "$_tracker12"; then
    pass "$name"
  else
    fail "$name" "exit=$_exit12"
  fi
  rm -rf "$_fake_bin12" "$_home12" "$_work12"
  rm -f "$_brief12"
}

# ---- 13: auto-log/log-failure-preserves-dispatch-exit ----
case_auto_log_log_failure_preserves_dispatch_exit() {
  local name="auto-log/log-failure-preserves-dispatch-exit"
  local _fake_bin13 _home13 _work13 _brief13 _stderr13 _exit13
  should_run "$name" || return 0

  _fake_bin13="$(mktemp -d)"
  cat > "$_fake_bin13/codex" << 'FAKEOF'
#!/usr/bin/env bash
printf '%s\n' \
  '{"type":"turn.started"}' \
  '{"type":"turn.completed","usage":{"input_tokens":10000,"output_tokens":500}}'
exit 0
FAKEOF
  chmod +x "$_fake_bin13/codex"

  _home13="$(mktemp -d)"
  mkdir -p "$_home13/.claude/scripts"
  # Deliberately no log-usage.sh so the auto-log call fails

  _work13="$(mktemp -d)"
  git init -q "$_work13"

  _brief13="$(mktemp --suffix=.md)"
  printf 'goal: test logging failure\n' > "$_brief13"

  PATH="$_fake_bin13:$PATH" HOME="$_home13" \
    "$DISPATCH" --cd "$_work13" --brief-file "$_brief13" >/dev/null 2>&1
  _exit13=$?

  # Find the stderr trace file written by dispatch
  _stderr13="$(ls "$_work13/.agent-trace/"*.stderr 2>/dev/null | head -1)"
  if [[ "$_exit13" -eq 0 && -n "$_stderr13" ]] && grep -q "usage log failed" "$_stderr13"; then
    pass "$name"
  else
    fail "$name" ""
  fi
  rm -rf "$_fake_bin13" "$_home13" "$_work13"
  rm -f "$_brief13"
}

# ---- 14: alias-resolution-spark prints resolved CMD with effort and resolved banner ----
case_alias_resolution_spark_prints_resolved_model_and_banner_no_trace_files() {
  local name="alias-resolution-spark prints resolved model + effort + banner + no trace files"
  local _work14 _brief14 _before14 _stderr14 _after14 _output14 _exit14
  should_run "$name" || return 0

  _work14="$(mktemp -d)"
  git init -q "$_work14"
  mkdir -p "$_work14/.agent-trace"

  _brief14="$(mktemp --suffix=.md)"
  printf 'goal: print cmd alias resolution test\n' > "$_brief14"

  _before14="$(find "$_work14/.agent-trace" -maxdepth 1 \( -type f -o -type l \) 2>/dev/null | wc -l)"
  _stderr14="$(mktemp)"
  set +e
  _output14="$("$DISPATCH" --cd "$_work14" --brief-file "$_brief14" --model codex-spark --print-cmd 2>"$_stderr14")"
  _exit14=$?
  set -e
  _after14="$(find "$_work14/.agent-trace" -maxdepth 1 \( -type f -o -type l \) 2>/dev/null | wc -l)"

  if [[ "$_exit14" -eq 0 ]] \
    && [[ "$_output14" == *"-m gpt-5.3-codex-spark"* ]] \
    && [[ "$_output14" == *'-c model_reasoning_effort="high"'* ]] \
    && [[ "$_before14" == "$_after14" ]] \
    && grep -q "model:    codex-spark → gpt-5.3-codex-spark (effort=high)" "$_stderr14"; then
    pass "$name"
  else
    fail "$name" ""
  fi
  rm -rf "$_work14"
  rm -f "$_brief14" "$_stderr14"
}

# ---- 15: full-form-passthrough keeps raw wire model id, effort falls to global default ----
# "gpt-5.3-codex-spark" is a wire id, not an alias key, so it has no alias
# effort column to inherit; effort resolution still applies the global
# default (medium) independent of the model-alias match.
case_full_form_passthrough_keeps_model_no_effort() {
  local name="full-form-passthrough keeps full model, effort falls to global default"
  local _work15 _brief15 _output15 _exit15
  should_run "$name" || return 0

  _work15="$(mktemp -d)"
  git init -q "$_work15"

  _brief15="$(mktemp --suffix=.md)"
  printf 'goal: print cmd full-form passthrough test\n' > "$_brief15"

  set +e
  _output15="$("$DISPATCH" --cd "$_work15" --brief-file "$_brief15" --model gpt-5.3-codex-spark --print-cmd)"
  _exit15=$?
  set -e
  if [[ "$_exit15" -eq 0 ]] \
    && [[ "$_output15" == *"-m gpt-5.3-codex-spark"* ]] \
    && [[ "$_output15" == *'model_reasoning_effort="medium"'* ]]; then
    pass "$name"
  else
    fail "$name" ""
  fi
  rm -rf "$_work15"
  rm -f "$_brief15"
}

# ---- 16: unknown-alias-fallback keeps raw model, effort falls to global default ----
# Effort resolution is independent of model-alias match — an unknown model
# still gets the global default effort (medium) applied via -c
# model_reasoning_effort, since there is no alias effort column to consult.
case_unknown_alias_fallback_keeps_raw_model() {
  local name="unknown-alias-fallback keeps raw model, effort falls to global default"
  local _work16 _brief16 _output16 _exit16
  should_run "$name" || return 0

  _work16="$(mktemp -d)"
  git init -q "$_work16"

  _brief16="$(mktemp --suffix=.md)"
  printf 'goal: print cmd unknown alias fallback test\n' > "$_brief16"

  set +e
  _output16="$("$DISPATCH" --cd "$_work16" --brief-file "$_brief16" --model unknown-tag --print-cmd)"
  _exit16=$?
  set -e
  if [[ "$_exit16" -eq 0 ]] \
    && [[ "$_output16" == *"-m unknown-tag"* ]] \
    && [[ "$_output16" == *'model_reasoning_effort="medium"'* ]]; then
    pass "$name"
  else
    fail "$name" ""
  fi
  rm -rf "$_work16"
  rm -f "$_brief16"
}

# ---- 16a: default model (no --model) resolves to gpt-5.5 with medium effort ----
# Behavior: with no --model and no config override, dispatch applies pm-dispatch's
#   pinned default (the `default` alias → gpt-5.5) instead of inheriting the host
#   ~/.codex/config.toml model. The default alias's effort column is medium, so a
#   plain dispatch is medium by default without an explicit --effort flag.
# Steps:
#   1. Run --print-cmd with an empty HOME (no ~/.pm-dispatch/config) and no --model.
#   2. Assert the printed CMD carries -m gpt-5.5 and model_reasoning_effort="medium".
case_default_model_resolves_gpt55() {
  local name="default-model/no --model resolves to gpt-5.5 + medium effort"
  local _home _work _brief _out _exit
  should_run "$name" || return 0

  _home="$(mktemp -d)"          # empty home: no ~/.pm-dispatch/config override
  _work="$(mktemp -d)"; git init -q "$_work"
  _brief="$(mktemp --suffix=.md)"; printf 'goal: default model test\n' > "$_brief"

  set +e
  _out="$(HOME="$_home" "$DISPATCH" --cd "$_work" --brief-file "$_brief" --print-cmd)"
  _exit=$?
  set -e
  if [[ "$_exit" -eq 0 ]] \
    && [[ "$_out" == *"-m gpt-5.5"* ]] \
    && [[ "$_out" == *'-c model_reasoning_effort="medium"'* ]]; then
    pass "$name"
  else
    fail "$name" ""
  fi
  rm -rf "$_work" "$_home"
  rm -f "$_brief"
}

# ---- 16b: explicit --model gpt-5.5 resolves with medium effort ----
# Behavior: explicitly requesting gpt-5.5 resolves through the alias table and
#   attaches medium reasoning effort.
# Steps:
#   1. Run --print-cmd with --model gpt-5.5.
#   2. Assert the CMD carries -m gpt-5.5 and model_reasoning_effort="medium".
case_explicit_gpt55_resolves_medium_effort() {
  local name="default-model/--model gpt-5.5 resolves + medium effort"
  local _home _work _brief _out _exit
  should_run "$name" || return 0

  _home="$(mktemp -d)"
  _work="$(mktemp -d)"; git init -q "$_work"
  _brief="$(mktemp --suffix=.md)"; printf 'goal: explicit gpt-5.5 test\n' > "$_brief"

  set +e
  _out="$(HOME="$_home" "$DISPATCH" --cd "$_work" --brief-file "$_brief" --model gpt-5.5 --print-cmd)"
  _exit=$?
  set -e
  if [[ "$_exit" -eq 0 ]] \
    && [[ "$_out" == *"-m gpt-5.5"* ]] \
    && [[ "$_out" == *'-c model_reasoning_effort="medium"'* ]]; then
    pass "$name"
  else
    fail "$name" ""
  fi
  rm -rf "$_work" "$_home"
  rm -f "$_brief"
}

# ---- 16c: explicit --model gpt-5.4 (fallback) resolves with medium effort ----
# Behavior: the documented fallback model gpt-5.4 resolves through the alias table
#   and attaches medium reasoning effort.
# Steps:
#   1. Run --print-cmd with --model gpt-5.4.
#   2. Assert the CMD carries -m gpt-5.4 and model_reasoning_effort="medium".
case_explicit_gpt54_resolves_medium_effort() {
  local name="default-model/--model gpt-5.4 fallback resolves + medium effort"
  local _home _work _brief _out _exit
  should_run "$name" || return 0

  _home="$(mktemp -d)"
  _work="$(mktemp -d)"; git init -q "$_work"
  _brief="$(mktemp --suffix=.md)"; printf 'goal: fallback gpt-5.4 test\n' > "$_brief"

  set +e
  _out="$(HOME="$_home" "$DISPATCH" --cd "$_work" --brief-file "$_brief" --model gpt-5.4 --print-cmd)"
  _exit=$?
  set -e
  if [[ "$_exit" -eq 0 ]] \
    && [[ "$_out" == *"-m gpt-5.4"* ]] \
    && [[ "$_out" == *'-c model_reasoning_effort="medium"'* ]]; then
    pass "$name"
  else
    fail "$name" ""
  fi
  rm -rf "$_work" "$_home"
  rm -f "$_brief"
}

# ---- 16e: explicit --model default alias resolves to gpt-5.5 + medium ----
# Behavior: the `default` alias is data-backed in share/model-aliases.tsv and
#   resolves to the gpt-5.5 wire id with medium effort.
# Steps:
#   1. Run --print-cmd with --model default.
#   2. Assert the CMD carries -m gpt-5.5 and model_reasoning_effort="medium".
case_default_alias_resolves_gpt55() {
  local name="default-model/--model default alias resolves to gpt-5.5 + medium"
  local _home _work _brief _out _exit
  should_run "$name" || return 0

  _home="$(mktemp -d)"
  _work="$(mktemp -d)"; git init -q "$_work"
  _brief="$(mktemp --suffix=.md)"; printf 'goal: default alias test\n' > "$_brief"

  set +e
  _out="$(HOME="$_home" "$DISPATCH" --cd "$_work" --brief-file "$_brief" --model default --print-cmd)"
  _exit=$?
  set -e
  if [[ "$_exit" -eq 0 ]] \
    && [[ "$_out" == *"-m gpt-5.5"* ]] \
    && [[ "$_out" == *'-c model_reasoning_effort="medium"'* ]]; then
    pass "$name"
  else
    fail "$name" ""
  fi
  rm -rf "$_work" "$_home"
  rm -f "$_brief"
}

# ---- 17: timeout precedence env-only uses CODEX_DISPATCH_TIMEOUT ----
case_timeout_env_only_precedence() {
  local name="timeout/env-only uses CODEX_DISPATCH_TIMEOUT"
  local _home17 _work17 _brief17 _stderr17 _exit17
  should_run "$name" || return 0

  _home17="$(mktemp -d)"
  _work17="$(mktemp -d)"
  git init -q "$_work17"
  _brief17="$(mktemp --suffix=.md)"
  _stderr17="$(mktemp)"
  printf 'goal: timeout precedence env-only test\n' > "$_brief17"
  set +e
  HOME="$_home17" CODEX_DISPATCH_TIMEOUT=600 \
    "$DISPATCH" --cd "$_work17" --brief-file "$_brief17" --print-cmd >/dev/null 2>"$_stderr17"
  _exit17=$?
  set -e
  if [[ "$_exit17" -eq 0 ]] && grep -q "timeout:  600s" "$_stderr17"; then
    pass "$name"
  else
    fail "$name" ""
  fi
  rm -rf "$_work17" "$_home17"
  rm -f "$_brief17" "$_stderr17"
}

# ---- 19: timeout precedence --timeout flag wins over CODEX_DISPATCH_TIMEOUT env ----
# Config loading has moved to pmctl (CC-293); direct adapter invocations only see
# CODEX_DISPATCH_TIMEOUT env and the --timeout flag. This case verifies the flag wins.
case_timeout_precedence_brief_field() {
  local name="timeout/--timeout flag beats CODEX_DISPATCH_TIMEOUT env"
  local _work19 _brief19 _stderr19 _exit19
  should_run "$name" || return 0

  _work19="$(mktemp -d)"
  git init -q "$_work19"
  _brief19="$(mktemp --suffix=.md)"
  _stderr19="$(mktemp)"
  printf 'goal: timeout precedence flag wins\n' > "$_brief19"
  set +e
  CODEX_DISPATCH_TIMEOUT=700 \
    "$DISPATCH" --cd "$_work19" --brief-file "$_brief19" --timeout 1200 --print-cmd >/dev/null 2>"$_stderr19"
  _exit19=$?
  set -e
  if [[ "$_exit19" -eq 0 ]] && grep -q "timeout:  1200s" "$_stderr19"; then
    pass "$name"
  else
    fail "$name" ""
  fi
  rm -rf "$_work19"
  rm -f "$_brief19" "$_stderr19"
}

# ---- 20: alias source missing exits non-zero ----
case_alias_source_missing_exits_2() {
  local name="alias-source/missing TSV exits non-zero"
  local _work _brief _dispatch _out _exit _tmproot
  should_run "$name" || return 0
  _work="$(mktemp -d)"; git init -q "$_work"
  _brief="$(mktemp --suffix=.md)"; printf 'goal: alias missing test\n' > "$_brief"
  # Build a fake repo tree so the bootstrap can resolve source_repo and copy the lib.
  _tmproot="$(mktemp -d)"
  mkdir -p "$_tmproot/adapters/codex" "$_tmproot/scripts/lib"
  cp "$REPO_ROOT/scripts/lib/model-aliases.sh" "$_tmproot/scripts/lib/"
  cp "$REPO_ROOT/scripts/lib/reasoning-effort.sh" "$_tmproot/scripts/lib/"
  cp "$REPO_ROOT/scripts/lib/timeout-resolve.sh" "$_tmproot/scripts/lib/"
  cp "$REPO_ROOT/scripts/lib/dispatch-common.sh" "$_tmproot/scripts/lib/"
  _dispatch="$_tmproot/adapters/codex/dispatch.sh"
  sed \
    -e 's|^PM_DISPATCH_ALIAS_FILE=.*|PM_DISPATCH_ALIAS_FILE="/tmp/__nonexistent_alias_$$"|g' \
    -e 's|^\[\[ -f "$PM_DISPATCH_ALIAS_FILE" \]\].*|: # forced PM_DISPATCH_ALIAS_FILE for test|g' \
    "$DISPATCH" > "$_dispatch"
  chmod +x "$_dispatch"
  set +e
  _out="$(bash "$_dispatch" --cd "$_work" --brief-file "$_brief" --model codex-spark --print-cmd 2>&1)"
  _exit=$?
  set -e
  if [[ "$_exit" -ne 0 ]] && grep -qiE "not found|alias source|missing" <<<"$_out"; then
    pass "$name"
  else
    fail "$name" "exit=$_exit out=$(head -1 <<<"$_out")"
  fi
  rm -rf "$_work" "$_tmproot"; rm -f "$_brief"
}

# ---- 21: alias source malformed exits non-zero ----
case_alias_source_malformed_exits_nonzero() {
  local name="alias-source/malformed TSV exits non-zero"
  local _work _brief _dispatch _alias_file _out _exit _tmproot
  should_run "$name" || return 0
  _work="$(mktemp -d)"; git init -q "$_work"
  _brief="$(mktemp --suffix=.md)"; printf 'goal: alias malformed test\n' > "$_brief"
  _alias_file="$(mktemp)"
  printf 'bad-alias\tgpt-5.3\n' > "$_alias_file"
  # Build a fake repo tree so the bootstrap can resolve source_repo and copy the lib.
  _tmproot="$(mktemp -d)"
  mkdir -p "$_tmproot/adapters/codex" "$_tmproot/scripts/lib"
  cp "$REPO_ROOT/scripts/lib/model-aliases.sh" "$_tmproot/scripts/lib/"
  cp "$REPO_ROOT/scripts/lib/reasoning-effort.sh" "$_tmproot/scripts/lib/"
  cp "$REPO_ROOT/scripts/lib/timeout-resolve.sh" "$_tmproot/scripts/lib/"
  cp "$REPO_ROOT/scripts/lib/dispatch-common.sh" "$_tmproot/scripts/lib/"
  _dispatch="$_tmproot/adapters/codex/dispatch.sh"
  sed \
    -e "s|^PM_DISPATCH_ALIAS_FILE=.*|PM_DISPATCH_ALIAS_FILE=\"$_alias_file\"|g" \
    -e 's|^\[\[ -f "$PM_DISPATCH_ALIAS_FILE" \]\].*|: # forced PM_DISPATCH_ALIAS_FILE for test|g' \
    "$DISPATCH" > "$_dispatch"
  chmod +x "$_dispatch"
  set +e
  _out="$(bash "$_dispatch" --cd "$_work" --brief-file "$_brief" --model codex-spark --print-cmd 2>&1)"
  _exit=$?
  set -e
  if [[ "$_exit" -ne 0 ]] && grep -qi "malformed" <<<"$_out"; then
    pass "$name"
  else
    fail "$name" "exit=$_exit out=$(head -1 <<<"$_out")"
  fi
  rm -rf "$_work" "$_tmproot"; rm -f "$_brief" "$_alias_file"
}

# ---- 22: alias source installed-helper fallback resolves from ../share ----
case_alias_source_installed_helper_fallback() {
  local name="alias-source/fallback to ../share/model-aliases.tsv"
  local _root _script_dir _share_dir _work _brief _dispatch _out _exit
  should_run "$name" || return 0
  _root="$(mktemp -d)"
  _script_dir="$_root/codex-dispatch.ABC123"
  _share_dir="$_root/share"
  mkdir -p "$_script_dir" "$_share_dir" "$_script_dir/lib"
  cp "$DISPATCH" "$_script_dir/codex-dispatch.sh"
  cp "$REPO_ROOT/scripts/lib/model-aliases.sh" "$_script_dir/lib/"
  cp "$REPO_ROOT/scripts/lib/reasoning-effort.sh" "$_script_dir/lib/"
  cp "$REPO_ROOT/scripts/lib/timeout-resolve.sh" "$_script_dir/lib/"
  cp "$REPO_ROOT/scripts/lib/dispatch-common.sh" "$_script_dir/lib/"
  chmod +x "$_script_dir/codex-dispatch.sh"
  printf 'codex-spark\tgpt-5.3-codex-spark\thigh\n' > "$_share_dir/model-aliases.tsv"
  _work="$(mktemp -d)"; git init -q "$_work"
  _brief="$(mktemp --suffix=.md)"; printf 'goal: alias fallback test\n' > "$_brief"
  _dispatch="$_script_dir/codex-dispatch.sh"
  set +e
  _out="$(bash "$_dispatch" --cd "$_work" --brief-file "$_brief" --model codex-spark --print-cmd 2>&1)"
  _exit=$?
  set -e
  if [[ "$_exit" -eq 0 ]]; then
    pass "$name"
  else
    fail "$name" "exit=$_exit out=$(head -1 <<<"$_out")"
  fi
  rm -rf "$_root" "$_work"; rm -f "$_brief"
}

# ---- 23: isolation workspace-network generates network override ----
case_isolation_workspace_network() {
  # Verifies that --isolation workspace-network generates --sandbox workspace-write
  # plus the sandbox_workspace_write.network_access=true config override.
  # Steps:
  # 1. Create a temp dir with a minimal brief file.
  # 2. Run codex-dispatch.sh --isolation workspace-network --print-cmd.
  # 3. Assert output contains --sandbox workspace-write AND network_access=true.
  local name="isolation-workspace-network"
  local dir brief out
  should_run "$name" || return 0

  dir="$(mktemp -d)"
  brief="$dir/brief.md"
  printf 'goal: isolation test\n' > "$brief"
  out="$(bash "$DISPATCH" --cd "$dir" --brief-file "$brief" --isolation workspace-network --print-cmd 2>&1)"
  rm -rf "$dir"
  if ! printf '%s\n' "$out" | grep -q -- '--sandbox workspace-write'; then
    fail "$name" "expected --sandbox workspace-write in output; got: $out"
    return
  fi
  if ! printf '%s\n' "$out" | grep -q 'sandbox_workspace_write.network_access=true'; then
    fail "$name" "expected sandbox_workspace_write.network_access=true in output; got: $out"
    return
  fi
  pass "$name"
}

# ---- 24: isolation workspace-write does not generate network override ----
case_isolation_workspace_write_no_network() {
  # Verifies that --isolation workspace-write generates --sandbox workspace-write
  # without any network_access config override.
  # Steps:
  # 1. Create a temp dir with a minimal brief file.
  # 2. Run codex-dispatch.sh --isolation workspace-write --print-cmd.
  # 3. Assert output contains --sandbox workspace-write and does NOT contain network_access.
  local name="isolation-workspace-write-no-network"
  local dir brief out
  should_run "$name" || return 0

  dir="$(mktemp -d)"
  brief="$dir/brief.md"
  printf 'goal: isolation test\n' > "$brief"
  out="$(bash "$DISPATCH" --cd "$dir" --brief-file "$brief" --isolation workspace-write --print-cmd 2>&1)"
  rm -rf "$dir"
  if ! printf '%s\n' "$out" | grep -q -- '--sandbox workspace-write'; then
    fail "$name" "expected --sandbox workspace-write; got: $out"
    return
  fi
  if printf '%s\n' "$out" | grep -q 'network_access'; then
    fail "$name" "workspace-write must not add network_access override; got: $out"
    return
  fi
  pass "$name"
}

# ---- 25: unknown isolation level exits 2 ----
case_isolation_unknown_level_exits_error() {
  # Verifies that an unrecognised isolation level causes codex-dispatch.sh to exit 2.
  # Steps:
  # 1. Create a temp dir with a minimal brief file.
  # 2. Run codex-dispatch.sh --isolation unknown-level --print-cmd.
  # 3. Assert exit code is exactly 2.
  local name="isolation-unknown-level-error"
  local dir brief code
  should_run "$name" || return 0

  dir="$(mktemp -d)"
  brief="$dir/brief.md"
  printf 'goal: isolation test\n' > "$brief"
  set +e
  bash "$DISPATCH" --cd "$dir" --brief-file "$brief" --isolation unknown-level --print-cmd >/dev/null 2>&1
  code=$?
  set -e
  rm -rf "$dir"
  if [[ "$code" -ne 2 ]]; then
    fail "$name" "expected exit 2 for unknown isolation level; got $code"
    return
  fi
  pass "$name"
}

# ---- 26: isolation none is rejected (codex full-access retired) ----
case_isolation_none() {
  # Verifies that --isolation none is rejected fail-loud (exit 2). codex's
  # danger-full-access mapping was removed with the codex-executor retirement;
  # `none` is no longer in adapters/codex/isolation-map.yaml, so the adapter's
  # isolation lookup fails with an "unknown isolation_level" error. codex's max
  # isolation is workspace-write.
  # Steps:
  # 1. Create a temp dir with a minimal brief file.
  # 2. Run codex-dispatch.sh --isolation none --print-cmd; capture exit code.
  # 3. Assert exit 2 and an "unknown isolation_level" message mentioning none.
  local name="isolation-none-rejected"
  local dir brief out code
  should_run "$name" || return 0

  dir="$(mktemp -d)"
  brief="$dir/brief.md"
  printf 'goal: isolation test\n' > "$brief"
  out="$(bash "$DISPATCH" --cd "$dir" --brief-file "$brief" --isolation none --print-cmd 2>&1)" && code=0 || code=$?
  rm -rf "$dir"
  if [[ "$code" -ne 2 ]]; then
    fail "$name" "expected exit 2 for retired isolation level none; got $code (out: $out)"
    return
  fi
  if ! printf '%s\n' "$out" | grep -qi 'unknown isolation_level'; then
    fail "$name" "expected 'unknown isolation_level' message; got: $out"
    return
  fi
  pass "$name"
}

# ---- 26b: raw --sandbox danger-full-access is rejected fail-loud ----
case_sandbox_danger_full_access_rejected() {
  # Verifies the codex full-access retirement holds against the raw native flag,
  # not just the --isolation none path. A caller passing --sandbox
  # danger-full-access directly (or via pmctl dispatch run native-flag
  # passthrough) must be rejected fail-loud (exit 2) before `codex exec` is built.
  # Steps:
  # 1. Create a temp dir with a minimal brief file.
  # 2. Run codex-dispatch.sh --sandbox danger-full-access --print-cmd; capture exit.
  # 3. Assert exit 2 and that the printed command does NOT contain danger-full-access.
  local name="sandbox-danger-full-access-rejected"
  local dir brief out code
  should_run "$name" || return 0

  dir="$(mktemp -d)"
  brief="$dir/brief.md"
  printf 'goal: sandbox bypass test\n' > "$brief"
  out="$(bash "$DISPATCH" --cd "$dir" --brief-file "$brief" --sandbox danger-full-access --print-cmd 2>&1)" && code=0 || code=$?
  rm -rf "$dir"
  if [[ "$code" -ne 2 ]]; then
    fail "$name" "expected exit 2 for retired --sandbox danger-full-access; got $code (out: $out)"
    return
  fi
  if printf '%s\n' "$out" | grep -q -- 'danger-full-access' && printf '%s\n' "$out" | grep -q -- 'codex exec'; then
    fail "$name" "printed codex exec command still contains danger-full-access: $out"
    return
  fi
  pass "$name"
}

# ---- 27: isolation read-only generates read-only sandbox ----
case_isolation_read_only() {
  # Verifies that --isolation read-only generates --sandbox read-only.
  # Steps:
  # 1. Create a temp dir with a minimal brief file.
  # 2. Run codex-dispatch.sh --isolation read-only --print-cmd.
  # 3. Assert output contains --sandbox read-only.
  local name="isolation-read-only"
  local dir brief out
  should_run "$name" || return 0

  dir="$(mktemp -d)"
  brief="$dir/brief.md"
  printf 'goal: isolation test\n' > "$brief"
  out="$(bash "$DISPATCH" --cd "$dir" --brief-file "$brief" --isolation read-only --print-cmd 2>&1)"
  rm -rf "$dir"
  if ! printf '%s\n' "$out" | grep -q -- '--sandbox read-only'; then
    fail "$name" "expected --sandbox read-only in output; got: $out"
    return
  fi
  pass "$name"
}

# ---- 28: isolation sandboxed generates workspace-write without network override ----
case_isolation_sandboxed() {
  # Verifies that --isolation sandboxed generates --sandbox workspace-write
  # without any network_access config override.
  # Steps:
  # 1. Create a temp dir with a minimal brief file.
  # 2. Run codex-dispatch.sh --isolation sandboxed --print-cmd.
  # 3. Assert output contains --sandbox workspace-write and does NOT contain network_access.
  local name="isolation-sandboxed"
  local dir brief out
  should_run "$name" || return 0

  dir="$(mktemp -d)"
  brief="$dir/brief.md"
  printf 'goal: isolation test\n' > "$brief"
  out="$(bash "$DISPATCH" --cd "$dir" --brief-file "$brief" --isolation sandboxed --print-cmd 2>&1)"
  rm -rf "$dir"
  if ! printf '%s\n' "$out" | grep -q -- '--sandbox workspace-write'; then
    fail "$name" "expected --sandbox workspace-write; got: $out"
    return
  fi
  if printf '%s\n' "$out" | grep -q 'network_access'; then
    fail "$name" "sandboxed must not add network_access override; got: $out"
    return
  fi
  pass "$name"
}

# ---- 28a: --effort flag overrides the model alias's own effort column ----
case_effort_flag_overrides_alias() {
  local name="effort-flag/--effort low overrides alias's high"
  local dir brief out
  should_run "$name" || return 0

  dir="$(mktemp -d)"
  brief="$dir/brief.md"
  printf 'goal: effort override test\n' > "$brief"
  out="$(bash "$DISPATCH" --cd "$dir" --brief-file "$brief" --model default --effort low --print-cmd 2>&1)"
  rm -rf "$dir"
  if ! printf '%s\n' "$out" | grep -q -- 'model_reasoning_effort="low"'; then
    fail "$name" "expected model_reasoning_effort=\"low\"; got: $out"
    return
  fi
  pass "$name"
}

# ---- 28b: omitting --effort with no alias match falls back to global default (medium) ----
case_effort_flag_default_medium() {
  local name="effort-flag/omit --effort falls back to global default medium"
  local dir brief out
  should_run "$name" || return 0

  dir="$(mktemp -d)"
  brief="$dir/brief.md"
  printf 'goal: effort default test\n' > "$brief"
  out="$(bash "$DISPATCH" --cd "$dir" --brief-file "$brief" --model unknown-tag --print-cmd 2>&1)"
  rm -rf "$dir"
  if ! printf '%s\n' "$out" | grep -q -- 'model_reasoning_effort="medium"'; then
    fail "$name" "expected model_reasoning_effort=\"medium\"; got: $out"
    return
  fi
  pass "$name"
}

# ---- 28c: invalid --effort value is rejected before dispatch ----
case_effort_flag_invalid_rejected() {
  local name="effort-flag/invalid value rejected"
  local dir brief out exit_code
  should_run "$name" || return 0

  dir="$(mktemp -d)"
  brief="$dir/brief.md"
  printf 'goal: effort invalid test\n' > "$brief"
  set +e
  out="$(bash "$DISPATCH" --cd "$dir" --brief-file "$brief" --effort bogus --print-cmd 2>&1)"
  exit_code=$?
  set -e
  rm -rf "$dir"
  if [[ "$exit_code" -eq 0 ]] || ! printf '%s\n' "$out" | grep -q 'low medium high'; then
    fail "$name" "expected non-zero exit and error listing low/medium/high; got exit=$exit_code out=$out"
    return
  fi
  pass "$name"
}

# ---- 29: print-cmd with no brief exits 0 and emits command ----
case_print_cmd_no_brief() {
  local name="print-cmd no-brief exits 0 and emits command"
  should_run "$name" || return 0
  local _work29 _out29 _err29 _exit29

  _work29="$(mktemp -d)"
  git init -q "$_work29"
  _err29="$(mktemp)"

  set +e
  _out29="$("$DISPATCH" --cd "$_work29" --print-cmd 2>"$_err29")"
  _exit29=$?
  set -e

  if [[ "$_exit29" -ne 0 ]]; then
    fail "$name" "exit $_exit29 - expected 0; print-cmd with no brief must not fail"
    return
  fi
  if [[ -z "$_out29" ]]; then
    fail "$name" "empty output - expected assembled command on stdout"
    return
  fi
  pass "$name"
}

case_state_store_no_direct_run_row_codex() {
  # Verifies that direct invocation of adapters/codex/dispatch.sh (bypassing
  # pmctl) does NOT write a Run row to the state store. pmctl owns state writes;
  # the adapter is state-ignorant after CC-309.
  local name="state-store/codex adapter direct invocation does not write Run row"
  should_run "$name" || return 0
  local _fake _home _work _brief _store _runs_file _code
  _fake="$(mktemp -d)"
  cat > "$_fake/codex" << 'FAKEOF'
#!/usr/bin/env bash
printf '%s\n' \
  '{"type":"turn.started"}' \
  '{"type":"turn.completed","usage":{"input_tokens":10,"output_tokens":5}}'
exit 0
FAKEOF
  chmod +x "$_fake/codex"
  _home="$(mktemp -d)"; mkdir -p "$_home/.claude/scripts"
  ln -s "$REPO_ROOT/scripts/log-usage.sh" "$_home/.claude/scripts/log-usage.sh"
  _store="$(mktemp -d)"
  _work="$(mktemp -d)"; git init -q "$_work"
  _brief="$(mktemp --suffix=.md)"
  printf 'task_id: CC-309\ngoal: state store codex row test\n' > "$_brief"
  set +e
  PATH="$_fake:$PATH" HOME="$_home" PM_DISPATCH_STATE_ROOT="$_store" \
    "$DISPATCH" --cd "$_work" --brief-file "$_brief" >/dev/null 2>&1
  _code=$?
  set -e
  _runs_file="$(find "$_store" -name "runs.jsonl" -type f 2>/dev/null | head -1 || true)"
  if [[ "$_code" -eq 0 && -z "$_runs_file" ]]; then
    pass "$name"
  else
    fail "$name" "code=$_code unexpected runs=${_runs_file:-none} content=$(cat "${_runs_file:-/dev/null}" 2>/dev/null | head -c 200)"
  fi
  rm -rf "$_fake" "$_home" "$_store" "$_work"; rm -f "$_brief"
}


# ---- latest.* symlink failure is tolerated (Windows MSYS, CC-308) ----
# On Windows MSYS, `ln -sfn` fails when refreshing the latest.* convenience
# symlinks because the target trace file does not yet exist. The adapter guards
# each `ln` with `2>/dev/null || true`; under `set -e` an unguarded failure would
# abort the whole dispatch before codex runs. Force `ln` to fail for latest.* and
# assert dispatch still completes and writes its real trace file.
case_latest_symlink_failure_tolerated() {
  local name="dispatch/latest.* symlink failure does not abort dispatch"
  local _fake _home _work _brief _exit _trace
  should_run "$name" || return 0

  _fake="$(mktemp -d)"
  cat > "$_fake/codex" << 'FAKEOF'
#!/usr/bin/env bash
printf '%s\n' \
  '{"type":"turn.started"}' \
  '{"type":"turn.completed","usage":{"input_tokens":10,"output_tokens":5}}'
exit 0
FAKEOF
  chmod +x "$_fake/codex"
  # Fake ln: fail for latest.* (simulate MSYS), delegate everything else to real ln.
  cat > "$_fake/ln" << 'FAKELN'
#!/usr/bin/env bash
for a in "$@"; do
  case "$a" in *latest.*) exit 1 ;; esac
done
for real in /usr/bin/ln /bin/ln; do [[ -x "$real" ]] && exec "$real" "$@"; done
exit 1
FAKELN
  chmod +x "$_fake/ln"

  _home="$(mktemp -d)"; mkdir -p "$_home/.claude/scripts"
  ln -s "$REPO_ROOT/scripts/log-usage.sh" "$_home/.claude/scripts/log-usage.sh"
  _work="$(mktemp -d)"; git init -q "$_work"
  _brief="$(mktemp --suffix=.md)"
  printf 'working_dir: %s\ngoal: test ln tolerance\n' "$_work" > "$_brief"

  set +e
  PATH="$_fake:$PATH" HOME="$_home" "$DISPATCH" --cd "$_work" --brief-file "$_brief" >/dev/null 2>&1
  _exit=$?
  set -e

  # Real trace file must exist; latest.jsonl symlink must be absent (ln failed).
  _trace="$(ls "$_work"/.agent-trace/codex-*.jsonl 2>/dev/null | head -1)"
  if [[ "$_exit" -eq 0 && -n "$_trace" && -s "$_trace" ]] \
     && [[ ! -e "$_work/.agent-trace/latest.jsonl" ]]; then
    pass "$name"
  else
    fail "$name" "exit=$_exit trace=${_trace:-missing} latest_symlink=$([[ -e "$_work/.agent-trace/latest.jsonl" ]] && echo present || echo absent)"
  fi
  rm -rf "$_fake" "$_home" "$_work"; rm -f "$_brief"
}

case_help_exits_0
case_help_output_preserved
case_fresh_invocation_reexecs_from_snapshot_copy
case_ambient_env_defense
case_ambient_path_defense
case_cleanup_no_leak
case_structural_snapshot_block_intact
case_dispatch_does_not_mutate_gitignore
case_auto_log_parser_single_integer
case_auto_log_successful_dispatch_logs_codex
case_auto_log_custom_path_codex
case_auto_log_failed_dispatch_no_log
case_auto_log_spark_model_logs_pool
case_auto_log_log_failure_preserves_dispatch_exit
case_alias_resolution_spark_prints_resolved_model_and_banner_no_trace_files
case_full_form_passthrough_keeps_model_no_effort
case_unknown_alias_fallback_keeps_raw_model
case_default_model_resolves_gpt55
case_explicit_gpt55_resolves_medium_effort
case_explicit_gpt54_resolves_medium_effort
case_default_alias_resolves_gpt55
case_timeout_env_only_precedence
case_timeout_precedence_brief_field
case_alias_source_missing_exits_2
case_alias_source_malformed_exits_nonzero
case_alias_source_installed_helper_fallback
case_isolation_workspace_network
case_isolation_workspace_write_no_network
case_isolation_unknown_level_exits_error
case_isolation_none
case_sandbox_danger_full_access_rejected
case_isolation_read_only
case_isolation_sandboxed
case_effort_flag_overrides_alias
case_effort_flag_default_medium
case_effort_flag_invalid_rejected
case_print_cmd_no_brief
case_latest_symlink_failure_tolerated
case_state_store_no_direct_run_row_codex

# ---- light alias resolves to gpt-5.3-codex-spark ----
case_model_alias_light() {
  local name="model-alias/--model light resolves to gpt-5.3-codex-spark"
  local _work _brief _out _exit
  should_run "$name" || return 0
  _work="$(mktemp -d)"; git init -q "$_work"
  _brief="$(mktemp --suffix=.md)"
  printf 'goal: light alias resolution test\n' > "$_brief"
  set +e
  _out="$("$DISPATCH" --cd "$_work" --brief-file "$_brief" --model light --print-cmd 2>/dev/null)"
  _exit=$?
  set -e
  if [[ "$_exit" -eq 0 ]] \
    && [[ "$_out" == *"-m gpt-5.3-codex-spark"* ]] \
    && [[ "$_out" == *'-c model_reasoning_effort="high"'* ]]; then
    pass "$name"
  else
    fail "$name" "exit=$_exit out=$(printf '%s' "$_out" | tail -1)"
  fi
  rm -rf "$_work"; rm -f "$_brief"
}

case_model_alias_light

# ---- trace-dir/--trace-dir routes trace out of repo ----
case_trace_dir_flag_routes_out_of_repo() {
  # Behavior: --trace-dir <abs> writes the run's trace files to that dir and
  # leaves the repo's in-repo .agent-trace untouched (the relocation seam).
  # Steps: fake codex; run with --trace-dir to a temp dir; assert trace lands
  # there and NOT under $work/.agent-trace.
  local name="trace-dir/--trace-dir routes trace out of repo"
  local fake work brief tdir
  should_run "$name" || return 0
  fake="$(mktemp -d)"
  cat > "$fake/codex" << 'FAKEOF'
#!/usr/bin/env bash
printf '%s\n' '{"type":"turn.completed","usage":{"input_tokens":1,"output_tokens":1,"cached_input_tokens":0,"reasoning_output_tokens":0}}'
exit 0
FAKEOF
  chmod +x "$fake/codex"
  work="$(mktemp -d)"; git init -q "$work"
  brief="$(mktemp --suffix=.md)"; printf 'goal: trace-dir test\n' > "$brief"
  tdir="$(mktemp -d)/explicit-trace"
  PATH="$fake:$PATH" "$DISPATCH" --cd "$work" --brief-file "$brief" --trace-dir "$tdir" >/dev/null 2>&1 || true
  if compgen -G "$tdir/codex-*.jsonl" >/dev/null && [[ ! -d "$work/.agent-trace" ]]; then
    pass "$name"
  else
    fail "$name" "override=$(ls "$tdir" 2>/dev/null) inrepo=$(ls "$work/.agent-trace" 2>/dev/null)"
  fi
  rm -rf "$fake" "$work" "$tdir"; rm -f "$brief"
}

# ---- trace-dir/relative --trace-dir rejected ----
case_trace_dir_relative_rejected() {
  # Behavior: a relative --trace-dir is rejected (exit 2) so trace location never
  # depends on cwd. Steps: run with a relative --trace-dir; assert non-zero exit.
  local name="trace-dir/relative --trace-dir rejected"
  local work brief rc
  should_run "$name" || return 0
  work="$(mktemp -d)"; git init -q "$work"
  brief="$(mktemp --suffix=.md)"; printf 'goal: t\n' > "$brief"
  set +e
  "$DISPATCH" --cd "$work" --brief-file "$brief" --trace-dir "rel/trace" >/dev/null 2>&1
  rc=$?
  set -e
  if [[ "$rc" -eq 2 ]]; then pass "$name"; else fail "$name" "rc=$rc"; fi
  rm -rf "$work"; rm -f "$brief"
}

case_trace_dir_flag_routes_out_of_repo
case_trace_dir_relative_rejected

th_summary
