# Agent Playbook Reconciliation Audit

This is an owner/consumer audit for the archived `agent-playbook-template`.
It is not a second policy source and does not authorize copying the template's
schemas, harness, adapters, or workflow documents into `pm-dispatch`.

## Boundary

`agent-playbook-template` remains a portable/reference repository. `pm-dispatch`
owns active dispatch behavior, runtime enforcement, state, gates, adapters,
context retrieval, and production schemas. A candidate rule is not migrated
until this audit names one active owner and one enforcement or evidence
consumer.

## Owner and consumer matrix

| Candidate | Active owner in pm-dispatch | Consumer / evidence | Status | Next action |
|---|---|---|---|---|
| Prompt-injection handling | `runtime/bin/pr-gate.sh` integrity checks; dispatch and reviewer contracts | Worktree-integrity verification and gate tests; general external-content handling still needs a policy gap audit | partial-existing | Audit the untrusted-content path before adding wording or enforcement |
| Secret non-disclosure | `SECURITY.md`; guard and preflight redaction helpers | `runtime/hooks/guard-pm-bash.sh`, `runtime/bin/pr-gate.sh`, trace/context redaction tests | existing-with-scope | Reconcile portable invariants against the existing redaction threat model |
| Input validation | `runtime/bin/brief-validate.sh`, `runtime/lib/identifier-policy.sh`, `runtime/lib/guard-framework.sh` | Brief, path, identifier, guard, and state tests | existing | Preserve fail-closed owners; do not copy GSEC rule files |
| MFT / INV / DIR | No canonical runtime owner yet | `agents/qa-tester.md` consumes the external 12-category QA matrix | defer | Build a crosswalk and run one authoring-only pilot before changing schemas |
| Simplicity | `agents/project-pm.md`; brief scope and architecture rules | PM briefs, `/pre-impl`, critic and architecture review | existing | Keep as a scope constraint, not a new global rule file |
| Explicit assumptions | `commands/pre-impl.md`; dispatch brief constraints/open questions | Pre-impl artifact and brief validation | existing | Verify the current workflow covers migration decisions |
| Verifiable success criteria | `core/schema/brief.schema.json`; `self_verify`; test and gate evidence | Brief validator, test-result, gate verifier | existing | Continue using acceptance and evidence contracts |
| Alignment loop | `/pre-impl` plus architecture reviewer | Conceptual map, constraints, and review | partial-existing | Decide whether challenge/response closure adds measurable value |
| Ubiquitous language | No glossary/retrieval owner | None | defer | Introduce only with a real retrieval or lint consumer |
| Self-reflection | `self_verify` and independent gate reviewers | Dispatch post-verify and PR gate | defer | Do not add a duplicate executor reflection protocol |
| Observability | `core/schema/event.schema.json`, run/trace state, delivery assurance | `pmctl trace`, run stats, gate verification | existing | Keep pm-dispatch-native telemetry and redaction rules |

## Schema and harness decision

Do not import `docs/schemas/*`, the template context-pack builder, adapter
harnesses, `docs/operating-rules.md`, or `docs/agent-playbook.md`. The
pm-dispatch context-pack, brief, test-result, gate, state, and event contracts
remain canonical even where the concepts overlap.

## MFT / INV / DIR pilot rule

MFT / INV / DIR are assertion-intent labels, not replacements for the existing
QA coverage dimensions (`happy`, `boundary`, `negative`, `regression`,
`concurrency`, `security`, `migration`, and `rollback`). Until a machine
consumer is identified, labels may appear only in planning or QA checklist
text. A schema field requires a separate producer, verifier, compatibility
plan, and regression coverage.

## Completion criteria

This audit is complete for a candidate only when:

1. one pm-dispatch owner is named;
2. one runtime, gate, test, or evidence consumer is named;
3. the candidate has an explicit status and non-goal; and
4. the relevant targeted tests and full-suite policy are recorded.

## Verification policy

The current document is an audit-only, documentation change. Its direct
verification is `git diff --check` plus review of the cited owner/consumer
paths. It does not claim that the listed `existing` candidates are newly
implemented or that the `partial-existing` and `defer` candidates are complete.

When a candidate advances to `reconciled`, record both parts below in the same
change:

| Candidate class | Targeted evidence | Full-suite policy |
|---|---|---|
| Brief, identifier, path, or guard validation | `bash tests/bin/run-tests.sh --path <changed-path>` | `bash tests/bin/run-all-tests.sh` before pm-dispatch PR creation |
| Gate, reviewer, state, or event contract | affected shell suite selected by `run-tests.sh --path` plus schema/verifier check | `bash tests/bin/run-all-tests.sh` and `bash tests/bin/run-tests.sh --verify-full <artifact>` |
| Documentation-only policy reconciliation | `git diff --check` plus semantic owner/consumer review | no executable suite claim; run the full suite if the change touches a runtime consumer |

This keeps the audit honest: a status entry is an inventory result until its
consumer evidence and verification policy are recorded.
