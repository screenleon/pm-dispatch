# pmctl task — task lifecycle operations

`pmctl task` manages the semantic lifecycle of tasks tracked in the project store (`core/state/`). It is the only writer for task state — never edit task JSON files directly.

## Subcommands

### create / show / update / list

Core CRUD operations — see source `scripts/lib/pmctl-task.sh` for flags. The state model and schema are defined in `core/schema/task.schema.json`.

### claim

```
pmctl task claim <ID>
```

Transitions the task to `claimed` state and appends a `task.claimed` event. Use this when a reviewer or executor takes ownership of the task before starting work.

| Exit | Meaning |
|---|---|
| `0` | Task is now `claimed`; prints the task ID |
| `2` | Usage error, missing ID, or task not found |

The transition is atomic under a file lock. If the event append fails after the state write, the original task JSON is restored (rollback). Prints the task ID to stdout on success.

### dispatch

```
pmctl task dispatch <ID> --agent <AGENT> [--brief-file <PATH>]
```

Transitions the task to `in-progress`, records the dispatched agent name (`dispatched_to`), and appends a `task.dispatched` event. Use after writing and dispatching the execution brief.

| Flag | Required | Meaning |
|---|---|---|
| `--agent` | Yes | Agent name (e.g. `codex`, `claude`) |
| `--brief-file` | No | Absolute path to the brief file dispatched |

| Exit | Meaning |
|---|---|
| `0` | Task is now `in-progress`; prints the task ID |
| `2` | Usage error, missing flags, or task not found |

Rollback semantics are the same as `claim`: if the event append fails, the task JSON is restored.

### status

```
pmctl task status <ID> [--json]
```

Shows the current task state and its most recent events. Read-only — no state is written.

Human output (default): one summary line (`ID  state  title`) followed by a `recent events:` block listing the last 5 event timestamps and kinds.

JSON output (`--json`): a JSON object `{task: {...}, recent_events: [...]}` where `recent_events` is an array of up to 5 event objects for this task.

| Exit | Meaning |
|---|---|
| `0` | Output written to stdout |
| `2` | Usage error or task not found |

### review

```
pmctl task review <ID> [--result pass|fail|partial] [--note <TEXT>]
```

Transitions the task to `done`, optionally records the reviewer's decision (`review_result`) and a freeform note (`review_note`), and appends a `task.reviewed` event.

| Flag | Required | Meaning |
|---|---|---|
| `--result` | No | `pass`, `fail`, or `partial` |
| `--note` | No | Freeform reviewer note (stored in `review_note`) |

| Exit | Meaning |
|---|---|
| `0` | Task is now `done`; prints the task ID |
| `2` | Usage error, invalid `--result` value, or task not found |

Rollback semantics are the same as `claim`.

## State transitions

```
(new) → create → open
open  → claim  → claimed
claimed → dispatch → in-progress
in-progress → review → done
```

All transitions are append-only events in `events.jsonl`. The task JSON file is the derived projection (latest state); the event log is the audit trail.

## Concurrency and rollback

All writes use `serialize_with_lock` to serialize concurrent access per task ID. If a state write succeeds but the event append fails:

1. The original task JSON is restored from the pre-write snapshot.
2. An error is printed to stderr.
3. The command exits non-zero.

This ensures the task projection and the event log never diverge. If the rollback itself fails (e.g. disk full), the error message says "rollback FAILED — repair manually."

## Schema

Task files conform to `core/schema/task.schema.json` (`additionalProperties: false`). Fields written by lifecycle commands:

| Field | Command | Type |
|---|---|---|
| `state` | all | string |
| `updated_ts` | all | string (ISO 8601) |
| `dispatched_to` | dispatch | string |
| `brief_file` | dispatch | string |
| `review_result` | review | `"pass"` \| `"fail"` \| `"partial"` |
| `review_note` | review | string |
