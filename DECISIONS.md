# pm-dispatch decisions

<!--
排序：按日期倒序（最新在上）。
H2 標題格式：## YYYY-MM-DD: <短描述>
每筆必含四節：Context / Decision / Alternatives considered / Constraints introduced
與 BACKLOG closure 對應的 entry，內文首行寫：Closes: BACKLOG.md#<PREFIX>-NNN
-->

## 2026-07-22: grok-host-and-executor-mvp

**Context**: Grok Build CLI (`grok`) already exposes Model B headless surfaces
(`--prompt-file`, `--output-format streaming-json` with terminal event `end`,
`--sandbox`, `--permission-mode`, `--reasoning-effort`) and a config home at
`~/.grok`. Maintainers want both axes: dispatch *to* Grok as an executor, and
run batch PM *inside* Grok as a host (`pmctl pm --host grok`). Host and
executor remain orthogonal (host-contract / executor-contract).

**Decision**: Ship a full MVP for both axes in one change set. Executor:
hand-authored `adapters/grok/` with `runner_kind: cli-subprocess`,
`write_guard_mode: cli-only`, dual isolation map (sandbox + permission_mode),
`terminal_event: end`, and `share/grok-model-aliases.tsv`. Host: minimal
`hosts/grok/` with doctor + path-resolver, `install_module: null` /
`uninstall_module: null`, honest `none`/cli_wrapper capabilities, and closed
format handler `grok-config-toml` for doctor-visible `$GROK_HOME/config.toml`.
Expand `executor-enum` + schema mirrors with `grok`; expand host allowlist
with `grok`. Defer `--enable-host grok` install/hooks and native slash `/pm`
to a follow-up once the axes exist.

**Alternatives considered**: (a) executor-only or host-only first — rejected;
user requested both axes and Grok already has the CLI surface for both.
(b) permission-mode-only isolation (mirror claude) — rejected; Grok's OS
sandbox is a real second layer and is the recommended mapping.
(c) full install/hooks in the same MVP — deferred to keep the first landing
reviewable and honest about unprobed guard bindings.

**Constraints introduced**: `isolation_level: none` remains opencode-only
(grok rejects it like codex/claude). Adding a third non-claude host keeps the
host-axis N≥2 red line intact without claiming unprobed guard coverage.
Executor enum expansion is a closed-policy edit kept in sync with
`run.schema.json` / `handover.schema.json`. For the grok adapter only,
`workspace-write` is **narrowed**: Grok OS sandboxes always allow writes under
`~/.grok` (session/config store) in addition to CWD/temp — there is no CWD-only
profile; this is documented in `adapters/grok/isolation-map.yaml` and
`docs/executor-contract.md`, and the adapter emits a stderr note at launch.
pm-dispatch does not clean or roll back `~/.grok`.

### Reuse confirmation (backfill 2026-07-22)

Formal prior-art confirmation was **not** run before first pr-gate; backfilled
after GO via `pmctl context reuse-scan` + targeted `context query` /
`context pack`.

**reuse-scan query** (repo plane):

```text
pmctl context reuse-scan . "add grok host and executor adapter dispatch isolation doctor path resolver model aliases terminal event"
```

Top hits (≤5 retained after review):

| # | Ref | Role in this change |
|---|-----|---------------------|
| 1 | `runtime/lib/executor-router.sh` (`_er_adapter_manifest` / runner_kind) | **Reuse as-is** — data-driven routing; no core branch for grok |
| 2 | `runtime/lib/pmctl-dispatch.sh` (`pmctl_dispatch_resolve_adapter`) | **Reuse as-is** — resolves `adapters/<name>/dispatch.sh` by convention |
| 3 | `runtime/lib/pmctl-adapter.sh` (`pmctl_adapter_generate`) | **Not used for ship** — production adapter hand-authored (same as claude/opencode) |
| 4 | `runtime/lib/dispatch-common.sh` (`dc_*`) | **Reuse as-is** — args/trace/footer/snapshot libs shared by all adapters |
| 5 | Host path resolvers (`hosts/*/lib/path-resolver.sh`) | **Pattern-reuse** — grok mirrors codex/opencode `*_host_config_root` + `host_manifest_expand_root_template` |

**Additional targeted reuse (from pack / query, not in top-5 scan):**

| Seam | Action |
|------|--------|
| `adapters/claude/dispatch.sh` | **Pattern-reuse** — self-snapshot, effort, permission_mode, footer, usage log |
| `adapters/opencode/dispatch.sh` + `isolation-map.yaml` | **Pattern-reuse** — isolation map reader; dual-layer is grok-specific |
| `adapters/*/adapter.yaml` | **Pattern-reuse** — `cli-subprocess` + `write_guard_mode: cli-only` + `terminal_event` |
| `runtime/lib/model-aliases.sh` (`ma_resolve_alias`) | **Reuse as-is** — TSV alias table for grok |
| `runtime/lib/host-manifest.sh` | **Reuse as-is** — doctor/path expand without host-named core |
| `runtime/bin/doctor.sh` (`executor_authed`) | **Extend** — add `grok` case only; no new probe framework |
| `runtime/lib/host-names.sh` | **Extend** — allowlist `grok` only |
| `core/policy/executor-enum.yaml` + schema mirrors | **Extend** — one-line enum add (same as opencode) |
| `tests/shell/test-opencode-dispatch.sh` (`case_pmctl_route`) | **Pattern-reuse** — fake CLI + Run row assertions |
| `tests/shell/test-claude-dispatch.sh` | **Pattern-reuse** — snapshot / isolation / footer cases |

**Deliberately not invented / not forked:**

- No new dispatch orchestrator, state writer, guard policy engine, or host-manifest reader.
- No host-named branches in `executor-router` / `host-manifest` core.
- No install/hooks write path (would have reopened codex/opencode install modules).

**Verdict:** MVP stays on existing seams; new code is axis-local (`adapters/grok/`, `hosts/grok/`) plus closed allowlist/enum extensions. Process gap closed by this backfill.

### Schema version bump (enum expansion)

Per `core/README.md` and the CC-376 precedent (`handover_version` 2→3,
`run.schema_version` 1→2 when `opencode` was added), expanding the closed
executor enum requires a versioned contract bump:

| Contract | Before | After |
|----------|--------|-------|
| `core/schema/run.schema.json` `schema_version` | 2 | **3** |
| `core/schema/handover.schema.json` `handover_version` | 3 | **4** |

Producers (`state-writer.sh` run JSON, handover authors), validators
(`handover_validate_handover_version`), fixtures, and dispatch-brief examples
were updated together. Older validators that accept only version 3 handovers
will reject version-4 envelopes until upgraded — the intentional mixed-version
fail-closed path.

Approver: screenleon (2026-07-22).

## 2026-07-06: v0.9.0-host-axis-includes-opencode

Relates: CC-436, CC-437, CC-438, CC-445, CC-448

**Context**: v0.9.0 規劃時（依 2026-07-04 roadmap，host 軸原僅排 codex-host 四票 CC-436/437/438/445，opencode host CC-448 排 v0.10.0/v1.0-rc），維護者於 2026-07-06 指示：host 軸不應只做 codex，opencode 也要在 v0.9.0 就嘗試作為 host。理由與 CC-448 票內既有論證一致——host 抽象比照 executor 抽象的 N≥2 紅線，只有 codex 一個非 claude host 時 `hosts/*/host.yaml` schema 容易被 codex 特例帶歪；等 schema 在 v0.9.0 定案後才驗 opencode，發現抽象走歪的成本更高。

**Decision**: CC-448 整票提前排入 v0.9.0 Phase 1（host 軸），三階段照票內順序：probe（唯讀、無前置，與 CC-436/437 並行先跑）→ `hosts/opencode/host.yaml`（依 CC-438 schema）→ install/doctor 接線（依 CC-445 host-generic write path）。「核心零改動、僅新增 `hosts/opencode/`」的 N=2 驗收紅線由 v1.0-rc 提前為 v0.9.0 版內驗收。若 opencode probe 判定 hook 機制不足以承接 guard，照票內 fallback（cli-only guard + host manifest 明宣告），不阻塞版本。

**Alternatives considered**: (a) 維持原案（opencode host 留 v1.0-rc）——被否，schema 帶歪風險後置；(b) 只提前 probe 階段——考慮過，但 probe 結果若良好而接線又隔一版，N=2 驗收仍延後，且 CC-445 的 write path 本就要求 host-generic，同版驗收成本最低。

**Constraints introduced**: v0.9.0 的 host 軸完成定義 = codex + opencode 雙 host 通過「install → doctor 全綠 → guard 實攔（或明宣告 cli-only）→ uninstall 無殘留」；`hosts/*/host.yaml` schema 修訂必須以雙 host 需求共同定案，不得 codex 特例。

Approver: screenleon（2026-07-06）。

## 2026-07-04: v1.0-public-roadmap-and-release-sequence

Relates: CC-032, CC-033, CC-216, CC-296, CC-333, CC-358, CC-431, CC-436, CC-437, CC-438, CC-444, CC-445, CC-446, CC-447, CC-448

