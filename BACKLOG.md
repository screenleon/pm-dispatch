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
| CC-006 | ✅ done | statusLine hook 自動寫入 rate-limits，`--remaining` 免手動輸入 | ux | 2026-05-13 | pr:#42 |
| CC-007 | ✅ done | brief qa_checklist 指引寫入 docs/codex-brief.md + agents/project-pm.md | process | 2026-05-13 | pr:#42 |
| CC-008 | ✅ done | Spark routing 判斷標準寫入 agents/project-pm.md | arch | 2026-05-13 | pr:#41 |
| CC-009 | ✅ done | UserPromptSubmit hook 自動 inject MEMORY.md 防止 auto-compact 遺忘 | ux/memory | 2026-05-14 | pr:#44 |
| CC-010 | 🔵 active | `/memory-compress` 指令：壓縮 MEMORY.md 條目減少 inject token 量 | ux/memory | 2026-05-14 | — |
| CC-011 | ⏸ deferred | sync-memory.sh + install 選項：symlink memory 到雲端資料夾實現跨裝置共用 | ux/memory | 2026-05-14 | — |
| CC-012 | ⏸ deferred | SessionStart hook：session 啟動時 pull 最新 memory（git/rsync）確保跨裝置同步 | ux/memory | 2026-05-14 | — |
| CC-013 | 🔵 active | `/caveman` token 壓縮 skill：lite/full/ultra 模式，長 session 降低 token 消耗 | ux | 2026-05-14 | — |
| CC-014 | 🔵 active | `using-git-worktrees` skill：parallel PR gate 隔離開發環境 | arch | 2026-05-14 | — |
| CC-015 | 🔵 active | `systematic-debugging` skill：結構化偵錯工作流 | ux | 2026-05-14 | — |
| CC-016 | ✅ done | gate NO-GO fix-loop 效率：PM brief 撰寫策略（discovery + --targeted + source-first） | process | 2026-05-14 | pr:#43 |
| CC-017 | ✅ done | 前端 UI 實作前置流程：提供圖片時需先讀取確認再 brief | process/ux | 2026-05-14 | pr:#43 |
| CC-018 | 🔵 active | Codex quota 自動追蹤：codex-dispatch 後查詢剩餘 quota 寫入 rate-limits-codex.json | ux/token | 2026-05-14 | — |
| CC-019 | 🔵 active | Episodic memory 層：Stop hook metadata + `/mem-log` + `/mem-recall` + `/mem-distill` | ux/memory | 2026-05-14 | — |
| CC-020 | 🔵 active | `/mem-search`：`rg` 關鍵字過濾 + Claude 語意理解，跨 memory 檔搜尋 | ux/memory | 2026-05-14 | — |
| CC-021 | 🔵 active | test scripts 支援 `--filter <pattern>` + `--list` 只跑/列出名稱匹配的 test case | ops/test | 2026-05-14 | — |

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
1. 新增 `scripts/hook-inject-memory.sh`：UserPromptSubmit hook，讀取 `~/.claude/projects/*/memory/MEMORY.md`（比對 cwd 對應的 project），注入 index 行到 context
2. `install-hooks.sh` 掛入 UserPromptSubmit；`uninstall-hooks.sh` 清除
3. **設計決策（2026-05-14）**：inject 永遠完整注入 index，不截斷。截斷會造成 Claude 遺失部分記憶規則，比 token 多花費更危險。當 index ≥ 50 條時，在 inject 末尾加入 directive 指示 Claude 在回覆前執行 `/memory-compress`，由 Claude 在 LLM 語意層做壓縮，而非 hook 靜默截斷。
4. 測試覆蓋：memory 存在時注入全部 index 行、不存在時靜默跳過、≥50 條時出現 `/memory-compress` directive

## CC-010 — `/memory-compress` 指令：壓縮 MEMORY.md 條目

**Problem**: MEMORY.md 隨時間增長後，CC-009 的 inject token 量持續上升；≥50 條時 hook 發出 directive，但 `/memory-compress` 指令本身不存在，directive 無從執行。
**Why**: claude-mem 的漸進式 token 注入策略 + Caveman 的 `caveman-compress` 概念共同指向：memory 需要定期被摘要壓縮，而非無限累積。

**設計決策（2026-05-14）**:
- 純 slash command（`commands/memory-compress.md`），邏輯完全由 Claude 執行，不需 shell script
- `$ARGUMENTS` 接收 `--dry-run` flag；dry-run 時只 print diff，不寫入任何檔案

