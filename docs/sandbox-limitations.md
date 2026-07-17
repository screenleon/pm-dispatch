# Sandbox Limitations and Workarounds

The pm-dispatch main thread (your terminal) has full access to your machine.
Codex executor briefs run inside a sandboxed environment with restricted access.
Understanding the boundary helps you write `self_verify` blocks that actually work.

## Capability boundary

| Resource | Main thread | Codex sandbox |
|---|---|---|
| Project files | read/write | read/write |
| `/home` (outside project) | read/write | read-only |
| Docker socket | available | not available |
| Network (outbound) | available | not available (verify in practice) |
| TCP localhost | available | **not available** by default; available with `--isolation workspace-network` |
| `~/.cache/go/build` (GOCACHE) | read/write | not writable (read-only `/home`) |
| `/tmp` | read/write | read/write |

> **Network note**: The Codex sandbox runs in an isolated network namespace by default.
> TCP connections to localhost services started by the main thread are **not reachable**
> from inside the sandbox (confirmed by empirical test: curl exit 7, connection refused).
> To enable TCP localhost access, use `--isolation workspace-network` when running the gate —
> this sets `sandbox_workspace_write.network_access=true` via the codex adapter. See Pattern 3.

## Pattern 1: Infrastructure setup before/after gate (Docker, DBs, etc.)

> **Security notice — `--allow-hooks` required**: Hook scripts are loaded from
> `.pm-dispatch/` inside the checked-out repository. A branch under review may
> supply or modify these scripts. By default pm-dispatch skips hooks and prints a
> warning. Pass `--allow-hooks` only for repositories and branches you trust.
>
> ```bash
> bash runtime/bin/pr-gate.sh --cd . --allow-hooks
> ```

The gate lifecycle hooks let the main thread start and stop infrastructure
around the gate run. Place hook scripts in `.pm-dispatch/` at your project root:

| Hook | When it runs | Executor support | Failure behaviour |
|---|---|---|---|
| `.pm-dispatch/pre-gate.sh` | before any reviewer dispatch | codex, claude | non-zero exit aborts the entire gate |
| `.pm-dispatch/post-gate.sh` | after gate completion, **only when gate result is GO** | codex, claude | non-zero exit marks gate as failed |

**Hook contract**:
- Runs as the main thread user (full machine access).
- Working directory is set to the project root (`$WORK_DIR`).
- If the file exists but is not executable, pm-dispatch prints a warning and skips it.
- Non-zero exit from either hook aborts the gate.
- **`--allow-hooks` required**: hooks are skipped by default unless this flag is passed.

