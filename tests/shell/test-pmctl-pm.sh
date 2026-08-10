#!/usr/bin/env bash
# Regression tests for the batch-only pmctl pm coordinator.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PMCTL="$REPO_ROOT/cli/pmctl"

# shellcheck source=tests/lib/test-harness.sh
. "$SCRIPT_DIR/../lib/test-harness.sh"
th_init "$@"

# Operator memory/config is external state. Contract-only prepare cases run
# against this checkout, so isolate both project-scoped config and legacy
# CLAUDE_CONFIG_DIR discovery at suite scope. Individual continuity/config
# cases opt into their own PM_MEMORY_DIR or fixture config explicitly.
export PM_DISPATCH_CONFIG_FILE="$tmp_root/no-operator-config"
export CLAUDE_CONFIG_DIR="$tmp_root/isolated-claude-config"
mkdir -p "$CLAUDE_CONFIG_DIR/projects"
unset PM_MEMORY_DIR PM_CFG_MEMORY_DIR PM_CFG_MEMORY_DIR_INVALID PM_CFG_MEMORY_CONFIG_STATUS

# Preparation now reports repo-context freshness. Avoid mutating this checkout's
# live derived DB in the many contract-only cases; dedicated fixture cases opt
# back into refresh explicitly.
export PM_DISPATCH_CONTEXT_AUTOREFRESH=0

# Behavior: prepare creates a snapshot and reports the non-interactive contract as JSON.
# Steps: run prepare against this checkout with a ticket in the request; assert its snapshot and policy fields.
case_prepare_emits_batch_contract() {
  local name="pmctl pm prepare: emits batch-only contract with snapshot"
  should_run "$name" || return 0
  local out code=0 snapshot
  out="$("$PMCTL" pm prepare --cd "$REPO_ROOT" --request 'implement CC-473' --json 2>/dev/null)" || code=$?
  if [[ "$code" -eq 0 ]] \
    && jq -e --arg wd "$REPO_ROOT" '.mode == "batch-only" and .working_dir == $wd and .focus_tickets == ["CC-473"] and .snapshot_status == "created" and .handover_required == true' <<<"$out" >/dev/null; then
    snapshot="$(jq -r '.snapshot_file' <<<"$out")"
    [[ -f "$snapshot" ]] && rm -f "$snapshot" && pass "$name" || fail "$name" "snapshot_file was not created"
  else
    fail "$name" "code=$code out=$out"
  fi
}

# Behavior: prepare's human mode exposes the batch contract and snapshot handoff.
# Steps: invoke prepare without --json; assert its required lines and remove the created snapshot.
case_prepare_emits_human_contract() {
  local name="pmctl pm prepare: emits human batch contract"
  should_run "$name" || return 0
  local out code=0 snapshot
  out="$("$PMCTL" pm prepare --cd "$REPO_ROOT" --request 'human contract CC-473' 2>/dev/null)" || code=$?
  snapshot="$(printf '%s\n' "$out" | sed -n 's/^snapshot_file: //p')"
  if [[ "$code" -eq 0 ]] \
    && [[ "$out" == *$'mode: batch-only\n'* ]] \
    && [[ "$out" == *"working_dir: $REPO_ROOT"* ]] \
    && [[ "$out" == *"focus_tickets: CC-473"* ]] \
    && [[ "$out" == *"snapshot_status: created"* ]] \
    && [[ "$out" == *"next: author a complete dispatch_handover_v1 brief, then run pmctl pm run"* ]] \
    && [[ -f "$snapshot" ]]; then
    rm -f "$snapshot"
    pass "$name"
  else
    fail "$name" "code=$code snapshot=$snapshot out=$out"
  fi
}

# Behavior: prepare defaults its work directory to the caller's git toplevel.
# Steps: invoke prepare from this checkout without --cd; assert its JSON work directory resolves to the checkout root.
case_prepare_defaults_to_caller_git_root() {
  local name="pmctl pm prepare: defaults to caller git root"
  should_run "$name" || return 0
  local out code=0 snapshot
  out="$(cd "$REPO_ROOT" && "$PMCTL" pm prepare --request 'default cwd CC-473' --json 2>/dev/null)" || code=$?
  if [[ "$code" -eq 0 ]] && jq -e --arg wd "$REPO_ROOT" '.working_dir == $wd' <<<"$out" >/dev/null; then
    snapshot="$(jq -r '.snapshot_file' <<<"$out")"
    [[ -f "$snapshot" ]] && rm -f "$snapshot"
    pass "$name"
  else
    fail "$name" "code=$code out=$out"
  fi
}

# Behavior: prepare succeeds without a snapshot when a target git repo has no BACKLOG.md.
# Steps: create a minimal git repo without a backlog; invoke prepare; assert unavailable snapshot status and null file.
case_prepare_degrades_without_backlog() {
  local name="pmctl pm prepare: degrades when backlog is absent"
  should_run "$name" || return 0
  local work="$tmp_root/no-backlog" out code=0
  mkdir -p "$work"
  git -C "$work" init -q
  out="$("$PMCTL" pm prepare --cd "$work" --request 'external repository request' --json 2>/dev/null)" || code=$?
  if [[ "$code" -eq 0 ]] && jq -e '.snapshot_status == "unavailable" and .snapshot_file == null' <<<"$out" >/dev/null; then
    pass "$name"
  else
    fail "$name" "code=$code out=$out"
  fi
}

