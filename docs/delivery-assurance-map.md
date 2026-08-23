# Delivery assurance map

> Provenance (2026-08-24): this content reflects the shipped state of CC-511 Phase B, CC-517, CC-520-522, CC-527, and CC-529; it is the runtime-aligned finalization content pass, and the drift-ratchet mechanism from Requirement 6 is not yet implemented.

Delivery assurance is a set of orthogonal coordinates and evidence chains, not one linear mandatory workflow or a synonym for a command exiting zero. A result can be sound on one dimension while another is `not_run`, `stale`, or `incomplete`.

## The ten dimensions

| Dimension | Producer | Artifact | Consumer | Reusable across recipes? | Honest status vocabulary |
|---|---|---|---|---|---|
| tier | gate request and policy resolver | resolved gate assurance record | gate verifier and maintainer | Yes, if its subject and policy resolution remain current | pass\|fail\|not_run\|not_applicable\|stale\|incomplete |
| mode | explicit gate request or policy recommendation | resolved gate assurance record | gate executor and handoff reader | Yes, as recorded execution topology | pass\|fail\|not_run\|not_applicable\|stale\|incomplete |
| reviewer coverage | policy resolver and reviewer dispatch | reviewer findings and coverage record | gate synthesis and verifier | No; it is scoped to the reviewed subject and pass | pass\|fail\|not_run\|not_applicable\|stale\|incomplete |
| reviewer independence | gate execution topology | session topology and synthesis record | maintainer assessing review separation | No; it describes how that review was run | pass\|fail\|not_run\|not_applicable\|stale\|incomplete |
| policy classification | classifier and trusted brief metadata | resolved policy signals and classification | policy resolver and verifier | No; reclassify the current subject | pass\|fail\|not_run\|not_applicable\|stale\|incomplete |
| test coverage | affected-test planner or full-suite runner | test result artifact and coverage record | QA review and release/PR decision | Only while its tree-bound evidence is current | pass\|fail\|not_run\|not_applicable\|stale\|incomplete |
| subject freshness | artifact verifier against the current tree | freshness verification result | continuation and publish decision | No; any relevant edit can make it stale | pass\|fail\|not_run\|not_applicable\|stale\|incomplete |
| manual evidence | author and human reviewer | bounded checklist or PR-referenced artifact | reviewer and publish decision | Only if the referenced evidence still applies | pass\|fail\|not_run\|not_applicable\|stale\|incomplete |
| remediation closure | maintainer resolving gate findings | remediation record and deterministic closure decision | maintainer and PR reader | No; it closes findings for a specific reviewed change | pass\|fail\|not_run\|not_applicable\|stale\|incomplete |
| publish authorization | publish verifier and maintainer | publish-consumer verification result and PR handoff | person authorized to publish | No; it is a decision for the current subject | pass\|fail\|not_run\|not_applicable\|stale\|incomplete |

`pass` in one row never implies `pass` in every other row. In particular, a zero command exit can show a command succeeded, but it does not by itself establish reviewer coverage, freshness, manual evidence, remediation closure, or authorization.

Manual evidence is deliberately bounded: put a checklist result in the PR and reference an existing artifact such as `docs/evidence/settings-screen.png`, plus the reviewer sign-off note. This is an artifact-reference pattern only; it introduces no runner, script, or automation.

## Policy reference values

No automated lint currently verifies that these markers stay in sync with their source files — that enforcement is a tracked follow-up, not yet built.

<!-- BEGIN GENERATED: core/policy/gate-tiers.tsv -->
| tier | default_reviewers | evidence_floor |
|---|---|---|
| express | critic,qa-tester | reviewer-verdicts |
| standard | critic,qa-tester,architecture-reviewer | reviewer-verdicts |
| full | critic,qa-tester,architecture-reviewer,security-reviewer,risk-reviewer | reviewer-verdicts |
<!-- END GENERATED -->

<!-- BEGIN GENERATED: core/policy/gate-modes.tsv -->
| mode | topology | synthesis |
|---|---|---|
| sequential | combined-session | inline |
| parallel | per-reviewer-sessions | separate-session |
<!-- END GENERATED -->

<!-- BEGIN GENERATED: core/policy/gate-pass-kinds.tsv -->
| pass_kind | scope | requires_initial_result | is_default |
|---|---|---|---|
| initial | comprehensive | false | true |
| targeted | remediation-delta | true | false |
<!-- END GENERATED -->

<!-- BEGIN GENERATED: core/policy/gate-policy-consumers.tsv -->
| policy_pass | policy | pass_kind | minimum_tier | required_reviewers | recommended_mode |
|---|---|---|---|---|---|
| generic:initial | generic | initial | express | critic,qa-tester | sequential |
| generic:targeted | generic | targeted | express | none | sequential |
| maintainer:initial | maintainer | initial | express | critic,qa-tester,architecture-reviewer,security-reviewer,risk-reviewer | parallel |
| maintainer:targeted | maintainer | targeted | express | none | parallel |
<!-- END GENERATED -->

