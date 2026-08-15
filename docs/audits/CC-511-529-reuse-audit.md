# CC-511 Phase B / CC-529 refactor and reuse audit

Date: 2026-08-15
Scope: `gate_publish_assessment_v1`, `/ship finish`, Gate closure, publish
verification, policy assurance, schema ownership, and their tests.

## Audit method

- Inspected the complete feature diff from the `main` subject through the
  publish-assessment implementation.
- Searched existing helpers and all affected call sites with `rg`, including
  subject fingerprinting, digesting, structural validation, closure
  verification, policy applicability, and ship output generation.
- Ran the repository reuse scan for the CC-511/CC-529 publish-assessment
  description.
- Checked the prior Git history for an existing
  `gate_publish_assessment_*` producer or verifier.
- Reviewed the production/test boundary and the script ownership/consumer
  inventories.

## Reuse decisions

`runtime/lib/gate-publish.sh` is the single owner of the
`gate_publish_assessment_v1` producer and verifier. No equivalent historical
producer or verifier exists. It deliberately reuses these established owners:

| Concern | Canonical owner | Consumer |
|---|---|---|
| Structural schema validation | `gate_structural_schema_verify` | publish assessment |
| Source digests | `gate_digest_file` | publish assessment |
| Remediation closure semantics | `gate_remediation_closure_verify` | publish assessment |
| Gate subject fingerprint | `_gate_subject_tree_fingerprint` | ship finish boundary |
| Policy applicability and baseline/preferred meaning | `gate_policy_applicability_assess` | publish assessment |
| Output projection | `gate_publish_assessment_build` / `gate_publish_assessment_verify` | ship stdout, PR body, finish marker |

The test-only builders and lower-level stubs are intentional isolation seams;
they do not duplicate production ownership.

## Finding and remediation

The audit found one warranted cleanup: `pmctl-ship.sh` had a fallback that used
only `git rev-parse <head>^{tree}` when the canonical Gate subject helper was
not loaded. That fallback represented a weaker, different fingerprint
algorithm and could make an isolated caller disagree with the publication
subject. It was removed. The subject fingerprint implementation now lives in
the existing source-safe `runtime/lib/gate-subject.sh` owner, so ship can load
the exact Gate helper without importing the larger result verifier or
overriding test seams. Ship now fails closed when the canonical helper is
unavailable, and a regression test locks that boundary.

Result: **CHANGED** — removed the divergent subject-fingerprint fallback and
added `ship subject fingerprint requires canonical Gate helper`.

After this correction, no further warranted production refactor/reuse change
was identified. The shared publish module, existing Gate helpers, and three
ship output consumers have one source owner each.

## Validation

- `cli/pmctl context reuse-scan ...`
- `bash tests/shell/test-pmctl-ship.sh`
- `bash tools/lint/lint-script-domain-inventory.sh`
- `git diff --check`
