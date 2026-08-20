# Milestones

<!-- Ordering: newest version section always FIRST (descending). New milestone → add at the top, above the previous one.
     Scope change policy:
     - Blocking bug discovered mid-milestone → add to current milestone, fix immediately
     - Non-blocking bug → BACKLOG new ticket, evaluate in next milestone
     - New feature → default defer; may add if matches theme AND ≤1 PR scope
-->

---

## Pre-v1 stabilization sequence（2026-07-30 重排；v1.0 尚未排程）

> 這不是 v1.0 倒數或 release forecast。以下 v0.x milestones 用來逐版消化目前
> 已知的遷移、操作、安全、證據與公開化缺口；當前規劃維持連續的
> v0.11.0 → v0.12.0，完成 v0.12.0 後才重新做一次 v1.0 readiness review，
> 再決定是否建立 v1.0.0 milestone。任何未完成的 critical surface 都不能因版本
> 接近而自動降級或略過。Milestone 同時保留既有版本的交付歷史與 remaining plan；
> 重排只在既有 phase 後追加新工作，不移除已記錄的完成項目，也不從 archive 拉回
> 原本不在 milestone 的舊票。

## v0.12.0 — public contract candidate（暫定；未啟動）

> 最後排程更新：2026-07-30（原 v0.14.0 連續改編為 v0.12.0）

**主題**：完成 public posture 與 stable/experimental contract candidate；本版產物
是「是否具備建立 v1.0 milestone 的事實基礎」，不是 v1.0 RC。Runtime authority、
Gate correctness 與 release evidence 仍必須先在 v0.11.0 關閉。

> **設計依據**：契約凍結必須晚於 CLI discovery、state compatibility、
> upgrade/release evidence 與 detached recovery，避免先承諾再補安全語意；
> manifest／schema／generated distribution 的雙重 authority 也必須先收斂。

### Phase 1 — public surface

| 票 | 摘要 | 狀態 |
|----|------|------|
| CC-032 | feedback cross-link glossary 公開化，清除 public dead/private-only link | 🔵 |
| CC-033 | README/onboarding public posture、history audit 處置、repo collaboration surface | 🔵（history audit ✅ 2026-07-18；其餘未啟動） |
| CC-514 | orthogonal assurance map、machine-derived tier/mode/policy tables 與 docs-only／functional／high-risk recipes；draft 可先行，runtime-aligned finalization 後公開 | 🔵 |

### Phase 2 — contract candidate

| 票 | 摘要 | 狀態 |
|----|------|------|
| CC-446 | stable/experimental CLI + schema、SemVer/deprecation、deprecated surface 清掃；補上 authority 分類 | 🔵 |

### 待後續 / 明確排除

- v1.0.0 milestone、RC 日期與 release tag：**全部尚未排程**；本版完成後另做 readiness review。
- CC-447 live dogfood 可作 readiness evidence，但不得用一次 happy path 取代 contract/evidence 缺口。

---

## v0.11.0 — pre-v1 stabilization：state compatibility + release/operational evidence（進行中）

> 最後排程更新：2026-08-14（保留既有 Phase 1–9 交付歷史；CC-521 已由
> pr:#470 關閉，CC-522 的 QA execution evidence 與 self-authored external
> evidence fail-closed boundary 兩個 slices 已交付）

**主題**：一次消化 v1.0 前已知的 state compatibility、release/upgrade evidence 與 operational evidence 缺口。原 v0.11.0（state compatibility + writer boundary）、v0.12.0（release evidence + upgrade proof）、v0.13.0（detached recovery + operational evidence）合併為本版；其中 detached reconciliation（CC-499）已提前於 v0.10.0 出貨，不在本版 scope。Phase 10–12 追加 public contract candidate 前必須收斂的 runtime authority、Gate security 與 generated-source 邊界。

> **設計依據**：合併只降低 release closure 次數，不改變原有排序理由——state compatibility 先於 writer ratchet、evidence parity 先於 upgrade smoke、契約凍結（v0.12.0）仍晚於本版全部內容。三版合一後 tag 間隔變長，任何 critical surface 不得因版本收斂而降級或略過；新增架構工作只能在既有 phase 後追加，不覆寫已完成的 milestone history。

### P0 — planning authority + current-tree evidence（2026-08-14）

> 這是 v0.11.0 後續工作的 immediate gate，不是新的 workflow engine。P0 完成前，
> 不開始 CC-517 的 production dogfood，也不把舊 tree 的 full-suite artifact 當作
> current main evidence。

| P0 work item | Required outcome | 狀態 |
|----|------|------|
| CC-532 scope reconciliation | Linux/WSL2 repo-layout canonical modules 視為本票 scope；standalone distribution／copy parity 移至 CC-546 | ⚠️ partial（2026-08-20 查證：`pr-gate.sh` 6,500→4,247 行，policy／subject／scope／assurance 已成模組，但 options 與 reviewer-contract 仍是空殼——33 個 option 分支留在 composition root，`gate-options.sh` 僅 2 個 setter。Requirement 1 尚未達成，不是 closure pending） |
| CC-533 foundation boundary | PR #480 保留為 schema-derived foundation；handwritten structural cleanup 與 version split 維持 partial，不擴大成 Gate workflow 重構 | ⚠️ partial（票面殘留工作明訂待 CC-517／CC-511 Phase B 穩定後才動，狀態正確） |
| Planning records | BACKLOG、MILESTONES、DECISIONS 使用同一份 scope/status | ✅ 2026-08-20（pr:#500 對齊 CC-511／CC-517／CC-527／CC-529 的實際交付；並以 `E-PARTIAL-DATE-STALE` 讓「body 記了新交付而 index 沒跟上」成為可機械偵測的失敗） |
| Current-tree full suite | 由 [[CC-511]] Phase A 吸收為 publish 前的常設不變式 | ✅ 2026-08-20（見同日 DECISIONS：這是每次 merge 就失效的不變式，不是可標記完成的工作項；publish path 已強制 current-tree authoritative PASS） |
| CC-546 | standalone distribution／installed copy bundle／canonical-dist parity 的獨立 deferred follow-up | ⏸ deferred |

### P1 — delivery closure evidence（2026-08-14 起動；垂直切片順序）

> P1 的目標是讓可信的 Gate evidence 真正收斂到「修正後的 final tree 為何可發布」；
> 不新增 `/deliver`、workflow engine、FSM 或新的 gate kind。每一片都必須保留
> initial review、remediation delta、affected tests、targeted confirmation 與
> authoritative full suite 的正交語意。

實作順序固定如下，後一片不得在前一片 contract 未穩定前啟動：

> 交付進度（2026-08-20 查證）：切片 1 已由 pr:#482 交付首片、切片 2 已由 pr:#483
> 交付 closure artifact、切片 3 已由 pr:#484 交付 shared publish assessment；三張票
> 均**未因此結案**，各自殘留見 BACKLOG。切片 4（CC-505）尚未啟動。

1. **CC-527 parity closure（active first slice）**：完成 truthful coordinate
   label 與 copy-mode／repo-layout、sequential／parallel meaning-parity fixtures；
   `tier`、`pass`、`coverage` 的 machine basis 與 human label 由 gate shell 維護。
2. **CC-517 remediation_closure_v1（next）**：只新增 immutable evidence artifact
   與 mechanical local／targeted／split classification，不建立 persistent lifecycle。
3. **CC-511 Phase B + CC-529（after closure schema）**：`/ship` 只消費 shared
   verifier 已驗證的 closure、tests、targeted confirmation 與 final-tree full-suite
   artifacts；stdout、PR body、finish marker 從同一份 verified assessment 產生。
4. **CC-505 Phase 1/2（after delivery closure dogfood）**：先做 lexical retrieval
   correctness，再做 shadow telemetry；不得先宣稱 token savings 或引入 embeddings。

P1 的每張實作 PR 都應綁定 deterministic contract tests；任何 reviewer coverage
或 publish policy 的自動降級，均不屬於本順序的隱含結果。

