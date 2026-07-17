<!-- pm-schema: v1.2 -->
# pm-dispatch backlog
<!--
ID PREFIX: CC
CC-001/CC-002 were consumed by PR #24 fix bundle inline, with no standalone entries; this file starts at CC-003.
-->

## Index

| #  | Status | 主題 | 影響面 | 首次記錄 | Refs | Priority | Epic |
|----|--------|------|--------|----------|------|----------|------|
| CC-450 | 🟢 someday | 其餘 9 個 test-*.sh docstring 格式統一（CC-004 同款 Behavior/Steps，跨檔） | ops | 2026-07-03 | — | P3 | — |
| CC-451 | ✅ closed 2026-07-15 | core/ 定義層接上 runtime：enum 單一來源 + state 寫入 schema 驗證（CC-446 契約凍結前置；2026-07-06 盲測稽核；v0.9.0） | arch | 2026-07-06 | pr:#409 | P2 | design |
| CC-452 | 🔵 active | guard/hook 對稱性與併發 hardening：episodes.jsonl append 加鎖、三安全 guard set -e 統一、ISO8601 正規化抽 lib（2026-07-06 盲測稽核；v0.9.0） | ops | 2026-07-06 | — | P3 | hygiene |
| CC-453 | 🔵 active | worktree/auto-pack 路徑契約 hardening：worktree create stdout 契約、auto-pack work_dir fail-loud、opencode isolation 錯誤訊息修正（2026-07-06 盲測稽核；v0.9.0） | ops | 2026-07-06 | — | P3 | hygiene |
| CC-454 | 🟢 someday | CI shellcheck ignore_names 白名單 ratchet 收斂：獨立 job + 白名單清零機制（比照 CC-450 模式；2026-07-06 盲測稽核） | ops/test | 2026-07-06 | — | P3 | hygiene |
| CC-456 | 🔵 active | 去除 maintainer-local `~/github/` 佈局假設：repos-root 參數化 + prose/scripts/pm 層全面 sweep + lint 防再犯（2026-07-06 使用者指出；v1.0 public 前提；v0.9.0） | arch/portability | 2026-07-06 | — | P2 | oss |
| CC-460 | 🔵 active | `pmctl commands --json` manifest 單一來源 + router↔manifest↔README 三方防漂移 lint（承接 CC-033 #4 README surface 重建、CC-446 #5a `--json` 覆蓋率缺口；2026-07-07 openyida 跨專案分析） | DX/docs | 2026-07-07 | — | P2 | design |
| CC-461 | 🟢 someday | `doctor.sh --fix`：僅限冪等/可逆/不碰使用者內容類別的自動修復；待 CC-447 offline smoke 產出摔倒點清單後定白名單（2026-07-07 openyida 跨專案分析） | ops/install | 2026-07-07 | — | P3 | — |
| CC-462 | 🟢 someday | e2e 可拋棄資源紀律：前綴命名 + registry JSON + result artifact；掛在 CC-449 e2e 新 phase 之後，與 CC-447 live smoke 共用同一 registry（2026-07-07 openyida 跨專案分析） | ops/test | 2026-07-07 | — | P3 | — |
| CC-463 | 🟢 someday | `pmctl batch` 泛用批次執行原語；依賴 CC-460（合法性驗證來源）；新注入面須過 security-reviewer（2026-07-07 openyida 跨專案分析） | arch/process | 2026-07-07 | — | P3 | design |
| CC-464 | 🟢 someday | `pmctl ticket draft --from <notes>`：隨手筆記→結構化 backlog 票草稿；依賴 CC-286（prefix-generic next-id，⏸ deferred 尚未排程）；review-first 邊界獨立設計，CC-054 僅供鬆散參照非直接前例（2026-07-07 openyida 跨專案分析） | ux/process | 2026-07-07 | — | P3 | — |
| CC-486 | ⏸ deferred | direct-impact test planner mapping 提前退出：changed path 含 `agents/*.md`／`commands/*.md` 時 `map_path` 呼叫未註冊的 `lint-frontmatter`，`add_suite` 回傳 1 並在 `set -e` 下無輸出終止，導致 `run-tests.sh --base ... --list` exit 1 | ops/test | 2026-07-13 | feedback:2026-07-13 | P2 | hygiene |
| CC-489 | 🔵 active | `scripts/` domain ownership重整：Phase 0–6 implementation、三 host live wiring refresh 與 final reuse audit 已完成；等待 final PR gate/authoritative full-suite evidence 後關票 | arch | 2026-07-14 | feedback:2026-07-17 | P2 | design |
| CC-490 | ✅ done | project-scoped explicit memory config：取代全域單值 `dispatch.memory_dir`，避免多 repo 靜默共用 pm-dispatch canonical store | arch/memory | 2026-07-14 | pr:#406 | P1 | design |
| CC-491 | ✅ closed 2026-07-15 | PR-gate pre-flight 機械式 evidence contract：傳遞 command、selected suites、逐項結果與 tree fingerprint，讓 reviewer reuse 已驗證結果並禁止無條件重跑 | ops/gate | 2026-07-14 | pr:#408 | P1 | design |
| CC-493 | 🟢 someday | Prompt→Skill→Command→Harness 升級規則文件化：可測試的分類判準（何時停在 prompt、何時升為 skill、何時做成 command、何時需要 harness-level hook/guard/state），並盤點 `commands/`／`skills/`／`agents/` 現況對照分類（2026-07-15 CC-489 三方 multi-model synthesis） | process/docs | 2026-07-15 | feedback:2026-07-15 | P2 | design |
| CC-494 | 🟢 someday | design: executor 局部設計裁量權 envelope——在 dispatch brief / executor contract 定義「可自行處理的局部設計」與「必須 halt 回報 PM」的邊界（例如新增 schema 欄位 `design_latitude`/`architectural_conflicts`）；三方 multi-model synthesis 2:1 分歧（codex/fable 認為現行邊界過度僵硬需要新機制，opencode 認為現行 `isolation_level`/executor 欄位已足夠彈性），本票僅追蹤決策、不預設結論（2026-07-15） | schema/process | 2026-07-15 | feedback:2026-07-15 | P3 | design |
| CC-495 | 🔵 active | `pmctl dispatch cancel <run_id>`：detached run 中途終止機制。`core/policy/dispatch-states.yaml` 已定義 `cancelled` 為合法 terminal state 且無任何 code path 寫入；`.supervisor.pid` 存在但未被任何 pmctl 子命令讀取；使用者目前唯一手段是手動 kill pid，無文件、可能留孤兒 process、無 `run.cancelled` event（2026-07-15 使用者發現 executor 缺乏可終止行為） | arch/gate | 2026-07-15 | feedback:2026-07-15 | P2 | design |
| CC-496 | ✅ done | Codex command guard 的單次 bypass transport 修復：提示建議 `PM_GUARD_PM_BASH=off`，但 inline assignment 在 PreToolUse hook 前尚未進入環境，導致已確認風險的 branch cleanup 仍被攔截 | ops | 2026-07-15 | pr:#407 | P1 | hygiene |
| CC-465 | 🔵 active | memory/context 關鍵詞管線 CJK 支援：抽出共用零依賴斷詞 lib，取代三處各自 ASCII-only 抽詞；工作序列起點（465→467→468→466）（2026-07-07 記憶系統深入分析） | memory | 2026-07-07 | feedback:2026-07-07 | P2 | retrieval |
| CC-466 | 🔵 active | 記憶卡片生命週期閉環：expires_at 執行 + 關窗式 supersede + usage sidecar 休眠偵測 + doctor→distill 接線；排在 CC-467 之後（需其遙測為前置）（2026-07-07 記憶系統分析 + 外部研究 Graphiti/mcp-memory-service） | memory | 2026-07-07 | feedback:2026-07-07 | P2 | retrieval |
| CC-467 | 🔵 active | `pmctl memory stats`：注入效益可視化（唯讀聚合器）——注入 bytes/卡片命中分佈/從未命中卡/episode 填寫率，回答「記憶有跟沒有差在哪」；排在 CC-466 之前（2026-07-07；業界僅離線 recall 評測，無 per-injection 遙測） | DX/memory | 2026-07-07 | — | P2 | retrieval |
| CC-468 | 🔵 active | dispatch brief 帶 memory 約束：PM 萃取為非敏感 `constraints:` 清單（pointer 僅作 provenance），依賴 CC-465 CJK 先行（2026-07-07；auto-pack 現為 repo-only by construction） | ops/memory | 2026-07-07 | — | P2 | retrieval |
| CC-011 | 🟢 someday | sync-memory.sh + install 選項：symlink memory 到雲端資料夾實現跨裝置共用 | ux/memory | 2026-05-14 | — | — | — |
| CC-012 | 🟢 someday | SessionStart hook：session 啟動時 pull 最新 memory（git/rsync）確保跨裝置同步 | ux/memory | 2026-05-14 | — | — | — |
| CC-015 | 🟢 someday | `systematic-debugging` skill：結構化偵錯工作流；作為升級規則(CC-493)定案後的首個試點 skill，落地於 `skills/systematic-debugging/SKILL.md` 而非 slash command | ux | 2026-05-14 | — | P3 | — |
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
| CC-446 | 🔵 active | v1.0 契約凍結：`docs/stability-contract.md` 四層分級（stable/experimental CLI + stable/internal schema）+ SemVer/deprecation 政策 + 執行 CC-296 清掃（v1.0 P0，v0.9.0 候選；DECISIONS 2026-07-04） | process/DX | 2026-07-04 | — | P2 | design |
| CC-447 | 🔵 active | 乾淨機器 onboarding 雙 smoke：offline clean-install smoke（v0.9.0 候選）+ live dogfood smoke（v1.0-rc）；摔倒點逐一開票；QA_RULES_DIR 缺席行為驗證 | docs/ops | 2026-07-04 | — | P2 | — |
| CC-449 | 🔵 active | release-verify/test-e2e 對 v0.8.0 新 surface（`pmctl ship`/`pmctl worktree`）無 live 煙測 + run-all-tests 套件註冊完整性 lint（CC-444 收尾發現 test-pmctl-worktree 未註冊，已修；防再漏）+ CI↔run-all parity 斷言（2026-07-06 稽核：24 個本地 suite CI 缺席）（v0.9.0 候選） | ops/test | 2026-07-04 | — | P2 | — |
| CC-472 | 🟢 someday | spike: antigravity（`agy` CLI）host 唯讀 probe——比照 CC-436/CC-448 階段 1 模式，實測 command 載入能力 + hook/plugin 機制 + 五個 capability enum 的 provider/confidence 判定，不落地 `hosts/antigravity/host.yaml`；排在 CC-445 通用 install/uninstall dispatcher 之後、與 CC-448 opencode 同批或緊接其後評估（N=3 驗證點） | arch/install | 2026-07-08 | — | P3 | spike |

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