# Behavior: preparation refreshes the target repo's canonical context DB and
# reconciles a marker deletion on the next preparation.
# Steps: prepare a fixture with a unique marker, assert repo_context + query hit;
# remove the marker, prepare again, then assert the same DB no longer returns it.
case_prepare_repo_context_marker_round_trip() {
  local name="pmctl pm prepare: repo context marker round-trip uses canonical DB"
  should_run "$name" || return 0
  command -v sqlite3 >/dev/null 2>&1 || { pass "$name (sqlite unavailable)"; return 0; }
  local work="$tmp_root/prepare-context-work" marker out snapshot query code=0
  mkdir -p "$work/docs"
  git -C "$work" init -q
  marker="$work/docs/cc484-prepare.md"
  printf '# CC484 prepare marker\n\ncc484prepareroundtrip\n' > "$marker"
  out="$(PM_DISPATCH_CONTEXT_AUTOREFRESH=1 "$PMCTL" pm prepare --cd "$work" --request 'cc484prepareroundtrip' --json 2>/dev/null)" || code=$?
  snapshot="$(jq -r '.snapshot_file // empty' <<<"$out" 2>/dev/null || true)"
  [[ -n "$snapshot" && -f "$snapshot" ]] && rm -f "$snapshot"
  if [[ "$code" -ne 0 ]] || ! jq -e --arg repo "$work" --arg db "$work/.pm-dispatch/ctx/context.db" \
      '.repo_context.resolved_repo_root == $repo and .repo_context.db_path == $db and .repo_context.freshness == "fresh" and (.repo_context.refresh_status == "built" or .repo_context.refresh_status == "refreshed")' <<<"$out" >/dev/null; then
    fail "$name" "first prepare did not report fresh canonical context: code=$code out=$out"; return 0
  fi
  query="$(PM_DISPATCH_CONTEXT_AUTOREFRESH=0 "$PMCTL" context query "$work" cc484prepareroundtrip 2>/dev/null)"
  [[ "$query" == *"docs/cc484-prepare.md"* ]] || { fail "$name" "marker missing after prepare: $query"; return 0; }
  rm -f "$marker"
  code=0
  out="$(PM_DISPATCH_CONTEXT_AUTOREFRESH=1 "$PMCTL" pm prepare --cd "$work" --request 'cc484prepareroundtrip removal' --json 2>/dev/null)" || code=$?
  snapshot="$(jq -r '.snapshot_file // empty' <<<"$out" 2>/dev/null || true)"
  [[ -n "$snapshot" && -f "$snapshot" ]] && rm -f "$snapshot"
  query="$(PM_DISPATCH_CONTEXT_AUTOREFRESH=0 "$PMCTL" context query "$work" cc484prepareroundtrip 2>/dev/null)"
  if [[ "$code" -eq 0 ]] && jq -e '.repo_context.freshness == "fresh"' <<<"$out" >/dev/null && [[ "$query" == *"# no hits"* ]]; then
    pass "$name"
  else
    fail "$name" "removed marker remained or context stale: code=$code prepare=$out query=$query"
  fi
}

# Behavior: prepare extracts each CC ticket once even when it occurs repeatedly in the request.
# Steps: prepare a request containing duplicate IDs; assert focus_tickets preserves first-seen unique order.
case_prepare_deduplicates_focus_tickets() {
  local name="pmctl pm prepare: deduplicates extracted focus tickets"
  should_run "$name" || return 0
  local out code=0 snapshot
  out="$("$PMCTL" pm prepare --cd "$REPO_ROOT" --request 'CC-473 then CC-473 and CC-474 then CC-473' --json 2>/dev/null)" || code=$?
  if [[ "$code" -eq 0 ]] && jq -e '.focus_tickets == ["CC-473", "CC-474"]' <<<"$out" >/dev/null; then
    snapshot="$(jq -r '.snapshot_file' <<<"$out")"
    [[ -f "$snapshot" ]] && rm -f "$snapshot"
    pass "$name"
  else
    fail "$name" "code=$code out=$out"
  fi
}

# Behavior: prepare rejects an empty request before creating any snapshot.
# Steps: invoke prepare with whitespace-only request text and assert usage exit 2.
case_prepare_rejects_empty_request() {
  local name="pmctl pm prepare: rejects empty request"
  should_run "$name" || return 0
  local code=0
  "$PMCTL" pm prepare --cd "$REPO_ROOT" --request '   ' >/dev/null 2>&1 || code=$?
  [[ "$code" -eq 2 ]] && pass "$name" || fail "$name" "expected exit 2, got $code"
}

# Behavior: prepare rejects a work directory outside a git worktree before creating a snapshot.
# Steps: pass a non-git directory with a valid request; assert usage exit 2 and the worktree error.
case_prepare_rejects_non_git_workdir() {
  local name="pmctl pm prepare: rejects non-git workdir"
  should_run "$name" || return 0
  local out="$tmp_root/non-git-prepare.out" code=0
  "$PMCTL" pm prepare --cd "$tmp_root" --request 'CC-473' > "$out" 2>&1 || code=$?
  if [[ "$code" -eq 2 ]] && grep -q 'must be inside a git worktree' "$out"; then
    pass "$name"
  else
    fail "$name" "expected worktree error, got $code out=$(<"$out")"
  fi
}

