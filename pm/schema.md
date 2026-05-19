# pm-schema: v1.1

Cross-repo planning convention for `~/github/*` managed product repos.
Canonical path: `~/github/pm-dispatch/pm/schema.md`. `~/.claude/.pm/schema.md` is a symlink alias maintained by `pm-dispatch/install.sh`.

## 1. 檔案佈局

每個受管 repo（active product repo）在 repo root 持有：

- `BACKLOG.md` — 工作條目單一真理（active + 近期 closed stub）
- `DECISIONS.md` — 已沉澱的設計決策日誌（既有檔案沿用）
- `BACKLOG-ARCHIVE.md` — 歸檔倉，僅在膨脹政策觸發時建立

跨 repo 或 cross-cutting 的決策放 `~/.claude/.pm/DECISIONS.md`（自身），不汙染個別 repo 的 DECISIONS.md。

`~/.claude/.pm/` 角色：schema 中央控制點 + cross-repo decisions + 共用 templates / scripts（後續 D2/D3 才產出）。它**不**集中聚合各 repo 的 backlog；rollup 由 read-only 工具產生。

## 2. BACKLOG.md 結構

### 2.1 頂部 metadata

```
<!-- pm-schema: v1.1 -->
# <repo-name> backlog
```

### 2.2 ID 規則

- 條目編號 `<PREFIX>-NNN`，PREFIX 為 repo 縮寫（例：`PA` for project-alpha, `PB` for project-beta）。
- ID 永久穩定：**永不重用、永不重排**。新增固定取「目前最大號 + 1」。
- closed / dropped 條目保留 ID，狀態欄變更，body 折疊。

### 2.3 Status enum

八個可接受 status token：

- `🔵 active` — 仍在 backlog，包含尚未開工 / 進行中 / 阻塞中（細節寫在 body）
- `✅ closed YYYY-MM-DD` — 已 ship，body 折疊為 closed stub（§2.6）
- `🚫 dropped YYYY-MM-DD` — 不做了，body 折疊為 stub 並指向 DECISIONS
- `✅ done` — **soft-close**：已完成但不需要 PR 追蹤或具體日期的項目（例：文件新增、config 設定）。body 保持 active 格式（Problem/Why/Requirement），不需折疊為 stub；不需要 `See:` 引用。
- `⏸ deferred` — **延後**：不是不做，而是等待外部條件（依賴項、時機）再推進。body 保持 active 格式；與 `🔵 active` 的差異是「現在刻意不排程」。
- `🟡 deferred` — **明確延後（alternate）**：`⏸ deferred` 的同義視覺變體；語義相同，validator 兩者皆接受。
- `🟢 someday` — **有朝一日**：概念有效但優先級極低、暫無預期排程；不等外部條件，只是「未來某天再做」。
- `⚠️ partial YYYY-MM-DD` — **部分完成**：本條目主體已 ship，但仍有 sub-items 尚未完成（見 body 說明）。body 保持 active 格式；`YYYY-MM-DD` 為首批交付日期。

不再使用 `todo / doing / done / blocked` 等舊四態；`doing / blocked` 屬於 active 內的暫態，記在 body。

### 2.4 索引 table

緊接在標題之後，欄位固定：

| #  | Status | 主題 | 影響面 | 首次記錄 | Refs | Priority | Epic |
|----|--------|------|--------|----------|------|----------|------|

- **#**：條目 ID
- **Status**：上述可接受 token 之一
- **主題**：6–12 字標題
- **影響面**：見下方 area enum；單值或斜線複合
- **首次記錄**：`YYYY-MM-DD`，fallback 順序見下
- **Refs**：結構化引用，語法見 §2.4.3；空則 `—`
- **Priority**：`P1` / `P2` / `P3` / `—`（優先度；未設為 `—`）。向下相容：v1.1 file 中缺此欄的列 emit W-MISSING-COLS。
- **Epic**：`oss` / `reuse-debt` / `hygiene` / `—`（語義分組；空則 `—`）。詳見 §2.4.5。

索引必須與 body 條目一一對應，順序按 ID 升冪。

#### 2.4.1 area enum

固定值（單一或以 `/` 複合，最多 2 段）：

**Layer tokens**（系統分層）：
`arch / backend / frontend / content / ops / connector / DX / product`

**Topic tokens**（工具層 / 影響面）：
`ux / process / memory / token / test / gate`

- `ux` — 使用者操作體驗、developer ergonomics
- `process` — 開發流程、工作流、PM 規範
- `memory` — 跨 session 記憶層（episodic / semantic memory）
- `token` — token 用量追蹤、quota 管理
- `test` — 測試基礎設施、test runner、fixture
- `gate` — PR gate 工具、reviewer 流程

