# Changelog

All notable changes to pm-dispatch are documented here.
Format inspired by [Keep a Changelog](https://keepachangelog.com/).
Versions follow [Semantic Versioning](https://semver.org/).

---

## [Unreleased]

### Changed

- **The memory injection budget is now measured in actual UTF-8 bytes, not
  characters.** `pmctl memory stats` and the `UserPromptSubmit` injection hook
  both used bash's `${#line}`, which counts characters under a UTF-8 locale — a
  CJK character is 3 bytes but counted as 1, so a CJK-heavy `MEMORY.md` index
  undercounted its real injection cost by roughly a quarter against
  `MEMORY_MAX_INJECT_BYTES`, a budget whose name and purpose are both
  byte-based. Both call sites now share `memory_byte_len_var` (`lib/memory.sh`),
  a no-fork helper (temporarily switches to the C locale, where `${#s}` counts
  bytes) so the fix does not add a subprocess to a per-line hot path. The
  `/memory-compress` skill's authoring rule changes from "≤ 150 characters" to
  "≤ 150 UTF-8 bytes" to match what is actually enforced.
- **The Stop-hook episode skeleton writer is retired**, along with the
  `session_lifecycle` host-contract capability it was the sole implementation
  of (`docs/host-contract.md`'s capability enum drops from five entries to
  four; `hosts/claude/host.yaml`, `hosts/codex/host.yaml`,
  `hosts/opencode/host.yaml`, and `hosts/grok/host.yaml` all lose their
  `session_lifecycle` declaration). The card that introduced it named its own
  exit condition — a trial period ending in the writer being dropped if
  episode fill rate stayed low — and two audits two months apart (12%, then
  8%, declining rather than stable) confirmed it. `/mem-log` is now the sole
  episode writer; every episode it appends already carries a real summary, so
  `episode_fill_rate_pct` and `pmctl memory rebuild-summary`'s emptiness rule
  are kept only for `episodes.jsonl` history that predates the retirement.
  `pmctl memory append-episode`'s `--skeleton` mode and its session-id dedupe
  are removed as dead code with the writer gone. `install-guards.sh` /
  `hosts/codex/bin/install.sh` no longer register the hook and now prune it
  from an existing install; `runtime/hooks/guard-session-summary.sh` itself is
  deleted.

- **`/ship` now governs the *form* of a finding's remedy, not just that it is
  fixed (CC-554).** Every finding is still addressed — an unaddressed finding
  remains a NO-GO — but when the proposed remedy is a *new permanent blocking
  test*, it must first clear the admission criteria in the configured QA rules
  checkout (`QA_RULES_DIR`'s Tier 1 entry). A case that pins a private helper
  or source literal, covers input outside the project's declared support range,
  duplicates an existing broader scenario, or survives mutation of the code it
  claims to guard is closed instead by a recorded alternative: fix without a
  permanent test, fold into an existing parameterized case, move to an extended
  suite, open a follow-up ticket, or reject the finding with evidence. The
  PR body records the decision **either way** — the criteria an admitted case
  meets, or the alternative taken and why — because a silent admission and a
  criterion never consulted otherwise leave the same record, which makes the
  count of alternatives taken meaningless on its own. `commands/ship.md`
  carries a self-contained summary so a substituted rules directory that
  defines no such criteria still gets the policy. Round count is deliberately
  left alone as a stopping condition — reducing test growth is done at the
  finding end, not by capping gate rounds.

- **v0.11.0 P0/P1 planning records reconciled against what actually shipped.**
  CC-517 and CC-529 recorded no delivering PR at all despite #483 and #484;
  CC-511 and CC-527 carried status dates older than their own bodies. The P0
  "current-tree full suite" row is closed as absorbed by CC-511 Phase A rather
  than tracked as work — it is an invariant that decays on every merge, so it
  could never reach a terminal state (see DECISIONS 2026-08-20). CC-517 moves
  from active to partial: its main body shipped, contrary to an earlier reading
  of this ticket taken from a phrase search rather than the implementation.

- **The publish authorization route now names what actually authorized the
  publish (CC-511 Phase B).** It was derived from whether a targeted
  confirmation ran; the route it labels is defined by whether the primary
  review examined the final tree, which the closure records directly as
  `primary.subject` versus `final_subject`. Those answer different questions
  and the closure schema lets them disagree — a remediation closed entirely
  locally needs no targeted confirmation while leaving the primary review bound
  to a pre-remediation tree, which the old derivation labelled a `final_tree_review`
  that never happened. A four-row matrix now covers both routes across both
  confirmation states; `final_tree_review` had previously only ever appeared as
  fixture input, never as an asserted build output.
- **`pmctl ship finish --help` keeps naming `--gate-result` and `--full-result`
  (CC-529).** The parser's mutual-exclusion behavior already had an oracle; the
  public option list had none, and the existing discovery test only asserts that
  a `Main options:` section exists, not what any command puts in it.

- **The context index now holds a file's actual content (CC-505 Phase 1).**
  Every non-markdown file — shell included — was stored as a single chunk
  holding the first 200 characters, so function bodies were not in the index at
  all; they are now windowed with bounded bodies. Content past the cap is split
  across chunks rather than truncated — for a long markdown section and equally
  for a single physical line longer than the cap, whose tail would otherwise be
  dropped by the SQL escaper while indexing reported success. Window size and cap were chosen from measured
  body lengths so the cap guards outliers instead of truncating routinely.
  Measured cost on this repository: chunks 5,027 → 13,041, database 5.5 → 32.6
  MB, full rebuild 1m23s (tracked for follow-up), incremental run 6.3 → 9.3s.
- **An edit that preserves mtime no longer leaves the index silently stale
  (CC-505).** mtime is now a fast path and `files.sha1` decides. A new
  `index_meta` table records the extractor version, and a change to it forces
  re-extraction — without that, a chunker change leaves existing databases
  serving chunks the current extractor would never produce while every file
  still looks up to date.
- **Removed a hashing subprocess per indexed chunk.** `file_chunks.sha1` has no
  reader anywhere in the repository, and computing it measured at over 40% of
  index time.

- **Context index rebuild is 51% faster (CC-563).** Escaping a value for SQL was
  called through command substitution, which forks a subshell every time — twice
  per chunk and three times per symbol, roughly 26,000 forks on a full rebuild.
  The escaping rule is unchanged; hot paths now assign through `printf -v`
  instead. Full rebuild 1m23s → 40.5s, and 2m40s → 40.5s counting the per-chunk
  hashing removed alongside it. Profiling contradicted the ticket's own guess:
  symbol extraction and escaping together were 7%, not the 60% it assumed.

### Fixed

- **A test that asserts a default no longer measures the caller's environment
  (CC-561).** `jobs-default-caps-high-nproc` stubs `nproc` to 32 to prove the
  parallel cap is 4, but did not control `PM_DISPATCH_TEST_MAX_JOBS` — the knob
  that overrides that cap — so running the suite with it set reported
  "default exceeded high-nproc safety cap of 4" about a subject that was never
  at its default. Third occurrence of the class; the standing defence was a
  hand-written `unset` of two names that only grew after someone was bitten.
  The cleared set now comes from the canonical variable inventory, which gains
  a `fixture_scrub` column because the distinction the fix needs — a knob
  belonging to the *subject a test launches* versus one belonging to the suite
  itself or to its caller — was not expressible before. `input_class` cannot
  separate them and the existing isolation column is free text, so the
  requirement was written down in a form nothing could enforce. Scrubbing is
  applied at `th_init` and by the nine self-contained suites that do not call
  it, and fails closed if the inventory is unreadable or declares nothing.
  `PM_DISPATCH_TEST_COMMAND_IDENTITY` is deliberately preserved: pr-gate
  exports it and the suite result writer consumes it, so it is a contract
  rather than a leak.

- **A synthesis parity rejection now names which entries differ (CC-553).**
  Nine parity checks guard the synthesis artifact, and seven of them returned
  only the name of the check — including `test-gap matrix parity mismatch`,
  which cost a whole gate round on 2026-08-07. Synthesis gets exactly one
  correction retry and the rejection reason is the only information it
  receives, so a reason it cannot act on spends that retry reproducing the same
  output. The `id_delta` helper already existed for precisely this, and the
  comment above it already stated the rule; it was simply applied at two of the
  nine sites. All seven now carry the delta, using a composite key where
  identity is not a bare id (`reviewer:surface` for coverage and uncertain
  cells, `finding_id` for the remediation seed). Two checks that bundled
  several independent rules behind one string — root-cause grouping and
  uncertainties — now say which rule failed before giving the delta, following
  the shape the disagreement check already used. Reason strings keep their
  existing prefixes and only gain detail, so callers matching on them are
  unaffected.

- **Gate scope expansion no longer spawns two processes per candidate
  (CC-557).** Building the scope manifest ran one `jq` to test each expansion
  candidate against the changed-path set and another to build its JSON object,
  so a bounded 512-entry expansion cost 1024 processes. Profiling a case that
  reaches that bound put `_gate_scope_expansions_collect` at 23.2s of a 37s
  total, with fixture setup at 0.27s — the cost was in the production code, not
  in the test. Membership is now answered from a set resolved once per call, and
  entries are appended as NUL-separated fields that the collector's existing
  final `jq` pass decodes in one go, adding no new process. NUL is safe as the
  separator by construction rather than by escaping: a bash string cannot
  contain a NUL byte, so no field value can forge a record boundary. Measured
  1352 → 327 `jq` invocations and 37s → 14s on that case. Every gate builds a
  scope manifest, so real runs benefit too, but in proportion to how many
  expansion candidates the change produces — a typical diff yields far fewer
  than this case's deliberate 512, so the aggregate suite time moves only a few
  percent. The concentrated win is what matters here: the case that sat at
  84-86% of its per-case watchdog now sits at 32% under the same full-suite
  contention.

- **A remediation closure can no longer cite evidence it does not locate
  (CC-558).** `gate-remediation-closure`'s `evidenceRef` expressed "at least one
  locator" as `anyOf: [{required: [line]}, {required: [symbol]}]`. JSON Schema's
  `required` asserts only that the key is *present*, and both properties are
  nullable, so `{"path": ..., "line": null, "symbol": null}` validated — an
  evidence ref pointing nowhere, which still satisfied the per-finding
  "at least one evidence ref" count. Quantity was standing in for
  traceability. Both anyOf branches now narrow the type they require, matching
  what the sibling `gate-reviewer-result` and `gate-synthesis-result`
  definitions already did; the closure schema was the only one that had not.
  The runtime bundle is regenerated from the canonical schema, so the runtime
  claim verifier rejects it too. A standing per-schema invariant now rejects the
  idiom itself: `anyOf` over a bare `required` naming a *nullable* property
  cannot express "at least one", so every such branch must narrow the type it
  requires. All 19 schemas pass it today, and a twentieth cannot reintroduce the
  trap.

- **`pmctl gate wait` no longer reports a running supervisor as dead
  (CC-556).** The supervisor's `supervisor.identity` record was captured by the
  *launcher*, in the window where `setsid` had not yet moved the child into its
  own process group — so the recorded pgid was the launcher's and could never
  match the supervisor again. Any gate that outlived the caller's wait budget
  therefore failed identity re-verification and was announced as
  `supervisor died without terminal evidence` (exit 3), whose natural remedy —
  re-dispatch — discards a healthy in-flight gate and pays for the whole round
  twice. The supervisor now publishes its own identity at readiness, after
  `setsid` has taken effect, so the pgid is self-observed rather than inferred;
  the launcher's provisional snapshot moves to a separate path with a single
  writer each, and is only consulted while the authoritative record does not
  yet exist. `gate wait` also stops collapsing two different answers into one:
  a process the kernel no longer reports is stated as gone, while an identity
  that merely fails to re-verify is reported as unresolved, names the recorded
  pid, and points at the `ps` command that settles it — rather than asserting a
  death it cannot prove.

- **A NO-GO verdict is no longer downgraded to an infrastructure failure
  (CC-555).** pr-gate's exit trap emits its `failure-result:` branch on any
  non-zero status, and a NO-GO verdict *is* exit 1. That was harmless while the
  supervisor read the first matching log line; once the label became
  authoritative for the verdict classification, the trap overwrote a verified
  `result:` handoff and reported a completed review as `failed`. Both emitters
  are now guarded — the handoff file and its stdout twin, since the log
  fallback reads the last match and fixing one end alone would leave the other
  lying. This is the defect this ticket exists to fix with its operands
  swapped, and it was observed live on the first real NO-GO to run under the
  new code.

- **`--mode sequential` gets the same single correction retry as the parallel
  route (CC-555).** The retry loop lived only in the parallel branch, so a
  sequential round whose result failed protocol validation was voided outright
  — reviewers included. That made the mode chosen when session budget is tight
  the only mode with no safety net. Observed when a combined session spent five
  minutes losing a fight with `apply_patch` over the fenced
  `reviewer_result_v1` blocks in the gate result, wrote the reviewer sections
  out of order, and produced no synthesis block. The retry carries the actual
  rejected reason under the same single-line/800-char boundary CC-553
  established, and empties `OUTPUT_FILE` first: the brief has the executor
  create-then-append, so re-authoring over a half-ordered document would
  compound the defect. A stale subject binding still refuses the retry — new
  evidence cannot describe an older tree.

- **A gate protocol failure is no longer reported as a review verdict, and its
  one correction retry is no longer blind (CC-553).** `pr-gate.sh` marks a
  publishable artifact with `result:` and a post-mortem with `failure-result:`,
  but `gate-supervisor.sh` matched either label and kept only the path. Its
  "never encode an infrastructure failure as a verdict" guard keyed off an
  *empty* path, so a protocol failure that retained an inspectable artifact
  satisfied the guard by being non-empty, and exit 1 became `NO-GO`. Because a
  rejected synthesis still contains its own `Final: GO` line, `pmctl gate wait`
  then printed `state: NO-GO` directly above `Final: GO` — an unreviewed
  infrastructure failure presenting as a reviewed verdict, and the friendlier
  line is the one a reader takes. The label is now load-bearing: only `result:`
  means pr-gate stands behind the artifact; `failure-result:` resolves to
  `failed` (exit 2) regardless of the exit code. This is the same
  `infra_error` vs `fail` distinction the QA rules require of test runners,
  applied to the gate itself.

  The synthesis retry brief was a fixed heredoc naming four possible causes
  ("transport, malformed-output, schema, or parity") while `$_synthesis_reason`
  was computed and never passed in, so the single correction attempt re-rolled
  the same prompt and reproduced the same defect — losing the whole round,
  every reviewer session included. The brief now carries the actual rejected
  check.

  Parity reasons in `gate-result-verify.sh` now name the delta instead of
  restating the check: `findings union parity mismatch` and its inventory
  sibling report `missing=[...] unexpected=[...]`, and distinguish a wrong id
  set from matching ids with differing field values — two defects with
  different fixes. `invalid disagreement references` reports each
  offending entry with the specific rule it broke and the observed value,
  rather than one generic list of all six rules the entry contract bundles —
  including why `finding_ids` needs two ids, the rule most often tripped
  innocently when a single reviewer raises a lone objection. CC-553's remaining
  scope (auditing the other multi-constraint reason strings) is unchanged.

  The supervisor no longer learns which handoff a run produced by scanning the
  combined log, which also carries the output of every dispatch session the
  gate spawns. Once the `result:` / `failure-result:` label became load-bearing
  for the verdict classification, a child session printing a `result:`-prefixed
  line before pr-gate's own handoff could have restored exactly the defect
  above. pr-gate now writes its handoff to `pr-gate.handoff` inside the
  `--run-dir` it was given — a file only it writes — and the supervisor prefers
  it, falling back to the log (last match, since the handoff is emitted from
  the EXIT trap after every child finishes) only for a copy-mode or older
  pr-gate that writes none.

  Those diagnostics quote ids read from the **rejected** artifact, and the
  disagreement branch by definition selects entries that failed the shape
  contract — so a quoted id may be any JSON value, including a string
  containing newlines. Since the reason then crosses into a privileged agent's
  retry brief, it is now defended at both ends: the verifier reduces every
  quoted id to a bounded, single-line, punctuation-free token, and pr-gate
  flattens any residual newline before appending the YAML block scalar. Either
  end alone would silently stop protecting the other if it changed, so both
  are asserted.

- **Lint resolves the pinned ShellCheck from the tool cache instead of
  requiring it on `PATH` (CC-551).** `lint-shellcheck.sh` validated only that
  the ambient `PATH` already carried the pinned version, so a gate reviewer or
  CI sandbox with a system ShellCheck stopped `run-tests.sh` at its Phase 0
  structural precheck — no behavioral suite ran at all, and the reviewer
  reported missing execution evidence every round. Supplying local evidence
  never stopped it recurring, because it never changed the reviewer's own
  environment. `bootstrap-shellcheck.sh --resolve` now reports a usable pinned
  binary offline: `PATH` when it matches, otherwise the already-populated
  cache. When neither can supply it, lint still fails closed and names both
  probes plus the command that populates the cache. Resolution never downloads,
  and the version check itself is unchanged — `--check` keeps its existing
  meaning for release verification.

  Because that makes the cache an execution source these tools choose rather
  than one the operator picked, a cached binary is now authenticated by content:
  `tools/lint/shellcheck-assets.tsv` records a `binary_sha256` per platform,
  derived from the release archive whose checksum the same row already pinned,
  and resolution rejects a mismatch before the binary is ever run. A version
  string a binary prints about itself cannot establish what it is. The same
  digest is checked when installing, when reusing an existing cache entry, and
  on the freshly extracted binary — in every case *before* the version probe,
  since running the candidate is exactly what the digest exists to gate.

- **Test guards no longer fail on other processes' writes to live shared state
  (CC-550).** Three suites proved "this run did not touch live state" by
  fingerprinting a shared file before and after. That oracle cannot distinguish
  this suite's writes from any other process's, and both targets are written by
  ordinary use: the auto-context hook queries the repo context DB on every
  prompt. One 41-minute gate preflight died this way — the guard reported that
  "a case operated on `$REPO_ROOT`", a conclusion its evidence could not
  support, and the round aborted before any reviewer was dispatched. Each guard
  now asserts the deterministic property upstream of any write: that the call
  under test *resolves* to its fixture, never the live target. The context suite
  additionally routes every call through a wrapper that refuses, at the call site
  and with the reason, any invocation not placed inside the fixture tree — an
  explicit live root, or a bare call from a directory the CLI would resolve back
  to the repository. It checks a sufficient precondition for isolation rather
  than reimplementing the CLI's resolution rules, so the suite-wide coverage the
  fingerprint provided is kept without its attribution problem. Failure messages
  state only what the evidence supports.

- **Gate reviewer-protocol failures are correctable on their retry (CC-549).**
  An invalid `test_gaps` row was reported as a bare
  `invalid test-gap matrix contract` covering ~10 constraints, so the reviewer
  could not tell what it broke and its single corrective retry tended to
  reproduce the same class of error — discarding a full gate round. Every
  observed instance was the same root cause: a value taken from a sibling enum
  (`missing_layer` values placed in `coverage_dimensions`). The diagnostic now
  names the row, the field, the offending value, the permitted set, and that
  confusion explicitly, reusing the precise-diagnostic pattern already used for
  finding contracts.

  Fixing that surfaced a second, pre-existing defect: `pr-gate.sh` classified
  retryability by whole-string equality, while the verifier already appended
  `": <detail>"` to the finding-contract reasons — so the most actionable
  diagnostics were exactly the ones never retried. Retryability now matches the
  reason stem.

- **Memory human output neutralizes terminal control sequences.**
  `pmctl memory stats` and `pmctl memory doctor` printed index-derived card
  paths and the resolved memory directory verbatim, so anyone able to add a
  MEMORY.md entry (or name a directory) could embed ESC/OSC sequences that the
  reader's terminal executes on display. Control characters are now rendered as
  inert `\xNN` text in human mode; JSON mode keeps the exact value in its
  escaped form.

- **Memory reports escape every JSON control character.** `pmctl memory doctor`
  and `pmctl memory stats` build their JSON by hand and escaped only `\n` and
  `\r`. A tab in a memory directory or card path — legal on POSIX filesystems —
  produced a document no parser accepts. All characters with a short escape now
  get one, and the rest of the C0 range is emitted as `\u00XX`.

- **An unreadable usage sidecar is no longer reported as zero activity.**
  `memory_usage_read` suppresses store errors, so a corrupt, locked, or
  permission-denied sidecar previously rendered as a successful all-never-hit
  report. `pmctl memory stats` now reports `usage_store: error` and says so in
  human output; an absent sidecar remains a valid zero-activity report.

- **`pmctl memory rebuild-summary` skips whitespace-only summaries.** It tested
  emptiness before trimming, so a summary of only spaces produced an empty
  bullet in `episodes.summary.md` while `pmctl memory stats` counted the same
  entry as unfilled. Both now apply one rule.

- **CJK-aware shared retrieval term extraction (CC-465).** Memory-injection
  ranking and context prompt/reuse scans each carried their own ASCII-only
  tokenizer, so CJK characters were treated as separators and dropped. For a
  maintainer working in Chinese this meant the keyword tier scored 0 on every
  prompt, ranking degraded to pure frecency, and — because the usage sidecar
  only accrues on keyword hits — the frecency signal never accumulated either.
  A single `runtime/lib/retrieval-terms.sh` (ASCII identifiers plus overlapping
  CJK 2-grams) now backs both call sites. English behavior is preserved by
  parameterizing rather than unifying policy: the injection hook keeps
  min-length 4 with no stop-list, context/reuse-scan keeps min-3
  stop-filtered. Input past `RETRIEVAL_TERM_MAX_BYTES` still extracts from the
  prefix, but says so on stderr so truncation cannot masquerade as an empty
  index. FTS5 `unicode61` behavior for Chinese queries is a separate concern
  and is not addressed here.

- **Standalone Gate bundles load canonical libraries (CC-532).** `pr-gate.sh`
  derived each library path independently, and the loads keyed only on the
  installed-copy root resolved to `<bundle>/../lib` under the standalone-copy
  layout — a path outside the bundle. Those loads silently fell through to
  generated in-script duplicates of `gate-result-verify.sh` and
  `artifact-paths.sh` instead of the shared implementations. Every library now
  resolves through one layout-aware root, so all three topologies run the same
  canonical code, and a bundle missing a library fails closed at the load site
  naming the layout and path rather than degrading into a stale copy.

  The two in-script duplicates and their generator
  (`tools/generate-gate-result-verifier-fallback.sh`) are removed; a Gate bundle
  is a directory contract (`pr-gate.sh` plus `lib/`, `core/policy/`, `agents/`
  and `adapters/`), and a single copied `pr-gate.sh` was never runnable on its
  own — it already failed closed on the executor router. The bounded copy-mode
  policy snapshot is unaffected and remains load-bearing for installed copies.

- **Reproducible ShellCheck toolchain.** CI and maintainer lint now resolve one
  repository-pinned ShellCheck version instead of inheriting different analyzer
  rules from `ubuntu-latest` or a host package manager. The shared bootstrap
  verifies official release assets by SHA-256, lint and release verification
  reject version drift before scanning, and affected-test ratchets cover the
  pin, asset manifest, bootstrap, workflow, and exact-version diagnostics.

- **Concurrent memory, lock, state, and Gate lifecycle hardening.** Memory usage
  telemetry now uses a WAL-enabled SQLite primary store with atomic updates and
  a TSV migration/fallback path. Cold-start WAL contention now runs the SQLite
  CLI in fail-fast mode and retries only BUSY/LOCKED whole transactions with a
  bounded jittered backoff, preventing both dropped telemetry and a partial
  autocommit/double-count retry. Portable mkdir locks use verifiable owner
  nonces and fenced unlock/reclaim behavior. Test suites receive isolated
  `TMPDIR`/`XDG_RUNTIME_DIR` state, terminal sentinels win the detached-readiness
  race, and state-writer failures remain fail-loud. (PR #469)

- **Codex reviewer `QA_RULES_DIR` resolution (CC-541).** Gate dispatch resolves
  the rules directory host-side and exports it before launching reviewers.
  Structured diagnostics distinguish a genuinely absent rules source from a
  reviewer that reports it missing despite host confirmation; nested fixtures
  scrub inherited rule-path state. (PR #465)

- **Preflight `--test-timeout` default too low for a full-suite escalation
  (CC-522).** `pr-gate.sh`'s default `--test-timeout` was 1800s. A change to a
  high-fanout runner/install substrate (e.g. `tests/lib/test-harness.sh`)
  forces `tests/bin/run-tests.sh` to escalate from an affected-only run to the
  full suite, which measured 37m22s wall-clock on this repo — every such
  preflight run was killed at the 1800s ceiling and reported as non-authorizing
  `Final: INCOMPLETE` rather than completing. Default raised to 3600s.

### Changed

- **Targeted Gate coordinate separation foundation (CC-527 partial, PR #472).**
  Added the canonical `--pass targeted --reviewers ... --initial-result ...`
  form, retained the legacy shorthand through the same resolver, rejected
  conflicting mixed spellings, and recorded spelling provenance. Initial-tier
  inheritance, explicit tier/coverage selection bases, stale/legacy initial
  handling, truthful full-tier/QA-only labeling, and complete execution-mode
  parity remain open; CC-527 is not closed by this PR.

- **Source-safe runtime and identifier-policy closure (CC-530, PR #473
  foundation).** Every `runtime/lib/*.sh` now has a mechanically checked
  no-side-effect source contract under caller-owned strict modes: no shell
  policy/cwd/trap/job mutation, direct exit, process spawn, external exec, or
  filesystem write. Identifier validation centrally owns strict domain
  grammars plus safe artifact-leaf compatibility, and the Gate verifier's
  standalone fallback derives its run-id ERE from that canonical policy.

- **Manifest-authoritative Adapter dispatch entrypoint (CC-531).** The
  implementation establishes
  `dispatch_entrypoint` as the sole runtime path authority and centralizes safe
  manifest resolution. During the bounded schema v1 migration window, a
  manifest without that field falls back with a deprecation warning to the
  historical runtime convention `./dispatch.sh`; legacy `runner_ref` metadata
  is never interpreted as a path, and cannot override a present canonical
  value. New built-ins and generated manifests omit `runner_ref`; installed
  copy-mode carries a receipt-owned Gate runtime/policy snapshot plus bounded
  Adapter runtime, alias, and usage assets, and fails before wiring entrypoints
  when a load-bearing path conflicts or required bundle content is incomplete.
  A closure refactor makes preflight and apply consume one bundle inventory,
  publishes dependencies and managed trees before entrypoints, routes every
  Gate deployment through the canonical explicit-root executor router, and
  gives install refresh, uninstall, and doctor one schema-validating receipt
  reader. Changed-path selection ratchets every direct manifest consumer,
  including runner-kind, end-to-end, hook-profile, Gate shard, guard, and
  uninstall coverage.
  Deterministic repo/copy, foreground/detached, Gate/router, path-security,
  receipt-lifecycle, and matching current-tree full-suite evidence close CC-531.

- **Copy-mode verifier fallback provenance ratchet (CC-525).** The generated
  inline verifier now points to the executable canonical generator at
  `tools/generate-gate-result-verifier-fallback.sh`. Generator checks fail loud
  on generator identity or executable drift, malformed markers, provenance
  drift, and generated-body parity changes; the verifier behavior and bundle
  layout remain unchanged.

### Added

- **`pmctl memory stats` — injection-benefit report (CC-467).** A read-only
  aggregator over data that already exists (MEMORY.md, the usage sidecar,
  `episodes.jsonl`); it opens no new telemetry write surface. Reports index
  size against the per-prompt injection budget, per-card hit counts and
  never-hit cards, last-hit recency using the same day boundaries as frecency
  ranking, and the episode summary fill rate. The concentration block
  (`hit_coverage_pct`, `top5_share_pct`) exists because raw hit counts look
  healthiest in the worst state: when nearly every card is hit on nearly every
  prompt, ranking has no discrimination left and injection degrades into
  "emit whatever fits". Usage numbers are keyed per card file, so two index
  lines linking one card no longer double-count. The injection budget caps now
  live in `runtime/lib/memory.sh` and are read by both the hook and the
  reporter, so the reported budget cannot drift from the enforced one.
  `card_hits` answers "which card is repeatedly selected" with per-card
  `{card, access_count, last_access_day}` rows, most-hit first, bounded by
  `--hit-limit` (counts and totals are never capped, so bounding the list
  cannot falsify them). Corrupt input is never presentable as absence:
  `usage_store: error` marks an unreadable sidecar and `episodes_malformed` /
  `episodes_status` mark unparseable episode rows, because this report is cited
  in retention decisions, and `unmeasurable_cards` separates cards whose path
  the tab-delimited sidecar cannot represent from cards genuinely never hit.
  Both human and JSON output escape control characters in memory-derived paths
  — including C1 bytes such as a raw `0x9B` CSI, which `[[:cntrl:]]` does not
  match — by decoding UTF-8, so CJK card names survive intact. `--json` carries `schema_version: 1`; exit `0` report, `1` invalid
  canonical selection, `2` usage error — an unhealthy number is never an error
  exit.

- **Actionable Gate test-gap evidence and bounded protocol recovery (CC-521).**
  Current selected-reviewer results publish `pr_gate_result_v5`: every reviewer
  emits evidence-backed test-gap rows, synthesis preserves their exact union,
  separates operational/user cautions, and produces focused/manual/full
  verification plans. Parallel Gate retries only failed reviewer roles or
  synthesis once for transport, malformed-output, schema, or parity failures;
  attempts are recorded against the immutable subject, while stale bindings
  and analysis uncertainty are never retried. Deterministic fixtures cover
  malformed/truncated/wrong-subject/dropped-row and recovery exhaustion. An
  opt-in seeded live evaluator reports recall and variance with
  `correctness_gate:false`. Historical v1-v4 artifacts remain readable.

- **Full-runner Phase 0 structural fail-fast (CC-543).** Cheap registry, lint,
  and schema suites run before behavioral suites; the first Phase 0 failure
  prevents any remaining expensive suite from starting while preserving
  structured skip rows. `--collect-all` retains the release-diagnostic path,
  and `--verify-full` rejects incompatible flag combinations. (PR #465)

- **Bounded reviewer citation correction (CC-545).** Parallel Gate retries only
  reviewers whose sole protocol error is an invalid evidence reference, once,
  with the rejected citations in a corrective brief. Other protocol failures
  remain immediately `INCOMPLETE`, and retry output stays under the existing
  watchdog, hash, and tamper checks. (PR #465)

- **Truthful `--test-cmd` preflight outcomes (CC-522 Phase A).** Preflight
  evidence now records execution, test verdict, evidence richness, and
  authorization independently. Opaque nonzero exits, timeouts, environment
  failures, stale subjects, and malformed structured evidence terminate as
  non-authorizing `Final: INCOMPLETE` (exit 3), rather than claiming a
  diff-caused test failure. Only a subject-valid structured assertion failure
  yields the mechanical `Final: NO-GO`; legacy exit-0 commands remain valid
  opaque evidence.

- **Nested gate test timeout diagnostics (CC-522 test-harness follow-up).** `test-pr-gate`
  now labels each nested gate invocation with its owning case and duration,
  bounds it with a configurable case watchdog, and verifies cleanup of a
  stalled fixture. The affected-test scheduler runs this process-heavy suite
  alone, preventing concurrent integration suites from turning resource
  contention into an opaque 15-minute suite timeout.

- **Deterministic synthesis parity and remediation seed (CC-520).** Completed
  selected-reviewer routes now emit `pr_gate_result_v4` with exactly one
  `gate_synthesis_result_v1` block. The verifier mechanically reconciles the
  selected/not-reviewed dimensions, reviewer-by-surface coverage matrix,
  complete stable-ID inventory and findings union, uncertainty/caution sets,
  root-cause membership, and a pending `remediation_closure_v1` seed against
  the authoritative reviewer JSON. Silent drops, duplicate IDs, coverage
  drift, missing verification expectations, malformed uncertainty objects, or
  malformed seeds stop as synthesis protocol `INCOMPLETE`. Sequential and
  parallel modes share the same contract and fixed human sections for must-fix
  order, advisories/cautions, coverage gaps, and recommended verification;
  executor-authored frontmatter is normalized to an unbound v1 staging result,
  so a model that anticipates v4 cannot race the shell-owned assurance sidecar
  publication. Multiple model-authored assurance pointers fail closed, while
  the shell alone binds the final bounded pointer and result version.
  Legacy v1-v3 results remain readable under their historical contracts.

- **Fail-closed gate artifact handoff hardening.** Model staging accepts an exact
  `+---` patch-marker variant only long enough to canonicalize it back to a real
  YAML fence; malformed or ambiguous staging still fails closed. Protocol
  failures now emit `failure-result: <path>` so detached supervisors preserve
  and surface the inspectable artifact without treating it as a verdict.

- **Reviewer command guard false-positive hardening.** Quoted operands of
  `rg`/`grep`/`egrep`/`fgrep` are treated as search data during denylist
  matching, so reviewing source text containing destructive spellings no
  longer blocks a reviewer; executable `sed`/`awk` programs remain subject to
  denylist inspection. Command substitutions remain conservative and denied.
  Actual destructive command forms remain denied. Supervisor EXIT handling also
  publishes a failed terminal claim when normal dispatch exits before result
  handoff, while parent reconciliation defers until the producer stops.

- **Selected-reviewer coverage and finding contract (CC-519).** Every selected
  reviewer now emits a scope-bound `gate_reviewer_result_v1` JSON report with
  an explicit eleven-surface checklist, evidence/reasons, stable finding IDs,
  hard-gate/origin classification, affected behavior, failure mode, minimum
  fix boundary, and verification expectation. The JSON verdict replaces
  Markdown headings as the machine source of truth, so duplicate headings no
  longer abort a completed review. Legacy role values such as `pass` are mapped
  to the common enum in reviewer instructions, role-specific prose is confined
  to rationale/findings, and diagnostics distinguish top-level, coverage,
  finding, evidence-reference, and verdict failures. Current scope manifests
  include a subject/base snapshot reference index with line counts and content
  digests; nonexistent, out-of-scope, or out-of-range reviewer references fail
  before synthesis. Missing/malformed sections, incomplete checklists, invalid
  IDs, evidence-less blockers, and aggregate verdict drift fail closed as
  protocol `INCOMPLETE`. Completed reports are preserved in
  `pr_gate_result_v3`; v1/v2 and pre-index v3 results remain readable under
  their legacy contracts.

- **Immutable gate scope manifest (CC-518).** `pmctl gate run` now creates a
  content-addressed `gate_scope_manifest_v1` before reviewer dispatch, bound to
  the immutable gate subject and linked from `gate_assurance_v3`. It declares
  changed/renamed/untracked paths, hunk ranges, paired tests, sensitive
  signals, surface flags, and bounded peer/call-site/shared-helper hints.
  Sequential and parallel reviewers receive the same manifest digest.
  Budget omissions stop as `INCOMPLETE` unless explicitly accepted with
  `--accept-scope-truncation`; accepted truncation remains recorded with exact
  omitted counts and reasons. Symbol expansion is language-aware, and shell
  call-site hints are limited to direct source-path consumers, preventing
  embedded foreign-language snippets and unrelated local functions with common
  names from exhausting the search-match budget. Consumer scans read through
  the full immutable snapshot so `pipefail` cannot turn an early grep match
  into a nondeterministic omission. A compatible-language query that truly
  exceeds the limit still fails closed. Named v3 consumers now require verified
  linked scope evidence; historical v3 envelopes with unavailable scope remain
  readable only through non-authorizing artifact inspection.

- **Immutable gate subject and shared three-axis verification (CC-515).**
  Current gate producers emit `gate_assurance_v3` with a stable Git
  common-directory repository key, provenance-only observed root, base/head
  refs and commits, tree fingerprint, subject kind/dirty policy, timestamps,
  and digest-bound evidence links. `pmctl gate verify` now reports
  `artifact_valid`, `subject_current`, and `policy_applicable` independently
  with reason codes and optional JSON output. Named consumers require all
  three axes; default inspection remains compatible with historical
  artifact-validity checks. Gate wait and ship finish use the same verifier,
  so stale or policy-insufficient GO text cannot authorize continuation.

- **Parent-operation control plane for indirect dispatch (CC-508).** Producers
  that launch detached children — `pmctl gate run` and `pmctl ship` — now create
  a durable parent operation record (`core/schema/operation.schema.json`, owned
  by the canonical state writer) and attach every child run to it *before*
  launch, so ownership is provable rather than inferred. New ownership-scoped
  routes `pmctl <gate|ship> cancel <operation-id> --cd <dir> [--grace N]` and
  `pmctl <gate|ship> reconcile <operation-id> --cd <dir>` cancel or converge
  only the children recorded under that operation, each through the trusted
  `pmctl dispatch cancel` primitive — never by accepting a caller-supplied PID.
  Reconcile never infers completion from workspace artifacts: an unresolved
  child leaves the parent `indeterminate`. `doctor` gains a read-only
  `parent-operations` check that reports non-terminal records with the exact
  reconcile command to run. Task dispatch is deliberately not wired yet.

- **Grok executor + host (MVP).** New `adapters/grok/` Model B executor
  (`pmctl dispatch run --adapter grok`) with dual isolation mapping
  (`--sandbox` + `--permission-mode` via `isolation-map.yaml`), streaming-json
  terminal event `end`, `share/grok-model-aliases.tsv`, and fake-CLI suite
  `tests/shell/test-grok-dispatch.sh`. New `hosts/grok/` batch-only host
  (manifest + doctor + path-resolver; `install_module: null`) with
  `pmctl pm/memory --host grok` allowlist support. Executor enum and schema
  mirrors include `grok`; host format enum adds `grok-config-toml`.
  Contract versions bump with the closed-enum expansion: Run
  `schema_version` **2→3**, handover `handover_version` **3→4** (CC-376
  precedent).

- **All-production-domain state-writer ratchet (CC-500).** The layer-boundary
  suite now scans every production shell domain for direct state-root and
  load-bearing entity mutations, including redirects, `jq >`, `mv`, `cp`, and
  multiline command forms. The designated writer and pure path resolver are
  the only module exemptions; only `rebuildable: true` SQLite caches declared
  by `core/state/layout.yaml` may write outside that boundary. Self-injecting
  fixtures prove each violation shape fails while readers and derived caches
  remain legal.

- **`pmctl state status [--json]` (CC-498).** Read-only state-store
  compatibility report: resolved store root, observed store layout version vs
  supported versions, project key, entity schema versions (read live from
  `core/schema/*.schema.json`), root safety/writability, and migration
  availability. Never creates or repairs the store — a future-version or
  uninitialized store is observed with zero mutation. Exit 3 signals an
  incompatible store for machine consumers (doctor/support report).

### Changed

- **Gate reviewer dispatch goes through shared runtime, not the CLI (CC-508).**
  `runtime/bin/pr-gate.sh` previously launched reviewer children by re-entering
  `cli/pmctl`, contradicting the dependency direction in
  `docs/architecture/script-domain-ownership.md` (cli → runtime → adapter). It
  now loads `pmctl_dispatch_run`/`pmctl_dispatch_wait` from `runtime/lib`,
  sourced inside a per-dispatch subshell so the gate's long-lived shell — which
  evaluates reviewer commands and runs the parallel watchdog — does not inherit
  pmctl's global namespace. The library route requires the repo layout: shared
  libraries derive their root as `<lib>/../..`, so a copy-mode bundle carrying
  `lib/` beside the gate degrades to direct adapter dispatch without
  parent-operation tracking, as it already announced. Coverage note: the
  end-to-end `/tmp/brief-gate-*` guarded-snapshot assertion now applies only to
  the repo-layout route; the copy-mode fixtures assert that the executor
  receives an existing brief, since no guard constrains that path.

- **Usage-tracker default moved to the host-neutral namespace (CC-508).**
  `ops/usage/log-usage.sh` and `ops/usage/token-usage.sh` now default to
  `~/.pm-dispatch/usage-tracker.jsonl` instead of `~/.claude/usage-tracker.jsonl`,
  so a Codex-only or Grok-only dispatch no longer creates a Claude-specific home
  directory. Upgraded installations keep their existing history at the old path:
  set `PM_DISPATCH_USAGE_LOG_FILE=~/.claude/usage-tracker.jsonl` to retain one
  tracker in place, or move the file. `doctor` warns whenever history sits at the
  former default (or is split across both) and prints the remediation.

- **Task and decision rollback deletes use the canonical writer (CC-500).**
  Failed event emission no longer removes projections directly from pmctl
  modules; `task_delete` and `decision_delete` now enforce ID validation,
  store safety/version gates, project partition resolution, and loud failure
  through `runtime/lib/state-writer.sh`.

- **Store layout version naming split (CC-498).** The store-wide layout
  version (`$STORE/VERSION`, `layout.yaml` `store_layout_version`) is now
  named and documented as distinct from per-entity `schema_version` fields.
  Supported versions and the migration registry live in one shared source
  (`runtime/lib/state-compat.sh`) consumed by both the writer's version gate
  and `state status`.

### Fixed

- **Operation state writes now participate in writer-boundary parity
  (CC-508).** `layout.yaml` declares the three operation writer entry points
  and the append-locked `children.jsonl` relation, while dropping the stale,
  unimplemented `review_upsert` declaration. The production-domain ratchet now
  recognizes operation projections and child relations as load-bearing state,
  and the affected-test planner selects layout parity whenever either the
  layout contract or state writer changes.

- **A detached gate launcher failure terminalizes its childless parent
  (CC-508).** `pmctl gate run` creates the parent operation before either
  lifecycle path starts, but the detached branch returned the launcher's status
  directly. A failure before the supervisor exists — missing
  `gate-supervisor.sh`, unresolvable run dir, readiness timeout — therefore left
  a `running` operation that owned no child, visible only as a doctor warning.
  The detached path now applies the same childless-failure compensation the
  foreground path already did.

- **A failed detached launch no longer leaves an unresolvable reserved child
  (CC-508).** A child is attached to its parent operation before the launch
  boundary so it can never become an un-cancellable orphan. Supervisor launch
  failure already wrote a `failed` terminal claim, but earlier failures inside
  `pmctl_dispatch_run_detached` (run-spec write, state transitions, brief
  snapshot) did not — leaving a recorded child with no terminal evidence, so
  reconcile downgraded a provable launch failure to `indeterminate`. The
  dispatch layer now writes the terminal claim for any launch failure after
  reservation (an exclusive-create CAS, so it is a no-op when the inner path
  already claimed the run), and `pmctl ship` falls back from the childless
  compensation — which cannot apply once a child exists — to `reconcile`.

- **Operation cancel/reconcile diagnose the failure instead of exiting silently
  (CC-508).** An unknown operation id — the common case when one is copied from
  a PR body or created on another host, since operation records are
  machine-local — used to exit 2 with no output. Both routes now distinguish
  "no such operation" from "exists but foreign", name the resolved working
  directory, and print usage on a malformed invocation.

- **Relative `--cd` no longer reports an owned operation as foreign (CC-508).**
  `cancel`/`reconcile` compared the caller's raw `--cd` value against the
  absolute `working_dir` stored at creation, so `--cd .` located the record and
  then refused it as a foreign target. Both routes now resolve `--cd` to an
  absolute physical path, matching the contract `pmctl_operation_create`
  already enforces.

- **Path normalisation of "." aborted under `set -u`.**
  `_portable_normalize_path` declared its accumulator array without an
  initialiser; on bash before 5.2 a declared-but-unassigned array is unbound, so
  any input normalising to no path segments (`.`, `./.`) failed with
  `out: unbound variable` instead of returning `.`.

- **Unreadable state-store versions fail closed cleanly (CC-507).** `pmctl
  state status` now catches a failed `VERSION` read and emits its structured
  `unreadable` report with exit 3 instead of being terminated by Bash's
  optimized `$(<file)` redirection with exit 1 and a raw permission error.

- **State writer no longer recommends a nonexistent command (CC-498).** The
  unsupported-store-version error used to instruct running `pmctl state
  migrate`, which does not exist. Remediation text is now derived from the
  migration registry: a command is only named when a runnable migration path
  actually exists; otherwise the error points at `pmctl state status`.

## [0.10.0] — 2026-07-20

### Added

- **`pmctl dispatch reconcile` (CC-499).** Diagnoses and converges stale
  detached runs (crash, reboot, orphan, PID reuse) using only trusted
  out-of-repo evidence — never infers success from advisory records, and
  never overwrites an existing terminal claim; convergence only ever
  CAS-claims `failed`, and only when process absence is provable. Reports
  in-flight / terminal-authenticated / orphaned / process-gone-without-evidence
  / indeterminate (PID-reuse suspected). Identity capture now records a
  `boot_id` so a reboot short-circuits straight to "gone" instead of risking
  a post-reboot `starttime` coincidence. `pmctl dispatch reconcile <run_id>|--all
  --cd <dir> [--dry-run]`; `doctor.sh` gained a read-only stale-run scan.

- **`pmctl dispatch cancel` / `dispatch status` (CC-495).** Detached runs can be
  terminalized with trusted process-group kill (PID/PGID/starttime/comm
  re-verify before signal), exclusive terminal CAS shared with natural
  complete, durable cancelled Run/Event/dispatch record, and a
  nonce-authenticated `cancelled` sentinel. `pmctl dispatch wait` returns
  **exit 130** for authenticated cancel (distinct from failed, timeout 124,
  and indeterminate 3). Minimal in-flight discovery via `dispatch status`.
  Run schema/policy and event schema gain `cancelled` / `run.cancelled`.

### Fixed

- **Worktree/auto-pack path-contract hardening (CC-453, PR#430).**
  `pmctl_worktree_create` now redirects `git worktree add` progress chatter to
  stderr so its stdout contract is exactly one line (the worktree path).
  `pmctl_dispatch_auto_pack` validates a non-git work_dir as an absolute,
  existing directory and fail-loud skips packing otherwise — a garbage
  work_dir can no longer create directories under the current CWD via a
  relative `mkdir -p`. The opencode adapter's isolation error message now only
  recommends its actually supported level (`none`).

### Changed

- **Guard/hook symmetry hardening (CC-452, PR#431).** `guard-pm-write.sh` and
  `guard-reviewer-write.sh` now declare `set -euo pipefail` like
  `guard-executor-write.sh`; a regression test enumerates every
  `runtime/hooks/guard-*.sh` dynamically and pins `guard-pm-bash.sh`'s
  documented `set -uo pipefail` exemption. The duplicated episode-date
  ISO8601 normalization in `guard-inject-memory.sh` and
  `guard-session-summary.sh` is extracted to `memory_iso8601_normalize()` in
  `runtime/lib/memory.sh`. The episodes.jsonl append lock (audit item 1) was
  already fixed earlier and is verified not regressed.

---

## [0.9.0] — 2026-07-18

### Added

- **Structured shell-test docstring contract (CC-004, PR#369).** All 124
  `test-pr-gate` cases now use the shared `Behavior`/`Steps` convention, and a
  dedicated allowlist-based linter plus CI regression suite prevents converted
  test files from silently drifting back to unstructured comments.

- **Manifest-driven script and host-module ownership (CC-489 Phases 0–6;
  PR#405/#410–#415/#417).** Host write modules and config-root resolvers are
  declared by each host manifest; OpenCode, Codex, and Claude install,
  uninstall, doctor, hook, and path-resolution implementations live under
  their owning host domains. The final migration moves shared runtime, test,
  tooling, and operations implementations into canonical owner directories,
  leaving only audited compatibility shims under `scripts/`.

### Changed

- **Multi-host PM and host abstraction closure (CC-436/437/438/445/448/457/471/473/480; PR#372/#374/#375/#381/#384/#391/#394/#395).** Claude, Codex, and OpenCode now share the host-manifest capability contract and host-aware install/doctor/guard wiring. Codex gains the batch-only `pmctl pm prepare/run` coordinator, and canonical memory survives host switches without relying on another host's private tree.

- **Canonical context and memory correctness (CC-455/459/483/484/488/490/492; PR#371/#379/#397/#399/#401/#403/#406).** Context follows the target repository, prompt retrieval is deterministic, all three hosts resolve and write the same project-scoped canonical memory, Codex lifecycle hooks preserve provenance, and invalid explicit selections fail closed.

- **Gate, runner, and operational safety (CC-458/469/470/474/477/481/482/485/487/491/496; PR#378/#383/#387/#388/#396/#397/#398/#402/#407/#408).** Gate run/wait UX, absolute reviewer tooling, bounded timeouts, independent reasoning effort, concurrency-safe usage accounting, reusable pre-flight evidence, reviewer least privilege, and Codex's audited one-turn guard bypass are covered by structured fail-closed tests.

- **Model and adapter compatibility maintenance (CC-475/476/478/479; PR#389/#390/#392/#393).** Claude and Codex aliases track their current model families; legacy Claude aliases remain supported, and OpenCode's deny-mode hang has a bounded timeout/permission workaround.

- **Core/runtime ownership and CLI discovery (CC-451/454/456/460/489/497; PR#409/#405/#410–#421).** Runtime enums and state schema validation now have canonical sources; 151 implementation/fixture paths moved to their owner domains with compatibility-shim and stale-reference ratchets; ShellCheck and maintainer-path coverage match CI; and `pmctl` now provides root/area/leaf help, a machine-readable command catalog, suggestions, and README parity checks.

- **v0.8.0 → v0.9 candidate upgrade acceptance (CC-501, PR#424).** Added a
  fully isolated, artifact-producing three-host upgrade smoke and fixed the
  ownership-safe refresh paths it exposed: manifest-owned Claude assets and
  `pmctl` transfer to a new checkout, stale dispatch allowlist entries are
  retired, Codex refreshes only commands rooted in a verified pm-dispatch
  checkout, and OpenCode transfers a checksum-verified receipt while retaining
  its original byte-exact uninstall backup. The smoke requires doctor 0 FAIL,
  no retired `scripts/` targets, an idempotent dry-run, and byte preservation of
  foreign config, canonical memory, and user data.

- **Public-history exposure audit (CC-033 audit slice, PR#423).** Scanned all 493 commits reachable from heads, remotes, and tags for private keys, provider-token shapes, credential URLs/assignments, sensitive filenames, runtime artifacts, oversized blobs, maintainer-local paths, and author-email exposure. No actionable credential or committed runtime artifact was found; the durable audit records synthetic-token false positives, the decision not to rewrite published history for non-secret paths/email metadata, and GitHub secret scanning being disabled as a v0.14.0 settings follow-up.

- **Host-neutral shared PR gate (CC-502, PR#422).** `pr-gate` now resolves reviewer definitions from product-owned assets instead of `$HOME/.claude/agents`, pins workspace-owned policies to the trusted base revision, and supplies reviewers with canonical-memory provenance/context through shared runtime libraries. Invalid canonical selections and unexpected resolution/query failures fail closed. A real `pmctl gate run --executor codex` regression proves the production path works in an isolated non-Claude HOME without creating `.claude` state, while Claude executor parity remains covered.

- **Fail-closed structured test evidence (PR#400/#408/#422).** The shared test runner now limits its default parallel fan-out to four jobs to preserve file-descriptor and subprocess headroom for heavyweight suites, while explicit `--jobs`/`PM_DISPATCH_TEST_MAX_JOBS` overrides remain available. Structured-result consumers reject missing, empty, or malformed sinks instead of treating incomplete evidence as success.

- **Canonical migration references and release metadata (PR#417/#425).** Current README, core, platform, milestone, backlog, and release-checklist surfaces now point to the owner-domain paths established by the script-domain migration. The inventory linter rejects retired implementation references while preserving historical records, compatibility coverage, and installed `~/.claude/scripts/` helper names; release verification now derives coverage from the canonical suite registry instead of a copied suite count.

### Docs

- **v0.9 planning, probe, and closure records
  (PR#370/#373/#377/#380/#382/#385/#386/#404/#416/#419).** Milestone scope,
  host probes, cross-project analysis, model/effort decisions, follow-up tickets,
  terminal-ticket archival, and pre-v1 stabilization/upgrade plans now preserve
  the rationale and evidence behind the implemented v0.9 changes without
  presenting deferred work as shipped behavior.

### Fixed

- **Milestone docs-freshness status parsing (PR#376).** The U2
  planned-versus-released check now reads only the milestone heading, so status
  words in explanatory body text cannot produce a false stale-status finding.

- **Repeated full-suite escalation in the affected-test planner (CC-489,
  PR#411).** Repeated high-fanout paths now keep `mark_full` successful, so a
  diff containing both `install.sh` and `uninstall.sh` cannot exit silently
  under `set -e` before producing structured test evidence.

- **Release-gate synthetic tree remains clean (PR#425).** The live E2E fixture
  commits `.pm-dispatch/` to its synthetic repository's ignore policy before
  context refresh, preventing derived context state from tripping the gate's
  clean-tree guard. Structural regression coverage locks the setup order.

- **Real-HOME uninstall convergence (PR#425).** The dedicated pmctl teardown
  removes `~/.local/bin/pmctl` before the manifest loop sees the same entry. That
  already-gone, out-of-`~/.claude` destination is now treated as an idempotent
  success instead of a safety conflict, so uninstall removes its manifest and
  a second run converges with zero safety skips. Missing paths never trigger a
  deletion; broken symlinks and existing out-of-root targets still pass through
  the fail-closed ownership and containment checks.

## [0.8.0] — 2026-07-04

### Added

- **Memory substrate cross-tool location seam (CC-412, PR#352).** `find_memory_dir` now honors an explicit override with precedence `PM_MEMORY_DIR` env > `dispatch.memory_dir` config > `CLAUDE_CONFIG_DIR` convention — behavior is byte-identical to before when neither override is set. The injection layering is now documented in `docs/memory-system.md`: the portable core is the `pmctl context --source memory` retrieval API; injection is a per-tool adapter concern (Claude keeps its existing hook; codex/opencode/future hosts call the retrieval API directly).

- **Gate detached lifecycle (CC-423, PR#353).** `pmctl gate run --lifecycle detached` (now the default) returns a `gate_id` immediately and runs `pr-gate.sh` under a `setsid`/`nohup` gate-supervisor, mirroring the existing dispatch detached mode. `pmctl gate wait <gate_id>` reattaches via a nonce-authenticated sentinel and fails closed on result-integrity violations. A session interrupt can no longer kill a running gate or corrupt its exit-code reporting.

- **Repo-wide git worktree tooling (CC-014, PR#358).** `pmctl worktree create/list/remove/gc` manages per-ticket worktree lanes with a tracked manifest, plus the `using-git-worktrees` skill documenting the parallel-development workflow. Executor-agnostic by design — worktree lifecycle is pmctl's responsibility, not any executor's.

- **`/ship <ticket-id>` command (CC-439, PR#360).** Takes one explicit backlog ticket from implementation through pr-gate to an open PR without step-by-step confirmation stops: pre-flight consistency checks, gate `Final:` verdict reading, NO-GO fix-loop until stuck, GO → push + PR, never auto-merges.

- **`pmctl ship prepare/finish` + `--parallel` N-lane orchestrator v1 (CC-441, PR#363).** `ship prepare`/`ship finish` are the scriptable bookends of the CC-439 ship contract (ticket validation + branch creation; single gate round + GO-gated push/PR with branch-identity, dirty-tree, HEAD-moved, and gh-preflight guards). `ship --parallel` runs N ticket lanes concurrently on CC-014 worktrees, each dispatched detached with its own run_id-partitioned artifacts; lane failures are isolated and reported per lane; GO lanes queue for human merge — never auto-merged. Hardened during real e2e acceptance: marker-based GO detection (never trusts free text), concurrent double-dispatch race guard, tracking-file locking, and a `partial` status for push-succeeded-but-PR-failed.

- **Shared detached-launch lib (CC-434, PR#356).** Extracted the setsid/nohup launch + nonce-authenticated sentinel logic duplicated byte-for-byte between `dispatch-supervisor.sh` and `gate-supervisor.sh` into `scripts/lib/detached-launch.sh` (7 shared functions; `resolve_repo_root` stays inline for bootstrap reasons, guarded by a verbatim-diff fixture test). Pure delegation — no external behavior change; dispatch-side security preflights untouched.

- **`pmctl ship <ticket-id>` unified start entry (CC-442/CC-443).** `pmctl ship <id> [--worktree] [--adapter <name>]` replaces the split between `ship prepare` (in-place only) and worktree creation (previously reachable only via `ship --parallel`): bare is in-place (identical to `prepare`, still available as an explicit alias), `--worktree` creates an isolated worktree with no dispatch, and `--adapter` (implying `--worktree`) creates the worktree and dispatches detached. `ship finish` is unchanged and stays a separate verb. `ship --parallel` is now sugar that calls the unified entry once per ticket instead of duplicating worktree-create/brief-write/dispatch logic. Lane tracking moved from the `--parallel`-only `ship-parallel.jsonl` to `ship-lanes.jsonl`, now written by any `--worktree` lane (manual or dispatched) with a new `adapter` field; a manual lane with no dispatch record correctly surfaces as `status=prepared` instead of a misleading `running`. Every terminal outcome after a worktree is created — including a `mktemp`/dispatch-run failure — is tracked (new `status=dispatch-failed`, preserved across status refreshes) so a lane can never exist on disk without a corresponding `ship status`/`list` record; a tracking-write failure itself is now a hard failure (nonzero exit) rather than a swallowed warning. `gc.auto` guarding stays owned exclusively by the `--parallel` batch wrapper (not duplicated per-lane).

- **`pr-gate.sh --head <ref>` (CC-425).** Gate can now review a fixed head ref (branch, tag, or commit) with no PR and no working tree involved — review a branch before opening a PR, or diff `v0.6.0..v0.7.0` tag-to-tag. Uses the same merge-base (three-dot) semantics as the default `--base` path, so `base`'s independent progress after the fork point never leaks into the diff. Rejects `--allow-dirty` (which folds in local uncommitted state) as incompatible, and rejects a bare `--head` with a controlled error instead of crashing. Forwarded transparently through both the foreground and `--lifecycle detached` routes since `pmctl gate run` already passes unrecognized flags through to `pr-gate.sh`.

### Performance

- **`test-release-verify.sh` shared `--no-suite` cache (CC-432, PR#354).** Twelve duplicate `release-verify.sh --no-suite` invocations now share one cached run (`rv_no_suite_once`), cutting the suite from ~380s to ~127s.

### Docs

- **Install host-PM-aware spike convergence (CC-381, PR#359).** Three-way independent analysis (main thread / codex read-only self-test / external) converged in `docs/spikes/CC-381.md`: codex `PreToolUse` hooks are stable and fail-closed, sufficient to carry write/bash guards. CC-381 graduates from a design statement into three requirement-bearing follow-up tickets (CC-436 payload probe, CC-437 host-aware doctor, CC-438 host manifest schema v1); `install.sh` write path deliberately untouched.

- **`/ship` parallel-execution spike (CC-440, PR#361).** Converged the five design decisions for N-lane parallel shipping in `docs/spikes/CC-440.md` (lane failure isolation, executor-owned gate fix-loop, worktree lifetime until human merge, tunable N with structural isolation, no custom git locks — only `gc.auto` off during parallel runs); same PR fixed the worktree dependency-install doc.

- **`uninstall.sh` Windows warning anchored to `PM_DISPATCH_REPO` (CC-214, PR#362).** The manual uninstall command in `docs/platform-support.md` no longer assumes a hardcoded clone location.

- **Note**: CC-276 (persistent gate overrides) appears in the v0.8.0 milestone as pre-delivered work rediscovered during planning; its changelog entry lives under v0.6.0 (gh-174, PR#301).

---

## [0.7.1] — 2026-06-30

### Added

- **`/pre-release` Layer 2 — semantic diff coverage (CC-430, PR#339).** After Layer 1 structural audit, the command now runs a main-thread inline Layer 2 analysis: per scoped ticket, reads the `Requirement` section from BACKLOG.md (stops at next `##` or `**Depends on**`; N/A if absent), lists changed files via `gh pr diff <PR#> --name-only`, then fetches each relevant file's patch individually via `gh api /repos/{owner}/{repo}/pulls/{PR#}/files` — no full PR patch dump. Outputs a coverage table (`Covered / Partial / Gap / N/A`) with Confidence (`High / Med / Low`) and Flag (`⚠️` for Partial/Gap/Low) columns. No sub-job dispatch. Does not produce GO/NO-GO — judgement stays with the user.

- **`pm-write-guard` hook: three new allow rules with cross-rule symlink escape prevention (CC-258, PR#342).** Added `/tmp/<slug>/*.md`, `docs/spikes/{CC-NNN*,*-scope,*-rfc}.md`, and symlink-normalized memory double-canonicalization allow rules. Added ~15 regression tests for cross-rule symlink escape edge cases. Total test count reaches 193.

- **`doctor.sh` ↔ `install-hooks.sh` hook-profile parity test (CC-224, PR#341).** Added `scripts/test-hook-profile.sh` asserting that the minimal hook sets listed in `doctor.sh` and `install-hooks.sh` match exactly, preventing silent drift when a new hook is added to one file but not the other.

- **Shared adapter lib: `scripts/lib/model-aliases.sh` (CC-420, PR#345).** Extracted the model-alias TSV parser shared by the `claude`, `codex`, and `opencode` adapters (~30 duplicate lines eliminated). All three adapters now source this lib.

- **Shared adapter lib: `scripts/lib/timeout-resolve.sh` (CC-421, PR#346).** Extracted the timeout-precedence resolution logic (brief timeout > adapter default > system default) shared by the three adapters and `dispatch-post-verify.sh` (~15 lines × 4 eliminated).

- **Shared adapter lib: `scripts/lib/dispatch-common.sh` (CC-422, PR#347).** Extracted five shared adapter init helpers (`require_brief_file`, `require_working_dir`, `load_model_aliases`, `resolve_timeout`, `init_run_dir`) into a single sourced lib. All three adapters now share a single init sequence.

### Fixed

- **`uninstall.sh` blast-radius guard: exact managed-root path rejection (CC-210, PR#340).** Added `[[ "$dst" == "$managed_root" ]]` precise path check to prevent the managed root itself from being deleted during uninstall. Added regression test case.

- **`test-portable.sh` lock contention: FIFO-gated IPC replaces fixed `sleep 1.2` (CC-240, PR#344).** `case_mkdir_lock_contention` now uses a FIFO release signal for cross-process synchronization instead of a timing-dependent sleep, eliminating CI flakiness on slow runners. Satisfies qa-testing-rules constraint against sleep-based async synchronization.

- **Archiver safe-drop: terminal row preserved when body is absent everywhere (CC-285, PR#343).** When a terminal row's body section is absent from both `BACKLOG.md` and `BACKLOG-ARCHIVE.md`, the archiver now preserves the row and emits a warning instead of silently dropping it. Added regression fixture.

---

## [0.7.0] — 2026-06-29

### Changed

- **Context retrieval ordering is now a mandatory PM contract.** The PM agent rule and context-retrieval spec now require context query before Read/Grep/full-file opens, with targeted fallback only after no hits (CC-400).

- **Retrieval-first defaults are now load-bearing (CC-402).** Three coordinated changes make context-first the default dispatch behavior instead of opt-in:
  - **`dispatch.auto_pack` built-in default flipped `off` → `on`.** Every `pmctl dispatch run` now runs reuse-scan and appends an `auto_context:` block by default; `--no-auto-pack` (or `dispatch.auto_pack = off`) opts out. Precedence is flag > config > built-in (on).
  - **`BRIEF_VALIDATE_RETRIEVAL` default flipped `warn` → `fail`.** A file-writing brief with no retrieval evidence (`context:` / `auto_context:` / `retrieval_skip_reason:`) is now **rejected**, not just warned. Set `BRIEF_VALIDATE_RETRIEVAL=warn` to restore the advisory behavior.
  - **Detached + auto-pack is now supported** (previously rejected before launch), and in **both** lifecycles the augmented brief is landed at the guardable `/tmp/brief-<run_id>.md` path so a single brief is guarded == validated == executed == recorded. Under `detached` it is recorded as the run-spec's trusted `brief_file` and the supervisor re-guards/validates/executes it (no second `--brief-file` passthrough); under `foreground` dispatch snapshots the pack to the same `/tmp` path, guards it, and forwards it. The authored `--brief-file` is still guarded first for path policy (a brief outside the `/tmp` pattern is denied before any pack derivation). The dispatch gate now validates the *effective* (post-auto-pack) brief so an appended `auto_context:` block counts as evidence under `fail` mode.

- **`/mem-search` now routes through `pmctl context --source memory` (CC-406, PR#325).** Direct `rg` is kept only as a fallback when the memory index is unavailable. This aligns `/mem-search` with the retrieval-first contract; required CC-403's memory source to land first.

- **MEMORY.md injection now uses usage-based frecency ranking (CC-427, PR#329).** Tier-1 (`priority: always`) cards are pinned unconditionally; normal cards are ranked by a Firefox-style bucket score (`access_count × age_bucket`) with W-TinyLFU aging — pure-integer, zero-LLM. Replaces the previous alphabetical/insertion-order injection that caused the 33-card budget failure.

- **Lifecycle validity gate suppresses stale/superseded cards from frecency ranking (CC-428, PR#332).** Cards with `status: stale` or `status: superseded` are excluded from normal ranking regardless of usage score; `priority: always` pins bypass the gate. Cards with `access_count` bucket = 0 are demoted. Five new regression tests.

### Added

- **`brief-validate.sh` now checks retrieval evidence for file-writing briefs.** Non-trivial briefs must carry a non-empty `context:` block (or the `auto_context:` block that `pmctl dispatch run --auto-pack` appends), or a non-empty `retrieval_skip_reason:` (CC-401). The check shipped at `BRIEF_VALIDATE_RETRIEVAL=warn` and is now **fail** by default — see the `Changed` entry above for the default flip (CC-402); set `BRIEF_VALIDATE_RETRIEVAL=warn` to restore advisory behavior.

- **`pmctl context` now supports `--source memory|repo|all` (CC-403, PR#313).** Memory cards and episodes are a first-class queryable context source alongside the repo index. Memory-local DB backed by `source_domain: memory`; `pack memories[]` populated; reuse-scan remains repo-only. Supersedes/absorbs CC-340 MVP; embeddings remainder stays in CC-340.

- **MEMORY.md injection budget: 20 entries / 3000B cap with `priority: always` pin (CC-404, PR#328).** Replaces the previous unbounded inject-all behavior. Prompt-keyword ordering places relevant cards at the top of the injected block. Usage-based dynamic ranking factored out to CC-427.

- **Memory card frontmatter standardized; `/mem-doctor` read-only health check added (CC-405, PR#315, PR#327).** Schema fields: `topics`, `priority`, `status`, `updated_at`, `repo_refs`. `pmctl memory doctor` reports dead links, stale `repo_refs`, unreferenced cards, and `episodes.jsonl` size warnings. `status: active` enforced at write time by `/mem-distill` and `/memory-compress`; 33 live cards backfilled.

- **Episodes derived summaries and archival strategy (CC-407, PR#330).** `episodes.jsonl` remains append-only (auditable). `/mem-distill` now produces a `episodes.summary.md` monthly summary. Shard/archive threshold configurable; integrates with `/mem-doctor` size warnings.

- **Memory commands rewritten in pure bash — python3 dependency removed (CC-424, PR#326).** `pmctl memory dir` behavior isolated; fixture-isolated test coverage added.

- **Context test suite is now parallel-safe (CC-411, PR#314).** Removed coupling to the live repo; tests run correctly in parallel and isolated environments without shared-state flakiness.

- **Guard script terminology unified: `hook-*.sh` → `guard-*.sh` (CC-384, PR#310).** `framework/`, `helper/`, and `env` prefix scripts renamed consistently. `install.sh`, `uninstall.sh`, and `doctor` commands rewired; parity scanner and documentation updated.

- **`run-all-tests` now runs test suites in parallel (CC-409, PR#311).** `--jobs N` (default: `nproc`) controls concurrency. Dispatch-wait poll interval is now configurable. Significantly reduces local test cycle time.

- **`/pre-release` milestone audit command (CC-426, PR#334).** `pmctl pre-release audit <milestone-id>` runs Layer 1 structural checks (PR ref completeness, ticket body residuals, CHANGELOG coverage, BACKLOG index/body status consistency) and appends a Layer 3 blind-spot declaration. Outputs a report — not a GO/NO-GO verdict. Layer 2 semantic diff coverage planned for CC-430.

- **v0.7.0 release closure: first `/pre-release` dogfood run (CC-429, PR#335).** Applied the audit tool to v0.7.0 itself: found and fixed 25 structural drift issues (19 CHANGELOG entries missing, 1 MILESTONES PR ref, 2 BACKLOG-ARCHIVE `pr:#TBD` residuals), then tagged and published the release.

- **Artifact relocation out-of-repo — CC-003 epic complete (CC-413–CC-419, PR#318–#324).** Six-phase migration:
  - Phase 0 (CC-413, PR#318): pr-gate integrity check excludes its own artifact paths — stops gate from flagging own outputs.
  - Phase 1 (CC-414, PR#319): `--trace-dir` flag/env priority seam — adapters can override trace write location without touching core paths.
  - Phase 2 (CC-415, PR#320): post-verify containment guard uses `--run-dir` as boundary; exits in-repo path assumption.
  - Phase 3a (CC-416, PR#321): gate artifacts relocated to out-of-repo state store; original artifact path bug fixed.
  - Phase 3b (CC-417, PR#322): dispatch artifacts relocated symmetrically.
  - Phase 4 (CC-418, PR#323): artifact observer + `pmctl artifacts list/show` discoverability interface.
  - Phase 5 (CC-419, PR#324): out-of-repo store is now the default; `pmctl artifacts gc` with `--keep-last`/`--max-age-days`; cross-repo migration via `pmctl artifacts migrate`. Closes CC-003 epic.

### Fixed

- **Guard audit log no longer leaks `Permission denied` to stderr when `hooks.log` is read-only (CC-410, PR#311).** `g_audit`'s append now wraps in a brace group (`{ printf ...; } 2>/dev/null || true`) so the redirect-open failure is silenced correctly. Audit remains best-effort and never affects allow/deny decisions or guard exit code. Regression test added to `test-guards.sh`.

---

## [0.6.0] — 2026-06-19

**Theme**: Executor abstraction (v0.6.0) — runtime decoupling. Foundation phase: declare an adapter's execution topology once in its manifest so the router, guard wrappers, and install wiring derive from a single source instead of re-encoding it three times.

### Added

- **`/spike` skill + `spike` planner agent give spike investigations a first-class, committed workflow instead of ad-hoc Explore calls.** `agents/spike.md` reads a `spike`-epic ticket's `Investigation scope` / `Done-when`, plans 2–3 *diverging* angles (code-audit / interface-draft / prior-art / tool-eval) with a per-angle executor + model, and returns a `spike_plan_v1` block; the **main thread** fans out one agent per angle (subagents cannot spawn subagents — same shape as `/pr-gate`'s reviewer fan-out), then re-invokes the agent to synthesize a `docs/spikes/<ticket-id>.md` decision file (`Recommendation` is the load-bearing output) and update the ticket's `Result log`. Carries the existing spike disciplines forward: pilot-walkthrough for API-design spikes, `test_target` + GREEN/AMBER/RED rubric and mandatory main-thread verdict validation for tool-evaluation spikes (sandbox/network/local-tooling failure is local-env → AMBER, never RED). Decision rule documented so spike stays distinct from `/discover` (choose options) and `/research` (import external options): use spike only when a candidate is selected and a *durable* feasibility/API/architecture decision must be committed before a brief can be written (CC-220).

- **`/research` skill brings external knowledge in as a filtered feasibility list instead of raw search noise — the outward complement to `/discover`.** `commands/research.md` runs a grounded pipeline: (1) **internal anchoring** against `DECISIONS.md` + project memory to establish "what we already have / what we ruled out and why" (isolated into one step with a documented swap-point to `pmctl context --source memory` for when CC-403 lands — no bespoke memory search path persists); (2) a mandatory **directioning question** to narrow the query before any search (no search fires from a vague topic); (3) a **WebSearch-capable agent** fetches 3–5 bounded external data points; (4) the main thread **filters each method against internal constraints**, marking it adoptable or naming the specific constraint/decision it conflicts with; (5) a mandatory **persistence prompt** asking whether to convert a result into a BACKLOG ticket, a spike ticket, or a memory note — so external research never stays an ephemeral conversation artifact. Never auto-opens tickets or modifies files without confirmation (CC-344).

- **`pmctl gate run` supports persistent accepted-risk overrides so a maintainer no longer re-types the same override every gate round.** A `--override-file <f>` flag (or auto-discovery of `.gate-overrides.md` at the repo root) injects the accepted-risk declarations into every reviewer and synthesis brief, instructing reviewers not to re-block those items unless the diff materially changes the accepted risk. Override rendering is centralized in one `render_gate_overrides_block` helper shared by the sequential, parallel-reviewer, and parallel-synthesis brief templates. Every run that applies overrides appends a deterministic **provenance audit** (`## Gate Overrides Applied`) to the gate result recording the source file and the exact suppressed content — written by the gate itself (not the executor), on both GO and NO-GO, so an override-driven suppression can never be silent. The provenance block is parser-safe: every line is indented and the result is re-verified after the append, so a parser-hostile override file (containing `Final: GO` / `---`) cannot corrupt the gate verdict. The trust boundary of auto-discovering an override file from the reviewed worktree is an explicitly accepted trade-off (`DECISIONS.md`); `.gate-overrides.md` is the sole reviewer-facing override channel — `DECISIONS.md` is deliberately **not** read as an override source, because a PR-gate must judge the current PR's diff on its own merits rather than be pre-biased by accumulated history (gh-174).

- **`docs/sandbox-limitations.md` documents the recurring codex-executor sandbox friction patterns and their workarounds**, and `skills/dispatch-brief` now points PM authors at it before writing `self_verify` blocks that use `go build`, network calls, Docker, or `git commit` (gh-173).

### Fixed

- **The parallel gate watchdog now reaps the whole executor process tree on timeout instead of only the dispatch wrapper.** A timed-out reviewer or synthesis session previously left its grandchild executor (`codex exec`, or a test `sleep` stub) orphaned and running, because `kill <pid>` only signaled the backgrounded `eval`/dispatch.sh process. A new `_kill_process_tree` helper walks descendants depth-first (`pgrep -P`) so both watchdogs kill the entire tree; regression-locked by no-leak assertions in the hanging-reviewer/synthesis tests. Also fixes the `pr-gate.sh -h` help output silently truncating before the option list, and guards `--override-file` against a missing operand (controlled CLI error instead of a `set -u` unbound-variable abort).

### Changed

- **`pmctl dispatch run` now delegates its post-preflight executor tail to one shared internal function and persists the adapter stdout footer durably.** The guard/config preflight remains in `pmctl_dispatch_run`; the pending/dispatched/verifying/terminal transitions, adapter subprocess pipeline, footer parse, post-verify call, and dispatch-record write now live in `pmctl_dispatch_execute_tail` so the future detached supervisor can reuse the same behavior-preserving tail. Adapter stdout is now teed to `<work_dir>/.agent-trace/<run_id>.footer` instead of a deleted `mktemp`, preserving the footer-declared per-run `trace:`/`last:`/`stderr:` paths across recovery windows while keeping the explicit-path post-verify contract unchanged. No lifecycle CLI surface was added (CC-397).

- **`adapters/claude/adapter.yaml` — `runner_kind` corrected from `host-native` to `cli-subprocess` to match the canonical headless route.** Since CC-383 (gate route) and CC-388 (general implementation), the canonical claude executor is headless `claude --print` driven by `pmctl dispatch run --adapter claude` — an independent CLI subprocess — but the manifest still declared `host-native` (the same-host `Agent(claude-executor)` topology, now a documented fallback). The stale value made `runner_kind` an untrustworthy predicate (it blocked the CC-391 detach-eligibility derivation). The manifest now declares `runner_kind: cli-subprocess` with two explicit per-flag overrides that keep the three derived flags' resolved values **behavior-identical**: `write_guard_mode: cli-only` (the brief is pmctl-landed; no executor subagent self-writes a brief via a live host `Write`, so a live PreToolUse hook must not gate it — same enforcement as before) and `needs_bash_guard: false` (claude self-governs command execution via `--permission-mode`; pm-dispatch registers no executor bash policy for claude). `dispatch_route` is left to derive to `main_thread_bash_background` (the headless-subprocess route, replacing the now-inaccurate `agent_executor` label); per CC-373 the route value is allowlist-membership + log label only and does not drive the exec branch, and `dispatch_via` forwarding `--sandbox`/`--approval` to a now-`cli-subprocess` claude is a no-op (`adapters/claude/dispatch.sh` already accepts and ignores those flags). Guard behavior is unchanged — this is a metadata correction, not a guard-edge change (security/risk-sensitive, verified fail-closed-preserving). Refreshed the now-stale `host-native`/`claude-as-host` framing in `docs/executor-contract.md` (cli-only guard table + the executor-profiles table's Sandbox-model / Write-Bash-mechanism / Suitable-scope rows, which still described claude as a main-thread execution surface) and code comments in `executor-router.sh`, `hook-executor-write-guard.sh`, `pmctl-gate.sh`, `pr-gate.sh`. New regression locks in `test-runner-kind.sh` (claude resolves to route `main_thread_bash_background` / guard `cli-only` / bash-guard `false`; manifest declares the two overrides) and updated `test-executor-router.sh` / `test-hooks.sh` (CC-392).

- **codex subagent-self-write brief path formally retired — `pmctl dispatch run --adapter codex` is the sole routine codex path.** Closes the CC-385 D5 guard-collapse follow-through. The `write_guard_mode: cli-only` manifest flip already shipped with CC-389; this change makes the retirement canonical in the docs and corrects two stale guard claims in `docs/executor-contract.md`: (1) the live-hook-vs-cli-only table listed `hook` mode as "e.g. codex" — but codex overrode to `cli-only` once its brief became pmctl-landed, so `hook` mode now has **no shipped adapter** and is reframed as reserved for the no-headless-CLI self-writing fallback class; (2) the "two dispatch entrypoints" paragraph claimed the `Agent(codex-executor)` brief-file write is gated by the live PreToolUse hook — false on two counts (codex-executor has no `Write` tool, so the main thread pre-writes the brief; and codex is `cli-only`, so the live hook no-ops), corrected to enforcement via `pmctl guard check`. `docs/dispatch-brief.md` and `agents/codex-executor.md` tightened to "sole routine path; the Agent route is a fallback that never self-writes a brief"; `agents/project-pm.md` and `skills/dispatch-brief` already aligned. The live-hook write-guard branch and script body are **retained** (fallback regression) — `scripts/test-hooks.sh` gains a regression-lock note that the surviving `write_guard_mode: hook` enforce branch is not dead code (unit-locked by `test-runner-kind.sh`) and must not be simplified away. Acceptance: 6 consecutive real `pmctl dispatch run --adapter codex` dispatches ran as independent subprocesses (exit 0) with **no live write-guard hook fired** and the CC-386 triple-machine-check PASS (structural trace + `turn.completed` terminal event + `self_verify` cmd). No core/manifest code change (CC-387).

- **Executor write-guards collapsed into one manifest-driven `scripts/hook-executor-write-guard.sh`.** The former `hook-codex-write-guard.sh` and `hook-claude-write-guard.sh` carried a byte-identical brief-path policy (`/tmp/brief-*.md`, symlink rejection, parent-resolves-to-`/tmp`); they are replaced by a single wrapper that derives the runtime from `agent_type` (`<runtime>-executor`) and reads that runtime's `write_guard_mode` from its adapter manifest (CC-372). The security-relevant **live-hook vs cli-only** asymmetry is now declared by the manifest, not inferred from which files exist: a `hook`-mode runtime (cli-subprocess, e.g. codex) is enforced on every live `Edit`/`Write`; a `cli-only` runtime (host-native, e.g. claude-as-host self-exec) **no-ops when the wrapper fires as a live PreToolUse hook** and is enforced only when driven by `pmctl guard check` (which now exports `PM_GUARD_CHECK_CLI`). `scripts/lib/pmctl-guard.sh` resolves the unified wrapper for every executor runtime and fails closed (deny) in the CLI path for a runtime with no valid manifest. `install-hooks.sh`/`uninstall-hooks.sh`/`doctor.sh` are rewired to the unified hook, and `install-hooks.sh` prunes the retired per-runtime write-guard entries from existing installs on upgrade. Adding an executor runtime now needs no new guard file. `hook-codex-bash-guard.sh` is deliberately untouched (genuinely codex-only, gated by `needs_bash_guard`). The deprecated `CLAUDE_HOOK_{CODEX,CLAUDE}_WRITE_GUARD` env shims are dropped (past v0.5.0); per-runtime bypass is `PM_HOOK_<RUNTIME>_WRITE_GUARD=off`. `docs/executor-contract.md` guard section refreshed (incl. the live-vs-cli table and a correction that a non-Claude host may have its own — possibly partial — hook mechanism). +20 guard cases across `test-hooks.sh` (runtime-asymmetry block + claude bypass/audit-log coverage) / `test-pmctl-guard.sh` / `test-install.sh` (CC-374).

- **`scripts/lib/executor-router.sh` — executor routing is now DATA-DRIVEN from on-disk adapter manifests instead of a hardcoded `codex|claude` enum.** `dispatch_route_for` (the dispatch allowlist gate + route resolver) and `resolve_executor` now treat an executor as routable iff `adapters/<name>/adapter.yaml` is a readable, non-symlink manifest declaring a valid `runner_kind`; the route is derived from that `runner_kind` via the single `runner_kind_resolve_flag` table (CC-372), honoring an explicit `dispatch_route` override. The trust boundary moves from a code constant to the manifest, so it is fail-closed: an invalid name (strict bare-identifier check blocks path traversal before the path is built), a missing/invalid manifest, or an invalid `runner_kind` all refuse. `dispatch_via_codex`/`dispatch_via_claude` are generalized into one `dispatch_via <executor> …` that resolves `adapters/<executor>/dispatch.sh` by validated name and forwards the codex-native `--sandbox`/`--approval` flags only for `cli-subprocess` runner-kinds (host-native executors drop them); the two named functions remain as thin compat shims. `scripts/pr-gate.sh` switched its three dispatch call sites to the generic `dispatch_via "$EXECUTOR"`, so a new adapter dispatches with no router edit; its no-lib copy-mode fallback keeps a hardcoded `codex|claude` form (no `adapters/` tree to read) and is documented as an intentional degraded mirror. The gate's redundant hardcoded `auto|codex|claude` `--executor` pre-validation was removed — `resolve_executor` is now the single fail-closed authority, so `pmctl gate run --executor <name>` accepts any routable adapter without a `pr-gate.sh` edit — and the result-heading mode label derives from `${EXECUTOR}` instead of a literal `codex`. Net effect: registering an executor is now "drop `adapters/<name>/` with a valid manifest" — no edit to `executor-router.sh`. +12 cases in `scripts/test-executor-router.sh` (incl. the zero-core-edit acceptance proof, override honoring, fail-closed paths, path-traversal + malformed-name rejection, and symlinked-manifest rejection of the trust-boundary guard). Folds in CC-360 (claude route alignment). Deferred to CC-376: folding `--sandbox`/`--approval` into the unified `--isolation` contract (CC-373).

- **`scripts/pr-gate.sh` — `pmctl gate run --executor claude` now dispatches an INDEPENDENT headless subprocess instead of handing over.** Previously the claude route emitted a `pr-gate-handover_v1` block for the orchestrating host to fan out in-session `Agent(claude-executor)` reviewers — which made the result a host self-review and tripped the spawned subagent's permission layer. It now dispatches the headless claude adapter (`claude --print` via `adapters/claude/dispatch.sh`) as a separate OS process, exactly like codex (`dispatch_via_claude` mirrors `dispatch_via_codex`), and integrity-checks the result in-process with `gate_result_verify`. The `pr-gate-handover_v1` block, `add_pr_gate_handover_entry`/`emit_pr_gate_handover_block`, and the claude-handover special-cases (post-gate skip, NO-GO non-exit) are retired; `docs/pr-gate-handover-schema.md` is marked deprecated and `commands/pr-gate.md` no longer documents a fan-out route. New `--model <id>` flag on the gate (default `default` → adapter's pinned model: codex gpt-5.5 / claude sonnet; pass a concrete id to override). Added `inline-fallback-matches-lib` regression asserting the inline `gate_result_verify` fallback stays in sync with the lib. Profile suite realigned to subprocess assertions; +1 `claude-executor-dispatches-subprocess` case (CC-383).

### Added

- **True detached dispatch + `pmctl dispatch wait` (Phase 7c-2b).** `pmctl dispatch run --lifecycle detached` now writes the run-spec and initial pending/dispatched state, launches `scripts/dispatch-supervisor.sh` through a single dedicated `setsid`/`nohup` helper (`nohup ... & disown` fallback when `setsid` is unavailable), redirects supervisor output to `<work_dir>/.agent-trace/<run_id>.supervisor.log`, writes the advisory PID sidecar at `<work_dir>/.agent-trace/<run_id>.supervisor.pid`, prints only the `run_id`, and exits without waiting for the adapter. `pmctl dispatch wait <run_id> --cd <work_dir> [--timeout <secs>]` is the reattach surface: `--cd` is mandatory, invalid/missing run ids exit 2, timeout exits 124. **Wait completion authority**: the authoritative signal is a supervisor-written sentinel at `/tmp/pm-supervisor-sentinel-<run_id>-<nonce>` — not the in-workspace `.dispatch-results/<run_id>.md` record. The nonce is generated by the parent (not written to the run-spec) and passed to the supervisor via env (unset before exec-ing the adapter); the sentinel key is stored in a per-user private directory (mode 700). If the key is absent (e.g., after a prior successful wait), dispatch wait falls back to the durable workspace record. The `.dispatch-results/<run_id>.md` record remains a human-readable observability artifact and is read for its summary when available. The detached supervisor inherits the same environment as foreground dispatch by explicit security-gate decision for the login-auth CLI deployment. **The built-in default lifecycle is changed from `foreground` to `detached` for eligible adapters (cli-subprocess)**: bare `pmctl dispatch run` (no `--lifecycle` flag and no `dispatch.lifecycle` config) now returns a `run_id` immediately without waiting for the adapter to complete. Callers that relied on synchronous exit-code semantics must add `--lifecycle foreground` or set `dispatch.lifecycle = foreground` in their project config. The `dispatch.lifecycle` config key (introduced in 7c-2a) is the recommended opt-back path for scripts that need the old blocking behavior. **Breaking change for `dispatch.auto_pack = on` users**: bare `pmctl dispatch run` with `dispatch.auto_pack = on` in config now fails immediately because the new default lifecycle (`detached`) is incompatible with `--auto-pack`; pass `--lifecycle foreground` explicitly or set `dispatch.lifecycle = foreground` to restore the previous behavior.

- **`pmctl dispatch run --lifecycle foreground|detached` — the dispatch lifecycle axis (Phase 7c-2a, synchronous supervisor).** Introduces lifecycle ownership as a dispatch-time choice, orthogonal to `runner_kind` (how the executor is reached): `foreground` keeps the in-process tail (built-in default in 7c-2a; changed to `detached` for eligible adapters in 7c-2b above); `detached` hands the post-preflight tail to a supervisor. A `dispatch.lifecycle = foreground|detached` config key (`PM_CFG_LIFECYCLE`) sets the default, with `--lifecycle` winning. Detach-eligibility is **derived** from the adapter's declared `runner_kind` via `runner_kind_detach_eligible` (cli-subprocess = eligible; host-native = not) — never a manifest lifecycle field — and an ineligible adapter (or `--print-cmd`) is rejected **before** any executor launch. The new `scripts/dispatch-supervisor.sh` consumes a pmctl-produced run-spec (`<work_dir>/.agent-trace/<run_id>.runspec`, schema v2: the `--cd` and `--brief-file` values recorded as trusted scalars + only the non-core adapter args as base64 passthrough, written atomically) and is explicitly **not a bypass door**: it derives its own `REPO_ROOT`, then re-runs the *full* security preflight — adapter name validation, dispatch.sh symlink/containment guard, route allowlist (shared `pmctl_dispatch_resolve_adapter`), `brief-validate.sh` on the exact brief to be executed, and `pmctl guard check` — before invoking the shared `pmctl_dispatch_execute_tail`. The supervisor rebuilds the adapter command's `--cd`/`--brief-file` from the trusted scalars (and rejects any attempt to smuggle a second `--cd`/`--brief-file` through the passthrough args), so the brief that is guarded and validated is exactly the one executed — no divergent second source. `--lifecycle detached` is rejected when combined with auto-pack (the derived pack brief diverges from the guarded `/tmp` brief; deferred), with `--print-cmd`, or for an ineligible adapter. In 7c-2a the supervisor runs **synchronously**, so detached is behavior-equivalent to foreground; `setsid`/`nohup` true detachment, immediate `run_id` return, and `pmctl dispatch wait <run_id>` from the durable record land in 7c-2b (CC-399). New `scripts/test-dispatch-lifecycle.sh` (21 cases) covers the flag/config precedence, eligibility gate, pre-launch rejection (ineligible / print-cmd / auto-pack), run-spec round-trip, and the supervisor's re-validation of tampered run-specs (non-routable/traversal adapter, malformed brief, smuggled `--brief-file`) (CC-398).
- **`pmctl dispatch run` durable dispatch records** — foreground dispatch now writes `<work_dir>/.dispatch-results/<run_id>.md` after every terminal outcome, with YAML frontmatter plus a short human-readable verify summary. The record is repo-local and gitignored, mirrors the final run state without changing `run.schema.json`, and is best-effort: a write failure logs to stderr without changing the dispatch exit code (CC-225).
- **`scripts/lib/runner-kind.sh` / `adapters/{codex,claude}/adapter.yaml`** — the **runner-kind manifest foundation** of the executor-abstraction milestone. An adapter declares one primitive, `runner_kind` (`cli-subprocess` = thin subprocess dispatcher gated by live hooks, e.g. codex; `host-native` = self-executing host gated by its own harness, e.g. claude-as-host); the three execution-topology flags — `dispatch_route`, `write_guard_mode` (`hook` \| `cli-only`), `needs_bash_guard` — derive from it via `runner_kind_resolve_flag`, the single place the mapping lives. A non-empty per-flag override wins over the runner-kind default, so a genuine asymmetry (e.g. a future `cli-subprocess` adapter that needs no bash guard) is declared, never inferred from which hook files exist. The derivation is a pure, host-agnostic function: whichever runtime hosts the PM (claude or codex), driving any executor reads the same manifest and resolves the same path. The existing codex (`cli-subprocess`) and claude (`host-native`) adapters gain backfilled manifests with byte-identical dispatch/guard behavior, and `pmctl adapter generate` now emits `runner_kind` for new adapters (required fields 8 → 9). Pure-additive; no router or guard consumer is rewired in this phase. 31 new cases in `scripts/test-runner-kind.sh` (CC-372).
- **`scripts/lib/gate-result-verify.sh` + `pmctl gate verify`** — extracted the gate-result integrity contract (non-empty; exactly one plain `Final: GO|NO-GO`; frontmatter `final:` present and equal to the body verdict; optional pin to the shell-computed verdict) into a single sourceable library — now the one authority used by the synchronous (single-session) route, the parallel synthesis route, and the new `pmctl gate verify <file>` command. `pmctl gate verify` gives the `--executor claude` host-native route — whose result is written out-of-process *after* the handover — the SAME post-write integrity check the codex route runs in-process, so a host-written gate result is confirmable/trackable via pmctl **without changing claude's execution model**. `pr-gate.sh` keeps an inline fallback of the verifier for standalone copy-mode (exercised by the copy-mode test). 5 new cases in `scripts/test-pmctl-gate.sh` (CC-382).

### Removed

- **`agents/claude-executor.md` retired.** Claude execution is now adapter-only, matching opencode: `pmctl dispatch run --adapter claude` invokes `adapters/claude/dispatch.sh` and the headless `claude --print` subprocess. Removed the in-session Agent file, its smoke test, and the stale guard/docs references that described a claude Agent fallback.

- **`agents/codex-executor.md` retired + codex `danger-full-access` cut (decision A).** Symmetric to the claude-executor retirement, codex is now adapter-only — every executor runs as an independent subprocess via `pmctl dispatch run`, with no in-session Agent executor route. The `Agent(codex-executor)` route's only unique capability was `isolation_level: none` (danger-full-access), hard-rejected on the Bash route and reachable only via that Agent escape hatch. Analysis (CC-395) found it **non-load-bearing** (codex's default `workspace-write` is a real sandbox), **zero-usage** (no real brief ever set it), and a Model-A-era artifact (the Agent gate predates Model B's trusted main-thread brief authoring). **Decision: cut it.** `scripts/lib/handover-validate.sh` now rejects `isolation_level: none` for every executor **except opencode** on **all** routes (was: bash-route-only); opencode keeps `none` because it is load-bearing there (no finer-grained sandbox — `--dangerously-skip-permissions` is its sole unattended mode). codex's max isolation is now `workspace-write`; `none` is removed from `adapters/codex/isolation-map.yaml`, and `adapters/codex/dispatch.sh` additionally rejects a raw `--sandbox danger-full-access` flag fail-loud (exit 2) — the single chokepoint every dispatch path crosses — so native-flag passthrough via `pmctl dispatch run` cannot reintroduce full access past the `isolation_level` policy. claude reaches the same end-state (its `none` was already unreachable post-claude-executor). **Guard + wiring removed:** the codex-only `scripts/hook-codex-bash-guard.sh` (+ its `adapters/codex/bash-guard.sh` symlink) is deleted — it only ever gated the retired subagent's Bash; `adapters/codex/adapter.yaml` overrides `needs_bash_guard: false` (codex now matches claude/opencode), and `scripts/install-hooks.sh` gains a manifest-driven **orphan cleanup** that prunes any wired-but-unbacked adapter bash guard from existing installs on the next run. `scripts/lib/pmctl-guard.sh` drops the codex pre-bash policy cell — no executor runtime registers a pre-bash policy now, so `pmctl guard check`/`pmctl safe bash` for `executor` fail closed (exit 3). The now-dead `PM_HOOK_CODEX_READ_ROOTS` export (consumed only by the deleted guard) is removed from `adapters/codex/dispatch.sh`. **Docs/tests swept:** `docs/dispatch-brief.md` (§Fallback + §Fallback Agent Call Checklist removed), `docs/executor-contract.md`, `docs/CONCEPTS.md`, `docs/review-model.md`, `docs/model-tier-policy.md`, `commands/pm.md`, `agents/project-pm.md`, `README.md`, `SECURITY.md` converged to the adapter-only/no-Agent-fallback model; new regression locks: codex `none` rejected on the `agent_executor` route, `--profile full` wires no adapter bash guard, install-hooks orphan-cleanup prunes a seeded stale guard, codex resolves `needs_bash_guard=false`, and `pmctl safe bash --role executor` fail-closes. The install `--profile` flag is retained (now wires no adapter guard, since none ship) — its full removal is deferred. Follow-up CC-396 tracks remaining CC-provenance comment cleanup in operational files (CC-395).

- **Deprecated-surface removal sweep (v0.6.0 Phase 4).** Retired the deprecation cruft tracked since v0.4.0/v0.5.0, now that the migration windows have closed. (1) **Handover legacy isolation trio removed** — `scripts/lib/handover-validate.sh` drops the `handover_validate_sandbox` / `handover_validate_approval` / `handover_validate_skip_git_check` validators and their `export -f`; `isolation_level` is now a **required** handover field (no longer "canonical OR legacy trio"), and a brief that still carries any of `sandbox` / `approval` / `skip_git_check` is rejected with `legacy field removed in v0.6.0; use isolation_level instead` rather than being silently ignored. The codex adapter's own native `--sandbox`/`--approval` CLI flags (the translation target of `isolation_level`, in `adapters/codex/dispatch.sh`) are untouched — they are not the deprecated handover surface. (2) **`CLAUDE_HOOK_*` env shims removed** — the 9 backward-compat shim lines (target v0.5.0) across the five `scripts/hook-*.sh` guards are deleted; use `PM_HOOK_*`. (3) **`scripts/codex-dispatch.sh` residue cleaned** — the shim file itself was deleted in the v0.3.0 sunset (CC-296); this sweep removes the now-dead `if [[ -f codex-dispatch.sh ]]` allowlist guards (kept in parity across `scripts/lib/allowlist.sh`, `doctor.sh`, `uninstall-hooks.sh`, and the `test-install.sh` / `test-doctor.sh` mirrors) and corrects stale `codex-dispatch.sh` references in comments/messages (`pmctl-adapter.sh`, `adapters/codex/isolation-map.yaml`, `codex-watch.sh`, `test-state-store.sh`) to `adapters/codex/dispatch.sh`. (4) **`bash scripts/pr-gate.sh` direct invocation** is **downgraded to a doc-only deprecation** (not removed): `pr-gate.sh` is the gate implementation (`pmctl-gate.sh` `exec`s it) and standalone/copy-mode remains an officially supported fallback, so no file removal or runtime warning — docs recommend `pmctl gate run`. The `--profile pm|codex|claude` guard-check flag was already gone (guard check takes `--role`/`--runtime`); the `--profile minimal|full` flag on install/doctor is a different surface and stays. `docs/dispatch-brief.md` and `docs/executor-contract.md` updated to mark the trio removed; handover/dispatch test fixtures migrated to `isolation_level` with new trio-rejected regression locks (CC-335).

### Fixed

- **`MILESTONES.md`** — the `## v0.5.0` section header still read `規劃中` (planned) after the `v0.5.0` tag shipped (2026-06-13), tripping the `check-docs-freshness` planned-but-tagged blocking check; corrected to `released 2026-06-13` (CC-335).
- **`scripts/pr-gate.sh`** — the gate's brief templates produced briefs that `brief-validate.sh` (the reviewer executor's first action since CC-351) always REJECTs, so the `--executor claude` gate route never ran a review: the combined brief's `acceptance:` was indented under `self_verify:` ("missing field 'acceptance'"), and all three templates (combined / parallel-reviewer / synthesis) had a `self_verify` block with no `- cmd:` machine-check ("self_verify has no 'cmd:' entry"). Dedented `acceptance` to column 0 and converted `- file-exists: <out>` to `- cmd: "test -f <out>"`. Added 3 regression cases asserting each generated brief passes `brief-validate.sh` — the gap that let it ship, since the stubbed gate tests never validated the generated brief (CC-379).
- **`scripts/install-hooks.sh` / `scripts/uninstall-hooks.sh`** — the pr-gate reviewer guard permission was allow-listed only in bare form `Bash(pmctl guard check:*)`. An in-session reviewer subagent whose `PATH` lacks the pmctl bin dir invokes `pmctl` by absolute path, which did not match — and a background subagent cannot prompt, so the guard call was denied and the gate result file could not be written (same tilde-vs-absolute class as CC-291). `install-hooks.sh` now writes the bare, absolute (`${PMCTL_BIN_DIR:-$HOME/.local/bin}`), and tilde forms; `uninstall-hooks.sh` removes all three (install/uninstall kept symmetric per CC-368); the three CC-334 reviewer-permission tests assert the abs+tilde forms (CC-380).
- **`scripts/pr-gate.sh`** — a relative `--output` (or relative `--cd` default) was embedded verbatim into the reviewer brief's `pmctl guard check … --file` constraint and the `pr-gate-handover_v1` `output_file` field, but the reviewer write-guard requires an absolute `file_path` and the handover schema mandates an absolute `output_file`. The guard therefore exited nonzero and the reviewer aborted the write, leaving a 0-byte result while the gate reported success — for **both** executors (codex and the claude handover). `OUTPUT_FILE` is now normalized to absolute against the working dir before brief construction. New regression `relative-output-normalized-to-absolute` asserts the generated brief carries the absolute guard path; the bug had escaped because callers had only ever passed the default (already-absolute) output (CC-382).
- **`scripts/test-run-all-tests.sh`** — mirrored the `test-runner-kind` suite into the meta-test's `SUITE_NAMES` registration and path map; CC-372 had added it to `scripts/run-all-tests.sh` only, drifting the aggregator's listed count (55) from the meta-test's expected count (54) and cascading 9 local-only failures. Not a CI job, so CI was unaffected (CC-382).

### Maintenance

- **Operational file CC-provenance cleanup.** Removed design-history ticket references (CC-NNN) from `scripts/`, `adapters/`, and `lib/` operational files; BACKLOG, MILESTONES, CHANGELOG, and test fixture data are unaffected (CC-396, PR #303).

- **`scripts/release-verify.sh` Phase 3b — v0.6.0 feature smoke.** New phase exercises three v0.6.0 contracts against the real installed binary: adapter manifests (`runner_kind` field presence for codex/claude/opencode), write-guard policy (`pmctl guard check` executor allow/block), and brief-validate policy (legacy `sandbox`/`approval`/`skip_git_check` trio rejection + `isolation_level:none` codex rejection). Three `test_phase3b_*` regression functions added to `test-release-verify.sh` (PR #304).

## [0.5.0] — 2026-06-13

**Theme**: Local context substrate + memory read/write loop. Builds on the v0.4.0 state-first foundation by making context usable *before* dispatch via a dual-plane index with a single context-pack interface — a repo plane (`pmctl context index/update/query` over files / symbols / chunks: "where to change, what to reuse") and a knowledge plane (heading-anchored index over BACKLOG / DECISIONS / MILESTONES / docs: "why"), with state/event records as a ranking signal ("what happened recently"). The thin vertical slice `repo index → context-pack → reuse-scan` lands end-to-end and is wired into the dispatch flow (`reuse-scan` prior-art pass, opt-in auto-pack) with usage observable via `pmctl trace`. The memory loop closes: `/mem-distill` distills anomaly events into cards (write side), the anchored knowledge index serves them back (read side). Also completes the `pmctl` state-ops surface (`task claim/dispatch/status/review`, `safe bash`, `validate`), adds the `/discover` milestone seeder and the warning-mode task lifecycle gate, sunsets the v0.3.0 deprecations (`--profile` alias, `codex-dispatch.sh` shim), and closes Windows MSYS/NTFS portability gaps. Per `docs/platform-support.md` (CC-370), Linux + WSL2 are the supported platforms during core development; native Windows Git Bash and macOS sign-off are deferred to a dedicated platform phase.

### Removed

- **`scripts/hook-tool-trace.sh`** — retired the write-only tool telemetry hook; `install-hooks.sh` no longer registers it and prunes existing registrations on upgrade (CC-367).
- **`scripts/hook-routing-log.sh`** — removed the no-op routing-log deprecation stub; `install-hooks.sh` prunes existing PostToolUse registrations while the routing-to-events migration path remains available for legacy data (CC-367).
- **`pmctl guard check --profile <pm|codex|claude>`** — deprecated alias removed (sunset target v0.5.0 reached, per CC-296). Callers must use `--role <pm|executor|reviewer>` + `--runtime <codex|claude>`. Back-compat test cases `deprecated-profile-*` / `profile-role-mutex` removed from `scripts/test-pmctl-guard.sh` (CC-296).
- **`scripts/codex-dispatch.sh` compatibility exec wrapper** — removed. The canonical adapter is `adapters/codex/dispatch.sh`, invoked via `pmctl dispatch run --adapter codex`. All operational docs (`agents/`, `commands/`, `docs/`) updated to the canonical path; historical spike docs are unchanged (CC-296).

### Changed

- **`agents/codex-executor.md` / `agents/claude-executor.md`** — brief schema validation is now a **deterministic, fail-fast first action** on both Agent fallback executors, replacing the hand-kept LLM-judgment field tables (which omitted `schema_version` and behaved inconsistently across sessions/prompt-cache state). Validation is delegated to the single `scripts/brief-validate.sh`: codex-executor reaches it through the `pmctl dispatch run` pre-flight (`hook-codex-bash-guard.sh` blocks a direct `bash` call, so the dispatch command IS the gate); claude-executor calls `brief-validate.sh` directly (no bash-verb guard) before reading any target file or editing. A malformed brief — including a plain-prose brief with no `schema_version` — is REJECTed (`REJECT: missing field '<name>'`) with no executor spawned and no target file read, identically on every dispatch. Authoritative required-field list now lives only in `brief-validate.sh` + `docs/dispatch-brief.md` §Required fields (no drift-prone duplicate in the agent prompts) (CC-351).
- **`agents/claude-executor.md` / `docs/dispatch-brief.md`** — claude-executor restructured to mirror `agents/codex-executor.md`: `pmctl dispatch run --adapter claude` is the single documented file-based primary route, and `Agent(claude-executor)` is a narrow fallback with an explicit N-condition allowlist table + caller decision checklist (replacing the prior loose bullet list). The host-independent escape hatch (no `claude` CLI in PATH) and the `/pr-gate` reviewer fan-out are documented as sanctioned uses so neither is mistaken for legacy. `docs/dispatch-brief.md` §Fallback gains a symmetric claude fallback table. Unifies the two-executor mental model for maintenance; no runtime/code change (CC-353).
- **`commands/mem-distill.md`** — the **write side of the memory loop**: `/mem-distill` now reads the **anomaly slice** of `events.jsonl` (`pmctl trace tail --kind run.failed/guard.denied/task.blocked --json`) alongside `episodes.jsonl`. Recurring `(adapter, exit_class)` patterns (≥ 2 occurrences) become feedback-card candidates; a single occurrence is promoted only when it reveals a persistent constraint. Happy-path lifecycle events are explicitly excluded (no distillable semantics). Step-1 path discovery moved from a Python snippet to bash (the project carries no Python dependency). 8 new structural cases in `test-commands.sh` (CC-234).

### Added

- **`scripts/lib/pmctl-context.sh` / `cli/pmctl` / `core/schema/context-pack.schema.json`** — the **repo-index foundation** of the v0.5.0 context substrate. `pmctl context index/update/query` builds a Bash + SQLite builtin index over the repo (`files` / `symbols` / `file_chunks` tables, WAL concurrency, FTS5-optional with a `LIKE` fallback for sqlite3 builds without FTS5); change detection is mtime-based (sha1 stored for debug only), with stale-row reconciliation on re-index and path-boundary enforcement. `context-pack.schema.json` gains the `context_hit_v1` optional fields — `source_domain` (knowledge / repo / state), `why_relevant`, `trust_level` (high / medium / low), `refs` — and relaxes `schema_version` from `const: 2` to `enum: [1, 2]` so v1 packs stay valid. 20 new test cases in `scripts/test-pmctl-context.sh` (CC-237 / CC-338).

- **`scripts/lib/pmctl-context.sh` / `agents/project-pm.md` / `docs/context-retrieval.md`** — **anchored knowledge index + retrieval reflex**, the read side of the context plane. A per-format chunker seam (`_ctx_chunk_file`) indexes Markdown docs as heading-anchored sections (so BACKLOG / DECISIONS / MILESTONES / docs are queryable instead of grep-only) and txt / json / yaml via a sliding window; `pmctl context query --domain knowledge|repo` filters by path-based classification (no schema change). The "query the index before grep" discipline is recorded in the platform-neutral `docs/context-retrieval.md` contract plus a one-line pointer in `agents/project-pm.md` (kept out of CLAUDE.md to avoid platform binding). 9 new test cases (CC-354).

- **`scripts/lib/pmctl-context.sh` / `docs/context-retrieval.md` / `docs/dispatch-brief.md` / `agents/project-pm.md` / `skills/dispatch-brief/SKILL.md`** — **wires the context plane into the dispatch flow and makes usage observable** (the spine's first operational callers). Brief-authoring docs now require a `pmctl context reuse-scan` prior-art pass before a brief is written; `reuse-scan` output is capped at ≤ 5 hits to keep stop-word noise out of the executor token budget. `pmctl context query` / `reuse-scan` each emit a `context.queried` / `context.reuse_scanned` event (two new event kinds + a `context` subject_type in `core/schema/event.schema.json`), so adoption is measurable via `pmctl trace tail --kind context.queried`. 3 new test cases (CC-356).

- **`scripts/lib/pmctl-task.sh` / `scripts/lib/pmctl-safe.sh` / `scripts/lib/pmctl-validate.sh` / `cli/pmctl`** — completes the `pmctl` state-ops surface. `pmctl task claim/dispatch/status/review` drive the task lifecycle FSM (`claimed → in-progress → done`), recording `dispatched_to` and review metadata and emitting `task.claimed` / `task.dispatched` / `task.reviewed` events (three new kinds in `core/schema/event.schema.json`). `pmctl safe bash --role/--runtime -- <cmd>` runs a `pre-bash` guard check and executes only on pass (non-zero exit on deny). `pmctl validate` lands the handover-validate framework. 13 new task-lifecycle cases (38 total in `test-pmctl-task.sh`) + 6 `test-pmctl-safe.sh` cases + `test-pmctl-validate.sh` (CC-215 / CC-341).

- **`commands/discover.md`** — `/discover [theme]` skill: switches PM into divergent mode, reads the backlog (someday + deferred) + `DECISIONS.md` + `MILESTONES.md` + recent git log, and ranks 5–10 opportunities by `(impact × timeliness) / size` as a milestone-seeder list. Pure exploration output — no dispatch brief, no ticket creation, no implementation steps (CC-343).

- **`scripts/lib/pmctl-dispatch.sh` / `scripts/lib/pmctl-config.sh`** — opt-in dispatch auto-pack for prior-art context. `pmctl dispatch run --auto-pack` (or config `dispatch.auto_pack = on`) extracts the brief `goal`, runs `pmctl context reuse-scan`, and forwards an augmented copy at `.pm-dispatch/ctx/packs/<run_id>.md` with up to 5 pointer-only `auto_context:` entries; `--no-auto-pack` overrides config. The authored brief stays unchanged, the default remains off, failures degrade to the original brief with stderr warnings, and every enabled dispatch emits `context.auto_packed` telemetry including zero-hit cases. Docs updated in `docs/dispatch-brief.md` and `docs/context-retrieval.md`; regression coverage added in `scripts/test-pmctl-dispatch.sh` (CC-366).

- **`scripts/lib/pmctl-context.sh`** — `pmctl context query`, `pmctl context pack`, and `pmctl context reuse-scan` now lazy-build the repo-local context DB when it is missing and run the existing mtime-based incremental refresh before reading when it exists. `PM_DISPATCH_CONTEXT_AUTOBUILD=0` preserves the graceful empty no-DB path, and `PM_DISPATCH_CONTEXT_AUTOREFRESH=0` skips the refresh pass (CC-365).

- **`docs/spikes/README.md`** — `test_target:` field contract: required for language-aware tool verdict spikes (codegraph, AST-grep, semgrep, etc.); documents how it differs from `working_dir:` and why omitting it makes the verdict non-reproducible. Adds a reference verdict rubric template (GREEN/AMBER/RED) that explicitly enumerates sandbox network isolation and missing dev dependencies as local-env classes under RED criterion 1 — so an executor in a sandboxed environment correctly issues AMBER rather than RED for network-blocked installs (CC-255).
- **`docs/dispatch-brief.md`** — new `test_target:` optional section in §Optional sections: required for language-aware tool verdict spikes, documents the contract and cross-links to `docs/spikes/README.md` (CC-255).
- **`agents/project-pm.md`** — `test_target:` brief-authoring rule: when briefing a verdict-issuing spike for a language-aware tool, PM must set `test_target:` to a committed representative codebase and include the verdict rubric template in setup instructions; RED applies only to clean dev machines — sandbox/network local-env failures are AMBER (CC-255).

- **`scripts/lib/pmctl-context.sh` / `cli/pmctl`** — `pmctl context pack` and `pmctl context reuse-scan` subcommands, the first consumers of the repo-index. `pack` assembles multiple repo-index queries into a JSON context-pack (schema_version 2, conforming to `core/schema/context-pack.schema.json`): hits classified into `symbols[]` (symbol-name matches) and `files[]` (chunk/FTS text matches), deduplicated by ref across queries. `reuse-scan` takes a free-text description, extracts search terms via `_ctx_extract_terms` (stop-word filter, min 3 chars, unique), runs each against the repo index, and emits a `reuse_candidates:` YAML block for pasting into a dispatch brief's `context:` field. Both require the repo index (`pmctl context index` first); no new external deps. Hits are queried via internal `_ctx_query_hits_raw` (structured TSV emitter shared by pack, reuse-scan, and the YAML query surface — removes YAML-parse coupling). `context pack` rejects non-directory positional repo arguments (exit 2) and whitespace-only `--task-id` values. 20 new test cases in `scripts/test-pmctl-context.sh` (CC-239).

- **`scripts/lib/pmctl-context.sh`** — `_ctx_extract_symbols` no longer indexes Markdown headings as symbols. Markdown/YAML/JSON/text files contribute to `file_chunks` (text-search) only; symbol extraction is restricted to code-language files (shell/Go/Python/JS/TS). This removes document-structure noise from `reuse_candidates:` output — CHANGELOG, BACKLOG, and other prose files no longer dominate reuse-scan results. 1 new regression test (`pmctl context index: Markdown headings are not indexed as symbols`); total 41 tests in `scripts/test-pmctl-context.sh` (CC-349).

- **`scripts/lib/pmctl-task.sh` / `cli/pmctl`** — tiered **Task lifecycle gate** on the `claimed → in-progress` transition, warning mode. Two new optional fields on `core/schema/task.schema.json`: `behavioral_units` (non-negative integer, estimated unit count) and `size_tier` (enum: trivial / small / substantial). `pmctl task create` and `pmctl task update` each gain `--behavioral-units <N>` and `--size-tier <tier>` flags. At dispatch time, `_pmctl_task_derive_tier` derives the effective tier (explicit `size_tier` takes precedence over derivation from `behavioral_units`; tasks with neither are unconstrained). When tier is **substantial** (≥ 3 units or `size_tier: substantial`), `pmctl task dispatch` emits a warning to stderr — "substantial task — /pre-impl design artifact recommended before dispatch" — and appends a `task.lifecycle.warn` event (`core/schema/event.schema.json`) as **best-effort telemetry** (emit is non-fatal — event-append failure is swallowed via `|| true` and does not block the dispatch transition). trivial / small / unknown tiers proceed silently; the gate is always **non-blocking** (warning mode first, hard-fail deferred to v0.6.0 when real-world usage data is available). 14 new test cases; 63 / 63 pass (CC-235).

### Fixed

- **`scripts/install-hooks.sh` / `scripts/uninstall-hooks.sh` / `scripts/doctor.sh`** — managed hook `command` paths are now shell-escaped (`printf %q`) when written to `settings.json`, so a repo checked out under a path containing a space (e.g. a Windows home `C:/Users/First Last/`) produces runnable hooks. Previously the unquoted path was word-split when Claude Code ran the hook through the shell, so **every** hook failed with `No such file or directory` (surfaced at turn end by the Stop hook). `printf %q` leaves space-free paths verbatim, so existing installs see no churn. `uninstall-hooks.sh` matches both the raw and escaped command prefix when removing managed hooks; `doctor.sh` strips shell-escape backslashes before its checkout comparison so escaped hooks are no longer mis-flagged as "wired from a different checkout". Regression test `install-hooks-spaced-repo-root` added to `scripts/test-install.sh`.
- **Windows (MSYS/Git-Bash on NTFS) portability bundle** — a set of MSYS-only false failures and real bugs, fixed without changing POSIX behavior (CC-368):
  - **`scripts/install-hooks.sh` / `scripts/uninstall-hooks.sh`** — the path-bearing `jq` writes now run with `MSYS2_ARG_CONV_EXCL='*' MSYS_NO_PATHCONV=1` so MSYS no longer rewrites the `printf %q` escape backslash (`Lien\ Chen` → `Lien/ Chen`) when passing args to a native `jq.exe`. The escaping landed correctly on Linux but corrupted spaced-home paths on Windows + winget jq. Because disabling that conversion would also stop the native `jq` from opening a POSIX-path positional input file, the input `settings.json` is fed via **stdin redirect** (the shell opens it) rather than as a positional argument — so the guard protects the `--arg` values without breaking the read. Both vars are no-ops where MSYS is absent.
  - **`scripts/lib/portable.sh` / `scripts/lib/state-writer.sh` / `scripts/lib/pmctl-dispatch.sh`** — new `_portable_canonical_path` (POSIX no-op; on MSYS collapses `C:/` vs `/c/` vs drive-letter case via `cygpath -m`) is applied before the dispatch partition hash (`_sw_project_key`) and to the dispatch `--cd` working dir used for pack/reuse-scan paths, so the same repo reached by different path spellings lands in one partition. Existing POSIX partition keys are unchanged.
  - **`scripts/test-core-schemas.sh`** — `_yaml_get` strips trailing `\r` so the enum-sync comparison no longer reports a false mismatch between identical schema/YAML values that differ only by CRLF.
  - **`scripts/test-state-store.sh` / `scripts/test-pmctl-dispatch.sh`** — the `0700`-mode and symlink-rejection cases now probe filesystem capability and `SKIP` with a reason where NTFS cannot enforce Unix permissions or `ln -s` copies instead of linking, rather than failing. icacls-based real ACL enforcement is tracked separately (CC-369).

---

## [0.4.0] — 2026-06-08

**Theme**: State-first foundation + review model. `pmctl` becomes the sole writer of Run and Event records (CC-309..317); the routing_log.md machine-write path is retired in favour of `events.jsonl`. The Review Model ("Relocating Rigor") is formalised: pre-impl six-section contract, brief `architecture_impact`/`conceptual_map` fields, brief-validate quality rules, architecture-reviewer conceptual-map-first process, and pr-gate rigor tiers (CC-322..327). PM dispatch routing switches to size-first (Tiny inline / Small `model:light` / Medium-Large Codex default, CC-332). `pmctl task`, `decision`, and `trace tail` ship as the first CLI consumers of the state substrate (CC-215, CC-315). Release polish closes Windows portability gaps, renames all env vars to `PM_HOOK_*`, and hardens the install/uninstall surface (CC-321, CC-334, CC-272, CC-336, CC-337).

### Added

- **`scripts/lib/pmctl-task.sh` / `cli/pmctl`** — `pmctl task create/show/list/update`, the first state-store write path for the Task entity. `create` validates required fields (id, title), rejects duplicate IDs via per-task lock, writes a projection file under `state/<project>/tasks/<id>.json`, and emits a `task.created` event to `events.jsonl`; rollback removes the projection if event append fails. `update` validates the state transition (pending→in-progress→completed/blocked/cancelled), writes the updated projection, and emits `task.state_changed`. `show` and `list` are read-only queries over projection files. All writes use `serialize_with_lock` for concurrency safety. 25-case test suite `scripts/test-pmctl-task.sh` covers happy path, boundary, invalid inputs, duplicate rejection, event-append failure + rollback, concurrency, and raw-admin state edit contract (CC-215, PR #242).
- **`scripts/lib/pmctl-decision.sh` / `cli/pmctl`** — `pmctl decision add`, the first state-store write path for the Decision entity. Accepts `--date`, `--title`, `--path`, `--closes` (CSV ticket list), and `--tags` (CSV tag list); derives a slug-based projection filename; validates required fields; rejects duplicate IDs under a per-decision lock; writes a projection file under `state/<project>/decisions/<slug>.json`; emits a `decision.recorded` event; rolls back the projection if event append fails. 11-case test suite `scripts/test-pmctl-decision.sh` covers required fields, CSV array parsing, duplicate rejection, event emission, write failure + rollback, and cleanup-failure visibility (CC-215, PR #242).
- **`scripts/lib/state-writer.sh`** — two new projection writers: `sw_upsert_task` (task create/update with FSM state validation and projection-file merge) and `sw_append_decision` (decision write with slug-derived filename and duplicate guard). Both follow the same temp-write/rename pattern as the existing run/event writers and are exercised by the extended `scripts/test-state-store.sh` (CC-215, PR #242).

- **`commands/pre-impl.md`** — upgraded to a six-section structured artifact contract: Intention, Non-goals, Bounded Context, Conceptual Map, Acceptance Metrics, Verification Plan. The `Conceptual Map` section maps directly to the brief's `conceptual_map:` field. Trigger condition expanded: `/pm` routing now requires `/pre-impl` when `behavioral_units ≥ 3` **or** `architecture_impact ≠ none` (any cross-layer, shared-module, or new-interface change). Design constraint list in Step 4 retained for paste into `constraints:` (CC-323).
- **`docs/dispatch-brief.md`** — two new optional fields: `architecture_impact: none|minor|major` (declares architectural weight; drives pr-gate tier suggestion) and `conceptual_map:` (plain-text structure description; required when `architecture_impact: major`; primary input for `architecture-reviewer`). Brief examples updated. `constraints:` trigger condition updated to match new routing rule (CC-324).
- **`scripts/brief-validate.sh`** — quality rules: `architecture_impact` invalid enum → FAIL; `architecture_impact:major` without `conceptual_map` → FAIL; file-writing brief `self_verify` with no `cmd:` entry → FAIL; acceptance containing vague phrase ("works as expected" / "passes tests" / "no errors") → WARN; `behavioral_units ≥ 3` without `qa_checklist` → WARN. Added `warn()` helper (emits without exit). Test suite extended from 22 to 32 cases (CC-324, CC-325).
- **`agents/architecture-reviewer.md`** — Process section restructured: when brief has `conceptual_map`, read map first, compare diff against map, open source files **selectively** (map/diff disagreement, risk surface, `architecture_impact:major`); when no map, fall back to diff review and note absence in findings (CC-326).
- **`scripts/pr-gate.sh`** — new `--brief <file>` option: reads `architecture_impact` from the brief and emits an advisory suggestion when the auto-detected tier is lower than the impact level implies (`major` → suggest full; `minor` + express detected → suggest standard). Advisory only — user-selected or auto-detected tier always takes precedence (CC-327).
- **`docs/review-model.md`** — formalises the pm-dispatch Review Model ("Relocating Rigor"): four layers — (1) Intention & Spec review upstream via `/pre-impl`, (2) Cross-Context Isolation via pr-gate subagents, (3) Conceptual Map review by the architecture-reviewer, (4) Machine Verification via `self_verify cmd:`. Explains when line-by-line diff inspection is appropriate (exception, not default) and cross-links to `docs/CONCEPTS.md`, `docs/dispatch-brief.md`, and `docs/pr-gate-handover-schema.md`. Added "pr-gate rigor tiers" section with express/standard/full semantics table and tier-suggestion documentation. Removed `> Planned` blockquotes now that CC-323/CC-326 are shipped (CC-322, CC-327).
- **`skills/pr-gate-review/SKILL.md`** — tier descriptions updated to reflect rigor-level semantics; `--brief` option documented (CC-327).
- **`docs/model-tier-policy.md` / `agents/project-pm.md`** — PM dispatch routing is now size-first: Tiny tasks (< 30 lines, 1–2 files, no new behavior) → main-thread inline; Small tasks (< 50 lines, ≤ 2 adjacent files, no new interfaces/abstractions/hooks) → `model: light` (codex-spark / haiku); Medium/Large → Codex `default`. PM prompt updated to match: Tiny triggers an inline recommendation (no brief), Small triggers a `model: light` brief (CC-332).
- **`scripts/lib/pmctl-trace.sh` / `cli/pmctl`** — `pmctl trace tail`, the first reader over the state substrate (writers CC-309..314 already shipped). Reads `events.jsonl` plus `archive/events-*.jsonl.gz` (partition resolved via the writer's `_sw_project_dir`), merges active + archive chronologically by `ts` (append order preserved on equal timestamps so a future `--since` cannot miss archived state), and supports `--kind / --task|--subject / --id / --since/--until` (inclusive) `/ -n|--limit` (default 20) `/ --all / --json`. Malformed JSON rows are skipped with a counted stderr warning; a missing store exits 0 with empty output; reads are a streamed linear scan (indexing deferred, acceptable at current volumes). Read-only — no writer, schema, layout, or data-model change. 12-case suite `test-pmctl-trace.sh`; read contract recorded in `docs/architecture/v0.4.0-state-first-foundation.md` (D6 / §10.B) (CC-315).
- **`scripts/lib/state-writer.sh`** — bounded-growth **rotation** for the append-only state store, closing the active+archive loop the CC-315 reader already merges. When `runs.jsonl` / `events.jsonl` cross a byte threshold (default 50 MB, env `PM_DISPATCH_ROTATE_MAX_BYTES`; the 90-day trigger is deferred — mtime cannot represent record age) the active file rotates, under the per-entity append lock, into a gzipped, **monotonically-numbered** segment `archive/<entity>-$YYYYMM-$NNNN.jsonl.gz` (fixes the same-month collision in the original `-$YYYYMM` shape). Rotation stages the active file to a **destination-named `.staging`** so crash recovery is genuinely idempotent — a stage left behind after a successful publish is detected (the target segment exists) and dropped rather than re-archived, so a crash in the publish→cleanup window never duplicates rows in trace/history. Rotation is best-effort and never fails the canonical append (a missing/broken `gzip` degrades to no-rotation, surfaced loudly on stderr + `state-writer.err`, never silently); `runs` and `events` rotate independently. No reader/schema/data-model change. 13-case suite `test-state-store-rotation.sh`; contract recorded in the scoping doc (D7 / §10.B), `layout.yaml` archive shape synced (golden parity test → CC-317) (CC-316).
- **`scripts/lib/state-writer.sh` / `scripts/lib/portable.sh`** — state-store **safety & robustness hardening**, completing the v0.4.0 state-first foundation. (1) `state_store_init` runs a store-root safety gate: non-mutating checks (symlinked leaf, ownership) reject **before** any `mkdir`/`chmod` so a rejected root is never touched, then the root is created `0700` and rejected if still writable via **either** the group- or world-write bit (stat-based octal check); the VERSION compatibility gate runs **before** the mutating repair so an unsupported future store is never mutated; `PM_DISPATCH_ALLOW_UNSAFE_STATE_ROOT=1` downgrades rejections to a warning. (2) The `mkdir_lock` flock-less fallback writes `pid host epoch` owner metadata and reclaims only *clearly* stale owners — a **same-host** owner is reclaimed solely on dead-PID evidence (never on age, so a long-running live holder is never stolen), while the age ceiling (`PM_DISPATCH_LOCK_STALE_SECS`, default 60) applies only to **remote** owners; reclaim has an ABA guard + bounded retries; a new `mkdir_unlock` documents the release contract (the `owner` file means a bare `rmdir` no longer suffices); `serialize_with_lock` releases on kill via a subshell-scoped `EXIT` trap; a non-fatal once-per-process warning fires on UNC/9P/NFS/CIFS/SMB lock paths. (3) `scripts/test-state-layout-parity.sh` is a pure bash+grep+jq golden test binding `core/state/layout.yaml` (subdirs, file/lock names, archive pattern) to the writer's behavior so future drift fails CI. No schema/rotation/reader/data-model change; contract recorded in the scoping doc (§10.B) (CC-317).
- **`scripts/install-hooks.sh`** — install now idempotently merges three `permissions.allow` entries required by `/pr-gate` reviewer subagents: `Write(<workspace>/**/.gate-results/**)`, `Bash(pmctl guard check:*)`, `Bash(mkdir -p:*)`. Workspace root is derived from the pm-dispatch repo's parent directory at install time (e.g. `~/github` when installed at `~/github/pm-dispatch`), with a `$HOME` fallback when the parent equals HOME or filesystem root. Without these entries, `--executor claude` reviewer agents were silently permission-blocked after a fresh install. Idempotency: existing entries are detected by exact string match and never duplicated; a failed jq transform prints a clear error and exits non-zero (CC-334).

### Changed

- **`docs/dispatch-brief.md` / `docs/executor-contract.md`** — executor contract cleanup: added §Commit delegation rule (executor must not commit on behalf of the caller; delegation is explicit) and §Style notes to `dispatch-brief.md`; added §Async dispatch behavior to `executor-contract.md` clarifying that `pmctl dispatch run` returns immediately after adapter launch and that callers must not assume synchronous completion. Eliminates the false-partial pattern where executors appeared to "partially complete" due to the async gap (CC-272, PR #245).
- **`scripts/codex-dispatch.sh`** — added stderr deprecation warning (`[deprecated]`) on every invocation: callers should use `pmctl dispatch run --adapter codex` instead of invoking `scripts/codex-dispatch.sh` directly. `commands/pm.md` and `agents/codex-executor.md` updated to reflect the preferred path as primary route (CC-336, PR #246).
- **`scripts/hook-*.sh`, `adapters/codex/dispatch.sh`, tests, docs** — all seven `CLAUDE_HOOK_*` env vars renamed to `PM_HOOK_*` (`PM_HOOK_LOG_DIR`, `PM_HOOK_PM_GUARD`, `PM_HOOK_CLAUDE_WRITE_GUARD`, `PM_HOOK_CODEX_GUARD`, `PM_HOOK_CODEX_WRITE_GUARD`, `PM_HOOK_CODEX_READ_ROOTS`, `PM_HOOK_DISPATCH_ABS`, `PM_HOOK_REVIEWER_GUARD`) across 15 files. Backward-compat shims in all production hooks: if a `CLAUDE_HOOK_*` var is set, a deprecation warning is emitted to stderr and the value is honoured; shims are scheduled for removal after v0.5.0. `grep -r CLAUDE_HOOK_ scripts/ adapters/ docs/` returns only the shim deprecation-warning lines. 427 tests, 0 failures (CC-321).

### Fixed

- **`scripts/hook-reviewer-write-guard.sh`** — reviewer write-guard now derives the allowed `.gate-results/` directory from the **target file path**, not pm-dispatch's own install location, so `/pr-gate` works when pm-dispatch is installed in one repo but used to gate a *different* project (cross-project). The v0.3.0 guard resolved the repo root from `<install-repo>/scripts/` and bound writes to that checkout's `.gate-results`, which blocked reviewer writes whenever the gated project differed from the install checkout; the `CLAUDE_HOOK_GATE_REPO_ROOT` strict-binding override is removed entirely. Regression coverage in `test-hooks.sh` / `test-pmctl-guard.sh` (CC-319).
- **`adapters/codex/dispatch.sh`** — the codex adapter now derives `$WORK_DIR`'s git root and exports `CLAUDE_HOOK_CODEX_READ_ROOTS=<git_root>:/tmp[:<inherited>]` before `codex exec`, so codex can read the dispatch target's sources regardless of where the repo lives. Previously the guard defaulted to `$HOME/github:/tmp`, so codex dispatched to a repo outside `~/github` was blocked from reading its own source files. Any caller-set `CLAUDE_HOOK_CODEX_READ_ROOTS` is preserved as a trailing fallback; the `/tmp` baseline is re-added because the explicit export replaces the guard default (correctness, not policy widening). New coverage in `test-codex-dispatch.sh` (CC-320).
- **`scripts/doctor.sh`** — `detect_hook_profile()` auto case now checks `detect_platform == windows` before `codex_available`, forcing `_want_full=0` on Windows. Previously, a Windows Git Bash environment with codex in PATH would select the `full` profile and fail doctor because `install-hooks.sh` correctly installs `minimal` on Windows. Direct regression test `case_doctor_windows_auto_profile_codex_on_path` added to `test-doctor.sh`. `test-pr-gate-profile.sh` gains a suite-level skip on Windows (uses `ln -sf` for system binary stubs); `test-claude-executor.sh` case 5 and four cases in `test-dispatch-post-verify.sh` gain case-level skips on Windows (symlink operations unsupported in MSYS). `uninstall.sh` pruning loop now prints `pruned <dir>` after a successful empty-directory removal and silently skips non-empty directories; regression coverage in `test-uninstall.sh` TC-27 (CC-337, PR #247).

---

## [0.3.0] — 2026-06-03

**Theme**: PM runtime spine — schema-first, state-first, adapter-thin. Restructures pm-dispatch from "Claude Code settings + dispatch scripts" into a layered runtime: `core/` (schema + policy) → `cli/pmctl` + `scripts/lib/` (runtime orchestrator) → `adapters/` (thin executor shims). Ships executor-agnostic dispatch (`pmctl dispatch run`), role×runtime guard keying (`pmctl guard check --role/--runtime`), concurrent-dispatch race-safety, and reviewer prompt-injection defense. Also lands cross-platform install/runtime hardening (CC-308/CC-104t, PR #220): Windows (MSYS/Git-Bash) compatibility, `cli/pmctl` installed onto PATH, the codex-dispatch shim as a real script, and removal of the `python3` dependency (pure bash + jq). M0–M4 + Hygiene Track all complete. CC-215 (`pmctl task`/`decision`/`trace`) deferred to v0.4.0.

### Added

- **`install.sh` / `uninstall.sh` / `scripts/doctor.sh`** — install `cli/pmctl` onto PATH (CC-308 follow-up). Closes the gap where the codex pr-gate reviewer guard and `pmctl dispatch run` call the bare command `pmctl` but it was never placed on PATH, so a fresh install failed with `pmctl: command not found`. On Linux/macOS/WSL, install symlinks `cli/pmctl` → `${PMCTL_BIN_DIR:-~/.local/bin}/pmctl` (idempotent, never clobbers a foreign file, prints a PATH-remediation note when the bin dir is off PATH). On Windows it prints manual-PATH instructions and does **not** copy — a copied `pmctl` resolves the wrong `REPO_ROOT` and cannot source its repo libs. `uninstall.sh` removes the symlink only when it resolves to *this* checkout's `cli/pmctl` (ownership check; the symlink lives outside the managed root, so the manifest path cannot reach it). `doctor.sh` gains a warn-level check that the `pmctl` on PATH belongs to this checkout (a foreign `pmctl` shadowing the CLI is flagged, not silently accepted). New coverage in `test-install.sh`, `test-uninstall.sh`, `test-doctor.sh`.
- **`scripts/lib/pmctl-config.sh`** — shared config loader; `pmctl dispatch run` now owns config resolution (CC-293, PR #216). `pmctl_dispatch_run` calls `pm_config_load` and exports `PM_CFG_TIMEOUT` + `PM_CFG_DEFAULT_MODEL` to the adapter subprocess — adapters receive config values via env and drop all config-loading code. Precedence: adapter-specific env vars (`CODEX_DISPATCH_TIMEOUT`, `CLAUDE_DISPATCH_TIMEOUT`) > pmctl-exported config > adapter built-in default (1200 / `default` alias). Removes ~50 LOC of duplicated config-parsing from `adapters/codex/dispatch.sh` and `adapters/claude/dispatch.sh`.
- **`skills/` starter SKILL.md files** — `skills/dispatch-brief/SKILL.md` and `skills/pr-gate-review/SKILL.md` (CC-061), the first concrete Agent Skills, aligned to the Anthropic layout (`skills/<name>/SKILL.md` with `name` + `description` frontmatter). Both are **thin** pointer skills — they route to the existing contract/runtime (`docs/dispatch-brief.md`, `agents/project-pm.md`, `/pr-gate`, `scripts/pr-gate.sh`) rather than duplicating logic — giving CC-014/015/026 the directory base they were waiting on. `scripts/lint-frontmatter.sh` now also scans `skills/<name>/SKILL.md` (closing a doc-drift where the README claimed skills/ was linted but the scanner only covered `agents/` + `commands/`); +2 `test-lint-frontmatter.sh` cases lock in the skills/ scan.
- **`scripts/test-layer-boundaries.sh`** — the executable layer-boundary enforcer (CC-233), the last M3 spine ticket. Keeps `core/` declarative + CLI-agnostic (no shell/executables; only `.yaml`/`.json`/`.md`; no CLI-product-named files/dirs; no CLI name as a field-name **key** — enum *values* and prose are allowed) and keeps thin adapters from re-absorbing the shared flow (`adapters/**/*.sh` non-comment lines must not call `brief-validate` / guard / route / `dispatch-post-verify` / pmctl; executor-specific invocation + output glue + state/usage logging are allowed). 12 cases: 5 real-repo enforcement checks + 7 self-tests that plant violations. Dedicated CI job (CC-233).
- **`adapters/claude/dispatch.sh`** — thin claude executor adapter (CC-266), symmetric to the codex adapter. Invokes headless `claude --print --output-format json` as the canonical, **host-independent** claude executor (a CLI subprocess driven by `pmctl dispatch run --adapter claude`), so codex-as-PM can drive claude-as-executor — completing the 4-cell PM×executor matrix. `agents/claude-executor.md` (Agent-spawn) is retained as the same-host optimization when Claude is the PM. Self-snapshot crash-safety; extracts JSON `.result` → `.agent-trace/latest.last` (the only pmctl-facing artifact); best-effort state-store row (`executor:"claude"`) + `claude`-pool usage logging. 14-case suite in `scripts/test-claude-dispatch.sh` (fake claude on PATH).
- **`scripts/hook-claude-write-guard.sh` + `claude` guard profile** — closes the guard gap so `pmctl dispatch run --adapter claude` is validated AND guarded (fail-closed preserved). The brief-file pre-write policy mirrors codex (`/tmp/brief-*.md`); the hook is NOT wired as a PreToolUse hook (claude-executor self-executes under harness/`--permission-mode`, so a `/tmp`-only PreToolUse guard would block its legitimate work-dir edits). `pmctl-guard.sh` now accepts `--profile pm|codex|claude` (CC-266).
- **`scripts/lib/pmctl-dispatch.sh` + `pmctl dispatch run`** — executor-agnostic dispatch orchestrator (CC-289, approach B). pmctl OWNS the shared flow: resolve adapter by convention (`adapters/<name>/dispatch.sh`) → route → `brief-validate` → `pmctl guard check` (per-profile policy) → invoke adapter subprocess → read the `.agent-trace/latest.last` output contract → `dispatch-post-verify`. The only data read back from an adapter is `latest.last` + exit code; no executor-specific tokens live in pmctl. Replaces the prior `dispatch run` stub. **Policy invariants (no bypass door):** `--brief-file` is required and the inline `--` form is refused (every dispatch is validated + guarded); `--adapter` must be a bare identifier `^[a-z][a-z0-9_-]*$` (no path traversal); the resolved `dispatch.sh` must be a regular file whose physical path stays inside `adapters/` (symlink/boundary-escape rejected); routing is a mandatory allowlist and an unavailable router/guard fails closed.
- **`adapters/codex/dispatch.sh`** — the codex adapter, relocated from `scripts/codex-dispatch.sh` (now a thin compatibility **exec wrapper** so existing callers keep working; to be removed in a later cleanup). Stays thin: executor invocation + output-contract glue only. Self-snapshot crash-safety preserved; repo-root resolution follows the wrapper to the real adapter (CC-289; wrapper converted from a Git symlink to a real script for Windows copy-mode installs in CC-308, below).
- **`scripts/test-pmctl-dispatch.sh`** — 17-case suite for the orchestrator: missing/unknown adapter, invalid adapter name, symlinked-adapter rejection, adapter-by-convention resolution + route trace, non-core arg passthrough, brief-validation block, guard deny, inline-form refusal, fail-closed router/guard branches, missing `--cd`/`--brief-file`, happy-path post-verify, adapter exit-code passthrough, and post-verify failure (CC-289).
- **`scripts/dispatch-post-verify.sh`** — executor-agnostic Phase 3 post-verify pipeline: reads `.agent-trace/latest.last`, enforces exact `cmd: pass` whole-line self-verify match, validates symlink targets stay inside `.agent-trace/`, and rejects `failed`/`partial`/`blocked` executor status. 21 fixture-based test cases in `scripts/test-dispatch-post-verify.sh` (CC-264 PR B).
- **`scripts/test-dispatch-post-verify.sh`** — 21-case fixture suite covering happy path, boundary, negative inputs, symlink safety, and the exact executor output contract (CC-264 PR B).
- **`scripts/test-claude-executor.sh`** — 5 regression cases for the claude-executor trace-write and self-verify contract (CC-264b).
- **`core/policy/isolation-level.yaml`** — new policy enum: `none | read-only | workspace-write | sandboxed`; adapters translate these intent values to executor-native flags (CC-262 M1).
- **`adapters/claude/isolation-map.yaml`** — no-op translation table for claude-executor; all four isolation levels map to empty native-flags (CC-262 M1).
- **`scripts/lib/portable.sh` `_portable_sha1()`** — cross-platform SHA-1 helper: tries `sha1sum` (GNU/Linux), falls back to `shasum -a 1` (macOS/BSD), returns 1 with a logged warning if both are missing. `FAKE_SHA1_MISSING=1` test shim included (CC-263).
- **`scripts/hook-reviewer-write-guard.sh` + `reviewer` guard role** — write-guard policy that restricts reviewer agent writes to `.gate-results/` only (CC-297, PR #218). Defense against prompt-injection in diff content causing reviewers to overwrite source files. Both sequential (`--sequential`) and parallel (`--parallel`) reviewer briefs embed an explicit `pmctl guard check --role reviewer --runtime $EXECUTOR --event pre-write --file $OUTPUT_FILE` call before any write; the hook is NOT wired as a PreToolUse hook. `cli/pmctl guard check` extended to accept `--role reviewer`. 78 test cases in `scripts/test-pr-gate.sh` (+2 guard-constraint assertions); 57 cases in `scripts/test-pmctl-guard.sh` (+2 reviewer cases; +1 relative-symlink case).
- **`docs/spikes/fanout-dispatch-spike.md`** — architecture evaluation of 4 fan-out approaches for multi-reviewer parallel dispatch (CC-297, PR #218). Approach B (`pmctl gate run` orchestrator) recommended for v0.4.0; selected over Approach A (main-thread fan-out via Agent()) for its executor-agnostic orchestration and consistent guard enforcement.
- **`scripts/pr-gate.sh` `--allow-dirty` flag + dirty-worktree preflight** — gate now fails explicitly when `BASE...HEAD` has committed changes AND the working tree is dirty (CC-260, PR #214). Previously the gate silently proceeded with a dirty worktree, leaving uncommitted edits invisible to reviewers. `--allow-dirty` opt-in folds working-tree changes into the review scope (useful for iterative gate/fix cycles when fixes are not yet committed).

### Fixed

- **`scripts/hook-reviewer-write-guard.sh` + `docs/executor-contract.md`** — bind reviewer writes to **this repo's** `.gate-results/`, not any directory named `.gate-results` anywhere on disk (pr-gate advisory clearance). The guard derives the repo root from its own location (`<repo>/scripts/`); `CLAUDE_HOOK_GATE_REPO_ROOT` overrides it for tests. Also documents the `reviewer` role in the `pmctl guard check` CLI signature. Regression cases added in `test-hooks.sh` / `test-pmctl-guard.sh` (including an off-repo `.gate-results` deny).
- **`scripts/lib/pmctl-dispatch.sh` + `adapters/codex/dispatch.sh` + `adapters/claude/dispatch.sh`** — fix concurrent dispatch race on `latest.*` symlinks (CC-305, PR #216). `pmctl dispatch run` now tees adapter stdout to a temp file, parses the per-run `last:`/`stderr:` footer paths, and passes them as `--last`/`--stderr` flags to `dispatch-post-verify.sh`. Post-verify uses explicit per-run artifact paths rather than `latest.*` symlinks, eliminating the race where a concurrent second dispatch overwrites `latest.*` before the first run's post-verify reads it. `latest.*` symlinks remain updated by adapters for human observation only. Regression: stale `latest.last` avoidance case + tee `PIPESTATUS` propagation case added to `scripts/test-pmctl-dispatch.sh`.
- **`install.sh` / `uninstall.sh` / `scripts/install-hooks.sh` / `scripts/uninstall-hooks.sh`** — honor an explicit `CLAUDE_HOME` env override so install/uninstall can target an alternate directory (sandbox / rehearsal) without overriding the whole `$HOME`. Previously `CLAUDE_HOME` was hardcoded to `$HOME/.claude`, and bare `$HOME/.claude` references (`.pm` dest + install manifest in install.sh; the hook `settings.json` + `statusline-chain.conf` in both install-hooks.sh and uninstall-hooks.sh; the `.pm-dispatch` removal in uninstall.sh) bypassed it — so there was no safe way to test an install without touching the real config. All destinations now derive from `CLAUDE_HOME`, passed per-call to the hook (un)install sub-scripts (not exported, so it does not leak into the `--verify` preflight's nested test installs). New `test-install.sh` cases assert an override redirects both install and uninstall, removes the override's hook wiring, and leaves a sentinel `$HOME/.claude` config untouched (CC-294).
- **`scripts/pr-gate.sh`** — pre-create gate output file (`touch "$OUTPUT_FILE"`) before emitting the `pr-gate-handover_v1` handover block; fixes silent result loss when a background `claude-executor` subagent cannot `Write` to a new file path (CC-267).
- **`scripts/pr-gate.sh`** — escape literal `$` in unquoted heredoc templates (`\$)`, `\$'`) in the brief escalation regex and self-verify grep pattern to prevent sporadic bash parse errors (CC-257 residual).
- **`adapters/codex/dispatch.sh`** — dispatch now pins pm-dispatch's own default model (the `default` alias → `gpt-5.5` via `share/model-aliases.tsv`; `gpt-5.4` fallback) instead of letting omitted `--model` inherit the host's `~/.codex/config.toml` default. Previously, hosts whose interactive codex default was `gpt-5.3-codex-spark` silently ran **pr-gate and `/pm` dispatch on the spark model** (lower context ceiling, separate usage pool) — wrong for analysis-heavy work. The reserved `dispatch.default_model` config key is now wired (precedence: `--model` flag > config > built-in `default` alias). `share/model-aliases.tsv` gains a data-backed `default → gpt-5.5` alias (the adapter references the alias, so the wire id lives in the TSV alone) plus `gpt-5.5`/`gpt-5.4` rows; `scripts/lib/handover-validate.sh` now accepts dotted wire ids so every alias is a valid handover `model:` value. `codex-spark` stays opt-in (CC-292).
- **`cli/pmctl`** — symlink resolver now handles relative symlinks via loop-based readlink resolution (CC-297, PR #218). Previously `readlink -f` (or the naive `readlink` single-call form) failed when the symlink target is a relative path and the CWD changed during codex self-snapshot bootstrap. The resolver now follows each link hop and resolves the target relative to the link's own directory, mirroring the approach in `scripts/pr-gate.sh`. Covered by new `cli-symlink-repo-root-relative` test case in `scripts/test-pmctl-guard.sh`.

### Changed

- **`commands/pm.md` + `scripts/dispatch-post-verify.sh`** — thin-`/pm` post-verify reuse (CC-059, M4's last ticket; reshaped from the obsolete "move runtime into `pm-dispatch-runner.sh`" — M0–M3 already extracted that into `scripts/lib/`, and `pm.md`'s remaining steps are main-thread tool-call orchestration that cannot live in shell). The Bash-route completion steps 4–8 (`<last>` read, stderr surface, git diff/status, `self_verify:` match) were duplicated as prose in `pm.md` while `scripts/dispatch-post-verify.sh` (CC-264b) already implemented the same logic **with tests**. `dispatch-post-verify.sh` now accepts optional `--last`/`--stderr`/`--brief-file` flags so `/pm` can post-verify the **per-run** paths parsed from the dispatch footer (race-safe; `latest.*` symlinks race across concurrent dispatches), plus `--base <ref>` so the diff evidence honors the caller-selected integration base via **merge-base (`<base>...HEAD`)** semantics — preserving `/pm`'s base-aware verification for non-`origin/main` targets and not surfacing unrelated upstream commits when the integration branch has advanced; absent flags it falls back to `latest.*` + `origin/main`, leaving the positional `<work_dir> [brief_file]` contract used by `pmctl dispatch run` + codex-executor unchanged. The `.agent-trace/` symlink-containment guard now covers flag-supplied paths too, and a flag-supplied `--stderr` is **fail-closed** (a missing supplied artifact → FAILED, signaling a broken footer parse / lost artifact) while the positional `latest.stderr` path stays optional for `pmctl dispatch run` + codex-executor. `pm.md`'s verification body collapses to one tested `dispatch-post-verify.sh` call; the JSONL `command_execution` evidence cross-check (proving each `self_verify:` item actually ran, vs. the script's final-message `cmd: pass` claim) is **retained** as an explicit main-thread step the executor-agnostic script cannot do. The flag parser also guards value-taking flags against a missing/flag-shaped value (`--last --stderr X` fails as usage, not a confusing not-found). `test-dispatch-post-verify.sh` +17 cases (override happy-path, containment rejection for `--last`/`--stderr`, nonexistent-path stop, stderr fallback, supplied-`--stderr` fail-closed, `--brief-file`, ambiguous brief, unknown flag, missing-value, flag-as-value, the full `/pm` flag-combo shape, `--base` integration-base diff with base-dependent content assertion, `--base` merge-base exclusion of an advanced upstream, `--base` HEAD fallback, and the `--` positional sentinel); 21→38, all green.
- **`docs/architecture/v0.3.0-synthesis.md` + `MILESTONES.md`** — reconciled the architecture blueprint with the as-built code after a read-only audit (CC-295). Added a **Conformance status (as-built)** section: (A) deliberate divergences now adopted as canonical — `runtime/` realized as `cli/pmctl` + `scripts/lib/*`, symmetric codex+claude adapters in v0.3.0, `pmctl` ships backlog/guard/dispatch (rest → v0.4.0), live numbering M0–M6; (B) known-open divergences documented as pending a scope decision — state single-writer rule unmet, `routing_log.md` still machine-written, `Event`/`Review`/`Decision` schema-only, `pm/` not folded into `core/`, no `mcp/README.md` / `pmctl --json`. Inline `AS-BUILT` notes added to §5.1/§6/§7. No code change.
- **`agents/claude-executor.md`** — self-verify format hardened: exact whole-line `cmd: pass` / `cmd: fail: <reason>` matching; `status:blocked` check; portable `realpath`; trace-dir symlink guard; `OK-NOBRIEF` mode for briefless runs (CC-264b).
- **`docs/executor-contract.md`** — updated with filesystem output contract details and executor `latest.last` symlink timestamp format (CC-264b).
- **`scripts/hook-save-rate-limits.sh`** — added `CLAUDE_STATUSLINE_CHAIN_ACTIVE` / `CAS_STATUSLINE_CHAIN_ACTIVE` guard to prevent infinite loop when a chain script calls back into the same hook.
- **`scripts/run-all-tests.sh`** — registered `test-dispatch-post-verify.sh` and `test-claude-executor.sh` suites (CC-264 PR B). Registered `test-pmctl-dispatch.sh`; mirrored the new suite into `test-run-all-tests.sh` (count 37→38) (CC-289).
- **`cli/pmctl`** — `dispatch run` now sources `executor-router` + `pmctl-dispatch` and routes to `pmctl_dispatch_run`; the legacy stub is removed (CC-289).
- **`scripts/lib/executor-router.sh`** — `dispatch_via_codex` now emits the canonical `adapters/codex/dispatch.sh` path instead of the legacy `scripts/codex-dispatch.sh` shim, so internal callers depend on the real adapter and shim removal touches no internal call sites (CC-289).
- **`adapters/claude/isolation-map.yaml`** — filled the previously no-op map with a real claude schema: `isolation_level → claude --permission-mode` (none→bypassPermissions, read-only→default, workspace-write/network/sandboxed→acceptEdits). Verified empirically that headless `claude -p` honors these (acceptEdits edits; default denies writes with no approver) (CC-266).
- **`scripts/run-all-tests.sh` + `scripts/test-run-all-tests.sh` + `.github/workflows/lint.yml`** — registered `test-claude-dispatch.sh` (suite count 38→39; dedicated CI job; added to shellcheck `ignore_names` as a sourcing test) (CC-266).
- **`scripts/run-all-tests.sh` + `scripts/test-run-all-tests.sh` + `.github/workflows/lint.yml`** — registered `test-layer-boundaries.sh` (suite count 39→40; dedicated CI job; shellcheck `ignore_names`) (CC-233).
- **`scripts/test-pmctl-dispatch.sh`** — config coverage at pmctl layer (CC-293, PR #216): config timeout exported to codex adapter, config timeout exported to claude adapter, config model exported, caller `--model` beats config, malformed config warns + fallback, `--timeout` flag forwarded by pmctl beats config-exported `PM_CFG_TIMEOUT`. Full precedence chain (`--timeout` flag > adapter env > pmctl config > 1200) verified end-to-end.
- **`scripts/lib/state-writer.sh` `sw_append_dispatch_run`** — new shared run-row builder (CC-305, PR #216). Centralizes state-store dispatch run-row construction (schema_version, executor, task_id, model, timestamps, paths); `adapters/codex/dispatch.sh` and `adapters/claude/dispatch.sh` each replace ~50 LOC of duplicated jq blocks with a single `sw_append_dispatch_run` call. `sw_extract_task_id` helper added alongside it.
- **`scripts/lib/pmctl-fs.sh` `pmctl_validate_adapter_name`** — adapter name regex aligned to `^[a-z][a-z0-9_-]*$` (was `^[a-z][a-z0-9-]*$`, missing underscore; now matches docs and `docs/spikes/cc215-adapter-generate-codex-plan.md`) (CC-305, PR #216).
- **`scripts/test-claude-dispatch.sh`** — 2 cases: `CLAUDE_DISPATCH_TIMEOUT` env sets adapter timeout (adapter-level direct invocation); state-store `executor:"claude"` + task_id row. Config-precedence coverage moved to pmctl suite (CC-293, PR #216).
- **`pmctl adapter generate`** — now scaffolds an executable `dispatch.sh` stub (added to `generated_files`) alongside `run.sh`, so a generated adapter is reachable through `pmctl dispatch run` and fails loudly until wired rather than tripping "unknown adapter"; generated README documents the two-script structure + allowlist registration (CC-289, addressing gate feedback).
- **`adapters/codex/dispatch.sh`** — alias/isolation-map fallbacks gained a repo-source-layout (`../../`) tier so resolution holds if the self-snapshot bootstrap is bypassed in the relocated path (CC-289).
- **`scripts/test-pmctl-adapter-generate.sh`** — fixture now carries the dispatch orchestrator libs; the "reaches dispatch route" case asserts the real orchestrator is reached rather than the old stub message (CC-289).
- **`scripts/lib/state-writer.sh` `_sw_project_key()`** — replaces raw `sha1sum` call with `_portable_sha1()`; hash failures now log via `_sw_log_error` and fall back to `global` partition (CC-263).
- **`core/README.md`** and **`agents/project-pm.md`** — removed v0.3.x forward-reference language now that M1 is shipped; prose updated to present tense (CC-261).
- **`scripts/test-test-harness.sh`** — removed dead `assert_contains()` definition (never called; file uses own `pass_case`/`fail_case` framework for cyclic-test-vs-SUT reasons). Added header comment documenting the framework choice (CC-256).
- **`scripts/test-run-all-tests.sh`** — added comment above local `assert_contains()` explaining why it stays local: orchestrator uses `pass_case`/`fail_case`, not the unified harness counters (CC-256).
- **BACKLOG** — closed CC-254 (harness assert_* no auto-pass; shipped PR #149) and CC-256 (3-file assert_* migration audit; completed).
- **`.gate-briefs/` brief filenames runtime-neutral** — gate brief files are renamed to the pattern `brief-<uuid>.md` (was `codex-brief-<uuid>.md`) so the same artifact structure works for both codex and claude executor routes (CC-298, PR #215). The executor is recorded in the brief's YAML frontmatter (`executor:` field) rather than the filename. All downstream consumers that previously grepped for `codex-brief-` updated to the new pattern.
- **`commands/pm.md`** — dispatch routes unified through `pmctl dispatch run --adapter codex|claude` (CC-299, PR #213). The codex path previously bypassed the `pmctl dispatch run` orchestrator for the claude host-as-PM case; now both routes use the runtime layer consistently, so guard + brief-validate + post-verify are enforced regardless of which host is running. `Agent(executor)` is retained as an Agent-spawn optimization for the same-Claude-host path; `pmctl dispatch run --adapter claude` is the canonical host-independent route.

### Deprecated

> Sunset target: **v0.5.0** — these were kept through v0.3.0 + v0.4.0 (two official releases) and **removed in v0.5.0** (CC-296).

- **`pmctl guard check --profile <pm|codex|claude>`** — superseded by `--role <pm|executor>` + `--runtime <codex|claude>` (CC-291). Was accepted as a back-compat alias; removed in v0.5.0.
- **`scripts/codex-dispatch.sh` compatibility exec wrapper** — the real adapter is `adapters/codex/dispatch.sh` (CC-289). Was a thin exec-wrapper for external callers; removed in v0.5.0.

### Removed

- **`/caveman` slash command (`commands/caveman.md`)** -- token-compression skill removed; text compression causes information loss in design/architecture discussions where omitted constraints lead to misunderstandings (CC-265).
- **`/caveman-commit` slash command (`commands/caveman-commit.md`)** -- removed alongside `/caveman` (CC-265).

### Test coverage

- `test-dispatch-post-verify.sh` — 38 cases (21 from CC-264 PR B; +17 from CC-059 flag/base coverage); see `scripts/test-dispatch-post-verify.sh`.
- `test-claude-executor.sh` — 5 cases (CC-264b); see `scripts/test-claude-executor.sh`.
- `test-state-store.sh case_project_key_no_sha1sum` — stubs both sha1sum and shasum, asserts _sw_project_key returns `global` non-fatally (CC-263).
- `test-usage-tracker.sh missing_type_defaults_to_unknown` — regression case for entries missing `type` field (CC-104t, PR #220).

### Windows compatibility + Python removal (CC-308/CC-104t, PR #220)

- **`scripts/codex-dispatch.sh`** — converted from Git-stored symlink to real exec wrapper. On Windows, Git stores symlinks as plain-text files containing the target path; copy-mode install then copies that text, causing `No such file or directory` at runtime. The exec wrapper resolves `$SELF_DIR/../adapters/codex/dispatch.sh` and works both in-repo (dev) and from the installed `~/.claude/scripts/` location (CC-308).
- **`install.sh`** — `adapters/` is now installed as a first-class directory (junction on Windows, per-file symlinks on Linux/macOS). Required so the `codex-dispatch.sh` exec wrapper can resolve `~/.claude/adapters/codex/dispatch.sh` from the installed location (CC-308).
- **`scripts/test-pr-gate.sh`** — adds Windows Git Bash platform skips for three tests that rely on POSIX features unavailable without Developer Mode: `via-symlink` (ln -s), `pre-gate-hook-not-executable`, `post-gate-hook-not-executable` (chmod -x) (CC-308).
- **`scripts/token-usage.sh`** — full rewrite in pure bash+jq, eliminating the 246-line embedded Python analytics script. Implements time-window filtering (`--today`/`--all`/`--Nh`) via `fromdateiso8601`, JSONL parsing with malformed-line tolerance (missing-`type` entries default to `unknown`), token aggregation by pool, calibration + rate-limits reading, divergence warning (>10% diff), rate/ETA estimation, and by-type/by-session breakdown. No `python3` dependency (CC-104t).
- **`adapters/codex/dispatch.sh`** — `python3` JSONL token-count parser replaced with `jq -rs 'first(…)'` (CC-104t).
- **`scripts/test-codex-dispatch.sh`** — mirrors the jq expression in the token-count regression test (CC-104t).
- **`scripts/test-pmctl-guard.sh`** — `python3 os.path.relpath` replaced with a pure bash `_bash_relpath` function for the relative-symlink test case (CC-104t).
- **`scripts/test-check-docs-freshness.sh`** — `python3` JSON-line validation replaced with `jq -rs '.'` (CC-104t).
- **`scripts/test-usage-tracker.sh`** — four `python3` JSON fixture writes replaced with `jq -n --argjson ts` (CC-104t).
- **`scripts/test-hooks.sh`** — `python3` mtime fallback removed from `_set_mtime_secs_ago`; `perl` only (CC-104t).

## [0.2.0] — 2026-05-22

**Theme**: Cross-platform operations, environment health tooling, and schema improvements.

### Added

- **`scripts/doctor.sh`** — install environment health check: verifies `claude`/`jq` on PATH, hooks wired in `settings.json`, memory dir present, scripts executable, frontmatter lint clean. Accepts `--profile minimal|full|auto`; each failing check prints a concrete remediation step. Wired into `install.sh` post-install and `scripts/run-all-tests.sh` (CC-058).
- **`scripts/run-all-tests.sh`** — standalone test aggregator that runs all per-subsystem suites and produces a single pass/fail summary; replaces `install.sh --verify` as the canonical health check tool (CC-104n).
- **`scripts/lib/portable.sh` `serialize_with_lock()`** — cross-platform locking shim: prefers `flock` when available, falls back to `mkdir_lock`. Eliminates `flock` hard-dependency on Windows Git Bash (CC-104p).
- **`uninstall.sh`** — manifest-driven uninstall removes only files recorded in the install manifest; safety guard rejects dst not strictly under the managed root.
- **`install.sh` copy-mode refresh semantics** — re-running `install.sh` now compares `sha256(src)` vs `sha256(dst)` directly; only changed files are re-copied (CC-221).
- **`install.sh` jq prerequisite check** — jq is checked at the top of the installer before any tests run; error includes a platform-aware install hint (CC-104l).
- **`install.sh` copy-mode banner** — when files were installed via copy fallback, a summary banner at the end reminds the user to re-run after source edits (CC-104v).
- **pm-schema v1.1** — BACKLOG index table adds `Priority` (P1/P2/P3) and `Epic` columns; `pm/scripts/validate.sh` and `pm/scripts/rollup.sh` updated (CC-052).
- **pm-schema v1.2** — adds `design` and `spike` epic enum values; validator and rollup updated (CC-104/CC-205).
- **`DECISIONS.md`** — repo-level architectural decision log; `validate.sh` guards that referenced IDs exist (CC-067).
- **`CONTRIBUTING.md`** + **`CODE_OF_CONDUCT.md`** — source-available contributor guidelines + Contributor Covenant 2.1 (CC-031).
- **`commands/skill-refine.md`** Prerequisites section documenting `CLAUDE_MEMORY_DIR` requirement (CC-025b).
- **`scripts/test-commands.sh`** — contract-lint CI test for `pre-impl.md` Q4 contract and agent output-brevity contract; wired into `lint.yml` `test-commands` job (CC-039/CC-053). `/caveman` and `/caveman-commit` contracts were removed in CC-265.

### Changed

- **`scripts/lint-frontmatter.sh`** — complete YAML flow-collection validation matching PyYAML semantics: dq escape whitelist, adjacent-quote detection, tab-indented list item rejection, and empty-entry check (`[foo,,bar]`). Covers all four collection paths (key-level `[...]` / `{...}`, list-item `[...]` / `{...}`). Regression suite expanded from 35 to 68 test cases (CC-056/CC-058).
- **Hook scripts** — rewrote `hook-log-claude-usage.sh`, `hook-inject-memory.sh`, `hook-session-summary.sh`, and `hook-save-rate-limits.sh` from python3 to jq. Eliminates python3 as a runtime dependency; fixes Windows Git Bash failures caused by the Microsoft Store python3 stub (CC-104t).
- **`install.sh`** — `link_or_copy()` now detects real-directory dst conflict before attempting `ln -s` (CC-104u); on Windows Git Bash, managed directories (`agents/`, `commands/`, etc.) are created as PowerShell directory junctions so they auto-sync after `git pull` (CC-207).
- **`hook-routing-log.sh`** — replaced `flock`/fd9 pattern with `serialize_with_lock()` portable shim (CC-104p).
- **`pm/scripts/validate.sh`** — bidirectional Index ↔ Section consistency check; CHANGELOG drift detection (CC-030/CC-046).
- **`agents/project-pm.md`** Rule B — added point 5 (next-layer sweep) to NO-GO fix-loop protocol; added contract-test rule to brief-writing section (CC-039).
- **`commands/pre-impl.md`** — added Q4 (contract test completeness) to Step 2 (CC-039).

### Fixed

- `hook-routing-log.sh` row-loss on Windows: `flock` is Linux-only; `serialize_with_lock()` shim restores concurrent-safe appends on Git Bash (CC-104p).
- `install.sh` copy-mode idempotency: stale copies were not refreshed on re-install because sha comparison used the old manifest hash instead of comparing src vs dst directly (CC-221).

### Known limitations

- macOS is documented but not dogfood-tested. Install code path is the same as Linux; report issues via GitHub Issues.
- Windows Git Bash: individual `scripts/*.sh` helper files are still installed via copy (not junction); re-run `bash install.sh` after pulling to refresh changed copies.
- `CC-200..CC-204` reuse-debt items deferred: shared executor-router, profile-detect shim, handover validator framework, test-harness lib, hook framework.

### Test coverage

Added since v0.1.0:
- 68 lint-frontmatter regression cases (was 35)
- 32 doctor health-check cases
- 23 run-all-tests aggregator cases
- Additional install/uninstall/portable cases

## [0.1.0] — 2026-05-17

First public release. The repo was made source-available (public read/fork; external PRs not accepted at this time). This release bundles the **CC-OSS** epic that prepared the codebase for that transition.

### Added
- **`agents/claude-executor.md`** — second concrete executor (alongside `codex-executor`) so the repo runs without the Codex CLI. The five reviewer agents (critic / qa-tester / architecture-reviewer / security-reviewer / risk-reviewer) were always Claude-native; codex was only the runner wrapper.
- **`install.sh --profile minimal|full`** — install profile flag. `minimal` skips the codex-only guard hooks; `full` wires every hook. Auto-detect when unset: `command -v codex` present → `full`, else `minimal`.
- **`scripts/lib/portable.sh`** — cross-platform shim: `realpath_m()` / `safe_tmpdir()` / `mkdir_lock()` (replaces `flock`) / `detect_platform()` / `file_size_bytes()` (GNU/BSD/`wc -c` fallback). Makes Windows Git Bash + macOS + Linux uniform.
- **`scripts/codex-dispatch.sh` `--model` alias mapping** — PM-facing short alias `codex-spark` resolves to wire-format `gpt-5.3-codex-spark` + reasoning effort `high`; unknown aliases fall through unchanged.
- **`/pr-gate` `--executor codex|claude|auto`** — gate orchestration mirrors the `/pm` executor split; minimal-profile users can run the gate via main-thread `Agent()` calls. New `pr-gate-handover_v1` fenced schema for claude-mode reviewer fan-out.
- **`docs/executor-contract.md`** — abstract executor interface (input / output / profiles / forward-compat).
- **`docs/pr-gate-handover-schema.md`** — handover schema for the `/pr-gate` claude path.
- **`docs/platform-support.md`** — Linux/macOS/WSL2 first-class; Windows Git Bash + minimal profile supported; install dependency table.
- **`docs/GETTING_STARTED.md`** — clone → install → first `/pm` walkthrough for new readers.
- **`docs/CONCEPTS.md`** — explains the four Claude Code extensibility surfaces (hooks-as-policy / slash commands / subagents / memory tiers) with a worked `/pm` example.
- **`docs/memory-system.md`** — memory dir layout + four tiers + bootstrap-empty pattern.
- **`CONTRIBUTING.md`** + **`CODE_OF_CONDUCT.md`** — source-available stance + Contributor Covenant 2.1.
- **`commands/skill-refine.md`** (CC-025) — `/skill-refine <skill-name>` slash command wraps `scripts/skill-refine.sh` feedback-signal bundler.
- **`commands/*.md`** — `## What / ## When to use / ## Example` sections on 7 commands (mem-distill / mem-log / mem-recall / mem-search / memory-compress / pre-impl / skill-refine).

### Changed
- All hardcoded `/home/<user>/github/pm-dispatch` paths in production docs/agents/commands replaced with `${PM_DISPATCH_REPO}` placeholder; `install-hooks.sh` auto-derives it from `git rev-parse --show-toplevel` when unset.
- README intro reframed for first-time public readers (source-available stance + top-of-file links to `GETTING_STARTED.md` and `CONCEPTS.md`).
- `scripts/codex-pr-gate.sh` renamed to `scripts/pr-gate.sh`; `scripts/test-codex-pr-gate.sh` renamed to `scripts/test-pr-gate.sh`.
- `commands/codex-pr-gate.md` and `commands/pr-gate.md` merged into a single `commands/pr-gate.md` that invokes `scripts/pr-gate.sh`; the old Agent-subagent approach is replaced by the script's `--parallel` mode.
- `scripts/lib/handover-validate.sh` `executor` enum opens from `{codex}` to `{codex, claude}`; codex-only metadata fields (`sandbox`/`approval`/`skip_git_check`) remain required for schema stability but are accepted-as-no-op by `claude`.
- `scripts/hook-routing-log.sh` `flock` + fd9 pattern replaced by `mkdir_lock`; audit message strings preserved verbatim for log compatibility.

### Fixed
- `scripts/hook-routing-log.sh` rotation: `stat -c %s` was Linux-only and silently no-op'd on macOS/BSD (rotation never triggered). Now uses `file_size_bytes()` shim (GNU stat → BSD stat → `wc -c` fallback).

### Known limitations
- Codex CLI not validated on Windows; `--profile full` falls back to `minimal` automatically on Windows with a stderr warning.
- External PRs are not accepted at this time. Issues are welcome but have no SLA. See `CONTRIBUTING.md`.
- `CC-200..CC-204` are surfaced architectural reuse-debt items deferred to post-release: shared executor-router, profile-detect shim, handover validator framework, test-harness shared lib, hook framework.

### Test coverage
- 299 hook regression cases
- 16 codex-dispatch cases (CC-047 model alias mapping)
- 63 dispatch-handover schema cases
- 43 install / profile cases
- 4 claude-executor cases
- 15 portable shim cases
- 41 pr-gate cases
- 9 pr-gate-profile (executor split) cases
- **Total: 490 cases**, plus `lint-scripts` (37 files) and `lint-agents` (8 agents).

### Added
- `scripts/hook-routing-log.sh` (CC-028): PostToolUse hook that auto-appends one
  JSONL row per Brief/Dispatch routing decision to the active project's
  `routing_log.md` (inside a marker-fenced auto-block); triggers on Bash
  `codex-dispatch.sh` invocations and Agent dispatches whose `subagent_type` is
  `codex-executor` (or aliases). Mirrors CC-027's `hook-tool-trace.sh` design
  family — metadata-only, non-blocking, multi-path JSON hedge, single-archive
  1 MiB rotation. `q_hit` / `second_thoughts` fields stay null at hook time;
  post-classification deferred to a future `/routing-distill`.
- `scripts/migrate-routing-log.sh` (CC-028): one-time migrator invoked by
  `install-hooks.sh` on first wire-in; converts existing free-form bullet
  sections in `routing_log.md` into JSONL rows inside the new auto-block,
  preserves the legacy markdown table byte-for-byte, writes a
  `routing_log.md.bak` atomic backup before any modification.
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