**Context**: v0.8.0 四個 Phase 已全部完成但尚未 tag（v0.7.1 之後累積 17 commits，含計畫外的 ship 系列 CC-439..443）。維護者提出「進入正式版之前還缺什麼」的規劃問題。主線程全面盤點（MILESTONES v0.4.0→v0.8.0、BACKLOG 全部開放票、近期 spikes）收斂六軸差距，外部 chatgpt review 對初版規劃補上兩個結構修正（宣稱邊界先行、P0/P1/P2 分層取代軸並列），並經事實驗證修正三點：(1) **repo 已經是 public**（`gh repo view` 實測 `isPrivate: false`）——CC-033「flip 前防護」的前提已過時，README 卻仍寫 private-maintainer scoped，posture 需要 reconcile；(2) README 版本徽章停在上一 release **不是 drift**——RELEASE_CHECKLIST 明定 badge 僅於 release 時 bump 至 target tag、為唯一版本標記；(3) 平台 support matrix **已存在**（`docs/platform-support.md`），僅剩「core-development phase / v0.5.0+」舊措辭待更新為 v1.0 承諾。六軸差距：host 抽象未收口（guard/doctor/install 仍 claude-host-only）、可靠性證據層缺席（CC-358 無 reader；CC-431 release 驗證從未跑過第三方 adapter）、契約凍結不存在（無 stable/experimental 分級；CC-296 漂兩版）、onboarding 從未乾淨環境實測、公開 posture 未收口（CC-032 dead wikilink）、平台措辭過時。

**Decision**: **v1.0 = public 正式版**，核心原則（採外部 review 表述）：**v1.0 只承諾已有證據、已有契約、已有支援矩陣的表面；其餘一律標 experimental**。宣稱面拍板：executor stable = codex/claude/opencode（CC-431 e2e 通過為憑）；**host 支援 = claude + codex + opencode 三者**（maintainer 2026-07-04 追加拍板：v1.0 必須做到 codex host 與 opencode host——host 抽象比照 executor 抽象，N=2 非 claude host 才算抽象成立）。分層：**P0 定義性 blocker** = CC-446 stability contract（`docs/stability-contract.md` 四層分級：stable CLI / experimental CLI / stable schema / internal schema；吸收 CC-296 deprecation 清掃 + README deprecated 連結矛盾）、CC-032（policies glossary + link validator）、CC-033（rescope 為 public posture reconciliation：README 文案一致、Issues/Discussions 設定、**即刻** git history 損害盤點）。**P1 證據層（缺則降級宣稱）** = CC-358 `pmctl run-stats`（具體 DoD 見票）、CC-431 opencode e2e、host 軸 CC-436/437/438 + CC-445（codex-host install write path）+ 新票 CC-448（opencode host，N=2 host 抽象驗收）、CC-447 onboarding 雙 smoke（offline clean install + live dogfood）。**P2 非 blocker** = 無殘留——原候選「CC-433 shared sentinel lib」經查已交付（CC-433 spike GREEN → CC-434 落地 `scripts/lib/detached-launch.sh`，pr:#356，2026-07-02）；殘餘 poll→通知遷移為 CC-435 條件觸發票（multi-waiter 場景出現才議），維持不排。Release 順序：**(a)** 立即 tag v0.8.0（CC-444）；**(b)** v0.9.0 = evidence + contract + codex-host 軸（CC-358、CC-431、CC-446、CC-436→437→438、CC-445、CC-447 offline smoke）；**(c)** v0.10.0 / v1.0-rc = opencode host（CC-448）+ public posture（CC-032、CC-033）+ live dogfood smoke + rc 期間真實 run-stats 蒐證；**(d)** v1.0.0 = 零新功能聲明版（release notes 附 run-stats 報告；stability contract 凍結生效；平台矩陣措辭更新）。MCP CC-216 維持 defer——其「核心穩定後再評估」條件於 v1.0 成立，列為 post-1.0 第一題。Approver: screenleon（2026-07-04：「public 正式版」+「v1.0 做到 opencode host、codex host 這 2 個」）。

**Alternatives considered**: (a) **v1.0 = 自用穩定版**——被維護者否決，公開是本輪正式版目標。(b) **契約凍結延至 rc 一次做完**——省兩三週，但 deprecation 清掃與分級擠在 release 前最易漏項；且 experimental 分級本身就是 ship/worktree 系列仍在熱變動期的解法（標 experimental 即可先凍結框架），不必等它們穩定。否決。(c) **codex-host-only at v1.0**（opencode host 留 post-1.0）——工作量最小，但 host 抽象只有 N=1 非 claude 實例，重蹈「僥倖非抽象」風險（executor 軸當年即以 N≥2 為紅線）；maintainer 明確拍板要雙 host。否決。(d) **v0.9.0 先做新能力（ship 並行迭代等）**——延長契約熱變動期、證據層繼續缺席。否決；接受 v0.9/v0.10「幾乎零新玩具」的動力成本。(e) **先做 CC-064 bootstrap wizard 改善 onboarding**——乾淨機器實測更便宜且先驗證需求；wizard 僅在實測證明需要時升級。否決先做。

**Constraints introduced**: git history 損害盤點**即刻執行**（repo 已公開，任何歷史洩漏已曝光——目標是發現與處置，不是 flip 前防護；上次審查 2026-05-15 已過期 ~250 commits）；CC-032 link-target validator 綠燈為 v1.0 hard constraint（公開讀者不可見 dead wikilink）；stability contract 凍結後，machine 契約（brief schema、adapter.yaml、host.yaml、run-spec、gate result）變更受 SemVer/deprecation 政策約束；ship/worktree 子指令與 `ship-lanes.jsonl` 於 v1.0 標 **experimental**（至少一個 rc 週期後才可升 stable）；host 抽象驗收紅線 = 「新增第三個 host = 放 `hosts/<name>/` manifest，核心零改動」（鏡像 executor 抽象驗收句）；v1.0.0 tag 版本零新功能；CC-216 等 post-1.0 議題不得插入 v0.9/v0.10 排程。

## 2026-06-23: dispatch-gate-artifacts-relocate-out-of-repo

Relates: CC-003, CC-413, CC-414, CC-415, CC-416, CC-417, CC-418, CC-419

**Context**: dispatch 與 pr-gate 把 scratch artifact 寫進使用者 repo 工作目錄：`.agent-trace/`（每次 dispatch 的 executor JSONL 事件流 + footer/runspec/supervisor log，`adapters/*/dispatch.sh` 把 `TRACE_DIR` 寫死成 `$WORK_DIR/.agent-trace`）、`.gate-briefs/`、`.gate-results/`。這造成兩層問題：(L1) pr-gate `--parallel` 的 integrity check（`pr-gate.sh:895/1093`）對 `git status --porcelain` 取 dispatch 前後 hash 偵測 prompt-injection，但 gate 自己的寫入若未被 `.gitignore` 蓋掉就會改變 status hash → 在健康 repo 誤判 abort（這是 CC-003 原始症狀）；(L2) 即使 gitignore 蓋掉，檔案仍實體落在使用者專案資料夾（本 repo 實測 `.agent-trace` 已累積 93MB/552 檔），且問題跨所有被 dispatch/gate 作用過的 repo——使用者視為污染。根因是 adapter 把「執行 cwd」與「trace 落點」綁死，gate reviewer 又走同一批 adapter，所以單改 gate 無法讓 repo 不被碰。關鍵事實（驗證 `scripts/lib/state-writer.sh`）：out-of-repo state 慣例**已存在**——`_sw_store_root`（`PM_DISPATCH_STATE_ROOT` > `$XDG_DATA_HOME/pm-dispatch/state` > `~/.local/share/pm-dispatch/state`）+ `_sw_project_key`（canonical git toplevel → SHA-1 → `projects/<hash>/`）+ 0700 安全模型 + `_sw_write_repo_json`；run-records/events/tasks 早已走這條。

**Decision**: 採方向 D-wide——把 dispatch 與 gate 的全部 artifact 搬出 repo，**複用既有 `state-writer.sh` seam**（不另開 `XDG_STATE_HOME` 或 `PM_STATE_DIR`）。目標布局 `$PM_DISPATCH_STATE_ROOT/projects/<repo-sha1>/runs/<run_id>/{trace/.agent-trace,gate/.gate-briefs,gate/.gate-results,dispatch/...}`，保留 `.gate-results` 葉名以維持 `guard-reviewer-write.sh` 的綁名語義。cwd 與 trace-root 用 `--trace-dir <abs>` flag + `PM_DISPATCH_TRACE_DIR` env 解耦（precedence flag > env > legacy default）；orchestrator 算一次傳給 adapter，adapter 保持笨。containment guard（`dispatch-post-verify.sh`）信任邊界從「在 repo 內」改成「在 caller 供給的本次 run trace dir 內」（canonical realpath 前綴比對）——新邊界更安全（state root 0700、非攻擊者可影響，repo 工作樹反而含被審 diff）。verdict 檔視為 human-facing：預設也出 repo，但 stdout 印路徑 + 提供 `--output` 顯式匯回。**分階段落地**（CC-413..419，見 BACKLOG），第一切片為「引入 seam、預設不變、零行為改動」，最後才翻預設。既有散落副產物（含本 repo 與其他被作用過的 repo）以一次性遷移/清理子票處理（CC-419）。規模上這是橫跨 dispatch 子系統的結構性改動，故將 CC-003 重定義為 epic umbrella、其餘為 phase 子票。決策依據：Opus + Codex（有 repo 存取）+ ChatGPT/Gemini/Grok（外部）五方獨立分析一致選 D-wide；唯一分歧（state root 用 `XDG_STATE_HOME` vs 複用 state-writer）由兩個有 repo 存取的來源裁決為複用既有 seam。Approver: screenleon（2026-06-23）。