# Behavior: Codex preparation deterministically hydrates request-relevant context from shared project memory.
# Steps: create a Claude-authored card in PM_MEMORY_DIR, prepare the same repo, and assert the host-neutral handoff.
case_prepare_hydrates_shared_memory() {
  local name="pmctl pm prepare: hydrates shared memory across host boundary"
  should_run "$name" || return 0
  local work="$tmp_root/memory-work" mdir="$tmp_root/canonical-memory" cfg="$tmp_root/unused-claude-config" out="$tmp_root/memory-prepare.json" code=0 snapshot encoded legacy
  mkdir -p "$work" "$mdir"
  git -C "$work" init -q
  cat > "$mdir/MEMORY.md" <<'MD'
- [Host switch rule](project_host_switch.md) — preserve hostswitche2e continuity across runtimes
MD
  cat > "$mdir/project_host_switch.md" <<'MD'
---
topics:
  - hostswitche2e
priority: normal
status: active
updated_at: "2026-07-12"
repo_refs: []
---
The hostswitche2e rule says every host must reuse the canonical project memory.
MD
  out="$(PM_MEMORY_DIR="$mdir" CLAUDE_CONFIG_DIR="$cfg" "$PMCTL" pm prepare --cd "$work" --request 'hostswitche2e' --json 2>/dev/null)" || code=$?
  snapshot="$(jq -r '.snapshot_file // empty' <<<"$out" 2>/dev/null || true)"
  [[ -n "$snapshot" && -f "$snapshot" ]] && rm -f "$snapshot"
  encoded="-${work#/}"; encoded="${encoded//\//-}"
  legacy="$cfg/projects/$encoded/memory"
  if [[ "$code" -eq 0 ]] && jq -e --arg mdir "$mdir" \
    '.memory_resolution.status == "resolved" and .memory_resolution.resolution_source == "env" and .memory_resolution.memory_dir == $mdir and .memory_context_status == "hydrated" and (.memory_context | contains("project_host_switch.md"))' <<<"$out" >/dev/null \
    && [[ ! -e "$legacy" ]]; then
    pass "$name"
  else
    fail "$name" "code=$code out=$out"
  fi
}

# Behavior: preparation names the calling host while keeping pmctl canonical and native memory auxiliary.
# Steps: run the same shared-memory query through all host labels and assert identical refs/authority.
case_prepare_emits_cross_host_memory_provenance() {
  local name="pmctl pm prepare: all hosts emit canonical pmctl provenance"
  should_run "$name" || return 0
  local work="$tmp_root/provenance-work" mdir="$tmp_root/provenance-memory" host out snapshot code
  mkdir -p "$work" "$mdir"
  git -C "$work" init -q
  printf '%s\n' '- [CC483 provenance](project_cc483.md) — cc483provenancemarker' > "$mdir/MEMORY.md"
  printf '%s\n' '---' 'topics:' '  - cc483provenancemarker' 'priority: normal' 'status: active' 'updated_at: "2026-07-13"' 'repo_refs: []' '---' 'canonical cc483provenancemarker' > "$mdir/project_cc483.md"
  for host in claude codex opencode grok generic; do
    code=0
    out="$(PM_MEMORY_DIR="$mdir" "$PMCTL" pm prepare --cd "$work" --host "$host" --request cc483provenancemarker --json 2>/dev/null)" || code=$?
    snapshot="$(jq -r '.snapshot_file // empty' <<<"$out" 2>/dev/null || true)"
    [[ -n "$snapshot" && -f "$snapshot" ]] && rm -f "$snapshot"
    if [[ "$code" -ne 0 ]] || ! jq -e --arg host "$host" --arg mdir "$mdir" \
      '.memory_provenance.host == $host and .memory_provenance.provider == "pmctl" and .memory_provenance.authority == "canonical" and .memory_provenance.memory_dir == $mdir and .memory_provenance.resolution_source == "env" and .memory_provenance.hit_count >= 1 and (.memory_provenance.refs | index("project_cc483.md:1") != null) and .memory_provenance.auxiliary_memory.role == "auxiliary" and .memory_provenance.auxiliary_memory.status == "unknown"' <<<"$out" >/dev/null; then
      fail "$name" "host=$host code=$code out=$out"; return 0
    fi
  done
  pass "$name"
}

# Behavior: a conflicting host-native note cannot replace canonical pmctl results.
# Steps: place opposite text under CODEX_HOME, query canonical memory, and assert only canonical refs are exposed.
case_prepare_native_conflict_stays_auxiliary() {
  local name="pmctl pm prepare: conflicting native note cannot replace canonical constraint"
  should_run "$name" || return 0
  local work="$tmp_root/native-conflict-work" mdir="$tmp_root/native-conflict-memory" codex_home="$tmp_root/native-conflict-codex" out snapshot code=0
  mkdir -p "$work" "$mdir" "$codex_home/memories"
  git -C "$work" init -q
  printf '%s\n' '- [Canonical authority](canonical_rule.md) — cc483authoritymarker' > "$mdir/MEMORY.md"
  printf '%s\n' '---' 'topics:' '  - cc483authoritymarker' 'priority: always' 'status: active' 'updated_at: "2026-07-13"' 'repo_refs: []' '---' 'CANONICAL_RULE_WINS cc483authoritymarker' > "$mdir/canonical_rule.md"
  printf '%s\n' 'NATIVE_CONFLICT_WINS cc483authoritymarker' > "$codex_home/memories/conflict.md"
  out="$(PM_MEMORY_DIR="$mdir" CODEX_HOME="$codex_home" "$PMCTL" pm prepare --cd "$work" --host codex --request cc483authoritymarker --json 2>/dev/null)" || code=$?
  snapshot="$(jq -r '.snapshot_file // empty' <<<"$out" 2>/dev/null || true)"
  [[ -n "$snapshot" && -f "$snapshot" ]] && rm -f "$snapshot"
  if [[ "$code" -eq 0 ]] && jq -e \
    '.memory_provenance.provider == "pmctl" and (.memory_provenance.refs | index("canonical_rule.md:1") != null) and .memory_provenance.auxiliary_memory.status == "unknown" and (.memory_context | contains("conflict.md") | not)' <<<"$out" >/dev/null; then
    pass "$name"
  else
    fail "$name" "code=$code out=$out"
  fi
}