## CC-449 — release-verify/test-e2e：ship/worktree surface 煙測 + 套件註冊完整性 lint 🔵 active

**Problem**：v0.8.0 新增的 `pmctl ship`（unified entry / prepare / finish / `--parallel`）與 `pmctl worktree`（create/list/remove/gc）只有 unit 套件覆蓋；release sign-off 的 e2e 路徑（`test-e2e.sh` Phase B/C）只驗 dispatch 輸出契約與 pr-gate 機制，對這兩個新 surface 零 live 煙測。且 [[CC-444]] 收尾時發現 `test-pmctl-worktree.sh`（36 cases）**根本沒註冊進 full runner registry**——套件存在但 aggregator 從未執行，release-verify 的「全套綠燈」靜默漏掉它（已於 CC-444 補註冊）；「新增 suite 必須註冊」目前無任何機械防護。CC-481 後 canonical registry 位於 `scripts/lib/test-suite-runner.sh`，`run-all-tests.sh --list` 仍是穩定查詢 surface。

**Why**：v1.0 P1 證據層的一環——release sign-off 的覆蓋範圍必須跟上 surface 的成長，否則 `release-verify GO` 的可信度逐版稀釋；註冊完整性 lint 是同類靜默缺口的止血閥。

**Requirement**：
1. **套件註冊完整性 lint**（第一刀，機械）：`scripts/test-*.sh` 存在但未在 `scripts/lib/test-suite-runner.sh` 註冊 → fail loud（允許顯式 exclude 清單，如 fixture-only helper）；接入 CI 與 `release-verify.sh` Phase 1。注意新增套件目前需**三處**同步——共用 executor（SUITE 陣列 + path map）與 `test-run-all-tests.sh`（`SUITE_NAMES` mirror + `suite_path` case）；後者的 parity 已由 meta 套件自身把關（CC-444 補註冊時實際觸發），lint 只需補「檔案存在但未註冊」這缺口，並評估讓 meta-suite 從 canonical executor 動態派生以消除第三處人工同步。
2. **ship/worktree e2e 煙測**：`test-e2e.sh` 新增 phase——synthetic target 上走一次 `pmctl worktree create → pmctl ship <id> --worktree → ship status 讀到 prepared → worktree remove`（不 dispatch、不花 LLM token 的最小閉環）；`ship finish` 的 live 驗證（含 gate）評估成本後決定納入或明文排除並記錄理由。
3. 與 [[CC-431]]（adapter 清單動態派生）同批評估，避免 e2e 腳本兩次重構。
4. **CI↔run-all parity 斷言**（2026-07-06 盲測稽核擴充）：`.github/workflows/lint.yml` 的 job 清單與 full runner registry 各自手動維護、零 parity 檢查——實測 24 個本地 suite 在 CI 從未執行，含 dispatch 核心（test-dispatch-lifecycle、test-dispatch-common、test-detached-launch、test-opencode-dispatch）與三個最大 pmctl 套件（test-pmctl-context/memory/dispatch）。lint 需一併涵蓋：canonical executor 每個註冊 suite 必須在 CI 出現，或列入顯式豁免清單並附理由（如 live-DB 互斥、耗時）。這是比第 1 項「未註冊」更大的同類靜默缺口。
5. **零覆蓋 lib 盤點**（同批）：`scripts/lib/gate-workspace.sh`、`scripts/lib/pmctl-config.sh` 在所有測試檔零引用——補最小套件或記錄豁免理由。
6. **surface 覆蓋分類 lint（反向補完，2026-07-07 openyida 跨專案分析併入）**：每個 command/agent/skill 必須宣告 `coverage: e2e|unit|opt-in|manual-only|deprecated` + 一行理由；本項是第 1 項「套件存在但未註冊」的反向缺口——「surface 存在但沒人宣告它該有什麼等級的覆蓋」。清單載體與既有 lint 機制（第 1/4 項）同批評估，避免產出第二套獨立 YAML/清單格式。

**Done-when**：lint 落地且能抓到「新增未註冊套件」與「已註冊但 CI 缺席且無豁免」與「surface 缺 coverage 宣告」三類注入測試；e2e 新 phase 在 `release-verify.sh --e2e` 下通過；排除項（若有）記錄於腳本註解與本票。

**Dependencies**：與 [[CC-431]] 檔案面重疊（test-e2e.sh/release-verify.sh），宜同版處理。v0.9.0 候選。
**See**: [[CC-444]] Outcome、pr:#367

---

## CC-451 — core/ 定義層接上 runtime：enum 單一來源 + state 寫入 schema 驗證 ✅ 2026-07-15

**Problem**: `core/` 定義層（8 個 JSON Schema + policy enum/狀態機 YAML）從未接上 runtime——`core/README.md` 自承「the current implementation handles path resolution and state writes without validating against the definition layer (integration deferred to a future milestone)」；三個 policy 檔（`executor-enum.yaml`、`dispatch-routes.yaml` 等）檔頭標「deferred to v0.3.x runtime phase」至今（v0.8.0）未兌現。實際後果：executor/isolation enum 在 adapter dispatch 腳本與 `handover-validate.sh` 各硬編一份、靠人工同步（`executor-enum.yaml` 自承 "embedded inline ... kept in sync"）；`scripts/lib/state-writer.sh` 手寫 JSON、不經任何 schema 檢查。

**Why**: [[CC-446]] v1.0 契約凍結要把 schema 列為 stable 承諾，但 runtime 從不驗證的 schema，其承諾是空的——凍結前應先讓定義層「真的在管事」。enum inline 複本漂移也是未來新增第 4 個 executor 時的實際回歸風險（2026-07-06 盲測稽核）。

**Requirement**:
1. **enum 單一來源**：executor / isolation-level 等 enum 由 `core/policy/*.yaml` 派生（runtime 讀取或 build-time 生成，實作時 `/pre-impl` 收斂取捨）；至少先落地一個 parity 回歸測試鎖住「所有 inline 複本 == policy YAML」，抓漂移。
2. **state 寫入驗證**：state-writer append 的 event/record 對 `core/schema/*.schema.json` 對應 schema 做結構檢查（jq 層即可，不引新依賴）；預設 fail-loud，可保留 warn-only 過渡開關。
3. 不改 schema 內容本身；現有綠燈路徑行為不變（回歸鎖住）。

**Non-goals**: 不做完整 JSON Schema validator（draft-07 全語意）；結構檢查以「必要欄位存在 + enum 值合法」為度。

**Runtime validation disposition (2026-07-15)**: writer 邊界統一採 deterministic、`jq`-only 的 schema 子集（recursive object `required`、`const`、primitive `type`、`enum`、`if`/`then`），取代舊有「主機剛好裝了 `jsonschema` 才做完整 draft-07，未安裝即跳過」的環境相依行為。`pattern`、length/range、`format`、`additionalProperties` 等完整 draft-07 keyword 仍由 development/test schema checks 負責，明確不屬 runtime load-bearing contract；這是本票 Non-goals 的具體化，不改 schema 內容或版本。

**Outcome**: executor、dispatch route、isolation level 與 task state 的 runtime 驗證已改由 `core/policy` 單一來源驅動；Run、Event、Task、Decision 的 durable write boundary 統一以 `jq` 執行明確界定的 schema 結構子集，預設 fail loud 並保留顯式 warn-only 過渡模式。policy substitution、invalid enum／required／nested type、projection side effect 與 lifecycle fallback regression 均已落地；targeted gate GO，authoritative full suite 79 passed、0 failed、0 skipped。

