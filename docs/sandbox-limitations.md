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
| TCP localhost | available | available |
| `~/.cache/go/build` (GOCACHE) | read/write | not writable (read-only `/home`) |
| `/tmp` | read/write | read/write |

> **Network note**: External network access from the Codex sandbox is currently unconfirmed.
> TCP connections to localhost (e.g. a DB started by a pre-gate hook) are reachable.
> Verify external connectivity in practice before relying on it in a brief.

## Pattern 1: Infrastructure setup before/after gate (Docker, DBs, etc.)

The gate lifecycle hooks let the main thread start and stop infrastructure
around the gate run. Place hook scripts in `.pm-dispatch/` at your project root:

| Hook | When it runs | Executor support | Failure behaviour |
|---|---|---|---|
| `.pm-dispatch/pre-gate.sh` | before any reviewer dispatch | codex, claude | non-zero exit aborts the entire gate |
| `.pm-dispatch/post-gate.sh` | after all reviewers finish (codex only, success path) | **codex only** | non-zero exit marks gate as failed |

**Hook contract**:
- Runs as the main thread user (full machine access).
- Working directory is set to the project root (`$WORK_DIR`).
- If the file exists but is not executable, pm-dispatch prints a warning and skips it.
- Non-zero exit from either hook aborts the gate.

> **`--executor claude` limitation**: On the claude executor route, `pr-gate.sh`
> emits a handover block and exits before reviewers run. `post-gate.sh` is therefore
> **not invoked** on that route (a notice is printed to stderr). Pre-gate works
> normally on both routes.

**Two post-gate usage patterns**

Depending on your use case, choose the right approach:

**(A) Teardown that must always run** (e.g., `docker compose down`, even if a reviewer fails):
Use a bash `trap` inside `pre-gate.sh` — cleanup is then guaranteed regardless of gate outcome.

```bash
# .pm-dispatch/pre-gate.sh — always-teardown via trap
#!/usr/bin/env bash
set -euo pipefail
cleanup() { docker compose -f docker-compose.test.yml down; }
trap cleanup EXIT
docker compose -f docker-compose.test.yml up -d db
until docker compose -f docker-compose.test.yml exec -T db pg_isready -q; do sleep 1; done
```

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

With the database running, the Codex sandbox can reach it via TCP localhost,
so brief `self_verify` commands like `go test ./...` will have a live DB available.

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

## Adding new patterns

Encountered a sandbox constraint not covered here?
[Open an issue](https://github.com/screenleon/pm-dispatch/issues) with the
label `docs` and describe the constraint and workaround you found.
