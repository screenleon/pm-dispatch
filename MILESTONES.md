# Milestones

<!-- Ordering: newest version section always FIRST (descending). New milestone → add at the top, above the previous one.
     Scope change policy:
     - Blocking bug discovered mid-milestone → add to current milestone, fix immediately
     - Non-blocking bug → BACKLOG new ticket, evaluate in next milestone
     - New feature → default defer; may add if matches theme AND ≤1 PR scope
-->

---

## v0.6.0 — executor abstraction（runtime 解耦合；規劃中 2026-06-14）

**主題**：把 dispatch / guard / 安裝三條路徑上「綁定特定 executor」的最後硬編碼收乾淨，讓 pm-dispatch 真正 **executor-agnostic**。一句話驗收標準：**「新增第三個 executor = 放 `adapters/<name>/` + 一份 manifest，核心零改動」**——router 自動路由、guard 自動套對、install 自動接線。並用 **opencode + Google Antigravity（`agy`）兩個真 adapter** 落地當抽象的驗收（N≥2 才算抽象成立，不是僥倖）。Umbrella epic：[[CC-333]]（runtime 解耦合）。

> **設計依據（本 session 2026-06-13/14 分析）**：dispatch 接縫（`pmctl dispatch run --adapter <name>`）其實已乾淨——上層只認 adapter 名字，輸出契約是 `.agent-trace/latest.last`。殘留耦合集中在一個**隱藏屬性**：adapter 的 **runner-kind**（`cli-subprocess` thin-dispatch/hook-gated vs `host-native` self-exec/harness-gated），目前被隱式寫死三遍（`executor-router.sh` case ／哪些 hook 檔存在＋settings 接線 ／每個 guard 的 threat-model）。v0.6.0 = 把 runner-kind 宣告一次在 `adapter.yaml`，router / guard / install 全部由它衍生。

> **Scope 取捨**：依本 repo「thin vertical slice、≤1 PR/feature」慣例分階段，每階段可獨立 ship。Phase 2/3 動 allowlist 與 guard 安全邊界，**硬 gate**（security-reviewer + risk-reviewer，不可 PM 自我 override，見 [[gate-clear-all-on-block]]）。**保守退路**：若 Phase 1+2（manifest + router）落地後評估 guard 收口風險過高，Phase 3 可單獨延 v0.7.0，但 manifest 欄位（CC-372）會懸空一版——故預設走完整版。

### Phase 1 — manifest runner-kind 地基（P2；純加法，先行）

| 票 | 摘要 | 狀態 |
|----|------|------|
| CC-372 | `adapter.yaml` 加 `runner_kind` + 衍生旗標（`dispatch_route`/`write_guard_mode`/`needs_bash_guard`）；codex/claude 回填行為不變 | ✅ pr:#277 |

### Phase 2 — router 資料驅動（P2；security/risk gate）

| 票 | 摘要 | 狀態 |
|----|------|------|
| CC-373 | `executor-router.sh` 拔除 `codex\|claude` enum，改讀 manifest；allowlist = 有合法 manifest 的 adapter；泛化/移除 `dispatch_via_codex`。**吸收 CC-360** | ✅ pr:#279 |

### Phase 3 — guard wrapper 收口 + 安裝接線（P2-P3；security/risk gate）

| 票 | 摘要 | 狀態 |
|----|------|------|
| CC-374 | hook-guard wrapper 收成 role-參數化、委派 `pmctl guard check`；行為由 manifest 衍生。**吸收 CC-066/CC-062，收尾 CC-307**。紅線：bash-guard 由 `needs_bash_guard` 決定、live-hook bit 由 manifest 明宣告 | ✅ pr:#280 |
| CC-379 | pr-gate 生成 brief 過不了 brief-validate（`self_verify` 格式、`acceptance` 縮排）→ claude gate route 全壞修復 | ✅ pr:#277 |
| CC-380 | gate reviewer 的 `pmctl guard check` allowlist 缺絕對/tilde 形式 → 背景 reviewer subagent 一律 DENY 修復 | ✅ pr:#277 |
| CC-382 | pr-gate `--output` 相對路徑 → 兩 executor 皆產空結果；抽 `gate-result-verify.sh` + 新增 `pmctl gate verify` | ✅ pr:#277 |
| CC-383 | `pmctl gate --executor claude` 改走獨立 headless subprocess；退場 handover；`dispatch_via_claude` 對稱 codex | ✅ pr:#278 |
| CC-375 | install/uninstall/doctor 的 hook 接線由 manifest 能力旗標衍生；三方一致性回歸（呼應 CC-368） | ✅ pr:#281 |

