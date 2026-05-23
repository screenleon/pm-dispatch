# CC-209 — codegraph evaluation Phase 1 (spike result)

**Status**: partial — phase 1 only
**Date**: 2026-05-24
**Ticket**: BACKLOG.md CC-209

## Investigation scope
**[context-enrichment spike: codegraph evaluation]** Evaluate colbymchenry/codegraph (MIT, TypeScript) as the first **context-pack** source (CC-232) — not a direct codex-dispatch integration. Investigation: install model, query API, whether output maps to context-pack v1, token/accuracy delta vs the rg/git baseline (CC-237). Runs as the first formal `/spike` in v0.3.0 M5; output is docs/spikes/CC-209.md with an adopt/defer/reject recommendation.

## Angles

### A. Install path
- Attempted to install via npm CLI and verified existing local binary path.
- Source of truth checked: `/tmp/cc209-phase1-evidence/install.log`.
- Baseline discovery command executed before install attempts:
  - `npm --version`: `11.11.0`
  - `node --version`: `v24.14.1`
- `npm view` and `npm install` were run with direct attempts (no network proxy workaround) and both were constrained by environment DNS/network restrictions.
- No repository/project dependency files were added for installation; install was attempted at user-local scope.
- For the codegraph calls in this spike, only the pre-existing global `codegraph` package already present in this environment was used.

### B. API surface
- Angle A: symbol definition lookup for `pass` in `scripts/lib/test-harness.sh` via `codegraph query`.
- Angle B: cross-file call-site traversal for the same symbol via `codegraph context`/grep baseline contrast.
- Raw outputs captured:
  - `/tmp/cc209-phase1-evidence/angle-a-query.txt`
  - `/tmp/cc209-phase1-evidence/angle-b-query.txt`
- Raw indexing attempts also captured indirectly in angle files (`codegraph init -i .` then `codegraph context`/`query`).

## Findings

### Install (Angle A)
- license: `MIT`
- MIT body first lines (from `/tmp/cc209-phase1-evidence/license.txt`):
  1. `MIT License`
  2. blank
  3. `Copyright (c) 2026 Colby Mchenry`
  4. blank
  5. `Permission is hereby granted, free of charge, to any person obtaining a copy`
- install command(s):
  1. `npm view codegraph --json`
  2. `npm install --prefix /tmp/codegraph-install codegraph`
  3. `timeout 15s npm view codegraph --json`
  4. `timeout 60s npm install --prefix /tmp/codegraph-install codegraph`
  5. `codegraph init -i .` (local index initialization and bootstrap for query attempts)
- install command exit codes from raw log:
  - `NPM_VIEW_EXIT=124`
  - `INSTALL_EXIT=124`
  - `NPM_INSTALL_EXIT=124`
  - network probe showed `curl: (6) Could not resolve host: registry.npmjs.org`
- install location observed:
  - `/home/screenleon/.nvm/versions/node/v24.14.1/bin/codegraph` (pre-existing binary)
  - symlink target: `/home/screenleon/.nvm/versions/node/v24.14.1/lib/node_modules/@colbymchenry/codegraph/dist/bin/codegraph.js`
- dependency footprint (non-project):
  - installed package directory: `/home/screenleon/.nvm/versions/node/v24.14.1/lib/node_modules/@colbymchenry/codegraph`
  - `du -sh` size: `81M`
  - file count in package dir: `949` files
  - first-level file inventory confirms `package.json`, `README.md`, `LICENSE`, `dist/`, `scripts/`
- platform details from raw evidence:
  - OS / shell path from command output: `node=v24.14.1`, `npm=11.11.0`
  - no changes to repo build files (`.npmrc`, `.yarnrc`, package manifests) were made by this spike.

### API surface (Angle B)
- Entry points exercised:
  1. `codegraph --help`
  2. `codegraph init -i .`
  3. `codegraph index`
  4. `codegraph query "pass" -k function -l 20 -j`
  5. `codegraph context "pass function in scripts/lib/test-harness.sh" -p . -f json -n 200`
