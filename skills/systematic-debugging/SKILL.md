---
name: systematic-debugging
description: Use when investigating a bug, regression, unexpected behavior, or failing test and you need a repeatable path from reproduction through a verified fix. Follow the existing test and git evidence rather than guessing, then add a focused regression test.
---

# Systematic debugging

A **thin method pointer** — use the repository's existing tests, history, and
validation rather than inventing a debugging harness or a new command.

**Do not perform state transitions and do not bypass guards.** This is a
reasoning method, not authorization to alter workflow state or evade existing
controls.

## When to use

Apply this method when a failure needs more than a one-line correction: a test
regressed, behavior is surprising, or the cause is not already proven.

## Method

1. **Reproduce.** Start with the smallest reliable failing test, command, or
   user-visible case. Record the observed result and the expected result before
   changing code.
2. **Isolate.** Narrow the failing path with the relevant tests, targeted
   searches, and `git diff`/`git log` when recent changes may matter. Reduce
   inputs or scope until unrelated behavior is out of the way.
3. **Hypothesize.** State a concrete, falsifiable explanation of the cause and
   identify the evidence that would disprove it. Prefer one testable cause over
   a list of guesses.
4. **Verify.** Run the smallest existing test or inspection that distinguishes
   the hypothesis from alternatives. If it does not, return to isolation rather
   than treating a plausible story as proof.
5. **Fix.** Make the minimal change supported by the verified cause. Preserve
   existing guards, contracts, and state-transition boundaries.
6. **Regression test.** Add or extend a focused test that failed before the
   fix, then run it and the relevant existing suite. Check the final diff for
   accidental scope growth.

## Evidence to keep

- Keep the original failing case reproducible until the fix is verified.
- Let existing repository tests and validation commands define success.
- If no regression test is justified, record why and run the closest existing
  coverage instead.

## Boundaries

- Do not turn this method into a slash command, hook, or new harness check.
- Do not replace evidence with a state update, a guard exception, or a broad
  refactor.
- Escalate when the evidence points to a missing decision or an external
  dependency rather than a local defect.