# Behavior: Codex preparation refuses an invalid explicit memory selection instead of reading legacy memory.
# Steps: create an available legacy path plus a missing PM_MEMORY_DIR and assert fail-closed preparation.
case_prepare_rejects_invalid_explicit_memory() {
  local name="pmctl pm prepare: invalid explicit memory fails closed"
  should_run "$name" || return 0
  local work="$tmp_root/invalid-memory-work" cfg="$tmp_root/invalid-memory-cfg" missing="$tmp_root/absent-memory" out="$tmp_root/invalid-memory.out" code=0 encoded
  mkdir -p "$work"
  git -C "$work" init -q
  encoded="-${work#/}"; encoded="${encoded//\//-}"
  mkdir -p "$cfg/projects/$encoded/memory"
  PM_MEMORY_DIR="$missing" CLAUDE_CONFIG_DIR="$cfg" "$PMCTL" pm prepare --cd "$work" --request 'must not fall back' --json > "$out" 2>&1 || code=$?
  if [[ "$code" -eq 1 ]] && grep -q 'explicit memory configuration is invalid' "$out"; then
    pass "$name"
  else
    fail "$name" "expected exit 1 without fallback; code=$code out=$(<"$out")"
  fi
}

# Behavior: a resolved memory directory with no relevant cards is an explicit no-hits outcome.
# Steps: prepare against an empty shared directory and assert null context without blocking PM work.
case_prepare_reports_no_memory_hits() {
  local name="pmctl pm prepare: resolved memory with zero hits reports no-hits"
  should_run "$name" || return 0
  local work="$tmp_root/no-hits-work" mdir="$tmp_root/no-hits-memory" out code=0 snapshot
  mkdir -p "$work" "$mdir"
  git -C "$work" init -q
  out="$(PM_MEMORY_DIR="$mdir" "$PMCTL" pm prepare --cd "$work" --request 'nothingmatches98765' --json 2>/dev/null)" || code=$?
  snapshot="$(jq -r '.snapshot_file // empty' <<<"$out" 2>/dev/null || true)"
  [[ -n "$snapshot" && -f "$snapshot" ]] && rm -f "$snapshot"
  if [[ "$code" -eq 0 ]] && jq -e \
    '.memory_resolution.status == "resolved" and .memory_context_status == "no-hits" and .memory_context == null' <<<"$out" >/dev/null; then
    pass "$name"
  else
    fail "$name" "code=$code out=$out"
  fi
}

# Behavior: retrieval failure degrades to query-failed while preserving a successful preparation contract.
# Steps: source the coordinator with a resolved-memory stub and failing context pack; assert the JSON status.
case_prepare_reports_memory_query_failure() {
  local name="pmctl pm prepare: memory pack failure reports query-failed"
  should_run "$name" || return 0
  . "$REPO_ROOT/runtime/lib/pmctl-pm.sh"
  local work="$tmp_root/query-failed-work" mdir="$tmp_root/query-failed-memory" out="$tmp_root/query-failed.json" code=0
  mkdir -p "$work" "$mdir"
  git -C "$work" init -q
  # shellcheck disable=SC2329 # Indirectly invoked by pmctl_pm_prepare.
  pmctl_memory_resolve() {
    jq -cn --arg repo "$work" --arg mdir "$mdir" '{schema_version:1,status:"resolved",repo_root:$repo,project_key:"test",memory_dir:$mdir,resolution_source:"env",readable:true,writable:true,reason:null}'
  }
  # shellcheck disable=SC2329 # Indirectly invoked by pmctl_pm_prepare.
  _ctx_extract_terms() { printf 'queryfailureterm\n'; }
  # shellcheck disable=SC2329 # Indirectly invoked by pmctl_pm_prepare.
  pmctl_context_pack() { return 9; }
  pmctl_pm_prepare "$REPO_ROOT" --cd "$work" --request 'queryfailureterm' --json > "$out" 2>/dev/null || code=$?
  unset -f pmctl_memory_resolve _ctx_extract_terms pmctl_context_pack
  if [[ "$code" -eq 0 ]] && jq -e \
    '.memory_context_status == "query-failed" and .memory_context == null' "$out" >/dev/null; then
    pass "$name"
  else
    fail "$name" "code=$code out=$(<"$out")"
  fi
}

# Behavior: oversized memory packs stay valid JSON by dropping whole memory entries.
# Steps: stub an 80-entry pack over 6000 bytes; prepare and assert bounded parseable output.
case_prepare_bounds_memory_pack_without_corruption() {
  local name="pmctl pm prepare: oversized memory pack stays parseable and bounded"
  should_run "$name" || return 0
  . "$REPO_ROOT/runtime/lib/pmctl-pm.sh"
  local work="$tmp_root/oversized-pack-work" mdir="$tmp_root/oversized-pack-memory" out="$tmp_root/oversized-pack.json" code=0
  mkdir -p "$work" "$mdir"
  git -C "$work" init -q
  # shellcheck disable=SC2329 # Indirectly invoked by pmctl_pm_prepare.
  pmctl_memory_resolve() {
    jq -cn --arg repo "$work" --arg mdir "$mdir" '{schema_version:1,status:"resolved",repo_root:$repo,project_key:"test",memory_dir:$mdir,resolution_source:"env",readable:true,writable:true,reason:null}'
  }
  # shellcheck disable=SC2329 # Indirectly invoked by pmctl_pm_prepare.
  _ctx_extract_terms() { printf 'oversizedpackterm\n'; }
  # shellcheck disable=SC2329 # Indirectly invoked by pmctl_pm_prepare.
  pmctl_context_pack() {
    jq -cn '{schema_version:2,task_id:"pm-prepare",built_ts:"2026-07-12T00:00:00Z",sources:[{name:"memory-index",version:"1"}],files:[],symbols:[],memories:[range(0;80) as $i | {ref:("card-"+($i|tostring)+"-"+("x"*120)+".md:1"),source:"memory-index",confidence:0.75,source_domain:"memory",why_relevant:"memory match",trust_level:"high"}],risks:[]}'
  }
  pmctl_pm_prepare "$REPO_ROOT" --cd "$work" --request 'oversizedpackterm' --json > "$out" 2>/dev/null || code=$?
  unset -f pmctl_memory_resolve _ctx_extract_terms pmctl_context_pack
  if [[ "$code" -eq 0 ]] && jq -e \
    '.memory_context_status == "hydrated" and (.memory_context | length) <= 6000 and ((.memory_context | fromjson | .memories | length) > 0) and ((.memory_context | fromjson | .memories | length) < 80)' "$out" >/dev/null; then
    pass "$name"
  else
    fail "$name" "code=$code out=$(<"$out")"
  fi
}

