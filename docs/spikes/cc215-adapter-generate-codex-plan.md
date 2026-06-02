# CC-215 Spike: `pmctl adapter generate` Implementation Plan

Date: 2026-05-28

Scope: planning only. This spike does not change production code.

## Recommended option

Recommend the shortcut path: **Option C now, with a required D-compatible stub `adapter.yaml`**.

The first implementation should generate an executable shell adapter immediately, because the repo is bash-first today and `pmctl` will be called from hooks where startup cost matters. The generated `run.sh` can be tested with the current `scripts/lib/test-harness.sh` style by asserting file creation, mode bits, idempotency, dry-run behavior, expected argv, and refusal of unsafe adapter names. Requiring a tiny `adapter.yaml` at the same time avoids making the shell wrapper the only source of truth.

This is the best complexity fit for a solo bash maintainer. Full Option D is architecturally better, but it forces schema, manifest parsing, doctor semantics, generated-file checksum policy, and adapter introspection before the CLI has stabilized. Option C-only is easier, but it creates an opaque adapter surface that `pmctl doctor`, future MCP, and layer-boundary tests cannot reason about. The stub manifest keeps the implementation small while preserving the migration path.

If this choice is wrong, the breakage is specific:

- If full D is attempted too early, CC-215 can stall on manifest design and YAML parsing rules instead of delivering a usable `pmctl` MVP.
- If C-only ships, later `doctor` and MCP work will need to reverse-engineer shell files or introduce a breaking adapter migration.
- If A is chosen, the repo keeps duplicating `commands/pm.md` prose and every CLI grows its own prompt drift.
- If B is chosen, generation produces inert config and still needs a runner before any adapter can execute.

## File layout

`pmctl` itself should be added under `cli/` and keep subcommands in sourceable bash libraries:

```text
cli/
  pmctl                         main executable; parses global flags and routes subcommands
scripts/lib/
  pmctl-adapter.sh              adapter subcommands, including pmctl_adapter_generate
  pmctl-fs.sh                   small shared helpers: repo root, mkdir, atomic write, chmod
  pmctl-policy.sh               enum/policy helpers over core/policy/*.yaml simple lists
  executor-router.sh            from CC-200; dispatch route selection and adapter lookup
  handover-validator.sh         from CC-202; handover parse/validation facade
  hook-framework.sh             from CC-204; hook/guard entrypoint conventions
```

`pmctl adapter generate <name>` should create exactly these files:

```text
adapters/<name>/
  adapter.yaml                  authored stub manifest; source of truth for executor and map refs
  isolation-map.yaml            generated starter map from core/policy/isolation-level.yaml values
  run.sh                        generated executable shim; DO-NOT-EDIT; calls pmctl dispatch/run path
  README.md                     generated human install notes for wiring the target CLI to run.sh
```

The generator should not create `commands/pm-<name>.md` or `agents/<name>.md` in the first implementation. That is Option A leakage. CLI-native command files can be added later as adapter-specific install steps if a target CLI requires them, but their content should point at `adapters/<name>/run.sh` rather than duplicating PM dispatch logic.

For `codex`, the concrete output paths are:

```text
adapters/codex/adapter.yaml
adapters/codex/isolation-map.yaml
adapters/codex/run.sh
adapters/codex/README.md
```

## `adapter.yaml` minimum schema

Keep the M3 stub to 8 fields. It must be a deliberately tiny YAML subset: one scalar per line plus a simple `generated_files` list. No nested objects until the full Option D schema lands.

| Field | Type | Description |
|---|---|---|
| `schema_version` | integer | Adapter manifest schema version. Start at `1`. |
| `adapter_name` | string | Directory-safe adapter name; must match `^[a-z][a-z0-9_-]*$`. |
| `executor` | string | Executor enum value from `core/policy/executor-enum.yaml`. |
| `cli_binary` | string | Native CLI command the adapter expects on `PATH`, e.g. `codex`. |
| `isolation_map_ref` | string | Relative path to this adapter's isolation map. |
| `runner_ref` | string | Relative path to generated executable shim. |
| `dispatch_contract` | string | Contract identifier the runner expects, initially `dispatch_handover_v1`. |
| `generated_files` | string list | Relative generated files that may be overwritten by regeneration. |

Example for `codex`:

```yaml
schema_version: 1
adapter_name: codex
executor: codex
cli_binary: codex
isolation_map_ref: ./isolation-map.yaml
runner_ref: ./run.sh
dispatch_contract: dispatch_handover_v1
generated_files:
  - isolation-map.yaml
  - run.sh
  - README.md
```

