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
| CC-452 | ✅ done | guard/hook 對稱性與併發 hardening；僅與 lifecycle/state correctness 直接相關的 slice 納入 v0.10.0 | ops | 2026-07-06 | pr:#431 | P3 | hygiene |
| CC-453 | ✅ done | worktree/auto-pack 路徑契約 hardening；僅與 lifecycle/state correctness 直接相關的 slice 納入 v0.10.0 | ops | 2026-07-06 | pr:#430 | P3 | hygiene |
| CC-461 | 🟢 someday | `doctor.sh --fix`：僅限冪等/可逆/不碰使用者內容類別的自動修復；待 CC-447 offline smoke 產出摔倒點清單後定白名單（2026-07-07 openyida 跨專案分析） | ops/install | 2026-07-07 | — | P3 | — |
| CC-462 | 🟢 someday | e2e 可拋棄資源紀律：前綴命名 + registry JSON + result artifact；掛在 CC-449 e2e 新 phase 之後，與 CC-447 live smoke 共用同一 registry（2026-07-07 openyida 跨專案分析） | ops/test | 2026-07-07 | — | P3 | — |
| CC-463 | 🟢 someday | `pmctl batch` 泛用批次執行原語；依賴 CC-460（合法性驗證來源）；新注入面須過 security-reviewer（2026-07-07 openyida 跨專案分析） | arch/process | 2026-07-07 | — | P3 | design |
| CC-464 | 🟢 someday | `pmctl ticket draft --from <notes>`：隨手筆記→結構化 backlog 票草稿；依賴 CC-286（prefix-generic next-id，⏸ deferred 尚未排程）；review-first 邊界獨立設計，CC-054 僅供鬆散參照非直接前例（2026-07-07 openyida 跨專案分析） | ux/process | 2026-07-07 | — | P3 | — |
| CC-493 | 🟢 someday | Prompt→Skill→Command→Harness 升級規則文件化：可測試的分類判準（何時停在 prompt、何時升為 skill、何時做成 command、何時需要 harness-level hook/guard/state），並盤點 `commands/`／`skills/`／`agents/` 現況對照分類（2026-07-15 CC-489 三方 multi-model synthesis） | process/docs | 2026-07-15 | feedback:2026-07-15 | P2 | design |
| CC-494 | 🟢 someday | design: executor 局部設計裁量權 envelope——在 dispatch brief / executor contract 定義「可自行處理的局部設計」與「必須 halt 回報 PM」的邊界（例如新增 schema 欄位 `design_latitude`/`architectural_conflicts`）；三方 multi-model synthesis 2:1 分歧（codex/fable 認為現行邊界過度僵硬需要新機制，opencode 認為現行 `isolation_level`/executor 欄位已足夠彈性），本票僅追蹤決策、不預設結論（2026-07-15） | schema/process | 2026-07-15 | feedback:2026-07-15 | P3 | design |
| CC-495 | ✅ done | `pmctl dispatch cancel <run_id>`：可信任的 detached-run cancel terminalization、PID reuse 防護、cancel-vs-complete 單一終態、authenticated cancelled sentinel | arch/gate | 2026-07-15 | feedback:2026-07-15 | P1 | design |
| CC-498 | ✅ done | State compatibility surface：status、layout/entity 版本命名、真實 migration availability | arch/schema | 2026-07-17 | pr:#435 | P1 | design |
| CC-499 | ✅ done | Detached run reconciliation：crash、reboot、stale sentinel、PID identity 與 orphan recovery | arch/ops | 2026-07-17 | pr:#429 | P2 | design |
| CC-500 | ✅ done | State single-writer boundary enforcement：all-production-domain direct-writer ratchet | arch/test | 2026-07-17 | pr:#438 | P2 | design |
| CC-503 | ✅ closed 2026-07-24 | shared tooling/hooks host-boundary 收斂：skill-refine canonical memory、prompt payload adapter、state-root audit log、content ratchet | arch/hook | 2026-07-17 | pr:#445 | P2 | hygiene |
| CC-504 | ✅ closed 2026-07-23 | top-level install/uninstall/doctor 移除 Claude base-spine 特例，建立 manifest-driven multi-host lifecycle 與 product-asset ownership | arch/install | 2026-07-17 | pr:#442 | P2 | design |
| CC-505 | 🔵 active | context plane lexical 檢索補完（Ph1 engine+統一排序+fixtures；Ph2 agent 契約+shadow 儀器化；evidence-gated 收緊 → [[CC-506]]）（2026-07-20 四方 synthesis；CC-346/347 前置） | memory/DX | 2026-07-20 | — | P2 | retrieval |
| CC-506 | ⏸ deferred | retrieval evidence-gated 收緊：shadow 評測（coverage@5、critical miss、read reduction、outcome parity）達標後才收緊 broad-Read 指引並重評 [[CC-340]] resume 條件；前置 = [[CC-505]] Ph2 shipped + ≥20 真實任務證據 | memory/DX | 2026-07-20 | — | P3 | retrieval |
| CC-507 | ✅ done | `pmctl state status`：無法讀取 `VERSION` 時被 Bash `$(<file)` redirection 提前中止，未回傳契約的 unreadable/exit 3 | arch/test | 2026-07-21 | pr:#437 | P1 | design |
| CC-508 | ✅ closed 2026-07-25 | executor producer 的 parent-operation control plane：可追溯子 run、受控取消與單一終態；目前納入 gate／ship，task dispatch 保留為後續接入 | arch/gate | 2026-07-21 | pr:#447 | P2 | design |
| CC-509 | ✅ closed 2026-07-22 | detached gate launch liveness：對 sandbox parent-death 早期死亡 fail-loud，提供 supervisor readiness／identity evidence | arch/gate | 2026-07-22 | pr:#440 | P2 | hygiene |
| CC-510 | ✅ closed 2026-07-23 | Codex detached dispatch continuation：App Server callback、authenticated completion envelope 與 foreground fallback | arch/DX | 2026-07-23 | pr:#443 | P2 | design |
| CC-511 | ⚠️ partial 2026-07-24 | ship publish authorization：Phase A current-tree authoritative full-suite 與 CC-515 shared verifier foundation 已交付；Phase B review-closure evidence 仍待 CC-517 | release/gate | 2026-07-23 | pr:#446 | P1 | design |
| CC-512 | ✅ closed 2026-07-27 | Slices A／B／C 已交付：coordinate sources／CLI resolution、machine-owned assurance envelope／evidence capture、shared verifier／parity ratchets；targeted 不再是 tier | ops/gate | 2026-07-23 | pr:#451 | P1 | design |
| CC-513 | ✅ closed 2026-07-28 | canonical gate policy resolver：minimum tier、required reviewers、mode recommendation 與 downgrade audit | security/gate | 2026-07-23 | pr:#452 | P1 | design |
| CC-514 | 🔵 active | orthogonal delivery assurance map、machine-derived tables 與 feature/docs/high-risk recipes | docs/process | 2026-07-23 | — | P2 | design |
| CC-515 | ✅ closed 2026-07-29 | `gate_assurance_v3` immutable subject 與 artifact／subject／policy 三軸 shared verifier；downstream scope／closure producers 分屬 CC-518／CC-517 | arch/gate | 2026-07-23 | pr:#454 | P1 | design |
| CC-516 | ⏸ deferred | evidence-gated thin delivery wrapper 評估；只組合既有 primitives，不建立 workflow engine/FSM | ux/process | 2026-07-23 | — | P3 | spike |
| CC-517 | 🔵 active | maintainer `/ship`：primary review、structured remediation closure 與 conditional targeted confirmation | process/gate | 2026-07-23 | — | P1 | design |
| CC-518 | ✅ closed 2026-07-29 | gate scope manifest v1：immutable subject、changed paths、paired tests、signals 與 bounded expansion | ops/gate | 2026-07-23 | pr:#455 | P1 | design |
| CC-519 | ✅ closed 2026-07-30 | selected-reviewer coverage／finding contract：declared coverage、stable IDs 與 actionable fix boundary | ops/gate | 2026-07-23 | pr:#456 | P1 | design |
| CC-520 | ✅ closed 2026-07-31 | synthesis parity 與 remediation seed：findings union、root-cause grouping、coverage matrix 與 no-silent-drop | ops/gate | 2026-07-23 | pr:#460 | P1 | design |
| CC-521 | 🔵 active | test-gap matrix、protocol recovery 與 live recall evaluation 分層 | ops/test | 2026-07-23 | — | P2 | design |
| CC-522 | 🔵 active | 任意 `--test-cmd` 的 opaque／structured capability negotiation、執行失敗分類與外部 evidence recovery | ops/test | 2026-07-27 | feedback:2026-07-27 | P1 | design |
| CC-523 | ✅ closed 2026-07-28 | `pmctl gate cancel` 必須終止 reviewer 派發前仍在執行的 foreground preflight 與其 process tree | arch/gate | 2026-07-27 | pr:#453 | P1 | hygiene |
| CC-524 | 🔵 active | `pmctl artifacts show` 顯示 canonical absolute run root 並提供穩定 machine-readable locator | ux/ops | 2026-07-27 | feedback:2026-07-27 | P2 | hygiene |
| CC-525 | 🔵 active | copy-mode verifier fallback 的 generated provenance 必須指向實際 generator，並由 parity ratchet 防止再次漂移 | ops/test | 2026-07-28 | feedback:2026-07-28 | P3 | hygiene |
| CC-526 | 🔵 active | reviewer override file 的 symlink trust-boundary hardening 與相容性契約 | security/gate | 2026-07-28 | feedback:2026-07-28 | P2 | hygiene |
| CC-527 | 🔵 active | targeted gate CLI 拆分 pass、reviewer coverage 與 tier，避免 full targeted 語意重疊 | ux/gate | 2026-07-28 | feedback:2026-07-28 | P2 | design |
| CC-528 | ✅ closed 2026-07-30 | publish policy compatibility：generic 為可接受 baseline、maintainer 為 preferred，並允許 ship 驗證既有 current-tree Gate artifact | release/gate | 2026-07-30 | pr:#457 | P1 | design |
| CC-529 | 🔵 active | publish assurance observability：在 ship 成功輸出、PR body 與 finish marker 保留 embedded policy 與 baseline/preferred satisfaction | release/gate | 2026-07-30 | feedback:2026-07-30 | P2 | hygiene |
| CC-530 | 🔵 active | source-safe runtime library contract + centralized domain identifier policy | arch/reuse | 2026-07-30 | feedback:2026-07-30 | P1 | hygiene |
| CC-531 | 🔵 active | Adapter manifest contract closure：dispatch entrypoint 成為唯一 runtime authority | arch/schema | 2026-07-30 | feedback:2026-07-30 | P1 | design |
| CC-532 | 🔵 active | Gate canonical modules + generated standalone distribution + parity fixtures | arch/gate | 2026-07-30 | feedback:2026-07-30 | P1 | reuse-debt |
| CC-533 | 🔵 active | schema-derived Gate structural validator，手寫 verifier 只保留跨 artifact semantics | schema/gate | 2026-07-30 | feedback:2026-07-30 | P1 | design |
| CC-534 | 🟢 someday | `commands.tsv` 驅動 CLI routing、safe handler dispatch 與 lazy module loading | arch/DX | 2026-07-30 | feedback:2026-07-30 | P2 | design |
| CC-535 | 🟢 someday | detached-launch 上的 supervised-run primitive + versioned JSON run-spec | arch/ops | 2026-07-30 | feedback:2026-07-30 | P2 | design |
| CC-536 | 🟢 someday | 擴充 Adapter SDK 的 shared lifecycle／manifest／trace contract，保留 executor-native behavior | arch/reuse | 2026-07-30 | feedback:2026-07-30 | P2 | reuse-debt |
| CC-537 | 🟢 someday | suite metadata 與 changed-path impact mapping 資料化；full suite 維持 authoritative | ops/test | 2026-07-30 | feedback:2026-07-30 | P2 | hygiene |
| CC-538 | 🟢 someday | Host resolver／doctor 共用 primitives，Host policy 繼續由各 Host 擁有 | arch/ops | 2026-07-30 | feedback:2026-07-30 | P2 | reuse-debt |
| CC-539 | 🟢 someday | state `layout.yaml` build-time authority + generated runtime constants | arch/schema | 2026-07-30 | feedback:2026-07-30 | P2 | design |
| CC-540 | 🟢 someday | `pmctl state prune`：刪除前先抽取+驗證 gate/dispatch run 摘要，避免歷史分析資料隨磁碟空間一起消失 | ops/gate | 2026-07-31 | — | P2 | hygiene |
| CC-541 | 🔵 active | codex reviewer sandbox 讀不到主機上已存在的 `QA_RULES_DIR`，qa-tester 對 hard-stop 與可用規則來源之間 fail-loud 行為需要釐清並修復 | ops/gate | 2026-08-04 | feedback:2026-08-04 | P2 | hygiene |
| CC-542 | 🔵 active | 移除 `test-pmctl-context`／`test-release-verify` 的 LIVE_DB_EXCLUSIVE 全域互斥：release-verify Phase 3 context-index 改用隔離 fixture repo，不再重建 live `context.db` | ops/test | 2026-08-04 | — | P1 | hygiene |
| CC-543 | 🟢 someday | Full test runner 增加 fail-fast structural precheck（registry lint／regression／schema 等便宜檢查獨立成 Phase 0，失敗即中止，不啟動昂貴 suite） | ops/test | 2026-08-04 | — | P2 | hygiene |
| CC-465 | 🔵 active | memory/context 關鍵詞管線 CJK 支援：抽出共用零依賴斷詞 lib，取代三處各自 ASCII-only 抽詞；工作序列起點（465→467→468→466）（2026-07-07 記憶系統深入分析） | memory | 2026-07-07 | feedback:2026-07-07 | P2 | retrieval |
| CC-466 | ⏸ deferred | 記憶卡片生命週期閉環：expires_at 執行 + 關窗式 supersede + usage sidecar 休眠偵測 + doctor→distill 接線；僅在 CC-467 證明 stale/dormant card 已形成實際問題時啟動 | memory | 2026-07-07 | feedback:2026-07-07 | P2 | retrieval |
| CC-467 | 🔵 active | `pmctl memory stats`：注入效益可視化（唯讀聚合器）——注入 bytes/卡片命中分佈/從未命中卡/episode 填寫率，回答「記憶有跟沒有差在哪」；排在 CC-466 之前（2026-07-07；業界僅離線 recall 評測，無 per-injection 遙測） | DX/memory | 2026-07-07 | — | P2 | retrieval |
| CC-468 | ⏸ deferred | dispatch brief 帶 memory 約束與信任邊界；完成 CC-465→CC-467 後，僅在 usage evidence 證明有價值時啟動 | ops/memory | 2026-07-07 | — | P2 | retrieval |
| CC-011 | 🟢 someday | sync-memory.sh + install 選項：symlink memory 到雲端資料夾實現跨裝置共用 | ux/memory | 2026-05-14 | — | — | — |
| CC-012 | 🟢 someday | SessionStart hook：session 啟動時 pull 最新 memory（git/rsync）確保跨裝置同步 | ux/memory | 2026-05-14 | — | — | — |
| CC-015 | 🟢 someday | `systematic-debugging` skill：結構化偵錯工作流；作為升級規則(CC-493)定案後的首個試點 skill，落地於 `skills/systematic-debugging/SKILL.md` 而非 slash command | ux | 2026-05-14 | — | P3 | — |
| CC-018 | 🟢 someday | Codex quota 自動追蹤 + rate-limit 路徑統一（吸收 CC-269）：寫到 `~/.local/share/pm-dispatch/state/rate-limits.json`；解析 API response headers；token-usage.sh 加 Codex pool 顯示 | ux/token | 2026-05-14 | — | P3 | — |
| CC-023 | ⏸ deferred | `coupling-reviewer`：PR gate 加入語言感知耦合分析（dependency-cruiser/gocyclo/coca） | ops/gate | 2026-05-14 | — | — | — |
| CC-026 | 🟢 someday | `/skill-distill`：偵測重複工作流，產出草稿 skill .md | ux/memory | 2026-05-15 | — | P3 | — |
| CC-032 | 🔵 active | `[[feedback_*]]` cross-link 公開化：抽到 `docs/policies/` glossary 避免 dead link（v1.0 前置；v0.12.0 contract candidate） | process/DX | 2026-05-15 | — | P2 | — |
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
| CC-244 | 🟢 someday | **[Typed artifact pipeline — spike → brief → handover schema]** Define `spike_v1` schema mirroring existing `dispatch_handover_v1`: frontmatter (`spike_id`, `status`, `decisions_resolved`, `branch_base`, `ticket_ids_consumed`, `project_tooling`) + named sections (`scope`, `findings`, `constraints`, `decisions`, `phase3_handover`). Add `tools/spikes/spike-validate.sh` (mirror `handover-validate.sh`) + `tools/spikes/gen-brief-from-spike.sh` (mechanical brief extraction). Reduces main-thread courier cost, makes spike→brief authoring mechanical, gives invariant checkpoints (`decisions_resolved=true` ⇒ no re-asking Q1/Q2). Defer until 3+ spike docs exist and the brief-extraction pattern repeats; only one spike (CC-060) today, so schema would be premature overhead. CC-243 field names chosen to align with this future schema (no re-wash needed at upgrade time). | arch | 2026-05-23 | — | — | design |
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
| CC-358 | 🔵 active | runner telemetry：`pmctl run-stats` per-adapter 成功率/失敗模式/fallback 分析（v1.0 readiness 證據；v0.11.0） | ops/memory | 2026-06-10 | — | P2 | design |
| CC-359 | 🟢 someday | concept: backlog-driven batch dispatch with worktree isolation（PM manages `git worktree` lifecycle；executor-agnostic；human-in-the-loop merge；PR-only output） | arch/ops | 2026-06-11 | — | — | design |
| CC-364 | ⏸ deferred | **[perf: `pmctl trace tail --all` per-event jq spawn]** `pmctl trace tail --kind <k> --all --json` is O(n) with a high per-event constant — ~20s for 338 events (~60ms/event), consistent with spawning a jq/subprocess per event rather than one streaming pass. Surfaced while diagnosing #270 context-telemetry test flakiness; the tests no longer depend on it (telemetry now honors `PM_DISPATCH_STATE_ROOT`, so the suite isolates state). Standalone reader-perf follow-up. **See**: pr:#270 | ops | 2026-06-12 | pr:#270 | P3 | hygiene |
| CC-369 | ⏸ deferred | Windows state store 真實 ACL via icacls（parked: CC-370；border case relative to profile ACL protection） | ops/portability | 2026-06-13 | — | — | hygiene |
| CC-370 | ⏸ deferred | **[native Windows support deferred to post-core platform phase]** 核心功能開發期間正式只支援 Linux + WSL2（WSL2 視為 Linux）；原生 Windows Git Bash 非官方支援，使用者走 WSL2。理由是專注：開發期同時扛多平台會排擠核心功能（CI 只測 Linux，每次碰 Windows 都要人工驗證 + gate churn，見 #272/#273）。已合併的 portability 程式碼保留（綠且成本低），但不再新增 Windows 分支，直到核心定型（v0.5.0+）後的專屬平台階段。Parks: CC-038, CC-104d/e/f/g/j/k/r/s, CC-369。**See**: DECISIONS.md 2026-06-13 defer-native-windows-support-during-core-dev | ops/portability | 2026-06-13 | — | — | design |
| CC-377 | ⏸ deferred | adapter: Google Antigravity（`agy`）executor（DEFERRED：headless CLI 1.0.8 不成熟；resume: newer agy with `--output-format stream-json`；umbrella: CC-333） | arch/portability | 2026-06-13 | — | P2 | design |
| CC-390 | ⏸ deferred | codex dispatch trace-capture 強化（FD inheritance cold-start flake；fail-closed safe；resume: stable repro；umbrella: CC-333） | arch/portability | 2026-06-15 | — | P3 | design |
| CC-393 | 🟢 someday | design: portable-skill-substrate — CLI-agnostic skill 控制層（design seed after v0.6.0 N≥2；3 control skills + Portable Skill v0 frontmatter；umbrella: CC-333） | arch | 2026-06-16 | — | — | design |
| CC-435 | 🟢 someday | **[poll→通知機制 single-waiter guard：條件觸發，非既定後續票]** 只有在真正出現多個 waiter 需要同時等待同一個 run_id/gate_id 的場景時才拿出來討論；候選設計見 `docs/spikes/CC-433.md` Open risks（方案 A：`flock` 搶鎖+敗者退回輪詢；方案 B：per-waiter 專屬 fifo+supervisor 廣播）。CC-434 完成後重新盤點成本效益：輪詢 vs blocking read 在單一 waiter/數分鐘等待場景下資源消耗差距趨近於零，延遲改善（≤2s→近乎即時）對人在等 gate 結果無感，而兩個方案都要在安全敏感的 supervisor 檔案引入新 race condition，投資報酬率目前不足，故不排入既定實作，僅記錄設計供未來觸發條件成立時起步。 | arch/gate | 2026-07-02 | — | P3 | design |
| CC-446 | 🔵 active | public contract candidate：stable/experimental CLI + schema、authority 分類、SemVer/deprecation 與 CC-296 清掃（v0.12.0；非 v1 RC） | process/DX | 2026-07-04 | — | P2 | design |
| CC-447 | 🔵 active | onboarding 三 smoke：offline clean install + N-1 upgrade（v0.11.0）+ live dogfood（readiness review 後再排） | docs/ops | 2026-07-04 | — | P2 | — |
| CC-449 | ✅ done | release evidence parity：suite registry、CI parity、OpenCode（吸收 CC-431）、ship/worktree smoke（v0.11.0） | ops/test | 2026-07-04 | pr:#439 | P2 | — |
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
6. 每份候選 manifest、schema、registry、policy 與 layout specification 都標記為
   `runtime authority`、`build-time authority` 或 `parity/documentation
   specification`；runtime/build-time authority 必須有單一 consumer/generator
   路徑與 drift check，不得一面宣稱 source of truth、一面維護等價手寫實作。

