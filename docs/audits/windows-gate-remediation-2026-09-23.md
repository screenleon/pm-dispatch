# Windows gate remediation — 2026-09-23

This supplements the 2026-09-22 runtime and gate audits. No Python dependency
was introduced. The gate still uses native Windows Git Bash and Codex's
provisioned elevated Windows sandbox.

## Incident and changes

Gate `gate-20260922-151929-5272ce` produced reviewer text but did not produce
a verified gate result. Its generated self-verification command passed a
space-bearing output path to `test -f` without shell quoting. All four brief
generation sites now shell-escape the filename using Bash `printf %q`.
The post-verifier consumes a plain command scalar and executes it using Bash.

The same gate's parent operation remained unresolved because reconciliation
rejected drive-letter child directories even though attachment accepts them.
Reconciliation now uses the existing absolute-directory predicate. A real
`gate wait` reconciled operation `op-20260922T151921Z-2faf65` to `failed`, with
two children and zero unresolved children. This does not convert the old
review into a successful gate. Cancellation's separate path handling is
outside this reconciliation change.

## QA rules provenance

The user designated `\\wsl.localhost\Ubuntu\home\screenleon\github\qa-testing-rules`.
Its top-level Markdown files were copied to the ignored local directory
`.gate-results/qa-rules-20260923`. Each copy was compared with the source using
SHA-256; `source-manifest.json` records hashes and capture time. The gate runner
passes this directory through `QA_RULES_DIR` using a native Windows path.
The source repository was not edited. Reviewers must read `AGENT.md` there,
and the referenced files relevant to their task.

## Security finding disposition

