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
| CC-461 | ⚠️ partial 2026-09-06 | `doctor.sh --fix`：第一刀 `scripts-executable` 白名單已交付；後續 whitelist／host-specific fix 只在有真實摔倒點與冪等/可逆/不碰使用者內容證據時擴充，不再當成尚未實作的功能 | ops/install | 2026-07-07 | pr:#575 | P3 | — |
| CC-462 | 🟢 someday | e2e 可拋棄資源紀律：前綴命名 + registry JSON + result artifact；掛在 CC-449 e2e 新 phase 之後，與 CC-447 live smoke 共用同一 registry（2026-07-07 openyida 跨專案分析） | ops/test | 2026-07-07 | — | P3 | — |
| CC-463 | 🟢 someday | `pmctl batch` 泛用批次執行原語；依賴 CC-460（合法性驗證來源）；新注入面須過 security-reviewer（2026-07-07 openyida 跨專案分析） | arch/process | 2026-07-07 | — | P3 | design |
| CC-464 | 🟢 someday | `pmctl ticket draft --from <notes>`：隨手筆記→結構化 backlog 票草稿；依賴 CC-286（prefix-generic next-id，⏸ deferred 尚未排程）；review-first 邊界獨立設計，CC-054 僅供鬆散參照非直接前例（2026-07-07 openyida 跨專案分析） | ux/process | 2026-07-07 | — | P3 | — |
| CC-494 | 🟢 someday | design: executor 局部設計裁量權 envelope——在 dispatch brief / executor contract 定義「可自行處理的局部設計」與「必須 halt 回報 PM」的邊界（例如新增 schema 欄位 `design_latitude`/`architectural_conflicts`）；三方 multi-model synthesis 2:1 分歧（codex/fable 認為現行邊界過度僵硬需要新機制，opencode 認為現行 `isolation_level`/executor 欄位已足夠彈性），本票僅追蹤決策、不預設結論（2026-07-15） | schema/process | 2026-07-15 | feedback:2026-07-15 | P3 | design |
| CC-506 | ⏸ deferred | retrieval evidence-gated 收緊：shadow 評測（coverage@5、critical miss、read reduction、outcome parity）達標後才收緊 broad-Read 指引並重評 [[CC-340]] resume 條件；前置 = [[CC-505]] Ph2 shipped + ≥20 真實任務證據 | memory/DX | 2026-07-20 | — | P3 | retrieval |
| CC-516 | ⏸ deferred | evidence-gated thin delivery wrapper 評估；只組合既有 primitives，不建立 workflow engine/FSM | ux/process | 2026-07-23 | — | P3 | spike |
| CC-534 | 🟢 someday | `commands.tsv` 驅動 CLI routing、safe handler dispatch 與 lazy module loading | arch/DX | 2026-07-30 | feedback:2026-07-30 | P2 | design |
| CC-535 | 🟢 someday | detached-launch 上的 supervised-run primitive + versioned JSON run-spec | arch/ops | 2026-07-30 | feedback:2026-07-30 | P2 | design |
| CC-537 | 🟢 someday | suite metadata 與 changed-path impact mapping 資料化；full suite 維持 authoritative | ops/test | 2026-07-30 | feedback:2026-07-30 | P2 | hygiene |
| CC-539 | 🟢 someday | state `layout.yaml` build-time authority + generated runtime constants | arch/schema | 2026-07-30 | feedback:2026-07-30 | P2 | design |
| CC-546 | ⏸ deferred | standalone Gate distribution／copy parity follow-up：獨立定義 bundle schema、generation、installed parity 與 support boundary；不回併 Linux/WSL2 canonical module extraction | arch/gate | 2026-08-14 | — | P2 | reuse-debt |
| CC-466 | ⏸ deferred | 記憶卡片生命週期閉環：expires_at 執行 + 關窗式 supersede + usage sidecar 休眠偵測 + doctor→distill 接線；僅在 CC-467 證明 stale/dormant card 已形成實際問題時啟動 | memory | 2026-07-07 | feedback:2026-07-07 | P2 | retrieval |
| CC-468 | ⏸ deferred | dispatch brief 帶 memory 約束與信任邊界；完成 CC-465→CC-467 後，僅在 usage evidence 證明有價值時啟動 | ops/memory | 2026-07-07 | — | P2 | retrieval |
| CC-011 | 🟢 someday | sync-memory.sh + install 選項：symlink memory 到雲端資料夾實現跨裝置共用 | ux/memory | 2026-05-14 | — | — | — |
| CC-012 | 🟢 someday | SessionStart hook：session 啟動時 pull 最新 memory（git/rsync）確保跨裝置同步 | ux/memory | 2026-05-14 | — | — | — |
| CC-018 | 🟢 someday | Codex quota 自動追蹤 + rate-limit 路徑統一（吸收 CC-269）：寫到 `~/.local/share/pm-dispatch/state/rate-limits.json`；解析 API response headers；token-usage.sh 加 Codex pool 顯示 | ux/token | 2026-05-14 | — | P3 | — |
| CC-023 | ⏸ deferred | `coupling-reviewer`：PR gate 加入語言感知耦合分析（dependency-cruiser/gocyclo/coca） | ops/gate | 2026-05-14 | — | — | — |
| CC-026 | 🟢 someday | `/skill-distill`：偵測重複工作流，產出草稿 skill .md | ux/memory | 2026-05-15 | — | P3 | — |
| CC-033 | 🔵 active | public posture reconciliation：README/協作表面 + **即刻** git history 損害盤點（audit 先行；其餘 v0.12.0） | process | 2026-05-15 | — | P2 | — |
| CC-035 | 🟢 someday | install/uninstall-guards basename+scripts/ heuristic：未覆蓋另一工具也在 scripts/ 下同名 hook 的 collision edge case | ops | 2026-05-15 | pr:#53 | P3 | — |
| CC-038 | ⏸ deferred | Windows/cross-platform 鎖機制：`flock` Linux-only，未來支援需替代方案（parked: CC-370） | ops/portability | 2026-05-15 | — | — | oss |
| CC-044 | ⏸ deferred | `tool-trace.jsonl` 三階段升級（吸收 CC-027b/c）：Phase 1 rotation/retention；Phase 2 bounded error counter；Phase 3 async validation | ux/memory | 2026-05-15 | — | — | — |
| CC-045 | ⏸ deferred | brief timeout heuristic：依 target repo playbook depth 設 timeout（not only edit size）；brief 可加 skip-playbook-reread 短路指令 | process/DX | 2026-05-16 | — | — | — |
| CC-054 | ⏸ deferred | CC-025 M2 — `/skill-refine` diff generation and Claude-assisted refinement；scope deferred when CC-025b was closed in `feat/cc039-cc025b-v2` | ux/memory | 2026-05-18 | pr:#67 | — | — |
| CC-063 | ⏸ deferred | Trace/token/gate metrics dashboard：`.agent-trace/*.jsonl` + `rate-limits*.json` + `.gate-results/*.md` 視覺化 per-session token、gate pass rate、routing_log 趨勢 | ux/ops | 2026-05-18 | — | P3 | — |
| CC-064 | ⏸ deferred | Project bootstrap wizard：互動式 `ops/setup/setup-project.sh --init` 引導新 repo 建立 memory、rules、PM schema | ux | 2026-05-18 | roadmap:CC-031 | P2 | — |
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
| CC-227 | ⏸ deferred | **[refactor: extract yaml-frontmatter lib + shared validation helpers]** 把 `check_frontmatter()` 與 shared helpers（dq-escape/adjacent-quote/empty-entry，原 CC-226 範圍）一起搬到 `tools/lint/lib/yaml-frontmatter.sh`；`lint-frontmatter.sh` 成薄 CLI 包裝；`doctor.sh` 可 source lib 取代 fork subprocess。CC-226 已合併入本票。 | arch/reuse | 2026-05-22 | pr:#119 | P3 | oss |
| CC-236 | 🟢 someday | **[pmctl report — away-from-keyboard state roll-up]** A `pmctl report` rolling up state since last invocation (open tasks, blockers, last gate verdict, recent runs). Deprioritized 2026-05-22: the maintainer does not run agents unattended, so a "morning report" time-gap framing has low current need; on-demand status is already part of the `pmctl` surface (CC-215). Revisit if the workflow ever includes overnight / away dispatch. | ux | 2026-05-22 | — | — | design |
| CC-253 | 🟢 someday | **[CC-209 Phase 2: codegraph benchmark on representative target codebase]** Phase 1 (PR #151) verdict AMBER — codegraph install ✓ license MIT ✓ API ✓, but pm-dispatch (bash/markdown) isn't a valid test target (`62 unsupported language`). Phase 2 re-scope: user picks a TS/JS/Python/Go target codebase at brief time, index it via codegraph, run 3 representative queries against rg/git baseline, measure token + latency delta. Output: append `## Phase 2` section to `docs/spikes/cc209-codegraph-phase1.md` OR new sibling doc. Verdict per original CC-209 ticket: adopt / defer / reject for context-pack source (CC-232 / CC-237). | ops/token | 2026-05-24 | pr:TBD | P3 | spike |
| CC-259 | 🟢 someday | **[yaml.sh lib extraction]** Extract `_yaml_get` bash/awk helper and `case_yaml_parse` structural validator from `tests/shell/test-core-schemas.sh` into `tests/lib/yaml.sh` for reuse across test scripts; add independent test file `tests/shell/test-yaml-lib.sh` and wire into `run-all-tests.sh` + CI. Currently only used in `test-core-schemas.sh`; extraction deferred from CC-229 M1 PR to reduce gate surface. Trigger: second consumer in a new test script. | ops/test | 2026-05-25 | pr:TBD | P3 | — |
| CC-270 | ⏸ deferred | **[test: concurrent pmctl adapter generate guard]** Two simultaneous `pmctl adapter generate <same-name>` runs can race: the precheck+mkdir+trap sequence is not atomic. Blast radius: one run may delete another's partial output; reproducible by deleting `adapters/<name>` and rerunning. Deferred — single-developer workflow makes this low-probability; fix with atomic mkdir using `mkdir` exit-code guard when needed. | test/ops | 2026-05-28 | — | P3 | — |
| CC-273 | ⏸ deferred | arch: unified lifecycle hook event spec（`.pm-dispatch/hooks/<event>.sh`）；activate when second hook point beyond gate pre/post emerges | arch/gate | 2026-05-28 | — | P3 | — |
| CC-286 | ⏸ deferred | **[pmctl: prefix-generic next-id derivation]** `runtime/bin/pm-prep-snapshot.sh` derives `backlog_next_id` CC-only (it emits `CC-NNN`); under the working-set contract it scans BACKLOG.md + BACKLOG-ARCHIVE.md for the max, but only `CC-` IDs. A cross-repo next-id (other prefixes: JS-, PA-) must be prefix-derived and centralized in pmctl, scanning both working-set and archive. Retire pm-prep-snapshot's CC-hardcoded derivation when `pmctl backlog`/next-id lands. Surfaced by pr-gate critic+architecture on #186. | arch | 2026-05-30 | — | P3 | design |
| CC-306 | ⏸ deferred | **[arch: extend CC-233 layer enforcer to runtime-named data paths in scripts/]** Guard against re-introducing `.codex-*`/`.claude-*` DATA directories under scripts/ (the optional follow-up deferred from CC-298). | arch | 2026-06-01 | — | P3 | design |
| CC-340 | ⏸ deferred | knowledge index: embeddings/semantic-backend remainder（FTS/LIKE MVP 已由 CC-403 接管；本票保留 Khoj-class semantic accelerator，待 FTS ranking 不足時 resume） | memory | 2026-06-08 | — | P3 | retrieval |
| CC-342 | 🟢 someday | agent: debt-auditor — proactive tech-debt health scan（`agents/debt-auditor.md`；`pmctl audit <path>` 呼叫；PR-free 主動健康掃描，有別於現有 PR-focused reviewers） | process/DX | 2026-06-05 | — | P3 | design |
| CC-346 | ⏸ deferred | repo-index: cross-file ref tracking `file_refs` table（paused 2026-06-10；resume trigger: reuse-scan 進過 ≥2 份真 brief 且缺 ref 資料為瓶頸；屆時先 Phase a bash source） | ops | 2026-06-09 | — | P3 | design |
| CC-347 | 🟢 someday | pr-gate blast-radius analysis using CC-346 file_refs（blast_radius 清單注入 brief context；無 CC-346 index 時靜默跳過） | gate | 2026-06-09 | — | P3 | design |
| CC-348 | 🟢 someday | **[pmctl project-map: cross-file dependency graph visualisation]** `pmctl project-map [--format text/dot] [--from <path>] [--depth N]` — 以 CC-346 file_refs 表輸出 ASCII 樹狀（預設）或 Graphviz DOT 引用圖；標示 broken refs（to_path 不在 files 表）；無 index 時 exit 1 並提示 `pmctl context index`。 | ops/DX | 2026-06-09 | — | P3 | design |
| CC-352 | ⏸ deferred | **[codex-executor sandbox friction Pattern 1+2: apply_patch retry noise + Go module cache blocked]** issue:#173 Pattern 3（git commit blocked）已由 CC-272 pr:#245 吸收修復。剩餘：(1) apply_patch 中途失敗 self-retry 噪音 — brief 改拆小 hunk 加 unique context；(2) go build 時 GOPATH copy 被 sandbox 擋 — 文件化 GOPATH=/tmp/gopath 慣例。兩者均為 doc/convention fix。 | ops/DX | 2026-06-10 | — | P3 | — |
| CC-355 | 🟢 someday | knowledge index: HTML semantic chunking `<h1-6>`（trigger: .html file enters knowledge plane；plug into CC-354 per-format chunker seam） | memory | 2026-06-10 | — | P3 | design |
| CC-357 | 🟢 someday | **[skill as contract: machine-readable schema for skills]** 現有 skills/ 都是純 markdown prose（SKILL.md），沒有機器可讀的 input schema、output contract、tool_constraints、completion_condition。這使得 skill 無法被驗證、無法被工具自動發現、也無法像 dispatch_handover_v1 那樣由 validator 強制執行契約。本票引入 skill schema（YAML frontmatter 或 JSON sidecar），使 skill 具備：明確的輸入型別、輸出格式、允許/禁止工具清單、完成條件——平行於 brief-validate.sh 對 brief 的驗證角色。 | arch/DX | 2026-06-10 | — | — | design |
| CC-359 | 🟢 someday | concept: backlog-driven batch dispatch with worktree isolation（PM manages `git worktree` lifecycle；executor-agnostic；human-in-the-loop merge；PR-only output） | arch/ops | 2026-06-11 | — | — | design |
| CC-369 | ⏸ deferred | Windows state store 真實 ACL via icacls（parked: CC-370；border case relative to profile ACL protection） | ops/portability | 2026-06-13 | — | — | hygiene |
| CC-370 | ⏸ deferred | **[native Windows support deferred to post-core platform phase]** 核心功能開發期間正式只支援 Linux + WSL2（WSL2 視為 Linux）；原生 Windows Git Bash 非官方支援，使用者走 WSL2。理由是專注：開發期同時扛多平台會排擠核心功能（CI 只測 Linux，每次碰 Windows 都要人工驗證 + gate churn，見 #272/#273）。已合併的 portability 程式碼保留（綠且成本低），但不再新增 Windows 分支，直到核心定型（v0.5.0+）後的專屬平台階段。Parks: CC-038, CC-104d/e/f/g/j/k/r/s, CC-369。**See**: DECISIONS.md 2026-06-13 defer-native-windows-support-during-core-dev | ops/portability | 2026-06-13 | — | — | design |
| CC-377 | ⏸ deferred | adapter: Google Antigravity（`agy`）executor（DEFERRED：headless CLI 1.0.8 不成熟；resume: newer agy with `--output-format stream-json`；umbrella: CC-333） | arch/portability | 2026-06-13 | — | P2 | design |
| CC-390 | ⏸ deferred | codex dispatch trace-capture 強化（FD inheritance cold-start flake；fail-closed safe；resume: stable repro；umbrella: CC-333） | arch/portability | 2026-06-15 | — | P3 | design |
| CC-393 | 🟢 someday | design: portable-skill-substrate — CLI-agnostic skill 控制層（design seed after v0.6.0 N≥2；3 control skills + Portable Skill v0 frontmatter；umbrella: CC-333） | arch | 2026-06-16 | — | — | design |
| CC-435 | 🟢 someday | **[poll→通知機制 single-waiter guard：條件觸發，非既定後續票]** 只有在真正出現多個 waiter 需要同時等待同一個 run_id/gate_id 的場景時才拿出來討論；候選設計見 `docs/spikes/CC-433.md` Open risks（方案 A：`flock` 搶鎖+敗者退回輪詢；方案 B：per-waiter 專屬 fifo+supervisor 廣播）。CC-434 完成後重新盤點成本效益：輪詢 vs blocking read 在單一 waiter/數分鐘等待場景下資源消耗差距趨近於零，延遲改善（≤2s→近乎即時）對人在等 gate 結果無感，而兩個方案都要在安全敏感的 supervisor 檔案引入新 race condition，投資報酬率目前不足，故不排入既定實作，僅記錄設計供未來觸發條件成立時起步。 | arch/gate | 2026-07-02 | — | P3 | design |
| CC-447 | 🔵 active | onboarding 三 smoke：offline clean install + N-1 upgrade（v0.11.0，**✅ 已交付**）+ live dogfood（2026-10-24 第一輪完成：一個公開 repo、gate GO、13 次介入，`ship` 與 `QA_RULES_DIR` 缺席未跑，票維持 active） | docs/ops | 2026-07-04 | pr:#573 feedback:2026-10-24 | P2 | — |
| CC-472 | 🟢 someday | spike: antigravity（`agy` CLI）host 唯讀 probe——比照 CC-436/CC-448 階段 1 模式，實測 command 載入能力 + hook/plugin 機制 + 五個 capability enum 的 provider/confidence 判定，不落地 `hosts/antigravity/host.yaml`；排在 CC-445 通用 install/uninstall dispatcher 之後、與 CC-448 opencode 同批或緊接其後評估（N=3 驗證點） | arch/install | 2026-07-08 | — | P3 | spike |
| CC-568 | 🟢 someday | `/mem-distill` Case→Strategy 機械式提升：對 `episodes.jsonl` 既有結構化欄位做 count/cluster 門檻判定，取代逐次主觀「感覺像 pattern」的判斷；依賴 [[CC-567]] 的 outcome 證據決定是否值得做（2026-08-25 memory 架構設計討論） | memory/DX | 2026-08-25 | — | P2 | retrieval |
| CC-569 | 🟢 someday | `pmctl task` / `context pack` 擴充 working-memory 敘事欄位（`selected_memories`／`rejected_paths`／`blockers`／`next_action`）：延伸既有 schema，不新建第二個「現在在幹嘛」真相來源；依賴 [[CC-567]] 證明有價值後再排（2026-08-25 memory 架構設計討論） | memory/DX | 2026-08-25 | — | P2 | design |
| CC-570 | 🟢 someday | Fact/Case/Strategy `memory_function`／`memory_subtype` metadata 分類法：先蒐集 [[CC-567]] 的 applied/outcome 證據，再決定值不值得建分類機制——不憑直覺先建立稅務式標籤（2026-08-25 memory 架構設計討論；外部文章優先序建議相反，本 repo 刻意反過來） | memory/DX | 2026-08-25 | — | P3 | retrieval |
| CC-575 | 🟢 someday | test-governance Batch 1 存量遷移：把其餘 ~35 處 `pass "$name (... unavailable ...)"`（多在 `test-doctor.sh` 的 jq guard、也有 `test-core-schemas`／`test-install`／`test-pmctl-memory`／`test-runtime-lib-coverage` 的 `UNAVAILABLE:` 裸行）改用 case-level `skip()`。primitive 與 authoritative gate 已於 pr:#<TBD> 落地並遷移 6 個代表站點；本票只做剩餘機械遷移，不再動 harness/runner/schema | ops/test | 2026-08-28 | — | P3 | hygiene |
| CC-578 | 🟢 someday | config-surface authority 標記（[[CC-446]] Req 6 拆出）：每份 manifest／schema／registry／policy／layout spec（~44 檔：19 `core/schema/*.json` + 20 `*.yaml` + 5 `core/policy/*.tsv`）標記為 `runtime authority`／`build-time authority`／`parity/documentation spec`；runtime／build-time authority 必須有單一 consumer/generator 路徑與 drift check，不得一面宣稱 source of truth 一面維護等價手寫實作。多為逐檔判斷、多數需新增 drift 測試，是獨立多 PR 工程；與 [[CC-451]] 同批評估（runtime 從不驗證的 schema 不列 stable） | process/DX | 2026-08-30 | — | P2 | design |
| CC-581 | 🟢 someday | `gate_reviewer_protocol_verify` 的二次方 `block=` 累加（`runtime/lib/gate-result-verify.sh:651`）：逐行 bash 字串串接抽 fenced reviewer_result 區塊，對區塊行數 O(n²)。[[CC-579]] census 實測 bash 端非 gate 主成本（88% 在 jq），故列次要未動。無感但屬演算法級劣化，值得在有人為別因動到該函式時順手換 O(n)（`mapfile`＋`printf` 或單次 `awk` 切檔），維持 fence 巢狀／截斷／空區塊失敗語意與 `GATE_REVIEWER_PROTOCOL_DOCUMENT_ERROR` 值不變。獨立排程投報不足 | ops/gate | 2026-09-08 | — | P3 | — |
| CC-592 | 🟢 someday | **[qa-tester 的 codex sandbox 結構性地無法啟動真實 Windows process，導致任何需要真實 process 驗證的 gate finding 卡住]** 兩次獨立 gate dispatch（sequential 90s bound、parallel 120s bound）中，qa-tester 嘗試重新執行一個會啟動真實 Windows Job Object supervisor 的測試時，兩次都在整個 timeout 期間**零輸出**後逾時（exit 124）——同一測試由本機（非 sandbox）直接執行 5 次以上皆在 10 秒內通過。訊號（完全零輸出，而非部分進度）與 #609（AppContainer 阻擋 MSYS2 對全域 namespace 的存取）、#619（codex Windows sandbox 決定性拒絕 exec_command）同一類，但這次發生在 **reviewer 驗證路徑本身**，而非 gate 的 producer 端。目前僅能靠 `.gate-overrides.md` 逐案記錄 accepted risk 繞過（2026-09-27 CC-590 gate 過程中發現，兩輪 gate 皆命中同一訊號）。 | ops/gate | 2026-09-27 | — | P2 | spike |
| CC-602 | ⚠️ partial 2026-10-01 | **[context workflow-refresh 的 timeout-kill 有時會印出誤導的 `printf: write error: Permission denied`，而不是安靜結束]** GitHub issue #633；與 [[CC-596]] 相關但不是同一個問題（CC-596 只修暫存檔洩漏）。 | ops/portability | 2026-09-30 | pr:#653 | P3 | hygiene |
| CC-604 | 🟢 someday | **[`gate-scope.sh` 收尾整理：collector 過大、三處「檔案內有哪些 symbol」讀取邏輯重複、fixed-head 模式仍有每來源固定次數的 fork]** CC-599 審查（architecture-reviewer／critic）提出但刻意不併入該 PR 的後續：`_gate_scope_expansions_collect_into` 拆成 shell consumer 與 symbol call-site 兩個 per-source emitter；tracked／untracked／shell consumer 三種「一個檔案內出現哪些 symbol」的讀取視需要共用 helper；fixed-head 模式下每個來源對 12 個副檔名各做一次 `git cat-file -e`、每個 consumer 一次 `git show`（CC-599 實測 fixed-head 剩餘成本）。 | ops/gate | 2026-09-30 | pr:#647 | P3 | hygiene |
| CC-606 | 🟢 someday | **[`awk -v wanted="$key"` 會處理反斜線跳脫，`--tier`／`--mode` 這類 CLI 值可通過 policy 驗證卻與 bash 字串比較不一致]** [[CC-600]] 的 security-reviewer 指出的既有問題（非該 PR 引入）：`awk -v` 會展開跳脫序列，因此 `--tier 'expre\163s'` 或結尾帶反斜線的 `express\` 會被 `_gate_assurance_policy_lookup` 視為 `express`，但後續 `[[ $TIER == express ]]` 之類的 bash 比較不會。需本機 CLI 控制權，不是提權，屬驗證正規化不一致。修法：改用 `ENVIRON` 傳值，或在 lookup 前拒絕含反斜線的 key。 | ops/gate | 2026-09-30 | pr:#649 | P3 | hygiene |
| CC-607 | 🟢 someday | **[worktree 主 checkout 解析與 drive-path 判斷的收尾整理]** [[CC-601]] 審查提出但刻意不併入的後續：`_pmctl_worktree_main_root` 與 `_sw_main_repo_root` 近乎重複，應讓前者委派給 state-paths 的解析器（或共用一個 helper）；`portable.sh` 內解析根目錄的 `case [A-Za-z]:/*` 分支與三處 jq regex 尚未統一，其中 `gate-result-verify.sh` 的 jq regex 只接受 `X:/`，`host-doctor-primitives.sh`／`hosts/claude/lib/doctor.sh` 接受 `X:[/\\]`；測試輔助 `tests/lib/test-memory-config-fixtures.sh` 與 `tests/shell/test-pr-gate.sh` 仍有 `--git-common-dir` 加 `== /*` 的寫法；common dir 不是 `<root>/.git`（submodule、`--separate-git-dir`）時 `dirname` 會回傳其父目錄（與 POSIX 相同，但在 Windows 上先前碰巧走 fallback 而答對）。 | ops/portability | 2026-09-30 | pr:#651 | P3 | reuse-debt |
| CC-608 | ⚠️ partial 2026-10-23 | **[kill 時 context refresh 其餘寫入的 `write error`：辨識實際失敗的 fd，必要時才擴大保護]** [[CC-602]] 只靜音了 7 個 `$(...)` 內的 fallback `printf`，原始觸發條件未重現。其餘同一路徑上的寫入仍未保護：`pmctl_context_workflow_refresh_bounded` 的 `>&2` 進度行、`printf >> "$batch_sql"`、`_ctx_extract_symbols`／`_ctx_chunk_emit` 這類 `< <(...)` producer（CC-595 到 CC-598 之後是逐檔案的主要工作，critic 認為是現在最可能的殘留來源）、`pmctl-gate.sh` 等處的 `\|\| printf`。需要先重現（原生 Windows、`timeout -k` 殺受限 refresh，並以 `BASH_XTRACEFD` 或把 fd 1/2 導到已關閉的管線辨識失敗的 fd），再決定是 producer 的 `2>/dev/null`、子程序收到 TERM 後安靜退出，或移除剩餘逐檔案 `$(...)`。 | ops/portability | 2026-10-01 | pr:#653 pr:#724 | P3 | hygiene |
| CC-610 | 🟢 someday | **[lint：EXIT trap 處理函式（含其內部呼叫）所用的函式必須定義在 `trap ... EXIT` 之前]** [[CC-609]] 的缺陷型態可重現於任何提早安裝 trap 的 `set -u` 腳本，淺層檢查（只看 handler 名稱）會漏掉，因為 `qa_execution_finalize` 是從 handler 本體內被呼叫。需要追蹤 handler 本體的傳遞呼叫。架構審查建議記錄為後續而不放進 CC-609 的小修正。 | ops/test | 2026-10-01 | pr:#654 | P3 | hygiene |
| CC-612 | ⚠️ partial 2026-10-06 | **[`adapter_manifest_file` 每次呼叫都重新做 2 個 `$(cd -P && pwd -P)` 與 2 個 `adapter_manifest_scalar`，兩個 case 合計 37 次]** 同一份剖析（兩個 case 合計）：`adapter_manifest_file` 37 次、148 個行程；`adapter_manifest_runner_kind` 21 次、42；`adapter_manifest_dispatch_path` 7 次、35；合計約 225（約 6%）。呼叫端為 `executor-router.sh:84`／`:151`／`:155`／`:212` 與 `pr-gate.sh:548` 的迴圈。可行方向是依 `(repo-root, adapter)` 快取驗證結果，但該函式的 symlink／「不得逃出 adapters/」檢查是信任邊界，快取必須保留相同保證（例如以解析後路徑與 mtime 當鍵，或明確記錄「單次 gate 內快照」並由 security-reviewer 審查）。 | ops/gate | 2026-10-01 | — | P2 | hygiene |
| CC-614 | 🟢 someday | **[`gate-result-verify.sh` 的重複驗證占 pr-gate 行程數的約 23%，需要更細的剖析才能決定能否去重]** 同一份剖析（兩個 case 合計）：`gate-result-verify.sh` 各函式合計約 850 個行程（`_gate_reviewer_protocol_document_verify` 18 次 162、`gate_synthesis_protocol_verify` 6 次 144、`gate_reviewer_protocol_verify` 9 次 108、`_gate_reviewer_heal_empty_existing_evidence` 90、`gate_result_verify` 6 次 86 等），另有 `gate-structural-verify.sh` 的 `_gate_structural_schema_errors` 60 次（每次 `jq` 一次，`:32`）。`gate_result_verify` 在兩個 case 合計 6 次，是否有同一批檔案被重複驗證尚未查證。需先弄清楚各次驗證是否必要（不同階段、不同保證）或可共用一次解析，再決定是否去重；不得削弱驗證。 | ops/gate | 2026-10-01 | — | P3 | hygiene |
| CC-620 | ✅ closed 2026-10-23 | **[`gate wait` 的失敗原因靠 grep supervisor log 取得，`gate status` 與 `pmctl ship` 看不到；改由 supervisor 在 sentinel 寫入結構化的 `failure_reason`]** CC-615 審查（architecture）指出：消費端 scrape log 是脆弱的契約；`gate-supervisor.sh` 本來就解析同一個 log 的 `result:`／`failure-result:` 並寫 sentinel（`final_state`、`exit_code`、`result_file`），是 `failure_reason=` 欄位的自然擁有者。log 也收子 session 輸出（可含被審查 repo 的內容），所以仍須去除控制字元與截斷。repo 中沒有 dispatch 的 `failure_reason` 先例。 | ops/gate | 2026-10-03 | pr:#725 | P3 | hygiene |
| CC-621 | 🟢 someday | **[`pmctl gate run` 的 parent 端驗證還不涵蓋需要 policy 表或檔案的選項值：`--tier`、`--mode`、`--pass`（實測 `--tier bogus` 會啟動 detached gate 再失敗）、`--brief`、`--output`、`--policy-override`、`--reviewers` 的內容]** 長期做法（architecture 建議）：policy 模組提供「接受解析後的值並回傳狀態」的驗證入口，`pr-gate.sh` 與 parent 都呼叫。現況這些值仍在 supervisor 內失敗，由 CC-615 的「最後一個錯誤」行顯示。 | ops/gate | 2026-10-03 | — | P3 | hygiene |
| CC-622 | 🟢 someday | **[已發布的結果檔與 reviewer 輸出的讀取端幾乎都以「整行比對」解析（`^---$`、` ```reviewer_result_v1 `），Windows 寫的檔案若帶 CRLF 會讓它們失效；CC-618 只處理了 BOM]** CC-618 審查時指出：`gate-result-verify.sh`（`:85,107,223,571,802`）、`gate-assurance.sh:230`、`gate-result-read.sh:25,44`、normalizer 自己的 `^\+?---$`、`gate-reviewer-contract.sh:29` 的 `^```reviewer_result_v1$` grep 都是整行比對。在 Git Bash 的 gawk 上 CR 會被剝掉所以 CRLF 的 staging 檔可正常 normalize（兩位審查者各自驗證），但在 Linux／macOS 的 awk 上會以同樣的 `found 0` 失敗；實測的失敗 run 只有 BOM、沒有 CR，所以這是潛在風險，不是已證實的失敗。 | ops/gate | 2026-10-03 | — | P3 | hygiene |
| CC-623 | 🟢 someday | **[第 3 次端到端 gate 的 QA 證據記錄的 log 雜湊（`f4326af1…`）與封存後 log 的實際雜湊（`30d25053…`）不一致，原因不明]** CC-617 審查（critic）發現並由本機重算證實：`qa-execution-20261003-031431.json` 的 `attempt.log.sha256` 是 `f4326af1d03271022503a119320ea9eea03b74f4446a883ec2c665c5d5b4d9f7`，封存在 state store 的 log（1572 bytes，23 行）實際是 `30d25053c5c41af1e55a3f14bde8a59a40342c26bd67f71c8282bfb0ccc68fb2`（排除 CRLF）。候選原因：timeout 後殘存的子行程又寫入 log（`>` 截斷寫入的 stale offset）、或 gate 結束時 `relocate_gate_artifacts` 搬移／複製過程改動了檔案。目前沒有任何讀取端驗證這個雜湊，所以不影響判決，但證據的可驗證性是它存在的目的。 | ops/gate | 2026-10-03 | — | P3 | hygiene |
| CC-626 | 🟢 someday | **[QA execution 證據只在發布時被強制：assurance 沒有記錄它、沒有逐次歷史、發布後沒有摘要綁定]** CC-624 審查（architecture、security、critic）留下的後續：(1) assurance sidecar 沒有 QA execution 的狀態與雜湊，`pmctl gate verify` 事後無法證明 GO 沒有建立在 inconclusive 證據上（較舊的 `pr-gate.sh` 或手改的副本無從區分）→ 把 `evidence.qa_execution {status, artifact, sha256}` 放進 assurance，規則改成 lib 內的共用判斷，由 pr-gate 與 verify 共用；(2) 拒絕時改成寫 `Final: INCOMPLETE` 並以 exit 3 發布一份驗證過、不具授權的結果（與 pre-flight 的 INCOMPLETE 一致），而非 exit 1 加 failure-result；要先確認 synthesis 驗證器接受事後改寫 Final；(3) helper 保留逐次歷史（attempts 陣列），讓「中間失敗、最後通過」可見，也能把 nonzero 與 timeout 分開處理；(4) 證據檔在 dispatch 後做摘要綁定（reviewer 產物已有 TAMPERED_ARTIFACTS 檢查）；(5) symlink 的情況目前有處理但沒有測試（Windows 主機上 symlink 不可靠）；(6) 拒絕次數沒有計數器或 run-stats 欄位，無法量測誤判率。 | ops/gate | 2026-10-03 | — | P3 | hygiene |
| CC-628 | 🟢 someday | **[`core.symlinks=false` 時 tracked 的 120000 項目在磁碟上是普通檔：`working_tree` 以 file 雜湊、`fixed_ref` 以 symlink 雜湊，兩者仍不同；skip-prefix 與 symlink-as-file 沒有判別性測試]** CC-619 審查（critic、qa-tester）發現：與 exec-bit 無關的另一種 Windows 偏差（既有）；變異「移除 skip-prefix 清單」與「symlink 當普通檔」目前都存活。另可考慮在 assurance 記錄非雜湊的 `subject.mode_source`（值為 filesystem 或 index），讓驗證者知道指紋依哪條規則產生（security 與 architecture 建議；不進 manifest 以免改變所有 Linux 指紋）。 | ops/gate | 2026-10-03 | — | P3 | hygiene |
| CC-631 | 🟢 someday | **[git 失敗注入的測試夾具在五個 suite 各有一份：抽成 `tests/lib/git-stub.sh`]** CC-627、CC-629 (a)(b) 的測試都在 PATH 最前面放一個 git 替身，讓指定的呼叫失敗（`SUBJECT_STUB_*`、`SCOPE_STUB_*`、`PM_TEST_STATUS_*`、`CC629_*`，另有 test-pmctl-ship.sh 內嵌的一份），每份各有自己的環境變數詞彙與計數方式。architecture 建議：`git_stub_install <dir> <match-expr> [--fail-at N] [--partial]`，先於 PATH 變動解析真正的 git 並存在替身專用的變數，計數器放在 `<dir>`，提供 `git_stub_calls <dir>` 給 log 斷言，支援精確參數比對與 token 子字串比對，並支援「從第 N 次起持續失敗」。遷移會動到 test-gate-scope、test-pmctl-ship-finish、test-pmctl-ship、test-pr-gate，以及選擇性複製 `tests/lib` 的夾具與環境變數清冊；不再依賴 gate-git.sh 的抽取（該抽取已改列 CC-633），不要塞進 bugfix PR。 | ops/gate | 2026-10-04 | — | P3 | hygiene |
| CC-632 | 🟢 someday | **[ship 與 pr-gate 的 git 狀態讀取還有幾個既有的小缺口（建議性）]** CC-629 (b) 審查（security、critic）留下，皆不是這次引入、皆低風險：(1) `_pmctl_ship_worktree_status` 排除完成標記用的 `:(exclude).pm-dispatch-ship-finish.json` 是前綴 pathspec 而不是精確檔名，同名的**目錄**會把裡面的未追蹤檔案從 `status` 藏起來（指紋只略過精確檔名，所以最後一個保護點仍會抓到），註解「只排除那個精確路徑」不準確；改成不加 pathspec、在 shell 過濾精確那一行；(2) 指紋與注入檢查的讀取沒有固定 `--untracked-files=all --ignore-submodules=none` 與 `-c core.fsmonitor=false`，能寫 `.git/config` 的 session 可用 `status.showUntrackedFiles` 遮蔽自己的變更（但能寫 `.git/config` 本來就能透過 `core.fsmonitor` 或 hook 執行程式碼，不是新的信任邊界）；(3) dirty 檢查用 `-- .` 限定在 work_dir，若 work_dir 是 repo 的子目錄，外面的變更看不見（lane 都是 worktree 根目錄，可能無法觸發）；(4) `ship finish` 與 `prepare` 的 `git status` 失敗訊息帶 git 的第一行，但 pr-gate 的注入檢查訊息只指出階段與指令，沒有 git 的原因（stderr 被丟掉）。 | ops/gate | 2026-10-04 | — | P3 | hygiene |
| CC-633 | 🟢 someday | **[抽出共用的 `runtime/lib/gate-git.sh`：`_gate_scope_git_to_file` 與 CC-627 的 `_gate_subject_git_listing` 幾乎相同]** CC-629 (a)(b)(c) 審查（architecture）的結論：**暫不做**，因為要動安裝清單、`pr-gate.sh` 的 bootstrap 迴圈、按清單複製 `runtime/lib` 的測試夾具（test-gate-lifecycle、test-pr-gate-profile）、`tests/bin/run-tests.sh` 的高扇出分類與測試登錄，而目前只有 scope 與 subject 兩個 helper 這一對使用者（CC-629 (b)(c) 的修法都是在原處檢查狀態，沒有重用 helper）。**觸發條件**：出現第三個同形態的使用者，或開始做 CC-631。屆時的形狀：`gate_git_to_file <out> <git-args...>`，呼叫端自己傳 `-C`，訊息帶呼叫者名稱，成功時轉送 git 的警告，失敗時回 1 並印 git 的 fatal 或 error 行；guard 以新函式名稱判斷（混合安裝）；不要放進 `gate-digest.sh`。 | ops/gate | 2026-10-04 | — | P3 | hygiene |
| CC-634 | 🟢 someday | **[`gate-digest.sh` 的兩種模式各有一份工具探測：合成單一 `_gate_digest_select`]** CC-629 (c) 審查（architecture）：`gate_digest_init` 與 `_gate_digest_stream_probe` 各有一份「sha256sum 優先、shasum -a 256 次之」的 `command -v` 加 `printf ''` 管線的探測，靠「keep in step」註解維持一致；可合成一個設定變數的選擇函式。收益小（逐次路徑存在就是為了保留舊的成本結構），等下次動到 `gate-digest.sh` 時順手做。 | ops/gate | 2026-10-04 | — | P3 | hygiene |
| CC-640 | 🟢 someday | **[`pmctl artifacts gc`、`worktree gc/remove` 在不是 git repo 的目錄且沒有 `--cd` 時會靜默落到共用的 `global` 分區；gate、pm、portable 各有一份相同的「git 根目錄否則 `$PWD`」推導]** CC-639 審查（security、critic）指出：缺省改成目前目錄後，從 `~` 或 `/tmp` 執行 `artifacts gc` 會對 `projects/global/runs`（所有在 git repo 外的 dispatch 與 gate 執行）套用保留規則，沒有「不在 repo 內」的錯誤；同一個行為用 `--cd` 指向非 repo 目錄本來就可達，缺省讓它更容易誤觸。另外 `_pmctl_gate_default_cd`（pmctl-gate.sh）、`pmctl_pm_default_cd`（pmctl-pm.sh）與 CC-639 新增的 `portable_default_work_dir` 是同一個推導的三份副本，統一前要先確定各庫單獨載入時能取得共用函式。 | DX | 2026-10-08 | — | P3 | hygiene |
| CC-643 | 🟢 someday | **[原生 Windows 測試分流（CC-641）結案時沒做的後續，各有觸發條件]** CC-641 結案時把審查提出、未處理的項目收在這裡（另含 CC-642、issue #621、#650 的後續），每項附觸發條件；沒有觸發就不做：狀態 emoji 清單分散在多處、`cygpath`「有就轉」樣式有五份、`jq --arg <絕對路徑>` 其餘位置未逐一量測、舊的各自探測尚未改用 `th_require_*`、`gc` 的追蹤判斷改問 git 而不是比對字串等。 | ops/portability | 2026-10-10 | — | P3 | hygiene |
| CC-662 | 🟢 someday | **[repo index 的更新只在最後一次 COMMIT，被 90 秒上限砍掉就整個重來]** CC-660 查證：`_ctx_index_tree` 把所有變更檔放在同一個交易，並在最後才 COMMIT；`pmctl_context_workflow_refresh_bounded` 用 `timeout` 砍掉時，已算好的 mtime、sha1 與 SQL 全部丟掉，下一次 `gate run` 從頭來，大型 repo 因此每次都在上限處逾時、永遠收斂不了。量測（原生 Windows，559 個檔案）：無變更的更新約 4 秒、約 7 ms／檔，所以約 1 萬個檔案就逼近 90 秒，第一次建立更久。 | ops/gate | 2026-10-21 | feedback:2026-10-21 | P3 | hygiene |
| CC-663 | ✅ closed 2026-10-23 | **[`pmctl worktree create` 只能放在 state store 底下：原生 Windows 的預設路徑約 146 字元，深的 `node_modules` 會超過 MAX_PATH 260]** GitHub issue #720。`--path`、`PMCTL_WORKTREE_ROOT` 與長路徑警告。 | ops | 2026-10-22 | pr:#721 | P3 | hygiene |
| CC-664 | ✅ closed 2026-10-23 | **[targeted 輪次以 NO-GO 結束時，gate 發布 remediation closure 失敗：`failed deterministic claim verification`]** 2026-10-23 的 #721 gate 第二輪：結果檔有效，但 `gate wait` 回報 `failed exit: 2`，原因只在 supervisor-stdout.log。 | ops/gate | 2026-10-23 | pr:#722 | P3 | hygiene |
| CC-665 | ✅ closed 2026-10-23 | **[gate 的 scope manifest 階段沒有計時，#621 的現況無法從日誌判斷；平台文件還寫原生 Windows 完成不了 gate]** 重新量測 #621：約每個變更的 `lib/` 或 shell 檔 1 到 1.3 秒，不是 14–17 分鐘。 | ops/gate | 2026-10-23 | feedback:2026-10-23 pr:#723 | P3 | hygiene |
| CC-666 | 🟢 someday | **[`pmctl ship` 與前景 `gate run` 對「gate 沒過審查」與「gate 工具失敗」沒有分開呈現]** CC-620 只讓 `gate wait` 把 failed（執行錯誤）與 NO-GO（審查判決）分開。`ship finish` 以 gate 的結束碼決定下一步，前景 `gate run` 直接回傳結束碼，兩者是否給出可分辨的標示尚未查證。 | ops/gate | 2026-10-23 | feedback:2026-10-23 | P3 | hygiene |
| CC-667 | ✅ closed 2026-10-24 | **[外部 repo 第一次 `gate run` 就被 pm-dispatch 自己建的目錄弄髒，然後拒絕執行]** 在 `t3-oss/create-t3-turbo` 的 worktree 裡，`gate run` 先建 `.pm-dispatch/ctx/context.db`，隨後以 `working tree is dirty` 失敗。`pmctl ship finish` 已有 `_pmctl_ship_ensure_gitignore` 與統一清單，`setup-project.sh` 的清單卻沒有 `.pm-dispatch/`，README 也沒有把它列為上手步驟。 | ops/gate | 2026-10-24 | feedback:2026-10-24 pr:#729 | P3 | hygiene |
| CC-668 | 🟢 someday | **[審查期間 pm-dispatch 自己寫入的 `.dispatch-results/` 觸發 `possible prompt injection` 誤報]** reviewer 的派發紀錄寫進目標 worktree 的 `.dispatch-results/`，被「審查期間工作樹不得變動」檢查當成篡改，訊息指控的卻是 prompt injection。檢查沒有排除自己的產物目錄，訊息也沒有列出是哪些路徑變了。 | ops/gate | 2026-10-24 | feedback:2026-10-24 | P3 | hygiene |
| CC-669 | ✅ closed 2026-10-25 | **[gate 對 reviewer 結果的閉合欄位做嚴格字串比較，CRLF 的完整結果被判為「truncated」，自動重試也無效]** `runtime/lib/gate-result-verify.sh` 以 `[[ "$line" == '```' ]]` 找閉合欄位，行尾是 `\r` 就不相等。原生 Windows 上同一主體兩次結果不同（間歇性），訊息「truncated reviewer result」與事實不符。 | ops/gate | 2026-10-24 | feedback:2026-10-24 pr:#731 | P3 | hygiene |
| CC-670 | ✅ closed 2026-10-25 | **[`pmctl worktree remove` 遇到 pnpm 的超長路徑失敗，提示卻說「dirty? pass --force」]** worktree 放在 `C:\dogfood\w1` 仍因 `node_modules` 巢狀路徑超過 260 字元而 `Filename too long`；git 已把 worktree 解除註冊，留下半刪目錄，而提示把原因說成工作樹有未提交內容。 | ops | 2026-10-24 | feedback:2026-10-24 pr:#733 | P3 | hygiene |
| CC-671 | ✅ closed 2026-10-25 | **[兩個錯誤訊息不指出該怎麼做：`gate verify` 傳 gate id、政策下限拒絕沒說保留已要求的 reviewer]** `pmctl gate verify <gate_id>` 只得到 awk 的 `cannot open file`（它吃的是結果檔路徑）；targeted 輪次只要求 `qa-tester` 時，拒絕訊息只列 `required=[architecture-reviewer, risk-reviewer]`，沒說 `qa-tester` 也要保留。 | ops/gate | 2026-10-24 | feedback:2026-10-24 pr:#731 | P3 | hygiene |
| CC-672 | 🟢 someday | **[上手第一次體驗的兩個摩擦：installer 一次只報第一個衝突、`doctor.sh` 要 4 分 49 秒]** 舊 symlink 擋住 installer 時，每次只報一個路徑，三輪才清完 5 個；`doctor.sh` 在原生 Windows 約 4 分 49 秒，還沒查慢在哪，只有一次量測。 | ops/install | 2026-10-24 | feedback:2026-10-24 | P3 | hygiene |
| CC-673 | ✅ closed 2026-10-25 | **[context indexer 與 `pmctl ship finish` 把整個 `.pm-dispatch` 寫進 `.gitignore`，用戶的 hook 與 config 因此看不見]** [[CC-667]] 讓閘門只把 `.pm-dispatch/ctx` 當自己的輸出，但這兩個寫 `.gitignore` 的地方仍忽略整個目錄，被索引過的 repo 裡 reviewer 寫進 `.pm-dispatch/post-gate.sh`（`--allow-hooks` 會執行）在 `git status` 上看不到，完整性檢查也看不到。 | ops/gate | 2026-10-25 | feedback:2026-10-25 pr:#730 | P2 | hygiene |
| CC-674 | ✅ closed 2026-10-25 | **[被舊版寫了整行 `.pm-dispatch` 的 repo，reviewer 寫入的 `post-gate.sh` 仍躲過完整性檢查]** [[CC-673]] 之後新設定的 repo 看得見 hook，但舊 repo（舊版與 context indexer 寫的整行 `.pm-dispatch`）裡 git 什麼都不報，`--allow-hooks` 會執行的檔案可以被 reviewer 改寫而 gate 不知道。 | ops/gate | 2026-10-25 | feedback:2026-10-25 pr:#732 | P2 | hygiene |
| CC-675 | ✅ closed 2026-10-25 | **[一個 gate 要 16 到 21 分鐘，`gate wait` 上限 540 秒，操作員要等 2 到 3 輪；時間花在哪沒有資料]** 2026-10-25 量了四個完整 gate：16.2、17.2、16.1、20.8 分鐘。 | ops/gate | 2026-10-25 | feedback:2026-10-25 pr:#734 | P3 | hygiene |
| CC-676 | 🟢 someday | **[完整性檢查只看得到 git 報告的內容，被忽略但會被信任或執行的檔案看不見]** CC-674 補了兩個 hook 檔；`.gate-overrides.md` 等同類缺口待查。 | ops/gate | 2026-10-25 | feedback:2026-10-25 | P3 | hygiene |
| CC-677 | 🟢 someday | **[qa-tester 在 11 個 gate 的第一次嘗試中每次都最後完成，可能是關鍵路徑]** reviewer 階段約佔 gate 總時間 57%；QA 比第二慢的晚 23 到 256 秒（中位數 176 秒）。QA 內部耗時未拆開。 | ops/gate | 2026-10-25 | feedback:2026-10-25 | P3 | hygiene |
| CC-678 | 🟢 someday | **[synthesis 因單一 finding 的 disagreement 被驗證器拒絕而整個重跑]** 11 個 gate 中一次，多約 164 到 274 秒；頻率未知。 | ops/gate | 2026-10-25 | feedback:2026-10-25 | P3 | hygiene |
| CC-679 | ✅ closed 2026-10-25 | **[本機一個指令跑完 CI 的 lint 集合]** #731 與 #732 各被本機沒跑到的 lint 擋過一次，各多一輪約 20 分鐘的 gate。 | ops | 2026-10-25 | feedback:2026-10-25 pr:#735 | P3 | hygiene |
| CC-680 | 🟢 someday | **[只能在 WSL 跑的測試檔，QA 沙箱拿不到執行證據而 hard block]** #733 前兩輪 NO-GO；`--test-cmd` 帶 WSL runner 解決，但沒寫在任何指引裡。 | ops/gate | 2026-10-25 | feedback:2026-10-25 | P3 | hygiene |
| CC-681 | 🟢 someday | **[CC-669 留下的兩個小缺口：統計讀者的圍欄比對，與圍欄後空白的 truncated 訊息]** 安全降級但數字缺了，訊息不精確。 | ops/gate | 2026-10-25 | feedback:2026-10-25 | P3 | hygiene |
| CC-682 | 🟢 someday | **[讓等待一個 gate 更便宜：進度資訊、自動續等、輪詢指引]** CC-675 只改了逾時訊息的措辭，沒有降低要等的次數；gate 中位數 1060 秒，單次 wait 在這個環境要在 540 秒內回來。 | ops/gate | 2026-10-25 | feedback:2026-10-25 | P3 | hygiene |
| CC-683 | 🟢 someday | **[reviewer 重試恢復後，gate 的 operation 仍被標成 failed]** 一個 GO 且可驗證的 gate，`gate wait` 卻印 `operation ... state: failed`；原因是失敗的第一次嘗試仍算一個失敗的子 run。n=1，機制已從程式碼確認。 | ops/gate | 2026-10-25 | feedback:2026-10-25 | P3 | hygiene |
| CC-684 | 🟢 someday | **[test-pmctl-gate 的取消時間預算（10 秒）在負載下不夠穩]** 一個 gate 預檢因 `elapsed=10`、`10 -lt 10` 為假而失敗，取消本身成功。n=2（2026-10-26 再發生一次，優先度 P2），原因未查出。 | ops/gate | 2026-10-25 | feedback:2026-10-25 | P2 | hygiene |
| CC-685 | ⚠️ partial 2026-10-26 | **[等 gate 的人看不到它做到哪一步：沒有階段、最後進展與產物位置（issue #736）]** 第 1 步已做（階段事件 + `pmctl gate status` + `gate wait` 逾時階段行），並追加指紋批次化（detached gate 內 `subject_snapshot` 72 到 88 秒 → 8 秒、預檢前後指紋 72 到 85 秒 → 5 到 7 秒，摘要不變；一台機器各一次，最終 gate 含 reviewer 的完整耗時 32 分 11 秒 → 15 分 50 秒，批次化約佔 5 分鐘，其餘是模型與測試時間的變動）；執行預覽、占位檔、前置預算、ETA 待做。 | ops/gate | 2026-10-26 | feedback:2026-10-26 pr:#737 | P2 | hygiene |
| CC-686 | ⚠️ partial 2026-10-26 | **[記憶注入 hook 每次提示耗時隨卡片數線性增長，原生 Windows 約 130 張卡就超過宿主的 30 秒（issue #738）]** 第一階段已做：每張卡不再啟動行程（200 張卡 48 秒 → 3.5 秒、1000 張卡約 8 秒，輸出逐字不變）；固定成本約 2 秒、中繼資料快取、usage 預算、episodes 讀模型待做。 | ops/memory | 2026-10-26 | feedback:2026-10-26 pr:#739 | P1 | hygiene |
| CC-687 | ⚠️ partial 2026-10-27 | **[記憶平面索引（`<memory_dir>/.pm-dispatch/context.db`）建置與更新太慢：1000 張卡冷建 301 秒、沒有變動的更新約 4 到 5 秒（issue #738 的「SQLite」部分）]** 第一步已做：索引每個檔案不再為檔案大小（`wc -c \| tr`）與時間（`date`）各啟動行程（100 張卡 36 → 24 秒、300 張卡 100 → 42 秒，資料庫內容逐列相同）；逐行 bash 切塊、暖更新的 bash 迴圈待做。 | ops/memory | 2026-10-27 | feedback:2026-10-27 pr:#740 | P1 | hygiene |
| CC-688 | 🔵 active | **[注入 hook 的 usage 讀寫：兩次 sqlite 讀、每張命中卡一個 fork 的 SQL 引號、讀寫逾時合計可超過 26 秒（issue #738 第 2 點）]** 一次 snapshot、hook 專用的總時間預算、持鎖故障注入測試；計畫見下方 CC-688 一節。 | ops/memory | 2026-10-27 | feedback:2026-10-27 | P1 | hygiene |
| CC-689 | ⚠️ partial 2026-10-27 | **[通用量測工具：一句指令得知任何 pmctl 路徑用了多久、花在哪（issue #742）]** 最小版已做：`pmctl time [--runs N] [--json] -- <指令>`（cold / warm p50 p95 max、各階段毫秒、平台程序啟動基準）與 `pm_timing_phase` 標記（`PM_DISPATCH_TIMING_FILE`，未設定時零行程、不寫 stdout）；prompt-scan 已標 5 個階段。外部程序啟動計數、`pmctl diagnose perf` 固定情境、hook 接線重現待做。 | ops/gate | 2026-10-27 | feedback:2026-10-27 pr:#743 | P1 | hygiene |
| CC-690 | 🔵 active | **[prompt-scan hook（`inject-context.sh`）在 Windows 每次提示 37 到 57 秒（issue #741）]** 先用 CC-689 的階段標記量出占比，再修最大的一段（遙測 `events_append`、逐 row 解析、hook 內刷新）；計畫見下方 CC-690 一節。 | ops/memory | 2026-10-27 | feedback:2026-10-27 pr:#744 pr:#745 | P1 | hygiene |

---

## Convention

**ID scheme**: `CC-NNN` sequential. ID gaps are normal — use the `epic` column (see `pm/schema.md §2.4.5`) for semantic grouping instead of ID ranges. The `CC-1NN`/`CC-2NN` range-reservation convention is deprecated (see `DECISIONS.md#2026-05-19-deprecate-id-gap-convention`).

**Sub-letter IDs**: `CC-NNNa`, `CC-NNNb`, `CC-NNNc` are follow-up tickets to a parent `CC-NNN`, with independent lifecycles.

**Status legend** — _non-terminal_ (stay on the board):
- `🔵 active` — in backlog (not-started / in-progress / blocked)
- `⏸ deferred` — waiting on external condition or trigger, not scheduled
- `🟢 someday` — valid idea, no expected schedule
- `⚠️ partial YYYY-MM-DD` — partially shipped; sub-items remain open (see body)

_Terminal_ (CC-378: swept OUT to `BACKLOG-ARCHIVE.md` by `ops/backlog/archive-closed-backlog.sh` — index row + body both leave BACKLOG.md, no stub):
- `✅ done [YYYY-MM-DD]` — completed; date optional. **Terminal + archived** (the old soft-close-stays-active rule was retired — see DECISIONS 2026-06-14).
- `✅ closed YYYY-MM-DD` — shipped, PR-backed dated variant of `done`; terminal.
- `🟢 superseded YYYY-MM-DD` — superseded by a later item; archived body keeps a `Superseded by [[CC-NNN]]` pointer. (Same 🟢 glyph as `someday` but opposite liveness — terminal rows leave the board on the next archive run, so a 🟢 left on the board should only be `someday`.)
- `🚫 dropped YYYY-MM-DD` — will not do; archived body keeps `See: DECISIONS.md` if decided.

**Archival**: terminal tickets are swept entirely to `BACKLOG-ARCHIVE.md` (no `**See**:` stub remains in BACKLOG.md). Query closed items via the archive's body headings.

**Priority column**: `P1`（本週必做）/ `P2`（本 sprint）/ `P3`（排隊）/ `—`（未設）。
**Epic column**: `oss`（CC-OSS 公開源碼系列）/ `reuse-debt`（技術債重用）/ `hygiene`（流程維護）/ `design`（新功能架構設計與 interface 決策）/ `spike`（調查類任務）/ `—`（其他）。
向下相容：v1.1/v1.2 file 中缺此兩欄的列只 emit 警告（不阻斷 gate）。

<!-- archived stubs — full text in BACKLOG-ARCHIVE.md -->

## CC-447 — 乾淨機器 onboarding 雙 smoke（offline + live dogfood）🔵 active

**Problem**：GETTING_STARTED 與 install 鏈從未被第二使用者或乾淨環境驗證過——所有安裝驗證都發生在維護者已高度客製的機器上。repo 已 public，外部使用者的 install 體驗就是專案的第一印象，摔倒點目前不可見。

**Why**：v1.0 的第二個承諾是「別人裝得起來、用得下去」（DECISIONS 2026-07-04）；這比做 bootstrap wizard（[[CC-064]]）便宜且先驗證需求。

**Requirement**（拆三個 smoke，時點不同）：
1. **Offline clean-install smoke**（v0.11.0）：fresh Linux + WSL2 各一輪，不需任何 CLI auth——`install.sh --dry-run` → `CLAUDE_HOME=/tmp/... install.sh` → `doctor.sh` → `uninstall.sh` 無殘留。驗 install 鏈本體與文件一致性。
2. **Live dogfood smoke**（readiness review 後另排）：真實 Claude/Codex auth 環境，走完整 onboarding：install → doctor → 首次 `/pm` → 首次 `pmctl dispatch run` → 首次 `pmctl ship`（一次 gate 到 PR）。
3. **N-1 upgrade smoke**（v0.11.0）：從 latest released tag 安裝，建立代表性的 Claude/Codex/OpenCode managed config，再切到 current checkout 重跑 installer；驗證 doctor 全綠、最小 command 可執行、uninstall 無殘留，且 foreign hooks/config、canonical memory 與使用者資料未被修改。
4. 每個摔倒點（缺依賴、文件與行為不符、錯誤訊息不可行動）逐一開票，不在本票內修。
5. `QA_RULES_DIR` 外部依賴缺席時的行為驗證：qa-tester 在沒有 qa-testing-rules checkout 的機器上是 fail-loud 還是靜默劣化，結論寫入報告。
6. [[CC-064]] bootstrap wizard 僅在實測證明需要時才升級為實作票。

**Release qualification**：offline clean-install 與 N-1 upgrade 是 v0.11.0 release candidate 的最終驗證，不是中途功能票。可先維護可重現的 harness 與報告模板；只有在所有會改 lifecycle、shared hooks、state 或文件的 v0.11.0 work 已進入 freeze 後，才可產生可用於 release 的正式證據。若 release surface 在 smoke 後改變，該 smoke 必須重跑。

**2026-09-05 交付（pr:#573）**：Requirement 1／3 完成——`ops/release/clean-install-smoke.sh`（單一 checkout dry-run→install→doctor→uninstall→無殘留，對 `.bak.*`／空骨架檔／`xdg/opencode` 空目錄做安全產物 allowlist）與 `ops/release/upgrade-smoke-v0.10-v0.11.sh`（v0.10.0 baseline→目前 candidate，改用真實安裝流程即為可重現 harness，取代原先設想的一次性報告文件）皆跑出 `GO`。摔倒點依 Requirement 4 開票：clean-install smoke 首次跑就抓到 codex host install/uninstall 的 scratch temp file 洩漏，即 [[CC-580]]，其 Requirement 1 已在同一 PR 內修復並驗證（allowlist 已排除掉刻意保留的備份/骨架安全產物，不誤判為殘留）。Requirement 5（`QA_RULES_DIR` 缺席行為）與 Requirement 2（live dogfood）維持未動，票繼續 active。

**2026-10-23 live dogfood 計畫**：第一個目標是公開 repo `t3-oss/create-t3-turbo`（MIT、維護中、約 141 個追蹤檔、`apps/` 有 Next 與 Expo，形狀接近 #621 回報者的 pnpm／turbo monorepo，但規模小得多）。流程與紀錄欄位在 `docs/notes/live-dogfood-report-template.md`：安裝或更新、短路徑 `worktree create --path`、gate、刻意製造審查 NO-GO 與工具失敗並確認輸出分得清、修正後 targeted 重跑、`ship`；每步記耗時與人工介入次數（由實際操作者計數）。證據邊界寫在 `docs/platform-support.md`：這一輪只證明流程能跑完，不證明全套測試在原生 Windows 通過，也不證明 #621／#620 回報者的 monorepo 規模。

**2026-10-24 live dogfood 第一輪**：報告在 `docs/notes/live-dogfood-2026-10-24-create-t3-turbo.md`。在 `t3-oss/create-t3-turbo`（`8f945b7`）上走完安裝、短路徑 worktree（`C:\dogfood\w1`）、gate、自然發生的 NO-GO 與多次工具失敗、修正、targeted 重跑，第 6 輪 `Final: GO`，`gate verify` 為 `assurance: verified`；13 次人工介入。`failed` 與 NO-GO 靠輸出就分得出來（[[CC-620]] 在外部 repo 上第一次驗證到）。依 Requirement 4 開了 6 張票，未在本輪修：[[CC-667]]（忽略清單）、[[CC-668]]（`possible prompt injection` 誤報）、[[CC-669]]（CRLF 閉合欄位）、[[CC-670]]（worktree remove 超長路徑）、[[CC-671]]（兩個不可行動的訊息）、[[CC-672]]（installer 一次一個衝突、doctor 4 分 49 秒）。**未涵蓋**：乾淨機器（開發機有舊殘留）、`pmctl ship`（對別人的公開 repo 不能 push）、`QA_RULES_DIR` 缺席（Requirement 5，每輪都有設定）、#621 規模的 monorepo（141 個追蹤檔，scope manifest 5 到 10 秒）、整套測試在原生 Windows 通過（目標 repo 沒有測試）。n=1，一個 repo、一個執行器家族。

**Done-when**：在 v0.11.0 release candidate 上，三個 smoke 的實測報告 committed（`docs/notes/` 或票內）；clean install 與 N-1 upgrade 都有可重現證據——**已達成**；摔倒點全部開票——offline smoke 摔倒點已開 [[CC-580]]；GETTING_STARTED 修正到與實測一致——**尚未做**；live dogfood 完成——**第一輪完成（n=1，見上；`ship`、`QA_RULES_DIR` 缺席、乾淨機器仍未涵蓋）**。

**Dependencies**：offline/N-1 smoke 在 [[CC-497]]、[[CC-456]]、[[CC-449]]、[[CC-503]] 後，且 v0.11.0 release freeze 中執行；live smoke 不預先綁 v1.0，待 v0.12.0 後 readiness review 排程。
**See**: DECISIONS.md 2026-07-04

## CC-461 — `doctor.sh --fix`：冪等/可逆自動修復 ⚠️ partial 2026-09-06

**Problem**: 原始缺口是 doctor 只診斷不修復；第一刀 `scripts-executable` 已由 PR #575（2026-09-06，commit `f10f9af`）交付。後續仍需以實際摔倒點評估其他白名單與 host-specific fix，不因保留這張 umbrella 票而預設增加修復項。

**Why**: 降低 onboarding 摩擦（呼應 [[CC-447]] 乾淨機器 onboarding 的動機），但自動修復本身有風險——必須先知道「摔倒點長什麼樣」才能定義安全的自動修復範圍，避免修復動作本身造成新的不可逆狀態。

**Requirement**:
1. 範圍限定：僅冪等（重跑無副作用）、可逆（有明確復原路徑）、不碰使用者內容（不動 BACKLOG/DECISIONS/memory 等使用者資料）三類檢查項可自動修復；每項修復動作需獨立小函式、獨立測試。
2. **範圍改訂（2026-09-05）**：原計畫等 [[CC-447]] offline smoke 產出摔倒點清單才定白名單，但實測只有 n=1（[[CC-580]] 的 codex host temp-file 洩漏），且該缺陷已直接在上游程式碼修掉——它是一次性的 trap-disarm bug，不是「診斷後讓使用者按 `--fix`」的材料，不適合當白名單第一項。改為第一刀白名單直接取自 doctor.sh 既有檢查項清單中已符合冪等/可逆/不碰使用者內容三條件者：`scripts-executable`（missing +x → `chmod +x`，天然冪等可逆）。後續 slice 再視是否有更多真實摔倒點擴充白名單。
3. 與 [[CC-437]] doctor host module 介面對齊（host-specific 檢查項若可修復，走同一 module 介面）——CC-437 已交付。

**Done-when**: 白名單內每個修復項有「修復前狀態 → `--fix` → 修復後狀態」的回歸測試；`--fix` 對白名單外的問題明確拒絕（不猜測性修復）。

**Dependencies**: 與 [[CC-437]]（已交付）對齊；不再依賴 [[CC-447]] 摔倒點清單（該依賴已由 Requirement 2 的範圍改訂解除）。
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

## CC-468 — dispatch brief 帶 memory 約束：PM 萃取為 constraints 清單（pointer 僅作 provenance）⏸ deferred

**Problem**: auto-pack 走 reuse-scan 且 repo-only by construction；`context pack --source memory` 存在但 dispatch 從不使用。結果：feedback 卡裡的約束（如「此 repo 禁用某工具」「reviewer 反覆擋的模式」）永遠不會自動進 brief，全靠 PM 記得手貼——記憶對 executor 行為零影響力。

**Why**: 成功指標（DECISIONS 2026-06-10）本來就是「brief 直接引用 memory/decision anchors」；目前管線只對 repo plane 兌現，memory plane 缺最後一哩。單純 pointer-only ref 讓 executor 拿到一個 ref 卻看不到約束本體，等於沒有約束力——因此改為由 PM 在 brief authoring / auto-pack 階段，把私有卡片規則**萃取（extract）成一份非敏感的 `constraints:` 清單**直接寫入 brief；pointer 僅保留作為來源標記（provenance-only），不再是 executor 唯一可見的內容。約束類卡片常以中文撰寫，依賴 [[CC-465]] 先把 CJK 抽詞修好，查詢命中才可靠。

**Requirement**:
1. brief 授權／auto-pack 對 memory plane 做一次查詢；只有 curated／高 trust tier、未過期、未 supersede 的 constraint-type card 能轉成 normative `constraints:`。episode、raw event、低信任 retrieval result 只能作為 evidence，不能直接形成指令。
2. retrieved memory 一律視為 untrusted data，不得執行其中的 prompt/tool instruction；每條萃取出的 constraint 保留 source pointer、trust tier、status、expiry 作為 provenance。
3. 私有／敏感內容（含中文原文的具體措辭）不需逐字進入 repo-bound 產物；萃取後的 constraint 表述須為可公開的非敏感摘要，數量設上限。
4. 零命中時不加空區塊（比照 `auto_context:` 現行語意）；查詢或萃取失敗 fail-open 不阻斷 dispatch。
5. 補惡意 prompt-injection card、敏感資料 redaction、過期／superseded card、互相矛盾 card 的測試。

**Activation trigger**: 完成 [[CC-465]] → [[CC-467]] 後，只有 usage evidence 證明 memory constraints 對 dispatch 有實際價值才啟動；不因票已存在自動實作。

---

## CC-466 — 記憶卡片生命週期閉環：expires_at 執行 + 關窗式 supersede + 休眠偵測 + doctor→distill 接線 ⏸ deferred

**Problem**: 卡片 schema 有 `expires_at` / `status` 生命週期欄位但無任何執行面：注入 hook 只降級 `stale`/`superseded`、不看 `expires_at`；doctor 不報過期卡；usage sidecar 只餵排序、不餵老化（沒有「N 天未命中」的休眠訊號）；doctor 找到的 stale_repo_refs / orphan 與 `/mem-distill` 的提案迴路完全斷開，修復全靠人記得。記憶只進不出，長期必然膨脹並讓固定注入預算被殭屍卡佔據。

**Why**: 2026-07-07 外部研究（/research）結論——確定性生命週期的成熟做法是：(a) Graphiti/Zep 的雙時間軸「關窗不刪除」失效模型（schema 與關窗操作是確定性的，只有矛盾偵測需要智慧——正好是 `/mem-distill` 的既有職責）；(b) mcp-memory-service 家族的 access-count / last-access 休眠偵測（零 LLM）。pm-dispatch 原料已齊（usage sidecar、doctor、confirm-gated distill），缺的只是接線；LLM 判斷全部留在顯式指令桶，hooks 維持 zero-LLM。已評估並排除：mem0 每寫入 LLM 仲裁、Letta sleep-time LLM 整理（違反 zero-LLM hooks；`/mem-distill` + `/memory-compress` 已是顯式等價物）。本票應排在 [[CC-467]] 之後執行——需要先有可信賴的注入效益遙測，才能在其上建置休眠偵測與降級/移除判斷邏輯；在遙測可信之前先做生命週期自動化容易誤判。

**Requirement**:
1. 過期卡（`expires_at` 已過）在注入時降級、在 doctor 報告中列出。
2. supersede 採關窗語意：舊卡保留並標記失效日期與後繼指向，不物理刪除（與現有 archive-in-place 慣例一致）。
3. doctor 能從 usage sidecar 偵測休眠卡（超過門檻天數未命中）並列出。
4. `/mem-distill` 讀取 doctor 結構化輸出，把過期／休眠／stale-ref 卡轉成 UPDATE/REMOVE 提案，沿用既有確認閘門（不新增任何自動寫入路徑）。

**Activation trigger**: [[CC-467]] 的真實遙測顯示 stale/dormant card 已佔用注入預算或造成檢索品質問題才啟動；否則維持 deferred。
**Source**: 2026-07-07 /research——Graphiti bi-temporal（github.com/getzep/graphiti）、mcp-memory-service decay 家族（github.com/doobidoo/mcp-memory-service）。

---

## CC-472 — spike: antigravity（`agy`）host 唯讀 probe 🟢 someday

**Problem**：使用者正在跟 agy（antigravity CLI）討論把它接成 pm-dispatch 的一個 host（PM 在該 CLI 內被驅動，而非僅作 executor adapter）。目前完全沒有評估過 agy 屬於哪一類、guard 綁定是否可行。

**Why**：討論過程中釐清一個先前被混淆的區分——**Executor**（背景自動派工、靠 post-verify 機械判定）需要結構化的 JSONL/JQ 可審計輸出；**Host**（人類互動起點）門檻低很多，只要能載入專案 slash command（如 `/pm`）、能在內部 agent 呼叫 Bash/檔案寫入時觸發 `pmctl guard check` 就夠格。`docs/host-contract.md` 的 `guard_bindings` schema 已內建這個分級：`pm_command_interface` 是強制宣告的能力（這才是「算不算 host」的門檻），`command_guard`/`file_guard` 允許合法宣告 `provider: none`（`confidence: probed`/`observed` 代表「已實測、這個 host 結構上就是做不到攔截」，是誠實終態宣告，不是缺陷）。

**Requirement**：比照 [[CC-436]]/[[CC-448]] 階段 1 的唯讀 probe 模式——不落地 `hosts/antigravity/host.yaml`，只實測：
1. command 載入能力（能否載入 pm-dispatch 的 `/pm` 這類 slash command，或有無等價機制）。
2. hook/plugin 機制（能否在 Bash/檔案寫入時觸發 `pmctl guard check`）。
3. 四個 capability enum（`command_guard`/`file_guard`/`pm_command_interface`/`statusline`）的 provider/confidence 判定（`session_lifecycle` 已於 2026-08-21 隨 Stop-hook 空殼寫入者一併退役，不再是 host-contract 的一部分）。

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
**Amendment (2026-09-01)**: bounded **experimental local-use exception** — native Windows Git Bash is supported for local Claude/Codex use (PowerShell-launchable hook commands, `MSYS=winsymlinks:nativestrict` native symlinks with copy fallback; prerequisites: Git Bash, jq, sqlite3, Developer Mode). The deferral otherwise stands: CI/release sign-off remain Linux/WSL2 only and parked CC-104x tickets stay parked. See DECISIONS.md 2026-09-01 `windows-git-bash-experimental-local-use-exception`.
**See**: DECISIONS.md 2026-06-13 `defer-native-windows-support-during-core-dev`.

## CC-369 — Windows state store 真實 ACL via icacls（deferred）

**Problem**: CC-368 #2 在 NTFS 上以 SKIP-with-reason 處理 `state_store_init` 的 0700 斷言（`chmod` 是 no-op），但這只讓測試誠實，並未在 Windows 上達成等價的「僅擁有者可存取」保護。目前 state store 落在 `%USERPROFILE%` 下，僅依賴該目錄既有的 NTFS ACL。
**Why**: 真正等價 0700 需以 `icacls` 移除繼承並僅授權目前使用者，屬 Windows 專屬分支與測試成本。相對於 profile 目錄既有 ACL，邊際安全收益不高，且 Windows 尚非 Supported，故 deferred。
**Requirement**: 待 Windows = Supported flag flip 前評估：`state-writer.sh` 在 Windows 偵測下以 `icacls "<store_root>" /inheritance:r /grant:r "%USERNAME%:(OI)(CI)F"` 等價設定收斂保護，並補對應能力測試。
**Source**: 2026-06-13 CC-368 #2 收尾時分出的 follow-up。

## CC-450 — 其餘 9 個 test-*.sh docstring 格式統一（CC-004 同款 Behavior/Steps，跨檔）

**Problem**: [[CC-004]] 實作時盤點發現，同樣的 docstring 不一致問題不只 test-pr-gate.sh：`test-doctor.sh`(5)、`test-e2e-script.sh`(13)、`test-install.sh`(77)、`test-patch-gitignore.sh`(5)、`test-pr-gate-profile.sh`(13)、`test-release-verify.sh`(25)、`test-run-all-tests.sh`(26)、`test-setup-project.sh`(9)、`test-uninstall.sh`(28) 共 9 個檔案、201 個 test function 完全沒有 `# Behavior:`/`# Steps:` 開頭註解。
**Why**: 純 audit-quality / 一致性問題，不影響測試邏輯或功能；規模較大故從 CC-004 拆出獨立票，避免單票範圍無限擴張。
**Requirement**: 依 `tests/lib/test-harness.sh` 頂部新增的 docstring 慣例說明（CC-004 帶入），逐檔把上述 9 個檔案的 test function 補上 `# Behavior:`/`# Steps:` 註解區塊，整段置於函式宣告正上方、不拆進函式內部。不改測試邏輯。完成後跑對應套件全綠、`bash -n` 語法檢查、以及 run_test 呼叫名稱與函式宣告的交叉核對（避免重蹈 CC-004 實作中一度誤刪宣告行的錯誤）。
**Source**: 2026-07-03 CC-004 實作時的範圍盤點。

## CC-011 — sync-memory.sh + 跨裝置共用（deferred；建議與 CC-012 合併實作）

**Problem**: `~/.claude/projects/*/memory/` 為本機路徑，多台電腦之間 memory 各自獨立，無法共用。
**Why**: 用戶目前不急，但設計上若以 symlink 指向 Dropbox/iCloud/OneDrive 資料夾，可以零維護代價實現跨裝置共用，且完全相容現有 file-based memory 架構。
**Requirement** (Phase 1): `ops/setup/sync-memory.sh --setup <cloud-path>` 把 memory 資料夾 symlink 到雲端同步路徑；`install.sh` 加入 opt-in 步驟。
**Phase 2**: CC-012 (SessionStart pull hook) — 兩者應同一 PR 實作，CC-012 無獨立實作價值。
**Status note (CC-050 audit 2026-05-18)**: Downgraded from ⏸ deferred to 🟢 someday — concept valid, no active plan. Re-evaluate if cross-device sync interest grows.

## CC-012 — SessionStart hook pull memory（deferred；建議與 CC-011 合併實作）

**Problem**: 若多台電腦透過 CC-011 共用同一雲端 memory 資料夾，session 啟動時不保證已取得最新版本。
**Why**: 輕量方式是 SessionStart hook 觸發一次 rsync/git pull，確保 memory 是最新版。
**Requirement**: `hosts/claude/hooks/sync-memory.sh` SessionStart hook；支援 git pull 和 rsync 兩種模式；失敗時靜默降級。
**Note**: 依賴 CC-011；建議與 CC-011 合入同一 PR（Phase 1 + Phase 2 同步落地，CC-012 無獨立實作意義）。
**Status note (CC-050 audit 2026-05-18)**: Downgraded from ⏸ deferred to 🟢 someday — depends on CC-011; no active plan. Re-evaluate together with CC-011.

## CC-018 — Codex quota 自動追蹤 + rate-limit 路徑統一（吸收 CC-269）

**Problem**: (A) CC-006 解決了 Claude 5h rate-limit 自動讀取，但 Codex 無等效 hook 機制；目前 Codex 使用量只靠 `log-usage.sh` 手動寫入，用戶無法即時得知剩餘額度。(B) CC-269（已合併）：`hosts/claude/hooks/save-rate-limits.sh` 寫到 `~/.claude/rate-limits.json`，與 claude-account-switcher 等工具衝突；pm-dispatch 不應寫入 `~/.claude/` 共用路徑。
**Why**: Codex 走 OpenAI API 路徑，quota 資訊需要主動查詢（response header 或 `/v1/organization/usage`），架構不同於 Claude StatusLine hook。rate-limit 寫入應集中到 pm-dispatch 自己的 state 目錄以避免多工具衝突。
**Requirement**:
1. 研究 Codex API response headers（`x-ratelimit-remaining-requests` / `x-ratelimit-remaining-tokens`）
2. 若有：`adapters/codex/dispatch.sh` dispatch 後解析 headers，寫入 `~/.local/share/pm-dispatch/state/rate-limits.json`（對齊 CC-230 state store）
3. 若無：呼叫 `/v1/organization/usage` 或記錄技術限制
4. `hosts/claude/hooks/save-rate-limits.sh` 改寫到同一 `~/.local/share/pm-dispatch/state/rate-limits.json`（Claude pool + Codex pool 合一），停止寫 `~/.claude/rate-limits.json`
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
**Resume trigger（2026-07-15 三方 multi-model synthesis）**: codex/opencode 分析一致認為此票是 skill 平台化早熟的具體例子（自動偵測+產生 skill 草稿=雛形 marketplace）。除依賴 CC-027/CC-025 外，[[CC-493]] 已定案（`docs/skill-command-harness-policy.md`）——草稿產物目標維持
`skills/<name>/SKILL.md` 而非 `commands/<draft-name>.md`；上方 Requirement 1/3 描述的
`commands/skill-distill.md` slash-command 介面本身仍成立（`/foo` 觸發＝Tier 3），
只有它產出的草稿檔案位置需照此調整。
**Source**: 2026-05-15 對話討論 Hermes Agent self-improvement loop 與 pm-dispatch 的 gap 分析。

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
3. GitHub 設定決策照原 Requirement 1（Issues/Discussions/template/labels/CITATION.cff），在 v0.12.0 完成；觀察期留到未來 stable release 後。
4. **README 使用者表面重建**（2026-07-06 盲測稽核追加）：README 只記載 15 個 command 中的 2 個（`/pm`、`/pr-gate`）、Agents 段缺 spike agent、Layout 段引用已不存在的 `settings/` 目錄且缺 `skills/`（install.sh 實際會接線）——commands/agents/skills 清單改為與實際目錄一致（可由 `commands/*.md` frontmatter description 派生），Layout 修正到與 install 行為相符。
5. **Audit slice completed 2026-07-18**：以 `b7799c3` 為 baseline，掃描全部 493 個 reachable commits（含 2026-05-15 後 450 commits）。未發現需 rotation/history rewrite 的 credential、私鑰或誤入 runtime artifact；token-shaped matches 均為測試 fixture／字串誤判。已記錄兩項非 secret exposure（maintainer 絕對路徑、commit Gmail metadata）及一項持續防護缺口（GitHub secret scanning disabled）。處置與可重跑方法見 [docs/audits/CC-033-git-history-audit.md](docs/audits/CC-033-git-history-audit.md)。本票維持 active；README/協作表面、secret-scanning enablement verification 仍屬 v0.12.0。
someday → active，P3 → P2。

**Progress 2026-08-31（Req 2 + Req 4 交付，pr:#567）**：README posture 句改成「publicly readable personal distribution, not a public support contract」與 CONTRIBUTING 對齊；§Commands（2/14→14）／§Agents（補 `spike`）／新增 §Skills 由 `commands/`／`agents/`／`skills/` 目錄各 file 的 `description:` frontmatter 重建；§Layout 刪不存在的 `settings/`、補 `skills/`。新 `tools/lint/lint-readme-surface-lists.sh` 斷言三段清單與目錄 set-equal（跳過群組標題、缺 heading 大聲失敗），防再漂。`SECURITY.md` 加「Repository security posture」段記錄 secret scanning／push protection／Dependabot 皆 disabled + 確切 `gh api` 開啟指令——啟用是維護者 console 動作、非程式改動。**票維持 active**：Req 1/3（Issues/Discussions/template/labels/CITATION.cff）+ secret-scanning 啟用 + 2-4 週觀察窗仍屬 v0.12.0。

**Source**: 2026-05-15 對話 — 公開前置盤點 #4。

## CC-035 — install/uninstall-hooks basename+scripts/ collision edge case

**Problem**: install/uninstall hooks 目前以 basename + `scripts/` heuristic 判斷既有 hook 是否屬於 pm-dispatch，但另一個工具若也在 `scripts/` 下使用同名 hook，仍可能 collision。
**Why**: CC-034 修掉 full-path 比對造成的 append-not-replace bug，但 basename heuristic 仍不是完整 ownership model。
**Requirement**: 設計更明確的 hook ownership marker 或 install manifest，讓 uninstall/replace 只影響 pm-dispatch 自己寫入的 hook entry。
**Source**: CC-034 follow-up from PR #53.

## CC-038 — Windows / cross-platform locking primitive（deferred）

**Problem**: CC-037 用 `flock -x -w 2` 序列化 `hook-routing-log.sh` 的 append/rotation 路徑。`flock` 是 Linux util-linux 工具，Windows（純 PowerShell / Git Bash 無 util-linux）與 macOS（預設不裝 util-linux，需 `brew install flock`）都不能直接使用。除了 hook-routing-log，整個 `scripts/` 樹大量依賴 Linux-isms（GNU awk、GNU sed、`printf -v`、`procfs`、`/dev/null` 重導向細節等），整體 portability 是一塊待面對的工作面，不只這一支腳本。
**Why**: 使用者後續可能需要在 Windows 系統開發 / 跑 pm-dispatch（WSL 不算 native Windows）。在那之前，所有 Linux-only 依賴都是 latent block。CC-037 引入 `flock` 沒有惡化現況（其他 hook 已依賴大量 Linux-only 工具），但每多一個依賴點，將來 portability work 範圍就多一塊。現在不修不影響任何 Linux user，所以這是 latent / blocked-on-windows-demand 條目，不是 active bug。
**Requirement**: 任一方向皆可：(1) 抽象層 `runtime/lib/lock.sh`，依平台選 `flock` (Linux) / `shlock` (macOS 內建) / PowerShell `Mutex` 或 atomic file create loop (Windows)，hook 透過 wrapper 取得鎖；(2) Portable 替代：用 `mkdir`-based atomic locking 取代 flock，所有平台 portable，但需顯式 stale-lock cleanup；(3) 限制範圍：明確聲明 pm-dispatch 僅支援 POSIX（Linux + macOS via Homebrew util-linux），Windows 走 WSL2，寫進 `README.md` + `docs/platform-support.md`。
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
**Requirement**: `tools/lint/coupling-check.sh` 語言偵測 + 工具呼叫，只分析 changed files；PR gate 加入可選 `--coupling` flag；閾值超過 → block-soft。
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
3. （可選 / 第二階段）`adapters/codex/dispatch.sh` 啟動時偵測 `<working_dir>/rules/` 或 `<working_dir>/AGENTS.md` 存在且 `--timeout < 900` 時 emit stderr WARNING（不阻擋），surface author 設置錯誤於 SIGKILL 之前。
4. 觀察 N≥2 次 cross-session 重現後，promote 為 `feedback_brief_timeout_playbook_depth` memory（`known-bug backlog rule` + `Codex routing preferences` 衍生）。
**Source**: 2026-05-16 cross-session diagnostic — deep-playbook target repo dispatch exit 124 with 240s timeout, trace `.agent-trace/codex-20260516-193626-47431.jsonl`。
**Note**: 立即 workaround 是 brief author 對 deep playbook repo 預設 timeout=1500s；本條 ticket 是把這條 workaround 升級為文件化規則 + 可選 wrapper-side warning。
**Cross-link**: `Codex routing preferences` 路由表 / `known-bug backlog rule` 補登原則。

## CC-054 — CC-025 M2 `/skill-refine` diff generation（deferred）

**Problem**: CC-025 delivered the M1 read-only signal bundle and CC-025b closed the usage-guard plus `CLAUDE_MEMORY_DIR` contract follow-ups, but the original M2 scope for `/skill-refine` diff generation remains unimplemented.
**Why**: The useful product loop is not complete until the tool can turn skill feedback signals into a reviewable refinement diff. Closing CC-025b without a separate M2 tracker would make that deferred scope easy to lose.
**Requirement**:
1. Extend `/skill-refine` so it can generate a proposed diff for the target skill or command from curated memory/feedback signals.
2. Keep the default behavior review-first: emit the diff for user or main-thread approval rather than directly rewriting skill files.
3. Include Claude-assisted refinement guidance in `commands/skill-refine.md`, with clear dry-run and apply boundaries.
4. Add contract tests for diff-generation behavior and no-direct-write safety.
**Resume trigger (2026-07-15 三方 multi-model synthesis)**: 同 CC-026，屬 skill 平台化早熟範疇。[[CC-493]] 已定案（`docs/skill-command-harness-policy.md`）：`skill-refine` 的
互動介面（`/skill-refine`）本身維持 command（Tier 3，`/foo` 觸發），但本票的 diff
generation 邏輯應輸出／操作 `skills/<name>/SKILL.md`，而非把邏輯本身寫成新的
`commands/skill-refine.md` 內容——是否需要仍待實際排入時評估，非本票定案範圍。
**Source**: PR #67 CC-025 M1 implementation and 2026-05-18 CC-025b closure decision in `feat/cc039-cc025b-v2`.

## CC-063 — [P2] Trace / token / gate metrics dashboard

**Problem**: `.agent-trace/*.jsonl`、`rate-limits*.json`、`.gate-results/*.md` 已積累豐富資料（per-session token、gate pass/fail、routing_log 校準記錄），但沒有視覺化介面；只能手動 grep。
**Why**: token 趨勢、gate 通過率、routing 準確度對長期 workflow 最佳化很有價值；資料已在，缺的是 consumer。
**Requirement**: `ops/diagnostics/dashboard.sh`（或 HTML report）：讀取 `.agent-trace/*.jsonl` 統計 per-session input/output token；讀 `.gate-results/*.md` 統計 GO/NO-GO rate；讀 `routing_log/*.csv` 計算 Q1/Q2/Q3 準確度。輸出 terminal-friendly 摘要表。

## CC-064 — [P2] Project bootstrap wizard

**Problem**: 新 repo 接入 pm-dispatch 需要手讀 GETTING_STARTED.md、手跑多個指令（`setup-project.sh`、memory init、rules 建立、PM schema 建立）；沒有一鍵引導流程。
**Why**: 降低接入門檻是 OSS 擴散的關鍵；現有 install.sh 處理 Claude 工具安裝，但不處理「把 pm-dispatch 接入現有 project」的 onboarding。
**Requirement**: `ops/setup/setup-project.sh --init <project-path>` 互動式引導：建立 `.claude/memory/`、`rules/` 骨架、`pm/BACKLOG.md` 模板、`.gitignore` 追加 artifact paths；結束時輸出「下一步」checklist。

## CC-065 — [P2] Per-repo configurable gate pipeline

**Problem**: 所有 repo 共用同一組 reviewer（architecture-reviewer、critic、qa-tester、risk-reviewer、security-reviewer）和 tier 預設。某些 repo（如純文件、seed data）不需要 security-reviewer；某些高風險 repo 應強制 full tier。
**Why**: 目前唯一的調整方式是每次手動傳 `--targeted` 或 `--tier`，無法設為 repo 級預設值。
**Requirement**: `.pm-dispatch/gate.toml`（per-repo）支援設定 `default_tier`、`required_reviewers`、`skip_reviewers`；`runtime/bin/pr-gate.sh` 讀取此 config 做為預設值（CLI flags 仍可 override）。

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

**Why**: Both issues were raised in gate-20260521-115634 as [medium] advise on PR #112. They share the same file surface (`install.sh` junction helpers) and the same root cause (Windows/Bash interop assumptions). One PR cleans up both cleanly.

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

**Problem**: `tools/lint/lint-frontmatter.sh` mixes CLI parsing, frontmatter boundary detection, and a ~150-line hand-rolled YAML subset parser in a single file. The parser logic (`check_frontmatter()`) has no stable call boundary, making it hard to reuse from other scripts (e.g., `doctor.sh` currently forks a subprocess to call the linter), hard to test in isolation, and hard to extend without touching the CLI script. Additionally (absorbed from CC-226), the 4 collection branches each repeat the same dq-escape whitelist regex and adjacent-quoted-scalar check, creating a silent parity-gap risk.

**Why**: User feedback after CC-058 gating. Doing both extractions together is the right call: the grammar contract becomes a first-class lib with clear ownership, and the shared helpers never diverge because there is only one call site.

**Requirement**:
1. Move `check_frontmatter()` and all YAML-subset validation helpers into `tools/lint/lib/yaml-frontmatter.sh`
2. Extract shared dq-escape/adjacent-quote/empty-entry helpers into the lib (eliminates the 4-branch repetition from CC-226); ensure a parity test or single call site prevents future per-branch divergence
3. `tools/lint/lint-frontmatter.sh` becomes a thin CLI wrapper that sources the lib
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
- Main-thread validation section appended per ``feedback_spike_validation_mandatory``.
- BACKLOG CC-209 row flipped to `✅ closed` with final verdict after Phase 2 lands.

**Priority**: P3 — feeds CC-232 / CC-237 design, not blocking other work.

**Cross-link**: CC-209 (Phase 1 origin), `docs/spikes/cc209-codegraph-phase1.md`, CC-255 (template improvements this depends on), CC-232 (context-pack consumer), CC-237 (enricher consumer), ``feedback_spike_validation_mandatory``.

## CC-259 — yaml.sh lib extraction（someday）

**Problem**: `_yaml_get` (bash/awk list extractor) and `case_yaml_parse` (structural validator) are currently inlined in `tests/shell/test-core-schemas.sh`. When a second test script needs YAML parsing, these helpers will be copy-pasted, diverging over time.

**Why**: Deferred from CC-229 M1 substrate PR to avoid expanding an already-large gate surface. The helpers were freshly written in CC-229 and have exactly one consumer; extraction before a second consumer exists is premature. Trigger for promotion: a new `test-*.sh` that needs to parse/validate YAML.

**Requirement**:
- Extract `_yaml_get` and `case_yaml_parse` into `tests/lib/yaml.sh` (source-able, no side effects on load)
- Wire `tests/lib/yaml.sh` into `tests/shell/test-core-schemas.sh` via `source` (replace inline definitions)
- Add `tests/shell/test-yaml-lib.sh` with independent unit tests for both helpers (cover key-found, key-missing, tab-indented, empty-file, no-key-line cases)
- Wire `test-yaml-lib.sh` into `run-all-tests.sh` and `.github/workflows/lint.yml`
- All existing test-core-schemas.sh cases must still pass (golden-parity)

**Acceptance**:
1. `grep -c "_yaml_get\|case_yaml_parse" tests/lib/yaml.sh` ≥ 2 (both helpers present)
2. `grep -q "source.*lib/yaml.sh" tests/shell/test-core-schemas.sh`
3. `bash tests/shell/test-yaml-lib.sh` → exit 0
4. `bash tests/shell/test-core-schemas.sh` → exit 0
5. `bash tests/bin/run-all-tests.sh` → exit 0

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

**Problem**: CC-206 added `pre-gate.sh` / `post-gate.sh` hooks directly into `runtime/bin/pr-gate.sh`. If future tools (e.g., `codex-dispatch.sh`, `brief-validate.sh`) also need hook points, each script will independently add its own pre/post blocks — resulting in inconsistent naming, invocation contracts, and user documentation.

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

**Problem**: `runtime/bin/pm-prep-snapshot.sh` derives `backlog_next_id` for the `CC-` prefix only — it emits `CC-NNN` and scans BACKLOG.md + BACKLOG-ARCHIVE.md for the max `CC-` id. Other-prefix repos (JS-, PA-) are not handled; a generic next-id that only read the working-set index would also reuse archived IDs (the §2.2 hazard fixed CC-only in CC-284).

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

**Update 2026-07-20（四方 multi-model synthesis）**: 四方（ChatGPT／Fable／opencode／codex gpt-5.6-sol）一致確認本票是 context-plane graph-lite 路線的樞紐。恢復時的設計補充：(a) Phase a 僅做 Bash literal `source`／`.` 邊，confidence 分級 EXTRACTED（literal 已解析）／INFERRED（穩定變數展開如 `$ROOT`）／AMBIGUOUS（動態路徑），沿用既有 `backend`+`confidence` 欄位慣例；(b) markdown 連結與 `[[...]]` 亦可作 EXTRACTED 邊；test 對應從 canonical suite registry（`tests/lib/test-suite-runner.sh`）derive 為 INFERRED 邊，不另建獨立 mapping 表；(c) auto-pack 已 default ON，原「reuse-scan 零 caller」顧慮已結構性降低，但 resume trigger（≥2 份真 brief 且缺 ref 資料為瓶頸）**仍未被證明**——開工前先翻真實 auto-pack brief 驗證，availability ≠ trigger satisfied；(d) 排序上 [[CC-505]]（檢索補完）先行，與 [[CC-347]] 作同一 evidence-gated 垂直切片交付。

## CC-347 — pr-gate: blast-radius analysis using cross-file refs 🟢 someday → v0.5.0 P3

**Problem**: 現行 gate 只審查 diff 內的檔案，但一個 Bash helper 或 schema 的改動，波及的是**所有 source 它的腳本**。gate 在不知道波及範圍的情況下做 risk review，等於盲目評估——risk-reviewer 無從判斷「修一行 state-writer.sh 是低風險還是影響 15 個腳本的高風險」。

**Why**: CC-346 的 `file_refs` 表提供了解析好的引用圖。在 gate brief 組裝時，對每個被修改的符號走一層 ref 圖，就能列出「直接受影響的未修改檔案集合」（blast radius）。這個資訊注入 brief 的 `context:` 節點，讓 risk-reviewer 和 security-reviewer 做有依據的 scope 評估。

**Requirement**:
- `runtime/bin/pr-gate.sh` 在組裝 brief 前呼叫 `pmctl context query` 取得 diff 中每個變更符號的 `refs`
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

**Update 2026-07-20（四方 multi-model synthesis）**: 與 [[CC-346]] Phase a 作同一垂直切片交付（edges 落地即接第一個消費者）。介面補充：新增 `pmctl context impact --changed <path>... [--depth 1] --json`，以 reverse `file_refs` recursive CTE 計算、附深度／數量上限與 cycle 抑制；輸出分四段——`direct_dependents`（EXTRACTED 邊）／`possible_dependents`（INFERRED/AMBIGUOUS）／`affected_tests`（直接 test-source/invocation 邊）／`truncated`（揭露截斷），並揭露 index freshness，防止 stale edges 造成虛假安心。gate brief 注入沿用既有 `pack.risks[]` 佔位欄。不做 ML risk scoring——fan-in 與 diff 特徵直接透明呈現給 reviewer。

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

## CC-516 — evidence-gated thin delivery wrapper 評估 ⏸ deferred

**Problem**: 一份分析建議立即新增 `/deliver` 或 formal lifecycle command，其他
分析則一致認為現有 `/ship`、gate、runner 與 publish primitives 已足夠，當前缺口
主要是契約漂移與文件 discoverability。現在新增 command/state machine 會在 runtime
truth 尚未收斂時複製 orchestration，並增加另一條會漂移的成功定義。

**Trigger**: [[CC-514]] 上線後累積至少 20 次真實 delivery 記錄；只有在記錄顯示
短 recipe 仍反覆發生相同 handoff／ordering 錯誤，或至少 3 次需要同一段人工 glue
才能完成，才啟動本 spike。偏好、想像中的便利或單次長流程不足以觸發。
每筆 evidence 至少分類為 `ordering_error|stale_artifact_reuse|omitted_stage|
repeated_manual_glue|false_success_claim`；若主要問題只是 discoverability，優先修
docs/help，不啟動 wrapper。

**Spike questions**:

1. 問題是否可由修正文案、help recipe 或既有 `/ship` 解決，而不新增 surface？
2. 若需 wrapper，最小版本能否只解析參數並順序呼叫 canonical primitives，同時
   回報各 dimension 的 artifact/status，而不擁有 reviewer、runner、publish 或
   state-transition 邏輯？
3. command、skill 或 `pmctl` leaf 哪個落點符合 [[CC-493]] 的升級判準？
4. 如何證明 wrapper 與 direct primitive path 產生相同 assurance artifacts，
   並在任何 partial/stale/failure 狀態 fail closed？

**Adopt boundary**: 最多交付 thin synchronous wrapper；不建立 workflow engine、
profile/preset DSL、persistent lifecycle state、FSM、resume scheduler 或第二套
gate/test schema。若需求實際是 multi-run parent control，回到 [[CC-508]]，不得
偷渡進本票。

**Dependencies**: [[CC-514]] shipped + trigger evidence。P3，未排入 milestone。

**Cross-link**: [[CC-493]]、[[CC-508]]。

---

## CC-546 — standalone Gate distribution／copy parity follow-up ⏸ deferred

**Problem**：CC-532 的 Linux/WSL2 canonical module extraction 已完成，但 standalone
distribution、installed copy bundle 與 canonical/dist parity 仍需要獨立的 bundle
schema、generation authority、install layout 與 support contract。把它留在 CC-532
會重新引入兩條 authoring/runtime authority，並使目前 developer-path scope 漂移。

**Requirement**：另行定義 bundle schema、生成與 freshness check、installed/copy
layout、缺件 fail-closed contract、canonical/dist behavior parity、CI/release
coverage 以及正式 support boundary。不得在本票前置實作 native Windows；不得把
copy compatibility fixture 誤當成 standalone distribution acceptance。

**Activation**：待 CC-517／CC-511 Phase B delivery closure 穩定，且實際需要
standalone distribution 的使用情境成立後再排程；在此之前保持 deferred。

---

## CC-534 — registry-driven CLI router + lazy loading 🟢 someday

**Problem**: `commands.tsv` 已驅動 help、discovery 與 lint，但 `cli/pmctl` 仍以大型
手寫 `case`、eager library sourcing 與重複 handler checks 執行 routing。Registry
與 router 是兩份 implementation，只能靠 awk lint 比對。

**Why**: Command metadata 若是 build-time authority，就應同時產生安全 routing
table；如此新增 command 才能只增加 handler、registry row 與 tests，並避免每次啟動
載入所有 command modules。

**Requirement**:

1. 擴充 command registry 表達 module、handler 與 argument mode，並在 build 階段
   產生 shell routing table；usage/stability/JSON/mutating metadata 維持同一來源。
2. Generic router 只接受固定 repo-relative module 與 safe function-name handler，
   lazy source 所選 module 後以直接函式呼叫 dispatch，不使用 `eval`。
3. Registry lint 驗 module/handler 存在、source-safe、command path 唯一，並以
   characterization fixtures 鎖定現有 argument forwarding、help、exit 與 JSON
   behavior。
4. [[CC-530]] source-safety 完成前不啟動 migration；完成後分批轉接，避免一次改寫
   全部 CLI contracts。

---

## CC-535 — supervised-run primitive + versioned JSON run-spec 🟢 someday

**Problem**: `detached-launch.sh` 已正確抽出 nonce、setsid/nohup、sentinel wait 與
process identity，但 Gate、Dispatch、Operation 上層仍各自維護 reserve、spec、
ready、terminal claim、cancel 與 reconcile。Dispatch supervisor 另使用
`key=value + native_b64` serialization，增加自訂 parser 與 schema drift surface。

**Why**: Gate 與 Dispatch 需要相同 lifecycle primitives，但擁有不同 policy、
preflight 與 artifact semantics。窄型 supervised-run layer可收斂真正共享的
control plane，而不演變成 generic workflow engine。

**Requirement**:

1. 在 `detached-launch.sh` 上定義 reserve ID、versioned spec write/read、launch、
   ready publication、wait、terminal claim、cancel 與 reconcile primitives。
2. Run-spec 採 versioned JSON 並以既有 jq prerequisite 驗證；native args、workdir、
   brief與 domain identity 不再使用自訂 key/value/base64 array format。
3. Gate policy、Adapter resolution、reviewer dispatch、brief/result validation 與
   artifact synthesis保留在各 domain；不得建立 DAG、FSM、preset DSL 或 generic
   workflow engine。
4. Parent與detached supervisor仍各自在自己的 trust boundary重新執行 preflight，
   但呼叫同一 shared implementation；不得以抽象化為由刪除 defense-in-depth
   invocation。

---

## CC-537 — data-driven test suite + impact registries 🟢 someday

**Problem**: Test suite names與paths在同一 shell file分開維護，changed-path impact
planner又以另一個大型 `case` 維護 path→suite mapping。Lint可以比對結構，卻無法
消除三份註冊 authority。

**Why**: Suite metadata與impact selection資料化後，可降低新增或改名 suite 時的
維護成本，也能讓 broad shared-path escalation規則明確可審；但 focused planner
不得取代 authoritative full suite。

**Requirement**:

1. 建立 suite registry，表達 name、path、timeout、serial group、tags 與 CI
   requirement；runner與`--list`從同一 authoring source取得資料。
2. 建立 impact registry，表達 path pattern、suite、reason與 escalation，
   並檢查 missing suite、unreachable rule、ambiguous precedence與 shared lifecycle/
   schema path缺少 broad escalation。
3. `run-tests.sh --base`只作快速 focused selection；release/gate authoritative
   evidence仍由 full runner及其 verification contract產生。
4. 用現有 changed-path fixtures做 before/after parity，另加入新增 suite只改
   registry即可被 runner與CI發現的 regression。

---

## CC-539 — state layout build-time authority + generated constants 🟢 someday

**Problem**: `core/state/layout.yaml` 自稱machine-readable state layout並宣告root、
partition、files、subdirs、schemas與writers，但runtime `state-paths.sh`仍手寫相同
constants，再由parity tests反向比對。文件宣稱與實際runtime authority不一致。

**Why**: State layout是public contract candidate的基礎；若YAML只作specification就
應明說，若作authoring authority就應在build階段產生runtime constants。維持模糊
狀態會讓每次layout change都要求人工同步兩份模型。

**Requirement**:

1. 將`core/state/layout.yaml`定為build-time authoring authority，產生
   `runtime/generated/state-layout.sh`等runtime constants；若實作盤點證明某欄位
   只能是parity specification，必須在schema與[[CC-446]] authority表明確降級，
   不得繼續宣稱runtime直接解析。
2. Generator涵蓋store root defaults、project/run subdirs、writer entrypoints與其他
   真正load-bearing constants，並以`--check`拒絕stale output。
3. Runtime啟動不得新增yq/Python或動態YAML parsing dependency；generation只發生
   在開發/build階段。
4. 保留`state-writer.sh` single-writer、atomic writes、rotation recovery與schema
   validation；layout generation不得重寫writer boundary或migration semantics。

---

## CC-506 — retrieval evidence-gated 收緊：shadow 評測與 broad-Read 指引 ⏸ deferred

**Problem**: [[CC-505]] 完成後索引「較完整、輸出較小」可被 fixture 證明，但「Agent 正確使用且不因少讀而降準」只能用真實任務證據證明。在證據到位前就收緊 broad-Read fallback，風險是 critical retrieval miss 直接轉成漏讀、錯設計或 gate 失敗。

**Requirement**:
1. shadow mode 蒐證：以 [[CC-505]] Phase 2 落地的 telemetry，累積 ≥20 個真實任務的記錄（檢索 top-5、實際讀取檔案／段落、最終修改檔案、測試檔案、gate 後補讀補改）。
2. 評測指標：required-anchor coverage@5（最終必要的既有檔案／章節有多少進前五）；critical miss（檢索缺漏導致錯誤設計、漏測或 gate 擋下）；read reduction（前後全檔 Read 次數、讀取 bytes、廣泛 Grep 次數）；outcome parity（focused/full tests、gate verdict、修正輪數）——不得只量 token 不量結果品質。
3. 收緊門檻（全部滿足才動指引）：exact-symbol fixture top-1 100%；canonical fixtures expected refs 全進 top-5；shadow tasks 無 critical miss；freshness／truncated／zero-hit fallback 皆有測試；gate 結果無明顯惡化。不要求所有相關檔案進 top-5，只要求必要 anchor 不漏。
4. 達標後：收緊 agent 導引中的 broad-Read fallback 措辭（保留 source-verified 原則）；以 observed read-reduction 數據重評 [[CC-340]] embeddings resume 條件。

**Done-when**: 評測報告落地（coverage@5、critical miss、read reduction、outcome parity 各有數字）；門檻判定有明確結論；達標則指引收緊 PR 合併、未達標則記錄缺口回饋 [[CC-505]]／[[CC-346]]。

**Non-goals**: 不新增索引技術；不做 embeddings 實作（僅重評 resume 條件）。

**Dependencies**: 前置 = [[CC-505]] Phase 2 shipped + 日曆時間蒐證（≥20 真實任務）。P3，未排入 milestone。模式沿用 auto-pack 先例：機制+telemetry 先行、evidence 後收緊。

## CC-568 — `/mem-distill` Case→Strategy 機械式提升：`episodes.jsonl` count/cluster 門檻 🟢 someday

**Problem**: `episodes.jsonl` 是既有的 episodic／raw-history 層（`/mem-log` 逐 session
append 的結構化摘要，已在 `pmctl memory stats` 中有 `episodes_total`／
`episode_fill_rate_pct` 等欄位），語意上已經接近文章分類法裡的「Case」，只是沒有被
明確標記成 Case。`/mem-distill`（`commands/mem-distill.md`）現況是把近期 `/mem-log`
session 與 `run.failed`／`guard.denied`／`task.blocked` 事件轉成 MEMORY 索引異動提案，
但「什麼樣的重複情況足以從單次 Case 提升成一張 Strategy 卡」目前沒有明確規則——實務上
是助理每次執行 `/mem-distill` 時憑印象判斷「這個好像出現過兩三次、感覺像個 pattern」。

**Why this shape（反模式說明，來自既有設計討論結論，勿重新開放）**:
1. **不建立獨立 Case 卡片層**。Case 應該留在 `episodes.jsonl` 的結構化欄位內
   （problem／resolution／evidence），不要變成每次失敗都新開一張
   `memory_subtype: case` 卡片——那會重新引入卡片稀釋問題，正是 `pmctl memory stats`
   的 `concentration`（`top5_share_pct`／`cards_never_hit`）指標存在的目的。只有真正
   晉升為 Strategy 的內容才落地成卡片。
2. **不加主觀的「感覺像 pattern」提升步驟**。`/mem-distill` 的 Case→Strategy 判斷必須
   基於對 `episodes.jsonl` 既有結構化欄位做機械式 count／cluster（例如同一
   topic／keyword 群集達到數字門檻），不是助理每次執行時的臨場判斷。門檻數字與
   clustering 依據（哪個既有欄位、如何正規化比對）由實作前的 `/pre-impl` 或本票的
   spike 階段定案，不在本票 Problem 敘述中預設鎖死。

**Requirement**:
1. 設計並實作對 `episodes.jsonl` 既有欄位的機械式 clustering／counting 規則
   （例如以既有 topic 或關鍵詞欄位分群，達到可設定的最小重複次數才視為候選 Strategy）。
2. `/mem-distill` 的提案輸出區分「本次仍留在 episode 層的 Case」與「已達門檻、建議升級
   為 Strategy 卡片草稿的候選」，維持既有的「產出提案、不直接寫入」的 dry-run 慣例
   （見 `commands/mem-distill.md` `--dry-run` 現況）。
3. 補齊：門檻邊界測試（剛好達標／差一次未達標）、跨 session 群集正確歸併、既有
   `episodes_malformed` 資料不得污染 clustering 結果。

**Non-goals**: 不建立獨立 Case 卡片 tier；不移除既有的人工確認寫入步驟；不預設具體門檻
數字（交由實作階段依真實資料定案）。

**Dependencies**: 前置 = [[CC-567]] 的 applied/outcome 證據——只有先看到哪些 Case 真的
被反覆套用且有正面 outcome，才知道 clustering 門檻設在哪裡才有意義，不要在沒有證據時
先建機制。與 [[CC-570]] 的分類法 metadata 正交但相關：本票只做 Case→Strategy 的
「何時該升級」判斷，不涉及 Fact/Case/Strategy 的顯式標記欄位。

---

## CC-569 — `pmctl task` / `context pack` 擴充 working-memory 敘事欄位 🟢 someday

**Problem**: 外部文章的「Working Memory」概念（目前在做什麼、已篩選哪些記憶、拒絕了哪些
路徑、卡在哪、下一步是什麼）在本 repo 已經有兩個既有的骨架承載者：`pmctl task` 的完整
生命週期狀態（`docs/pmctl-task.md` — create/claim/dispatch/status/review，`task.schema.json`
`additionalProperties: false`）與 `pmctl context pack` 的 task-scoped 組裝輸出（含
`memories[]` 陣列與 `context.packed` 遙測——`docs/context-retrieval.md` §Dispatch
auto-pack／§Shadow telemetry）。但兩者目前都不承載文章要的敘事欄位：
`selected_memories`（這次真的選了哪些記憶）、`rejected_paths`（考慮過但放棄的路徑）、
`blockers`（卡住原因）、`next_action`（下一步）。

**Why this shape（反模式說明，來自既有設計討論結論，勿重新開放）**: **不新建一個
`working_set.yaml` 或任何新檔案格式**來承載這些欄位。理由：`pmctl task` 已經是
「現在在幹嘛」的權威狀態來源（含 concurrency/rollback 保證，見
`docs/pmctl-task.md` §Concurrency and rollback），`context pack` 已經是任務範圍
retrieval 組裝的權威輸出。如果另開一個新的「working memory」檔案，它會與 `pmctl task`
狀態各自演化、彼此漂移，變成第二個難以同步的真相來源——這正是外部文章的建議裡我們刻意
不採用的部分。應該做的是把缺的欄位加進**既有** schema。

**Requirement**:
1. 盤點 `core/schema/task.schema.json` 現有欄位（`state`／`dispatched_to`／
   `brief_file`／`review_result`／`review_note`），評估 `blockers`／`next_action`
   適合加在 task schema 的哪個生命週期階段（例如 `status`/`review` 寫入時機），
   `additionalProperties: false` 的既有嚴格性必須保留，新欄位需顯式加入 schema。
2. 評估 `selected_memories`／`rejected_paths` 更貼近 `context pack` 輸出（本來就有
   `memories[]` 與 shadow telemetry 的 `top_k_refs`），還是貼近 task 狀態——由實作前
   `/pre-impl` 定案歸屬，不在本票預先鎖死。若可行，優先考慮直接擴充
   `context.packed`／`context.auto_packed` 既有 event payload，而非另開新 event kind。
3. 新欄位一律可選（optional），零填寫時不得破壞既有 `pmctl task`／`pmctl context pack`
   消費端；沿用既有的 fail-open／零信號誠實回報慣例。

**Non-goals**: 不建立新檔案格式或新的狀態儲存位置；不取代 `pmctl task` 既有的
state machine；不在本票內做 Case→Strategy 或 Fact/Case/Strategy 分類。

**Dependencies**: 前置 = [[CC-567]] 證明 applied/outcome 訊號有實際價值後再排入
——如果證據顯示 PM 選記憶的行為本來就穩定或影響有限，這些敘事欄位的邊際價值需要重新評估。
架構影響：本票涉及 `core/schema/` 既有 schema 擴充，實作前應先跑 `/pre-impl`。

---

## CC-570 — Fact/Case/Strategy `memory_function`／`memory_subtype` metadata 分類法 🟢 someday

**Problem**: 外部文章提出的三層分類（Factual／Experiential／Working Memory，
Experiential 再分 Case→Strategy→Skill）目前在本 repo 只有 Factual 的部分已經對應
（既有 4 層卡片 tier：`feedback_*`／`project_*`／`reference_*`／`user_*`，見
`docs/memory-system.md` §Four card tiers）。若要把 Case／Strategy／Skill 顯式標記為
卡片 metadata（例如新增 `memory_function`／`memory_subtype` frontmatter 欄位），
需要先確認這樣的分類機制真的有實際用途，而不是為了對齊一篇外部文章的分類法本身。

**Why deferred（刻意反轉文章建議的優先序）**: 外部文章建議先做分類/標記（Fact vs Case
vs Strategy metadata tagging），再做行為追蹤。本 repo 討論結論刻意相反：分類法本身不
產生行為改變，只有 applied/outcome 資料能告訴我們卡片稀釋、排序失效、或 Case 升級延遲
這些問題實際發生在哪裡。在沒有 [[CC-567]] 的一週份 applied/outcome 證據之前先建分類
machinery，是憑一篇文章的直覺蓋機制，屬於本 repo 已經吃過虧的模式（`episode_fill_rate_pct`
記載過先前的空骨架欄位案例）。

**Requirement（僅在啟動時展開，本票現況只記錄意圖）**:
1. 啟動門檻：[[CC-567]] 已交付並累積至少一段觀察窗（比照 CC-566／CC-467 先例的
   evidence-gated 啟動模式）之後，才重新評估本票是否值得做。
2. 若啟動，範圍應限定在為既有 4 層卡片 tier 疊加語意標記，不新建第 5 層卡片體系。

**Non-goals**: 不在證據到位前實作；不建立與既有 4 層 tier 平行的新分類體系；不吸收
[[CC-568]]（Case→Strategy 提升邏輯）或 [[CC-569]]（working-memory schema 欄位）的範圍
——三者關注點不同，合併會讓單票驗收條件模糊。

**Dependencies**: 前置 = [[CC-567]] shipped + 觀察窗證據。P3，不預設排入 milestone。

---

## CC-575 — test-governance Batch 1 存量遷移：其餘 pass-as-skip 站點 🟢 someday

**Problem**: `tests/lib/test-harness.sh` 的 case-level `skip()` primitive 與
authoritative-evidence gate（`test-result.sh`：任何 case skip → `authoritative:
false` + `contract: full-with-skips`）已落地，並遷移了 6 個代表站點（perl／
sqlite3／symlink／hardlink／jq 各一）。但實際掃描發現 pass-as-skip 站點 **40+**
（memory `test-governance-batches-plan` 寫的「8-9 處」嚴重過期）：`test-doctor.sh`
一個檔就有 ~30 處 `pass "$name (jq not available - skip)"`，另有
`test-core-schemas`／`test-install`／`test-pmctl-memory`／`test-runtime-lib-coverage`
的變體與 `UNAVAILABLE:` 裸行。一次全遷是 15 個套件的大 diff，是本案要治的
「測試系統變成第二套產品」風險。

**Why**: primitive 已存在且有契約測試護住，剩下的是**純機械遷移**——
`pass "$name (X unavailable)"` → `skip "$name" "<why X is needed>"`。低風險、
可分批、不需再動 harness／runner／schema。做完後 `pmctl gate stats` 之類的
authoritative 判定才真的看得到 skip 分母。

**Requirement**:
1. 把其餘 `pass "$name (... unavailable / not available / absent ...)"` 站點改用
   `skip "$name" "<reason>"`，reason 說明缺的是什麼、為何該 case 需要它。
2. `test-runtime-lib-coverage.sh` 的裸 `printf 'UNAVAILABLE: ...'` 行（既不 pass
   也不 fail、對計數隱形）改成 `skip`。
3. 不新增 harness／runner／schema 行為；不加 lint 禁止未來的 pass-as-skip（另議）。
4. 每批遷移後跑受影響套件確認：依賴存在時走真斷言（零 skip、零迴歸），
   依賴缺失時 `N passed, M failed, K skipped` 的 K 正確、套件仍 exit 0。

**Non-goals**: 不做 suite manifest／`optional`/`required` case 分類（[[CC-537]]，
park）；不加新 lint；不改 authoritative gate 條件（已是「任何 case skip → 非
authoritative」）。

**Cross-link**: `test-governance-batches-plan`（Batch 1 收尾）、[[CC-537]]。

---

## CC-578 — config-surface authority 標記 + drift check（CC-446 Req 6 拆出）🟢 someday

**Problem**：`docs/stability-contract.md`（[[CC-446]]）定義了「Stable schema／Internal
schema」兩層，但 repo 內 ~44 份規格檔——19 個 `core/schema/*.schema.json`、20 個
`*.yaml`（`hosts/*/host.yaml`、`adapters/*/adapter.yaml`、`adapters/*/isolation-map.yaml`、
`core/policy/*.yaml`、`core/state/layout.yaml`）、5 個 `core/policy/*.tsv`——沒有逐檔
宣告自己是 **runtime authority**（執行期真的讀它並據以行動）、**build-time authority**
（產生器的來源，例如 adapter-generate 讀 manifest）、還是 **parity/documentation
spec**（描述行為但執行期不讀，靠平行測試維持一致）。少了這個分類，重構時無法判斷
「改這份檔會不會靜默改變執行行為」，也無法保證每份 runtime authority 檔都真有單一
consumer + drift check（而不是一面宣稱 source of truth、一面維護等價手寫實作）。

**Why**：[[CC-446]] Req 6 原文。與 [[CC-451]] 同批評估——runtime 從不驗證的 schema
不應列 stable。此工作獨立於 stability contract 的核心價值（詞彙、SemVer、deprecation
流程已於 CC-446 落地），且逐檔判斷 + 多數需新增 drift 測試，是多 PR 工程，故拆為
獨立票而非拖住 CC-446。

**Requirement**：
1. 每份規格檔頂端（或一份中央 registry TSV）標記 `runtime-authority` /
   `build-time-authority` / `parity-spec` 三選一，附一行 rationale 與 consumer 路徑。
2. 每個 `runtime-authority` / `build-time-authority` 檔必須指到單一 consumer/generator
   函式，且有一個 drift check（parity 測試或 schema 驗證）確保手寫實作不漂移；缺者
   逐一補測試或降級為 `parity-spec`。
3. 既有 precedent 沿用：`core/state/layout.yaml` 已寫「Canonical shell definition:
   runtime/lib/state-compat.sh」、`docs/host-contract.md` 已有 authority 用語、
   `lint-script-domain-inventory.sh` 是同形狀的 ratchet——本票是把這個模式推廣到
   全部規格檔，不是發明新機制。
4. 一個 lint（或擴充既有 registry lint）強制「每份規格檔都有 authority 標記」且
   「runtime/build-time authority 檔在 registry 有 consumer + drift-check 欄位」。

**Done-when**：全部 ~44 份規格檔有 authority 標記；每個 runtime/build-time authority
檔有具名 consumer + drift check；一個 lint 機械強制此契約；`docs/stability-contract.md`
的「Stable schema／Internal schema」層可直接引用這份分類。

**Non-goals**：不改任何規格檔的內容或執行行為；不合併／拆分現有 schema；不做
`core/schema` 的 `$id`／`$ref` 重整（另議）。

**Dependencies**：[[CC-446]]（詞彙前置，已 done）、[[CC-451]]（同批評估 runtime 不驗證
的 schema）。

**See**: [[CC-446]] Req 6；DECISIONS.md 2026-07-04

## CC-581 — gate_reviewer_protocol_verify 二次方 block 累加 🟢 someday

**Problem**：`runtime/lib/gate-result-verify.sh:651` 的
`block="${block}${block:+$'\n'}${line}"` 在 `while IFS= read -r line` 迴圈裡逐行
累加 fenced reviewer_result 區塊；bash 字串串接每次都複製整段已累積內容，對區塊行數
是 O(n²)。[[CC-579]] census 實測 bash 端整體不是 gate 主成本（88% 在 jq），故當時
列為次要、未動。

**Why**：reviewer_result 區塊通常只有數十行，二次方成本目前無感；但這是已知的
演算法級劣化，值得在有人為別的原因動到 `gate_reviewer_protocol_verify` 時順手換成
一次性 `awk` 抽取或陣列 append + `printf '%s\n'`。獨立排程投報不足。

**Requirement**：把逐行 `block=` 字串累加換成 O(n) 做法（例：`mapfile` 到陣列後
`printf`，或單次 `awk` 依 fence 切檔），維持現有 fence 巢狀／截斷／空區塊的失敗語意
與 `GATE_REVIEWER_PROTOCOL_DOCUMENT_ERROR` 值不變；`test-pr-gate.sh` 的 reviewer
protocol case 全綠。

**Non-goals**：不改 fenced-block 契約、不動 per-reviewer 逐檔驗證鏈的行程邊界
（[[CC-573]] 禁區）。

**See**: [[CC-579]]（本票的觸發來源與次要目標段）

---

## CC-592 — qa-tester 的 codex sandbox 結構性地無法啟動真實 Windows process 🟢 someday

**Problem**：qa-tester 作為 codex-dispatched reviewer，在原生 Windows 上似乎
完全無法啟動任何真實的 OS-level process（例如 `powershell.exe`／Windows Job
Object）——不是變慢，而是完全沒有任何進展或輸出。

**實測重現**：CC-590 落地過程中，同一個新增的 regression test（會啟動一個真的
detached Windows Job Object supervisor，再由獨立步驟強制 kill 掉它）被 qa-tester
的 codex-dispatched reviewer session 嘗試重新執行了兩次，兩次都是完全獨立的
session：
1. Sequential mode，90 秒 bound：`timeout --kill-after=15` 逾時（exit 124），
   log 檔案完全 0 bytes。
2. Parallel mode（每個 reviewer 各自獨立 session），120 秒 bound：同樣逾時
   （exit 124），log 同樣完全 0 bytes。

同一個測試由主執行緒（非 sandbox）直接執行超過 5 次，每次都在 10 秒內通過
（含真實 Job Object 啟動＋強制 kill＋偵測），與 qa-tester 兩次「完全零輸出」
形成強烈對比——如果只是單純變慢，log 裡應該至少看得到測試 suite 最初幾個
case 的 PASS/FAIL 行。

**Why（推測，尚無決定性訊號）**：訊號型態（完全零輸出、非部分進度）與本
repo 已記錄的兩個原生 Windows sandbox 案例同一類：
- issue #609：AppContainer 阻擋 MSYS2 對 `\BaseNamedObjects\`
  全域 namespace 的存取。
- issue #619：codex 在原生 Windows 的 `exec_command` sandbox 決定性拒絕
  （`helper_unknown_error: setup refresh had errors`）。

但這次的差異是：發生在 **reviewer 的驗證路徑本身**，而不是 gate 的 producer
（`gate run`）端；且沒有像 #619 那樣的明確錯誤訊息可供 grep 辨識，只有沉默的
逾時。

**Requirement（spike 先行，尚未確定修法方向）**：
1. 收集更多樣本：在不同 tier／mode／timeout 下重現，確認是否 100% 可重現，
   或僅是高機率。
2. 確認具體卡住的位置：是 `mkfifo`／`read -t`，還是 `powershell.exe` 呼叫
   本身被 sandbox 靜默掛起。
3. 評估修法方向：(a) 讓 qa-tester 的測試執行改用一個不需要真實 process 啟動
   的替代驗證手段（例如結構化 evidence 交接，而非重新執行）；(b) 若確認是
   codex sandbox policy 的限制，评估是否能透過 dispatch 時的 sandbox 參數
   放寬（`isolation_level`／`--sandbox` 等）取得权限；(c) 記錄為已知限制，
   要求審查涉及真實 process 啟動的變更時一律走人工驗證＋accepted risk，
   不強求 qa-tester 自動化覆蓋。

**Non-goals**：不假設現有的 accepted-risk workaround（記錄在
`.gate-overrides.md`）不再需要——即使本票修好，既有 override 紀錄仍應保留
作為歷史紀錄。

**Done-when**：spike 產出一份決策文件（`docs/spikes/CC-592.md`），明確判定
根因與建議走向（修復／規避／接受現狀三選一），供後續票依循。

**See**: [[CC-590]]（2026-09-27 gate 過程中兩輪獨立命中同一訊號的 session）；
GitHub issue #609；GitHub issue #619；`.gate-overrides.md` 內 CC-590 相關的
accepted-risk 紀錄

---

## CC-602 — timeout-kill 時誤導的 `printf: write error: Permission denied` ⚠️ partial 2026-10-01

**Problem**：GitHub issue #633：context workflow-refresh 被 `timeout -k 5` 終止時，有時
會印出 `printf: write error: Permission denied`，而不是安靜地結束。[[CC-596]] 處理了同一個
kill 情境的暫存檔洩漏，但沒有處理這個訊息。

**Requirement**：查明寫入失敗的 fd 與來源，讓 kill 後不輸出誤導訊息。

**Done-when（原文，尚未達成）**：以與 issue 相同的重現步驟不再出現該訊息。**無法達成**，
因為本機從未重現出該訊息（沒有基準可比較「不再出現」）。**已驗證的主張**（見下）：fallback
值寫入失敗現在是安靜的，由測試釘住。

**狀態 `⚠️ partial`（pr:#653，2026-10-01；PR 於本次更新時尚待合併）**：緩解已交付，但原始
觸發條件未重現、涵蓋不完整，所以不標 ✅ done，PR 用 `Refs #633`，issue 保持開啟。
**已交付**：新增 `_ctx_fallback`（`printf '%s' "$1" 2>/dev/null || :`），`pmctl-context.sh`
中放在 `$(...)` 內的 7 個 fallback `printf`（`_ctx_file_mtime`、`_ctx_file_sha1`、
`_ctx_now_epoch`、兩個 `wc`、兩個 sqlite3 FTS 探測）改用它。新增測試用關閉 stdout（EBADF，
與 issue 的 EACCES 走相同程式路徑與訊息）驗證：舊版印出
`line 361: printf: write error: Bad file descriptor` 並以 rc 1 結束，新版安靜且 rc 0；值在
stdout 開著時不變。**未重現的證據**：在 `main` 與 CC-595 之前的 commit `a4241e0` 上各對真實
`workflow-refresh` 於 4–15 秒殺 12 次（每次全新 index）、確定性的「只殺讀取端」測試、100 次
壓力測試，皆 0 次命中；[[CC-595]] 已移除大部分逐檔案 `$(...)`，與此吻合。原始診斷（kill
時 `stat` 等工具先死、fallback 寫入已無讀取端的管線）是 issue 提出者的推論。**未涵蓋**：同一
kill 路徑上其他寫入（受限 wrapper 的 `>&2` 進度行、`printf >> "$batch_sql"`、
`_ctx_extract_symbols`／`_ctx_chunk_emit` 這類 `< <(...)` producer）以及其他 lib 約 15 處同樣的
`|| printf` 寫法。**收尾條件**：原生 Windows 上實際確認 gate／dispatch log 不再出現該訊息，
或取得重現並辨識失敗的 fd，後續見 [[CC-608]]。**審查方式須如實記錄**：未走 `pmctl gate
run`，由五位 reviewer 分別審查（皆無 block），沒有 gate result artifact、沒有 authoritative
full-suite 結果，且審查者與實作者同模型家族。

**See**: GitHub issue #633；[[CC-596]]；[[CC-595]]。

---

## CC-604 — `gate-scope.sh` 收尾整理 🟢 someday

**Problem**：[[CC-599]] 把 symbol 搜尋批次化後，審查提出但刻意不併入該 PR 的三項整理：
(1) `_gate_scope_expansions_collect_into` 已經很大，自然的拆法是兩個 per-source
emitter（shell consumer hints、symbol call-site hints），並可共用同一組動態範圍表格；
(2) tracked 檔、untracked 檔與 shell consumer 三處都在做「一個檔案內出現哪些 symbol」，
讀檔方式不同（`git grep -o` 輸出、工作樹 `grep -o`、`_gate_scope_path_content`），
可在下次修改時抽成共用 helper；(3) fixed-head 模式下，每個來源仍對 12 個副檔名各做
一次 `git cat-file -e`（`_gate_scope_path_exists`），每個 consumer 一次 `git show`，
是 CC-599 之後 fixed-head 剩餘的固定成本（真實 diff 仍需約 14 秒）。

**Requirement**：依上述三點整理，行為不變；沿用 CC-599 的新舊輸出逐位元比對方式驗證
（同一份輸入、舊版 `gate-scope.sh` 對新版）。

**Done-when**：真實 diff 與合成 fixture 的 manifest 與整理前逐位元相同；fixed-head 模式
耗時可量測地下降；`scope-collector/*` 與既有 scope-manifest 測試維持通過。

**See**: [[CC-599]]；[[CC-600]]。

---

## CC-606 — `awk -v` 反斜線跳脫造成 policy key 驗證與 bash 比較不一致 🟢 someday

**Problem**：[[CC-600]] 的 security-reviewer 以實測指出（既有問題，非該 PR 引入）：
`_gate_assurance_policy_lookup` 以 `-v wanted="$key"` 傳值，awk 會處理 `-v` 值中的
反斜線跳脫，所以 `--tier 'expre\163s'`（八進位跳脫）與結尾為反斜線的
`--tier 'express\'` 都會比對到表格中的 `express`，通過 `pr-gate.sh` 的驗證；但原始字串
仍存入 `TIER_OVERRIDE`，之後 `[[ $TIER == express ]]` 之類的 bash 比較不會相等。需要
本機 CLI 控制權，不是提權，是驗證正規化不一致。

**Requirement**：讓 lookup 以位元組原樣比較 key：改用 `ENVIRON` 傳值（不經跳脫處理），
或在 lookup 前拒絕含反斜線的 key；一併檢查 `_gate_assurance_policy_values` 與
`pr-gate.sh:395-409` 的 `--tier`／`--mode` 驗證路徑。

**Done-when**：`--tier 'expre\163s'` 與 `--tier 'express\'` 被拒絕（與其他未知 tier 相同
的錯誤與 rc）；既有 lookup 行為不變。

**See**: [[CC-600]]。

---

## CC-607 — worktree 主 checkout 解析與 drive-path 判斷的收尾整理 🟢 someday

**Problem**：[[CC-601]] 修好 Windows linked worktree 的主 checkout 解析後，審查列出幾項刻意
不併入的整理：(1) `_pmctl_worktree_main_root`（`pmctl-worktree.sh`）與
`_sw_main_repo_root`（`state-paths.sh`）近乎重複，CC-591／CC-601 已因此連續被重修；自然方向是
前者委派給後者（`pmctl-worktree.sh` 本來就會載入 `state-paths.sh`）；(2) `portable.sh` 內解析
根目錄的 `case [A-Za-z]:/*` 分支與 jq 內的 `test("^[A-Za-z]:...")`（`gate-result-verify.sh`
只接受 `X:/`，`host-doctor-primitives.sh`、`hosts/claude/lib/doctor.sh` 接受 `X:[/\\]`）無法
呼叫 bash 謂詞，已出現不一致，未來容易再漂移；(3) `tests/lib/test-memory-config-fixtures.sh` 與
`tests/shell/test-pr-gate.sh` 的測試輔助仍有 `--git-common-dir` 加 `== /*`；(4) common dir 不是
`<root>/.git`（submodule、`--separate-git-dir`）時 `dirname` 回傳其父目錄，POSIX 上早就如此，
Windows 上以前因為 drive-letter 被當成相對路徑而碰巧走 `--show-toplevel` fallback 答對。

**Requirement**：依上述整理，行為不變；jq 的 regex 至少統一接受的分隔符；為 (4) 決定是否改用
`git rev-parse --show-toplevel` 對照，或檢查 common dir 的 basename。

**Done-when**：`_pmctl_worktree_main_root` 不再自帶判斷；jq regex 與 bash 謂詞接受的集合一致並有
測試；既有 `main-repo-root/`、`worktree main root:` 測試維持通過。

**See**: [[CC-601]]；[[CC-591]]。

---

## CC-608 — kill 時 context refresh 其餘寫入的 `write error`：辨識實際失敗的 fd ⚠️ partial 2026-10-23

**Problem**：[[CC-602]] 依 issue #633 提出者的建議，只靜音了 `pmctl-context.sh` 中放在 `$(...)`
內的 7 個 fallback `printf`。原始觸發條件（原生 Windows、`timeout -k` 終止受限 refresh 時
偶爾出現 `printf: write error: Permission denied`）在本機從未重現（`main` 與 CC-595 之前的
commit 各 12 次真實 kill、確定性機制測試、100 次壓力測試皆 0 次命中），所以不知道實際失敗的
是哪個 fd。同一 kill 路徑上其餘寫入仍未保護：`pmctl_context_workflow_refresh_bounded` 的
`printf ... >&2` 進度行；`printf >> "$batch_sql"`（寫檔，不是管線，較不可能）；
`_ctx_extract_symbols`／`_ctx_chunk_emit` 這類 `< <(...)` producer（寫入的管線其讀取端就是會被
kill 的索引 shell，CC-595 到 CC-598 之後是逐檔案的主要工作）；以及其他 lib 約 15 處同樣的
`|| printf` fallback（`pmctl-artifacts.sh`、`pmctl-memory.sh`、`pmctl-worktree.sh`、
`pmctl-gate.sh` 等）。

**Requirement**：先取得重現或證據（在原生 Windows 以 `timeout -k` 殺受限 refresh，並用
`BASH_XTRACEFD`／把 fd 1 與 2 導到已關閉的管線辨識失敗的 fd，或請 #633 提出者在新版上重測並
附完整 stderr），再決定保護方式：producer 加 `2>/dev/null`、子程序收到 TERM 後安靜退出、或
移除剩餘逐檔案 `$(...)`（CC-595/597/598 的方向）。不要在沒有證據時對全部寫入加 `2>/dev/null`，
那會掩蓋真正的診斷。

**Progress 2026-10-23（部分完成，尚未關閉）**：原生 Windows 上以 `timeout -k 5 <0.5 到 12 秒>` 殺 refresh 共 64 次，只有 1 次（0.5 秒）出現 stderr：`jq: error: writing output failed: Invalid argument`；`printf: write error: Permission denied` 本身仍未重現（n=1，結論僅為「不一定是那 7 個 `printf`」）。緩解放在 `pmctl_context_workflow_refresh_bounded`：child stderr 先進暫存檔，逾時（124／137）時重放前丟掉這兩種訊息（printf 那種是照 #633 的回報文字，不是觀察到的），其他行與沒被殺的執行完全保留；代價是 child 的進度行改在它結束後才輸出。新案例 `case_context_refresh_bounded_drops_kill_write_errors`（拿掉過濾會失敗）。這是症狀層的緩解，根因層的做法（refresh child 收到 TERM 後安靜退出）與辨識實際失敗的 fd、請 #633 提出者重測都還沒做。

**Done-when**：取得可重現的步驟或在 Windows 上確認 gate／dispatch log 不再出現該訊息，並以測試
釘住所選的保護；#633 因此可以關閉。

**See**: [[CC-602]]；GitHub issue #633；[[CC-595]]／[[CC-597]]／[[CC-598]]。

---

## CC-610 — lint：EXIT trap 用到的函式必須先於 trap 定義 🟢 someday

**Problem**：[[CC-609]] 的缺陷型態（trap 提早安裝，handler 內呼叫的函式定義在後面）可在任何
`set -u` 腳本重現。只檢查 handler 名稱的淺層 lint 會漏掉它，因為
`qa_execution_finalize` 是從 `gate_exit_cleanup` 本體內被呼叫。

**Requirement**：實作一個 lint（`tools/lint/`），對每個 `trap <handler> EXIT`，沿 handler
本體追蹤傳遞呼叫，確認被呼叫的、定義在同一檔的函式都定義在該 trap 之前；並以一個故意違規的
fixture 證明它會失敗。

**Done-when**：lint 納入 CI，對現有 `pr-gate.sh` 通過（範圍含 `runtime/lib` 中被 source 的函式，或明確只檢查同一檔內定義的函式並寫明），對重現 CC-609 的 fixture 失敗。

**See**: [[CC-609]]；GitHub issue #650。

---

## CC-612 — `adapter_manifest_file` 重複驗證 🟢 someday

**Problem**：見索引列。每次呼叫都重做目錄與 manifest 的 realpath 與 schema／name 檢查。

**Requirement**：減少重複驗證的行程數，同時保留 symlink、「不得逃出 adapters/」與
`schema_version`／`adapter_name` 的保證。快取鍵與失效條件必須明確，並經 security-reviewer 審查。

**Done-when**：行程數下降（xtrace 證明）；既有 adapter 測試維持通過；新增測試證明被替換成
symlink 或改名的 adapter 仍被拒絕。

**See**: [[CC-611]]；GitHub issue #650。

**Update 2026-10-06（部分完成）**：[[CC-637]] 批次 1 去掉 `dispatch_path`、`effective_route`、`runner_kind` 內部對 `adapter_manifest_file` 的重複呼叫（不用快取，檢查內容與順序不變，`dispatch_path` 1757 到 740 毫秒）。呼叫端各自逐次呼叫 `adapter_manifest_file`（`executor-router.sh`、`pr-gate.sh` 的迴圈、guard hook 的四次呼叫）仍未處理，快取方案仍需 security-reviewer 審查。

---

## CC-614 — `gate-result-verify.sh` 重複驗證的剖析與去重評估 🟢 someday

**Problem**：見索引列。

**Requirement**：先以更細的剖析（逐次呼叫的輸入與階段）列出每次驗證的目的，判斷哪些是冗餘；
只對確認冗餘者去重。**不得削弱任何驗證保證**。

**Done-when**：產出一份「每次驗證為何存在」的對照，並對可去重者以行程數與測試證明；或記錄結論
「皆必要」並關閉本票。

**See**: [[CC-611]]；GitHub issue #650。

---

## CC-620 — `gate wait` 的失敗原因改為 sentinel 欄位 ✅ 2026-10-23

**Problem**：見索引列。

**Requirement**：`gate-supervisor.sh` 在寫終態 sentinel 時加入 `failure_reason=`（log 的最後一個 `Error:` 行，去除控制字元、
截斷），`pmctl gate wait`、`gate status`、`pmctl ship` 共用；log grep 留作舊 sentinel 的 fallback。先查 dispatch 的失敗紀錄
是否有可對齊的欄位。不得把子 session 的輸出當成權威原因。

**Resolution 2026-10-23**：#725。`gate-supervisor.sh` 在終態 sentinel 為 `failed` 時寫 `failure_reason=`（共用函式 `detached_launch_failure_reason`：最後一個 `Error:`／`INCOMPLETE:` 行，去除控制字元、每行截 300 字元，多行以 ` | ` 連接）；`pmctl gate wait` 優先讀它，舊 sentinel 仍用同一函式讀 log。`gate wait` 對 `failed` 印 `failed is an execution error, not a review verdict`，對 GO／NO-GO sentinel 但結果檔無法確認的六個 `FAIL:` 出口印 `an integrity error (exit 2), not a review verdict`，與 NO-GO 既有的 `NO-GO is the gate verdict` 成對。測試證明第二次 `gate wait` 在 log 被刪後仍報告原因（拿掉欄位會失敗）。

**Non-goals**：只有 `gate wait` 是消費端；`gate` 沒有 `status` 子命令，`pmctl ship` 不讀 sentinel，前景 `gate run` 也沒改，這三處的 failed 與 NO-GO 區分見 [[CC-666]]。

**See**: [[CC-615]]。

---

## CC-621 — parent 端驗證 policy 表與檔案相關的選項值 🟢 someday

**Problem**：見索引列。

**Requirement**：抽出「驗證 `--tier`／`--mode`／`--pass` 的值（含與 policy 的一致性）」的函式，`pr-gate.sh` 與 `pmctl gate run`
的 parent 共用；`--brief`／`--output`／`--policy-override`／`--reviewers` 的內容檢查評估是否適合提前（涉及檔案與 repo 狀態，
可能維持在 pr-gate 內）。

**Done-when**：`pmctl gate run --tier bogus` 在 parent 即以 exit 2 失敗，不啟動 supervisor；有測試。

**See**: [[CC-615]]。

---

## CC-622 — Windows 寫的結果檔帶 CRLF 時，整行比對的讀取端會失效 🟢 someday

**Problem**：見索引列。

**Requirement**：先在 Linux awk（CI 的環境）重現：把 CRLF 的 staging 結果與 reviewer 輸出餵給 normalizer 與各讀取端，確認哪些失敗。
若要修，優先在「檔案進入 gate 的第一個邊界」（normalizer 與 reviewer 輸出的收取點）一次性把 CRLF 轉為 LF（staging 檔本來就會被完整重寫），
而不是讓每個讀取端各自容忍。不得放寬已發布結果的驗證。

**Done-when**：CRLF 的 staging 與 reviewer 輸出在 Linux CI 上被接受或明確拒絕，有測試。

**See**: [[CC-618]]。

---

## CC-623 — QA 證據記錄的 log 雜湊與封存的 log 不一致 🟢 someday

**Problem**：見索引列。

**Requirement**：先重現：在 Linux 與 Windows 各跑一次 timeout 的 QA helper（`qa-test-attempt-*.sh`）再走完 gate 結尾的 `relocate_gate_artifacts`，比對記錄的與搬移後的雜湊；
區分「殘存子行程在雜湊之後寫入」（helper 應確保整個 process group 結束再算雜湊）與「搬移過程改動檔案」。不得因此放寬證據的完整性檢查。

**Done-when**：找到原因並修復，有測試（雜湊等於封存 log 的 sha256）。

**See**: [[CC-617]]。

---

## CC-626 — QA execution 證據的發布後強制與逐次歷史 🟢 someday

**Problem**：見索引列。

**Requirement**：先決定 (1) 與 (2) 的語意（assurance 的 schema 版本、exit 3 的呼叫端相容性），再做 (3)–(6)；不得放寬 CC-624 的拒絕。

**Done-when**：`pmctl gate verify` 能拒絕一個建立在 inconclusive QA 證據上的 GO；逐次歷史有測試；拒絕次數可量測。

**See**: [[CC-624]]；[[CC-617]]。

---

## CC-628 — Windows symlink 偏差與 subject 規則的可觀察性 🟢 someday

**Problem**：見索引列。

**Requirement**：先重現 `core.symlinks=false` 的偏差，決定 `working_tree` 對 tracked 120000 項目的處理（以 index 記錄的型別與連結目標為準）；補 skip-prefix 與 symlink-as-file 的判別性測試；評估 assurance 的 `subject.mode_source` 欄位。

**Done-when**：同一個 commit、乾淨工作樹時，含 symlink 的 repo 在 Windows 的 `working_tree` 與 `fixed_ref` 指紋相同，有測試。

**See**: [[CC-619]]；[[CC-627]]。

---

## CC-631 — git 失敗注入的共用測試夾具 🟢 someday

**Problem**：見索引列。

**Requirement**：抽出 `tests/lib/git-stub.sh`（簽章見索引列），先遷移 CC-627 與 CC-629 的測試，行為不變；在環境變數清冊登記一次；不要與行為修改的 PR 混在一起。

**Done-when**：五個 suite 共用同一個夾具，原有的變異測試仍全數被抓到。

**See**: [[CC-629]]；[[CC-627]]。

---

## CC-632 — ship 與 pr-gate 的 git 狀態讀取的建議性加固 🟢 someday

**Problem**：見索引列。

**Requirement**：逐項評估索引列的四點，每項用 git 替身或臨時建立的目錄重現後再修；(1)(2) 會改變 `git status` 的輸出，需確認不影響既有的 dirty 判斷。

**Done-when**：(1) 的同名目錄情境有測試；其餘項目各有結論（修或明確放棄）。

**See**: [[CC-629]]。

---

## CC-633 — 抽出共用的 gate-git.sh 🟢 someday

**Problem**：見索引列。

**Requirement**：只在觸發條件成立時做；純重構、不改行為，先列清要動的檔案（安裝清單、bootstrap 迴圈、複製 lib 的測試夾具、`run-tests.sh` 高扇出分類、測試登錄、環境變數清冊），同一個 PR 內遷移 `gate-scope.sh` 與 `gate-subject.sh`，並讓 CC-627／CC-629 (a) 的測試原樣通過。

**Done-when**：兩個 helper 合一，原有的變異測試仍全數被抓到。

**See**: [[CC-629]]；[[CC-631]]。

---

## CC-634 — gate-digest.sh 的工具探測合併 🟢 someday

**Problem**：見索引列。

**Requirement**：合成單一選擇函式，兩種模式共用；保持 CC-611 的成本契約（初始化後每個摘要一個工具行程，逐次路徑維持原本的探測成本）。

**Done-when**：`test-gate-digest.sh` 全數通過，包括行程計數的案例。

**See**: [[CC-629]]；[[CC-611]]。

---

## CC-640 — 缺省目標目錄的後續：非 git 目錄的破壞性子命令與重複的推導 🟢 someday

**Problem**：見索引列。

**Requirement**：
1. 決定 `artifacts gc|migrate`、`worktree gc|remove` 在沒有 `--cd` 且目前目錄不在 git work tree 內時的行為：回用法錯誤（exit 2，要求 `--cd`），或保留現狀並在輸出標明正在處理 `global` 分區。`artifacts list|show` 與 `gate` 是否維持現狀一併決定（dispatch 在 repo 外執行時 `global` 分區是合法的資料位置）。
2. 把 `_pmctl_gate_default_cd`、`pmctl_pm_default_cd` 併到 `portable_default_work_dir`，前提是兩個庫單獨載入（測試）時能取得它。

**Done-when**：需求 1 的決定有測試（非 git 目錄、`--dry-run` 與實際 gc 各一）；需求 2 之後 repo 內只剩一份推導。

**Trigger**：有人在非 repo 目錄誤跑 `artifacts gc`，或第四份副本出現。

**See**: [[CC-639]]。

---

## CC-643 — 原生 Windows 測試分流的後續 🟢 someday

**Problem**：見索引列。[[CC-641]] 結案時審查提出而沒做的項目，以及 [[CC-642]]、GitHub issue #621 與 #650 留下的後續，收在這裡。每項都是一個決定：現在不做，以及什麼情況下再做。

**Requirement**（每項「觸發」才動手，不是現在排程）：
1. 狀態 emoji 的清單分散在 `_pra_trailing_status`、`_pra_leading_status_emoji`、`validate.sh`、`archive-closed-backlog.sh` 與一個 lint。觸發：需要第三個針對基本平面以外 emoji 的 gawk／grep 變通 → 抽成共用的 `status-emoji` 函式庫。未驗證是否受影響：`check-planning-status-consistency.sh` 的 bash `case` 樣式，以及 export `C.UTF-8` 的入口（`doctor.sh`、`dispatch-post-verify.sh`、`release-verify.sh`、`check-docs-freshness.sh`、`tests/bin/run-tests.sh`、`tests/lib/test-suite-runner.sh`）。
2. `case_gate_remediation_closure_null_locator_rejected` 同時斷言與 CLI 無關的執行期驗證器，沒有 `jsonschema` 時一起被跳過。觸發：有人需要在沒有 `jsonschema` 的環境看到該驗證器的結果 → 拆成獨立案例。
3. archive 腳本改按位元組後沒有「非 ASCII 標題原樣搬移」的案例。觸發：再改 `archive-closed-backlog.sh`。
4. 舊的各自探測（`test-state-paths.sh` 的 `_mk_verified_symlink`、`test-state-store.sh` 內嵌的兩處 symlink 檢查、`test-pmctl-operation.sh` 的 `_require_setsid`、`test-doctor.sh` 的 `_TD_CAN_SYMLINK`）尚未改用 `th_require_*`。觸發：第三份不一致的探測出現，或放寬 `test-test-harness.sh` 釘著的跳過字串。
5. `cygpath` 「有就轉」的樣式在 `portable.sh`、`gate-result-verify.sh`、`state-writer.sh`、`pmctl-artifacts.sh`、`pmctl-worktree.sh` 各一份。觸發：第六份出現 → 收斂成 `portable.sh` 的 `portable_native_path`（不能直接用 `_portable_canonical_path`，它會把磁碟機代號改小寫、與 git 輸出比對會失配）。
6. 其餘 `jq --arg <絕對路徑>`：`pr-gate.sh`、`gate-scope.sh`、`pmctl-memory-config.sh`、`pmctl-operation.sh`、`pmctl-pm.sh`。兩邊都經過 jq 的比對會一起被改寫、結果一致；只有「一邊經 jq、另一邊是 shell 變數或人看的輸出」才會出問題。觸發：在原生量到實際差異。`pmctl memory resolve --json` 與 `artifacts show --json` 在原生的路徑寫法不同（`C:/` 對 `/c/`），`test-skill-refine.sh` 以測試端改寫遮住了前者。
7. 把路徑交給原生 `git` 的其他程式碼，與 `git worktree add -b … "$base"` 沒有 `--`。repo 路徑本身含 `[`／`*`／`?` 時 `git -C` 直接報 `cannot change to`，失敗即停、不會誤刪（已量測，列在 `docs/platform-support.md`）。觸發：有人回報。
8. `pmctl worktree gc` 的「是否仍被追蹤」現在是兩個訊號（`git worktree list` 比對加檢出目錄 `.git` 指向的管理目錄是否存在）。更穩的作法是改問 git（`git worktree list --porcelain -z` 配合 `realpath`）。觸發：兩個訊號仍在某個環境不一致。
9. `_pmctl_artifacts_fsync_file` 比對英文「Permission denied」，本地化的 coreutils 不會走備援（失敗方向是保留 run，安全）。`test-pmctl-operation.sh` 內嵌的 `ps -p … | awk` 與 `detached-launch.sh` 的 `_dl_win_winpid_of` 重複。`run_watch_for_sample` 在原生用固定 12 秒視窗（改成輪詢會更快，但案例斷言整段輸出，提早結束可能截斷）。觸發：各自出現第二個使用者或實際不穩。
10. [[CC-642]] 留下的：非 git 目錄的專案鍵後備（`pmctl-config.sh`、`pmctl-memory.sh:171`）直接雜湊路徑，沒有走 `_portable_canonical_path`；`_pmctl_worktree_git_path` 與 `gate-result-verify.sh` 的 `cygpath -m` 沒有加 `-l`（它們產生給原生行程用的寫法，不是身分鍵）；`cygpath` 失敗走後備時沒有記錄。
11. 沒有 `PM_REQUIRE_CAPABILITIES` 之類把探測跳過變成失敗的開關：由 `test-test-harness.sh` 的哨兵（Linux 非 root 時每個探測必須回報「有」）代替；該套件從 CC-641 結案的 PR 起在 CI 執行。以 root 執行時需要「chmod 000 檔案不可讀」的案例會跳過，經 `run-tests.sh` 的完整驗證因此是非權威的，接受。

12. CI 加固（審查提出，皆為整個 repo 既有的做法）：所有 `actions/checkout@v6` 都沒設 `persist-credentials: false`（唯讀 token，沒有套件需要 push）；`lint-test-suite-registry.sh` 只確認套件路徑出現在某個 `run:` 區塊，無法證明迴圈真的執行它（刪掉 `exit 1` 檢查 lint 仍綠）；兩個新任務的迴圈逐字重複，出現第三組時抽成腳本（例如 `tools/ci/run-suites.sh`）。觸發：第三組套件，或一次實際漏檢。
13. （[[CC-655]]：#621 補充的三個問題 A 看不到 INCOMPLETE 原因、B 區域變數被當符號、C CRLF 警告已由 #710、#711 處理；下列 (1) 仍未做。）[[CC-599]] 之後 GitHub issue #621（scope manifest 14 到 17 分鐘）剩下的建議（建議 3「批次搜尋」已由 CC-599 完成）：（1）只展開 diff 實際碰到的 symbol、（2）候選數到達預算就提前停止（CC-599 的 Requirement 寫了「到達 budget 時提前停止」，但交付段沒有提到，視為未交付）、（4）只超出「提示性」預算也讓 gate 在派發前 `INCOMPLETE`（目前仍是，見 `docs/review-model.md`）、（5）supervisor log 顯示各階段耗時。2026-10-11 量測（合成倉庫、工作樹模式）：800 次符號查詢約 33 秒、1600 次約 60 秒，線性成長，所以重跑一次只要約半分鐘而不是 15 分鐘。觸發：真實 diff 的 manifest 階段再次超過約 2 分鐘。

14. GitHub issue #650 的觀察 3：pr-gate 測試日誌每個案例有 2 到 5 行 `LF will be replaced by CRLF`（`core.autocrlf=true`），只是雜訊。觸發：有人因此看漏真正的警告。

15. `pmctl context` 的 `sqlite3` 呼叫有一批不設 busy timeout（寫入端與索引的批次寫入已設 5 秒）：讀取（`query`、`pack`、狀態檢查）在 reindex 寫入期間可能回 `database is locked`；更要緊的是 **FTS5 探測**（`CREATE VIRTUAL TABLE IF NOT EXISTS _fts5_probe`，`pmctl-context.sh` 的 `_ctx_fts5_supported`）也沒有：被並行讀取者鎖住時回 rc=5，索引就當作「不支援 FTS5」而**跳過 FTS 重建**，`content_fts` 保留已刪除檔案的舊條目，之後沒有變化的執行也不會重建它，直到下一次變更（[[CC-603]] 的 WAL 壓力測試：4 個並行讀取者、12 次執行中 1 次，WSL）。這是既有的正確性問題，也讓 CC-603 的空間回收在那次沒有效果（舊 FTS 索引的頁還在）。觸發：有人看到 query 回傳已不存在的檔案，或 hook 因此變成空結果；修法是這些呼叫統一加 5 秒 busy timeout（提示 hook 的延遲特性會隨之改變，需評估）。

16. ✅ 已處理（[[CC-645]]，2026-10-12）：[[CC-644]] 時在 main 上就失敗的原生 `test-pmctl-gate` 案例與第 2 份分片的中止點。原生整套 82 個案例全數通過。
17. `jq` 垫片的涵蓋缺口（[[CC-648]] 後）：約 30 個不傳路徑形狀 `--arg` 值的腳本（guard hook、`ops/`、`tools/`、supervisor）仍帶只加 `-b` 的兩行舊垫片，一旦開始傳路徑值就要改成 source 垫片；`env jq`／`xargs jq`／`timeout jq` 繞過函數；環境變數、`/dev/fd/N` 不涵蓋。觸發：這些腳本之一開始傳路徑值，或路徑值在原生出現被改寫的症狀。
18. [[CC-644]] 審查留下的後續：(a) 非磁碟機的絕對檔案運算元（`/tmp/...`，`TMPDIR` 未設時的 `mktemp`）每次 `jq` 呼叫多一次 `cygpath`（實測約 0.15–0.26 s，MSYS 原本在行程內免費轉換）；可行方向是快取 `/tmp` 的原生前綴或讓 hook 設定 `TMPDIR` 為磁碟機路徑。(b) `gate-assurance.sh`、`gate-policy.sh`、`gate-protocol.sh`、`gate-result-verify.sh`、`gate-reviewer-contract.sh`、`pmctl-gate.sh` 內 8 處 `MSYS2_ARG_CONV_EXCL='*' jq` 前綴現在多餘（無檔案運算元，無害），可移除。(c) `pmctl-gate.sh`／`pmctl-dispatch.sh` 把工作目錄用身分形式（`c:/...`）當 `work_dir` 傳遞，與 `docs/architecture/path-forms.md` 的規則不符；operation 記錄的 `working_dir` 也是 `C:/...`。(d) `_portable_long_posix_path` 目前只有安裝清單 key 在用，artifact 寫入端尚未統一經過它。觸發：hook 延遲被注意到、下一次清理 gate 腳本，或有人需要 `work_dir` 的單一寫法時。
19. [[CC-645]] 審查留下的後續：(a) 與 dispatch 對稱的做法是取消方在確認 producer 死亡後補寫已認證的 `cancelled` 哨兵（`docs/executor-contract.md` kill-before-claim），`gate wait` 就不必讀 operation store；目前由 wait 推論。(b) 取消發生在 ready 哨兵出現之前，wait 仍等到逾時回「never reached readiness」(3)。(c) 推論只比 pid + starttime，不比 `boot_id`。(d) `th_wire_path` 是獨立於 `_portable_long_posix_path` 的預言，兩份規則改動時要一起看；`th_secure_state_root` 以 `USERNAME` 授權，`test-state-store.sh` 以 SID，可統一。(e) operation 的 `indeterminate` 取消結果（producer_failures／child_failures 非 0）在 wait 仍顯示「請改用 foreground 重試」，訊息可區分。觸發：處理 gate 取消流程、或 wait 的不確定訊息造成誤判時。
20. [[CC-648]] 在原生實測時發現、與垫片無關的既有問題：(a) ✅ 已處理（[[CC-649]]）：`hosts/codex/bin/uninstall.sh` 不認得安裝時寫入的 Windows 包装形式 `bash '<路徑>'`；(b)(c) ✅ 已處理（[[CC-653]]）：原生 `test-install.sh` 的整份中止、`install-guards-windows-migrates-raw-path-hooks` 與 `uninstall-guards-removes-unlisted-hooks`（後者見 [[CC-652]]）；原生現在能跑完並出摘要。 
22. ✅ 已處理（[[CC-650]]）：[[CC-649]] 審查留下的 (a) claude 卸載不認 Windows 包装形式、(b) 候選清單收斂、(c) PowerShell 彎引號。仍開著：(d) ✅ 部分處理（[[CC-652]]）：claude 卸載現在認得 `C:/…` 混合形式（2026-06-13 之前的原生安裝寫過，原生 `uninstall-guards-removes-unlisted-hooks` 因此恢復通過）；仍開著：codex 一側、8.3 短名寫法的 claude hook、輸出仍是誤導的「not wired, nothing to do」；(e) `test-install.sh` 的 `install-guards-windows-migrates-raw-path-hooks` 假設 `printf %q` 的路徑不含空格。
21. [[CC-648]] 審查留下的後續：(a) 把「傳路徑值的腳本必須 source 垫片」做成 lint：預設要求 source，兩行片段只允許出現在一份明列的「會被 install.sh 複製到 repo 外」清單（`ops/usage/log-usage.sh`、`token-usage.sh`、`~/.claude/scripts/lib` 的 bundle，來源是 install.sh 的 `helper_specs`），比「凡有 `--arg` 就要 source」的粗規則不誤傷必須獨立的複本；(b) 8 份 source 區塊是複製貼上，可讓 lint 驗證其與標準文字一致；(c) 庫的規則目前只掃 `runtime/lib/`，`tests/lib/test-suite-runner.sh` 仍帶片段；(d) OpenCode 的 `pm_prepare.ts` 在原生 Windows 由 `Bun.spawn` 直接執行無副檔名的 bash 腳本；以 Node 近似實測，無論 `C:/…` 或 `/c/…` 都是 ENOENT（`.exe` 則 `C:/…` 可、`/c/…` 不可），經 `bash` 包裝兩種寫法都可。若日後支援原生 OpenCode，需要 `bash` 包裝或可執行的包裝檔並明確給原生路徑，`pm.md` 給模型的指令形式也隨之改變。觸發：有人開始支援原生 OpenCode，或又有腳本在傳路徑值時帶回兩行片段。
23. ✅ 已處理（[[CC-651]]）：CC-650 驗證時發現的原生 `test-portable` `portable-legacy-directory-receipt-migration` 失敗；根因是 CC-642 之前記下的收據項目升級後對不上查詢鍵。
24. [[CC-651]] 審查留下，CC-652 查證：收據的 `src` 以呼叫端的寫法原樣記下（`realpath_m` 在 MSYS 不做長名轉換，實測 `/tmp/x` 與 `/c/Users/LIENCH~1/…` 都原樣返回），符號連結目標也是用同一個字串建立的，所以同一次安裝內不會對不上；要對不上需要兩次安裝用不同寫法稱呼同一個 checkout，那不是 CC-642 造成的新問題。本機沒有原生符號連結，無法重現「讀回的連結目標寫法不同」，所以沒有改；若之後在有符號連結的原生環境看到 `prev_src` 比對失敗，再以 `_portable_long_posix_path` 正規化兩邊。
25. CC-652 發現：對 2026-06-13 之前寫下 `C:/…` 形式的 `settings.json` 重新執行 `install-guards.sh`，不會產生重複項，但舊的 `C:/…/save-rate-limits.sh` statusLine 與舊路徑的 hook 原樣留著（沒有改寫成 `bash '/c/…'` 形式，也沒有被視為要取代的舊項）；舊 hook 路徑本來就已因為 CC-489 的搬家失效，statusLine 則維持以前的行為。是否讓安裝遷移這些項目待評估（先看有沒有人真的還有這種設定）。
26. [[CC-653]] 風險審查留下，實測確認：搬移或改名 checkout 後重新執行 `install-guards.sh`，Stop hook（`log-usage.sh`）與 statusLine 不會被取代——舊的 Stop hook 留著且多出一份，舊 statusLine 原樣不動，Windows 與 Linux 相同（兩者用精確字串比對，不像 `managed_shared` 那樣看路徑形狀）。結果是舊路徑的 Stop hook 在每次 Stop 失敗。要不要讓它們也用路徑形狀比對，需要先決定「兩份 checkout 並存時誰勝出」（`managed_shared` 的行為是最後一次安裝的 checkout 勝出）。
27. [[CC-653]] 審查留下的低風險項：(a) doctor 的 `normalize_path`（含新的 `unwrap_bash`）對極長的引號串或反斜線串是二次方時間（2 萬個引號約 5 秒；既有的反斜線處理本來就一樣），需要能寫使用者自己的 `settings.json`／`hooks.json`，而那本來就能執行任意 hook；可在拆包裝前限制命令長度。(b) `install-guards.sh` 的淘汰 hook 清理（`hook-tool-trace.sh`、`retired_context_hook`、`retired_session_hook`）沒有拆包裝；實際上不會發生，因為包裝形式出現（v0.10.0）時那些 hook 早已淘汰。(c) 原生 Windows 上 `installed-copy-gate-reader-layout` 在 `-ef` 防護處 skip，等於失去「已安裝的 pr-gate 經過 manifest 入口」那一段的原生覆蓋；要恢復需要不經過 checkout 內 junction 的入口（環境變數覆寫或 checkout 之外的複本）。skip 發生在約 4 分鐘的安裝與 `--print-cmd` 之後，是刻意的：前面的函式庫複本斷言仍會真的失敗，提前 skip 會連它們也丟掉。(d) `portable_bash_wrapped_command` 的第二參數形式 `& '<bash.exe>' '<path>'` 兩個拆包裝實作都不認；只有 `pr-gate.sh` 用，不會出現在設定檔 hook。
28. [[CC-661]] 驗證時在原生 Windows 量到、與該票無關的三個既有失敗（main 上同樣；WSL 上都通過）：`test-lint-model-aliases.sh`（1 通過、12 失敗，各案例的 lint 都回報預期的錯誤訊息，但案例本身判定為失敗，原因未查）、`test-opencode-dispatch.sh`（第 18 個案例之後整個套件無摘要結束，exit 1，疑似 `set -e` 與 `pipefail` 的同類問題）、`test-pmctl-dispatch.sh`（state root 的 ACL 檢查，已知）。需要在原生 Windows 驗證這幾個套件時，改用 `ops/diagnostics/run-tests-in-wsl.sh`。

**Done-when**：沒有。每項由自己的觸發條件決定；觸發時開獨立票或隨該次變更處理。

**See**: [[CC-641]]、[[CC-642]]。

---


## CC-662 — repo index 的更新可以續做 🟢 someday

**Problem**：見索引列。

**Requirement**：先決定形狀再動手。選項：(a) 變更檔分成固定大小的區塊，每塊各自 COMMIT，被砍掉時已完成的區塊保留，下次從差異繼續（新鮮度標記與已刪除檔案的對帳只在最後一塊寫入，部分完成的索引不得標成 fresh）；(b) 把可選的更新移到背景，不阻塞 gate，下一次才用得到。兩者都要在一個至少數千個檔案的 repo 上量測前後時間；索引的交易語意有 #632、#634 的前因，不要在沒有量測的情況下改。CC-660 已讓逾時訊息說明如何一次性調高上限，這是在此之前的緩解。

**Done-when**：在大型 repo 上連續兩次 `pmctl gate run`，第二次的更新在上限內完成，且被砍掉的更新不會留下標成 fresh 的部分索引。

**See**: [[CC-660]]；[[CC-599]]。

---

## CC-663 — `pmctl worktree create` 可指定 checkout 位置，原生 Windows 路徑過長時警告 ✅ 2026-10-23

**Resolution 2026-10-23**：#721（issue #720）。`create` 新增 `--path <dir>`（checkout 的確切位置）與環境變數 `PMCTL_WORKTREE_ROOT`（每個 checkout 放在 `<dir>/<slug>`）；相對路徑以 exit 2 拒絕；路徑以 wire 形式（`_portable_normalize_path` 加 `_portable_long_posix_path`）寫入 manifest，所以 `list`、`remove`、`gc` 不用改。Windows 上預設路徑加 slug 超過 80 個字元（260 減去典型的 180 字元 `node_modules` 深度）時，`create` 在 stderr 警告，門檻可用 `PMCTL_WORKTREE_LONG_PATH_WARN` 調整；判斷放在 `_pmctl_worktree_warn_if_long_path`，以 `detect_platform` 為準。驗證：WSL 內 `test-pmctl-worktree.sh` 47 項通過，兩個變異（`-gt` 改 `-ge`、拿掉平台判斷）都會讓新案例失敗；原生 Windows 沒有驗證（state root 的 ACL 檢查擋住這個套件）。pr-gate 三輪：前兩輪 qa-tester 擋（警告沒測試、create 結果沒檢查；沒有 cygpath 的測試案例依主機而定），第三輪 `Final: GO`。

**Non-goals**：issue #720 建議 2（原生 Windows 預設改用更短的位置，例如以短雜湊取代 40 位元的分區鍵）沒做，會改變 checkout 的既有位置與分區鍵的使用方式（見 #595）；根目錄沒有做成 `pmctl config` 的設定鍵，現在只有環境變數與選項。

**See**: [[CC-643]]。

---

## CC-664 — targeted 輪次以 NO-GO 結束時，remediation closure 發布失敗 ✅ 2026-10-23

**Resolution 2026-10-23**：#722。根因：`gate_remediation_closure_publish` 把 synthesis 的所有 `remediation_confirmations` id 原樣寫進 `targeted_confirmation.finding_ids`，但最後是 NO-GO 時所有 diff-caused finding 都被分類成 `stop_split`；`gate_remediation_closure_verify` 要求「沒有任何 finding 分類為 `targeted_confirmation` 時，id 清單必須是空的」，所以 producer 產出的檔案過不了自己的驗證，發布時以 `Error: unable to publish remediation closure evidence` 結束，`gate wait` 顯示 `failed exit: 2`（結果檔本身有效）。修法：`finding_ids` 由實際被分類為 `targeted_confirmation` 的 finding 推導（排序），producer 與 verifier 兩邊的條件因此一致。新測試 `case_gate_remediation_closure_publish_targeted_no_go_names_only_classified_confirmations` 在修復前重現原錯誤。驗證：WSL 內 `test-core-schemas.sh` 163 項、`test-pmctl-gate.sh` 82 項（2 項略過）、`test-pmctl-ship-finish.sh` 82 項通過。

**Non-goals**：`gate wait` 在這種失敗時仍只顯示 `failed exit: 2` 與 supervisor 日誌路徑，result 已寫出時的 NO-GO 不會在 wait 輸出裡標明；未改動。

**See**: [[CC-655]]；[[CC-663]]。

---

## CC-665 — gate 記錄 scope manifest 階段耗時，平台文件記錄原生 Windows 的實測 ✅ 2026-10-23

**Resolution 2026-10-23**：#723。supervisor 日誌新增 `pr-gate: scope manifest built in <N>s (changed paths=<M>)`（計時涵蓋變更集合、manifest 寫入，不含之後的 digest 與 jq 讀取）；既有的 `test_scope_manifest_complete_and_shared_across_parallel_dispatch` 加一個斷言（變異檢查會失敗）。`docs/platform-support.md` 記錄 2026-10-23 的原生 Windows full tier GO（一次執行）與下列重新量測。

**重新量測 #621（原生 Windows，main `3de39a2`，固定 head，每個情境各跑一次，只計時 `_gate_scope_changes_collect` 加 `_gate_scope_expansions_collect`）**：合成 TS repo（640 個追蹤檔，50 個 `lib/` 檔各 16 個函式）66 s；本 repo 40 個變更檔 38 s、179 個變更檔 162 s。展開只對 `lib/`、`shared/` 與 shell 檔進行，約每個這類變更檔 1 到 1.3 秒。沒有量過 #621 當時的版本，所以「比 14–17 分鐘快」是與 issue 數字的比較，不是前後對照。

**Non-goals**（#621 其餘建議，刻意不做）：預算滿了提早停止（改變保留哪 512 筆與省略數量）；只展開 diff 觸及的符號（改變 reviewer 看到的內容）；提示性截斷不再 `INCOMPLETE`（`docs/review-model.md` 的政策）。

**See**: [[CC-655]]；[[CC-664]]。

---

## CC-666 — ship 與前景 gate run 區分「審查沒過」與「工具失敗」 🟢 someday

**Problem**：見索引列。

**Requirement**：先查證 `pmctl ship finish` 與前景 `pmctl gate run` 在 gate 結束碼為 1（NO-GO）與 2（failed）時各印什麼；若沒有可分辨的標示，沿用 CC-620 的措辭（`failed is an execution error, not a review verdict`）與 sentinel `failure_reason`。

**Done-when**：兩個入口在 NO-GO 與 failed 時輸出不同且明確的句子，有測試。

**See**: [[CC-620]]；[[CC-664]]。

---

## CC-667 — 外部 repo 第一次 gate run 前補齊 pm-dispatch 的忽略清單 ✅ 2026-10-24

**Problem**：2026-10-24 在 `t3-oss/create-t3-turbo` 的 live dogfood（[[CC-447]]）中，第一輪 `gate run` 先在目標 worktree 建了 `.pm-dispatch/ctx/context.db`，接著因 `working tree is dirty while the branch has committed changes against main` 失敗。`ops/setup/setup-project.sh` 的忽略清單（`.agent-trace/`、`.gate-briefs/`、`.gate-results/`、`.agents/`、`.pm-dispatch-state/`）沒有 `.pm-dispatch/`，也沒有 `.dispatch-results/`；README 沒有把 `setup-project.sh` 列為上手步驟。`pmctl ship finish` 另有 `_pmctl_ship_ensure_gitignore` 與 `_PMCTL_SHIP_BOOKKEEPING_PATTERNS`（`runtime/lib/pmctl-ship.sh`），只在 ship 時補。

**Requirement**：先決定誰負責：`gate run` 在第一次寫入前補忽略（寫 `.git/info/exclude` 不動被追蹤的檔案，或沿用 ship 的 `.gitignore` 補丁），或文件把 `setup-project.sh` 列入上手。三份清單（setup-project、ship、doctor 若有）收斂為同一個來源。

**Done-when**：外部 repo 的第一次 `pmctl gate run` 不因 pm-dispatch 自己的目錄失敗；有測試；清單只有一個來源。

**Resolution 2026-10-24**：#729。選了「閘門自己不把這些目錄當變更」而不是「補 `.gitignore`」：`runtime/lib/artifact-paths.sh` 新增 `PM_OWN_OUTPUT_LEAVES`（`.agent-trace .gate-briefs .gate-results .dispatch-results .pm-dispatch/ctx .pm-dispatch-state`），髒樹前檢、完整性指紋與 scope 列表都問它。`PM_ARTIFACT_LEAVES` 不動，因為 `pmctl artifacts gc --all-repos` 會刪、`migrate` 會複製那份清單，context index 不能在裡面（有測試釘住）。`setup-project.sh` 補上 `.pm-dispatch/ctx/` 與 `.dispatch-results/`。只排除 `ctx/` 而不是整個 `.pm-dispatch/`，是因為用戶自己的 `config`、`pre-gate.sh`、`post-gate.sh` 也在那裡：第一版把整個目錄排除，被既有的 `post-gate-hook-skipped-on-no-go` 測試在 CI 抓到，而且那會讓 reviewer 寫進去的 `post-gate.sh`（`--allow-hooks` 會執行它）躲過完整性檢查；pr-gate 的兩位 reviewer 當時給的是 advise，沒有指出這點。縮窄之後第二輪 full-tier gate 給了 NO-GO（qa-tester 的 hard_block，critic 的 advise 指向同一處）：完整性指紋用的預設 `git status` 會把只含未跟蹤檔案的目錄折成一條 `?? .pm-dispatch/`，路徑過濾看不進去，審查期間 `ctx/` 出現或消失就又是誤報。改成 `artifact_status_porcelain`（用同一份 pathspec 排除再過濾），`pr-gate.sh` 的三個快照都走它，有測試釘住並做過變異檢查。清單只有一個來源：ship 的 `_PMCTL_SHIP_BOOKKEEPING_PATTERNS` 與 `setup-project.sh` 的 `ENTRIES` 都改成從 `PM_OWN_OUTPUT_LEAVES` 派生（ship 取每一項的頂層目錄，所以仍寫 `.pm-dispatch`，與 context indexer 一致；setup 另外保留 Codex 側的 `.agents/`），新增一個目錄只改一處，有測試和變異檢查。還沒收斂的是 context indexer 的 `_ctx_ensure_gitignore`，它直接寫 `.pm-dispatch`，其測試把整個目錄當作要忽略的對象，沒有動。README 仍未把 `setup-project.sh` 列為上手步驟，閘門已不需要它。

**See**: [[CC-668]]；[[CC-447]]；`docs/notes/live-dogfood-2026-10-24-create-t3-turbo.md`。

---

## CC-668 — 審查期間 pm-dispatch 自己的產物不應觸發 prompt injection 誤報 🟢 someday

**Problem**：同一次 dogfood 的第二輪：`reviewer sessions modified working tree -- possible prompt injection`（`runtime/bin/pr-gate.sh:3727`，合成階段另有 `:4016`）。實際變動是 reviewer 派發紀錄寫進 `.dispatch-results/`（`runtime/lib/dispatch-record.sh`）。審查沒有失敗，工具也沒有壞，是一個把自己的產物當篡改的檢查；訊息指控的卻是注入攻擊。

**Requirement**：檢查排除 pm-dispatch 自己的 bookkeeping 路徑（與 [[CC-667]] 共用清單），並在訊息列出實際變動的路徑；真的有外部變動時才用現在的措辭。

**Done-when**：只有 `.dispatch-results/` 變動時 gate 不失敗；變動其他路徑時訊息列出路徑；有測試。

**Progress（2026-10-24，pr:#729）**：第一半由 [[CC-667]] 的同一個改動解掉：完整性指紋用的 `artifact_filter_porcelain` 現在把 `.dispatch-results/`、`.pm-dispatch/ctx/`、`.pm-dispatch-state/` 當成自己的輸出，單元測試覆蓋過濾，沒有另外寫「審查期間 reviewer 寫入 `.dispatch-results/`」的整段 gate 測試。第二半未做：真的有外部變動時，訊息仍不列出變動的路徑。票維持 someday，只剩這一項。

**See**：[[CC-667]]；[[CC-620]]。

---

## CC-669 — reviewer 結果的閉合欄位比較要容忍 CRLF，且 truncated 的判定不能對完整結果成立 ✅ 2026-10-25

**Problem**：`runtime/lib/gate-result-verify.sh` 約 699 行起逐行解析，以 `[[ "$line" == '```' ]]` 找閉合欄位。原生 Windows 上 reviewer 寫出 `` ```
 ``，閉合不成立，函式以「truncated reviewer result」結束；自動重試同樣失敗，整個 gate `failed`（exit 2）。同一主體下一輪沒有出現，所以是間歇性。architecture-reviewer 其實已 `approve`、risk-reviewer 為 `advise`，結論沒有被採信。

**Requirement**：逐行讀取時去掉行尾 `\r`（或在擷取前正規化 reviewer 輸出）；「truncated」只在真的沒有閉合時成立。其他消費同一份 reviewer 檔的地方一併檢查。

**Done-when**：含 CRLF 的完整 reviewer 結果通過協定檢查；真正未閉合的結果仍被拒；有兩種輸入的測試。

**Resolution 2026-10-25**：#731。新增共用的 `gate_file_normalise_eol`（`gate-result-verify.sh`，去掉每行行尾的 CR，改過檔案時設 `GATE_EOL_NORMALISED`），在模型寫的檔案進入 gate 的三個入口各呼叫一次：reviewer 檔的快照驗證（`gate_reviewer_protocol_verify_snapshot`，驗證前對暫存副本做，取代原檔的就是正規化後的那份，所以附進結果的證據不帶 CR）、sequential 與 synthesis 共用的 `gate_result_staging_normalize`（frontmatter 的 `---` 比對原本也會被 CR 擋住，和 CC-618 的 BOM 同類，會印一行 Note）。直接讀檔的地方也容忍 CR：`gate_reviewer_protocol_verify` 的逐行迴圈、`_gate_reviewer_protocol_documents`、`_gate_reviewer_replace_json_block` 和 `gate_result_findings_by_severity` 的 awk，所以 CRLF 的已發布結果在 `gate verify` 與統計讀者看來和 LF 一樣。真的沒有閉合圍欄的結果仍以 `truncated reviewer result` 拒絕（有測試）。範圍比票上寫的大，是因為精確比對圍欄的地方至少五處，只修一處會讓 CRLF 流進後面再壞。四個變異檢查（拿掉迴圈去 CR、拿掉快照正規化、拿掉 staging 正規化、拿掉抽取器與替換器的 CR 容忍）各自讓對應案例失敗。第一版 gate 的 NO-GO 是 QA 在原生 Windows 上跑新測試抓到的：`grep -q $'\r'` 在原生 Git Bash 以文字模式讀檔，看不到 CR，所以「有 CR 才改寫」的守衛永遠不成立、正規化從未執行，WSL 上卻看得到所以本機沒發現。現在不做預檢，永遠跑 awk 再用 `cmp` 判斷是否改變；測試裡偵測 CR 一律用 `tr -cd`，不用 grep。另外原生 gawk 讀檔時本來就吃掉 CR，所以 awk 這幾處的 CR 容忍只對 Linux/WSL/macOS 有作用，對應的變異檢查要在 WSL 上做。sequential 路線在 staging 正規化之前已被快照驗證轉成 LF，所以 staging 的 Note 只在 synthesis 路線出現。**沒做**：`pmctl-gate-stats.sh` 的 jq 仍精確比對圍欄，CRLF 的已發布結果在統計裡會顯示 `unavailable`（安全降級）；圍欄後面多空白、縮排的圍欄或更長的圍欄仍會被說成 `truncated`，訊息不精確。

**See**: [[CC-620]]（failed 與 NO-GO 的區分）; `docs/notes/live-dogfood-2026-10-24-create-t3-turbo.md` 第 5 輪.

---

## CC-670 — worktree remove 遇到超長路徑要說原因，且不留半刪目錄 ✅ 2026-10-25

**Problem**：`runtime/lib/pmctl-worktree.sh:471` 在 `git worktree remove` 失敗時一律印 `(dirty? pass --force to override)`。2026-10-24 在 `C:\dogfood\w1`（路徑本身很短）移除裝過 pnpm 依賴的 worktree，git 回 `failed to delete ... Filename too long`，實際 worktree 已被解除註冊，目錄留下一半。`--force` 不會解決，手動以 `\\?\` 前綴刪除用了 44 秒。

**Requirement**：失敗時轉述 git 的實際錯誤；遇到路徑過長時在原生 Windows 改走長路徑刪除，或明確說出手動做法；不在 worktree 已解除註冊後仍回報成可重試。

**Done-when**：超長路徑的 worktree 能被移除或得到可行動的指示；有測試（可用模擬的 git 錯誤）。

**Resolution 2026-10-25**：#733。先重現：git 2.42 for Windows 上，對路徑超過 260 字元的 worktree 執行 `git worktree remove`，印 `failed to delete ... Filename too long`、**已取消註冊**但目錄留了一半（和 dogfood 完全一致）；同一個命令加 `-c core.longpaths=true` 就刪得掉。所以根本修法是新增 `_pmctl_worktree_git`（`git -C <dir> -c core.longpaths=true ...`，其他平台忽略這個設定），`worktree create`、`remove`、`gc` 的 git 呼叫都經過它，而不是另寫一套長路徑刪除。`remove` 失敗時轉述 git 自己的錯誤；只有 git 說是髒工作樹時才給 `--force` 提示；若 git 已不再追蹤該 worktree 而目錄還在（用既有的 `_pmctl_worktree_is_tracked` 判斷，它也處理 8.3 短檔名、junction 與磁碟機代號大小寫），訊息明說這個狀態（重試與 `--force` 都沒用）、請操作員確認內容後自行刪除，manifest 條目保留，之後 `pmctl worktree gc` 會收掉它。`gc` 同樣誠實：git 不再追蹤的 checkout 仍照既有合約收掉 manifest 條目，但目錄還在時不再印單純的 `removed`，而是說「已從 manifest 移除，目錄仍在」；會動到進行中 worktree 的那一支，失敗時也轉述 git 的錯誤，不再一律說「有未提交的變更」。**刻意不由 pmctl 自己刪那個殘留目錄**：同樣的狀態也會出現在 worktree 的管理目錄被 prune、目錄裡還有未提交工作的時候，自動 `rm -rf` 會丟資料。測試：深路徑移除、git 失敗時的原因與兩種狀態（仍註冊／已取消註冊）、髒工作樹的提示（併入既有案例）、gc 對殘留目錄的訊息（併入既有案例）、argv 案例多釘 `core.longpaths`；四個變異檢查各自失敗（含 gc 對「非髒工作樹失敗」的訊息）。完整 gate 的第一次 NO-GO 是兩個測試缺口：深路徑案例的 `mkdir -p ... && printf` 失敗會被吞掉而讓測試在沒測到超長路徑時通過（現在建不出超過 260 字元的檔案就是失敗），以及 gc 新的非髒失敗分支沒有直接測試（現在有）。第二次 NO-GO 抓到真正的缺陷：gc 的單行訊息已誠實，結尾摘要卻仍把非髒的失敗算進 `skipped N dirty worktree(s)`，現在另計並寫成 `could not remove N worktree(s)`，測試改為捕獲結束碼並斷言整段輸出都不含 dirty。同一次 NO-GO 的 hard block 是 QA 的沙箱跑不了這個測試檔（原生 Windows 的狀態根目錄權限拒絕），拿不到執行證據；這個測試檔在這台機器只能在 WSL 跑，所以 gate 要用 `--test-cmd 'bash ops/diagnostics/run-tests-in-wsl.sh test-pmctl-worktree'` 讓 gate 在派發前自己執行它。審查代理的兩個真實發現已處理：失敗提示原本自己寫的註冊判斷比 `_pmctl_worktree_is_tracked` 弱，在短檔名路徑上會誤報；我原本寫的「gc 在目錄刪掉後才清 manifest」不是事實，且第一版 gc 改成保留條目違反既有測試寫明的合約，已改回。**限制**：這台機器的原生環境跑不了 `test-pmctl-worktree`（`worktree create` 在此失敗，已知的狀態根目錄權限問題），深路徑案例在 Linux 上只是順利通過，回歸價值要在能跑這個測試檔的 Windows 環境才有；原生的證據是上面的 git 直接重現。已經被舊版弄成半刪狀態的 worktree 不會自動修復，按新訊息的指示手動處理。`worktree add` 也帶了 `core.longpaths`，但沒有重現過它在深路徑上失敗，是為了一致性而不是已證實的修正。

**See**: [[CC-663]] (`--path`); #720.

---

## CC-671 — gate verify 與政策下限拒絕的訊息要說該怎麼做 ✅ 2026-10-25

**Problem**：兩處，同一次 dogfood：(a) `pmctl gate verify gate-...`（傳 gate id）只印 awk 的 `cannot open file '<cwd>/gate-...' for reading`，命令其實要結果檔路徑；(b) targeted 輪次只要求 `qa-tester`，拒絕訊息是 `coverage: requested=explicit required=["architecture-reviewer","risk-reviewer"]`，沒有說 `qa-tester` 也要保留，操作員得猜。

**Requirement**：(a) 引數不是檔案時說明用法並提示結果檔位置，或接受 gate id；(b) 訊息列出「需要補上」與「需要保留」兩組，或直接給可貼上的 `--reviewers` 值。

**Done-when**：兩種輸入各得到一句可行動的訊息；有測試。

**Resolution 2026-10-25**：#731。(a) `pmctl gate verify` 的引數不是檔案時印出它要的是 `gate wait` 的 `result:` 那一行的路徑；長得像 gate id 時再提示用 `pmctl artifacts show <id>` 找結果檔，退出碼 2，不再是 awk 的 `cannot open file`。沒有改成接受 gate id。(b) 政策下限拒絕時，coverage 違規多印兩行：已選的 reviewer、要補上的 reviewer，以及可貼上的 `--reviewers <已選,補上>`；違規 JSON 的形狀與 schema 不變，只改 `pr-gate.sh` 的輸出。

**See**: [[CC-620]].

---

## CC-672 — 上手第一次體驗：installer 一次報全部衝突，量測並說明 doctor 的耗時 🟢 someday

**Problem**：(a) 舊 symlink 擋住 `install.sh` 時只報第一個衝突（先 `agents`、`adapters`，再 `.pm`，再 `~/.claude/scripts` 下的 `doctor.sh`、`pr-gate.sh` 兩個連結），清完 5 個用了三輪；(b) `doctor.sh` 在這台原生 Windows 機器約 4 分 49 秒（19 OK、3 WARN、0 FAIL），只有一次量測，尚不知道慢在哪一項。

**Requirement**：(a) 在拒絕接線前把所有衝突一次列出；(b) 先量每一項檢查的耗時（`--timings` 或臨時日誌），再決定要不要改，沒有量測前不動。

**Done-when**：(a) 一次輸出全部衝突；(b) 有每項耗時的資料，並依資料決定修或關。

**See**：[[CC-447]]；[[CC-461]]（doctor `--fix`）。

---

## CC-673 — indexer 與 ship 只忽略 `.pm-dispatch/ctx`，不忽略整個目錄 ✅ 2026-10-25

**Problem**：[[CC-667]]（#729）把閘門的自有輸出縮到 `.pm-dispatch/ctx`，理由是 `config`、`pre-gate.sh`、`post-gate.sh` 是用戶的，而 `--allow-hooks` 會執行 `post-gate.sh`。但 `_ctx_ensure_gitignore`（context indexer）與 `_pmctl_ship_ensure_gitignore`（ship）仍把 `.pm-dispatch` 整個寫進 `.gitignore`，所以在被索引過的 repo 裡，那個縮窄對 `git status` 沒有效果：reviewer 寫入的 hook 照樣不可見。

**Requirement**：兩處改成只忽略生成的部分；清單只在 `PM_OWN_OUTPUT_LEAVES` 一處維護。

**Done-when**：索引後 `.pm-dispatch/post-gate.sh` 不被忽略而 `.pm-dispatch/ctx/` 被忽略；舊的 `.pm-dispatch` 規則仍被視為已涵蓋；有測試與變異檢查。

**Resolution 2026-10-25**：#730。`_ctx_ensure_gitignore` 改寫並查詢 `.pm-dispatch/ctx`（`.pm-dispatch`、`.pm-dispatch/`、`.pm-dispatch/ctx[/]` 任一行都算已涵蓋；git 已經忽略時不動 `.gitignore`）。ship 直接逐項寫 `PM_OWN_OUTPUT_LEAVES`（不再有 `_PMCTL_SHIP_BOOKKEEPING_PATTERNS` 這個拷貝，也不再折成頂層目錄）；兩處共用 `artifact-paths.sh` 的 `artifact_gitignore_covers`（父目錄規則算已涵蓋）與 `PM_CTX_LEAF`（indexer 寫入的那一項只在那裡命名一次）；`.pm-dispatch` 單行仍可通過 `_pmctl_ship_gitignore_is_bookkeeping_only`（舊版寫的檔案）。`PM_OWN_OUTPUT_LEAVES` 補上 `.pm-dispatch/test-results`（ship 的整套測試紀錄，原本被整個目錄的規則涵蓋）。行為變化：已被舊版 indexer 寫過 `.pm-dispatch` 的 repo 不受影響（舊行仍有效）；新 repo 的 `.pm-dispatch/config` 與 hook 會顯示為未跟蹤，這是目的。 **沒做**：已經被舊版寫了整行 `.pm-dispatch` 的 repo 不會被遷移，那些 repo 裡 hook 仍不可見；由 [[CC-674]] 處理（改成讓完整性檢查直接讀 hook 檔案）。本倉庫自己的 `.gitignore` 也留著整行 `.pm-dispatch/`，因為它註明可把 `PM_DISPATCH_STATE_ROOT` 設成 `.pm-dispatch`，那時整個目錄都是狀態。

**See**: [[CC-667]]; [[CC-668]].

---

## CC-674 — 完整性檢查直接讀 `--allow-hooks` 會執行的檔案 ✅ 2026-10-25

**Problem**：[[CC-673]]（#730）讓新設定的 repo 只忽略 `.pm-dispatch/ctx`，但已經有整行 `.pm-dispatch` 的 repo（舊版 `pmctl ship finish` 與 context indexer 都寫過，後者對每個被索引的 repo 都寫）裡，`git status` 看不到 `.pm-dispatch/post-gate.sh`。審查期間 reviewer 寫入這個檔案時，三個完整性指紋不變，gate 照常往下走，`--allow-hooks` 再以操作員的權限執行它。端到端案例證實：拿掉修正後，reviewer 寫的 hook 完全沒被發現。

**Requirement**：不依賴使用者的 `.gitignore`。完整性檢查要直接納入 gate 會執行的 hook 檔案。

**Done-when**：在整行忽略 `.pm-dispatch` 的 repo 裡，審查期間新增或修改 `pre-gate.sh` / `post-gate.sh` 會讓 gate 以 prompt injection 中止；有單元與端到端測試和變異檢查。

**Resolution 2026-10-25**：#732。`runtime/lib/artifact-paths.sh` 新增 `PM_HOOK_FILES`、`artifact_hook_state`（每個 hook 的內容、symlink 目標或 `absent`）與 `artifact_integrity_snapshot`（過濾後的 `git status` 加上 hook 狀態）；`pr-gate.sh` 的三個指紋（派發前、派發後、synthesis 後）都改走它。不遷移也不改使用者的 `.gitignore`，既有 repo 立即受保護。原本想在 `pmctl doctor` 加警告，但 doctor 的 `REPO_ROOT` 是 pm-dispatch 的 checkout，看不到目標 repo，所以放棄；也不自動改使用者的 `.gitignore`。端到端案例沿用既有的 `CODEX_GATE_STUB_INJECT_FILE`（補上 `mkdir -p`），hook 與一般檔案兩輪，後者是對照組。hook 路徑在 `artifact-paths.sh` 只命名一次（`PM_PRE_GATE_HOOK`、`PM_POST_GATE_HOOK`），`pr-gate.sh` 執行 hook 與完整性檢查都讀同一組；讀不到的 hook 讓快照失敗（pipefail 使 gate 中止），不是被略過。同類的其他缺口另開 [[CC-676]]。 第一版完整 gate 的 NO-GO（四位 reviewer 指向同一處）抓到我造成的回歸：把 `git status | filter` 包進 `artifact_integrity_snapshot` 後，函式的結束狀態變成後面 hook 迴圈的狀態，`git status` 失敗被吞掉，gate 會拿不完整的指紋繼續，既有的三個 `injection-check-git-failure-*` 案例因此失敗，我當時沒跑它們。修正用 `PIPESTATUS` 明確回傳前段 pipeline 的失敗，不依賴呼叫端的 pipefail，並加了不開 pipefail 的負面測試與變異檢查。 第二輪 gate 的 GO 帶一個中度、既有的建議（critic）：`chmod +x` 一個已存在、原本不可執行的被忽略 hook，內容與 git 狀態都不變，`--allow-hooks` 卻從略過變成執行；現在快照也納入可執行狀態（用 `pr-gate.sh` 判斷是否執行的同一個 `-x`）。原生 Git Bash 的 `-x` 對 `#!` 開頭的檔案永遠為真、不看權限，所以那裡權限位元本來就影響不了執行，測試只在 `chmod 644` 真的讓 `-x` 變假的平台上斷言；變異檢查在 WSL 上做。變異檢查：把 hook 狀態從快照拿掉，端到端案例的 hook 那一輪失敗。沒做：`.pm-dispatch/config` 沒納入（它不被執行，且 gate 外的工具可能合法改它）。

**See**: [[CC-673]]; [[CC-667]].

---

## CC-675 — 一個 gate 要 16 到 21 分鐘，操作員要等 2 到 3 輪，時間花在哪沒有資料 ✅ 2026-10-25

**Problem**：2026-10-25 在 #730、#731 期間跑了四個完整 gate（codex 執行器、full tier、6 位 reviewer 與 synthesis）。從 gate id 的時間到結果檔的修改時間：16.2、17.2、16.1、20.8 分鐘。這個環境一次 `gate wait` 最多 540 秒（超過會被自動丟到背景），所以每個 gate 都要等兩輪以上，第一輪一定以 `timed out after 540s` 結束，輸出看起來像失敗，其實 gate 還在跑。時間用在哪沒有拆解（reviewer 派發、QA 跑測試、synthesis、驗證）。

**Evidence boundary**：只量了這四個 gate，同一台機器、同一個執行器。結果檔出現之後 `gate wait` 回報得多快沒有精確量過；在查過的一次（`gate-20261025-015939-731bd5`，結果檔 11:20:29），一個短的 wait 馬上回了 GO，沒有證據顯示回報有延遲。我先前在 PR #731 的說明裡說「wait 端有延遲、結果早就產生」，這個說法沒有證據支持，在此撤回。

**Requirement**：(a) 先量：用 supervisor 紀錄與事件檔拆出各階段耗時，記在票裡；(b) 依資料決定：若時間主要在 reviewer，評估能否縮小（reviewer 數、tier）；若在等待編排，評估 `gate wait` 在逾時訊息裡明說「gate 仍在跑，正常」並建議下一步，或提供可持續等待的寫法（例如文件化以 Monitor 輪詢結果檔），而不是讓操作員猜。

**Done-when**：有各階段耗時的資料；操作員等一個 gate 需要的呼叫次數與逾時訊息的語意被決定並記錄（修或關）。

**Resolution 2026-10-25**：#734。量了 2026-10-25 的 11 個完整 gate（codex 執行器、full tier、5 位 reviewer 加 synthesis），方法是 gate id、scope manifest、各 reviewer 的 `.agent-trace/gate-*.log`、reviewer 結果檔、`gate-protocol-attempts-*.jsonl` 與結果檔的修改時間（本機時區，gate id 是 UTC，差 9 小時）。

| 階段 | 範圍 | 中位數 |
|---|---|---|
| 總時間 | gate id 到 supervisor 結束 | 1060 秒（903 到 1341） |
| 前置 | 啟動、context 更新、policy、scope manifest | 157 秒（128 到 179） |
| reviewer | manifest 到所有 reviewer 結果就緒 | 607 秒（441 到 806，後者含一次 reviewer 重試） |
| synthesis 與發布 | 所有 reviewer 就緒到結果檔 | 281 秒（254 到 555，後者含一次 synthesis 重試） |
| 收尾 | 結果檔到 supervisor 結束 | 29 到 36 秒 |

各階段的中位數加起來不會剛好等於總時間的中位數（約 1077 對 1060 秒），中位數本來就不可加。

三個結論。(1) reviewer 階段約佔 57%，而且每個 gate 的第一次嘗試中最後完成的都是 qa-tester（比第二慢的晚 23 到 256 秒，中位數 176 秒），開 [[CC-677]]。(2) synthesis 有一次因驗證器拒絕單一 finding 的 disagreement 而整個重跑，多約 164 到 274 秒（555 秒對其餘 10 個 gate 的最大值 391 秒與中位數 281 秒），開 [[CC-678]]。(3) `gate wait` 在這個環境單次呼叫要在 540 秒內回來（超過會被丟到背景，這是 harness 的限制，不是 pmctl 的預設，預設是 1200 秒），而 gate 最短的一次是 903 秒，所以以 540 秒輪詢時每個 gate 至少要等兩輪，第一輪必定以逾時結束；先前我在 #731 的說明裡說「wait 端有延遲、結果早就產生」沒有證據，在查過的一次中結果檔出現後 wait 馬上回報，這個說法已撤回（見票內 Evidence boundary）。

決定：`gate wait` 沒有缺陷，不改行為；逾時訊息原本寫「timed out」，讀起來像失敗，改成「gave up waiting ... this is not a verdict」，並說「gate 可能仍在背景執行、一次 wait 常常不夠、再執行同一個指令」（退出碼 124 不變）。只說「可能」是刻意的：這條訊息也會在 supervisor 已死、operation 還在 `cancelling` 的狀態印出，那時 gate 並不在跑；審查代理指出我第一版寫成「仍在執行」是過度宣稱。同一個審查也抓到我漏改的地方：`tests/shell/test-gate-lifecycle.sh` 有一個斷言 `timed out`（我先前只搜 `timed out after`，漏了不帶 `after` 的），以及 `commands/pr-gate.md` 叫代理「重試一次再當作卡住」，和量到的 gate 時間衝突，現改為「一直重跑同一個 wait，直到有 verdict 或 exit 3，不要把 124 當卡住」。`dispatch wait` 的訊息沒有動，兩者措辭現在不同，沒有共用 helper（各只有一個 printf，gate 這邊還有額外的存活判斷）。逾時後的等待次數沒有被降低：那由 gate 本身的時間決定（[[CC-677]]、[[CC-678]]）。**限制**：n=11、同一台機器與執行器；票上原本寫的「16 到 21 分鐘」來自當時的 4 個 gate，現在樣本是 11 個（15 到 22 分鐘）；QA 內部的耗時沒有拆開；結果檔出現後 wait 回報的延遲只精確查過一次。**沒做的候選**（讓等待更便宜，不改 gate 本身的時間）：`gate wait` 印經過時間與近期 gate 的耗時中位數、`gate wait` 在總預算內自動續等、把以 Monitor 輪詢結果檔的做法寫進指引；這是我在 Resolution 裡漏掉的 Requirement (b)，改開 [[CC-682]]。最後一輪 gate 還顯示了一個和耗時無關的現象：reviewer 重試恢復後 GO，operation 卻是 `failed`，開 [[CC-683]]。同一輪還開了 [[CC-679]]（本機一個指令跑 CI 的 lint 集合）、[[CC-680]]（只能在 WSL 跑的測試檔給 QA 的執行證據）、[[CC-681]]（CC-669 留下的兩個小缺口），它們是這一輪發現、但不屬於耗時的後續。

**See**: [[CC-620]]（failed 與 NO-GO 的區分）; [[CC-666]]; `docs/review-model.md`.

---

## CC-676 — 完整性檢查只看得到 git 報告的內容，被忽略的檔案看不見 🟢 someday

**Problem**：prompt injection 檢查的三個指紋（`pr-gate.sh`）用 `git diff HEAD` 加上 `git status`（排除 pm-dispatch 自己的輸出）。被 `.gitignore`、`.git/info/exclude` 或全域忽略規則涵蓋的檔案，審查期間被 reviewer 改了也不會讓指紋變動。[[CC-674]] 只補了 `--allow-hooks` 會執行的兩個 hook 檔；同一類的缺口還有：已核對屬實的是 `.gate-overrides.md`（`pr-gate.sh` 在 `--override-file` 未指定時自動找，內容注入每個 reviewer 的 brief，可抑制「已接受風險」的 finding；本輪載入發生在派發前，所以 reviewer 在審查期間改它只會影響下一輪）。審查代理另外提到 `--test-cmd` 會執行的被忽略檔案、`.git/hooks` 與 `.git/config`，這些**我沒有核對**，要在這張票裡先查證。

**Requirement**：先列出 gate 或 ship 會信任或執行、且位於工作樹或 `.git` 內的檔案清單（附程式碼出處），逐項判斷 reviewer 沙箱是否寫得到；寫得到的，納入 `artifact_integrity_snapshot` 的明列清單。不要改成對所有被忽略的檔案做雜湊（`node_modules` 等會讓指紋又慢又誤報）。

**Done-when**：清單與判斷記在票裡；寫得到而且會被信任或執行的檔案都被指紋涵蓋，各有一個端到端案例（reviewer 寫入後 gate 中止）和變異檢查。

**See**: [[CC-674]]; [[CC-667]].

---

## CC-677 — qa-tester 在每個 gate 的第一次嘗試中都最後完成，可能是關鍵路徑 🟢 someday

**Problem**：[[CC-675]] 量了 11 個完整 gate（2026-10-25，codex 執行器、full tier，今天 #728 到 #733 期間的所有 gate）。四位非 QA reviewer 在 manifest 建好後約 330 到 450 秒完成（用了 `--test-cmd` 預檢的那一個除外），qa-tester 在 430 到 640 秒完成，在每一個 gate 的第一次嘗試中都是最後完成的。QA 比第二慢的 reviewer 晚 23 到 256 秒（11 個值的中位數 176 秒）。reviewer 階段（manifest 到所有 reviewer 結果就緒）中位數 607 秒，約佔 gate 總時間的 57%，所以 gate 時間可能大致是「QA 的時間」加上固定的前置和 synthesis；這是推論，n=11、兩者的範圍有重疊（非 QA 約 330 到 450 秒、QA 430 到 640 秒），沒有做過改變 QA 的時間再量總時間的實驗。

**Evidence boundary**：同一台機器、同一個執行器、n=11。QA 的耗時沒有拆開，不知道是模型思考時間還是它執行測試的時間（QA 會產生並執行 `qa-test-attempt`）。

**Requirement**：先量 QA 內部：模型時間與測試執行時間各佔多少（`.agent-trace` 的 codex 紀錄與 `qa-execution-*.json` 的時間）。再決定：若主要是測試執行，評估和 `--test-cmd` 預檢的重疊（今天 `gate-20261025-091816-8dc667` 用了預檢，QA 與其他人的差距縮到 73 秒，但其他人也慢了約 150 秒，總時間沒有變短，所以不是單純搬家）；若主要是模型時間，評估 QA 的 brief 範圍。順手把「分階段耗時與最慢的 reviewer」加進既有的 `pmctl gate stats`（它已有總耗時 mean/p50/max），不要另寫腳本。

**Done-when**：QA 內部耗時有資料；有一個被實測確認能縮短關鍵路徑的改動，或有資料支持的「不值得改」；`gate stats` 能重現這些數字。

**See**: [[CC-675]]; [[CC-678]].

---

## CC-678 — synthesis 因單一 finding 的 disagreement 被驗證器拒絕而整個重跑 🟢 someday

**Problem**：2026-10-25 的 `gate-20261025-084832-bfccb7`（PR #733 的第一輪 gate）：synthesis 的第一次嘗試被拒絕，原因是 `invalid disagreement references: entry D-001: finding_ids has 1 id(s); a disagreement records two or more findings in conflict, so a lone objection is a finding, not a disagreement`（`gate-protocol-attempts-*.jsonl` 記為 `retryable-failure`）。整個 synthesis 重跑一次，這個 gate 的 synthesis 與發布階段是 555 秒，其餘 10 個 gate 是 254 到 391 秒（11 個的中位數 281 秒），比其餘 gate 多約 164 到 274 秒（對最大值 391 秒與中位數 281 秒）。

**Evidence boundary**：11 個 gate 裡有 1 個 synthesis 重試，另一個 gate（`gate-20261025-015939-731bd5`）重試的是 risk-reviewer（多約 166 秒）。n 太小，不能據此說頻率。

**Requirement**：先累積更多 gate 的 `gate-protocol-attempts` 資料，算 synthesis 重試的頻率與原因分布。若這個原因反覆出現：評估由 shell 確定性地處理（把只有一個 finding 的 disagreement 降為一般 finding 或丟棄，因為內容已在 finding 清單裡），而不是靠模型再生成一次；任何放寬驗證器的改動要有測試，且不能放過真正的格式錯誤。

**Done-when**：重試頻率與原因有資料；有資料支持的決定（確定性處理、改 prompt、或維持現狀）。

**See**: [[CC-675]]; [[CC-677]].

---

## CC-679 — 本機一個指令跑完 CI 的 lint 集合 ✅ 2026-10-25

**Problem**：2026-10-25 在 #731、#732 各被 CI 擋過一次，都是我本機沒跑到的 lint：#731 是 `lint-test-docstrings`（測試函式正上方缺 `# Behavior:` 說明），#732 是 `lint-shellcheck`（`SC2034`，我跑的 shellcheck 範圍和 CI 的不同）。每次都多一輪約 20 分鐘的 gate。CI 的 lint 集合分散在 `.github/workflows/lint.yml` 的許多步驟，沒有本機的單一入口；我是臨時寫腳本逐一跑。

**Requirement**：提供一個指令（放在 `ops/diagnostics/` 或 `tools/lint/`）本機跑完 CI `lint.yml` 的同一組 lint，列出非零的項目；清單從 workflow 或 `tools/lint/` 目錄派生，不要手抄第二份。需要輸入的（例如 `lint-permanent-test-admissions` 要 PR 本文）明確跳過並說明。

**Done-when**：一個指令重現 CI 的 lint 結果；清單與 CI 不會分家（有測試或由 workflow 派生）；`docs/` 或貢獻指引提到它。

**Resolution 2026-10-25**：#735。新增 `ops/diagnostics/run-ci-lints.sh`：讀 `.github/workflows/lint.yml`，跑每個呼叫 `tools/lint/` 底下腳本或 `pm/scripts` 的 `validate.sh`、`lint-*.sh` 的 `run:` 步驟（今天 19 個），只在 runner 上有意義的步驟（用到 GitHub token、`git fetch`、runner 暫存目錄，今天 2 個）列為跳過並說明原因；一個失敗不會停下後面的步驟，失敗的步驟顯示最後 20 行，任何失敗就退出 1。`--list` 列出步驟與各自的指令、`--only TEXT` 篩選、`--wsl` 在原生 Windows 上經由既有的 `run-tests-in-wsl.sh --sync-only` 把工作樹複製進 WSL 再在那裡跑（沒有另寫第二套同步）。清單從 workflow 派生，不是手抄，所以 CI 新增的 lint 步驟會自己出現；regression 套件（`tests/shell/test-lint-*.sh`）刻意不在範圍內。登記為 `test-run-ci-lints`（runner 清單、`lint.yml` 一步），7 個案例：fixture workflow 的列出與跳過、全數通過、失敗後繼續與輸出、`--only`、CRLF 的 workflow、真實 `lint.yml` 的清單（有已知步驟、有 CI 專用的跳過、不含測試套件的區塊）、用法錯誤。兩個變異各自讓對應案例失敗（拿掉 CR 去除、讓失敗的步驟不再讓整體失敗）。寫它的過程就用上了它：第一次從原生 Windows 的完整執行（2 分 12 秒、`--wsl`）抓到這個 PR 自己新檔案的兩個問題（ShellCheck SC2016、變數消費者清單過期），在 WSL 跑新套件則抓到只有原生才綠的 fixture（假 linter 沒有執行權限）；我的 CRLF 測試最初太弱，拿掉 CR 去除它也過，現在要求名稱不帶 CR。審查代理另外抓到、已處理的：(1) 每個步驟改用 `bash -e` 跑，因為 GitHub 就是這樣跑 `run:` 腳本；沒有 `-e` 時，區塊中間失敗而最後一個指令成功的步驟本機會綠、CI 會紅，正好違背這個工具的目的（今天的區塊不受影響，但新增的會）。(2) 選取規則改成「真的執行」：註解或 echo 提到 `tools/lint/` 不再把整段區塊選進來，並加上字邊界。(3) 步驟名稱只取該步驟自己那一層的 `name:`，巢狀的 `with: name:` 不會蓋掉；`env:` 在 `run:` 之後才出現的 `${{` 也會讓步驟被判為 CI 專用；折疊區塊、引號純量、非 bash 的 `shell:` 會跳過並說明原因，不再默默跑錯。(4) `--wsl` 拒絕和 `--root`、`--workflow` 併用（那是主機路徑，WSL 裡不存在），跑完會移除自己複製的暫存樹，Ctrl-C 也會清掉暫存目錄。六個變異（拿掉 CR 去除、失敗不影響整體、拿掉 `bash -e`、註解也選取、名稱取任何深度、忽略 `env:` 的 `${{`）各自讓對應案例失敗。沒做：把這個 awk 與 `lint-test-suite-registry.sh` 的 workflow 解析抽成共用 helper（兩處都加了互相指向的註解）、平行執行（最慢的是約 2 分鐘的 ShellCheck lint，其餘加起來很短，平行幾乎不縮短總時間）。**限制**：不跑 `lint-permanent-test-admissions`（需要 PR 本文與 GitHub token）；選取規則看的是指令文字，所以一個把 lint 路徑藏在別處的步驟不會被選到；在原生 Windows 不加 `--wsl` 也能跑但很慢，部分 lint 結果不同。

**See**: [[CC-675]].

---

## CC-680 — 只能在 WSL 跑的測試檔，QA 沙箱拿不到執行證據而 hard block 🟢 someday

**Problem**：PR #733 的前兩輪完整 gate 都 NO-GO，其中一個 hard block 是 qa-tester 的沙箱跑不了 `tests/shell/test-pmctl-worktree.sh`（原生 Windows 的狀態根目錄權限拒絕，見 [[CC-369]] 與 [[CC-643]]），拿不到任何執行證據，我在 WSL 上的 50/50 它看不到。第三輪改用 `--test-cmd 'bash ops/diagnostics/run-tests-in-wsl.sh test-pmctl-worktree'` 讓 gate 在派發前自己執行，QA 引用了那份預檢證據，gate 才 GO。這個做法沒有寫在任何指引裡，是 reviewer 的 NO-GO 逼出來的。

**第二個例子**：PR #734（只改 `gate wait` 的逾時訊息，測試在 `test-pmctl-gate` 與 `test-gate-lifecycle`）的第一輪完整 gate 的結果是 `failed`（exit 2），不是 NO-GO：`Final GO refused: the supplemental test evidence of the qa-tester is inconclusive (qa-execution-...json) and no pre-flight test run passed; re-run with a passing --test-cmd`。reviewer 本身是 4 approve、1 advise、沒有 finding；qa-tester 的補充執行證據是 `status: inconclusive`、0 個指令。用 `--test-cmd 'bash ops/diagnostics/run-tests-in-wsl.sh test-pmctl-gate test-gate-lifecycle'` 重跑後 GO。這個例子**沒有**證明那兩個測試檔不能在原生跑（我沒有驗證過），只證明 QA 沙箱在這個環境下拿不到可結論的證據，host 因此拒絕出 GO。所以建議範圍不只「只能在 WSL 跑的測試檔」，而是「QA 沙箱拿不到證據時」。

**Requirement**：把「在原生 Windows 上，改動涉及只能在 WSL 跑的測試檔時，用 `--test-cmd` 帶 WSL runner 提供執行證據」寫進 gate 的使用指引（`docs/review-model.md` 或 pr-gate 技能說明）。評估是否讓 gate 在偵測到 QA 無法執行被改動的測試檔時給出這個建議，而不是等 reviewer hard block 之後才發現。

**Done-when**：指引有這個做法與適用條件；偵測與建議（若做）有測試。

**See**: [[CC-675]]; [[CC-643]]; [[CC-369]].

---

## CC-681 — CC-669 留下的兩個小缺口：統計讀者與圍欄後空白 🟢 someday

**Problem**：[[CC-669]]（#731）讓 gate 在模型寫的檔案進入處把 CRLF 轉成 LF，且讓圍欄讀者容忍行尾 CR。兩件事沒做：(a) `runtime/lib/pmctl-gate-stats.sh` 的 jq 仍用精確比對讀 `reviewer_result_v1` 圍欄，CRLF 的已發布結果在統計裡會顯示 `unavailable`（安全降級，但數字缺了）；(b) 圍欄後面多空白、縮排的圍欄或更長的圍欄，仍會被說成 `truncated reviewer result`，訊息對這些情況不精確（結果其實完整，只是圍欄不合規格）。

**Requirement**：(a) 讓統計讀者容忍 CR（或統一經過同一個正規化）；(b) 未閉合時，若找得到「幾乎是圍欄」的行，訊息說明「閉合圍欄必須剛好是三個反引號」而不是 `truncated`。

**Done-when**：CRLF 的已發布結果在 `gate stats` 有數字；近似圍欄的結果得到可行動的訊息；有測試。

**See**: [[CC-669]]; [[CC-675]].

---

## CC-682 — 讓等待一個 gate 更便宜：進度資訊、自動續等、輪詢指引 🟢 someday

**Problem**：[[CC-675]] 只改了 `gate wait` 逾時訊息的措辭，沒有降低操作員要等的次數。這個環境單次呼叫要在 540 秒內回來，而 gate 的中位數耗時 1060 秒，所以仍要兩到三輪 wait，每一輪操作員（或代理）都要重新啟動一次，也看不到 gate 跑到哪個階段。

**Requirement**：評估並擇一或多個（做之前先看是否有 CC-677、CC-678 縮短 gate 本身的效果）：(a) `gate wait` 逾時時印出已經過的時間與近期 gate 的耗時中位數（資料來自既有的 `pmctl gate stats`）；(b) `gate wait` 在總預算內自動續等，而不是一次逾時就回 124；(c) 把「用 Monitor 輪詢結果檔或 sentinel」寫進 `commands/pr-gate.md`，讓代理不必手動串連多個 wait。`dispatch wait` 有同樣的 124 語意與不同的措辭，一併決定要不要對齊。

**Done-when**：選定的做法有測試；一個典型 gate 需要的 wait 呼叫次數有量測前後對照。

**See**: [[CC-675]]; [[CC-677]]; [[CC-678]]; [[CC-685]]（`pmctl gate status` 已覆蓋「進度資訊」；(a) 的耗時中位數、(b) 自動續等、(c) 輪詢指引仍在這張票）.

---

## CC-683 — reviewer 重試恢復後，gate 的 operation 仍被標成 failed 🟢 someday

**Problem**：`pmctl_operation_reconcile`（`runtime/lib/pmctl-operation.sh` 約 548 到 553 行）把每個終態為 `failed` 或 `partial` 的子 run 都計入 `failed`，只要有一個就把整個 operation 標成 `failed`，不分辨這個失敗的子 run 之後是否已被有限重試恢復。2026-10-25 的 `gate-20261025-102110-111f90`：security-reviewer 第一次嘗試是 `transport failure`（`gate-protocol-attempts-*.jsonl` 記為 `retryable-failure`，第二次嘗試 `recovered`），gate 最後是 `Final: GO`、`gate verify` 為 `assurance: verified`，但 `gate wait` 印出 `operation: op-20261025T102103Z-134d52  state: failed  children: 7  unresolved: 0`。同一天另一個 gate（`gate-20261025-084832-bfccb7`）也有 7 個子 run，但重試的是 synthesis 的協定驗證（run 本身成功，沒有失敗的子 run），operation 是 `completed`。

**Evidence boundary**：機制是讀程式碼確定的；實際發生只有 1 次（n=1）。沒有查過有哪些流程依賴 operation 狀態（例如 `pmctl ship`、`state status`、`artifacts gc` 是否會因 `failed` 而改變行為）。

**Requirement**：先查誰讀 operation 的 `failed` 並因此改變行為。再決定：reconcile 要知道哪些失敗的子 run 已被後續嘗試取代（gate 的 `gate-protocol-attempts` 已經記錄 `recovered`，或在 `children.jsonl` 標註取代關係），取代後的 operation 該是 `completed`，並帶上「有 N 個子 run 被重試恢復」的資訊，而不是把恢復後的 GO 顯示成失敗。

**Done-when**：一個 reviewer 在第一次嘗試 transport failure、重試後恢復的 gate，其 operation 為 `completed`（或明確的恢復狀態），`gate wait` 輸出不再自相矛盾；沒有被取代的失敗子 run 仍然讓 operation 為 `failed`；有測試與變異檢查。

**See**: [[CC-675]]; [[CC-620]].

---

## CC-684 — test-pmctl-gate 的取消時間預算（10 秒）在負載下不夠穩 🟢 someday

**Problem**：`tests/shell/test-pmctl-gate.sh` 的案例 `gate cancel: foreground preflight process tree stops before cancelled terminal` 斷言 `elapsed -lt _GATE_TEST_CANCEL_BUDGET`，預設預算是 10 秒（原生 Windows 為 120 秒）。2026-10-25 在 PR #734 的 gate 預檢（`run-tests-in-wsl.sh test-pmctl-gate test-gate-lifecycle`）中，這個案例失敗一次：取消本身成功（`state: cancelled`、`gate_rc=130`、`cancel=0`、進程樹條件都滿足），但 `elapsed=10`，`10 -lt 10` 為假，gate 因預檢非零而在派發 reviewer 前中止（`failed`，exit 3）。同一個指令在前一個 gate 是 83/83，之後我只改了 BACKLOG。取消使用 `--grace 2`。

**Evidence boundary（更新 2026-10-26）**：**第二次發生（n=2）**：CC-685 的 PR #737 的 gate 預檢（`test-gate-lifecycle test-pmctl-gate`，經 `run-tests-in-wsl.sh`）在同一個案例失敗，日誌 `cancel=0`、`state: cancelled`、`gate_rc=130`、`elapsed=10`，取消本身成功，只是又踩到 `10 -lt 10`；gate 因此是 `INCOMPLETE`（exit 3），沒有派 reviewer，白花約 13 分鐘。那段時間我在同一台機器上跑指紋的基準測試（CPU 與行程密集），時間上吻合負載假說，但沒有證明因果。第一次（PR #734 的 gate）之後的重跑用了 `PM_GATE_TEST_CANCEL_BUDGET=30`（用 `WSLENV` 轉進 WSL）才過，這次的重跑也一樣，所以兩次「通過」都是在預算 30 秒下，不是預設值。兩次都是取消成功而預算踩線，所以這是預算太緊，不是取消壞掉。優先度因此從 P3 提到 P2：任何帶 `test-pmctl-gate` 預檢的 gate 都會被它擋。

**Requirement**：先量這個案例在 WSL 上多次執行的 `elapsed` 分布（空閒與有負載時），再決定預設預算。這個預算的用途是偵測取消卡死，不是效能要求，所以應該設成「明顯大於 grace 的正常耗時、明顯小於卡死」的值，並考慮用 grace 推導（例如 grace 的倍數加固定餘裕）而不是寫死一個接近正常值的數字。失敗訊息也應該印出 elapsed 與預算，現在只有 `gate_rc` 與 `elapsed` 混在一長串輸出裡。

**Done-when**：預設預算有量測依據；同一個案例在負載下不再因為踩線而失敗；失敗時能看出是時間預算而不是取消失敗。

**See**: [[CC-675]]; [[CC-680]].

---

## CC-685 — 等 gate 的人看不到它做到哪一步：沒有階段、最後進展與產物位置 ⚠️ partial 2026-10-26

**Problem**：issue #736（延伸 #726 的 C、D）。等待一個 gate 時，使用者不知道它在比較哪個 branch/base、為什麼是這個 tier、現在在哪個階段、有沒有實質進展，也找不到 log 與結果在哪。`pmctl artifacts show` 只列出幾乎是空的 supervisor log；run 目錄的 hash 看不出是哪個 repo；結果檔從一開始就是 0 bytes 的占位檔，gate ID 用 UTC 而結果檔用本機時間，兩者對不起來。issue 回報的案例：Windows 上只改 2 個檔案，約 26 分鐘仍未進 reviewer。

**Evidence boundary**：issue 的 26 分鐘是使用者回報，沒有完整 trace，我**沒有重現**。我自己量過的（[[CC-675]]，n=11、同一台機器）前置階段中位數 157 秒、scope manifest 約 12 秒，與 issue 的 7 分鐘、26 分鐘差很多。issue 自己也寫了不能宣稱 fingerprint 是唯一瓶頸。所以這張票先做「讓下一次能量到、看得到」，不做任何效能最佳化。

**Delivered（第 1 步，2026-10-26）**：
- `runtime/lib/gate-phase.sh`：detached gate 把階段事件（帶時區的時間戳、`start|end|info`、`key=value` 細節）逐行附加到 `<run dir>/gate-phase-events.jsonl`；寫入失敗或沒有 run 目錄時靜默略過，不影響任何判決。
- `pr-gate.sh` 在這些固定點記錄：`gate`（開始 / 以 exit 結束，兩個 EXIT trap 都記）、`prepare`、`context`（repo、branch、HEAD、base、tier 與原因、mode、reviewer、結果檔路徑）、`subject_snapshot`、`scope_manifest`、`preflight_fingerprint`（測試前 / 後各一次）、`preflight_tests`、`worktree_hash`（reviewer 前 / 後）、`reviewers`（並行：每位啟動與重試；序列：每次嘗試）、`synthesis`（每次嘗試）、`publish`。
- `pmctl gate status <gate_id> [--cd <repo>]`：只讀終止 sentinel、supervisor 身分記錄與事件檔，不觸發任何掃描。分開印出 `heartbeat`（supervisor 行程是否存活）與 `progress`（最後一次事件）；印出 state、目前 phase 與該 phase 已花時間、總耗時、計畫（context 事件）、最近 6 個事件、supervisor log 與事件檔的路徑，以及結果檔狀態（pending 的 0-byte 占位檔、內容已存在但 gate 未完成、或已發布的路徑）。無法判定時印 `unknown`，不保證仍在執行。exit 0 = 已印出狀態，2 = 用法錯誤，3 = 該 `--cd` 下沒有這個 gate。
- `pmctl gate wait` 逾時時多印一行 `phase <名稱> for <時間>, last event <時間> ago`，並指向 `gate status`；原有的措辭不變。

**Delivered（同一個 PR #737 追加：指紋批次化，2026-10-26）**：
- **研究**（原生 Windows、564 個追蹤檔，同一份工作樹，一台機器）：現行 `_gate_subject_tree_fingerprint` 要 118 到 127 秒（gate 內實測 78 到 85 秒）。其中每個檔案一次 `gate_digest_file` 約 102 到 109 秒（每次約 181 毫秒，約 4 次 fork/exec；一次 `$(...)` fork 約 23 毫秒、一次 exec 約 48 毫秒），每個檔案一次 `$(printf '%q')` 約 15 秒；一次批次 `sha256sum` 處理全部檔案只要 1 秒。Linux（WSL）同一函式 6 秒。一個 gate 的事件檔實測到 3 次指紋（`subject_snapshot`、預檢前、預檢後）；依呼叫點推得 reviewer 之後還有 2 次（`verify_preflight_artifacts_current`、最終 assurance 快照），**已由最終 gate 的事件檔證實**（reviewer 結束後有兩筆 `fingerprint info`），`gate wait` 結束時的驗證另算一次。reviewer 結束到 publish 之間沒有事件的 3 分 33 秒，**已證實**是後面兩次指紋，批次化後這段降為 37 秒。
- `runtime/lib/gate-subject.sh`：working-tree / committed-head 指紋先用一次 `xargs -0 sha256sum -z --` 取得全部普通檔的摘要放進只在該次呼叫內有效的快取，再逐檔組 manifest；路徑跳脫改用 `printf -v`（不開子 shell）。**摘要與舊函式逐位元相同**（原生 Windows 與 Linux 在同一份樹上得到同一個值）。快取沒有的檔案（含 `[` `]` `\` 換行、恰為 `@`、`*` 或 `-` 的名字、批次失敗、`sha256sum` 不支援 `-z`）照舊逐檔案雜湊，錯誤仍由那條路徑回報（exit 2）。`PM_GATE_SUBJECT_BATCH_DIGESTS=0` 關閉批次。函式層實測：原生 Windows 105 秒 → 5 秒（564 個檔案全部命中、0 次落空）。**這個數字只對函式成立**：第一版在真實 detached gate 裡沒有生效（見下一條），修正後用只到預檢的 detached gate 量到（同一台機器、各一次）：`subject_snapshot` 由 72 到 88 秒降到 8 秒，預檢前後兩次 fingerprint 由 72 到 85 秒降到 5 到 7 秒。最終 gate（序列模式、含 reviewer、一次）端到端 15 分 50 秒，對比同 PR 較早那個 gate 的 32 分 11 秒；批次化能歸因的約 5 分鐘（快照 85 秒 → 5 秒、預檢前後指紋各 78 與 77 秒 → 3 秒、reviewer 結束後那段 3 分 33 秒 → 37 秒），其餘約 11 分鐘（reviewer 9 分 26 秒對 15 分 57 秒、測試 4 分 26 秒對 7 分 36 秒）是模型時間與機器負載的變動，沒有量。
- **gate 審查（第三輪）找到我引入的完整性漏洞**：名字恰好是 `-` 的檔案，`sha256sum` 即使在 `--` 之後仍把它當標準輸入，批次裡 stdin 是空的，快取存下「空輸入的摘要」，於是改了這個檔案指紋卻不變；四位 reviewer 獨立指出同一點。逐檔案路徑沒有這個問題（它用完整路徑）。修正是讓恰為 `-` 的名字走逐檔案路徑；夾具現在永遠有一個非空的 `-` 檔，新案例只改它的內容並要求指紋改變且與逐檔案一致，把 `-` 放回批次會讓它失敗。我先前列「批次放不下的名字」時只想到輸出格式與關聯陣列鍵的問題，漏了 `sha256sum` 自己對運算元 `-` 的特例。
- 實作時踩到的坑，測試都固定住了：原生 Git Bash 的 `sha256sum` 在二進位模式輸出 `hash *name`（星號）而非兩個空格，解析若假設兩個空格會**無聲**退回逐檔案路徑而不報錯，所以有命中與落空計數器；`[[ $p == *[\$'\n']* ]]` 會把字母 `n` 當成怪字元；快取不可跨次沿用（預檢前後兩次指紋就是要看見變化）。**最大的一個：第一版在 detached gate 裡完全沒有生效。** detached gate 的環境變數總量很大（模擬用 30 KB 的變數可重現），`xargs` 以「參數上限減環境大小」算可用空間，不夠就放棄（`xargs: environment is too large for exec`、`assertion "bc_ctl.arg_max >= LINE_MAX" failed`），我的程式把錯誤丟掉，指紋無聲退回逐檔案；單獨呼叫與前台 `pr-gate.sh` 只要 5 到 11 秒，所以我先前只量函式就宣稱改善，直到發現真實 gate 的事件檔仍是 75 到 80 秒才查到。修正是用 `env -i PATH="$PATH" xargs` 在最小環境下執行；另外每次指紋都會把 `digests batched=N per-file=M` 記成階段事件，`gate status` 看得到，下次無聲退回時一眼就會發現。
- 測試（`tests/shell/test-gate-digest.sh`）：批次與逐檔案指紋逐位元相同（含空白、非 ASCII、前導 `-`、括號、`@`、`*`、反斜線、換行、符號連結、空檔、二進位、可執行、被刪除、未追蹤、gate 產物）並檢查命中 / 落空數；批次只起常數個 `sha256sum` 行程；星號 / 兩空格 / 不支援 `-z` 三種輸出；快取不跨次；讀不到的檔案兩條路徑都 exit 2（只在 Linux 非 root）。

**Not done（待做，順序即建議）**：
1. 執行預覽（issue A）：在昂貴步驟前印 repo、branch、HEAD、merge-base、變更檔數、tier 原因與預計 reviewer；base 無法解析、空 diff 或異常大的範圍給具體診斷。目前只有 `context` 事件在 policy 解析之後才寫入，base 偵測（含 `gh pr view`）與 policy 解析的耗時還沒有各自的事件。
2. 結果占位檔（issue C）：`pr-gate.sh` 開頭 `touch "$OUTPUT_FILE"` 建立 0-byte 檔。`gate status` 已把它標為 pending，但檔案本身仍以正式名稱存在；要改成不以正式名稱出現，需先確認 `GATE_OUTPUT_EXISTED` 與 assurance sidecar 的讀取者。另外 gate ID 與結果檔名的時區差還沒處理。
3. 逐階段耗時的量測，餵給 `pmctl gate stats`，之後才能決定 issue D（前置總預算）與 E（有樣本與適用條件的 ETA）。第一筆實測（PR #737 自己的 gate，序列模式，原生 Windows，**只有這一筆**）總共 32 分 11 秒：prepare 32 秒、subject_snapshot 85 秒、scope_manifest 29 秒、預檢前 fingerprint 78 秒、預檢測試 7 分 36 秒、預檢後 fingerprint 77 秒、reviewers 15 分 57 秒、publish 1 秒；三次 snapshot/fingerprint 合計約 4 分鐘（約 12%）。**reviewers 結束到 publish 開始之間有 3 分 33 秒沒有任何事件**（應是結果驗證與 assurance 收尾），要先補事件才看得出那段在做什麼。預算耗盡的語意必須是獨立的 incomplete 狀態，**絕不因超時回 GO**，並與 wait 逾時、取消、reviewer 判決可區分；預設秒數要有量測依據。
4. fingerprint 進度計數（issue B 的「可計數工作」）與其餘效能。**批次 hash 已在 PR #737 做完，見 Delivered**；剩下的瓶頸不在我們能優化的範圍：預檢測試本身（約 7.6 分鐘）與序列 reviewer（約 16 分鐘，模型時間）。`prepare`（32 秒，推測是 `gh pr view` 與 policy 解析）與 `scope_manifest`（29 秒）要先補事件量到細項再談。不能只憑 mtime/size 判定內容未變，也不能犧牲審查期間的變更偵測。
5. 沒有機器可讀輸出（`gate status --json`）；需要時再加。
6. 指紋批次化之後的後續（`/simplify` 審查提出、屬實但不在 PR #737 內做）：(a) `fixed_ref` 仍是每個 blob 兩個行程（`git cat-file` + `gate_digest_file`），若它在 Windows 上成為 gate 的 subject 會比剛修好的路徑慢；可用 `git cat-file --batch`。(b) 「一次摘要多個檔案」更適合放在 `gate-digest.sh` 當 `gate_digest_files`（它擁有「一個 64 位十六進位摘要或失敗」的契約，CC-629 c），再讓 `gate-scope.sh` 對未追蹤檔案的逐檔案迴圈（約第 97 到 120 行）複用；目前只在 `gate-subject.sh` 內。(c) 預取與 manifest 各列一次 `git ls-files`、各建一個暫存目錄、各檢查一次 `-L/-f`，每次指紋多約一個 git 行程與數十毫秒；批次化後一次指紋剩下的約 5 秒還沒拆開量測（`read -d ''` 逐位元組讀取、manifest 迴圈）。(d) `declare -gA` 需要 bash 4.2；專案本來就以 4.2 為下限，但 macOS 內建 3.2 要自備較新的 bash。(e) detached gate 的環境變數總量超過 30 KB，原因未查：它讓 `xargs` 拒絕執行，也可能影響其他把大量參數交給子行程的地方；值得量一次環境裡各變數的大小，看是誰導出了大物件。

**Done-when**：issue #736 的驗收條件逐項勾掉；Windows 原生與 WSL 的結果分開記錄。

**Windows 驗證的限制**：新增的 `gate status` 與事件檔測試在原生 Windows 與 WSL 各跑；`tests/shell/test-pr-gate.sh` 中兩個擴充的案例（成功的序列 gate、預檢失敗的 gate）在原生 Windows 本來就跑不了（`sequential dispatch exited 2`，沒有我的改動的 HEAD 同樣失敗），只在 WSL 驗證。

**See**: [[CC-675]]; [[CC-682]]（等待成本：進度資訊的部分由本票覆蓋，自動續等與輪詢指引仍在 CC-682）; [[CC-677]]; GitHub issue #736、#726。

---

## CC-686 — 記憶注入 hook 每次提示耗時隨卡片數線性增長，原生 Windows 約 130 張卡就超過 30 秒 ⚠️ partial 2026-10-26

**Problem**：issue #738。`runtime/hooks/guard-inject-memory.sh` 在每次 UserPromptSubmit 都執行。舊版對每張一般卡各啟動 3 次 `awk`（priority、status、topics）加 1 次 `tr`（計分），Windows 上每個行程數十毫秒，所以時間隨卡片數線性成長，超過宿主的 30 秒期限後輸出被丟棄。

**Baseline（原生 Windows、這台機器、合成卡片、每格一次，N=50 重複一次為 12.4 秒）**：

| 卡數 | 10 | 50 | 100 | 200 |
|---|---|---|---|---|
| 舊版 hook | 4.6 秒 | 12.4 到 13.2 秒 | 25.1 秒 | 48.2 秒 |
| 本票第一階段 | 約 2.1 到 2.6 秒 | 約 2.2 秒 | 約 2.9 秒 | 約 3.5 到 3.7 秒 |

1000 張卡：新版 6.9 與 7.0 秒（兩次，補回「只讀一般檔案」的檢查之前）、約 8.1 秒（補回之後，一次）；舊版**沒有量**，依線性外推約 230 秒，這只是外推。每張卡成本由約 230 毫秒降到約 4 到 5 毫秒。舊版 `awk` 啟動數 8 張卡 25 次、40 張卡 121 次（`tr` 10 → 42 次）。

**Delivered（第一階段，issue 的「先消除 N 倍程序成本」）**：
- `runtime/lib/memory.sh` 新增 `memory_index_snapshot`：一個 `awk` 讀 `MEMORY.md`，用 `getline` 在 awk 內讀每張被連結的卡的 frontmatter，一次輸出 `tier / degraded / score / rel / line`。規則逐條沿用舊的 `_card_field` / `_card_topics` / `_score`（第一個 frontmatter 區塊、第一個 `priority:` / `status:`、`  - ` 的 topics、去引號、ASCII 小寫化）。目錄與關鍵字走環境變數與檔案，不進 argv。
- `memory_age_bucket_var`（不開子 shell 的版本；`memory_age_bucket` 改為包它）。
- hook：`cwd`+`prompt` 一個 `jq`、resolve 結果一個 `jq`（NUL 分隔）；episodes 只完整讀一次（舊版 slurp 兩次）並把日期運算由 3 個行程併成 1 個；tier2 排序改用記憶體裡的列。
- **行為保持**：以 `HEAD` 匯出的原版為比對基準，輸出與 usage 資料表在這些情形下逐字相同：10/50 張卡、12 種 episodes 變體與 7 種邊界 episodes（空白摘要、缺摘要、`"\n"`、`" \n "`、tab、`false`、數字、`null`、壞行與空行、時區、小數秒、非物件、剛記錄、壞日期、空檔、無檔）、15 張邊界卡片 × 7 種提示詞（無命中、CJK、空、多行、大小寫、超長）。
- **只讀一般檔案（gate 審查找到的退步）**：舊 hook 對每張被連結的卡先做 `[[ -f ]]`；改成 awk 的 `getline` 後這個檢查消失，索引連到沒有 writer 的 FIFO 時 hook 會一直阻塞到宿主的 30 秒期限（我實測：原版 2 秒結束，新版 25 秒逾時），連到無限裝置的符號連結則會無界讀取。現在由 hook 先用 bash 內建的 `[[ -f ]]` 列出「一般檔案」清單，awk 只開清單內的卡；代價是每張卡多一次內建 stat，1000 張卡約多 1 秒。新案例 `a-fifo-as-a-linked-card-does-not-block-the-hook` 在忽略清單時會逾時失敗。critic 與 security-reviewer 各提了同一點（advisory），qa-tester 指出同一個測試缺口。
- 新套件 `tests/shell/test-memory-hook.sh`（4 案例，原生與 Linux 都過）：邊界卡片的黃金輸出（由原版產生）、`awk`/`tr` 行程數不隨卡數增長（對原版會失敗：25 → 121）、多行提示詞後行的關鍵字、episodes 十四個分支。
- 現有回歸（Linux）：`test-guards` 310 通過、`test-pmctl-memory` 135 通過。

**Not done（順序即建議）**：
1. 固定成本約 2 秒：`pmctl_memory_resolve` 約 0.8 秒（`pm_config_project_key` 與 `_sw_worktree_project_key` 各跑多個 git，project key 算兩次）、`memory_usage_commit` 約 0.25 秒、約 5 個 `jq`（各約 50 毫秒）、載入函式庫。
2. usage 讀取：目前 `total_events` 與逐卡資料兩次 sqlite 行程，hook 用不到前者；usage 寫入在第一個 stdout 前同步執行，沒有 hook 專用的短預算（issue 的「同步 retrieval 不應被使用統計拖垮」）；已遷移的 TSV 每輪仍重展開 migration SQL。
3. **中繼資料索引／快取（issue 的第二階段）**：本票沒有回答這個問題。每次提示仍讀每張卡的 frontmatter，成本仍隨卡數線性成長（1000 張約 7 秒）。是否引入、以及「進階自動注入是否以 SQLite 為必要條件」是待確認的產品決策，不是本票做的。
4. episodes 讀模型：目前每次仍讀整份 `episodes.jsonl`（O(episodes)）；issue 要求 10/1000/100000 行的量測，未做。
5. 三平台基準：issue 要求原生 Windows、原生 Linux、WSL 各自的 baseline/after、cold/warm p50/p95；本票只有原生 Windows 單機的單次數字，Linux 與 WSL 只驗證了「行為相同、測試通過」，沒有量速度。
6. `/simplify` 審查提出、屬實但不在本票做的後續：(a) 卡片 frontmatter 規則現在有三份實作（此處 `^---` 圍欄，`pmctl-memory.sh` 的 `_mem_card_repo_refs` / `_mem_card_top_keys` 用 `^---[[:space:]]*$`，加上 lint），應統一成共用原語並讓 GC、stats、search 重用；本票刻意保持舊規則以不改行為。(b) 把 snapshot 拆成「中繼資料」與「計分」兩層。(c) 多處 `jq` 的 NUL 分隔讀取可抽成共用 helper。(d) 計數 stub（`_counting_stub_dir`）搬到 `tests/lib`。(e) 再省兩個 `jq`（resolve 結果與日期運算，各約 70 毫秒）。(f) 排名迴圈到 1000 張以上才顯著，必要時讓 awk 讀 usage 並直接輸出 composite。

**Evidence boundary**：issue 沒有使用者實際的安裝 revision、卡片數、episodes 大小與分階段量測；這裡的卡片是我合成的（每張約 600 位元組，含 frontmatter），所以「約 130 張卡越過 30 秒」是我的機器上的線性外推，不是使用者環境的結果。

**發現（順帶，與本票無關）**：CRLF 結尾的卡片，`priority: always` 在 Linux 上不會被釘住（值帶 CR），在原生 Windows 的 awk（文字模式吞掉 CR）上會；這是原版就有的平台差異，新版保持一致，新套件因此不放 CRLF 卡。

**Done-when**：issue #738 的驗收條件逐項勾掉；至少原生 Windows、原生 Linux、WSL 三平台有公布的基準。

**See**: GitHub issue #738；[[CC-685]]（同一個「量測再改」方法與教訓）。

---

## CC-687 — 記憶平面索引建置與更新太慢 ⚠️ partial 2026-10-27

**Problem**：issue #738 問「為什麼用了 SQLite 還是慢」。程式裡有兩個 SQLite：usage 側檔（CC-688）和記憶平面索引 `<memory_dir>/.pm-dispatch/context.db`（`pmctl context query --source memory`、`/mem-search`、`/mem-recall`、gate 的記憶脈絡、pm 的 context pack 在用；注入 hook **沒有**用）。後者讀很快、建置與更新很慢。

**實測（原生 Windows、這台機器、合成卡片，單次，雜訊大）**：
- 讀一個建好的索引：約 87 到 95 毫秒。
- 1000 張卡冷建：301 秒（約 0.3 秒一張卡）。以帶時間戳的 `bash -x` 軌跡拆開：`wc -c \| tr` 約 85 秒、`date` 約 66 秒（兩者合計一張卡 3 個行程）、逐行切塊（純 bash）約 120 秒、`_ctx_extract_symbols` 的行程替換約 19 秒。
- 沒有任何變動的更新：4.2 到 5.2 秒。批次 `stat` 0.65 秒、批次 `sha1sum` 0.84 秒、讀 `files` 表 0.09 秒，下限約 1.6 秒；其餘在四個對全部檔案的 bash 迴圈，軌跡下沒有單一主導的行（約 1000 次 × 數個 `$(…)`／陣列操作）。
- 注意：`_ctx_ensure_fresh_memory` 若傳入結尾帶 `/` 的目錄，檔案相對路徑對不上資料庫裡的鍵，會整個重建（我測試時踩到，兩次各 305 秒）。呼叫端（`_ctx_resolve_memory_dir`）傳的是否帶斜線**尚未確認**，列為待查。

**步驟與狀態**：
1. ✅ 每個檔案的大小改用已批次的 `stat`（新的 `_ctx_batch_stats`，同一次 `stat` 多輸出 `%s`），整個執行只讀一次時鐘（`files.indexed_at` 與 `index_meta.built_at` 改為本次執行開始時的值，原本是各檔處理時的值；只有 `context status` 回報 `latest_indexed_at`，沒有判斷邏輯讀它）。冷建 100 張卡 36 → 24 秒、300 張卡 100 → 42 秒（單次，雜訊大）。以 40 張邊界卡（空檔、無結尾換行、單引號與中文檔名）對 `main` 的乾淨匯出建出資料庫，`files`／`file_chunks`／symbols 數／`index_meta` 逐列相同。測試：`pmctl context index: building the index starts no wc/tr/date process per file`，把舊行為還原的變異會失敗（6 張卡 23 次、30 張卡 95 次）。第一輪 gate（GO）的 qa-tester advisory 指出一個真退步：repo 平面（`git ls-files`）會列出符號連結，不帶 `-L` 的 `stat` 回傳連結文字的長度（14），舊的 `wc -c <` 跟隨連結（目標 296）。已修（連結不用批次的大小，由產生器照舊量目標），新案例 `a symlinked file is stored with the size of its target` 在移除修正時失敗（`size_bytes=14`，目標 296）；該案例在原生 Windows 會跳過（沒有真的符號連結），只在 Linux/WSL 驗證。
2. ⬜ 切塊（`_ctx_chunk_markdown`／`_ctx_chunk_window`）由逐行 bash 改為一個 awk 處理所有要重建的檔案；`_ctx_extract_symbols` 對 markdown 不需要行程替換。需要逐列相同的比對（含 CRLF、無結尾換行、長行、非 ASCII）；估計還可省冷建的一半，**未量測前不承諾數字**。
3. ⬜ 暖更新：四個 bash 迴圈改為一次 awk 比對（`stat` 輸出對 `files` 表），保留現行的契約「mtime 相同仍用 sha1 判定」（不改成只看 mtime）。目標是接近 1.6 秒的下限；**未做**。
4. ⬜ 查呼叫端是否會傳帶斜線的目錄，並在入口正規化。
5. ⬜ 三平台基準：Linux、WSL 的速度沒量過。

**不做**：不把這個索引接到注入 hook。理由見 CC-686：hook 要知道卡片是否被外部改過，得對全部檔案 `stat`，其成本與直接讀取同一個量級；一個 `awk` 讀 1000 張卡約 0.5 秒。

## CC-688 — 注入 hook 的 usage 讀寫預算 🔵 active

**Problem**：issue #738 第 2 點。`memory_usage_read` 對每次提示啟動兩個 `sqlite3`（先讀 `total_events`，再讀全部列；hook 的載入函式丟掉 `total_events`），讀取 `.timeout 10000`；寫入 `memory_usage_commit_sqlite` 最多 4 次嘗試，每次 busy handler 1500 毫秒加重試暫停，並且對**每張命中的卡**用 `$(_memory_usage_sql_quote …)` 多一個子 shell。最壞情況：2 × 10 秒讀 + 4 × 1.5 秒寫 ≈ 26 秒，在宿主 30 秒期限內只剩 4 秒。這是由程式碼推得的上限，**不是實測**。

**計畫**：
1. 讀：一個 `sqlite3` 行程只取列；`total_events` 只在需要它的呼叫端另取。hook 專用的讀逾時（預設 2 秒，環境變數可調，登記到變數清單）。讀失敗維持現有的 `MEMORY_USAGE_READ_FAILED` 降級，不把讀不到當成「從未使用」。
2. 寫：`_memory_usage_sql_quote` 改為寫入變數的版本（與 `memory_age_bucket_var` 同樣做法）；hook 專用的寫入總時間預算（預設 3 秒，涵蓋所有嘗試與暫停）；預算用完就放棄這一輪的寫入並明確降級，保留 WAL、`BEGIN IMMEDIATE`、`-bail`、exactly-once 重試與遷移保護，不改全域鎖逾時。
3. 被略過的寫入要讓統計知道：本票先決定並寫明——略過就少記，退化只影響排序的頻率權重，不影響輸出的正確性；若要在 `stats` 顯示略過次數，需另外設計儲存（不能在已被鎖住的資料庫裡寫），列為待決定而非預設。
4. 測試：持鎖故障注入（背景 `sqlite3` 持有 `BEGIN IMMEDIATE`），hook 必須在預算內結束且仍印出完整注入；讀取同理；50 個並發寫入者與 exactly-once 的既有測試不得變動。
5. 量測：持鎖時的 hook 牆鐘時間，修改前後。

**順序**：CC-687 步驟 1 → CC-688 → CC-687 步驟 2 到 4。互不堆疊 PR。

## CC-689 — 通用量測工具 ⚠️ partial 2026-10-27

**Problem**：issue #742。#738、#741、#736 各自需要「各階段耗時、cold / warm、p50 / p95」的基準，但每次都臨時手拼（`bash -x` + awk），格式不一，xtrace 還會放大耗時、吞掉 `$(...)` 內的追蹤，PR 的效能宣稱無法複核。

**最小版（本票已做）**：
- `pmctl time [--runs N] [--json] [--show-output] [--baseline] -- <指令>`：第一個詞是 `pmctl` 時跑本 checkout 的 `cli/pmctl`；輸出丟棄（`--show-output` 才顯示）；cold 是第一次，warm 是其餘的 nearest-rank p50 / p95 / max；有失敗的 run 時結束碼 1。
- `runtime/lib/timing.sh` 的 `pm_timing_phase <name>`：只在 `PM_DISPATCH_TIMING_FILE` 有值時寫一行「名稱 TAB 時間」到該檔，不碰 stdout / stderr，未設定時不啟動任何行程；階段持續到下一個標記或指令結束。時間用 `$EPOCHREALTIME`，量測本身不啟動行程。
- prompt-scan 標了 `ensure_fresh`、`checks`、`query`、`rank`、`emit_event` 五段。第一次實測（單次、一台 Windows 機器）：`ensure_fresh` 約 5 秒、`query` 約 3 秒、`emit_event` 約 2.9 秒，與 #741 的懷疑一致，但還沒做 p50 / p95 的系統性量測。
- 報告只含耗時、次數、工具版本；不含指令參數與輸出（測試有檢查）。

**待做**：第一個標記之前的耗時補一列「未歸屬」，讓表加總等於牆鐘時間；成對的 start/end 區段（巢狀階段、`events_append` 內部拆分）；外部程序啟動計數（與計時分兩種模式，報告註明數字來自哪個模式）；`pmctl diagnose perf` 固定情境與 hook 接線重現；其他熱路徑加標記時再逐一登記。

**See**: GitHub issue #742；[[CC-690]]（第一個使用者）；[[CC-685]]（同一個「量測再改」方法）。

## CC-690 — prompt-scan hook 在 Windows 每次提示 37 到 57 秒 🔵 active

**Problem**：issue #741。第二個 UserPromptSubmit hook（`inject-context.sh`，`pmctl context prompt-scan`）原生 Windows 每次 37 到 57 秒，逼近它自己 45 秒的內部 timeout。與 #738（記憶 hook）是不同路徑。

**計畫**：
1. 用 `pmctl time --runs 10 -- pmctl context prompt-scan . "<固定提示>"` 量出各階段的 p50 / p95，貼在 PR。
2. 修最大的一段，一次一段，每段前後各量一次：遙測 `events_append` 移出同步關鍵路徑或降價（保留事件語意與 exactly-once）；`_ctx_parse_query_tsv` 逐 row 解析改批次；hook 內不做同步刷新（過期要可見）；`_ctx_chunk_markdown` 與 CC-687 步驟 2 到 5 合併評估。
3. 用真實 hook 路徑驗證，不只量函式（見 CC-685 的教訓）。

**順序**：CC-689 → CC-690 → CC-688 → CC-687 步驟 2 到 5。互不堆疊 PR。

**第 1 步已做（遙測寫入的行程數）**：
- `_ctx_emit_usage_event` 與 `_ctx_emit_pack_event` 共用 `_ctx_event_stamp`（時間與事件 id）；usage 事件不再為每個事件啟動 `date` 兩次、`dd | od | tr`、`jq`：時間由 shell 內建格式化（同一個 epoch、固定 UTC），隨機位元組只用一個 `od`，一般事件（無查詢文字、普通 kind、整數命中數）直接格式化，輸出位元組與原 `jq` 程式相同（測試逐位元組比對）；有查詢文字或奇怪的值仍走 `jq`。
- 專案 key 的行程內快取（`_sw_project_key_var`；簽章是 `_SW_REPO_ROOT` 與 `PWD`，不快取 `global`），`state_store_init` 與之後的 `_sw_project_dir` 不再各算一次 `git rev-parse` 加雜湊。
- 量測（一台原生 Windows 機器、行程啟動約 38 毫秒、prompt-scan 每次約 9 秒）：交錯 A/B 三輪，`emit_event` 階段 2.64 / 2.76 / 2.76 秒 → 2.14 / 2.17 / 2.22 秒（每輪都降，約 0.55 秒）；總時間 p50 的差異（約 0.2 秒）在這台機器的雜訊內，分不出來。#741 回報的機器行程啟動約 230 毫秒，拿掉的行程在那台預期省更多，但尚未在那台驗證。
- 審查：重構／重用審查（4 個 agent）採用兩項（`_ctx_event_stamp` 由 usage 與 pack 事件共用；專案 key 快取命中不再開子 shell）。pr-gate 第一輪（standard、sequential、codex）NO-GO：直接路徑的測試預期值取自被測輸出，改為取自請求的 kind／查詢／命中數，UTC 測試改用前後時鐘區間；兩種變異（命中數寫死 0、kind 寫死）都被擋下。定向 qa-tester pass 被 policy floor 拒絕（執行錯誤，不是裁決），改跑完整 initial pass。再補一則中度建議（emitter 結束碼要被斷言），最終 head `5d2a9ad` 的 gate 為 GO、無任何建議，`gate verify` 三軸通過。risk-reviewer 未被選入。

**第 2 步已做（`query` 階段的 FTS5 探測）**：`prompt-scan` 對每個詞呼叫 `_ctx_parse_query_tsv`，而 `_ctx_query_hits_raw` 跑在 process substitution 的子 shell 裡，`_ctx_fts5_available` 的快取每次都隨子 shell 消失，於是每個詞（最多 8 個）都重做 FTS5 探測：`CREATE VIRTUAL TABLE`、`DROP TABLE`（兩次寫入）、`sqlite_master` 查詢加 `grep`，每個詞約 150 毫秒。現在 `prompt-scan` 在迴圈前於父 shell 問一次 `_ctx_fts_usable`，答案放進 `_CTX_FTS_USABLE[<db>]`，迴圈後清掉；`_ctx_query_hits_raw` 有值就用，沒有就照舊自己探測（其他呼叫端行為不變）。輸出與 main 逐位元組相同。
- 量測（同一台機器，prompt-scan 整體，交錯 A/B 三輪）：11.45 / 11.30 / 11.87 秒 → 9.89 / 10.25 / 10.78 秒，每輪少約 1.1 到 1.6 秒。階段拆分這次沒有可信數字（我的 awk 算錯），不引用。
- 測試：`test-state-hot-path.sh` 兩個案例（一次探測、答案與逐詞探測相同；六個詞的真實 `prompt-scan` 探測次數少於詞數）；拿掉預熱後第二個案例失敗（探測 7 次）。
- 仍未動：`ensure_fresh` 約 2 秒、ACL 檢查約 630 毫秒、每個詞仍有的 `_ctx_db_path` / `_ctx_sql_str` 子 shell 與兩個 `sqlite3 | tr`（下一步可合併成一次 sqlite3 呼叫）。

**剩下的大頭（未動）**：`state_store_init` 的 ACL 安全檢查約 630 毫秒（Windows 上叫 PowerShell，fail-closed，不為了速度快取判斷）；`ensure_fresh` 約 2 秒；`query`（`_ctx_parse_query_tsv` 逐 row）約 3 秒。下一步先量 `query` 內部。