**Dependencies**: [[CC-446]] 的前置/同批（stable schema 分級需要「有驗證」的事實支撐）。承接 [[CC-211]]（schema-first epic）的 runtime 驗證切片。v0.9.0。
**Source**: 2026-07-06 盲測程式碼稽核（四路獨立分析，未讀 backlog 前提下收斂的最大未規劃項）。
**See**: pr:#409

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

## CC-486 — direct-impact planner 未註冊 suite 觸發 `set -e` 提前退出 ⏸ deferred

**Problem**: `scripts/run-tests.sh --base origin/main --list` 在 changed paths 含 `agents/*.md` 或 `commands/*.md` 時，`map_path` 會呼叫 `add_suite lint-frontmatter`；但 `test-suite-runner.sh --list` 沒有註冊該 suite。`add_suite` 的最後一個條件式因此回傳 1，頂層 `set -e` 直接終止，沒有 planner diagnostics，exit 1。

**Acceptance**: 未註冊的 optional mapping 不得讓 planner 提前退出；應修正 mapping 名稱或讓 `add_suite` 明確 return 0，並新增包含 agent/command changed path 的 regression，確認 `--list` 輸出已選 suites、coverage gaps 與 exit 0。不得藉此弱化「沒有任何可用 suite 時 exit 2」的既有契約。

**Evidence**: CC-483 收尾時以 `bash -x scripts/run-tests.sh --base origin/main --list` 重現；trace 停在 `add_suite lint-frontmatter` 的 `[[ -n '' ]]`。同一批 CC-483 focused suites與 lint 均綠，故此項獨立追蹤，不視為 CC-483 產品 regression。

---

## CC-489 — `scripts/` domain ownership 與 manifest-driven entrypoint 重整 🔵 active

**Problem**: repository 目前把 host adapters、install/uninstall、doctor modules、memory hooks、gate/runtime supervisors、維運工具、lint 與所有 test runners 集中在單一 `scripts/`。檔名雖有前綴，但 ownership、依賴方向與「新增功能應放哪裡」無法從目錄結構判斷；host manifest 已能描述 module path，實體程式卻仍多數留在共享 scripts 根目錄，長期會增加跨 host 漂移、路徑硬編與搬移成本。更隱晦的問題是這些腳本同時攜帶了大量 ambient configuration contract：host home/config root、legacy alias、timeout/model/isolation 預設、`HOME`/`PATH`/`TMPDIR` fallback、repo-root 相對路徑推導、child-process env 傳遞與 test-only injection。若只搬檔案，即使內容不變也可能改變路徑解析、優先序與實體寫入目標。

**Framing**: 本票不是 bulk rename，遷移單位也不是單一 file；每一個 executable/module 必須以「path + invocation ABI + variable/config contract + side-effect boundary + consumers/tests」作為一個可驗證單位。先鎖住現行行為與 ownership，才允許變更實體路徑；不得以「搬後 focused tests 有綠」取代 env/side-effect parity。

**Decision / target shape**:
1. host 專屬 executable、hook adapter、doctor 與 install module 歸 `hosts/<host>/{bin,hooks,lib}`；`hosts/<host>/host.yaml` 是它們的發現單一來源。CC-488 新增的 Codex explicit-memory writer 直接落在 `hosts/codex/bin/`，不再新增 `scripts/codex-*` debt。
2. host-neutral canonical business logic 留在共用 runtime/CLI layer；例如 memory resolver/writer 不複製到各 host，host 目錄只保留薄 adapter。通用 ops/release 工具與 test harness 另有明確 domain，不因搬目錄而複製實作。
3. 先產出 current→target path map 與 variable contract ledger。每個對外或跨模組變數至少記錄 owner、input type（public override/legacy alias/internal derived/test injection）、default source、precedence、child-process propagation、side effects、sensitivity、test isolation 與 compatibility plan。
4. shared dispatcher 與 host module 先建立明確 invocation ABI；repo root、dry-run 等執行輸入由 argv 或等價的可機械驗證介面傳入，不再依賴 module 恰好位於 `scripts/` 而以 `SCRIPT_DIR/..` 猜 repo root。舊入口由 shim 轉接新 ABI。
5. host PM runtime 與 dispatched executor adapter 維持正交 ownership：`hosts/<host>/` 擁有 host config root、hook/install/doctor/lifecycle；`adapters/<name>/` 擁有 executor model、timeout、reasoning effort、isolation mapping；`PM_CFG_*`、state/context/memory 等 canonical config 留在 shared runtime。不得只因變數名稱含 host 名稱就移入 `hosts/`。
6. host config root/default/legacy alias 必須在對應 host-owned resolver 收斂，install、uninstall、doctor 與 hook installer 共用同一組解析與衝突規則。shared manifest reader 不得長期硬編 `CODEX_HOME`、`CLAUDE_CONFIG_DIR`、`XDG_CONFIG_HOME` 等具名 host 變數與預設值；展開必須來自 manifest/host resolver 的受限宣告，不得 `eval` manifest data。
7. 按 domain 分批搬遷，禁止一次性全庫 rename。對已公開／已安裝路徑保留有期限、帶 deprecation 訊息的 shim，manifest/registry 與 tests 先切新路徑，最後依明確刪除條件移除 shim。
8. 新增 layer/path/variable lint：host-specific implementation 不得再出現在共享 core/runtime entrypoints；新增 host module 必須由 manifest 引用；shared resolver 不得新增未宣告的 host env；suite 必須由 test registry 發現，不能靠散落硬編路徑。過渡期以明確 grandfather inventory 鎖住現有債務，但不允許新增。

**Priority implementation plan**:
1. **Phase 0 — contract inventory（不搬檔）**：建立 executable ownership/current→target map、variable contract ledger、consumer graph、穩定入口清單、shim removal criteria 與允許依賴方向。先盤點 production env、host legacy alias、ambient `HOME`/`PATH`/`TMPDIR`/XDG、test injection 與 secrets，不得只 grep host-name prefix。
2. **Phase 1 — behavior-lock tests + module ABI**：先以現行路徑建立 env/default/side-effect parity matrix，覆蓋 unset/empty/conflicting alias/含空白路徑/relocated fixture/hostile `HOME` 與全環境沙盒；再讓 manifest dispatcher 明確傳遞 repo root 與 dry-run，並保留既有 direct-call 相容。
3. **Phase 2 — host resolver 收斂**：先將 Claude canonical `CLAUDE_CONFIG_DIR`/legacy `CLAUDE_HOME` 衝突規則收為單一 host-owned resolver，再對 Codex/OpenCode 建立同型 resolver/manifest declaration；改造 shared `host_manifest_expand_path` 為不含 host-name branches 的受限展開。
4. **Phase 3 — OpenCode pilot migration**：搬遷 OpenCode install/uninstall/doctor，用最小 host slice 驗證 manifest-first consumer cutover、legacy shim、inventory ratchet 與 filesystem parity。
5. **Phase 4 — Codex host migration**：搬遷 Codex install/uninstall/doctor/command hook，同時驗證已安裝 `hooks.json` 的舊路徑 refresh/uninstall 相容；已在 `hosts/codex/bin/` 的 canonical memory writer 不搬動。
6. **Phase 5 — Claude host migration**：搬遷 Claude guards installer/uninstaller、doctor 與 Claude-only hooks/libs，並去除 `install.sh`/`uninstall.sh` 繞過 manifest dispatcher 的 base-host 特例；保留 top-level installer 作為產品入口。
7. **Phase 6 — shared domains 與 shim retirement**：三個 host phase 穩定後，再分批搬 shared runtime、test harness、tooling 與 ops/release；依公告期、consumer 清零與 release smoke 結果移除相容 shim。這是 CC-489 可關票的最終階段，不與 Phase 3–5 的 host migration 混成單一 PR。

**Phase 0 completed (2026-07-15)**: 新增 `docs/architecture/script-domain-ownership.md`、`script-domain-inventory.tsv`、`script-variable-inventory.tsv` 與 `script-variable-consumers.tsv`。path inventory 機械對齊目前 `scripts/` 174/174 files（119 executables、52 sourced libs、3 fixtures），每列已指定 artifact kind、owner domain、proposed target、migration disposition 與 stability；其中 19 個 installed/maintainer/host-wiring paths 必須 move-with-shim，其餘 155 個在 consumer 切換後 move-then-remove。variable ledger 另以結構化欄位記錄 module-derived path、host roots/legacy alias、ambient env、resolved `PM_CFG_*`、state/context/gate/test controls 與 API credential passthrough 的 owner、precedence、propagation、side effect 與 isolation contract；static consumer graph 將 62 個 exact/wildcard declarations 對應至 310 個 production/test references。`scripts/lint-script-domain-inventory.sh` 已把 path set、owner→target、shim、variable declaration、consumer path safety 與 graph freshness 收為 ratchet，consumer filesystem validation 不再組合 shell command；`test-script-domain-inventory` 的 10 個 fixture regressions（含 stale graph mutation 與 hostile repo path injection）已註冊進共用 suite runner，changed-path planner 亦會在 inventory/contract 變更時選取兩者。architecture contract 完成 dependency direction、module ABI 目標、穩定入口、shim 刪除條件與實體搬遷順序；本階段沒有搬動 production file，下一階段須等待 [[CC-451]]、[[CC-490]]、[[CC-491]] 核心契約收斂後，才從 env/default/side-effect behavior-lock tests 與明確 repo-root/dry-run module ABI 開始。

