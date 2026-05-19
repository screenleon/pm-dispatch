# pm-dispatch decisions

<!--
排序：按日期倒序（最新在上）。
H2 標題格式：## YYYY-MM-DD: <短描述>
每筆必含四節：Context / Decision / Alternatives considered / Constraints introduced
與 BACKLOG closure 對應的 entry，內文首行寫：Closes: BACKLOG.md#<PREFIX>-NNN
-->

## 2026-05-19: cc030-validate-bidirectional

Closes: BACKLOG.md#CC-030

### Context

validate.sh 原本只做 Index→Body 的單向一致性檢查（index row 有對應 body section 才合法）。
Body→Index 方向（孤立 section 沒有 index row）、closure date 對齊（E-CLOSURE-DATE-MISMATCH）、以及 CHANGELOG drift（E-CHANGELOG-DRIFT）均已在 PR #93（CC-052）前後陸續實作。

CC-030 的目標是確認雙向一致性全覆蓋，並補充缺漏的 fixture。

### Decision

透過程式結構驗證（validate.sh）實施雙向 Index↔Section 一致性，而不依賴 reviewer 紀律。
補充 `bad-orphan-section` fixture 驗證 direction (b)：body section 存在但 index row 缺失 → E-INDEX-MISMATCH。
38 tests pass（含新 fixture）。

### Alternatives considered

- 只文件化規範、靠 PM agent 紀律維持 — 無法在 CI 被偵測，drift 會隨時間累積。
- 在 PM agent 提示詞加 lint 提醒 — prompt 層 enforcement 不可靠，結構 validator 是唯一穩固邊界。

### Constraints introduced

- validate.sh E-INDEX-MISMATCH 同時涵蓋兩個方向；fixture 需兩者皆有對應測試案例。
- 新 fixture 命名規範：`bad-orphan-section`（body-only 孤立 section）、`bad-index-mismatch`（index-only 孤立 row）。

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

---

## 2026-05-19: cc046-validate-dedup

Closes: CC-046

**Context**: validate.sh Pass 2 (`note_index_refs`) re-implemented the
status emoji→kind mapping that Pass 1's `parse_status()` already covers.
`run_validate_case_multi` in run-tests.sh was a copy-paste of
`run_validate_case` with only arg-order differences.

**Decision**: Extract `status_kind()` helper in Pass 2's awk block; merge
`run_validate_case_multi` into a varargs `run_validate_case` and migrate
all 34 call sites. No behavior change — pure dedup.

**Amendment (2026-05-19)**: Gate advisory (critic + arch-reviewer) correctly identified
that `status_kind()` as a Pass-2-local function still left two independent awk programs
with separate status classifiers. Fix: merged Pass 1 and Pass 2 into a single awk
invocation. `parse_status()` (Pass 1) now sets `row_kind[id]`; `parse_index_row()`
reuses `row_kind[id]` for PR-token drift tracking. `note_index_refs()` and
`status_kind()` are both removed. No behavior change.

**Constraints**: Tests (run-tests.sh) must remain green; no new fixtures
needed; no schema version bump.
