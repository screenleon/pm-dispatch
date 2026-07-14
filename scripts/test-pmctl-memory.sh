#!/usr/bin/env bash
# Regression tests for `pmctl memory doctor` (scripts/lib/pmctl-memory.sh).
# shellcheck disable=SC2154  # tmp_root supplied by sourced test-harness
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PMCTL="$REPO_ROOT/cli/pmctl"

# shellcheck source=scripts/lib/test-harness.sh
# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib/test-harness.sh"
# shellcheck source=scripts/lib/memory.sh
# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib/memory.sh"
th_init "$@"

# Snapshot the developer's live project-memory dir up front (a read, for the
# baseline) so a dedicated guard case proves the suite never MUTATES it — doctor
# must stay read-only AND no case may accidentally point doctor at the live dir.
# Every case operates on an isolated fixture under $tmp_root via a fake
# CLAUDE_CONFIG_DIR.
_LIVE_MEM_DIR="$(find_memory_dir "$REPO_ROOT" 2>/dev/null || true)"
_live_mem_fingerprint() {
  if [[ -n "$_LIVE_MEM_DIR" && -d "$_LIVE_MEM_DIR" ]]; then
    find "$_LIVE_MEM_DIR" -type f -printf '%P:%s:%T@\n' 2>/dev/null | sort
  else
    printf 'ABSENT\n'
  fi
}
_LIVE_MEM_BASELINE="$(_live_mem_fingerprint)"

# ── Helpers ────────────────────────────────────────────────────────────────────

# Encode a repo path into the CLAUDE config "projects" dir key.
# Mirrors scripts/lib/memory.sh encode_path: "/a/b" → "-a-b".
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
  printf 'dispatch.memory_dir = %s\n' "$mdir" > "$config"
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
  printf 'dispatch.memory_dir = %s\n' "$cfg_dir" > "$config"
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
  printf 'dispatch.memory_dir = %s\n' "$missing" > "$config"
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
  printf 'dispatch.memory_dir = relative-memory\n' > "$config"
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
  local name="pmctl memory doctor: dispatch.memory_dir config resolves an override-only memory dir"
  should_run "$name" || return 0

  local cfg="$tmp_root/docover-cfg" repo="$tmp_root/docover-repo"
  local override="$tmp_root/docover-override" fakehome="$tmp_root/docover-home"
  # cfg has NO projects/<repo>/memory dir — a hit proves resolution went
  # through dispatch.memory_dir, not the CLAUDE_CONFIG_DIR walk.
  mkdir -p "$cfg/projects" "$repo" "$override" "$fakehome/.pm-dispatch"
  write_compliant_card "$override/feedback_test.md" test-card
  printf '# Memory Index\n- [test](feedback_test.md) — hook\n' > "$override/MEMORY.md"
  printf 'dispatch.memory_dir = %s\n' "$override" > "$fakehome/.pm-dispatch/config"

  local out="$tmp_root/docover.json" status=0
  HOME="$fakehome" CLAUDE_CONFIG_DIR="$cfg" "$PMCTL" memory doctor --repo-root "$repo" --json \
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
  local name="pmctl memory dir: dispatch.memory_dir config overrides discovery when PM_MEMORY_DIR unset"
  should_run "$name" || return 0

  local cfg="$tmp_root/pmcfg-cfg" repo="$tmp_root/pmcfg-repo" override="$tmp_root/pmcfg-override" fakehome="$tmp_root/pmcfg-home"
  mkdir -p "$repo" "$override" "$fakehome/.pm-dispatch"
  printf 'dispatch.memory_dir = %s\n' "$override" > "$fakehome/.pm-dispatch/config"

  local out status=0
  out="$(HOME="$fakehome" CLAUDE_CONFIG_DIR="$cfg" "$PMCTL" memory dir "$repo" 2>/dev/null)" || status=$?

  if ! assert_exit "$name" "$status" 0; then return 0; fi
  if [[ "$out" != "$override" ]]; then
    fail "$name" "expected '$override' got '$out'"
    return 0
  fi
  pass "$name"
}

