# Milestones

<!-- Ordering: newest version section always FIRST (descending). New milestone → add at the top, above the previous one.
     Scope change policy:
     - Blocking bug discovered mid-milestone → add to current milestone, fix immediately
     - Non-blocking bug → BACKLOG new ticket, evaluate in next milestone
     - New feature → default defer; may add if matches theme AND ≤1 PR scope
-->

---

## v0.5.0 — local context substrate（本地 context 地基；規劃中）

**主題**：把 v0.4.0 的 state-first substrate 升級為 **dispatch 前可用的 context**——以「**雙索引 + 單一 context-pack 介面**」的形狀，讓 PM 在派工前同時拿到「**為什麼**」（第二大腦：memory / backlog / decisions）、「**在哪改、可重用什麼**」（repo index：files / symbols / helpers / tests）、與「**最近發生什麼**」（state/event 作 ranking signal）。這是 v0.4.0「無使用者可見賣點」之後的第一個能力層。

> **設計原則（2026-06-08 採納）**：knowledge 與 repo 是**兩個不同搜尋平面**，生命週期相反——knowledge 是 curated / durable / 人類語義（壞了要人修），repo index 是 derived / rebuildable / 程式碼結構（壞了刪掉重建）。原則：**分開建 index、統一輸出 context-pack**，不混成一坨。knowledge 給「為什麼」、repo 給「在哪改」、state/event 給「最近脈絡」。FTS5 列為 optional 加速層、**不可當 hard dependency**（Windows Git Bash 的 sqlite3 未必含 FTS5）→ 必備 `LIKE` / `grep` fallback 並納入測試。外部工具（Khoj / Memori / tree-sitter / codegraph）只接 backend，不入 MVP。

> **Scope 取捨**：依本 repo「thin vertical slice、≤1 PR/feature」慣例，v0.5.0 **不**一次做完雙索引全貌。聚焦**一條端到端可見路徑**：`repo index → context-pack → reuse-scan`（直接攻擊 CC-200..204 reuse-debt，dispatch brief 立即受益）。完整 knowledge index（FTS over 全 memory）與既有 `/mem-search` 重疊，v0.5.0 只做 schema 對齊，重型版延 v0.6.0。細節待 `/discover`（CC-343）跑完後再校準。

### Phase 0 — 票號 hygiene（pre-work，先解再開工）

| 票號 | 說明 | 狀態 |
|---|---|---|
| CC-328→CC-338 | **CC-328 票號衝突已解（2026-06-08）**：CC-328 同時指向「light alias 文件（#229 已 ship，記於 v0.4.0 旁支修正）」與「repo symbol index」。已 ship 的 light-alias 保留 CC-328（歷史不可動）；repo-index 改號至 **CC-338**。見 DECISIONS 2026-06-08 | ✅ 改號完成 |
| CC-339 | 防同號異義 lint：`pm/scripts/lint-ticket-ids.sh` 斷言同一 id 不可同時是 active board 的 open 票與 archive 的 closed 票，emit `E-ID-COLLISION`，接入 lint.yml | ✅ 2026-06-08 |
| CC-329→CC-342 / CC-330→CC-343 | **lint 首次抓到的兩個既存撞號**：active `debt-auditor`（CC-329）撞 archive FSM-table 票；active `/discover`（CC-330）撞 archive state_store_init 票。已關閉者保留原號（歷史不可動），未開工的 forward 票改號至 **CC-342 / CC-343**。見 DECISIONS 2026-06-08 | ✅ 改號完成 |

### Phase 1 — context-pack spine（P1；端到端垂直切片）

| 票號 | 說明 | 目標 P |
|---|---|---|
| CC-237 | **context-enricher interface**：定義 `context_hit_v1`（`source_domain: knowledge / repo / state`、`why_relevant`、`trust_level`、`refs`）作為 CC-232 既有 context-pack schema 的擴充；schema_version enum [1,2]（additive，v1 pack 繼續有效）。定位 = interface（builtin-index 為 backend），非單一 source | ✅ pr:#253 |
| CC-338 | **repo index MVP**（原 CC-328，見 Phase 0 改號）：bash + sqlite3 實作 `files` / `symbols` / `file_chunks`；shell/python/ts/js/go regex symbols + markdown heading chunks；mtime incremental；FTS5-optional + grep fallback；SQLite WAL 並行；暴露 `pmctl context index/update/query` | ✅ pr:#253 |
| CC-239 | **reuse-scan + context pack 組裝**（spine 的 user-visible 終點）：PM briefing 時查 prior art，輸出 `reuse_candidates`（helper / test pattern + why_relevant）並組裝 `pmctl context pack` 統一輸出（context_hit_v1 hits，依 symbols/files 分類）；brief 吸收。repo-index 的第一個 consumer，直接消化 reuse-debt | ✅ pr:#TBD |

