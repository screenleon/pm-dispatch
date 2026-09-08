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
| Read totals from a shared log while an earlier census was still alive | An interrupted census keeps forking into the same log. This produced an apparent 200,000-call "grep storm" that does not exist. The tool now runs its subject in its own session, tears down the whole process group, and holds an `flock` for the duration — a pid file that is read and then written is not enough, because two launches can both observe it absent. |
| Treat a failing instrumented run as a valid measurement | An instrumented run that exits non-zero measured something other than the behaviour under test. The tool now prints the subject's outcome first and labels the numbers unusable when it failed. |

The census takes `--suite <path>`, so it can profile any suite — and so its own
regression tests (`tests/shell/test-gate-subprocess-census.sh`) can point it at
synthetic subjects whose subprocess behaviour is known exactly, and assert the
reported counts against them. Verifying a measurement tool against the real gate
would be both slow and circular: the real call counts are what it is meant to
discover.

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

## Slice 1 Task 0 — per-call-site attribution (2026-08-31)

`--mode bash --attribute jq` reports jq invocations per `source:line`. Its total
reconciles **exactly** with `--mode exec` (729 = 729 on the same subject), so
this is a complete attribution, not a sample.

Getting there took three corrections, each of which produced a
plausible-looking but wrong ranking:

- **Nested frames.** bash marks a subshell's xtrace with a deeper run of `+`.
  A pattern anchored on a single `+` folds every subshell call into the
  preceding record — this alone hid most call sites and misattributed their
  text to whichever line came before. This was the big one: 145 attributed
  before the fix, 729 after.
- **Multi-line commands.** A traced command spans several output lines, so each
  record must run from its prefix to the next.
- **Command word, not mention.** The binary counts only as the command word of
  its record. Accepting the name anywhere counts `jq_rc=0`,
  `local jq_display_def=`, and `command -v jq` as invocations — inventing call
  sites that do not exist.

### Where the jq calls actually are

Per file, over two gate runs (halve for one run):

| calls | file |
|---|---|
| 310 | `gate-result-verify.sh` |
| 134 | `gate-policy.sh` |
| 120 | `gate-structural-verify.sh` |
| 58 | `pr-gate.sh` |
| 40 | `gate-scope.sh` |
| 32 | `gate-closure.sh` |
| 60 | everything else combined |

Hottest individual sites (two runs):

| calls | site | what it is |
|---|---|---|
| 60 | `gate-structural-verify.sh:22` | `jq -e 'has($name)'` — **an existence probe for the schema name** |
| 60 | `gate-structural-verify.sh:27` | the schema validation pass itself |
| 32 | `gate-policy.sh:586` | policy signal evaluation |
| 24 | `gate-result-verify.sh:2056` | — |
| 22 | `gate-policy.sh:234` | — |
| 18 each | `gate-result-verify.sh:194,237,258,263,326,546,672,705` | the per-reviewer-document chain |

**The single clearest target is the `has($name)` probe.** Every schema
validation opens jq once only to ask whether the schema name exists in the
bundle, then opens it again to validate. The validating pass already receives
`--arg name` and can report an unknown schema itself, so the probe is 30
invocations per gate — about 8% of all jq — for a question the next call
already answers. The 2026-08-20 read-only analysis independently listed this
same probe among its low-risk removals.

The per-reviewer-document chain remains a target but is second, not first: its
sites are 9 per gate each rather than 30.

## Not established here

- Which specific call sites are safe to batch. `runtime/lib/gate-result-verify.sh`
  alone has 74 static jq sites; each needs its own read.
- Whether any call site depends on per-invocation failure isolation. CC-573
  recorded that collapsing jq passes can silently drop a "bad data must fail
  loudly" contract, so each collapse needs that checked explicitly.
- Any number for a real (non-stub) gate. The reviewer dispatch dominates there;
  this baseline only bounds the shell overhead.

## Slice 1 continuation — reviewer bindings (2026-09-06)

The reviewer verifier used two separate jq processes to read `reviewer` and
`scope_manifest_sha256` before its finding diagnostics. Both comparisons now
run at the start of that existing diagnostic pass. JSON parsing and evidence
healing still precede it; reviewer mismatch, stale scope, and finding errors
retain that precedence. Schema and evidence-reference validation still run.

On the same `tier-detection` subject, `--mode exec` measured **676 → 640 jq
calls** across two gate runs: 18 reviewer-document validations save two calls
each, or **18 fewer calls per gate (5.3%)**. Both subjects passed all two cases;
other instrumented binary counts were unchanged. This is a process-count
measurement, not a claim about end-to-end latency or reviewer model time.

Reproduce before and after the change:

```bash
bash ops/diagnostics/gate-subprocess-census.sh --mode exec
```

The library-level case in `test-gate-structural-verify.sh` checks binding-error
precedence, malformed JSON rejection, acceptance of a complete reviewer
document, and a maximum of six jq processes for that document. The affected
suite mapping includes this case when `gate-result-verify.sh` changes.

Refactor/reuse audit: reuse the existing diagnostic pass and canonical reviewer
fixture; no new parser, serialization delimiter, cache, or helper abstraction
is needed. Parsing, healing, and structural-validation passes have distinct
failure contracts and remain separate. Further call-site batching and the
subsequent concurrency experiment remain later CC-579 slices.

## Slice 1 continuation — empty policy matches (2026-09-06)

