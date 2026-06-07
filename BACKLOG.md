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
| CC-018 | 🔵 active | Codex quota 自動追蹤：codex-dispatch 後查詢剩餘 quota 寫入 rate-limits-codex.json | ux/token | 2026-05-14 | — | P3 | — |
| CC-023 | ⏸ deferred | `coupling-reviewer`：PR gate 加入語言感知耦合分析（dependency-cruiser/gocyclo/coca） | ops/gate | 2026-05-14 | — | — | — |
| CC-026 | 🔵 active | `/skill-distill`：偵測重複工作流，產出草稿 skill .md | ux/memory | 2026-05-15 | — | P3 | — |
| CC-027b | 🟡 deferred | `tool-trace.jsonl` health signal：bounded error counter + downstream warning | ux/memory | 2026-05-15 | — | — | — |
| CC-027c | 🟡 deferred | `hook-tool-trace.sh` strict JSON validation：jq inline cost ~25ms/call 超 budget；探索 async post-validation 或 sampled fraction | ux/memory | 2026-05-15 | — | — | — |
| CC-032 | 🔵 active | `[[feedback_*]]` cross-link 公開化：抽到 `docs/policies/` glossary 避免 dead link | process/DX | 2026-05-15 | — | P3 | — |
| CC-033 | 🔵 active | Public flip checklist：Issues/Discussions 設定、CITATION.cff（選配）、後續觀察期 | process | 2026-05-15 | — | P3 | — |
| CC-035 | 🔵 active | install/uninstall-hooks basename+scripts/ heuristic：未覆蓋另一工具也在 scripts/ 下同名 hook 的 collision edge case | ops | 2026-05-15 | pr:#53 | P3 | — |
| CC-038 | ⏸ deferred | Windows / cross-platform 鎖機制：`flock` Linux-only，未來支援 Windows/macOS 需替代方案 | ops/portability | 2026-05-15 | — | — | — |
| CC-044 | ⏸ deferred | `tool-trace.jsonl` rotation/retention policy（max sessions vs bytes vs archive） | ux/memory | 2026-05-15 | — | — | — |
| CC-045 | ⏸ deferred | brief timeout heuristic：依 target repo playbook depth 設 timeout，不能只看 edit size；brief context 可加「skip playbook re-read」短路指令；codex-dispatch.sh 可選 warn 當 repo 有 `rules/`/`AGENTS.md` 且 timeout < 900s | process/DX | 2026-05-16 | — | — | — |
| CC-104d | 🟡 deferred | **[Windows dogfood r1 findings]** Hardcoded `$HOME/github` read root default in `hook-codex-bash-guard.sh:54`; `CLAUDE_HOOK_CODEX_READ_ROOTS` env override exists but default is wrong on Windows where repos live under `~/Documents/github/` or arbitrary paths. Should be derived from `PM_DISPATCH_REPO` parent or removed | ops | 2026-05-17 | — | — | oss |
| CC-104e | 🟡 deferred | **[Windows dogfood r1 findings]** WSL ↔ Windows `~/.claude/projects/<project-id>/memory/` divergence: project ID is path-sanitization of working dir. Same repo cloned at `~/github/pm-dispatch` (WSL) and `C:\Users\<user>\Documents\github\pm-dispatch` (Windows) produces different IDs → memory partitioned. Harness-level (Claude Code) issue; document workaround (symlink, or PM_DISPATCH_PROJECT_ID override) | ux/memory | 2026-05-17 | — | — | oss |
| CC-104f | 🟡 deferred | **[Windows dogfood r1 findings]** jq is hard-dep for hooks layer. Options: vendor static `gojq` binary (3 MB × 3 platforms), or expose `--no-hooks` install mode that skips hook wiring entirely (lightweight install for jq-less users). Latter preferred — keeps "no auto-install of system pkgs" principle | arch/install | 2026-05-17 | — | — | oss |
| CC-104g | ⚠️ partial 2026-05-17 | **[Windows dogfood r1 fixes]** portable.sh test fixes: symlink test SKIP + detect_platform host_native PASS on Windows ✅; mkdir_lock FIFO sync ✅ but underlying `mkdir` on Git Bash still allows second concurrent acquire — real Windows portability bug, NOT test sync issue. See CC-104k | ops/test | 2026-05-17 | pr:#80 | — | oss |
| CC-104j | 🟡 deferred | **[Windows dogfood r1 r2 finding]** `test-dispatch-handover.sh:674-685` `brief_file_symlink_rejects_case` uses `ln -s` for fixture setup; on Git Bash falls back to copy → validator treats as regular file → test fails. Same skip-if-not-symlink pattern as CC-104g case (a) — `[[ -L "$link" ]]` precondition → SKIP | ops/test | 2026-05-17 | — | — | oss |
| CC-104k | 🟡 deferred | **[UNC/9P filesystem caveat — re-scoped from `mkdir_lock` atomicity claim]** Race test on Windows Git Bash 5.2.15 (Windows 11) confirmed `mkdir` IS atomic on **local NTFS** (`C:\...\Temp` — Git Bash's `/tmp`); 20/20 rounds × 50 parallel = exactly 1 winner each. Original CC-037 regression failure on Windows was specifically when running pm-dispatch from `\\\\wsl.localhost\\Ubuntu\\...` (9P UNC bridging WSL FS to Windows) — 9P protocol or its Windows client does not preserve mkdir atomicity. Not a code bug; install-on-local-disk caveat. See **CC-104r** for the install-time UNC path detect / docs warn follow-up. If a third filesystem ever surfaces `mkdir`-non-atomic, revisit with `set -C` + `: > file` primitive (already race-tested as atomic on tested FS) | ops/portability | 2026-05-18 | — | — | oss |
| CC-104m | 🟡 deferred | **[Platform layout — post-v0.1.0]** pm-dispatch staging dir + multi-target projection: introduce `~/.pm-dispatch/content/` as canonical view, then symlink-project to `~/.claude/` and (future) `~/.codex/` etc. Today pm-dispatch is Claude-only by virtue of where install.sh lands; this re-shapes it as a tool-agnostic content platform. Touches install.sh, manifest schema (v0 → v1 with `target` field), uninstall semantics. Decided 2026-05-18 (CC-104c scope discussion, Path Y). Open until clear Codex/Cursor/Aider integration need surfaces | arch/install | 2026-05-18 | — | — | oss |
| CC-104o | 🟢 superseded 2026-05-20 | **[Windows dogfood r3 finding]** Microsoft Store python3 reparse-point stub (`/c/Users/<user>/AppData/Local/Microsoft/WindowsApps/python3.exe`) returns exit 49 in non-interactive contexts → 36 preflight cases FAIL (every `inject-hook/*`, `session-hook/*`, `rl-hook/*`, `stop_*`, `mem-recall/format-validator`, `cross-cmd/*` because hook scripts internally call python3). Fix: install.sh / install-hooks.sh preflight detects the MS Store stub via `python3 -c 'pass'` exit-49 probe, hard-fail with platform-aware hint (`winget install Python.Python.3.12` + "remove WindowsApps stub from PATH or order real Python first"). Required before Windows = Supported flag flip — fork users on Windows hit this on first install. Superseded by CC-104t which eliminates python3 entirely via jq rewrite. | ops | 2026-05-18 | — | — | oss |
| CC-104r | ⏸ deferred | **[Windows dogfood r3 finding]** `hook-tool-trace.sh` performance_budget assertion: 27990 ms actual vs 3500 ms budget on Windows native filesystem (WSL UNC path `\\wsl.localhost\...` is ~8× slower than local disk). Not a pm-dispatch bug — physical filesystem characteristic. Fix is two-part: (a) `docs/platform-support.md` warns "install on local disk, avoid cross-WSL/native FS boundaries"; (b) preflight detects UNC path → prints warning and skips budget assertion (10 lines). Polish, not blocker | docs/ops | 2026-05-18 | — | — | oss |
| CC-104s | 🟡 deferred | **[Windows dogfood r3 finding]** `hook-tool-trace.sh:195` `read_home_path_basename_only` returns `first_arg_or_skill:null` on Windows because case-glob `"$HOME"/*` uses forward slashes (`/c/Users/Lien Chen`) but harness sends `file_path` with backslashes (`C:\Users\Lien Chen\...`); both case branches miss. Fix: normalize input path via `cygpath`/string-replace (`\\` → `/`, `C:\Users\...` → `/c/Users/...`) before case-match. Polish — affects trace JSON observability only, not functionality | ops/portability | 2026-05-18 | — | — | oss |
| CC-205 | ⏸ deferred | `/pm` dual-executor planning: `--executor auto/codex/claude` flag（與 pr-gate 介面對齊）+ `dispatch_handover_v1` 加 `executor` 欄位；加 `--parallel-plan` mode — PM 偵測 arch/multi-subsystem/first-design 特徵時，在 dispatch 前暫停並詢問用戶是否啟用；確認後 codex 與 claude 各自獨立規劃，current model 合成一份 best-of 計劃輸出；`/pm --parallel-plan` flag 可跳過確認步驟直接 parallel dispatch | process | 2026-05-20 | — | P2 | design |
| CC-209 | 🟢 someday | **[context-enrichment spike: codegraph evaluation]** Evaluate colbymchenry/codegraph (MIT, TypeScript, 18.8k★, active) as a **context-pack** source (CC-232). Phase 1 spike `docs/spikes/cc209-codegraph-phase1.md` (2026-05-24): codex returned RED on misapplied rubric; **main-thread validation amended to AMBER** — install ✓, license MIT ✓, API works ✓, BUT pm-dispatch is not codegraph's intended target (bash/markdown stack not supported). Phase 2 (benchmark) deferred until brief re-specifies target as TS/JS/Python/Go codebase. Process lessons: rubric must enumerate sandbox-block as local-env; spike brief must specify test target separately from working directory; main-thread validation mandatory for verdict-issuing spikes. | ops/token | 2026-05-21 | pr:TBD | P3 | spike |
| CC-210 | ⏸ deferred | **[uninstall blast-radius guard]** `uninstall.sh` currently allows `$HOME/.claude` itself to pass the managed-root safety guard (dst must start with managed root); a malformed or tampered copy-mode manifest entry matching the directory hash could remove the entire Claude config tree. Fix: add an explicit `[[ "$dst" == "$managed_root" ]]` rejection check before the startswith guard, so only strict descendants of the managed root are deletable. Raised by risk-reviewer in PR #110 gate as [medium] advisory. | ops | 2026-05-21 | pr:#110 | P3 | hygiene |
| CC-211 | ⏸ deferred | **[v0.3.0 architecture epic]** Restructure pm-dispatch into a schema-first / state-first / adapter-thin PM runtime — four layers: `core/` (data + policy) → `runtime/` (`pmctl` spine) → `adapters/` (delivery) → `mcp/` (bridge, v0.4.0). Absorbs Multica / Memori / Superpowers / AI Night Shift concepts into one state substrate. Broken into milestones — live **M0–M6** in MILESTONES.md (synthesis §6 is the original M0–M5 cut); runtime is realized as `cli/pmctl` (not a `runtime/` dir). See docs/architecture/v0.3.0-synthesis.md **Conformance status** for as-built drift (codex+claude adapters shipped; state-first / `mcp/` still open). Umbrella epic for CC-229..CC-237 + existing CC-059/060/061/200-204/215/217-220. | arch/portability | 2026-05-21 | — | P1 | design |
| CC-215 | ⚠️ partial 2026-05-28 | **[pmctl — core CLI entrypoint]** Implement `cli/pmctl` as the language-agnostic runtime for pm-dispatch. Interface: `pmctl task create/claim/dispatch/status/review`, `pmctl decision add`, `pmctl backlog sync`, `pmctl trace tail`, `pmctl guard check --event <pre-write\|pre-bash\|post-task> --file/--command <val>`, `pmctl adapter generate <claude\|codex\|antigravity\|opencode>`. AI CLI adapters become thin wrappers: Claude `/pm task-123` → `pmctl task dispatch task-123 --agent claude`; Codex equivalent calls the same binary. Guard logic moves from Claude-only hooks into pmctl so any CLI without hook support can call `pmctl guard check` from a command wrapper or `pmctl safe-bash "cmd"`. Adapter generator (`pmctl adapter generate`) produces per-CLI config from core agent definitions — prevents 4-way drift. **Partial**: `adapter generate` (#171) + `dispatch run` stub shipped; `task`/`decision`/`backlog`/`guard`/`trace`/`safe-bash` unbuilt (see body). Depends on CC-211. | arch/portability | 2026-05-21 | pr:#171 | P2 | design |
| CC-216 | ⏸ deferred | **[MCP server — pm-dispatch-server]** **Deferred to v0.4.0**. (AS-BUILT 2026-05-31: the `mcp/README.md` spec originally planned for v0.3.0 was **not** written — `mcp/` is absent and `pmctl` has no general `--json`; the whole MCP surface incl. the spec is deferred. See synthesis Conformance status §B.) The server is built once `pmctl` is stable. Implement `mcp/pm-dispatch-server` exposing pm-dispatch operations as MCP tools: pm_list_tasks, pm_read_task, pm_create_task, pm_update_status, pm_add_decision, pm_request_review, pm_dispatch_to_agent, pm_read_trace, pm_guard_check. Enables Claude Code, OpenCode, Antigravity CLI, and any future MCP-capable AI tool to share one PM system without per-tool command wiring. MCP becomes the universal bridge; adapters handle only auth / config / format differences. Implementation path: thin Node.js or Python wrapper over pmctl subprocesses (avoids duplicating logic), or native bash MCP server once spec stabilises. Depends on CC-211, CC-215 (pmctl stable before wrapping). | arch/portability | 2026-05-21 | — | — | design |
| CC-220 | ⏸ deferred | **[spike agent + `/spike` skill]** Implement `agents/spike.md` and `commands/spike.md`. Spike agent is a **planner** (like `project-pm`): reads a BACKLOG spike ticket, plans 2–3 investigation angles, returns a `spike_plan` block; the **main thread** fans out one Agent per angle (subagents cannot spawn subagents); the spike agent is re-invoked to synthesise findings into `docs/spikes/CC-NNN.md` and update the `Result log`. Modeled on `/pr-gate`'s reviewer fan-out. v0.3.0 M5. Depends on CC-218. | process/DX | 2026-05-21 | — | P3 | design |
| CC-212 | ⏸ deferred | **[CC-207 advise follow-up]** `make_junction_windows()` 仍用 inline PowerShell 字串傳路徑（`-Path '$win_src' -Target '$win_dst'`），但 `remove_junction_windows()` 已改用 `PM_DISPATCH_RM_DST` env var；兩者路徑傳遞慣例不一致，且 inline 字串在路徑含單引號時會壞掉。修正：改用 `PM_DISPATCH_MAKE_SRC` / `PM_DISPATCH_MAKE_DST` env var 傳入，統一 PowerShell 邊界慣例。Raised by critic + architecture-reviewer in gate-20260521-115634 as [medium] advise. | ops/portability | 2026-05-21 | pr:#112 | P3 | oss |
| CC-213 | ⏸ deferred | **[CC-207 advise follow-up]** `install_dir_junction()` 的 idempotency 邏輯用 Bash `[[ -L "$dest_dir" ]]` + `readlink` 判斷已安裝 junction，但 PowerShell 建立的 Windows directory junction 在 Git Bash 下不一定呈現為 `-L`；重新執行 `bash install.sh` 可能把 junction 目錄誤認為真實目錄而 fallback 到 per-file copy 並覆蓋 manifest。修正：加 Windows-aware junction probe（讀 manifest `mode` 欄位作 idempotency 判斷，或 `powershell.exe [System.IO.File]::GetAttributes`）。Raised by critic + qa-tester in gate-20260521-115634 as [medium]. | ops/portability | 2026-05-21 | pr:#112 | P3 | oss |
| CC-214 | ⏸ deferred | **[CC-207 advise follow-up]** `docs/platform-support.md` 手動 uninstall 說明使用裸 `bash uninstall.sh`，在非 repo-root 工作目錄下執行會找不到腳本；應改為 `bash "${PM_DISPATCH_REPO}/uninstall.sh"` 形式（與文件其他範例一致）。Raised by critic in gate-20260521-115634 as [low] advise. | ops/DX | 2026-05-21 | pr:#112 | P3 | oss |
| CC-225 | ⏸ deferred | **[claude-executor result observability]** `claude-executor` task output 寫入 session-scoped `/tmp/` 路徑，不進 REPO、不可跨 session 回溯，且無法 git diff 追蹤執行歷史。設計目標：主線程在 claude-executor 完成後把 brief 路徑、result 摘要、exit status 寫入 REPO 固定目錄（格式與 `.gate-results/` 一致），作為 CC-211 / CC-216 MCP 架構抽離的前提。sub-concern of CC-211. | ops | 2026-05-22 | — | P3 | design |
| CC-226 | ⏸ deferred | **[lint-frontmatter: extract shared dq-escape validation helper]** `check_frontmatter()` 內有 4 個 collection branch 各自重複相同的 dq escape whitelist regex、adjacent-quote check、empty-entry check，未來修改一個 branch 容易遺漏其他三個，造成 parity gap。建議抽取成 shared bash helper，或以 parity test 確保 4 個 branch 永遠同步。Raised as [medium] advisory in gate-20260522-171123. | arch/reuse | 2026-05-22 | pr:#119 | P3 | oss |
| CC-227 | ⏸ deferred | **[lint-frontmatter: extract YAML subset parser into lib/yaml-frontmatter.sh]** `lint-frontmatter.sh` 同時包含 CLI 解析、frontmatter 邊界偵測、~150 行 YAML subset parser，三個職責混在同一檔案。建議將 `check_frontmatter()` 搬到 `scripts/lib/yaml-frontmatter.sh`，讓 `lint-frontmatter.sh` 成為薄 CLI 包裝，`doctor.sh` 可 source lib 取代 fork subprocess，與 CC-226 建議合併進行。User feedback after CC-058 gating. | arch/reuse | 2026-05-22 | pr:#119 | P3 | oss |
| CC-228 | ⏸ deferred | **[BACKLOG validator-debt cleanup]** `pm/scripts/validate.sh` exits 1 on `main` with ~31 pre-existing E-codes: E-INDEX-MISMATCH (CC-104d/e/f/g/j/k/m/r/s in index but no body section), E-AREA-ENUM (slash-combined / non-enum areas e.g. `arch`/`config`/`schema` on CC-052/060/104v/203/204), E-REFS-PREFIX (bare `CC-NNN` refs on CC-059/060/061/064/066). Resolve per class: add missing sections or drop index rows; widen the area enum (e.g. add `arch`) or rewrite rows; fix ref prefixes. Surfaced during CC-222 close-out. | process | 2026-05-22 | roadmap:CC-277 | P2 | hygiene |
| CC-234 | ⏸ deferred | **[v0.3.0 M4: memory v2 — event-derived]** Point `/mem-distill` at `events.jsonl` (the action stream) alongside `episodes.jsonl` — memory derived from what agents do (tool calls, decisions, gate verdicts), not just chat (Memori-inspired). Four-tier card system unchanged; gives the event tier a schema. | memory | 2026-05-22 | — | P2 | design |
| CC-235 | ⏸ deferred | **[v0.3.0 M4: tiered lifecycle gate]** Make the spec→design→plan discipline (today advisory in `commands/pre-impl.md` + `agents/project-pm.md`) a `pmctl`-enforced Task lifecycle gate **graded by task size** (mirrors the pr-gate express/standard/full tiers): trivial/mechanical → no gate; small → one-line intent+acceptance; substantial (≥3 behavioral units, or touches a shared module, or new interface) → full `/pre-impl` design artifact before `claimed→in-progress`. Superpowers-inspired. | process | 2026-05-22 | — | P2 | design |
| CC-236 | 🟢 someday | **[pmctl report — away-from-keyboard state roll-up]** A `pmctl report` rolling up state since last invocation (open tasks, blockers, last gate verdict, recent runs). Deprioritized 2026-05-22: the maintainer does not run agents unattended, so a "morning report" time-gap framing has low current need; on-demand status is already part of the `pmctl` surface (CC-215). Revisit if the workflow ever includes overnight / away dispatch. | ux | 2026-05-22 | — | — | design |
| CC-237 | ⏸ deferred | **[v0.3.0 M4: context-enricher baseline]** Implement the context-enricher baseline sources — rg / `git ls-files` / `git diff` / memory search — producing a context-pack (CC-232) before dispatch. codegraph is evaluated separately as the CC-209 spike. `pmctl context build`. | ux | 2026-05-22 | — | P3 | design |
| CC-238 | ⏸ deferred | **[/pr-gate claude-route fan-out hardening]** CC-217 made the `/pr-gate` claude-executor reviewer/synthesis fan-out run detached (`run_in_background`). Gate advisories on the new flow (CC-217 gate, gate-20260523): (a) no timeout/fallback if a reviewer agent never reports completion → indefinite wait; (b) single fan-out step weakens per-reviewer failure attribution on partial failure; (c) no test artifact validates background completion / relay ordering. Add a completion timeout + partial-failure attribution + test coverage for the claude-route fan-out. | gate | 2026-05-23 | pr:#124 | P3 | oss |
| CC-239 | ⏸ deferred | **[reuse-scan capability]** New work keeps duplicating existing helpers / scripts / patterns (the recurring CC-200..204 reuse debt) because nothing surfaces "this already exists" before a brief is written. A dedicated reuse/refactor *agent* was considered and rejected (subagents cannot dispatch → it would only duplicate `project-pm`; refactor is not a distinct cognitive mode; refactor expertise already lives in architecture/risk/critic reviewers + the `dispatch-brief.md` refactor skeleton). The right shape is a **reuse-scan capability** invoked during PM briefing — queries the codebase for prior art and emits a reuse report the brief incorporates. Builds on CC-232 / CC-237 / CC-061. | reuse | 2026-05-23 | — | P3 | design |
| CC-240 | ⏸ deferred | **[test-suite reliability follow-ups]** Part (a) — suite-count derivation in `scripts/test-run-all-tests.sh` — closed via CC-219 (pr:#129). Remaining: `[low]` `scripts/test-portable.sh::case_mkdir_lock_contention` holds the lock with a fixed `sleep 1.2` (pre-existing; conflicts with the qa AGENT.md red line on `sleep` for async sync) → CI-timing flakiness. Fix with an IPC / event-driven lock-hold. | test | 2026-05-23 | pr:#127 | P3 | oss |
| CC-244 | 🟢 someday | **[Typed artifact pipeline — spike → brief → handover schema]** Define `spike_v1` schema mirroring existing `dispatch_handover_v1`: frontmatter (`spike_id`, `status`, `decisions_resolved`, `branch_base`, `ticket_ids_consumed`, `project_tooling`) + named sections (`scope`, `findings`, `constraints`, `decisions`, `phase3_handover`). Add `scripts/spike-validate.sh` (mirror `handover-validate.sh`) + `scripts/gen-brief-from-spike.sh` (mechanical brief extraction). Reduces main-thread courier cost, makes spike→brief authoring mechanical, gives invariant checkpoints (`decisions_resolved=true` ⇒ no re-asking Q1/Q2). Defer until 3+ spike docs exist and the brief-extraction pattern repeats; only one spike (CC-060) today, so schema would be premature overhead. CC-243 field names chosen to align with this future schema (no re-wash needed at upgrade time). | arch | 2026-05-23 | — | — | design |
| CC-224 | ⏸ deferred | **[shared hook-profile inventory: doctor.sh ↔ install-hooks.sh]** `doctor.sh` owns a second hardcoded minimal/full hook membership model alongside `install-hooks.sh`, creating a silent drift path when hooks are added or profile semantics change. Extract the hook-profile list into a shared shell helper (e.g. `scripts/hook-profile.sh`) or add a parity test asserting both files expect the same hook set. Raised by critic + architecture-reviewer as [medium] advise in gate-20260522-100348. | arch/reuse | 2026-05-22 | — | P3 | oss |
| CC-054 | ⏸ deferred | CC-025 M2 — `/skill-refine` diff generation and Claude-assisted refinement；scope deferred when CC-025b was closed in `feat/cc039-cc025b-v2` | ux/memory | 2026-05-18 | pr:#67 | — | — |
| CC-062 | ⏸ deferred | codex-bash-guard policy test matrix：建立 `tests/policy/codex-bash-guard/` 結構化 allow/deny JSON fixtures；讓安全 policy 從「很聰明的 shell parser」變「可驗證的 test matrix」 | ops/security | 2026-05-18 | — | — | — |
| CC-063 | 🟡 deferred | Trace / token / gate metrics dashboard：`.agent-trace/*.jsonl` + `rate-limits*.json` + `.gate-results/*.md` 已有足夠資料；可視化 per-session token、gate pass rate、routing_log 校準趨勢 | ux/ops | 2026-05-18 | — | P3 | — |
| CC-064 | 🟡 deferred | **[P2]** Project bootstrap wizard：互動式 `scripts/setup-project.sh --init` 引導新 repo 建立 memory、rules、PM schema；取代目前「手讀 GETTING_STARTED.md 再手跑指令」流程 | ux | 2026-05-18 | roadmap:CC-031 | P2 | — |
| CC-065 | 🟡 deferred | Per-repo configurable gate pipeline：不同 repo 可設定不同 reviewer 組合與 tier 預設（例如 `.pm-dispatch/gate.toml`）；現在所有 repo 共用同一 gate config | ops/gate | 2026-05-18 | — | P3 | — |
| CC-066 | 🟡 deferred | Declarative `policy.yml` for hook allowlist：把 `hook-codex-bash-guard.sh` 的允許/拒絕清單從 shell logic 抽成 `config/policy.yml`；hook 讀 policy 而非 hardcode；可 per-repo override | arch/security | 2026-05-18 | roadmap:CC-204 | P3 | design |
| CC-253 | 🔵 active | **[CC-209 Phase 2: codegraph benchmark on representative target codebase]** Phase 1 (PR #151) verdict AMBER — codegraph install ✓ license MIT ✓ API ✓, but pm-dispatch (bash/markdown) isn't a valid test target (`62 unsupported language`). Phase 2 re-scope: user picks a TS/JS/Python/Go target codebase at brief time, index it via codegraph, run 3 representative queries against rg/git baseline, measure token + latency delta. Output: append `## Phase 2` section to `docs/spikes/cc209-codegraph-phase1.md` OR new sibling doc. Verdict per original CC-209 ticket: adopt / defer / reject for context-pack source (CC-232 / CC-237). | ops/token | 2026-05-24 | pr:TBD | P3 | spike |
| CC-255 | 🔵 active | **[Spike infrastructure: rubric + brief template improvements]** PR #151 codegraph Phase 1 surfaced 2 spike-infra gaps that misled codex: (a) verdict rubric must enumerate sandbox-block as a "local env" example alongside peerDep (codex misapplied RED criterion because sandbox isolation wasn't an explicit local-env class in the rubric); (b) spike brief template must specify test target as a separate field from working directory — when target language-aware tools (e.g. codegraph) are evaluated, the brief must commit to a representative target codebase, not let codex pick on its own (Phase 1 brief said "pick a symbol in pm-dispatch" which pre-committed wrong target). Touch points: `/tmp/cc<NNN>-content/verdict-rubric.md` templates, `docs/spikes/README.md` skeleton, `docs/dispatch-brief.md` schema add optional `test_target:` field for spike briefs. | process | 2026-05-24 | pr:TBD | P3 | spike |
| CC-258 | ⏸ deferred | **[pm-write-guard hook policy revision]** Current `scripts/hook-pm-write-guard.sh` denies 3 legitimate PM-author patterns (12/207 deny audit hits over 10 days): (A) `/tmp/<task-slug>/*.md` verbatim-as-attached-file (Pattern 2 of `[[feedback_codex_brief_discipline]]`), (B) `<repo>/docs/spikes/{CC-NNN*,*-scope,*-rfc}.md` PM-author surface, (C) memory writes that resolve through the `memory-private/` symlink (`realpath_m` chases the symlink before the allow-pattern match — hook bug). Three new allow rules + `realpath_m_lex` (or `-s`) helper + ~15 new test cases in `scripts/test-hooks.sh`. Not blocking M1; deferred until user prioritizes. | process | 2026-05-24 | pr:#156 | P3 | hygiene |
| CC-259 | 🟢 someday | **[yaml.sh lib extraction]** Extract `_yaml_get` bash/awk helper and `case_yaml_parse` structural validator from `scripts/test-core-schemas.sh` into `scripts/lib/yaml.sh` for reuse across test scripts; add independent test file `scripts/test-yaml-lib.sh` and wire into `run-all-tests.sh` + CI. Currently only used in `test-core-schemas.sh`; extraction deferred from CC-229 M1 PR to reduce gate surface. Trigger: second consumer in a new test script. | ops/test | 2026-05-25 | pr:TBD | P3 | — |
| CC-268 | 🟡 deferred | **[docs: run_in_background default async escalation undocumented]** Agent tool 未設 `run_in_background:true` 時，harness 可能靜默升格為 async 並回傳 `Async agent launched successfully`（codex-executor 已觀察到此行為）。需文件化哪些 subagent 類型永遠 async、預設行為保證。| docs/DX | 2026-05-28 | — | P3 | — |
| CC-269 | 🟡 deferred | **[ops: pm-dispatch hook-save-rate-limits.sh 應寫到自己的 state 路徑]** 目前 `scripts/hook-save-rate-limits.sh` 寫到 `~/.claude/rate-limits.json`，與 claude-account-switcher 等其他工具使用同一檔名，造成多工具衝突。應改寫到 `~/.local/share/pm-dispatch/state/rate-limits.json`（對齊 CC-230 state store 位置），並同步更新所有讀取此路徑的腳本。 | ops/install | 2026-05-28 | — | P3 | — |
| CC-270 | 🟡 deferred | **[test: concurrent pmctl adapter generate guard]** Two simultaneous `pmctl adapter generate <same-name>` runs can race: the precheck+mkdir+trap sequence is not atomic. Blast radius: one run may delete another's partial output; reproducible by deleting `adapters/<name>` and rerunning. Deferred — single-developer workflow makes this low-probability; fix with atomic mkdir using `mkdir` exit-code guard when needed. | test/ops | 2026-05-28 | — | P3 | — |
| CC-272 | 🟡 deferred | **[process: brief template — omit commit block; document main-thread commit delegation]** 每個 brief 末尾的 `git add + git commit` 均被 `hook-codex-bash-guard` 擋住，executor 回報 `status: partial`（即使程式碼正確），主線程每次都必須手動 commit。推薦 Option A：從 brief template 移除 commit block，在 `docs/dispatch-brief.md` 明文「commit 永遠委派主線程」。Option B：hook allowlist 加入無破壞性 git add/commit。 | process/DX | 2026-05-28 | — | P2 | — |
| CC-273 | 🟡 deferred | **[arch: unified lifecycle hook event spec]** CC-206 只在 gate 層加了 pre/post-gate hooks。如果未來多個工具（dispatch、validate 等）都需要 hook 點，應定義統一的 lifecycle event 命名規範（如 `.pm-dispatch/hooks/<event>.sh`）和呼叫合約，而非在每個腳本各自加 pre/post block。目前無需求，等有第二個 hook 點需求時再設計。 | arch/gate | 2026-05-28 | — | P3 | — |
| CC-276 | 🟡 deferred | **[feat: persistent gate override declarations]** 每輪 gate 重開 fresh session，已接受的 risk override 必須重新聲明。支援 `--override-file` 或自動探索 `.gate-overrides.md`，inject 到 reviewer prompt 前置脈絡，避免已接受的 block 重複出現。 | gate/process | 2026-05-29 | — | P2 | — |
| CC-285 | 🟡 deferred | **[archiver safe-drop: don't drop a terminal row whose body exists nowhere]** `scripts/archive-closed-backlog.sh` currently drops a terminal index row even when no body section exists in BACKLOG.md and none is in BACKLOG-ARCHIVE.md (warns to stderr). In a valid backlog `validate.sh`'s index↔body 1:1 invariant prevents this, and it is git-recoverable — recorded as accepted tradeoff in DECISIONS 2026-05-30. Defense-in-depth follow-up: keep the row + emit a loud warning when the body is in neither file, leaving it for manual reconciliation rather than removing it. Surfaced by pr-gate critic on #186. | ops | 2026-05-30 | — | P3 | hygiene |
| CC-286 | 🟡 deferred | **[pmctl: prefix-generic next-id derivation]** `scripts/pm-prep-snapshot.sh` derives `backlog_next_id` CC-only (it emits `CC-NNN`); under the working-set contract it scans BACKLOG.md + BACKLOG-ARCHIVE.md for the max, but only `CC-` IDs. A cross-repo next-id (other prefixes: JS-, PA-) must be prefix-derived and centralized in pmctl, scanning both working-set and archive. Retire pm-prep-snapshot's CC-hardcoded derivation when `pmctl backlog`/next-id lands. Surfaced by pr-gate critic+architecture on #186. | arch | 2026-05-30 | — | P3 | design |
| CC-296 | 🟡 deferred | **[chore: v0.3.0 deprecation sunset — remove after 2 official releases]** 移除 v0.3.0 引入的 deprecated 面，sunset 目標 **v0.5.0**（經 v0.3.0 + v0.4.0 兩個正式版本後）。(1) `pmctl guard check --profile pm/codex/claude` 別名 → 全部 caller 改 `--role`/`--runtime`，移除 alias + deprecation warning + back-compat 測試（[[CC-291]]）。(2) `scripts/codex-dispatch.sh` 相容 symlink shim → 真正 adapter 是 `adapters/codex/dispatch.sh`，移除 shim 並遷移外部 caller（[[CC-289]]）。Gate 在 release ≥ v0.5.0 才執行；屆時複查是否有其他 v0.3.0 deprecation 需一併清。User-requested 2026-06-01。關聯 [[CC-291]]、[[CC-289]]。 | release | 2026-06-01 | — | P2 | hygiene |
| CC-306 | 🟡 deferred | **[arch: extend CC-233 layer enforcer to runtime-named data paths in scripts/]** Guard against re-introducing `.codex-*`/`.claude-*` DATA directories under scripts/ (the optional follow-up deferred from CC-298). | arch | 2026-06-01 | — | P3 | design |
| CC-307 | 🟡 deferred | **[arch: pm role cross-runtime — guard 已 runtime-agnostic，但文件與 alias 仍暗示 pm = claude-only]** CC-291 的兩軸設計（role ⊥ runtime）明確要求 pm guard policy 不能綁 runtime。`hook-pm-write-guard.sh` 確實 runtime-agnostic（任何 runtime 套用同一規則）✓，且 `--role pm --runtime codex` CLI 路徑已可正常呼叫 ✓；但目前三個地方仍暗示 pm=claude-only：(1) deprecated `--profile pm` alias hardcode `runtime="claude"`，(2) `scripts/lib/pmctl-guard.sh` 說明說「currently claude-only」，(3) 無 codex-as-pm dispatch end-to-end 測試。修法：(1) alias 部分接受（deprecated, 將由 CC-296 移除，hardcode 是 convenience 不是設計限制）；(2) 把「currently claude-only」說明改為「guard policy is runtime-agnostic; no deployed codex-as-pm use case yet」以分清設計與現況；(3) 加 integration smoke test：`pmctl dispatch run --adapter codex --role pm` 可成功 dispatch。Origin user 2026-06-02。關聯 [[CC-291]]（two-axis design）、[[CC-296]]（alias sunset）、[[CC-215]]（pmctl dispatch run）。 | arch | 2026-06-02 | — | P3 | design |
| CC-314 | ✅ closed 2026-06-05 | **[arch: routing_log → events.jsonl migration + deprecate machine-write]** 新增 routing_log→events 遷移 + kind 映射（bash-dispatch/agent-dispatch → run.dispatched 等）+ subject-id 策略；停掉 `hook-routing-log.sh` 機器寫；舊 `migrate-routing-log.sh` 降為 legacy-markdown cleanup。見 §10.A6（D3）。 | arch | 2026-06-03 | pr:#234 | P2 | design |
| CC-315 | ✅ closed 2026-06-06 | **[arch: state read/query contract + pmctl trace]** pmctl 提供 by id/task/kind/time-window 讀取；定義 active+archive 讀取語義（排序 / 壞行容忍 / time-window / 索引 vs 串流）；`pmctl trace` 為第一個 state consumer。見 §3.7（D6）。 | arch | 2026-06-03 | pr:#237 | P2 | design |
| CC-316 | ✅ closed 2026-06-06 | **[arch: state store rotation impl]** 依 `layout.yaml` 把 runs/events rotate 成 `archive/*-$YYYYMM-NNNN.jsonl.gz`（月內加單調 segment 後綴避免碰撞）；reader 合併 active+archive。見 §3.8 / §10.B（D7）。 | arch | 2026-06-03 | pr:#238 | P2 | design |
| CC-317 | ✅ closed 2026-06-06 | **[arch: state store safety & robustness hardening]** store-root 安全（canonicalize / 拒 symlink-component / world-writable / 0700）；mkdir-lock stale-owner 協定（pid/host/trap/bounded reclaim）+ UNC/9P preflight warn；`layout.yaml` 成可執行真相源（writer/reader 消費 或 golden test）。見 §10.B。 | arch | 2026-06-03 | pr:#239 | P2 | design |
| CC-321 | 🔵 active | **[refactor: rename CLAUDE_HOOK_* env vars to PM_HOOK_* for executor-agnostic naming]** pm-dispatch 的 hook 設定 env var（`CLAUDE_HOOK_CODEX_READ_ROOTS`、`CLAUDE_HOOK_CODEX_GUARD`、`CLAUDE_HOOK_PM_GUARD`、`CLAUDE_HOOK_REVIEWER_GUARD` 等）都冠 `CLAUDE_` 前綴，與 executor-agnostic 目標不符。改為 `PM_HOOK_` 前綴；舊名保留為 deprecated alias 一個 release 後移除。需同步更新 install-hooks.sh、test-hooks.sh、test-pmctl-guard.sh 及文件。Breaking change — 獨立 PR。 | ops | 2026-06-04 | — | P2 | hygiene |
| CC-322 | ✅ closed 2026-06-05 | **[docs: review-model.md — Relocating Rigor 哲學文件]** 把「嚴謹搬家」正式定名為 pm-dispatch Review Model：四層 = 上游 intention review → cross-context isolation → 下游 conceptual map → machine verification。連結 CONCEPTS.md / dispatch-brief.md / pr-gate-handover-schema.md。不改任何腳本或 skill。 | docs | 2026-06-05 | pr:#236 | P2 | design |
| CC-323 | ✅ closed 2026-06-07 | **[skill: 強化 /pre-impl 輸出 contract — Intention + Conceptual Map 必填]** 升級 `/pre-impl` 為架構影響任務的強制上游關卡：固定輸出 sections（Intention / Non-goals / Bounded Context / Conceptual Map / Acceptance Metrics / Verification Plan）；`/pm` 路由對 `behavioral_units ≥ 3` 或 `architecture_impact ≠ none` 自動要求先跑。 | process | 2026-06-05 | pr:#TBD | P2 | design |
| CC-324 | ✅ closed 2026-06-07 | **[schema: dispatch brief 新增 conceptual_map + architecture_impact 欄位]** brief schema 加 `architecture_impact: none\|minor\|major` + `conceptual_map`（`major` 時必填）；conceptual_map 優先給 architecture-reviewer 用，而非直接掃 source diff。連結 CC-323 / CC-325 / CC-326。 | docs | 2026-06-05 | pr:#TBD | P2 | design |
| CC-325 | ✅ closed 2026-06-07 | **[infra: brief-validate 強化 — Acceptance Metrics + conceptual_map 品質機器檢查]** 新增品質規則：acceptance 含空泛語則 WARN；file-writing task 無 `cmd:` self_verify 則 FAIL；`behavioral_units ≥ 3` 無 qa_checklist 則 WARN；`architecture_impact: major` 無 conceptual_map 則 FAIL；新增 10 個對應測試 cases（32/32 pass）。 | ops | 2026-06-05 | pr:#TBD | P2 | design |
| CC-326 | ✅ closed 2026-06-07 | **[agent: 更新 architecture-reviewer prompt — Conceptual Map 優先於 source diff]** reviewer 策略改為：(1) 優先讀 conceptual_map；(2) 確認 bounded context / layer boundary；(3) 只在 map 與 diff 不一致、risk surface 需抽查、architecture_impact:major 等情境才看 source files（selectively，非 only）。 | docs | 2026-06-05 | pr:#TBD | P3 | — |
| CC-327 | ✅ closed 2026-06-07 | **[pr-gate: tier 定義改為 rigor level]** 重新定義 express / standard / full 語意；`--brief <file>` 選項讀 architecture_impact 做 tier 建議（advisory，永遠允許 override）；docs/review-model.md + skills/pr-gate-review/SKILL.md 對應更新。 | gate | 2026-06-05 | pr:#TBD | P3 | — |
| CC-328 | 🟢 someday | **[spike: lightweight built-in symbol index for context-pack（standard Unix toolchain only）]** 在 v0.4.0 state-first 地基落地後，以 Bash + awk/sed/grep/find + sqlite3 實作 repo 持久化 symbol index，讓 dispatch 前能產出低 token、高相關度的 context pack，減少 subagent 重複 grep/read。定位介於 CC-237（context-enricher interface）與 CC-209（codegraph external tool）之間——內建 layer，不依賴外部 binary。External backend（ctags / ffts-grep / tree-sitter）作為 optional 加速層，不列入 MVP scope。 | ops/token | 2026-06-05 | — | P3 | design |
| CC-329 | 🟢 someday | **[agent: debt-auditor — proactive tech-debt health scan on living code]** 新增 `agents/debt-auditor.md`：對指定 codebase 區域（目錄 / module）做主動技術債健康掃描，不需要 PR 觸發。輸出是按優先序排列的債務清單（重複、慣例分歧、過早抽象、缺少測試的不變量），含位置、影響、建議修法、預估規模。定位為**真正新的認知模式**（proactive health assessment），有別於所有現有 reviewer（全部 PR-diff focused）。由 `pmctl audit <path>` 或 `/audit` skill 呼叫；隔離執行確保不受進行中任務錨定。 | process/DX | 2026-06-05 | — | P3 | design |
| CC-330 | 🟢 someday | **[skill: /discover — milestone seeder + opportunity scanner]** 新增 `commands/discover.md`：以「發散模式」呼叫 project-pm，讀取 backlog（someday+deferred 項目）+ DECISIONS + MILESTONES + 近期 git activity，輸出高槓桿機會清單（含問題、why、預估規模）。定位為 brainstorm/ideation 的正確形狀——利用 PM 的既有 context 而非隔離，避免重新推導已有的設計決策。用於「v0.X.0 milestone 規劃前想知道可以做什麼」的發散探索。 | process/DX | 2026-06-05 | — | P3 | design |
| CC-332 | ✅ closed 2026-06-05 | **[docs/process: PM size-first dispatch routing policy]** 依任務大小決定 route：Tiny → 主線程 inline（不派發）；Small → `model: light`（codex-spark / haiku）；Medium/Large → Codex default。更新 `docs/model-tier-policy.md` §Implementation tasks 為 size-first 路由表，並對應更新 `agents/project-pm.md` Dispatch model selection，讓 PM 對 Tiny 建議 inline（不寫 brief），Small 寫 `model: light` brief。 | docs/process | 2026-06-05 | pr:#236 | P2 | hygiene |

---

## Convention

**ID scheme**: `CC-NNN` sequential. ID gaps are normal — use the `epic` column (see `pm/schema.md §2.4.5`) for semantic grouping instead of ID ranges. The `CC-1NN`/`CC-2NN` range-reservation convention is deprecated (see `DECISIONS.md#2026-05-19-deprecate-id-gap-convention`).

**Sub-letter IDs**: `CC-NNNa`, `CC-NNNb`, `CC-NNNc` are follow-up tickets to a parent `CC-NNN`, with independent lifecycles.

**Status legend**:
- `🔵 active` — in backlog (not-started / in-progress / blocked)
- `✅ closed YYYY-MM-DD` — shipped; body collapsed to closed stub
- `🚫 dropped YYYY-MM-DD` — will not do; body stubs to DECISIONS
- `✅ done` — soft-close; no PR or date needed
- `⏸ deferred` / `🟡 deferred` — waiting on external condition, not scheduled
- `🟢 someday` — valid idea, no expected schedule
- `🟢 superseded YYYY-MM-DD` — superseded by a later item; body stubs to successor CC-NNN
- `⚠️ partial YYYY-MM-DD` — partially shipped; sub-items remain open (see body)

**Closed stubs**: When inflation policy triggers, closed bodies move to `BACKLOG-ARCHIVE.md`; index row + `**See**: BACKLOG-ARCHIVE.md` stub remain here.

**Priority column**: `P1`（本週必做）/ `P2`（本 sprint）/ `P3`（排隊）/ `—`（未設）。
**Epic column**: `oss`（CC-OSS 公開源碼系列）/ `reuse-debt`（技術債重用）/ `hygiene`（流程維護）/ `design`（新功能架構設計與 interface 決策）/ `spike`（調查類任務）/ `—`（其他）。
向下相容：v1.1/v1.2 file 中缺此兩欄的列只 emit 警告（不阻斷 gate）。

<!-- archived stubs — full text in BACKLOG-ARCHIVE.md -->

## CC-104o — Windows Store python3 stub (superseded by CC-104t)

**See**: CC-104t

## CC-003 — parallel-gate artifact-ignore 前置檢查

**Problem**: scripts/pr-gate.sh parallel mode 在 line 410/414 對 git status --porcelain 取 fingerprint，但 fingerprint 取樣後 gate 本身會寫入 .agent-trace/ / .gate-briefs/ / .gate-results/。若 target repo 沒跑過 setup-project.sh 或這三個路徑未在 .gitignore，gate 自己的寫入就會改動 status hash，觸發 line 575 的 fail-closed integrity check，在原本健康的 repo 卡住 PR review。
**Why**: parallel mode 整體假設「gate 執行期間 git status 不會被 gate 自己污染」。這假設只在 .gitignore 已含三個 artifact 路徑時成立，但 setup-project.sh 是否跑過、是否完整，gate 沒有 preflight 驗證。Cross-reviewer overlap (qa-tester + risk-reviewer 同點)，代表不是單一 reviewer 視角偏見。Loud + reversible (不會默默過 gate)，但屬於把工作流卡死的 ops 問題。
**Requirement**: parallel mode 啟動時必須能在 target repo 確認 gate artifact 路徑已被 ignore，或結構性排除這些路徑使其不影響 integrity check。可接受任一方向：preflight ignore-coverage 檢查（缺則明確指引跑 setup-project.sh）；或 integrity check 計算 status hash 時排除 known gate artifact paths；或文件 + test 明示 setup-project.sh 是 parallel mode precondition，並讓未滿足時的失敗訊息直接指向修復步驟。

## CC-004 — test-pr-gate.sh docstring 格式統一

**Problem**: scripts/test-pr-gate.sh 新增的 shell test functions 使用散文註解描述行為，而非 pm-schema 規範的 structured behavior/Steps docstring 形式。
**Why**: tests 本身 behavior-named、deterministic，功能無虞，純為 audit-quality / 一致性問題。長期會讓新人讀測試時樣式不一。
**Requirement**: 把新增 test functions 的開頭註解改寫成與既有 hook tests 一致的 behavior/Steps docstring 結構。不改測試邏輯。

## CC-011 — sync-memory.sh + 跨裝置共用（deferred）

**Problem**: `~/.claude/projects/*/memory/` 為本機路徑，多台電腦之間 memory 各自獨立，無法共用。
**Why**: 用戶目前不急，但設計上若以 symlink 指向 Dropbox/iCloud/OneDrive 資料夾，可以零維護代價實現跨裝置共用，且完全相容現有 file-based memory 架構。
**Requirement**: `scripts/sync-memory.sh --setup <cloud-path>` 把 memory 資料夾 symlink 到雲端同步路徑；`install.sh` 加入 opt-in 步驟。
**Status note (CC-050 audit 2026-05-18)**: Downgraded from ⏸ deferred to 🟢 someday — concept valid, no active plan. Re-evaluate if cross-device sync interest grows.

## CC-012 — SessionStart hook pull memory（deferred）

**Problem**: 若多台電腦透過 CC-011 共用同一雲端 memory 資料夾，session 啟動時不保證已取得最新版本。
**Why**: 輕量方式是 SessionStart hook 觸發一次 rsync/git pull，確保 memory 是最新版。
**Requirement**: `scripts/hook-sync-memory.sh` SessionStart hook；支援 git pull 和 rsync 兩種模式；失敗時靜默降級。
**Note**: 依賴 CC-011。
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

## CC-018 — Codex quota 自動追蹤

**Problem**: CC-006 解決了 Claude 5h rate-limit 自動讀取，但 Codex 無等效 hook 機制；目前 Codex 使用量只靠 `log-usage.sh` 手動寫入，用戶無法即時得知剩餘額度。
**Why**: Codex 走 OpenAI API 路徑，quota 資訊需要主動查詢（response header 或 `/v1/organization/usage`），架構不同於 Claude StatusLine hook。
**Requirement**:
1. 研究 Codex API response headers（`x-ratelimit-remaining-requests` / `x-ratelimit-remaining-tokens`）
2. 若有：`scripts/codex-dispatch.sh` dispatch 後解析 headers，寫入 `~/.claude/rate-limits-codex.json`
3. 若無：呼叫 `/v1/organization/usage` 或記錄技術限制
4. `token-usage.sh` 加入 Codex pool 剩餘顯示
**Note**: 實作前需先手動驗證 Codex API header 行為。

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

## CC-044 — `tool-trace.jsonl` rotation/retention policy upgrade（deferred）

**Current baseline (shipped in CC-027)**: 4 MiB single-archive rotation — when `tool-trace.jsonl` exceeds 4 MiB, it is renamed to `tool-trace.jsonl.1` (overwriting any prior `.1`) and a fresh main file is started. Retention semantics: "current file plus one overwritten archive". Constant-time stat check, non-blocking on rotation failure.
**Problem**: The 4 MiB single-archive baseline bounds growth (clears the unbounded-growth risk) but overwrites prior trace history on each rotation. For long-running projects or post-hoc analysis of CC-025/CC-026 signals, multi-window retention may be needed.
**Why**: Multi-tier retention needs a separate design choice: retain by last N sessions, gzip/archive windows, or time-based eviction. The MVP baseline keeps blast radius low while CC-025/026 consumers are not yet implemented.
**Requirement**: Design and implement the upgrade from "current + one overwritten archive" to a multi-window retention policy (proposal: N rotated archives with gzip, or daily archive directory). Include tests for boundary behavior, archive integrity, and non-blocking failure.
**Source**: 2026-05-15 CC-027 implementation brief + PR-gate critic/arch/risk advise on rotation/retention contract clarification.

## CC-027b — `tool-trace.jsonl` health signal（deferred）

**Problem**: Trace collection failures are currently best-effort and audit-only. If append, parse, or rotation problems persist, downstream CC-025/CC-026 workflows may read incomplete `tool-trace.jsonl` data without a visible warning.
**Why**: The hook must stay non-blocking, but silent long-term degradation makes later skill-refine / skill-distill signals unreliable. A bounded local error counter can preserve non-blocking behavior while surfacing sustained failure to downstream commands.
**Requirement**: Add a bounded error counter for `tool-trace.jsonl` health and have downstream commands surface a warning when the error count exceeds N. Keep hook execution non-blocking and cap any health-state file growth.
**Source**: `2026-05-15 CC-027 PR-gate risk-reviewer finding`.

## CC-027c — `hook-tool-trace.sh` strict JSON validation（deferred）

**Problem**: Brace-shaped malformed JSON (e.g. `{"cwd":"/x","tool_name":"Bash","tool_input":{` truncated mid-object) can pass the bash brace heuristic and produce a garbage line in `tool-trace.jsonl`. Identified by critic + qa-tester in CC-027 PR-gate.
**Why**: Strict validation via inline `jq -e .` costs ~25ms/call subprocess startup on this host — alone exceeds the entire per-call budget (8.2ms baseline). Inline strict mode is structurally incompatible with the hook performance contract.
**Requirement**: Explore async post-validation path: append first (non-blocking), validate sampled fraction asynchronously, or move strict validation to the downstream consumer (CC-025/026) where 25ms/call is amortized over rare reads instead of every tool invocation.
**Note**: Garbage line is data-quality concern only — no security/risk vector (the garbage doesn't leak content, doesn't crash, downstream consumers can skip malformed lines defensively).
**Source**: `2026-05-15 CC-027 PR-gate critic + qa-tester findings`.

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

## CC-062 — codex-bash-guard policy test matrix

**Problem**: `hook-codex-bash-guard.sh` 的允許/拒絕邏輯非常複雜（newline 檢查、quote 檢查、shell metacharacters、background mode、git form allowlist、read path allowlist）。目前有 test-hooks.sh 的整合測試，但沒有結構化的 per-rule fixtures；policy 改動的影響面不透明。
**Why**: shell-based policy parser 有兩種失效模式：過度阻擋合法工作流，以及漏過某些 bypass。只有可讀的 allow/deny test matrix 能讓安全 policy 從「很聰明」變「可驗證」。
**Requirement**: 建立 `tests/policy/codex-bash-guard/` 目錄，以 JSON fixtures（每個 fixture 含 `input`、`expected: allow|deny`、`reason`）描述每條規則的 allow 和 deny case；`scripts/test-codex-bash-guard.sh` 讀 fixtures 執行；CI 加入此 job。

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

## CC-066 — [P2] Declarative policy.yml for hook allowlist

**Problem**: `hook-codex-bash-guard.sh` 的 git allowlist、read path allowlist、shell metacharacter blocklist 等 policy 直接寫在 shell script 邏輯中；per-repo override 不可能，policy 審計需要讀 shell code。
**Why**: policy-as-code 優於 policy-in-code：可 diff、可 review、可 override、可 lint。CC-204（hook framework reuse）完成後這條的實作成本大幅下降。
**Requirement**: `config/policy.yml`（repo 級預設）+ `~/.pm-dispatch/policy.yml`（user override）定義 git allowlist / read roots / metachar blocklist；hook 腳本 load + merge policy；CC-062 test matrix 讀 policy fixtures。依賴 CC-062、CC-204。

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

## CC-212 — `make_junction_windows()` env-var path-passing standardization（deferred）

**Problem**: `make_junction_windows()` passes the source and destination paths as inline PowerShell
command-string arguments (`-Path '$win_src' -Target '$win_dst'`), but `remove_junction_windows()`
already uses `PM_DISPATCH_RM_DST` env var. Paths containing single quotes break the inline form.
Two different conventions in the same portability layer increase maintenance risk.

**Why**: Raised by critic (path quoting) and architecture-reviewer (convention inconsistency) in
gate-20260521-115634 as [medium] advise on PR #112.

**Requirement**: Replace inline PowerShell path arguments in `make_junction_windows()` with
`PM_DISPATCH_MAKE_SRC` and `PM_DISPATCH_MAKE_DST` env vars (matching the pattern already
used by `remove_junction_windows()`). Update `test_install_dir_junction_manifest_entry` fake
powershell.exe to assert both env vars.

**Complements**: CC-207 (parent), CC-213 (idempotency).

**Priority**: P3.

## CC-213 — `install_dir_junction()` Windows-aware idempotency probe（deferred）

**Problem**: The idempotent reinstall path checks `[[ -L "$dest_dir" ]]` + `readlink` to detect
an already-installed junction, but PowerShell-created Windows directory junctions may not appear
as `-L` in Git Bash (reparse points vs. Unix symlinks). A second `bash install.sh` run could
therefore treat the junction directory as a real directory, fall back to per-file copy, and
flush a manifest without the `junction` mode entry.

**Why**: Windows real-device verification confirmed idempotency passes in practice (PR #112), but
the `-L` assumption was flagged as insufficiently proven by critic + qa-tester in gate-20260521-115634
as [medium]. The QA block was overridden with Windows dogfood evidence; this ticket captures the
remaining automation gap.

**Requirement**: Add a manifest-driven idempotency probe: before the `-L` check, read the
existing manifest for the entry's `mode` field; if `mode == "junction"` treat the destination as
an existing junction regardless of whether Bash `-L` fires. Add a focused test that exercises
the "manifest says junction, `-L` is false" branch.

**Complements**: CC-207 (parent), CC-212 (path-passing).

**Priority**: P3.

## CC-214 — platform-support.md manual uninstall command anchoring（deferred）

**Problem**: The manual uninstall warning in `docs/platform-support.md` uses `bash uninstall.sh`
without anchoring to the repo path; running it from any other working directory silently fails.

**Why**: Raised by critic in gate-20260521-115634 as [low] advise. Other examples in the same
document already use the `"${PM_DISPATCH_REPO}/uninstall.sh"` form.

**Requirement**: Replace the bare `bash uninstall.sh` in the Windows uninstall warning block with
`bash "${PM_DISPATCH_REPO}/uninstall.sh"` (one-line change).

**Priority**: P3 — tiny fix, fold into next docs PR.

## CC-215 — pmctl — core CLI entrypoint（⚠️ partial）

**Status (2026-05-30)**: `cli/pmctl` exists as a thin spine. **Shipped**: `adapter generate <claude|codex|antigravity|opencode>` (PR #171, real, via `scripts/lib/pmctl-adapter.sh`) + `dispatch run` (stub — prints a trace line, runtime not wired). **Open**: `task create/claim/dispatch/status/review`, `decision add`, `backlog sync/view`, `trace tail`, `guard check`, `safe-bash` — none implemented. The M2-extracted libs (executor-router CC-200, handover-validate CC-202, hook-framework CC-204) are NOT yet wired into pmctl subcommands. This remainder is not currently placed in any milestone (M3 table omits it); needs a v0.3.0-vs-v0.4.0 scope decision. Per the 2026-05-30 Phase-2 discussion, the recommended first real subcommand is `pmctl backlog` (the maintainer's active pain), building on the working-set contract ([[CC-284]]).

**Problem**: pm-dispatch has no language-agnostic runtime binary. All orchestration logic is
reached through Claude-specific hooks and commands, preventing non-Claude CLIs from accessing
the same PM capabilities without duplicating logic.

**Why**: `pmctl` as a standalone binary makes pm-dispatch a proper tool layer: Claude hooks,
Codex wrappers, and MCP server all become thin callers into one well-defined CLI interface.
Guard logic and dispatch state move from Claude-only paths into `pmctl` so any CLI without hook
support can call `pmctl guard check` or `pmctl safe-bash`.

**Requirement**:
- Implement `cli/pmctl` with subcommand interface:
  - `pmctl task create|claim|dispatch|status|review`
  - `pmctl decision add`
  - `pmctl backlog sync`
  - `pmctl trace tail`
  - `pmctl guard check --event <pre-write|pre-bash|post-task> --file/--command <val>`
  - `pmctl adapter generate <claude|codex|antigravity|opencode>`
- Claude adapter: `/pm task-123` → `pmctl task dispatch task-123 --agent claude`
- Guard logic migrates from Claude-only hooks into `pmctl` so hook is just a thin caller.
- `pmctl adapter generate` produces per-CLI config from core agent definitions.

**Depends on**: CC-211 (core layer extracted first).

**Complements**: CC-211 (architecture), CC-216 (MCP server wraps pmctl).

**Priority**: P1 within CC-211 roadmap. Evaluate at v0.3.0.

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

## CC-225 — claude-executor result observability（deferred）

**Problem**: `claude-executor` task output is written to session-scoped `/tmp/` paths that are not tracked in the repo, cannot be reviewed across sessions, and are not recoverable after the shell exits. The main thread has no durable record of brief path, result summary, or exit status for completed executor tasks.

**Why**: Raised from gate-20260522-145444 (CC-058 gating). The observability gap was observed during the CC-058 session: claude-executor tasks ran but their outputs were opaque to the main thread with no git-diffable artifact. This blocks the CC-211/CC-216 MCP architecture extraction.

**Requirement**: After a claude-executor task completes, the main thread should write the brief path, result summary, and exit status to a repo-tracked directory (format consistent with `.gate-results/`). This serves as the prerequisite for the MCP task abstraction in CC-211/CC-216.

**Dependencies**: CC-211 (MCP architecture design), CC-058 (doctor.sh merge — prerequisite)

**Priority**: P3 — design prerequisite; not blocking current workflows.

**Cross-link**: CC-211 (MCP architecture), CC-216 (task abstraction)

## CC-226 — lint-frontmatter: extract shared dq-escape validation helper（deferred）

**Problem**: `scripts/lint-frontmatter.sh` repeats the same double-quoted escape whitelist regex and adjacent-quoted-scalar check across 4 separate collection branches (key-level flow seq, key-level flow mapping, list-item flow seq, list-item flow mapping). A future grammar fix applied to one branch can be missed in the others, causing a silent parity gap.

**Why**: Raised as medium advisory by critic + architecture-reviewer in gate-20260522-171123 (CC-058 gating). The current branch coverage is green and covers all 4 paths, so the risk is low now, but will grow as the grammar is extended.

**Requirement**: Extract the dq escape whitelist check, the adjacent-quoted-scalar check, and the empty-entry check into a shared bash helper or predicate function. Ensure a parity test (or single call site) prevents future per-branch divergence.

**Dependencies**: CC-058 (lint-frontmatter rewrite — merged)

**Priority**: P3 — maintainability; not blocking current workflows.

**Cross-link**: CC-224 (hook-profile inventory duplication — same class of debt), CC-227 (module extraction — can be done together)

## CC-227 — lint-frontmatter: extract YAML subset parser into lib/yaml-frontmatter.sh（deferred）

**Problem**: `scripts/lint-frontmatter.sh` mixes CLI parsing, frontmatter boundary detection, and a ~150-line hand-rolled YAML subset parser in a single file. The parser logic (`check_frontmatter()`) has no stable call boundary, making it hard to reuse from other scripts (e.g., `doctor.sh` currently forks a subprocess to call the linter), hard to test in isolation, and hard to extend without touching the CLI script.

**Why**: User feedback after CC-058 gating: splitting the YAML validation into a dedicated library file would improve long-term maintainability. Relates to the CC-226 shared-helper advisory — if both are done together, the grammar contract becomes a first-class lib with clear ownership.

**Requirement**:
1. Move `check_frontmatter()` and all YAML-subset validation helpers into `scripts/lib/yaml-frontmatter.sh`
2. `scripts/lint-frontmatter.sh` becomes a thin CLI wrapper that sources the lib
3. `doctor.sh` can optionally source the lib directly instead of fork-execing the linter
4. Tests can source the lib and call `check_frontmatter()` directly, reducing tmp-file overhead
5. If done together with CC-226: shared dq-escape/adjacent-quote/empty-entry helpers live in the lib

**Dependencies**: CC-058 (lint-frontmatter rewrite — merged), CC-226 (shared helpers — can be combined)

**Priority**: P3 — maintainability; not blocking current workflows.

**Cross-link**: CC-226 (shared validation helpers — recommend combining), CC-224 (hook-profile lib extraction — same pattern)

**Cross-link**: CC-211 (MCP architecture), CC-216 (task abstraction)

## CC-228 — BACKLOG validator-debt cleanup（deferred）

**Problem**: `pm/scripts/validate.sh` exits 1 on `main` with ~31 pre-existing E-codes, none introduced by recent PRs. An always-red validator provides no signal — a real new error would be invisible.

**Why**: The debt accumulated as the schema tightened (CC-030 / CC-052 / CC-067) faster than existing rows were migrated.

**Requirement** (resolve per error class, dry-run `validate.sh` after each, target exit 0):
1. `E-INDEX-MISMATCH` — CC-104d/e/f/g/j/k/m/r/s have index rows but no body section. Add stub sections or drop the index rows (they were Windows-dogfood sub-items, mostly folded into shipped PRs).
2. `E-AREA-ENUM` — CC-052/060/104v/203/204 etc. use slash-combined or non-enum areas (`arch`, `config`, `schema`, `ops`, `hook`). Widen the `area` enum (adding `arch`/`ops` is additive and fixes the most rows) or rewrite the rows.
3. `E-REFS-PREFIX` — CC-059/060/061/064/066 carry bare `CC-NNN` refs; the Refs column requires a prefix. Move ticket cross-links into the section body.

**Priority**: P2 — not blocking, but should land before v0.3.0 M1 tightens the schema further.

**Cross-link**: surfaced during CC-222 close-out 2026-05-22.

## CC-234 — memory v2: event-derived distillation（deferred）

**Problem**: The memory system is chat-derived — `episodes.jsonl` summarizes conversations. The durable signal is the action stream (tool calls, decisions, gate verdicts).

**Why**: Memori's insight — memory from what agents *do*, not just what they say. The Event log (CC-230) is that action stream.

**Requirement**: Point `/mem-distill` at `events.jsonl` as an input alongside `episodes.jsonl`. The existing four-tier card system is unchanged; this gives the `event` tier a schema. No separate memory engine.

**Milestone**: v0.3.0 M4.

**Priority**: P2.

**Cross-link**: CC-230 (events.jsonl), CC-229 (event schema).

## CC-235 — Task lifecycle gate: tiered spec→design→plan（deferred）

**Problem**: The spec→design→plan discipline (`/pre-impl`, the `qa_checklist` rule) is advisory prose in `agents/project-pm.md` — not enforced. But a single uniform gate would over-burden trivial tasks — a typo fix should not need a design artifact.

**Why**: Enforcement should be **graded by task size**, consistent with pm-dispatch's existing tiered patterns: the pr-gate express/standard/full tiers and the sonnet-default / Opus-escalation model-tier policy. The gate's weight scales with the task.

**Requirement**: `pmctl` enforces a tiered gate on the `claimed → in-progress` transition:
- **Trivial** — 1 mechanical unit (typo, rename, doc tweak, dep bump): no gate; dispatch directly.
- **Small** — ~2 units, localized: lightweight — a one-line intent + acceptance in the brief; no `/pre-impl` artifact.
- **Substantial** — ≥3 behavioral units, OR touches a shared module/schema, OR introduces a new interface: full spec→design→plan; a `/pre-impl` design artifact is required before the transition.
The ≥3-units threshold and the shared-module / new-interface triggers already exist in `agents/project-pm.md`; this ticket makes them a graded state-machine gate rather than advisory prose.

**Milestone**: v0.3.0 M4.

**Priority**: P2.

**Cross-link**: CC-229 (Task schema/lifecycle), CC-022 (`/pre-impl`).

## CC-236 — pmctl report: away-from-keyboard state roll-up（someday）

**Deprioritized 2026-05-22**: the original "morning report" framing assumed unattended / overnight agent runs. In actual practice the maintainer does not run agents away from the computer, so a time-gap roll-up has low current need. Demoted from v0.3.0 M4 to `🟢 someday`. On-demand state queries are already part of the `pmctl` surface (CC-215); this ticket is specifically the *periodic / since-you-were-away* report.

**Problem** (conditional): if unattended or overnight dispatch ever becomes part of the workflow, there is no single command to see what happened while away.

**Why**: A read-only roll-up over the state substrate (CC-230) would answer that without hand-reconstruction. The idea is sound; the need is gated on a workflow change.

**Requirement** (if revived): `pmctl report` — open tasks, blockers, last gate verdict per active task, runs since last invocation. Read-only query over the CC-230 store.

**Revisit when**: the workflow includes overnight / away-from-keyboard agent runs.

**Cross-link**: CC-230 (state store), CC-211 (epic); AI Night Shift mapping — docs/architecture/v0.3.0-synthesis.md §5.3.

## CC-237 — context-enricher baseline: rg/git/memory sources（deferred）

**Problem**: The `context-pack` abstraction (CC-232) needs concrete sources before it is useful.

**Why**: A baseline of always-available sources (no external dependency) proves the abstraction and is the comparison point for the codegraph spike (CC-209).

**Requirement**: Implement context-enricher sources — `rg`, `git ls-files`, `git diff`, memory search — producing a `context-pack` before dispatch. `pmctl context build`. codegraph is NOT a baseline source; it is evaluated separately (CC-209).

**Milestone**: v0.3.0 M4.

**Priority**: P3.

**Cross-link**: CC-232 (schema/interface), CC-209 (codegraph spike).

## CC-238 — /pr-gate claude-route background fan-out hardening（deferred）

**Problem**: CC-217 made the `/pr-gate` claude-executor reviewer and synthesis fan-out (`commands/pr-gate.md` Route B) run detached via `run_in_background: true`. The CC-217 gate (gate-20260523, express tier) raised three advisories on the new flow.

**Why**: A detached fan-out with no timeout can wait indefinitely if a reviewer agent never reports completion; a single fan-out step makes per-reviewer attribution weaker on partial failure; and the behavior change has no test artifact.

**Requirement**:
- Add a completion timeout / fallback for the background reviewer + synthesis agents — a non-reporting agent must degrade to a partial/fail result, not an indefinite wait.
- Preserve per-reviewer failure attribution when only one fan-out branch fails.
- Add test coverage for the claude-route background completion + relay ordering (`scripts/test-pr-gate.sh` or a `commands/`-contract test).

**Priority**: P3 — advisory follow-up; the CC-217 GO was not blocked on it.

**Cross-link**: CC-217 (origin), `commands/pr-gate.md` Route B.

## CC-239 — reuse-scan capability（deferred）

**Problem**: pm-dispatch carries recurring reuse debt — CC-200..204 are all "the same logic duplicated across scripts / hooks / tests". New work keeps re-creating helpers and patterns that already exist, because nothing surfaces "this already exists" before a brief is written. The maintainer asked whether a dedicated **reuse/refactor agent** should be added; it was analysed and is the wrong shape (see Why).

**Why**: A dedicated reuse/refactor *agent* is not the right abstraction:
- Subagents cannot spawn subagents, so a "refactor agent" could only be a *planner* — duplicating `project-pm`, which already owns task triage / decomposition / brief-writing.
- pm-dispatch agents split by **cognitive mode** (plan / execute / review), not by domain. Refactor is not a new mode — it is ordinary implementation. The spike agent (CC-220) earned a dedicated agent by being a genuinely distinct mode (uncertainty reduction); refactor is not.
- Refactor *expertise* is already placed: `architecture-reviewer` (coupling / abstraction fit), `risk-reviewer` (migration safety / reversibility) and `critic` (scope / convention drift) review every refactor PR, and `docs/dispatch-brief.md` already carries a `refactor` brief skeleton (semantic preservation, all-call-sites-updated, tests green). A refactor agent would duplicate those.
- The v0.3.0 synthesis already concluded "no separate reuse/refactor agent" — reuse work *is* ordinary briefed implementation (`docs/architecture/v0.3.0-synthesis.md`; the CC-200..204 extraction tickets are exactly this).

The genuinely-missing piece is the **front-end**: a reuse-scan that runs *before* briefing so the brief reuses rather than duplicates. That is a capability, not an agent — "split by goal, not by role".

**Requirement**: a reuse-scan **capability** (a skill / context step, not an agent), invoked by `project-pm` during briefing, that queries the codebase for prior art relevant to the task — similar functions, shared helpers, existing patterns (`rg` / `git grep` baseline; symbol / AST sources later) — and emits a "reuse report" the dispatch brief incorporates. It is one consumer of the `context-pack` (CC-232) / context-enricher (CC-237) infrastructure and belongs in `skills/` (CC-061). Refactor *execution* (mechanical or semantic) stays on the existing brief → executor → gate path with the `dispatch-brief.md` refactor skeleton — no new execution agent.

**Priority**: P3 — quality-of-life capability; depends on the M1/M4 context infrastructure (CC-232 / CC-237), so evaluate for v0.3.0 M4 or later.

**Cross-link**: CC-232 (context-pack schema), CC-237 (context-enricher baseline), CC-061 (skills/), CC-200..CC-204 (the reuse debt this prevents recurring), `docs/architecture/v0.3.0-synthesis.md`.

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

## CC-255 — Spike infrastructure: rubric + brief template improvements（active）

**Problem**: CC-209 Phase 1 spike (PR #151) surfaced 2 spike-infrastructure gaps that caused codex to misapply the rubric:

1. **Verdict rubric ambiguity on "local env" scope**: rubric RED criterion 1 read "Install fails after a reasonable attempt and the failure is not a local env issue (e.g. peerDep that the user could resolve)". Codex hit a sandbox network block, classified it as "not local env" because the rubric only enumerated peerDep as a local-env class. Reality: sandbox isolation is the same conceptual class.
2. **Spike brief test-target ambiguity**: Phase 1 brief said "Angle A: pick one well-known symbol in pm-dispatch" — that sentence pre-committed pm-dispatch as the indexed test target. For language-aware tools (codegraph, semgrep, similar), the indexed target must match the tool's supported language set; the brief must commit to the right target, not let the executor pick.

**Why**: Both gaps caused codex to issue an inaccurate verdict (`RED` when the true verdict was `AMBER`). The errors weren't fabrications — codex executed honestly — but rubric + brief ambiguity made them analytically derivable from the prompt. Future spikes will repeat these unless the infrastructure is hardened.

**Requirement**:
- **Rubric template** (`/tmp/cc<NNN>-content/verdict-rubric.md` future spikes write): RED criterion 1 enumeration expanded to "(e.g. peerDep, sandbox network isolation, missing dev dependencies)". Add a sentence: "ANY constraint of the executor's local environment (sandbox, network, missing tools) counts as local-env — not a project quality signal."
- **Spike brief template** (in `docs/spikes/README.md` skeleton OR `docs/dispatch-brief.md`): add optional `test_target:` field to spike-brief schema. Required when the spike evaluates a language-aware tool (codegraph, AST-grep, semgrep, etc.); optional otherwise. Field commits to the representative target codebase the spike will exercise, distinct from the spike's working_dir.
- Update `agents/project-pm.md` brief-authoring guidance: when briefing a verdict-issuing spike for a language-aware tool, require `test_target:` in the brief output.

**Acceptance**:
- `docs/spikes/README.md` skeleton updated with `test_target:` field documented.
- `docs/dispatch-brief.md` schema adds `test_target:` as optional section.
- Reference verdict-rubric template enumerates sandbox-block as local-env example.
- `agents/project-pm.md` brief-authoring rules updated to require `test_target:` for language-aware-tool verdict spikes.
- Regression: re-author CC-209 Phase 2 brief (CC-253 work) using the new template; confirm it commits to `test_target:` with a user-chosen literal path explicitly.

**Priority**: P3 — process polish; affects every future spike but each individual cost is small.

**Cross-link**: CC-209 (Phase 1 origin showing both gaps), CC-253 (Phase 2 dependent on these template improvements), `[[feedback_spike_pilot_required]]` (sibling spike-process rule), `[[feedback_spike_validation_mandatory]]` (sibling validation rule).

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

## CC-268 — docs: run_in_background default async escalation undocumented（deferred）

**Problem**: Agent tool called without `run_in_background:true` may silently promote the subagent to async mode and return `Async agent launched successfully` instead of blocking. Observed with `codex-executor` (ran ~3m45s async without the flag). Docs say "Claude decides" but give no criteria; callers cannot reliably predict whether the dispatch blocks the main thread.

**Priority**: P3 — docs clarity only; no functional impact on existing flows.

**Proposed fix**: Document in `commands/pm.md` or `docs/executor-contract.md` which subagent types always run async, and whether/when the default blocks.

**See**: issue:#166

## CC-269 — ops: hook-save-rate-limits.sh 應寫到 pm-dispatch 自己的 state 路徑（deferred）

**Problem**: `scripts/hook-save-rate-limits.sh` 寫到 `~/.claude/rate-limits.json`，與 claude-account-switcher 及其他工具共用同一檔名，多工具安裝時造成互相覆蓋。

**Why**: pm-dispatch 和 claude-account-switcher 是獨立工具，各自的 rate-limit 資料應存於各自的 state 目錄，不應依賴共用檔名作為「約定」。

**Requirement**:
- `scripts/hook-save-rate-limits.sh` 改寫到 `~/.local/share/pm-dispatch/state/rate-limits.json`（對齊 CC-230 state store 目錄）
- 更新所有讀取此路徑的腳本（doctor.sh、usage 相關腳本等）
- install.sh / uninstall.sh 同步更新 manifest（若有對應條目）
- 設計上：`~/.claude/rate-limits.json` 屬於 Claude Code / claude-account-switcher，pm-dispatch 不寫該路徑

**Context**: 2026-05-28 發現 — statusline-chain.conf 中 pm-dispatch hook 與 claude-account-switcher hook 同時寫到相同檔案。暫時從 chain 移除 pm-dispatch hook 以解除衝突；此票為正式修復。

**Dependencies**: CC-230（state store 目錄已建立）

**Priority**: P3 — 現有 workaround（從 chain 移除）可用；不阻斷其他工作。

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

## CC-272 — process: brief template — omit commit block; document main-thread commit delegation（deferred）

**Problem**: Every brief ends with a `git add + git commit` block that `hook-codex-bash-guard` blocks. The executor marks the commit step as failed and reports `status: partial` in the output summary — even when all code changes are correct. The main thread must manually stage and commit after every dispatch. The brief template implicitly encourages adding a commit block, creating a permanent noise signal.

**Options**:
- **A (preferred)**: Remove the commit block from the brief template and document in `docs/dispatch-brief.md` that commit is always delegated to the main thread. Update `self_verify` template to stop including `git commit` as a success criterion.
- **B**: Add `git add` + `git commit` (without destructive flags) to `hook-codex-bash-guard` allowlist. Requires security review of hook policy (`[[CC-066]]`).
- **C**: `scripts/codex-dispatch.sh` reads a `.commit-msg` file written by the executor and performs the commit on its behalf; executor stays sandboxed.

**Impact**: Every dispatch shows false `status: partial`; creates a recurring manual step the main thread must remember.

**See**: issue:#173 (Pattern 3)

**Cross-link**: `[[CC-066]]` (declarative policy.yml for hook allowlist — relevant if Option B chosen)

**Priority**: P2 — every dispatch affected; Option A is pure documentation with immediate noise reduction.

---

## CC-273 — arch: unified lifecycle hook event spec（deferred）

**Problem**: CC-206 added `pre-gate.sh` / `post-gate.sh` hooks directly into `scripts/pr-gate.sh`. If future tools (e.g., `codex-dispatch.sh`, `brief-validate.sh`) also need hook points, each script will independently add its own pre/post blocks — resulting in inconsistent naming, invocation contracts, and user documentation.

**Proposed direction**: Define a shared lifecycle event spec:
- Convention: `.pm-dispatch/hooks/<event>.sh` (e.g., `hooks/pre-gate.sh`, `hooks/post-dispatch.sh`)
- Single call site in a helper (e.g., `lib/run-lifecycle-hook.sh <event>`)
- Consistent contract: runs from project root as main thread; non-zero aborts the triggering operation
- Single `docs/lifecycle-hooks.md` covering all events (supersedes the pattern docs in `sandbox-limitations.md`)

**When to activate**: When a **second** hook point is requested (not gate). Design cost before that point exceeds the benefit.

**Cross-link**: `[[CC-206]]` (first hook point — gate pre/post)

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

## CC-104k — [Windows dogfood] UNC/9P filesystem mkdir atomicity caveat 🟡 deferred

**Problem**: `mkdir` is atomic on local NTFS but NOT on `\\wsl.localhost\...` (9P UNC). Running pm-dispatch from a WSL UNC path on Windows breaks concurrent lock semantics.
**Fix**: Document install-on-local-disk caveat; add preflight UNC path detection + warning. See CC-104r for the docs/warning follow-up.

## CC-104m — [Windows dogfood] Platform layout — multi-target projection 🟡 deferred

**Problem**: pm-dispatch is currently Claude-only by install.sh target. Introduce `~/.pm-dispatch/content/` as canonical view with symlink-project to `~/.claude/` and future tool targets.
**Scope**: Post-v0.1.0, deferred until Codex/Cursor/Aider integration need surfaces.

## CC-104r — [Windows dogfood r3] hook-tool-trace.sh performance budget on Windows ⏸ deferred

**Problem**: Actual: 27990 ms vs 3500 ms budget on WSL UNC path (9P is ~8× slower than local disk). Not a pm-dispatch code bug.
**Fix**: (a) `docs/platform-support.md` warn; (b) preflight detects UNC path → skips budget assertion.

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

## CC-296 — [release] v0.3.0 deprecation sunset — remove after 2 official releases 🟡 deferred

**Origin (user, 2026-06-01)**: 「這次 0.3.0 的版本有些需要 deprecate 的部分，請幫我在 2 次正式版本之後開始進行移除。」v0.3.0 引入的 back-compat 面要在經過兩個正式版本（v0.3.0 + v0.4.0）後、於 **v0.5.0** 移除。

**Sunset target**: release ≥ **v0.5.0**. Do NOT remove earlier — the deprecation must stay live through v0.3.0 and v0.4.0 so external callers have two releases to migrate.

**Items to remove**:
1. **`pmctl guard check --profile <pm|codex|claude>`** alias (`scripts/lib/pmctl-guard.sh`): the deprecated profile→`(role,runtime)` mapping + the stderr deprecation warning + the `--profile`/`--role` mutual-exclusion branch. Migrate any remaining caller to `--role <pm|executor>` + `--runtime <codex|claude>`. Drop the `deprecated-profile-*` / `profile-role-mutex` back-compat cases from `scripts/test-pmctl-guard.sh` (keep the `--role`/`--runtime` cases). Origin [[CC-291]].
2. **`scripts/codex-dispatch.sh` compatibility symlink shim**: the canonical adapter is `adapters/codex/dispatch.sh` ([[CC-289]]). Internal callers already use the real path (`executor-router` emits it). Remove the shim once external references (agent docs using the `~/github/.../scripts/codex-dispatch.sh` form, `~/.claude/settings.json` allow rules) are migrated to the adapter path — coordinate with agent-doc updates so dispatch keeps working.

**On removal**: re-scan for any other v0.3.0 `### Deprecated` CHANGELOG entries and clear them in the same sweep; move the CHANGELOG `### Deprecated` items to `### Removed` for the v0.5.0 entry.

**Cross-link**: `[[CC-291]]` (`--profile` alias origin), `[[CC-289]]` (codex-dispatch shim origin).

## CC-307 — [arch] pm role cross-runtime — guard 已 runtime-agnostic，但文件與 alias 仍暗示 pm = claude-only 🟡 deferred

**Problem**: CC-291 的兩軸設計（role ⊥ runtime）要求 pm guard policy 不能綁 runtime。`hook-pm-write-guard.sh` 已 runtime-agnostic ✓，`--role pm --runtime codex` CLI 路徑已可呼叫 ✓，但以下三點仍讓人誤以為 pm=claude-only 是設計決定：

1. **deprecated `--profile pm` alias** hardcode `runtime="claude"`（`scripts/lib/pmctl-guard.sh`）
2. **說明文字** 說「currently claude-only; no codex-as-pm」，未分清「guard 設計」與「現有部署」
3. **無 codex-as-pm end-to-end test** — 沒有驗證 `pmctl dispatch run --adapter codex` 配合 pm-role brief 可成功 dispatch

**Why it matters**: 若下一個 PM runtime（如 Gemini CLI / OpenCode）出現，工程師會誤以為 pm 不能跨 runtime 而重複發明輪子，而非直接走 `--role pm --runtime <new>` 路徑。兩軸設計的可擴展性在這裡被文件化的 false constraint 遮蔽。

**Fix scope**:
1. **alias** — 接受 deprecated hardcode（CC-296 會移除 `--profile`，不值得在此改）。文件說清楚 "convenience alias for common case, not a design constraint"
2. **說明文字** — 把「pm only ever runs on claude; no codex-as-pm」改為「pm guard policy is runtime-agnostic; claude is the currently deployed pm runtime, but other runtimes are supported by design」（`scripts/lib/pmctl-guard.sh`）
3. **integration test** — `scripts/test-pmctl-guard.sh` 加一個 smoke test: `pmctl guard check --role pm --runtime codex --event pre-write --file /tmp/brief-task.md` 確認 guard 路徑通（已有 claude 版，補 codex 版對稱）

**Acceptance**: 文件改完後，讀程式碼的工程師應能明確看出「pm role 是 runtime-agnostic 的設計，目前只有 claude 部署，但 codex-as-pm 不需改 guard 就能支援」。

**Cross-link**: `[[CC-291]]`（two-axis design），`[[CC-296]]`（alias sunset），`[[CC-215]]`（pmctl dispatch run）。

---

## CC-306 — [arch] extend CC-233 layer enforcer to runtime-named data paths in scripts/ 🟡 deferred

**Problem**: CC-298 removed the current pr-gate runtime-named brief data paths, but the layer-boundary checks do not yet prevent a future script from reintroducing runtime-named data directories.

**Requirement**: Extend the CC-233 enforcer to catch `.codex-*` / `.claude-*` data directories under `scripts/` while keeping adapter-owned paths under `adapters/codex/` and `adapters/claude/` allowed.

**Why deferred / P3**: Optional defense-in-depth follow-up from CC-298; the implementation change is complete without strengthening validators in this ticket.

**Not done by CC-309**: CC-309's inverted layer-boundary test (`check_adapters_no_state_writes` in `test-layer-boundaries.sh`) forbids **adapters** from writing state directly — a different rule. This ticket's `.codex-*`/`.claude-*` runtime-named **data-dir** guard under `scripts/` is still unimplemented. (Corrects a v0.4.0 MILESTONES row that had conflated the two.)

**Cross-link**: `[[CC-233]]`, `[[CC-298]]`, `[[CC-309]]`.

## CC-314 — routing_log.md → events.jsonl migration + deprecate machine-write

**Problem**: deprecating the `routing_log.md` machine-write needs a real migration: the hook writes `kind` `bash-dispatch`/`agent-dispatch` (`hook-routing-log.sh:322-325`) which are **not** in the core Event enum (`event.schema.json:18-30`), and the existing `migrate-routing-log.sh` only migrates the old markdown shape.

**Plan**: build a `routing_log → events.jsonl` migration with explicit kind mapping (→ `run.dispatched` etc.) + a subject-id strategy; stop the hook's markdown machine-write; keep `migrate-routing-log.sh` as legacy-markdown cleanup only.

**Detail**: scoping doc §10.A6, §4 (D3 = deprecate).

**Outcome**: 2026-06-05 — shipped in pr:#234. `hook-routing-log.sh` deprecated (early-exit), `migrate-routing-to-events.sh` added with deterministic IDs and idempotency, `ROUTE_LOG_ENABLED=0` in `install-hooks.sh`.

**See**: pr:#234

## CC-315 — state read/query contract + pmctl trace

**Problem**: `state-writer.sh` is write-only and `cli/pmctl` has no read/query/trace subcommand (`cli/pmctl:35-78`); consumers would read state by ad-hoc JSONL grep, and a single-writer with no read contract is half a substrate.

**Plan**: `pmctl` owns read ops over state — by id / `task_id` / event `kind` / time-window — with `pmctl --json` output; define active+archive read semantics (ordering, corrupt-row tolerance, time-window, indexed vs streamed). `pmctl trace` is the first consumer.

**Detail**: scoping doc §3.7, §3.6, §10.B (D6). Related: [[CC-316]].

**Outcome**: 2026-06-06 — shipped in pr:#237. `scripts/lib/pmctl-trace.sh` adds `pmctl trace tail` over `events.jsonl` + `archive/events-*.jsonl.gz` (partition via the writer's `_sw_project_dir`); filters by id/kind/subject/time-window, merges active+archive chronologically (append order preserved on equal `ts`), skips malformed rows with a counted warning, streamed linear scan (indexing deferred). 12-case suite `test-pmctl-trace.sh`. Read-only — no writer/schema/layout touched.

**See**: pr:#237

## CC-316 — state store rotation implementation

**Problem**: `core/state/layout.yaml:46-63` specifies gz rotation (`archive/{runs,events}-$YYYYMM.jsonl.gz`) but no code implements it (`state_store_init` only mkdirs `archive/`), so `runs.jsonl`/`events.jsonl` grow unbounded; and the monthly path collides on >1 rotation/month.

**Plan**: implement rotation per layout with a monotonic segment suffix (`*-$YYYYMM-NNNN.jsonl.gz`); the reader (CC-315) merges active + archived segments.

**Detail**: scoping doc §3.8, §10.B (D7). Related: [[CC-315]].

**Outcome**: 2026-06-06 — shipped in pr:#238. Rotation in `scripts/lib/state-writer.sh` under the per-entity append lock: byte threshold (50 MB, `PM_DISPATCH_ROTATE_MAX_BYTES` override; 90-day trigger deferred), monotonic `archive/<entity>-$YYYYMM-$NNNN.jsonl.gz` segments, **destination-named `.staging`** for genuinely idempotent crash recovery (no duplicate rows in the publish→cleanup window), best-effort + loud (never fails the canonical append; degradation on stderr + `state-writer.err`). 13-case suite `test-state-store-rotation.sh`. layout/writer golden-parity test left to [[CC-317]].

**See**: pr:#238

## CC-317 — state store safety & robustness hardening

**Problem**: `_sw_store_root` trusts `PM_DISPATCH_STATE_ROOT`/`XDG_DATA_HOME` directly with plain `mkdir -p` (`state-writer.sh:32-90`) — no canonicalization, symlink-component rejection, world-writable check, or `0700` mode; `serialize_with_lock`'s mkdir fallback has no stale-owner protocol (`portable.sh:174-180`) — a killed writer on a flock-less FS blocks until timeout; and `layout.yaml` is "definitions only" while writer paths are hardcoded (drift-prone).

**Plan**: canonicalize + permission-check the store root (reject unsafe symlink/world-writable; `0700`); mkdir lock carries pid/host/start-time + cleanup trap + bounded stale reclaim + a UNC/9P preflight warning; make `layout.yaml` an executable source of truth (writer/reader consume it, or golden tests compare paths/locks/subdirs).

**Detail**: scoping doc §10.B.

**Outcome**: 2026-06-06 — shipped in pr:#239, completing the v0.4.0 state-first foundation. (A) `state_store_init` runs a store-root safety gate — non-mutating symlink-leaf + ownership checks reject before any mkdir/chmod, then `0700` + either-bit group/world-writable rejection; VERSION gate runs before the mutating repair; `PM_DISPATCH_ALLOW_UNSAFE_STATE_ROOT=1` escape hatch. (B) `mkdir_lock` carries pid/host/epoch owner metadata, reclaims only clearly-stale owners (same-host dead-PID never on age; remote by age ceiling) with ABA guard + bounded retries; `mkdir_unlock` documents release; subshell `EXIT` trap for kill-safety; non-fatal UNC/9P warning. (C) `scripts/test-state-layout-parity.sh` golden test binds layout.yaml ↔ writer. Suites: portable 41, state-store 63, layout-parity 3.

**See**: pr:#239

## CC-321 — refactor: rename CLAUDE_HOOK_* env vars to PM_HOOK_*

**Problem**: pm-dispatch hook configuration env vars use a `CLAUDE_HOOK_` prefix (`CLAUDE_HOOK_CODEX_READ_ROOTS`, `CLAUDE_HOOK_CODEX_GUARD`, `CLAUDE_HOOK_PM_GUARD`, `CLAUDE_HOOK_REVIEWER_GUARD`, `CLAUDE_HOOK_GATE_REPO_ROOT` (deleted), `CLAUDE_HOOK_DISPATCH_ABS`, `CLAUDE_HOOK_LOG_DIR`). The prefix creates a false coupling to the Claude Code agent system — these are pm-dispatch's own config knobs and should be in the `PM_HOOK_` or `PM_DISPATCH_` namespace.

**Plan**:
1. Rename each env var to `PM_HOOK_*` equivalent across all hooks, tests, and docs.
2. Add a shim period: if the old `CLAUDE_HOOK_*` name is set, emit a deprecation warning to stderr and honour it. Remove the shim after one release cycle.
3. Update `scripts/install-hooks.sh`, all `test-hooks.sh` / `test-pmctl-guard.sh` references, and `docs/`.

**Acceptance**: `grep -r CLAUDE_HOOK_ scripts/ adapters/ docs/` returns only the shim/deprecation-warning lines.

**Scope limit**: does NOT rename `CLAUDE_HOOK_LOG_DIR` if that conflicts with Claude Code's own log dir convention — verify first.

**Priority note**: breaking change; hold until CC-319/CC-320 are merged and no active PRs depend on the old names.

**Cross-link**: [[CC-319]], [[CC-320]].

---

## CC-322 — docs: review-model.md — Relocating Rigor 哲學文件

**Problem**: pm-dispatch 已有 cross-context isolated reviewers（pr-gate sub-agents）、machine verification（`self_verify cmd:`）、上游 spec review（`/pre-impl`），但沒有文件把這些機制命名成一套完整的 Review Model，讓新接觸的維護者看不出設計意圖。

**Why**: 「Relocating Rigor」—— 嚴謹從中間逐行 review 搬到兩頭（上游 intention / 下游 verification）—— 是 pm-dispatch workflow 的核心哲學，值得正式成文。文件也是後續 CC-323–CC-327 實作的理念錨點。

**Requirement**:
1. 新增 `docs/review-model.md`，定義四層：
   - Layer 1（上游）：Intention & Spec review，在 agent 動手前確認方向
   - Layer 2（中層）：Cross-Context Isolation，reviewer 用乾淨 session 讀最終產物
   - Layer 3（下游）：Conceptual Map review，看架構不看每行 code
   - Layer 4（驗收）：Machine Verification，`self_verify cmd:` 強制執行
2. 說明 pm-dispatch 哪些現有機制對應哪一層
3. 說明逐行 code review 降級為 exception（agent 卡住 / 方向明確錯才人工介入）
4. 新增 cross-link：`docs/CONCEPTS.md`、`docs/dispatch-brief.md`、`docs/pr-gate-handover-schema.md`

**Non-goals**: 不改任何 script / skill / agent。

**Outcome**: 2026-06-05 — shipped in pr:#236. `docs/review-model.md` 落地（四層 Review Model + 逐行 review 降級為 exception + cross-links）；CHANGELOG [Unreleased] Added 記錄；Layer 1/Layer 3 的 planned 行為以 `> **Planned** (CC-323/CC-326)` blockquote 標示，與 backlog active 狀態對齊。

**See**: pr:#236

**Cross-link**: [[CC-323]], [[CC-324]], [[CC-326]], [[CC-327]].

---

## CC-323 — skill: 強化 /pre-impl 輸出 contract — Intention + Conceptual Map 必填

**Problem**: `/pre-impl` 目前是輔助命令，輸出格式鬆散；`/pm` 不會自動要求先跑。架構影響型任務缺乏強制的上游 intention / boundary review 關卡，導致 agent 實作方向可能在沒有人明確點頭的情況下就開始。

**Why**: 文章「Relocating Rigor」最核心的一點：在 agent 動手前，先把架構原型在腦袋裡（或文件裡）看過一遍再放它去做。這比事後逐行修正便宜得多。

**Requirement**:
1. 更新 `commands/pre-impl.md`，定義固定輸出 sections：
   - `## Intention` — 這次真正解決什麼問題
   - `## Non-goals` — 明確不做什麼
   - `## Bounded Context` — 可碰 / 不可碰的 module / script / command
   - `## Conceptual Map` — 純文字流程圖或結構圖（必填）
   - `## Acceptance Metrics` — 可驗收條件（非「works as expected」）
   - `## Verification Plan` — machine-check vs. semantic-check 分類
2. `agents/project-pm.md` 路由規則新增：`behavioral_units ≥ 3` 或 `architecture_impact ≠ none` → 自動要求先跑 `/pre-impl`，PM approve 後才進 dispatch brief
3. 輸出格式可直接銜接 dispatch brief schema（CC-324 的 `conceptual_map` 欄位）

**Acceptance**:
- `/pre-impl "<task>"` 輸出包含上述六個 sections
- PM 收到 architecture 影響任務時，在 brief 前先呼叫 `/pre-impl` 並等待確認

**Dependencies**: [[CC-322]]（文件錨點）；銜接 [[CC-324]]（brief schema）。

**Outcome**: 2026-06-07 — shipped in pr:#TBD. `commands/pre-impl.md` 升級為六個固定 sections（Intention / Non-goals / Bounded Context / Conceptual Map / Acceptance Metrics / Verification Plan）；Step 4 保留 design constraint list 可直接 paste 進 brief；`agents/project-pm.md` routing rule 擴大觸發條件（加 `architecture_impact ≠ none`）；docs/review-model.md Layer 1 移除 Planned blockquote。

**See**: pr:#TBD

---

## CC-324 — schema: dispatch brief 新增 conceptual_map + architecture_impact 欄位

**Problem**: dispatch brief schema 目前沒有方式表達「這次改動的架構影響程度」或「架構概念圖」，導致 architecture-reviewer 只能掃 source diff，而非先看概念圖。

**Why**: 讓 brief 攜帶 `architecture_impact` 與 `conceptual_map`，架構影響輕重就有明確的機器可讀欄位，後續 brief-validate（CC-325）與 tier 自動建議（CC-327）才有資料來源。

**Requirement**:
1. `docs/dispatch-brief.md` 加入新欄位說明：
   ```yaml
   architecture_impact: none | minor | major
   conceptual_map: |
     [純文字圖，architecture_impact != none 時必填]
   ```
2. `scripts/brief-validate.sh` 對新欄位做結構驗證（`architecture_impact` 必須是合法 enum 值）
3. `docs/dispatch-brief.md` 說明 `conceptual_map` 優先給 `architecture-reviewer` 用，非強制掃 source diff 的替代品

**Acceptance**:
- `brief-validate.sh` 對合法 `architecture_impact` 值 PASS、非法值 FAIL
- 文件有範例 brief 含 `conceptual_map`

**Dependencies**: [[CC-323]]（pre-impl 產出可填入此欄位）；銜接 [[CC-325]], [[CC-326]], [[CC-327]].

**Outcome**: 2026-06-07 — shipped in pr:#TBD. `docs/dispatch-brief.md` 加入 `architecture_impact`（`none|minor|major`）與 `conceptual_map` optional 欄位說明；含範例 YAML；`scripts/brief-validate.sh` 加入 enum 驗證函式與 `has_conceptual_map`。

**See**: pr:#TBD

---

## CC-325 — infra: brief-validate 強化 — Acceptance Metrics + conceptual_map 品質機器檢查

**Problem**: `brief-validate.sh` 目前只做結構檢查（欄位存在性、enum 合法性），不檢查「品質」。Acceptance Metrics 可以是空泛語（"works as expected"）、file-writing task 可以沒有任何 machine-checkable self_verify，這兩種情況都會讓 agent 有模糊空間偷懶或幻覺。

**Why**: 文章「Relocating Rigor」：Acceptance Metrics 一定要先寫清楚，指標含糊就會用最省力的方式交差。機器檢查可以把這條規則變成強制 policy，不靠人工審查。

**Requirement**:
- `brief-validate.sh` 新增品質規則：

| 條件 | 行為 |
|---|---|
| `acceptance` 含 "works as expected" / "passes tests" / "no errors" 等空泛語 | FAIL + 提示重寫 |
| file-writing task 無任何 `- cmd:"…"` self_verify | FAIL |
| `behavioral_units ≥ 3` 無 `qa_checklist` | WARN |
| `architecture_impact: major` 無 `conceptual_map` | FAIL |
| sensitive path + sequential pr-gate | WARN → 建議 `--parallel` |

- 加入對應測試 cases

**Non-goals**: 不改 brief 執行流程，只在驗證層加規則。

**Dependencies**: [[CC-324]]（`architecture_impact` 欄位需先定義）；[[CC-323]]（acceptance metrics 格式由 pre-impl contract 奠定）.

**Outcome**: 2026-06-07 — shipped in pr:#TBD. `scripts/brief-validate.sh` 加入品質規則：acceptance 含空泛語 → WARN；file-writing 無 `cmd:` self_verify → FAIL；`architecture_impact:major` 無 `conceptual_map` → FAIL；`behavioral_units ≥ 3` 無 `qa_checklist` → WARN；`scripts/test-brief-validate.sh` 加入 10 個新 test cases（32/32 pass）。

**See**: pr:#TBD

---

## CC-326 — agent: 更新 architecture-reviewer prompt — Conceptual Map 優先於 source diff

**Problem**: `agents/architecture-reviewer.md` 目前直接讀 source diff / file list，沒有指示「先看 conceptual_map」。即使 brief 有 conceptual_map，reviewer 也不保證會用它。

**Why**: 文章「Relocating Rigor」：「Architect / Editor，不是逐行 inspector」—— reviewer 看的是整個架構對不對，不是某行寫得漂不漂亮。只有在 conceptual_map 與 diff 不一致、或 risk surface 需要抽查時，才需要進入 source files。

**Requirement**:
1. `agents/architecture-reviewer.md` 在 review 指示開頭加入：
   - 若 brief 有 `conceptual_map`：優先讀 map，確認 bounded context / layer boundary，只在 map 與 diff 不一致或 risk surface 需抽查時才看 source files
   - 若 brief 無 `conceptual_map`：維持現行 source diff review，但在 finding 中 note「建議提供 conceptual_map」
2. 改動僅限 `agents/architecture-reviewer.md`，不影響其他 reviewer

**Acceptance**:
- `architecture-reviewer` prompt 包含 conceptual_map 優先讀取指示

**Cross-link**: [[CC-322]], [[CC-324]].

**Outcome**: 2026-06-07 — shipped in pr:#TBD. `agents/architecture-reviewer.md` Process 段落改為 conceptual_map-first（有 map 時先讀 map，source diff selectively）；無 map fallback 維持 diff review 並 note 缺失；docs/review-model.md Layer 3 移除 Planned blockquote。

**See**: pr:#TBD

---

## CC-327 — pr-gate: tier 定義改為 rigor level（而非 reviewer 數量）

**Problem**: `express / standard / full` 三個 tier 目前的語意是「reviewer 數量多寡」，沒有對應到「review 嚴謹程度」的概念，也沒有與 brief 的 `architecture_impact` 掛鉤。

**Why**: 文章「Relocating Rigor」：tier 應該反映「需要多嚴謹的 review」而不只是「幾個 reviewer」。與 brief 的 `architecture_impact` 掛鉤後，tier 選擇可以自動建議，減少人工判斷。

**Requirement**:
1. 更新 `scripts/pr-gate.sh` + 相關文件，重新定義 tier 語意：
   - `express`：hotfix / docs-only / `architecture_impact: none` → machine verification + combined session reviewer
   - `standard`：一般 feature / `architecture_impact: minor` → conceptual map 必要 + critic + qa + architecture
   - `full`：架構變動 / `architecture_impact: major` / sensitive path → parallel cross-context + security + risk hard gates + synthesis
2. `scripts/pr-gate.sh` 加入 tier 自動建議邏輯：若 brief 有 `architecture_impact`，啟動前 emit 建議 tier（user 仍可 override）
3. 更新 `docs/review-model.md`（CC-322）tier 說明段落

**Acceptance**:
- 文件中三個 tier 的語意對應到 rigor level，不只是 reviewer 數量
- 帶 `architecture_impact: major` 的 brief → gate 建議 `full` tier（emit warning，不強制）

**Cross-link**: [[CC-322]], [[CC-324]], [[CC-323]].

**Outcome**: 2026-06-07 — shipped in pr:#TBD. `scripts/pr-gate.sh` 加入 `--brief <file>` 選項與 tier advisory 邏輯（`architecture_impact:major` → suggest full；`minor` + express detected → suggest standard；advisory only，不強制）；`docs/review-model.md` 加入「pr-gate rigor tiers」章節；`skills/pr-gate-review/SKILL.md` tier 說明改為 rigor level 語意；移除 review-model.md 中的舊式 Planned blockquotes。

**See**: pr:#TBD

---

## CC-328 — spike: lightweight built-in symbol index for context-pack（Bash+SQLite，無外部依賴）🟢 someday

**Problem**: pm-dispatch subagent 在 dispatch 前缺乏結構化的 repo context，只能透過重複 grep/read 探索相關檔案與 symbol，造成 token 浪費與 dispatch brief context 不穩定。現有方案不足：CC-237（context-enricher interface）需要外部 rg；CC-209（codegraph evaluation）評估的是 TypeScript external tool，已獲 AMBER——pm-dispatch 的 bash/markdown stack 不在其支援範圍內。

**Why**: 需要一個**內建**的 context layer，僅依賴 standard Unix toolchain（`bash / find / grep / awk / sed / sqlite3`），不引入任何需要另行安裝的 binary（如 ctags、rg、Node.js、Rust binary），在 dispatch 前產生 compact context pack（相關檔案 + approximate symbols + test hints），直接注入 dispatch brief，減少 subagent 盲目探索成本。此能力應建在 v0.4.0 state-first 地基上（消費 Run/Event/trace 提供的 recently touched files、task history 等動態排序資料），因此等地基落地後再實作。

**Requirement**:

*Phase 1 — Spike（MVP，Bash+SQLite only）*
1. `pm context init`：掃描 repo 建立 SQLite index（`files` + `symbols` 兩張表）
2. `pm context update [path]`：增量更新（依 mtime/sha1 偵測變更）
3. symbol 提取策略：Bash + awk/sed/grep 的 regex-based approximation，支援 Shell（function）、Go（func/type/struct/interface）、Python（def/class）、TypeScript/JavaScript（function/class/const arrow）
4. `pm context pack "<query>"`：以關鍵字查詢，輸出 context pack（relevant files + symbols + search hints），格式可直接嵌入 dispatch brief
5. 以 pm-dispatch 自身 repo 作為第一個 fixture，比較 3 個真實任務的 before/after dispatch brief

*SQLite schema（最小可行）*:
```sql
files(id, path, language, size_bytes, mtime, sha1, indexed_at)
symbols(id, file_id, name, kind, language, line_start, line_end, signature, backend, confidence)
```

*MVP 內建依賴*: `bash`, `find`, `grep`, `awk`, `sed`, `sqlite3`（不新增任何其他依賴）

*Optional backend（Phase 2 以後）*: ctags、ffts-grep、tree-sitter — 只作為加速層，MVP 無此需求

**Non-goals**:
- 精準 AST parsing / call graph
- LSP references / semantic embeddings
- MCP server / daemon / web UI
- 取代 CC-209 codegraph spike（兩者定位不同：CC-209 評估外部工具；CC-328 建內建 layer）
- 取代 CC-237 context-enricher（CC-237 是 interface；CC-328 是其中一個 source）

**Dependencies**:
- 建議等 v0.4.0 Run/Event/trace state 穩定後實作（CC-315 / CC-316）
- context pack 格式應對齊 CC-232 context-pack schema 介面
- 實作後作為 CC-237 context-enricher 的 `--source builtin-index` backend

**Milestone**: `🟢 someday` — v0.5.0 candidate，待 v0.4.0 state-first 地基落地後排入規劃。

**Cross-link**: [[CC-237]], [[CC-209]], [[CC-232]], [[CC-239]], [[CC-315]].

---

## CC-329 — agent: debt-auditor — proactive tech-debt health scan on living code 🟢 someday

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

**Cross-link**: [[CC-220]], [[CC-239]], [[CC-328]], [[CC-237]].

---

## CC-330 — skill: /discover — milestone seeder + opportunity scanner 🟢 someday

**Problem**: project-pm 是**收斂模式**（reactive：收到任務 → 分解 → 派工），沒有內建的**發散模式**（proactive：讀 backlog + 近況 → 生成機會清單）。每次 milestone 規劃都靠對話即興，缺少系統性的「現在最值得做什麼」掃描。

**Why**: Brainstorm / ideation 的正確形狀是利用 PM 的既有 context（memory、DECISIONS、MILESTONES），而非隔離的新 agent。隔離反而要重新推導所有設計決策。正確形狀是：一個 **skill** 切換 PM 到發散模式，結構化地生成機會清單。

**Requirement**:
- `commands/discover.md` — `/discover [theme]` skill 定義：
  - 以指定 theme（可選）或預設「當前 repo 最高槓桿改善點」為提示
  - 讀取：backlog（`🟢 someday` + `⏸ deferred` 項目）+ DECISIONS + MILESTONES（next milestone 範圍）+ `git log --oneline -30`
  - 輸出：5–10 個機會項目，每項含 `{title, problem_in_one_line, why_now, estimated_size: XS/S/M/L}`，按槓桿高低排序
  - 不產出 dispatch brief，不承諾任何實作——純探索輸出
- 典型用法：`/discover v0.5.0 themes`、`/discover dispatch pipeline improvements`、`/discover`（全域）
- 結果由使用者決定是否轉為正式 ticket 或 milestone

**Non-goals**:
- 不取代 `/pm`（project-pm 收斂模式仍是主路徑）
- 不自動建立 ticket（由使用者判斷後手動開）
- 不是 standalone agent（PM 已有所需 context，不需要隔離）

**Relationship**:
- 使用 PM 發散模式消費 backlog + MILESTONES
- 未來可以接 CC-328 context index 強化 codebase 相關機會的偵測精度

**Milestone**: `🟢 someday` — 實作成本 XS（只需一個 commands/discover.md），可提前於其他 someday 項目。

**Cross-link**: [[CC-220]], [[CC-239]], [[CC-237]], [[CC-328]].

---

## CC-332 — docs/process: PM size-first dispatch routing policy

**Problem**: PM dispatch 的 model / route 選擇沒有以「任務大小」為一級判準，`docs/model-tier-policy.md` 與 `agents/project-pm.md` 對 Tiny / Small 任務的路由各說各話，存在 source-of-truth drift。

**Plan**: 將 §Implementation tasks 改寫為 size-first 路由表 — Tiny → 主線程 inline（不派發、不寫 brief）；Small → `model: light`（codex-spark / haiku）；Medium/Large → Codex `default`。同步更新 `agents/project-pm.md` 的 Dispatch model selection，使 PM 對 Tiny 給 inline 建議、對 Small 寫 `model: light` brief，並澄清 main-thread 與 PM routing 角色。

**Detail**: 純文件 / process change；不改腳本。

**Outcome**: 2026-06-05 — shipped in pr:#236. `docs/model-tier-policy.md` 與 `agents/project-pm.md` 路由表對齊，CHANGELOG [Unreleased] Added 記錄。

**See**: pr:#236

---