**Phase 1 module ABI slice completed (2026-07-15)**: 前置 [[CC-451]]、[[CC-490]]、[[CC-491]] 均已完成後，manifest write dispatcher 已要求 absolute repo root，並對 Codex/OpenCode install/uninstall modules 明確傳遞 `--repo-root` 與 `--dry-run`。四個 module 先驗證 supplied checkout 再 source repo libraries；舊路徑 direct-call 介面仍相容。`test-host-write-parity` 新增 relocated Codex/OpenCode fixtures，從 manifest-dispatched install、managed-state owner 到 uninstall 全程證明不再依賴 `scripts/` directory depth，並鎖住 generic dispatcher 與 relocated Codex module 的 relative repo root 在執行前 fail-loud。既有 Codex/OpenCode write suites、full-HOME/PMCTL_BIN_DIR sandbox integration、dry-run side-effect 與 Claude byte-parity regressions 維持通過。本切片不包含 Phase 2 host resolver 收斂，也尚未搬動 production path。

**Phase 2 host resolver slice completed (2026-07-16)**: 三個 host manifest 現在各自宣告 `path_resolver_module`／`path_resolver_function`，實作分別位於 `hosts/{claude,codex,opencode}/lib/path-resolver.sh`。shared `host_manifest_expand_path` 僅驗證 manifest-declared repo-relative module 與 function identifier 後委派，不再包含任何 `CODEX_HOME`／`CLAUDE_CONFIG_DIR`／`CLAUDE_HOME`／`XDG_CONFIG_HOME` 名稱、default 或 host branch，也未使用 `eval`。Claude base install/uninstall、hook install/uninstall 與 doctor 已共用同一 resolver，鎖住 canonical→legacy→`HOME/.claude` precedence 與 conflicting alias fail-closed；Codex/OpenCode 維持 explicit root→host default。回歸覆蓋 unset、empty、相同/衝突 legacy alias、含空白 root、hostile `HOME`、relocated fixture 與 shared-reader no-host-name ratchet；variable consumer graph 已由 shared reader 轉移到 host-owned modules。本階段沒有搬動既有 production file。交付時另修正 affected-test planner 的既有 repeated-`mark_full` bug：同一 diff 依序命中 `install.sh`、`uninstall.sh` 時不再因第二次空字串條件在 `set -e` 下靜默退出；此修正只恢復 test evidence 規劃，不改 resolver 產品行為。下一階段從 OpenCode pilot migration 開始。

**Phase 3 plan — OpenCode pilot migration**:
1. **Production move set**: `scripts/install-host-opencode.sh` → `hosts/opencode/bin/install.sh`、`scripts/uninstall-host-opencode.sh` → `hosts/opencode/bin/uninstall.sh`、`scripts/lib/doctor-host-opencode.sh` → `hosts/opencode/lib/doctor.sh`。同一切片更新 `hosts/opencode/host.yaml`、path/variable inventory 與 consumer graph，不搬 OpenCode adapter，也不改 permission/receipt 產品語意。
2. **Manifest-first cutover**: `doctor.sh` 的 host module discovery 從 `scripts/lib/doctor-host-*.sh` glob 改為逐一讀取 manifest `doctor_module`；install/uninstall 繼續只經 `host-write.sh` 讀 manifest。shared loader 只驗證 repo-relative path/function contract，不新增 OpenCode branch。
3. **Compatibility**: 舊 install/uninstall 路徑保留 thin shim，只解析自身 checkout root 後原樣轉送 argv/exit status，deprecation 只寫 stderr；舊 doctor lib 是 internal sourced path，production/test consumer 切換後直接移除，不建立第二個 source shim。
4. **Acceptance / evidence**: manifest path 與 legacy direct call 對 install、dry-run、idempotent reinstall、user-owned conflict、receipt restore 與 uninstall 的 stdout machine payload、exit code 及 filesystem diff 一致；relocated/space-path fixture 全程不依賴 module depth；`test-host-write-opencode`、`test-host-write-parity`、`test-doctor`、`test-host-manifest`、`test-script-domain-inventory` 與 full-`HOME`/`PMCTL_BIN_DIR` sandbox 全綠，而且 repo 外只變動 fixture 允許的 XDG tree。
5. **Exit gate**: manifest/production consumer 已無舊 OpenCode implementation path；inventory 只將兩個 legacy shim 列為 compatibility debt；完成一次 install → doctor → uninstall live-like sandbox smoke 後，才允許開始 Phase 4。

**Phase 3 completed (2026-07-16)**: OpenCode install/uninstall/doctor 已搬至 `hosts/opencode/{bin,lib}` 並由 `host.yaml` 發現；shared doctor loader 改為依 manifest `doctor_module` 載入，舊 install/uninstall 入口只保留 stderr deprecation 的 thin shim，舊 internal doctor path 已移除。搬遷過程暴露的 minimal-`PATH` 問題已在 shared manifest reader 以純 Bash path/scalar parsing 收旂，changed-path planner 也將 shared manifest 變更對應到三 host write/parity/doctor suites。refactor/reuse 稽核將 doctor、host-write、path resolver 三處新增的 module path 解析與 fail-closed 驗證收斂至 `host_manifest_module_path`；legacy shims 則刻意保持 self-contained，避免相容入口新增脆弱依賴。gate advisory 後，loader fail-fast 亦統一經 `emit_summary` 輸出 JSONL fail record/summary；parallel synthesis fixture 使用 suite-private `TMPDIR` 並保留 gate stderr，避免 full-run 暫態失敗不可診斷。path inventory 現為 173 個 `scripts/` files，variable graph 為 62 declarations/317 refs；14 個 direct-impact suites 全綠（含 OpenCode 15、parity 8、doctor 65、host manifest 91、Codex host-write 45、PR-gate 147 cases）。

**Phase 4 plan — Codex host migration**:
1. **Production move set**: 將 Codex install/uninstall/doctor 搬到 `hosts/codex/{bin,lib}`，將 `scripts/hook-codex-command-guard.sh` 搬到 `hosts/codex/hooks/command-guard.sh`；manifest 改指新 module。`hosts/codex/bin/memory-update.sh` 與 `adapters/codex/` 均維持原位，不在此 phase 重寫 canonical memory 或 executor semantics。
2. **Installed-path transition**: 新 install 必須將 `hooks.json` 寫為新 hook path；舊 install/uninstall/command-hook 路徑保留 thin shim，且 uninstaller 必須能辨識、移除同一 checkout 的 old/new managed command，但不得誤刪同 basename 的其他 checkout 或 user hook。重跑 installer 應把自己的 stale old path refresh 到 new path。
3. **Contract ratchets**: Codex path resolver 繼續擁有 `CODEX_HOME`/default；shared manifest/host-write/doctor loader 不出現 Codex env 名稱或分支。inventory/consumer graph 要區分 host runtime 與 `adapters/codex` executor axis，禁止因搬遷把兩者合併。
4. **Acceptance / evidence**: 舊版 `hooks.json` fixture 經 reinstall 後只剩 new path，經 uninstall 後只移除本 checkout managed entries；headless benign allow/destructive deny hook smoke 與 session-summary/canonical-memory routing 不退化；`test-host-write-codex`、`test-host-write-parity`、`test-doctor`、`test-host-manifest`、Codex hook/guard focused suites 與 hostile-`HOME` sandbox 全綠。
5. **Exit gate**: live-like install → headless hook probe → doctor → uninstall 證明無 orphan hook、無誤寫 canonical memory、無 operator config diff；舊路徑只剩明列 compatibility shim 與專門 parity test。

**Phase 4 completed (2026-07-16)**: Codex install/uninstall/doctor/command guard 已搬到 `hosts/codex/{bin,lib,hooks}` 並由 `host.yaml` 發現；`hosts/codex/bin/memory-update.sh` 與 `adapters/codex/` 維持原位。舊 install/uninstall/command-hook 路徑保留 self-contained thin shim，舊 internal doctor 路徑已移除；新 installer 會精準將同一 checkout 的舊 `hooks.json` command refresh 為 host-owned path，新 uninstaller 同時辨識 raw/escaped old/new identity，且保留其他 checkout 的同 basename hook。refactor/reuse 稽核將 installer、uninstaller、doctor 共用的 hook identity 收斂到 `hosts/codex/lib/hook-paths.sh`。驗收通過 Codex host-write 48、manifest 91、relocated parity 8、doctor 65、install 90、uninstall 28、inventory 10 cases 與 131-file shell lint；live-like 全環境沙盒完成 install → benign allow/destructive deny probe → doctor → uninstall，最終 `hooks.json` 為空、canonical-memory sentinel 未變、operator config 未被觸碰。Phase 5 可開始，CC-489 仍保持 active。

