# Script domain ownership and migration inventory

This document defines the planning baseline for separating the repository's
shell code by ownership. It is deliberately contract-first: no path in the
inventory is active merely because it appears here. A path becomes active only
when its consumers, tests, manifest or registry entry, and compatibility shim
move together in a verified migration slice.

The inventory was captured on 2026-07-15 and became the migration ledger for
every file that was then below `scripts/`. It now records each historical path,
its canonical owner path, and whether the historical path remains a shim.

## Inventory artifacts

- [`script-domain-inventory.tsv`](script-domain-inventory.tsv) is the complete
  historical-to-canonical path map. It contains 170 rows.
- [`script-variable-inventory.tsv`](script-variable-inventory.tsv) records
  cross-module inputs, ambient environment, legacy aliases, resolved config,
  fault-injection families, and secret passthrough. Module-local scratch
  variables are intentionally excluded unless their derivation changes when a
  file moves.
- [`script-variable-consumers.tsv`](script-variable-consumers.tsv) is the
  checked-in static variable-to-consumer graph. It maps every declared exact or
  wildcard variable to its current production or test references without
  treating comments or shell parsing as runtime data flow.
- [`script-domain-reference-allowlist.tsv`](script-domain-reference-allowlist.tsv)
  records the bounded production consumers that must recognize a retired path
  to migrate already-installed configuration. Shim paths are derived directly
  from the path inventory and therefore do not belong in this allowlist.

The complete path, shim-target, variable, and consumer contracts are ratcheted
together by:

```bash
bash tools/lint/lint-script-domain-inventory.sh
```

The linter rejects untracked or missing scripts, invalid owner-to-target
mappings, stable paths without shims, undeclared or unreferenced variables,
unsafe consumer paths, a stale static consumer graph, and retired
implementation paths in current operational docs or code. The stale-reference
ratchet derives exact historical-to-canonical pairs from the inventory: it does
not reject the unrelated `pm/scripts/` tree or installed
`~/.claude/scripts/` helper ABI, and it excludes historical spike evidence.
`CHANGELOG.md` and `BACKLOG-ARCHIVE.md` are historical records and are likewise
outside the operational-document scan. Current `BACKLOG.md` remains enforced;
`MILESTONES.md` enforcement covers only unimplemented planning sections and
never rewrites completed phases or released-version history.
Consumer filesystem checks treat repository and relative paths as data without
constructing shell commands. Its regression fixtures are registered as
`test-script-domain-inventory` in the shared suite runner.

The TSV files are planning contracts, not runtime registries. Production code
must not read them to locate modules.

## Target ownership domains

| Domain | Canonical root | Owns | Must not own |
|---|---|---|---|
| Shared runtime | `runtime/{bin,hooks,lib}` | canonical CLI workflows, state, memory, context, guard primitives, supervisors | named host defaults or test fault injection |
| Host modules | `hosts/<host>/{bin,hooks,lib}` | host config roots, lifecycle hooks, install, uninstall, doctor | executor model selection or canonical project state |
| Executor adapters | `adapters/<name>/` | model aliases, timeout/effort resolution, isolation mapping, native output parsing | PM-host installation or shared dispatch flow |
| Test harness | `tests/{bin,shell,lib,fixtures}` | suite registry, runners, fixtures, fault injection | production defaults or operator state |
| Operations | `ops/{backlog,diagnostics,migrations,release,setup,usage}` | maintainer workflows and migrations | host runtime policy hidden behind an ops script |
| Tooling | `tools/{lint,skills}` | static validation and repository authoring helpers | runtime business logic |
| Compatibility | existing `scripts/` paths | time-bounded forwarding shims only | a second implementation or divergent defaults |

The canonical owner distribution is:

- test harness: 85 files
- shared runtime: 58 files
- host modules: 9 files across Claude, Codex, and OpenCode
- operations: 10 files
- tooling: 8 files

## Allowed dependency direction

The allowed direction is from an entrypoint toward its declared owner, then
toward shared primitives and declarative definitions:

```text
public entrypoint or compatibility shim
  -> host module | shared runtime | ops | test harness | tooling
  -> shared runtime primitives
  -> core policy and schema definitions
```