**Alternatives considered**: (a) **方向 A（filter）**——integrity check 計算 status hash 時排除三個已知 artifact 路徑。只解 L1 誤判，L2 污染仍在（檔案還在 repo）。保留為 CC-413 Phase 0 止血切片，非最終架構。(b) **方向 B（auto-patch .gitignore）**——gate 主動補 `.gitignore`。解 L1、`git status` 乾淨但檔案仍在 repo（L2 部分）；且打破既有刻意不變量測試 `test_pr_gate_does_not_mutate_gitignore`。否決。(c) **方向 C（preflight abort）**——只把「莫名卡死」換成「明確卡死」，健康 repo 首跑仍被擋，未真正解問題。否決。(d) **D-narrow（只搬 gate）**——因 gate reviewer 走同一批 adapter，仍須解耦 adapter trace-root，等於碰 dispatch；且造成「兩套 artifact 世界」每個 adapter/observer/guard/doc 都要解釋兩種行為。否決，改 D-wide。(e) **新建 `XDG_STATE_HOME` 根**——外部三家建議（規範上 state log 正位），但與 repo 既有 `state-writer.sh`（`XDG_DATA_HOME`）不一致；一致性 + 既有安全模型與測試 > 規範純度，否決。

**Constraints introduced**: `.gate-results` 葉目錄名必須保留為 run dir 下最後一段，否則 `guard-reviewer-write.sh` 綁名 injection guard 失效。post-verify containment 必須對 canonical 化的 trusted run-dir 做前綴比對（不可再以 `$WORK_DIR` 為界）。trace 寫入非 optional——CI 無可寫 HOME 時須 fail loud（明確指引設 `PM_DISPATCH_TRACE_DIR`/`PM_DISPATCH_STATE_ROOT`），不可靜默掉資料。run id 不可只用秒級 timestamp（並發會撞，須加 PID/隨機）。`latest.*` symlink 降級為人類便利、非權威；per-run 目錄為唯一權威來源。state store 須有 GC/retention（JSONL trace 很大），否則無限增長。翻預設前須保留 in-repo opt-in（`--artifact-root in-repo` / `PM_DISPATCH_ARTIFACT_MODE=in-repo`）至少一個 release，並提供可發現性指令（`pmctl artifacts list/show`）。

## 2026-06-21: retrieval-first-defaults-on-and-fail

Closes: BACKLOG.md#CC-402

**Context**: After CC-400 (mandatory retrieval order) and CC-401 (brief-validate retrieval-evidence chokepoint, shipped at `BRIEF_VALIDATE_RETRIEVAL=warn`), the retrieval-first discipline existed but was not load-bearing: the only structural context-first mechanism — dispatch `--auto-pack` — defaulted off AND was rejected under the default `detached` lifecycle (the augmented pack brief diverged from the guarded `/tmp` brief), and the evidence gate only warned. The earlier auto-pack decision (2026-06-13 `passive-context-v1-auto-pack-pointer-only-opt-in`) deliberately shipped auto-pack **opt-in, default off**, gated on `context.auto_packed` telemetry before flipping the default.

**Decision**: Ship the full coherent slice in one PR rather than staging the flips: (1) make detached + auto-pack compatible AND land the augmented brief at the guardable `/tmp/brief-<run_id>.md` in BOTH lifecycles so one brief is guarded == validated == executed == recorded — detached records it as the run-spec trusted `brief_file` and the supervisor re-guards it; foreground snapshots the pack to `/tmp`, guards it, and forwards it; the authored `--brief-file` is guarded first for path policy (CC-398 invariant intact, no second `--brief-file` passthrough); (2) move the dispatch gate validation to **after** auto-pack so it validates the effective brief and an appended `auto_context:` block counts as evidence; (3) flip `dispatch.auto_pack` built-in default **off → on**; (4) flip `BRIEF_VALIDATE_RETRIEVAL` default **warn → fail**. Approver: screenleon (chose full-C "complete, not half-baked" over compat-only or compat+single-flip, 2026-06-21), explicitly accepting the revision of the observe-first telemetry gate on the auto-pack default — rationale: both flips are cheaply reversible config defaults, auto-pack is fail-open + pointer-only + read-only reuse-scan (worst case adds low-value pointers, never breaks a dispatch), and this is a single-developer dogfood tool where the author, gate-runner, and brief-author are the same actor.

**Alternatives considered**: (a) **Compat-only, defer both flips** — cleanest single-purpose PR for the HARD gate; rejected as half-baked (leaves Ph1 advisory, not enforced). (b) **Compat + warn→fail only** — rejected as the *worst* ordering: it requires evidence before the auto-supply mechanism (auto_pack) is on by default, pushing the burden back to manual `context:` discipline — exactly the reflex-degradation CC-401 fought. (c) **Make auto-pack stamp a "0-hit, scanned" auto_context block** so auto_pack-on always satisfies the gate — rejected as dishonest: it would turn the gate into a rubber stamp; a brief whose scan found nothing and whose author wrote nothing genuinely skipped retrieval and should declare `retrieval_skip_reason:`.

**Constraints introduced**: A file-writing brief with **zero** reuse hits and no hand-authored `context:`/`retrieval_skip_reason:` is rejected by default — auto-pack does not manufacture evidence. The PM agent (CC-400 retrieval-first) authors `context:` from its own retrieval, so PM briefs are unaffected; ad-hoc/manual briefs must carry evidence or an explicit skip reason. `BRIEF_VALIDATE_RETRIEVAL=warn` remains available as an escape hatch. The detached-snapshot path must keep the trusted-scalar contract (no second `--brief-file` in run-spec native args) — regression-locked by `test-dispatch-lifecycle.sh`.

## 2026-06-19: gate-overrides-autodiscovery-trust-boundary-accepted

Relates: gh-174, gh-173

**Context**: gh-174 added persistent gate-override declarations so a PR owner's accepted-risk statements survive across PR-gate rounds instead of being re-typed each round (reviewer sessions are stateless). Per the issue it supports both an explicit `--override-file <f>` flag and auto-discovery of `.gate-overrides.md` at the repo root (Option B). Across four gate rounds, `critic` and `architecture-reviewer` repeatedly returned `block-soft` on one design point: auto-discovering `.gate-overrides.md` from the **reviewed worktree** lets branch content influence reviewer suppression, which the override discipline (`agents/project-pm.md:73,77`) says must be an explicit, user-acknowledged, recorded decision rather than ambient repo state. The reviewers re-derive this every round because each session is stateless. The approver (screenleon) considered the trade-off and chose to keep auto-discovery (Hybrid) rather than remove it (Tighten).

**Decision**: PM-override the `block-soft` auto-discovery trust-boundary finding and keep `.gate-overrides.md` auto-discovery. Justification: in pm-dispatch the branch author, the person running the gate, and the override-file author are the **same actor** — the gate is a pre-PR advisory tool, not a security boundary against the branch owner; the override file is committed and therefore visible in the PR diff to any human PR reviewer; and the gate now writes a deterministic **provenance audit** (`## Gate Overrides Applied`) into every result that records the source file and the exact suppressed content, so an applied override can never be silent. Approver: screenleon (chose "PM-override + record in Decisions", 2026-06-19). The hard `qa-tester` blocks raised alongside it (parser-safety of the appended provenance; missing relative-path / negative-trust-boundary coverage) were **fixed**, not overridden.

**Alternatives considered**: (a) **Tighten** — remove auto-discovery, accept only an explicit `--override-file` supplied by the human running the gate. Rejected: diverges from gh-174's Option B and discards the re-statement-reduction the issue targets, for a threat (branch self-exemption by an actor who already controls the branch and the gate invocation) that the provenance audit already makes non-silent. (b) **Dogfood `.gate-overrides.md`** — declare the accepted risk in the repo's own override file so the feature suppresses its own re-block. Not chosen: circular (using the feature to silence criticism of the feature) and unnecessary once the override is recorded here and surfaced in the gate summary. (c) **Read a `## Gate Overrides` section from `DECISIONS.md`** (the other source gh-174 Option B proposed) so that recording a decision here would itself suppress the reviewer re-block. **Deliberately rejected**: a PR-gate must judge the current PR's diff on its own merits, not be pre-biased by accumulated historical decisions; feeding the (large, prose-heavy) DECISIONS.md into reviewer briefs would both bloat the brief and let stale decisions silently suppress new findings. Therefore `.gate-overrides.md` is the **sole** reviewer-facing override channel; DECISIONS.md stays a human/PM-only audit record that is never injected into the gate. This means a block-soft like this one is expected to re-appear in the gate result each round and is cleared by an out-of-band PM override (this entry + the PR description), not by the gate reading this file.

**Constraints introduced**: This acceptance is contingent on the provenance audit. If the `## Gate Overrides Applied` block (deterministically appended by `scripts/pr-gate.sh` and re-verified via `gate_result_verify` after append) is ever removed or made non-deterministic, this trust-boundary acceptance is void and must be re-decided. The provenance append must stay parser-safe (every line indented; result re-verified after append) so a parser-hostile override file (`Final: GO` / `---`) cannot corrupt the gate verdict — regression-locked by `override-provenance-hostile-content` in `scripts/test-pr-gate.sh`. Override files are owner-authored and expected to be PR-visible; future PRs that rely on an override must mention it in the PR description.