After the reviewer-binding slice (#576), the same two-gate `tier-detection`
census measured **640 → 608 jq calls**: one empty-array probe removed for each
of 16 signal rows per gate, or **16 fewer calls per gate (5.0%)**. Both measured
subjects passed two cases, and the other instrumented binary counts stayed
unchanged. This is a process-count result; it does not establish a wall-time
improvement, and earlier cross-day timing figures are not comparable.

Every match producer in `_gate_policy_resolve` already returns a compact JSON
array, or leaves the initial literal `[]`. Comparing that internal output with
`[]` removes the separate `jq -r length` process. The classification, path
regex, and brief-value match computations themselves are unchanged. A failed
brief-value array producer now explicitly returns execution failure, matching
the other array producers, before any policy result can be emitted.

The library-level cost case checks exact tier/reviewer/match evidence for all
three match-source kinds. Adding eight unmatched classification rules leaves
the entire policy result unchanged and adds eight jq calls, not sixteen. A
temporary reintroduction of the old length probe failed that assertion with
growth=16; restoring the optimization passed. A separate one-off fault probe
confirmed a failed brief-value jq returns exit 2 with no policy result.

Refactor/reuse audit: reuse the existing compact-array producers and their
error cleanup; no new JSON encoder, cache, matcher, or helper layer is needed.
Existing end-to-end policy cases remain in place. This is another bounded
cost reduction, not evidence that a tenfold reduction in gate overhead is
achievable; larger batching needs separate safety and payoff evidence.

## Slice 1 close-out — subject-field batch + census hardening (2026-09-08)

Re-measurement at HEAD `e610245` (after #568/#569/#570/#576/#577), same
two-gate `tier-detection` subject:

| point | jq calls / 2 runs | jq / gate |
|---|---|---|
| Slice 0 baseline (#568) | 736 | 368 |
| after schema probe (#570) | 676 | 338 |
| after reviewer bindings (#576) | 640 | 320 |
| after empty-policy skip (#577) | 608 | 304 |
| **this change** | **588** | **294** |

Cumulative: **368 → 294 jq/gate, −74 (−20%)**.

This change folds the six per-field `jq -r` reads that
`_gate_assurance_linked_evidence_verify` makes on the assurance file before
calling `gate_scope_manifest_verify` into one `@tsv` pass (**−10 jq/gate**),
and applies the same fold to the four-field wait decision and the human
`pmctl gate verify` summary in `runtime/lib/pmctl-gate.sh` (not exercised by
this census subject, which drives `pr-gate.sh` directly). Every folded read is
`jq -r` on a document already schema-verified upstream; `jq -r` on a missing
field and `@tsv` on a null field both yield an empty value, so an absent field
still arrives as an empty argument exactly as before, and `|| true` on the
`read` preserves the prior non-fatal behaviour on an unreadable file. The
values are git keys, commit SHAs, refs and enum statuses, none of which can
contain a tab or newline, so `@tsv` escaping cannot desync the split.

`ops/diagnostics/gate-subprocess-census.sh` itself had two defects found while
re-measuring, both now fixed and locked with regression cases in
`tests/shell/test-gate-subprocess-census.sh`:

- `--mode bash` exited **rc=141**: each tally pipeline ends in `head -N`, and
  once `sort -rn`'s output exceeds a pipe buffer the closed pipe drives it to
  SIGPIPE, which under `pipefail` + `set -e` aborted the script *before* the
  `--attribute` table — the entire point of `--mode bash`. The reporting
  pipelines now cannot end the script; the measurement's usability is still
  the subject exit code.
- the `mktemp -d` scratch dir (~3.6 MB/run) was never removed; the EXIT trap
  now deletes it after the optional `--out` copy.

## Close-out: CC-579 done (2026-09-08)

Five slices shipped: the census tool + baseline (#568), exact per-call-site
attribution (#569), schema-probe merge (#570), reviewer-binding batch (#576),
empty-policy probe skip (#577), and this subject-field batch + census
hardening. jq per gate fell **368 → 294 (−20%)**.

The remainder is not safely collapsible:

- **~30 jq/gate is the schema validator itself** (`gate-structural-verify.sh`
  `jq -f`) — that *is* the verification, not overhead.
- **~63 jq/gate is the per-reviewer-document chain** in
  `gate-result-verify.sh` (`:190`–`:703`): a sequence of distinct
  "bad data must fail loudly" boundaries — invalid-JSON, binding-mismatch,
  schema, test-gap, evidence-ref — each raising its own
  `GATE_REVIEWER_PROTOCOL_DOCUMENT_ERROR`. They run as separate processes by
  design; folding them is exactly the CC-573 hazard this ticket's Risks
  section forbids without per-merge-point proof, and #576 already folded the
  cheap reads there.
- the rest is a 2–4 jq/gate long tail in the repo's most security-sensitive
  script, each site needing individual failure-isolation review, for a
  projected full-suite saving below the mechanical-optimisation ROI floor
  (see the `test-suite-duration-ceiling` note) — and cross-day wall/CPU on
  this machine is not comparable, so the saving is not reliably measurable.

The concurrency re-test (originally "Slice 2") is **not pursued**: the earlier
8-job experiment failed on the correctness axis (two suites failed), which a
20% jq reduction does not change; revisit only if suite composition changes.

The durable win is the repeatable census tool + this baseline: any future gate
change now has a before/after oracle.

The quadratic `block="${block}…"` accumulation in
`gate_reviewer_protocol_verify` (`gate-result-verify.sh:651`) is bash-side, not
the 88% jq cost, and is spun out to CC-581 rather than held here.
