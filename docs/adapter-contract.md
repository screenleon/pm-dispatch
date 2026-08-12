# Adapter manifest dispatch contract

Status: accepted CC-531 contract (2026-08-11). Runtime, repo-layout and
copy-mode conformance fixtures, plus a matching current-tree full suite, passed
for closure.

## Scope and authority

Every Adapter is rooted at `adapters/<adapter>/` and has an `adapter.yaml`.
The manifest is the authored source of truth for Adapter metadata. For runtime
launch resolution, the sole canonical field is:

```yaml
schema_version: 1
adapter_name: example
runner_kind: cli-subprocess
dispatch_entrypoint: ./dispatch.sh
```

`dispatch_entrypoint` selects the executable that implements the Adapter's
dispatch contract. Outside the canonical reader's schema v1 fallback, no
runtime consumer may derive that path from the Adapter name, a built-in
allowlist, `runner_kind`, `runner_ref`, or a fixed `dispatch.sh` suffix.

The manifest itself is authored input and must not appear in `generated_files`.
New built-in manifests and `pmctl adapter generate` output must declare
`dispatch_entrypoint` and must not emit `runner_ref`.

## Schema v1 migration window

`runner_ref` predates a load-bearing dispatch field. Historical built-ins used
`runner_ref: ./dispatch.sh`, while generated manifests used
`runner_ref: ./run.sh`; the runtime actually launched `./dispatch.sh` by
convention. Treating `runner_ref` as a path now would therefore redirect old
generated Adapters to the wrong script.

For schema version 1, the canonical reader uses this bounded resolution table:

| `dispatch_entrypoint` | `runner_ref` | Runtime result |
|---|---|---|
| valid value | absent | use `dispatch_entrypoint` |
| valid value | any value, including a different value | use `dispatch_entrypoint`; `runner_ref` may produce a deprecation warning |
| absent | absent | deprecated fallback to `./dispatch.sh` |
| absent | `./dispatch.sh` | deprecated fallback to `./dispatch.sh`; do not read the value as a path |
| absent | `./run.sh` or any other value | deprecated fallback to `./dispatch.sh`; do not execute or reject because of the value |
| present but invalid | any value | reject; never recover through the legacy fallback |

This is a schema v1 compatibility window, not a second authority. The reader
may report machine-readable provenance such as `manifest` or
`schema_v1_dispatch_convention`, plus one stable deprecation diagnostic. A
future schema version may require `dispatch_entrypoint` and remove the fallback,
but that removal requires its own versioned migration decision.

`run.sh` may remain an Adapter-local helper or user-facing wrapper. It is not
selected by `runner_ref` and is not a runtime entrypoint unless a valid
`dispatch_entrypoint` explicitly names it.

## Safe relative-path contract

Before launch, the canonical reader must validate all of the following:

1. The value is a non-empty string beginning with `./`; it is not absolute,
   every segment after the leading `./` matches `[A-Za-z0-9._-]+`, and no
   segment is empty, `.` or `..`.
2. The value is data only. Shell expansion, command substitution, globbing, and
   `eval` must never be applied to it.
3. The Adapter directory is resolved to a physical path. No entrypoint path
   component may be a symlink, whether it resolves inside or outside the
   Adapter directory. This rule rejects symlink escapes without creating a
   second, resolution-dependent path identity.
4. The target remains below the exact physical Adapter-directory boundary,
   exists, is a regular file, and is executable. Prefix lookalikes such as
   `adapter-evil/` do not count. An absolute path, lexical traversal, symlinked
   component, missing target, directory, or non-executable target is rejected
   before dispatch.
5. `runner_kind` and its derived routing flags are valid under the existing
   runner-kind policy. A valid entrypoint cannot make an invalid runner
   topology routable.

Validation and execution must use the same resolved Adapter root and target;
callers must not validate one path and later reconstruct another from raw
manifest text.

## One reader, all consumers

Adapter enumeration, validation, executor routing, foreground dispatch,
detached supervisor re-validation, generator conformance, and Gate dispatch for
its supported reviewer-policy runtimes must call the same source-safe manifest
reader. That reader owns:

- Adapter identifier validation through the shared identifier policy;
- regular, non-symlink manifest trust-boundary checks;
- schema and `runner_kind` validation;
- canonical entrypoint selection and schema v1 fallback provenance; and
- safe physical-path resolution.