**Phase 5 plan — Claude host migration**:
1. **Production move set**: 將 `scripts/install-guards.sh`、`scripts/uninstall-guards.sh`、`scripts/lib/doctor-host-claude.sh` 搬到 `hosts/claude/{bin,lib}`；將 Claude-only `guard-log-claude-usage.sh`、`guard-save-rate-limits.sh` 與 `prompt-context-timeouts.sh` 搬到 `hosts/claude/{hooks,lib}`。shared PM/memory/context guard 先保留 shared runtime ownership，等 Phase 6 再搬，避免 Claude phase 偷渡 host-neutral logic。
2. **Remove the base-host exception**: `hosts/claude/host.yaml` 宣告可執行 install/uninstall module；top-level `install.sh`/`uninstall.sh` 仍是用戶產品入口、負責 assets/symlinks/manifest 總編排，但 Claude hook/settings 寫入改為經 generic host-write dispatcher，不再直接呼叫 `scripts/install-guards.sh`。預設 Claude 與 opt-in host loop 必須去重，uninstall 不得執行兩次。
3. **Compatibility and chain safety**: 舊 guards installer/uninstaller 與兩個已寫入 `settings.json`/`statusline-chain.conf` 的 hook path 保留 thin shim。installer 可將同 checkout old path refresh 為 new path，但必須保留 unrelated Stop/UserPromptSubmit hooks、Claude Account Switcher 與 abtop chain；uninstall 同時識別 old/new managed path，不刪他方同 basename hook。
4. **Resolver and copy-mode boundary**: `CLAUDE_CONFIG_DIR`/`CLAUDE_HOME` 衝突與 default 仍只在 Claude resolver；doctor 以 manifest module 為 normal mode。單檔 copy-mode fallback 只保留可獨立驗證的降級診斷，fix text 指向 top-level installer，不複製 host resolver/hook inventory 邏輯。
5. **Acceptance / evidence**: 覆蓋 canonical/legacy alias 同值與衝突、minimal/full profile、settings 含無關 hooks、stale old paths、statusline chain、spaced checkout、dry-run、full-`HOME`/`PMCTL_BIN_DIR` sandbox與 install-manifest uninstall preservation；`test-install`、`test-doctor`、`test-hook-profile-parity`、`test-host-manifest`、相關 guard/context/memory suites 與 live-like statusline payload smoke 全綠。
6. **Exit gate**: top-level install/uninstall 對 Claude settings 已無 direct script-path special case；manifest 是 install/uninstall/doctor 唯一 module discovery source；真實 chain 不在驗收中被修改，除非另有明確 live-write 授權。Phase 5 通過後 CC-489 仍保持 active，由 Phase 6 完成 shared domain 搬遷與 shim retirement 才關票。

**Phase 5 completed (2026-07-16)**: Claude guards install/uninstall、doctor、usage/rate-limit hooks 與 prompt-context timeout contract 已搬到 `hosts/claude/{bin,hooks,lib}`，`host.yaml` 現在宣告三個 lifecycle module；top-level install/uninstall 保留產品 assets/symlink 編排，但 Claude settings 寫入與清理由 generic host-write dispatcher 發現，不再直接呼叫 `scripts/` implementation path，optional host loop 亦明確去重 Claude。舊 installer/uninstaller 與兩個已安裝 hook path 保留 thin compatibility shim；reinstall 會將同 checkout 或已失效舊 checkout 的 legacy hook path refresh 到 host-owned path，uninstall 以 checkout prefix 同時移除 old/new managed entries並保留 unrelated hook、既有 statusline chain 與 foreign settings。explicit repo-root ABI 可安全轉送 profile 參數且保留 spaced checkout 的 logical identity，minimal `PATH`、MSYS native-jq boundary、canonical/legacy config-root conflict、dry-run、full-environment isolation與 manifest-preserving failure recovery均有回歸。focused evidence 通過 install 91、uninstall 29、doctor 65、guards 301、Codex host-write 48、OpenCode host-write 15、host manifest 91、host parity 8、inventory 10 cases、135-file syntax/executable lint及 host-owned ShellCheck；live-like sandbox 完成 install → statusline payload/chain → uninstall，foreign hook/settings與 canonical-memory sentinel 均未變。CC-489 仍保持 active，下一階段只做 Phase 6 shared domains 與 shim retirement。

**Phase 6 implementation and final refactor/reuse audit completed (2026-07-17)**: inventory 宣告的 shared runtime、test harness、tooling、ops/release 共 151 個 implementation/fixture path 已搬到 `runtime/`、`tests/`、`tools/`、`ops/` 並移除舊檔；`scripts/` 精確剩下 19 個 move-with-shim 相容入口，內部 consumer、CLI、CI、suite registry、changed-path planner、install source 與文件皆改用 owner path。installer 的 user-helper name/source/legacy-source 收斂到單一 spec table，精準 refresh 本 checkout 的舊 symlink 並保留 foreign target；三 host resolver 重複的 template 展開收斂到 host-neutral prefix-only helper，host env/default/alias 仍由各 host 擁有，且不再全域替換路徑後段的 token-shaped literal；inventory ratchet 新增 shim→declared target linkage 與 executable 驗證，存在但誤導向的相容層會 fail loud。late live audit 另補 Codex memory/session legacy hook 去重遷移，以及 Claude/Codex doctor 對 configured managed command target 的 existence/executable fail-loud 檢查。focused suites 通過 Codex host-write 49、doctor 67、install 92、uninstall 29、OpenCode host-write 15、host manifest 91、host parity 9、inventory 11；三 host live refresh 後 doctor 為 27 ok、0 warn、0 fail，重跑 dry-run 為 0 conflict 且全部 idempotent，OpenCode 1.18.2 resolved config 載入 checkout-specific pmctl allow、`/pm` command 與 `pm_prepare` permission。final sequential Claude gate `gate-20260717-092054` 以 explicit `--test-cmd 'tests/bin/run-all-tests.sh'` 取得同工作樹 structured evidence（79 passed、0 failed、0 timed out、0 skipped），critic=advise、qa=pass、architecture=approve、security=pass、risk=pass，Final GO；非阻擋 advise 已收斂 backlog 狀態與 upgrade/reinstall 文件。implementation 與驗證完成，但在 real PR artifact 建立前 CC-489 保持 active，開 PR 後再同步 table/heading/`pr:#` reference 關票。

**Acceptance**: (a) architecture map 說明每類 executable 的 owner 與允許依賴方向，variable ledger 可機械或結構化盤點每個跨模組 input/default/precedence/propagation/side effect/test isolation；(b) relocated fixture 證明 module 不再依賴舊 `scripts/` 深度推導 repo root，direct legacy entrypoint 仍能經 shim 產生 byte/exit/side-effect-compatible 結果；(c) Codex、Claude、OpenCode install/doctor/uninstall 從各自 manifest 發現 module，shared dispatcher/resolver 不列 host-specific path、env 或 default；(d) staged migration 每一刀均通過 install parity、uninstall preservation、doctor、hostile-env/full-`HOME` sandbox、full runner 與 release smoke，filesystem diff 證明不觸碰 operator 真實 host config、pmctl symlink、canonical memory 與 repo 外狀態；(e) host/adapter/shared/test 變數 ownership 沒有跨軸漂移，legacy alias 衝突、default precedence、secret redaction 與 child env allowlist 的回歸全綠；(f) 最終 `scripts/` 只保留明確定義的相容入口或通用 ops entrypoints，不再作為所有 shell code 的默認垃圾桶。

**Boundary / sequencing**: 本票在 [[CC-488]] lifecycle product contract 完成後執行（CC-488 已於 2026-07-14 done，前置條件已清除）。CC-488 只遵守新檔案 placement 與 manifest discovery 原則，不藉機搬完既有 Codex/Claude/OpenCode scripts；避免把路徑遷移 regression 混入 canonical memory correctness。2026-07-15 三方（codex/opencode/fable）multi-model synthesis 一致建議 production relocation 排在 [[CC-451]]/[[CC-490]]/[[CC-491]] 核心 harness 收口票之後，避免路徑遷移與 state/schema/evidence 收口同時進行；Phase 0 contract inventory 可先行，但不得在前置契約仍變動時開始 production move。本票可收斂變數 owner/default 位置與模組傳遞契約，但不重新設計 [[CC-490]] 的 project-scoped config schema/resolver precedence，也不改變 [[CC-491]] evidence semantics。

**Current diagnostic evidence (2026-07-15)**: `scripts/` 現有 174 files（root shell entrypoints 119、`scripts/lib` shell modules 52、`test-*.sh` 76），host manifests 仍有 7 個 doctor/install/uninstall module refs 指向 `scripts/`。shared `scripts/lib/host-manifest.sh` 的 path expander 直接解析 `CODEX_HOME`、`CLAUDE_CONFIG_DIR`、`XDG_CONFIG_HOME` 與各自 `$HOME` default；Claude config-root canonical/legacy precedence 重複出現在 install/uninstall/guards/doctor；install/uninstall 另以 `${PMCTL_BIN_DIR:-$HOME/.local/bin}` 決定真實 symlink 寫入目標。既有回饋已證明測試只覆蓋 `CLAUDE_HOME`/`CODEX_HOME` 而漏掉 `HOME`/`PMCTL_BIN_DIR` 會刪改 operator 真實 `~/.local/bin/pmctl`，因此 full-environment isolation 與 filesystem-diff 是 blocker acceptance，不是可選 hardening。

**Source**: 2026-07-14 使用者指出所有 script 集中於 `scripts/` 造成後續維護困難，要求特定內容放回對應位置並統一讀取；2026-07-15 使用者進一步指出腳本內的特定變數、default/fallback 與環境傳遞也必須獨立歸位，不能將本票當成單純搬檔。