**Done-when**：分級表覆蓋全部 pmctl 子指令與 schema 檔；CC-296 清掃完成；repo 內無「標 deprecated 但無移除計畫」的懸空表面；README 與分級文件互相一致。

**Dependencies**：吸收 [[CC-296]] 執行。[[CC-451]]、[[CC-460]] command inventory、[[CC-498]] state compatibility 為事實前置。Cross-link [[CC-286]]、[[CC-357]]、[[CC-531]]～[[CC-539]]。v0.12.0 contract candidate；完成後才進行 v1.0 readiness review。
**See**: DECISIONS.md 2026-07-04

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

## CC-449 — release-verify/test-e2e：ship/worktree surface 煙測 + 套件註冊完整性 lint ✅ 2026-07-21

**Problem**：v0.8.0 新增的 `pmctl ship`（unified entry / prepare / finish / `--parallel`）與 `pmctl worktree`（create/list/remove/gc）只有 unit 套件覆蓋；release sign-off 的 e2e 路徑（`tests/shell/test-e2e.sh` Phase B/C）只驗 dispatch 輸出契約與 pr-gate 機制，對這兩個新 surface 零 live 煙測。且 [[CC-444]] 收尾時發現 `tests/shell/test-pmctl-worktree.sh`（36 cases）**根本沒註冊進 full runner registry**——套件存在但 aggregator 從未執行，release-verify 的「全套綠燈」靜默漏掉它（已於 CC-444 補註冊）；「新增 suite 必須註冊」目前無任何機械防護。CC-481 後 canonical registry 位於 `tests/lib/test-suite-runner.sh`，`tests/bin/run-all-tests.sh --list` 是穩定查詢 surface。OpenCode 已是現有 adapter，但 `test-e2e`／`release-verify` 的 adapter 驗證與 Phase B/C 尚未提供等價證據；此範圍由本票吸收 [[CC-431]]。

**Why**：v1.0 P1 證據層的一環——release sign-off 的覆蓋範圍必須跟上 surface 的成長，否則 `release-verify GO` 的可信度逐版稀釋；註冊完整性 lint 是同類靜默缺口的止血閥。

**Outcome**：canonical suite/CI parity lint 與 regression 注入案例已納入 CI 及
release Phase 1；OpenCode adapter inventory 與 Phase B2 的 local ship/worktree
smoke 已有證據。`ship finish` 因需要有效 gate artifact、GitHub 認證且可能推送或
建立 PR，明確保留在 protected ship/release workflow，不在可逆的 local smoke 執行。
`runtime/lib/gate-workspace.sh`、`runtime/lib/pmctl-config.sh` 現有 direct
regression coverage；commands、agents、skills 則由單一 TSV registry 與 lint 強制
coverage tier/reason 宣告，並以缺宣告注入測試釘住。

**Requirement**：
1. **套件註冊完整性 lint**（第一刀，機械）：`tests/shell/test-*.sh` 存在但未在 `tests/lib/test-suite-runner.sh` 註冊 → fail loud（允許顯式 exclude 清單，如 fixture-only helper）；接入 CI 與 `ops/release/release-verify.sh` Phase 1。評估讓 meta-suite 從 canonical executor 動態派生，消除人工同步面。
2. **ship/worktree e2e 煙測**：`tests/shell/test-e2e.sh` 新增 phase——synthetic target 上走一次 `pmctl worktree create → pmctl ship <id> --worktree → ship status 讀到 prepared → worktree remove`（不 dispatch、不花 LLM token 的最小閉環）；`ship finish` 的 live 驗證（含 gate）評估成本後決定納入或明文排除並記錄理由。
3. **OpenCode adapter evidence**（吸收 [[CC-431]]）：adapter 清單由 canonical adapter inventory 派生；Phase B dispatch 支援 OpenCode；Phase C pr-gate smoke 若不能使用 OpenCode executor，須明文降標或記錄排除理由。
4. **CI↔run-all parity 斷言**（2026-07-06 盲測稽核擴充）：`.github/workflows/lint.yml` 的 job 清單與 full runner registry 各自手動維護、零 parity 檢查——實測 24 個本地 suite 在 CI 從未執行，含 dispatch 核心（test-dispatch-lifecycle、test-dispatch-common、test-detached-launch、test-opencode-dispatch）與三個最大 pmctl 套件（test-pmctl-context/memory/dispatch）。lint 需一併涵蓋：canonical executor 每個註冊 suite 必須在 CI 出現，或列入顯式豁免清單並附理由（如 live-DB 互斥、耗時）。這是比第 1 項「未註冊」更大的同類靜默缺口。
5. **零覆蓋 lib 盤點**（同批）：`runtime/lib/gate-workspace.sh`、`runtime/lib/pmctl-config.sh` 在所有測試檔零引用——補最小套件或記錄豁免理由。
6. **surface 覆蓋分類 lint（反向補完，2026-07-07 openyida 跨專案分析併入）**：每個 command/agent/skill 必須宣告 `coverage: e2e|unit|opt-in|manual-only|deprecated` + 一行理由；本項是第 1 項「套件存在但未註冊」的反向缺口——「surface 存在但沒人宣告它該有什麼等級的覆蓋」。清單載體與既有 lint 機制（第 1/4 項）同批評估，避免產出第二套獨立 YAML/清單格式。

**Done-when**：lint 落地且能抓到「新增未註冊套件」與「已註冊但 CI 缺席且無豁免」與「surface 缺 coverage 宣告」三類注入測試；e2e 新 phase 在 `release-verify.sh --e2e` 下通過；排除項（若有）記錄於腳本註解與本票。

**Dependencies**：已吸收 [[CC-431]]；與 [[CC-454]] 協調 CI/lint ownership，但不合併 ShellCheck domain coverage。v0.11.0。
**See**: [[CC-444]] Outcome、pr:#367、pr:#439

---

## CC-452 — guard/hook 對稱性與併發 hardening ✅ 2026-07-20

**Outcome**: Shipped via pr:#431。Item 1（episodes.jsonl 無鎖 append）已由先前工作
（`0b66f1f`）以 `serialize_with_lock` 修復，本票驗證未回歸、不再改碼。Item 2：
`guard-pm-write.sh`/`guard-reviewer-write.sh` 統一 `set -euo pipefail`；對稱性回歸
測試動態列舉 `runtime/hooks/guard-*.sh`（新 guard 自動納入），並明文釘住唯一豁免
`guard-pm-bash.sh`（其 `[[ cond ]] && exit 0` no-op 快路徑在 `-e` 下會中止並誤擋所
有非 PM Bash 呼叫；理由已註記於該檔 `set` 行）。Item 3：兩 hook 重複的 ISO8601 正
規化抽為 `runtime/lib/memory.sh` 的 `memory_iso8601_normalize()`，並移除與
bare-fractional catch-all 重複的 fractional-Z 分支。Gate GO
（`gate-20260720-052655-e72d67`）；全套件 87 suites 綠。See CHANGELOG Unreleased。

**See**: pr:#431

**Problem**（2026-07-06 盲測稽核，三項低風險高確定性 correctness/一致性缺口）:
1. `guard-session-summary.sh` 對 episodes.jsonl 的 skeleton append 是裸 `>>` 無鎖，而同一資料面的 `guard-inject-memory.sh` usage sidecar 已用 `serialize_with_lock`——並發 Stop hook（同 cwd 多 session）可交錯寫、破壞 dedup 前提。
2. 三個安全 guard 的 shell 選項不一致：`guard-executor-write.sh` 用 `set -euo pipefail`，`guard-pm-write.sh`/`guard-reviewer-write.sh` 缺 `-e`——未預期非零命令靜默續行。
3. ISO8601 日期正規化 ~30 行在 `guard-inject-memory.sh` 與 `guard-session-summary.sh` 逐字重複，漂移風險。

**Requirement**:
1. episodes.jsonl append 包進 `serialize_with_lock`，補並發回歸測試。
2. 三安全 guard 統一 `set -euo pipefail`（逐檔確認無依賴非零續行的路徑後切換）。
3. ISO8601 正規化抽到 `runtime/lib/memory.sh`（兩 hook 既有共用點），兩處改呼叫。
各項行為對現有測試 byte-compatible；只修對稱性與併發安全。

**Dependencies**: 無硬前置；只有與 CC-495/498 lifecycle/state correctness 直接相關的 slice 納入 v0.10.0，其餘維持一般 hardening backlog。
**Source**: 2026-07-06 盲測程式碼稽核（runtime 管線角度）。

## CC-453 — worktree/auto-pack 路徑契約 hardening ✅ 2026-07-19

**Outcome**: Shipped via pr:#430。`pmctl_worktree_create` 把 `git worktree add`
的 stdout chatter 導向 stderr，stdout 契約收斂為只印 worktree 路徑；auto-pack 對
非 git work tree 的 work_dir 驗證「絕對路徑 + 存在」，不符即 fail-loud 跳過 pack
（沿用既有 warning + telemetry 模式），杜絕相對路徑 `mkdir -p` 在 CWD 產目錄的
洩漏鏈；opencode isolation 錯誤訊息只提實際支援值 `none`。三項均補回歸測試
（含「垃圾 work_dir 不得在 CWD 產生任何目錄」斷言）。

**See**: pr:#430

**Problem**（2026-07-06 盲測稽核 + 實際洩漏案例）:
1. `pmctl_worktree_create` 以「stdout 最後一行 = worktree 路徑」為輸出契約，`git worktree add` 的 stdout chatter（`HEAD is now at ...`）不抑制、只靠消費端 `tail -1`（`pmctl-ship.sh` 等）——契約脆弱。2026-07-03 開發期間曾實際把 5 個名為 `HEAD is now at <sha> seed` 的垃圾目錄洩漏到 repo 根目錄（內含 `.pm-dispatch/ctx/packs`；因 `.pm-dispatch` 被 gitignore，`git status` 完全不可見）。2026-07-06 已清除，現行套件重跑不再重現，但根因鏈仍在。
2. `pmctl_dispatch_auto_pack` 對 work_dir 的 ctx_root 解析：`git -C "$work_dir" rev-parse` 失敗時靜默 fallback `ctx_root="$work_dir"`，接著相對路徑 `mkdir -p`——垃圾輸入會在當時 CWD 造出目錄而非 fail。
3. `adapters/opencode/dispatch.sh` 的 isolation 錯誤訊息推薦 `workspace-write`，但其 `isolation-map.yaml` 只支援 `none`——把使用者導向不被接受的值。

**Requirement**:
1. `pmctl_worktree_create` 抑制 git chatter 進 stdout（導向 stderr 或丟棄），stdout 收斂為「只印路徑」；既有 `tail -1` 消費端保持相容。
2. auto-pack 對 work_dir 驗證「存在 + 絕對路徑」，不符即 fail-loud 跳過 pack（沿用既有 auto-pack warning + telemetry 模式），絕不相對路徑 mkdir。
3. opencode isolation 錯誤訊息只提實際支援值。
各項補回歸測試（含「垃圾 work_dir 不得在 CWD 產生任何目錄」斷言）。

**Dependencies**: 無硬前置；只有與 CC-495/498 lifecycle/state correctness 直接相關的 slice 納入 v0.10.0。與 [[CC-449]] e2e 煙測互補（那邊驗 happy path，本票驗防禦面）。
**Source**: 2026-07-06 盲測程式碼稽核；洩漏目錄實例（已清除）。

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

## CC-465 — memory/context 關鍵詞管線 CJK 支援 🔵 active