Topic tokens 可與 layer tokens 複合（例：`ux/memory`、`ops/test`、`ops/gate`）。純 topic 也合法（例：`process`、`ux`）。

Alias（寫入時自動正規化，PM agent 解析時容錯）：`architecture` → `arch`、`operations` → `ops`、`con` → `connector`。未列入的詞先討論擴 enum，不可自由發明。

#### 2.4.2 「首次記錄」fallback

理想值是條目首次寫入 BACKLOG 的日期。當遷移 / 補登時無此資訊，依序 fallback：

1. 若已 closed，用 `completed_at`（與 closed 標記日期同源）
2. 否則取條目最早的 `Status note` 日期
3. 都沒有時用 migration 當日，並在 body 末尾加 `<!-- 首次記錄: backfilled YYYY-MM-DD -->` 註解標出

#### 2.4.3 Refs 結構化語法

每筆引用 `prefix:target`。v1 封閉前綴：

- `decisions:#anchor` — 同 repo `DECISIONS.md` H2 anchor
- `roadmap:#anchor` — 同 repo `ROADMAP.md` anchor
- `pr:#NNN` 或 `pr:owner/repo#NNN` — GitHub PR（跨 repo 加 `owner/repo`）
- `commit:<sha7>` — 7 位 commit SHA
- `feedback:YYYY-MM-DD` — user feedback 日期

多筆：index 欄以 `, ` 分隔，≤ 3 條；溢出寫 body `**Refs**:` 行（見 §2.5）。缺值 `—`。未列前綴一律不接受；新類型先升 schema。

#### 2.4.4 Priority enum

`P1`（本週必做）/ `P2`（本 sprint 內）/ `P3`（backlog 中排隊）/ `—`（未設定）。

#### 2.4.5 Epic enum

`oss`（CC-OSS 公開源碼系列）/ `reuse-debt`（技術債重用）/ `hygiene`（流程/schema 維護）/ `—`（未分組）。
新 repo 可以擴充此 enum；擴充需同步更新 `pm/schema.md` 並 bump patch version。

### 2.5 條目 body 三層格式

每個 active 條目 body 固定三節 Problem / Why / Requirement，**只寫到這三層為止**。後接可選的 `Tags` 行與溢出用的 `Refs` 行：

```
## JS-013 — 語料儲存格式重評

**Problem**: <現象，使用者或開發者觀察到什麼>
**Why**: <根因；既有設計在哪個假設下成立、為何現在不成立>
**Requirement**: <可驗證的成果條件，不寫實作>
**Tags**: P1, M4
**Refs**: pr:#42, feedback:2026-04-30
```

- `Tags`：放 `priority` / `milestone` 等次要維度。寫法 `P{1-3}` / `M{n}`；多個以 `, ` 分隔；無則整行省略（不寫 `—`）。priority 已有專屬 index 欄（§2.4.4）；milestone 仍僅在 Tags 行。
  - **Variant — closed-enum milestone + theme axis**：採用 repo 可改以封閉 enum（如 `{M1, M3, M4, DX}`）約束 `milestone:`，並另加 sibling `theme:` 欄位承載 topic / content 軸（free-form lowercase-kebab-case，single token，ASCII）。此變體下 `milestone:` 在無 release commitment 時整行省略；`theme:` 開放擴充、不需 schema bump。project-alpha 於 2026-05-07 採用此模式（含 yml-level validator），參考 `../project-alpha/DECISIONS.md#2026-05-07-pm-schema-v1-milestone-theme-split`。
- `Refs`：僅在 index 欄已塞滿（>3 條）或需註記非主要引用時出現；語法同 §2.4.3。索引欄裡的 ref 不必在 body 重複。
- **不寫實作細節**：不指定具體欄位、API 路徑、檔案改動方式。實作走 codex 的 brief，brief 是 ephemeral，不入 BACKLOG。
- 暫態（doing / blocked / 進度筆記）以單獨 `**Status note (YYYY-MM-DD)**:` 行追加，最多保留最近 3 條，更舊的併入或刪除。

### 2.6 Closed / dropped stub

closed 條目有兩種折疊形式：

**DECISIONS-backed stub**（預設）：outcome 已沉澱到 DECISIONS.md 時使用。

```
## JS-008 — Japanese-first 文法解釋契約 ✅ 2026-04-30

**Outcome**: <一句結果>
**See**: DECISIONS.md#2026-04-30-japanese-first-explanations-with-chinese-reveal
```

