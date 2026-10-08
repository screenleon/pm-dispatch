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
| CC-447 | 🔵 active | onboarding 三 smoke：offline clean install + N-1 upgrade（v0.11.0，**✅ 已交付**）+ live dogfood（readiness review 後再排，票維持 active 待此項） | docs/ops | 2026-07-04 | pr:#573 | P2 | — |
| CC-472 | 🟢 someday | spike: antigravity（`agy` CLI）host 唯讀 probe——比照 CC-436/CC-448 階段 1 模式，實測 command 載入能力 + hook/plugin 機制 + 五個 capability enum 的 provider/confidence 判定，不落地 `hosts/antigravity/host.yaml`；排在 CC-445 通用 install/uninstall dispatcher 之後、與 CC-448 opencode 同批或緊接其後評估（N=3 驗證點） | arch/install | 2026-07-08 | — | P3 | spike |
| CC-568 | 🟢 someday | `/mem-distill` Case→Strategy 機械式提升：對 `episodes.jsonl` 既有結構化欄位做 count/cluster 門檻判定，取代逐次主觀「感覺像 pattern」的判斷；依賴 [[CC-567]] 的 outcome 證據決定是否值得做（2026-08-25 memory 架構設計討論） | memory/DX | 2026-08-25 | — | P2 | retrieval |
| CC-569 | 🟢 someday | `pmctl task` / `context pack` 擴充 working-memory 敘事欄位（`selected_memories`／`rejected_paths`／`blockers`／`next_action`）：延伸既有 schema，不新建第二個「現在在幹嘛」真相來源；依賴 [[CC-567]] 證明有價值後再排（2026-08-25 memory 架構設計討論） | memory/DX | 2026-08-25 | — | P2 | design |
| CC-570 | 🟢 someday | Fact/Case/Strategy `memory_function`／`memory_subtype` metadata 分類法：先蒐集 [[CC-567]] 的 applied/outcome 證據，再決定值不值得建分類機制——不憑直覺先建立稅務式標籤（2026-08-25 memory 架構設計討論；外部文章優先序建議相反，本 repo 刻意反過來） | memory/DX | 2026-08-25 | — | P3 | retrieval |
| CC-575 | 🟢 someday | test-governance Batch 1 存量遷移：把其餘 ~35 處 `pass "$name (... unavailable ...)"`（多在 `test-doctor.sh` 的 jq guard、也有 `test-core-schemas`／`test-install`／`test-pmctl-memory`／`test-runtime-lib-coverage` 的 `UNAVAILABLE:` 裸行）改用 case-level `skip()`。primitive 與 authoritative gate 已於 pr:#<TBD> 落地並遷移 6 個代表站點；本票只做剩餘機械遷移，不再動 harness/runner/schema | ops/test | 2026-08-28 | — | P3 | hygiene |
| CC-578 | 🟢 someday | config-surface authority 標記（[[CC-446]] Req 6 拆出）：每份 manifest／schema／registry／policy／layout spec（~44 檔：19 `core/schema/*.json` + 20 `*.yaml` + 5 `core/policy/*.tsv`）標記為 `runtime authority`／`build-time authority`／`parity/documentation spec`；runtime／build-time authority 必須有單一 consumer/generator 路徑與 drift check，不得一面宣稱 source of truth 一面維護等價手寫實作。多為逐檔判斷、多數需新增 drift 測試，是獨立多 PR 工程；與 [[CC-451]] 同批評估（runtime 從不驗證的 schema 不列 stable） | process/DX | 2026-08-30 | — | P2 | design |
| CC-581 | 🟢 someday | `gate_reviewer_protocol_verify` 的二次方 `block=` 累加（`runtime/lib/gate-result-verify.sh:651`）：逐行 bash 字串串接抽 fenced reviewer_result 區塊，對區塊行數 O(n²)。[[CC-579]] census 實測 bash 端非 gate 主成本（88% 在 jq），故列次要未動。無感但屬演算法級劣化，值得在有人為別因動到該函式時順手換 O(n)（`mapfile`＋`printf` 或單次 `awk` 切檔），維持 fence 巢狀／截斷／空區塊失敗語意與 `GATE_REVIEWER_PROTOCOL_DOCUMENT_ERROR` 值不變。獨立排程投報不足 | ops/gate | 2026-09-08 | — | P3 | — |
| CC-592 | 🟢 someday | **[qa-tester 的 codex sandbox 結構性地無法啟動真實 Windows process，導致任何需要真實 process 驗證的 gate finding 卡住]** 兩次獨立 gate dispatch（sequential 90s bound、parallel 120s bound）中，qa-tester 嘗試重新執行一個會啟動真實 Windows Job Object supervisor 的測試時，兩次都在整個 timeout 期間**零輸出**後逾時（exit 124）——同一測試由本機（非 sandbox）直接執行 5 次以上皆在 10 秒內通過。訊號（完全零輸出，而非部分進度）與 #609（AppContainer 阻擋 MSYS2 對全域 namespace 的存取）、#619（codex Windows sandbox 決定性拒絕 exec_command）同一類，但這次發生在 **reviewer 驗證路徑本身**，而非 gate 的 producer 端。目前僅能靠 `.gate-overrides.md` 逐案記錄 accepted risk 繞過（2026-09-27 CC-590 gate 過程中發現，兩輪 gate 皆命中同一訊號）。 | ops/gate | 2026-09-27 | — | P2 | spike |
| CC-594 | ✅ closed 2026-10-02 | **[原生 Windows 上這台機器的 jq（WinGet 版）對任何非 TTY 的輸出（重導向到檔案、pipe、command substitution）都會自動加上 CRLF，不限 `-r` 模式，範圍遍布整個 repo]** 修 CC-593 時發現同一根因在 `tests/shell/test-core-schemas.sh` 造成 33 個測試失敗——多數是 `enum-sync` 類檢查：兩邊列印出來的值完全相同（例如 `schema enum: claude,codex,grok,opencode; yaml values: claude,codex,grok,opencode`）卻仍判定 FAIL，因為 `_schema_enum()` 的 `jq -r` 呼叫吐出的每一行列舉值都帶有看不見的尾端 `\r`。全 repo 掃描 `tests/`／`runtime/lib/`／`tools/lint/`／`tools/generate/` 下用到 `jq -r` 的檔案有 **64 個**；此機器沒有行為正常（純 LF）的 MSYS 版 jq 可以直接替換（僅有 WinGet 裝的原生版本，沒有 pacman/MSYS2 完整安裝）。範圍遠大於 CC-593 的四個獨立小修，需要一次性的架構決策（例如統一的 jq 包裝函式／全面補 `tr -d '\r'`／或改善 jq 安裝來源），而非逐一補丁。 | ops/test | 2026-09-28 | pr:#663 | P2 | spike |
| CC-602 | ⚠️ partial 2026-10-01 | **[context workflow-refresh 的 timeout-kill 有時會印出誤導的 `printf: write error: Permission denied`，而不是安靜結束]** GitHub issue #633；與 [[CC-596]] 相關但不是同一個問題（CC-596 只修暫存檔洩漏）。 | ops/portability | 2026-09-30 | pr:#653 | P3 | hygiene |
| CC-603 | 🟢 someday | **[`context.db` 永遠不會縮小：沒有 VACUUM／auto_vacuum，即使 #620 的 `.next` 症狀被正確 reconcile，肥大的 db 也維持肥大]** GitHub issue #636。 | ops | 2026-09-30 | — | P3 | hygiene |
| CC-604 | 🟢 someday | **[`gate-scope.sh` 收尾整理：collector 過大、三處「檔案內有哪些 symbol」讀取邏輯重複、fixed-head 模式仍有每來源固定次數的 fork]** CC-599 審查（architecture-reviewer／critic）提出但刻意不併入該 PR 的後續：`_gate_scope_expansions_collect_into` 拆成 shell consumer 與 symbol call-site 兩個 per-source emitter；tracked／untracked／shell consumer 三種「一個檔案內出現哪些 symbol」的讀取視需要共用 helper；fixed-head 模式下每個來源對 12 個副檔名各做一次 `git cat-file -e`、每個 consumer 一次 `git show`（CC-599 實測 fixed-head 剩餘成本）。 | ops/gate | 2026-09-30 | pr:#647 | P3 | hygiene |
| CC-606 | 🟢 someday | **[`awk -v wanted="$key"` 會處理反斜線跳脫，`--tier`／`--mode` 這類 CLI 值可通過 policy 驗證卻與 bash 字串比較不一致]** [[CC-600]] 的 security-reviewer 指出的既有問題（非該 PR 引入）：`awk -v` 會展開跳脫序列，因此 `--tier 'expre\163s'` 或結尾帶反斜線的 `express\` 會被 `_gate_assurance_policy_lookup` 視為 `express`，但後續 `[[ $TIER == express ]]` 之類的 bash 比較不會。需本機 CLI 控制權，不是提權，屬驗證正規化不一致。修法：改用 `ENVIRON` 傳值，或在 lookup 前拒絕含反斜線的 key。 | ops/gate | 2026-09-30 | pr:#649 | P3 | hygiene |
| CC-607 | 🟢 someday | **[worktree 主 checkout 解析與 drive-path 判斷的收尾整理]** [[CC-601]] 審查提出但刻意不併入的後續：`_pmctl_worktree_main_root` 與 `_sw_main_repo_root` 近乎重複，應讓前者委派給 state-paths 的解析器（或共用一個 helper）；`portable.sh` 內解析根目錄的 `case [A-Za-z]:/*` 分支與三處 jq regex 尚未統一，其中 `gate-result-verify.sh` 的 jq regex 只接受 `X:/`，`host-doctor-primitives.sh`／`hosts/claude/lib/doctor.sh` 接受 `X:[/\\]`；測試輔助 `tests/lib/test-memory-config-fixtures.sh` 與 `tests/shell/test-pr-gate.sh` 仍有 `--git-common-dir` 加 `== /*` 的寫法；common dir 不是 `<root>/.git`（submodule、`--separate-git-dir`）時 `dirname` 會回傳其父目錄（與 POSIX 相同，但在 Windows 上先前碰巧走 fallback 而答對）。 | ops/portability | 2026-09-30 | pr:#651 | P3 | reuse-debt |
| CC-608 | 🟢 someday | **[kill 時 context refresh 其餘寫入的 `write error`：辨識實際失敗的 fd，必要時才擴大保護]** [[CC-602]] 只靜音了 7 個 `$(...)` 內的 fallback `printf`，原始觸發條件未重現。其餘同一路徑上的寫入仍未保護：`pmctl_context_workflow_refresh_bounded` 的 `>&2` 進度行、`printf >> "$batch_sql"`、`_ctx_extract_symbols`／`_ctx_chunk_emit` 這類 `< <(...)` producer（CC-595 到 CC-598 之後是逐檔案的主要工作，critic 認為是現在最可能的殘留來源）、`pmctl-gate.sh` 等處的 `\|\| printf`。需要先重現（原生 Windows、`timeout -k` 殺受限 refresh，並以 `BASH_XTRACEFD` 或把 fd 1/2 導到已關閉的管線辨識失敗的 fd），再決定是 producer 的 `2>/dev/null`、子程序收到 TERM 後安靜退出，或移除剩餘逐檔案 `$(...)`。 | ops/portability | 2026-10-01 | pr:#653 | P3 | hygiene |
| CC-610 | 🟢 someday | **[lint：EXIT trap 處理函式（含其內部呼叫）所用的函式必須定義在 `trap ... EXIT` 之前]** [[CC-609]] 的缺陷型態可重現於任何提早安裝 trap 的 `set -u` 腳本，淺層檢查（只看 handler 名稱）會漏掉，因為 `qa_execution_finalize` 是從 handler 本體內被呼叫。需要追蹤 handler 本體的傳遞呼叫。架構審查建議記錄為後續而不放進 CC-609 的小修正。 | ops/test | 2026-10-01 | pr:#654 | P3 | hygiene |
| CC-612 | ⚠️ partial 2026-10-06 | **[`adapter_manifest_file` 每次呼叫都重新做 2 個 `$(cd -P && pwd -P)` 與 2 個 `adapter_manifest_scalar`，兩個 case 合計 37 次]** 同一份剖析（兩個 case 合計）：`adapter_manifest_file` 37 次、148 個行程；`adapter_manifest_runner_kind` 21 次、42；`adapter_manifest_dispatch_path` 7 次、35；合計約 225（約 6%）。呼叫端為 `executor-router.sh:84`／`:151`／`:155`／`:212` 與 `pr-gate.sh:548` 的迴圈。可行方向是依 `(repo-root, adapter)` 快取驗證結果，但該函式的 symlink／「不得逃出 adapters/」檢查是信任邊界，快取必須保留相同保證（例如以解析後路徑與 mtime 當鍵，或明確記錄「單次 gate 內快照」並由 security-reviewer 審查）。 | ops/gate | 2026-10-01 | — | P2 | hygiene |
| CC-614 | 🟢 someday | **[`gate-result-verify.sh` 的重複驗證占 pr-gate 行程數的約 23%，需要更細的剖析才能決定能否去重]** 同一份剖析（兩個 case 合計）：`gate-result-verify.sh` 各函式合計約 850 個行程（`_gate_reviewer_protocol_document_verify` 18 次 162、`gate_synthesis_protocol_verify` 6 次 144、`gate_reviewer_protocol_verify` 9 次 108、`_gate_reviewer_heal_empty_existing_evidence` 90、`gate_result_verify` 6 次 86 等），另有 `gate-structural-verify.sh` 的 `_gate_structural_schema_errors` 60 次（每次 `jq` 一次，`:32`）。`gate_result_verify` 在兩個 case 合計 6 次，是否有同一批檔案被重複驗證尚未查證。需先弄清楚各次驗證是否必要（不同階段、不同保證）或可共用一次解析，再決定是否去重；不得削弱驗證。 | ops/gate | 2026-10-01 | — | P3 | hygiene |
| CC-615 | ✅ closed 2026-10-03 | **[`pmctl gate run` 在 supervisor 因參數錯誤立刻結束時仍回報「detached」成功，錯誤只出現在 supervisor-stdout.log；Windows 的 `C:/…` 絕對路徑被 `--run-dir` 拒絕]** 2026-10-03 端到端 gate 實測（見 CC-594 S4 證據）：傳 `--run-dir C:/Users/…` 時 `pmctl gate run` 回傳 0 並印出「detached; check the verdict with: pmctl gate wait …」，約 20 秒後 `pmctl gate wait` 才得到 `state: failed exit: 2` 與「parent operation … could not be reconciled from trusted child evidence」，真正原因（`Error: --run-dir must be an absolute path: C:/Users/…`）只在 `runs/<id>/supervisor-stdout.log`。使用者要自己去翻 state store 才找得到。 | ops/gate | 2026-10-03 | pr:#665 | P2 | hygiene |
| CC-616 | ✅ closed 2026-10-03 | **[`pr-gate.sh --head <ref>` 搭配 `--test-cmd` 一定會在最後的 assurance 驗證失敗（preflight evidence 綁工作樹指紋、assurance 綁 fixed_ref 指紋），而且是在跑完整個 reviewer session 之後才失敗，沒有任何測試涵蓋這個組合]** 2026-10-03 實測：`pmctl gate run --head feat/CC-594-s4 --base main --test-cmd …`，reviewer 判 GO，但 `gate assurance linked preflight evidence subject claim mismatch`：preflight evidence 的 `subject` 是 `{kind: workspace, fingerprint_before: a0abe626…}`（`pr-gate.sh:2444`、`_preflight_tree_fingerprint`），assurance 的 `subject.tree_fingerprint` 是 `3326ccb0…`（`GATE_SUBJECT_KIND=fixed_ref`，`pr-gate.sh:1887`）。（2026-10-03 PR 審查後更正：先前寫「同一個 commit 指紋仍不同、與平台無關」說太滿。ref 不是目前 HEAD 時 preflight 測的是錯的程式碼，指紋當然不同；ref 就是目前 HEAD 且工作樹乾淨時，Linux 上兩個指紋相同，這次在 Windows 看到的差異來自 MSYS 把有 shebang 的追蹤檔回報成可執行，見 CC-619。）已修：在分派之前以 exit 2 拒絕。 | ops/gate | 2026-10-03 | pr:#664 | P2 | hygiene |
| CC-617 | ✅ closed 2026-10-03 | **[改到高扇出檔案（如 `tests/lib/test-harness.sh`）的 PR，其 qa-tester 補充測試會因 `run-tests.sh` 升級成 full suite 而在 reviewer 自選的 `--timeout 180` 內跑不完，被記成 timeout，reviewer 據此判 NO-GO；brief 完全沒說預算怎麼運作]** 2026-10-03 實測（第 3 次端到端 gate）：log 第 3 行 `escalating to full suite: high-fanout runner/install substrate changed: tests/lib/test-harness.sh`；evidence `attempt.status: timeout`、`timeout_seconds: 180`、`exit_status: 124`。**更正（原票有一半是誤診）**：原票說「codex sandbox 內 `/tmp` 暫存目錄不可寫」是錯的：`No such file or directory` 是 log 的**最後幾行**，發生在 180 秒 timeout 砍掉 runner、runner 的清理 trap 刪掉暫存目錄、而 `lint-pmctl-commands` 還在跑的那一刻；前三個 suite 在同一個 sandbox 的 `/tmp` 裡都寫入正常。180 秒不是 gate 或 QA rules 設的（repo 與 rules 中都找不到），是 reviewer 自己挑的。已修：brief 說明預算與 timeout 的意義、helper 的 log 註記、`run-tests.sh` 的升級訊息、契約文件。 | ops/gate | 2026-10-03 | pr:#667 | P2 | hygiene |
| CC-618 | ✅ closed 2026-10-03 | **[reviewer 寫出的結果檔以 UTF-8 BOM 開頭時，`gate_result_staging_normalize` 看不到第一行的 frontmatter 圍欄，`gate_result_version` 被數成 0，整個 run 以 `staging frontmatter must contain exactly one gate_result_version (found 0)` 失敗，沒有留下可驗證的結果]** 2026-10-03 實測（第 3 次端到端 gate）：reviewer 回報 `Final: NO-GO` 並寫了完整、合規的結果檔（`gate_result_version: pr_gate_result_v1`、`final: NO-GO`、reviewers、escalation 都在），但檔案的前 3 個位元組是 `ef bb bf`（沒有 CR）；成功的第 4 次結果沒有 BOM，所以 Windows 上的 Codex 是偶發地寫 BOM。（原票文寫「NO-GO 路徑缺 frontmatter、不確定是 gate 還是 reviewer 契約」；位元組證據顯示兩者都不是：是 gate 端的編碼容錯缺陷。）已修：normalizer 在解析前去除開頭的 BOM。 | ops/gate | 2026-10-03 | pr:#666 | P2 | hygiene |
| CC-619 | ✅ closed 2026-10-03 | **[原生 Windows 上 `working_tree` subject 指紋與 `fixed_ref` 指紋對同一個 commit 算出不同的值：`_gate_subject_tree_fingerprint working_tree` 用檔案系統的 `-x` 取執行位元，而 MSYS 把有 shebang 的檔案回報成可執行]** 2026-10-03 實測（HEAD 乾淨、ref = HEAD、`core.filemode=false`、`core.autocrlf=true`）：兩種指紋分別是 `fb1bc82e…` 與 `88fdae17…`；334 個 mode 100644 的追蹤檔中有 88 個在 MSYS 下 `-x` 為真（例如 `hosts/claude/lib/doctor.sh`、`hosts/codex/lib/hook-paths.sh` 這類帶 shebang 的函式庫），檔案位元組與 blob 相同（`git hash-object --no-filters` 一致，所以不是 CRLF）。目前只有 `--head <ref>` 會把兩種 subject 混用（已由 CC-616 拒絕）；預設 HEAD 的 `committed_head` 與 preflight 同用 `working_tree` 方法，所以一致（第 4 次端到端 run 的 `subject_current: pass`）。風險是日後任何把 ref 指紋與工作樹指紋比對的功能（例如 `pmctl ship` 重用 subject、驗證某個 ref 的 gate 結果）在 Windows 上會誤判不新鮮。 **已修**：`core.filemode=false` 時，tracked 檔案的執行位元取 index 記錄的 mode、untracked 檔案視為非可執行（plain `git add` 記錄的值）；`core.filemode` 為 true／未設時 manifest 逐位元不變（chmod 仍會改變 subject）。審查（五位）無阻擋，抓到並修了一個回歸：第一版對 untracked 檔案仍用 `-x`，新增的 shebang 檔案在 `git add` 前後指紋會變。行為變更：`core.filemode=false` 的主機上同一棵樹的 `working_tree` 指紋變一次，舊的 gate 結果要重跑。後續見 CC-627、CC-628。 | ops/gate | 2026-10-03 | pr:#670 | P3 | hygiene |
| CC-620 | 🟢 someday | **[`gate wait` 的失敗原因靠 grep supervisor log 取得，`gate status` 與 `pmctl ship` 看不到；改由 supervisor 在 sentinel 寫入結構化的 `failure_reason`]** CC-615 審查（architecture）指出：消費端 scrape log 是脆弱的契約；`gate-supervisor.sh` 本來就解析同一個 log 的 `result:`／`failure-result:` 並寫 sentinel（`final_state`、`exit_code`、`result_file`），是 `failure_reason=` 欄位的自然擁有者。log 也收子 session 輸出（可含被審查 repo 的內容），所以仍須去除控制字元與截斷。repo 中沒有 dispatch 的 `failure_reason` 先例。 | ops/gate | 2026-10-03 | — | P3 | hygiene |
| CC-621 | 🟢 someday | **[`pmctl gate run` 的 parent 端驗證還不涵蓋需要 policy 表或檔案的選項值：`--tier`、`--mode`、`--pass`（實測 `--tier bogus` 會啟動 detached gate 再失敗）、`--brief`、`--output`、`--policy-override`、`--reviewers` 的內容]** 長期做法（architecture 建議）：policy 模組提供「接受解析後的值並回傳狀態」的驗證入口，`pr-gate.sh` 與 parent 都呼叫。現況這些值仍在 supervisor 內失敗，由 CC-615 的「最後一個錯誤」行顯示。 | ops/gate | 2026-10-03 | — | P3 | hygiene |
| CC-622 | 🟢 someday | **[已發布的結果檔與 reviewer 輸出的讀取端幾乎都以「整行比對」解析（`^---$`、` ```reviewer_result_v1 `），Windows 寫的檔案若帶 CRLF 會讓它們失效；CC-618 只處理了 BOM]** CC-618 審查時指出：`gate-result-verify.sh`（`:85,107,223,571,802`）、`gate-assurance.sh:230`、`gate-result-read.sh:25,44`、normalizer 自己的 `^\+?---$`、`gate-reviewer-contract.sh:29` 的 `^```reviewer_result_v1$` grep 都是整行比對。在 Git Bash 的 gawk 上 CR 會被剝掉所以 CRLF 的 staging 檔可正常 normalize（兩位審查者各自驗證），但在 Linux／macOS 的 awk 上會以同樣的 `found 0` 失敗；實測的失敗 run 只有 BOM、沒有 CR，所以這是潛在風險，不是已證實的失敗。 | ops/gate | 2026-10-03 | — | P3 | hygiene |
| CC-623 | 🟢 someday | **[第 3 次端到端 gate 的 QA 證據記錄的 log 雜湊（`f4326af1…`）與封存後 log 的實際雜湊（`30d25053…`）不一致，原因不明]** CC-617 審查（critic）發現並由本機重算證實：`qa-execution-20261003-031431.json` 的 `attempt.log.sha256` 是 `f4326af1d03271022503a119320ea9eea03b74f4446a883ec2c665c5d5b4d9f7`，封存在 state store 的 log（1572 bytes，23 行）實際是 `30d25053c5c41af1e55a3f14bde8a59a40342c26bd67f71c8282bfb0ccc68fb2`（排除 CRLF）。候選原因：timeout 後殘存的子行程又寫入 log（`>` 截斷寫入的 stale offset）、或 gate 結束時 `relocate_gate_artifacts` 搬移／複製過程改動了檔案。目前沒有任何讀取端驗證這個雜湊，所以不影響判決，但證據的可驗證性是它存在的目的。 | ops/gate | 2026-10-03 | — | P3 | hygiene |
| CC-624 | ✅ closed 2026-10-03 | **[host 從不讀取 `qa_execution_evidence_v1` 的狀態：「non-authorizing」只是稽核檔案上的標籤，沒有任何驗證或判決邏輯使用它]** CC-617 審查（security、critic）指出：`gate-result-verify.sh` 與 `gate-assurance.sh` 都不讀 `qa-execution-*.json`；沒有設 `--test-cmd` 時，QA reviewer 的判斷是唯一的測試證據，變更造成的卡住（也是 timeout）可以被報成缺口而放行。已修：沒有通過的 pre-flight 時，`pr-gate.sh` 拒絕發布 `Final: GO`，除非 QA 證據恰為 `completed` 或 `not_run`（`inconclusive`、遺失、symlink、無法解析都拒絕；exit 1、failure-result、Final 行改為 INCOMPLETE、無 sidecar、無 `result:`）；helper 在任何一次 timeout 後維持 `inconclusive`。審查（五位）無阻擋，修了：最後一個指令決定狀態導致 timeout 後接 `true` 可繞過、證據檔不可讀時 fail-open、保留的結果仍寫 GO、錯誤訊息缺出路。未做的部分見 CC-626。 | ops/gate | 2026-10-03 | pr:#669 | P2 | hygiene |
| CC-625 | 🟢 someday | **[qa-tester 仍可無視 brief 的預算說明而選 `--timeout 180` 搭配 full-suite 命令；需要決定性的預算機制]** CC-617 的 brief 指引是模型行為，不能保證。risk 審查建議的選項：helper 匯出剩餘 session 預算（例如 `PM_RUN_TESTS_BUDGET=<秒>`），`run-tests.sh` 在預算太短時拒絕升級並以非零離開、印出 suite 數量；或對高扇出的 diff 由 gate 自己把完整測試放進 pre-flight。architecture 反對在 helper 內夾住或縮放 `--timeout`（會悄悄改變模型選定的命令契約與記錄的 `timeout_seconds`）。 | ops/gate | 2026-10-03 | — | P3 | hygiene |
| CC-626 | 🟢 someday | **[QA execution 證據只在發布時被強制：assurance 沒有記錄它、沒有逐次歷史、發布後沒有摘要綁定]** CC-624 審查（architecture、security、critic）留下的後續：(1) assurance sidecar 沒有 QA execution 的狀態與雜湊，`pmctl gate verify` 事後無法證明 GO 沒有建立在 inconclusive 證據上（較舊的 `pr-gate.sh` 或手改的副本無從區分）→ 把 `evidence.qa_execution {status, artifact, sha256}` 放進 assurance，規則改成 lib 內的共用判斷，由 pr-gate 與 verify 共用；(2) 拒絕時改成寫 `Final: INCOMPLETE` 並以 exit 3 發布一份驗證過、不具授權的結果（與 pre-flight 的 INCOMPLETE 一致），而非 exit 1 加 failure-result；要先確認 synthesis 驗證器接受事後改寫 Final；(3) helper 保留逐次歷史（attempts 陣列），讓「中間失敗、最後通過」可見，也能把 nonzero 與 timeout 分開處理；(4) 證據檔在 dispatch 後做摘要綁定（reviewer 產物已有 TAMPERED_ARTIFACTS 檢查）；(5) symlink 的情況目前有處理但沒有測試（Windows 主機上 symlink 不可靠）；(6) 拒絕次數沒有計數器或 run-stats 欄位，無法量測誤判率。 | ops/gate | 2026-10-03 | — | P3 | hygiene |
| CC-627 | ✅ closed 2026-10-04 | **[subject 指紋在 `git ls-files` / `git ls-tree` 失敗時被靜默吞掉：manifest 變空，指紋變成「空 manifest」的固定值]** CC-619 審查（security）指出：`_gate_subject_tree_fingerprint` 用 process substitution 讀 git 輸出（`fixed_ref` 的 `ls-tree`、`committed_head`／`working_tree` 的 `ls-files`），git 失敗（`safe.directory`／所有權錯誤、損壞的 index）時迴圈不執行、結束碼被丟掉。若攻擊者讓 git 在綁定與驗證時都以同樣方式失敗，指紋不綁任何東西。既有問題（舊程式相同），CC-619 的新分支多了第二個輸入來源（`--stage` 與 `--others` 其一失敗時 tracked 檔案消失而 untracked 仍在）。修法：讀入暫存檔並檢查 git 的結束碼，失敗就 return 2；加測試（git 以失敗取代時指紋函式回非零，不是固定值）。 **已修**：每個 git 清單先寫入暫存檔並檢查結束碼，失敗時回 2 且不輸出；stderr 印一行含 git 原因的訊息；manifest 一開始就建立，合法的空清單仍是有效指紋（含 pipefail 下）；最後的 sort 與摘要不再依賴呼叫端的 pipefail，並要求結果為 64 位十六進位。正常 git 下指紋逐位元不變（含本 repo 實測）。審查（五位）無阻擋，抓到並修了我第一版的回歸：空清單在 pipefail 下會失敗。同類問題的清查見 CC-629。 | ops/gate | 2026-10-03 | pr:#671 | P2 | hygiene |
| CC-628 | 🟢 someday | **[`core.symlinks=false` 時 tracked 的 120000 項目在磁碟上是普通檔：`working_tree` 以 file 雜湊、`fixed_ref` 以 symlink 雜湊，兩者仍不同；skip-prefix 與 symlink-as-file 沒有判別性測試]** CC-619 審查（critic、qa-tester）發現：與 exec-bit 無關的另一種 Windows 偏差（既有）；變異「移除 skip-prefix 清單」與「symlink 當普通檔」目前都存活。另可考慮在 assurance 記錄非雜湊的 `subject.mode_source`（值為 filesystem 或 index），讓驗證者知道指紋依哪條規則產生（security 與 architecture 建議；不進 manifest 以免改變所有 Linux 指紋）。 | ops/gate | 2026-10-03 | — | P3 | hygiene |
| CC-629 | ✅ closed 2026-10-04 | **[gate 完整性輸入中還有同樣「吞掉 git 結束碼」的寫法：scope digest、dirty 檢查、dispatch 前後雜湊]** 三組都已完成：(a) PR #672：`gate-scope.sh` 的 `_gate_policy_scope_content_digest` 與 `_gate_scope_changes_collect` 在 git 失敗時回 2、不輸出（舊版在呼叫端沒有 pipefail 時，連 tracked 的 `git diff` 失敗都照樣產生摘要，未知的 diff 模式也回成功）；(b) PR #673：`pmctl-ship.sh` 的 dirty 檢查（`ship finish` 的三個發布保護點、dispatched lane 的兩次狀態讀取、`ship prepare`）原本把「git status 失敗」讀成「乾淨」，現在拒絕並帶出 git 的訊息；(c) PR #674：摘要原語 `gate_digest_stream`／`gate_digest_file` 在工具失敗時原本回空摘要加 0（約 35 個寫成「失敗就 return」守衛的呼叫端因此從未生效，CC-611 的測試把它釘成「更動時要有意識」的契約），現在回 2 且不輸出，兩種模式都適用；`fixed_ref` 的 blob 摘要改走檔案；`gate_subject_snapshot` 在 git 失敗時回 2；`_worktree_is_dirty` 把失敗的列表視為 dirty；closure 的 `artifact_sha256`、`ship` 的 lane id、QA attempt 腳本的摘要 helper 不再記錄空值。**一次更正**：`pr-gate.sh` dispatch 前後的雜湊本來就在最上層的 `set -euo pipefail` 下 fail-closed（靜默），原票說它們會「雜湊相等而失效」是錯的；只加了訊息。刻意沒做：抽出共用的 `gate-git.sh`（要動安裝清單、bootstrap 迴圈、按清單複製 lib 的夾具、高扇出分類與登錄，而兩個 helper 只有一對使用者），改列 CC-633（附觸發條件）。剩餘的後續在 CC-630、CC-631、CC-632、CC-634。 | ops/gate | 2026-10-04 | pr:#674 | P2 | hygiene |
| CC-630 | 🟢 someday | **[scope 擴充搜尋（`git grep`）失敗時被當成沒有結果，reviewer 看到的相關檔案默默變少]** CC-629 (a) 審查（architecture、critic）留下：`_gate_scope_search_paths`、`_gate_scope_symbol_hits_collect`、`_gate_scope_symbol_hits_fallback` 用 `git grep` 加上為了「沒有符合」結束碼 1 而加的 true 後備，會一併隱藏真正的錯誤（rc 大於等於 2，例如 fixed-head 的 commit 取不到時是 128）；結果又經 process substitution 與 mapfile 傳遞，狀態傳不出來；這段程式碼是 CC-599 為 Windows 效能調校過的。擴充只是 reviewer 的提示與可引用證據（manifest 宣告為 bounded-hints-not-complete-call-graph），不是綁定，所以建議的形狀是**不讓 gate 失敗**：沿用現有的截斷機制，在 `reasons_json` 加 `expansion-search-unavailable`，使狀態成為 incomplete（除非 `--accept-scope-truncation`），讓失敗可見、可覆寫、有記錄；rc 0 與 1 視為正常，rc 大於等於 2 視為不可用；搜尋函式改寫到呼叫端提供的檔案並回傳狀態（檔案重導不增加 fork 數）。另含：`git diff` 加 `--no-ext-diff --no-textconv` 的加固（會改變有 textconv 或外部 diff 驅動的使用者的位元組，需評估）、暫存目錄在 SIGINT 或 TERM 時外洩（`gate_digest_file` 在工具失敗時回空摘要的項目已由 CC-629 (c) 修掉）。 | ops/gate | 2026-10-04 | — | P3 | hygiene |
| CC-631 | 🟢 someday | **[git 失敗注入的測試夾具在五個 suite 各有一份：抽成 `tests/lib/git-stub.sh`]** CC-627、CC-629 (a)(b) 的測試都在 PATH 最前面放一個 git 替身，讓指定的呼叫失敗（`SUBJECT_STUB_*`、`SCOPE_STUB_*`、`PM_TEST_STATUS_*`、`CC629_*`，另有 test-pmctl-ship.sh 內嵌的一份），每份各有自己的環境變數詞彙與計數方式。architecture 建議：`git_stub_install <dir> <match-expr> [--fail-at N] [--partial]`，先於 PATH 變動解析真正的 git 並存在替身專用的變數，計數器放在 `<dir>`，提供 `git_stub_calls <dir>` 給 log 斷言，支援精確參數比對與 token 子字串比對，並支援「從第 N 次起持續失敗」。遷移會動到 test-gate-scope、test-pmctl-ship-finish、test-pmctl-ship、test-pr-gate，以及選擇性複製 `tests/lib` 的夾具與環境變數清冊；不再依賴 gate-git.sh 的抽取（該抽取已改列 CC-633），不要塞進 bugfix PR。 | ops/gate | 2026-10-04 | — | P3 | hygiene |
| CC-632 | 🟢 someday | **[ship 與 pr-gate 的 git 狀態讀取還有幾個既有的小缺口（建議性）]** CC-629 (b) 審查（security、critic）留下，皆不是這次引入、皆低風險：(1) `_pmctl_ship_worktree_status` 排除完成標記用的 `:(exclude).pm-dispatch-ship-finish.json` 是前綴 pathspec 而不是精確檔名，同名的**目錄**會把裡面的未追蹤檔案從 `status` 藏起來（指紋只略過精確檔名，所以最後一個保護點仍會抓到），註解「只排除那個精確路徑」不準確；改成不加 pathspec、在 shell 過濾精確那一行；(2) 指紋與注入檢查的讀取沒有固定 `--untracked-files=all --ignore-submodules=none` 與 `-c core.fsmonitor=false`，能寫 `.git/config` 的 session 可用 `status.showUntrackedFiles` 遮蔽自己的變更（但能寫 `.git/config` 本來就能透過 `core.fsmonitor` 或 hook 執行程式碼，不是新的信任邊界）；(3) dirty 檢查用 `-- .` 限定在 work_dir，若 work_dir 是 repo 的子目錄，外面的變更看不見（lane 都是 worktree 根目錄，可能無法觸發）；(4) `ship finish` 與 `prepare` 的 `git status` 失敗訊息帶 git 的第一行，但 pr-gate 的注入檢查訊息只指出階段與指令，沒有 git 的原因（stderr 被丟掉）。 | ops/gate | 2026-10-04 | — | P3 | hygiene |
| CC-633 | 🟢 someday | **[抽出共用的 `runtime/lib/gate-git.sh`：`_gate_scope_git_to_file` 與 CC-627 的 `_gate_subject_git_listing` 幾乎相同]** CC-629 (a)(b)(c) 審查（architecture）的結論：**暫不做**，因為要動安裝清單、`pr-gate.sh` 的 bootstrap 迴圈、按清單複製 `runtime/lib` 的測試夾具（test-gate-lifecycle、test-pr-gate-profile）、`tests/bin/run-tests.sh` 的高扇出分類與測試登錄，而目前只有 scope 與 subject 兩個 helper 這一對使用者（CC-629 (b)(c) 的修法都是在原處檢查狀態，沒有重用 helper）。**觸發條件**：出現第三個同形態的使用者，或開始做 CC-631。屆時的形狀：`gate_git_to_file <out> <git-args...>`，呼叫端自己傳 `-C`，訊息帶呼叫者名稱，成功時轉送 git 的警告，失敗時回 1 並印 git 的 fatal 或 error 行；guard 以新函式名稱判斷（混合安裝）；不要放進 `gate-digest.sh`。 | ops/gate | 2026-10-04 | — | P3 | hygiene |
| CC-634 | 🟢 someday | **[`gate-digest.sh` 的兩種模式各有一份工具探測：合成單一 `_gate_digest_select`]** CC-629 (c) 審查（architecture）：`gate_digest_init` 與 `_gate_digest_stream_probe` 各有一份「sha256sum 優先、shasum -a 256 次之」的 `command -v` 加 `printf ''` 管線的探測，靠「keep in step」註解維持一致；可合成一個設定變數的選擇函式。收益小（逐次路徑存在就是為了保留舊的成本結構），等下次動到 `gate-digest.sh` 時順手做。 | ops/gate | 2026-10-04 | — | P3 | hygiene |
| CC-636 | 🔵 active | **[Windows 上 `tests/shell/test-doctor.sh` 每個案例約 45 秒，整個檔案一小時以上，單次本機驗證跑不完]** 2026-10-06 量測：取樣 4 個案例 46／81／43／44 秒，原因是每次 `doctor.sh` 的固定成本，不是單一案例卡住。追蹤一次執行：`check_frontmatter_lint` 約 8.6 秒（每個案例都對真實 repo 跑一次 `tools/lint/lint-frontmatter.sh`，與案例要測的內容無關）、`check_parent_operations` 加 `check_usage_tracker_path` 約 4 秒、`host_manifest_scalar` 每次逐行重讀 6 到 7 KB 的 `host.yaml`（一次執行約 280 次、約 6.4 萬次迴圈）。對本機真實狀態（302 筆 run 紀錄）直接跑 `doctor.sh` 300 秒仍未結束，推測 `check_detached_runs` 對每筆紀錄各做一次程序探測，尚未逐筆驗證。 | ops/test | 2026-10-06 | — | P2 | hygiene |
| CC-637 | ✅ closed 2026-10-08 | **[`adapter_manifest_*` 對同一份 manifest 重複驗證：`dispatch_path` 內部呼叫 `adapter_manifest_file` 約 5 次，原生 Windows 上單次 1.7 秒；guard hook 因此每次呼叫 5.3 秒]** 2026-10-06 對 `guard-executor-write.sh` 單次呼叫追蹤：`adapter-manifest.sh` 約 2.3 秒（`dispatch_path` 1.76、`effective_route` 0.71、`runner_kind` 0.37、`file` 0.28 秒），`guard-framework.sh` 約 1.35 秒（4 次 jq，0.1 到 0.45 秒）。同一份 manifest 被驗證多次，每次是兩次 `cd -P` 加 `pwd -P` 與兩次逐行讀檔。這也是使用者實際感受到的寫檔 guard 延遲，不只是測試成本。 | ops/portability | 2026-10-06 | — | P2 | hygiene |
| CC-638 | 🔵 active | **[原生 Windows 上的測試太慢：單次外部程序約 64 到 100 毫秒，一次 `dispatch run` 約 320 次啟動，逐一優化每批只能省 3% 到 10%；改在 WSL2 跑，大測試檔快一個數量級，小的約 3 倍]** 2026-10-06 量測：`pmctl dispatch run` 單次 64 秒，其中外部程序約 32 秒，平均每次約 100 毫秒，分散在幾十個呼叫點，沒有單一大頭（PowerShell ACL 檢查 8 次約 5.5 秒最大）。同樣的測試在 WSL2（只算測試本身，每次呼叫另加約 6 秒同步；單次量測）：`test-lint-frontmatter` 2 到 3 對 27 秒、`test-executor-router` 4 對 34 秒、`test-state-status` 17 對 62 秒（Linux 上 23 過 0 失敗，Windows 上有 1 個 NTFS 失敗，兩邊的工作不完全相同）、`test-guards` 整份 110 秒（Windows 超過 10 分鐘）。小測試檔加上同步後只快約 3 倍，大測試檔才有一個數量級的差距。 | ops/portability | 2026-10-06 | — | P2 | hygiene |
| CC-639 | 🔵 active | **[`pmctl worktree`、`artifacts`、`ship` 沒給 `--cd` 時操作的是 `cli/pmctl` 所在的 pm-dispatch checkout，而不是目前所在的 repo]** GitHub issue #677：從另一個專案執行 `pmctl worktree create fix/x` 會在 pm-dispatch 裡建分支與 linked worktree。原因是 `cli/pmctl` 把 `"$REPO_ROOT"`（函式庫的來源）同時當作 `repo_root` 傳入，各庫在 `--cd` 為空時把 `work_dir` 退回 `repo_root`；`commands/using-git-worktrees.md` 的約定是 `--cd` 指向「目前目錄以外」的 repo，缺省就是目前目錄（與 `pmctl artifacts`/`pmctl dispatch` 同一慣例）。在 WSL 實測確認：`worktree create` 的分支建在 install repo（install 1、目前 repo 0）、`worktree list`/`artifacts list`/`ship status` 看的是 install repo 的登記，`ship prepare` 回「no such ticket」。 | DX | 2026-10-08 | — | P1 | hygiene |
| CC-640 | 🟢 someday | **[`pmctl artifacts gc`、`worktree gc/remove` 在不是 git repo 的目錄且沒有 `--cd` 時會靜默落到共用的 `global` 分區；gate、pm、portable 各有一份相同的「git 根目錄否則 `$PWD`」推導]** CC-639 審查（security、critic）指出：缺省改成目前目錄後，從 `~` 或 `/tmp` 執行 `artifacts gc` 會對 `projects/global/runs`（所有在 git repo 外的 dispatch 與 gate 執行）套用保留規則，沒有「不在 repo 內」的錯誤；同一個行為用 `--cd` 指向非 repo 目錄本來就可達，缺省讓它更容易誤觸。另外 `_pmctl_gate_default_cd`（pmctl-gate.sh）、`pmctl_pm_default_cd`（pmctl-pm.sh）與 CC-639 新增的 `portable_default_work_dir` 是同一個推導的三份副本，統一前要先確定各庫單獨載入時能取得共用函式。 | DX | 2026-10-08 | — | P3 | hygiene |

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

**Done-when**：在 v0.11.0 release candidate 上，三個 smoke 的實測報告 committed（`docs/notes/` 或票內）；clean install 與 N-1 upgrade 都有可重現證據——**已達成**；摔倒點全部開票——offline smoke 摔倒點已開 [[CC-580]]；GETTING_STARTED 修正到與實測一致——**尚未做**；live dogfood 完成——**待 readiness review**。

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

## CC-594 — 原生 Windows 上 jq 對任何非 TTY 輸出都加 CRLF，範圍遍布全 repo ✅ 2026-10-02

**Problem**：修 [[CC-593]] 時發現，這台機器上安裝的 jq（WinGet 版
`jqlang.jq`）只要輸出目的地不是終端機（重導向到檔案、進 pipe、被
command substitution 捕捉），就會自動把每一行的 `\n` 換成 `\r\n`——不限
`-r`（raw output）模式，`jq -S .`（一般 JSON 輸出）一樣會發生。這是
Windows C runtime「文字模式」stdout 的典型行為，不是 jq 本身的邏輯 bug。

**已確認範圍**：`bash tests/shell/test-core-schemas.sh` 單獨執行出現 33 個
失敗，多數是 `enum-sync` 類檢查——兩邊印出來的值完全相同（例如
`schema enum: claude,codex,grok,opencode; yaml values: claude,codex,grok,opencode`）
卻仍判定 FAIL，因為 `_schema_enum()` 的 `jq -r` 呼叫吐出的每一行列舉值都
帶有看不見的尾端 `\r`，讓字串比對必然失敗。全 repo 掃描
`tests/`／`runtime/lib/`／`tools/lint/`／`tools/generate/` 下用到
`jq -r` 的檔案有 **64 個**，尚未逐一確認各自是否真的受影響（有些可能是
單純顯示用途、無精確字串比對，不受影響）。

**已確認的限制**：此機器沒有行為正常（純 LF）的 MSYS 版 jq 可以直接替換
——只有 WinGet 裝的原生版本，沒有 pacman／完整 MSYS2 安裝，所以不存在
「換一個 binary 就整批解決」的捷徑。

**Requirement（尚未決定修法方向，需要架構決策）**：
1. 盤點 64 個檔案裡，哪些 `jq -r`／`jq` 呼叫的輸出實際會進入精確字串比對
   （如 `cmp`、`[[ == ]]`、逐行 diff），哪些只是顯示／人類閱讀用途、CRLF
   不影響正確性。
2. 補 regression：`test-core-schemas.sh` 的 `enum-sync` 案例轉綠（見下方實測：
   33 個失敗中 11 個是 CRLF，另 22 個是缺少 `jsonschema` CLI，與本票無關）。

**2026-10-02 spike 結果與決定（方案 A）**

*已實測的事實*（jq 1.8.1 WinGet 原生版）：
- `jq -b`（`--binary`，jq ≥ 1.6；`docs/platform-support.md` 本來就要求 ≥ 1.6）讓輸出
  變成純 LF，JSON 輸出（`-S .`）也一樣。本票原文「不存在換 binary 的捷徑」不成立。
- 影響的**不只是顯示**：`jq -cS . | sha256sum` 加與不加 `-b` 分別是 `fdd1d186…`／
  `157b4d1b…`，後者等於 Linux 的值，所以 Windows 上算出的 gate 摘要與 Linux 不相容。
  文件記載的 Windows 安裝就是這個原生 jq（`winget install jqlang.jq`），不是邊角案例。
- 受影響的形狀是**多行**輸出（`$(...)` 內、`while read`）；單行 `$(jq -r ...)` 不受影響。
- 輸入端（同一台機器、同一版 jq 實測；加 `-b` 前 → 後）：`jq -R` 與 `jq -Rs` 讀 stdin（管線或
  重導向）：`\r` 被吞掉 → **保留**（與 Linux 相同）；`jq -Rs 檔案`、`jq -R 檔案`、`--rawfile`、
  JSON 輸入：不變（檔案讀入兩邊都吞掉 `\r`）。**2026-10-02 S3 更正**：S1 當時記成「`-Rs` stdin
  不變、`-Rs 檔案`／`--rawfile` 由保留變吞掉」，是量測時把輸出端的 CRLF 轉換誤判成輸入端行為；
  S3 改用「數 jq 實際看到的 CR 字元」和「輸出 JSON 字串顯示 `\r`」兩種方法重量，結果如上。既有
  Windows 使用者的 jsonl 狀態檔是舊版 jq 寫出的 CRLF（但經 `$(jq -c ...)` 再 `printf '%s\n'`
  寫入的共用日誌本來就是 LF）。
- 函式 `jq(){ command jq -b "$@"; }` 對同 shell、`export -f` 的子 bash 有效，對 `env -i`、
  `timeout jq`、`xargs jq`、`env jq` 無效；全 repo 以「程式」形態呼叫 jq 的只有 2 處且都在
  測試。PATH 包裝腳本每次呼叫多一次 bash 啟動（約 40 ms），不採用；`BASH_ENV` 會洩漏到所有
  子行程，不當主要手段。
- 盤點：34 個函式庫 + 36 個非測試入口腳本呼叫 jq；其中 22 個不 source 任何共用函式庫
  （獨立 hook、ops、tools、hosts/*/lib/doctor.sh），hook 可能被 `link_or_copy` 以複製方式
  安裝，不能依賴相對路徑 source。

*決定*：函式 shim，只在 `OSTYPE` 為 msys／cygwin **且 PATH 上真的有 jq** 時定義
（`PM_DISPATCH_JQ_LF=1|0` 可覆寫平台判斷）；`runtime/lib/jq-lf.sh` 定義、載入時不啟動任何
行程；**不改 `portable.sh`**（它的契約是 source 不改變呼叫端 shell 政策）。有 repo 版面的
腳本 source 該檔；獨立腳本改用逐字相同的兩行內嵌片段（見 `jq-lf.sh` 檔頭；片段只看 `OSTYPE`，
不看 `PM_DISPATCH_JQ_LF`）。**「PATH 上沒有 jq 就不定義」是審查（5 位獨立審查者一致）抓到的
必要條件**：否則 `command -v jq` 永遠成功，約 30 處「jq 是否存在」的前置檢查
（`pr-gate.sh:381`、`g_require_jq`、`pmctl-state/task/trace/decision/guard` 等）全部失效，缺 jq
時只會在執行中途得到 127。函式存在時 `command -v jq` 只印出 `jq`，取程式路徑須用
`type -P jq`。**不加 `export -f`**：hook 由 host 啟動、本來就需要內嵌片段，`export -f` 只省
pmctl 派生子行程那一部分的編輯，且過不了 `env -i`／`timeout`／`xargs`。

*切片*（每片一個 PR）：
1. **S1**（pr:#660）：`jq-lf.sh` + 單元測試（假 CRLF stub、參數／stdin／離開碼原樣傳遞、
   在全新 bash 程序中量測「載入無行程、不改選項、不留輔助函式」、無 jq 時不定義、與 Linux
   相同的摘要）+ 接線測試（`th_init`；`cli/pmctl` 與 `pr-gate.sh` 以 `bash -x` 觀察 source）+
   接上 `cli/pmctl`（`-r` 保護，精簡 fixture 不必補檔）、`pr-gate.sh`、測試 harness + 把以
   `command -v` 取 jq 路徑的測試改成 `type -P`、把在行程內用清空 PATH 模擬「沒有 jq」的測試
   加上 `unset -f jq`。
2. **S2**（已完成，pr:#661；實作時加片段的腳本是 44 個，不是估計的 22 個，
   因為傳遞性 source 閉包把 guard hook、安裝／解除安裝入口、`doctor.sh`、`pmctl-context.sh` 與 5 個
   測試／runner 腳本也納入；全部加了逐字相同的片段，`lint-jq-lf` 與其 17 案例測試、census 的
   `type -P` 修正與測試皆已合入；審查補強：偵測 `if jq`／`command jq`／裸字引數等呼叫形式、
   `"$d/lib-$x.sh"` 這類部分動態 source 視為動態、沒有 +x 的腳本也算入口、`dispatch-supervisor.sh`
   的動態載入迴圈原本漏網、其餘三個可執行位元函式庫改以 `jq-lf-exemptions.tsv` 豁免而非各塞一份片段）：22 個獨立入口加片段、其餘入口 source；新增 lint 與其測試（含變異：移除任一入口
   會被抓到）。lint 規則要看**傳遞性的 source 閉包**，不是只看「本身呼叫 jq 的腳本」（一個本身
   不呼叫 jq、但 source 了 `guard-framework.sh` 的 hook 否則會漏網）；snippet 要逐字比對。
   自成一體、不呼叫 `th_init` 的 9 個測試套件也要處理。把 snippet 放進 guard hook 前，須確認
   其「jq 缺失就失敗關閉」路徑仍然有效（`type -P jq` 條件已保證）。
3. **S3**（已完成，pr:#662；逐站結果見下方「S3 審查結果」）：審查逐行讀可能含 CRLF 資料之處並讓它們容忍 CR（`rtrimstr("\r")` 放在
   `select(length>0)` 之前）。範圍依 **grep 結果**，不是估計值：非測試檔中約 20 個檔案出現
   `jq -R`（含 `hosts/claude/hooks/log-usage.sh`、`ops/usage/token-usage.sh`、
   `runtime/lib/dispatch-record.sh`）；`-R`（非 `-s`）讀 stdin 是行為改變的那一類，stdin 的
   `-Rs … split("\n")`（`gate-policy.sh:288`、`pmctl-artifacts.sh:402`、`pmctl-task.sh:64`、
   `pmctl-dispatch.sh:546`）兩邊都保留 `\r` 但仍須確認，`-Rs 檔案`／`--rawfile`（行為改變為
   吞掉 `\r`）也要看；另有使用者提供的 slug 經 `jq -R .`（`pmctl-worktree.sh:157`）。目前餵入
   的資料多半是 LF。已知風險：空的 CRLF 行（`\r`）會通過 `select(length>0)` 再 `fromjson`
   失敗，使 `pmctl-gate-stats.sh:189` 把它算成損毀行並標記歷史不完整。這台機器上唯一的 CRLF
   jsonl 是 `~/.pm-dispatch/usage-tracker.jsonl`（由尚未轉換的 `hooks/log-usage.sh` 寫入，pmctl
   不用 `-R` 讀它）。評估是否移除 [[CC-593]] 留下的 `| tr -d '\r'`。
4. **S4**（已完成，pr:#663；本票隨此片關閉，結果見下方「S4 結果與 Windows 實測證據」）：Windows 實測證據、CHANGELOG、關閉本票。可一併評估：`doctor.sh` 加一行 shim 檢查
   （`$(jq -n -r '"a","b"')` 應恰好是 `a\nb`，並顯示 `type -P jq` 與旋鈕值）、摘要不符的錯誤
   訊息加「用舊版產生的產物請重跑 gate」提示（`gate-result-verify.sh:137,1897,2027`）、一個
   強制啟用 shim 的 Linux CI 組態（`th_init` 會清掉旋鈕，需要不被清除的方式；用於抓出 PATH
   stub 檢查 `$1` 而收到多出的 `-b` 這類只有 Windows 看得到的問題）。

*S4 結果與 Windows 實測證據*（2026-10-02，jq 1.8.1 WinGet，本機 Git Bash）：
- **`doctor.sh` 的 `jq-line-endings` 檢查**（只在原生 Windows 執行）：實機輸出
  `[OK] jq writes LF line endings (<jq 路徑>; PM_DISPATCH_JQ_LF=auto)`；用會回 CRLF 的 jq stub 得到警告
  與修法；平台為 linux 時不出現。測試 `doctor-jq-line-endings-check`（移除平台判斷的變異會被抓到）。
- **摘要不符提示**：只加在「由 `jq -cS` 輸出算摘要」的兩處比對失敗（`gate_scope_manifest_verify` 的
  內容摘要、protected attestation 的 `subject_sha256`）；`:137`、`:2027` 是對檔案位元組取 sha256，
  不因本票改變，所以不加。提示經 `detect_platform` 判斷（尊重 `PM_DISPATCH_PLATFORM`），只在
  Windows 出現。attestation 那一處審查後縮小：只有「subject 摘要確實不符」才提示，其他被認證值
  （result sha、assurance sha、repo、run id）不符不提示，避免把真正的竄改訊號說成升級問題。兩處的
  接線都有不需 JSON-schema 驗證器的測試（`test-gate-scope-manifest-verify.sh`，這台機器與 Linux
  都能跑；移除呼叫、改成無條件提示、移除平台判斷的變異都會被抓到）。
- **強制啟用 shim 的 Linux CI**：`PM_DISPATCH_TEST_FORCE_JQ_LF=1`（庫存為 test-config、不被清除）讓
  `th_init` 匯出 `PM_DISPATCH_JQ_LF=1`；CI job `test-jq-lf-forced` 以它跑 11 個讀／stub／摘要 jq 輸出
  的套件。行內片段只看 `OSTYPE`，所以這條腿涵蓋的是函式庫路徑（pmctl、pr-gate、`th_init`），不含
  獨立腳本。
- **Done-when 逐項**：`test-core-schemas` 138 過／22 敗，`enum-sync` 失敗 0（S1 前 127／33、其中 11 個
  是 CRLF）；其餘 22 個需要 JSON-schema 驗證器（python `jsonschema` 模組與 CLI 都沒裝），與換行無關。
  摘要與 Linux 已知向量一致：`test-jq-lf` 的 real-jq 案例（`jq -cS .` 的 sha256 等於 Linux 值；無 `-b`
  時是 `fdd1d186…`、有 shim 時是 `157b4d1b…`）與 `test-gate-digest` 13／0、`test-gate-assurance-verify`
  17／0、`test-gate-scope-manifest-verify` 11／0、`test-gate-structural-verify` 16／0、`test-gate-policy`
  22／0；`tier-detection` 與 `standard-tier-detection` 兩個 pr-gate 案例通過（118 s）；CHANGELOG 已說明
  Windows 摘要的一次性變動（S1 條目的 Behavior changes）。`pmctl gate`／`pr-gate.sh` 的端到端結果見下方「端到端 gate 實測」。
- **關閉當下尚未驗證的部分**：新的 CI job `test-jq-lf-forced` 從未在 Linux 跑過（這台機器的 shim 本來就開著，
  強制旋鈕量不到新東西），以該 PR 的 CI 結果為準；它會跑完全部 11 個套件再列出失敗者，不會因第一個失敗而遮住
  其餘。端到端 gate 已在 2026-10-03 實測（見下方「端到端 gate 實測」）：第 4 次跑通並通過驗證，前 3 次的失敗已拆成 CC-615～CC-618。
- **仍存在、已記載的限制**：以「程式」形態啟動的 jq（`timeout 5 jq`、`xargs jq`、`find -exec jq`）繞過函式；
  lint 檢查「有載入」而非「在第一次 jq 呼叫之前載入」；`dynamic-ok` 的理由是審查過的宣告而非證明。

*端到端 gate 實測*（2026-10-03，原生 Windows、jq 1.8.1、shim 生效，使用者明確要求；`pmctl gate run --executor codex
--tier standard --mode sequential --base main --test-cmd "bash tests/shell/test-jq-lf.sh"`，前景逐次等待，
可用記憶體約 3.4–3.9 GB 未出現記憶體壓力）。四次嘗試：
1. **第 1 次失敗（我的輸入）**：`--run-dir C:/Users/…`（Windows 磁碟機形式）被 pr-gate 拒絕，`pmctl gate run` 卻回報 detached
   成功，約 20 秒後 `gate wait` 才是 `failed exit 2`，原因只在 `supervisor-stdout.log` → CC-615。改用預設的 repo 內
   `.gate-results`。
2. **第 2 次失敗（`--head feat/CC-594-s4` 加 `--test-cmd`）**：scope manifest（`status=complete`、jq 派生的 sha256）、pre-flight
   測試（pass 並寫出 evidence）、codex 分派與 reviewer（四位全 approve，**GO**）都完成，最後 assurance 驗證
   `linked preflight evidence subject claim mismatch`（preflight evidence 綁工作樹指紋 `a0abe626…`，assurance 綁 fixed_ref
   指紋 `3326ccb0…`）。ref 不是目前 HEAD 時是測錯程式碼（Linux 同樣會發生）；ref 就是目前 HEAD 時，Windows 上的差異來自執行位元偏移 → CC-616（已修：拒絕）、CC-619。
3. **第 3 次失敗（預設 HEAD，subject 含 `tests/lib/test-harness.sh`）**：qa-tester 的必要 helper 升級成大範圍測試集，180 秒逾時，
   QA evidence `inconclusive`，reviewer 判 **NO-GO**；之後 `sequential gate staging frontmatter must contain exactly one
   gate_result_version (found 0)`，run 以 failure-result 結束。helper 的 log 也顯示 codex sandbox 內 `/tmp` 暫存目錄問題 →
   CC-617、CC-618。
4. **第 4 次成功（預設 HEAD，一行文件變更的拋棄式本地分支，未推送，已刪除）**：`pmctl gate wait` → `state: GO, exit: 0`，
   結果檔 `gate_result_version: pr_gate_result_v5`、`final: GO`、`tier: standard`、`mode: sequential`、reviewers critic
   approve／qa-tester pass／architecture-reviewer approve；獨立的 `pmctl gate verify` → `gate result OK`、`assurance:
   verified`、`artifact_valid: pass`、`subject_current: pass`、`policy_applicable: pass`。這代表 shim 生效時，gate 從 scope
   manifest 的 jq 摘要、preflight evidence、assurance 與 attestation 驗證到最終判定，可以在原生 Windows 上走完。
- **耗時**：啟動 40–180 秒（context 索引更新有 90 秒上限，第 1 次逾時而略過），reviewer session 約 15–20 分鐘，`gate verify` 約
  205 秒（MSYS fork 成本；重複驗證見 CC-614）。
- **其他觀察（未開票）**：`context.reuse_scanned telemetry not recorded (state-writer not loaded)` 警告在每次 dispatch 出現。
- **結論**：端到端可行，但需要避開上述四個問題才能得到 GO；沒有任何一次是 shim 造成的失敗。

*S3 審查結果*（非測試檔的每個 `jq -R*`／`--rawfile` 呼叫點；判準：`-b` 只改變 stdin 的 `-R`／`-Rs`，
檔案讀入不變）：
- **會看到 CRLF 資料且受影響 → 已修**：`pmctl_gate_stats_frozen_row`（`pmctl-gate-stats.sh`，原
  `:189`；`runs-summary.jsonl` 的空 CRLF 行
  通過 `select(length>0)` 後 `fromjson` 失敗，被算成損毀行並標記歷史不完整）：`rtrimstr("\r")` 放在
  `select` 之前；新增端到端案例（舊讀取點失敗、新的通過；Linux 上同樣會發生，因為 Linux jq 本來就
  保留 `\r`）。
- **看 CRLF 資料但本來就容忍 → 加釘住測試**：`pmctl-trace.sh:226`、`pmctl-run-stats.sh:210`
  （`events.jsonl`；空行在 LF／CRLF 下結果相同、行尾 `\r` 是合法的 JSON 空白）：新增「CRLF 檔與 LF 檔
  結果逐位元組相同」案例，CR 專一的變異（拒絕以 `\r` 結尾的行）只被新案例抓到。
- **輸入是 bash／git／內部清單產生的 LF 字面值，不含 CR → 不需改**：`install.sh:375,464`
  （`dispatch_allowlist_entries`）、`install-guards.sh:194,554`、`uninstall-guards.sh:131`、
  `pmctl-state.sh:178,180`、`pmctl-worktree.sh:157`、`pmctl-ship.sh:1597`（`grep -oE` 只取反引號內
  的 token）、`gate-policy.sh:288` 與 `pr-gate.sh:1166-1171`（git 輸出）、`pmctl-dispatch.sh:546`
  （awk 輸出；上游 `reuse_yaml` 是 repo 內產生的 LF 檔，不是狀態檔）、`pmctl-task.sh:64`
  （`pmctl_policy_values` 已 `tr -d '\r'`）、`pmctl-artifacts.sh:402`（reviewer 行來自對 gate 結果檔的
  awk；該 awk 與 `_gate_result_frontmatter_value` 都用 `/^---$/` 比對 frontmatter 界線，CRLF 檔連
  界線都比對不到，會在到達 jq 之前就變成空的 `final` / `incomplete_source`，所以 CR 進不了 jq；本機
  gate 也寫 LF）、`dispatch-record.sh:24-36`（使用者文字的 `-Rs .`：`\r` 現在被保留並跳脫成 `\r`，
  與 Linux 相同，是更忠實的行為；Linux CI 已涵蓋同一條路徑）。
- **`-n` 加 `--arg`（沒有輸入）→ 不受影響**：`pmctl-ship.sh:1402-1410`、`pmctl-worktree.sh:285-288`、
  `pmctl-memory-config.sh:216`、`opencode/bin/install.sh:81`。
- **檔案讀入（`-Rs 檔案`、`--rawfile`）→ 行為不變**：`log-usage.sh:15,31`、`guard-inject-memory.sh:298-299`、
  `token-usage.sh:120`、`pmctl-memory.sh:958`、`gate-scope.sh:820,823,986`、`pmctl-artifacts.sh:255`、
  `pmctl-gate-stats.sh:171-173`。
- 移除 [[CC-593]] 留下、只為 jq 輸出而存在的 `| tr -d '\r'`：`gate-structural-validator.sh:52`、
  `lint-pmctl-commands.sh:86`（兩個腳本都已載入 shim；實測無 shim 時輸出有 4965 個 CR、有 shim 為 0，
  `--check` 與 lint 仍通過）。`tests/shell/test-gate-policy.sh` 裡 6 處同樣只為 jq 輸出而存在的
  `tr -d '\r'` 也移除（該套件經 `th_init` 載入 shim，22 案例仍全過）。runtime／tools／ops／hosts
  其餘的 `tr -d '\r'` 是給 sqlite3、awk、PowerShell、`git show` 比對用的，與 jq 無關，保留。

*S2 的額外必做事項（審查提出）*：`ops/diagnostics/gate-subprocess-census.sh:154` 有
`real="$(command -v "$tool")"` 且 `jq` 在被包裝清單（:150）內，是獨立腳本；加 snippet 後 `real`
會變成字面的 `jq`，產生的包裝腳本會呼叫自己而無限遞迴，**必須在加 snippet 的同一個修改把它改成
`type -P` 並加測試**。lint 以 `jq-lf.sh` 檔頭兩行為唯一真理逐字比對各獨立腳本，並在假的
`OSTYPE` 下於全新 shell 載入函式庫與 snippet、比較兩者行為；傳遞性 source 閉包是全新的工具，
遇到 `pr-gate.sh` 這類動態 source 迴圈要用明確 allowlist 或註記，不能悄悄略過。

**Non-goals**：不逐點補 `| tr -d '\r'`（每點多一個行程，且沒有防止漏掉的機制）；不要求使用者
換 jq 來源；不處理缺少 `jsonschema` CLI 的 22 個案例（另案）。

**Done-when**：S1–S4 完成；lint 通過；`test-core-schemas.sh` 在這台機器上除缺 `jsonschema`
的案例外全數通過；摘要與 Linux 已知向量一致；`tier-detection` 等 pr-gate case 仍通過；
CHANGELOG 說明 Windows 上摘要的一次性變動（跨升級進行中的 gate 產物）。

**See**: [[CC-593]]（同根因，已修復的四個較小範圍案例）

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

## CC-603 — `context.db` 不會縮小 🟢 someday

**Problem**：GitHub issue #636：`context.db` 沒有 `VACUUM`／`auto_vacuum`，即使 #620 的
`.next` 症狀被 [[CC-595]] 之前的修正正確 reconcile，膨脹過的 db 也永遠維持肥大。

**Requirement**：在 reindex 或明確的 maintenance 動作中安全地縮小 db（需考慮鎖與
並行）。

**Done-when**：在一個先膨脹再清理過的 fixture 上，執行後檔案大小可量測地下降，且
不影響並行讀取。

**See**: GitHub issue #636。

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

## CC-608 — kill 時 context refresh 其餘寫入的 `write error`：辨識實際失敗的 fd 🟢 someday

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

## CC-615 — `pmctl gate run` 在 supervisor 立刻失敗時仍回報 detached 成功 ✅ 2026-10-03

**Problem**：見索引列。`pmctl gate run` 在 parent 端沒有驗證 supervisor 會用到的參數（至少 `--run-dir` 必須是 POSIX
絕對路徑），也沒有等 supervisor 的第一個里程碑就回報成功；使用者看到的是「detached」，錯誤在 20 秒後才以
`failed exit 2` 且沒有原因的形式出現，原因只在 `runs/<id>/supervisor-stdout.log`。

**Requirement**：(1) parent 在 detach 之前驗證會導致 supervisor 立刻結束的參數（`--run-dir` 絕對路徑、`--head` ref
存在等，以及 CC-616 加在 `pr-gate.sh` 的 `--head` 加 `--test-cmd` 拒絕：共用那條規則，不要複製），失敗時直接以 usage 錯誤結束；(2) Windows 上 `C:/…`、`C:\…` 形式的絕對路徑要嘛轉成 POSIX 形式接受，要嘛給出
明確的錯誤訊息（建議用 `/c/…`）；(3) `pmctl gate wait` 在 `failed` 時把 `supervisor-stdout.log` 的最後 `Error:` 行印出來。

**Done-when**：上述參數錯誤在 `gate run` 就失敗並有可讀訊息；`gate wait` 顯示失敗原因；各有一個測試。

**結果（pr:#665）**：parent 端（`_pmctl_gate_validate_run_args`）在 context 更新、parent operation、detach 之前，用
`gate_options_parse` 與共用規則（`gate_options_require_workdir`、`gate_options_require_head_compatible`、
`gate_options_require_refs_exist`）驗證；`--run-dir` 的 Windows 磁碟機路徑給出「請寫 `/c/Users/...`」提示（選擇提示而非轉換：
轉換會讓信任邊界檢查失去意義）；`gate wait` 在 `failed` 時印出 supervisor log 的最後一行 `Error:`（去除控制字元、截斷 300 字、
標示為「log 的最後一個錯誤」而不是判決，因為該 log 也收子 session 的輸出）與 log 路徑。審查中修正：舊版 `gate-options.sh`
（缺新函式）不會讓每次 run 被拒絕；`--head` 規則現在在 ref 存在檢查之前（`--head <不存在> --test-cmd x` 由 exit 1 變 exit 2，
已記載）。**仍然晚才驗證**：`--tier`／`--mode`／`--pass`（需要 policy 表）、`--brief`／`--output`／`--policy-override`／
`--reviewers` 的內容 → CC-621；`gate wait` 靠 grep log 取得原因、`gate status` 與 `pmctl ship` 看不到 → CC-620。

**See**: [[CC-594]]（S4 的端到端證據）；[[CC-616]]；[[CC-620]]；[[CC-621]]。

---

## CC-616 — `--head <ref>` 加 `--test-cmd` 的組合一定在 assurance 驗證失敗 ✅ 2026-10-03

**Problem**：見索引列。

**Requirement**：先決定語意再修：(a) 與 `--allow-dirty` 一樣，`--head <ref>` 搭配 `--test-cmd` 在 reviewer 分派**之前**就拒絕，並說明
原因（preflight 在工作樹跑，subject 不是被審查的 ref）；或 (b) preflight 在 ref 的乾淨 checkout（或 worktree）上跑，
evidence 的 subject 改綁 ref 指紋；或 (c) 這種 subject 的 preflight 記為不具授權力的 advisory，不進入 assurance 的
linked evidence 比對。不得放寬 `linked preflight evidence subject claim mismatch` 對一般 subject 的檢查。

**Done-when**：選定的語意有測試（含 `--head` 加 `--test-cmd` 的案例，Linux 可跑）；不再有「跑完 reviewer 才失敗」。

**結果（pr:#664）**：選方案 (a)。`pr-gate.sh` 在 `--head <ref>`（`HEAD_REF != HEAD`）加 `--test-cmd`（且沒有
`--skip-preflight-tests`）時以 exit 2 拒絕，訊息列出替代做法；`--head HEAD` 是預設 subject，不拒絕。審查時發現
原先「指紋永遠不可能相符、與平台無關」的說法說太滿，已更正（見索引列與 CC-619）。方案 (b)（在 ref 的乾淨 checkout 上跑
preflight）仍可日後加入，拒絕只是可放寬的收窄。`pmctl gate run` 下這個 exit 2 仍會延遲出現（CC-615）；
CC-615 實作時應共用這條規則，不要複製。

**See**: [[CC-594]]（S4 的端到端證據）；[[CC-615]]；[[CC-619]]。

---

## CC-617 — 改到高扇出檔案時 qa-tester 的補充測試在自選預算內跑不完 ✅ 2026-10-03

**Problem**：見索引列（含對原票 `/tmp` 說法的更正）。

**結果（pr:#667）**：槓桿在 brief 與可觀察性，不動判決邏輯。(1) brief 的 QA execution 區塊說明 gate session 預算（所有 reviewer 共用）與單一命令約四分之一的上限、
要透過 repo runner 以名稱或路徑跑 suite、不要等待已宣布的 full-suite 升級（先列出選擇，改跑針對缺口的特定 suite）、命令撞到 `--timeout` 是「單獨不具結論、不能支持 GO」的證據：
報告為缺口，若 log 顯示在 diff 碰到的程式碼中卡住就是阻擋性發現，只是慢不算測試失敗；原生 Windows 另加「suite 慢數倍，選較少的 suite 而不是調大 timeout」。(2) helper 在 rc 124／137 時
依實際經過時間在 log 加註（達到上限才說「stopped by --timeout」，否則說「不一定是 timeout」）。(3) `run-tests.sh` 的升級訊息寫出 suite 數量。(4) 契約文件說明高扇出變更的完整測試
應放在 pre-flight（`--test-cmd` 加大的 `--test-timeout`）。審查中撤回了第一版的兩個錯誤：「timeout 不是測試失敗」（host 從不讀 QA execution 的狀態，只有 pre-flight 與 reviewer 的判斷
擋得住，變更造成的卡住也是 timeout）與「Windows 建議至少 540 秒」（session 預算 1200 秒由所有 reviewer 共用，watchdog 逾時會丟掉整個結果）。

**未處理**：reviewer 仍可無視文字（→ CC-625 決定性的預算機制）；host 端沒有強制 inconclusive QA 證據的後果（→ CC-624）；已記錄的 log 雜湊與封存的 log 不一致（→ CC-623）。

**See**: [[CC-594]]（S4 的端到端證據）；[[CC-613]]；[[CC-623]]；[[CC-624]]；[[CC-625]]。

---

## CC-618 — 結果檔以 UTF-8 BOM 開頭時 gate 整個 run 失敗 ✅ 2026-10-03

**Problem**：見索引列。

**結果（pr:#666）**：根因由位元組證實（失敗 run 的結果檔開頭 `ef bb bf 2d 2d 2d`、0 個 CR；成功 run 的結果是 `2d 2d 2d`）：
`gate_result_staging_normalize` 以 `^\+?---$` 在第一行找 frontmatter 圍欄，BOM 讓圍欄沒打開。修法：normalizer 在解析前去除開頭的
BOM（只在前 3 個位元組恰為 `ef bb bf` 時，只剝 3 個位元組），印出一行 `Note:`，既有的重寫會以不含 BOM 的內容重新發布。sequential
與 PM synthesis 兩條路徑都經過這個函式。測試 `staging-result-with-bom-normalized`（三個分支）在舊程式碼上得到與真實 run 完全相同的錯誤。
審查確認：解析器差異不可利用（剝除後的位元組會被 `gate_result_verify` 與 `gate_finalize_assurance` 完整重新驗證）；選擇在消費端容忍，
因為檔案由 Codex 自己的寫檔工具產生，repo 沒有可以修改的產出點。

**未處理（→ CC-622）**：CRLF 是同一類的潛在問題。

**See**: [[CC-594]]（S4 的端到端證據）；[[CC-622]]。

---

## CC-619 — Windows 上 `working_tree` 與 `fixed_ref` 指紋對同一個 commit 不同 ✅ 2026-10-03

**Problem**：見索引列。

**Requirement**：先用一個 Linux 可跑的重現（追蹤的 100644 檔案加 shebang、`chmod +x`、`core.filemode=false`，此時 git 不報變動，
但檔案系統 `-x` 為真）確認根因，再決定修法：`working_tree` 模式的執行位元改取 git 的記錄（index 的 mode，
未追蹤檔另行處理），而不是 `-x`。這會改變 Windows 上 `working_tree` 指紋（一次性的摘要不符，要在 CHANGELOG 說明，同 CC-594 S1
的 Behavior changes）；Linux 上 `-x` 與 mode 一致，指紋不變。不得削弱 subject 綁定。

**Done-when**：同一個 commit、乾淨工作樹時，`working_tree` 與 `fixed_ref` 指紋在 Windows 與 Linux 相同，有測試。

**結果（pr:#670）**：在只有 `core.filemode=false` 的 scratch repo 重現（舊 `working_tree` `a9bb648a…` ≠ `fixed_ref` `a4b47d87…`，新版相同）。
規則依 git 自己的設定：`core.filemode=false` 時 tracked 檔案用 index mode、untracked 用非可執行；其餘主機仍用 `-x`（維持 Linux 逐位元不變，不削弱 subject 綁定）。
architecture 審查回答了設計問題：不採「永遠用 index mode」（Linux 上 post-gate 的 chmod 會看不見），也不把規則寫進 manifest（會改變所有 Linux 指紋）。
Windows 與 WSL 都跑過測試（filemode 開啟的案例在 Windows 主機會 SKIP，因為 MSYS 無法表示沒有 shebang 的檔案的執行位元）；各項變異測試（含 untracked 檔案）全數被抓到。
既有的 oracle 測試在這台 Windows 主機上本來就因同一根因而失敗，已改為翻轉 index mode。
**更正**：中途我曾以為五個 `ship publish assessment` 案例因此修好，那是拿整個 suite 與 `--filter` 的結果比較得出的錯誤結論，這些案例在改動前後都失敗（fixture 不算指紋），已從 CHANGELOG 移除。

**See**: [[CC-627]]；[[CC-628]]； [[CC-616]]；[[CC-594]]（S4 的端到端證據）。

---

## CC-620 — `gate wait` 的失敗原因改為 sentinel 欄位 🟢 someday

**Problem**：見索引列。

**Requirement**：`gate-supervisor.sh` 在寫終態 sentinel 時加入 `failure_reason=`（log 的最後一個 `Error:` 行，去除控制字元、
截斷），`pmctl gate wait`、`gate status`、`pmctl ship` 共用；log grep 留作舊 sentinel 的 fallback。先查 dispatch 的失敗紀錄
是否有可對齊的欄位。不得把子 session 的輸出當成權威原因。

**Done-when**：三個命令都顯示同一個原因，有測試（含控制字元與長度）。

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

## CC-624 — host 不強制 QA execution 證據的後果 ✅ 2026-10-03

**Problem**：見索引列。

**結果（pr:#669）**：語意選擇是「拒絕發布」而不是降級或改判：只在 `Final: GO` 且沒有通過的 pre-flight 時，檢查 QA 證據（先 finalize 已死的 `running` checkpoint）是否恰為 `completed` 或 `not_run`，否則 exit 1、保留 failure-result（`Final` 行改寫為 INCOMPLETE 並附 `## Host Refusal` 說明）、不發布 sidecar 與 `result:`。
遺失、symlink、無法解析的證據視為 `unreadable` 並拒絕（QA 的補充指令以同一使用者執行 diff 自己的測試，能改寫證據檔）。helper 記錄 `attempt_timeouts`，任何一次 timeout 之後狀態維持 `inconclusive`；
其餘情況只判最後一個指令（brief 告訴 qa-tester 以通過的 suite 收尾）。NO-GO、通過的 pre-flight（任何通過的 `--test-cmd`，不論是否涵蓋 diff）、`completed`/`not_run` 不受影響。

**審查（critic、qa-tester、security、risk、architecture）**：無阻擋。採納：sticky timeout、fail closed、Final 行改寫、錯誤訊息寫出路（`--test-cmd`，`--head` 不可併用）與檔名（`--run-dir` 會搬走路徑）、補 NO-GO／`not_run`／exit 1／unreadable／sticky 測試；七個變異全數被抓到。
順帶修：兩個既有的 QA abort stub 在暫存路徑含空白的主機上本來就失敗（awk `$2`），改為讀整行。

**未處理**：見 [[CC-626]]。

**See**: [[CC-617]]；[[CC-626]]。

---

## CC-625 — QA 補充測試預算的決定性機制 🟢 someday

**Problem**：見索引列。

**Requirement**：先評估 helper 匯出剩餘預算加 runner 拒絕升級（`run-tests.sh` 是 repo 專屬，契約文件要定義這個介面），與 gate 自動把高扇出變更的完整測試放進 pre-flight 兩條路；
比較決定性、對 repo 無關性的影響與使用者可預期性。

**Done-when**：改到高扇出檔案的 PR 在 Windows 上不再因 reviewer 自選的短預算而得到 inconclusive 的 QA 證據，有測試。

**See**: [[CC-617]]；[[CC-624]]。

---

## CC-626 — QA execution 證據的發布後強制與逐次歷史 🟢 someday

**Problem**：見索引列。

**Requirement**：先決定 (1) 與 (2) 的語意（assurance 的 schema 版本、exit 3 的呼叫端相容性），再做 (3)–(6)；不得放寬 CC-624 的拒絕。

**Done-when**：`pmctl gate verify` 能拒絕一個建立在 inconclusive QA 證據上的 GO；逐次歷史有測試；拒絕次數可量測。

**See**: [[CC-624]]；[[CC-617]]。

---

## CC-627 — subject 指紋吞掉 git 的失敗 ✅ 2026-10-04

**Problem**：見索引列。

**Requirement**：讀 git 輸出時檢查結束碼（暫存檔或 `mapfile` 加明確的 wait），失敗即 return 2，涵蓋 `fixed_ref`、`committed_head`、`working_tree` 三個分支與兩個 `ls-files` 來源；不得改變正常情況下的指紋。

**Done-when**：git 失敗時指紋函式回非零而不是固定的空 manifest 摘要，有測試（以 PATH 上的 git 替身或損壞的 index 重現）。

**結果（pr:#671）**：見索引列。`gate-subject.sh` 的三種 kind 共用 `_gate_subject_git_listing`（寫檔、檢查狀態、印原因），manifest 與清單放在同一個暫存目錄並在所有出口清除。
測試涵蓋：每個清單失敗、git 印出清單後才失敗（真實的失敗型態）、結束碼固定為 2、stderr 內容、暫存目錄不外洩、合法空清單；Windows 與 WSL 都跑過，變異全數被抓到。
風險審查指出的可觀測性回歸（舊的 ls-files 迴圈會讓 git 自己的訊息顯示出來）一併修正。

**See**: [[CC-629]]； [[CC-619]]。

---

## CC-628 — Windows symlink 偏差與 subject 規則的可觀察性 🟢 someday

**Problem**：見索引列。

**Requirement**：先重現 `core.symlinks=false` 的偏差，決定 `working_tree` 對 tracked 120000 項目的處理（以 index 記錄的型別與連結目標為準）；補 skip-prefix 與 symlink-as-file 的判別性測試；評估 assurance 的 `subject.mode_source` 欄位。

**Done-when**：同一個 commit、乾淨工作樹時，含 symlink 的 repo 在 Windows 的 `working_tree` 與 `fixed_ref` 指紋相同，有測試。

**See**: [[CC-619]]；[[CC-627]]。

---

## CC-629 — gate 完整性輸入的 git 失敗清查 ✅ 2026-10-04

**Problem**：見索引列。

**Requirement**：逐一確認每個位置在 git 失敗時的行為（讀成「空」、「乾淨」或「相等」都是 fail-open），改成失敗即回非零並印出原因；不得改變 git 正常時的輸出。依 (a)(b)(c) 分成獨立的 PR，每組有 PATH 上 git 替身的測試（失敗、輸出一半後失敗、合法的空結果）。

**結果**：(a) #672、(b) #673、(c) #674，見索引列。git 失敗時，scope digest、change set、dirty 檢查、指紋函式與摘要原語都不會產生看似有效的結果；dispatch 前後雜湊本來就 fail-closed，只補了訊息。摘要契約的改變（CC-611 釘住的舊行為）是有意識的：標頭註解與 CHANGELOG 說明，測試改寫為 `case_gate_digest_tool_failure_is_a_failure_in_both_modes`。

**See**: [[CC-627]]；[[CC-619]]；[[CC-611]]；[[CC-630]]；[[CC-631]]；[[CC-632]]；[[CC-633]]；[[CC-634]]。

---

## CC-630 — scope 擴充搜尋的 git 失敗 🟢 someday

**Problem**：見索引列。

**Requirement**：先確認擴充清單如何進入 manifest 與 reference index（reviewer 只能引用其中的路徑），再依索引列的形狀實作：`expansion-search-unavailable` 的 reason、`git grep` 結束碼 0／1／其餘的區分、搜尋函式改寫檔案並回傳狀態，保持 CC-599 的 fork 數；加 PATH 上 git 替身的測試（失敗、輸出一半後失敗、合法的無符合）。

**Done-when**：`git grep` 真正失敗時 manifest 標示 incomplete 並說明原因，而不是默默少了相關檔案；無符合時行為不變；Windows 上的耗時不變。

**See**: [[CC-629]]；[[CC-599]]。

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

## CC-636 — Windows 上 test-doctor.sh 的固定成本 🔵 active

**Problem**：見索引列。數字來自 2026-10-06 的本機量測（Windows 11、Git Bash）：每個執行真實 `doctor.sh` 的案例約 43 到 47 秒，一次追蹤到的 `doctor.sh` 內部為 18 到 34 秒（同一案例前後相差近一倍，百分比只當排序參考）。`test-doctor.sh` 共 93 個案例，整個檔案超過單次 570 秒的工具上限，所以 Windows 上的本機驗證只能靠 hosted CI。

**Why**：驗證證據拿不到會讓 Windows 上的 PR 只剩 hosted CI 當證據（見 CC-635 的保證限制）。成本是每次 `doctor.sh` 呼叫的固定開銷，案例越多越慢。

**Requirement**（依序、分開驗證）：
1. 測試不再對真實 repo 重複跑 frontmatter lint：doctor 提供明確的略過開關或可替換的 lint 路徑，只由測試設定；預設行為不變，並保留至少一個案例執行真實 lint 路徑。
2. `host_manifest_scalar` 每次 `doctor.sh` 執行只讀一次 `host.yaml`（快取），輸出與現在逐字相同。
3. `check_detached_runs` 的成本與紀錄數成正比，是否設上限或在能判斷時略過，另開票：它改變使用者每天看到的 `doctor` 行為。

**Done-when**：`test-doctor.sh` 單一案例在本機的時間顯著下降（前後以同一案例、同一台機器量測並貼出數字）；全部案例結果不變；hosted CI 全過。

**Non-goals**：不改檢查本身的判斷邏輯；不刪除任何案例；不動 pr-gate 與其他測試檔（它們各有自己的成本，另行量測）。

**Update 2026-10-06（PR 進行中，Requirement 1 的一部分）**：`tools/lint/lint-frontmatter.sh` 每個檔案原本啟動 sed、grep、awk 與管線，改為單次行程內讀取；本 repo 上輸出逐字相同，單次執行約 8 秒降到約 1 秒，`test-lint-frontmatter.sh` 51 秒降到 26 秒，`doctor-grok-authed-via-xai-env` 案例 33 到 47 秒降到 27 秒（單次量測，雜訊大）。尚未做：Requirement 1 的「測試略過 lint」開關（改寫後 lint 只剩約 1 秒，可能不需要）、Requirement 2、3。

**量測方法**：`BASH_ENV` 指向含 `set -x` 與 `PS4` 的檔案以追蹤子 bash 腳本（`SHELLOPTS` 在此環境唯讀）。

**See**: [[CC-635]]；[[CC-599]]；[[CC-611]]。

**Update 2026-10-08（需求 2 以量測否決）**：原假設「`host_manifest_scalar` 重複開檔是 doctor 的主要成本」不成立。實作預載（啟動時一次解析所有 `hosts/*/host.yaml` 的頂層純量，子殼層繼承查表）後，單次讀取從約 46 毫秒降到約 30 毫秒，但 `doctor.sh` 整體仍是 6.2 到 6.7 秒對 6.3 到 6.6 秒（各三次），在雜訊內，因此沒有合併。先前「`host-manifest.sh` 佔 11 秒」是巢狀 xtrace 把時間重複計算的假象，不可當成排序以外的數字。不重複計算的逐檢查耗時（一次追蹤共 7.1 秒）：`check_parent_operations` 1.45（即 `pmctl state status`，見 [[CC-637]]）、`check_memory_dir` 1.43（`find_memory_dir` 逐層往上走目錄，每層一次 `encode_path` 與 `dirname` 子殼層，另有 `pm_config_*`）、`check_frontmatter_lint` 1.0、`doctor_host_codex_run` 0.68、`doctor_host_grok_run` 0.58、`check_detached_runs` 0.54。下一個實際可省的是 `find_memory_dir`（hook 每次提示也會呼叫），其次才是其餘；需求 3（`check_detached_runs`）也只有 0.54 秒，優先序低。

**Update 2026-10-08（更正，`find_memory_dir` 也不值得做）**：上一段把 `check_memory_dir` 的 1.43 秒列為下一個目標，是追蹤把時間放大的結果。實測（微基準，單次、有雜訊）：整個 `find_memory_dir` 約 510 毫秒，其中 `pm_config_project_key` 約 380 毫秒（git、路徑正規化與 SHA-1，是專案狀態分區的身分，不應為速度更動），目錄走訪的 `encode_path` 與 `dirname` 全部合計約 130 毫秒；全換成內建字串操作最多省 `doctor` 約 2%。另外 `memory-dir.sh` 檔頭明說它是安裝、遷移與 doctor 用，不在 hook 路徑上（hook 直接載入 `memory.sh`），先前「hook 每次提示也會呼叫」的說法是錯的。結論：doctor 的剩餘成本是許多各約 0.5 到 1.5 秒的小項（`pmctl state status`、frontmatter lint、各 host 檢查），沒有單一值得做的大項；本票不再追加批次，若要再降要改變做法（例如跳過或快取整段檢查），那是產品行為決定，另案。

---

## CC-637 — adapter-manifest 重複驗證與 guard hook 啟動成本 ✅ 2026-10-08

**Problem**：見索引列。量測（2026-10-06，Windows 11、Git Bash，單次量測、雜訊大）：`adapter_manifest_dispatch_path` 1757 毫秒、`effective_route` 711、`runner_kind` 373、`file` 276；一次 `guard-executor-write.sh` 呼叫 5.3 秒。原因是公開函式各自重新呼叫 `adapter_manifest_file`（重新做目錄解析與 manifest 讀取），`dispatch_path` 內部合計約 5 次。

**Requirement**（分批，每批各自驗證）：
1. 公開函式只驗證一次：`runner_kind`、`effective_route`、`dispatch_path` 共用 `_adapter_manifest_runner_kind_of`，安全檢查（schema、adapter 名稱、symlink、逃出 adapters/、逃出 adapter 目錄）內容與順序不變。
2. guard hook 本身仍各自呼叫 `dispatch_path`、`file`、`runner_kind`、`scalar`，可合併為一次驗證後取值。
3. `guard-framework.sh` 用 4 次 jq 讀同一個 JSON 輸入，可合併。
4. 其他用到 `adapter-manifest.sh` 的呼叫端（doctor、pr-gate、pmctl-dispatch、executor-router）重新量測。

**Done-when**：新舊實作在真實 adapter 與壞掉的 manifest（schema、名稱、runner_kind、route、dispatch_entrypoint 的各種錯誤）上，stdout、stderr、結束碼逐字相同；`test-executor-router.sh`、`test-hook-profile-parity.sh`、`test-pmctl-adapter-generate.sh`、`test-guards.sh --filter exw:` 結果與 main 相同；前後以同一函式、同一台機器量測並貼出數字。

**Non-goals**：不放寬任何安全檢查；不引入跨函式呼叫的快取（長時間執行的行程會讓快取的驗證過期）。

**Update 2026-10-06（批次 1 的 PR）**：Requirement 1 完成：`dispatch_path` 1757 到 740 毫秒、`effective_route` 711 到 399、`runner_kind` 與 `file` 約持平；guard hook 單次 5.3 到 3.4 秒。新舊比對 80 筆輸入（4 個真實 adapter 與 13 組壞掉的 manifest，各 4 個函式）完全一致。Requirement 2 到 4 尚未做。

**驗證範圍與已知缺口（批次 1）**：`test-executor-router.sh` 34 過 1 失敗，失敗的案例（symlink 與執行位元，這台沒有支援）在 main 上相同；`test-guards.sh` 只跑 `--filter exw:`（30 過），整份超過 10 分鐘且一次背景執行因記憶體不足被停止；審查發現新內部函式漏了 `export -f`（子 bash 繼承匯出函式時會 command not found），已修並新增兩個案例（子殼層呼叫、無效 runner_kind 直接拒絕）。`adapter_manifest_dispatch_path` 在這種子殼層本來就會失敗（安全樣式經匯出函式往返後失效），在 main 上相同，未處理。

**Update 2026-10-06（批次 2）**：`pmctl state status` 的 jq 行程由約 12 個降到約 6 個：七個 entity 的 schema 版本合成一次 jq 呼叫（缺檔仍為 null），`supported` 與 `safe_reasons` 兩條管線各合成一次。`pmctl state status --json` 約 3.95 秒降到約 2.92 秒，`test-state-status.sh` 98 秒降到 62 秒（單次量測，雜訊大），輸出在 9 種 schema 情況（正常、缺一個、缺全部、空檔案、兩個空檔案、單檔多文件、enum 與缺 schema_version 欄位、const false、壞 JSON）下逐字相同，壞 JSON 時只有 jq 自己的錯誤訊息文字不同（多檔一起讀時可能指到相鄰的檔名），結束碼同為 2。審查發現第一版以位置對應檔案與版本，空檔案或多文件檔案會讓其餘 entity 的版本無聲錯位，已改為以 `input_filename` 取得 entity 名稱，並新增三個案例（完整物件與 key 順序、缺檔空檔多文件、enum 與格式錯誤）。只在 jq 1.8.1 與這台 Git Bash 驗證；jq 1.6 與 bash 4.3 以下（空陣列展開已用 `${arr[@]+...}` 防護）未實測。`pmctl state status` 其餘成本：PowerShell 檢查 state 目錄 ACL 約 0.66 秒（`state-writer.sh`）、`_sw_project_key` 約 0.49 秒，尚未處理，ACL 檢查是安全邊界，需 security 審查才能考慮快取。

**Update 2026-10-06（批次 3，需求 2、3）**：`guard-executor-write.sh` 不再各自重新驗證 manifest（`dispatch_path` 驗證一次，hook 取它設定的 `_ADAPTER_MANIFEST_FILE` 與 `_ADAPTER_MANIFEST_RUNNER_KIND`），`g_read_json` 三次 jq 合為一次（欄位以單位分隔字元連接，tool_input 放最後；agent_type 或 tool_name 含該字元視為格式錯誤拒絕，非字串的 agent_type 改為緊湊輸出）。hook 單次約 2.0 降到約 1.4 秒（單次量測）。在 Linux jq 上對 17 種輸入新舊逐字相同，除上述兩種有意差異。WSL：`test-guards` 305、`test-executor-router` 37、`test-hook-profile-parity` 5 全過。審查後補：新 hook 搭舊函式庫時改用 `${VAR:-}` 讓明確的 refuse（結束碼 2）執行，不再因 `set -u` 以結束碼 1 放行；agent_type 與 tool_name 保留舊行為去掉結尾換行；多個 JSON 值拒絕。測試 310 過（WSL）。需求 4（其餘呼叫端重新量測）與 `g_jq` 的第四次 jq 尚未做。

**量測教訓**：`test-guards.sh --filter` 不會只跑一個案例（整個檔案的 hook 呼叫都會執行），所以「單一案例秒數乘案例數」的估計不可信；用整份檔案的實際時間或逐段追蹤。

**See**: [[CC-612]]（同一個熱點，先前以剖析發現；本票不做快取，改為去掉函式內部的重複呼叫）；[[CC-636]]；[[CC-635]]。

**結果（2026-10-08，需求 4 以量測結案）**：批次 1 到 3 已合併（#681、#682、#684）。需求 4 重新量測：`pmctl dispatch run` 一次 38.6 秒中 `adapter-manifest.sh` 約 1.1 秒（不到 3%）；`doctor.sh` 一次約 11 秒中 `adapter-manifest.sh` 為 0，幾乎全部在 `host-manifest.sh`，由 [[CC-636]] 第 2 項處理。其餘呼叫端（executor-router、pr-gate 迴圈）的成本小於測量雜訊，不再另做。未處理且不再掛在本票：`g_jq` 的第四次 jq（每次約 0.1 秒）、`pmctl state status` 的 PowerShell 權限檢查（約 0.66 秒，安全邊界，需 security 審查才能考慮快取）與 `_sw_project_key`（約 0.49 秒）；有需要時另開票。

---

## CC-638 — 原生 Windows 測試成本與 WSL2 執行輔助 🔵 active

**Problem**：見索引列。Windows 上 `test-doctor.sh` 整份超過一小時、`test-guards.sh` 超過 10 分鐘，工具單次上限（約 570 秒）內跑不完，本機驗證因此只能靠 hosted CI。逐一減少外部程序（[[CC-636]]、[[CC-637]]）每批只能省 3% 到 10%。

**Requirement**：
1. `ops/diagnostics/run-tests-in-wsl.sh`：把工作目錄（含未 commit 的修改）同步進 WSL2 的獨立暫存目錄、清掉 NTFS 假的模式位元並補回真正的執行位元、逐個測試檔計時執行；通過後移除暫存目錄，失敗、`--keep` 或 `--sync-only` 時保留，超過一天的舊目錄於下次啟動清掃；本批交付。
2. `--changed [--base REF]`：把本機變更與未追蹤的路徑（不含已刪除）交給 WSL 內的 `tests/bin/run-tests.sh` 選測試；本批交付。若變更到影響面大的路徑（例如 `tests/lib/test-suite-runner.sh`），`run-tests.sh` 會升級成整個套件，單次 `--timeout` 不夠，需要另外提高。
3. 文件說明何時用它、何時仍須原生驗證（ACL、PowerShell、Job Object、路徑轉換）、這不是沙盒；本批交付。
4. 之後依 [[CC-637]] 的剩餘項目繼續減少外部程序，優先順序以整份檔案的實際時間為準。

**Done-when**：在 WSL 上對同一個工作目錄執行指定測試檔並印出結束碼與秒數；失敗與逾時以結束碼 1、錯誤的測試名稱或參數與不支援的平台以結束碼 2 拒絕；純函式（套件名稱、檔案與可執行清單、變更路徑、結果解析）在任何平台有測試。同步與執行本身需要原生 Windows 加 WSL，沒有自動化測試，以手動驗證並記錄在 PR。

**Non-goals**：不取代原生 Windows 驗證；不改產品程式；不處理 WSL 以外的環境；不更動 Defender 或其他安全設定（量測期間沒有證據顯示它是主因）；不為了自動測試同步流程而加入假的 `wsl.exe` 與測試專用環境變數（CI 的 Linux 本來就會跑測試套件本身；假的 `wsl.exe` 也抓不到真正遇過的兩個錯誤，它們都是 Windows 專屬）。

**Update 2026-10-06**：第一版同步時 Git Bash 把 `/home/...` 參數改寫成 `C:/Program Files/Git/home/...`，檔案被複製進 repo 根目錄一個名為 `C:` 的垃圾目錄；已用只對 `wsl.exe` 該次呼叫設定 `MSYS2_ARG_CONV_EXCL` 修正（不可全域設定，git 也是原生程式）。另一個錯誤：從 NTFS 打包會讓每個檔案都帶執行位元，`git add -A` 在 WSL 記成 `100755`，`lint-jq-lf` 因此把所有函式庫當成進入點；現在先清除再只補回真正的。同步約 6 秒，三個測試檔 2 到 3、4、17 秒。

**Update 2026-10-06（審查後）**：腳本拆成可 `source` 的純函式；摘要改由 WSL 端以標記行回報並保留完整日誌，失敗時印出失敗案例與日誌路徑；可執行清單改 NUL 分隔；WSL 端刪除前再檢查路徑；暫存目錄上層 `700`；每次執行獨立暫存目錄（含程序 id 與亂數）；`--changed` 的路徑集合比照 `run-tests.sh` 只取 ACMR，並在同步前先算好，壞的 ref 或沒有變更時不花同步成本。曾做過用假的 `wsl.exe` 在 Linux 驗證整個流程的測試，後來依維護者意見移除（見 Non-goals）。

**Update 2026-10-08（WSL 基準）**：2026-10-08 在原生 Windows 對 110 個測試檔各跑一次（上限 120 秒，分片與 meta 套件另計）：55 過、33 不過、22 逾時，共約 79 分鐘。不通過的 55 個之中，把 54 個（扣掉只在發布時用即時 adapter 跑的 `test-e2e`）放到 WSL：51 個通過，約 94% 的原生失敗與逾時是 Windows 專屬。WSL 上不通過的找出下列與 Windows 無關的原因並修正：（1）WSL 的 shellcheck 是 0.8.0 而專案固定 0.11.0，`test-release-verify` 8 個案例回 NO-GO，helper 現在解析一次 `tools/lint/bootstrap-shellcheck.sh --resolve` 的版本並放到每個測試檔的 `PATH` 最前面（需先在 WSL 內執行一次該腳本，裝在 `~/.cache/pm-dispatch/tools`；找不到時 helper 印出提醒）；（2）暫存樹沿用原目錄名、分支 `main`、有 `origin/main`（origin 就是暫存 repo 本身，不是真的遠端），`test-pm-prep-snapshot` 兩個案例因此通過；日誌路徑多一層 `<scratch>/<repo 名>/.pmd-wsl-logs`；（3）`test-opencode-dispatch` 原判斷「不穩定」是錯的，同一棵樹原版 10/10 失敗：store 底下有兩個專案分區各有 `events.jsonl`，測試用 `find | head -1` 取第一個，結果取決於目錄順序；改為挑含有 `run.completed` 的那個（原版在 CI 通過是靠順序碰巧，這一點是推論，未在 CI 上驗證）；（4）Linux 的 jq 1.6 不接受 `jq -b`，`test-jq-lf` 強制啟用 shim 的案例在這種 jq 上改為明確跳過（Windows 上改為失敗，不會靜默跳過），並更正 `jq-lf.sh` 注解；（5）helper 讀寫 `PATH`，變量消費圖補一行。另有一次 `test-doctor` 7 個失敗，來自專案根目錄一個未追蹤的 `bash.exe.stackdump`：helper 把未追蹤且未被忽略的檔案一起提交進暫存 repo，doctor 因此當成已追蹤檔案檢查 CRLF；helper 的行為不變（已知限制：未追蹤、未被忽略的檔案仍會一起提交），但 `*.stackdump` 已加進 `.gitignore`，Git Bash 異常退出留下的崩潰轉儲不會再被同步或誤提交；用強制結束 Git Bash 行程的方式停掉背景工作也會產生它，應避免。pr-gate 四個分片在 WSL 各需 512 到 651 秒（CI 期限 2400 秒），`test-pr-gate` 本身不是登記的測試檔。審查另指出、未在本批處理：`test-state-store.sh` 與 `test-migrate-routing-to-events.sh` 有同樣的 `find | head -1` 寫法，目前只有單一分區所以不受影響，若日後出現第二個分區會同樣失敗（可抽共用的找檔 helper）。

**See**: [[CC-636]]；[[CC-637]]；[[CC-635]]。

---

## CC-639 — 子命令的目標 repo 缺省應是目前目錄 🔵 active

**Problem**：見索引列。

**Requirement**：
1. `pmctl worktree create|list|remove|gc`、`pmctl artifacts list|show|gc|migrate`、`pmctl ship prepare|run|finish|status|list|--parallel` 在沒有 `--cd` 時，目標 repo 是目前目錄所在 repo 的 git 根目錄，不在 git repo 內才用目前目錄；與 `gate run`／`gate wait` 既有的 `_pmctl_gate_default_cd` 同一個推導，由 `portable_default_work_dir` 提供。`repo_root` 只用來載入 pm-dispatch 自己的函式庫。
2. 回歸測試，且修正前會失敗：worktree 的 list／remove／gc（從子目錄）與 create（用「誘餌 install repo」直接呼叫函式，失敗時不會碰到真正的 checkout）、artifacts 的 list／show／gc／migrate（從子目錄）、ship 的 prepare（即 run 的入口）與 status（從子目錄）、`portable_default_work_dir` 本身（根目錄、子目錄、非 git 目錄）。
3. 文件說明缺省值。

**Done-when**：從另一個 repo（含子目錄）執行上述子命令不加 `--cd`，作用在該 repo；新測試在修正前失敗、修正後通過；受影響測試檔在 WSL 通過。

**Non-goals**：不改 `--cd` 本身的語意；不改函式庫的簽名。沒有直接測試的位置：`ship finish`、`ship list`、`ship --parallel`、`ship <id> --worktree/--adapter` 與 `prepare` 共用同一個缺省運算式但各自沒有案例（finish 會推送與開 PR，不適合以只讀方式測；其餘需要完整的 lane 設定）。不在 git repo 內且沒有 `--cd` 時**不是錯誤**，目標就是目前目錄（artifacts 與狀態庫對非 git 目錄使用共用的 `global` 分區），這個行為留給 [[CC-640]] 決定。

**行為改變**：以前缺省是 pm-dispatch 自己的 checkout，所以舊缺省建立的 worktree 登記、artifacts 都在 pm-dispatch 的分區，現在要加 `--cd <pm-dispatch 的 checkout>` 才看得到。

**See**: GitHub issue #677；[[CC-607]]；[[CC-640]]。

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
