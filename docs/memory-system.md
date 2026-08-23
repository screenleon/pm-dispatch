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
ranks), `unparsed_index_entries` (index lines with no parseable `.md` link;
counted separately because they are not cards and must not enter the per-card
ratios), `card_count` (distinct linked card files — the unit the usage sidecar
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
measures its own budget (`memory_byte_len_var`, actual UTF-8 bytes), so the two
numbers are directly comparable and both match what `MEMORY_MAX_INJECT_BYTES`
actually bounds — including CJK-heavy lines, which `${#line}` would have
undercounted.

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
non-whitespace content. A Stop hook previously wrote empty skeletons for
`/mem-log` to fill in by hand; it is retired (fill rate stayed at 8-12% for
over two months, the trial period the card that added it named), so
`/mem-log` is now the only writer and every episode it appends already has a
summary. The metric and `pmctl memory rebuild-summary`'s emptiness rule are
kept for episodes.jsonl history that still holds skeletons from before the
retirement.

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

## Per-prompt token cost

This is the number readers actually want before turning the hook on or off:
what does `guard-inject-memory.sh` cost per turn, and what does it buy back.

**It runs every turn, not once per session.** `MEMORY.md` is not a one-time
system-prompt load — the hook is wired to `UserPromptSubmit`, so it re-reads
the index, re-ranks it against the *current* prompt's keywords, and re-injects
a block on every single user message. A 30-turn session pays this cost 30
times, not once.

**Per-injection size is capped, but the cap is generous relative to a typical
turn.** `MEMORY_MAX_INJECT_BYTES=3000` plus a ~250-byte preamble and an
optional one-line episode reminder — call it ~3300 bytes worst case. For this
repo's own memory store (mixed English/Mandarin, see `pmctl memory stats`
above), that lands around **900–1300 tokens** per prompt at full budget, and
commonly less: the byte cap, not the 20-entry cap, is usually what truncates
first when hook text runs long, so a real injection often lands closer to
15-18 entries and 600–900 tokens. There is no per-prompt way to see this
number directly in-session; run `pmctl memory stats` to see what the *whole*
index would cost against the same budget arithmetic.

**It does not benefit from prompt caching.** The block is re-ranked by
keyword hits against each new prompt (see the composite score in
`guard-inject-memory.sh`), so its content is very likely to differ turn to
turn. It doesn't invalidate the cached prefix from earlier turns — hooks
append to the new turn, they don't rewrite history — but the injected content
itself is paid for fresh, uncached, on every single turn where the hook fires.

**What this buys back:**
- Continuity that survives context compaction and new sessions without the
  user re-stating standing preferences, project facts, or prior corrections.
- Structural enforcement instead of prose. CLAUDE.md-style "never do X" rules
  hit ~70% compliance in public research; a hook that mechanically injects the
  card every time closes that gap for anything actually indexed.
- Usage-weighted ranking (frecency + keyword hits) means the cards that keep
  mattering surface first as the store grows, rather than an unranked dump.

**What it costs beyond the raw tokens:**
- The tax is flat per turn regardless of whether the current prompt needs any
  memory at all — a one-line "yes, ship it" pays the same preamble-plus-budget
  cost as a prompt that actually needs recalled context.
- At scale the budget silently degrades: this repo's store has 86 cards behind
  a 20-entry/3000-byte window, so most cards are invisible on any given prompt
  unless a keyword hits them (`pmctl memory stats` reports the omitted count
  every run — 62–70 cards omitted here is typical, not an anomaly).