**Requirement**:
1. 新增 `commands/memory-compress.md`：slash command，包含以下 Claude 指令：
   - Read MEMORY.md → 列出所有 `- [Title](file.md) — hook` 條目
   - 對每個條目 Read 對應 .md 檔
   - 壓縮 hook 行（目標 ≤ 15 words、≤ 150 chars）：保留最核心規則，移除冗餘描述
   - 合併主題重疊的條目（e.g., 3 個 codex-dispatch feedback → 1 條）
   - 標記疑似過時條目（引用不存在的函式/路徑）→ 列出供用戶確認再刪
   - 重寫 MEMORY.md；`--dry-run` 則只顯示 before/after diff
2. 壓縮目標：index 行數 < 50（對應 CC-009 threshold）、總字數減少 ≥ 30%
3. 每個 `[[name]]` cross-link 仍然有效（壓縮時不刪除 slug）

**測試**：不需要 shell test（slash command = markdown 指令，無殼層邏輯）。
**工作量**：Small（1 個 .md 檔，~80 行）。
**依賴**：CC-009 ✅。

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

## CC-016 — gate NO-GO fix-loop 效率：PM brief 撰寫策略

**Problem**: JapanJob fix/residence-location-backfill 分支跑了 4 輪 gate 才通過，原因是 main thread 寫 fix brief 時：
(1) 沒有先讀原始碼確認 diff 範圍，只靠 gate 報告文字；
(2) gate round 1 泛指「缺測試」，但沒枚舉所有 call sites，brief 只補了明確點名的地方；
(3) 確認修復時跑完整 5-reviewer full gate，浪費 token；
(4) gate 報告被當作「完整清單」而非「最少清單」。

**Why**: gate reviewer 的枚舉深度是漸進的——第一輪只能報最明顯的缺口，第二輪看到測試後才能逐函式比對。PM brief 寫作策略若不補 discovery 步驟，就必然產生多輪循環。這是工具層（claude-config PM agent）的流程問題，不是個別 repo 的業務規則問題。

**Requirement**: 在 `agents/project-pm.md` 的「gate NO-GO 後撰寫 fix brief」區塊加入下列規則：

1. **Source-first**：收到 NO-GO 後，先讀 diff 範圍內的相關原始碼，再寫 brief；不可只靠 gate 報告文字推斷範圍。

2. **Discovery 步驟**：若 gate 報告提到新加入的 helper 函式，brief 必須要求 codex 先 `grep` 所有 call sites，對每個 call site 補對應測試，而非只測試 gate 明確點名的位置。

3. **--targeted 重跑**：gate NO-GO 已知問題分類（只剩 qa-tester block、只剩 risk-reviewer block 等）時，重跑用 `--targeted <reviewers>`，不跑完整 full tier。full tier 只用於首輪或問題分類不明確時。

4. **「最少清單」原則**：把 gate round 1 的報告視為「至少需要修的清單」，而非「所有需要修的完整清單」。在 brief 中加入「找出所有類似情境」的 discovery 指令，避免 round 2 gate 發現相同類型的新問題。

**影響文件**: `agents/project-pm.md`（主要）、`commands/pr-gate.md`（--targeted 使用時機說明）。

---

## CC-008 — Spark routing 判斷標準寫入 agents/project-pm.md

**Problem**: PM 派發 codex 任務時，尚無文件說明何時應選 `--model codex-spark` 而非預設 codex。Spark 適合小型、定點修改，但沒有明確標準。
**Why**: 若 PM 自動選 Spark 處理輕量任務，可降低 token 消耗。但錯誤路由（把大任務給 Spark）會導致結果品質下降。
**Requirement**: 在 `agents/project-pm.md` 加 Spark routing 判斷規則：(a) diff 預期 < 50 行、(b) 單一檔案修改、(c) 無跨模組依賴時，優先考慮 Spark；否則走預設 codex。


## CC-017 — 前端 UI 實作前置流程：提供圖片時需先讀取確認再 brief

**Problem**: 當使用者提供 UI 設計圖（截圖、wireframe、mockup）要求實作前端畫面時，PM 或 Claude 直接進入 brief 撰寫或 codex 派發，沒有先確認畫面的互動細節、元件狀態、響應式行為等，導致實作完才發現方向偏差，需要大幅返工。

**Why**: UI 畫面的「看起來像」和「實際行為一致」之間有大量隱性規格：
- hover / focus / active 狀態是否要特別處理
- 資料載入中、空狀態、錯誤狀態如何呈現
- RWD breakpoint 行為（圖片通常只有一個螢幕尺寸）
- 動畫 / transition 有無
- 元件邊界（哪些是共用元件、哪些是 one-off）
- 顏色/字型/間距的精確 token 對應

不先釐清這些，codex 會做出「外觀像但行為差很多」的實作，後續修改成本遠高於事前討論。

**Requirement**: 在 `agents/project-pm.md` 加入前端 UI 實作前置規則：