**Archive-backed stub**（膨脹觸發後的批量歸檔）：完整 prose 已移至 `BACKLOG-ARCHIVE.md` 時使用；只需 `**See**:` 指標，無需 `**Outcome**`。

```
## CC-NNN — title ✅ 2026-05-18

**See**: BACKLOG-ARCHIVE.md
```

`Why / Requirement` 兩種形式均不保留，避免雙真理。

### 2.7 Code TODO 追蹤條目（optional pattern）

允許但不強制：將 repo 內的 `// TODO(PA-NNN):` 註解綁到一個 backlog 條目，作為「程式碼欠帳的單一聚集點」。沿用 project-beta #10 風格：

- 條目主題寫「Code TODO 追蹤」
- body Requirement 列出當前所有掛 ID 的 TODO 位置
- 解決一個就從清單刪除，整批清完再 close

不採用此 pattern 的 repo 直接忽略。

## 3. DECISIONS.md 結構

沿用既有格式，只硬性約束以下：

- 按日期**倒序**（最新在上）。
- 每筆 entry 的 H2 標題格式：`## YYYY-MM-DD: <短描述>`
- 內容必含：**Context / Decision / Alternatives considered / Constraints introduced** 四節（既有 project-alpha DECISIONS.md 已是此模式）。
- 與 BACKLOG closure 對應的 entry 在內文首行寫 `Closes: BACKLOG.md#JS-NNN`。
- 純跨切面決策（無 backlog 對應）允許 standalone，但需在 Context 解釋為何不掛 backlog。

## 4. 檔案膨脹政策

對 BACKLOG.md：

- 行數 > 500 **或** closed/dropped 條目佔比 > 50% 時，觸發歸檔。
- 歸檔動作：將 closed/dropped 條目的 body section 整段移至 `BACKLOG-ARCHIVE.md`；在 BACKLOG.md 原位留下 **closed stub**（heading 含 `✅ YYYY-MM-DD` 或 `🚫 YYYY-MM-DD`，加 `**See**: BACKLOG-ARCHIVE.md` 指標）；index row 保留、不移除。
- BACKLOG.md 永遠保留 index table 及 closed stubs，方便一眼掃描所有條目的狀態；完整歷史在 `BACKLOG-ARCHIVE.md`。
- DECISIONS.md 不歸檔（決策不過期）。

## 5. 跨 repo 採用規則

- **採用**：active product repo（current: project-alpha, project-beta, project-gamma 等有持續開發的 repo）。
- **跳過**：純 sandbox / 一次性實驗 / 純內容 repo（看個案決定）。
- 採用時 BACKLOG.md 頂部必須有 `<!-- pm-schema: v1.1 -->`（v1.1 為當前版本；v1 file 仍被 validator 接受，但不驗證新欄），否則 PM agent 視為未採用、不解析。
- schema 升級（v2 等）時，`.pm/schema.md` bump 版本，受管 repo 逐個遷移；混用版本期間 PM agent 依個別檔頂部宣告解析。

## 6. 與 PM agent 互動契約

### 6.1 讀取順序

PM agent 讀 backlog 時：

1. 先解析 index table → 取得條目清單與 status 概覽。
2. 僅在需要 body 時才解析該條目段落（按 H2 anchor 定位）。
3. 不依賴 body 中的非結構化敘述做狀態判斷；status 唯一來源是 index table 的 Status 欄。

### 6.2 寫入紀律

新增條目：

1. 讀 index table 取最大號，+1 為新 ID。
2. 在 index table 末端追加列。
3. 在 body 區尾端追加三層段落。
4. 兩處同一 commit / 同一 write 必須一起更新。

狀態變更（active → closed/dropped）：

1. 更新 index Status 欄。
2. 替換 body 為 stub（保留 H2 標題與 ID）。
3. 若有對應 DECISIONS entry，stub 內 `See:` 必填。

進度筆記（status note）：

1. 只動該條目 body，不動 index。
2. 追加而非取代；超過 3 條時刪最舊。

### 6.3 並寫衝突避免

- PM agent 每次寫入只動**單一條目 block**（H2 段落 + 對應 index 列）；不要在同一次寫入跨多個無關條目。
- 多 agent 並行時，靠 git commit 粒度避免衝突；若必須改多條目，分多次 commit。
- index table 是熱點：寫入前先讀整張 table，產生 diff，避免 stale overwrite。

## 7. 不在 schema 範圍內的事

- 工具腳本（rollup / lint）— 後續 D2/D3 工作項。
- BACKLOG ↔ codex brief 的橋接格式 — 由 PM agent 自行決定，brief 仍是 ephemeral。
- IDE / 編輯器整合 — 不假設。
