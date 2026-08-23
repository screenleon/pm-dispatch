# pm-dispatch Review Model

## The core idea: Relocating Rigor

Traditional code review puts rigor in the middle of the pipeline — a human (or AI) reads every changed line after the code is written. pm-dispatch relocates that rigor to the two ends:

- **Upstream**: confirm intention and boundaries *before* the agent starts writing anything.
- **Downstream**: machine-verify postconditions *after* the agent finishes, independent of session context.

The middle — line-by-line diff inspection — becomes an exception rather than the default. It fires only when the upstream check was skipped, when a reviewer flags a structural concern, or when the machine check fails and the cause is not obvious.

---

## The four layers

```
┌─────────────────────────────────────────────────────────────────────┐
│ Layer 1 — Intention & Spec review          (before dispatch)        │
│   What are we solving? What's out of scope? What's the boundary?    │
├─────────────────────────────────────────────────────────────────────┤
│ Layer 2 — Cross-Context Isolation          (pr-gate reviewers)      │
│   Clean sessions read the final product; no dispatch-session bias   │
├─────────────────────────────────────────────────────────────────────┤
│ Layer 3 — Conceptual Map review            (architecture lens)      │
│   Does the structure make sense? Boundaries respected? Map vs diff? │
├─────────────────────────────────────────────────────────────────────┤
│ Layer 4 — Machine Verification             (after gate)             │
│   self_verify cmd: runs postconditions; pass = done, fail = reopen  │
└─────────────────────────────────────────────────────────────────────┘
```

### Layer 1 — Intention & Spec review

**When**: before writing a dispatch brief for any task where `behavioral_units ≥ 3` or `architecture_impact ≠ none` — any change touching a shared module, crossing a layer boundary, or introducing a new interface or schema field.

**Mechanism**: `/pre-impl "<task description>"` — produces a **structured pre-impl artifact** with six fixed sections: Intention, Non-goals, Bounded Context, Conceptual Map, Acceptance Metrics, Verification Plan. Paste the `Conceptual Map` section into the brief's `conceptual_map:` field and the design constraint list into `constraints:`.

The point is not to produce documentation — it is to catch a wrong direction before any code is written. A five-minute pre-impl that reveals a scope disagreement saves a multi-round gate cycle.

### Layer 2 — Cross-Context Isolation

**When**: after the executor finishes; triggered by `/pr-gate`.

**Mechanism**: `/pr-gate` runs its reviewers (`critic`, `qa-tester`, `security-reviewer`, `risk-reviewer`, `architecture-reviewer`) in a review session *separate from the one that produced the diff*. Each reviewer receives a brief with the diff, task context, and (if present) the conceptual map — but not the dispatch session's reasoning, prior attempts, or implicit anchors. A sequential gate runs the reviewers together in one fresh session (codex or Claude, per `--executor`); the parallel path gives each reviewer its own independent session followed by a PM synthesis pass. An explicit user choice wins; when mode is omitted, policy selects its recommendation.

This isolation matters because context-window anchoring is real: a reviewer who watched the code being written will tend to evaluate the approach rather than the outcome. A reviewer who arrives at the finished diff cold asks "does this make sense in isolation?" — a harder and more valuable question.

The isolation *from the dispatch session* is structural, not advisory: the review session is a separate process and cannot read the implementer's context. Per-reviewer independence — each reviewer also blind to the others — is provided by the parallel path; sequential mode trades that for a single combined review session. See [pr-gate-handover-schema.md](pr-gate-handover-schema.md) for the handover protocol.

### Layer 3 — Conceptual Map review

**When**: as part of the Layer 2 gate; specifically the `architecture-reviewer` subagent's role.

**Mechanism**: the architecture-reviewer reads `conceptual_map` first — a plain-text description of the proposed structure — and verifies layer boundaries and module ownership from the map. Source file inspection is used **selectively**: when the map and diff disagree, when a specific risk surface warrants a spot check, when `architecture_impact` is `major`, or when the map is silent on a boundary the diff crosses.

