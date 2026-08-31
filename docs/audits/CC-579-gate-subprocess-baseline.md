# CC-579 — pr-gate execution-cost baseline

**Date**: 2026-08-31
**Tool**: `ops/diagnostics/gate-subprocess-census.sh`
**Subject**: `tests/shell/test-pr-gate.sh --filter tier-detection` (2 cases, 2 gate runs)
**Machine**: WSL2, 8 cores, 7 GB RAM

This is the measurement slice of CC-579. It establishes *where* a gate run
spends its time, so a later optimisation slice has a number to move and an
oracle to prove it moved. It changes no product behaviour.

## Why this needed measuring at all

A gate run in the test suite dispatches a stub reviewer that returns
immediately, so it does no model work. Every second such a run takes is the
gate's own shell work — and a single run takes **14 s**.

That matters twice over:

- **Test cost.** The `test-pr-gate` family is **5,261 CPU-s of the full
  suite's 10,707 CPU-s — 49%**. `tests/shell/test-pr-gate.sh` invokes the gate
  254 times.
- **Production cost.** Every real gate pays the same 14 s of shell work before
  any reviewer output exists.

## Method, and why the obvious methods were wrong

The census wraps a fixed set of binaries on `PATH`. Each wrapper preserves
argv, stdin/stdout/stderr, and exit code, so the subject's behaviour is
unchanged and the counts are exact. Under instrumentation the subject still
passes (`2 passed, 0 failed`), which is the check that the measurement is of
normal behaviour rather than of a perturbed run.

Three earlier attempts produced numbers that looked authoritative and were not.
They are recorded here so the next person does not repeat them:

| Attempt | What went wrong |
|---|---|
| Count forks, conclude from the count | ~950 forks per gate is only ~1.4 s of fork overhead — 10% of the run. Counting calls answers the wrong question; the cost is time *inside* the children. |
| Read totals from a shared log while an earlier census was still alive | An interrupted census keeps forking into the same log. This produced an apparent 200,000-call "grep storm" that does not exist. The tool now runs its subject in its own session, tears down the whole process group, and refuses to start while another census is alive. |
| Treat a failing instrumented run as a valid measurement | An instrumented run that exits non-zero measured something other than the behaviour under test. The tool now prints the subject's outcome first and labels the numbers unusable when it failed. |

Durations of an instrumented run are inflated by the wrapper forks (14 s → ~22 s
for this subject). Read per-binary totals from `--mode time`; never read wall
time off an instrumented run.

## Baseline

`--mode time`, 2 gate runs:

| binary | calls | total_s | mean_ms | share of child time |
|---|---|---|---|---|
| **jq** | **736** | **28.88** | **39.25** | **88%** |
| awk | 364 | 1.39 | 3.82 | 4% |
| git | 238 | 0.82 | 3.43 | 3% |
| grep | 136 | 0.59 | 4.35 | 2% |
| cat | 173 | 0.49 | 2.81 | 1% |
| sha256sum | 173 | 0.43 | 2.49 | 1% |
| mktemp | 109 | 0.18 | 1.67 | <1% |
| sed | 10 | 0.02 | 2.21 | <1% |
| **ALL** | **1,939** | **32.81** | | |

**~368 jq invocations per gate run × ~39 ms ≈ 14 s** — which is the entire
duration of a gate run.

The 39 ms mean is not a slow program: it is jq's interpreter start-up, paid
once per invocation. The cost is the invocation count, not the filters.

## Where the calls come from

`--mode exec` clusters calls by flag shape. The dominant pattern is
single-field extraction repeated against the same document:

```
72  jq -e --arg          47  jq -nc --arg         36  jq -r length
62  jq -n -r             38  jq -n -e             36  jq -r .reviewer
27  jq -c --arg          24  jq -r --arg          22  jq -e type
18  jq -r .scope_manifest_sha256    12  jq -r .status    8  jq -r .kind
```

`jq -r length`, `jq -r .reviewer`, `jq -r .status`, `jq -r .kind`,
`jq -r .tree_fingerprint` are one-field reads that each pay a full interpreter
start-up. Reading the fields a caller needs in one pass is the shape the
repository has already applied twice, in CC-364 and CC-573.

`--mode bash` confirms the work that never leaves bash is not the problem, but
is concentrated enough to note: `gate-result-verify.sh` accounts for 19,050 of
~29,600 traced simple commands (64%), of which 16,787 are the per-line loop
over the result artifact at `gate-result-verify.sh:628-652`. That loop also
accumulates its block with `block="${block}...${line}"`, which is quadratic in
block size. It is a secondary target, not the primary one.

## What this predicts

If the per-gate jq invocation count drops by an order of magnitude, the gate
family's ~4,600 CPU-s of jq start-up largely goes away. Against the current
10,707 CPU-s suite at 4 concurrent jobs, that moves the full-suite wall time
from ~50 min toward ~31 min, and takes several seconds off every real gate.

This is a projection from the baseline, not a measured result. The optimisation
slice must re-run this census and show the drop.

The census is an operator diagnostic and is not wired into CI. A slice that
reduces the invocation count should also add a regression lock of the shape
already used in `tests/shell/test-pmctl-trace.sh`
(`case_trace_tail_single_jq_pass`): a counting `jq` shim asserting the tally is
flat in input size, so a later return to per-item spawning fails a test even
though the output stays byte-identical.

## Not established here

- Which specific call sites are safe to batch. `runtime/lib/gate-result-verify.sh`
  alone has 74 static jq sites; each needs its own read.
- Whether any call site depends on per-invocation failure isolation. CC-573
  recorded that collapsing jq passes can silently drop a "bad data must fail
  loudly" contract, so each collapse needs that checked explicitly.
- Any number for a real (non-stub) gate. The reviewer dispatch dominates there;
  this baseline only bounds the shell overhead.