### Phase 4 — dispatch-model 統一：Model B 全面上路（P2；[[CC-385]] 決策落地）

> 採用 Model B（pmctl 落地 brief → executor 獨立子程序消費）為**唯一** dispatch 主路（spike [[CC-385]] / [[CC-385a]]，DECISIONS 2026-06-15）。定序紅線：先建可信驗證（CC-386）才退場舊路（CC-387）——任何時刻 guard 不得在 migration 中途被弱化（fail-closed）。

| 票 | 摘要 | 狀態 |
|----|------|------|
| CC-386 | pmctl post-verify 成為 executor 結果唯一驗證者（exit code + trace 完整性 + self_verify 實跑）。**keystone，先行** | ✅ |
| CC-387 | codex 子代理自寫 brief 路退場；`pmctl dispatch run` 為唯一 codex routine 路；live-hook routine 全 no-op。相依 CC-386 | ✅ |
| CC-388 | claude adapter 作為一般 implementation executor（非僅 gate route）；與 codex 對稱。切換至 stream-json JSONL。相依 CC-383/CC-386 | ✅ |
| CC-389 | non-interactive executor 契約 spec（auth 前提 + fail-loud + 唯一輸出/驗證 + fallback policy）；CC-376/377 落地基準；per-adapter 語意終止事件驗證（unblock CC-387） | ✅ |

### Phase 5 — 真 adapter 驗收（P2；抽象的證明）

| 票 | 摘要 | 狀態 |
|----|------|------|
| CC-376 | opencode executor adapter（第一個第三方 adapter；落地若需改核心 = 抽象未竟）。以 CC-389 契約為基準 | ✅ pr:#TBD |
| CC-377 | Google Antigravity `agy` executor adapter（第二個；驗 N≥2）。**注意 Gemini CLI 已棄用，目標是 antigravity 非 gemini** | 🔵 |

### Phase 6 — deprecation 清掃（P2）

| 票 | 摘要 | 狀態 |
|----|------|------|
| CC-335 | deprecated surface 移除 sweep；其中 `--profile` alias 與 `codex-dispatch.sh` shim 為 runtime-coupling cruft，與本 milestone 同期最自然 | 🔵 |

### Phase 7 — executor lifecycle ownership（P2；executor 抽象的完成式）

> **為什麼在 v0.6.0 而非 v0.7.0（2026-06-15 user 校準）**：`host-native` 把 executor 綁死在 host harness，detached-supervised 把它解開——**這正是本 milestone「runtime 解耦合」主題的完成式**，不是下一版新題目；且 [[CC-391]] 是 [[CC-385]]（Model B 決策，Phase 4）的直接續集，分跨兩版會把 dispatch-model 故事打碎。thin-slice 是**每個 PR** 的紀律、非每個 milestone；Phase 7 三薄片各自可獨立 ship。
>
> **排序紅線**：Phase 7 實作必須排在 **Phase 5（真 adapter CC-376/377）之後**——先在 N≥2 adapter 下證明 executor 抽象，再加 lifecycle 層，避免 supervisor 契約被 codex/claude 特例帶歪。**逃生口**（沿用 Phase 3 寫法）：若 v0.6.0 收尾時 Phase 7 未及，可單獨延 v0.6.x 點版或 v0.7.0，但預設留在 v0.6.0。
>
> **設計依據**：Model B（[[CC-385]]/[[CC-386]]..[[CC-389]]）已交付 brief-可信落地 + executor-獨立子程序 + pmctl-三重機檢驗證；但派發仍 **foreground-sync**（`pmctl dispatch run` 阻塞、in-process 驗證、main 持有生命週期）。缺的是 process 生命週期擁有權、durable 結果、listener 通知。這不是 [[CC-372]] runner_kind（怎麼**到達** executor），而是 **lifecycle ownership**（啟動後**誰持有**）——正交新軸。**定位紅線**：lifecycle 是**派發當下的選擇**（`pmctl dispatch run --lifecycle foreground\|detached` + config 預設），**非 manifest 欄位**；可 detach 資格由 runner_kind（headless-CLI Model B）推導，`host-native` 不可 detach；不引入 `lifecycle_mode`/schema 改名（避與 [[CC-384]] 撞）。verify 層直接重用 [[CC-386]]/[[CC-389]]，durable substrate 重用 [[CC-211]]；真正 net-new 只有 detached supervisor 與 notify channel。