### Phase 2 — knowledge 面 + lifecycle（P2）

| 票號 | 說明 | 目標 P |
|---|---|---|
| CC-343 | `/discover` skill：讀 backlog（someday+deferred）+ DECISIONS + MILESTONES + 近期 git，輸出高槓桿機會清單（milestone seeder）。吃 knowledge 面、亦驗證 knowledge 搜尋需求（原 CC-330，撞號改號，見 Phase 0） | ✅ pr:#251 |
| CC-234 | memory v2 minimal：`/mem-distill` 加 `events.jsonl` 輸入；同時作為 knowledge 面的 content 來源 | P3 |
| CC-235 | Task lifecycle gate（warning mode first，不先 hard-gate） | P2 |
| CC-341 | `pmctl validate`（接 CC-202 handover-validate framework；原 milestone 誤指已關閉的 CC-202，改用此 active 票） | ✅ pr:#252 |
| CC-215 | pmctl state-ops 補完（remaining：`task claim/dispatch/status/review` + `safe-bash`）——收掉長期 ⚠️ partial | ✅ pr:#252 |

### Phase 3 — hygiene / deprecation（P2-P3）

| 票號 | 說明 | 目標 P |
|---|---|---|
| CC-296 | v0.3.0 deprecation sunset（`--profile` alias + `codex-dispatch.sh` shim；已過 v0.3.0+v0.4.0 兩個正式版本） | P2 |
| CC-255 | spike rubric + `test_target:` 模糊點修補 | P3 |

### 延後至 v0.6.0+（明確排除於 v0.5.0）

- **完整 knowledge index（CC-340）**（FTS over 全 memory / wiki / episodes）——與既有 `/mem-search` 重疊；v0.5.0 只對齊 schema，standalone index 延 v0.6.0。已開 `🟢 someday` 票追蹤，對稱於 repo-index CC-338。
- **External index backends**——Khoj（semantic knowledge）、Memori（cross-runtime；回寫只走 `memory_proposal`）、tree-sitter / codegraph（CC-209 / CC-253 spike）、ctags。規則：local canonical first，external accelerator second。
- **CC-216 MCP server**——需穩定 pmctl，延 v0.6.0+。
- **CC-333 runtime 解耦（`PM_MEMORY_DIR`）**——knowledge index 落地後再評估 path 抽象需求。

---

## v0.4.0 — state-first foundation（地基完成 2026-06-06，尚未 tag）

**主題**：把 v0.3.0 的 spine 補成**真正 state-first**——`pmctl` 成為機器狀態的**唯一 writer**，dispatch 路徑經 `pmctl` 寫出 Run + Event，`routing_log.md` 機器寫入廢棄改用 `pmctl trace`。決策見 `DECISIONS.md` 2026-06-03（CC-211 committed）；完整 scoping 見 [`docs/architecture/v0.4.0-state-first-foundation.md`](docs/architecture/v0.4.0-state-first-foundation.md)。

> **狀態（2026-06-08）：地基全數落地，review model track 完成。** writers（CC-309/310/311/312/313/314）+ reader `pmctl trace`（CC-315 #237）+ rotation（CC-316 #238）+ store 安全/鎖/layout-parity（CC-317 #239）+ review model（CC-322→327）+ PM_HOOK_* 改名（CC-321 #243）+ install permissions.allow（CC-334 #244）皆已合併。release/tag **尚未**進行。剩餘 release blocker：CC-272 ✅ 已完成（见 Release Blocker Polish）；剩餘：CHANGELOG + tag。能力層（CC-234/235/237）、CC-202、CC-235 移至 v0.5.0；CC-306 為 optional P3 defense-in-depth（見下）。

> **Scope 取捨（2026-06-03 拍板）**：維護者接受 v0.4.0 短期**無使用者可見賣點**——目前使用者少，基建正確性優先於推新功能。以 timeboxed thin vertical slice 降風險；撐不起（需跨 adapters/hooks/gate 大改）才退回增量。MCP（CC-216）與能力層（CC-234/237）延到地基落地之後。

### Phase 1 — single-writer 地基（先做）

