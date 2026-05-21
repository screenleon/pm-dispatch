## Q1 - Tier choice
Recommendation: adopt codegraph fast tier as the first-class enrichment tier for `briefs` `files:` auto-fill. [lightweight]

- Fast tier [lightweight]: `codegraph context "<task>" --no-code` on a 91-source-file Go+TS repo is ~517 chars (~130 tokens) and already returned matching `path:line` symbols + entry points; this is directly in the right shape for concise `files:` injection and avoids full file reads.
- Fast tier [lightweight]: full index is ~2.9s with tree-sitter-only indexing (no LLM, no LSP, no embeddings), so startup/install runtime is bounded and predictable for multi-language targets.
- Rich tier [heavy]: LSP/embedding/dataflow tiers are only justified if tasks require high-precision symbol resolution beyond lexical/structural matching or architecture-level queries. Given the goal is to cut exploration reads and reduce token burn from missing file lists, the fast tier already addresses the problem with significantly lower operational cost.
- Recommendation rating (Q1): [lightweight] on default path, because token-cost reduction is likely achieved at the same time as avoiding the heavy dependencies explicitly rejected in constraints.

## Q2 - Indexing cadence for multi-repo dispatch
- (a) Index on-demand right before each dispatch [medium]: no staleness risk because indexing is immediately fresh; cost is paid every run (2.9s on a mid-size repo in the provided baseline) and scales poorly as dispatch count and target count grow.
- (b) Persistent per-repo index with `codegraph sync` (and optional initial bootstrap) [lightweight]: best balance; usually one-time bootstrap per repo plus quick sync/update work at call-time, good fit for “intermittent, multiple repos” because it reduces repeated full-index cost while keeping stale risk bounded by the sync interval.
- (c) Background watcher daemon [heavy]: explicit file-watcher process per repo is a long-running dependency that is hard to justify for intermittent repos; state drift with repo lifecycles (moved/removed worktrees, offline periods) adds hidden complexity with little benefit over on-demand `sync`.
- Recommended cadence for Q2: [lightweight] option (b). Degradation path: if sync fails or no index is present, fall back to an on-demand full index and log a warning rather than silently using stale/empty context.

## Q3 - Lighter alternatives
- Universal-ctags tags file [lightweight]: provides fast symbol-to-path candidates and does not require heavy services. It gives cheap candidate discovery for mechanical rename/entry-point-like tasks, but no built-in semantic ranking against a natural-language task and weaker handling of multi-symbol disambiguation.
- git grep / ripgrep symbol scan [lightweight]: zero extra infra, immediate and deterministic, and useful for exact-name discovery (`func`, `class`, `export`, TODO markers). It misses ranking and task-semantic expansion, so it tends to over-select when user language is vague or abstract.
- codegraph `query`/`files` subcommands (without full `context`) [lightweight]: if available from the same fast index, this is probably the closest low-cost substitute to full `context` with less payload and still structured file hints. It remains index-dependent, and the practical benefit is narrower than full context output.
- Missing vs codegraph-full-context in Q3: ctags/rg are generally good at explicit symbol discovery; codegraph query/files are generally better at task-to-symbol mapping but cannot help if syntax/semantic intent is absent. Compared to full `context`, they trade recall/clarity for lower per-call output size.
- Ratings summary: ctags [lightweight], rg [lightweight], codegraph query/files [lightweight].

## Q4 - Risks and failure modes
- Stale index feeds wrong files [high]: stale entries can under- or over-scope a dispatch and either miss needed files or add noise; mitigate with per-repo `sync` before dispatch, TTL/age check, and hard fallback when index timestamp is too old or unavailable.
- Extra global npm dependency on codegraph [medium]: introduces install and supply-chain/toolchain risk for environments with strict package policies; mitigate with opt-in enablement and clear preflight check before use.
- `.codegraph/` artifact placement and `.gitignore` hygiene [medium]: index artifacts can clutter diffs or leak large generated files; mitigate with strict repo-local placement, auto-ensure `.gitignore` entry/guardrails, and explicit “do-not-treat-as-source” policy in dispatch logs.
- Multi-repo index management [high]: many target repos mean many local index states, orphaned indexes for stale repos, and mixed update cadences; mitigate with metadata tracking (repo path + index age + commit SHA), eviction policy, and cleanup on dispatch failures.
- Missing/empty index behavior [high]: empty/missing index would degrade quality if treated as authoritative; mitigate with explicit downgrade path that preserves current `files:` behavior and marks enrichment as “best-effort only”.
- Severity summary: stale index and missing/empty index are the top user-visible correctness risks; dependency and multi-repo management are medium-to-high operational risks in heterogeneous CI/dev environments.

## Verdict
Adopt a light-weight, optional codegraph path using fast-tier indexing and fast-path `sync`-on-use (not a resident daemon), with graceful fallback to existing `files:`/read-only brief behavior when index quality is uncertain. The key reason is this is the smallest change that targets the real pain point (missing file scope causing Codex exploration) without importing heavy services that conflict with the project’s lightweight constraint.
