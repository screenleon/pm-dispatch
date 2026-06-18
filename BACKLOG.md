<!-- pm-schema: v1.2 -->
# pm-dispatch backlog

<!--
ID PREFIX: CC
CC-001/CC-002 were consumed by PR #24 fix bundle inline, with no standalone entries; this file starts at CC-003.
-->

## Index

| #  | Status | 主題 | 影響面 | 首次記錄 | Refs | Priority | Epic |
|----|--------|------|--------|----------|------|----------|------|
| CC-003 | 🔵 active | parallel-gate artifact-ignore 前置檢查 | ops/arch | 2026-05-12 | pr:#38 | P3 | — |
| CC-004 | 🔵 active | test-pr-gate.sh docstring 格式統一 | ops | 2026-05-12 | pr:#38 | P3 | — |
| CC-011 | 🟢 someday | sync-memory.sh + install 選項：symlink memory 到雲端資料夾實現跨裝置共用 | ux/memory | 2026-05-14 | — | — | — |
| CC-012 | 🟢 someday | SessionStart hook：session 啟動時 pull 最新 memory（git/rsync）確保跨裝置同步 | ux/memory | 2026-05-14 | — | — | — |
| CC-014 | 🟡 deferred | `using-git-worktrees` skill：parallel PR gate 隔離開發環境 | arch | 2026-05-14 | — | — | — |
| CC-015 | 🟡 deferred | `systematic-debugging` skill：結構化偵錯工作流 | ux | 2026-05-14 | — | — | — |
| CC-018 | 🔵 active | **[rate-limit 統一]** Codex quota 自動追蹤 + pm-dispatch rate-limit 路徑統一（吸收 CC-269）：改寫到 `~/.local/share/pm-dispatch/state/rate-limits.json`；解析 Codex API response headers；token-usage.sh 加入 Codex pool 剩餘顯示。 | ux/token | 2026-05-14 | — | P3 | — |
| CC-023 | ⏸ deferred | `coupling-reviewer`：PR gate 加入語言感知耦合分析（dependency-cruiser/gocyclo/coca） | ops/gate | 2026-05-14 | — | — | — |
| CC-026 | 🔵 active | `/skill-distill`：偵測重複工作流，產出草稿 skill .md | ux/memory | 2026-05-15 | — | P3 | — |
| CC-032 | 🔵 active | `[[feedback_*]]` cross-link 公開化：抽到 `docs/policies/` glossary 避免 dead link | process/DX | 2026-05-15 | — | P3 | — |
| CC-033 | 🔵 active | Public flip checklist：Issues/Discussions 設定、CITATION.cff（選配）、後續觀察期 | process | 2026-05-15 | — | P3 | — |
| CC-035 | 🔵 active | install/uninstall-hooks basename+scripts/ heuristic：未覆蓋另一工具也在 scripts/ 下同名 hook 的 collision edge case | ops | 2026-05-15 | pr:#53 | P3 | — |
| CC-038 | ⏸ deferred | Windows / cross-platform 鎖機制：`flock` Linux-only，未來支援 Windows/macOS 需替代方案 | ops/portability | 2026-05-15 | — | — | — |
| CC-044 | ⏸ deferred | **[infra: tool-trace reliability, retention, data-quality bundle]** `tool-trace.jsonl` 三階段升級（吸收 CC-027b + CC-027c）：Phase 1 rotation/retention multi-window policy；Phase 2 bounded error counter + health signal；Phase 3 async post-validation for malformed JSON。分 phase 實作但同一 epic。 | ux/memory | 2026-05-15 | — | — | — |
| CC-045 | ⏸ deferred | brief timeout heuristic：依 target repo playbook depth 設 timeout，不能只看 edit size；brief context 可加「skip playbook re-read」短路指令；codex-dispatch.sh 可選 warn 當 repo 有 `rules/`/`AGENTS.md` 且 timeout < 900s | process/DX | 2026-05-16 | — | — | — |
| CC-104d | 🟡 deferred | **[Windows dogfood r1 findings]** Hardcoded `$HOME/github` read root default in `hook-codex-bash-guard.sh:54`; `CLAUDE_HOOK_CODEX_READ_ROOTS` env override exists but default is wrong on Windows where repos live under `~/Documents/github/` or arbitrary paths. Should be derived from `PM_DISPATCH_REPO` parent or removed | ops | 2026-05-17 | — | — | oss |
| CC-104e | 🟡 deferred | **[Windows dogfood r1 findings]** WSL ↔ Windows `~/.claude/projects/<project-id>/memory/` divergence: project ID is path-sanitization of working dir. Same repo cloned at `~/github/pm-dispatch` (WSL) and `C:\Users\<user>\Documents\github\pm-dispatch` (Windows) produces different IDs → memory partitioned. Harness-level (Claude Code) issue; document workaround (symlink, or PM_DISPATCH_PROJECT_ID override) | ux/memory | 2026-05-17 | — | — | oss |
| CC-104f | 🟡 deferred | **[Windows dogfood r1 findings]** jq is hard-dep for hooks layer. Options: vendor static `gojq` binary (3 MB × 3 platforms), or expose `--no-hooks` install mode that skips hook wiring entirely (lightweight install for jq-less users). Latter preferred — keeps "no auto-install of system pkgs" principle | arch/install | 2026-05-17 | — | — | oss |
| CC-104g | ⚠️ partial 2026-05-17 | **[Windows dogfood r1 fixes]** portable.sh test fixes: symlink test SKIP + detect_platform host_native PASS on Windows ✅; mkdir_lock FIFO sync ✅ but underlying `mkdir` on Git Bash still allows second concurrent acquire — real Windows portability bug, NOT test sync issue. See CC-104k | ops/test | 2026-05-17 | pr:#80 | — | oss |
| CC-104j | 🟡 deferred | **[Windows dogfood r1 r2 finding]** `test-dispatch-handover.sh:674-685` `brief_file_symlink_rejects_case` uses `ln -s` for fixture setup; on Git Bash falls back to copy → validator treats as regular file → test fails. Same skip-if-not-symlink pattern as CC-104g case (a) — `[[ -L "$link" ]]` precondition → SKIP | ops/test | 2026-05-17 | — | — | oss |
| CC-104k | 🟡 deferred | **[UNC/9P filesystem caveat — re-scoped from `mkdir_lock` atomicity claim]** Race test on Windows Git Bash 5.2.15 (Windows 11) confirmed `mkdir` IS atomic on **local NTFS** (`C:\...\Temp` — Git Bash's `/tmp`); 20/20 rounds × 50 parallel = exactly 1 winner each. Original CC-037 regression failure on Windows was specifically when running pm-dispatch from `\\\\wsl.localhost\\Ubuntu\\...` (9P UNC bridging WSL FS to Windows) — 9P protocol or its Windows client does not preserve mkdir atomicity. Not a code bug; install-on-local-disk caveat. See **CC-104r** for the install-time UNC path detect / docs warn follow-up. If a third filesystem ever surfaces `mkdir`-non-atomic, revisit with `set -C` + `: > file` primitive (already race-tested as atomic on tested FS) | ops/portability | 2026-05-18 | — | — | oss |
| CC-104m | 🟡 deferred | **[Platform layout — post-v0.1.0]** pm-dispatch staging dir + multi-target projection: introduce `~/.pm-dispatch/content/` as canonical view, then symlink-project to `~/.claude/` and (future) `~/.codex/` etc. Today pm-dispatch is Claude-only by virtue of where install.sh lands; this re-shapes it as a tool-agnostic content platform. Touches install.sh, manifest schema (v0 → v1 with `target` field), uninstall semantics. Decided 2026-05-18 (CC-104c scope discussion, Path Y). Open until clear Codex/Cursor/Aider integration need surfaces | arch/install | 2026-05-18 | — | — | oss |
| CC-104r | ⏸ deferred | **[Windows dogfood r3 finding]** `hook-tool-trace.sh` performance_budget assertion: 27990 ms actual vs 3500 ms budget on Windows native filesystem (WSL UNC path `\\wsl.localhost\...` is ~8× slower than local disk). Not a pm-dispatch bug — physical filesystem characteristic. Fix is two-part: (a) `docs/platform-support.md` warns "install on local disk, avoid cross-WSL/native FS boundaries"; (b) preflight detects UNC path → prints warning and skips budget assertion (10 lines). Polish, not blocker | docs/ops | 2026-05-18 | — | — | oss |
| CC-104s | 🟡 deferred | **[Windows dogfood r3 finding]** `hook-tool-trace.sh:195` `read_home_path_basename_only` returns `first_arg_or_skill:null` on Windows because case-glob `"$HOME"/*` uses forward slashes (`/c/Users/Lien Chen`) but harness sends `file_path` with backslashes (`C:\Users\Lien Chen\...`); both case branches miss. Fix: normalize input path via `cygpath`/string-replace (`\\` → `/`, `C:\Users\...` → `/c/Users/...`) before case-match. Polish — affects trace JSON observability only, not functionality | ops/portability | 2026-05-18 | — | — | oss |
| CC-205 | ⏸ deferred | `/pm` dual-executor planning: `--executor auto/codex/claude` flag（與 pr-gate 介面對齊）+ `dispatch_handover_v1` 加 `executor` 欄位；加 `--parallel-plan` mode — PM 偵測 arch/multi-subsystem/first-design 特徵時，在 dispatch 前暫停並詢問用戶是否啟用；確認後 codex 與 claude 各自獨立規劃，current model 合成一份 best-of 計劃輸出；`/pm --parallel-plan` flag 可跳過確認步驟直接 parallel dispatch | process | 2026-05-20 | — | P2 | design |
| CC-209 | 🟢 someday | **[context-enrichment spike: codegraph evaluation]** Evaluate colbymchenry/codegraph (MIT, TypeScript, 18.8k★, active) as a **context-pack** source (CC-232). Phase 1 spike `docs/spikes/cc209-codegraph-phase1.md` (2026-05-24): codex returned RED on misapplied rubric; **main-thread validation amended to AMBER** — install ✓, license MIT ✓, API works ✓, BUT pm-dispatch is not codegraph's intended target (bash/markdown stack not supported). Phase 2 (benchmark) deferred until brief re-specifies target as TS/JS/Python/Go codebase. Process lessons: rubric must enumerate sandbox-block as local-env; spike brief must specify test target separately from working directory; main-thread validation mandatory for verdict-issuing spikes. | ops/token | 2026-05-21 | pr:TBD | P3 | spike |
| CC-210 | ⏸ deferred | **[uninstall blast-radius guard]** `uninstall.sh` currently allows `$HOME/.claude` itself to pass the managed-root safety guard (dst must start with managed root); a malformed or tampered copy-mode manifest entry matching the directory hash could remove the entire Claude config tree. Fix: add an explicit `[[ "$dst" == "$managed_root" ]]` rejection check before the startswith guard, so only strict descendants of the managed root are deletable. Raised by risk-reviewer in PR #110 gate as [medium] advisory. | ops | 2026-05-21 | pr:#110 | P3 | hygiene |
| CC-211 | ⏸ deferred | **[v0.3.0 architecture epic]** Restructure pm-dispatch into a schema-first / state-first / adapter-thin PM runtime — four layers: `core/` (data + policy) → `runtime/` (`pmctl` spine) → `adapters/` (delivery) → `mcp/` (bridge, v0.4.0). Absorbs Multica / Memori / Superpowers / AI Night Shift concepts into one state substrate. Broken into milestones — live **M0–M6** in MILESTONES.md (synthesis §6 is the original M0–M5 cut); runtime is realized as `cli/pmctl` (not a `runtime/` dir). See docs/architecture/v0.3.0-synthesis.md **Conformance status** for as-built drift (codex+claude adapters shipped; state-first / `mcp/` still open). Umbrella epic for CC-229..CC-237 + existing CC-059/060/061/200-204/215/217-220. | arch/portability | 2026-05-21 | — | P1 | design |
| CC-216 | ⏸ deferred | **[MCP server — pm-dispatch-server]** **Deferred to v0.4.0**. (AS-BUILT 2026-05-31: the `mcp/README.md` spec originally planned for v0.3.0 was **not** written — `mcp/` is absent and `pmctl` has no general `--json`; the whole MCP surface incl. the spec is deferred. See synthesis Conformance status §B.) The server is built once `pmctl` is stable. Implement `mcp/pm-dispatch-server` exposing pm-dispatch operations as MCP tools: pm_list_tasks, pm_read_task, pm_create_task, pm_update_status, pm_add_decision, pm_request_review, pm_dispatch_to_agent, pm_read_trace, pm_guard_check. Enables Claude Code, OpenCode, Antigravity CLI, and any future MCP-capable AI tool to share one PM system without per-tool command wiring. MCP becomes the universal bridge; adapters handle only auth / config / format differences. Implementation path: thin Node.js or Python wrapper over pmctl subprocesses (avoids duplicating logic), or native bash MCP server once spec stabilises. Depends on CC-211, CC-215 (pmctl stable before wrapping). | arch/portability | 2026-05-21 | — | — | design |
| CC-220 | ⏸ deferred | **[spike agent + `/spike` skill]** Implement `agents/spike.md` and `commands/spike.md`. Spike agent is a **planner** (like `project-pm`): reads a BACKLOG spike ticket, plans 2–3 investigation angles, returns a `spike_plan` block; the **main thread** fans out one Agent per angle (subagents cannot spawn subagents); the spike agent is re-invoked to synthesise findings into `docs/spikes/CC-NNN.md` and update the `Result log`. Modeled on `/pr-gate`'s reviewer fan-out. v0.3.0 M5. Depends on CC-218. | process/DX | 2026-05-21 | — | P3 | design |
| CC-212 | ⏸ deferred | **[fix: harden Windows junction install — path-passing + idempotency]** 兩個 Windows junction hardening 合併一 PR（吸收 CC-213）：(A) `make_junction_windows()` 改用 `PM_DISPATCH_MAKE_SRC`/`PM_DISPATCH_MAKE_DST` env var 傳路徑，統一 PowerShell boundary 慣例；(B) `install_dir_junction()` 加 manifest-driven idempotency probe，不再依賴 `-L` 偵測。 | ops/portability | 2026-05-21 | pr:#112 | P3 | oss |
| CC-214 | ⏸ deferred | **[CC-207 advise follow-up]** `docs/platform-support.md` 手動 uninstall 說明使用裸 `bash uninstall.sh`，在非 repo-root 工作目錄下執行會找不到腳本；應改為 `bash "${PM_DISPATCH_REPO}/uninstall.sh"` 形式（與文件其他範例一致）。Raised by critic in gate-20260521-115634 as [low] advise. | ops/DX | 2026-05-21 | pr:#112 | P3 | oss |
| CC-225 | ✅ done | **[claude-executor result observability]** `claude-executor` task output 寫入 session-scoped `/tmp/` 路徑，不進 REPO、不可跨 session 回溯，且無法 git diff 追蹤執行歷史。設計目標：主線程在 claude-executor 完成後把 brief 路徑、result 摘要、exit status 寫入 REPO 固定目錄（格式與 `.gate-results/` 一致），作為 CC-211 / CC-216 MCP 架構抽離的前提。sub-concern of CC-211. | ops | 2026-05-22 | — | P3 | design |
| CC-227 | ⏸ deferred | **[refactor: extract yaml-frontmatter lib + shared validation helpers]** 把 `check_frontmatter()` 與 shared helpers（dq-escape/adjacent-quote/empty-entry，原 CC-226 範圍）一起搬到 `scripts/lib/yaml-frontmatter.sh`；`lint-frontmatter.sh` 成薄 CLI 包裝；`doctor.sh` 可 source lib 取代 fork subprocess。CC-226 已合併入本票。 | arch/reuse | 2026-05-22 | pr:#119 | P3 | oss |
| CC-236 | 🟢 someday | **[pmctl report — away-from-keyboard state roll-up]** A `pmctl report` rolling up state since last invocation (open tasks, blockers, last gate verdict, recent runs). Deprioritized 2026-05-22: the maintainer does not run agents unattended, so a "morning report" time-gap framing has low current need; on-demand status is already part of the `pmctl` surface (CC-215). Revisit if the workflow ever includes overnight / away dispatch. | ux | 2026-05-22 | — | — | design |
| CC-238 | ⏸ deferred | **[/pr-gate claude-route fan-out hardening]** CC-217 made the `/pr-gate` claude-executor reviewer/synthesis fan-out run detached (`run_in_background`). Gate advisories on the new flow (CC-217 gate, gate-20260523): (a) no timeout/fallback if a reviewer agent never reports completion → indefinite wait; (b) single fan-out step weakens per-reviewer failure attribution on partial failure; (c) no test artifact validates background completion / relay ordering. Add a completion timeout + partial-failure attribution + test coverage for the claude-route fan-out. | gate | 2026-05-23 | pr:#124 | P3 | oss |
| CC-240 | ⏸ deferred | **[test-suite reliability follow-ups]** Part (a) — suite-count derivation in `scripts/test-run-all-tests.sh` — closed via CC-219 (pr:#129). Remaining: `[low]` `scripts/test-portable.sh::case_mkdir_lock_contention` holds the lock with a fixed `sleep 1.2` (pre-existing; conflicts with the qa AGENT.md red line on `sleep` for async sync) → CI-timing flakiness. Fix with an IPC / event-driven lock-hold. | test | 2026-05-23 | pr:#127 | P3 | oss |
| CC-244 | 🟢 someday | **[Typed artifact pipeline — spike → brief → handover schema]** Define `spike_v1` schema mirroring existing `dispatch_handover_v1`: frontmatter (`spike_id`, `status`, `decisions_resolved`, `branch_base`, `ticket_ids_consumed`, `project_tooling`) + named sections (`scope`, `findings`, `constraints`, `decisions`, `phase3_handover`). Add `scripts/spike-validate.sh` (mirror `handover-validate.sh`) + `scripts/gen-brief-from-spike.sh` (mechanical brief extraction). Reduces main-thread courier cost, makes spike→brief authoring mechanical, gives invariant checkpoints (`decisions_resolved=true` ⇒ no re-asking Q1/Q2). Defer until 3+ spike docs exist and the brief-extraction pattern repeats; only one spike (CC-060) today, so schema would be premature overhead. CC-243 field names chosen to align with this future schema (no re-wash needed at upgrade time). | arch | 2026-05-23 | — | — | design |
| CC-224 | ⏸ deferred | **[shared hook-profile inventory: doctor.sh ↔ install-hooks.sh]** `doctor.sh` owns a second hardcoded minimal/full hook membership model alongside `install-hooks.sh`, creating a silent drift path when hooks are added or profile semantics change. Extract the hook-profile list into a shared shell helper (e.g. `scripts/hook-profile.sh`) or add a parity test asserting both files expect the same hook set. Raised by critic + architecture-reviewer as [medium] advise in gate-20260522-100348. | arch/reuse | 2026-05-22 | — | P3 | oss |
| CC-054 | ⏸ deferred | CC-025 M2 — `/skill-refine` diff generation and Claude-assisted refinement；scope deferred when CC-025b was closed in `feat/cc039-cc025b-v2` | ux/memory | 2026-05-18 | pr:#67 | — | — |
| CC-063 | 🟡 deferred | Trace / token / gate metrics dashboard：`.agent-trace/*.jsonl` + `rate-limits*.json` + `.gate-results/*.md` 已有足夠資料；可視化 per-session token、gate pass rate、routing_log 校準趨勢 | ux/ops | 2026-05-18 | — | P3 | — |
| CC-064 | 🟡 deferred | **[P2]** Project bootstrap wizard：互動式 `scripts/setup-project.sh --init` 引導新 repo 建立 memory、rules、PM schema；取代目前「手讀 GETTING_STARTED.md 再手跑指令」流程 | ux | 2026-05-18 | roadmap:CC-031 | P2 | — |
| CC-065 | 🟡 deferred | Per-repo configurable gate pipeline：不同 repo 可設定不同 reviewer 組合與 tier 預設（例如 `.pm-dispatch/gate.toml`）；現在所有 repo 共用同一 gate config | ops/gate | 2026-05-18 | — | P3 | — |
| CC-253 | 🔵 active | **[CC-209 Phase 2: codegraph benchmark on representative target codebase]** Phase 1 (PR #151) verdict AMBER — codegraph install ✓ license MIT ✓ API ✓, but pm-dispatch (bash/markdown) isn't a valid test target (`62 unsupported language`). Phase 2 re-scope: user picks a TS/JS/Python/Go target codebase at brief time, index it via codegraph, run 3 representative queries against rg/git baseline, measure token + latency delta. Output: append `## Phase 2` section to `docs/spikes/cc209-codegraph-phase1.md` OR new sibling doc. Verdict per original CC-209 ticket: adopt / defer / reject for context-pack source (CC-232 / CC-237). | ops/token | 2026-05-24 | pr:TBD | P3 | spike |
| CC-258 | ⏸ deferred | **[pm-write-guard hook policy revision]** Current `scripts/hook-pm-write-guard.sh` denies 3 legitimate PM-author patterns (12/207 deny audit hits over 10 days): (A) `/tmp/<task-slug>/*.md` verbatim-as-attached-file (Pattern 2 of `[[feedback_codex_brief_discipline]]`), (B) `<repo>/docs/spikes/{CC-NNN*,*-scope,*-rfc}.md` PM-author surface, (C) memory writes that resolve through the `memory-private/` symlink (`realpath_m` chases the symlink before the allow-pattern match — hook bug). Three new allow rules + `realpath_m_lex` (or `-s`) helper + ~15 new test cases in `scripts/test-hooks.sh`. Not blocking M1; deferred until user prioritizes. | process | 2026-05-24 | pr:#156 | P3 | hygiene |
| CC-259 | 🟢 someday | **[yaml.sh lib extraction]** Extract `_yaml_get` bash/awk helper and `case_yaml_parse` structural validator from `scripts/test-core-schemas.sh` into `scripts/lib/yaml.sh` for reuse across test scripts; add independent test file `scripts/test-yaml-lib.sh` and wire into `run-all-tests.sh` + CI. Currently only used in `test-core-schemas.sh`; extraction deferred from CC-229 M1 PR to reduce gate surface. Trigger: second consumer in a new test script. | ops/test | 2026-05-25 | pr:TBD | P3 | — |
| CC-270 | 🟡 deferred | **[test: concurrent pmctl adapter generate guard]** Two simultaneous `pmctl adapter generate <same-name>` runs can race: the precheck+mkdir+trap sequence is not atomic. Blast radius: one run may delete another's partial output; reproducible by deleting `adapters/<name>` and rerunning. Deferred — single-developer workflow makes this low-probability; fix with atomic mkdir using `mkdir` exit-code guard when needed. | test/ops | 2026-05-28 | — | P3 | — |
| CC-273 | 🟡 deferred | **[arch: unified lifecycle hook event spec]** CC-206 只在 gate 層加了 pre/post-gate hooks。如果未來多個工具（dispatch、validate 等）都需要 hook 點，應定義統一的 lifecycle event 命名規範（如 `.pm-dispatch/hooks/<event>.sh`）和呼叫合約，而非在每個腳本各自加 pre/post block。目前無需求，等有第二個 hook 點需求時再設計。 | arch/gate | 2026-05-28 | — | P3 | — |
| CC-276 | 🟡 deferred | **[feat: persistent gate override declarations]** 每輪 gate 重開 fresh session，已接受的 risk override 必須重新聲明。支援 `--override-file` 或自動探索 `.gate-overrides.md`，inject 到 reviewer prompt 前置脈絡，避免已接受的 block 重複出現。 | gate/process | 2026-05-29 | — | P2 | — |
| CC-285 | 🟡 deferred | **[archiver safe-drop: don't drop a terminal row whose body exists nowhere]** `scripts/archive-closed-backlog.sh` currently drops a terminal index row even when no body section exists in BACKLOG.md and none is in BACKLOG-ARCHIVE.md (warns to stderr). In a valid backlog `validate.sh`'s index↔body 1:1 invariant prevents this, and it is git-recoverable — recorded as accepted tradeoff in DECISIONS 2026-05-30. Defense-in-depth follow-up: keep the row + emit a loud warning when the body is in neither file, leaving it for manual reconciliation rather than removing it. Surfaced by pr-gate critic on #186. | ops | 2026-05-30 | — | P3 | hygiene |
| CC-286 | 🟡 deferred | **[pmctl: prefix-generic next-id derivation]** `scripts/pm-prep-snapshot.sh` derives `backlog_next_id` CC-only (it emits `CC-NNN`); under the working-set contract it scans BACKLOG.md + BACKLOG-ARCHIVE.md for the max, but only `CC-` IDs. A cross-repo next-id (other prefixes: JS-, PA-) must be prefix-derived and centralized in pmctl, scanning both working-set and archive. Retire pm-prep-snapshot's CC-hardcoded derivation when `pmctl backlog`/next-id lands. Surfaced by pr-gate critic+architecture on #186. | arch | 2026-05-30 | — | P3 | design |
| CC-306 | 🟡 deferred | **[arch: extend CC-233 layer enforcer to runtime-named data paths in scripts/]** Guard against re-introducing `.codex-*`/`.claude-*` DATA directories under scripts/ (the optional follow-up deferred from CC-298). | arch | 2026-06-01 | — | P3 | design |
| CC-342 | 🟢 someday | **[agent: debt-auditor — proactive tech-debt health scan on living code]** 新增 `agents/debt-auditor.md`：對指定 codebase 區域（目錄 / module）做主動技術債健康掃描，不需要 PR 觸發。輸出是按優先序排列的債務清單（重複、慣例分歧、過早抽象、缺少測試的不變量），含位置、影響、建議修法、預估規模。定位為**真正新的認知模式**（proactive health assessment），有別於所有現有 reviewer（全部 PR-diff focused）。由 `pmctl audit <path>` 或 `/audit` skill 呼叫；隔離執行確保不受進行中任務錨定。 | process/DX | 2026-06-05 | — | P3 | design |
| CC-344 | 🟢 someday | **[skill: /research — grounded external research with internal context anchoring]** 新增 `commands/research.md`：補足 `/discover` 純內部掃描的盲區，加入外部研究維度。流程：(1) 自動讀內部相關 memory/decisions 建立錨定；(2) 問使用者 1–2 個定向問題縮小搜尋範圍；(3) 派有 WebSearch 能力的 agent 抓取外部實作與方法；(4) 主線程以內部設計 constraint 過濾結果，標記「可採用」或「與 constraint X 衝突」。目標：讓外部技術知識能有效導入而非淪為噪音。與 `/discover` 互補——discover 看「我們已知但未做的」，research 看「外部有我們還沒想到的」。 | process/DX | 2026-06-09 | — | P3 | design |
| CC-345 | 🟢 someday | **[dx: claude adapter 即時進度串流（stream-json）]** `adapters/claude/dispatch.sh` 目前使用 `--output-format json`，stdout 完全 buffered 至 process 結束，dispatch 期間 trace 為空、working tree 無變動，使用者無法判斷 executor 在讀取或寫檔。改用 `--output-format stream-json` 並以 tee 寫入 trace，同步解析 tool-use events，在 stderr banner 即時顯示 `[reading]`、`[writing]`、`[running]` 進度行。 | ux/ops | 2026-06-09 | — | P2 | design |
| CC-346 | ⏸ deferred | **[repo-index: cross-file ref tracking（file_refs layer，5 languages）]** CC-338 只有 symbol+chunk，看不出引用關係。新增 `file_refs(from_id, to_path, ref_type, line_number, resolved)` 表，以 grep 解析 bash source、Java import、JS/TS import/require、Go import。分三 phase：(a) bash、(b) JS/TS、(c) Java+Go。讓 query 回傳的 `refs` 欄位含直接引用者，並為 CC-347 blast-radius 和 CC-239 reuse-scan 提供資料。**Paused 2026-06-10（arch review）**：reuse-scan 本身尚無任何操作面 caller——給沒人用的工具加深資料層是加倍下注未驗證假設。Resume trigger：reuse-scan 輸出（經 CC-356 接線）實際進過 ≥2 份真 brief，且觀察到缺 ref 資料確為瓶頸；屆時先只做 Phase a（bash source）。 | ops | 2026-06-09 | — | P3 | design |
| CC-347 | 🟢 someday | **[pr-gate: blast-radius analysis using cross-file refs（CC-346）]** gate brief 組裝時對 diff 中每個變更符號走一層 file_refs 圖，彙整成 `blast_radius` 清單（`{file, referenced_by: [path,...], ref_count: N}`）注入 brief context 段落，讓 risk-reviewer 有依據評估波及範圍。無 CC-346 index 時靜默跳過。 | gate | 2026-06-09 | — | P3 | design |
| CC-348 | 🟢 someday | **[pmctl project-map: cross-file dependency graph visualisation]** `pmctl project-map [--format text/dot] [--from <path>] [--depth N]` — 以 CC-346 file_refs 表輸出 ASCII 樹狀（預設）或 Graphviz DOT 引用圖；標示 broken refs（to_path 不在 files 表）；無 index 時 exit 1 並提示 `pmctl context index`。 | ops/DX | 2026-06-09 | — | P3 | design |
| CC-333 | 🔵 active | **[arch: pm-dispatch runtime 解耦合 — 移除對 Claude AI 路徑、hook 機制、術語的硬依賴]（v0.6.0 umbrella epic）** pm-dispatch 目前在七個層面硬耦合 Claude Code runtime：(1) memory 路徑（`~/.claude/projects/<id>/memory/`）；(2) hook 機制（PreToolUse/PostToolUse）；(3) 設定格式（settings.json）；(4) 安裝路徑（`~/.claude/`）；(5) env var 前綴（`CLAUDE_HOOK_*`，CC-321 部分解）；(6) dispatch 術語（`dispatch_handover_v1`、Agent tool 約定）；(7) reviewer agents 直接讀 Claude memory 路徑而非透過 handover brief。目標：pm-dispatch 的核心 workflow 應可在不同 AI runtime（或 CLI 工具）上運行，Claude-specific 部分降為 adapter layer。**v0.6.0 執行子票**：[[CC-372]]（runner-kind manifest）→ [[CC-373]]（router 資料驅動）→ [[CC-374]]/[[CC-375]]（guard 收口＋安裝接線）→ [[CC-386]]/[[CC-387]]/[[CC-388]]/[[CC-389]]（dispatch-model 統一 Model B 全面上路，[[CC-385]] 決策）→ [[CC-376]]/[[CC-377]]（opencode/antigravity 真 adapter 驗收）＋ [[CC-335]]（deprecation 清掃）。見 MILESTONES.md v0.6.0。 | arch | 2026-06-07 | — | P2 | design |
| CC-335 | ✅ done | **[release: deprecated surface registry + v0.6.0 removal sweep]** 追蹤 v0.4.0/v0.5.0 期間標記為 deprecated 的 public surface，在 v0.6.0 統一移除。實況分三類：handover legacy trio（sandbox/approval/skip_git_check）＋ CLAUDE_HOOK_* shims 真實移除（含 JSON schema 收斂）；codex-dispatch.sh shim 早於 v0.3.0 sunset 刪除，本次清 dead-code 殘留；pr-gate.sh 直呼降級為文件 deprecation（standalone 為官方 fallback，不刪檔）；guard --profile 早已移除。**See**: pr:#292 | release | 2026-06-16 | pr:#292 | P2 | — |
| CC-340 | 🟢 someday | **[knowledge index: heavy remainder after CC-354 — standalone FTS + embeddings]** The usable anchored-TOC slice (in-repo knowledge-doc section indexing) is pulled forward to CC-354 (v0.5.0). CC-340 is now the heavy remainder, symmetric to the repo index CC-338: out-of-repo memory cards + wiki + episodes (low-trust) indexing, standalone full-text ranking, embeddings, and richer trust-tier weighting — deferred to v0.6.0, overlapping /mem-search. FTS5-optional + LIKE/grep fallback; no embeddings in MVP. | memory | 2026-06-08 | — | P3 | design |
| CC-352 | ⏸ deferred | **[codex-executor sandbox friction Pattern 1+2: apply_patch retry noise + Go module cache blocked]** issue:#173 Pattern 3（git commit blocked）已由 CC-272 pr:#245 吸收修復。剩餘：(1) apply_patch 中途失敗 self-retry 噪音 — brief 改拆小 hunk 加 unique context；(2) go build 時 GOPATH copy 被 sandbox 擋 — 文件化 GOPATH=/tmp/gopath 慣例。兩者均為 doc/convention fix。 | ops/DX | 2026-06-10 | — | P3 | — |
| CC-355 | 🟢 someday | **[knowledge index: HTML semantic chunking — `<h1-6>` sections]** CC-354 chunks markdown by heading and txt/other by line windows; HTML falls back to window chunking, losing its `<h1>..<h6>` section structure (the same human-authored semantic anchors as markdown headings). Plug an html strategy into the CC-354 per-format chunker seam: split on heading tags, use tag-stripped heading text as the chunk heading, strip tags for the lead, handle parsing edge cases (comments, pre/code, entities). Split out because robust HTML parsing in bash is its own concern and there is no html knowledge source in the repo today. Trigger: a real html file enters the knowledge plane. | memory | 2026-06-10 | — | P3 | design |
| CC-357 | 🟢 someday | **[skill as contract: machine-readable schema for skills]** 現有 skills/ 都是純 markdown prose（SKILL.md），沒有機器可讀的 input schema、output contract、tool_constraints、completion_condition。這使得 skill 無法被驗證、無法被工具自動發現、也無法像 dispatch_handover_v1 那樣由 validator 強制執行契約。本票引入 skill schema（YAML frontmatter 或 JSON sidecar），使 skill 具備：明確的輸入型別、輸出格式、允許/禁止工具清單、完成條件——平行於 brief-validate.sh 對 brief 的驗證角色。 | arch/DX | 2026-06-10 | — | — | design |
| CC-358 | 🟢 someday | **[runner telemetry: evaluate with real runs — success rate / failure pattern / fallback analysis]** events.jsonl 已有每次 run 的完整生命週期資料（pending/dispatched/verifying/ok/failed），但沒有任何 consumer 分析「哪類任務成功率高低」、「失敗的主因是什麼」、「fallback 觸發頻率」。這使 adapter 路由決策完全主觀，也無從判斷 recovery 策略。本票在現有 events 原料上建立 runner telemetry layer：從 task history 計算 per-adapter 成功率、依 goal/context 分群的失敗模式、fallback 觸發原因分佈——提供資料驅動的 runner diversity（CC-2xx）與 recovery 決策依據。 | ops/memory | 2026-06-10 | — | — | design |
| CC-359 | 🟢 someday | **[concept: backlog-driven batch dispatch with worktree isolation]** 設計理念：pm-dispatch 本身管理 git worktree 生命週期（`git worktree add/remove`），讓多個 executor worker 在各自隔離的 filesystem workspace 平行處理 backlog task，不依賴任何特定 executor 的 platform feature。核心原則：(1) executor-agnostic — worktree 管理是 pmctl 責任，非 executor 責任；(2) human-in-the-loop — batch dispatch 後 merge 決策仍在人這邊，無 auto-merge；(3) 衝突可觀測不禁止 — 以 BACKLOG area 欄位做粗粒度衝突分組（同 area 排隊，不同 area 可平行），不做逐檔 conflict detection；(4) PR-only — 每個 task 產出獨立 branch + PR，由人統一 review。適合類型：測試補強、文件補強、小 bug、CLI option 補齊；不適合：架構核心大改、schema breaking change。Token budget 可作為 scheduler 輸入控制並行度。 | arch/ops | 2026-06-11 | — | — | design |
| CC-364 | ⏸ deferred | **[perf: `pmctl trace tail --all` per-event jq spawn]** `pmctl trace tail --kind <k> --all --json` is O(n) with a high per-event constant — ~20s for 338 events (~60ms/event), consistent with spawning a jq/subprocess per event rather than one streaming pass. Surfaced while diagnosing #270 context-telemetry test flakiness; the tests no longer depend on it (telemetry now honors `PM_DISPATCH_STATE_ROOT`, so the suite isolates state). Standalone reader-perf follow-up. **See**: pr:#270 | ops | 2026-06-12 | pr:#270 | P3 | hygiene |
| CC-369 | 🟡 deferred | **[Windows state store 真實 ACL via icacls]** CC-368 #2 在 NTFS 上以 SKIP-with-reason 處理 0700 斷言（chmod 是 no-op）；state store 目前僅靠 `%USERPROFILE%` 既有 ACL 保護。真正等價 0700 需在 Windows 用 `icacls` 限定目前使用者繼承移除 + 授權，要寫 Windows 專屬分支與測試。邊際安全收益相對 profile ACL 不高，故 deferred；gated behind [[CC-370]] 平台階段。 | ops/portability | 2026-06-13 | — | — | hygiene |
| CC-370 | ⏸ deferred | **[native Windows support deferred to post-core platform phase]** 核心功能開發期間正式只支援 Linux + WSL2（WSL2 視為 Linux）；原生 Windows Git Bash 非官方支援，使用者走 WSL2。理由是專注：開發期同時扛多平台會排擠核心功能（CI 只測 Linux，每次碰 Windows 都要人工驗證 + gate churn，見 #272/#273）。已合併的 portability 程式碼保留（綠且成本低），但不再新增 Windows 分支，直到核心定型（v0.5.0+）後的專屬平台階段。Parks: CC-038, CC-104d/e/f/g/j/k/r/s, CC-369。**See**: DECISIONS.md 2026-06-13 defer-native-windows-support-during-core-dev | ops/portability | 2026-06-13 | — | — | design |
| CC-371 | 🟡 deferred | **[uninstall: prune empty `~/.claude/adapters/` dir]** `uninstall.sh` / `uninstall-hooks.sh` 的 empty-dir prune 清單涵蓋 agents/commands/skills/scripts/share，但漏了 `adapters/`：移除 `adapters/claude`+`adapters/codex` symlink 後留下空的 `~/.claude/adapters/` 父目錄。空目錄、無 dangling link、無功能影響，屬清潔瑕疵。Fix：將 `adapters` 加入 prune 清單，並補 uninstall 回歸斷言（leftover-dir 檢查）。v0.5.0 釋出 §2a 手動驗證時發現。 | ops/install | 2026-06-13 | — | P3 | hygiene |
| CC-376 | ✅ done | **[adapter: opencode executor]** 新增 `adapters/opencode/`（dispatch.sh + adapter.yaml + isolation-map.yaml），以 `pmctl dispatch run --adapter opencode` 為唯一文件化主路；宣告 [[CC-372]] `runner_kind`，map opencode 的 sandbox/permission/model-alias 至統一 isolation 契約，輸出統一 `.agent-trace/latest.last`。**抽象的驗收證明**：落地若需改 router/guard 核心，代表 [[CC-373]]/[[CC-374]] 抽象未竟。相依 [[CC-373]]、[[CC-374]]、[[CC-389]]（non-interactive 契約基準）。umbrella [[CC-333]]。 | arch/portability | 2026-06-13 | — | P2 | design |
| CC-377 | 🟡 deferred | **[adapter: Google Antigravity (`agy`) executor]** 新增 `adapters/antigravity/`（cli binary `agy`；最終 adapter 命名 impl 時定）。與 [[CC-376]] 對稱：宣告 `runner_kind`、map sandbox/permission/model-alias、統一輸出契約。注意 Google **Gemini CLI 已棄用**，目標是 Antigravity `agy` 而非 gemini。第二個真 adapter，驗證抽象在 N≥2 下成立。相依 [[CC-373]]、[[CC-374]]、[[CC-389]]（non-interactive 契約基準）。**DEFERRED — 待 agy 版本更新（spike 2026-06-16）**：agy **有免費額度**（Gemini 3.x / Claude 4.6 / GPT-OSS 經 OAuth，成本非阻因）；暫緩原因是 **headless CLI 尚未成熟**——1.0.8 無結構化輸出旗標（--output-format/-o/--format/--log-level/--stream-format 實測皆被拒）、無 run 子命令、--print 吐 prose narration 無語意終止事件、headless 不穩（3/3 探針 timeout）；無 machine 契約可建乾淨 adapter。**agy 仍為首選第二 adapter**，resume = 較新 agy 出可用的 headless stream-json。見 `docs/spikes/CC-377-agy-headless-feasibility.md`。umbrella [[CC-333]]。 | arch/portability | 2026-06-13 | — | P2 | design |
| CC-381 | 🟡 deferred | **[arch: install host-PM-aware — 每個可當主 PM 的 host runtime 都對應寫入設定，不只 claude]** `install.sh`/`install-hooks.sh` 目前寫死 claude harness（`~/.claude/settings.json` 的 hook 接線＋permissions allow-list＋statusline＋agents/commands 介面）——只有「claude 當 host PM」時才正確。codex（或未來 host）當主 PM 時設定面不同（`~/.codex/`、AGENTS.md、自有 sandbox/permission 模型，無 `~/.claude` PreToolUse hook），[[CC-334]]/[[CC-380]] 寫進 `~/.claude` 的 guard/權限接線在 codex-host 下完全不生效 → codex-PM 安裝拿不到任何 gate/guard plumbing。這是 [[CC-333]] 硬耦合 **layer 4（install 路徑）+ layer 3/5（hook 機制/設定格式）**，且是「誰當 host PM」這條軸，與 [[CC-373]]/[[CC-374]]（PM→executor 軸）正交。要求：install 變 host-PM-aware，對每個支援的 host runtime 由 manifest（關聯 [[CC-372]] runner_kind、[[CC-375]] manifest 衍生接線）衍生該 host 的等價設定（hook/guard、allow-list 或 sandbox policy、PM 介面），每 host 維持 install/uninstall/doctor 三方一致（[[CC-368]]）。排在 v0.6.0 executor-abstraction 核心（[[CC-373]]..[[CC-377]]）之後。umbrella [[CC-333]]。 | arch/install | 2026-06-14 | — | P2 | design |
| CC-388 | ✅ done | **[arch: claude adapter 作為一般 implementation executor，非僅 gate route]** [[CC-383]] 已證 claude 獨立 headless `claude --print` 於 **gate route**。本票驗證並補齊 `pmctl dispatch run --adapter claude` 用於**一般 implementation brief**（非 gate）：一次真實 dispatch run，輸出契約 `.agent-trace/latest.last` 與 [[CC-386]] post-verify 對齊，確認 claude 與 codex 在 implementation 軸對稱。切換至 `--output-format stream-json --verbose`（JSONL 事件串流，對稱 codex），`.last` 提取從終止 `type==result` 事件取 `.result`。相依 [[CC-383]]、[[CC-386]]。umbrella [[CC-333]]。**See**: pr:#287 | arch/portability | 2026-06-15 | pr:#287 | P2 | design |
| CC-390 | 🔵 active | **[infra: codex dispatch trace-capture 強化 — trace 不依賴繼承 FD 跨 sandbox 存活]** codex 0.139.0 在 session 冷啟動最初 1–2 次 dispatch 偶發 trace-capture flake：wrapper 把 codex stdout 經**繼承 FD** 重導向到 `<work_dir>/.agent-trace/<ts>.jsonl`，該檔在 codex sandbox 邊界偶失（`.last` 由 codex 依路徑自開故存活、`.jsonl` 與 run-time stderr 經繼承 FD 偶失）。8 次 run 證**非確定性**、且 **fail-closed 安全**（trace 缺→post-verify 正確判 FAIL、不誤判 PASS）。`workspace-write` 與 `sandboxed` isolation 實 map 到同一 codex 指令（皆 `--sandbox workspace-write`、無 override）。候選修法：trace 寫 `<work_dir>` 外（XDG state／temp），或經 wrapper 控制的 pipe（tee）而非繼承 FD，使 trace 不跨 codex sandbox 邊界。**需可穩定複現才能驗證修法**。發現於 [[CC-387]] 真實驗收。umbrella [[CC-333]]。 | arch/portability | 2026-06-15 | — | P3 | design |
| CC-384 | 🟢 someday | **[arch: guard 腳本術語脫鉤 — `hook-*` → 平台中性 `guard-*`]** `scripts/hook-*.sh`（8 檔）＋ `hook-framework.sh` ＋ `hk_*`/`HK_*` 函式/變數 ＋ `PM_HOOK_*` env 沿用 Claude 平台的「hook」術語，但這些其實是 **PreToolUse 協定的策略腳本**：被 Claude 活 hook 觸發、**或**被 `pmctl guard check` 餵合成 JSON 驅動（cli-only 模式根本不是平台 hook）。[[CC-374]] 收口後 cli-only 那半讓「hook」更名實不符（user 2026-06-14 提出）。將整族改名為平台中性的 `guard-*`（如 `guard-executor-write.sh`），連同 framework/helper/env 前綴一起掃；保留 settings.json 的 `PreToolUse` 鍵（那是 Claude 平台自有、改不得）。純命名/機械改動但跨 install/uninstall/doctor 接線＋parity scanner＋測試＋文件——須與安全邊界改動分開的獨立 PR，不混進 guard 行為票。[[CC-333]] layer 2（hook 機制）/ 6（術語）；可與 [[CC-335]] deprecation 清掃同期。排在真 adapter [[CC-376]]/[[CC-377]] 之後。 | arch/portability | 2026-06-14 | — | P3 | design |
| CC-391 | ✅ done | **[arch(spike): detached-supervised dispatch — executor lifecycle ownership 軸]** Model B（[[CC-385]]/[[CC-386]]..[[CC-389]]）已使 executor 成獨立子程序、由 pmctl 三重機檢驗證，但派發仍 **foreground-sync**：`pmctl dispatch run` 阻塞、in-process 驗證、main 持有生命週期。本 spike（決策-only）決定是否新增一條與 [[CC-372]] `runner_kind` **正交**的 **lifecycle ownership** 軸：main 只建 run + `setsid`/`nohup` 起 detached supervisor → supervisor 持有 executor、跑 post-verify（重用 [[CC-386]]/[[CC-389]]）、寫 durable run-state（[[CC-225]]）、append events.jsonl（[[CC-211]] FSM）、best-effort 通知 listener（durable-outbox 為 load-bearing、fifo/socket 選配）。**定位修正**：lifecycle 是派發當下選擇（`pmctl dispatch run --lifecycle foreground\|detached` + config 預設），**非 manifest 欄位**；可 detach 資格由 runner_kind（headless-CLI Model B）推導，host-native 不可 detach。不加 `lifecycle_mode` 欄位、不動 schema 改名（避與 [[CC-384]] 撞）。收 [[CC-238]]（fan-out 無 timeout/attribution = 缺 supervisor 症狀）。排 v0.6.0 Phase 7（[[CC-376]]/[[CC-377]] 之後）。umbrella [[CC-333]]。**See**: pr:#288 | arch | 2026-06-15 | pr:#288 | P2 | design |
| CC-392 | ✅ done | **[arch: claude adapter runner_kind 分類漂移 — manifest 宣告 `host-native` 但 adapter 實跑 headless `claude --print`]** `adapters/claude/adapter.yaml` 宣告 `runner_kind: host-native`，但自 [[CC-383]]/[[CC-388]] 後 `adapters/claude/dispatch.sh` 實際是 headless `claude --print` 獨立子程序（行為上 cli-subprocess / Model B），讓 `runner_kind` 成為不可信謂詞、卡住 [[CC-391]] detach 資格推導。修法：`runner_kind: cli-subprocess` ＋ override `write_guard_mode: cli-only`、`needs_bash_guard: false`（三衍生旗標解析後行為 byte-identical；`dispatch_route` derive 至 main_thread_bash_background 僅 label，不驅動 exec 分支）；同步刷新 `executor-contract.md` profiles/guard 表與相關 code comment 過時的 host-native 措辭；加回歸鎖定。pr-gate standard = GO。關聯 [[CC-391]]、[[CC-373]]、[[CC-383]]、[[CC-388]]、[[guard-role-runtime]]。**See**: pr:#289 | arch/portability | 2026-06-15 | pr:#289 | P2 | design |
| CC-393 | 🟢 someday | **[design: portable-skill-substrate — CLI-agnostic skill 控制層]** 把 pm-dispatch 提升為 dispatch「skill-guided agents」：skill 為平台中立的 portable Markdown contract（方法），adapter 為平台轉譯層，core 管 task/context/permission/verify/memory，tool layer 為權限邊界。原則：capability-matching 非平台名、skill 不執行/不持狀態/不知平台、evidence-based completion、runtime 注入非全域安裝。重點：多數能力 pm-dispatch 已獨立長出（adapter manifest CC-372、post-verify CC-386、manifest guard CC-374/375），本票是替既有控制層命名/索引而非補洞。高槓桿子集＝control skills（guard-aware-brief、guard-result-review、markdown-drift-audit）。最小落地＝3 個 control skill＋thin Portable Skill v0 frontmatter，不做 marketplace/全域安裝/skill DSL。排程：v0.6.0（N≥2 抽象成立後）之後，與 [[CC-216]] v0.7.0 MCP 通用橋同層同期評估。設計捕捉見 `docs/notes/portable-skill-substrate.md`。umbrella [[CC-333]]。 | arch | 2026-06-16 | — | — | design |
| CC-394 | ✅ done | **[arch: 退場 `agents/claude-executor.md` — claude 收斂為 adapter-only（對齊 opencode）]** Model B 後 claude 主路是 headless `claude --print` 子程序（`adapters/claude/`，[[CC-388]]）；`Agent(claude-executor)` 已降級為「Claude 當 PM host 且 `claude` CLI 不在 PATH」的窄 fallback。它**不補任何能力缺口**（adapter 做同樣的事，與 codex-executor 的 danger-full-access 缺口不同），且持續課維護稅——[[CC-335]] 即因 trio 引用藏在此檔連兩輪 gate NO-GO。opencode（[[CC-376]]）已是 adapter-only、無 Agent，為目標形狀。退場範圍：刪 agent 檔＋guard role-model 的 executor(claude) 慣例分支＋install/uninstall 接線＋test-pmctl-guard/test-install/test-hook-framework 相關案例＋文件收斂（commands/pm.md Route B、executor-contract profiles、dispatch-brief fallback）。決策前置：確認無「Claude 為 host 但 claude CLI 缺席仍需跑 claude brief」的真實環境（傾向 fail-loud 而非默默降級）；保留 same-host 免 spawn 子程序的最佳化為唯一反論。umbrella [[CC-333]]（in-session Agent executor 層）。先於 [[CC-395]]。 | arch/portability | 2026-06-17 | — | P2 | design |
| CC-396 | 🟢 someday | **[chore: 清理 operational 檔內的 CC-provenance 註解]** scripts/adapters/cli/core 等非文件檔殘留「設計沿革票號」註解（如 `pmctl-guard.sh` 的 `# ...(CC-288; keying CC-291)`），違反 No-CC-in-operational 慣例，應搬去 docs/DECISIONS 或刪除。**明確排除**：測試 fixture data（如 `test-pmctl-task.sh` 用 `task create CC-101` 當輸入）與 ID 格式範例（如 `task.schema.json` 的 `e.g. CC-229`）——皆為合法測試輸入/說明，非違規。需逐處判斷非機械替換；估真違規子集遠小於原始 grep 計數。發現於 [[CC-395]] 退場工作。 | process/DX | 2026-06-17 | — | P3 | — |
| CC-395 | ✅ done | **[arch: 退場 `agents/codex-executor.md`（codex 收斂為 adapter-only）]** 對稱 [[CC-394]]。`Agent(codex-executor)` 現存唯一獨有能力是 `danger-full-access`（`isolation_level: none`）——退 agent 前須先拍板其去留。**DECISION 2026-06-17：選 (A) 砍掉 codex full-access**——codex 最高權限收斂為 `workspace-write` 真沙箱，brief 帶 `none` 在所有 route fail-loud REJECT。依據：codex full-access 非 load-bearing（有 workspace-write 安全預設）、零實際使用、Agent 閘是 Model B 前的遺產、claude 經 [[CC-394]] 已在同一 end-state；opencode 的 `none` 為 load-bearing 故不動。退場 plan（同 [[CC-394]] 機械性、零能力損失）：full-access 收口 ＋ 退 agent 檔/guard/install/test ＋ 文件收斂。security gate 風險低（收窄非放寬）。實作後 pr-gate full tier 首輪 NO-GO（raw `--sandbox danger-full-access` 旁路）→ 於 adapter chokepoint 修復＋回歸 → 重跑 GO。排在 [[CC-394]] 之後。umbrella [[CC-333]]。 | arch/security | 2026-06-16 | pr:#294 | P3 | design |
| CC-397 | ✅ done | **[refactor: extract pmctl_dispatch_run executor tail + persist footer durably]** Phase 7c-1 groundwork for detached-supervised dispatch ([[CC-391]]). Extract the post-preflight executor tail (invoke → footer → verify → terminal state + [[CC-225]] record) into one shared internal function (behavior-identical), and replace the ephemeral mktemp footer with a durable per-run `.agent-trace/<run_id>.footer` so a later supervisor crash between adapter exit and post-verify cannot lose the footer-derived per-run paths ([[CC-305]] explicit-path contract preserved). No supervisor/lifecycle surface yet ([[CC-391]]落地 7c-2). umbrella [[CC-333]]. | arch | 2026-06-17 | — | P2 | design |
| CC-398 | ✅ done | **[feat: dispatch lifecycle axis — `--lifecycle detached` + synchronous supervisor boundary]** Phase 7c-2a of [[CC-391]]. Add the dispatch-time lifecycle axis: `pmctl dispatch run --lifecycle foreground\|detached` (+ `dispatch.lifecycle` config default), detach-eligibility DERIVED from `runner_kind` (`runner_kind_detach_eligible`; cli-subprocess=yes, host-native=no), reject ineligible adapters pre-launch, and a new `scripts/dispatch-supervisor.sh` that consumes a pmctl-produced run-spec (v2: trusted `--cd`/`--brief-file` scalars + non-core passthrough) and RE-RUNS the full security preflight (name/containment/route + brief-validate + guard) so it is not a bypass door — guarded brief == validated brief == executed brief. Supervisor runs SYNCHRONOUSLY (behavior-equivalent to foreground); `setsid`/`nohup` true detachment + `pmctl dispatch wait` are 7c-2b ([[CC-399]]). HARD security+risk gate. umbrella [[CC-333]]. | arch | 2026-06-17 | — | P2 | design |
| CC-399 | ✅ done | **[feat: detached dispatch true detachment + `pmctl dispatch wait`]** Phase 7c-2b of [[CC-391]]. Flip the `scripts/dispatch-supervisor.sh` launch to `setsid`/`nohup` with redirected stdio so the supervisor survives the caller exiting; `--lifecycle detached` returns a `run_id` immediately (pending/dispatched written before return); add `pmctl dispatch wait <run_id>` resolving the terminal outcome from the durable `.dispatch-results/<run_id>.md` record ([[CC-225]]; run_id is identity, PID advisory only). Builds on the 7c-2a ([[CC-398]]) supervisor + run-spec. Then 7c-3 = [[CC-238]] generic supervisor timeout + per-child attribution. HARD security/risk gate approved full env inheritance for login-auth CLI deployment. umbrella [[CC-333]]. **See**: pr:#298 | arch | 2026-06-18 | pr:#298 | P2 | design |

---

## Convention

**ID scheme**: `CC-NNN` sequential. ID gaps are normal — use the `epic` column (see `pm/schema.md §2.4.5`) for semantic grouping instead of ID ranges. The `CC-1NN`/`CC-2NN` range-reservation convention is deprecated (see `DECISIONS.md#2026-05-19-deprecate-id-gap-convention`).

**Sub-letter IDs**: `CC-NNNa`, `CC-NNNb`, `CC-NNNc` are follow-up tickets to a parent `CC-NNN`, with independent lifecycles.

**Status legend** — _non-terminal_ (stay on the board):
- `🔵 active` — in backlog (not-started / in-progress / blocked)
- `⏸ deferred` / `🟡 deferred` — waiting on external condition, not scheduled
- `🟢 someday` — valid idea, no expected schedule
- `⚠️ partial YYYY-MM-DD` — partially shipped; sub-items remain open (see body)

_Terminal_ (CC-378: swept OUT to `BACKLOG-ARCHIVE.md` by `scripts/archive-closed-backlog.sh` — index row + body both leave BACKLOG.md, no stub):
- `✅ done [YYYY-MM-DD]` — completed; date optional. **Terminal + archived** (the old soft-close-stays-active rule was retired — see DECISIONS 2026-06-14).
- `✅ closed YYYY-MM-DD` — shipped, PR-backed dated variant of `done`; terminal.
- `🟢 superseded YYYY-MM-DD` — superseded by a later item; archived body keeps a `Superseded by [[CC-NNN]]` pointer. (Same 🟢 glyph as `someday` but opposite liveness — terminal rows leave the board on the next archive run, so a 🟢 left on the board should only be `someday`.)
- `🚫 dropped YYYY-MM-DD` — will not do; archived body keeps `See: DECISIONS.md` if decided.

**Archival**: terminal tickets are swept entirely to `BACKLOG-ARCHIVE.md` (no `**See**:` stub remains in BACKLOG.md). Query closed items via the archive's body headings.

**Priority column**: `P1`（本週必做）/ `P2`（本 sprint）/ `P3`（排隊）/ `—`（未設）。
**Epic column**: `oss`（CC-OSS 公開源碼系列）/ `reuse-debt`（技術債重用）/ `hygiene`（流程維護）/ `design`（新功能架構設計與 interface 決策）/ `spike`（調查類任務）/ `—`（其他）。
向下相容：v1.1/v1.2 file 中缺此兩欄的列只 emit 警告（不阻斷 gate）。

<!-- archived stubs — full text in BACKLOG-ARCHIVE.md -->

## CC-381 — arch: install host-PM-aware 🟡 deferred

**Problem**: `install.sh` / `install-hooks.sh` 把整個安裝面寫死成 claude harness：PreToolUse/SessionEnd 等 hook 接進 `~/.claude/settings.json`、reviewer 與 dispatch 的 `permissions.allow`、statusline、以及 `agents/` `commands/` 的 PM 介面，全部假設「claude 是 host PM」。一旦 codex（或未來 host）當主 PM，這些都不對：codex 的設定面是 `~/.codex/` ＋ `AGENTS.md` ＋自有 sandbox/approval 模型，沒有 `~/.claude` 那套 PreToolUse hook。[[CC-334]]/[[CC-380]] 把 reviewer guard 與 allow-list 寫進 `~/.claude/settings.json`——在 codex-host 下根本不載入，等於 codex-PM 安裝拿不到任何 gate/guard plumbing。

**這是哪條軸**: 「誰當 host PM」的軸，與目前 v0.6.0 在做的「PM→executor」軸（[[CC-373]]/[[CC-374]]）**正交**。runner_kind（[[CC-372]]）解的是「被驅動的 executor 怎麼到達」；本票解的是「驅動者（host PM runtime）的安裝/設定面」。對應 [[CC-333]] 七耦合的 **layer 4（install 路徑 `~/.claude/`）＋ layer 3/5（hook 機制／設定格式）**，memory 已標記為「later」。

**Requirement**:
- install 變 host-PM-aware：對每個支援當 PM 的 host runtime，由 manifest 衍生該 host 的等價設定 target＋format（hook/guard 接線、allow-list 或 sandbox/approval policy、PM 命令介面），而非寫死 `~/.claude/`。
- 與 [[CC-372]] runner_kind ＋ [[CC-375]]（manifest 衍生接線）對齊：host 的「設定面在哪、長怎樣」應是 manifest 宣告，不是程式碼常數。
- 每個 host 維持 install / uninstall / doctor 三方一致（[[CC-368]] 教訓），並各自有回歸測試。
- 釐清跨 host 的 guard 落點：claude-host 走 `~/.claude` PreToolUse hook；codex-host 需把對應 guard 放進 codex 的攔截點（或退回 cli-only 由 `pmctl guard check` 撐）。**Update 2026-06-14（user）**：Codex 現在已有 hook 機制（可能不完全）——所以 codex-host 不必只能走 cli-only fallback，可評估把 write/bash guard 接進 codex 原生 hook（對齊 [[CC-372]] `write_guard_mode=hook`），是本票把 install 變 host-aware 時要勘的能力。`docs/executor-contract.md` 已不再斷言「非 Claude host 無 PreToolUse 等價」。

**Non-goals**: 不是 executor 軸（[[CC-373]]/[[CC-374]] 已涵蓋 PM→codex/claude/opencode/agy 的 dispatch）；本票只管「host PM runtime 的安裝設定面」。不在本票決定 codex-host 的最終 hook 機制細節——先把 install 的 host 分派抽象出來。

**Sequencing**: 排在 v0.6.0 executor-abstraction 核心（[[CC-373]]..[[CC-377]]）之後；可能落在 v0.7.0（與 [[CC-333]] layer 1/7、MCP 同期評估）。

**See**: [[CC-333]] umbrella（layer 4 install-path）、關聯 [[CC-380]]（暴露 install 的 claude-host 中心性）、[[guard-role-runtime]]（role×runtime 兩軸）、[[CC-375]]（manifest 衍生接線）。

---

## CC-384 — arch: guard 腳本術語脫鉤（`hook-*` → `guard-*`）🟢 someday

**Problem（user 2026-06-14）**: `scripts/hook-*.sh`（8 檔）、`scripts/lib/hook-framework.sh`、`hk_*`/`HK_*` 函式與變數、`PM_HOOK_*` env 都沿用 Claude 平台的「hook」術語。但它們本質是 **PreToolUse 協定的策略腳本**：輸入是 PreToolUse 形狀的 JSON、輸出是 exit code，可由 (a) Claude 活 PreToolUse 觸發，**或** (b) `pmctl guard check` 合成同樣的 JSON 餵入。後者（尤其 [[CC-374]] 收口後 claude 的 cli-only 路徑）**根本不是平台 hook**，只是被餵合成輸入的策略評估器——「hook」對這一半名實不符。

**Why**: 這是 [[CC-333]] layer 2（hook 機制）/ layer 6（術語）的硬耦合：Claude 平台詞漏進想做 runtime-agnostic 的核心。對齊 runner_kind/manifest 之後，命名也應該中性化。

**Requirement**:
- `hook-*.sh` → 平台中性 `guard-*`（如 `guard-executor-write.sh`、`guard-pm-write.sh`、`guard-codex-bash.sh`）；`hook-framework.sh` → `guard-framework.sh`；`hk_*`/`HK_*` → `g_*`/`G_*`（或等價）；`PM_HOOK_*` env 評估是否改名（保 deprecated alias）。
- **保留** settings.json 的 `PreToolUse` 鍵——那是 Claude 平台自有、不可改；被接進去的腳本對 Claude 而言確實是 hook。
- 三方一致：install/uninstall/doctor 接線 + doctor parity scanner + 測試 + 文件同步改。

**Non-goals / 切割**: 純命名/機械改動，**不可**與 guard 行為/安全邊界票混在同一 PR（會污染 security review）。獨立 PR。

**Sequencing**: 排在真 adapter [[CC-376]]/[[CC-377]] 之後；可與 [[CC-335]] deprecation 清掃同期評估。

**See**: [[CC-374]]（收口後讓 cli-only 名實不符浮現）、[[CC-372]]（runner_kind/write_guard_mode）、[[CC-335]]（deprecation sweep）、umbrella [[CC-333]]。

---

## CC-393 — design: portable-skill-substrate — CLI-agnostic skill 控制層 🟢 someday

**Type**: design seed（想法捕捉；非 milestone 承諾）

**Thesis（session 2026-06-16）**: pm-dispatch 從 dispatch agents 升級為 dispatch **skill-guided agents**。skill = 平台中立的 portable Markdown contract（方法）、adapter = 平台轉譯層、core = 管 task/context/permission/verify/memory、tool layer = 權限邊界。

**Principles**: capability-matching 非平台名；skill 不執行/不持狀態/不知平台；evidence-based completion；runtime 注入非全域安裝。

**Key caveat**: 多數能力 pm-dispatch 已獨立長出——adapter manifest（[[CC-372]]）、post-verify 唯一驗證者（[[CC-386]]）、manifest-driven guard（[[CC-374]]/[[CC-375]]）。本票是替既有控制層**命名/索引**，不是補洞。

**Highest-leverage subset（control skills）**: `guard-aware-brief`（brief 帶 relevant controls + expected guards + completion condition）、`guard-result-review`（guard pass/fail → workflow decision，不改狀態）、`markdown-drift-audit`（Markdown ↔ script ↔ template ↔ core 漂移）。閉環：rule → brief → guard → evidence → state decision。

**Minimal landing**: 不做 marketplace/全域安裝/skill DSL；只做 3 個 control skill + thin Portable Skill v0 frontmatter。

**Boundaries**: skill 不跑 shell、不查 DB、不改 task status、不繞 guard、不當 workflow engine。

**Sequencing**: 排 v0.6.0（executor 抽象在 N≥2 = [[CC-376]]+[[CC-377]] 證明成立）**之後**；自然歸宿與 [[CC-216]]（v0.7.0 MCP 通用橋）同層同期——兩者都讓任意 host 透過穩定、平台中立契約共用單一 pm-dispatch。

**See**: `docs/notes/portable-skill-substrate.md`（完整 session synthesis）、umbrella [[CC-333]]。

---

## CC-394 — arch: 退場 agents/claude-executor.md（claude 收斂為 adapter-only） ✅ 2026-06-17

**Problem**: Model B（[[CC-385]]）後，claude 的 canonical 執行路是 headless `claude --print` 子程序（`adapters/claude/`，[[CC-388]]/[[CC-392]]）。`Agent(claude-executor)` 已被 DECISIONS 2026-06-13 明訂降級為「Claude 當 PM host 時的 same-host 最佳化」，pm.md Route B 進一步把它收成「`claude` CLI 不在 PATH 時」的窄 fallback。

**Why 退場**:
1. **零能力缺口** — claude-executor 與 claude adapter 做完全一樣的事，唯一觸發是「binary 缺席」；對比 codex-executor 補的是 bash route 拒絕的 `danger-full-access`（真功能）。
2. **這正是 [[CC-333]] 要拆的耦合** — `Agent()`-spawn = Claude-runtime 專屬執行模型；Model B/adapter 的重點就是讓執行成為與 host 無關的 CLI 子程序。
3. **持續維護稅** — [[CC-335]] 即因 trio 引用藏在此檔導致 gate 連兩輪 NO-GO；每次契約改動都要維持此檔一致。
4. **目標形狀已存在** — opencode（[[CC-376]]）就是 adapter-only、無 Agent；本票讓 claude 對齊它。

**決策前置**: 確認無「Claude 為 host、但 `claude` CLI 二進位缺席、卻仍需執行 claude brief」的真實環境（repo 哲學 [[CC-389]] 傾向 fail-loud 而非默默降級）。唯一反論 = 重視 same-host 免 spawn 子程序的最佳化（DECISIONS:245）；若採納則改為「保留但文件收斂成單一觸發條件」。

**退場 checklist**: 刪 `agents/claude-executor.md`；`pmctl-guard.sh` 的 `executor(claude)` 慣例分支；`install-hooks.sh`/`uninstall-hooks.sh`/`doctor.sh` 相關接線；`test-pmctl-guard.sh`/`test-install.sh`/`test-hook-framework.sh` 案例；文件收斂（`commands/pm.md` Route B、`docs/executor-contract.md` profiles、`docs/dispatch-brief.md` §Fallback）。

**Sequencing**: 機械性、零能力損失，可先於 [[CC-395]]。umbrella [[CC-333]]（in-session Agent executor 層）。

**See**: pr:#293

**See**: [[CC-395]]（codex 對稱退場）、[[CC-333]]、[[CC-388]]、[[CC-376]]。

---

## CC-395 — arch: 退場 agents/codex-executor.md + 決定 danger-full-access 去留 ✅ 2026-06-17

**See**: pr:#294

**Problem**: 對稱 [[CC-394]]，把 codex 也收斂為 adapter-only。`Agent(codex-executor)` 現存的唯一獨有能力是 `danger-full-access`（`isolation_level: none`）——`handover-validate.sh:330` hard-reject `none` 於 `main_thread_bash_background`（opencode 除外），只允許經 `agent_executor` route = 人為明示 `Agent(codex-executor)` spawn。退 agent 前必須先拍板 full-access 去留。

**DECISION (2026-06-17): 選 (A) — 砍掉 codex full-access。** codex 最高權限收斂為 `workspace-write` 真沙箱；任何 codex brief 帶 `isolation_level: none` 在**所有 route** fail-loud REJECT。決策依據見下方校正分析。未來若真有 full-access 需求，再以獨立明示旗標（原 (b) 形狀）deliberate 重新引入；現在不為零使用的能力背安全債。

**校正分析（取代原 (a)/(b) 二選一框架）**:
- **codex full-access 非 load-bearing**：codex 預設 `workspace-write` → `--sandbox workspace-write` 是可無人值守寫檔的真沙箱，正常 brief 完全不需要 `none`。砍掉 `none` 不影響任何現行 dispatch。
- **opencode 的 `none` 才是 load-bearing，不能砍**：opencode 無細粒度沙箱，`none` → `--dangerously-skip-permissions` 是它**唯一**的無人值守模式（CC-376）。所以「codex 擋 / opencode 放」的不對稱是**有原則的**（依 executor 是否具沙箱預設），不是要消除的 smell。本票只動 codex，opencode 不動。
- **零實際使用**：`git log -S "isolation_level: none"` 掃全史，`none` 只出現在退場/sweep/test commit，**無任何真實 brief 用過 codex full-access**。
- **Agent 閘是 Model A 遺產**：full-access 綁 `Agent(codex-executor)` 的設計源於子代理自寫 brief 時代；Model B（[[CC-385]]）後所有 brief 由 main thread 撰寫，此閘的原始威脅模型已位移。
- **claude 已在 A end-state**：[[CC-394]] 退 claude-executor 後，claude full-access 已無路可達（bash route reject `none` + 無 Agent route），且 claude `workspace-write` → `acceptEdits` 同樣是安全無人值守預設。決策 A 等於讓 codex 與 claude 現狀對齊——最終只剩 opencode 保留 `none`。

**退場 plan（A 形狀，零能力損失，同 [[CC-394]] 機械性）**:
1. **full-access 收口**：`handover-validate.sh` 將 `none` 對 codex 的 reject 從「僅 bash route」擴到**所有 route**（含 `agent_executor`）；codex `isolation-map.yaml` 移除 `none` 條目；訊息指向「codex max isolation = workspace-write」。opencode 的 `none` 豁免保留不動。實作可沿用現有 executor-name 特例，或更乾淨地由「adapter 是否具 sandboxed level」推導（thin-slice 不強制）。
2. **退 agent 檔**：刪 `agents/codex-executor.md` ＋ guard role-model 的 executor(codex) 慣例分支 ＋ install/uninstall 接線 ＋ `test-pmctl-guard`／`test-install`／`test-hook-framework`／`test-hooks` 相關案例。
3. **文件收斂**：`commands/pm.md`（移除 full-access 經 Agent fallback 的指引）、`docs/dispatch-brief.md` §Fallback（移除 full-access 列＋`agent_executor` full-access 描述）、`docs/executor-contract.md`、`docs/CONCEPTS.md`、`docs/review-model.md`。
4. **回歸鎖定**：新增 codex `none` 在所有 route 被 REJECT 的測試；opencode `none` on bash route 仍 accept 的既有測試保留。

**Sequencing**: 排在 [[CC-394]] 之後（已 MERGED main 185adfc）。決策已拍板，ready to implement。security/risk hard gate：本案是**收窄**權限（移除 full-access 出口），非放寬，過 gate 風險低。umbrella [[CC-333]]。

**claude 對稱（本票一併收）**: 收口邏輯改為「`none` 僅 opencode 允許，其餘 executor 全 route REJECT」，故 claude 的 `none`（bypassPermissions）亦同步變成全 route 明確拒絕（先前僅 bash route reject、agent route 未明確且已無 claude agent）。語義更清、與 codex 對稱，零行為風險（claude full-access 本就不可達）。

**衍生**: 退場工作中發現 operational 檔（scripts/adapters/cli/core）殘留設計沿革票號註解違反 No-CC-in-operational 慣例，拆 [[CC-396]] 專責清理（明確排除測試 fixture data 與 ID 格式範例）。

**See**: [[CC-394]]（claude 對稱、先行、已 MERGED）、[[CC-333]]、[[CC-385]]（Model B 使 brief 全由 main thread 撰寫，鬆動 Agent 閘）、[[CC-376]]（opencode load-bearing `none` 來源）、[[CC-387]]、[[CC-391]]（無 Agent 後 lifecycle 簡化）、[[CC-396]]（衍生清理票）。

---

## CC-396 — chore: 清理 operational 檔內的 CC-provenance 註解 🟢 someday

**Problem**: `scripts/`、`adapters/`、`cli/`、`core/` 等非文件檔殘留設計沿革票號註解（如 `scripts/lib/pmctl-guard.sh:3` `# Executor-agnostic guard-check front-end (CC-288; role×runtime keying CC-291)`），違反 No-CC-in-operational 慣例（票號只進 BACKLOG/MILESTONES/CHANGELOG/docs）。

**重要 scope 界定**: 原始 `grep -rE "CC-[0-9]+"` 在 operational 樹得數百筆，但**絕大多數非違規**：
- **測試 fixture data**（保留）—— `test-pmctl-task.sh`（228 筆）、`test-archive-closed-backlog.sh`（96 筆）等用 `CC-101`/`CC-103.json` 當 backlog/task 工具的測試輸入；刪了測試會壞。
- **ID 格式範例**（保留）—— `core/schema/task.schema.json` 的 `"e.g. CC-229, JS-106"` 是說明 ticket-id 文法。
- **provenance 註解**（本票目標）—— 程式碼註解裡記設計沿革的票號，應搬 docs/DECISIONS 或刪。

**做法**: 逐處判斷（非機械 sed 替換）；分類 fixture/範例/沿革，只動沿革子集。完成後加 lint 規則防回歸（選配，視子集大小）。

**Sequencing**: [[CC-395]] 合併後另開 PR，避免污染退場 diff。發現於 [[CC-395]] 退場工作。umbrella [[CC-333]]（衛生軸）。

---

## CC-397 — refactor: extract pmctl_dispatch_run executor tail + persist footer durably ✅ 2026-06-17

**Closed 2026-06-17**: Implemented Phase 7c-1 groundwork for detached-supervised dispatch. `pmctl_dispatch_run` keeps the existing guard/config preflight and delegates the post-preflight executor tail to `pmctl_dispatch_execute_tail`, preserving the foreground transition order and exit-code behavior. Adapter stdout footer capture now writes `<work_dir>/.agent-trace/<run_id>.footer` durably instead of a deleted `mktemp`, while post-verify still receives the footer-derived explicit `--last`/`--jsonl`/`--stderr` paths. No supervisor, detached lifecycle, start/wait command, or run schema surface was added.

**Problem / 目標**: [[CC-391]] 的 detached-supervised dispatch 軸需要 supervisor 之後重用 foreground dispatch 已驗證的 executor tail：adapter invocation → footer parse → verifying → post-verify → terminal state + [[CC-225]] durable record。現況 tail inline 在 `pmctl_dispatch_run`，且 footer 只存在於 `mktemp`，parse 後立即刪除；若未來 supervisor 在 adapter exit 後、post-verify 前崩潰，會丟失 [[CC-305]] explicit-path handoff 的 per-run artifact paths。

**Requirement**:
- Extract post-preflight tail into one shared internal function, behavior-identical for foreground dispatch: pending → dispatched → adapter pipeline → verifying → failed/ok, same exit propagation, same post-verify stdout/stderr, same record write semantics.
- Replace the ephemeral footer temp file with durable `<work_dir>/.agent-trace/<run_id>.footer`; create `.agent-trace/` defensively before `tee`; do not delete the footer.
- Preserve the explicit-path contract: footer `trace:`/`last:`/`stderr:` are still parsed and passed to `dispatch-post-verify.sh` as `--jsonl`/`--last`/`--stderr`; post-verify does not read `latest.*` when explicit paths are present.
- Keep Phase 7c-1 scoped to groundwork only: no `--lifecycle`, no supervisor process, no detach/start/wait command, no `run.schema.json` change.

**Verification**: `scripts/test-pmctl-dispatch.sh` covers durable footer persistence with per-run artifact paths and direct invocation of the extracted tail, including the foreground lifecycle order `pending,dispatched,verifying,ok`.

**See**: [[CC-391]], [[CC-225]], [[CC-305]], [[CC-333]].

---

## CC-398 — feat: dispatch lifecycle axis — `--lifecycle detached` + synchronous supervisor boundary ✅ 2026-06-17

**Closed 2026-06-17**: Implemented Phase 7c-2a of the detached-supervised dispatch axis. Adds the dispatch-time lifecycle choice without true process detachment yet, so the security boundary lands and gates on its own before the `setsid`/`nohup` mechanics (7c-2b, [[CC-399]]).

**Problem / 目標**: [[CC-391]] spike (partial-adopt) 的遷移順序 D7 steps 3–4：在真正 detach 之前，先把 lifecycle 作為派發當下的選擇引入、把 supervisor 邊界立起來、並讓「supervisor 不能成為 guard 旁路」這條紅線可獨立審查。eligibility 由 [[CC-372]] `runner_kind` 推導（非 manifest 欄位），符合 [[CC-391]] modeling red line。

**Requirement / 實作**:
- `runner_kind_detach_eligible <runner_kind>` in `scripts/lib/runner-kind.sh` (cli-subprocess→0 eligible, host-native→1, unknown→2; exported).
- `pmctl dispatch run --lifecycle foreground|detached` parsing (consumed by pmctl, never forwarded to the adapter) + `dispatch.lifecycle` config key → `PM_CFG_LIFECYCLE` (`scripts/lib/pmctl-config.sh`); precedence flag > config > foreground.
- `pmctl_dispatch_detach_eligible` rejects ineligible adapters BEFORE any executor launch; detached + `--print-cmd` and detached + auto-pack rejected pre-launch.
- Factored `pmctl_dispatch_resolve_adapter` (name + symlink/containment + route allowlist) and `pmctl_dispatch_validate_brief` (brief-validate) as shared preflight steps used by both `pmctl_dispatch_run` and the supervisor; existing error messages preserved.
- `pmctl_dispatch_write_runspec` writes a durable `<work_dir>/.agent-trace/<run_id>.runspec` (schema v2): `--cd`/`--brief-file` as trusted scalars + only the non-core adapter args as base64 passthrough (atomic mktemp+mv). `pmctl_dispatch_run_detached` splits the core args out of forward, records them as scalars, and asserts the forwarded brief equals the guarded brief.
- New `scripts/dispatch-supervisor.sh`: reads `--run-spec`, derives REPO_ROOT from its own path, rejects passthrough args smuggling a second `--cd`/`--brief-file`, RE-RUNS the full preflight (resolve_adapter → validate_brief → guard) on the SAME brief it will execute, rebuilds the adapter command from trusted scalars, then calls `pmctl_dispatch_execute_tail`. Not a bypass door — a tampered run-spec cannot reach an executor pmctl would refuse, nor execute a brief different from the one guarded/validated.
- 7c-2a scope only: supervisor invoked SYNCHRONOUSLY; no `setsid`/`nohup`, no `dispatch start`/`wait`, no `run.schema.json` change.

**Gate (full tier)**: first run NO-GO (5/5 reviewers) — supervisor skipped `brief-validate.sh` and the run-spec split trust between guarded scalars and opaque forward args (guard one brief, execute another). Fixed by run-spec v2 (trusted core scalars + non-core passthrough), supervisor brief-validate, smuggle rejection, and detached+auto-pack rejection. The medium log-hygiene finding was an artifact of the codex sandbox's own landlock denial on `~/.claude/logs` (our `hk_audit` is already best-effort silent), not a code defect.

**Verification**: `scripts/test-dispatch-lifecycle.sh` (21 cases): foreground default writes no run-spec; detached behavior-equivalent (+v2 run-spec, ok record); adapter-failure exit propagation; invalid `--lifecycle`; detached+`--print-cmd`; detached+auto-pack; ineligible adapter rejected pre-launch (no executor run); eligibility unit gate over cli-subprocess/host-native/missing/unknown; `dispatch.lifecycle=detached` config; flag beats config; supervisor rejects non-routable + path-traversal adapters, missing run-spec, malformed brief (before launch), and smuggled `--brief-file`. Existing `test-pmctl-dispatch.sh` / `test-dispatch-record.sh` / `test-runner-kind.sh` unchanged-green (foreground identical).

**See**: [[CC-391]], [[CC-397]], [[CC-372]], [[CC-225]], [[CC-399]], [[CC-333]].

---

## CC-399 — feat: detached dispatch true detachment + `pmctl dispatch wait` ✅ 2026-06-18

**Closed 2026-06-18**: Implemented true detached dispatch for the 7c-2b supervisor slice. `pmctl dispatch run --lifecycle detached` now writes the run-spec, records the initial pending/dispatched FSM rows, launches `scripts/dispatch-supervisor.sh` via `setsid nohup ... &` (falling back to `nohup ... & disown` where `setsid` is unavailable), writes `.agent-trace/<run_id>.supervisor.pid` as advisory diagnostics, redirects supervisor output to `.agent-trace/<run_id>.supervisor.log`, prints only the `run_id`, and exits 0 without waiting for the adapter.

`pmctl dispatch wait <run_id> --cd <work_dir>` was added as the reattach surface. It requires explicit `--cd`, validates the run id, polls only `.dispatch-results/<run_id>.md` through `dispatch_record_read_state`, treats an absent record as non-terminal, times out with 124, and exits with the recorded run exit code once `final_state` is terminal. Security gate decision for this slice: the detached supervisor inherits the same environment as foreground dispatch; no unset/allowlist layer is added because the deployment uses login-authenticated CLIs rather than API keys in env.

**Problem / 目標**: Phase 7c-2b of [[CC-391]] — turn the 7c-2a ([[CC-398]]) synchronous supervisor into a genuinely detached one (D7 step 5). The boundary and run-spec already exist; this slice adds true process detachment and the reattach/wait surface.

**Requirement**:
- Launch `scripts/dispatch-supervisor.sh` via `setsid`/`nohup` with stdio redirected to a per-run supervisor log; the supervisor must survive the calling shell/session exiting and own + reap the executor child.
- `pmctl dispatch run --lifecycle detached` returns a `run_id` immediately, after writing `pending`/`dispatched`, instead of blocking on the tail.
- `pmctl dispatch wait <run_id>` resolves the terminal outcome from the durable `.dispatch-results/<run_id>.md` record ([[CC-225]]); identity is `run_id`, PID is advisory only and must include recorded start time when used.
- Security gate: inherit the foreground dispatch environment unchanged for detached supervisors; no env unset/allowlist layer in this deployment because executor CLIs use login auth, not API keys in env.
- Acceptance: one real eligible adapter detached run returns a run_id before completion, the original thread exits, and `dispatch wait` reports the terminal outcome from durable state with no orphaned child.

**Sequencing**: after [[CC-398]]; then 7c-3 = [[CC-238]] (generic supervisor timeout + per-child attribution, retire the pr-gate fan-out one-off). HARD security+risk gate passed for the env inheritance decision above.

**See**: [[CC-391]], [[CC-398]], [[CC-225]], [[CC-238]], [[CC-333]], `docs/spikes/CC-391-detached-supervised-dispatch-scope.md`, pr:#298.

---

## CC-388 — arch: claude adapter 作為一般 implementation executor ✅ 2026-06-15

**Problem / 目標**: [[CC-383]] 證明了 claude 獨立 headless `claude --print` 於 **gate route**，但「一般 implementation 派發」軸尚未驗證對稱。Model B 全面上路要求 `pmctl dispatch run --adapter claude` 能跑一般 implementation brief，非僅 gate 特例。

**Requirement**:
- 驗證並補齊 `pmctl dispatch run --adapter claude --brief-file … --cd …` 用於一般 implementation brief（含 file-writing brief）。
- 輸出契約 `.agent-trace/latest.last` 與 [[CC-386]] post-verify 對齊；claude 與 codex 在 implementation 軸的 dispatch/verify 路徑對稱。
- 釐清 claude 被派發為 executor 時的 isolation/permission（對比其當 host PM 時的 host-native 角色，[[guard-role-runtime]]）。

**串流/可觀察性 — 決定 (b)（user 2026-06-15）**: codex 用 `codex exec --json` = 逐事件 JSONL 串流（可逐條確認、有 `turn.completed`）；claude adapter 現用 `claude -p --output-format json` = 結尾單一 JSON blob（`.result`/`.is_error`，無逐步串流）。**決定：採串流**——claude adapter 改 `--output-format stream-json`（`--verbose` 視需要），取得逐事件 JSONL，與 codex 對稱可逐條確認（user 偏好：能串流就優先串流，見 [[feedback_prefer_streaming_executor_output]]）。實作要點：(1) `adapters/claude/dispatch.sh` 的 `--output-format json` → `stream-json`；(2) `.last` 萃取從「單物件 `.result`」改為「stream 末筆 `type==result` 事件的 `.result`」；(3) `is_error` 偵測改抓該 result 事件；(4) token usage 萃取同步調整。注意 [[CC-386]] 結構完整性檢查（`jq empty`）對單 blob 與 stream 兩種 shape 皆已成立，故此改動只增 observability，不影響 trace 驗證正確性、CC-386 零改動。

**驗收**: 一次真實 `pmctl dispatch run --adapter claude` implementation run，產出檔案、self_verify 通過、[[CC-386]] 三重機檢判 PASS。

**Dependencies**: [[CC-383]]、[[CC-386]]。umbrella [[CC-333]]。

**See**: pr:#287

---

## CC-390 — infra: codex dispatch trace-capture 強化 🔵 active

**Problem / 目標**: [[CC-387]] 真實驗收期間發現，codex 0.139.0 在 session 冷啟動最初 1–2 次 dispatch 偶發 trace-capture flake。`adapters/codex/dispatch.sh` 把 codex stdout 經**繼承 FD**（`> "$TRACE"`）重導向到 `<work_dir>/.agent-trace/<ts>.jsonl`，但該檔在 codex sandbox 邊界偶失：`.last`（codex 以 `--output-last-message` 依路徑自開）存活，`.jsonl` 與 run-time `.stderr`（皆經 wrapper 繼承 FD）偶失，導致 [[CC-386]] post-verify「trace not found / 結構不完整」FAIL。

**證據（8 次 run）**: 非確定性——最初 2 次失敗、其後連 6 次完整 dispatch 全綠（含全新 repo 的 first-run）。已否證：isolation 值（`workspace-write` 與 `sandboxed` map 到**同一** codex 指令）、codex 是否 mutate workspace、fresh-repo first-run。最符合：codex CLI 冷啟動 transient（與 `agents/codex-executor.md` 既載「silent startup 已知 transient」一致）。

**安全性質**: **fail-closed**——trace 缺失時 post-verify 正確判 FAIL，**永不誤判 PASS**；失敗方向是 false-negative（成功 run 被報為失敗），非 false-positive。故非緊急。

**候選修法**: (a) trace 寫 `<work_dir>` 外（XDG state／temp 目錄），使 trace 不在 codex sandbox 的 workspace 內、也不污染 git status；(b) codex stdout 經 wrapper 控制的 pipe（`tee`）而非繼承 FD 直寫 in-workspace 檔（需處理 `PIPESTATUS` 以保留 exit code）。(a) 動到 trace 合約（post-verify／footer／latest 指標／多處測試引用 `<work_dir>/.agent-trace/`），較大；(b) 較外科。**前提：須先能穩定複現才能驗證任一修法**。

**Dependencies**: [[CC-386]]（trace 驗證合約）。發現於 [[CC-387]]。umbrella [[CC-333]]。

---

## CC-376 — adapter: opencode executor ✅ 2026-06-16

**Problem / 目標**: 新增 opencode 作為第一個「第三方」executor adapter，驗證 v0.6.0 抽象：新增 executor 只需放 `adapters/opencode/`，不動核心。

**Requirement**:
- `adapters/opencode/`：`dispatch.sh`（叫起 opencode CLI，寫統一輸出契約 `.agent-trace/latest.last` + exit code）、`adapter.yaml`（含 [[CC-372]] `runner_kind`，opencode 為 CLI subprocess）、`isolation-map.yaml`（把統一 `--isolation` 翻成 opencode 的 sandbox/permission 旗標）。
- 主路 = `pmctl dispatch run --adapter opencode`；model-alias 解析按 [[CC-292]] executor-specific 約定（`default` alias → opencode 的 wire id）。
- 釐清 opencode 的 sandbox/permission 模型與 bash 攔截能力 → 決定 manifest 的 `needs_bash_guard`/`write_guard_mode`。

**驗收（抽象的證明）**: 落地過程若需修改 `executor-router.sh` 或 guard wrapper 核心，代表 [[CC-373]]/[[CC-374]] 抽象未竟——回頭補抽象，而非在 adapter 內 workaround。核心零改動已確認：`dispatch_route_for opencode` 純由 manifest 衍生。

**Additional**: `share/opencode-model-aliases.tsv`（6 個短 alias）；`fallback_chain` 宣告於 adapter.yaml；dispatch.sh 實作 sequential retry（5 free models，per-attempt timeout = total/N，min 120s）；三重錯誤偵測（exit code + session.error JSONL + step_finish 缺失）。

**Dependencies**: [[CC-373]]、[[CC-374]]。umbrella [[CC-333]]。

**See**: pr:#290

---

## CC-377 — adapter: Google Antigravity (`agy`) executor 🟡 deferred

**Status (2026-06-16)**: **DEFERRED — 待 agy 版本更新**。agy **有免費額度**（Gemini 3.x / Claude 4.6 / GPT-OSS 經 OAuth，成本非阻因）；暫緩純因 **headless CLI 尚未完善**。feasibility spike 證 agy 1.0.8 無 machine 契約，詳見 `docs/spikes/CC-377-agy-headless-feasibility.md`。實測：`--output-format`/`-o`/`--format`/`--log-level`/`--stream-format` 旗標皆被拒、無 `run` 子命令、`--print` 吐 prose narration（無 JSON/SSE、無語意終止事件）、headless 不穩（3/3 trivial-prompt 探針 timeout、不甩 do-not-use-tools 指令）。社群/AI 研究宣稱的 stream-json/SSE 模式不在 1.0.8（可能較新 build 才有）。**agy 仍為首選第二 adapter**。**Resume trigger（主路）**：較新 agy 出可用的 headless `--output-format stream-json` → 重跑探針，有 JSONL+終止事件即鏡像 `adapters/opencode/` 落地。**N≥2 影響**：暫未由 agy 達成；opencode（[[CC-376]]）為目前唯一獨立第三方 adapter；Phase 7 lifecycle 紅線（N≥2 後才做）出現 sequencing 缺口，待 maintainer 定奪（且 2026-06 免費 CLI 池枯竭，傾向等 agy 成熟而非另尋）。

**Problem / 目標**: 新增 Google Antigravity（CLI binary `agy`）作為第二個第三方 executor adapter，與 [[CC-376]] 對稱。第二個 adapter 的意義是驗證抽象在 **N≥2** 下成立——若 opencode 是特例僥倖，agy 會暴露出來。

**Note**: Google 的 **Gemini CLI 已棄用**；本票目標是 Antigravity 的 `agy` CLI，**不是 gemini**。adapter 目錄/名稱建議 `antigravity`（cli_binary `agy`），最終命名 impl 時定（須為 strict-identifier `^[a-z][a-z0-9_-]*$`）。

**Requirement**: 結構同 [[CC-376]]——`adapters/antigravity/` 的 dispatch.sh + adapter.yaml（`runner_kind`）+ isolation-map.yaml；主路 `pmctl dispatch run --adapter antigravity`；map sandbox/permission/model-alias；釐清 bash 攔截能力決定 guard 旗標。

**驗收**: 同 [[CC-376]]——零核心改動即可落地。

**Dependencies**: [[CC-373]]、[[CC-374]]。建議排在 [[CC-376]] 之後（第一個 adapter 若暴露抽象缺口，先補再上第二個）。umbrella [[CC-333]]。

---

## CC-391 — arch(spike): detached-supervised dispatch — executor lifecycle ownership 軸 ✅ 2026-06-15

**Type**: design spike（決策-only；本票不實作）
**Status**: closed — 決策已記錄並 fold 進 v0.6.0 Phase 7；落地（7c）以新子票追蹤（見 MILESTONES Phase 7）。**See**: pr:#288
**Relates**: [[CC-333]]（runtime 解耦 umbrella）、[[CC-385]]（Model B 決策 — 前置）、[[CC-386]]/[[CC-389]]（pmctl 三重機檢 = 驗證層，重用）、[[CC-211]]/[[CC-216]]（run-FSM + events.jsonl + MCP task 抽象 = durable substrate）、[[CC-225]]（durable result 記錄）、[[CC-238]]（fan-out hardening = 症狀）、[[CC-273]]（lifecycle *hook event* spec — 正交、勿混）、[[CC-376]]/[[CC-377]]（真 adapter — 排序前置）

**Problem / why now**: Model B（[[CC-385]]/[[CC-386]]..[[CC-389]]）已交付四件事中的兩件半——brief 由可信代碼落地、executor 為獨立子程序、結果由 `pmctl` 三重機檢驗證（exit + 結構完整性 + 語意終止事件）。但派發本身仍是 **foreground-sync**：`pmctl dispatch run` 阻塞、在 process 內跑 post-verify、**main thread 是生命週期擁有者**。缺的是：(1) 啟動後誰持有 executor 生命週期、main 死了能否續活；(2) 結果如何 durable 化；(3) listener 還活著時如何通知。這三題不是「pm-dispatch 怎麼到達 executor」（[[CC-372]] runner_kind 解的），而是「executor 啟動後誰持有它的生命週期」——是一條**正交的新軸**。

**The axis（user 2026-06-15 分析）**:

```
runner_kind     executor 怎麼被呼叫？        cli-subprocess / host-native / future mcp-tool
lifecycle       啟動後誰持有/等待/收尾？      foreground-sync / detached-supervised
notify          完成怎麼提醒活著的主線程？     durable-outbox(load-bearing) / fifo|socket(選配)
verify          誰判定結果可信？              pmctl-post-verify（= CC-386/389，已是現貨）
```

**定位修正（與初版 user 寫法的差異，spike 要拍板）**: `runner_kind` 是 executor 的**內在屬性**（有沒有 CLI、是不是 host）；foreground vs detached 是**派發當下呼叫者的選擇**，不是 executor 屬性——同一個 codex 可前景派發（盯著看）或 detached 派發（射後不理）。因此：
- lifecycle **不作 manifest 欄位**，作派發旗標 `pmctl dispatch run --lifecycle <foreground|detached>` + `dispatch.lifecycle` config 預設（detached 證實前預設 foreground）。
- 可 detach 之**資格**由現有資訊推導（Model B headless-CLI executor 才可 detach；`host-native` 的 claude-as-host **不可** detach，因為它本身就是 main thread）——不需新欄位。
- 不引入 `lifecycle_mode`/`invoke_kind`/`guard_mode` 的 `schema_version: 2` 改名（會與 [[CC-384]] `hook-*`→`guard-*` 正面對撞）；manifest 詞彙整理集中到未來單一 schema bump，且須先值得。

**The new component — supervisor（監工）**:

```
pmctl dispatch start         # main：建 run 紀錄、落地 brief、setsid/nohup 起 supervisor、回 run-id、可離場
  └─ supervisor（detached）  # 持有 executor child；main 死也活（真 detach，非 run_in_background）
       ├─ 跑 executor
       ├─ post-verify        # 重用 CC-386/389
       ├─ 寫 durable run-state + result artifact   # = CC-225（復活並擴大到所有 executor）
       ├─ append events.jsonl（run FSM）           # = CC-211 substrate
       └─ best-effort 通知 listener                # = notify 軸（唯一真正新做的 channel）
pmctl runs / pmctl dispatch wait <id> / pmctl inbox  # reattach：新的 main 撈回結果
```

機制紅線：(1) **真 detach** 需 `setsid`/`nohup`——今天的 `run_in_background:true` child 仍在 session process group，session 死會 SIGHUP；(2) **notify** 以 **durable outbox/inbox 為 load-bearing**（死後存活、source of truth），live 通知（fifo/socket）僅 best-effort 疊加，永不 load-bearing。

**重用、不重開**:
- [[CC-225]]（claude-executor result observability）= durable-state 半，已 specced → 復活並**擴大到所有 executor**，作本軸的 durable 記錄。
- [[CC-238]]（pr-gate fan-out：無 timeout、attribution 弱、無測試）= **缺 supervisor 的症狀**；supervisor 的 timeout + per-child attribution 收掉它。
- [[CC-273]]（unified lifecycle *hook event* spec）= **不同軸**（tool-step hook 事件，非 process 生命週期）；保持分開、互連。
- [[CC-211]]/[[CC-216]] = supervisor 寫入的底層；不另開 store。

**Acceptance（spike 須輸出）**: 一個決策 **adopt / partial-adopt / defer**；若 adopt 另附——(1) detach 機制（setsid/nohup）與孤兒回收策略；(2) durable run-state 的 schema 與落點（對齊 [[CC-211]] FSM 與 [[CC-225]] `.gate-results/`-style）；(3) notify 的 outbox 契約與 `pmctl inbox`/`dispatch wait` 介面；(4) foreground→detached 遷移順序（任一時刻 guard fail-closed 不弱化）；(5) 一次真實 detached 派發證明結果與 foreground 等價。

**Sequencing**: 排 **v0.6.0 Phase 7**（executor 抽象的完成式），於真 adapter [[CC-376]]/[[CC-377]]（Phase 5）落地後——先在 N≥2 adapter 下證明 executor 抽象，再加 lifecycle 層，避免 supervisor 契約被 codex/claude 特例帶歪；屆時亦摸清 [[CC-381]]（host-PM-aware install）可一起設計通知。**理由**：`host-native` 把 executor 綁死在 host harness，detached-supervised 把它解開，正是 v0.6.0「runtime 解耦合」主題的完成式，且本票是 [[CC-385]] Model B 決策的直接續集，不宜分跨兩版。**逃生口**：若 v0.6.0 收尾時 Phase 7 未及，可單獨延 v0.6.x/v0.7.0（沿用 Phase 3 寫法），預設留 v0.6.0。**例外前拉**：若 [[CC-376]] 過程真的需要 durable result 記錄，只前拉 [[CC-225]] 的 durable-outbox 薄片，不前拉整個 supervisor。

**Non-goals**: 不在本票實作 supervisor；不改 Model B（CC-385..389）已上線行為；不解 [[CC-381]] host-PM install 軸（那是「誰當 host PM」軸，與本「executor 啟動後生命週期」軸亦正交）。

**Spike outcome（2026-06-15，codex 深入分析）**: 詳見 `docs/spikes/CC-391-detached-supervised-dispatch-scope.md`。判定 **partial-adopt** — 採納 lifecycle 為新派發軸、detached supervisor 為長期形狀，但「使用者可見 detached 派發」延後到兩個前提解決後：
1. **detach 資格不能單靠 runner_kind 推導**：`adapters/claude/adapter.yaml` 宣告 `runner_kind: host-native`，但 `adapters/claude/dispatch.sh` 實際跑 headless `claude --print`（CC-383/388 後的漂移）→ `runner_kind == cli-subprocess` 不是可信的資格謂詞。須先釐清 claude 分類（host-native vs cli-subprocess，或 claude-as-host / headless 兩 profile），或由「實際 adapter route/primitive」算資格＋測試。→ 已拆 [[CC-392]]（detach 落地前置）。
2. **footer/durable artifact 先行**：(a) 現行 `_footer_tmp` 為 `mktemp` parse 後即刪（`pmctl-dispatch.sh`）→ detached supervisor 崩潰會丟失 CC-305 防競態的 per-run footer handoff，須在 verify 前把 footer 持久化到 run 目錄；(b) state store 在 `~/.local/share/pm-dispatch/state`（user data），但 [[CC-225]] 要 repo-tracked `.gate-results/`-style → durable-outbox **不等於 events.jsonl**，須獨立 repo-local result/outbox artifact 為 load-bearing、再 mirror 到 state store。

遷移 fail-closed 順序（spike D7）：保持預設 foreground → 抽 executor tail（行為不變）→ foreground 模式先加 footer/result/outbox 持久化並驗 CC-305 仍成立 → supervisor foreground test 模式 → `--lifecycle detached` opt-in（ineligible adapter 啟動前拒絕）→ 才接 `setsid`/`nohup` + `dispatch wait`。紅線：不加 manifest `lifecycle_mode`；不讓 fifo/socket 成 load-bearing；supervisor 不得收未過 preflight 的 raw brief/adapter path。

**See**: [[CC-333]] umbrella、[[v0.6.0-planning]]、MILESTONES.md v0.6.0 Phase 7、`docs/spikes/CC-391-detached-supervised-dispatch-scope.md`。

---

## CC-392 — arch: claude adapter runner_kind 分類漂移 ✅ 2026-06-15

**Resolution**: `adapters/claude/adapter.yaml` set to `runner_kind: cli-subprocess` with overrides `write_guard_mode: cli-only` + `needs_bash_guard: false` — the three derived flags resolve behavior-identically (guard unchanged); `dispatch_route` now derives to `main_thread_bash_background` (label only, per [[CC-373]]). Stale `host-native`/`claude-as-host`/main-thread framing refreshed in `docs/executor-contract.md` (guard + profiles tables) and code comments. Regression added in `test-runner-kind.sh` (claude resolved flags + overrides) plus `test-executor-router.sh`/`test-hooks.sh` updates. pr-gate standard tier GO (advisories on stale profile rows cleared in-PR). Unblocks [[CC-391]] detach-eligibility. **See**: pr:#289.

**Problem**: `adapters/claude/adapter.yaml` 宣告 `runner_kind: host-native`（`adapters/claude/adapter.yaml:16`，註解述「claude-as-host self-executes its own edits gated by the host harness」），但自 [[CC-383]]（gate route 改走獨立 headless）+ [[CC-388]]（一般 implementation 對稱 codex）後，`adapters/claude/dispatch.sh` 實際是 `CMD=(claude -p --output-format stream-json …)`（`adapters/claude/dispatch.sh:5`、`:229`）的 **headless 獨立子程序**，由 `pmctl dispatch run --adapter claude` 驅動——行為上是 cli-subprocess / Model B。manifest 宣告與實際行為不一致，且 manifest 註解過時。發現於 [[CC-391]] 的 codex 深入分析（`docs/spikes/CC-391-*.md`，spike partial-adopt 前提 1）。

**Why now / 影響**: 今日尚未弄壞 dispatch——[[CC-373]] 的去風險結論是 `dispatch_route` 在 `pmctl-dispatch` 僅作 allowlist（zero/non-zero）+ log label、**不驅動 exec 分支**；而 `write_guard_mode` 對 `host-native` 與「`cli-subprocess` + cli-only override」恰好同值（cli-only），所以是「對的結論、錯的理由」。真正的問題是 `runner_kind` 因此成為**不可信謂詞**：任何由它衍生的判斷都不能盡信。具體卡點是 [[CC-391]] 的 **detach 資格推導**（「headless-CLI Model B executor 可 detach、host-native 不可」）——若照 manifest，claude 會被誤判為不可 detach，但它實際就是 headless subprocess。

**Decision needed**: claude 有兩執行模式——canonical headless `claude --print`（`pmctl dispatch run`，executor-contract 文件化主路）與 same-host `Agent(claude-executor)` 優化路。兩條路徑：
- (A) 把 canonical 定為 `runner_kind: cli-subprocess`，並 override `write_guard_mode: cli-only` + `needs_bash_guard: false` 以保持行為 byte-identical（比照 codex 用 per-flag override 偏離 runner-kind 預設的慣例，見 `scripts/lib/runner-kind.sh` override seam）。same-host Agent 路降為文件化 fallback。
- (B) 引入可表達「host-native fallback + cli-subprocess canonical」的機制（較重，可能踩 schema 改名，與 [[CC-384]] 衝突——不偏好）。
**傾向 (A)**：canonical route 就是 headless，manifest 應反映 canonical；[[CC-373]] 當時明確 defer 此 claude 角色歧義（因 dispatch 不靠它），[[CC-391]] 強制它收斂。

**Requirement**: manifest 的 `runner_kind`（＋必要 override）反映 canonical headless 路；`runner_kind_resolve_flag` 解析後三衍生旗標（`dispatch_route`/`write_guard_mode`/`needs_bash_guard`）對 claude 的**有效值與行為 byte-identical**（不得弱化 guard）；更新過時註解；加回歸測試鎖定（manifest 一致性 + 衍生旗標值）。**紅線**：這是 guard 安全邊界相關，security/risk hard gate；不得在 migration 中途弱化 claude 的 write guard。

**Dependencies / 關聯**: [[CC-391]]（detach 資格前置——本票須先收斂）、[[CC-373]]（曾 defer 此歧義）、[[CC-383]]/[[CC-388]]（造成漂移的兩 PR）、[[guard-role-runtime]]（role×runtime 兩軸）、[[CC-372]]（runner_kind manifest）。

**Priority**: P2 — `runner_kind` 可信度 + [[CC-391]] detach 落地前置；排 v0.6.0 Phase 7。

**See**: `docs/spikes/CC-391-detached-supervised-dispatch-scope.md`（Open questions：claude 最終分類）、umbrella [[CC-333]]。

---

## CC-371 — uninstall: prune empty `~/.claude/adapters/` dir

**Problem**: `uninstall.sh` (via `uninstall-hooks.sh`) prunes the managed parent dirs `agents/`, `commands/`, `skills/`, `scripts/`, and `share/` once empty, but the prune list omits `adapters/`. After the `adapters/claude` + `adapters/codex` symlinks are removed, an empty `~/.claude/adapters/` directory is left behind.
**Why**: Cosmetic only — the directory is empty, there are no dangling symlinks, and nothing functional remains. The `docs/RELEASE_CHECKLIST.md` §2a "no leftover dir" intent (which it states explicitly for `share/`) is not fully met.
**Requirement**: Add `adapters` to the empty-dir prune list in the uninstall path so a clean uninstall leaves no managed parent dirs; extend the uninstall regression coverage with a leftover-dir assertion (no managed parent dir survives a full uninstall).
**Source**: surfaced during v0.5.0 release §2a manual verification (2026-06-13); `~/.claude/adapters/` observed empty after `uninstall.sh`, hand-cleaned to restore the test environment.

## CC-370 — native Windows support deferred to post-core platform phase

**Problem**: During active feature development, supporting native Windows Git Bash concurrently with core work diverts effort from features — each MSYS failure class (symlink/Developer-Mode, flock/mkdir locks, `chmod 0700` no-op on NTFS, path dialects, CRLF, native `jq.exe` arg conversion) needs its own branch + skip-guard, and CI runs Linux only so every Windows-touching change carries manual verification + gate churn (#272 shipped Linux-green but Windows-broken; #273's first cut passed pr-gate yet broke on native jq.exe). The blocker is **focus**, not testability.
**Decision**: core-development phase officially targets **Linux + WSL2 only** (WSL2 treated as Linux); native Windows Git Bash is **not officially supported** — Windows users run under WSL2. Already-merged portability code (#272/#273, CC-104*) is kept (green, low-cost) but no new native-Windows branches are added until a dedicated **platform phase after the core stabilizes (v0.5.0+)**. Contract is explicit in `docs/platform-support.md`, `README.md`, `docs/RELEASE_CHECKLIST.md` (sign-off = Linux/WSL2 only); `doctor.sh`/`release-verify.sh` print a "use WSL2" notice on native Windows.
**Parks** (re-triage at the platform phase): CC-038 (locking primitive), CC-104d/e/f/g/j/k/r/s (Windows dogfood findings), CC-369 (state-store icacls ACL).
**See**: DECISIONS.md 2026-06-13 `defer-native-windows-support-during-core-dev`.

## CC-369 — Windows state store 真實 ACL via icacls（deferred）

**Problem**: CC-368 #2 在 NTFS 上以 SKIP-with-reason 處理 `state_store_init` 的 0700 斷言（`chmod` 是 no-op），但這只讓測試誠實，並未在 Windows 上達成等價的「僅擁有者可存取」保護。目前 state store 落在 `%USERPROFILE%` 下，僅依賴該目錄既有的 NTFS ACL。
**Why**: 真正等價 0700 需以 `icacls` 移除繼承並僅授權目前使用者，屬 Windows 專屬分支與測試成本。相對於 profile 目錄既有 ACL，邊際安全收益不高，且 Windows 尚非 Supported，故 deferred。
**Requirement**: 待 Windows = Supported flag flip 前評估：`state-writer.sh` 在 Windows 偵測下以 `icacls "<store_root>" /inheritance:r /grant:r "%USERNAME%:(OI)(CI)F"` 等價設定收斂保護，並補對應能力測試。
**Source**: 2026-06-13 CC-368 #2 收尾時分出的 follow-up。

## CC-003 — parallel-gate artifact-ignore 前置檢查

**Problem**: scripts/pr-gate.sh parallel mode 在 line 410/414 對 git status --porcelain 取 fingerprint，但 fingerprint 取樣後 gate 本身會寫入 .agent-trace/ / .gate-briefs/ / .gate-results/。若 target repo 沒跑過 setup-project.sh 或這三個路徑未在 .gitignore，gate 自己的寫入就會改動 status hash，觸發 line 575 的 fail-closed integrity check，在原本健康的 repo 卡住 PR review。
**Why**: parallel mode 整體假設「gate 執行期間 git status 不會被 gate 自己污染」。這假設只在 .gitignore 已含三個 artifact 路徑時成立，但 setup-project.sh 是否跑過、是否完整，gate 沒有 preflight 驗證。Cross-reviewer overlap (qa-tester + risk-reviewer 同點)，代表不是單一 reviewer 視角偏見。Loud + reversible (不會默默過 gate)，但屬於把工作流卡死的 ops 問題。
**Requirement**: parallel mode 啟動時必須能在 target repo 確認 gate artifact 路徑已被 ignore，或結構性排除這些路徑使其不影響 integrity check。可接受任一方向：preflight ignore-coverage 檢查（缺則明確指引跑 setup-project.sh）；或 integrity check 計算 status hash 時排除 known gate artifact paths；或文件 + test 明示 setup-project.sh 是 parallel mode precondition，並讓未滿足時的失敗訊息直接指向修復步驟。

## CC-004 — test-pr-gate.sh docstring 格式統一

**Problem**: scripts/test-pr-gate.sh 新增的 shell test functions 使用散文註解描述行為，而非 pm-schema 規範的 structured behavior/Steps docstring 形式。
**Why**: tests 本身 behavior-named、deterministic，功能無虞，純為 audit-quality / 一致性問題。長期會讓新人讀測試時樣式不一。
**Requirement**: 把新增 test functions 的開頭註解改寫成與既有 hook tests 一致的 behavior/Steps docstring 結構。不改測試邏輯。

## CC-011 — sync-memory.sh + 跨裝置共用（deferred；建議與 CC-012 合併實作）

**Problem**: `~/.claude/projects/*/memory/` 為本機路徑，多台電腦之間 memory 各自獨立，無法共用。
**Why**: 用戶目前不急，但設計上若以 symlink 指向 Dropbox/iCloud/OneDrive 資料夾，可以零維護代價實現跨裝置共用，且完全相容現有 file-based memory 架構。
**Requirement** (Phase 1): `scripts/sync-memory.sh --setup <cloud-path>` 把 memory 資料夾 symlink 到雲端同步路徑；`install.sh` 加入 opt-in 步驟。
**Phase 2**: CC-012 (SessionStart pull hook) — 兩者應同一 PR 實作，CC-012 無獨立實作價值。
**Status note (CC-050 audit 2026-05-18)**: Downgraded from ⏸ deferred to 🟢 someday — concept valid, no active plan. Re-evaluate if cross-device sync interest grows.

## CC-012 — SessionStart hook pull memory（deferred；建議與 CC-011 合併實作）

**Problem**: 若多台電腦透過 CC-011 共用同一雲端 memory 資料夾，session 啟動時不保證已取得最新版本。
**Why**: 輕量方式是 SessionStart hook 觸發一次 rsync/git pull，確保 memory 是最新版。
**Requirement**: `scripts/hook-sync-memory.sh` SessionStart hook；支援 git pull 和 rsync 兩種模式；失敗時靜默降級。
**Note**: 依賴 CC-011；建議與 CC-011 合入同一 PR（Phase 1 + Phase 2 同步落地，CC-012 無獨立實作意義）。
**Status note (CC-050 audit 2026-05-18)**: Downgraded from ⏸ deferred to 🟢 someday — depends on CC-011; no active plan. Re-evaluate together with CC-011.

## CC-014 — `using-git-worktrees` skill

**Status note (CC-050 audit 2026-05-18)**: Downgraded from 🔵 active — no open branch. Re-activate when work begins.
**Problem**: `--parallel` PR gate 各 reviewer 在同一 working tree 執行，reviewer 寫入可能互相干擾。
**Why**: git worktree 讓每個 subagent 在獨立環境工作，避免狀態污染，也直接補強 CC-003 的解法方向。
**Requirement**: `commands/using-git-worktrees.md` skill，指導平行開發中使用 git worktree；評估 `--parallel` gate 是否可為每個 reviewer 建立獨立 worktree。

## CC-015 — `systematic-debugging` skill

**Status note (CC-050 audit 2026-05-18)**: Downgraded from 🔵 active — no open branch. Re-activate when work begins.
**Problem**: debug 工作流目前無標準化流程，每次偵錯方式不一致，容易遺漏根本原因分析。
**Why**: 結構化偵錯步驟（reproduce → isolate → hypothesize → verify → fix → regression test）有助於複雜 bug 分析。
**Requirement**: `commands/systematic-debugging.md` slash command，提供結構化偵錯步驟。

## CC-018 — Codex quota 自動追蹤 + rate-limit 路徑統一（吸收 CC-269）

**Problem**: (A) CC-006 解決了 Claude 5h rate-limit 自動讀取，但 Codex 無等效 hook 機制；目前 Codex 使用量只靠 `log-usage.sh` 手動寫入，用戶無法即時得知剩餘額度。(B) CC-269（已合併）：`scripts/hook-save-rate-limits.sh` 寫到 `~/.claude/rate-limits.json`，與 claude-account-switcher 等工具衝突；pm-dispatch 不應寫入 `~/.claude/` 共用路徑。
**Why**: Codex 走 OpenAI API 路徑，quota 資訊需要主動查詢（response header 或 `/v1/organization/usage`），架構不同於 Claude StatusLine hook。rate-limit 寫入應集中到 pm-dispatch 自己的 state 目錄以避免多工具衝突。
**Requirement**:
1. 研究 Codex API response headers（`x-ratelimit-remaining-requests` / `x-ratelimit-remaining-tokens`）
2. 若有：`scripts/codex-dispatch.sh` dispatch 後解析 headers，寫入 `~/.local/share/pm-dispatch/state/rate-limits.json`（對齊 CC-230 state store）
3. 若無：呼叫 `/v1/organization/usage` 或記錄技術限制
4. `scripts/hook-save-rate-limits.sh` 改寫到同一 `~/.local/share/pm-dispatch/state/rate-limits.json`（Claude pool + Codex pool 合一），停止寫 `~/.claude/rate-limits.json`
5. 更新所有讀取 rate-limit 的腳本（doctor.sh、usage 相關、statusline consumers）
6. `token-usage.sh` 加入 Codex pool 剩餘顯示
**Note**: 實作前需先手動驗證 Codex API header 行為。CC-063 dashboard 之後可吃此 state，但不在本票範圍。

## CC-026 — `/skill-distill` 從重複工作流產出 skill

**Problem**: 重複的多步驟工作流（例：手動跑 `git checkout main && git pull && ./install.sh --dry-run && ./install.sh`、或某個 codex brief → 審查 → 修正的固定 5-step）目前需要 user 自己注意到「這個我做第三次了」才會手寫成 skill。沒有系統性偵測。
**Why**: 跟 CC-025 同一個 episode 層基礎建設；差別是 CC-025 改進「已有 skill」，CC-026 提議「新 skill」。優先序我建議在 CC-025 之後 — 等 episode 中 skill execution 標記成熟、`/skill-refine` 的 diff 提議流程驗證可信，再啟動偵測 + 產出。否則容易產生雜訊建議讓 user 必須一直拒絕。
**Requirement**:
1. `commands/skill-distill.md` slash command，介面：`/skill-distill [--dry-run] [--min-occurrences N]`。
2. 讀 `episodes.jsonl`，對工具序列做相似度聚類（例：tool name 的 n-gram、Bash command pattern）。
3. 若同樣序列在不同 session 出現 ≥ N 次（預設 3）且總長度 ≥ 5 步，產出草稿 `commands/<draft-name>.md` 並回報出處 episodes。
4. 預設 `--dry-run` 只印名稱與草稿 outline，user 確認後再寫檔。
**Note**: 依賴 **CC-027** 與 **CC-025**。順序：CC-027 訊號層落地 → CC-025 驗證單一 skill 改進迴路 → CC-026 才有足夠資料做序列聚類。
**Source**: 2026-05-15 對話討論 Hermes Agent self-improvement loop 與 pm-dispatch 的 gap 分析。

## CC-032 — `[[feedback_*]]` cross-link 公開化（dead-link 防護）

**Problem**: BACKLOG.md（含本次 CC-025..CC-030 新條目）多處引用 `[[feedback_undocumented_harness_payload]]`、`[[feedback_known_bug_backlog]]`、`[[feedback_codex_routing]]`、`[[routing_log]]` 等 — 這些 memory 檔**不在 repo 內**（在 `~/.claude/projects/<proj>/memory/`，純本地）。轉公開後，外部讀者點不開、不知道內容、cross-link 形同 dead link。
**Why**: 公開要兼容「沒有 user memory 的讀者」。兩條路：(a) 把這些 feedback rules 中真正屬於 repo 政策的部分抽到 `docs/policies/*.md` 並改 link 指向新位置；(b) 在每次第一次引用時 inline 引述兩三行。前者乾淨且可被 search engine 索引、後者侵入度低但容易過時。建議 (a)，配合 schema 規則：所有 BACKLOG 條目的 `[[name]]` 必須對應 `docs/policies/<name>.md` 存在。
**Requirement**:
1. 盤點所有 BACKLOG.md / docs/ 中 `[[feedback_*]]` 與 `[[*_log]]` 出現位置。
2. 把屬於「repo 適用政策」（非個人偏好）的 rule 抽寫至 `docs/policies/<slug>.md`，每篇含：摘要、原因、實作守則、reference。
3. 更新所有 `[[name]]` 改為 `[docs/policies/<slug>.md](docs/policies/<slug>.md)` 或 `[[<slug>]]`（若決定保留 wikilink 風格、配合 CC-030 validator 擴充驗證 link target 存在）。
4. 個人偏好類 feedback memory（不適合公開）留 local memory 不對外。
**Note**: 與 CC-030 schema validator 設計協同 — 可同 PR 加上「`[[name]]` link target 必須存在」的 validation。Blocks **CC-033**。
**Source**: 2026-05-15 對話 — 公開前置盤點 #3（Explore 未抓到的盲點）。

## CC-033 — Public flip checklist 與後續觀察

**Problem**: 完成 CC-031/CC-032 後，public flip 本身仍涉及多個 GitHub repo 設定決策（Issues 開關、Discussions 開關、template、labels、release tagging policy），需要明確 checklist 避免「按下 public 後才發現某設定不對」。
**Why**: 公開是 one-way door — 翻成 public 之後 commit history 全部對外（雖然 git history 已審 clean）；issue 也會公開。所以 flip 本身需要清單化，並決定先試水溫的 setting（Discussions only vs 全開）。
**Requirement**:
1. 決策清單：(a) Issues 開關（建議先關，僅 Discussions），(b) Discussions categories 規劃，(c) PR template，(d) release tagging（已有 1.1.0，是否設 GitHub Releases），(e) 是否加 CITATION.cff。
2. 觀察期：flip 後 2-4 週評估 — 若有有效 use case 出現再開 Issues。
3. Flip 動作本身為 1 行：`gh repo edit --visibility public`。
**Note**: 依賴 **CC-031**, **CC-032** 完成；本條為「最後一哩」與後續評估。
**Source**: 2026-05-15 對話 — 公開前置盤點 #4。

## CC-035 — install/uninstall-hooks basename+scripts/ collision edge case

**Problem**: install/uninstall hooks 目前以 basename + `scripts/` heuristic 判斷既有 hook 是否屬於 pm-dispatch，但另一個工具若也在 `scripts/` 下使用同名 hook，仍可能 collision。
**Why**: CC-034 修掉 full-path 比對造成的 append-not-replace bug，但 basename heuristic 仍不是完整 ownership model。
**Requirement**: 設計更明確的 hook ownership marker 或 install manifest，讓 uninstall/replace 只影響 pm-dispatch 自己寫入的 hook entry。
**Source**: CC-034 follow-up from PR #53.

## CC-038 — Windows / cross-platform locking primitive（deferred）

**Problem**: CC-037 用 `flock -x -w 2` 序列化 `hook-routing-log.sh` 的 append/rotation 路徑。`flock` 是 Linux util-linux 工具，Windows（純 PowerShell / Git Bash 無 util-linux）與 macOS（預設不裝 util-linux，需 `brew install flock`）都不能直接使用。除了 hook-routing-log，整個 `scripts/` 樹大量依賴 Linux-isms（GNU awk、GNU sed、`printf -v`、`procfs`、`/dev/null` 重導向細節等），整體 portability 是一塊待面對的工作面，不只這一支腳本。
**Why**: 使用者後續可能需要在 Windows 系統開發 / 跑 pm-dispatch（WSL 不算 native Windows）。在那之前，所有 Linux-only 依賴都是 latent block。CC-037 引入 `flock` 沒有惡化現況（其他 hook 已依賴大量 Linux-only 工具），但每多一個依賴點，將來 portability work 範圍就多一塊。現在不修不影響任何 Linux user，所以這是 latent / blocked-on-windows-demand 條目，不是 active bug。
**Requirement**: 任一方向皆可：(1) 抽象層 `scripts/lib/lock.sh`，依平台選 `flock` (Linux) / `shlock` (macOS 內建) / PowerShell `Mutex` 或 atomic file create loop (Windows)，hook 透過 wrapper 取得鎖；(2) Portable 替代：用 `mkdir`-based atomic locking 取代 flock，所有平台 portable，但需顯式 stale-lock cleanup；(3) 限制範圍：明確聲明 pm-dispatch 僅支援 POSIX（Linux + macOS via Homebrew util-linux），Windows 走 WSL2，寫進 `README.md` + `docs/platform-support.md`。
**Cross-link**: triggered by CC-037 implementation choice (flock). 不阻塞當前 release。所有 hook scripts (`hook-routing-log.sh`, `hook-tool-trace.sh`, `hook-codex-bash-guard.sh`, `hook-pm-write-guard.sh` 等) 共用同一個 portability 平面，啟動時應一次性盤點所有 Linux-isms。
**Source**: 2026-05-15 user 在 CC-037 收尾階段點出「之後可能需要支援 Windows」。

## CC-044 — `tool-trace.jsonl` reliability, retention, data-quality bundle（deferred；吸收 CC-027b + CC-027c）

**Current baseline (shipped in CC-027)**: 4 MiB single-archive rotation — when `tool-trace.jsonl` exceeds 4 MiB, it is renamed to `tool-trace.jsonl.1` (overwriting any prior `.1`) and a fresh main file is started. Retention semantics: "current file plus one overwritten archive". Constant-time stat check, non-blocking on rotation failure.
**Problem**: Three related reliability gaps in `tool-trace.jsonl` all feed the same downstream risk — skill-distill / skill-refine signals become unreliable if trace data is lossy or untrustworthy:
- (Phase 1) Single-archive baseline overwrites prior trace history on rotation; multi-window retention needed for longer post-hoc analysis.
- (Phase 2, absorbed from CC-027b) Append/parse/rotation failures are best-effort and audit-only; sustained failure degrades downstream CC-025/CC-026 signals with no visible warning.
- (Phase 3, absorbed from CC-027c) Brace-shaped malformed JSON (truncated mid-object) can pass the bash brace heuristic; inline `jq -e .` validation costs ~25ms/call, exceeding the per-call budget.
**Why**: The hook must stay non-blocking, but silent long-term degradation makes skill-refine/skill-distill signals unreliable. Addressing all three together avoids a partial-fix where Phase 1 lands but the health/validation layer lags.
**Implementation sequence** (can split into 3 PRs within the same epic):
1. **Phase 1 — multi-window retention**: upgrade from "current + one overwritten archive" to N rotated archives (gzip or daily archive dir). Include boundary/archive-integrity/non-blocking-failure tests.
2. **Phase 2 — health signal**: add bounded error counter for `tool-trace.jsonl` health; downstream commands (CC-025/CC-026) surface a warning when error count exceeds N. Keep hook non-blocking; cap health-state file growth.
3. **Phase 3 — async validation**: async post-validation path (append first, validate sampled fraction asynchronously, or move strict validation to downstream CC-025/026 consumer where 25ms/call amortizes over rare reads). Garbage line is data-quality concern only — no security vector.
**Activate when**: CC-025/CC-026 consumers are close to implementation and reliable trace data becomes load-bearing.
**Source**: 2026-05-15 CC-027 brief + PR-gate critic/arch/risk (rotation), risk-reviewer (health, CC-027b), critic+qa-tester (validation, CC-027c).

## CC-023 — `coupling-reviewer` PR gate 耦合分析（deferred）

**Problem**: PR gate 的 architecture-reviewer 依賴 Claude 主觀判斷耦合問題，沒有客觀量化基線。
**Why**: 量化耦合指標（afferent/efferent coupling、循環複雜度）可提供客觀基線；coca/dependency-cruiser/gocyclo 等工具已成熟。
**Requirement**: `scripts/coupling-check.sh` 語言偵測 + 工具呼叫，只分析 changed files；PR gate 加入可選 `--coupling` flag；閾值超過 → block-soft。
**Note**: 依賴 CC-022 建立設計評審文化後再推進。

## CC-045 — brief timeout heuristic + playbook-depth short-circuit（deferred）

**Problem**: Brief author 目前對 `timeout` 沒有明確啟發法 — 多半以 edit size 為單一估算依據。但 Codex 預設行為是先吃完整個 target repo 的 onboarding chain（AGENTS.md / rules/global / rules/domain / 跨 repo playbook docs）再動工。對 playbook 深的 repo 即使只改 ~10 行也會在 prelude 階段燒掉 200s+，超薄 timeout 直接 SIGKILL 在 research 階段。
**Why**: 2026-05-16 cross-session diagnostic — a deep-playbook target repo (rules/global + rules/domain + cross-repo playbook refs) ran a yml/md parity edit (~10 yml + 4 md lines mechanical sync) via codex-dispatch.sh `--timeout 240`, exit 124; trace showed 11 `command_execution` events all in doc-read phase (prompt-budget, cross-repo playbook docs, DECISIONS.md, project manifest, rules/global, rules/domain), zero edit-phase progress. **根因**：brief author 把「edit 14 行 ≈ 240s」推估時未把 playbook depth 算進去。
**Requirement**:
1. `docs/dispatch-brief.md` brief schema 文件加 `timeout` 啟發法 guidance：
   - flat repo（無 `rules/`、無 `AGENTS.md`、無 cross-repo playbook 連結）：mechanical edit 240–600s OK
   - shallow playbook（單一 `AGENTS.md` 或 `<10` 條 rules）：mechanical edit 600–900s
   - deep playbook（`rules/global` + `rules/domain` 或跨 repo playbook refs）：mechanical edit **最低 900s**；judgment-heavy（editorial / schema）1500s+
2. brief context 加可選短路 clause 模板：`"Constraints captured in this brief; do NOT re-read AGENTS.md / rules/ / playbook docs"` — 對 self-contained brief + mechanical edit 直接砍 5–10 個 read 命令。需在 `docs/dispatch-brief.md` 給範例。
3. （可選 / 第二階段）`scripts/codex-dispatch.sh` 啟動時偵測 `<working_dir>/rules/` 或 `<working_dir>/AGENTS.md` 存在且 `--timeout < 900` 時 emit stderr WARNING（不阻擋），surface author 設置錯誤於 SIGKILL 之前。
4. 觀察 N≥2 次 cross-session 重現後，promote 為 `feedback_brief_timeout_playbook_depth` memory（[[known-bug backlog rule]] + [[Codex routing preferences]] 衍生）。
**Source**: 2026-05-16 cross-session diagnostic — deep-playbook target repo dispatch exit 124 with 240s timeout, trace `.agent-trace/codex-20260516-193626-47431.jsonl`。
**Note**: 立即 workaround 是 brief author 對 deep playbook repo 預設 timeout=1500s；本條 ticket 是把這條 workaround 升級為文件化規則 + 可選 wrapper-side warning。
**Cross-link**: [[Codex routing preferences]] 路由表 / [[known-bug backlog rule]] 補登原則。

## CC-054 — CC-025 M2 `/skill-refine` diff generation（deferred）

**Problem**: CC-025 delivered the M1 read-only signal bundle and CC-025b closed the usage-guard plus `CLAUDE_MEMORY_DIR` contract follow-ups, but the original M2 scope for `/skill-refine` diff generation remains unimplemented.
**Why**: The useful product loop is not complete until the tool can turn skill feedback signals into a reviewable refinement diff. Closing CC-025b without a separate M2 tracker would make that deferred scope easy to lose.
**Requirement**:
1. Extend `/skill-refine` so it can generate a proposed diff for the target skill or command from curated memory/feedback signals.
2. Keep the default behavior review-first: emit the diff for user or main-thread approval rather than directly rewriting skill files.
3. Include Claude-assisted refinement guidance in `commands/skill-refine.md`, with clear dry-run and apply boundaries.
4. Add contract tests for diff-generation behavior and no-direct-write safety.
**Source**: PR #67 CC-025 M1 implementation and 2026-05-18 CC-025b closure decision in `feat/cc039-cc025b-v2`.

## CC-063 — [P2] Trace / token / gate metrics dashboard

**Problem**: `.agent-trace/*.jsonl`、`rate-limits*.json`、`.gate-results/*.md` 已積累豐富資料（per-session token、gate pass/fail、routing_log 校準記錄），但沒有視覺化介面；只能手動 grep。
**Why**: token 趨勢、gate 通過率、routing 準確度對長期 workflow 最佳化很有價值；資料已在，缺的是 consumer。
**Requirement**: `scripts/dashboard.sh`（或 HTML report）：讀取 `.agent-trace/*.jsonl` 統計 per-session input/output token；讀 `.gate-results/*.md` 統計 GO/NO-GO rate；讀 `routing_log/*.csv` 計算 Q1/Q2/Q3 準確度。輸出 terminal-friendly 摘要表。

## CC-064 — [P2] Project bootstrap wizard

**Problem**: 新 repo 接入 pm-dispatch 需要手讀 GETTING_STARTED.md、手跑多個指令（`setup-project.sh`、memory init、rules 建立、PM schema 建立）；沒有一鍵引導流程。
**Why**: 降低接入門檻是 OSS 擴散的關鍵；現有 install.sh 處理 Claude 工具安裝，但不處理「把 pm-dispatch 接入現有 project」的 onboarding。
**Requirement**: `scripts/setup-project.sh --init <project-path>` 互動式引導：建立 `.claude/memory/`、`rules/` 骨架、`pm/BACKLOG.md` 模板、`.gitignore` 追加 artifact paths；結束時輸出「下一步」checklist。

## CC-065 — [P2] Per-repo configurable gate pipeline

**Problem**: 所有 repo 共用同一組 reviewer（architecture-reviewer、critic、qa-tester、risk-reviewer、security-reviewer）和 tier 預設。某些 repo（如純文件、seed data）不需要 security-reviewer；某些高風險 repo 應強制 full tier。
**Why**: 目前唯一的調整方式是每次手動傳 `--targeted` 或 `--tier`，無法設為 repo 級預設值。
**Requirement**: `.pm-dispatch/gate.toml`（per-repo）支援設定 `default_tier`、`required_reviewers`、`skip_reviewers`；`scripts/pr-gate.sh` 讀取此 config 做為預設值（CLI flags 仍可 override）。

## CC-205 — `/pm` dual-executor planning + `--parallel-plan` mode（deferred）

**Problem**: `/pm` 目前固定走單一 executor（codex 或 claude），沒有辦法對高影響任務
取得兩個 planner 的獨立視角；routing 決策也是隱性的（PM agent 內部決定），無法從
command 介面顯式控制。

**Why**: 架構/跨模組/首次設計類任務，單一 planner 有盲點風險；兩個 planner 各自獨立
規劃再合成，等同 pr-gate parallel reviewer 模式在計劃階段的對應。顯式 `--executor`
flag 讓 routing 可見、可測試，與 pr-gate 介面對齊降低學習成本。

**Requirement**:
1. `/pm` 加 `--executor auto|codex|claude` flag（default: auto，行為與現行相同）
2. `dispatch_handover_v1` schema 加 `executor` 欄位，PM skill 與 pr-gate skill 共用
   同一 handover 解析路徑
3. PM agent instructions 加偵測規則：task 符合下列任一條件時，在 dispatch 前暫停並
   詢問用戶是否啟用 `--parallel-plan`：area 包含 arch/process/gate；task 涉及多個
   subsystem 的 interface 設計；task 是「首次設計 X」而非「改現有 X」
4. `--parallel-plan` mode：codex 與 claude 各自獨立 dispatch 同一規劃任務；兩份計劃
   完成後，current model（synthesis pass）整合為一份 best-of 計劃輸出給用戶
5. `/pm --parallel-plan <task>` 顯式 flag 跳過確認步驟，直接 parallel dispatch
6. 一般查詢維持背景執行（run_in_background）；有 checkpoint 需求時切前景

**Dependencies**: CC-200（executor-router.sh 共用 routing lib）、CC-059（thin pm.md
script-layer）、CC-202（handover validator framework）

**Acceptance criteria**:
- [ ] `/pm --executor claude <task>` 強制走 claude-only 路徑
- [ ] `/pm --executor codex <task>` 強制走 codex 路徑
- [ ] PM 偵測到 arch task → 輸出 checkpoint 訊息並等待用戶確認
- [ ] 用戶確認後 → codex + claude 各自規劃 → synthesis 輸出一份計劃
- [ ] `/pm --parallel-plan <task>` 顯式 flag → 直接 parallel dispatch，無 checkpoint
- [ ] `dispatch_handover_v1` block 含 `executor` 欄位，pr-gate skill 可解析同一格式
- [ ] 一般 `/pm <task>`（無 arch 特徵）維持背景執行，行為不變

## CC-209 — codegraph integration: pre-indexed context for Codex briefs（deferred）

**Reframed 2026-05-22**: this is now a **context-enrichment spike** — evaluate codegraph as the first source behind the `context-pack` abstraction (CC-232), not a direct `codex-dispatch.sh` flag. Runs as the first formal `/spike` in v0.3.0 M5. Requirement bullet 3 below (`--codegraph-enrich` flag on `codex-dispatch.sh`) is superseded by `pmctl context build --source codegraph`. See [`docs/architecture/v0.3.0-synthesis.md`](../docs/architecture/v0.3.0-synthesis.md) §9.

**Problem**: Codex briefs rely on manually-specified `files:` lists for context.
If the list is incomplete, Codex spends tokens exploring the codebase via grep/read.

**Why**: colbymchenry/codegraph (MIT, TypeScript, 9,475 stars, active May 2026) builds
a pre-indexed code knowledge graph for Claude Code / Codex / Cursor. Querying it before
dispatch could auto-supply relevant file context and reduce per-brief token cost —
aligned with pm-dispatch's core token-efficiency goal.

**Requirement** (investigation scope):
1. Understand codegraph install model (Claude Code plugin vs. standalone CLI).
2. Identify query API: what does a graph query return, and can it be embedded in a brief preamble?
3. Prototype: add optional `--codegraph-enrich` flag to `codex-dispatch.sh` that runs a
   codegraph query and injects top-N relevant file paths into the brief `files:` block.
4. Measure token delta on 3 representative briefs with/without enrichment.

**Priority**: P3 — non-urgent. Evaluate after v0.2.0 milestone closes.

## CC-210 — uninstall.sh: reject managed-root exact path as deletion target（deferred）

**Problem**: `uninstall.sh` checks `[[ "$dst" == "$managed_root"* ]]` (startswith), which
allows `$managed_root` itself to pass. A malformed copy-mode manifest entry with a
destination equal to `$HOME/.claude` could cause the uninstaller to delete the entire
Claude config directory.

**Why**: Raised as [medium] advisory by risk-reviewer in PR #110 gate. Normal installer
manifests never create such entries, but defense-in-depth suggests rejecting the exact
root to align worst-case blast radius with "remove installed artifacts," not "remove all
Claude config."

**Requirement**: In `uninstall.sh`, before the `rm` / `unlink` call, add:
```bash
[[ "$dst" == "$managed_root" ]] && { warn "skipping managed root itself: $dst"; continue; }
```
Add a test case in `scripts/test-uninstall.sh`: manifest entry with dst == managed root
is skipped and a warning is emitted.

**Priority**: P3 — low urgency (normal manifests are safe). Fix before any public release.

## CC-211 — multi-CLI platform architecture（deferred）

**v0.3.0 epic** (updated 2026-05-22): umbrella epic for the v0.3.0 PM-runtime restructure. The original P0–P5 ordering below is **superseded** — see [`docs/architecture/v0.3.0-synthesis.md`](../docs/architecture/v0.3.0-synthesis.md) for the design breakdown (its **Conformance status** section tracks as-built drift; live numbering is **M0–M6** in `MILESTONES.md`, vs the §6 M0–M5 design cut) and `MILESTONES.md` v0.3.0 for ticket assignment. MCP (CC-216) and `adapters/antigravity`/`opencode` are deferred to v0.4.0; `adapters/codex` shipped in v0.3.0 (with claude).

**Problem**: pm-dispatch is currently framed as "Claude Code personal config + Codex dispatch
wrapper". As Codex CLI, Antigravity CLI, OpenCode, and other AI tools mature, this framing creates
coupling creep: hooks, adapters, and business logic intermingle because there is no enforced
boundary between the CLI-agnostic PM engine and each tool's delivery path.

**Why**: Re-framing pm-dispatch as an "agent-native PM orchestration toolkit" with explicit layer
boundaries allows any AI CLI to use the same PM system without forking logic. Guard engine,
dispatch state machine, reviewer policy, and schema definitions should be owned once.

**Requirement** (4-layer architecture, design scope):

| Layer | Path | Owns |
|---|---|---|
| `core/` | `core/schemas/`, `core/lib/` | PM schema, task/decision/review models, reviewer policy, dispatch state machine — zero CLI awareness |
| `runtime/` | `cli/pmctl` | `pmctl` CLI, dispatch runner, trace logger, guard engine, validator, report generator |
| `adapters/` | `adapters/claude/`, `adapters/codex/`, `adapters/antigravity/`, `adapters/opencode/` | Format conversion only; each adapter translates CLI-specific calls into `pmctl` invocations |
| `mcp/` | `mcp/pm-dispatch-server` | MCP tool bridge; any MCP-capable CLI (Claude Code, OpenCode, Antigravity CLI) shares one server |

**Key design rules**:
- `core/` never changes per CLI; no `~/.claude/` assumptions.
- Guard engine lives in `pmctl`; Claude hooks are one delivery path, not the definition.
- Adapters own zero business logic.
- `pmctl adapter generate <claude|codex|antigravity|opencode>` produces per-CLI config from core agent definitions to prevent 4-way drift.

**Priority order**: P0 extract `core/schemas/` (lock data format across CLIs) → P1 pmctl CLI (CC-215) → P2 Claude commands call pmctl → P3 Codex adapter formalised → P4 MCP server (CC-216) → P5 Antigravity/OpenCode adapters.

**Complements**: CC-059 (thin `/pm.md` script-layer), CC-215 (pmctl), CC-216 (MCP server).

**Priority**: P4 — long-term direction. Evaluate at v0.3.0 milestone planning.

## CC-212 — Windows junction install hardening: path-passing + idempotency（deferred；吸收 CC-213）

**Problem**: Two related hardening gaps in the Windows junction install surface — recommend same PR:
- **(A, original CC-212)** `make_junction_windows()` passes paths as inline PowerShell command-string arguments (`-Path '$win_src' -Target '$win_dst'`), but `remove_junction_windows()` already uses `PM_DISPATCH_RM_DST` env var. Paths containing single quotes break the inline form; the two-convention split increases maintenance risk.
- **(B, absorbed from CC-213)** `install_dir_junction()` idempotency logic uses `[[ -L "$dest_dir" ]]` + `readlink`, but PowerShell-created Windows directory junctions may not appear as `-L` in Git Bash. A second `bash install.sh` can therefore treat the junction as a real directory, fall back to per-file copy, and flush a manifest without the `junction` mode entry.

**Why**: Both issues were raised in gate-20260521-115634 as [medium] advise on PR #112. They share the same file surface (`scripts/install.sh` junction helpers) and the same root cause (Windows/Bash interop assumptions). One PR cleans up both cleanly.

**Requirement**:
- **(A)** Replace inline PowerShell path arguments in `make_junction_windows()` with `PM_DISPATCH_MAKE_SRC` and `PM_DISPATCH_MAKE_DST` env vars (matching `remove_junction_windows()` pattern). Update `test_install_dir_junction_manifest_entry` fake powershell.exe to assert both env vars.
- **(B)** Add a manifest-driven idempotency probe: before the `-L` check, read the existing manifest for the entry's `mode` field; if `mode == "junction"` treat the destination as an existing junction regardless of Bash `-L`. Add a focused test for the "manifest says junction, `-L` is false" branch.

**Complements**: CC-207 (parent), CC-214 (docs uninstall anchoring — optionally fold in).

**Priority**: P3.

## CC-214 — platform-support.md manual uninstall command anchoring（deferred）

**Problem**: The manual uninstall warning in `docs/platform-support.md` uses `bash uninstall.sh`
without anchoring to the repo path; running it from any other working directory silently fails.

**Why**: Raised by critic in gate-20260521-115634 as [low] advise. Other examples in the same
document already use the `"${PM_DISPATCH_REPO}/uninstall.sh"` form.

**Requirement**: Replace the bare `bash uninstall.sh` in the Windows uninstall warning block with
`bash "${PM_DISPATCH_REPO}/uninstall.sh"` (one-line change).

**Priority**: P3 — tiny fix, fold into next docs PR.

## CC-216 — MCP server — pm-dispatch-server（deferred）

**v0.4.0** (updated 2026-05-22): deferred to v0.4.0 per the v0.3.0 synthesis — MCP must wrap a stable `pmctl`, never an immature one. v0.3.0 was to ship only `mcp/README.md` defining the tool surface as a `pmctl` interface design constraint (AS-BUILT 2026-05-31: not written — `mcp/` absent; see synthesis Conformance status §B). See [`docs/architecture/v0.3.0-synthesis.md`](../docs/architecture/v0.3.0-synthesis.md) §5.4.

**Problem**: Each AI CLI (Claude Code, OpenCode, Antigravity CLI) needs separate command/hook wiring
to reach pm-dispatch. There is no universal bridge that works for any MCP-capable tool without
per-CLI adaptation.

**Why**: An MCP server exposes pm-dispatch operations as standard MCP tools, meaning any
MCP-capable CLI gets full PM access with no additional wiring. Adapters shrink to auth/config/
format differences only.

**Requirement**:
- Implement `mcp/pm-dispatch-server` exposing MCP tools:
  - `pm_list_tasks`, `pm_read_task`, `pm_create_task`, `pm_update_status`
  - `pm_add_decision`, `pm_request_review`, `pm_dispatch_to_agent`
  - `pm_read_trace`, `pm_guard_check`
- Implementation path: thin Node.js or Python wrapper over `pmctl` subprocesses (avoids
  duplicating logic), or native bash MCP server once spec stabilises.
- MCP becomes the universal bridge; adapters handle only auth / config / format differences.

**Depends on**: CC-211 (core layer), CC-215 (pmctl stable before wrapping).

**Complements**: CC-211 (architecture), CC-215 (pmctl as backend).

**Priority**: P4 within CC-211 roadmap. Evaluate at v0.3.0.

## CC-220 — spike agent + `/spike` skill（deferred）

**Corrected 2026-05-22**: the original "spike agent dispatches parallel sub-agents" is structurally impossible — **subagents cannot spawn subagents**. The spike agent is a *planner* (like `project-pm`); the **main thread** fans out one Agent per angle, modeled on `/pr-gate`'s reviewer fan-out. v0.3.0 M5.

**Problem**: Spike investigations are currently ad-hoc: the PM dispatches a mix of Explore
calls, the findings are summarized in conversation context, and nothing is committed to
the repo. Repeating a spike wastes tokens; the result is not reviewable.

**Why**: A dedicated spike agent with a structured workflow produces a committed, reviewable
result file. The parallel multi-angle dispatch matches how PM agent dispatches reviewers —
reusing the same agent/fan-out primitives for a different cognitive mode.

**Requirement**:
- `agents/spike.md` — spike agent definition:
  - Reads BACKLOG spike ticket for `Investigation scope` and `Done-when`
  - Plans 2–3 investigation angles (e.g., existing-coupling audit / interface draft / prior art)
  - Returns a `spike_plan` block (2–3 angles); the **main thread** fans out one `Agent` per angle — subagents cannot spawn subagents (same constraint as `project-pm`)
  - Synthesises findings into `docs/spikes/CC-NNN.md`
  - Updates BACKLOG body `Result log` field with the file pointer
- `commands/spike.md` — `/spike CC-NNN` skill invoking the agent
- Executor design: each executor type has its own model pool (codex: codex-default + lightweight variants; claude: haiku/sonnet/opus); dispatch layer picks executor+model from pool — no cross-pool model assignment
- Sandbox is orthogonal to executor type; future: both executor types should support sandbox on/off flag (tracked separately)
- Architecture spikes: dispatch 2–3 sub-agents with different angles for multi-perspective coverage

**Depends on**: CC-218 (spike type + docs/spikes/ directory must exist first).

**Complements**: CC-218 (infrastructure), CC-209 (first spike to run through the new agent).

**Priority**: P3. Implement after CC-218.

## CC-224 — shared hook-profile inventory: doctor.sh ↔ install-hooks.sh（deferred）

**Problem**: `scripts/doctor.sh` owns a second hardcoded minimal/full hook membership model (around line 240) that mirrors the one in `scripts/install-hooks.sh`. When a new hook is added or a profile boundary changes, it is easy to update one file and miss the other — this is a silent drift path with no compile-time check.

**Why**: Raised by critic and architecture-reviewer as [medium] advise in PR-gate `gate-20260522-100348`. The duplication became structurally significant once `--profile minimal|full|auto` was added and both files enumerate hooks by profile.

**Requirement**: Extract the managed hook list and profile classification into a shared shell helper (e.g. `scripts/hook-profile.sh`) sourced by both `doctor.sh` and `install-hooks.sh`. Alternatively, add a parity test (e.g. `test-hook-profile-parity.sh`) that parses both files and asserts the hook sets are identical for each profile tier.

**Dependencies**: CC-058（profile flag already landed）

**Priority**: P3 — maintainability; current duplication is limited to two well-known files.

**Cross-link**: CC-223（boundary fix; pair these if tackling doctor.sh again）, CC-204（hook/profile reuse debt）

## CC-225 — claude-executor result observability（done）

**Problem**: `claude-executor` task output is written to session-scoped `/tmp/` paths that are not tracked in the repo, cannot be reviewed across sessions, and are not recoverable after the shell exits. The main thread has no durable record of brief path, result summary, or exit status for completed executor tasks.

**Why**: Raised from gate-20260522-145444 (CC-058 gating). The observability gap was observed during the CC-058 session: claude-executor tasks ran but their outputs were opaque to the main thread with no git-diffable artifact. This blocks the CC-211/CC-216 MCP architecture extraction.

**Requirement**: After an executor task completes, the durable record — brief path, result summary, exit status, and post-verify verdict — must be written to a repo-tracked directory (format consistent with `.gate-results/`). **Scope broadened (2026-06-15)**: originally framed for `claude-executor`, but under Model B (CC-385..389) every executor now runs as an independent subprocess, so this is the **all-executor durable run-state** record, not a claude-specific one. It is the **durable-state half** of the detached-supervised dispatch axis ([[CC-391]]): the supervisor writes this record so a main thread that exited (or a fresh one) can recover the outcome. Prerequisite for the MCP task abstraction in CC-211/CC-216.

**Dependencies**: [[CC-211]] (MCP architecture / run-FSM substrate), [[CC-391]] (lifecycle spike — consumer of this record), CC-058 (doctor.sh merge — prerequisite)

**Priority**: P3 — design prerequisite; not blocking current workflows. May be pulled forward as a thin durable-outbox slice if [[CC-376]] (opencode adapter) needs it (see [[CC-391]] sequencing).

**Cross-link**: [[CC-391]] (detached-supervised dispatch), [[CC-211]] (run-FSM), [[CC-216]] (task abstraction)

**Closed 2026-06-17**: Implemented the foreground durable-state half for all `pmctl dispatch run` adapters. Each terminal foreground run writes `<work_dir>/.dispatch-results/<run_id>.md` with YAML frontmatter and a short verify summary, without changing the run schema or adding a `runs.jsonl` pointer. The artifact is repo-local and gitignored; write failures are soft and do not alter dispatch exit codes. The detached supervisor follow-up can write the same record format.

## CC-227 — refactor: extract yaml-frontmatter lib + shared validation helpers（deferred；吸收 CC-226）

**Problem**: `scripts/lint-frontmatter.sh` mixes CLI parsing, frontmatter boundary detection, and a ~150-line hand-rolled YAML subset parser in a single file. The parser logic (`check_frontmatter()`) has no stable call boundary, making it hard to reuse from other scripts (e.g., `doctor.sh` currently forks a subprocess to call the linter), hard to test in isolation, and hard to extend without touching the CLI script. Additionally (absorbed from CC-226), the 4 collection branches each repeat the same dq-escape whitelist regex and adjacent-quoted-scalar check, creating a silent parity-gap risk.

**Why**: User feedback after CC-058 gating. Doing both extractions together is the right call: the grammar contract becomes a first-class lib with clear ownership, and the shared helpers never diverge because there is only one call site.

**Requirement**:
1. Move `check_frontmatter()` and all YAML-subset validation helpers into `scripts/lib/yaml-frontmatter.sh`
2. Extract shared dq-escape/adjacent-quote/empty-entry helpers into the lib (eliminates the 4-branch repetition from CC-226); ensure a parity test or single call site prevents future per-branch divergence
3. `scripts/lint-frontmatter.sh` becomes a thin CLI wrapper that sources the lib
4. `doctor.sh` can optionally source the lib directly instead of fork-execing the linter
5. Tests can source the lib and call `check_frontmatter()` directly, reducing tmp-file overhead

**Acceptance**: `lint-frontmatter.sh` golden parity preserved; lib direct unit tests pass; `doctor.sh` optional source path verified.

**Dependencies**: CC-058 (lint-frontmatter rewrite — merged)

**Priority**: P3 — maintainability; not blocking current workflows.

**Cross-link**: CC-224 (hook-profile lib extraction — same pattern), CC-226 (merged into this ticket)

## CC-236 — pmctl report: away-from-keyboard state roll-up（someday）

**Deprioritized 2026-05-22**: the original "morning report" framing assumed unattended / overnight agent runs. In actual practice the maintainer does not run agents away from the computer, so a time-gap roll-up has low current need. Demoted from v0.3.0 M4 to `🟢 someday`. On-demand state queries are already part of the `pmctl` surface (CC-215); this ticket is specifically the *periodic / since-you-were-away* report.

**Problem** (conditional): if unattended or overnight dispatch ever becomes part of the workflow, there is no single command to see what happened while away.

**Why**: A read-only roll-up over the state substrate (CC-230) would answer that without hand-reconstruction. The idea is sound; the need is gated on a workflow change.

**Requirement** (if revived): `pmctl report` — open tasks, blockers, last gate verdict per active task, runs since last invocation. Read-only query over the CC-230 store.

**Revisit when**: the workflow includes overnight / away-from-keyboard agent runs.

**Cross-link**: CC-230 (state store), CC-211 (epic); AI Night Shift mapping — docs/architecture/v0.3.0-synthesis.md §5.3.

## CC-238 — /pr-gate claude-route background fan-out hardening（deferred）

**Problem**: CC-217 made the `/pr-gate` claude-executor reviewer and synthesis fan-out (`commands/pr-gate.md` Route B) run detached via `run_in_background: true`. The CC-217 gate (gate-20260523, express tier) raised three advisories on the new flow.

**Why**: A detached fan-out with no timeout can wait indefinitely if a reviewer agent never reports completion; a single fan-out step makes per-reviewer attribution weaker on partial failure; and the behavior change has no test artifact.

**Requirement**:
- Add a completion timeout / fallback for the background reviewer + synthesis agents — a non-reporting agent must degrade to a partial/fail result, not an indefinite wait.
- Preserve per-reviewer failure attribution when only one fan-out branch fails.
- Add test coverage for the claude-route background completion + relay ordering (`scripts/test-pr-gate.sh` or a `commands/`-contract test).

**Priority**: P3 — advisory follow-up; the CC-217 GO was not blocked on it.

**Note (2026-06-15)**: advisories (a) no-timeout / indefinite-wait and (b) weak per-reviewer attribution are **symptoms of the missing supervisor** — a detached fan-out with no process that owns each child's lifecycle. The detached-supervised dispatch spike ([[CC-391]]) subsumes both: the supervisor's completion timeout + per-child attribution is the general fix, of which this gate-route case is one instance. Sequence (c) test coverage with that work rather than building a one-off timeout in `pr-gate.sh`.

**Cross-link**: [[CC-391]] (supervisor — general fix), CC-217 (origin), `commands/pr-gate.md` Route B.

## CC-240 — test-suite reliability follow-ups（deferred — partial）

**Status**: Part (a) — suite-count derivation in `scripts/test-run-all-tests.sh` — closed via CC-219 (pr:#129); the assertions now derive expected pass/skip totals from `${#SUITE_NAMES[@]}`. Part (b) below remains open.

**Problem (remaining)**: `scripts/test-portable.sh::case_mkdir_lock_contention` holds the lock with a fixed `sleep 1.2` to create contention overlap (pre-existing — not introduced by CC-203).

**Why**: Fixed-`sleep` async timing is flaky on slow / preempted CI hosts and conflicts with the qa-testing-rules AGENT.md red line on `sleep` for async synchronization — a flaky gate test erodes the gate's signal.

**Requirement**:
- `test-portable.sh::case_mkdir_lock_contention`: replace the fixed `sleep 1.2` lock-hold with an IPC / event-driven control path (e.g. a FIFO-gated holder, matching the pattern already used elsewhere in the portable-lock tests).

**Priority**: P3 — test-infra hardening; advisory follow-up, the CC-203 GO was not blocked on it.

**Cross-link**: CC-203 (origin), `scripts/test-run-all-tests.sh`, `scripts/test-portable.sh`.

## CC-244 — Typed artifact pipeline: spike → brief → handover schema（someday）

**Premise**: spike documents today (we have one: `docs/spikes/CC-060.md`) are free-form prose. The brief-authoring step extracts decisions + handover fields from prose, which (a) costs PM tokens re-reading the spike, (b) loses invariant checkpoints (no `decisions_resolved=true` flag, so the next agent might re-ask resolved questions), (c) makes main thread inline the whole spike when courier-ing between agents.

**Design sketch**: define `spike_v1` schema mirroring the existing `dispatch_handover_v1`:

```yaml
---
spike_id: CC-060
status: phase_3_ready    # phase_1_raw | phase_2_synthesis | phase_3_ready
decisions_resolved: true
branch_base: origin/main@f905db7
ticket_ids_consumed: [CC-242]
project_tooling: {makefile: false, backlog_render_target: false}
---
## scope
## findings
## constraints
## decisions
## phase3_handover     # bridges directly to dispatch_handover_v1
```

Add `scripts/spike-validate.sh` (mirror `handover-validate.sh`) + `scripts/gen-brief-from-spike.sh` (mechanical extraction).

**Why deferred to someday, not active**: only one spike exists today (CC-060). Schema's leverage scales with N — for N=1 it's pure overhead. Defer until 3+ spike docs accumulate and the brief-extraction pattern repeats verbatim, indicating real automation value. CC-243's schema-key naming was chosen now so that upgrade to CC-244 doesn't re-wash field names.

**Trigger conditions to promote from someday → active**:
- 3+ spike documents under `docs/spikes/` with similar phase-1/phase-2/phase-3 structure
- Two consecutive brief-authoring rounds where PM essentially copy-pastes the same fields out of spike prose
- Or: an automation use case (e.g. CI-side spike-stage tracking) that requires structured spike state

**See**: CC-243 (snapshot fields already aligned).

## CC-253 — CC-209 Phase 2: codegraph benchmark on representative target codebase（active）

**Problem**: CC-209 Phase 1 spike (PR #151) returned `Verdict: AMBER` because pm-dispatch's bash + markdown stack is outside codegraph's supported language set; the index produced `0 files / 0 nodes` (correctly — pm-dispatch is the wrong test target for a code-context tool). Phase 2 (benchmark token + latency vs rg/git baseline per original CC-209 ticket) was gated on Phase 1 verdict; running it on pm-dispatch would produce uninformative numbers.

**Why**: codegraph's intended use is indexing a target codebase that codex/Claude is being dispatched **against** (e.g., the user's app under development), not indexing pm-dispatch itself (the orchestration tool). To produce a meaningful adopt/defer/reject verdict for CC-232 (context-pack source) + CC-237 (enricher baseline), Phase 2 needs a representative target in codegraph's supported language set (TypeScript / JavaScript / Python / Go).

**Requirement**:
- Spike brief MUST specify `test_target:` explicitly (per CC-255 brief template improvement): user picks a TS/JS/Python/Go codebase from `~/github/` at brief time; the brief commits the target path as a literal parameter so the executor doesn't have to guess.
- Index target via `codegraph index` (pre-existing v0.8.0 binary at `~/.nvm/.../bin/codegraph` per PR #151 evidence).
- Run 3 representative queries — pick from real briefs (e.g., a "find all callers of `<symbol>`" query, a "definition lookup" query, a "callgraph traversal" query).
- Baseline: `rg` + `git ls-files` returning equivalent file/symbol set.
- Measure: input-token proxy (`wc -c` on full files in baseline vs `wc -c` on codegraph-filtered subset), latency (`time`).
- Verdict: adopt (token saving > 50% with acceptable precision) / defer (insufficient signal) / reject (worse than baseline).
- Apply CC-255 spike-validation discipline: main-thread cross-checks claims (license, install path, output shape) against `gh api` + WebFetch independently before consuming the verdict.

**Acceptance**:
- `docs/spikes/cc209-codegraph-phase2.md` (or appended `## Phase 2` to phase1 doc) exists with 3 query benchmarks + verdict.
- Phase 2 brief commits to `test_target:` field per CC-255 template.
- Main-thread validation section appended per `[[feedback_spike_validation_mandatory]]`.
- BACKLOG CC-209 row flipped to `✅ closed` with final verdict after Phase 2 lands.

**Priority**: P3 — feeds CC-232 / CC-237 design, not blocking other work.

**Cross-link**: CC-209 (Phase 1 origin), `docs/spikes/cc209-codegraph-phase1.md`, CC-255 (template improvements this depends on), CC-232 (context-pack consumer), CC-237 (enricher consumer), `[[feedback_spike_validation_mandatory]]`.

## CC-258 — pm-write-guard hook policy revision（deferred）

**Problem**: `scripts/hook-pm-write-guard.sh` currently allows only `~/.claude/projects/<project>/memory/**`. Audit of 207 denies over 10 days identified 3 legitimate PM-author patterns being incorrectly denied (12 hits; the rest are red-team / regression-test traffic).

**Why**:
- `/tmp/<task-slug>/*.md` is the verbatim-as-attached-file pattern from `[[feedback_codex_brief_discipline]]` (Pattern 2). Current deny forces PM to fall back to inline embedding — the exact failure mode the pattern was written to avoid (apply_patch debug-loop hang).
- `<repo>/docs/spikes/*-scope.md` / `*-rfc.md` are PM-authorship territory; the inline-return → main-thread-write round-trip is a no-value transcription step.
- Memory writes through symlinked memory dir (`memory-private/` per `[[reference_memory_private_repo]]`) get denied because `realpath_m` chases the symlink before the allow-pattern match. Hook bug, not policy.

**Requirement**:
- Three new allow rules (A: `/tmp/[a-z][!/]*/[!/]*.md`, B: `*/docs/spikes/{CC-NNN*,*-scope,*-rfc}.md`, C: dual-normalization for symlinked memory dir via lex_path-vs-abs_path).
- New `realpath_m_lex` helper (or `realpath -s` flag) in `scripts/lib/portable.sh`.
- ~50 LoC in `hook-pm-write-guard.sh`, ~20 LoC in `portable.sh`, ~15 new test cases in `scripts/test-hooks.sh`.
- `BACKLOG.md`, `DECISIONS.md`, `agents/*.md`, `commands/*.md`, `scripts/**`, `/tmp/brief-*.md` continue to deny (verified by audit).

**Acceptance**:
- The 12 currently-denied legitimate writes succeed under the new rules.
- All 195 currently-denied non-legitimate writes (including all red-team test cases) continue to deny.
- New regression tests cover Rule A boundaries (no intermediate dir → deny, traversal → deny, nested subdirs → deny, non-.md → deny), Rule B boundaries (not under spikes/ → deny, no CC-/-scope/-rfc prefix-suffix → deny), Rule C (symlinked memory entry → allow, file-symlink-jump-out → deny).
- `pm/scripts/validate.sh` BACKLOG parity preserved.

**Milestone**: Post-M1 process tooling (not blocking M1 substrate work).

**Priority**: P3 — process improvement. Current friction is workable via inline-return + main-thread-write or `CLAUDE_HOOK_PM_GUARD=off` bypass.

**Open questions**: see spike doc §Open questions (Rule A pattern strictness — loose `[a-z]` vs require `-content` suffix; memory-private root configurability — hard-code vs env var; filename allowlist scope — pre-add `-design.md`/`-proposal.md` or wait for audit; bypass mechanism — single global vs per-rule; spike scope vs spike output split).

**See**: `docs/spikes/CC-258-pm-write-guard-policy.md` (full design, audit data table, code change sketch, test coverage sketch, risks + mitigations).

**Cross-link**: `[[feedback_codex_brief_discipline]]` (Pattern 2 origin), `[[feedback_spike_validation_mandatory]]` (why `/tmp/brief-*.md` stays denied), `[[reference_memory_private_repo]]` (symlink target).

---

## CC-259 — yaml.sh lib extraction（someday）

**Problem**: `_yaml_get` (bash/awk list extractor) and `case_yaml_parse` (structural validator) are currently inlined in `scripts/test-core-schemas.sh`. When a second test script needs YAML parsing, these helpers will be copy-pasted, diverging over time.

**Why**: Deferred from CC-229 M1 substrate PR to avoid expanding an already-large gate surface. The helpers were freshly written in CC-229 and have exactly one consumer; extraction before a second consumer exists is premature. Trigger for promotion: a new `test-*.sh` that needs to parse/validate YAML.

**Requirement**:
- Extract `_yaml_get` and `case_yaml_parse` into `scripts/lib/yaml.sh` (source-able, no side effects on load)
- Wire `scripts/lib/yaml.sh` into `scripts/test-core-schemas.sh` via `source` (replace inline definitions)
- Add `scripts/test-yaml-lib.sh` with independent unit tests for both helpers (cover key-found, key-missing, tab-indented, empty-file, no-key-line cases)
- Wire `test-yaml-lib.sh` into `run-all-tests.sh` and `.github/workflows/lint.yml`
- All existing test-core-schemas.sh cases must still pass (golden-parity)

**Acceptance**:
1. `grep -c "_yaml_get\|case_yaml_parse" scripts/lib/yaml.sh` ≥ 2 (both helpers present)
2. `grep -q "source.*lib/yaml.sh" scripts/test-core-schemas.sh`
3. `bash scripts/test-yaml-lib.sh` → exit 0
4. `bash scripts/test-core-schemas.sh` → exit 0
5. `bash scripts/run-all-tests.sh` → exit 0

**Milestone**: v0.3.x (post-M1); pick up when a second YAML-parsing test script is introduced.

**Priority**: P3 — no active consumer need today; purely technical debt prevention.

## CC-270 — test: concurrent pmctl adapter generate guard（deferred）

**Problem**: `pmctl_adapter_generate` precheck + `mkdir -p` + ERR trap sequence is not
atomic. Two concurrent calls with the same name can race: one failing run's trap removes
the other run's partial output.

**Blast radius**: Local generated adapter directory deleted. Reproducible by deleting
`adapters/<name>` and re-running `pmctl adapter generate <name>`. No persistent data
loss, no external side effects.

**Why deferred**: Single-developer workflow makes concurrent invocation unlikely. The
recovery path (delete and regenerate) is documented.

**Fix path**: Replace `[[ -d $adapter_dir ]] && die` + `mkdir -p` with an atomic
`mkdir "$adapter_dir" 2>/dev/null || die "adapter already exists: adapters/$name"`.
This makes directory creation the mutex.

**Dependencies**: None.

**Priority**: P3 — low probability, reversible.

---

## CC-273 — arch: unified lifecycle hook event spec（deferred）

**Problem**: CC-206 added `pre-gate.sh` / `post-gate.sh` hooks directly into `scripts/pr-gate.sh`. If future tools (e.g., `codex-dispatch.sh`, `brief-validate.sh`) also need hook points, each script will independently add its own pre/post blocks — resulting in inconsistent naming, invocation contracts, and user documentation.

**Proposed direction**: Define a shared lifecycle event spec:
- Convention: `.pm-dispatch/hooks/<event>.sh` (e.g., `hooks/pre-gate.sh`, `hooks/post-dispatch.sh`)
- Single call site in a helper (e.g., `lib/run-lifecycle-hook.sh <event>`)
- Consistent contract: runs from project root as main thread; non-zero aborts the triggering operation
- Single `docs/lifecycle-hooks.md` covering all events (supersedes the pattern docs in `sandbox-limitations.md`)

**When to activate**: When a **second** hook point is requested (not gate). Design cost before that point exceeds the benefit.

**Distinct from [[CC-391]]**: this ticket is about *tool-step lifecycle hook events* (pre/post-gate, pre/post-dispatch call sites in scripts) — a user-extensibility seam. [[CC-391]] is about *process lifecycle ownership* (who owns the executor subprocess after launch, durable result, notification). Same word "lifecycle", orthogonal concerns; do not merge.

**Cross-link**: `[[CC-206]]` (first hook point — gate pre/post), [[CC-391]] (process lifecycle — distinct axis)

**Priority**: P3 — no current requirement; activate when second hook point emerges.

---

## CC-276 — feat: persistent gate override declarations to reduce re-statement across rounds

**Problem**: Each `pr-gate.sh` run spawns fresh reviewer sessions with no memory of previous rounds. When users consciously accept a known risk (storage cleanup failure, Docker unavailable in sandbox, etc.) and provide an override declaration, Round N+1 reviewers see the same code with no context of the previous override and re-block. Users must re-state identical override declarations every round. Observed: 9+ rounds on a single PR primarily due to re-blocking on already-accepted known risks.

**Requirement**:
- `pr-gate.sh` accepts `--override-file <path>` flag (Option A) OR auto-discovers `.gate-overrides.md` at repo root (Option B)
- Override file format: freeform markdown with per-reviewer override declarations (see issue for example)
- Reviewer brief preamble injects override content with instruction: "Do not re-block on these specific items unless the diff changes the risk materially"
- When no override file is present, behaviour is unchanged (backward compatible)

**Override file example** (`.gate-overrides.md`):
```markdown
## Gate Overrides (permanent, owner-accepted)

- [security] I accept that storage cleanup may fail after DB anonymization.
  Accepted: 2026-05-20. Owner: @screenleon.
- [risk] Docker is unavailable in the gate sandbox; integration tests pass locally.
  Accepted: 2026-05-20. Owner: @screenleon.
```

**Acceptance**:
1. `bash scripts/pr-gate.sh --cd . --override-file .gate-overrides.md` — override content injected into all 5 reviewer prompts
2. Reviewers that previously blocked on an overridden item return pass/advise (not block) when the diff is unchanged
3. `bash scripts/test-pr-gate.sh` → exit 0 (new test covering override injection)
4. No override file → behaviour identical to today

**area**: gate/process
**Raised by**: issue:#174 (2026-05-28)
**Priority**: P2 — DX improvement; reduces friction on PRs with known-accepted risks across multi-round gate iteration.

## CC-104d — [Windows dogfood r1] hook-codex-bash-guard.sh hardcoded read-root 🟡 deferred

**Problem**: `hook-codex-bash-guard.sh:55` defaults read-root to `$HOME/github:/tmp`; repos under `~/Documents/github/` or arbitrary Windows paths are not covered. `CLAUDE_HOOK_CODEX_READ_ROOTS` env override exists but the wrong default silently restricts hooks.

**Scope clarification (2026-06-04, from CC-320 pr:#224 gate)**: the `$HOME/github` default is *only* consumed on the **codex-executor subagent PreToolUse path** where the env var is unset. The adapter/CLI dispatch path (`adapters/codex/dispatch.sh`) now always exports `<git_root>:/tmp[:inherited]` (CC-320), so the default is dead there. Do **not** "unify on `/tmp` only" — that would strip repo read access from the subagent path and break the common case rather than fix it.

**Fix direction — derive, don't hardcode**: replace `$HOME/github` with a derived repo root (e.g. `PM_DISPATCH_REPO` parent, or `git rev-parse --show-toplevel` of the hook's invocation cwd), keeping `/tmp` as the scratch baseline. *Alternative*, only if the codex-executor-as-subagent path is confirmed fully retired post-CC-299 (i.e. everything goes through the adapter which always sets the env): the default becomes near-dead code and may be reduced/removed — but verify that retirement first; do not assume it. Prefer fail-closed + explicit hint over silently defaulting to `/tmp` when no repo root can be derived.

**Cross-link**: [[CC-320]], [[CC-299]].

## CC-104e — [Windows dogfood r1] WSL ↔ Windows memory path divergence 🟡 deferred

**Problem**: Project ID is path-sanitized working dir. Same repo at `~/github/pm-dispatch` (WSL) and `C:\Users\...\github\pm-dispatch` (Windows) produces different IDs → memory is partitioned across environments.
**Fix**: Document workaround (symlink, or `PM_DISPATCH_PROJECT_ID` override); harness-level issue upstream.

## CC-104f — [Windows dogfood r1] jq hard-dependency in hooks layer 🟡 deferred

**Problem**: Hooks layer hard-depends on `jq`. Options: vendor static `gojq` binary (3 MB × 3 platforms), or expose `--no-hooks` install mode for jq-less users.
**Decision**: `--no-hooks` preferred — keeps no-auto-install principle.

## CC-104g — [Windows dogfood r1] portable.sh test fixes ⚠️ partial 2026-05-17

**Problem**: `mkdir_lock` FIFO sync passes ✅ but underlying `mkdir` on Git Bash allows second concurrent acquire — real Windows portability bug. See CC-104k for the UNC/9P root cause.
**See**: pr:#80

## CC-104j — [Windows dogfood r1/r2] test-dispatch-handover.sh symlink fixture on Git Bash 🟡 deferred

**Problem**: `brief_file_symlink_rejects_case` uses `ln -s` for fixture; on Git Bash falls back to copy → validator treats as regular file → test fails. Fix: add `[[ -L "$link" ]]` precondition → SKIP.

## CC-104k — [Windows dogfood] UNC/9P filesystem mkdir atomicity caveat 🟡 deferred（建議與 CC-104r 合併實作）

**Problem**: `mkdir` is atomic on local NTFS but NOT on `\\wsl.localhost\...` (9P UNC). Running pm-dispatch from a WSL UNC path on Windows breaks concurrent lock semantics.
**Fix**: Not a code bug — install-on-local-disk caveat. Fix is docs + preflight; see CC-104r for the implementation. **建議與 CC-104r 同一 PR 落地** — CC-104k 是問題分析，CC-104r 是 docs/preflight 修正，屬同一 caveat 的兩半。

## CC-104m — [Windows dogfood] Platform layout — multi-target projection 🟡 deferred

**Problem**: pm-dispatch is currently Claude-only by install.sh target. Introduce `~/.pm-dispatch/content/` as canonical view with symlink-project to `~/.claude/` and future tool targets.
**Scope**: Post-v0.1.0, deferred until Codex/Cursor/Aider integration need surfaces.

## CC-104r — [Windows dogfood r3] hook-tool-trace.sh performance budget on Windows ⏸ deferred（建議與 CC-104k 合併實作）

**Problem**: Actual: 27990 ms vs 3500 ms budget on WSL UNC path (9P is ~8× slower than local disk). Not a pm-dispatch code bug — physical filesystem characteristic of running pm-dispatch from `\\wsl.localhost\...`.
**Fix** (two-part — covers both CC-104r + CC-104k's caveat documentation): (a) `docs/platform-support.md` warn "install on local disk, avoid cross-WSL/native FS boundaries"; (b) preflight detects UNC path → prints warning and skips budget assertion (~10 lines). **建議與 CC-104k 同一 PR**：CC-104k 是問題根因分析，CC-104r 是 docs/preflight 落地，屬同一 caveat 的兩半。

## CC-104s — [Windows dogfood r3] hook-tool-trace.sh path normalization on Git Bash 🟡 deferred

**Problem**: `read_home_path_basename_only` case-glob fails on Windows backslash paths. Fix: normalize via `cygpath`/string-replace before case-match. Affects trace JSON observability only.

## CC-285 — [ops] archiver safe-drop: don't drop a terminal row whose body exists nowhere 🟡 deferred

**Problem**: `scripts/archive-closed-backlog.sh` drops a terminal index row (`✅ closed` / `🚫 dropped`) even when no body section accompanies it in BACKLOG.md and none already exists in BACKLOG-ARCHIVE.md. It emits a per-id stderr warning, but the row metadata is removed (recoverable only via git).

**Why**: In a valid backlog this cannot happen — `pm/scripts/validate.sh` enforces an index↔body 1:1 invariant, so a terminal row always has a body to archive. It only arises from malformed/partial state. Recorded as an accepted tradeoff in DECISIONS 2026-05-30. This ticket tracks the defense-in-depth improvement if that invariant ever weakens.

**Requirement**:
1. When a terminal row's body is found in neither BACKLOG.md (this run) nor BACKLOG-ARCHIVE.md, do NOT drop the row; keep it and emit a loud warning for manual reconciliation.
2. Regression fixture: terminal row + no body anywhere → row preserved + warning (not removed).

**Cross-link**: `[[CC-284]]` (working-set contract / archiver), pr-gate finding on PR #186.

## CC-286 — [arch] pmctl: prefix-generic next-id derivation 🟡 deferred

**Problem**: `scripts/pm-prep-snapshot.sh` derives `backlog_next_id` for the `CC-` prefix only — it emits `CC-NNN` and scans BACKLOG.md + BACKLOG-ARCHIVE.md for the max `CC-` id. Other-prefix repos (JS-, PA-) are not handled; a generic next-id that only read the working-set index would also reuse archived IDs (the §2.2 hazard fixed CC-only in CC-284).

**Why**: pm-prep-snapshot is pm-dispatch-specific by design, so its CC-coupling is currently consistent (not a regression). But the cross-repo next-id belongs in `pmctl`, deriving the prefix from the target repo and scanning both the working set and the archive. Surfaced by pr-gate critic + architecture-reviewer on PR #186.

**Requirement**:
1. `pmctl` next-id: derive prefix from the repo's existing IDs (or config); compute max across BACKLOG.md + BACKLOG-ARCHIVE.md; `+1`.
2. Retire pm-prep-snapshot's CC-hardcoded derivation once pmctl provides next-id.

**Cross-link**: `[[CC-215]]` (pmctl core), `[[CC-282]]` (pmctl backlog), `[[CC-284]]` (working-set + the CC-only fix this generalizes).

## CC-306 — [arch] extend CC-233 layer enforcer to runtime-named data paths in scripts/ 🟡 deferred

**Problem**: CC-298 removed the current pr-gate runtime-named brief data paths, but the layer-boundary checks do not yet prevent a future script from reintroducing runtime-named data directories.

**Requirement**: Extend the CC-233 enforcer to catch `.codex-*` / `.claude-*` data directories under `scripts/` while keeping adapter-owned paths under `adapters/codex/` and `adapters/claude/` allowed.

**Why deferred / P3**: Optional defense-in-depth follow-up from CC-298; the implementation change is complete without strengthening validators in this ticket.

**Not done by CC-309**: CC-309's inverted layer-boundary test (`check_adapters_no_state_writes` in `test-layer-boundaries.sh`) forbids **adapters** from writing state directly — a different rule. This ticket's `.codex-*`/`.claude-*` runtime-named **data-dir** guard under `scripts/` is still unimplemented. (Corrects a v0.4.0 MILESTONES row that had conflated the two.)

**Cross-link**: `[[CC-233]]`, `[[CC-298]]`, `[[CC-309]]`.

## CC-342 — agent: debt-auditor — proactive tech-debt health scan on living code 🟢 someday

**Renumbered**: 原 CC-329；與 BACKLOG-ARCHIVE 已關閉的 FSM transition-table 票（✅ 2026-06-05）撞號，未開工的 debt-auditor 改號至 CC-342。撞號由 ticket-id lint 偵測，見 DECISIONS 2026-06-08。

**Problem**: 所有現有 reviewer（critic / architecture-reviewer / qa-tester）均以 PR diff 為觸發點，無法主動掃描 codebase 區域的技術債。結果是：重複程式、慣例分歧、過早抽象這類問題只有在 PR gate 中偶然被提及（以 `advise` 方式），沒有系統性的優先排序與追蹤。

**Why**: 技術債的最佳偵測時機是「任務之間」，而非「PR 審查中」。獨立的健康掃描 agent 在隔離 context 下讀取目標區域，不受正在進行的任務錨定，能給出客觀、可排序的債務清單，作為 milestone 規劃的輸入。

**Requirement**:
- `agents/debt-auditor.md` — agent 定義：
  - 輸入：目標路徑（目錄 / 模組 / glob），可選「關注面向」（duplication / conventions / tests / abstractions / all）
  - 流程：廣讀目標區域（Grep/Glob/Read）→ 識別 debt 項目 → 按 severity 與 fix-cost 排序 → 產出結構化報告
  - 輸出 YAML block（`debt_findings: [{severity, location, kind, issue, suggest, estimated_size}]`）
  - 不做任何修改，純讀取模式（tools: Read, Bash, Glob, Grep）
- `commands/audit.md` 或 `/audit` skill：呼叫 debt-auditor agent，結果由主線程摘要
- 定位為**新認知模式**（health assessment），有別於 PR-focused reviewer：
  - critic → diff 正確性（有 PR）
  - architecture-reviewer → diff 結構 fit（有 PR）
  - debt-auditor → 存活 codebase 的主動健康掃描（**無需 PR**）

**Non-goals**:
- 不執行修改（執行仍走 brief → executor → gate 路徑）
- 不取代 architecture-reviewer（PR gate 仍是 arch-reviewer 的地盤）
- 不做全 repo 掃描（target path 必須明確，避免輸出過大）

**Milestone**: `🟢 someday` — v0.5.0 candidate，與 CC-220 spike agent 同批考慮。

**Cross-link**: [[CC-220]], [[CC-239]], [[CC-338]], [[CC-237]].

---

## CC-344 — skill: /research — grounded external research with internal context anchoring 🟢 someday

**Problem**: `/discover` 只掃內部 backlog——只能看到「我們已經想到但還沒做」的機會，完全沒有「我們還沒想到的事」這條路。每次想引入外部方法（競品設計、社群實作、學術技術）都要手動搜尋，且搜出來的結果缺乏內部設計 constraint 的過濾，噪音大。

**Why**: 有效的外部研究需要兩個錨：(a) 知道自己「已有什麼」避免重複；(b) 知道「為什麼之前沒做某些事」避免搜到被排除的路。這兩個錨都在內部 memory/decisions 裡，用完全隔離的 agent 搜尋反而丟掉了最有用的 context。正確形狀是：先讀內部建立錨定，再問一個定向問題，最後帶著 constraint 去搜。

**Requirement**:
- `commands/research.md` — `/research [topic]` skill 定義：
  1. **內部錨定**：自動讀取與 topic 相關的 memory cards + DECISIONS 段落，建立「已有什麼、哪些路已排除」的 baseline
  2. **定向問題**：問使用者 1–2 個精準問題縮小搜尋查詢（例：「你說記憶優化，是指 recall 精度、token 壓縮、還是 episodic 連貫性？」）
  3. **外部搜尋**：派一個有 WebSearch 工具的 agent，帶著定向查詢抓取 3–5 個外部資訊點（實作、論文、社群討論）
  4. **過濾輸出**：主線程以內部 constraint 過濾，每個外部方法標記「可採用」或「與 [constraint X] 衝突，原因是 [decision Y]」
- 輸出不是搜尋結果的 dump，而是「可行性評估清單」

**Non-goals**:
- 不自動開票（使用者決定是否跟進）
- 不取代 `/discover`（兩者互補：discover 看內部機會，research 看外部方法）
- 不做完全自由的 web crawl——搜尋查詢必須由定向問題錨定

**Relationship**:
- 互補於 `/discover`（CC-343）——discover 是內部發散，research 是外部引入
- 未來可與 CC-338 repo index 整合：錨定時加入 repo 層的「已有哪些 helper/pattern」

**Milestone**: `🟢 someday` — 需要 WebSearch agent 能力，設計依賴 `/discover` 先落地驗證發散模式形狀。

**Cross-link**: [[CC-343]], [[CC-237]], [[CC-340]].

---

## CC-345 — dx: claude adapter 即時進度串流（stream-json）🟢 someday

**Problem**: `adapters/claude/dispatch.sh` 使用 `--output-format json`，使 claude 的 stdout 完全 buffered 至 process 結束才 flush。dispatch 執行期間 trace file 為 0 bytes、git working tree 無變動，使用者無從判斷 executor 是在讀取、規劃還是寫檔，只能盲等。

**Why**: `claude -p` 支援 `--output-format stream-json`，逐行輸出 NDJSON events（tool_use、tool_result、assistant），包含 tool name 與路徑。切換後可同步解析 events，在 stderr banner 即時顯示進度：
- `[reading]  core/schema/context-pack.schema.json`
- `[writing]  scripts/lib/pmctl-context.sh`
- `[running]  bash scripts/test-pmctl-context.sh → exit 0`

讓使用者在 dispatch 進行中就能看到 executor 正在操作哪些檔案，不再盲等 15–30 分鐘。

**Requirement**:
- `adapters/claude/dispatch.sh` 改用 `--output-format stream-json`
- 以 `tee` 同步寫入 trace file 並 pipe 至 progress parser
- `scripts/lib/claude-progress.sh`（新建）：讀 NDJSON stream，解析 tool_use events 並輸出 `[reading]`、`[writing]`、`[running]` 進度行至 stderr
- stream-json 不輸出單一 `.result` 欄位；dispatch.sh 結尾改從 stream 末尾 assistant message 擷取 `.last` 內容
- 向後相容：stream-json 不可用時 fallback 到 json

**Non-goals**:
- 不解析 assistant 思考內容（只解析 tool_use / tool_result events）
- 不改變 `.last` / `.jsonl` 最終格式（post-verify 向後相容）
- 不加 TUI / 進度條，純 stderr 行輸出

**Milestone**: `🟢 someday` — 不影響正確性；排在 v0.5.0 P1 工作完成後。

**Priority**: P2.

**Cross-link**: [[CC-338]], [[CC-341]].

## CC-346 — repo-index: cross-file ref tracking（file_refs layer，5 languages）⏸ paused 2026-06-10

**Problem**: `pmctl context query` 回傳 symbol + chunk hits，但看不出哪些檔案 import / source 了命中的模組。同一個 helper 被 10 個腳本 source，在 context hit 中卻像孤立的節點——dispatcher 不知道修改它的波及範圍，reuse-scan（CC-239）也無法辨識「這個 helper 已到處被用，不要再重複」。

**Why**: 加入 **import / source 解析層**（pure grep，無 AST），可以：
1. 讓 `pmctl context query` 在回傳 symbol hit 時附帶 `refs`（哪些檔案引用了它）
2. 讓 pr-gate blast-radius（CC-347）利用 ref graph 計算修改一個符號的實際影響檔案集
3. 讓 reuse-scan（CC-239）從「誰已在用這個 helper」推斷重用建議

架構上，這是 CC-338 repo-index 的第四張表，完全 optional（如無 CC-346 資料，CC-337/CC-239 fallback 到無 ref 模式）。不引入新的 binary 依賴。

**Requirement**:

*新增 SQLite 表*:
```sql
file_refs(id, from_id INTEGER REFERENCES files(id),
          to_path TEXT,        -- 被引用的 normalized 相對路徑（未必已在 files 表）
          ref_type TEXT,       -- source | import | require
          line_number INTEGER,
          resolved INTEGER)    -- 1 = to_path 已在 files 表；0 = unresolved
```

*語言支援（grep-only，無 AST）*:
| Language | 觸發模式 | ref_type |
|---|---|---|
| Bash / sh | `. <file>` 或 `source <file>` | source |
| Java | `import com.example.Foo;` | import |
| JavaScript | `require("./foo")` | require |
| TypeScript | `import ... from "./foo"` | import |
| Go | `import "github.com/.../pkg"` | import |

*增量更新*: `pmctl context update [path]` 執行後重新掃描受影響檔案的 ref 行；全量 `pmctl context index` 含 ref 掃描。

*查詢整合*: `pmctl context query` 在 `context_hit_v1` 回傳的 `refs` 欄位附帶直接引用者（to_path 命中的 from_id 集合），最多 5 條。

**Phase plan**:
- Phase a（MVP）: Bash `source` / `.` 解析，驗證 file_refs 表 + 增量更新
- Phase b: 加入 JS/TS `import` / `require`
- Phase c: 加入 Java `import` + Go `import`

**Acceptance**:
- `file_refs(from_id, to_path, ref_type, line_number, resolved)` table is created and populated by `pmctl context index` for at least the Phase a (Bash `source` / `.`) parser, with a fixture repo asserting resolved vs unresolved refs.
- `pmctl context update <file>` re-scans refs for a single file without a full rebuild.
- `pmctl context query` emits a bounded `refs` field (direct referrers) on hits; `LIKE`/`grep` fallback path tested.
- No schema migration breakage to the existing CC-338 `files` / `symbols` / `file_chunks` tables.

**Pause rationale（2026-06-10 arch review）**: 同日稍早曾以「reuse-scan 沒 ref 資料幫助有限」promote someday→P2，但 review 指出前提未驗證——reuse-scan 本身 ship 後（#256）操作面零 caller，給沒人用的工具加深資料層是加倍下注。先做 CC-356（接線 + 使用可觀測），用實際使用證據決定是否恢復本票。

**Resume trigger**: reuse-scan 輸出（經 [[CC-356]] 接線）實際進過 ≥2 份真 brief，且觀察到「缺 ref 資料」確為 reuse 建議品質的瓶頸。恢復時先只做 Phase a（bash source），不直上 5 語言。

**Milestone**: paused — 原排 v0.5.0 Phase 2；恢復後依當時 milestone 重排（depends CC-338 landed, CC-356 evidence）。

**Priority**: P3（promoted P3→P2 2026-06-10 早場，同日 arch review 改回 P3 + paused；見 DECISIONS 2026-06-10 scope-trim entry）。

**Cross-link**: [[CC-338]] (repo-index, parent table), [[CC-237]] (context_hit_v1 refs 欄位), [[CC-239]] (reuse-scan consumer), [[CC-347]] (blast-radius consumer), [[CC-356]] (wiring precondition).

## CC-347 — pr-gate: blast-radius analysis using cross-file refs 🟢 someday → v0.5.0 P3

**Problem**: 現行 gate 只審查 diff 內的檔案，但一個 Bash helper 或 schema 的改動，波及的是**所有 source 它的腳本**。gate 在不知道波及範圍的情況下做 risk review，等於盲目評估——risk-reviewer 無從判斷「修一行 state-writer.sh 是低風險還是影響 15 個腳本的高風險」。

**Why**: CC-346 的 `file_refs` 表提供了解析好的引用圖。在 gate brief 組裝時，對每個被修改的符號走一層 ref 圖，就能列出「直接受影響的未修改檔案集合」（blast radius）。這個資訊注入 brief 的 `context:` 節點，讓 risk-reviewer 和 security-reviewer 做有依據的 scope 評估。

**Requirement**:
- `scripts/pr-gate.sh` 在組裝 brief 前呼叫 `pmctl context query` 取得 diff 中每個變更符號的 `refs`
- 彙整成 `blast_radius` 清單：`{file, referenced_by: [path, …], ref_count: N}`
- 注入 brief `context:` 段落（`blast_radius_summary: N files directly affected outside diff`）
- 如無 CC-346 index（`file_refs` 表不存在或為空），此步驟靜默跳過（不阻擋 gate）
- risk-reviewer agent definition 補充：若 brief 含 `blast_radius` 節點，應審查 blast radius > 5 的符號改動

**Acceptance**:
- Gate brief for a change to a widely-sourced helper includes `blast_radius_summary`
- Gate brief for a repo without CC-346 index proceeds without error

**Milestone**: v0.5.0 P3（depends CC-346 Phase a）。

**Priority**: P3.

**Cross-link**: [[CC-346]] (data source), [[CC-338]] (repo-index), [[CC-237]] (context_hit_v1).

## CC-348 — pmctl project-map: cross-file dependency graph visualisation 🟢 someday

**Problem**: `pmctl context query` 回傳 per-query hits，但沒有辦法一眼看出 scripts/ 的整體引用結構：哪些腳本是「hub」（被大量 source），哪些是「leaf」（只被一個腳本 source），哪些 source 了不存在的路徑（broken refs）。這個結構對新貢獻者和 architecture-reviewer 都很有價值，但目前只能透過 grep + 手動追蹤推導。

**Why**: CC-346 的 `file_refs` 表一旦存在，project-map 就是一個純 SQL 聚合 + 格式化輸出的薄 CLI，無需額外的分析邏輯。輸出一份 text 或 dot 格式的引用圖，可直接貼進 PR 描述或 architecture review。

**Requirement**:
- `pmctl project-map [--format text|dot] [--from <path>] [--depth <n>]`
- `--format text`（default）: ASCII 樹狀列出引用鏈；indent 代表 depth
- `--format dot`：輸出 Graphviz DOT，可用 `dot -Tsvg` 渲染
- `--from <path>`：只顯示從指定檔案出發的子圖（單一起點 DFS）
- `--depth <n>`（default 3）：限制展開深度，避免 hub 節點爆炸
- 標示 broken refs（to_path 不在 files 表）
- 如無 CC-346 index，列印 `project-map requires CC-346 ref index; run: pmctl context index` 並 exit 1

**Non-goals**:
- 不生成 HTML / interactive graph（shell-only MVP）
- 不整合至 gate brief（那是 CC-347 的工作）
- 不解析 AST（依賴 CC-346 的 grep-level refs）

**Milestone**: `🟢 someday`（depends CC-346 Phase a+）。

**Priority**: P4.

**Cross-link**: [[CC-346]] (data source), [[CC-347]] (gate blast-radius consumer).

---

## CC-352 — codex-executor sandbox friction Pattern 1+2: apply_patch retry + Go module cache ⏸ deferred

**Context**: issue:#173 記錄了三種 codex-executor sandbox 摩擦模式。Pattern 3（git commit blocked — executor 回報 false partial）已由 CC-272 pr:#245 修復（brief template 移除 commit block，文件化主線程 commit delegation）。本票追蹤剩餘兩種。

**Pattern 1 — apply_patch 中途失敗 self-retry 噪音**

apply_patch 對大型或結構複雜的檔案可能失敗（patch 與當前檔案狀態不對齊）；codex 偵測後重讀檔案重試，通常第二次成功。噪音出現在 trace 中，加 1-2 min/次，且摘要顯示「non-fatal error in stderr」易被誤判為真實失敗。

Fix：brief authoring convention — 拆小 edit hunk，每段加 unique surrounding context 減少 patch ambiguity；可加入 codex-executor dispatch rules 文件。

**Pattern 2 — go build GOPATH copy 被 sandbox 擋**

sandbox 下 `cp -a <module-cache> /tmp` 被 workspace-write policy 擋；codex fallback 到 plain cp 或自行設 GOPATH，但需時 10-15 min/dispatch。

Fix：文件化 `GOPATH=/tmp/gopath go build` 慣例到 brief self_verify go build template，讓 codex 不需在 runtime 自行發現 workaround。

**Effort**: 兩者均為 pure doc/convention fix，無 code change。

**Priority**: P3 — 非阻斷性；Pattern 2 每次 go build dispatch 都出現，但有已知 workaround。

**Cross-link**: [[CC-272]] (Pattern 3 fix, pr:#245), [[CC-066]] (bash guard allowlist, relevant if Pattern 1 fix expands to allowlist approach).

**See**: issue:#173

---

## CC-333 — arch: pm-dispatch runtime 解耦合（v0.6.0 umbrella epic）🔵 active

> **v0.6.0 umbrella（2026-06-13 升格）**：本票為 v0.6.0「executor abstraction」milestone 的母 epic。主軸是「**新增第三個 executor = 放 `adapters/<name>/` + 一份 manifest，核心零改動**」，用 opencode + Antigravity 兩個真 adapter 落地當驗收。執行子票對應下方七層耦合：
>
> | 層面 | v0.6.0 子票 |
> |------|------------|
> | 2/3/6（hook 機制 / 設定格式 / dispatch 路由與術語） | [[CC-372]] runner-kind manifest → [[CC-373]] router 資料驅動 → [[CC-374]]/[[CC-375]] guard 收口＋安裝接線 |
> | 6（adapter 證明） | [[CC-376]] opencode、[[CC-377]] antigravity(`agy`) |
> | deprecation（runtime-coupling cruft 移除：`--profile`、`codex-dispatch.sh` shim） | [[CC-335]] |
> | 1/4/7（memory 路徑 / 安裝路徑 / reviewer memory 讀取） | **延後 v0.7.0+**（本版不處理；見 MILESTONES v0.6.0「延後」段） |
>
> 註：MCP（[[CC-216]]）為「通用橋」，邏輯上是 executor 抽象之後的下一層，**defer 至 v0.6.0 之後**（2026-06-13 user 拍板）。

**Problem**: pm-dispatch 在設計上以 Claude Code 為唯一執行環境，導致七個層面的硬耦合。目前任何想換 runtime（或在不同 AI CLI 環境使用）的嘗試，都需要手動繞過大量 Claude-specific 假設。

**Why**: pm-dispatch 的核心價值（dispatch brief 契約、PR gate review pipeline、policy enforcement、state store）與「執行在哪個 AI 上」理論上無關。但目前 memory 路徑、hook 機制、設定格式都直接假設 Claude Code。把這些降為 adapter layer 後，系統才能真正 runtime-agnostic，也更容易測試和移植。

**耦合清單（audit 2026-06-07）**：

| 層面 | 具體耦合 | 代表檔案 |
|------|---------|---------|
| 1. Memory 路徑 | `~/.claude/projects/<claude-project-id>/memory/` 硬寫在 agent 指令與 docs | `agents/project-pm.md`, `agents/critic.md`, `agents/architecture-reviewer.md`, `commands/mem-*.md` |
| 2. Hook 機制 | PreToolUse / PostToolUse / SessionStart / SessionStop 是 Claude Code 特有 primitive | 所有 `scripts/hook-*.sh`, `scripts/install-hooks.sh`, `docs/CONCEPTS.md` |
| 3. 設定格式 | `~/.claude/settings.json` 結構（`.hooks.PreToolUse[]` 等）與 Claude Code 版本綁定 | `scripts/install-hooks.sh`, `scripts/doctor.sh`, `scripts/test-install.sh` |
| 4. 安裝路徑 | `~/.claude/` 作為所有 assets 安裝目標（雖有 `CLAUDE_HOME` override，但 fallback 仍 Claude-specific） | `install.sh`, `uninstall.sh`, `scripts/install-hooks.sh` |
| 5. Env var 前綴 | `CLAUDE_HOOK_*` / `CLAUDE_CONFIG_DIR` 前綴（CC-321 已完成重命名 `CLAUDE_HOOK_*` → `PM_HOOK_*`；shims 至 v0.5.0 移除） | `scripts/hook-*.sh`, `scripts/lib/memory.sh` |
| 6. Dispatch 術語 | `dispatch_handover_v1` 區塊格式、`Agent tool` 呼叫約定、`claude --print` CLI 假設 | `docs/dispatch-brief.md`, `adapters/claude/dispatch.sh`, `commands/pm.md` |
| 7. Reviewer memory 讀取 | Reviewer agents 直接讀 `~/.claude/projects/<id>/memory/` 而非透過 handover brief | `agents/critic.md`, `agents/architecture-reviewer.md`, `agents/risk-reviewer.md`, `agents/security-reviewer.md` |

**解耦合方向（供後續拆票參考）**：

- **層面 7（最小代價，最高收益）**：Reviewer agents 移除直接 memory 路徑引用；改由 PM 在建 handover brief 時 embed 相關 memory 內容至 `project_memory:` 欄位，reviewers 只讀 brief。
- **層面 5**：CC-321 已完成（2026-06-08）。`PM_HOOK_*` 已取代 `CLAUDE_HOOK_*`，shims 至 v0.5.0 移除。
- **層面 4**：`CLAUDE_HOME` override 已存在，補齊所有 bypass-door 後降為 pure adapter 設定。
- **層面 1**：引入 `PM_MEMORY_DIR` env var；PM agent 讀寫由 env 指定路徑，預設仍 `~/.claude/...` 但可 override。
- **層面 2/3**：Hook 機制是 Claude Code 深度 primitive，短期不可能完全抽象；目標是把 hook 邏輯（guard policy）從 Claude hook event 格式中抽出，讓 policy 可獨立測試，hook 僅作為 trigger adapter。
- **層面 6**：`dispatch_handover_v1` 格式是 internal contract，重命名後可 rename 為 `pm_dispatch_handover_v1`；`claude --print` 已封裝在 `adapters/claude/dispatch.sh`，不需大改。

**Non-goals**: 本票不追求「完全不依賴 Claude Code」——Claude 仍是主要執行環境。目標是「核心 workflow 不假設 Claude-specific 路徑與機制」，降低移植成本與測試複雜度。

**Dependencies**: [[CC-321]]（env var 重命名，應先於本票任何 hook 相關子票）。

---

## CC-335 — release: deprecated surface registry + v0.6.0 removal sweep ✅ 2026-06-16

**See**: pr:#292

> **v0.6.0 Phase 4**：本票即 v0.6.0「executor abstraction」milestone 的 deprecation 清掃階段。其中 `--profile` alias（→ `--role`+`--runtime`）與 `codex-dispatch.sh` shim（→ `pmctl dispatch run --adapter codex`）正是 runtime-coupling cruft，與 [[CC-373]]/[[CC-374]] 抽象收口同期最自然。見 MILESTONES v0.6.0。

追蹤 v0.4.0/v0.5.0 期間標記為 deprecated 的 public surface，在 v0.6.0 統一移除。每個項目在移除前需先補 stderr deprecation warning（讓使用者有遷移週期）。

### Deprecated surfaces（v0.6.0 sweep 結果）

| Surface | Deprecated since | Replacement | Removal target | 狀態 |
|---|---|---|---|---|
| `bash scripts/pr-gate.sh` 直呼腳本 | v0.4.0 | `pmctl gate run` | doc-only | ✅ **降級為文件 deprecation**：pr-gate.sh 是 gate 實作本體（`pmctl-gate.sh` 以 `exec` 呼叫），且 standalone/copy-mode 是官方支援的 fallback；不刪檔、不加 runtime warning，僅文件建議 `pmctl gate run`。 |
| `scripts/codex-dispatch.sh` shim（legacy callers） | pre-v0.4.0 | `pmctl dispatch run --adapter codex` | v0.6.0 | ✅ shim 檔早於 v0.3.0 sunset（CC-296）刪除；本次清掃 allowlist/doctor/uninstall 內守衛永不存在檔的 dead-code 與殘留 stale 註解。 |
| `--profile <pm\|codex\|claude>` flag in `pmctl guard check` | pre-v0.4.0 | `--role` + `--runtime` flags | v0.6.0 | ✅ guard check 早已只接受 `--role`/`--runtime`；無殘留 shim（install/doctor 的 `--profile minimal\|full` 為不同 surface，非本票）。 |
| `sandbox` / `approval` / `skip_git_check` legacy metadata fields | pre-v0.4.0 | `isolation_level` field | v0.6.0 | ✅ **移除**：`handover-validate.sh` 刪除三個驗證函式、isolation_level 改必填、trio 欄位出現即 reject 並給遷移訊息；codex adapter 原生 `--sandbox/--approval`（isolation_level 翻譯目標）保留。 |
| `CLAUDE_HOOK_*` env vars（shims） | v0.4.0（CC-321） | `PM_HOOK_*` | v0.5.0 | ✅ **移除**：5 個 `hook-*.sh` 內 9 行向後相容 shim 全刪（0 測試依賴）。 |

### Work items（已完成）

1. ✅ trio / CLAUDE_HOOK_* 在 v0.5.0 前已有 stderr deprecation warning，遷移週期已過。
2. ✅ 移除實作後全測試套件綠燈（trio fixture 轉 isolation_level、刪 trio 函式測試、加 trio-rejected 測試）。
3. ✅ 清理文件（dispatch-brief.md / executor-contract.md）與 dead-code 殘留。

### How to add a new deprecated surface

在這個 body 的 table 新增一行，欄位：surface（exact invocation）、deprecated since（vX.Y.Z）、replacement（exact new invocation）、removal target（vX.Y.Z）。不需另開票。

---

## CC-340 — knowledge index: standalone FTS over memory/backlog/decisions 🟢 someday → v0.6.0

**Problem**: The repo index (CC-338) covers the code plane ("where to change, what to reuse"), but the second-brain plane — "why, how was this decided, what failed before" — has no structured search backing the context-pack. `/mem-search` exists as a skill but is keyword/grep over files, not an index with ranking or trust tiers.

**Why**: knowledge and repo are two different search planes with opposite lifecycles (curated/durable vs derived/rebuildable). v0.5.0 ships the repo plane + the shared interface (CC-237). The **anchored-TOC slice** of the knowledge index (per-section chunking of in-repo knowledge docs — enough to make the read side usable; memory-card indexing explicitly excluded) is pulled forward to **CC-354** (v0.5.0 Phase 2), because without it the knowledge plane has no queryable index at all. CC-340 narrows to the **heavy remainder**: standalone full-text ranking, embeddings, and low-trust episodic chunking — deferred to v0.6.0, overlapping the existing `/mem-search` surface.

**Requirement** (v0.6.0 — remainder after CC-354):
- Full-text ranking over wiki + episodes.jsonl (low-trust episodic chunks) beyond the anchored TOC CC-354 delivers.
- Embeddings / semantic backend (optional accelerator — Khoj-class).
- Richer trust-tier ranking (curated > wiki > backlog body > episode > raw event) and recency vs durability weighting.

**Non-goals**:
- Rewriting memory cards or making SQLite the source of truth (canonical stays the Markdown / JSONL).
- Replacing `/mem-search` UX before the index proves out.

**Milestone**: v0.6.0 — symmetric to CC-338; the usable slice is CC-354, this is the heavy remainder.

**Priority**: P3.

**Cross-link**: [[CC-354]] (anchored-TOC slice, pulled forward), [[CC-338]] (repo-index counterpart), [[CC-237]] (shared interface), [[CC-234]] (memory v2 write side), [[CC-232]] (pack schema).

## CC-355 — knowledge index: HTML semantic chunking（`<h1-6>` sections）🟢 someday

**Problem**: CC-354 chunks knowledge files by a per-format strategy — markdown by `^#{1,6}` headings, txt/other by line windows. HTML files fall back to window chunking, which loses their real section structure (`<h1>..<h6>` headings carry the same human-authored semantic anchors as markdown headings).

**Why**: HTML is structurally symmetric to Markdown (`<h1-6>` ≈ `^#{1,6}`), so it deserves heading-based chunking for the same retrieval quality. It is split out of CC-354 because robust HTML parsing in bash/grep is its own concern (nested tags, attributes, comments, `<pre>`/`<code>` blocks, entity decoding) and there is no `.html` knowledge source in the repo today — this is forward-looking generality, not a current need.

**Requirement** (when an HTML knowledge source appears):
- Plug an `html` strategy into the CC-354 per-format chunker seam: split on `<h1>`..`<h6>`, use the (tag-stripped) heading text as the chunk heading, strip tags for the lead.
- Add an `html`/`htm` branch to `_ctx_detect_language` and to the index scan `find` list (deferred from CC-354).
- Handle the parsing edge cases (comments, `<pre>`/`<code>`, entities) or document the known-fragile boundaries.
- Reuse the existing `file_chunks` columns; no schema migration.

**Acceptance**:
- An `.html` fixture with `<h1>` / `<h2>` sections produces one `file_chunks` row per heading, with tag-stripped heading text and correct `line_start` / `line_end` anchors.
- Comments, `<pre>` / `<code>` blocks, and HTML entities are handled per a stated rule (either correctly parsed or explicitly documented as a known-fragile boundary with the observed behavior).
- `pmctl context query` returns the right `<h2>` section ref for a query matching that section's heading.

**Trigger**: a real `.html` file enters the knowledge plane, or a consumer needs HTML-section retrieval.

**Priority**: P3.

**Cross-link**: [[CC-354]] (per-format chunker seam this plugs into), [[CC-340]] (knowledge index family).

## CC-357 — skill as contract: machine-readable schema for skills

**Problem**: `skills/` 下的所有 skill（目前 `dispatch-brief`、`pr-gate-review`）都是純 markdown prose 的 `SKILL.md`。沒有任何機器可讀欄位定義：輸入型別是什麼、輸出格式是什麼、允許/禁止使用哪些工具、什麼狀態算「完成」。這和 brief 的狀況一模一樣——brief 在引入 `dispatch_handover_v1` schema + `brief-validate.sh` 之前，也是純 prose，無從驗證。

**Why**: pm-dispatch 的 brief 已有明確契約（`dispatch_handover_v1` schema、`brief-validate.sh`、`pmctl validate brief`），任何 malformed brief 都在 dispatch 前被機器攔截。Skill 卻沒有對等機制——skill 的「輸入是什麼」、「輸出格式是什麼」、「需要什麼工具」完全靠人讀 prose 理解，沒有驗證層。長遠而言，skill 越來越多後，這個缺乏 contract 的問題會重演 brief 的問題：caller 不知道 skill 期待什麼、skill 產出什麼格式的東西、skill 用了哪些工具。

**Core idea**: 給每個 skill 一份 machine-readable 描述，使 skill 能被驗證、被自動發現、被工具限制強制執行。參考 `dispatch_handover_v1` 的設計哲學：不是要限制創意，而是讓機器可以在 skill 被呼叫前/後做檢查。具體欄位設計留待實作期規劃，可能的方向：
- `input:` — skill 接受的 arguments/context 型別
- `output:` — skill 保證產出的格式（e.g. `dispatch_handover_v1 block`、`gate_verdict`、plain text）
- `tool_constraints:` — 允許/禁止哪些工具（與 guard.sh 的 role-based policy 互補）
- `completion_condition:` — 什麼算完成（observable state，不只是「模型說完了」）

**Non-goals**: 不重新設計 skill 執行機制；不要求現有 skill prose 消失（schema 是 complement，不是 replace）；不在此票做 validator。

**Milestone**: someday（無里程碑排期，概念票）。

**Priority**: 未定（someday）。

**Cross-link**: `dispatch_handover_v1` (brief contract analogue), `brief-validate.sh` (validator pattern), [[CC-215]] (pmctl validate surface), `skills/dispatch-brief/SKILL.md` + `skills/pr-gate-review/SKILL.md` (first candidates).

## CC-358 — runner telemetry: evaluate with real runs — success rate / failure pattern / fallback analysis

**Problem**: `events.jsonl` 已有每次 run 的完整生命週期原料（`run.pending` → `run.dispatched` → `run.verifying` → `run.ok`/`run.failed`），但目前沒有任何 consumer 分析這些資料。結果是：每次任務成功或失敗都只是一次性觀察，不會累積成任何可查詢的分佈。PM 無法知道「這類任務 codex adapter 的成功率如何」、「最常見的失敗原因是什麼」、「fallback 到 claude 的頻率有多高」——所有路由和 recovery 決策都靠直覺。

**Why**: pm-dispatch 的核心價值主張之一是「減少浪費」，但沒有 runner telemetry 就無法衡量浪費在哪裡。目前有三個決策點完全沒有資料支撐：
1. **Adapter routing**（codex vs claude）：根據什麼選？主觀猜測。
2. **Recovery strategy**（失敗後 retry 還是 fallback）：沒有失敗模式分佈，無從判斷 retry 有沒有意義。
3. **Runner diversity**（要不要支援第三個 adapter）：沒有現有 adapter 的成功率資料，無從判斷值不值得。

本票的核心理念：**用自己的任務歷史來驅動自己的決策**——events.jsonl 是現成的 telemetry 原料，缺的是分析層。

**Core idea**: 在現有 events 原料上建立 `pmctl run-stats`（或類似 subcommand），提供：
- Per-adapter 成功率（成功/失敗/超時 分佈）
- 依 goal 分群的失敗模式（常見失敗在哪類任務？）
- Fallback 觸發頻率和觸發原因
- 時序趨勢（最近 N 次 vs 歷史整體）

**Non-goals**: 不做 ML 分類；不做實時 dashboard；不改 events.jsonl schema（用現有欄位）。分析是離線/按需，不是自動觸發。

**Resume trigger for related tickets**: 本票的觀察結果是 [[CC-346]]（cross-file ref）resume 的補充證據，也是任何 runner diversity 票（multi-vendor adapter）的前置條件——先看數據，再決定要不要加第三個 adapter。

**Milestone**: someday（無里程碑排期，概念票）。

**Priority**: 未定（someday）。

**Cross-link**: `events.jsonl` (data source), `pmctl trace tail` (existing consumer, read model to build on), [[CC-234]] (write side of memory loop — episodes 可補充 events 的語意), [[CC-346]] (paused; needs CC-356 evidence first, this ticket adds more evidence dimension).

## CC-359 — backlog-driven batch dispatch with worktree isolation（concept）

**Concept**: pm-dispatch 自己管理 `git worktree` 生命週期，讓多個 executor worker 在各自隔離的 filesystem workspace 平行處理 backlog task。不依賴任何特定 executor 的 platform feature——worktree 管理是 pmctl 的責任，不是 codex 或 claude 等 executor 的責任。

**Design principles**:

- **Executor-agnostic worktree management**: `git worktree add <path> -b agent/<task-id>` / `git worktree remove <path>` 由 pmctl 負責，codex 和 claude 都能在各自的 worktree 裡跑，不依賴特定 executor 的 isolation 機制。
- **Human-in-the-loop**: batch dispatch 後 merge 決策仍在人這邊，無 auto-merge，PR-only 原則不變。
- **衝突可觀測不禁止**: 以 BACKLOG `area` 欄位做粗粒度衝突分組——同 area task 排隊不並行；不同 area 可平行。不做逐檔 conflict detection（成本高且在 brief 寫完前無法計算）。逐 PR review 和 rebase 流程處理邏輯衝突。
- **PR-only output**: 每個 task 在各自 worktree 產出 commit + branch + PR，由人統一 review 和 merge。

**Suitable tasks for parallel dispatch**: 測試補強、文件補強、小 bug 修復、CLI option 補齊、error message 改善、backlog spike/survey。不適合：架構核心大改、schema breaking change、多個 task 改相同核心介面。

**Token budget as scheduler input**: 可設 `--budget low/normal/aggressive` 控制並行度（worker 數、adapter 選擇、是否使用 Opus）。

**Priority reasoning**: 需要 memory loop 完整落地後，才能有足夠的 context substrate 讓 batch dispatcher 智能分派任務。無固定里程碑——後續視工作流需求與 backlog 積壓情況決定是否優先。

**Non-goals for this concept ticket**: 不設計具體 subcommand syntax 或 schema——那是 implementation ticket 的工作；本票只記錄理念和約束。

**Cross-link**: [[CC-358]] (runner telemetry — batch dispatcher 的決策依據), [[CC-346]] (paused), `git worktree` (stdlib, no new dependency).

---

## CC-364 — perf: `pmctl trace tail --all` per-event jq spawn（deferred）

**See**: pr:#270

`pmctl trace tail --kind <kind> --all --json` is O(n) with a high per-event constant — measured ~20s for 338 events (~60ms/event), consistent with spawning a `jq` (or equivalent subprocess) per event rather than a single streaming pass. Discovered while diagnosing the #270 context-telemetry test flakiness: `context.queried` / `context.reuse_scanned` events accumulate in a partition, and the readback assertions called `trace tail --all`, so reads degraded as the partition grew. The tests were de-coupled from this — context telemetry now honors `PM_DISPATCH_STATE_ROOT`, so the suite isolates all state into a throwaway root — leaving this as a standalone reader-performance follow-up, not a blocker. Fix: rework `trace tail` filtering/serialization as a single `jq` pass (or a streaming reader) over `events.jsonl`.
