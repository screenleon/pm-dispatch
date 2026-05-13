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

## CC-008 — Spark routing 判斷標準寫入 agents/project-pm.md

**Problem**: PM 派發 codex 任務時，尚無文件說明何時應選 `--model codex-spark` 而非預設 codex。Spark 適合小型、定點修改，但沒有明確標準。
**Why**: 若 PM 自動選 Spark 處理輕量任務，可降低 token 消耗。但錯誤路由（把大任務給 Spark）會導致結果品質下降。
**Requirement**: 在 `agents/project-pm.md` 加 Spark routing 判斷規則：(a) diff 預期 < 50 行、(b) 單一檔案修改、(c) 無跨模組依賴時，優先考慮 Spark；否則走預設 codex。
