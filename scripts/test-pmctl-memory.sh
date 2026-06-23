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

# Run doctor against a fixture; writes JSON to $1, returns doctor exit code.
run_doctor_json() {
  local out="$1" cfg="$2" repo="$3"; shift 3
  local status=0
  CLAUDE_CONFIG_DIR="$cfg" "$PMCTL" memory doctor --repo-root "$repo" --json "$@" \
    > "$out" 2>/dev/null || status=$?
  return "$status"
}

# ── Test cases ─────────────────────────────────────────────────────────────────

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
  printf -- '---\nname: alpha\n---\nbody\n' > "$mdir/card_alpha.md"
  printf -- '---\nname: beta\n---\nbody\n' > "$mdir/card_beta.md"

  local out="$tmp_root/clean.json" status=0
  run_doctor_json "$out" "$cfg" "$repo" || status=$?

  if ! assert_exit "$name" "$status" 0; then return 0; fi
  if ! assert_file_contains "$name" "$out" '"schema_version":1'; then return 0; fi
  if ! assert_file_contains "$name" "$out" '"issues_count":0'; then return 0; fi
  if ! assert_file_contains "$name" "$out" '"entry_count":2'; then return 0; fi
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

# ── Run all cases ──────────────────────────────────────────────────────────────

case_memory_doctor_clean_fixture
case_memory_doctor_dead_link
case_memory_doctor_orphan_card
case_memory_doctor_duplicate_hooks
case_memory_doctor_repo_refs_fresh_not_flagged
case_memory_doctor_repo_refs_stale_flagged
case_memory_doctor_episodes_bytes
case_memory_doctor_unknown_flag_exit2
case_memory_doctor_repo_root_override
case_memory_doctor_no_live_dir_mutation

th_summary
