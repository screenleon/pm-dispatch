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

# ── Run all cases ──────────────────────────────────────────────────────────────

case_memory_dir_happy_path
case_memory_dir_nested_subdir
case_memory_dir_uses_pwd_default
case_memory_dir_not_found
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
case_memory_doctor_repo_refs_unsafe_path
case_memory_doctor_fn_symbol_injection
case_memory_doctor_fn_function_keyword_boundary
case_memory_doctor_no_live_dir_mutation

th_summary
