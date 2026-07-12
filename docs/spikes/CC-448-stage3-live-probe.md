# CC-448 stage 3 — OpenCode live probe record

This document records the isolated live probe used before the stage-3 write
path was implemented. The ticket-specific package generator was intentionally
removed after the probe completed: it was neither a production tool nor an
automated test, and keeping it under `scripts/` made the supported CLI surface
ambiguous.

The throwaway package used a private `XDG_CONFIG_HOME` and compared four rows:

| Profile | Probe | Question |
|---|---|---|
| control | pm | Can a custom command obtain deterministic `pmctl pm prepare` JSON? |
| deny-all | pm | Does a catch-all Bash deny also block command-template shell expansion? |
| allow-pmctl | pm | Does a later checkout-specific pmctl rule preserve the PM path? |
| allow-pmctl | guard | Does the catch-all still deny an unrelated Bash command? |

The matrix separates three facts that must not be conflated:

1. A custom command can inject deterministic `pmctl pm prepare` output.
2. A global Bash deny may or may not govern custom-command shell-output
   expansion; the `deny-all pm` row determines this empirically.
3. A last-match-wins allow rule for `pmctl` can preserve the PM path while the
   catch-all denies unrelated Bash; the `allow-pmctl guard` row verifies the
   negative side.

## Outcome

- OpenCode custom-command integration could obtain parseable
  `pmctl pm prepare` JSON.
- Permission patterns use last-match-wins behavior: catch-all deny followed by
  a checkout-specific pmctl allow preserved the PM path.
- The same policy denied an unrelated Bash command and did not create the
  sentinel file.
- The first fixed bootstrap command later proved insufficient for preserving
  request-specific focus tickets. The shipped implementation therefore uses
  the argv-safe `pm_prepare` custom tool and is covered by
  `scripts/test-host-write-opencode.sh` instead of this probe harness.

The maintained acceptance evidence now lives in
`docs/spikes/CC-445-448-cross-host-live-acceptance.md`, while ownership,
rollback, hostile-path serialization, and generic preflight behavior are
executable regression tests. Reproduction should use those supported surfaces,
not restore the retired ticket-specific generator.

References: OpenCode permissions use last matching pattern precedence, and
custom commands support shell-output injection in their prompt templates:
<https://opencode.ai/docs/permissions/>,
<https://opencode.ai/docs/commands/>.
