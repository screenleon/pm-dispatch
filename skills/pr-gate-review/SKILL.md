---
name: pr-gate-review
description: Use before opening a PR to run the tiered pre-PR review pipeline (critic, qa-tester, security-reviewer, risk-reviewer, architecture-reviewer) on the current branch. Covers tier/mode selection, the GO / NO-GO contract, and how to clear findings.
---

# PR-gate review

A **thin pointer skill** — the gate is implemented by `runtime/bin/pr-gate.sh` and the
`/pr-gate` command; this skill says when to reach for it and how to read the result.

## When to use

You have a committed change on a branch and are about to open a PR. Run the gate
first; do not open a PR on an un-gated change (per the project PR workflow:
implement → pr-gate → fix NO-GO → push → PR).

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
- Default = **sequential**, low token cost. `--mode parallel` gives each reviewer an independent session; `--parallel` remains a compatibility spelling.
- Trusted `architecture_impact` from `--brief <file>` is enforced by the canonical policy resolver (`minor` → at least `standard`, `major` → `full`).
- Request a tier with `--tier express|standard|full`; a request below the policy floor fails before dispatch. Re-gate a remediation subset with `--targeted r1,r2 --initial-result <path>`.

## Reading the result

The result file carries `pr_gate_result_v2` frontmatter with `final: GO|NO-GO`,
per-reviewer verdicts, and a bounded pointer to its sibling
`gate_assurance_v2` JSON envelope. The `Final: GO|NO-GO` line is the
parser-significant one (plain text, exact shape). Run
`pmctl gate verify <result-file>` from the reviewed repository before consuming
assurance claims; legacy
`pr_gate_result_v1` files and unbound v1 envelopes verify only as
`assurance: unavailable`. A standalone
copy-mode v2 result may also carry `evidence_status: unavailable` inside its
valid envelope; treat its verdict as structurally valid without inferring
implementation isolation or independent reviewer sessions. Repo-layout
independence is authoritative only when verification also confirms the
protected producer attestation, the invoking repository's canonical state
partition, and every claimed canonical run record. Current v2 envelopes also
record the shell-owned policy classification, matched signals, floors, resolved
coordinates, and any scope-bound user override.

- **NO-GO** (a reviewer returned `block`): fix the blocking finding. Per project
  convention, clear **every** finding (high/med/low/advise) on a NO-GO, not just
  the blocks, then re-gate.
- **GO with advise**: not blocking, but prefer to clear cheap/meaningful advise
  before the PR, or track it as a follow-up ticket.

## Scope gotcha

The gate diffs the branch against the base. Make sure local `main` is up to date
(fast-forward to `origin/main`) before gating, or already-merged work can leak
into the diff and produce spurious findings.
