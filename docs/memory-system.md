# Memory system

For personal forks, memory is the persistence layer that lets PM and Codex sessions keep continuity across time without overloading token budgets.

See [`CONCEPTS.md`](CONCEPTS.md) for the full conceptual framing.

## Why memory exists

Claude Code sessions are stateless by design, and this repo relies on memory files to avoid forgetting owner-specific preferences and repo-specific conventions. Memory exists to make behavior stable across reboots, reduce repeated clarification, and keep memory recall targeted to actual signal.

## On-disk layout

By default, all fork and runtime state lives under:

`~/.claude/projects/<id>/memory/`

This default is overridable — see [Cross-tool portability](#cross-tool-portability) below.

Typical files are:

```
MEMORY.md
feedback_*.md
project_*.md
reference_*.md
user_*.md
episodes.jsonl
```

`<id>` is the project identifier derived from the sanitized absolute path of the checked-out project root.

## MEMORY.md as the inject index

`MEMORY.md` is loaded into context automatically for applicable sessions. Keep it as the index only:

- short bullet list entries (`- [Title](file.md) — hook text`)
- concise link text and hook lines
- frontmatter-rich detail in the referenced files

The runtime flow is simple: one always-loaded entry file (`MEMORY.md`) plus optional reads from its linked cards.

## Four card tiers

The curated cards are split by purpose so the index can stay compact and the loader can fetch depth only when needed.

| Pattern | Tier purpose | Scope |
|---|---|---|
| `feedback_*.md` | Durable feedback memory | Explicit preferences, constraints, and repeated user or reviewer guidance |
| `project_*.md` | Durable project memory | Architecture, flow definitions, PM decisions, and repo-specific invariants |
| `reference_*.md` | Durable reference memory | Stable references for command usage, scripts, and external expectations |
| `user_*.md` | Durable user memory | Personal workflow preferences and maintainable guardrail notes for the maintainer |

`episodes.jsonl` remains the episodic layer (append-only session summaries) and feeds `/mem-recall` and `/mem-distill` when needed.

## Card frontmatter schema

Card frontmatter is **additive**. The legacy block — `name`, `description`, and
the `metadata:` map (`node_type`, `type`, `originSessionId`) — is preserved
byte-for-byte; the standardized fields append as **top-level YAML after the
`metadata:` block**. The `metadata:` block must never be removed or renamed: the
external memory-graph tool keys off `metadata.node_type`/`type`, and
`/memory-compress` reads `metadata.type` for merge-by-tier.

| Field | Type | Notes |
|---|---|---|
| `topics` | list<str> | retrieval/trust ranking facets (consumed by `pmctl context --source memory`) |
| `priority` | enum | exactly one of `always` / `normal` / `low` |
| `status` | str | lifecycle, e.g. `active` |
| `updated_at` | str | `"YYYY-MM-DD"` |
| `expires_at` | str | optional expiry date |
| `repo_refs` | list<str> | machine-checkable refs (may be empty `[]`) — see grammar below |

Example (additive — legacy block unchanged):

```yaml
---
name: development-workflow
description: …
metadata:
  node_type: memory
  type: feedback
  originSessionId: …
topics:
  - workflow
priority: normal
status: active
updated_at: "2026-06-23"
repo_refs:
  - flag:pmctl gate run --executor codex
---
```

### `repo_refs` grammar

Each ref is a machine-checkable pointer so the health check can detect staleness.

| Kind | Syntax | Fresh when |
|---|---|---|
| file | `path:<repo-root-relative>` (no leading `/`) | `test -f "$REPO_ROOT/<path>"` |
| symbol | `fn:<rel-path>#<symbol>` | file exists AND a shell def `^<symbol>()` / `^function <symbol>` is found |
| flag | `flag:<invocation> <--flag-token>` | the `--token` is found under `scripts/` |

A ref that fails its check is **stale** and surfaces in `pmctl memory doctor`.
An out-of-grammar ref is also reported stale rather than silently fresh: a
`path:`/`fn:` path that is absolute or contains a `..` segment (it must stay
repo-root-relative), or an `fn:` symbol that is not a shell identifier. `repo_refs`
accepts both block-style (one `- ` item per line) and flow-style (`[a, b]`) YAML
lists; the doctor parses and staleness-checks both.

## Health check: `pmctl memory doctor`

`pmctl memory doctor` is a **read-only** reporter over the memory dir — it
mutates nothing. Write-time enforcement is already live: `/mem-distill` and
`/memory-compress` both block a write when a card is missing a required field.

```sh
pmctl memory doctor [--json] [--repo-root <path>]
```

Report fields (ordered): `memory_dir`, `entry_count`, `memory_bytes`,
`episodes_bytes` (0 if absent), `shard_count`, `dead_links` (MEMORY.md link → missing file),
`orphan_cards` (card present but unreferenced, MEMORY.md excluded),
`duplicate_hooks` (hook text on ≥2 index lines), `stale_repo_refs`
(`{card, ref}` per the grammar above), `cards_missing_fields`
(`{card, missing: [...]}` for any card lacking a required field —
`topics`/`priority`/`status`/`updated_at`/`repo_refs`; `repo_refs` may be `[]`
but the key must exist), `issues_count`. `--json` emits a single object carrying
`schema_version: 1`. Exit codes: `0` healthy, `1` issues found, `2` usage error.
When explicit canonical resolution is invalid, the report remains read-only and
returns one additive `resolution_issues` entry with the rejected source and
reason; it never inspects a legacy fallback as though that were the selected
project store.

`cards_missing_fields` lists any not-yet-migrated card still lacking a required
field — useful for spot-checking coverage even though write-time enforcement is
already active.

## Injection benefit: `pmctl memory stats`

`pmctl memory doctor` answers "is the memory dir well-formed". `pmctl memory
stats` answers a different question: **what does having memory actually buy
me?** It is also strictly read-only, and it opens no new telemetry write
surface — every number is aggregated from files other commands already
maintain (the MEMORY.md index, the usage sidecar written by
`guard-inject-memory.sh`, and `episodes.jsonl`).

```sh
pmctl memory stats [--json] [--repo-root <path>] [--never-hit-limit <n>] [--hit-limit <n>]
```

Report fields: `index_entry_count` (MEMORY.md index lines — the unit injection
ranks), `card_count` (distinct linked card files — the unit the usage sidecar
keys on; two index lines pointing at one card count as one card),
`index_inject_bytes` with `inject_budget_bytes` / `inject_budget_entries`,
`usage_store` (`sqlite3` / `tsv` / `none` / `error`), `cards_with_hits`,
`cards_never_hit`, `total_access`, a `concentration` block, `last_hit_buckets`
(the same day boundaries `memory_age_bucket` uses for frecency, so the report
and the ranking agree), `card_hits`, `never_hit_cards`, `unmeasurable_cards`,
`episodes_total`,
`episodes_with_summary`, `episode_fill_rate_pct`, `episodes_malformed`,
`episodes_status`, and `shard_count`. `--json`
emits a single object carrying `schema_version: 1`. Exit codes: `0` report
emitted, `1` canonical memory selection invalid, `2` usage error — an unhealthy
*number* is never an error exit, because this is a report, not a gate.

`index_inject_bytes` is measured exactly the way `guard-inject-memory.sh`
measures its own budget (`${#line}` under the ambient locale), so the two are
directly comparable. Note that this is a character count, not a byte count, for
non-ASCII index text — the number tracks what the hook enforces rather than
what the name literally promises.

`card_hits` is the per-card answer to "which card is repeatedly selected":
`{card, access_count, last_access_day}` rows ordered most-hit first, bounded by
`--hit-limit` (default 20, `0` = no cap) with `card_hits_truncated` marking a
cut list. Counts and `cards_with_hits` are never capped, so bounding the list
never falsifies the totals. Cards with no recorded access are absent here and
listed under `never_hit_cards` instead.

`unmeasurable_cards` holds indexed cards whose path contains a tab or newline.
The usage sidecar is tab-delimited and its writer refuses such a relpath, so
their usage can never be recorded — calling them never-hit would assert an
absence of use this telemetry never measured. Making them measurable requires
changing the sidecar encoding, which is a write-surface change and therefore
outside this read-only command.

**Reading the concentration block.** `hit_coverage_pct` is the share of cards
that have ever been hit; `top5_share_pct` is the share of all accesses
belonging to the five most-hit cards. These exist because raw hit counts look
*healthiest* in exactly the state that is worst: when every card is hit on
every prompt, ranking has no discrimination left and injection degrades into
"emit whatever fits the budget". A coverage near 100% combined with a
`top5_share_pct` close to `5 × 100 / cards_with_hits` (the perfectly flat
value) is that failure, not health.

`usage_store: error` means the sidecar exists but could not be read (corrupt,
locked, or permission-denied). This is reported distinctly because an absent
sidecar and an unreadable one both yield zero rows, but only the first is
evidence that the cards went unused — silently collapsing the second into
"no activity" would invite exactly the wrong retention decision.

`episode_fill_rate_pct` counts only episodes whose `summary` has
non-whitespace content. The Stop hook writes empty skeletons and `/mem-log`
fills them in by hand, so a low fill rate means `/mem-distill`'s upstream is
dry — a fact that was previously invisible. `pmctl memory rebuild-summary`
applies the same emptiness rule, so one concept does not get two answers.

Rows that fail to parse are reported as `episodes_malformed` rather than
discarded, and `episodes_status: error` marks an episodes file that exists but
could not be read at all. Same reasoning as `usage_store: error` — this report
is cited in retention decisions, so corrupt data must never be presentable as
an empty history.

Human output renders memory-derived paths with control characters escaped as
inert `\xNN` text. Index link targets and directory names are attacker-
influenced in the sense that anyone able to write a card or name a directory
chooses them, and a terminal will act on ESC/OSC bytes it is handed. The scan
decodes UTF-8 rather than escaping bytes, so C1 controls (including the raw
`0x9B` CSI byte, which `[[:cntrl:]]` does not match) are neutralized while CJK
card names pass through intact. `--json` applies the same decoding, emitting
C1 as `\u00XX`: JSON does not require escaping C1, but this output is read
straight in a terminal, and a raw C1 byte is not valid UTF-8 either.

## Bootstrap-empty pattern for fork users

Fork users can start with no cards and still keep the setup stable:

1. Create the memory directory path only:

```sh
mkdir -p "$HOME/.claude/projects/<id>/memory"
```

2. Add a minimal `MEMORY.md` seed:

```text
# Memory

This is a fork-owned inject file.
```

3. Use `/mem-log` at the end of a useful session to build the first episodic entries.

4. Promote recurring session facts with `/mem-distill` when the first durable rules appear.

This keeps bootstrap lightweight and avoids carrying stale upstream defaults into a private adaptation.

## Private-repo symlink pattern (optional)

If you want durable memory cards to stay outside this public repo, you may symlink the memory directory to a separate private repository and keep this repo as launcher-only state.

Use this pattern when:

- you want memory cards to be version-controlled privately,
- your private note history should evolve independently from public installer scaffolding,
- you want to share installer behavior without sharing personal memory snapshots.

The key behavior stays unchanged: hooks still target `~/.claude/projects/<id>/memory/`, while that path can be backed by a private location maintained in your fork workflow.

## Cross-tool portability

Memory cards, `pmctl memory doctor`, and `pmctl context --source memory` are
already tool-neutral: cards are plain Markdown+YAML, and retrieval goes
through `pmctl`, not a Claude-specific format. The two remaining Claude-only
pieces are the memory directory's default *location* and its *injection*
mechanism — both now have an explicit seam so other tools (codex, opencode,
future hosts) can share the same memory without depending on Claude Code.

**Location seam**: the memory-dir resolver (`find_memory_dir`) honors an
explicit override, checked in this order:

1. `PM_MEMORY_DIR` environment variable (highest priority; works everywhere,
   including the Claude Code hook path, at zero extra cost)
2. the matching `memory.projects.<project_key>.dir` entry in
   `~/.pm-dispatch/config` (checked by CLI-driven callers — `pmctl memory *`,
   `pmctl context --source memory`, installer/migrator scripts — not by the
   low-latency `memory.sh` hook path itself)
3. the `CLAUDE_CONFIG_DIR/projects/<id>/memory/` convention (unchanged
   default when neither override is set)

The deprecated `dispatch.memory_dir` global key is unsafe in a multi-repo
environment. Strict resolution returns `invalid-explicit` with
`resolution_source: config-legacy-global`; compatibility discovery ignores the
value and warns. Migrate it atomically for one repository with:

```bash
pmctl memory config migrate --repo-root /absolute/repo --json
pmctl memory config lint --json
```

For a new or replacement mapping, use `pmctl memory config set --repo-root
/absolute/repo --memory-dir /absolute/memory`. Both commands preserve unrelated
config lines; `set` removes a remaining unsafe global key. Repeating `migrate`
after success is a no-op. Tests must still isolate operator config with
`PM_DISPATCH_CONFIG_FILE`; they must never assume `~/.pm-dispatch/config` is
absent.

An unset override falls through to the next tier. Once an environment override
or matching project-scoped config entry is present, however, an invalid or
missing target fails closed for `pmctl memory`, direct memory-context indexing,
and installer/migrator discovery. Mutating maintenance commands such as `shard`
and `rebuild-summary` therefore cannot redirect writes into a legacy store.

At a **host-switch boundary**, use the stricter diagnostic contract instead
of relying on that compatibility fallback:

```bash
pmctl memory resolve --repo-root "$(pwd)" --json
```

The result identifies the canonical repo, stable project key, selected memory
directory, and resolution source (`env`, `config`, `legacy`,
`config-legacy-global`, or `none`). An explicit `PM_MEMORY_DIR` or matched
project-scoped config path that is unavailable returns
`status: invalid-explicit` and exit 3; it never falls through to another
host's legacy directory. With no explicit selection, legacy Claude discovery
remains compatible, and absence is reported as `unavailable`.
Exit codes are `0` resolved, `1` unavailable, `2` usage error, and `3`
invalid explicit selection.

Lifecycle adapters that can receive a real directory outside a Git worktree
use `--allow-non-git`. That option keeps env/config validation and legacy
discovery inside this same resolver, while deriving a deterministic path key;
hooks must not reconstruct a synthetic resolution record themselves. Normal PM
preparation and dispatch remain Git-only.

**Injection is a per-tool adapter, not part of the portable core.** The
portable core is strict resolution, `pmctl context --source memory`, and the
canonical write API. Claude and Codex can both run the host-neutral
`guard-inject-memory.sh` on `UserPromptSubmit`; OpenCode's installed `/pm`
command calls its `pm_prepare` custom tool; a host with neither mechanism uses
`pmctl pm prepare --host generic` directly. All four routes expose pmctl as
canonical and label unobserved host-native memory `auxiliary/unknown`.

For every batch PM interface, this call is deterministic rather than a model
convention: `pmctl pm prepare --host <name>` runs strict resolution and a bounded,
request-scoped memory query on every preparation. Its JSON contract carries
`memory_resolution`, `memory_provenance`, `memory_context_status`, and the retrieved
`memory_context`, so a calling host can verify which canonical memory it used.
No memory or zero hits is fail-open; an invalid explicit selection is
fail-closed to prevent silent continuity loss.

Writes use the same resolver. `pmctl memory append-episode --repo-root <repo>
--host <name> --summary <text>` appends one locked JSONL record to the resolved
canonical `episodes.jsonl`. It refuses invalid explicit paths, unwritable
directories, and symlink episode targets; it never accepts a caller-guessed
memory directory. `--host` is required and has no default: it records the
adapter that actually initiated the event, while project identity alone selects
the canonical destination. `/mem-log` and each host's Stop adapter both use this
API; skeleton session-id dedupe happens inside the same append lock.

| Host | Deterministic read entry | Canonical write entry | Native memory |
| --- | --- | --- | --- |
| Claude | `/pm` calls `pm prepare --host claude`; `UserPromptSubmit` runs `guard-inject-memory.sh` | `pmctl memory append-episode --host claude` | auxiliary; `unknown` unless separately observed |
| Codex | `UserPromptSubmit` runs `guard-inject-memory.sh`; batch PM uses `--host codex` | `codex-memory-update.sh` routes explicit requests to `pmctl memory append-episode --host codex`; `Stop` writes a canonical skeleton | auxiliary; `unknown` unless separately observed |
| OpenCode | `/pm` calls the installed `pm_prepare` tool with `--host opencode` | `pmctl memory append-episode --host opencode` | auxiliary; `unknown` unless separately observed |
| Generic/no hook | `pmctl pm prepare --host generic` | `pmctl memory append-episode --host generic` | auxiliary; `unknown` |

## Practical conventions

- Keep `MEMORY.md` short and high-signal.
- Put permanence into card files (`feedback_`, `project_`, `reference_`, `user_`).
- Use `/memory-compress` after heavy memory growth.
- Run `/mem-recall` for session continuity before a major `/pm` batch.
- Keep `episodes.jsonl` append-only for auditability.

### Codex explicit update requests

The Codex host installer adds a marker-delimited block to
`$CODEX_HOME/AGENTS.md`. When a user explicitly asks to update, save, or record
project memory, that guidance routes the action through:

```bash
/path/to/pm-dispatch/hosts/codex/bin/memory-update.sh \
  --repo-root "$(git rev-parse --show-toplevel)" \
  --summary "$SUMMARY" \
  --json
```

The wrapper fixes writer provenance to `codex` and delegates path selection to
the strict resolver. It never accepts a native-memory path. `AGENTS.md` is a
model instruction surface, not a filesystem access-control boundary, so the
installer and tests make the supported route deterministic while the
filesystem-diff E2E verifies that this route changes only canonical
`episodes.jsonl`. Invalid explicit memory remains fail-closed.


## Runtime conventions

1. Keep the index (`MEMORY.md`) deterministic: one purpose per entry, one sentence per hook.
2. Prefer edits through slash-command flows so changes stay within the declared scope.
3. Treat `/mem-distill` output as a proposal until reviewed; write only when confirmed.
4. Keep stale entries visible until manually archived to avoid accidental loss of context.
5. Let a fork owner keep this document as a local contract and update it with their own private conventions over time.