### Phase 1 — state compatibility surface（原 v0.11.0）

| 票 | 摘要 | 狀態 |
|----|------|------|
| CC-498 | layout/entity version 命名、`pmctl state status [--json]`、migration availability | ✅ pr:#435 |
| CC-500 | all-production-domain single-writer enforcement | ✅ pr:#438 |
| CC-507 | `state status` unreadable `VERSION` fail-closed exit contract | ✅ pr:#437 |

### Phase 2 — release evidence parity（原 v0.12.0 Phase 1）

| 票 | 摘要 | 狀態 |
|----|------|------|
| CC-449 | 吸收 CC-431：suite registry、CI parity、OpenCode、ship/worktree smoke | ✅ pr:#439 |

### Phase 3 — lifecycle ownership（原 v0.12.0 Phase 2）

| 票 | 摘要 | 狀態 |
|----|------|------|
| CC-504 | manifest-driven multi-host lifecycle，移除 Claude base-spine 特例；product receipt、selected-host ownership、legacy migration 與 doctor dispatch 完整交付 | ✅ pr:#442 |
| CC-508 | executor producer 的 parent-operation control plane：gate／ship 在 launch 前掛載 child、ownership-scoped cancel／reconcile、doctor 診斷；task dispatch 依票面不接入 | ✅ pr:#447 |

### Phase 4 — shared tooling/hooks host boundary（原 v0.12.0 Phase 3）

| 票 | 摘要 | 狀態 |
|----|------|------|
| CC-503 | canonical memory/payload/log roots + shared-layer content ratchet | ✅ pr:#445 |

### Phase 5 — operational evidence（原 v0.13.0 Phase 2）

| 票 | 摘要 | 狀態 |
|----|------|------|
| CC-358 | per-adapter outcome/failure/fallback run stats，供 release/readiness 報告引用 | 🔵 |

### Release qualification — v0.11.0 freeze 後

| 票 | 摘要 | 狀態 |
|----|------|------|
| CC-447 | offline clean install + latest released tag→v0.11 RC N-1 upgrade；foreign config/memory/user data 不變。屬正式 release evidence，若 release surface 改變即重跑 | 🔵 |

### Phase 6 — immediate publish correctness

> 依 2026-07-23 gate/delivery orthogonality decision，先堵住與新 review schema 無關的
> 發布漏洞：任何官方 ship path 都必須在 current tree full-suite artifact 通過後才可
> push／開 PR。

| 票 | 摘要 | 狀態 |
|----|------|------|
| CC-511 Phase A | direct／parallel ship publish path 共用既有 full-result verifier；stale/partial/skip/suite/tree drift 全部 fail closed | ✅ pr:#446 |

### Phase 7 — evidence + policy foundations

> 實作順序：CC-512 先鎖定 machine-owned assurance coordinates；CC-513 才能在同一
> vocabulary 上產 policy resolution；CC-515 最後把 structural evidence 與 immutable
> subject／freshness／consumer applicability 接起來。三者是不同責任，不合併成 profile。

| 票 | 摘要 | 狀態 |
|----|------|------|
| CC-512 | Slices A／B／C：coordinate sources／CLI resolution、machine-owned assurance envelope／evidence capture、shared verifier／parity ratchets；targeted 不再是 tier | ✅ pr:#451 |
| CC-513 | canonical resolver：minimum tier、required reviewers、mode recommendation／user-choice provenance、generic vs maintainer policy 與 tier/coverage downgrade audit | ✅ pr:#452 |
| CC-515 | immutable subject、三軸 shared verifier 與 downstream evidence link contract；scope／closure producers 分屬 CC-518／CC-517 | ✅ pr:#454 |

### Phase 8 — existing gate structured evidence

> 只強化既有 `pmctl gate run`；protocol completeness 與 live-model recall 分開，不新增
> gate kind、workflow engine 或 FSM。

| 票 | 摘要 | 狀態 |
|----|------|------|
| CC-518 | `gate_scope_manifest_v1`：immutable subject、changed/renamed/untracked、paired tests、signals、bounded expansion/truncation | ✅ pr:#455 |
| CC-519 | selected-reviewer coverage/finding contract；sequential logical sections 與 parallel session isolation 分開 | ✅ pr:#456 |
| CC-520 | synthesis findings-union parity、root-cause grouping、coverage matrix、remediation seed、no silent drop | ✅ pr:#460 |
| CC-521 | actionable test-gap matrix + bounded protocol recovery；seeded live recall 僅作 quality evaluation | ✅ pr:#470 |
| CC-522 | Slice A truthful preflight、Slice B QA partial evidence、Slice C external evidence disabled pending CI attestation | ✅ |
| CC-541 | host-side `QA_RULES_DIR` resolution/export + missing-source diagnostic | ✅ pr:#465 |
| CC-543 | full runner Phase 0 structural fail-fast + `--collect-all` | ✅ pr:#465 |
| CC-545 | evidence-reference-contract 違規 reviewer 單次修正性重派 | ✅ pr:#465 |

### Phase 9 — maintainer closure + publish authorization

| 票 | 摘要 | 狀態 |
|----|------|------|
| CC-528 | publish policy compatibility：generic current-tree initial GO 為 baseline、maintainer 為 preferred；ship 可驗證明確 supplied result | ✅ pr:#457 |
| CC-529 | publish assurance observability：ship stdout、PR body、finish marker 保留 producer policy 與 baseline/preferred satisfaction | ⚠️ partial 2026-08-15 |
| CC-517 | `/ship` primary review→local/targeted/split remediation closure→final affected/full tests；不虛稱 final-tree GO | 🔵 |
| CC-511 Phase B | final-tree review或 primary-review closure authorization + current-tree full PASS → publish | ⚠️ partial 2026-08-15 |

### Phase 10 — runtime foundation + Adapter authority（新增）