> **Executor routes behave identically**: both `--executor codex` and
> `--executor claude` dispatch the reviewers as an independent headless subprocess
> and complete the gate in-process (the older claude "emit a handover block and
> exit before reviewers run" route was retired). Pre-gate and post-gate therefore
> fire the same way on both routes — `post-gate.sh` runs after gate completion on
> either executor when the result is GO.

**Two post-gate usage patterns**

Depending on your use case, choose the right approach:

**(A) Teardown that must always run** (e.g., `docker compose down`, even if a reviewer fails):
Wrap `pr-gate.sh` in a shell function or CI step that uses a `trap` in the
**caller**, not inside `pre-gate.sh`. The hook exits after setup; any `trap`
inside it cleans up immediately, not after the gate finishes.

```bash
# wrapper script or CI step
#!/usr/bin/env bash
set -euo pipefail
cleanup() { docker compose -f docker-compose.test.yml down; }
trap cleanup EXIT

docker compose -f docker-compose.test.yml up -d db
until docker compose -f docker-compose.test.yml exec -T db pg_isready -q; do sleep 1; done

bash runtime/bin/pr-gate.sh --cd . --allow-hooks
```

The teardown trap is now in scope for the full gate run. Alternatively, use a
CI `finally` / `always` block for the same effect.

**(B) Action that should run only on gate success** (e.g., posting a Slack notification, tagging a build):
Use `post-gate.sh` directly. It runs only after all reviewers and synthesis succeed.

```bash
# .pm-dispatch/post-gate.sh — success-only action
#!/usr/bin/env bash
set -euo pipefail
# Only reached when gate verdict is GO
curl -s -X POST "$SLACK_WEBHOOK" -d '{"text":"Gate passed — ready to open PR"}'
```

Make hook files executable after creating them:

```bash
chmod +x .pm-dispatch/pre-gate.sh .pm-dispatch/post-gate.sh
```

## Pattern 2: Go build in brief self_verify

Go requires a writable build cache (`GOCACHE`, default `~/.cache/go/build`).
Because `/home` is read-only inside the Codex sandbox, `go build` fails unless
you redirect the cache to `/tmp`.

**Minimal fix** — add this to every `self_verify` block that calls `go`:

```yaml
self_verify:
  - cmd: "GOCACHE=/tmp/go-cache go build ./..."
    expect: "exits 0"
  - cmd: "GOCACHE=/tmp/go-cache go test ./..."
    expect: "exits 0"
```

**Why not `GOPATH=/tmp/gopath`?** Setting `GOPATH` to `/tmp` severs access to
the module cache (`$GOPATH/pkg/mod`), causing all modules to re-download — which
fails without network access. `GOCACHE` controls only compiled artifacts and is
the minimal correct intervention.

**Vendor mode (alternative)**: If your project uses `go mod vendor`, you can
run `go build -mod=vendor ./...` without any cache at all. This is useful for
strict reproducibility but requires the vendor directory to be committed.

## Pattern 3: Integration tests that need a live service

Because the Codex sandbox is network-isolated, integration tests that connect
to a database or other TCP service must run on the **main thread**, not inside
a Codex brief's `self_verify` block.

The correct pattern: run integration tests in `pre-gate.sh` (which has full
machine access), then let gate reviewers check the code. The reviewers only need
to read the diff — they do not re-run the tests.

```bash
# .pm-dispatch/pre-gate.sh — start DB, run integration tests, stop DB
#!/usr/bin/env bash
set -euo pipefail

cleanup() { docker compose -f docker-compose.test.yml down 2>/dev/null || true; }
trap cleanup EXIT

docker compose -f docker-compose.test.yml up -d db
until docker compose -f docker-compose.test.yml exec -T db pg_isready -q; do sleep 1; done

# Run integration tests on the main thread (full network access)
make test-integration
```

Then run the gate:

```bash
bash runtime/bin/pr-gate.sh --cd . --allow-hooks
```

**Why this works**: `pre-gate.sh` runs as the main-thread user with full Docker and
network access. If `make test-integration` fails, the hook exits non-zero and the gate
aborts before dispatching any reviewers. If it passes, reviewers proceed to review the
code diff only — they do not need network access.

**Codex `self_verify` limitation**: By default, the sandbox is network-isolated and
cannot reach localhost services — do not add DB-connection commands to `self_verify`
blocks unless the gate was invoked with `--isolation workspace-network`, which enables
TCP localhost access inside the executor. The pre-gate.sh pattern above remains the
preferred approach for integration tests because failures abort the gate before any
token budget is spent.

**Alternative — `--executor claude`**: If you need reviewers to run commands that
require network access, use `--executor claude`. The claude executor runs as an
independent headless `claude --print` subprocess (not an in-session subagent, and
does not inherit the main thread's environment) — grant it network access the same
way as codex, via `--isolation workspace-network`.

**When to use pre-gate.sh vs `--isolation workspace-network`**

| Situation | Recommended approach |
|---|---|
| Integration tests must pass *before* reviewers see the diff (fail fast, save token budget) | `pre-gate.sh` with `--allow-hooks` (Pattern 3) |
| The executor needs live TCP access *during* `self_verify` (e.g., a running service already started by the user) | `--isolation workspace-network` |
| Teardown must run on both success and failure | Caller-level `trap cleanup EXIT` (Pattern 1A) |
| Reviewers need network access (external API calls, package downloads) | `--executor claude` (inherits main-thread environment) |

## Pattern 4: git commit blocked in executor sandbox

`git add` and `git commit` inside the executor sandbox are blocked by the
executor sandbox permission model. This is by design: the executor must not push to the branch
autonomously. Current enforcement is via the executor dispatch layer; future
adapters may also provide adapter-specific bash guards for additional safety.

**Impact**: A brief that ends with a `git commit` step will always fail that
step, causing the dispatch report to show `status: partial` even when all code
changes were applied correctly. The commit block in `self_verify` also fails
post-verify.

**Fix (Option A — recommended)**: Do not include `git add` / `git commit` in
brief `self_verify` or `task` blocks. Commit is always delegated to the main
thread after you review the executor's diff.

Brief `self_verify` pattern — correct:
```yaml
self_verify:
  - cmd: "bash scripts/test.sh"
  - git-status no-collateral-damage
```

Brief `self_verify` pattern — **incorrect** (always fails):
```yaml
self_verify:
  - cmd: "git add -A && git commit -m 'feat: ...' "   # blocked by hook — omit this
```

**There is no allow-list workaround**: the commit delegation rule is structural, not
a hook policy toggle — executors MUST NOT include a commit step in briefs, `self_verify`,
`constraints`, or `acceptance` (see `docs/dispatch-brief.md` §Commit delegation rule).
Commit is always the main thread's job, after reviewing the diff.

**Standard workflow**: After `pmctl dispatch run` finishes:
1. Review the executor's diff with `git diff` / `git status`
2. Stage and commit from the main thread: `git add <files> && git commit`

## Pattern 5: apply_patch intermediate failures

When the executor edits a large or structurally complex file using
`apply_patch`, the patch may not apply cleanly if the surrounding context has
changed since the brief was written. The executor usually detects this, re-reads
the file, and retries — succeeding on the second attempt.

**Impact**: Noise in the dispatch trace; adds 1–2 minutes per occurrence; can
appear as a "non-fatal error in stderr" in the post-verify report even when all
changes are actually applied correctly.

**Fix**: Break large file edits into smaller, anchored hunks in the brief's
`task:` block. Give each hunk a short, unique anchor string (a nearby function
name, a distinctive comment, a unique variable name) so the executor can
unambiguously locate the insertion point:

```yaml
task:
  Edit runtime/bin/pr-gate.sh:
  - Locate the line starting with "WORK_DIR=" (search uniquely identifies this line)
  - After that line, add: ...
  - Separately locate the line "cd "$WORK_DIR"" and add below it: ...
```

This is brief-authoring discipline, not a tool limitation — the executor handles
uniquely-anchored hunks reliably.

## Adding new patterns

Encountered a sandbox constraint not covered here?
[Open an issue](https://github.com/screenleon/pm-dispatch/issues) with the
label `docs` and describe the constraint and workaround you found.
