#!/usr/bin/env bash
# Regression tests for `pmctl memory doctor` (runtime/lib/pmctl-memory.sh).
# shellcheck disable=SC2154  # tmp_root supplied by sourced test-harness
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PMCTL="$REPO_ROOT/cli/pmctl"

# shellcheck source=tests/lib/test-harness.sh
# shellcheck disable=SC1091
. "$SCRIPT_DIR/../lib/test-harness.sh"
# shellcheck source=runtime/lib/memory.sh
# shellcheck disable=SC1091
. "$REPO_ROOT/runtime/lib/memory.sh"
# shellcheck source=tests/lib/test-memory-config-fixtures.sh
# shellcheck disable=SC1091
. "$SCRIPT_DIR/../lib/test-memory-config-fixtures.sh"
th_init "$@"

# Operator config is external state. Every case starts isolated and opts into a
# fixture config explicitly when exercising project-scoped selection.
export PM_DISPATCH_CONFIG_FILE="$tmp_root/no-operator-config"
unset PM_MEMORY_DIR PM_CFG_MEMORY_DIR PM_CFG_MEMORY_DIR_INVALID PM_CFG_MEMORY_CONFIG_STATUS

# Resolve the developer's live project-memory dir so cases can assert no fixture
# run ever lands there. Every case operates on an isolated fixture under
# $tmp_root via a fake CLAUDE_CONFIG_DIR.
#
# This is deliberately NOT used as a content-fingerprint mutation guard. Such a
# guard cannot tell "a case in this suite wrote there" from "an unrelated
# process did", and the prompt-injection hook writes the live usage sidecar on
# every turn — so the assertion failed for reasons the suite does not control,
# blocking on other people's activity. Read-only behavior is proven against
# isolated fixtures instead (case_memory_doctor_is_read_only,
# case_memory_stats_is_read_only), and resolution safety by
# case_memory_commands_resolve_only_fixture_dirs.
_LIVE_MEM_DIR="$(find_memory_dir "$REPO_ROOT" 2>/dev/null || true)"

# ── Helpers ────────────────────────────────────────────────────────────────────

# Encode a repo path into the CLAUDE config "projects" dir key.
# Mirrors runtime/lib/memory.sh encode_path: "/a/b" → "-a-b".
mem_encode_path() {
  printf '%s' "-${1#/}" | tr '/' '-'
}

# Create an isolated fixture: a fake CLAUDE_CONFIG_DIR whose projects/<repo>/memory
# dir is what find_memory_dir resolves for $repo. Echoes the memory dir path.
make_fixture_memory() {
  local cfg="$1" repo="$2"
  local mdir
  mdir="$cfg/projects/$(mem_encode_path "$repo")/memory"
  mkdir -p "$mdir"
  printf '%s' "$mdir"
}

# Write a card carrying all required frontmatter fields (compliant card).
# $1 = path, $2 = name. repo_refs is empty so the card is fresh on every check.
write_compliant_card() {
  local path="$1" cardname="$2"
  cat > "$path" <<MD
---
name: $cardname
topics:
  - x
priority: normal
status: active
updated_at: "2026-06-23"
repo_refs: []
---
body
MD
}

# Run doctor against a fixture; writes JSON to $1, returns doctor exit code.
run_doctor_json() {
  local out="$1" cfg="$2" repo="$3"; shift 3
  local status=0
  CLAUDE_CONFIG_DIR="$cfg" "$PMCTL" memory doctor --repo-root "$repo" --json "$@" \
    > "$out" 2>/dev/null || status=$?
  return "$status"
}

# Parser-backed JSON assertion (spike a3 requires jq -e, not substring matching).
# Returns 0 when the jq filter is truthy; calls fail() and returns 1 otherwise.
_HAVE_JQ=0
command -v jq >/dev/null 2>&1 && _HAVE_JQ=1
assert_jq() {
  local name="$1" file="$2" filter="$3"
  if [[ "$_HAVE_JQ" -ne 1 ]]; then
    return 0  # jq absent: skip parser-backed check, substring asserts still run
  fi
  if jq -e "$filter" "$file" >/dev/null 2>&1; then
    return 0
  fi
  fail "$name" "assert_jq: filter failed [$filter] on $(cat "$file" 2>/dev/null)"
  return 1
}

# ── Test cases ─────────────────────────────────────────────────────────────────

# Behavior: strict resolution reports an explicit cross-host memory directory and stable project identity.
# Steps: create a git repo plus external memory dir; resolve through PM_MEMORY_DIR; assert the JSON contract.
case_memory_resolve_env_contract() {
  local name="pmctl memory resolve: env override emits resolved contract"
  should_run "$name" || return 0
  local repo="$tmp_root/resolve-env-repo" mdir="$tmp_root/shared-memory" out="$tmp_root/resolve-env.json" status=0
  mkdir -p "$repo" "$mdir"
  git -C "$repo" init -q
  PM_MEMORY_DIR="$mdir" "$PMCTL" memory resolve --repo-root "$repo" --json > "$out" 2>/dev/null || status=$?
  if [[ "$status" -eq 0 ]] && jq -e --arg repo "$repo" --arg mdir "$mdir" \
    '.status == "resolved" and .repo_root == $repo and .memory_dir == $mdir and .resolution_source == "env" and (.project_key | length) > 0 and .readable == true and .writable == true' "$out" >/dev/null; then
    pass "$name"
  else
    fail "$name" "status=$status out=$(<"$out")"
  fi
}