<!-- BEGIN GENERATED: core/policy/gate-policy-signals.tsv -->
| signal | match_source | pattern | minimum_tier | required_reviewers | recommended_mode |
|---|---|---|---|---|---|
| docs-only | classification | docs-only | express | none | sequential |
| bounded-runtime | classification | bounded-runtime | express | none | sequential |
| medium-change | classification | medium-change | standard | architecture-reviewer | parallel |
| large-change | classification | large-change | full | critic,qa-tester,architecture-reviewer,security-reviewer,risk-reviewer | parallel |
| binary-change | classification | binary-change | standard | architecture-reviewer | parallel |
| renamed-input | classification | renamed | express | none | sequential |
| untracked-input | classification | untracked | express | none | sequential |
| generated-input | classification | generated | express | none | sequential |
| cross-boundary | classification | cross-boundary | standard | architecture-reviewer | parallel |
| security-sensitive-path | path-regex | (^|[/_.-])(auth|oauth|jwt|sessions?|secrets?|passwords?|tokens?|credentials?|cors|csrf|webhooks?|sudo|ssh|payments?|billing)([/_.-]|$) | express | security-reviewer | parallel |
| input-execution-path | path-regex | (^|[/_.-])(eval|exec|execute|command|shell|hook|guard|allowlist)([/_.-]|$)|(^|/)(\.github|workflows?|ci)(/|$) | standard | security-reviewer | parallel |
| risk-sensitive-path | path-regex | (^|[/_.-])(migrations?|migrate|destructive|deletions?|delete|removals?|remove|rollback|concurrency|concurrent|race|locks?|cancel|reconcile)([/_.-]|$) | express | risk-reviewer | parallel |
| public-contract-path | path-regex | (^|/)(cli|commands|skills|core/schema)(/|$)|(^|[/_.-])(apis?|schemas?|contracts?)([/_.-]|$) | standard | architecture-reviewer | parallel |
| policy-source-path | path-regex | (^|/)core/policy(/|$) | full | architecture-reviewer,security-reviewer,risk-reviewer | parallel |
| brief-architecture-minor | brief-value | minor | standard | architecture-reviewer | parallel |
| brief-architecture-major | brief-value | major | full | critic,qa-tester,architecture-reviewer,security-reviewer,risk-reviewer | parallel |
<!-- END GENERATED -->

<!-- BEGIN GENERATED: core/policy/reviewer-policy.yaml -->
| reviewer | kind | phase |
|---|---|---|
| critic | advisory | all |
| architecture-reviewer | advisory | impl-only |
| security-reviewer | hard-gate | impl-only |
| risk-reviewer | hard-gate | impl-only |
| qa-tester | hard-gate | test-phase |

| verdict |
|---|
| approve |
| pass |
| pass-not-applicable |
| advise |
| block-soft |
| block |
| needs-tests |
<!-- END GENERATED -->

The source tables are inputs to a resolution, not promises that every listed reviewer ran or every assurance dimension passed. An explicit mode remains independent of tier and coverage; a pass kind is likewise not a tier alias.

## Three composable recipes

`/ship` is this repository's maintainer-recommended path. `pmctl gate`, the test runner, and `ship finish` are composable primitives that can be used independently; the recommended path is not the only legal way to ship.

### Docs-only change

- `tier: express`
- `mode: sequential`
- Reviewer coverage: record the policy-resolved coverage; a docs-only classification can be `not_applicable` for additional implementation reviewers.
- Reviewer independence: combined-session review is a distinct, recorded choice.
- Tests: run affected documentation checks when applicable; otherwise record `not_applicable`, not an invented green test result.
- Manual evidence: if rendered output matters, reference a bounded screenshot path and sign-off note in the PR.
- Publish authorization: obtain the current publish-consumer verification and maintainer decision separately from the gate result.

### General functional change — pm-dispatch maintainer recipe

- `tier: standard`
- `mode: parallel`
- Reviewer coverage: the initial comprehensive maintainer gate records all policy-required reviewers; this is separate from tier and mode.
- Publish authorization: verify the current result for the `publish` consumer and make the maintainer publication decision separately.

For pm-dispatch maintainers, use this exact order: **focused tests -> refactor/reuse audit -> one primary comprehensive gate -> targeted remediation rounds -> deterministic closure -> post-fix affected tests/audit -> full suite -> publish**. This is not a fixed one-round abbreviation: per `commands/ship.md`'s operational rule, an ordinary finding at any round count is fixed and re-gated with a scoped `--pass targeted --reviewers <reviewer,...>` confirmation, not re-run as a second comprehensive gate; round count alone is never a stop signal (a real gate has needed 7 rounds to converge). The loop stops only when the ticket's own premise turns out wrong, or Rule A's 3-strike audit shows no further progress on confirmed diff-caused blockers. Generic `pmctl gate` users may choose a different re-gate policy — this order is the pm-dispatch maintainer recipe only, not a universal mandate.

### High-risk or manual-verification change

- `tier: full`
- `mode: parallel`
- Reviewer coverage: include the policy-resolved security, risk, architecture, QA, and critic coverage as applicable; do not infer coverage merely from the displayed tier or mode.
- Reviewer independence: per-reviewer sessions and separate synthesis provide the recorded independence topology.
- Manual evidence: attach or reference the bounded checklist artifact (for example, a screenshot path) and reviewer sign-off note from the PR.
- Publish authorization: after current full-suite evidence and current gate verification, obtain an explicit maintainer authorization; neither artifact alone authorizes publication.

## Scope boundary

CC-514 is documentation-only. This document introduces no new command, workflow profile, persistent workflow state, preset DSL, or FSM; it also adds no `/deliver`. A possible thin wrapper is deferred to CC-516 pending real usage evidence.