**See**: `CHANGELOG.md` CC-489 Phase 6、feedback:2026-07-17、gate:`gate-20260717-092054`

---

## CC-490 — project-scoped explicit memory config，避免跨 repo canonical bleed ✅ 2026-07-15

**Problem**: `~/.pm-dispatch/config` 的 `dispatch.memory_dir` 是全域單值，但 resolver 對每個 repo 都無條件套用。CC-488 gate R1 後的 live read-only probe 已確認：pm-dispatch、JapanJob、qa-testing-rules 雖有不同 stable `project_key`，三者目前都回報 `resolution_source=config` 並解析到 pm-dispatch 的 canonical memory dir。任何其他 repo 的 canonical append 因此可能成功但寫入錯誤專案，屬靜默 cross-project data bleed；同一問題亦使本機 fixture 在未隔離 config 時誤寫 live store。

**Boundary**: 本票處理 config schema/resolver 的 project scoping 與 live migration；不重做 [[CC-488]] 的 Codex hook/session/update routing，也不把多 repo memory 合併成一個共享資料庫。CC-488 的三 host 驗收只證明「同一 repo 跨 host」一致，不能當成「跨 repo 共用同一 dir」的授權。

**Requirement**:
1. explicit config 必須以 stable project identity 選址（例如 project-key keyed mapping 或等價 repo-scoped section），不得在未匹配 repo 時套用另一專案路徑。
2. unmatched repo 應回到自身 legacy discovery 或明確 unavailable；matched explicit path 失效仍維持 fail closed，不得退回另一 repo/native store。
3. 定義舊 `dispatch.memory_dir` 單值的相容與 migration 規則；在多 repo 環境不得繼續默認為全域 override，doctor/config lint 必須能指出 unsafe legacy-global 設定。
4. 以 pm-dispatch、JapanJob、qa-testing-rules 三個不同 project key 做 isolated + live read-only E2E，證明同 repo Claude/Codex/OpenCode 仍同址、不同 repo 不同址；append 測試必須以 filesystem diff 證明零 cross-project write。

**Immediate safety note**: 在本票落地前，`dispatch.memory_dir` 只能視為 single-repo/single-purpose config；多 repo 操作不得把它當成安全的 machine-wide default。測試一律用 `PM_DISPATCH_CONFIG_FILE` 隔離，不得讀取 operator live config。

**Implementation (2026-07-15)**: config schema 已改為 `memory.projects.<stable-project-key>.dir`；`pmctl memory config set|migrate|lint` 提供原子管理、legacy-global 診斷與可重複 migration。strict resolver 對舊 global key 回報 `config-legacy-global` / exit 3，matched invalid path 維持 fail closed，unmatched repo 回到自身 legacy 或 unavailable。完善稽核另補上原實作未封閉的 compatibility fallback：`memory dir`、doctor、shard、rebuild-summary、direct `context --source memory` 與 installer/migrator discovery 現在共用 explicit-selection validity helper；invalid matched/env target 不得讀寫 legacy store，doctor 以 `resolution_issues` 回報來源與原因。isolated regression 已擴為三個 project key、project-scoped 四 host continuity、maintenance/context 零 fallback write；live read-only probe 證明 pm-dispatch 走 scoped config，JapanJob 與 qa-testing-rules 各回自身 legacy，config lint 0 issues。Claude standard gate `gate-20260715-032942-90cd0b` 使用明確 `--test-cmd` 後 GO（critic approve、qa-tester pass、architecture-reviewer approve）；gate 後 authoritative full suite 79 passed、0 failed、0 skipped。

**Acceptance**: 三 repo resolve 的 project key 與 memory dir 對應正確；跨 host 同 repo continuity 不退化；invalid matched config fail closed；unmatched repo 不使用 pm-dispatch memory；doctor/config diagnostics、memory/pm/guard regressions與 live migration evidence 全綠。

**See**: pr:#406

**Source**: CC-488 Claude full-tier gate R1 risk/QA findings；2026-07-14 live probe confirmed JapanJob (`01a9ed...`) and qa-testing-rules (`100334...`) both resolved to pm-dispatch memory through the global config value.

---

## CC-491 — PR-gate pre-flight 機械式 evidence 與 reviewer reuse contract ✅ 2026-07-15

**Problem**: `pr-gate.sh --test-cmd` 目前只把 pre-flight 結果以 `Pre-flight test run: pass|fail` 提供給 reviewer，沒有傳遞實際 command、selected suites、逐 suite 結果或被驗證工作樹的 fingerprint。QA reviewer 因而無法判斷哪些 behavioral units 已有可信證據；即使 pre-flight 已通過，仍可能手工列舉相同 suite 再跑一次。`gate-20260714-145345-2998745` 中 9 個已通過的 suite 被 QA 重複執行，部分因 180 秒 timeout 又重跑，最終單一 sequential reviewer session 耗盡 1200 秒，只完成 critic、留下 inconclusive partial artifact。

**Boundary**: 本票建立 pre-flight producer → PR-gate → reviewer 的 evidence/reuse contract；不重寫 [[CC-481]] 的 direct-impact planner、不把 authoritative full suite 搬回 gate lifecycle，也不禁止 reviewer 對「既有 evidence 未覆蓋」的新行為做最小補充驗證。

**Requirements**:
1. 每次 pre-flight 必須產生 versioned、machine-readable result。通用必填核心只包含經安全處理的 command identity、exit status、started/finished time、timeout 與 log path/digest；不得要求一般 repo 的 `npm run test`／`go test ./...` 等指令實作 pm-dispatch 專用 producer。使用 `scripts/run-tests.sh` 時才附加 selection mode、planner 自動推導的 changed paths、selected suites、逐 suite pass/fail/timeout/duration，以及 aggregate status；changed paths 不是使用者輸入欄位。
2. basic result 與 reusable evidence 必須分層：沒有受測內容 identity 的結果仍是有效 basic artifact，但標為 `reusable:false`；只有 gate 要主張 PASS 仍為 current／可避免重跑時，才必須自動綁定 subject fingerprint。Git repo/base/head 僅為可選 provenance，不是通用 result 必填。pre-flight 後若 fingerprint 對應的 tracked 或 untracked 內容改變，PR-gate 不得把舊 PASS 呈現為 current evidence。
3. PR-gate 必須機械驗證 result schema、artifact digest、fingerprint 與實際 pre-flight exit status，再把結構化 evidence 摘要及 artifact pointer 放進 reviewer brief；不得只由自然語言宣稱 `pass`，也不得要求 reviewer 從自由格式 log 猜測已跑項目。
4. QA reviewer 收到 current structured PASS evidence 後，必須先建立 behavioral-unit → existing-suite evidence 對照；已涵蓋 suite 不得 reflexively rerun。只有 evidence 未涵蓋、stale/invalid 或具體 flake 疑點時才能補跑最小 suite，且須在結果中記錄 gap、理由、command 與新增 evidence。generic command 的 coverage 明確標為 opaque/advisory：QA 可引用 aggregate PASS，但無法確認 behavioral coverage 時仍可執行最小 repo-native 補充驗證，不保證 0 次重跑，也不得偽稱 suite-level reuse。
5. Reviewer 不得以手寫 `for`/`&&` 清單取代 repo planner，也不得在 source working tree 建立 `.qa-test-*` 等暫存輸出；補充測試應使用 repo runner 的 selection/parallelism contract，輸出歸 gate run artifact directory。單獨指定一個 suite 時才允許 sequential execution。
6. detached/foreground、artifact relocation 與 timeout 路徑都必須保留同一 evidence schema；partial／timeout gate 要能指出 pre-flight 已完成、哪些 reviewer 額外執行了什麼，以及重複 suite 數量，不得把 partial artifact 誤當 GO。

**Acceptance**:
- focused pre-flight 透過 `run-tests.sh` 後，reviewer brief 可機械讀出 changed paths、selected suites、逐 suite結果與一致的 tree fingerprint；QA 對完全涵蓋且 current 的 PASS evidence 執行 0 個重複 suite。
- 新增一個未被 planner mapping 涵蓋的 behavioral unit 時，QA 只補跑能覆蓋該 gap 的最小測試並附理由；不得重跑其餘已通過 suite。
- pre-flight 後修改 tracked 或 untracked 受測內容會使 evidence 判為 stale，gate/reviewer 不得 reuse 舊 PASS。
- generic 不支援 rich result 的 `--test-cmd` 仍有可驗證的 basic artifact，且不需修改指令或採用 pm-dispatch 專用格式；明確標示 coverage opaque/advisory，不偽造 selected-suite evidence，也不承諾 QA 0 次重跑。
- regression 覆蓋 pass/fail/timeout、artifact tamper、tree drift、run-dir relocation，以及本次「9 個 suite 被重跑導致 reviewer timeout」案例。

**Source**: 2026-07-14 `gate-20260714-145345-2998745` post-mortem；pre-flight 已 PASS，但 brief 僅提供布林狀態，QA 重複執行相同 focused suites並使 sequential full-tier gate timeout／inconclusive。