# Behavior: an unavailable explicit path never falls through to an existing Claude legacy memory.
# Steps: create legacy memory, point PM_MEMORY_DIR at a missing path, and assert invalid-explicit exit 3.
case_memory_resolve_invalid_explicit_no_fallback() {
  local name="pmctl memory resolve: invalid explicit path fails without legacy fallback"
  should_run "$name" || return 0
  local repo="$tmp_root/resolve-invalid-repo" cfg="$tmp_root/resolve-invalid-cfg" missing="$tmp_root/missing-memory" out="$tmp_root/resolve-invalid.json" status=0 legacy
  mkdir -p "$repo"
  git -C "$repo" init -q
  legacy="$(make_fixture_memory "$cfg" "$repo")"
  PM_MEMORY_DIR="$missing" CLAUDE_CONFIG_DIR="$cfg" "$PMCTL" memory resolve --repo-root "$repo" --json > "$out" 2>/dev/null || status=$?
  if [[ "$status" -eq 3 ]] \
    && jq -e '.status == "invalid-explicit" and .resolution_source == "env" and .memory_dir == null' "$out" >/dev/null \
    && [[ -d "$legacy" ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$(<"$out")"
  fi
}

# Behavior: without an override, strict resolution preserves Claude project-memory discovery.
# Steps: create only the legacy path, resolve it, and assert source=legacy.
case_memory_resolve_legacy_compatibility() {
  local name="pmctl memory resolve: unset override preserves legacy discovery"
  should_run "$name" || return 0
  local repo="$tmp_root/resolve-legacy-repo" cfg="$tmp_root/resolve-legacy-cfg" out="$tmp_root/resolve-legacy.json" status=0 mdir
  mkdir -p "$repo"
  git -C "$repo" init -q
  mdir="$(make_fixture_memory "$cfg" "$repo")"
  (unset PM_MEMORY_DIR; CLAUDE_CONFIG_DIR="$cfg" "$PMCTL" memory resolve --repo-root "$repo" --json) > "$out" 2>/dev/null || status=$?
  if [[ "$status" -eq 0 ]] && jq -e --arg mdir "$mdir" \
    '.status == "resolved" and .resolution_source == "legacy" and .memory_dir == $mdir' "$out" >/dev/null; then
    pass "$name"
  else
    fail "$name" "status=$status out=$(<"$out")"
  fi
}

# Behavior: strict resolution honors dispatch.memory_dir as the shared cross-host location.
# Steps: write an isolated config, resolve an existing directory, and assert source=config.
case_memory_resolve_config_contract() {
  local name="pmctl memory resolve: config override emits resolved contract"
  should_run "$name" || return 0
  local repo="$tmp_root/resolve-config-repo" mdir="$tmp_root/config-memory" config="$tmp_root/resolve-config.conf" out="$tmp_root/resolve-config.json" status=0
  mkdir -p "$repo" "$mdir"
  git -C "$repo" init -q
  write_project_memory_config "$config" "$repo" "$mdir"
  (unset PM_MEMORY_DIR; PM_DISPATCH_CONFIG_FILE="$config" "$PMCTL" memory resolve --repo-root "$repo" --json) > "$out" 2>/dev/null || status=$?
  if [[ "$status" -eq 0 ]] && jq -e --arg mdir "$mdir" \
    '.status == "resolved" and .resolution_source == "config" and .memory_dir == $mdir' "$out" >/dev/null; then
    pass "$name"
  else
    fail "$name" "status=$status out=$(<"$out")"
  fi
}

# Behavior: PM_MEMORY_DIR remains the highest-priority explicit selector.
# Steps: set env and config to different valid dirs; assert env wins deterministically.
case_memory_resolve_env_outranks_config() {
  local name="pmctl memory resolve: env override outranks config"
  should_run "$name" || return 0
  local repo="$tmp_root/resolve-precedence-repo" env_dir="$tmp_root/precedence-env-memory" cfg_dir="$tmp_root/precedence-config-memory" config="$tmp_root/resolve-precedence.conf" out="$tmp_root/resolve-precedence.json" status=0
  mkdir -p "$repo" "$env_dir" "$cfg_dir"
  git -C "$repo" init -q
  write_project_memory_config "$config" "$repo" "$cfg_dir"
  PM_MEMORY_DIR="$env_dir" PM_DISPATCH_CONFIG_FILE="$config" "$PMCTL" memory resolve --repo-root "$repo" --json > "$out" 2>/dev/null || status=$?
  if [[ "$status" -eq 0 ]] && jq -e --arg env_dir "$env_dir" \
    '.resolution_source == "env" and .memory_dir == $env_dir' "$out" >/dev/null; then
    pass "$name"
  else
    fail "$name" "status=$status out=$(<"$out")"
  fi
}

# Behavior: an unavailable config-selected directory does not fall through to Claude legacy memory.
# Steps: create legacy memory plus a missing configured directory; assert source=config and exit 3.
case_memory_resolve_invalid_config_no_fallback() {
  local name="pmctl memory resolve: invalid config path fails without legacy fallback"
  should_run "$name" || return 0
  local repo="$tmp_root/resolve-bad-config-repo" cfg="$tmp_root/resolve-bad-config-claude" missing="$tmp_root/missing-config-memory" config="$tmp_root/resolve-bad-config.conf" out="$tmp_root/resolve-bad-config.json" status=0 legacy
  mkdir -p "$repo"
  git -C "$repo" init -q
  legacy="$(make_fixture_memory "$cfg" "$repo")"
  write_project_memory_config "$config" "$repo" "$missing"
  (unset PM_MEMORY_DIR; PM_DISPATCH_CONFIG_FILE="$config" CLAUDE_CONFIG_DIR="$cfg" "$PMCTL" memory resolve --repo-root "$repo" --json) > "$out" 2>/dev/null || status=$?
  if [[ "$status" -eq 3 ]] \
    && jq -e '.status == "invalid-explicit" and .resolution_source == "config" and .memory_dir == null' "$out" >/dev/null \
    && [[ -d "$legacy" ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$(<"$out")"
  fi
}

# Behavior: relative env/config selections are rejected because they vary by host cwd.
# Steps: exercise both explicit sources and assert the same absolute-path diagnostic.
case_memory_resolve_rejects_relative_explicit_paths() {
  local name="pmctl memory resolve: relative explicit paths are invalid"
  should_run "$name" || return 0
  local repo="$tmp_root/resolve-relative-repo" config="$tmp_root/resolve-relative.conf" env_out="$tmp_root/resolve-relative-env.json" cfg_out="$tmp_root/resolve-relative-config.json" env_status=0 cfg_status=0
  mkdir -p "$repo"
  git -C "$repo" init -q
  PM_MEMORY_DIR="relative-memory" "$PMCTL" memory resolve --repo-root "$repo" --json > "$env_out" 2>/dev/null || env_status=$?
  write_project_memory_config "$config" "$repo" relative-memory
  (unset PM_MEMORY_DIR; PM_DISPATCH_CONFIG_FILE="$config" "$PMCTL" memory resolve --repo-root "$repo" --json) > "$cfg_out" 2>/dev/null || cfg_status=$?
  if [[ "$env_status" -eq 3 && "$cfg_status" -eq 3 ]] \
    && jq -e '.resolution_source == "env" and .status == "invalid-explicit" and (.reason | contains("absolute path"))' "$env_out" >/dev/null \
    && jq -e '.resolution_source == "config" and .status == "invalid-explicit" and (.reason | contains("absolute path"))' "$cfg_out" >/dev/null; then
    pass "$name"
  else
    fail "$name" "env_status=$env_status cfg_status=$cfg_status env=$(<"$env_out") cfg=$(<"$cfg_out")"
  fi
}

# Behavior: no override and no legacy directory is a distinct unavailable result.
# Steps: resolve an isolated git repo against an empty Claude config and assert exit 1/status unavailable.
case_memory_resolve_unavailable() {
  local name="pmctl memory resolve: no memory reports unavailable"
  should_run "$name" || return 0
  local repo="$tmp_root/resolve-none-repo" cfg="$tmp_root/resolve-none-cfg" out="$tmp_root/resolve-none.json" status=0
  mkdir -p "$repo" "$cfg"
  git -C "$repo" init -q
  (unset PM_MEMORY_DIR; PM_DISPATCH_CONFIG_FILE="$tmp_root/no-config" CLAUDE_CONFIG_DIR="$cfg" "$PMCTL" memory resolve --repo-root "$repo" --json) > "$out" 2>/dev/null || status=$?
  if [[ "$status" -eq 1 ]] && jq -e \
    '.status == "unavailable" and .resolution_source == "none" and .memory_dir == null' "$out" >/dev/null; then
    pass "$name"
  else
    fail "$name" "status=$status out=$(<"$out")"
  fi
}

# Behavior: the strict resolver rejects a repo root outside a git worktree.
# Steps: pass the harness temp root and assert the documented usage error.
case_memory_resolve_rejects_non_git_root() {
  local name="pmctl memory resolve: non-git repo root exits 2"
  should_run "$name" || return 0
  local non_git="$tmp_root/resolve-non-git" out="$tmp_root/resolve-non-git.out" status=0
  mkdir -p "$non_git"
  "$PMCTL" memory resolve --repo-root "$non_git" --json > "$out" 2>&1 || status=$?
  if [[ "$status" -eq 2 ]] && grep -q 'must be inside a git worktree' "$out"; then
    pass "$name"
  else
    fail "$name" "status=$status out=$(<"$out")"
  fi
}

case_memory_doctor_clean_fixture() {
  local name="pmctl memory doctor: clean fixture → exit 0, issues_count 0, schema_version 1"
  should_run "$name" || return 0

  local cfg="$tmp_root/clean-cfg" repo="$tmp_root/clean-repo"
  mkdir -p "$repo"
  local mdir; mdir="$(make_fixture_memory "$cfg" "$repo")"
  cat > "$mdir/MEMORY.md" <<'MD'
# Memory Index
- [alpha](card_alpha.md) — hook text one
- [beta](card_beta.md) — hook text two
MD
  write_compliant_card "$mdir/card_alpha.md" alpha
  write_compliant_card "$mdir/card_beta.md" beta

  local out="$tmp_root/clean.json" status=0
  run_doctor_json "$out" "$cfg" "$repo" || status=$?

  if ! assert_exit "$name" "$status" 0; then
    fail "$name" "expected 0 but got $status: $(<"$out")"
    return 0
  fi
  if ! assert_file_contains "$name" "$out" '"schema_version":1'; then return 0; fi
  if ! assert_file_contains "$name" "$out" '"issues_count":0'; then return 0; fi
  if ! assert_file_contains "$name" "$out" '"entry_count":2'; then return 0; fi
  if ! assert_file_contains "$name" "$out" '"cards_missing_fields":[]'; then return 0; fi
  # finding #2: assert memory_dir + memory_bytes schema fields directly.
  if ! assert_file_contains "$name" "$out" "\"memory_dir\":\"$mdir\""; then return 0; fi
  if ! assert_file_matches "$name" "$out" '"memory_bytes":[1-9][0-9]*'; then return 0; fi
  # Parser-backed schema assertions (spike a3): types + exit-code contract.
  if ! assert_jq "$name" "$out" '.schema_version == 1'; then return 0; fi
  if ! assert_jq "$name" "$out" '(.dead_links | type) == "array"'; then return 0; fi
  if ! assert_jq "$name" "$out" '(.stale_repo_refs | type) == "array"'; then return 0; fi
  if ! assert_jq "$name" "$out" '(.cards_missing_fields | type) == "array"'; then return 0; fi
  if ! assert_jq "$name" "$out" '.issues_count == 0'; then return 0; fi
  pass "$name"
}

case_memory_doctor_dead_link() {
  local name="pmctl memory doctor: MEMORY.md link to missing file → dead_links + exit 1"
  should_run "$name" || return 0

  local cfg="$tmp_root/dead-cfg" repo="$tmp_root/dead-repo"
  mkdir -p "$repo"
  local mdir; mdir="$(make_fixture_memory "$cfg" "$repo")"
  cat > "$mdir/MEMORY.md" <<'MD'
# Memory Index
- [present](card_present.md) — present hook
- [gone](card_gone.md) — gone hook
MD
  printf -- '---\nname: present\n---\nbody\n' > "$mdir/card_present.md"
  # card_gone.md intentionally absent

  local out="$tmp_root/dead.json" status=0
  run_doctor_json "$out" "$cfg" "$repo" || status=$?

  if ! assert_exit "$name" "$status" 1; then return 0; fi
  if ! assert_file_contains "$name" "$out" '"dead_links":["card_gone.md"]'; then return 0; fi
  pass "$name"
}

case_memory_doctor_orphan_card() {
  local name="pmctl memory doctor: unreferenced card → orphan_cards (MEMORY.md excluded)"
  should_run "$name" || return 0

  local cfg="$tmp_root/orphan-cfg" repo="$tmp_root/orphan-repo"
  mkdir -p "$repo"
  local mdir; mdir="$(make_fixture_memory "$cfg" "$repo")"
  cat > "$mdir/MEMORY.md" <<'MD'
# Memory Index
- [linked](card_linked.md) — linked hook
MD
  printf -- '---\nname: linked\n---\nbody\n' > "$mdir/card_linked.md"
  printf -- '---\nname: orphan\n---\nbody\n' > "$mdir/card_orphan.md"

  local out="$tmp_root/orphan.json" status=0
  run_doctor_json "$out" "$cfg" "$repo" || status=$?

  if ! assert_exit "$name" "$status" 1; then return 0; fi
  if ! assert_file_contains "$name" "$out" '"orphan_cards":["card_orphan.md"]'; then return 0; fi
  # MEMORY.md must never be reported as an orphan.
  local body; body="$(<"$out")"
  if [[ "$body" == *'MEMORY.md'* ]]; then
    fail "$name" "MEMORY.md should be excluded from orphan_cards: $body"
    return 0
  fi
  pass "$name"
}

case_memory_doctor_duplicate_hooks() {
  local name="pmctl memory doctor: same hook text on ≥2 index lines → duplicate_hooks"
  should_run "$name" || return 0

  local cfg="$tmp_root/dup-cfg" repo="$tmp_root/dup-repo"
  mkdir -p "$repo"
  local mdir; mdir="$(make_fixture_memory "$cfg" "$repo")"
  cat > "$mdir/MEMORY.md" <<'MD'
# Memory Index
- [one](card_one.md) — shared hook line
- [two](card_two.md) — shared hook line
- [three](card_three.md) — unique hook line
MD
  printf -- '---\nname: one\n---\n' > "$mdir/card_one.md"
  printf -- '---\nname: two\n---\n' > "$mdir/card_two.md"
  printf -- '---\nname: three\n---\n' > "$mdir/card_three.md"

  local out="$tmp_root/dup.json" status=0
  run_doctor_json "$out" "$cfg" "$repo" || status=$?

  if ! assert_exit "$name" "$status" 1; then return 0; fi
  if ! assert_file_contains "$name" "$out" '"duplicate_hooks":["shared hook line"]'; then return 0; fi
  pass "$name"
}

case_memory_doctor_repo_refs_fresh_not_flagged() {
  local name="pmctl memory doctor: fresh path:/fn:/flag: refs are NOT flagged (negative control)"
  should_run "$name" || return 0

  local cfg="$tmp_root/fresh-cfg" repo="$tmp_root/fresh-repo"
  mkdir -p "$repo/scripts"
  # Real targets so every ref kind verifies fresh.
  printf 'hello\n' > "$repo/agents-file.md"
  printf 'g_audit() {\n  :\n}\n' > "$repo/scripts/lib-frame.sh"
  printf 'use --executor here\n' > "$repo/scripts/flagholder.sh"

  local mdir; mdir="$(make_fixture_memory "$cfg" "$repo")"
  cat > "$mdir/MEMORY.md" <<'MD'
# Memory Index
- [refcard](card_refs.md) — ref card hook
MD
  cat > "$mdir/card_refs.md" <<'MD'
---
name: refcard
metadata:
  type: feedback
topics:
  - x
priority: normal
status: active
updated_at: "2026-06-23"
repo_refs:
  - path:agents-file.md
  - fn:scripts/lib-frame.sh#g_audit
  - flag:pmctl gate run --executor codex
---
body
MD

  local out="$tmp_root/fresh.json" status=0
  run_doctor_json "$out" "$cfg" "$repo" || status=$?

  if ! assert_exit "$name" "$status" 0; then
    fail "$name" "expected 0 (no issues) but got $status: $(<"$out")"
    return 0
  fi
  if ! assert_file_contains "$name" "$out" '"stale_repo_refs":[]'; then return 0; fi
  pass "$name"
}

case_memory_doctor_repo_refs_stale_flagged() {
  local name="pmctl memory doctor: stale path:/fn:/flag: refs ARE flagged with {card,ref} (positive control)"
  should_run "$name" || return 0

  local cfg="$tmp_root/stale-cfg" repo="$tmp_root/stale-repo"
  mkdir -p "$repo/scripts"
  # Symbol present under a DIFFERENT name → fn: with old name is stale.
  printf 'g_audit_renamed() {\n  :\n}\n' > "$repo/scripts/lib-frame.sh"
  # No file with --absentflag token anywhere under scripts/ → flag: stale.
  printf 'nothing here\n' > "$repo/scripts/other.sh"

  local mdir; mdir="$(make_fixture_memory "$cfg" "$repo")"
  cat > "$mdir/MEMORY.md" <<'MD'
# Memory Index
- [refcard](card_refs.md) — ref card hook
MD
  cat > "$mdir/card_refs.md" <<'MD'
---
name: refcard
repo_refs:
  - path:deleted/gone.sh
  - fn:scripts/lib-frame.sh#g_audit
  - flag:pmctl thing --absentflag
---
body
MD

  local out="$tmp_root/stale.json" status=0
  run_doctor_json "$out" "$cfg" "$repo" || status=$?

  if ! assert_exit "$name" "$status" 1; then
    fail "$name" "expected 1 (issues) but got $status: $(<"$out")"
    return 0
  fi
  # All three stale kinds present, each carrying card + ref.
  if ! assert_file_contains "$name" "$out" '{"card":"card_refs.md","ref":"path:deleted/gone.sh"}'; then return 0; fi
  if ! assert_file_contains "$name" "$out" '{"card":"card_refs.md","ref":"fn:scripts/lib-frame.sh#g_audit"}'; then return 0; fi
  if ! assert_file_contains "$name" "$out" '{"card":"card_refs.md","ref":"flag:pmctl thing --absentflag"}'; then return 0; fi
  pass "$name"
}

case_memory_doctor_repo_refs_flow_style() {
  local name="pmctl memory doctor: flow-style repo_refs [a, b] are parsed + staleness-checked"
  should_run "$name" || return 0

  local cfg="$tmp_root/flow-cfg" repo="$tmp_root/flow-repo"
  mkdir -p "$repo"
  printf 'present\n' > "$repo/present.md"  # path:present.md fresh; path:gone.md stale

  local mdir; mdir="$(make_fixture_memory "$cfg" "$repo")"
  cat > "$mdir/MEMORY.md" <<'MD'
# Memory Index
- [flowcard](card_flow.md) — flow card hook
MD
  # Flow-style YAML lists for both topics and repo_refs.
  cat > "$mdir/card_flow.md" <<'MD'
---
name: flowcard
topics: [x]
priority: normal
status: active
updated_at: "2026-06-23"
repo_refs: [path:present.md, path:gone.md]
---
body
MD

  local out="$tmp_root/flow.json" status=0
  run_doctor_json "$out" "$cfg" "$repo" || status=$?

  if ! assert_exit "$name" "$status" 1; then
    fail "$name" "expected 1 (one stale flow ref) but got $status: $(<"$out")"
    return 0
  fi
  # The stale flow item is detected; the card is NOT flagged for missing fields
  # (flow-style topics/repo_refs keys are recognized).
  if ! assert_file_contains "$name" "$out" '{"card":"card_flow.md","ref":"path:gone.md"}'; then return 0; fi
  if ! assert_file_contains "$name" "$out" '"cards_missing_fields":[]'; then return 0; fi
  local body; body="$(<"$out")"
  if [[ "$body" == *'path:present.md'* ]]; then
    fail "$name" "fresh flow ref path:present.md must not be flagged stale: $body"
    return 0
  fi
  pass "$name"
}

case_memory_doctor_episodes_bytes() {
  local name="pmctl memory doctor: episodes.jsonl present → bytes>0; absent → 0"
  should_run "$name" || return 0

  # present
  local cfg="$tmp_root/ep-cfg" repo="$tmp_root/ep-repo"
  mkdir -p "$repo"
  local mdir; mdir="$(make_fixture_memory "$cfg" "$repo")"
  printf '# Memory Index\n' > "$mdir/MEMORY.md"
  printf '{"ts":"2026-06-23","summary":"x"}\n' > "$mdir/episodes.jsonl"
  local out="$tmp_root/ep.json" status=0
  run_doctor_json "$out" "$cfg" "$repo" || status=$?
  if [[ "$status" -ne 0 ]]; then fail "$name" "present case exit $status"; return 0; fi
  local present; present="$(<"$out")"
  if [[ "$present" == *'"episodes_bytes":0'* ]]; then
    fail "$name" "episodes present but reported 0: $present"; return 0
  fi

  # absent
  local cfg2="$tmp_root/noep-cfg" repo2="$tmp_root/noep-repo"
  mkdir -p "$repo2"
  local mdir2; mdir2="$(make_fixture_memory "$cfg2" "$repo2")"
  printf '# Memory Index\n' > "$mdir2/MEMORY.md"
  local out2="$tmp_root/noep.json" status2=0
  run_doctor_json "$out2" "$cfg2" "$repo2" || status2=$?
  if [[ "$status2" -ne 0 ]]; then fail "$name" "absent case exit $status2"; return 0; fi
  if ! assert_file_contains "$name" "$out2" '"episodes_bytes":0'; then return 0; fi
  pass "$name"
}

case_memory_doctor_unknown_flag_exit2() {
  local name="pmctl memory doctor: unknown flag → exit 2"
  should_run "$name" || return 0

  local cfg="$tmp_root/uf-cfg" repo="$tmp_root/uf-repo"
  mkdir -p "$repo"
  local mdir; mdir="$(make_fixture_memory "$cfg" "$repo")"
  printf '# Memory Index\n' > "$mdir/MEMORY.md"

  local status=0
  CLAUDE_CONFIG_DIR="$cfg" "$PMCTL" memory doctor --repo-root "$repo" --frobnicate \
    >/dev/null 2>&1 || status=$?
  if assert_exit "$name" "$status" 2; then pass "$name"; fi
}

case_memory_doctor_repo_root_missing_operand_exit2() {
  local name="pmctl memory doctor: --repo-root without a value → exit 2 + error"
  should_run "$name" || return 0

  local err="$tmp_root/rr-missing.err" status=0
  # --repo-root is the last token, so no operand follows it.
  "$PMCTL" memory doctor --repo-root >/dev/null 2>"$err" || status=$?
  if ! assert_exit "$name" "$status" 2; then return 0; fi
  if ! assert_file_contains "$name" "$err" '--repo-root requires a value'; then return 0; fi
  pass "$name"
}

case_memory_doctor_help_exit0() {
  local name="pmctl memory doctor: --help → exit 0 + usage contract"
  should_run "$name" || return 0

  local out="$tmp_root/help.out" status=0
  "$PMCTL" memory doctor --help >"$out" 2>&1 || status=$?
  if ! assert_exit "$name" "$status" 0; then
    fail "$name" "expected 0 but got $status: $(<"$out")"
    return 0
  fi
  if ! assert_file_contains "$name" "$out" 'Usage: pmctl memory doctor'; then return 0; fi
  if ! assert_file_contains "$name" "$out" '--json'; then return 0; fi
  if ! assert_file_contains "$name" "$out" '--repo-root'; then return 0; fi
  if ! assert_file_contains "$name" "$out" '0 healthy, 1 issues found, 2 usage error'; then return 0; fi
  pass "$name"
}

case_memory_doctor_repo_root_override() {
  local name="pmctl memory doctor: --repo-root resolves repo_refs against the given root"
  should_run "$name" || return 0

  # Memory dir keyed by repoA; refs verified against repoA via --repo-root.
  local cfg="$tmp_root/ovr-cfg" repoA="$tmp_root/ovr-repoA"
  mkdir -p "$repoA"
  printf 'present\n' > "$repoA/target.md"
  local mdir; mdir="$(make_fixture_memory "$cfg" "$repoA")"
  cat > "$mdir/MEMORY.md" <<'MD'
# Memory Index
- [refcard](card_refs.md) — ref card hook
MD
  cat > "$mdir/card_refs.md" <<'MD'
---
name: refcard
topics:
  - x
priority: normal
status: active
updated_at: "2026-06-23"
repo_refs:
  - path:target.md
---
body
MD

  # With repo-root=repoA, target.md exists → fresh → exit 0.
  local out="$tmp_root/ovr.json" status=0
  run_doctor_json "$out" "$cfg" "$repoA" || status=$?
  if ! assert_exit "$name" "$status" 0; then
    fail "$name" "repoA root should resolve target.md fresh, got $status: $(<"$out")"
    return 0
  fi
  if ! assert_file_contains "$name" "$out" '"stale_repo_refs":[]'; then return 0; fi
  pass "$name"
}

case_memory_doctor_missing_required_fields() {
  local name="pmctl memory doctor: card missing required frontmatter → cards_missing_fields + exit 1"
  should_run "$name" || return 0

  local cfg="$tmp_root/miss-cfg" repo="$tmp_root/miss-repo"
  mkdir -p "$repo"
  local mdir; mdir="$(make_fixture_memory "$cfg" "$repo")"
  cat > "$mdir/MEMORY.md" <<'MD'
# Memory Index
- [full](card_full.md) — full hook
- [bare](card_bare.md) — bare hook
MD
  # Compliant card: not flagged. Bare card: only name → all 5 fields missing.
  write_compliant_card "$mdir/card_full.md" full
  printf -- '---\nname: bare\n---\nbody\n' > "$mdir/card_bare.md"

  local out="$tmp_root/miss.json" status=0
  run_doctor_json "$out" "$cfg" "$repo" || status=$?

  if ! assert_exit "$name" "$status" 1; then
    fail "$name" "expected 1 (issues) but got $status: $(<"$out")"
    return 0
  fi
  # The bare card is flagged with all required fields; the compliant card is not.
  if ! assert_file_contains "$name" "$out" '{"card":"card_bare.md","missing":["topics","priority","status","updated_at","repo_refs"]}'; then return 0; fi
  local body; body="$(<"$out")"
  if [[ "$body" == *'card_full.md'* ]]; then
    fail "$name" "compliant card_full.md must not appear in cards_missing_fields: $body"
    return 0
  fi
  pass "$name"
}

case_memory_doctor_no_memory_dir() {
  local name="pmctl memory doctor: no memory dir → empty healthy report + exit 0"
  should_run "$name" || return 0

  # cfg has NO projects/<repo>/memory dir → find_memory_dir resolves nothing.
  local cfg="$tmp_root/nodir-cfg" repo="$tmp_root/nodir-repo"
  mkdir -p "$cfg/projects" "$repo"

  local out="$tmp_root/nodir.json" status=0
  run_doctor_json "$out" "$cfg" "$repo" || status=$?

  if ! assert_exit "$name" "$status" 0; then
    fail "$name" "expected 0 for absent memory dir but got $status: $(<"$out")"
    return 0
  fi
  if ! assert_file_contains "$name" "$out" '"memory_dir":""'; then return 0; fi
  if ! assert_jq "$name" "$out" '.schema_version == 1 and .issues_count == 0 and .entry_count == 0'; then return 0; fi
  if ! assert_jq "$name" "$out" '(.dead_links | length) == 0 and (.cards_missing_fields | length) == 0'; then return 0; fi
  pass "$name"
}

case_memory_doctor_config_memory_dir_override() {
  local name="pmctl memory doctor: project-scoped config resolves an override-only memory dir"
  should_run "$name" || return 0

  local cfg="$tmp_root/docover-cfg" repo="$tmp_root/docover-repo"
  local override="$tmp_root/docover-override" fakehome="$tmp_root/docover-home"
  # cfg has NO projects/<repo>/memory dir — a hit proves resolution went
  # through dispatch.memory_dir, not the CLAUDE_CONFIG_DIR walk.
  mkdir -p "$cfg/projects" "$repo" "$override" "$fakehome/.pm-dispatch"
  write_compliant_card "$override/feedback_test.md" test-card
  printf '# Memory Index\n- [test](feedback_test.md) — hook\n' > "$override/MEMORY.md"
  write_project_memory_config "$fakehome/.pm-dispatch/config" "$repo" "$override"

  local out="$tmp_root/docover.json" status=0
  PM_DISPATCH_CONFIG_FILE="$fakehome/.pm-dispatch/config" CLAUDE_CONFIG_DIR="$cfg" "$PMCTL" memory doctor --repo-root "$repo" --json \
    > "$out" 2>/dev/null || status=$?

  if ! assert_exit "$name" "$status" 0; then return 0; fi
  if ! assert_jq "$name" "$out" ".memory_dir == \"$override\""; then return 0; fi
  pass "$name"
}

case_memory_doctor_repo_refs_unsafe_path() {
  local name="pmctl memory doctor: path: ref escaping the repo (../ or absolute) → stale, not fresh"
  should_run "$name" || return 0

  local cfg="$tmp_root/unsafe-cfg" repo="$tmp_root/unsafe-repo"
  mkdir -p "$repo"
  # A real file ABOVE the repo root: a naive `test -f "$repo/../escape.md"` would
  # find it and call the ref fresh. The grammar is repo-relative, so it must be stale.
  printf 'x\n' > "$tmp_root/escape.md"

  local mdir; mdir="$(make_fixture_memory "$cfg" "$repo")"
  cat > "$mdir/MEMORY.md" <<'MD'
# Memory Index
- [unsafe](card_unsafe.md) — unsafe hook
MD
  cat > "$mdir/card_unsafe.md" <<'MD'
---
name: unsafe
topics: [x]
priority: normal
status: active
updated_at: "2026-06-23"
repo_refs:
  - path:../escape.md
  - path:/etc/hosts
---
body
MD

  local out="$tmp_root/unsafe.json" status=0
  run_doctor_json "$out" "$cfg" "$repo" || status=$?

  if ! assert_exit "$name" "$status" 1; then
    fail "$name" "expected 1 (both refs invalid→stale) but got $status: $(<"$out")"
    return 0
  fi
  if ! assert_file_contains "$name" "$out" '{"card":"card_unsafe.md","ref":"path:../escape.md"}'; then return 0; fi
  if ! assert_file_contains "$name" "$out" '{"card":"card_unsafe.md","ref":"path:/etc/hosts"}'; then return 0; fi
  pass "$name"
}

case_memory_doctor_fn_symbol_injection() {
  local name="pmctl memory doctor: fn: ref with regex metachars → stale, not falsely fresh"
  should_run "$name" || return 0

  local cfg="$tmp_root/inj-cfg" repo="$tmp_root/inj-repo"
  mkdir -p "$repo/scripts"
  # File contains a real function; a malicious symbol '.*' would match it via
  # grep -E if interpolated raw. A non-identifier symbol must be treated stale.
  printf 'real_fn() {\n  :\n}\n' > "$repo/scripts/lib.sh"

  local mdir; mdir="$(make_fixture_memory "$cfg" "$repo")"
  cat > "$mdir/MEMORY.md" <<'MD'
# Memory Index
- [inj](card_inj.md) — inj hook
MD
  cat > "$mdir/card_inj.md" <<'MD'
---
name: inj
topics: [x]
priority: normal
status: active
updated_at: "2026-06-23"
repo_refs:
  - fn:scripts/lib.sh#.*
---
body
MD

  local out="$tmp_root/inj.json" status=0
  run_doctor_json "$out" "$cfg" "$repo" || status=$?

  if ! assert_exit "$name" "$status" 1; then
    fail "$name" "expected 1 (non-identifier symbol → stale) but got $status: $(<"$out")"
    return 0
  fi
  if ! assert_file_contains "$name" "$out" '{"card":"card_inj.md","ref":"fn:scripts/lib.sh#.*"}'; then return 0; fi
  pass "$name"
}

case_memory_doctor_fn_function_keyword_boundary() {
  local name="pmctl memory doctor: fn: with 'function name' form requires exact symbol boundary"
  should_run "$name" || return 0

  local cfg="$tmp_root/fnkw-cfg" repo="$tmp_root/fnkw-repo"
  mkdir -p "$repo/scripts"
  # Only the RENAMED function exists, defined with the `function` keyword form.
  # fn:...#g_audit must be STALE (no exact g_audit); a naive ^function g_audit
  # prefix-match would wrongly call it fresh. fn:...#g_audit_renamed is fresh.
  printf 'function g_audit_renamed() {\n  :\n}\n' > "$repo/scripts/f.sh"

  local mdir; mdir="$(make_fixture_memory "$cfg" "$repo")"
  cat > "$mdir/MEMORY.md" <<'MD'
# Memory Index
- [fnkw](card_fnkw.md) — fnkw hook
MD
  cat > "$mdir/card_fnkw.md" <<'MD'
---
name: fnkw
topics: [x]
priority: normal
status: active
updated_at: "2026-06-23"
repo_refs:
  - fn:scripts/f.sh#g_audit
  - fn:scripts/f.sh#g_audit_renamed
---
body
MD

  local out="$tmp_root/fnkw.json" status=0
  run_doctor_json "$out" "$cfg" "$repo" || status=$?

  if ! assert_exit "$name" "$status" 1; then
    fail "$name" "expected 1 (g_audit stale via boundary) but got $status: $(<"$out")"
    return 0
  fi
  # The renamed-prefix ref is stale; the exact ref is fresh (not flagged).
  if ! assert_file_contains "$name" "$out" '{"card":"card_fnkw.md","ref":"fn:scripts/f.sh#g_audit"}'; then return 0; fi
  local body; body="$(<"$out")"
  if [[ "$body" == *'#g_audit_renamed"'* ]]; then
    fail "$name" "exact symbol g_audit_renamed must be fresh, not flagged stale: $body"
    return 0
  fi
  pass "$name"
}

# ── pmctl memory dir tests ─────────────────────────────────────────────────────

case_memory_dir_happy_path() {
  local name="pmctl memory dir: cwd with memory dir → prints dir path, exit 0"
  should_run "$name" || return 0

  local cfg="$tmp_root/mdir-cfg" repo="$tmp_root/mdir-repo"
  mkdir -p "$repo"
  local mdir; mdir="$(make_fixture_memory "$cfg" "$repo")"

  local out status=0
  out="$(CLAUDE_CONFIG_DIR="$cfg" "$PMCTL" memory dir "$repo" 2>/dev/null)" || status=$?

  if ! assert_exit "$name" "$status" 0; then return 0; fi
  if [[ "$out" != "$mdir" ]]; then
    fail "$name" "expected '$mdir' got '$out'"
    return 0
  fi
  pass "$name"
}

case_memory_dir_nested_subdir() {
  local name="pmctl memory dir: nested subdir cwd → walks up to find memory dir"
  should_run "$name" || return 0

  local cfg="$tmp_root/nested-cfg" repo="$tmp_root/nested-repo"
  local subdir="$repo/a/b/c"
  mkdir -p "$subdir"
  local mdir; mdir="$(make_fixture_memory "$cfg" "$repo")"

  local out status=0
  out="$(CLAUDE_CONFIG_DIR="$cfg" "$PMCTL" memory dir "$subdir" 2>/dev/null)" || status=$?

  if ! assert_exit "$name" "$status" 0; then return 0; fi
  if [[ "$out" != "$mdir" ]]; then
    fail "$name" "expected '$mdir' got '$out'"
    return 0
  fi
  pass "$name"
}

case_memory_dir_uses_pwd_default() {
  local name="pmctl memory dir: no arg uses \$PWD"
  should_run "$name" || return 0

  local cfg="$tmp_root/pwd-cfg" repo="$tmp_root/pwd-repo"
  mkdir -p "$repo"
  local mdir; mdir="$(make_fixture_memory "$cfg" "$repo")"

  local out status=0
  out="$(cd "$repo" && CLAUDE_CONFIG_DIR="$cfg" "$PMCTL" memory dir 2>/dev/null)" || status=$?

  if ! assert_exit "$name" "$status" 0; then return 0; fi
  if [[ "$out" != "$mdir" ]]; then
    fail "$name" "expected '$mdir' got '$out'"
    return 0
  fi
  pass "$name"
}

case_memory_dir_not_found() {
  local name="pmctl memory dir: no memory dir → exit nonzero, no stdout"
  should_run "$name" || return 0

  local cfg="$tmp_root/nomdir-cfg" repo="$tmp_root/nomdir-repo"
  mkdir -p "$cfg/projects" "$repo"
  # No memory dir created under cfg for this repo.

  local out status=0
  out="$(CLAUDE_CONFIG_DIR="$cfg" "$PMCTL" memory dir "$repo" 2>/dev/null)" || status=$?

  if [[ "$status" -eq 0 ]]; then
    fail "$name" "expected nonzero exit when no memory dir found, got 0"
    return 0
  fi
  if [[ -n "$out" ]]; then
    fail "$name" "expected empty stdout on miss, got: '$out'"
    return 0
  fi
  pass "$name"
}

case_memory_dir_pm_memory_dir_env_override() {
  local name="pmctl memory dir: PM_MEMORY_DIR env overrides CLAUDE_CONFIG_DIR discovery"
  should_run "$name" || return 0

  local cfg="$tmp_root/pmenv-cfg" repo="$tmp_root/pmenv-repo" override="$tmp_root/pmenv-override"
  mkdir -p "$repo" "$override"
  # No memory dir under $cfg for $repo — override must be what wins.

  local out status=0
  out="$(PM_MEMORY_DIR="$override" CLAUDE_CONFIG_DIR="$cfg" "$PMCTL" memory dir "$repo" 2>/dev/null)" || status=$?

  if ! assert_exit "$name" "$status" 0; then return 0; fi
  if [[ "$out" != "$override" ]]; then
    fail "$name" "expected '$override' got '$out'"
    return 0
  fi
  pass "$name"
}

case_memory_dir_pm_memory_dir_unset_byte_identical() {
  local name="pmctl memory dir: PM_MEMORY_DIR unset → byte-identical to pre-seam resolution"
  should_run "$name" || return 0

  local cfg="$tmp_root/pmunset-cfg" repo="$tmp_root/pmunset-repo"
  mkdir -p "$repo"
  local mdir; mdir="$(make_fixture_memory "$cfg" "$repo")"

  local out status=0
  out="$(unset PM_MEMORY_DIR; CLAUDE_CONFIG_DIR="$cfg" "$PMCTL" memory dir "$repo" 2>/dev/null)" || status=$?

  if ! assert_exit "$name" "$status" 0; then return 0; fi
  if [[ "$out" != "$mdir" ]]; then
    fail "$name" "expected '$mdir' got '$out'"
    return 0
  fi
  pass "$name"
}

case_memory_dir_config_dispatch_memory_dir_override() {
  local name="pmctl memory dir: project-scoped config overrides discovery when PM_MEMORY_DIR unset"
  should_run "$name" || return 0

  local cfg="$tmp_root/pmcfg-cfg" repo="$tmp_root/pmcfg-repo" override="$tmp_root/pmcfg-override" fakehome="$tmp_root/pmcfg-home"
  mkdir -p "$repo" "$override" "$fakehome/.pm-dispatch"
  write_project_memory_config "$fakehome/.pm-dispatch/config" "$repo" "$override"

  local out status=0
  out="$(PM_DISPATCH_CONFIG_FILE="$fakehome/.pm-dispatch/config" CLAUDE_CONFIG_DIR="$cfg" "$PMCTL" memory dir "$repo" 2>/dev/null)" || status=$?

  if ! assert_exit "$name" "$status" 0; then return 0; fi
  if [[ "$out" != "$override" ]]; then
    fail "$name" "expected '$override' got '$out'"
    return 0
  fi
  pass "$name"
}

case_memory_dir_pm_memory_dir_outranks_config() {
  local name="pmctl memory dir: PM_MEMORY_DIR env outranks project-scoped config"
  should_run "$name" || return 0

  local cfg="$tmp_root/pmboth-cfg" repo="$tmp_root/pmboth-repo"
  local env_win="$tmp_root/pmboth-env-win" cfg_lose="$tmp_root/pmboth-cfg-lose" fakehome="$tmp_root/pmboth-home"
  mkdir -p "$repo" "$env_win" "$cfg_lose" "$fakehome/.pm-dispatch"
  write_project_memory_config "$fakehome/.pm-dispatch/config" "$repo" "$cfg_lose"

  local out status=0
  out="$(PM_MEMORY_DIR="$env_win" PM_DISPATCH_CONFIG_FILE="$fakehome/.pm-dispatch/config" CLAUDE_CONFIG_DIR="$cfg" "$PMCTL" memory dir "$repo" 2>/dev/null)" || status=$?

  if ! assert_exit "$name" "$status" 0; then return 0; fi
  if [[ "$out" != "$env_win" ]]; then
    fail "$name" "expected '$env_win' (env) got '$out'"
    return 0
  fi
  pass "$name"
}

case_memory_dir_malformed_config_memory_dir_fails_closed() {
  local name="pmctl memory dir: malformed project-scoped path fails closed without legacy resolution"
  should_run "$name" || return 0

  local cfg="$tmp_root/pmbad-cfg" repo="$tmp_root/pmbad-repo" fakehome="$tmp_root/pmbad-home"
  mkdir -p "$repo" "$fakehome/.pm-dispatch"
  local mdir; mdir="$(make_fixture_memory "$cfg" "$repo")"
  write_project_memory_config "$fakehome/.pm-dispatch/config" "$repo" relative/not-absolute

  local out err status=0
  err="$tmp_root/pmbad.err"
  out="$(PM_DISPATCH_CONFIG_FILE="$fakehome/.pm-dispatch/config" CLAUDE_CONFIG_DIR="$cfg" "$PMCTL" memory dir "$repo" 2>"$err")" || status=$?

  if ! assert_exit "$name" "$status" 3; then return 0; fi
  if [[ -n "$out" ]]; then
    fail "$name" "expected no resolved directory, got '$out' instead of rejecting legacy '$mdir'"
    return 0
  fi
  if ! grep -q 'malformed value for memory.projects.' "$err"; then
    fail "$name" "expected a malformed-value warning on stderr, got: $(<"$err")"
    return 0
  fi
  pass "$name"
}

case_memory_dir_no_mutation() {
  local name="pmctl memory dir: does not create or mutate directories on hit or miss"
  should_run "$name" || return 0

  local cfg="$tmp_root/nomut-cfg" repo="$tmp_root/nomut-repo"
  mkdir -p "$cfg/projects" "$repo"
  local before; before="$(find "$cfg" "$repo" -type f 2>/dev/null | sort)"

  # Miss path: no mutation expected.
  CLAUDE_CONFIG_DIR="$cfg" "$PMCTL" memory dir "$repo" >/dev/null 2>&1 || true

  local after; after="$(find "$cfg" "$repo" -type f 2>/dev/null | sort)"
  if [[ "$before" != "$after" ]]; then
    fail "$name" "unexpected filesystem changes after miss"
    return 0
  fi

  # Hit path: no mutation of the memory dir beyond what was set up.
  local mdir; mdir="$(make_fixture_memory "$cfg" "$repo")"
  local before_hit; before_hit="$(find "$cfg" "$repo" -type f 2>/dev/null | sort)"
  CLAUDE_CONFIG_DIR="$cfg" "$PMCTL" memory dir "$repo" >/dev/null 2>&1 || true
  local after_hit; after_hit="$(find "$cfg" "$repo" -type f 2>/dev/null | sort)"
  if [[ "$before_hit" != "$after_hit" ]]; then
    fail "$name" "unexpected filesystem changes after hit"
    return 0
  fi
  pass "$name"
}

# Behavior: memory commands under test resolve only into fixture directories, never the developer's live memory dir.
# Steps: run doctor and stats against a fixture; read the memory_dir each reports; assert both are inside tmp_root and neither is the live dir.
case_memory_commands_resolve_only_fixture_dirs() {
  local name="pmctl memory doctor/stats: fixture runs resolve inside tmp_root, never the live memory dir"
  should_run "$name" || return 0

  # This replaces a content-fingerprint guard over the live memory dir. That
  # oracle could not distinguish "a case in this suite wrote there" from "an
  # unrelated process did" — and the prompt-injection hook writes the live
  # usage sidecar on every turn, so it failed for reasons the suite does not
  # control. Assert the property that actually matters and is deterministic:
  # a fixture run must never resolve to the live directory in the first place.
  local cfg="$tmp_root/resolve-fixture-cfg" repo="$tmp_root/resolve-fixture-repo" mdir
  mdir="$(make_stats_fixture "$cfg" "$repo" 1)"

  local out dir
  out="$tmp_root/resolve-fixture-doctor.json"
  CLAUDE_CONFIG_DIR="$cfg" "$PMCTL" memory doctor --repo-root "$repo" --json > "$out" 2>/dev/null || true
  dir="$(jq -r '.memory_dir // empty' "$out" 2>/dev/null || printf '')"
  if [[ "$dir" != "$mdir" ]]; then
    fail "$name" "doctor resolved [$dir], expected the fixture dir [$mdir]"
    return 0
  fi

  out="$tmp_root/resolve-fixture-stats.json"
  CLAUDE_CONFIG_DIR="$cfg" "$PMCTL" memory stats --repo-root "$repo" --json > "$out" 2>/dev/null || true
  dir="$(jq -r '.memory_dir // empty' "$out" 2>/dev/null || printf '')"
  if [[ "$dir" != "$mdir" ]]; then
    fail "$name" "stats resolved [$dir], expected the fixture dir [$mdir]"
    return 0
  fi

  # And the live dir must not be reachable from tmp_root by construction.
  if [[ -n "$_LIVE_MEM_DIR" && "$_LIVE_MEM_DIR" == "$tmp_root"/* ]]; then
    fail "$name" "live memory dir resolves inside tmp_root: $_LIVE_MEM_DIR"
    return 0
  fi
  pass "$name"
}

# Behavior: pmctl memory doctor writes nothing into the memory directory it inspects.
# Steps: build a fixture with cards and episodes; fingerprint it; run doctor in both modes; assert the fingerprint is unchanged.
case_memory_doctor_is_read_only() {
  local name="pmctl memory doctor: does not write to the memory dir it inspects"
  should_run "$name" || return 0

  local cfg="$tmp_root/doc-ro-cfg" repo="$tmp_root/doc-ro-repo" mdir
  mdir="$(make_stats_fixture "$cfg" "$repo" 2)"
  printf '{"date":"2026-08-01","session_id":"a","summary":"x"}\n' > "$mdir/episodes.jsonl"

  local before after
  before="$(find "$mdir" -type f -printf '%P:%s\n' 2>/dev/null | sort)"
  CLAUDE_CONFIG_DIR="$cfg" "$PMCTL" memory doctor --repo-root "$repo" --json >/dev/null 2>&1 || true
  CLAUDE_CONFIG_DIR="$cfg" "$PMCTL" memory doctor --repo-root "$repo" >/dev/null 2>&1 || true
  after="$(find "$mdir" -type f -printf '%P:%s\n' 2>/dev/null | sort)"
  if [[ "$before" != "$after" ]]; then
    fail "$name" "doctor mutated the memory dir it inspected"
    return 0
  fi
  pass "$name"
}

# ── Shard cases ───────────────────────────────────────────────────────────────

case_memory_shard_below_limit() {
  local name="pmctl memory shard: below limit — no shard files created"
  should_run "$name" || return 0

  local cfg repo mdir
  cfg="$(mktemp -d -p "$tmp_root")"
  repo="$(mktemp -d -p "$tmp_root")"
  mdir="$(make_fixture_memory "$cfg" "$repo")"

  # Write 5 episodes (well below EP_SHARD_LINE_LIMIT=1000).
  local ep="$mdir/episodes.jsonl"
  local i
  for i in $(seq 1 5); do
    printf '{"date":"2026-05-%02d","cwd":"%s","session_id":"s%d","summary":"entry %d"}\n' \
      "$i" "$repo" "$i" "$i" >> "$ep"
  done

  local out status=0
  out="$(CLAUDE_CONFIG_DIR="$cfg" "$PMCTL" memory shard --repo-root "$repo" 2>&1)" || status=$?

  if [[ "$status" -ne 0 ]]; then
    fail "$name" "pmctl memory shard exited $status; output: $out"
    return 0
  fi
  # Should report "no shard needed".
  if ! printf '%s' "$out" | grep -q "no shard needed"; then
    fail "$name" "expected 'no shard needed', got: $out"
    return 0
  fi
  # No shard files should exist.
  local shards
  shards="$(find "$mdir" -name 'episodes.????-??.jsonl' 2>/dev/null | wc -l)"
  if [[ "$shards" -ne 0 ]]; then
    fail "$name" "expected 0 shard files, got $shards"
    return 0
  fi
  pass "$name"
}

case_memory_shard_above_limit() {
  local name="pmctl memory shard: above limit — archives old months"
  should_run "$name" || return 0

  local cfg repo mdir
  cfg="$(mktemp -d -p "$tmp_root")"
  repo="$(mktemp -d -p "$tmp_root")"
  mdir="$(make_fixture_memory "$cfg" "$repo")"

  local ep="$mdir/episodes.jsonl"

  # Write EP_SHARD_LINE_LIMIT+1 entries spread across two old months + current.
  # We use a fixed "current" month different from old months to avoid clock dependency.
  # pmctl_memory_shard compares against `date -u +%Y-%m`; we write old entries for
  # 2020-01 and 2020-02, which are safely in the past.
  local i
  for i in $(seq 1 600); do
    printf '{"date":"2020-01-%02d","cwd":"%s","session_id":"s%d","summary":"old entry %d"}\n' \
      "$(( (i % 28) + 1 ))" "$repo" "$i" "$i" >> "$ep"
  done
  for i in $(seq 1 600); do
    printf '{"date":"2020-02-%02d","cwd":"%s","session_id":"s%d","summary":"old entry %d"}\n' \
      "$(( (i % 28) + 1 ))" "$repo" "$i" "$i" >> "$ep"
  done
  # One entry for current month (should remain in main file).
  local cur_ym
  cur_ym="$(date -u +%Y-%m 2>/dev/null || date +%Y-%m)"
  printf '{"date":"%s-01","cwd":"%s","session_id":"scur","summary":"current entry"}\n' \
    "$cur_ym" "$repo" >> "$ep"

  local out status=0
  out="$(CLAUDE_CONFIG_DIR="$cfg" "$PMCTL" memory shard --repo-root "$repo" 2>&1)" || status=$?
  if [[ "$status" -ne 0 ]]; then
    fail "$name" "pmctl memory shard exited $status; output: $out"
    return 0
  fi

  # Shard files for 2020-01 and 2020-02 should now exist (copy-only archive).
  local shard_jan="$mdir/episodes.2020-01.jsonl"
  local shard_feb="$mdir/episodes.2020-02.jsonl"
  if [[ ! -f "$shard_jan" ]]; then
    fail "$name" "expected shard file episodes.2020-01.jsonl to exist; output: $out"
    return 0
  fi
  if [[ ! -f "$shard_feb" ]]; then
    fail "$name" "expected shard file episodes.2020-02.jsonl to exist; output: $out"
    return 0
  fi

  # shard is copy-only: main episodes.jsonl must NOT be modified (all 1201 lines remain).
  local main_lines
  main_lines="$(wc -l < "$ep")"
  if [[ "$main_lines" -ne 1201 ]]; then
    fail "$name" "shard must not modify main episodes.jsonl (expected 1201 lines, got $main_lines)"
    return 0
  fi
  # Current-month entry must still be present in main file.
  if ! grep -q '"scur"' "$ep"; then
    fail "$name" "main episodes.jsonl should still contain the current-month entry"
    return 0
  fi
  # Shard file for 2020-01 should have exactly 600 entries (copy of old entries).
  local shard_jan_lines
  shard_jan_lines="$(wc -l < "$shard_jan")"
  if [[ "$shard_jan_lines" -ne 600 ]]; then
    fail "$name" "expected 600 lines in shard 2020-01, got $shard_jan_lines"
    return 0
  fi
  # Output should mention the archived count.
  if ! printf '%s' "$out" | grep -q "copied"; then
    fail "$name" "expected 'copied' in output, got: $out"
    return 0
  fi
  pass "$name"
}

case_memory_shard_idempotent() {
  local name="pmctl memory shard: running shard twice leaves shard files unchanged (idempotent)"
  should_run "$name" || return 0

  local cfg repo mdir
  cfg="$(mktemp -d -p "$tmp_root")"
  repo="$(mktemp -d -p "$tmp_root")"
  mdir="$(make_fixture_memory "$cfg" "$repo")"

  # Need >1000 lines to trigger shard: 600 (2020-01) + 500 (2020-02) + 1 current = 1101.
  local ep="$mdir/episodes.jsonl"
  local i
  for i in $(seq 1 600); do
    printf '{"date":"2020-01-%02d","cwd":"%s","session_id":"s%d","summary":"old %d"}\n' \
      "$(( (i % 28) + 1 ))" "$repo" "$i" "$i" >> "$ep"
  done
  for i in $(seq 1 500); do
    printf '{"date":"2020-02-%02d","cwd":"%s","session_id":"t%d","summary":"old2 %d"}\n' \
      "$(( (i % 28) + 1 ))" "$repo" "$i" "$i" >> "$ep"
  done
  local cur_ym
  cur_ym="$(date -u +%Y-%m 2>/dev/null || date +%Y-%m)"
  printf '{"date":"%s-01","cwd":"%s","session_id":"scur","summary":"current"}\n' "$cur_ym" "$repo" >> "$ep"

  # First shard run.
  CLAUDE_CONFIG_DIR="$cfg" "$PMCTL" memory shard --repo-root "$repo" >/dev/null 2>&1 || true
  local lines_after_first
  lines_after_first="$(wc -l < "$mdir/episodes.2020-01.jsonl" 2>/dev/null || printf '0')"

  # Second shard run — shard file must have same line count (idempotent overwrite).
  CLAUDE_CONFIG_DIR="$cfg" "$PMCTL" memory shard --repo-root "$repo" >/dev/null 2>&1 || true
  local lines_after_second
  lines_after_second="$(wc -l < "$mdir/episodes.2020-01.jsonl" 2>/dev/null || printf '0')"

  if [[ "$lines_after_first" -ne "$lines_after_second" ]]; then
    fail "$name" "shard not idempotent: $lines_after_first lines after first run, $lines_after_second after second"
    return 0
  fi
  if [[ "$lines_after_second" -ne 600 ]]; then
    fail "$name" "expected 600 lines in shard file, got $lines_after_second"
    return 0
  fi
  pass "$name"
}

case_memory_rebuild_summary_no_duplicate_after_shard() {
  local name="pmctl memory rebuild-summary: no duplicate entries in summary after shard run"
  should_run "$name" || return 0

  local cfg repo mdir
  cfg="$(mktemp -d -p "$tmp_root")"
  repo="$(mktemp -d -p "$tmp_root")"
  mdir="$(make_fixture_memory "$cfg" "$repo")"

  # Need >1000 lines to trigger shard: 600 (2020-01) + 500 (2020-02) + 1 current = 1101.
  local ep="$mdir/episodes.jsonl"
  local i
  for i in $(seq 1 600); do
    printf '{"date":"2020-01-%02d","cwd":"%s","session_id":"s%d","summary":"old %d"}\n' \
      "$(( (i % 28) + 1 ))" "$repo" "$i" "$i" >> "$ep"
  done
  for i in $(seq 1 500); do
    printf '{"date":"2020-02-%02d","cwd":"%s","session_id":"t%d","summary":"old2 %d"}\n' \
      "$(( (i % 28) + 1 ))" "$repo" "$i" "$i" >> "$ep"
  done
  local cur_ym
  cur_ym="$(date -u +%Y-%m 2>/dev/null || date +%Y-%m)"
  printf '{"date":"%s-01","cwd":"%s","session_id":"scur","summary":"current entry"}\n' "$cur_ym" "$repo" >> "$ep"

  # Run shard first — verify it actually ran (shard file must exist).
  local shard_status=0
  CLAUDE_CONFIG_DIR="$cfg" "$PMCTL" memory shard --repo-root "$repo" >/dev/null 2>&1 || shard_status=$?
  if [[ "$shard_status" -ne 0 ]]; then
    fail "$name" "pmctl memory shard failed with exit $shard_status"
    return 0
  fi
  if [[ ! -f "$mdir/episodes.2020-01.jsonl" ]]; then
    fail "$name" "shard did not create episodes.2020-01.jsonl; shard may not have run"
    return 0
  fi

  # Then rebuild summary — verify it succeeded.
  local rs_status=0
  CLAUDE_CONFIG_DIR="$cfg" "$PMCTL" memory rebuild-summary --repo-root "$repo" >/dev/null 2>&1 || rs_status=$?
  if [[ "$rs_status" -ne 0 ]]; then
    fail "$name" "pmctl memory rebuild-summary failed with exit $rs_status"
    return 0
  fi

  local summary="$mdir/episodes.summary.md"
  if [[ ! -f "$summary" ]]; then
    fail "$name" "episodes.summary.md not created"
    return 0
  fi

  # Count how many entries appear under 2020-01 heading. Should be exactly 600.
  local entry_count
  entry_count="$(grep -c '^- 2020-01' "$summary" 2>/dev/null || printf '0')"
  if [[ "$entry_count" -ne 600 ]]; then
    fail "$name" "expected 600 entries for 2020-01, got $entry_count (duplicate entries?)"
    return 0
  fi
  pass "$name"
}

case_memory_rebuild_summary_basic() {
  local name="pmctl memory rebuild-summary: produces episodes.summary.md grouped by month"
  should_run "$name" || return 0

  local cfg repo mdir
  cfg="$(mktemp -d -p "$tmp_root")"
  repo="$(mktemp -d -p "$tmp_root")"
  mdir="$(make_fixture_memory "$cfg" "$repo")"

  local ep="$mdir/episodes.jsonl"
  {
    printf '{"date":"2026-05-01","cwd":"%s","session_id":"a","summary":"may entry one"}\n' "$repo"
    printf '{"date":"2026-05-02","cwd":"%s","session_id":"b","summary":"may entry two"}\n' "$repo"
    printf '{"date":"2026-06-01","cwd":"%s","session_id":"c","summary":"june entry"}\n'   "$repo"
  } >> "$ep"

  local out status=0
  out="$(CLAUDE_CONFIG_DIR="$cfg" "$PMCTL" memory rebuild-summary --repo-root "$repo" 2>&1)" || status=$?
  if [[ "$status" -ne 0 ]]; then
    fail "$name" "pmctl memory rebuild-summary exited $status; output: $out"
    return 0
  fi

  local summary="$mdir/episodes.summary.md"
  if [[ ! -f "$summary" ]]; then
    fail "$name" "episodes.summary.md not created; output: $out"
    return 0
  fi
  # Should have two month sections.
  local month_count
  month_count="$(grep -c '^## ' "$summary")"
  if [[ "$month_count" -ne 2 ]]; then
    fail "$name" "expected 2 month sections in summary, got $month_count"
    return 0
  fi
  # 2026-06 should appear before 2026-05 (newest first).
  local june_line may_line
  june_line="$(grep -n '^## 2026-06' "$summary" | cut -d: -f1)"
  may_line="$(grep -n '^## 2026-05' "$summary" | cut -d: -f1)"
  if [[ -z "$june_line" || -z "$may_line" ]]; then
    fail "$name" "missing month sections in summary"
    return 0
  fi
  if [[ "$june_line" -ge "$may_line" ]]; then
    fail "$name" "2026-06 should appear before 2026-05 (newest first)"
    return 0
  fi
  pass "$name"
}

case_memory_rebuild_summary_skips_empty_summary() {
  local name="pmctl memory rebuild-summary: skips skeleton entries with empty summary"
  should_run "$name" || return 0

  local cfg repo mdir
  cfg="$(mktemp -d -p "$tmp_root")"
  repo="$(mktemp -d -p "$tmp_root")"
  mdir="$(make_fixture_memory "$cfg" "$repo")"

  local ep="$mdir/episodes.jsonl"
  {
    printf '{"date":"2026-05-01","cwd":"%s","session_id":"a","summary":""}\n'         "$repo"
    printf '{"date":"2026-05-02","cwd":"%s","session_id":"b","summary":"real entry"}\n' "$repo"
    # Whitespace-only and leading-blank-line skeletons are unfilled too. `pmctl
    # memory stats` counts them as unfilled, so this generator must skip them —
    # otherwise one concept has two answers and the summary gains empty bullets.
    printf '{"date":"2026-05-03","cwd":"%s","session_id":"c","summary":"   "}\n'      "$repo"
    printf '{"date":"2026-05-04","cwd":"%s","session_id":"d","summary":"\\n  "}\n'    "$repo"
  } >> "$ep"

  local status=0
  CLAUDE_CONFIG_DIR="$cfg" "$PMCTL" memory rebuild-summary --repo-root "$repo" >/dev/null 2>&1 || status=$?
  if [[ "$status" -ne 0 ]]; then
    fail "$name" "pmctl memory rebuild-summary exited $status"
    return 0
  fi

  local summary="$mdir/episodes.summary.md"
  [[ -f "$summary" ]] || { fail "$name" "summary not created"; return 0; }
  local entry_count
  entry_count="$(grep -c '^- ' "$summary")"
  if [[ "$entry_count" -ne 1 ]]; then
    fail "$name" "expected 1 bullet (all skeleton forms skipped), got $entry_count: $(cat "$summary")"
    return 0
  fi
  # No bullet may be emitted with an empty body.
  if grep -qE '^- [0-9-]+: *$' "$summary"; then
    fail "$name" "emitted an empty bullet: $(cat "$summary")"
    return 0
  fi
  pass "$name"
}

case_memory_rebuild_summary_deterministic() {
  local name="pmctl memory rebuild-summary: rebuild is deterministic (same output on second run)"
  should_run "$name" || return 0

  local cfg repo mdir
  cfg="$(mktemp -d -p "$tmp_root")"
  repo="$(mktemp -d -p "$tmp_root")"
  mdir="$(make_fixture_memory "$cfg" "$repo")"

  local ep="$mdir/episodes.jsonl"
  printf '{"date":"2026-06-01","cwd":"%s","session_id":"a","summary":"first"}\n'  "$repo" >> "$ep"
  printf '{"date":"2026-06-02","cwd":"%s","session_id":"b","summary":"second"}\n' "$repo" >> "$ep"

  local status=0
  CLAUDE_CONFIG_DIR="$cfg" "$PMCTL" memory rebuild-summary --repo-root "$repo" >/dev/null 2>&1 || status=$?
  if [[ "$status" -ne 0 ]]; then fail "$name" "first rebuild-summary exited $status"; return 0; fi
  local first_run
  first_run="$(cat "$mdir/episodes.summary.md")"

  CLAUDE_CONFIG_DIR="$cfg" "$PMCTL" memory rebuild-summary --repo-root "$repo" >/dev/null 2>&1 || status=$?
  if [[ "$status" -ne 0 ]]; then fail "$name" "second rebuild-summary exited $status"; return 0; fi
  local second_run
  second_run="$(cat "$mdir/episodes.summary.md")"

  if [[ "$first_run" != "$second_run" ]]; then
    fail "$name" "rebuild produced different output on second run"
    return 0
  fi
  pass "$name"
}

case_memory_shard_no_memory_dir() {
  local name="pmctl memory shard: no memory directory → exits 1 with message"
  should_run "$name" || return 0
  local cfg repo
  cfg="$(mktemp -d -p "$tmp_root")"
  repo="$(mktemp -d -p "$tmp_root")"
  mkdir -p "$cfg/projects"  # no memory subdir
  local out status=0
  out="$(CLAUDE_CONFIG_DIR="$cfg" "$PMCTL" memory shard --repo-root "$repo" 2>&1)" || status=$?
  if [[ "$status" -ne 1 ]]; then
    fail "$name" "expected exit 1 for no memory dir, got $status; output: $out"
    return 0
  fi
  if ! printf '%s' "$out" | grep -q "no memory directory"; then
    fail "$name" "expected 'no memory directory' message; got: $out"
    return 0
  fi
  pass "$name"
}

case_memory_rebuild_summary_no_memory_dir() {
  local name="pmctl memory rebuild-summary: no memory directory → exits 1 with message"
  should_run "$name" || return 0
  local cfg repo
  cfg="$(mktemp -d -p "$tmp_root")"
  repo="$(mktemp -d -p "$tmp_root")"
  mkdir -p "$cfg/projects"  # no memory subdir
  local out status=0
  out="$(CLAUDE_CONFIG_DIR="$cfg" "$PMCTL" memory rebuild-summary --repo-root "$repo" 2>&1)" || status=$?
  if [[ "$status" -ne 1 ]]; then
    fail "$name" "expected exit 1 for no memory dir, got $status; output: $out"
    return 0
  fi
  if ! printf '%s' "$out" | grep -q "no memory directory"; then
    fail "$name" "expected 'no memory directory' message; got: $out"
    return 0
  fi
  pass "$name"
}

case_memory_shard_config_memory_dir_override() {
  local name="pmctl memory shard: project-scoped config resolves an override-only memory dir"
  should_run "$name" || return 0

  local cfg repo override fakehome
  cfg="$(mktemp -d -p "$tmp_root")"
  repo="$(mktemp -d -p "$tmp_root")"
  override="$(mktemp -d -p "$tmp_root")"
  fakehome="$(mktemp -d -p "$tmp_root")"
  mkdir -p "$cfg/projects" "$fakehome/.pm-dispatch"  # cfg has NO memory dir for $repo
  write_project_memory_config "$fakehome/.pm-dispatch/config" "$repo" "$override"

  local ep="$override/episodes.jsonl"
  local i
  for i in $(seq 1 5); do
    printf '{"date":"2026-05-%02d","cwd":"%s","session_id":"s%d","summary":"entry %d"}\n' \
      "$i" "$repo" "$i" "$i" >> "$ep"
  done

  local out status=0
  out="$(PM_DISPATCH_CONFIG_FILE="$fakehome/.pm-dispatch/config" CLAUDE_CONFIG_DIR="$cfg" "$PMCTL" memory shard --repo-root "$repo" 2>&1)" || status=$?

  if [[ "$status" -ne 0 ]]; then
    fail "$name" "expected shard to resolve override-only memory dir; exited $status: $out"
    return 0
  fi
  if ! printf '%s' "$out" | grep -q "no shard needed"; then
    fail "$name" "expected 'no shard needed' (5 lines below limit); got: $out"
    return 0
  fi
  pass "$name"
}

case_memory_rebuild_summary_config_memory_dir_override() {
  local name="pmctl memory rebuild-summary: project-scoped config resolves an override-only memory dir"
  should_run "$name" || return 0

  local cfg repo override fakehome
  cfg="$(mktemp -d -p "$tmp_root")"
  repo="$(mktemp -d -p "$tmp_root")"
  override="$(mktemp -d -p "$tmp_root")"
  fakehome="$(mktemp -d -p "$tmp_root")"
  mkdir -p "$cfg/projects" "$fakehome/.pm-dispatch"  # cfg has NO memory dir for $repo
  write_project_memory_config "$fakehome/.pm-dispatch/config" "$repo" "$override"

  local ep="$override/episodes.jsonl"
  printf '{"date":"2026-05-01","cwd":"%s","session_id":"a","summary":"may entry one"}\n' "$repo" >> "$ep"

  local out status=0
  out="$(PM_DISPATCH_CONFIG_FILE="$fakehome/.pm-dispatch/config" CLAUDE_CONFIG_DIR="$cfg" "$PMCTL" memory rebuild-summary --repo-root "$repo" 2>&1)" || status=$?

  if [[ "$status" -ne 0 ]]; then
    fail "$name" "expected rebuild-summary to resolve override-only memory dir; exited $status: $out"
    return 0
  fi
  if [[ ! -f "$override/episodes.summary.md" ]]; then
    fail "$name" "expected episodes.summary.md under the config-override memory dir; output: $out"
    return 0
  fi
  pass "$name"
}

case_memory_index_not_produced() {
  local name="pmctl memory shard+rebuild-summary: episodes.index.jsonl is not produced (deferred)"
  should_run "$name" || return 0
  # episodes.index.jsonl was mentioned in CC-407 spec but is explicitly deferred to a
  # follow-up ticket. Asserting its absence documents the conscious deferral contract.
  local cfg repo mdir
  cfg="$(mktemp -d -p "$tmp_root")"
  repo="$(mktemp -d -p "$tmp_root")"
  mdir="$(make_fixture_memory "$cfg" "$repo")"
  printf '{"date":"2026-05-01","cwd":"%s","session_id":"a","summary":"entry"}\n' "$repo" > "$mdir/episodes.jsonl"
  CLAUDE_CONFIG_DIR="$cfg" "$PMCTL" memory rebuild-summary --repo-root "$repo" >/dev/null 2>&1 || true
  CLAUDE_CONFIG_DIR="$cfg" "$PMCTL" memory shard --repo-root "$repo" >/dev/null 2>&1 || true
  if [[ -f "$mdir/episodes.index.jsonl" ]]; then
    fail "$name" "episodes.index.jsonl was created but is deferred to a follow-up"
    return 0
  fi
  pass "$name"
}

case_memory_shard_help_exit0() {
  local name="pmctl memory shard: --help exits 0 with usage"
  should_run "$name" || return 0
  local out status=0
  out="$(CLAUDE_CONFIG_DIR="/dev/null" "$PMCTL" memory shard --help 2>&1)" || status=$?
  if [[ "$status" -ne 0 ]]; then
    fail "$name" "--help exited $status; output: $out"
    return 0
  fi
  if ! printf '%s' "$out" | grep -qi "usage"; then
    fail "$name" "--help output lacks 'Usage'; output: $out"
    return 0
  fi
  pass "$name"
}

case_memory_shard_at_exact_limit() {
  local name="pmctl memory shard: exactly at EP_SHARD_LINE_LIMIT (1000) — no shard needed"
  should_run "$name" || return 0

  local cfg repo mdir
  cfg="$(mktemp -d -p "$tmp_root")"
  repo="$(mktemp -d -p "$tmp_root")"
  mdir="$(make_fixture_memory "$cfg" "$repo")"

  local ep="$mdir/episodes.jsonl"
  local cur_ym i
  cur_ym="$(date -u +%Y-%m 2>/dev/null || date +%Y-%m)"
  # Write exactly 1000 entries (the limit is -le 1000, so 1000 must NOT shard).
  for i in $(seq 1 1000); do
    printf '{"date":"%s-01","cwd":"%s","session_id":"s%d","summary":"entry %d"}\n' \
      "$cur_ym" "$repo" "$i" "$i" >> "$ep"
  done

  local out status=0
  out="$(CLAUDE_CONFIG_DIR="$cfg" "$PMCTL" memory shard --repo-root "$repo" 2>&1)" || status=$?
  if [[ "$status" -ne 0 ]]; then
    fail "$name" "exited $status; output: $out"
    return 0
  fi
  if ! printf '%s' "$out" | grep -q "no shard needed"; then
    fail "$name" "expected 'no shard needed' at exactly 1000 lines, got: $out"
    return 0
  fi
  local shards
  shards="$(find "$mdir" -name 'episodes.????-??.jsonl' 2>/dev/null | wc -l)"
  if [[ "$shards" -ne 0 ]]; then
    fail "$name" "expected 0 shard files at limit, got $shards"
    return 0
  fi
  pass "$name"
}

case_memory_shard_repo_root_missing_operand_exit2() {
  local name="pmctl memory shard: --repo-root missing value exits 2"
  should_run "$name" || return 0
  local status=0
  CLAUDE_CONFIG_DIR="/dev/null" "$PMCTL" memory shard --repo-root 2>/dev/null || status=$?
  if [[ "$status" -ne 2 ]]; then
    fail "$name" "expected exit 2 for missing --repo-root operand, got $status"
    return 0
  fi
  pass "$name"
}

case_memory_rebuild_summary_repo_root_missing_operand_exit2() {
  local name="pmctl memory rebuild-summary: --repo-root missing value exits 2"
  should_run "$name" || return 0
  local status=0
  CLAUDE_CONFIG_DIR="/dev/null" "$PMCTL" memory rebuild-summary --repo-root 2>/dev/null || status=$?
  if [[ "$status" -ne 2 ]]; then
    fail "$name" "expected exit 2 for missing --repo-root operand, got $status"
    return 0
  fi
  pass "$name"
}

case_memory_shard_unknown_arg_exit2() {
  local name="pmctl memory shard: unknown argument exits 2"
  should_run "$name" || return 0
  local status=0
  CLAUDE_CONFIG_DIR="/dev/null" "$PMCTL" memory shard --bogus-flag 2>/dev/null || status=$?
  if [[ "$status" -ne 2 ]]; then
    fail "$name" "expected exit 2 for unknown arg, got $status"
    return 0
  fi
  pass "$name"
}

case_memory_shard_no_episodes_file() {
  local name="pmctl memory shard: no episodes.jsonl exits 0 with message"
  should_run "$name" || return 0
  local cfg repo mdir
  cfg="$(mktemp -d -p "$tmp_root")"
  repo="$(mktemp -d -p "$tmp_root")"
  mdir="$(make_fixture_memory "$cfg" "$repo")"
  # Do NOT create episodes.jsonl.
  local out status=0
  out="$(CLAUDE_CONFIG_DIR="$cfg" "$PMCTL" memory shard --repo-root "$repo" 2>&1)" || status=$?
  if [[ "$status" -ne 0 ]]; then
    fail "$name" "expected exit 0, got $status; output: $out"
    return 0
  fi
  if ! printf '%s' "$out" | grep -q "no episodes"; then
    fail "$name" "expected 'no episodes' in output; got: $out"
    return 0
  fi
  pass "$name"
}

case_memory_rebuild_summary_help_exit0() {
  local name="pmctl memory rebuild-summary: --help exits 0 with usage"
  should_run "$name" || return 0
  local out status=0
  out="$(CLAUDE_CONFIG_DIR="/dev/null" "$PMCTL" memory rebuild-summary --help 2>&1)" || status=$?
  if [[ "$status" -ne 0 ]]; then
    fail "$name" "--help exited $status; output: $out"
    return 0
  fi
  if ! printf '%s' "$out" | grep -qi "usage"; then
    fail "$name" "--help output lacks 'Usage'; output: $out"
    return 0
  fi
  pass "$name"
}

case_memory_rebuild_summary_unknown_arg_exit2() {
  local name="pmctl memory rebuild-summary: unknown argument exits 2"
  should_run "$name" || return 0
  local status=0
  CLAUDE_CONFIG_DIR="/dev/null" "$PMCTL" memory rebuild-summary --bogus-flag 2>/dev/null || status=$?
  if [[ "$status" -ne 2 ]]; then
    fail "$name" "expected exit 2 for unknown arg, got $status"
    return 0
  fi
  pass "$name"
}

case_memory_rebuild_summary_no_episodes_file() {
  local name="pmctl memory rebuild-summary: no episodes.jsonl exits 0 with message"
  should_run "$name" || return 0
  local cfg repo mdir
  cfg="$(mktemp -d -p "$tmp_root")"
  repo="$(mktemp -d -p "$tmp_root")"
  mdir="$(make_fixture_memory "$cfg" "$repo")"
  # Do NOT create episodes.jsonl.
  local out status=0
  out="$(CLAUDE_CONFIG_DIR="$cfg" "$PMCTL" memory rebuild-summary --repo-root "$repo" 2>&1)" || status=$?
  if [[ "$status" -ne 0 ]]; then
    fail "$name" "expected exit 0, got $status; output: $out"
    return 0
  fi
  if ! printf '%s' "$out" | grep -q "no episodes"; then
    fail "$name" "expected 'no episodes' in output; got: $out"
    return 0
  fi
  pass "$name"
}

case_memory_doctor_ignores_episodes_summary() {
  local name="pmctl memory doctor: episodes.summary.md is NOT reported as orphan or missing-fields card"
  should_run "$name" || return 0

  local cfg repo mdir
  cfg="$(mktemp -d -p "$tmp_root")"
  repo="$(mktemp -d -p "$tmp_root")"
  mdir="$(make_fixture_memory "$cfg" "$repo")"

  write_compliant_card "$mdir/card.md" "card"
  printf -- '- [Card](card.md) — some hook\n' > "$mdir/MEMORY.md"
  printf '{"date":"2026-06-01","cwd":"%s","session_id":"a","summary":"entry"}\n' "$repo" > "$mdir/episodes.jsonl"

  # Produce episodes.summary.md via rebuild-summary.
  local rs_status=0
  CLAUDE_CONFIG_DIR="$cfg" "$PMCTL" memory rebuild-summary --repo-root "$repo" >/dev/null 2>&1 || rs_status=$?
  if [[ "$rs_status" -ne 0 ]]; then
    fail "$name" "rebuild-summary failed with exit $rs_status"
    return 0
  fi
  if [[ ! -f "$mdir/episodes.summary.md" ]]; then
    fail "$name" "episodes.summary.md not created"
    return 0
  fi

  # Doctor should report issues_count 0 (no orphan, no missing-fields for summary).
  local out status=0
  out="$(CLAUDE_CONFIG_DIR="$cfg" "$PMCTL" memory doctor --repo-root "$repo" --json 2>&1)" || status=$?

  local issues
  issues="$(printf '%s' "$out" | grep -o '"issues_count":[0-9]*' | grep -o '[0-9]*')"
  if [[ "$issues" != "0" ]]; then
    fail "$name" "expected issues_count=0 but got $issues; doctor output: $out"
    return 0
  fi

  local orphans
  orphans="$(printf '%s' "$out" | grep -o '"orphan_cards":\[[^]]*\]')"
  if printf '%s' "$orphans" | grep -q "episodes.summary.md"; then
    fail "$name" "episodes.summary.md wrongly appeared in orphan_cards: $orphans"
    return 0
  fi
  pass "$name"
}

case_memory_doctor_shard_count() {
  local name="pmctl memory doctor: shard_count reflects episodes shard files"
  should_run "$name" || return 0

  local cfg repo mdir
  cfg="$(mktemp -d -p "$tmp_root")"
  repo="$(mktemp -d -p "$tmp_root")"
  mdir="$(make_fixture_memory "$cfg" "$repo")"

  write_compliant_card "$mdir/card.md" "card"
  printf -- '- [Card](card.md) — some hook\n' > "$mdir/MEMORY.md"
  printf '{"date":"2026-05-01","cwd":"%s","session_id":"a","summary":"entry"}\n' "$repo" > "$mdir/episodes.jsonl"

  # No shard files yet — shard_count should be 0.
  local out0
  out0="$(CLAUDE_CONFIG_DIR="$cfg" "$PMCTL" memory doctor --repo-root "$repo" --json 2>&1)" || true
  local cnt0
  cnt0="$(printf '%s' "$out0" | grep -o '"shard_count":[0-9]*' | grep -o '[0-9]*')"
  if [[ "$cnt0" != "0" ]]; then
    fail "$name" "expected shard_count=0 with no shard files, got: $cnt0"
    return 0
  fi

  # Create two shard files.
  printf '{"date":"2026-03-01","session_id":"x","summary":"old"}\n' > "$mdir/episodes.2026-03.jsonl"
  printf '{"date":"2026-04-01","session_id":"y","summary":"old"}\n' > "$mdir/episodes.2026-04.jsonl"

  local out2 status2=0
  out2="$(CLAUDE_CONFIG_DIR="$cfg" "$PMCTL" memory doctor --repo-root "$repo" --json 2>&1)" || status2=$?
  local cnt2
  cnt2="$(printf '%s' "$out2" | grep -o '"shard_count":[0-9]*' | grep -o '[0-9]*')"
  if [[ "$cnt2" != "2" ]]; then
    fail "$name" "expected shard_count=2 with two shard files, got: $cnt2"
    return 0
  fi
  pass "$name"
}

# ── Stats cases ───────────────────────────────────────────────────────────────

# Run stats against a fixture; writes JSON to $1, returns the exit code.
run_stats_json() {
  local out="$1" cfg="$2" repo="$3"; shift 3
  local status=0
  CLAUDE_CONFIG_DIR="$cfg" "$PMCTL" memory stats --repo-root "$repo" --json "$@" \
    > "$out" 2>/dev/null || status=$?
  return "$status"
}

# Fixture with $2 linked cards and a MEMORY.md index. Echoes the memory dir.
make_stats_fixture() {
  local cfg="$1" repo="$2" count="$3" mdir i
  mkdir -p "$repo"
  mdir="$(make_fixture_memory "$cfg" "$repo")"
  : > "$mdir/MEMORY.md"
  for ((i = 1; i <= count; i++)); do
    write_compliant_card "$mdir/card$i.md" "card$i"
    printf -- '- [Card %d](card%d.md) — hook %d\n' "$i" "$i" "$i" >> "$mdir/MEMORY.md"
  done
  printf '%s' "$mdir"
}

# Behavior: with no usage sidecar every indexed card reports as never-hit and the report still succeeds.
# Steps: build a 3-card fixture with no sidecar; run stats --json; assert counts, usage_store none, and zero-denominator percentages.
case_memory_stats_no_usage_all_never_hit() {
  local name="pmctl memory stats: no usage sidecar → every card never-hit, exit 0"
  should_run "$name" || return 0

  local cfg="$tmp_root/st-none-cfg" repo="$tmp_root/st-none-repo" mdir out="$tmp_root/st-none.json" status=0
  mdir="$(make_stats_fixture "$cfg" "$repo" 3)"
  run_stats_json "$out" "$cfg" "$repo" || status=$?
  if ! assert_exit "$name" "$status" 0; then return 0; fi
  assert_jq "$name" "$out" '.schema_version == 1' || return 0
  assert_jq "$name" "$out" '.card_count == 3 and .index_entry_count == 3' || return 0
  assert_jq "$name" "$out" '.usage_store == "none"' || return 0
  assert_jq "$name" "$out" '.cards_with_hits == 0 and .cards_never_hit == 3' || return 0
  assert_jq "$name" "$out" '(.never_hit_cards | length) == 3' || return 0
  # An empty denominator must report 0, never divide by zero or emit a blank.
  assert_jq "$name" "$out" '.concentration.hit_coverage_pct == 0 and .concentration.top5_share_pct == 0' || return 0
  # index_inject_bytes must reflect real index lines, not a placeholder.
  assert_jq "$name" "$out" '.index_inject_bytes > 0' || return 0
  assert_jq "$name" "$out" ".inject_budget_entries == $MEMORY_MAX_INJECT_ENTRIES and .inject_budget_bytes == $MEMORY_MAX_INJECT_BYTES" || return 0
  pass "$name"
}

# Behavior: recorded sidecar accesses drive coverage, total_access, concentration, and recency buckets.
# Steps: seed 3 accesses on card1 and 1 on card2; run stats --json; assert hit/never-hit split, totals, top5 share, and bucket placement.
case_memory_stats_usage_hits_and_concentration() {
  local name="pmctl memory stats: sidecar hits drive coverage, total_access, and top5 share"
  should_run "$name" || return 0

  local cfg="$tmp_root/st-hit-cfg" repo="$tmp_root/st-hit-repo" mdir out="$tmp_root/st-hit.json" status=0
  mdir="$(make_stats_fixture "$cfg" "$repo" 4)"

  # card1 x3, card2 x1; card3/card4 never accessed. Threshold is far above the
  # event count so W-TinyLFU decay cannot halve the counts mid-test.
  local sidecar today
  sidecar="$(memory_usage_sidecar_path "$mdir")"
  today=$(( $(date +%s) / 86400 ))
  memory_usage_commit "$sidecar" 100000 "$today" card1.md card1.md card1.md card2.md >/dev/null

  run_stats_json "$out" "$cfg" "$repo" || status=$?
  if ! assert_exit "$name" "$status" 0; then return 0; fi
  assert_jq "$name" "$out" '.cards_with_hits == 2 and .cards_never_hit == 2' || return 0
  assert_jq "$name" "$out" '.total_access == 4' || return 0
  # Fewer than 5 hit cards → top5 covers everything → share is 100%.
  assert_jq "$name" "$out" '.concentration.top5_access == 4 and .concentration.top5_share_pct == 100' || return 0
  assert_jq "$name" "$out" '.concentration.hit_coverage_pct == 50' || return 0
  assert_jq "$name" "$out" '(.never_hit_cards | sort) == ["card3.md","card4.md"]' || return 0
  # Accesses were committed with today's day stamp → most-recent bucket only.
  assert_jq "$name" "$out" '.last_hit_buckets.recent_0_4 == 2' || return 0
  assert_jq "$name" "$out" '[.last_hit_buckets | to_entries[] | select(.key != "recent_0_4") | .value] | add == 0' || return 0
  pass "$name"
}

# Behavior: two index lines linking one card count as two entries but one card for usage purposes.
# Steps: index the same card file twice and record one access; run stats --json; assert index_entry_count 2, card_count 1, and un-inflated totals.
case_memory_stats_duplicate_index_link_counted_once() {
  local name="pmctl memory stats: two index lines linking one card count as one card"
  should_run "$name" || return 0

  local cfg="$tmp_root/st-dup-cfg" repo="$tmp_root/st-dup-repo" mdir out="$tmp_root/st-dup.json" status=0
  mkdir -p "$repo"
  mdir="$(make_fixture_memory "$cfg" "$repo")"
  write_compliant_card "$mdir/dup.md" "dup"
  printf -- '- [Dup A](dup.md) — hook a\n- [Dup B](dup.md) — hook b\n' > "$mdir/MEMORY.md"

  local sidecar today
  sidecar="$(memory_usage_sidecar_path "$mdir")"
  today=$(( $(date +%s) / 86400 ))
  memory_usage_commit "$sidecar" 100000 "$today" dup.md >/dev/null

  run_stats_json "$out" "$cfg" "$repo" || status=$?
  if ! assert_exit "$name" "$status" 0; then return 0; fi
  # Ranking is per line, so entries stay 2; usage is keyed per card, so 1.
  assert_jq "$name" "$out" '.index_entry_count == 2 and .card_count == 1' || return 0
  # Without dedup this would report total_access 2 and coverage over 2 cards.
  assert_jq "$name" "$out" '.cards_with_hits == 1 and .total_access == 1' || return 0
  assert_jq "$name" "$out" '.concentration.hit_coverage_pct == 100' || return 0
  pass "$name"
}

# Behavior: the episode fill rate counts only summaries with non-whitespace content.
# Steps: write 4 episodes of which one has real text; run stats --json; assert totals and a 25 percent fill rate.
case_memory_stats_episode_fill_rate() {
  local name="pmctl memory stats: episode fill rate counts only non-whitespace summaries"
  should_run "$name" || return 0

  local cfg="$tmp_root/st-ep-cfg" repo="$tmp_root/st-ep-repo" mdir out="$tmp_root/st-ep.json" status=0
  mdir="$(make_stats_fixture "$cfg" "$repo" 1)"
  {
    printf '{"date":"2026-08-01","session_id":"a","summary":"real work"}\n'
    printf '{"date":"2026-08-02","session_id":"b","summary":""}\n'
    printf '{"date":"2026-08-03","session_id":"c"}\n'
    # A whitespace-only summary is an empty skeleton, not a logged episode.
    printf '{"date":"2026-08-04","session_id":"d","summary":"   "}\n'
  } > "$mdir/episodes.jsonl"

  run_stats_json "$out" "$cfg" "$repo" || status=$?
  if ! assert_exit "$name" "$status" 0; then return 0; fi
  assert_jq "$name" "$out" '.episodes_total == 4 and .episodes_with_summary == 1' || return 0
  assert_jq "$name" "$out" '.episode_fill_rate_pct == 25' || return 0
  pass "$name"
}

# Behavior: --never-hit-limit bounds the listed never-hit cards without capping the count.
# Steps: build a 5-card fixture with no usage; run stats with limit 2 then 0; assert list length, uncapped count, and the truncation flag.
case_memory_stats_never_hit_limit() {
  local name="pmctl memory stats: --never-hit-limit caps the list but not the count"
  should_run "$name" || return 0

  local cfg="$tmp_root/st-lim-cfg" repo="$tmp_root/st-lim-repo" out="$tmp_root/st-lim.json" status=0
  make_stats_fixture "$cfg" "$repo" 5 >/dev/null

  run_stats_json "$out" "$cfg" "$repo" --never-hit-limit 2 || status=$?
  if ! assert_exit "$name" "$status" 0; then return 0; fi
  assert_jq "$name" "$out" '(.never_hit_cards | length) == 2' || return 0
  assert_jq "$name" "$out" '.cards_never_hit == 5' || return 0
  assert_jq "$name" "$out" '.never_hit_cards_truncated == true' || return 0

  # 0 means "no cap", not "list nothing".
  local out0="$tmp_root/st-lim0.json" status0=0
  run_stats_json "$out0" "$cfg" "$repo" --never-hit-limit 0 || status0=$?
  if ! assert_exit "$name" "$status0" 0; then return 0; fi
  assert_jq "$name" "$out0" '(.never_hit_cards | length) == 5' || return 0
  assert_jq "$name" "$out0" '.never_hit_cards_truncated == false' || return 0
  pass "$name"
}

# Behavior: a repo with no resolvable memory dir yields an empty but well-formed report.
# Steps: point stats at a repo with no projects memory dir; run stats --json; assert exit 0 and zeroed counts.
case_memory_stats_no_memory_dir() {
  local name="pmctl memory stats: no memory dir → empty report, exit 0"
  should_run "$name" || return 0

  local cfg="$tmp_root/st-nodir-cfg" repo="$tmp_root/st-nodir-repo" out="$tmp_root/st-nodir.json" status=0
  mkdir -p "$repo" "$cfg/projects"
  run_stats_json "$out" "$cfg" "$repo" || status=$?
  if ! assert_exit "$name" "$status" 0; then return 0; fi
  assert_jq "$name" "$out" '.card_count == 0 and .cards_with_hits == 0' || return 0
  assert_jq "$name" "$out" '.episode_fill_rate_pct == 0' || return 0
  pass "$name"
}

# Behavior: an unrecognized flag is a usage error rather than a silently ignored argument.
# Steps: build a fixture; run stats with --frobnicate; assert exit 2.
case_memory_stats_unknown_flag_exit2() {
  local name="pmctl memory stats: unknown flag → exit 2"
  should_run "$name" || return 0

  local cfg="$tmp_root/st-uf-cfg" repo="$tmp_root/st-uf-repo" status=0
  make_stats_fixture "$cfg" "$repo" 1 >/dev/null
  CLAUDE_CONFIG_DIR="$cfg" "$PMCTL" memory stats --repo-root "$repo" --frobnicate \
    >/dev/null 2>&1 || status=$?
  if assert_exit "$name" "$status" 2; then pass "$name"; fi
}

# Behavior: --never-hit-limit rejects non-numeric and missing operands with the documented diagnostic.
# Steps: run stats with a non-numeric limit then with no operand; assert exit 2 and the specific stderr message for each.
case_memory_stats_bad_never_hit_limit_exit2() {
  local name="pmctl memory stats: non-numeric --never-hit-limit → exit 2 + error"
  should_run "$name" || return 0

  local err="$tmp_root/st-badlim.err" status=0
  "$PMCTL" memory stats --never-hit-limit abc >/dev/null 2>"$err" || status=$?
  if ! assert_exit "$name" "$status" 2; then return 0; fi
  if ! assert_file_contains "$name" "$err" 'non-negative integer'; then return 0; fi

  # A missing operand is a distinct usage error, not a silent default.
  local err2="$tmp_root/st-nolim.err" status2=0
  "$PMCTL" memory stats --never-hit-limit >/dev/null 2>"$err2" || status2=$?
  if ! assert_exit "$name" "$status2" 2; then return 0; fi
  if ! assert_file_contains "$name" "$err2" '--never-hit-limit requires a value'; then return 0; fi
  pass "$name"
}

# Behavior: --help prints the usage contract and exits successfully.
# Steps: run stats --help; capture stdout; assert exit 0 and that the usage line and --never-hit-limit appear.
case_memory_stats_help_exit0() {
  local name="pmctl memory stats: --help → exit 0 + usage contract"
  should_run "$name" || return 0

  local out="$tmp_root/st-help.txt" status=0
  "$PMCTL" memory stats --help > "$out" 2>&1 || status=$?
  if ! assert_exit "$name" "$status" 0; then return 0; fi
  if ! assert_file_contains "$name" "$out" 'Usage: pmctl memory stats'; then return 0; fi
  if ! assert_file_contains "$name" "$out" '--never-hit-limit'; then return 0; fi
  pass "$name"
}

# Behavior: an invalid PM_MEMORY_DIR fails closed in both output modes instead of reporting the legacy store.
# Steps: create a fixture holding a sentinel card, run stats with a nonexistent PM_MEMORY_DIR in JSON then human mode; assert exit 1, resolution_issues fields, and no sentinel leak.
case_memory_stats_invalid_env_selection_fails_closed() {
  local name="pmctl memory stats: invalid PM_MEMORY_DIR → exit 1, resolution_issues, no legacy fallback"
  should_run "$name" || return 0

  # A perfectly good legacy store exists at the conventional location. An
  # explicit-but-invalid selection must NOT silently report it: that would make
  # a misconfigured host look healthy while describing another project's memory.
  local cfg="$tmp_root/st-badenv-cfg" repo="$tmp_root/st-badenv-repo" mdir
  mdir="$(make_stats_fixture "$cfg" "$repo" 3)"
  local sentinel="card2.md"

  local out="$tmp_root/st-badenv.json" status=0
  PM_MEMORY_DIR="$tmp_root/does-not-exist-anywhere" CLAUDE_CONFIG_DIR="$cfg" \
    "$PMCTL" memory stats --repo-root "$repo" --json > "$out" 2>/dev/null || status=$?
  if ! assert_exit "$name" "$status" 1; then return 0; fi
  assert_jq "$name" "$out" '.schema_version == 1' || return 0
  assert_jq "$name" "$out" '.memory_dir == ""' || return 0
  assert_jq "$name" "$out" '(.resolution_issues | length) == 1' || return 0
  assert_jq "$name" "$out" '.resolution_issues[0].reason | length > 0' || return 0
  assert_jq "$name" "$out" '.resolution_issues[0] | has("source")' || return 0
  # Fallback proof: nothing from the legacy store may appear in the report.
  if grep -q "$sentinel" "$out" 2>/dev/null; then
    fail "$name" "invalid explicit selection fell back to the legacy store: $(cat "$out")"
    return 0
  fi
  if grep -qF "$mdir" "$out" 2>/dev/null; then
    fail "$name" "invalid explicit selection leaked the legacy memory dir: $(cat "$out")"
    return 0
  fi

  # Human mode must fail closed identically, not degrade into a normal report.
  local hout="$tmp_root/st-badenv.txt" hstatus=0
  PM_MEMORY_DIR="$tmp_root/does-not-exist-anywhere" CLAUDE_CONFIG_DIR="$cfg" \
    "$PMCTL" memory stats --repo-root "$repo" > "$hout" 2>/dev/null || hstatus=$?
  if ! assert_exit "$name" "$hstatus" 1; then return 0; fi
  if ! assert_file_contains "$name" "$hout" 'invalid explicit configuration'; then return 0; fi
  if ! assert_file_contains "$name" "$hout" 'resolution_issues'; then return 0; fi
  if grep -q "$sentinel" "$hout" 2>/dev/null; then
    fail "$name" "human mode fell back to the legacy store: $(cat "$hout")"
    return 0
  fi
  pass "$name"
}

# Behavior: a configured memory_dir that does not exist fails closed rather than falling back.
# Steps: write a project config naming a missing memory dir; run stats --json; assert exit 1, one resolution issue, and no legacy path in the output.
case_memory_stats_invalid_config_selection_fails_closed() {
  local name="pmctl memory stats: invalid configured memory_dir → exit 1, no legacy fallback"
  should_run "$name" || return 0

  local cfg="$tmp_root/st-badcfg-cfg" repo="$tmp_root/st-badcfg-repo"
  local fakehome="$tmp_root/st-badcfg-home" mdir
  mdir="$(make_stats_fixture "$cfg" "$repo" 2)"
  mkdir -p "$fakehome/.pm-dispatch"
  # Config names a memory dir that does not exist — a matched-but-absent
  # selection, which is distinct from "no configuration at all".
  write_project_memory_config "$fakehome/.pm-dispatch/config" "$repo" \
    "$tmp_root/st-badcfg-missing-target"

  local out="$tmp_root/st-badcfg.json" status=0
  PM_DISPATCH_CONFIG_FILE="$fakehome/.pm-dispatch/config" CLAUDE_CONFIG_DIR="$cfg" \
    "$PMCTL" memory stats --repo-root "$repo" --json > "$out" 2>/dev/null || status=$?
  if ! assert_exit "$name" "$status" 1; then return 0; fi
  assert_jq "$name" "$out" '(.resolution_issues | length) == 1' || return 0
  if grep -qF "$mdir" "$out" 2>/dev/null; then
    fail "$name" "invalid configured selection fell back to the legacy store: $(cat "$out")"
    return 0
  fi
  pass "$name"
}

# Behavior: a tab in an indexed card path still yields parseable, value-preserving JSON.
# Steps: index a card whose filename contains a tab; run stats --json; assert jq parses it and the name round-trips exactly.
case_memory_stats_json_escapes_control_characters() {
  local name="pmctl memory stats: a tab in an indexed path stays valid, value-preserving JSON"
  should_run "$name" || return 0

  # Tabs are legal in POSIX filenames. A hand-built JSON emitter that only
  # escapes \n and \r produces a document no parser accepts.
  local cfg="$tmp_root/st-ctl-cfg" repo="$tmp_root/st-ctl-repo" mdir
  mkdir -p "$repo"
  mdir="$(make_fixture_memory "$cfg" "$repo")"
  local tabbed=$'ta\tbbed.md'
  write_compliant_card "$mdir/$tabbed" "tabbed"
  printf -- '- [Tabbed](%s) — hook\n' "$tabbed" > "$mdir/MEMORY.md"

  local out="$tmp_root/st-ctl.json" status=0
  run_stats_json "$out" "$cfg" "$repo" || status=$?
  if ! assert_exit "$name" "$status" 0; then return 0; fi
  if [[ "$_HAVE_JQ" -eq 1 ]]; then
    if ! jq -e . "$out" >/dev/null 2>&1; then
      fail "$name" "emitted JSON is unparseable: $(cat "$out")"
      return 0
    fi
    # Escaping must not corrupt the value — it round-trips to the exact name.
    # jq reads \t in this filter as a real tab, so this compares against the
    # literal filename, not against its escaped spelling. A tab-bearing path is
    # reported as unmeasurable (its usage cannot be recorded), not never-hit.
    assert_jq "$name" "$out" '.unmeasurable_cards[0] == "ta\tbbed.md"' || return 0
  fi
  pass "$name"
}

# Behavior: a corrupt usage sidecar reports usage_store error instead of a successful zero-activity report.
# Steps: run stats with no sidecar, then corrupt the SQLite store and rerun; assert none versus error and the human-mode warning.
case_memory_stats_unreadable_sidecar_is_not_zero_activity() {
  local name="pmctl memory stats: unreadable sidecar reports usage_store=error, not silent zero activity"
  should_run "$name" || return 0

  local cfg="$tmp_root/st-corrupt-cfg" repo="$tmp_root/st-corrupt-repo" mdir
  mdir="$(make_stats_fixture "$cfg" "$repo" 2)"
  mkdir -p "$mdir/.pm-dispatch"

  # Absent sidecar first: this is a legitimate zero-activity report.
  local absent="$tmp_root/st-absent.json" astatus=0
  run_stats_json "$absent" "$cfg" "$repo" || astatus=$?
  if ! assert_exit "$name" "$astatus" 0; then return 0; fi
  assert_jq "$name" "$absent" '.usage_store == "none" and .cards_with_hits == 0' || return 0

  # Now a present but unreadable store. Both cases yield zero rows; only one of
  # them is evidence that the cards went unused.
  #
  # Corrupt the store rather than chmod it: a permission-based fixture is a
  # no-op for a root test runner, which would leave this case green even if the
  # error branch were deleted. Corruption fails the read for every uid.
  local sidecar; sidecar="$(memory_usage_sidecar_path "$mdir")"
  if [[ "$sidecar" != *.sqlite3 ]]; then
    # Without sqlite3 the sidecar is a plain TSV that `cat` reads regardless of
    # content, so this boundary has no deterministic failure to stage here.
    pass "$name"
    return 0
  fi
  printf 'this is not a sqlite database at all\n' > "$sidecar"

  local out="$tmp_root/st-corrupt.json" status=0
  run_stats_json "$out" "$cfg" "$repo" || status=$?
  if ! assert_exit "$name" "$status" 0; then return 0; fi
  assert_jq "$name" "$out" '.usage_store == "error"' || return 0
  # A degraded read must not masquerade as measured zero activity.
  assert_jq "$name" "$out" '.cards_with_hits == 0 and .total_access == 0' || return 0

  local hout="$tmp_root/st-corrupt.txt" hstatus=0
  CLAUDE_CONFIG_DIR="$cfg" "$PMCTL" memory stats --repo-root "$repo" > "$hout" 2>/dev/null || hstatus=$?
  if ! assert_exit "$name" "$hstatus" 0; then return 0; fi
  if ! assert_file_contains "$name" "$hout" 'NOT evidence of no activity'; then return 0; fi
  pass "$name"
}

# Behavior: the report names each card's own hit count and last-hit day, ordered most-hit first.
# Steps: seed 3 accesses on card2 and 1 on card1; run stats --json and human; assert ordering, exact counts, and that --hit-limit does not alter totals.
case_memory_stats_reports_per_card_hit_counts() {
  local name="pmctl memory stats: reports each card's hit count and last-hit day, most-hit first"
  should_run "$name" || return 0

  # CC-467 Requirement 1 asks for per-card hit counts, not only aggregates:
  # global totals cannot tell a maintainer WHICH card is repeatedly selected.
  local cfg="$tmp_root/st-percard-cfg" repo="$tmp_root/st-percard-repo" mdir
  mdir="$(make_stats_fixture "$cfg" "$repo" 3)"
  local sidecar today
  sidecar="$(memory_usage_sidecar_path "$mdir")"
  today=$(( $(date +%s) / 86400 ))
  memory_usage_commit "$sidecar" 100000 "$today" card1.md card2.md card2.md card2.md >/dev/null

  local out="$tmp_root/st-percard.json" status=0
  run_stats_json "$out" "$cfg" "$repo" || status=$?
  if ! assert_exit "$name" "$status" 0; then return 0; fi
  assert_jq "$name" "$out" '(.card_hits | length) == 2' || return 0
  # Ordered most-hit first, with the exact counts — not a bucket or a share.
  assert_jq "$name" "$out" '.card_hits[0].card == "card2.md" and .card_hits[0].access_count == 3' || return 0
  assert_jq "$name" "$out" '.card_hits[1].card == "card1.md" and .card_hits[1].access_count == 1' || return 0
  assert_jq "$name" "$out" ".card_hits[0].last_access_day == $today" || return 0
  assert_jq "$name" "$out" '.card_hits_truncated == false' || return 0
  # Never-hit cards belong in never_hit_cards, never as a zero-count hit row.
  assert_jq "$name" "$out" '[.card_hits[] | select(.access_count == 0)] | length == 0' || return 0

  # Human mode must carry the same per-card counts.
  local hout="$tmp_root/st-percard.txt"
  CLAUDE_CONFIG_DIR="$cfg" "$PMCTL" memory stats --repo-root "$repo" > "$hout" 2>/dev/null || true
  if ! assert_file_contains "$name" "$hout" 'card_hits'; then return 0; fi
  if ! grep -qE '^  - 3 +card2\.md' "$hout"; then
    fail "$name" "human mode lacks the per-card count row: $(cat "$hout")"
    return 0
  fi

  # --hit-limit bounds the list without falsifying the counts.
  local lout="$tmp_root/st-percard-lim.json" lstatus=0
  run_stats_json "$lout" "$cfg" "$repo" --hit-limit 1 || lstatus=$?
  if ! assert_exit "$name" "$lstatus" 0; then return 0; fi
  assert_jq "$name" "$lout" '(.card_hits | length) == 1 and .card_hits_truncated == true' || return 0
  assert_jq "$name" "$lout" '.cards_with_hits == 2 and .total_access == 4' || return 0
  pass "$name"
}

# Behavior: --hit-limit honors zero as no-cap and rejects missing, option-like, malformed, and oversized operands.
# Steps: seed 3 hit cards; run stats with limit 0 then 1; then run the four invalid operand forms; assert list sizes, unchanged totals, and exit 2 with this command's own diagnostic.
case_memory_stats_hit_limit_boundaries() {
  local name="pmctl memory stats: --hit-limit boundary contract (0, missing, option-like, malformed, oversized)"
  should_run "$name" || return 0

  local cfg="$tmp_root/st-hlb-cfg" repo="$tmp_root/st-hlb-repo" mdir
  mdir="$(make_stats_fixture "$cfg" "$repo" 3)"
  local sidecar today
  sidecar="$(memory_usage_sidecar_path "$mdir")"
  today=$(( $(date +%s) / 86400 ))
  memory_usage_commit "$sidecar" 100000 "$today" card1.md card2.md card3.md >/dev/null

  # 0 means "no cap", not "hide every row" — the inverse would silently make
  # the report look like there is no hit evidence at all.
  local out0="$tmp_root/st-hlb0.json" s0=0
  run_stats_json "$out0" "$cfg" "$repo" --hit-limit 0 || s0=$?
  if ! assert_exit "$name" "$s0" 0; then return 0; fi
  assert_jq "$name" "$out0" '(.card_hits | length) == 3 and .card_hits_truncated == false' || return 0

  # Bounding the list must never change the totals it is a view of.
  local out1="$tmp_root/st-hlb1.json" s1=0
  run_stats_json "$out1" "$cfg" "$repo" --hit-limit 1 || s1=$?
  if ! assert_exit "$name" "$s1" 0; then return 0; fi
  assert_jq "$name" "$out1" '(.card_hits | length) == 1 and .card_hits_truncated == true' || return 0
  assert_jq "$name" "$out1" '.cards_with_hits == 3 and .total_access == 3' || return 0

  local err status
  # missing operand
  err="$tmp_root/st-hlb-missing.err"; status=0
  "$PMCTL" memory stats --hit-limit >/dev/null 2>"$err" || status=$?
  if ! assert_exit "$name" "$status" 2; then return 0; fi
  if ! assert_file_contains "$name" "$err" '--hit-limit requires a value'; then return 0; fi

  # option-like operand
  err="$tmp_root/st-hlb-optlike.err"; status=0
  "$PMCTL" memory stats --hit-limit --json >/dev/null 2>"$err" || status=$?
  if ! assert_exit "$name" "$status" 2; then return 0; fi
  if ! assert_file_contains "$name" "$err" '--hit-limit requires a value'; then return 0; fi

  # non-numeric
  err="$tmp_root/st-hlb-nan.err"; status=0
  "$PMCTL" memory stats --hit-limit 3x >/dev/null 2>"$err" || status=$?
  if ! assert_exit "$name" "$status" 2; then return 0; fi
  if ! assert_file_contains "$name" "$err" 'non-negative integer'; then return 0; fi

  # oversized: must be this command's diagnostic, not a raw shell arithmetic error
  err="$tmp_root/st-hlb-big.err"; status=0
  "$PMCTL" memory stats --hit-limit 99999999999999999999999999 >/dev/null 2>"$err" || status=$?
  if ! assert_exit "$name" "$status" 2; then return 0; fi
  if ! assert_file_contains "$name" "$err" 'non-negative integer'; then return 0; fi
  if grep -qi 'value too great\|syntax error' "$err"; then
    fail "$name" "leaked a raw shell arithmetic error: $(cat "$err")"
    return 0
  fi
  pass "$name"
}

# Behavior: hit rows order by count numerically, so a count past a fixed pad width cannot sort below a smaller one.
# Steps: seed counts straddling the ten-digit boundary via the TSV sidecar; run stats --json; assert descending card order and the exact largest count.
case_memory_stats_hit_rows_sort_numerically() {
  local name="pmctl memory stats: hit rows order by count numerically, not by a padded lexical key"
  should_run "$name" || return 0

  # A fixed-width zero-padded sort key silently inverts ordering once a counter
  # exceeds the pad width. Seed counts that straddle a 10-digit boundary.
  local cfg="$tmp_root/st-sort-cfg" repo="$tmp_root/st-sort-repo" mdir
  mdir="$(make_stats_fixture "$cfg" "$repo" 3)"
  mkdir -p "$mdir/.pm-dispatch"
  local today; today=$(( $(date +%s) / 86400 ))
  {
    printf '# total_events=0\n'
    printf 'card1.md\t10000000000\t%d\n' "$today"
    printf 'card2.md\t9999999999\t%d\n'  "$today"
    printf 'card3.md\t5\t%d\n'           "$today"
  } > "$mdir/.pm-dispatch/inject-usage.tsv"

  local out="$tmp_root/st-sort.json" status=0
  run_stats_json "$out" "$cfg" "$repo" || status=$?
  if ! assert_exit "$name" "$status" 0; then return 0; fi
  assert_jq "$name" "$out" '[.card_hits[].card] == ["card1.md","card2.md","card3.md"]' || return 0
  assert_jq "$name" "$out" '.card_hits[0].access_count == 10000000000' || return 0
  pass "$name"
}

# Behavior: JSON output escapes C1 controls while leaving CJK card names intact.
# Steps: place a C1-bearing orphan card beside an indexed CJK card; run stats and doctor with --json; assert no raw 0x9b byte, parseable JSON, and an exact CJK round-trip.
case_memory_stats_json_escapes_c1_controls() {
  local name="pmctl memory stats --json: C1 controls are escaped and CJK card names survive"
  should_run "$name" || return 0

  # JSON output is routinely read straight in a terminal, so a raw 0x9B CSI in
  # an indexed filename is a live injection vector there too — and a raw C1
  # byte is not valid UTF-8, so emitting it also breaks the document.
  local cfg="$tmp_root/st-jc1-cfg" repo="$tmp_root/st-jc1-repo" mdir
  mkdir -p "$repo"
  mdir="$(make_fixture_memory "$cfg" "$repo")"
  # The stats path must actually RENDER a C1 value, or the assertions below are
  # vacuous. A raw 0x9B is invalid UTF-8 and defeats bash's index-link regex, so
  # such a card never reaches stats output at all. Index the UTF-8 encoding of
  # the same code point (0xC2 0x9B) instead: it parses as a link, flows into
  # never_hit_cards, and exercises the escaper's C1 branch for real. The raw
  # byte is kept as an unindexed orphan so doctor still covers that form.
  local c1raw=$'a\x9b31mX.md'
  local c1utf=$'u\xc2\x9b31mX.md'
  local cjk=$'中文記憶卡.md'
  write_compliant_card "$mdir/$c1raw" "c1raw"
  write_compliant_card "$mdir/$c1utf" "c1utf"
  write_compliant_card "$mdir/$cjk" "cjk"
  {
    printf -- '- [C1](%s) — hook\n' "$c1utf"
    printf -- '- [CJK](%s) — hook\n' "$cjk"
  } > "$mdir/MEMORY.md"

  local out="$tmp_root/st-jc1.json" status=0
  run_stats_json "$out" "$cfg" "$repo" || status=$?
  if ! assert_exit "$name" "$status" 0; then return 0; fi
  if LC_ALL=C grep -q $'\x9b' "$out"; then
    fail "$name" "stats JSON retained a raw C1 (0x9b) byte"
    return 0
  fi
  if [[ "$_HAVE_JQ" -eq 1 ]]; then
    if ! jq -e . "$out" >/dev/null 2>&1; then
      fail "$name" "emitted JSON is unparseable: $(cat "$out")"
      return 0
    fi
    # CJK must round-trip exactly; escaping its continuation bytes would corrupt it.
    assert_jq "$name" "$out" '.never_hit_cards | index("中文記憶卡.md") != null' || return 0
    # The indexed C1 card is present, and jq decodes it back to the exact
    # original bytes: escaped on the wire, value-preserving on read.
    assert_jq "$name" "$out" '.never_hit_cards | index("u\u009b31mX.md") != null' || return 0
  fi
  # The escape must be the literal \u009b sequence, not the raw code point.
  if ! assert_file_contains "$name" "$out" '\u009b'; then return 0; fi

  # doctor shares the emitter and reports the C1 card as an orphan.
  local dout="$tmp_root/st-jc1-doctor.json"
  CLAUDE_CONFIG_DIR="$cfg" "$PMCTL" memory doctor --repo-root "$repo" --json > "$dout" 2>/dev/null || true
  if LC_ALL=C grep -q $'\x9b' "$dout"; then
    fail "$name" "doctor JSON retained a raw C1 (0x9b) byte"
    return 0
  fi
  if [[ "$_HAVE_JQ" -eq 1 ]] && ! jq -e . "$dout" >/dev/null 2>&1; then
    fail "$name" "doctor JSON is unparseable: $(cat "$dout")"
    return 0
  fi
  pass "$name"
}

# Behavior: an index entry with no parseable .md link is reported separately, not counted as a card.
# Steps: index one valid card plus a malformed and a non-.md entry; run stats --json; assert card_count, coverage, and the separate unparsed count.
case_memory_stats_unparsed_index_entries_excluded() {
  local name="pmctl memory stats: unparseable index entries do not enter card_count or coverage"
  should_run "$name" || return 0

  # card_count is documented as distinct linked card FILES. Counting a non-card
  # entry would inflate cards_never_hit and depress hit_coverage_pct, making a
  # documented per-card ratio quietly measure something else.
  local cfg="$tmp_root/st-unparsed-cfg" repo="$tmp_root/st-unparsed-repo" mdir
  mkdir -p "$repo"
  mdir="$(make_fixture_memory "$cfg" "$repo")"
  write_compliant_card "$mdir/real.md" "real"
  {
    printf -- '- [Real](real.md) — hook\n'
    printf -- '- [Notes](notes.txt) — a link that is not a card file\n'
    printf -- '- [Broken] no link at all\n'
  } > "$mdir/MEMORY.md"

  local sidecar today
  sidecar="$(memory_usage_sidecar_path "$mdir")"
  today=$(( $(date +%s) / 86400 ))
  memory_usage_commit "$sidecar" 100000 "$today" real.md >/dev/null

  local out="$tmp_root/st-unparsed.json" status=0
  run_stats_json "$out" "$cfg" "$repo" || status=$?
  if ! assert_exit "$name" "$status" 0; then return 0; fi
  assert_jq "$name" "$out" '.index_entry_count == 3' || return 0
  assert_jq "$name" "$out" '.card_count == 1' || return 0
  assert_jq "$name" "$out" '.unparsed_index_entries == 2' || return 0
  # The one real card is hit, so coverage is a clean 100 percent.
  assert_jq "$name" "$out" '.cards_with_hits == 1 and .cards_never_hit == 0' || return 0
  assert_jq "$name" "$out" '.concentration.hit_coverage_pct == 100' || return 0
  assert_jq "$name" "$out" '.never_hit_cards == []' || return 0
  pass "$name"
}

# Behavior: a card path the tab-delimited sidecar cannot represent reports as unmeasurable rather than never-hit.
# Steps: index one tab-bearing card and one plain card; run stats --json; assert the tab card appears only under unmeasurable_cards.
case_memory_stats_unrecordable_card_is_not_never_hit() {
  local name="pmctl memory stats: a tab-bearing card path is unmeasurable, not never-hit"
  should_run "$name" || return 0

  # The sidecar is tab-delimited and memory_usage_commit refuses such a relpath,
  # so its usage can never be recorded. Calling it "never hit" would assert an
  # absence of use that this telemetry never measured.
  local cfg="$tmp_root/st-unmeas-cfg" repo="$tmp_root/st-unmeas-repo" mdir
  mkdir -p "$repo"
  mdir="$(make_fixture_memory "$cfg" "$repo")"
  local tabbed=$'ta\tb.md'
  write_compliant_card "$mdir/$tabbed" "tabbed"
  write_compliant_card "$mdir/plain.md" "plain"
  {
    printf -- '- [Tabbed](%s) — hook\n' "$tabbed"
    printf -- '- [Plain](plain.md) — hook\n'
  } > "$mdir/MEMORY.md"

  local out="$tmp_root/st-unmeas.json" status=0
  run_stats_json "$out" "$cfg" "$repo" || status=$?
  if ! assert_exit "$name" "$status" 0; then return 0; fi
  assert_jq "$name" "$out" '(.unmeasurable_cards | length) == 1' || return 0
  assert_jq "$name" "$out" '.unmeasurable_cards[0] == "ta\tb.md"' || return 0
  # It must NOT be double-counted as a never-hit card.
  assert_jq "$name" "$out" '[.never_hit_cards[] | select(test("\t"))] | length == 0' || return 0
  assert_jq "$name" "$out" '.never_hit_cards == ["plain.md"]' || return 0
  pass "$name"
}

# Behavior: unparseable episode rows are counted and surfaced instead of being silently dropped.
# Steps: write an episodes file with one valid and two malformed rows; run stats --json and human; assert the malformed count, status, and that a clean file reports zero malformed.
case_memory_stats_malformed_episodes_are_not_zero_history() {
  local name="pmctl memory stats: malformed episode rows are counted, not silently dropped"
  should_run "$name" || return 0

  local cfg="$tmp_root/st-epbad-cfg" repo="$tmp_root/st-epbad-repo" mdir
  mdir="$(make_stats_fixture "$cfg" "$repo" 1)"
  {
    printf '{"date":"2026-08-01","session_id":"a","summary":"real work"}\n'
    printf '{"date":"2026-08-02","session_id":"b"\n'
    printf 'not json at all\n'
  } > "$mdir/episodes.jsonl"

  local out="$tmp_root/st-epbad.json" status=0
  run_stats_json "$out" "$cfg" "$repo" || status=$?
  if ! assert_exit "$name" "$status" 0; then return 0; fi
  # Corrupt rows must be visible: treating them as "no history" could drive a
  # destructive retention decision.
  assert_jq "$name" "$out" '.episodes_malformed == 2' || return 0
  assert_jq "$name" "$out" '.episodes_total == 1 and .episodes_with_summary == 1' || return 0
  assert_jq "$name" "$out" '.episodes_status == "ok"' || return 0

  local hout="$tmp_root/st-epbad.txt"
  CLAUDE_CONFIG_DIR="$cfg" "$PMCTL" memory stats --repo-root "$repo" > "$hout" 2>/dev/null || true
  if ! assert_file_contains "$name" "$hout" 'malformed row'; then return 0; fi

  # A clean file must NOT claim malformed rows.
  local cfg2="$tmp_root/st-epok-cfg" repo2="$tmp_root/st-epok-repo" mdir2
  mdir2="$(make_stats_fixture "$cfg2" "$repo2" 1)"
  printf '{"date":"2026-08-01","session_id":"a","summary":"x"}\n' > "$mdir2/episodes.jsonl"
  local out2="$tmp_root/st-epok.json"
  run_stats_json "$out2" "$cfg2" "$repo2" || true
  assert_jq "$name" "$out2" '.episodes_malformed == 0 and .episodes_status == "ok"' || return 0
  pass "$name"
}

# Behavior: human output neutralizes C1 controls without mangling CJK card names.
# Steps: place a C1-bearing orphan card beside an indexed CJK card; run doctor then stats in human mode; assert no raw 0x9b byte, an escaped form, and an intact CJK name.
case_memory_human_output_neutralizes_c1_controls() {
  local name="pmctl memory stats/doctor: C1 controls are neutralized without mangling CJK names"
  should_run "$name" || return 0

  # 0x9B is CSI on an 8-bit-capable emulator and is NOT matched by [[:cntrl:]].
  # The same byte range is UTF-8's continuation range, so a naive bytewise
  # sanitizer would corrupt this repo's own Chinese card names — assert both.
  local cfg="$tmp_root/st-c1-cfg" repo="$tmp_root/st-c1-repo" mdir
  mkdir -p "$repo"
  mdir="$(make_fixture_memory "$cfg" "$repo")"
  local c1raw=$'a\x9b31mX.md'
  local c1utf=$'u\xc2\x9b31mX.md'
  local cjk=$'中文記憶卡.md'
  write_compliant_card "$mdir/$c1raw" "c1raw"
  write_compliant_card "$mdir/$c1utf" "c1utf"
  write_compliant_card "$mdir/$cjk" "cjk"
  # Two C1 forms, two render paths. The raw 0x9B byte defeats bash's index-link
  # regex, so it can only reach output through doctor's orphan-card glob; the
  # UTF-8 encoding of the same code point parses as a link and so is the form
  # that actually exercises the stats renderer.
  {
    printf -- '- [C1](%s) — hook\n' "$c1utf"
    printf -- '- [CJK](%s) — hook\n' "$cjk"
  } > "$mdir/MEMORY.md"

  local dout="$tmp_root/st-c1-doctor.txt"
  CLAUDE_CONFIG_DIR="$cfg" "$PMCTL" memory doctor --repo-root "$repo" > "$dout" 2>/dev/null || true
  if LC_ALL=C grep -q $'\x9b' "$dout"; then
    fail "$name" "doctor human output retained a raw C1 (0x9b) byte"
    return 0
  fi
  if ! assert_file_contains "$name" "$dout" '\x9b'; then return 0; fi

  # The CJK card is indexed and compliant, so doctor lists it nowhere; stats
  # names it under never_hit_cards. It must survive intact there — a bytewise
  # sanitizer would escape its UTF-8 continuation bytes and corrupt it.
  local out="$tmp_root/st-c1.txt" status=0
  CLAUDE_CONFIG_DIR="$cfg" "$PMCTL" memory stats --repo-root "$repo" > "$out" 2>/dev/null || status=$?
  if ! assert_exit "$name" "$status" 0; then return 0; fi
  if LC_ALL=C grep -q $'\x9b' "$out"; then
    fail "$name" "stats human output retained a raw C1 (0x9b) byte"
    return 0
  fi
  if ! assert_file_contains "$name" "$out" "$cjk"; then return 0; fi
  pass "$name"
}

# Behavior: illegal UTF-8 sequences are escaped bytewise while legal multi-byte characters pass through.
# Steps: source the library; escape overlong, surrogate, above-U+10FFFF, CJK, and 4-byte emoji values; assert the illegal ones are escaped and the legal ones are byte-identical.
case_memory_escapers_reject_illegal_utf8() {
  local name="memory escapers: overlong, surrogate, and above-U+10FFFF sequences are escaped, not emitted raw"
  should_run "$name" || return 0

  # Validating only "lead byte plus continuation bytes" admits sequences that
  # are structurally shaped like UTF-8 but illegal, so they would be emitted raw
  # inside a document that claims to be JSON.
  # shellcheck source=runtime/lib/pmctl-memory.sh
  # shellcheck disable=SC1091
  . "$REPO_ROOT/runtime/lib/pmctl-memory.sh"

  local got
  # Non-shortest form of U+0000.
  got="$(_mem_json_esc $'\xe0\x80\x80')"
  if [[ "$got" != '\u00e0\u0080\u0080' ]]; then
    fail "$name" "overlong sequence not escaped: [$got]"
    return 0
  fi
  # UTF-8-encoded surrogate D800, which is not a legal scalar value.
  got="$(_mem_json_esc $'\xed\xa0\x80')"
  if [[ "$got" != '\u00ed\u00a0\u0080' ]]; then
    fail "$name" "encoded surrogate not escaped: [$got]"
    return 0
  fi
  # Above U+10FFFF.
  got="$(_mem_json_esc $'\xf4\x90\x80\x80')"
  if [[ "$got" != '\u00f4\u0090\u0080\u0080' ]]; then
    fail "$name" "above-U+10FFFF sequence not escaped: [$got]"
    return 0
  fi
  # Legal multi-byte input must be byte-identical — the tightened validation
  # must not start escaping ordinary CJK or 4-byte characters.
  got="$(_mem_json_esc '中文.md')"
  if [[ "$got" != '中文.md' ]]; then
    fail "$name" "legal CJK was altered: [$got]"
    return 0
  fi
  got="$(_mem_json_esc $'\xf0\x9f\x98\x80')"
  if [[ "$got" != $'\xf0\x9f\x98\x80' ]]; then
    fail "$name" "legal 4-byte character was altered: [$got]"
    return 0
  fi
  # The human renderer shares the validation and must agree.
  got="$(_mem_human_safe $'\xe0\x80\x80')"
  if [[ "$got" != '\xe0\x80\x80' ]]; then
    fail "$name" "human renderer left an overlong sequence unescaped: [$got]"
    return 0
  fi
  pass "$name"
}

# Behavior: an oversized sidecar counter degrades the read instead of wrapping into a negative total.
# Steps: write a sidecar row with a 26-digit access count; run stats --json; assert usage_store error and a non-negative total.
case_memory_stats_oversized_counter_degrades() {
  local name="pmctl memory stats: an oversized sidecar counter degrades rather than wrapping negative"
  should_run "$name" || return 0

  # Bash arithmetic silently wraps past 2^63 instead of failing, so an
  # unbounded counter would produce a negative total_access in a report used
  # for retention decisions — a wrong number is worse than a loud failure.
  local cfg="$tmp_root/st-bigcnt-cfg" repo="$tmp_root/st-bigcnt-repo" mdir
  mdir="$(make_stats_fixture "$cfg" "$repo" 2)"
  mkdir -p "$mdir/.pm-dispatch"
  local today; today=$(( $(date +%s) / 86400 ))
  {
    printf '# total_events=0\n'
    printf 'card1.md\t99999999999999999999999999\t%d\n' "$today"
    printf 'card2.md\t3\t%d\n' "$today"
  } > "$mdir/.pm-dispatch/inject-usage.tsv"

  local out="$tmp_root/st-bigcnt.json" status=0
  run_stats_json "$out" "$cfg" "$repo" || status=$?
  if ! assert_exit "$name" "$status" 0; then return 0; fi
  assert_jq "$name" "$out" '.usage_store == "error"' || return 0
  assert_jq "$name" "$out" '.total_access >= 0' || return 0
  assert_jq "$name" "$out" '[.card_hits[] | select(.access_count < 0)] | length == 0' || return 0
  pass "$name"
}

# Behavior: a newline inside a memory-derived path is escaped, never swallowed into a joined string.
# Steps: source the library; escape a two-segment newline-bearing value in JSON and human form; assert each segment survives around an explicit escape.
case_memory_escapers_preserve_embedded_newlines() {
  local name="memory escapers: an embedded newline is escaped, not silently closed up"
  should_run "$name" || return 0

  # A newline is legal in a POSIX path. Both escapers run the value through awk,
  # which consumes newlines as record separators — without re-emitting them,
  # "a<NL>b" renders as "ab" and attributes data to an object that never existed.
  # shellcheck source=runtime/lib/pmctl-memory.sh
  # shellcheck disable=SC1091
  . "$REPO_ROOT/runtime/lib/pmctl-memory.sh"

  local got
  got="$(_mem_json_esc $'a\nb')"
  if [[ "$got" != 'a\nb' ]]; then
    fail "$name" "json escaper produced [$got], expected [a\\nb]"
    return 0
  fi
  got="$(_mem_human_safe $'a\nb')"
  if [[ "$got" != 'a\x0ab' ]]; then
    fail "$name" "human escaper produced [$got], expected [a\\x0ab]"
    return 0
  fi
  # Ordinary and multi-byte values must be untouched by the separator handling.
  got="$(_mem_json_esc 'plain.md')"
  if [[ "$got" != 'plain.md' ]]; then
    fail "$name" "json escaper altered a plain value: [$got]"
    return 0
  fi
  got="$(_mem_json_esc '中文.md')"
  if [[ "$got" != '中文.md' ]]; then
    fail "$name" "json escaper mangled a CJK value: [$got]"
    return 0
  fi
  pass "$name"
}

# Behavior: the shared memory readers on the prompt hook's path declare no bash 4.3 namerefs.
# Steps: scan memory.sh, pmctl-memory.sh, and guard-inject-memory.sh; grep for nameref declarations; fail naming the offending file if any is found.
case_memory_shared_readers_avoid_bash_43_namerefs() {
  local name="memory shared readers: no bash-4.3 namerefs in the hook's library path"
  should_run "$name" || return 0

  # memory_usage_load originally took caller-named arrays via `local -n`, which
  # requires bash 4.3 and would have been this repo's only such dependency —
  # in a shared library sourced by the prompt hook. Pin the decision so it
  # cannot creep back in unnoticed.
  local f
  for f in "$REPO_ROOT/runtime/lib/memory.sh" \
           "$REPO_ROOT/runtime/lib/pmctl-memory.sh" \
           "$REPO_ROOT/runtime/hooks/guard-inject-memory.sh"; do
    if grep -nE '(local|declare|typeset)[[:space:]]+(-[A-Za-z]*n[A-Za-z]*)[[:space:]]' "$f" >/dev/null 2>&1; then
      fail "$name" "nameref declaration found in $f: $(grep -nE '(local|declare|typeset)[[:space:]]+-[A-Za-z]*n[A-Za-z]*[[:space:]]' "$f")"
      return 0
    fi
  done
  pass "$name"
}

# Behavior: an option-like operand is treated as a missing value rather than a path.
# Steps: run stats with --repo-root --json then --never-hit-limit --json; assert exit 2 and the requires-a-value diagnostic for each.
case_memory_stats_option_like_operand_is_usage_error() {
  local name="pmctl memory stats: an option-like operand is a missing value, not a path"
  should_run "$name" || return 0

  # `--repo-root --json` must not be parsed as a request to stat a repository
  # literally named "--json"; that silently drops the caller's --json intent.
  local err="$tmp_root/st-optlike.err" status=0
  "$PMCTL" memory stats --repo-root --json > /dev/null 2>"$err" || status=$?
  if ! assert_exit "$name" "$status" 2; then return 0; fi
  if ! assert_file_contains "$name" "$err" '--repo-root requires a value'; then return 0; fi

  local err2="$tmp_root/st-optlike2.err" status2=0
  "$PMCTL" memory stats --never-hit-limit --json > /dev/null 2>"$err2" || status2=$?
  if ! assert_exit "$name" "$status2" 2; then return 0; fi
  if ! assert_file_contains "$name" "$err2" '--never-hit-limit requires a value'; then return 0; fi
  pass "$name"
}

# Behavior: a numeric limit wider than a shell integer exits 2 with this command's diagnostic.
# Steps: run stats with a 26-digit --never-hit-limit; assert exit 2, the non-negative-integer message, and no raw shell arithmetic error.
case_memory_stats_oversized_limit_is_usage_error() {
  local name="pmctl memory stats: a numeric --never-hit-limit wider than a shell integer exits 2"
  should_run "$name" || return 0

  # Syntactically numeric but unrepresentable: without a width bound this
  # reaches the arithmetic conversion and dies with a raw bash error instead of
  # this command's documented usage-error contract.
  local err="$tmp_root/st-bignum.err" status=0
  "$PMCTL" memory stats --never-hit-limit 99999999999999999999999999 \
    > /dev/null 2>"$err" || status=$?
  if ! assert_exit "$name" "$status" 2; then return 0; fi
  if ! assert_file_contains "$name" "$err" 'non-negative integer'; then return 0; fi
  # The diagnostic must be this command's, not bash's arithmetic error.
  if grep -qi 'value too great\|syntax error' "$err"; then
    fail "$name" "leaked a raw shell arithmetic error: $(cat "$err")"
    return 0
  fi
  pass "$name"
}

# Behavior: human output renders ESC-bearing index paths as inert escaped text.
# Steps: index a card whose filename embeds an OSC sequence; run stats then doctor in human mode; assert no raw ESC byte survives in either.
case_memory_human_output_neutralizes_terminal_controls() {
  local name="pmctl memory stats/doctor: human output neutralizes terminal control sequences"
  should_run "$name" || return 0

  # Anyone who can add a MEMORY.md index entry could otherwise embed an OSC/ESC
  # sequence that the reader's terminal executes when the report is displayed.
  local cfg="$tmp_root/st-esc-cfg" repo="$tmp_root/st-esc-repo" mdir
  mkdir -p "$repo"
  mdir="$(make_fixture_memory "$cfg" "$repo")"
  local evil=$'ev\x1b]0;pwned\x07il.md'
  write_compliant_card "$mdir/$evil" "evil"
  printf -- '- [Evil](%s) — hook\n' "$evil" > "$mdir/MEMORY.md"

  local out="$tmp_root/st-esc.txt" status=0
  CLAUDE_CONFIG_DIR="$cfg" "$PMCTL" memory stats --repo-root "$repo" > "$out" 2>/dev/null || status=$?
  if ! assert_exit "$name" "$status" 0; then return 0; fi
  if LC_ALL=C grep -q $'\x1b' "$out"; then
    fail "$name" "stats human output retained an ESC byte"
    return 0
  fi
  if ! assert_file_contains "$name" "$out" '\x1b'; then return 0; fi

  # doctor renders the same index-derived data and must not be the soft spot.
  local dout="$tmp_root/st-esc-doctor.txt"
  CLAUDE_CONFIG_DIR="$cfg" "$PMCTL" memory doctor --repo-root "$repo" > "$dout" 2>/dev/null || true
  if LC_ALL=C grep -q $'\x1b' "$dout"; then
    fail "$name" "doctor human output retained an ESC byte"
    return 0
  fi
  pass "$name"
}

# Behavior: last-hit bucket labels match the day boundaries memory_age_bucket actually applies.
# Steps: seed five cards at 0, 5, 20, 60, and 200 days old via the TSV sidecar; run stats --json; assert exactly one card lands in each labeled bucket.
case_memory_stats_age_buckets_match_frecency_boundaries() {
  local name="pmctl memory stats: last_hit bucket labels match memory_age_bucket's real boundaries"
  should_run "$name" || return 0

  local cfg="$tmp_root/st-age-cfg" repo="$tmp_root/st-age-repo" mdir out="$tmp_root/st-age.json" status=0
  mdir="$(make_stats_fixture "$cfg" "$repo" 5)"

  # Seed the legacy TSV directly: memory_usage_commit always stamps today, and
  # these cases need specific last_access days. memory_usage_read falls back to
  # the TSV when no sqlite store exists, so this works with or without sqlite3.
  local today; today=$(( $(date +%s) / 86400 ))
  mkdir -p "$mdir/.pm-dispatch"
  {
    printf '# total_events=5\n'
    # One card per bucket, at a day distance inside each labeled range.
    printf 'card1.md\t1\t%d\n' $(( today - 0 ))
    printf 'card2.md\t1\t%d\n' $(( today - 5 ))
    printf 'card3.md\t1\t%d\n' $(( today - 20 ))
    printf 'card4.md\t1\t%d\n' $(( today - 60 ))
    printf 'card5.md\t1\t%d\n' $(( today - 200 ))
  } > "$mdir/.pm-dispatch/inject-usage.tsv"

  run_stats_json "$out" "$cfg" "$repo" || status=$?
  if ! assert_exit "$name" "$status" 0; then return 0; fi
  assert_jq "$name" "$out" '.cards_with_hits == 5' || return 0
  # The label day ranges are only honest while these land one-per-bucket. If
  # memory_age_bucket's boundaries move, this fails instead of the report
  # quietly mislabeling recency tiers.
  assert_jq "$name" "$out" '
    .last_hit_buckets
    | .recent_0_4 == 1 and .recent_5_14 == 1 and .recent_15_31 == 1
      and .recent_32_90 == 1 and .older_90_plus == 1' || return 0
  pass "$name"
}

# Behavior: running stats writes nothing to the memory dir and accrues no synthetic access.
# Steps: seed one access, fingerprint the memory dir, run stats --json, re-fingerprint; assert identical trees and an unchanged total_access.
case_memory_stats_is_read_only() {
  local name="pmctl memory stats: does not write to the memory dir or the usage sidecar"
  should_run "$name" || return 0

  local cfg="$tmp_root/st-ro-cfg" repo="$tmp_root/st-ro-repo" mdir out="$tmp_root/st-ro.json" status=0
  mdir="$(make_stats_fixture "$cfg" "$repo" 2)"
  local sidecar today
  sidecar="$(memory_usage_sidecar_path "$mdir")"
  today=$(( $(date +%s) / 86400 ))
  memory_usage_commit "$sidecar" 100000 "$today" card1.md >/dev/null

  local before after
  before="$(find "$mdir" -type f -printf '%P:%s\n' 2>/dev/null | sort)"
  run_stats_json "$out" "$cfg" "$repo" || status=$?
  if ! assert_exit "$name" "$status" 0; then return 0; fi
  after="$(find "$mdir" -type f -printf '%P:%s\n' 2>/dev/null | sort)"
  if [[ "$before" != "$after" ]]; then
    fail "$name" "stats mutated the memory dir: before/after differ"
    return 0
  fi
  # Reading must not accrue a synthetic access for the reporting run itself.
  assert_jq "$name" "$out" '.total_access == 1' || return 0
  pass "$name"
}

# Behavior: every host appends through the same project-scoped canonical path.
# Steps: append one marker per host through one scoped config and assert JSONL/provenance.
case_memory_append_episode_cross_host_contract() {
  local name="pmctl memory append-episode: Claude Codex OpenCode Grok and generic share canonical path"
  should_run "$name" || return 0
  local repo="$tmp_root/append-cross-host-repo" mdir="$tmp_root/append-cross-host-memory"
  local config="$tmp_root/append-cross-host.conf" host out status=0
  mkdir -p "$repo" "$mdir"
  git -C "$repo" init -q
  write_project_memory_config "$config" "$repo" "$mdir"
  for host in claude codex opencode grok generic; do
    out="$(PM_DISPATCH_CONFIG_FILE="$config" "$PMCTL" memory append-episode --repo-root "$repo" --host "$host" \
      --session-id "session-$host" --date "2026-07-13T00:00:00Z" --summary "${host}-canonical-marker" --json 2>/dev/null)" || status=$?
    if [[ "$status" -ne 0 ]] || ! jq -e --arg host "$host" --arg mdir "$mdir" \
        '.provider == "pmctl" and .authority == "canonical" and .writer_host == $host and .memory_dir == $mdir and .episode.writer_host == $host' <<<"$out" >/dev/null; then
      fail "$name" "host=$host status=$status out=$out"; return 0
    fi
  done
  if [[ "$(wc -l < "$mdir/episodes.jsonl" | tr -d ' ')" == "5" ]] \
    && jq -e -s 'map(.writer_host) == ["claude","codex","opencode","grok","generic"]' "$mdir/episodes.jsonl" >/dev/null; then
    pass "$name"
  else
    fail "$name" "episodes=$(cat "$mdir/episodes.jsonl" 2>/dev/null || true)"
  fi
}

case_memory_append_episode_requires_host() {
  local name="pmctl memory append-episode: shared writer requires explicit initiating host"
  should_run "$name" || return 0
  local repo="$tmp_root/append-host-required-repo" mdir="$tmp_root/append-host-required-memory" out status=0
  mkdir -p "$repo" "$mdir"; git -C "$repo" init -q
  out="$(PM_MEMORY_DIR="$mdir" "$PMCTL" memory append-episode --repo-root "$repo" --summary must-not-default 2>&1)" || status=$?
  if [[ "$status" -eq 2 && "$out" == *"--host is required"* && ! -e "$mdir/episodes.jsonl" ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$out"
  fi
}

# Behavior: the write API never falls through from an invalid explicit path to legacy memory.
# Steps: create writable legacy memory, select a missing PM_MEMORY_DIR, and assert no episode is written.
case_memory_append_episode_invalid_explicit_no_fallback() {
  local name="pmctl memory append-episode: invalid explicit path fails closed without legacy write"
  should_run "$name" || return 0
  local repo="$tmp_root/append-invalid-repo" cfg="$tmp_root/append-invalid-cfg" missing="$tmp_root/append-missing" out="$tmp_root/append-invalid.out" legacy status=0
  mkdir -p "$repo"
  git -C "$repo" init -q
  legacy="$(make_fixture_memory "$cfg" "$repo")"
  PM_MEMORY_DIR="$missing" CLAUDE_CONFIG_DIR="$cfg" "$PMCTL" memory append-episode --repo-root "$repo" \
    --host codex --summary 'must-not-land' --json > "$out" 2>&1 || status=$?
  if [[ "$status" -eq 3 && ! -e "$legacy/episodes.jsonl" ]] && grep -q 'canonical memory resolution failed' "$out"; then
    pass "$name"
  else
    fail "$name" "status=$status legacy_episode=$([[ -e "$legacy/episodes.jsonl" ]] && printf yes || printf no) out=$(<"$out")"
  fi
}

# Behavior: an episode written by one host is immediately queryable through the shared pmctl memory plane.
# Steps: Codex appends a unique marker, then a host-neutral memory query retrieves episodes.jsonl.
case_memory_append_episode_query_round_trip() {
  local name="pmctl memory append-episode: Codex write is queryable by shared memory retrieval"
  should_run "$name" || return 0
  command -v sqlite3 >/dev/null 2>&1 || { pass "$name (sqlite unavailable)"; return 0; }
  local repo="$tmp_root/append-query-repo" mdir="$tmp_root/append-query-memory" marker="cc483codexwriteroundtrip" out status=0
  mkdir -p "$repo" "$mdir"
  git -C "$repo" init -q
  PM_MEMORY_DIR="$mdir" "$PMCTL" memory append-episode --repo-root "$repo" --host codex --summary "$marker" --json >/dev/null 2>&1 || status=$?
  out="$(PM_MEMORY_DIR="$mdir" "$PMCTL" context query "$repo" --source memory -- "$marker" 2>/dev/null || true)"
  if [[ "$status" -eq 0 && "$out" == *"episodes.jsonl"* ]]; then
    pass "$name"
  else
    fail "$name" "status=$status query=$out"
  fi
}

# Behavior: the generic lifecycle fallback is owned by the strict resolver, not a hook-local reimplementation.
# Steps: resolve a non-git cwd with the explicit opt-in and assert deterministic canonical provenance.
case_memory_resolve_allows_generic_non_git() {
  local name="pmctl memory resolve: generic non-git fallback stays structured"
  should_run "$name" || return 0
  local cwd="$tmp_root/resolve-generic-cwd" cfg="$tmp_root/resolve-generic-cfg" mdir out status=0
  mkdir -p "$cwd"
  mdir="$(make_fixture_memory "$cfg" "$cwd")"
  out="$(CLAUDE_CONFIG_DIR="$cfg" "$PMCTL" memory resolve --repo-root "$cwd" --allow-non-git --json 2>/dev/null)" || status=$?
  if [[ "$status" -eq 0 ]] && jq -e --arg cwd "$cwd" --arg mdir "$mdir" \
      '.status == "resolved" and .repo_root == $cwd and .memory_dir == $mdir and .resolution_source == "legacy" and (.project_key | length) > 0' <<<"$out" >/dev/null; then
    pass "$name"
  else
    fail "$name" "status=$status out=$out"
  fi
}

# Behavior: skeleton dedupe is performed inside the canonical append lock.
# Steps: launch concurrent Stop-style writes for one session and assert one JSONL record.
case_memory_append_episode_concurrent_skeleton_dedupe() {
  local name="pmctl memory append-episode: concurrent skeleton writes deduplicate"
  should_run "$name" || return 0
  local repo="$tmp_root/append-skeleton-repo" mdir="$tmp_root/append-skeleton-memory" i failed=0
  mkdir -p "$repo" "$mdir"
  git -C "$repo" init -q
  for i in 1 2 3 4 5 6; do
    PM_MEMORY_DIR="$mdir" "$PMCTL" memory append-episode --repo-root "$repo" --host claude \
      --session-id shared-stop-session --summary "" --skeleton >/dev/null 2>&1 &
  done
  wait || failed=1
  if [[ "$failed" -eq 0 && "$(wc -l < "$mdir/episodes.jsonl" | tr -d ' ')" == "1" ]] \
    && jq -e -s 'length == 1 and .[0].session_id == "shared-stop-session" and .[0].summary == ""' "$mdir/episodes.jsonl" >/dev/null; then
    pass "$name"
  else
    fail "$name" "failed=$failed episodes=$(cat "$mdir/episodes.jsonl" 2>/dev/null || true)"
  fi
}

# Behavior: canonical writes refuse an episodes.jsonl symlink even when its target is writable.
# Steps: point episodes.jsonl at an external file and assert the command fails without changing it.
case_memory_append_episode_refuses_symlink() {
  local name="pmctl memory append-episode: refuses symlink target"
  should_run "$name" || return 0
  local repo="$tmp_root/append-symlink-repo" mdir="$tmp_root/append-symlink-memory" target="$tmp_root/external-episodes" out status=0
  mkdir -p "$repo" "$mdir"
  git -C "$repo" init -q
  printf 'sentinel\n' > "$target"
  ln -s "$target" "$mdir/episodes.jsonl"
  out="$(PM_MEMORY_DIR="$mdir" "$PMCTL" memory append-episode --repo-root "$repo" --host generic --summary must-not-land 2>&1)" || status=$?
  if [[ "$status" -eq 1 && "$(<"$target")" == "sentinel" && "$out" == *"refusing symlink target"* ]]; then
    pass "$name"
  else
    fail "$name" "status=$status target=$(<"$target") out=$out"
  fi
}

# Behavior: a target swapped to a symlink immediately before commit cannot redirect the canonical write.
# Steps: intercept the final rename, install a symlink to an external sentinel, and assert rename replaces only the link.
case_memory_append_episode_symlink_swap_race() {
  local name="pmctl memory append-episode: atomic commit defeats symlink swap race"
  should_run "$name" || return 0
  # shellcheck disable=SC1091
  . "$REPO_ROOT/runtime/lib/pmctl-memory.sh"
  local mdir="$tmp_root/append-race-memory" episodes target append_dir json_line status=0 swapped=0
  mkdir -p "$mdir"
  episodes="$mdir/episodes.jsonl"
  target="$tmp_root/append-race-external"
  append_dir="$mdir/.pm-dispatch"
  printf 'sentinel\n' > "$target"
  _pmctl_memory_secure_append_dir "$append_dir"
  json_line='{"date":"2026-07-14T00:00:00Z","cwd":"/tmp/race","session_id":"race","summary":"atomic","writer_host":"codex"}'
  # shellcheck disable=SC2329,SC2317  # invoked indirectly by the sourced append helper.
  mv() {
    if [[ "$swapped" -eq 0 && "${*: -1}" == "$episodes" ]]; then
      ln -sf -- "$target" "$episodes"
      swapped=1
    fi
    command mv "$@"
  }
  _pmctl_memory_append_episode_inner "$episodes" "$json_line" summary race "$append_dir" || status=$?
  unset -f mv
  if [[ "$status" -eq 0 && "$swapped" -eq 1 && ! -L "$episodes" ]] \
    && [[ "$(<"$target")" == "sentinel" ]] \
    && jq -e '.summary == "atomic" and .writer_host == "codex"' "$episodes" >/dev/null 2>&1; then
    pass "$name"
  else
    fail "$name" "status=$status swapped=$swapped target=$(<"$target") episodes=$(cat "$episodes" 2>/dev/null || true)"
  fi
}

# Behavior: the append lock/work directory cannot be redirected through a symlink.
# Steps: symlink .pm-dispatch to an external directory and assert fail-closed with no episode artifacts.
case_memory_append_episode_refuses_symlink_lock_dir() {
  local name="pmctl memory append-episode: refuses symlink lock directory"
  should_run "$name" || return 0
  local repo="$tmp_root/append-lock-repo" mdir="$tmp_root/append-lock-memory" external="$tmp_root/append-lock-external" out status=0
  mkdir -p "$repo" "$mdir" "$external"
  git -C "$repo" init -q
  ln -s "$external" "$mdir/.pm-dispatch"
  out="$(PM_MEMORY_DIR="$mdir" "$PMCTL" memory append-episode --repo-root "$repo" --host codex --summary must-not-land 2>&1)" || status=$?
  if [[ "$status" -eq 1 && "$out" == *"refusing symlink lock directory"* ]] \
    && [[ ! -e "$mdir/episodes.jsonl" && -z "$(find "$external" -mindepth 1 -print -quit)" ]]; then
    pass "$name"
  else
    fail "$name" "status=$status out=$out external=$(find "$external" -mindepth 1 -print 2>/dev/null || true)"
  fi
}

# Behavior: one config file can safely map independent repositories without a
# machine-wide fallback, and an unmatched append cannot touch another project.
case_memory_config_project_isolation() {
  local name="pmctl memory config: project mapping prevents cross-project resolve and append"
  should_run "$name" || return 0
  local repo_a="$tmp_root/config-project-a" repo_b="$tmp_root/config-project-b" repo_c="$tmp_root/config-project-c"
  local mem_a="$tmp_root/config-memory-a" mem_b="$tmp_root/config-memory-b"
  local cfg="$tmp_root/project-config" empty_claude="$tmp_root/project-empty-claude"
  local before after out status=0
  mkdir -p "$repo_a" "$repo_b" "$repo_c" "$mem_a" "$mem_b" "$empty_claude/projects"
  git -C "$repo_a" init -q; git -C "$repo_b" init -q; git -C "$repo_c" init -q
  printf 'sentinel = keep\n' > "$cfg"
  PM_DISPATCH_CONFIG_FILE="$cfg" "$PMCTL" memory config set --repo-root "$repo_a" --memory-dir "$mem_a" --json > "$tmp_root/config-set.json"
  PM_DISPATCH_CONFIG_FILE="$cfg" "$PMCTL" memory config set --repo-root "$repo_b" --memory-dir "$mem_b" --json >/dev/null
  before="$(find "$mem_a" "$mem_b" -type f -printf '%p:%s:%T@\n' | sort)"
  out="$(PM_DISPATCH_CONFIG_FILE="$cfg" CLAUDE_CONFIG_DIR="$empty_claude" "$PMCTL" memory resolve --repo-root "$repo_c" --json 2>/dev/null)" || status=$?
  PM_DISPATCH_CONFIG_FILE="$cfg" CLAUDE_CONFIG_DIR="$empty_claude" "$PMCTL" memory append-episode \
    --repo-root "$repo_c" --host codex --summary cross-project-must-fail >/dev/null 2>&1 || true
  after="$(find "$mem_a" "$mem_b" -type f -printf '%p:%s:%T@\n' | sort)"
  if [[ "$status" -eq 1 && "$before" == "$after" ]] \
    && jq -e '.status == "unavailable" and .resolution_source == "none"' <<<"$out" >/dev/null \
    && grep -q '^sentinel = keep$' "$cfg" \
    && grep -q "^memory.projects.$(memory_fixture_project_key "$repo_a").dir = $mem_a$" "$cfg" \
    && grep -q "^memory.projects.$(memory_fixture_project_key "$repo_b").dir = $mem_b$" "$cfg"; then
    pass "$name"
  else
    fail "$name" "status=$status out=$out before=[$before] after=[$after] config=$(<"$cfg")"
  fi
}

# Behavior: every maintenance surface rejects an invalid matched mapping rather
# than reading or writing the repository's otherwise discoverable legacy store.
# Steps: configure a missing scoped target over a populated legacy store, invoke
# doctor, dir, shard, and rebuild-summary, then assert diagnostics and zero writes.
case_memory_config_invalid_maintenance_no_fallback() {
  local name="pmctl memory config: invalid matched mapping blocks doctor and maintenance fallback"
  should_run "$name" || return 0
  local repo="$tmp_root/config-maint-repo" claude="$tmp_root/config-maint-claude"
  local config="$tmp_root/config-maint.conf" missing="$tmp_root/config-maint-missing" legacy
  local doctor="$tmp_root/config-maint-doctor.json" status_doctor=0 status_dir=0 status_shard=0 status_rebuild=0
  mkdir -p "$repo"; git -C "$repo" init -q
  legacy="$(make_fixture_memory "$claude" "$repo")"
  printf '{"date":"2026-01-01","summary":"legacy sentinel"}\n' > "$legacy/episodes.jsonl"
  write_project_memory_config "$config" "$repo" "$missing"

  PM_DISPATCH_CONFIG_FILE="$config" CLAUDE_CONFIG_DIR="$claude" "$PMCTL" memory doctor --repo-root "$repo" --json > "$doctor" 2>/dev/null || status_doctor=$?
  PM_DISPATCH_CONFIG_FILE="$config" CLAUDE_CONFIG_DIR="$claude" "$PMCTL" memory dir "$repo" >/dev/null 2>&1 || status_dir=$?
  PM_DISPATCH_CONFIG_FILE="$config" CLAUDE_CONFIG_DIR="$claude" "$PMCTL" memory shard --repo-root "$repo" >/dev/null 2>&1 || status_shard=$?
  PM_DISPATCH_CONFIG_FILE="$config" CLAUDE_CONFIG_DIR="$claude" "$PMCTL" memory rebuild-summary --repo-root "$repo" >/dev/null 2>&1 || status_rebuild=$?

  if [[ "$status_doctor" -eq 1 && "$status_dir" -eq 3 && "$status_shard" -eq 3 && "$status_rebuild" -eq 3 ]] \
    && jq -e '.issues_count == 1 and .resolution_issues[0].source == "config" and (.resolution_issues[0].reason | contains("does not exist"))' "$doctor" >/dev/null \
    && [[ ! -e "$legacy/episodes.summary.md" ]] \
    && [[ -z "$(find "$legacy" -maxdepth 1 -name 'episodes.????-??.jsonl' -print -quit)" ]]; then
    pass "$name"
  else
    fail "$name" "doctor=$status_doctor dir=$status_dir shard=$status_shard rebuild=$status_rebuild report=$(<"$doctor")"
  fi
}

# Behavior: deprecated global config is diagnostic and fail-closed until one
# explicit repository migration atomically replaces it with a scoped entry.
case_memory_config_legacy_migration() {
  local name="pmctl memory config: unsafe global fails closed then migrates idempotently"
  should_run "$name" || return 0
  local repo="$tmp_root/config-migrate-repo" mem="$tmp_root/config-migrate-memory" cfg="$tmp_root/config-migrate.conf"
  local out status=0 lint_status=0
  mkdir -p "$repo" "$mem"; git -C "$repo" init -q
  printf 'dispatch.default_timeout = 700\ndispatch.memory_dir = %s\n' "$mem" > "$cfg"
  out="$(PM_DISPATCH_CONFIG_FILE="$cfg" "$PMCTL" memory resolve --repo-root "$repo" --json 2>/dev/null)" || status=$?
  PM_DISPATCH_CONFIG_FILE="$cfg" "$PMCTL" memory config lint --json > "$tmp_root/config-legacy-lint.json" || lint_status=$?
  if [[ "$status" -ne 3 || "$lint_status" -ne 1 ]] \
    || ! jq -e '.resolution_source == "config-legacy-global" and .status == "invalid-explicit"' <<<"$out" >/dev/null \
    || ! jq -e '.issues | any(.code == "unsafe-legacy-global")' "$tmp_root/config-legacy-lint.json" >/dev/null; then
    fail "$name" "pre-migration status=$status lint=$lint_status out=$out"
    return 0
  fi
  PM_DISPATCH_CONFIG_FILE="$cfg" "$PMCTL" memory config migrate --repo-root "$repo" --json > "$tmp_root/config-migrate.json" || {
    fail "$name" "migration failed"; return 0;
  }
  PM_DISPATCH_CONFIG_FILE="$cfg" "$PMCTL" memory config migrate --repo-root "$repo" --json > "$tmp_root/config-migrate-noop.json" || {
    fail "$name" "second migration was not idempotent"; return 0;
  }
  status=0
  out="$(PM_DISPATCH_CONFIG_FILE="$cfg" "$PMCTL" memory resolve --repo-root "$repo" --json 2>/dev/null)" || status=$?
  if [[ "$status" -eq 0 ]] \
    && jq -e --arg mem "$mem" '.resolution_source == "config" and .memory_dir == $mem' <<<"$out" >/dev/null \
    && jq -e '.action == "migrate-noop"' "$tmp_root/config-migrate-noop.json" >/dev/null \
    && ! grep -q '^dispatch.memory_dir[[:space:]]*=' "$cfg" \
    && grep -q '^dispatch.default_timeout = 700$' "$cfg"; then
    pass "$name"
  else
    fail "$name" "post-migration status=$status out=$out config=$(<"$cfg")"
  fi
}

# Behavior: matched malformed/missing project paths are reported, while entries
# for other projects never poison the selected repository.
case_memory_config_lint_and_matched_fail_closed() {
  local name="pmctl memory config: lint diagnoses malformed and missing matched paths"
  should_run "$name" || return 0
  local repo="$tmp_root/config-lint-repo" cfg="$tmp_root/config-lint.conf" key missing="$tmp_root/config-lint-missing"
  local status=0 lint_status=0 out
  mkdir -p "$repo"; git -C "$repo" init -q; key="$(memory_fixture_project_key "$repo")"
  printf 'memory.projects.bad.dir = /tmp/nope\nmemory.projects.%s.dir = %s\nmemory.projects.%s.dir = %s\n' \
    "$key" "$missing" "$key" "$missing" > "$cfg"
  out="$(PM_DISPATCH_CONFIG_FILE="$cfg" "$PMCTL" memory resolve --repo-root "$repo" --json 2>/dev/null)" || status=$?
  PM_DISPATCH_CONFIG_FILE="$cfg" "$PMCTL" memory config lint --json > "$tmp_root/config-lint.json" || lint_status=$?
  if [[ "$status" -eq 3 && "$lint_status" -eq 1 ]] \
    && jq -e '.status == "invalid-explicit" and .resolution_source == "config"' <<<"$out" >/dev/null \
    && jq -e '.issues | any(.code == "malformed-project-key") and any(.code == "duplicate-project-key") and any(.code == "missing-memory-dir")' "$tmp_root/config-lint.json" >/dev/null; then
    pass "$name"
  else
    fail "$name" "resolve=$status lint=$lint_status out=$out report=$(<"$tmp_root/config-lint.json")"
  fi
}

case_memory_config_linked_worktree_identity() {
  local name="pmctl memory config: linked worktree shares primary project mapping"
  should_run "$name" || return 0
  local repo="$tmp_root/config-worktree-main" wt="$tmp_root/config-worktree-linked"
  local mem="$tmp_root/config-worktree-memory" cfg="$tmp_root/config-worktree.conf" main_json wt_json
  mkdir -p "$repo" "$mem"; git -C "$repo" init -q
  printf 'seed\n' > "$repo/README.md"
  git -C "$repo" add README.md
  git -C "$repo" -c user.name=test -c user.email=test@example.invalid commit -qm seed
  git -C "$repo" worktree add -q -b config-worktree-branch "$wt"
  PM_DISPATCH_CONFIG_FILE="$cfg" "$PMCTL" memory config set --repo-root "$repo" --memory-dir "$mem" --json >/dev/null
  main_json="$(PM_DISPATCH_CONFIG_FILE="$cfg" "$PMCTL" memory resolve --repo-root "$repo" --json)"
  wt_json="$(PM_DISPATCH_CONFIG_FILE="$cfg" "$PMCTL" memory resolve --repo-root "$wt" --json)"
  if [[ "$(jq -r '.project_key' <<<"$main_json")" == "$(jq -r '.project_key' <<<"$wt_json")" ]] \
    && jq -e --arg mem "$mem" '.resolution_source == "config" and .memory_dir == $mem' <<<"$wt_json" >/dev/null; then
    pass "$name"
  else
    fail "$name" "main=$main_json worktree=$wt_json"
  fi
}

# ── Run all cases ──────────────────────────────────────────────────────────────

case_memory_resolve_env_contract
case_memory_resolve_invalid_explicit_no_fallback
case_memory_resolve_legacy_compatibility
case_memory_resolve_config_contract
case_memory_resolve_env_outranks_config
case_memory_resolve_invalid_config_no_fallback
case_memory_resolve_rejects_relative_explicit_paths
case_memory_resolve_unavailable
case_memory_resolve_rejects_non_git_root
case_memory_resolve_allows_generic_non_git
case_memory_append_episode_cross_host_contract
case_memory_append_episode_requires_host
case_memory_append_episode_invalid_explicit_no_fallback
case_memory_append_episode_query_round_trip
case_memory_append_episode_concurrent_skeleton_dedupe
case_memory_append_episode_refuses_symlink
case_memory_append_episode_symlink_swap_race
case_memory_append_episode_refuses_symlink_lock_dir
case_memory_config_project_isolation
case_memory_config_invalid_maintenance_no_fallback
case_memory_config_legacy_migration
case_memory_config_lint_and_matched_fail_closed
case_memory_config_linked_worktree_identity
case_memory_dir_happy_path
case_memory_dir_nested_subdir
case_memory_dir_uses_pwd_default
case_memory_dir_not_found
case_memory_dir_pm_memory_dir_env_override
case_memory_dir_pm_memory_dir_unset_byte_identical
case_memory_dir_config_dispatch_memory_dir_override
case_memory_dir_pm_memory_dir_outranks_config
case_memory_dir_malformed_config_memory_dir_fails_closed
case_memory_dir_no_mutation
case_memory_doctor_clean_fixture
case_memory_doctor_dead_link
case_memory_doctor_orphan_card
case_memory_doctor_duplicate_hooks
case_memory_doctor_repo_refs_fresh_not_flagged
case_memory_doctor_repo_refs_stale_flagged
case_memory_doctor_repo_refs_flow_style
case_memory_doctor_episodes_bytes
case_memory_doctor_unknown_flag_exit2
case_memory_doctor_repo_root_missing_operand_exit2
case_memory_doctor_help_exit0
case_memory_doctor_repo_root_override
case_memory_doctor_missing_required_fields
case_memory_doctor_no_memory_dir
case_memory_doctor_config_memory_dir_override
case_memory_doctor_repo_refs_unsafe_path
case_memory_doctor_fn_symbol_injection
case_memory_doctor_fn_function_keyword_boundary
case_memory_commands_resolve_only_fixture_dirs
case_memory_doctor_is_read_only
case_memory_shard_below_limit
case_memory_shard_above_limit
case_memory_shard_idempotent
case_memory_rebuild_summary_no_duplicate_after_shard
case_memory_shard_no_memory_dir
case_memory_rebuild_summary_no_memory_dir
case_memory_shard_config_memory_dir_override
case_memory_rebuild_summary_config_memory_dir_override
case_memory_index_not_produced
case_memory_shard_at_exact_limit
case_memory_shard_repo_root_missing_operand_exit2
case_memory_rebuild_summary_repo_root_missing_operand_exit2
case_memory_shard_help_exit0
case_memory_shard_unknown_arg_exit2
case_memory_shard_no_episodes_file
case_memory_rebuild_summary_help_exit0
case_memory_rebuild_summary_unknown_arg_exit2
case_memory_rebuild_summary_no_episodes_file
case_memory_rebuild_summary_basic
case_memory_rebuild_summary_skips_empty_summary
case_memory_rebuild_summary_deterministic
case_memory_doctor_ignores_episodes_summary
case_memory_doctor_shard_count
case_memory_stats_no_usage_all_never_hit
case_memory_stats_usage_hits_and_concentration
case_memory_stats_duplicate_index_link_counted_once
case_memory_stats_episode_fill_rate
case_memory_stats_never_hit_limit
case_memory_stats_no_memory_dir
case_memory_stats_unknown_flag_exit2
case_memory_stats_bad_never_hit_limit_exit2
case_memory_stats_help_exit0
case_memory_stats_is_read_only
case_memory_stats_invalid_env_selection_fails_closed
case_memory_stats_invalid_config_selection_fails_closed
case_memory_stats_json_escapes_control_characters
case_memory_stats_unreadable_sidecar_is_not_zero_activity
case_memory_shared_readers_avoid_bash_43_namerefs
case_memory_escapers_preserve_embedded_newlines
case_memory_escapers_reject_illegal_utf8
case_memory_stats_oversized_counter_degrades
case_memory_stats_option_like_operand_is_usage_error
case_memory_stats_oversized_limit_is_usage_error
case_memory_human_output_neutralizes_terminal_controls
case_memory_human_output_neutralizes_c1_controls
case_memory_stats_reports_per_card_hit_counts
case_memory_stats_hit_limit_boundaries
case_memory_stats_hit_rows_sort_numerically
case_memory_stats_json_escapes_c1_controls
case_memory_stats_unrecordable_card_is_not_never_hit
case_memory_stats_unparsed_index_entries_excluded
case_memory_stats_malformed_episodes_are_not_zero_history
case_memory_stats_age_buckets_match_frecency_boundaries

th_summary
