# Host manifest contract (`hosts/<name>/host.yaml`, schema v1)

A **host** is the runtime the PM itself runs inside (Claude Code, Codex CLI,
opencode). A host manifest declares, as static facts, what pm-dispatch can
wire onto that host: which files an installer would own, what hook/permission
surface exists, which guard capabilities the host can carry, and where the
host's doctor/uninstall modules live.

This is the **sister structure** of the executor adapter manifest
(`adapters/<name>/adapter.yaml`). The two describe orthogonal axes:

| Axis | Manifest | Question it answers |
|---|---|---|
| Host (PM itself) | `hosts/<name>/host.yaml` | "When this CLI is the PM runtime, what guard/doctor/install plumbing can it host?" |
| Executor (PM→worker) | `adapters/<name>/adapter.yaml` | "When the PM dispatches this CLI as a worker subprocess, how is it launched and guarded?" |

They must never merge semantics. `runner_kind`, `write_guard_mode`, and
`needs_bash_guard` are adapter-axis fields and do not appear in a host
manifest; a host gaining a native hook does not change how the same CLI
behaves as a dispatched executor.

## Design rules

- **Manifest holds static facts; judgment stays in code.** Paths, formats,
  event names, capability declarations belong here. Detection strategy,
  probing, install planning, and migrations live in scripts — the manifest is
  not a programming language.
- **Declared / probed / effective layering.** The manifest is the *declared*
  layer. The host's doctor module reports the *probed* layer
  (`emit_capability` records). *Effective* is what an end-to-end guard test
  observes. A manifest must never declare more than a probe has demonstrated;
  when the layers disagree, the lower one wins.
- **No host-specific branches in core.** Adding a host means adding a
  `hosts/<name>/` directory (manifest + doctor module), not editing core
  scripts. This mirrors the executor-adapter acceptance rule.
- **No maintainer-local layout assumptions.** Target paths are expressed via
  the host's own home variable (`$CODEX_HOME`, `$XDG_CONFIG_HOME`, …), never
  via a hard-coded user directory.

## Top-level fields

| Field | Required | Meaning |
|---|---|---|
| `schema_version` | yes | Positive integer; this document describes version `1`. |
| `host_name` | yes | Host identifier; must equal the `hosts/<name>/` directory name. |
| `host_binary` | yes | CLI binary probed on `$PATH` to consider the host present. |
| `install_targets` | yes | List of files the install write path would own or assert (see below). |
| `hook_surface` | yes | Hook runtime facts: config format, event names, headless requirements. May be an empty map for hosts with no hook system. |
| `guard_bindings` | yes | List of guard capability declarations (see below). |
| `permissions_surface` | yes | The host's native permission model outside the hook surface. Carries `config_target` (must reference an `install_targets` entry `id`) and `managed` (boolean: whether the install write path manages that surface). |
| `doctor_module` | yes | Repo-relative path to the sourceable doctor host module; must exist. |
| `uninstall_module` | yes | Repo-relative path to the uninstall module, or `null` while no install write path exists. |

### `install_targets` entries

| Field | Meaning |
|---|---|
| `id` | Stable identifier other sections reference (e.g. `permissions_surface.config_target`). |
| `path` | Target path, expressed with the host's home env var. |
| `format` | One of the format-handler enum below. |
| `managed` | `true` if the install write path owns the file content; `false` if it is only read/asserted (doctor visibility). |

### Format handlers

Closed enum; adding a value is a schema revision, not a per-host improvisation:

- `claude-settings-json` — Claude Code `settings.json` (hooks block, permissions).
- `codex-hooks-json` — `hooks.json` under the codex home; same hooks-block
  shape as Claude Code `settings.json` (probed: codex reads this file, not a
  `config.toml` section).
- `codex-config-toml` — codex `config.toml` (approval/sandbox policy).
- `opencode-config-json` — `opencode.json` declarative permission config.
- `markdown-managed-block` — owned marker-delimited block inside a Markdown file.
- `symlink-tree` — directory wired as symlinks back into the repo.
- `copy-tree` — directory materialized as copies (single-file/copy-mode installs).