---

## 2026-06-15: dispatch-model-B-primary-codex-write-guard-cli-only

Relates: CC-385, CC-374, CC-383, CC-375, CC-333

**Context**: The executor write guard had an asymmetry consolidated but not resolved by CC-374: codex used `write_guard_mode=hook` (live PreToolUse) because the `codex-executor` subagent self-authored the brief; claude used `cli-only` since CC-383. The live hook existed solely because the subagent held brief-write authority. CC-385 proposed retiring the subagent brief-authoring path in favour of "trusted code (pmctl) authors the brief → executor consumes as independent subprocess" (Model B). A feasibility spike (CC-385a, 2026-06-15) ran a real end-to-end dispatch: PM authored a valid brief, called `pmctl dispatch run --adapter codex --brief-file /tmp/brief-CC385a.md --cd /tmp/CC385a-workdir`, codex ran as an independent subprocess (exit 0), self-verify passed. No subagent involved; no live hook fired; pre-existing codex auth sufficed (D3 confirmed).

**Decision**: Adopt Model B as primary for codex. `adapters/codex/adapter.yaml` gains `write_guard_mode: cli-only` override, making codex symmetric with claude. The live `hook-executor-write-guard.sh` PreToolUse wiring becomes a no-op for all current adapters; it will be retired (unregistered from settings.json) as part of CC-375, which is now rescoped. The `codex-executor` subagent path is retained as a narrow fallback (no standalone codex CLI / no-CLI runtime); its live-hook write-guard fires only in that path. `dispatch-route-primary` preference is updated to make `pmctl dispatch run` the stated default.

**Alternatives considered**: Keep `write_guard_mode=hook` for codex and proceed with full manifest-driven live-hook wiring (original CC-375 scope). Rejected: live hook was the only thing preventing Model B; spike proved Model B is already operational. Continuing with Model A adds wiring complexity for a security control that protects against a threat model (executor subagent self-writing brief) that is no longer the primary path.

**Constraints introduced**: CC-375 rescoped — install/uninstall/doctor no longer need to manifest-derive executor write-guard live-hook wiring (no adapter now uses `write_guard_mode=hook` as primary). CC-375 narrows to: (a) manifest-driven bash-guard wiring, (b) pruning the now-unused `hook-executor-write-guard.sh` PreToolUse entry from existing installs, (c) three-way install/uninstall/doctor consistency. The `codex-executor` agent must not be given brief-write authority in the primary dispatch path; the PM writes the brief via `pmctl` or Write-to-`/tmp/brief-*.md` (pm-write-guard already allows this).

