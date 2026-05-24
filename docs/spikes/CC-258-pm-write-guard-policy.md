# CC-258: pm-write-guard policy revision

> Status: draft spike — read-only design pass. Ticket id `CC-258` is placeholder; user assigns real id on triage.
> Inputs: `scripts/hook-pm-write-guard.sh` (130 lines), `scripts/lib/portable.sh:81-105` (`realpath_m`), `~/.claude/logs/hooks.log` (300 entries: 207 deny / 73 allow / 20 bypass), `scripts/test-hooks.sh:139-224` (current pm-guard suite).
> Related memories: `[[feedback_codex_brief_discipline]]`, `[[feedback_spike_validation_mandatory]]`, `[[reference_memory_private_repo]]`.

## Problem

The current `hook-pm-write-guard.sh` (`scripts/hook-pm-write-guard.sh:125-129`) enforces a single allow pattern:

```sh
case "$abs_path" in
  "$ALLOWED_BASE"/[!/]*/memory/*) allow "inside memory dir" ;;
esac
deny "outside memory directory (resolved to $abs_path)"
```

where `ALLOWED_BASE=$HOME/.claude/projects` (`scripts/hook-pm-write-guard.sh:28`). Anything outside `~/.claude/projects/<project>/memory/**` is denied.

Audit data (last ~10 days, 207 denies) reveals three categories that the policy currently rejects but that the PM agent has a legitimate, recurrent reason to perform:

1. **Verbatim-as-attached-file split** under `/tmp/<task-slug>-content/*.md` — codified in `[[feedback_codex_brief_discipline]]` Pattern 2 (`~/.claude/projects/-home-screenleon-github/memory/feedback_codex_brief_discipline.md:23-39`). The pattern exists precisely to prevent the apply_patch debug-loop hang documented in CC-247/248/250 retros, but the guard punishes PM for following its own published discipline, forcing inline embedding (the failure mode the pattern was written to avoid).
2. **Spike scope docs** at `<repo>/docs/spikes/*-scope.md` (and full spike docs `<repo>/docs/spikes/CC-NNN.md`). PM is the natural author — the alternative is a no-value transcription round-trip through main thread.
3. **Memory writes resolved through the project-memory symlink** to `~/github/memory-private/` (`[[reference_memory_private_repo]]`, since 2026-05-16 Phase 0 split). `realpath_m` (`scripts/lib/portable.sh:81-105`) resolves the symlink before the case match, so the resolved path falls outside `$ALLOWED_BASE`, producing a spurious deny.

Patterns that must remain denied (PM is a planner, not an author of artefacts under formal validation): `BACKLOG.md`, `DECISIONS.md`, `agents/*.md`, `commands/*.md`, `scripts/**`, and `/tmp/brief-*.md` (the codex-dispatch brief checkpoint stays main-thread for handover validation per `[[feedback_spike_validation_mandatory]]`).

## Audit data

Sampled all 207 `hook-pm-write-guard … decision=deny` lines in `~/.claude/logs/hooks.log` (2026-05-04 → 2026-05-24). Categorisation by deny target:

| Category                                              | Count | Disposition under new policy        |
|-------------------------------------------------------|------:|-------------------------------------|
| `agents/project-pm.md` (regression test repeated)     |    60 | stays denied (self-modification)    |
| `/tmp/oops.md` (test fixture, repeated)               |    20 | stays denied                        |
| `/tmp/memory/../../etc/passwd` (traversal test)       |    20 | stays denied                        |
| `memory-evil/x.md` (prefix-collision test)            |    19 | stays denied                        |
| `tool_input.file_path empty` / `foo.md` (test inputs) |    61 | stays denied                        |
| `/tmp/<task-slug>-content/*.md`                       |     9 | **becomes allow** (live PM traffic) |
| `/tmp/brief-<task>.md`                                |     6 | stays denied (per spec)             |
| `/tmp/CC-NNN-*.md` (loose top-level)                  |     3 | stays denied (see Open question 1)  |
| `<repo>/docs/spikes/*.md`                             |     2 | **becomes allow**                   |
| `BACKLOG.md`                                          |     2 | stays denied                        |
| `<repo>/project/backlog.yml` (japanese-site)          |     2 | stays denied (project record)       |
| `memory/project_japanese-site.md` (symlink resolve)   |     1 | **becomes allow** (bug fix)         |
| `/tmp/evil-target` via memory/_test_evil_link.md      |     1 | stays denied (symlink attack)       |