| 票 | 摘要 | 狀態 |
|----|------|------|
| CC-391 | **(7a 決策-only，先行)** detached-supervised dispatch 建模決策：lifecycle 作派發旗標非 manifest 欄位、supervisor 元件邊界、durable-outbox 為 load-bearing、foreground→detached 遷移順序（fail-closed 不弱化）、一次真實 detached 派發等價證明。**codex spike = partial-adopt**（`docs/spikes/CC-391-*.md`） | 🔵 |
| CC-392 | **(7a 前置)** claude adapter `runner_kind` 分類漂移修正——manifest 宣告 `host-native` 但 adapter 實跑 headless `claude --print`（[[CC-383]]/[[CC-388]] 後）→ `runner_kind` 不可信、卡住 [[CC-391]] detach 資格推導。傾向定 canonical 為 `cli-subprocess`＋override 保行為不變；security/risk hard gate（不弱化 claude write guard） | 🔵 |
| CC-225 | **(7b durable，可獨立先 ship)** all-executor durable run-state 記錄（brief 路徑 / result 摘要 / exit / post-verify 判定 → repo-tracked，格式對齊 `.gate-results/`）；對齊 [[CC-211]] run-FSM。supervisor 的 durable 半；真 adapter 需要時前拉 | ⏸ |
| CC-391 落地子票 | **(7c net-new 核心，Phase 5 後)** `pmctl dispatch start`（setsid/nohup detached supervisor）+ `pmctl dispatch wait`/`pmctl inbox`（reattach）+ durable-outbox notify channel；重用 [[CC-386]]/[[CC-389]] post-verify。**spike 決策後再開正式子票號** | — |
| CC-238 | **(7c)** pr-gate fan-out 無 timeout / 弱 attribution = 缺 supervisor 症狀；以通用 supervisor timeout + per-child attribution 收掉（非在 `pr-gate.sh` 做一次性 timeout） | ⏸ |

### 延後至 v0.7.0+（明確排除於 v0.6.0）

- **CC-216 MCP server**——「通用橋」邏輯上是 executor 抽象＋lifecycle 之後的下一層，且為重型 net-new surface（Node/Python server + `pmctl --json`），不符 thin-slice。**2026-06-13 user 拍板 defer。** v0.7.0 headline，見下方 v0.7.0 區段。
- **CC-333 七層耦合中的 1/4/7**（memory 路徑 / 安裝路徑 / reviewer memory 讀取）——本版聚焦 dispatch+guard+install+lifecycle 的 executor 抽象；memory/install-target 軸（含 [[CC-104m]] 多目標投影）留待後續。
- **CC-358 / CC-359**（runner telemetry / worktree batch dispatch）——建在抽象之上的能力層，抽象穩定後再做。
- **完整 knowledge index（CC-340）**——延續 v0.5.0 的 v0.6.0+ 排除，與 executor 抽象無關，獨立排程。

---

## v0.7.0 — 通用橋 MCP server（規劃中 2026-06-15）

**主題**：executor 抽象（v0.6.0 dispatch/guard/install + lifecycle）穩定後的下一層——**MCP 通用橋**，讓任意 MCP-aware host 透過單一協定使用 pm-dispatch，不必逐工具接線。

> **為什麼排在 v0.6.0 之後**：MCP 必須包**穩定的** pmctl 與**已收口的 executor 抽象**（含 lifecycle）。v0.6.0 把 executor 變成資料驅動、生命週期獨立的 supervised worker 後，MCP 才有穩定的下層可包。重型 net-new surface（Node/Python server + `pmctl --json`），不符 v0.6.0 thin-slice。**2026-06-13 user 拍板從 v0.6.0 defer。**