| 票 | 摘要 | 狀態 |
|----|------|------|
| CC-530 | source-safe runtime libraries + unified identifier policy；source-side-effect contract、production/copy-mode consumer parity 與 current-tree full-suite evidence 已完成 | ✅ closed 2026-08-12 (pr:#473, closure) |
| CC-531 | canonical `dispatch_entrypoint`、schema v1 bounded migration、copy-mode reader/manifest parity | ✅ 2026-08-11 |

### Phase 11 — Gate security + coordinate cleanup（新增）

| 票 | 摘要 | 狀態 |
|----|------|------|
| CC-526 | reviewer override symlink／replacement trust-boundary hardening | ✅ pr:#475 |
| CC-527 | targeted pass、reviewer coverage 與 tier 的 CLI coordinate 分離；tier 由 current subject/policy 解析，仍待 complete parity closure | ⚠️ partial (pr:#472, #476) |

### Phase 12 — Gate canonical source + schema foundation（新增）

| 票 | 摘要 | 狀態 |
|----|------|------|
| CC-525 | 修正 verifier fallback provenance 並鎖定唯一 generator；generator identity、marker、provenance 與 body parity 已有 fail-closed ratchet | ✅ closed 2026-08-13 |
| CC-532 | Linux/WSL2 repo-layout canonical Gate modules；P0 current-tree evidence 後 closure，standalone distribution 移至 CC-546 | ⚠️ partial |
| CC-533 | PR #480 schema-derived structural validation foundation；handwritten structural cleanup 與 version dispatch separation 待 delivery schema 穩定後收尾 | ⚠️ partial |

### 計畫外同期 correctness hardening（已合併 main）

| 交付 | 摘要 | 狀態 |
|------|------|------|
| PR #469 | SQLite memory usage concurrency、portable lock fencing、operation/sentinel consistency、suite temp/state isolation 與 gate readiness race hardening | ✅ |

### 待後續 / 明確排除

- 沒有真實 N→N+1 path 時不建空 migration engine，也不宣稱 `state migrate` 可用。
- 真實 auth 的 end-to-end live dogfood 留到 v1 readiness review；本版先建立可重現的 offline/upgrade evidence。
- bootstrap wizard 仍由 smoke 的真實摔倒點決定，不預先實作。
- 不從 advisory record 推導 success；無可信證據時保留 indeterminate。
- memory product expansion 不因 telemetry 名稱相近而併入本版。
- CLI registry、supervised-run kernel、Adapter SDK、test registry、Host primitive 與
  state-layout generation 以 CC-534～CC-539 保留在 backlog，不擴入 v0.11.0。
- Tier、mode、reviewer coverage、independence、subject 與 publish authorization 不互相推論；`full` 不等於 parallel，parallel 不等於 full coverage。
- 不在本版新增 `/deliver`、新 gate kind、workflow profile/preset、persistent workflow state 或 FSM；CC-517 只調整 repo-owned maintainer `/ship` policy，其他使用者可繼續自由組合 generic primitives。thin wrapper 只有在 CC-514 後的真實分類證據觸發 CC-516 才評估。

---

## v0.10.0 — detached cancel safety + reconciliation（✅ released 2026-07-20）

> 最後排程更新：2026-07-20（✅ released：tag `v0.10.0` + GitHub Release；CC-499 提前交付入帳、後續版次重整）

**主題**：只補 detached lifecycle 的中止對稱面；先把 process identity、terminal race 與 completion evidence 做對，再談 crash/reboot recovery。

### Phase 1 — trusted cancellation

| 票 | 摘要 | 狀態 |
|----|------|------|
| CC-495 | process-group cancel、PID identity、terminal CAS、authenticated cancelled sentinel、wait distinct exit | ✅ pr:#428 |

### Phase 2 — bounded correctness hardening

| 票 | 摘要 | 狀態 |
|----|------|------|
| CC-452 | guard/hook 對稱性與併發 hardening（僅 lifecycle correctness 直接相關 slice） | ✅ pr:#431 |
| CC-453 | worktree/auto-pack 路徑契約 hardening（僅 lifecycle correctness 直接相關 slice） | ✅ pr:#430 |

### Phase 3 — detached run reconciliation（提前交付）

> 原排 v0.13.0 Phase 1；實作於 tag 前即合併進 main，隨本版 tag 出貨，故入帳本版並納入 release audit 範圍。

| 票 | 摘要 | 狀態 |
|----|------|------|
| CC-499 | conservative reconcile、doctor stale-run diagnostics、PID reuse/key-loss/crash tests | ✅ pr:#429 |

### 待後續 / 明確排除

- 不做 pause/resume 或完整 dispatch list。
- cancel 若依賴 workspace 可偽造資料、刪除 completion proof 或可能誤殺 reused PID，本版不得 release。
- reconcile 不從 advisory record 推導 success；無可信證據時保留 indeterminate。

---

## v0.9.0 — migration closure + CLI discoverability（✅ released 2026-07-18）

> 最後排程更新：2026-07-18（release closure）

**主題**：讓 CC-489 後的產品表面追上 current tree，並讓第一次接觸 `pmctl` 的使用者能只靠 CLI/README 找到正確操作。本版不宣稱接近 v1.0，也不凍結完整 public contract。

> **設計依據**：151 個 implementation/fixture path 已搬遷且 full runner 79 passed，但 compatibility shims 仍掩蓋 docs/CI/backlog 漂移；同時 root/area help 缺失使現有能力對使用者不可發現。

> **交付記錄邊界**：下列 Phase 0–5 是 `v0.8.0` tag（2026-07-04）之後已合併到 `main`、但尚未形成下一個 release tag 的成果，不代表 v0.9.0 已 release。Phase 6 起才是目前 remaining scope。

### Phase 0 — host abstraction 與跨 host PM surface（✅ 已交付）

| 票 | 摘要 | 狀態 |
|----|------|------|
| CC-436 / CC-437 / CC-438 | Codex PreToolUse probe、host-aware doctor、host manifest schema v1 | ✅ pr:#372/#374/#375 |
| CC-457 | Claude host manifest reference instance，讓三 host 使用同一 capability schema | ✅ pr:#381 |
| CC-445 / CC-448 | manifest-driven install/doctor/guard write path；OpenCode 作 N=2 host 驗收 | ✅ pr:#384/#395 |
| CC-471 / CC-473 | 確認 Codex 無 Claude-style 互動 subagent 入口，交付 batch-only `pmctl pm prepare/run` | ✅ spike + pr:#391 |
| CC-480 | Claude→Codex/OpenCode host-switch memory continuity 與 deterministic hydration | ✅ pr:#394 |

### Phase 1 — context 與 canonical memory correctness（✅ 已交付）

| 票 | 摘要 | 狀態 |
|----|------|------|
| CC-455 | context plane 預設跟隨 CWD git toplevel，不再誤打 pm-dispatch 自身 DB | ✅ pr:#371 |
| CC-459 | prompt-scan retrieval reflex、PM Retrieve step、零敏感 prompt telemetry | ✅ pr:#379 |
| CC-483 | Claude/Codex/OpenCode 統一使用 canonical `pmctl memory` resolver/writer | ✅ pr:#399 |
| CC-484 | JapanJob／qa-testing-rules context refresh 與 marker round-trip 修復 | ✅ pr:#397 |
| CC-488 | Codex prompt/session lifecycle hooks、explicit canonical update seam、host provenance | ✅ pr:#401 |
| CC-490 | project-scoped explicit memory config，修復跨 repo canonical bleed | ✅ pr:#406 |
| CC-492 | Claude UserPromptSubmit timeout envelope 與殘缺 context DB 復原 | ✅ pr:#403 |

### Phase 2 — gate、runner 與操作安全（✅ 已交付）

| 票 | 摘要 | 狀態 |
|----|------|------|
| CC-458 | gate run/wait 的 `--cd` 預設、可複製 wait hint、verdict/exit contract | ✅ pr:#378 |
| CC-469 | Codex reviewer sandbox 使用 absolute `pmctl` path | ✅ pr:#388 |
| CC-470 | sequential gate timeout 止血、test-first fail-fast、慢 suite enforcement | ✅ pr:#383 |
| CC-474 | dispatch/gate reasoning effort 獨立參數化，預設 medium | ✅ pr:#387 |
| CC-477 | guard memory usage sidecar 並發 lost-update 修復 | ✅ pr:#396 |
| CC-481 / CC-482 | direct-impact iteration vs final evidence 分層、reviewer 最小讀取權限 | ✅ pr:#397 |
| CC-485 | 工具能力與 maintainer policy 分離；固定本 repo release procedure | ✅ pr:#398 |
| CC-487 | GitHub Actions `test-guards` bounded diagnostics 與非確定性 hang hardening | ✅ pr:#402 |
| CC-491 | reusable pre-flight evidence、suite results、tree fingerprint、reviewer reuse contract | ✅ pr:#408；full 79 passed |
| CC-496 | Codex command guard one-turn bypass transport 與 audit contract | ✅ pr:#407 |

### Phase 3 — model/adapter compatibility maintenance（✅ 已交付）

| 票 | 摘要 | 狀態 |
|----|------|------|
| CC-475 | Claude sonnet alias 對齊 `claude-sonnet-5` | ✅ pr:#389 |
| CC-476 | OpenCode headless deny hang root-cause spike、timeout/permission workaround | ✅ pr:#390 |
| CC-478 | Codex default alias 對齊 gpt-5.6 系列 | ✅ pr:#392 |
| CC-479 | model alias 表改名為 Codex-specific，補回 Claude legacy aliases | ✅ pr:#393 |

### Phase 4 — core/runtime definition 與 domain migration（✅ 已交付）

| 票 | 摘要 | 狀態 |
|----|------|------|
| CC-451 | core enum 單一來源、state writer runtime schema validation | ✅ pr:#409 |
| CC-489 | host write ABI、path resolver、OpenCode/Codex/Claude modules、151 個 implementation/fixture path 搬遷與 19-shim ratchet | ✅ pr:#405/#410–#415 |

### Phase 5 — supporting hygiene（✅ 已交付）

| 票／PR | 摘要 | 狀態 |
|--------|------|------|
| CC-004 / pr:#369 | `test-pr-gate.sh` docstring 統一與 docstring ratchet | ✅ |
| pr:#376 | docs-freshness milestone heading-only regression 修復 | ✅ |
| pr:#386 | 19 張 terminal backlog tickets canonical archive sweep | ✅ |
| CC-486 / pr:#400 | affected-test registered-suite selection、agent/command/skill regression 與 maintainability-review/gate workflow ordering hardening | ✅ |

### Phase 6 — migration surface closure（目前 working set）

| 票 | 摘要 | 狀態 |
|----|------|------|
| CC-497 / pr:#417 | canonical paths、docs/backlog/milestone/release metadata、stale-reference ratchet | ✅ |
| CC-456 / pr:#418 | 移除 maintainer-local `~/github` operational assumptions | ✅ |
| CC-454 / pr:#420 | canonical ShellCheck domains + ignore ratchet + CI/local parity | ✅ |

### Phase 7 — user-facing CLI discovery（✅ 已交付）

| 票 | 摘要 | 狀態 |
|----|------|------|
| CC-460 | root/area/leaf help、command registry、`commands --json`、router/help/README parity | ✅ pr:#421 |

### Phase 8 — release migration evidence + host-boundary blocker（✅ 已交付）

| 票 | 摘要 | 狀態 |
|----|------|------|
| CC-502 | shared gate/reviewer移除 `.claude` asset與memory前置 | ✅ pr:#422 |
| CC-501 | v0.8.0→v0.9 candidate install/upgrade/doctor/uninstall preservation smoke | ✅ pr:#424 |

### Parallel audit（不阻塞 Phase 6/7）

| 票 | 摘要 | 狀態 |
|----|------|------|
| CC-033（audit slice only） | git-history 敏感內容／損害盤點；public copy 不在本版修改 | ✅ 2026-07-18；結果：`docs/audits/CC-033-git-history-audit.md` |

### 待後續 / 明確排除

- CC-495/498 之後的 lifecycle/state 能力不塞入 v0.9.0。
- CC-503/504 的全面 shared hook/tooling與 host lifecycle收斂留 v0.12.0；v0.9只處理 CC-502 gate blocker與 CC-501一次性 migration evidence。
- public posture、contract freeze、RC 與 v1.0 tag 均不屬本版。
- Phase 0–5 只記錄已合併 baseline，不重新開工、不占用 Current working set。

---

## v0.8.0 — memory substrate 跨工具可攜 + gate DX（✅ released 2026-07-04）

> 最後排程更新：2026-07-04（release closure CC-444）

**主題**：延續 v0.6.0（executor abstraction）與 v0.7.0（retrieval-base：memory 成為 `pmctl context` 可檢索 source）兩版已交付的抽象工作，補上最後兩個 Claude 專屬耦合點——**memory 位置 resolver** 與 **注入機制**（CC-412，headline）；並行做兩張範圍小、風險低、彼此檔案面不重疊的 gate DX 票（CC-276、CC-423）；另起一個 spike-only phase 把 CC-381（host-PM-aware install）從「設計問題陳述」推進到「有具體 Requirement 的實作票」，為下一版鋪路。

> **設計依據**：2026-07-01 四路獨立分析收斂——主線程 BACKLOG 掃描、codex 獨立 read-only audit、opencode 獨立 read-only audit、外部 chatgpt 研究文件（僅在前三者完成後才讀取），四者皆將 CC-412 列為第一優先。CC-381 原被四方共同建議延後，但覆核發現其前置票（CC-372/374/375/380）已全數 ✅ done，排除理由修正為「設計未收斂」而非「規模過大」，故改列 spike-only phase 而非整票延後。

### Phase 0 — release 文件 drift 清理（P3；無票號，直接修正）

> 純文字修正，零行為風險，與 Phase 1 的 load-bearing 向後相容要求無關，獨立 PR 先行，不與 CC-412 混批審查。

- README 版本徽章：`v0.6.0` → `v0.7.1`
- MILESTONES.md v0.7.1 標頭：「規劃中 2026-06-29」→ 標記已 released（tag + GitHub Release 已於 2026-06-30 建立）
- CC-333 index/body 狀態同步：index 標 `⏸ deferred`（BACKLOG.md 之前），body heading 標 `🔵 active`，需一致

### Phase 1 — memory substrate 跨工具可攜（P3；headline；load-bearing 向後相容）

| 票 | 摘要 | 狀態 |
|----|------|------|
| CC-412 | memory substrate 跨工具可攜：(a) 位置 seam — `find_memory_dir` 支援 `PM_MEMORY_DIR`（或 `dispatch.memory_dir` config）顯式覆寫，解析優先序 env > config > `CLAUDE_CONFIG_DIR` 慣例，未設時行為與今天 byte-identical；(b) 注入分層文件化 — 「可攜核心＝`pmctl context --source memory` retrieval API；注入＝per-tool adapter」，Claude 沿用現有 hook，codex/opencode/未來 host 改為主動呼叫 retrieval API | ✅ done pr:#352 |

> 兩子需求耦合度低，若實作時發現超出 medium 估計，可拆 Phase 1a（代碼）/ 1b（docs）降低單一 PR 審查負擔。

### Phase 2 — gate DX（P3；低風險並行；與 Phase 1 檔案面不重疊）

| 票 | 摘要 | 狀態 |
|----|------|------|
| CC-276 | persistent gate override declarations：`--override-file` 或自動探索 `.gate-overrides.md`，inject 到 reviewer prompt 前置脈絡，避免已接受的 risk override 每輪重新聲明 | ✅ done pr:#301（規劃前已交付，覆核發現） |
| CC-423 | gate detached lifecycle：`pmctl gate run --lifecycle detached`（現為預設）回傳 gate_id 立即退出；gate-supervisor 以 nohup/setsid 跑 pr-gate.sh；sentinel 機制 + `pmctl gate wait <gate_id>` 輪詢，result 完整性 fail-closed，鏡像既有 `dispatch --lifecycle detached` 模式 | ✅ done pr:#353 |
| CC-433 | detached lifecycle 收尾：(1) 抽出 dispatch/gate 兩份 supervisor 共用的 sentinel 啟動邏輯成共用 lib；(2) `pmctl dispatch wait`/`pmctl gate wait` 的輪詢改主動通知。CC-423 交付後發現的改善項，spike 收斂於 `docs/spikes/CC-433.md` | ✅ spike done；(1) lib GREEN → CC-434 落地 pr:#356；(2) poll→通知 AMBER 不採，殘餘 → CC-435（條件觸發 someday） |
| CC-432 | run-all-tests.sh 耗時瓶頸：`test-release-verify.sh` 12 個重複 `--no-suite` 呼叫改共用快取（`rv_no_suite_once`），380s → ~127s。方向 A（Phase 3 smoke 改隔離假 repo）與 `LIVE_DB_EXCLUSIVE` 序列化耦合窄化皆評估後擱置不追（風險高於效益，未來可重新評估） | ✅ done pr:#354 |
| CC-425 | gate 解除 PR 綁定：`pr-gate.sh --head <ref>` 新增，以既有 `--base` 相同的 merge-base（three-dot）語意 diff 一組固定 ref，不涉 PR/working tree；盤點發現 result 路徑 PR# key 問題已在 CC-423 detached lifecycle 重構中解決（改用 gate_id），`--base` 也已支援無 PR 場景，故實際範圍小於原評估 | ✅ done pr:#355 |

> CC-433 排入 Phase 2 作為 CC-423 的後續收斂項，非阻塞本 Phase 其餘票的完成。CC-432 為 CC-423 pr-gate 迭代中發現並記錄的衍生票，同樣併入 Phase 2。CC-425 原評估「需重構 gate result key schema，範圍比 CC-276/423 大一截」暫不排入，2026-07-02 使用者確認排入本 Phase 處理；實作前盤點發現 result key 已在 CC-423 detached lifecycle 重構中改為 gate_id-keyed，範圍縮小為僅需新增 `--head <ref>`，`/pre-impl` 的向下相容顧慮已不適用，見 pr:#355。

### Phase 3 — CC-381 spike-only（P3；design 收斂，非完整實作）✅ spike done pr:#359

| 票 | 摘要 | 狀態 |
|----|------|------|
| CC-381 | install host-PM-aware — 縮小為 read-only host-profile-detection / doctor 擴充切片：讓 `doctor.sh`/`pmctl doctor` 能回答「目前 host 是 claude/codex/opencode？哪些能力有 wiring？哪些只能透過 pmctl 手動使用？」不動 installer write path。前置票 CC-372/374/375/380 已全數 done，本 Phase 目標是把 CC-381 從設計陳述推進為有明確 Requirement 的實作票 | ✅ spike done pr:#359 |

> **Phase 3 結果**：2026-07-02 三方獨立分析（主線程/codex read-only 實測/chatgpt 外部視角）收斂於 `docs/spikes/CC-381.md`。最大不確定性（codex hook 機制是否足以承接 write/bash guard）已由 codex 自身唯讀實測解答：`PreToolUse` hook stable 且 fail-closed，足以承接，不必退回 cli-only fallback。CC-381 從設計陳述推進為三張有明確 Requirement 的後續票：**CC-436**（codex PreToolUse payload 驗證 probe，第一刀，唯讀）、**CC-437**（doctor 擴充切片，可與 CC-436 並行）、**CC-438**（host manifest schema v1 draft，依賴 CC-436）。三票排入下一版（v0.9.0 候選，待排程）評估，`install.sh` write path 仍不動。

### Phase 4 — CC-014 repo 通用 worktree 平行開發工具（P3；低風險並行；與 Phase 1-3 檔案面不重疊）

| 票 | 摘要 | 狀態 |
|----|------|------|
| CC-014 | repo 通用 worktree 建立/列出/清理工具 + `using-git-worktrees` skill，支援多票並行開發；`--parallel` PR gate reviewer 隔離整合留待未來 follow-up ticket，未併入本次範圍 | ✅ done pr:#358 |

> 由 CC-050 稽核降級的 ⏸ deferred（無開放分支）重新啟用；2026-07-02 範圍由「pr-gate reviewer 隔離」擴大為「repo 通用 worktree 工具」；規劃時尚未有實作分支，範圍與時程由後續 `/pre-impl` 或直接 dispatch 時再收斂。

### Phase 5 — 計畫外同期 ship（規劃外交付，v0.8.0 開發期間完成）

> ship 系列（CC-439→443）為 v0.8.0 排程後由使用者需求驅動的計畫外主線；CC-434 為 CC-433 spike GREEN 結論的即時落地；CC-214 為文件 hygiene。均已各自過 pr-gate。

| 票 | 摘要 | 狀態 |
|----|------|------|
| CC-434 | 抽共用 detached-launch lib（`scripts/lib/detached-launch.sh`，7 函式）；dispatch/gate 兩 supervisor + wait 端改共用，行為位元組不變 | ✅ done pr:#356 |
| CC-214 | platform-support.md 手動 uninstall 指令錨定 `PM_DISPATCH_REPO` | ✅ done pr:#362 |
| CC-439 | `/ship <ticket-id>` command：明確票直接實作到開 PR，pre-flight 一致性檢查 + gate 迴圈收斂 | ✅ done pr:#360 |
| CC-440 | spike: `/ship` 並行版可行性，五項設計決策收斂（`docs/spikes/CC-440.md`） | ✅ spike done pr:#361 |
| CC-441 | `pmctl ship prepare/finish` + `--parallel` N-lane orchestrator v1（建在 CC-014 worktree 上，保留 CC-439 ship 契約） | ✅ done pr:#363 |
| CC-442 | spike: 統一 `pmctl ship <ticket-id>` 單一入口，三項決策收斂（`docs/spikes/CC-442.md`） | ✅ spike done pr:#364 |
| CC-443 | 實作：統一 `pmctl ship <ticket-id>` start 入口（`--worktree`/`--adapter`；`ship-lanes.jsonl` tracking；`dispatch-failed` 狀態） | ✅ done pr:#365 |

### Phase 6 — release closure（tag 前完成）

| 票 | 摘要 | 狀態 |
|----|------|------|
| CC-444 | v0.8.0 release closure：`/pre-release v0.8.0` 稽核 → CHANGELOG 補全（Layer 1 抓到 6 票缺漏 + ship 系列）→ MILESTONES/README 收斂 → release notes → tag | ✅ pr:#367 |

### 待後續 / 明確排除

- **CC-358（runner telemetry）**——與 CC-412 無架構相依，更適合作為 v0.9.0 gate 決策的前置證據，不排入本版。
- **CC-346 Phase a（bash source ref index）**——BACKLOG.md 明文 resume trigger（reuse-scan 進過 ≥2 份真 brief）尚未觸發，排入即覆蓋票自身 gating 準則，未排入。
- **CC-216 MCP**——2026-06-18 已拍板不排入任何 milestone，維持排除。
- **CC-340 embeddings**——維持排除，同既有立場，待 FTS/LIKE ranking 證明不足再 resume。
- **CC-377 agy adapter**——等待 agy headless CLI 版本更新，不排入。
- **CC-381 完整實作**（installer write path、多 host 設定面改寫）——Phase 3 spike 已收斂為 CC-436/437/438 三張後續票（見上方 Phase 3 結果），installer write path 仍留給這三票驗證完成後的下一版評估。

---

## v0.7.1 — release 工具完整化 + 積累 hygiene 清掃（✅ released 2026-06-30）

> 最後排程更新：2026-06-29

**主題**：兩條主軸並行——(1) 完善 release 工具鏈：補上 `/pre-release` Layer 2 語義比對，讓報告從「tracking hygiene 乾淨」升級到「PR diff 實際覆蓋 Requirement 可追溯」；(2) 清掃 v0.4.0–v0.7.0 期間累積的 guard/test/ops P3 hygiene 票群。小而聚焦的點版本，**不引入新能力架構**。

> **設計原則**：v0.7.1 是 v0.7.0 之後的穩定化版本，不開新能力前線。每張票都有明確 Requirement 且可獨立 ship。CC-422（dispatch-common spike）、CC-216（MCP）、CC-377（agy headless CLI）明確不排入。

### Phase 1 — release 工具鏈完整化（P1；headline）

| 票 | 摘要 | 狀態 |
|----|------|------|
| CC-430 | `/pre-release` Layer 2：主線程逐 ticket 讀 BACKLOG Requirement + `gh pr diff` 分析覆蓋度，輸出 per-ticket 結論表。相依 [[CC-426]]（Layer 1 ✅）、[[CC-403]]（memory context ✅）、[[CC-404]]（注入預算 ✅）。Layer 2 不輸出 GO/NO-GO，判斷留給人 | ✅ pr:#339 |

### Phase 2 — guard / install hygiene（P3；guard 安全加固 + install 正確性）

| 票 | 摘要 | 狀態 |
|----|------|------|
| CC-210 | `uninstall.sh` blast-radius guard：加 `[[ "$dst" == "$managed_root" ]]` 精確路徑拒絕，防止 managed-root 本身被刪；補 test case。PR #110 gate [medium] advisory 遺留 | ✅ pr:#340 |
| CC-258 | `pm-write-guard` hook 政策修訂：加三條合法 PM-author allow rule（`/tmp/<slug>/*.md`、`docs/spikes/{CC-NNN*,*-scope,*-rfc}.md`、symlink memory 雙正規化）；補 ~15 條迴歸測試 | ✅ pr:#342 |
| CC-224 | `doctor.sh` ↔ `install-hooks.sh` hook-profile 一致性：抽共用 `scripts/hook-profile.sh` 或加 parity test，防止新 hook 加入只更新一處的靜默漂移 | ✅ pr:#341 |

### Phase 3 — test / ops 可靠性（P3；測試基礎建設）

| 票 | 摘要 | 狀態 |
|----|------|------|
| CC-240 | `test-portable.sh::case_mkdir_lock_contention` 替換固定 `sleep 1.2`：改用 FIFO-gated IPC 同步，消除 CI 時序不確定性（qa-testing-rules 紅線：不用 sleep 做非同步同步） | ✅ pr:#344 |
| CC-285 | archiver safe-drop：terminal row 的 body 在 BACKLOG.md 與 BACKLOG-ARCHIVE.md 都不存在時，保留 row 並 emit 警告（不刪），供人工處置；加迴歸 fixture | ✅ pr:#343 |

### Phase 4 — adapter 共用邏輯抽 lib（P3；可選；不依賴 Phase 1–3）

| 票 | 摘要 | 狀態 |
|----|------|------|
| CC-420 | adapter 共用 model alias TSV 解析 → `scripts/lib/model-aliases.sh`；claude / codex / opencode 三 adapter ~30 行重複消除 | ✅ pr:#345 |
| CC-421 | adapter 共用 timeout 優先序邏輯 → `scripts/lib/timeout-resolve.sh`；3 adapter + post-verify ~15 行×4 重複消除 | ✅ pr:#346 |

> Phase 4 兩張票可獨立 ship，與 Phase 1–3 無依賴。CC-422（dispatch-common.sh）需先 spike 確認邊界，**不排入本版**。

### 待後續 / 明確排除

- **CC-422（adapter dispatch-common）**——需 spike 確認邊界再實作，不排入 v0.7.1。
- **CC-032（`[[feedback_*]]` 公開化）+ CC-033（Public flip）**——CC-032 仍 🔵 active 但無明確時程；CC-033 依賴 CC-032，整組後置評估，若 CC-032 本版完成可順帶納入。
- **CC-286（pmctl prefix-generic next-id）**——P3 arch 設計，不阻塞任何已排項目，後置評估。
- **CC-216 MCP server**——明確不排入任何 milestone（2026-06-18 user 拍板）。
- **CC-377 agy adapter**——等待 agy headless CLI 版本更新，不排入。
- **Layer 3（embeddings / 全語意 backend）**——屬 CC-340 殘餘，不排入本版。

---

## v0.7.0 — retrieval-first context discipline + memory 檢索基底（✅ released 2026-06-29）
> 最後排程更新：2026-06-26

**主題**：讓「找既有資料」這件事真的**優先走內建 `pmctl context`**，並把 memory 變成可被檢索的 source——分兩層：行為層（context-first 紀律，在單一 chokepoint 強制）+ 能力層（memory 成為 `pmctl context` 的 source、收斂單一檢索入口、治理 memory 自身的 inject bloat 與 staleness）。

> **設計依據**：2026-06-18 memory + `pmctl context` 統整（opus 獨立分析 + codex 獨立第二意見 + 外部 chatgpt/gemini/grok 研究對照）。核心洞察兩層：(1) **能力缺口**——`pmctl context` 的 index 只掃 repo 內檔，memory（repo 外 `~/.claude/projects/<id>/memory/`）**完全搜不到**，故對「決策/規則/偏好」這類最常找的特定資料，「優先用 pmctl context」物理上不可能；(2) **行為缺口**——即使能力補上，prompt 裡的「reflex」會在壓力下退化成 grep，必須在**單一 chokepoint 強制**（[[feedback_cut_capability_close_all_paths]]）。

### Phase 1 — retrieval-first context discipline（P2；行為層，可先行）

> 純 prompt/command/validator/dispatch，**不**碰 memory 索引引擎；風險低、最快改變行為。

| 票 | 摘要 | 狀態 |
|----|------|------|
| CC-400 | prompt/docs 檢索順序強制：project-pm Principle 3 改硬性「context query →（no hits 才）Read/Grep」；context-retrieval.md 升級為「Query before Read/Grep/full-file open」。純文件，零程式風險 | ✅ pr:#308 |
| CC-401 | brief-validate retrieval 證據 chokepoint：非 trivial brief 須有 `context:`／`auto_context:`／`retrieval_skip_reason:`，先 warn 後 fail（`BRIEF_VALIDATE_RETRIEVAL`）。把 reflex 釘成合約。相依 [[CC-400]] | ✅ pr:#308 |
| CC-402 | auto-pack 與 detached lifecycle 相容（augmented brief 記為 run-spec trusted brief_file）+ gate 改驗 effective brief；`dispatch.auto_pack` 預設翻 on、`BRIEF_VALIDATE_RETRIEVAL` 預設翻 fail（CC-401 fail-flip）。HARD security/risk gate。相依 [[CC-399]] | ✅ pr:#309 |

### Phase 2 — memory 檢索基底（P2-P3；能力層）

> 讓 memory 成為 `pmctl context` 的可檢索 source，並收斂出單一檢索入口；同時治理 memory 本身的 inject bloat 與 staleness。

| 票 | 摘要 | 狀態 |
|----|------|------|
| CC-403 | `pmctl context --source repo/memory/all`：memory 變可檢索 source（memory-local DB、schema `source_domain` 補 memory、pack `memories[]` 填值、reuse-scan 維持 repo-only）。**supersede/吸收 [[CC-340]] MVP**，embeddings 留 CC-340 | ✅ pr:#313 |
| CC-404 | `MEMORY.md` 注入硬預算（20 條/3000B）+ `priority: always` pin + prompt-keyword 排序，取代「全注入 + >=50 才警告」。usage-based 動態排序分流至 [[CC-427]] | ✅ pr:#328 |
| CC-405 | memory card frontmatter 標準化（topics/priority/status/updated_at/repo_refs）+ read-only `/mem-doctor` 健檢（dead links、stale repo_refs、未引用 card、episodes 大小） | ✅ pr:#315 pr:#327 |
| CC-406 | `/mem-search` 改走 `pmctl context --source memory`，rg 僅 fallback。相依 [[CC-403]]（之前 /mem-search 無法誠實「優先用 pmctl context」） | ✅ pr:#325 |
| CC-407 | episodes 衍生摘要/索引 + 歸檔策略（append-only 保留，加可重建 summary/index、shard/archive）。延伸 [[CC-234]]。優先度最低 | ✅ pr:#330 |
| CC-411 | context 測試並行安全隔離：拔除對活 repo 耦合，讓測試套件可在並行/隔離環境正確跑完 | ✅ pr:#314 |
| CC-424 | memory commands 去 python3 化：純 bash 改寫 + `pmctl memory dir` 行為隔離 + 測試覆蓋 | ✅ pr:#326 |
| CC-427 | tier1 只認 `priority: always`（pin），normal 卡改 usage-based recency+frequency frecency 排序（Firefox bucket `access_count×age_bucket` + W-TinyLFU 老化，純整數零 LLM）；修 [[CC-404]] 預算因 33 卡全 `status: active` 失效。Phase 1 spike → Phase 2 實作 | ✅ pr:#329 |
| CC-428 | lifecycle validity gate：stale/superseded card 不因高 usage frecency 排前；`priority: always` bypass；bucket=0 降等 + 5 新測試。相依 [[CC-427]] | ✅ pr:#332 |

### Phase 3 — guard 術語 hygiene（P3；與 retrieval 主線正交，已解鎖可獨立 ship）

> 純命名脫鉤，**零行為改動**：`hook-*.sh`（8 檔）/ `hook-framework.sh` / `hk_*`/`HK_*` 函式 / `PM_HOOK_*` env → 平台中性 `guard-*`；`settings.json` 的 `PreToolUse` 鍵保留（Claude 平台自有）。獨立 PR，不可與安全邊界票混搭。前置 [[CC-376]] ✅ 已達成；[[CC-377]] deferred 不阻本票。

| 票 | 摘要 | 狀態 |
|----|------|------|
| CC-384 | `hook-*.sh` → `guard-*.sh`、framework/helper/env 前綴一起掃；install/uninstall/doctor 接線 + parity scanner + 測試 + 文件同步。[[CC-333]] layer 2/6 | ✅ pr:#310 |

> **排序紅線**：Phase 1（CC-400→401）行為層可先做，立即回答「如何讓檢索優先用 pmctl context」。Phase 2 能力層中，[[CC-403]] 是 [[CC-406]] 的前置（memory source 不存在前 /mem-search 改不了）；[[CC-405]] metadata 宜先於或同捆 [[CC-404]] 注入預算（否則預算截斷可能蓋掉關鍵約束）。**逃生口**：Phase 1 可獨立提前到 v0.6.x 點版；Phase 2 若評估過重可單獨延 v0.7.x。

### Phase 4 — artifact relocation + test infra（與 retrieval 正交；v0.6.0 後同期 ship）

> CC-003 epic（artifact-relocation）與 CC-409/CC-410 在 v0.7.0 開發期間完成，功能主題與 retrieval 正交但為 v0.7.0 期間的 commit。

| 票 | 摘要 | 狀態 |
|----|------|------|
| CC-409 | `run-all-tests` 並行執行（`--jobs N`，預設 nproc）+ dispatch-wait poll 可設定；大幅縮短本機測試時間 | ✅ pr:#311 |
| CC-410 | guard audit log 對唯讀 `hooks.log` fail-silent：wrap append 在 subshell 以正確抑制 bash 重導向錯誤 | ✅ pr:#311 |
| CC-413 | Phase 0 止血：pr-gate integrity check 排除自身 artifact 路徑，避免 gate 誤判 own outputs | ✅ pr:#318 |
| CC-414 | Phase 1：trace-root seam（`--trace-dir` flag / env 優先序）——adapter 可覆蓋 trace 落點 | ✅ pr:#319 |
| CC-415 | Phase 2：post-verify containment guard 改以 `--run-dir` 為界；退場 in-repo path 假設 | ✅ pr:#320 |
| CC-416 | Phase 3a：gate artifacts 搬出 repo（`run-dir` seam 接線，原始 artifact 路徑 bug 修復） | ✅ pr:#321 |
| CC-417 | Phase 3b：normal dispatch artifacts 搬出 repo（與 Phase 3a 對稱） | ✅ pr:#322 |
| CC-418 | Phase 4：observer + `pmctl artifacts list/show` 可發現性介面 | ✅ pr:#323 |
| CC-419 | Phase 5：翻預設 out-of-repo + GC + 跨 repo 既有副產物遷移；close CC-003 epic | ✅ pr:#324 |

### Phase 5 — release closure（2026-06-26 追加；tag 前完成）

> Phase 1–4 全部完成。Phase 5 是 release 的最後兩張：先建工具（CC-426）、再用工具對自己審查一次（CC-429）。

| 票 | 摘要 | 狀態 |
|----|------|------|
| CC-426 | `/pre-release` milestone 落地審查工具 — Layer 1 結構檢查（ticket body 有無待辦、PR# 覆蓋、CHANGELOG range）+ Layer 3 盲點聲明。輸出報告非 GO/NO-GO。Layer 2 語義比對移至 [[CC-430]]。 | ✅ pr:#334 |
| CC-429 | v0.7.0 release closure：對自身跑 `/pre-release v0.7.0`；修 CHANGELOG/MILESTONES/BACKLOG drift；寫 release notes；tag v0.7.0。相依 [[CC-426]] | ✅ pr:#335 |

### 待後續 / 與本版正交

- **CC-216 MCP server（DEFERRED，不排入 milestone）**——「通用橋」讓任意 MCP-aware host 透過單一協定使用 pm-dispatch。**2026-06-18 user 拍板：先 defer、不排入任何 milestone，待核心（executor 抽象 + retrieval/memory 基底）覺得**基本都穩定**後再考慮**。重型 net-new surface（Node/Python server + `pmctl --json`），需穩定 pmctl + 已收口 executor 抽象作下層。相依 [[CC-211]]、[[CC-215]]。
- **CC-273（unified lifecycle *hook event* spec）**——tool-step hook 事件（user-extensibility seam），與 process lifecycle（v0.6.0 Phase 7）正交；待出現第二個 hook 點需求再做。
- **CC-333 七層耦合 1/4/7**（memory / install-target / reviewer memory 讀取軸）——與 executor 抽象軸正交，獨立排程。
- **CC-340 knowledge index 重型版**——**已被 [[CC-403]] supersede**：memory-index MVP 移入 Phase 2，CC-340 僅剩 embeddings / 語意後端 remainder，待 FTS/LIKE 證明不足再 resume。
- **CC-026（/skill-distill）——continue defer**：前置 episode signal 層（CC-027b/c）仍 deferred；列入 someday 待 signal 層就緒再評估。
- **CC-018（rate-limit 統一）——continue defer**：ux/token 主題與 retrieval 正交；維持 P3 active 不排入 v0.7.0。
- **CC-342（debt-auditor agent）——continue someday**：proactive 技術債掃描與本版主題無直接相關；待核心穩定後再評估。
- **CC-357（skill as contract schema）——continue someday**：架構較大、無明確 trigger 條件，不排入 v0.7.0。
- **CC-033（Public flip checklist）——blocked on CC-032**：CC-032（`[[feedback_*]]` 公開化）仍 🔵 active 未完成；CC-033 依賴其完成，不排入 v0.7.0。

---

## v0.6.0 — executor abstraction（runtime 解耦合；released 2026-06-19）

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
| CC-376 | opencode executor adapter（第一個第三方 adapter；落地若需改核心 = 抽象未竟）。以 CC-389 契約為基準 | ✅ pr:#290 |
| CC-377 | Google Antigravity `agy` executor adapter（第二個；驗 N≥2）。**注意 Gemini CLI 已棄用，目標是 antigravity 非 gemini**。**🟡 DEFERRED — 待 agy 版本更新（spike 2026-06-16）**：agy **有免費額度**（成本非阻因），暫緩純因 **headless CLI 尚未成熟**——1.0.8 無結構化輸出 / 無語意終止事件 / headless 不穩 → 無 machine 契約可建乾淨 adapter（`docs/spikes/CC-377-agy-headless-feasibility.md`）。**agy 仍為首選第二 adapter**，resume = 較新 agy 出可用 headless stream-json。**escape-hatch**：N≥2 暫未由 agy 達成，opencode 為唯一獨立第三方 adapter。**牽動 Phase 7 排序紅線**（lifecycle 須 N≥2 後）→ 待 maintainer 定奪是否以 opencode 單一獨立 adapter 視為抽象已證、或等 agy 成熟（2026-06 免費 CLI 池枯竭，傾向等 agy） | 🟡 |

### Phase 6 — deprecation 清掃（P2）

| 票 | 摘要 | 狀態 |
|----|------|------|
| CC-335 | deprecated surface 移除 sweep：handover legacy trio（sandbox/approval/skip_git_check）＋ CLAUDE_HOOK_* shims 移除；codex-dispatch.sh shim 殘留 dead-code 清理；pr-gate.sh 直呼降級為文件 deprecation（standalone 為官方 fallback，不刪檔） | ✅ |
| CC-394 | 退場 `agents/claude-executor.md` — claude 收斂為 adapter-only（對齊 opencode） | ✅ |
| CC-395 | 退場 `agents/codex-executor.md` + 砍 codex danger-full-access（decision A）：`none` 僅 opencode 允許、codex/claude 全 route reject；刪 codex bash-guard ＋ install orphan-cleanup ＋ pmctl-safe/pre-bash fail-closed；文件/測試收斂。衍生 CC-396（operational 檔 CC-provenance 註解清理） | ✅ |
| CC-396 | 清理 scripts/adapters/lib 等 operational 檔中殘留設計沿革票號（CC-NNN）註解；保留測試 fixture data 與 ID 格式範例 | ✅ pr:#303 |
| CC-371 | uninstall adapter 殘留清理：`uninstall.sh` 補上 `adapters/` 目錄移除（CC-395 adapter 退場的收尾）| ✅ pr:#300 |

### Phase 7 — executor lifecycle ownership（P2；executor 抽象的完成式）

> **為什麼在 v0.6.0 而非 v0.7.0（2026-06-15 user 校準）**：`host-native` 把 executor 綁死在 host harness，detached-supervised 把它解開——**這正是本 milestone「runtime 解耦合」主題的完成式**，不是下一版新題目；且 [[CC-391]] 是 [[CC-385]]（Model B 決策，Phase 4）的直接續集，分跨兩版會把 dispatch-model 故事打碎。thin-slice 是**每個 PR** 的紀律、非每個 milestone；Phase 7 三薄片各自可獨立 ship。
>
> **排序紅線**：Phase 7 實作必須排在 **Phase 5（真 adapter CC-376/377）之後**——先在 N≥2 adapter 下證明 executor 抽象，再加 lifecycle 層，避免 supervisor 契約被 codex/claude 特例帶歪。**逃生口**（沿用 Phase 3 寫法）：若 v0.6.0 收尾時 Phase 7 未及，可單獨延 v0.6.x 點版或 v0.7.0，但預設留在 v0.6.0。
>
> **設計依據**：Model B（[[CC-385]]/[[CC-386]]..[[CC-389]]）已交付 brief-可信落地 + executor-獨立子程序 + pmctl-三重機檢驗證；但派發仍 **foreground-sync**（`pmctl dispatch run` 阻塞、in-process 驗證、main 持有生命週期）。缺的是 process 生命週期擁有權、durable 結果、listener 通知。這不是 [[CC-372]] runner_kind（怎麼**到達** executor），而是 **lifecycle ownership**（啟動後**誰持有**）——正交新軸。**定位紅線**：lifecycle 是**派發當下的選擇**（`pmctl dispatch run --lifecycle foreground\|detached` + config 預設），**非 manifest 欄位**；可 detach 資格由 runner_kind（headless-CLI Model B）推導，`host-native` 不可 detach；不引入 `lifecycle_mode`/schema 改名（避與 [[CC-384]] 撞）。verify 層直接重用 [[CC-386]]/[[CC-389]]，durable substrate 重用 [[CC-211]]；真正 net-new 只有 detached supervisor 與 notify channel。

| 票 | 摘要 | 狀態 |
|----|------|------|
| CC-391 | **(7a 決策-only，先行)** detached-supervised dispatch 建模決策：lifecycle 作派發旗標非 manifest 欄位、supervisor 元件邊界、durable-outbox 為 load-bearing、foreground→detached 遷移順序（fail-closed 不弱化）、一次真實 detached 派發等價證明。**codex spike = partial-adopt**（`docs/spikes/CC-391-*.md`） | ✅ pr:#288 |
| CC-392 | **(7a 前置)** claude adapter `runner_kind` 分類漂移修正——manifest 宣告 `host-native` 但 adapter 實跑 headless `claude --print`（[[CC-383]]/[[CC-388]] 後）→ `runner_kind` 不可信、卡住 [[CC-391]] detach 資格推導。傾向定 canonical 為 `cli-subprocess`＋override 保行為不變；security/risk hard gate（不弱化 claude write guard） | ✅ pr:#289 |
| CC-225 | **(7b durable，可獨立先 ship)** all-executor durable run-state 記錄（brief 路徑 / result 摘要 / exit / post-verify 判定 → repo-tracked，格式對齊 `.gate-results/`）；對齊 [[CC-211]] run-FSM。supervisor 的 durable 半；真 adapter 需要時前拉 | ✅ pr:#295 |
| CC-397 | **(7b refactor，前置 7c)** `pmctl_dispatch_run` executor tail 抽出為獨立函式 `pmctl_dispatch_execute_tail`；adapter stdout footer 從 mktemp 改為 durable sidecar（`<run_id>.footer`），確保 recovery window 可讀 | ✅ pr:#296 |
| CC-398 | **(7c-2a)** dispatch lifecycle axis：`--lifecycle foreground\|detached` + config key `dispatch.lifecycle`；detach 資格由 `runner_kind` 推導（cli-subprocess = eligible）；`scripts/dispatch-supervisor.sh` 同步 supervisor；21 個 test-dispatch-lifecycle 案例 | ✅ pr:#297 |
| CC-399 | **(7c-2b)** `pmctl dispatch run --lifecycle detached` now launches the supervisor via `setsid`/`nohup`, returns `run_id` immediately, writes advisory supervisor PID/log sidecars. `pmctl dispatch wait <run_id> --cd <dir>` reattaches via the supervisor sentinel (nonce-bearing `/tmp` path, key in per-user private dir); falls back to `.dispatch-results/<run_id>.md` when key is absent. `pmctl inbox`/notify channel remain out of this thin slice. | ✅ pr:#298 |
| CC-238 | **(7c)** pr-gate fan-out 無 timeout / 弱 attribution：加 reviewer + synthesis 本地 watchdog（SIGTERM-based，per-reviewer attribution）。**設計決策**：`pr-gate.sh` parallel fan-out 直接管理子程序（非走 `pmctl dispatch run`），故 local watchdog 是正確的 ownership boundary；general supervisor（[[CC-399]]）為不同路徑。tradeoff 記錄於 BACKLOG CC-238 body。 | ✅ pr:#300 |

### Phase 8 — gate 工具能力 + 規劃技能（追加，v0.6.0 一同 ship）

| 票 | 摘要 | 狀態 |
|----|------|------|
| gh-174 | `pmctl gate run` 支援 persistent accepted-risk overrides（`--override-file`/auto-discover `.gate-overrides.md`）；每次 run 附加不可靜默的 provenance audit block，parser-safe | ✅ pr:#301 |
| gh-173 | `docs/sandbox-limitations.md` — codex sandbox 摩擦模式（`go build`、網路、Docker、`git commit`）與 workaround 文件；`skills/dispatch-brief` 補指引 | ✅ pr:#301 |
| CC-408 | next-step uncertainty router — PM-level 決策層，判斷一個需求應走 `/discover`、`/spike`、`/research` 還是直接 brief；避免把 spike/research 混用為 pure-exploration 工具 | ✅ pr:#302 |
| CC-220 | `/spike` skill + `spike` planner agent（`agents/spike.md`）——spike 有 committed 流程：planner 規劃 2-3 diverging angles，main thread fan-out，synthesize `docs/spikes/<id>.md` | ✅ pr:#302 |
| CC-344 | `/research` skill（`commands/research.md`）——外部知識引入管道：internal anchor → direction question → bounded WebSearch → filter against constraints → persistence prompt | ✅ pr:#302 |

### 延後至 v0.7.0+（明確排除於 v0.6.0）

- **CC-216 MCP server（DEFERRED，不排入 milestone）**——「通用橋」邏輯上是 executor 抽象＋lifecycle 之後的下一層，重型 net-new surface（Node/Python server + `pmctl --json`），不符 thin-slice。**2026-06-13 從 v0.6.0 defer；2026-06-18 user 進一步拍板：不排入任何 milestone，待核心（executor 抽象 + retrieval/memory 基底）覺得**基本都穩定**後再考慮。** 不再是 v0.7.0 headline——v0.7.0 改為 retrieval-first + memory 主題。
- **CC-333 七層耦合中的 1/4/7**（memory 路徑 / 安裝路徑 / reviewer memory 讀取）——本版聚焦 dispatch+guard+install+lifecycle 的 executor 抽象；memory/install-target 軸（含 [[CC-104m]] 多目標投影）留待後續。
- **CC-358 / CC-359**（runner telemetry / worktree batch dispatch）——建在抽象之上的能力層，抽象穩定後再做。
- **完整 knowledge index（CC-340）**——**已被 [[CC-403]] supersede**（2026-06-18）：memory-index MVP 移入 v0.7.0 retrieval epic，CC-340 僅剩 embeddings remainder。

---

## v0.5.0 — local context substrate（本地 context 地基；released 2026-06-13）

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
