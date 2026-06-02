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
| CC-207 | 🟡 deferred | **[Windows dogfood r3 finding]** `install.sh` on Git Bash (OSTYPE=msys/cygwin) falls back to copying files instead of symlinking (`ln -s` does not work); 83 files copied across agents/, commands/, scripts/, .pm — after pm-dispatch updates users must re-run `bash install.sh` to sync. Fix: detect Git Bash, use PowerShell `mklink /J` (directory junction, no admin required) for each target. | ops/portability | 2026-05-20 | — | P2 | oss |
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
| CC-260 | ✅ closed 2026-06-01 | **[pr-gate.sh: dirty-worktree fail-loud preflight]** When a branch has committed changes, `git diff "$BASE"...HEAD` silently omits uncommitted tracked and untracked files. Fix: fail with exit 3 only when committed `BASE...HEAD` changes exist and the worktree is dirty; `--allow-dirty` explicitly folds committed + working-tree changes into review scope. Dirty-only-no-commit trees still use the existing working-tree fallback. Flagged by critic [medium] in CC-229 Gate 12. | gate/ops | 2026-05-25 | pr:#214 | P2 | — |
| CC-262 | ⚠️ partial 2026-05-25 | **[Executor isolation 抽象層]** M1 ✅（PR #162）：`core/policy/isolation-level.yaml` + `adapters/claude/isolation-map.yaml`。M2 ⏳：`codex-dispatch.sh` dispatch 前展開 isolation_level。M3 ⏳：`agents/project-pm.md` PM brief template 改寫 `isolation_level:` 取代三個原生欄位。v0.4.0 ⏳：`adapters/codex/isolation-map.yaml`。 | arch/process | 2026-05-25 | pr:#162 (M1) | P2 | design |
| CC-268 | 🟡 deferred | **[docs: run_in_background default async escalation undocumented]** Agent tool 未設 `run_in_background:true` 時，harness 可能靜默升格為 async 並回傳 `Async agent launched successfully`（codex-executor 已觀察到此行為）。需文件化哪些 subagent 類型永遠 async、預設行為保證。| docs/DX | 2026-05-28 | — | P3 | — |
| CC-269 | 🟡 deferred | **[ops: pm-dispatch hook-save-rate-limits.sh 應寫到自己的 state 路徑]** 目前 `scripts/hook-save-rate-limits.sh` 寫到 `~/.claude/rate-limits.json`，與 claude-account-switcher 等其他工具使用同一檔名，造成多工具衝突。應改寫到 `~/.local/share/pm-dispatch/state/rate-limits.json`（對齊 CC-230 state store 位置），並同步更新所有讀取此路徑的腳本。 | ops/install | 2026-05-28 | — | P3 | — |
| CC-270 | 🟡 deferred | **[test: concurrent pmctl adapter generate guard]** Two simultaneous `pmctl adapter generate <same-name>` runs can race: the precheck+mkdir+trap sequence is not atomic. Blast radius: one run may delete another's partial output; reproducible by deleting `adapters/<name>` and rerunning. Deferred — single-developer workflow makes this low-probability; fix with atomic mkdir using `mkdir` exit-code guard when needed. | test/ops | 2026-05-28 | — | P3 | — |
| CC-272 | 🟡 deferred | **[process: brief template — omit commit block; document main-thread commit delegation]** 每個 brief 末尾的 `git add + git commit` 均被 `hook-codex-bash-guard` 擋住，executor 回報 `status: partial`（即使程式碼正確），主線程每次都必須手動 commit。推薦 Option A：從 brief template 移除 commit block，在 `docs/dispatch-brief.md` 明文「commit 永遠委派主線程」。Option B：hook allowlist 加入無破壞性 git add/commit。 | process/DX | 2026-05-28 | — | P2 | — |
| CC-273 | 🟡 deferred | **[arch: unified lifecycle hook event spec]** CC-206 只在 gate 層加了 pre/post-gate hooks。如果未來多個工具（dispatch、validate 等）都需要 hook 點，應定義統一的 lifecycle event 命名規範（如 `.pm-dispatch/hooks/<event>.sh`）和呼叫合約，而非在每個腳本各自加 pre/post block。目前無需求，等有第二個 hook 點需求時再設計。 | arch/gate | 2026-05-28 | — | P3 | — |
| CC-274 | 🟡 deferred | **[docs: reconcile CC-262 planning text with shipped isolation implementation]** CC-262 entry 有三處過時：(1) enum 只列 4 值，缺 workspace-network；(2) sandboxed 語義仍寫「完整隔離」，實為 best-effort workspace-write；(3) M2/v0.4.0 仍標 deferred，均已在 PR #175 落地。 | docs | 2026-05-29 | pr:#175 | P2 | — |
| CC-276 | 🟡 deferred | **[feat: persistent gate override declarations]** 每輪 gate 重開 fresh session，已接受的 risk override 必須重新聲明。支援 `--override-file` 或自動探索 `.gate-overrides.md`，inject 到 reviewer prompt 前置脈絡，避免已接受的 block 重複出現。 | gate/process | 2026-05-29 | — | P2 | — |
| CC-285 | 🟡 deferred | **[archiver safe-drop: don't drop a terminal row whose body exists nowhere]** `scripts/archive-closed-backlog.sh` currently drops a terminal index row even when no body section exists in BACKLOG.md and none is in BACKLOG-ARCHIVE.md (warns to stderr). In a valid backlog `validate.sh`'s index↔body 1:1 invariant prevents this, and it is git-recoverable — recorded as accepted tradeoff in DECISIONS 2026-05-30. Defense-in-depth follow-up: keep the row + emit a loud warning when the body is in neither file, leaving it for manual reconciliation rather than removing it. Surfaced by pr-gate critic on #186. | ops | 2026-05-30 | — | P3 | hygiene |
| CC-286 | 🟡 deferred | **[pmctl: prefix-generic next-id derivation]** `scripts/pm-prep-snapshot.sh` derives `backlog_next_id` CC-only (it emits `CC-NNN`); under the working-set contract it scans BACKLOG.md + BACKLOG-ARCHIVE.md for the max, but only `CC-` IDs. A cross-repo next-id (other prefixes: JS-, PA-) must be prefix-derived and centralized in pmctl, scanning both working-set and archive. Retire pm-prep-snapshot's CC-hardcoded derivation when `pmctl backlog`/next-id lands. Surfaced by pr-gate critic+architecture on #186. | arch | 2026-05-30 | — | P3 | design |
| CC-293 | ✅ closed 2026-06-02 | **[arch: lift default/config resolution into pmctl runtime]** dispatch 的 default-model + `dispatch.default_model` config precedence 目前住在 `adapters/codex/dispatch.sh`(CC-292 gate 上 critic + architecture-reviewer 都提)。當下一個跨 adapter 的 dispatch config 軸出現時,把 config/default 解析從 adapter 抽到 `pmctl dispatch run` runtime,避免 policy-like precedence 在每個 adapter 重複。關聯 [[CC-292]]、[[CC-289]]、[[CC-211]]。 | arch | 2026-05-31 | pr:#216 | P3 | design |
| CC-296 | 🟡 deferred | **[chore: v0.3.0 deprecation sunset — remove after 2 official releases]** 移除 v0.3.0 引入的 deprecated 面，sunset 目標 **v0.5.0**（經 v0.3.0 + v0.4.0 兩個正式版本後）。(1) `pmctl guard check --profile pm/codex/claude` 別名 → 全部 caller 改 `--role`/`--runtime`，移除 alias + deprecation warning + back-compat 測試（[[CC-291]]）。(2) `scripts/codex-dispatch.sh` 相容 symlink shim → 真正 adapter 是 `adapters/codex/dispatch.sh`，移除 shim 並遷移外部 caller（[[CC-289]]）。Gate 在 release ≥ v0.5.0 才執行；屆時複查是否有其他 v0.3.0 deprecation 需一併清。User-requested 2026-06-01。關聯 [[CC-291]]、[[CC-289]]。 | release | 2026-06-01 | — | P2 | hygiene |
| CC-297 | ✅ closed 2026-06-02 | **[arch: register `reviewer` as a guard role — one fixed rule]** pr-gate 的 5 個 reviewers + synthesis 是會寫檔的 agent，但落點目前只靠 prompt 指示（「Only write OUTPUT_FILE」）+ codex `workspace-write` sandbox，**沒有硬 guard**——CC-291 generalization 的下一個實例（user 2026-06-01）。設計定調：**一個 `reviewer` role + 一條固定規則 = 只能寫 `.gate-results/` 目錄**，跨 tier-subset（用幾個 reviewer 是 orchestration 的事，guard 不列舉）與 parallel/sequential（兩模式都寫 `.gate-results/`，故綁**目錄**不綁檔名）統一套用。brief（`.gate-briefs/`）由 gate 腳本寫、**不算 reviewer**，排除在規則外。兩條 dispatch 路徑（codex + claude）**均採用顯式 `pmctl guard check --role reviewer`** 寫在 reviewer brief 裡，不走 auto PreToolUse hook（CC-291 uniform design）。`--output` 覆寫到 repo 外 = operator 信任逃生口，文件化。defense-in-depth（防 diff 內 prompt-injection 誘導 reviewer 亂寫），非阻塞。brief 位置統一見 [[CC-298]]。關聯 [[CC-291]]、[[CC-288]]、[[CC-298]]。**實作完成 pr:#218（open，awaiting merge）**。 | arch | 2026-06-01 | pr:#218 | P3 | design |
| CC-299 | ✅ closed 2026-06-01 | **[arch: 統一 executor dispatch 路徑 — codex-executor 與 claude-executor 都走外部 CLI dispatch]** 目前 `claude-executor` 走 Agent tool subagent + Claude 內建 Read/Edit/Write（直接操作），而 `codex-executor` 走 `codex-dispatch.sh` → Codex CLI。兩條路徑不一致。正確架構：兩者都走 `pmctl dispatch run --adapter <X> --brief-file /tmp/brief.md`，分別呼叫外部 CLI（codex CLI / `claude --print`）。`Agent(subagent_type="claude-executor")` 是錯誤用法——`claude-executor` 的正確角色是對 `adapters/claude/dispatch.sh` 的外部呼叫，不是 Claude 在自己內部扮演另一個 Claude。改造後：主線程一律用 `bash pmctl dispatch run --adapter codex/claude` 派發，不使用 Agent tool 執行 implementation 任務。影響範圍：`agents/claude-executor.md`（角色定義改寫）、`agents/codex-executor.md`（dispatch 路徑改為 `pmctl dispatch run`）、主線程 dispatch 呼叫點、`memory/feedback_codex_529_fallback.md`（529 fallback 規則更新：permission denied ≠ 529，應診斷根因）。Origin user 2026-06-01。關聯 [[CC-289]]（pmctl dispatch run）、[[CC-266]]（adapters/claude/dispatch.sh）、[[CC-291]]（executor role 定義）。 | arch | 2026-06-01 | — | P2 | design |
| CC-305 | ✅ closed 2026-06-02 | **[bug: concurrent pmctl dispatch runs race on latest.* symlinks → post-verify reads wrong .last]** 兩個 `pmctl dispatch run` 並行時各 adapter 都執行 `ln -sfn` 覆蓋 `latest.*`；`dispatch-post-verify.sh` 先檢查 `latest.last` 非空，此時可能已指向另一 adapter 剛建的空檔案 → `latest.last is empty` 假失敗。影響 pr-gate parallel fan-out 與所有並行 dispatch 場景。完整修法見 body。關聯 [[CC-289]]。 | ops/gate | 2026-06-01 | pr:#216 | P2 | — |
| CC-306 | 🟡 deferred | **[arch: extend CC-233 layer enforcer to runtime-named data paths in scripts/]** Guard against re-introducing `.codex-*`/`.claude-*` DATA directories under scripts/ (the optional follow-up deferred from CC-298). | arch | 2026-06-01 | — | P3 | design |
| CC-307 | 🟡 deferred | **[arch: pm role cross-runtime — guard 已 runtime-agnostic，但文件與 alias 仍暗示 pm = claude-only]** CC-291 的兩軸設計（role ⊥ runtime）明確要求 pm guard policy 不能綁 runtime。`hook-pm-write-guard.sh` 確實 runtime-agnostic（任何 runtime 套用同一規則）✓，且 `--role pm --runtime codex` CLI 路徑已可正常呼叫 ✓；但目前三個地方仍暗示 pm=claude-only：(1) deprecated `--profile pm` alias hardcode `runtime="claude"`，(2) `scripts/lib/pmctl-guard.sh` 說明說「currently claude-only」，(3) 無 codex-as-pm dispatch end-to-end 測試。修法：(1) alias 部分接受（deprecated, 將由 CC-296 移除，hardcode 是 convenience 不是設計限制）；(2) 把「currently claude-only」說明改為「guard policy is runtime-agnostic; no deployed codex-as-pm use case yet」以分清設計與現況；(3) 加 integration smoke test：`pmctl dispatch run --adapter codex --role pm` 可成功 dispatch。Origin user 2026-06-02。關聯 [[CC-291]]（two-axis design）、[[CC-296]]（alias sunset）、[[CC-215]]（pmctl dispatch run）。 | arch | 2026-06-02 | — | P3 | design |
| CC-298 | ✅ closed 2026-06-02 | **[arch: 統一 brief 落點 + 產物檔名去 runtime 化]** runtime 是 adapter 的事（CC-291/CC-233 同一界線），**資料產物不該綁 runtime 名**。現況半一致：dispatch brief 已 runtime-agnostic（兩 adapter 都吃 `--brief-file`，實際 `/tmp/brief-*.md`）✓；但 pr-gate had a runtime-named brief directory（`scripts/pr-gate.sh:360`）+ runtime-tokenized claude brief filenames（L495/L684）✗；`.agent-trace/codex-<ts>.jsonl`/`claude-<ts>` trace 檔名也帶 runtime（消費端 `latest.*` 已 agnostic）✗。目標：(1) brief 統一到**一個 runtime-agnostic 落點**，codex/claude 都讀同一處；(2) 生成的資料產物（brief / gate result / reviewer output）檔名去掉 runtime token，**改在檔案內容**（frontmatter/header）記錄哪個 model 執行。Scope 邊界：`adapters/codex/`、`adapters/claude/` 腳本目錄本就 runtime-specific（它們**是** adapter，CC-233 允許）——不在此列；executor-internal trace **格式**本就 runtime-specific（codex JSONL vs claude JSON），trace 檔名是否一併中性化待議（消費端已用 `latest.*`）。可考慮把 CC-233 layer enforcer 擴及「scripts/ 內 runtime-named 資料路徑」做防回歸。Origin user 2026-06-01。關聯 [[CC-291]]、[[CC-233]]、[[CC-289]]、[[CC-297]]。 | arch | 2026-06-01 | pr:#216 | P2 | design |

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

## CC-207 — Windows Git Bash symlink fallback: use mklink /J in install.sh（deferred）

**Problem**: On Git Bash (OSTYPE=msys/cygwin), `ln -s` silently falls back to file
copy rather than creating real symlinks. After pulling pm-dispatch updates, users
must re-run `bash install.sh` to sync the copies (83 files across agents/, commands/,
scripts/, .pm). This breaks the "pull = auto-sync" expectation that Linux/macOS/WSL2
users have.

**Why**: NTFS symlinks require Windows Developer Mode or `MSYS=winsymlinks:nativestrict`
which cannot be assumed for all users. Directory junctions (`mklink /J`) are available
without elevated privileges but require calling PowerShell from bash.
The current copy fallback is correct as a safety net; the missing piece is an explicit
Git Bash detection branch that uses junctions instead of silently falling back to copy.

**Requirement**:
1. `install.sh` detects Git Bash via `$OSTYPE == msys*` or `cygwin*`
2. Uses `powershell.exe -Command "cmd /c mklink /J ..."` for each per-file link target
   (`mklink /J` = directory junction; no admin or developer mode required)
3. Verified: junction survives PATH resolution and Claude Code session startup on Windows
4. `test-install.sh` gains a smoke test for the junction path (skip on non-Windows CI)
5. `docs/platform-support.md` updated to reflect auto-sync is restored

**Workaround**: after pulling updates, re-run `bash install.sh` to re-copy files.

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

## CC-260 — pr-gate.sh: dirty-worktree fail-loud preflight ✅ 2026-06-01

**See**: pr:#214

**Problem**: When a branch has committed changes, `scripts/pr-gate.sh` uses `git diff "$BASE"...HEAD` to build the reviewer brief stat. This silently omits uncommitted tracked changes (`git diff HEAD`) and untracked files. During CC-229 Gate 12, the brief stat did not include `install.sh` and `scripts/test-schema-task-mirrors-backlog.sh` which were in the dirty worktree but not yet committed.

**Why**: Gate reviewers can only assess what's in the brief. Silently omitting working-tree changes means new files and tracked modifications that haven't been committed are invisible to reviewers. This is especially impactful for long-running iterative gate sessions where fixes accumulate in the working tree before a final commit.

**Requirement**:
- Detect dirty worktree (tracked changes or non-gitignored untracked files) when the branch has committed `BASE...HEAD` changes.
- Without `--allow-dirty`, fail loud with exit 3 and guidance to commit first or opt into dirty review scope.
- With `--allow-dirty`, fold the working tree into scope: committed + uncommitted tracked changes via `git diff "$BASE"` and non-gitignored untracked files via `git ls-files --others --exclude-standard`.
- Preserve the existing dirty-only-no-commit behavior: no preflight failure because the working-tree fallback already reviews those changes.

**Acceptance**:
1. Committed `BASE...HEAD` changes + dirty worktree without `--allow-dirty` → exit 3 with guidance.
2. `--allow-dirty` folds committed + working-tree changes into review scope.
3. Dirty-only-no-commit worktrees are still reviewed by the existing fallback.
4. `bash scripts/test-pr-gate.sh` → exit 0.
5. `bash scripts/run-all-tests.sh` → exit 0.

**Milestone**: v0.3.x (post-M1); prioritize before the next multi-gate iterative fix session.

**Priority**: P2 — operational correctness for gate reviews; detected as real drift in CC-229 gate cycle.

---

## CC-262 — Executor isolation 抽象層：`isolation_level` 欄位 + adapter 轉譯契約（deferred）

**Problem**: 現行 brief schema 中 `sandbox`、`approval`、`skip_git_check` 是 Codex 原生欄位，直接出現在 PM 撰寫的 brief 裡。當 executor 為 `claude` 時，PM 必須填入 canonical no-op 值（`workspace-write` / `never` / `false`）——這是 leaky abstraction：brief 層洩漏了底層 executor 的實作細節。

**Why**: 用戶設計目標：「功能與執行環境分離」。Brief 應表達隔離 *意圖*（需要什麼程度的保護），adapter 層負責把意圖翻譯成各 executor 的原生機制。這樣未來加入新 executor（opencode、antigravity）只需新增一個 adapter map，不需改動 brief schema 或 PM 撰寫規則。與 v0.3.0 的 `adapters/` named-slot 架構完全吻合。

**Requirement**:
- `core/policy/`（CC-231 延伸）：新增 `isolation_level` enum，值為 `none | read-only | workspace-write | sandboxed`，附語意定義（none=無限制；read-only=不寫 FS；workspace-write=僅寫 project dir；sandboxed=完整隔離）
- `adapters/codex/isolation-map.yaml`：每個 `isolation_level` 值 → `{sandbox, approval, skip_git_check}` 原生欄位的對應表（v0.4.0，暫緩）
- `adapters/claude/isolation-map.yaml`：每個 `isolation_level` 值 → no-op（claude-executor 無 sandbox flags）（v0.3.0 M1 殘留，當前範圍）
- `agents/project-pm.md`：PM brief template 改寫 `isolation_level:` 取代三個原生欄位；說明三個原生欄位為 adapter-generated，PM 不直接填寫
- `scripts/codex-dispatch.sh`：dispatch 前讀取 `adapters/codex/isolation-map.yaml` 展開 `isolation_level` → 原生欄位；遇未知值 → 立即 exit 1 with error

**Acceptance (M1 scope — adapters/claude only)**:
1. `grep -q "isolation_level" core/policy/executor-enum.yaml` → match（或對應 policy 檔案）
2. `cat adapters/claude/isolation-map.yaml` → 檔案存在，包含 4 個 no-op 映射
3. `bash scripts/run-all-tests.sh` → exit 0

**Acceptance (M2 scope — deferred)**:
4. `grep "isolation_level" agents/project-pm.md` → 至少一個 match；`grep 'sandbox.*workspace-write' agents/project-pm.md` → PM brief template 區段無此行
5. `bash scripts/test-codex-dispatch.sh` → exit 0（含 isolation_level 展開測試）

**Acceptance (v0.4.0 scope — adapters/codex deferred)**:
6. `cat adapters/codex/isolation-map.yaml` → 包含全部 4 個 isolation_level 的映射

**Scope revision 2026-05-25**: adapters/codex 移至 v0.4.0；當前範圍為 M1（core/policy/ enum + adapters/claude/ no-op map）。

**M1 shipped (2026-05-25, PR #162)**: `core/policy/isolation-level.yaml` and `adapters/claude/isolation-map.yaml` created. M2 (codex-dispatch.sh expansion) and v0.4.0 (adapters/codex) remain deferred.

---

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

## CC-274 — docs: reconcile CC-262 planning text with shipped isolation implementation

**Problem**: CC-262 in BACKLOG.md has three stale areas flagged by Round 11 gate critic:
1. Requirement block lists only 4 enum values (`none | read-only | workspace-write | sandboxed`) — `workspace-network` (shipped in M2 / PR #175) is missing.
2. Sandboxed semantic still says "完整隔離" but the Codex adapter maps it to `workspace-write` (best-effort, no true ephemeral mode); `core/policy/isolation-level.yaml` and adapter comments now reflect this.
3. Acceptance (M2) and Acceptance (v0.4.0) still mark `codex-dispatch.sh` expansion and `adapters/codex/isolation-map.yaml` as "deferred" — both shipped in PR #175.

**Fix**:
- Update CC-262 Requirement block to list all 5 enum values including `workspace-network`.
- Correct sandboxed semantic to "best-effort strongest isolation; Codex maps to workspace-write".
- Mark M2 and v0.4.0 acceptance criteria as landed (PR #175).

**area**: docs
**Priority**: P2 — stale planning text causes confusion when reading the BACKLOG for future isolation work.

**Raised by**: critic [medium] × 3, Round 11 gate (feat/cc206-gate-hooks).

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

**Problem**: `hook-codex-bash-guard.sh:54` defaults read-root to `$HOME/github`; repos under `~/Documents/github/` or arbitrary Windows paths are not covered. `CLAUDE_HOOK_CODEX_READ_ROOTS` env override exists but the wrong default silently restricts hooks.
**Fix**: Derive from `PM_DISPATCH_REPO` parent or remove the hardcoded default.

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

## CC-293 — [arch] lift default/config resolution into pmctl runtime ✅ 2026-06-02

**See**: pr:#216

**Problem**: `adapters/codex/dispatch.sh` owned default-model selection and `dispatch.default_model` config precedence — policy-like resolution in a thin adapter, flagged by critic + architecture-reviewer at CC-292 gate. Deferred until a second adapter needed the same config axis.

**Trigger met**: adding `adapters/claude/dispatch.sh` (CC-305 / pr:#216) created the second shared dispatch config axis, fulfilling the deferral condition.

**Resolution**: `scripts/lib/pmctl-config.sh` centralizes config parsing. `pmctl-dispatch.sh` calls `pm_config_load` in `pmctl_dispatch_run` and exports `PM_CFG_TIMEOUT` + `PM_CFG_DEFAULT_MODEL` to the adapter subprocess — adapters receive config values via env rather than sourcing the config file themselves. Both adapters dropped all config-loading code; their existing `elif [[ -n "${PM_CFG_TIMEOUT:-}" ]]` / `${PM_CFG_DEFAULT_MODEL:-}` branches now consume the exported values. Precedence maintained: `--timeout`/`--model` flags (parsed last) win over everything; adapter-specific env vars (`CODEX_DISPATCH_TIMEOUT`, `CLAUDE_DISPATCH_TIMEOUT`) are next; pmctl-exported config (`PM_CFG_TIMEOUT`, `PM_CFG_DEFAULT_MODEL`) is third; adapter built-in default (1200 / `default` alias) is fallback for direct invocations without pmctl.

**Cross-link**: `[[CC-292]]` (origin), `[[CC-289]]` (`pmctl dispatch run`), `[[CC-211]]` (v0.3.0 arch epic), `[[CC-305]]` (trigger).


## CC-296 — [release] v0.3.0 deprecation sunset — remove after 2 official releases 🟡 deferred

**Origin (user, 2026-06-01)**: 「這次 0.3.0 的版本有些需要 deprecate 的部分，請幫我在 2 次正式版本之後開始進行移除。」v0.3.0 引入的 back-compat 面要在經過兩個正式版本（v0.3.0 + v0.4.0）後、於 **v0.5.0** 移除。

**Sunset target**: release ≥ **v0.5.0**. Do NOT remove earlier — the deprecation must stay live through v0.3.0 and v0.4.0 so external callers have two releases to migrate.

**Items to remove**:
1. **`pmctl guard check --profile <pm|codex|claude>`** alias (`scripts/lib/pmctl-guard.sh`): the deprecated profile→`(role,runtime)` mapping + the stderr deprecation warning + the `--profile`/`--role` mutual-exclusion branch. Migrate any remaining caller to `--role <pm|executor>` + `--runtime <codex|claude>`. Drop the `deprecated-profile-*` / `profile-role-mutex` back-compat cases from `scripts/test-pmctl-guard.sh` (keep the `--role`/`--runtime` cases). Origin [[CC-291]].
2. **`scripts/codex-dispatch.sh` compatibility symlink shim**: the canonical adapter is `adapters/codex/dispatch.sh` ([[CC-289]]). Internal callers already use the real path (`executor-router` emits it). Remove the shim once external references (agent docs using the `~/github/.../scripts/codex-dispatch.sh` form, `~/.claude/settings.json` allow rules) are migrated to the adapter path — coordinate with agent-doc updates so dispatch keeps working.

**On removal**: re-scan for any other v0.3.0 `### Deprecated` CHANGELOG entries and clear them in the same sweep; move the CHANGELOG `### Deprecated` items to `### Removed` for the v0.5.0 entry.

**Cross-link**: `[[CC-291]]` (`--profile` alias origin), `[[CC-289]]` (codex-dispatch shim origin).

## CC-297 — [arch] register `reviewer` as a guard role ✅ 2026-06-02

**See**: pr:#218 (open, gate GO 2026-06-02)

**Origin (user, 2026-06-01, during CC-291 work)**: 「pr-gate 應該也算是一種 role 你覺得呢」+ 隨後的挑論：reviewer 最多 5 個方向、不一定全用；又有 parallel/sequential 差異；user 傾向「**統一套用一條固定防範規則**」。對——pr-gate 的 reviewers + synthesis 是會寫檔、需要 guard 的 agent，正是 CC-291 generalization 的下一個具體實例，繼 `pm` / `executor` 之後。

**Design（定調 2026-06-01）— 一個 role、一條固定規則、綁目錄**：
- **一個 `reviewer` guard-role**，對應 5 個 reviewer agent-type + synthesis。漂亮示範 CC-291 的「role ≠ agent-type」：多 agent-type → 一個 guard-role。
- **固定規則 = 只能 Write 到 `.gate-results/` 目錄**。綁**目錄不綁檔名**：parallel 寫 `.gate-results/reviewer-<r>-<ts>.md`、sequential 寫 `.gate-results/gate-<ts>.md`，兩模式一條規則。
- **跨 tier-subset 統一**：用幾個 / 哪幾個 reviewer 是 tier/orchestration 的決定，guard 不列舉 reviewer。
- **brief 排除**：`.gate-briefs/` 由 pr-gate.sh / orchestrator 寫，不是 reviewer 寫，不放進 reviewer 規則。
- **兩條 dispatch 路徑均用顯式 `pmctl guard check`**（設計演進 2026-06-02）：codex-route 和 claude-route reviewer brief 都內嵌 `pmctl guard check --role reviewer --runtime ${EXECUTOR} --event pre-write --file ${OUTPUT_FILE}` 約束；**不走 auto PreToolUse hook**（CC-291 uniform explicit design）。
- **`--output` 覆寫例外**：operator 信任逃生口，文件化。

**Resolution（pr:#218）**:
- `scripts/hook-reviewer-write-guard.sh` — policy backing script，reviewer Write/Edit 必須落在 `.gate-results/`；`CLAUDE_HOOK_REVIEWER_GUARD=off` bypass；audit log
- `pmctl guard check` 新增 `--role reviewer`；所有 role（含 pm）現在都需要 `--runtime`；pm/reviewer runtime 驗 `codex|claude` enum
- Sequential + parallel reviewer brief 均內嵌顯式 `pmctl guard check` 約束
- `cli/pmctl` 修正 symlink REPO_ROOT 解析（loop-based resolver，覆蓋相對 symlink 路徑）
- `docs/spikes/fanout-dispatch-spike.md` — fan-out 架構 spike（推薦 v0.4.0 Approach B: `pmctl gate run`）
- Tests: test-hooks.sh 346/0, test-pmctl-guard.sh 57/0, test-pr-gate.sh 78/0; gate GO (standard tier)

**Cross-link**: `[[CC-291]]`（role-keyed registry）、`[[CC-288]]`（guard surface）、`[[CC-298]]`（brief 位置統一）。

## CC-298 — [arch] 統一 brief 落點 + 產物檔名去 runtime 化 ✅ 2026-06-02

**See**: pr:#216

**Resolution**: pr-gate brief output moved to `.gate-briefs/` (runtime-agnostic shared directory); brief filenames no longer carry runtime tokens (`pr-gate-<ts>.md` rather than `codex-pr-gate-<ts>.md`); `.codex-briefs/` runtime-named historical directory removed. Defense-in-depth enforcer extension (preventing re-introduction of runtime-named data paths under `scripts/`) captured as separate deferred follow-up in [[CC-306]].

**Origin (user, 2026-06-01, during CC-297 discussion)**: User flagged the runtime-named brief directory and runtime-tokenized artifact names; the target was one shared brief location for claude/codex and an in-file record of which model executed. This is CC-291（runtime 是 adapter 的事）/ CC-233（core 不放 CLI-named 檔）同一條界線，延伸到**資料產物**。

**現況（grounded）**:
- ✓ dispatch brief 已 runtime-agnostic：`adapters/codex/dispatch.sh` 與 `adapters/claude/dispatch.sh` 都收 `--brief-file`，guard 政策對兩者都是 `/tmp/brief-*.md`（讀取端已統一）。
- ✗ pr-gate：the old `BRIEF_DIR` used a runtime-named brief directory（`scripts/pr-gate.sh:360`），且 claude route 的 brief 檔名帶 runtime（combined/reviewer variants，L495/L684）。
- ✗ trace 檔名帶 runtime：`.agent-trace/codex-<ts>.{jsonl,last,stderr}`、`claude-<ts>.*`（消費端讀 `latest.*` symlink，已 agnostic）。

**Target**:
1. **brief 落點統一**：pr-gate 的 brief 目錄改成 runtime-agnostic 目錄（例如 `.gate-briefs/` 或與 dispatch 共用一個 `.pm-briefs/`）；brief 檔名去掉 `claude`/`codex` token。codex/claude 都從同一處讀。
2. **產物檔名去 runtime 化**：生成的資料產物（brief、gate result、reviewer output）檔名不帶 runtime；**執行的 model 記在檔案內容**（gate result frontmatter 已有 `reviewers:` / `mode:`，可加 per-artifact `executed_by:`；brief header 加一行）。

**Scope 邊界（別過度延伸）**:
- `adapters/<runtime>/` 腳本目錄本就 runtime-specific——它們**是** adapter，CC-233 明確允許 adapter 以 runtime 命名。不在此票。
- `scripts/codex-dispatch.sh` / `scripts/claude-dispatch.sh` 是 adapter 入口（shim 已由 [[CC-296]] 排程移除）——屬 adapter 名，不在此票。
- executor-internal **trace 格式**本就 runtime-specific（codex JSONL vs claude JSON）；trace **檔名**是否一併中性化待議——消費端已用 `latest.*`，價值較低，可作 forensic 保留 runtime 名或一併改。實作時定。

**防回歸（可選）**: 考慮把 [[CC-233]] 的 layer-boundary enforcer 擴及「`scripts/` 內以 runtime 命名的**資料路徑**」，避免日後又長出 `.codex-*` 資料目錄。

**Why deferred / P2**: 一致性清理，user-flagged；非阻塞當前流程，但會動到 pr-gate + trace 命名的多處 caller，需一次到位 + 測試。先讓 CC-291 落地。

**Cross-link**: `[[CC-291]]`（runtime=adapter concern）、`[[CC-233]]`（no CLI-named files）、`[[CC-289]]`（dispatch orchestrator）、`[[CC-297]]`（reviewer role，brief 排除）。

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

**Cross-link**: `[[CC-233]]`, `[[CC-298]]`.

## CC-305 — [ops/gate] concurrent pmctl dispatch runs race on latest.* symlinks ✅ 2026-06-02

**See**: pr:#216

**Problem**: When two or more `pmctl dispatch run` calls target the same `<work_dir>/.agent-trace/` (e.g. pr-gate parallel reviewer fan-out), each adapter calls `ln -sfn <adapter>-<ts>.last latest.last` on finish. A second dispatch that finishes between the first adapter's end and its post-verify check silently overwrites `latest.*` → `dispatch-post-verify.sh` sees an empty or wrong `.last` → `latest.last is empty` false failure, or worse, verifies the wrong run's output.

Discovered 2026-06-01: concurrent codex + claude smoke test; codex exit 0 and correct output, but post-verify failed because the claude adapter had already overwritten `latest.last` with an empty file.

**Root cause**: `latest.*` is shared mutable global state per working directory. Any actor that touches it races with every concurrent dispatch.

**Resolution (#216, 2026-06-02)**: Implemented point 2 (pmctl owns the output contract) — the simpler sufficient fix. `pmctl dispatch run` now tees adapter stdout to a temp file, parses the per-run `last:` / `stderr:` footer lines, and passes them to `dispatch-post-verify.sh` via `--last`/`--stderr` flags. Post-verify uses explicit per-run paths; `latest.*` symlinks remain as human-observation convenience only. Per-run isolated subdirectory (point 1) deferred — not needed once pmctl consumes the explicit footer. Regression tests added: stale `latest.last` avoidance + tee `PIPESTATUS` propagation. `docs/executor-contract.md` updated with footer handoff subsection.

Also shipped in same PR: `scripts/lib/pmctl-config.sh` shared config loader + `sw_append_dispatch_run` shared run-row builder (eliminating ~100 LOC of adapter duplication), `pmctl_validate_adapter_name` regex fix (`^[a-z][a-z0-9_-]*$`), 5 new test cases.

**Acceptance** (all met):
- Stale `latest.last` no longer causes post-verify false failure (CC-305 regression case passes).
- Footer exit code propagated correctly through tee pipeline.
- `scripts/run-all-tests.sh`: 40 passed, 0 failed.

**Cross-link**: `[[CC-289]]` (pmctl dispatch run), `[[CC-299]]` (unified dispatch routes), `[[CC-264]]` (dispatch-post-verify.sh), `[[CC-293]]` (config dedup).

## CC-299 — [arch] 統一 executor dispatch 路徑 ✅ 2026-06-01

**See**: pr:#213