**Problem**: 記憶注入排序（`guard-inject-memory.sh` 的 keyword 抽取）、檢索抽詞（`_ctx_extract_terms` → prompt-scan / reuse-scan）、FTS5 索引（unicode61 tokenizer）三處分詞全為 ASCII-only，CJK 字元被當分隔符丟棄。維護者工作語言為中文：中文 prompt 的 keyword tier 恆為 0 分、tier2 排序退化為純 frecency；且 usage sidecar 只在 keyword 命中時累積 access，中文工作流永遠累積不到使用訊號——整套 frecency 機制對 CJK 使用者形同虛設。prompt-scan / reuse-scan 對中文任務描述抽不出任何詞；FTS5 對整段中文只存單一 token，中文查詢僅靠 LIKE substring fallback 硬撐。

**Why**: 分詞邏輯設計時只考慮英文 identifier；CJK 無空白斷詞，ASCII 字元類過濾直接消滅整段文字。這是功能性缺陷而非排序品質調校——注入排序、usage 累積、檢索三條線同時失效。解法定調為**抽出一個共用零依賴斷詞 lib**（CJK bigram：連續 CJK 串切 2-gram），讓三個呼叫端遷移過去共用同一實作，而非三處各自獨立補丁——避免三份幾乎相同的邏輯各自漂移。FTS5 unicode61 tokenizer 對中文查詢的行為則視為與此共用 lib 分離的獨立關注點，另案驗證，不預設用同一次修改解決。不需外部分詞器，符合 bash / zero-LLM hooks 約束，也不觸發 [[CC-340]]（embeddings/semantic backend）的 resume 條件。

**Requirement**:
1. 抽出共用零依賴斷詞 lib（如 `runtime/lib/retrieval-terms.sh`），實作 CJK bigram 斷詞函式作為單一實作來源。
2. `runtime/hooks/guard-inject-memory.sh`（keyword tier 抽取／注入排序）與 `runtime/lib/pmctl-context.sh` 的 `_ctx_extract_terms`（`prompt-scan` / `reuse-scan` 抽詞）改為呼叫共用 lib，取代各自現有的抽詞邏輯。
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

