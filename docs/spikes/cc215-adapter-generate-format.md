# Spike: `pmctl adapter generate` — Format Option Analysis

**Date**: 2026-05-28  
**Ticket**: CC-215 (pmctl MVP)  
**Constraint**: near-zero runtime deps (bash + jq only; no Python/Node/Go)  
**Method**: Explore agent (codebase survey) + Opus agent (design analysis), parallel

---

## What We Already Know From The Repo

The only existing adapter artifact is `adapters/claude/isolation-map.yaml` — a pure YAML
translation table mapping `core/policy/isolation-level.yaml` enum values to executor-native flags.
This is the **only adapter-shaped precedent** and it is YAML-only.

`v0.3.0-synthesis.md` §4 states the invariant:
> Adapters know: how one CLI invokes things, how to render output.
> Adapters must NOT know: schema internals, dispatch state transitions, guard rules.

`core/README.md` invariant 2 forbids CLI names (`codex`, `claude`, `antigravity`, `opencode`) as
path segments inside `core/` — CLI-specific bits live under `adapters/<name>/` only.

**Important**: Adding a new executor is a *breaking schema bump* to `core/policy/executor-enum.yaml`
and `handover.schema.json`, not an adapter-generate concern. `pmctl adapter generate` is about
delivery-surface plumbing: surfacing a `/pm`-equivalent command and emitting valid handover blocks.

---

## Four Options

### Option A — Markdown template generation

Produces `agents/<name>-pm.md` + `commands/pm-<name>.md`, mirroring today's Claude convention.

| | |
|---|---|
| **Zero-dep fit** | Excellent |
| **MCP-future fit** | Poor |

**Pros**
- Trivial to implement; copies existing Claude pattern exactly.
- LLM host CLI reads prompt natively.

**Cons**
- Propagates the v0.3.0 anti-pattern (`commands/pm.md` "prose with embedded bash") that the
  synthesis explicitly targets for removal.
- Each target CLI has a different loader convention (Codex: `AGENTS.md`/`~/.codex/`; OpenCode:
  different layout; Antigravity: again different). "Markdown" hides divergence without solving it.
- No machine-readable contract: `pmctl doctor`, layer-boundary tests, and future MCP cannot
  introspect what an adapter declares.
- Hard to keep in sync with `core/policy/` changes.

**Verdict**: Cheapest, but propagates the architecture defect v0.3.0 is built to remove. Acceptable only as a temporary bridge.

---

### Option B — YAML/JSON config generation only

Produces `adapters/<name>/config.yaml` with agent persona, command triggers, isolation mapping,
pmctl invocation pattern. Nothing reads it unless a shim or the CLI natively supports it.

| | |
|---|---|
| **Zero-dep fit** | Good (JSON fine; YAML needs care with jq) |
| **MCP-future fit** | Best |

**Pros**
- Single declarative source of truth; consistent with `core/policy/*.yaml` style.
- Machine-readable: `pmctl doctor`, layer tests, MCP can introspect.
- Per-CLI divergence becomes data, not duplicated prose.
- Cleanly versionable (`schema_version` convention already established).

**Cons**
- No target CLI today loads a pm-dispatch-shaped YAML. Inert without a runner.
- LLM persona (multi-KB Markdown blob) cannot live cleanly in a YAML key — either embed Markdown
  in YAML (escaping hell with jq) or reference a separate `.md` (back to Option A + manifest).
- Risk of inventing a private DSL no one outside pm-dispatch reads.

**Verdict**: Architecturally cleanest, but ships nothing executable on its own. Needs a shell shim to be a complete adapter.

---

### Option C — Shell wrapper generation only

Produces `adapters/<name>/dispatch.sh`. The target CLI invokes the script; the script wraps pmctl
calls in the idiom that specific CLI expects.

| | |
|---|---|
| **Zero-dep fit** | Excellent |
| **MCP-future fit** | Poor |

**Pros**
- Matches CC-266 commitment (`adapters/claude/dispatch.sh` shape) — already-blessed pattern.
- Executable: ships the actual thing the new CLI calls.
- Bash + jq substrate; perfect fit for zero-dep constraint.
- Trivially testable with `test-harness.sh`.

**Cons**
- Generator needs N templates internally; divergence is moved, not eliminated.
- No machine-readable surface: `pmctl doctor` can't tell what executor an adapter declares
  without grepping the script.
- Future MCP wrapper has nothing structured to consume.
- Drift risk between adapter scripts and core schemas.

