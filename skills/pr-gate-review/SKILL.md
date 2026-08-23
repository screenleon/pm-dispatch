---
name: pr-gate-review
description: Use before opening a PR to run the tiered pre-PR review pipeline (critic, qa-tester, security-reviewer, risk-reviewer, architecture-reviewer) on the current branch. Covers tier/mode selection, the GO / NO-GO contract, and how to clear findings.
---

# PR-gate review

A **thin pointer skill** — the gate is implemented by `runtime/bin/pr-gate.sh` and the
`/pr-gate` command; this skill says when to reach for it and how to read the result.

## When to use

You have a committed change on a branch and are about to open a PR. For this
repository's maintainer-recommended PR route, run the gate first (implement →
pr-gate → fix NO-GO → push → PR); other workflows may compose their assurance
evidence differently.

## How to run

- Slash command: `/pr-gate` (see `commands/pr-gate.md`). It dispatches the
  reviewers and writes a typed result to `.gate-results/`.
- Direct: `pmctl gate run --cd <repo> --executor auto --policy generic [--mode sequential|parallel]`.
- Reasoning effort defaults to `medium` (`--effort low|medium|high`, independent of `--model`/`--executor`). Only reach for `--effort high` when you need deeper analysis — e.g. a hard-to-diagnose finding, or escalating after repeated NO-GO rounds on the same issue.

**Tier / mode** (tiers reflect rigor level, not reviewer count):
- `express` — hotfix, docs-only, `architecture_impact: none`; machine verify + critic + qa.
- `standard` — feature, `architecture_impact: minor`; adds architecture-reviewer with conceptual map.
- `full` — large or architectural change, `architecture_impact: major`; defaults to all reviewer dimensions.
- Sensitive paths add their security/risk/architecture reviewer without automatically forcing `full`.
- With no mode flag, policy auto-selects its recommendation. An explicit
  `--mode sequential` (lower token cost) or `--mode parallel` (independent
  reviewer sessions) always wins; `--sequential` / `--parallel` remain
  compatibility spellings.
- Preserve an explicit user mode on follow-up or targeted gates after NO-GO;
  omit the flag only when the user left mode selection to policy.
- Trusted `architecture_impact` from `--brief <file>` is enforced by the canonical policy resolver (`minor` → at least `standard`, `major` → `full`).
- Request a tier with `--tier express|standard|full`; a request below the policy floor fails before dispatch. Re-gate a remediation subset with `--targeted r1,r2 --initial-result <path>`.

## Reading the result

Completed selected-reviewer results carry `pr_gate_result_v4` frontmatter with
`final: GO|NO-GO`, per-reviewer verdicts, one synthesis parity block, and a
bounded pointer to the sibling `gate_assurance_v3` JSON envelope. The
`Final: GO|NO-GO` line is
parser-significant (plain text, exact shape), but is not freshness or
authorization evidence. Run
`pmctl gate verify <result-file> --cd <reviewed-repo> --consumer embedded --json`
before consuming assurance claims. Named-consumer success requires all three
axes to pass: `artifact_valid`, `subject_current`, and `policy_applicable`.
Legacy result v1-v3 and v1/v2 assurance artifacts remain readable under their
historical contracts; result v3 proves reviewer protocol but not synthesis
parity. They cannot prove capabilities their versions did not record.
Repo-layout authorization is authoritative only when
verification also confirms the protected producer attestation, the invoking
repository's canonical state partition, and every claimed canonical run
record. Current v3 envelopes also record the shell-owned policy classification,
matched signals, resolved coordinates, linked evidence, and any scope-bound
user override.

Treat `gate_synthesis_result_v1` as a parity-preserving view of the raw
reviewer documents. Copied coverage/inventory/test-gap fields are restored
from those documents on the live gate run before the check — never from
later `pmctl gate verify`. Grouping and disagreements remain synthesis
judgments. The remaining union, uncertainty, caution, and seed fields are
machine-checked.
Root-cause groups organize findings without replacing stable IDs. A synthesis
protocol `INCOMPLETE` is not reviewer NO-GO and cannot authorize publication,
even when every reviewer verdict says approve.

- **NO-GO** (a reviewer returned `block`): fix the blocking finding. Per project
  convention, clear **every** finding (high/med/low/advise) on a NO-GO, not just
  the blocks, then re-gate.
- **GO with advise**: not blocking, but prefer to clear cheap/meaningful advise
  before the PR, or track it as a follow-up ticket.

## Scope gotcha

The gate diffs the branch against the base. Make sure local `main` is up to date
(fast-forward to `origin/main`) before gating, or already-merged work can leak
into the diff and produce spurious findings.