# Behavior: human preparation exposes hydrated canonical memory with explicit fences.
# Steps: stub a resolved pack, invoke non-JSON mode, and assert all human contract lines.
case_prepare_human_emits_hydrated_memory_contract() {
  local name="pmctl pm prepare: human mode emits hydrated memory contract"
  should_run "$name" || return 0
  . "$REPO_ROOT/runtime/lib/pmctl-pm.sh"
  local work="$tmp_root/human-memory-work" mdir="$tmp_root/human-memory-dir" out="$tmp_root/human-memory.out" code=0
  mkdir -p "$work" "$mdir"
  git -C "$work" init -q
  # shellcheck disable=SC2329 # Indirectly invoked by pmctl_pm_prepare.
  pmctl_memory_resolve() {
    jq -cn --arg repo "$work" --arg mdir "$mdir" '{schema_version:1,status:"resolved",repo_root:$repo,project_key:"test",memory_dir:$mdir,resolution_source:"env",readable:true,writable:true,reason:null}'
  }
  # shellcheck disable=SC2329 # Indirectly invoked by pmctl_pm_prepare.
  _ctx_extract_terms() { printf 'humanmemoryterm\n'; }
  # shellcheck disable=SC2329 # Indirectly invoked by pmctl_pm_prepare.
  pmctl_context_pack() {
    printf '%s\n' '{"schema_version":2,"task_id":"pm-prepare","built_ts":"2026-07-12T00:00:00Z","sources":[{"name":"memory-index","version":"1"}],"files":[],"symbols":[],"memories":[{"ref":"card.md:1","source":"memory-index","confidence":0.75,"source_domain":"memory","why_relevant":"memory match","trust_level":"high"}],"risks":[]}'
  }
  pmctl_pm_prepare "$REPO_ROOT" --cd "$work" --request 'humanmemoryterm' > "$out" 2>/dev/null || code=$?
  unset -f pmctl_memory_resolve _ctx_extract_terms pmctl_context_pack
  if [[ "$code" -eq 0 ]] \
    && grep -q '^memory_status: hydrated$' "$out" \
    && grep -q "^memory_dir: $mdir$" "$out" \
    && grep -q '^--- memory_context ---$' "$out" \
    && grep -q '"ref":"card.md:1"' "$out" \
    && grep -q '^--- end_memory_context ---$' "$out"; then
    pass "$name"
  else
    fail "$name" "code=$code out=$(<"$out")"
  fi
}

# Behavior: human preparation reports unavailable memory without fabricating a path or context block.
# Steps: stub the resolver's unavailable result and assert the negative-space contract.
case_prepare_human_emits_unavailable_memory_contract() {
  local name="pmctl pm prepare: human mode omits unavailable memory details"
  should_run "$name" || return 0
  . "$REPO_ROOT/runtime/lib/pmctl-pm.sh"
  local work="$tmp_root/human-no-memory-work" out="$tmp_root/human-no-memory.out" code=0
  mkdir -p "$work"
  git -C "$work" init -q
  # shellcheck disable=SC2329 # Indirectly invoked by pmctl_pm_prepare.
  pmctl_memory_resolve() {
    printf '%s\n' '{"schema_version":1,"status":"unavailable","repo_root":"x","project_key":"x","memory_dir":null,"resolution_source":"none","readable":false,"writable":false,"reason":null}'
    return 1
  }
  pmctl_pm_prepare "$REPO_ROOT" --cd "$work" --request 'no memory here' > "$out" 2>/dev/null || code=$?
  unset -f pmctl_memory_resolve
  if [[ "$code" -eq 0 ]] \
    && grep -q '^memory_status: unavailable$' "$out" \
    && ! grep -q '^memory_dir:' "$out" \
    && ! grep -q '^--- memory_context ---$' "$out"; then
    pass "$name"
  else
    fail "$name" "code=$code out=$(<"$out")"
  fi
}

# Behavior: the pack bound helper fails when fixed envelope fields alone exceed the budget.
# Steps: call the helper with no memories and a tiny limit; assert nonzero and no output.
case_bound_memory_pack_rejects_oversized_envelope() {
  local name="pmctl pm prepare: pack bound rejects oversized fixed envelope"
  should_run "$name" || return 0
  . "$REPO_ROOT/runtime/lib/pmctl-pm.sh"
  local out="$tmp_root/oversized-envelope.out" code=0
  pmctl_pm_bound_memory_pack '{"schema_version":2,"task_id":"a-large-fixed-envelope","sources":[],"memories":[]}' 10 > "$out" 2>/dev/null || code=$?
  if [[ "$code" -ne 0 && ! -s "$out" ]]; then
    pass "$name"
  else
    fail "$name" "expected nonzero with empty output; code=$code out=$(<"$out")"
  fi
}