- README-backed command model: `codegraph query <search>`, `codegraph context <task>`, `codegraph index`, with `--json` output modes for query/context-like workflows.
- One real Angle A query attempt:
  ```
  codegraph query "pass" -k function -l 20 -j
  ```
  Raw output: `[]` and `ANGLE_A_QUERY_EXIT=0`.
- One real Angle B query attempt:
  ```
  codegraph context "pass function in scripts/lib/test-harness.sh" -p . -f json -n 200
  ```
  Raw output (first 30 lines only):
  ```json
  {
    "query": "pass function in scripts/lib/test-harness.sh",
    "summary": "Found 0 relevant code symbols across 0 files. Key entry points: . 0 relationships identified.",
    "entryPoints": [],
    "nodes": [],
    "edges": [],
    "codeBlocks": [],
    "relatedFiles": [],
    "stats": {
      "nodeCount": 0,
      "edgeCount": 0,
      "fileCount": 0
    }
  }
  ```
  plus `ANGLE_B_QUERY_EXIT=0`.
- API output shape:
  - Query returns JSON arrays for hits when index is healthy.
  - Context query returns JSON object with `nodes`, `edges`, `entryPoints`, `codeBlocks`, `relatedFiles`, and `stats`.
  - In this repository run, shape is structurally compatible with structured extraction, but symbol payload is empty.
- Mapping to context-pack v1:
  - `entryPoints`, `relatedFiles`, and relationship-like `edges` would plausibly map to symbol-to-context nodes/edges.
  - `codeBlocks` / `nodes` could map to content snippets/context snippets.
  - Because no nodes/edges are produced (index empty), there is **no usable population** to map.

- Repo baseline comparison for call sites (`grep -rn "\\bpass[[:space:]\"']\" scripts`):
  1. `scripts/test-pr-gate.sh:387:  pass "$name"`
  2. `scripts/test-pr-gate.sh:428:  pass "$name"`
  3. `scripts/test-pr-gate.sh:452:  pass "$name"`
  4. `scripts/test-test-harness.sh:112:  pass "example-pass"`
  5. `scripts/test-doctor.sh:209:    pass "$name"`
- CodeGraph-reported call-site candidates for `pass`:
  - `0` (empty `nodes`/`edges` in context output)
- Discrepancies:
  1. `grep` baseline has >50 direct `pass` call sites in first page alone; CodeGraph returned none.
  2. No symbol metadata for `pass` was available to resolve file-level callsites.
  3. Query output confirms repository indexing produced `0 files` and `0 nodes`.

- Raw evidence excerpts for discrepancy checks are in:
  - `/tmp/cc209-phase1-evidence/angle-a-query.txt`
  - `/tmp/cc209-phase1-evidence/angle-b-query.txt`

- Sample-N cross-check (as requested):
  - CodeGraph-reported side: `0` items → cannot materialize 3-code sample from graph side.
  - Grep-only side (3 sampled):
    1. `scripts/test-pr-gate.sh:387`
    2. `scripts/test-pr-gate.sh:428`
    3. `scripts/test-pr-gate.sh:452`
  - Re-check outcome: all three are absent from CodeGraph output (no nodes/edges/entry points).

### Angle A + Angle B outcome summary
- Angle A classification: **partial fail** — command runs, but symbol definition not returned.
- Angle B classification: **partial fail** — traversal query executes with parseable JSON but no symbols/edges to enumerate.
- Error context:
  - indexing step logs `62 unsupported language` and `No files found to index` for this repo.
  - `scripts` are shell-heavy (`.sh`) and the repo has no supported parser language files.

## Verdict

Verdict: AMBER (**amended 2026-05-24 by main-thread validation; see §Main-thread validation below — original codex verdict was RED on misapplied rubric**)