- Unlike the context-retrieval hook (`PM_DISPATCH_DISABLE_PROMPT_CONTEXT=1`,
  see [context-retrieval.md](context-retrieval.md#prompt-auto-scan-deterministic-retrieval-at-prompt-time)),
  there is no env-var kill switch for this hook — turning it off means
  removing `guard-inject-memory.sh` from `~/.claude/settings.json`, which also
  turns off frecency tracking (the sidecar only accrues hits when the hook
  runs).

**Levers, cheapest first:**
- Lower `MEMORY_MAX_INJECT_ENTRIES` / `MEMORY_MAX_INJECT_BYTES` (`lib/memory.sh`)
  if the per-turn tax matters more than breadth.
- Run `/memory-compress` periodically — it shrinks index *entries* (the hook
  text), which is the part charged every turn, without touching card detail.
- Keep `priority: always` reserved for genuinely session-invariant facts: tier1
  cards bypass the byte budget entirely, so an over-pinned index inflates the
  floor cost of every single prompt regardless of relevance.

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
the canonical destination. `/mem-log` is the sole writer — the Stop-hook
skeleton writer and its `--skeleton` session-id dedupe mode are retired.

| Host | Deterministic read entry | Canonical write entry | Native memory |
| --- | --- | --- | --- |
| Claude | `/pm` calls `pm prepare --host claude`; `UserPromptSubmit` runs `guard-inject-memory.sh` | `pmctl memory append-episode --host claude` | **auxiliary; CONFIRMED double-injected (2026-08-23)** — Claude Code's own project-memory feature loads the entirety of `MEMORY.md` once at session start (a `claudeMd`-labeled context block, unbounded — no relation to `MEMORY_MAX_INJECT_BYTES`), separately from `guard-inject-memory.sh`'s own per-turn budgeted injection. Observed on this repo's own store: ~14KB / ~86 entries loaded natively once (≈5,500–6,500 tokens), on top of the hook's ~600–1,300 tokens *every* turn. See [Per-prompt token cost](#per-prompt-token-cost) and the "Double-injection on Claude" note below. |
| Codex | `UserPromptSubmit` runs `guard-inject-memory.sh`; batch PM uses `--host codex` | `codex-memory-update.sh` routes explicit requests to `pmctl memory append-episode --host codex` | **auxiliary; CONFIRMED not duplicated (2026-08-23)** — Codex's native `AGENTS.md` install target (`hosts/codex/host.yaml`) is real, but the marker-delimited block `codex_memory_contract_append` writes (`hosts/codex/lib/memory-contract.sh`) is fixed procedural text (~20 lines / ~300 tokens: "write memory via pmctl, never under `.codex/memories`"), not the `MEMORY.md` index content. Codex also has its own native memory store (`.codex/memories`), but the contract text explicitly redirects the model away from ever writing there, so it stays empty and never becomes a second copy of canonical memory. Codex's *only* per-turn memory content comes from the same `guard-inject-memory.sh` budget as everyone else. |
| Grok | `pmctl pm prepare --host grok` only (explicit call; MVP) | `pmctl memory append-episode --host grok` | **repo side confirmed clean; host side unverified** — `hosts/grok/host.yaml` declares `hook_surface: {}`: no `UserPromptSubmit` wiring ships at all in this MVP, so pm-dispatch cannot cause a double-injection here today. Whether the Grok Build TUI itself has its own passive project-memory auto-load (independent of this repo) has not been observed — verifying requires running `grok` against a populated memory dir and inspecting its own verbose/debug session log, which is outside what this repo's code can confirm. |
| OpenCode | `/pm` calls the installed `pm_prepare` tool with `--host opencode` | `pmctl memory append-episode --host opencode` | **repo side confirmed clean; host side unverified** — same `hook_surface: {}` situation as Grok: no automatic hook, memory only flows through an explicit `/pm` call. OpenCode's own native memory behavior (if any) is unobserved for the same reason as Grok. |
| Generic/no hook | `pmctl pm prepare --host generic` | `pmctl memory append-episode --host generic` | auxiliary; `unknown` |

### Double-injection on Claude

Confirmed 2026-08-23 by direct inspection of a live Claude Code session's
injected context against this repo's own `MEMORY.md` (14,055 bytes / 86
entries, `wc -c` on the canonical file matched the size of the natively
loaded block exactly). Two independent, non-coordinating mechanisms both put
`MEMORY.md` content into context:

1. **Claude Code's native project-memory load** — a `claudeMd`-labeled
   context block containing the *entire* `MEMORY.md`, unbounded, injected
   once (observed at the first turn after `/clear`). This is a Claude Code
   product feature, not a `pmctl`/repo mechanism — pm-dispatch cannot
   configure, cap, or disable it, and its behavior is not covered by any
   test in this repo.
2. **`guard-inject-memory.sh`** — the canonical, tested, host-neutral hook
   documented throughout this file, budgeted to `MEMORY_MAX_INJECT_BYTES`
   (3000) / `MEMORY_MAX_INJECT_ENTRIES` (20), re-ranked and re-injected on
   *every* `UserPromptSubmit`.

These are not simply redundant: (1) is a black box this repo does not
control or test — the canonical-memory design principle throughout this file
("never fall through to native or legacy memory") already treats any
host-native memory as untrusted, so (2) remains necessary as the only
guaranteed, tested delivery path regardless of what Claude Code's native
feature does or stops doing. The actual waste is that `MEMORY_MAX_INJECT_BYTES`
was sized without accounting for (1) already having delivered a full copy
once per session on Claude specifically — Codex has no equivalent native
full-load (see the Codex row above), so the same constant is correctly sized
there. **[[CC-566]] shipped this fix**: `guard-inject-memory.sh` now accepts
an explicit, non-ambient `--host <name>` argument — the same
`claude|codex|opencode|grok|generic` shape `install-guards.sh`/`doctor.sh`
already recognized and stripped before comparison (`without_host_arg`),
scaffolding that predated this fix and was never previously exercised.
`hosts/claude/bin/install-guards.sh` wires the hook with `--host claude`,
which selects `MEMORY_CLAUDE_MAX_INJECT_ENTRIES` (10) /
`MEMORY_CLAUDE_MAX_INJECT_BYTES` (1500) instead of the shared
`MEMORY_MAX_INJECT_ENTRIES` (20) / `MEMORY_MAX_INJECT_BYTES` (3000) — roughly
halving the per-turn hook cost on Claude. Codex's wiring
(`hosts/codex/bin/install.sh`) is untouched: no `--host` argument, so it keeps
the full shared budget, since it has no equivalent native full-load safety
net. The argument is deliberately a CLI flag baked into the wired command
string, never an env var — `MEMORY_MAX_INJECT_BYTES` is deliberately not
env-overridable per the comment in `lib/memory.sh`, to avoid the ambient-leak
class of bug from [[env-var-ambient-leak-into-fixtures]]. A pre-CC-566 install
(bare path, no `--host`) self-heals on the next `install-guards.sh` run:
`managed_shared()`'s existing `without_host_arg` stripping still recognizes it
as the managed hook and rewrites it to the suffixed form.

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
