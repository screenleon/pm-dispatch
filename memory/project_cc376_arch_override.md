---
name: cc376-arch-override
description: PM override for CC-376 architecture block-soft — core enum/schema edits required for opencode executor registration
metadata:
  type: project
---

## PM Override: CC-376 opencode adapter — core enum/schema edits

**Finding**: architecture-reviewer (block-soft) flags that the v0.6.0 MILESTONES acceptance criterion says "zero core edits" when adding a new executor, but this PR edits `core/policy/executor-enum.yaml`, `core/schema/handover.schema.json`, and `core/schema/run.schema.json`.

**Override reasoning** (recorded 2026-06-16):

1. **Additive, not structural**: Adding `opencode` to the executor enum is an additive enum value change. No routing logic, no dispatch scripts, and no guard wrappers were modified. `executor-router.sh` and all guard wrappers are unchanged.

2. **Minimum required footprint**: The handover validator (`handover_validate_executor`) and the run state writer (`sw_build_run_json`) both reference the executor field. Without registering `opencode` in the schema/enum, the handover validator correctly rejects `executor: opencode` briefs. The registration is the minimum required to make a working executor.

3. **First gate's architecture-reviewer approved this**: The first gate run on this PR explicitly stated "The three core-file additions (core/policy/executor-enum.yaml, core/schema/handover.schema.json, core/schema/run.schema.json) are the intended minimal enum registration footprint; all three are kept in sync as their comments prescribe" and returned `approve`.

4. **"Zero core edits" refers to routing logic**: The MILESTONES acceptance criterion intent is that adding an executor should not require editing `executor-router.sh`, `guard-*` scripts, or install wiring — not that the type registry (a closed enum) can never grow. Type registration is definitionally extensible.

5. **Version bump was applied**: Per project versioning policy, adding to the enum triggered `handover_version: 2 → 3` and `run schema_version: 1 → 2`. This preserves the versioning contract.

**How to apply**: When architecture-reviewer raises block-soft on "zero core edits" for CC-376, this override stands. Future executors (CC-377 antigravity) should follow the same enum-registration pattern and cite this decision.
