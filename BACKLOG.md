<!-- pm-schema: v1.2 -->
# pm-dispatch backlog

<!--
ID PREFIX: CC
CC-001/CC-002 were consumed by PR #24 fix bundle inline, with no standalone entries; this file starts at CC-003.
-->

## Index

| #  | Status | 主題 | 影響面 | 首次記錄 | Refs | Priority | Epic |
|----|--------|------|--------|----------|------|----------|------|
| CC-476 | ✅ done | opencode `edit`+`bash` 同時 deny 時 `opencode run` 掛起根因調查（spike，CC-448 階段 2 blocking open risk） | install/ops | 2026-07-09 | pr:#390 | P2 | spike |
| CC-450 | 🟢 someday | 其餘 9 個 test-*.sh docstring 格式統一（CC-004 同款 Behavior/Steps，跨檔） | ops | 2026-07-03 | — | P3 | — |
| CC-475 | ✅ done | claude sonnet model alias 過期：`share/claude-model-aliases.tsv` 的 `default`/`sonnet` 仍釘 `claude-sonnet-4-6`，未跟進最新 `claude-sonnet-5`（opus/haiku 已對齊最新）（2026-07-09 使用者發現） | ops | 2026-07-09 | pr:#389 | P2 | — |
| CC-451 | 🔵 active | core/ 定義層接上 runtime：enum 單一來源 + state 寫入 schema 驗證（CC-446 契約凍結前置；2026-07-06 盲測稽核；v0.9.0） | arch | 2026-07-06 | — | P2 | design |
| CC-452 | 🔵 active | guard/hook 對稱性與併發 hardening：episodes.jsonl append 加鎖、三安全 guard set -e 統一、ISO8601 正規化抽 lib（2026-07-06 盲測稽核；v0.9.0） | ops | 2026-07-06 | — | P3 | hygiene |
| CC-453 | 🔵 active | worktree/auto-pack 路徑契約 hardening：worktree create stdout 契約、auto-pack work_dir fail-loud、opencode isolation 錯誤訊息修正（2026-07-06 盲測稽核；v0.9.0） | ops | 2026-07-06 | — | P3 | hygiene |
| CC-454 | 🟢 someday | CI shellcheck ignore_names 白名單 ratchet 收斂：獨立 job + 白名單清零機制（比照 CC-450 模式；2026-07-06 盲測稽核） | ops/test | 2026-07-06 | — | P3 | hygiene |
| CC-456 | 🔵 active | 去除 maintainer-local `~/github/` 佈局假設：repos-root 參數化 + prose/scripts/pm 層全面 sweep + lint 防再犯（2026-07-06 使用者指出；v1.0 public 前提；v0.9.0） | arch/portability | 2026-07-06 | — | P2 | oss |
| CC-460 | 🔵 active | `pmctl commands --json` manifest 單一來源 + router↔manifest↔README 三方防漂移 lint（承接 CC-033 #4 README surface 重建、CC-446 #5a `--json` 覆蓋率缺口；2026-07-07 openyida 跨專案分析） | DX/docs | 2026-07-07 | — | P2 | design |
| CC-461 | 🟢 someday | `doctor.sh --fix`：僅限冪等/可逆/不碰使用者內容類別的自動修復；待 CC-447 offline smoke 產出摔倒點清單後定白名單（2026-07-07 openyida 跨專案分析） | ops/install | 2026-07-07 | — | P3 | — |
| CC-462 | 🟢 someday | e2e 可拋棄資源紀律：前綴命名 + registry JSON + result artifact；掛在 CC-449 e2e 新 phase 之後，與 CC-447 live smoke 共用同一 registry（2026-07-07 openyida 跨專案分析） | ops/test | 2026-07-07 | — | P3 | — |
| CC-463 | 🟢 someday | `pmctl batch` 泛用批次執行原語；依賴 CC-460（合法性驗證來源）；新注入面須過 security-reviewer（2026-07-07 openyida 跨專案分析） | arch/process | 2026-07-07 | — | P3 | design |
| CC-464 | 🟢 someday | `pmctl ticket draft --from <notes>`：隨手筆記→結構化 backlog 票草稿；依賴 CC-286（prefix-generic next-id，⏸ deferred 尚未排程）；review-first 邊界獨立設計，CC-054 僅供鬆散參照非直接前例（2026-07-07 openyida 跨專案分析） | ux/process | 2026-07-07 | — | P3 | — |
| CC-479 | ✅ done | `share/model-aliases.tsv` 改名為 `share/codex-model-aliases.tsv`（與 `claude-model-aliases.tsv`/`opencode-model-aliases.tsv` 命名對齊）；`share/claude-model-aliases.tsv` 補回 `sonnet-4-6`/`sonnet-4-5`/`opus-4-6`/`opus-4-7` 舊世代 alias（可選用，非 default）（2026-07-12 使用者發現） | ops | 2026-07-12 | pr:#393 | P2 | — |
| CC-478 | ✅ done | codex default model alias 過期：`share/model-aliases.tsv` 的 `default` 仍釘舊 `gpt-5.5`，未跟進新的 gpt-5.6 三分支（sol/terra/luna）（2026-07-12 使用者發現） | ops | 2026-07-12 | pr:#392 | P2 | — |
| CC-480 | ✅ done | host-switch memory continuity：嚴格 resolution contract + Codex `pmctl pm prepare` 確定性 hydration + Claude↔Codex 共用同一 canonical memory E2E；v0.9.0 host 軸 continuity 驗收 | arch/memory | 2026-07-12 | — | P1 | design |
| CC-465 | 🔵 active | memory/context 關鍵詞管線 CJK 支援：抽出共用零依賴斷詞 lib，取代三處各自 ASCII-only 抽詞；工作序列起點（465→467→468→466）（2026-07-07 記憶系統深入分析） | memory | 2026-07-07 | feedback:2026-07-07 | P2 | retrieval |
| CC-466 | 🔵 active | 記憶卡片生命週期閉環：expires_at 執行 + 關窗式 supersede + usage sidecar 休眠偵測 + doctor→distill 接線；排在 CC-467 之後（需其遙測為前置）（2026-07-07 記憶系統分析 + 外部研究 Graphiti/mcp-memory-service） | memory | 2026-07-07 | feedback:2026-07-07 | P2 | retrieval |
| CC-467 | 🔵 active | `pmctl memory stats`：注入效益可視化（唯讀聚合器）——注入 bytes/卡片命中分佈/從未命中卡/episode 填寫率，回答「記憶有跟沒有差在哪」；排在 CC-466 之前（2026-07-07；業界僅離線 recall 評測，無 per-injection 遙測） | DX/memory | 2026-07-07 | — | P2 | retrieval |
| CC-468 | 🔵 active | dispatch brief 帶 memory 約束：PM 萃取為非敏感 `constraints:` 清單（pointer 僅作 provenance），依賴 CC-465 CJK 先行（2026-07-07；auto-pack 現為 repo-only by construction） | ops/memory | 2026-07-07 | — | P2 | retrieval |
| CC-469 | ✅ done | codex reviewer sandbox 找不到 pmctl：`codex exec --sandbox workspace-write` 派工 reviewer 時，sandbox 內裸呼叫 `pmctl guard check` 回報 command not found，導致該 reviewer 中止、gate 產不出結果檔案（2026-07-07 平行模式 gate run 實測發現） | ops/gate | 2026-07-09 | pr:#388 | P2 | — |
| CC-011 | 🟢 someday | sync-memory.sh + install 選項：symlink memory 到雲端資料夾實現跨裝置共用 | ux/memory | 2026-05-14 | — | — | — |
| CC-012 | 🟢 someday | SessionStart hook：session 啟動時 pull 最新 memory（git/rsync）確保跨裝置同步 | ux/memory | 2026-05-14 | — | — | — |
| CC-015 | ⏸ deferred | `systematic-debugging` skill：結構化偵錯工作流 | ux | 2026-05-14 | — | — | — |
| CC-018 | 🟢 someday | Codex quota 自動追蹤 + rate-limit 路徑統一（吸收 CC-269）：寫到 `~/.local/share/pm-dispatch/state/rate-limits.json`；解析 API response headers；token-usage.sh 加 Codex pool 顯示 | ux/token | 2026-05-14 | — | P3 | — |
| CC-023 | ⏸ deferred | `coupling-reviewer`：PR gate 加入語言感知耦合分析（dependency-cruiser/gocyclo/coca） | ops/gate | 2026-05-14 | — | — | — |
| CC-026 | 🟢 someday | `/skill-distill`：偵測重複工作流，產出草稿 skill .md | ux/memory | 2026-05-15 | — | P3 | — |
| CC-032 | 🔵 active | `[[feedback_*]]` cross-link 公開化：抽到 `docs/policies/` glossary 避免 dead link（v1.0 P0，v1.0-rc 候選；DECISIONS 2026-07-04） | process/DX | 2026-05-15 | — | P2 | — |
| CC-033 | 🔵 active | public posture reconciliation（原 flip checklist；repo 已 public 故 rescope）：README 文案一致、Issues/Discussions 設定、CITATION.cff（選配）、**即刻** git history 損害盤點（v1.0 P0，盤點即刻＋其餘 v1.0-rc；依賴 CC-032；DECISIONS 2026-07-04） | process | 2026-05-15 | — | P2 | — |
| CC-035 | 🟢 someday | install/uninstall-guards basename+scripts/ heuristic：未覆蓋另一工具也在 scripts/ 下同名 hook 的 collision edge case | ops | 2026-05-15 | pr:#53 | P3 | — |
| CC-038 | ⏸ deferred | Windows/cross-platform 鎖機制：`flock` Linux-only，未來支援需替代方案（parked: CC-370） | ops/portability | 2026-05-15 | — | — | oss |
| CC-044 | ⏸ deferred | `tool-trace.jsonl` 三階段升級（吸收 CC-027b/c）：Phase 1 rotation/retention；Phase 2 bounded error counter；Phase 3 async validation | ux/memory | 2026-05-15 | — | — | — |
| CC-045 | ⏸ deferred | brief timeout heuristic：依 target repo playbook depth 設 timeout（not only edit size）；brief 可加 skip-playbook-reread 短路指令 | process/DX | 2026-05-16 | — | — | — |
| CC-054 | ⏸ deferred | CC-025 M2 — `/skill-refine` diff generation and Claude-assisted refinement；scope deferred when CC-025b was closed in `feat/cc039-cc025b-v2` | ux/memory | 2026-05-18 | pr:#67 | — | — |
| CC-063 | ⏸ deferred | Trace/token/gate metrics dashboard：`.agent-trace/*.jsonl` + `rate-limits*.json` + `.gate-results/*.md` 視覺化 per-session token、gate pass rate、routing_log 趨勢 | ux/ops | 2026-05-18 | — | P3 | — |
| CC-064 | ⏸ deferred | Project bootstrap wizard：互動式 `scripts/setup-project.sh --init` 引導新 repo 建立 memory、rules、PM schema | ux | 2026-05-18 | roadmap:CC-031 | P2 | — |
| CC-065 | ⏸ deferred | Per-repo configurable gate pipeline：不同 repo 可設定不同 reviewer 組合與 tier 預設（例如 `.pm-dispatch/gate.toml`） | ops/gate | 2026-05-18 | — | P3 | — |
| CC-104d | ⏸ deferred | **[Windows]** hook-codex-bash-guard.sh hardcoded `$HOME/github` read-root；應改為派生自 `PM_DISPATCH_REPO` parent（parked: CC-370） | ops | 2026-05-17 | — | — | oss |
| CC-104e | ⏸ deferred | **[Windows]** WSL ↔ Windows memory path divergence：不同 project-id 致 memory partitioned；workaround: symlink 或 PM_DISPATCH_PROJECT_ID override（parked: CC-370） | ux/memory | 2026-05-17 | — | — | oss |
| CC-104f | ⏸ deferred | **[Windows]** jq hard-dep in hooks layer；`--no-hooks` install mode preferred（parked: CC-370） | arch/install | 2026-05-17 | — | — | oss |
| CC-104g | ⚠️ partial 2026-05-17 | **[Windows]** portable.sh test fixes: symlink SKIP ✅；mkdir_lock FIFO sync ✅；但 Git Bash `mkdir` 仍允許第二個 acquire — see CC-104k（parked: CC-370） | ops/test | 2026-05-17 | pr:#80 | — | oss |
| CC-104j | ⏸ deferred | **[Windows]** test-dispatch-handover.sh symlink fixture 在 Git Bash 失敗（`ln -s` → copy fallback → validator treats as regular file）（parked: CC-370） | ops/test | 2026-05-17 | — | — | oss |
| CC-104k | ⏸ deferred | **[Windows]** UNC/9P `mkdir` non-atomic（`\\wsl.localhost\...`，本地 NTFS 正常）；not a code bug；docs/preflight fix in CC-104r（pair with CC-104r；parked: CC-370） | ops/portability | 2026-05-18 | — | — | oss |
| CC-104m | ⏸ deferred | **[Windows]** Platform layout multi-target projection：`~/.pm-dispatch/content/` as canonical view + symlink to `~/.claude/` etc.（parked: CC-370） | arch/install | 2026-05-18 | — | — | oss |
| CC-104r | ⏸ deferred | **[Windows]** hook-tool-trace.sh perf budget fails on WSL UNC path（9P ~8× slower）；docs + preflight UNC detection fix（pair with CC-104k；parked: CC-370） | docs/ops | 2026-05-18 | — | — | oss |
| CC-104s | ⏸ deferred | **[Windows]** hook-tool-trace.sh path normalization fails on Git Bash backslashes；normalize via cygpath before case-match（parked: CC-370） | ops/portability | 2026-05-18 | — | — | oss |
| CC-205 | ⏸ deferred | `/pm` dual-executor planning：`--executor auto/codex/claude` flag + `--parallel-plan` mode（PM 偵測 arch 特徵時暫停確認；parallel dispatch 後主線程合成計劃） | process | 2026-05-20 | — | P2 | design |
| CC-209 | 🟢 someday | codegraph evaluation（Phase 1 AMBER）：pm-dispatch 非有效測試目標；Phase 2 benchmark 需 TS/JS/Python/Go codebase（see CC-253） | ops/token | 2026-05-21 | pr:TBD | P3 | spike |
| CC-211 | ⏸ deferred | v0.3.0 arch epic：schema-first PM runtime（core/runtime/adapters/mcp 四層）；adapters codex+claude 已 ship；state-first/mcp 仍 open | arch/portability | 2026-05-21 | — | P1 | design |
| CC-212 | ⏸ deferred | **[fix: harden Windows junction install — path-passing + idempotency]** 兩個 Windows junction hardening 合併一 PR（吸收 CC-213）：(A) `make_junction_windows()` 改用 `PM_DISPATCH_MAKE_SRC`/`PM_DISPATCH_MAKE_DST` env var 傳路徑，統一 PowerShell boundary 慣例；(B) `install_dir_junction()` 加 manifest-driven idempotency probe，不再依賴 `-L` 偵測。 | ops/portability | 2026-05-21 | pr:#112 | P3 | oss |
| CC-216 | ⏸ deferred | MCP server（DEFERRED no milestone，2026-06-18 user 拍板；待 executor 抽象 + retrieval/memory 基底穩定後再評估） | arch/portability | 2026-05-21 | — | — | design |
| CC-227 | ⏸ deferred | **[refactor: extract yaml-frontmatter lib + shared validation helpers]** 把 `check_frontmatter()` 與 shared helpers（dq-escape/adjacent-quote/empty-entry，原 CC-226 範圍）一起搬到 `scripts/lib/yaml-frontmatter.sh`；`lint-frontmatter.sh` 成薄 CLI 包裝；`doctor.sh` 可 source lib 取代 fork subprocess。CC-226 已合併入本票。 | arch/reuse | 2026-05-22 | pr:#119 | P3 | oss |
| CC-236 | 🟢 someday | **[pmctl report — away-from-keyboard state roll-up]** A `pmctl report` rolling up state since last invocation (open tasks, blockers, last gate verdict, recent runs). Deprioritized 2026-05-22: the maintainer does not run agents unattended, so a "morning report" time-gap framing has low current need; on-demand status is already part of the `pmctl` surface (CC-215). Revisit if the workflow ever includes overnight / away dispatch. | ux | 2026-05-22 | — | — | design |
| CC-244 | 🟢 someday | **[Typed artifact pipeline — spike → brief → handover schema]** Define `spike_v1` schema mirroring existing `dispatch_handover_v1`: frontmatter (`spike_id`, `status`, `decisions_resolved`, `branch_base`, `ticket_ids_consumed`, `project_tooling`) + named sections (`scope`, `findings`, `constraints`, `decisions`, `phase3_handover`). Add `scripts/spike-validate.sh` (mirror `handover-validate.sh`) + `scripts/gen-brief-from-spike.sh` (mechanical brief extraction). Reduces main-thread courier cost, makes spike→brief authoring mechanical, gives invariant checkpoints (`decisions_resolved=true` ⇒ no re-asking Q1/Q2). Defer until 3+ spike docs exist and the brief-extraction pattern repeats; only one spike (CC-060) today, so schema would be premature overhead. CC-243 field names chosen to align with this future schema (no re-wash needed at upgrade time). | arch | 2026-05-23 | — | — | design |
| CC-253 | 🟢 someday | **[CC-209 Phase 2: codegraph benchmark on representative target codebase]** Phase 1 (PR #151) verdict AMBER — codegraph install ✓ license MIT ✓ API ✓, but pm-dispatch (bash/markdown) isn't a valid test target (`62 unsupported language`). Phase 2 re-scope: user picks a TS/JS/Python/Go target codebase at brief time, index it via codegraph, run 3 representative queries against rg/git baseline, measure token + latency delta. Output: append `## Phase 2` section to `docs/spikes/cc209-codegraph-phase1.md` OR new sibling doc. Verdict per original CC-209 ticket: adopt / defer / reject for context-pack source (CC-232 / CC-237). | ops/token | 2026-05-24 | pr:TBD | P3 | spike |
| CC-259 | 🟢 someday | **[yaml.sh lib extraction]** Extract `_yaml_get` bash/awk helper and `case_yaml_parse` structural validator from `scripts/test-core-schemas.sh` into `scripts/lib/yaml.sh` for reuse across test scripts; add independent test file `scripts/test-yaml-lib.sh` and wire into `run-all-tests.sh` + CI. Currently only used in `test-core-schemas.sh`; extraction deferred from CC-229 M1 PR to reduce gate surface. Trigger: second consumer in a new test script. | ops/test | 2026-05-25 | pr:TBD | P3 | — |
| CC-270 | ⏸ deferred | **[test: concurrent pmctl adapter generate guard]** Two simultaneous `pmctl adapter generate <same-name>` runs can race: the precheck+mkdir+trap sequence is not atomic. Blast radius: one run may delete another's partial output; reproducible by deleting `adapters/<name>` and rerunning. Deferred — single-developer workflow makes this low-probability; fix with atomic mkdir using `mkdir` exit-code guard when needed. | test/ops | 2026-05-28 | — | P3 | — |
| CC-273 | ⏸ deferred | arch: unified lifecycle hook event spec（`.pm-dispatch/hooks/<event>.sh`）；activate when second hook point beyond gate pre/post emerges | arch/gate | 2026-05-28 | — | P3 | — |
| CC-286 | ⏸ deferred | **[pmctl: prefix-generic next-id derivation]** `scripts/pm-prep-snapshot.sh` derives `backlog_next_id` CC-only (it emits `CC-NNN`); under the working-set contract it scans BACKLOG.md + BACKLOG-ARCHIVE.md for the max, but only `CC-` IDs. A cross-repo next-id (other prefixes: JS-, PA-) must be prefix-derived and centralized in pmctl, scanning both working-set and archive. Retire pm-prep-snapshot's CC-hardcoded derivation when `pmctl backlog`/next-id lands. Surfaced by pr-gate critic+architecture on #186. | arch | 2026-05-30 | — | P3 | design |
| CC-306 | ⏸ deferred | **[arch: extend CC-233 layer enforcer to runtime-named data paths in scripts/]** Guard against re-introducing `.codex-*`/`.claude-*` DATA directories under scripts/ (the optional follow-up deferred from CC-298). | arch | 2026-06-01 | — | P3 | design |
| CC-333 | 🔵 active | arch: pm-dispatch runtime 解耦合（v0.6.0 umbrella）；layer 2/3/5/6 已交付（v0.6.0）；layer 1（CC-412）已交付、layer 4 spike（CC-381）已收斂為 CC-436/437/438；layer 7 待評估；open sub-tickets: CC-390/393/412/436/437/438 | arch | 2026-06-07 | — | P2 | design |
| CC-340 | ⏸ deferred | knowledge index: embeddings/semantic-backend remainder（FTS/LIKE MVP 已由 CC-403 接管；本票保留 Khoj-class semantic accelerator，待 FTS ranking 不足時 resume） | memory | 2026-06-08 | — | P3 | retrieval |
| CC-342 | 🟢 someday | agent: debt-auditor — proactive tech-debt health scan（`agents/debt-auditor.md`；`pmctl audit <path>` 呼叫；PR-free 主動健康掃描，有別於現有 PR-focused reviewers） | process/DX | 2026-06-05 | — | P3 | design |
| CC-346 | ⏸ deferred | repo-index: cross-file ref tracking `file_refs` table（paused 2026-06-10；resume trigger: reuse-scan 進過 ≥2 份真 brief 且缺 ref 資料為瓶頸；屆時先 Phase a bash source） | ops | 2026-06-09 | — | P3 | design |
| CC-347 | 🟢 someday | pr-gate blast-radius analysis using CC-346 file_refs（blast_radius 清單注入 brief context；無 CC-346 index 時靜默跳過） | gate | 2026-06-09 | — | P3 | design |
| CC-348 | 🟢 someday | **[pmctl project-map: cross-file dependency graph visualisation]** `pmctl project-map [--format text/dot] [--from <path>] [--depth N]` — 以 CC-346 file_refs 表輸出 ASCII 樹狀（預設）或 Graphviz DOT 引用圖；標示 broken refs（to_path 不在 files 表）；無 index 時 exit 1 並提示 `pmctl context index`。 | ops/DX | 2026-06-09 | — | P3 | design |
| CC-352 | ⏸ deferred | **[codex-executor sandbox friction Pattern 1+2: apply_patch retry noise + Go module cache blocked]** issue:#173 Pattern 3（git commit blocked）已由 CC-272 pr:#245 吸收修復。剩餘：(1) apply_patch 中途失敗 self-retry 噪音 — brief 改拆小 hunk 加 unique context；(2) go build 時 GOPATH copy 被 sandbox 擋 — 文件化 GOPATH=/tmp/gopath 慣例。兩者均為 doc/convention fix。 | ops/DX | 2026-06-10 | — | P3 | — |
| CC-355 | 🟢 someday | knowledge index: HTML semantic chunking `<h1-6>`（trigger: .html file enters knowledge plane；plug into CC-354 per-format chunker seam） | memory | 2026-06-10 | — | P3 | design |
| CC-357 | 🟢 someday | **[skill as contract: machine-readable schema for skills]** 現有 skills/ 都是純 markdown prose（SKILL.md），沒有機器可讀的 input schema、output contract、tool_constraints、completion_condition。這使得 skill 無法被驗證、無法被工具自動發現、也無法像 dispatch_handover_v1 那樣由 validator 強制執行契約。本票引入 skill schema（YAML frontmatter 或 JSON sidecar），使 skill 具備：明確的輸入型別、輸出格式、允許/禁止工具清單、完成條件——平行於 brief-validate.sh 對 brief 的驗證角色。 | arch/DX | 2026-06-10 | — | — | design |
| CC-358 | 🔵 active | runner telemetry：`pmctl run-stats` per-adapter 成功率/失敗模式/fallback 分析（v1.0 P1 證據層，v0.9.0 候選；DECISIONS 2026-07-04） | ops/memory | 2026-06-10 | — | P2 | design |
| CC-359 | 🟢 someday | concept: backlog-driven batch dispatch with worktree isolation（PM manages `git worktree` lifecycle；executor-agnostic；human-in-the-loop merge；PR-only output） | arch/ops | 2026-06-11 | — | — | design |
| CC-364 | ⏸ deferred | **[perf: `pmctl trace tail --all` per-event jq spawn]** `pmctl trace tail --kind <k> --all --json` is O(n) with a high per-event constant — ~20s for 338 events (~60ms/event), consistent with spawning a jq/subprocess per event rather than one streaming pass. Surfaced while diagnosing #270 context-telemetry test flakiness; the tests no longer depend on it (telemetry now honors `PM_DISPATCH_STATE_ROOT`, so the suite isolates state). Standalone reader-perf follow-up. **See**: pr:#270 | ops | 2026-06-12 | pr:#270 | P3 | hygiene |
| CC-369 | ⏸ deferred | Windows state store 真實 ACL via icacls（parked: CC-370；border case relative to profile ACL protection） | ops/portability | 2026-06-13 | — | — | hygiene |
| CC-370 | ⏸ deferred | **[native Windows support deferred to post-core platform phase]** 核心功能開發期間正式只支援 Linux + WSL2（WSL2 視為 Linux）；原生 Windows Git Bash 非官方支援，使用者走 WSL2。理由是專注：開發期同時扛多平台會排擠核心功能（CI 只測 Linux，每次碰 Windows 都要人工驗證 + gate churn，見 #272/#273）。已合併的 portability 程式碼保留（綠且成本低），但不再新增 Windows 分支，直到核心定型（v0.5.0+）後的專屬平台階段。Parks: CC-038, CC-104d/e/f/g/j/k/r/s, CC-369。**See**: DECISIONS.md 2026-06-13 defer-native-windows-support-during-core-dev | ops/portability | 2026-06-13 | — | — | design |
| CC-377 | ⏸ deferred | adapter: Google Antigravity（`agy`）executor（DEFERRED：headless CLI 1.0.8 不成熟；resume: newer agy with `--output-format stream-json`；umbrella: CC-333） | arch/portability | 2026-06-13 | — | P2 | design |
| CC-390 | ⏸ deferred | codex dispatch trace-capture 強化（FD inheritance cold-start flake；fail-closed safe；resume: stable repro；umbrella: CC-333） | arch/portability | 2026-06-15 | — | P3 | design |
| CC-393 | 🟢 someday | design: portable-skill-substrate — CLI-agnostic skill 控制層（design seed after v0.6.0 N≥2；3 control skills + Portable Skill v0 frontmatter；umbrella: CC-333） | arch | 2026-06-16 | — | — | design |
| CC-431 | 🔵 active | **[test-e2e.sh + release-verify.sh: opencode adapter support]** `--adapter` 目前只接受 `claude\|codex\|auto`；opencode 在 v0.6.0 加入後未同步更新 e2e 驗證路徑。需：(1) 將 opencode 加入兩腳本的 adapter 驗證清單；(2) Phase B dispatch 支援 opencode；(3) Phase C pr-gate smoke 評估是否可用 opencode executor（目前硬碼 codex）。觸發：release-verify --e2e --adapter opencode 被拒（exit 2）。v1.0 executor stable 宣稱的證據前置（v0.9.0 候選；DECISIONS 2026-07-04） | ops/test | 2026-06-30 | — | P2 | — |
| CC-435 | 🟢 someday | **[poll→通知機制 single-waiter guard：條件觸發，非既定後續票]** 只有在真正出現多個 waiter 需要同時等待同一個 run_id/gate_id 的場景時才拿出來討論；候選設計見 `docs/spikes/CC-433.md` Open risks（方案 A：`flock` 搶鎖+敗者退回輪詢；方案 B：per-waiter 專屬 fifo+supervisor 廣播）。CC-434 完成後重新盤點成本效益：輪詢 vs blocking read 在單一 waiter/數分鐘等待場景下資源消耗差距趨近於零，延遲改善（≤2s→近乎即時）對人在等 gate 結果無感，而兩個方案都要在安全敏感的 supervisor 檔案引入新 race condition，投資報酬率目前不足，故不排入既定實作，僅記錄設計供未來觸發條件成立時起步。 | arch/gate | 2026-07-02 | — | P3 | design |
| CC-445 | 🔵 active | install write path host-aware：依 host manifest（CC-438）衍生 install/uninstall/doctor 對 codex-host 的接線；CC-381 完整實作第一刀（v0.9.0 候選；依賴 CC-436/438；umbrella: CC-333） | arch/install | 2026-07-04 | pr:#395 | P2 | design |
| CC-446 | 🔵 active | v1.0 契約凍結：`docs/stability-contract.md` 四層分級（stable/experimental CLI + stable/internal schema）+ SemVer/deprecation 政策 + 執行 CC-296 清掃（v1.0 P0，v0.9.0 候選；DECISIONS 2026-07-04） | process/DX | 2026-07-04 | — | P2 | design |
| CC-447 | 🔵 active | 乾淨機器 onboarding 雙 smoke：offline clean-install smoke（v0.9.0 候選）+ live dogfood smoke（v1.0-rc）；摔倒點逐一開票；QA_RULES_DIR 缺席行為驗證 | docs/ops | 2026-07-04 | — | P2 | — |
| CC-448 | 🔵 active | opencode host support：階段 1 probe 完成、CC-476 spike 解除掛起 blocking risk → 階段 2 `hosts/opencode/host.yaml` → 階段 3 install/doctor 接線；host 抽象 N=2 驗收（v0.9.0；依賴 CC-438已done/CC-445；umbrella: CC-333；DECISIONS 2026-07-04+2026-07-06） | arch/install | 2026-07-04 | pr:#395 | P2 | design |
| CC-449 | 🔵 active | release-verify/test-e2e 對 v0.8.0 新 surface（`pmctl ship`/`pmctl worktree`）無 live 煙測 + run-all-tests 套件註冊完整性 lint（CC-444 收尾發現 test-pmctl-worktree 未註冊，已修；防再漏）+ CI↔run-all parity 斷言（2026-07-06 稽核：24 個本地 suite CI 缺席）（v0.9.0 候選） | ops/test | 2026-07-04 | — | P2 | — |
| CC-472 | 🟢 someday | spike: antigravity（`agy` CLI）host 唯讀 probe——比照 CC-436/CC-448 階段 1 模式，實測 command 載入能力 + hook/plugin 機制 + 五個 capability enum 的 provider/confidence 判定，不落地 `hosts/antigravity/host.yaml`；排在 CC-445 通用 install/uninstall dispatcher 之後、與 CC-448 opencode 同批或緊接其後評估（N=3 驗證點） | arch/install | 2026-07-08 | — | P3 | spike |
| CC-473 | ✅ done | `pmctl pm`：batch-only `prepare/run` CLI surface，共用 snapshot、handover validation、detached dispatch/authenticated wait；Codex host manifest/doctor 宣告 partial `cli_wrapper`，Claude gate GO 且真實 Codex live smoke 通過 | arch/install | 2026-07-10 | pr:#391 | P2 | design |
| CC-474 | ✅ done | dispatch/gate reasoning effort 獨立可調：目前 effort 綁死在 model alias 第三欄（share/*-model-aliases.tsv，多數 alias 寫死 high），無法在不換 model 的前提下單獨調降/調升；新增 `--effort` 旗標覆蓋、預設改 medium（CC-445 pr-gate 多輪迭代觀察，2026-07-08） | ops/gate | 2026-07-08 | pr:#387 | P3 | — |
| CC-477 | 🔵 active | guard memory usage sidecar 並發遺失更新：建立可診斷 repro，修正 lock protocol，消除 full-suite flake | ops/test | 2026-07-10 | feedback:2026-07-10 | P2 | hygiene |

---

## Convention

**ID scheme**: `CC-NNN` sequential. ID gaps are normal — use the `epic` column (see `pm/schema.md §2.4.5`) for semantic grouping instead of ID ranges. The `CC-1NN`/`CC-2NN` range-reservation convention is deprecated (see `DECISIONS.md#2026-05-19-deprecate-id-gap-convention`).

**Sub-letter IDs**: `CC-NNNa`, `CC-NNNb`, `CC-NNNc` are follow-up tickets to a parent `CC-NNN`, with independent lifecycles.

**Status legend** — _non-terminal_ (stay on the board):
- `🔵 active` — in backlog (not-started / in-progress / blocked)
- `⏸ deferred` — waiting on external condition or trigger, not scheduled
- `🟢 someday` — valid idea, no expected schedule
- `⚠️ partial YYYY-MM-DD` — partially shipped; sub-items remain open (see body)

_Terminal_ (CC-378: swept OUT to `BACKLOG-ARCHIVE.md` by `scripts/archive-closed-backlog.sh` — index row + body both leave BACKLOG.md, no stub):
- `✅ done [YYYY-MM-DD]` — completed; date optional. **Terminal + archived** (the old soft-close-stays-active rule was retired — see DECISIONS 2026-06-14).
- `✅ closed YYYY-MM-DD` — shipped, PR-backed dated variant of `done`; terminal.
- `🟢 superseded YYYY-MM-DD` — superseded by a later item; archived body keeps a `Superseded by [[CC-NNN]]` pointer. (Same 🟢 glyph as `someday` but opposite liveness — terminal rows leave the board on the next archive run, so a 🟢 left on the board should only be `someday`.)
- `🚫 dropped YYYY-MM-DD` — will not do; archived body keeps `See: DECISIONS.md` if decided.

**Archival**: terminal tickets are swept entirely to `BACKLOG-ARCHIVE.md` (no `**See**:` stub remains in BACKLOG.md). Query closed items via the archive's body headings.

**Priority column**: `P1`（本週必做）/ `P2`（本 sprint）/ `P3`（排隊）/ `—`（未設）。
**Epic column**: `oss`（CC-OSS 公開源碼系列）/ `reuse-debt`（技術債重用）/ `hygiene`（流程維護）/ `design`（新功能架構設計與 interface 決策）/ `spike`（調查類任務）/ `—`（其他）。
向下相容：v1.1/v1.2 file 中缺此兩欄的列只 emit 警告（不阻斷 gate）。

<!-- archived stubs — full text in BACKLOG-ARCHIVE.md -->

## CC-445 — install write path host-aware（CC-381 完整實作第一刀）🔵 active

**Problem**：[[CC-381]] spike 收斂出三張唯讀票（[[CC-436]] payload probe、[[CC-437]] doctor host-aware、[[CC-438]] host manifest schema），並明文把 installer write path 留給「三票驗證完成後的下一版」。在 write path 落地前，「pm-dispatch 支援 codex host」只是文件宣稱——install/uninstall 無法把 guard binding、hook 接線真正接到 codex host 上。

**Why**：v1.0 public 正式版的 host-agnostic 宣稱需要至少一個非 claude host 的完整 install 鏈（DECISIONS 2026-07-04：v0.9.0 = host 軸完成 + 證據層）。

**Requirement**（粗刻，待 [[CC-436]]/[[CC-438]] 結果收斂後以 `/pre-impl` 定案）：
1. install/uninstall/doctor 的 codex-host 接線由 host manifest（[[CC-438]] `hosts/codex/host.yaml`）能力旗標衍生——鏡像 adapter manifest 模式（[[CC-375]] 先例：manifest 宣告一次，三方一致性回歸鎖住）。
2. write/bash guard 綁進 codex `PreToolUse` hook（[[CC-381]] spike 已實測可行、fail-closed；欄位表達力以 [[CC-436]] probe 結果為準）。
3. uninstall 對稱清除 + doctor parity check（呼應 CC-224/CC-375 的三方一致性教訓）。
4. **claude-host 殘餘耦合一併盤點**（2026-07-06 盲測稽核）：`adapters/*/dispatch.sh` 硬編 `${HOME}/.claude/scripts/log-usage.sh` 做 usage 記帳——host-generic write path 落地時改由 host manifest／既有 `PM_CFG_*` env 慣例衍生，或明文宣告該能力 claude-host-only，消除 host-independent 宣稱與實作的落差。
5. **manifest declared-vs-probed parity check**（[[CC-438]] PR #375 gate advisory；qa-tester + architecture-reviewer 共同點名）：consumer 落地時加上 manifest 宣告 capability 對 probe 紀錄的機械比對，宣告不得默默超出 probed 佐證。

**Done-when**：(a) claude host 路徑 **byte-compatible**（既有 install 輸出零變更，回歸鎖住）；(b) codex host 路徑至少通過 dry-run + sandbox `CODEX_HOME` 實裝驗證：install → doctor 全綠 → guard 實際攔截一次違規寫入 → uninstall 無殘留；(c) install/uninstall/doctor 三方 parity test 覆蓋 host 維度。

**Dependencies**：依賴 [[CC-436]]（payload 表達力）、[[CC-438]]（schema）；與 [[CC-437]] 的 doctor host module 介面對齊。write path 必須 host-generic（由 `hosts/*/host.yaml` 驅動，非 codex 特例）——[[CC-448]] opencode host 是本票抽象的 N=2 驗收。umbrella [[CC-333]]。v0.9.0 候選。
**See**: `docs/spikes/CC-381.md`、DECISIONS.md 2026-07-04

**Update 2026-07-08（rescope：codex-only 切片，host-generic dispatcher 延後）**：pr-gate 第 17 輪（critic/qa-tester/architecture-reviewer 三方）指出目前實作仍是 codex 特例——`install.sh`/`uninstall.sh` 直接呼叫 `scripts/{install,uninstall}-guards-codex.sh`，尚未有 manifest 驅動的通用 install/uninstall dispatcher；而本票 Dependencies 明訂的 N=2 驗收依賴 [[CC-448]]（opencode host），該票尚未完成，此刻本質上無法真正驗證「非 codex 特例」的抽象是否正確。使用者拍板：本 PR 明確定位為 **CC-445 第一刀（codex 實裝切片）**，不宣稱達成 host-generic 驗收；本票維持 active，通用 install/uninstall dispatcher（連同 [[CC-448]] N=2 驗證）留待 opencode host 落地後同批處理。`scripts/lib/host-manifest.sh` 檔頭註解已誠實記載這個過渡狀態（manifest 消除的是「facts 寫死在 per-host 腳本裡」，不是「per-host 腳本本身要不要存在」），本次僅需在此追加決策記錄，不需要再改程式碼。critic/architecture-reviewer 的 block-soft 已由使用者明確接受 override；qa-tester 的兩個缺測試 finding（`host_manifest_names`/`host_manifest_scalar` 無直接測試）已修（`scripts/test-host-write-codex.sh` 補 7 個案例）。

**Update 2026-07-08（antigravity/agy host 候選，唯讀 probe 併入本票後續範圍）**：使用者正在跟 agy（antigravity CLI）討論把它接成 pm-dispatch 的一個 host，過程中釐清一個先前被混淆的區分——**Executor**（背景自動派工、靠 post-verify 機械判定）需要結構化的 JSONL/JQ 可審計輸出；**Host**（人類互動起點，PM 在該 CLI 內被驅動）門檻低很多，只要能載入專案 slash command（如 `/pm`）、能在內部 agent 呼叫 Bash/檔案寫入時觸發 `pmctl guard check` 就夠格。`docs/host-contract.md` 的 `guard_bindings` schema 其實已內建這個分級：`pm_command_interface` 是強制宣告的能力（這才是「算不算 host」的門檻），`command_guard`/`file_guard` 允許合法宣告 `provider: none`（`confidence: probed`/`observed` 代表「已實測、這個 host 結構上就是做不到攔截」，是誠實終態宣告，不是缺陷）。agy 目前完全沒被評估過屬於哪一類、guard 綁定是否可行；比照 [[CC-436]]/[[CC-448]] 階段 1 的唯讀 probe 模式（不落地 `hosts/antigravity/host.yaml`，只實測 command 載入能力 + hook/plugin 機制 + 五個 capability enum 的 provider/confidence 判定，結論寫 `docs/spikes/CC-472.md`），排在本票的通用 install/uninstall dispatcher 工作**之後**、與 [[CC-448]] opencode 同批或緊接其後評估——antigravity 若真的接成 host，會是這個抽象的第三個驗證點（N=3），使用者原話：「他只要是能呼叫pmctl 以及幫我排序內容 其實就可以算是host，只是有些host 沒有辦法限制 有些可以」。

**Update 2026-07-09（pr-gate 第 18 輪，security/risk block 修復 + architecture block-soft 例外落地記錄）**：security-reviewer 與 risk-reviewer 都抓到同一個真實 bug——`scripts/guard-pm-bash.sh` 的 destructive-command denylist 用 whitespace-dependent 正則比對 raw command 字串，會被 shell expansion 形式繞過（`rm${IFS}-rf${IFS}/tmp/x` 這類命令在 guard 比對時字面上沒有空白，但 Bash 執行時把 `${IFS}` 展開成分隔符，等同 `rm -rf /tmp/x`）；已修：新增 `_normalize_for_denylist`（`scripts/guard-pm-bash.sh`），比對前先把 `$IFS`/`${IFS}`/ANSI-C 空白轉義（`$'\x20'` 等）摺疊成字面空白，僅影響 denylist 判斷，不影響 audit/deny 訊息使用的原始字串；`scripts/test-guards.sh` 補 5 個回歸案例（IFS 花括號展開、bare `$IFS`、ANSI-C quoting、git push 變體、以及一個確認正常引用 `$IFS` 的指令不被誤擋的 allow case）。明確接受的殘留缺口（比照既有 case-sensitivity 缺口的記錄風格）：brace expansion（`{rm,-rf,/tmp/x}`）、變數間接展開、`eval`/command substitution 組出的指令仍可繞過——單一字串 denylist 本質上無法取代真正的 shell parser。architecture-reviewer 的 block-soft（`install.sh`/`uninstall.sh` codex 特例分支）是 R17 已由使用者拍板 override 的同一個 finding 重複出現；本輪把該例外正式寫入 `docs/host-contract.md`「No host-specific branches in core」設計規則下，作為可查詢的 recorded exception，而非僅存在對話記錄裡，降低往後每輪重複觸發同一個已決策問題的成本。`bash scripts/test-guards.sh` 283 綠（原 278 + 新增 5）。

**Update 2026-07-09（pr-gate 第 19 輪，quote/backslash 繞過 + uninstall malformed-JSON 中止修復）**：改用 `pmctl gate run --test-cmd` 讓 pre-flight 自動跑 `run-all-tests.sh`（test_suite: pass），這輪三個新 finding：(1) security-reviewer 找到同一 denylist 的第二種繞過——`r'm' -rf /tmp/x`（quote-split token 重組）與 `r\m -rf /tmp/x`（單字元 backslash escape）在比對時字面上不含 `rm` 子字串，但 Bash 執行時引號/跳脫字元被移除後就是 `rm -rf /tmp/x`；`_normalize_for_denylist` 加一段 quote-strip（移除 `'`/`"`）+ backslash-collapse（`\X`→`X`），僅影響方向是讓比對「更容易命中」而非更寬鬆，`scripts/test-guards.sh` 補 4 案例（quote-split rm、backslash-escape rm、quote-split git push flag、一個確認 `git commit -m "hello world"` 這種正常帶空白引號參數不被誤擋的 allow case）。(2)(3) critic/qa-tester/architecture-reviewer/risk-reviewer 都指出 `uninstall.sh` 現在無條件呼叫 `scripts/uninstall-guards-codex.sh`，若使用者的 `$CODEX_HOME/hooks.json` 本來就損毀（跟本 checkout 是否曾裝過 codex guard 無關），`jq` 在 `set -e` 下會直接中止整個 uninstall；已修：呼叫既有 jq 轉換前先 `jq empty` 驗證，非合法 JSON 就印警告後 `exit 0` 跳過（不修改該檔案），`scripts/test-host-write-codex.sh` 補 `uninstall-guards-codex-malformed-hooks-json-skips-not-errors` 案例（31 綠，原 30）。`bash scripts/test-guards.sh` 287 綠（原 283 + 新增 4）。

**Update 2026-07-09（pr-gate 第 21 輪：GO）**：第 20 輪 pre-flight fail-fast 擋在 `test-pmctl-task` 一個並發競態測試（timing-sensitive，單獨重跑與全套件重跑皆綠，確認與本次改動無關）；重送第 21 輪，critic/qa-tester/architecture-reviewer/security-reviewer/risk-reviewer 五方全數 approve/pass，無 finding。R18-R19 的三個真實修復（IFS/ANSI-C 繞過、quote-split/backslash 繞過、uninstall malformed-JSON 中止）與 architecture 例外記錄均獲確認。本票 codex 實裝切片（第一刀）至此收斂為 GO，待使用者確認後 push + 開 PR。

**Update 2026-07-12（host-generic remainder started）**：milestone 明確拆開「Codex baseline 已可用」與「host abstraction 尚未收尾」。`hosts/*/host.yaml` 新增 `install_module` wiring metadata；Codex manifest 補齊現有 install/uninstall module，`install.sh`/`uninstall.sh` 的 Codex-named call site 改為共用 host dispatcher，舊 `--enable-codex-command-guard` 保留為 generic selector 的相容 alias。此切片消除核心對 Codex module path 的直接點名；N=2 與 OpenCode 實際 config write/E2E 仍由 [[CC-448]] 階段 3 驗收，本票維持 active。

**Update 2026-07-12（Claude parity 補驗）**：維護者指出共用 dispatcher 相容性不能只驗 Codex。新增跨 host parity suite，以純 Claude baseline 對照同時啟用 Codex+OpenCode 的 sandbox install；排除 install receipt/backup 後，Claude managed surface fingerprint byte-compatible，兩路 uninstall 後 surface 亦一致。至此 dispatcher slice 同時有 Codex 回歸、OpenCode stage-3 ownership 回歸與 Claude byte-compatible 證據；本票剩餘為 usage-log 的 claude-host 硬編耦合盤點，以及 CC-448 正式 live E2E。

**Update 2026-07-12（Claude host live acceptance GO）**：維護者在 Claude GUI 以共同 `host_acceptance_v1` request 實測通過：`/pm` loaded、working dir 正確、CC-445/448 focus snapshot created、canonical memory readable（legacy resolver、同 project key `4633b7e7f780014195b603f84ce281c3a1afd97b`、context hydrated）、無非預期 permission prompt/timeout、無 tracked write 或 executor/reviewer dispatch。Claude host side 可視為 live GO；N=2 終判只待正式 wiring 後的 OpenCode GUI 回報。

**Update 2026-07-12（usage-log Claude 路徑耦合解除）**：`adapters/{claude,codex}/dispatch.sh` 不再預設執行 `${HOME}/.claude/scripts/log-usage.sh`；兩個 adapter 在 self-snapshot 時一併複製 repo-owned `scripts/log-usage.sh`，執行期預設使用 snapshot-local logger，`PM_CFG_USAGE_LOG_PATH` 仍保留最高優先覆寫。回歸測試以不存在 `~/.claude/scripts/` 的乾淨 HOME 分別證實 Claude/Codex executor 均可記帳，並覆蓋 override 與 logger failure 不改寫 dispatch exit code。這消除的是 executable path 的 host 耦合；tracker data path migration 屬 [[CC-452]]，不混入本票。結合 Claude/OpenCode GUI live GO 與三 host install parity，CC-445/448 本批已無功能 blocker，剩 implementation gate/PR 收尾。

**Update 2026-07-12（implementation gate R1 NO-GO，全 findings 處理）**：full-tier gate `gate-20260712-084801-67c115` pre-flight 全綠但 reviewer verdict NO-GO。依維護者規則「任一 block 即處理該輪所有 findings」，未只修 security/QA blocker：(1) OpenCode TypeScript tool 的 checkout-derived `PMCTL` 改由 `jq` 序列化為 JSON/TypeScript string literal，封住 quote/newline source injection，新增 hostile checkout path regression；(2) 所有 `--enable-host` module 在任何 Claude/base write 前先跑 read-only host preflight，OpenCode 既有 Bash policy 等 conflict 現在整批 fail-before-mutation，新增 generic conflict/base-surface-zero-write regression，同時關閉 critic、QA、risk 三方重疊 finding；(3) architecture low finding 的 `CLAUDE_HOME`/`CLAUDE_CONFIG_DIR` 分裂一併收斂：`CLAUDE_CONFIG_DIR` 成為 manifest/install/uninstall/doctor/guards canonical root，`CLAUDE_HOME` 僅保留相容 alias，兩者顯式不同時 install/uninstall/doctor fail-loud，並補 canonical override、conflict zero-write 與 doctor regression。定向 suites 綠，待完整 pre-flight + 全 reviewer re-gate。

**Update 2026-07-12（implementation gate R2 GO）**：`gate-20260712-091848-e1da26` full-tier sequential、test suite pass；critic approve、qa-tester pass、architecture approve、security pass、risk pass，無 escalation，`Final: GO`。R1 的 security injection、partial multi-host install、generic failure coverage、Claude config-root split 均由 reviewer 逐項確認關閉。QA 唯一 non-blocking low（新 OpenCode test functions 的 `Behavior:`/`Steps:` docstring 一致性）已依維護者指示於 gate 後補齊；此變更僅為 comment，定向 docstring lint 與 OpenCode 13-case suite 綠，不重跑 PR gate。Draft PR #395 已開；CC-445/448 維持 active 等待 review/merge，合併後才轉 terminal done/archive。

## CC-446 — v1.0 契約凍結：stable/experimental 分級 + SemVer/deprecation 政策 🔵 active

**Problem**：目前沒有任何文件回答「pmctl 哪些子指令是 stable、哪些是 experimental」；machine 契約（dispatch brief schema、`adapter.yaml`、`host.yaml`（[[CC-438]] 後）、run-spec、`ship-lanes.jsonl`、`.dispatch-results/`、gate result 格式）沒有版本化與相容承諾；[[CC-296]] deprecation sunset（`--profile` alias、`codex-dispatch.sh` shim）從 v0.5.0 排程至今漂了兩版未執行；`docs/pr-gate-handover-schema.md` 標 deprecated 卻仍列在 README 目錄。ship/worktree 系列（[[CC-443]]）剛落地，schema 仍在熱變動期。

**Why**：v1.0 的第一個承諾是「契約不再隨意破壞」（DECISIONS 2026-07-04）；公開後外部 fork 使用者會依賴這些表面，沒有分級與 deprecation 政策，任何重構都變成潛在 breaking change。

**Requirement**：
1. `docs/stability-contract.md`：四層分級表——
   - **Stable CLI**（v1.0 起受 SemVer 約束）：候選 `pmctl dispatch run/wait`、`pmctl gate run/wait/verify`、`pmctl validate brief`、`pmctl guard check`、`pmctl context index/update/query/pack/reuse-scan`（定案於本票實作時全面盤點）。
   - **Experimental CLI**：新近落地的 `pmctl ship` 全家與 worktree/lane 子指令——至少經過一個 rc 週期無 schema 變動才可升 stable。
   - **Stable schema**：dispatch brief schema、`adapter.yaml` 基本欄位、gate result verdict shape、`host.yaml`（[[CC-438]] 落地後納入）。
   - **Internal schema**（明確宣告外部工具不得依賴）：`ship-lanes.jsonl`、run-spec 內部欄位、sentinel/key-file layout、`.dispatch-results/` 內部格式。
2. SemVer 承諾範圍（什麼算 breaking）+ deprecation 流程（宣告 → 保留期 ≥1 minor → 移除）。
3. 執行 [[CC-296]] deprecation 清掃（已過 v0.3.0 起多個正式版本）。
4. deprecated surface 全清點：README 仍列已標 deprecated 的 `pr-gate-handover-schema.md`（executor-contract 已明言該 fan-out 路徑 retired）——去留與 README 目錄同步，消除自相矛盾。
5. **契約可驗證性盤點**（2026-07-06 盲測稽核擴充）：(a) stable CLI 分級準則納入 `--json` 支援一致性——現僅約半數子指令支援（task/dispatch/ship/memory/worktree/trace/decision 有；backlog/guard/artifacts/gate/context/validate/pre-release 無），列 stable 的讀取型子指令應有結構化輸出或明文排除；(b) 「schema 承諾與行為不符」項逐一定案去留，如 `core/state/layout.yaml` 的 `threshold_days`（宣告但未實作，rotation 只看 bytes）。與 [[CC-451]] 同批評估——runtime 從不驗證的 schema 不應列 stable。

**Done-when**：分級表覆蓋全部 pmctl 子指令與 schema 檔；CC-296 清掃完成；repo 內無「標 deprecated 但無移除計畫」的懸空表面；README 與分級文件互相一致。

**Dependencies**：吸收 [[CC-296]] 執行。[[CC-451]]（core schema runtime 接線）為 stable schema 分級的事實前置，宜先行或同批。Cross-link [[CC-286]]（prefix-generic next-id，影響 cross-repo ID contract，可同批評估）、[[CC-357]]（skill schema——**明確排除**，除非 v1.0 要宣稱 skill 為 machine-readable public API）。v0.9.0 候選（v1.0 P0）。
**See**: DECISIONS.md 2026-07-04

## CC-447 — 乾淨機器 onboarding 雙 smoke（offline + live dogfood）🔵 active

**Problem**：GETTING_STARTED 與 install 鏈從未被第二使用者或乾淨環境驗證過——所有安裝驗證都發生在維護者已高度客製的機器上。repo 已 public，外部使用者的 install 體驗就是專案的第一印象，摔倒點目前不可見。

**Why**：v1.0 的第二個承諾是「別人裝得起來、用得下去」（DECISIONS 2026-07-04）；這比做 bootstrap wizard（[[CC-064]]）便宜且先驗證需求。

**Requirement**（拆兩個 smoke，時點不同）：
1. **Offline clean-install smoke**（v0.9.0）：fresh Linux + WSL2 各一輪，不需任何 CLI auth——`install.sh --dry-run` → `CLAUDE_HOME=/tmp/... install.sh` → `doctor.sh` → `uninstall.sh` 無殘留。驗 install 鏈本體與文件一致性。
2. **Live dogfood smoke**（v1.0-rc）：真實 Claude/Codex auth 環境，走完整 onboarding：install → doctor → 首次 `/pm` → 首次 `pmctl dispatch run` → 首次 `pmctl ship`（一次 gate 到 PR）。
3. 每個摔倒點（缺依賴、文件與行為不符、錯誤訊息不可行動）逐一開票，不在本票內修。
4. `QA_RULES_DIR` 外部依賴缺席時的行為驗證：qa-tester 在沒有 qa-testing-rules checkout 的機器上是 fail-loud 還是靜默劣化，結論寫入報告。
5. [[CC-064]] bootstrap wizard 僅在實測證明需要時才升級為實作票。

**Done-when**：兩個 smoke 的實測報告 committed（`docs/notes/` 或票內）；摔倒點全部開票；GETTING_STARTED 修正到與實測一致。

**Dependencies**：offline smoke 無前置可先行；live smoke 宜在 [[CC-446]] 契約凍結後執行。offline = v0.9.0 候選、live = v1.0-rc。
**See**: DECISIONS.md 2026-07-04

## CC-448 — opencode host support：probe → host manifest → install/doctor 接線（host 抽象 N=2 驗收）🔵 active

**Problem**：maintainer 2026-07-04 拍板 v1.0 host 支援面 = claude + **codex + opencode** 三者。[[CC-436]]/[[CC-437]]/[[CC-438]]/[[CC-445]] 只覆蓋 codex host；opencode 作為 host（PM 在 opencode session 內驅動 pm-dispatch，而非僅作 executor adapter）的能力面（hook/plugin 機制可否承接 write/bash guard、設定面佈局、session lifecycle）完全未驗證。

**Why**：host 抽象比照 executor 抽象的 N≥2 紅線——只有 codex 一個非 claude host 時，`hosts/*/host.yaml` schema 可能被 codex 特例帶歪（executor 軸的歷史教訓）。opencode host 落地若需改核心 = 抽象未竟。

**Requirement**（三階段，鏡像 CC-381→CC-436/437/438 的推進模式）：
1. **Probe**（唯讀，鏡像 [[CC-436]]）：opencode 的 hook/plugin 機制實測——有無 PreToolUse 等價事件？payload 表達力（command？file path？）？fail-closed 可行否？結論寫 `docs/spikes/CC-448.md`。
2. **Manifest**：`hosts/opencode/host.yaml` 以 [[CC-438]] schema v1 宣告 opencode host 能力（probe 結果決定 `guard_bindings` 表達）；若 schema 需為 opencode 增欄位，屬 schema 修訂而非 opencode 特例分支。
3. **接線**：[[CC-437]] doctor host module + [[CC-445]] install write path 對 opencode host 生效——驗收紅線：**核心零改動，僅新增 `hosts/opencode/` 內容**；做不到即回頭修抽象。

**Done-when**：sandbox 環境 opencode host install → doctor 全綠 →（若 probe 判定 guard 可承接）guard 攔截一次違規 → uninstall 無殘留；`docs/spikes/CC-448.md` 記錄能力矩陣；若 probe 判定 opencode hook 機制不足以承接 guard，fallback 為 cli-only guard（`pmctl guard check`）並在 host manifest 明宣告，v1.0 文件如實標示該能力差異。

**Dependencies**：依賴 [[CC-438]]（schema）、[[CC-445]]（host-generic write path）；probe（階段 1）可與 CC-436/437 並行先跑。umbrella [[CC-333]]。~~v1.0-rc 候選~~ → **v0.9.0**。

**Update 2026-07-06（v1.0-rc → v0.9.0 整票提前）**: 維護者拍板 v0.9.0 host 軸 = codex + opencode 雙 host（DECISIONS 2026-07-06）——N=2 驗收紅線由 v1.0-rc 提前為 v0.9.0 版內驗收，避免 `hosts/*/host.yaml` schema 在只有 codex 一個非 claude host 時定案被特例帶歪。三階段順序不變：階段 1 probe 與 [[CC-436]]/[[CC-437]] 並行先跑；[[CC-438]] schema 定案須同時吃進雙 probe 結果；階段 2+3 依 [[CC-438]]/[[CC-445]] 之後收尾。

**Update 2026-07-06（階段 1 probe 完成）**：`docs/spikes/CC-448.md`。關鍵發現：opencode 有宣告式 `permission.{bash,edit,...}: allow/ask/deny` 靜態設定，guard binding 比 codex 的 hooks.json 外掛式機制更簡單（不需寫腳本）；`bash: deny` 實測 fail-closed 且比 codex 乾淨（模型完全不嘗試呼叫）；但 `edit: deny` 單獨設定會被 `bash: allow` 繞過（用 shell 重導向寫檔案），必須兩者都納管才是真正的 file guard——這與 CC-436 的 codex `apply_patch`/`Bash` 不對稱發現同一類問題；`edit`+`bash` 同時 deny 會導致 `opencode run` 掛起，根因未查明，是階段 2 manifest 定案前的 blocking open risk。階段 2（`hosts/opencode/host.yaml`）、階段 3（doctor/install 接線）尚未開始。

**Update 2026-07-09（[[CC-476]] spike 解除 blocking open risk）**：`docs/spikes/CC-476.md`（中等信心）——掛起最可能系統性根因是 upstream `anomalyco/opencode` open issue #35073（headless subagent 權限 ask 誤判為 interactive），非 edit+bash 特定組合的獨立 bug；無直接修復但有繞過方式：階段 2 manifest 的 `bash` guard binding 一律用 per-pattern object 形式 `{"*":"deny"}`（非 bare string），並在 headless dispatch 外掛強制 timeout+kill（沿用 [[CC-470]] 逾時止血機制）。[[CC-438]] schema v1 已定案完成（pr:#375，BACKLOG-ARCHIVE.md）——階段 2 的兩個前置依賴（schema、掛起風險）皆已清除，可以開始寫 `hosts/opencode/host.yaml`。

**Update 2026-07-12（階段 2 started）**：新增 authored `hosts/opencode/host.yaml` 與 read-only doctor module，按 probe 如實宣告 native config command guard、unsupported file guard，以及尚未驗證的 PM command/lifecycle/statusline；install/uninstall modules 暫為 `null`。這個邊界是刻意的：在階段 3 證明 OpenCode 能安全、可逆地合併全域 permission config，且套用 guard 後仍有可用的 `pmctl` command path 前，不把「Bash 全 deny」誤算成完整 host。本機 OpenCode 1.17.7 唯讀覆核進一步確認 `command.<name>.template` 是 prompt template、不是可繞過 tool permission 的 deterministic shell wrapper；因此可行方案須在「per-pattern Bash denylist 仍放行 pmctl」與「實測 plugin command hook 執行 pmctl」之間收斂，不能直接沿用 `{"*":"deny"}` 並宣稱 PM interface 完成。下一步為 config merge ownership/rollback、command path probe 與 sandbox install→doctor→guard→uninstall E2E。
**Update 2026-07-12（stage-3 live design validated）**：維護者使用 throwaway `XDG_CONFIG_HOME` 實測確認兩個 acceptance facts：(1) `permission.bash` 以 catch-all deny 在前、checkout-specific `pmctl` allow 在後時，last-match-wins 正確放行 pmctl 並攔截非 pmctl 指令；(2) OpenCode custom command 能正常取得 `pmctl pm prepare` JSON。stage 3 可據此進入正式 wiring：只管理無既有 Bash policy 的 config（衝突即 fail-loud）、產生綁定本 checkout 絕對 pmctl path 的 `/pm` command、receipt + hash 驗證後可逆 rollback；不得覆寫或猜測合併既有使用者 Bash policy。

**Update 2026-07-12（stage-3 wiring implemented）**：`install.sh --enable-host opencode` 現由 manifest module 寫入 catch-all Bash deny + checkout-specific pmctl allow，並產生 native `/pm` command；receipt 記錄原 config backup 與 installed hashes。既有 `permission.bash`/permission shorthand/symlink config/foreign `/pm` 一律 fail-loud；uninstall 僅在 config 與 command hashes 未變時 byte-exact restore，否則保留使用者修改並中止。doctor 回報 wired `host_native/partial` PM interface 與 `host_policy/blocking/full` command guard。新增 OpenCode ownership suite（10 cases）與 Claude/Codex/OpenCode parity suite；正式跨 host live acceptance 使用 `docs/spikes/CC-445-448-cross-host-live-acceptance.md`，通過前本票維持 active。

**Update 2026-07-12（OpenCode GUI acceptance round 1 → remediation）**：GUI `/pm` 成功載入、working dir/snapshot/memory 全部正常且無 prompt/timeout，但回傳 `focus_tickets: []`，未帶入 request 明示的 CC-445/448；根因是 command 用固定 bootstrap request 做 shell-output injection，後續 prose 雖要求模型按 request 重跑，實際模型直接採用了 bootstrap envelope。修正為安裝 `pm_prepare` custom tool：command 強制把完整 GUI request 與抽出的 focus ticket array 作結構化 tool args；tool 以 `Bun.spawn(argv)`（非 shell）呼叫 pmctl，消除 quoting/injection 並保留 request-specific memory/focus。實機 upgrade 同時觀察到 OpenCode 自動為 config 加 `$schema`；receipt 改存忽略該欄的 canonical semantic hash，command/tool 仍 byte-hash，其他 config 修改照舊 fail-closed。ownership suite 擴為 11 cases；真實 `~/.config/opencode` 已升級，待 GUI 完全重啟後 round 2。

**Update 2026-07-12（OpenCode GUI acceptance round 2 GO）**：修正版真實 wiring 複驗通過：`/pm` loaded、working dir 正確、`focus_tickets=[CC-445,CC-448]`、snapshot created、memory readable/legacy resolver/context hydrated、project key `4633b7e7f780014195b603f84ce281c3a1afd97b` 與 Claude 完全一致、無 permission prompt/timeout。結合先前 catch-all deny + checkout pmctl allow 的 guard 實測，OpenCode host 功能性 acceptance GO；CC-448 保持 active 僅待本批 implementation gate/PR 收尾，不再有 host capability blocker。

**Update 2026-07-12（draft PR opened）**：與 [[CC-445]] 共用 draft PR #395；full-tier implementation gate 與 Claude/OpenCode live acceptance 均 GO。票維持 active 等待 review/merge，合併後再依 terminal/archive 規則關閉。
**See**: DECISIONS.md 2026-07-04、DECISIONS.md 2026-07-06、`docs/spikes/CC-448.md`、`docs/spikes/CC-476.md`

## CC-449 — release-verify/test-e2e：ship/worktree surface 煙測 + 套件註冊完整性 lint 🔵 active

**Problem**：v0.8.0 新增的 `pmctl ship`（unified entry / prepare / finish / `--parallel`）與 `pmctl worktree`（create/list/remove/gc）只有 unit 套件覆蓋；release sign-off 的 e2e 路徑（`test-e2e.sh` Phase B/C）只驗 dispatch 輸出契約與 pr-gate 機制，對這兩個新 surface 零 live 煙測。且 [[CC-444]] 收尾時發現 `test-pmctl-worktree.sh`（36 cases）**根本沒註冊進 `run-all-tests.sh`**——套件存在但 aggregator 從未執行，release-verify 的「全套綠燈」靜默漏掉它（已於 CC-444 補註冊）；「新增 suite 必須註冊」目前無任何機械防護。

**Why**：v1.0 P1 證據層的一環——release sign-off 的覆蓋範圍必須跟上 surface 的成長，否則 `release-verify GO` 的可信度逐版稀釋；註冊完整性 lint 是同類靜默缺口的止血閥。

**Requirement**：
1. **套件註冊完整性 lint**（第一刀，機械）：`scripts/test-*.sh` 存在但未在 `run-all-tests.sh` 註冊 → fail loud（允許顯式 exclude 清單，如 fixture-only helper）；接入 CI 與 `release-verify.sh` Phase 1。注意新增套件目前需**三處**同步——`run-all-tests.sh`（SUITE 陣列 + path map）與 `test-run-all-tests.sh`（`SUITE_NAMES` mirror + `suite_path` case）；後者的 parity 已由 meta 套件自身把關（CC-444 補註冊時實際觸發），lint 只需補「檔案存在但未註冊」這缺口，並評估把 meta-suite mirror 改為從 run-all-tests.sh 動態派生以消除第三處人工同步。
2. **ship/worktree e2e 煙測**：`test-e2e.sh` 新增 phase——synthetic target 上走一次 `pmctl worktree create → pmctl ship <id> --worktree → ship status 讀到 prepared → worktree remove`（不 dispatch、不花 LLM token 的最小閉環）；`ship finish` 的 live 驗證（含 gate）評估成本後決定納入或明文排除並記錄理由。
3. 與 [[CC-431]]（adapter 清單動態派生）同批評估，避免 e2e 腳本兩次重構。
4. **CI↔run-all parity 斷言**（2026-07-06 盲測稽核擴充）：`.github/workflows/lint.yml` 的 job 清單與 `run-all-tests.sh` 註冊表各自手動維護、零 parity 檢查——實測 24 個本地 suite 在 CI 從未執行，含 dispatch 核心（test-dispatch-lifecycle、test-dispatch-common、test-detached-launch、test-opencode-dispatch）與三個最大 pmctl 套件（test-pmctl-context/memory/dispatch）。lint 需一併涵蓋：run-all 每個註冊 suite 必須在 CI 出現，或列入顯式豁免清單並附理由（如 live-DB 互斥、耗時）。這是比第 1 項「未註冊」更大的同類靜默缺口。
5. **零覆蓋 lib 盤點**（同批）：`scripts/lib/gate-workspace.sh`、`scripts/lib/pmctl-config.sh` 在所有測試檔零引用——補最小套件或記錄豁免理由。
6. **surface 覆蓋分類 lint（反向補完，2026-07-07 openyida 跨專案分析併入）**：每個 command/agent/skill 必須宣告 `coverage: e2e|unit|opt-in|manual-only|deprecated` + 一行理由；本項是第 1 項「套件存在但未註冊」的反向缺口——「surface 存在但沒人宣告它該有什麼等級的覆蓋」。清單載體與既有 lint 機制（第 1/4 項）同批評估，避免產出第二套獨立 YAML/清單格式。

**Done-when**：lint 落地且能抓到「新增未註冊套件」與「已註冊但 CI 缺席且無豁免」與「surface 缺 coverage 宣告」三類注入測試；e2e 新 phase 在 `release-verify.sh --e2e` 下通過；排除項（若有）記錄於腳本註解與本票。

**Dependencies**：與 [[CC-431]] 檔案面重疊（test-e2e.sh/release-verify.sh），宜同版處理。v0.9.0 候選。
**See**: [[CC-444]] Outcome、pr:#367

---

## CC-475 — claude sonnet model alias 過期：對齊最新 claude-sonnet-5 ✅ 2026-07-09

**Problem**：`share/claude-model-aliases.tsv` 的 `default`/`sonnet` 兩列 alias 仍解析到 `claude-sonnet-4-6`，但目前最新的 Claude Sonnet 版本已是 `claude-sonnet-5`（wire id `claude-sonnet-5`）。對照同一份檔案內的 `opus`（`claude-opus-4-8`）與 `haiku`（`claude-haiku-4-5-20251001`），這兩個 alias 都已對齊各自家族的最新版本——只有 sonnet 這條路徑漏了更新，導致 `pmctl dispatch run`/`pmctl gate run` 在未指定 `--model` 時（也就是絕大多數呼叫的預設路徑）派發到一個過期的 model id。

**Why**：`default` alias 是整條 claude 派發路徑最常用的隱性入口（`docs/dispatch-brief.md` 明文「omit `--model` or write `model: default`」為建議寫法），過期的釘死版本代表日常派工都在用一個非最新的 model，且这類版本字串是分散在多處文件/測試的字面值，容易在下次模型升級時再度漏改（沒有單一 owner 盤點「目前最新版本 vs alias 表現況」）。

**Requirement**：
1. **更新 `share/claude-model-aliases.tsv`**：`default`/`sonnet` 兩列的 model 欄位從 `claude-sonnet-4-6` 改為 `claude-sonnet-5`；檔頭註解（第 15/16/23 行附近）同步更新版本字串與說明。
2. **文件同步**：`docs/model-tier-policy.md`、`docs/dispatch-brief.md` 提及 `claude-sonnet-4-6` 的字面值全部改為 `claude-sonnet-5`。
3. **測試同步**：`scripts/test-claude-dispatch.sh` 中斷言 `claude-sonnet-4-6` 字面值、且實際驅動 `adapters/claude/dispatch.sh` + 真實 `share/claude-model-aliases.tsv` 的案例（`case_model_alias_sonnet`、`case_model_alias_default`、`case_model_no_flag_resolves_default`、`case_model_pm_cfg_default_model`）改為斷言 `claude-sonnet-5`。`scripts/test-model-aliases.sh` 內同名字面值不動——盤點後確認該檔用的是純合成 fixture（`_mk_tsv` 自建一份與 repo 真實 tsv 無關的臨時表，測的是 `ma_resolve_alias` 解析器本身的行為，非「目前 sonnet 該指向哪個版本」），改了也不會提高覆蓋率，故明文列為 non-goal（見下）。
4. **不動 archive**：`BACKLOG-ARCHIVE.md`、`docs/spikes/*` 內的歷史記錄字面值保留不改（那是過去執行紀錄的事實描述，非現況契約）。

**Non-goals**：不順帶調整 opus/haiku 這兩個目前已對齊最新版本的 alias；不做「自動偵測 CLI 最新可用 model 並自動更新 alias 表」的機制化方案（那是更大範圍的設計題，這票僅修正當下已知的過期字面值）；不改 `scripts/test-model-aliases.sh` 裡 `claude-sonnet-4-6` 這個合成 fixture 字面值——該測試不讀真實 `share/claude-model-aliases.tsv`，字面值只是解析器測試的任意樣本資料，與本票要修正的「目前 sonnet 該指向哪個版本」無關。

**Verification**：`scripts/test-claude-dispatch.sh` 全綠（33/33，含上述 4 案例斷言更新後的字面值）；`scripts/test-model-aliases.sh` 維持全綠但不需要改動內容；`pmctl dispatch run --cd <tmp> --brief-file <tmp> --print-cmd`（不帶 `--model`）組出的指令含 `claude-sonnet-5`。

**Source**：使用者於確認派發相關內容時發現，2026-07-09。

**See**: pr:#389

---

## CC-476 — opencode `edit`+`bash` 同時 deny 掛起根因調查（spike）✅ 2026-07-09

**Problem**：[[CC-448]] 階段 1 probe（`docs/spikes/CC-448.md`）發現，opencode 宣告式 permission config 若同時設 `edit: deny` + `bash: deny`，`opencode run` 會無聲掛起（90 秒 timeout 內無任何輸出即被中止），即使帶 `--dangerously-skip-permissions`；這與單獨 `bash: deny`（模型乾淨回覆「I can't run shell commands」）行為不一致。根因未查——是等待某個永遠不會到來的互動提示？還是 opencode 內部重試迴圈？在不知道根因之前，無法確認「file-level guard 需要 edit+bash 都 deny 才算真正擋住」這個 CC-448 的核心結論在 headless dispatch 路徑上是否可行（若掛起無法解，等於這個保守預設在 headless 場景是死路）。

**Why**：這是 [[CC-448]] 階段 2（`hosts/opencode/host.yaml` manifest 定案）明文列出的 blocking open risk，卡住整個 opencode host 接線；同時是 v0.9.0 host 軸（codex+opencode N=2 驗收）的排程路徑上的節點。範圍窄、技術性（單一行為的根因），不是「該往哪個方向走」的開放性問題，適合小規模 spike 而非完整 /discover。

**Requirement**：
- Investigation scope：
  1. 用 `opencode run --format json`（或等效 debug/verbose 旗標）重現 CC-448 probe 的掛起情境，觀察掛起當下 process 狀態（`strace`/`py-spy` 等價工具或至少 `ps`/thread dump）——掛起是在等待 stdin/TTY 互動輸入？是網路呼叫卡住（model provider 重試）？還是某個內部 promise 沒有 resolve？
  2. 查 opencode 原始碼/CHANGELOG/issue tracker（若原始碼可讀取或有本地 vendor 副本）：`permission.edit`/`permission.bash` 同時 deny 時的內部處理路徑是否有已知 issue 或文件記錄的行為。
  3. 排除法：測試 edit+bash 以外的權限組合（如 `edit: deny` + `webfetch: deny`、三者全 deny）是否同樣掛起，縮小是「edit+bash 特定組合」還是「任兩個以上工具同時 deny 就掛」。
  4. 若能重現，嘗試找出繞過/修復方式（例如某個 flag、某個 config 欄位、升級版本後是否已修）。
- Done-when：能明確回答「掛起的觸發條件與根本機制是什麼」，並給出對 CC-448 階段 2 manifest 設計的建議之一：(a) 掛起有解，記錄解法；(b) 掛起無解但有繞過方式（如加 timeout + 強制 kill，接受 degrade）；(c) 掛起無解也無繞過，CC-448 manifest 需改設計（例如 opencode host 不採「全 deny」保守預設，改用其他 guard binding 策略）。
- Result log：`docs/spikes/CC-476.md`

**Outcome**：3-angle fan-out（重現+process檢視 / 原始碼與 issue tracker 先例 / 觸發組合縮小）收斂出建議 (b)：掛起無解但有繞過方式，中等信心（非高信心，見 spike 文件 Open risks）。最可能的系統性根因是 upstream `anomalyco/opencode` 已知 open issue #35073（headless subagent 的 ask 被誤判為 interactive，等待不存在的回應者，修復 PR #35823 未合併，正好對應本機安裝版本 1.17.8）——比「edit+bash 特定組合」這個框架更能解釋 a3 觀察到的「相同 config+prompt 時掛時不掛」flakiness。繞過方式：(1) `bash` 一律用 per-pattern object 形式 `{"*":"deny"}` 而非 bare string `"deny"`（a3 樣本雖小但方向一致）；(2) headless dispatch 呼叫 opencode 一律外掛強制 timeout+kill（CC-470 逾時止血機制可沿用），把掛起當作已知、有限機率的 degrade 情境接受；(3) 之後升級 opencode 版本前先確認 PR #35823 是否已合併修復 #35073。解除 [[CC-448]] 階段 2 manifest 定案的 blocking open risk。完整三角度證據、矛盾調和推理、Open risks 見 `docs/spikes/CC-476.md`。

**Dependencies**：承接 [[CC-448]] 階段 1 probe 的 open risk；解開後回頭解鎖 [[CC-448]] 階段 2。

**Source**：2026-07-09 PM discovery-route 分析（CC-445/469/470/474 陸續合併後盤點 v0.9.0 host 軸下一步）。
**See**: `docs/spikes/CC-476.md`、pr:#390

---

## CC-474 — dispatch/gate reasoning effort 獨立可調參數，預設收斂為 medium ✅ 2026-07-09

**Problem**：`pmctl dispatch run` / `pmctl gate run` 目前沒有獨立的 reasoning-effort 控制旗標——effort 值綁死在 `share/model-aliases.tsv`（codex）與 `share/claude-model-aliases.tsv`（claude）每一列 alias 的第三欄，經 `scripts/lib/model-aliases.sh` 解析出 `MA_RESOLVE_EFFORT` 後直接餵給 adapter（codex 端見 `adapters/codex/dispatch.sh:285` 的 `-c model_reasoning_effort="..."`）。這代表使用者若想調整某次派工的推理強度，唯一手段是換一個不同的 model alias——但常用 alias（codex 的 `default`/`gpt-5.5`/`gpt-5.4`/`codex-spark`/`light` 全部寫死 `high`；claude 的 `default`/`sonnet`/`light`/`haiku` 寫死 `normal`，只有 `opus` 是 `high`）並沒有「同一個 model、不同 effort」的組合可選。

**Why**：model 選擇（能力/成本層級）與 reasoning effort（同一 model 內的推理深度/延遲/token 用量）是兩個獨立維度，糊在同一張 alias 表格裡意味著每次想省成本/縮短等待就得被迫換一個能力較弱的 model，或反過來為了拉高 effort 被迫換一個較貴的 model。CC-445 這次 pr-gate 迭代（全程用 codex `default` alias、effort 固定 `high`，跑了 12+ 輪 full-tier ×5 reviewer）讓使用者實際感受到這個耦合的成本；使用者的訴求是把 dispatch/gate 的預設 effort 收斂為 `medium`，同時保留視情況調高/調低的彈性，而不是二選一寫死。

**Requirement**：
1. **新增 `--effort <value>` CLI 旗標**：`pmctl dispatch run` 與 `pmctl gate run` 都接受，語意為「覆蓋 model alias 解析出的 effort」，優先序為 `--effort` 旗標 > model alias 內建 effort > 全域預設 `medium`。旗標值域需對齊各 adapter 實際支援的 reasoning-effort 詞彙（codex/claude 目前用的值如 `high`/`normal`，需在實作時盤點 codex CLI `model_reasoning_effort` 與 claude CLI 對應設定各自接受哪些字面量，必要時做一層 pm-dispatch 內部詞彙 → adapter 原生詞彙的正規化，而非直接透傳使用者輸入）。
2. **預設值收斂為 medium**：修改 `share/model-aliases.tsv`、`share/claude-model-aliases.tsv` 常用 alias（`default`/`gpt-5.5`/`gpt-5.4`/`sonnet`/`haiku` 等）的 effort 欄位，或改為由旗標邏輯在未指定 `--effort` 時套用全域預設，兩種做法擇一並在票內定案（後者更貼近「效果獨立於 alias」的設計方向，但需確認不會影響 `light`/`codex-spark` 這類本來就該維持低延遲的路徑）。
3. **文件同步**：`docs/dispatch-brief.md`、`docs/executor-contract.md` 補上 `--effort` 契約說明；`agents/project-pm.md`、`pr-gate-review` skill 提及派工時預設 medium、僅在需要更深入分析（如高風險/連續 NO-GO 升級）時才建議使用者手動加 `--effort high`。
4. **opencode adapter 現況盤點**：目前 opencode adapter 沒有任何 effort/reasoning 解析邏輯——查明 opencode 是否原生支援等效概念；若支援則一併補上，若不支援則在票內明文記錄為 non-goal（不要為了統一介面而偽造一個 opencode 不支援的旗標語意）。

**Non-goals**：不做「依 tier/risk 自動升降 effort」的啟發式（那是另一個更大的政策題目，先讓旗標本身可控即可）；不改變各 model 的能力/報價層級選擇邏輯本身；不強行讓三個 adapter 的 effort 詞彙變成完全相同的字串集合（各家原生支援的值域不同，正規化層負責轉換，不是消滅差異）。

**Verification**：model-alias 解析相關測試套件新增 `--effort` override 案例（含「旗標覆蓋 alias 內建值」與「未給旗標時套用全域預設 medium」兩態）；`test-pr-gate.sh`/`test-pmctl-dispatch.sh` 斷言帶 `--effort <value>` 時組出的 adapter 指令帶正確的原生 reasoning-effort 設定；相關 doctor/dispatch 套件全綠。

**Source**：使用者在 CC-445 pr-gate 多輪迭代（本 session 全程以 codex `default` alias 隱性 `high` effort 執行）之後提出，2026-07-08。

**See**: pr:#387

---

## CC-451 — core/ 定義層接上 runtime：enum 單一來源 + state 寫入 schema 驗證 🔵 active

**Problem**: `core/` 定義層（8 個 JSON Schema + policy enum/狀態機 YAML）從未接上 runtime——`core/README.md` 自承「the current implementation handles path resolution and state writes without validating against the definition layer (integration deferred to a future milestone)」；三個 policy 檔（`executor-enum.yaml`、`dispatch-routes.yaml` 等）檔頭標「deferred to v0.3.x runtime phase」至今（v0.8.0）未兌現。實際後果：executor/isolation enum 在 adapter dispatch 腳本與 `handover-validate.sh` 各硬編一份、靠人工同步（`executor-enum.yaml` 自承 "embedded inline ... kept in sync"）；`scripts/lib/state-writer.sh` 手寫 JSON、不經任何 schema 檢查。

**Why**: [[CC-446]] v1.0 契約凍結要把 schema 列為 stable 承諾，但 runtime 從不驗證的 schema，其承諾是空的——凍結前應先讓定義層「真的在管事」。enum inline 複本漂移也是未來新增第 4 個 executor 時的實際回歸風險（2026-07-06 盲測稽核）。

**Requirement**:
1. **enum 單一來源**：executor / isolation-level 等 enum 由 `core/policy/*.yaml` 派生（runtime 讀取或 build-time 生成，實作時 `/pre-impl` 收斂取捨）；至少先落地一個 parity 回歸測試鎖住「所有 inline 複本 == policy YAML」，抓漂移。
2. **state 寫入驗證**：state-writer append 的 event/record 對 `core/schema/*.schema.json` 對應 schema 做結構檢查（jq 層即可，不引新依賴）；預設 fail-loud，可保留 warn-only 過渡開關。
3. 不改 schema 內容本身；現有綠燈路徑行為不變（回歸鎖住）。

**Non-goals**: 不做完整 JSON Schema validator（draft-07 全語意）；結構檢查以「必要欄位存在 + enum 值合法」為度。

**Dependencies**: [[CC-446]] 的前置/同批（stable schema 分級需要「有驗證」的事實支撐）。承接 [[CC-211]]（schema-first epic）的 runtime 驗證切片。v0.9.0。
**Source**: 2026-07-06 盲測程式碼稽核（四路獨立分析，未讀 backlog 前提下收斂的最大未規劃項）。

## CC-452 — guard/hook 對稱性與併發 hardening 🔵 active

**Problem**（2026-07-06 盲測稽核，三項低風險高確定性 correctness/一致性缺口）:
1. `guard-session-summary.sh` 對 episodes.jsonl 的 skeleton append 是裸 `>>` 無鎖，而同一資料面的 `guard-inject-memory.sh` usage sidecar 已用 `serialize_with_lock`——並發 Stop hook（同 cwd 多 session）可交錯寫、破壞 dedup 前提。
2. 三個安全 guard 的 shell 選項不一致：`guard-executor-write.sh` 用 `set -euo pipefail`，`guard-pm-write.sh`/`guard-reviewer-write.sh` 缺 `-e`——未預期非零命令靜默續行。
3. ISO8601 日期正規化 ~30 行在 `guard-inject-memory.sh` 與 `guard-session-summary.sh` 逐字重複，漂移風險。

**Requirement**:
1. episodes.jsonl append 包進 `serialize_with_lock`，補並發回歸測試。
2. 三安全 guard 統一 `set -euo pipefail`（逐檔確認無依賴非零續行的路徑後切換）。
3. ISO8601 正規化抽到 `scripts/lib/memory.sh`（兩 hook 既有共用點），兩處改呼叫。
各項行為對現有測試 byte-compatible；只修對稱性與併發安全。

**Dependencies**: 無前置；v0.9.0 hardening phase，與其他 phase 檔案面不重疊可並行。
**Source**: 2026-07-06 盲測程式碼稽核（runtime 管線角度）。

## CC-477 — guard memory usage sidecar 並發遺失更新 🔵 active

**Problem**: `scripts/test-guards.sh` 的 `memory-usage/concurrent-no-lost-updates` 已多次在完整 `run-all-tests.sh` 中失敗（例如 2026-07-10 gate pre-flight 觀察到 final `access_count=21`, expected `25`），但單獨重跑可通過。這表示 `guard-inject-memory.sh` 的 usage sidecar read-modify-write 路徑在真實 contention 下仍可能遺失 access increment，或其測試/lock lifecycle 本身不具足夠隔離與可觀測性。它反覆阻斷 gate，不能再視為偶發噪音。

**Why**: usage sidecar 是 frecency 排序的唯一寫入訊號；遺失更新會讓排序資料偏低且不可觀測。更重要的是，`serialize_with_lock` 已是此路徑的既有安全宣稱，卻無法在 full-suite 壓力下穩定兌現，代表 lock scope、ownership、清理或測試同步其中至少一處有缺口。

**Requirement**:
1. 先建立可重複、可診斷的 contention repro：每個 writer 有唯一 id、barrier/start timing、完成數與 sidecar 最終值皆可記錄；失敗時保留足夠的 sandbox evidence 判斷是 writer 未啟動、lock 未互斥、還是 commit 被覆寫。
2. 釐清 `serialize_with_lock` 對同一 sidecar 的鎖 key、owner、timeout/cleanup 與 read-modify-write scope；修正根因，不以無上限 retry 或降低 assertion 掩蓋。
3. 修正後，並發 regression 在同一 suite 及 `run-all-tests.sh` 平行執行下都必須穩定：至少多輪 contention 壓測零遺失更新，且不引入全域鎖或跨 fixture state 汙染。
4. 將 failure evidence 與 chosen locking invariant 寫入測試註解或短設計 note，使下次 gate failure 可直接定位。

**Non-goals**: 不改 canonical Markdown card；不把 usage sidecar 改成資料庫；不因測試 flake 而跳過 `test-guards` 或把 gate pre-flight 改成 warn-only。

**Dependencies**: 與 [[CC-452]] 同屬 guard/hook concurrency hardening，但本票涵蓋的是已使用 lock 的 usage sidecar 交易完整性；可並行調查，修法若需要 shared lock helper 則在實作時協調。v0.9.0 hardening P2。

**Evidence**: 2026-07-10 full gate pre-flight 多次出現 `memory-usage/concurrent-no-lost-updates` 遺失 increment（21/25）；另一次 `test-pmctl-memory` fixture case 單獨重跑通過，支持「full-suite contention / isolation」方向，而非 CC-473 行為回歸。

---

## CC-478 — codex default model alias 過期：對齊 gpt-5.6 三分支 ✅ 2026-07-12

**Problem**: `share/model-aliases.tsv` 的 `default` 仍釘舊 `gpt-5.5`，未跟進新推出的 GPT 5.6 世代。GPT 5.6 並非單一 wire id，而是三個具名分支：`gpt-5.6-sol`（frontier）、`gpt-5.6-terra`（balanced/everyday）、`gpt-5.6-luna`（fast/affordable）。

**Resolution**: `default` 改指向 `gpt-5.6-terra`（與舊 `default`→`gpt-5.5` 同屬 balanced/everyday 定位最相符）；`gpt-5.6-sol`/`gpt-5.6-luna` 同步登錄為可明確指定的 alias；`gpt-5.5`/`gpt-5.4` 保留為 fallback chain；`gpt-5.3-codex-spark`/`light` 維持獨立用量池不變。同步更新 `adapters/codex/dispatch.sh`、`docs/dispatch-brief.md`、`scripts/pr-gate.sh` 註解與對照表，並在 `docs/model-tier-policy.md` 新增三分支選型指引。新增/更新 `scripts/test-codex-dispatch.sh`、`scripts/test-pmctl-dispatch.sh` 測試斷言，`scripts/lint-model-aliases.sh` 通過。`/pr-gate` standard tier：GO（2 個 low advise，皆已修正：測試函式改名、選型指引補上）。

**See**: pr:#392

---

## CC-479 — `share/model-aliases.tsv` 改名 + claude 舊世代 alias 補回 ✅ 2026-07-12

**Problem**: `share/model-aliases.tsv`（codex table）沒有前綴，與 `share/claude-model-aliases.tsv`、`share/opencode-model-aliases.tsv` 的命名慣例不一致，容易誤以為是「泛用」表。另外，`share/claude-model-aliases.tsv` 在先前的 sonnet-5 bump（CC-475）中只保留了當前世代 alias，沒有像 codex 表（CC-478 保留 gpt-5.5/gpt-5.4 fallback）一樣保留舊世代 alias 供明確指定回退。

**Resolution**: `git mv share/model-aliases.tsv share/codex-model-aliases.tsv`；同步更新 runtime 路徑解析（`adapters/codex/dispatch.sh` 的 snapshot 來源/目的檔名與 `PM_DISPATCH_ALIAS_FILE` fallback chain）、`scripts/lint-model-aliases.sh`、`scripts/lib/model-aliases.sh` 錯誤訊息、`install.sh` share asset 安裝路徑、`docs/dispatch-brief.md`／`docs/model-tier-policy.md`／`agents/project-pm.md` 的路徑引用，以及對應測試（`test-install.sh`、`test-uninstall.sh`、`test-codex-dispatch.sh`、`test-dispatch-handover.sh`、`test-lint-model-aliases.sh`）。歷史/凍結紀錄（`CHANGELOG.md`、`BACKLOG-ARCHIVE.md`、已關閉票的內文、`docs/spikes/*.md`）刻意不動，保留當時真實路徑。

同時對照 Anthropic 官方文件（platform.claude.com/docs，2026-07-12 確認）補回 `share/claude-model-aliases.tsv` 的舊世代 alias：`sonnet-4-6`→`claude-sonnet-4-6`、`sonnet-4-5`→`claude-sonnet-4-5-20250929`、`opus-4-6`→`claude-opus-4-6`、`opus-4-7`→`claude-opus-4-7`（皆非 default，僅供明確指定回退），並在 `scripts/test-claude-dispatch.sh` 新增對應覆蓋案例、`docs/dispatch-brief.md` Claude 對照表同步。

**Requirement**（驗收，皆已完成）:
1. `scripts/lint-model-aliases.sh` 通過（codex + claude 兩表的 doc-sync／test-fixture-coverage 檢查）。
2. `pmctl backlog lint` 通過。
3. `test-codex-dispatch.sh`、`test-claude-dispatch.sh`、`test-lint-model-aliases.sh`、`test-install.sh`（`install-share-asset-*`）、`test-dispatch-handover.sh`、`test-pmctl-dispatch.sh` 全數通過。

**See**: pr:#393

---

## CC-453 — worktree/auto-pack 路徑契約 hardening 🔵 active

**Problem**（2026-07-06 盲測稽核 + 實際洩漏案例）:
1. `pmctl_worktree_create` 以「stdout 最後一行 = worktree 路徑」為輸出契約，`git worktree add` 的 stdout chatter（`HEAD is now at ...`）不抑制、只靠消費端 `tail -1`（`pmctl-ship.sh` 等）——契約脆弱。2026-07-03 開發期間曾實際把 5 個名為 `HEAD is now at <sha> seed` 的垃圾目錄洩漏到 repo 根目錄（內含 `.pm-dispatch/ctx/packs`；因 `.pm-dispatch` 被 gitignore，`git status` 完全不可見）。2026-07-06 已清除，現行套件重跑不再重現，但根因鏈仍在。
2. `pmctl_dispatch_auto_pack` 對 work_dir 的 ctx_root 解析：`git -C "$work_dir" rev-parse` 失敗時靜默 fallback `ctx_root="$work_dir"`，接著相對路徑 `mkdir -p`——垃圾輸入會在當時 CWD 造出目錄而非 fail。
3. `adapters/opencode/dispatch.sh` 的 isolation 錯誤訊息推薦 `workspace-write`，但其 `isolation-map.yaml` 只支援 `none`——把使用者導向不被接受的值。

**Requirement**:
1. `pmctl_worktree_create` 抑制 git chatter 進 stdout（導向 stderr 或丟棄），stdout 收斂為「只印路徑」；既有 `tail -1` 消費端保持相容。
2. auto-pack 對 work_dir 驗證「存在 + 絕對路徑」，不符即 fail-loud 跳過 pack（沿用既有 auto-pack warning + telemetry 模式），絕不相對路徑 mkdir。
3. opencode isolation 錯誤訊息只提實際支援值。
各項補回歸測試（含「垃圾 work_dir 不得在 CWD 產生任何目錄」斷言）。

**Dependencies**: 無前置；v0.9.0 hardening phase。與 [[CC-449]] e2e 煙測互補（那邊驗 happy path，本票驗防禦面）。
**Source**: 2026-07-06 盲測程式碼稽核；洩漏目錄實例（已清除）。

## CC-456 — 去除 maintainer-local `~/github/` 佈局假設（repos-root 參數化 + sweep + lint 防再犯）🔵 active

**Problem**（2026-07-06 維護者自指出）: `~/github/` 是維護者本機的 repo 佈局習慣，卻已滲進多個操作性檔案成為隱含產品假設——其他使用者的 repo 可能在任何位置。盤點（2026-07-06）：
- `agents/project-pm.md`：agent description 寫死「repos under ~/github/」；工作流第一步 `ls ~/github/` 識別專案；brief schema 指向 `~/github/pm-dispatch/docs/dispatch-brief.md`（同時硬編了 pm-dispatch 的安裝位置）。
- `agents/qa-tester.md`：`QA_RULES_DIR` default `$HOME/github/qa-testing-rules`（有 env 覆寫，但 default 是 maintainer-local）。
- `commands/pm.md`：`--all-repos` 掃 `~/github/*/`（有 `--repos-root` 覆寫，default 同病）。
- `commands/skill-refine.md`：memory dir 範例假設 `-home-<user>-github` project slug。
- `scripts/guard-pm-write.sh`：deny 訊息內嵌 `~/github/pm-dispatch/docs/...` 路徑。
- `pm/scripts/validate.sh`：usage 訊息 `$HOME/github/pm-dispatch`；`pm/schema.md` canonical path 宣稱 `~/github/pm-dispatch/...`；`pm/templates/DECISIONS.md` 模板內文 `~/github/`。
（test fixtures 用 `/home/example/github` 屬合成路徑，不在範圍；`hook-codex-bash-guard` read-root 舊案由 [[CC-104d]] 追蹤且該腳本已不在現行 scripts/。）

**Why**: v1.0 public 正式版（DECISIONS 2026-07-04）的「別人裝得起來、用得下去」承諾，與 [[CC-447]] 乾淨機器 smoke 直接相關——非 `~/github/` 佈局的使用者會在 pm agent 識別專案、QA rules 解析、guard 錯誤訊息等處遇到靜默錯位或誤導。這與 [[CC-455]]（context repo_root 打錯 repo）同根：系統多處把「維護者本機佈局」當成「使用者環境契約」。

**Requirement**:
1. **參數化單一來源**：以既有 `PM_DISPATCH_REPO`（install 已錨定）派生 repos-root default（如其 parent 目錄），新增 env/config 覆寫（命名沿 `PM_DISPATCH_*` 慣例）；`--all-repos`、project-pm 的專案識別步驟、QA_RULES_DIR default 全改由此派生。
2. **prose/文件 sweep**：上列各檔的 `~/github/` 字面改為 env 引用、佔位符（如 `<repos-root>`）或由安裝路徑派生的描述；`pm/schema.md` canonical path 改錨 `PM_DISPATCH_REPO`。
3. **lint 防再犯**：比照既有 ratchet 慣例，在 lint 層加斷言——operational files（agents/commands/skills/scripts/docs/pm 模板）不得出現 `~/github` / `$HOME/github` 字面（測試 fixtures 的合成路徑除外）；sweep 完成後 allowlist 清空鎖死。
4. 與 [[CC-447]] offline smoke 驗收互扣：smoke 環境刻意用非 `~/github/` 佈局跑一輪。

**Dependencies**: 無硬前置；宜在 [[CC-447]] offline smoke 之前或同批完成，讓 smoke 直接驗證。與 [[CC-445]]（install write path）檔案面部分重疊（install/env 慣例），排程時注意順序。v0.9.0。
**Source**: 維護者 2026-07-06「`~/github/` 是我本地的使用方式，不代表其他使用者」；主線程同日全 repo 盤點。

---

## CC-460 — `pmctl commands --json` manifest + router↔manifest↔README 三方防漂移 lint 🔵 active

**Problem**: [[CC-033]] 2026-07-06 盲測稽核發現 README 只列 15 個 command 中的 2 個（`/pm`、`/pr-gate`）；[[CC-446]] Requirement 5a 發現 `--json` 覆蓋率僅約半數子指令。兩者共同根因是同一個缺口——command/subcommand 的機器可讀清單不存在單一來源，README 與 router 各自手動維護、無防漂移機制。2026-07-07 openyida（DingTalk 宜搭 AI-native CLI）跨專案分析發現其 `commands --json` + `check:commands` 三方比對模式直接命中此缺口。

**Why**: README 手動維護的 command 清單注定漂移（已實測漂到 2/15）；[[CC-446]] 契約凍結要把 CLI 分級列為 stable 承諾，若連「有哪些 command」都沒有機器可讀的單一來源，分級表本身就建立在會漂移的地基上。

**Requirement**:
1. `pmctl commands --json`：列舉所有已註冊 command/subcommand，輸出結構化 JSON（name、summary、area、stability tier 若 CC-446 已定案）。**權威來源分工**（避免雙寫漂移）：pmctl 內部 router 表是「command 是否存在/可執行」的權威來源（manifest 的 name/area 欄位由此派生）；`commands/*.md` frontmatter 是「summary 說明文字」的權威來源（manifest 讀取但不擁有存在性判定）。router 有但 frontmatter 缺（或反之）視為第 2 項 lint 要抓的漂移，而非留給實作臨時決定。
2. **三方防漂移 lint**：router 已註冊的 command ↔ `pmctl commands --json` 輸出 ↔ README command 目錄，三者任一方向缺漏即 fail loud；接入 CI。
3. **README/docs command 索引自動生成**（原 openyida 分析草稿的獨立子項，因與 manifest 屬同一 PR 範圍且無獨立驗收價值而併入本票，不另開票）：README command 目錄段落改由 `pmctl commands --json` 生成或以生成結果核對，取代目前手動列表。
4. 與 [[CC-451]] enum 單一來源同一設計精神（一份定義、多處消費、機械 parity 檢查）——實作時可借鏡其 parity 回歸測試模式。

**Non-goals**: 不做 command 說明文件內容重寫（僅索引/存在性，不驗證每個 command 的說明品質）；不覆蓋 skill/agent 的 coverage 分類（見 [[CC-449]] 第 6 項，機制不同、載體待同批評估避免兩套 YAML）。

**Done-when**: `pmctl commands --json` 輸出涵蓋全部已註冊 command；三方 lint 在 CI 抓到「新增 command 未進 README」與「README 列了已刪除 command」兩類注入測試；README 目錄與 lint 輸出一致。

**Dependencies**: 與 [[CC-446]]（stable CLI 分級表需要這份清單作為覆蓋範圍的事實依據，宜同批或先行）、[[CC-451]]（parity lint 設計參照）。v0.9.0 候選（契約凍結 Phase 3 的前置證據）。
**Source**: 2026-07-07 openyida（github.com/openyida/openyida）跨專案分析——`commands --json` manifest + `check:commands` 三方防漂移模式；承接 [[CC-033]] #4、[[CC-446]] #5a 兩個既有票內已記載的缺口。

## CC-461 — `doctor.sh --fix`：冪等/可逆自動修復 🟢 someday

**Problem**: `doctor.sh` 目前只診斷不修復——使用者發現問題後仍要手動對照文件執行修復步驟。2026-07-07 openyida 跨專案分析發現其 `doctor --fix` 模式：對可安全自動化的檢查項提供一鍵修復。

**Why**: 降低 onboarding 摩擦（呼應 [[CC-447]] 乾淨機器 onboarding 的動機），但自動修復本身有風險——必須先知道「摔倒點長什麼樣」才能定義安全的自動修復範圍，避免修復動作本身造成新的不可逆狀態。

**Requirement**:
1. 範圍限定：僅冪等（重跑無副作用）、可逆（有明確復原路徑）、不碰使用者內容（不動 BACKLOG/DECISIONS/memory 等使用者資料）三類檢查項可自動修復；每項修復動作需獨立小函式、獨立測試。
2. 白名單需待 [[CC-447]] offline smoke 產出摔倒點清單後才定案——避免憑空猜測要修什麼。
3. 與 [[CC-437]] doctor host module 介面對齊（host-specific 檢查項若可修復，走同一 module 介面）。

**Done-when**: 白名單內每個修復項有「修復前狀態 → `--fix` → 修復後狀態」的回歸測試；`--fix` 對白名單外的問題明確拒絕（不猜測性修復）。

**Dependencies**: 宜在 [[CC-447]] offline smoke 產出摔倒點清單後啟動；與 [[CC-437]] 對齊。
**Source**: 2026-07-07 openyida 跨專案分析——`doctor --fix` 模式。

## CC-462 — e2e 可拋棄資源紀律：前綴 + registry JSON + result artifact 🟢 someday

**Problem**: e2e/live smoke 測試建立的暫時性資源（synthetic ticket、worktree、branch）目前無統一的可拋棄資源紀律——清理靠個別測試自行處理，缺少集中登記與清單化收尾證據。2026-07-07 openyida 跨專案分析發現其做法：可拋棄資源一律加前綴命名 + 寫入 registry JSON + 收尾產出 result artifact。

**Why**: [[CC-449]] 新增的 ship/worktree e2e 煙測與 [[CC-447]] live dogfood smoke 都會產生此類暫時性資源，若無集中紀律，兩票會各自發明一套清理機制、後續維護者難以判斷「這個殘留資源是不是某次跑壞的 e2e 沒清乾淨」。

**Requirement**:
1. 可拋棄資源統一前綴命名慣例（如 `pmd-e2e-<run-id>-`）。
2. 建立時登記進一個 registry JSON（run-scoped），收尾時逐一核對登記清單完成清理，未清乾淨即 fail loud 並列出殘留。
3. 收尾產出 result artifact（本次建立/清理了哪些資源），供除錯與稽核。
4. 與 [[CC-447]] live smoke 共用同一 registry 機制，避免兩套實作。

**Done-when**: registry 機制落地且至少被 [[CC-449]] 新 e2e phase 或 [[CC-447]] live smoke 其中一者採用；殘留資源可被 lint 抓到。

**Dependencies**: 掛在 [[CC-449]] e2e 新 phase 之後實作；與 [[CC-447]] live smoke 共用同一 registry。
**Source**: 2026-07-07 openyida 跨專案分析——可拋棄資源紀律模式。

## CC-463 — `pmctl batch` 泛用批次執行原語 🟢 someday

**Problem**: 目前沒有通用的「對多個 ticket/target 批次執行同一動作」原語——每次需要批次操作（如批次跑 gate、批次 dispatch）都是臨時腳本。2026-07-07 openyida 跨專案分析發現其 `batch` 子指令模式。

**Why**: 批次執行涉及新的注入面（使用者提供的批次清單可能被用來繞過單筆操作的驗證）——這不是低風險的便利性功能，須明確設計安全邊界再落地，故列 someday 而非直接排入 milestone。

**Requirement**:
1. 依賴 [[CC-460]]（`pmctl commands --json` manifest）確認批次目標「存在於已註冊 command 清單」這一必要條件，但 manifest 現規劃欄位（name/summary/area/stability）**不含**批次安全性判定，不足以單獨作為合法性驗證來源。本票須額外定義獨立的 batch-safe allowlist/引數 contract（如標記哪些 command 允許被批次呼叫、批次專屬引數限制），manifest 只負責「這個 command 名稱真實存在」，不接受任意 shell 片段這條防線由本票自建。
2. 安全邊界設計需過 security-reviewer（新注入面：使用者可控的批次清單）。
3. 實作前 `/pre-impl` 收斂：批次的原子性/部分失敗行為（全有全無 vs 盡力而為 + 報告）、並行度上限。

**Done-when**: 有明確 Requirement 與安全邊界設計文件（`/pre-impl` 輸出）後才具備排入 milestone 的條件；本票目前僅記錄構想。

**Dependencies**: [[CC-460]]（合法性驗證來源）。
**Source**: 2026-07-07 openyida 跨專案分析——`batch` 子指令模式。

## CC-464 — `pmctl ticket draft --from <notes>` 🟢 someday

**Problem**: 目前從隨手筆記到結構化 backlog 票草稿全靠人工（PM agent 手動寫 pm-schema v1.2 格式）。2026-07-07 openyida 跨專案分析發現其 `flash-to-prd`（隨手筆記→結構化 PRD）模式。

**Why**: 若能把「筆記→結構化草稿」的機械部分自動化，可以降低 PM 起草票的摩擦；但草稿品質判斷（Problem/Why 是否抓對根因、Priority 是否合理）仍需人工 review，本票只做草稿生成，不做自動核准。

**Requirement**:
1. 依賴 [[CC-286]]（prefix-generic next-id derivation）——**注意 CC-286 目前狀態為 ⏸ deferred、尚未排程**，本票的 next-id 需求在 CC-286 落地前只能沿用現有 `pm-prep-snapshot.sh` 的 CC-only 派生，不阻塞本票開票但會限制其排入 milestone 的時機。
2. 輸出為草稿（含 Problem/Why/Requirement 骨架），不自動寫入 BACKLOG.md——review-first 邊界：草稿必須經人工確認後才落地，比照現有「PM 產出 brief 交主線程」的既定模式獨立設計，**CC-054 僅供鬆散參照**（CC-054 本身是 `/skill-refine` diff generation 的 deferred 票，非本票的直接設計前例，不應視為既定機制）。

**Done-when**: 有明確 Requirement 與人工 review 邊界設計後才具備排入 milestone 的條件；本票目前僅記錄構想。

**Dependencies**: [[CC-286]]（⏸ deferred，尚未排程）。
**Source**: 2026-07-07 openyida 跨專案分析——`flash-to-prd` 模式。

---

## CC-480 — host-switch memory continuity：resolution contract + deterministic hydration ✅ 2026-07-12

**Problem**: [[CC-412]] 已把 memory cards、resolver override 與 `pmctl context --source memory` 做成跨工具 substrate，但「切換 host 後仍確定讀到同一份 memory」尚無 runtime 契約。`find_memory_dir` 對不存在的顯式 override 會靜默 fall through 到 Claude legacy path；Codex/OpenCode 雖可手動呼叫 retrieval API，卻沒有 deterministic chokepoint 保證每次 PM preparation 都會讀取。結果是 host 切換可能表面成功、實際讀到另一個目錄，或完全漏掉既有 memory。

**Why**: v0.9.0 要宣稱 Claude + Codex + OpenCode host 軸成立，除了 install/doctor/guard，還必須維持 PM 的跨 session continuity。Memory 是 project-owned substrate，不是 host-owned state；host manifest 只描述 host 如何承載能力，不應各自持有或複製 memory。這張票補的是 [[CC-445]]/[[CC-448]] 未涵蓋的 project-memory continuity 驗收，並沿用 [[CC-412]]，不另造一套 Codex memory。

**Requirement**:
1. 新增 `pmctl memory resolve [--repo-root <path>] [--json]`，輸出 canonical repo root、stable project key、memory dir、resolution source（`env`/`config`/`legacy`/`none`）、readable/writable 與 status。
2. 保留 `find_memory_dir` 舊呼叫端的 byte-compatible fallback；新 strict resolver 對已明確設定但不存在／不可用的 `PM_MEMORY_DIR` 或 `dispatch.memory_dir` fail-loud，不得偷偷切到 legacy memory。未設定且沒有 legacy memory則回報 `unavailable`，不是錯誤目錄。
3. `pmctl pm prepare` 在 snapshot 之後固定執行 memory resolve + request-scoped `pmctl context pack --source memory`，把 bounded retrieval 結果放入 JSON/human preparation contract；零 memory／零命中 fail-open，明確錯誤 override fail-closed。
4. Host-switch E2E fixture：同一 repo、同一 canonical memory，由 Claude legacy path 與 `PM_MEMORY_DIR`/config 路徑分別進入時 resolve 到同一位置；Claude 建立的 card 可由 Codex preparation 讀到；不得複製或建立第二份 memory。
5. 不把 memory location 加進 `hosts/*/host.yaml`；host manifest 與 memory substrate 保持正交。跨 host 寫入 provenance、episode namespace 與 telemetry coverage 若超出本切片，明列 follow-up，不能讓本票虛假宣稱已解決。

**Done-when**: `pmctl memory resolve --json` 可機械區分 resolved/unavailable/invalid-explicit；`pmctl pm prepare --json` 對共用 memory 回傳來源與非空相關 context；不存在的 explicit override 阻止 preparation；unset 路徑維持既有行為；memory/pm/commands tests 全綠，並由 Claude 對 diff 與測試證據做獨立確認。

**Resolution**: 新增 strict `pmctl memory resolve`（env > config > legacy，stable worktree-aware project key，invalid explicit/relative path fail-loud）；`pmctl pm prepare` 固定產出 canonical resolution + pointer-only memory context pack，pack 以完整 `memories[]` 項目縮減維持 ≤6000 bytes 且 JSON 永遠可解析，human/JSON 兩種 contract 均覆蓋。`commands/pm.md` 與 `agents/project-pm.md` 已接上 consumer guidance：canonical memory 優先、ref confinement、不得複製成 host-local memory。驗證：memory 61/61、pm 26/26、commands 276/276、backlog 18/18；Claude targeted pr-gate `gate-20260712-054618-f7d93e` Final GO，`pmctl gate verify` 通過。

**See**: Claude pr-gate `gate-20260712-054618-f7d93e`（Final GO）

**Dependencies / sequencing**: 建在 [[CC-412]]（已完成）與 [[CC-473]]（Codex batch PM interface，已完成）上；與 [[CC-445]]/[[CC-448]] cross-link 但不混入 host install manifest。[[CC-452]]/[[CC-477]] 是後續跨 host 共寫 episodes/usage sidecar 的正確性前置；memory 品質工作序列調整為 **CC-480 → CC-465 → CC-467 → CC-468 → CC-466**，其中 CC-465 可與本票的 resolver 切片並行。

---

## CC-465 — memory/context 關鍵詞管線 CJK 支援 🔵 active

**Problem**: 記憶注入排序（`guard-inject-memory.sh` 的 keyword 抽取）、檢索抽詞（`_ctx_extract_terms` → prompt-scan / reuse-scan）、FTS5 索引（unicode61 tokenizer）三處分詞全為 ASCII-only，CJK 字元被當分隔符丟棄。維護者工作語言為中文：中文 prompt 的 keyword tier 恆為 0 分、tier2 排序退化為純 frecency；且 usage sidecar 只在 keyword 命中時累積 access，中文工作流永遠累積不到使用訊號——整套 frecency 機制對 CJK 使用者形同虛設。prompt-scan / reuse-scan 對中文任務描述抽不出任何詞；FTS5 對整段中文只存單一 token，中文查詢僅靠 LIKE substring fallback 硬撐。

**Why**: 分詞邏輯設計時只考慮英文 identifier；CJK 無空白斷詞，ASCII 字元類過濾直接消滅整段文字。這是功能性缺陷而非排序品質調校——注入排序、usage 累積、檢索三條線同時失效。解法定調為**抽出一個共用零依賴斷詞 lib**（CJK bigram：連續 CJK 串切 2-gram），讓三個呼叫端遷移過去共用同一實作，而非三處各自獨立補丁——避免三份幾乎相同的邏輯各自漂移。FTS5 unicode61 tokenizer 對中文查詢的行為則視為與此共用 lib 分離的獨立關注點，另案驗證，不預設用同一次修改解決。不需外部分詞器，符合 bash / zero-LLM hooks 約束，也不觸發 [[CC-340]]（embeddings/semantic backend）的 resume 條件。

**Requirement**:
1. 抽出共用零依賴斷詞 lib（如 `scripts/lib/retrieval-terms.sh`），實作 CJK bigram 斷詞函式作為單一實作來源。
2. `scripts/guard-inject-memory.sh`（keyword tier 抽取／注入排序）與 `scripts/lib/pmctl-context.sh` 的 `_ctx_extract_terms`（`prompt-scan` / `reuse-scan` 抽詞）改為呼叫共用 lib，取代各自現有的抽詞邏輯。
3. FTS5 unicode61 tokenizer 對中文查詢的行為（含 LIKE fallback）獨立驗證，視為與共用 lib 分離的關注點，允許各自的修復時程與驗收。
4. 既有英文行為不變；回歸測試涵蓋純英文、中英混合、純中文三類輸入，並驗證兩個呼叫端遷移至共用 lib 後行為一致。

**Cross-link**: [[CC-340]]（deferred；本票是非 embedding 的分詞修正，非其替代）。**工作序列**：本票是 CC-465 → CC-467 → CC-468 → CC-466 序列化工作串的起點——CJK 抽詞先修好，統計可視化與 brief 約束萃取才有可信賴的中文訊號可用。

---

## CC-467 — `pmctl memory stats`：注入效益可視化 🔵 active

**Problem**: 記憶注入每 prompt 默默執行，維護者無法回答「有記憶跟沒記憶差在哪」：沒有指標顯示注入了多少 bytes、哪些卡常被命中、哪些卡從未命中、episodes 骨架的語意摘要填寫率（Stop hook 只寫空骨架、`/mem-log` 靠人跑；填寫率低則 `/mem-distill` 上游是乾的，且此事目前完全不可見）。

**Why**: 2026-07-07 外部研究——全業界（Letta / mem0 / Zep / Claude Code 社群工具）都只量離線 retrieval recall，無人做 per-injection 效益遙測；唯一在野的 token 可視化是 claude-mem 的 token economics 顯示。pm-dispatch 原料已齊（inject-usage.tsv、episodes.jsonl、doctor）——一個唯讀聚合報表即可回答維護者的核心疑問，符合「輕量執行」方向：不加新遙測寫入面，只聚合既有資料。範圍刻意收斂為純唯讀聚合器（無新寫入面），先讓維護者看得見注入效益，再由 [[CC-466]] 在可信賴的遙測基礎上建置生命週期判斷。

**Requirement**:
1. 唯讀子指令輸出：卡片總數與注入預算使用、各卡命中次數與最後命中時間分佈、從未命中卡清單、episode 填寫率（非空 summary 佔比）。
2. 支援 `--json`（與 doctor 同級的結構化輸出）。
3. 不新增 hook 寫入面；僅聚合既有 sidecar / episodes / doctor 資料，不引入新的寫入路徑。

**Cross-link**: [[CC-465]]（CJK 抽詞先行，統計才能正確反映中文卡片的命中率）、[[CC-466]]（本票須先上線——[[CC-466]] 的休眠偵測邏輯建立在本票產出的遙測之上）。**工作序列**：CC-465 → CC-467 → CC-468 → CC-466。

---

## CC-468 — dispatch brief 帶 memory 約束：PM 萃取為 constraints 清單（pointer 僅作 provenance）🔵 active

**Problem**: auto-pack 走 reuse-scan 且 repo-only by construction；`context pack --source memory` 存在但 dispatch 從不使用。結果：feedback 卡裡的約束（如「此 repo 禁用某工具」「reviewer 反覆擋的模式」）永遠不會自動進 brief，全靠 PM 記得手貼——記憶對 executor 行為零影響力。

**Why**: 成功指標（DECISIONS 2026-06-10）本來就是「brief 直接引用 memory/decision anchors」；目前管線只對 repo plane 兌現，memory plane 缺最後一哩。單純 pointer-only ref 讓 executor 拿到一個 ref 卻看不到約束本體，等於沒有約束力——因此改為由 PM 在 brief authoring / auto-pack 階段，把私有卡片規則**萃取（extract）成一份非敏感的 `constraints:` 清單**直接寫入 brief；pointer 僅保留作為來源標記（provenance-only），不再是 executor 唯一可見的內容。約束類卡片常以中文撰寫，依賴 [[CC-465]] 先把 CJK 抽詞修好，查詢命中才可靠。

**Requirement**:
1. brief 授權／auto-pack 對 memory plane 做一次查詢，命中約束類卡片後，由 PM 將其規則轉譯為非敏感的 `constraints:` 條列寫入 brief（不是原文卡片內容，也不是單純 ref）。
2. 每條萃取出的 constraint 同時保留來源 pointer（ref + trust tier）作為 provenance，供人工回查原卡；executor 執行時只需讀 `constraints:` 清單。
3. 私有／敏感內容（含中文原文的具體措辭）不需逐字進入 repo-bound 產物；萃取後的 constraint 表述須為可公開的非敏感摘要，數量設上限。
4. 零命中時不加空區塊（比照 `auto_context:` 現行語意）；查詢或萃取失敗 fail-open 不阻斷 dispatch。

**Cross-link**: [[CC-465]]（依賴其先修好 CJK 抽詞——約束類卡片常以中文撰寫，命中依賴中文分詞正確）、[[CC-466]]。**工作序列**：CC-465 → CC-467 → CC-468 → CC-466。

---

## CC-466 — 記憶卡片生命週期閉環：expires_at 執行 + 關窗式 supersede + 休眠偵測 + doctor→distill 接線 🔵 active

**Problem**: 卡片 schema 有 `expires_at` / `status` 生命週期欄位但無任何執行面：注入 hook 只降級 `stale`/`superseded`、不看 `expires_at`；doctor 不報過期卡；usage sidecar 只餵排序、不餵老化（沒有「N 天未命中」的休眠訊號）；doctor 找到的 stale_repo_refs / orphan 與 `/mem-distill` 的提案迴路完全斷開，修復全靠人記得。記憶只進不出，長期必然膨脹並讓固定注入預算被殭屍卡佔據。

**Why**: 2026-07-07 外部研究（/research）結論——確定性生命週期的成熟做法是：(a) Graphiti/Zep 的雙時間軸「關窗不刪除」失效模型（schema 與關窗操作是確定性的，只有矛盾偵測需要智慧——正好是 `/mem-distill` 的既有職責）；(b) mcp-memory-service 家族的 access-count / last-access 休眠偵測（零 LLM）。pm-dispatch 原料已齊（usage sidecar、doctor、confirm-gated distill），缺的只是接線；LLM 判斷全部留在顯式指令桶，hooks 維持 zero-LLM。已評估並排除：mem0 每寫入 LLM 仲裁、Letta sleep-time LLM 整理（違反 zero-LLM hooks；`/mem-distill` + `/memory-compress` 已是顯式等價物）。本票應排在 [[CC-467]] 之後執行——需要先有可信賴的注入效益遙測，才能在其上建置休眠偵測與降級/移除判斷邏輯；在遙測可信之前先做生命週期自動化容易誤判。

**Requirement**:
1. 過期卡（`expires_at` 已過）在注入時降級、在 doctor 報告中列出。
2. supersede 採關窗語意：舊卡保留並標記失效日期與後繼指向，不物理刪除（與現有 archive-in-place 慣例一致）。
3. doctor 能從 usage sidecar 偵測休眠卡（超過門檻天數未命中）並列出。
4. `/mem-distill` 讀取 doctor 結構化輸出，把過期／休眠／stale-ref 卡轉成 UPDATE/REMOVE 提案，沿用既有確認閘門（不新增任何自動寫入路徑）。

**Cross-link**: [[CC-452]]（episodes.jsonl 併發 hardening，同資料面）、[[CC-467]]（前置依賴：本票排在 CC-467 之後，需要其遙測作為休眠判斷基礎）。**工作序列**：CC-465 → CC-467 → CC-468 → CC-466（本票為序列終點）。
**Source**: 2026-07-07 /research——Graphiti bi-temporal（github.com/getzep/graphiti）、mcp-memory-service decay 家族（github.com/doobidoo/mcp-memory-service）。

---

## CC-469 — codex reviewer sandbox 找不到 pmctl ✅ 2026-07-09

**Problem**：`pmctl gate run --parallel`（或任何以 codex 為 reviewer 的派工）啟動 `codex exec --sandbox workspace-write` 後，reviewer brief 內裸呼叫 `pmctl guard check ...` 回報 `pmctl: command not found`，該 reviewer 未產出結果、整個 gate 拿不到完整結論。2026-07-07 一次平行模式 gate run 實測重現，另一個 session 稍早也踩過同症狀。

**Why**：目前 `pmctl` 裸指令慣例是為了讓 Claude 的 permission-allow 前綴比對成立而設計；同一套「裸指令」假設套用到 codex sandbox 執行環境時可能失效——`codex exec` 的沙盒子行程未必繼承互動 shell 的完整 PATH（尤其 `~/.local/bin`），根因尚未確認。連續在兩個獨立情境命中，非偶發。

**Requirement**（待調查後定案，此為粗刻）：
1. 確認 `codex exec --sandbox workspace-write` 子行程實際繼承的 PATH/env——是否真的漏了 `~/.local/bin`，或另有原因（cwd、shell 種類等）。
2. 依調查結果選擇修法：(a) codex-dispatch.sh 派工前顯式帶入/保留 PATH；或 (b) reviewer brief 對 `pmctl` 呼叫改用可靠的絕對路徑解析（不破壞既有 Claude 端裸指令慣例）。
3. 回歸測試覆蓋兩種 gate 派工模式（sequential/parallel）在最小化 PATH 環境下仍能找到 `pmctl`。

**Dependencies**：與 [[CC-445]] 無關（後者是 PM 本身跑在 codex host 上；本票是 codex 被派去當 reviewer 時的沙盒環境問題）。

**Resolution**：根因未能確定性重現（互動環境下手動測試 `codex exec --sandbox workspace-write` 找得到 `pmctl`），故不追根因，改採方案 (b)：`pr-gate.sh` 在自身環境解析 `pmctl` 絕對路徑（PATH 查找，找不到則退回同倉庫 sibling `cli/pmctl`），codex reviewer brief 的 guard-check 指令改嵌入該絕對路徑；claude reviewer brief 維持裸 `pmctl`（PreToolUse permission-allow 前綴比對需要）。兩種解析路徑都失敗時（如隔離測試 fixture）退回裸字，行為不變。新增 3 個回歸測試覆蓋 sequential/parallel codex 絕對路徑解析與 claude 裸指令不受影響。
**See**: pr:#388

---

## CC-472 — spike: antigravity（`agy`）host 唯讀 probe 🟢 someday

**Problem**：使用者正在跟 agy（antigravity CLI）討論把它接成 pm-dispatch 的一個 host（PM 在該 CLI 內被驅動，而非僅作 executor adapter）。目前完全沒有評估過 agy 屬於哪一類、guard 綁定是否可行。

**Why**：討論過程中釐清一個先前被混淆的區分——**Executor**（背景自動派工、靠 post-verify 機械判定）需要結構化的 JSONL/JQ 可審計輸出；**Host**（人類互動起點）門檻低很多，只要能載入專案 slash command（如 `/pm`）、能在內部 agent 呼叫 Bash/檔案寫入時觸發 `pmctl guard check` 就夠格。`docs/host-contract.md` 的 `guard_bindings` schema 已內建這個分級：`pm_command_interface` 是強制宣告的能力（這才是「算不算 host」的門檻），`command_guard`/`file_guard` 允許合法宣告 `provider: none`（`confidence: probed`/`observed` 代表「已實測、這個 host 結構上就是做不到攔截」，是誠實終態宣告，不是缺陷）。

**Requirement**：比照 [[CC-436]]/[[CC-448]] 階段 1 的唯讀 probe 模式——不落地 `hosts/antigravity/host.yaml`，只實測：
1. command 載入能力（能否載入 pm-dispatch 的 `/pm` 這類 slash command，或有無等價機制）。
2. hook/plugin 機制（能否在 Bash/檔案寫入時觸發 `pmctl guard check`）。
3. 五個 capability enum（`command_guard`/`file_guard`/`session_lifecycle`/`pm_command_interface`/`statusline`）的 provider/confidence 判定。

結論寫 `docs/spikes/CC-472.md`。

**排程**：排在 [[CC-445]] 通用 install/uninstall dispatcher 工作**之後**、與 [[CC-448]] opencode 同批或緊接其後評估——antigravity 若真的接成 host，會是這個抽象的第三個驗證點（N=3）。使用者原話：「他只要是能呼叫pmctl 以及幫我排序內容 其實就可以算是host，只是有些host 沒有辦法限制 有些可以」。

**Dependencies**：與 [[CC-436]]（codex host probe）/[[CC-448]]（opencode host probe）同方法論；N=3 驗證需在 [[CC-445]]/[[CC-448]] 落地後才有意義。

---

## CC-473 — `pmctl pm` CLI surface ✅ 2026-07-12

**Problem**：[[CC-471]] spike 確認 codex 沒有 Claude Agent/subagent 呼叫機制，無法承接 `/pm` 的互動式 orchestration。要讓非 Claude host（codex、未來的 opencode/antigravity）也能用到 PM orchestration（snapshot 產生、handover validation、dispatch/wait 迴圈、discovery routing），需要一個不依賴 Claude harness 專屬工具（`Agent`/`AskUserQuestion`）的共用入口。

**Why**：`commands/pm.md` 目前的 orchestration 邏輯只存在於 Claude command markdown 裡，若每個新 host 都各自複製一份邏輯，會變成 architecture-reviewer 一再點名的「host-specific 分支各自維護、彼此漂移」問題（同類前例：[[CC-445]] 的 codex install/uninstall 分支）。

**Requirement**（規劃階段，粗刻）：
1. 把 `commands/pm.md` 的 snapshot 擷取、handover 驗證、dispatch/wait 排程邏輯抽成 `pmctl pm` CLI 指令，Claude `/pm` 與未來的 codex 呼叫同一份實作。
2. **明確範圍邊界**：`pmctl pm` 對非 Claude host 只提供 batch-only 模式（一次性餵完整需求、拿一次性 handover/結果），不做互動式澄清迴圈——這個縮水必須是設計時就聲明的限制，不是事後才發現的落差。Claude 自己的 `/pm` 可以繼續在同一套底層原語之上疊加 `Agent`/`AskUserQuestion` 的互動層。
3. 需要定義：當一個請求本該觸發 Claude `/pm` 的 uncertainty routing（discovery fan-out、範圍不明確的問題）時，batch-only 模式下要怎麼降級處理（例如預設走最保守路線並附上理由，而不是卡住等一個沒人能回答的問題）。

**Dependencies**：承接 [[CC-471]] spike 發現。與 [[CC-448]]（opencode host）並行——opencode 的 `pm_command_interface` 是獨立問題，不能假設跟 codex 一樣不支援，需要各自 probe 確認。

**Update 2026-07-10（implementation started）**：新增 `pmctl pm prepare`（batch-only request + snapshot contract）與 `pmctl pm run`（brief validation → detached dispatch → authenticated wait）。Codex manifest/doctor 改宣告 `cli_wrapper` / `partial`，不再把 binary 在 PATH 誤報為有完整互動式 `/pm`。Claude `/pm` 的 snapshot 呼叫改走 `pmctl pm prepare`；其 Agent/AskUserQuestion 與 run-level interactive monitoring 仍保留在 Claude host layer。後續補齊真實 Codex live smoke 後再結案。

**Closed 2026-07-12**：PR #391 已完成 full-tier Claude PR-gate（GO）。真實 Codex live smoke 以 `pmctl pm prepare → dispatch_handover_v1 → pmctl pm run --adapter codex → authenticated wait` 完成，run `run-20260711T181739Z-78ba4f` 的 dispatch/wait 皆 exit 0，Codex 回報 PASS 且工作目錄無修改。

**See**: pr:#391

---

## CC-393 — design: portable-skill-substrate — CLI-agnostic skill 控制層 🟢 someday

**Type**: design seed（想法捕捉；非 milestone 承諾）

**Thesis（session 2026-06-16）**: pm-dispatch 從 dispatch agents 升級為 dispatch **skill-guided agents**。skill = 平台中立的 portable Markdown contract（方法）、adapter = 平台轉譯層、core = 管 task/context/permission/verify/memory、tool layer = 權限邊界。

**Principles**: capability-matching 非平台名；skill 不執行/不持狀態/不知平台；evidence-based completion；runtime 注入非全域安裝。

**Key caveat**: 多數能力 pm-dispatch 已獨立長出——adapter manifest（[[CC-372]]）、post-verify 唯一驗證者（[[CC-386]]）、manifest-driven guard（[[CC-374]]/[[CC-375]]）。本票是替既有控制層**命名/索引**，不是補洞。

**Highest-leverage subset（control skills）**: `guard-aware-brief`（brief 帶 relevant controls + expected guards + completion condition）、`guard-result-review`（guard pass/fail → workflow decision，不改狀態）、`markdown-drift-audit`（Markdown ↔ script ↔ template ↔ core 漂移）。閉環：rule → brief → guard → evidence → state decision。

**Minimal landing**: 不做 marketplace/全域安裝/skill DSL；只做 3 個 control skill + thin Portable Skill v0 frontmatter。

**Boundaries**: skill 不跑 shell、不查 DB、不改 task status、不繞 guard、不當 workflow engine。

**Sequencing**: 排 v0.6.0（executor 抽象在 N≥2 = [[CC-376]]+[[CC-377]] 證明成立）**之後**；自然歸宿與 [[CC-216]]（v0.7.0 MCP 通用橋）同層同期——兩者都讓任意 host 透過穩定、平台中立契約共用單一 pm-dispatch。

**See**: `docs/notes/portable-skill-substrate.md`（完整 session synthesis）、umbrella [[CC-333]]。

---

## CC-390 — infra: codex dispatch trace-capture 強化 ⏸ deferred

**Problem / 目標**: [[CC-387]] 真實驗收期間發現，codex 0.139.0 在 session 冷啟動最初 1–2 次 dispatch 偶發 trace-capture flake。`adapters/codex/dispatch.sh` 把 codex stdout 經**繼承 FD**（`> "$TRACE"`）重導向到 `<work_dir>/.agent-trace/<ts>.jsonl`，但該檔在 codex sandbox 邊界偶失：`.last`（codex 以 `--output-last-message` 依路徑自開）存活，`.jsonl` 與 run-time `.stderr`（皆經 wrapper 繼承 FD）偶失，導致 [[CC-386]] post-verify「trace not found / 結構不完整」FAIL。

**證據（8 次 run）**: 非確定性——最初 2 次失敗、其後連 6 次完整 dispatch 全綠（含全新 repo 的 first-run）。已否證：isolation 值（`workspace-write` 與 `sandboxed` map 到**同一** codex 指令）、codex 是否 mutate workspace、fresh-repo first-run。最符合：codex CLI 冷啟動 transient（與 `agents/codex-executor.md` 既載「silent startup 已知 transient」一致）。

**安全性質**: **fail-closed**——trace 缺失時 post-verify 正確判 FAIL，**永不誤判 PASS**；失敗方向是 false-negative（成功 run 被報為失敗），非 false-positive。故非緊急。

**候選修法**: (a) trace 寫 `<work_dir>` 外（XDG state／temp 目錄），使 trace 不在 codex sandbox 的 workspace 內、也不污染 git status；(b) codex stdout 經 wrapper 控制的 pipe（`tee`）而非繼承 FD 直寫 in-workspace 檔（需處理 `PIPESTATUS` 以保留 exit code）。(a) 動到 trace 合約（post-verify／footer／latest 指標／多處測試引用 `<work_dir>/.agent-trace/`），較大；(b) 較外科。**前提：須先能穩定複現才能驗證任一修法**。

**Dependencies**: [[CC-386]]（trace 驗證合約）。發現於 [[CC-387]]。umbrella [[CC-333]]。

---

## CC-377 — adapter: Google Antigravity (`agy`) executor ⏸ deferred

**Status (2026-06-16)**: **DEFERRED — 待 agy 版本更新**。agy **有免費額度**（Gemini 3.x / Claude 4.6 / GPT-OSS 經 OAuth，成本非阻因）；暫緩純因 **headless CLI 尚未完善**。feasibility spike 證 agy 1.0.8 無 machine 契約，詳見 `docs/spikes/CC-377-agy-headless-feasibility.md`。實測：`--output-format`/`-o`/`--format`/`--log-level`/`--stream-format` 旗標皆被拒、無 `run` 子命令、`--print` 吐 prose narration（無 JSON/SSE、無語意終止事件）、headless 不穩（3/3 trivial-prompt 探針 timeout、不甩 do-not-use-tools 指令）。社群/AI 研究宣稱的 stream-json/SSE 模式不在 1.0.8（可能較新 build 才有）。**agy 仍為首選第二 adapter**。**Resume trigger（主路）**：較新 agy 出可用的 headless `--output-format stream-json` → 重跑探針，有 JSONL+終止事件即鏡像 `adapters/opencode/` 落地。**N≥2 影響**：暫未由 agy 達成；opencode（[[CC-376]]）為目前唯一獨立第三方 adapter；Phase 7 lifecycle 紅線（N≥2 後才做）出現 sequencing 缺口，待 maintainer 定奪（且 2026-06 免費 CLI 池枯竭，傾向等 agy 成熟而非另尋）。

**Problem / 目標**: 新增 Google Antigravity（CLI binary `agy`）作為第二個第三方 executor adapter，與 [[CC-376]] 對稱。第二個 adapter 的意義是驗證抽象在 **N≥2** 下成立——若 opencode 是特例僥倖，agy 會暴露出來。

**Note**: Google 的 **Gemini CLI 已棄用**；本票目標是 Antigravity 的 `agy` CLI，**不是 gemini**。adapter 目錄/名稱建議 `antigravity`（cli_binary `agy`），最終命名 impl 時定（須為 strict-identifier `^[a-z][a-z0-9_-]*$`）。

**Requirement**: 結構同 [[CC-376]]——`adapters/antigravity/` 的 dispatch.sh + adapter.yaml（`runner_kind`）+ isolation-map.yaml；主路 `pmctl dispatch run --adapter antigravity`；map sandbox/permission/model-alias；釐清 bash 攔截能力決定 guard 旗標。

**驗收**: 同 [[CC-376]]——零核心改動即可落地。

**Dependencies**: [[CC-373]]、[[CC-374]]。建議排在 [[CC-376]] 之後（第一個 adapter 若暴露抽象缺口，先補再上第二個）。umbrella [[CC-333]]。

---

## CC-370 — native Windows support deferred to post-core platform phase

**Problem**: During active feature development, supporting native Windows Git Bash concurrently with core work diverts effort from features — each MSYS failure class (symlink/Developer-Mode, flock/mkdir locks, `chmod 0700` no-op on NTFS, path dialects, CRLF, native `jq.exe` arg conversion) needs its own branch + skip-guard, and CI runs Linux only so every Windows-touching change carries manual verification + gate churn (#272 shipped Linux-green but Windows-broken; #273's first cut passed pr-gate yet broke on native jq.exe). The blocker is **focus**, not testability.
**Decision**: core-development phase officially targets **Linux + WSL2 only** (WSL2 treated as Linux); native Windows Git Bash is **not officially supported** — Windows users run under WSL2. Already-merged portability code (#272/#273, CC-104*) is kept (green, low-cost) but no new native-Windows branches are added until a dedicated **platform phase after the core stabilizes (v0.5.0+)**. Contract is explicit in `docs/platform-support.md`, `README.md`, `docs/RELEASE_CHECKLIST.md` (sign-off = Linux/WSL2 only); `doctor.sh`/`release-verify.sh` print a "use WSL2" notice on native Windows.
**Parks** (re-triage at the platform phase): CC-038 (locking primitive), CC-104d/e/f/g/j/k/r/s (Windows dogfood findings), CC-369 (state-store icacls ACL).
**See**: DECISIONS.md 2026-06-13 `defer-native-windows-support-during-core-dev`.

## CC-369 — Windows state store 真實 ACL via icacls（deferred）

**Problem**: CC-368 #2 在 NTFS 上以 SKIP-with-reason 處理 `state_store_init` 的 0700 斷言（`chmod` 是 no-op），但這只讓測試誠實，並未在 Windows 上達成等價的「僅擁有者可存取」保護。目前 state store 落在 `%USERPROFILE%` 下，僅依賴該目錄既有的 NTFS ACL。
**Why**: 真正等價 0700 需以 `icacls` 移除繼承並僅授權目前使用者，屬 Windows 專屬分支與測試成本。相對於 profile 目錄既有 ACL，邊際安全收益不高，且 Windows 尚非 Supported，故 deferred。
**Requirement**: 待 Windows = Supported flag flip 前評估：`state-writer.sh` 在 Windows 偵測下以 `icacls "<store_root>" /inheritance:r /grant:r "%USERNAME%:(OI)(CI)F"` 等價設定收斂保護，並補對應能力測試。
**Source**: 2026-06-13 CC-368 #2 收尾時分出的 follow-up。

## CC-450 — 其餘 9 個 test-*.sh docstring 格式統一（CC-004 同款 Behavior/Steps，跨檔）

**Problem**: [[CC-004]] 實作時盤點發現，同樣的 docstring 不一致問題不只 test-pr-gate.sh：`test-doctor.sh`(5)、`test-e2e-script.sh`(13)、`test-install.sh`(77)、`test-patch-gitignore.sh`(5)、`test-pr-gate-profile.sh`(13)、`test-release-verify.sh`(25)、`test-run-all-tests.sh`(26)、`test-setup-project.sh`(9)、`test-uninstall.sh`(28) 共 9 個檔案、201 個 test function 完全沒有 `# Behavior:`/`# Steps:` 開頭註解。
**Why**: 純 audit-quality / 一致性問題，不影響測試邏輯或功能；規模較大故從 CC-004 拆出獨立票，避免單票範圍無限擴張。
**Requirement**: 依 `scripts/lib/test-harness.sh` 頂部新增的 docstring 慣例說明（CC-004 帶入），逐檔把上述 9 個檔案的 test function 補上 `# Behavior:`/`# Steps:` 註解區塊，整段置於函式宣告正上方、不拆進函式內部。不改測試邏輯。完成後跑對應套件全綠、`bash -n` 語法檢查、以及 run_test 呼叫名稱與函式宣告的交叉核對（避免重蹈 CC-004 實作中一度誤刪宣告行的錯誤）。
**Source**: 2026-07-03 CC-004 實作時的範圍盤點。

## CC-454 — CI shellcheck ignore_names 白名單 ratchet 收斂 🟢 someday

**Problem**: `.github/workflows/lint.yml` 的 shellcheck 步驟帶約 90 個檔案的 `ignore_names` 豁免白名單——絕大多數腳本實質未過 shellcheck；白名單靠人工維護、無 ratchet 票追蹤，且掛在 `test-skill-refine` 這個語意不相關的 job 底下。新增腳本若忘記處理，會無聲繞過靜態檢查。

**Why**: 與 [[CC-450]]（docstring ratchet）同型的「規則已立、backfill 未竟」狀態，但缺少 CC-450 那樣的顯式追蹤；白名單只增不減。

**Requirement**:
1. shellcheck 拆成獨立 CI job（脫離 test-skill-refine）。
2. `ignore_names` 白名單視為待清零 ratchet：逐批修檔、縮減白名單（比照 lint-test-docstrings 的 explicit-allowlist 收斂模式）；新腳本預設必須過 shellcheck，不得直接進白名單。
3. 修檔時沿用既有慣例：動態 source 帶 `disable=SC1091`；test 檔的 `tmp_root` 等跨檔變數帶 `SC2154`。

**Dependencies**: 無；規模大（~90 檔）故列 someday，逐版收割。與 [[CC-450]] 可共用「ratchet 進度 = allowlist 縮張」的機制敘事。
**Source**: 2026-07-06 盲測程式碼稽核（測試/CI 角度）。

## CC-011 — sync-memory.sh + 跨裝置共用（deferred；建議與 CC-012 合併實作）

**Problem**: `~/.claude/projects/*/memory/` 為本機路徑，多台電腦之間 memory 各自獨立，無法共用。
**Why**: 用戶目前不急，但設計上若以 symlink 指向 Dropbox/iCloud/OneDrive 資料夾，可以零維護代價實現跨裝置共用，且完全相容現有 file-based memory 架構。
**Requirement** (Phase 1): `scripts/sync-memory.sh --setup <cloud-path>` 把 memory 資料夾 symlink 到雲端同步路徑；`install.sh` 加入 opt-in 步驟。
**Phase 2**: CC-012 (SessionStart pull hook) — 兩者應同一 PR 實作，CC-012 無獨立實作價值。
**Status note (CC-050 audit 2026-05-18)**: Downgraded from ⏸ deferred to 🟢 someday — concept valid, no active plan. Re-evaluate if cross-device sync interest grows.

## CC-012 — SessionStart hook pull memory（deferred；建議與 CC-011 合併實作）

**Problem**: 若多台電腦透過 CC-011 共用同一雲端 memory 資料夾，session 啟動時不保證已取得最新版本。
**Why**: 輕量方式是 SessionStart hook 觸發一次 rsync/git pull，確保 memory 是最新版。
**Requirement**: `scripts/hook-sync-memory.sh` SessionStart hook；支援 git pull 和 rsync 兩種模式；失敗時靜默降級。
**Note**: 依賴 CC-011；建議與 CC-011 合入同一 PR（Phase 1 + Phase 2 同步落地，CC-012 無獨立實作意義）。
**Status note (CC-050 audit 2026-05-18)**: Downgraded from ⏸ deferred to 🟢 someday — depends on CC-011; no active plan. Re-evaluate together with CC-011.

## CC-015 — `systematic-debugging` skill

**Status note (CC-050 audit 2026-05-18)**: Downgraded from 🔵 active — no open branch. Re-activate when work begins.
**Problem**: debug 工作流目前無標準化流程，每次偵錯方式不一致，容易遺漏根本原因分析。
**Why**: 結構化偵錯步驟（reproduce → isolate → hypothesize → verify → fix → regression test）有助於複雜 bug 分析。
**Requirement**: `commands/systematic-debugging.md` slash command，提供結構化偵錯步驟。

## CC-018 — Codex quota 自動追蹤 + rate-limit 路徑統一（吸收 CC-269）

**Problem**: (A) CC-006 解決了 Claude 5h rate-limit 自動讀取，但 Codex 無等效 hook 機制；目前 Codex 使用量只靠 `log-usage.sh` 手動寫入，用戶無法即時得知剩餘額度。(B) CC-269（已合併）：`scripts/hook-save-rate-limits.sh` 寫到 `~/.claude/rate-limits.json`，與 claude-account-switcher 等工具衝突；pm-dispatch 不應寫入 `~/.claude/` 共用路徑。
**Why**: Codex 走 OpenAI API 路徑，quota 資訊需要主動查詢（response header 或 `/v1/organization/usage`），架構不同於 Claude StatusLine hook。rate-limit 寫入應集中到 pm-dispatch 自己的 state 目錄以避免多工具衝突。
**Requirement**:
1. 研究 Codex API response headers（`x-ratelimit-remaining-requests` / `x-ratelimit-remaining-tokens`）
2. 若有：`scripts/codex-dispatch.sh` dispatch 後解析 headers，寫入 `~/.local/share/pm-dispatch/state/rate-limits.json`（對齊 CC-230 state store）
3. 若無：呼叫 `/v1/organization/usage` 或記錄技術限制
4. `scripts/hook-save-rate-limits.sh` 改寫到同一 `~/.local/share/pm-dispatch/state/rate-limits.json`（Claude pool + Codex pool 合一），停止寫 `~/.claude/rate-limits.json`
5. 更新所有讀取 rate-limit 的腳本（doctor.sh、usage 相關、statusline consumers）
6. `token-usage.sh` 加入 Codex pool 剩餘顯示
**Note**: 實作前需先手動驗證 Codex API header 行為。CC-063 dashboard 之後可吃此 state，但不在本票範圍。

## CC-026 — `/skill-distill` 從重複工作流產出 skill

**Problem**: 重複的多步驟工作流（例：手動跑 `git checkout main && git pull && ./install.sh --dry-run && ./install.sh`、或某個 codex brief → 審查 → 修正的固定 5-step）目前需要 user 自己注意到「這個我做第三次了」才會手寫成 skill。沒有系統性偵測。
**Why**: 跟 CC-025 同一個 episode 層基礎建設；差別是 CC-025 改進「已有 skill」，CC-026 提議「新 skill」。優先序我建議在 CC-025 之後 — 等 episode 中 skill execution 標記成熟、`/skill-refine` 的 diff 提議流程驗證可信，再啟動偵測 + 產出。否則容易產生雜訊建議讓 user 必須一直拒絕。
**Requirement**:
1. `commands/skill-distill.md` slash command，介面：`/skill-distill [--dry-run] [--min-occurrences N]`。
2. 讀 `episodes.jsonl`，對工具序列做相似度聚類（例：tool name 的 n-gram、Bash command pattern）。
3. 若同樣序列在不同 session 出現 ≥ N 次（預設 3）且總長度 ≥ 5 步，產出草稿 `commands/<draft-name>.md` 並回報出處 episodes。
4. 預設 `--dry-run` 只印名稱與草稿 outline，user 確認後再寫檔。
**Note**: 依賴 **CC-027** 與 **CC-025**。順序：CC-027 訊號層落地 → CC-025 驗證單一 skill 改進迴路 → CC-026 才有足夠資料做序列聚類。
**Source**: 2026-05-15 對話討論 Hermes Agent self-improvement loop 與 pm-dispatch 的 gap 分析。

## CC-032 — `[[feedback_*]]` cross-link 公開化（dead-link 防護）

**Problem**: BACKLOG.md（含本次 CC-025..CC-030 新條目）多處引用 `[[feedback_undocumented_harness_payload]]`、`[[feedback_known_bug_backlog]]`、`[[feedback_codex_routing]]`、`[[routing_log]]` 等 — 這些 memory 檔**不在 repo 內**（在 `~/.claude/projects/<proj>/memory/`，純本地）。轉公開後，外部讀者點不開、不知道內容、cross-link 形同 dead link。
**Why**: 公開要兼容「沒有 user memory 的讀者」。兩條路：(a) 把這些 feedback rules 中真正屬於 repo 政策的部分抽到 `docs/policies/*.md` 並改 link 指向新位置；(b) 在每次第一次引用時 inline 引述兩三行。前者乾淨且可被 search engine 索引、後者侵入度低但容易過時。建議 (a)，配合 schema 規則：所有 BACKLOG 條目的 `[[name]]` 必須對應 `docs/policies/<name>.md` 存在。
**Requirement**:
1. 盤點所有 BACKLOG.md / docs/ 中 `[[feedback_*]]` 與 `[[*_log]]` 出現位置。
2. 把屬於「repo 適用政策」（非個人偏好）的 rule 抽寫至 `docs/policies/<slug>.md`，每篇含：摘要、原因、實作守則、reference。
3. 更新所有 `[[name]]` 改為 `[docs/policies/<slug>.md](docs/policies/<slug>.md)` 或 `[[<slug>]]`（若決定保留 wikilink 風格、配合 CC-030 validator 擴充驗證 link target 存在）。
4. 個人偏好類 feedback memory（不適合公開）留 local memory 不對外。
**Note**: 與 CC-030 schema validator 設計協同 — 可同 PR 加上「`[[name]]` link target 必須存在」的 validation。Blocks **CC-033**。
**Update 2026-07-04**: 進入 v1.0 P0（someday → active，P3 → P2；v1.0-rc 候選）。repo 已為 public，本票的 link-target validator 綠燈為 v1.0 hard constraint（公開讀者不可見 dead wikilink）；DECISIONS 2026-07-04（v1.0-public-roadmap-and-release-sequence）。
**Source**: 2026-05-15 對話 — 公開前置盤點 #3（Explore 未抓到的盲點）。

## CC-033 — Public flip checklist 與後續觀察

**Problem**: 完成 CC-031/CC-032 後，public flip 本身仍涉及多個 GitHub repo 設定決策（Issues 開關、Discussions 開關、template、labels、release tagging policy），需要明確 checklist 避免「按下 public 後才發現某設定不對」。
**Why**: 公開是 one-way door — 翻成 public 之後 commit history 全部對外（雖然 git history 已審 clean）；issue 也會公開。所以 flip 本身需要清單化，並決定先試水溫的 setting（Discussions only vs 全開）。
**Requirement**:
1. 決策清單：(a) Issues 開關（建議先關，僅 Discussions），(b) Discussions categories 規劃，(c) PR template，(d) release tagging（已有 1.1.0，是否設 GitHub Releases），(e) 是否加 CITATION.cff。
2. 觀察期：flip 後 2-4 週評估 — 若有有效 use case 出現再開 Issues。
3. Flip 動作本身為 1 行：`gh repo edit --visibility public`。
**Note**: 依賴 **CC-031**, **CC-032** 完成；本條為「最後一哩」與後續評估。
**Update 2026-07-04（rescope：flip 前提已過時）**: 2026-07-04 實測 `gh repo view` 確認 **repo 已經是 public**（`isPrivate: false`）——本票原「flip 前防護」框架失效，rescope 為 **public posture reconciliation**（v1.0 P0，DECISIONS 2026-07-04）：
1. **即刻 git history 損害盤點**（非 flip 前防護，是已曝光後的發現與處置）：原「git history 已審 clean」結論成於 2026-05-15，之後已累積 ~250 commits（含大量 dispatch trace / memory 路徑相關工作）——重掃 secrets、個人路徑、意外入 repo 的本機 artifact；發現即處置（rotate/清除/評估影響）。
2. **README posture 一致化**：README 仍寫 "private-maintainer scoped" 而 repo 實際 public——文案改為明確的「publicly readable personal distribution, not a public support contract」定位（或依 v1.0 宣稱調整），與 CONTRIBUTING（不收外部 PR、issue 無 SLA）對齊。
3. GitHub 設定決策照原 Requirement 1（Issues/Discussions/template/labels/CITATION.cff），時點改為 v1.0-rc；觀察期反轉為 v1.0.0 發佈後的觀察窗。
4. **README 使用者表面重建**（2026-07-06 盲測稽核追加）：README 只記載 15 個 command 中的 2 個（`/pm`、`/pr-gate`）、Agents 段缺 spike agent、Layout 段引用已不存在的 `settings/` 目錄且缺 `skills/`（install.sh 實際會接線）——commands/agents/skills 清單改為與實際目錄一致（可由 `commands/*.md` frontmatter description 派生），Layout 修正到與 install 行為相符。
someday → active，P3 → P2。
**Source**: 2026-05-15 對話 — 公開前置盤點 #4。

## CC-035 — install/uninstall-hooks basename+scripts/ collision edge case

**Problem**: install/uninstall hooks 目前以 basename + `scripts/` heuristic 判斷既有 hook 是否屬於 pm-dispatch，但另一個工具若也在 `scripts/` 下使用同名 hook，仍可能 collision。
**Why**: CC-034 修掉 full-path 比對造成的 append-not-replace bug，但 basename heuristic 仍不是完整 ownership model。
**Requirement**: 設計更明確的 hook ownership marker 或 install manifest，讓 uninstall/replace 只影響 pm-dispatch 自己寫入的 hook entry。
**Source**: CC-034 follow-up from PR #53.

## CC-038 — Windows / cross-platform locking primitive（deferred）

**Problem**: CC-037 用 `flock -x -w 2` 序列化 `hook-routing-log.sh` 的 append/rotation 路徑。`flock` 是 Linux util-linux 工具，Windows（純 PowerShell / Git Bash 無 util-linux）與 macOS（預設不裝 util-linux，需 `brew install flock`）都不能直接使用。除了 hook-routing-log，整個 `scripts/` 樹大量依賴 Linux-isms（GNU awk、GNU sed、`printf -v`、`procfs`、`/dev/null` 重導向細節等），整體 portability 是一塊待面對的工作面，不只這一支腳本。
**Why**: 使用者後續可能需要在 Windows 系統開發 / 跑 pm-dispatch（WSL 不算 native Windows）。在那之前，所有 Linux-only 依賴都是 latent block。CC-037 引入 `flock` 沒有惡化現況（其他 hook 已依賴大量 Linux-only 工具），但每多一個依賴點，將來 portability work 範圍就多一塊。現在不修不影響任何 Linux user，所以這是 latent / blocked-on-windows-demand 條目，不是 active bug。
**Requirement**: 任一方向皆可：(1) 抽象層 `scripts/lib/lock.sh`，依平台選 `flock` (Linux) / `shlock` (macOS 內建) / PowerShell `Mutex` 或 atomic file create loop (Windows)，hook 透過 wrapper 取得鎖；(2) Portable 替代：用 `mkdir`-based atomic locking 取代 flock，所有平台 portable，但需顯式 stale-lock cleanup；(3) 限制範圍：明確聲明 pm-dispatch 僅支援 POSIX（Linux + macOS via Homebrew util-linux），Windows 走 WSL2，寫進 `README.md` + `docs/platform-support.md`。
**Cross-link**: triggered by CC-037 implementation choice (flock). 不阻塞當前 release。所有 hook scripts (`hook-routing-log.sh`, `hook-tool-trace.sh`, `hook-codex-bash-guard.sh`, `hook-pm-write-guard.sh` 等) 共用同一個 portability 平面，啟動時應一次性盤點所有 Linux-isms。
**Source**: 2026-05-15 user 在 CC-037 收尾階段點出「之後可能需要支援 Windows」。

## CC-044 — `tool-trace.jsonl` reliability, retention, data-quality bundle（deferred；吸收 CC-027b + CC-027c）

**Current baseline (shipped in CC-027)**: 4 MiB single-archive rotation — when `tool-trace.jsonl` exceeds 4 MiB, it is renamed to `tool-trace.jsonl.1` (overwriting any prior `.1`) and a fresh main file is started. Retention semantics: "current file plus one overwritten archive". Constant-time stat check, non-blocking on rotation failure.
**Problem**: Three related reliability gaps in `tool-trace.jsonl` all feed the same downstream risk — skill-distill / skill-refine signals become unreliable if trace data is lossy or untrustworthy:
- (Phase 1) Single-archive baseline overwrites prior trace history on rotation; multi-window retention needed for longer post-hoc analysis.
- (Phase 2, absorbed from CC-027b) Append/parse/rotation failures are best-effort and audit-only; sustained failure degrades downstream CC-025/CC-026 signals with no visible warning.
- (Phase 3, absorbed from CC-027c) Brace-shaped malformed JSON (truncated mid-object) can pass the bash brace heuristic; inline `jq -e .` validation costs ~25ms/call, exceeding the per-call budget.
**Why**: The hook must stay non-blocking, but silent long-term degradation makes skill-refine/skill-distill signals unreliable. Addressing all three together avoids a partial-fix where Phase 1 lands but the health/validation layer lags.
**Implementation sequence** (can split into 3 PRs within the same epic):
1. **Phase 1 — multi-window retention**: upgrade from "current + one overwritten archive" to N rotated archives (gzip or daily archive dir). Include boundary/archive-integrity/non-blocking-failure tests.
2. **Phase 2 — health signal**: add bounded error counter for `tool-trace.jsonl` health; downstream commands (CC-025/CC-026) surface a warning when error count exceeds N. Keep hook non-blocking; cap health-state file growth.
3. **Phase 3 — async validation**: async post-validation path (append first, validate sampled fraction asynchronously, or move strict validation to downstream CC-025/026 consumer where 25ms/call amortizes over rare reads). Garbage line is data-quality concern only — no security vector.
**Activate when**: CC-025/CC-026 consumers are close to implementation and reliable trace data becomes load-bearing.
**Source**: 2026-05-15 CC-027 brief + PR-gate critic/arch/risk (rotation), risk-reviewer (health, CC-027b), critic+qa-tester (validation, CC-027c).

## CC-023 — `coupling-reviewer` PR gate 耦合分析（deferred）

**Problem**: PR gate 的 architecture-reviewer 依賴 Claude 主觀判斷耦合問題，沒有客觀量化基線。
**Why**: 量化耦合指標（afferent/efferent coupling、循環複雜度）可提供客觀基線；coca/dependency-cruiser/gocyclo 等工具已成熟。
**Requirement**: `scripts/coupling-check.sh` 語言偵測 + 工具呼叫，只分析 changed files；PR gate 加入可選 `--coupling` flag；閾值超過 → block-soft。
**Note**: 依賴 CC-022 建立設計評審文化後再推進。

## CC-045 — brief timeout heuristic + playbook-depth short-circuit（deferred）

**Problem**: Brief author 目前對 `timeout` 沒有明確啟發法 — 多半以 edit size 為單一估算依據。但 Codex 預設行為是先吃完整個 target repo 的 onboarding chain（AGENTS.md / rules/global / rules/domain / 跨 repo playbook docs）再動工。對 playbook 深的 repo 即使只改 ~10 行也會在 prelude 階段燒掉 200s+，超薄 timeout 直接 SIGKILL 在 research 階段。
**Why**: 2026-05-16 cross-session diagnostic — a deep-playbook target repo (rules/global + rules/domain + cross-repo playbook refs) ran a yml/md parity edit (~10 yml + 4 md lines mechanical sync) via codex-dispatch.sh `--timeout 240`, exit 124; trace showed 11 `command_execution` events all in doc-read phase (prompt-budget, cross-repo playbook docs, DECISIONS.md, project manifest, rules/global, rules/domain), zero edit-phase progress. **根因**：brief author 把「edit 14 行 ≈ 240s」推估時未把 playbook depth 算進去。
**Requirement**:
1. `docs/dispatch-brief.md` brief schema 文件加 `timeout` 啟發法 guidance：
   - flat repo（無 `rules/`、無 `AGENTS.md`、無 cross-repo playbook 連結）：mechanical edit 240–600s OK
   - shallow playbook（單一 `AGENTS.md` 或 `<10` 條 rules）：mechanical edit 600–900s
   - deep playbook（`rules/global` + `rules/domain` 或跨 repo playbook refs）：mechanical edit **最低 900s**；judgment-heavy（editorial / schema）1500s+
2. brief context 加可選短路 clause 模板：`"Constraints captured in this brief; do NOT re-read AGENTS.md / rules/ / playbook docs"` — 對 self-contained brief + mechanical edit 直接砍 5–10 個 read 命令。需在 `docs/dispatch-brief.md` 給範例。
3. （可選 / 第二階段）`scripts/codex-dispatch.sh` 啟動時偵測 `<working_dir>/rules/` 或 `<working_dir>/AGENTS.md` 存在且 `--timeout < 900` 時 emit stderr WARNING（不阻擋），surface author 設置錯誤於 SIGKILL 之前。
4. 觀察 N≥2 次 cross-session 重現後，promote 為 `feedback_brief_timeout_playbook_depth` memory（[[known-bug backlog rule]] + [[Codex routing preferences]] 衍生）。
**Source**: 2026-05-16 cross-session diagnostic — deep-playbook target repo dispatch exit 124 with 240s timeout, trace `.agent-trace/codex-20260516-193626-47431.jsonl`。
**Note**: 立即 workaround 是 brief author 對 deep playbook repo 預設 timeout=1500s；本條 ticket 是把這條 workaround 升級為文件化規則 + 可選 wrapper-side warning。
**Cross-link**: [[Codex routing preferences]] 路由表 / [[known-bug backlog rule]] 補登原則。

## CC-054 — CC-025 M2 `/skill-refine` diff generation（deferred）

**Problem**: CC-025 delivered the M1 read-only signal bundle and CC-025b closed the usage-guard plus `CLAUDE_MEMORY_DIR` contract follow-ups, but the original M2 scope for `/skill-refine` diff generation remains unimplemented.
**Why**: The useful product loop is not complete until the tool can turn skill feedback signals into a reviewable refinement diff. Closing CC-025b without a separate M2 tracker would make that deferred scope easy to lose.
**Requirement**:
1. Extend `/skill-refine` so it can generate a proposed diff for the target skill or command from curated memory/feedback signals.
2. Keep the default behavior review-first: emit the diff for user or main-thread approval rather than directly rewriting skill files.
3. Include Claude-assisted refinement guidance in `commands/skill-refine.md`, with clear dry-run and apply boundaries.
4. Add contract tests for diff-generation behavior and no-direct-write safety.
**Source**: PR #67 CC-025 M1 implementation and 2026-05-18 CC-025b closure decision in `feat/cc039-cc025b-v2`.

## CC-063 — [P2] Trace / token / gate metrics dashboard

**Problem**: `.agent-trace/*.jsonl`、`rate-limits*.json`、`.gate-results/*.md` 已積累豐富資料（per-session token、gate pass/fail、routing_log 校準記錄），但沒有視覺化介面；只能手動 grep。
**Why**: token 趨勢、gate 通過率、routing 準確度對長期 workflow 最佳化很有價值；資料已在，缺的是 consumer。
**Requirement**: `scripts/dashboard.sh`（或 HTML report）：讀取 `.agent-trace/*.jsonl` 統計 per-session input/output token；讀 `.gate-results/*.md` 統計 GO/NO-GO rate；讀 `routing_log/*.csv` 計算 Q1/Q2/Q3 準確度。輸出 terminal-friendly 摘要表。

## CC-064 — [P2] Project bootstrap wizard

**Problem**: 新 repo 接入 pm-dispatch 需要手讀 GETTING_STARTED.md、手跑多個指令（`setup-project.sh`、memory init、rules 建立、PM schema 建立）；沒有一鍵引導流程。
**Why**: 降低接入門檻是 OSS 擴散的關鍵；現有 install.sh 處理 Claude 工具安裝，但不處理「把 pm-dispatch 接入現有 project」的 onboarding。
**Requirement**: `scripts/setup-project.sh --init <project-path>` 互動式引導：建立 `.claude/memory/`、`rules/` 骨架、`pm/BACKLOG.md` 模板、`.gitignore` 追加 artifact paths；結束時輸出「下一步」checklist。

## CC-065 — [P2] Per-repo configurable gate pipeline

**Problem**: 所有 repo 共用同一組 reviewer（architecture-reviewer、critic、qa-tester、risk-reviewer、security-reviewer）和 tier 預設。某些 repo（如純文件、seed data）不需要 security-reviewer；某些高風險 repo 應強制 full tier。
**Why**: 目前唯一的調整方式是每次手動傳 `--targeted` 或 `--tier`，無法設為 repo 級預設值。
**Requirement**: `.pm-dispatch/gate.toml`（per-repo）支援設定 `default_tier`、`required_reviewers`、`skip_reviewers`；`scripts/pr-gate.sh` 讀取此 config 做為預設值（CLI flags 仍可 override）。

## CC-205 — `/pm` dual-executor planning + `--parallel-plan` mode（deferred）

**Problem**: `/pm` 目前固定走單一 executor（codex 或 claude），沒有辦法對高影響任務
取得兩個 planner 的獨立視角；routing 決策也是隱性的（PM agent 內部決定），無法從
command 介面顯式控制。

**Why**: 架構/跨模組/首次設計類任務，單一 planner 有盲點風險；兩個 planner 各自獨立
規劃再合成，等同 pr-gate parallel reviewer 模式在計劃階段的對應。顯式 `--executor`
flag 讓 routing 可見、可測試，與 pr-gate 介面對齊降低學習成本。

**Requirement**:
1. `/pm` 加 `--executor auto|codex|claude` flag（default: auto，行為與現行相同）
2. `dispatch_handover_v1` schema 加 `executor` 欄位，PM skill 與 pr-gate skill 共用
   同一 handover 解析路徑
3. PM agent instructions 加偵測規則：task 符合下列任一條件時，在 dispatch 前暫停並
   詢問用戶是否啟用 `--parallel-plan`：area 包含 arch/process/gate；task 涉及多個
   subsystem 的 interface 設計；task 是「首次設計 X」而非「改現有 X」
4. `--parallel-plan` mode：codex 與 claude 各自獨立 dispatch 同一規劃任務；兩份計劃
   完成後，current model（synthesis pass）整合為一份 best-of 計劃輸出給用戶
5. `/pm --parallel-plan <task>` 顯式 flag 跳過確認步驟，直接 parallel dispatch
6. 一般查詢維持背景執行（run_in_background）；有 checkpoint 需求時切前景

**Dependencies**: CC-200（executor-router.sh 共用 routing lib）、CC-059（thin pm.md
script-layer）、CC-202（handover validator framework）

**Acceptance criteria**:
- [ ] `/pm --executor claude <task>` 強制走 claude-only 路徑
- [ ] `/pm --executor codex <task>` 強制走 codex 路徑
- [ ] PM 偵測到 arch task → 輸出 checkpoint 訊息並等待用戶確認
- [ ] 用戶確認後 → codex + claude 各自規劃 → synthesis 輸出一份計劃
- [ ] `/pm --parallel-plan <task>` 顯式 flag → 直接 parallel dispatch，無 checkpoint
- [ ] `dispatch_handover_v1` block 含 `executor` 欄位，pr-gate skill 可解析同一格式
- [ ] 一般 `/pm <task>`（無 arch 特徵）維持背景執行，行為不變

## CC-209 — codegraph integration: pre-indexed context for Codex briefs（deferred）

**Reframed 2026-05-22**: this is now a **context-enrichment spike** — evaluate codegraph as the first source behind the `context-pack` abstraction (CC-232), not a direct `codex-dispatch.sh` flag. Runs as the first formal `/spike` in v0.3.0 M5. Requirement bullet 3 below (`--codegraph-enrich` flag on `codex-dispatch.sh`) is superseded by `pmctl context build --source codegraph`. See [`docs/architecture/v0.3.0-synthesis.md`](../docs/architecture/v0.3.0-synthesis.md) §9.

**Problem**: Codex briefs rely on manually-specified `files:` lists for context.
If the list is incomplete, Codex spends tokens exploring the codebase via grep/read.

**Why**: colbymchenry/codegraph (MIT, TypeScript, 9,475 stars, active May 2026) builds
a pre-indexed code knowledge graph for Claude Code / Codex / Cursor. Querying it before
dispatch could auto-supply relevant file context and reduce per-brief token cost —
aligned with pm-dispatch's core token-efficiency goal.

**Requirement** (investigation scope):
1. Understand codegraph install model (Claude Code plugin vs. standalone CLI).
2. Identify query API: what does a graph query return, and can it be embedded in a brief preamble?
3. Prototype: add optional `--codegraph-enrich` flag to `codex-dispatch.sh` that runs a
   codegraph query and injects top-N relevant file paths into the brief `files:` block.
4. Measure token delta on 3 representative briefs with/without enrichment.

**Priority**: P3 — non-urgent. Evaluate after v0.2.0 milestone closes.

## CC-211 — multi-CLI platform architecture（deferred）

**v0.3.0 epic** (updated 2026-05-22): umbrella epic for the v0.3.0 PM-runtime restructure. The original P0–P5 ordering below is **superseded** — see [`docs/architecture/v0.3.0-synthesis.md`](../docs/architecture/v0.3.0-synthesis.md) for the design breakdown (its **Conformance status** section tracks as-built drift; live numbering is **M0–M6** in `MILESTONES.md`, vs the §6 M0–M5 design cut) and `MILESTONES.md` v0.3.0 for ticket assignment. MCP (CC-216) and `adapters/antigravity`/`opencode` are deferred to v0.4.0; `adapters/codex` shipped in v0.3.0 (with claude).

**Problem**: pm-dispatch is currently framed as "Claude Code personal config + Codex dispatch
wrapper". As Codex CLI, Antigravity CLI, OpenCode, and other AI tools mature, this framing creates
coupling creep: hooks, adapters, and business logic intermingle because there is no enforced
boundary between the CLI-agnostic PM engine and each tool's delivery path.

**Why**: Re-framing pm-dispatch as an "agent-native PM orchestration toolkit" with explicit layer
boundaries allows any AI CLI to use the same PM system without forking logic. Guard engine,
dispatch state machine, reviewer policy, and schema definitions should be owned once.

**Requirement** (4-layer architecture, design scope):

| Layer | Path | Owns |
|---|---|---|
| `core/` | `core/schemas/`, `core/lib/` | PM schema, task/decision/review models, reviewer policy, dispatch state machine — zero CLI awareness |
| `runtime/` | `cli/pmctl` | `pmctl` CLI, dispatch runner, trace logger, guard engine, validator, report generator |
| `adapters/` | `adapters/claude/`, `adapters/codex/`, `adapters/antigravity/`, `adapters/opencode/` | Format conversion only; each adapter translates CLI-specific calls into `pmctl` invocations |
| `mcp/` | `mcp/pm-dispatch-server` | MCP tool bridge; any MCP-capable CLI (Claude Code, OpenCode, Antigravity CLI) shares one server |

**Key design rules**:
- `core/` never changes per CLI; no `~/.claude/` assumptions.
- Guard engine lives in `pmctl`; Claude hooks are one delivery path, not the definition.
- Adapters own zero business logic.
- `pmctl adapter generate <claude|codex|antigravity|opencode>` produces per-CLI config from core agent definitions to prevent 4-way drift.

**Priority order**: P0 extract `core/schemas/` (lock data format across CLIs) → P1 pmctl CLI (CC-215) → P2 Claude commands call pmctl → P3 Codex adapter formalised → P4 MCP server (CC-216) → P5 Antigravity/OpenCode adapters.

**Complements**: CC-059 (thin `/pm.md` script-layer), CC-215 (pmctl), CC-216 (MCP server).

**Priority**: P4 — long-term direction. Evaluate at v0.3.0 milestone planning.

## CC-212 — Windows junction install hardening: path-passing + idempotency（deferred；吸收 CC-213）

**Problem**: Two related hardening gaps in the Windows junction install surface — recommend same PR:
- **(A, original CC-212)** `make_junction_windows()` passes paths as inline PowerShell command-string arguments (`-Path '$win_src' -Target '$win_dst'`), but `remove_junction_windows()` already uses `PM_DISPATCH_RM_DST` env var. Paths containing single quotes break the inline form; the two-convention split increases maintenance risk.
- **(B, absorbed from CC-213)** `install_dir_junction()` idempotency logic uses `[[ -L "$dest_dir" ]]` + `readlink`, but PowerShell-created Windows directory junctions may not appear as `-L` in Git Bash. A second `bash install.sh` can therefore treat the junction as a real directory, fall back to per-file copy, and flush a manifest without the `junction` mode entry.

**Why**: Both issues were raised in gate-20260521-115634 as [medium] advise on PR #112. They share the same file surface (`scripts/install.sh` junction helpers) and the same root cause (Windows/Bash interop assumptions). One PR cleans up both cleanly.

**Requirement**:
- **(A)** Replace inline PowerShell path arguments in `make_junction_windows()` with `PM_DISPATCH_MAKE_SRC` and `PM_DISPATCH_MAKE_DST` env vars (matching `remove_junction_windows()` pattern). Update `test_install_dir_junction_manifest_entry` fake powershell.exe to assert both env vars.
- **(B)** Add a manifest-driven idempotency probe: before the `-L` check, read the existing manifest for the entry's `mode` field; if `mode == "junction"` treat the destination as an existing junction regardless of Bash `-L`. Add a focused test for the "manifest says junction, `-L` is false" branch.

**Complements**: CC-207 (parent), CC-214 (docs uninstall anchoring — optionally fold in).

**Priority**: P3.

## CC-216 — MCP server — pm-dispatch-server（deferred）

**Status (updated 2026-06-18)**: **DEFERRED — not assigned to any milestone.** Originally deferred to v0.4.0, then floated as v0.7.0 headline; 2026-06-18 user 拍板：不排入任何 milestone，待核心（executor 抽象 + retrieval/memory 基底，見 v0.7.0 retrieval epic）覺得**基本都穩定**後再考慮。MCP must wrap a stable `pmctl`, never an immature one. v0.3.0 was to ship only `mcp/README.md` defining the tool surface as a `pmctl` interface design constraint (AS-BUILT 2026-05-31: not written — `mcp/` absent; see synthesis Conformance status §B). See [`docs/architecture/v0.3.0-synthesis.md`](../docs/architecture/v0.3.0-synthesis.md) §5.4.

**Problem**: Each AI CLI (Claude Code, OpenCode, Antigravity CLI) needs separate command/hook wiring
to reach pm-dispatch. There is no universal bridge that works for any MCP-capable tool without
per-CLI adaptation.

**Why**: An MCP server exposes pm-dispatch operations as standard MCP tools, meaning any
MCP-capable CLI gets full PM access with no additional wiring. Adapters shrink to auth/config/
format differences only.

**Requirement**:
- Implement `mcp/pm-dispatch-server` exposing MCP tools:
  - `pm_list_tasks`, `pm_read_task`, `pm_create_task`, `pm_update_status`
  - `pm_add_decision`, `pm_request_review`, `pm_dispatch_to_agent`
  - `pm_read_trace`, `pm_guard_check`
- Implementation path: thin Node.js or Python wrapper over `pmctl` subprocesses (avoids
  duplicating logic), or native bash MCP server once spec stabilises.
- MCP becomes the universal bridge; adapters handle only auth / config / format differences.

**Depends on**: CC-211 (core layer), CC-215 (pmctl stable before wrapping).

**Complements**: CC-211 (architecture), CC-215 (pmctl as backend).

**Priority**: P4 within CC-211 roadmap. Evaluate at v0.3.0.

## CC-227 — refactor: extract yaml-frontmatter lib + shared validation helpers（deferred；吸收 CC-226）

**Problem**: `scripts/lint-frontmatter.sh` mixes CLI parsing, frontmatter boundary detection, and a ~150-line hand-rolled YAML subset parser in a single file. The parser logic (`check_frontmatter()`) has no stable call boundary, making it hard to reuse from other scripts (e.g., `doctor.sh` currently forks a subprocess to call the linter), hard to test in isolation, and hard to extend without touching the CLI script. Additionally (absorbed from CC-226), the 4 collection branches each repeat the same dq-escape whitelist regex and adjacent-quoted-scalar check, creating a silent parity-gap risk.

**Why**: User feedback after CC-058 gating. Doing both extractions together is the right call: the grammar contract becomes a first-class lib with clear ownership, and the shared helpers never diverge because there is only one call site.

**Requirement**:
1. Move `check_frontmatter()` and all YAML-subset validation helpers into `scripts/lib/yaml-frontmatter.sh`
2. Extract shared dq-escape/adjacent-quote/empty-entry helpers into the lib (eliminates the 4-branch repetition from CC-226); ensure a parity test or single call site prevents future per-branch divergence
3. `scripts/lint-frontmatter.sh` becomes a thin CLI wrapper that sources the lib
4. `doctor.sh` can optionally source the lib directly instead of fork-execing the linter
5. Tests can source the lib and call `check_frontmatter()` directly, reducing tmp-file overhead

**Acceptance**: `lint-frontmatter.sh` golden parity preserved; lib direct unit tests pass; `doctor.sh` optional source path verified.

**Dependencies**: CC-058 (lint-frontmatter rewrite — merged)

**Priority**: P3 — maintainability; not blocking current workflows.

**Cross-link**: CC-224 (hook-profile lib extraction — same pattern), CC-226 (merged into this ticket)

## CC-236 — pmctl report: away-from-keyboard state roll-up（someday）

**Deprioritized 2026-05-22**: the original "morning report" framing assumed unattended / overnight agent runs. In actual practice the maintainer does not run agents away from the computer, so a time-gap roll-up has low current need. Demoted from v0.3.0 M4 to `🟢 someday`. On-demand state queries are already part of the `pmctl` surface (CC-215); this ticket is specifically the *periodic / since-you-were-away* report.

**Problem** (conditional): if unattended or overnight dispatch ever becomes part of the workflow, there is no single command to see what happened while away.

**Why**: A read-only roll-up over the state substrate (CC-230) would answer that without hand-reconstruction. The idea is sound; the need is gated on a workflow change.

**Requirement** (if revived): `pmctl report` — open tasks, blockers, last gate verdict per active task, runs since last invocation. Read-only query over the CC-230 store.

**Revisit when**: the workflow includes overnight / away-from-keyboard agent runs.

**Cross-link**: CC-230 (state store), CC-211 (epic); AI Night Shift mapping — docs/architecture/v0.3.0-synthesis.md §5.3.

## CC-244 — Typed artifact pipeline: spike → brief → handover schema（someday）

**Premise**: spike documents today (we have one: `docs/spikes/CC-060.md`) are free-form prose. The brief-authoring step extracts decisions + handover fields from prose, which (a) costs PM tokens re-reading the spike, (b) loses invariant checkpoints (no `decisions_resolved=true` flag, so the next agent might re-ask resolved questions), (c) makes main thread inline the whole spike when courier-ing between agents.

**Design sketch**: define `spike_v1` schema mirroring the existing `dispatch_handover_v1`:

```yaml
---
spike_id: CC-060
status: phase_3_ready    # phase_1_raw | phase_2_synthesis | phase_3_ready
decisions_resolved: true
branch_base: origin/main@f905db7
ticket_ids_consumed: [CC-242]
project_tooling: {makefile: false, backlog_render_target: false}
---
## scope
## findings
## constraints
## decisions
## phase3_handover     # bridges directly to dispatch_handover_v1
```

Add `scripts/spike-validate.sh` (mirror `handover-validate.sh`) + `scripts/gen-brief-from-spike.sh` (mechanical extraction).

**Why deferred to someday, not active**: only one spike exists today (CC-060). Schema's leverage scales with N — for N=1 it's pure overhead. Defer until 3+ spike docs accumulate and the brief-extraction pattern repeats verbatim, indicating real automation value. CC-243's schema-key naming was chosen now so that upgrade to CC-244 doesn't re-wash field names.

**External reference (2026-07-07 openyida 跨專案分析)**: openyida 的 "generate-page" 產出物 manifest 模式（生成物本身攜帶 manifest 描述其結構，供後續 AI 編輯安全定位）是本票 `spike_v1`/`dispatch_handover_v1` schema 化構想的外部佐證之一——不改變本票的觸發條件（仍待 3+ spike 文件與 brief-extraction pattern 重複出現）。

**Trigger conditions to promote from someday → active**:
- 3+ spike documents under `docs/spikes/` with similar phase-1/phase-2/phase-3 structure
- Two consecutive brief-authoring rounds where PM essentially copy-pastes the same fields out of spike prose
- Or: an automation use case (e.g. CI-side spike-stage tracking) that requires structured spike state

**See**: CC-243 (snapshot fields already aligned).

## CC-253 — CC-209 Phase 2: codegraph benchmark on representative target codebase（active）

**Problem**: CC-209 Phase 1 spike (PR #151) returned `Verdict: AMBER` because pm-dispatch's bash + markdown stack is outside codegraph's supported language set; the index produced `0 files / 0 nodes` (correctly — pm-dispatch is the wrong test target for a code-context tool). Phase 2 (benchmark token + latency vs rg/git baseline per original CC-209 ticket) was gated on Phase 1 verdict; running it on pm-dispatch would produce uninformative numbers.

**Why**: codegraph's intended use is indexing a target codebase that codex/Claude is being dispatched **against** (e.g., the user's app under development), not indexing pm-dispatch itself (the orchestration tool). To produce a meaningful adopt/defer/reject verdict for CC-232 (context-pack source) + CC-237 (enricher baseline), Phase 2 needs a representative target in codegraph's supported language set (TypeScript / JavaScript / Python / Go).

**Requirement**:
- Spike brief MUST specify `test_target:` explicitly (per CC-255 brief template improvement): user picks a TS/JS/Python/Go codebase from `~/github/` at brief time; the brief commits the target path as a literal parameter so the executor doesn't have to guess.
- Index target via `codegraph index` (pre-existing v0.8.0 binary at `~/.nvm/.../bin/codegraph` per PR #151 evidence).
- Run 3 representative queries — pick from real briefs (e.g., a "find all callers of `<symbol>`" query, a "definition lookup" query, a "callgraph traversal" query).
- Baseline: `rg` + `git ls-files` returning equivalent file/symbol set.
- Measure: input-token proxy (`wc -c` on full files in baseline vs `wc -c` on codegraph-filtered subset), latency (`time`).
- Verdict: adopt (token saving > 50% with acceptable precision) / defer (insufficient signal) / reject (worse than baseline).
- Apply CC-255 spike-validation discipline: main-thread cross-checks claims (license, install path, output shape) against `gh api` + WebFetch independently before consuming the verdict.

**Acceptance**:
- `docs/spikes/cc209-codegraph-phase2.md` (or appended `## Phase 2` to phase1 doc) exists with 3 query benchmarks + verdict.
- Phase 2 brief commits to `test_target:` field per CC-255 template.
- Main-thread validation section appended per `[[feedback_spike_validation_mandatory]]`.
- BACKLOG CC-209 row flipped to `✅ closed` with final verdict after Phase 2 lands.

**Priority**: P3 — feeds CC-232 / CC-237 design, not blocking other work.

**Cross-link**: CC-209 (Phase 1 origin), `docs/spikes/cc209-codegraph-phase1.md`, CC-255 (template improvements this depends on), CC-232 (context-pack consumer), CC-237 (enricher consumer), `[[feedback_spike_validation_mandatory]]`.

## CC-259 — yaml.sh lib extraction（someday）

**Problem**: `_yaml_get` (bash/awk list extractor) and `case_yaml_parse` (structural validator) are currently inlined in `scripts/test-core-schemas.sh`. When a second test script needs YAML parsing, these helpers will be copy-pasted, diverging over time.

**Why**: Deferred from CC-229 M1 substrate PR to avoid expanding an already-large gate surface. The helpers were freshly written in CC-229 and have exactly one consumer; extraction before a second consumer exists is premature. Trigger for promotion: a new `test-*.sh` that needs to parse/validate YAML.

**Requirement**:
- Extract `_yaml_get` and `case_yaml_parse` into `scripts/lib/yaml.sh` (source-able, no side effects on load)
- Wire `scripts/lib/yaml.sh` into `scripts/test-core-schemas.sh` via `source` (replace inline definitions)
- Add `scripts/test-yaml-lib.sh` with independent unit tests for both helpers (cover key-found, key-missing, tab-indented, empty-file, no-key-line cases)
- Wire `test-yaml-lib.sh` into `run-all-tests.sh` and `.github/workflows/lint.yml`
- All existing test-core-schemas.sh cases must still pass (golden-parity)

**Acceptance**:
1. `grep -c "_yaml_get\|case_yaml_parse" scripts/lib/yaml.sh` ≥ 2 (both helpers present)
2. `grep -q "source.*lib/yaml.sh" scripts/test-core-schemas.sh`
3. `bash scripts/test-yaml-lib.sh` → exit 0
4. `bash scripts/test-core-schemas.sh` → exit 0
5. `bash scripts/run-all-tests.sh` → exit 0

**Milestone**: v0.3.x (post-M1); pick up when a second YAML-parsing test script is introduced.

**Priority**: P3 — no active consumer need today; purely technical debt prevention.

## CC-270 — test: concurrent pmctl adapter generate guard（deferred）

**Problem**: `pmctl_adapter_generate` precheck + `mkdir -p` + ERR trap sequence is not
atomic. Two concurrent calls with the same name can race: one failing run's trap removes
the other run's partial output.

**Blast radius**: Local generated adapter directory deleted. Reproducible by deleting
`adapters/<name>` and re-running `pmctl adapter generate <name>`. No persistent data
loss, no external side effects.

**Why deferred**: Single-developer workflow makes concurrent invocation unlikely. The
recovery path (delete and regenerate) is documented.

**Fix path**: Replace `[[ -d $adapter_dir ]] && die` + `mkdir -p` with an atomic
`mkdir "$adapter_dir" 2>/dev/null || die "adapter already exists: adapters/$name"`.
This makes directory creation the mutex.

**Dependencies**: None.

**Priority**: P3 — low probability, reversible.

---

## CC-273 — arch: unified lifecycle hook event spec（deferred）

**Problem**: CC-206 added `pre-gate.sh` / `post-gate.sh` hooks directly into `scripts/pr-gate.sh`. If future tools (e.g., `codex-dispatch.sh`, `brief-validate.sh`) also need hook points, each script will independently add its own pre/post blocks — resulting in inconsistent naming, invocation contracts, and user documentation.

**Proposed direction**: Define a shared lifecycle event spec:
- Convention: `.pm-dispatch/hooks/<event>.sh` (e.g., `hooks/pre-gate.sh`, `hooks/post-dispatch.sh`)
- Single call site in a helper (e.g., `lib/run-lifecycle-hook.sh <event>`)
- Consistent contract: runs from project root as main thread; non-zero aborts the triggering operation
- Single `docs/lifecycle-hooks.md` covering all events (supersedes the pattern docs in `sandbox-limitations.md`)

**When to activate**: When a **second** hook point is requested (not gate). Design cost before that point exceeds the benefit.

**Distinct from [[CC-391]]**: this ticket is about *tool-step lifecycle hook events* (pre/post-gate, pre/post-dispatch call sites in scripts) — a user-extensibility seam. [[CC-391]] is about *process lifecycle ownership* (who owns the executor subprocess after launch, durable result, notification). Same word "lifecycle", orthogonal concerns; do not merge.

**Cross-link**: `[[CC-206]]` (first hook point — gate pre/post), [[CC-391]] (process lifecycle — distinct axis)

**Priority**: P3 — no current requirement; activate when second hook point emerges.

---

## CC-104d — [Windows dogfood r1] hook-codex-bash-guard.sh hardcoded read-root ⏸ deferred

**Problem**: `hook-codex-bash-guard.sh:55` defaults read-root to `$HOME/github:/tmp`; repos under `~/Documents/github/` or arbitrary Windows paths are not covered. `CLAUDE_HOOK_CODEX_READ_ROOTS` env override exists but the wrong default silently restricts hooks.

**Scope clarification (2026-06-04, from CC-320 pr:#224 gate)**: the `$HOME/github` default is *only* consumed on the **codex-executor subagent PreToolUse path** where the env var is unset. The adapter/CLI dispatch path (`adapters/codex/dispatch.sh`) now always exports `<git_root>:/tmp[:inherited]` (CC-320), so the default is dead there. Do **not** "unify on `/tmp` only" — that would strip repo read access from the subagent path and break the common case rather than fix it.

**Fix direction — derive, don't hardcode**: replace `$HOME/github` with a derived repo root (e.g. `PM_DISPATCH_REPO` parent, or `git rev-parse --show-toplevel` of the hook's invocation cwd), keeping `/tmp` as the scratch baseline. *Alternative*, only if the codex-executor-as-subagent path is confirmed fully retired post-CC-299 (i.e. everything goes through the adapter which always sets the env): the default becomes near-dead code and may be reduced/removed — but verify that retirement first; do not assume it. Prefer fail-closed + explicit hint over silently defaulting to `/tmp` when no repo root can be derived.

**Cross-link**: [[CC-320]], [[CC-299]].

## CC-104e — [Windows dogfood r1] WSL ↔ Windows memory path divergence ⏸ deferred

**Problem**: Project ID is path-sanitized working dir. Same repo at `~/github/pm-dispatch` (WSL) and `C:\Users\...\github\pm-dispatch` (Windows) produces different IDs → memory is partitioned across environments.
**Fix**: Document workaround (symlink, or `PM_DISPATCH_PROJECT_ID` override); harness-level issue upstream.

## CC-104f — [Windows dogfood r1] jq hard-dependency in hooks layer ⏸ deferred

**Problem**: Hooks layer hard-depends on `jq`. Options: vendor static `gojq` binary (3 MB × 3 platforms), or expose `--no-hooks` install mode for jq-less users.
**Decision**: `--no-hooks` preferred — keeps no-auto-install principle.

## CC-104g — [Windows dogfood r1] portable.sh test fixes ⚠️ partial 2026-05-17

**Problem**: `mkdir_lock` FIFO sync passes ✅ but underlying `mkdir` on Git Bash allows second concurrent acquire — real Windows portability bug. See CC-104k for the UNC/9P root cause.
**See**: pr:#80

## CC-104j — [Windows dogfood r1/r2] test-dispatch-handover.sh symlink fixture on Git Bash ⏸ deferred

**Problem**: `brief_file_symlink_rejects_case` uses `ln -s` for fixture; on Git Bash falls back to copy → validator treats as regular file → test fails. Fix: add `[[ -L "$link" ]]` precondition → SKIP.

## CC-104k — [Windows dogfood] UNC/9P filesystem mkdir atomicity caveat ⏸ deferred（建議與 CC-104r 合併實作）

**Problem**: `mkdir` is atomic on local NTFS but NOT on `\\wsl.localhost\...` (9P UNC). Running pm-dispatch from a WSL UNC path on Windows breaks concurrent lock semantics.
**Fix**: Not a code bug — install-on-local-disk caveat. Fix is docs + preflight; see CC-104r for the implementation. **建議與 CC-104r 同一 PR 落地** — CC-104k 是問題分析，CC-104r 是 docs/preflight 修正，屬同一 caveat 的兩半。

## CC-104m — [Windows dogfood] Platform layout — multi-target projection ⏸ deferred

**Problem**: pm-dispatch is currently Claude-only by install.sh target. Introduce `~/.pm-dispatch/content/` as canonical view with symlink-project to `~/.claude/` and future tool targets.
**Scope**: Post-v0.1.0, deferred until Codex/Cursor/Aider integration need surfaces.

## CC-104r — [Windows dogfood r3] hook-tool-trace.sh performance budget on Windows ⏸ deferred（建議與 CC-104k 合併實作）

**Problem**: Actual: 27990 ms vs 3500 ms budget on WSL UNC path (9P is ~8× slower than local disk). Not a pm-dispatch code bug — physical filesystem characteristic of running pm-dispatch from `\\wsl.localhost\...`.
**Fix** (two-part — covers both CC-104r + CC-104k's caveat documentation): (a) `docs/platform-support.md` warn "install on local disk, avoid cross-WSL/native FS boundaries"; (b) preflight detects UNC path → prints warning and skips budget assertion (~10 lines). **建議與 CC-104k 同一 PR**：CC-104k 是問題根因分析，CC-104r 是 docs/preflight 落地，屬同一 caveat 的兩半。

## CC-104s — [Windows dogfood r3] hook-tool-trace.sh path normalization on Git Bash ⏸ deferred

**Problem**: `read_home_path_basename_only` case-glob fails on Windows backslash paths. Fix: normalize via `cygpath`/string-replace before case-match. Affects trace JSON observability only.

## CC-286 — [arch] pmctl: prefix-generic next-id derivation ⏸ deferred

**Problem**: `scripts/pm-prep-snapshot.sh` derives `backlog_next_id` for the `CC-` prefix only — it emits `CC-NNN` and scans BACKLOG.md + BACKLOG-ARCHIVE.md for the max `CC-` id. Other-prefix repos (JS-, PA-) are not handled; a generic next-id that only read the working-set index would also reuse archived IDs (the §2.2 hazard fixed CC-only in CC-284).

**Why**: pm-prep-snapshot is pm-dispatch-specific by design, so its CC-coupling is currently consistent (not a regression). But the cross-repo next-id belongs in `pmctl`, deriving the prefix from the target repo and scanning both the working set and the archive. Surfaced by pr-gate critic + architecture-reviewer on PR #186.

**Requirement**:
1. `pmctl` next-id: derive prefix from the repo's existing IDs (or config); compute max across BACKLOG.md + BACKLOG-ARCHIVE.md; `+1`.
2. Retire pm-prep-snapshot's CC-hardcoded derivation once pmctl provides next-id.

**Cross-link**: `[[CC-215]]` (pmctl core), `[[CC-282]]` (pmctl backlog), `[[CC-284]]` (working-set + the CC-only fix this generalizes).

## CC-306 — [arch] extend CC-233 layer enforcer to runtime-named data paths in scripts/ ⏸ deferred

**Problem**: CC-298 removed the current pr-gate runtime-named brief data paths, but the layer-boundary checks do not yet prevent a future script from reintroducing runtime-named data directories.

**Requirement**: Extend the CC-233 enforcer to catch `.codex-*` / `.claude-*` data directories under `scripts/` while keeping adapter-owned paths under `adapters/codex/` and `adapters/claude/` allowed.

**Why deferred / P3**: Optional defense-in-depth follow-up from CC-298; the implementation change is complete without strengthening validators in this ticket.

**Not done by CC-309**: CC-309's inverted layer-boundary test (`check_adapters_no_state_writes` in `test-layer-boundaries.sh`) forbids **adapters** from writing state directly — a different rule. This ticket's `.codex-*`/`.claude-*` runtime-named **data-dir** guard under `scripts/` is still unimplemented. (Corrects a v0.4.0 MILESTONES row that had conflated the two.)

**Cross-link**: `[[CC-233]]`, `[[CC-298]]`, `[[CC-309]]`.

## CC-342 — agent: debt-auditor — proactive tech-debt health scan on living code 🟢 someday

**Renumbered**: 原 CC-329；與 BACKLOG-ARCHIVE 已關閉的 FSM transition-table 票（✅ 2026-06-05）撞號，未開工的 debt-auditor 改號至 CC-342。撞號由 ticket-id lint 偵測，見 DECISIONS 2026-06-08。

**Problem**: 所有現有 reviewer（critic / architecture-reviewer / qa-tester）均以 PR diff 為觸發點，無法主動掃描 codebase 區域的技術債。結果是：重複程式、慣例分歧、過早抽象這類問題只有在 PR gate 中偶然被提及（以 `advise` 方式），沒有系統性的優先排序與追蹤。

**Why**: 技術債的最佳偵測時機是「任務之間」，而非「PR 審查中」。獨立的健康掃描 agent 在隔離 context 下讀取目標區域，不受正在進行的任務錨定，能給出客觀、可排序的債務清單，作為 milestone 規劃的輸入。

**Requirement**:
- `agents/debt-auditor.md` — agent 定義：
  - 輸入：目標路徑（目錄 / 模組 / glob），可選「關注面向」（duplication / conventions / tests / abstractions / all）
  - 流程：廣讀目標區域（Grep/Glob/Read）→ 識別 debt 項目 → 按 severity 與 fix-cost 排序 → 產出結構化報告
  - 輸出 YAML block（`debt_findings: [{severity, location, kind, issue, suggest, estimated_size}]`）
  - 不做任何修改，純讀取模式（tools: Read, Bash, Glob, Grep）
- `commands/audit.md` 或 `/audit` skill：呼叫 debt-auditor agent，結果由主線程摘要
- 定位為**新認知模式**（health assessment），有別於 PR-focused reviewer：
  - critic → diff 正確性（有 PR）
  - architecture-reviewer → diff 結構 fit（有 PR）
  - debt-auditor → 存活 codebase 的主動健康掃描（**無需 PR**）

**Non-goals**:
- 不執行修改（執行仍走 brief → executor → gate 路徑）
- 不取代 architecture-reviewer（PR gate 仍是 arch-reviewer 的地盤）
- 不做全 repo 掃描（target path 必須明確，避免輸出過大）

**Milestone**: `🟢 someday` — v0.5.0 candidate，與 CC-220 spike agent 同批考慮。

**Cross-link**: [[CC-220]], [[CC-239]], [[CC-338]], [[CC-237]].

---

## CC-346 — repo-index: cross-file ref tracking（file_refs layer，5 languages）⏸ paused 2026-06-10

**Problem**: `pmctl context query` 回傳 symbol + chunk hits，但看不出哪些檔案 import / source 了命中的模組。同一個 helper 被 10 個腳本 source，在 context hit 中卻像孤立的節點——dispatcher 不知道修改它的波及範圍，reuse-scan（CC-239）也無法辨識「這個 helper 已到處被用，不要再重複」。

**Why**: 加入 **import / source 解析層**（pure grep，無 AST），可以：
1. 讓 `pmctl context query` 在回傳 symbol hit 時附帶 `refs`（哪些檔案引用了它）
2. 讓 pr-gate blast-radius（CC-347）利用 ref graph 計算修改一個符號的實際影響檔案集
3. 讓 reuse-scan（CC-239）從「誰已在用這個 helper」推斷重用建議

架構上，這是 CC-338 repo-index 的第四張表，完全 optional（如無 CC-346 資料，CC-337/CC-239 fallback 到無 ref 模式）。不引入新的 binary 依賴。

**Requirement**:

*新增 SQLite 表*:
```sql
file_refs(id, from_id INTEGER REFERENCES files(id),
          to_path TEXT,        -- 被引用的 normalized 相對路徑（未必已在 files 表）
          ref_type TEXT,       -- source | import | require
          line_number INTEGER,
          resolved INTEGER)    -- 1 = to_path 已在 files 表；0 = unresolved
```

*語言支援（grep-only，無 AST）*:
| Language | 觸發模式 | ref_type |
|---|---|---|
| Bash / sh | `. <file>` 或 `source <file>` | source |
| Java | `import com.example.Foo;` | import |
| JavaScript | `require("./foo")` | require |
| TypeScript | `import ... from "./foo"` | import |
| Go | `import "github.com/.../pkg"` | import |

*增量更新*: `pmctl context update [path]` 執行後重新掃描受影響檔案的 ref 行；全量 `pmctl context index` 含 ref 掃描。

*查詢整合*: `pmctl context query` 在 `context_hit_v1` 回傳的 `refs` 欄位附帶直接引用者（to_path 命中的 from_id 集合），最多 5 條。

**Phase plan**:
- Phase a（MVP）: Bash `source` / `.` 解析，驗證 file_refs 表 + 增量更新
- Phase b: 加入 JS/TS `import` / `require`
- Phase c: 加入 Java `import` + Go `import`

**Acceptance**:
- `file_refs(from_id, to_path, ref_type, line_number, resolved)` table is created and populated by `pmctl context index` for at least the Phase a (Bash `source` / `.`) parser, with a fixture repo asserting resolved vs unresolved refs.
- `pmctl context update <file>` re-scans refs for a single file without a full rebuild.
- `pmctl context query` emits a bounded `refs` field (direct referrers) on hits; `LIKE`/`grep` fallback path tested.
- No schema migration breakage to the existing CC-338 `files` / `symbols` / `file_chunks` tables.

**Pause rationale（2026-06-10 arch review）**: 同日稍早曾以「reuse-scan 沒 ref 資料幫助有限」promote someday→P2，但 review 指出前提未驗證——reuse-scan 本身 ship 後（#256）操作面零 caller，給沒人用的工具加深資料層是加倍下注。先做 CC-356（接線 + 使用可觀測），用實際使用證據決定是否恢復本票。

**Resume trigger**: reuse-scan 輸出（經 [[CC-356]] 接線）實際進過 ≥2 份真 brief，且觀察到「缺 ref 資料」確為 reuse 建議品質的瓶頸。恢復時先只做 Phase a（bash source），不直上 5 語言。

**Milestone**: paused — 原排 v0.5.0 Phase 2；恢復後依當時 milestone 重排（depends CC-338 landed, CC-356 evidence）。

**Priority**: P3（promoted P3→P2 2026-06-10 早場，同日 arch review 改回 P3 + paused；見 DECISIONS 2026-06-10 scope-trim entry）。

**Cross-link**: [[CC-338]] (repo-index, parent table), [[CC-237]] (context_hit_v1 refs 欄位), [[CC-239]] (reuse-scan consumer), [[CC-347]] (blast-radius consumer), [[CC-356]] (wiring precondition).

## CC-347 — pr-gate: blast-radius analysis using cross-file refs 🟢 someday → v0.5.0 P3

**Problem**: 現行 gate 只審查 diff 內的檔案，但一個 Bash helper 或 schema 的改動，波及的是**所有 source 它的腳本**。gate 在不知道波及範圍的情況下做 risk review，等於盲目評估——risk-reviewer 無從判斷「修一行 state-writer.sh 是低風險還是影響 15 個腳本的高風險」。

**Why**: CC-346 的 `file_refs` 表提供了解析好的引用圖。在 gate brief 組裝時，對每個被修改的符號走一層 ref 圖，就能列出「直接受影響的未修改檔案集合」（blast radius）。這個資訊注入 brief 的 `context:` 節點，讓 risk-reviewer 和 security-reviewer 做有依據的 scope 評估。

**Requirement**:
- `scripts/pr-gate.sh` 在組裝 brief 前呼叫 `pmctl context query` 取得 diff 中每個變更符號的 `refs`
- 彙整成 `blast_radius` 清單：`{file, referenced_by: [path, …], ref_count: N}`
- 注入 brief `context:` 段落（`blast_radius_summary: N files directly affected outside diff`）
- 如無 CC-346 index（`file_refs` 表不存在或為空），此步驟靜默跳過（不阻擋 gate）
- risk-reviewer agent definition 補充：若 brief 含 `blast_radius` 節點，應審查 blast radius > 5 的符號改動

**Acceptance**:
- Gate brief for a change to a widely-sourced helper includes `blast_radius_summary`
- Gate brief for a repo without CC-346 index proceeds without error

**Milestone**: v0.5.0 P3（depends CC-346 Phase a）。

**Priority**: P3.

**Cross-link**: [[CC-346]] (data source), [[CC-338]] (repo-index), [[CC-237]] (context_hit_v1).

## CC-348 — pmctl project-map: cross-file dependency graph visualisation 🟢 someday

**Problem**: `pmctl context query` 回傳 per-query hits，但沒有辦法一眼看出 scripts/ 的整體引用結構：哪些腳本是「hub」（被大量 source），哪些是「leaf」（只被一個腳本 source），哪些 source 了不存在的路徑（broken refs）。這個結構對新貢獻者和 architecture-reviewer 都很有價值，但目前只能透過 grep + 手動追蹤推導。

**Why**: CC-346 的 `file_refs` 表一旦存在，project-map 就是一個純 SQL 聚合 + 格式化輸出的薄 CLI，無需額外的分析邏輯。輸出一份 text 或 dot 格式的引用圖，可直接貼進 PR 描述或 architecture review。

**Requirement**:
- `pmctl project-map [--format text|dot] [--from <path>] [--depth <n>]`
- `--format text`（default）: ASCII 樹狀列出引用鏈；indent 代表 depth
- `--format dot`：輸出 Graphviz DOT，可用 `dot -Tsvg` 渲染
- `--from <path>`：只顯示從指定檔案出發的子圖（單一起點 DFS）
- `--depth <n>`（default 3）：限制展開深度，避免 hub 節點爆炸
- 標示 broken refs（to_path 不在 files 表）
- 如無 CC-346 index，列印 `project-map requires CC-346 ref index; run: pmctl context index` 並 exit 1

**Non-goals**:
- 不生成 HTML / interactive graph（shell-only MVP）
- 不整合至 gate brief（那是 CC-347 的工作）
- 不解析 AST（依賴 CC-346 的 grep-level refs）

**Milestone**: `🟢 someday`（depends CC-346 Phase a+）。

**Priority**: P4.

**Cross-link**: [[CC-346]] (data source), [[CC-347]] (gate blast-radius consumer).

---

## CC-352 — codex-executor sandbox friction Pattern 1+2: apply_patch retry + Go module cache ⏸ deferred

**Context**: issue:#173 記錄了三種 codex-executor sandbox 摩擦模式。Pattern 3（git commit blocked — executor 回報 false partial）已由 CC-272 pr:#245 修復（brief template 移除 commit block，文件化主線程 commit delegation）。本票追蹤剩餘兩種。

**Pattern 1 — apply_patch 中途失敗 self-retry 噪音**

apply_patch 對大型或結構複雜的檔案可能失敗（patch 與當前檔案狀態不對齊）；codex 偵測後重讀檔案重試，通常第二次成功。噪音出現在 trace 中，加 1-2 min/次，且摘要顯示「non-fatal error in stderr」易被誤判為真實失敗。

Fix：brief authoring convention — 拆小 edit hunk，每段加 unique surrounding context 減少 patch ambiguity；可加入 codex-executor dispatch rules 文件。

**Pattern 2 — go build GOPATH copy 被 sandbox 擋**

sandbox 下 `cp -a <module-cache> /tmp` 被 workspace-write policy 擋；codex fallback 到 plain cp 或自行設 GOPATH，但需時 10-15 min/dispatch。

Fix：文件化 `GOPATH=/tmp/gopath go build` 慣例到 brief self_verify go build template，讓 codex 不需在 runtime 自行發現 workaround。

**Effort**: 兩者均為 pure doc/convention fix，無 code change。

**Priority**: P3 — 非阻斷性；Pattern 2 每次 go build dispatch 都出現，但有已知 workaround。

**Cross-link**: [[CC-272]] (Pattern 3 fix, pr:#245), [[CC-066]] (bash guard allowlist, relevant if Pattern 1 fix expands to allowlist approach).

**See**: issue:#173

---

## CC-333 — arch: pm-dispatch runtime 解耦合（v0.6.0 umbrella epic）🔵 active

> **v0.6.0 umbrella（2026-06-13 升格）**：本票為 v0.6.0「executor abstraction」milestone 的母 epic。主軸是「**新增第三個 executor = 放 `adapters/<name>/` + 一份 manifest，核心零改動**」，用 opencode + Antigravity 兩個真 adapter 落地當驗收。執行子票對應下方七層耦合：
>
> | 層面 | v0.6.0 子票 |
> |------|------------|
> | 2/3/6（hook 機制 / 設定格式 / dispatch 路由與術語） | [[CC-372]] runner-kind manifest → [[CC-373]] router 資料驅動 → [[CC-374]]/[[CC-375]] guard 收口＋安裝接線 |
> | 6（adapter 證明） | [[CC-376]] opencode、[[CC-377]] antigravity(`agy`) |
> | deprecation（runtime-coupling cruft 移除：`--profile`、`codex-dispatch.sh` shim） | [[CC-335]] |
> | 1/4/7（memory 路徑 / 安裝路徑 / reviewer memory 讀取） | **延後 v0.7.0+**（本版不處理；見 MILESTONES v0.6.0「延後」段） |
>
> 註：MCP（[[CC-216]]）為「通用橋」，邏輯上是 executor 抽象之後的下一層，**defer 至 v0.6.0 之後**（2026-06-13 user 拍板）。

**Problem**: pm-dispatch 在設計上以 Claude Code 為唯一執行環境，導致七個層面的硬耦合。目前任何想換 runtime（或在不同 AI CLI 環境使用）的嘗試，都需要手動繞過大量 Claude-specific 假設。

**Why**: pm-dispatch 的核心價值（dispatch brief 契約、PR gate review pipeline、policy enforcement、state store）與「執行在哪個 AI 上」理論上無關。但目前 memory 路徑、hook 機制、設定格式都直接假設 Claude Code。把這些降為 adapter layer 後，系統才能真正 runtime-agnostic，也更容易測試和移植。

**耦合清單（audit 2026-06-07）**：

| 層面 | 具體耦合 | 代表檔案 |
|------|---------|---------|
| 1. Memory 路徑 | `~/.claude/projects/<claude-project-id>/memory/` 硬寫在 agent 指令與 docs | `agents/project-pm.md`, `agents/critic.md`, `agents/architecture-reviewer.md`, `commands/mem-*.md` |
| 2. Hook 機制 | PreToolUse / PostToolUse / SessionStart / SessionStop 是 Claude Code 特有 primitive | 所有 `scripts/hook-*.sh`, `scripts/install-hooks.sh`, `docs/CONCEPTS.md` |
| 3. 設定格式 | `~/.claude/settings.json` 結構（`.hooks.PreToolUse[]` 等）與 Claude Code 版本綁定 | `scripts/install-hooks.sh`, `scripts/doctor.sh`, `scripts/test-install.sh` |
| 4. 安裝路徑 | `~/.claude/` 作為所有 assets 安裝目標（雖有 `CLAUDE_HOME` override，但 fallback 仍 Claude-specific） | `install.sh`, `uninstall.sh`, `scripts/install-hooks.sh` |
| 5. Env var 前綴 | `CLAUDE_HOOK_*` / `CLAUDE_CONFIG_DIR` 前綴（CC-321 已完成重命名 `CLAUDE_HOOK_*` → `PM_HOOK_*`；shims 至 v0.5.0 移除） | `scripts/hook-*.sh`, `scripts/lib/memory.sh` |
| 6. Dispatch 術語 | `dispatch_handover_v1` 區塊格式、`Agent tool` 呼叫約定、`claude --print` CLI 假設 | `docs/dispatch-brief.md`, `adapters/claude/dispatch.sh`, `commands/pm.md` |
| 7. Reviewer memory 讀取 | Reviewer agents 直接讀 `~/.claude/projects/<id>/memory/` 而非透過 handover brief | `agents/critic.md`, `agents/architecture-reviewer.md`, `agents/risk-reviewer.md`, `agents/security-reviewer.md` |

**解耦合方向（供後續拆票參考）**：

- **層面 7（最小代價，最高收益）**：Reviewer agents 移除直接 memory 路徑引用；改由 PM 在建 handover brief 時 embed 相關 memory 內容至 `project_memory:` 欄位，reviewers 只讀 brief。
- **層面 5**：CC-321 已完成（2026-06-08）。`PM_HOOK_*` 已取代 `CLAUDE_HOOK_*`，shims 至 v0.5.0 移除。
- **層面 4**：`CLAUDE_HOME` override 已存在，補齊所有 bypass-door 後降為 pure adapter 設定。
- **層面 1**：引入 `PM_MEMORY_DIR` env var；PM agent 讀寫由 env 指定路徑，預設仍 `~/.claude/...` 但可 override。
- **層面 2/3**：Hook 機制是 Claude Code 深度 primitive，短期不可能完全抽象；目標是把 hook 邏輯（guard policy）從 Claude hook event 格式中抽出，讓 policy 可獨立測試，hook 僅作為 trigger adapter。
- **層面 6**：`dispatch_handover_v1` 格式是 internal contract，重命名後可 rename 為 `pm_dispatch_handover_v1`；`claude --print` 已封裝在 `adapters/claude/dispatch.sh`，不需大改。

**Non-goals**: 本票不追求「完全不依賴 Claude Code」——Claude 仍是主要執行環境。目標是「核心 workflow 不假設 Claude-specific 路徑與機制」，降低移植成本與測試複雜度。

**Dependencies**: [[CC-321]]（env var 重命名，應先於本票任何 hook 相關子票）。

---

## CC-340 — knowledge index: standalone FTS over memory/backlog/decisions ⏸ deferred (SUPERSEDED by [[CC-403]])

> **SUPERSEDED 2026-06-18**: the out-of-repo memory-card / episodes indexing + standalone full-text ranking MVP is now owned by **[[CC-403]]** (`pmctl context --source memory`, retrieval epic, v0.7.0). CC-340 is retained only as the **embeddings / semantic-backend remainder** (Khoj-class accelerator) that CC-403 explicitly leaves out of its MVP; resume only if FTS5/LIKE ranking proves insufficient in practice. The anchored-TOC slice already shipped as [[CC-354]] (v0.5.0).

**Problem**: The repo index (CC-338) covers the code plane ("where to change, what to reuse"), but the second-brain plane — "why, how was this decided, what failed before" — has no structured search backing the context-pack. `/mem-search` exists as a skill but is keyword/grep over files, not an index with ranking or trust tiers.

**Why**: knowledge and repo are two different search planes with opposite lifecycles (curated/durable vs derived/rebuildable). v0.5.0 ships the repo plane + the shared interface (CC-237). The **anchored-TOC slice** of the knowledge index (per-section chunking of in-repo knowledge docs — enough to make the read side usable; memory-card indexing explicitly excluded) is pulled forward to **CC-354** (v0.5.0 Phase 2), because without it the knowledge plane has no queryable index at all. CC-340 narrows to the **heavy remainder**: standalone full-text ranking, embeddings, and low-trust episodic chunking — deferred to v0.6.0, overlapping the existing `/mem-search` surface.

**Requirement** (v0.6.0 — remainder after CC-354):
- Full-text ranking over wiki + episodes.jsonl (low-trust episodic chunks) beyond the anchored TOC CC-354 delivers.
- Embeddings / semantic backend (optional accelerator — Khoj-class).
- Richer trust-tier ranking (curated > wiki > backlog body > episode > raw event) and recency vs durability weighting.

**Non-goals**:
- Rewriting memory cards or making SQLite the source of truth (canonical stays the Markdown / JSONL).
- Replacing `/mem-search` UX before the index proves out.

**Milestone**: v0.6.0 — symmetric to CC-338; the usable slice is CC-354, this is the heavy remainder.

**Priority**: P3.

**Cross-link**: [[CC-354]] (anchored-TOC slice, pulled forward), [[CC-338]] (repo-index counterpart), [[CC-237]] (shared interface), [[CC-234]] (memory v2 write side), [[CC-232]] (pack schema), [[CC-403]] (supersedes the memory-index MVP).

## CC-355 — knowledge index: HTML semantic chunking（`<h1-6>` sections）🟢 someday

**Problem**: CC-354 chunks knowledge files by a per-format strategy — markdown by `^#{1,6}` headings, txt/other by line windows. HTML files fall back to window chunking, which loses their real section structure (`<h1>..<h6>` headings carry the same human-authored semantic anchors as markdown headings).

**Why**: HTML is structurally symmetric to Markdown (`<h1-6>` ≈ `^#{1,6}`), so it deserves heading-based chunking for the same retrieval quality. It is split out of CC-354 because robust HTML parsing in bash/grep is its own concern (nested tags, attributes, comments, `<pre>`/`<code>` blocks, entity decoding) and there is no `.html` knowledge source in the repo today — this is forward-looking generality, not a current need.

**Requirement** (when an HTML knowledge source appears):
- Plug an `html` strategy into the CC-354 per-format chunker seam: split on `<h1>`..`<h6>`, use the (tag-stripped) heading text as the chunk heading, strip tags for the lead.
- Add an `html`/`htm` branch to `_ctx_detect_language` and to the index scan `find` list (deferred from CC-354).
- Handle the parsing edge cases (comments, `<pre>`/`<code>`, entities) or document the known-fragile boundaries.
- Reuse the existing `file_chunks` columns; no schema migration.

**Acceptance**:
- An `.html` fixture with `<h1>` / `<h2>` sections produces one `file_chunks` row per heading, with tag-stripped heading text and correct `line_start` / `line_end` anchors.
- Comments, `<pre>` / `<code>` blocks, and HTML entities are handled per a stated rule (either correctly parsed or explicitly documented as a known-fragile boundary with the observed behavior).
- `pmctl context query` returns the right `<h2>` section ref for a query matching that section's heading.

**Trigger**: a real `.html` file enters the knowledge plane, or a consumer needs HTML-section retrieval.

**Priority**: P3.

**Cross-link**: [[CC-354]] (per-format chunker seam this plugs into), [[CC-340]] (knowledge index family).

## CC-357 — skill as contract: machine-readable schema for skills

**Problem**: `skills/` 下的所有 skill（目前 `dispatch-brief`、`pr-gate-review`）都是純 markdown prose 的 `SKILL.md`。沒有任何機器可讀欄位定義：輸入型別是什麼、輸出格式是什麼、允許/禁止使用哪些工具、什麼狀態算「完成」。這和 brief 的狀況一模一樣——brief 在引入 `dispatch_handover_v1` schema + `brief-validate.sh` 之前，也是純 prose，無從驗證。

**Why**: pm-dispatch 的 brief 已有明確契約（`dispatch_handover_v1` schema、`brief-validate.sh`、`pmctl validate brief`），任何 malformed brief 都在 dispatch 前被機器攔截。Skill 卻沒有對等機制——skill 的「輸入是什麼」、「輸出格式是什麼」、「需要什麼工具」完全靠人讀 prose 理解，沒有驗證層。長遠而言，skill 越來越多後，這個缺乏 contract 的問題會重演 brief 的問題：caller 不知道 skill 期待什麼、skill 產出什麼格式的東西、skill 用了哪些工具。

**Core idea**: 給每個 skill 一份 machine-readable 描述，使 skill 能被驗證、被自動發現、被工具限制強制執行。參考 `dispatch_handover_v1` 的設計哲學：不是要限制創意，而是讓機器可以在 skill 被呼叫前/後做檢查。具體欄位設計留待實作期規劃，可能的方向：
- `input:` — skill 接受的 arguments/context 型別
- `output:` — skill 保證產出的格式（e.g. `dispatch_handover_v1 block`、`gate_verdict`、plain text）
- `tool_constraints:` — 允許/禁止哪些工具（與 guard.sh 的 role-based policy 互補）
- `completion_condition:` — 什麼算完成（observable state，不只是「模型說完了」）

**Non-goals**: 不重新設計 skill 執行機制；不要求現有 skill prose 消失（schema 是 complement，不是 replace）；不在此票做 validator。

**Milestone**: someday（無里程碑排期，概念票）。

**Priority**: 未定（someday）。

**Cross-link**: `dispatch_handover_v1` (brief contract analogue), `brief-validate.sh` (validator pattern), [[CC-215]] (pmctl validate surface), `skills/dispatch-brief/SKILL.md` + `skills/pr-gate-review/SKILL.md` (first candidates).

## CC-358 — runner telemetry: evaluate with real runs — success rate / failure pattern / fallback analysis

**Problem**: `events.jsonl` 已有每次 run 的完整生命週期原料（`run.pending` → `run.dispatched` → `run.verifying` → `run.ok`/`run.failed`），但目前沒有任何 consumer 分析這些資料。結果是：每次任務成功或失敗都只是一次性觀察，不會累積成任何可查詢的分佈。PM 無法知道「這類任務 codex adapter 的成功率如何」、「最常見的失敗原因是什麼」、「fallback 到 claude 的頻率有多高」——所有路由和 recovery 決策都靠直覺。

**Why**: pm-dispatch 的核心價值主張之一是「減少浪費」，但沒有 runner telemetry 就無法衡量浪費在哪裡。目前有三個決策點完全沒有資料支撐：
1. **Adapter routing**（codex vs claude）：根據什麼選？主觀猜測。
2. **Recovery strategy**（失敗後 retry 還是 fallback）：沒有失敗模式分佈，無從判斷 retry 有沒有意義。
3. **Runner diversity**（要不要支援第三個 adapter）：沒有現有 adapter 的成功率資料，無從判斷值不值得。

本票的核心理念：**用自己的任務歷史來驅動自己的決策**——events.jsonl 是現成的 telemetry 原料，缺的是分析層。

**Core idea**: 在現有 events 原料上建立 `pmctl run-stats`（或類似 subcommand），提供：
- Per-adapter 成功率（成功/失敗/超時 分佈）
- 依 goal 分群的失敗模式（常見失敗在哪類任務？）
- Fallback 觸發頻率和觸發原因
- 時序趨勢（最近 N 次 vs 歷史整體）

**Non-goals**: 不做 ML 分類；不做實時 dashboard；不改 events.jsonl schema（用現有欄位）。分析是離線/按需，不是自動觸發。

**Resume trigger for related tickets**: 本票的觀察結果是 [[CC-346]]（cross-file ref）resume 的補充證據，也是任何 runner diversity 票（multi-vendor adapter）的前置條件——先看數據，再決定要不要加第三個 adapter。

**Milestone**: v0.9.0 候選（v1.0 P1 證據層；DECISIONS 2026-07-04）。

**Priority**: P2。

**Update 2026-07-04（someday → active；具體 DoD）**: v1.0 的「穩定性有證據」承諾以本票為 reader——release 宣稱不能只靠「最近沒炸」。DoD：
1. `pmctl run-stats --since <date> --by-adapter [--json]`：統計 dispatch/gate terminal outcome 分佈、post-verify failure、missing terminal event、adapter nonzero exit、fallback 使用次數。
2. 不做 dashboard（[[CC-063]] 維持 deferred）；先有 reader 與可引用的報告。
3. RELEASE_CHECKLIST 新增證據項：「v1.0 rc 期間至少 N 次真實 dispatch/gate 有統計報告、無未解釋的系統性 failure」；v1.0.0 release notes 附 run-stats 報告。

**Cross-link**: `events.jsonl` (data source), `pmctl trace tail` (existing consumer, read model to build on), [[CC-234]] (write side of memory loop — episodes 可補充 events 的語意), [[CC-346]] (paused; needs CC-356 evidence first, this ticket adds more evidence dimension).

## CC-359 — backlog-driven batch dispatch with worktree isolation（concept）

**Concept**: pm-dispatch 自己管理 `git worktree` 生命週期，讓多個 executor worker 在各自隔離的 filesystem workspace 平行處理 backlog task。不依賴任何特定 executor 的 platform feature——worktree 管理是 pmctl 的責任，不是 codex 或 claude 等 executor 的責任。

**Design principles**:

- **Executor-agnostic worktree management**: `git worktree add <path> -b agent/<task-id>` / `git worktree remove <path>` 由 pmctl 負責，codex 和 claude 都能在各自的 worktree 裡跑，不依賴特定 executor 的 isolation 機制。
- **Human-in-the-loop**: batch dispatch 後 merge 決策仍在人這邊，無 auto-merge，PR-only 原則不變。
- **衝突可觀測不禁止**: 以 BACKLOG `area` 欄位做粗粒度衝突分組——同 area task 排隊不並行；不同 area 可平行。不做逐檔 conflict detection（成本高且在 brief 寫完前無法計算）。逐 PR review 和 rebase 流程處理邏輯衝突。
- **PR-only output**: 每個 task 在各自 worktree 產出 commit + branch + PR，由人統一 review 和 merge。

**Suitable tasks for parallel dispatch**: 測試補強、文件補強、小 bug 修復、CLI option 補齊、error message 改善、backlog spike/survey。不適合：架構核心大改、schema breaking change、多個 task 改相同核心介面。

**Token budget as scheduler input**: 可設 `--budget low/normal/aggressive` 控制並行度（worker 數、adapter 選擇、是否使用 Opus）。

**Priority reasoning**: 需要 memory loop 完整落地後，才能有足夠的 context substrate 讓 batch dispatcher 智能分派任務。無固定里程碑——後續視工作流需求與 backlog 積壓情況決定是否優先。

**Non-goals for this concept ticket**: 不設計具體 subcommand syntax 或 schema——那是 implementation ticket 的工作；本票只記錄理念和約束。

**Cross-link**: [[CC-358]] (runner telemetry — batch dispatcher 的決策依據), [[CC-346]] (paused), `git worktree` (stdlib, no new dependency).

---

## CC-364 — perf: `pmctl trace tail --all` per-event jq spawn（deferred）

**See**: pr:#270

`pmctl trace tail --kind <kind> --all --json` is O(n) with a high per-event constant — measured ~20s for 338 events (~60ms/event), consistent with spawning a `jq` (or equivalent subprocess) per event rather than a single streaming pass. Discovered while diagnosing the #270 context-telemetry test flakiness: `context.queried` / `context.reuse_scanned` events accumulate in a partition, and the readback assertions called `trace tail --all`, so reads degraded as the partition grew. The tests were de-coupled from this — context telemetry now honors `PM_DISPATCH_STATE_ROOT`, so the suite isolates all state into a throwaway root — leaving this as a standalone reader-performance follow-up, not a blocker. Fix: rework `trace tail` filtering/serialization as a single `jq` pass (or a streaming reader) over `events.jsonl`.

## CC-431 — test-e2e.sh + release-verify.sh: opencode adapter support 🔵 active

**Problem**: `test-e2e.sh` 和 `release-verify.sh` 的 `--adapter` 旗標只接受 `claude|codex|auto`；opencode adapter 在 v0.6.0 加入後，e2e 驗證路徑從未同步更新。執行 `release-verify.sh --e2e --adapter opencode` 直接 exit 2 被拒。

**Why**: opencode 是已支援的 first-class adapter（`adapters/opencode.sh` 存在、Phase 3b smoke 通過），但無法用它做完整 e2e release sign-off，是驗證覆蓋度的缺口。

**Requirement**:
- `test-e2e.sh` 的 `--adapter` 驗證清單改為從 `adapters/` 目錄動態派生（對照 dispatch adapter 清單），不再維護獨立硬碼清單；新 adapter 加入後自動生效
- Phase B dispatch 路徑直接用 dispatch 既有 adapter 路由，無需在 e2e 層另做判斷
- Phase C（pr-gate smoke）若仍需限制 executor（如僅 codex），在不支援的 adapter 下改為 SKIP 並說明，而非 exit 2
- `release-verify.sh` 同步移除 `--adapter` 硬碼驗證，改走相同派生路徑

**Acceptance**:
- `release-verify.sh --e2e --adapter opencode` 不再 exit 2；正常執行或在已知限制處 SKIP
- 新增 adapter 後無需修改 test-e2e.sh 驗證清單即可自動支援
- Phase B opencode dispatch 可通過

**Trigger**: `release-verify.sh --e2e --adapter opencode` → `exit 2: --adapter must be claude|codex|auto` (2026-06-30, v0.7.1 release sign-off)

**Priority**: P2（v0.9.0 候選）.

**Update 2026-07-04（someday → active）**: v1.0「executor stable = codex/claude/opencode」宣稱的證據前置（DECISIONS 2026-07-04 P1 證據層）——release 驗證從未跑過第三方 adapter 是 executor-agnostic 宣稱的實質漏洞。若本票 e2e 未過，v1.0 文件須把 opencode executor 降標 experimental（不可與 codex/claude 並列 stable）。Phase C pr-gate smoke 若 reviewer pipeline 僅支援 codex，文件化為「gate executor codex-only」而非 SKIP 靜默。

**See**: pr:#339

## CC-435 — poll→通知機制 single-waiter guard：條件觸發，非既定後續票 🟢 someday

**Problem**：`docs/spikes/CC-433.md` 判定 poll→通知機制遷移為 AMBER——mkfifo blocking read 技術可行且延遲大幅改善，但發現並發 waiter 讀同一個 fifo 會造成 byte-level 資料損毀的正確性風險（輪詢設計沒有這個問題）。CC-434 實作完成後與使用者進一步討論了兩個候選防護設計，重新盤點成本效益後決定不排入既定實作。

**Why**（盤點結論，決定本票只在條件觸發時才啟動）：
- **資源消耗**：輪詢（`sleep 2s` + `stat()`）與 blocking read 在「一個 run/gate 對應一個 waiter、等待數分鐘到數十分鐘」的實際用量下，差距趨近於零——兩者都是「睡眠中不耗 CPU」等級，不構成採用理由。
- **延遲精度**：唯一有意義的量化差異是輪詢最多晚 2 秒才發現完成，listener 近乎即時；但這個延遲對「人在等 PR gate/dispatch 結果」的使用情境無感，不是使用者能察覺的體驗差異。
- **複雜度／風險**：兩個候選設計都要在安全敏感的 supervisor 檔案（`dispatch-supervisor.sh`/`gate-supervisor.sh`）與 wait 端引入新的 race condition、新的清理責任、新的測試面，投資報酬率不足以證成這個複雜度。

**Requirement**（候選設計草稿，僅供未來觸發條件成立時起步，非本票立即要做的規格）：
- **方案 A**：對 sentinel 的 `.waitlock` 檔案做 `flock -n` 搶排他鎖；搶到鎖的 waiter 走 mkfifo blocking read 快速路徑，搶不到鎖的 waiter 安全退回既有輪詢（`detached_launch_wait_for_sentinel`），不去碰 fifo。需補上「拿到鎖後、mkfifo 之前先檢查 sentinel 是否已存在」的 TOCTOU 修正（supervisor 搶先完成的情況）。`detached_launch_write_sentinel` 需加一段 best-effort 廣播（fifo 存在才嘗試非阻塞寫入，失敗不影響檔案寫入這個唯一正確性來源）。
- **方案 B**：每個 waiter 建立自己專屬的 fifo（不共享），supervisor 完成時掃描一個註冊表目錄、逐一廣播寫入每個已註冊 waiter 的 fifo。沒有任何 waiter 需要退回輪詢，代價是要處理註冊 race（同樣用 TOCTOU 檢查解）與殭屍 fifo 清理（比照現有 `pmctl_dispatch_wait` key file 靠 tmpwatch 回收的先例，不影響正確性）。

**Done-when**：僅在觸發條件成立（見下）後才需要收斂 Done-when；屆時應包含至少 3 個新測試案例：兩個以上 waiter 同時等待同一個 run_id/gate_id、supervisor 比任一 waiter 先完成、fifo/lock 建立失敗時的行為。

**Trigger**（條件觸發，非既定排程）：**僅在真正出現需要多個 waiter 同時等待同一個 run_id/gate_id 的場景時才拿出來討論**（例如某個 orchestration 流程設計上就要 fan-out 通知給多個消費者）。目前 `pmctl dispatch wait`/`gate wait` 的呼叫模式都是「一個呼叫端等一個結果」，此條件尚未成立，故列為 someday 而非排入 milestone。

**area**: arch/gate
**Priority**: P3（someday，條件觸發）。
**Cross-link**: [[CC-433]]、[[CC-434]]。
