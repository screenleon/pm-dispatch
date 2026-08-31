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
| CC-461 | 🟢 someday | `doctor.sh --fix`：僅限冪等/可逆/不碰使用者內容類別的自動修復；待 CC-447 offline smoke 產出摔倒點清單後定白名單（2026-07-07 openyida 跨專案分析） | ops/install | 2026-07-07 | — | P3 | — |
| CC-462 | 🟢 someday | e2e 可拋棄資源紀律：前綴命名 + registry JSON + result artifact；掛在 CC-449 e2e 新 phase 之後，與 CC-447 live smoke 共用同一 registry（2026-07-07 openyida 跨專案分析） | ops/test | 2026-07-07 | — | P3 | — |
| CC-463 | 🟢 someday | `pmctl batch` 泛用批次執行原語；依賴 CC-460（合法性驗證來源）；新注入面須過 security-reviewer（2026-07-07 openyida 跨專案分析） | arch/process | 2026-07-07 | — | P3 | design |
| CC-464 | 🟢 someday | `pmctl ticket draft --from <notes>`：隨手筆記→結構化 backlog 票草稿；依賴 CC-286（prefix-generic next-id，⏸ deferred 尚未排程）；review-first 邊界獨立設計，CC-054 僅供鬆散參照非直接前例（2026-07-07 openyida 跨專案分析） | ux/process | 2026-07-07 | — | P3 | — |
| CC-493 | ✅ done | Prompt→Skill→Command→Harness 升級規則文件化：可測試的分類判準（何時停在 prompt、何時升為 skill、何時做成 command、何時需要 harness-level hook/guard/state），並盤點 `commands/`／`skills/`／`agents/` 現況對照分類（2026-07-15 CC-489 三方 multi-model synthesis） | process/docs | 2026-07-15 | pr:#513 | P2 | design |
| CC-494 | 🟢 someday | design: executor 局部設計裁量權 envelope——在 dispatch brief / executor contract 定義「可自行處理的局部設計」與「必須 halt 回報 PM」的邊界（例如新增 schema 欄位 `design_latitude`/`architectural_conflicts`）；三方 multi-model synthesis 2:1 分歧（codex/fable 認為現行邊界過度僵硬需要新機制，opencode 認為現行 `isolation_level`/executor 欄位已足夠彈性），本票僅追蹤決策、不預設結論（2026-07-15） | schema/process | 2026-07-15 | feedback:2026-07-15 | P3 | design |
| CC-505 | ✅ done | context plane lexical 檢索補完（Ph1 engine+統一排序+fixtures；Ph2 agent 契約+shadow 儀器化；evidence-gated 收緊 → [[CC-506]]）（2026-07-20 四方 synthesis；CC-346/347 前置） | memory/DX | 2026-07-20 | pr:#516 | P2 | retrieval |
| CC-506 | ⏸ deferred | retrieval evidence-gated 收緊：shadow 評測（coverage@5、critical miss、read reduction、outcome parity）達標後才收緊 broad-Read 指引並重評 [[CC-340]] resume 條件；前置 = [[CC-505]] Ph2 shipped + ≥20 真實任務證據 | memory/DX | 2026-07-20 | — | P3 | retrieval |
| CC-511 | ✅ done | ship publish authorization：Phase A current-tree authoritative full-suite 與 CC-515 shared verifier foundation 已交付；Phase B review-closure evidence 已由 CC-517 收斂 | release/gate | 2026-07-23 | pr:#446, pr:#484, pr:#507 | P1 | design |
| CC-514 | ✅ done | orthogonal delivery assurance map、machine-derived tables 與 feature/docs/high-risk recipes；Req 5 cross-document lint 與 Req 6 drift ratchet 收斂成同一個動態發現機制（`tools/lint/check-policy-doc-sync.sh`），Req 1-4/7 已於 pr:#522 交付 | docs/process | 2026-07-23 | pr:#522 | P2 | design |
| CC-516 | ⏸ deferred | evidence-gated thin delivery wrapper 評估；只組合既有 primitives，不建立 workflow engine/FSM | ux/process | 2026-07-23 | — | P3 | spike |
| CC-517 | ✅ done | maintainer `/ship`：primary review、structured remediation closure 與 conditional targeted confirmation | process/gate | 2026-07-23 | pr:#483, pr:#506 | P1 | design |
| CC-524 | ✅ done | `pmctl artifacts show` 顯示 canonical absolute run root 並提供穩定 machine-readable locator | ux/ops | 2026-07-27 | feedback:2026-07-27, pr:#537 | P2 | hygiene |
| CC-527 | ✅ done | targeted gate CLI 拆分 pass、reviewer coverage 與 tier；tier 由 current subject/policy 解析，initial result 僅為 remediation context | ux/gate | 2026-07-28 | pr:#472, pr:#476, pr:#482, pr:#505 | P2 | design |
| CC-529 | ✅ done | publish assurance observability：以 gate_publish_assessment_v1 將 ship stdout、PR body 與 finish marker 綁到同一份 verified assessment；preferred 路徑早有真實佐證（PR #517），baseline 路徑本次以 generic gate + `ship finish --gate-result` 補做真實 dogfood | release/gate | 2026-07-30 | feedback:2026-07-30, pr:#484 | P2 | hygiene |
| CC-532 | ✅ done | Linux/WSL2 repo-layout canonical Gate modules：options／policy／subject／scope／reviewer-contract／assurance 均有單一 source owner；standalone／copy parity 在 [[CC-546]] | arch/gate | 2026-07-30 | feedback:2026-07-30 | P1 | reuse-debt |
| CC-533 | ✅ done | schema-derived Gate structural validator：assurance／scope-manifest／reviewer-result／synthesis-result 四型全數完成 schema-first 重寫 | schema/gate | 2026-07-30 | pr:#480, pr:#524, pr:#525, pr:#526, pr:#527, pr:#528 | P1 | design |
| CC-534 | 🟢 someday | `commands.tsv` 驅動 CLI routing、safe handler dispatch 與 lazy module loading | arch/DX | 2026-07-30 | feedback:2026-07-30 | P2 | design |
| CC-535 | 🟢 someday | detached-launch 上的 supervised-run primitive + versioned JSON run-spec | arch/ops | 2026-07-30 | feedback:2026-07-30 | P2 | design |
| CC-536 | ✅ done | 擴充 Adapter SDK 的 shared lifecycle／manifest／trace contract，保留 executor-native behavior | arch/reuse | 2026-07-30 | feedback:2026-07-30, pr:#549 | P2 | reuse-debt |
| CC-537 | 🟢 someday | suite metadata 與 changed-path impact mapping 資料化；full suite 維持 authoritative | ops/test | 2026-07-30 | feedback:2026-07-30 | P2 | hygiene |
| CC-538 | ✅ done | Host resolver／doctor 共用 primitives，Host policy 繼續由各 Host 擁有 | arch/ops | 2026-07-30 | feedback:2026-07-30, pr:#548 | P2 | reuse-debt |
| CC-539 | 🟢 someday | state `layout.yaml` build-time authority + generated runtime constants | arch/schema | 2026-07-30 | feedback:2026-07-30 | P2 | design |
| CC-540 | ✅ done | `pmctl state prune`：刪除前先抽取+驗證 gate/dispatch run 摘要，避免歷史分析資料隨磁碟空間一起消失 | ops/gate | 2026-07-31 | pr:#515 | P2 | hygiene |
| CC-546 | ⏸ deferred | standalone Gate distribution／copy parity follow-up：獨立定義 bundle schema、generation、installed parity 與 support boundary；不回併 Linux/WSL2 canonical module extraction | arch/gate | 2026-08-14 | — | P2 | reuse-debt |
| CC-559 | ✅ closed 2026-08-23 | **[memory usage sidecar 無法記錄含 tab／newline／backslash 的卡片路徑]** SQLite／TSV 兩個後端在共用傳輸邊界統一 escape／unescape（雙射字元掃描，無 sentinel 碰撞風險）；`# schema=2` 一次性遷移標記避免既有原始資料被誤判；`unmeasurable_cards` 恆為空但誠實回報機制保留。See pr:#521. | ops/memory | 2026-08-19 | pr:#521 | P3 | hygiene |
| CC-562 | ✅ done | synthesis／reviewer 驗證器仍有多個「多約束共用單一 reason 字串」分支（`invalid coverage matrix`、`invalid finding inventory or union`、`duplicate finding ID collision`、`selected/not-reviewed dimensions mismatch`），單次修正重試收到後無法行動；[[CC-553]] Req 2 判定需同等精度但屬不同 helper 形狀（逐項指出違規條目，非集合差集），故分票 | ops/gate | 2026-08-19 | pr:#510 | P3 | hygiene |
| CC-560 | ✅ done | `_gate_scope_reference_index_collect` 每筆 reference 都以 `jq -nc` 建一個 JSON 物件（實測 4.9s×2），與 [[CC-557]] 已修掉的 `_gate_scope_expansion_append` 是同一類寫法；CC-557 未一併處理是因預算餘裕已足，非因不成立 | ops/gate | 2026-08-19 | pr:#511 | P3 | hygiene |
| CC-554 | ✅ done | 永久 regression test 缺少准入門檻：`/ship` 規範「修完每個 finding」但不規範修法形式，reviewer 每提一個邊界就永久長一個阻擋 case，case 又需要 meta-test 保護；QA 規則加六條准入條件＋五條替代路徑，ship.md 加對應例外（明確不設輪數上限，見 [[CC-544]]） | ops/gate | 2026-08-17 | pr:#490, pr:#530, pr:#544, pr:#555 | P1 | hygiene |
| CC-552 | ✅ done | `test_default_worker_cap` 以 `sleep 0.1` 製造 worker 重疊窗口來驗證併發上限，違反 QA 規則的「不得以 sleep 同步」；主機負載會改變觀測到的重疊數，與 worker-cap 正確性無關（2026-08-17 CC-551 gate round 4 qa-tester，pre-existing） | ops/test | 2026-08-17 | — | P3 | hygiene |
| CC-548 | ✅ closed 2026-08-26 | **[context.db FTS5 對 CJK 查詢無索引無排序]** Spike 判定 **AMBER — defer，暫不實作**：無 sqlite 版本下限硬衝突，rebuild 遷移成本為零，但實測 trigram rebuild 慢 ~4.9x、索引大 +32.6%，而品質增益在本 repo 實際語料上僅小幅（68 筆抽樣命中中多 1 筆），且原票「unicode61 無 ranking」前提經量測不成立。See `docs/spikes/CC-548.md`. | memory | 2026-08-16 | — | P2 | retrieval |
| CC-466 | ⏸ deferred | 記憶卡片生命週期閉環：expires_at 執行 + 關窗式 supersede + usage sidecar 休眠偵測 + doctor→distill 接線；僅在 CC-467 證明 stale/dormant card 已形成實際問題時啟動 | memory | 2026-07-07 | feedback:2026-07-07 | P2 | retrieval |
| CC-468 | ⏸ deferred | dispatch brief 帶 memory 約束與信任邊界；完成 CC-465→CC-467 後，僅在 usage evidence 證明有價值時啟動 | ops/memory | 2026-07-07 | — | P2 | retrieval |
| CC-011 | 🟢 someday | sync-memory.sh + install 選項：symlink memory 到雲端資料夾實現跨裝置共用 | ux/memory | 2026-05-14 | — | — | — |
| CC-012 | 🟢 someday | SessionStart hook：session 啟動時 pull 最新 memory（git/rsync）確保跨裝置同步 | ux/memory | 2026-05-14 | — | — | — |
| CC-015 | ✅ done | `systematic-debugging` skill：結構化偵錯工作流；作為升級規則(CC-493)定案後的首個試點 skill，落地於 `skills/systematic-debugging/SKILL.md` 而非 slash command | ux | 2026-05-14 | pr:#518 | P3 | — |
| CC-018 | 🟢 someday | Codex quota 自動追蹤 + rate-limit 路徑統一（吸收 CC-269）：寫到 `~/.local/share/pm-dispatch/state/rate-limits.json`；解析 API response headers；token-usage.sh 加 Codex pool 顯示 | ux/token | 2026-05-14 | — | P3 | — |
| CC-023 | ⏸ deferred | `coupling-reviewer`：PR gate 加入語言感知耦合分析（dependency-cruiser/gocyclo/coca） | ops/gate | 2026-05-14 | — | — | — |
| CC-026 | 🟢 someday | `/skill-distill`：偵測重複工作流，產出草稿 skill .md | ux/memory | 2026-05-15 | — | P3 | — |
| CC-032 | ✅ done | 私有 memory cross-link 公開化：使用者面向 doc 3 處 inline 展開、規劃紀錄 ~24 處 `[[slug]]` 改 backtick／正規 link、新 `lint-doc-wikilinks.sh` CI enforce（v0.12.0 contract candidate） | process/DX | 2026-05-15 | — | P2 | — |
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
| CC-244 | ✅ closed 2026-08-23 | **[Typed artifact pipeline — spike → brief → handover schema]** Spike concluded **Reject**: sampled spike docs don't fit the proposed `spike_v1` five-part schema, the courier-cost premise is unverified, and the candidate tooling (`spike-validate.sh`/`gen-brief-from-spike.sh`) is premature. See `docs/spikes/CC-244.md`. | arch | 2026-05-23 | — | — | spike |
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
| CC-358 | ✅ done | runner telemetry：`pmctl run-stats` per-adapter 成功率/失敗模式/fallback 分析（v1.0 readiness 證據；v0.11.0） | ops/memory | 2026-06-10 | pr:#523 | P2 | design |
| CC-359 | 🟢 someday | concept: backlog-driven batch dispatch with worktree isolation（PM manages `git worktree` lifecycle；executor-agnostic；human-in-the-loop merge；PR-only output） | arch/ops | 2026-06-11 | — | — | design |
| CC-364 | ✅ done | **[perf: `pmctl trace tail --all` per-event jq spawn]** `trace tail` scan phase reworked from two jq spawns per event (plus one per row in the human emitter) to a single `jq -R` streaming pass over the concatenated archive+active stream; ~24s→0.2s for 400 events, jq invocation count now fixed regardless of event count. Behavior parity preserved (filters, inclusive time window, malformed tolerance, chronological merge, limit/--all, compact-JSON byte identity). **See**: pr:#270, pr:#546 | ops | 2026-06-12 | pr:#270, pr:#546 | P3 | hygiene |
| CC-369 | ⏸ deferred | Windows state store 真實 ACL via icacls（parked: CC-370；border case relative to profile ACL protection） | ops/portability | 2026-06-13 | — | — | hygiene |
| CC-370 | ⏸ deferred | **[native Windows support deferred to post-core platform phase]** 核心功能開發期間正式只支援 Linux + WSL2（WSL2 視為 Linux）；原生 Windows Git Bash 非官方支援，使用者走 WSL2。理由是專注：開發期同時扛多平台會排擠核心功能（CI 只測 Linux，每次碰 Windows 都要人工驗證 + gate churn，見 #272/#273）。已合併的 portability 程式碼保留（綠且成本低），但不再新增 Windows 分支，直到核心定型（v0.5.0+）後的專屬平台階段。Parks: CC-038, CC-104d/e/f/g/j/k/r/s, CC-369。**See**: DECISIONS.md 2026-06-13 defer-native-windows-support-during-core-dev | ops/portability | 2026-06-13 | — | — | design |
| CC-377 | ⏸ deferred | adapter: Google Antigravity（`agy`）executor（DEFERRED：headless CLI 1.0.8 不成熟；resume: newer agy with `--output-format stream-json`；umbrella: CC-333） | arch/portability | 2026-06-13 | — | P2 | design |
| CC-390 | ⏸ deferred | codex dispatch trace-capture 強化（FD inheritance cold-start flake；fail-closed safe；resume: stable repro；umbrella: CC-333） | arch/portability | 2026-06-15 | — | P3 | design |
| CC-393 | 🟢 someday | design: portable-skill-substrate — CLI-agnostic skill 控制層（design seed after v0.6.0 N≥2；3 control skills + Portable Skill v0 frontmatter；umbrella: CC-333） | arch | 2026-06-16 | — | — | design |
| CC-435 | 🟢 someday | **[poll→通知機制 single-waiter guard：條件觸發，非既定後續票]** 只有在真正出現多個 waiter 需要同時等待同一個 run_id/gate_id 的場景時才拿出來討論；候選設計見 `docs/spikes/CC-433.md` Open risks（方案 A：`flock` 搶鎖+敗者退回輪詢；方案 B：per-waiter 專屬 fifo+supervisor 廣播）。CC-434 完成後重新盤點成本效益：輪詢 vs blocking read 在單一 waiter/數分鐘等待場景下資源消耗差距趨近於零，延遲改善（≤2s→近乎即時）對人在等 gate 結果無感，而兩個方案都要在安全敏感的 supervisor 檔案引入新 race condition，投資報酬率目前不足，故不排入既定實作，僅記錄設計供未來觸發條件成立時起步。 | arch/gate | 2026-07-02 | — | P3 | design |
| CC-446 | ✅ done | public contract candidate：stable/experimental CLI + schema、SemVer/deprecation 政策；Slice B `docs/stability-contract.md` + 首輪 CLI 分類（#564），Slice C `lint-deprecation-sunset` + `threshold_days` 移除，CC-296 兩個具名目標早於 v0.5.0／v0.3.0 移除。Req 6（config-surface authority 標記，~44 檔）拆出 [[CC-578]] | process/DX | 2026-07-04 | pr:#560, pr:#564 | P2 | design |
| CC-447 | 🔵 active | onboarding 三 smoke：offline clean install + N-1 upgrade（v0.11.0）+ live dogfood（readiness review 後再排） | docs/ops | 2026-07-04 | — | P2 | — |
| CC-472 | 🟢 someday | spike: antigravity（`agy` CLI）host 唯讀 probe——比照 CC-436/CC-448 階段 1 模式，實測 command 載入能力 + hook/plugin 機制 + 五個 capability enum 的 provider/confidence 判定，不落地 `hosts/antigravity/host.yaml`；排在 CC-445 通用 install/uninstall dispatcher 之後、與 CC-448 opencode 同批或緊接其後評估（N=3 驗證點） | arch/install | 2026-07-08 | — | P3 | spike |
| CC-566 | ✅ done | `guard-inject-memory.sh` 依 host 給獨立注入預算：實測確認 Claude 端有原生 `claudeMd` 全量 MEMORY.md 載入（無上限，session 一次）與 hook 每輪裁切注入雙重疊加；Codex 無對應原生全量安全網，不能單純調降全域常數（2026-08-23 token-cost 分析） | memory/DX | 2026-08-23 | pr:#519 | P2 | hygiene |
| CC-567 | ✅ done | memory `selected`→`applied`→`outcome` 追蹤：擴充 `pmctl memory stats` 既有 matched/injected 遙測，補上「PM 是否判為相關」「是否真的影響 brief/執行」「是否真有幫助」三段缺口（2026-08-25 memory 架構設計討論；本題優先序高於分類法，見 [[CC-570]]） | memory/DX | 2026-08-25 | pr:#532 | P1 | retrieval |
| CC-568 | 🟢 someday | `/mem-distill` Case→Strategy 機械式提升：對 `episodes.jsonl` 既有結構化欄位做 count/cluster 門檻判定，取代逐次主觀「感覺像 pattern」的判斷；依賴 [[CC-567]] 的 outcome 證據決定是否值得做（2026-08-25 memory 架構設計討論） | memory/DX | 2026-08-25 | — | P2 | retrieval |
| CC-569 | 🟢 someday | `pmctl task` / `context pack` 擴充 working-memory 敘事欄位（`selected_memories`／`rejected_paths`／`blockers`／`next_action`）：延伸既有 schema，不新建第二個「現在在幹嘛」真相來源；依賴 [[CC-567]] 證明有價值後再排（2026-08-25 memory 架構設計討論） | memory/DX | 2026-08-25 | — | P2 | design |
| CC-570 | 🟢 someday | Fact/Case/Strategy `memory_function`／`memory_subtype` metadata 分類法：先蒐集 [[CC-567]] 的 applied/outcome 證據，再決定值不值得建分類機制——不憑直覺先建立稅務式標籤（2026-08-25 memory 架構設計討論；外部文章優先序建議相反，本 repo 刻意反過來） | memory/DX | 2026-08-25 | — | P3 | retrieval |
| CC-571 | ✅ done | `_ctx_fts_rebuild`／`_ctx_index_file` 共用的 sqlite atomic-script 缺口：DROP+CREATE+INSERT 未加 `-bail`（實測 sqlite3 CLI 預設不會在錯誤時中止，單靠 BEGIN/COMMIT 不足）、呼叫端不檢查回傳值、`_ctx_index_file` 還有第三個獨立 bug（`rm -f` 蓋掉 sqlite3 真實 exit code）；`/simplify` altitude review 抓到手足函式同缺陷，範圍已擴大涵蓋兩者（[[CC-548]] spike 的 Open risks 側面發現，非本票 tokenizer 範圍） | memory/ops | 2026-08-26 | pr:#539 | P2 | hygiene |
| CC-572 | ✅ done | pr-gate synthesis retry（sequential／parallel 兩條路徑）留下已存在但 0 bytes 的 `$OUTPUT_FILE`，executor 的 patch 工具仍可能選擇 Update File 而非 Add File 語意，對空內容找不到 context line 而崩潰（`apply_patch verification failed`）；CC-571 gate saga 連續四輪協定失敗實測發現（2026-08-26） | gate/ops | 2026-08-26 | pr:#541 | P2 | hygiene |
| CC-573 | ✅ done | `pmctl run-stats` 每個事件行 fork 一個 jq（`pmctl_run_stats_extract_line`），與 [[CC-364]] 修掉前的 `trace tail` 同形狀。實測 jq 呼叫 N+2、~34ms/event，真實 6642 行 `events.jsonl` 時 `run-stats --json` 前景 2 分鐘 timeout。改為單次 `jq -R` 串流 over 串接的 archive+active：jq 呼叫 102/302/902 → 2/2/2、牆鐘 3-30s → 0.19s 打平、輸出對 origin/main 逐位元組相同。archive+active 串接 idiom 與 `pmctl-trace.sh` 重複 ~12 行，兩 consumer 下不抽、file header 記錄理由 | ops | 2026-08-27 | pr:#547 | P2 | hygiene |
| CC-574 | ✅ done | `tests/shell/test-run-all-tests.sh` 手抄一份 `SUITE_NAMES`（~106 筆）與 `suite_path()` case（~106 筆），與權威的 `tests/lib/test-suite-runner.sh` `SUITE_NAMES`／`SUITE_PATHS` 平行維護——新套件要同時改兩處，漏改則 `known-suite-count` 紅（`suite-registry-mirror`；本 session CC-538／CC-536 各踩一次）。改為 meta-test 開場 awk-parse 權威 registry 推導出自己的 list，移除鏡像；lint.yml 的 per-suite job 由 `lint-test-suite-registry.sh` 交叉檢查、非靜默漂移鏡像，不在本票範圍 | ops/test | 2026-08-28 | pr:#550 | P3 | hygiene |
| CC-575 | 🟢 someday | test-governance Batch 1 存量遷移：把其餘 ~35 處 `pass "$name (... unavailable ...)"`（多在 `test-doctor.sh` 的 jq guard、也有 `test-core-schemas`／`test-install`／`test-pmctl-memory`／`test-runtime-lib-coverage` 的 `UNAVAILABLE:` 裸行）改用 case-level `skip()`。primitive 與 authoritative gate 已於 pr:#<TBD> 落地並遷移 6 個代表站點；本票只做剩餘機械遷移，不再動 harness/runner/schema | ops/test | 2026-08-28 | — | P3 | hygiene |
| CC-576 | ✅ done | 測試成本重新規劃（實測基線）：全套 10,764 CPU-s／110 suite，`test-pr-gate` 4 shard 佔 49.1%、top-10 佔 72%、其餘 85 個 suite 只佔 6.1%。成本不是「測試太多」也不是「斷言劣質」（290 case 只有 9 個純文字斷言），而是 243 個 case 每個都 spawn 一次真的 `pr-gate.sh`（uncontended 實測 mean 8.2s／p90 18s）。唯一會複利的槓桿是把行為從 integration 層（8.2s/case）搬到 unit 層（`test-gate-protocol` 實測 0.12s/case，68×），也就是續拆 `pr-gate.sh` 時**同時搬測試**；已辨識 57 個可搬 case（pre-dispatch policy 29 + brief-composition 28）。本票只定基線、判準與順序，不含實作 | ops/test | 2026-08-29 | pr:#560 | P2 | design |
| CC-577 | ✅ done | lint 規則穿測試外衣的 case 退場（評估 4 個、搬 2 個、留 2 個）：`test-pmctl-memory.sh` 的 `case_memory_shared_readers_avoid_bash_43_namerefs`（grep 3 個硬編檔禁 `local -n`）、`test-dispatch-common.sh` 的 `case_dispatch_common_no_adapter_name_in_code`（grep 禁 adapter 字面值）、`test-host-manifest.sh:596`（grep `doctor.sh` 格式字串）、`test-e2e-script.sh` 的 `test_phase_c_commits_context_ignore`（斷言腳本內文含某行而非跑它）。全語料掃描確認只有這 4 個是真 proxy（另 12 處讀 production 檔的斷言都合法）。搬進 `test-layer-boundaries.sh`（既有「掃 ROOT + fixture 種違規」模式、全套 1 秒）：規則從「查 3 個硬編檔」變「掃整棵樹」覆蓋變強；e2e 那個改真跑再驗檔。買到的是先例與覆蓋強度，不是時間（4 case 省不到 5s）。是 [[CC-576]] Req 2「測試層級判準」的示範案例 | ops/test | 2026-08-29 | pr:#559 | P3 | hygiene |
| CC-578 | 🟢 someday | config-surface authority 標記（[[CC-446]] Req 6 拆出）：每份 manifest／schema／registry／policy／layout spec（~44 檔：19 `core/schema/*.json` + 20 `*.yaml` + 5 `core/policy/*.tsv`）標記為 `runtime authority`／`build-time authority`／`parity/documentation spec`；runtime／build-time authority 必須有單一 consumer/generator 路徑與 drift check，不得一面宣稱 source of truth 一面維護等價手寫實作。多為逐檔判斷、多數需新增 drift 測試，是獨立多 PR 工程；與 [[CC-451]] 同批評估（runtime 從不驗證的 schema 不列 stable） | process/DX | 2026-08-30 | — | P2 | design |

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

## CC-446 — v1.0 契約凍結：stable/experimental 分級 + SemVer/deprecation 政策 ✅ 2026-08-30

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
6. 每份候選 manifest、schema、registry、policy 與 layout specification 都標記為
   `runtime authority`、`build-time authority` 或 `parity/documentation
   specification`；runtime/build-time authority 必須有單一 consumer/generator
   路徑與 drift check，不得一面宣稱 source of truth、一面維護等價手寫實作。

**Done-when**：分級表覆蓋全部 pmctl 子指令與 schema 檔；CC-296 清掃完成；repo 內無「標 deprecated 但無移除計畫」的懸空表面；README 與分級文件互相一致。

**Dependencies**：吸收 [[CC-296]] 執行。[[CC-451]]、[[CC-460]] command inventory、[[CC-498]] state compatibility 為事實前置。Cross-link [[CC-286]]、[[CC-357]]、[[CC-531]]～[[CC-539]]。v0.12.0 contract candidate；完成後才進行 v1.0 readiness review。

**Progress (2026-08-30, re-scope against current repo)**：
- **Problem 部分過期**：CC-296 的兩個具名目標早已移除——`pmctl guard check --profile` alias 於 v0.5.0（[[CC-291]] #205）、`scripts/codex-dispatch.sh` shim 於 v0.3.0 sunset。「執行 CC-296」如字面所寫是 no-op；Req 3 視為已完成。live 的 `install.sh --profile minimal|full` 是**現行功能**、與已移除的 alias 無關。
- **剩餘 deprecated 表面是新一代**：`scripts/*.sh` = 19 個 [[CC-489]] 路徑遷移 shim；`docs/pr-gate-handover-schema.md`（v0.6.0 retired）。
- **分類基礎設施已存在**：`cli/commands.tsv` 早有 8 欄含 `stability`／`json` 欄，`lint-pmctl-commands.sh` 驗 registry↔router↔README parity，`pmctl commands --json`（[[CC-460]]）已出貨。
- **拆片**：
  - **Slice B ✅（本次 PR）** = `docs/stability-contract.md`（四層詞彙 + SemVer 範圍 + deprecation 流程 + evidence 限制聲明）+ `cli/commands.tsv` 首輪分類（`commands`／`state status` → `stable`，其餘 `experimental`）+ lint 規則「stable 非 mutating ⇒ json=true」+ handover 文件三處引用改歷史語氣。Req 1（詞彙與 table 骨架）、Req 2、Req 4、Req 5a（lint 半）交付；`stable` 集合刻意極小。
  - **Slice C ✅** = `tools/lint/lint-deprecation-sunset.sh`（掃 docs deprecation banner／`core/schema` `deprecated` keyword／`cli/commands.tsv` `stability=deprecated`，每個要具名 `vX.Y[.Z]` 或進 `deprecation-sunset-allowlist.tsv`）+ 把 `stability-contract.md` 的「target invariant」改成真 invariant（雙 enforcer：新 lint + `lint-script-domain-inventory.sh` 對 `scripts/*.sh` 的既有守門）。**shim 決策 = KEEP**：19 個 `scripts/*.sh` 是 [[CC-489]] ratchet 的受治理層（有 owner + drift check + reference allowlist），不是懸空表面；移除＝改動 CC-489 ratchet，投報比低（complexity economics），列 [[CC-578]] 不做的清單外的獨立選項。
  - **Slice D**：Req 5b ✅（`core/state/layout.yaml` 移除兩個宣告未實作的 `threshold_days: 90`）；**Req 6（authority 標記，~44 檔）拆出 [[CC-578]]**——逐檔判斷 + 多數需新增 drift 測試，是獨立多 PR 工程，不擋 stability contract 的價值。
