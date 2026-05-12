# Changelog

All notable changes to claude-config are documented here.
Format inspired by [Keep a Changelog](https://keepachangelog.com/).
Versions follow [Semantic Versioning](https://semver.org/).

---

## [Unreleased]

### Changed
- `scripts/codex-pr-gate.sh` renamed to `scripts/pr-gate.sh`; `scripts/test-codex-pr-gate.sh` renamed to `scripts/test-pr-gate.sh`
- `commands/codex-pr-gate.md` and `commands/pr-gate.md` merged into a single `commands/pr-gate.md` that invokes `scripts/pr-gate.sh`; the old Agent-subagent approach is replaced by the script's `--parallel` mode

### Added
- `scripts/pr-gate.sh`: **parallel mode** (`--parallel`) — one independent
  codex session per reviewer followed by a project-pm synthesis session; avoids
  shared-context anchoring and token pressure between reviewers. Default remains
  sequential (one combined session); use `--parallel` when reviewer independence
  matters (auth/payment/sensitive paths) or when token budget allows it.
- `scripts/pr-gate.sh`: **adjacent test file auto-detection** — for each
  changed `.go` source file the companion `*_test.go` is automatically appended
  to the reviewer brief; for `.ts`/`.tsx` sources the `__tests__/<name>.test.ts(x)`
  and sibling `<name>.test.ts(x)` are appended. Files already in the diff are
  de-duplicated. This gives reviewers visibility into coverage gaps in unchanged
  test files.
- `agents/qa-tester.md`: **Step 0 pre-flight coverage enumeration** added to
  Mode C — the reviewer must enumerate every new behavioral unit (function,
  param, field, handler) from the diff and verify adjacent test coverage before
  proceeding to the audit; missing coverage is a blocking finding.

---

## [1.1.0] - 2026-05-12

### Added
- `scripts/patch-gitignore.sh`: shared helper that idempotently appends Claude
  output dirs (`.agent-trace/`, `.codex-briefs/`, `.gate-results/`, `.agents/`)
  under a guarded header block in any git repo's `.gitignore`; supports
  `--dry-run`; exits silently if the directory is not a git repo
- `scripts/codex-dispatch.sh` and `scripts/pr-gate.sh` now call
  `patch-gitignore.sh` automatically so every project gets the entries without
  manual setup
- `scripts/setup-project.sh` now calls `patch-gitignore.sh` for the same
  idempotent bootstrap path

### Fixed
- `.agents/` (created by Claude Code's Agent tool) added to the auto-patch
  entry list so the directory is always ignored without manual action
- Duplicate `mkdir -p "$(dirname "$OUTPUT_FILE")"` call removed from
  `pr-gate.sh`

---

## [1.0.0] - 2026-05-12 (initial public release)

### Added
- MIT License (`LICENSE`)
- Two-tier agent model: hot-path `AGENT.md` entrypoint + reference files
- Agent definitions: `project-pm`, `critic`, `architecture-reviewer`,
  `security-reviewer`, `risk-reviewer`, `qa-tester`, `codex-executor`
- `scripts/codex-dispatch.sh`: sandboxed Codex CLI dispatch with approval gate,
  trace capture, and hook guard
- `scripts/pr-gate.sh`: sequential PR-gate via a single codex session
  (express / standard / full tier auto-detection)
- `scripts/setup-project.sh`: per-project bootstrap (`.gitignore`, brief dir)
- `/pr-gate`, `/pm` skill commands
- `docs/codex-brief.md`: brief schema reference
- `docs/model-tier-policy.md`: model selection rules per agent type

### Changed
- Memory paths in agent definitions use generic `<claude-project-id>` form
  instead of hardcoded user paths (public-release safety, PR #36)
- `agents/qa-tester.md`: qa-testing-rules path configurable via `QA_RULES_DIR`
  env var (PR #36)
- Planning consistency fixes across agent definitions (PR #36)