1. **圖片讀取確認**：收到含圖片的前端實作請求時，PM 必須先用 Read tool 讀取圖片，然後向使用者列出從圖片可辨識的元件清單與行為假設，請使用者確認或補充。

2. **必問清單**（每次 UI 實作 brief 前都要確認）：
   - 互動狀態：hover / focus / disabled / loading / empty / error 狀態的呈現方式
   - 響應式：目標螢幕尺寸，圖片以外的 breakpoint 行為
   - 動態行為：有無 transition / animation，行為觸發時機
   - 元件邊界：哪些元件應該是 reusable，哪些是 page-specific
   - Design token 對應：顏色、字型、間距是否有現有 token 可對應

3. **Brief 鎖定**：確認完成前不得開始寫 codex brief；使用者回覆後，將確認內容摘要為 brief 的 `context` 區塊，讓 codex 知道設計決策已經定案。

**影響文件**: `agents/project-pm.md`（加入 UI 實作前置流程規則）。

## CC-018 — Codex quota 自動追蹤：codex-dispatch 後查詢剩餘 quota

**Problem**: CC-006 透過 StatusLine hook 解決了 Claude 5h rate-limit 的自動讀取，但 Codex（codex-executor）並無等效的 hook 機制——沒有 stdin 事件，也沒有 rate_limits 欄位可掛。目前 Codex 使用量只靠 `log-usage.sh` 手動寫入 usage-tracker.jsonl，用戶無法即時得知 Codex pool 剩餘額度，只能進 dashboard 查。

**Why**: Claude 的 rate_limits 透過 StatusLine hook 由 Claude Code 推送，是 CLI 設計。Codex 走 OpenAI API 路徑，quota 資訊需要主動 API 查詢（`/v1/organization/usage` 或 response header `x-ratelimit-remaining-tokens`），架構不同。若能在 `codex-dispatch.sh` 派發後自動讀 response header 或週期性 API 查詢，就能補齊這個資訊缺口，讓 `token-usage.sh --remaining` 對 Codex pool 也有資料可用。

**Requirement**:
1. 研究 Codex API response headers：確認是否回傳 `x-ratelimit-remaining-requests` / `x-ratelimit-remaining-tokens`（類似 OpenAI standard headers）
2. 若有：在 `scripts/codex-dispatch.sh` 中，dispatch 後解析 response headers，將 Codex 剩餘 quota 寫入 `~/.claude/rate-limits-codex.json`（格式與 rate-limits.json 對齊：`{ "updated_at": ..., "remaining_tokens": ..., "reset_at": ... }`）
3. 若無（Codex 走 batch/async 路徑不回傳即時 quota）：改為在 dispatch 後呼叫 `/v1/organization/usage` 查詢，或記錄「目前技術限制，無法自動取得」供日後重評估
4. `token-usage.sh` 加入 Codex pool 剩餘顯示（讀 rate-limits-codex.json）
5. 測試覆蓋：header 存在時寫入、header 缺失時靜默跳過、json 格式正確

**注意**: 實作前需先驗證 Codex API 的 rate-limit header 行為，若 API 不支援，此項可能降為 documentation-only（記錄技術限制）。CC-008 Spark routing 實作時需同步確認 Spark 是否有獨立 quota endpoint。

## CC-019 — Episodic memory 層：session 摘要 + `/mem-recall` + `/mem-distill`

**Problem**: 目前 memory 系統只有一層（MEMORY.md flat index），缺乏跨 session 的事件歷史。對話結束後，這個 session 發生了什麼、解決了什麼問題、做了什麼決策，都會消失在 auto-compact 中。

**Why**: 認知科學架構（CoALA / agentmemory）和 claude-mem 都驗證了 episodic layer 的價值：把每個 session 壓縮成 3-5 行摘要，比試圖在 MEMORY.md 裡記錄所有細節更有效率。Session 歷史可以按需注入（`/mem-recall`），也可以定期整合提升 MEMORY.md 品質（`/mem-distill`）。

**Requirement**:
1. 新增 `scripts/hook-session-summary.sh`：Stop hook，session 結束時記錄 metadata-only skeleton entry（`{"date":"...","cwd":"...","session_id":"...","summary":""}`）到 `episodes.jsonl`；語意摘要由使用者主動執行 `/mem-log` 填入
2. 新增 `commands/mem-log.md`：slash command，session 期間由使用者呼叫，讓 Claude 生成 3-5 行摘要並寫入 episodes.jsonl；Stop hook 在 /mem-log 已執行時自動跳過
3. 新增 `commands/mem-recall.md`：slash command，讀取最近 N 個 episode 注入 context（預設 5）
4. 新增 `commands/mem-distill.md`：slash command，讓 Claude 讀取最近 10 個 episodes，對照現有 MEMORY.md，更新/新增/移除條目，提供 dry-run 預覽
5. `install-hooks.sh` / `uninstall-hooks.sh` 掛入 Stop hook（與現有 `hook-log-claude-usage.sh` 並行）
6. 測試覆蓋：episodes.jsonl 正確 append、格式驗證、/mem-recall 注入格式、Stop hook 在 /mem-log 先跑後不重複寫入