## Bash skeleton

The function must be defined before dispatch, otherwise bash will execute the `case` before the function exists. This skeleton is intentionally plain bash plus `jq` availability checking only; it writes a simple YAML subset with heredocs and reads enum YAML with line-based parsing because no YAML parser is allowed.

```bash
#!/usr/bin/env bash
# cli/pmctl - pm-dispatch runtime CLI

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# shellcheck source=scripts/lib/pmctl-adapter.sh
[[ -r "$REPO_ROOT/scripts/lib/pmctl-adapter.sh" ]] && . "$REPO_ROOT/scripts/lib/pmctl-adapter.sh"

pmctl_die() {
  printf 'pmctl: %s\n' "$*" >&2
  exit 2
}

pmctl_require_jq() {
  command -v jq >/dev/null 2>&1 || pmctl_die "jq not found"
}

pmctl_validate_adapter_name() {
  local name="${1:-}"
  [[ "$name" =~ ^[a-z][a-z0-9_-]*$ ]] || pmctl_die "invalid adapter name: $name"
}

pmctl_policy_values() {
  local file="$1"
  awk '
    $1 == "-" {
      value = $2
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
      if (value != "") print value
    }
  ' "$file"
}

pmctl_policy_contains() {
  local file="$1" wanted="$2"
  pmctl_policy_values "$file" | grep -Fx -- "$wanted" >/dev/null
}

pmctl_write_new_file() {
  local path="$1" mode="${2:-0644}"
  if [[ -e "$path" ]]; then
    pmctl_die "refusing to overwrite existing file: ${path#$REPO_ROOT/}"
  fi
  umask 022
  cat >"$path"
  chmod "$mode" "$path"
}

pmctl_adapter_generate() {
  local name="${1:?pmctl: adapter generate requires <name>}"
  local adapter_dir executor_file isolation_file
  local isolation_level native_flags

  pmctl_require_jq
  pmctl_validate_adapter_name "$name"

  adapter_dir="$REPO_ROOT/adapters/$name"
  executor_file="$REPO_ROOT/core/policy/executor-enum.yaml"
  isolation_file="$REPO_ROOT/core/policy/isolation-level.yaml"

  [[ -r "$executor_file" ]] || pmctl_die "missing policy file: core/policy/executor-enum.yaml"
  [[ -r "$isolation_file" ]] || pmctl_die "missing policy file: core/policy/isolation-level.yaml"

  if ! pmctl_policy_contains "$executor_file" "$name"; then
    pmctl_die "adapter name is not in executor enum: $name"
  fi

  mkdir -p "$adapter_dir"

  pmctl_write_new_file "$adapter_dir/adapter.yaml" 0644 <<EOF
schema_version: 1
adapter_name: $name
executor: $name
cli_binary: $name
isolation_map_ref: ./isolation-map.yaml
runner_ref: ./run.sh
dispatch_contract: dispatch_handover_v1
generated_files:
  - isolation-map.yaml
  - run.sh
  - README.md
EOF

  {
    printf '# adapters/%s/isolation-map.yaml\n' "$name"
    printf '# Generated by pmctl adapter generate %s.\n\n' "$name"
    printf 'mappings:\n'
    while IFS= read -r isolation_level; do
      case "$name/$isolation_level" in
        codex/none) native_flags='{ "--sandbox": "danger-full-access" }' ;;
        codex/read-only) native_flags='{ "--sandbox": "read-only" }' ;;
        codex/workspace-write) native_flags='{ "--sandbox": "workspace-write" }' ;;
        codex/sandboxed) native_flags='{ "--sandbox": "workspace-write" }' ;;
        *) native_flags='{}' ;;
      esac
      printf '  %s:\n' "$isolation_level"
      printf '    native_flags: %s\n' "$native_flags"
    done < <(pmctl_policy_values "$isolation_file")
  } | pmctl_write_new_file "$adapter_dir/isolation-map.yaml" 0644

  pmctl_write_new_file "$adapter_dir/run.sh" 0755 <<'EOF'
#!/usr/bin/env bash
# Generated by pmctl adapter generate. DO NOT EDIT.

set -euo pipefail

ADAPTER_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$ADAPTER_DIR/../.." && pwd)"

exec "$REPO_ROOT/cli/pmctl" dispatch run --adapter "$(basename "$ADAPTER_DIR")" "$@"
EOF

  pmctl_write_new_file "$adapter_dir/README.md" 0644 <<EOF
# $name adapter

Generated by \`pmctl adapter generate $name\`.

Wire the target CLI command surface to execute:

\`\`\`bash
bash "$adapter_dir/run.sh" "\$@"
\`\`\`

Do not edit generated files listed in \`adapter.yaml\`; regenerate them with \`pmctl adapter generate $name\`.
EOF

  printf 'pmctl: generated adapter %s at %s\n' "$name" "${adapter_dir#$REPO_ROOT/}"
}

cmd="${1:-}"
shift 2>/dev/null || true
sub="${1:-}"
shift 2>/dev/null || true

case "$cmd/$sub" in
  adapter/generate) pmctl_adapter_generate "$@" ;;
  validate/handover) pmctl_validate_handover "$@" ;;
  dispatch/run) pmctl_dispatch_run "$@" ;;
  guard/check) pmctl_guard_check "$@" ;;
  ""/) pmctl_die "missing command" ;;
  *) pmctl_die "unknown command: $cmd $sub" ;;
esac
```