**Outcome**: 已完成 portable basic evidence 與 structured suite evidence 分層；一般 repo 可維持原有 `npm run test` 等指令而不採用專用 producer，Git provenance 為選填。pm-dispatch runner 會自動輸出 planner-derived coverage、逐 suite 結果與 subject fingerprint，gate 對 tracked/untracked drift、malformed artifact、timeout 與 tamper fail closed；QA evidence accounting 保留 generic opaque evidence 的最小補充驗證權，同時禁止無理由重跑 current structured PASS suites。PR gate GO，authoritative full suite 79 passed、0 failed、0 skipped。

**See**: pr:#408

**Cross-link**: [[CC-470]], [[CC-481]], [[CC-485]].

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

## CC-393 — design: portable-skill-substrate — CLI-agnostic skill 控制層 🟢 someday

**Type**: design seed（想法捕捉；非 milestone 承諾）

**Thesis（session 2026-06-16）**: pm-dispatch 從 dispatch agents 升級為 dispatch **skill-guided agents**。skill = 平台中立的 portable Markdown contract（方法）、adapter = 平台轉譯層、core = 管 task/context/permission/verify/memory、tool layer = 權限邊界。

**Principles**: capability-matching 非平台名；skill 不執行/不持狀態/不知平台；evidence-based completion；runtime 注入非全域安裝。

**Key caveat**: 多數能力 pm-dispatch 已獨立長出——adapter manifest（[[CC-372]]）、post-verify 唯一驗證者（[[CC-386]]）、manifest-driven guard（[[CC-374]]/[[CC-375]]）。本票是替既有控制層**命名/索引**，不是補洞。

**Highest-leverage subset（control skills）**: `guard-aware-brief`（brief 帶 relevant controls + expected guards + completion condition）、`guard-result-review`（guard pass/fail → workflow decision，不改狀態）、`markdown-drift-audit`（Markdown ↔ script ↔ template ↔ core 漂移）。閉環：rule → brief → guard → evidence → state decision。

**Minimal landing**: 不做 marketplace/全域安裝/skill DSL；只做 3 個 control skill + thin Portable Skill v0 frontmatter。

**Boundaries**: skill 不跑 shell、不查 DB、不改 task status、不繞 guard、不當 workflow engine。

**Resume trigger（2026-07-15 三方 multi-model synthesis）**: 三個獨立 executor 分析一致認為現階段是平台化早熟；待 [[CC-015]] 等首批高命中率 skill 落地並累積 2-3 次真實重複使用證據後，再評估是否需要這層跨 CLI substrate。

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