# Behavior: invalid explicit memory cleanup removes a snapshot created earlier in preparation.
# Steps: inject a deterministic snapshot producer plus invalid resolver and assert no orphan remains.
case_prepare_invalid_memory_cleans_snapshot() {
  local name="pmctl pm prepare: invalid memory removes created snapshot"
  should_run "$name" || return 0
  . "$REPO_ROOT/runtime/lib/pmctl-pm.sh"
  local work="$tmp_root/snapshot-cleanup-work" toolroot="$tmp_root/snapshot-toolroot" snapshot="$tmp_root/orphan-snapshot.md" out="$tmp_root/snapshot-cleanup.out" code=0
  mkdir -p "$work" "$toolroot/runtime/bin"
  git -C "$work" init -q
  printf '%s\n' '#!/usr/bin/env bash' \
    "printf 'snapshot fixture\\n' > '$snapshot'" \
    "printf '%s\\n' '$snapshot'" > "$toolroot/runtime/bin/pm-prep-snapshot.sh"
  chmod +x "$toolroot/runtime/bin/pm-prep-snapshot.sh"
  # shellcheck disable=SC2329 # Indirectly invoked by pmctl_pm_prepare.
  pmctl_memory_resolve() {
    printf '%s\n' '{"schema_version":1,"status":"invalid-explicit","repo_root":"x","project_key":"x","memory_dir":null,"resolution_source":"env","readable":false,"writable":false,"reason":"missing"}'
    return 3
  }
  pmctl_pm_prepare "$toolroot" --cd "$work" --request 'cleanup snapshot' --json > "$out" 2>&1 || code=$?
  unset -f pmctl_memory_resolve
  if [[ "$code" -eq 1 ]] && [[ ! -e "$snapshot" ]] && grep -q 'explicit memory configuration is invalid' "$out"; then
    pass "$name"
  else
    fail "$name" "code=$code snapshot_exists=$([[ -e "$snapshot" ]] && printf yes || printf no) out=$(<"$out")"
  fi
}

# Behavior: an unknown pm subcommand fails with the pm command usage contract.
# Steps: invoke pmctl pm with an unsupported subcommand; assert usage exit 2 and the prepare usage line.
case_unknown_subcommand_shows_usage() {
  local name="pmctl pm: unknown subcommand shows usage"
  should_run "$name" || return 0
  local out="$tmp_root/unknown.out" code=0
  "$PMCTL" pm not-a-real-subcommand > "$out" 2>&1 || code=$?
  if [[ "$code" -eq 2 ]] && grep -q '^usage: pmctl pm prepare' "$out"; then
    pass "$name"
  else
    fail "$name" "expected exit 2 with pm usage, got $code out=$(<"$out")"
  fi
}

# Behavior: run validates first, then uses the existing detached dispatch and wait primitives.
# Steps: source the coordinator with fake primitives; assert launch/wait arguments and JSON result.
case_run_uses_validate_detached_wait() {
  local name="pmctl pm run: validates then dispatches detached and waits"
  should_run "$name" || return 0
  # shellcheck source=runtime/lib/pmctl-pm.sh
  . "$REPO_ROOT/runtime/lib/pmctl-pm.sh"
  local trace="$tmp_root/run-trace" out="$tmp_root/run.out" seen_validate seen_launch seen_wait code=0
  pmctl_validate_brief() { printf 'validate:%s\n' "$*" >> "$trace"; return 0; }
  pmctl_dispatch_run() { printf 'launch:%s\n' "$*" >> "$trace"; printf 'run-test-473\n'; }
  pmctl_dispatch_wait() {
    [[ "${1:-}" == "$REPO_ROOT" ]] || return 97
    shift
    printf 'wait:%s\n' "$*" >> "$trace"
    return 0
  }
  pmctl_pm_run "$REPO_ROOT" --adapter codex --brief-file /tmp/brief-test.md --cd "$REPO_ROOT" --timeout 61 --json > "$out" || code=$?
  seen_validate="$(grep '^validate:' "$trace" || true)"
  seen_launch="$(grep '^launch:' "$trace" || true)"
  seen_wait="$(grep '^wait:' "$trace" || true)"
  if [[ "$code" -eq 0 ]] \
    && [[ "$seen_validate" == *"/tmp/brief-test.md"* ]] \
    && [[ "$seen_launch" == *"--lifecycle detached"* ]] \
    && [[ "$seen_wait" == "wait:run-test-473 --cd $REPO_ROOT --timeout 61" ]] \
    && jq -e '.run_id == "run-test-473" and .wait_exit_code == 0' "$out" >/dev/null; then
    pass "$name"
  else
    fail "$name" "code=$code validate=$seen_validate launch=$seen_launch wait=$seen_wait out=$(<"$out")"
  fi
}

# Behavior: run's human mode prints the authenticated dispatch handoff result.
# Steps: stub validation, launch, and wait; assert dispatch plus memory provenance lines.
case_run_emits_human_contract() {
  local name="pmctl pm run: emits human batch contract"
  should_run "$name" || return 0
  # shellcheck source=runtime/lib/pmctl-pm.sh
  . "$REPO_ROOT/runtime/lib/pmctl-pm.sh"
  local out="$tmp_root/run-human.out" code=0
  pmctl_validate_brief() { return 0; }
  pmctl_dispatch_run() { printf 'run-test-human-output\n'; }
  pmctl_dispatch_wait() { return 0; }
  pmctl_pm_run "$REPO_ROOT" --adapter codex --brief-file /tmp/brief-test.md --cd "$REPO_ROOT" > "$out" || code=$?
  if [[ "$code" -eq 0 ]] \
    && grep -q '^run_id: run-test-human-output$' "$out" \
    && grep -q '^memory_provider: pmctl$' "$out" \
    && grep -q '^auxiliary_memory_status: unknown$' "$out" \
    && grep -q '^wait_exit_code: 0$' "$out"; then
    pass "$name"
  else
    fail "$name" "code=$code out=$(<"$out")"
  fi
}