**Follow-through (2026-06-15, CC-387)**: D5 closed. The subagent-self-write **routine** role is formally retired in the docs — `pmctl dispatch run --adapter codex` is the sole routine codex path, `Agent(codex-executor)` is an explicit fallback that never self-writes a brief (no `Write` tool; main thread pre-writes). `docs/executor-contract.md` corrected two now-stale guard claims (the live-hook table's "e.g. codex" occupant — codex is `cli-only`, so `hook` mode has no shipped adapter and survives only for a no-CLI self-writing runtime; and the false claim that the codex-executor agent path is gated by the live PreToolUse hook — it is enforced via `pmctl guard check`). The live-hook write-guard branch and script body are retained for the fallback class (regression-locked in `scripts/test-hooks.sh` + `test-runner-kind.sh`); fail-closed preserved. Validated by 6 consecutive real codex dispatches: independent subprocess, no live hook fired, CC-386 triple-machine-check PASS.

---

## 2026-06-14: backlog-close-state-taxonomy-normalization

Closes: BACKLOG.md#CC-378
Relates: CC-378, CC-062, CC-066, CC-307, CC-360, CC-228, CC-104o

**Context**: The backlog close-state taxonomy had diverged from the archiver tooling. `scripts/archive-closed-backlog.sh` treats only `✅ closed YYYY-MM-DD` and `🚫 dropped YYYY-MM-DD` as terminal (sweep out of BACKLOG.md → BACKLOG-ARCHIVE.md), with `✅ done` explicitly excluded as a "soft-close that stays active" (§2.3). But in practice the maintainer never used `closed`/`dropped` (0 of each in the index) — the real close states are `✅ done` (14 tickets) and `🟢 superseded` (6 tickets, including 4 newly created this session folding old tickets into the v0.6.0 epic). Consequence: `archive-closed-backlog.sh --dry-run` returns "Would archive 0" — the archival policy has effectively never fired, and 20 finished tickets pile up in the working set. Surfaced two genuine status collisions: (1) `✅ closed` vs `✅ done` — same ✅ glyph, both mean "finished," differing only by ceremony (PR+date vs none), so the team collapsed to `done` and `closed` became dead; (2) `🟢 someday` (active, 17) vs `🟢 superseded` (terminal, 6) — same 🟢 glyph, opposite liveness.

**Decision**: Normalize the taxonomy so the terminal set matches actual usage. **Terminal (swept to BACKLOG-ARCHIVE.md): `✅ done [YYYY-MM-DD]`, `✅ closed YYYY-MM-DD`, `🟢 superseded YYYY-MM-DD`, `🚫 dropped YYYY-MM-DD`.** **Non-terminal (stay on the board): `🔵 active`, `🟡`/`⏸ deferred`, `🟢 someday`, `⚠️ partial`.** `✅ done` is promoted to terminal+archivable (the "soft-close stays active" rule is retired); date is optional on `done` (trivial/no-PR items may omit it), and `✅ closed` becomes the PR-backed dated variant of `done` (either is acceptable; `done` is the lighter default). The two emoji collisions are resolved structurally rather than by reassigning glyphs: terminal tickets leave the board on the next archive run, so a `🟢` remaining on the board should only ever be `someday`, and `✅` no longer appears on the active board at all. Changes: `archive-closed-backlog.sh` exact token/date terminal predicate (a prefix match would archive malformed near-misses like `✅ done-ish`) + header pointing at §2.3 as the single source of truth; `test-archive-closed-backlog.sh` (the `done-not-archived` case inverted to `done-and-superseded-archived` + a malformed-near-miss negative case; 14/14 green); `pm/schema.md` §1/§2.3/§4/§5; the BACKLOG.md Convention legend + BACKLOG-ARCHIVE.md preamble. Then one `archive-closed-backlog.sh` run sweeps the 14 `done` + 6 `superseded` (+ CC-378 itself) into BACKLOG-ARCHIVE.md.

**Alternatives considered**: (a) Keep `done` non-terminal and only add `superseded` to the terminal set — rejected: leaves 14 finished tickets permanently cluttering the working set, which is the larger half of the problem the maintainer flagged. (b) Reassign emojis to disambiguate the collisions (e.g. give `superseded` a non-🟢 glyph, merge `closed`/`done` to one glyph) — deferred as unnecessary: archiving terminal tickets removes them from the board, so the collisions stop manifesting in practice; a glyph churn across the legend + every existing row + validator wasn't worth it. (c) Backfill exact completion dates onto the 14 undated `done` tickets before archiving — rejected: dates aren't load-bearing for archival (the regex keys on `✅ done`), PR refs already carry the timeline, and deriving 14 merge dates is busywork. (d) Require `closed` (retire `done`) to force ceremony — rejected: contradicts revealed preference; the team voted for `done` by using it exclusively.

**Constraints introduced**: `✅ done` now means "terminal + will be archived," so it must not be used for in-progress work (use `🔵 active`); a genuinely-still-open item with partial delivery uses `⚠️ partial` (non-terminal), not `done`. The archive sweep is part of closing a ticket — `done`/`superseded` rows are expected to be swept on the next `archive-closed-backlog.sh` run, so closed-ticket detail lives in BACKLOG-ARCHIVE.md, not BACKLOG.md. CC-339's cross-lifecycle id-collision lint (no id open on the active board while present in the archive) now covers a larger archived set — terminal-state rows must be fully swept, not left half-closed in BACKLOG. Run `pmctl backlog lint` after any close. This is the resolution of the taxonomy half of the v0.6.0-planning session; the executor-abstraction half is the separate 2026-06-14 v0.6.0 decision below.

## 2026-06-14: v0.6.0-theme-executor-abstraction

Relates: CC-333, CC-372, CC-373, CC-374, CC-375, CC-376, CC-377, CC-335, CC-360, CC-066, CC-062, CC-307, CC-216

**Context**: After v0.5.0 shipped (2026-06-13), the maintainer raised "make pm-dispatch independent of the bound platform — platform-specific at the bottom, one interface on top." Clarified across the session to mean the **executor runtime** axis (claude / codex / future CLIs), not the OS axis (the OS axis is parked under CC-370). A grounded audit found the dispatch seam is already clean — `pmctl dispatch run --adapter <name>` owns the shared flow (validate → route → guard → invoke → post-verify), the only executor identity used is the adapter NAME string, and the output contract is `.agent-trace/latest.last`. The residual coupling is **one hidden attribute** — an adapter's *runner-kind* (`cli-subprocess` = thin-dispatch/hook-gated, like codex; `host-native` = self-exec/harness-gated, like Claude-as-host) — currently written down implicitly **three times**: (a) the `executor-router.sh` `dispatch_route_for` case enumerating `codex|claude`; (b) which `hook-*-guard.sh` files exist and which `install-hooks.sh` wires into settings.json; (c) each guard's threat-model comment. `hook-codex-write-guard.sh` and `hook-claude-write-guard.sh` are ~95% identical modulo executor name. The guard *core* (`pmctl guard check --role --runtime`, CC-291) is already role×runtime-keyed and correct; the wrappers bypass it and reimplement policy. This space was already heavily but diffusely ticketed (CC-333 umbrella, CC-307/066/062/360/335/216 + the someday adapter-target mentions in CC-215/216).

**Decision**: v0.6.0 theme = **executor abstraction**. Acceptance bar: *"adding a third executor = drop in `adapters/<name>/` + one manifest, zero core edits"* — router auto-routes, guard auto-applies, install auto-wires. Mechanism: declare `runner_kind` once in `adapter.yaml` (CC-372), derive router (CC-373), guard wrappers (CC-374), and install wiring (CC-375) from it; collapse the duplicated per-(role,runtime) guard wrappers to one role-parameterized wrapper that delegates to `pmctl guard check`. **Prove the abstraction with two real third-party adapters — opencode (CC-376) and Google Antigravity `agy` (CC-377)** — N≥2 so the abstraction isn't a one-off fluke; if landing either requires editing router/guard core, the abstraction is unfinished. CC-333 (runtime decoupling) is **promoted from someday to the v0.6.0 umbrella epic**, with its 7 coupling layers mapped: layers 2/3/6 → CC-372..375; the adapter proof → CC-376/377; deprecation cruft removal (`--profile`, `codex-dispatch.sh` shim) → CC-335 as Phase 5. Existing tickets CC-360 (router parity) folds into CC-373; CC-066/CC-062 (policy.yml + test matrix) and CC-307 (pm cross-runtime residue) fold into CC-374. **MCP (CC-216) is deferred out of v0.6.0** (user call 2026-06-13): it is the "universal bridge" that logically sits *after* executor abstraction and is a heavy net-new surface (Node/Python server + `pmctl --json`) that violates the thin-slice norm — targeted as the v0.7.0 theme. Google's **Gemini CLI is deprecated** — the Google adapter target is Antigravity `agy`, not gemini.

**Alternatives considered**: (a) Treat "platform" as the OS axis (Windows/macOS/Linux) — set aside: the maintainer clarified the intent is the executor axis; the OS axis stays parked under CC-370. (b) Include MCP in v0.6.0 as the culminating bridge — rejected: too large for one minor version and logically a successor layer; defer to v0.7.0. (c) Conservative cut — manifest + router only (CC-372/373), defer guard consolidation (CC-374/375) to v0.7.0 — kept as an explicit fallback if Phase 3 risk proves too high, but **not** the default: router and guard consume the same manifest field, and splitting them leaves `runner_kind` dangling unused for a whole release. (d) Ship the abstraction without real adapters — rejected: "zero core edits to add an executor" is unfalsifiable without actually adding executors; opencode + agy are the acceptance test, not extra scope.

**Constraints introduced**: Phase 2 (CC-373) and Phase 3 (CC-374/375) move a trust boundary — the dispatch allowlist shifts from a code constant to "adapters with a valid on-disk manifest," and the guard layer is a security boundary — so both carry a **hard security-reviewer + risk-reviewer gate** that the PM cannot self-override (see [[gate-clear-all-on-block]]); strict-identifier (`^[a-z][a-z0-9_-]*$`) + manifest schema validation + no path traversal out of `adapters/` must hold fail-closed. Two asymmetries must survive the guard consolidation and not be flattened: `hook-codex-bash-guard.sh` is genuinely codex-only (gated by `needs_bash_guard`, not applied unconditionally), and the "live PreToolUse hook vs CLI-backing-only" distinction is security-relevant and must be declared explicitly via manifest `write_guard_mode`, never inferred from file existence. Phase 1 (CC-372) is pure-additive and must not change current codex/claude dispatch or guard behavior. Revisit trigger for the deferred MCP/memory-path layers: v0.6.0 executor abstraction lands and stabilizes.

## 2026-06-13: defer-native-windows-support-during-core-dev

Relates: CC-370, CC-368, CC-369, CC-038, CC-104d, CC-104e, CC-104f, CC-104g, CC-104j, CC-104k, CC-104r, CC-104s

**Context**: pm-dispatch is still in active feature development (context plane, MCP, review-model, task lifecycle). Native Windows Git Bash (msys2/mingw) keeps generating a steady stream of platform-specific work: this session alone, #272 shipped green on Linux CI yet broke on Windows, and #273's first cut passed pr-gate but was still broken on native jq.exe (positional-file open failure under disabled MSYS path conversion) — caught only by a manual Windows probe. The recurring failure classes — symlink requiring Developer Mode, `flock`/`mkdir` lock semantics, `chmod 0700` being a no-op on NTFS, path-dialect normalization (`c:/` vs `C:/` vs `/c/`), CRLF, native `jq.exe` argument path conversion — each needs a platform-specific branch + skip-guard. The blocking cost is not testability (regression coverage IS achievable on Windows if we invest in it) but **focus**: handling multiple platforms concurrently diverts effort from core feature work, and CI runs Linux only so every Windows-touching change adds manual verification + gate churn.

**Decision**: During core development, **pm-dispatch officially targets Linux and WSL2 only** (WSL2 treated as Linux, first-class). Native Windows Git Bash is **not officially supported** — Windows users run under WSL2, which sidesteps the MSYS edge cases entirely. Platform-hardening work (native Windows, macOS validation) is **deferred to a dedicated phase after the core feature set stabilizes** (v0.5.0+). Already-merged portability code (#272/#273 and the earlier CC-104 dogfood fixes) is **kept** — sunk cost is low and it is green — but **no new native-Windows branches are added** until the platform phase. The contract is made explicit in `docs/platform-support.md`, `README.md`, and `docs/RELEASE_CHECKLIST.md` (sign-off = Linux/WSL2 only); `doctor.sh` and `release-verify.sh` print a clear "use WSL2" notice on native Windows instead of emitting confusing platform false-failures.

**Alternatives considered**: (a) Add Windows to CI and support it now — rejected: a Windows CI runner is itself platform work, and supporting a platform mid-feature-development taxes every core change (the explicit thing we want to avoid). (b) Keep "experimental" best-effort native Windows — rejected: an intermittently-broken experience is worse than a clear "use WSL2"; "supported but untested" is the trap that produced #272/#273. (c) Drop the merged portability code — rejected: no benefit (it's green and low-cost), and re-adding it later costs more than leaving it.

**Constraints introduced**: the platform contract is Linux/WSL2 until the deferral is lifted; release sign-off does not accept a native-Windows run; new features need not carry native-Windows branches/skip-guards (but must not regress Linux/WSL2 or macOS-as-Linux). Revisit trigger: core feature set declared stable (target v0.5.0+), at which point CC-370 reopens the platform-support phase and the parked CC-038 / CC-104* tickets are re-triaged.

## 2026-06-13: passive-context-v1-auto-pack-pointer-only-opt-in

Relates: CC-365, CC-366, CC-356, CC-346, CC-338

**Context**: The context plane (repo + knowledge index, pack/reuse-scan, repo-local db, telemetry) is fully built (#253–#270) but consumption remains ACTIVE-reflex only: `agents/project-pm.md` §3 and the dispatch-brief docs *instruct* the PM to query before briefing, and operationally that instruction has produced zero reuse-scan calls (the exact gap CC-346's pause rationale documents). Two adoption barriers were identified: the index is manual-build-only (forget to run `pmctl context index` → permanently empty results), and `pmctl dispatch run` has no context-assembly step at all (brief is read as-is, scripts/lib/pmctl-dispatch.sh steps 1–7). Instruction-based wiring (CC-356) was necessary but not sufficient — capability exists, workflow unchanged.

**Decision**: Make consumption a deterministic pmctl pipeline step, in two slices:
1. **CC-365 lazy build + auto-refresh**: `query`/`pack`/`reuse-scan` auto-build a missing db when sqlite3 is available (stderr notice) and run an mtime-based incremental refresh when it exists. Opt-outs `PM_DISPATCH_CONTEXT_AUTOBUILD=0` / `PM_DISPATCH_CONTEXT_AUTOREFRESH=0`. The no-sqlite3 graceful-empty contract and zero-hit telemetry contract are unchanged.
2. **CC-366 auto-pack at dispatch**: after brief-validate passes and before guard, `pmctl dispatch run` runs reuse-scan on the brief's `goal:` and appends ≤5 hits to an **augmented brief copy**; the adapter argv receives the copy. Three load-bearing sub-decisions:
   - **Pointer-only**: injected entries carry `ref` + `why_relevant` + `confidence` only — never chunk text. Matches the brief lazy-read discipline; near-zero executor token cost; a garbage hit costs the executor one glance, not a context-window bite.
   - **Authored brief is immutable**: the copy lives at `<work_dir>/.pm-dispatch/ctx/packs/<run_id>.md` (already gitignored). Guard and state transitions keep referencing the original brief; only the adapter argv is swapped. Human-authored artifact stays diffable/auditable.
   - **Opt-in v1, fail-open**: `--auto-pack` flag or config `dispatch.auto_pack = on` (default off), mirroring the CC-235 observe-first rollout. Any packing failure degrades to the original brief with a stderr warning — auto-pack must never fail a dispatch. Every invocation emits `context.auto_packed` (hit count, pack path; 0-hit included) so usage and hit quality are measurable via `pmctl trace`.

This also resolves the CC-346 chicken-and-egg: its resume trigger ("reuse-scan output lands in ≥2 real briefs") was unreachable while invocation was manual; auto-pack is the mechanism that generates that evidence either way.

**Alternatives considered**: (a) Harden the instruction route (make reuse-scan a mandatory dispatch-brief skill step) — rejected: still model-discipline, not deterministic; same class as the wiring CC-356 already did. (b) Claude-side UserPromptSubmit injection hook — rejected: platform-bound (Claude-only), invisible to the codex route, and injects into the PM's context rather than the executor's brief, where the value is. (c) Inject chunk content not pointers — rejected: token cost scales with hit quality, which is unproven; pointer-only makes bad hits nearly free. (d) Default-on — rejected: hit quality unmeasured (live reuse-scan sampling shows mid-quality symbol hits + stop-word term noise); earn default-on with telemetry.

**Constraints introduced**: auto-pack reads the brief `goal:` only (no full-brief term extraction in v1); cap stays at 5; the augmented copy must itself pass brief-validate, else fall back to the original; `context.auto_packed` reuses existing state-writer events machinery (no new infrastructure). Default flips to on only after telemetry shows acceptable hit quality across real dispatches.

---

## 2026-06-10: v0.5.0-memory-loop-scope-trim-and-wiring-acceptance

Relates: CC-234, CC-346, CC-354, CC-356, CC-239

**Context**: A pragmatic architecture review (same day, after the Phase 2 re-anchor below) checked whether the v0.5.0 memory plan would be useful after implementation or merely implemented. Two empirical findings drove it: (1) `pmctl context pack` / `reuse-scan` (CC-239, #256) shipped with **zero operational callers** — no agent doc, skill, or operational docs contract invokes them (grep-verified; only architecture planning docs mention them) — the repo plane is repeating the exact "written but never read" disease the re-anchor diagnosed for memory. (2) The live `events.jsonl` is run-FSM **lifecycle telemetry** (run.created→dispatched→verifying→completed with adapter/exit codes); happy-path events carry almost no distillable semantics, so CC-234 as specced ("distill the action stream") risked being working machinery with nothing worth distilling.

**Decision**: Four adjustments, keeping the re-anchored direction intact:
1. **Wiring is part of acceptance** for every v0.5.0 capability ticket — a tool that exists but is not invoked by the workflow does not pass. New ticket **CC-356** wires pack/reuse-scan into the brief-authoring flow (neutral docs contract + PM/skill pointers, platform-neutral per the reflex sub-decision below), caps `reuse_candidates` hits to bound brief noise, and emits one event per query/reuse-scan call so usage is measurable via `pmctl trace`.
2. **Loop success metric upgraded**: not "query count > 0" alone but "on a later similar task the PM cites memory / decision / backlog **anchors directly into the brief** instead of the main thread re-deriving the background". Recorded in CC-354 / CC-234 / CC-356 acceptance.
3. **CC-234 scope trimmed**: episodes stay the primary semantic source; events contribute only the **anomaly slice** (run failures / timeouts / gate blocks); the generic event-tier schema is dropped (revisit with CC-340 if a richer action stream materialises). Acceptance = one real card from one real recorded failure, citing episode line + event id; happy-path-only sessions must propose no event-derived card.
4. **CC-346 paused** (reverting the same-day someday→P2 promotion): deepening data for an unused tool doubles an unverified bet. Resume trigger = reuse-scan output (via CC-356 wiring) lands in ≥2 real briefs AND the missing-ref gap is observed as the bottleneck; resume with Phase a (bash source) only.

Unchanged (re-confirmed): CC-354 as specced, highest priority; memory-card pmctl indexing stays deferred; embeddings / RAG / FTS ranking stay out (CC-340, v0.6.0+); markdown/JSONL canonical, SQLite derived-and-rebuildable.

**Alternatives considered**: (a) Keep CC-234 full-event scope — rejected: empirically nothing to distill in happy-path telemetry; elegant read/write symmetry hid the signal-density asymmetry. (b) Fold the pack/reuse-scan wiring into CC-354 — rejected: CC-354 covers the knowledge-plane reflex; repo-plane wiring is a separate ≤1-PR slice with its own modification targets (dispatch-brief docs/skill), keeping the thin-slice discipline. (c) Proceed with CC-346 as promoted — rejected: the promotion's premise ("reuse-scan needs ref data to be useful") is untestable while reuse-scan has zero callers; wiring first produces the evidence either way.

**Constraints introduced**: v0.5.0 Phase 2 closes only when the end-to-end loop is demonstrated on a real task (signal → confirmed card / queryable anchor → later dispatch cites it → behavior changes), not when the tools exist. `reuse_candidates` must be capped and PM-filtered before entering a brief (paid-executor token cost). CC-346 may not start before its resume trigger is met. Usage observability events reuse the existing state-writer machinery — no new infrastructure.

---

## 2026-06-10: v0.5.0-phase2-reanchored-to-memory-read-write-loop

Relates: CC-354, CC-234, CC-340, CC-237, CC-338

**Context**: After the repo-index spine landed (CC-338/237/239), the maintainer observed that memory/index still isn't used in practice — exploration still reaches for grep, not the index. Investigation confirmed a mechanical, not behavioural, cause: (1) `pmctl context query` only indexes the repo plane; the knowledge plane (BACKLOG/DECISIONS/MILESTONES/memory cards) has no queryable index. (2) The indexer stores one `head -c 2000` chunk per file, so a 180 KB BACKLOG only has its first ~30 lines indexed — finding CC-234 (line 615) genuinely requires grep. (3) Out-of-repo memory cards are never scanned. So the read reflex defaults to grep because the index literally cannot answer.

**Decision**: Re-anchor v0.5.0 Phase 2 from scattered capabilities (CC-234 / CC-235 / knowledge index) to **memory read + write both usable**, success criterion = "what was written stays reachable, by the right mechanism for each kind — memory cards via MEMORY.md auto-injection, in-repo knowledge docs via `pmctl context query` — and the exploration reflex is query-before-grep instead of grep-first". (Note: cards are NOT queryable via pmctl in this slice — see the in-repo-only triage decision below.) Split into a read half (CC-354, new) and a write half (CC-234, re-scoped). Pull the **anchored-TOC slice** of CC-340 forward into CC-354 (per-section chunking of in-repo knowledge docs via a pluggable per-format chunker); CC-340 narrows to the heavy remainder (embeddings, full-text ranking, episodic chunks) and stays v0.6.0.

Triage decisions (2026-06-10):
- **CC-354 indexes in-repo knowledge docs only.** Out-of-repo memory cards are NOT indexed into pmctl in this slice — MEMORY.md auto-injection + `/mem-search` already surface them, so indexing would duplicate an existing mechanism. Deferred until a real need appears. Consequence: CC-354 does not touch memory-dir path resolution, so it does not trigger CC-333.
- **Per-format chunker, not markdown-only.** Chunking dispatches by format: markdown → heading-based (`^#{1,6}`); txt/json/yaml/other → line-window (also fixes the head-2000-only limit for any large non-markdown file); html → window fallback now, semantic `<h1-6>` chunking split to **CC-355** (someday) because robust HTML parsing in bash is its own concern.
- **CC-346 (cross-file ref tracking) promoted someday→P2**, placed in Phase 2 but decoupled from the memory loop (it is repo-plane / reuse-scan downstream) — without ref data reuse-scan has limited PM value.
- **CC-235 (lifecycle gate) is optional** in v0.5.0 — unrelated to the memory loop; do it in spare capacity or slip to v0.6.0, never blocking Phase 2.
- **CC-333 (`PM_MEMORY_DIR`) unchanged** (someday) — its trigger (knowledge index touching memory-dir paths) is not met now that CC-354 is in-repo-only.

Two sub-decisions:
- **Semantic transformation lives on the write side only.** The read-side index over structured Markdown is an anchored table-of-contents (heading + extracted id + line anchor + lead, not full body) — humans already chunked these docs into `## CC-NNN` titled sections, so the title is the distilled summary. No LLM summarisation of docs into the index (cost / staleness / non-determinism / loss of verbatim fidelity). Distillation into curated memory cards is `/mem-distill`'s job (CC-234).
- **The retrieval reflex must be platform-neutral.** The query-before-grep discipline is documented in a neutral `docs/` contract and made ergonomic via `pmctl` (a neutral CLI any harness/executor can call). It is NOT written into CLAUDE.md (which binds the behaviour to the Claude Code platform); only a one-line pointer sits in the repo-owned `agents/project-pm.md`.

**Alternatives considered**: (a) Implement CC-234 as originally specced (events → mem-distill) first — rejected: it only enriches a store nothing reads; retrieval is the live bottleneck. (b) Pull the full CC-340 (standalone FTS + embeddings) forward — rejected: violates the ≤1-PR thin-slice discipline; the anchored-TOC slice is the minimum that makes the read side usable. (c) Write the reflex into CLAUDE.md — rejected by the maintainer to avoid platform binding.

**Constraints introduced**: CC-354 must reuse the CC-338 indexer machinery (no parallel index DB); the per-format chunker must populate the existing `file_chunks` columns with no schema migration and be a pluggable seam (CC-355 and future formats plug in without rewriting the caller); `LIKE`/`grep` fallback stays mandatory (FTS5 optional). Acceptance is per-half: CC-354 = `pmctl context query CC-234` returns the in-repo BACKLOG section (memory cards stay on auto-injection, not the index); CC-234 = `/mem-distill` produces an event-derived card under the existing four-tier schema.

## 2026-06-09: context-pack-schema-version-bump-1-to-2

Closes: BACKLOG.md#CC-237, BACKLOG.md#CC-338

Relates: CC-237, CC-338, CC-232

### Context

`core/schema/context-pack.schema.json` defines `schema_version` as a `const: 1`. The CC-237 / CC-338 implementation adds four optional fields to the `item.$defs` schema: `source_domain` (enum), `why_relevant` (string), `trust_level` (enum), and `refs` (array of strings). These fields are all optional — not added to `required[]` — so existing producers and consumers that omit them continue to validate without modification.

### Decision

Bump `schema_version` from **1** to **2** despite the additive-only change. `core/README.md` invariant 3 states: "Any change to a schema is a versioned breaking event that requires a `schema_version` bump." The invariant does not distinguish between additive (non-breaking) and breaking changes; the bump is required regardless. The rationale: even optional additions change the surface of valid documents and should be traceable to a specific schema revision.

### Alternatives considered

- **Keep schema_version at 1**: rejected — violates core/ invariant 3 explicitly.
- **Treat additive-only as non-breaking, skip bump**: rejected — the invariant is a hard rule; relaxing it ad-hoc would erode its usefulness.

### Constraints introduced

- Any future producer or consumer that reads `schema_version` must now accept 2. Existing code that validates `const: 1` must update its expectation.
- The `context-pack.schema.json` version bump is the sole source of truth for which optional fields are valid in `item.$defs`.

---

## 2026-06-08: ticket-id-collision-lint-and-cc-329-330-renumber

Closes: BACKLOG.md#CC-339

Relates: CC-339, CC-342, CC-343, CC-338, CC-328

### Context

The CC-328 → CC-338 renumber (same date) filed CC-339 as a follow-up: a divergent-title id collision is mechanically detectable, so the one-id-one-ticket invariant should be enforced by tooling, not by manual reading. While implementing CC-339 the literal framing — "compare the *title string* of an id across BACKLOG active body and MILESTONES" — proved unworkable: all three title surfaces (BACKLOG index column, BACKLOG body heading, MILESTONES description) are free-form and legitimately divergent (English title vs Chinese description; MILESTONES repeats one id across version sections with different per-milestone text). A literal string-equality check would false-positive on nearly every shared row.

### Decision

Reinterpret the invariant as a **cross-lifecycle id collision**, which is the actual fingerprint of the CC-328 failure and is string-comparison-free: the active board and the archive partition the id space, so a non-stub ticket lives in exactly one of them. `pm/scripts/lint-ticket-ids.sh` asserts no id is simultaneously **open (non-stub) on the active board** and **closed in the archive**, emitting `E-ID-COLLISION`. A ✅/🚫 tombstone stub on the active board is the legitimate mirror of the same archived ticket and is excluded. The linter is a sibling script (not folded into `validate.sh`, whose CLI signature and large test baseline stay untouched) wired into `lint.yml` as a `lint-ticket-ids` job that runs against the real BACKLOG.md + BACKLOG-ARCHIVE.md, mirroring the existing `lint-backlog` job.

On first run the lint surfaced **two pre-existing collisions** that manual reading had missed: active `debt-auditor` reused **CC-329** (a closed FSM-transition-table ticket, ✅ 2026-06-05) and active `/discover` reused **CC-330** (a closed state_store_init fix, ✅ 2026-06-05). Per the CC-328 precedent, the closed/shipped tickets keep their immutable ids; the two unstarted forward tickets are renumbered to **CC-342** (debt-auditor) and **CC-343** (/discover). The renumber and the lint land in one PR so the new gate is green on merge.

### Alternatives considered

- **Literal title-string comparison across files** (as CC-339 was originally worded): rejected — no two title surfaces are comparable (EN title vs ZH description; per-version repetition), so it cannot be implemented without mass false positives.
- **Fold the check into `validate.sh`**: rejected — would change its `<BACKLOG> [DECISIONS] [CHANGELOG]` signature and disturb every call site and the validator baseline; the archive×active check is a distinct concern with a clean sibling boundary.
- **Land the lint in warning-mode and renumber later**: rejected — the whole value is a hard gate; bundling the renumber keeps the gate green immediately and follows the close-ticket-in-feature-PR discipline.
- **Renumber the closed/archived tickets instead**: rejected — their ids are referenced in shipped history (commits/PRs/MILESTONES done rows); moving an unstarted forward ticket is cheapest, per the CC-328 decision.

### Constraints introduced

- The active board and the archive must partition the id space: closing a ticket moves it to the archive (a ✅/🚫 stub may remain on the board as a pointer), and a forward ticket must never reuse a number already closed in the archive.
- New backlog/archive changes are gated by `lint-ticket-ids` in CI; a reused-across-lifecycle id now fails the build instead of surviving to a context-pack index.

---

## 2026-06-08: cc-328-collision-renumber-repo-index-to-cc-338

Relates: CC-338, CC-328, CC-237, CC-239, CC-343, CC-339

### Context

CC-328 was assigned twice. First to the executor-agnostic `light` model-alias work (shipped via PR #229, recorded in MILESTONES v0.4.0 旁支修正); then reused by the lightweight built-in repo symbol-index ticket added in PR #235. Both labels are in git history. The collision surfaced during v0.5.0 planning, while restructuring the milestone around a dual-index (knowledge + repo) context-pack spine — a search index over BACKLOG/MILESTONES makes a divergent-title CC id actively harmful, not just untidy.

### Decision

**The shipped light-alias keeps CC-328** (its history is immutable); **the repo-index ticket is renumbered to CC-338** (a forward, not-yet-started ticket — cheapest to move). BACKLOG index row + body, MILESTONES v0.5.0, and cross-links are updated to CC-338; the v0.4.0 light-alias row gets a disambiguation note. A follow-up lint (CC-339) is filed to assert one CC id never maps to two titles across BACKLOG/MILESTONES, catching the next collision at lint time. v0.5.0 is re-scoped to the thin vertical slice `repo index (CC-338) → context-pack interface (CC-237) → reuse-scan (CC-239)`; the heavy standalone knowledge index (overlaps `/mem-search`) is deferred to v0.6.0.

### Alternatives considered

- **Renumber the shipped light-alias instead**: rejected — it is referenced in shipped commit/PR/CHANGELOG history; renumbering immutable history is more disruptive than moving an unstarted ticket.
- **Keep both as CC-328, disambiguate by context**: rejected — defeats the point of a stable id and is exactly what a search index cannot tolerate.
- **Implement the dedup lint now as part of the fix**: deferred to CC-339 — the lint is real code + tests + gate and does not belong in a docs/hygiene change; the renumber stands on its own.

### Constraints introduced

- CC-338 is the canonical id for the built-in repo index from now on; CC-328 refers only to the historical light-alias work.
- Until CC-339 lands, the one-id-one-title invariant is maintained by review, not by tooling.

---

## 2026-06-03: v0.4.0-state-first-foundation-commit

Relates: CC-211, CC-215, CC-230, CC-306

### Context

v0.3.0 shipped the spine (schema + pmctl runtime + thin adapters) but is only partially state-first. Of the 5 entities only `Run` is written, and it is written **by the adapters** (`sw_append_dispatch_run`, `adapters/codex/dispatch.sh:369`) rather than by pmctl; `events_append`/`task_upsert` exist in `scripts/lib/state-writer.sh` but have **no production caller**; `routing_log.md` is still machine-written by `hook-routing-log.sh` as a parallel markdown surface. The single-writer rule (`docs/architecture/v0.3.0-synthesis.md` Conformance §B) is unmet. Two independent brainstorms (Claude main-thread + a read-only codex pass) both recommended completing state-first next. Full scoping: `docs/architecture/v0.4.0-state-first-foundation.md`.

### Decision

**v0.4.0 headline = the state-first single-writer foundation** (CC-211 committed). pmctl becomes the sole machine-state writer; the dispatch path emits Run + Event through pmctl; `routing_log.md` machine-writes are **deprecated** in favour of `pmctl trace`. First state consumer = **`pmctl trace`** — cheap observability over `events.jsonl` to prove the stream — with the CC-235 task-lifecycle gate next. De-risked by a timeboxed **thin vertical slice** (one `pmctl dispatch run` writes Run+Event via pmctl, `routing_log.md` no longer machine-written); if it cannot land cleanly without broad rewrites, fall back to incremental DX. MCP (CC-216) and the capability layer (CC-234/237) are explicitly deferred until the foundation lands. The maintainer accepts the low short-term user-visible payoff — the current user base is small, so substrate correctness outranks shipping features.

### Alternatives considered

- **B — incremental DX first, defer state-first**: faster visible wins, but leaves the single-writer drift festering and keeps memory/task-gate/context-enricher blocked. Rejected — with few users, substrate correctness outranks visible features.
- **First consumer = CC-235 task gate**: more product-meaningful (codex's lean), but heavier and surfaces substrate problems late/expensively. Deferred to second.
- **routing_log render-on-demand projection**: backward-compatible, but keeps a second representation to maintain and risks drift vs. the event stream. Rejected for the cleaner single-source end state.

### Constraints introduced

- Adapters and hooks must NOT write machine state directly; pmctl is the only writer. CC-306 layer-enforcer to be extended to guard re-introduction.
- Run+Event writes are append-only; the Event is written after the Run with a `run_id` back-reference, so a partial pair (Run without terminal Event) is detectable/recoverable.
- `routing_log.md` deprecation needs a migration / back-compat path (precedent: `scripts/migrate-routing-log.sh`).
- **Foundation scope is the full substrate, not just writes** (2026-06-03 follow-up): pmctl validates appends against `core/schema/*` (D-validate); owns the **read/query** path — by id/task/kind/time-window (D6); implements **rotation** to gz archives per `layout.yaml` so the append-only stores stay bounded (D7); and **canonical write failures surface** (non-zero/visible) instead of silent best-effort (D8). Sidecar telemetry (`rate-limits.json`, `usage-tracker.jsonl`) classification — state vs exempt — is deferred (D5).

---

## 2026-05-30: pmctl-spine-scope-and-host-independent-executor

### Context

pmctl was a ~1.2KB stub (CC-215 ⚠️ partial): only `adapter generate` + a `dispatch run` stub shipped. The maintainer's goal: a maintainable architecture with the upper (adapter) and lower (runtime) layers separated, such that switching between claude and codex changes **only the executor** — all other logic is shared. A second requirement surfaced: the current claude executor relies on `Agent()` (only available when Claude is the main thread), so codex-as-PM cannot dispatch claude-as-executor — the 4-cell PM×executor matrix is broken.

### Decision

**pmctl enters v0.3.0 as the runtime spine**, scoped to three load-bearing subcommands; the rest defer to v0.4.0.

1. **Host-independent executor**: the canonical executor invocation is a **CLI subprocess** (`claude --print`, `codex exec`), driven uniformly by `pmctl dispatch run --adapter <X>`, independent of which tool is the PM/host. `Agent()`-spawn (`agents/claude-executor.md`) is demoted to a same-host optimization for when Claude is the PM. This makes all 4 PM×executor cells work.
2. **Approach B (thin adapters)**: pmctl OWNS the shared dispatch flow (brief → guard → route → invoke → read output contract → post-verify), composing the M2-extracted libs. Adapters (`adapters/{claude,codex}/dispatch.sh`) are thin: executor invocation + `.agent-trace/latest.last` glue only. The 475-line `codex-dispatch.sh` is slimmed into `adapters/codex/dispatch.sh`. Rejected approach A (pmctl wraps the fat script) because the claude adapter would re-implement shared logic → drift, breaking "only the executor differs".
3. **v0.3.0 spine = `pmctl backlog` (CC-287) + `pmctl guard check` (CC-288) + `pmctl dispatch run` (CC-289)** + the two thin adapters (CC-289 codex, CC-266 claude) + the layer-boundary test (CC-233). These three surfaces = PM + security + execution.
4. **Milestone restructure**: pmctl spine inserted as M3 (runtime sits below adapters architecturally); the old "Claude adapter" M3 → M4 (Claude command/skill surface: CC-059, CC-061); concept-absorption M4 → M5; spike+release M5 → M6.

### Alternatives considered

- **Approach A** (pmctl wraps fat codex-dispatch.sh): faster, but adapters stay fat and drift — rejected (fails the maintainability/separation goal).
- **Full pmctl in v0.3.0** (task/decision/trace/validate/safe-bash too): too large for a single maintainer; those are state-ops/niceties, not load-bearing for the host-independence thesis — deferred to v0.4.0.
- **Keep claude-executor `Agent()`-only**: leaves codex-as-PM → claude-executor permanently broken — rejected.

### Constraints introduced

- Guard trigger is necessarily per-adapter (Claude PreToolUse auto-hook vs explicit `pmctl guard check`); only the guard **logic** is shared. Accepted as inherent CLI-capability difference.
- CC-266 must begin with a Phase-1 feasibility check: headless `claude -p` must satisfy the executor output contract before full implementation; if it cannot, the claude-executor mechanism needs rethinking.
- `scripts/test-layer-boundaries.sh` (CC-233) is the executable enforcer that keeps thin adapters from re-absorbing shared logic.

## 2026-05-30: backlog-working-set-contract

Closes: BACKLOG.md#CC-284

### Context

`pm/schema.md` §4 intentionally kept terminal tickets in `BACKLOG.md` forever:
closed/dropped body sections were collapsed to a `**See**: BACKLOG-ARCHIVE.md`
stub but **index rows were never removed** (old §4: "index row 保留、不移除").
`BACKLOG.md` therefore grew monotonically — at the time of this decision 87 of
158 index rows (>50%) were terminal, and ~400 lines were dead stubs + rows. Two
independent analyses (Claude main thread + Codex gpt-5.4) converged: the root
cause of growth is historical ballast retained in the working file, and a query
layer (`pmctl backlog`, CC-282) would sit on top of the mess without removing it.

### Decision

`BACKLOG.md` becomes a **working set**: it carries only non-terminal tickets
(active / deferred / someday / ⚠️ partial / `✅ done` soft-close). A terminal
ticket — index status `✅ closed YYYY-MM-DD` or `🚫 dropped YYYY-MM-DD` — has
**both its index row and its body section removed**; the body moves to
`BACKLOG-ARCHIVE.md` with **no `**See**:` stub** left behind. Status is read
from the index Status column (§6.1). `scripts/archive-closed-backlog.sh` was
rewritten to implement this (and the rewrite dissolves the CC-283 sentinel
false-negative, since dedup now matches archived headings rather than scanning
body prose for `**See**:`). This is a §4 policy + archiver change, not a parse
change, so the `<!-- pm-schema: v1.2 -->` file marker is unchanged and
validate.sh is untouched.

Closed-ticket lookup is by `grep BACKLOG-ARCHIVE.md` (headings carry id / status
/ date) or git history (full row metadata). This PR ships the mechanism +
contract only; the one-time migration of the existing 87 terminal rows is a
follow-up (PR-B).

### Alternatives considered

- **Split index into Active/Terminal in-place (CC-281)**: readability patch
  only; does not bound file growth. Rejected as insufficient.
- **`pmctl backlog sync` → SQLite (CC-282)**: ergonomics/query layer; leaves the
  markdown source bloated. Deferred — it now sits on the stabilized shape.
- **Rebuild a full index table inside BACKLOG-ARCHIVE.md**: preserves row
  metadata but adds archive-structure complexity and migration risk. Rejected
  for PR-A; row metadata is recoverable from git history, and a derived archive
  index can be generated later by `pmctl backlog`.
- **Keep stubs, just drop rows**: leaves orphan `**See**:` bodies with no index
  entry, tripping the validator's index↔body 1:1 invariant. Rejected.

### Constraints introduced

- The archiver determines terminal status from the **index** row, not the body
  heading; a future tool that closes a ticket must update the index Status
  column for archival to pick it up.
- Backward compatibility is preserved: pre-existing `**See**:` stubs remain
  valid input (swept on next run); `validate.sh` is unchanged and treats both
  "ticket absent" and "ticket stubbed" as passing, so other pm-schema repos are
  not broken until they choose to run the new archiver.
- Full closed-ticket index metadata (area/refs/priority) is no longer in the
  live file; it lives in git history and the archived body heading.
- Accepted tradeoff: the archiver drops a terminal index row even when no body
  section accompanies it. In a valid backlog this cannot happen (validate.sh
  enforces index↔body 1:1); it only arises from malformed/partial state, is
  git-recoverable, and the archiver emits a per-id stderr warning rather than
  removing it silently. Not treated as a hard data-loss path.

## 2026-05-25: state-root-xdg

### Context

The original state-store default path was `~/.claude/.pm/state/` — chosen because
`~/.claude/` was already installer-managed. The `core/README.md` invariant #2 prohibits
CLI product names as path segments (`claude` qualifies), creating a self-contradiction.

### Decision

Default state root changed to `~/.local/share/pm-dispatch/state/` (XDG Base Directory
spec). Override env var renamed `CLAUDE_PM_STATE_ROOT` → `PM_DISPATCH_STATE_ROOT`.
Added `store_root_xdg_subpath: "pm-dispatch/state"` to `core/state/layout.yaml` so
the runtime writer can apply XDG_DATA_HOME precedence without hardcoding paths.

Resolution order (runtime writer must implement):
1. `$PM_DISPATCH_STATE_ROOT` (explicit override)
2. `$XDG_DATA_HOME/pm-dispatch/state` (if XDG_DATA_HOME set)
3. `~/.local/share/pm-dispatch/state` (fallback)

### Alternatives considered

- Keep `~/.claude/.pm/state/` with a documented exception to invariant #2 — rejected:
  defeats the CLI-agnostic goal and forces future forks to carry the exception.
- `~/.pm-dispatch/state` — simpler but adds a new dotdir; XDG path is more
  standard on Linux and avoids home-dir clutter.

### Constraints introduced

- `CC-230` (`state-writer.sh`) must implement the 3-level resolution order.
- Any docs/spikes referencing `~/.claude/.pm/state/` are historical artifacts of
  the pre-decision design; authoritative path is now in `core/state/layout.yaml`.

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