**Status note (2026-07-15 CC-489 三方 multi-model synthesis）**: 重新定位為 harness/skill 分類下第一個高命中率試點 skill；不再落地為 slash command，改落地於 `skills/systematic-debugging/SKILL.md`（progressive disclosure，thin pointer 風格，比照現有 `skills/dispatch-brief`、`skills/pr-gate-review`）。
**Problem**: debug 工作流目前無標準化流程，每次偵錯方式不一致，容易遺漏根本原因分析。
**Why**: 結構化偵錯步驟（reproduce → isolate → hypothesize → verify → fix → regression test）有助於複雜 bug 分析；同時是驗證「skill = 可替換工作方法、非 workflow engine」定位的第一個實例。
**Requirement**: `skills/systematic-debugging/SKILL.md`，提供結構化偵錯步驟；不執行 state transition、不繞過 guard。
**Sequencing**: 待 [[CC-493]] 升級規則票定案分類判準後再落地，避免格式先於規則。

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
**Update 2026-07-30**: 排入 v0.12.0 public contract candidate（尚非 v1.0 RC）。repo 已為 public，本票的 link-target validator 綠燈為未來 stable release 的 hard constraint。
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
3. GitHub 設定決策照原 Requirement 1（Issues/Discussions/template/labels/CITATION.cff），在 v0.12.0 完成；觀察期留到未來 stable release 後。
4. **README 使用者表面重建**（2026-07-06 盲測稽核追加）：README 只記載 15 個 command 中的 2 個（`/pm`、`/pr-gate`）、Agents 段缺 spike agent、Layout 段引用已不存在的 `settings/` 目錄且缺 `skills/`（install.sh 實際會接線）——commands/agents/skills 清單改為與實際目錄一致（可由 `commands/*.md` frontmatter description 派生），Layout 修正到與 install 行為相符。
5. **Audit slice completed 2026-07-18**：以 `b7799c3` 為 baseline，掃描全部 493 個 reachable commits（含 2026-05-15 後 450 commits）。未發現需 rotation/history rewrite 的 credential、私鑰或誤入 runtime artifact；token-shaped matches 均為測試 fixture／字串誤判。已記錄兩項非 secret exposure（maintainer 絕對路徑、commit Gmail metadata）及一項持續防護缺口（GitHub secret scanning disabled）。處置與可重跑方法見 [docs/audits/CC-033-git-history-audit.md](docs/audits/CC-033-git-history-audit.md)。本票維持 active；README/協作表面、secret-scanning enablement verification 仍屬 v0.12.0。
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

Add `tools/spikes/spike-validate.sh` (mirror `handover-validate.sh`) + `tools/spikes/gen-brief-from-spike.sh` (mechanical extraction).

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
5. 判準文件需引用下列外部依據，使判準不只是本 repo 習慣的成文化（見「External grounding」）：第一級與第四級的分界採 degrees-of-freedom 判準；第二級採 progressive disclosure 的尺寸門檻；並在文件內建立「指令預算」概念（重要約束前置）。

**External grounding**（2026-07-25 外部檢索；每條均有可驗證來源）:
- **Degrees of freedom**（第一級↔第四級分界）：多種做法皆可、依情境判斷 → 留在文字；操作脆弱易錯／需一致性／需固定順序 → 降為 script 或 validator。與本 repo `DECISIONS.md 2026-05-19 cc030-validate-bidirectional`「prompt 層 enforcement 不可靠，結構 validator 是唯一穩固邊界」同向，互相印證。來源：<https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices.md>
- **Progressive disclosure 尺寸契約**（第二級量化門檻）：metadata（name/description）常駐載入、body 按需載入；`description` ≤1,024 字元、`SKILL.md` body <500 行、reference 檔案自 SKILL.md 起算一層深（更深會被部分讀取）、>100 行的 reference 需附目錄。現況實測本 repo 最大 prompt 資產 281 行，全數低於 500 行門檻——判準應據此記錄「現況合格」，避免把本票誤讀為需要大規模改寫既有 prompt。來源：同上。
- **指令密度衰減（量化）**：指令數量上升時，指令遵循率系統性下降，且存在偏向較早指令的傾向（後段指令先被忽略）；最佳前沿模型在 500 條指令密度下約 68% 正確率。用於支撐「指令預算」與「重要約束前置」兩項排序原則。來源：IFScale, arXiv:2507.11538 (2025-07)。

**Non-goals**: 不在本票內實際搬遷任何 `commands/`/`agents/` 檔案到 `skills/`；不建立 skill schema/validator（見 [[CC-357]]）；不建立 skill marketplace 或 DSL（見 [[CC-393]]）；不依本票改寫既有 `agents/`／`commands/` prompt（外部證據不支持大規模校準改寫，見 External grounding 第二點）。

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

## CC-495 — `pmctl dispatch cancel <run_id>`：detached run 中途終止機制 ✅ 2026-07-19

**Outcome**: Shipped `pmctl dispatch cancel <run_id> --cd <work_dir>` and
minimal discovery via `pmctl dispatch status --cd <work_dir>` (ticket req. 8).
Trusted state-derived artifact dir records supervisor identity
(pid/pgid/starttime/comm/isolated); cancel re-verifies before process-group
SIGTERM/SIGKILL and refuses non-isolated live groups. Exclusive
`$run_id.terminal` CAS ensures a single winner among ok/failed/partial/
cancelled. Cancel writes Run/Event (`run.cancelled`)/dispatch record then
nonce-authenticated cancelled sentinel; wait returns exit 130. Lifecycle
suite covers in-flight cancel, already-terminal non-overwrite, identity
mismatch, non-isolated refuse, orphaned PGID, forged workspace/`--trace-dir`,
incomplete record still wait-resolvable, and status listing.

**See**: pr:#428

**Problem**: `pmctl dispatch run --lifecycle detached` 有 `run`（啟動）與 `wait`（等待完成），但沒有任何方式可以在使用者發現 executor 卡住、跑錯方向、或需要中途喊停時主動終止一個進行中的 run。現況只能手動找到並 `kill $(cat <run_dir>/<run_id>.supervisor.pid)`——這個路徑完全沒有文件記錄，且：
1. `_pmctl_dispatch_launch_supervisor`（`runtime/lib/pmctl-dispatch.sh`）用 `detached_launch_under_setsid` 啟動 supervisor，若只 kill `.supervisor.pid` 記錄的單一 pid，底層真正在執行的 adapter CLI 子行程（在其自己的 process group 內）不保證被連帶終止，可能留下孤兒 process（性質類似 CC-487 觀察到的 CI 殘留 bash process）。
2. `core/policy/dispatch-states.yaml` 已定義 `cancelled` 為合法的 dispatch-level terminal state（`pending`/`in-progress` 均可轉入），但 canonical runtime 沒有任何 code path 寫入這個狀態——schema 已預留位置，實作完全空白。
3. `core/schema/run.schema.json` 的 `state` enum（`pending`/`dispatched`/`verifying`/`ok`/`partial`/`failed`）與 `core/policy/run-states.yaml` 也都沒有 `cancelled`，run-level 狀態機需要同步補上，否則 dispatch-level 的 `cancelled` 無法對應到底層 run 的真實終止原因。
4. 手動 kill 不會產生任何 event（`events.jsonl` 無 `run.cancelled`/`dispatch.cancelled` 記錄），dispatch record 會永遠卡在 `pending`/`dispatched` 狀態，沒有機械證據區分「使用者主動中止」與「跑到一半當掉/timeout」。

**Why**: 語意上刻意選 `cancel` 而非 `stop`——`stop` 暗示「之後可以續跑/resume」，但一個 executor run 中途被打斷後，brief 可能只執行到一半、檔案可能改到一半，狀態不完整、不安全恢復；`cancel` 精確表達「終止且結果不可信，需重新 dispatch」這個唯一合理語意，避免使用者誤以為存在 pause/resume 能力。這也是今天稍早 CC-489 三方分析點出的「控制面宣稱可審計/可恢復，但完成判定的對稱面（中止）完全沒有機械證據」的具體落地缺口。

**Requirement**:
1. `pmctl dispatch cancel <run_id> --cd <work_dir>` 的權威資料只來自 out-of-repo trusted run directory；workspace 內可被 executor 修改的 PID、record 或狀態不得作為 cancel authority。
2. 啟動時記錄 PID、PGID 與可驗證的 process start/command identity。cancel 在送 signal 前必須重新驗證 identity，PID reuse 或 identity 不符時 fail-closed，不得誤殺其他 process。
3. cancel 與 supervisor 自然完成共用 terminalization lock 或 compare-and-set；`ok`/`failed`/`cancelled` 只能有一個 terminal winner，既有 terminal 絕不覆寫。
4. 對已驗證的 process group 先送 `SIGTERM`，grace period 後仍存活再送 `SIGKILL`，並確認 group 已退出；不得只 kill supervisor PID 留下 adapter 子行程。
5. cancel 成功後，先以 designated writer 寫入 cancelled Run/Event/dispatch record，再由 trusted controller 寫入 nonce-authenticated `cancelled` sentinel；只有 terminal evidence 全部 durable 後才清理 pid/runspec/brief 等非證據 artifact。**不得刪除尚未被 wait 消費的 sentinel/key completion proof。**
6. `core/policy/run-states.yaml` 與 `core/schema/run.schema.json` 補上 `cancelled` terminal state 與合法 transitions。
7. `pmctl dispatch wait <run_id>` 驗證並消費 authenticated cancelled sentinel，以穩定且可文件化的非零 exit contract 區分 cancelled、failed、timeout、indeterminate；advisory record 不得單獨證明 terminal outcome。
8. 提供最小 in-flight run discovery，讓使用者不必手動翻 state directory；`docs/executor-contract.md` 說明 cancel、timeout 與不支援 resume 的邊界。

**Acceptance**:
- 對真實 in-flight detached codex/opencode/claude run cancel 後，底層 adapter process group 全數終止且無孤兒。
- cancelled Run/Event/dispatch record 與 authenticated sentinel 一致；`wait` 能驗證、消費並以穩定 distinct exit 回報 cancelled。
- cancel-vs-natural-complete race 重複壓測不產生雙終態；對既有 terminal cancel 不覆寫。
- PID reuse／identity mismatch、workspace 偽造 PID/record、部分 evidence write failure 全部 fail-closed 且不誤殺、不宣稱成功。
- `tests/shell/test-dispatch-lifecycle.sh` 與 detached supervisor focused tests 覆蓋以上案例。

**Non-goals**: 不做 pause/resume（語意上已排除）；不做完整的 `pmctl dispatch list` UI/篩選功能（見第 4 項，僅最小發現機制）；不處理 non-detached（foreground）dispatch 的取消——foreground 呼叫端本來就能用 Ctrl-C 直接中斷。

**Source**: 2026-07-15 使用者在 CC-489 三方 multi-model synthesis 收斂後，回想起「pmctl executor 相關內容目前沒有停止的行為」並要求確認；經查 `core/policy/dispatch-states.yaml`、`core/schema/run.schema.json`、`runtime/lib/pmctl-dispatch.sh` 確認 `cancelled` 狀態存在於 policy 但無任何實作，`.supervisor.pid` 未被任何子命令消費。使用者明確要求以 `cancel`（而非 `stop`）作為指令名稱，理由是中途終止的 run 不具備可恢復語意。

**Cross-link**: [[CC-470]]（既有逾時止血 kill 機制可沿用）、[[CC-487]]（孤兒 process 殘留的既有觀察案例）、[[CC-489]]（三方 multi-model synthesis 脈絡）、`docs/executor-contract.md`。

## CC-498 — State compatibility surface：status、版本命名、migration registry ✅ 2026-07-20

**Outcome**: Shipped read-only `pmctl state status [--json]` — resolved store
root、observed store layout version vs supported versions、project key、entity
schema versions（live 讀 `core/schema/*.schema.json`）、root safety/writability
與 migration availability；incompatible store 以 exit 3 機械回報，對
future/uninitialized/unreadable store 全程零 mutation。layout/entity 版本命名
切分：`layout.yaml` 改宣告 `store_layout_version`，supported versions 與
declarative migration registry 收斂於 `runtime/lib/state-compat.sh`，writer
version gate 與 status 共用同一來源。writer 的 unsupported-version 錯誤改由
registry 查詢產生 remediation — 不再推薦不存在的 `pmctl state migrate`，改指向
`pmctl state status`。migration engine 依 requirement 4 未展開（無真實 N→N+1
path）。`tests/shell/test-state-status.sh` 17 cases 註冊於兩份 suite registry。

**See**: pr:#435

## CC-499 — Detached run reconciliation：crash、reboot、stale sentinel、orphan recovery ✅ 2026-07-19

**Outcome**: Shipped `pmctl dispatch reconcile <run_id>|--all --cd <work_dir>
[--dry-run]`, reusing [[CC-495]]'s trusted identity/terminal-CAS primitives.
Classifier reads only trusted out-of-repo evidence (identity file, pid file,
runspec, terminal claim) and reports in-flight / terminal-authenticated /
orphaned / process-gone-without-evidence / indeterminate (PID-reuse
suspected); never infers success and never overwrites an existing terminal —
convergence only ever CAS-claims `failed`, and only when process absence is
provable. Added `boot_id=` to the identity file/verify path (detached-launch.sh)
so a reboot short-circuits straight to "gone" instead of risking a
post-reboot starttime coincidence. `doctor.sh` gained a read-only
`check_detached_runs` (dry-run reconcile scan) surfacing stale runs with a
`pmctl dispatch reconcile --all --dry-run` fix hint. Test suite covers
orphaned convergence, dry-run no-write, process-gone-without-evidence,
PID-reuse refusal, in-flight untouched, already-terminal not overwritten,
unknown run fail-closed, `--all` multi-run scan, and the boot_id/reboot
short-circuit.

**See**: pr:#429

## CC-500 — State single-writer boundary enforcement ✅ 2026-07-21

**Outcome**: 將 `core/state/layout.yaml` 的 designated-writer 宣告落實為跨 CLI、runtime、hosts、adapters、ops、tools 與 scripts 的 production-domain content ratchet，可偵測 direct redirect、`jq >`、`mv`、`cp` 與 multiline mutation；豁免只限 canonical writer、pure path resolver、readers 與 layout 宣告的 `rebuildable:true` SQLite cache。Task/decision event rollback 刪除收旂至 `task_delete` / `decision_delete`，統一 ID validation、store compatibility、project partition 解析與 loud failure。Self-injecting fixtures 與 state-store regression 覆蓋合法路徑、違規旁路、invalid ID、init failure 與 removal failure；affected tests 14/14、PR gate GO、rebase 最新 main 後 authoritative full suite 88/88 通過。

**See**: pr:#438

## CC-509 — detached gate launch liveness：sandbox parent-death 與 supervisor readiness ✅ 2026-07-22

**Problem**: `pmctl gate run` 預設 detached，launcher 以 `setsid nohup ... &`
建立 background supervisor 後立即回傳 gate ID；目前只代表 shell 已 fork，沒有
PID identity、readiness handshake 或 supervisor 已成功 exec 的證據。在具
`bwrap --die-with-parent` 的 command sandbox，launcher 結束後 descendants
會被回收，而 `setsid` 只切換 session、不能脫離 parent-death 規則。實測 gate
run directory 僅留下 0-byte `supervisor.log`，無 sentinel、result、trace 或
Claude session；最小 probe 也在 launcher 回傳後連第一行 `started` 都未寫入。

**Why**: 使用者看到「detached」與 gate ID 時，合理期待已存在可等待的 gate。
若 supervisor 未曾啟動卻把 timeout 留給 waiter，會浪費等待時間，並把 host
lifecycle 不相容誤呈現為 executor 或 reviewer 故障。這是 detached launcher
的 truthful-liveness contract，不是 CC-449 release evidence 的範圍。

**Requirement**:
1. detached gate launch 必須在回傳 gate ID 前取得可驗證的 supervisor readiness
   evidence（例如受限時間內的 ready sentinel 與受信任 PID identity）；fork
   success 本身不得視為啟動成功。
2. supervisor 在 exec／參數解析前後的 early exit 必須被 launcher 偵測，回傳
   非零且保留可讀 diagnostic；不得只建立空 run directory 後宣告 detached。
3. 偵測或明確宣告 parent-death sandbox 時，detached lifecycle 必須 fail-loud
   並指向 `--lifecycle foreground`，或採用該 host 保證可跨 command 存活的
   supervised transport；不得依賴 `setsid` 作為逃逸機制。
4. gate wait 對沒有 readiness／terminal evidence 的 run 維持 fail-closed，
   並區分未曾啟動、早期死亡與真正在執行但逾時三種狀態。
5. 測試須涵蓋 launcher process 結束後 descendant 的存活契約，而非只在同一
   parent shell 尚存時等待 child；加入 sandbox-like parent-death probe、early
   supervisor failure、正常 detached run 與 foreground fallback。

**Done-when**: `pmctl gate run` 不會對不存在的 detached supervisor 回傳成功；
操作者可從 machine evidence 判斷 gate 已啟動、已早期失敗或仍在執行，且在
parent-death sandbox 中得到明確可行的 foreground 指引。

**Dependencies**: [[CC-495]] 的 authenticated terminalization 與 [[CC-499]]
的 detached-run reconciliation 可重用；不等待 [[CC-508]] 的 parent-operation
control plane，因為 gate 自身的 launch truthfulness 必須先成立。

**Source**: 2026-07-22 CC-449 Claude gate 實測；foreground Claude gate 已證明
executor/reviewer 本身可正常完成 `Final: GO`，問題限於 detached launch
lifecycle。

**Outcome**: detached gate 現在只有在取得 nonce-authenticated readiness 與受驗證的
supervisor PID/starttime identity 後才回傳 gate ID。supervisor 在 readiness 前死亡、
readiness identity 不符、或 parent-death sandbox 導致早期死亡時皆 fail-loud 並指向
`--lifecycle foreground`；wait 會區分從未 readiness、readiness 後死亡與仍在執行的
真實 timeout。回歸覆蓋 zombie identity、mismatched readiness、invalid readiness timeout
與兩種 fail-closed wait 狀態；Claude gate `Final: GO`。

**See**: pr:#440

---

## CC-510 — Codex detached dispatch continuation ✅ 2026-07-23

**Problem**: detached dispatch 已有 authenticated `dispatch wait`，但 Codex host
的 batch-only 路徑只會在 shell 結束時得到結果；背景 terminal 完成不等於模型會
自動收到新 turn，因而不能可靠地讀取 result 後續作。舊版 Codex client 也可能沒有
background terminal，或無法提供 App Server callback。

**Requirement**:

1. Codex host 以 host-owned waiter 將 `pmctl dispatch wait` 的 exit code 與
   artifact recovery command 封裝成固定 continuation envelope；sentinel 仍是唯一
   authenticated completion source。
2. Codex CLI 預設以同一 waiter foreground 等待；sandbox 不保證可回連 persistent
   App Server control socket。只有明確整合、同時提供 background terminal、thread id
   與 control socket 時，才由 continuation supervisor 在 wait 完成後以 `turn/start`
   將 verified envelope 注入 originating thread，不能用 shell `&` 假裝 detached continuation。
3. timeout 僅允許重試同一 wait 一次；indeterminate、timeout 與 failure 都先讀
   artifacts，絕不自動重派。新嘗試若 host 不能保證 detached child 存活，明確改用
   foreground lifecycle。
4. install 必須升級既有受管理 Codex `AGENTS.md` marker；uninstall 必須只移除
   managed block 並還原使用者原有內容。

**Done-when**: Codex host 可在 App Server callback 可用時自行建立 continuation turn，
且在舊 client 或 sandbox lifecycle 不相容時有可驗證的 foreground fallback；success、
callback rejection、timeout、indeterminate 與 legacy-install rollback 均有直接回歸覆蓋。

**See**: pr:#443

---

## CC-511 — ship publish authorization：current-tree full suite + review closure 🔵 active

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

---

## CC-512 — tier／mode／pass／coverage／independence assurance 正交化 ✅ 2026-07-27

**Problem**: runtime 雖已將 tier detection、reviewer selection 與
`SEQUENTIAL=true|false` 分開，但目前仍有三個 truth gap：

1. `--reviewers` 在沒有 explicit tier 時會把 `TIER` 改成 `targeted`，把 remediation
   delta／review scope 誤分類成 rigor tier；`--targeted` 又只是 `--reviewers` alias，
   無法引用 initial review。
2. `express|standard|full` 實際主要選擇預設 reviewer 清單，文件卻把 `full` 寫成
   parallel + 五 reviewer + 較高 assurance。requested intent、resolved defaults 與
   actual evidence 沒有分開。
3. final Markdown frontmatter 由 reviewer／synthesis session 產生；
   `gate_result_verify` 只驗 `Final:` 唯一性與 frontmatter/body parity，不能證明實際
   mode、selected reviewers、skipped reviewers 或 session independence。

**Assurance coordinates**:

1. **Tier** 是 rigor intent/preset，closed enum 僅
   `express|standard|full`。記錄 `tier.requested: auto|<tier>` 與
   `tier.resolved: <tier>`；tier table 可提供 default reviewers／evidence floor，
   但不得把 default 當 actual coverage 或 policy authorization。
2. **Mode** 只描述 execution topology。記錄
   `mode.requested: default|sequential|parallel` 與
   `mode.resolved: sequential|parallel`；sequential =
   `combined-session`，parallel = `per-reviewer-sessions` + synthesis。
3. **Pass kind** 獨立為 `initial|targeted`。Targeted 是 remediation delta review，
   不是 tier；必須記錄 initial gate result reference 與 inherited／requested
   coverage basis，不能冒充 initial comprehensive review。
4. **Coverage** 分開記錄 requested、selected、skipped reviewer sets；tier defaults、
   CLI override 與實際 dispatch 結果不得互相替代。
5. **Independence** 分開記錄 implementation-context isolation、
   reviewer topology、`per_reviewer_independent` 與 machine-captured session
   evidence/status。缺 evidence 時只能標 `unverified|unavailable`，不能宣稱 verified。

**Requirement**:

1. 建立分離的 portable machine sources（預定
   `core/policy/gate-tiers.tsv`、`core/policy/gate-modes.tsv`、
   `core/policy/gate-pass-kinds.tsv`）；repo-layout runtime 直接讀 source，
   standalone/copy-mode fallback 使用 bounded generated snapshot + freshness ratchet，
   不手寫第二份 policy。三表分別擁有 reviewer defaults／topology／
   initial-reference requirement，
   不建立合併 profile。
2. CLI canonicalize：
   - 新增 `--mode sequential|parallel`；既有 `--parallel`／`--sequential` 為
     compatibility spelling，互相衝突時 fail closed。
   - `--reviewers` 只覆蓋 requested coverage，不再改 tier。
   - `--targeted <reviewers>` 表示 `pass.kind=targeted`，不再只是 alias；必須搭配
     `--initial-result <path>`。Initial-result 的結構存在性在本票驗，subject freshness
     與 applicability 留給 [[CC-515]]。
   - omitted tier/mode/pass 分別記錄為 `auto`、`default`、`initial`；tier 由
     detector resolve，`default` mode 代表未明確選擇並由 [[CC-513]] policy
     recommendation resolve，pass 預設為 initial。
3. Gate shell 在 dispatch 前決定 coordinates，並在 dispatch／wait 時機械擷取實際
   reviewer/synthesis session evidence；reviewer LLM 不得自行宣稱 tier、mode、
   coverage 或 independence。
4. 新 producer 寫 `pr_gate_result_v2` Markdown + `gate_assurance_v1` machine-owned
   JSON sidecar；Markdown只保留human findings與bounded relative pointer。Envelope
   至少含上述五組coordinates、actual reviewer dispatch outcome與evidence status；
   artifact relocation、explicit `--output`、foreground/detached、
   sequential/parallel及copy-mode都須byte-/meaning-parity。
5. 擴充 shared verifier 只判斷本票擁有的
   **structural + claim consistency**：enum、requested/resolved、selected/skipped
   partition、mode/topology/session evidence、pass/initial reference及 Markdown pointer
   parity。Stable repo subject、digest/freshness與 consumer policy applicability仍由
   [[CC-515]]；risk-based floor仍由 [[CC-513]]。
6. `pr_gate_result_v1` 維持 legacy structural verification，但明示
   `assurance: unavailable`，不能被新 consumer 當完整 evidence；新 producer 不再
   產生 v1。不得讓舊 artifact 因缺新欄位被誤報 forged。
7. CLI help、result contract、`docs/review-model.md`、commands、skills與測試引用相同
   machine source或 bounded generated markers；README只保留 pointer。修正既有
   `full => parallel` rigor-tier敘述，但不把本票號寫入 operational docs。

**Delivery slices（同一 ticket；不得提前宣稱完成）**:

1. **A — coordinate sources + CLI resolution（✅ delivered 2026-07-27）**：
   三份 canonical TSV、repo-layout direct load、copy-mode bounded snapshot +
   parity ratchet、canonical `--mode`、targeted initial reference、closed
   invalid/conflicting inputs，以及 dispatch brief 中的 requested/resolved／coverage
   coordinates。`--tier full --reviewers critic` 保留 full intent + critic-only
   selection；新 producer／verifier 尚未交付。
2. **B — machine-owned envelope + evidence capture（✅ delivered 2026-07-27,
   pr:#451）**：sequential combined session、parallel per-reviewer/synthesis sessions、
   targeted initial reference、copy-mode truthful degradation。
3. **C — verifier + remaining parity ratchets（✅ delivered 2026-07-27,
   pr:#451）**：claim consistency、v1 legacy classification、result/help/docs parity、
   affected-test mapping。

**Done-when**:

- `express|standard|full × sequential|parallel × initial|targeted` 的合法矩陣可
  round-trip；targeted fixtures皆帶 initial reference。
- `full+sequential` 不宣稱 parallel、`express+parallel` 不宣稱 full coverage；
  `--tier full --reviewers critic` 可誠實產生「full intent + critic-only actual
  coverage」，是否 policy-sufficient 留給後續 verifier。
- Validator 能抓到 missing/duplicate reviewer partition、targeted 無 initial、
  parallel 無 per-session evidence、combined session 冒充 per-reviewer independent、
  LLM frontmatter與machine envelope不一致、copy-mode冒充 verified，以及v1被誤當新
  assurance。

**Non-goals**: 不在本票決定 sensitive-path／risk-based minimum floor（[[CC-513]]）；
不驗 artifact subject/freshness/publish applicability（[[CC-515]]）；不建立 scope
manifest或finding schema（[[CC-518]]／[[CC-519]]）；不新增 gate kind、workflow
engine、FSM或 mandatory parallel policy。

**Dependencies**: 無 hard implementation dependency；本票先鎖定 coordinates，
[[CC-513]]再產 policy resolution，[[CC-515]]再把 structural evidence 與
subject/freshness/applicability接起來。

**Outcome**: Slices A／B／C 已完成。Gate producer 現在以分離的 portable policy
sources解析 tier、mode、pass、coverage與independence，並產生 machine-owned
assurance sidecar；dispatch outcome、canonical run evidence、result／repository／
subject bindings與protected attestation皆由 runtime 擷取，不再由 reviewer Markdown
自述。Shared verifier會檢查 structural／claim consistency、coverage partition、
mode／topology、targeted initial reference與v1 legacy降級；copy-mode fallback由
shared verifier產生並受parity ratchet保護。Formal full gate為GO且assurance verified，
current-tree authoritative full suite為97 passed、0 failed、0 skipped。

**See**: pr:#451

**Cross-link**: [[CC-513]]、[[CC-515]]、[[CC-518]]、[[CC-519]]、
`docs/review-model.md`。

---

## CC-513 — canonical gate policy resolver ✅ 2026-07-28

**Problem**: sensitive-path regex、brief `architecture_impact`、tier detection、
reviewer defaults、mode suggestions 與 CLI overrides 分散在不同 branches／文件。
Generic gate 需要 risk-based minimum floor；pm-dispatch maintainer `/ship` 又希望
primary review 固定使用完整 reviewer coverage。若把兩種 policy 或 mode 混進 tier，
generic 使用者會被不必要強制，maintainer 路徑則可能漏掉必要 dimensions。

**Requirement**:

1. 建立單一可測 resolver，輸入 diff classification、trusted brief metadata、
   generated/untracked/renamed paths、requested tier/mode/pass/reviewers、repo policy
   與 accepted-risk override；輸出：
   `minimum_tier`、`required_reviewers`、`recommended_mode`、mode selection
   source／recommendation divergence、`downgrade_allowed`、matched signals 與
   override provenance。
2. **Generic `pmctl gate` risk-based floor**：
   - docs-only：critic/qa；
   - bounded runtime：critic/qa，依 matched signal增加 dimensions；
   - auth/credentials/input execution：security；
   - migration/destructive/concurrency/rollback：risk；
   - public API/schema/cross-boundary：architecture；
   - high-risk/major：full reviewer coverage。
   不再宣稱任何 runtime change 一律需要所有 hard-gate reviewers。
3. **Maintainer `/ship` policy**：primary comprehensive review 固定要求 critic、
   qa、architecture、security、risk 全 coverage，因 [[CC-517]] 預設只做一次
   primary discovery；這是 repo-owned recipe，不強迫 generic gate。
4. Mode 與 tier 分離且 mode 為 user-owned：使用者未指定時，resolver 才採用
   `recommended_mode` 自動選擇；明確 sequential／parallel 一律優先，偏離建議只記錄
   selection source 與 divergence，不視為 downgrade，也不要求 policy override。
   `minimum_tier: full` 本身不得強制 parallel。
5. requested tier/reviewer 低於 resolver floor 時 fail closed，除非使用者提供
   scope-bounded accepted-risk override；mode 不屬於 downgrade allowance。
   security/risk hard-gate override 不能由 PM 自行接受。未來 [[CC-065]] repo config
   可加嚴 tier／coverage，不得靜默降低 canonical floor。
6. classification/resolution artifact 列出每個 matched path/field/signal、selected/
   skipped dimensions、mode recommendation／selection source／divergence、downgrade
   reason 與 override provenance；所有 consumer 使用同一 output，不各自複製 regex。

**Done-when**: 每份 gate artifact 都能機械回答「為什麼需要這個 minimum tier／
reviewers、policy 建議哪個 mode、以及最終是 user 或 policy 選擇」；generic 與
maintainer policy 可獨立測試，full 不再隱含或強制 parallel。

**Non-goals**: 不以分類 signal 取代真正 review；不把 architecture reviewer 全域
升為 hard gate；不讓 maintainer recipe 改寫 generic defaults。

**Cross-link**: [[CC-065]]、[[CC-512]]、[[CC-515]]、[[CC-517]]、[[CC-518]]。

**Outcome**: Shipped the canonical gate-policy resolver and versioned policy
registries. Generic and maintainer consumers now resolve minimum tier, required
reviewer coverage, recommended mode, explicit user-mode provenance, matched
signals, and bounded downgrade approval once; the machine-owned assurance
envelope carries and verifies that result across foreground, detached, wait,
and ship paths. Explicit sequential／parallel choice remains user-owned.

**See**: pr:#452

---

## CC-514 — orthogonal delivery assurance map 與 recipes 🔵 active

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
   focused tests→audit→一次 primary comprehensive gate→一次完整 remediation→
   deterministic closure→post-fix affected tests/audit→full→publish；只有
   security/risk、public contract 或跨邊界 remediation 才用既有 `--reviewers`
   做一次 targeted confirmation，不回到 repeat-until-GO loop。generic `pmctl gate`
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

**Done-when**: 一位未讀原始 agents/scripts 的 maintainer 能從 README 找到正確
recipe，並準確判斷每個 assurance dimension 是 pass、未跑、不可用或 stale；跨文件
lint 阻止 tier/mode/full-suite 順序重新漂移。

**Dependencies**: draft skeleton 可先行；runtime-aligned finalization 等
[[CC-511]] Phase B、[[CC-517]]、[[CC-520]]～[[CC-522]]、[[CC-527]]、
[[CC-529]]～[[CC-533]]。排入 v0.12.0 public surface，避免文件先承諾尚未落地的
行為。

**Cross-link**: [[CC-493]]、`commands/ship.md`、`docs/review-model.md`。

---

## CC-515 — immutable subject、freshness 與 applicability verifier ✅ 2026-07-29

**Problem**: preflight tests 已有 repo/base/head/tree evidence，但 final gate artifact
主要依賴 prose `Final:`。外部 consumer 無法分辨 artifact 本身壞掉、subject 已過期，
或 artifact 仍有效但不符合目前 publish policy。此票被 publish、policy、scope
manifest 與 remediation closure 共同依賴，屬 P1 evidence foundation。

**Requirement**:

1. gate artifact 增加 immutable subject/provenance：
   - stable repository key、git common-dir identity、remote identity（若存在）；
   - observed physical/canonical root（只作 provenance，不作唯一 identity）；
   - base ref+commit、head ref+commit、tree fingerprint；
   - `subject_kind: committed_head|working_tree|fixed_ref`、dirty policy、
     created/finished timestamps。
   Worktree path 改變不能單獨讓同一 Git subject 失效。
2. verifier 分開輸出：
   - `artifact_valid`：schema、digest、content parity；
   - `subject_current`：repo/base/head/tree 是否仍符合 current consumer subject；
   - `policy_applicable`：tier/mode/coverage/review/closure evidence 是否滿足 consumer。
   每一軸都有 reason codes；例如 base 前進是 valid artifact 但 stale/not applicable，
   不是 forged/invalid。
3. 提供 shared `pmctl gate verify` path，供 gate wait、ship finish、[[CC-511]]
   publish authorization 與未來 consumer 呼叫；不得各自 grep `Final:` 或自行重做
   repo identity/freshness 邏輯。
4. final artifact 連結 preflight evidence digest/subject、[[CC-512]] resolved tier/
   mode/pass/coverage/independence、[[CC-513]] policy resolution，以及 [[CC-518]]
   scope manifest。
   finalize 前重新計算 working subject；HEAD/tree drift 標 stale，不產生可重用
   current-subject authorization。
5. 覆蓋 result copy/replay、different physical worktree same git subject、different
   repo same path shape、HEAD moved、dirty drift、base advanced、fixed ref、
   malformed digest、valid-but-policy-insufficient 與 valid current result。

**Done-when**: 任一 consumer 可得到結構化 validity/freshness/applicability 三軸結果，
並以 stable repo subject 驗證 artifact；沒有 consumer 再以 `Final: GO` 當作 freshness
或 publish authorization。

**Outcome**：Shipped `gate_assurance_v3`、immutable Git subject、linked preflight
digest，以及 `pmctl gate verify` 的 artifact／subject／policy 三軸 assessment；
gate wait 與 ship finish 都改用同一 shared verifier。Copy/replay、linked worktree、
different repo、base/head/tree drift、fixed ref、digest 與 policy insufficiency
都有直接回歸。Evidence link contract 對 scope manifest／closure 明確支援
`unavailable|verified`，verified link 會驗 basename、digest 與 subject fingerprint。

本票擁有的 verifier foundation 已完整交付。`gate_scope_manifest_v1` 的內容與 producer
仍由 [[CC-518]] 負責；`remediation_closure_v1` 的 lifecycle 與 producer 仍由
[[CC-517]] 負責。兩者是依賴 CC-515 的 downstream evidence，不是 CC-515 的未完成
範圍。

**See**: pr:#454

**Non-goals**: 不以 gate artifact 取代 test result；不把 policy applicable 等同
merge authorization；不要求 worktree path 永久固定。

**Priority**: P1。

**Cross-link**: [[CC-491]]、[[CC-509]]、[[CC-511]]、[[CC-512]]、[[CC-513]]、
[[CC-517]]、[[CC-518]]。

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

## CC-517 — maintainer `/ship` primary review + remediation closure 🔵 active

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

**Non-goals**: 不把此偏好存成 memory-only instruction；不修改 generic gate 的公共
自由度；不保證 LLM 一輪能發現所有可能問題；不新增 workflow engine、FSM 或背景
orchestrator。

**Dependencies**: [[CC-512]]、[[CC-513]]、[[CC-515]]、[[CC-518]]～[[CC-521]]。
P1，排入 v0.11.0 delivery assurance correctness。

**Cross-link**: [[CC-485]]、[[CC-511]]、[[CC-514]]。

---

## CC-518 — gate scope manifest v1 ✅ 2026-07-29

**See**: pr:#455

**Problem**: reviewers 目前主要從 diff list 與個別 prompt 探索 scope；renamed/
untracked paths、paired tests、sensitive signals 與 bounded adjacent context 沒有一份
共同、immutable、可揭露截斷的 manifest。不同 reviewers 可能從不同 scope 起步，
synthesis 也無法判斷「沒 finding」是已看過或根本未收到。

**Requirement**:

1. 直接強化既有 `pmctl gate run`，在 dispatch 前產生 `gate_scope_manifest_v1`；
   不新增 gate command/mode/lifecycle。
2. manifest 連結 [[CC-515]] immutable subject，列出完整 changed/renamed/untracked
   paths、diff hunks、paired tests、[[CC-513]] matched sensitive signals，以及
   public interface/schema/config/install/CI/release/migration flags。
3. bounded adjacent expansion 第一版只承諾可機械推導的 peer/call-site hints與直接
   shared-helper consumers；每個加入項記錄 expansion reason、source與 limits。
   不宣稱完整 call graph。
4. manifest 明列 truncation/budget、omitted counts/reasons 與 content digest；未獲
   明確接受的 truncation 使 operation `INCOMPLETE`，不得靜默縮 scope。
5. sequential/parallel selected reviewers 都收到同一 manifest digest；mode 不影響
   scope contract。

**Done-when**: 任一 gate result 可引用 immutable manifest，證明 selected reviewers
收到相同 declared scope；renamed/untracked、paired-test、sensitive-signal、bounded
expansion 與 truncation 有 deterministic fixtures。

**Non-goals**: 不建立全語言 call graph；不聲稱 manifest 包含所有語意相關檔案；
不把 scope declaration 當 review completeness。

**Dependencies**: [[CC-513]]、[[CC-515]]。P1。

**Cross-link**: [[CC-491]]、[[CC-519]]。

---

## CC-519 — selected-reviewer coverage／finding contract ✅ 2026-07-30

**See**: pr:#456

**Problem**: reviewer prose 沒有一致的 coverage declaration；找到 blocker 後可能
early stop，finding 也常缺少受影響 behavior、fix boundary 與 verification expectation。
「五個 reviewer 各自獨立 session」又錯把 coverage contract 綁到 parallel mode。

**Requirement**:

1. 每個 **selected reviewer** 都完成相同 logical contract，不論 mode：
   sequential 可在 combined session 產生獨立 reviewer sections；parallel 才要求
   per-session isolation evidence。實際 mode/independence 由 [[CC-512]] 記錄。
2. reviewer×surface checklist 每格為
   `examined|not_applicable|uncertain`，附 evidence refs/reason。遇到 blocking
   finding 後仍完成其餘 applicable checklist，不得 early stop。
3. 每個 finding 含 stable ID、reviewer、severity、hard-gate class、source path+
   line/symbol、affected behavior、why it matters、failure mode、minimum fix
   boundary、verification expectation，以及
   `diff_caused|pre_existing|uncertain|caution`。
4. 無 source evidence 的泛泛建議不能升 blocker；`not_applicable`/`uncertain` 不能
   靠沉默表示。Missing/empty/malformed reviewer section 或 checklist 不完整使
   protocol `INCOMPLETE`。
5. schema/contract deterministic tests涵蓋 sequential logical sections、parallel
   session evidence、blocker no-early-stop、missing checklist、invalid stable ID與
   evidence-less blocker。
6. `gate_reviewer_result_v1.verdict` 是唯一 machine verdict；Markdown heading
   只作 human presentation，重複或缺少 heading 不得讓已完成 review 變成格式失敗。
   Shell 必須從已驗證 JSON verdict 機械聚合 GO／NO-GO，並與 final result parity。
7. Current scope manifests carry an immutable reviewer reference index with
   repository path、subject/base snapshot、line count 與 content SHA-256。
   Coverage evidence refs 與 finding source 必須命中該 index；不存在、scope 外或
   超出 snapshot line count 的引用使 protocol `INCOMPLETE`。

**Done-when**: selected reviewer outputs 都是 schema-complete、coverage-declared，
且 finding 可直接作 remediation input；不對未選 reviewer 或模型 recall 作虛假保證。

**Non-goals**: 不要求所有 gate 都選五 reviewers；不以 coverage-declared 宣稱
reviewer 完全理解 scope；不讓 parallel 代替 coverage。

**Dependencies**: [[CC-512]]、[[CC-518]]。P1。

**Cross-link**: [[CC-513]]、[[CC-520]]。

---

## CC-520 — synthesis parity 與 remediation seed ✅ 2026-07-31

**Problem**: synthesis 目前強調 cross-reviewer overlaps與最高 severity，可能在
dedup 時丟失較低 severity finding、test expectation、caution 或 reviewer disagreement。
Primary gate 要支援集中 remediation，必須證明 synthesis 保留所有原始 stable IDs，
而不是宣稱找到了所有真實 defects。

**Requirement**:

1. synthesis 對 selected reviewer findings 做 deterministic ID inventory與 union；
   root-cause grouping可合併呈現，但保留每個 original ID、reviewer dimension、
   verification expectation與 disposition slot。
2. 輸出 reviewer×surface coverage matrix、findings union、root-cause groups、
   disagreements、uncertainties、cautions、not-reviewed dimensions與
   `remediation_closure_v1` seed。
3. consolidated human result固定提供 must-fix順序、advisory/cautions、uncovered/
   uncertain scopes與 recommended verification pointers；使用者無須逐一開 raw
   outputs，但 raw artifact仍可追溯。
4. validator比對 reviewer ID inventory與 synthesis inventory；silent drop、
   duplicate collision、coverage parity mismatch、missing caution/test expectation
   皆 `INCOMPLETE`，不得產生可用 authorization。
5. deterministic fake-artifact tests涵蓋不同 reviewer 同 root cause、同檔不同問題、
   lower-severity preservation、disagreement、dropped ID、duplicate ID與 malformed
   remediation seed。

**Done-when**: synthesis 可機械證明 findings-union-complete與 coverage parity；
remediation seed保留所有 actionable evidence，但不宣稱 defect-complete。

**Non-goals**: 不判定模型 recall；不在本票設計 test-gap schema或 transport retry；
不建立 workflow state。

**Dependencies**: [[CC-519]]。P1。

**Cross-link**: [[CC-517]]、[[CC-521]]。

**Outcome**: Selected-reviewer Gate results now emit `pr_gate_result_v4` with one
`gate_synthesis_result_v1` block. The verifier mechanically proves the complete
stable-ID inventory/findings union, coverage matrix, root-cause grouping,
uncertainties/cautions, and pending remediation seed against the authoritative
reviewer JSON. Silent drops, duplicate IDs, coverage drift, and malformed
verification expectations or seeds fail closed as `INCOMPLETE`.

**See**: pr:#460

---

## CC-521 — test-gap matrix、protocol recovery 與 live evaluation 分層 🔵 active

**Problem**: 「請補測試」缺少 layer/scenario/oracle/failure signal，無法一次修正；
同時 transport/schema recovery 與模型能否找出 seeded defects 是不同性質。前者可
deterministic fail closed，後者具模型波動，不應混成 CI hard gate。

**Requirement**:

1. qa-tester及發現 behavior gap 的 reviewer輸出 test-gap matrix：affected behavior/
   contract、existing evidence、missing layer、scenario、oracle、failure signal、
   suggested command。依適用性涵蓋 happy/boundary/negative/regression及 concurrency/
   security/migration/rollback；足夠時以 `no_gap` + evidence 明示。
2. consolidated result呈現 test coverage to add/strengthen、operational/user cautions
   與修正後 focused/manual/full verification plan；[[CC-520]] parity不得丟失矩陣列。
3. bounded in-operation recovery只處理 transport failure、malformed output、
   schema failure與 synthesis parity failure；只重試失敗 reviewer/synthesis，保留
   immutable subject與有效 outputs並記錄 attempts。Subject drift標 stale，analysis
   uncertainty保留，不以 retry掩蓋。
4. deterministic CI contract tests使用 fake artifacts驗 missing matrix field、
   malformed result、truncation、wrong subject、dropped row、retry success/exhaustion。
5. seeded multi-defect/multi-test-gap fixtures作 **live model evaluation**，報 recall、
   variance與 regression observation；不作一般 deterministic CI hard PASS，也不
   宣稱一次 review 找完所有 defects。

**Done-when**: protocol/schema/recovery 有穩定 CI contract；使用者可從一次 gate取得
具體補測與驗證方向；live recall品質另有可觀察 benchmark，不污染 correctness gate。

**Non-goals**: 不把模型 recall 當 deterministic invariant；不因 uncertainty自動重試；
不新增另一套 gate。

**Dependencies**: [[CC-518]]、[[CC-519]]、[[CC-520]]。P2。

**Cross-link**: [[CC-470]]、[[CC-481]]、[[CC-491]]、[[CC-517]]。

---

## CC-522 — `--test-cmd` execution outcome 與 evidence capability 分層 🔵 active

**Framing**: 本票強化既有 `pmctl gate run --test-cmd` pre-flight 與 qa-tester
對測試執行證據的解讀，不重寫 gate 流程。任意可執行 shell command 永遠是合法輸入；
structured result 是 opt-in capability，不是導入 gate 前必須先改造各 repo runner 的
門檻。本票保留 [[CC-491]] 的 portable opaque evidence 與 structured reusable
evidence 分工；tier／mode／pass／coverage／independence 仍由 [[CC-512]] 擁有，
subject freshness／consumer applicability 仍由 [[CC-515]] 擁有，test-gap內容仍由
[[CC-521]] 擁有。禁止新增 gate kind、workflow engine、強制 runner migration，
或以 stdout/stderr 關鍵字猜測 assertion／環境失敗。

**Problem**: `--test-cmd` 可能是任意 legacy command，未必產生建議的 structured
result；即使 command 有執行，也可能因 reviewer sandbox、依賴、網路、資源限制或
timeout 非零退出，而同一 tree 在外部環境可正常通過。目前 pre-flight 雖能保存
opaque evidence 並在內部辨識 timeout／stale／invalid，最後仍把所有非 PASS 合併成
一般 test FAIL／NO-GO；qa-tester 也把 non-runnable／flaky 一律視為 block。這會把
「沒有可用 authorization evidence」誤寫成「diff 已證明有 defect」，同時迫使使用者
為了避免 false block 先投入 runner 格式改造。

**Requirement**:

1. capability negotiation 必須是漸進式：
   - command 未寫 structured sink 時，接受 portable opaque evidence；
   - command 寫出 schema-valid result 時，提升為 structured evidence；
   - command 有寫 sink 但內容 malformed／subject 不符時標 `invalid-evidence`，
     不得靜默降級 opaque。
2. machine outcome 分開記錄 command execution、test verdict、evidence richness 與
   authorization applicability。closed execution classification 至少涵蓋
   `pass|test-fail|timeout|environment-error|stale|invalid-evidence|
   unclassified-nonzero`；opaque 非零不得靠 log heuristic 自動宣稱 `test-fail`。
3. 只有 subject-valid structured assertion/test failure 可產生機械 test NO-GO。
   `timeout|environment-error|unclassified-nonzero` 使 operation
   `INCOMPLETE/non-authorizing`，保留 command digest、exit、timeout、log digest、
   tree fingerprint與 recovery instructions，但不得冒充 diff-caused reviewer
   blocker。Opaque PASS 只證明該 command 對該 subject exit 0，不宣稱 suite coverage
   完整或可作 no-duplicate reuse。
4. qa-tester output 增加 `inconclusive` run result、failure class 與 evidence refs。
   已有 outer pre-flight PASS 時不得反射性重跑 full suite，只能追加 scope-bounded
   targeted checks；reviewer sandbox 的 timeout／environment failure回報
   inconclusive，只有可歸因 assertion failure、diff-caused coverage gap或測試
   anti-pattern 可 block。
5. qa-tester 在執行任何可能耗時的自主測試前，必須先寫入並 flush early
   checkpoint，至少含已完成 matrix/audit、預定 command、開始時間、timeout budget、
   evidence refs 與 `run.status: running`。測試必須經 bounded shell-owned wrapper
   執行，持續保存 stdout/stderr log、process exit／timeout 與最後可觀察進度；
   reviewer session被外層 watchdog終止時，gate仍機械產生
   `partial/inconclusive` artifact，列出完成／未完成 sections、checkpoint與 log
   pointer。不得只依賴模型在 command 返回後才首次寫檔，也不得讓 timeout留下
   0-byte／無結果。
6. sequential combined session與parallel reviewer session都必須保留上述 qa
   checkpoint/result；partial qa artifact不是有效 reviewer verdict，synthesis不得
   將它補寫成 pass／block或納入正常 findings union，operation只能
   `INCOMPLETE/non-authorizing`。若模型在 checkpoint 前違規直接執行長測試，wrapper
   仍須留下 shell-owned attempt/log evidence並明示 `checkpoint: missing`。
7. 外部執行 evidence recovery 必須驗證同一 repository subject、HEAD/tree
   fingerprint、command digest、suite identity與 artifact integrity；符合
   [[CC-515]] freshness/applicability 才能取代 inconclusive。口頭／純 log PASS
   可作 manual clue，不得單獨授權 GO。不得自動重跑或提高 timeout 掩蓋 performance
   regression；重跑由使用者明示或 policy-bounded recovery 觸發並記錄 attempts。
8. human result 明確區分 `code/test NO-GO`、`gate INCOMPLETE` 與
   `evidence unavailable`，提供可複製的 same-command／adjusted-timeout／external
   evidence recovery 指令，不要求使用者先採用 structured producer。
9. deterministic fixtures 覆蓋：opaque PASS、opaque nonzero、structured PASS／
   test-fail、sink missing、sink malformed、timeout、environment error、tree drift、
   external evidence subject match/mismatch、qa targeted failure、timeout 前已寫
   checkpoint、checkpoint 前違規執行仍有 shell log、sequential／parallel partial
   preservation，以及不得把 inconclusive轉成 blocker或 GO。

**Done-when**: 任意 legacy `--test-cmd` 不需格式改造即可得到 truthful opaque
evidence；structured producer可獲得更強 reuse/coverage 語意；環境／timeout失敗會
fail closed 但不誤報產品 defect；qa-tester與 gate artifact對同一 execution class
給出一致、可恢復的結論；qa自主測試即使 timeout 也必有非空 checkpoint、attempt
metadata與 log pointer。

**Non-goals**: 不保證任意 command 可自動判斷失敗根因；不解析自由文字 log 作
authorization；不降低 current-tree test evidence要求；不讓 external PASS 省略
subject/digest驗證；不在本票建立通用 CI provider integration。

**Dependencies**: outcome/capability Phase A 複用 [[CC-470]]／[[CC-491]] 可先行；
external reusable evidence Phase B 依賴 [[CC-515]]。與 [[CC-521]] 的 test-gap／
protocol recovery contract保持正交。P1。

**Cross-link**: [[CC-470]]、[[CC-491]]、[[CC-512]]、[[CC-515]]、[[CC-521]]。

---

## CC-523 — gate cancel 終止 pre-review foreground producer work ✅ 2026-07-28

**Framing**: 本票是 [[CC-508]] parent-operation cancellation 契約的 regression
closure，不重做 operation control plane、`pmctl dispatch cancel` 或 gate workflow。
範圍限於 gate 已建立 parent operation、但尚未派發第一個 reviewer child 時仍由
producer 擁有的執行工作；foreground preflight 是必須通過的原始重現，detached
lifecycle 若共用同一 pre-review seam 也不得保留分歧。允許加入最小、可重用的
producer execution identity／cancellation metadata，但不建立泛用 job-control
framework，也不接受使用者提供的裸 PID。

**Problem**: 現行 `pmctl_operation_cancel` 只遍歷 parent record 已記錄的 child
dispatch runs。foreground `pmctl gate run` 在 reviewer 派發前會同步執行
`--test-cmd` preflight；此時 operation 已存在但 `children.jsonl` 仍為空。
`pmctl gate cancel <operation-id>` 因而可把 operation 直接寫成 `cancelled`，卻沒有
停止仍在執行的 `pr-gate.sh`、`timeout` wrapper 或測試 process tree。2026-07-27
實際操作已觀察到 cancel 回報後 foreground preflight 仍持續執行。這使 durable
state 與真實 liveness 互相矛盾，也可能讓已取消 producer 繼續寫 artifact、晚到
派發 reviewer，違反 [[CC-508]]「任一 in-flight producer 可驗證取消且無孤兒」的
Done-when。

**Requirement**:

1. gate 必須在進入任何 pre-review 工作前，發布與 operation ID、canonical
   repository／workdir 綁定的 producer execution identity；若以 PID／process
   group 表示，必須含 starttime 或等價 anti-reuse evidence，並由 producer 自行
   寫入 trusted state，cancel caller 不得注入任意 PID。
2. `pmctl gate cancel` 遇到尚無 reviewer child、但 producer／preflight 仍 live
   的 operation 時，必須先要求 producer 停止並終止該次 preflight 的完整 process
   tree；沿用 bounded grace 後 escalation 的取消語意。只有確認 producer 與其
   owned descendants 已停止後才能寫 `cancelled`；identity mismatch、無法確認
   termination 或部分停止一律收斂為 `indeterminate`／非零。
3. gate producer 必須在 preflight 完成後、每次 reviewer dispatch 前與
   finalization 前檢查 durable cancellation intent。cancel 已勝出的 operation
   不得再派發 child、不得以 late GO／NO-GO／failed 覆寫 `cancelled`，也不得把
   cancelled preflight 誤報成程式碼 test failure。
4. foreground caller 必須以明確非成功狀態返回，並輸出 operation ID、取消結果與
   可查 evidence；若 detached gate 在同一階段被取消，supervisor、sentinel 與
   wait 結論必須使用相同 terminal semantics，不得只殺 child 或只改 state。
5. 已派發 reviewer 後的既有 child ownership／`pmctl dispatch cancel` 路徑、
   foreign-project 拒絕、cancel-vs-complete 單一終態與 reconcile 規則必須保持；
   producer cancellation primitive 應為窄 API，不在 gate／ship 各自複製未驗證的
   signal 邏輯。
6. deterministic regression 使用 FIFO／readiness handshake 啟動會阻塞的
   foreground preflight，從另一 process 執行 `pmctl gate cancel`，驗證 bounded
   return、preflight 與 descendants 全部死亡、operation 為 `cancelled`、零
   reviewer dispatch、零 late artifact overwrite。另覆蓋 cancel/finish race、
   PID reuse／identity mismatch、重複 cancel、preflight 已退出與 termination
   失敗轉 `indeterminate`；禁止以裸 sleep 猜時序。

**Done-when**: 對 reviewer 派發前仍在執行的 foreground gate operation 執行
`pmctl gate cancel <operation-id>` 後，cancel 只有在 producer-owned preflight
process tree 已可驗證停止時才回報 `cancelled`；原 foreground caller bounded
返回、沒有 reviewer child 或孤兒程序、沒有 late terminal overwrite，且
foreground／detached 共用一致的 cancellation terminal contract。

**Non-goals**: 不重寫 preflight evidence classification（→ [[CC-522]]）；不擴張
為任意 shell job manager；不允許 PID-only cancellation；不變更使用者未要求的
timeout 預設。

**Dependencies**: regression boundary 直接承接 [[CC-508]]，並複用 [[CC-495]]
dispatch cancellation 與 [[CC-509]] supervisor identity／liveness evidence。P1，
應先於下一次依賴 foreground gate cancellation 的 maintainer delivery 處理。

**Outcome**: Gate parent operations now persist verified producer process
identity before pre-review work. Cancellation stops and reaps the foreground
preflight or detached supervisor process tree before terminalizing the
operation, preserves indeterminate on unverifiable termination, and prevents
late reviewer dispatch or terminal overwrite.

**See**: pr:#453

---

## CC-524 — artifacts show canonical absolute run root 🔵 active

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

---

## CC-525 — generated verifier fallback provenance path ratchet 🔵 active

**Framing**: 本票是 copy-mode 維護資訊的窄幅清理，不改 verifier 行為、gate
verdict 或 bundle layout。`runtime/bin/pr-gate.sh` 的 inline fallback 仍由唯一既有
generator 管理；修正與 ratchet 應併入後續小型 maintenance change。

**Problem**: inline fallback 的 generated block 註解目前宣稱由不存在的
`scripts/sync-gate-result-verifier-fallback.sh` 產生，實際 canonical generator
是 `tools/generate-gate-result-verifier-fallback.sh`。現有 `--check` 能驗證內容
parity，卻沒有驗證 provenance 指向可執行、存在且唯一的 generator；維護者依註解
操作時會走到錯誤 recovery path。

**Requirement**:

1. generated block 的 provenance 必須指向 repo 內實際 canonical generator，
   路徑可由 repository root 穩定解析，且文件與測試不得另宣告第二個同步工具。
2. 擴充既有 generator `--check` 或相鄰 contract test，同時驗證 marker、generated
   body parity 與 provenance path；不存在、不可執行或漂移到非 canonical 路徑時
   必須 fail-loud。
3. copy-mode standalone fallback、repo-layout shared verifier 與現有 ShellCheck
   source annotation 均保持；註解修正不得手動改寫 generated verifier body。

**Done-when**: 維護者可直接依 inline 註解執行實際 generator；CI 在 provenance
再次指向不存在或非 canonical 工具時失敗，而目前 verifier parity 與 copy-mode
行為完全不變。

**Non-goals**: 不新增 generator；不改 verdict parser、artifact schema 或 fallback
內容；不把 generator 搬到另一個目錄；不併入 [[CC-513]] 的 policy resolver。

**Dependencies**: 延伸 [[CC-512]] 的 shared verifier／fallback parity seam，與
[[CC-513]] 僅共享發現時點、沒有交付依賴。P3，適合後續小型 maintenance PR。

---

## CC-526 — reviewer override symlink trust-boundary hardening 🔵 active

**Framing**: 本票只處理 free-form reviewer override channel
（auto-discovered `.gate-overrides.md` 與 explicit `--override-file`）的檔案信任
邊界。它與 [[CC-513]] 的 machine-validated policy override 是不同輸入面；因為
拒絕 symlink 會改變既有信任／相容行為，必須獨立交付並明確測試。

**Problem**: reviewer override 目前只以 `-f` 接受檔案，再 canonicalize parent
並讀取內容；symlink 指向 regular target 仍會通過。workspace 內的
`.gate-overrides.md` 或 explicit path 因此可把 reviewer prompt content
重新導向其他位置，而現有 provenance 只記錄 symlink lexical path 與 target
content hash，沒有把這項 redirect semantics 當成可見的 trust decision。

**Requirement**:

1. auto-discovered 與 explicit reviewer override 必須使用同一窄 validator，只接受
   readable、non-empty、regular、non-symlink file；拒絕訊息需指出輸入與違反的
   contract，且在任何 reviewer dispatch／brief injection 前 fail-closed。
2. validation、canonical path、讀取與 sha256 provenance 的順序必須避免
   check/use 間把 symlink 或 target 換入；若 shell primitive 無法提供原子 open，
   必須以可驗證 identity／content stability check 收斂，而非只增加一次 `-L`。
3. regular file 的 auto-discovery、relative explicit path、含空白路徑、content
   injection 與 provenance 行為保持相容；若 empty／unreadable file 原先可用而
   新契約改為拒絕，需在 CLI／review docs 明示 migration。
4. deterministic regression 覆蓋 auto 與 explicit symlink、absolute／relative
   external target、dangling link、empty／unreadable file、正常檔案及 validation
   後置換情境；測試必須證明被拒內容不會出現在 reviewer brief 或 result
   provenance。

**Done-when**: symlink 或 validation 後遭置換的 reviewer override 無法影響任何
reviewer brief；regular override 的既有使用方式維持，新的拒絕行為有契約測試與
相容性說明。

**Non-goals**: 不重新設計 accepted-risk 語法；不把 reviewer override 升格為
policy downgrade；不宣稱防禦具有同一 OS 帳號寫入權限的攻擊者；不順帶修改
[[CC-513]] policy override validation。

**Dependencies**: 與 [[CC-513]] 的 policy override trust boundary 保持正交，並
可參考 [[CC-258]] 的 symlink-safe install contract，但不得假設 realpath-only
即足夠。P2，需獨立 review 與 compatibility evidence。

---

## CC-527 — targeted gate CLI coordinate separation 與 truthful labeling 🔵 active

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

**Requirement**:

1. 定義 canonical explicit form，設計目標為
   `--pass targeted --reviewers qa-tester --initial-result <path>`；pass kind、
   coverage 與 initial-result 必須各自驗證。既有 `--targeted <reviewers>` 保留為
   compatibility shorthand，且必須機械展開為完全相同的 coordinates，不能形成
   第二條 resolver path。
2. Targeted tier resolution 必須有單一、可解釋的 basis：未明確指定 tier 時，優先
   繼承 subject-applicable initial result 的 resolved tier；若 initial artifact
   無法提供可信 tier，必須使用 canonical policy resolution 或 fail closed，不得從
   targeted reviewer 數量反推 tier。這項 inheritance/applicability 接線依賴
   [[CC-515]]，不可用未驗證 frontmatter prose 代替。
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
   explicit full-tier + QA-only coverage 的 truthful labeling、tier inheritance、
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

---

## CC-528 — publish policy compatibility：generic baseline + maintainer preferred ✅ 2026-07-30

**See**: pr:#457

**Problem**: `generic` 與 `maintainer` 是 Gate consumer policy，不是權限或身分；
但 shared verifier 目前以 policy 名稱完全相等判斷 applicability，並把 `publish`
直接映射成 `maintainer`。結果是 valid/current 的 generic GO 被標成
`consumer_policy_mismatch`，即使它已通過完整 diff classification、risk signals、
minimum tier、required reviewer coverage 與 dispatch evidence。`pmctl ship finish`
又只能重新執行 maintainer Gate，無法驗證呼叫者已有的 current-tree generic GO，
把「maintainer 是較佳發布保證」誤作「maintainer 是唯一可接受身分」。

**Requirement**:

1. 定義 policy compatibility：`generic` 是最低可接受 baseline，`maintainer` 是其
   stronger policy；explicit `maintainer` consumer 仍嚴格要求 maintainer，
   `generic` consumer 可接受 generic 或 maintainer，`publish` consumer 接受兩者並
   以 maintainer 為 preferred。`embedded` consumer 繼續驗 artifact 自己宣告的 policy。
2. `policy_applicable` 除 required／embedded policy 外，必須輸出
   `preferred_policy` 與 `policy_satisfaction: baseline|preferred`。未達 preferred
   只能降為 baseline 訊號，不得讓 applicability fail；低於 required minimum 才以
   穩定 reason code fail。
3. `pmctl ship finish` 預設仍執行 maintainer policy；新增明確
   `--gate-result <artifact>` 讓 caller 沿用既有 initial result。Supplied artifact
   必須以 publish consumer 通過 artifact validity、current subject、policy
   applicability、canonical dispatch authorization 與 scope evidence；targeted
   artifact 在 [[CC-517]] closure path 交付前不得單獨授權 publish，且所有 result
   仍受 gate 前後
   HEAD／dirty guards 與 current-tree authoritative full-suite 約束。
4. `publish` 的 direct current-tree review path 不要求 remediation closure；這是
   [[CC-511]] 已決定的第一種 review authorization。Primary review 經 remediation
   後以 closure 授權 final tree 的第二條 path 仍由 [[CC-517]]／CC-511 Phase B
   實作，本票不得假裝已交付。
5. CLI 必須拒絕 `--gate-result` 與只對新 Gate 有意義的 `--reviewers` 混用；relative
   artifact path 以 `--cd` worktree 為基準。不得自動掃描或猜測 latest result。
6. 回歸覆蓋 generic→generic、maintainer→generic、generic→maintainer、
   generic→publish baseline、maintainer→publish preferred，以及 supplied
   valid／stale／invalid Gate result 對 ship publish boundary 的行為。

**Done-when**: valid/current generic GO 可作 publish baseline，maintainer GO 以
machine-readable preferred 狀態呈現；explicit maintainer verification 仍不接受
generic；`ship finish --gate-result` 可沿用指定 artifact 且不放寬其他發布軸。

**Non-goals**: 不降低 generic risk-based floor；不改 maintainer initial 五 reviewer
coverage或 mode recommendation；不實作 remediation ledger／targeted confirmation；
不自動選擇 result；不把 Gate GO、full-suite PASS、publish authorization 或 merge
authorization重新合併成單一座標。

**Dependencies**: 延伸 [[CC-513]] policy resolver、[[CC-515]] shared verifier與
[[CC-518]] scope manifest；是 [[CC-517]]／CC-511 Phase B 前的 policy compatibility
clarification。P1，排入 v0.11.0 delivery assurance correctness。

**Cross-link**: [[CC-511]]、[[CC-513]]、[[CC-515]]、[[CC-517]]、[[CC-518]]、
[[CC-529]]。

---

## CC-529 — publish assurance observability：baseline／preferred 可追溯 🔵 active

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

**Done-when**: 任一成功 ship publication 都能只靠 stdout、PR body 或 finish
marker 回答 embedded producer policy 與 publish satisfaction，三者與 shared
verifier 完全一致；舊 marker 保持可讀，help synopsis 與 parser contract 有回歸
鎖定。

**Non-goals**: 不改 generic／maintainer reviewer floor、tier、mode 或 compatibility
ordering；不新增 Gate、publish authorization 或 workflow engine；不實作 dashboard、
scheduled audit 或歷史 marker backfill；不把 [[CC-517]] remediation closure 併入。

**Dependencies**: 延伸 [[CC-528]] policy compatibility 與 [[CC-515]] shared
verifier，沿用 [[CC-511]] publish marker／PR boundary。P2，排入 v0.11.0 delivery
assurance observability。

**Cross-link**: [[CC-511]]、[[CC-513]]、[[CC-515]]、[[CC-517]]、[[CC-528]]。

---

## CC-530 — source-safe runtime libraries + unified identifier policy 🔵 active

**Problem**: `runtime/lib/portable.sh` 在被 source 時直接修改 strict-mode flags，
consumer 因此必須自行保存與還原 caller state；同時 Adapter 等 domain identifier
在 enum、filesystem、router 與 dispatch resolver 使用不同 regex，合法名稱會隨入口
改變。這兩種隱藏差異會阻礙 Gate module、Adapter manifest 與 CLI lazy-loading
後續重用。

**Why**: Sourceable library 應只提供 callable behavior，identifier policy 則應有
單一 ownership。若基礎 library 會改變 shell 狀態、各 consumer 又自行定義名稱，
後續每次抽 module 都會複製 bootstrap 與 compatibility 邏輯，且安全檢查無法證明
所有入口一致。

**Requirement**:

1. 定義並機械驗證 `runtime/lib/*.sh` source contract：source 階段不得改變 shell
   flags、cwd、global trap，不得寫檔、spawn process 或直接 `exit`；strict mode 與
   lifecycle ownership 留在 `runtime/bin/*`、`cli/pmctl` 與 executable Adapter。
2. 移除 `portable.sh` 的 caller-state side effect，清理 consumer 的 flag
   save/restore workaround；既有 callable behavior 與 executable error contract
   保持。
3. 建立 centralized identifier policy，明確列出 Adapter、Host、run、operation
   等 domain 的 canonical grammar；允許 domain 間有不同規則，但同一 domain 的
   enum、manifest、filesystem、router 與 resolver 必須共用同一 validator。
4. Source-safety fixtures 在不同 errexit/nounset/pipefail 組合下驗 flags、cwd、
   files、traps 與 process side effects；identifier conformance fixtures 覆蓋所有
   production entrypoints 與 boundary values。

---

## CC-531 — Adapter manifest dispatch entrypoint contract closure 🔵 active

**Problem**: Built-in manifests 宣告 `runner_ref: ./dispatch.sh`，generator 卻產生
`./run.sh`；實際 dispatch runtime 又不讀該欄位，而是硬編碼
`adapters/<adapter>/dispatch.sh`。Manifest 看似是 source of truth，實際不具
load-bearing authority，新增或改名 entrypoint 仍需修改 core runtime。

**Why**: v0.12.0 若要把 `adapter.yaml` 列為 public contract，必須先讓 manifest
真正控制 runtime resolution。否則文件、generator 與執行路徑會形成三份互相矛盾
的 authority，custom Adapter 無法只靠自己的 manifest 接入。

**Requirement**:

1. 定義語意明確的 canonical dispatch entrypoint 欄位；`runner_ref` 的遷移、
   deprecated alias 或拒絕策略必須明文且有 compatibility fixtures，generator 與
   built-in manifests 同步。
2. 所有 Adapter enum、dispatch、executor routing 與 validation path 都透過同一
   manifest reader 解析 entrypoint，不再固定尋找 `dispatch.sh`；名稱驗證共用
   [[CC-530]] identifier policy。
3. Entrypoint 必須是 Adapter 目錄內的 safe relative path；拒絕 absolute path、
   `..` escaping、symlink escaping、missing/non-executable target 與不合法
   `runner_kind` 組合。
4. Conformance suite 證明將某 Adapter 的 entrypoint 改成 `./worker.sh` 後只改
   manifest 即可 dispatch，無須修改 `pmctl-dispatch.sh`、executor router 或其他
   shared runtime。

---

## CC-532 — Gate canonical modules + generated standalone distribution 🔵 active

**Problem**: `runtime/bin/pr-gate.sh` 同時承擔 option parsing、policy、subject、
scope、reviewer contract、synthesis、assurance、publication 與 copy-mode fallback，
canonical authoring source已接近 6,500 行。Portability 所需 generated snapshot
與正常 repo-layout 邏輯混在同一檔，讓每次 contract 變更都擴大 review 與 regression
surface。

**Why**: Gate 已是專案複雜度中心，但 copy-mode standalone portability 仍是必要
產品能力。Canonical modules 與 generated distribution 分離後，才能在不增加 runtime
dependency、不改使用者安裝模式的前提下，讓 domain ownership、測試隔離與 code
review 回到可維護範圍。

**Requirement**:

1. 依 domain 抽出 source-safe canonical modules，至少涵蓋 options、policy、
   subject、scope、reviewer contract 與 assurance；`runtime/bin/pr-gate.sh`
   成為 repo-layout composition root，首批搬移只做 behavior-preserving migration。
2. Standalone copy-mode 由唯一 build tool 產生 distribution bundle；generated
   policy/verifier fallback 不再作為日常 canonical authoring source，並延續
   [[CC-525]] 的 provenance 與 stale check。
3. Symlink/repo-layout 安裝 canonical entrypoint，copy-mode 安裝 generated
   distribution；兩者維持相同 prerequisite 與 runtime dependency。
4. CI 的 build `--check` 拒絕 stale bundle；同一組 fixtures 比對 canonical/dist
   的 stdout、stderr、exit code 與 artifacts，並覆蓋 copy-mode 無 repo-layout
   dependency 的真實執行。

---

## CC-533 — schema-derived Gate structural validator 🔵 active

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

## CC-536 — Adapter SDK lifecycle／manifest／trace expansion 🟢 someday

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

## CC-538 — Host resolver／doctor shared primitives 🟢 someday

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

## CC-540 — `pmctl state prune`：刪除前摘要抽取＋驗證，避免歷史分析資料隨磁碟空間消失 🟢 someday

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

---

## CC-541 — codex reviewer sandbox 讀不到主機上已存在的 `QA_RULES_DIR` 🔵 active

**Problem**：`agents/qa-tester.md` 規定 qa-tester 必須以
`${QA_RULES_DIR:-<repos-root>/qa-testing-rules}/AGENT.md` 作為 Tier 1 規則
來源，缺席時「stop and ask the caller」。2026-08-04 針對 CC-522 timeout／
scope-manifest 修復的 `pmctl gate run --executor codex --mode sequential`
實測：該路徑（`/home/screenleon/github/qa-testing-rules`）在主機上確實
存在，但派發給 codex reviewer 子行程的 sandbox 回報找不到，qa-tester 因而
對整份 diff 判 `block`（`hard_gate_class: hard_block`），即使它列出需要
補跑驗證的三個測試檔（`test-test-harness.sh`、`test-run-tests.sh`、
`test-core-schemas.sh`）在主線程都已個別跑過且全過。此案已用
`.gate-overrides.md` accepted-risk 走使用者已授權的 override 流程放行，
非本票範圍；本票是後續調查與根治。

**Why**：目前無法區分兩種情況——(a) `QA_RULES_DIR` 真的在此機器上不存在
（[[CC-447]] item 5 涵蓋的乾淨機器情境），(b) 目錄存在但 reviewer 執行環境
的 sandbox／`--cd` 邊界看不到它（本票情境）。兩者的正確修復方向完全不同：
(a) 需要 qa-tester fail-loud 提示使用者安裝／設定，(b) 需要 dispatch 層把
`QA_RULES_DIR` 顯式傳入 reviewer sandbox 的可讀路徑，而不是依賴 reviewer
子行程自行從檔案系統相對路徑猜測。目前 qa-tester 的 hard block 對兩種情況
一視同仁，讓「路徑存在但沙盒隔離」的可修復狀況也變成整份 gate 的
`Final: NO-GO`，且沒有任何診斷區分兩者。

**Requirement**：
1. 先重現並定案 fail-loud 分類：在 codex `--executor codex` 的 reviewer
   dispatch 路徑，確認 `QA_RULES_DIR`／`PM_DISPATCH_REPOS_ROOT`／
   `PM_DISPATCH_REPO` 是否有傳入子行程環境；若有傳入但 sandbox
   （`workspace-write`／`read-only`／`sandboxed`）仍阻擋讀取 repos-root
   之外的路徑，記錄實際 sandbox 邊界規則來源（codex CLI 的
   `--sandbox` 語意）。
2. 依 1. 的結論二選一或並行：(a) dispatch 層在建立 reviewer brief／sandbox
   前，將已解析的 `QA_RULES_DIR` 內容（或其 Tier 1 entry point 檔案）複製
   或顯式掛載進 reviewer 可讀的 workspace 快照內，讓 sandbox 邊界不再是
   讀取障礙；或 (b) 若 sandbox 設計上刻意不允許讀取 repos-root 之外任何
   路徑，qa-tester 的錯誤訊息與 gate 結果必須清楚標示「規則來源存在但
   sandbox 拒絕讀取」，不得與「規則來源真的不存在」共用同一段訊息／同一個
   `uncertain` coverage reason，避免使用者誤判成需要另外安裝
   qa-testing-rules。
3. 與 [[CC-447]] item 5（乾淨機器缺 checkout 的行為驗證）交叉驗證：兩個
   情境（缺席 vs. 存在但不可讀）都要各自有一次可重現的實測記錄。
4. 新增回歸測試：至少一個 fixture 模擬「`QA_RULES_DIR` 在呼叫端環境存在，
   但 reviewer dispatch 的 sandbox 看不到」，斷言 gate 產出的訊息／
   coverage reason 明確區分於「完全缺席」情境。

**Done-when**：codex reviewer sandbox 對已存在的 `QA_RULES_DIR` 要嘛能正常
讀到（(a) 修復），要嘛在無法讀到時給出與「規則來源缺席」明確不同的診斷
訊息（(b) 修復）；有回歸測試鎖住兩種情境的區分；與 [[CC-447]] item 5 的
「缺席」情境分別留下可重現證據。

**Non-goals**：不重新設計 qa-tester 的 override 政策本身（沿用
`agents/qa-tester.md` §Override policy 既有的「red-line block 不可
PM-overridable、需使用者明確接受」規則）；不改變 codex sandbox 的整體
isolation 分級語意（`core/policy/isolation-level.yaml`）。

**Dependencies**：與 [[CC-447]] item 5 協調但不合票（範圍不同：本票是
sandbox 可見性，CC-447 item 5 是乾淨機器缺 checkout）。P2。

**Source**：2026-08-04 針對 [[CC-522]] timeout／scope-manifest 修復的 gate
round 實測（gate-20260804-055257-17cd44，qa-tester-F001 block）；使用者
核准以 `.gate-overrides.md` accepted-risk 放行本輪，並要求另開票追蹤根治。

---

## CC-542 — 移除 test-pmctl-context／test-release-verify 的 live-DB 全域互斥 🔵 active

**Problem**：`tests/lib/test-suite-runner.sh` 的 `LIVE_DB_EXCLUSIVE` 把
`test-pmctl-context` 與 `test-release-verify` 標記為互斥：兩者都會碰
`$REPO_ROOT/.pm-dispatch/ctx/context.db`——`test-pmctl-context` 斷言這個
DB 在測試期間不能被改動，`test-release-verify` 則因為執行
`release-verify.sh` Phase 3（對**這個 repo 本身**跑
`pmctl context index`）而確實會重建它。並行執行會讓寫入方觸發讀取方的
guard，產生 false failure，所以 scheduler 目前的解法是「這兩個 suite
一律獨佔全部 4 個 job slot」。2026-08-04 完整 34:12 wall-time 實測中，
這兩段獨佔合計約 6 分鐘（`test-pmctl-context` 162s + `test-release-verify`
197s），且獨佔期間其餘已排隊 suite 全部停擺，是整趟 run 裡最大的單一
scheduling 損失（模擬顯示移除後可從 34:12 降到約 28:43）。

**Why**：`test-release-verify` 真正需要驗證的是 `release-verify.sh` 的
邏輯正確性，不是「這台機器上開發者的 repo context.db 内容」；用 live repo
當測試 fixture 只是圖方便，代價是把兩個本可平行的 suite 綁死成序列化
barrier，且每次開發者本機跑 full suite 都要付這筆固定成本。

**Requirement**：
1. 找出 `release-verify.sh` Phase 3 對 repo root 的依賴點（目前呼叫
   `pmctl context index "$REPO_ROOT"` 或等價路徑），改為可注入 target
   repo（例如既有 `--repo`/環境變數模式，比照其他 phase 的 fixture
   注入方式），production 預設行為（對真正呼叫端 repo 索引）不變。
2. `test-release-verify.sh` 改成對一個臨時建立的 fixture repo（獨立
   `.pm-dispatch/ctx/context.db`）執行 Phase 3 驗證，不再觸碰開發者的
   live repo context.db。
3. 確認沒有其他 suite（含未來新增）會在測試期間對 live repo 執行
   `pmctl context index`；若有，一併納入隔離或明確排除。
4. 兩個 suite 都從 `tests/lib/test-suite-runner.sh` 的 `LIVE_DB_EXCLUSIVE`
   移除，恢復一般平行排程。
5. 回歸測試：驗證 `test-release-verify` 執行前後開發者 repo 的
   `context.db`（mtime／內容）不變（比照 `test-pmctl-context` 既有的
   no-live-db-mutation 手法）。

**Done-when**：`LIVE_DB_EXCLUSIVE` 為空或已移除；`test-pmctl-context`／
`test-release-verify` 可與其他 suite 任意並行且穩定通過（連續跑 3 次無
false failure）；`release-verify.sh` 對真正 repo 的 production 行為（無
`--repo`/target 覆寫時）不變；有回歸測試鎖住 live repo context.db 不被
測試修改；full suite wall-time 有實測數字佐證改善（對照 2026-08-04 的
34:12 基準）。

**Non-goals**：不重寫 `release-verify.sh` 其餘 phase；不改變
`test-pmctl-context` 既有的 guard 邏輯本身；不在本票內做 duration-aware
suite 排序（獨立、低優先度，不需開票）。

**Dependencies**：無硬前置。P1——直接對應「full suite 太慢」的最大單一
可修復項目。

**Source**：2026-08-04 對 07:28:50Z–08:03:02Z 完整 34:12 full-suite 實測的
事後分析（4-job 平行化耗時分解 + LIVE_DB_EXCLUSIVE 排程模擬），使用者
確認後開票。

---

## CC-543 — Full test runner fail-fast structural precheck 🟢 someday

**Problem**：`tests/lib/test-suite-runner.sh` 的 `ACTIVE_SUITE_NAMES` 把
便宜的結構性檢查（`test-lint-test-suite-registry`、
`test-lint-surface-coverage`、schema 相關 lint 等）與昂貴的行為性 suite
（PR-gate shards、doctor、e2e smoke）混在同一份註冊順序中間執行，且沒有
任何機制在前者失敗時提前中止整輪。2026-08-04 的實測中，
`lint-test-suite-registry`／`test-lint-test-suite-registry`／
`test-release-verify` 三個失敗其實是同一個根因（registry drift），
理論上 1 秒內就能判定必然失敗，但完整 runner 仍跑滿 34:12 才回報結果。

**Why**：這不影響「成功跑完整套」的 wall time，但直接影響開發迭代體感與
CI 資源浪費——結構性設定錯誤本應是最快回饋的一類失敗，目前卻是最慢。

**Requirement**：
1. 定義一組「Phase 0」suite 清單：純結構性、無需起 process tree／fixture
   repo、預期在數秒內完成的 lint／registry／schema 檢查。
2. Full runner（或其上層 CI 入口）先跑 Phase 0；任一 Phase 0 suite 失敗
   時，跳過所有 Phase 1（其餘）suite，直接回報 FAIL 並在此中止，不啟動
   PR-gate shards／doctor／e2e 等昂貴 suite。
3. 提供顯式 opt-out（例如 `--collect-all`）供需要完整診斷輸出的情境（如
   release-verify 需要蒐集所有 phase 證據時）使用，行為需與現有
   `release-verify.sh` phase-boundary 註解精神一致。
4. 回歸測試：模擬 Phase 0 suite 失敗，斷言 runner 在秒級時間內結束且未
   啟動任何 Phase 1 suite（可用既有 `write_suite_stub` 手法量測是否被
   呼叫）。

**Done-when**：Phase 0 失敗情境下，full runner 在數十秒內回報 FAIL 並中止
（不再跑滿全部 100 suite）；有回歸測試鎖住「Phase 0 失敗時 Phase 1 未被
啟動」；`--collect-all` opt-out 存在且有測試覆蓋；Phase 0 全過時行為與現
狀完全一致（不影響成功路徑的 wall time 或結果)。