Additional constraints:

- `core/` remains declarative and never depends on executable layers.
- Host modules may call the public `pmctl` surface or shared runtime primitives;
  they must not source another host's module.
- Executor adapters remain orthogonal to PM hosts. They may use adapter-local
  data and approved shared primitives, but must not absorb shared dispatch flow
  or host install logic.
- Operations use public CLI/runtime contracts. An ops tool must not become a
  hidden alternate implementation of memory, state, gate, or host resolution.
- Test code may depend on every production layer. Production layers must never
  source test helpers or honor test-only variables outside explicit test seams.
- Compatibility shims may validate arguments and locate the new implementation;
  they must not resolve defaults independently.

## Module invocation contract

Moving a file changes `BASH_SOURCE` and directory depth. A host or runtime
module therefore cannot use `SCRIPT_DIR/..` as an implicit repository ABI.
Migration slices must converge on these inputs:

1. Repository root is passed explicitly as `--repo-root <absolute-path>` or an
   equivalent positional API owned by the dispatcher.
2. Mutation mode is passed explicitly (`--dry-run` where supported).
3. Host selection comes from the manifest entry chosen by the dispatcher, not
   from the filename or a host-name branch in shared code.
4. The callee validates that the supplied root contains the expected manifest
   and refuses relative, missing, or escaping paths.
5. Direct legacy entrypoints translate their existing CLI into the new ABI and
   preserve stdout, stderr, exit status, and filesystem side effects.
6. Environment inheritance is not an API. Variables accepted across the module
   boundary must appear in the variable inventory and be covered by parity
   tests.

The manifest write dispatcher now enforces the first compatibility slice of
this contract for the Codex and OpenCode install/uninstall modules. It accepts
only an absolute repository root, resolves the manifest-selected module, and
invokes it with `--repo-root <absolute-path>` plus `--dry-run` when requested.
Those four modules validate the supplied checkout before sourcing repository
libraries. Their historical direct-call forms remain valid and derive the root
from the compatibility path, but a dispatcher call no longer depends on that
path depth. Relocated Codex and OpenCode fixtures exercise install, managed
state ownership, and uninstall through the manifest dispatcher.

## Variable ownership rules

The variable inventory distinguishes five boundary classes:

1. **Public override**: documented operator input with a stable precedence rule.
2. **Host root or legacy alias**: resolved only by the owning host module.
3. **Resolved config**: produced by shared config resolution and passed narrowly
   to the consumer; `PM_CFG_*` does not become host-owned.
4. **Internal/test injection**: bounded seam for supervisors or tests; never a
   production default.
5. **Secret passthrough**: inherited only by the intended executor process and
   never rendered into logs, artifacts, receipts, manifests, or diagnostics.

The following rules are migration blockers:

- Claude's canonical config root and its legacy alias must resolve in one
  host-owned function shared by install, uninstall, doctor, and hook wiring.
- Shared manifest code must not permanently name `CODEX_HOME`,
  `CLAUDE_CONFIG_DIR`, or `XDG_CONFIG_HOME`. Host manifests/resolvers must supply
  the bounded expansion contract without `eval`.
- A test that may install or uninstall must replace the entire `HOME`, or set
  every write-root override including `PMCTL_BIN_DIR`. Overriding only a host
  home is insufficient.
- `PATH`, `TMPDIR`, XDG directories, repo root, and working directory are part
  of behavior parity even when they are not product configuration.
- Model, timeout, effort, and isolation inputs belong to the executor-adapter
  axis unless they configure the PM host itself.

## Consumer graph

### Installation and host lifecycle

```text
install.sh / uninstall.sh
  -> shared host manifest and write dispatcher
  -> hosts/<host>/host.yaml
  -> declared install or uninstall module
  -> host-owned config resolver and format handler

doctor entrypoint
  -> shared doctor coordinator
  -> manifest-declared host doctor module
```

Claude's base installation remains a special asset-orchestration path, but its
install, uninstall, doctor, and hook wiring share the manifest-declared
`hosts/claude/lib/path-resolver.sh` contract. Codex and OpenCode resolve their
manifest targets through equivalent host-owned modules, and all host write
implementations live below `hosts/<host>/`.