Net effect: **12 of 207 denies become allows** under the new policy. The remaining 195 are either regression-test traffic against the existing suite (160) or correctly-denied attempts at protected artefacts (35).

The three "real" patterns (rows 6, 9, 12) account for all denies from non-test sessions in the last week.

## Proposed policy revision

### Allow rule additions

Three additional allow rules, layered after the existing `memory/` rule and before the catch-all deny.

**Rule A — split-content directory under `/tmp`:**

```
/tmp/<task-slug>/<file>.md
```

where `<task-slug>` matches `[a-z][a-z0-9-]+` (must start with a lowercase letter; lowercase, digits, hyphens; min length 2) AND the path has exactly one segment between `/tmp/` and the filename (no nested subdirs). Filename must end in `.md`.

Glob form (case statement): `/tmp/[a-z][!/]*/[!/]*.md`.

Rationale for `[a-z][!/]*` (any lowercase-prefixed single segment) rather than the stricter `*-content`:
- Live traffic uses both `cc249-prb2-content/` and `cc209-content/` (the `-content` suffix), but PM agents writing spike artefacts also use bare task ids (`/tmp/CC-060-*`). Requiring `-content` suffix would force PM to rename directories purely to satisfy the hook.
- Requiring lowercase-leading and single-segment blocks two attack shapes: `/tmp/.hidden/x.md` (dotfile dir) and `/tmp/X/../../etc/passwd.md` (segment-count check; realpath collapses `..`). The realpath collapse means the `[!/]*` second segment already rejects post-normalization traversal because the collapsed path would no longer have the `/tmp/<seg>/<file>` shape.
- Excludes `/tmp/brief-*.md` (top-level, no intermediate dir) — codex-dispatch briefs stay outside this rule.

Reject example: `/tmp/CC-060-spike-draft.md` (no intermediate dir) → still denied. PM must write split content under `/tmp/cc060-content/<file>.md`. This is mild friction but aligned with `[[feedback_codex_brief_discipline]]` Pattern 2's `/tmp/<task>-content/` convention.

**Rule B — spike scope docs under repo:**

```
<repo>/docs/spikes/CC-NNN*.md
<repo>/docs/spikes/*-scope.md
<repo>/docs/spikes/*-rfc.md
```

Glob form (case): `*/docs/spikes/[A-Z][A-Z]-[0-9]*.md`, `*/docs/spikes/*-scope.md`, `*/docs/spikes/*-rfc.md`.

Boundary justification:
- Restrict to `docs/spikes/` subtree only — not `docs/**` — to keep `docs/agents/`, `docs/dispatch-brief.md`, `docs/decisions/` (if it exists) on the deny path. Spikes are explicitly PM authorship territory; the rest of `docs/` are contracts or process artefacts.
- Include `CC-NNN*.md` because the actually observed live denies were `CC-060.md` and `CC-229-substrate-scope.md` — both ticket-id-prefixed.
- Include `-rfc.md` because RFCs are a near-sibling of spikes and the friction of adding them later is non-zero. They are PM-authorship in the same sense.
- Do NOT broaden to `docs/spikes/*.md` arbitrarily — keeps the door closed on PM dropping random files (e.g. `notes.md`, `tmp.md`) into the spikes dir. Anything not matching one of the three patterns still routes through main thread.

The leading `*/` is intentional — does not constrain repo location. The PM operates across multiple repos (pm-dispatch, japanese-site) and the rule should apply to any repo's `docs/spikes/`.

**Rule C — memory writes through symlinked memory dir (bug fix; see next section).**

Precedence is allow-first: each rule is evaluated in order; first match wins. Catch-all deny if no rule fires.