# Behavior: dispatch re-resolves canonical memory and carries provenance/refs in the executed brief.
# Steps: stub resolver/query/dispatch, run as OpenCode host, and inspect JSON plus forwarded brief.
case_run_carries_memory_provenance_into_dispatch_brief() {
  local name="pmctl pm run: dispatch artifact carries canonical memory provenance"
  should_run "$name" || return 0
  . "$REPO_ROOT/runtime/lib/pmctl-pm.sh"
  local work="$tmp_root/run-provenance-work" mdir="$tmp_root/run-provenance-memory" brief="$tmp_root/run-provenance-source.md" trace="$tmp_root/run-provenance-trace" out="$tmp_root/run-provenance.out" code=0 effective
  mkdir -p "$work" "$mdir"
  git -C "$work" init -q
  printf 'working_dir: %s\ngoal: cc483 dispatch provenance\nfiles:\n  - read: README.md\nacceptance:\n  - provenance\n' "$work" > "$brief"
  # shellcheck disable=SC2329 # Indirectly invoked by pmctl_pm_run.
  pmctl_validate_brief() { return 0; }
  # shellcheck disable=SC2329 # Indirectly invoked by pmctl_pm_run.
  pmctl_memory_resolve() { jq -cn --arg repo "$work" --arg mdir "$mdir" '{schema_version:1,status:"resolved",repo_root:$repo,project_key:"cc483-key",memory_dir:$mdir,resolution_source:"env",readable:true,writable:true,reason:null}'; }
  # shellcheck disable=SC2329 # Indirectly invoked by pmctl_pm_run.
  pmctl_dispatch_extract_goal() { printf 'cc483 dispatch provenance\n'; }
  # shellcheck disable=SC2329 # Indirectly invoked by pmctl_pm_run.
  pmctl_context_pack() { printf '%s\n' '{"schema_version":2,"task_id":"pm-run","memories":[{"ref":"canonical.md:7"}]}' ; }
  # shellcheck disable=SC2329 # Indirectly invoked by pmctl_pm_run.
  pmctl_dispatch_run() { printf '%s\n' "$*" > "$trace"; printf 'run-test-provenance\n'; }
  # shellcheck disable=SC2329 # Indirectly invoked by pmctl_pm_run.
  pmctl_dispatch_wait() { return 0; }
  pmctl_pm_run "$REPO_ROOT" --adapter codex --brief-file "$brief" --cd "$work" --host opencode --json > "$out" || code=$?
  unset -f pmctl_validate_brief pmctl_memory_resolve pmctl_dispatch_extract_goal pmctl_context_pack pmctl_dispatch_run pmctl_dispatch_wait
  effective="$(jq -r '.dispatch_brief // empty' "$out" 2>/dev/null || true)"
  if [[ "$code" -eq 0 ]] \
    && jq -e '.memory_provenance.host == "opencode" and .memory_provenance.provider == "pmctl" and .memory_provenance.hit_count == 1 and .memory_provenance.refs == ["canonical.md:7"]' "$out" >/dev/null \
    && [[ -f "$effective" ]] \
    && grep -q '^canonical_memory_provenance:$' "$effective" \
    && grep -q 'canonical.md:7' "$effective" \
    && grep -q -- "--brief-file $effective" "$trace"; then
    pass "$name"
  else
    fail "$name" "code=$code effective=$effective out=$(<"$out") trace=$(cat "$trace" 2>/dev/null || true)"
  fi
}

# Behavior: run rejects an invalid handover before it can launch a dispatch.
# Steps: invoke the CLI with a malformed brief and assert usage exit 2 and no executor requirement.
case_run_rejects_invalid_brief() {
  local name="pmctl pm run: rejects invalid brief before dispatch"
  should_run "$name" || return 0
  local brief="$tmp_root/invalid.md" code=0
  printf 'not a handover\n' > "$brief"
  "$PMCTL" pm run --adapter codex --brief-file "$brief" --cd "$REPO_ROOT" >/dev/null 2>&1 || code=$?
  [[ "$code" -eq 2 ]] && pass "$name" || fail "$name" "expected exit 2, got $code"
}

# Behavior: run rejects incomplete invocations before validating or dispatching a brief.
# Steps: omit required adapter and brief arguments; assert usage exit 2 and the complete required-field error.
case_run_requires_adapter_brief_and_workdir() {
  local name="pmctl pm run: requires adapter brief and workdir"
  should_run "$name" || return 0
  local out="$tmp_root/missing-run-fields.out" code=0
  "$PMCTL" pm run --cd "$REPO_ROOT" > "$out" 2>&1 || code=$?
  if [[ "$code" -eq 2 ]] && grep -q -- '--adapter, --brief-file, and --cd are required' "$out"; then
    pass "$name"
  else
    fail "$name" "expected required-field error, got $code out=$(<"$out")"
  fi
}

# Behavior: run rejects a work directory outside a git worktree before dispatch.
# Steps: supply all required flags with a non-git directory; assert usage exit 2 and the worktree error.
case_run_rejects_non_git_workdir() {
  local name="pmctl pm run: rejects non-git workdir"
  should_run "$name" || return 0
  local out="$tmp_root/non-git-run.out" code=0
  "$PMCTL" pm run --adapter codex --brief-file /tmp/brief-test.md --cd "$tmp_root" > "$out" 2>&1 || code=$?
  if [[ "$code" -eq 2 ]] && grep -q 'must be inside a git worktree' "$out"; then
    pass "$name"
  else
    fail "$name" "expected worktree error, got $code out=$(<"$out")"
  fi
}

# Behavior: run rejects a malformed dispatch identifier and does not enter its wait path.
# Steps: stub validation and launch with an invalid identifier; assert exit 1, diagnostic, and no wait trace.
case_run_rejects_invalid_dispatch_id() {
  local name="pmctl pm run: rejects invalid dispatch id before wait"
  should_run "$name" || return 0
  # shellcheck source=runtime/lib/pmctl-pm.sh
  . "$REPO_ROOT/runtime/lib/pmctl-pm.sh"
  local trace="$tmp_root/invalid-id-trace" out="$tmp_root/invalid-id.out" code=0
  pmctl_validate_brief() { return 0; }
  pmctl_dispatch_run() { printf 'not-a-run-id\n'; }
  pmctl_dispatch_wait() { printf 'wait-called\n' >> "$trace"; return 0; }
  pmctl_pm_run "$REPO_ROOT" --adapter codex --brief-file /tmp/brief-test.md --cd "$REPO_ROOT" > "$out" 2>&1 || code=$?
  if [[ "$code" -eq 1 ]] && grep -q 'dispatch returned invalid run id' "$out" && [[ ! -e "$trace" ]]; then
    pass "$name"
  else
    fail "$name" "expected invalid-id rejection, got $code out=$(<"$out") trace=$(cat "$trace" 2>/dev/null || true)"
  fi
}

