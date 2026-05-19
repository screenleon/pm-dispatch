# pm-dispatch decisions

<!--
排序：按日期倒序（最新在上）。
H2 標題格式：## YYYY-MM-DD: <短描述>
每筆必含四節：Context / Decision / Alternatives considered / Constraints introduced
與 BACKLOG closure 對應的 entry，內文首行寫：Closes: BACKLOG.md#<PREFIX>-NNN
-->

## 2026-05-19: Deprecate ID-gap convention

Closes: BACKLOG.md#CC-067

### Context

pm-schema v1.1（CC-052，PR #93）在 BACKLOG index table 引入顯式 `epic` 欄位（`oss` / `reuse-debt` / `hygiene` / `—`），提供機器可讀的分組依據。在此之前，pm-dispatch BACKLOG 以 ID 保留範圍慣例（CC-1NN = OSS epic、CC-2NN = reuse-debt）作為語義分組 workaround。隨著 ticket 數量自然增長至 CC-100 以上，流水號與保留範圍的邊界衝突將成為現實問題。

### Decision

廢棄 ID gap 慣例。從此以後 `epic` 欄位是唯一權威分組訊號；新增 ticket 統一以「目前最大號 + 1」遞增，不再為語義分組跳號或保留 ID 空間。既有 CC-1NN/CC-2NN 的 ticket ID 維持不動（歷史穩定）。`pm/schema.md §2.4.5` 和 BACKLOG.md Convention 章節移除 ID gap 文件說明。

### Alternatives considered

- 維持 ID gap 慣例 — 隨著 ticket 數量增長，合法流水號將進入「保留」範圍，製造歧義；且 `epic` 欄已提供更好的替代。
- 重排既有 ID（將 CC-1NN/CC-2NN 重編） — 違反 ID 永久穩定原則，git history 引用也需同步更新，成本高風險大。

### Constraints introduced

- 新增 ticket 不可為語義分組跳號或保留 ID 空間；`epic` 欄位是唯一分組機制。
- 若未來需要新增 epic 類型，依 `pm/schema.md §2.4.5` 規定更新 schema 並 bump patch version。