### Phase 1 — MCP server + `pmctl --json`（P2）

| 票 | 摘要 | 狀態 |
|----|------|------|
| CC-216 | `mcp/pm-dispatch-server` + `mcp/README.md` + `pmctl --json` 設計約束；thin Node/Python wrapper over pmctl subprocesses（避免邏輯重複），或 spec 穩定後 native bash MCP server。相依 [[CC-211]]、[[CC-215]]（pmctl 穩定先於包裝）、v0.6.0 executor 抽象＋lifecycle | ⏸ |

### 待後續 / 與本版正交

- **CC-273（unified lifecycle *hook event* spec）**——tool-step hook 事件（user-extensibility seam），與 process lifecycle（v0.6.0 Phase 7）正交；待出現第二個 hook 點需求再做。
- **CC-333 七層耦合 1/4/7**（memory / install-target / reviewer memory 讀取軸）——與 executor 抽象軸正交，獨立排程；可與 MCP 同期評估。
- **完整 knowledge index（CC-340）**——standalone FTS + embeddings 重型版，與 executor 抽象無關，獨立排程。

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
| CC-239 | **reuse-scan + context pack 組裝**（spine 的 user-visible 終點）：PM briefing 時查 prior art，輸出 `reuse_candidates`（helper / test pattern + why_relevant）並組裝 `pmctl context pack` 統一輸出（context_hit_v1 hits，依 symbols/files 分類）；brief 吸收。repo-index 的第一個 consumer，直接消化 reuse-debt | ✅ pr:#256 |

### Phase 2 — memory 讀寫閉環（P2；本 milestone 能力主軸）

> **重定錨（2026-06-10）**：原 Phase 2 是散裝能力（CC-234 / CC-235 / knowledge index 各自為政）。改以 **memory 讀寫都順** 為主軸——驗收：寫側 `/mem-distill` 產 event-derived 卡片；讀側 in-repo knowledge docs 可 `pmctl context query`（不再 grep BACKLOG），memory cards 維持既有 MEMORY.md auto-injection；動手前先查 index 再 grep。觸發原因見 `DECISIONS.md` 2026-06-10：memory 寫了沒人讀——knowledge plane 無可查 index（`pmctl context query` 只索引 repo plane）、retrieval 反射仍是 grep；且 indexer 對每檔只存 `head -c 2000` 一塊，180 KB 的 BACKLOG 只有前 ~30 行進 index，連找 CC-234 都得 grep。
>
> **讀寫分工（語意轉化只發生在寫側）**：**寫側**做語意轉化（episodes + events → memory card，卡片本身即蒸餾產物）；**讀側**只當「**帶錨點的語意目錄**」（heading + 抽 id + 行錨點 + lead，**不存全文**，命中後 lazy-read 原檔）。index **不**對結構化 markdown 做 LLM 全文摘要——這類文件人類已用 `## CC-NNN` 標題語意化過，標題即摘要。
>
> **Scope trim + 驗收原則（2026-06-10 arch review 採納，見 DECISIONS 同日 scope-trim entry）**：(1) **接線即驗收**——v0.5.0 各能力票的驗收必含「工具被工作流實際呼叫」，不止「工具存在」；repo plane 已出現反例（pack/reuse-scan ship 後零 caller→ 新增 CC-356 接線票）。(2) **Loop 成功指標**＝後續類似任務時 PM **直接引用 memory / decision / backlog anchor 組 brief**，main thread 不再重新推論背景——query 次數 > 0 只是必要非充分。(3) CC-234 縮範圍：實測 events.jsonl 為 run-FSM lifecycle telemetry（happy path 無可蒸餾語義），寫側改吃 episodes + **異常 events**（exit≠0 / timeout / gate block），砍 generic event-tier schema。(4) CC-346 暫緩：reuse-scan 未被使用前不加深資料層，resume trigger = CC-356 接線後觀察到實際使用且 ref 缺口為瓶頸。