- `stable` 凍結基礎明寫「maintainer-exercised + suite-covered evidence, not clean-machine dogfood」（[[CC-447]] environment-blocked）。

**結案 2026-08-30**：Slice B（#564）+ Slice C + Req 5b 交付；CC-296 清掃早於 v0.5.0／v0.3.0 完成；Req 6 拆 [[CC-578]]。stability contract 詞彙、SemVer 範圍、deprecation 流程與其 CI enforcer 皆落地。

**See**: DECISIONS.md 2026-07-04；pr:#560（判準+順序）、pr:#564（Slice B）

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

**Done-when**：在 v0.11.0 release candidate 上，三個 smoke 的實測報告 committed（`docs/notes/` 或票內）；clean install 與 N-1 upgrade 都有可重現證據；摔倒點全部開票；GETTING_STARTED 修正到與實測一致。

**Dependencies**：offline/N-1 smoke 在 [[CC-497]]、[[CC-456]]、[[CC-449]]、[[CC-503]] 後，且 v0.11.0 release freeze 中執行；live smoke 不預先綁 v1.0，待 v0.12.0 後 readiness review 排程。
**See**: DECISIONS.md 2026-07-04

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

## CC-559 — memory usage sidecar 無法記錄含 tab／newline 的卡片路徑 ✅ 2026-08-23

**Problem**: usage sidecar 是 tab-delimited 格式，其 writer 拒收含 tab 或 newline 的
relpath（`runtime/lib/pmctl-memory.sh` 內 `unmeasurable_cards` 分支的註解載明此約束）。
這類記憶卡因此**永遠不可能累積任何使用紀錄**，不論實際被注入幾次。

**Why**: `pmctl memory stats` 目前的處理是誠實的——把它們列進 `unmeasurable_cards` 而非
`never_hit_cards`，因為「從未命中」是一個關於使用的**斷言**，而這條路徑上的遙測從來沒有
測量過，報成 never-hit 等於用「沒量到」冒充「沒發生」。但誠實回報不等於修好：根因是儲存
格式無法表示這些路徑。

**當初為何不做**: [[CC-467]] 的 Requirement 3 明文限定「不新增寫入面，只聚合既有資料」，
而無損編碼是寫入面變更，因此當時就宣告為 follow-up。

**Requirement**:
1. sidecar 改用可表示任意 POSIX 路徑的無損編碼（如逐欄 escape 或改用可容納分隔字元的格式）。
2. 既有 sidecar 需有遷移路徑；不得讓既有使用紀錄歸零。
3. 遷移後 `unmeasurable_cards` 應恆為空；若仍有無法表示的輸入，必須保留誠實回報而非改口
   稱 never-hit。

**Priority note**: 檔名含 tab／newline 的記憶卡屬病態情形，實務發生率極低，故列 P3
🟢 someday。列票的目的是**不讓這個已知缺口隨 [[CC-467]] 封存而消失**。

**Cross-link**: [[CC-467]]（本 follow-up 的來源票）、[[CC-466]]（生命週期判斷建立在遙測
可信度之上）。