**Non-goals**：不做 duration-aware 排序（獨立低優先度項目，不需開票）；
不改變個別 suite 內部邏輯；不影響 `LIVE_DB_EXCLUSIVE`／[[CC-542]] 的
排程行為。

**Dependencies**：無硬前置，可與 [[CC-542]] 並行或先後皆可，兩者範圍不
重疊。P2。

**Source**：2026-08-04 對完整 full-suite 實測的事後分析；同一次分析中
「registry drift 三個 failure 同根因」的觀察直接指出目前缺乏 fail-fast
short circuit。

---

## CC-508 — 所有間接 dispatch 的 parent-operation control plane ✅ 2026-07-25

**Problem**: `pmctl gate run`、`pmctl ship --parallel`／adapter 路徑、`pmctl task dispatch` 與任何未來 producer 都可能以一個 parent operation 間接啟動一或多個 detached dispatch；但產品控制面主要只暴露個別 `pmctl dispatch cancel <run_id>`。parent ID 與其子 run 沒有強制、可查的 ownership relation，也沒有一致的 producer-level cancel surface。當任一 producer 卡住、選錯 executor 或需中止時，操作者無法透過 pmctl 取消整個 operation；直接對 supervisor PID 操作會繞過 run state、sentinel 與 cancel-vs-complete 單一終態契約，並可能留下無法判定的 stale operation。

