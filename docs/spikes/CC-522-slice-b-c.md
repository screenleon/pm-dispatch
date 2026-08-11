# CC-522 Slice B/C delivery plan

## Goal

Keep test execution evidence separate from reviewer prose. A failed or timed
out command is never treated as a product-test failure unless a subject-bound
structured result proves that assertion.

## Slice B — QA execution evidence

1. Before reviewer dispatch, create one host-owned `qa_execution_evidence_v1`
   artifact for the selected `qa-tester`.
2. Supplemental QA commands use the host-created helper. It atomically records
   a running checkpoint, command identity, timeout, and log path before it
   executes the command under `timeout --kill-after=15`.
3. The helper records only `pass`, `nonzero`, or `timeout`; a nonzero QA command
   is inconclusive execution evidence, never a synthetic reviewer blocker.
4. On reviewer-session failure, gate EXIT cleanup finalizes a pending record as
   `inconclusive`, retaining checkpoint and log pointers. A normal gate with no
   supplemental execution records `not_run`.

## Slice C — external evidence boundary

1. Local `pr-gate` rejects `--external-test-evidence`; a caller-controlled JSON
   file and its digest can prove transport integrity, not which runner executed
   the test.
2. An inconclusive local preflight is recovered by rerunning the repository-owned
   command locally. External logs, PASS JSON, and caller-supplied hashes remain
   non-authorizing clues only.
3. A future remote-evidence route requires a CI-provider OIDC/provenance
   attestation verifier bound to the repository, workflow, commit, and command.
   It is deliberately not implemented by this slice.

## Verification

- Existing preflight contracts remain covered by `test-pr-gate`.
- The external-evidence regression proves the retired local option is rejected
  before reviewer dispatch; the delivery plan and public command guidance state
  the same non-authorizing boundary.
- QA artifacts are gate-owned post-mortem evidence and relocate together with
  other timestamped artifacts under `--run-dir`.