**Status note (2026-07-15 CC-489 三方 multi-model synthesis）**: 重新定位為 harness/skill 分類下第一個高命中率試點 skill；不再落地為 slash command，改落地於 `skills/systematic-debugging/SKILL.md`（progressive disclosure，thin pointer 風格，比照現有 `skills/dispatch-brief`、`skills/pr-gate-review`）。
**Problem**: debug 工作流目前無標準化流程，每次偵錯方式不一致，容易遺漏根本原因分析。
**Why**: 結構化偵錯步驟（reproduce → isolate → hypothesize → verify → fix → regression test）有助於複雜 bug 分析；同時是驗證「skill = 可替換工作方法、非 workflow engine」定位的第一個實例。
**Requirement**: `skills/systematic-debugging/SKILL.md`，提供結構化偵錯步驟；不執行 state transition、不繞過 guard。
**Sequencing**: 待 [[CC-493]] 升級規則票定案分類判準後再落地，避免格式先於規則。

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
**Resume trigger（2026-07-15 三方 multi-model synthesis）**: codex/opencode 分析一致認為此票是 skill 平台化早熟的具體例子（自動偵測+產生 skill 草稿=雛形 marketplace）。除依賴 CC-027/CC-025 外，另需 [[CC-493]] 升級規則票定案，且草稿產物目標應是 `skills/<name>/SKILL.md` 而非 `commands/<draft-name>.md`。
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
**Resume trigger (2026-07-15 三方 multi-model synthesis)**: 同 CC-026，屬 skill 平台化早熟範疇；待 [[CC-493]] 升級規則票定案後再評估是否需要，且落地目標應是 `skills/` 而非 `commands/skill-refine.md`。
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

**Resume trigger（2026-07-15 三方 multi-model synthesis）**: 目前僅 2 個 skill，schema/validator 屬 premature optimization。待 skills 數量 ≥5 且已有跨 host consumer 實際使用、或已觀察到具體 discovery/誤用事故時才 reopen；在此之前維持純 prose。

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

## CC-493 — Prompt→Skill→Command→Harness 升級規則文件化 🟢 someday

**Problem**: 使用者一篇論述主張 pm-dispatch 已從「加幾個 skills」演化為專用 coding-agent 控制平面，三層疊加：原生 harness → pm-dispatch 控制面 → 可替換 skills。經 codex/opencode/project-pm(fable) 三個獨立 executor 各自分析同一份論述並比對 repo 現況後一致指出：這個三層定位大致成立，但「什麼時候該用哪一層」目前完全沒有文件化的判準——`commands/` 下混雜了 workflow entrypoint（`pm.md`/`pr-gate.md`/`ship.md`）與純方法性內容（`using-git-worktrees.md`/`research.md`/`pre-impl.md`），`docs/CONCEPTS.md` 甚至把 slash command 直接稱為「skills」，而 `skills/` 目錄本身只有 2 個真正的 `SKILL.md`。

**Why**: 沒有分類判準，新功能會持續依「就手」而非「該不該」落點，重演 command/skill 術語混淆，也讓 CC-015/CC-026/CC-054 這類 skill 相關票的產物定位（`commands/*.md` vs `skills/*/SKILL.md`）反覆漂移。這是三方一致認為成本最低、槓桿最高的第一步。

**Requirement**:
1. 撰寫一份判準文件（建議 `docs/CONCEPTS.md` 新增小節，或獨立 `docs/policies/skill-command-harness.md`），明文四級判準：
   - 第一次出現、低頻、無副作用 → 停在 prompt，不留任何檔案。
   - 跨 repo/跨 session 重複 2–3 次、可中斷恢復、不涉權限邊界 → 提煉為 `skills/<name>/SKILL.md`（thin pointer，不執行 state transition、不繞 guard）。
   - 需要使用者主動輸入 `/foo` 啟動、或需要參數解析 → `commands/<name>.md`（可以只是 skill 的啟動包裝）。
   - 需要 hard enforcement、持久狀態、機械 evidence 或 lifecycle 控制 → 只能落在 `pmctl`/`core/`/guard hook。
2. 盤點現有 `commands/`、`skills/`、`agents/` 目錄逐項對照此判準，列出「保留原狀」vs「建議遷移」清單（不在本票直接搬檔案）。
3. 修正 `docs/CONCEPTS.md` 中把 slash command 稱為「skills」的用詞混用。
4. 依此判準回頭修正 CC-015/CC-026/CC-054 的產物定位描述（已在各票加註依賴本票）。

**Non-goals**: 不在本票內實際搬遷任何 `commands/`/`agents/` 檔案到 `skills/`；不建立 skill schema/validator（見 [[CC-357]]）；不建立 skill marketplace 或 DSL（見 [[CC-393]]）。

**Source**: 2026-07-15 使用者提供「harness/skill/pm-dispatch 三層定位」論述，經 `pmctl dispatch run --adapter codex`、`--adapter opencode` 與 `project-pm`(model: fable) 三方獨立分析收斂。

**Cross-link**: [[CC-015]]、[[CC-026]]、[[CC-054]]、[[CC-357]]、[[CC-393]]、[[CC-489]]。

## CC-494 — design: executor 局部設計裁量權 envelope 🟢 someday

**Type**: design seed（三方分歧追蹤票；非 milestone 承諾）

**Problem**: 「PM thinks / executor implements」原則對控制 scope 有效，但論述指出執行階段常發現既有 API 不符預期、需要小重構、測試暴露 edge case；若 executor 完全不能做局部設計判斷，會變成「發現問題 → blocked → 回 PM → 改 brief → 重新 dispatch」，安全但昂貴。經 codex/opencode/project-pm(fable) 三方獨立分析同一份論述後，對此點出現 2:1 分歧：

- **codex**：建議界線是「executor 不得擅自擴大產品/API/資料模型/權限設計的影響面，但可在既有契約內處置必要的小重構、相鄰 call-site、一致性修補與測試 edge case；超出 brief 的設計決策才回報 blocked」。
- **project-pm(fable)**：建議把此裁量權從 Rule B 的散落 prose 慣例升格為 dispatch brief schema 一級欄位，例如可選的 `design_latitude:`。
- **opencode**：不同意現行邊界過度僵硬——認為 `dispatch_handover_v1` 的 `isolation_level`/`executor` 欄位、post-verify 只驗結果不約束實作路徑，已經給 executor 充分空間；「blocked → 回 PM」在目前設計中更多是 scope control 的 feature 而非 bug。

**Why**: 三方對「現況是否已足夠」沒有共識，但都同意若要動，應該是「限制設計影響半徑」而非「禁止所有設計」。這是一個會影響 dispatch brief schema 的結構性改動，值得獨立追蹤而非在這次 backlog 整理中順手定案。

**Requirement**（留待展開票時定案，此處僅列候選方向）：
1. 評估是否需要在 `dispatch_handover_v1`/executor report contract 新增欄位（如 `design_latitude:` 或 `architectural_conflicts[]`），或維持現行 prose-only 慣例（Rule B minimum-list principle）。
2. 若新增欄位，需明列「executor 可自行處理」（局部/可逆/符合 acceptance 的實作判斷）vs「必須 halt 回報 PM」（public API、schema migration、permission、跨模組架構、scope/成本承諾）的具體邊界。
3. 若決定不新增機制，需把現行 prose 慣例（Rule B）在 `docs/dispatch-brief.md`/`docs/executor-contract.md` 中明確化，降低新 contributor 誤讀風險。

**Non-goals**: 不預設本票會採納 codex/fable 的新欄位提案；不在此票修改 `core/schema/brief.schema.json`（若決定新增欄位，另開實作票）。

**Source**: 2026-07-15 三方（codex/opencode/project-pm fable）multi-model synthesis 對同一份「harness/skill/pm-dispatch 三層定位」論述的獨立分析分歧點。

**Cross-link**: [[CC-489]]、`docs/dispatch-brief.md`、`docs/executor-contract.md`。

## CC-495 — `pmctl dispatch cancel <run_id>`：detached run 中途終止機制 🔵 active

**Problem**: `pmctl dispatch run --lifecycle detached` 有 `run`（啟動）與 `wait`（等待完成），但沒有任何方式可以在使用者發現 executor 卡住、跑錯方向、或需要中途喊停時主動終止一個進行中的 run。現況只能手動找到並 `kill $(cat <run_dir>/<run_id>.supervisor.pid)`——這個路徑完全沒有文件記錄，且：
1. `_pmctl_dispatch_launch_supervisor`（`scripts/lib/pmctl-dispatch.sh:826`）用 `detached_launch_under_setsid` 啟動 supervisor，若只 kill `.supervisor.pid` 記錄的單一 pid，底層真正在執行的 adapter CLI 子行程（在其自己的 process group 內）不保證被連帶終止，可能留下孤兒 process（性質類似 CC-487 觀察到的 CI 殘留 bash process）。
2. `core/policy/dispatch-states.yaml` 已定義 `cancelled` 為合法的 dispatch-level terminal state（`pending`/`in-progress` 均可轉入），但 `grep -rn "cancelled" scripts/lib/*.sh scripts/*.sh` 沒有任何非測試程式碼寫入這個狀態——schema 已預留位置，實作完全空白。
3. `core/schema/run.schema.json` 的 `state` enum（`pending`/`dispatched`/`verifying`/`ok`/`partial`/`failed`）與 `core/policy/run-states.yaml` 也都沒有 `cancelled`，run-level 狀態機需要同步補上，否則 dispatch-level 的 `cancelled` 無法對應到底層 run 的真實終止原因。
4. 手動 kill 不會產生任何 event（`events.jsonl` 無 `run.cancelled`/`dispatch.cancelled` 記錄），dispatch record 會永遠卡在 `pending`/`dispatched` 狀態，沒有機械證據區分「使用者主動中止」與「跑到一半當掉/timeout」。

**Why**: 語意上刻意選 `cancel` 而非 `stop`——`stop` 暗示「之後可以續跑/resume」，但一個 executor run 中途被打斷後，brief 可能只執行到一半、檔案可能改到一半，狀態不完整、不安全恢復；`cancel` 精確表達「終止且結果不可信，需重新 dispatch」這個唯一合理語意，避免使用者誤以為存在 pause/resume 能力。這也是今天稍早 CC-489 三方分析點出的「控制面宣稱可審計/可恢復，但完成判定的對稱面（中止）完全沒有機械證據」的具體落地缺口。

**Requirement**:
1. `pmctl dispatch cancel <run_id> --cd <work_dir>`：
   - 讀取 `<run_dir>/<run_id>.supervisor.pid`，對其**process group**（而非單一 pid）送 `SIGTERM`，給予短暫 grace period 後對仍存活的成員送 `SIGKILL`（沿用 CC-470 既有逾時止血機制的 kill 慣例，不重新發明）。
   - 若 pid file 不存在或對應 process 已不存在（run 已自然終止），fail-loud 並回報「run 已非 in-flight 狀態」，不誤寫終止記錄。
   - 終止成功後：透過既有 `pmctl_dispatch_write_transition` 寫入 dispatch record 的 `cancelled` 終態，並寫入對應的 `run.cancelled`/`dispatch.cancelled` event（比照現有 `run.ok`/`run.failed` 的 event 結構）。
   - 清理 sentinel/pid file，避免殘留讓後續 `pmctl dispatch wait` 誤判。
2. `core/policy/run-states.yaml` 與 `core/schema/run.schema.json` 的 `state` enum 補上 `cancelled`（作為 terminal state，仿照 `dispatch-states.yaml` 既有定義），並更新 transitions 表（`dispatched`/`verifying` 可轉入）。
3. `pmctl dispatch wait <run_id>` 遇到 `cancelled` 終態需明確回報（非 0 exit code，訊息與 timeout/failed 區分），呼叫端才能分辨「使用者主動終止」而非「adapter 失敗」。
4. 為了讓使用者知道有哪些 run_id 可以 cancel，補一個最小化的發現機制（例如讀取 `.dispatch-results/` 目錄下尚未終態的 record 列出 run_id/adapter/created_ts）；不需要完整的 `pmctl dispatch list` 子命令設計，只要求 cancel 的使用路徑不必靠使用者自己肉眼翻 run_id。
5. `docs/executor-contract.md` 補上取消流程的文件段落：何時該用、行為保證（process group termination、無 resume）、與 timeout 自動終止的差異。

**Acceptance**:
- 對一個真實 in-flight 的 detached codex/opencode/claude run 呼叫 `pmctl dispatch cancel`，底層 adapter process 與其子行程全數終止，`ps` 確認無孤兒殘留。
- dispatch record 終態為 `cancelled`，`events.jsonl` 有對應 event，`pmctl dispatch wait` 對已 cancel 的 run_id 回報明確、與 failed/timeout 不同的訊息。
- 對已經自然終止（ok/failed/partial）的 run_id 呼叫 cancel，fail-loud 且不覆寫既有終態。
- `scripts/test-dispatch-lifecycle.sh` 新增對應案例；既有 dispatch lifecycle 測試全綠。

**Non-goals**: 不做 pause/resume（語意上已排除）；不做完整的 `pmctl dispatch list` UI/篩選功能（見第 4 項，僅最小發現機制）；不處理 non-detached（foreground）dispatch 的取消——foreground 呼叫端本來就能用 Ctrl-C 直接中斷。

**Source**: 2026-07-15 使用者在 CC-489 三方 multi-model synthesis 收斂後，回想起「pmctl executor 相關內容目前沒有停止的行為」並要求確認；經 grep `core/policy/dispatch-states.yaml`、`core/schema/run.schema.json`、`scripts/lib/pmctl-dispatch.sh` 確認 `cancelled` 狀態存在於 schema 但無任何實作，`.supervisor.pid` 未被任何子命令消費。使用者明確要求以 `cancel`（而非 `stop`）作為指令名稱，理由是中途終止的 run 不具備可恢復語意。

**Cross-link**: [[CC-470]]（既有逾時止血 kill 機制可沿用）、[[CC-487]]（孤兒 process 殘留的既有觀察案例）、[[CC-489]]（三方 multi-model synthesis 脈絡）、`docs/executor-contract.md`。

## CC-496 — Codex command guard 單次 bypass transport 修復 ✅ 2026-07-15

**Problem**: `guard-pm-bash.sh` 的 deny message 指示在確認風險後使用 `PM_GUARD_PM_BASH=off` 做 one-turn bypass，但 Codex `PreToolUse` hook 會在 Bash 解讀 command-local environment assignment 前執行。實際輸入 `PM_GUARD_PM_BASH=off git branch -D ...` 時，hook process 看不到該變數，仍會拒絕命令，提示與可達行為不一致。

**Requirement**:
1. Codex command hook 必須把 command 開頭、大小寫完全一致的 `PM_GUARD_PM_BASH=off` 提升為該次 hook invocation 的 bypass。
2. assignment 出現在 command 中段、值不是 lowercase `off`，或下一個 hook call 都不得繼承 bypass。
3. bypass 必須沿用既有 `decision=bypass` audit，不另開未稽核路徑。
4. 修正後重新執行已確認為 merged 的 local branch cleanup 與 worktree prune。

**Acceptance**: exact leading assignment 對 denylisted command allow 且留下 bypass audit；同一 command 下一次未帶 assignment 時恢復 deny；中段與錯誤大小寫 assignment 均 deny。

**Outcome**: Codex hook 現在只把 command 開頭、大小寫完全一致的 `PM_GUARD_PM_BASH=off` 提升為當次 hook environment；中段與錯誤大小寫仍 deny，下一次呼叫不繼承。Codex host suite 43/43 通過，Claude gate `gate-20260715-044654-7da04e` 使用明確 `--test-cmd` 後 GO；live acceptance 已成功刪除所有確認 merged 的舊 local branches 並 prune worktree metadata。

**See**: pr:#407

**Source**: 2026-07-15 清理 PR #406 合併後的 local branches 時，repo guard 兩次攔下已確認風險的 `git branch -D`；第二次已使用提示指定的 inline `PM_GUARD_PM_BASH=off`，仍因 Codex hook transport 時序而被拒絕。
