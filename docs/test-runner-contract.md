# Test runner contract

pm-dispatch has two deliberately different test entry points. They solve
different problems and neither silently substitutes for the other.

## Iteration runner

`scripts/run-tests.sh` plans direct-impact suites from changed paths and invokes
the shared suite executor with explicit `--suite` selections. It is optimized for a
short edit/fix feedback loop.

```bash
bash scripts/run-tests.sh --base origin/main
bash scripts/run-tests.sh --path scripts/lib/pmctl-context.sh
bash scripts/run-tests.sh --base origin/main --list
```

The planner currently knows direct path-to-suite relationships only. It does
not claim a trustworthy transitive dependency graph. Every run therefore prints
`contract=iteration-only`; paths without a direct behavioral mapping are listed
as coverage gaps. Changes to high-fanout runner/install substrates escalate to
the full suite instead of returning an unsafe targeted result.

For an iterative reviewer gate, the caller may opt in explicitly through the
generic gate interface:

```bash
pmctl gate run \
  --cd /path/to/pm-dispatch \
  --test-cmd 'bash scripts/run-tests.sh --base origin/main' \
  --lifecycle detached
```

`pr-gate` does not auto-detect this command or any runner filename. Other repos
remain free to supply their own `--test-cmd`, or none.

## pm-dispatch maintainer delivery profile

`scripts/run-all-tests.sh` is the backward-compatible full-suite entry point; it
delegates to `scripts/run-tests.sh --all`. For this repository's own delivery
workflow, run it independently of the PR-gate lifecycle so its wall-clock
budget cannot consume the gate supervisor/reviewer budget:

```bash
bash scripts/run-all-tests.sh
```

The pm-dispatch maintainer profile is deliberately asymmetric:

1. During implementation and an optional PR-gate review, run affected suites
   for fast feedback.
2. Immediately before creating a pm-dispatch PR, run
   `scripts/run-all-tests.sh` outside the gate lifecycle. It writes
   `.pm-dispatch/test-results/latest-full.json` (`pm_test_result_v1`).
3. Verify that artifact against the still-current source tree before opening
   the pm-dispatch PR:

       bash scripts/run-tests.sh --verify-full .pm-dispatch/test-results/latest-full.json

The verifier accepts only an authoritative full PASS with no requested skips,
the complete current suite registry, an unchanged tree during the run, and
matching current tree + runner-contract fingerprints. Any edit after the full
run invalidates the evidence and requires another full run.

`release-verify.sh` is this project's release command. It always performs a
fresh full run in Phase 2 and verifies its new artifact before continuing.
`--no-suite` remains an explicit diagnostic escape hatch and can produce only
PARTIAL GO, never a pm-dispatch release sign-off.

These are project-maintainer policy choices, not requirements imposed by the
generic gate tool. Each capability remains independently callable: another
repository may use `--test-cmd` with its own runner, use a gate with no test
command, run tests without a gate, or use neither. `pr-gate` does not select or
enforce a delivery profile.

## Aggregator selection primitive

The internal suite executor's `--suite <name>` is repeatable and runs only the
named, registered suites in registry order. Unknown names fail before execution.
`run-tests.sh` owns that primitive; `run-all-tests.sh` deliberately exposes only
the same runner's `--all` compatibility mode.
