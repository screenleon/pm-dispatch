<!-- pm-schema: v1 -->
# claude-config backlog

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
| CC-006 | 🔵 active | statusLine hook 自動寫入 rate-limits，`--remaining` 免手動輸入 | ux | 2026-05-13 | pr:#40 |
| CC-007 | 🔵 active | brief qa_checklist 指引寫入 docs/codex-brief.md + agents/project-pm.md | process | 2026-05-13 | — |
| CC-008 | 🔵 active | Spark routing 判斷標準寫入 agents/project-pm.md | arch | 2026-05-13 | — |
| CC-009 | 🔵 active | UserPromptSubmit hook 自動 inject MEMORY.md 防止 auto-compact 遺忘 | ux/memory | 2026-05-14 | — |
| CC-010 | 🔵 active | `/memory-compress` 指令：壓縮 MEMORY.md 條目減少 inject token 量 | ux/memory | 2026-05-14 | — |
| CC-011 | ⏸ deferred | sync-memory.sh + install 選項：symlink memory 到雲端資料夾實現跨裝置共用 | ux/memory | 2026-05-14 | — |
| CC-012 | ⏸ deferred | SessionStart hook：session 啟動時 pull 最新 memory（git/rsync）確保跨裝置同步 | ux/memory | 2026-05-14 | — |
| CC-013 | 🔵 active | `/caveman` token 壓縮 skill：lite/full/ultra 模式，長 session 降低 token 消耗 | ux | 2026-05-14 | — |
| CC-014 | 🔵 active | `using-git-worktrees` skill：parallel PR gate 隔離開發環境 | arch | 2026-05-14 | — |
| CC-015 | 🔵 active | `systematic-debugging` skill：結構化偵錯工作流 | ux | 2026-05-14 | — |

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

## CC-006 — `claude-usage.sh` → `token-usage.sh` 改名 + statusLine hook 自動寫入 rate-limits

**Problem**: 腳本現在追蹤 claude / codex / spark 三個 pool，但名稱 `claude-usage.sh` 暗示只追蹤 Claude，產生誤導。同時 `--remaining N` 需手動輸入剩餘 %，而 Claude Code CLI 已透過 statusLine hook stdin 提供即時 `rate_limits` 資料。
**Why**:
- 改名：命名應反映功能範圍。`token-usage.sh` 精確描述「查詢各 pool token 使用量」，與 pool 種類無關。配對邏輯：`log-usage.sh`（寫入）↔ `token-usage.sh`（讀取）。
- rate-limits hook：abtop 的 `abtop-statusline.sh` 示範了取得路徑，但正確做法是 claude-config 自己掛 hook，不依賴 abtop 是否安裝。
**Requirement**:
1. `scripts/claude-usage.sh` → `scripts/token-usage.sh`（更新所有引用：install.sh、install-hooks.sh、uninstall-hooks.sh、test-install.sh、test-usage-tracker.sh、README.md、docs/）
2. `~/.claude/scripts/` symlink 同步更新；`~/.claude/settings.json` 中的路徑更新
3. 新增 `scripts/hook-save-rate-limits.sh`：statusLine hook，讀 stdin JSON → 提取 `rate_limits` → 寫入 `~/.claude/rate-limits.json`
4. `install-hooks.sh` 掛入 StatusLine；`uninstall-hooks.sh` 清除
5. `token-usage.sh --remaining`（無參數）：讀 `~/.claude/rate-limits.json`，自動計算 `100 - five_hour.used_percentage`；`updated_at` 超過 30 分鐘或檔案不存在則警告並退回手動輸入

## CC-007 — brief qa_checklist 指引寫入 docs/codex-brief.md + agents/project-pm.md

**Problem**: PR #40 開發過程中 7 輪 gate 才通過，主因是 brief 列了行為變更但沒預先列出對應測試需求，導致 qa-tester 每輪都 block 追加 coverage。
**Why**: 若 brief 在 `files` 或獨立區塊明確列出「每個新 behavioral unit 需要哪些測試」，codex-executor 第一次就能一起實作，省去多輪 gate + fix 循環。
**Requirement**: 在 `docs/codex-brief.md` 加 `qa_checklist` 選填區塊規範（引入 3+ behavioral units 時必填）；在 `agents/project-pm.md` 加 PM 生成 brief 時的對應指引。

## CC-009 — UserPromptSubmit hook 自動 inject MEMORY.md

**Problem**: Claude Code auto-compact 時只保留對話摘要，`~/.claude/projects/*/memory/` 的檔案雖存在磁碟，但 Claude 因 context 壓縮而可能遺忘 MEMORY.md 的存在或內容，跨 session 記憶斷裂。
**Why**: claude-mem 專案驗證了 UserPromptSubmit hook 是最有效的防遺忘時機（每次用戶輸入前注入，確保 compact 後 memory 仍在 context）。相較 SessionStart hook，UserPromptSubmit 更能對抗 mid-session compact。
**Requirement**:
1. 新增 `scripts/hook-inject-memory.sh`：UserPromptSubmit hook，讀取 `~/.claude/projects/*/memory/MEMORY.md`（比對 cwd 對應的 project），以精簡格式注入 context
2. `install-hooks.sh` 掛入 UserPromptSubmit；`uninstall-hooks.sh` 清除
3. inject 內容限制在 500 tokens 以內（僅 index 行，不含詳細 memory 檔內容）
4. 測試覆蓋：memory 存在時注入、不存在時靜默跳過