### `hook_surface`

| Field | Meaning |
|---|---|
| `config_format` | Format handler the hook wiring uses. |
| `events` | Hook event names the host runtime exposes. |
| `headless_required_flags` | Optional. Flags a headless invocation must pass for hooks to fire at all (see "Hook trust in headless runs"). |

Hosts whose guard story is purely declarative config (no hook scripts) declare
an empty `hook_surface: {}` rather than inventing pseudo-events.

## Capability object (`guard_bindings` entries)

Field names align **verbatim** with the doctor `emit_capability` tuple so the
declared and probed layers stay mechanically comparable:

| Field | Enum | Meaning |
|---|---|---|
| `capability` | `command_guard`, `file_guard`, `session_lifecycle`, `pm_command_interface`, `statusline` | The semantic capability being declared. |
| `binding_form` | `hook-script`, `config-fragment`, `none` | What artifact realizes the binding: an executable hook script wired into the host's hook surface, or a fragment merged into the host's declarative config. Never assume a guard binding is a script — opencode's is config. `none` means no binding artifact exists or has been designed, and is legal only when `provider` is `none`; an evaluated-but-unsupported capability may instead keep its anticipated form (e.g. `hook-script`) to record what the binding would be once its gaps close. |
| `provider` | `host_hook`, `host_policy`, `host_native`, `cli_wrapper`, `doc_instruction`, `none` | Mechanism class providing the capability. |
| `enforcement` | `blocking`, `approval`, `advisory`, `none` | What a violation does. |
| `coverage` | `full`, `partial`, `none` | How much of the capability's surface the binding reaches. |
| `stability` | `stable`, `evolving` | Whether the host mechanism is still moving. |
| `confidence` | `observed`, `probed`, `declared`, `assumed` | Evidence strength, strongest first: observed in production use > probed end-to-end once > declared by host docs > assumed. |

Optional per-entry field `payload_fields` maps guard-check inputs to the
host's payload field paths, documenting how the binding feeds
`pmctl guard check`. Its keys are a closed set — `command`, `cwd`,
`file_path` — because an unknown key would declare an input the guard CLI
cannot consume.

**Full enumeration**: every value of the closed `capability` enum must appear
exactly once in `guard_bindings` — a missing entry is a validation error, not
a statement. A capability the host cannot currently carry is declared with
`provider: none` / `enforcement: none` / `coverage: none`, and its
`confidence` field distinguishes the two `none` states doctor output needs to
tell apart:

- `confidence: probed` (or `observed`) on a `none` entry means **evaluated and
  unsupported** — a probe demonstrated the host cannot carry it today.
- `confidence: assumed` on a `none` entry means **not yet evaluated** — the
  unsupported declaration is a placeholder awaiting a probe, and such an entry
  typically pairs with `binding_form: none`.

Omissions carry no semantic meaning; the manifest validator rejects them.

## Closure-of-all-paths acceptance clause

A **file guard** binding may be declared with `coverage` above `none` only if
it closes *every* write path the host exposes — including generic shell
execution. Both probed hosts fail this today in the same structural way:

- codex: `apply_patch` payloads embed the target path in patch text (no
  `file_path` field; a parser is required), and shell redirection
  (`cat > file`) writes through the Bash tool without surfacing any file path.
- opencode: `edit: deny` alone is bypassed by the model writing the file via
  the still-allowed `bash` tool (probed: the file was really created).

Guarding only the edit/write-specific tools while leaving bash open is not a
partial file guard — it is not a file guard. Such a state must be declared
`provider: none` (with the command guard carrying whatever command-pattern
mitigation exists), and the adapter-axis `write_guard_mode: cli-only`
brief-level guard remains the fallback. The same rule applies symmetrically:
a host that can deny bash but not edit tools cannot claim `command_guard`
closure over file writes.

Manifests must also not assume a conservative deny-everything default is
usable: probing showed that denying all execution tools simultaneously can
hang a headless run instead of failing cleanly. Until a host's all-deny
behavior is verified, declare only the specific bindings that were probed.

## Hook trust in headless runs