The old review alleged that `Bash(pmctl guard check *)` permits unrelated
commands appended using shell operators. This premise contradicts the
[Claude Code permission contract](https://code.claude.com/docs/en/permissions):
compound commands are split and each component needs independent permission;
the documentation also describes checks for substitutions and redirections.
The wildcard alone is therefore not evidence of that bypass. The allowlist
is retained and its comment now cites this contract. A fake Claude executable
cannot establish the real permission parser's security behavior; no such
test is claimed here, and no live adversarial Claude probe was performed.
Executable resolution and audit-log writes are separate considerations.

## Regression evidence and scope

Two integration tests exercise the actual implementation and filesystem.
Only the external reviewer is stubbed in the path test. The independent
oracles are: filenames are literal data, a missing file fails verification,
and a trusted failed child cannot leave an inactive parent running or make
it successful. The operation test also verifies terminal idempotency.

Test timing is **test-after**, following incident diagnosis; restoring the
original defects is used as a mutation check. This is not claimed as the
strict test-first sequence requested by the QA rules. Assertion semantics
remain subject to reviewer/human review; passing automation is not approval.

| Category | Applies | Cases or reason |
|---|---|---|
| Happy path | Yes | Existing literal result verifies; Windows child reconciles |
| Boundary | Yes | Result exists versus absent; drive-letter versus POSIX representation |
| Negative inputs | Yes | Filename containing space, quote, semicolon and substitution syntax |
| Error paths | Yes | Missing result returns failure; trusted failed child yields failed parent |
| State transitions | Yes | Running to failed; repeated reconciliation preserves record |
| Concurrency | Existing coverage | Existing operation lock/attachment tests; lock algorithm unchanged |
| Side effects | Yes | No injected file; persisted failed state and unchanged terminal timestamp |
| Resource lifecycle | Existing harness | Isolated temporary fixtures and bounded subprocess watchdogs |
| Security | Yes | Literal filename cannot execute substitution; no claimed Claude parser test |
| Performance | N/A | No throughput/size algorithm change; bounded regression execution |
| Contract | Yes | Generated brief consumed by real post-verifier; real supervisor terminal claim |
| Backward compatibility | Yes | Existing terminal-claim schema; no stored-data migration |

The permanent tests cover observed Windows failures that previous tests missed,
and assert behavior rather than source text or implementation call order.
Repetition and mutation results are recorded below. The subsequent live gate
has its own result artifact; this report alone does not authorize merging or
deployment.

### Executed checks

- Both new integration tests passed in three consecutive native Windows runs.
- The Windows operation subset passed all six cases, with no skips.
- Restoring unquoted `test -f` commands caused the literal-path test to fail
  (`present=1`, expected 0). Restoring the POSIX-only child check caused the
  operation test to fail (`indeterminate`, zero children, one unresolved).
  The original fixes were restored automatically after this mutation run.
- A real Codex Windows sandbox could read the local QA entry point. The
  reviewer guard allowed the result path (0) and denied the source path (2).
- All eleven changed shell scripts passed Bash syntax checks and ShellCheck
  0.11.0, using the repository's existing per-file suppressions. The adapter,
  outside the canonical lint inventory, separately excluded its existing
  SC1091 snapshot-source diagnostic. JSON output avoided the native tool's
  console encoding failure. `git diff --check` passed.

## Additional failures exposed by the live rerun

`gate-20260922-233431-716e27` reached reviewer completion and passed the real
escaped-filename self-verification. All four reviewer blocks said approve,
but the gate exited 2 during assurance validation. It is not an accepted GO.
Its parent operation correctly counted its one successful child dispatch;
that aggregate operation state does not replace the gate's own exit/verdict.

The failed assurance envelope retained a reviewer-override source written as
`C:/...` by native jq's MSYS argument conversion. The assurance contract
requires POSIX provenance paths. Both reviewer and policy override producers
now disable argument conversion for their individual JSON-construction call,
consistent with the existing subject/assurance producers. Validation was not
relaxed, and no global MSYS setting was changed.

The existing explicit-override and scope-bound policy-override integration
cases reproduced the real assurance failure (exit 2) before these fixes.
After that fix they exposed the next boundary: native jq emits CRLF, and
Bash's process-substitution `read` retained a literal CR on the last TSV field.
A probe of the saved live artifact showed the same SHA as 64 characters in
command substitution versus 65 characters with a final CR in `read`.
The verifier now removes only the record-terminating CR from the last field
of its two TSV reads. TSV escapes CR characters inside field data, so this
does not remove data or weaken hash equality. The saved live evidence then
passed linked-evidence verification without modifying it. The native-output
behavior is documented in the [jq manual](https://jqlang.org/manual/).

The external-reviewer fixtures had also split paths on whitespace, preventing
these existing cases from reaching the assurance boundary. Their brief-path
parsing now retains the complete path after the field separator; canonical
source assertions likewise avoid native argument conversion. These are
external-boundary fixtures, not replacements for gate implementation logic.
No additional permanent test was needed for the provenance failure: the
existing full gate cases detect it. This portion followed reproduce, fix,
then repeat verification; fixture-only failures were not counted as red proof.
Both existing override cases then passed three consecutive native Windows
runs. Their negative phase continued to reject an unauthorized coverage
downgrade with exit 3. The PowerShell wrapper in the platform guide also passed
a real `pmctl --help` smoke check and restored the caller's PATH afterward.

The same live review incorrectly claimed supplemental tests succeeded while
its checkpoint recorded a nonzero no-match command. That statement is not
accepted as test evidence. Historical artifacts remain unedited; details are
in `.gate-results/windows-gate-observation-20260923.md`. The next live run uses
an explicit host preflight command and tells reviewers that `--filter` matches
a literal substring. Reviewer prose must be checked against execution evidence.

## Protected dispatch path binding

The saved canonical records for `run-20260922T234341Z-c1d10c` use `c:/...`
for `working_dir` and `C:/...` for the trace, while the signed assurance uses
`/c/...`. The authorization verifier previously compared these strings
literally. On native Windows it now derives the native path spellings from
the bound repository and run roots, then permits only those exact aliases
(including either drive-letter case). It does not canonicalize arbitrary
record paths, fold directory-name case, or weaken the `.agent-trace/` boundary.
POSIX comparisons retain their original single exact spelling.

Three integration scenarios use real files, digests and the real authorization
verifier: accept equivalent Windows paths; reject another repository; reject
a sibling trace directory. The original verifier rejected the positive case.
After the fix all three passed three consecutive runs. Removing repository
equality and broadening the trace prefix caused both negative cases to fail;
the production checks were then restored byte-for-byte. This additional
coverage protects a supported, high-impact authorization boundary that the
copy-mode gate fixtures do not exercise. Oracle: a completed run must belong
to the bound repository and the same gate's trace directory.
