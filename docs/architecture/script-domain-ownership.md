# Script domain ownership and migration inventory

This document defines the planning baseline for separating the repository's
shell code by ownership. It is deliberately contract-first: no path in the
inventory is active merely because it appears here. A path becomes active only
when its consumers, tests, manifest or registry entry, and compatibility shim
move together in a verified migration slice.

The inventory was captured on 2026-07-15. It covers every file below
`scripts/` and separates path ownership from variable/configuration ownership.

## Inventory artifacts

- [`script-domain-inventory.tsv`](script-domain-inventory.tsv) is the complete
  current-to-proposed path map. It contains 174 rows: 119 executable scripts,
  52 sourced libraries, and 3 fixtures.
- [`script-variable-inventory.tsv`](script-variable-inventory.tsv) records
  cross-module inputs, ambient environment, legacy aliases, resolved config,
  fault-injection families, and secret passthrough. Module-local scratch
  variables are intentionally excluded unless their derivation changes when a
  file moves.
- [`script-variable-consumers.tsv`](script-variable-consumers.tsv) is the
  checked-in static variable-to-consumer graph. It maps every declared exact or
  wildcard variable to its current production or test references without
  treating comments or shell parsing as runtime data flow.

The path inventory is complete when this comparison has no output:

```bash
comm -3 \
  <(find scripts -type f -printf '%p\n' | sort) \
  <(tail -n +2 docs/architecture/script-domain-inventory.tsv | cut -f1 | sort)
```

The complete path, variable, and consumer contracts are ratcheted together by:

```bash
bash scripts/lint-script-domain-inventory.sh
```

The linter rejects untracked or missing scripts, invalid owner-to-target
mappings, stable paths without shims, undeclared or unreferenced variables,
unsafe consumer paths, and a stale static consumer graph. Consumer filesystem
checks treat repository and relative paths as data without constructing shell
commands. Its regression fixtures are registered as
`test-script-domain-inventory` in the shared suite runner.

The TSV files are planning contracts, not runtime registries. Production code
must not read them to locate modules.

## Target ownership domains

| Domain | Proposed root | Owns | Must not own |
|---|---|---|---|
| Shared runtime | `runtime/{bin,hooks,lib}` | canonical CLI workflows, state, memory, context, guard primitives, supervisors | named host defaults or test fault injection |
| Host modules | `hosts/<host>/{bin,hooks,lib}` | host config roots, lifecycle hooks, install, uninstall, doctor | executor model selection or canonical project state |
| Executor adapters | `adapters/<name>/` | model aliases, timeout/effort resolution, isolation mapping, native output parsing | PM-host installation or shared dispatch flow |
| Test harness | `tests/{bin,shell,lib,fixtures}` | suite registry, runners, fixtures, fault injection | production defaults or operator state |
| Operations | `ops/{backlog,diagnostics,migrations,release,setup,usage}` | maintainer workflows and migrations | host runtime policy hidden behind an ops script |
| Tooling | `tools/{lint,skills}` | static validation and repository authoring helpers | runtime business logic |
| Compatibility | existing `scripts/` paths | time-bounded forwarding shims only | a second implementation or divergent defaults |

The current owner distribution is:

- test harness: 85 files
- shared runtime: 58 files
- host modules: 13 files across Claude, Codex, and OpenCode
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

Claude's base installation is currently a special path and must reach the same
module contract before its physical relocation. Codex and OpenCode already have
manifest-declared optional modules, but their declared paths still point into
`scripts/`.

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

Suite discovery must eventually come from one test registry. Relocation cannot
replace the current hard-coded suite map with a second list elsewhere.

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

## Migration order

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

## Known blockers before physical relocation

- The shared path expander still contains named host variables and defaults.
- Claude config-root precedence is repeated across multiple entrypoints.
- Host write modules still infer the repository from their current directory
  depth and the dispatcher does not pass an explicit repository-root argument.
- The suite registry and changed-path mapping contain current `scripts/` paths.
- Installed symlinks and generated hook commands embed current paths.
- Full environment isolation is not expressed as one reusable test contract.

These are expected inputs to the behavior-lock and module-ABI phase. They are
not authorization to begin a bulk rename.