Tests should add a focused `scripts/test-pmctl-adapter-generate.sh` using `scripts/lib/test-harness.sh`. Minimum cases:

- rejects missing name and unsafe names
- rejects names absent from `core/policy/executor-enum.yaml`
- creates all four expected files for a temporary enum fixture
- writes executable mode for `run.sh`
- refuses to overwrite existing adapter files
- generated `run.sh` contains a single `exec "$REPO_ROOT/cli/pmctl" dispatch run --adapter ...` path

## Risks

Risk: YAML is not parseable with `jq` and the project has no `yq` dependency -> Mitigation: keep M3 `adapter.yaml` to a tiny line-oriented YAML subset and document that full nested schema waits for the D phase.

Risk: `pmctl adapter generate codex` cannot succeed until `codex` is present in `core/policy/executor-enum.yaml` -> Mitigation: make the failure explicit; adding an executor remains a schema-breaking policy change, not generator side effect.

Risk: generated shims drift after manual edits -> Mitigation: mark generated files with `DO NOT EDIT`, list them in `generated_files`, refuse overwrite in M3, and add checksum/idempotent regeneration only when full D lands.

Risk: `sandboxed` has no obvious Codex-native equivalent in the current `handover.schema.json`, which accepts `workspace-write`, `read-only`, and `danger-full-access` -> Mitigation: map `sandboxed` conservatively to `workspace-write` for the starter map and require CC-202/doctor to flag lossy mappings.

Risk: adapter generation accidentally revives markdown command duplication -> Mitigation: generate only `README.md` for human wiring notes; do not generate `commands/pm-<name>.md` or agent persona files in CC-215.

## Batch A dependencies

CC-200 (`scripts/lib/executor-router.sh`) should provide the dispatch path that generated `run.sh` calls indirectly through `pmctl dispatch run`:

- `pmctl` sources `executor-router.sh` to resolve `--adapter <name>` to `adapters/<name>/adapter.yaml`.
- `pmctl` uses router helpers to choose the native executor path and to build safe argv for `scripts/codex-dispatch.sh` or future adapter runners.
- `pmctl` should not duplicate the `commands/pm.md` route table; CC-200 owns route selection for `executor: codex` vs `executor: claude`.

CC-202 (`scripts/lib/handover-validator.sh`, likely wrapping today’s `scripts/lib/handover-validate.sh`) should provide validation and parsing surfaces:

- `pmctl` sources the validator to extract `dispatch_handover_v1`, split metadata/body, validate required fields, and enforce safe argv.
- `pmctl adapter generate` can stay mostly independent, but generated runners need the validator when they accept a handover block or brief file.
- `pmctl doctor` later should reuse validator/policy helpers to compare `adapter.yaml` executors with `core/policy/executor-enum.yaml` and isolation maps with `core/policy/isolation-level.yaml`.

CC-204 (`scripts/lib/hook-framework.sh`) is not a hard dependency for `adapter generate` itself:

- `pmctl` sources the hook framework for `pmctl guard check`, not for file generation.
- If an adapter later installs CLI hook entrypoints, those entrypoints should call `pmctl guard check` rather than embedding hook logic in `adapters/<name>/run.sh`.
- The only CC-204 pattern CC-215 should copy is the sourceable-library boundary: no top-level side effects, caller owns `set -euo pipefail`, and tests use `scripts/lib/test-harness.sh`.