### Hook bug fix (symlink resolution)

Current code (`scripts/hook-pm-write-guard.sh:117-127`):

```sh
abs_path="$(realpath_m "$file_path" 2>/dev/null)" || {
  deny "realpath failed on file_path"
}

case "$abs_path" in
  "$ALLOWED_BASE"/[!/]*/memory/*) allow "inside memory dir" ;;
esac
```

`realpath_m` chases all symlinks (`scripts/lib/portable.sh:89` invokes `realpath -m`). When `~/.claude/projects/<proj>/memory` is itself a symlink (the memory-private split per `[[reference_memory_private_repo]]`), `abs_path` resolves to `/home/screenleon/github/memory-private/<file>.md`, which fails the case match.

**Fix**: check the allow pattern against TWO normalizations:

1. `lex_path` — lexical normalization only (collapse `..`, dedupe `//`, NO symlink chase). This is what the case statement needs to test against, because the symlink IS the allowed entry point.
2. `abs_path` — full realpath as today, used only for the security checks (catching `../../etc/passwd`-style traversal that resolves outside the allowed prefix).

Concrete change at `scripts/hook-pm-write-guard.sh:117-129`:

```sh
# Lexical-only normalization (collapse `..` and `//`, do NOT chase symlinks).
# This preserves the user-facing symlinked memory dir as the allowed entry.
lex_path="$(realpath_m -s "$file_path" 2>/dev/null)" || lex_path="$file_path"

# Full realpath: resolves symlinks. Used for security checks (traversal,
# symlink-jump out of allowed dirs).
abs_path="$(realpath_m "$file_path" 2>/dev/null)" || {
  deny "realpath failed on file_path"
}

# --- ALLOW RULES (first match wins) ---

# Rule C: memory dir (test against lex_path so a symlinked memory/ still matches).
case "$lex_path" in
  "$ALLOWED_BASE"/[!/]*/memory/*)
    # Anti-symlink-jump: if the file itself is a symlink, its target must ALSO
    # land inside an allowed memory tree. Permitted destinations are:
    #   - any path under $ALLOWED_BASE/<proj>/memory/  (lexical), or
    #   - any path under ~/github/memory-private/      (the documented symlink target)
    case "$abs_path" in
      "$ALLOWED_BASE"/[!/]*/memory/*) allow "inside memory dir" ;;
      "$HOME"/github/memory-private/*) allow "inside memory dir (private repo)" ;;
      *) deny "memory write redirected outside allowed memory roots (resolved to $abs_path)" ;;
    esac
    ;;
esac

# Rule A: /tmp/<task-slug>/<file>.md (split-content pattern from feedback_codex_brief_discipline).
# Test against abs_path so traversal (/tmp/x/../../etc/passwd.md) is normalized away
# before the segment-count match runs.
case "$abs_path" in
  /tmp/[a-z][!/]*/[!/]*.md)
    # Defense in depth: parent dir must resolve to a single segment under /tmp.
    parent="$(dirname "$abs_path")"
    real_parent="$(realpath_m "$parent" 2>/dev/null)" || deny "realpath of parent failed"
    case "$real_parent" in
      /tmp/[a-z][!/]*) allow "task-slug content dir under /tmp" ;;
      *) deny "task-slug parent resolved outside /tmp (got: $real_parent)" ;;
    esac
    ;;
esac

