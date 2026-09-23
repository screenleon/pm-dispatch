# Windows runtime investigation — 2026-09-22

## Scope

Native Windows Git Bash, local checkout at `67115ff`, with pre-existing
uncommitted changes in `adapters/claude/dispatch.sh`. Those adapter changes
were preserved. This investigation is not a full-suite or release sign-off.

User constraint: do not add Python 3 as a runtime requirement without a
demonstrated Windows-specific benefit. No Python dependency was added.
Inspection of `runtime/`, `hosts/`, `adapters/`, and `cli/` found no Python
interpreter invocation; the Python references in `pmctl-context.sh` classify
indexed source languages. Current Windows process isolation, record replacement,
and ACL checks already use PowerShell / Windows primitives.

## Findings

1. **Choose the correct Bash explicitly.** PowerShell's `Get-Command bash`
   resolves `C:\Windows\System32\bash.exe` on this machine. Explicit
   `C:\Program Files\Git\bin\bash.exe --noprofile --norc` successfully runs
   `bash cli/pmctl --help` under `MINGW64_NT-10.0-26200`. `pmctl` was absent
   from the probed shell PATH. The PowerShell example in `platform-support.md`
   now names the Git Bash executable explicitly.
2. **The latest recorded gate failure is quota exhaustion.** Four dispatch
   results created at `2026-09-22T07:09:29Z`–`07:09:30Z` report exit 1.
   Their `.last` files say the weekly limit was reached. The inspected
   `claude-20260922-161307-36486.jsonl` ends with `api_error_status: 429`,
   `terminal_reason: api_error`, and `is_error: true`. It also contains
   successful tool activity: the reviewer did start. This is historical
   evidence, not a live account-quota check.
3. **Reviewer permission remains a separate issue.** That trace records
   denied Bash calls for `git diff` and `git show`. The existing uncommitted
   adapter change allows `pmctl guard check *`; it does not by itself prove
   that reviewers can obtain all required evidence or write their verdict.
   Validate a bounded reviewer workflow after quota is available; do not
   solve this by broadly disabling permissions.
4. **Default test temp ACLs fail the new state-root guard.** The initial
   Windows operation test stopped with `ACL grants write to a non-owner
   principal`. The user's temp directory has additional Modify grants,
   including `CodexSandboxUsers`. The production state root inspected here
   instead gives that group ReadAndExecute. The successful follow-up setup
   creates a fresh temp parent with an owner-only inheritable ACL and sets
   `TMPDIR` for tests. Existing directory permissions are not changed and
   `PM_DISPATCH_ALLOW_UNSAFE_STATE_ROOT` is not enabled.
5. **Two fixture assumptions hid Windows coverage.** Replacement tests
   stubbed `cygpath` with support for `-w` only. On native Windows this
   prevented `-m` canonicalization and caused ownership rejection before
   the replacement under test. The stub now delegates other arguments to
   the real `cygpath` when available. The Claude snapshot assertion also
   rejected quoted paths containing spaces; its xtrace match now accepts
   them. These changes repair tests, not production replacement semantics.

## Validation

Executed with Git Bash on this Windows machine, using the private ACL-safe
temporary parent described above (PowerShell `DirectorySecurity`, current
owner FullControl, inheritance disabled on that new parent only):

| Command | Result |
| --- | --- |
| `timeout 180 bash tests/shell/test-pmctl-operation.sh --filter Windows` | 5 passed, 0 failed, 0 skipped |
| `timeout 180 bash tests/shell/test-claude-dispatch.sh` | 39 passed, 0 failed, 0 skipped |
| `git diff --check` | Passed |

The operation suite's replacement cases simulate the failing `mv` and native
replacement boundary; they do not test the real PowerShell File.Replace API.
The adapter suite uses a fake Claude executable and consumes no model quota.
The first unrestricted-temp attempt was rejected by the ACL guard. After
isolating temp permissions, two operation fixtures failed before the fixes.
An intermediate adapter run was invalidated by editing its script while Bash
was reading it; the complete, unmodified rerun above is the validation result.
No live model dispatch, full suite, or Job Object cancellation acceptance was
performed. Temporary probe scripts and the private test parent were removed.

## Next acceptance work

- Keep Git Bash as the shell runtime and use PowerShell only at existing
  Windows OS boundaries; current findings do not justify a Python rewrite.
- Run Windows state tests from a private temporary root whose ACL satisfies
  the same policy as production state. Never globally bypass the ACL guard
  merely to make tests green.
- Validate native Job Object launch, identity, cancellation, and descendant
  cleanup separately. Passing mocked adapter tests does not establish these.
- After model quota is available, run one bounded reviewer end to end and
  check evidence reads, policy checks, verdict output, and terminal operation
  state. Classify quota, permission, timeout, and process failures separately
  before deciding whether retries help.
- Retain Linux/WSL2 release verification. The old Windows 10/0 hook acceptance
  record does not establish current dispatch/gate correctness.