| 票號 | 說明 | 狀態 |
|---|---|---|
| CC-211 | 承諾 state-first（epic）；§5 thin slice：一條 `pmctl dispatch run` 經 pmctl 寫 Run+Event、`routing_log.md` 不再機器寫 | ✅ slice (#223)（地基 CC-309..317 完成；epic 延續至能力層/MCP） |
| CC-309 | single-writer：Run/Event 寫入上收 `pmctl`；guard emit Event；writer 邊界硬化（拒 newline/NUL + compact + schema-validate）；寫失敗變響；反轉 layer-boundary 測試 | ✅ (#223) |
| CC-310 | transactional Run+Event（operation-id + 對帳不變量）+ Run FSM 生命週期（pending→…→terminal，每轉移 emit Event） | ✅ (#228) |
| CC-311 | state store VERSION gating + migration（不得靜默降級） | ✅ (#230) |
| CC-312 | schema 收緊（dispatch-run 必填 trace 欄位）+ per-event payload / FSM 轉移驗證 | ✅ (#230) |
| CC-313 | project partition identity：寫 `repo.json` + worktree/aliases + 拒 `global` | ✅ (#232) |
| CC-314 | `routing_log.md` → `events.jsonl` 遷移 + kind 映射 + 停機器寫（D3） | ✅ (#234) |
| CC-316 | rotation 實作（gz、月內 segment 後綴、archive 可查；D7） | ✅ (#238) |
| CC-317 | state store 安全/穩健硬化（store-root perms/symlink、mkdir-lock stale-owner、layout 可執行真相源） | ✅ (#239) |
| CC-306 | layer enforcer 擴及「禁止 `scripts/` 下重新引入 runtime-named data dirs（`.codex-*`/`.claude-*`，CC-298 follow-up）」。注：CC-309 已做的是 adapter 直接寫 state 的反轉測試（A2），與本票**不同**；本票尚未實作 | 🟡 deferred P3（optional defense-in-depth，非地基） |
| — | builds on **CC-230 ✅ #159**（state store + 佈局已在；本階段完成其本意） | — |

### Phase 2 — pmctl state ops + 讀取/查詢

| 票號 | 說明 | 狀態 |
|---|---|---|
| CC-215 | `pmctl task create/show/list/update` + `pmctl decision add`：schema validation、event emission、per-entity lock boundary、rollback（#242）；`pmctl task claim/dispatch/status/review`、`pmctl --json`、`safe-bash` 尚未實作 | ⚠️ partial (#171, #242) |
| CC-315 | 讀取/查詢契約（by id/task/kind/time-window；active+archive 語義）+ `pmctl trace`（D6） | ✅ (#237) |
| CC-202 | `pmctl validate`（接 handover-validate） | 🟡 → v0.5.0 |

### Phase 3 — 第一個 state consumer

| 票號 | 說明 | 狀態 |
|---|---|---|
| CC-315 | **`pmctl trace`**（第一個 consumer，D2=a）：對 `events.jsonl` 的可觀測性，最小表面證明 event stream | ✅ (#237) |
| CC-235 | Task lifecycle gate（trace 之後的下一個 consumer） | 🟡 → v0.5.0 |

### 旁支修正（已合入 main，不在 Phase 1–3 主路徑）

| 票號 | 說明 | 狀態 |
|---|---|---|
| CC-328 | executor-agnostic `light` alias 文件 + claude adapter alias lint/tests + default model contract 修正（omit `--model` 走 alias table 對齊 codex adapter）。註：此為 light-alias CC-328；後來撞號的 repo symbol-index 已改號 **CC-338**（見 v0.5.0 Phase 0） | ✅ (#229) |
| CC-331 | test-install CI 並行化（core/hooks --group）+ jq batch + `_PM_DISPATCH_PREFLIGHT_RUNNER` 注入接縫 + stub-based verify 架構（移除 escape-hatch bypass） | ✅ (#231) |
| CC-321 | rename `CLAUDE_HOOK_*` → `PM_HOOK_*` across 15 files；backward-compat shims（v0.5.0 移除）；427 tests 0 failures | ✅ (#243) |
| CC-334 | install-hooks.sh 安裝時 idempotent merge `permissions.allow`（reviewer subagent 必需的 Write/.gate-results + Bash/pmctl guard check + mkdir -p）；gate-workspace lib 抽取；uninstall-hooks 對稱清除；83 tests 0 failures | ✅ (#244) |

### Review Model Track（並行；不阻塞 Phase 1–3）

文章「Relocating Rigor」的理念合入：把「嚴謹」從中間的逐行 review 搬到上游 intention/spec review 與下游 machine verification，中間層交給 cross-context isolated reviewer。此 track 與 state-first Phase 1–3 相互獨立，可在空檔時穿插實作。

| 票號 | 說明 | 狀態 |
|---|---|---|
| CC-322 | `docs/review-model.md` — Relocating Rigor 哲學正式文件；連結 CONCEPTS.md / dispatch-brief.md / pr-gate-handover-schema.md | ✅ closed |
| CC-332 | PM size-first dispatch routing：Tiny→inline / Small→`model: light` / Medium-Large→Codex default；更新 `docs/model-tier-policy.md` + `agents/project-pm.md` | ✅ closed |
| CC-323 | 強化 `/pre-impl` 輸出 contract：Intention / Non-goals / Bounded Context / Conceptual Map / Acceptance Metrics / Verification Plan 必填；`/pm` 路由對 `behavioral_units ≥ 3` 或 `architecture_impact ≠ none` 自動要求先跑 | ✅ closed |
| CC-324 | dispatch brief schema 新增 `conceptual_map` + `architecture_impact` 欄位；`architecture_impact: major` 時 `conceptual_map` 必填 | ✅ closed |
| CC-325 | brief-validate 強化：acceptance 含空泛語 WARN；file-writing 無 `cmd:` FAIL；`architecture_impact: major` 無 `conceptual_map` FAIL；`behavioral_units ≥ 3` 無 `qa_checklist` WARN；32/32 tests pass | ✅ closed |
| CC-326 | 更新 `architecture-reviewer` prompt：優先讀 conceptual_map，selectively 看 source diff（major / map-diff 不一致 / risk surface）；無 map fallback + note | ✅ closed |
| CC-327 | `/pr-gate` tier 改為 rigor level；`--brief` 選項做 tier advisory；docs/review-model.md 加 rigor tiers 章節 | ✅ closed |

**狀態（2026-06-07）：Review Model Track 全數完成。** CC-323 → CC-327 已落地；pre-impl 六段式 contract、brief schema 架構欄位、brief-validate 品質規則、architecture-reviewer conceptual-map-first、pr-gate rigor tier 均已上線。

### Release Blocker Polish（v0.4.0 tag 前必收）

| 票號 | 說明 | 狀態 |
|---|---|---|
| CC-272 | executor contract cleanup bundle（Part A + Part B 全完成）：`docs/dispatch-brief.md` §Commit delegation rule + §Style notes；`docs/executor-contract.md` §Async dispatch behavior；false partial 來源消除 | ✅ |
| CC-336 | deprecated warnings + executor docs preferred path update（codex-dispatch.sh → pmctl dispatch run；pm.md + codex-executor.md 同步） | ✅ |
| CC-337 | Windows portability：doctor.sh auto-profile false FAIL fix + test suite skip-guards（test-pr-gate-profile/test-claude-executor/test-dispatch-post-verify）+ uninstall prune feedback | ✅ |
| — | CHANGELOG.md v0.4.0 section + git tag `v0.4.0` + GitHub Release | ✅ |

### 地基之後 / 延後（不在地基範圍）

- **CC-202**（pmctl validate）、**CC-235**（Task lifecycle gate）— 原標 `→ v0.4.0`，依 2026-06-08 scope 決策改為 **v0.5.0**（地基已完成，能力層不擠入 v0.4.0 release）。
- CC-234（memory v2 event-derived）、CC-237（context-enricher baseline）— 能力層，建在 event stream 上，地基落地後才做，目標 **v0.5.0**。
- **CC-343**（`/discover` milestone seeder；原 CC-330，撞號改號）— 從 someday 提前至 **v0.5.0** 優先；實作成本 XS，槓桿高。
- CC-216 — `mcp/pm-dispatch-server` + `mcp/README.md` + `pmctl --json` 設計約束；MCP 必須包**穩定的** pmctl，故在 state ops 之後，目標 v0.6.0+。
- CC-220（`/spike` workflow）、CC-209（codegraph spike，🟢 someday）。
- CC-296 — v0.3.0 deprecation sunset（`--profile` alias + `codex-dispatch.sh` shim），目標 **v0.5.0**（待 2 個正式版本）。
- `adapters/antigravity` / `adapters/opencode` — named slot，不實作。

---

## v0.3.0 — PM runtime restructure（released 2026-06-03）

**主題**：把 pm-dispatch 從「Claude Code 設定 + dispatch 腳本」重構成 schema-first / state-first / adapter-thin 的 **PM runtime**；把 Multica / Memori / Superpowers / AI Night Shift 的概念吸收進單一 state substrate，而非四個獨立功能。

完整架構規劃見 [`docs/architecture/v0.3.0-synthesis.md`](docs/architecture/v0.3.0-synthesis.md)（三方獨立規劃對照與綜合）+ [`docs/architecture/v0.3.0-source-plans.md`](docs/architecture/v0.3.0-source-plans.md)。Epic：CC-211。**as-built 落差見該文件的 [Conformance status](docs/architecture/v0.3.0-synthesis.md) 段**（2026-05-31 對齊；A=已採納的演進、B=待決定的開放落差）。

四層架構：`core/`（資料模型 + 政策）→ runtime（**as-built：`cli/pmctl` + `scripts/lib/*`**，非 `runtime/` 目錄）→ `adapters/`（交付層）→ `mcp/`（外部橋接，v0.4.0；`mcp/README.md` 尚未建）。

> **Release scope（2026-06-01 確認）**：v0.3.0 交付 **PM runtime spine**（core/schema + pmctl spine + adapter boundary）。Full state-first consumption（`task`/`decision`/`trace` state ops、event-derived memory、context enricher）延至 v0.4.0；`mcp/` 亦延至 v0.4.0。M0–M4 完成度定義為 spine-level complete，非 full state-first product complete。

### M0 — 便宜前置抽取（零架構風險）— ✅ complete 2026-05-23

| 票號 | 說明 | 狀態 |
|---|---|---|
| CC-201 | `detect_executor_profile()` shim | ✅ (#123) |
| CC-203 | `test-harness.sh` 共用測試 lib | ✅ (#127/#128/#135–#140) |
| CC-218 | spike tracking 基建 | ✅ (#125) |
| CC-219 | pre-milestone doc-freshness gate | ✅ (#129) |
| CC-217 | claude-executor 背景 dispatch | ✅ (#124) |
| CC-060 | Codex model/config 外部化 | ✅ (#131) |

### M1 prerequisite — gate-infra typed surface

| 票號 | 說明 | 狀態 |
|---|---|---|
| CC-250 | `/pr-gate v2` typed result + escalation hint（為 CC-231 reviewer-policy 抽取提供 typed gate output surface） | ✅ (#144) |
| CC-251 | Brief-authoring discipline for multi-file dispatches (`apply_patch` retry-cap / verbatim-as-attached-file / `expected_head_sha` state pin) | ✅ (#145) |

### M1 — state / schema substrate（核心交付）

| 票號 | 說明 | 狀態 |
|---|---|---|
| CC-229 | `core/schema/` — task/run/event/review/decision schemas | ✅ (#157) |
| CC-230 | `~/.local/share/pm-dispatch/state/` state store + `routing_log.md`→`runs.jsonl` | ✅ (#159) |
| CC-231 | `core/policy/` 抽取（reviewer-policy / executor-enum / dispatch-states） | ✅ (#157) |
| CC-232 | context-pack schema + context-enricher 介面 | ✅ (#157) |
| CC-262 | `isolation_level` enum 全三段完成 — adapters/claude no-op map（#162）；codex-dispatch 展開（#175）；PM template（#180）。注：`adapters/codex` 的 dispatch.sh 已由 CC-289 實作（#194）；CC-262 planning 文字/狀態與已 ship 實作的對齊由 [[CC-274]] 完成（2026-06-03；`adapters/codex/isolation-map.yaml` 已 present，5 級映射） | ✅ (#162/#175/#180) |

### M2 — 由抽取長出 runtime — ✅ complete 2026-05-28

| 票號 | 說明 | 狀態 |
|---|---|---|
| CC-264 | dispatch pipeline quality：PR A `brief-validate.sh`（✅ #163/#164）+ PR B `dispatch-post-verify.sh` executor-agnostic Phase 3 post-verify（✅ #167） | ✅ (#163,#164,#167) |
| CC-202 | handover-validator framework 抽取（→ `pmctl validate` 串接移 M3） | ✅ (#170) |
| CC-204 | hook framework 抽取（→ `pmctl guard check` 串接移 M3） | ✅ (#172) |
| CC-200 | executor-router 抽取（→ dispatch runner 串接移 M3） | ✅ (#170) |
| CC-215 | `cli/pmctl` adapter generate subcommand（C-now + D-stub，#171）；`task`/`decision`/`backlog`/`guard`/`trace`/`safe-bash` 子命令未建 | ⚠️ partial (#171) |

### M3 — pmctl runtime spine + 對稱薄 adapter（host-independent executor 核心）— ✅ complete 2026-05-31

完成 M2 未竟的 runtime 層。**原則**：executor 一律是 CLI subprocess，由 `pmctl dispatch run --adapter <X>` 統一叫起，**不依賴誰是主線程**；`Agent()` 僅為「Claude 當 host」時的最佳化捷徑。共用邏輯（brief / guard / route / validate / post-verify）住 `pmctl` + `scripts/lib`；adapter 只放 executor 專屬 invocation + 統一輸出契約（`.agent-trace/latest.last`）。v0.3.0 內 claude 與 codex 兩個 executor 都要實做、且四格（PM × executor）全通。

| 票號 | 說明 | 狀態 |
|---|---|---|
| CC-287 | `pmctl backlog`（view / lint / archive；吸收 CC-282） | ✅ (#190) |
| CC-288 | `pmctl guard check`（接 CC-204 hook-framework；guard 邏輯共用、觸發方式 per-adapter） | ✅ (#191) |
| CC-289 | `pmctl dispatch run`（**走 B**：擁有共用流程；codex-dispatch.sh 瘦成 `adapters/codex/dispatch.sh`） | ✅ (#194) |
| CC-266 | `adapters/claude/dispatch.sh`（`claude --print` 薄 executor，使 codex-as-PM → claude-executor 可行；含 Phase-1 feasibility 檢查） | ✅ (#195) |
| CC-233 | `scripts/test-layer-boundaries.sh`（分層強制器：core/→無 CLI 名、adapters/→無共用邏輯） | ✅ (#197) |

### M4 — Claude 指令 / skill 介面（舊 M3 剩餘）— ✅ complete 2026-05-31

| 票號 | 說明 | 狀態 |
|---|---|---|
| CC-059 | thin `commands/pm.md`（reshaped → post-verify 複用抽取，approach B；原「runner」前提已被 M0–M3 抽取淘汰） | ✅ (#204) |
| CC-061 | `skills/` 目錄 + starter SKILL.md | ✅ 2026-05-31 |
| CC-206 | gate lifecycle hooks（pre/post-gate + `--allow-hooks` opt-in + `--isolation` flag） | ✅ (#175) |
| CC-271 | `docs/sandbox-limitations.md`（folded into CC-206 PR） | ✅ (#175) |
| CC-262 | `agents/project-pm.md` PM template 改寫 `isolation_level:`（M3 residual；M1 adapters/claude 已 ship #162） | ✅ (#180) |

### BACKLOG Hygiene Track（平行於 M3/M4；P1 優先）

| 票號 | 說明 | 狀態 |
|---|---|---|
| CC-277 | 修正 BACKLOG.md 所有 E-code（E-AREA-ENUM / E-REFS-PREFIX / stale active rows）→ `validate.sh` exit 0（P1） | ✅ (#183) |
| CC-278 | 將 `validate.sh` 接入 CI `lint.yml`（Phase 1 warn-only；Phase 2 hard-fail after CC-277）（P2） | ✅ (#184) |
| CC-279 | `scripts/archive-closed-backlog.sh` — idempotent bloat-policy executor（P2） | ✅ (#184) |
| CC-280 | 執行 archive script，壓縮當前 BACKLOG 膨脹（deferred until CC-279）（P2） | ✅ (#185) |
| CC-281 | BACKLOG index 分割 Active / Terminal（comment delimiter；deferred until CC-280）（P3） | 🚫 dropped 2026-05-30 |
| CC-282 | `pmctl backlog sync` → SQLite derived query layer（deferred until CC-215 M3）（P3） | 🚫 dropped 2026-05-30 |
| CC-291 | `pmctl guard check` — `--role`/`--runtime` generalization（吸收 CC-288；`--profile` alias deprecated） | ✅ (#205) |
| CC-300 | dispatch allowlist bootstrap（CC-208 follow-up；gate citation guard 後置修正） | ✅ (#206/#207) |
| CC-301 | multi-line hook chain + uninstall allowlist cleanup | ✅ (#207) |
| CC-302 | `install.sh` settings.json timestamped backup | ✅ (#211) |
| CC-303 | allowlist entry construction 集中化 → `scripts/lib/allowlist.sh`（adapter-agnostic dynamic scan） | ✅ (#211) |
| CC-304 | hook `_rate_tmp` trap leak + startup stale-temp cleanup | ✅ (#209) |

### v0.3.0 收尾（M3/M4 after-burn）

spine 已 ship，以下為 v0.3.0 release 前必收的殘餘架構縫與 polish。

| 票號 | 說明 | 狀態 | P |
|---|---|---|---|
| CC-299 | `/pm` 改走 `pmctl dispatch run --adapter codex\|claude`；`Agent(executor)` 降為 fallback | ✅ (#213) | P2 |
| CC-260 | `/pr-gate` dirty worktree fail-loud preflight：only fail when `BASE...HEAD` has committed changes and worktree is dirty; `--allow-dirty` folds working tree into review scope | ✅ (#214) | P2 |
| CC-305 | concurrent `pmctl dispatch run` race on `latest.*` symlinks → explicit per-run footer paths in post-verify；`pmctl-config.sh` 共用 config loader；`sw_append_dispatch_run` 共用 state-store row builder | ✅ (#216) | P2 |
| CC-298 | `.gate-briefs/` + brief filenames runtime-neutral（runtime 記錄在 frontmatter） | ✅ (#216) | P2 |
| CC-215 | `pmctl task`/`decision`/`trace`/`safe-bash`（spine 已含 backlog+guard+dispatch；剩餘延 v0.4.0） | ⚠️ partial | P2 |
| CC-293 | config/default 解析從 `adapters/codex/dispatch.sh` 提升至 `pmctl dispatch run` runtime layer | ✅ (#216) | P3 |
| CC-297 | `reviewer` guard role — 只能寫 `.gate-results/`（防 prompt-injection 誘導 reviewer 亂寫）；`cli/pmctl` relative symlink fix；fan-out spike | ✅ (#218) | P3 |

### M5 — 概念吸收 → 全部移至 v0.4.0

| 票號 | 說明 | 狀態 |
|---|---|---|
| CC-234 | memory v2 — event-derived distillation（Memori） | 🟡 → v0.4.0 |
| CC-235 | Task lifecycle gate — spec→design→plan 強制（Superpowers） | 🟡 → v0.4.0 |
| CC-237 | context-enricher baseline — rg/git/memory sources | 🟡 → v0.4.0 |

### M6 — release prep（v0.3.0 收尾）

CC-220（spike workflow）、CC-209（codegraph spike）已移至 v0.4.0。

| 票號 | 說明 | 狀態 |
|---|---|---|
| CC-261 | v0.3.x 前瞻文字更新（`core/README.md` + `agents/project-pm.md`） | ✅ (#162) |
| CC-265 | 移除 `/caveman` 與 `/caveman-commit` | ✅ 2026-05-26 |
| — | v0.3.0 release prep（CHANGELOG + tag + GitHub Release） | ✅ 2026-06-03（CHANGELOG #219；tag `v0.3.0`；GitHub Release published） |

### v0.3.0 範圍外 → v0.4.0

- **pmctl 剩餘子命令** — `pmctl validate`（接 CC-202 handover-validate）、`pmctl task / decision / trace`（state-ops，建在 CC-230 state store 上）、`pmctl safe-bash`。v0.3.0 spine 只放 backlog + guard + dispatch 三個 load-bearing 面（CC-215 partial）。
- **M5 概念吸收全部延 v0.4.0** — CC-234（memory v2 event-derived）、CC-235（Task lifecycle gate）、CC-237（context-enricher baseline）。
- **M6 spike workflow 延 v0.4.0** — CC-220（`agents/spike.md` + `/spike` command）、CC-209（codegraph context-enrichment spike，降 🟢 someday）。
- CC-216 — `mcp/pm-dispatch-server` 實作（v0.4.0）。**as-built：原規劃 v0.3.0 應放的 `mcp/README.md` 介面規格尚未建**（連帶 `pmctl --json` 設計約束未落實）；整個 `mcp/` 延 v0.4.0。見 synthesis 的 Conformance status §B。
- CC-296 — v0.3.0 deprecation sunset（`--profile` alias + `codex-dispatch.sh` shim 移除，目標 v0.5.0，待 2 個正式版本後執行）。
- `adapters/antigravity` / `adapters/opencode` — named slot，不實作（Antigravity CLI 取代 Gemini CLI；原規劃寫的 `gemini` 一律改為 `antigravity`）。注：**`adapters/codex` 已在 v0.3.0 實作**（與 claude 對稱薄 adapter），原「延 v0.4.0」規劃已 superseded。
- AI Night Shift autonomy loop — 不做
- CC-236 `pmctl report` 晨報 — 🟢 someday（2026-05-22；無人值守執行需求低）

---

## v0.2.0 — Cross-platform ops（released 2026-05-22）

**主題**：完整 install / verify / uninstall 操作週期；環境健康診斷；Windows Git Bash 正確性修復。

Tag: `v0.2.0` @ `2c55650`（released 2026-05-22；GitHub Release published）

核心內容（詳見 CHANGELOG.md v0.2.0 section）：
- `scripts/doctor.sh` — 環境健康檢查，每項給出可操作修復步驟（CC-058）
- `scripts/run-all-tests.sh` — standalone 全套測試聚合器（CC-104n）
- `uninstall.sh` — manifest-driven 移除（CC-109）
- `install.sh` — directory junction（Windows）、copy-mode refresh、jq prereq check（CC-207/CC-221/CC-104l/v）
- `scripts/lib/portable.sh` `serialize_with_lock()` — flock portable shim（CC-104p）
- Hook scripts python3 → jq 重寫（CC-104t）
- pm-schema v1.1/v1.2（Priority/Epic 欄位、design/spike epic）（CC-052/CC-205）

### Completed since v0.1.0

| PR | Tickets | 說明 |
|---|---|---|
| #79 | CC-104b | 安裝時 jq 缺失給出 platform-aware 提示 |
| #80 | CC-104g/h/i | Windows dogfood r1 修復（portable.sh / brief validator / .gitattributes） |
| #83 | CC-025b, CC-039 | commands self-test + skill-refine guard |
| #82 | CC-013 | /caveman token 壓縮 skill |
| #84 | CC-053 | CLI self-test coverage（test-commands.sh） |
| #85 | CC-005 | install.sh preflight 改為 --verify opt-in |
| #86 | CC-055/056/057 | lint-frontmatter CI + pr-gate frontmatter fix + README 同步 |
| #87 | CC-049/050 | 歸檔已關閉票 + 審核 stale deferred |
| #88 | CC-051 | BACKLOG convention preamble（status emoji legend） |
| #89 | CC-104c | link_or_copy() + install manifest（symlink-unavailable host 支援） |
| #93 | CC-052 | pm-schema v1.1 — Priority & Epic 欄位 |
| #95 | CC-067 | 廢棄 ID-gap 慣例；新增 DECISIONS.md |
| #96 | CC-030 | bad-orphan-section fixture |
| #98 | CC-046 | validate.sh 重構（合併 awk pass + 統一 test helper） |
| #99 | CC-024 | 標記 test-usage-weekly CI 已完成 |
| #100 | CC-104u | link_or_copy CONFLICT fix（real-directory dst） |
| #101 | CC-104n | standalone run-all-tests.sh + dir-idempotency fix |
| #102 | CC-031 | SECURITY.md, CONTRIBUTING.md, working language 聲明 |
| #104 | CC-205 | pm-schema v1.2 — design epic + validate/rollup v1.2 |
| #105 | CC-206 | gate lifecycle hook 設計記錄（BACKLOG entry） |
| #106 | — | SECURITY.md GitHub Private Security Advisory 流程 |
| #107 | CC-104t | hooks 層 python3 → jq 重寫；新增 memory.sh / memory-dir.sh |
| #108 | CC-207 | platform-support.md 改寫 + CC-207 BACKLOG entry |
| #109 | cc-uninstall | manifest-driven uninstall.sh（23 security tests） |
| #110 | — | uninstall-hooks.sh generic repo-root removal fix（49 tests） |
| #111 | — | CC-209/CC-210/CC-211 BACKLOG entries + Epic enum fix |
| #112 | CC-207 | Windows Git Bash directory junction support |
| #113 | CC-212/213/214 | CC-207 advise follow-ups（env-var path 傳遞、junction idempotency、docs uninstall 錨定） |
| #114 | CC-104p | flock → serialize_with_lock portable shim；routing-log fresh-HOME fix |
| #115 | CC-217..220 | spike epic + process improvement BACKLOG entries |
| #116 | CC-104l, CC-104v | install.sh jq prereq check + copy-mode banner |
| #117 | CC-221 | copy-mode refresh semantics（link_or_copy src-vs-dst sha compare） |
| #119 | CC-058 | scripts/doctor.sh + lint-frontmatter PyYAML-equivalent validation + 68 regression tests |

### Roadmap (all shipped)

| 票號 | 說明 | 狀態 |
|---|---|---|
| CC-058 | `scripts/doctor.sh` — 環境健康檢查 | ✅ |
| CC-104l | install.sh 頂部加 jq 先決條件 check + README | ✅ |
| CC-104v | copy-mode 安裝後顯示 summary banner | ✅ |
| CC-221 | copy-mode refresh semantics（link_or_copy src-vs-dst sha compare） | ✅ |
| CC-104p | flock → portable locking shim（Windows row-loss 修復） | ✅ |
| CC-222 | v0.2.0 release prep（CHANGELOG + docs + tag + GitHub Release） | ✅ |

---

## v0.1.0 — Foundation（released 2026-05-17）

**主題**：CC-OSS epic — 首次公開發布；跨平台基礎建設 + PR gate pipeline。

Tag: `v0.1.0` @ commit `72a9405`

核心內容（詳見 CHANGELOG.md 或 PR #77 release notes）：
- `scripts/pr-gate.sh` unified PR gate（sequential / parallel）
- `scripts/codex-dispatch.sh` codex 派送 wrapper
- `scripts/install.sh` + `scripts/lib/portable.sh` cross-platform installer
- pm-schema v1.0 + `pm/scripts/validate.sh` + `pm/scripts/rollup.sh`
- hook 層完整套件（inject-memory / routing-log / tool-trace / session-summary 等）
- Windows dogfood r1（CC-104a/b/c/d/e/f）修復
