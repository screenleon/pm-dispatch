# Native Windows pr-gate attempt — 2026-09-22

## Subject and invocation

- PR: https://github.com/screenleon/pm-dispatch/pull/616
- Branch: `fix/gate-sequential-transport-retry`, HEAD `67115ff`.
- Subject: local `main` plus the working tree (`--allow-dirty`), including
  the existing Claude adapter changes and the Windows investigation fixes.
  This is not an attestation of the remote PR head alone.
- Command, through the explicit Git for Windows Bash executable:

  ```bash
  bash cli/pmctl gate run --cd . --base main --allow-dirty \
    --executor codex --mode sequential --lifecycle detached --timeout 900
  ```

- Gate: `gate-20260922-105342-489255`.
- Parent operation: `op-20260922T105335Z-29fac3`.
- Resolved reviewer model: `gpt-5.6-terra`, medium effort.
- Model-diversity limitation: the local Windows fixes were authored in this
  GPT-6 session; the original branch's implementation model was not verified.
  Codex was selected because the preceding Claude runs recorded weekly quota
  exhaustion. This is a same-family fallback, not independent model-family
  assurance; Claude quota was not rechecked live in this attempt.
- Coverage: critic, qa-tester, architecture-reviewer, security-reviewer.
  Policy recommended parallel; this run explicitly selected sequential.

## Result: incomplete / execution failure

The background Windows supervisor started, and its producer identity was
registered in the operation record. Context refresh exceeded its 90-second
bound and was skipped as optional. Scope generation completed and the Codex
reviewer started. The sequential recovery path attempted one retry.

The reviewer could read repository files using PowerShell, but the mandatory
pre-write guard could not execute: Git Bash inside the reviewer sandbox
crashed with `CreateFileMapping ... Win32 error 5`. The reviewer declined to
write the result, as required by the guard contract. The gate exhausted its
retry and terminated without reviewer sections or an authoritative verdict.

`pmctl gate wait gate-20260922-105342-489255 --cd . --timeout 30` reported:

```text
gate: gate-20260922-105342-489255  state: failed  exit: 2
operation: op-20260922T105335Z-29fac3  state: indeterminate  children: 0  unresolved: 1
pmctl gate wait: parent operation op-20260922T105335Z-29fac3 could not be reconciled from trusted child evidence
```

This is neither GO nor a reviewer NO-GO. Do not use the empty result file as
approval evidence. The parent-operation reconciliation issue remains open;
no state record was manually rewritten to make it appear complete.

## Sandbox diagnosis

Installed CLI: `codex-cli 0.154.0`. User configuration selects
`[windows] sandbox = "unelevated"`. A single-command probe of the alternative
backend, without editing the user config, was attempted:

```powershell
codex -c windows.sandbox=elevated sandbox -- 'C:/Program Files/Git/bin/bash.exe' --noprofile --norc --version
```

It failed before Bash startup:

```text
helper_sandbox_lock_failed: lock sandbox bin dir ...\.codex\.sandbox-bin failed:
SetNamedSecurityInfoW sandbox dir failed: 5
```

The inspected `.sandbox-bin` directory is owned by `BUILTIN\Administrators`;
the current user has Modify rather than FullControl. This is consistent with
the ACL-update denial, but does not establish that changing ownership alone
would repair all sandbox provisioning. Existing ACLs and user config were
left unchanged. No sandbox bypass or Python dependency was introduced.

Official guidance prefers the elevated native backend and identifies
administrator-approved provisioning as a prerequisite:
[OpenAI Windows sandbox documentation](https://learn.chatgpt.com/docs/windows/windows-sandbox).
Repair/re-run the supported sandbox setup with administrator approval, then
repeat the cheap Bash probe before spending model quota on another gate.

## Evidence locations

Under the canonical local state project partition
`977e786724346a12ee302cd8a817667f14986efb`:

- `runs/gate-20260922-105342-489255/supervisor-stdout.log`
- `runs/gate-20260922-105342-489255/.agent-trace/codex-20260922-201305-9910.jsonl`
- `operations/op-20260922T105335Z-29fac3.json`

Local scope artifact: `.gate-results/gate-scope-manifest-20260922-195433.json`.
Requested result: `.gate-results/gate-20260922-195433.md` (no valid verdict).

After sandbox repair, rerun the gate on the then-current subject and verify
the resulting artifact with `pmctl gate verify`. Separately investigate why
the terminal gate's operation had no trusted child evidence for reconciliation.