**Why**: 「producer 間接啟動 dispatch」不能把 parent 當成普通裸程序、把 child 當成唯一可管理物件。取消權限、影響範圍、結果完整性都必須從 parent operation 向下傳遞，且只能取消它所擁有的 children。這是所有 dispatch-capable command 的共同 correctness contract，不是 gate 的附屬功能；任何繞過記錄／關聯／受控終態的 producer 都不得出貨。

**Requirement**:
1. 建立 durable parent-operation record，至少含 operation ID、kind、owner project/workdir、executor、created／terminal timestamps、authenticated cancellation metadata，以及所有 child dispatch run ID 的 append-only relation；machine state 一律仍由 canonical writer 寫入。
2. 所有實際會派發 executor 的 producer 必須接入此 record：至少 gate、ship 的 adapter／parallel lanes；`task dispatch` 目前只改 task lifecycle metadata、沒有啟動 executor，因此不是 producer，必須由 contract test 守住「不得暗中派發」的分類。未來若 task dispatch 開始 launch executor，必須在同一變更接入 parent/child contract；新增或重構 dispatch-capable command 時，CI ratchet 必須拒絕未宣告 parent/child contract 的路徑。
3. 每個 producer 提供一致命名的 cancel surface（例如 `pmctl gate cancel <id>`、`pmctl ship cancel <id>`、`pmctl task cancel <id>`），以 recorded ownership 找到 parent 與其 children；不得接受任意 PID、任意 run ID 或跨 project 的 cancellation target。
4. cancel 順序與 `pmctl dispatch cancel` 對齊：先要求 parent 停止再以 pmctl 逐一取消已記錄、仍 in-flight 的 children；race 中只能產生一個 terminal state（completed／failed／cancelled），不覆寫已完成 result，也不取消其他 operation 的 run。
5. 每個 producer 的 wait／status／verify 對 cancelled terminal state 提供可驗證、非成功的結論與 result/sentinel evidence；crash、reboot、PID reuse、child already terminal、部分 child cancellation、stale parent 均 fail-closed 並可由 reconcile/doctor 說明。
6. 抽出的 parent/child relation 與 cancellation primitive 必須是明確、窄的 reusable API；禁止各 producer 重複 supervisor/PID 邏輯，也不以一次性 gate 修補取代全域契約。
7. 回歸覆蓋 gate、ship 與 task dispatch 的取消、child dispatch cancellation、race（cancel vs finish）、foreign target 拒絕、sentinel/result integrity、reconcile 與不碰非本 operation run 的負向測試。

