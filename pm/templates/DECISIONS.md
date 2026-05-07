# <repo-name> decisions

<!--
本檔為 pm-schema v1 模板。新 repo 採用流程：
1. 複製本檔至 repo root，命名為 DECISIONS.md（若已存在 DECISIONS.md，沿用既有，不覆寫）
2. 把 <repo-name> 換成 repo 名稱
3. 刪除本段 HTML 註解
schema 全文：~/github/.pm/schema.md

排序：按日期倒序（最新在上）。
H2 標題格式：## YYYY-MM-DD: <短描述>
每筆必含四節：Context / Decision / Alternatives considered / Constraints introduced
與 BACKLOG closure 對應的 entry，內文首行寫：Closes: BACKLOG.md#<PREFIX>-NNN
純跨切面決策（無 backlog 對應）允許 standalone，但需在 Context 解釋為何不掛 backlog。
不歸檔（決策不過期）。
-->

## YYYY-MM-DD: <短描述>

Closes: BACKLOG.md#<PREFIX>-NNN

### Context

<為什麼要做這個決策；觸發事件、現況限制、相關 backlog 條目。>

### Decision

<選了什麼。一段話講清楚「做什麼」，不寫實作細節。>

### Alternatives considered

- <選項 A> — <為何沒選>
- <選項 B> — <為何沒選>

### Constraints introduced

<這個決策對未來工作加了哪些硬性限制？哪些東西從此不准做？哪些假設被固化？>

---

<!--
範例（standalone 跨切面決策，不掛 backlog）：

## 2026-04-15: Adopt pm-schema v1 across managed repos

### Context

Multiple repos under ~/github/ 各自演化 BACKLOG / DECISIONS 格式，PM agent 解析成本高。
此決策不掛單一 repo backlog —— 是 cross-cutting，本身就由 ~/github/.pm/DECISIONS.md 承載。

### Decision

採用 pm-schema v1，schema 文件位於 ~/github/.pm/schema.md。
受管 repo BACKLOG.md 頂部以 <!-- pm-schema: v1 --> 宣告版本。

### Alternatives considered

- 維持各 repo 自由格式 — PM agent 解析負擔過重，無法 rollup
- 直接走 GitHub Issues — 跨 repo aggregation 仍需手寫工具，且離本機 IDE workflow 太遠

### Constraints introduced

- 新增受管 repo 必須採 schema；schema 升級需逐 repo 遷移
- BACKLOG.md 三層結構（Problem/Why/Requirement）禁止寫實作細節
- closure stub 必須指 DECISIONS，避免雙真理
-->
