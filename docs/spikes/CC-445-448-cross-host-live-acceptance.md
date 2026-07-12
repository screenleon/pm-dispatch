# CC-445 / CC-448 — Claude + OpenCode host live acceptance

Both hosts receive the exact request in
[`fixtures/CC-445-448-host-acceptance-request.md`](fixtures/CC-445-448-host-acceptance-request.md)
and must return `host_acceptance_v1`. Capability differences are expected;
preparation, memory continuity, bounded completion, and absence of unexpected
writes are the common invariants.

Before each host run, capture the dirty/clean baseline from an ordinary shell:

```bash
git status --porcelain=v1 > /tmp/cc445-448-before.status
```

## Claude host

In an existing authenticated Claude Code TUI opened at the repository root,
type `/pm `, paste the complete fixture content on the same request, and only
then submit it:

```text
/pm <paste the complete host-acceptance fixture here>
```

Claude may use its native project-PM orchestration to reason, but the request prohibits worker
dispatch and implementation. Its host-level `command_guard` may honestly be
`none`; that is not a failure.

## OpenCode host — formal stage-3 wiring

Use a throwaway OpenCode config while retaining the operator's normal auth and
session data:

```bash
export CC448_XDG=/tmp/cc448-formal-opencode-config
export CC448_CLAUDE=/tmp/cc448-formal-claude-home
export CC448_BIN=/tmp/cc448-formal-bin

XDG_CONFIG_HOME="$CC448_XDG" \
CLAUDE_CONFIG_DIR="$CC448_CLAUDE" \
PMCTL_BIN_DIR="$CC448_BIN" \
bash install.sh --profile minimal --enable-host opencode

XDG_CONFIG_HOME="$CC448_XDG" \
opencode run --dir /home/screenleon/github/pm-dispatch \
  --command pm \
  --format json \
  "$(<docs/spikes/fixtures/CC-445-448-host-acceptance-request.md)"
```

The OpenCode result must additionally show that its native policy remains
effective: catch-all Bash is denied and the checkout-specific `pmctl` command
path is allowed. The previously completed guard probe supplies that negative
evidence; this run confirms the formally installed `/pm` asset uses the same
path.

After preserving the result, verify doctor and uninstall symmetry:

```bash
XDG_CONFIG_HOME="$CC448_XDG" bash scripts/doctor.sh --json \
  | jq -c 'select(.host == "opencode")'

XDG_CONFIG_HOME="$CC448_XDG" \
bash scripts/uninstall-host-opencode.sh

test ! -e "$CC448_XDG/opencode/opencode.json"
test ! -e "$CC448_XDG/opencode/commands/pm.md"
```

## Comparison

Compare the two JSON objects field by field:

- common hard requirements: command loaded, correct working directory/focus,
  snapshot created, readable canonical memory, no query failure, no timeout,
  no tracked writes;
- Claude-specific accepted boundary: host command guard may be `none`;
- OpenCode-specific hard requirement: native command guard is blocking with
  catch-all deny plus checkout-specific pmctl allow;
- both results must resolve the same `memory_project_key`.

After each host run, verify that the tracked/untracked status is unchanged:

```bash
git status --porcelain=v1 > /tmp/cc445-448-after.status
cmp /tmp/cc445-448-before.status /tmp/cc445-448-after.status
```

Do not close CC-445/CC-448 if either host fails the common invariants, if the
project keys differ, or if formal OpenCode uninstall leaves managed files.

## Results — 2026-07-12

| Host | `/pm` | Focus | Snapshot | Memory | Prompt/timeout | Verdict |
|---|---|---|---|---|---|---|
| Claude | loaded | CC-445, CC-448 | created | legacy / hydrated / readable | none | GO |
| OpenCode round 1 | loaded | empty | created | legacy / hydrated / readable | none | FAIL — fixed bootstrap request |
| OpenCode round 2 | loaded | CC-445, CC-448 | created | legacy / hydrated / readable | none | GO |

Both successful hosts resolved project key
`4633b7e7f780014195b603f84ce281c3a1afd97b`. OpenCode's earlier independent
guard probe also passed: catch-all Bash deny blocked non-pmctl commands while
the checkout-specific pmctl allow rule remained usable. Round-1 remediation
replaced shell-output bootstrap injection with an argv-safe `pm_prepare`
custom tool carrying the exact request and focus list.
