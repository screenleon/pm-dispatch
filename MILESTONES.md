# Milestones

<!-- Scope change policy:
     - Blocking bug discovered mid-milestone → add to current milestone, fix immediately
     - Non-blocking bug → BACKLOG new ticket, evaluate in next milestone
     - New feature → default defer; may add if matches theme AND ≤1 PR scope
-->

---

## v0.3.0 — PM runtime restructure（規劃中）

**主題**：把 pm-dispatch 從「Claude Code 設定 + dispatch 腳本」重構成 schema-first / state-first / adapter-thin 的 **PM runtime**；把 Multica / Memori / Superpowers / AI Night Shift 的概念吸收進單一 state substrate，而非四個獨立功能。

完整架構規劃見 [`docs/architecture/v0.3.0-synthesis.md`](docs/architecture/v0.3.0-synthesis.md)（三方獨立規劃對照與綜合）+ [`docs/architecture/v0.3.0-source-plans.md`](docs/architecture/v0.3.0-source-plans.md)。Epic：CC-211。

四層架構：`core/`（資料模型 + 政策）→ `runtime/`（`pmctl` 主幹）→ `adapters/`（交付層）→ `mcp/`（外部橋接，v0.4.0）。

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
| CC-229 | `core/schema/` — task/run/event/review/decision schemas | ⏳ |
| CC-230 | `~/.local/share/pm-dispatch/state/` state store + `routing_log.md`→`runs.jsonl` | ⏳ |
| CC-231 | `core/policy/` 抽取（reviewer-policy / executor-enum / dispatch-states） | ⏳ |
| CC-232 | context-pack schema + context-enricher 介面 | ⏳ |

### M2 — 由抽取長出 runtime

| 票號 | 說明 | 狀態 |
|---|---|---|
| CC-202 | handover-validator framework → `pmctl validate` | ⏳ |
| CC-204 | hook framework → guard engine → `pmctl guard check` | ⏳ |
| CC-200 | executor-router → dispatch runner | ⏳ |
| CC-215 | `bin/pmctl` MVP（全子命令 `--json` 輸出） | ⏳ |

### M3 — 重新接 Claude adapter

| 票號 | 說明 | 狀態 |
|---|---|---|
| CC-059 | thin `commands/pm.md` | ⏳ |
| CC-061 | `skills/` 目錄 + starter SKILL.md | ⏳ |
| CC-233 | `scripts/test-layer-boundaries.sh` 分層邊界測試 | ⏳ |

### M4 — 概念吸收

| 票號 | 說明 | 狀態 |
|---|---|---|
| CC-234 | memory v2 — event-derived distillation（Memori） | ⏳ |
| CC-235 | Task lifecycle gate — spec→design→plan 強制（Superpowers） | ⏳ |
| CC-237 | context-enricher baseline — rg/git/memory sources | ⏳ |

### M5 — spike workflow + release

| 票號 | 說明 | 狀態 |
|---|---|---|
| CC-220 | `agents/spike.md` + `commands/spike.md`（planner + 主執行緒 fan-out） | ⏳ |
| CC-209 | context-enrichment spike：codegraph 評估（第一個正式 `/spike`） | ⏳ |
| — | v0.3.0 release prep | ⏳ |

### v0.3.0 範圍外 → v0.4.0

- CC-216 — `mcp/pm-dispatch-server` 實作（v0.3.0 只放 `mcp/README.md` 工具介面規格作為 `pmctl` 設計約束）
- `adapters/codex` / `adapters/antigravity` / `adapters/opencode` — named slot，不實作（Antigravity CLI 取代 Gemini CLI；原規劃寫的 `gemini` 一律改為 `antigravity`）
- AI Night Shift autonomy loop — 不做
- CC-236 `pmctl report` 晨報 — 降為 🟢 someday（2026-05-22；無人值守執行需求低，非 v0.4.0 排程）

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