This distinguishes the architecture-reviewer's role as **Architect / Editor** rather than inspector. The aim is to evaluate structural correctness from a ten-line conceptual map without scanning 300 changed lines to form a layer-boundary opinion.

When `conceptual_map` is absent, the architecture-reviewer falls back to diff inspection and notes the absence in its findings — the fallback is slower, noisier, and more likely to produce false-positive findings.

### Layer 4 — Machine Verification

**When**: at the end of every executor run; the executor itself evaluates `self_verify` before declaring done.

**Mechanism**: the `self_verify:` block in a dispatch brief contains one or more postcondition checks. Items tagged `cmd:` are shell commands the executor runs; a non-zero exit means the task is *not* done, regardless of what the diff looks like. The outer dispatcher then re-checks `acceptance:` from outside the executor.

```
self_verify:
  - cmd: "bash tools/lint/lint-agents.sh"
  - cmd: "bash tests/shell/test-run-all-tests.sh"
  - git-status no-collateral-damage    # executor-evaluated (not a shell cmd)
```

The pairing matters:

| Field | Evaluated by | Purpose |
|---|---|---|
| `self_verify cmd:` | executor (inside) | prove done before returning |
| `acceptance:` | main thread / post-verify (outside) | contract from the brief author's perspective |

If machine verification passes, the task is done. If it fails, it re-opens. This replaces "looks good to me after a quick scan" with a reproducible binary signal.

---

## How the layers interact

```
/pre-impl → dispatch brief → executor → affected tests → refactor/reuse audit
    L1            L1               L4       fast feedback       maintainer policy
        → /pr-gate → full suite → PR
           L2+L3+L4   final verify
```

A typical task flows left to right. Each arrow is a checkpoint; a failure at any checkpoint stops forward motion rather than producing a bad merge.

The refactor/reuse audit is a maintainer checkpoint after the main
implementation, not another generic gate layer. It inspects the actual diff and
nearby helpers/call sites for behavior-preserving simplification, consolidation,
and reuse before cross-context review. Run it once before the first PR gate.