**Done-when**: 操作者可只用 pmctl 對任一 in-flight producer operation 做可驗證取消；其所有已記錄 child run 收斂到正確終態、無孤兒或跨 operation 影響；各 producer 的等待者不會把 cancelled/stale operation 誤報為成功；現有與未來 dispatch-capable command 都受同一 contract ratchet 保護。

**Dependencies**: [[CC-495]]（dispatch cancel terminalization）與 [[CC-499]]（detached reconciliation）為基礎；本票先定全域 parent-operation contract，再逐一遷移全部既有 producer，不能以「未來有需要」延後 ship、task dispatch 或其他現存派發路徑。

**Outcome**: gate 與 ship 現在都在 launch boundary 前建立 durable parent-operation record 並掛上每個 child，取消與 reconcile 只作用於自己記錄的 children，且一律經由 trusted `pmctl dispatch cancel` primitive，不接受呼叫端傳入的 PID。reconcile 不從 workspace artifact 推論完成：任一 child 缺可信終態即維持 `indeterminate`。doctor 新增唯讀 `parent-operations` 診斷並直接給出對應的 reconcile 指令。task dispatch 依票面維持不接入。

審查揪出三個同類缺陷——ownership 已保留、但保留之後的失敗路徑沒寫終態證據——並全部修復：child 已 attach 後 launch 失敗改由 dispatch 補寫 `failed` terminal claim（exclusive-create CAS，內層已 claim 時為 no-op），ship 隨之改走 reconcile；detached gate launcher 在 supervisor 存在前失敗改套用與前景路徑相同的 childless 補償；unknown/foreign operation id 不再靜默 exit 2，且相對 `--cd` 不再被誤判為 foreign。每個回歸測試都做過反向驗證（停用修正後確認測試回報 `indeterminate`／`running`，而非空過）。