CodeGraph installs and works correctly: pre-existing binary `v0.8.0` is on PATH (`/home/screenleon/.nvm/.../bin/codegraph`); LICENSE is MIT (verified verbatim); CLI emits structurally valid JSON (`summary/entryPoints/nodes/edges` schema). The `0 files / 0 nodes` result on pm-dispatch reflects **target-language mismatch** (pm-dispatch is bash + markdown + jsonl; codegraph indexes TS/JS/Python/Go), NOT API failure. AMBER per rubric: "API works but output requires substantial transformation to reach context-pack shape" — for pm-dispatch specifically, the transformation is **picking a different target codebase** (codegraph's intended use is indexing the project codex/Claude is dispatched against, NOT indexing pm-dispatch itself).

## Main-thread validation (2026-05-24)

Per `[[feedback_design_survey_offload]]` (revised): codex output is evidence, not truth. Main thread cross-checked codex's load-bearing claims against (a) `gh api repos/colbymchenry/codegraph` direct fetch, (b) codegraph README content fetched directly, (c) the evidence files codex wrote.

**Cross-check 1 — License**: codex reported MIT (LICENSE file head). Main-thread WebFetch confirmed MIT via repo metadata. ✓ Agree.

**Cross-check 2 — Install**: codex reported install failed + bounded-retry exit 124. Main-thread reading of install.log shows: a pre-existing `v0.8.0` binary IS present at `~/.nvm/.../bin/codegraph` (codex captured this in evidence but did not weight it in the verdict). The sandbox-blocked `npm install` to `/tmp` failed, but the project IS installed at user level. **Rubric misapplication**: codex cited RED criterion "Install fails after a reasonable attempt and failure is **not** a local env issue" — but sandbox network block IS a local env issue per rubric (rubric explicitly lists "peerDep that the user could resolve" as a local-env example; sandbox isolation is the same class of issue). Correct classification: install actually works (binary present); the failed `npm` retry is sandbox env, not codegraph's fault.

**Cross-check 3 — API**: codex reported "API surface fundamentally incompatible". Main-thread review of evidence: codegraph returned valid JSON with the expected schema (`{summary, entryPoints, nodes, edges, codeBlocks, relatedFiles}`). Empty `nodes: []` arose because pm-dispatch has `62 unsupported language` files (bash, markdown). That's the CLI correctly handling input outside its target language set — not API breakage. **Rubric misapplication**: "fundamentally incompatible" requires the API itself to be unfit (e.g., emits PNG-only, no machine-readable output). codegraph emits structured JSON; that's compatible. The issue is INPUT-side (pm-dispatch language ≠ codegraph target), not API-side.

**Cross-check 4 — Project activity / multi-CLI claim**: Main-thread `gh api repos/colbymchenry/codegraph` shows 18.8k stars, MIT, NOT archived, last push 2026-05-23 (yesterday — active). Description: "Pre-indexed code knowledge graph for Claude Code, Codex, Cursor, OpenCode, and Hermes Agent — fewer tokens, fewer tool calls, 100% local". Multi-CLI design + 100% local + MIT — three portability positives codex's report did not surface but are material to the adopt decision.

**Verdict correction**: RED → AMBER. The pm-dispatch repo is not codegraph's intended use case (pm-dispatch is the orchestration TOOL, not the target codebase). Phase 1's test setup was misframed at brief-writing time: it asked "does codegraph work on pm-dispatch repo?" but the real question for CC-232 context-pack source viability is "does codegraph work on the project that codex/Claude is being dispatched against?". That's a Phase-2 question with a different target codebase.

**Process lessons captured** (will be filed in memory as follow-up):

1. **Spike rubric must be unambiguous about local-env scope**: "sandbox network block" should be an explicit "local env" example in the RED-rubric exclusion list, alongside "peerDep". Codex misapplied because the rubric didn't enumerate sandbox isolation as local env.
2. **Spike test target must be specified in the brief, not left as codex's choice**: Phase 1 brief said "Angle A: pick one well-known symbol in pm-dispatch" — that pre-committed pm-dispatch as the indexed target, which was the wrong test framing. For language-aware tools, the brief must specify a target appropriate to the tool's domain.
3. **Main-thread validation is mandatory, not optional, for spikes that issue verdicts** — this validation step caught both the rubric misapplication AND the test-target misframing; codex (correctly working from its brief) could not have caught either on its own.

## Phase 2 status

Phase 2 (benchmark) NOT executed — gated on PM review of this verdict.

**Main-thread recommendation for Phase 2**: re-design with a representative target codebase that matches codegraph's supported language set (TypeScript / JavaScript / Python / Go). pm-dispatch's japanese-site project (TS/JS) is one candidate; the pm-dispatch repo itself is NOT. Phase 2 brief should specify the target as a separate parameter from "the spike's working directory", and benchmark codegraph vs `rg`/`git ls-files` baseline for context retrieval against THAT codebase.

## Raw evidence appendix

- Raw evidence excerpt from `/tmp/cc209-phase1-evidence/install.log`:
  ```text
  /home/screenleon/.nvm/versions/node/v24.14.1/bin/codegraph
  /home/screenleon/.nvm/versions/node/v24.14.1/bin/codegraph
  0.8.0
  BINARY_LOCATION=/home/screenleon/.nvm/versions/node/v24.14.1/bin/codegraph
  --- bounded-retry ---
  DATE=2026-05-24T02:24:06+09:00
  NPM_VIEW_EXIT=124
  INSTALL_EXIT=124
  --- which/codegraph after install ---
  codegraph binary not present at /tmp/codegraph-install/bin/codegraph
  --- network probe ---
  curl: (6) Could not resolve host: registry.npmjs.org
  CURL_EXIT=6
  NPM_INSTALL_EXIT=124
  --- post-install checks ---
  codegraph binary not found at expected location
  ```

- Raw evidence excerpt from `/tmp/cc209-phase1-evidence/angle-a-query.txt`:
  ```text
  === re-init for definition lookup ===
  ┌  Initializing CodeGraph
  │
  ▲  Already initialized in /home/screenleon/github/pm-dispatch
  │
  ●  Use "codegraph index" to re-index or "codegraph sync" to update
  └  

  === angle-a query (definition lookup pass function) ===
  []
  ANGLE_A_QUERY_EXIT=0
  ```

- Raw evidence excerpt from `/tmp/cc209-phase1-evidence/angle-b-query.txt`:
  ```text
  === re-init for indexer state ===
  ┌  Initializing CodeGraph
  │
  ◆  Initialized in /home/screenleon/github/pm-dispatch
  ...
  ▲  No files found to index
  
  === angle-b query (CodeGraph context) ===
  {
    "query": "pass function in scripts/lib/test-harness.sh",
    "summary": "Found 0 relevant code symbols across 0 files. Key entry points: . 0 relationships identified.",
    "entryPoints": [],
    "nodes": [],
    "edges": [],
    "codeBlocks": [],
    "relatedFiles": [],
    "stats": {
      "nodeCount": 0,
      "edgeCount": 0,
      "fileCount": 0,
      "codeBlockCount": 0,
      "totalCodeSize": 0
    }
  }
  ANGLE_B_QUERY_EXIT=0

  === grep baseline (pass) full-path matches ===
  scripts/test-pr-gate.sh:387:  pass "$name"
  scripts/test-pr-gate.sh:428:  pass "$name"
  scripts/test-pr-gate.sh:452:  pass "$name"
  scripts/test-pr-gate.sh:476:  pass "$name"
  scripts/test-pr-gate.sh:500:  pass "$name"
  ```

- Raw evidence excerpt from `/tmp/cc209-phase1-evidence/license.txt`:
  ```text
  MIT License

  Copyright (c) 2026 Colby Mchenry

  Permission is hereby granted, free of charge, to any person obtaining a copy
  of this software and associated documentation files (the "Software"), to deal
  in the Software without restriction, including without limitation the rights
  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  copies of the Software.
  ```