**Verdict**: Solves "executable today" and matches CC-266, but loses the introspection benefits of `core/policy/*.yaml`.

---

### Option D — Hybrid: declarative spec + generated shell shim ✅ Recommended

Produces both:
- `adapters/<name>/adapter.yaml` — source of truth (executor, isolation-map, command trigger,
  pmctl invocation template, output-contract paths)
- `adapters/<name>/run.sh` + other shims — *generated* from the YAML by `pmctl adapter generate`,
  marked `DO-NOT-EDIT`, regenerable

Re-running `pmctl adapter generate <name>` rebuilds shims from spec; spec is the authored artifact.

| | |
|---|---|
| **Zero-dep fit** | Good (bash heredoc + jq substitution) |
| **MCP-future fit** | Best |

**Pros**
- One source of truth → ships an executable. Addresses both gaps in B and C.
- Matches existing repo idiom: `adapters/claude/isolation-map.yaml` is already this kind of YAML
  spec. Option D just adds the codegen step — the pattern is not new.
- Layer-boundary test, doctor, and future MCP read YAML; no need to parse shell.
- Drift between adapters and `core/policy/` becomes machine-detectable (`pmctl doctor` can flag
  adapters referencing an unknown executor or isolation level).
- Re-generation is idempotent: when `handover.schema.json` bumps `handover_version`, regenerating
  all adapters is one command.
- Persona prompt stays as a separate `.md` reference — avoids YAML-embedded-Markdown ugliness.

**Cons**
- Two artifacts per adapter to keep coherent; "DO-NOT-EDIT" shims require discipline (or CI
  checksum enforcement).
- Generator is more complex than C (templater, not just copier). Still bash+jq-feasible.
- Requires committing to `adapter.yaml` field schema upfront (small design task A/C avoid).
  Mitigation: start with ≤10 fields — the union of `isolation-map.yaml` +
  `{executor, command_trigger, invokes_pmctl, schema_version: 1}`.

**Verdict**: Only option that honors v0.3.0's extraction principle, reuses the existing adapter precedent, gives MCP something to discover, and ships an executable shim — all within bash + jq.

---

## Recommendation

**Adopt Option D.**

The existing `adapters/claude/isolation-map.yaml` is already half of Option D's YAML spec.
The codegen step is the only new piece.

**The key trade-off**: upfront schema design (≤10 fields, 1 hour of thinking) vs. long-term drift
cost. With four target CLIs committed in BACKLOG (`claude`, `codex`, `antigravity`, `opencode`),
the second adapter is not hypothetical — it is planned work. Option C's opaque-script drift costs
activate immediately on the second adapter.

### Safe Shortcut If Schedule Is Tight

**C-now → D-later**: Ship the shell wrapper generator first, but require it to *also* emit a stub
`adapter.yaml` containing `{executor, isolation_map_ref, schema_version: 1}`, even if nothing
reads the YAML in M3. This preserves the upgrade path without full manifest design today.

---

## `adapter.yaml` Minimum Schema (proposed, ~10 fields)

```yaml
schema_version: 1
executor: codex                        # must match core/policy/executor-enum.yaml
cli_name: codex                        # display name / invocation binary
isolation_map: ./isolation-map.yaml    # relative ref to isolation translation table
command_trigger: "codex /pm"           # how the user invokes the PM surface in this CLI
pmctl_dispatch: "pmctl task dispatch {task_id} --agent {executor}"
output_contract:
  trace_dir: .agent-trace
  last_file: .agent-trace/latest.last
persona_ref: ../../agents/project-pm.md   # shared persona (no duplication)
generated_files:
  - run.sh
```

---

## Files Referenced

- `adapters/claude/isolation-map.yaml` — existing adapter precedent
- `core/policy/executor-enum.yaml` — source of truth for valid executors
- `core/policy/isolation-level.yaml` — isolation enum consumed by isolation-map
- `core/schema/handover.schema.json` — dispatch contract executors must satisfy
- `docs/architecture/v0.3.0-synthesis.md` — definitive design authority
- `commands/pm.md` — the "prose with embedded bash" anti-pattern to phase out

---

## Next Step

Before writing the CC-215 implementation brief:
1. Confirm Option D (or C-now shortcut) with user
2. Finalize the `adapter.yaml` schema fields (can be done in the brief's `constraints:` section)
3. Batch CC-200 + CC-202 + CC-204 (reuse-debt extractions) as a prerequisite PR — these
   provide the shared lib surface that `pmctl` will source