同時把 `runtime/bin/pr-gate.sh` 的 reviewer dispatch 從回頭呼叫 `cli/pmctl` 改為載入 `runtime/lib` 的 dispatch 函式，修正 `docs/architecture/script-domain-ownership.md` 定義的依賴方向；lib 在每次 dispatch 的 subshell 內 source，保留原有行程隔離。此路徑需要 repo layout（shared libs 以 `<lib>/../..` 推導自身 root），copy-mode bundle 維持既有降級路徑，文件已載明補平方式是給 libs 明確 root、而非還原 CLI 呼叫。

證據：full tier gate GO（五名 reviewer 全 approve/pass）、targeted risk-reviewer GO（零 finding）、current-tree 全套 97 suites 0 failed 0 skipped、CI 57/57。兩輪 GO 的 parent operation 皆自行收斂為 `completed / children: 1 / unresolved: 0`。

**See**: pr:#447

## CC-503 — shared tooling/hooks host-boundary 收斂 ✅ 2026-07-24

**Problem**: script domain 已依檔案路徑分到 shared runtime、host modules與 tooling，但 content boundary 尚未 ratchet：`tools/skills/skill-refine.sh` 強制 `CLAUDE_MEMORY_DIR`；`runtime/hooks/guard-inject-context.sh` 位於 shared runtime卻解析 Claude UserPromptSubmit payload並 source `hosts/claude`; 多個 shared guard預設 audit log在 `$HOME/.claude/logs`；`guard-pm-write.sh` 把 writable memory root固定為 `$HOME/.claude/projects`。

**Why**: 只搬檔不處理 inputs/defaults/side effects，會讓 shared path 看似通用、實際仍在 Claude host才成立。這些問題不應與 [[CC-502]] 的 release-blocking gate路徑混修，也不應順手擴張 [[CC-054]] 的 diff-generation產品範圍。

**Requirement**:
1. `/skill-refine` 與 bundler透過 canonical `pmctl memory dir/resolve` 取得 project memory；`PM_MEMORY_DIR`/project config precedence與 invalid-explicit fail-closed沿用單一 resolver，`CLAUDE_MEMORY_DIR` 僅能作有期限的 compatibility seam或移除。
2. prompt-time context injection拆成 host payload adapter與 shared prompt-scan primitive；Claude payload/timeouts歸 `hosts/claude`，shared primitive只接收正規化 cwd/prompt/repo input。
3. shared guard audit log預設改由 canonical state/log resolver或 host binding顯式傳入；不得在非 Claude host side effect建立 `.claude` tree。
4. PM write policy若仍允許 memory writes，必須依 canonical resolved memory root判定；invalid explicit selection fail-closed，symlink/escape安全不降級。若 canonical writer已取代 direct edit，明文縮小或移除該 allow rule。
5. 建立 content ratchet：shared runtime/tooling不得直接 source `hosts/<name>`、使用 host config root作通用 default，或把單一 host env當唯一 API；bounded allowlist每列需 owner、理由、consumer與退場條件。

**Done-when**: 上述 shared consumers在 Claude/Codex/OpenCode host fixture下使用同一 canonical input/output contract；host-specific parsing只存在 host module；content ratchet有正反注入測試並接入 CI/full runner。

**Plan**：Phase A 先以 shared log-root resolver、canonical memory resolver 與 host payload adapter 切斷 Claude-only default；Phase B 將 PM write policy改為 canonical resolved root並補 symlink/invalid-explicit negative cases；Phase C 以 repository content ratchet（direct host source、host-root default、single-host-only API）守住邊界。每一 phase 都須在 Claude/Codex/OpenCode fixtures跑同一 contract；不得為了相容而在 shared layer重新引入 host fallback。

**Dependencies**: [[CC-502]] 先建立 gate/reviewer pattern；[[CC-054]] 保持 deferred且只處理 review-first diff generation。必須在 [[CC-447]] 正式 N-1 release qualification 前完成。P2，v0.11.0 host-boundary closure。

**Outcome 2026-07-24**: Shared prompt scanning now consumes normalized inputs while Claude payload parsing and timeout policy live in the Claude host adapter. Shared tooling and guards resolve canonical memory and product-owned log roots without creating `.claude` trees; direct PM memory edits are removed in favor of the canonical writer boundary. Content ratchets and Claude/Codex/OpenCode fixture coverage enforce the boundary.

**See**: pr:#445

## CC-504 — manifest-driven multi-host lifecycle，移除 Claude base-spine 特例 ✅ 2026-07-23

**Problem**: host manifests已能為 Claude/Codex/OpenCode宣告 install/uninstall/doctor modules，但頂層 `install.sh`、`uninstall.sh` 與 `runtime/bin/doctor.sh` 的 base orchestration仍先解析 Claude config root、把 product assets/manifest放進 Claude tree，其他 host再作附加 wiring；copy-mode doctor也保留 Claude-specific fallback。Codex/OpenCode-only環境因此仍無法形成真正獨立的 product lifecycle。

**Why**: 這是文件已承認的 transitional compatibility path，不能在 v0.9 release前以全面重構方式臨時擴 scope；但 [[CC-447]] 要建立可長期沿用的 multi-host N-1 upgrade proof前，必須先決定 product-owned assets、host-owned config與 shared state各自的 canonical owner，否則每版 smoke都會固化 Claude特例。

**Requirement**:
1. 盤點頂層 installer/uninstaller/doctor的 product assets、host bindings、shared CLI/state與 compatibility ABI，定義不依賴任一 host home的 ownership graph。
2. top-level lifecycle以 manifest-selected modules協調所有 selected hosts；Claude與Codex/OpenCode使用同一 dispatch contract，無隱含 base host。Codex/OpenCode-only install不得建立或要求 `.claude`。
3. install manifest移到 product-owned canonical location，或定義可證明安全的 per-host manifest aggregation；uninstall只移除各 owner宣告的 artifacts並保留 foreign content。
4. doctor core只做 shared checks與 manifest module dispatch；host binary/auth/config/hook remediation留在 `hosts/<name>`，移除 Claude copy-mode business logic或把它降為明列、有退場條件的 compatibility wrapper。
5. 保留既有 installed helper ABI所需的 bounded shims，並提供 old Claude-base install到新 lifecycle的 upgrade/migration path；不得用 clean-install-only重構破壞既有使用者。

**Done-when**: 三個 host可各自或組合 install→doctor→uninstall；未選 host零 config side effect；foreign config與canonical memory preserved；[[CC-447]] 可在同一 lifecycle contract上執行 future N-1 upgrade而不特判 Claude base tree。

**See**: pr:#442

**Outcome 2026-07-23**: Product receipt ownership now lives outside any host tree, records selected hosts durably, and migrates legacy Claude-local receipts safely. Install, uninstall, and doctor dispatch only manifest-selected hosts; unselected hosts have no config side effect, partial uninstall preserves remaining ownership, and doctor reports receipt/config drift. Legacy installed helpers retain bounded Claude compatibility fallback while the canonical lifecycle no longer requires a Claude base tree.

**Dependencies**: 以 [[CC-501]] 的一次性 evidence作現況輸入，與 [[CC-503]] 的 shared content boundary協調；在 [[CC-447]] final N-1 contract前完成。P2，v0.11.0。

## CC-505 — context plane lexical 檢索補完與排序 🔵 active

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

**Requirement — Phase 2（agent 契約 + shadow 儀器化；小 PR，跟在 Phase 1 後）**:
8. Agent-facing injection 明確採用 **index-first, source-verified** 契約：retrieval hit 是導航與 scope-narrowing evidence，不是原始來源替代品；factual conclusion、code edit、gate/security/release 判斷前必須 targeted-read 命中的 bounded span；zero-hit、stale/unknown freshness、truncated 或 ambiguous 結果必須 fallback 至 targeted Grep/Read；no hit 不得解讀為不存在。本階段只改導引措辭，**不收緊**任何現有 fallback 行為。
9. shadow telemetry：在既有 context.* 事件上記錄 top-K refs、pack bytes、full-file baseline bytes、truncation/freshness，以及 Agent 後續實際 source-read bytes 與最終修改／引用檔案是否在 top-K——供 [[CC-506]] 評測消費。覆蓋面必須含工作流路徑（dispatch auto-pack、ship、gate memory context），不得只儀器化互動式 `context query`。
10. `context_savings` 遙測命名為 `compression_ratio_vs_full_file_baseline`（注入 bytes vs 全檔 baseline bytes）；沒有 observed read-reduction 證據時不得宣稱實際節省倍數；不得引用外部專案的節省倍數宣稱。餵 [[CC-467]]／[[CC-358]] 的 evidence 線。

**Done-when**: Phase 1——檢索能命中段落深處內容；四個 consumer 對相同 query 使用相同 ranking order；hits 帶 rank／match_kind／bounded span／score components／freshness；fixture suite 證明 exact-symbol top-1、expected refs top-K、mtime-preserving edit freshness、budget truncation disclosure；整合測試證明 dispatch auto-pack 與 gate memory context 的注入內容出自同一 ranking path（對同一 query 與直接 `context query` 排序一致）。Phase 2——agent-facing 輸出攜帶 index-first/source-verified fallback 指令；shadow telemetry 欄位落地並開始蒐集。收緊 broad-Read 指引**不在本票**（→ [[CC-506]]）。

**Non-goals**: 不做 embeddings（[[CC-340]] 維持 deferred，resume 條件由 [[CC-506]] 評測後重評）；不做 edges／blast radius（[[CC-346]]／[[CC-347]] 的範圍）；不引入 tree-sitter/AST 或外部索引工具；不在本票收緊 broad-Read fallback 或宣告實際 token 節省（[[CC-506]]）；跨 host prompt 注入接線屬 [[CC-503]]，本票不因其未完成而阻塞。

**Dependencies**: 無硬前置；與 [[CC-465]]（CJK 斷詞）同屬檢索品質線可協調但不合票。排序：本票 Phase 1 完成即解鎖 [[CC-346]] Phase a + [[CC-347]] 垂直切片（不需等 [[CC-506]]）。**未排入 milestone**——v0.11.0 之後的 context-plane 版次候選。

**Source**: 2026-07-20 四方 multi-model synthesis（外部參照 tirth8205/code-review-graph 的可轉移性分析；四方一致：不裝外部工具、不建第二套系統，在既有 context.db 上補「檢索品質 → edges → change impact」三層）。2026-07-20 外部 review 補強：consumer ranking 統一、index-first/source-verified 契約、fixture corpus、shadow evidence 與誠實命名（ranking ≠ confidence；ratio ≠ 實際節省）；phase 拆分依 auto-pack 先例（機制+telemetry 先行、evidence 後收緊，見 CC-402 default flip 模式）。

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

## CC-507 — `pmctl state status` unreadable VERSION fail-closed ✅ 2026-07-21

**Outcome**: `pmctl state status` 改用可被條件式捕捉讀取失敗的 command substitution，避免 Bash `$(<file)` redirection 在 `set -e` 下提前中止。無法讀取 `VERSION` 時現在會回傳結構化 `store_state: unreadable`、exit 3，不洩漏 raw Permission denied，且保持 store 零 mutation。回歸測試驗證 exit code、JSON contract、stderr 與 tree snapshot；affected tests 9/9、PR gate GO、authoritative full suite 88/88 通過。

**See**: pr:#437