# Rule B: spike docs under <repo>/docs/spikes/.
case "$abs_path" in
  */docs/spikes/CC-[0-9]*.md|*/docs/spikes/*-scope.md|*/docs/spikes/*-rfc.md)
    allow "spike doc under docs/spikes" ;;
esac

deny "outside memory directory (resolved to $abs_path)"
```

Notes:
- `realpath_m -s` is the standard `realpath -s` flag (no-symlink). It's supported on GNU coreutils realpath. Need to confirm BSD/macOS support — `scripts/lib/portable.sh:81-105` shows `realpath_m` already passes `-m` (allow non-existent components) and works cross-platform. The `-s` flag should be added to the linux/macos branch; for windows the `_portable_realpath_windows` shim does no symlink resolution by default (Windows path semantics), so `-s` is effectively a no-op there.
- An alternative to widening `realpath_m`: do lexical normalization inline in the hook with bash parameter expansion + a small `..`-collapse loop, avoiding any change to `portable.sh`. Cleaner separation of concerns; uglier code. Recommend the `realpath -s` route and only fall back to inline if `-s` isn't reliably portable.
- The `$HOME/github/memory-private/*` literal in Rule C is the only piece of policy that hard-codes a user-specific path. Cleaner alternative: read it from an env var `CLAUDE_MEMORY_PRIVATE_ROOT` (default `$HOME/github/memory-private`). Recommended: env var with default, to keep the hook generic for other users adopting the same split.

### Denials confirmed

The following stay denied (existing tests in `scripts/test-hooks.sh:147-160` continue to pass without modification):

- `<repo>/BACKLOG.md`, `<repo>/BACKLOG-ARCHIVE.md` — formal project record; `scripts/validate.sh` enforces format (the CC-251 retro origin). Main-thread validate-then-write is the contract.
- `<repo>/DECISIONS.md` — formal decision log.
- `<repo>/agents/*.md`, `<repo>/commands/*.md` — process contracts. PM editing PM agent = self-modification (60 of the 207 denies are exactly this regression test).
- `<repo>/scripts/**` — code; goes through executor + brief + self_verify.
- `<repo>/MILESTONES.md`, `<repo>/CHANGELOG.md`, `<repo>/README.md`, repo root markdown — process artefacts.
- `/tmp/brief-*.md` — codex-dispatch brief checkpoint stays main-thread per `[[feedback_spike_validation_mandatory]]`. NOT covered by Rule A because Rule A requires an intermediate directory segment (`/tmp/<slug>/<file>.md`).
- `<repo>/docs/agents/`, `<repo>/docs/dispatch-brief.md`, anything in `docs/` not under `docs/spikes/`.
- Any path that, after full `realpath` resolution, lands outside the allowed roots (catches symlink-jump attacks like the existing test fixture at `scripts/test-hooks.sh` that links a memory file to `/tmp/evil-target`).
- Project-level `project/backlog.yml` files (e.g. japanese-site) — these are project records, not PM-authorship.

### Precedence + bypass

**Precedence** (first match wins, evaluated in order):

1. Rule C (memory dir, with symlink fix)
2. Rule A (`/tmp/<slug>/*.md`)
3. Rule B (`docs/spikes/CC-N*.md` | `*-scope.md` | `*-rfc.md`)
4. Catch-all deny

Order rationale: memory is the highest-volume PM target (correct authorship), so early-exit. Spike docs are next-most-permissive but rarest; placing them last lets the catch-all log every denied attempt against `docs/` so we can audit boundary-creep over time.

**Bypass**: keep `CLAUDE_HOOK_PM_GUARD=off` as-is (`scripts/hook-pm-write-guard.sh:100-104`). The 20 logged bypasses in the audit window are all regression-test traffic (`scripts/test-hooks.sh:202`), so the mechanism is not abused in practice and remains the emergency escape hatch.

Recommendation: do NOT add finer-grained bypasses (e.g. `CLAUDE_HOOK_PM_GUARD=allow-spikes`). They fragment the policy surface and make audit log analysis harder. If the user later finds a recurrent missing-allow case, the audit log will show it and policy can be widened — exactly the discovery loop that produced this spike.

## Code change sketch

File: `scripts/hook-pm-write-guard.sh` (single file).

Lines 117-129 (current 13 lines) replaced by ~35 lines of layered allow/deny logic (sketched above in "Hook bug fix").

Lines 28 (`ALLOWED_BASE`) — add a second constant:
```sh
ALLOWED_BASE="$HOME/.claude/projects"
ALLOWED_MEMORY_PRIVATE="${CLAUDE_MEMORY_PRIVATE_ROOT:-$HOME/github/memory-private}"
```

Lines 45-54 (`deny` heredoc) — update the help text:
```
  allowed:   ${ALLOWED_BASE}/<project>/memory/**
             /tmp/<task-slug>/*.md  (split-content per codex-brief discipline)
             <repo>/docs/spikes/{CC-NNN*,*-scope,*-rfc}.md
```

File: `scripts/lib/portable.sh` — possible touch.

Lines 81-105 (`realpath_m`) — accept an optional `-s` first arg (or split into `realpath_m_lex` helper). If the cross-platform story for `-s` is awkward on macOS BSD realpath, prefer the helper-split approach:

```sh
realpath_m_lex() {
  # Lexical-only: collapse `..` and `//`, do NOT chase symlinks.
  # Used by hooks that need to test patterns against the user-facing path
  # (e.g. a symlinked memory dir is still a valid allow entry).
  ...
}
```

Total change: ~50 lines in `hook-pm-write-guard.sh`, ~20 lines in `portable.sh` (if helper-split route taken).

## Test coverage

Existing regression suite lives in `scripts/test-hooks.sh:139-224` (pm-guard section). No standalone `test-pm-write-guard.sh` exists — additions go to `test-hooks.sh`.

**Keep all existing cases** (`scripts/test-hooks.sh:141-224`). They validate the unchanged denial surface. Mutation testing on the existing memory-dir match would catch regressions in Rule C.

**New positive cases** (allow paths):

```sh
# Rule A: /tmp/<task-slug>/*.md
run_case "pm: Write /tmp/cc249-prb2-content/00-rules.md → allow" 0 "$PMHOOK" \
  '{"agent_type":"project-pm","tool_name":"Write","tool_input":{"file_path":"/tmp/cc249-prb2-content/00-cross-cutting-rules.md"}}'

run_case "pm: Write /tmp/cc060-content/spike-template.md → allow" 0 "$PMHOOK" \
  '{"agent_type":"project-pm","tool_name":"Write","tool_input":{"file_path":"/tmp/cc060-content/spike-template.md"}}'

# Rule B: <repo>/docs/spikes/
run_case "pm: Write docs/spikes/CC-258-foo.md → allow" 0 "$PMHOOK" \
  "{\"agent_type\":\"project-pm\",\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$REPO_ROOT/docs/spikes/CC-258-policy.md\"}}"

run_case "pm: Write docs/spikes/foo-scope.md → allow" 0 "$PMHOOK" \
  "{\"agent_type\":\"project-pm\",\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$REPO_ROOT/docs/spikes/cc229-substrate-scope.md\"}}"

run_case "pm: Write docs/spikes/proposal-rfc.md → allow" 0 "$PMHOOK" \
  "{\"agent_type\":\"project-pm\",\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$REPO_ROOT/docs/spikes/proposal-rfc.md\"}}"
```

**New negative cases** (boundary tests):

```sh
# Rule A boundaries
run_case "pm: Write /tmp/CC-060.md (no intermediate dir) → deny" 2 "$PMHOOK" \
  '{"agent_type":"project-pm","tool_name":"Write","tool_input":{"file_path":"/tmp/CC-060.md"}}' \
  "outside memory directory"

run_case "pm: Write /tmp/brief-foo.md → deny (top-level brief stays denied)" 2 "$PMHOOK" \
  '{"agent_type":"project-pm","tool_name":"Write","tool_input":{"file_path":"/tmp/brief-foo.md"}}' \
  "outside memory directory"

run_case "pm: Write /tmp/.hidden/x.md → deny (leading dot blocked)" 2 "$PMHOOK" \
  '{"agent_type":"project-pm","tool_name":"Write","tool_input":{"file_path":"/tmp/.hidden/x.md"}}' \
  "outside memory directory"

run_case "pm: Write /tmp/Foo/x.md → deny (uppercase leading char blocked)" 2 "$PMHOOK" \
  '{"agent_type":"project-pm","tool_name":"Write","tool_input":{"file_path":"/tmp/Foo/x.md"}}' \
  "outside memory directory"

run_case "pm: Write /tmp/a/b/c.md → deny (nested subdirs blocked)" 2 "$PMHOOK" \
  '{"agent_type":"project-pm","tool_name":"Write","tool_input":{"file_path":"/tmp/a/b/c.md"}}' \
  "outside memory directory"

run_case "pm: Write /tmp/a/x.txt → deny (non-.md blocked)" 2 "$PMHOOK" \
  '{"agent_type":"project-pm","tool_name":"Write","tool_input":{"file_path":"/tmp/a/x.txt"}}' \
  "outside memory directory"

run_case "pm: Write /tmp/x/../etc/passwd.md → deny (traversal normalized)" 2 "$PMHOOK" \
  '{"agent_type":"project-pm","tool_name":"Write","tool_input":{"file_path":"/tmp/x/../etc/passwd.md"}}' \
  "outside memory directory"

# Rule B boundaries
run_case "pm: Write docs/dispatch-brief.md → deny (not under spikes/)" 2 "$PMHOOK" \
  "{\"agent_type\":\"project-pm\",\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$REPO_ROOT/docs/dispatch-brief.md\"}}" \
  "outside memory directory"

run_case "pm: Write docs/spikes/notes.md → deny (no CC-/-scope/-rfc prefix-suffix)" 2 "$PMHOOK" \
  "{\"agent_type\":\"project-pm\",\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$REPO_ROOT/docs/spikes/notes.md\"}}" \
  "outside memory directory"

# Rule C: symlinked memory dir
# Setup: symlink a tmp dir to act as memory dir, write through it.
_link_memdir="$(mktemp -d)/memory-target"
mkdir -p "$_link_memdir"
_proj_dir="$HOME/.claude/projects/test-symlink-proj"
mkdir -p "$_proj_dir"
ln -s "$_link_memdir" "$_proj_dir/memory"
run_case "pm: Write through symlinked memory dir → allow" 0 "$PMHOOK" \
  "{\"agent_type\":\"project-pm\",\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$_proj_dir/memory/foo.md\"}}"

# Symlink-jump attack: file inside memory dir is itself a symlink pointing to /tmp/evil.
ln -s /tmp/evil-target "$_proj_dir/memory/jumper.md"
run_case "pm: Edit via memory-dir symlink redirected outside → deny" 2 "$PMHOOK" \
  "{\"agent_type\":\"project-pm\",\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$_proj_dir/memory/jumper.md\"}}" \
  "redirected outside"
rm -rf "$_proj_dir" "$_link_memdir"
```

**Audit-log assertions** (extend pattern from `scripts/test-hooks.sh:212-224`):

```sh
$LIST || truncate_log
$LIST || printf '%s' '{"agent_type":"project-pm","tool_name":"Write","tool_input":{"file_path":"/tmp/cc060-content/x.md"}}' | "$PMHOOK" >/dev/null 2>&1
assert_log "pm: allow line records task-slug reason" "task-slug content dir"
```

**Estimated additions**: ~15 new test cases, ~30 lines of test code. Suite runtime impact negligible (each case is sub-50ms).

## Risks + mitigations

| Risk                                                                                                   | Severity | Mitigation                                                                                                                                                                            |
|--------------------------------------------------------------------------------------------------------|----------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Rule A widens write surface to all of `/tmp/<lowercase-prefix>/`; another process leaves a confusable directory and PM writes into it. | Medium   | PM only writes when it intends to. The audit log records every write with full path; review weekly. Defense in depth: realpath-of-parent check ensures single-segment shape under /tmp. |
| Rule B opens `docs/spikes/` to PM mass-edit; PM rewrites someone else's spike doc.                     | Low      | Spike docs are git-tracked; reviewable in diff. Spikes are explicitly PM authorship territory per project convention; no contract is violated.                                         |
| `realpath -s` portability issue on macOS BSD realpath.                                                 | Medium   | Test on macOS as part of `test-portable.sh`. Fallback: implement lexical normalization in bash directly (parameter expansion + small `..`-collapse loop) to avoid `realpath -s`.       |
| Symlink-jump via `memory/jumper.md → /tmp/evil` becomes invisible to the rewritten Rule C if anti-jump check is wrong. | High     | Explicit test case (Rule C negative, above). Tests both symlinked memory-dir entry AND symlinked file inside memory-dir to verify the dual realpath comparison.                       |
| `CLAUDE_MEMORY_PRIVATE_ROOT` env var defaults to `$HOME/github/memory-private` — installer must surface this to users not on that layout. | Low      | Document in `docs/dispatch-brief.md` or installer notes. Hook still works correctly for users without the memory-private split (the env-var-gated allow rule simply never fires).      |
| TOCTOU between realpath resolution and Write: attacker swaps a symlink after the hook check.           | Low      | Same risk class as the existing hook; no regression. PreToolUse hooks fundamentally cannot prevent TOCTOU. Out of scope.                                                              |
| Allow rule for `docs/spikes/CC-N*.md` could be exploited via `docs/spikes/CC-9../../../etc/passwd.md` shaped paths. | Low      | The case match runs against `abs_path` (full realpath), so `..` is collapsed. Test case `docs/spikes/CC-1/../etc/passwd.md → deny` will assert this.                                   |
| Policy widening masks future apply-time bugs: PM commits a malformed spike doc that later breaks pmctl/gates. | Low      | Spike docs are non-load-bearing for tooling today. If they become load-bearing (e.g. typed `spike_v1` schema per `[[feedback_spike_validation_mandatory]]` long-term note), add a separate validate step at that time, not in the write-guard. |

## Decisions resolved 2026-05-24

1. **Rule A `/tmp/<slug>/` shape** → **loose `[a-z][!/]*`** (any lowercase-prefixed single segment). Live traffic uses both `cc060-` and `cc249-prb2-content` styles; stricter rule would force PM to rename directories without security benefit.
2. **Memory-private root configurability** → **env var with default** (`CLAUDE_MEMORY_PRIVATE_ROOT=${...:-$HOME/github/memory-private}`). **Note**: the memory-private repo split (`[[reference_memory_private_repo]]`) is itself **provisional** — user has flagged intent to evaluate external memory frameworks (mem0, agent-memory, etc.) and rework the memory architecture later. The env-var indirection is forward-compatible with any future move: only the env value changes, not the hook code.
3. **`docs/spikes/` filename allowlist scope** → **only `CC-NNN*.md` / `*-scope.md` / `*-rfc.md`**. Do NOT pre-add `*-design.md` / `*-proposal.md`. Wait for audit evidence before widening — the audit-driven discovery loop is exactly what produced this spike.
4. **Bypass mechanism** → **single `CLAUDE_HOOK_PM_GUARD=off`**. Audit confirms current bypass is only used in tests; no abuse signal. Per-rule bypasses fragment policy surface without benefit.
5. **Spike scope vs spike output split** → **NOT split**. Flat `docs/spikes/` + filename suffix convention is the adopted shape (`-scope.md` = PM-author, `-synthesis.md` = main-thread verdict, `-claude.md`/`-codex.md` = executor outputs). Repository has ~10 spike docs total; subdirectory split is premature optimization. If future hook policy needs to enforce main-thread-only authorship on verdict docs, add a deny rule for `*-synthesis.md` (suffix-pattern) rather than a directory split. Reconsider directory split at >30 spike docs or when automation needs directory-based discrimination.
6. **Rollout** → **single PR** (test + code together). Diff is small enough for atomic review.

---

### Critical Files for Implementation
- /home/screenleon/github/pm-dispatch/scripts/hook-pm-write-guard.sh
- /home/screenleon/github/pm-dispatch/scripts/lib/portable.sh
- /home/screenleon/github/pm-dispatch/scripts/test-hooks.sh
- /home/screenleon/.claude/projects/-home-screenleon-github/memory/feedback_codex_brief_discipline.md (reference for Rule A pattern shape)
- /home/screenleon/.claude/projects/-home-screenleon-github/memory/reference_memory_private_repo.md (reference for Rule C bug context)