### PM, dispatch, and gate

```text
cli/pmctl
  -> shared runtime libraries
  -> supervisor or validator entrypoint
  -> manifest-selected executor adapter
  -> trace, state, and result verification
```

The CLI remains the stable coordinator. Relocating an implementation must not
create host-specific dispatch branches in `cli/pmctl`.

`pr-gate` consumes canonical-memory resolution and context packing through the
same shared runtime libraries; shared runtime must not call back up through the
public `cli/pmctl` coordinator. Reviewer policy files outside the reviewed
workspace are trusted installation assets. Policy files inside the reviewed
workspace are snapshotted from the trusted base revision, never from the dirty
or feature working tree being reviewed.

### Hooks and canonical project state

```text
host hook binding
  -> thin host hook or shared hook entrypoint
  -> cli/pmctl guard, context, or memory command
  -> canonical shared runtime
```

Host hooks may supply provenance and payload adaptation. They do not own a copy
of canonical memory, context, guard, or state logic.

### Tests and release verification

```text
run-tests / run-all-tests compatibility entrypoint
  -> test suite registry and runner
  -> tests/shell and tooling/lint
  -> result artifact verification

release verification
  -> public test runner contract
  -> E2E and release-specific checks
```

Suite discovery comes from one test registry. Relocation must not introduce a
second suite list elsewhere.

## Stable entrypoints and shims

Nineteen current paths require a compatibility shim according to the inventory.
They fall into three groups:

- Installed user tools: `doctor.sh`, `log-usage.sh`, `patch-gitignore.sh`,
  `pr-gate.sh`, `setup-project.sh`, and `token-usage.sh`.
- Maintainer contracts: `brief-validate.sh`, `release-verify.sh`,
  `run-all-tests.sh`, and `run-tests.sh`.
- Existing host wiring: Claude/Codex/OpenCode install and uninstall modules plus
  the currently installed host hook paths.

A shim must:

1. contain no business logic or independent default resolution;
2. resolve the repository root without assuming the new module's depth;
3. forward arguments and exit status exactly;
4. emit deprecation information on stderr without corrupting machine-readable
   stdout;
5. remain covered by a direct legacy-entrypoint parity test.

A shim may be removed only when all of these are true:

- manifests, registries, installers, tests, and current documentation use the
  new path;
- repository search finds no non-historical consumer of the old path;
- an install/upgrade cycle has replaced managed external links or copied files;
- the announced compatibility window has elapsed;
- removal passes install, uninstall, doctor, focused parity, full runner, and
  release smoke checks.

Historical backlog, changelog, and spike records are evidence and are not
rewritten merely to erase an old path string.

## Executed migration order

1. Lock this inventory and add behavior tests for environment precedence,
   filesystem side effects, relocated checkouts, and full-home isolation.
2. Introduce the explicit module invocation ABI while implementations remain at
   their current paths.
3. Consolidate host-owned root/default/legacy-alias resolvers and remove named
   host environment branches from shared expansion.
4. Use OpenCode install, uninstall, and doctor as the first physical relocation
   slice; retain old paths as shims.
5. Apply the proven contract to Codex, then Claude.
6. Relocate the test harness, shared runtime, tooling, and operations by domain.
7. Remove shims only through the criteria above.

## Physical relocation status

Physical relocation is complete. All 170 canonical targets exist in their
declared domains; 151 internal historical paths are absent, and `scripts/`
contains exactly the 19 compatibility shims declared by the inventory. The
ratchet verifies both file-set equality and that every shim names its declared
canonical target, so a present-but-misdirected forwarder fails validation.

The CLI, manifests, host installers, suite registry, changed-path planner,
documentation, and CI invoke canonical owner paths. Installed user-tool names
remain stable while their sources come from `runtime/` or `ops/`; reinstall
refreshes copied or linked assets without changing that external ABI. Host
config roots and aliases remain host-owned, while their common leading-token
template expansion is shared and replaces only the declared prefix.

Shim removal remains a future compatibility-window decision governed by the
criteria above. No implementation is allowed to move back under `scripts/`.