**設計決策**:
- Stop hook metadata-only（無 LLM 呼叫）：session 結束時零成本記錄；語意摘要由使用者在 session 活躍時呼叫 /mem-log 取得
- episodes.jsonl 只 append，不覆寫：歷史不可刪除，壓縮靠 /mem-distill
- /mem-distill 有 --dry-run：讓用戶看到要改什麼再確認
- inject hook 在 >24h 無記錄時顯示 💡 提示，引導使用者執行 /mem-log

**依賴**: CC-009（UserPromptSubmit hook）已完成，episodic 層是自然延伸。

## CC-020 — `/mem-search`：跨 memory 檔語意搜尋

**Problem**: 隨著 memory 檔數量增加，「我之前記過關於 X 的東西嗎？」這類問題需要手動翻 MEMORY.md 再 Read 個別檔案，效率低。

**Why**: `rg`（ripgrep）可以在毫秒內掃遍所有 memory 檔做關鍵字過濾，Claude 再對結果做語意理解。這個組合在目前規模（< 50 個 memory 檔）完全夠用，不需要向量資料庫或 BM25。等規模真正成長時（200+ 筆）再評估本地 embedding（`sentence-transformers`）。

**Requirement**:
1. 新增 `commands/mem-search.md`：slash command，用法 `/mem-search <query>`
2. 執行邏輯：
   - `rg -l "<query>" ~/.claude/projects/*/memory/` → 找出包含關鍵字的 memory 檔
   - 若有結果：Claude Read 這些檔案 → 語意理解 → 回答
   - 若無結果：Claude 看 MEMORY.md index → 判斷語意相關條目 → Read 那些檔 → 回答
3. 輸出格式：列出命中的 memory 條目 + 相關摘要，說明「記憶來源」
4. 無需測試腳本（slash command 為 markdown，邏輯在 Claude 端執行）

**設計決策**:
- 搜尋工具選 `rg` 而非 BM25：corpus 小（< 50 檔），rg 速度和準確度已足夠，不需要排名演算法
- 語意理解靠 Claude：不需要 embedding API 或外部模型
- 未來擴展路徑：規模 > 200 筆時考慮 `sentence-transformers` 本地 embedding

**依賴**: CC-009（memory 結構穩定）、CC-019（episodic 層建立後 /mem-search 也能搜尋 episodes）。

## CC-021 — test scripts 支援 `--filter <pattern>` 只跑匹配的 test case

**Problem**: 每次 gate NO-GO 後加入 1-2 個 test case，驗證時仍需跑整套測試（例如 `scripts/test-hooks.sh` 233 tests、`scripts/test-install.sh` 23 tests），即使被改動的只有 1 個函式。這造成不必要的等待，也讓「是否真的只有新測試受影響」變得不可見。

**Why**: 目前 test scripts 把所有 test function 依序呼叫，沒有 filter 機制。當 gate 要求「只補 inject-hook/default-home-fallback 這條測試」，最小驗證路徑應該是只跑那一個 case，而非整個 suite。fix-loop 每輪多跑 200+ 無關 tests 累積浪費明顯。

**Requirement**:
1. `scripts/test-hooks.sh` 和 `scripts/test-install.sh` 支援 `--filter <pattern>` 選項：只執行 case name 包含 `<pattern>` 的 test function（用 `[[ "$name" == *"$FILTER"* ]]` 做字串比對即可，不需 regex）
2. 無 `--filter` 時行為不變，仍跑全部
3. `--filter` 下 `PASS/FAIL` 計數只統計實際跑的 case，輸出格式不變
4. 加入 `--list` 選項：列出所有 test case 名稱，方便查詢 pattern（`printf '%s\n' "${ALL_CASES[@]}"`）
5. gate re-run 文件（`docs/pr-gate-flow.md` 或 `commands/pr-gate.md`）加入說明：gate fix 後本地驗證時，可用 `--filter <changed-area>` 最小化執行範圍；完整 suite 仍需在 gate 中跑

**實作方向**:
- 各 test function 開頭已有 `local name="<case-name>"` 變數，只需在 `PASS++/FAIL++` 前加 `[[ -z "$FILTER" || "$name" == *"$FILTER"* ]] || return` 即可 skip
- 或改為先收集 case list 再 dispatch，兩種方式都行

**影響文件**: `scripts/test-hooks.sh`、`scripts/test-install.sh`（主要）；`commands/pr-gate.md` 或 `docs/` 文件說明（次要）。
