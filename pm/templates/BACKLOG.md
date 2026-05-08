<!-- pm-schema: v1 -->
# <repo-name> backlog

<!--
本檔為 pm-schema v1 模板。新 repo 採用流程：
1. 複製本檔至 repo root，命名為 BACKLOG.md
2. 把 <repo-name> 換成 repo 名稱（例：japanese-site）
3. 確認 ID PREFIX（例：JS / JJ / MN），寫入下方 ID 規則註解
4. 刪除本段 HTML 註解後即可使用
schema 全文：~/.claude/.pm/schema.md
-->

<!--
ID PREFIX: <PREFIX>   （例：JS for japanese-site）
ID 規則：永久穩定，永不重用、永不重排。新增取「目前最大號 + 1」。
-->

## Index

| #  | Status | 主題 | 影響面 | 首次記錄 | Refs |
|----|--------|------|--------|----------|------|
| <PREFIX>-001 | 🔵 active | <6–12 字標題> | backend | YYYY-MM-DD | — |

<!--
Status enum（僅三值）：
  🔵 active
  ✅ closed YYYY-MM-DD
  🚫 dropped YYYY-MM-DD
影響面：backend / frontend / content / ops / arch / product 之一或斜線複合
索引必須與下方 body 一一對應，順序按 ID 升冪。
-->

---

## <PREFIX>-001 — <主題與索引一致>

**Problem**: <現象，使用者或開發者觀察到什麼>
**Why**: <根因；既有設計在哪個假設下成立、為何現在不成立>
**Requirement**: <可驗證的成果條件，不寫實作>

<!--
暫態（doing / blocked / 進度筆記）以下列格式追加，最多保留最近 3 條：

**Status note (YYYY-MM-DD)**: <短句，例：blocked on upstream API change>

closed / dropped 條目折疊為 stub：

## <PREFIX>-NNN — <主題> ✅ YYYY-MM-DD

**Outcome**: <一句結果>
**See**: DECISIONS.md#YYYY-MM-DD-<slug>

dropped 同樣折疊，標題改 🚫，See 仍指 DECISIONS（解釋為何不做）。
-->