# Behavior: run preserves a non-zero authenticated wait result after emitting its batch result.
# Steps: stub a valid launch and a failing wait; assert the returned exit code and JSON wait_exit_code match.
case_run_propagates_wait_failure() {
  local name="pmctl pm run: propagates wait failure exit code"
  should_run "$name" || return 0
  # shellcheck source=runtime/lib/pmctl-pm.sh
  . "$REPO_ROOT/runtime/lib/pmctl-pm.sh"
  local out="$tmp_root/wait-failure.out" code=0
  pmctl_validate_brief() { return 0; }
  pmctl_dispatch_run() { printf 'run-test-wait-failure\n'; }
  pmctl_dispatch_wait() { [[ "${1:-}" == "$REPO_ROOT" ]] || return 97; return 42; }
  pmctl_pm_run "$REPO_ROOT" --adapter codex --brief-file /tmp/brief-test.md --cd "$REPO_ROOT" --json > "$out" || code=$?
  if [[ "$code" -eq 42 ]] && jq -e '.run_id == "run-test-wait-failure" and .wait_exit_code == 42' "$out" >/dev/null; then
    pass "$name"
  else
    fail "$name" "expected wait exit 42, got $code out=$(<"$out")"
  fi
}

# Behavior: JSON mode owns stdout even when the shared wait primitive emits an advisory record.
# Steps: stub wait stdout; invoke JSON mode; assert the complete output remains parseable JSON.
case_run_json_suppresses_wait_stdout() {
  local name="pmctl pm run: JSON output suppresses wait stdout"
  should_run "$name" || return 0
  # shellcheck source=runtime/lib/pmctl-pm.sh
  . "$REPO_ROOT/runtime/lib/pmctl-pm.sh"
  local out="$tmp_root/json-wait-stdout.out" code=0
  pmctl_validate_brief() { return 0; }
  pmctl_dispatch_run() { printf 'run-test-json-output\n'; }
  pmctl_dispatch_wait() { printf 'advisory wait output\n'; return 0; }
  pmctl_pm_run "$REPO_ROOT" --adapter codex --brief-file /tmp/brief-test.md --cd "$REPO_ROOT" --json > "$out" || code=$?
  if [[ "$code" -eq 0 ]] && jq -e '.run_id == "run-test-json-output" and .wait_exit_code == 0' "$out" >/dev/null; then
    pass "$name"
  else
    fail "$name" "expected parseable JSON, got $code out=$(<"$out")"
  fi
}

# Behavior: run forwards optional adapter flags unchanged into the shared detached dispatcher.
# Steps: stub launch and wait; invoke model, isolation, and no-auto-pack options; assert all appear in launch argv.
case_run_forwards_optional_dispatch_flags() {
  local name="pmctl pm run: forwards model isolation and no-auto-pack"
  should_run "$name" || return 0
  # shellcheck source=runtime/lib/pmctl-pm.sh
  . "$REPO_ROOT/runtime/lib/pmctl-pm.sh"
  local trace="$tmp_root/optional-flags-trace" code=0
  pmctl_validate_brief() { return 0; }
  pmctl_dispatch_run() { printf '%s\n' "$*" > "$trace"; printf 'run-test-optional-flags\n'; }
  pmctl_dispatch_wait() { [[ "${1:-}" == "$REPO_ROOT" ]] || return 97; return 0; }
  pmctl_pm_run "$REPO_ROOT" --adapter codex --brief-file /tmp/brief-test.md --cd "$REPO_ROOT" \
    --model gpt-5.5 --isolation read-only --no-auto-pack >/dev/null || code=$?
  local args="$(<"$trace")"
  if [[ "$code" -eq 0 ]] \
    && [[ "$args" == *"--model gpt-5.5"* ]] \
    && [[ "$args" == *"--isolation read-only"* ]] \
    && [[ "$args" == *"--no-auto-pack"* ]]; then
    pass "$name"
  else
    fail "$name" "code=$code launch_args=$args"
  fi
}

case_prepare_emits_batch_contract
case_prepare_emits_human_contract
case_prepare_defaults_to_caller_git_root
case_prepare_degrades_without_backlog
case_prepare_repo_context_marker_round_trip
case_prepare_deduplicates_focus_tickets
case_prepare_rejects_empty_request
case_prepare_rejects_non_git_workdir
case_prepare_hydrates_shared_memory
case_prepare_emits_cross_host_memory_provenance
case_prepare_native_conflict_stays_auxiliary
case_prepare_rejects_invalid_explicit_memory
case_prepare_reports_no_memory_hits
case_prepare_reports_memory_query_failure
case_prepare_bounds_memory_pack_without_corruption
case_prepare_human_emits_hydrated_memory_contract
case_prepare_human_emits_unavailable_memory_contract
case_bound_memory_pack_rejects_oversized_envelope
case_prepare_invalid_memory_cleans_snapshot
case_unknown_subcommand_shows_usage
case_run_uses_validate_detached_wait
case_run_emits_human_contract
case_run_carries_memory_provenance_into_dispatch_brief
case_run_rejects_invalid_brief
case_run_requires_adapter_brief_and_workdir
case_run_rejects_non_git_workdir
case_run_rejects_invalid_dispatch_id
case_run_propagates_wait_failure
case_run_json_suppresses_wait_stdout
case_run_forwards_optional_dispatch_flags
th_summary
