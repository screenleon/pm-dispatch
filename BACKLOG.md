<!-- pm-schema: v1.2 -->
# pm-dispatch backlog

<!--
ID PREFIX: CC
CC-001/CC-002 were consumed by PR #24 fix bundle inline, with no standalone entries; this file starts at CC-003.
-->

## Index

| #  | Status | 主題 | 影響面 | 首次記錄 | Refs | Priority | Epic |
|----|--------|------|--------|----------|------|----------|------|
| CC-004 | 🟢 someday | test-pr-gate.sh docstring 格式統一 | ops | 2026-05-12 | pr:#38 | P3 | — |
| CC-011 | 🟢 someday | sync-memory.sh + install 選項：symlink memory 到雲端資料夾實現跨裝置共用 | ux/memory | 2026-05-14 | — | — | — |
| CC-012 | 🟢 someday | SessionStart hook：session 啟動時 pull 最新 memory（git/rsync）確保跨裝置同步 | ux/memory | 2026-05-14 | — | — | — |
| CC-014 | ⏸ deferred | `using-git-worktrees` skill：parallel PR gate 隔離開發環境 | arch | 2026-05-14 | — | — | — |
| CC-015 | ⏸ deferred | `systematic-debugging` skill：結構化偵錯工作流 | ux | 2026-05-14 | — | — | — |
| CC-018 | 🟢 someday | Codex quota 自動追蹤 + rate-limit 路徑統一（吸收 CC-269）：寫到 `~/.local/share/pm-dispatch/state/rate-limits.json`；解析 API response headers；token-usage.sh 加 Codex pool 顯示 | ux/token | 2026-05-14 | — | P3 | — |
| CC-023 | ⏸ deferred | `coupling-reviewer`：PR gate 加入語言感知耦合分析（dependency-cruiser/gocyclo/coca） | ops/gate | 2026-05-14 | — | — | — |
| CC-026 | 🟢 someday | `/skill-distill`：偵測重複工作流，產出草稿 skill .md | ux/memory | 2026-05-15 | — | P3 | — |
| CC-032 | 🟢 someday | `[[feedback_*]]` cross-link 公開化：抽到 `docs/policies/` glossary 避免 dead link | process/DX | 2026-05-15 | — | P3 | — |
| CC-033 | 🟢 someday | Public flip checklist：Issues/Discussions 設定、CITATION.cff（選配）、後續觀察期 | process | 2026-05-15 | — | P3 | — |
| CC-035 | 🟢 someday | install/uninstall-guards basename+scripts/ heuristic：未覆蓋另一工具也在 scripts/ 下同名 hook 的 collision edge case | ops | 2026-05-15 | pr:#53 | P3 | — |
| CC-038 | ⏸ deferred | Windows/cross-platform 鎖機制：`flock` Linux-only，未來支援需替代方案（parked: CC-370） | ops/portability | 2026-05-15 | — | — | oss |
| CC-044 | ⏸ deferred | `tool-trace.jsonl` 三階段升級（吸收 CC-027b/c）：Phase 1 rotation/retention；Phase 2 bounded error counter；Phase 3 async validation | ux/memory | 2026-05-15 | — | — | — |
| CC-045 | ⏸ deferred | brief timeout heuristic：依 target repo playbook depth 設 timeout（not only edit size）；brief 可加 skip-playbook-reread 短路指令 | process/DX | 2026-05-16 | — | — | — |
| CC-054 | ⏸ deferred | CC-025 M2 — `/skill-refine` diff generation and Claude-assisted refinement；scope deferred when CC-025b was closed in `feat/cc039-cc025b-v2` | ux/memory | 2026-05-18 | pr:#67 | — | — |
| CC-063 | ⏸ deferred | Trace/token/gate metrics dashboard：`.agent-trace/*.jsonl` + `rate-limits*.json` + `.gate-results/*.md` 視覺化 per-session token、gate pass rate、routing_log 趨勢 | ux/ops | 2026-05-18 | — | P3 | — |
| CC-064 | ⏸ deferred | Project bootstrap wizard：互動式 `scripts/setup-project.sh --init` 引導新 repo 建立 memory、rules、PM schema | ux | 2026-05-18 | roadmap:CC-031 | P2 | — |
| CC-065 | ⏸ deferred | Per-repo configurable gate pipeline：不同 repo 可設定不同 reviewer 組合與 tier 預設（例如 `.pm-dispatch/gate.toml`） | ops/gate | 2026-05-18 | — | P3 | — |
| CC-104d | ⏸ deferred | **[Windows]** hook-codex-bash-guard.sh hardcoded `$HOME/github` read-root；應改為派生自 `PM_DISPATCH_REPO` parent（parked: CC-370） | ops | 2026-05-17 | — | — | oss |
| CC-104e | ⏸ deferred | **[Windows]** WSL ↔ Windows memory path divergence：不同 project-id 致 memory partitioned；workaround: symlink 或 PM_DISPATCH_PROJECT_ID override（parked: CC-370） | ux/memory | 2026-05-17 | — | — | oss |
| CC-104f | ⏸ deferred | **[Windows]** jq hard-dep in hooks layer；`--no-hooks` install mode preferred（parked: CC-370） | arch/install | 2026-05-17 | — | — | oss |
| CC-104g | ⚠️ partial 2026-05-17 | **[Windows]** portable.sh test fixes: symlink SKIP ✅；mkdir_lock FIFO sync ✅；但 Git Bash `mkdir` 仍允許第二個 acquire — see CC-104k（parked: CC-370） | ops/test | 2026-05-17 | pr:#80 | — | oss |
| CC-104j | ⏸ deferred | **[Windows]** test-dispatch-handover.sh symlink fixture 在 Git Bash 失敗（`ln -s` → copy fallback → validator treats as regular file）（parked: CC-370） | ops/test | 2026-05-17 | — | — | oss |
| CC-104k | ⏸ deferred | **[Windows]** UNC/9P `mkdir` non-atomic（`\\wsl.localhost\...`，本地 NTFS 正常）；not a code bug；docs/preflight fix in CC-104r（pair with CC-104r；parked: CC-370） | ops/portability | 2026-05-18 | — | — | oss |
| CC-104m | ⏸ deferred | **[Windows]** Platform layout multi-target projection：`~/.pm-dispatch/content/` as canonical view + symlink to `~/.claude/` etc.（parked: CC-370） | arch/install | 2026-05-18 | — | — | oss |
| CC-104r | ⏸ deferred | **[Windows]** hook-tool-trace.sh perf budget fails on WSL UNC path（9P ~8× slower）；docs + preflight UNC detection fix（pair with CC-104k；parked: CC-370） | docs/ops | 2026-05-18 | — | — | oss |
| CC-104s | ⏸ deferred | **[Windows]** hook-tool-trace.sh path normalization fails on Git Bash backslashes；normalize via cygpath before case-match（parked: CC-370） | ops/portability | 2026-05-18 | — | — | oss |
| CC-205 | ⏸ deferred | `/pm` dual-executor planning：`--executor auto/codex/claude` flag + `--parallel-plan` mode（PM 偵測 arch 特徵時暫停確認；parallel dispatch 後主線程合成計劃） | process | 2026-05-20 | — | P2 | design |
| CC-209 | 🟢 someday | codegraph evaluation（Phase 1 AMBER）：pm-dispatch 非有效測試目標；Phase 2 benchmark 需 TS/JS/Python/Go codebase（see CC-253） | ops/token | 2026-05-21 | pr:TBD | P3 | spike |
| CC-210 | ✅ done | **[uninstall blast-radius guard]** `uninstall.sh` currently allows `$HOME/.claude` itself to pass the managed-root safety guard (dst must start with managed root); a malformed or tampered copy-mode manifest entry matching the directory hash could remove the entire Claude config tree. Fix: add an explicit `[[ "$dst" == "$managed_root" ]]` rejection check before the startswith guard, so only strict descendants of the managed root are deletable. Raised by risk-reviewer in PR #110 gate as [medium] advisory. **See**: pr:#340 | ops | 2026-05-21 | pr:#340 | P3 | hygiene |
| CC-211 | ⏸ deferred | v0.3.0 arch epic：schema-first PM runtime（core/runtime/adapters/mcp 四層）；adapters codex+claude 已 ship；state-first/mcp 仍 open | arch/portability | 2026-05-21 | — | P1 | design |
| CC-212 | ⏸ deferred | **[fix: harden Windows junction install — path-passing + idempotency]** 兩個 Windows junction hardening 合併一 PR（吸收 CC-213）：(A) `make_junction_windows()` 改用 `PM_DISPATCH_MAKE_SRC`/`PM_DISPATCH_MAKE_DST` env var 傳路徑，統一 PowerShell boundary 慣例；(B) `install_dir_junction()` 加 manifest-driven idempotency probe，不再依賴 `-L` 偵測。 | ops/portability | 2026-05-21 | pr:#112 | P3 | oss |
| CC-214 | ⏸ deferred | **[CC-207 advise follow-up]** `docs/platform-support.md` 手動 uninstall 說明使用裸 `bash uninstall.sh`，在非 repo-root 工作目錄下執行會找不到腳本；應改為 `bash "${PM_DISPATCH_REPO}/uninstall.sh"` 形式（與文件其他範例一致）。Raised by critic in gate-20260521-115634 as [low] advise. | ops/DX | 2026-05-21 | pr:#112 | P3 | oss |
| CC-216 | ⏸ deferred | MCP server（DEFERRED no milestone，2026-06-18 user 拍板；待 executor 抽象 + retrieval/memory 基底穩定後再評估） | arch/portability | 2026-05-21 | — | — | design |
| CC-224 | ✅ done | **[shared hook-profile inventory: doctor.sh ↔ install-guards.sh]** `doctor.sh` owns a second hardcoded minimal/full hook membership model alongside `install-guards.sh`, creating a silent drift path when hooks are added or profile semantics change. Extract the hook-profile list into a shared shell helper (e.g. `scripts/hook-profile.sh`) or add a parity test asserting both files expect the same hook set. Raised by critic + architecture-reviewer as [medium] advise in gate-20260522-100348. **See**: pr:#341 | arch/reuse | 2026-05-22 | — | P3 | oss |
| CC-227 | ⏸ deferred | **[refactor: extract yaml-frontmatter lib + shared validation helpers]** 把 `check_frontmatter()` 與 shared helpers（dq-escape/adjacent-quote/empty-entry，原 CC-226 範圍）一起搬到 `scripts/lib/yaml-frontmatter.sh`；`lint-frontmatter.sh` 成薄 CLI 包裝；`doctor.sh` 可 source lib 取代 fork subprocess。CC-226 已合併入本票。 | arch/reuse | 2026-05-22 | pr:#119 | P3 | oss |
| CC-236 | 🟢 someday | **[pmctl report — away-from-keyboard state roll-up]** A `pmctl report` rolling up state since last invocation (open tasks, blockers, last gate verdict, recent runs). Deprioritized 2026-05-22: the maintainer does not run agents unattended, so a "morning report" time-gap framing has low current need; on-demand status is already part of the `pmctl` surface (CC-215). Revisit if the workflow ever includes overnight / away dispatch. | ux | 2026-05-22 | — | — | design |
| CC-240 | 🔵 active | **[test-suite reliability follow-ups]** Part (a) — suite-count derivation in `scripts/test-run-all-tests.sh` — closed via CC-219 (pr:#129). Remaining: `[low]` `scripts/test-portable.sh::case_mkdir_lock_contention` holds the lock with a fixed `sleep 1.2` (pre-existing; conflicts with the qa AGENT.md red line on `sleep` for async sync) → CI-timing flakiness. Fix with an IPC / event-driven lock-hold. | test | 2026-05-23 | pr:#127 | P3 | oss |
| CC-244 | 🟢 someday | **[Typed artifact pipeline — spike → brief → handover schema]** Define `spike_v1` schema mirroring existing `dispatch_handover_v1`: frontmatter (`spike_id`, `status`, `decisions_resolved`, `branch_base`, `ticket_ids_consumed`, `project_tooling`) + named sections (`scope`, `findings`, `constraints`, `decisions`, `phase3_handover`). Add `scripts/spike-validate.sh` (mirror `handover-validate.sh`) + `scripts/gen-brief-from-spike.sh` (mechanical brief extraction). Reduces main-thread courier cost, makes spike→brief authoring mechanical, gives invariant checkpoints (`decisions_resolved=true` ⇒ no re-asking Q1/Q2). Defer until 3+ spike docs exist and the brief-extraction pattern repeats; only one spike (CC-060) today, so schema would be premature overhead. CC-243 field names chosen to align with this future schema (no re-wash needed at upgrade time). | arch | 2026-05-23 | — | — | design |
| CC-253 | 🟢 someday | **[CC-209 Phase 2: codegraph benchmark on representative target codebase]** Phase 1 (PR #151) verdict AMBER — codegraph install ✓ license MIT ✓ API ✓, but pm-dispatch (bash/markdown) isn't a valid test target (`62 unsupported language`). Phase 2 re-scope: user picks a TS/JS/Python/Go target codebase at brief time, index it via codegraph, run 3 representative queries against rg/git baseline, measure token + latency delta. Output: append `## Phase 2` section to `docs/spikes/cc209-codegraph-phase1.md` OR new sibling doc. Verdict per original CC-209 ticket: adopt / defer / reject for context-pack source (CC-232 / CC-237). | ops/token | 2026-05-24 | pr:TBD | P3 | spike |
| CC-258 | ✅ done | pm-write-guard hook 政策修訂：3 條新 allow rule（`/tmp/<slug>/*.md`、`docs/spikes/*`、symlink memory 雙正規化）+ ~15 迴歸測試 | process | 2026-05-24 | pr:#342 | P3 | hygiene |
| CC-259 | 🟢 someday | **[yaml.sh lib extraction]** Extract `_yaml_get` bash/awk helper and `case_yaml_parse` structural validator from `scripts/test-core-schemas.sh` into `scripts/lib/yaml.sh` for reuse across test scripts; add independent test file `scripts/test-yaml-lib.sh` and wire into `run-all-tests.sh` + CI. Currently only used in `test-core-schemas.sh`; extraction deferred from CC-229 M1 PR to reduce gate surface. Trigger: second consumer in a new test script. | ops/test | 2026-05-25 | pr:TBD | P3 | — |
| CC-270 | ⏸ deferred | **[test: concurrent pmctl adapter generate guard]** Two simultaneous `pmctl adapter generate <same-name>` runs can race: the precheck+mkdir+trap sequence is not atomic. Blast radius: one run may delete another's partial output; reproducible by deleting `adapters/<name>` and rerunning. Deferred — single-developer workflow makes this low-probability; fix with atomic mkdir using `mkdir` exit-code guard when needed. | test/ops | 2026-05-28 | — | P3 | — |
| CC-273 | ⏸ deferred | arch: unified lifecycle hook event spec（`.pm-dispatch/hooks/<event>.sh`）；activate when second hook point beyond gate pre/post emerges | arch/gate | 2026-05-28 | — | P3 | — |
| CC-276 | ⏸ deferred | **[feat: persistent gate override declarations]** 每輪 gate 重開 fresh session，已接受的 risk override 必須重新聲明。支援 `--override-file` 或自動探索 `.gate-overrides.md`，inject 到 reviewer prompt 前置脈絡，避免已接受的 block 重複出現。 | gate/process | 2026-05-29 | — | P2 | — |
| CC-285 | ✅ done | **[archiver safe-drop: don't drop a terminal row whose body exists nowhere]** `scripts/archive-closed-backlog.sh` currently drops a terminal index row even when no body section exists in BACKLOG.md and none is in BACKLOG-ARCHIVE.md (warns to stderr). In a valid backlog `validate.sh`'s index↔body 1:1 invariant prevents this, and it is git-recoverable — recorded as accepted tradeoff in DECISIONS 2026-05-30. Defense-in-depth follow-up: keep the row + emit a loud warning when the body is in neither file, leaving it for manual reconciliation rather than removing it. Surfaced by pr-gate critic on #186. | ops | 2026-05-30 | — | P3 | hygiene |
| CC-286 | ⏸ deferred | **[pmctl: prefix-generic next-id derivation]** `scripts/pm-prep-snapshot.sh` derives `backlog_next_id` CC-only (it emits `CC-NNN`); under the working-set contract it scans BACKLOG.md + BACKLOG-ARCHIVE.md for the max, but only `CC-` IDs. A cross-repo next-id (other prefixes: JS-, PA-) must be prefix-derived and centralized in pmctl, scanning both working-set and archive. Retire pm-prep-snapshot's CC-hardcoded derivation when `pmctl backlog`/next-id lands. Surfaced by pr-gate critic+architecture on #186. | arch | 2026-05-30 | — | P3 | design |
| CC-306 | ⏸ deferred | **[arch: extend CC-233 layer enforcer to runtime-named data paths in scripts/]** Guard against re-introducing `.codex-*`/`.claude-*` DATA directories under scripts/ (the optional follow-up deferred from CC-298). | arch | 2026-06-01 | — | P3 | design |
| CC-333 | ⏸ deferred | arch: pm-dispatch runtime 解耦合（v0.6.0 umbrella）；layer 2/3/5/6 已交付（v0.6.0）；layer 1/4/7 移後版；open sub-tickets: CC-381/390/393/412 | arch | 2026-06-07 | — | P2 | design |
| CC-340 | ⏸ deferred | knowledge index: embeddings/semantic-backend remainder（FTS/LIKE MVP 已由 CC-403 接管；本票保留 Khoj-class semantic accelerator，待 FTS ranking 不足時 resume） | memory | 2026-06-08 | — | P3 | retrieval |
| CC-342 | 🟢 someday | agent: debt-auditor — proactive tech-debt health scan（`agents/debt-auditor.md`；`pmctl audit <path>` 呼叫；PR-free 主動健康掃描，有別於現有 PR-focused reviewers） | process/DX | 2026-06-05 | — | P3 | design |
| CC-346 | ⏸ deferred | repo-index: cross-file ref tracking `file_refs` table（paused 2026-06-10；resume trigger: reuse-scan 進過 ≥2 份真 brief 且缺 ref 資料為瓶頸；屆時先 Phase a bash source） | ops | 2026-06-09 | — | P3 | design |
| CC-347 | 🟢 someday | pr-gate blast-radius analysis using CC-346 file_refs（blast_radius 清單注入 brief context；無 CC-346 index 時靜默跳過） | gate | 2026-06-09 | — | P3 | design |
| CC-348 | 🟢 someday | **[pmctl project-map: cross-file dependency graph visualisation]** `pmctl project-map [--format text/dot] [--from <path>] [--depth N]` — 以 CC-346 file_refs 表輸出 ASCII 樹狀（預設）或 Graphviz DOT 引用圖；標示 broken refs（to_path 不在 files 表）；無 index 時 exit 1 並提示 `pmctl context index`。 | ops/DX | 2026-06-09 | — | P3 | design |
| CC-352 | ⏸ deferred | **[codex-executor sandbox friction Pattern 1+2: apply_patch retry noise + Go module cache blocked]** issue:#173 Pattern 3（git commit blocked）已由 CC-272 pr:#245 吸收修復。剩餘：(1) apply_patch 中途失敗 self-retry 噪音 — brief 改拆小 hunk 加 unique context；(2) go build 時 GOPATH copy 被 sandbox 擋 — 文件化 GOPATH=/tmp/gopath 慣例。兩者均為 doc/convention fix。 | ops/DX | 2026-06-10 | — | P3 | — |
| CC-355 | 🟢 someday | knowledge index: HTML semantic chunking `<h1-6>`（trigger: .html file enters knowledge plane；plug into CC-354 per-format chunker seam） | memory | 2026-06-10 | — | P3 | design |
| CC-357 | 🟢 someday | **[skill as contract: machine-readable schema for skills]** 現有 skills/ 都是純 markdown prose（SKILL.md），沒有機器可讀的 input schema、output contract、tool_constraints、completion_condition。這使得 skill 無法被驗證、無法被工具自動發現、也無法像 dispatch_handover_v1 那樣由 validator 強制執行契約。本票引入 skill schema（YAML frontmatter 或 JSON sidecar），使 skill 具備：明確的輸入型別、輸出格式、允許/禁止工具清單、完成條件——平行於 brief-validate.sh 對 brief 的驗證角色。 | arch/DX | 2026-06-10 | — | — | design |
| CC-358 | 🟢 someday | runner telemetry：per-adapter 成功率/失敗模式/fallback 分析（events.jsonl 原料已有；`pmctl run-stats` 候選） | ops/memory | 2026-06-10 | — | — | design |
| CC-359 | 🟢 someday | concept: backlog-driven batch dispatch with worktree isolation（PM manages `git worktree` lifecycle；executor-agnostic；human-in-the-loop merge；PR-only output） | arch/ops | 2026-06-11 | — | — | design |
| CC-364 | ⏸ deferred | **[perf: `pmctl trace tail --all` per-event jq spawn]** `pmctl trace tail --kind <k> --all --json` is O(n) with a high per-event constant — ~20s for 338 events (~60ms/event), consistent with spawning a jq/subprocess per event rather than one streaming pass. Surfaced while diagnosing #270 context-telemetry test flakiness; the tests no longer depend on it (telemetry now honors `PM_DISPATCH_STATE_ROOT`, so the suite isolates state). Standalone reader-perf follow-up. **See**: pr:#270 | ops | 2026-06-12 | pr:#270 | P3 | hygiene |
| CC-369 | ⏸ deferred | Windows state store 真實 ACL via icacls（parked: CC-370；border case relative to profile ACL protection） | ops/portability | 2026-06-13 | — | — | hygiene |
| CC-370 | ⏸ deferred | **[native Windows support deferred to post-core platform phase]** 核心功能開發期間正式只支援 Linux + WSL2（WSL2 視為 Linux）；原生 Windows Git Bash 非官方支援，使用者走 WSL2。理由是專注：開發期同時扛多平台會排擠核心功能（CI 只測 Linux，每次碰 Windows 都要人工驗證 + gate churn，見 #272/#273）。已合併的 portability 程式碼保留（綠且成本低），但不再新增 Windows 分支，直到核心定型（v0.5.0+）後的專屬平台階段。Parks: CC-038, CC-104d/e/f/g/j/k/r/s, CC-369。**See**: DECISIONS.md 2026-06-13 defer-native-windows-support-during-core-dev | ops/portability | 2026-06-13 | — | — | design |
| CC-377 | ⏸ deferred | adapter: Google Antigravity（`agy`）executor（DEFERRED：headless CLI 1.0.8 不成熟；resume: newer agy with `--output-format stream-json`；umbrella: CC-333） | arch/portability | 2026-06-13 | — | P2 | design |
| CC-381 | ⏸ deferred | arch: install host-PM-aware（host runtime axis：codex/opencode host PM 設定面；排在 CC-373..377 之後；umbrella: CC-333） | arch/install | 2026-06-14 | — | P2 | design |
| CC-390 | ⏸ deferred | codex dispatch trace-capture 強化（FD inheritance cold-start flake；fail-closed safe；resume: stable repro；umbrella: CC-333） | arch/portability | 2026-06-15 | — | P3 | design |
| CC-393 | 🟢 someday | design: portable-skill-substrate — CLI-agnostic skill 控制層（design seed after v0.6.0 N≥2；3 control skills + Portable Skill v0 frontmatter；umbrella: CC-333） | arch | 2026-06-16 | — | — | design |
| CC-412 | 🟢 someday | memory substrate 跨工具可攜：位置 seam（`PM_MEMORY_DIR` override）+ 注入／檢索分層（可攜核心＝pmctl retrieval API） | arch/memory | 2026-06-23 | — | P3 | retrieval |
| CC-420 | 🔵 active | refactor: adapter 共用 model alias TSV 解析抽 lib（claude/codex/opencode 三者 ~30行重複）→ `scripts/lib/model-aliases.sh` | arch | 2026-06-24 | — | P3 | — |
| CC-421 | 🔵 active | refactor: adapter 共用 timeout 優先序邏輯抽 lib（3 adapter + post-verify ~15行×4重複）→ `scripts/lib/timeout-resolve.sh` | arch | 2026-06-24 | — | P3 | — |
| CC-422 | 🟢 someday | refactor: adapter 共用 dispatch 初始化邏輯抽 lib（claude/codex ~200行相似）→ `scripts/lib/dispatch-common.sh`；需先 spike 確認邊界 | arch | 2026-06-24 | — | P3 | — |
| CC-423 | 🟢 someday | gate detached lifecycle：`pmctl gate run --lifecycle detached` 回傳 gate_id 立即退出；gate-supervisor 以 nohup/setsid 跑 pr-gate.sh；sentinel 機制 + `pmctl gate wait <gate_id>` 輪詢；session interrupt 不影響 gate 執行結果 | arch | 2026-06-25 | — | P3 | — |
| CC-425 | 🟢 someday | **[gate: 解除 PR 綁定，改以 base..head ref 對為輸入]** 現在 `pmctl gate run` 預設從 `origin/main` fork point 推斷 base，gate result 以 PR# 為 key；改成接受任意兩個 ref（`--base <ref> --head <ref>`），讓 gate 可在開 PR 前本地跑，也可比較任意 branch 差異。需重構 gate 的 base 解析邏輯與 result 存放路徑（目前以 PR# 為 key，改以 `<base>..<head>` slug 或 run_id）。 | ops/gate | 2026-06-25 | — | P3 | — |
| CC-430 | ✅ done | **[release: `/pre-release` Layer 2 — 語義比對]** 承接 [[CC-426]] Layer 2。主線程直接讀取各 ticket Requirement 章節（從 BACKLOG）+ 對應 PR diff 摘要（`gh pr diff <PR#>`），內聯分析覆蓋度，輸出 per-ticket 結論表。相依 [[CC-426]]（Layer 1 穩定基礎）、[[CC-403]]（memory context query）、[[CC-404]]（注入預算）。 | ops/process | 2026-06-26 | pr:#339 | P1 | — |

---

## Convention

**ID scheme**: `CC-NNN` sequential. ID gaps are normal — use the `epic` column (see `pm/schema.md §2.4.5`) for semantic grouping instead of ID ranges. The `CC-1NN`/`CC-2NN` range-reservation convention is deprecated (see `DECISIONS.md#2026-05-19-deprecate-id-gap-convention`).

**Sub-letter IDs**: `CC-NNNa`, `CC-NNNb`, `CC-NNNc` are follow-up tickets to a parent `CC-NNN`, with independent lifecycles.

**Status legend** — _non-terminal_ (stay on the board):
- `🔵 active` — in backlog (not-started / in-progress / blocked)
- `⏸ deferred` — waiting on external condition or trigger, not scheduled
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

## CC-381 — arch: install host-PM-aware ⏸ deferred

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

## CC-390 — infra: codex dispatch trace-capture 強化 ⏸ deferred

**Problem / 目標**: [[CC-387]] 真實驗收期間發現，codex 0.139.0 在 session 冷啟動最初 1–2 次 dispatch 偶發 trace-capture flake。`adapters/codex/dispatch.sh` 把 codex stdout 經**繼承 FD**（`> "$TRACE"`）重導向到 `<work_dir>/.agent-trace/<ts>.jsonl`，但該檔在 codex sandbox 邊界偶失：`.last`（codex 以 `--output-last-message` 依路徑自開）存活，`.jsonl` 與 run-time `.stderr`（皆經 wrapper 繼承 FD）偶失，導致 [[CC-386]] post-verify「trace not found / 結構不完整」FAIL。

**證據（8 次 run）**: 非確定性——最初 2 次失敗、其後連 6 次完整 dispatch 全綠（含全新 repo 的 first-run）。已否證：isolation 值（`workspace-write` 與 `sandboxed` map 到**同一** codex 指令）、codex 是否 mutate workspace、fresh-repo first-run。最符合：codex CLI 冷啟動 transient（與 `agents/codex-executor.md` 既載「silent startup 已知 transient」一致）。

**安全性質**: **fail-closed**——trace 缺失時 post-verify 正確判 FAIL，**永不誤判 PASS**；失敗方向是 false-negative（成功 run 被報為失敗），非 false-positive。故非緊急。

**候選修法**: (a) trace 寫 `<work_dir>` 外（XDG state／temp 目錄），使 trace 不在 codex sandbox 的 workspace 內、也不污染 git status；(b) codex stdout 經 wrapper 控制的 pipe（`tee`）而非繼承 FD 直寫 in-workspace 檔（需處理 `PIPESTATUS` 以保留 exit code）。(a) 動到 trace 合約（post-verify／footer／latest 指標／多處測試引用 `<work_dir>/.agent-trace/`），較大；(b) 較外科。**前提：須先能穩定複現才能驗證任一修法**。

**Dependencies**: [[CC-386]]（trace 驗證合約）。發現於 [[CC-387]]。umbrella [[CC-333]]。

---

## CC-377 — adapter: Google Antigravity (`agy`) executor ⏸ deferred

**Status (2026-06-16)**: **DEFERRED — 待 agy 版本更新**。agy **有免費額度**（Gemini 3.x / Claude 4.6 / GPT-OSS 經 OAuth，成本非阻因）；暫緩純因 **headless CLI 尚未完善**。feasibility spike 證 agy 1.0.8 無 machine 契約，詳見 `docs/spikes/CC-377-agy-headless-feasibility.md`。實測：`--output-format`/`-o`/`--format`/`--log-level`/`--stream-format` 旗標皆被拒、無 `run` 子命令、`--print` 吐 prose narration（無 JSON/SSE、無語意終止事件）、headless 不穩（3/3 trivial-prompt 探針 timeout、不甩 do-not-use-tools 指令）。社群/AI 研究宣稱的 stream-json/SSE 模式不在 1.0.8（可能較新 build 才有）。**agy 仍為首選第二 adapter**。**Resume trigger（主路）**：較新 agy 出可用的 headless `--output-format stream-json` → 重跑探針，有 JSONL+終止事件即鏡像 `adapters/opencode/` 落地。**N≥2 影響**：暫未由 agy 達成；opencode（[[CC-376]]）為目前唯一獨立第三方 adapter；Phase 7 lifecycle 紅線（N≥2 後才做）出現 sequencing 缺口，待 maintainer 定奪（且 2026-06 免費 CLI 池枯竭，傾向等 agy 成熟而非另尋）。

**Problem / 目標**: 新增 Google Antigravity（CLI binary `agy`）作為第二個第三方 executor adapter，與 [[CC-376]] 對稱。第二個 adapter 的意義是驗證抽象在 **N≥2** 下成立——若 opencode 是特例僥倖，agy 會暴露出來。

**Note**: Google 的 **Gemini CLI 已棄用**；本票目標是 Antigravity 的 `agy` CLI，**不是 gemini**。adapter 目錄/名稱建議 `antigravity`（cli_binary `agy`），最終命名 impl 時定（須為 strict-identifier `^[a-z][a-z0-9_-]*$`）。

**Requirement**: 結構同 [[CC-376]]——`adapters/antigravity/` 的 dispatch.sh + adapter.yaml（`runner_kind`）+ isolation-map.yaml；主路 `pmctl dispatch run --adapter antigravity`；map sandbox/permission/model-alias；釐清 bash 攔截能力決定 guard 旗標。

**驗收**: 同 [[CC-376]]——零核心改動即可落地。

**Dependencies**: [[CC-373]]、[[CC-374]]。建議排在 [[CC-376]] 之後（第一個 adapter 若暴露抽象缺口，先補再上第二個）。umbrella [[CC-333]]。

---

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

## CC-210 — uninstall.sh: reject managed-root exact path as deletion target ✅ 2026-06-29

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

**See**: pr:#340

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

**Status (updated 2026-06-18)**: **DEFERRED — not assigned to any milestone.** Originally deferred to v0.4.0, then floated as v0.7.0 headline; 2026-06-18 user 拍板：不排入任何 milestone，待核心（executor 抽象 + retrieval/memory 基底，見 v0.7.0 retrieval epic）覺得**基本都穩定**後再考慮。MCP must wrap a stable `pmctl`, never an immature one. v0.3.0 was to ship only `mcp/README.md` defining the tool surface as a `pmctl` interface design constraint (AS-BUILT 2026-05-31: not written — `mcp/` absent; see synthesis Conformance status §B). See [`docs/architecture/v0.3.0-synthesis.md`](../docs/architecture/v0.3.0-synthesis.md) §5.4.

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

## CC-224 — shared hook-profile inventory: doctor.sh ↔ install-guards.sh ✅ 2026-06-29

**Problem**: `scripts/doctor.sh` owns a second hardcoded minimal/full hook membership model (around line 240) that mirrors the one in `scripts/install-hooks.sh`. When a new hook is added or a profile boundary changes, it is easy to update one file and miss the other — this is a silent drift path with no compile-time check.

**Why**: Raised by critic and architecture-reviewer as [medium] advise in PR-gate `gate-20260522-100348`. The duplication became structurally significant once `--profile minimal|full|auto` was added and both files enumerate hooks by profile.

**Requirement**: Extract the managed hook list and profile classification into a shared shell helper (e.g. `scripts/hook-profile.sh`) sourced by both `doctor.sh` and `install-hooks.sh`. Alternatively, add a parity test (e.g. `test-hook-profile-parity.sh`) that parses both files and asserts the hook sets are identical for each profile tier.

**Dependencies**: CC-058（profile flag already landed）

**Priority**: P3 — maintainability; current duplication is limited to two well-known files.

**Cross-link**: CC-223（boundary fix; pair these if tackling doctor.sh again）, CC-204（hook/profile reuse debt）

**See**: pr:#341

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

## CC-258 — pm-write-guard hook policy revision ✅ 2026-06-29

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

**See**: pr:#342; `docs/spikes/CC-258-pm-write-guard-policy.md` (full design, audit data table, code change sketch, test coverage sketch, risks + mitigations).

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

## CC-104d — [Windows dogfood r1] hook-codex-bash-guard.sh hardcoded read-root ⏸ deferred

**Problem**: `hook-codex-bash-guard.sh:55` defaults read-root to `$HOME/github:/tmp`; repos under `~/Documents/github/` or arbitrary Windows paths are not covered. `CLAUDE_HOOK_CODEX_READ_ROOTS` env override exists but the wrong default silently restricts hooks.

**Scope clarification (2026-06-04, from CC-320 pr:#224 gate)**: the `$HOME/github` default is *only* consumed on the **codex-executor subagent PreToolUse path** where the env var is unset. The adapter/CLI dispatch path (`adapters/codex/dispatch.sh`) now always exports `<git_root>:/tmp[:inherited]` (CC-320), so the default is dead there. Do **not** "unify on `/tmp` only" — that would strip repo read access from the subagent path and break the common case rather than fix it.

**Fix direction — derive, don't hardcode**: replace `$HOME/github` with a derived repo root (e.g. `PM_DISPATCH_REPO` parent, or `git rev-parse --show-toplevel` of the hook's invocation cwd), keeping `/tmp` as the scratch baseline. *Alternative*, only if the codex-executor-as-subagent path is confirmed fully retired post-CC-299 (i.e. everything goes through the adapter which always sets the env): the default becomes near-dead code and may be reduced/removed — but verify that retirement first; do not assume it. Prefer fail-closed + explicit hint over silently defaulting to `/tmp` when no repo root can be derived.

**Cross-link**: [[CC-320]], [[CC-299]].

## CC-104e — [Windows dogfood r1] WSL ↔ Windows memory path divergence ⏸ deferred

**Problem**: Project ID is path-sanitized working dir. Same repo at `~/github/pm-dispatch` (WSL) and `C:\Users\...\github\pm-dispatch` (Windows) produces different IDs → memory is partitioned across environments.
**Fix**: Document workaround (symlink, or `PM_DISPATCH_PROJECT_ID` override); harness-level issue upstream.

## CC-104f — [Windows dogfood r1] jq hard-dependency in hooks layer ⏸ deferred

**Problem**: Hooks layer hard-depends on `jq`. Options: vendor static `gojq` binary (3 MB × 3 platforms), or expose `--no-hooks` install mode for jq-less users.
**Decision**: `--no-hooks` preferred — keeps no-auto-install principle.

## CC-104g — [Windows dogfood r1] portable.sh test fixes ⚠️ partial 2026-05-17

**Problem**: `mkdir_lock` FIFO sync passes ✅ but underlying `mkdir` on Git Bash allows second concurrent acquire — real Windows portability bug. See CC-104k for the UNC/9P root cause.
**See**: pr:#80

## CC-104j — [Windows dogfood r1/r2] test-dispatch-handover.sh symlink fixture on Git Bash ⏸ deferred

**Problem**: `brief_file_symlink_rejects_case` uses `ln -s` for fixture; on Git Bash falls back to copy → validator treats as regular file → test fails. Fix: add `[[ -L "$link" ]]` precondition → SKIP.

## CC-104k — [Windows dogfood] UNC/9P filesystem mkdir atomicity caveat ⏸ deferred（建議與 CC-104r 合併實作）

**Problem**: `mkdir` is atomic on local NTFS but NOT on `\\wsl.localhost\...` (9P UNC). Running pm-dispatch from a WSL UNC path on Windows breaks concurrent lock semantics.
**Fix**: Not a code bug — install-on-local-disk caveat. Fix is docs + preflight; see CC-104r for the implementation. **建議與 CC-104r 同一 PR 落地** — CC-104k 是問題分析，CC-104r 是 docs/preflight 修正，屬同一 caveat 的兩半。

## CC-104m — [Windows dogfood] Platform layout — multi-target projection ⏸ deferred

**Problem**: pm-dispatch is currently Claude-only by install.sh target. Introduce `~/.pm-dispatch/content/` as canonical view with symlink-project to `~/.claude/` and future tool targets.
**Scope**: Post-v0.1.0, deferred until Codex/Cursor/Aider integration need surfaces.

## CC-104r — [Windows dogfood r3] hook-tool-trace.sh performance budget on Windows ⏸ deferred（建議與 CC-104k 合併實作）

**Problem**: Actual: 27990 ms vs 3500 ms budget on WSL UNC path (9P is ~8× slower than local disk). Not a pm-dispatch code bug — physical filesystem characteristic of running pm-dispatch from `\\wsl.localhost\...`.
**Fix** (two-part — covers both CC-104r + CC-104k's caveat documentation): (a) `docs/platform-support.md` warn "install on local disk, avoid cross-WSL/native FS boundaries"; (b) preflight detects UNC path → prints warning and skips budget assertion (~10 lines). **建議與 CC-104k 同一 PR**：CC-104k 是問題根因分析，CC-104r 是 docs/preflight 落地，屬同一 caveat 的兩半。

## CC-104s — [Windows dogfood r3] hook-tool-trace.sh path normalization on Git Bash ⏸ deferred

**Problem**: `read_home_path_basename_only` case-glob fails on Windows backslash paths. Fix: normalize via `cygpath`/string-replace before case-match. Affects trace JSON observability only.

## CC-285 — [ops] archiver safe-drop: don't drop a terminal row whose body exists nowhere ✅ 2026-06-30

**Problem**: `scripts/archive-closed-backlog.sh` drops a terminal index row (`✅ closed` / `🚫 dropped`) even when no body section accompanies it in BACKLOG.md and none already exists in BACKLOG-ARCHIVE.md. It emits a per-id stderr warning, but the row metadata is removed (recoverable only via git).

**Why**: In a valid backlog this cannot happen — `pm/scripts/validate.sh` enforces an index↔body 1:1 invariant, so a terminal row always has a body to archive. It only arises from malformed/partial state. Recorded as an accepted tradeoff in DECISIONS 2026-05-30. This ticket tracks the defense-in-depth improvement if that invariant ever weakens.

**Requirement**:
1. When a terminal row's body is found in neither BACKLOG.md (this run) nor BACKLOG-ARCHIVE.md, do NOT drop the row; keep it and emit a loud warning for manual reconciliation.
2. Regression fixture: terminal row + no body anywhere → row preserved + warning (not removed).

**Cross-link**: `[[CC-284]]` (working-set contract / archiver), pr-gate finding on PR #186.

**See**: pr:#TBD

## CC-286 — [arch] pmctl: prefix-generic next-id derivation ⏸ deferred

**Problem**: `scripts/pm-prep-snapshot.sh` derives `backlog_next_id` for the `CC-` prefix only — it emits `CC-NNN` and scans BACKLOG.md + BACKLOG-ARCHIVE.md for the max `CC-` id. Other-prefix repos (JS-, PA-) are not handled; a generic next-id that only read the working-set index would also reuse archived IDs (the §2.2 hazard fixed CC-only in CC-284).

**Why**: pm-prep-snapshot is pm-dispatch-specific by design, so its CC-coupling is currently consistent (not a regression). But the cross-repo next-id belongs in `pmctl`, deriving the prefix from the target repo and scanning both the working set and the archive. Surfaced by pr-gate critic + architecture-reviewer on PR #186.

**Requirement**:
1. `pmctl` next-id: derive prefix from the repo's existing IDs (or config); compute max across BACKLOG.md + BACKLOG-ARCHIVE.md; `+1`.
2. Retire pm-prep-snapshot's CC-hardcoded derivation once pmctl provides next-id.

**Cross-link**: `[[CC-215]]` (pmctl core), `[[CC-282]]` (pmctl backlog), `[[CC-284]]` (working-set + the CC-only fix this generalizes).

## CC-306 — [arch] extend CC-233 layer enforcer to runtime-named data paths in scripts/ ⏸ deferred

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

## CC-340 — knowledge index: standalone FTS over memory/backlog/decisions ⏸ deferred (SUPERSEDED by [[CC-403]])

> **SUPERSEDED 2026-06-18**: the out-of-repo memory-card / episodes indexing + standalone full-text ranking MVP is now owned by **[[CC-403]]** (`pmctl context --source memory`, retrieval epic, v0.7.0). CC-340 is retained only as the **embeddings / semantic-backend remainder** (Khoj-class accelerator) that CC-403 explicitly leaves out of its MVP; resume only if FTS5/LIKE ranking proves insufficient in practice. The anchored-TOC slice already shipped as [[CC-354]] (v0.5.0).

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

**Cross-link**: [[CC-354]] (anchored-TOC slice, pulled forward), [[CC-338]] (repo-index counterpart), [[CC-237]] (shared interface), [[CC-234]] (memory v2 write side), [[CC-232]] (pack schema), [[CC-403]] (supersedes the memory-index MVP).

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

## CC-412 — memory substrate 跨工具可攜（decouple from Claude-specific location + injection）

**Problem**: 專案記憶目前綁兩處 Claude 專屬實作，使「跨 AI 工具/agent（codex、opencode、未來 host）共用同一份專案記憶」困難：(1) `find_memory_dir`（`scripts/lib/memory.sh`）的目錄慣例寫死 `CLAUDE_CONFIG_DIR/projects/<encode(cwd)>/memory/`；(2) MEMORY.md 的每-session 注入靠 Claude Code 的 UserPromptSubmit hook，其他工具沒有等價 hook，既無法定位也無法注入。

**Why / 決策分析（此 ticket 即 decision record）**:
- **已可攜的部分**（CC-405 剛強化，刻意做成工具中立）：卡片＝純 Markdown+YAML；`pmctl memory doctor`、`pmctl context --source memory`（[[CC-403]] 的中立檢索 API）；memory 衍生 DB；[[CC-405]] frontmatter schema（topics/priority/status/...）。標準化反而**降低** Claude 耦合——把記憶從「memory-graph 工具的不透明附屬品」變成 pmctl 可檢查、可檢索的結構化資料。
- **真正耦合僅兩處**：位置 resolver + 注入機制。`metadata.node_type`/`originSessionId` 是 Claude memory-graph 的 additive 標籤，YAML 忽略未知鍵，**不阻礙**其他工具（[[CC-405]] spike 已明訂禁止移除 `metadata` block，正是為了不鎖死）。
- **決策方向**：不打掉重練、不移除任何東西；**加兩個 seam**。

**Requirement**:
- **位置 seam**：`find_memory_dir` 支援顯式 `PM_MEMORY_DIR`（或 config `dispatch.memory_dir`）覆寫，解析優先序明確（env > config > `CLAUDE_CONFIG_DIR` 慣例）；`memory doctor` / `context --source memory` / `mem-*` 全部走同一解析。未設時行為與今天 byte-identical（向後相容 load-bearing）。
- **注入 adapter 化**：文件化「**可攜核心＝pmctl retrieval API**；注入＝per-tool adapter」。Claude UserPromptSubmit hook 為現成 adapter；其他工具不靠 hook，改主動呼叫 `pmctl context --source memory` 取記憶。
- 下游 [[CC-404]]/[[CC-406]]/[[CC-407]] 應建在 retrieval API 上、而非 Claude 注入機制上。

**Acceptance**:
- 設 `PM_MEMORY_DIR` 後 `pmctl memory doctor` / `pmctl context --source memory` 解析到該目錄；未設時與今天行為一致。
- docs 說明跨工具取記憶走 `pmctl context --source memory`（注入為 per-tool adapter）。
- 不破壞 Claude 路徑預設；`metadata` block 維持不動。

**Sequencing / relation**: 與 [[CC-011]]/[[CC-012]]（記憶**跨裝置** sync：symlink/pull）**正交**——那是同一份 memory 跨機器，本票是同一份 memory **跨工具**可攜；兩者可共用「位置不再硬綁 ~/.claude」這個 seam。建在 [[CC-403]] retrieval API 上。

**Priority**: P3（someday）。

## CC-420 — refactor: adapter 共用 model alias TSV 解析抽 lib 🟢 someday

**Problem**: claude/codex/opencode 三個 adapter 各自重複相同的 model alias TSV 解析邏輯（約 30 行 × 3）。

**Why**: 三份複製體確保任何欄位調整或 alias 格式變化都要改三處，且測試覆蓋分散——實際上三個 adapter 讀同一份 TSV 格式，解析邏輯 byte-identical。

**Requirement**: 抽 `scripts/lib/model-aliases.sh` 提供 `ma_resolve_alias <adapter> <alias>` 函式；三個 adapter source 該 lib 並刪除各自的重複邏輯；`test-model-aliases.sh` 直接測試 lib；現有 adapter 測試的 alias 行為路徑不得退化。不改 TSV schema 或 alias 語意。

**Acceptance**:
- `bash scripts/test-model-aliases.sh` 通過。
- 三個 adapter 的 model alias 行為與今天 byte-identical（現有 adapter 測試綠）。
- `lint-model-aliases.sh` 仍通過。

**Priority**: P3（someday）。

## CC-421 — refactor: adapter 共用 timeout 優先序邏輯抽 lib 🟢 someday

**Problem**: 三個 adapter 與 `dispatch-post-verify.sh` 均有相同的 timeout 優先序模式（flag > env > config > default），約 15 行 × 4 處重複。

**Why**: timeout 優先序若需調整（例如加 config 層級或改 default 值），須改 4 處且各處行為需保持一致；目前缺乏單一 source of truth。

**Requirement**: 抽 `scripts/lib/timeout-resolve.sh` 提供 `tr_resolve_timeout <flag_val> <env_var_name> <config_key> <default>` 函式；四個呼叫方改用此函式；現有測試的 timeout 行為路徑不得退化。不改 timeout 語意或預設值。

**Acceptance**:
- 四個呼叫方（claude/codex/opencode adapter + dispatch-post-verify）行為與今天 byte-identical。
- 新增 `test-timeout-resolve.sh` 覆蓋 flag > env > config > default 四層優先序。

**Priority**: P3（someday）。

## CC-422 — refactor: adapter 共用 dispatch 初始化邏輯抽 lib 🟢 someday

**Problem**: claude/codex 兩個 adapter 有約 200 行高度相似的 dispatch 初始化邏輯（snapshot、isolation map 解析、brief 讀取、run-dir 建立）。

**Why**: 兩份複製體讓 dispatch 核心流程改動需同步兩處，且介面不一致時 bug 只在一個 adapter 出現——歷史上 CC-414 的 trace-dir seam 就因此需要在三個 adapter 各自加一次。opencode 在此已有部分分歧（isolation 翻譯不同），須仔細界定共用邊界。

**Requirement**: 分析 claude/codex/opencode 三個 adapter 的 dispatch 初始化，識別可安全共用的部分（純 setup：snapshot、brief parse、run-dir 建立）與必須保持 per-adapter 的部分（isolation 翻譯、native flag 傳遞）；抽出前者到 `scripts/lib/dispatch-common.sh`；後者維持 per-adapter。不改任何可見行為。

**Acceptance**:
- 三個 adapter 的 dispatch 行為與今天 byte-identical（現有 adapter 測試全綠）。
- 新增 `test-dispatch-common.sh` 覆蓋被抽出的共用函式。
- `dispatch-common.sh` 不引入跨 adapter 的隱式耦合（isolation 翻譯仍 per-adapter）。

**Note**: dispatch-common 涉及 adapter 核心邏輯，重構前須先確認三個 adapter 的分歧點；建議在實作前做 spike 確認介面邊界。

**Priority**: P3（someday）。

## CC-423 — gate detached lifecycle 🟢 someday

**Problem**: `pmctl gate run` 目前以 foreground 模式執行（無 lifecycle 選項），透過 Claude Code harness 的 `run_in_background: true` 監控。Session interrupt 會讓 harness 遺失對 gate process 的追蹤，回報錯誤的 exit code（同 CC-418 之前 dispatch 的問題）。

**Why**: dispatch 已透過 `--lifecycle detached`（nohup/setsid + sentinel 機制）完全解耦，gate 應有對等能力。Gate 跑 3-5 分鐘，風險低於 dispatch（30+ 分鐘），但架構上仍是同一個缺陷：process 存活與否取決於 harness 是否在線。

**Requirement**:
- `pmctl gate run --lifecycle detached` 立即回傳 `gate_id`（格式：`gate-<ts>-<rand>`），exit 0
- `scripts/gate-supervisor.sh`：以 `nohup/setsid` 啟動 `pr-gate.sh`，完成後寫 sentinel（複用 dispatch sentinel 機制：`/tmp/pm-gate-sentinel-<gate_id>-<nonce>`）
- `pmctl gate wait <gate_id> --cd <work_dir>`：輪詢 sentinel，完成後輸出 `gate: <gate_id>  state: <GO/NO-GO>  exit: <N>`，exit 代碼等同 sentinel
- `/pr-gate` skill 改為兩步：(1) detached launch → gate_id，(2) `pmctl gate wait` in background
- 維持 `--lifecycle foreground` 作為 backward-compat 選項（預設改 detached）

**Acceptance**:
- `pmctl gate run --lifecycle detached` 回傳 gate_id 並立即退出
- Session interrupt 後 gate 繼續執行，`pmctl gate wait` 在新 session 中可重新等待結果
- gate result file 路徑仍從 gate run dir 讀取（已有 gate-20xxx 格式）
- `pmctl gate run --lifecycle foreground` 行為不變（backward-compat）

**See**: dispatch sentinel 實作於 `scripts/dispatch-supervisor.sh`、`scripts/lib/pmctl-dispatch.sh`（`pmctl_dispatch_run_detached`、`pmctl_dispatch_wait`）可參考複用。

**Priority**: P3（someday）.

## CC-425 — gate: 解除 PR 綁定，改以 base..head ref 對為輸入 🟢 someday

**Problem**: `pmctl gate run` 目前的 base 推斷邏輯綁死在 `git merge-base --fork-point origin/main HEAD`，gate result 也以 PR# 為 primary key——這意味著 gate 只能在已有 PR（或預設對 main）的情況下有意義地跑，無法在開 PR 前本地對任意兩個 branch 做 diff-gate，也無法比較 `v0.6.0..v0.7.0` 這類 tag-to-tag diff。

**Why**: 讓 gate 成為通用的「diff 品質閘門」，不依賴 PR 存在。可用於：開 PR 前先本地跑確認、milestone boundary 差異審查、任意 feature branch 對 release branch 的 diff review。

**Requirement**:
- `pmctl gate run [--base <ref>] [--head <ref>]`：兩者均可省略（維持現有推斷行為作為 fallback）。
- gate result 存放路徑從 PR# key 改為 `<base-slug>..<head-slug>` 或 run_id，PR# 僅在有 PR 時作為 optional metadata 加入。
- 文件 + `pmctl gate run --help` 說明新參數。

**Priority**: P3（someday）.

## CC-430 — release: `/pre-release` Layer 2 — 語義比對 ✅ 2026-06-29

**Problem**: CC-426 Layer 1 只驗結構標記（✅/PR ref/CHANGELOG mention），無法確認 PR diff 是否真的滿足 ticket 的 Requirement——ticket 說改 X/Y/Z，diff 只改了 X/Y 的情況在 Layer 1 完全偵測不到。

**Why**: Layer 2 補上「需求 vs 實作」的語義比對層，讓 `/pre-release` 報告從「tracking hygiene 乾淨」升級到「實作覆蓋可追溯」。Layer 1 是必要前提（穩定的結構資料讓 diff mapping 可靠），Layer 2 是增值層。

**Requirement**:

承接 [[CC-426]] Layer 2 設計：

**主線程執行策略**
- 主線程逐 ticket 讀取 BACKLOG 的 Requirement 章節
- 對應 PR diff 摘要由主線程取（`gh pr diff <PR#>`）
- 主線程內聯分析覆蓋度，輸出 per-ticket 結論
- 可取 `pmctl context query --source memory` 相關 decision 背景輔助判斷

**Output 格式（追加至 Layer 1 + Layer 3 報告後）**：
```
### Layer 2 — Semantic coverage
| Ticket | Requirement summary | Diff coverage | Confidence | Flag |
```

**Constraints**:
- 主線程執行，不派發子 job（閱讀理解任務，主線程直接處理）
- PR diff 由主線程自行取，每 ticket targeted read，不整份 diff 一次塞入
- 不輸出 GO/NO-GO；報告判斷留給人

**Depends on**: [[CC-426]]（Layer 1 穩定基礎）、[[CC-403]]（memory context query）、[[CC-404]]（注入預算）。

**Priority**: P1（v0.7.1）. CC-429 dogfood run 完成後升 P1（2026-06-29）；CC-426 Layer 1 穩定、依賴 CC-403/CC-404 全 ✅。

**See**: pr:#339
