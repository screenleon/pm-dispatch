#!/usr/bin/env bash
# Regression tests for tools/lint/lint-readme-surface-lists.sh.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LINTER="$REPO_ROOT/tools/lint/lint-readme-surface-lists.sh"

# shellcheck source=tests/lib/test-harness.sh
# shellcheck disable=SC1091
. "$SCRIPT_DIR/../lib/test-harness.sh"
th_init "$@"

# fixture <slug> -- a minimal repo whose README + dirs are set-equal (passes).
# Callers then mutate a dir or a README bullet.
fixture() {
  # shellcheck disable=SC2154  # tmp_root from th_init
  local root="$tmp_root/$1"
  mkdir -p "$root/commands" "$root/agents" "$root/skills/alpha" "$root/skills/beta"
  : > "$root/commands/one.md"
  : > "$root/commands/two.md"
  : > "$root/agents/pm.md"
  : > "$root/agents/critic.md"
  : > "$root/skills/alpha/SKILL.md"
  : > "$root/skills/beta/SKILL.md"
  cat > "$root/README.md" <<'MD'
# X

### Agents

**Orchestration**
- **pm** — a.

**Reviewers**
- **critic** — b.

### Commands

- **/one** — c.
- **/two** — d.

### Skills

- **alpha** — e.
- **beta** — f.

### Other
MD
  printf '%s\n' "$root"
}
run_linter() { bash "$LINTER" --repo-root "$1" 2>&1; }
want_pass() {
  local name="$1" root="$2" out rc=0
  out="$(run_linter "$root")" || rc=$?
  if [[ "$rc" -eq 0 ]]; then pass "$name"; else fail "$name" "expected exit 0, got $rc :: $out"; fi
}
want_fail() {
  local name="$1" root="$2" needle="$3" out rc=0
  out="$(run_linter "$root")" || rc=$?
  if [[ "$rc" -ne 0 && "$out" == *"$needle"* ]]; then pass "$name"
  else fail "$name" "expected non-zero + '$needle', got rc=$rc :: $out"; fi
}

test_real_repo_passes() {
  local name="the real repo README is in sync"
  should_run "$name" || return 0
  want_pass "$name" "$REPO_ROOT"
}

test_balanced_fixture_passes() {
  local name="a set-equal fixture passes; group headers are not bullets"
  should_run "$name" || return 0
  local root; root="$(fixture "$name")"
  want_pass "$name" "$root"
}

test_command_on_disk_missing_from_readme_fails() {
  local name="a command file with no README bullet is a finding"
  should_run "$name" || return 0
  local root; root="$(fixture "$name")"
  : > "$root/commands/three.md"
  want_fail "$name" "$root" "command 'three' exists on disk but has no bullet"
}

test_stale_command_bullet_fails() {
  local name="a README command bullet naming nothing on disk is a finding"
  should_run "$name" || return 0
  local root; root="$(fixture "$name")"
  sed -i 's#- \*\*/two\*\* — d.#- **/two** — d.\n- **/ghost** — g.#' "$root/README.md"
  want_fail "$name" "$root" "lists 'ghost' but no such command exists"
}

test_duplicate_command_bullet_fails() {
  local name="a command listed twice under README Commands is a finding"
  should_run "$name" || return 0
  local root; root="$(fixture "$name")"
  sed -i 's#- \*\*/two\*\* — d.#- **/two** — d.\n- **/two** — again.#' "$root/README.md"
  want_fail "$name" "$root" "lists 'two' more than once (one bullet per command)"
}

test_duplicate_agent_bullet_fails() {
  local name="an agent listed twice under README Agents is a finding"
  should_run "$name" || return 0
  local root; root="$(fixture "$name")"
  sed -i 's#- \*\*critic\*\* — b.#- **critic** — b.\n- **critic** — again.#' "$root/README.md"
  want_fail "$name" "$root" "lists 'critic' more than once (one bullet per agent)"
}

test_duplicate_skill_bullet_fails() {
  local name="a skill listed twice under README Skills is a finding"
  should_run "$name" || return 0
  local root; root="$(fixture "$name")"
  sed -i 's#- \*\*beta\*\* — f.#- **beta** — f.\n- **beta** — again.#' "$root/README.md"
  want_fail "$name" "$root" "lists 'beta' more than once (one bullet per skill)"
}

test_missing_agent_fails() {
  local name="an agent file with no README bullet is a finding"
  should_run "$name" || return 0
  local root; root="$(fixture "$name")"
  : > "$root/agents/qa-tester.md"
  want_fail "$name" "$root" "agent 'qa-tester' exists on disk but has no bullet"
}

test_missing_skill_fails() {
  local name="a skill dir with no README bullet is a finding"
  should_run "$name" || return 0
  local root; root="$(fixture "$name")"
  mkdir -p "$root/skills/gamma"; : > "$root/skills/gamma/SKILL.md"
  want_fail "$name" "$root" "skill 'gamma' exists on disk but has no bullet"
}

test_absent_section_heading_is_a_hard_finding() {
  local name="a missing '### Skills' heading fails loudly, not silently"
  should_run "$name" || return 0
  local root; root="$(fixture "$name")"
  sed -i '/^### Skills$/,/^### Other$/d' "$root/README.md"
  printf '### Other\n' >> "$root/README.md"
  want_fail "$name" "$root" "no '### Skills' section"
}

test_leading_slash_is_optional() {
  local name="a command bullet without a leading slash still matches"
  should_run "$name" || return 0
  local root; root="$(fixture "$name")"
  sed -i 's#- \*\*/one\*\* — c.#- **one** — c.#' "$root/README.md"
  want_pass "$name" "$root"
}

test_bad_flag_is_usage_error() {
  local name="an unknown flag exits 2"
  should_run "$name" || return 0
  local out rc=0
  out="$(bash "$LINTER" --nope 2>&1)" || rc=$?
  if [[ "$rc" -eq 2 ]]; then pass "$name"; else fail "$name" "expected exit 2, got $rc :: $out"; fi
}

test_real_repo_passes
test_balanced_fixture_passes
test_command_on_disk_missing_from_readme_fails
test_stale_command_bullet_fails
test_duplicate_command_bullet_fails
test_duplicate_agent_bullet_fails
test_duplicate_skill_bullet_fails
test_missing_agent_fails
test_missing_skill_fails
test_absent_section_heading_is_a_hard_finding
test_leading_slash_is_optional
test_bad_flag_is_usage_error

th_summary
