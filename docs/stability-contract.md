# Stability contract

> **Contract phase:** pm-dispatch is pre-1.0 and single-maintainer. This document
> defines the vocabulary and the promotion process; it does **not** yet freeze a
> broad surface. Every tier assigned here is frozen on *maintainer-exercised +
> test-suite-covered* evidence, **not** clean-machine dogfood (CC-447 is
> environment-blocked). A wider `stable` surface waits on that dogfood.

pm-dispatch exposes two kinds of surface a downstream fork can build on: the
`pmctl` command-line interface, and a set of on-disk **schemas** (JSON/YAML
documents the runtime reads or writes). This document says which parts carry a
compatibility promise, what counts as breaking each one, and how a surface is
retired.

## The four layers

| Layer | What it covers | Promise |
|---|---|---|
| **Stable CLI** | `pmctl` subcommands whose `cli/commands.tsv` row is `stability = stable` | SemVer-protected from v1.0; breaking change only in a MAJOR release, after a deprecation cycle |
| **Experimental CLI** | every other `pmctl` subcommand (`stability = experimental`) | none; signature, flags, output, and exit codes may change in any MINOR release |
| **Stable schema** | `core/schema/brief.schema.json`, `adapters/<name>/adapter.yaml` base fields, `hosts/<name>/host.yaml`, the gate-result verdict shape (the `Final: GO`/`Final: NO-GO` line and the `gate_reviewer_result_v1` `verdict` enum) | additive/back-compatible changes only without a `schema_version` bump; a breaking change bumps the integer and ships a migration or compatibility window |
| **Internal schema** | `ship-lanes.jsonl`, run-spec internal fields, sentinel/key-file layout, `.dispatch-results/` internal format, the `scripts/*.sh` compatibility shims | **explicitly not for external consumption**; may change in any release with no migration and no changelog "breaking" note |

`deprecated` is a transitional state a **Stable CLI** entry passes through on its
way out (see *Deprecation process*), not a fifth layer. The `cli/commands.tsv`
`stability` column therefore takes exactly `stable`, `experimental`, or
`deprecated`.

## Authority

`cli/commands.tsv` is the single machine-readable projection of the CLI tiers.
`pmctl commands --json`, `pmctl <area> <cmd> --help`, and the README command
index are all derived from it and checked for drift by
`tools/lint/lint-pmctl-commands.sh`. This document is the human contract; it does
not carry its own per-command copy of the tier data.

## SemVer scope — what counts as breaking

Version numbers are `MAJOR.MINOR.PATCH`. From v1.0, a **Stable** surface may only
break in a MAJOR release, and only after the *Deprecation process* below has run.
**Experimental** and **Internal** surfaces are exempt.

### Stable CLI

**Breaking (MAJOR only):**
- removing a subcommand or an existing flag
- changing the meaning of an existing flag
- adding a required positional or required flag
- changing a success exit code, or flipping an error path between zero and non-zero
- removing a field from `--json` output, or changing an existing field's type or meaning

**Not breaking (any MINOR/PATCH):**
- adding a subcommand or an optional flag
- adding a field to `--json` output
- rewording human-readable stdout/stderr — only `--json` output is a contract; text not covered by `--json` is not
- performance changes; clearer error text at an unchanged exit code

### Stable schema

**Breaking:** removing or renaming an existing field; making an existing optional
field required; narrowing an existing field's type or enum; changing the meaning
of `schema_version`. Crossing this line bumps the `schema_version` integer and
ships a migration or a compatibility window.

**Not breaking:** adding an optional field (additive, back-compatible — no
`schema_version` bump, per `docs/host-contract.md` §Versioning); adding an enum
value where consumers already fail open; relaxing validation.

### Internal schema

No promise. Any release may change these. The runtime owns both the producer and
the consumer; external tooling must not parse them.

## Deprecation process

1. **Announce** in `CHANGELOG.md` under the release that introduces the
   replacement, and mark the surface at its source (a banner in the doc, a
   `deprecated: use <x>` line in the shim, `stability = deprecated` in
   `cli/commands.tsv`).
2. **Retain** for at least one MINOR version after the announcement.
3. **Remove** in a later release; a Stable-CLI removal additionally requires a
   MAJOR bump.

**Target invariant:** the repository holds no surface marked deprecated without a
named removal version. This is not yet fully true — the `scripts/*.sh` shims (see
*Pending* below) carry a `deprecated:` marker with no sunset version. That single
known gap is owned by CC-446 Slice C, which assigns their removal version and
adds an enforcer; until then the invariant is a target, not a checked fact.
`tools/lint/lint-pmctl-commands.sh` already enforces the CLI-tier vocabulary and
the stable-read `--json` rule, but does not yet check named-sunset coverage.

### Already retired

- `pmctl guard check --profile <pm|codex|claude>` — superseded by
  `--role`/`--runtime` (CC-291); removed in v0.5.0.
- `scripts/codex-dispatch.sh` — the codex dispatch wrapper; removed in the v0.3.0
  sunset (logic now in `adapters/codex/dispatch.sh`).
- The `pr-gate-handover_v1` block and its fan-out route — the claude gate
  executor now dispatches an independent subprocess like codex; retired in v0.6.0
  (CC-383). `docs/pr-gate-handover-schema.md` is kept for historical reference.

  > `install.sh --profile minimal|full` is a **current** feature, unrelated to
  > the removed `guard check` alias above. It scopes which adapter hook set is
  > wired and is not deprecated.

### Pending

- `scripts/*.sh` (19 path-relocation shims from CC-489) — each prints
  `deprecated: use <new-path>` and re-execs the canonical script. Kept as an
  Internal-schema compatibility surface; a named sunset version is set by the
  CC-446 follow-up that also decides removal vs. formal support.

## Stable-CLI entries (v0 classification)

The first pass is deliberately small. A subcommand is `stable` only when its
signature has been unchanged for a release cycle, it has automated regression
coverage, and its output is either a machine contract (`--json`) or has no
structured-output obligation (a mutating action whose result is an exit code).

| Subcommand | Why stable |
|---|---|
| `commands` | the discovery primitive every other tool reads; trivial, `--json`, non-mutating |
| `state status` | the state-store compatibility report (CC-498), designed as a stable contract; `--json`, non-mutating |

**Stable candidates, not yet promoted:** `dispatch run` / `dispatch wait`
(dispatch lifecycle — promote after a rc cycle with no signature change),
`validate brief` (needs `--json` or a documented exclusion first), `gate verify`
(gate artifact family still in flux). Everything else is `experimental`.

`lint-pmctl-commands.sh` enforces: a `stable` non-mutating subcommand must have
`json = true`. There is no exclusion list — a stable read command that cannot
emit structured output stays `experimental` until it can.

## Related

- `docs/host-contract.md` — `host.yaml` schema and its `schema_version` rule
- `docs/adapter-contract.md` — `adapter.yaml` schema
- `docs/executor-contract.md` — the PM→executor handoff (current Layer-2
  isolation; supersedes the retired handover route)
- `cli/commands.tsv` — the machine-readable CLI tier projection
- `BACKLOG.md` CC-446 — the re-scope and the follow-up slices