Hook-carrying hosts may gate hook execution behind an interactive trust
prompt. Probed on codex: a headless `codex exec` with hooks configured hangs
indefinitely (not fail-closed) unless `--dangerously-bypass-hook-trust` is
passed, and no persisted trust store or trust subcommand exists. For hooks the
PM generated itself from this repo's own manifest, that flag is therefore the
*headless enablement condition*, not a bypass of an unknown third party's
code: the "danger" in the flag name refers to trusting foreign hooks, which
does not apply to self-authored ones. Manifests record such flags in
`hook_surface.headless_required_flags` so dispatch paths treat them as
mandatory, because omitting them silently deadlocks the pipeline rather than
degrading it.

## Versioning

`schema_version` is a positive integer. Additive, backward-compatible fields
may land within a version; removing or re-typing a field, or extending a
closed enum, bumps the version. The manifest validator accepts only versions
it knows how to check (currently `1`) — a manifest declaring a newer version
fails validation until the validator learns that version's rules. Once the repo-wide stability contract lands,
`host.yaml` joins the stable-schema tier and changes become subject to its
deprecation policy.

## Worked example: opencode as a second host

The schema was finalized against two probed hosts specifically so that no
field encodes a codex-ism. This walkthrough expresses the opencode probe
results in schema v1 terms; the actual `hosts/opencode/host.yaml` ships with
the opencode wiring work, not with this document.

```yaml
schema_version: 1
host_name: opencode
host_binary: opencode
install_targets:
  - id: config
    path: "$XDG_CONFIG_HOME/opencode/opencode.json"
    format: opencode-config-json
    managed: true
# No hook scripts: the guard story is declarative permission config
# (permission.bash / permission.edit: allow|ask|deny, with per-pattern
# objects for bash). The JS plugin system exists but is unprobed; nothing
# is declared for it.
hook_surface: {}
guard_bindings:
  - capability: command_guard
    binding_form: config-fragment     # a merged config fragment, not a script
    provider: host_policy             # declarative policy, not a hook process
    enforcement: blocking
    coverage: full                    # per-pattern bash rules probed fail-closed
    stability: evolving
    confidence: probed
  - capability: file_guard
    binding_form: config-fragment
    provider: none                    # edit:deny alone is bypassed via bash;
    enforcement: none                 # closure-of-all-paths not yet met, and
    coverage: none                    # all-deny hangs headless runs (unverified root cause)
    stability: evolving
    confidence: probed
  # Full enumeration: the remaining capabilities have not been evaluated on
  # this host — none tuple with confidence assumed, not omission.
  - capability: session_lifecycle
    binding_form: none
    provider: none
    enforcement: none
    coverage: none
    stability: evolving
    confidence: assumed
  - capability: pm_command_interface
    binding_form: none
    provider: none
    enforcement: none
    coverage: none
    stability: evolving
    confidence: assumed
  - capability: statusline
    binding_form: none
    provider: none
    enforcement: none
    coverage: none
    stability: evolving
    confidence: assumed
permissions_surface:
  config_target: config
  managed: true
doctor_module: scripts/lib/doctor-host-opencode.sh
uninstall_module: null
```

Points the walkthrough demonstrates:

- `binding_form: config-fragment` and `provider: host_policy` carry the
  declarative-config host without any schema change — the guard binding is
  not assumed to be a script.
- The closure-of-all-paths clause produces the same honest `none` declaration
  for both hosts' file guards, for the same structural reason (edit/write
  tools and shell execution are separate gates).
- Full enumeration keeps the two `none` states distinguishable: the file
  guard is `none`/`probed` (evaluated, unsupported), while the three
  unevaluated capabilities are `none`/`assumed` placeholders — nothing is
  omitted.
- Denying a whole tool declaratively is *cleaner* than hook interception (the
  tool is never exposed to the model) but yields no per-attempt payload to
  audit; a host needing blocked-attempt logging must layer a plugin hook,
  which would be a new probed binding, not a silent upgrade of this one.
- `hook_surface: {}` is legal: a host with no hook system still has a full
  guard story through policy.