## CC-010 — `/memory-compress` 指令：壓縮 MEMORY.md 條目

**Problem**: MEMORY.md 隨時間增長後，CC-009 的 inject token 量會持續上升，最終超過 500 token 上限或使 context 膨脹。
**Why**: claude-mem 的漸進式 token 注入策略 + Caveman 的 `caveman-compress` 概念共同指向：memory 需要定期被摘要壓縮，而非無限累積。
**Requirement**:
1. 新增 `commands/memory-compress.md`：slash command，呼叫壓縮邏輯
2. 對 MEMORY.md 中的每個條目：讀取對應 memory 檔 → 摘要為 1-2 行精華 → 更新 MEMORY.md index 行
3. 壓縮後 MEMORY.md 總長度目標 < 100 行
4. 提供 `--dry-run` 選項預覽壓縮結果，不實際寫入

## CC-011 — sync-memory.sh + install 選項：symlink memory 到雲端資料夾（跨裝置，deferred）

**Problem**: `~/.claude/projects/*/memory/` 為本機路徑，多台電腦之間 memory 各自獨立，無法共用。
**Why**: 用戶目前不急，但設計上若以 symlink 指向 Dropbox/iCloud/OneDrive 資料夾，可以零維護代價實現跨裝置共用，且完全相容現有 file-based memory 架構。
**Requirement**:
1. `scripts/sync-memory.sh`：提供 `--setup <cloud-path>` 選項，把 `~/.claude/projects/` 下的 memory 資料夾 symlink 到指定雲端同步路徑
2. `install.sh` 加入可選步驟（opt-in，詢問是否設定雲端 memory 路徑）
3. 文件說明支援的同步工具（Dropbox、iCloud、OneDrive、Google Drive 本機同步資料夾）
**Note**: 此項 deferred，有實際跨裝置需求時再實作。

## CC-012 — SessionStart hook：pull 最新 memory（deferred）

**Problem**: 若多台電腦透過 CC-011 共用同一雲端 memory 資料夾，session 啟動時不保證已取得最新版本（雲端同步可能有延遲）。
**Why**: AgentMemory 專案的 P2P mesh sync 概念過重；更輕量的方式是 SessionStart hook 觸發一次 `rsync` 或 `git pull`，確保 memory 是最新版。
**Requirement**:
1. 新增 `scripts/hook-sync-memory.sh`：SessionStart hook，若設定了 sync 端點則執行 pull
2. 支援兩種模式：(a) git repo 模式（git pull）、(b) rsync 模式（rsync from remote）
3. 失敗時靜默降級（不阻斷 session 啟動）
**Note**: 此項 deferred，依賴 CC-011 完成後再評估。

## CC-013 — `/caveman` token 壓縮 skill

**Problem**: 長 session 中 Claude 回應冗長，token 消耗快速，尤其在 codex brief 審核、多輪 gate 等場景。
**Why**: Caveman 專案實測降低 65-75% token 用量，架構（slash command + hook）與 claude-config 完全相容。`lite`/`full`/`ultra` 三模式讓用戶依場景調整。
**Requirement**:
1. 新增 `commands/caveman.md`：slash command，切換壓縮模式（off / lite / full / ultra）
2. 模式定義寫入 CLAUDE.md（全域生效）或 project CLAUDE.md（project 生效）
3. 提供 `/caveman-commit` 變體：生成超簡潔 git commit message

## CC-014 — `using-git-worktrees` skill

**Problem**: `--parallel` PR gate 目前各 reviewer 在同一 working tree 執行，reviewer 的寫入（artifact 目錄）可能互相干擾，且無法確保每個 reviewer 看到的是原始狀態。
**Why**: Superpowers 專案的 `using-git-worktrees` skill 示範了如何讓每個 subagent 在獨立 worktree 中工作，避免狀態污染。這直接補強 CC-003 的解法方向。
**Requirement**:
1. 新增 `commands/using-git-worktrees.md`：skill，指導如何在平行開發中使用 git worktree
2. 評估 `--parallel` gate 是否可以為每個 reviewer 建立獨立 worktree（替代方案或 CC-003 的補充）

## CC-015 — `systematic-debugging` skill

**Problem**: debug 工作流目前無標準化流程，每次偵錯方式不一致，容易遺漏根本原因分析。
**Why**: Superpowers 的 `systematic-debugging` skill 提供 RED-GREEN-REFACTOR 以外的結構化偵錯步驟，有助於複雜 bug 分析。
**Requirement**:
1. 新增 `commands/systematic-debugging.md`：slash command，提供結構化偵錯步驟（reproduce → isolate → hypothesize → verify → fix → regression test）

## CC-008 — Spark routing 判斷標準寫入 agents/project-pm.md

**Problem**: PM 派發 codex 任務時，尚無文件說明何時應選 `--model codex-spark` 而非預設 codex。Spark 適合小型、定點修改，但沒有明確標準。
**Why**: 若 PM 自動選 Spark 處理輕量任務，可降低 token 消耗。但錯誤路由（把大任務給 Spark）會導致結果品質下降。
**Requirement**: 在 `agents/project-pm.md` 加 Spark routing 判斷規則：(a) diff 預期 < 50 行、(b) 單一檔案修改、(c) 無跨模組依賴時，優先考慮 Spark；否則走預設 codex。
