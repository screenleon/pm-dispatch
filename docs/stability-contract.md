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
   replacement, and mark the surface at its source (a `> **DEPRECATED`/`RETIRED`
   banner in the doc, a `deprecated: use <x>` line in the shim, `stability =
   deprecated` in `cli/commands.tsv`).
2. **Retain** for at least one MINOR version after the announcement.
3. **Remove** in a later release; a Stable-CLI removal additionally requires a
   MAJOR bump.

**Invariant:** every deprecation marker in the project names a removal or
retirement version, or is a compat surface with a named owner and a drift check.
Two enforcers keep this true:

- `tools/lint/lint-deprecation-sunset.sh` — scans the docs deprecation banners,
  `core/schema/*.schema.json` `deprecated` keywords, and `cli/commands.tsv`
  `stability = deprecated` rows; each must name a `vX.Y[.Z]` version or be listed
  in `tools/lint/deprecation-sunset-allowlist.tsv` with a reason.
- `tools/lint/lint-script-domain-inventory.sh` — the CC-489 ratchet that owns the
  `scripts/*.sh` path shims (see *Retained compatibility* below): every shim has a
  declared owner, a canonical target, and an executable-target check in
  `docs/architecture/script-domain-inventory.tsv`.

`tools/lint/lint-pmctl-commands.sh` additionally enforces the CLI-tier vocabulary
and the stable-read `--json` rule.

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

### Retained compatibility

- `scripts/*.sh` (19 path-relocation shims from CC-489) — each prints
  `deprecated: use <new-path>` to stderr and re-execs the canonical script under
  `runtime/`, `ops/`, `hosts/`, `tools/`, or `tests/bin/`. These are an
  Internal-schema compat surface **deliberately retained with no dated sunset**:
  they are pure path aliases with zero behaviour, and they are governed —
  `docs/architecture/script-domain-inventory.tsv` records every shim's owner and
  canonical target, and `tools/lint/lint-script-domain-inventory.sh` fails if a
  shim is missing, non-executable, or points at the wrong target. Because they
  have an owner and a drift check they satisfy the invariant without a version;
  they are not scanned by `lint-deprecation-sunset.sh`. A future PR may still
  retire the `move-with-shim` tier, but that is a change to the CC-489 ratchet,
  not a loose end.

## Stable-CLI entries (v0 classification)

The first pass is deliberately small. A subcommand is `stable` only when its
signature has been unchanged for a release cycle, it has automated regression
coverage, and its output is either a machine contract (`--json`) or has no
structured-output obligation (a mutating action whose result is an exit code).

| Subcommand | Why stable | Contract regression lock |
|---|---|---|
| `commands` | the discovery primitive every other tool reads; trivial, `--json`, non-mutating | `tests/shell/test-pmctl-discovery.sh` → `case_commands_json_contract` |
| `state status` | the state-store compatibility report (CC-498), designed as a stable contract; `--json`, non-mutating | `tests/shell/test-state-status.sh` → `case_compatible_store_json_contract` (happy-path `--json` key set + exit 0), `case_future_version_fail_closed` (exit 3) |

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
- `tools/lint/lint-deprecation-sunset.sh` + `tools/lint/deprecation-sunset-allowlist.tsv` — the sunset-version enforcer
- `docs/architecture/script-domain-inventory.tsv` — owns the `scripts/*.sh` path shims (CC-489 ratchet)
- `BACKLOG.md` CC-446 — the re-scope; CC-578 — the spun-out authority-tagging work
