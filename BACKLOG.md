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
| CC-104o | 🟢 superseded 2026-05-20 | **[Windows dogfood r3 finding]** Microsoft Store python3 reparse-point stub (`/c/Users/<user>/AppData/Local/Microsoft/WindowsApps/python3.exe`) returns exit 49 in non-interactive contexts → 36 preflight cases FAIL (every `inject-hook/*`, `session-hook/*`, `rl-hook/*`, `stop_*`, `mem-recall/format-validator`, `cross-cmd/*` because hook scripts internally call python3). Fix: install.sh / install-hooks.sh preflight detects the MS Store stub via `python3 -c 'pass'` exit-49 probe, hard-fail with platform-aware hint (`winget install Python.Python.3.12` + "remove WindowsApps stub from PATH or order real Python first"). Required before Windows = Supported flag flip — fork users on Windows hit this on first install. Superseded by CC-104t which eliminates python3 entirely via jq rewrite. | ops | 2026-05-18 | — | — | oss |
| CC-104r | ⏸ deferred | **[Windows dogfood r3 finding]** `hook-tool-trace.sh` performance_budget assertion: 27990 ms actual vs 3500 ms budget on Windows native filesystem (WSL UNC path `\\wsl.localhost\...` is ~8× slower than local disk). Not a pm-dispatch bug — physical filesystem characteristic. Fix is two-part: (a) `docs/platform-support.md` warns "install on local disk, avoid cross-WSL/native FS boundaries"; (b) preflight detects UNC path → prints warning and skips budget assertion (10 lines). Polish, not blocker | docs/ops | 2026-05-18 | — | — | oss |
| CC-104s | 🟡 deferred | **[Windows dogfood r3 finding]** `hook-tool-trace.sh:195` `read_home_path_basename_only` returns `first_arg_or_skill:null` on Windows because case-glob `"$HOME"/*` uses forward slashes (`/c/Users/Lien Chen`) but harness sends `file_path` with backslashes (`C:\Users\Lien Chen\...`); both case branches miss. Fix: normalize input path via `cygpath`/string-replace (`\\` → `/`, `C:\Users\...` → `/c/Users/...`) before case-match. Polish — affects trace JSON observability only, not functionality | ops/portability | 2026-05-18 | — | — | oss |
| CC-205 | ⏸ deferred | `/pm` dual-executor planning: `--executor auto/codex/claude` flag（與 pr-gate 介面對齊）+ `dispatch_handover_v1` 加 `executor` 欄位；加 `--parallel-plan` mode — PM 偵測 arch/multi-subsystem/first-design 特徵時，在 dispatch 前暫停並詢問用戶是否啟用；確認後 codex 與 claude 各自獨立規劃，current model 合成一份 best-of 計劃輸出；`/pm --parallel-plan` flag 可跳過確認步驟直接 parallel dispatch | process | 2026-05-20 | — | P2 | design |
| CC-209 | 🟢 someday | **[context-enrichment spike: codegraph evaluation]** Evaluate colbymchenry/codegraph (MIT, TypeScript, 18.8k★, active) as a **context-pack** source (CC-232). Phase 1 spike `docs/spikes/cc209-codegraph-phase1.md` (2026-05-24): codex returned RED on misapplied rubric; **main-thread validation amended to AMBER** — install ✓, license MIT ✓, API works ✓, BUT pm-dispatch is not codegraph's intended target (bash/markdown stack not supported). Phase 2 (benchmark) deferred until brief re-specifies target as TS/JS/Python/Go codebase. Process lessons: rubric must enumerate sandbox-block as local-env; spike brief must specify test target separately from working directory; main-thread validation mandatory for verdict-issuing spikes. | ops/token | 2026-05-21 | pr:TBD | P3 | spike |
| CC-210 | ⏸ deferred | **[uninstall blast-radius guard]** `uninstall.sh` currently allows `$HOME/.claude` itself to pass the managed-root safety guard (dst must start with managed root); a malformed or tampered copy-mode manifest entry matching the directory hash could remove the entire Claude config tree. Fix: add an explicit `[[ "$dst" == "$managed_root" ]]` rejection check before the startswith guard, so only strict descendants of the managed root are deletable. Raised by risk-reviewer in PR #110 gate as [medium] advisory. | ops | 2026-05-21 | pr:#110 | P3 | hygiene |
| CC-211 | ⏸ deferred | **[v0.3.0 architecture epic]** Restructure pm-dispatch into a schema-first / state-first / adapter-thin PM runtime — four layers: `core/` (data + policy) → `runtime/` (`pmctl` spine) → `adapters/` (delivery) → `mcp/` (bridge, v0.4.0). Absorbs Multica / Memori / Superpowers / AI Night Shift concepts into one state substrate. Broken into milestones — live **M0–M6** in MILESTONES.md (synthesis §6 is the original M0–M5 cut); runtime is realized as `cli/pmctl` (not a `runtime/` dir). See docs/architecture/v0.3.0-synthesis.md **Conformance status** for as-built drift (codex+claude adapters shipped; state-first / `mcp/` still open). Umbrella epic for CC-229..CC-237 + existing CC-059/060/061/200-204/215/217-220. | arch/portability | 2026-05-21 | — | P1 | design |
| CC-215 | ✅ done | **[pmctl — core CLI entrypoint]** Implement `cli/pmctl` as the language-agnostic runtime for pm-dispatch. Interface: `pmctl task create/claim/dispatch/status/review`, `pmctl decision add`, `pmctl backlog sync`, `pmctl trace tail`, `pmctl guard check --event <pre-write\|pre-bash\|post-task> --file/--command <val>`, `pmctl adapter generate <claude\|codex\|antigravity\|opencode>`. AI CLI adapters become thin wrappers: Claude `/pm task-123` → `pmctl task dispatch task-123 --agent claude`; Codex equivalent calls the same binary. Guard logic moves from Claude-only hooks into pmctl so any CLI without hook support can call `pmctl guard check` from a command wrapper or `pmctl safe-bash "cmd"`. Adapter generator (`pmctl adapter generate`) produces per-CLI config from core agent definitions — prevents 4-way drift. **Shipped**: `adapter generate` (#171) + `dispatch run` (#194); `task create/show/list/update` + `decision add` (#242); `task claim/dispatch/status/review` + `safe bash` + `validate brief` (#252). All planned subcommands complete. Depends on CC-211. | arch/portability | 2026-05-21 | pr:#171,pr:#242,pr:#252 | P2 | design |
| CC-216 | ⏸ deferred | **[MCP server — pm-dispatch-server]** **Deferred to v0.4.0**. (AS-BUILT 2026-05-31: the `mcp/README.md` spec originally planned for v0.3.0 was **not** written — `mcp/` is absent and `pmctl` has no general `--json`; the whole MCP surface incl. the spec is deferred. See synthesis Conformance status §B.) The server is built once `pmctl` is stable. Implement `mcp/pm-dispatch-server` exposing pm-dispatch operations as MCP tools: pm_list_tasks, pm_read_task, pm_create_task, pm_update_status, pm_add_decision, pm_request_review, pm_dispatch_to_agent, pm_read_trace, pm_guard_check. Enables Claude Code, OpenCode, Antigravity CLI, and any future MCP-capable AI tool to share one PM system without per-tool command wiring. MCP becomes the universal bridge; adapters handle only auth / config / format differences. Implementation path: thin Node.js or Python wrapper over pmctl subprocesses (avoids duplicating logic), or native bash MCP server once spec stabilises. Depends on CC-211, CC-215 (pmctl stable before wrapping). | arch/portability | 2026-05-21 | — | — | design |
| CC-220 | ⏸ deferred | **[spike agent + `/spike` skill]** Implement `agents/spike.md` and `commands/spike.md`. Spike agent is a **planner** (like `project-pm`): reads a BACKLOG spike ticket, plans 2–3 investigation angles, returns a `spike_plan` block; the **main thread** fans out one Agent per angle (subagents cannot spawn subagents); the spike agent is re-invoked to synthesise findings into `docs/spikes/CC-NNN.md` and update the `Result log`. Modeled on `/pr-gate`'s reviewer fan-out. v0.3.0 M5. Depends on CC-218. | process/DX | 2026-05-21 | — | P3 | design |
| CC-212 | ⏸ deferred | **[fix: harden Windows junction install — path-passing + idempotency]** 兩個 Windows junction hardening 合併一 PR（吸收 CC-213）：(A) `make_junction_windows()` 改用 `PM_DISPATCH_MAKE_SRC`/`PM_DISPATCH_MAKE_DST` env var 傳路徑，統一 PowerShell boundary 慣例；(B) `install_dir_junction()` 加 manifest-driven idempotency probe，不再依賴 `-L` 偵測。 | ops/portability | 2026-05-21 | pr:#112 | P3 | oss |
| CC-214 | ⏸ deferred | **[CC-207 advise follow-up]** `docs/platform-support.md` 手動 uninstall 說明使用裸 `bash uninstall.sh`，在非 repo-root 工作目錄下執行會找不到腳本；應改為 `bash "${PM_DISPATCH_REPO}/uninstall.sh"` 形式（與文件其他範例一致）。Raised by critic in gate-20260521-115634 as [low] advise. | ops/DX | 2026-05-21 | pr:#112 | P3 | oss |
| CC-225 | ⏸ deferred | **[claude-executor result observability]** `claude-executor` task output 寫入 session-scoped `/tmp/` 路徑，不進 REPO、不可跨 session 回溯，且無法 git diff 追蹤執行歷史。設計目標：主線程在 claude-executor 完成後把 brief 路徑、result 摘要、exit status 寫入 REPO 固定目錄（格式與 `.gate-results/` 一致），作為 CC-211 / CC-216 MCP 架構抽離的前提。sub-concern of CC-211. | ops | 2026-05-22 | — | P3 | design |
| CC-227 | ⏸ deferred | **[refactor: extract yaml-frontmatter lib + shared validation helpers]** 把 `check_frontmatter()` 與 shared helpers（dq-escape/adjacent-quote/empty-entry，原 CC-226 範圍）一起搬到 `scripts/lib/yaml-frontmatter.sh`；`lint-frontmatter.sh` 成薄 CLI 包裝；`doctor.sh` 可 source lib 取代 fork subprocess。CC-226 已合併入本票。 | arch/reuse | 2026-05-22 | pr:#119 | P3 | oss |
| CC-228 | 🟢 superseded 2026-06-08 | **[BACKLOG validator-debt cleanup]** `pm/scripts/validate.sh` exits 1 on `main` with ~31 pre-existing E-codes: E-INDEX-MISMATCH (CC-104d/e/f/g/j/k/m/r/s in index but no body section), E-AREA-ENUM (slash-combined / non-enum areas e.g. `arch`/`config`/`schema` on CC-052/060/104v/203/204), E-REFS-PREFIX (bare `CC-NNN` refs on CC-059/060/061/064/066). Resolve per class: add missing sections or drop index rows; widen the area enum (e.g. add `arch`) or rewrite rows; fix ref prefixes. Surfaced during CC-222 close-out. | process | 2026-05-22 | roadmap:CC-277 | P2 | hygiene |
| CC-234 | 🔵 active | **[v0.5.0 P2 write-half: memory v2 — event-derived semantic cards]** Point `/mem-distill` at `events.jsonl` (the action stream — tool calls, decisions, gate verdicts) alongside `episodes.jsonl`, distilling both into semantic memory cards. This is the write side of the v0.5.0 memory read+write loop; semantic transformation lives here, not in the index. Four-tier card system unchanged; gives the event tier a schema (Memori-inspired). Acceptance: a card written here is retrievable through the CC-354 read side (loop closes). | memory | 2026-05-22 | — | P2 | design |
| CC-235 | ⏸ deferred | **[v0.3.0 M4: tiered lifecycle gate]** Make the spec→design→plan discipline (today advisory in `commands/pre-impl.md` + `agents/project-pm.md`) a `pmctl`-enforced Task lifecycle gate **graded by task size** (mirrors the pr-gate express/standard/full tiers): trivial/mechanical → no gate; small → one-line intent+acceptance; substantial (≥3 behavioral units, or touches a shared module, or new interface) → full `/pre-impl` design artifact before `claimed→in-progress`. Superpowers-inspired. | process | 2026-05-22 | — | P2 | design |
| CC-236 | 🟢 someday | **[pmctl report — away-from-keyboard state roll-up]** A `pmctl report` rolling up state since last invocation (open tasks, blockers, last gate verdict, recent runs). Deprioritized 2026-05-22: the maintainer does not run agents unattended, so a "morning report" time-gap framing has low current need; on-demand status is already part of the `pmctl` surface (CC-215). Revisit if the workflow ever includes overnight / away dispatch. | ux | 2026-05-22 | — | — | design |
| CC-237 | ✅ closed 2026-06-09 | **[v0.5.0 P1: context-enricher interface]** Define `context_hit_v1` (source_domain knowledge/repo/state, why_relevant, trust_level, refs) extending the CC-232 context-pack schema; schema_version bumped 1→2 (additive; v1 packs remain valid via enum). Delivers the interface contract; the assembled `pmctl context pack` output is CC-239. builtin-index backend is CC-338. | ux | 2026-05-22 | pr:#253 | P1 | design |
| CC-238 | ⏸ deferred | **[/pr-gate claude-route fan-out hardening]** CC-217 made the `/pr-gate` claude-executor reviewer/synthesis fan-out run detached (`run_in_background`). Gate advisories on the new flow (CC-217 gate, gate-20260523): (a) no timeout/fallback if a reviewer agent never reports completion → indefinite wait; (b) single fan-out step weakens per-reviewer failure attribution on partial failure; (c) no test artifact validates background completion / relay ordering. Add a completion timeout + partial-failure attribution + test coverage for the claude-route fan-out. | gate | 2026-05-23 | pr:#124 | P3 | oss |
| CC-239 | ✅ closed 2026-06-10 | **[v0.5.0 P2: reuse-scan capability — first consumer of repo-index]** New work keeps duplicating existing helpers / scripts / patterns (the recurring CC-200..204 reuse debt) because nothing surfaces "this already exists" before a brief is written. A dedicated reuse/refactor *agent* was considered and rejected (subagents cannot dispatch → it would only duplicate `project-pm`; refactor is not a distinct cognitive mode; refactor expertise already lives in architecture/risk/critic reviewers + the `dispatch-brief.md` refactor skeleton). The right shape is a **reuse-scan capability** invoked during PM briefing — queries the codebase for prior art via context-pack and emits a reuse report the brief incorporates. First consumer of the repo index (CC-338) through the CC-237 interface. **See**: pr:#256 | reuse | 2026-05-23 | pr:#256 | P2 | design |
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
| CC-270 | 🟡 deferred | **[test: concurrent pmctl adapter generate guard]** Two simultaneous `pmctl adapter generate <same-name>` runs can race: the precheck+mkdir+trap sequence is not atomic. Blast radius: one run may delete another's partial output; reproducible by deleting `adapters/<name>` and rerunning. Deferred — single-developer workflow makes this low-probability; fix with atomic mkdir using `mkdir` exit-code guard when needed. | test/ops | 2026-05-28 | — | P3 | — |
| CC-272 | ✅ done | **[docs: executor contract cleanup bundle]** 兩個 executor 文件噪音問題合併處理（吸收 CC-268）：(A) brief template 移除 git commit block — executor 回報 false partial；改為主線程 commit delegation 文件化；(B) run_in_background 默認 async 升格行為文件化。目標：`docs/dispatch-brief.md` + `docs/executor-contract.md` 一次更新。 | process/DX | 2026-05-28 | — | P1 | — |
| CC-273 | 🟡 deferred | **[arch: unified lifecycle hook event spec]** CC-206 只在 gate 層加了 pre/post-gate hooks。如果未來多個工具（dispatch、validate 等）都需要 hook 點，應定義統一的 lifecycle event 命名規範（如 `.pm-dispatch/hooks/<event>.sh`）和呼叫合約，而非在每個腳本各自加 pre/post block。目前無需求，等有第二個 hook 點需求時再設計。 | arch/gate | 2026-05-28 | — | P3 | — |
| CC-276 | 🟡 deferred | **[feat: persistent gate override declarations]** 每輪 gate 重開 fresh session，已接受的 risk override 必須重新聲明。支援 `--override-file` 或自動探索 `.gate-overrides.md`，inject 到 reviewer prompt 前置脈絡，避免已接受的 block 重複出現。 | gate/process | 2026-05-29 | — | P2 | — |
| CC-285 | 🟡 deferred | **[archiver safe-drop: don't drop a terminal row whose body exists nowhere]** `scripts/archive-closed-backlog.sh` currently drops a terminal index row even when no body section exists in BACKLOG.md and none is in BACKLOG-ARCHIVE.md (warns to stderr). In a valid backlog `validate.sh`'s index↔body 1:1 invariant prevents this, and it is git-recoverable — recorded as accepted tradeoff in DECISIONS 2026-05-30. Defense-in-depth follow-up: keep the row + emit a loud warning when the body is in neither file, leaving it for manual reconciliation rather than removing it. Surfaced by pr-gate critic on #186. | ops | 2026-05-30 | — | P3 | hygiene |
| CC-286 | 🟡 deferred | **[pmctl: prefix-generic next-id derivation]** `scripts/pm-prep-snapshot.sh` derives `backlog_next_id` CC-only (it emits `CC-NNN`); under the working-set contract it scans BACKLOG.md + BACKLOG-ARCHIVE.md for the max, but only `CC-` IDs. A cross-repo next-id (other prefixes: JS-, PA-) must be prefix-derived and centralized in pmctl, scanning both working-set and archive. Retire pm-prep-snapshot's CC-hardcoded derivation when `pmctl backlog`/next-id lands. Surfaced by pr-gate critic+architecture on #186. | arch | 2026-05-30 | — | P3 | design |
| CC-296 | 🟡 deferred | **[chore: v0.3.0 deprecation sunset — remove after 2 official releases]** 移除 v0.3.0 引入的 deprecated 面，sunset 目標 **v0.5.0**（經 v0.3.0 + v0.4.0 兩個正式版本後）。(1) `pmctl guard check --profile pm/codex/claude` 別名 → 全部 caller 改 `--role`/`--runtime`，移除 alias + deprecation warning + back-compat 測試（[[CC-291]]）。(2) `scripts/codex-dispatch.sh` 相容 symlink shim → 真正 adapter 是 `adapters/codex/dispatch.sh`，移除 shim 並遷移外部 caller（[[CC-289]]）。Gate 在 release ≥ v0.5.0 才執行；屆時複查是否有其他 v0.3.0 deprecation 需一併清。User-requested 2026-06-01。關聯 [[CC-291]]、[[CC-289]]。 | release | 2026-06-01 | — | P2 | hygiene |
| CC-306 | 🟡 deferred | **[arch: extend CC-233 layer enforcer to runtime-named data paths in scripts/]** Guard against re-introducing `.codex-*`/`.claude-*` DATA directories under scripts/ (the optional follow-up deferred from CC-298). | arch | 2026-06-01 | — | P3 | design |
| CC-307 | 🟡 deferred | **[arch: pm role cross-runtime — guard 已 runtime-agnostic，但文件與 alias 仍暗示 pm = claude-only]** CC-291 的兩軸設計（role ⊥ runtime）明確要求 pm guard policy 不能綁 runtime。`hook-pm-write-guard.sh` 確實 runtime-agnostic（任何 runtime 套用同一規則）✓，且 `--role pm --runtime codex` CLI 路徑已可正常呼叫 ✓；但目前三個地方仍暗示 pm=claude-only：(1) deprecated `--profile pm` alias hardcode `runtime="claude"`，(2) `scripts/lib/pmctl-guard.sh` 說明說「currently claude-only」，(3) 無 codex-as-pm dispatch end-to-end 測試。修法：(1) alias 部分接受（deprecated, 將由 CC-296 移除，hardcode 是 convenience 不是設計限制）；(2) 把「currently claude-only」說明改為「guard policy is runtime-agnostic; no deployed codex-as-pm use case yet」以分清設計與現況；(3) 加 integration smoke test：`pmctl dispatch run --adapter codex --role pm` 可成功 dispatch。Origin user 2026-06-02。關聯 [[CC-291]]（two-axis design）、[[CC-296]]（alias sunset）、[[CC-215]]（pmctl dispatch run）。 | arch | 2026-06-02 | — | P3 | design |
| CC-321 | ✅ closed 2026-06-08 | **[refactor: rename CLAUDE_HOOK_* env vars to PM_HOOK_* for executor-agnostic naming]** pm-dispatch 的 hook 設定 env var（`CLAUDE_HOOK_CODEX_READ_ROOTS`、`CLAUDE_HOOK_CODEX_GUARD`、`CLAUDE_HOOK_PM_GUARD`、`CLAUDE_HOOK_REVIEWER_GUARD` 等）都冠 `CLAUDE_` 前綴，與 executor-agnostic 目標不符。改為 `PM_HOOK_` 前綴；舊名保留為 deprecated alias 一個 release 後移除。需同步更新 install-hooks.sh、test-hooks.sh、test-pmctl-guard.sh 及文件。Breaking change — 獨立 PR。 | ops | 2026-06-04 | pr:#243 | P2 | hygiene |
| CC-338 | ✅ closed 2026-06-09 | **[v0.5.0 P1: lightweight built-in repo index for context-pack（standard Unix toolchain only）]** 以 Bash + awk/sed/grep/find + sqlite3 實作 repo 持久化 index（files / symbols / file_chunks），並暴露 `pmctl context index/update/query` 三個 CLI 指令。SQLite WAL 並行。FTS5-optional + grep fallback。`pmctl context pack` 組裝層屬 CC-239（reuse-scan）。原 CC-328 改號至此，見 DECISIONS 2026-06-08。 | ops/token | 2026-06-05 | pr:#253 | P1 | design |
| CC-342 | 🟢 someday | **[agent: debt-auditor — proactive tech-debt health scan on living code]** 新增 `agents/debt-auditor.md`：對指定 codebase 區域（目錄 / module）做主動技術債健康掃描，不需要 PR 觸發。輸出是按優先序排列的債務清單（重複、慣例分歧、過早抽象、缺少測試的不變量），含位置、影響、建議修法、預估規模。定位為**真正新的認知模式**（proactive health assessment），有別於所有現有 reviewer（全部 PR-diff focused）。由 `pmctl audit <path>` 或 `/audit` skill 呼叫；隔離執行確保不受進行中任務錨定。 | process/DX | 2026-06-05 | — | P3 | design |
| CC-343 | ✅ done | **[skill: /discover — milestone seeder + opportunity scanner]** 新增 `commands/discover.md`：以「發散模式」呼叫 project-pm，讀取 backlog（someday+deferred 項目）+ DECISIONS + MILESTONES + 近期 git activity，輸出高槓桿機會清單（含問題、why、預估規模）。定位為 brainstorm/ideation 的正確形狀——利用 PM 的既有 context 而非隔離，避免重新推導已有的設計決策。用於「v0.X.0 milestone 規劃前想知道可以做什麼」的發散探索。從 someday 提前至 v0.5.0 P1（實作成本 XS；提供 milestone seeder 功能後可用來規劃後續工作）。 | process/DX | 2026-06-05 | pr:#251 | P1 | design |
| CC-344 | 🟢 someday | **[skill: /research — grounded external research with internal context anchoring]** 新增 `commands/research.md`：補足 `/discover` 純內部掃描的盲區，加入外部研究維度。流程：(1) 自動讀內部相關 memory/decisions 建立錨定；(2) 問使用者 1–2 個定向問題縮小搜尋範圍；(3) 派有 WebSearch 能力的 agent 抓取外部實作與方法；(4) 主線程以內部設計 constraint 過濾結果，標記「可採用」或「與 constraint X 衝突」。目標：讓外部技術知識能有效導入而非淪為噪音。與 `/discover` 互補——discover 看「我們已知但未做的」，research 看「外部有我們還沒想到的」。 | process/DX | 2026-06-09 | — | P3 | design |
| CC-345 | 🟢 someday | **[dx: claude adapter 即時進度串流（stream-json）]** `adapters/claude/dispatch.sh` 目前使用 `--output-format json`，stdout 完全 buffered 至 process 結束，dispatch 期間 trace 為空、working tree 無變動，使用者無法判斷 executor 在讀取或寫檔。改用 `--output-format stream-json` 並以 tee 寫入 trace，同步解析 tool-use events，在 stderr banner 即時顯示 `[reading]`、`[writing]`、`[running]` 進度行。 | ux/ops | 2026-06-09 | — | P2 | design |
| CC-346 | 🔵 active | **[repo-index: cross-file ref tracking（file_refs layer，5 languages）]** CC-338 只有 symbol+chunk，看不出引用關係。新增 `file_refs(from_id, to_path, ref_type, line_number, resolved)` 表，以 grep 解析 bash source、Java import、JS/TS import/require、Go import。分三 phase：(a) bash、(b) JS/TS、(c) Java+Go。讓 query 回傳的 `refs` 欄位含直接引用者，並為 CC-347 blast-radius 和 CC-239 reuse-scan 提供資料。Promoted someday→P2 2026-06-10：reuse-scan 沒有引用資料時對 PM 幫助有限。排 v0.5.0 Phase 2，與 memory loop 解耦（repo plane 下游）。 | ops | 2026-06-09 | — | P2 | design |
| CC-347 | 🟢 someday | **[pr-gate: blast-radius analysis using cross-file refs（CC-346）]** gate brief 組裝時對 diff 中每個變更符號走一層 file_refs 圖，彙整成 `blast_radius` 清單（`{file, referenced_by: [path,...], ref_count: N}`）注入 brief context 段落，讓 risk-reviewer 有依據評估波及範圍。無 CC-346 index 時靜默跳過。 | gate | 2026-06-09 | — | P3 | design |
| CC-348 | 🟢 someday | **[pmctl project-map: cross-file dependency graph visualisation]** `pmctl project-map [--format text/dot] [--from <path>] [--depth N]` — 以 CC-346 file_refs 表輸出 ASCII 樹狀（預設）或 Graphviz DOT 引用圖；標示 broken refs（to_path 不在 files 表）；無 index 時 exit 1 並提示 `pmctl context index`。 | ops/DX | 2026-06-09 | — | P3 | design |
| CC-349 | ✅ closed 2026-06-10 | **[repo-index: symbol index limited to code files only — Markdown headings are not reusable symbols]** `pmctl context index` 對所有 Markdown 檔案提取 heading 作為 symbol，但 Markdown heading 不是「可複用的程式碼符號」——shell function、Python function、JS/TS export 才是。Markdown heading 大量混入 symbol index 導致 reuse-scan 的命中以文件結構為主，淹沒真正有用的 code symbol。修法（語言層級，不綁特定檔名）：在 `_ctx_extract_symbols`（`scripts/lib/pmctl-context.sh`）移除 `markdown)` case——Markdown/YAML/JSON/文字檔只建 file_chunks index，不建 symbol。`_ctx_detect_language` 回傳的 `lang` 欄位已可判斷語言，修改範圍小。預期效果：任何 repo 上 reuse-scan 命中均以程式碼符號（函式、class、export）為主；文件標題不佔據排名。**See**: pr:#257 | ops/DX | 2026-06-10 | pr:#257 | P2 | — |
| CC-334 | ✅ done | **[install: install-hooks.sh 安裝時自動 merge 必要 permissions.allow 條目至 ~/.claude/settings.json]** pr-gate claude 路由的 reviewer subagent 需要 Write 和 Bash 權限才能寫入 .gate-results 並執行 guard check。現行安裝流程只裝 hooks，未補 permissions，導致安裝後 /pr-gate 仍不可用。需在 install-hooks.sh 結尾依使用者實際工作區路徑動態推算寫入的 glob，再 idempotent merge 進 settings.json。 | install/ux | 2026-06-08 | pr:#244 | P1 | — |
| CC-333 | 🟢 someday | **[arch: pm-dispatch runtime 解耦合 — 移除對 Claude AI 路徑、hook 機制、術語的硬依賴]** pm-dispatch 目前在七個層面硬耦合 Claude Code runtime：(1) memory 路徑（`~/.claude/projects/<id>/memory/`）；(2) hook 機制（PreToolUse/PostToolUse）；(3) 設定格式（settings.json）；(4) 安裝路徑（`~/.claude/`）；(5) env var 前綴（`CLAUDE_HOOK_*`，CC-321 部分解）；(6) dispatch 術語（`dispatch_handover_v1`、Agent tool 約定）；(7) reviewer agents 直接讀 Claude memory 路徑而非透過 handover brief。目標：pm-dispatch 的核心 workflow 應可在不同 AI runtime（或 CLI 工具）上運行，Claude-specific 部分降為 adapter layer。 | arch | 2026-06-07 | — | P3 | design |
| CC-335 | 🟢 someday | **[release: deprecated surface registry + v0.6.0 removal sweep]** 追蹤 v0.4.0/v0.5.0 期間標記為 deprecated 的 public surface，在 v0.6.0 統一移除。已知項目：(1) `bash scripts/pr-gate.sh` 直呼腳本 → 改用 `pmctl gate run`（deprecated v0.4.0）；(2) `scripts/codex-dispatch.sh` shim → 改用 `pmctl dispatch run --adapter codex`（deprecated pre-v0.4.0，warning 已加 CC-336）；(3) `--profile` flag in `pmctl guard check` → 改用 `--role` + `--runtime`（deprecated pre-v0.4.0）；(4) `sandbox`/`approval`/`skip_git_check` legacy metadata fields → 改用 `isolation_level`（deprecated pre-v0.4.0）。每個項目需補 deprecation warning（stderr）再刪除實作。 | release | 2026-06-08 | — | P2 | — |
| CC-336 | ✅ done | dx: deprecated warnings + executor docs preferred path update | docs | 2026-06-08 | pr:#246 | P2 | — |
| CC-337 | ✅ done | portability: Windows Git Bash skip-guards + doctor.sh auto-profile fix | ops/portability | 2026-06-08 | pr:#247 | P1 | — |
| CC-339 | ✅ done | **[lint: prevent duplicate CC id with divergent title]** Sibling `lint-ticket-ids.sh` + lint.yml job asserting no id is open on the active board while closed in the archive (cross-lifecycle collision; string-comparison-free reinterpretation). Caught CC-329/CC-330 collisions on first run (renumbered to CC-342/CC-343). v0.5.0 Phase 0 follow-up. | process | 2026-06-08 | pr:#250 | P3 | hygiene |
| CC-340 | 🟢 someday | **[knowledge index: standalone FTS over memory/backlog/decisions]** Local knowledge-search index (the second-brain plane, symmetric to the repo index CC-338): index MEMORY.md + memory cards + wiki + BACKLOG / DECISIONS / MILESTONES + episodes, answering "why / how was this decided / prior failure modes" before dispatch. v0.5.0 only aligns the schema (context_hit_v1, CC-237); the heavy standalone index overlaps /mem-search and is deferred to v0.6.0. FTS5-optional + LIKE/grep fallback; no embeddings in MVP. | memory | 2026-06-08 | — | P3 | design |
| CC-341 | ✅ done | **[pmctl validate: wire handover-validate framework into pmctl]** The CC-202 handover-validator framework shipped (#170) but was never wired into a `pmctl validate` subcommand. MILESTONES v0.5.0 previously pointed at the closed CC-202; this is its active home. Wire `pmctl validate brief` as a read-only validation front-end matching the handover-validate.sh framework (exit 0=valid / 1=invalid / 2=usage). Read-only by design, same as guard check — no state written. | arch | 2026-06-08 | pr:#252 | P2 | design |
| CC-350 | ✅ done | **[bug: pmctl gate run SIGPIPE×pipefail — stdout pipe → 0-byte result + false-success exit 0]** `scripts/pr-gate.sh` banner `printf` 在 stdout 接 pipe 時 SIGPIPE×pipefail 提前中斷 dispatch；結果檔 0 bytes；整條命令誤報 exit 0。false-success 對自動化 caller 比 false-failure 危險（空結果被當作 gate 通過）。Fix 方向：結果完整性把關（非空才 exit 0）、banner SIGPIPE 容錯、或介面文件警告。 | ops/gate | 2026-06-10 | pr:#258 | P2 | hygiene |
| CC-351 | ✅ done | **[codex-executor: brief schema validation must fail-fast before any file reads]** 非 YAML brief（缺 schema_version/goal/files/self_verify）送到 codex-executor 時，部分 invocation 立即 REJECT，其他進入無效 loop 耗費大量 token；同 session 兩個相同格式 brief 行為分歧。Fix：把 schema validation 移到所有 file reads 之前的第一步，無論 dispatch 上下文或 session 狀態。 | ops/DX | 2026-06-10 | pr:#259 | P2 | hygiene |
| CC-352 | ⏸ deferred | **[codex-executor sandbox friction Pattern 1+2: apply_patch retry noise + Go module cache blocked]** issue:#173 Pattern 3（git commit blocked）已由 CC-272 pr:#245 吸收修復。剩餘：(1) apply_patch 中途失敗 self-retry 噪音 — brief 改拆小 hunk 加 unique context；(2) go build 時 GOPATH copy 被 sandbox 擋 — 文件化 GOPATH=/tmp/gopath 慣例。兩者均為 doc/convention fix。 | ops/DX | 2026-06-10 | — | P3 | — |
| CC-353 | ✅ done | **[unify executor dispatch: claude-executor symmetric to codex-executor]** claude-executor.md 缺 codex-executor 的「N-condition fallback allowlist」結構，兩份 executor 文件不對稱、難維護。統一：pmctl dispatch run --adapter claude 定為唯一文件化主路；claude-executor.md 重構成鏡像 codex 的窄 fallback（lifecycle 框架 + fallback 表 + caller checklist）；pr-gate reviewer fan-out 標為正當用途非 fallback。對齊 dispatch-brief.md §Fallback。隨 CC-351 同 PR。 | ops/DX | 2026-06-10 | pr:#259 | P2 | hygiene |
| CC-354 | 🔵 active | **[v0.5.0 P2 read-half: anchored knowledge index + retrieval reflex]** knowledge plane has no queryable index — `pmctl context query` only covers the repo plane, and the indexer stores one `head -c 2000` chunk per file, so a 180 KB BACKLOG only has its first ~30 lines indexed (finding CC-234 needs grep). Pull the anchored-TOC slice of CC-340 forward via a pluggable per-format chunker (markdown heading-based, txt/json/yaml window-based, html window fallback — semantic html deferred to CC-355): store heading + extracted CC-id/decision-id + line anchor + lead, not full text; add `pmctl context query --domain knowledge`. In-repo knowledge docs only — out-of-repo memory cards stay on existing MEMORY.md auto-injection, deferred. Wire the query-before-grep discipline into a neutral docs contract plus pmctl — not CLAUDE.md, to avoid platform binding — with only a pointer in agents/project-pm.md. Read side of the memory read+write loop; closes with CC-234. | memory | 2026-06-10 | — | P2 | design |
| CC-355 | 🟢 someday | **[knowledge index: HTML semantic chunking — `<h1-6>` sections]** CC-354 chunks markdown by heading and txt/other by line windows; HTML falls back to window chunking, losing its `<h1>..<h6>` section structure (the same human-authored semantic anchors as markdown headings). Plug an html strategy into the CC-354 per-format chunker seam: split on heading tags, use tag-stripped heading text as the chunk heading, strip tags for the lead, handle parsing edge cases (comments, pre/code, entities). Split out because robust HTML parsing in bash is its own concern and there is no html knowledge source in the repo today. Trigger: a real html file enters the knowledge plane. | memory | 2026-06-10 | — | P3 | design |

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

## CC-215 — pmctl — core CLI entrypoint ✅ 2026-06-09

**See**: pr:#252 (final slice); pr:#171, pr:#242 (prior slices)

**Status (2026-06-09)**: All planned pmctl state-ops shipped. **Shipped (PR #171)**: `adapter generate` + `dispatch run`. **Shipped (PR #242)**: `task list/show/create/update` + `decision add`. **Shipped (PR #252)**: `task claim/dispatch/status/review` + `safe bash` + `task.claimed/task.dispatched/task.reviewed` event kinds. `backlog view/sync` via CC-287, `guard check` via CC-288/CC-291, `trace` via CC-315 (stale references in body below).

**Milestone (2026-06-08)**: the genuinely-remaining pmctl state-ops — `task claim/dispatch/status/review` + `safe-bash` — are targeted for **v0.5.0 Phase 2** so the `⚠️ partial` does not float indefinitely. `pmctl validate` is split out as its own active ticket (CC-341).

**Problem**: pm-dispatch has no language-agnostic runtime binary. All orchestration logic is
reached through Claude-specific hooks and commands, preventing non-Claude CLIs from accessing
the same PM capabilities without duplicating logic.

**Why**: `pmctl` as a standalone binary makes pm-dispatch a proper tool layer: Claude hooks,
Codex wrappers, and MCP server all become thin callers into one well-defined CLI interface.
Guard logic and dispatch state move from Claude-only paths into `pmctl` so any CLI without hook
support can call `pmctl guard check` or `pmctl safe-bash`.

**Requirement** (full surface — all subcommands now shipped across PRs #171/#242/#252):
- Implement `cli/pmctl` with subcommand interface:
  - ✅ `pmctl task list/show/create/update` (PR #242)
  - ✅ `pmctl decision add` (PR #242)
  - ✅ `pmctl task claim|dispatch|status|review` (PR #252)
  - ✅ `pmctl validate brief` (PR #252, see CC-341)
  - ✅ `pmctl safe bash` (PR #252)
  - ✅ `pmctl backlog sync` (via CC-287)
  - ✅ `pmctl trace tail` (via CC-315)
  - ✅ `pmctl guard check --event <pre-write|pre-bash|post-task> --file/--command <val>` (via CC-288/CC-291)
  - ✅ `pmctl adapter generate <claude|codex|antigravity|opencode>` (PR #171)
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

## CC-228 — BACKLOG validator-debt cleanup ✅ 2026-06-08

**See**: Superseded by CC-277 (pr:#183). `pm/scripts/validate.sh` now exits 0 on main with no E-codes — verified 2026-06-08. CC-228 described a real debt that CC-277 fully resolved in v0.3.0 BACKLOG Hygiene Track.

**Original problem**: `pm/scripts/validate.sh` exits 1 on `main` with ~31 pre-existing E-codes, none introduced by recent PRs. An always-red validator provides no signal — a real new error would be invisible.

**Why**: The debt accumulated as the schema tightened (CC-030 / CC-052 / CC-067) faster than existing rows were migrated.

**Requirement** (resolve per error class, dry-run `validate.sh` after each, target exit 0):
1. `E-INDEX-MISMATCH` — CC-104d/e/f/g/j/k/m/r/s have index rows but no body section. Add stub sections or drop the index rows (they were Windows-dogfood sub-items, mostly folded into shipped PRs).
2. `E-AREA-ENUM` — CC-052/060/104v/203/204 etc. use slash-combined or non-enum areas (`arch`, `config`, `schema`, `ops`, `hook`). Widen the `area` enum (adding `arch`/`ops` is additive and fixes the most rows) or rewrite the rows.
3. `E-REFS-PREFIX` — CC-059/060/061/064/066 carry bare `CC-NNN` refs; the Refs column requires a prefix. Move ticket cross-links into the section body.

**Priority**: P2 — not blocking, but should land before v0.3.0 M1 tightens the schema further.

**Cross-link**: surfaced during CC-222 close-out 2026-05-22.

## CC-234 — memory v2: event-derived distillation（write-half of the memory loop）

**Problem**: The memory system is chat-derived — `episodes.jsonl` summarizes conversations. The durable signal is the action stream (tool calls, decisions, gate verdicts).

**Why**: Memori's insight — memory from what agents *do*, not just what they say. The Event log (CC-230) is that action stream. This is the **write side** of the v0.5.0 memory read+write loop: the semantic transformation (distilling raw episodes + events into a curated card) lives here, in `/mem-distill`, NOT in the read-side index — the index over structured docs stays an anchored table-of-contents (CC-354), and memory cards are where distilled semantic knowledge is authored.

**Requirement**: Point `/mem-distill` at `events.jsonl` as an input alongside `episodes.jsonl`. Filter to distillable kinds (run.completed/failed, review.verdict, decision.recorded, task.state_changed); analyse action-pattern signals (repeated failures in a subsystem, gate-verdict clusters, decision clusters) alongside chat summaries. The existing four-tier card system is unchanged; this gives the `event` tier a schema. No separate memory engine. State store may be uninitialised → graceful fallback to episodes-only distillation.

**Acceptance**: `/mem-distill` consuming a session's `events.jsonl` + `episodes.jsonl` produces/updates a memory card capturing an action-derived fact (not just chat), under the existing four-tier schema, with user confirmation. The card surfaces to the agent via the existing MEMORY.md auto-injection path (memory cards are NOT indexed into pmctl in v0.5.0 — see CC-354 scope boundary). Together with CC-354 (in-repo knowledge docs queryable), this makes memory read + write both usable — the write half here, the read half (docs) in CC-354.

**Milestone**: v0.5.0 Phase 2 (memory read+write, write half).

**Priority**: P2.

**Cross-link**: [[CC-354]] (read side — anchored knowledge index), CC-230 (events.jsonl), CC-229 (event schema), `commands/mem-distill.md` (modification target).

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

## CC-237 — context-enricher interface: context_hit_v1 + pmctl context pack ✅ 2026-06-09

**Problem**: The `context-pack` abstraction (CC-232) shipped a schema (#157) but has no concrete producer. v0.5.0 makes it the single interface that fuses the repo index (CC-338), memory search, and git into one dispatch-time context-pack.

**Why**: knowledge and repo are two different search planes with opposite lifecycles (curated/durable vs derived/rebuildable). They must be indexed separately but emitted through one interface so consumers (`/pm`, `/discover`, reuse-scan, `/mem-search`) read one shape. This is the spine of v0.5.0; it is also the comparison baseline for the codegraph spike (CC-209).

**Requirement** (shipped 2026-06-09):
- Extended CC-232 context-pack schema with `context_hit_v1` optional fields: `source_domain` (enum: knowledge / repo / state), `why_relevant` (string), `trust_level` (enum: high / medium / low), `refs` (string array). `schema_version` changed from `const:2` to `enum:[1,2]` for backward compat.
- `pmctl context index / update / query` (builtin-index backend). Pack assembler (`pmctl context pack`) is CC-239.
- FTS5 is optional; a `LIKE` / `grep` fallback is mandatory and tested (Windows Git Bash sqlite3 may lack FTS5).

**Milestone**: v0.5.0 Phase 1 (P1 spine).

**Priority**: P1.

**Cross-link**: [[CC-232]] (schema), [[CC-338]] (repo-index backend), [[CC-239]] (consumer), [[CC-209]] (codegraph spike).

**See**: pr:#254

## CC-238 — /pr-gate claude-route background fan-out hardening（deferred）

**Problem**: CC-217 made the `/pr-gate` claude-executor reviewer and synthesis fan-out (`commands/pr-gate.md` Route B) run detached via `run_in_background: true`. The CC-217 gate (gate-20260523, express tier) raised three advisories on the new flow.

**Why**: A detached fan-out with no timeout can wait indefinitely if a reviewer agent never reports completion; a single fan-out step makes per-reviewer attribution weaker on partial failure; and the behavior change has no test artifact.

**Requirement**:
- Add a completion timeout / fallback for the background reviewer + synthesis agents — a non-reporting agent must degrade to a partial/fail result, not an indefinite wait.
- Preserve per-reviewer failure attribution when only one fan-out branch fails.
- Add test coverage for the claude-route background completion + relay ordering (`scripts/test-pr-gate.sh` or a `commands/`-contract test).

**Priority**: P3 — advisory follow-up; the CC-217 GO was not blocked on it.

**Cross-link**: CC-217 (origin), `commands/pr-gate.md` Route B.

## CC-239 — reuse-scan capability ✅ 2026-06-10

**Problem**: pm-dispatch carries recurring reuse debt — CC-200..204 are all "the same logic duplicated across scripts / hooks / tests". New work keeps re-creating helpers and patterns that already exist, because nothing surfaces "this already exists" before a brief is written. The maintainer asked whether a dedicated **reuse/refactor agent** should be added; it was analysed and is the wrong shape (see Why).

**Why**: A dedicated reuse/refactor *agent* is not the right abstraction:
- Subagents cannot spawn subagents, so a "refactor agent" could only be a *planner* — duplicating `project-pm`, which already owns task triage / decomposition / brief-writing.
- pm-dispatch agents split by **cognitive mode** (plan / execute / review), not by domain. Refactor is not a new mode — it is ordinary implementation. The spike agent (CC-220) earned a dedicated agent by being a genuinely distinct mode (uncertainty reduction); refactor is not.
- Refactor *expertise* is already placed: `architecture-reviewer` (coupling / abstraction fit), `risk-reviewer` (migration safety / reversibility) and `critic` (scope / convention drift) review every refactor PR, and `docs/dispatch-brief.md` already carries a `refactor` brief skeleton (semantic preservation, all-call-sites-updated, tests green). A refactor agent would duplicate those.
- The v0.3.0 synthesis already concluded "no separate reuse/refactor agent" — reuse work *is* ordinary briefed implementation (`docs/architecture/v0.3.0-synthesis.md`; the CC-200..204 extraction tickets are exactly this).

The genuinely-missing piece is the **front-end**: a reuse-scan that runs *before* briefing so the brief reuses rather than duplicates. That is a capability, not an agent — "split by goal, not by role".

**Requirement**: a reuse-scan **capability** (a skill / context step, not an agent), invoked by `project-pm` during briefing, that queries the codebase for prior art relevant to the task — similar functions, shared helpers, existing patterns — and emits a "reuse report" the dispatch brief incorporates. It is one consumer of the `context-pack` (CC-232) / context-enricher (CC-237) infrastructure and belongs in `skills/` (CC-061). Refactor *execution* stays on the existing brief → executor → gate path — no new execution agent.

*Provider dispatch architecture (tiered)*:
- Tier 0 (baseline): `rg` / `git grep` text search + `git log --oneline` for recently-touched files — zero setup, always available
- Tier 1 (builtin-index): `pmctl context query` via CC-338 repo-index (symbol + chunk search, FTS5/LIKE fallback) — available after first `pmctl context index`
- Tier 2 (cross-file refs): CC-346 `file_refs` layer (import/source call graph, 5 languages) — deepens relevance ranking
- Tier 3 (future): CC-209 codegraph — optional accelerator; same interface, richer output

Each tier is a **drop-in upgrade**: the consumer (`/pm` briefing, CC-239 reuse-scan) reads the same `context_hit_v1` shape regardless of which tier produced the hit.

*Output shape extensions (aligned with context_hit_v1, CC-237)*:
- `summary` (string): one-line description of the reuse candidate ("validates brief schema fields: schema_version, goal, …")
- `tags` (string array): searchable labels drawn from symbol kind / language / topic ("schema", "bash", "validation")
- `why_relevant` (string): reason this hit matches the current brief (filled by Tier 1+; may be absent for Tier 0 grep hits)

**Milestone**: v0.5.0 Phase 2 — the user-visible terminus of the context-pack spine; the first consumer of the repo index (CC-338) through the CC-237 interface.

**Priority**: P2 — depends on CC-338 (repo index) + CC-237 (interface) landing first.

**Cross-link**: CC-232 (context-pack schema), CC-237 (context-enricher baseline), CC-338 (builtin-index backend), CC-346 (cross-file refs), CC-209 (future codegraph), CC-061 (skills/), CC-200..CC-204 (the reuse debt this prevents recurring), `docs/architecture/v0.3.0-synthesis.md`.

**See**: pr:#256

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

**Co-implementation note**: CC-255 是 CC-253 的前置條件（CC-253 brief 必須使用 CC-255 更新的 `test_target:` 欄位）。若目標 codebase 已選定，建議 CC-255 + CC-253 同一 PR 實作，好處是 CC-255 有首個真實用例驗證。若 target repo 尚未選定，則先做 CC-255，等 target ready 再開 CC-253。CC-253 landing 後，CC-209 umbrella ticket 可一併關閉（標 superseded by CC-253）。

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

## CC-272 — docs: executor contract cleanup bundle ✅ 2026-06-08

**Result**: `docs/dispatch-brief.md` 新增 §Commit delegation rule（含反例 + 正例）；§Style notes 補 commit 禁止條目。`docs/executor-contract.md` 新增 §Async dispatch behavior（sync vs async 判斷規則、per-scenario table 拆分 primary Bash 路徑 vs Agent fallback、diagnosis 指引）。新增 `pmctl gate run` 子命令（`cli/pmctl` + `scripts/lib/pmctl-gate.sh`）使 gate 走統一 pmctl 介面而非直呼腳本；`commands/pr-gate.md` Step 1/2 同步更新。消除 false partial 噪音來源，確立 pmctl 為 gate 唯一 public 介面。

**See**: pr:#245

兩個 executor 文件噪音問題合併成一個 docs PR：

### Part A — brief template: omit commit block; document main-thread commit delegation

**Problem**: Every brief ends with a `git add + git commit` block that `hook-codex-bash-guard` blocks. The executor marks the commit step as failed and reports `status: partial` in the output summary — even when all code changes are correct. The main thread must manually stage and commit after every dispatch. The brief template implicitly encourages adding a commit block, creating a permanent noise signal.

**Options**:
- **A (preferred)**: Remove the commit block from the brief template and document in `docs/dispatch-brief.md` that commit is always delegated to the main thread. Update `self_verify` template to stop including `git commit` as a success criterion.
- **B**: Add `git add` + `git commit` (without destructive flags) to `hook-codex-bash-guard` allowlist. Requires security review of hook policy (`[[CC-066]]`).
- **C**: `scripts/codex-dispatch.sh` reads a `.commit-msg` file written by the executor and performs the commit on its behalf; executor stays sandboxed.

**Impact**: Every dispatch shows false `status: partial`; creates a recurring manual step the main thread must remember.

**See**: issue:#173 (Pattern 3)

### Part B — run_in_background default async escalation (absorbed from CC-268)

**Problem**: Agent tool called without `run_in_background:true` may silently promote the subagent to async mode and return `Async agent launched successfully` instead of blocking. Observed with `codex-executor` (~3m45s async without the flag). Docs say "Claude decides" but give no criteria; callers cannot reliably predict whether the dispatch blocks the main thread.

**Proposed fix**: Document in `docs/executor-contract.md` which subagent types always run async, and whether/when the default blocks.

**See**: issue:#166

**Cross-link**: `[[CC-066]]` (declarative policy.yml for hook allowlist — relevant if Option B chosen for Part A)

**Priority**: P2 — Part A affects every dispatch; Option A is pure documentation with immediate noise reduction.

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

## CC-321 — refactor: rename CLAUDE_HOOK_* env vars to PM_HOOK_* ✅ 2026-06-08

**Problem**: pm-dispatch hook configuration env vars use a `CLAUDE_HOOK_` prefix (`CLAUDE_HOOK_CODEX_READ_ROOTS`, `CLAUDE_HOOK_CODEX_GUARD`, `CLAUDE_HOOK_PM_GUARD`, `CLAUDE_HOOK_REVIEWER_GUARD`, `CLAUDE_HOOK_GATE_REPO_ROOT` (deleted), `CLAUDE_HOOK_DISPATCH_ABS`, `CLAUDE_HOOK_LOG_DIR`). The prefix creates a false coupling to the Claude Code agent system — these are pm-dispatch's own config knobs and should be in the `PM_HOOK_` or `PM_DISPATCH_` namespace.

**Plan**:
1. Rename each env var to `PM_HOOK_*` equivalent across all hooks, tests, and docs.
2. Add a shim period: if the old `CLAUDE_HOOK_*` name is set, emit a deprecation warning to stderr and honour it. Remove the shim after one release cycle.
3. Update `scripts/install-hooks.sh`, all `test-hooks.sh` / `test-pmctl-guard.sh` references, and `docs/`.

**Acceptance**: `grep -r CLAUDE_HOOK_ scripts/ adapters/ docs/` returns only the shim/deprecation-warning lines.

**Scope limit**: does NOT rename `CLAUDE_HOOK_LOG_DIR` if that conflicts with Claude Code's own log dir convention — verify first.

**Priority note**: breaking change; hold until CC-319/CC-320 are merged and no active PRs depend on the old names.

**Result**: All 7 `CLAUDE_HOOK_*` vars renamed to `PM_HOOK_*` across 15 files (6 hook scripts, 1 adapter, 3 test scripts, README, spike doc). Backward-compat shims added in all production hooks (removed after v0.5.0). `grep -r CLAUDE_HOOK_ scripts/ adapters/ docs/` returns only shim printf lines. 427 tests, 0 failures.

**Cross-link**: [[CC-319]], [[CC-320]].

**See**: pr:#243

---

## CC-338 — lightweight built-in repo index for context-pack（Bash+SQLite，無外部依賴）✅ 2026-06-09

**Renumbered**: 原 CC-328；與 PR #229 的 light-alias（已 ship，記於 MILESTONES v0.4.0 旁支修正）撞號，repo-index 改號至 CC-338。見 DECISIONS 2026-06-08。

**Problem**: pm-dispatch subagent 在 dispatch 前缺乏結構化的 repo context，只能透過重複 grep/read 探索相關檔案與 symbol，造成 token 浪費與 dispatch brief context 不穩定。現有方案不足：CC-237（context-enricher interface）需要外部 rg；CC-209（codegraph evaluation）評估的是 TypeScript external tool，已獲 AMBER——pm-dispatch 的 bash/markdown stack 不在其支援範圍內。

**Why**: 需要一個**內建**的 context layer，僅依賴 standard Unix toolchain（`bash / find / grep / awk / sed / sqlite3`），不引入任何需要另行安裝的 binary（如 ctags、rg、Node.js、Rust binary），在 dispatch 前產生 compact context pack（相關檔案 + approximate symbols + test hints），直接注入 dispatch brief，減少 subagent 盲目探索成本。此能力建在 v0.4.0 state-first 地基上（消費 Run/Event/trace 提供的 recently touched files、task history 等動態排序資料）；地基已落地，排入 v0.5.0 Phase 1。

**Requirement**:

*Phase 1 — MVP（Bash+SQLite only）*
1. `pmctl context index --source repo`：掃描 repo 建立 SQLite index（`files` / `symbols` / `file_chunks` 三張表）
2. `pmctl context update [path]`：增量更新（**mtime-only** 偵測變更；sha1 儲存供 debug 用，不參與 skip 判斷——content 變更但 mtime 保留時不會重新 index，此為 documented contract）
3. symbol 提取策略：Bash + awk/sed/grep 的 regex-based approximation，支援 Shell（function）、Go（func/type/struct/interface）、Python（def/class）、TypeScript/JavaScript（function/class/const arrow）；Markdown **以單一 chunk（前 2000 bytes）儲存**（heading-based chunking 延至後續 PR）
4. `pmctl context query "<query>"` — symbol + text 搜尋，格式對齊 `context_hit_v1`（CC-237）；`pmctl context pack` 組裝層屬 CC-239
5. FTS5 為 optional 加速層；缺 FTS5 時 fallback 到 `LIKE` / `grep` 並納入測試（Windows Git Bash sqlite3 未必含 FTS5）
6. 以 pm-dispatch 自身 repo 作為第一個 fixture，比較 3 個真實任務的 before/after dispatch brief

*SQLite schema（最小可行）*:
```sql
files(id, path, language, size_bytes, mtime, sha1, indexed_at)
symbols(id, file_id, name, kind, language, line_start, line_end, signature, backend, confidence)
file_chunks(id, file_id, heading, line_start, line_end, text, sha1)
```

*MVP 內建依賴*: `bash`, `find`, `grep`, `awk`, `sed`, `sqlite3`（不新增任何其他依賴）

*Optional backend（Phase 2 以後）*: ctags、ffts-grep、tree-sitter — 只作為加速層，MVP 無此需求

**Non-goals**:
- 精準 AST parsing / call graph
- LSP references / semantic embeddings
- MCP server / daemon / web UI
- 取代 CC-209 codegraph spike（兩者定位不同：CC-209 評估外部工具；CC-338 建內建 layer）
- 取代 CC-237 context-enricher（CC-237 是 interface；CC-338 是其 `--source builtin-index` backend）
- 重型 knowledge index（FTS over 全 memory）——與 `/mem-search` 重疊，延 v0.6.0

**Dependencies**:
- v0.4.0 Run/Event/trace state（CC-315 / CC-316）已穩定
- context pack 格式對齊 CC-232 context-pack schema + `context_hit_v1`（CC-237）
- 作為 CC-237 context-enricher 的 `--source builtin-index` backend；CC-239 reuse-scan 為第一個 consumer

**Milestone**: v0.5.0 Phase 1（P1 spine）。

**Priority**: P1.

**Cross-link**: [[CC-237]], [[CC-209]], [[CC-232]], [[CC-239]], [[CC-315]].

**See**: pr:#254

---

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

## CC-343 — skill: /discover — milestone seeder + opportunity scanner ✅ 2026-06-09

**See**: pr:#251

**Renumbered**: 原 CC-330；與 BACKLOG-ARCHIVE 已關閉的 state_store_init mkdir-failure 票（✅ 2026-06-05）撞號，未開工的 /discover 改號至 CC-343。撞號由 ticket-id lint 偵測，見 DECISIONS 2026-06-08。

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
- 未來可以接 CC-338 context index 強化 codebase 相關機會的偵測精度

**Milestone**: `🟢 someday` — 實作成本 XS（只需一個 commands/discover.md），可提前於其他 someday 項目。

**Cross-link**: [[CC-220]], [[CC-239]], [[CC-237]], [[CC-338]].

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

## CC-346 — repo-index: cross-file ref tracking（file_refs layer，5 languages）🔵 v0.5.0 Phase 2 P2

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

**Milestone**: v0.5.0 P3（depends CC-338 landed）。

**Priority**: P3.

**Cross-link**: [[CC-338]] (repo-index, parent table), [[CC-237]] (context_hit_v1 refs 欄位), [[CC-239]] (reuse-scan consumer), [[CC-347]] (blast-radius consumer).

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

## CC-349 — repo-index: symbol index limited to code files only ✅ 2026-06-10

**Problem**: `pmctl context index` 把所有 Markdown heading 當成 symbol 建索引，但 Markdown heading 不是「可複用的程式碼符號」——shell function、Python function、JS/TS export 才是。任何含有大量 heading 的 Markdown 文件（不限 pm-dispatch 的 BACKLOG/CHANGELOG）都會在 reuse-scan 中佔據大多數命中，淹沒真正的 code symbol。

**Root cause**: `_ctx_extract_symbols` 的 `markdown)` case 讓 Markdown heading 和 shell function 走同一條 symbol 路徑。

**Solution（語言層級，不綁特定檔名）**: 從 `_ctx_extract_symbols`（`scripts/lib/pmctl-context.sh`）移除 `markdown)` case——Markdown/YAML/JSON/純文字等文件類型只建 file_chunks index，不建 symbol。程式碼語言（shell/python/js/ts/go）保留 symbol 提取。修改範圍：約 6 行刪除，0 新增。

**Expected outcome**: 任何 repo 上 reuse-scan 均以程式碼符號（函式、class、export）為主；文件標題不佔據排名。通用規則，不綁 pm-dispatch 特定檔案。

**Scope**: `_ctx_extract_symbols` markdown case 刪除 + 1 回歸測試（Markdown 檔案索引後 symbols table 為 0 row，file_chunks 有 1+ row）。

**Priority**: P2（直接影響 reuse-scan 核心 use case）。

**Cross-link**: [[CC-338]] (repo-index indexer), [[CC-239]] (reuse-scan consumer).

**See**: pr:#257

---

## CC-350 — bug: pmctl gate run SIGPIPE×pipefail — stdout pipe → 0-byte result + false-success exit 0 ✅ 2026-06-10

**Problem**: `scripts/pr-gate.sh` 在 dispatch reviewer 之前會 `printf` 多行 banner 到 stdout。當下游 consumer（`head -N`、`grep -q` 等早期關閉的 pipe）讀完後關閉 pipe，下一個 `printf` 寫入已關閉的 pipe → SIGPIPE；腳本 `set -o pipefail` 讓主流程在 dispatch 之前中斷；結果檔停在 `touch` 建立的 0 bytes；shell 對整條 pipeline 回報的 exit code 是最後一段（`head`）的 exit 0 → 整體誤報成功。false-success 比 false-failure 危險：自動化 caller（含 AI agent、CI）把空結果當成 gate 通過。

**Evidence**: issue:#255 記錄了 7 次相同 branch gate run：接 `| head` 全部 0-byte + exit 0；無 pipe 全部正常產出。

**Fix options（擇一或併用）**:
1. **結果完整性把關**：main 結尾在回報前驗證 OUTPUT_FILE 非空且含 `^Final: (GO|NO-GO)$`；不滿足則 exit 非 0。確保 0-byte 永遠不會誤報成功。
2. **stdout 容錯**：banner/progress 的 `printf` 對 SIGPIPE 容錯（`trap '' PIPE` 或 `|| true`），讓下游關 pipe 不中斷 gate 主流程。
3. **文件警告**：README / `pmctl gate run -h` 明示不得 pipe gate stdout；截斷輸出請用 `> file` 或讀 `.gate-results/`。

**Priority**: P2 — false-success 對自動化 caller 是靜默安全漏洞。

**Resolution**: 採 option 2（stdout 容錯）為主。第一次嘗試（`trap '' PIPE`）在 `set -e` 下不足——EPIPE 讓 `printf` 回傳非零，`set -e` 仍在 dispatch 前中止。完整修法兩處：(1) `say()` helper 包裝所有進度輸出（`printf … 2>/dev/null || true`），訊號 + set-e 雙重容錯；(2) sequential 與 synthesis 的 foreground `eval` 改 `>&2`，避免 dispatch 子程序繼承已關閉的 consumer pipe 而提前死亡。既有 per-route result-integrity 檢查維持為 exit code 權威。回歸測試 `test_piped_stdout_does_not_abort_gate`（接 `head -n1` 斷言結果檔完整）。

**See**: pr:#258, issue:#255

---

## CC-351 — codex-executor: brief schema validation must fail-fast before any file reads ✅ 2026-06-10

**Problem**: codex-executor 收到非 YAML brief（缺 schema_version/goal/files/self_verify 欄位）時行為不一致——同一 session、相同格式的兩個 brief，一個立即 REJECT，另一個進入無效 loop：讀 brief、嘗試 Bash edit（被 hook 擋）、循環找 Codex dispatch 路徑，耗費大量 token 後被外部 TaskStop 終止。行為分歧根因不明（可能是 session-state 差異或 prompt 快取邊界）。

**Requirement**: `agents/codex-executor.md` 的執行協議應把 brief schema validation 移到 **所有 file reads 之前的第一步**：若 brief 缺少必填欄位或無法解析為 YAML frontmatter，立即 REJECT 並輸出明確錯誤訊息，無論 dispatch 上下文或 session 狀態為何。

**Acceptance**:
1. 以純 Markdown prose brief（無 `schema_version`）dispatch codex-executor → 立即 REJECT，不讀任何 target file
2. REJECT 訊息含缺少的欄位名稱
3. 行為在同 session 多次 dispatch 下一致（不因快取狀態改變）

**Priority**: P2 — 每次格式錯誤 brief 都可能耗費數千 token；行為不可預測加劇除錯難度。

**Scope note (planning 2026-06-10)**: fix 對稱套用到**兩個 Agent fallback executor**。codex-executor 的 §0 gate 走 `pmctl dispatch run`（codex-bash-guard 擋 `bash` verb，無法直接呼叫 brief-validate），靠 `pmctl-dispatch.sh` 第 3 步 brief-validate 在 spawn codex 前 REJECT；claude-executor 的 §0 gate **直接** `bash scripts/brief-validate.sh <brief>`（claude 無 verb guard），exit 1 即 REJECT 且不讀 target file。兩者收斂到同一支 `scripts/brief-validate.sh`、同一 REJECT 訊息格式。兩檔都補回漏列的 `schema_version`。正規路徑（兩個 adapter 皆走 pmctl）本已有確定性 gate，僅 Agent fallback 需 prompt 硬化。

**Cross-link**: [[CC-045]] (brief timeout heuristic), [[CC-272]] (executor contract docs), [[CC-353]] (executor dispatch 統一，同 PR).

**See**: pr:#259, issue:#217

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

## CC-353 — unify executor dispatch: claude-executor symmetric to codex-executor ✅ 2026-06-10

**Problem**: 兩個 executor 的文件結構不對稱，難維護。`codex-executor.md` 已是完整的「pmctl 主路 + N-condition fallback allowlist + caller decision checklist」結構（lifecycle-leak 警告、§When NOT to use 5-condition 表、10-item checklist）；`claude-executor.md` 的 §When NOT to use 只是簡單 bullet list，沒有對稱的 fallback 結構。心智模型雙軌，每次改 executor 契約都要分別理解兩套敘述。

**Insight（planning 2026-06-10）**: claude 的「pmctl 優先」其實已是現行設計——`commands/pm.md` Route B 主路即 `pmctl dispatch run --adapter claude`，`Agent(claude-executor)` 已被文件化為「`claude --print` 不可用時」的窄 fallback。但 `Agent(claude-executor)` 不是純 legacy，有兩個真實職責：(1) 無 `claude` CLI 的主機上的 host-independent 逃生口（pmctl 路要 spawn 外部 `claude --print` binary，無 CLI 即失敗）；(2) `pr-gate` Route B 的 reviewer fan-out（in-session 並行 spawn，本來就該用 Agent）。因此**完全砍掉 Agent 路會損失能力 + 逼 pr-gate 重寫**——決議採對稱窄 fallback，不砍。

**Requirement**:
1. `agents/claude-executor.md` 重構成與 `agents/codex-executor.md` 鏡像的結構：頂部 lifecycle/fallback 框架、§When NOT to use 改成 N-condition fallback allowlist 表 + caller decision checklist。
2. 明定 `pmctl dispatch run --adapter claude` 為唯一文件化的檔案式主路；`Agent(claude-executor)` 為窄 fallback，條件清楚列出：①無 `claude` CLI ②main-thread context 壓力 ③sync sequencing ④pr-gate reviewer fan-out（標為**正當用途、非 fallback**，避免被誤砍）。
3. 窄幅對齊 `docs/dispatch-brief.md §Fallback`（claude fallback 表對稱於 codex）；如 `docs/executor-contract.md` 有不對稱敘述一併校準。

**Acceptance**:
1. `claude-executor.md` 與 `codex-executor.md` 的 fallback 段結構鏡像（同樣的 allowlist 表 + checklist 形狀）
2. 文件明確標示 pmctl 為主路、Agent 為窄 fallback，且 pr-gate fan-out 不被列為「不要用」
3. `bash scripts/lint-agents.sh` exit 0

**Effort**: prose-only，無 code 變更。

**Priority**: P2 — 維護性債；統一心智模型降低 executor 契約後續修改成本。

**Cross-link**: [[CC-351]] (fail-fast 驗證，同 PR 同 branch), [[CC-272]] (executor contract docs), [[CC-266]] (claude adapter).

**See**: pr:#259

---

## CC-334 — install: install-hooks.sh 安裝時自動 merge permissions.allow ✅ 2026-06-08

**Problem**: pr-gate 的 `--executor claude` 路由會透過 Agent tool 派生 reviewer subagents（Claude Code harness agents）。這些 subagents 需要明確的 `permissions.allow` 條目才能寫入 `.gate-results/` 並執行 `pmctl guard check`。現行 `install-hooks.sh` 只在 `~/.claude/settings.json` 寫入 hooks（PreToolUse/PostToolUse 條目），完全沒有補 `permissions.allow`，導致**安裝後 `/pr-gate` 仍無法正常運作**——需要使用者自行發現問題並手動補。對使用者而言等同工具無用。

**Root cause**: install-hooks.sh 的設計只考慮到 hooks 安裝，沒有考慮到 permissions 是同樣重要的執行前提。

**Required permissions** (reviewer subagents 需要):
- `Write(<workspace>/**/.gate-results/**)` — 寫 gate 結果
- `Bash(pmctl guard check:*)` — 執行 guard check
- `Bash(mkdir -p:*)` — 建目錄

**Design: 動態推算 workspace 路徑**

使用者的 repo 根目錄因人而異（`~/github/`, `~/projects/`, `~/code/` 等），不能 hardcode。策略：

1. **在安裝時偵測 workspace root**：取 pm-dispatch 安裝目錄的 **parent**（即 `dirname "$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"`）。如果使用者的 repos 都在同一資料夾，這個 parent 就是 workspace root。
2. **產生 glob**：`<workspace_root>/**/.gate-results/**`（例如 `/home/user/github/**/.gate-results/**`）。
3. **Fallback**：若偵測失敗（非 git repo、或 parent == HOME），改用 `$HOME/**/.gate-results/**`——仍然安全（限制在 `.gate-results` 子目錄）。
4. **Idempotent merge**：用 jq 讀現有 `permissions.allow` 陣列，若條目已存在則跳過，否則 append；避免重複安裝造成重複條目。

**Acceptance**:
- `bash install.sh` 完成後，`jq '.permissions.allow' ~/.claude/settings.json` 包含正確的 Write glob 和兩個 Bash 條目。
- 重複執行 `install.sh` 不重複寫入（idempotent）。
- 在 `/home/user/github/` 和 `/home/user/projects/` 兩種佈局下，glob 路徑都正確對應。
- 若 jq 不存在或 settings.json 格式損毀，印出清楚錯誤，不靜默失敗。

**Implementation location**: `scripts/install-hooks.sh` 尾段，在 hooks 安裝成功後執行；或抽為獨立函式 `install_permissions()`。

**Self-verify**:
- `cmd: "jq -e '.permissions.allow | map(select(test(\".gate-results\"))) | length > 0' ~/.claude/settings.json"`
- `cmd: "bash scripts/install-hooks.sh && bash scripts/install-hooks.sh; jq '.permissions.allow | length' ~/.claude/settings.json | diff - <(jq '.permissions.allow | length' ~/.claude/settings.json)"`（重複安裝長度不變）

**Cross-link**: [[CC-321]]（PM_HOOK 重命名，同一 install UX 修復脈絡）。

**Result**: `install-hooks.sh` 安裝後自動 idempotent merge 三個 reviewer permissions.allow 條目（Write glob、pmctl guard check、mkdir -p）。workspace root 從 pm-dispatch repo parent 動態推算，git 失敗或 parent==HOME 時 fallback 到 $HOME。`uninstall-hooks.sh` 同步移除這三個 managed entries。workspace 偵測邏輯抽出至 `scripts/lib/gate-workspace.sh` 供 install/uninstall 共用。9 個 gate-perms 測試案例，83 tests passed。

**See**: pr:#244

---

## CC-333 — arch: pm-dispatch runtime 解耦合 🟢 someday

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

## CC-335 — release: deprecated surface registry + v0.6.0 removal sweep 🟢 someday

追蹤 v0.4.0/v0.5.0 期間標記為 deprecated 的 public surface，在 v0.6.0 統一移除。每個項目在移除前需先補 stderr deprecation warning（讓使用者有遷移週期）。

### Deprecated surfaces

| Surface | Deprecated since | Replacement | Removal target |
|---|---|---|---|
| `bash scripts/pr-gate.sh` 直呼腳本 | v0.4.0 | `pmctl gate run` | v0.6.0 |
| `scripts/codex-dispatch.sh` shim（legacy callers） | pre-v0.4.0 | `pmctl dispatch run --adapter codex` | v0.6.0 |
| `--profile <pm\|codex\|claude>` flag in `pmctl guard check` | pre-v0.4.0 | `--role` + `--runtime` flags | v0.6.0 |
| `sandbox` / `approval` / `skip_git_check` legacy metadata fields | pre-v0.4.0 | `isolation_level` field | v0.6.0 |
| `CLAUDE_HOOK_*` env vars（shims） | v0.4.0（CC-321） | `PM_HOOK_*` | v0.5.0 |

### Work items

1. 每個 deprecated surface 在主路徑補 `printf '[deprecated] ...\n' >&2` warning。
2. 確認現有測試不依賴 deprecated 路徑（或加 `--legacy` flag 測試 warning 本身）。
3. v0.6.0 移除實作、刪除 shim files、清理文件。

### How to add a new deprecated surface

在這個 body 的 table 新增一行，欄位：surface（exact invocation）、deprecated since（vX.Y.Z）、replacement（exact new invocation）、removal target（vX.Y.Z）。不需另開票。

---

## CC-336 — dx: deprecated warnings + executor docs preferred path update ✅ 2026-06-08

三個變更確保呼叫舊路徑時有明確提示，且 agent/command 文件反映正確的 preferred path：

1. **`scripts/codex-dispatch.sh`** — 加 stderr `[deprecated]` 三行 warning，任何直接呼叫都能看到。
2. **`commands/pm.md`** — `executor: codex` 的 primary route label 從 `scripts/codex-dispatch.sh` 改為 `pmctl dispatch run --adapter codex`。
3. **`agents/codex-executor.md`** — Step 2 Bash 模板改為 `pmctl dispatch run --adapter codex ...`；Job 步驟和 §When NOT to use this agent 同步更新。

**Root cause**: PM 主線程 dispatch 時看到的 agent 文件仍指向 `codex-dispatch.sh`，導致 agent 讀到舊 instruction 後繼續走 deprecated 路徑（blocking main thread）。

**See**: pr:#246

---

## CC-337 — portability: Windows Git Bash skip-guards + doctor.sh auto-profile fix ✅ 2026-06-08

Windows v0.4.0 dogfood 發現三類問題，分 P1/P2/P3 修：

**P1 — `scripts/doctor.sh` auto-profile false FAIL**（release blocker）

`detect_hook_profile()` 的 `auto` case 只看 `codex_available`，不看平台。Windows Git Bash 若 PATH 有 codex CLI → 判定 `full` → 期待 codex hooks → FAIL。但 `install-hooks.sh` 在 Windows 正確安裝 `minimal`。

Fix：在 `check_hooks()` 的 `detect_hook_profile()` inner logic 中，先 `detect_platform == windows` → 強制 `_want_full=0`，再才看 `codex_available`。

**P2 — 測試套件缺 Windows skip-guards**（Windows CI 失敗）

| 套件 | 問題 | 修法 |
|---|---|---|
| `test-pr-gate-profile` | `create_runner` 用 `ln -sf` 建 system binary stubs | suite-level skip on windows |
| `test-claude-executor` case 5 | `ln -sfn` + `-L` check 在 MSYS 失敗 | case-level skip on windows |
| `test-dispatch-post-verify` 4 cases | `ln -sfn`/`ln -s` symlink security tests | case-level skip on windows |

**P3 — `uninstall.sh` 空目錄清理回饋**（UX）

pruning loop 改為：先 `-d` 判斷是否存在，成功 `rmdir` 後印 `pruned <dir>`，靜默略過非空目錄。

**See**: pr:#247


## CC-339 — lint: prevent duplicate CC id with divergent title ✅ 2026-06-08

**Problem**: The same CC id can silently map to two different tickets. CC-328 was assigned to the shipped light-alias work (#229, recorded in MILESTONES v0.4.0 旁支修正), then reused by the repo symbol-index ticket (#235) — only caught by manual reading during v0.5.0 planning. A knowledge/repo search index makes this worse: a recalled CC id that resolves to two meanings poisons the context-pack.

**Why**: canonical ticket metadata must be clean before it backs a search index. A divergent-title collision is mechanically detectable; relying on a human to notice it is the failure mode that produced this ticket.

**Requirement**: add a validator rule (in `pm/scripts/validate.sh` or a sibling wired into `lint.yml`) that asserts one CC id never maps to two different titles across the BACKLOG active body and MILESTONES tables. Emit an E-code on collision. The CC-328 → CC-338 renumber (DECISIONS 2026-06-08) is the first fixture.

**Amendment (DECISIONS 2026-06-08)**: the literal "compare title *strings* across BACKLOG/MILESTONES" above proved unworkable — all title surfaces are free-form and legitimately divergent (EN title vs ZH description; one id repeated per milestone). The shipped invariant is the string-comparison-free equivalent: one id never both **open on the active board** and **closed in the archive** (cross-lifecycle collision). This narrower-but-mechanical scope is intentional, not drift — see the Result note below and DECISIONS.

**Milestone**: v0.5.0 Phase 0 follow-up (hygiene; not blocking the spine).

**Priority**: P3.

**Result**: Shipped as `pm/scripts/lint-ticket-ids.sh` (sibling, not folded into `validate.sh`), wired into `lint.yml` as the `lint-ticket-ids` job. The literal "compare title strings across BACKLOG/MILESTONES" framing was unworkable (all title surfaces are free-form and legitimately divergent — EN title vs ZH description, ids repeated per-version), so the invariant was reinterpreted as a string-comparison-free **cross-lifecycle collision**: no id may be open (non-stub) on the active board while also closed in the archive. On first run it caught two pre-existing collisions — `debt-auditor` (CC-329) and `/discover` (CC-330) reusing closed archive ids — both renumbered to [[CC-342]] / [[CC-343]] in this PR. See DECISIONS 2026-06-08.

**Cross-link**: [[CC-338]] (renumber that motivated this), [[CC-342]], [[CC-343]] (collisions caught), [[CC-237]].

**See**: pr:#250

## CC-340 — knowledge index: standalone FTS over memory/backlog/decisions 🟢 someday → v0.6.0

**Problem**: The repo index (CC-338) covers the code plane ("where to change, what to reuse"), but the second-brain plane — "why, how was this decided, what failed before" — has no structured search backing the context-pack. `/mem-search` exists as a skill but is keyword/grep over files, not an index with ranking or trust tiers.

**Why**: knowledge and repo are two different search planes with opposite lifecycles (curated/durable vs derived/rebuildable). v0.5.0 ships the repo plane + the shared interface (CC-237). The **anchored-TOC slice** of the knowledge index (per-section chunking + memory-card indexing — enough to make the read side usable) is pulled forward to **CC-354** (v0.5.0 Phase 2), because without it the knowledge plane has no queryable index at all. CC-340 narrows to the **heavy remainder**: standalone full-text ranking, embeddings, and low-trust episodic chunking — deferred to v0.6.0, overlapping the existing `/mem-search` surface.

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

## CC-354 — anchored knowledge index + retrieval reflex（read-half of the memory loop）

**Problem**: The knowledge plane (BACKLOG / DECISIONS / MILESTONES / memory cards) has no queryable index. `pmctl context query` (CC-338/237/239) only indexes the repo plane (files / symbols / chunks). Worse, the indexer stores exactly one `head -c 2000` chunk per file (`_ctx_generate_file_sql` in `scripts/lib/pmctl-context.sh`), so a 180 KB BACKLOG.md only has its first ~30 lines indexed — CC-234 at line 615 is unreachable, and finding it requires grep. Out-of-repo memory cards (`~/.claude/.../memory/`) are not scanned at all. Net effect: the whole context substrate exists but the read reflex is still grep.

**Why**: This is the **read side** of the v0.5.0 memory read+write loop. Semantic transformation belongs on the write side (CC-234 memory cards); the read-side index over structured docs should be an **anchored table-of-contents**, not a copy of the document — humans already semantically chunked these files into `## CC-NNN` titled sections, so the heading IS the distilled summary. No LLM pass, always fresh, exact-match preserved, refs point to the real section for lazy-read.

**Requirement**:
- **Per-format chunking strategy** (replaces the current single `head -c 2000` chunk; dispatch by `_ctx_detect_language`):
  - **markdown** → heading-based: split on `^#{1,6}` into per-section chunks; store heading + extracted CC-id/decision-id + short lead (Problem/Why first lines), NOT the full body.
  - **txt / json / yaml / other non-heading formats** → window-based: fixed N-line windows with line anchors (also fixes the current head-2000-only limitation for any large non-markdown file).
  - **html** → window fallback for this slice; semantic `<h1-6>` chunking deferred to CC-355 (robust HTML parsing in bash is a separate concern).
  - All strategies populate the already-existing `file_chunks.heading` / `line_start` / `line_end` columns — no schema migration. The chunker must be a pluggable per-format seam so CC-355 (and future formats) plug in without rewriting the caller.
- **Domain tagging**: path-based classifier so hits from BACKLOG / DECISIONS / MILESTONES / docs emit `source_domain: knowledge` + `trust_level: high` (currently `_ctx_query_hits_raw` hard-codes `repo`).
- **`pmctl context query --domain knowledge|repo`** optional filter.
- **Retrieval reflex (platform-neutral)**: document the query-before-grep discipline in a neutral `docs/` contract referenced by the dispatch/executor contract; surface `pmctl context query` as the ergonomic first stop. Do NOT write it into CLAUDE.md (platform binding); only a one-line pointer in `agents/project-pm.md`.
- FTS5 optional; `LIKE` / `grep` fallback mandatory and tested (consistent with CC-338).

**Scope boundary (decided 2026-06-10)**: this slice indexes **in-repo knowledge docs only** (BACKLOG / DECISIONS / MILESTONES / docs). Out-of-repo memory cards (`~/.claude/.../memory/`) are NOT indexed here — they are already surfaced to the agent via MEMORY.md auto-injection + `/mem-search`, so indexing them now would duplicate an existing mechanism. Indexing memory cards into pmctl is deferred until a real need appears (then revisit alongside CC-340 / CC-333). Consequence: CC-354 does not touch memory-dir path resolution, so it does not trigger CC-333.

**Acceptance**: `pmctl context query CC-234` returns `BACKLOG.md:<section-line>` (the in-repo grep problem is fixed); `.txt` / large `.json` files return window chunks beyond their first 2000 bytes; the query-before-grep discipline is documented neutrally with the project-pm pointer. Memory-card retrieval is out of scope (stays on auto-injection).

**Non-goals** (stay in CC-340): indexing out-of-repo memory cards / episodes; embeddings / semantic backend; full-text ranking; making SQLite the source of truth. This slice is the minimum that makes the in-repo knowledge-doc read side usable.

**Milestone**: v0.5.0 Phase 2 (memory read+write loop, read half).

**Priority**: P2.

**Cross-link**: [[CC-234]] (write side), [[CC-355]] (html semantic chunking follow-up), [[CC-340]] (heavy remainder, this is its pulled-forward slice), [[CC-338]] (repo-index machinery reused), [[CC-237]] (context_hit_v1 interface), [[CC-349]] (symmetric: removed markdown symbols, this adds markdown section chunks).

## CC-355 — knowledge index: HTML semantic chunking（`<h1-6>` sections）🟢 someday

**Problem**: CC-354 chunks knowledge files by a per-format strategy — markdown by `^#{1,6}` headings, txt/other by line windows. HTML files fall back to window chunking, which loses their real section structure (`<h1>..<h6>` headings carry the same human-authored semantic anchors as markdown headings).

**Why**: HTML is structurally symmetric to Markdown (`<h1-6>` ≈ `^#{1,6}`), so it deserves heading-based chunking for the same retrieval quality. It is split out of CC-354 because robust HTML parsing in bash/grep is its own concern (nested tags, attributes, comments, `<pre>`/`<code>` blocks, entity decoding) and there is no `.html` knowledge source in the repo today — this is forward-looking generality, not a current need.

**Requirement** (when an HTML knowledge source appears):
- Plug an `html` strategy into the CC-354 per-format chunker seam: split on `<h1>`..`<h6>`, use the (tag-stripped) heading text as the chunk heading, strip tags for the lead.
- Handle the parsing edge cases (comments, `<pre>`/`<code>`, entities) or document the known-fragile boundaries.
- Reuse the existing `file_chunks` columns; no schema migration.

**Trigger**: a real `.html` file enters the knowledge plane, or a consumer needs HTML-section retrieval.

**Priority**: P3.

**Cross-link**: [[CC-354]] (per-format chunker seam this plugs into), [[CC-340]] (knowledge index family).

## CC-341 — pmctl validate: wire handover-validate framework into pmctl ✅ 2026-06-09

**See**: pr:#252

**Problem**: The handover-validator framework (CC-202) was extracted and shipped via PR #170, but the `pmctl validate` subcommand that exposes it was deferred ("→ pmctl validate 串接移 M3") and never landed. MILESTONES v0.5.0 was pointing at the **closed** CC-202 for this remaining wiring, leaving it without an active ticket — surfaced during v0.5.0 follow-up review 2026-06-08.

**Why**: CC-202 is closed (framework done); reusing a closed id for open work is the same divergent-reference hazard the CC-328 → CC-338 renumber fixed. The remaining wiring deserves its own active id.

**Shipped**: `scripts/lib/pmctl-validate.sh` with `pmctl_validate_brief` + `validate/brief` case in `cli/pmctl` + 6-case test suite (`test-pmctl-validate.sh`). Exit-code contract: 0 = valid, 1 = invalid block/metadata, 2 = usage error. Read-only by design (like `pmctl guard check`) — no events written; callers use the exit code to gate dispatch.

**Milestone**: v0.5.0 Phase 2.

**Priority**: P2.

**Cross-link**: [[CC-202]] (framework, closed), [[CC-215]] (pmctl subcommand surface), [[CC-237]].
