<!-- pm-schema: v1 -->
# pm-dispatch backlog

<!--
ID PREFIX: CC
CC-001/CC-002 were consumed by PR #24 fix bundle inline, with no standalone entries; this file starts at CC-003.
-->

## Index

| #  | Status | 主題 | 影響面 | 首次記錄 | Refs |
|----|--------|------|--------|----------|------|
| CC-003 | 🔵 active | parallel-gate artifact-ignore 前置檢查 | ops/arch | 2026-05-12 | pr:#38 |
| CC-004 | 🔵 active | test-pr-gate.sh docstring 格式統一 | ops | 2026-05-12 | pr:#38 |
| CC-005 | 🔵 active | install.sh preflight 跑 test-pr-gate 增加延遲 | ops | 2026-05-12 | pr:#38 |
| CC-006 | ✅ closed 2026-05-13 | statusLine hook 自動寫入 rate-limits，`--remaining` 免手動輸入 | ux | 2026-05-13 | pr:#42 |
| CC-007 | ✅ closed 2026-05-13 | brief qa_checklist 指引寫入 docs/codex-brief.md + agents/project-pm.md | process | 2026-05-13 | pr:#42 |
| CC-008 | ✅ closed 2026-05-13 | Spark routing 判斷標準寫入 agents/project-pm.md | arch | 2026-05-13 | pr:#41 |
| CC-009 | ✅ closed 2026-05-14 | UserPromptSubmit hook 自動 inject MEMORY.md 防止 auto-compact 遺忘 | ux/memory | 2026-05-14 | pr:#44 |
| CC-010 | ✅ closed 2026-05-14 | `/memory-compress` 指令：壓縮 MEMORY.md 條目減少 inject token 量 | ux/memory | 2026-05-14 | pr:#45 |
| CC-011 | ⏸ deferred | sync-memory.sh + install 選項：symlink memory 到雲端資料夾實現跨裝置共用 | ux/memory | 2026-05-14 | — |
| CC-012 | ⏸ deferred | SessionStart hook：session 啟動時 pull 最新 memory（git/rsync）確保跨裝置同步 | ux/memory | 2026-05-14 | — |
| CC-013 | ✅ closed 2026-05-18 | `/caveman` token 壓縮 skill：lite/full/ultra 模式，長 session 降低 token 消耗 | ux | 2026-05-14 | gate:GO R7 |
| CC-014 | 🔵 active | `using-git-worktrees` skill：parallel PR gate 隔離開發環境 | arch | 2026-05-14 | — |
| CC-015 | 🔵 active | `systematic-debugging` skill：結構化偵錯工作流 | ux | 2026-05-14 | — |
| CC-016 | ✅ closed 2026-05-14 | gate NO-GO fix-loop 效率：PM brief 撰寫策略（discovery + --targeted + source-first） | process | 2026-05-14 | pr:#43 |
| CC-017 | ✅ closed 2026-05-14 | 前端 UI 實作前置流程：提供圖片時需先讀取確認再 brief | process/ux | 2026-05-14 | pr:#43 |
| CC-018 | 🔵 active | Codex quota 自動追蹤：codex-dispatch 後查詢剩餘 quota 寫入 rate-limits-codex.json | ux/token | 2026-05-14 | — |
| CC-019 | ✅ closed 2026-05-14 | Episodic memory 層：Stop hook metadata + `/mem-log` + `/mem-recall` + `/mem-distill` | ux/memory | 2026-05-14 | pr:#45 |
| CC-020 | ✅ closed 2026-05-14 | `/mem-search`：`rg` 關鍵字過濾 + Claude 語意理解，跨 memory 檔搜尋 | ux/memory | 2026-05-14 | pr:#45 |
| CC-021 | ✅ closed 2026-05-14 | test scripts 支援 `--filter <pattern>` + `--list` 只跑/列出名稱匹配的 test case | ops/test | 2026-05-14 | pr:#45 |
| CC-022 | ✅ closed 2026-05-14 | `/pre-impl` 指令：開發前設計評審，強制定義邊界/依賴/變動點，減少事後重構 | ux/arch | 2026-05-14 | pr:#46 |
| CC-023 | ⏸ deferred | `coupling-reviewer`：PR gate 加入語言感知耦合分析（dependency-cruiser/gocyclo/coca） | ops/gate | 2026-05-14 | — |
| CC-024 | 🔵 active | `test-usage-weekly.sh` 加入 GitHub Actions CI（lint.yml 新增 job） | ops/test | 2026-05-14 | pr:#48 |
| CC-025 | ✅ closed 2026-05-18 | `/skill-refine`：讀 skill 執行 episodes + 後續更正訊號，提 diff 自我精修 | ux/memory | 2026-05-15 | pr:#67,#68 |
| CC-025b | ✅ closed 2026-05-18 | `/skill-refine` M1+M2 advisory follow-ups：M1 usage-guard tests + `CLAUDE_MEMORY_DIR` 環境契約文件化/repo-default fallback | ux/memory/test | 2026-05-17 | feat/cc039-cc025b-v2 |
| CC-026 | 🔵 active | `/skill-distill`：偵測重複工作流，產出草稿 skill .md | ux/memory | 2026-05-15 | — |
| CC-027 | ✅ closed 2026-05-15 | PreToolUse `hook-tool-trace.sh`：tool/skill 觸發落 tool-trace.jsonl（CC-025/CC-026 前置） | ux/memory | 2026-05-15 | pr:#54 |
| CC-027b | 🟡 deferred | `tool-trace.jsonl` health signal：bounded error counter + downstream warning | ux/memory | 2026-05-15 | — |
| CC-027c | 🟡 deferred | `hook-tool-trace.sh` strict JSON validation：jq inline cost ~25ms/call 超 budget；探索 async post-validation 或 sampled fraction | ux/memory | 2026-05-15 | — |
| CC-028 | ✅ closed 2026-05-15 | PostToolUse `hook-routing-log.sh`：codex-dispatch 自動 append routing_log 記錄 Q1/Q2/Q3 校準資料 | ux/memory | 2026-05-15 | pr:#55 |
| CC-029 | ✅ closed 2026-05-15 | `test-codex-dispatch.sh` 加入 CI（與 CC-024 並行做 lint.yml 補完） | ops/test | 2026-05-15 | pr:#57 |
| CC-030 | 🔵 active | `pm/scripts/validate.sh` 補 Index ↔ Section 雙向一致性 + CHANGELOG drift 檢查 | ops/process | 2026-05-15 | — |
| CC-031 | 🔵 active | 開源前置：`CONTRIBUTING.md` + `SECURITY.md` + README 工作語言聲明 | process/DX | 2026-05-15 | — |
| CC-032 | 🔵 active | `[[feedback_*]]` cross-link 公開化：抽到 `docs/policies/` glossary 避免 dead link | process/DX | 2026-05-15 | — |
| CC-033 | 🔵 active | Public flip checklist：Issues/Discussions 設定、CITATION.cff（選配）、後續觀察期 | process | 2026-05-15 | — |
| CC-034 | ✅ closed 2026-05-15 | `install-hooks.sh` 改名/移動 checkout 後 append-not-replace bug：以 hook script basename 取代 full-path 比對 | ops | 2026-05-15 | pr:#53 |
| CC-035 | 🔵 active | install/uninstall-hooks basename+scripts/ heuristic：未覆蓋另一工具也在 scripts/ 下同名 hook 的 collision edge case | ops | 2026-05-15 | pr:#53 |
| CC-036 | ✅ closed 2026-05-18 | `/pm` dispatch async ergonomics restore：classify+brief 仍走 subagent；execute 改 main-thread `Bash(codex-dispatch.sh, run_in_background:true)` 直派；恢復 dispatch + 完成通知並行 | ux/process | 2026-05-15 | verified-in-place |
| CC-037 | ✅ closed 2026-05-18 | `hook-routing-log.sh` concurrent append race：並行 PostToolUse 可能 silent-drop routing row | ux/memory | 2026-05-15 | verified-in-place |
| CC-038 | ⏸ deferred | Windows / cross-platform 鎖機制：`flock` Linux-only，未來支援 Windows/macOS 需替代方案 | ops/portability | 2026-05-15 | CC-037 follow-up |
| CC-039 | 🔵 active | shared-schema brief enrichment + `/pre-impl` Q4 repo-rule audit + 每輪 fix brief next-layer sweep（JS-110、CC-013 兩次 7 輪 gate 後驗證） | process | 2026-05-15 | — |
| CC-036b | ✅ closed 2026-05-16 | dispatch handover authorized-override reconciliation：spec 允許 caller-authorized `skip_git_check:true` / `sandbox:danger-full-access` / `approval:on-request`，但 validator 預設 hard-reject 無 override channel；docs/commands example 也需 default-safe 化 | arch/process | 2026-05-16 | CC-036 follow-up |
| CC-040 | ✅ closed 2026-05-16 | agent-agnostic dispatch schema rename：`docs/codex-brief.md` → `docs/dispatch-brief.md` + `codex_dispatch_handover_v1` → `dispatch_handover_v1` + `executor:` 欄位（為未來非 codex executor 預留） | arch/process | 2026-05-15 | pr:#66 |
| CC-044 | ⏸ deferred | `tool-trace.jsonl` rotation/retention policy（max sessions vs bytes vs archive） | ux/memory | 2026-05-15 | — |
| CC-045 | ⏸ deferred | brief timeout heuristic：依 target repo playbook depth 設 timeout，不能只看 edit size；brief context 可加「skip playbook re-read」短路指令；codex-dispatch.sh 可選 warn 當 repo 有 `rules/`/`AGENTS.md` 且 timeout < 900s | process/DX | 2026-05-16 | — |
| CC-046 | ⏸ deferred | validate.sh + run-tests.sh dedup：(a) 第二個 awk pass (changelog drift) 重複解析 backlog index status / refs，shared parsing 抽出；(b) `run_validate_case_multi` 與 `run_validate_case` assertion body 高度重複，改 varargs 單一 helper | ops/test | 2026-05-16 | — |
| CC-047 | ✅ closed 2026-05-17 | `scripts/codex-dispatch.sh` model alias mapping：`--model codex-spark` 透傳給 codex CLI 後得到 400 invalid_request_error（API 只認 `gpt-5.3-codex-spark`），需要 alias 表把短名映射到 codex CLI 接受的全名 + reasoning effort | ops/dispatch | 2026-05-17 | pr:#69 |
| CC-100 | ✅ closed 2026-05-17 | **[CC-OSS Phase 1]** Sanitize personal paths + OSS-baseline docs：拔 `/home/<user>` 硬編碼 → `${PM_DISPATCH_REPO}` env contract；新增 `CONTRIBUTING.md` + `CODE_OF_CONDUCT.md`；LICENSE 已存在 | process/docs | 2026-05-17 | pr:#71 |
| CC-101 | ✅ closed 2026-05-17 | **[CC-OSS Phase 2 spike]** Executor-contract schema + adapter design：brief schema 加 `executor:` 欄位；`docs/executor-contract.md`；CC-040 schema rename 延伸 | arch/process | 2026-05-17 | pr:#72 |
| CC-102 | ✅ closed 2026-05-17 | **[CC-OSS Phase 2 impl]** `claude-executor` agent + `install.sh --profile minimal\|full`：minimal profile 跳過 codex hooks，預設 executor=claude；既有 codex flow 全 regression pass | arch/install | 2026-05-17 | pr:#73 |
| CC-102b | ✅ closed 2026-05-17 | CC-102 PR-gate advisory follow-ups：(a) 直接 e2e regression test 覆蓋 `install.sh --profile minimal\|full` + auto-detect；(b) install-hooks.sh minimal profile downgrade — fold-in 進 CC-102 同 PR（qa-tester r2 升 block；都已修） | ops/install | 2026-05-17 | pr:#73 |
| CC-103 | ✅ closed 2026-05-17 | **[CC-OSS Phase 3]** `scripts/lib/portable.sh` shim（`realpath_m` / `safe_tmpdir` / `mkdir_lock` / `file_size_bytes`）+ `docs/platform-support.md`；改寫 3 個 hook 用 shim；`install-hooks.sh` 偵測 platform 跳過 Linux-only hook | ops/portable | 2026-05-17 | pr:#74 |
| CC-103b | ✅ closed 2026-05-17 | CC-103 follow-up: `/pr-gate` executor split — `--executor codex|claude|auto`; mirror CC-102 `/pm` route split so minimal-profile users can run the gate | arch/install | 2026-05-17 | pr:#75 |
| CC-104 | ✅ closed 2026-05-17 | **[CC-OSS Phase 4]** Onboarding docs batch：README intro rewrite + `docs/GETTING_STARTED.md` + `docs/memory-system.md` + 7 個 `commands/*.md` 補 what/when/example 三段（pm.md / pr-gate.md 已含 Route A/B 故跳過） | docs/ux | 2026-05-17 | pr:#76 |
| CC-105 | ✅ closed 2026-05-17 | **[CC-OSS Phase 5]** v0.1.0 release：`CHANGELOG.md` [0.1.0] section + BACKLOG status flip + private→public visibility + tag v0.1.0 + GitHub release + main branch protection（require linear history） | process/release | 2026-05-17 | pr:#77 |
| CC-104b | 🔵 active | **[Windows dogfood r1 fixes]** install-hooks jq error → platform-aware install hints | ops/install | 2026-05-17 | pr:#79 |
| CC-104c | 🟡 deferred | **[Windows dogfood r1 fixes]** install.sh `link()` → `link_or_copy()`: detect post-creation if `ln -s` produced a real symlink (Git Bash without dev-mode + `MSYS=winsymlinks:nativestrict` silently copies); fall back to `cp -r` + manifest file (`~/.claude/.pm-dispatch-manifest.json`); re-install uses manifest instead of `[[ -L ]]` check. Without this, "edit source → ~/.claude/ live" workflow breaks on Windows | arch/install | 2026-05-17 | — |
| CC-104d | 🟡 deferred | **[Windows dogfood r1 findings]** Hardcoded `$HOME/github` read root default in `hook-codex-bash-guard.sh:54`; `CLAUDE_HOOK_CODEX_READ_ROOTS` env override exists but default is wrong on Windows where repos live under `~/Documents/github/` or arbitrary paths. Should be derived from `PM_DISPATCH_REPO` parent or removed | ops/hook | 2026-05-17 | — |
| CC-104e | 🟡 deferred | **[Windows dogfood r1 findings]** WSL ↔ Windows `~/.claude/projects/<project-id>/memory/` divergence: project ID is path-sanitization of working dir. Same repo cloned at `~/github/pm-dispatch` (WSL) and `C:\Users\<user>\Documents\github\pm-dispatch` (Windows) produces different IDs → memory partitioned. Harness-level (Claude Code) issue; document workaround (symlink, or PM_DISPATCH_PROJECT_ID override) | ux/memory | 2026-05-17 | — |
| CC-104f | 🟡 deferred | **[Windows dogfood r1 findings]** jq is hard-dep for hooks layer. Options: vendor static `gojq` binary (3 MB × 3 platforms), or expose `--no-hooks` install mode that skips hook wiring entirely (lightweight install for jq-less users). Latter preferred — keeps "no auto-install of system pkgs" principle | arch/dep | 2026-05-17 | — |
| CC-104g | ⚠️ partial 2026-05-17 | **[Windows dogfood r1 fixes]** portable.sh test fixes: symlink test SKIP + detect_platform host_native PASS on Windows ✅; mkdir_lock FIFO sync ✅ but underlying `mkdir` on Git Bash still allows second concurrent acquire — real Windows portability bug, NOT test sync issue. See CC-104k | ops/test | 2026-05-17 | pr:#80 |
| CC-104h | ✅ closed 2026-05-17 | **[Windows dogfood r1 fixes]** `handover-validate.sh` brief_file validator now accepts paths under `/tmp` + `$TMPDIR / $TEMP / $TMP` (POSIX or MSYS forward-slash form). Windows backslash paths still rejected at metadata-metachar level — documented limitation | ops/validator | 2026-05-17 | pr:#80 |
| CC-104i | ✅ closed 2026-05-17 | **[Windows dogfood r1 fixes]** `.gitattributes` forces LF — verified `file install.sh ... portable.sh` no CRLF after checkout on Windows | ops/repo | 2026-05-17 | pr:#80 |
| CC-104j | 🟡 deferred | **[Windows dogfood r1 r2 finding]** `test-dispatch-handover.sh:674-685` `brief_file_symlink_rejects_case` uses `ln -s` for fixture setup; on Git Bash falls back to copy → validator treats as regular file → test fails. Same skip-if-not-symlink pattern as CC-104g case (a) — `[[ -L "$link" ]]` precondition → SKIP | ops/test | 2026-05-17 | — |
| CC-104k | 🟡 deferred | **[Windows dogfood r1 r2 finding]** **Real Windows portability bug**: `mkdir_lock` allows second concurrent acquire on Git Bash even when lockdir exists (FIFO test sync confirms first holder acquired). Suspect: Git Bash `mkdir` is not atomic create-if-not-exists for some path shapes, OR `sleep 1.2` doesn't actually sleep 1.2s. Need: investigate via `strace`/`procmon` on Windows; possibly use `flock` with sibling lockfile when on POSIX, fall back to filesystem-specific atomic primitive on Windows. Blocks `hook-routing-log.sh` concurrent-safety on Windows | ops/portable | 2026-05-17 | — |
| CC-104l | 🟡 deferred | **[Windows dogfood r1 r2 finding]** jq install hint visibility: install-hooks.sh shows the platform-aware hint per CC-104b (#79), BUT install.sh preflight runs `test-hooks` FIRST which fails with bare "jq missing" repeated 200+ times before hitting install-hooks.sh. Add (a) jq prerequisite check at top of install.sh BEFORE preflight (one-line hint), (b) jq install command at top of README "Install" section so first-time readers see it before clicking through to platform-support.md | ops/install/ux | 2026-05-17 | — |
| CC-200 | ⏸ deferred | **[Reuse debt]** `scripts/lib/executor-router.sh` — 抽出共用 codex/claude routing logic（目前 `/pm`、`/pr-gate` 各寫一套，未來 N=3 consumer 痛點） | arch/reuse | 2026-05-17 | — |
| CC-201 | ⏸ deferred | **[Reuse debt]** `detect_executor_profile()` shim 進 `scripts/lib/portable.sh` — `install-hooks.sh` + `pr-gate.sh` 各自重複 `command -v codex` 判斷 | arch/reuse | 2026-05-17 | — |
| CC-202 | ⏸ deferred | **[Reuse debt]** handover validator framework — `dispatch_handover_v1` 與 `pr-gate-handover_v1` 共用 fence/metadata/body validator 抽象；future handover schemas 不再手刻 | arch/reuse | 2026-05-17 | — |
| CC-203 | ⏸ deferred | **[Reuse debt]** `scripts/lib/test-harness.sh` — 8+ 個 `test-*.sh` 都各寫 `--filter/--list`/`should_run()`/PASS-FAIL counter/scratch dir setup；source-able 共用 lib 統一 | ops/test/reuse | 2026-05-17 | — |
| CC-204 | ⏸ deferred | **[Reuse debt]** hook framework — pm-write-guard/codex-bash-guard/codex-write-guard/routing-log 共通 stdin-json-parse → decision-matrix → audit-log 結構；目前 copy-paste-modify | arch/hook/reuse | 2026-05-17 | — |
| CC-049 | 🟡 deferred | **[BACKLOG hygiene Tier 1]** Archive closed CC ticket detail sections → `BACKLOG-ARCHIVE.md`. Currently 26 closed sections cluttering 688-line BACKLOG body; index status emoji + PR ref preserved in main file, full prose moved to archive. Goal: reduce active BACKLOG to ~350 lines for faster scan | process/docs | 2026-05-17 | — |
| CC-050 | 🟡 deferred | **[BACKLOG hygiene Tier 1]** Audit stale deferred tickets CC-011/012/013/014/015 (memory-sync / SessionStart pull / `/caveman` / using-git-worktrees skill / systematic-debugging skill) from 2026-05-14. Post-CC-OSS public, some may be obsolete or low-priority; mark `🟢 backlog-for-someday` or drop with reasoning recorded | process/docs | 2026-05-17 | — |
| CC-051 | 🟡 deferred | **[BACKLOG hygiene Tier 1]** Add schema convention preamble at top of BACKLOG.md: ID convention (`CC-NNN` sequential except `CC-1NN` = CC-OSS epic markers, `CC-2NN` = reuse-debt markers — semantic groupings, not numeric ranges), sub-letter convention (`CC-NNNa/b/c` = follow-ups to parent ticket), status emoji legend (✅ closed / 🟡 deferred / 🔵 active / ⚠️ partial / ⏸ deferred-low-pri). Without this docs, fork users see "weird gaps" and don't know the conventions | process/docs | 2026-05-17 | — |
| CC-052 | 🟡 deferred | **[BACKLOG schema upgrade]** Tier 2 alternative: `pm-schema v1.1` adds `epic:` field — sequential IDs (CC-048..) with `epic: oss` / `epic: reuse-debt` as orthogonal grouping. Retroactive renumbering of CC-100/200 series + PR/commit refs is expensive; only do if multi-month signal that the ID-gap convention is causing real confusion. CC-051 (preamble) is the cheaper resolution | process/schema | 2026-05-17 | — |

---

## CC-003 — parallel-gate artifact-ignore 前置檢查

**Problem**: scripts/pr-gate.sh parallel mode 在 line 410/414 對 git status --porcelain 取 fingerprint，但 fingerprint 取樣後 gate 本身會寫入 .agent-trace/ / .codex-briefs/ / .gate-results/。若 target repo 沒跑過 setup-project.sh 或這三個路徑未在 .gitignore，gate 自己的寫入就會改動 status hash，觸發 line 575 的 fail-closed integrity check，在原本健康的 repo 卡住 PR review。
**Why**: parallel mode 整體假設「gate 執行期間 git status 不會被 gate 自己污染」。這假設只在 .gitignore 已含三個 artifact 路徑時成立，但 setup-project.sh 是否跑過、是否完整，gate 沒有 preflight 驗證。Cross-reviewer overlap (qa-tester + risk-reviewer 同點)，代表不是單一 reviewer 視角偏見。Loud + reversible (不會默默過 gate)，但屬於把工作流卡死的 ops 問題。
**Requirement**: parallel mode 啟動時必須能在 target repo 確認 gate artifact 路徑已被 ignore，或結構性排除這些路徑使其不影響 integrity check。可接受任一方向：preflight ignore-coverage 檢查（缺則明確指引跑 setup-project.sh）；或 integrity check 計算 status hash 時排除 known gate artifact paths；或文件 + test 明示 setup-project.sh 是 parallel mode precondition，並讓未滿足時的失敗訊息直接指向修復步驟。

## CC-004 — test-pr-gate.sh docstring 格式統一

**Problem**: scripts/test-pr-gate.sh 新增的 shell test functions 使用散文註解描述行為，而非 pm-schema 規範的 structured behavior/Steps docstring 形式。
**Why**: tests 本身 behavior-named、deterministic，功能無虞，純為 audit-quality / 一致性問題。長期會讓新人讀測試時樣式不一。
**Requirement**: 把新增 test functions 的開頭註解改寫成與既有 hook tests 一致的 behavior/Steps docstring 結構。不改測試邏輯。

## CC-005 — install.sh preflight 跑 test-pr-gate 增加延遲

**Problem**: install.sh:151 把展開後完整的 test-pr-gate.sh 加入 preflight 套件，install 整體時間變長。
**Why**: 風險面是低的（失敗 loud、rollback = revert 該行 preflight），但每次 install 都付出代價。如果未來 test-pr-gate 套件繼續長大，install 體驗會持續惡化，現在留個 entry 以便未來決策時有歷史。
**Requirement**: 監測 install 端到端時間；若 preflight 變成 dev 體驗瓶頸，考慮 (a) 拆 fast / slow tiers、(b) 預設 fast，full 由 env var 觸發、(c) 在 CI 跑 full 而 install 只跑 smoke 子集。目前不需立即動作。

## CC-006 — statusLine hook 自動寫入 rate-limits ✅ 2026-05-13

**Outcome**: `scripts/token-usage.sh` 取代 `claude-usage.sh`；`hook-save-rate-limits.sh` StatusLine hook 自動寫入 `~/.claude/rate-limits.json`，`--remaining` 免手動輸入剩餘 %。
**See**: pr:#42

## CC-007 — brief qa_checklist 指引 ✅ 2026-05-13

**Outcome**: `docs/codex-brief.md` 加入 `qa_checklist` 選填區塊規範；`agents/project-pm.md` 加入 PM 生成 brief 時的對應指引。
**See**: pr:#42

## CC-008 — Spark routing 判斷標準 ✅ 2026-05-13

**Outcome**: `agents/project-pm.md` 加入 Spark routing 三條件判斷規則（diff < 50 行、≤ 2 檔案、無跨模組依賴）。
**See**: pr:#41

## CC-009 — UserPromptSubmit hook inject MEMORY.md ✅ 2026-05-14

**Outcome**: `scripts/hook-inject-memory.sh` 新增；每次 UserPromptSubmit 時注入完整 MEMORY.md index 防 auto-compact 遺忘；≥50 條時發出 `/memory-compress` directive。
**See**: pr:#44

## CC-010 — `/memory-compress` 指令 ✅ 2026-05-14

**Outcome**: `commands/memory-compress.md` 新增；slash command 讓 Claude 壓縮/合併 MEMORY.md 條目，支援 `--dry-run`。
**See**: pr:#45

## CC-011 — sync-memory.sh + 跨裝置共用（deferred）

**Problem**: `~/.claude/projects/*/memory/` 為本機路徑，多台電腦之間 memory 各自獨立，無法共用。
**Why**: 用戶目前不急，但設計上若以 symlink 指向 Dropbox/iCloud/OneDrive 資料夾，可以零維護代價實現跨裝置共用，且完全相容現有 file-based memory 架構。
**Requirement**: `scripts/sync-memory.sh --setup <cloud-path>` 把 memory 資料夾 symlink 到雲端同步路徑；`install.sh` 加入 opt-in 步驟。

## CC-012 — SessionStart hook pull memory（deferred）

**Problem**: 若多台電腦透過 CC-011 共用同一雲端 memory 資料夾，session 啟動時不保證已取得最新版本。
**Why**: 輕量方式是 SessionStart hook 觸發一次 rsync/git pull，確保 memory 是最新版。
**Requirement**: `scripts/hook-sync-memory.sh` SessionStart hook；支援 git pull 和 rsync 兩種模式；失敗時靜默降級。
**Note**: 依賴 CC-011。

## CC-013 — `/caveman` token 壓縮 skill ✅ 2026-05-18

**Problem**: 長 session 中 Claude 回應冗長，token 消耗快速，尤其在 codex brief 審核、多輪 gate 等場景。
**Why**: Caveman 專案實測降低 65-75% token 用量，架構（slash command + hook）與 pm-dispatch 完全相容。
**Requirement**: `commands/caveman.md` slash command，切換壓縮模式（off / lite / full / ultra）；`/caveman-commit` 變體生成超簡潔 commit message。

**Outcome**: gate GO（R7，2026-05-18）。實作摘要：
- `commands/caveman.md`：off/lite/full/ultra 四模式切換；空參/無效參數各有明確 stop-before-Step-2 行為；Step 2 輸出固定格式 `Caveman mode: <MODE>`
- `commands/caveman-commit.md`：讀 `git diff --cached` → 推斷 type/scope/subject → 純文字輸出；breaking-change 用 `!` append 到 type/scope；`$ARGUMENTS` 作 hint
- 8 個 agent 檔全部加入 `# Output brevity` section（agent-to-agent 壓縮常態化；`/caveman` 僅影響對用戶的回應）
- `scripts/test-commands.sh`：66 個 contract assertions；CI job 已接入 `.github/workflows/lint.yml`

**Post-mortem（7 輪 gate）**：屬於 CC-039 記錄的「洋蔥剝皮」模式的第二個案例。具體觸發條件：同一 PR 同時新增功能檔案 + 對應的 contract test script，qa-tester 對 test script 的完整性要求與對功能本身同等嚴格，但無事先 behavioral contract 清單，導致每輪只補 1–2 個缺口。見 CC-039 補充分析。

## CC-014 — `using-git-worktrees` skill

**Problem**: `--parallel` PR gate 各 reviewer 在同一 working tree 執行，reviewer 寫入可能互相干擾。
**Why**: git worktree 讓每個 subagent 在獨立環境工作，避免狀態污染，也直接補強 CC-003 的解法方向。
**Requirement**: `commands/using-git-worktrees.md` skill，指導平行開發中使用 git worktree；評估 `--parallel` gate 是否可為每個 reviewer 建立獨立 worktree。

## CC-015 — `systematic-debugging` skill

**Problem**: debug 工作流目前無標準化流程，每次偵錯方式不一致，容易遺漏根本原因分析。
**Why**: 結構化偵錯步驟（reproduce → isolate → hypothesize → verify → fix → regression test）有助於複雜 bug 分析。
**Requirement**: `commands/systematic-debugging.md` slash command，提供結構化偵錯步驟。

## CC-016 — gate NO-GO fix-loop 效率 ✅ 2026-05-14

**Outcome**: `agents/project-pm.md` 加入 source-first、discovery 步驟、`--targeted` 重跑、「最少清單」四項 fix brief 撰寫規則。
**See**: pr:#43

## CC-017 — 前端 UI 實作前置流程 ✅ 2026-05-14

**Outcome**: `agents/project-pm.md` 加入 UI 實作前置規則：圖片讀取確認、互動狀態/RWD/元件邊界必問清單、brief 鎖定流程。
**See**: pr:#43

## CC-018 — Codex quota 自動追蹤

**Problem**: CC-006 解決了 Claude 5h rate-limit 自動讀取，但 Codex 無等效 hook 機制；目前 Codex 使用量只靠 `log-usage.sh` 手動寫入，用戶無法即時得知剩餘額度。
**Why**: Codex 走 OpenAI API 路徑，quota 資訊需要主動查詢（response header 或 `/v1/organization/usage`），架構不同於 Claude StatusLine hook。
**Requirement**:
1. 研究 Codex API response headers（`x-ratelimit-remaining-requests` / `x-ratelimit-remaining-tokens`）
2. 若有：`scripts/codex-dispatch.sh` dispatch 後解析 headers，寫入 `~/.claude/rate-limits-codex.json`
3. 若無：呼叫 `/v1/organization/usage` 或記錄技術限制
4. `token-usage.sh` 加入 Codex pool 剩餘顯示
**Note**: 實作前需先手動驗證 Codex API header 行為。

## CC-019 — Episodic memory 層 ✅ 2026-05-14

**Outcome**: `scripts/hook-session-summary.sh` Stop hook 記錄 metadata skeleton；`commands/mem-log.md` 生成語意摘要寫入 `episodes.jsonl`；`commands/mem-recall.md` 注入近期 episodes；`commands/mem-distill.md` 整合 episodes 更新 MEMORY.md。
**See**: pr:#45

## CC-020 — `/mem-search` 跨 memory 搜尋 ✅ 2026-05-14

**Outcome**: `commands/mem-search.md` 新增；`rg` 關鍵字過濾 + Claude 語意理解，跨所有 memory 檔搜尋。
**See**: pr:#45

## CC-021 — test scripts `--filter` / `--list` ✅ 2026-05-14

**Outcome**: `scripts/test-hooks.sh` 和 `scripts/test-install.sh` 新增 `--filter <pattern>` 只跑匹配 case，`--list` 列出所有 case 名稱。
**See**: pr:#45

## CC-022 — `/pre-impl` 開發前設計評審 ✅ 2026-05-14

**Outcome**: `commands/pre-impl.md` 新增；強制回答職責邊界/依賴方向/變動接縫三個設計問題，輸出可貼入 brief `constraints:` 的約束清單。同時修正 `pm/scripts/validate.sh` schema drift（`✅ done`、`⏸ deferred`、topic-area tokens）並對齊 `pm/schema.md`、`pm/templates/BACKLOG.md`。
**See**: pr:#46

## CC-024 — `test-usage-weekly.sh` 加入 GitHub Actions CI

**Problem**: `scripts/test-usage-weekly.sh`（20 tests）在 PR gate 手動執行通過，但 `.github/workflows/lint.yml` 未包含此 suite，merged PR 後無 CI 保護。
**Why**: `usage-weekly.sh` 是 read-only 報告工具，迴歸影響面低但覆蓋率現在是靠手動 gate 維持，長期不穩固。qa-tester 在 gate-20260514-174657 發出 advisory（non-blocking）。
**Requirement**: 在 `.github/workflows/lint.yml` 加入一個 `test-usage-weekly` job，執行 `bash scripts/test-usage-weekly.sh`；失敗 → CI 阻擋。

## CC-025 — `/skill-refine` skill 自我精修

**Problem**: skill / command（`/pr-gate`、`/codex-pr-gate`、`/pm`、`/pre-impl` 等）的 .md 內容是手寫的，使用過程中遇到的卡點與更正只會沉澱成 feedback memory（例：[[feedback_gate_on_stacked_branches]]、[[feedback_stale_binary_before_smoke]]），不會回流到 skill 本身。下次同個 skill 的 fresh 使用者（包含未來的自己）仍會踩同樣的洞。
**Why**: PR #45 已落地 `episodes.jsonl` + `/mem-log` + `/mem-distill`，episode 層已包含「該 session 用了哪些 skill / 是否有後續更正」的原始訊號 — 缺的是把這個訊號針對「skill 本身」做 diff 提議的閉環。Hermes Agent README 把這條稱作 "skills self-improve during use"，是 self-improvement loop 中 pm-dispatch 最明顯的缺口。預期 ROI 最高，因為 PR-gate / Codex routing 是高頻使用的 skill，每一條 feedback rule 沉澱回 skill 都能直接降低未來 fix-loop 輪數（對應 [[feedback_shared_schema_briefs]] 的根本痛點）。
**M1**: PR #TBD lands a read-only `scripts/skill-refine.sh` spike that scans curated `feedback_*.md` memory entries for a target skill and emits a markdown signal bundle. No diff generation or LLM call.
**M2 deferred**: slash-command shell (`commands/skill-refine.md`) and Claude-generated refinement diff remain follow-up scope.
**Requirement**:
1. `commands/skill-refine.md` slash command，介面：`/skill-refine <skill-name> [--dry-run]`。
2. 讀 `episodes.jsonl` 近 N 個 entry 中 metadata 顯示有觸發該 skill 的 session；提取後續 turns 的 user-correction 訊號（user 在 skill 跑完後立刻給出 "no"/"actually"/"don't"/「不對」/「應該」等更正詞、或重發類似 prompt）。
3. 對 `commands/<skill-name>.md` 提 diff，預設 `--dry-run` 印出 patch 等待 user 確認；非 dry-run 也僅輸出 diff 不直寫，由 user/main thread 套用（避免 skill 自改 skill 的回授風險）。
4. 觀察期：先當 `/mem-distill` 的兄弟工具，不進 cron / 自動觸發，避免污染。
**Note**: 依賴 **CC-027**（PreToolUse tool-trace 基礎建設）— 原本標為 spike brief 內待釐清的訊號層，現移為獨立前置項目。
**Source**: 2026-05-15 對話討論 Hermes Agent self-improvement loop 與 pm-dispatch 的 gap 分析。

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

## CC-027 — PreToolUse `hook-tool-trace.sh` tool/skill 觸發訊號層

**Problem**: 現有 `hook-session-summary.sh`（Stop）只記 session-level metadata，`hook-inject-memory.sh`（UserPromptSubmit）只 inject 不寫；中間「哪些 tool / skill 在這個 session 裡跑過、執行序列為何」沒有任何結構化記錄。CC-025 `/skill-refine` 要找「某 skill 跑完後 user 立刻更正」的訊號、CC-026 `/skill-distill` 要找「重複工作流」的序列 — 兩者都讀空。
**Why**: 不先補這層，CC-025/CC-026 即使寫了也只能讀空資料。設計上是 PR #45 episode layer 的更細顆粒度版本 — 不重做摘要而是新增 `tool-trace.jsonl` 獨立檔，避免污染既有 episodes.jsonl schema。關鍵約束：純 metadata、零 LLM 呼叫，不能讓 PreToolUse 變慢。
**Requirement**:
1. `scripts/hook-tool-trace.sh` PreToolUse hook（matcher 全部），從 stdin JSON envelope 僅解析必要 metadata（tool name、首參數的 skill 名 / path snippet）並 append `{ts, session_id, tool, first_arg_or_skill}` 到 `~/.claude/projects/<proj>/memory/tool-trace.jsonl`；**不持久化完整 payload、不對 stdin 內容跑 LLM、不阻擋 tool call**。實作需依 [[feedback_undocumented_harness_payload]] hedge 多 JSON 路徑取 tool / params 欄位。
2. `/mem-log` 與 `hook-session-summary.sh` 寫 episode 時可選讀同 session 的 tool-trace，產出工具序列 summary 一併塞進 episode metadata（仍純 metadata，不調 LLM）。
3. tool-trace.jsonl 採獨立檔以便日後輪轉/壓縮；最近 N session 保留，超過 archive 或刪除。
4. `install-hooks.sh` wire PreToolUse；`scripts/test-hooks.sh` 加對應 case 驗證 append 結構、效能不退化、不阻擋。
**Note**: blocks **CC-025**, **CC-026**。在這條落地前，CC-025/026 不應啟動。
**Source**: 2026-05-15 對話 — pm-dispatch 改善分析（A2）。
**Outcome**: 2026-05-15 — Added metadata-only PreToolUse `hook-tool-trace.sh`, install wiring, and hook regression coverage; PR #54.
**See**: pr:#54

## CC-028 — PostToolUse `hook-routing-log.sh` 自動 append routing_log

**Problem**: Memory 的 `routing_log` 設計為「Brief/Dispatch routing 決策的 append-only log，作為 Q1/Q2/Q3 規則校準資料」 — 但實際上**沒有自動寫入機制**，靠人手動追加；事實上沒人追加，calibration 永遠不會累積。
**Why**: `feedback_codex_routing` 的 Q1/Q2/Q3 規則目前只靠主動意識，沒有量化校準。Routing 決策本來就是 `codex-dispatch.sh` 呼叫的 by-product，可由 hook 在 dispatch 後自動落地。與 CC-027 同類設計（純 metadata logger），但訊號內容不同。
**Requirement**:
1. `scripts/hook-routing-log.sh` PostToolUse hook，觸發條件：(a) `Bash` tool 且 command 含 `codex-dispatch.sh`，或 (b) `Agent` tool dispatch 至 codex-executor 子代理。實作須 hedge 多 JSON 路徑取 envelope 欄位（候選含 `agent_type` / `subagent_type` / `subagent.type` 等，具體欄位以執行期觀察為準，對應 [[feedback_undocumented_harness_payload]]）— spike brief 第一步須先樣本驗證實際 envelope shape。
2. 從 brief 檔（`.codex-briefs/<id>.md` 或 dispatch first non-flag arg）讀 `goal:` / `files:`，append `{ts, brief_id, goal_excerpt, file_count, q_hit?}` 到 `routing_log.md`。
3. `q_hit` 為選填，MVP 可只記 raw metadata，由 `/mem-distill` 或新增的 `/routing-distill` 後製判斷 Q1/Q2/Q3 hit。
4. `scripts/test-hooks.sh` 加對應 case：dispatch 觸發、非 dispatch Bash 不觸發、append 結構正確、append 失敗不能阻擋 dispatch 結果。
**Source**: 2026-05-15 對話 — pm-dispatch 改善分析（A1）。對應 [[routing_log]] 與 [[feedback_codex_routing]] 設計目標。
**Outcome**: 2026-05-15 — Added PostToolUse `hook-routing-log.sh` + one-time migrator `migrate-routing-log.sh` (3 existing bullet entries → JSONL); install wiring, 19 routing hook/installer regression cases, 5 migrator cases; 298/298 + 5/5 green. MVP fields: brief_file + goal_excerpt only; brief_id / file_count deferred to `/routing-distill`-side computation. Per-hook q_hit/second_thoughts left null — post-classification deferred to a later `/routing-distill`. PR #55.
**See**: pr:#55

## CC-029 — `test-codex-dispatch.sh` 加入 CI

**Problem**: `.github/workflows/lint.yml` 跑 6 個 jobs 但**不包含 `test-codex-dispatch.sh`**（13 snapshot tests）。`codex-dispatch.sh` 是高頻 + 安全敏感（sandbox / approval flags / write-guard 互動），沒有 CI 保護等同信任「dispatch 邏輯不會被誤改」 — 與 [[feedback_codex_dispatch_foreground]] 記錄的曾發生 orphaned-job 事故風險不相稱。
**Why**: 先前以「snapshot 環境敏感」為由排除，但 snapshot 本來就是 fixture，能在 CI clean env 跑。與 CC-024（test-usage-weekly 缺 CI）同類問題、同類修正 — 兩者可一起作為單一 PR 補完 `lint.yml`，共用 PR 成本。
**Requirement**:
1. `.github/workflows/lint.yml` 加 `test-codex-dispatch` job，runner steps 同既有 test jobs 模式。
2. 確認 snapshot fixtures 不依賴本機 `$HOME` 絕對路徑、不依賴外部 secret；若有則先補 fixture isolation 再進 CI。
3. 與 CC-024 同 PR 處理。
**Source**: 2026-05-15 對話 — pm-dispatch 改善分析（A3）。
**Outcome**: 2026-05-15 — PR #57 合併；`lint.yml` 加入 `test-codex-dispatch` 與 `test-usage-weekly` 兩個 job，fixture-driven 無外部依賴。後續 PR #58 (CC-036) 再追加 `test-dispatch-handover` job。
**See**: pr:#57

## CC-030 — `pm/scripts/validate.sh` Index↔Section 雙向一致性 + CHANGELOG drift

**Problem**: `pm/scripts/validate.sh` 只驗 Index 表格欄位格式，無法捕捉：(a) Index row 缺對應 `## CC-XXX —` detail section、(b) detail section 缺對應 Index row、(c) `[Unreleased]` CHANGELOG 條目與 BACKLOG 狀態歧義（active 但 [Unreleased] 引用 / closed 但仍出現於 active 表）。實際發生過：CC-024 retroactively 加入 Index、CC-003/004/005 status 與 [Unreleased] 對應不明。
**Why**: [[feedback_known_bug_backlog]] 規則目前靠自律維持；schema 工具能把它升級為結構性保證，同精神於 PR #46 `/pre-impl` — 用工具強制流程，不靠 reviewer 抓。
**Requirement**:
1. `pm/scripts/validate.sh` 加雙向一致性：(a) 每筆 Index row 必須有同 ID 的 detail section、(b) 反之亦然、(c) closure marker 一致性 — 若 Index 標 `✅ closed YYYY-MM-DD`，對應 detail section 必須有 `✅ YYYY-MM-DD` 或 `**Outcome**:` 區段對齊日期。**title 與 status 文字不做嚴格字串相等比對**（detail section 目前 schema 不含 status 欄位；若未來要求 status 兩處相等需先做 schema migration 在 detail section 增列 status，並一次回填全部既有 entry）。
2. CHANGELOG drift 檢查（可選 / 第二階段）：`[Unreleased]` 引用的 `pr:#NN` 對應 backlog row 必須是 `✅ closed` 狀態。
3. 對應 `pm/scripts/test/fixtures/` 加 `bad-orphan-index/`、`bad-orphan-section/`、`bad-changelog-drift/` fixture；既有 `good/` fixture 通過。
4. `.github/workflows/lint.yml` 既有 schema test 自動涵蓋，不需新 job。
**Source**: 2026-05-15 對話 — pm-dispatch 改善分析（B2）。對應 [[feedback_known_bug_backlog]] 由 feedback rule 升級為結構性保證。

## CC-031 — 開源前置：CONTRIBUTING.md + SECURITY.md + README 工作語言聲明

**Problem**: repo 目前缺 `CONTRIBUTING.md`（PR/branching/test 要求）、`SECURITY.md`（vuln 揭露管道）；README 也未說明工作語言為中文 + 英文 commit。轉公開後，外部讀者沒有明確進入點，會在 issue tracker 提不適合的需求或誤解語言預期。
**Why**: 公開的「使用面」前置條件之一；無 CoC 可接受，但 CONTRIBUTING + SECURITY 是 GitHub OSS 慣例 + 法律保護（responsible disclosure 路徑）。和 [[breaking-change for maintainability]] 一致：與其公開後逐個應付外部需求，不如事先寫清楚預期。
**Requirement**:
1. `CONTRIBUTING.md`：PR 流程（必跑 `/pr-gate` + `pm/scripts/validate.sh`）、branch 命名、commit message 風格、test 強制要求、為何不接受 `--no-verify`。
2. `SECURITY.md`：vuln 揭露 email 與不揭露時段；hook bypass / sandbox escape 算 in-scope。
3. README 加 `Working language` 區段：「Primary working language is Mandarin Chinese; commit messages and code identifiers are English. Foreign-language contributors are welcome but should expect bilingual issue threads.」
4. CoC 不放（個人 repo 風險低、避免 boilerplate）。
**Source**: 2026-05-15 對話 — 公開前置盤點 #1。Blocks **CC-033**（public flip）。

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

## CC-034 — `install-hooks.sh` 改名/移動 checkout 後 append-not-replace bug

**Problem**: `scripts/install-hooks.sh:101-106` 的 idempotency 檢查使用完整路徑字串相等比對：`select(.command == $pm)`。同路徑首次或重跑時可正確 skip；但**改名 / 移動 checkout 路徑後重跑時**，新路徑與舊路徑字串不等 → 舊 entry 不被識別 → 新 entry append 進去，留下舊 entry 變成 ghost。每個 hook 會 fire 兩次（舊指向已失效路徑、新指向有效路徑），且舊 entry 必須手動清。
**Why**: 2026-05-15 PR #51 改名 claude-config → pm-dispatch 時親身踩到 — 需要先 manual `rm` 22 個 stale symlinks + 手寫覆蓋 settings.json 才完成 cutover。對應 [[feedback_known_bug_backlog]]：observed 就要登錄。非一般使用 path：日常 install/uninstall 不會觸發，但任何「同一 hook 但路徑變了」的情境都會（多機 sync 路徑不同、fork 後改名、目錄重組）。
**Requirement**:
1. 把 idempotency 比對改為以 hook script **basename** 識別（例：`(.command | split("/") | last) == "hook-pm-write-guard.sh"`），不是 full path。
2. 在 add 前先 prune：移除所有 basename 相同但 path 不同的舊 entry，再 append 當前 path 的新 entry → 真正 idempotent 跨路徑。
3. `scripts/test-hooks.sh` 加 fixture：先以路徑 A install、改路徑為 B 後再 install，預期 settings.json 只剩 B 的 entry、A 的被清掉。
4. `uninstall-hooks.sh` 同步改為 basename match，避免 uninstall 也踩同 bug。
5. 注意 statusLine 處理：目前 chain logic 已用 `_statusline_already_wired` 條件存在判斷，basename 改造需確認 chain 不被誤刪。
**Note**: 此 bug 不阻擋一般使用；列為 ops 維護債。
**Source**: 2026-05-15 對話 — PR #51 改名 cutover 時 observed。
**Outcome**: 2026-05-15 — `install-hooks.sh` + `uninstall-hooks.sh` 改 basename match；test-hooks.sh 加跨路徑 fixture；statusLine chain 安全保留。PR #53.
**See**: pr:#53

## CC-036 — `/pm` dispatch async ergonomics restore ✅ 2026-05-18

**Problem**: 從 2026-05-09 PR #33（landed `[[feedback_codex_dispatch_foreground]]`）之後，`/pm` 工作流預設把所有 codex 派發都導去 `Agent(subagent_type:"codex-executor")`。subagent foreground-only rule 是正確的（防 orphan），但同時也讓 main thread 在 dispatch 期間完全停擺（觀察過 10.8 分鐘 idle window）。修法前的舊體驗——main-thread 直接 `Bash(codex-dispatch.sh, run_in_background:true)` 派、利用 harness PID-tracking + 完成通知並行做別的事——還在能用，但目前的命令路由完全不走那條，等於把「能 async 的場景」也強制 sync。
**Why**: foreground rule 是 **subagent 限制**（subagent session 結束時 codex 被 SIGKILL → orphan）。**Main-thread 沒有 session 結束問題**，harness 會等 background 完成發通知。被 misroute 的不是規則本身、是消費路徑。User 2026-05-15 觀察：「之前 orphan 完成之後會自動通知 一樣可以完整把資料回收 但是不知道為什麼最近更新之後 反而會一直等待」——點出此 regression。
**Requirement**:
1. `commands/pm.md` 文檔流程：classify + brief composition 仍由 `Agent(subagent_type:"project-pm")` 在 subagent 內完成（不變）；但**派發階段**改為「PM 回 brief 給 main thread → main thread 用 `Bash(scripts/codex-dispatch.sh --brief-file <path>, run_in_background:true)` 直派」。
2. 完成通知由 harness 自動 fire，main thread 在收到通知前可繼續做別的事（讀檔、回 user、開新 dispatch parallel）。
3. `Agent(subagent_type:"codex-executor")` 路徑**保留**作為 fallback：(a) 嚴格 brief schema 驗證需求、(b) main-thread context-window 已滿不適合直派、(c) main-thread 流程已被其他 sync 工作佔住。文檔需明寫此三條 fallback 條件。
4. 自我校準：派出後若超過 `--timeout`（預設 1200s）仍無 completion notification、main thread 應主動 ps grep + filesystem check 判斷是否 true orphan（呼應 `[[feedback_codex_dispatch_foreground]]` 更新的 verification-first diagnostic）。
5. 觀察 1–2 週後，根據 `routing_log.md` auto-block 資料統計 main-thread direct vs subagent 派發比例與成功率，再決定是否進一步把 codex-executor agent 改成「brief-validator only, no dispatch」（會是 CC-036b 後續票）。
**Source**: 2026-05-15 對話 — CC-028 落地後 user 反映派 codex 主執行緒被卡住、回想舊 async + notify 體驗較佳。對應 [[feedback_codex_dispatch_foreground]] 與 [[feedback_skill_background_main_thread]]。
**Note**: 設計變動（不是 mechanical patch），實作前須跑 `/pre-impl` 把「commands/pm.md 既有結構 + brief→main-thread handover 介面 + fallback 條件」釐清；不適合直接走 codex execution。
**Cross-link**: **CC-037 必須在 CC-036 同 PR 或之前 merge**。CC-036 把 dispatch 改成 main-thread `run_in_background` 後，並行 dispatch 機率上升，CC-037 的 concurrent-append race 才會真正觸發 silent row loss。在序列 foreground dispatch 的當前狀態下 race 無法發生，所以 CC-037 defer 是安全的；CC-036 落地當下若 CC-037 仍 open，必須先補 flock 再開 async dispatch。

**Outcome（2026-05-18 驗證）**: 功能已在先前某 PR 實作並落地——`commands/pm.md` 已以 Route A（main-thread Bash `run_in_background:true`）為 primary route；`Agent(codex-executor)` 已降為 fallback allowlist；`docs/dispatch-brief.md §Fallback` 已明列 4 條 fallback 條件。本票不需新 PR，直接 verified-in-place close。⚠️ CC-037（hook race）隨著 CC-036 上線，race surface 已從理論轉為實際，應盡快排入。

## CC-037 — `hook-routing-log.sh` concurrent append race

**Problem**: risk-reviewer's 2026-05-15 PR #55 finding at `scripts/hook-routing-log.sh:204`: the append path rewrites the whole file via temp + `mv` without a lock. Concurrent PostToolUse invocations can race, silently losing one routing row. Blast radius is bounded because this is calibration telemetry, but the loss mode is silent.
**Why**: `routing_log.md` is the feedback source for future routing calibration. If parallel dispatches drop rows under normal concurrent hook execution, downstream `/routing-distill` metrics can undercount exactly the high-concurrency cases that need calibration.
**Requirement**:
1. Introduce `flock` on a sibling lockfile around the append path or switch to atomic rotation-aware append.
2. Add a test fixture in `scripts/test-hooks.sh` that fires two concurrent hook invocations and asserts row-count delta == 2 post-merge.
3. Keep the hook's "non-blocking" contract — if locking fails after a short timeout, audit and skip rather than block dispatch.
**Source**: 2026-05-15 PR #55 risk-reviewer finding; tracked per [[feedback_known_bug_backlog]].
**Cross-link**: **gating dependency of CC-036**. Under current serial foreground dispatch (one codex at a time), the race surface is closed — concurrent PostToolUse events do not happen in practice, so this finding is theoretical. CC-036 opens async parallel dispatch from main thread, which makes concurrent PostToolUse events routine; CC-037 must close before CC-036 ships or land in the same PR. Until CC-036 is picked up, no production impact.
**Override-record**: User explicitly accepted bounded, silent loss of routing calibration telemetry for PR #55 merge on 2026-05-15, per gate result `.gate-results/gate-20260515-174253.md` "Override path" clause. Both `/pr-gate` reviewers (qa-tester + risk-reviewer) downgraded to block-soft after PR #55 fix round; CC-037 remains tracked here as follow-up.

## CC-038 — Windows / cross-platform locking primitive（deferred）

**Problem**: CC-037 用 `flock -x -w 2` 序列化 `hook-routing-log.sh` 的 append/rotation 路徑。`flock` 是 Linux util-linux 工具，Windows（純 PowerShell / Git Bash 無 util-linux）與 macOS（預設不裝 util-linux，需 `brew install flock`）都不能直接使用。除了 hook-routing-log，整個 `scripts/` 樹大量依賴 Linux-isms（GNU awk、GNU sed、`printf -v`、`procfs`、`/dev/null` 重導向細節等），整體 portability 是一塊待面對的工作面，不只這一支腳本。
**Why**: 使用者後續可能需要在 Windows 系統開發 / 跑 pm-dispatch（WSL 不算 native Windows）。在那之前，所有 Linux-only 依賴都是 latent block。CC-037 引入 `flock` 沒有惡化現況（其他 hook 已依賴大量 Linux-only 工具），但每多一個依賴點，將來 portability work 範圍就多一塊。現在不修不影響任何 Linux user，所以這是 latent / blocked-on-windows-demand 條目，不是 active bug。
**Requirement**: 任一方向皆可：(1) 抽象層 `scripts/lib/lock.sh`，依平台選 `flock` (Linux) / `shlock` (macOS 內建) / PowerShell `Mutex` 或 atomic file create loop (Windows)，hook 透過 wrapper 取得鎖；(2) Portable 替代：用 `mkdir`-based atomic locking 取代 flock，所有平台 portable，但需顯式 stale-lock cleanup；(3) 限制範圍：明確聲明 pm-dispatch 僅支援 POSIX（Linux + macOS via Homebrew util-linux），Windows 走 WSL2，寫進 `README.md` + `docs/platform-support.md`。
**Cross-link**: triggered by CC-037 implementation choice (flock). 不阻塞當前 release。所有 hook scripts (`hook-routing-log.sh`, `hook-tool-trace.sh`, `hook-codex-bash-guard.sh`, `hook-pm-write-guard.sh` 等) 共用同一個 portability 平面，啟動時應一次性盤點所有 Linux-isms。
**Source**: 2026-05-15 user 在 CC-037 收尾階段點出「之後可能需要支援 Windows」。

## CC-036b — dispatch handover authorized-override reconciliation

**Problem**: `scripts/lib/handover-validate.sh` hard-rejects `skip_git_check: true`, `sandbox: danger-full-access`, and any `approval` value other than `never`. But `docs/codex-brief.md` and `commands/pm.md` describe these as caller-authorized overrides — implying an escape hatch exists. Today there is NO escape hatch: the validator's `handover_validate_all_metadata` returns 1 with no authorized-override branch, so PM cannot emit those metadata values even with explicit user authorization. Spec ↔ behavior mismatch.

Additionally, `commands/pm.md:13` shows the illustrative dispatch command WITH `--skip-git-check`, while line 16 says to omit the flag when `skip_git_check: false` (the default). A maintainer copying the template literally would bypass the git check.

**Why**: surfaced as critic medium + low in CC-036 final gate (2026-05-16, `.gate-results/gate-20260516-010223.md`). Both are advisory, non-blocking, but they document a real inconsistency that will bite the first time someone needs `skip_git_check: true` for a non-git workdir or `danger-full-access` for an install-to-`~/.claude/` brief.

**Requirement**: pick one path:
1. **Add authorized-override channel**: extend handover metadata with `override_authorized_by: <user|caller>` (or similar) field; validator accepts dangerous values only when paired with the authorization field; add per-field tests for authorized + unauthorized branches.
2. **Remove from docs**: declare flatly that the bash route does NOT support these overrides; if the caller needs them, fall back to `Agent(codex-executor)` with `--sandbox danger-full-access` etc. passed as flags through the executor's existing override mechanism. Tighten `docs/codex-brief.md` + `commands/pm.md` wording.

Plus: revise `commands/pm.md` example to be default-safe (omit `--skip-git-check`) and document conditional flag insertion separately.

**Source**: 2026-05-16 CC-036 final gate critic advise findings.

**Closed 2026-05-16**: Plan-2 alignment applied; bash route docs/messages now direct dangerous-flag needs to Agent(codex-executor) fallback. PR pending.

## CC-040 — agent-agnostic dispatch schema rename ✅ 2026-05-16

**Problem**: CC-036 ships the new dispatch flow with **codex-specific naming throughout**：
- `docs/codex-brief.md` (schema doc)
- `codex_dispatch_handover_v1` (handover block tag, PM→main-thread)
- 多處 cross-reference 寫死 "codex"

But the brief SCHEMA itself（`working_dir` / `goal` / `files` / `constraints` / `self_verify` / `acceptance`）是通用的——任何 coding executor（aider、openhands、未來的 in-house tools）都能消費同樣形狀。把命名綁死在 codex 上，未來新增 executor 就要做大範圍 rename + 跨檔 sync，成本被推遲到那時。

**Why**: 2026-05-15 user 在 CC-036 設計階段點出「brief.md 好像不需要特別寫給 codex 這樣之後其他的 agent 都可以順利套用 而不是被固定給 Codex」。當下 CC-036 流程已 in-flight、scope 已凍結，所以決議「先不全改、寫進 backlog」— 保留命名一致性、避免 CC-036 PR 範圍爆炸。但通用化是正確方向，留著當下次自然 trigger 時的改造機會。

**Trigger conditions**（什麼時候真的該動）：
1. 新增第二個 executor（例如 aider/openhands/in-house worker）— 強 trigger
2. 對外開源前 polishing — `codex-brief` 在外部觀感上把 pm-dispatch 跟單一商業工具綁死
3. 任何時候有人想 retire codex CLI 換成別的工具 — 強 trigger

**Requirement**: 三組工作：
1. **檔案重命名 + handover tag 重命名**：
   - `git mv docs/codex-brief.md docs/dispatch-brief.md`
   - 所有引用 `docs/codex-brief.md` 的檔案改路徑（grep -rl）
   - `codex_dispatch_handover_v1` → `dispatch_handover_v1`（doc + agent + 任何 hook 內的 string match）
2. **Handover schema 加 `executor:` 欄位**：
   - 預設值 `codex`；新欄位寫入 `agents/project-pm.md` instruction、`commands/pm.md` doc、`docs/dispatch-brief.md` schema
   - 對應 mapping：`executor: codex` → `scripts/codex-dispatch.sh` (bash route) / `agents/codex-executor.md` (agent route)
   - 顯式聲明「目前僅支援 codex；其他 executor 需新增對應 dispatch script + agent」
3. **保留 codex-specific 命名的範圍**：
   - `scripts/codex-dispatch.sh` 不重命名（**這支腳本就是包 codex CLI**）
   - `agents/codex-executor.md` 不重命名（這個 agent 知道 codex 124 retry / .last 0.128 quirk）
   - `feedback_codex_dispatch_lifecycle_leak` memory 保留（leak **就是** codex-specific bug）

**Migration safety**: 因 handover tag rename 涉及 PM agent 的 prompt template，**現役 session 在 transition 期間可能看到舊 PM 回新 tag 或新 PM 回舊 tag**。建議在同一 PR 中：
- 同步改 PM agent + 改 main-thread parser（commands/pm.md）
- 避免老 episodes.jsonl replay — hard cutover
- 加 `handover_version: 2`（可選）標示 schema 變動，main-thread parser 可同時識別 v1 與 v2

**Cross-link**: triggered by CC-036 design discussion 2026-05-15。CC-036 本身用 codex-specific 命名 ship，由本條目記錄通用化欠款。**不阻塞當前 release**。
**Outcome**: 2026-05-16 — Atomic breaking-change rename via PR #66: fence tag → `dispatch_handover_v1`, doc → `docs/dispatch-brief.md`, `handover_version: 2` (v1 rejected), required `executor:` enum {codex}. No dual-recognition. 5 new boundary tests; PR-gate r1 GO (critic advise / qa approve / arch approve).
**See**: pr:#66

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

## CC-039 — shared-schema brief enrichment + `/pre-impl` Q4 repo-rule audit + fix-brief next-layer sweep

**Problem**: japanese-site JS-110（furigana.title_ja `Pair[]` → `Token[]` shared-schema spike）即使在 `/pre-impl` + 既有 `[[shared_schema_briefs]]` 規則加持下，仍跑了 6 輪 PR gate 才達到 GO 狀態。每輪 emerging finding 中相當比例可追溯到三個系統性 brief-authoring 缺口：

1. **Brief 漏項（5/6 輪可預先寫入）**：
   - 既有防禦性 pattern 沒對齊（renderer 對舊 `FuriganaPair[]` 有 `isRenderableFuriganaPair` filter，新 Token[] brief 沒要求等價 filter → Round 1 critic high）。
   - 治理/契約層 surface 未列入 brief（`/api/version` API-002 規則沒考慮 → Round 6 critic high；ADR 既有文件 supersession 沒列 → Round 1 critic medium；舊文件早段範例對齊 → Round 2 critic low）。
   - 共用型跨 domain 影響漏盤（pre-impl Q2 surface map 已標 `apiTypes` 共用，但 brief scope 漏列 vocab-side lint → Round 3 architecture high）。
   - **Brief 內部一致性**：brief 自身 constraint 描述（strip-then-round-trip）與 brief 自身 ADR example 描述（full-string round-trip）打架 → Round 4 critic + architecture cross-overlap block-soft。

2. **`/pre-impl` skill Q1/Q2/Q3 未掃 repo-wide invariant**：
   - 沒讀 `rules/global/*.md`（API-002 / UI-003 / 等 NNN-rules）。
   - 沒列出本 brief 觸發的所有 NNN-rule 對應檢查。
   - 沒檢查文件治理慣例（哪些 ADR 描述舊 shape、是否需要 supersession + DECISIONS.md）。

3. **每輪 fix brief 只 address 前輪 finding、無 proactive 下一層 sweep**：reviewer 注意力資源有限呈「洋蔥剝皮」狀（先看 immediate diff bug → 修完才看下一層 contract → 再下一層 governance）。fix brief 若同時主動掃「這次修動是否觸發更深層議題」，可壓縮收斂輪數。

**Why**: 量化：6 輪 gate ≈ 25 min × 6 = 2.5 hr review。若初始 brief 多投入 30 min 跑下面 checklist + `/pre-impl` 多 1 個 Q4，估算可省 4–5 輪 = 75–100 min（ROI 3–4x）。已有 `[[shared_schema_briefs]]` 主規則但只強制 "全表面 audit"，缺**具體可勾選 checklist** 與**governance dimension**。

**Requirement**:
1. 新增 `rules/global/shared-schema-checklist.md`（或 append `[[shared_schema_briefs]]` body），列出強制 checklist：
   - □ `/api/version` 影響：wire shape 變了嗎？bump milestone？(API-002)
   - □ ADR 治理：哪份 ADR 文件記載舊 shape？brief 是否列入 supersede + DECISIONS.md / 新 ADR？
   - □ 防禦性 runtime parity：舊 shape 有 `isRenderable*` filter / validator 嗎？新 shape 等價物在 brief 嗎？
   - □ 共用型 audit：`apiTypes`/schema 中的 type 是否被多個 domain 引用？(grammar/vocab/quiz/classifier)，每個 domain 的 lint + tests 都列入 brief 嗎？
   - □ Brief 內部一致性：constraint vs ADR example 描述同一規則嗎？regex 是否 byte-identical？
   - □ Test fixture 全 sweep：跨檔 grep 舊 shape fixture（renderer / annotations-invariant / staticApi 等），全進 brief 還是漏？
   - □ CLI flag 加新 mode：負面測試（invalid value → exit code）在 brief 嗎？
2. 擴充 `commands/pre-impl.md` 加入 **Q4：Repo-wide invariant audit**：
   - 讀 `rules/global/*.md` + `rules/domain/<domain>.md`
   - 列出與本 brief 相關的 NNN-rules（API-002 / UI-003 等）
   - 明確將每條 rule 對應的檢查放進 brief constraints
3. 在 `docs/dispatch-brief.md` 或 `agents/project-pm.md` 加入 **fix-brief 撰寫指引**：
   - 不只 address 上輪 finding，主動跑 1 個 follow-up 思考：「這次修動是否觸發更深層議題？」
   - 範例 trigger：修 ADR supersede → 同步掃 ADR 全文舊範例；升級 lint → 掃 spec/code 對齊；改 wire shape → 掃 API version、cache、external-client 影響。

**Source**: 2026-05-15 japanese-site JS-110 6-round gate convergence post-mortem。對應 [[shared_schema_briefs]] 既有規則的補強（不是取代）。
**Note**: 實作前可選 `/pre-impl`，但本 ticket 本身是 process 改進（rules + commands + docs），無 schema 變動，可直接寫 brief。
**Cross-link**: [[shared_schema_briefs]] 主規則 + CC-022 `/pre-impl` 既有 skill。

---

**2026-05-18 追加案例：CC-013（7 輪 gate）**

CC-013（`/caveman` + agent brevity）出現了與 JS-110 不同觸發條件但相同收斂模式的「洋蔥剝皮」現象。差異點：

- JS-110 的根因是「shared-schema 跨 domain 影響面未事先盤點」
- CC-013 的根因是「**新功能 + 對應 contract test script 在同一 PR 新增，但沒有事先列出 behavioral contract 清單**」

CC-013 的七輪逐步修補路徑（每輪 1–2 個缺口）：

| 輪次 | 阻擋原因 |
|------|---------|
| R1 | 命令行為設計問題（no-state-tracking 措辭、breaking-change 格式）+ 完全沒有測試 |
| R2 | `--filter` 無參數無限迴圈、零匹配靜默通過、CI 未接線 |
| R3 | `assert_frontmatter` 漏檢 closing `---`、brevity 未限定在 section 內、未知 flag 靜默忽略 |
| R4 | 7 種 commit type 只測 3 個；`Caveman mode: <MODE>` 確認輸出未測 |
| R5 | `$ARGUMENTS` hint 行為未覆蓋；使用說明與實際輸出不符 |
| R6 | agent brevity 的 `no closing summary` 規則未測 |
| R7 | **GO** |

**CC-039 Requirement 補充項（已確認的新子模式）**：

在 Requirement 清單追加：
- □ **同 PR 新增 contract test script 時**，先逐條列出被測命令的所有 behavioral contract（空參、無效參數、每條輸出格式、每個 type/flag、每個 section 中的規則），再寫 assertion——不能邊寫邊補。適用於 `test-commands.sh`、`test-hooks.sh` 等 contract test 類腳本。

## CC-045 — brief timeout heuristic + playbook-depth short-circuit（deferred）

**Problem**: Brief author 目前對 `timeout` 沒有明確啟發法 — 多半以 edit size 為單一估算依據。但 Codex 預設行為是先吃完整個 target repo 的 onboarding chain（AGENTS.md / rules/global / rules/domain / 跨 repo playbook docs）再動工。對 playbook 深的 repo 即使只改 ~10 行也會在 prelude 階段燒掉 200s+，超薄 timeout 直接 SIGKILL 在 research 階段。
**Why**: 2026-05-16 japanese-site `chore/js-100-split-js-113` 修 yml/md parity（~10 yml + 4 md 行 mechanical sync）走 codex-dispatch.sh `--timeout 240`，exit 124；trace 顯示 11 個 `command_execution` 全是 doc read（`prompt-budget.yml`、`../agent-playbook-template/docs/{rules-quickstart,operating-rules,agent-playbook}.md`、`DECISIONS.md`、`project/project-manifest.md`、`rules/global/{security-baseline,prompt-injection}.md`、`rules/domain/*.md`），未進編輯階段。**根因**：brief author 把「edit 14 行 ≈ 240s」推估時未把 playbook depth 算進去。
**Requirement**:
1. `docs/dispatch-brief.md` brief schema 文件加 `timeout` 啟發法 guidance：
   - flat repo（無 `rules/`、無 `AGENTS.md`、無 cross-repo playbook 連結）：mechanical edit 240–600s OK
   - shallow playbook（單一 `AGENTS.md` 或 `<10` 條 rules）：mechanical edit 600–900s
   - deep playbook（`rules/global` + `rules/domain` 或跨 repo playbook refs，例：japanese-site）：mechanical edit **最低 900s**；judgment-heavy（editorial / schema）1500s+
2. brief context 加可選短路 clause 模板：`"Constraints captured in this brief; do NOT re-read AGENTS.md / rules/ / playbook docs"` — 對 self-contained brief + mechanical edit 直接砍 5–10 個 read 命令。需在 `docs/dispatch-brief.md` 給範例。
3. （可選 / 第二階段）`scripts/codex-dispatch.sh` 啟動時偵測 `<working_dir>/rules/` 或 `<working_dir>/AGENTS.md` 存在且 `--timeout < 900` 時 emit stderr WARNING（不阻擋），surface author 設置錯誤於 SIGKILL 之前。
4. 觀察 N≥2 次 cross-session 重現後，promote 為 `feedback_brief_timeout_playbook_depth` memory（[[known-bug backlog rule]] + [[Codex routing preferences]] 衍生）。
**Source**: 2026-05-16 cross-session diagnostic — japanese-site dispatch exit 124 with 240s timeout，trace `.agent-trace/codex-20260516-193626-47431.jsonl`。
**Note**: 立即 workaround 是 brief author 對 deep playbook repo 預設 timeout=1500s；本條 ticket 是把這條 workaround 升級為文件化規則 + 可選 wrapper-side warning。
**Cross-link**: [[Codex routing preferences]] 路由表 / [[known-bug backlog rule]] 補登原則。

## CC-046 — validate.sh + run-tests.sh dedup（deferred）

**Problem**: CC-030 (PR-gate r6 GO) 落地後留兩個 cross-overlap advisory (critic + architecture-reviewer)：
1. `pm/scripts/validate.sh` 第二個 awk pass（CHANGELOG drift）獨立解析 backlog index 的 status / refs 而非 reuse 第一 pass 結果。當前不影響正確性，但 schema status 或 ref grammar 未來變動時兩 pass 容易 drift。
2. `pm/scripts/test/run-tests.sh` 的 `run_validate_case_multi`（CC-030 fix-r2 引入）與既有 `run_validate_case` assertion body 高度重複（exit-code check / token extraction / stderr handling / cleanup 幾乎全 copy），增加 assertion drift 風險。
**Why**: 兩條都是 maintainability advisory，非 release blocker（critic 標 advise、qa 標 approve、arch 標 advise）。當前 validator 範圍小、重複可控；若 CC-030 後續再加 cross-file 規則或 multi-arg test 形態，重複會變痛點。**Cohesion** 主因。
**Requirement**:
1. `pm/scripts/validate.sh`：抽 backlog index parsing（status + refs grammar）為 shared awk routine 或單一 awk 程式碼 block；CHANGELOG drift pass 改 consume 該 shared state，不重新 parse。
2. `pm/scripts/test/run-tests.sh`：合併 `run_validate_case` 與 `run_validate_case_multi` 為單一 varargs helper（例：`run_validate_case <name> <code> <token> <validate-args>...`），既有 13 個 single-arg case 改為 forward-compatible 形式（preserve existing signature semantics 或一次性 migrate 全部 call sites）。
3. 同時補 QA r5/r6 提到的 structured docstring 注解（behavior/Steps style）— 雖然是低優先，但既然在動 helper 不妨一起。
**Source**: 2026-05-16 gate-20260516-205441 (r5) + gate-20260516-205833 (r6) advisory findings。CC-030 直接 follow-up。
**Note**: 安全 refactor，無 schema 變動；建議 fixture 增加之前先做 dedup，否則新 case 又繞 helper 重複一次。
**Cross-link**: 跟 [[shared_schema_briefs]] 同精神 — 把 schema-grammar 集中在單一處避免 drift。

## CC-025b — `/skill-refine` M1+M2 advisory follow-ups（deferred）

**Problem**: CC-025 M1 (PR #67) 與 M2 (`commands/skill-refine.md`) PR-gate 留三條 advisory，未阻擋 GO 但屬已知缺口需追蹤：
1. (qa-tester / M1) `scripts/skill-refine.sh:11-14` 的 `$# -ne 1` usage guard 無 behavior test — 0-arg 與 multi-arg invocation 沒有 exit-code + stderr shape 的斷言，CLI 行為退化會無察覺通過。
2. (critic + architecture-reviewer / M2) `commands/skill-refine.md:24-29` 與 `scripts/skill-refine.sh:29-36` — slash command spec 沒揭露 `CLAUDE_MEMORY_DIR` 是 mandatory env；外部 shell 沒設此變數直接執行 `/skill-refine <name>` 會 hard-fail，違反「slash command 文件 = user-facing contract」原則。隱藏 runtime coupling。
**Why**: Claude Code 環境通常已 export `CLAUDE_MEMORY_DIR`，所以 PR-gate 與 critic 都標 advise 而非 block；但對 fresh dev shell / CI / 跨機器 dogfood 場景仍是 footgun。`feedback_known_bug_backlog` 要求 deferred advisory 進 backlog；`feedback_validator_dryrun_before_strengthen` 同精神 — 先把 contract 寫清楚再給更多人用。
**Requirement**:
1. `scripts/test-skill-refine.sh`：新增至少兩個 case — `no_args_exits_2_with_usage` + `multi_args_exits_2_with_usage`，斷言 exit code + stderr 含 `Usage:` token。
2. Choose one of：(a) `commands/skill-refine.md` body 加 prerequisite section 明示 `CLAUDE_MEMORY_DIR` 需 export（含 `${HOME}/.claude/projects/.../memory` 範例路徑）；OR (b) `scripts/skill-refine.sh` 在 env 未設時嘗試 default fallback 路徑（依 Claude Code 預設 layout，例如 `${HOME}/.claude/projects/-home-<user>-github/memory`，找不到再 exit 2）。(a) 與 (b) 互斥，建議先 (a) 因 zero code change。
3. （可選）PR-gate brief 加 sanity check：跑 `unset CLAUDE_MEMORY_DIR; bash scripts/skill-refine.sh pr-gate` 期望 exit 2 + 明確 hint，作為 fresh-shell smoke。
**Source**: 2026-05-17 gate-20260517-155611.md（M2 PR-gate r1 GO advisory）。
**Note**: 兩條 advise 共享 root cause（env contract 沒文件化），所以同票處理；fix 後 M2 follow-up close。
**Cross-link**: [[feedback_known_bug_backlog]] / [[feedback_native_perspective]] 衍生「文件化 user contract」原則。

## CC-047 — `scripts/codex-dispatch.sh` model alias mapping

**Problem**: `bash scripts/codex-dispatch.sh --model codex-spark ...` 失敗 — codex CLI 收到 `-m codex-spark` 後丟 `400 invalid_request_error: The 'codex-spark' model is not supported when using Codex with a ChatGPT account`。實際合法 model ID 為 `gpt-5.3-codex-spark`（user `~/.config/codex/config.toml` 預設值），而 PM agent / `/pm` 出的 brief 持續用短名 `codex-spark` 描述 routing 決策。短名與 wire-format ID 不一致導致 dispatch 一律 hard-fail。
**Why**: 兩件事必須對齊：(1) PM 用 short alias（`codex-spark`）描述決策邏輯，符合 `[[feedback_codex_routing]]` Q1/Q2/Q3 表的命名習慣；(2) wire-format API 只認全名 `gpt-5.3-codex-spark` + reasoning effort `high`。當前 dispatch script 第 134 行 `CMD+=(-m "$MODEL")` 純字串透傳，沒有 alias 表。每次 PM 寫 `codex-spark` 都會踩雷。tactical workaround 是 brief author 改用全名或留空（讓 codex config default 接手），但這把對齊責任推給 brief author。
**Requirement**:
1. `scripts/codex-dispatch.sh` 加 alias resolution layer：定義 alias → `<full-model-id>:<reasoning-effort>` 映射表（初版至少 `codex-spark` → `gpt-5.3-codex-spark` + `model_reasoning_effort=high`），未在表中的字串 fallback 為原樣透傳。
2. 同步處理 reasoning effort：用 `-c model_reasoning_effort=...` 透傳（CLI 支援的 config override 形式）或別的等效機制；確認 spark 短名解析後 effort 確實送達 codex。
3. `docs/dispatch-brief.md` / `agents/project-pm.md` 加 alias 對照表，明示 PM 可繼續用短名、wire-format 對齊由 dispatch script 負責。
4. 加 1-2 個 `scripts/test-codex-dispatch.sh` 行為 case：(a) `--model codex-spark` 預期 alias 解析後 `CMD` 含 `gpt-5.3-codex-spark`；(b) `--model gpt-5.3-codex-spark` 預期原樣透傳；(c) `--model unknown-tag` 預期 fallback 原樣（保留現行行為）。
**Source**: 2026-05-17 CC-025 M2 dispatch first attempt — task `b6vuj0gns` exit 1，trace `.agent-trace/codex-20260517-154951-18117.jsonl`，stderr 顯示 `400 invalid_request_error`；第二次重派移除 `--model` 走 codex config default 成功（task `bsvdlt7xr`）。User 在後續 turn 確認 `gpt-5.3-codex-spark high` 是其 codex CLI 慣用設定。
**Note**: 純 dispatch script 內部變更，無需動 PM agent 或 brief schema。實作前可參考 codex 官方 CLI doc 確認 `model_reasoning_effort` config override 對哪些 model family 生效。
**Cross-link**: [[feedback_codex_routing]] Q1/Q2/Q3 表 + [[feedback_bash_route_approval_never]] 同精神 — dispatch script 負責把 PM 短語映射成 wire-format。

---

# CC-OSS Epic — Open-source pm-dispatch（CC-100 to CC-105）

**Epic goal**: 把 pm-dispatch 從個人 audience-of-one 工具開源成 public GitHub repo，讓 Windows-only / 不用 WSL2 / 不用 Codex / 純 Claude Code 使用者能 onboard。

**Audience shift**: 從 [[project_japanese-site_audience]] 的 audience-of-one 模型 → 多人 public 模型。但仍保留現有 user 的 codex-using workflow 不破壞（codex 變 opt-in profile）。

**Sequencing**: Phase 1 → 2 → 3 → 4 → 5，**嚴格串行**。Phase 2 設計變更會碰 brief schema 與 dispatch flow，必須在 Phase 1 sanitize 完成後再動；Phase 3 portability shim 依賴 Phase 2 codex-optional 設計才有意義（不然 Windows user 仍會撞 codex requirement）。

**Cross-link**: [[project_pm-dispatch]] / [[breaking-change for maintainability]]（codex-optional 用 additive `executor:` 欄位 + 預設值切換，不破壞既有 schema）。

## CC-100 — [CC-OSS Phase 1] Sanitize personal paths + OSS-baseline docs

**Problem**: 6+ production files（`commands/pm.md` / `agents/project-pm.md` / `agents/codex-executor.md` / `docs/dispatch-brief.md` / `scripts/codex-dispatch.sh` / `README.md`）含 `/home/<user>/github/pm-dispatch` 硬編碼絕對路徑；外部 contributor 讀 README 與範例會看見「Lien 的個人桌面」而非通用設計。`CONTRIBUTING.md` / `CODE_OF_CONDUCT.md` 缺；LICENSE (MIT) 已存在但未在 README 標示。
**Why**: 開源第一條原則是「repo 看起來不像某人的 dotfiles」。Sanitize 是後續 phase 的前提 — 沒做 phase 2 的範例會把 `/home/<user>` 越寫越多。
**Requirement**:
1. 所有 production files（排除 `scripts/test-*.sh` fixtures 與 `BACKLOG.md` / `CHANGELOG.md`）的 `/home/<user>/github/pm-dispatch` 改為 `${PM_DISPATCH_REPO}` placeholder。
2. `scripts/install-hooks.sh` 新增 `PM_DISPATCH_REPO=${PM_DISPATCH_REPO:-$(git rev-parse --show-toplevel)}` 預設值；未設 env 時用 git toplevel 自動推斷。
3. 新增 `CONTRIBUTING.md`（~100 行：branch flow、PR-gate workflow、brief schema pointer 到 `docs/dispatch-brief.md`、Conventional Commits 約定）。
4. 新增 `CODE_OF_CONDUCT.md`（Contributor Covenant 2.1 verbatim）。
5. `README.md` 補一段 "Personal paths in examples use `${PM_DISPATCH_REPO}`" 說明 + LICENSE badge。
**Self-verify**: `grep -rn "/home/<user>" --include="*.sh" --include="*.md" | grep -v "scripts/test-" | grep -v "BACKLOG.md" | grep -v "CHANGELOG.md"` 必須 0 hit（`<user>` = 維護者 local username）。
**Acceptance**: 上 grep 0 hit；既有 `scripts/test-hooks.sh` + `scripts/test-codex-dispatch.sh` 全綠（無 behavior change）；fresh clone 跑 `bash install.sh --dry-run` 結果與 PR 前一致（除 `PM_DISPATCH_REPO` 自動推斷訊息）。
**Note**: 純 rename + 新 docs，**zero behavior change**。Backwards-compat：`PM_DISPATCH_REPO` 未設時 fallback 至 `git toplevel`，現有 user 無感。
**Cross-link**: [[breaking-change for maintainability]] 此票走 additive env contract，不破壞既有 user。

## CC-101 — [CC-OSS Phase 2 spike] Executor-contract schema + adapter design

**Problem**: 當前 PM agent brief 直接寫 codex-specific 欄位（`sandbox` / `approval` / `model` / `dispatch_route: main_thread_bash_background`）；`commands/pm.md` 整段 dispatch route 都寫死 codex。若要讓不裝 codex 的 user 也能用 PM/brief 流程，schema 必須抽象化執行端。
**Why**: CC-040 已做了部分 schema rename（`dispatch_handover_v1` 通用化、`executor:` 欄位預留）；本 phase 把 spike 延伸成完整 executor adapter contract。
**Requirement**:
1. 新檔 `docs/executor-contract.md`：abstract executor interface（input = brief markdown + metadata；output = file diff + test evidence + report）。
2. brief metadata schema 加 `executor: claude-main | codex` 欄位；schema validator (`scripts/lib/handover-validate.sh`) 識別。
3. 設計（不實作）`claude-main` executor 的執行語意：main thread Claude 讀 brief → 用 Edit/Write/Bash 完成 acceptance steps → 觸發 reviewer pipeline。文件化於 `docs/executor-contract.md`。
4. `agents/project-pm.md` 補 "Executor selection" 段，說明預設依 install profile 決定。
5. Spike output：design doc（不動 code），讓 CC-102 impl 有清楚契約可實作。
**Acceptance**: `docs/executor-contract.md` 含 input/output 契約 + 兩個 executor profile (codex / claude-main) 對照表；`scripts/lib/handover-validate.sh` 接受 `executor:` 欄位且預設 codex（backward-compat）；無 runtime behavior change。
**Note**: 純 spike，不動 dispatch 行為。impl 在 CC-102。
**Cross-link**: [[project_pm-dispatch]] hooks-as-policy / [[feedback_codex_routing]] / CC-040 schema rename。

## CC-102 — [CC-OSS Phase 2 impl] `claude-executor` agent + install profile

**Problem**: CC-101 設計完 contract，CC-102 實作 `claude-main` executor 路徑與 install profile 切換。同事不裝 codex 要能跑完一個簡單 `/pm` task。
**Why**: 完成 codex-optional 架構的「實際可跑」里程碑。
**Requirement**:
1. 新 agent `agents/claude-executor.md`：受 brief → main thread Bash/Edit/Write 完成 acceptance → 跑 reviewer pipeline；不呼叫任何 codex script。
2. `commands/pm.md` 拆兩條路徑：`executor: claude-main`（預設，新 user）走 claude-executor；`executor: codex`（既有 user）走 codex-dispatch.sh。
3. `scripts/install-hooks.sh` 加 `--profile minimal|full` flag：minimal 跳過 `hook-codex-bash-guard.sh` / `hook-codex-write-guard.sh` 註冊；full 維持現狀。
4. `install.sh` 加 `--profile` passthrough；`README.md` 寫明選法。
5. Backwards-compat：未指定 `--profile` 偵測 codex CLI 是否存在 → 有 = full、無 = minimal。
**Self-verify**:
- `scripts/test-hooks.sh` 全綠（既有 codex flow 不破壞）
- 新增 test：`scripts/test-claude-executor.sh` 跑一個 trivial brief（無 codex），exit 0
- `install.sh --profile minimal` 結果不註冊 codex hooks（grep settings.json）
**Acceptance**: fresh user 不裝 codex 能跑完 `/pm "add hello.sh that echoes hello"` task → claude-executor 完成 → reviewer pipeline 跑 → PR-gate 通過；既有 codex flow 全 regression pass。
**Note**: 風險最高的 phase，建議自己（user）親自驗 codex flow 不破；同事驗 minimal flow。
**Cross-link**: CC-101（spike） / [[Subagents cannot spawn subagents]]（claude-executor 設計要注意 main thread vs subagent 邊界）。

## CC-103 — [CC-OSS Phase 3] Portability shim + Windows / Git Bash 支援

**Problem**: 3 個 hook（`hook-pm-write-guard.sh` / `hook-codex-bash-guard.sh` / `hook-codex-write-guard.sh`）依賴 `realpath -m`（Git Bash 預設無）；`hook-routing-log.sh` 依賴 `flock`（Git Bash 無）；`scripts/handover-validate.sh` 假設 `/tmp/brief-*.md` 路徑模式。Windows-only user 即使裝了 Git for Windows + Git Bash + jq 也會撞這些 Linux-only 用法。
**Why**: Phase 3 是「同事真能用」的硬門檻。Phase 2 把 codex 拔掉後，剩下的 Linux-only bash 用法是最後障礙。
**Requirement**:
1. 新 `scripts/lib/portable.sh`：`realpath_m()` / `safe_tmpdir()` / `mkdir_lock()` 三個 shim；偵測 platform 走最佳實作（Linux=原生 / macOS=`realpath` via coreutils / Git Bash=純 bash 實作）。
2. 改寫 3 個 codex/pm hook 用 shim。
3. `hook-routing-log.sh` 的 `flock` 改 `mkdir_lock`（atomic mkdir-based lock，跨平台）。
4. `scripts/install-hooks.sh` 偵測 platform；Windows 上跳過依賴 Linux-only utility 的 hook（或標 warning）。
5. 新檔 `docs/platform-support.md`（~80 行）：Linux/macOS = first-class、WSL2 = same as Linux、Windows Git Bash + minimal profile = supported、其他 = best-effort。
6. 列出 Windows user 需要手動裝的 deps：`winget install jqlang.jq`、Git for Windows extras 含 coreutils、PowerShell 7 optional。
**Self-verify**:
- `scripts/test-hooks.sh` 在 Git Bash on Windows 全綠（或標明哪些跳過 + 為什麼）— 需 Windows dogfood
- `scripts/lib/portable.sh` 個別函式有 unit test（`scripts/test-portable.sh`）
**Acceptance**: fresh Win11 + Git for Windows + jq + Claude Code 能完成「clone → install.sh --profile minimal → invoke /pm "trivial task"」一條 path；`docs/platform-support.md` 含 step-by-step。
**Note**: 你不在 Windows，這 phase 後半段依賴同事 dogfood。建議 phase 結束前讓同事跑一輪並 report friction，再 close。
**Cross-link**: BACKLOG CC-037 `hook-routing-log.sh` flock portability（既有 deferred item，本 phase 順手解掉）/ [[breaking-change for maintainability]]（shim 是 additive，無 schema 變更）。

## CC-104 — [CC-OSS Phase 4] Onboarding docs batch

**Problem**: 同事「用過 Claude Code 但沒碰 hooks/agents/skills」。沒有 onboarding doc 直接讀 `agents/project-pm.md` 會 lost；需要從 hooks-as-policy / subagent / slash command / memory 四概念開始的入門路徑。
**Why**: Phase 1-3 完成後，技術上可跑；但「同事看完不會用」就等於沒開源。docs 是 last-mile UX。
**Requirement**:
1. `README.md` rewrite（200-300 行）：what / why / 5-min quickstart / 連到 GETTING_STARTED 與 CONCEPTS。
2. `docs/GETTING_STARTED.md`（150-200 行）：clone → install → first `/pm` 一條 path；含 troubleshooting。
3. `docs/CONCEPTS.md`（250-350 行）：hooks-as-policy / subagent / slash command / memory tiers 四概念；給沒碰過的讀者。**user 起 30 分鐘 brain-dump 第一版**（design intent 你最懂），Claude 補結構與範例。
4. `docs/memory-system.md`（100 行）：memory dir 在哪、為何 per-project、如何 bootstrap empty、symlink 進 private repo 的 pattern（不曝光私人路徑）。
5. 既有 `commands/*.md` 補強：每個 slash command 補 "What / When to use / Example" 三段（codex 用 `/skill-refine` 走 brief flow，逐一處理）。
**Self-verify**: 同事在不問 user 的前提下，從 README → GETTING_STARTED → 第一個 `/pm` 成功 dispatch trivial brief；用 record-feedback 方式回報哪一段卡住。
**Acceptance**: 上述 5 個 doc 條件 + `commands/*.md` 全部補完三段；fresh reader 走 GETTING_STARTED 能 0-error 跑到 first PR。
**Note**: CONCEPTS.md 是 critical path 且 user 必須親自起草第一版。其他 4 份可派發。**本票第一階段先草 CONCEPTS.md draft（main thread Claude 起草 + user 審）**，其餘 docs 在 Phase 3 完成後再啟動。
**Cross-link**: [[project_japanese-site_japanese-first]] 同精神 — 預設 surface 對主 audience 友善；本 repo 主 audience = 多人 OSS。

## CC-105 — [CC-OSS Phase 5] BACKLOG cleanup + v0.1.0 public release

**Problem**: BACKLOG 含多條 user-specific 項目（CC-011 sync-memory 到雲端、CC-012 SessionStart pull memory、CC-013 caveman skill 等）不適合 public roadmap；`.agent-trace/` / `.codex-briefs/` / `.gate-results/` 是 working-dir artifact 不該進 public history；private→public visibility 切換不可逆。
**Why**: Phase 1-4 完成後做最後 cleanup + 正式 release。一切都要可逆性檢查 + dry-run。
**Requirement**:
1. audit BACKLOG.md：標 `personal/` prefix 或刪除（CC-011 / CC-012 / CC-013 等 user-specific）；保留通用 ops/process 條目。
2. `.gitignore` 補 `.agent-trace/` / `.codex-briefs/` / `.gate-results/` / `*.bak`；確認既有 commit history 無 leak（若有，BFG 或 git-filter-repo 處理）。
3. 新檔 `CHANGELOG.md` v0.1.0 section：列出 CC-OSS phase 1-4 全部 PR + key feature inventory。
4. 在 dry-run 個人 repo `pm-dispatch-public-dryrun` 試跑一遍同事 onboarding flow（clone → install → /pm）；確認 0-friction 再切 main repo。
5. GitHub repo settings：private → public；**切 public 後立刻啟用** main branch protection（require linear history；不啟用 require-PR 因為 source-available 模式 maintainer 直推 main 是合法路徑）。**Sequencing constraint**: GitHub free tier 私人 repo 無 branch protection 功能，必須先切 public 才能啟用此設定（user 已確認 2026-05-17）。
6. tag `v0.1.0` + GitHub release（含 release notes 引用 CHANGELOG）。
**Acceptance**: repo public；同事能 fork、clone、按 GETTING_STARTED 跑完；CHANGELOG v0.1.0 紀錄完整；無歷史 leak。
**Note**: 切 public 是**不可逆**操作（star/fork 後 history 永遠 public）。Step 4 dry-run 是 hard requirement，不能跳。
**Stance**: pm-dispatch 採 **source-available** 模式（policy 已寫入 CONTRIBUTING.md 2026-05-17）— public for visibility，外部 PR 不受理，issue 開放無 SLA。本 ticket 因此**不**包含 GitHub issue/PR templates / CODEOWNERS / require-PR branch protection（這些是 open-contributor 模式才需要）。若未來轉 open-contributor，補開 follow-up ticket。
**Cross-link**: [[gate-architecture-not-data]]（這票多數是 docs/config 改動，gate 找對 reviewer 即可，不要對 BACKLOG 條目重審）。

## CC-103b — /pr-gate executor split (closed 2026-05-17)

**Outcome 2026-05-17**: `/pr-gate` now routes through `executor` selection via
`--executor codex|claude|auto`; minimal-profile users can run the full gate workflow
without `codex` installed.

1. `scripts/pr-gate.sh` added route-aware dispatch for all `codex-dispatch.sh`
   call sites.
2. `--executor auto` resolves by `command -v codex` and remains the default.
3. New `pr-gate-handover_v1` schema documented in `docs/pr-gate-handover-schema.md`.
4. `commands/pr-gate.md` updated with Route A (codex) and Route B (claude) orchestration.
5. Direct e2e regression coverage added in `scripts/test-pr-gate-profile.sh`.

**Problem**: CC-103 made `/pm` portable, but `/pr-gate` still hard-depended on
codex dispatch and had no main-thread fan-out shape for minimal-profile users.

**Why**: This blocks the same portability objective CC-102 delivered for PM: users
with minimal profile still needed codex for gate execution and could not complete PR
review cycles in-place.

**Cross-link**: CC-102 + CC-103 + [[project_pm-dispatch]]

## CC-102b — CC-102 PR-gate advisory follow-ups（closed 2026-05-17）

**Outcome 2026-05-17**: CC-102 PR-gate r2 升 block；advisory 全 fold-in 進 CC-102 同 PR：
- `scripts/install-hooks.sh` jq 段加 minimal profile downgrade pass（match basename + scripts/ parent，remove 既有 codex guard hooks + 清空 matcher block）
- `scripts/test-install.sh` 加 4 case：`install-sh-profile-minimal-skips-codex-hooks` / `install-sh-profile-full-wires-codex-hooks` / `install-hooks-profile-downgrade-removes-codex` / `install-hooks-profile-invalid-value-rejected`
- `CONTRIBUTING.md` test inventory 加 `test-install.sh` / `test-claude-executor.sh` / `lint-scripts.sh` / `lint-agents.sh`

**原始 Problem** (CC-102 PR-gate gate-20260517-202651.md r1 留下；r2 gate-20260517-203505.md qa-tester 升 high block，依 gate-driven design 必須 fix in-PR)：
1. (qa-tester) `install.sh --profile minimal|full` + auto-detect (`command -v codex`) 沒有直接 e2e regression test
2. (architecture-reviewer) `scripts/install-hooks.sh` minimal profile 只 skip 插入 codex guard hooks，不會 remove 已存在的；用 `--profile full` 安裝後再 `--profile minimal` rerun，settings.json 不會 converge 到 minimal contract
**Why**: qa-tester r2 verdict: "add regression tests for --profile minimal/full installer behavior and reversible/downgrade semantics" 是 NO-GO 必修。
**Cross-link**: [[feedback_known_bug_backlog]] — backlog-only deferral 不足以滿足 qa-tester；future code-affecting advisory 應直接 fold-in 同 PR。