After gate remediation, structural or scope-unclear fixes repeat the audit;
localized fixes that preserve the architecture may skip it with a recorded
reason. [`/ship` Step 3](../commands/ship.md#step-3--gate-loop) is the
authoritative operational threshold. This keeps the cheap maintenance pass
ahead of expensive review without duplicating the full rule across documents.

The affected-test planner (`tests/bin/run-tests.sh`) is the iteration path before
and between gate rounds. The authoritative `tests/bin/run-all-tests.sh` runs only
after a GO verdict against the final tree. A diff-caused full-suite fix returns
through affected tests and targeted review before the full suite is repeated.

### Gate model diversity

Select the PR-gate model by comparing it with the **actual primary
implementation model family**, not with a host or adapter label. OpenCode can
run Claude, OpenAI, Gemini, and other model families, and executor routes may
accept an explicit `--model`; therefore host names are not reliable model
identifiers.

Prefer an available gate model from a different family than the model that
produced the primary diff. For mixed-model implementation, prefer a family not
responsible for the primary change. An explicit user selection wins. Use the
same resolved executor/model pair for targeted re-runs.

If no alternate family is available, a same-family gate is allowed only when
the handoff records the implementation model, resolved gate model, and fallback
reason. The PR description records both model identities so this best-effort
selection remains reviewable.

For small tasks (`behavioral_units < 3` and `architecture_impact: none`), Layer 1 may be skipped and Layer 3 is lightweight. For tasks with architecture impact, all four layers are active and Layer 3 gets a full conceptual map as input.

### Evidence chain

Each layer produces an artifact that the next layer consumes. This is not abstract philosophy — every arrow carries a concrete handoff:

| Layer | Input | Artifact produced | Consumed by |
|---|---|---|---|
| Layer 1 | task request | `/pre-impl` sections: Conceptual Map + design constraints | brief `conceptual_map:` + `constraints:` fields |
| Layer 2 | final diff + handover brief | isolated reviewer findings (critic / qa / security / risk) | pr-gate synthesis |
| Layer 3 | `conceptual_map` + diff | architecture finding (map vs. diff alignment) | pr-gate synthesis |
| Layer 4 | `self_verify cmd:` entries | command exit codes (pass / fail) | PM / merger decision |

When an artifact is missing — no `conceptual_map`, no `self_verify cmd:`, no isolated review — the downstream consumer degrades or falls back. The four-layer model produces a reliable signal only when the full chain is intact.

---

## pr-gate assurance coordinates

The gate resolves one canonical policy result from the complete diff
classification, trusted brief metadata, requested coordinates, consumer policy,
and any explicit scope-bound downgrade authorization. `--tier` requests a
**rigor level**; it cannot silently lower the resolver's minimum floor.

| Tier | When | Default reviewer coverage |
|---|---|---|
| `express` | docs-only or bounded low-blast-radius change | critic + qa |
| `standard` | medium/binary/cross-boundary change, `architecture_impact: minor` | critic + qa + architecture-reviewer |
| `full` | large change or `architecture_impact: major` | critic + qa + architecture-reviewer + security + risk |

Sensitive paths add the corresponding security, risk, or architecture reviewer
to required coverage without automatically converting every bounded change to
`full`. Trusted `architecture_impact` is an enforced policy input:
`minor` establishes a `standard` floor and `major` establishes a `full` floor.

**Tier, mode, pass kind, and coverage are independent**:

- Tier records rigor intent and supplies default reviewer coverage only when
  coverage is omitted. An explicit `--reviewers` list never rewrites tier, but
  it must still include risk-derived required reviewers unless a scope-bound
  user policy override records an approved omission. Maintainer publication
  policy remains stricter.
- Mode records execution topology and remains a user-owned cost/independence
  choice. When mode is omitted, policy auto-selects its recommendation from the
  consumer and matched signals. Explicit `--mode sequential` or
  `--mode parallel` always wins; the envelope records recommendation divergence
  without treating it as a downgrade. A `full` tier does not force parallel.
- Pass kind records whether the review is initial or a remediation-delta
  targeted pass. The canonical spelling is `--pass targeted --reviewers
  <reviewers> --initial-result <path>`; it is not a tier alias. The legacy
  `--targeted <reviewers>` shorthand expands to those same pass and coverage
  coordinates. Mixed canonical/shorthand input is accepted only when both
  request the same pass and reviewer set, and the assurance sidecar records
  the spelling provenance. The initial artifact is remediation context only:
  every targeted pass resolves its tier from the current subject and policy,
  even when its content overlaps a prior gate. Tier and coverage selection
  bases are recorded independently.

The generic consumer preserves an explicit coverage choice only when it keeps
all risk-derived required reviewers (or a scope-bound override authorizes an
omission). The maintainer
`/ship` initial pass fixes coverage at all five reviewer dimensions while
preserving the independently resolved tier and mode. Targeted passes under
either consumer remain scoped to the requested remediation reviewers and do
not satisfy a comprehensive-review consumer.

Producer policy names are assurance strategies, not identities. Applicability
uses this compatibility contract:

| Verifier consumer | Minimum policy | Preferred policy | Accepted producer policy |
|---|---|---|---|
| `embedded` | artifact policy | artifact policy | exact artifact policy |
| `generic` | `generic` | `generic` | `generic` or `maintainer` |
| `maintainer` | `maintainer` | `maintainer` | `maintainer` only |
| `publish` | `generic` | `maintainer` | `generic` or `maintainer` |

The policy axis records `required_policy`, `preferred_policy`,
`embedded_policy`, and `policy_satisfaction`. A generic initial GO therefore
satisfies publish as `baseline`; a maintainer initial GO satisfies it as
`preferred`. Missing a preference is not an applicability failure. Falling
below the required minimum remains a failure. Publish compatibility does not
change either producer's tier, reviewer floor, or mode recommendation.

Any requested tier or coverage below the policy floor fails before reviewer
dispatch. A tier/coverage downgrade is accepted only through an explicitly
supplied `gate_policy_override_v1` JSON file bound to the exact scope fingerprint
and recording user approval. Mode is not a downgrade coordinate: explicit user
selection needs no override. The fingerprint includes the content-addressed
tracked patch and every in-scope untracked file, not only file names or aggregate
line counts. The free-form `.gate-overrides.md` file remains reviewer
finding/suppression context; it is recorded separately and cannot authorize a
policy downgrade.

The reviewer-override channel accepts only readable, non-empty, NUL-free regular
files whose final path component is not a symlink, including dangling symlinks.
`.gate-overrides.md` is discovered at the physical workspace root; explicit
relative `--override-file` paths are based at `--cd`. Legacy symlink, empty,
unreadable, non-regular, and NUL-containing override paths now fail before
reviewer dispatch. On Linux and WSL2 the gate validates identity and content
around a private snapshot, and uses that accepted snapshot—not a later source
reread—for briefs and recorded provenance. This bounded check does not claim
protection against a malicious concurrent writer using the same OS uid.

The portable policy sources are
[`core/policy/gate-tiers.tsv`](../core/policy/gate-tiers.tsv),
[`core/policy/gate-modes.tsv`](../core/policy/gate-modes.tsv), and
[`core/policy/gate-pass-kinds.tsv`](../core/policy/gate-pass-kinds.tsv), plus
the consumer and risk-signal tables
[`core/policy/gate-policy-consumers.tsv`](../core/policy/gate-policy-consumers.tsv)
and
[`core/policy/gate-policy-signals.tsv`](../core/policy/gate-policy-signals.tsv).
Changes under `core/policy/` are themselves a full-tier signal with
architecture, security, and risk coverage, so the governance tables cannot
quietly lower their own future review floor through a small edit.

After reviewer dispatch completes, the current producer writes
`pr_gate_result_v5` Markdown plus a sibling `gate_assurance_v3` JSON envelope.
Historical v4 results remain readable under the earlier synthesis contract.
Historical v3 assurance envelopes written before `selection_basis` was added
remain readable only when both selection-basis fields are absent; current v3
producers emit both fields, and a partial or contradictory claim is invalid.
A pre-dispatch fail-fast route has no reviewer protocol and intentionally
remains `pr_gate_result_v2`. The Markdown contains human findings and a bounded
relative `gate_assurance` pointer; the shell-owned envelope records
requested/resolved coordinates, independent tier/coverage selection bases,
selected/skipped coverage, actual dispatch
outcomes, run IDs, and the evidence status behind independence claims. The v3
envelope adds an immutable subject: stable Git common-directory repository
identity, optional remote identity, provenance-only observed root, base/head
refs and commits, tree fingerprint, subject kind, dirty policy, and
created/finished observations. It links preflight evidence and a
`gate_scope_manifest_v1` by digest; closure evidence remains explicitly
unavailable until that producer exists. Envelopes also embed the canonical
policy result:
classification facts, every matched signal and path, minimum tier, required
coverage, recommended mode, whether policy or the user selected the mode,
recommendation divergence, enforcement status, and both policy-override and
reviewer-override provenance. Repo-layout results with
verified independence also carry
a shell-owned attestation in the protected gate run directory.

Before any reviewer dispatch, the producer creates one manifest bound to that
immutable subject. It records the complete changed-path set (including rename
origins/destinations and in-scope untracked files), zero-context diff hunk
ranges, conventional paired tests, matched sensitive-path signals, and
public-interface/schema/config/install/CI/release/migration flags. It also adds
bounded same-stem peers, symbol call-site hints, and direct shared-helper
consumers. Every expansion entry states its reason, source, evidence kind, and
limit; the manifest explicitly says this is not a complete call graph.

Symbol hints are selected by the changed file's language before any search
budget is applied. Candidate call sites must use a compatible source language;
foreign-language snippets embedded in a file cannot become symbols for that
file. Shell functions are file-local unless another shell script directly
references the defining script, so shell call-site hints are limited to those
direct consumers. This keeps generic names such as `usage` from expanding to
unrelated scripts while preserving fail-closed behavior when a semantically
eligible query really exceeds its declared budget. Consumer content checks read
the complete snapshot before deciding a match; they do not use an
early-terminating pipeline that could turn an upstream SIGPIPE into a
subject-identical but narrower manifest.

The manifest publishes its budgets, omitted counts/reasons, and a canonical
content digest. Any omission makes the gate `INCOMPLETE` before reviewer
dispatch unless the operator explicitly supplies `--accept-scope-truncation`;
accepted omissions remain visible as `accepted_truncation`. Sequential,
parallel, and synthesis briefs all carry the same artifact digest, so execution
mode cannot silently change the declared review scope. The manifest is a scope
declaration, not proof that a reviewer understood or exhaustively reviewed it.

Every selected reviewer emits one fenced `gate_reviewer_result_v1` JSON object
bound to the shared scope-manifest SHA-256. Its checklist covers changed files,
paired tests, sensitive signals, explicit surface flags, and bounded expansion;
each cell is `examined`, `not_applicable`, or `uncertain`, with evidence
references and a reason. A blocker does not terminate the checklist early.
Findings carry reviewer-prefixed stable IDs, severity, hard-gate class, origin,
source path plus line or symbol, affected behavior, failure mode, minimum fix
boundary, and verification expectation. Pre-existing issues and cautions cannot
be blocking.

Current v5 reviewers also emit a non-empty `test_gaps` matrix. Each row binds an
affected behavior and contract to existing evidence, applicable happy/boundary/
negative/regression/concurrency/security/migration/rollback dimensions, a
missing test layer, scenario, oracle, failure signal, and suggested command.
Sufficient coverage is explicit as `no_gap` plus evidence; silence is not a
coverage claim. Any reviewer that finds a behavior gap records it, while
qa-tester owns the full applicable-dimension audit.

Current scope manifests include a `declared-review-reference-set` index for the
subject/base snapshots supplied to reviewers. Each entry records path, snapshot
kind, line count, and content SHA-256. Coverage references and finding sources
must use an indexed path (or the digest-verified manifest itself); line
references must be within the indexed snapshot. Nonexistent, out-of-scope, or
out-of-range references make the protocol `INCOMPLETE` before synthesis.
Legacy pre-index manifests remain readable for historical result verification.

The JSON `verdict` is the only canonical reviewer verdict. Markdown headings
are optional presentation: duplicate, missing, or differently formatted
headings do not invalidate an otherwise unique schema-complete report. The
shell validates each report before synthesis, computes GO/NO-GO from the JSON
verdicts, preserves the original reports in the final result, and verifies
their aggregate against `Final:`. Missing, duplicate, malformed, or
coverage-incomplete reports make the operation `INCOMPLETE`; they are not a
reviewer `NO-GO`. Coverage declaration calibrates what was examined and never
claims model recall or defect completeness.

The verdict vocabulary is exactly `approve`, `advise`, `block-soft`, or
`block`. Reviewer prompts map legacy `pass` and `pass-not-applicable` wording
to `approve`, and place narrative conclusions in `rationale` rather than
inventing role-specific top-level keys. Protocol failures identify the first
invalid layer as JSON, top-level/binding, coverage, finding,
evidence-reference, or verdict so a format error is not misdiagnosed as missing
coverage.

Completed reviewer routes also carry one `gate_synthesis_result_v1`. The
gate shell restores its reviewer-by-surface matrix, stable-ID inventory, and
other copied reviewer fields from the raw reviewer documents before parity
checks, so an LLM retyping those arrays cannot fail the round on typography.
Empty test-gap `existing_evidence` filled from a same-behavior finding source
is written back into the reviewer markdown before that copy. Restore logs the
fields it changed and refuses to rewrite a result whose sibling assurance
sidecar already records a protected attestation; `pmctl gate verify` never
calls it.
The findings union preserves every source field and verification expectation. Root-cause groups may consolidate presentation, but
they partition immutable finding IDs rather than replacing them.
Disagreements remain explicit; uncertainties and cautions are derived from the
original coverage statuses and finding origins. The nested
`remediation_closure_v1` document is only a pending seed, not proof that any
finding was fixed or that the final tree was re-reviewed.

For v5, synthesis additionally copies every reviewer test-gap row into one
parity-checked matrix, separates operational and user cautions, and publishes a
focused/manual/full post-fix verification plan. Focused commands are derived
exactly from gap rows, so consolidation cannot silently discard a requested
test.

The shell verifies selected/not-reviewed dimensions, coverage and finding
parity, unique IDs, exact group membership, uncertainty/caution sets, and seed
parity. Any silent drop, duplicate, malformed object, or missing verification
expectation makes synthesis `INCOMPLETE`. The fixed human sections summarize
must-fix order, advisories/cautions, coverage gaps/uncertainties, and
recommended verification without replacing the machine evidence. This proves
union completeness relative to the emitted reviewer documents; it does not
prove model recall or defect completeness.

Parallel mode provides one bounded in-operation recovery attempt for transport,
malformed-output, reviewer schema, and synthesis parity failures. Only failed
reviewer roles or synthesis are re-dispatched; validated reviewer artifacts and
the immutable subject are retained. Attempt records are written as
`gate_protocol_attempt_v1` JSONL bound to the scope digest and subject
fingerprint. Subject mismatch is stale and never retried, while valid analysis
uncertainty is preserved as evidence. Sequential combined sessions remain
fail-closed because their reviewer work is not independently addressable.

Seeded multi-gap live-model runs are evaluated separately with
`tools/eval/gate-test-gap-live-eval.sh`. The report exposes recall, range,
variance, and optional regression observations with `correctness_gate:false`;
it is deliberately outside deterministic CI correctness.

`pmctl gate verify <result> [--cd <repo>] [--consumer <name>] [--json]`
returns three independent axes:

- `artifact_valid`: result/sidecar schema, digest, and content parity;
- `subject_current`: repository, base, head, and tree freshness;
- `policy_applicable`: resolved coordinates, review evidence, consumer
  minimum/preference, and required authorization evidence.

Every axis includes stable reason codes. A copied artifact can remain valid
while lacking canonical dispatch authorization; a base advance or tree change
makes the subject stale without reclassifying the artifact as forged. Linked
worktree paths remain current when their stable Git subject is unchanged.
Default inspection preserves the historical artifact-validity exit contract;
passing `--consumer` is authorizing and requires all three axes to pass.
`gate wait` and `ship finish` consume this shared assessment rather than
grepping `Final: GO`.

The publication boundary adds one further shared artifact,
`gate_publish_assessment_v1`. It is produced only after the Gate assessment,
the immutable remediation closure, and the authoritative full-suite result
have all been verified against the same tree subject. Its policy object is
copied from the shared policy resolver, including producer policy and
`baseline|preferred` satisfaction. `ship finish` consumes this one assessment
for publication authorization; its stdout, PR body, and
`.pm-dispatch-ship-finish.json` marker must not independently recompute those
fields.

For the direct current-tree publication path, `publish` accepts a current
initial generic result as baseline and a current initial maintainer result as
preferred. A targeted result cannot authorize publication by itself. The
separate primary-review plus remediation-closure path must bind the final tree
and any required targeted confirmations before it can become an alternative
publication authorization.

Historical v3 envelopes that record `scope_manifest: unavailable` remain
artifact-readable under default inspection, but they do not satisfy a named
consumer after the scope-manifest producer is installed.

Subject verification intentionally fingerprints the complete included tree,
not only the diff. Its cost is therefore linear in tracked and included
untracked files each time a subject is finalized or verified. This is bounded
and acceptable for the current repository, but callers operating on large
monorepos should expect verification latency to scale with repository size.

Do not mutate the reviewed tree between gate finalization and `gate wait` or
`ship finish`. A formatter, test artifact, commit, or other included file write
correctly changes `subject_current` to `fail`; the consumer refuses the result
and reports the drift reason instead of silently authorizing a different tree.
Legacy result v1/v2 artifacts remain readable under their historical
contracts. Result v3 proves selected-reviewer protocol evidence; current result
v4 additionally proves synthesis union and coverage parity.
No gate result version is publication authorization by itself; `ship finish`
requires a current, applicable gate-assurance v3 assessment plus a verified
`gate_publish_assessment_v1` containing the authoritative current-tree
full-suite evidence and publication guards.
Without `--gate-result`, finish produces a fresh preferred maintainer result.
With an explicit `--gate-result <artifact>`, it reuses that result only after
publish-consumer verification; it never guesses a latest artifact.

The producer publishes the sidecar before atomically replacing the
self-contained staging v1 result with the bound result that references it, so
interruption cannot strand a result with a missing sidecar. A completed
selected-reviewer route becomes result v4; historical reviewer-only result v3
remains readable, and a pre-dispatch fail-fast result with no reviewer protocol
remains result v2. The protected attestation is published
afterward; verification uses a bounded retry when it observes that in-flight
canonical finalization. Legacy
`pr_gate_result_v1` and unbound `gate_assurance_v1` artifacts remain
structurally readable, but verification reports `assurance: unavailable`;
consumers must not infer mode, coverage, or independence from them. Earlier
`gate_assurance_v2` envelopes without the optional policy block remain
readable for artifact inspection, but they cannot supply immutable-subject or
consumer-applicability evidence.

Executor-authored frontmatter is not allowed to choose that publication
lifecycle. Before intermediate verdict verification, the producer requires one
supported version field, rejects multiple model-authored assurance pointers,
then rewrites the document to an unbound v1 staging form and removes at most one
model-authored pointer. This means an executor that anticipates the final v4
shape cannot cause a false protocol failure merely because the shell-owned
sidecar does not exist yet. Only finalization inserts the bounded sibling
pointer and upgrades the version.

---

## When line-by-line review is appropriate

Line-by-line code inspection is not banned — it is *demoted to an exception*. Use it when:

- The upstream intention check was skipped and the diff reveals an approach that seems wrong.
- A Layer 2 or Layer 3 reviewer flags a specific structural concern and the conceptual map does not resolve it.
- Machine verification fails and the root cause is not obvious from the failing command's output.
- The task was a spike or research output (no `self_verify` was possible) and the reviewer needs to evaluate reasoning quality.

In all other cases, the four-layer model gives a faster signal with less noise.

---

## Cross-references

- [docs/CONCEPTS.md](CONCEPTS.md) — the four Claude Code extensibility surfaces (hooks / slash commands / subagents / memory) that implement this model
- [docs/dispatch-brief.md](dispatch-brief.md) — the brief schema, including `self_verify`, `acceptance`, `conceptual_map`, and `architecture_impact` fields
- [docs/pr-gate-handover-schema.md](pr-gate-handover-schema.md) — the handover protocol that enforces Layer 2 isolation
- [docs/delivery-assurance-map.md](delivery-assurance-map.md) — the assurance dimensions, evidence chains, and composable delivery recipes
