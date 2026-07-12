# CC-448 stage 3 — OpenCode live probe runbook

This runbook tests the remaining host-interface question without touching the
operator's real OpenCode configuration.

Prepare a throwaway package:

```bash
bash scripts/prepare-cc448-opencode-probe.sh /tmp/cc448-opencode-stage3
```

Then run:

```bash
/tmp/cc448-opencode-stage3/run.sh control pm
/tmp/cc448-opencode-stage3/run.sh deny-all pm
/tmp/cc448-opencode-stage3/run.sh allow-pmctl pm
/tmp/cc448-opencode-stage3/run.sh allow-pmctl guard
test ! -e /tmp/cc448-opencode-stage3/guard-should-not-exist
```

The matrix separates three facts that must not be conflated:

1. A custom command can inject deterministic `pmctl pm prepare` output.
2. A global Bash deny may or may not govern custom-command shell-output
   expansion; the `deny-all pm` row determines this empirically.
3. A last-match-wins allow rule for `pmctl` can preserve the PM path while the
   catch-all denies unrelated Bash; the `allow-pmctl guard` row verifies the
   negative side.

Do not use `--dangerously-skip-permissions`. Preserve each JSONL stdout stream
for the ticket result. Stage 3 may proceed to reversible config merge design
only if the PM row succeeds and the guard sentinel remains absent.

References: OpenCode permissions use last matching pattern precedence, and
custom commands support shell-output injection in their prompt templates:
<https://opencode.ai/docs/permissions/>,
<https://opencode.ai/docs/commands/>.