**Closure 2026-08-23 (pr:#521)**：SQLite 與 TSV 兩個後端在共用的 tab-分隔傳輸邊界統一
escape／unescape；unescape 改用左至右字元掃描（無 sentinel byte），避免與真實 0x01
位元組碰撞。兩個後端各自補上 `# schema=2` 一次性遷移標記，讓既有（CC-559 之前寫入、
從未轉譯過）的原始資料不會在升級後被誤判成含逃逸序列——SQLite 端在 `card_relpath`
維持原始／canonical 儲存、只在 `SELECT` 進入共用邊界時轉譯；TSV 純檔案端因為本身就是
文字格式、沒有欄位邊界，仍需標記判別已轉譯／未轉譯兩種既有格式。三輪 pr-gate（parallel,
codex）後收斂：第一輪抓到 sentinel 碰撞與 SQLite 遷移缺口；第二輪抓到 TSV 端同款遷移
缺口未修，以及 3 個測試在 sqlite3 缺席時靜默宣稱通過；修正後第三輪 GO。新增 4 個回歸
測試（SOH 往返／不碰撞、SQLite 與 TSV 各自的 pre-fix 資料存活驗證）。`unmeasurable_cards`
機制保留但目前恆為空，符合 Requirement 3。

**See**: pr:#521

---

## CC-562 — 多約束共用單一 reason 字串的其餘分支 ✅ 2026-08-21

**Problem**: `runtime/lib/gate-result-verify.sh` 仍有數個分支把多條獨立規則折進同一個 reason
字串：`invalid coverage matrix`、`invalid finding inventory or union`、
`duplicate finding ID collision`、`selected/not-reviewed dimensions mismatch` 等。單次修正重試
只收到這個字串，因此無法知道是哪一條規則、哪一個條目出錯。

**Why**: 與 [[CC-553]] Req 6 同一問題，但**需要不同形狀的 helper**——parity 類用的是集合差集
（`id_delta`），這一類要的是「逐項指出違規條目與它違反的規則」，即同檔 `disagreement_defect`
的樣式。CC-553 因此判定分票而非硬併。

**明確不做**: `invalid top-level contract` 與 `invalid synthesis JSON document` 不需同等精度
——兩者代表產出物整體損毀，重試需要的是 schema 而非某個 id。此判斷已記於 [[CC-553]]。

**Requirement**:
1. 沿用 `disagreement_defect` 既有樣式，逐項指出違規條目與違反的規則，不另立風格。
2. 引用被拒產出物中的值時一律經 `safe_token`／`safe_join`（該值來自不可信來源且會被帶進下一個
   privileged brief）。
3. 驗證併入既有 table-driven case `synthesis-protocol/diagnostics-name-the-defect`，逐列 mutation
   驗證，不新增獨立 case。

**實戰佐證（2026-08-20）**：[[CC-561]] 的 targeted 重新 gate 因
`remediation confirmation set mismatch` 連續兩次 synthesis 失敗、recovery 用盡而整輪作廢
（`gate-20260819-181456-91ce0d`）。該 reason 屬本票類別——只說「不符」，不說少了或多了哪些
confirmation，因此重試無從行動。**這是本票從「理論上該修」變成「已知成本」的第一筆實測。**

**Cross-link**: [[CC-553]]（Req 2 的判斷來源）、[[CC-549]]（reviewer 端同一修法）、
[[CC-561]]（實戰佐證來源）。

**Closure 2026-08-21 (pr:#510)**: 沿用 `disagreement_defect` 樣式，為
`runtime/lib/gate-result-verify.sh` 新增 `coverage_cell_defect`、
`finding_inventory_defect`、`finding_union_defect` 三個逐項指出違規條目與規則的
helper，並套用到四個分支：`invalid coverage matrix`（逐格指出 reviewer/surface
與違反的欄位規則）、`invalid finding inventory or union`（逐條列出 inventory／
union 條目與規則）、`duplicate finding ID collision`（分別列出 inventory／union
各自的重複 id）、`selected/not-reviewed dimensions mismatch`（用既有 `id_delta`
指出 selected_reviewers／not_reviewed_dimensions 何者、缺什麼、多什麼）。所有
引用值一律經 `safe_token`／`safe_join`。驗證併入既有
`synthesis-protocol/diagnostics-name-the-defect` table-driven case（未新增獨立
case），窮舉 `coverage_cell_defect`（7 條）、`finding_inventory_defect`（8 條）、
`finding_union_defect`（15 條）每一個判斷分支各自的 mutation 與預期診斷文字，
外加 `not_reviewed_dimensions` 本身的 mismatch（而不只 `selected_reviewers`）。
兩輪 pr-gate（parallel, codex）NO-GO 後收斂：第一輪 qa-tester block-soft／
critic／security-reviewer advise 指出新分支只測一條規則、`not_reviewed_dimensions`
分支缺失、且未比照既有 `diagnostics-neutralize-injected-ids` 驗證新分支注入
安全；第二輪 qa-tester block／critic block-soft 指出 inventory／union 仍有未
覆蓋的分支。修正：table 補齊至 50 個 mutation 列，並把注入安全測試改成
table-driven，新增 coverage-cell／inventory／union 三個注入案例；
`synthesis-protocol/*` 全套 20 case 綠燈。`invalid top-level contract`／
`invalid synthesis JSON document` 依票面「明確不做」維持未變動。

**See**: pr:#510

---

## CC-560 — reference index 仍是每筆一個 jq process ✅ 2026-08-21

**Problem**: `_gate_scope_reference_index_collect` 對每一筆 reference 都執行一次
`jq -nc` 建立 JSON 物件並附加到檔案。[[CC-557]] 的 profile 實測該函式耗時 4.9s（一次 gate 內
呼叫兩次），是修掉 expansion collector 之後 scope manifest 建構的最大剩餘成本。

**Why**: 與 [[CC-557]] 修掉的 `_gate_scope_expansion_append` 是**同一類寫法**——per-record
process spawn。CC-557 之所以沒有一併處理，是因為修完 expansion 之後預算餘裕已從 84-86%
降到約 21%，繼續優化沒有立即效益；**不是因為這個問題不成立**。

**Requirement**:
1. 沿用 [[CC-557]] 已驗證的做法：append NUL 分隔欄位，由既有的收尾 jq pass 一次解碼。
   NUL 安全性是結構性的（bash 字串不可能含 NUL），不依賴跳脫。
2. 修改前後以 jq wrapper 計數與階段計時佐證，不憑猜測。

**Cross-link**: [[CC-557]]（同類寫法的第一次修正，含 profiling 方法）。

**Closure 2026-08-21 (pr:#511)**：沿用 [[CC-557]] 已驗證的做法，`_gate_scope_reference_index_collect`
逐筆 `jq -nc` 建物件改為 4 個 NUL 分隔欄位（path/snapshot/line_count/sha256）
append，迴圈結束後由唯一一個 `jq -Rs` pass 解碼＋`unique_by(.path)`＋
`sort_by(.path)`，輸出 shape 與排序邏輯不變。

**Profiling 佐證（合成 fixture，300 個 reference path，PATH shim 計數 jq 呼叫）**：
修正前 302 次 jq 呼叫／約 10-12s；修正後 2 次 jq 呼叫／約 2.5s。修正前後輸出
（`jq -S` 正規化後）逐位元組相同，確認純效能修正、無行為變更。

**pr-gate 第一輪（express，sequential，critic/qa-tester）NO-GO（1 block + 1 advise）**：
qa-tester 與 critic 各自獨立指出同一根因——既有 `scope-manifest` 整合測試只驗證
「聚合套件綠燈」，沒有針對這個新的 NUL positional decoder 本身的直接 fault-sensitive
regression（欄位順序、去重、排序若壞掉，聚合測試不保證會抓到）。修正：新增
`scope-collector/reference-index-direct-decode`——不經過完整 gate dispatch，直接
`source` `runtime/lib/gate-scope.sh` 呼叫 `_gate_scope_reference_index_collect`，
輸入含一個重複路徑，斷言輸出與獨立算出的 sha256 digest 逐位元組相符；已驗證此測試
具 fault-sensitivity（暫時把 decode 的 NUL 分隔符改壞會讓測試失敗）。

`tests/shell/test-pr-gate.sh --filter scope-` 14 案全過（含
`large-expansion-uses-file-input`、既有斷言 `reference_index.entries` 的
`complete-and-shared-parallel` 案，與新增的 direct-decode 案）。

**See**: pr:#511

---

## CC-554 — 永久 regression test 的准入門檻（Batch 0） ✅ 2026-08-29

**Problem**: `/ship` 要求「high／medium／low、hard gate／advisory 全部修完」，
但沒有規範**修法的形式**。實務上 reviewer 每提出一個新邊界，最省事的收斂方式就是
永久新增一個阻擋性 case——即使該 case 鎖定的是私有 helper、source 文字、或專案
根本不支援的輸入。[[CC-467]]（#486）是實例：12 輪 gate、33+ 個 memory stats case，
其中數個永久測試的實際目的已從「防止使用者 regression」漂移成「防止 reviewer 再次
提出同一問題」。長出來的 case 又需要 meta-test 保護，於是測試系統本身成為第二套產品。

**Why**: 這是「為了測試而策」的**流入端**。存量清理（harness skip 語意、exit-code
oracle、memory stats 合併）若在准入門檻之前做，下一個 PR 會原樣長回來。門檻是純規則
變更，零程式碼、不需 gate、不需 full suite，是投報比最高的第一步。

**Requirement**:
1. QA 規則 checkout（`QA_RULES_DIR` 的 Tier 1 entry）新增永久 regression test 的
   六條准入條件與五條替代收斂路徑（修程式不加測試／併入既有參數化案例／移到 extended
   suite／另立 ticket／以證據拒絕不成立的 finding）。
2. `commands/ship.md` 的 NO-GO 收斂段落加入對應例外：**finding 一律要處理，但修法
   形式是判斷**；不符准入條件時改走替代路徑並在 PR body 記錄理由。不得被讀成放寬
   gate——未處理的 finding 仍是 NO-GO。
3. 規則須對「替換掉的 QA 規則 repo」保持健壯：`agents/qa-tester.md` 明載 rules dir
   可替換，故 ship.md 需自帶摘要，不得硬相依於參考實作的節號。

**驗收方式**: 本票的效果不由「規則寫進去了」判定，而由後續 PR 的兩個數字判定——
**A** = 該 PR 新增的永久阻擋 case 數；**B** = 因未過准入條件而走替代路徑的 finding 數
（Step 2.5 要求在 PR body 記錄，故資料由規則自身產生，不需額外工具）。
觀察 2–3 個 PR 後判讀：B 恆為 0 表示閘門未咬合、只是裝飾，應回頭修規則而非繼續往下
做後續批次；A 下降且 gate 輪數未上升表示有效；A 下降但輪數上升表示過頭，reviewer 在
同一點反覆爭論，應放寬准入。

**Update 2026-08-20（第一次讀數；票維持 active）**: 規則自 pr:#490 生效後的
證據窗共 8 個 merged PR。其中 3 個是 docs/chore 未跑 gate；4 個 gate 一輪 GO、
零 finding 零 advisory，因此沒有任何 finding 的補救形式是新增永久測試；只有一個
PR 產生了合格實例——它跑了 3 輪，reviewer 提出 2 個 finding，兩者的補救都是新增
永久阻擋 case，兩個 case 都通過准入條件（各自 mutation 驗證且只失敗自己那一案）。

讀數：合格實例 2 個，A（因 finding 新增的永久阻擋 case）= 2，B（走替代路徑）= 0。

**判定：不能套用「B 恆為 0 ⇒ 閘門未咬合」**。此窗的 B=0 是正確結果而非裝飾——
兩個實例本來就該被 admit。真正暴露的是**驗收指標本身不可證偽**：原規則只在
「選擇替代路徑」時要求留記錄，admit 時不留任何痕跡，因此 B=0 同時相容於三種
情形（未曾查閱／查閱後 admit／沒有合格 finding），單看 B 永遠分不出來。

**處置**: `commands/ship.md` 改為兩條分支都必須記錄——admit 時載明所依據的准入
條件，否則載明所走的替代路徑與理由；並補上該段落的契約斷言（原段落自 pr:#490
起完全沒有測試覆蓋，是它能在 8 個 PR 內漂成不可量測的原因）。A/B 自下一個窗起
才具判別力，故本票不結案，重新起算觀察窗；下次讀數改看「合格實例數 / admit 數 /
alternative 數」三欄，缺記錄本身即為協定失敗而非歧義。參考 QA 規則 repo 的
reviewer-side duty 已要求提出者載明符合哪些條件，author side 先前沒有對稱義務，
該對稱化屬該 repo 的獨立變更，不在本票 scope。

**Update 2026-08-26（第二次讀數；票維持 active）**：對稱記錄規則自 pr:#530
（2026-08-25 生效）起的證據窗已累積 12 個 merged PR，遠超「觀察 2-3 個」的門檻。
逐一比對後找到 2 個合格實例——都是同一位執行者（本 agent）自己交付的 PR：pr:#539
因 gate finding 新增 7 個永久 regression case、pr:#541 因 gate finding 新增 2 個
永久測試函式，兩張 PR body **皆完全沒有**依規則寫「符合哪些准入條件」這一行。

讀數：合格實例 2 個，admit 數（附准入條件記錄）= 0，alternative 數 = 0，**缺記錄
數 = 2**。

**判定**：這次不是「B 恆為 0 的三種情形分不清楚」（上次讀數已排除這個病灶），而是
第三種、更根本的情形——**規則存在且無歧義，但執行者在動筆寫 PR body 的當下沒有
意識到要查它**。純文字提醒（寫在 Step 2.5，PR body 是在後面的 Step 4 才組裝）在
兩次連續合格實例上都沒有被觸發，證明「靠執行者記得回頭查一段前面讀過的規則」這個
機制本身不可靠，不是這次剛好疏忽。

**處置**：把 Step 4 的 PR body 樣板本身加一個 `Permanent test admissions:` 欄位
（原樣板只有 `Refactor/reuse audit`／`Final verdict`／`Full suite` 等既有欄位，
從缺永久測試這一項）。樣板本身是執行者組裝 PR body 時實際會複製的文字，欄位缺席
會讓遺漏顯性化（要嘛填實際記錄、要嘛明寫 `none`），不必再依賴幾個段落之前那句
散文提醒。新增對應回歸測試斷言樣板含這個欄位。A/B 讀數已可信（上次讀數已解決），
故本票仍不結案的理由改變：現在是要觀察「樣板改結構之後，缺記錄事件是否消失」，
而非「A/B 本身能否讀出訊號」。下次讀數起看第四欄——**樣板生效後的缺記錄次數**。

**Non-goals**: 不設 `max_full_review_rounds` 輪數上限——與 `commands/ship.md`
「round count 不是停止條件」直接衝突，且 [[CC-544]] 已證明放寬 gate 收斂條件會被
qa-tester／risk-reviewer 連擋並全數 revert。減量要從 finding 端做，不是從輪數端。

**Update 2026-08-29（結案）**：第三次讀數確認 Step 4 樣板欄位仍未咬合——本週期
又有三個 PR 漏填 `Permanent test admissions:` 行。處置已從「結構欄位」升級為
**CI 機械強制**：`tools/lint/lint-permanent-test-admissions.sh`（pr:#555）在 PR body
漏填／填 `none` 而既有測試檔在 base→HEAD 之間新增 `test_`/`case_` 函式身分時，
直接讓 PR check 失敗。

**結案理由**：三條原始 Requirement 早已交付——Req 1（QA 規則六條准入條件＋五條
替代路徑）與 Req 2/3（ship.md 例外段落＋自帶摘要不硬相依參考實作）於 pr:#490／
pr:#530 落地；其後三次觀察窗讀數各自出貨了對應補救（pr:#499 雙分支記錄、pr:#544
Step 4 樣板欄位、pr:#555 CI enforcer）。本票的「觀察 N 個 PR 看是否復發」驗收條款
在補救變成硬性 CI gate 後即失去意義——復發已被結構阻擋，不再是「觀察合規漂移」。
任何「enforcer 是否校準過頭／不足」的疑慮屬另立窄票，不在本票 scope。A（因 finding
新增的永久阻擋 case）在 `lint-permanent-test-admissions-shipped` 起可由 CI 直接量測。

「測試**退場**機制」（既有測試何時該合併／刪除的對稱另一半，見 memory
`next-phase-complexity-economics-direction`）是獨立概念，若要做另立票，不是本票續命理由。

**See**: pr:#490（Req 1，准入條件）、pr:#530（Req 2/3，ship.md）、pr:#499／pr:#544／
pr:#555（三次讀數的補救）、`cc554-admission-template-slot-shipped`、
`lint-permanent-test-admissions-shipped`。

**Cross-link**: [[CC-467]]（觸發實例）、[[CC-544]]（輪數上限的反證）、
[[CC-537]]（suite manifest，維持 someday）。後續批次見 memory
`test-governance-batches-plan`。

---

## CC-552 — worker-cap 測試以 sleep 製造重疊窗口

**Problem**: `tests/shell/test-lint-shellcheck.sh` 的 `test_default_worker_cap`
用 ShellCheck stub 內的 `sleep 0.1` 撐開一個時間窗，好讓兩個 worker 的
start/end 事件重疊，再以事件序列推算最大併發數。負載高或被搶佔的主機上，觀測到
的重疊數會與 worker-cap 的正確性脫鉤——上限仍是 2，但可能只觀測到 1（現行斷言
`max_active >= 1` 因此會放過），或在極端情況下產生誤判。

**Why**: 這是 QA 規則明文禁止的 sleep 同步。之所以不併入 [[CC-551]]：該票是
pre-existing 缺陷、與 ShellCheck 解析改動無關，且改法本身有風險——把 sleep 換成
檔案式 barrier 時，若併發上限實際為 1，barrier 會等到 timeout 才失敗，正是
[[CC-543]] 記錄過的 FIFO handshake hang 形狀。要在不引入 hang 的前提下取得確定性
重疊證明，需要獨立設計而非順手替換。

**Requirement**:
1. 以確定性的 fixture barrier 或事件協定取代 sleep，證明「同時有兩個 worker」與
   「沒有第三個」，不依賴經過時間。
2. barrier 不得在上限實際為 1 時退化成無界等待；失敗必須是有界且訊息明確。
3. 僅限本測試，不改 `lint-shellcheck.sh` 的併發實作。

**Cross-link**: [[CC-551]]（發現時點）、[[CC-543]]（bounded handshake 的既有教訓）。

**Update 2026-08-26（done，pr:#pending）**: stub `shellcheck` 改用事件式
barrier：每個 worker 起跑時先透過既有的 `serialize_with_lock`（沿用
production 本來就在用的可攜式鎖，而非另外重造一個）原子遞增計數並記錄觀測值；
第一個抵達的 worker 對一個雙向開啟（`<>`，避免只用唯讀/唯寫端造成 open()
本身卡住——這正是 [[CC-543]] 記錄過的 FIFO handshake hang 形狀）的 FIFO 做
有界（5 秒逾時）阻塞式 `read`，第二個抵達的 worker 寫入一行將其釋放，兩者才
一起往下跑；全程沒有任何 `sleep`。斷言也從 `max_active >= 1` 收緊為
`max_active == 2`（原本的門檻對「有沒有真的重疊」其實是無鑑別力的）。若上限
真的退化成 1，第二個 worker 永遠不會出現，逾時後乾脆失敗且訊息明確，而非無界
等待。gate 第二輪 qa-tester 進一步指出：release 的一方寫完信號就立刻繼續走向
deregister，並未等對方真的醒來，若上限退化成 3，前兩個 worker 有機會在第三個
worker 搶到鎖之前就雙雙 deregister，讓事件記錄看起來仍是 2；修法是加第二個
FIFO 做 ack 交握——release 方在放行後阻塞讀 ack，等對方真的從 barrier 醒來並
回覆才繼續，兩邊因此保證同時退場，不會有一方搶先鬆手。已用 `jobs` 改 3 的
mutation 直接驗證：max_active 從 2 變成可觀測到 6，測試如預期紅燈。範圍如票面
Requirement 3 所限，未動 `lint-shellcheck.sh` 本身的併發實作。

---

## CC-548 — context.db FTS5 對 CJK 查詢無索引無排序（spike）✅ 2026-08-26

**Problem**: [[CC-465]] 修好了注入排序與 prompt/reuse-scan 的 CJK 抽詞，但沒有動
FTS5 索引層。`context.db` 的 FTS5 表使用 unicode61 tokenizer，對整段中文只會產生
單一 token，因此中文查詢在 FTS5 上永遠 miss，實務上只靠 LIKE substring fallback
硬撐——沒有索引（全表掃描）也沒有 ranking（`bm25()` 無從施力）。維護者工作語言為
中文，代表 `pmctl context query` 的中文查詢品質與延遲都停留在 fallback 水準。

**Why**: 這是 [[CC-465]] Requirement 3 明文分離出來的關注點——該票原文即載明 FTS5
tokenizer 行為「視為與共用 lib 分離的關注點，允許各自的修復時程與驗收」，因為修法
與共用抽詞 lib 完全不同：不是改 bash 抽詞，而是換 FTS5 tokenizer 並重建索引。候選解
是 sqlite ≥3.34 的 `tokenize='trigram'`（CJK substring 可走索引），但它帶來 sqlite
版本下限與既有 `context.db` 的 rebuild／遷移成本，兩者都必須先量測才知道是否值得。
不預設要做——先 spike，再決定。

**Requirement**:
1. Spike：確認 `tokenize='trigram'` 所需的 sqlite 版本下限，以及該下限對
   [docs/platform-support.md](docs/platform-support.md) 宣稱的支援平台是否可接受（含無 trigram 時的降級路徑）。
2. Spike：量測既有 `context.db` 重建索引的成本與相容性影響（schema 版本、遷移是否
   可省略而直接重建、重建期間的查詢行為）。
3. Spike 產出 `docs/spikes/CC-548.md` 的 GREEN/AMBER/RED 判定；只有判定為值得做時
   才開實作切片，不因票已存在自動實作。
- Result log: docs/spikes/CC-548.md — **AMBER，defer**。sqlite trigram 版本下限
  （3.34.0）對 `docs/platform-support.md` 宣稱的支援平台無硬衝突（該文件未釘選
  sqlite 最低版本），且 `_ctx_fts5_available()` 既有 probe/fallback idiom 可廉價
  延伸出三層降級路徑；`_ctx_fts_rebuild()` 本就每次全量 DROP+recreate，切換
  tokenizer 遷移成本為零。但在本 repo 真實語料（64MB、19806 筆 content_fts）實測：
  rebuild 慢 ~4.9x（0.87s→4.24s）、索引檔大 +32.6%，查詢期間可能撞見表格不存在
  的既有 race window 也隨之等比放大（仍為既有缺口，非本票新增）。品質面：5 個真實
  中文詞抽樣（~68 筆命中）僅 1 筆因 unicode61 把連續中文段落當成單一不可分 token
  而漏收；`bm25()` 在 unicode61 下已有非退化排序——原票「無 ranking」前提經量測不
  成立。效益真實但目前偏小、成本非零，故未達開實作切片門檻；不因票已存在自動實作。

**Cross-link**: [[CC-465]]（本票承接其 Requirement 3 殘留）、[[CC-340]]（deferred；
embeddings/semantic backend——本票是索引層 tokenizer 修正，不是其替代）。

**See**: `docs/spikes/CC-548.md`（AMBER, defer）。

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

## CC-015 — `systematic-debugging` skill

**Status note (2026-08-22)**: The skill is landing in this change.
**Status note (2026-07-15 CC-489 三方 multi-model synthesis）**: 重新定位為 harness/skill 分類下第一個高命中率試點 skill；不再落地為 slash command，改落地於 `skills/systematic-debugging/SKILL.md`（progressive disclosure，thin pointer 風格，比照現有 `skills/dispatch-brief`、`skills/pr-gate-review`）。
**Problem**: debug 工作流目前無標準化流程，每次偵錯方式不一致，容易遺漏根本原因分析。
**Why**: 結構化偵錯步驟（reproduce → isolate → hypothesize → verify → fix → regression test）有助於複雜 bug 分析；同時是驗證「skill = 可替換工作方法、非 workflow engine」定位的第一個實例。
**Requirement**: `skills/systematic-debugging/SKILL.md`，提供結構化偵錯步驟；不執行 state transition、不繞過 guard。
**Sequencing**: [[CC-493]] 已定案（`docs/skill-command-harness-policy.md`）。本票符合
Tier 2（跨 session 重複、可中斷恢復、無權限邊界）判準，落地目標維持
`skills/systematic-debugging/SKILL.md`，可排入實作。

**Update 2026-08-25（done，pr:#518）**：`skills/systematic-debugging/SKILL.md` 已落地，
內容符合 Requirement——結構化偵錯步驟（reproduce → isolate → hypothesize → verify →
fix → regression test）、明確聲明「不執行 state transition、不繞過 guard」。狀態旗標
本次補記：本票 2026-08-22 的 body status note 已寫「landing in this change」，但索引列
從未從 `🔵 active` 翻成 `✅ done`，屬同一批漏更新（見 [[CC-567]]、[[CC-533]]）。

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

## CC-032 — 私有 memory cross-link 公開化（dead-link 防護）✅ 2026-08-31

**交付**：repo 文件裡指向本地 `~/.claude/.../memory/` 的 `[[slug]]` wikilink 對公開讀者是 dead link。實作時發現票的前提已過時——被引用的 `feedback_*` memory 檔多半在 2026-05-15 後的 memory 重組中已不存在（對維護者自己也早是 dead link），故不走原「抽到 `docs/policies/` glossary」路線。

1. **使用者面向 doc（3 處，inline 展開）**：`docs/dispatch-brief.md` 的 `feedback_codex_dispatch_lifecycle_leak`／`feedback_codex_dispatch_foreground` 兩處（原文緊接的句子已把內容寫出，ref 是贅字）；`docs/memory-system.md` 的 `env-var-ambient-leak-into-fixtures` 一處。
2. **規劃紀錄（BACKLOG／MILESTONES／DECISIONS，~24 處）**：指向 repo 檔的 `[[memory-system.md]]`／`[[docs/platform-support.md]]` 改成正規 `[text](path)` link；其餘 `[[memory-slug]]` 去掉 `[[ ]]` 改成 backtick 名稱（`` `suite-registry-mirror` `` 等）——移除 dead-link affordance、保留維護者可辨識的引用名。
3. **`docs/spikes/`／`docs/audits/`／`docs/architecture/` 不動**——時點快照、不維護。
4. **`tools/lint/lint-doc-wikilinks.sh`（新）**：掃 `BACKLOG.md`／`MILESTONES.md`／`DECISIONS.md`／`README.md`／`CONTRIBUTING.md`／`docs/*.md`（排除上述三個子目錄），跳過 fenced code 與 inline code span，任何非 `[[CC-NNN]]` 的 `[[...]]` → fail。CI enforce，防回歸。

**Source**: 2026-05-15 對話 — 公開前置盤點 #3。CC-030（原「schema validator 協同」）與 CC-031 均已不在 backlog。
**See**: `tools/lint/lint-doc-wikilinks.sh` + `tests/shell/test-lint-doc-wikilinks.sh`；`docs/dispatch-brief.md`、`docs/memory-system.md`、BACKLOG／MILESTONES／DECISIONS 的 `[[...]]` 清理。

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

## CC-244 — Typed artifact pipeline: spike → brief → handover schema（spike）✅ 2026-08-23

**Problem**: spike documents today are free-form prose (`docs/spikes/README.md`'s `Problem`/`Angles`/`Findings`/`Recommendation` skeleton, not a machine-parseable schema). The brief-authoring step extracts decisions + handover fields from that prose, which (a) costs PM tokens re-reading the spike, (b) loses invariant checkpoints (no `decisions_resolved=true` flag, so the next agent might re-ask resolved questions), (c) makes main thread inline the whole spike when courier-ing between agents. Whether a typed `spike_v1` schema (frontmatter + named sections, mirroring `dispatch_handover_v1`) is worth the authoring/validator overhead — versus a lighter mechanical extraction that doesn't require a new schema — is not yet decided.

**Why**: originally deferred to someday because only one spike doc existed (CC-060) and schema leverage scales with N. As of 2026-08-23, `docs/spikes/` holds 28 result files, all sharing the same de-facto structure (per `docs/spikes/README.md`) — the trigger condition ("3+ spike docs exist and the brief-extraction pattern repeats") is met. Before writing an implementation brief, the spike must confirm the schema shape actually reduces courier cost across real spikes, not just in the single-example design sketch below.

**Design sketch (input to the spike, not a committed decision)**: define `spike_v1` schema mirroring the existing `dispatch_handover_v1`:

```yaml
---
spike_id: CC-060
status: phase_3_ready    # phase_1_raw | phase_2_synthesis | phase_3_ready
decisions_resolved: true
branch_base: origin/main@f905db7
ticket_ids_consumed: [CC-242]
project_tooling: {makefile: false, backlog_render_target: false}
---
### scope
### findings
### constraints
### decisions
### phase3_handover     # bridges directly to dispatch_handover_v1
```

Candidate follow-on tooling: `tools/spikes/spike-validate.sh` (mirror `handover-validate.sh`) + `tools/spikes/gen-brief-from-spike.sh` (mechanical extraction).

**External reference (2026-07-07 openyida 跨專案分析)**: openyida 的 "generate-page" 產出物 manifest 模式（生成物本身攜帶 manifest 描述其結構，供後續 AI 編輯安全定位）是本票 `spike_v1`/`dispatch_handover_v1` schema 化構想的外部佐證之一。

**Requirement**:
- Investigation scope:
  1. Retrofit-fit check — sample several of the 28 existing `docs/spikes/*.md` files against the design-sketch schema: does their actual content map cleanly onto `scope`/`findings`/`constraints`/`decisions`/`phase3_handover`, or does real spike content resist that shape?
  2. Courier-cost claim — is main-thread token/re-read cost from prose spikes actually measurable/significant, or was the original premise (b)/(c) more assumption than measured?
  3. Frontmatter vs. sidecar — should structured fields live as spike-file YAML frontmatter (like this sketch) or a separate JSON sidecar per spike, and how does `decisions_resolved=true` avoid re-asking resolved questions in practice (what reads that field, and when)?
  4. Validator/tooling scope — is a dedicated `spike-validate.sh` + `gen-brief-from-spike.sh` pair justified now, or does the same leverage come from a lighter convention (e.g. a required frontmatter block checked by existing lint) without new scripts?
- Done-when: the spike states an adopt/defer/reject verdict on introducing `spike_v1`, and if adopt, commits the schema shape (frontmatter vs sidecar), the field list, and which of the two candidate tools (if any) are in scope for the follow-up implementation ticket.
- Result log: docs/spikes/CC-244.md — **Reject**. 0/6+ sampled spike docs (not an exhaustive review of all 28) map onto the sketch's five-part schema (phased spikes actively resist it; the shape already in de-facto use is `docs/spikes/README.md`'s own six-part skeleton); the courier-cost premise (b)/(c) is unverified — no consumption script exists, lazy-read discipline already predates this ticket, no incident of re-asked resolved questions found; `decisions_resolved` has zero producer/consumer anywhere in the repo; `spike-validate.sh`/`gen-brief-from-spike.sh` are premature (no `spike_v1` corpus to validate/extract from, and `handover-validate.sh`'s complexity precedent doesn't transfer — no shell-injection surface). No follow-up ticket opened; re-open only on a measured courier-cost incident.

**See**: `docs/spikes/CC-244.md` (Reject verdict), CC-243 (snapshot fields already aligned).

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

**Milestone**: v0.11.0（stable-readiness operational evidence；原 v0.13.0）。

**Priority**: P2。

**Update 2026-07-04（someday → active；具體 DoD）**: v1.0 的「穩定性有證據」承諾以本票為 reader——release 宣稱不能只靠「最近沒炸」。DoD：
1. `pmctl run-stats --since <date> --by-adapter [--json]`：統計 dispatch/gate terminal outcome 分佈、post-verify failure、missing terminal event、adapter nonzero exit、fallback 使用次數。
2. 不做 dashboard（[[CC-063]] 維持 deferred）；先有 reader 與可引用的報告。
3. RELEASE_CHECKLIST 新增證據項：「v1.0 rc 期間至少 N 次真實 dispatch/gate 有統計報告、無未解釋的系統性 failure」；v1.0.0 release notes 附 run-stats 報告。

**Cross-link**: `events.jsonl` (data source), `pmctl trace tail` (existing consumer, read model to build on), [[CC-234]] (write side of memory loop — episodes 可補充 events 的語意), [[CC-346]] (paused; needs CC-356 evidence first, this ticket adds more evidence dimension).

**Update 2026-08-24（done）**: `pmctl run-stats [--since <date|datetime>] [--by-adapter] [--json]` 出貨，DoD 三項全數達成：
1. 統計 dispatch terminal outcome 分佈（ok/failed/cancelled）、post-verify failure（`note:partial`）、missing terminal event、adapter nonzero exit、fallback 使用次數；預設 archive-inclusive（同步掃描 `archive/events-*.jsonl.gz`，比照 `pmctl trace tail`），gzip 不可用時明確在 `_meta` 與 stderr 說明降級為僅掃 active file。
2. 未做 dashboard；純 reader，`--json` 輸出 `{_meta, adapters}`。
3. RELEASE_CHECKLIST 新增 v1.0.0 專屬證據項（§5）與 feature matrix 列。

順帶新增 `fallback_used` event payload 欄位：opencode adapter 的 model fallback_chain 透過 footer 回報，`pmctl dispatch run` 寫入 events.jsonl，run-stats 可查詢（原本規劃排除，經 4 輪 pr-gate 後決定納入實作而非僅記錄限制）。4 輪 targeted gate 後 GO（sequential mode），見 PR。

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

## CC-364 — perf: `pmctl trace tail --all` per-event jq spawn ✅ 2026-08-27

**See**: pr:#270, pr:#546

`pmctl trace tail --kind <kind> --all --json` is O(n) with a high per-event constant — measured ~20s for 338 events (~60ms/event), consistent with spawning a `jq` (or equivalent subprocess) per event rather than a single streaming pass. Discovered while diagnosing the #270 context-telemetry test flakiness: `context.queried` / `context.reuse_scanned` events accumulate in a partition, and the readback assertions called `trace tail --all`, so reads degraded as the partition grew. The tests were de-coupled from this — context telemetry now honors `PM_DISPATCH_STATE_ROOT`, so the suite isolates all state into a throwaway root — leaving this as a standalone reader-performance follow-up, not a blocker. Fix: rework `trace tail` filtering/serialization as a single `jq` pass (or a streaming reader) over `events.jsonl`.

**Closure 2026-08-27 (pr:#546)**: scan phase is now one `jq -R` streaming pass over the concatenated `archive + active` stream — it classifies each line (malformed / filtered-out / kept) and emits kept rows as `<ts>\t<line_no>\t<compact-json>`, using jq's cumulative `input_line_number` as the global read-order tiebreaker for events sharing a timestamp. Both emit helpers stream through one jq via `cut -f3`. Five module-global `_PMCTL_TRACE_*` vars and three per-line scan helpers removed.

**Perf evidence**: 400 events `--all --json` ~24s → 0.2s (~100x). New `case_trace_tail_single_jq_pass` shims a counting `jq` onto PATH and asserts the invocation tally is equal (and non-zero) for a 20-event and a 200-event run — O(1) in event count; a per-event regression would make the 200-event tally ~10x the 20-event one. Behavior parity (filters, inclusive lexicographic window, malformed tolerance + `skipped N` warning, archive/active merge, limit/`--all`, compact-JSON byte identity) covered by the existing `test-pmctl-trace.sh` cases (14 passed) plus the new `case_trace_large_partition_streaming`.

**Not done here**: `pmctl-run-stats.sh` (CC-358) has the same archive+active scan shape with a per-line jq spawn; deliberately out of scope (different jq program + shell-side aggregation), left a pointer comment. No follow-up ticket filed yet.

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

## CC-493 — Prompt→Skill→Command→Harness 升級規則文件化 ✅ 2026-08-22

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
5. 判準文件需引用下列外部依據，使判準不只是本 repo 習慣的成文化（見「External grounding」）：第一級與第四級的分界採 degrees-of-freedom 判準；第二級採 progressive disclosure 的尺寸門檻；並在文件內建立「指令預算」概念（重要約束前置）。

**External grounding**（2026-07-25 外部檢索；每條均有可驗證來源）:
- **Degrees of freedom**（第一級↔第四級分界）：多種做法皆可、依情境判斷 → 留在文字；操作脆弱易錯／需一致性／需固定順序 → 降為 script 或 validator。與本 repo `DECISIONS.md 2026-05-19 cc030-validate-bidirectional`「prompt 層 enforcement 不可靠，結構 validator 是唯一穩固邊界」同向，互相印證。來源：<https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices.md>
- **Progressive disclosure 尺寸契約**（第二級量化門檻）：metadata（name/description）常駐載入、body 按需載入；`description` ≤1,024 字元、`SKILL.md` body <500 行、reference 檔案自 SKILL.md 起算一層深（更深會被部分讀取）、>100 行的 reference 需附目錄。現況實測本 repo 最大 prompt 資產 281 行，全數低於 500 行門檻——判準應據此記錄「現況合格」，避免把本票誤讀為需要大規模改寫既有 prompt。來源：同上。
- **指令密度衰減（量化）**：指令數量上升時，指令遵循率系統性下降，且存在偏向較早指令的傾向（後段指令先被忽略）；最佳前沿模型在 500 條指令密度下約 68% 正確率。用於支撐「指令預算」與「重要約束前置」兩項排序原則。來源：IFScale, arXiv:2507.11538 (2025-07)。

**Non-goals**: 不在本票內實際搬遷任何 `commands/`/`agents/` 檔案到 `skills/`；不建立 skill schema/validator（見 [[CC-357]]）；不建立 skill marketplace 或 DSL（見 [[CC-393]]）；不依本票改寫既有 `agents/`／`commands/` prompt（外部證據不支持大規模校準改寫，見 External grounding 第二點）。

**Source**: 2026-07-15 使用者提供「harness/skill/pm-dispatch 三層定位」論述，經 `pmctl dispatch run --adapter codex`、`--adapter opencode` 與 `project-pm`(model: fable) 三方獨立分析收斂。

**Cross-link**: [[CC-015]]、[[CC-026]]、[[CC-054]]、[[CC-357]]、[[CC-393]]、[[CC-489]]。

**Closure 2026-08-22 (pr:#513)**: 新增 `docs/skill-command-harness-policy.md`，落地
Requirement 1 的四級判準（含「指令預算」小節置頂）、Requirement 5 的三條外部依據
（degrees-of-freedom、progressive disclosure、IFScale 指令密度衰減，皆附引用）。
Requirement 2 盤點結果：`commands/`（15 個檔案）全數符合 Tier 3（皆需 `/foo` 觸發
或參數解析，含票面點名的「純方法性」`pre-impl.md`／`research.md`／
`using-git-worktrees.md`——澄清 Tier 2/3 真正判準是「是否需要使用者主動輸入 /foo」
而非「工作流 vs 方法」，三者皆需要）、`skills/`（2 個檔案）全數符合 Tier 2 契約；
**建議遷移清單為空**——歷史的 command/skill 混淆是命名問題，不是位置問題。
Requirement 3：`docs/CONCEPTS.md` Concept 2 標題與 TL;DR 表格移除「(a.k.a. skills)」
用詞，新增一段區分 slash command 與獨立的 skill primitive 並連結新判準文件。
Requirement 4：CC-015／CC-026／CC-054 的 Sequencing／Resume trigger 註記已更新為
「判準已定案」，維持原訂 `skills/` 落地目標不變（CC-026／CC-054 的 slash-command
互動介面本身仍正確維持 Tier 3，只有其產出物位置需照此判準）。

重新量測「現況合格」的引用數字：票面原引「281 行」（2026-07-15 量測，來自
`agents/project-pm.md`）已過時——現況（2026-08-22）最大 prompt 資產是
`commands/pr-gate.md` 482 行（command，非 skill，不受 500 行 skill-body 門檻約束），
兩個 SKILL.md 分別為 59／76 行，皆遠低於門檻；政策文件已改引正確數字並註記
「不要在此日期後直接沿用本文數字，需重新查證」。

**See**: pr:#513

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

## CC-511 — ship publish authorization：current-tree full suite + review closure ✅ 2026-08-21

**Problem**: `pmctl ship finish` 目前在 gate GO、HEAD 未移動且 tree clean 後直接
push／開 PR，沒有驗證 current tree 的 authoritative full suite。另一方面，
[[CC-517]] 的 primary review 可能審查 pre-remediation tree；若一律要求
「current-tree gate GO + current-tree full PASS」，就會迫使所有 remediation 重跑
full gate，與 conditional closure policy 衝突。真正的 publish invariant 應是
current-tree full PASS 加上適用 delivery policy 的 valid review authorization。

**Phase A — immediate full-suite enforcement（不等待新 schema）**:

1. 所有官方 pmctl ship publish path 在任何 push／PR mutation 前，必須取得
   current tree 的 authoritative full-suite PASS：可由 finish 執行，或以明確
   `--full-result <artifact>` 接受 caller 結果；兩者都呼叫既有
   `tests/bin/run-tests.sh --verify-full` canonical verifier。
2. verifier 現有的完整 suite registry、zero skip、tree 未漂移、tree fingerprint
   與 runner-contract fingerprint 要求全部保留；missing、partial、skip、fail、
   timeout、suite drift、tree drift 一律在 publish 前 fail closed。不能相信 exit 0、
   stdout 字串或舊 `latest-full.json`。
3. direct `pmctl ship finish` 與 parallel adapter-generated path 共用同一 verifier；
   full failure 不 push／開 PR，pre-existing/environment failure 另行記錄但不能偽裝
   PASS。保留 branch/ticket identity、clean-tree、HEAD drift、`gh` preflight 與
   partial-publish guards。

**Phase B — review authorization integration（依賴 evidence/closure）**:

4. publish verifier 接受兩種 review authorization，且明文記錄採用哪一種：
   - **final-tree review**：gate subject 與 current tree 匹配，verdict/policy 允許發布；
   - **primary-review closure**：valid primary review + closed
     `remediation_closure_v1` + required targeted confirmations passed + zero unresolved
     diff-caused／unauthorized hard-gate dispositions。
5. shared publish authorization summary 由 [[CC-515]] verifier 判斷 artifact validity、
   subject freshness 與 policy applicability；不得只 grep `Final: GO`。成功 marker
   與 PR handoff 記錄 review/full/closure artifact path、digest、subjects、manual
   evidence、accepted-risk provenance 與 authorization route。

**Phase A delivery（2026-07-24）**：`pmctl ship finish` 現在在任何 push／PR mutation
前，會對 current tree 執行 full suite 或接受 `--full-result`，並一律透過
`tests/bin/run-tests.sh --verify-full` 驗證。direct 與 parallel ship path 共用同一
finish 邊界；fresh run、invalid supplied result、relative artifact resolution、suite
failure、tree dirtiness 與 post-suite HEAD drift 都有 fail-closed regression coverage。
本次僅完成 Phase A；[[CC-515]] shared verifier foundation 已於 pr:#454 交付，
Phase B 的 review authorization 與 closure artifact 不在此 PR 範圍，仍待
[[CC-517]]。

**Phase B implementation (2026-08-15, partial)**：新增
`gate_publish_assessment_v1` shared publish boundary。`ship finish` 會把 current
Gate assessment、closed remediation closure、required targeted confirmation 與
authoritative full-suite 綁定到同一 subject；targeted Gate 只有在 closure
authorization 通過時才可進入 publish route。三個 ship output surface 均消費此
assessment；真實 producer/consumer dogfood 與完整 final-tree/primary-closure
矩陣仍需完成後才能收斂本票。

**Update 2026-08-20（Phase B route correctness）**: authorization route 先前由
`targeted_confirmation.status` 這個 proxy 推導，但 Requirement 4 對 final-tree review
的定義是「gate subject 與 current tree 匹配」——那是 closure 裡 `primary.subject`
與 `final_subject` 的比較，兩者回答的是不同問題，且 schema 允許它們不一致。改由該
比較推導後，新增四列矩陣（primary subject 同/異 × targeted pass/not_required）作為
第一份真正區分兩條 route 的覆蓋；先前 `final_tree_review` 只以 fixture 輸入出現過，
從未被斷言為 builder 的產出。mutation 顯示舊推導在兩列出錯，其中一列會**宣稱
final-tree review 但該 tree 從未被審過**。dogfood（真實 producer/consumer 端到端）
仍未完成，票維持 partial。

**Done-when**: 任一官方 ship publish path 都只能在（1）current tree authoritative
full-suite PASS 有效；（2）review authorization 對目前 delivery policy 有效；
（3）branch、HEAD、tree 與 evidence subject 匹配後 push／開 PR。Phase A 可先獨立
ship；Phase B 在 [[CC-517]] 完成後收斂。

**Non-goals**: 不把 full suite 搬進 generic gate；不要求所有 final tree 都 full
re-gate；不建立第二套 test-result schema；不把 publish authorization 等同 merge
authorization。

**Dependencies**: Phase A 複用 [[CC-449]]／[[CC-491]]，可立即實作；Phase B 的
[[CC-515]] verifier dependency 已滿足，剩餘依賴為 [[CC-517]]。

**Cross-link**: [[CC-512]]、[[CC-513]]、`docs/test-runner-contract.md`。

**Closure 2026-08-21 (pr:#507)**: [[CC-517]] 已於本日收斂，Phase B 解封。
`/pre-impl` 查證確認 final-tree／primary-closure route matrix 已由 PR #501 的
四列覆蓋交付（`case_publish_assessment_route_follows_reviewed_subject`）；真正
未完成的是「producer/consumer dogfood」——`tests/shell/test-pmctl-ship.sh` 裡
每一個驅動 `pmctl ship finish` 的既有測試（含先前的 `real-closure` 模式本身）
都無條件把 `gate_remediation_closure_verify` stub 成 `return 0`，所以 closure
producer（`gate_remediation_closure_publish`）與其在
`gate_publish_assessment_build` 內部呼叫的 consumer（真正的
`gate_remediation_closure_verify`）從未在一次真實 `ship finish` 呼叫鏈中同時
以未 stub 的狀態互相驗證過。新增 `case_finish_real_closure_verify_accepts_producer_output`
（`real-closure` 模式下移除該 stub，跑完整 finish 後對輸出的 closure 獨立重新
verify）與 `case_publish_assessment_rejects_closure_mutated_after_real_publish`
（用真實 producer 產出 closure 後竄改一個不變式欄位，斷言真實 verify 透過
`gate-publish.sh` 自己的錯誤訊息拒絕，而非走 shortcut）。兩案皆通過，且沿用
現有 fixture 通過真實 verify——**未變更任何 production code**，Requirement 1–6
與 route matrix 原本就已正確落實。`gate_policy_applicability_assess` 在同一組
測試裡仍是全面 stub，但它已在 `test-pmctl-gate.sh`（約 11 案）獨立驗證過，且
不在本票 Requirement 4/5 明列的 producer/consumer 缺口範圍內，故不視為本次
closure 的漏項；若未來有證據顯示這一軸也需要同等的 unstubbed dogfood，另開票
處理。

**See**: pr:#507

---

## CC-514 — orthogonal delivery assurance map 與 recipes

**Problem**: repo 已有 retrieve/spec、affected tests、refactor/reuse audit、
independent gate、full suite、publish 等成熟 primitives，但資訊散在 README、
`commands/ship.md`、review-model、runner contract、agents 與 skills。新使用者容易
把它們誤讀成唯一線性 workflow，或把「指令執行成功」誤當成所有 assurance
dimensions 都已完成；docs-only、一般功能、高風險／manual UI change 也缺少可直接
照做的短 recipe。

**Requirement**:

1. 建立 canonical delivery assurance map；至少把 tier、mode、reviewer coverage、
   reviewer independence、policy classification、test coverage、subject freshness、
   manual evidence、remediation closure 與 publish authorization列為正交維度。
   每個 dimension 說明 producer、artifact、consumer、可否 reuse，以及
   `pass|fail|not_run|not_applicable|stale|incomplete` 的誠實聲明。
2. 提供至少 docs-only、一般 functional change、高風險／含 manual verification
   三條短 recipe。pm-dispatch maintainer recipe 依 [[CC-517]] 維持
   focused tests→audit→一次 primary comprehensive gate→targeted remediation
   rounds→deterministic closure→post-fix affected tests/audit→full→publish；
   輪數本身不是停止訊號（`commands/ship.md` 已有單一 gate 收斂 7 輪的實例），
   只有 ticket 前提證偽或 Rule A 三振無進展才停。generic `pmctl gate`
   使用者仍可自行選擇其他 re-gate policy。manual evidence 只使用 bounded
   checklist／artifact reference，不建立新 runner。
3. recipe 明列兩個軸而非模糊寫「full gate」；例如 routine feature 可是
   `tier: standard, mode: sequential`，high-risk feature 可以是
   `tier: full, mode: parallel-recommended`。Reviewer coverage 與 publish
   authorization 另列，不由 tier/mode 推論。
4. 對齊 README、`docs/CONCEPTS.md`、`docs/review-model.md`、
   `docs/test-runner-contract.md`、commands 與 skills 的術語和入口：
   `/ship` 是本 repo maintainer recommended path，`pmctl gate`／runner／ship
   finish 是可組合 primitives；不得把建議路徑寫成唯一合法產品 workflow。
5. Tier/mode/reviewer-policy tables 必須來自 [[CC-512]]／[[CC-513]] 的
   machine-readable source 或 bounded generated markers；cross-document lint 不解析
   大段自由文字。README 只保留 discoverable pointer，canonical docs 承載概念。
6. 分兩步交付：先落 `draft terminology/map` 骨架，不宣稱 runtime 已支援；
   `runtime-aligned finalization` 等 [[CC-511]] Phase B、[[CC-517]]、
   [[CC-520]]～[[CC-522]]、[[CC-527]]、[[CC-529]] 及 v0.11.0 authority closure
   收斂後再做，並加入 drift ratchet。
7. 明文記錄現階段不新增 `/deliver`、workflow profile、persistent workflow state、
   preset DSL 或 FSM；若短 recipe 的真實使用證據顯示需要 wrapper，再由
   [[CC-516]] 評估。

**Delivered content（PR #522）**：`docs/delivery-assurance-map.md` 落地，涵蓋
Req 1（10 個正交維度表）、Req 2/3（三條 recipe，各自獨立標 tier/mode）、Req 4
（README／`docs/CONCEPTS.md`／`docs/review-model.md`／`docs/test-runner-contract.md`
／`commands/ship.md`／`pr-gate-review` skill 互相連結，`/ship` 明文標註為
maintainer-recommended path 而非唯一合法路徑）、Req 6 的 provenance 標頭與 Req 7
的 scope boundary 聲明。Req 5 的六張 policy 來源表已用 `<!-- GENERATED -->`
標記包起來，但文件本身明講「目前沒有機制驗證這些標記與來源同步」——這是內容落地，
不是本票 terminal closure。

**Remaining boundary**：Req 5 的跨文件 lint（驗證 generated marker 與
`core/policy/*` 同步）與 Req 6 的 drift ratchet 機制尚未實作；marker 語法、
diff/normalization 演算法與 CI 接線都還沒定案，需要先跑一輪
`/pre-impl "cross-document lint enforcing tier/mode/reviewer-policy generated
markers against core/policy/* sources"` 再開實作票，不得跳過設計直接動手。

**Done-when**: 一位未讀原始 agents/scripts 的 maintainer 能從 README 找到正確
recipe，並準確判斷每個 assurance dimension 是 pass、未跑、不可用或 stale；跨文件
lint 阻止 tier/mode/full-suite 順序重新漂移。

**Update 2026-08-27（Req 5/6 done）**：先跑 `/pre-impl` 定案設計——調查發現
`runtime/lib/gate-policy.sh` 早有同名 `BEGIN/END GENERATED` 標記把同一批 TSV
內嵌成 heredoc 供 standalone/copy 模式用，且 `tests/shell/test-pr-gate.sh` 已有
「逐一 heredoc byte-for-byte 比對來源 TSV」的先例；決定把 Req 5（cross-document
lint）與 Req 6（drift ratchet）收斂成同一個機制而非兩個產出物——新增
`tools/lint/check-policy-doc-sync.sh`，動態掃描所有 doc（含未 `git add` 的檔案）
找 `<!-- BEGIN GENERATED: <source> -->` 標記，逐一比對來源；「動態發現、不硬編碼
清單」本身就是 ratchet：新文件新增第 7 個區塊不必回頭改檢查器就會被涵蓋，已用
fixture 實測驗證。5 個 TSV 用通用比對（整行字串比對，不切 cell——`gate-policy-
signals.tsv` 的正則欄位含未跳脫的 `|`，切 cell 會誤判成多一欄，因此改成從來源
TSV 重建期望的整行文字直接比對）；`reviewer-policy.yaml` 是唯一特例（`reviewers:`
map + `verdicts:` list 巢狀結構），寫專用比對而非硬做通用 YAML renderer——這是
與使用者確認過的刻意範圍收斂，之後真的出現第二個 YAML 來源再重新設計。掛進
`.github/workflows/lint.yml`（兩個新 job：直接對真實 repo 跑 + 迴歸測試）與
`tests/lib/test-suite-runner.sh`/`tests/shell/test-run-all-tests.sh` 兩處登記
（依既有「Suite registry mirror」慣例）。單次重構重用確認抓到並修正：YAML 比對
原本兩趟重讀來源檔案且沿用切 cell 策略，改成單趟讀取＋整行字串比對，與 TSV 比對
統一策略；doc 檔案的 marker 掃描原本兩趟 awk（找區塊＋算開合平衡），合併成一趟；
`git ls-files` 原本漏掉尚未 `git add` 的新文件，改用 `--cached --others
--exclude-standard`，並補上對應 regression case。

---

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

## CC-517 — maintainer `/ship` primary review + remediation closure ✅ 2026-08-21

**Problem**: pm-dispatch maintainer `/ship` 目前把 gate remediation 設計成
repeat-until-GO loop；每輪只揭露少量新問題時，流程會反覆支付完整 LLM review 成本，
也讓 gate 從「獨立找問題」變成逐輪互動式 lint。把「只 gate 一次」留在個人 memory
又無法更新實際 command 行為，新的 main-thread session 仍會照舊重跑。這是本 repo
maintainer 想採用的 delivery policy，不應改寫 generic `pmctl gate` 或強迫其他
project 使用。

**Requirement**:

1. 更新 `commands/ship.md` 與 maintainer review model：primary implementation、
   affected tests、refactor/reuse audit 完成後，只執行一次 comprehensive PR gate。
   [[CC-513]] maintainer policy 固定要求五 reviewer coverage；mode 未指定時採
   policy recommendation，caller 明確選擇則優先，不把 full coverage 寫成必然
   parallel。Gate 使用 [[CC-518]]～[[CC-521]] 的 structured outputs。
2. 產生 `remediation_closure_v1` evidence，至少含 primary gate/result/subject、
   final subject、每個 stable finding ID 的 disposition、changed files、affected-test
   evidence、targeted confirmation evidence（若有）與 unresolved counts。所有
   diff-caused findings（high/medium/low、blocking/advisory）集中處理；pre-existing
   issue 只有在證明非本 diff 引入後另開 ticket。
3. 明確分類三種 outcome：
   - **local closure**：wording/comments/fixture/assertion/narrow error message／不新增
     行為的局部 guard；ledger closure→affected tests→full suite，不再 review；
   - **targeted confirmation**：security/risk finding、shared helper、public interface、
     schema/migration、permission、ownership/layer boundary、超出原 finding symbol/
     file，或無法確定是否新增行為；ledger→affected tests→既有 targeted reviewers
     一次→full suite；
   - **stop/split**：改變 ticket premise、新 public API/permission model/destructive
     migration/cross-module architecture 或明顯 scope expansion；不得靠再跑 full
     gate 塞回原票。
4. remediation 後 deterministic closure 必須證明 ledger 每個 finding 都有
   disposition/evidence、修改範圍未超出 finding boundary、沒有未授權 hard gate，
   local/targeted/split classification 有 mechanical reason，並重新跑 affected tests。
   Targeted confirmation 只驗 stable IDs 與 remediation delta，不重啟 full discovery；
   與 remediation 無關的新 advisory 另開 backlog，只有 remediation 新引入 blocker
   阻止收尾。
5. final result 誠實記錄 primary review subject/status/verdict、closed remediation、
   targeted confirmation `pass|not_required`、final affected/full test subject/status
   與 `publish_authorized`。除非 final tree 真的重跑 full gate，禁止宣稱 final-tree GO。
6. scope 只涵蓋 pm-dispatch repo-owned maintainer `/ship` policy、相關文件與 lint/
   command regressions。`pmctl gate` 的 sequential/parallel/targeted primitives、
   其他 repo 的 recipes 與 `pmctl ship finish` 行為保持可用，不受此票強制；本票
   不新增 gate command、gate kind、result family 或 lifecycle。

**Done-when**: `/ship` 對一般低風險 remediation 只呼叫一次 primary PR gate；所有
findings 有完整 closure evidence，只有明列的高風險條件會觸發一次既有 targeted
confirmation，且不再 full discovery。final tree 有 affected + authoritative full
PASS，PR handoff 不會把 initial verdict 錯綁到 remediation 後的 tree。測試能抓到
不必要 re-gate、該確認卻跳過、重啟 full discovery、漏 ledger finding、未授權
hard-gate disposition、scope-expanding remediation 與 false final-GO claim。

**Update 2026-08-15（pr:#483；狀態改為 partial）**: #483 交付 Requirement 2 的
`remediation_closure_v1` evidence artifact——shared runtime 產出、schema 與 verifier
接線（closure evidence、subject binding、affected-test evidence、assurance linkage），
並以 atomic no-replace 發布防止後續 producer 覆寫既有 closure。#483 的 PR body 未標記
任何 ticket，是本票 Refs 一度空白的原因。

主體視為已 ship，故依 schema 由 active 轉為 partial（日期為首批交付日）。逐項查證
（2026-08-20）：Req 1 單次 comprehensive gate 見 `commands/ship.md`（initial-result
即 comprehensive initial review，remediation 走 `--pass targeted --reviewers`）；
Req 3 的 local／targeted_confirmation／stop_split 三分類見
`core/schema/gate-remediation-closure.schema.json`；Req 4 見
`gate_remediation_closure_verify`；Req 5 的 `publish_authorized` 由
`runtime/lib/gate-closure.sh` 計算、`runtime/lib/gate-publish.sh` 消費。
**殘留範圍未逐項稽核**：本次只確認各 requirement 都有對應實作，尚未依 Done-when
驗證行為（不必要 re-gate、該確認卻跳過、重啟 full discovery、漏 ledger finding、
未授權 hard-gate disposition、scope-expanding remediation、false final-GO claim
是否都被測試涵蓋）。收尾前須補這一步。

**Non-goals**: 不把此偏好存成 memory-only instruction；不修改 generic gate 的公共
自由度；不保證 LLM 一輪能發現所有可能問題；不新增 workflow engine、FSM 或背景
orchestrator。

**Dependencies**: [[CC-512]]、[[CC-513]]、[[CC-515]]、[[CC-518]]～[[CC-521]]。
P1，排入 v0.11.0 delivery assurance correctness。

**Cross-link**: [[CC-485]]、[[CC-511]]、[[CC-514]]。

**Closure 2026-08-21 (pr:#506)**: 補上 2026-08-20 稽核筆記標記的殘留缺口。
`gate_remediation_closure_verify`（`runtime/lib/gate-closure.sh:420-524`）原本
只有一個 mutation test（`disposition="tracked"`）覆蓋，不足以證明約 15 條件
`and`-chain 裡每一條都真的有作用。把
`tests/shell/test-core-schemas.sh` 的
`case_gate_remediation_closure_runtime_claims` 擴成 table-driven，一個 Done-when
失敗模式配一個 mutation：unnecessary re-gate（accept baseline）、skipped
required confirmation、restarted full discovery（`delta_only=false`）、
unauthorized hard-gate disposition（`classification="stop_split"` 但非
split state）、scope-expanding remediation（finding `changed_paths` 超出
`changed_files`）、false final-GO claim（`publish_authorized=true` 但
`full_suite_status="not_run"`）。「漏 ledger finding」已由 synthesis 層
`test-pr-gate.sh` 的 `seed-missing-entry` mutation 覆蓋，不重複做。六個
mutation 全部針對現有 `gate-closure.sh` 跑出預期方向，未發現任何漏洞，
**未變更任何 production code**——Requirement 1–6 原本就已正確落實，這次只是
把缺的證據補齊。

**See**: pr:#506

---

## CC-524 — artifacts show canonical absolute run root

**Framing**: 本票補齊 [[CC-418]] observer／discoverability 已交付後暴露的 locator
缺口，不搬動 artifact、不改 state partition layout，也不把 `artifacts show`
擴張成檔案內容 viewer。human output 與 machine output 都必須由同一 canonical
state-path resolver 產生，不能另做 repo-local fallback 或掃描猜測。

**Problem**: `pmctl artifacts show <run-id> --cd <repo>` 已能從 canonical project
partition 找到 run directory，成功時卻只列出 `<bytes><TAB><relative-path>`。
使用者因此知道 `.gate-results/foo.md` 存在，卻不知道它實際位於哪個絕對根目錄；
尤其 artifact 已搬離 target repo、`PM_DISPATCH_STATE_ROOT`／XDG／HOME precedence
可能不同時，只能再次猜測或全檔案系統搜尋。錯誤路徑反而會印出 resolved run
directory，形成成功與失敗輸出的可發現性倒置。

**Requirement**:

1. 成功的 human output 必須在任何 file rows 前明確印出 canonical physical
   `run root: <absolute-path>`，其值為同一 `--cd` project partition 下
   `runs/<run-id>` 的實際目錄；即使 run directory 為空也必須印 root。
2. 保留現有檔案 size 與 relative-path 資訊；新增穩定 `--json` locator contract，
   至少含 schema/kind、run ID、canonical repository root、canonical absolute run
   root，以及依穩定順序排列的 `{relative_path,size_bytes}` files。human label 與
   JSON field 的 root 必須完全一致。
3. root 必須經 canonical path resolution，且驗證仍位於 resolver 選出的 project
   `runs/` containment 下；symlinked state root、relative `--cd`、git subdirectory
   與 custom `PM_DISPATCH_STATE_ROOT` 都不得產生 lexical-only、foreign partition
   或不存在的 success locator。
4. state-root precedence 繼續使用現行
   `PM_DISPATCH_STATE_ROOT` → `XDG_DATA_HOME` → HOME fallback；不得因 target repo
   找不到 `.gate-results` 就掃描其他 project partitions。unknown run／wrong
   `--cd` 維持非零，並在不越權搜尋的前提下給出可複製的 `artifacts list/show`
   recovery 指令。
5. regression fixtures 覆蓋 default 與 custom state root、含空白路徑、空 run、
   多層 artifact、human/JSON parity、stable ordering、wrong project、symlink
   canonicalization 與 containment rejection；現有 size/relative-path consumer
   必須有明確 compatibility 測試或 migration 說明。

**Done-when**: 操作者只執行一次
`pmctl artifacts show <run-id> --cd <repo>` 就能複製 canonical absolute run root
並直接定位列出的 artifact；automation 可用 `--json` 取得同一 locator，不需猜測
state store、搜尋 target repo 或解析錯誤訊息。

**Non-goals**: 不新增 `cat`／download／open 子指令；不改 artifact retention／GC；
不遷移既有 runs；不放寬 project partition containment；不替 missing artifact
重建內容。

**Dependencies**: 延伸 [[CC-418]] 已建立的 artifacts observer 與
`state-paths.sh` canonical partition seam；與 [[CC-515]] artifact
freshness／applicability verifier 正交。P2。

**Update 2026-08-26（done，pr:#537）**：五項 Requirement 全數交付。成功輸出在
任何 file rows 前印 `run root: <canonical-absolute-path>`（含空 run 目錄情境）；
新增 `--json` 回傳 `{schema_version,run_id,repo_root,run_root,files:
[{relative_path,size_bytes}]}`，human 與 JSON 的 root 值完全一致；canonicalization
重用既有 `realpath_m`（`portable.sh`），未新造第二套解析邏輯。containment 檢查
過程中實測發現一個真的安全漏洞：把 canonical run_dir 的父目錄與 canonical
runs_dir 做字串相等比對，在 `runs/` 本身被換成指向外部的 symlink 時是恆真的
（兩邊都會忠實跟隨同一個被置換的 symlink），會讓外部檔案內容被當成合法
"run root:" 成功輸出印出——已改用直接 lstat 檢查（`runs/` 目錄與 run_id leaf
本身皆不得是 symlink），新增共用 predicate `sw_run_dir_symlink_free`（放在
`state-paths.sh`、`sw_project_run_dir` 旁邊，因為 `gc`／`migrate` 共用同一條
未防護的路徑、風險比唯讀的 `show`更高，留給未來票接上，不在本票 Non-goals
範圍內擴大）。regression fixtures 涵蓋 symlinked state root（合法情境，需正確
解析成真實路徑）、containment escape（需拒絕）、relative `--cd`、git
subdirectory、空 run 目錄。pr-gate 首輪 GO（tier standard，critic／qa-tester／
architecture-reviewer／security-reviewer 全數審查，兩個 advisory-only 發現
不擋 merge：換行字元檔名邊界情境與既有的 same-host TOCTOU，皆記錄不修，理由
見 PR）；`tests/bin/run-all-tests.sh` 104 passed 0 failed。

---

## CC-527 — targeted gate CLI coordinate separation 與 truthful labeling ✅ 2026-08-21

**Framing**: 本票只收斂既有 gate assurance coordinates 的 CLI 表達與 human
label，不新增 gate kind、review workflow、tier 或 reviewer。[[CC-512]] 已確立
tier、pass kind 與 reviewer coverage 是正交座標；本票讓 public CLI 也能直接表達
這三軸，而不是由一個 `--targeted <reviewers>` 同時承擔 pass kind 與 coverage。
既有 shorthand 必須保留 bounded compatibility，不能藉語意清理限制 generic gate
使用者選擇 reviewer 或 execution mode。

**Problem**: `--tier full --targeted qa-tester --initial-result <path>` 在 machine
contract 中可解析為 `tier=full`、`pass=targeted`、`coverage=[qa-tester]`，但 human
語意容易把 `full` 誤讀成完整五 reviewer comprehensive gate。`--targeted` 目前又
同時選擇 remediation-delta pass 與 reviewer coverage，而 tier table 仍提供 default
reviewers；即使 resolver 有確定 precedence，CLI 表面仍讓 rigor、pass scope 與
coverage 看似互相覆蓋。這可能導致 maintainer recipe 錯稱「full gate」、重啟不必要
的 comprehensive discovery，或誤以為 targeted qa 已取得 full reviewer coverage。

**Update 2026-08-11 (PR #472, partial; ticket remains active)**: PR #472 已交付
canonical `--pass targeted --reviewers ... --initial-result ...`、legacy
`--targeted` shorthand 的同路徑展開、同值混用相容／衝突 fail-closed、CLI spelling
provenance，以及部分 deterministic fixtures。尚未完成的是 subject-applicable initial
result 的 tier inheritance、tier／coverage 各自的 machine-readable selection basis、
stale／legacy initial-result 行為、`tier=full + QA-only` truthful labeling，以及
copy-mode／repo-layout、sequential／parallel 的完整 meaning-parity 與 consumer
不得誤認 comprehensive coverage 的驗收。因此 PR #472 不構成 CC-527 closure。

**Update 2026-08-14 (P1 first slice, still partial)**: main 現在由 gate shell 在
published result 追加 deterministic `Gate Coordinates` block，明確列出 tier
(rigor)、pass scope、reviewer coverage、各自 selection basis 與 execution mode；
`tier=full + pass=targeted + coverage=[qa-tester]` 會標示為 remediation-delta，
不命名為 full/comprehensive gate。新增 fixtures 覆蓋 copy-mode、repo-layout 與
sequential／parallel meaning-parity。stale／legacy initial-result consumer parity
與 publish/closure consumption 仍留在後續 slice，票面維持 partial。

**Decision 2026-08-12 (PR #476)**: targeted pass 的 tier 必須從 current immutable
subject 與 current policy 重新解析；initial result 只證明 remediation context，不能
把舊 tree 的 tier 或 policy 帶進新 subject。這取代早期「subject-applicable initial
result 優先繼承 tier」草案，避免 stale/prior evidence 變成 current rigor authority。

**Requirement**:

1. 定義 canonical explicit form，設計目標為
   `--pass targeted --reviewers qa-tester --initial-result <path>`；pass kind、
   coverage 與 initial-result 必須各自驗證。既有 `--targeted <reviewers>` 保留為
   compatibility shorthand，且必須機械展開為完全相同的 coordinates，不能形成
   第二條 resolver path。
2. Targeted tier resolution 必須有單一、可解釋的 basis：無論有無 initial result，
   都從 current immutable subject 的 canonical policy resolution 取得 tier；使用者
   可明確指定 tier。initial result 只作 remediation context，不能提供或覆寫 current
   tier；不得從 targeted reviewer 數量反推 tier。不可用未驗證 frontmatter prose
   代替 current policy/subject evidence。
3. 使用者若有獨立 rigor 理由仍可明確請求 tier，但 explicit tier 不得擴張、替代或
   暗示 targeted coverage。CLI progress、brief、result 與 assurance 必須並列輸出
   `tier=<resolved>`、`pass=targeted`、`coverage=[...]` 及各自 selection basis；
   `tier=full` 不得被 human 文案命名為 `full gate` 或 comprehensive review。
4. Canonical 與 compatibility spellings 混用時，同值可接受、不同 pass／coverage
   請求 fail closed；`targeted` 缺 `--initial-result`、initial pass 帶 initial result、
   duplicate／empty reviewer、tier inheritance 不可驗證都必須在 dispatch 前給出
   actionable error。
5. 更新 `/pr-gate`、maintainer `/ship` 與 review model：follow-up confirmation
   必須描述為 targeted remediation pass，列出 tier 與 selected reviewers，不得以
   「full」代稱 coverage。[[CC-517]] 的 conditional targeted confirmation 使用
   canonical explicit form，但本票不實作 remediation closure。
6. Artifact/verifier 必須能機械回答 pass kind、tier basis、coverage basis、initial
   result reference 與 shorthand provenance；copy-mode、repo-layout、
   sequential／parallel 必須 meaning-parity。若既有 `gate_assurance_v2` 已可完整
   表達，優先重用而不新增 schema family。
7. Deterministic fixtures 覆蓋 canonical targeted、legacy shorthand parity、
   explicit full-tier + QA-only coverage 的 truthful labeling、current-policy tier
   resolution、
   stale／legacy initial result、conflicting spellings、缺 initial result，以及
   consumer 不得把 targeted artifact 當 comprehensive full-coverage evidence。

**Done-when**: 操作者看到任一 targeted command／result 都能分辨「審查 rigor、
remediation pass scope、實際 reviewer coverage」；canonical form 不再由
`--targeted` 一個參數承擔兩個座標，legacy shorthand 仍相容，且任何
`tier=full + pass=targeted + coverage=[qa-tester]` artifact 都不會被 UI、文件或
consumer 誤稱為 full/comprehensive gate。

**Non-goals**: 不移除 targeted confirmation；不強制 targeted 使用特定 tier、
reviewer 或 mode；不新增 workflow engine／FSM／gate kind；不把本票擴張成
[[CC-517]] remediation ledger、[[CC-515]] freshness verifier或新的 tier taxonomy。

**Dependencies**: CLI coordinate 分離延伸 [[CC-512]]；可信 initial-tier
inheritance 依賴 [[CC-515]]；maintainer consumer 接線由 [[CC-517]] 使用。P2，
可先交付 syntax/parity，再於 applicability verifier 完成後接 inheritance。

**Cross-link**: [[CC-512]]、[[CC-513]]、[[CC-514]]、[[CC-515]]、[[CC-517]]。

**Closure 2026-08-21 (pr:#505)**: 查證現況後確認 Requirement 1–7 已全數滿足。
Requirement 6/7 票面標記為「仍留在後續 slice」的 stale／legacy initial-result
consumer parity 與 publish/closure consumption，實際已由 [[CC-517]] PR #483／#484
（2026-08-15）交付：`runtime/lib/gate-closure.sh` 對 targeted closure 強制要求
initial result 的 immutable `*.assurance.json` sidecar 與 synthesis ledger，
subject/scope provenance 不符或 sidecar 缺失即 fail closed（見
`tests/shell/test-pmctl-ship.sh` `case_targeted_closure_rejects_legacy_initial_without_immutable_evidence`、
`case_targeted_closure_rejects_initial_subject_mismatch`、
`case_targeted_closure_requires_initial_finding_ledger`），只是當時未回連本票。
Requirement 4 的「tier inheritance 不可驗證」子項在 PR #476 決策後已不適用——
tier 一律從 current policy 重新解析，沒有可驗證的繼承路徑。本 slice 只補上
Requirement 4/7 CLI 層剩餘的 fail-closed fixture 缺口（`--pass initial` 誤帶
`--initial-result`、`--pass`/`--targeted` 互相衝突、`--reviewers`/`--targeted`
coverage 不一致、重複 reviewer、空／畸形 reviewer list），未變更任何 production
code。

**See**: pr:#505

---

## CC-529 — publish assurance observability：baseline／preferred 可追溯

**Framing**: 本票只延伸 [[CC-528]] 已建立的 publish policy compatibility，
讓成功發布保留「哪一種 producer policy、以 baseline 或 preferred 滿足 publish」
的 machine-readable audit trail。Shared verifier 仍是 policy applicability 的唯一
owner，`pmctl ship finish` 只能呈現 verifier 已驗證的 axes；不得從 tier、reviewer
數量、mode 或 human `Final: GO` 反推 assurance strength，也不得藉本票改寫
generic／maintainer policy、publication floor 或 [[CC-517]] remediation closure。

**Problem**: [[CC-528]] 讓 generic current-tree initial GO 可作 publish baseline，
maintainer GO 則是 preferred；但 successful `pmctl ship finish` stdout、PR body 的
Gate section 與 `.pm-dispatch-ship-finish.json` marker 目前只保留 `Final: GO` 與
result path。兩種不同 assurance strength 最後留下相同的 publication record，
操作者與 incident review 無法事後判斷該次發布是 generic baseline 或 maintainer
preferred。CLI usage 雖已列出 `--gate-result`，也缺少回歸測試防止 help synopsis
與 parser mutual-exclusion 契約再次漂移。

**Requirement**:

1. `pmctl ship finish` 只能從已通過 shared verifier 的 structured
   `policy_applicable` axis 取得 `embedded_policy`、`required_policy`、
   `preferred_policy` 與 `policy_satisfaction`；缺欄位、未知值或 verifier
   assessment 不完整時 fail closed，不以 result prose 或 Gate coverage 猜值。
2. Fresh maintainer Gate 與 supplied generic／maintainer result 的成功路徑，都要在
   stdout summary、PR body Gate section 及 `.pm-dispatch-ship-finish.json` marker
   明確保留 producer policy 與 `baseline|preferred` satisfaction。三個 surface
   必須來自同一份已驗證 assessment，不得各自重算。
3. Marker 變更採 additive、versioned 或明確 backward-compatible contract；既有
   不含新欄位的 marker 仍可由 status/list reader 安全讀取，但新 writer 不得在
   assessment 可用時省略 assurance fields。不得把 baseline 顯示成 failure，
   也不得把 generic 誤標為 maintainer。
4. PR body 與 human stdout 必須讓操作者一眼區分 baseline／preferred，同時保留
   result artifact path 供完整 verifier 重播；不得只加入模糊的「policy checked」
   文字。
5. Public help regression 必須斷言 `pmctl ship finish --help`／usage 包含
   `--gate-result`、`--full-result`，並保留 `--gate-result` 與 `--reviewers`
   mutual-exclusion 的表達；parser 行為測試仍是獨立 oracle。
6. Deterministic tests 覆蓋 supplied generic baseline、supplied/fresh maintainer
   preferred、缺失／malformed assurance fields、舊 marker reader compatibility，
   以及 stdout／PR body／marker 三個 surface 的值一致性。

**Update 2026-08-15（pr:#484）**: #484 交付共用的 verified publish assessment，
使 stdout、PR body 與 finish marker 得以來自同一份已驗證 assessment（Requirement 2 的
單一來源前提）。本票其餘 requirement 的驗收未因此成立，狀態維持 partial。

**Update 2026-08-20（Requirement 5 後半）**: parser 的 mutual-exclusion 行為早有
獨立 oracle，但 Requirement 5 另一半「help／usage 必須列出 `--gate-result`、
`--full-result`」沒有任何斷言——公開 help 的選項清單由 `cli/commands.tsv` 提供，
既有 discovery 測試只斷言 `Main options:` 這個區段標題存在，不檢查任何指令的實際
選項。已補上該迴歸（mutation 驗證：從 tsv 移除兩個旗標即失敗）。其餘 requirement
的驗收未變，票維持 partial。

**Done-when**: 任一成功 ship publication 都能只靠 stdout、PR body 或 finish
marker 回答 embedded producer policy 與 publish satisfaction，三者與 shared
verifier 完全一致；舊 marker 保持可讀，help synopsis 與 parser contract 有回歸
鎖定。

**Current implementation (2026-08-15)**：新增 `gate_publish_assessment_v1`，由
shared verifier 綁定 Gate、remediation closure 與 authoritative full-suite；
`ship finish` 的 stdout、PR body、finish marker 均從同一份 assessment 讀取
producer policy、preferred policy 與 baseline/preferred satisfaction。schema、
marker compatibility、targeted-closure policy 與 builder parity 已有 deterministic
coverage；仍需完成真實 producer/consumer dogfood 後才能標記 closed。

**Update 2026-08-26（done）**：重新盤點時發現 preferred（maintainer）路徑早已有
真實佐證——PR #517 的 Gate 段落已印出 `Publish assurance: producer=maintainer,
satisfaction=preferred`，是這個 repo 近期日常 `/ship` maintainer 流程的自然
副產物。唯獨 baseline（generic）路徑從未在真實 PR 出現過：這個 repo 近期的
實際工作流程每次都走 maintainer full gate，沒人真的用過 `pmctl ship finish
--gate-result <generic 產出的 GO>` 這條路。本次補做這次真實 dogfood——本票自己
這次 BACKLOG.md 更新即為 shipped 內容，交付方式刻意選用
`pmctl gate run --policy generic` 產出的 GO 結果 + `pmctl ship finish CC-529
--gate-result <path>`，而非慣用的 maintainer full gate；三個 surface（stdout、
PR body Gate 段落、`.pm-dispatch-ship-finish.json` marker）皆確認顯示
`producer=generic satisfaction=baseline`，與 shared verifier 輸出一致。至此
preferred／baseline 兩條路徑皆有真實 producer/consumer 佐證，Done-when 條件
成立，結案。

**Non-goals**: 不改 generic／maintainer reviewer floor、tier、mode 或 compatibility
ordering；不新增 Gate、publish authorization 或 workflow engine；不實作 dashboard、
scheduled audit 或歷史 marker backfill；不把 [[CC-517]] remediation closure 併入。

**Dependencies**: 延伸 [[CC-528]] policy compatibility 與 [[CC-515]] shared
verifier，沿用 [[CC-511]] publish marker／PR boundary。P2，排入 v0.11.0 delivery
assurance observability。

**Cross-link**: [[CC-511]]、[[CC-513]]、[[CC-515]]、[[CC-517]]、[[CC-528]]。

---

## CC-532 — Gate canonical modules for the Linux/WSL2 developer path ✅ 2026-08-22

**Problem**: `runtime/bin/pr-gate.sh` 同時承擔 option parsing、policy、subject、
scope、reviewer contract、synthesis、assurance、publication 與 copy-mode fallback，
canonical authoring source已接近 6,500 行。Portability 所需 generated snapshot
與正常 repo-layout 邏輯混在同一檔，讓每次 contract 變更都擴大 review 與 regression
surface。

**Why**: Gate 已是專案複雜度中心。先在 Linux/WSL2 的 repo-layout developer path
完成 canonical module ownership 與 composition root，才能降低 domain coupling、
測試隔離與 code review 的 regression surface；distribution portability 之後再
以獨立 slice 處理。

**Scope decision (2026-08-14)**: 本階段產品明確只支援 Linux/WSL2，先完成
developer/repo-layout path。Standalone distribution、跨平台 copy fallback 與其
generated bundle parity 不列入本階段驗收；保留既有相容性行為的歷史測試，但不再
擴大其 implementation surface。相容性 distribution 另立後續 slice，避免與
canonical module extraction 同時增加兩條 authoring/runtime authority。

**Requirement**:

1. 依 domain 抽出 source-safe canonical modules，至少涵蓋 options、policy、
   subject、scope、reviewer contract 與 assurance；`runtime/bin/pr-gate.sh`
   成為 repo-layout composition root，首批搬移只做 behavior-preserving migration。
2. Linux/WSL2 repo-layout 只保留一份 canonical authoring source；本階段不新增
   standalone distribution builder，也不把 copy-mode fallback 當作新的 runtime
   authority。
3. Canonical entrypoint 與 modules 由 repo-layout 載入；現有安裝／copy compatibility
   surface 維持既有行為，若後續要支援 generated distribution，另以獨立 slice
   定義 bundle schema、build 與 parity。
4. CI 以 module source-safety、layer boundary、repo-layout resolution、既有 gate
   behavior fixtures 驗證本階段；不加入 generated/dist parity 作為本階段 gate。

**Slice 1 — library resolution single authority（已交付）**：實測推翻了票面對
copy-mode 的前提。`pr-gate.sh` 對 executor router、memory runtime 與 policy reader
本來就是硬依賴（缺檔即 exit 2），所以「單一檔案的 standalone gate」從來不可執行；
實際 bundle 一直是目錄契約（`pr-gate.sh` + `lib/` + `core/policy/` + `agents/` +
`adapters/`）。inline verifier/artifact-paths fallback 之所以會在 standalone-copy
被觸發，是因為那兩處只看 installed-copy root，解析成 bundle 之外的 `../lib`——
是路徑缺陷，不是可攜性需求。Slice 1 因此把所有 library 解析收斂到單一
layout-aware root，刪除兩份 in-script 副本與其 generator（-2,260 行），並讓缺件
bundle 在載入點 fail closed。requirement 2 的 verifier fallback 部分就此消滅而非
搬移；bounded policy snapshot 不受影響，對 installed copy 仍是 load-bearing
（install 不複製 `core/policy/gate-*.tsv`）。

**Slice 2a（已完成，2026-08-14）**：policy、subject、scope、assurance 搬至
source-safe canonical modules。當時票面把 options 與 reviewer-contract 一併記成
已搬，但 `gate-options.sh` 只剩兩個 setter、`gate-reviewer-contract.sh` 幾乎是空殼，
33 個 option 分支與 override loader 仍在 `pr-gate.sh`。2026-08-20 查證確認
Requirement 1 尚未達成。

**Slice 2b（已完成，2026-08-22）**：`gate_options_init`／`gate_options_parse`／
`gate_options_require_workdir` 成為 CLI flag 單一 owner；`gate_load_reviewer_override`
搬入 `gate-reviewer-contract.sh`，digest 走既有 `gate_digest_file`。composition root
只呼叫這些函式；snapshot unlink 仍留在 entrypoint EXIT trap。ownership ratchet 改為
檢查 option flag arms 與 loader 定義位置，並加直接 parser 案例，避免再把空殼模組
記成完成。`pr-gate.sh` 約 4,247 → 3,911 行。Generated distribution／copy parity
維持 deferred，見 [[CC-546]]。

**Closure（2026-08-22）**：Requirement 1 的六個 named domain 現在各有單一 source
owner，Linux/WSL2 repo-layout 不再把 option 解析或 override loader 放在 composition
root。current-tree full-suite 依 2026-08-20 決策是 publish 常設不變式，不是本票
closure 條件。Standalone distribution 不得回併本票。

**See**: DECISIONS.md 2026-08-22

---

## CC-533 — schema-derived Gate structural validator

**Problem**: Gate JSON Schema 已定義 required fields、exact keys、enum、patterns、
conditions 與 finding shape，shared jq verifier 又手寫同一份 structural model。
Parity tests只能發現漂移，無法消除每次 contract 變更都必須同步修改 schema 與
validator 的雙重 authority。

**Why**: Structural validation 與跨 artifact domain semantics 是不同責任。前者
應由 schema authoring source 派生；後者才需要手寫 reviewer identity、subject、
scope、evidence index、digest 與 line-boundary 驗證。分層後可降低 Gate schema
演進成本，同時保留 Bash+jq lightweight runtime。

**Requirement**:

1. 由 canonical schema 派生或產生 Gate structural validator，涵蓋 required、
   type、enum、const、pattern、additional properties、array、`$ref` 與目前使用的
   conditional vocabulary；coverage surfaces 等 enum 不再手寫第二份。
2. 手寫 verifier 只保留跨 artifact semantics，例如 expected reviewer、
   scope/subject digest、reference-index membership、snapshot line bound 與 linked
   artifact integrity。
3. Assurance/reviewer contract 的 version dispatch 與各版本 verifier 分離，legacy
   compatibility 不再與 current exact-key logic 混成單一函式。
4. Generation 在開發／build 階段完成，runtime 仍只需要 Bash+jq；CI `--check`、
   schema fixtures 與 canonical/dist parity 證明 generated fragment 未 stale 且
   semantic checks 未被結構 generator 吸收或放寬。

**Delivered foundation（PR #480）**：canonical Gate schemas 現可生成 checked-in
runtime bundle，generic jq interpreter 已涵蓋目前使用的 structural vocabulary；
generator freshness check 與 schema fixtures 已接入。這是 foundation，不是本票
terminal closure。

**Remaining boundary**：handwritten verifier 仍保留部分 structural shape/version
branches；需待 [[CC-517]] 的 remediation closure schema 與 [[CC-511]] Phase B
consumer contract 穩定後，另以 behavior-preserving slice 完成 structural cleanup、
version dispatch separation 與 legacy/current verifier 分層。不得把這些剩餘工作提前
擴成 Gate workflow 重構。

**Update 2026-08-24（前置條件已解除，完成 assurance verifier 這一個 slice，pr:#524）**：
[[CC-517]]／[[CC-511]] Phase B 已於 #517 交付並穩定，本次針對 `gate_assurance_verify`
（`runtime/lib/gate-result-verify.sh`）完成 Req 2/3：
1. Req 3：`gate_assurance_v1`（無 schema 覆蓋的 legacy 分支）抽成獨立
   `_gate_assurance_verify_legacy_v1`，不再與 v2/v3 current 邏輯混在同一函式。
2. Req 2：v2/v3 分支裡約 230 行 only_keys／type／enum／pattern／const 手寫檢查
   （已逐一比對 `core/schema/gate-assurance.schema.json` 確認完全重複）全數移除，
   只留下 plain JSON Schema 無法表達的部分——同文件跨欄位一致性（例如
   `.bindings.repo_root == .subject.observed.root`）與外部比對（result markdown
   frontmatter、當場算出的檔案 digest、identifier-policy 的 run_id regex）。
   每一類刪除都用 fault-injection 驗證過（暫時砍掉某行、確認對應測試真的變紅、
   還原），而非單憑肉眼比對 schema 判斷安全。新增 `tests/shell/test-gate-assurance-verify.sh`
   （13 案例）鎖定行為；fixture 與 `test-core-schemas.sh` 共用同一份
   `tests/lib/gate-assurance-fixtures.sh`，避免兩處各自維護一份「合法 assurance
   長什麼樣」而悄悄漂移。
3. **範圍邊界（原始判斷，已於下方更新）**：reviewer-result／synthesis-result／
   scope-manifest 三個 artifact type 有類似規模的 only_keys 重複，本輪刻意不動。

**Update 2026-08-24（同日續，pr:#525）：`gate_scope_manifest_verify` 完成，並修正
第一輪遺漏**：
1. `core/schema/gate-scope-manifest.schema.json`（942 行）比 gate-assurance 的
   schema 更完整——用 `allOf`/`if`/`then` 編碼了 gate-assurance schema 沒有的多個
   跨欄位關聯（`subject_kind`↔`diff_kind`、`status`↔`truncation` 形狀、依 `status`
   決定的 `old_path`/`new_path`/`similarity` 形狀），所以這次可安全移除的範圍比
   assurance verifier 那輪更大。同樣逐條比對 schema＋fault-injection 驗證後執行；
   新增 `tests/shell/test-gate-scope-manifest-verify.sh`（10 案例），fixture 抽到
   `tests/lib/gate-scope-manifest-fixtures.sh` 與 `test-core-schemas.sh` 共用。
2. **修正殘留**：`/simplify` 的 altitude review 抓到第一輪（#524）遺漏——
   `gate-assurance.schema.json` 的 `gateSubject` definition 其實也用 `allOf`/`if`/
   `then` 編碼了 `subject_kind`↔`dirty_policy` 關聯，但 #524 的稽核只查了頂層
   `allOf`，沒查 definitions 內部巢狀的 `allOf`，導致這條 handwritten 判斷被誤留。
   本輪已用同樣的 fault-injection 方法確認、移除，並補上回歸測試。**教訓**：
   稽核 JSON Schema 覆蓋範圍時，`allOf`/`if`/`then` 可能巢狀在 `definitions`
   內部，只查頂層會漏判。
3. **reviewer-result／synthesis-result 改判**：深入檢視後發現兩者的「重複」並非
   意外——是刻意設計，用來在 reviewer 重試迴圈裡給出精準到欄位層級的錯誤訊息（見
   `gate-result-verify.sh` 裡明確的設計註解："a reviewer told only 'invalid
   test-gap matrix contract' cannot tell which of ~10 constraints it broke"）。
   直接比照 assurance/scope-manifest 的做法會犧牲這個診斷品質，因此**不适用同一種
   刪除法**，需要另外設計「先過 schema、再跑僅存的語意/診斷邏輯」的排序與拆分方式，
   保留欄位級診斷訊息。留給下一個 slice，範圍與風險都明顯更高。

**Update 2026-08-24（同日續，pr:#526）：reviewer-result／synthesis-result 改寫的前置
基礎建設**：深入盤點兩支函式約 1500 行診斷訊息語料後，確認只有一處（`test_gap_violation`
裡 `coverage_dimensions`／`missing_layer` 的相鄰 enum 混淆提示）是 schema 無法表達的
真正 domain hint，其餘都可由 schema 表達，只是目前是手刻訊息而非泛型解譯器產生。本輪
完成「積極版」的地基，尚未動手改寫兩支函式：
1. `runtime/lib/gate-structural-validator.jq` 的 issue 物件新增 `value`（觀察到的值），
   `runtime/lib/gate-structural-verify.sh` 新增 `gate_structural_schema_first_error`，
   把第一個違規格式化成單行「path: message (got: value)」診斷，品質可直接比對到與手刻
   訊息相當或更好（例："$.status: value is outside enum [...] (got: "bogus-status")"）。
   這是之後讓 reviewer-result／synthesis-result 先過 schema、再跑僅存語意邏輯時，用來
   取代手刻「X is not one of A/B/C」訊息的單一權威來源。
2. `core/schema/gate-reviewer-result.schema.json` 新增 `verdict` 為 `approve`／`advise`
   時禁止帶 `soft_block`／`hard_block` finding 的 `allOf` 規則。**修正框架**：這不是修
   live runtime bug——`gate-result-verify.sh` 現有的手刻 `verdict_contract` 今天已經
   透過其 else 分支（`all(.findings[]; .hard_gate_class == "none")`）強制此規則。此變更
   是補齊 schema 自身的完整性，讓之後的改寫能安全刪掉這條手刻檢查、改用
   `gate_structural_schema_first_error`，不是獨立的 bug fix。（`/simplify` altitude
   review 抓到我最初的錯誤描述，已當場修正。）
3. `tests/lib/gate-reviewer-result-fixtures.sh`：從 `test-core-schemas.sh` 抽出既有的
   `_gate_reviewer_result_valid_instance` 共用，避免新測試檔另建第二份「合法 reviewer
   result 長什麼樣」而漂移（reuse-agent 發現，已修正）。新增
   `tests/shell/test-gate-structural-verify.sh`（10 案例）鎖定上述兩項行為。
4. 全套測試 104/104、pr-gate sequential GO（全體 reviewer approve）驗證通過。
   **仍未開始**：`_gate_reviewer_protocol_document_verify` 與
   `gate_synthesis_protocol_verify` 本身的改寫（先跑 schema、刪除多餘手刻邏輯、保留
   唯一 domain hint 與所有跨物件／外部比對）留給下一個 slice。

**Update 2026-08-24（同日續，pr:#527）：`_gate_reviewer_protocol_document_verify` 改寫，
先跑 `/pre-impl`**：深入盤點後發現原始 pre-impl 對「domain hint 只有一處」的判斷過於
樂觀——實測至少三處手刻診斷（blocking_severity_violation／blocking_origin_violation／
test_gap_violation 的逐行 ID 命名＋sibling-enum 提示）都在既有測試裡被明確斷言精確文字，
刪除會真的降低 reviewer 重試迴圈的可用性，因此全數保留，未刪除：
1. 改用 `gate_structural_schema_first_error` 涵蓋 envelope 形狀（only_keys／kind／
   schema_version／coverage_claim）、coverage 陣列形狀（11 個宣告 surface＋逐項形狀）、
   finding 泛用形狀（縮寫 ID、不合法 evidence path 等未被下方手刻檢查攔下的情況）、
   verdict 形狀／相關性——全部已在 `core/schema/gate-reviewer-result.schema.json` 宣告。
2. 手刻檢查的執行順序刻意調整：`blocking_severity_violation`／`blocking_origin_violation`／
   `test_gap_contract`（逐行 ID 命名＋唯一 domain hint）必須搶在 schema 泛用訊息之前跑，
   否則 schema 會先攔截同一違規、產生較不具體的通用訊息；schema 呼叫本身用
   `case "$schema_path" in '$.test_gaps'*) ...` 判斷是否要讓路給手刻的 test-gap 診斷。
   這個排序耦合是 `/simplify` altitude review 明確點出的風險（未來若 schema 新增一條
   correlation，手刻檢查若沒同步搶跑，會悄悄退化成泛用訊息而非崩潰，只有斷言精確文字
   的測試抓得到），已記錄但未在本輪解決（需要 `gate_structural_schema_first_error`
   支援排除／優先序參數才能根治，屬於共用模組的後續強化，不在本票範圍）。
3. `/simplify` 四項平行 review 一致抓到 `display()` jq helper 在兩個獨立 jq 呼叫裡各自
   重複定義一份，已改用 bash 變數 `jq_display_def` 單一來源、兩處字串接合共用；並移除一段
   可證明不會觸發的「schema／手刻邏輯不一致」safety-net 防禦碼（`test_gap_contract` 依設計
   是 schema 對 test_gaps 規則的完整超集，該分支邏輯上不可達）。
4. `runtime/bin/pr-gate.sh` 的 `_GATE_RETRYABLE_PROTOCOL_REASONS` 陣列比對的是本函式回傳
   的 reason STEM 字串——重寫後仍回傳同一組五個分類字串（不變），未改動 pr-gate.sh。三處
   各自維護同一組字串（bash case、jq 訊息、pr-gate.sh 陣列）是既有模式，非本輪引入，altitude
   review 建議未來收斂成單一來源，列為 someday 而非本票範圍。
5. 驗證：`tests/shell/test-pr-gate.sh` 全套 285/285（含 8 個斷言精確診斷文字的
   reviewer-protocol 案例、synthesis-protocol 案例）、`lint-scripts.sh`／`lint-shellcheck.sh`
   全綠、pr-gate sequential 首輪即 GO。**仍未開始**：`gate_synthesis_protocol_verify`
   同模式改寫，留給下一個 slice。

**Update 2026-08-25（done，pr:#528）**：`gate_synthesis_protocol_verify` 完成同模式
改寫，四個 artifact type（assurance／scope-manifest／reviewer-result／synthesis-result）
全數收斂為 schema-first。`coverage_matrix`／`reviewer_finding_inventory` 兩個陣列項目
形狀改走 `gate_structural_schema_first_error` 共用解譯器；跨文件 parity（與原始 reviewer
document 逐欄位比對）、`findings_union`／`disagreements` 診斷、重複 id 偵測、injection-safe
id quoting 維持手寫——理由同前幾輪已定案的判斷：這些是跨物件推導或精準斷言文字的診斷
訊息，schema 無法表達或改寫會犧牲 retry-loop 可用性。新增 schema-owned enum violation
的回歸測試。pr-gate sequential 首輪 GO（critic／qa-tester／architecture-reviewer／
security-reviewer 全數 approve）。本票（含 #480/#524/#525/#526/#527/#528 六個 PR）全部
Requirement 皆已交付，狀態改為 done。狀態旗標本次補記——實際交付日為 2026-08-24（pr:#528
merge 時間），修正時才發現漏更新，與 [[CC-567]] 同一種模式：合併後
務必立刻回頭改票面狀態，否則下一次規劃會誤判成尚有剩餘工作。

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

## CC-536 — Adapter SDK lifecycle／manifest／trace expansion ✅ 2026-08-27

**See**: pr:#549

**Closure (2026-08-27)**: `runtime/lib/dispatch-common.sh` 加 4 個原語，取代 4 個
adapter 各自的複製：`dc_run_timestamp`（`TS=$(date …)-$$` ×4 → 1）、
`dc_resolve_sibling_file`（isolation-map／alias-tsv 的 3 段 fallback walk，×8 站點，
安靜回傳、caller 自己出錯誤訊息）、`dc_snapshot_copy_extras`（snapshot 額外檔清單
改成 `<src> <dst>` 參數對，非硬寫 cp 序列——D1 選 (c)：bash array 傳參、lib 內零
adapter 名）、`dc_parse_common_flags`（共同 7 旗標，未認得的 token 回 `DC_RESIDUAL_ARGS`
給各 adapter native tail——D3）。D2：一次做完含 snapshot bootstrap。isolation schema
翻譯、model 解析、CMD 組裝、run、banner、token log 全留 per-adapter；`adapter-manifest.sh`
（CC-531）與 CC-530 source-safety 契約未動。4 個 adapter 的 `--print-cmd` 對 `origin/main`
逐位元組相同。`test-dispatch-common.sh` 加每原語單測 + no-adapter-name 結構守衛；4 個
adapter 套件各加 parser-handoff 回歸（shared×native 交錯、缺值→exit 2）。Gate：full-tier
GO round 2（round 1 NO-GO：只有 codex 有新 parser 覆蓋，claude/grok/opencode 缺）。

**Problem**: `dispatch-common.sh` 已共用 snapshot、basic validation、trace 與 footer，
但 Claude、Codex、OpenCode、Grok 仍重複 self-snapshot/re-exec、common option
parsing、timestamp、manifest list/scalar、isolation translation loading 與 trace
bootstrap。

**Why**: 重複的是 Adapter lifecycle、transport、trace 與 contract glue，不是
executor-native behavior。擴充窄型 SDK 可讓新 Adapter 專注 native mapping，同時
避免製造一個包含所有供應商分支的巨型通用 Adapter。

**Requirement**:

1. 盤點並抽出 snapshot re-exec、common args、manifest access、isolation resolution、
   trace begin/finish 與 footer publication 等有至少兩個等價 consumer 的 primitives。
2. Manifest access 共用 [[CC-531]] authority；source behavior 共用 [[CC-530]]
   contract，且不得重新定義 identifier 或 entrypoint policy。
3. Codex reasoning/approval/sandbox、OpenCode API fallback、Claude headless output、
   Grok model/isolation semantics 等 native behavior 保留在各 Adapter。
4. Adapter conformance fixtures 鎖定 shared contract與每個 native translation；
   新 Adapter 的 executable主要只需 native CLI 定義、argument mapping、execution
   與 result parsing。

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

## CC-538 — Host resolver／doctor shared primitives ✅ 2026-08-27

**See**: pr:#548

**Closure (2026-08-27)**: `runtime/lib/host-resolver.sh` holds the parameterised
`host_simple_config_root <label> <env> <subdir>` extracted from the byte-identical
codex/grok/opencode `*_host_config_root` bodies (3 consumers); Claude keeps its
own canonical/legacy dual-var resolver (Req 1). `runtime/lib/host-doctor-primitives.sh`
holds the shared jq path-normalize / `--host` strip fragments (4 / 3 consumers) and
`host_doctor_filter_non_executable` (2 consumers); the 1-consumer variant
`normalize_path` in `hosts/claude/lib/doctor.sh` stays local per Req 4.
`host_manifest_target_path` in `host-manifest.sh` replaces the "scan
install_targets, match, expand" loop opencode ×3 + grok ×1 each re-implemented.
No host-name `case` enters shared code (Req 3); each host keeps its labels,
env-var names, defaults, allow-lists and messages. New
`tests/shell/test-host-resolver.sh` covers simple-resolver parity, a structural
no-host-switch guard, Claude conflict semantics, and concurrent-failure
diagnostic isolation (Req 4). Gate: full-tier GO round 3 (round 1 NO-GO on a
shared-`/tmp` stderr path in the new suite; fixed with per-call `mktemp` + a
concurrency regression case).

**Problem**: Codex、OpenCode與Grok的root resolver幾乎使用相同演算法，只差env、
default subdirectory與label；doctor modules也重複path normalization、command
identity、managed block、target/executable checks與diagnostic rendering。Claude
另有legacy alias conflict，不能直接套用 simple resolver。

**Why**: Shared primitives可降低新增Host成本，但Host policy與ownership仍必須留在
各Host module；若把host-name switch重新放回shared runtime，會破壞目前正確的
vertical ownership boundary。

**Requirement**:

1. 提供parameterized simple-root resolver，讓無legacy alias的Host宣告label、
   primary env與default root；Claude繼續由自身resolver處理primary/legacy conflict。
2. 抽出純mechanical doctor primitives：JSON path normalization、exact command
   identity、managed block detection、target existence、executable check與common
   diagnostic rendering。
3. 每個Host仍決定設定是否正確、哪些asset屬於自己及修復建議；shared layer不得新增
   host-name `case`或吸收Host-specific policy。
4. Conformance tests涵蓋simple resolver parity、Claude conflict semantics與各Host
   doctor輸出；第二個真正consumer存在前不抽單一用途helper。

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

## CC-540 — `pmctl state prune`：刪除前摘要抽取＋驗證，避免歷史分析資料隨磁碟空間消失 ✅ 2026-08-22

**Problem**: `~/.local/share/pm-dispatch/state/projects/<hash>/runs/` 每次
`gate run`／dispatch 都留下一個完整目錄（`.gate-results`、`.agent-trace`、
supervisor log 等），目前沒有任何 retention 機制。實測 pm-dispatch 專案本身
自 2026-06-24 起已累積 615 個 run 目錄、258M；另一個 repo 專案累積到 289M。
`pmctl` 完全沒有 prune／gc／retention 相關子指令。對這批歷史紀錄做一次性
分析（gate verdict 分布、reviewer block 原因分群、執行耗時）證明其中有真實
可複用的訊號（例如 qa-tester 的 high finding 集中在「新行為只驗到鄰近路徑、
未直接斷言新行為本身」），若日後只靠單純刪除瘦身，這類訊號會隨磁碟清理
一起消失，且無法回溯重建。

**Why**: 這些 run 目錄同時是「必須清理的體積負擔」與「唯一能重建歷史模式
分析的原始資料」，兩者互斥。刪除必須是不可逆動作裡少數需要事前防呆的
案例：若摘要抽取邏輯本身有 bug（漏欄位、誤判 verdict），刪除後就沒有辦法
重新摘要。且已知原始資料本身可能不完整（[[CC-509]] 修復前的 detached
launch 早期死亡會留下 0-byte 空殼 gate 結果），摘要邏輯必須把這種情況如實
標記，不能誤判為抽取失敗或悄悄略過。

**Requirement**:

1. 新增 `pmctl state prune`（或等效子指令），對 `state/projects/<hash>/runs/`
   下超過 age 門檻的 run 目錄執行「先摘要、驗證、後刪除」流程，順序不可
   反轉。
2. 摘要內容至少涵蓋：run id／時間戳、耗時（以目錄內檔案實際 mtime 極差計算，
   不得信任檔名內嵌時間戳——檔名時間與檔案 mtime 之間曾實測有系統性偏移）、
   gate YAML front-matter 的 `final`／`tier`／`most_severe`／各 reviewer
   verdict，以及每個 reviewer 的 finding 數量按 severity 分桶（不需保留
   finding 全文）。
3. 摘要寫入 project state 根目錄下永久保留的 `runs-summary.jsonl`（不受
   prune 影響），append 後必須讀回並 parse，確認必要欄位非 null 才視為
   驗證通過；驗證失敗時該筆的原始 run 目錄不得刪除，並記錄到
   `prune-skipped.log`，不得靜默略過。
4. 原始資料本身不完整（例如空白 `.gate-results/gate-*.md`）必須摘要為
   明確狀態（如 `status: incomplete_source`），不得因缺少 `final` 欄位而
   判定為摘要邏輯失敗。
5. 提供 `--dry-run`：只列出即將摘要＋刪除的 run 清單與抽取出的摘要內容，
   不寫入 summary 檔也不刪除，供人工抽查。
6. 摘要寫入與物理刪除之間保留寬限期（預設可設定天數）；寬限期內即使摘要
   已寫入，原始 run 目錄仍保留，供發現摘要邏輯 bug 時回溯重跑。
7. 測試需覆蓋摘要抽取的邊界情況，各自獨立 fixture＋斷言：reviewer
   `skipped`、`block-soft` severity、`tier` 欄位缺失、完全空白的
   `.gate-results`、單一 reviewer 多筆 finding、耗時計算的檔名時間戳誤導
   案例。

**Done-when**: `pmctl state prune` 可安全瘦身 `runs/` 目錄且不遺失可分析
的摘要訊號；摘要驗證失敗或原始資料不完整時行為明確、可觀察，不悄悄砍掉
無法復原的資料。

**Source**: 2026-07-31 主線程對 615 筆 gate 執行紀錄的一次性分析（NO-GO 率
57%、qa-tester 為最大 blocker），發現 runs/ 目錄無 retention 且分析價值
未被保留；使用者要求 prune 時一併產出摘要。

**Closure 2026-08-22**：查證後發現 `pmctl artifacts gc` 已是本票 Requirement 1 所指的
「等效子指令」——它已對 `state/projects/<hash>/runs/` 做 keep-last／max-age-days
retention，只是刪除前完全沒有摘要步驟。選擇擴充既有 `pmctl_artifacts_gc`
而非另立 `pmctl state prune`，避免兩套並存的刪除機制互相打架。

新增：`_pmctl_artifacts_run_summarize_json`（kind=gate/dispatch、
status=complete/incomplete_source、以目錄內檔案實際 mtime 極差計算的 duration——
批次一次 `stat -c %Y ... +`，不逐檔案 spawn，避免重演 CC-557/CC-560 的
per-item subprocess 教訓；gate 分支重用既有 `_gate_result_frontmatter_value`
解析 final/tier/most_severe，findings-by-severity 抓不到可解析的
`reviewer_result_v1` JSON block 時明確回報 `"unavailable"` 字串而非 0，避免
誤讀成「沒有 finding」）與
`_pmctl_artifacts_run_summary_append_verified`（append 後讀回驗證，
`status=complete` 的 gate 摘要只要求 `final` 非 null——tier／most_severe
在較舊 schema 版本可能本來就沒有，強制要求會誤判誠實的舊資料為抽取失敗、
永久卡住無法瘦身；驗證失敗即回滾剛寫入的那行並記錄到
`prune-skipped.log`，來源 run 目錄維持不刪）。新增 `--grace-days`（預設 3，
`PM_DISPATCH_GC_GRACE_DAYS` 可覆寫）：已摘要的 run 至少經過寬限期才會物理
刪除；既有 `runs-summary.jsonl` 的 `summarized_at` 一次性讀入關聯陣列比對，
不逐筆查詢。`--dry-run` 會預覽即將產出的摘要內容與寬限期倒數，不寫入摘要
檔或刪除任何檔案。

`tests/shell/test-pmctl-artifacts.sh` 新增 8 案：summarize-then-defer、
grace-period 期滿後刪除、incomplete_source 不當作驗證失敗、tier 欄位缺失
不當作驗證失敗、duration 取真實 mtime 而非 run id、findings-by-severity 分桶、
findings-by-severity 在無可解析區塊時回報 unavailable、驗證失敗時回滾＋記錄。
既有 19 案兩案（`--dry-run`／`--keep-last`）因新的預設 grace-period 行為改為
顯式帶 `--grace-days 0`，並順手修掉其中一案既有的 `grep -c ... \|\| printf`
慣用語 bug（no-match 時會把 grep 自己印的 "0" 與 fallback 的 "0" 併成
"0\n0"，撞壞 `-eq` 比較，過去被舊行為的固定 2 個 match 蓋過去而沒發作）。

**pr-gate 第一輪（full tier，parallel，5 reviewer）NO-GO（2 hard_block + 1
soft_block + 1 advise）**：risk-reviewer 指出 `_pmctl_artifacts_run_summary_append_verified`
的驗證只檢查「讀回的最後一行看起來合法」，沒檢查那行是不是**這筆 run** 自己寫的——
若 append 本身失敗（或被併發寫入插隊），`tail -1` 可能讀到別筆早已合法寫入的紀錄，
誤判為驗證通過而放行刪除，形成 fail-open。architecture-reviewer 獨立指出更根本的
併發問題：`already_summarized_at` 是每次 `gc` 呼叫各自載入一次的快照，兩個併發
`gc` process 可能都以為某 run 尚未摘要，各自 append 或各自誤判對方的合法行為
「驗證失敗」而回滾。qa-tester 指出兩個新 operator 契約完全沒有整合測試：
`PM_DISPATCH_GC_GRACE_DAYS` 環境變數單獨生效與「flag 優先於環境變數」的優先序，
以及正 grace 值下 `--dry-run` 真的只預覽、不寫入不刪除。critic（advisory）指出
`PM_DISPATCH_GC_GRACE_DAYS` 沒登記進 `docs/architecture/script-variable-consumers.tsv`。

修正：
1. 驗證改為 `jq -e --arg run_id ... '.run_id == $run_id and ...'`——讀回的那行必須
   真的是這筆 run 自己的紀錄，不能只是「看起來合法的某一行」；同時檢查 append 本身
   的 exit code。
2. 新增 `_pmctl_artifacts_run_summary_prune_line`（依內容精確比對移除，取代原本
   位置式的 `sed -i '$d'`——併發下「最後一行」不保證是自己剛寫的那行）。
3. 把「查詢是否已摘要→摘要→append+驗證→grace 判斷→刪除」整個決策抽成
   `_pmctl_artifacts_gc_process_run`，透過既有的 `serialize_with_lock`
   （`runtime/lib/portable.sh`，本 repo既有的 flock／mkdir-lock 共用原語，非
   新建鎖機制）以 `runs-summary.jsonl` 路徑為 lockbase、每個 project 序列化；
   查詢改成鎖內即時查（新增 `_pmctl_artifacts_run_summary_lookup`），不再依賴
   呼叫前的批次快照。犧牲了原本「一次載入全部 summarized_at」的效能優化，但
   額外 jq 呼叫數與「符合刪除資格的 run 數」成正比（通常個位數），不是
   CC-557/CC-560 修的「每個候選都一次」那種與**全部 run 數**成正比的形狀。
4. `docs/architecture/script-variable-consumers.tsv` 與
   `script-variable-inventory.tsv` 都補上 `PM_DISPATCH_GC_GRACE_DAYS` 列。
5. 新增 5 案：`PM_DISPATCH_GC_GRACE_DAYS` 單獨生效、flag 覆蓋環境變數、
   正 grace 值下 `--dry-run` 兩則預覽且不落地任何檔案、兩個 `gc` process
   併發跑同一個 run 只留一筆摘要記錄且無 `prune-skipped.log`、summary 檔
   設唯讀強制 append 失敗時該 run 仍保留且被記錄（不誤判為成功）。

`tests/shell/test-pmctl-artifacts.sh` 32 案全過（原 27 案＋本輪 5 案）。

**pr-gate 第二輪（full tier，parallel，5 reviewer）NO-GO（1 block + 1
block-soft，risk-reviewer／architecture-reviewer／security-reviewer 三方
approve）**：critic 指出 `PM_DISPATCH_GC_GRACE_DAYS` 環境變數本身沒有數值驗證——
非數字值會直接進 `grace_seconds=$(( grace_days * 86400 ))` 算術上下文，行為
未定義，可能悄悄瓦解寬限期這道安全窗。qa-tester 指出併發測試把兩個子行程的
exit code 都用 `wait ... || true` 吞掉，若其中一個 process 真的失敗，測試仍可能
巧合通過。

修正：
1. 在 `grace_seconds` 算術式前加驗證（比照既有 `--grace-days` flag 的同一條
   regex），非數字直接 `return 2` 並印出可操作訊息；驗證點刻意放在
   `--all-repos` 已提前 return 之後，不讓一個與該路徑無關的壞環境變數擋住
   `--all-repos` 清理。
2. 併發測試改成分別 `wait "$pid1"`／`wait "$pid2"` 各自取得 exit code 並
   斷言兩者皆為 0。
3. 新增一案：`PM_DISPATCH_GC_GRACE_DAYS` 設非數字時 exit 非 0、印出包含
   變數名的訊息、run 目錄與 `runs-summary.jsonl` 完全不受影響。

`tests/shell/test-pmctl-artifacts.sh` 33 案全過（32 案＋本輪 1 案）。

**pr-gate 第三輪（full tier，parallel，5 reviewer）NO-GO（1 block，
architecture-reviewer／risk-reviewer 為同一根因 RCG-002 各自 advise，
critic／security-reviewer approve）**：qa-tester 指出只驗證了
`PM_DISPATCH_GC_GRACE_DAYS` 環境變數路徑，`--grace-days` **flag** 本身帶非數字值
從未被直接測過（雖然 flag 解析的驗證邏輯本來就存在）。architecture-reviewer 與
risk-reviewer 指出同一個根因（RCG-002）：`serialize_with_lock` 逾時或失敗時，
迴圈把「沒有 RESULT 輸出」與「這個 run 沒事可做」混為一談，`gc` 仍回報乾淨的
成功摘要，讓鎖失敗的 run 悄悄跳過處理卻看起來正常結束。

修正：
1. 新增 `--grace-days not-a-number` 的直接整合測試（flag 路徑，區別於既有的
   環境變數路徑測試）。
2. 迴圈改為明確接住 `serialize_with_lock` 自身的 exit code；逾時或缺少
   `RESULT` 行時印出具名診斷（哪個 run、哪個 exit code）並累計失敗數，整個
   `gc` 呼叫結尾若有任何鎖失敗則 `return 2`，不再悄悄併入「0 個變動」的
   成功摘要。
3. 新增鎖逾時整合測試：外部 process 先用 `flock` 佔住
   `runs-summary.jsonl.lock`，以短 `PM_DISPATCH_LOCK_TIMEOUT_SECS` 跑 `gc`，
   斷言 exit 非 0、來源 run 目錄保留、stderr 具名指出是哪個 run。**這個測試
   當場抓到我自己引入的第二個真 bug**：`outcome_line="$(... | grep ... | tail -n 1)"`
   在鎖逾時、`$raw` 為空的情況下，`grep` 找不到匹配會回傳 exit 1；
   `runtime/lib/pmctl-artifacts.sh` 被 `cli/pmctl` 以 `set -euo pipefail`
   來源，`pipefail` 下這個沒接 `|| true` 的指令替換賦值本身就會直接觸發
   errexit，讓上面第 2 點的 `return 2` 邏輯完全成為永遠執行不到的死碼——不是
   測試邏輯的疏漏，是實作本身的疏漏，測試寫對了才抓到。修法：該賦值句尾
   加 `|| true`。

`tests/shell/test-pmctl-artifacts.sh` 35 案全過（33 案＋本輪 2 案）。

**pr-gate 第四輪（full tier，parallel，5 reviewer）NO-GO（1 block + 1
block，architecture-reviewer advisory，risk-reviewer／security-reviewer
approve）**：critic 指出 `_pmctl_artifacts_run_summary_lookup` 只檢查
`run_id` 相符與 `summarized_at` 非 null，沒有比照 append 時的同一套結構性
契約重新驗證——若有一筆不是經本票驗證流程寫入的既存紀錄（人工編輯、舊
schema、意外損毀）恰好符合這兩個條件，仍會被信任為「已驗證」並據此讓
grace 期滿後直接刪除，等於繞過整張票要建立的耐久性保證。qa-tester 指出
鎖逾時測試用固定 `sleep 0.3` 讓 lock holder 有機會先搶到鎖，屬非決定性
時序假設，且從未斷言 lock holder 子行程自己的 exit code。

修正：
1. `_pmctl_artifacts_run_summary_lookup` 的 jq 查詢加上與
   `_pmctl_artifacts_run_summary_append_verified` 相同的結構檢查
   （`kind`／`status` 非 null，且 `status=="complete" and kind=="gate"` 時
   `gate.final` 非 null）；不符合的既存紀錄視為「尚未有效摘要」，強制
   重新走一次 summarize＋append＋verify，而非直接信任。
2. 鎖逾時測試改為：lock holder 在 `flock -x` 真正取得鎖之後才寫入一個
   marker 檔，測試端改成有界輪詢（最多 5 秒）等 marker 出現，取代固定
   `sleep`；並個別 `wait` lock holder 子行程、斷言其 exit code 為 0。
3. 新增一案：既存摘要缺 `status` 欄位（模擬損毀／異質寫入）即使
   `summarized_at` 已遠超 grace 天數，仍不得被信任為已驗證，run 目錄本輪
   不刪除，改為寫入一筆新的、結構完整的摘要。

architecture-reviewer 另提一則 advisory（非本輪必修）：`gc` 直接呼叫
`gate-result-verify.sh` 的 `_gate_result_frontmatter_value`（模組間耦合到
一個非公開匯出的 helper），建議未來若有第二個消費端再抽成正式共用邊界；
本票僅一個消費端，暫不動架構。

`tests/shell/test-pmctl-artifacts.sh` 36 案全過（35 案＋本輪 1 案）。

**pr-gate 第五輪（full tier，parallel，5 reviewer）NO-GO（1 block，
critic／qa-tester／architecture-reviewer／security-reviewer 四方
approve）**：risk-reviewer 指出唯一剩下的真缺口——append+讀回驗證只證明
寫入到了 OS page cache，不是持久化儲存；在 `--grace-days 0` 下驗證通過後
立刻 `rm -rf`，若驗證通過與實際刪除之間發生斷電／crash，可能造成「摘要
沒真的落盤、來源 run 目錄已經沒了」的雙重遺失——正是本票從一開始要防的
那種不可逆遺失。

修正：驗證通過後、回傳「可安全刪除」之前，對 summary 檔呼叫
`sync -- "$file"`（GNU coreutils sync 支援對單一檔案 sync，早於本票決定
Linux/WSL2-only 核心開發期即可依賴）。`sync` 失敗視同驗證失敗——不刪除
line（資料本身可能沒問題，只是沒法確認落盤），run 目錄本輪不刪除、記錄到
`prune-skipped.log`；成功則放行。新增一案：stub `sync` 讓其固定失敗，
斷言 run 目錄保留、`prune-skipped.log` 具名，且 summary line 本身仍在
（fsync 失敗不等於資料無效，只是持久性未確認——比照既有的
append-failure 測試慣例，不斷言整體 exit code，因為這屬於既有的
「單一 run 驗證失敗被妥善記錄並保留」類別，不同於會強制整體 nonzero
exit 的鎖失敗類別）。

architecture-reviewer 的 advisory（模組邊界耦合）維持上一輪判斷，非本輪
必修，暫不動架構。

`tests/shell/test-pmctl-artifacts.sh` 37 案全過（36 案＋本輪 1 案）。

**pr-gate 第六輪（full tier，sequential，5 reviewer——依使用者新指示改預設
序列，見下方説明）NO-GO（2 hard_block + 1 soft_block，critic-F001／
qa-tester-F001／risk-reviewer-F001 三方鎖定同一根因，architecture-reviewer／
security-reviewer approve）**：三方都指出第五輪 fsync 修法留下的真缺口——
`sync` 失敗時只記錄到 `prune-skipped.log`，**卻沒把剛 append 的那行摘要
從 `runs-summary.jsonl` 撤回**。那一行在結構上跟正常驗證通過的紀錄完全
一樣（`run_id`／`summarized_at`／`kind`／`status`／`gate.final` 都非
null），所以下一次 `gc` 呼叫的 `_pmctl_artifacts_run_summary_lookup` 會把
它當成「已驗證」直接信任，讓 grace 期滿後的刪除建立在一筆從未成功落盤
確認過的紀錄上——等於本票從一開始要防的「驗證機制本身有 bug 導致誤刪」
情境，只是換了個觸發路徑。上一輪（第五輪）Closure 段落中「fsync 失敗
run 目錄保留、summary line 本身仍在」的描述本身沒錯（那是舊行為的忠實
記錄），但那個「仍在」正是本輪三方鎖定的根因，隨本輪修法作廢。

修正：`sync` 失敗分支比照既有「驗證失敗」分支的做法，在記錄
`prune-skipped.log` 之前先呼叫 `_pmctl_artifacts_run_summary_prune_line`
把剛 append 的那行精確移除。這樣任何一次 gc 呼叫只要無法確認落盤，就
不會留下任何看起來合法的紀錄——下一次 gc（不論 sync 這次是否恢復正常）
都必須從頭重新 summarize＋append＋sync，不可能繞過重新驗證直接刪除。

新增迴歸測試 `case_gc_retry_after_fsync_failure_resummarizes_before_deleting`：
第一次呼叫 stub `sync` 固定失敗（斷言 run 目錄保留、摘要行已被撤回，非
本輪新增而是修正既有 `case_gc_summary_fsync_failure_retains_run` 的斷言
方向），第二次呼叫恢復正常 `sync`，斷言 run 目錄最終被刪除且
`runs-summary.jsonl` 中該 run_id 恰好一行——證明刪除建立在第二次呼叫
自己全新、成功落盤確認的紀錄上，而不是復活第一次那筆未確認的紀錄。

`tests/shell/test-pmctl-artifacts.sh` 38 案全過（37 案＋本輪 1 案）。

**pr-gate 序列化說明**：本輪起使用者要求後續 pr-gate 一律預設走
`--mode sequential`，若判斷需要 parallel 須先徵求使用者同意；已寫入
repo 外部個人 memory（非本 repo 檔案）。

**See**: pr:#515

---

## CC-505 — context plane lexical 檢索補完與排序 ✅ 2026-08-22

**Problem**（2026-07-20 四方 multi-model synthesis：ChatGPT／Fable 主線程／opencode nemotron-3-ultra／codex gpt-5.6-sol；codex 實證發現）: 現行 context plane 並非真全文檢索——
1. chunk 只索引 heading + 正文前 200 字元（`runtime/lib/pmctl-context.sh:367`、`:436`），段落深處與 shell 函式本體的內容檢索不到。
2. FTS5 只作 quoted match 過濾器，未用 `bm25()` 排序，無 path/heading/trust/recency 加權；hit confidence 依 hit type 硬編碼而非取自 symbols 表（`:1128`）；LIKE fallback 同樣無序。
3. reuse-scan 把描述斷成獨立小寫詞逐一查詢，symbol hits 一律排在 text hits 前、取前五——「前五」反映插入順序而非相關性（`:1085`、`:1677`）。
4. `context pack` 有去重但無全域 item/byte budget；`risks[]` 恆為空（`:1544`，CC-347 佔位）。
5. freshness 只看 mtime；`files.sha1` 存了但未參與變更偵測，保 mtime 的編輯會靜默 stale（`:629`）；extractor 改版也不會觸發重建。

**Why**: 這是實作缺口而非 lexical 檢索已到極限——在補完之前，[[CC-340]]（embeddings）的 resume 條件「FTS ranking 不足」無法被誠實評估；而 [[CC-346]] edges 層的查詢品質也建立在檢索排序之上。本票是 context-plane 強化路線（graph-lite：edges + blast radius）的第一片。索引補完只能證明「索引較完整、輸出較小」，尚不能證明「Agent 會正確使用且不因少讀而降準」——後者由 Phase 2 儀器化蒐證、[[CC-506]] 評測收緊，刻意分離節奏（工程時間 vs 日曆時間）。

**Requirement — Phase 1（engine + 統一排序 + fixtures；deterministic，可一~兩 PR 收掉）**:
1. chunk 儲存有界的完整段落內容（bounded full-section bodies），取代 200 字元截斷；DB 尺寸以上限控制。
2. FTS5 路徑改用 `bm25()` 基礎排序，疊加 exact-symbol／heading／trust／domain 加權；LIKE fallback 給出確定性排序。排序穩定性的定義：同一 index snapshot、同一 query 下 rank 具確定性。
3. 所有 consumer（`query`／`prompt-scan`／`reuse-scan`／`context pack`）共用同一 ranking path，不得各自依插入順序、symbol-first 或獨立 heuristic 排序。每個 hit 輸出 `rank`、`match_kind`、bounded `line_start`／`line_end`、ranking score components、index freshness。**工作流入口亦受此約束**：`pmctl dispatch run` auto-pack（經 reuse-scan）、`pmctl ship`（經 dispatch）、`pmctl gate run` memory context（經 `context pack --source memory`）注入的內容必須可追溯到同一 ranking path 與 budget/freshness 契約；未來新增的 workflow surface 接 context plane 時同樣不得繞過（ratchet）。
4. 命名契約：lexical ranking 輸出 `ranking_score` + `score_components`（bm25／boosts 分項），不得命名或解釋為 correctness confidence——解析信心分級（EXTRACTED／INFERRED／AMBIGUOUS）屬 [[CC-346]]，與 lexical ranking 分離。
5. `context pack` 增加全域 item + byte budget（跨 query terms），超額截斷須在輸出中揭露。
6. freshness：mtime 快篩後以 `files.sha1` 驗證可疑案例；新增 `index_meta(schema_version, extractor_version, built_at)`，extractor 版本變更強制目標重建。
7. deterministic retrieval fixture corpus：覆蓋 exact symbol、heading、段落深處、同詞多義、path boost、trust weighting、長 section 分段、mtime-preserving edit、extractor-version rebuild。每個 fixture 宣告 expected top-K refs；exact-symbol expected ref 必須 top-1，其餘 expected refs 必須位於 bounded top-K。

**Update 2026-08-20（Phase 1 第一片：Req 1 + Req 6）**: chunk 改存 bounded full
bodies；程式語言檔案先前被壓成**一個 chunk、只存檔首 200 字元**，函式本體完全不在
索引裡，現改為窗口化。超過 cap 的內容一律**分段而非截斷**——長 markdown section 依 Req 7
如此，單一實體行超過 cap 者亦然（否則尾端會被 SQL escaper 靜默丟棄，而索引仍回報
成功；此缺陷由首輪 gate 的 qa-tester／critic 各自獨立指出）。新增 `index_meta(schema_version, extractor_version, built_at)`，extractor 版本
變更強制全量重新抽取；freshness 以 mtime 快篩後由 `files.sha1` 決定，mtime 不變的
編輯不再靜默 stale。

**參數有量測依據**（本 repo 實測）：窗口 20 行＋cap 2000 → 保留率 99.3%、p95=1232
遠低於 cap；40 行時 p95=2358 **超過** cap，會讓 cap 從離群值防護退化成常態截斷。

**已量測的成本**：chunk 5,027→13,041（2.6×）、DB 5.5→32.6 MB（6×）、增量執行
6.3→9.3s（+48%，sha1 驗證）、全量重建 1m23s。重建成本經 profile 後確認主因是既有
的 `_ctx_generate_file_sql` 被 chunk 數放大，另立 [[CC-563]]；順帶移除了
`file_chunks.sha1` 的 per-chunk hashing 子行程（全 repo 查證無任何 reader，實測佔
索引時間逾四成）。

**未動**：Req 2/3/4（bm25 排序與四 consumer 共用 ranking path）、Req 5（pack budget）、
Phase 2 全部。票維持 active。（此段為 2026-08-20 當時狀態，Req 2-7 已於後續兩次更新完成，見下。）

**Update 2026-08-21（Phase 1 第二片：Req 2/3/4）**：所有排序運算集中到唯一入口
`_ctx_query_hits_raw`——FTS5 路徑改用 `bm25()`（SQL 內直接算，不額外 spawn awk/bc
per row，見 `_ctx_compose_score` 註解引用的 CC-563 教訓）疊加 trust／domain 加權；
LIKE fallback 路徑改為 `ORDER BY path, line_start` 確定性排序（誠實聲明：非
relevance-ranked，只是 run-to-run 一致）。新增 `_ctx_rank_hits` 作為唯一排序＋截斷
入口，四個 consumer（`query`／`pack`／`reuse-scan`／`prompt-scan`）全部改呼叫它，
不再各自用「symbol hits 先、text hits 後、取前五」這種插入順序當排序（`reuse-scan`
原本 `cat sym_tsv files_tsv | head -5`、`prompt-scan` 原本 `cat files_tsv sym_tsv`
兩者順序還互相顛倒，證明先前完全是插入順序副作用而非設計）。三個工作流入口
（`pmctl-dispatch.sh` auto-pack、`pmctl-pm.sh`、`gate-memory-context.sh`）
呼叫點本身**未變更**——它們消費同一批共用函式，自動繼承新排序，驗證了 ratchet
條款成立。每個 hit 新增 `rank`／`match_kind`／`line_start`／`line_end`／
`ranking_score`／`score_components` 欄位，附加在既有 schema-required 的
`confidence` 之外（未改名、未改值，兩者語意刻意分離）；`context-pack.schema.json`
`schema_version` 2→3。`tests/shell/test-pmctl-context.sh` 130 案全過（3 案因
schema_version 斷言隨版次更新，非行為回歸）。**殘留**：Req 5（pack 全域 item/byte
budget）、Req 7（deterministic fixture corpus）、Phase 2 全部。票維持 active。

**Update 2026-08-21（Phase 1 第三片：Req 5 + Req 7，Phase 1 全數交付）**：
`pmctl context pack` 新增 `--max-items`／`--max-bytes`（預設 200 items／200000
bytes，可由 `PM_DISPATCH_CONTEXT_PACK_MAX_ITEMS`／`PM_DISPATCH_CONTEXT_PACK_MAX_BYTES`
覆寫）。新增 `_ctx_apply_pack_budget`：先跨 `files`／`symbols`／`memories` 三陣列
合併排序（`ranking_score` 同一量尺可比），依全域最高分保留至 `--max-items`；仍超過
`--max-bytes` 則逐一丟棄目前最低分存活項並重新序列化（沿用 `pmctl_pm_bound_memory_pack`
既有的「整筆刪除＋重新序列化，不直接切 JSON 字串」寫法），直到符合或歸零。任何
pack 輸出都附加 `truncation`（`applied`／`reason`／`budget`／`total_before`／
`kept`／`dropped`），即使沒有截斷也明確揭露，呼叫端不必用陣列長度反推。首版有真
bug：byte 迴圈量測的是加上 `truncation` 物件*之前*的 bytes，導致最終輸出（含
`truncation` 本身）仍可能超出 `--max-bytes`——由本票自己新增的迴歸測試
（`--max-bytes` 強制截斷案）當場抓到，修正為每次迭代都量測「item 陣列＋
truncation 物件」組裝後的最終大小。`context-pack.schema.json` schema_version
3→4，`truncation` 為 v4 必填（沿用既有 `if schema_version==N then required` 樣式）。

Req 7 新增 `make_retrieval_corpus_repo` 宣告式 fixture corpus，涵蓋 exact
symbol（top-1）、heading match、深段落內容（越過舊 200 字元截斷點）、同詞多義
（exact symbol 勝過純文字提及）、path/domain boost（knowledge domain 命中排在
repo domain 之前）、long section 分段（35 行 section 尾端 marker 仍可檢索，證明
Req 1 窗口化生效）；另外 trust weighting 用獨立 memory fixture（card vs
episode 共用同一詞）證明 trust 真的影響排序，不只是標籤正確。

`tests/shell/test-pmctl-context.sh` 144 案全過。

**pr-gate 第一輪（parallel，5 reviewer）NO-GO**：critic／qa-tester／risk-reviewer
三方各自獨立指出同一根因——`_ctx_apply_pack_budget` 量測 bytes 用
`printf '%s' "$final" \| wc -c`（不含換行），但函式實際輸出用
`printf '%s\n' "$final"`（含換行），在邊界值上會少算一 byte、讓超出
`--max-bytes` 的結果放行；且無「不可能的 cap」明確處理——若連 0-item 信封
（`truncation` 物件＋換行）都超過 `--max-bytes`，原本會靜默吐出超額結果。
修正：量測改成與實際輸出完全一致的形式；並新增 fail-closed 檢查，0-item
信封仍超額時回傳 exit 2 並印出可操作的 stderr 訊息，不再靜默違反自己宣告
的 budget。qa-tester 另指出 `PM_DISPATCH_CONTEXT_PACK_MAX_ITEMS`／
`PM_DISPATCH_CONTEXT_PACK_MAX_BYTES` 環境變數覆寫無對應測試，補上四案
（合法覆寫各一、非法覆寫各一）＋一案覆蓋「不可能的 cap」fail-closed 路徑。
`tests/shell/test-pmctl-context.sh` 149 案全過。

**pr-gate 第二輪（targeted，同 5 reviewer）NO-GO（1 block + 2 block-soft，
security-reviewer 轉 approve、risk-reviewer 轉 advise）**：critic 與
architecture-reviewer 各自獨立指出同一根因——no-index（無資料庫）與
sqlite-unavailable 兩條 graceful-empty 分支自己組裝並直接印出 JSON，完全
繞過唯一的 budget 執行點 `_ctx_apply_pack_budget`，導致 `--max-bytes` 設
得極小時這兩條分支仍會 exit 0 並吐出超額的空 envelope。修正：兩條分支都
改組出不含 `truncation` 的裸 pack，交給 `_ctx_apply_pack_budget` 統一組裝
／量測／fail-closed，不再各自維護第二套序列化樣板。qa-tester 另指出新增
的多筆 PMCTL 呼叫（baseline pack、corpus 迴圈 query、domain-boost query、
trust-weighting query）沒有顯式檢查 exit status，命令失敗會被當成空輸出
吞掉而非回報成 command failure——全部補上 exit code 檢查。risk-reviewer
指出 `^[1-9][0-9]*$` 對位數沒有上界，過大的值在後續 bash 算術比較可能溢位
產生誤導行為——收斂為 15 位數上限（遠低於 signed 64-bit 範圍），CLI flag
與環境變數兩種輸入路徑都收斂到同一位數上限。新增回歸測試：no-index 分支
的 impossible-cap fail-closed 案、CLI／環境變數各兩案的 overflow-boundary
拒絕案。`tests/shell/test-pmctl-context.sh` 154 案全過。

**pr-gate 第三輪（targeted，同 5 reviewer）NO-GO（1 block + 3 advise，收斂中）**：
qa-tester 指出缺一個「恰好貼齊 `--max-bytes` 上限」與「上限少一 byte」的邊界測試——
byte 比較是 `>` 不是 `>=`，需要測試鎖住這個等式邊界本身，而非只驗證「有沒有超
過」。critic 指出新增的兩個環境變數（`PM_DISPATCH_CONTEXT_PACK_MAX_ITEMS`／
`_MAX_BYTES`）沒有登記進 `docs/architecture/script-variable-consumers.tsv`／
`script-variable-inventory.tsv`（既有的 ratchet 清單）。architecture-reviewer
指出 `sources[]` 在 truncation 把所有 memory 項目都丟掉後，仍會殘留
`memory-index` 這個 provenance 項目，變成「宣稱有 producer 但沒有任何存活項目
歸屬於它」。risk-reviewer 指出所有 `--query` term 在最終 budget 套用之前就已經
各自累積 hits，沒有對 term 數量本身設界，極端呼叫（大量 `--query`）會在輸出
再小也逃不掉的前提下先耗盡中間工作量。

修正：新增 `PM_DISPATCH_CONTEXT_PACK_MAX_TERMS`（預設 50）在任何累積開始前
fail-closed 拒絕過多 term；`_ctx_pack_with_truncation` 內 `sources[]` 改為依
truncation 後實際存活的 `.memories` 長度重新過濾（過程中抓到一個 jq context bug：
`map(select(...))` 內 `.` 是陣列元素本身而非 pack root，第一版寫法讓
`.memories` 一律解析成 null，反而無條件丟棄 memory-index——用 `as $mem_kept`
在 map 之前綁定 root 值才修正）；兩個既有環境變數與新增的 `_MAX_TERMS` 都登記進
兩份 inventory tsv。新增 4 案：恰好貼齊 byte 上限與少一 byte 各一案（沿用
fixed-point 收斂手法定位「輸出剛好等於某個 cap 值」，避免任意挑一個 cap 導致
`truncation.budget.max_bytes` 本身的位數寬度反過來污染大小比較）、term 數量
上限拒絕案、`sources[]` 對齊存活 memory 項目案。`tests/shell/test-pmctl-context.sh`
157 案全過。

**pr-gate 第四輪（targeted，同 5 reviewer）NO-GO（1 block + 1 advise，
收斂近完成：architecture-reviewer／security-reviewer／risk-reviewer 三方
approve）**：qa-tester 指出新增的 `PM_DISPATCH_CONTEXT_PACK_MAX_TERMS` 只驗證
了「term 太多」的路徑，其環境變數本身的非法值（如 0）沒有直接的 fail-closed
回歸測試——補上一案。critic 指出前一輪只修了 memory-only pack 殘留
`memory-index` 的方向，同一問題的反方向（builtin-only pack 殘留
`memory-index`／memory-only pack 殘留 `builtin-index`）仍未處理——把
`_ctx_pack_with_truncation` 的 `sources[]` 調解邏輯推廣為同時檢查
`files+symbols` 與 `memories` 兩邊存活數量，兩個 producer 對稱處理，並新增
對稱的回歸測試（memory-only 不殘留 builtin-index）。`tests/shell/test-pmctl-context.sh`
159 案全過。

**pr-gate 第五輪（targeted，同 5 reviewer）NO-GO（1 block-soft，其餘 4 方
approve/pass，僅存效能疑慮）**：risk-reviewer 指出 `_ctx_apply_pack_budget`
的 byte-budget 迴圈每丟棄一筆項目就呼叫 `_ctx_pack_with_truncation`，而後者
內部的 `_ctx_pack_top_n` 會對**整個**候選集合重新排序＋重新序列化——對多
term、多 hit 的合法輸入配上偏緊的 `--max-bytes`，這是 O(丟棄次數 × 候選總數)
的二次方工作量與大量 subprocess 啟動。修正：在迴圈開始前，先把候選集合
**一次性**裁到最多 `keep_n`（≤ `max_items`）筆，之後每次 byte-budget 迭代都
只對這個已經很小的裁切後集合重新排序，把「每丟一筆重排全集合」降為「排序
一次＋後續都是小集合上的廉價重排」。新增回歸測試：40 個 term、60 個候選
symbol、`--max-bytes 4000` 強制大量裁切，斷言在合理時間內完成（30 秒上限，
非嚴格效能測試，只防止災難性劣化）且輸出仍在 byte cap 內。
`tests/shell/test-pmctl-context.sh` 160 案全過。

**pr-gate 第六輪（targeted，同 5 reviewer）NO-GO（1 block + 1 advise，其餘
3 方 approve/pass）**：qa-tester 指出 schema v4 的 `truncation` 契約（Req 5
新增）從未有過可執行的 schema-level accept/reject 測試——`test-pmctl-context.sh`
只驗證了 shell 產生端的行為，`test-core-schemas.sh`（schema 契約測試的正確
歸屬位置）完全沒有針對 v4 `truncation` 的案例。critic 指出 `pmctl_context_pack`
上方的函式頭註解仍寫著「schema v2」且只列了 `--source`，Req 2-5 疊代下來已
與實作嚴重脫節。修正：函式頭註解更新為 v4，列出 ranking 欄位與
`--max-items`／`--max-bytes`；`test-core-schemas.sh` 新增 5 案：完整 v4
truncation 驗證通過、v4 缺 truncation 拒絕、truncation 缺必要欄位拒絕、
`reason` 非法值拒絕、v1-v3 pack 不需要 truncation 仍驗證通過（相容性回歸）。
`tests/shell/test-core-schemas.sh` 160 案全過。

**Phase 1（Req 1-7）至此全數
交付。Phase 2（Req 8-10，agent 契約 + shadow telemetry）仍未開始，票維持
active。**（agent 契約 + shadow 儀器化；小 PR，跟在 Phase 1 後）**:
8. Agent-facing injection 明確採用 **index-first, source-verified** 契約：retrieval hit 是導航與 scope-narrowing evidence，不是原始來源替代品；factual conclusion、code edit、gate/security/release 判斷前必須 targeted-read 命中的 bounded span；zero-hit、stale/unknown freshness、truncated 或 ambiguous 結果必須 fallback 至 targeted Grep/Read；no hit 不得解讀為不存在。本階段只改導引措辭，**不收緊**任何現有 fallback 行為。
9. shadow telemetry：在既有 context.* 事件上記錄 top-K refs、pack bytes、full-file baseline bytes、truncation/freshness，以及 Agent 後續實際 source-read bytes 與最終修改／引用檔案是否在 top-K——供 [[CC-506]] 評測消費。覆蓋面必須含工作流路徑（dispatch auto-pack、ship、gate memory context），不得只儀器化互動式 `context query`。
10. `context_savings` 遙測命名為 `compression_ratio_vs_full_file_baseline`（注入 bytes vs 全檔 baseline bytes）；沒有 observed read-reduction 證據時不得宣稱實際節省倍數；不得引用外部專案的節省倍數宣稱。餵 [[CC-467]]／[[CC-358]] 的 evidence 線。

**Update 2026-08-22（Phase 2：Req 8-10 全數交付）**：Req 8 在
`docs/context-retrieval.md` 新增「Index-first, source-verified」一節（文件
頂部，`## Query before Read/Grep` 之前）——只改導引措辭，明文「本階段只改導引措辭，
不收緊任何現有 fallback 行為」，broad-Read 收緊仍留給 [[CC-506]]。

Req 9：`pmctl_context_pack` 先前完全沒有 telemetry（跟 `query`／`reuse-scan`／
`prompt-scan` 不同，先前只有 pack 這一個消費端零遙測）。新增
`context.packed` 事件（`core/schema/event.schema.json` enum 補一項），
`_ctx_pack_finish` 是唯一出口點，三個既有 `return` 分支（no-index／no-sqlite／
已索引成功路徑）統一經過它，zero-hit 分支 freshness 標為 `unavailable`，成功
路徑依 `_ctx_ensure_fresh`／`_ctx_ensure_fresh_memory` 的既有回傳碼標
`fresh`／`stale`（先前這兩個呼叫都用 `|| true` 吞掉結果，現在拿來當
freshness 訊號）。事件 payload 含 `top_k_refs`（依 `ranking_score` 取前 10、
非全量，避免 event 過大）、`pack_bytes`、`full_file_baseline_bytes`（新增
`_ctx_full_file_baseline_bytes_for_paths` 共用 helper，批次一次
`stat -c '%s' ... +`，不逐檔 stat——沿用 CC-557/CC-560 的 per-item
subprocess 教訓）、`compression_ratio_vs_full_file_baseline`、`truncation`
（原樣帶出既有 truncation 物件）。

工作流覆蓋面查證後發現只有兩條真實路徑，不是三條：`gate-memory-context.sh`
直接呼叫 `pmctl_context_pack`（`pr-gate.sh` 已接線，ship 走 `/ship` 內部
gate 呼叫同一份程式碼，因此「ship」與「gate memory context」是同一個
call site，不是分開的兩個）；另一條是 dispatch auto-pack，它走
`pmctl_context_reuse_scan`（不是 `pmctl_context_pack`），先前只有
`context.auto_packed` 事件帶 `hits`／`pack`／`source_brief`。擴充該事件
payload 為同一組欄位（`freshness`／`top_k_refs`／`pack_bytes`／
`full_file_baseline_bytes`／`compression_ratio_vs_full_file_baseline`），
從已渲染的 `auto_context:` block 反推（`_ctx_full_file_baseline_bytes_for_paths`
重構為通用 array-based helper，供 pack event 與 dispatch auto-pack 共用，
不重寫 stat 批次邏輯）；既有 5 個零命中／失敗提前 return 呼叫點維持 5 參數
呼叫（enrichment 全部走預設值 `[]`／`0`／`unavailable`），不強迫每個失敗
分支都重新計算。

「Agent 後續實際 source-read bytes」與「最終修改／引用檔案是否在
top-K」**刻意未在本輪實作**：這條關聯跨 process／executor 邊界，各
adapter trace 格式不同，且票面本身把「累積 ≥20 真實任務證據」列為
[[CC-506]] 的工作，不是本票的儀器化範圍——本輪只確保原始欄位在 pack
時點被記下，供 [[CC-506]] 之後跨事件 join。

Req 10：`compression_ratio_vs_full_file_baseline` 已是兩個事件唯一使用的
命名（未曾在程式碼中出現過 `context_savings` 這個舊名，故無需 rename，
只需採用票面指定的新名）；`docs/context-retrieval.md` 新增「Shadow
telemetry」一節明文「這是純粹的 size ratio，不是實際節省宣稱」的誠實命名
邊界。

新增 4 案：`context.packed`（含 top_k_refs／pack_bytes／baseline／ratio／
freshness 斷言）、zero-hit pack 仍出事件且 freshness=unavailable、
dispatch auto-pack 的 `context.auto_packed` 事件攜帶同組 enrichment 欄位。
`tests/shell/test-pmctl-context.sh` 164 案全過（162+2），
`tests/shell/test-pmctl-dispatch.sh` 54 案全過（53+1）。

**Done-when**: Phase 1——檢索能命中段落深處內容；四個 consumer 對相同 query 使用相同 ranking order；hits 帶 rank／match_kind／bounded span／score components／freshness；fixture suite 證明 exact-symbol top-1、expected refs top-K、mtime-preserving edit freshness、budget truncation disclosure；整合測試證明 dispatch auto-pack 與 gate memory context 的注入內容出自同一 ranking path（對同一 query 與直接 `context query` 排序一致）。Phase 2——agent-facing 輸出攜帶 index-first/source-verified fallback 指令；shadow telemetry 欄位落地並開始蒐集。收緊 broad-Read 指引**不在本票**（→ [[CC-506]]）。

**Non-goals**: 不做 embeddings（[[CC-340]] 維持 deferred，resume 條件由 [[CC-506]] 評測後重評）；不做 edges／blast radius（[[CC-346]]／[[CC-347]] 的範圍）；不引入 tree-sitter/AST 或外部索引工具；不在本票收緊 broad-Read fallback 或宣告實際 token 節省（[[CC-506]]）；跨 host prompt 注入接線屬 [[CC-503]]，本票不因其未完成而阻塞。

**Dependencies**: 無硬前置；與 [[CC-465]]（CJK 斷詞）同屬檢索品質線可協調但不合票。排序：本票 Phase 1 完成即解鎖 [[CC-346]] Phase a + [[CC-347]] 垂直切片（不需等 [[CC-506]]）。**未排入 milestone**——v0.11.0 之後的 context-plane 版次候選。

**Source**: 2026-07-20 四方 multi-model synthesis（外部參照 tirth8205/code-review-graph 的可轉移性分析；四方一致：不裝外部工具、不建第二套系統，在既有 context.db 上補「檢索品質 → edges → change impact」三層）。2026-07-20 外部 review 補強：consumer ranking 統一、index-first/source-verified 契約、fixture corpus、shadow evidence 與誠實命名（ranking ≠ confidence；ratio ≠ 實際節省）；phase 拆分依 auto-pack 先例（機制+telemetry 先行、evidence 後收緊，見 CC-402 default flip 模式）。

**pr-gate 第一輪（full tier，sequential，5 reviewer）NO-GO（1 block，其餘 4 方
approve/pass）**：qa-tester 指出 `context.packed` 新增的 `freshness` 欄位缺一個
「refresh 失敗時回報 stale」的直接行為測試。查證時發現這條路徑當時**不可能
通過**：`_ctx_index_tree` 執行 sqlite3 batch 寫入的那一行從未檢查過 exit
code——函式自己的回傳碼只來自最後兩行必定成功的 `printf`，導致 sqlite3
寫入失敗（例如唯讀 DB）在每個呼叫端（包含 `_ctx_ensure_fresh`）都跟成功
無法區分。這不是本輪新引入的缺陷，是既有程式碼的既有缺口，只是本票新增
的 `freshness` 契約第一次讓它變得可觀察、也必須被觀察。

修正：`_ctx_index_tree` 的 sqlite3 batch 寫入改為顯式檢查 exit code，失敗
即印出 stderr 並 `return 1`；`_ctx_ensure_fresh`／`_ctx_ensure_fresh_memory`
因此第一次能真正偵測到 refresh 失敗。新增一案：以 `chmod 555` 讓既存索引
目錄唯讀（模擬 refresh 寫入失敗），斷言 `context.packed` 事件的
`freshness` 確實回報 `stale` 且指令本身仍 exit 0（refresh 失敗只降級
freshness 訊號，不使 pack 本身失敗）。`tests/shell/test-pmctl-context.sh`
164 案全過（163+1）。

**pr-gate 第二輪起**：第一次以 `--pass targeted --reviewers qa-tester` 重派被
policy floor 拒絕（此 scope 的必要 reviewer 覆蓋是全體 5 名，targeted 單一
reviewer 不能繞過）——這是 policy 拒絕不是 verdict，改回全量重派。全量重派
後 qa-tester 又指出既有 `run-tests.sh --base main` 全套（供 QA supplemental
執行）在 gate 提供的 120 秒 helper 預算內逾時——查證後這是既有結構性限制
（`test-pmctl-context.sh`／`test-pmctl-dispatch.sh` 本身已各自跑到 200+ 秒，
早於本票就已如此，非本票新增的量體造成），非本票新增測試造成的迴歸。改用
`--test-cmd` 指向只涵蓋本票新增行為的 scoped 指令（3 個新案，約 8 秒），
讓 5 位 reviewer 都拿到完整、不逾時的證據，而非依賴 gate 內建的全量 QA
timeout 假設。

該輪 gate 又意外撞見一個 `case_execute_tail_direct_lifecycle_identity`
單次失敗（qa-tester 執行「supplemental」全套時觸發，與本票行為無關的既有
案例）——本機連跑 3 次與整份 `test-pmctl-dispatch.sh` 全套皆綠，判定為
gate 執行環境下的機率性 flake，重派後未再出現。

真正需要修的是第三輪 qa-tester-F001：dispatch auto-pack 的
`context.auto_packed` 事件成功路徑把 `freshness` **寫死成 `"fresh"`**——
`pmctl_context_reuse_scan` 內部同樣呼叫 `_ctx_ensure_fresh` 卻用 `|| true`
吞掉結果，導致 reuse-scan 命中一個「refresh 失敗、仍讀到舊資料」的 stale
索引時，也會被回報成 fresh。修正：在呼叫 `pmctl_context_reuse_scan` 前，
`pmctl_dispatch_auto_pack` 自行先呼叫一次 `_ctx_ensure_fresh`（與
reuse-scan 內部呼叫冪等，第二次是基於 mtime 的 no-op refresh），取其真實
回傳碼作為這次事件要回報的 `freshness`，取代寫死的字面值。

新增迴歸測試時發現原本兩個 stale fixture（`chmod 555` 整個 ctx 目錄）的
副作用比預期更大：sqlite3 的 FTS5 temp-store scratch file 需要目錄本身
可寫，連純讀查詢都會失敗，讓 pack／reuse-scan 一起退化成 zero-hit——那其實
是另一條已覆蓋的分支（no-index/查詢失敗），不是「refresh 失敗、舊資料仍可
讀」這個本票要驗的路徑。兩個既有 stale 案（`pmctl-context.sh` 與新增的
`pmctl-dispatch.sh` 案）都改為只 `chmod 444` DB **檔案本身**（目錄維持
可寫）——寫入交易失敗，讀取仍成功；並補強斷言：两案都要求 `top_k_refs`／
`hits` 非零，證明真的走了「有命中」的成功路徑，而非誤判一個空 pack 也算
「stale」。`tests/shell/test-pmctl-context.sh` 保持 164 案全過，
`tests/shell/test-pmctl-dispatch.sh` 55 案全過（54+1）。

**pr-gate 第五輪（full tier，sequential，5 reviewer）GO**：全數 approve/pass，
無新 finding。全套 `run-tests.sh --all` 100 passed, 0 failed；
`gate verify --consumer embedded` 三軸全過。

**See**: pr:#516

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

## CC-566 — `guard-inject-memory.sh` 依 host 給獨立注入預算，消除 Claude 端全量重複注入的浪費 ✅ 2026-08-23

**Problem**: 2026-08-23 直接比對一次真實 Claude Code session 的注入內容與本 repo 的
`MEMORY.md`（`wc -c` = 14,055 bytes，與 session 開場那個 `claudeMd`-labeled context
block 大小吻合）已實測確認：Claude Code 自身的原生 project-memory 功能會在
session 開場把整份 `MEMORY.md`（86 筆、完全不受 `MEMORY_MAX_INJECT_BYTES` 節制）
當作 context 完整載入一次（≈5,500–6,500 tokens），與 `guard-inject-memory.sh`
每輪重排、每輪重新注入的裁切版（600–1,300 tokens/輪，budget 3000
bytes/20 筆）完全獨立、互不知情。`lib/memory.sh` 裡這兩個常數，是在假設
hook 是使用者唯一記憶管道的前提下訂的，並未把 Claude 端已有一份無上限全量
副本墊底這件事算進去。但同一組常數同時被 Codex 使用，而 Codex **沒有**
對應的原生全量安全網——已用程式碼確認：`hosts/codex/lib/memory-contract.sh`
的 `codex_memory_contract_append` 寫進 `AGENTS.md` 的 marker 區塊只是約
20 行固定操作指令，不含 `MEMORY.md` 的實際內容——所以不能單純調降全域常數，
那會犧牲 Codex 的召回完整度去換 Claude 的省錢。詳細分析與量測方法見
[docs/memory-system.md](docs/memory-system.md) 的 “Per-prompt token cost” 與 “Double-injection on
Claude” 兩節。

**Requirement**:
1. 給 `guard-inject-memory.sh` 一個顯式、非環境變數的 per-host 預算入口——例如
   由各 host 的 install-guards 腳本在 wiring 時，以 CLI 參數（而非 ambient env
   var）傳入。`lib/memory.sh` 現有註解已明確排除 env override，理由是避免
   `env-var-ambient-leak-into-fixtures` 那類問題重演，本票必須沿用同一原則。
2. `hosts/claude/bin/install-guards.sh` 寫入的 hook command 帶一個較低的
   Claude 專屬預算（初始提案：1500 bytes / 10 筆，實際數字待 Requirement 3
   的量測結果決定，不預先鎖死）；`hosts/codex/bin/install.sh` 維持現行
   3000 bytes / 20 筆，不變。
3. 動手改動前先量測：用 `pmctl memory stats` 對照「原生全量清單」與「hook
   命中清單」的重疊率，確認調降 Claude 預算後被裁掉的卡片，是否本來就已經被
   原生全量涵蓋過——避免「兩邊剛好都裁到同一批冷門卡、實際上仍然漏掉某類
   卡片」的誤判。
4. `hosts/claude/lib/doctor.sh`、`hosts/codex/lib/doctor.sh` 與兩邊的
   `uninstall.sh` 既有的 command-string 精確比對邏輯，要同步更新成能辨識帶
   host 參數的 command——不能因為 command 多了參數就誤判成「未受管理的第三方
   hook」而重複寫入、或誤判成「找不到已裝 hook」而無法解除安裝。
5. regression fixtures 覆蓋：全新安裝取得 host 專屬預算、既有安裝升級後舊
   command 被正確替換、doctor 在兩個 host 上都回報一致的 `memory-injection:
   ok`、以及 Codex 預算與行為不受影響的對照組。

**Done-when**: Claude 端每輪 hook 注入 tokens 可觀察地下降，同時 `pmctl memory
stats` 回報的 Codex 端 `hit_coverage_pct`／`top5_share_pct` 不劣化；兩個 host 的
`doctor.sh` 都回報 `memory-injection: ok`；`tests/shell/test-guards.sh` 與兩個
host 各自的 install/uninstall 測試全過。

**Non-goals**: 不嘗試偵測、關閉、或以任何方式介入 Claude Code 自己的原生
`claudeMd` 全量載入——那是黑盒產品行為，不在本 repo 控制範圍內；不改變
「canonical memory 是唯一可信來源、host 原生記憶永遠是 auxiliary」這條既有
設計原則；不處理 Grok／OpenCode——兩者目前連 `UserPromptSubmit` hook 都未掛
（`host.yaml` 宣告 `hook_surface: {}`），不受本票描述的雙重注入問題影響。

**Dependencies**: 沿用 [docs/memory-system.md](docs/memory-system.md) Per-prompt token cost 與 Native
memory 表格的實測數據；避開 `env-var-ambient-leak-into-fixtures` 的教訓；
與 [[CC-467]]（injection ranking 鑑別力）正交，不重疊。P2。

**Shipped**：`guard-inject-memory.sh` 新增 `--host <name>`（以既有
`pmctl_host_is_valid` 驗證、無效值 fail-open 退回共用預算，不擋 prompt）；
`hosts/claude/bin/install-guards.sh` 把 Claude 的 wired command 改成帶
`--host claude`，選用 `MEMORY_CLAUDE_MAX_INJECT_ENTRIES=10` /
`MEMORY_CLAUDE_MAX_INJECT_BYTES=1500`；Codex wiring 完全不動。pr-gate（sequential,
codex executor）第一輪 NO-GO（qa-tester：既有升級路徑回歸測試不夠精確），修正
並以「先讓測試失敗、再讓它通過」驗證鑑別力後，targeted re-gate（qa-tester +
escalation 要求的 architecture-reviewer + security-reviewer）GO。單次
reuse/simplify 確認額外補上 `hosts/claude/lib/doctor.sh` 一個真缺口（過期 hook
偵測沒同步處理新的 `--host` 尾巴）。全套 `run-tests.sh --all` 100 passed, 0
failed。已 merge 並在本機重跑 `install.sh` 生效（`~/.claude/settings.json`
UserPromptSubmit 已帶 `--host claude`，`doctor.sh --profile full` 回報
`5 hooks present`）。

**See**: pr:#519

---
## CC-567 — memory `selected`→`applied`→`outcome` 追蹤：擴充既有 matched/injected 遙測

**Problem**: `pmctl memory stats`（見 `docs/memory-system.md` §Injection benefit）已經追蹤
`matched`（MEMORY.md 索引命中）與 `injected`（`guard-inject-memory.sh` usage sidecar 記錄的
實際注入次數），並用 `concentration` 區塊（`hit_coverage_pct`／`top5_share_pct`）專門偵測
「每張卡都被注入、排序失去鑑別力」這種退化。但整條鏈路在「注入」這一步就停了——沒有任何
地方記錄 PM 是否真的判斷這張卡與當前任務相關（`selected`）、萃取結果是否真的改變了 brief
或執行計畫（`applied`）、以及套用後是否真的有幫助（`outcome`）。目前的信號只能回答
「卡片有沒有被排進去」，回答不了「排進去之後有沒有用」，這是一個確認存在的真缺口。

**Why this first（優先序理由）**: 這是四張票裡故意排第一順位、且與外部文章建議順序相反的
一張。原因：(a) 成本低——`pmctl memory stats` 已經算出 matched/injected 的底層數字，本票只是
在既有管線上加一行 selected/applied/outcome 的紀錄與彙總，不是新建系統；(b) 它是後面所有票
（CC-568 Case→Strategy 提升、CC-569 working-memory schema 欄位、CC-570 分類法 metadata）
是否值得動手的證據來源。沒有 applied/outcome 資料，CC-568/569/570 的優先序判斷只能憑直覺，
而本 repo 過去已多次因為「憑感覺建機制」而蓋出沒人用的東西（見 `docs/memory-system.md`
`episode_fill_rate_pct` 一段：先前的空骨架欄位兩個月填充率只有 8-12%）。先蒐一週的
applied/outcome 資料，再決定 CC-568/569/570 裡哪些真值得做。

**Requirement**:
1. 在 PM 判斷一張候選卡片與當前任務相關並決定引用（`selected`）、以及該卡片內容真的
   進入 brief 的 `constraints:`／`context:` 或改變了執行決策（`applied`）的時間點，各記一筆
   可歸因到卡片路徑與任務／run 識別碼的事件——沿用既有 trace event 慣例
   （`context.packed`／`context.auto_packed` 的 shape 可作參考起點，不代表必須共用同一
   event kind）。
2. `outcome` 訊號至少涵蓋一個廉價、可自動判定的代理指標（例如：套用該卡片約束的 dispatch
   run 最終 gate 是否 GO、是否需要額外 fix round）；不要求人工標註每筆 outcome，人工標註
   可作為選用補充但不能是唯一路徑。
3. `pmctl memory stats` 新增彙總欄位呈現 selected/applied/outcome 三段的漏斗（例如
   selected→applied 轉換率、applied→outcome 為正的比例），沿用既有欄位的 read-only、
   零寫入 surface 慣例；`concentration` 既有邏輯不變、不重算。
4. 零信號時不得偽造成功；沿用現有 `usage_store: error` / `episodes_status: error` 的
   誠實回報慣例——量不到就回報「量不到」，不要塞入預設值稀釋統計。

**Non-goals**: 不在本票內建立 Case→Strategy 提升機制（[[CC-568]]）；不新建
working-memory schema 欄位（[[CC-569]]）；不建立 Fact/Case/Strategy 分類法
metadata（[[CC-570]]）。

**Dependencies**: 前置 = 無（在既有 `pmctl memory stats`／usage sidecar／trace event
基礎上擴充）。本票是 [[CC-568]]／[[CC-569]]／[[CC-570]] 的證據前置依賴。

**Update 2026-08-25（done）**: PR #532 合併（squash → main `b4027b9`）。三項 Requirement
全數達成：`selected` 沿用既有 usage sidecar `access_count > 0`，無新埋點；`applied`
為 dispatch 時自動掃描 brief 內容比對已選中卡片，掛在 `pmctl_dispatch_run` 的
brief-validate 之後，刻意不做主動呼叫式記錄（見 Why this first 一段的
`episode_fill_rate_pct` 前車之鑑）；`outcome` 為唯讀 join 既有 terminal-state
reader。新檔 `runtime/lib/memory-applied.sh`。經 7 輪 pr-gate 收斂：round 4 抓到
IFS tab-collapse 真資料損壞 bug，round 5-6 抓到 symlink race TOCTOU 與 hard-link
swap 兩個真資安漏洞，皆已補迴歸測試修復。5 位 reviewer（critic/qa-tester/
architecture-reviewer/security-reviewer/risk-reviewer）全數 approve，
`tests/bin/run-all-tests.sh` 104 passed 0 failed。CC-568/569/570 現在可以用本票
產出的真實 selected/applied/outcome 數字決定優先序，而非憑直覺。

---

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

## CC-571 — sqlite atomic-script 缺口：`_ctx_fts_rebuild`／`_ctx_index_file`

**Problem**: `runtime/lib/pmctl-context.sh` 的 `_ctx_fts_rebuild()` 對
`content_fts` 做 `DROP TABLE` → `CREATE VIRTUAL TABLE` → 兩個 `INSERT ... SELECT`，
整段用 heredoc 餵給 `sqlite3 "$db" >/dev/null`，沒有 `BEGIN`/`COMMIT`。兩個呼叫端
（`pmctl_context_index` 約 line 795、`pmctl_context_update` 約 line 1126）都是裸呼叫
`_ctx_fts_rebuild "$db"`，不檢查回傳值，之後照樣印「context index/update」成功訊息。

**Why**: 直接實測證實這不是理論風險。用一個蓄意中途出錯的重建腳本測試：
1. 不加 `-bail`：sqlite3 CLI 預設遇到錯誤只印訊息、**不中止**，照樣跑到 `COMMIT`
   （若有包 transaction 也一樣會提交半成功的內容）；exit code 雖然是 1，但呼叫端
   從不檢查。
2. 加 `-bail` 後才會在第一個錯誤處真正中止，交易維持未提交，行程結束時連線關閉
   觸發自動 rollback，舊的 `content_fts` 完整保留（已用最小 repro 驗證）。

三個問題疊在一起：(a) 沒有 atomicity——失敗可能留下半建或整個消失的表；(b) 沒有
`-bail`，單靠 `BEGIN`/`COMMIT` 不足以達成 (a) 的保護；(c) 呼叫端不檢查回傳值，
即使 (a)(b) 都修好，使用者也不會知道索引其實是舊的（rollback 後）卻顯示重建成功。
本票是 [[CC-548]] spike 過程中在 Open risks 側面發現的既有缺口，與該票的 tokenizer
判斷（AMBER，暫緩）完全無關；使用者已明確要求只處理這個 bug，不連動 trigram 切換。

**Requirement**:
1. `_ctx_fts_rebuild` 的 DROP/CREATE/INSERT 序列包進單一交易（`BEGIN
   IMMEDIATE`…`COMMIT`），並對 `sqlite3` 呼叫加 `-bail`（或等效機制），確保任何一步
   出錯都會在該步中止、交易不提交，使既有 `content_fts` 保持完整可查詢，而不是
   半建或消失。
2. `_ctx_fts_rebuild` 的失敗必須讓呼叫端可辨——回傳非零，且兩個呼叫端
   （`pmctl_context_index`／`pmctl_context_update`）改為檢查其回傳值：失敗時不得
   印「成功」字樣的訊息，改為誠實回報「FTS 索引重建失敗，仍使用既有索引」一類的
   降級狀態（比照本 repo既有 `usage_store: error`／`resolution_issues` 誠實回報慣例，
   不阻斷整體 index/update 流程——FTS 只是加速層，非唯一查詢路徑，LIKE fallback
   仍可用）。
3. Regression fixtures：模擬重建腳本中途失敗（例如注入一個會觸發 SQL 錯誤的條件），
   斷言 (a) 舊 `content_fts` 內容不變、(b) `_ctx_fts_rebuild` 回傳非零、(c) 呼叫端
   印出的訊息誠實反映失敗、不宣稱成功。

**Non-goals**: 不改 FTS5 tokenizer（unicode61 維持不變，[[CC-548]] 已判 AMBER 暫緩）；
不新增 schema 欄位或 `index_meta` 版本追蹤；不處理 query-during-rebuild 的
讀者可見性問題本身（rollback 後舊表持續可查詢，交易保護已隱含解決多數場景）。

**Update 2026-08-26（範圍擴大，實作中）**：`/simplify` 的 altitude review 在同一輪
reuse/簡化確認裡抓到手足函式同缺陷——`_ctx_index_file()`（`pmctl_context_update`
另一個呼叫路徑，寫的是 files／symbols／file_chunks 主索引資料，非 FTS 加速層）用
`BEGIN;`…`COMMIT;` 但同樣沒加 `-bail`；直接測試還額外找到第三個獨立 bug：其函式
本體最後一行是 `sqlite3 ...; rm -f "$tmpf"`，函式回傳值變成 `rm` 的 exit code（幾乎
恆為 0），完全蓋掉 sqlite3 真正的失敗狀態，即使先前已加 `-bail` 也測不出來。範圍
擴大為：兩個函式共用同一個新抽出的 `_ctx_sqlite_exec_atomic` helper（單一
`-bail` 呼叫來源，同時解決 reuse review 指出的「兩處各自重新推導同一手法」）；
`_ctx_index_file` 明確 `return "$rc"`（在 `rm` 之前先擷取），且其唯一呼叫端
（`pmctl_context_update`）失敗時視為**致命**（不同於 FTS——這是主索引資料而非
best-effort 加速層，宣稱「re-indexed」等於說謊）。新增對應 regression fixtures
（`_ctx_index_file` 回傳碼、`pmctl_context_update` 失敗時不宣稱成功）。使用者已
確認此擴大屬於「同一個 bug」範圍內的自然延伸，非另開新工。

**Cross-link**: [[CC-548]]（spike 中發現本缺口，Open risks 段落）。也可見
`runtime/lib/memory.sh` 的 `memory_usage_commit`（既有的 `-bail` atomic-script
先例，本票的 helper 命名與理由都直接引用它，而非各自重新推導）。

**Update 2026-08-26（done，pr:#539）**：pr-gate 5 輪後 GO（critic／qa-tester／
architecture-reviewer／security-reviewer 全數 approve）。前兩輪是真實發現並已修正：
round 1 critic-F001——stderr 有印降級訊息，但 stdout 的成功摘要行本身仍是無條件
「N indexed, M skipped」，對只看 stdout／exit code 的呼叫端是矛盾摘要，改成把降級
狀態直接併入 stdout 摘要行本身；round 2 critic-F001——首次建置索引失敗時（rebuild
前 `content_fts` 根本不存在），訊息卻說「現有索引維持」，改為依 rebuild 前是否已有
`content_fts` 分支措辭。中間另有 3 輪是 gate 執行環境本身的 synthesis 協定不穩定
（`apply_patch` 在同一份 result 檔案上多次操作互相衝突、`findings_union`/
`disagreement` 結構不一致），與程式碼無關，重跑收斂。`tests/bin/run-all-tests.sh`
104 passed 0 failed。狀態旗標本次於 main 更新後立即補記——同一 session 已因此類
漏更新撞過三次（CC-567／CC-533／CC-015），這次差點又漏，補上教訓：**合併前**就該
在 PR 裡帶上狀態翻轉，合併後才想起來永遠比合併前想起來更容易忘記。

---

## CC-572 — pr-gate synthesis 重試留下空但存在的 result 檔案，patch 工具語意混淆

**Problem**: CC-571 的 pr-gate saga 連續遇到 4 輪協定失敗，其中兩類錯誤反覆出現：
`apply_patch verification failed: invalid patch: multiple operations target <file>`
與 `Failed to find expected lines in <file>: ...`。追查後發現：sequential 模式的
synthesis 重試（`runtime/bin/pr-gate.sh` 約 line 2748）在重試前用 `: > "$OUTPUT_FILE"`
把結果檔案**清空但保留路徑存在**；parallel 模式的 synthesis 重試（約 line 3600 附近的
迴圈）則完全沒有清空或移除，重試時 `$OUTPUT_FILE` 仍是第一次嘗試的完整內容。兩者都
讓 executor 的 patch 工具面對一個「路徑存在」的檔案，可能因此選擇 `Update File`
（需要定位既有內容做編輯）而非 `Add File`（單純新建）語意——對 0 bytes 或即將整份
重寫的檔案，`Update File` 語意本質上找不到可定位的 context line，因而崩潰。

**Why**: reviewer-protocol 的重試路徑（同檔案內，寫到全新的
`reviewer-<name>-<ts>-retry1.md` 路徑）從未出現過這個問題——因為那個路徑保證是全新
的，patch 工具沒有選錯語意的空間。Synthesis 的兩條重試路徑都固定用同一個
`$OUTPUT_FILE`（這個路徑本身是使用者看得到的 canonical gate 結果路徑，不能像
reviewer 重試一樣改路徑），只能改成每次重試前把該路徑**整個移除**（而非清空），
逼 patch 工具只能選擇 `Add File`。

**Requirement**:
1. 兩條 synthesis 重試路徑（sequential／parallel）在重新 dispatch 前，都必須讓
   `$OUTPUT_FILE` 這個路徑真正不存在（而非僅清空內容），逼 patch 工具走
   `Add File` 而非 `Update File`。
2. Regression fixtures 驗證重試發生時 `$OUTPUT_FILE` 在第二次 dispatch **開始前**
   確實不存在，且既有 synthesis-protocol 測試全數維持綠燈。

**Non-goals**: 不改變 synthesis 重試次數（維持 1 次，不重新開放 CC-544 已被否決的
「重試把失敗變成通過」爭議——本票的重試機制本來就誠實回報協定失敗，不受影響）；
不修改 reviewer-protocol 既有的重試機制（已經是正確模式，不需要改）；不嘗試修正
codex 自己的 apply_patch 工具實作（不在本 repo 控制範圍）。

**Cross-link**: [[CC-571]]（gate saga 實測發現本問題的來源）。

**Update 2026-08-26（done，pr:#541）**：兩條路徑都已修好，新增迴歸測試直接斷言
重試發生時該路徑真的不存在（而非僅清空）。pr-gate 首輪 GO（未在該次 gate run
自身觸發 synthesis retry，修復是靠直接比對過往失敗 log 的根因＋白箱迴歸測試
驗證，非現場實戰）。`tests/bin/run-all-tests.sh` 104 passed 0 failed。

---

## CC-573 — `pmctl run-stats` 每事件行 fork 一個 jq ✅ 2026-08-27

**See**: pr:#547

**Problem**: `pmctl_run_stats_extract_line`（`runtime/lib/pmctl-run-stats.sh`）對
`events.jsonl` 的**每一行**執行一次 `jq -r`（過濾 `kind` 是否 `^run\.`、抽出 7 個
TSV 欄位）。掃描迴圈本身是純 bash（`mapfile -d $'\t'` + assoc array），沒有額外
fork，但 jq 是逐行 spawn。與 [[CC-364]] 修掉前的 `pmctl trace tail` 是**同一個
per-item subprocess 形狀**（見 `per-item-subprocess-class`）。

**Profile（2026-08-27，PATH jq wrapper 計數 + 牆鐘）**:

| N events | jq 呼叫數 | 牆鐘 |
|---:|---:|---:|
| 100 | 102 | 3.0s |
| 300 | 302 | 8.8s |
| 900 | 902 | 30.2s |

jq 呼叫 = N + 2（每事件一個 + 固定 2 個 setup/teardown）；牆鐘線性、
斜率約 **34ms/event**（WSL2 上 jq fork 主導）。真實 state store 的
`events.jsonl` = 6642 行時，`pmctl run-stats --json` 前景執行 **2 分鐘 timeout
（SIGTERM）**，外推約 225s。run-stats 是 v1.0 readiness 證據工具
（[[CC-358]] DoD），現在在真實資料上跑不完。

**Why now**: [[CC-364]] 剛把 `trace tail` 的同款問題修好，pattern 新鮮；
`events.jsonl` 的 archive+active 串接掃描現在有第二個 consumer。

**Requirement**:
1. 掃描階段改為**單次 `jq -R` 串流** over 串接的 archive+active 事件流：
   逐行 `try fromjson catch null`，非物件或非 `run.*` 者輸出 skip 標記，
   `run.*` 者輸出分隔欄位（沿用既有 7 欄：ts/kind/run_id/adapter/note/
   exit_code/fallback_used），迴圈結束後**一次** decode 進 assoc array。
   分隔符用 NUL 或 tab，比照 [[CC-364]] / CC-557 / CC-560 已驗證做法。
2. `--since` 過濾維持字典序 ISO-8601 比對語意；malformed row 容忍與
   `episodes_malformed` 式的計數維持既有誠實回報慣例。
3. Archive-inclusive 掃描（`read_archives`）、gzip 不可用時的 active-only
   fallback、`_meta` 回報，全部維持。
4. 新增 fault-sensitive perf 迴歸：PATH jq shim 計數，斷言小分區與大分區
   的 jq 呼叫數相等（O(1) in event count），比照 [[CC-364]] 的
   `case_trace_tail_single_jq_pass`。
5. 修正前後輸出以 `jq -S` 正規化後逐位元組比對，確認純效能修正、無行為變更。
6. 評估 `trace tail` 與 `run-stats` 的「archive 檔案發現 + 串接 + gzip fallback」
   是否值得抽成共用 primitive（兩者 jq 程式不同，只有串流串接那段可共用）；
   若第二個 consumer 不足以支撐抽象就記錄理由、不強抽。

**Non-goals**: 不改 run-stats 的輸出 schema 或 CLI 介面；不改 `--since` 驗證；
不動 [[CC-358]] 的 `fallback_used` event 訊號本身。

**Cross-link**: [[CC-364]]（同形狀的第一次修正，含 profiling 方法與 oracle 測試
技巧）、`per-item-subprocess-class`。

**Closure 2026-08-27 (pr:#547)**: 掃描階段改為單次 `jq -R` 串流 over 串接的
archive+active 事件流。新 helper `pmctl_run_stats_filter_program`（heredoc jq
程式，逐行 `try fromjson catch null`、非物件／非 `run.*`／被 `--since` 濾掉者輸出
`empty`、其餘輸出 7 欄 `@tsv`）＋ `pmctl_run_stats_scan_stream`（stdin 讀 TSV、
`mapfile -d $'\t'` 折進 `_rs_*`），取代 `extract_line`／`process_line`／
`scan_path`／`scan_gzip_path`。`--since` 謂詞下推進 jq，語意與原 shell 檢查完全
相同（僅在有界且 ts 非空且 ts < 界時丟棄）。

**Perf 佐證**：合成資料 jq 呼叫 102/302/902 → **2/2/2**，牆鐘 3.0–30.2s →
**0.19s 打平**。異質 fixture（正常 terminal／partial／nonzero exit／cancelled／
missing-terminal／fallback／pre-`--since`／2 個 malformed 行／非 run 事件／
archive-only run；3 adapter）輸出對 `origin/main` 逐位元組相同（`jq -S` 正規化，
JSON 與 human 皆是）。新增 `case_run_stats_single_jq_pass`（jq shim 計數 20 vs
200 run 相等）與 `case_run_stats_streaming_matches_reference`（golden 比對）。
`test-pmctl-run-stats.sh` 17 passed，全套 105 passed 0 failed 0 skipped。

**Req 6（共用 primitive）**：archive-glob + gzip-check + concat-then-one-jq-pass
的 ~12 行 idiom 現與 `pmctl-trace.sh` 重複。評估後**不抽**：兩者 jq 程式與輸出
consumer 不同，gzip 不可用的訊號也分歧（trace tail `read_archives=0`；run-stats
`archive_scanned=false` + `_meta`）；兩 consumer 下 callback 間接層不划算。理由寫進
`pmctl-run-stats.sh` file header，待第三個 consumer 出現再議。未立 follow-up 票。

---

## CC-574 — test-run-all-tests.sh 的 suite registry 鏡像去重 ✅ 2026-08-28

**See**: pr:#550

**Closure (2026-08-28)**: `test-run-all-tests.sh` 開場 `_load_suite_registry()`
awk-parse `test-suite-runner.sh` 的 `SUITE_NAMES` + `declare -A SUITE_PATHS`
兩個 block，填 `SUITE_NAMES` 陣列 + `SUITE_PATH_MAP`；`suite_path()` 變 map
lookup；parse 空 → 硬失敗指名格式變更。手抄的 ~106 筆字面 + ~106 分支 case
移除，淨 −28 行。因為 parsed path 會被接到 fixture repo root 再寫入，
`_suite_path_is_safe()` 對絕對／`..`／非白名單 root（`tests/`｜`tools/`｜
`pm/scripts/`）值 fail-closed 不寫檔，`write_suite_stub` 再驗 canonical
containment。3 條迴歸：`registry-derived-from-runner`（derive 逐行等於
`test-suite-runner.sh --list` + 每個 map value 安全且存在）、
`registry-derived-rejects-extra-nonexistent-mapping`、
`registry-parse-rejects-unsafe-paths`（traversal／絕對／錯 root 各一個
mutation-sensitive）。Gate：standard-tier GO round 3（round 1 parser
path-injection 面、round 2 每 rejection 類要獨立 mutation-sensitive case +
迭代 map 而非只有 names）。`lint-test-suite-registry.sh` 與 `lint.yml`
未動（Non-goals）。

**Problem**: 加一個測試套件要動三處：`tests/lib/test-suite-runner.sh` 的
`SUITE_NAMES` + `declare -A SUITE_PATHS`（權威），`tests/shell/test-run-all-tests.sh`
自己抄的 `SUITE_NAMES=(...)`（~106 筆字面）+ `suite_path()` case（~106 個 `printf`
分支），以及 `.github/workflows/lint.yml` 的 per-suite job。前兩者是**靜默漂移鏡像**
——漏改 `test-run-all-tests.sh` 那份，`known-suite-count` 這個 meta-test 才會紅，
訊息指向 count 不對而非「你少改一處」。本 session CC-538 與 CC-536 新增套件時各踩
一次（見 `suite-registry-mirror`）。`tools/lint/lint-test-suite-registry.sh` 已用
awk parse `test-suite-runner.sh` 的兩個 block 做交叉驗證，證明該格式可穩定解析。

**Why now**: 同一個坑一個 session 內踩兩次。成比例的修法是**移除鏡像**（讓
`test-suite-runner.sh` 成為 meta-test 的唯一 authoring source），不是 [[CC-537]]
的資料化 suite manifest——那是加第二層治理、被 PM 明確 park。

**Requirement**:
1. `test-run-all-tests.sh` 開場 awk-parse `$REPO_ROOT/tests/lib/test-suite-runner.sh`
   的 `SUITE_NAMES=(...)` 與 `declare -A SUITE_PATHS=(...)` 兩個 block，填出自己的
   `SUITE_NAMES` 陣列（保序）與一個 name→path 查表；`suite_path()` 變成查表 lookup
   （查無回傳 1，維持既有語意）。`SUITE_TOTAL` / `SUITE_MINUS_ONE` 從推導結果算。
2. Parse 產出 0 筆時**硬失敗**並指名 `test-suite-runner.sh` 格式變更，讓解析斷裂
   大聲而非靜默退化成空清單。
3. 新增迴歸：斷言推導出的 `SUITE_NAMES` 與 `test-suite-runner.sh --list` 輸出逐行
   相等（證明 derive == authority）；斷言每個 parsed path 都是 traversal-free、
   非絕對、且落在 registry 既有的三個 root（`tests/`、`tools/`、`pm/scripts/`）
   之一並存在。此外因為 parsed path 會被接到 fixture repo root 再寫入
   （mkdir／redirect／chmod），parse 期對不安全路徑（`..`／絕對／其他 root）
   **硬失敗不寫檔**，並另加一條迴歸：餵一個含 traversal `SUITE_PATHS` 值的假
   `test-suite-runner.sh`，斷言 `_load_suite_registry` 非零退出且未在 fixture
   之外建立任何檔案（gate security-reviewer-F001）。
4. `test-run-all-tests.sh` 的既有 case 全綠（fixture repo 寫 stub 仍用 `suite_path`；
   `known-suite-count` 現在恆等式成立）。

**Non-goals**: 不動 `test-suite-runner.sh` 的 registry 格式；不碰
`lint-test-suite-registry.sh`（它的 parse 服務不同目的——SUITE_NAMES↔SUITE_PATHS
的內部交叉驗證，合併會遮蔽 name-without-path）；不碰 `.github/workflows/lint.yml`
（per-suite job 由 `lint-test-suite-registry.sh` 交叉檢查，不是靜默漂移鏡像）；
不做 [[CC-537]] 的資料化 suite manifest。

**Cross-link**: `suite-registry-mirror`、[[CC-537]]（更大的資料化提案，park）。

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

## CC-576 — 測試成本重新規劃：實測基線、判準與順序 ✅ 2026-08-29

**Problem**: 維護者每次收工都跑 `tests/bin/run-tests.sh --all`（這是刻意的紅線：
受影響測試已由 pr-gate 跑過，全套的作用是「確保整體沒問題」，不接受改用
targeted 取代）。全套牆鐘約 30 分（機器有負載時實測 47 分），而測試量只增不減。
先前三次討論（`test-suite-duration-ceiling` 唯讀分析、`test-governance-batches-plan`
的 Batch 2/3/4、以及本次的「機械優化 vs 重新規劃」）都沒有拿實測數字回答
「這 30 分鐘到底是什麼、哪一塊可壓、哪一塊是不可壓的驗證工作」。

**Why**: 沒有基線就無法判斷任何測試治理提案的投報比，也無法分辨「測試太多」與
「單位測試太貴」。本票先把基線量出來、把判準寫死，後續批次才有依據依序進行。

### 實測基線（2026-08-29，main `af540bb`，8 核、job cap 4）

**A. 全套成本分布**
- 全套 10,764 CPU-s（179.4 CPU-min）／110 個 suite；4-way 併發下牆鐘約 30–47 分。
- `test-pr-gate-shard-{1..4}`＝5,287 CPU-s＝**49.1%**；top-10 suite＝**72%**；
  其餘 **85 個 suite 合計只佔 6.1%**（653s）。
- 結論：削減「suite 數量」對牆鐘幾乎無效；成本集中在單一 suite。

**B. `test-pr-gate.sh` 內部（13,078 行、290 個 case）**
- 290 個 case 中 **243 個各自 spawn 一次真的 `runtime/bin/pr-gate.sh`**。
- 單次 gate 執行成本（shard-1 單獨跑、無競爭，n=70）：**mean 8.2s／p50 7s／
  p90 18s／max 21s**。shard-1 的 gate 執行時間合計 577s。
- fixture 建置（`create_runner` 複製 `pr-gate.sh` + `agents/` + 1.5MB `runtime/lib/`）
  實測 **~14ms／次**，258 次合計 3.6s → **不是瓶頸**，「共用 fixture」方向無效。
- 併發代價：shard-1 單獨 577s gate 時間 vs 全套中 1,202s ≈ **2×**。每個
  `--parallel` case 內部再 fan-out ~5 個 reviewer 子行程，4 shard × 5 ≈ 20 個
  行程對 8 核 → 過度訂閱。但序列化 4 個 shard（4×~640s）比併發（~1,384s）更慢，
  **現行排程已接近最佳，不是槓桿**。

**C. 斷言品質（推翻「刪爛測試」假設）**
- 290 個 case 中只有 **9 個**只斷言輸出文字；**274 個**檢查 exit code 與／或
  `jq` 結構化輸出。→ 沒有可觀的「鎖內部措辭的垃圾測試」存量可刪。
- 真實 gate 路徑**沒有**病態子行程迴圈（policy signal validator 實測每次 gate
  執行 5 次 `grep`，與 5 條 path-regex 一致，符合設計）。→ 沒有 CC-364／CC-573
  那種「單次 jq 化」的免費午餐。

**D. 唯一會複利的槓桿：integration → unit**
- `test-gate-protocol.sh`（source lib、直接呼叫函式）：17 case／2s＝**0.12s/case**。
- `test-pr-gate.sh`（spawn 整個 gate）：**8.2s/case**。
- 比值 **≈68×**。[[CC-553]]／slice 1、slice 2（pr:#553／pr:#557）已示範此路徑：
  抽出 lib 後，該行為的測試從 8.2s 降到 0.12s。
- 可搬 case 盤點（自動分類 + 抽樣核對）：
  | 類別 | 數量 | 說明 |
  |---|---|---|
  | A 不 spawn gate（已便宜） | 47 (16.2%) | 無須處理 |
  | B dispatch 前就被拒（純 policy／validation） | 29 (10.0%) | **可搬** |
  | C 只斷言組出來的 brief（輸入的純函式） | 28 (9.7%) | **可搬** |
  | D 需要完整 dispatch+verify pipeline | 186 (64.1%) | 不可搬，這是真正的端到端驗證 |
- B+C＝**57 個 case**。全搬＝省 ~460 CPU-s（全套的 ~4%）。單看不多，但這是唯一
  同時（a）改善結構、（b）隨後續拆分複利、（c）不減少覆蓋 的方向。

**E. 誠實的天花板**
D 類 186 個 case × 8.2s ≈ **25 CPU-min 是不可壓的**——那是真的端到端 gate 行為。
加上 `test-install`（812s）等長尾，**全套不會降到 20 分以下**。本票的目標因此
不是「把 30 分變 10 分」，而是「讓它成長得更慢、讓新增的驗證落在 0.12s 那一層
而不是 8.2s 那一層」。

**Requirement**:
1. 把上述基線寫進可重跑的形式：一個唯讀腳本／文件，從既有 `--all` 的
   `test-result.json` 與 `test-pr-gate.sh` 的 `END pr-gate ... duration=` 行
   產出 A/B/D 三組數字，讓下次可比較而非重新人工量測。
   **（2026-08-29 調整：降級成文件化程序，不寫成維護型腳本——見下方 Update。）**
2. 訂**新測試的層級判準**（寫進 `commands/ship.md` 或 QA 規則）：新增 pr-gate
   相關驗證時，先問「這個行為是否為某個 `gate-*` lib 的純函式？」——是則測在 lib
   層（unit），否則才允許 spawn 整個 gate。這條是「阻斷 8.2s 層繼續長大」，與
   [[CC-554]] 的准入門檻互補（那條管「該不該有這個測試」，這條管「該測在哪一層」）。
3. 定**續拆 `pr-gate.sh` 的順序**，以 B/C 兩類 case 的密度排序而非行數：
   優先抽出 pre-dispatch policy／validation（B，29 case）與 brief composition
   （C，28 case）所依賴的函式，並在同一個 PR 內把對應 case 從 `test-pr-gate.sh`
   搬到新 lib 的 unit suite——**抽 lib 而不搬測試等於沒拿到這個槓桿**。
4. 明確標記已被本基線推翻的舊假設，避免重複討論：
   - ❌「共用／快取 fixture」——實測 14ms，無效。
   - ❌「刪低價值測試」——只有 9/290 純文字斷言，無存量可刪。
   - ❌「單次 jq／子行程優化」——真實 gate 路徑無病態迴圈。
   - ❌「改排程／shard 併發度」——序列化更慢，現行已近最佳。
   - ❌「收工改跑 targeted」——維護者已明確拒絕（全套的作用就是整體保證）。

**Non-goals**:
- 不在本票做任何抽取或搬遷（本票只產出基線、判準、順序）。
- 不設全套時間上限或 KPI 式的「砍 N% 測試」（`test-governance-batches-plan`
  兩份外部分析與 PM 皆反對）。
- 不改 `--all` 為預設之外的東西；不動 authoritative 契約。
- 不重啟 [[CC-537]] suite manifest（維持 park）。

**驗收方式**: 基線腳本可重跑並產出與本票相同結構的數字；判準（Req 2）進入
ship.md／QA 規則且下一個 pr-gate 相關 PR 實際被它導引到 lib 層；Req 3 的順序表
存在且每一項標註其 B/C case 數。後續實作批次各自開票，引用本票的順序表。

**Update 2026-08-29（規劃調整＋Req 2/3/4 交付，pr:#560）**

規劃時查證出一個**改變前提的事實**：**16 個 `gate-*.sh` lib 早就抽好了**
（共 6,712 行），但**只有 2 個有 unit suite**（`gate-protocol`、
`gate-structural-verify`）。其餘 14 個——含 `gate-policy.sh`(818)、
`gate-scope.sh`(1020)、`gate-assurance.sh`(420)、`gate-options.sh`(243)——的
測試全部還留在 `test-pr-gate.sh`，每個 case spawn 一次整個 gate。實測
`gate-policy.sh` / `gate-options.sh` **可獨立 source**，`_gate_policy_resolve`
是 JSON 進 JSON 出的純函式。

因此 Req 3 原本的框架（「續拆 `pr-gate.sh` 時**同時**搬測試」）對 B 類是錯的：
**B 類不需要再抽任何東西**，lib 已就緒，缺的只是 unit suite。C 類才真的需要先
抽（brief 是 `pr-gate.sh` 裡的 heredoc，沒有函式可測）。

**Req 1 → 降級成文件化程序（不寫維護型腳本）**。理由：一個腳本＝新 tool ＋
meta-test ＋ CI job ＋ registry 條目 ＋ 永久維護，而這組數字幾個月才看一次、
只在測試結構大改時才有意義。「為了量測測試成本而蓋一套要維護的測試基建」正是
本線在治的病。重跑程序（在 repo 根目錄）：

```sh
# A. 每個 suite 的 CPU 秒數與佔比（需先跑過一次 --all --result-file <json>）
bash tests/bin/run-tests.sh --all --result-file /tmp/full.json   # ~30-45 分
python3 -c "import json;d=json.load(open('/tmp/full.json'));r=sorted(((s['duration_seconds'],s['name']) for s in d['suite_results']),reverse=True);t=sum(x[0] for x in r);print(f'total {t}s / {len(r)} suites');[print(f'{v:6}s {v*100/t:5.1f}%  {n}') for v,n in r[:12]]"

# B/D. test-pr-gate.sh 的每 case gate 執行成本（單獨跑一個 shard 避免競爭失真）
bash tests/shell/test-pr-gate-shard-1.sh > /tmp/shard1.log 2>&1
grep -oE 'duration=[0-9]+s' /tmp/shard1.log | tr -dc '0-9\n' | sort -n | \
  awk '{a[NR]=$1;s+=$1} END{printf "n=%d sum=%ds mean=%.1fs p50=%s p90=%s max=%s\n",\
       NR,s,s/NR,a[int(NR*.5)],a[int(NR*.9)],a[NR]}'

# C. 可搬 case 分類（B=dispatch 前被拒 / C=只斷言 brief / D=需完整 pipeline）
#    見本票「D. 唯一會複利的槓桿」表；分類規則＝case 內是否出現 run_gate、
#    是否只斷言 "$brief"、名稱或斷言是否含 fails_before_dispatch 類記號。
```

**Req 2 ✅ 已交付**：`commands/ship.md` Step 3 在准入條件之後新增「Once a case
is admitted, choose its layer before writing it」段落——lib 層 0.12s vs 端到端
8.2s（~68×）、端到端要在 PR 說明為何 lib 層觀察不到、結構規則歸
`test-layer-boundaries.sh`、「該是 lib 函式卻內聯在指令裡」是程式面 finding 而
非付 8.2s 的理由。Step 4 樣板的 admissions 欄位同步要求記錄所選層級。
示範案例：[[CC-577]]（pr:#559）。

**Req 3 ✅ 已交付——改寫為「測試遷移順序表」**（非「拆分順序表」）：

| # | 批次 | 目標 lib（現況） | case 數 | 需先抽取？ | 備註 |
|---|---|---|---|---|---|
| 1 | policy／validation 拒絕路徑 | `gate-policy.sh`(818)、`gate-options.sh`(243) — **已抽、可獨立 source** | **B 類 29** | ❌ 不需要 | `_gate_policy_resolve` 是 JSON→JSON 純函式；override/duplicate/dormant/invalid-consumer 等拒絕分支可直接 unit 測。**投報最高、風險最低，先做這批** |
| 2 | scope manifest／adjacent-test 判定 | `gate-scope.sh`(1020) — 已抽 | B/C 混合，約 8–10 | ❌ 不需要 | `adjacent_*`（C 類 7 個）判定是路徑集合的純函式 |
| 3 | brief composition | **無**——heredoc 內聯在 `pr-gate.sh` | **C 類 28** | ✅ 需要 | 要先抽出「組 brief 字串」的函式才有東西可 unit 測；抽取本身有風險，排在 1/2 之後 |
| — | 端到端保留 | — | **D 類 186** | — | 真的需要 dispatch+verify pipeline，不搬 |

每一批各自開票，**必須在同一個 PR 內把 case 從 `test-pr-gate.sh` 搬走**——只寫新
unit suite 而不刪舊 case 等於兩邊都付錢，沒拿到槓桿。

**Req 4 ✅ 已交付**（寫票時即完成，見上方 Requirement 4 的五條 ❌）。

**See**: pr:#560（`commands/ship.md` Step 3 層級判準 + Step 4 樣板欄位；本票 body 的
Req 1 文件化程序、Req 3 測試遷移順序表）、[[CC-577]] pr:#559（判準的示範案例）。

**Cross-link**: [[CC-554]]（准入門檻，已結案——管「該不該有」；本票管「該測在哪
一層」）、[[CC-537]]（suite manifest，維持 park）、[[CC-575]]（pass-as-skip 存量
遷移）、memory `test-governance-batches-plan`（Batch 2/3/4 的舊規劃——本票的實測
推翻了其中「先清 `test-pmctl-memory` 存量」對牆鐘有意義的預期：該 suite 只佔
0.8%）、memory `test-suite-duration-ceiling`（2026-08-20 的機械優化上限結論，本票
以實測確認仍然成立）、`gate-protocol-lib-slice1-shipped`／`gate-protocol-lib-slice2-shipped`
（68× 槓桿的既有示範）。

---

## CC-577 — lint-規則穿測試外衣的 case 退場（搬到 layer-boundaries） ✅ 2026-08-29

**Problem**: 全測試語料掃描後，唯一符合「proxy test 應退場」判準的是 4 個
case——它們是 **lint 規則穿著測試的外衣**：只在有人跑那個 suite 時才檢查、只涵蓋
硬編在 case 裡的那幾個檔、且沒有任何 lint 保證新增的檔案也遵守同一規則。

| # | 位置 | 現在做什麼 | 問題 |
|---|---|---|---|
| 1 | `test-pmctl-memory.sh` `case_memory_shared_readers_avoid_bash_43_namerefs` | grep 3 個硬編檔禁 `local -n`（bash 4.3 nameref） | 規則對，但只查 3 個檔、埋在 85s 的 suite 裡 |
| 2 | `test-dispatch-common.sh` `case_dispatch_common_no_adapter_name_in_code` | grep `dispatch-common.sh` 禁出現 `codex\|claude\|opencode\|grok` 字面值 | 規則對（shared lib 要 adapter-agnostic），但只查 1 個檔 |
| 3 | `test-host-manifest.sh:596` | grep `doctor.sh` 找一段 `<provider> <enforcement> ...` 格式字串 | 鎖住 production 內文，非行為 |
| 4 | `test-e2e-script.sh` `test_phase_c_commits_context_ignore` | 斷言 e2e 腳本的 **body** 含某行 `printf '.pm-dispatch/\n' > ...`，而不是跑它再看檔案 | 典型 source-shape proxy（`ANTI-PATTERNS.md` #18） |

掃描同時確認：其餘 12 處「讀 production 檔的斷言」都**合法**（驗證安裝／產生出來的
檔案指向正確路徑，不是 proxy），不在本票範圍。

**Why**: 這 4 個 case 是 [[CC-576]] Req 2「新測試的層級判準」的現成示範案例——
「這個行為是不是某個東西的結構規則？是則測在結構層。」退場的正確形式是**搬到對的
層**，不是刪掉（規則本身 1 和 2 是真的要守）。

**Requirement**:
1. 把 #1、#2、#3 改寫成 `tests/shell/test-layer-boundaries.sh` 的規則函式，沿用該
   檔既有模式：每條規則是一個掃 ROOT 印出違規行的函式，先斷言真實 repo 乾淨，再在
   fixture 種一個違規證明規則會響。
   - #1：掃整個 `runtime/lib` + `runtime/hooks`（凡是 prompt-hook 會 source 的路徑）
     禁 `local -n` / `declare -n` / `typeset -n`，不再只查 3 個硬編檔。
   - #2：掃 `runtime/lib/dispatch-common.sh`（未來若有其他宣稱 adapter-agnostic 的
     shared lib 可加入清單）禁 adapter 字面值。
   - #3：改成斷言 `doctor.sh` 的**行為**（跑它、看它印出的 tuple 標頭），或若確實只
     需要格式一致性就併入既有的 doctor 輸出契約測試；不保留 source-grep 形式。
2. #4 改成真的執行該 e2e 階段（或其最小切片）再斷言 `.gitignore` 檔案內容，移除
   對腳本 body 的字串斷言。
3. 從原 suite 移除這 4 個 case；跑 `test-layer-boundaries`、`test-pmctl-memory`、
   `test-dispatch-common`、`test-host-manifest`、`test-e2e-script` 確認：新規則會抓到
   種進 fixture 的違規、真實 repo 乾淨、被移除 case 的原 suite 仍全綠。

**Non-goals**:
- 不動 `test-pr-gate.sh` 的 9 個長診斷斷言——已逐一看過，多數是 gate 的**對外**
  錯誤訊息（使用者會看到），不符合「鎖內部措辭」判準。
- 不合併 4 個 adapter dispatch suite（codex/claude/grok/opencode）——雖有 ~16 個
  同形 case，但這 4 個 suite 合計在全套 6.1% 桶裡，合併省不到時間、且會犧牲每個
  adapter 獨立可讀的 fixture（[[CC-536]] 教訓）。
- 不新增「禁止未來 proxy test」的 lint（另議；先看這次搬遷是否穩定）。

**驗收方式**: 4 個 case 從原 suite 消失、對應規則在 `test-layer-boundaries.sh` 且
其 fixture 違規測試會響；全套 case 數淨 −4，`test-layer-boundaries` 仍 <2s。

**Update 2026-08-29（已交付，pr:#559）**：實作時把 4 → **2 個真搬、2 個評估後留原地**。
- **搬**：#1 nameref、#2 adapter 字面值 → `check_shared_lib_no_namerefs`（掃 `runtime/lib`+`runtime/hooks` 整棵樹）、`check_shared_lib_adapter_agnostic`（讀 `ADAPTER_AGNOSTIC_LIBS` 陣列，一行可擴充）。兩者進 `ALL_CHECKS`、帶 fires + 誤報守門 self-test。`test-layer-boundaries` 41 passed / <2s；`test-pmctl-memory` −1、`test-dispatch-common` −1。
- **留**：#3 `test-host-manifest.sh:596` 是 doc↔code 一致性斷言，`test-layer-boundaries` 裝不下、強化成解析 `emit_capability` 對 P3 不成比例；#4 `test_phase_c_commits_context_ignore` 守的行為只有**未進自動化套件**的 `test-e2e.sh` 會跑，「真跑再驗檔」＝跑整個 live e2e，不可行，source-shape 是務實選擇。
- **Gate 教訓**：round 1 NO-GO（qa hard block）——搬過來的 nameref regex 只檢查第一個 flag cluster，漏掉 split-option `local -r -n`（這個洞是從被刪的舊 case 繼承來的；搬成整棵樹 ratchet 是修它的時機）。round 2（sequential）GO。

**See**: pr:#559（`check_shared_lib_no_namerefs` / `check_shared_lib_adapter_agnostic` 進 `test-layer-boundaries.sh`；`test-pmctl-memory` / `test-dispatch-common` 各刪 1 case）。

**Cross-link**: [[CC-576]]（Req 2 的示範案例）、[[CC-554]]（准入門檻——管「該不該
有」；本票管「該在哪一層」）、memory `test-governance-batches-plan`（Batch 2 曾點名
#4 e2e proxy 與另一個 nameref proxy，本票是那個方向的最小落地）、`ANTI-PATTERNS.md`
#18（source-shape proxy test）。

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

---