case_memory_dir_pm_memory_dir_outranks_config() {
  local name="pmctl memory dir: PM_MEMORY_DIR env outranks dispatch.memory_dir config"
  should_run "$name" || return 0

  local cfg="$tmp_root/pmboth-cfg" repo="$tmp_root/pmboth-repo"
  local env_win="$tmp_root/pmboth-env-win" cfg_lose="$tmp_root/pmboth-cfg-lose" fakehome="$tmp_root/pmboth-home"
  mkdir -p "$repo" "$env_win" "$cfg_lose" "$fakehome/.pm-dispatch"
  printf 'dispatch.memory_dir = %s\n' "$cfg_lose" > "$fakehome/.pm-dispatch/config"

  local out status=0
  out="$(PM_MEMORY_DIR="$env_win" HOME="$fakehome" CLAUDE_CONFIG_DIR="$cfg" "$PMCTL" memory dir "$repo" 2>/dev/null)" || status=$?

  if ! assert_exit "$name" "$status" 0; then return 0; fi
  if [[ "$out" != "$env_win" ]]; then
    fail "$name" "expected '$env_win' (env) got '$out'"
    return 0
  fi
  pass "$name"
}

case_memory_dir_malformed_config_memory_dir_falls_through() {
  local name="pmctl memory dir: malformed (relative) dispatch.memory_dir warns and falls through to legacy resolution"
  should_run "$name" || return 0

  local cfg="$tmp_root/pmbad-cfg" repo="$tmp_root/pmbad-repo" fakehome="$tmp_root/pmbad-home"
  mkdir -p "$repo" "$fakehome/.pm-dispatch"
  local mdir; mdir="$(make_fixture_memory "$cfg" "$repo")"
  printf 'dispatch.memory_dir = relative/not-absolute\n' > "$fakehome/.pm-dispatch/config"

  local out err status=0
  err="$tmp_root/pmbad.err"
  out="$(HOME="$fakehome" CLAUDE_CONFIG_DIR="$cfg" "$PMCTL" memory dir "$repo" 2>"$err")" || status=$?

  if ! assert_exit "$name" "$status" 0; then return 0; fi
  if [[ "$out" != "$mdir" ]]; then
    fail "$name" "expected fallback to legacy dir '$mdir' (malformed override must be ignored), got '$out'"
    return 0
  fi
  if ! grep -q 'malformed value for dispatch.memory_dir' "$err"; then
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

case_memory_doctor_no_live_dir_mutation() {
  local name="pmctl memory doctor suite: never mutates the live project-memory dir"
  should_run "$name" || return 0
  local now; now="$(_live_mem_fingerprint)"
  if [[ "$now" == "$_LIVE_MEM_BASELINE" ]]; then
    pass "$name"
  else
    fail "$name" "live memory dir changed during suite: baseline/now differ"
  fi
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
  printf '{"date":"2026-05-01","cwd":"%s","session_id":"a","summary":""}\n'         "$repo" >> "$ep"
  printf '{"date":"2026-05-02","cwd":"%s","session_id":"b","summary":"real entry"}\n' "$repo" >> "$ep"

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
    fail "$name" "expected 1 bullet (skeleton skipped), got $entry_count"
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
  local name="pmctl memory shard: dispatch.memory_dir config resolves an override-only memory dir"
  should_run "$name" || return 0

  local cfg repo override fakehome
  cfg="$(mktemp -d -p "$tmp_root")"
  repo="$(mktemp -d -p "$tmp_root")"
  override="$(mktemp -d -p "$tmp_root")"
  fakehome="$(mktemp -d -p "$tmp_root")"
  mkdir -p "$cfg/projects" "$fakehome/.pm-dispatch"  # cfg has NO memory dir for $repo
  printf 'dispatch.memory_dir = %s\n' "$override" > "$fakehome/.pm-dispatch/config"

  local ep="$override/episodes.jsonl"
  local i
  for i in $(seq 1 5); do
    printf '{"date":"2026-05-%02d","cwd":"%s","session_id":"s%d","summary":"entry %d"}\n' \
      "$i" "$repo" "$i" "$i" >> "$ep"
  done

  local out status=0
  out="$(HOME="$fakehome" CLAUDE_CONFIG_DIR="$cfg" "$PMCTL" memory shard --repo-root "$repo" 2>&1)" || status=$?

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
  local name="pmctl memory rebuild-summary: dispatch.memory_dir config resolves an override-only memory dir"
  should_run "$name" || return 0

  local cfg repo override fakehome
  cfg="$(mktemp -d -p "$tmp_root")"
  repo="$(mktemp -d -p "$tmp_root")"
  override="$(mktemp -d -p "$tmp_root")"
  fakehome="$(mktemp -d -p "$tmp_root")"
  mkdir -p "$cfg/projects" "$fakehome/.pm-dispatch"  # cfg has NO memory dir for $repo
  printf 'dispatch.memory_dir = %s\n' "$override" > "$fakehome/.pm-dispatch/config"

  local ep="$override/episodes.jsonl"
  printf '{"date":"2026-05-01","cwd":"%s","session_id":"a","summary":"may entry one"}\n' "$repo" >> "$ep"

  local out status=0
  out="$(HOME="$fakehome" CLAUDE_CONFIG_DIR="$cfg" "$PMCTL" memory rebuild-summary --repo-root "$repo" 2>&1)" || status=$?

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

# Behavior: every host appends through the same strict canonical episode path.
# Steps: append one marker per host to an env-selected memory dir and assert JSONL/provenance.
case_memory_append_episode_cross_host_contract() {
  local name="pmctl memory append-episode: Claude Codex OpenCode and generic share canonical path"
  should_run "$name" || return 0
  local repo="$tmp_root/append-cross-host-repo" mdir="$tmp_root/append-cross-host-memory" host out status=0
  mkdir -p "$repo" "$mdir"
  git -C "$repo" init -q
  for host in claude codex opencode generic; do
    out="$(PM_MEMORY_DIR="$mdir" "$PMCTL" memory append-episode --repo-root "$repo" --host "$host" \
      --session-id "session-$host" --date "2026-07-13T00:00:00Z" --summary "cc483-${host}-canonical-marker" --json 2>/dev/null)" || status=$?
    if [[ "$status" -ne 0 ]] || ! jq -e --arg host "$host" --arg mdir "$mdir" \
        '.provider == "pmctl" and .authority == "canonical" and .writer_host == $host and .memory_dir == $mdir and .episode.writer_host == $host' <<<"$out" >/dev/null; then
      fail "$name" "host=$host status=$status out=$out"; return 0
    fi
  done
  if [[ "$(wc -l < "$mdir/episodes.jsonl" | tr -d ' ')" == "4" ]] \
    && jq -e -s 'map(.writer_host) == ["claude","codex","opencode","generic"]' "$mdir/episodes.jsonl" >/dev/null; then
    pass "$name"
  else
    fail "$name" "episodes=$(cat "$mdir/episodes.jsonl" 2>/dev/null || true)"
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
  . "$REPO_ROOT/scripts/lib/pmctl-memory.sh"
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
case_memory_append_episode_invalid_explicit_no_fallback
case_memory_append_episode_query_round_trip
case_memory_append_episode_concurrent_skeleton_dedupe
case_memory_append_episode_refuses_symlink
case_memory_append_episode_symlink_swap_race
case_memory_append_episode_refuses_symlink_lock_dir
case_memory_dir_happy_path
case_memory_dir_nested_subdir
case_memory_dir_uses_pwd_default
case_memory_dir_not_found
case_memory_dir_pm_memory_dir_env_override
case_memory_dir_pm_memory_dir_unset_byte_identical
case_memory_dir_config_dispatch_memory_dir_override
case_memory_dir_pm_memory_dir_outranks_config
case_memory_dir_malformed_config_memory_dir_falls_through
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
case_memory_doctor_no_live_dir_mutation
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

th_summary