Consumers receive a validated result; they do not reparse `adapter.yaml` or
append `/dispatch.sh` themselves. Unknown fields do not become execution
instructions merely because a consumer recognizes their names.

Layout-aware callers pass the trusted deployment root to the canonical executor
router. Repo, installed-copy, and standalone-copy layouts may select different
roots, but they may not carry private copies of executor detection, route
selection, manifest parsing, argv construction, or conventional entrypoint
reconstruction.

## Copy-mode requirement

The installer carries every Adapter present in its source tree; dispatch-time
selection still comes only from the requested Adapter's validated manifest.
The receipt-owned installed-copy snapshot consists of:

- `adapters/<name>/` for each manifest and its referenced executable;
- `scripts/lib/` for the Gate shared runtime, including the canonical reader
  and its dependencies;
- `scripts/core/policy/isolation-level.yaml` for explicit Gate isolation;
- `runtime/lib/` for the bounded built-in Adapter bootstrap libraries;
- `share/` for built-in model-alias assets; and
- `ops/usage/log-usage.sh` for Adapter usage accounting.

These are deployment snapshots, not another path authority. The manifest still
selects the entrypoint, and every copied runtime resolves that manifest with the
same schema v1 migration and path rules used in repo-layout mode. Directory
receipt hashes declare the `logical-tree-v1` digest scheme and describe a
deterministic logical tree rather than archive order, so an untouched copy is
refreshable and uninstallable across filesystems. An older untagged tar-byte
directory receipt migrates only when its exact legacy digest can still prove
the installed copy untouched; ambiguous or unverifiable legacy state fails
closed without overwriting local bytes.

Installer preflight and application consume one ordered bundle inventory. Every
declared source must exist and be a readable regular file or directory during
preflight; a missing source is a conflict and records no receipt entry. Apply
publishes runtime, policy, and asset dependencies first, then the managed
reviewer and Adapter trees, and only then the Gate/doctor entrypoints. The same
inventory drives both phases so adding a load-bearing file cannot silently
update only validation or only installation.

Product receipt reads also have one authority. Install refresh, uninstall, and
doctor use the same full JSON/schema loader, which preserves escaped pathname
bytes, rejects malformed or duplicate-destination entries before mutation, and
propagates parser failures instead of hiding them behind line-oriented shell
parsing or process-substitution status.

If copy-mode cannot locate the canonical reader or manifest, or if the manifest
does not validate in the copied layout, it fails closed before launch. It must
not substitute an inline parser, a generated fixed path, or a hardcoded
`dispatch.sh` fallback outside the canonical reader. Copying the canonical
files is allowed; creating a second path authority is not. A foreign or modified
load-bearing bundle conflicts before copied entrypoints are wired, and installed
layout resolution cannot be shadowed by adjacent parent libraries, stale child
Adapter trees, reviewer directories, or host-local policy files.

## Conformance and closure

CC-531 acceptance requires deterministic evidence for at least:

- built-in and newly generated manifests declaring `dispatch_entrypoint` and
  omitting `runner_ref`;
- schema v1 manifests without the canonical field using the deprecated
  `./dispatch.sh` convention, including an old `runner_ref: ./run.sh` fixture;
- canonical values winning when stale `runner_ref` metadata differs;
- invalid canonical values failing closed without legacy recovery;
- absolute, traversal, boundary-prefix, any symlinked component, missing,
  directory, and non-executable targets being rejected;
- a custom Adapter changing only its manifest to `./worker.sh` and dispatching
  successfully without edits to shared runtime;
- repo-layout, copy-mode, foreground, detached, and supported Gate/router consumers
  resolving the same entrypoint and applying the same schema v1 fallback and
  deprecation diagnostic; and
- missing bundle sources producing no destination, receipt entry, or partial
  install; dependency/managed-tree/entrypoint ordering and receipt round trips
  remaining deterministic; and
- changed-path planning selecting every direct manifest consumer plus all Gate
  shards, with an exact-set ratchet that fails when the consumer set drifts; and
- an authoritative zero-skip full-suite PASS artifact whose source-tree
  fingerprint matches the accepted current tree.

CC-531 was closed only after all of this evidence was current. Future contract
changes must preserve the conformance fixtures and refresh the authoritative
full-suite artifact against the resulting source tree.
