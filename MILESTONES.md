# Milestones

<!-- Scope change policy:
     - Blocking bug discovered mid-milestone → add to current milestone, fix immediately
     - Non-blocking bug → BACKLOG new ticket, evaluate in next milestone
     - New feature → default defer; may add if matches theme AND ≤1 PR scope
-->

---

## v0.3.0 — PM runtime restructure（規劃中）

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
| CC-262 | `isolation_level` enum 全三段完成 — adapters/claude no-op map（#162）；codex-dispatch 展開（#175）；PM template（#180）。注：`adapters/codex` 的 dispatch.sh 已由 CC-289 實作（#194）；CC-262 planning 文字/狀態與已 ship 實作的對齊另由 [[CC-274]] 追蹤（adapters/codex isolation-map 仍 v0.4.0） | ✅ (#162/#175/#180) |

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
| CC-297 | `reviewer` guard role — 只能寫 `.gate-results/`（防 prompt-injection 誘導 reviewer 亂寫）；`cli/pmctl` relative symlink fix；fan-out spike | ⚠️ pr:#218 open | P3 |

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
| — | v0.3.0 release prep（CHANGELOG + tag + GitHub Release） | ⏳ |

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