| 票號 | 說明 | 目標 P |
|---|---|---|
| CC-343 | `/discover` skill：讀 backlog（someday+deferred）+ DECISIONS + MILESTONES + 近期 git，輸出高槓桿機會清單（milestone seeder）。吃 knowledge 面、亦驗證 knowledge 搜尋需求（原 CC-330，撞號改號，見 Phase 0） | ✅ pr:#251 |
| CC-354 | **讀側：anchored knowledge index + retrieval reflex**。對 in-repo knowledge docs（BACKLOG/DECISIONS/MILESTONES/docs）做 per-section TOC（heading + 抽 CC-id/decision-id + 行錨點 + lead，非全文），透過 pluggable per-format chunker（markdown heading / txt window；html deferred）；`pmctl context query --domain knowledge`；「查 index 再 grep」紀律寫入**中立 docs 契約 + pmctl**，不寫 CLAUDE.md（避免平台綁定），僅 agents/project-pm.md 放一行指標。repo 外 memory cards 維持 auto-injection，不進此刀。驗收含接線 + anchor-citation 指標（見上方驗收原則） | ✅ |
| CC-234 | **寫側：memory v2（2026-06-10 縮範圍）**。`/mem-distill` 吃 episodes.jsonl + events.jsonl 的**異常切片**（run 失敗/timeout/gate block）→ 語意化 memory card；happy-path lifecycle events 明確排除；不做 generic event-tier schema（延 CC-340 再議）。驗收 = 從一次真實失敗蒸餾出一張真卡（cite episode 行 + event id），經確認後寫入 | ✅ pr:#265 |
| CC-356 | **接線：context pack / reuse-scan 進 dispatch 流程 + 使用可觀測**（新增 2026-06-10）。pack/reuse-scan（#256）操作面零 caller——中立 docs 契約 + PM/skill 指標要求 brief 前先查 prior art；reuse_candidates 設 hit 上限防 brief 噪音；query/reuse-scan emit event 使使用次數可由 `pmctl trace` 量測。亦為 CC-346 的 resume-trigger 證據來源 | ✅ pr:#264 |
| CC-235 | Task lifecycle gate（warning mode first）——`pmctl task dispatch` 在 claimed→in-progress 轉移時依 `behavioral_units` / `size_tier` 欄位導出 tier，substantial（≥3 units 或明確標記）時 warn to stderr + emit `task.lifecycle.warn` event，非 blocking；trivial/small/unknown 靜默放行 | ✅ pr:#266 |
| CC-341 | `pmctl validate`（接 CC-202 handover-validate framework；原 milestone 誤指已關閉的 CC-202，改用此 active 票） | ✅ pr:#252 |
| CC-215 | pmctl state-ops 補完（remaining：`task claim/dispatch/status/review` + `safe-bash`）——收掉長期 ⚠️ partial | ✅ pr:#252 |

### Phase 3 — hygiene / deprecation（P2-P3）

| 票號 | 說明 | 目標 P |
|---|---|---|
| CC-296 | v0.3.0 deprecation sunset（`--profile` alias + `codex-dispatch.sh` shim；已過 v0.3.0+v0.4.0 兩個正式版本） | P2 |
| CC-255 | spike rubric + `test_target:` 模糊點修補 | P3 |

### 延後至 v0.6.0+（明確排除於 v0.5.0）

- **CC-346 cross-file ref tracking（file_refs 層）**——Resume trigger：reuse-scan 輸出進過 ≥2 份真 brief 且 ref 缺口確為瓶頸；恢復時先只做 Phase a（bash source）。paused 2026-06-10：reuse-scan 零 caller 時加深資料層 = 加倍下注未驗證假設。

- **完整 knowledge index（CC-340）**——standalone FTS + embeddings + episodes low-trust chunk 的重型版仍延 v0.6.0，與既有 `/mem-search` 重疊。**但 anchored-TOC 薄切（in-repo knowledge docs 的 section 目錄）已拉前至 v0.5.0 CC-354**：沒有它 memory 讀側完全不可用（連 BACKLOG 內的票都得 grep，見 Phase 2 重定錨）。CC-340 縮為剩餘範圍——repo 外 memory cards / wiki / episodes 索引 + standalone full-text + embeddings，對稱於 repo-index CC-338。
- **CC-355 HTML semantic chunking**——CC-354 的 per-format chunker 對 html 先走 window fallback；`<h1-6>` 語意 chunking 留 follow-up（bash 解析 HTML 脆、且 repo 目前無 .html knowledge 來源），plug 進 CC-354 的 chunker seam。
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
