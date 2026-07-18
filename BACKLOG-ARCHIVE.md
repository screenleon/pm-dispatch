<!-- pm-dispatch: backlog-archive 2026-07-18 -->
# pm-dispatch backlog — archive

Terminal (`✅ done` / `✅ closed` / `🟢 superseded` / `🚫 dropped`) tickets archived from
BACKLOG.md — both the index row and the body section (pm/schema.md §2.3 terminal set + §4
working-set model; CC-049, CC-279/280, CC-378).
BACKLOG.md keeps only non-terminal entries; no closed row or in-place stub remains there.
Last archived: 2026-07-18

---

## CC-005 — install.sh preflight 改為 opt-in via --verify ✅ 2026-05-18

**Outcome**: `./install.sh` now skips tests by default; `./install.sh --verify` runs the full suite. `CLAUDE_CONFIG_TEST_INSTALL_RUNNING=1` escape hatch unchanged. CI unaffected.
**See**: pr:#85

## CC-006 — statusLine hook 自動寫入 rate-limits ✅ 2026-05-13

**Outcome**: `scripts/token-usage.sh` 取代 `claude-usage.sh`；`hook-save-rate-limits.sh` StatusLine hook 自動寫入 `~/.claude/rate-limits.json`，`--remaining` 免手動輸入剩餘 %。
**See**: pr:#42

## CC-007 — brief qa_checklist 指引 ✅ 2026-05-13

**Outcome**: `docs/codex-brief.md` 加入 `qa_checklist` 選填區塊規範；`agents/project-pm.md` 加入 PM 生成 brief 時的對應指引。
**See**: pr:#42

## CC-008 — Spark routing 判斷標準 ✅ 2026-05-13

**Outcome**: `agents/project-pm.md` 加入 Spark routing 三條件判斷規則（diff < 50 行、≤ 2 檔案、無跨模組依賴）。
**See**: pr:#41

## CC-009 — UserPromptSubmit hook inject MEMORY.md ✅ 2026-05-14

**Outcome**: `scripts/hook-inject-memory.sh` 新增；每次 UserPromptSubmit 時注入完整 MEMORY.md index 防 auto-compact 遺忘；≥50 條時發出 `/memory-compress` directive。
**See**: pr:#44

## CC-010 — `/memory-compress` 指令 ✅ 2026-05-14

**Outcome**: `commands/memory-compress.md` 新增；slash command 讓 Claude 壓縮/合併 MEMORY.md 條目，支援 `--dry-run`。
**See**: pr:#45

## CC-013 — `/caveman` token 壓縮 skill ✅ 2026-05-18

**Problem**: 長 session 中 Claude 回應冗長，token 消耗快速，尤其在 codex brief 審核、多輪 gate 等場景。
**Why**: Caveman 專案實測降低 65-75% token 用量，架構（slash command + hook）與 pm-dispatch 完全相容。
**Requirement**: `commands/caveman.md` slash command，切換壓縮模式（off / lite / full / ultra）；`/caveman-commit` 變體生成超簡潔 commit message。

**Outcome**: gate GO（R7，2026-05-18）。實作摘要：
- `commands/caveman.md`：off/lite/full/ultra 四模式切換；空參/無效參數各有明確 stop-before-Step-2 行為；Step 2 輸出固定格式 `Caveman mode: <MODE>`
- `commands/caveman-commit.md`：讀 `git diff --cached` → 推斷 type/scope/subject → 純文字輸出；breaking-change 用 `!` append 到 type/scope；`$ARGUMENTS` 作 hint
- 8 個 agent 檔全部加入 `# Output brevity` section（agent-to-agent 壓縮常態化；`/caveman` 僅影響對用戶的回應）
- `scripts/test-commands.sh`：103 個 contract assertions；CI job 已接入 `.github/workflows/lint.yml`

**Post-mortem（7 輪 gate）**：屬於 CC-039 記錄的「洋蔥剝皮」模式的第二個案例。具體觸發條件：同一 PR 同時新增功能檔案 + 對應的 contract test script，qa-tester 對 test script 的完整性要求與對功能本身同等嚴格，但無事先 behavioral contract 清單，導致每輪只補 1–2 個缺口。見 CC-039 補充分析。

**See**: pr:#82

## CC-016 — gate NO-GO fix-loop 效率 ✅ 2026-05-14

**Outcome**: `agents/project-pm.md` 加入 source-first、discovery 步驟、`--targeted` 重跑、「最少清單」四項 fix brief 撰寫規則。
**See**: pr:#43

## CC-017 — 前端 UI 實作前置流程 ✅ 2026-05-14

**Outcome**: `agents/project-pm.md` 加入 UI 實作前置規則：圖片讀取確認、互動狀態/RWD/元件邊界必問清單、brief 鎖定流程。
**See**: pr:#43

## CC-019 — Episodic memory 層 ✅ 2026-05-14

**Outcome**: `scripts/hook-session-summary.sh` Stop hook 記錄 metadata skeleton；`commands/mem-log.md` 生成語意摘要寫入 `episodes.jsonl`；`commands/mem-recall.md` 注入近期 episodes；`commands/mem-distill.md` 整合 episodes 更新 MEMORY.md。
**See**: pr:#45

## CC-020 — `/mem-search` 跨 memory 搜尋 ✅ 2026-05-14

**Outcome**: `commands/mem-search.md` 新增；`rg` 關鍵字過濾 + Claude 語意理解，跨所有 memory 檔搜尋。
**See**: pr:#45

## CC-021 — test scripts `--filter` / `--list` ✅ 2026-05-14

**Outcome**: `scripts/test-hooks.sh` 和 `scripts/test-install.sh` 新增 `--filter <pattern>` 只跑匹配 case，`--list` 列出所有 case 名稱。
**See**: pr:#45

## CC-022 — `/pre-impl` 開發前設計評審 ✅ 2026-05-14

**Outcome**: `commands/pre-impl.md` 新增；強制回答職責邊界/依賴方向/變動接縫三個設計問題，輸出可貼入 brief `constraints:` 的約束清單。同時修正 `pm/scripts/validate.sh` schema drift（`✅ done`、`⏸ deferred`、topic-area tokens）並對齊 `pm/schema.md`、`pm/templates/BACKLOG.md`。
**See**: pr:#46

## CC-024 — `test-usage-weekly.sh` 加入 GitHub Actions CI

**Problem**: `scripts/test-usage-weekly.sh`（20 tests）在 PR gate 手動執行通過，但 `.github/workflows/lint.yml` 未包含此 suite，merged PR 後無 CI 保護。
**Why**: `usage-weekly.sh` 是 read-only 報告工具，迴歸影響面低但覆蓋率現在是靠手動 gate 維持，長期不穩固。qa-tester 在 gate-20260514-174657 發出 advisory（non-blocking）。
**Requirement**: 在 `.github/workflows/lint.yml` 加入一個 `test-usage-weekly` job，執行 `bash scripts/test-usage-weekly.sh`；失敗 → CI 阻擋。
**Source**: 2026-05-14 對話 — pm-dispatch 改善分析。與 CC-029（test-codex-dispatch）同 PR 處理。
**Outcome**: 2026-05-15 — PR #57 合併（與 CC-029 同 PR）；`lint.yml` 加入 `test-usage-weekly` job，fixture-driven 無外部依賴，20 tests 通過。
**See**: pr:#57

## CC-025 — `/skill-refine` skill 自我精修 ✅ 2026-05-18

**Outcome**: 2026-05-18 — M1 spike (`scripts/skill-refine.sh` + `commands/skill-refine.md`) 已合併；PR #67 實作 shell script，PR #68 追加 contract tests + 環境契約文件化。M2（diff 生成）留 CC-025b 後續。

**See**: pr:#67,pr:#68

**Problem**: skill / command（`/pr-gate`、`/codex-pr-gate`、`/pm`、`/pre-impl` 等）的 .md 內容是手寫的，使用過程中遇到的卡點與更正只會沉澱成 feedback memory（例：[[feedback_gate_on_stacked_branches]]、[[feedback_stale_binary_before_smoke]]），不會回流到 skill 本身。下次同個 skill 的 fresh 使用者（包含未來的自己）仍會踩同樣的洞。
**Why**: PR #45 已落地 `episodes.jsonl` + `/mem-log` + `/mem-distill`，episode 層已包含「該 session 用了哪些 skill / 是否有後續更正」的原始訊號 — 缺的是把這個訊號針對「skill 本身」做 diff 提議的閉環。Hermes Agent README 把這條稱作 "skills self-improve during use"，是 self-improvement loop 中 pm-dispatch 最明顯的缺口。預期 ROI 最高，因為 PR-gate / Codex routing 是高頻使用的 skill，每一條 feedback rule 沉澱回 skill 都能直接降低未來 fix-loop 輪數（對應 [[feedback_shared_schema_briefs]] 的根本痛點）。
**M1**: PR #TBD lands a read-only `scripts/skill-refine.sh` spike that scans curated `feedback_*.md` memory entries for a target skill and emits a markdown signal bundle. No diff generation or LLM call.
**M2 deferred**: slash-command shell (`commands/skill-refine.md`) and Claude-generated refinement diff remain follow-up scope.
**Requirement**:
1. `commands/skill-refine.md` slash command，介面：`/skill-refine <skill-name> [--dry-run]`。
2. 讀 `episodes.jsonl` 近 N 個 entry 中 metadata 顯示有觸發該 skill 的 session；提取後續 turns 的 user-correction 訊號（user 在 skill 跑完後立刻給出 "no"/"actually"/"don't"/「不對」/「應該」等更正詞、或重發類似 prompt）。
3. 對 `commands/<skill-name>.md` 提 diff，預設 `--dry-run` 印出 patch 等待 user 確認；非 dry-run 也僅輸出 diff 不直寫，由 user/main thread 套用（避免 skill 自改 skill 的回授風險）。
4. 觀察期：先當 `/mem-distill` 的兄弟工具，不進 cron / 自動觸發，避免污染。
**Note**: 依賴 **CC-027**（PreToolUse tool-trace 基礎建設）— 原本標為 spike brief 內待釐清的訊號層，現移為獨立前置項目。
**Source**: 2026-05-15 對話討論 Hermes Agent self-improvement loop 與 pm-dispatch 的 gap 分析。

## CC-027 — PreToolUse `hook-tool-trace.sh` tool/skill 觸發訊號層

**Problem**: 現有 `hook-session-summary.sh`（Stop）只記 session-level metadata，`hook-inject-memory.sh`（UserPromptSubmit）只 inject 不寫；中間「哪些 tool / skill 在這個 session 裡跑過、執行序列為何」沒有任何結構化記錄。CC-025 `/skill-refine` 要找「某 skill 跑完後 user 立刻更正」的訊號、CC-026 `/skill-distill` 要找「重複工作流」的序列 — 兩者都讀空。
**Why**: 不先補這層，CC-025/CC-026 即使寫了也只能讀空資料。設計上是 PR #45 episode layer 的更細顆粒度版本 — 不重做摘要而是新增 `tool-trace.jsonl` 獨立檔，避免污染既有 episodes.jsonl schema。關鍵約束：純 metadata、零 LLM 呼叫，不能讓 PreToolUse 變慢。
**Requirement**:
1. `scripts/hook-tool-trace.sh` PreToolUse hook（matcher 全部），從 stdin JSON envelope 僅解析必要 metadata（tool name、首參數的 skill 名 / path snippet）並 append `{ts, session_id, tool, first_arg_or_skill}` 到 `~/.claude/projects/<proj>/memory/tool-trace.jsonl`；**不持久化完整 payload、不對 stdin 內容跑 LLM、不阻擋 tool call**。實作需依 [[feedback_undocumented_harness_payload]] hedge 多 JSON 路徑取 tool / params 欄位。
2. `/mem-log` 與 `hook-session-summary.sh` 寫 episode 時可選讀同 session 的 tool-trace，產出工具序列 summary 一併塞進 episode metadata（仍純 metadata，不調 LLM）。
3. tool-trace.jsonl 採獨立檔以便日後輪轉/壓縮；最近 N session 保留，超過 archive 或刪除。
4. `install-hooks.sh` wire PreToolUse；`scripts/test-hooks.sh` 加對應 case 驗證 append 結構、效能不退化、不阻擋。
**Note**: blocks **CC-025**, **CC-026**。在這條落地前，CC-025/026 不應啟動。
**Source**: 2026-05-15 對話 — pm-dispatch 改善分析（A2）。
**Outcome**: 2026-05-15 — Added metadata-only PreToolUse `hook-tool-trace.sh`, install wiring, and hook regression coverage; PR #54.
**See**: pr:#54

## CC-028 — PostToolUse `hook-routing-log.sh` 自動 append routing_log

**Problem**: Memory 的 `routing_log` 設計為「Brief/Dispatch routing 決策的 append-only log，作為 Q1/Q2/Q3 規則校準資料」 — 但實際上**沒有自動寫入機制**，靠人手動追加；事實上沒人追加，calibration 永遠不會累積。
**Why**: `feedback_codex_routing` 的 Q1/Q2/Q3 規則目前只靠主動意識，沒有量化校準。Routing 決策本來就是 `codex-dispatch.sh` 呼叫的 by-product，可由 hook 在 dispatch 後自動落地。與 CC-027 同類設計（純 metadata logger），但訊號內容不同。
**Requirement**:
1. `scripts/hook-routing-log.sh` PostToolUse hook，觸發條件：(a) `Bash` tool 且 command 含 `codex-dispatch.sh`，或 (b) `Agent` tool dispatch 至 codex-executor 子代理。實作須 hedge 多 JSON 路徑取 envelope 欄位（候選含 `agent_type` / `subagent_type` / `subagent.type` 等，具體欄位以執行期觀察為準，對應 [[feedback_undocumented_harness_payload]]）— spike brief 第一步須先樣本驗證實際 envelope shape。
2. 從 brief 檔（`.codex-briefs/<id>.md` 或 dispatch first non-flag arg）讀 `goal:` / `files:`，append `{ts, brief_id, goal_excerpt, file_count, q_hit?}` 到 `routing_log.md`。
3. `q_hit` 為選填，MVP 可只記 raw metadata，由 `/mem-distill` 或新增的 `/routing-distill` 後製判斷 Q1/Q2/Q3 hit。
4. `scripts/test-hooks.sh` 加對應 case：dispatch 觸發、非 dispatch Bash 不觸發、append 結構正確、append 失敗不能阻擋 dispatch 結果。
**Source**: 2026-05-15 對話 — pm-dispatch 改善分析（A1）。對應 [[routing_log]] 與 [[feedback_codex_routing]] 設計目標。
**Outcome**: 2026-05-15 — Added PostToolUse `hook-routing-log.sh` + one-time migrator `migrate-routing-log.sh` (3 existing bullet entries → JSONL); install wiring, 19 routing hook/installer regression cases, 5 migrator cases; 298/298 + 5/5 green. MVP fields: brief_file + goal_excerpt only; brief_id / file_count deferred to `/routing-distill`-side computation. Per-hook q_hit/second_thoughts left null — post-classification deferred to a later `/routing-distill`. PR #55.
**See**: pr:#55

## CC-029 — `test-codex-dispatch.sh` 加入 CI

**Problem**: `.github/workflows/lint.yml` 跑 6 個 jobs 但**不包含 `test-codex-dispatch.sh`**（13 snapshot tests）。`codex-dispatch.sh` 是高頻 + 安全敏感（sandbox / approval flags / write-guard 互動），沒有 CI 保護等同信任「dispatch 邏輯不會被誤改」 — 與 [[feedback_codex_dispatch_foreground]] 記錄的曾發生 orphaned-job 事故風險不相稱。
**Why**: 先前以「snapshot 環境敏感」為由排除，但 snapshot 本來就是 fixture，能在 CI clean env 跑。與 CC-024（test-usage-weekly 缺 CI）同類問題、同類修正 — 兩者可一起作為單一 PR 補完 `lint.yml`，共用 PR 成本。
**Requirement**:
1. `.github/workflows/lint.yml` 加 `test-codex-dispatch` job，runner steps 同既有 test jobs 模式。
2. 確認 snapshot fixtures 不依賴本機 `$HOME` 絕對路徑、不依賴外部 secret；若有則先補 fixture isolation 再進 CI。
3. 與 CC-024 同 PR 處理。
**Source**: 2026-05-15 對話 — pm-dispatch 改善分析（A3）。
**Outcome**: 2026-05-15 — PR #57 合併；`lint.yml` 加入 `test-codex-dispatch` 與 `test-usage-weekly` 兩個 job，fixture-driven 無外部依賴。後續 PR #58 (CC-036) 再追加 `test-dispatch-handover` job。
**See**: pr:#57

## CC-034 — `install-hooks.sh` 改名/移動 checkout 後 append-not-replace bug

**Problem**: `scripts/install-hooks.sh:101-106` 的 idempotency 檢查使用完整路徑字串相等比對：`select(.command == $pm)`。同路徑首次或重跑時可正確 skip；但**改名 / 移動 checkout 路徑後重跑時**，新路徑與舊路徑字串不等 → 舊 entry 不被識別 → 新 entry append 進去，留下舊 entry 變成 ghost。每個 hook 會 fire 兩次（舊指向已失效路徑、新指向有效路徑），且舊 entry 必須手動清。
**Why**: 2026-05-15 PR #51 改名 claude-config → pm-dispatch 時親身踩到 — 需要先 manual `rm` 22 個 stale symlinks + 手寫覆蓋 settings.json 才完成 cutover。對應 [[feedback_known_bug_backlog]]：observed 就要登錄。非一般使用 path：日常 install/uninstall 不會觸發，但任何「同一 hook 但路徑變了」的情境都會（多機 sync 路徑不同、fork 後改名、目錄重組）。
**Requirement**:
1. 把 idempotency 比對改為以 hook script **basename** 識別（例：`(.command | split("/") | last) == "hook-pm-write-guard.sh"`），不是 full path。
2. 在 add 前先 prune：移除所有 basename 相同但 path 不同的舊 entry，再 append 當前 path 的新 entry → 真正 idempotent 跨路徑。
3. `scripts/test-hooks.sh` 加 fixture：先以路徑 A install、改路徑為 B 後再 install，預期 settings.json 只剩 B 的 entry、A 的被清掉。
4. `uninstall-hooks.sh` 同步改為 basename match，避免 uninstall 也踩同 bug。
5. 注意 statusLine 處理：目前 chain logic 已用 `_statusline_already_wired` 條件存在判斷，basename 改造需確認 chain 不被誤刪。
**Note**: 此 bug 不阻擋一般使用；列為 ops 維護債。
**Source**: 2026-05-15 對話 — PR #51 改名 cutover 時 observed。
**Outcome**: 2026-05-15 — `install-hooks.sh` + `uninstall-hooks.sh` 改 basename match；test-hooks.sh 加跨路徑 fixture；statusLine chain 安全保留。PR #53.
**See**: pr:#53

## CC-036 — `/pm` dispatch async ergonomics restore ✅ 2026-05-18

**Problem**: 從 2026-05-09 PR #33（landed `[[feedback_codex_dispatch_foreground]]`）之後，`/pm` 工作流預設把所有 codex 派發都導去 `Agent(subagent_type:"codex-executor")`。subagent foreground-only rule 是正確的（防 orphan），但同時也讓 main thread 在 dispatch 期間完全停擺（觀察過 10.8 分鐘 idle window）。修法前的舊體驗——main-thread 直接 `Bash(codex-dispatch.sh, run_in_background:true)` 派、利用 harness PID-tracking + 完成通知並行做別的事——還在能用，但目前的命令路由完全不走那條，等於把「能 async 的場景」也強制 sync。
**Why**: foreground rule 是 **subagent 限制**（subagent session 結束時 codex 被 SIGKILL → orphan）。**Main-thread 沒有 session 結束問題**，harness 會等 background 完成發通知。被 misroute 的不是規則本身、是消費路徑。User 2026-05-15 觀察：「之前 orphan 完成之後會自動通知 一樣可以完整把資料回收 但是不知道為什麼最近更新之後 反而會一直等待」——點出此 regression。
**Requirement**:
1. `commands/pm.md` 文檔流程：classify + brief composition 仍由 `Agent(subagent_type:"project-pm")` 在 subagent 內完成（不變）；但**派發階段**改為「PM 回 brief 給 main thread → main thread 用 `Bash(scripts/codex-dispatch.sh --brief-file <path>, run_in_background:true)` 直派」。
2. 完成通知由 harness 自動 fire，main thread 在收到通知前可繼續做別的事（讀檔、回 user、開新 dispatch parallel）。
3. `Agent(subagent_type:"codex-executor")` 路徑**保留**作為 fallback：(a) 嚴格 brief schema 驗證需求、(b) main-thread context-window 已滿不適合直派、(c) main-thread 流程已被其他 sync 工作佔住。文檔需明寫此三條 fallback 條件。
4. 自我校準：派出後若超過 `--timeout`（預設 1200s）仍無 completion notification、main thread 應主動 ps grep + filesystem check 判斷是否 true orphan（呼應 `[[feedback_codex_dispatch_foreground]]` 更新的 verification-first diagnostic）。
5. 觀察 1–2 週後，根據 `routing_log.md` auto-block 資料統計 main-thread direct vs subagent 派發比例與成功率，再決定是否進一步把 codex-executor agent 改成「brief-validator only, no dispatch」（會是 CC-036b 後續票）。
**Source**: 2026-05-15 對話 — CC-028 落地後 user 反映派 codex 主執行緒被卡住、回想舊 async + notify 體驗較佳。對應 [[feedback_codex_dispatch_foreground]] 與 [[feedback_skill_background_main_thread]]。
**Note**: 設計變動（不是 mechanical patch），實作前須跑 `/pre-impl` 把「commands/pm.md 既有結構 + brief→main-thread handover 介面 + fallback 條件」釐清；不適合直接走 codex execution。
**Cross-link**: **CC-037 必須在 CC-036 同 PR 或之前 merge**。CC-036 把 dispatch 改成 main-thread `run_in_background` 後，並行 dispatch 機率上升，CC-037 的 concurrent-append race 才會真正觸發 silent row loss。在序列 foreground dispatch 的當前狀態下 race 無法發生，所以 CC-037 defer 是安全的；CC-036 落地當下若 CC-037 仍 open，必須先補 flock 再開 async dispatch。

**Outcome（2026-05-18 驗證）**: 功能已在先前某 PR 實作並落地——`commands/pm.md` 已以 Route A（main-thread Bash `run_in_background:true`）為 primary route；`Agent(codex-executor)` 已降為 fallback allowlist；`docs/dispatch-brief.md §Fallback` 已明列 4 條 fallback 條件。本票不需新 PR，直接 verified-in-place close。⚠️ CC-037（hook race）隨著 CC-036 上線，race surface 已從理論轉為實際，應盡快排入。

**See**: (verified-in-place — implementation already in `commands/pm.md`; no separate PR)

## CC-037 — `hook-routing-log.sh` concurrent append race ✅ 2026-05-18

**Outcome**: 2026-05-18 — `scripts/hook-routing-log.sh` 已透過 `lib/portable.sh` 的 `mkdir_lock()` 取代 `flock`，append race 已序列化；concurrent writes 有 stale-lock GC。verified-in-place（`mkdir_lock` 實作隨 CC-038 portability work 落地）。

**See**: (verified-in-place — `scripts/hook-routing-log.sh` uses `mkdir_lock` from `lib/portable.sh`)

**Problem**: risk-reviewer's 2026-05-15 PR #55 finding at `scripts/hook-routing-log.sh:204`: the append path rewrites the whole file via temp + `mv` without a lock. Concurrent PostToolUse invocations can race, silently losing one routing row. Blast radius is bounded because this is calibration telemetry, but the loss mode is silent.
**Why**: `routing_log.md` is the feedback source for future routing calibration. If parallel dispatches drop rows under normal concurrent hook execution, downstream `/routing-distill` metrics can undercount exactly the high-concurrency cases that need calibration.
**Requirement**:
1. Introduce `flock` on a sibling lockfile around the append path or switch to atomic rotation-aware append.
2. Add a test fixture in `scripts/test-hooks.sh` that fires two concurrent hook invocations and asserts row-count delta == 2 post-merge.
3. Keep the hook's "non-blocking" contract — if locking fails after a short timeout, audit and skip rather than block dispatch.
**Source**: 2026-05-15 PR #55 risk-reviewer finding; tracked per [[feedback_known_bug_backlog]].
**Cross-link**: **gating dependency of CC-036**. Under current serial foreground dispatch (one codex at a time), the race surface is closed — concurrent PostToolUse events do not happen in practice, so this finding is theoretical. CC-036 opens async parallel dispatch from main thread, which makes concurrent PostToolUse events routine; CC-037 must close before CC-036 ships or land in the same PR. Until CC-036 is picked up, no production impact.
**Override-record**: User explicitly accepted bounded, silent loss of routing calibration telemetry for PR #55 merge on 2026-05-15, per gate result `.gate-results/gate-20260515-174253.md` "Override path" clause. Both `/pr-gate` reviewers (qa-tester + risk-reviewer) downgraded to block-soft after PR #55 fix round; CC-037 remains tracked here as follow-up.

## CC-036b — dispatch handover authorized-override reconciliation

**Problem**: `scripts/lib/handover-validate.sh` hard-rejects `skip_git_check: true`, `sandbox: danger-full-access`, and any `approval` value other than `never`. But `docs/codex-brief.md` and `commands/pm.md` describe these as caller-authorized overrides — implying an escape hatch exists. Today there is NO escape hatch: the validator's `handover_validate_all_metadata` returns 1 with no authorized-override branch, so PM cannot emit those metadata values even with explicit user authorization. Spec ↔ behavior mismatch.

Additionally, `commands/pm.md:13` shows the illustrative dispatch command WITH `--skip-git-check`, while line 16 says to omit the flag when `skip_git_check: false` (the default). A maintainer copying the template literally would bypass the git check.

**Why**: surfaced as critic medium + low in CC-036 final gate (2026-05-16, `.gate-results/gate-20260516-010223.md`). Both are advisory, non-blocking, but they document a real inconsistency that will bite the first time someone needs `skip_git_check: true` for a non-git workdir or `danger-full-access` for an install-to-`~/.claude/` brief.

**Requirement**: pick one path:
1. **Add authorized-override channel**: extend handover metadata with `override_authorized_by: <user|caller>` (or similar) field; validator accepts dangerous values only when paired with the authorization field; add per-field tests for authorized + unauthorized branches.
2. **Remove from docs**: declare flatly that the bash route does NOT support these overrides; if the caller needs them, fall back to `Agent(codex-executor)` with `--sandbox danger-full-access` etc. passed as flags through the executor's existing override mechanism. Tighten `docs/codex-brief.md` + `commands/pm.md` wording.

Plus: revise `commands/pm.md` example to be default-safe (omit `--skip-git-check`) and document conditional flag insertion separately.

**Source**: 2026-05-16 CC-036 final gate critic advise findings.

**Closed 2026-05-16**: Plan-2 alignment applied; bash route docs/messages now direct dangerous-flag needs to Agent(codex-executor) fallback. PR pending.

## CC-040 — agent-agnostic dispatch schema rename ✅ 2026-05-16

**Problem**: CC-036 ships the new dispatch flow with **codex-specific naming throughout**：
- `docs/codex-brief.md` (schema doc)
- `codex_dispatch_handover_v1` (handover block tag, PM→main-thread)
- 多處 cross-reference 寫死 "codex"

But the brief SCHEMA itself（`working_dir` / `goal` / `files` / `constraints` / `self_verify` / `acceptance`）是通用的——任何 coding executor（aider、openhands、未來的 in-house tools）都能消費同樣形狀。把命名綁死在 codex 上，未來新增 executor 就要做大範圍 rename + 跨檔 sync，成本被推遲到那時。

**Why**: 2026-05-15 user 在 CC-036 設計階段點出「brief.md 好像不需要特別寫給 codex 這樣之後其他的 agent 都可以順利套用 而不是被固定給 Codex」。當下 CC-036 流程已 in-flight、scope 已凍結，所以決議「先不全改、寫進 backlog」— 保留命名一致性、避免 CC-036 PR 範圍爆炸。但通用化是正確方向，留著當下次自然 trigger 時的改造機會。

**Trigger conditions**（什麼時候真的該動）：
1. 新增第二個 executor（例如 aider/openhands/in-house worker）— 強 trigger
2. 對外開源前 polishing — `codex-brief` 在外部觀感上把 pm-dispatch 跟單一商業工具綁死
3. 任何時候有人想 retire codex CLI 換成別的工具 — 強 trigger

**Requirement**: 三組工作：
1. **檔案重命名 + handover tag 重命名**：
   - `git mv docs/codex-brief.md docs/dispatch-brief.md`
   - 所有引用 `docs/codex-brief.md` 的檔案改路徑（grep -rl）
   - `codex_dispatch_handover_v1` → `dispatch_handover_v1`（doc + agent + 任何 hook 內的 string match）
2. **Handover schema 加 `executor:` 欄位**：
   - 預設值 `codex`；新欄位寫入 `agents/project-pm.md` instruction、`commands/pm.md` doc、`docs/dispatch-brief.md` schema
   - 對應 mapping：`executor: codex` → `scripts/codex-dispatch.sh` (bash route) / `agents/codex-executor.md` (agent route)
   - 顯式聲明「目前僅支援 codex；其他 executor 需新增對應 dispatch script + agent」
3. **保留 codex-specific 命名的範圍**：
   - `scripts/codex-dispatch.sh` 不重命名（**這支腳本就是包 codex CLI**）
   - `agents/codex-executor.md` 不重命名（這個 agent 知道 codex 124 retry / .last 0.128 quirk）
   - `feedback_codex_dispatch_lifecycle_leak` memory 保留（leak **就是** codex-specific bug）

**Migration safety**: 因 handover tag rename 涉及 PM agent 的 prompt template，**現役 session 在 transition 期間可能看到舊 PM 回新 tag 或新 PM 回舊 tag**。建議在同一 PR 中：
- 同步改 PM agent + 改 main-thread parser（commands/pm.md）
- 避免老 episodes.jsonl replay — hard cutover
- 加 `handover_version: 2`（可選）標示 schema 變動，main-thread parser 可同時識別 v1 與 v2

**Cross-link**: triggered by CC-036 design discussion 2026-05-15。CC-036 本身用 codex-specific 命名 ship，由本條目記錄通用化欠款。**不阻塞當前 release**。
**Outcome**: 2026-05-16 — Atomic breaking-change rename via PR #66: fence tag → `dispatch_handover_v1`, doc → `docs/dispatch-brief.md`, `handover_version: 2` (v1 rejected), required `executor:` enum {codex}. No dual-recognition. 5 new boundary tests; PR-gate r1 GO (critic advise / qa approve / arch approve).
**See**: pr:#66

## CC-039 — shared-schema brief enrichment + `/pre-impl` Q4 repo-rule audit + fix-brief next-layer sweep

**Outcome**: 2026-05-18 — PR #83 implemented the shared-schema checklist, `/pre-impl` Q4 repo-rule audit, and fix-brief next-layer sweep guidance.
**See**: pr:#83

**Problem**: japanese-site JS-110（furigana.title_ja `Pair[]` → `Token[]` shared-schema spike）即使在 `/pre-impl` + 既有 `[[shared_schema_briefs]]` 規則加持下，仍跑了 6 輪 PR gate 才達到 GO 狀態。每輪 emerging finding 中相當比例可追溯到三個系統性 brief-authoring 缺口：

1. **Brief 漏項（5/6 輪可預先寫入）**：
   - 既有防禦性 pattern 沒對齊（renderer 對舊 `FuriganaPair[]` 有 `isRenderableFuriganaPair` filter，新 Token[] brief 沒要求等價 filter → Round 1 critic high）。
   - 治理/契約層 surface 未列入 brief（`/api/version` API-002 規則沒考慮 → Round 6 critic high；ADR 既有文件 supersession 沒列 → Round 1 critic medium；舊文件早段範例對齊 → Round 2 critic low）。
   - 共用型跨 domain 影響漏盤（pre-impl Q2 surface map 已標 `apiTypes` 共用，但 brief scope 漏列 vocab-side lint → Round 3 architecture high）。
   - **Brief 內部一致性**：brief 自身 constraint 描述（strip-then-round-trip）與 brief 自身 ADR example 描述（full-string round-trip）打架 → Round 4 critic + architecture cross-overlap block-soft。

2. **`/pre-impl` skill Q1/Q2/Q3 未掃 repo-wide invariant**：
   - 沒讀 `rules/global/*.md`（API-002 / UI-003 / 等 NNN-rules）。
   - 沒列出本 brief 觸發的所有 NNN-rule 對應檢查。
   - 沒檢查文件治理慣例（哪些 ADR 描述舊 shape、是否需要 supersession + DECISIONS.md）。

3. **每輪 fix brief 只 address 前輪 finding、無 proactive 下一層 sweep**：reviewer 注意力資源有限呈「洋蔥剝皮」狀（先看 immediate diff bug → 修完才看下一層 contract → 再下一層 governance）。fix brief 若同時主動掃「這次修動是否觸發更深層議題」，可壓縮收斂輪數。

**Why**: 量化：6 輪 gate ≈ 25 min × 6 = 2.5 hr review。若初始 brief 多投入 30 min 跑下面 checklist + `/pre-impl` 多 1 個 Q4，估算可省 4–5 輪 = 75–100 min（ROI 3–4x）。已有 `[[shared_schema_briefs]]` 主規則但只強制 "全表面 audit"，缺**具體可勾選 checklist** 與**governance dimension**。

**Requirement**:
1. 新增 `rules/global/shared-schema-checklist.md`（或 append `[[shared_schema_briefs]]` body），列出強制 checklist：
   - □ `/api/version` 影響：wire shape 變了嗎？bump milestone？(API-002)
   - □ ADR 治理：哪份 ADR 文件記載舊 shape？brief 是否列入 supersede + DECISIONS.md / 新 ADR？
   - □ 防禦性 runtime parity：舊 shape 有 `isRenderable*` filter / validator 嗎？新 shape 等價物在 brief 嗎？
   - □ 共用型 audit：`apiTypes`/schema 中的 type 是否被多個 domain 引用？(grammar/vocab/quiz/classifier)，每個 domain 的 lint + tests 都列入 brief 嗎？
   - □ Brief 內部一致性：constraint vs ADR example 描述同一規則嗎？regex 是否 byte-identical？
   - □ Test fixture 全 sweep：跨檔 grep 舊 shape fixture（renderer / annotations-invariant / staticApi 等），全進 brief 還是漏？
   - □ CLI flag 加新 mode：負面測試（invalid value → exit code）在 brief 嗎？
2. 擴充 `commands/pre-impl.md` 加入 **Q4：Repo-wide invariant audit**：
   - 讀 `rules/global/*.md` + `rules/domain/<domain>.md`
   - 列出與本 brief 相關的 NNN-rules（API-002 / UI-003 等）
   - 明確將每條 rule 對應的檢查放進 brief constraints
3. 在 `docs/dispatch-brief.md` 或 `agents/project-pm.md` 加入 **fix-brief 撰寫指引**：
   - 不只 address 上輪 finding，主動跑 1 個 follow-up 思考：「這次修動是否觸發更深層議題？」
   - 範例 trigger：修 ADR supersede → 同步掃 ADR 全文舊範例；升級 lint → 掃 spec/code 對齊；改 wire shape → 掃 API version、cache、external-client 影響。

**Source**: 2026-05-15 japanese-site JS-110 6-round gate convergence post-mortem。對應 [[shared_schema_briefs]] 既有規則的補強（不是取代）。
**Note**: 實作前可選 `/pre-impl`，但本 ticket 本身是 process 改進（rules + commands + docs），無 schema 變動，可直接寫 brief。
**Cross-link**: [[shared_schema_briefs]] 主規則 + CC-022 `/pre-impl` 既有 skill。

---

**2026-05-18 追加案例：CC-013（7 輪 gate）**

CC-013（`/caveman` + agent brevity）出現了與 JS-110 不同觸發條件但相同收斂模式的「洋蔥剝皮」現象。差異點：

- JS-110 的根因是「shared-schema 跨 domain 影響面未事先盤點」
- CC-013 的根因是「**新功能 + 對應 contract test script 在同一 PR 新增，但沒有事先列出 behavioral contract 清單**」

CC-013 的七輪逐步修補路徑（每輪 1–2 個缺口）：

| 輪次 | 阻擋原因 |
|------|---------|
| R1 | 命令行為設計問題（no-state-tracking 措辭、breaking-change 格式）+ 完全沒有測試 |
| R2 | `--filter` 無參數無限迴圈、零匹配靜默通過、CI 未接線 |
| R3 | `assert_frontmatter` 漏檢 closing `---`、brevity 未限定在 section 內、未知 flag 靜默忽略 |
| R4 | 7 種 commit type 只測 3 個；`Caveman mode: <MODE>` 確認輸出未測 |
| R5 | `$ARGUMENTS` hint 行為未覆蓋；使用說明與實際輸出不符 |
| R6 | agent brevity 的 `no closing summary` 規則未測 |
| R7 | **GO** |

**CC-039 Requirement 補充項（已確認的新子模式）**：

在 Requirement 清單追加：
- □ **同 PR 新增 contract test script 時**，先逐條列出被測命令的所有 behavioral contract（空參、無效參數、每條輸出格式、每個 type/flag、每個 section 中的規則），再寫 assertion——不能邊寫邊補。適用於 `test-commands.sh`、`test-hooks.sh` 等 contract test 類腳本。

## CC-025b — `/skill-refine` M1+M2 advisory follow-ups（deferred）

**Problem**: CC-025 M1 (PR #67) 與 M2 (`commands/skill-refine.md`) PR-gate 留三條 advisory，未阻擋 GO 但屬已知缺口需追蹤：
1. (qa-tester / M1) `scripts/skill-refine.sh:11-14` 的 `$# -ne 1` usage guard 無 behavior test — 0-arg 與 multi-arg invocation 沒有 exit-code + stderr shape 的斷言，CLI 行為退化會無察覺通過。
2. (critic + architecture-reviewer / M2) `commands/skill-refine.md:24-29` 與 `scripts/skill-refine.sh:29-36` — slash command spec 沒揭露 `CLAUDE_MEMORY_DIR` 是 mandatory env；外部 shell 沒設此變數直接執行 `/skill-refine <name>` 會 hard-fail，違反「slash command 文件 = user-facing contract」原則。隱藏 runtime coupling。
**Why**: Claude Code 環境通常已 export `CLAUDE_MEMORY_DIR`，所以 PR-gate 與 critic 都標 advise 而非 block；但對 fresh dev shell / CI / 跨機器 dogfood 場景仍是 footgun。`feedback_known_bug_backlog` 要求 deferred advisory 進 backlog；`feedback_validator_dryrun_before_strengthen` 同精神 — 先把 contract 寫清楚再給更多人用。
**Requirement**:
1. `scripts/test-skill-refine.sh`：新增至少兩個 case — `no_args_exits_2_with_usage` + `multi_args_exits_2_with_usage`，斷言 exit code + stderr 含 `Usage:` token。
2. Choose one of：(a) `commands/skill-refine.md` body 加 prerequisite section 明示 `CLAUDE_MEMORY_DIR` 需 export（含 `${HOME}/.claude/projects/.../memory` 範例路徑）；OR (b) `scripts/skill-refine.sh` 在 env 未設時嘗試 default fallback 路徑（依 Claude Code 預設 layout，例如 `${HOME}/.claude/projects/-home-<user>-github/memory`，找不到再 exit 2）。(a) 與 (b) 互斥，建議先 (a) 因 zero code change。
3. （可選）PR-gate brief 加 sanity check：跑 `unset CLAUDE_MEMORY_DIR; bash scripts/skill-refine.sh pr-gate` 期望 exit 2 + 明確 hint，作為 fresh-shell smoke。
**Source**: 2026-05-17 gate-20260517-155611.md（M2 PR-gate r1 GO advisory）。
**Note**: 兩條 advise 共享 root cause（env contract 沒文件化），所以同票處理；fix 後 M2 follow-up close。
**Cross-link**: [[feedback_known_bug_backlog]] / [[feedback_native_perspective]] 衍生「文件化 user contract」原則。
**M2 follow-up**: diff generation and Claude-assisted refinement scope is tracked under CC-054.

## CC-047 — `scripts/codex-dispatch.sh` model alias mapping

**Problem**: `bash scripts/codex-dispatch.sh --model codex-spark ...` 失敗 — codex CLI 收到 `-m codex-spark` 後丟 `400 invalid_request_error: The 'codex-spark' model is not supported when using Codex with a ChatGPT account`。實際合法 model ID 為 `gpt-5.3-codex-spark`（user `~/.config/codex/config.toml` 預設值），而 PM agent / `/pm` 出的 brief 持續用短名 `codex-spark` 描述 routing 決策。短名與 wire-format ID 不一致導致 dispatch 一律 hard-fail。
**Why**: 兩件事必須對齊：(1) PM 用 short alias（`codex-spark`）描述決策邏輯，符合 `[[feedback_codex_routing]]` Q1/Q2/Q3 表的命名習慣；(2) wire-format API 只認全名 `gpt-5.3-codex-spark` + reasoning effort `high`。當前 dispatch script 第 134 行 `CMD+=(-m "$MODEL")` 純字串透傳，沒有 alias 表。每次 PM 寫 `codex-spark` 都會踩雷。tactical workaround 是 brief author 改用全名或留空（讓 codex config default 接手），但這把對齊責任推給 brief author。
**Requirement**:
1. `scripts/codex-dispatch.sh` 加 alias resolution layer：定義 alias → `<full-model-id>:<reasoning-effort>` 映射表（初版至少 `codex-spark` → `gpt-5.3-codex-spark` + `model_reasoning_effort=high`），未在表中的字串 fallback 為原樣透傳。
2. 同步處理 reasoning effort：用 `-c model_reasoning_effort=...` 透傳（CLI 支援的 config override 形式）或別的等效機制；確認 spark 短名解析後 effort 確實送達 codex。
3. `docs/dispatch-brief.md` / `agents/project-pm.md` 加 alias 對照表，明示 PM 可繼續用短名、wire-format 對齊由 dispatch script 負責。
4. 加 1-2 個 `scripts/test-codex-dispatch.sh` 行為 case：(a) `--model codex-spark` 預期 alias 解析後 `CMD` 含 `gpt-5.3-codex-spark`；(b) `--model gpt-5.3-codex-spark` 預期原樣透傳；(c) `--model unknown-tag` 預期 fallback 原樣（保留現行行為）。
**Source**: 2026-05-17 CC-025 M2 dispatch first attempt — task `b6vuj0gns` exit 1，trace `.agent-trace/codex-20260517-154951-18117.jsonl`，stderr 顯示 `400 invalid_request_error`；第二次重派移除 `--model` 走 codex config default 成功（task `bsvdlt7xr`）。User 在後續 turn 確認 `gpt-5.3-codex-spark high` 是其 codex CLI 慣用設定。
**Note**: 純 dispatch script 內部變更，無需動 PM agent 或 brief schema。實作前可參考 codex 官方 CLI doc 確認 `model_reasoning_effort` config override 對哪些 model family 生效。
**Cross-link**: [[feedback_codex_routing]] Q1/Q2/Q3 表 + [[feedback_bash_route_approval_never]] 同精神 — dispatch script 負責把 PM 短語映射成 wire-format。

---

# CC-OSS Epic — Open-source pm-dispatch（CC-100 to CC-105）

**Epic goal**: 把 pm-dispatch 從個人 audience-of-one 工具開源成 public GitHub repo，讓 Windows-only / 不用 WSL2 / 不用 Codex / 純 Claude Code 使用者能 onboard。

**Audience shift**: 從 [[project_japanese-site_audience]] 的 audience-of-one 模型 → 多人 public 模型。但仍保留現有 user 的 codex-using workflow 不破壞（codex 變 opt-in profile）。

**Sequencing**: Phase 1 → 2 → 3 → 4 → 5，**嚴格串行**。Phase 2 設計變更會碰 brief schema 與 dispatch flow，必須在 Phase 1 sanitize 完成後再動；Phase 3 portability shim 依賴 Phase 2 codex-optional 設計才有意義（不然 Windows user 仍會撞 codex requirement）。

**Cross-link**: [[project_pm-dispatch]] / [[breaking-change for maintainability]]（codex-optional 用 additive `executor:` 欄位 + 預設值切換，不破壞既有 schema）。

## CC-100 — [CC-OSS Phase 1] Sanitize personal paths + OSS-baseline docs

**Problem**: 6+ production files（`commands/pm.md` / `agents/project-pm.md` / `agents/codex-executor.md` / `docs/dispatch-brief.md` / `scripts/codex-dispatch.sh` / `README.md`）含 `/home/<user>/github/pm-dispatch` 硬編碼絕對路徑；外部 contributor 讀 README 與範例會看見「Lien 的個人桌面」而非通用設計。`CONTRIBUTING.md` / `CODE_OF_CONDUCT.md` 缺；LICENSE (MIT) 已存在但未在 README 標示。
**Why**: 開源第一條原則是「repo 看起來不像某人的 dotfiles」。Sanitize 是後續 phase 的前提 — 沒做 phase 2 的範例會把 `/home/<user>` 越寫越多。
**Requirement**:
1. 所有 production files（排除 `scripts/test-*.sh` fixtures 與 `BACKLOG.md` / `CHANGELOG.md`）的 `/home/<user>/github/pm-dispatch` 改為 `${PM_DISPATCH_REPO}` placeholder。
2. `scripts/install-hooks.sh` 新增 `PM_DISPATCH_REPO=${PM_DISPATCH_REPO:-$(git rev-parse --show-toplevel)}` 預設值；未設 env 時用 git toplevel 自動推斷。
3. 新增 `CONTRIBUTING.md`（~100 行：branch flow、PR-gate workflow、brief schema pointer 到 `docs/dispatch-brief.md`、Conventional Commits 約定）。
4. 新增 `CODE_OF_CONDUCT.md`（Contributor Covenant 2.1 verbatim）。
5. `README.md` 補一段 "Personal paths in examples use `${PM_DISPATCH_REPO}`" 說明 + LICENSE badge。
**Self-verify**: `grep -rn "/home/<user>" --include="*.sh" --include="*.md" | grep -v "scripts/test-" | grep -v "BACKLOG.md" | grep -v "CHANGELOG.md"` 必須 0 hit（`<user>` = 維護者 local username）。
**Acceptance**: 上 grep 0 hit；既有 `scripts/test-hooks.sh` + `scripts/test-codex-dispatch.sh` 全綠（無 behavior change）；fresh clone 跑 `bash install.sh --dry-run` 結果與 PR 前一致（除 `PM_DISPATCH_REPO` 自動推斷訊息）。
**Note**: 純 rename + 新 docs，**zero behavior change**。Backwards-compat：`PM_DISPATCH_REPO` 未設時 fallback 至 `git toplevel`，現有 user 無感。
**Cross-link**: [[breaking-change for maintainability]] 此票走 additive env contract，不破壞既有 user。

## CC-101 — [CC-OSS Phase 2 spike] Executor-contract schema + adapter design

**Problem**: 當前 PM agent brief 直接寫 codex-specific 欄位（`sandbox` / `approval` / `model` / `dispatch_route: main_thread_bash_background`）；`commands/pm.md` 整段 dispatch route 都寫死 codex。若要讓不裝 codex 的 user 也能用 PM/brief 流程，schema 必須抽象化執行端。
**Why**: CC-040 已做了部分 schema rename（`dispatch_handover_v1` 通用化、`executor:` 欄位預留）；本 phase 把 spike 延伸成完整 executor adapter contract。
**Requirement**:
1. 新檔 `docs/executor-contract.md`：abstract executor interface（input = brief markdown + metadata；output = file diff + test evidence + report）。
2. brief metadata schema 加 `executor: claude-main | codex` 欄位；schema validator (`scripts/lib/handover-validate.sh`) 識別。
3. 設計（不實作）`claude-main` executor 的執行語意：main thread Claude 讀 brief → 用 Edit/Write/Bash 完成 acceptance steps → 觸發 reviewer pipeline。文件化於 `docs/executor-contract.md`。
4. `agents/project-pm.md` 補 "Executor selection" 段，說明預設依 install profile 決定。
5. Spike output：design doc（不動 code），讓 CC-102 impl 有清楚契約可實作。
**Acceptance**: `docs/executor-contract.md` 含 input/output 契約 + 兩個 executor profile (codex / claude-main) 對照表；`scripts/lib/handover-validate.sh` 接受 `executor:` 欄位且預設 codex（backward-compat）；無 runtime behavior change。
**Note**: 純 spike，不動 dispatch 行為。impl 在 CC-102。
**Cross-link**: [[project_pm-dispatch]] hooks-as-policy / [[feedback_codex_routing]] / CC-040 schema rename。

## CC-102 — [CC-OSS Phase 2 impl] `claude-executor` agent + install profile

**Problem**: CC-101 設計完 contract，CC-102 實作 `claude-main` executor 路徑與 install profile 切換。同事不裝 codex 要能跑完一個簡單 `/pm` task。
**Why**: 完成 codex-optional 架構的「實際可跑」里程碑。
**Requirement**:
1. 新 agent `agents/claude-executor.md`：受 brief → main thread Bash/Edit/Write 完成 acceptance → 跑 reviewer pipeline；不呼叫任何 codex script。
2. `commands/pm.md` 拆兩條路徑：`executor: claude-main`（預設，新 user）走 claude-executor；`executor: codex`（既有 user）走 codex-dispatch.sh。
3. `scripts/install-hooks.sh` 加 `--profile minimal|full` flag：minimal 跳過 `hook-codex-bash-guard.sh` / `hook-codex-write-guard.sh` 註冊；full 維持現狀。
4. `install.sh` 加 `--profile` passthrough；`README.md` 寫明選法。
5. Backwards-compat：未指定 `--profile` 偵測 codex CLI 是否存在 → 有 = full、無 = minimal。
**Self-verify**:
- `scripts/test-hooks.sh` 全綠（既有 codex flow 不破壞）
- 新增 test：`scripts/test-claude-executor.sh` 跑一個 trivial brief（無 codex），exit 0
- `install.sh --profile minimal` 結果不註冊 codex hooks（grep settings.json）
**Acceptance**: fresh user 不裝 codex 能跑完 `/pm "add hello.sh that echoes hello"` task → claude-executor 完成 → reviewer pipeline 跑 → PR-gate 通過；既有 codex flow 全 regression pass。
**Note**: 風險最高的 phase，建議自己（user）親自驗 codex flow 不破；同事驗 minimal flow。
**Cross-link**: CC-101（spike） / [[Subagents cannot spawn subagents]]（claude-executor 設計要注意 main thread vs subagent 邊界）。

## CC-103 — [CC-OSS Phase 3] Portability shim + Windows / Git Bash 支援

**Problem**: 3 個 hook（`hook-pm-write-guard.sh` / `hook-codex-bash-guard.sh` / `hook-codex-write-guard.sh`）依賴 `realpath -m`（Git Bash 預設無）；`hook-routing-log.sh` 依賴 `flock`（Git Bash 無）；`scripts/handover-validate.sh` 假設 `/tmp/brief-*.md` 路徑模式。Windows-only user 即使裝了 Git for Windows + Git Bash + jq 也會撞這些 Linux-only 用法。
**Why**: Phase 3 是「同事真能用」的硬門檻。Phase 2 把 codex 拔掉後，剩下的 Linux-only bash 用法是最後障礙。
**Requirement**:
1. 新 `scripts/lib/portable.sh`：`realpath_m()` / `safe_tmpdir()` / `mkdir_lock()` 三個 shim；偵測 platform 走最佳實作（Linux=原生 / macOS=`realpath` via coreutils / Git Bash=純 bash 實作）。
2. 改寫 3 個 codex/pm hook 用 shim。
3. `hook-routing-log.sh` 的 `flock` 改 `mkdir_lock`（atomic mkdir-based lock，跨平台）。
4. `scripts/install-hooks.sh` 偵測 platform；Windows 上跳過依賴 Linux-only utility 的 hook（或標 warning）。
5. 新檔 `docs/platform-support.md`（~80 行）：Linux/macOS = first-class、WSL2 = same as Linux、Windows Git Bash + minimal profile = supported、其他 = best-effort。
6. 列出 Windows user 需要手動裝的 deps：`winget install jqlang.jq`、Git for Windows extras 含 coreutils、PowerShell 7 optional。
**Self-verify**:
- `scripts/test-hooks.sh` 在 Git Bash on Windows 全綠（或標明哪些跳過 + 為什麼）— 需 Windows dogfood
- `scripts/lib/portable.sh` 個別函式有 unit test（`scripts/test-portable.sh`）
**Acceptance**: fresh Win11 + Git for Windows + jq + Claude Code 能完成「clone → install.sh --profile minimal → invoke /pm "trivial task"」一條 path；`docs/platform-support.md` 含 step-by-step。
**Note**: 你不在 Windows，這 phase 後半段依賴同事 dogfood。建議 phase 結束前讓同事跑一輪並 report friction，再 close。
**Cross-link**: BACKLOG CC-037 `hook-routing-log.sh` flock portability（既有 deferred item，本 phase 順手解掉）/ [[breaking-change for maintainability]]（shim 是 additive，無 schema 變更）。

## CC-104 — [CC-OSS Phase 4] Onboarding docs batch

**Problem**: 同事「用過 Claude Code 但沒碰 hooks/agents/skills」。沒有 onboarding doc 直接讀 `agents/project-pm.md` 會 lost；需要從 hooks-as-policy / subagent / slash command / memory 四概念開始的入門路徑。
**Why**: Phase 1-3 完成後，技術上可跑；但「同事看完不會用」就等於沒開源。docs 是 last-mile UX。
**Requirement**:
1. `README.md` rewrite（200-300 行）：what / why / 5-min quickstart / 連到 GETTING_STARTED 與 CONCEPTS。
2. `docs/GETTING_STARTED.md`（150-200 行）：clone → install → first `/pm` 一條 path；含 troubleshooting。
3. `docs/CONCEPTS.md`（250-350 行）：hooks-as-policy / subagent / slash command / memory tiers 四概念；給沒碰過的讀者。**user 起 30 分鐘 brain-dump 第一版**（design intent 你最懂），Claude 補結構與範例。
4. `docs/memory-system.md`（100 行）：memory dir 在哪、為何 per-project、如何 bootstrap empty、symlink 進 private repo 的 pattern（不曝光私人路徑）。
5. 既有 `commands/*.md` 補強：每個 slash command 補 "What / When to use / Example" 三段（codex 用 `/skill-refine` 走 brief flow，逐一處理）。
**Self-verify**: 同事在不問 user 的前提下，從 README → GETTING_STARTED → 第一個 `/pm` 成功 dispatch trivial brief；用 record-feedback 方式回報哪一段卡住。
**Acceptance**: 上述 5 個 doc 條件 + `commands/*.md` 全部補完三段；fresh reader 走 GETTING_STARTED 能 0-error 跑到 first PR。
**Note**: CONCEPTS.md 是 critical path 且 user 必須親自起草第一版。其他 4 份可派發。**本票第一階段先草 CONCEPTS.md draft（main thread Claude 起草 + user 審）**，其餘 docs 在 Phase 3 完成後再啟動。
**Cross-link**: [[project_japanese-site_japanese-first]] 同精神 — 預設 surface 對主 audience 友善；本 repo 主 audience = 多人 OSS。

## CC-105 — [CC-OSS Phase 5] BACKLOG cleanup + v0.1.0 public release

**Problem**: BACKLOG 含多條 user-specific 項目（CC-011 sync-memory 到雲端、CC-012 SessionStart pull memory、CC-013 caveman skill 等）不適合 public roadmap；`.agent-trace/` / `.codex-briefs/` / `.gate-results/` 是 working-dir artifact 不該進 public history；private→public visibility 切換不可逆。
**Why**: Phase 1-4 完成後做最後 cleanup + 正式 release。一切都要可逆性檢查 + dry-run。
**Requirement**:
1. audit BACKLOG.md：標 `personal/` prefix 或刪除（CC-011 / CC-012 / CC-013 等 user-specific）；保留通用 ops/process 條目。
2. `.gitignore` 補 `.agent-trace/` / `.codex-briefs/` / `.gate-results/` / `*.bak`；確認既有 commit history 無 leak（若有，BFG 或 git-filter-repo 處理）。
3. 新檔 `CHANGELOG.md` v0.1.0 section：列出 CC-OSS phase 1-4 全部 PR + key feature inventory。
4. 在 dry-run 個人 repo `pm-dispatch-public-dryrun` 試跑一遍同事 onboarding flow（clone → install → /pm）；確認 0-friction 再切 main repo。
5. GitHub repo settings：private → public；**切 public 後立刻啟用** main branch protection（require linear history；不啟用 require-PR 因為 source-available 模式 maintainer 直推 main 是合法路徑）。**Sequencing constraint**: GitHub free tier 私人 repo 無 branch protection 功能，必須先切 public 才能啟用此設定（user 已確認 2026-05-17）。
6. tag `v0.1.0` + GitHub release（含 release notes 引用 CHANGELOG）。
**Acceptance**: repo public；同事能 fork、clone、按 GETTING_STARTED 跑完；CHANGELOG v0.1.0 紀錄完整；無歷史 leak。
**Note**: 切 public 是**不可逆**操作（star/fork 後 history 永遠 public）。Step 4 dry-run 是 hard requirement，不能跳。
**Stance**: pm-dispatch 採 **source-available** 模式（policy 已寫入 CONTRIBUTING.md 2026-05-17）— public for visibility，外部 PR 不受理，issue 開放無 SLA。本 ticket 因此**不**包含 GitHub issue/PR templates / CODEOWNERS / require-PR branch protection（這些是 open-contributor 模式才需要）。若未來轉 open-contributor，補開 follow-up ticket。
**Cross-link**: [[gate-architecture-not-data]]（這票多數是 docs/config 改動，gate 找對 reviewer 即可，不要對 BACKLOG 條目重審）。

## CC-103b — /pr-gate executor split (closed 2026-05-17)

**Outcome 2026-05-17**: `/pr-gate` now routes through `executor` selection via
`--executor codex|claude|auto`; minimal-profile users can run the full gate workflow
without `codex` installed.

1. `scripts/pr-gate.sh` added route-aware dispatch for all `codex-dispatch.sh`
   call sites.
2. `--executor auto` resolves by `command -v codex` and remains the default.
3. New `pr-gate-handover_v1` schema documented in `docs/pr-gate-handover-schema.md`.
4. `commands/pr-gate.md` updated with Route A (codex) and Route B (claude) orchestration.
5. Direct e2e regression coverage added in `scripts/test-pr-gate-profile.sh`.

**Problem**: CC-103 made `/pm` portable, but `/pr-gate` still hard-depended on
codex dispatch and had no main-thread fan-out shape for minimal-profile users.

**Why**: This blocks the same portability objective CC-102 delivered for PM: users
with minimal profile still needed codex for gate execution and could not complete PR
review cycles in-place.

**Cross-link**: CC-102 + CC-103 + [[project_pm-dispatch]]

## CC-102b — CC-102 PR-gate advisory follow-ups（closed 2026-05-17）

**Outcome 2026-05-17**: CC-102 PR-gate r2 升 block；advisory 全 fold-in 進 CC-102 同 PR：
- `scripts/install-hooks.sh` jq 段加 minimal profile downgrade pass（match basename + scripts/ parent，remove 既有 codex guard hooks + 清空 matcher block）
- `scripts/test-install.sh` 加 4 case：`install-sh-profile-minimal-skips-codex-hooks` / `install-sh-profile-full-wires-codex-hooks` / `install-hooks-profile-downgrade-removes-codex` / `install-hooks-profile-invalid-value-rejected`
- `CONTRIBUTING.md` test inventory 加 `test-install.sh` / `test-claude-executor.sh` / `lint-scripts.sh` / `lint-agents.sh`

**原始 Problem** (CC-102 PR-gate gate-20260517-202651.md r1 留下；r2 gate-20260517-203505.md qa-tester 升 high block，依 gate-driven design 必須 fix in-PR)：
1. (qa-tester) `install.sh --profile minimal|full` + auto-detect (`command -v codex`) 沒有直接 e2e regression test
2. (architecture-reviewer) `scripts/install-hooks.sh` minimal profile 只 skip 插入 codex guard hooks，不會 remove 已存在的；用 `--profile full` 安裝後再 `--profile minimal` rerun，settings.json 不會 converge 到 minimal contract
**Why**: qa-tester r2 verdict: "add regression tests for --profile minimal/full installer behavior and reversible/downgrade semantics" 是 NO-GO 必修。
**Cross-link**: [[feedback_known_bug_backlog]] — backlog-only deferral 不足以滿足 qa-tester；future code-affecting advisory 應直接 fold-in 同 PR。

## CC-053 — `test-commands.sh` CLI self-test coverage ✅ 2026-05-18

**Outcome**: Added self-tests for `--filter`, `--list`, unknown option (non-zero + error message), and zero-match filter behavior in `scripts/test-commands.sh`.
**See**: pr:#84

## CC-055 — `commands/pr-gate.md` frontmatter YAML syntax fixed ✅ 2026-05-18

**Outcome**: `argument-hint` value in `commands/pr-gate.md` frontmatter quoted as YAML string, resolving GitHub YAML parse error.
**See**: pr:#86

## CC-056 — `scripts/lint-frontmatter.sh` + CI job + 12 regression tests ✅ 2026-05-18

**Outcome**: New `scripts/lint-frontmatter.sh` validates YAML frontmatter in `agents/*.md` and `commands/*.md`. CI `lint-frontmatter` and `test-lint-frontmatter` jobs added. PyYAML dep declared.
**See**: pr:#86

## CC-057 — README `skills/` layout row + `update-config` ref removed ✅ 2026-05-18

**Outcome**: Removed `skills/      → ~/.claude/skills/` row from README layout table and `(or use the `update-config` skill)` parenthetical. Pending CC-061 to create the actual directory.
**See**: pr:#86

## CC-049 — BACKLOG hygiene Tier 1 archive closed detail sections ✅ 2026-05-18

**Outcome**: Moved 37 closed ticket body sections to BACKLOG-ARCHIVE.md; added archive stubs with `**See**: BACKLOG-ARCHIVE.md` for all 39 closed tickets. Reduced BACKLOG.md from 867 → 573 lines. Validator updated with `🟡 deferred` / `🟢 someday` status tokens; pm/schema.md and test fixtures updated.
**See**: pr:#87

## CC-050 — BACKLOG hygiene Tier 1 stale deferred audit ✅ 2026-05-18

**Outcome**: CC-011/012 → `🟢 someday`, CC-014/015 → `🟡 deferred` with CC-050 audit status notes. Five pending PR status corrections applied: CC-005 (pr:#85), CC-053 (pr:#84), CC-055/056/057 (pr:#86).
**See**: pr:#87

## CC-051 — BACKLOG schema convention preamble ✅ 2026-05-18

**Problem**: BACKLOG.md uses ID gaps, sub-letter IDs, and multiple status emoji without a compact convention preamble. Fork readers have no way to understand the naming conventions.
**Why**: Conventions emerged organically. Without documentation, `CC-1NN`/`CC-2NN` groupings and sub-letter IDs look like random gaps and typos to fork users.
**Requirement**: A `## Convention` prose section at the top of BACKLOG.md explains: ID scheme, sub-letter convention, status legend (all 8 tokens), and closed-stub format. Section must appear before archived stubs.
**See**: pr:#88

## CC-104q — codex preflight skip when codex is unavailable ✅ 2026-05-19

**See**: CC-104n

## CC-104u — link_or_copy real-directory dst CONFLICT fix ✅ 2026-05-19

**See**: pr:#100

## CC-104b — platform-aware install hints when jq is missing ✅ 2026-05-17

**See**: pr:#79

## CC-104c — link_or_copy() + install manifest for symlink-unavailable hosts ✅ 2026-05-17

**See**: pr:#89

## CC-104l — install.sh jq prerequisite check ✅ 2026-05-21

**Outcome**: `install.sh` now checks for `jq` immediately after argument parsing and exits with platform-specific install commands before preflight or hook wiring can emit repeated missing-`jq` errors. README install docs list `jq` as a prerequisite before the command block.
**See**: pr:#116

## CC-104t — python3→jq hook refactor; extract scripts/lib/memory.sh ✅ 2026-05-20

**See**: pr:#107

## CC-104p — serialize_with_lock routing-log shim ✅ 2026-05-21

**Outcome**: `scripts/lib/portable.sh` now exposes `serialize_with_lock()`, preferring `flock` when available and falling back to `mkdir_lock` via `FAKE_FLOCK_MISSING=1`-testable path. `hook-routing-log.sh` routes append serialization through the shim. Portable and routing tests cover both lock paths and rc propagation.
**See**: pr:TBD

## CC-104v — copy-mode install summary banner ✅ 2026-05-21

**Outcome**: `install.sh` counts `link_or_copy` rc=1 copy fallbacks and prints one non-dry-run summary banner explaining that source edits do not propagate automatically. Windows Git Bash docs now call out copied helper scripts and the need to re-run `bash install.sh` after updates.
**See**: pr:#116

## CC-030 — `pm/scripts/validate.sh` Index↔Section 雙向一致性 + CHANGELOG drift ✅ 2026-05-19

**Outcome**: validate.sh 實施雙向 Index↔Section 一致性（E-INDEX-MISMATCH 雙向）、closure 日期對齊（E-CLOSURE-DATE-MISMATCH）、CHANGELOG drift（E-CHANGELOG-DRIFT）。bad-orphan-section fixture 補完 direction (b) 覆蓋。38 tests pass。
**See**: DECISIONS.md#2026-05-19-cc030-validate-bidirectional

## CC-031 — 開源前置：CONTRIBUTING.md + SECURITY.md + README 工作語言聲明 ✅ 2026-05-19

**See**: pr:#102

**Problem**: repo 目前缺 `CONTRIBUTING.md`（PR/branching/test 要求）、`SECURITY.md`（vuln 揭露管道）；README 也未說明工作語言為中文 + 英文 commit。轉公開後，外部讀者沒有明確進入點，會在 issue tracker 提不適合的需求或誤解語言預期。
**Why**: 公開的「使用面」前置條件之一；無 CoC 可接受，但 CONTRIBUTING + SECURITY 是 GitHub OSS 慣例 + 法律保護（responsible disclosure 路徑）。和 [[breaking-change for maintainability]] 一致：與其公開後逐個應付外部需求，不如事先寫清楚預期。
**Requirement**:
1. `CONTRIBUTING.md`：PR 流程（必跑 `/pr-gate` + `pm/scripts/validate.sh`）、branch 命名、commit message 風格、test 強制要求、為何不接受 `--no-verify`。
2. `SECURITY.md`：vuln 揭露 email 與不揭露時段；hook bypass / sandbox escape 算 in-scope。
3. README 加 `Working language` 區段：「Primary working language is Mandarin Chinese; commit messages and code identifiers are English. Foreign-language contributors are welcome but should expect bilingual issue threads.」
4. CoC 不放（個人 repo 風險低、避免 boilerplate）。
**Source**: 2026-05-15 對話 — 公開前置盤點 #1。Blocks **CC-033**（public flip）。

## CC-046 — validate.sh + run-tests.sh dedup ✅ 2026-05-19

**See**: decisions:#cc046-validate-dedup

**Outcome**: (a) validate.sh 兩個 awk pass 合併為單一 awk 程式；`parse_status()` / `row_kind[]` 成為唯一的 status 解析路徑，CHANGELOG drift check 直接 consume 同一份 state。`note_index_refs()` 與 `status_kind()` 均刪除。(b) `run_validate_case_multi` 刪除，統一為 varargs `run_validate_case`，34 個 call site 全部遷移。38 tests pass。
**Deferred**: structured behavior/Steps docstring 注解（原 Requirement 3，低優先）— 未做，不影響正確性。如後續認為值得補，可作為獨立 hygiene PR。

## CC-052 — `pm-schema v1.1` BACKLOG schema upgrade ✅ 2026-05-19

**Outcome**: pm-schema v1.1 shipped — `Priority` + `Epic` index columns, validator checks (E-PRIORITY-ENUM / E-EPIC-ENUM / W-MISSING-COLS), all rows backfilled. 36 tests pass.
**See**: pr:#93

## CC-058 — scripts/doctor.sh：環境健康檢查 ✅ 2026-05-22

**See**: PR #119

**Problem**: 沒有單一指令能驗證「pm-dispatch 能否正常工作」。使用者需要逐一排查 claude/codex/jq 是否安裝、hooks 是否已 wire、memory dir 是否存在、scripts 是否 executable、frontmatter 是否合法。
**Why**: install.sh 處理「安裝」，但不處理「診斷」；新用戶在環境不完整時只能看到含糊的錯誤訊息。`scripts/doctor.sh` 是標準 toolchain 慣例（Homebrew `doctor`、Volta `doctor` 等）。
**Requirement**: `scripts/doctor.sh` 逐項檢查：(1) `claude` 是否在 PATH；(2) `codex` 是否在 PATH（warn 非 error）；(3) `jq` 是否存在；(4) hooks 是否 installed（讀 settings.json hooks 欄位）；(5) `~/.claude/projects/.../memory/` 目錄是否存在；(6) `scripts/*.sh` 是否 executable；(7) frontmatter lint（呼叫 CC-056）。每項 OK / WARN / FAIL 附修復指令。整體 exit 0（OK/WARN only）或 exit 1（any FAIL）。

## CC-060 — Codex model/config 外部化 ✅ 2026-05-23

**Problem**: Codex model 名稱（`gpt-5.3-codex-spark`）、sandbox policy（`workspace-write`）、approval policy（`never`）、timeout（1200s）等參數分散硬碼在 commands/*.md 與 scripts 中。Codex CLI model alias 已在 CC-047 修過一次；未來 OpenAI/Anthropic 改動 API 時又要逐一搜改。
**Why**: config drift 是 toolchain maintenance 的主要成本之一；config file + script 讀取比 grep-and-replace 更可靠。
**Requirement**: 建立 `defaults/codex.toml`（或 `.env.defaults`）收納模型名稱、sandbox、approval、timeout；scripts/codex-dispatch.sh 讀 config；commands 只引用語意名稱（`codex_spark`），不寫死 API 字串。依賴 CC-047（已關）。

**Outcome**: Shipped via PR #131 — `~/.pm-dispatch/config` introduced as the first user-config precedent; timeout + model alias SoT extracted from codex-dispatch.sh; spike doc `docs/spikes/CC-060.md` records Q1/Q2 design decisions (Q1=B bundled impl, Q2=A user-config location).

**See**: CC-242 (companion spike), CC-047 (model alias mapping prerequisite), `docs/spikes/CC-060.md`.

## CC-067 — [schema cleanup] 廢棄 ID gap 慣例 ✅ 2026-05-19

**Outcome**: `pm/schema.md §2.4.5` 移除 CC-1NN/CC-2NN 範圍標注；BACKLOG.md Convention 移除保留範圍說明並指向 DECISIONS.md；新建 DECISIONS.md 記錄決策。
**See**: DECISIONS.md#2026-05-19-deprecate-id-gap-convention

## CC-104n — install/test boundary ✅ 2026-05-19

**See**: pr:—

**Problem**: `install.sh preflight` (`--verify` block) runs all test suites when `--verify` is passed, and any environment-specific failure (missing bin, wrong PATH) aborts the entire install. Tests are hosted *inside* install.sh rather than in a standalone runner.

**Why**: CC-005 made preflight opt-in (`--verify`) — the right first step. The deeper issue is architectural: tests and install are conflated. Consequences: CC-104q (test-hooks runs codex cases even with `--profile minimal`); CC-104l (jq prereq check comes after the preflight that needs jq); new test suites must be manually wired into install.sh preflight; contributors have to know install.sh doubles as the test runner. The desired shape is the standard `make check` / `make install` separation — validate health separately from deploying files.

**Requirement**:
- (a) Create `scripts/run-all-tests.sh` — standalone test aggregator running all `test-*.sh` suites; environment-aware (skip codex cases when `command -v codex` is false, per CC-104q); supports `--skip <name>` for environment-specific opt-outs
- (b) Replace install.sh preflight block (`--verify` section) with a single `bash "$REPO_ROOT/scripts/run-all-tests.sh"` call
- (c) Document `run-all-tests.sh` as the canonical local test entry point in README
- (d) CC-104q (codex-case skip logic) lands in the same PR as CC-104n

**Related**: folds CC-104q; CC-104l (prereq ordering) is independent

## CC-206 — gate lifecycle hooks + sandbox limitations guide ✅ 2026-05-29

**Problem**: Codex sandbox 無法存取 Docker socket，導致需要 Docker backed services（Postgres、Redis 等）的整合測試在 gate 中無法執行。主線程（Claude Code session）有 Docker 權限，但 `pr-gate.sh` 目前無法讓主線程在 dispatch 前後執行 repo-specific 操作。更廣義地說：這是「主線程有能力 X，Codex sandbox 沒有」的通用問題，缺乏一個統一的說明讓使用者知道各類限制的解法。

**Why**: 正確的分層是 pm-dispatch 提供 hook 點、repo 自行實作內容（與 git hooks 設計哲學相同）。Docker Compose flag 直接加進 `pr-gate.sh` 會把 infra 耦合進 PM 工具。pm-dispatch 也應提供 `docs/sandbox-limitations.md` 讓使用者在遇到 sandbox 邊界時有單一查閱點。

**Deliverables**:

**(A) `scripts/pr-gate.sh` — hook 機制**
1. dispatch reviewers 前：若 `.pm-dispatch/pre-gate.sh` 存在且可執行，且 `--allow-hooks` flag 已傳入，主線程執行它
2. 所有 reviewer sessions 完成後：若 `.pm-dispatch/post-gate.sh` 存在且可執行，且 `--allow-hooks` 已傳入，且 gate 結果為 GO，主線程執行它
3. pre-gate hook exit non-zero → gate 中止，不 dispatch reviewers
4. 兩個 hook 均不存在、或未傳 `--allow-hooks` → gate 行為完全不變（backward compatible）

**(B) `docs/sandbox-limitations.md` — 使用者文件（吸收 CC-271 範圍）**
- 說明 Codex sandbox 能力邊界（read-only `/home`、無 Docker socket、無對外網路等）
- Section 1：Gate hooks（`pre-gate.sh` / `post-gate.sh`）— 什麼時候用、怎麼寫、Docker Compose 完整範例
- Section 2：Dispatch brief 中的 Go build cache — `GOCACHE=/tmp/go-cache` 模式說明與 `self_verify` 範例
- Section 3：其他常見限制與 workaround（未來可擴充）

**(C) `docs/dispatch-brief.md` — 小更新**
- 加入 "Go repo" 小節，指向 `sandbox-limitations.md`

**Acceptance criteria**:
- [ ] `--allow-hooks` 傳入 + `.pm-dispatch/pre-gate.sh` 存在且可執行 → gate 在 dispatch 前執行它（主線程）
- [ ] `--allow-hooks` 傳入 + `.pm-dispatch/post-gate.sh` 存在且可執行 + gate 結果 GO → gate 在所有 reviewer 完成後執行它
- [ ] 未傳 `--allow-hooks` → hook 跳過（印 warning），gate 行為不變
- [ ] pre-gate hook exit 1 → gate 中止，不 dispatch reviewers
- [ ] 兩個 hook 均不存在 → gate 行為與現行相同（regression test pass）
- [ ] `docs/sandbox-limitations.md` 存在，包含 Docker Compose 範例與 Go GOCACHE 說明
- [ ] `scripts/test-pr-gate.sh`（或獨立 `test-gate-hooks.sh`）覆蓋 hook 存在/不存在/exit-1 三個 case

**See**: issue:#103（hook 機制）、issue:#173 Pattern 2（Go GOCACHE）

**Cross-link**: `[[CC-271]]`（文件範圍折入此票）、`[[CC-064]]`（未來 bootstrap wizard 可引導建立 pre-gate.sh）

## CC-217 — claude-executor background dispatch ✅ 2026-05-23

**See**: PR #124

**Closed**: `commands/pr-gate.md` Route B claude-executor reviewer + synthesis fan-out now uses `run_in_background: true` with completion-notification handling; `commands/pm.md` already used it (repo-wide sweep confirmed no other dispatch sites). Gate advisories folded into CC-238.

**Problem**: `Agent(subagent_type:claude-executor)` calls in `/pm` Route B and `/pr-gate`
Route B block the main thread waiting for the executor to finish. The codex-executor path
already uses `run_in_background:true`; the claude-executor path does not, making the two
routes inconsistently expensive for the main thread token budget.

**Why**: Blocking dispatch holds the main thread context open for the full executor session
duration, increasing per-task token cost and defeating the "background dispatch" goal. The
codex-executor rule (`feedback_codex_dispatch_background.md`) already captures this principle;
claude-executor should follow the same pattern.

**Requirement**:
- Add `run_in_background:true` to all `Agent(subagent_type:claude-executor)` dispatch calls
  in `commands/pm.md`, `commands/pr-gate.md`, and any other dispatch sites.
- Update completion handling to await the async notification rather than blocking inline.
- Verify that Route B fan-out (parallel reviewer agents) is also non-blocking.

**Complements**: CC-205 (dual-executor planning), CC-059 (thin pm.md).

**Priority**: P2.

## CC-218 — spike tracking infrastructure ✅ 2026-05-23

**See**: PR #125

**Closed**: `spike` epic was already in `validate.sh` `valid_epic()` + `pm/schema.md` §2.4.5 (pm-schema v1.2) and CC-209 already carries it. PR #125 adds `docs/spikes/README.md` — the spike-ticket body convention (`Investigation scope` / `Done-when` / `Result log` within the standard `Requirement` section, per schema §2.5) + the `docs/spikes/CC-NNN.md` result-file format — and a `pm/schema.md` §2.4.5 pointer.

**Problem**: pm-dispatch has no formal spike ticket type. Tickets that require investigation
before spec can be written are marked `design`, conflating "we know what to build" with
"we don't know what to build yet". Spike results have no committed home, so findings
are lost between conversations.

**Why**: A distinct `spike` epic type makes the distinction explicit in validation and in
BACKLOG review. Committed spike result files (`docs/spikes/CC-NNN.md`) ensure findings
survive across sessions and inform future implementation briefs.

**Requirement**:
1. Add `spike` to `valid_epic()` in `pm/scripts/validate.sh`.
2. Define spike body structure in `docs/backlog-schema.md` (or equivalent):
   - `Investigation scope` — what is being explored
   - `Done-when` — what question must be answered to close the spike
   - `Result log` — pointer to `docs/spikes/CC-NNN.md`
3. Create `docs/spikes/` directory with `README.md` describing the format.
4. Update CC-209 index epic from `design` → `spike` (already done in this PR).

**Complements**: CC-220 (spike agent automates the investigation workflow).

**Priority**: P2.

## CC-219 — pre-milestone doc freshness gate ✅ 2026-05-23

**Problem**: Milestone releases can ship with stale README, MILESTONES.md, BACKLOG.md,
or `docs/` content. There is no automated check that doc state matches code state at
release time.

**Why**: Docs drift silently. A lightweight freshness gate catches obvious gaps (TBD PR
refs, closed tickets with missing close dates, MILESTONES sections not yet updated) before
a milestone tag is cut.

**Requirement**:
- Implement `scripts/check-docs-freshness.sh` that prints stale indicators and exits
  non-zero if any blocking gap exists:
  - BACKLOG: open tickets with `pr:TBD` refs after merge
  - MILESTONES: planned items not reflected in Completed section
  - README: version references not matching latest tag
- Add to milestone closure checklist (MILESTONES.md or CONTRIBUTING.md).

**Priority**: P3 — add before v0.3.0 milestone closes.

**Outcome**: Shipped via PR #129 — `scripts/check-docs-freshness.sh` runs U1 (README version), U2 (MILESTONES tag-section parity), U3 (BACKLOG TBD refs on closed rows = blocking). Ran on `main` immediately surfaced the CC-241 drift class (later closed without code change once drift was independently fixed).

**See**: CC-241 (drifts surfaced + closed), MILESTONES.md closure checklist.

## CC-201 — Reuse debt: `detect_executor_profile()` shim ✅ 2026-05-23

**See**: PR #123

**Problem**: `install-hooks.sh` and `pr-gate.sh` both repeat `command -v codex` style executor-profile detection.
**Why**: Profile detection should be consistent across install and dispatch paths.
**Requirement**: Move executor-profile detection into a shared shim, likely `scripts/lib/portable.sh` or a focused executor helper, and update both consumers.
**Closed**: `codex_available()` + `detect_executor_profile()` added to `scripts/lib/portable.sh`; `install-hooks.sh` / `pr-gate.sh` / `doctor.sh` (×2) consumers updated; `pr-gate.sh` + `doctor.sh` source the shim behind a graceful copy-mode fallback. +4 `test-portable.sh` cases, +1 `test-doctor.sh` regression case. PR #123 (v0.3.0 M0).

## CC-203 — Reuse debt: `scripts/lib/test-harness.sh` ✅ 2026-05-24

**Problem**: Eight or more `test-*.sh` scripts each implement their own `--filter`, `--list`, `should_run()`, pass/fail counter, and scratch-dir handling.
**Why**: Test harness behavior should be consistent, and fixes to CLI test behavior should not require repeated edits across scripts.
**Requirement**: Create a source-able `scripts/lib/test-harness.sh` and migrate test scripts incrementally.

**Progress** (closed 2026-05-24 — multi-PR incremental ticket; final state: 22 of 23 `scripts/test-*.sh` adopt the harness; the lone non-adopter is the deliberately excluded orchestrator `test-run-all-tests.sh`):
- PR #127 — `scripts/lib/test-harness.sh` created (`th_init` / `should_run` / `pass` / `fail` / `th_summary`) + its own suite `test-test-harness.sh`; pilot migration of `test-portable.sh` + `test-doctor.sh`. Gate advisories filed as CC-240.
- PR #128 — migrated `test-install.sh` + `test-claude-executor.sh` (the 2 GROUP A / mechanical files per an Explore survey).
- PR #135-#140 — GROUP-B batches migrated 16 remaining `test-*.sh` files (751 cases preserved across migrations); recurring lessons sealed into `[[feedback_test_migration_format_preservation]]`, `[[feedback_ci_shellcheck_test_exclude]]`, codex-sandbox-git-lock observation.
- PR #142 — `th_init --format=<preset>` (CC-247) + `th_init --fail-fast` (CC-248) options added to absorb the surviving per-file overrides as first-class harness presets/flags.
- PR #152 — CC-249 PR-B.2 v2 migrated 10/13 consumers to unified `assert_*` helpers (`assert_string_contains` / `assert_file_contains` / `assert_file_matches` / `assert_exit`), with the 4 fail-fast / format consumers adopting `th_init --format=... --fail-fast`. Zero per-file `pass`/`fail` overrides remain across the 10 migrated files.

**Outcome** (2026-05-24): Closed at 22/23 adoption. The 1 non-adopter is `scripts/test-run-all-tests.sh` (orchestrator that runs other `test-*.sh` as subprocesses and asserts on aggregated output — not a case-based harness fit; deliberately excluded per the GROUP-B re-analysis). The 3 files inside the harness's `assert_*` scope but excluded from PR-B.2 (test-test-harness self-cyclic + test-run-all-tests orchestrator + test-hooks audit-confirm) are carried forward as CC-256 on a separate axis (assert_* helpers, not th_init lifecycle).

**See**: PR #127, #128, #135-#140, #142, #152; CC-247, CC-248, CC-249, CC-256, `[[feedback_test_migration_format_preservation]]`, `[[feedback_ci_shellcheck_test_exclude]]`, `[[feedback_codex_brief_discipline]]`.

## CC-221 — copy-mode refresh semantics ✅ 2026-05-21

**See**: BACKLOG-ARCHIVE.md

**Problem**: `link_or_copy` idempotency check compares the installed copy's sha256 against the manifest's recorded sha (the sha of the old source at install time). When the source file later changes, the installed copy still matches the old manifest sha — so `link_or_copy` returns `ok` and the stale copy is not refreshed.
**Why**: The current install-again workflow does not fix stale copied helpers. The correct uninstall+reinstall workaround is documented (CC-104v), but the underlying implementation is wrong. A user who simply re-runs `install.sh` after pulling a source change will silently keep the old version.
**Requirement**: Change the `link_or_copy` copy-path to compare `sha256(src)` vs `sha256(dst)` at install time; if they differ and `mode=copy`, re-copy and update the manifest entry. Guard: if manifest has no prior entry, existing behavior (first-time copy) is unchanged.
**Closed**: Implemented in PR #117. `scripts/lib/portable.sh` now compares src vs dst sha256 directly; four new test cases in `scripts/test-portable.sh` cover stale refresh, up-to-date rerun, user-modified conflict, and dry-run refresh.

---

## CC-222 — v0.2.0 release prep ✅ 2026-05-22

**See**: PR #120

**Closed**: v0.2.0 released. CHANGELOG.md [0.2.0] written; MILESTONES.md v0.2.0 section closed; docs/GETTING_STARTED.md §4 + docs/platform-support.md docs-freshness sweep; README v0.2.0 sweep + `## Documentation` index; BACKLOG CC-058 flipped to ✅ closed. Merged via PR #120. Post-merge: `v0.2.0` tag pushed on `2c55650`; GitHub Release published with CHANGELOG.md [0.2.0] as release notes.

## CC-229 — core/schema: task/run/event/review/decision schemas ✅ 2026-05-25

**Problem**: pm-dispatch has no state model — tasks are `BACKLOG.md` rows, runs are trace files, reviews are `.gate-results/` files, and nothing links them.

**Why**: The v0.3.0 PM runtime needs a canonical data contract before any runtime code can be written (see [`docs/architecture/v0.3.0-synthesis.md`](../docs/architecture/v0.3.0-synthesis.md) §5.2).

**Requirement**:
- Create `core/schema/{task,run,event,review,decision}.schema.json` — JSON Schema for the five first-class entities and their lifecycles.
- Re-home `pm/schema.md` (the BACKLOG grammar) under `core/`.
- Ships with no behavior depending on it (de-risking); schema locked at end of M1.

**Milestone**: v0.3.0 M1.

**Priority**: P1 — every downstream layer references the schema.

**Outcome (spike phase complete 2026-05-24)**: Dual-path investigation spike (Claude + Codex independent designs + main-thread synthesis). All 6 deliverable sections converged on entity sketches, module dependency graph, and migration checklist. **3 design questions resolved 2026-05-24**: Q2 → per-project partitioning `projects/<sha1>/`, Q7 → dual-write `routing_log.md`+`runs.jsonl` in M1 (M2 cuts hook), Q8 → `schema_version: <int>` inline field-only (no directory versioning). Synthesis §F now documents the dual-write rollback / decommission plan. Schema-only impl PR ready to author once PR #156 merges.

**See**: `docs/spikes/CC-229-substrate-scope.md` (PM-authored scope), `docs/spikes/CC-229-substrate-claude.md` + `docs/spikes/CC-229-substrate-codex.md` (independent designs), `docs/spikes/CC-229-substrate-synthesis.md` (synthesis + open-question table).

**Cross-link**: CC-211 (epic), CC-230 (state store consumes these schemas).

## CC-230 — state store: ~/.local/share/pm-dispatch/state/ (XDG) ✅ 2026-05-25

**See**: `scripts/lib/state-writer.sh` + `scripts/codex-dispatch.sh` runs_append wiring + `scripts/test-state-store.sh` (18 cases) in pr:#159.

Dual-write strategy: `routing_log.md` stays in M1; `runs.jsonl` added in parallel. M2 cuts `hook-routing-log.sh`. Advisory follow-up: CC-263 (sha1sum portability, P3 someday).

## CC-231 — core/policy extraction ✅ 2026-05-25

**Problem**: Reviewer-gate policy, the executor enum, and the dispatch state machine live as prose scattered across `agents/project-pm.md` and command files — no single source.

**Why**: `core/` should own these as declarative, behavior-free definitions consumed by the runtime.

**Requirement**: Extract `core/policy/` — `reviewer-policy` (critic/arch/security/risk/qa gate matrix), `executor-enum` (closed: codex, claude), `dispatch-states` (the dispatch state machine). Pure definitions, zero behavior.

**Milestone**: v0.3.0 M1.

**Priority**: P2.

**See**: `core/policy/` in pr:#157 (`executor-enum.yaml`, `reviewer-policy.yaml`, `dispatch-states.yaml`, `run-states.yaml`, `task-states.yaml`, `dispatch-routes.yaml`).

**Cross-link**: CC-211 (epic), CC-204 (guard engine consumes policy).

## CC-232 — context-pack schema + context-enricher interface ✅ 2026-05-25

**Problem**: Brief context is hand-listed (`files:`); incomplete lists cost the executor exploration tokens. There is no abstraction for "assembled pre-dispatch context".

**Why**: A `context-pack` decouples context enrichment from any one executor or source; it serves spike, reuse/refactor, and (later) MCP resources alike.

**Requirement**: Define `core/schema/context-pack.schema.json` (files / symbols / memories / risks, each with a source + confidence) + the context-enricher interface (pluggable sources). Consumed via `pmctl context build`.

**Milestone**: v0.3.0 M1.

**Priority**: P2.

**See**: `core/schema/context-pack.schema.json` + `core/context-pack/source.interface.md` in pr:#157.

**Cross-link**: CC-237 (baseline sources), CC-209 (codegraph as a source — spiked).

## CC-241 — v0.2.0 doc-drift cleanup ✅ 2026-05-23

**Problem**: The CC-219 doc-freshness gate, run against `main` for the first time, surfaces three real pre-existing drifts:

1. `[FAIL]` `BACKLOG.md:81` — CC-104p row shows `✅ closed 2026-05-21` but the PR ref column is `pr:TBD`. The actual merged PR is **#114** (`feat(cc-104p): add serialize_with_lock portable shim; fix routing-log row-loss on fresh HOME`, merged 2026-05-21).
2. `[FAIL]` `MILESTONES.md` — the `## v0.2.0` section status string still reads as 規劃中/planned even though git tag `v0.2.0` was cut on 2026-05-22 (closed via CC-222 / PR #120). The CC-219 gate's U2 unit (`tag exists but section marked planned`) correctly flags this.
3. `[WARN]` `README.md` — no `vN.N.N` version reference anywhere in the file. CC-219's U1 unit treats absence as a warning (non-blocking), but releasing a v0.2.0 tag without README visibility weakens the user-facing surface.

**Why**: These drifts existed silently because no gate was running until CC-219. Now that the gate ships on `main`, every subsequent milestone close will trip the same three findings until they're fixed — the gate's signal degrades each time a known-but-unfixed FAIL is ignored. Closing the drift quickly preserves the gate's "if it flags, it matters" trust property.

**Requirement**:
- Update `BACKLOG.md:81` (CC-104p row) PR ref column from `pr:TBD` to `pr:#114`.
- Update `MILESTONES.md` `## v0.2.0` section: flip status from planned to released (date 2026-05-22, tag `v0.2.0`, closing-notes line consistent with the `## v0.1.0` section's prose).
- Update `README.md`: add a current-version reference (footer line, badge, or version-table row) so U1 can detect drift on future releases instead of falling through to the absent-warning branch.

**Acceptance**:
- `bash scripts/check-docs-freshness.sh` against `main` exits 0 (all three checks clean) after merge.
- `bash scripts/check-docs-freshness.sh --json` parses with zero findings.
- Single PR, data-only, expected diff < 20 lines.

**Priority**: P3 — hygiene; non-blocking but degrades gate signal each iteration it's deferred. Should ship in the same week as CC-219 merge.

**Cross-link**: CC-219 (the gate that surfaced these), CC-104p (origin of finding 1), CC-222 / MILESTONES.md (origin of finding 2).

**Outcome**: Closed on inspection 2026-05-23 — all three drifts had been independently fixed before this row was actioned: (a) `BACKLOG.md` CC-104p already had `pr:#114` (likely fixed in PR #114 itself), (b) `MILESTONES.md` `## v0.2.0` section already shows `（released 2026-05-22）` + Tag + closing notes, (c) `README.md` has `Version v0.2.0` badge linking to the release tag. No edit required; row closed by status flip only.

**See**: CC-219 (originator gate), CC-104p, MILESTONES.md `## v0.2.0`, README.md L2 badge.

## CC-242 — Spike: codex-dispatch param extraction survey ✅ 2026-05-23

**Outcome**: Surveyed sandbox/approval/timeout/model-alias hardcoded params across `scripts/codex-dispatch.sh`, `scripts/lib/handover-validate.sh`, hooks, `docs/dispatch-brief.md`, `agents/{project-pm,claude-executor}.md`, and 14+ test fixtures. Classified each axis by invariant source (validator vs doc vs contract vs hook vs test). Verdicts: sandbox = yes-with-guard (don't expose as knob), approval = no (load-bearing bash-route invariant), timeout = yes (env layer already exists; bundle a `~/.pm-dispatch/config` fallback), model alias = yes-with-guard (extract map to data file + render check). Hooks audit: not a gatekeeper for any of these axes — no co-edits needed there. Open questions Q1 (scope) and Q2 (config location) resolved by user: Q1=B (timeout + model-SoT bundled into one CC-060 impl PR); Q2=A (introduce `~/.pm-dispatch/config` as the first user-config precedent in the repo, optional / user-managed / never installer-created).
**Output**: `docs/spikes/CC-060.md` (transplanted from spike draft, with all phases + decisions preserved).
**See**: docs/spikes/CC-060.md

## CC-243 — pm-prep-snapshot: state-snapshot前置給PM agent ✅ 2026-05-23

**Problem**: PM agent spawns start cold and rely on caller-supplied brief metadata (branch HEAD, ticket IDs, project tooling). Two HALT classes observed in CC-242: (a) caller brief claimed `main = 5c02e30` but origin/main had advanced two PRs past that (#129 + #130 merged after the brief was written); (b) caller brief instructed "register CC-241 spike ticket" but CC-241 had been consumed by #130. PM had to spend its first phase verifying state instead of doing PM work.

**Solution**: New main-thread script `scripts/pm-prep-snapshot.sh` that runs immediately before any PM spawn and writes a typed snapshot to `/tmp/pm-snapshot-<ts>.md`:

```yaml
---
snapshot_ts: 2026-05-23T14:30:00+09:00
repo: pm-dispatch
branch_base: origin/main@<sha>
current_branch: <name>@<sha>
ahead_by: <N commits>
recently_merged:        # gh pr list --state merged --limit 5
  - "#130 fix(cc-241): ..."
  - ...
backlog_next_id: CC-245     # parsed from BACKLOG.md highest CC-N
focus_tickets:              # full row + body section per caller-named ID
  CC-243:
    status: 🔵 active
    row: "| CC-243 | ... |"
    body: |
      ## CC-243 — ...
project_tooling:
  makefile: false
  backlog_render_target: false
  has_validate_sh: true
---
```

PM brief template updated: caller adds `snapshot_file: /tmp/pm-snapshot-<ts>.md` field and a directive "Treat snapshot fields as ground truth; do not trust commit SHAs or ticket IDs from this brief's prose — re-derive them from the snapshot."

**Schema-key naming aligned with future CC-244 typed pipeline**: `branch_base`, `ticket_ids_consumed`, `project_tooling` — when CC-244 lands, the snapshot output becomes a frontmatter block of `spike_v1` without re-washing field names.

**Acceptance**:
- `scripts/pm-prep-snapshot.sh [--focus CC-N,CC-M]` writes a snapshot to `/tmp/pm-snapshot-<ts>.md` with all required fields
- `scripts/test-pm-prep-snapshot.sh` covers: no-focus path, with-focus path, ticket-not-found warning, derivation of `backlog_next_id`, `project_tooling` probe
- `agents/project-pm.md` updated with a "Snapshot ingestion" subsection telling PM to read the snapshot file first and prefer its values over brief prose
- `docs/dispatch-brief.md` schema documents the optional `snapshot_file` field
- `scripts/lint-scripts.sh` and `scripts/lint-frontmatter.sh` cover the new script
- README adds one-line description in the Scripts section

**Out of scope**: multi-repo snapshots, snapshot caching, snapshot diff between two times. Add tickets if/when a real workflow needs them.

**See**: CC-244 (future typed-pipeline upgrade path).

## CC-245 — Wire pm-prep-snapshot into /pm flow ✅ 2026-05-23

**Outcome**: `commands/pm.md` now runs `scripts/pm-prep-snapshot.sh` (built in CC-243) immediately before invoking the `project-pm` agent, with the focus list derived from any `CC-\d+` IDs in `$ARGUMENTS`. The resulting `/tmp/pm-snapshot-<ts>-<unique>.md` path is injected into the PM brief as `snapshot_file:`, which PM's `## Snapshot ingestion` section (added in CC-243) treats as ground truth — preferring it over caller-brief prose for commit SHAs / ticket IDs. Graceful degrade: snapshot failure (e.g. target repo has no `BACKLOG.md`) skips the snapshot step but does not block the dispatch.

**Why this matters**: CC-243 shipped the snapshot script + PM agent's ingestion-rule, but no caller actually invoked the script. This wiring is what realizes the value end-to-end. Without it, the script was shelf-ware.

**See**: CC-243 (script + agent ingestion rule), `docs/spikes/CC-060.md` §2.5 (motivating HALT classes), `commands/pm.md` (wiring location).

## CC-246 — pm-prep-snapshot echo OUT_PATH ✅ 2026-05-23

**Outcome**: One-line fix — `printf '%s\n' "$OUT_PATH"` after the atomic `mv` in `scripts/pm-prep-snapshot.sh`. Callers now capture the snapshot path via `SNAPSHOT_FILE="$(bash ... pm-prep-snapshot.sh ...)"` instead of having to scan `/tmp` after the fact. `commands/pm.md` updated to the capture pattern.

**Found by**: post-merge smoke test of CC-245 (PR #133). Smoke confirmed wiring worked end-to-end (PM read the snapshot, treated it as ground truth), but caller side needed `ls -lt /tmp/pm-snapshot-*.md` to find the file — a rough edge for any automation downstream.

**Test additions**: `cli-stdout-echoes-out-path` (assert stdout matches the path passed to `--out`), `cli-stdout-echoes-default-path` (assert default invocation prints a valid path to a real file). Also de-staled `frontmatter-core-fields: backlog_next_id` (was literal `CC-245`, now regex `CC-[0-9]+` so future ticket additions don't break it).

**See**: CC-243, CC-245.

## CC-247 — `th_init --format=<preset>`: 5-preset enum for residual print-format overrides ✅ 2026-05-23

**Problem**: After the CC-203 GROUP-B migration, 6 `test-*.sh` files still carry per-file `pass`/`fail` print-format overrides because the canonical `th_init` print format does not match what each test's golden output / VERBOSE convention expects. The override pattern violates the "harness is single source of truth for output" intent of CC-203 and re-introduces the drift CC-203 was meant to remove.

**Why**: The user prefers perfect DRY over harness minimalism (D3 decision 2026-05-23). The 6 surviving variants are a small, enumerable set — each maps cleanly to one of 6 print-format preset combinations (indent on/off × colon-suffix on/off × VERBOSE-gated on/off, minus impossible combinations). Encoding them as named presets (`--format=<name>`) keeps the harness as the single source of truth while letting each consumer pick its preset declaratively. No per-file override remains after this lands.

**Requirement**:
- Add a `--format=<preset>` flag to `th_init` in `scripts/lib/test-harness.sh` accepting exactly 6 preset names (final names + per-consumer mapping to be enumerated in the PR A brief based on a focused survey of the 6 consumer files — survey is OWNER of PR A brief, not this docs PR).
- After PR A merges, zero per-file `pass`/`fail` overrides remain in the 6 known consumer files.
- `--format=<unknown>` exits non-zero with a clear error (closed enum, not free-form string).

**Acceptance**:
- All 6 consumer test scripts pass with their original golden output after migration.
- `grep -nE '^(pass|fail)\(\)' scripts/test-*.sh` returns zero matches in the 6 known consumers post-migration.
- `bash scripts/run-tests.sh` exit 0 (no regression).

**Priority**: P2 — reuse-debt, blocks the "no more per-file format overrides" invariant CC-203 implicitly promised.

**Cross-link**: CC-203 (origin epic), CC-248 (sibling harness option — bundle in PR A).

**Outcome** (2026-05-23): Closed via PR #142 — `th_init --format=<preset>` lands as a closed enum of 5 presets: `colon-flat` (default), `colon-mixed`, `indent-1sp`, `indent-2sp`, `indent-2sp-quiet`. Unknown values exit 1 with explicit valid-list. Consumer adoption completed incrementally; final state verified post PR-B.2 v2 (#152) close-out: 4 of 10 migrated consumers explicitly select a non-default preset (test-skill-refine=colon-mixed, test-usage-tracker=indent-2sp, test-usage-weekly=indent-2sp, test-commands=indent-1sp); the other 6 use default colon-flat. `grep -lE '^(pass|fail)\(\)' scripts/test-*.sh` returns zero matches — no per-file print-format override remains. The 6→5 preset count delta vs the original spec: closer survey collapsed two near-identical layouts into one.

**See**: PR #142, PR #152 (consumer adoption fully realized), CC-248 (sibling), CC-203 (origin epic).

## CC-248 — `th_init --fail-fast`: promote fail-fast to harness option ✅ 2026-05-23

**Problem**: Three test scripts — `test-usage-weekly.sh`, `test-usage-tracker.sh`, `test-skill-refine.sh` — currently use per-script `exit 1` inside their custom `fail()` override to terminate on first failure instead of collecting all failures via the harness's default collect-all behavior. The override re-introduces a per-file format-divergence path that CC-203 set out to remove.

**Why**: Fail-fast vs collect-all is a legitimate, project-internal preference (mostly used where a failure invalidates all subsequent cases, e.g. shared state setup). Promoting it from "patch the harness override" to a first-class `th_init --fail-fast` option keeps the harness as the single source of truth and lets these 3 consumers express intent declaratively. Bundled with CC-247 in PR A — both are "remove the per-file `pass`/`fail` override class".

**Requirement**:
- Add `--fail-fast` flag to `th_init` in `scripts/lib/test-harness.sh`. When set, the first failing case causes `th_summary` (or the `fail()` path) to terminate the run with non-zero exit immediately; default behavior unchanged.
- The 3 consumer scripts switch from per-script `exit 1` override to `th_init --fail-fast`.

**Acceptance**:
- The 3 consumer scripts retain fail-fast semantics (regression test: inject a failing case early and confirm subsequent cases do not run).
- Default-mode scripts (collect-all) untouched — `bash scripts/run-tests.sh` exit unchanged.
- Zero per-script `exit 1` in `fail()` overrides remain across these 3 files.

**Priority**: P3 — reuse-debt; smaller blast radius than CC-247 but ships in same PR A.

**Cross-link**: CC-203 (origin epic), CC-247 (sibling harness option — bundle in PR A).

**Outcome** (2026-05-23): Closed via PR #142 — `th_init --fail-fast` lands as a boolean flag; when set, the `fail()` path calls `th_summary` after recording the failure, which exits non-zero immediately. Default (collect-all) behaviour unchanged. The 3 consumer scripts adopted in PR-B.2 v2 (#152): test-skill-refine.sh (`th_init --format=colon-mixed --fail-fast`), test-usage-tracker.sh (`th_init --format=indent-2sp --fail-fast`), test-usage-weekly.sh (`th_init --format=indent-2sp --fail-fast`). No per-script `exit 1` in `fail()` overrides remain in any of the 3 files.

**See**: PR #142, PR #152 (consumer adoption), CC-247 (sibling), CC-203 (origin epic).

## CC-249 — Consolidate divergent `assert_*` helpers in `scripts/lib/test-harness.sh` ✅ 2026-05-24

**Problem**: The shared test-harness exposes assertion helpers with non-uniform contracts that have drifted as more consumers migrated under CC-203:
- `assert_contains` has 3 different call signatures observed across the harness + consumers (haystack-first, needle-first, and a third variant where the message is positional vs keyword). Consumers each picked a variant; the harness accepts the union loosely.
- `assert_exit` has an arg-order conflict — some consumers call `assert_exit <expected> <actual>` and others call `assert_exit <actual> <expected>`. Both currently pass silently when the values are equal, masking the divergence.

**Why**: Divergent assertion contracts re-introduce the per-file-style cost CC-203 was supposed to retire. Consolidating to a single signature per helper is the right shape, but the unified API is not obvious from the call-sites alone — picking the wrong signature forces N consumer rewrites with high risk of behavior regression in the assertion-failure path. Therefore this ticket is **gated by a `/pre-impl` spike** (PR B sequence): the spike enumerates the divergent call-sites, picks the unified signature, and decides whether to break compat (call-site rewrite) or accept a multi-arity shim. Implementation only after the spike resolves.

**Requirement**:
- `/pre-impl` spike output documents: (a) all call-site variants of `assert_contains` and `assert_exit` in the harness + every migrated consumer; (b) chosen unified signature per helper; (c) migration strategy (break-and-rewrite vs multi-arity shim); (d) any deprecation path for legacy callers.
- Implementation PR (PR B) follows the spike's chosen signature; consumers updated in lockstep; assertion-failure messages remain at-least-as-informative as the pre-consolidation versions.

**Acceptance**:
- Single signature per assertion helper documented in the harness header comment.
- Every consumer in `scripts/test-*.sh` uses the unified signature.
- Regression test (in `test-test-harness.sh`) exercises both the pass and fail path for each consolidated helper.

**Priority**: P3 — reuse-debt; correctness ceiling, not a daily friction. Spike first, implement second.

**Cross-link**: CC-203 (origin epic), CC-247 / CC-248 (sibling harness work — separate PR A), `commands/pre-impl.md` (spike gate).

**Outcome** (2026-05-24): Closed via spike #146 + PR-B.1 #148 + CC-254 amendment #149 + PR-B.2 v2 #152. Spike Q1-Q5 (`docs/spikes/CC-249.md`) decided: unified signatures (`assert_string_contains`, `assert_file_contains`, `assert_file_matches`, `assert_exit`), canonical `assert_exit` arg-order = `<name> <actual> <expected>`, break-and-rewrite (Q3) over multi-arity shim. PR-B.1 #148 added the 4 unified helpers; CC-254 #149 stripped auto-pass after PR-B.2 v1 surfaced double-count conflict with consumer `assert && pass` pattern. PR-B.2 v2 #152 shipped pure-rename + local-def deletion across 10 of 13 consumers (−114 LoC, golden-parity preserved byte-identically). Excluded 3 files (test-test-harness cyclic dependency, test-run-all-tests orchestrator shape, test-hooks audit-confirm-only) carried forward as CC-256.

**See**: `docs/spikes/CC-249.md`, PR #146 / #148 / #149 / #152, CC-254, CC-256, `[[feedback_spike_pilot_required]]`, `[[feedback_test_migration_format_preservation]]`, `[[feedback_codex_brief_discipline]]`.

## CC-250 — `/pr-gate v2`: machine-readable result + escalation hint ✅ 2026-05-23

**Problem**: `/pr-gate` result files today are prose-only Markdown with a `Final: GO|NO-GO` grep target; consumers (validate.sh, downstream automation) can read the binary verdict but cannot see per-reviewer verdicts, mode, tier, or whether the gate recommends a follow-up targeted re-gate without parsing the prose. Reviewer override discipline is scattered across `agents/project-pm.md` + each reviewer's verdict scale, so a person reading one reviewer agent cannot find its override policy without cross-reference.

**Why**: As `/pr-gate` matures and feeds into the v0.3.0 M1 runtime layer (CC-231 reviewer-policy extraction, CC-215 pmctl), the result file becomes the contract between the gate and downstream tooling. A typed frontmatter + an explicit escalation hint section lets future consumers act on the gate output without re-parsing prose. Override-policy consolidation eliminates the per-reviewer documentation gap noticed during recurring gate cycles.

**Requirement**:
- **A**. Every gate result file (sequential + parallel) starts with a YAML frontmatter block (`gate_result_version: pr_gate_result_v1`, `final`, `tier`, `mode`, `most_severe`, `reviewers:` map with every reviewer in `$ALL_REVIEWERS` keyed to verdict-or-`skipped`, `escalation:` block). Existing `Final: GO|NO-GO` line in `## Gate Conclusion` is preserved verbatim.
- **B**. New `## Escalation` body section mirrors the frontmatter `escalation:` block. Both empty-list (recommended=false) and populated cases are valid emissions. Trigger: sensitive-path keyword in diff AND at least one reviewer returned advise|block-soft.
- **C**. `--base` detection prepends `gh pr view --json baseRefName` when no `--base` flag is given and `gh` is on PATH; gracefully degrades to current `origin/HEAD → main` chain.
- **D**. Each of the 5 reviewer agent .md files gains a `## Override policy` section consolidating discipline already documented in `agents/project-pm.md` §"User override discipline".

**Acceptance**:
- `test-pr-gate.sh` adds at least 3 new cases: (a) sequential result file starts with valid YAML frontmatter containing `gate_result_version: pr_gate_result_v1` + `final:` + `reviewers:` map; (b) `## Escalation` section is present with `**Recommended**:` line; (c) `^Final: (GO|NO-GO)$` line still present and unique (back-compat).
- `bash pm/scripts/validate.sh BACKLOG.md DECISIONS.md CHANGELOG.md 2>&1 | grep -c '^E-'` ≤ 30 (baseline).
- `bash scripts/run-tests.sh` exit 0.
- `shellcheck --severity=style scripts/pr-gate.sh` exits 0.

**Priority**: P2 — gate-infra prerequisite for v0.3.0 M1 (CC-231 reviewer-policy extraction depends on a typed gate result surface to extract policy from).

**Cross-link**: CC-231 (M1 reviewer-policy extraction consumer of this typed surface), CC-215 (pmctl downstream consumer), CC-208 (gate reviewer hallucination — related gate hardening), `MILESTONES.md` §v0.3.0 M1 prerequisite sub-table.

**Outcome**: Shipped via PR #144 — frontmatter + escalation + gh pr view fallback + 5 reviewer override-policy sections all landed. Meta-test self-gate confirmed format works end-to-end. Hang during dispatch (apply_patch debug loop, ~10 min stall) recovered on its own; the retrospective on this hang drove CC-251 brief-authoring discipline.

**See**: CC-251 (brief-discipline derived from CC-247/248 + CC-250 dispatch retros), CC-231 (downstream consumer), CC-215 (pmctl downstream consumer).

## CC-251 — Brief-authoring discipline for multi-file dispatches ✅ 2026-05-24

**Problem**: Codex dispatches on briefs that touch > 4 files OR embed > 50 lines of verbatim content (paragraphs, table rows, code blocks the executor must reproduce byte-identically) hit a debug-loop hang pattern: `apply_patch verification failed: Failed to find expected lines` → codex retries → eventually self-recovers OR exhausts dispatch timeout (1800s). Observed twice in 2026-05-23: CC-247/248 PR #142 (hit on 9-file harness migration) and CC-250 PR #144 (hit on 9-file gate-infra bundle).

**Why**: Three failure modes layer:
1. Large brief + many read files burns input-token budget that should go to accurate patch construction
2. Embedded verbatim content tempts codex to paraphrase during retype (CC-250 stderr showed `pass/fail print-format` → `print-format` — silent drop)
3. Large target files (BACKLOG.md 1500+ lines, pr-gate.sh 840 lines) with many same-prefix lines cause patch context to grab wrong location
4. Codex has no internal retry-cap on apply_patch failures — debug loop runs until dispatch timeout

The 3 patterns documented here address layers 2 / 3 / 4. Layer 1 (context budget) is mitigated separately by brief-splitting (split N-file dispatch into ⌈N/3⌉ smaller ones) — discipline first, split second.

**Requirement**:
- **`agents/project-pm.md`** gains a "Multi-file brief discipline" section in the "Writing a brief for codex-executor" prose, listing the 3 patterns with rationale + when-to-apply trigger (> 4 files OR > 50 lines verbatim).
- **`docs/dispatch-brief.md`** gains an optional `expected_head_sha` schema field under "Optional sections" with a usage example.
- Memory `[[feedback_codex_brief_discipline]]` documents the retro evidence (CC-247/248 + CC-250 stderr excerpts + apply_patch failure root cause).

**Acceptance**:
- 3 patterns documented verbatim in `agents/project-pm.md` (retry-cap text, verbatim-as-attached-file pattern, expected_head_sha pattern).
- `docs/dispatch-brief.md` lists `expected_head_sha` as Optional with example.
- Validator parity preserved at 30 (CC-228 baseline).
- No code change required this PR — discipline is brief-authoring time, not runtime. Long-term `pmctl` (CC-215) may add `--expect-head <sha>` flag at the wrapper level.

**Priority**: P3 — discipline polish; not a blocker but every future > 4-file dispatch should apply the patterns.

**Outcome**: Shipped via PR #145 (commit f40213b, merged 2026-05-23) bundled with the CC-250 close-out. The 3 patterns now live in `agents/project-pm.md` (L113-118: Multi-file brief discipline heading + retry-cap / verbatim-as-attached-file / expected_head_sha numbered list + >8-files split rule) and `docs/dispatch-brief.md` (L43-50: `expected_head_sha` optional schema field with example + self_verify usage). Validator parity preserved per CC-228 baseline. Memory card `[[feedback_codex_brief_discipline]]` captures the CC-247/248 + CC-250 stderr-trace retro evidence and the layer-2/3/4 root-cause mapping.

**See**: PR #145 (f40213b), `[[feedback_codex_brief_discipline]]`, CC-247/CC-248 (#142 hang origin), CC-250 (#144 hang origin), CC-244 (typed schema long-term resolution), CC-235 (tiered lifecycle gate long-term enforcement), CC-215 (pmctl `--expect-head` wrapper).

**Cross-link**: CC-247/CC-248 (#142 retro), CC-250 (#144 retro), CC-235 (tiered-lifecycle-gate that would enforce split mechanically), CC-244 (typed pipeline that would turn verbatim into schema fields), CC-215 (pmctl `--expect-head` wrapper option), memory `[[feedback_codex_brief_discipline]]`.

## CC-252 — `/pr-gate` brief template: harden `Final:` line emission ✅ 2026-05-24

**Problem**: The CC-250 (#144) brief template inside `scripts/pr-gate.sh` instructs codex to write `Final: GO|NO-GO` in the `## Gate Conclusion` section, but does not specify that the line must be at start-of-line with no markdown emphasis. Codex applies prose markdown convention (e.g., `**Final: GO**` bold) which fails `pr-gate.sh`'s back-compat parity grep `^Final: (GO|NO-GO)$` — gate exits 1 even when the verdict is GO. Observed on CC-249 spike dispatch 2026-05-23.

**Why**: The verdict frontmatter (CC-250 item A) carries the machine-readable verdict and works correctly, but the legacy `Final:` line is the back-compat anchor for any downstream tool / human parser that didn't migrate to frontmatter. False-negative gate exits cause local-run confusion and would break CI gating if any downstream tool uses pr-gate.sh's exit code as a quality signal.

**Requirement**:
- Both brief templates in `scripts/pr-gate.sh` (sequential + parallel synthesis) MUST explicitly tell codex: "Emit the `Final:` line **at start of line, plain text, no markdown emphasis (no `**`, no backticks), exact format `Final: GO` or `Final: NO-GO`**".
- Add a frontmatter-vs-Final-line parity instruction: codex must verify that frontmatter `final:` value matches the `Final:` line value (case-sensitive match on GO/NO-GO).
- `test-pr-gate.sh` add regression case: synthesis stub that writes `**Final: GO**` must trigger the back-compat check failure (not silently pass).

**Acceptance**:
- After the brief-template fix, /pr-gate exit code matches the verdict (GO → 0, NO-GO → non-zero); no false-negative exits on bold-Final emission.
- Regression test in test-pr-gate.sh covers the bold-Final failure mode.
- `bash scripts/test-pr-gate.sh` passes; `bash pm/scripts/validate.sh BACKLOG.md` parity preserved at baseline.

**Priority**: P3 — gate-infra polish; verdict itself is correct, only the exit-code parser is sensitive to format drift.

**Cross-link**: CC-250 (#144 origin), `[[feedback_codex_brief_discipline]]` (paraphrase-prevention discipline — related failure mode), `scripts/pr-gate.sh` (brief templates around L350 sequential + L520 parallel synthesis).

**Outcome**: Shipped via PR #147 — both brief templates patched with CRITICAL format constraints (no markdown emphasis, start-of-line, exact regex token); self_verify upgraded from bare `grep -c 'Final'` to anchored `grep -cE '^Final: (GO|NO-GO)$'`; frontmatter-vs-Final parity assertion added. Regression test `test_bold_final_line_rejected` (via `CODEX_GATE_STUB_BOLD_FINAL=1` env seam) locks the parser against future loosening. Meta-test on this branch confirmed plain `Final: GO` emission + frontmatter parity + exit 0.

**See**: CC-250 (#144 origin), `[[feedback_codex_brief_discipline]]`.

## CC-254 — CC-249 PR-B.1 amendment: harness assert_* no auto-pass ✅ 2026-05-24

**Problem**: PR-B.1 (#148) shipped harness `assert_*` helpers that auto-called `pass "$name"` on success. Spike Q1-Q5 assumed simple rename migration. PR-B.2 (consumer migration) dispatch 2026-05-24 surfaced a deeper design gap: the 13 consumer test scripts ALL follow the `assert_X "$name" ...; pass "$name"` pattern — `assert_*` is a check, the consumer separately calls `pass` to increment the counter. Pure rename would double-count PASS (harness implicit pass + consumer explicit pass). Codex defensively shadowed the harness by re-defining the 4 helpers in 9 of 13 consumer files (Q3 rejected this — "no shim, no deprecation"). Dispatch hit timeout 124 with 9 apply_patch failures in the 4 complex files; 9/11 consumers ended in shadow-shim state.

**Why**: The break-and-rewrite spike (Q3) is the right architectural call but PR-B.1's helper API was wrong. Auto-pass-in-helper makes assert behave like a one-step "check and account", which conflicts with the consumers' established "check, then account" rhythm. Removing auto-pass keeps the spike's break-and-rewrite intent intact while letting PR-B.2 be a simple rename: each `assert_contains "$n" $f "$x"` becomes `assert_file_contains "$n" $f "$x"` and the existing `pass "$n"` underneath stays unchanged.

**Requirement**:
- Strip `pass "$name"` from each of the 4 harness helpers (`assert_exit`, `assert_file_contains`, `assert_file_matches`, `assert_string_contains`); helpers still call `fail` on failure.
- Document the new contract in a header comment: success returns 0 without side-effects; consumer responsible for `&& pass "$name"` if PASS accounting is desired.
- Amend the 4 pass-path self-tests in `scripts/test-test-harness.sh` to add explicit `&& pass '<name>'` after the assert call so they continue to emit `1 passed`.
- The 4 fail-path self-tests are unaffected (they never relied on implicit pass).

**Acceptance**:
- `scripts/test-test-harness.sh` 30/30 passes (no regression).
- `scripts/test-run-all-tests.sh` integration 13/13 passes.
- Each of the 4 harness helpers returns 0 silently on success — no `pass` call inside the helper body.
- Header comment in `scripts/lib/test-harness.sh` documents the consumer-controlled accounting contract.
- After this PR merges, PR-B.2 can re-dispatch as pure rename (`assert_contains` → `assert_file_contains|matches|string_contains` + delete local helper defs) without double-counting risk.

**Priority**: P2 — unblocks PR-B.2 (consumer migration); CC-249 epic stuck until this lands.

**Cross-link**: CC-249 (parent epic), `docs/spikes/CC-249.md` (spike that missed this gap — amendment will update spike's Open Risks section), `[[feedback_codex_brief_discipline]]` (CC-251 — discipline that helped Codex catch and HALT-loop on the conflict rather than silently mis-migrate).

**Outcome** (2026-05-24): Shipped in PR #149 (`fix(cc-254): harness assert_* no auto-pass + 3 process artifacts from PR-B.2 retro`). All 4 assert_* helpers (`assert_exit`, `assert_file_contains`, `assert_file_matches`, `assert_string_contains`) return 0 silently on success; the 4 pass-path self-tests in `scripts/test-test-harness.sh` call `pass` explicitly. Enabled PR-B.2 v2 (CC-249, PR #152) to complete pure-rename consumer migration of 10/13 files (−114 LoC).

**See**: `scripts/lib/test-harness.sh` lines 148–188 (helpers), `scripts/test-test-harness.sh` lines 313–385 (self-tests), CC-249 (#148, #149, #152).

## CC-257 — pr-gate.sh stderr noise: `final::` command-not-found ×7 per invocation ✅ 2026-05-24

**Problem**: Every `/pr-gate` invocation emits 7 shell errors at `scripts/pr-gate.sh:362` (the codex brief heredoc opening line):

```
scripts/pr-gate.sh: line 362: final:: command not found
scripts/pr-gate.sh: line 362: **Final:: command not found
scripts/pr-gate.sh: line 362: Final:: command not found
scripts/pr-gate.sh: line 362: Final:: command not found
scripts/pr-gate.sh: line 362: Final:: command not found
scripts/pr-gate.sh: line 362: final:: command not found
scripts/pr-gate.sh: line 362: Final:: command not found
```

Reproducible on the CC-249 PR-B.2 v2 gate run (2026-05-24, `.gate-results/gate-20260524-174507.md`, dispatch trace `codex-20260524-174508-114715`). The errors match literal tokens inside the heredoc body (`final: GO\|NO-GO` frontmatter, `Final: GO\|NO-GO` output_format, `**Final: GO**` / `Final: **GO**` / `Final: Go` cautionary examples in the brief template added by CC-252 #147).

**Why**: Gate verdict + result file still emit correctly (this run produced `Final: GO` cleanly), so this is stderr noise only — but:
- It hits every PR gate run for every user
- It buries any real shell errors from `pr-gate.sh` under 7 false-positive lines
- It will confuse future debugging — anyone tailing the gate output sees "errors" when there are none

Heredoc starts at line 362 (`cat > "$BRIEF_FILE" << BRIEF_EOF`) — unquoted delimiter, so bash performs variable + command substitution + arithmetic expansion on the body. Hypothesis: somewhere in the body a `${VAR}` interpolation contains text that resolves to a bareword line bash tries to execute; OR a downstream `eval`/`source` reads the constructed brief and re-executes parsed lines. Needs investigation before fix.

**Requirement**:
- Reproduce locally with `bash -x` to identify which expansion (or downstream consumer) triggers the command-not-found.
- If heredoc-quoting fix is safe (no `${VAR}` interpolation lost), change `<< BRIEF_EOF` → `<< 'BRIEF_EOF'` and ensure every needed variable is otherwise injected (e.g. pre-render then substitute via `sed`).
- If the root cause is a downstream `eval`/`source`/`source <(...)` pattern, replace with a quote-safe alternative (`read -d ''`, `mapfile`, or proper parsing).
- Add a regression test that runs `/pr-gate` against a fixture branch and asserts stderr matches `^$` (or only a known noise allowlist).

**Acceptance**:
- `/pr-gate` (any tier) emits zero `command not found` errors at line 362 (or anywhere in `pr-gate.sh`).
- All existing gate runs continue to produce correct `Final: GO|NO-GO` verdicts (regression: re-run the gate on a known-GO branch + a known-NO-GO fixture).
- New regression test in `scripts/test-pr-gate.sh` (or `scripts/test-pr-gate-profile.sh`) asserts stderr cleanliness.

**Priority**: P3 — medium severity per `[[feedback_gate_finding_triage]]` (no-block gate finding), no correctness impact, but hits 100% of `/pr-gate` invocations and obscures real signals.

**Cross-link**: CC-252 (#147, added the cautionary `**Final: ...**` example lines that are inside the heredoc); CC-250 (#144, original `/pr-gate v2` machine-readable frontmatter); `[[feedback_gate_finding_triage]]` (severity rule applied).

**Outcome** (2026-05-24): Closed via 6-line edit to `scripts/pr-gate.sh` — escaped the 7 backtick pairs (`` ` `` → `` \` ``) in the 3 unique lines that appear in both the sequential brief heredoc (BRIEF_EOF, lines 451/452/467) and the synthesis brief heredoc (SBRIEF_P2, lines 839/840/860). Bash now treats them as literal backticks instead of attempting command substitution. Brief content unchanged from the codex consumer's perspective — the cautionary tokens still render as backticked code in markdown. Hypothesis (B, escape backticks) confirmed over Hypothesis (A, quote-delimiter heredoc): Option A would have required pre-substituting 12 `${VAR}` references + `$(date)`, a much larger refactor; Option B is a 6-line surgical edit with identical behaviour. Regression test added at `scripts/test-pr-gate.sh::test_brief_construction_emits_no_shell_errors` — invokes `run_gate` with `CODEX_GATE_CAPTURE_BRIEF` set, asserts stderr file does NOT contain `command not found` AND the captured brief still contains the cautionary tokens (`frontmatter \`final:\` field`, `` `**Final: GO**` ``). Verified locally: test-pr-gate.sh 48/48 (was 47, +1 from new case), test-test-harness.sh 30/30, lint-scripts 52 files OK.

**See**: `scripts/pr-gate.sh` heredocs BRIEF_EOF + SBRIEF_P2 (escaped backticks), `scripts/test-pr-gate.sh::test_brief_construction_emits_no_shell_errors` (regression), CC-252 (origin), CC-250 (template lineage), `[[feedback_gate_finding_triage]]` (severity rule).

## CC-256 — CC-249 reuse-debt tail: 3 excluded test files ✅ 2026-05-25

**Problem**: CC-249 spike (#146) Q1-Q5 + PR-B.2 v2 (this PR) migrated 10 of 13 consumer `test-*.sh` files off divergent local `assert_*` helpers onto the unified harness helpers from PR-B.1 (#148, amended by CC-254 #149). 3 files were deliberately excluded from the v2 migration batch:

- `scripts/test-test-harness.sh` — tests the harness itself (13 unified-helper call-sites). Migration would create a cyclic dependency where the system-under-test is also the helper-source. Needs a per-test classification: assertions that exercise the helpers must remain as raw bash, but assertions about other harness behaviour can adopt the helpers.
- `scripts/test-run-all-tests.sh` — orchestrator (2 unified-helper call-sites). Different test shape: it runs other test-*.sh as subprocesses and asserts on their aggregated output, not on file-level fixtures. Helper-fit needs a per-call review.
- `scripts/test-hooks.sh` — 0 unified-helper call-sites in current code. Audit-confirm only — if no `assert_(exit|file_contains|file_matches|string_contains)` ever appears, this file drops out of the reuse-debt set entirely (close as no-op).

**Why deferred not done in CC-249**: spike Q1-Q5 envisioned a uniform rename batch. The 3 files each need analysis, not rename. Including them in PR-B.2 v2 would have either (a) blocked the 10 clean migrations on per-file judgment calls or (b) shipped half-migrated state. Cleaner to ship the 10 + carry the tail.

**Requirement**:
- Per-file analysis for each of the 3 files: enumerate the assert-call-sites, classify each (migrate / keep-raw-bash / harness-self-test-exempt).
- For `test-test-harness.sh`: pick a rule that distinguishes "asserting on harness output" (must stay raw) vs "asserting on file fixtures using harness helpers" (can migrate). Document the rule in a header comment.
- For `test-run-all-tests.sh`: review the 2 call-sites; if they fit `assert_string_contains` / `assert_file_contains` shape, migrate; otherwise document why not.
- For `test-hooks.sh`: if the audit confirms 0 call-sites, close ticket as no-op (no edit needed).

**Acceptance**:
- Each of the 3 files either (a) migrated and golden-parity verified, or (b) has a header comment documenting why specific call-sites remain raw, or (c) confirmed-no-op (test-hooks.sh case).
- `scripts/test-test-harness.sh` 30/30 passes.
- `scripts/test-run-all-tests.sh` integration passes.
- `scripts/test-hooks.sh` 298+ cases pass (current count from memory).
- No new shadow shims of the 4 unified helpers in any file (`grep -cE '^(function )?(assert_exit|assert_file_contains|assert_file_matches|assert_string_contains)\(\)'` returns 0 across all consumers).

**Priority**: P3 — each file is small and the surface area is bounded; not blocking anything downstream. CC-249 epic closure does not depend on this.

**Cross-link**: CC-249 (parent epic, closed by the PR that introduces this row), CC-254 (#149, the harness amendment that enabled the v2 migration), `[[feedback_test_migration_format_preservation]]` (preservation contract any sub-migration here must honour).

**Outcome** (2026-05-25): Per-file audit completed.
- `test-test-harness.sh`: `assert_contains()` defined at line 26 but never called (dead code). Deleted definition. Added header comment explaining the file uses its own `pass_case`/`fail_case` framework because it tests the harness itself via subprocess probes — sourcing the unified harness at top-level would be a cyclic dependency.
- `test-run-all-tests.sh`: `assert_contains()` defined at line 61, called once at line 163. Orchestrator shape (runs suites as subprocesses, uses `pass_case`/`fail_case` counter) is incompatible with the unified harness `pass`/`fail` counter. Kept local with a one-line comment documenting the rationale.
- `test-hooks.sh`: 0 unified-helper call-sites confirmed. No changes needed. Closed as no-op.

**See**: CC-249 (parent epic), CC-254 (#149, harness amendment that enabled PR-B.2).

## CC-264 — Dispatch overhead reduction + executor-agnostic output contract ✅ 2026-05-28

**Status**: ✅ closed — PRs: #163 (PR A: brief-validate.sh), #164 + #167 (PR B: dispatch-post-verify.sh + CC-264b hardening)

**See**: CHANGELOG.md

**Problem**: Two coupled issues:
1. `codex-executor` as a subagent adds ~6 min overhead (2.5x ratio): 40 tool calls × 8s LLM API latency = ~320s. The validation and verification steps don't require LLM intelligence.
2. Post-dispatch verification was designed codex-specific (`codex-post-verify.sh`), but the executor-abstraction principle requires the output contract to be unified — any executor should produce the same output format so the same shell tool can verify any execution.

**Root cause**: Overhead = LLM subagent for shell-level work. Leak = executor-specific output path not standardized in `docs/executor-contract.md`.

**Why**: The executor-contract already decouples the input (brief schema) from the executor. The output must follow the same principle: all executors write to the same filesystem location so verification is executor-agnostic. Connection to CC-262 (isolation_level abstraction): same "goal vs executor" separation principle applied to the output layer.

**Design: executor-agnostic 3-phase shell pipeline**

```
Phase 1 — Pre-dispatch validation (shell, <1s):
  scripts/brief-validate.sh <brief-file>
  Validates required fields + self_verify for file-writing briefs + working_dir existence.
  Exit 0: VALID | Exit 1: REJECT: <reason>

Phase 2 — Dispatch (executor-specific; this layer is intentionally different):
  codex:  Bash(scripts/codex-dispatch.sh --cd <dir> --brief-file <path>, run_in_background:true)
  claude: Agent(claude-executor, ...) — must now also write to .agent-trace/

Phase 3 — Post-dispatch verification (executor-agnostic shell, <5s):
  scripts/dispatch-post-verify.sh <work_dir> [<brief_file>]
  Reads .agent-trace/latest.{last,stderr}, git diff/status, self_verify check.
  Exit 0: ok | Exit 1: partial/failed
```

**Output contract (new — added to executor-contract.md)**:

All executors MUST write to `<work_dir>/.agent-trace/`:
- `<executor>-<ts>.last` — final summary message (plain text)
- `latest.last` — symlink to the most recent `.last` file
- `latest.stderr` — error output (optional; may be empty)

`codex-dispatch.sh` already satisfies this contract (codex profile). `claude-executor` must add a final step to write `claude-<ts>.last` + `latest.last` symlink.

**Requirement**:

PR A — brief-validate.sh:
1. `scripts/brief-validate.sh` — pure bash/awk. Validates required fields, file-writing → self_verify, working_dir existence. Exit 0=VALID, 1=REJECT, 2=usage.
2. `scripts/test-brief-validate.sh` — 12+ cases covering all pass/reject/edge paths.
3. Wire into `scripts/run-all-tests.sh` + `scripts/test-run-all-tests.sh` + CI `lint.yml`.
4. `docs/dispatch-brief.md` — append `## Dispatch protocol` section (Phase 1 + Phase 2; Phase 3 placeholder for PR B).

PR B — output contract + dispatch-post-verify.sh:
5. `docs/executor-contract.md` — add `## Filesystem output contract` section specifying `.agent-trace/` standard.
6. `agents/claude-executor.md` — add final Report step: write `$WORK_DIR/.agent-trace/claude-<ts>.last` + `latest.last` symlink.
7. `scripts/dispatch-post-verify.sh` — executor-agnostic post-verify (reads `.agent-trace/latest.{last,stderr}`, git ops, self_verify check). Exit 0=ok, 1=partial/failed.
8. `scripts/test-dispatch-post-verify.sh` — fixture-based tests.
9. Wire into `scripts/run-all-tests.sh` + `scripts/test-run-all-tests.sh` + CI `lint.yml`.
10. `docs/dispatch-brief.md` — fill in Phase 3 placeholder.
11. `agents/codex-executor.md` — update lifecycle-leak note to reference shell pipeline as primary.

**Out of scope**: Changing `codex-dispatch.sh` itself; changing brief schema; removing codex-executor agent.

**Acceptance (PR A)**:
1. `bash scripts/brief-validate.sh /tmp/valid-brief.md` → exit 0, prints `VALID`
2. `bash scripts/brief-validate.sh /tmp/no-self-verify.md` → exit 1, contains `REJECT: missing field 'self_verify'`
3. `bash scripts/test-brief-validate.sh` → all cases pass
4. `bash scripts/run-all-tests.sh` → exit 0 (31 suites)

**Acceptance (PR B)**:
5. `grep "Filesystem output contract" docs/executor-contract.md` → match
6. `bash scripts/dispatch-post-verify.sh /tmp/fixture-workdir /tmp/fixture-brief.md` → exit 0, contains `status: ok`
7. `bash scripts/test-dispatch-post-verify.sh` → all cases pass
8. `bash scripts/run-all-tests.sh` → exit 0 (32 suites)

**Milestone**: v0.3.x — PR A first; PR B after PR A merges.

**Priority**: P2 — affects every dispatch; overhead saving ~6 min/dispatch on codex path.

**Overhead impact**:
- codex path: 6 min overhead → ~6s (shell only). Saving: ~99%.
- claude path: +16s at end (write .agent-trace/) relative to task duration of 5-10 min. Acceptable.

**Cross-link**: `[[CC-036]]`（dispatch async ergonomics）、`[[CC-040]]`（executor-contract schema）、`[[CC-262]]`（isolation_level abstraction — same goal/executor separation principle）、`[[feedback_dispatch_direct_bash]]`（workaround measurement）。

## CC-265 — Remove /caveman and /caveman-commit commands ✅ 2026-05-26

**Status**: closed
**Description**: Remove `/caveman` and `/caveman-commit` commands.

**See**: CHANGELOG.md

**Problem**: `/caveman` 指令的文字壓縮模式（lite/full/ultra）在節省 token 的同時，會省略回應中的約束、邊界條件、設計細節，在設計/架構討論中造成關鍵資訊遺失，導致後續實作出現傳達錯誤。壓縮帶來的 token 節省不值得這個風險。

**Removal scope**:
- `commands/caveman.md` — delete
- `commands/caveman-commit.md` — delete
- `scripts/test-commands.sh` — 移除 caveman/caveman-commit 測試段落（lines ~90–215）；保留 pre-impl.md Q4 與 agent output-brevity 段落
- `CHANGELOG.md` — 新增 `### Removed` 條目；更新 v0.2.0 test-commands.sh 描述
- `BACKLOG.md` — CC-013 row 標記 "Removed in CC-265"

**Outcome**: `commands/caveman.md` and `commands/caveman-commit.md` deleted; `scripts/test-commands.sh` caveman sections removed; CHANGELOG and BACKLOG updated.

**Why remove** (not just deprecate): caveman 在任何壓縮等級下都無法安全用於設計討論，且沒有已知的安全使用場景值得維護這個 code path。

**Brief**: `.codex-briefs/brief-cc265-remove-caveman.md`

**Acceptance**:
1. `commands/caveman.md` 不存在
2. `commands/caveman-commit.md` 不存在
3. `bash scripts/test-commands.sh` exits 0（pre-impl + agent-brevity 測試仍通過）
4. `bash scripts/run-all-tests.sh` exits 0（suite 數量不變）
5. `CHANGELOG.md [Unreleased]` 有 `### Removed` 段落

**Milestone**: v0.3.0 M5（release prep 前置清理）。

**Priority**: P2 — 移除會造成傳達錯誤的功能，應在 v0.3.0 release 前完成。

**Cross-link**: `[[CC-013]]`（original caveman ship, PR #82）。

---

## CC-267 — bug: executor:claude gate path — Write blocked in background subagent ✅ 2026-05-28

**Problem**: When `pr-gate.sh --executor claude` emits a `pr-gate-handover_v1` block and the calling skill fans out a `claude-executor` subagent with `run_in_background:true`, the subagent needs to **create** the gate result file. `Write` on a new file is denied in background mode — there is no interactive session to approve the permission. Subagent exits without writing; gate result is silently lost.

**Contrast with executor:codex**: Unaffected — Codex runs as a separate process not subject to the Claude Code permission model.

**Root cause**: Gate result file path is computed in `pr-gate.sh` but the file is not pre-created before the handover block is emitted. Background agent can `Edit` an existing file but cannot `Write` to a new path.

**Fix**: `touch "$OUTPUT_FILE"` immediately after `mkdir -p "$(dirname "$OUTPUT_FILE")"` at `scripts/pr-gate.sh:219`, before `emit_pr_gate_handover_block`. Regression test (`test_output_file_pre_created_before_handover`) uses a named pipe to verify the file exists at the moment the `output_file:` handover line is emitted.

**See**: issue:#165, pr:#169

**Cross-link**: `[[CC-217]]`（claude-executor background dispatch）、`[[CC-238]]`（fan-out hardening）、`[[CC-264]]`（executor-agnostic output contract）。

---

## CC-271 — process: Go build cache redirect — sandbox limitations guide ✅ 2026-05-29

> **Closed 2026-05-29**: The documentation scope of this ticket (Go `GOCACHE` redirect explanation) was folded into **CC-206** under `docs/sandbox-limitations.md`. Shipped in PR #175.

**Root cause**: The Codex sandbox makes `/home` read-only. Go's build cache (`GOCACHE`, default `~/.cache/go/build`) requires write access to store compiled artifacts. `go build` fails because it cannot write to `GOCACHE`. Codex then attempts `cp -a <module-cache> /tmp` — incorrectly conflating the build cache with the module download cache — which the workspace-write sandbox policy blocks (compound path). The retry loop (cp → block → discover `GOPATH=/tmp/gopath` → attempt) costs ~10-15 min per dispatch.

**Sandbox access map**:

| Path | Access | Purpose |
|------|--------|---------|
| `~/go/pkg/mod` (or `$GOPATH/pkg/mod`) | read-only ✓ | module source — Go can read this fine |
| `~/.cache/go/build` (`GOCACHE`) | **no write ✗** | compiled artifacts — root cause of failure |
| `/tmp` | read-write ✓ | redirect target |

**Fix**: Standardize `GOCACHE=/tmp/go-cache go build ./...` (and `go test`) in the brief `self_verify` template for Go target repos. This redirects only the writable build artifact layer; module source stays accessible at the original read-only path — no re-download required.

**Why not `GOPATH=/tmp/gopath`**: Moving the entire `GOPATH` severs access to already-downloaded modules, forcing Go to re-download them from the network (if sandbox allows) or fail. `GOCACHE` redirect is the minimal, correct intervention.

**Alternative — vendor mode**: `go mod vendor` + `go build -mod=vendor` eliminates all cache dependencies entirely (fully offline, reproducible). Trade-off: vendor directory adds repo size (tens to hundreds of MB) and requires sync on dependency updates. Prefer for projects with strict reproducibility requirements.

**Impact**: Every Go-target dispatch (e.g. JapanJob backend). Fix is brief template documentation only.

**See**: issue:#173 (Pattern 2)

**Priority**: P2 — reproducible on every Go dispatch; doc-only fix is low effort.

---
## CC-275 — bug: pr-gate.sh exits 127 after result write due to em dash bytes misinterpreted as command ✅ 2026-05-29

**Problem**: After a successful full-tier gate run (result file written correctly), `scripts/pr-gate.sh` exits with code 127:
```
/path/to/scripts/pr-gate.sh: line 1054: $'\200\224': command not found
```
`\200\224` (0x80 0x94) are the last two bytes of the UTF-8 em dash sequence (E2 80 94). Bash misparses the multi-byte UTF-8 sequence in certain shell versions/locales, treating the trailing bytes as a standalone command token. The gate result and verdict are correct — only the exit code is wrong. This causes any automated workflow (CI, main-thread exit-code check) to see a false failure.

**Affected lines** (approx, post-PR-#175):
- `scripts/pr-gate.sh` around line 1054: `printf 'Error: reviewer artifact(s) modified after review phase — synthesis-side tampering detected: %s\n'`
- Other em dash occurrences in the script

**Fix**: Replace all em dash (`—`, U+2014) characters in shell `printf` format strings and heredocs within `scripts/pr-gate.sh` with ASCII equivalents (e.g., `--` or `: `). No behaviour change.

**Acceptance**:
1. `grep -c $'\xe2\x80\x94' scripts/pr-gate.sh` → 0 (no em dashes remaining)
2. `bash scripts/run-all-tests.sh` → exit 0
3. Full gate run exits 0 on GO result and exits 1 on NO-GO result (no exit 127)

**area**: gate
**Raised by**: issue:#176 (2026-05-29)
**Priority**: P1 — reliability bug; wrong exit code breaks CI and main-thread gate loop detection.

**See**: pr:#179

---

## CC-277 — [backlog hygiene] fix CC-228 E-codes — reach validate.sh exit 0 ✅ 2026-05-30

**Problem**: `pm/scripts/validate.sh BACKLOG.md` exits 1 on `main` with ~20 pre-existing E-codes:
- E-AREA-ENUM: rows using invalid area values or too many area tokens
- E-REFS-PREFIX: rows with bare `CC-NNN` refs instead of valid prefixed form (`decisions:`, `roadmap:`, `commit:`, `feedback:`)
- Stale active rows: CC-200/CC-202/CC-204 (closed via PR #170) still show `🔵 active`

**Why**: Without a green validator, CI enforcement (CC-278) cannot be enabled. Errors accumulate silently.

**Requirement**:
1. For each E-AREA-ENUM row: rewrite area cell to use only valid enum tokens (max 2 tokens separated by `/`).
2. For each E-REFS-PREFIX row: change bare `CC-NNN` to `roadmap:CC-NNN` or `decisions:CC-NNN` as appropriate.
3. For stale active rows: update status to `✅ closed YYYY-MM-DD` with correct date, add PR ref.
4. After all fixes: `bash pm/scripts/validate.sh BACKLOG.md` exits 0 (no E-codes remain).

**Cross-link**: `[[CC-228]]` (parent), `[[CC-278]]` (unblocked by this).

## CC-278 — [ops] validate.sh in CI — warn-only then enforce ✅ 2026-05-30

**Problem**: `pm/scripts/validate.sh` encodes real BACKLOG invariants (index↔body parity, area enum, ref prefix, date format) but is not wired into `.github/workflows/lint.yml`. Errors accumulate on every PR without any CI signal.

**Why**: Without CI enforcement, all other BACKLOG hygiene improvements rot immediately after they are applied. CC-277 fixes the current debt; CC-278 ensures debt cannot re-accumulate.

**Requirement**:
1. Phase 1 (merged with or after CC-277): Add a `lint-backlog` job to `lint.yml` that runs `bash pm/scripts/validate.sh BACKLOG.md || true`; include a step that counts and prints error lines so CI output is informative even when the job passes.
2. Phase 2 (after CC-277 exits 0 on main): Remove `|| true`; job hard-fails on any E-code.
3. No new CLI flag in validate.sh needed — use `|| true` at the shell level for Phase 1.

**Cross-link**: `[[CC-277]]` (prerequisite for Phase 2), `[[CC-228]]`.

## CC-279 — [ops] scripts/archive-closed-backlog.sh — idempotent bloat-policy executor ✅ 2026-05-30

**Problem**: BACKLOG.md archiving (pm-schema §4 bloat policy: >500 lines OR >50% terminal items) is a fully manual operation. The 2026-05-29 archiving run (CC-049 Tier 2) required an ad-hoc Python script with no permanent home. There is no repeatable tool.

**Why**: Without a persistent, tested script, archiving will be deferred until the file becomes unmanageable again. The script is independent of pmctl (CC-215) — pmctl will call it as a subcommand when that CLI lands, not replace it.

**Requirement**:
1. `scripts/archive-closed-backlog.sh` — bash script, idempotent, accepts optional `--dry-run` flag.
2. Finds all `## CC-NNN — ... ✅` and `## CC-NNN — ... 🚫` body sections in BACKLOG.md that are NOT already stubs.
3. Appends each to BACKLOG-ARCHIVE.md (full body content, preserving header format).
4. Replaces each body in BACKLOG.md with `**See**: BACKLOG-ARCHIVE.md` stub.
5. Updates `Last archived: YYYY-MM-DD` header in BACKLOG-ARCHIVE.md.
6. Exits 0; prints count of archived sections.
7. Regression test in `scripts/test-archive-closed-backlog.sh` covering: happy path, idempotency (running twice produces no double-archive), dry-run output.

**Cross-link**: `[[CC-280]]` (first operational run), `[[CC-215]]` (pmctl will wrap this).

## CC-280 — [process] run archive-closed-backlog.sh to collapse current BACKLOG bloat ✅ 2026-05-30

**Problem**: BACKLOG.md closed-ticket detail sections accumulate and breach the pm-schema §4 bloat policy (>500 lines OR >50% terminal). Needed the first operational run of the CC-279 archiver.

**Result (2026-05-30)**: Ran `scripts/archive-closed-backlog.sh`. Archived CC-275, CC-277, CC-278 via the script; CC-279 archived manually because its body quotes the literal stub sentinel `**See**: BACKLOG-ARCHIVE.md`, which the script's `has_see` guard mis-reads as already-stubbed (filed as a follow-up). Validator green afterward.

**Cross-link**: `[[CC-279]]` (archiver script + the sentinel false-negative follow-up), `[[CC-281]]` (index split easier after this).
## CC-005 — install.sh preflight 改為 opt-in via `--verify` ✅ 2026-05-18

**See**: BACKLOG-ARCHIVE.md

## CC-027 — PreToolUse `hook-tool-trace.sh` ✅ 2026-05-15

**See**: BACKLOG-ARCHIVE.md

## CC-028 — PostToolUse `hook-routing-log.sh` ✅ 2026-05-15

**See**: BACKLOG-ARCHIVE.md

## CC-029 — `test-codex-dispatch.sh` 加入 CI ✅ 2026-05-15

**See**: BACKLOG-ARCHIVE.md

## CC-034 — `install-hooks.sh` 改名/移動 bug ✅ 2026-05-15

**See**: BACKLOG-ARCHIVE.md

## CC-039 — shared-schema brief enrichment + `/pre-impl` Q4 audit ✅ 2026-05-18

**See**: BACKLOG-ARCHIVE.md

## CC-047 — `scripts/codex-dispatch.sh` model alias mapping ✅ 2026-05-17

**See**: BACKLOG-ARCHIVE.md

## CC-055 — `commands/pr-gate.md` frontmatter YAML fixed ✅ 2026-05-18

**See**: BACKLOG-ARCHIVE.md

## CC-056 — `scripts/lint-frontmatter.sh` + CI job ✅ 2026-05-18

**See**: BACKLOG-ARCHIVE.md

## CC-057 — README `skills/` layout row removed ✅ 2026-05-18

**See**: BACKLOG-ARCHIVE.md

## CC-100 — [CC-OSS Phase 1] Sanitize personal paths ✅ 2026-05-17

**See**: BACKLOG-ARCHIVE.md

## CC-101 — [CC-OSS Phase 2 spike] Executor-contract schema ✅ 2026-05-17

**See**: BACKLOG-ARCHIVE.md

## CC-102 — [CC-OSS Phase 2 impl] `claude-executor` agent + install profile ✅ 2026-05-17

**See**: BACKLOG-ARCHIVE.md

## CC-103 — [CC-OSS Phase 3] Portability shim ✅ 2026-05-17

**See**: BACKLOG-ARCHIVE.md

## CC-104 — [CC-OSS Phase 4] Onboarding docs batch ✅ 2026-05-17

**See**: BACKLOG-ARCHIVE.md

## CC-105 — [CC-OSS Phase 5] BACKLOG cleanup + v0.1.0 release ✅ 2026-05-17

**See**: BACKLOG-ARCHIVE.md

## CC-024 — `test-usage-weekly.sh` 加入 GitHub Actions CI ✅ 2026-05-15

**See**: BACKLOG-ARCHIVE.md

## CC-200 — Reuse debt: `scripts/lib/executor-router.sh` ✅ 2026-05-28
**See**: BACKLOG-ARCHIVE.md

**Problem**: `/pm` and `/pr-gate` each encode codex/claude routing logic separately.
**Why**: A third consumer would turn the duplicated route logic into a maintenance cost and make executor behavior easier to drift.
**Requirement**: Extract shared codex/claude routing into `scripts/lib/executor-router.sh`, preserving existing CLI behavior for current callers.

## CC-202 — Reuse debt: handover validator framework ✅ 2026-05-28
**See**: BACKLOG-ARCHIVE.md

**Problem**: `dispatch_handover_v1` and `pr-gate-handover_v1` validators duplicate fence, metadata, and body validation structure.
**Why**: Future handover schemas should not require hand-written validation boilerplate for every shared grammar rule.
**Requirement**: Extract a reusable handover validator framework that schema-specific validators can configure.

## CC-204 — Reuse debt: hook framework ✅ 2026-05-28
**See**: BACKLOG-ARCHIVE.md

**Problem**: pm-write-guard, codex-bash-guard, and codex-write-guard repeat stdin JSON parsing, decision matrix, and audit-log structure.
**Why**: The guard hook layer has enough shared behavior that copy-paste-modify makes policy and logging drift likely.
**Requirement**: Extract a shared hook framework (`scripts/lib/hook-framework.sh`) for stdin JSON parsing, policy decisions, and audit logging, while preserving hook-specific policy rules.
**Scope note**: `hook-routing-log.sh` is intentionally excluded — it uses custom jq-free JSON parsing and structured JSONL audit logging with rotation/locking, fundamentally different from the guard hook pattern. It remains independent.

## CC-261 — v0.3.x 前瞻文字更新（deferred）

**Problem**: `core/README.md` 寫了未來式 "In the v0.3.x runtime phase, the designated writer module **will read**…" 加括號 "(runtime consumer deferred; M1 ships schema definitions only)"；`agents/project-pm.md` 的 exception rule 硬綁 "v0.3.x runtime PR"。v0.3.0 runtime 落地後，這兩段文字描述的是已完成而非未來的狀態，會誤導維護者。

**Why**: 文件的前瞻性語言是為了讓 M1 開發者知道 runtime 尚未實作；一旦實作落地，繼續存在的 "will" / "deferred" 說明成為雜訊，且版本號硬綁會在後續里程碑造成永久 drift。

**Requirement**:
- `core/README.md`: "will read" → 現在式；移除 "(runtime consumer deferred; M1 ships schema definitions only)" 括號整段
- `agents/project-pm.md`: "explicitly defer the runtime consumer to a v0.3.x runtime PR" → "explicitly defer the runtime consumer to a future runtime PR"（版本無關，永久有效）

**Acceptance**:
1. `grep "v0.3.x runtime phase" core/README.md` → no match
2. `grep "M1 ships schema definitions only" core/README.md` → no match
3. `grep "v0.3.x runtime PR" agents/project-pm.md` → no match

**Milestone**: v0.3.0 M5（release prep）— 加入 v0.3.0 release PR 的 self_verify 清單，PR 合併前必須通過。

**Priority**: P3 — doc cleanup；不阻擋任何功能，但 0.3.0 正式 release 前必須清掉。

**Cross-link**: `[[CC-229]]`（M1 substrate）、`[[CC-260_release_prep]]`（v0.3.0 release prep 票）。

**Outcome**: 2026-05-25 — Both edits applied in PR #162.
1. `core/README.md` — "will read…(runtime consumer deferred; M1 ships schema definitions only)" → present-tense, parenthetical removed.
2. `agents/project-pm.md` — "v0.3.x runtime PR" → "a future runtime PR".
All three acceptance grep checks pass.
**See**: pr:#162

---

## CC-263 — state-writer: portable SHA-1 hash for project partitioning（someday）

**Problem**: `_sw_project_key` in `scripts/lib/state-writer.sh` calls `sha1sum` directly to derive the per-project partition key. `sha1sum` is a GNU coreutils tool; it is absent on stock macOS (which ships `shasum -a 1`) and on some minimal Linux containers. When unavailable, the function silently falls back to `global`, mixing all project state into a single partition without any error log.

**Why**: The `core/state/layout.yaml` contract defines `$PROJECT := sha1(git rev-parse --show-toplevel)`. A silent fallback violates this contract, making cross-repo state isolation unreliable on non-Linux platforms. `scripts/lib/portable.sh` already sets the precedent for cross-platform helpers (`serialize_with_lock`, `link_or_copy`, etc.); the hash helper belongs there.

**Requirement**:
- `scripts/lib/portable.sh`: add `_portable_sha1()` — tries `sha1sum`, then `shasum -a 1`, then returns 1 with a logged warning
- `scripts/lib/state-writer.sh`: replace `sha1sum` call in `_sw_project_key` with `_portable_sha1`; if hash fails, log via `_sw_log_error` and fall back to `global`
- `scripts/test-state-store.sh`: add a `case_project_key_no_sha1sum` test that stubs out both `sha1sum` and `shasum` from PATH and asserts `_sw_project_key` returns `global` (non-fatal) rather than erroring

**Raised as**: [medium] by critic, architecture-reviewer, and risk-reviewer in CC-230 gate 5 (pr:#159).

**Acceptance**:
1. `bash scripts/test-state-store.sh` → all cases pass including the new stub test
2. `bash scripts/run-all-tests.sh` → exit 0
3. `grep -n 'sha1sum' scripts/lib/state-writer.sh` → only via `_portable_sha1`, no raw call

**Milestone**: v0.3.0 跨三個 phase — M1（CC-231 延伸）：`core/policy/` 加 enum 定義；M2（CC-200）：`codex-dispatch.sh` 展開邏輯；M3（adapter layer）：`adapters/{codex,claude}/isolation-map.yaml` + PM template 更新。

**Priority**: P2 — 架構正確性；目前 no-op 填法是 workaround，不阻斷功能但隨著 executor 增加越來越難維護。

**Cross-link**: `[[CC-231]]`（executor-enum policy）、`[[CC-200]]`（executor-router）、`[[CC-215]]`（pmctl adapter generate）、`[[CC-101]]`（executor-contract schema origin）。

**Outcome**: 2026-05-25 — `_portable_sha1()` added to `scripts/lib/portable.sh` with `FAKE_SHA1_MISSING=1` stub; `_sw_project_key` in `state-writer.sh` updated to use it; `case_project_key_no_sha1sum` test added. Shipped in PR #162.
**See**: pr:#162

---

## CC-283 — [bug] archive-closed-backlog.sh sentinel false-negative ✅ 2026-05-30

**Problem**: `scripts/archive-closed-backlog.sh` decides whether a `## CC-NNN — … ✅/🚫` section is already archived by scanning its entire body for the regex `**See**:.*BACKLOG-ARCHIVE`. A closed ticket whose body legitimately *quotes* that stub sentinel — e.g. CC-279, whose requirement text describes the stubbing behavior — matches the guard and is silently skipped. The section can never be collapsed, and once it is marked closed the validator flags `E-CLOSURE-NO-SEE` (closed section with no See stub), so a green validator now requires a manual archive of that one ticket.

**Why**: Surfaced during CC-280 (the first operational archive run): the script archived CC-275/277/278 but skipped CC-279, which had to be moved to `BACKLOG-ARCHIVE.md` by hand. Low severity (rare — only closed tickets that quote the sentinel), but it makes the archiver non-self-healing for exactly the tickets that document it.

**Requirement**:
1. Anchor stub detection so it only matches a section that *is* a stub, not one that mentions the sentinel — e.g. treat a section as already-stubbed only when its first non-empty content line is `**See**: BACKLOG-ARCHIVE.md`.
2. Add a regression fixture: a closed section whose body contains the literal string `**See**: BACKLOG-ARCHIVE.md` must still be archived exactly once.

**Cross-link**: `[[CC-279]]` (the archiver script), `[[CC-280]]` (run that surfaced it).

## CC-284 — [process] backlog working-set contract: schema §4 rewrite + archiver row-shedding ✅ 2026-05-30

**Problem**: `pm/schema.md` §4 kept terminal tickets in `BACKLOG.md` forever — closed/dropped bodies were stubbed but index rows were never removed. The file grew monotonically (at decision time 84 of ~158 index rows were terminal; ~400 lines of dead rows + stubs). A query layer (`pmctl backlog`, CC-282) would sit on top of the mess without removing it.

**Why**: Two independent analyses (Claude main thread + Codex gpt-5.4) converged: the growth root cause is historical ballast retained in the working file, and the fix must change the *contract*, not add tooling on top. Settling the contract first also de-risks the future `pmctl backlog` parser (no baking-in of a structure already slated to change).

**Requirement** (delivered):
1. Schema §4 → working-set model: terminal tickets' index row + body both leave `BACKLOG.md`; body moves to `BACKLOG-ARCHIVE.md`; no `**See**:` stub. §2.6 stub marked legacy, §6.1 lookup order updated. Policy/archiver change only — no parse-marker bump (stays v1.2), validate.sh untouched.
2. `scripts/archive-closed-backlog.sh` rewritten: reads terminal status from the index Status column (§6.1), drops the row, moves the body, dedups by archived heading — which dissolves CC-283 (no more body-prose sentinel scan).
3. Regression suite extended to 11 cases (row removal, CC-283 sentinel, `✅ done` soft-close preserved, legacy-stub sweep, partial-write recovery).
4. `DECISIONS.md` 2026-05-30 entry; one-time migration of the 84 terminal rows run in this PR.

**Outcome**: BACKLOG.md reduced to a non-terminal working set; closed-ticket lookup via `BACKLOG-ARCHIVE.md` headings or git history. Backward-compatible: legacy stubs remain valid input, `validate.sh` unchanged, other pm-schema repos unaffected until they run the new archiver.

**Cross-link**: `[[CC-283]]` (dissolved by the rewrite), `[[CC-280]]` (prior manual archive run), `[[CC-281]]` (in-place index split — superseded by this model; to be reconciled in hygiene follow-up), `[[CC-282]]` (`pmctl backlog` now builds on the stabilized shape), DECISIONS.md 2026-05-30.
## CC-025b — `/skill-refine` M1+M2 advisory follow-ups ✅ 2026-05-18

**See**: BACKLOG-ARCHIVE.md

## CC-036b — dispatch handover authorized-override reconciliation ✅ 2026-05-16

**See**: BACKLOG-ARCHIVE.md

## CC-102b — CC-102 PR-gate advisory follow-ups ✅ 2026-05-17

**See**: BACKLOG-ARCHIVE.md

## CC-103b — /pr-gate executor split ✅ 2026-05-17

**See**: BACKLOG-ARCHIVE.md

## CC-104h — CC-104 handover schema docs ✅ 2026-05-17

**See**: BACKLOG-ARCHIVE.md

## CC-104i — CC-104 install.sh profile docs ✅ 2026-05-17

**See**: BACKLOG-ARCHIVE.md

## CC-281 — [process/docs] split BACKLOG index into Active and Terminal sub-sections 🚫 2026-05-30

**Dropped**: superseded by the working-set contract ([[CC-284]]). The premise — index mixes active rows with 99+ terminal rows — no longer holds: terminal `✅ closed` / `🚫 dropped` rows now leave BACKLOG.md entirely (move to BACKLOG-ARCHIVE.md), so the index already contains only non-terminal rows. An in-place active/terminal split delimiter is therefore unnecessary.

**See**: DECISIONS.md 2026-05-30 (backlog-working-set-contract).

## CC-282 — [DX/product] pmctl backlog sync — SQLite derived query layer 🚫 2026-05-30

**Dropped**: absorbed into [[CC-287]] (`pmctl backlog`). CC-287 delivers `backlog view --status/--area/--milestone` directly over the working-set index (grep/awk), which is sufficient for the maintainer's query needs. A SQLite derived store was the controversial part (it does not reduce BACKLOG.md size — see the 2026-05-30 working-set analysis) and is an optional future optimization, not a v0.3.0 requirement. Re-file under v0.4.0 if indexed queries are ever genuinely needed.

**See**: [[CC-287]] (absorbing ticket), DECISIONS.md 2026-05-30.

## CC-287 — [v0.3.0 M3] `pmctl backlog` subcommand ✅ 2026-05-30

**Problem**: pmctl is a stub ([[CC-215]] ⚠️ partial). The maintainer's active pain is backlog management, and the working-set contract ([[CC-284]]) just stabilized the BACKLOG.md shape — the ideal anchor for the first real pmctl subcommand (Phase-2 of the 2026-05-30 plan).

**Why**: `pmctl backlog` is executor-agnostic, pure runtime-layer (lower layer in the upper/lower split), and gives daily value immediately. Building it on the stabilized working-set shape avoids baking a soon-to-change structure into the parser.

**Requirement**:
1. `pmctl backlog view [--status …] [--area …] [--milestone …]` — filtered render over the working-set index (grep/awk; no SQLite — see [[CC-282]] drop).
2. `pmctl backlog lint` — wrap `pm/scripts/validate.sh`.
3. `pmctl backlog archive` — wrap `scripts/archive-closed-backlog.sh`.
4. Layer discipline: no `~/.claude` / CLI-name coupling in the backlog logic (enforced by [[CC-233]]).

**Cross-link**: `[[CC-215]]` (pmctl spine), `[[CC-284]]` (working-set contract), `[[CC-282]]` (absorbed), `[[CC-286]]` (prefix-generic next-id belongs here).

## CC-288 — [v0.3.0 M3] `pmctl guard check` ✅ 2026-05-30

**Problem**: guard logic lives in Claude-only PreToolUse hooks (`hook-codex-bash-guard.sh`, `hook-pm-write-guard.sh`). A non-Claude host (codex-as-PM) cannot enforce the same guard. CC-204 already extracted the framework to `scripts/lib/hook-framework.sh`; it is not yet wired behind pmctl.

**Why**: moving guard **logic** into `pmctl guard check` makes it shared/executor-agnostic — any host enforces the identical policy. The **trigger** stays per-adapter (Claude PreToolUse auto-hook vs codex/other explicit `pmctl guard check` call); that asymmetry is an inherent CLI-capability difference, not a design flaw.

**Requirement**:
1. `pmctl guard check --event <pre-write|pre-bash|post-task> --file/--command <val>` → exit non-zero + reason on deny, composing `scripts/lib/hook-framework.sh`.
2. Claude PreToolUse hooks may shell to `pmctl guard check` (single source of policy) rather than duplicating logic.
3. Document the trigger-asymmetry (auto-hook vs explicit) in the executor contract.

**Cross-link**: `[[CC-204]]` (hook-framework extraction), `[[CC-215]]` (pmctl spine), `[[CC-289]]` (dispatch calls guard).

## CC-290 — [ops/DX] pr-gate flag ergonomics ✅ 2026-05-30

**Problem**: two `pr-gate.sh` flag papercuts caused avoidable dispatch failures. (1) The `/pr-gate` skill and the script's own comments call a reviewer-scoped re-gate "targeted", but the flag is `--reviewers` — invoking the raw script with `--targeted` failed with `Unknown arg`. (2) An unrecognized flag printed only `Unknown arg: X` and exited, forcing a source read to recover.

**Resolution** (pr:#192): `--targeted` is now an alias of `--reviewers` (forgiving whether invoked via skill or directly); the unknown-arg path prints the accepted-flags list. Covered by `test_unknown_arg_message` + `test_targeted_alias` in `scripts/test-pr-gate.sh`.

**Cross-link**: surfaced while running gates for `[[CC-288]]`.

## CC-233 — scripts/test-layer-boundaries.sh ✅ 2026-05-31

**Closed**: `scripts/test-layer-boundaries.sh` shipped as the four-layer dependency enforcer (core/ → no CLI names / `~/.claude` / bash; adapters/ → no shared-logic calls), wired into CI. Merged via PR #197.

**Problem**: The four-layer architecture is only a discipline; nothing enforces the dependency direction.

**Why**: One cheap structural test prevents slow architecture drift (the cost the layering exists to avoid).

**Requirement**: Add `scripts/test-layer-boundaries.sh` — grep `core/` for forbidden tokens (CLI product names, `~/.claude`, bash invocations), grep `adapters/` for state-mutation calls. Wire into CI.

**Milestone**: v0.3.0 M3.

**Priority**: P3.

**Cross-link**: CC-211 (epic).

## CC-266 — adapters/claude: claude as host-independent CLI executor ✅ 2026-05-31

**Closed**: `adapters/claude/dispatch.sh` shipped as the thin `claude --print` executor (invocation + `.agent-trace/latest.last` output-contract glue), enabling the codex-as-PM → claude-executor cell and completing the 4-cell PM×executor matrix. Phase-1 feasibility confirmed. Merged via PR #195.

**Principle (2026-05-30)**: the canonical claude-executor path is a `claude --print` **CLI subprocess**, invoked by `pmctl dispatch run --adapter claude` regardless of which tool is the PM/host. `Agent()`-spawn (`agents/claude-executor.md`) is kept only as a same-host optimization when Claude is the PM. This is what makes the codex-as-PM → claude-executor cell work and completes the 4-cell PM×executor matrix. The adapter is **thin** (invocation + `.agent-trace/latest.last` glue); shared flow lives in pmctl ([[CC-289]]).

**Problem**: `agents/claude-executor.md` 描述的是「Claude 作為主線程、自己執行任務」的路徑。當主線程是 Codex（PM 在 Codex 環境執行）並想派發 Claude 作為 executor 時，這條路徑無法被外部呼叫——Codex 沒有 `Agent` tool，無法直接啟動 claude-executor subagent。

**The concrete gap**:

```
現有：
  Codex-as-PM → scripts/codex-dispatch.sh → codex CLI（executor）
  Claude-as-PM → Agent tool → claude-executor（executor）

缺失：
  Codex-as-PM → ??? → Claude CLI → claude-executor（executor）
```

**Design target（M3 `adapters/claude/` 補完）**:

`adapters/claude/dispatch.sh`（或等效）定義從 Codex 環境透過 shell 呼叫 Claude CLI 的路徑：
1. 組合 brief 內容
2. 呼叫 `claude --print "..."` 或 `claude -f <brief_file>` 等等效 CLI 介面
3. 捕捉輸出，確保 Claude executor 寫 `.agent-trace/claude-<ts>.last` + `latest.last` symlink（CC-264b output contract）
4. `scripts/dispatch-post-verify.sh` 讀取結果（executor-agnostic，不需感知呼叫者是 Codex 或 Claude）

**Relation to CC-262**: CC-262 抽象化 isolation（executor 在什麼環境跑）；CC-266 補完 dispatch 側（主線程如何跨工具呼叫另一個 executor）。`adapters/claude/` 目前只有 `isolation-map.yaml`（CC-262 M1 交付物），dispatch 路徑是 M3 缺口。

**Prerequisites**: CC-264b（output contract + dispatch-post-verify.sh），CC-262 M2（codex adapter isolation map）。

**Recommended first step**: spike — 驗證 `claude --print` 或其他 CLI flag 能從 Codex subprocess 環境被呼叫並返回可解析輸出。

**Priority**: P1 — v0.3.0 M3；host-independence 的承重點。**Phase-1 first**: feasibility 檢查（headless `claude -p` 能否吃 brief、在 working-dir 改檔、產出可擷取的 final message + trace、permission mode 設定）再進實作。

**Cross-link**: `[[CC-289]]`（pmctl dispatch run 共用流程）、`[[CC-262]]`（isolation 抽象）、`[[CC-264]]`（output contract）、`[[CC-036]]`（dispatch ergonomics）。

---

## CC-289 — [v0.3.0 M3] `pmctl dispatch run` — approach B (thin adapters) ✅ 2026-05-31

**Closed**: `pmctl dispatch run --adapter <X>` now owns the shared flow (brief construct → guard → route → invoke adapter → read `.agent-trace/latest.last` → post-verify), composing the M2-extracted libs; `codex-dispatch.sh` slimmed into the thin `adapters/codex/dispatch.sh`. Replaces the prior stub. Merged via PR #194.

**Problem**: dispatch shared logic is fused into the 475-line `scripts/codex-dispatch.sh`. If `adapters/claude/` ([[CC-266]]) re-implements it, the two adapters drift — breaking the "only the executor differs" goal.

**Why (approach B)**: pmctl OWNS the shared dispatch flow; adapters become thin. This is the only structure that achieves host-independent, drift-free executor swapping. The shared logic is already extracted into libs (M2: executor-router/handover-validate/brief-validate/dispatch-post-verify), so B is mostly composition.

**Requirement**:
1. `pmctl dispatch run --adapter <X> [brief args]` owns: brief construct → `pmctl guard check` → route → invoke adapter → read `.agent-trace/latest.last` → `dispatch-post-verify.sh`.
2. Slim `codex-dispatch.sh` into a THIN `adapters/codex/dispatch.sh` (executor invocation + output-contract glue only); preserve crash-safety + the existing regression suite.
3. Replace the current `dispatch run` stub.
4. Pairs with [[CC-266]] (claude thin adapter) → 4-cell PM×executor matrix all green.

**Risk**: touches the battle-tested `codex-dispatch.sh`. Mitigation: shared bits already in libs; full regression suite + pr-gate; slim incrementally.

**Cross-link**: `[[CC-200]]` (executor-router), `[[CC-202]]` (handover-validate), `[[CC-266]]` (claude adapter), `[[CC-215]]` (pmctl spine).

## CC-061 — 建立 skills/ 目錄 + starter SKILL.md ✅ 2026-05-31

**Closed**: shipped two thin starter skills — `skills/dispatch-brief/SKILL.md` (points to `docs/dispatch-brief.md` / `agents/project-pm.md` for the handover contract + the rules that bite) and `skills/pr-gate-review/SKILL.md` (points to `/pr-gate` + `scripts/pr-gate.sh`), both aligned to the Anthropic Agent Skills layout (`skills/<name>/SKILL.md`, `name` + `description` frontmatter). Also extended `scripts/lint-frontmatter.sh` to scan `skills/<name>/SKILL.md` (closing a second doc-drift: README §scripts claimed skills/ was linted but the scanner only covered agents/ + commands/) and added 2 `test-lint-frontmatter.sh` cases proving skills/ is scanned. `install.sh` already installs `skills/` (junction; verified it handles the nested layout). CC-014/015/026 now have the directory base they were waiting on. Merged via the CC-061 PR.

**Problem**: README 和 CC-057 指出 `skills/` 目錄不存在，但 Anthropic Skills spec 定義 SKILL.md 為可重用能力包（只在需要時載入 context）。現有 `commands/pm.md`、`commands/pr-gate.md` 有大量重用邏輯，天然適合轉成 skills。CC-014（using-git-worktrees）、CC-015（systematic-debugging）、CC-026（/skill-distill）均等待 skills/ 基礎建設。
**Why**: skills 比 commands 更輕量（context on-demand），且是 Anthropic 現在主推的擴展方式。建立 2–3 個 starter skills 能讓 CC-014/015/026 有落地路徑，也修正 README 現有聲明。
**Requirement**: 建立 `skills/dispatch-brief/SKILL.md`（封裝 brief 建立 + handover validate 流程）和 `skills/pr-gate-review/SKILL.md`（封裝 reviewer 派發流程）；在 install.sh 的 helper scripts 區段加入 `skills/` symlink；README skills/ 目錄說明改為實際有內容。先行條件：CC-057 (A) 完成後執行此條。

## CC-294 — [ops] install.sh CLAUDE_HOME not overridable ✅ 2026-05-31

**Closed**: `install.sh`, `uninstall.sh`, `scripts/install-hooks.sh`, and `scripts/uninstall-hooks.sh` now honor an explicit `CLAUDE_HOME` env override (`CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"`), and every install/uninstall destination derives from `$CLAUDE_HOME` — the bare `$HOME/.claude` references that previously bypassed it (`.pm` dest + install manifest in install.sh; the hook `settings.json` + `statusline-chain.conf` in install-hooks.sh **and** uninstall-hooks.sh; the `.pm-dispatch` removal + leftover-dir sweep in uninstall.sh) are routed through it. `install.sh`/`uninstall.sh` pass `CLAUDE_HOME` to the hook (un)install sub-scripts **per-call (not exported)** so it does not leak into the `--verify` preflight's nested `run-all-tests` → test-install installs (which must default to their own `$HOME`). README install section documents the override. +2 `test-install.sh` cases assert an override redirects both install and uninstall, removes the override's hook wiring, and leaves a sentinel `$HOME/.claude` config untouched (the test fails if `uninstall-hooks.sh` regresses to real-home). Gate-driven: the first NO-GO caught that `uninstall-hooks.sh` still resolved `$HOME/.claude` (architecture-reviewer) and the uninstall test was too weak to prove the real-home boundary (qa-tester block + critic).

**Problem**: destination was hardcoded `$HOME/.claude` with no env/flag override, so install changes could not be rehearsed against a sandbox dir without overriding the whole `$HOME` (a blunt instrument that also moves every other `$HOME` reference). Surfaced 2026-05-31 during CC-061 install verification — a `CLAUDE_HOME=<tmp>` attempt was silently ignored and symlinked branch-only skills into the real `~/.claude/skills/`.

**Cross-link**: `[[CC-061]]` (where it surfaced).

## CC-292 — [ops] dispatch default model = gpt-5.5; decouple from host codex config ✅ 2026-05-31

**Closed**: shipped via PR #199 (adapter pins the data-backed `default` alias → gpt-5.5, decoupled from `~/.codex/config.toml`; `dispatch.default_model` config override shape-guarded; handover-validate accepts dotted ids) + PR #200 (shape-guard fallback test). Also reframed executor-agnostic: PM-facing surfaces name the `default` alias, never a wire model (model identity is per-executor). See [[dispatch-default-model]].

**Problem**: When a dispatch omits `--model`, `adapters/codex/dispatch.sh` passed no `-m` to `codex exec`, so codex fell back to the host's `~/.codex/config.toml` `model`. The user sets that to `gpt-5.3-codex-spark` for interactive use — so **pr-gate and `/pm` dispatch silently ran on spark**. `share/model-aliases.tsv` even documented the wrong assumption (`<default> (no --model) — gpt-5.3-codex`), which never held on a spark-defaulted host.

**Why**: The gate is analysis-heavy (it does not know where issues are) and must run on a full model. spark draws from a separate, independent usage pool and has a lower context ceiling — correct for known-small, single-location changes, wrong as the silent system default.

**Fix (shipped)**:
1. `adapters/codex/dispatch.sh` pins `DEFAULT_DISPATCH_MODEL="default"` (the data-backed `default` alias, which resolves to `gpt-5.5` via `share/model-aliases.tsv` — the wire id lives in the TSV alone); when `--model` is omitted the adapter injects it (precedence: `--model` flag > `~/.pm-dispatch/config` `dispatch.default_model` > built-in `default` alias). Decoupled from `~/.codex/config.toml`.
2. Wired the previously-reserved `dispatch.default_model` config key (config parse refactored to one direct-call `_load_pm_config` setting globals, preserving timeout precedence).
3. `share/model-aliases.tsv` + `docs/dispatch-brief.md`: added a data-backed `default → gpt-5.5` alias (the adapter references the alias, so the wire id lives in the TSV alone — single source of truth) plus `gpt-5.5`/`gpt-5.4` rows (effort `high`); corrected the default-model comment; spark documented as an independent usage pool.
4. `scripts/lib/handover-validate.sh`: model regex now allows `.` so dotted wire ids (gpt-5.5/gpt-5.4) are valid handover `model:` values — invariant: every `model-aliases.tsv` alias is handover-valid.
5. `agents/project-pm.md` model-selection guidance names the `default` alias (→ gpt-5.5) + spark opt-in criteria.
6. Tests: 6 new `test-codex-dispatch.sh` cases (default→gpt-5.5+high, explicit 5.5/5.4, `default` alias, config override, flag-beats-config precedence) + 1 `test-dispatch-handover.sh` case (dotted ids accepted). `lint-model-aliases.sh` / layer-boundaries / validate green.

**Fallback policy**: `gpt-5.4` is config-overridable, not runtime auto-retry — model availability is a stable host property, so a per-host config switch suffices and keeps the battle-tested dispatch path simple.

**Cross-link**: `[[CC-060]]` (codex model/config externalization).

## CC-295 — [docs] architecture conformance reconciliation ✅ 2026-05-31

**Closed**: a read-only architecture audit (codex + Claude, 2026-05-31) compared the built code against `docs/architecture/v0.3.0-synthesis.md`. Added a **Conformance status (as-built)** section to the synthesis doc and annotated §5.1 / §6 / §7 + `MILESTONES.md` so the blueprint is an honest north star again.

- **A (deliberate divergences, now canonical in the doc)**: `runtime/` is realized as `cli/pmctl` + `scripts/lib/*` (not a `runtime/` dir); both codex + claude thin adapters ship in v0.3.0 (synthesis had codex deferred); `pmctl` ships backlog/guard/dispatch only (validate/task/decision/trace/safe-bash → v0.4.0); milestone numbering is M0–M6 (MILESTONES.md authoritative; synthesis §6 is M0–M5 design rationale).
- **B (known-open, documented as pending a scoping decision under [[CC-211]])**: single-writer rule not met (adapters write `runs.jsonl`; `layout.yaml` self-admits "aspirational"); markdown/JSONL rule not met (`routing_log.md` still machine-written alongside `runs.jsonl`); schema-first but not state-first (only `Run` written; `Event`/`Review`/`Decision` schema-only); `pm/` did not fold into `core/` (validator is an executable, forbidden in `core/`); `mcp/README.md` not built + no general `pmctl --json`.

This ticket is the **doc reconciliation (A)** only; the **B** items are deliberately left as documented-open for a separate scope decision (spine release vs. realize state-first).

**Cross-link**: `[[CC-211]]` (v0.3.0 arch epic), `[[CC-233]]` (layer enforcer that codified the adapter-state-logging allowance).
## CC-059 — Thin /pm.md：把 runtime 執行邏輯移入 scripts ✅ 2026-05-31

**Closed**: M4 的最後一票。原票（2026-05-18）要求「把 runtime 邏輯移入 `scripts/pm-dispatch-runner.sh`」的前提已過時：M0–M3 的抽取（CC-200 executor-router、CC-202 handover-validate、CC-289 dispatch run…）早已把 brief/handover/dispatch 邏輯搬進 `scripts/lib/`，`commands/pm.md` 現在只剩 65 行（意圖 + 行為約束 + 腳本指標）。pm.md 殘留的步驟 1–10 是**主執行緒 tool-call 編排**（`Agent` spawn、`BashOutput` 讀取、exit-124 retry），本質上塞不進 shell，因此不寫 `pm-dispatch-runner.sh`。真正的殘留（approach B「複用抽取」）是步驟 4–8 的 post-verify 驗證程序仍以散文重複，而 `scripts/dispatch-post-verify.sh`（CC-264b）已實作同邏輯且有測試。交付：(1) 把 `dispatch-post-verify.sh` 參數化吃 `--last/--stderr/--brief-file`（footer 給的 per-run 路徑，race-safe；省略時 fallback `latest.*`，保住 `pmctl dispatch run` + codex-executor 既有呼叫者）+ `--base <ref>`（merge-base `<base>...HEAD` 語義，保留 /pm 對 non-origin/main 整合分支的 base-aware diff,advanced base 不會帶入無關 upstream commits）+ 對 flag 路徑套用既有 `.agent-trace` 圍堵 guard + 對 flag-supplied `--stderr` fail-closed（missing → FAILED；positional `latest.stderr` 維持 optional，不影響 pmctl/codex-executor）；(2) `commands/pm.md` 驗證主體塌縮成單一 `dispatch-post-verify.sh` 呼叫；JSONL `command_execution` 證據交叉檢查（證明每個 `self_verify:` 真的有跑,vs 腳本的 final-message `cmd: pass` 宣稱）**保留**為主執行緒步驟（executor-agnostic 腳本無法做）；(3) flag parser 對 value-taking flag 加 missing/flag-shaped value 防呆（`--last --stderr X` 報 usage 而非後段 not-found）；`test-dispatch-post-verify.sh` +17 cases（override OK、圍堵拒絕、fallback、supplied-`--stderr` fail-closed、--brief-file、ambiguous、unknown flag、missing-value、flag-as-value、完整 /pm flag-combo shape、--base diff（含 base-dependent content 斷言）、--base merge-base 排除 advanced upstream、--base HEAD fallback、`--` positional sentinel），21→38 全綠。Merged via PR #204。

**Problem**: `commands/pm.md` 包含 brief file 建立、handover validation、Codex dispatch、background mode、BashOutput tracking、stderr parsing、git diff verify、exit 124 retry 等大量流程邏輯。markdown command 逐漸變成「半程式碼、半 prompt、半 policy」的混合體。
**Why**: 當 Codex CLI、Claude Code hooks 或 scripts 行為改變時，markdown command 很容易與實際腳本 drift。script 有測試；markdown 沒有。
**Requirement**: 識別 pm.md 中可搬到 shell script 的 runtime 步驟（特別是 handover extraction + validation + dispatch 命令組裝）；移入 `scripts/pm-dispatch-runner.sh`（或直接加強 `scripts/lib/`）；pm.md 只保留「什麼情境呼叫什麼腳本」的意圖描述與 trigger 條件。依賴 CC-200（executor-router.sh）。

## CC-208 — Gate reviewer hallucination: document citation without verification ✅ 2026-06-01

**See**: pr:#206

**Problem**: Gate reviewers (primarily qa-tester) cite non-existent documents in
findings. Observed example: "AGENT.md §3" — this file does not exist in the repo.
The citation is used to justify a block verdict, forcing the main thread to manually
verify the reference before deciding to override or fix.

**Why**: Reviewer agents receive a diff, their agent definition, and the gate brief.
They do not receive a file listing or document index, so they infer docs from training
data and context rather than confirming existence. The constraint in their definition
does not currently include "only cite documents you can confirm exist."

**Requirement** (any of the following):
1. Inject a verified file list (e.g., `find . -name "*.md" | sort`) into the gate
   brief preamble so reviewers can cross-check citations before writing findings.
2. Add an explicit instruction to each reviewer agent definition: "Do not cite any
   document, section, or rule file by name unless you can confirm it appears in the
   diff or in documents read during this session."
3. Gate synthesis step verifies reviewer document citations against actual repo files
   and flags unverifiable references as advisory-only rather than blocking.

**Priority**: P3 — non-urgent. Occurs on ~30% of gate runs based on observed pattern.
Each occurrence adds ~1–2 min of manual verification overhead.

## CC-291 — [arch] guard profile = role × runtime (PM is a role; codex/claude are runtimes) ✅ 2026-06-01

**See**: pr:#205

**Origin (user, 2026-05-31, during CC-266 review)**: 在 `pmctl guard check --profile pm|codex|claude` 裡,`pm` 是「角色」,`codex`/`claude` 是「runtime」——兩個正交的軸被壓成一條扁平清單。User 的直覺:**PM 本身應該是一種 agent(角色),底下由 codex 或 claude 來執行**。這個直覺是對的,而且現況已半實現:`--profile pm` 已是 runtime-agnostic(codex-as-PM 顯式呼叫、claude-as-PM 走 PreToolUse,共用同一個 project-pm 政策)。

**The conflation**:

```
            codex            claude
  PM     codex-as-PM      claude-as-PM     ← guard 都用 `pm` 政策(已收斂)
  exec   codex-executor   claude-executor  ← guard 用 codex/claude(未收斂)
```

3 個 profile 覆蓋 4 cell,因為 PM 角色跨 runtime 收斂成一個;executor 角色才被 runtime 切成兩個。命名也不一致:`pm` 是角色名,`codex`/`claude` 是 runtime 名。

**Target model**: guard 吃 **`--role <pm | executor | …>`**(runtime-agnostic),runtime 由 dispatch 的 `--adapter` 決定。**guard 關心角色;dispatch 關心 runtime。**

- PM 角色 → 一個政策(memory 目錄),跨 runtime(現況已如此)。
- executor 角色 → 在 **dispatch-guard 層**,codex 與 claude 的政策其實一模一樣(`/tmp/brief-*.md`),所以本來就能收斂成一個 `executor`。

**Two layers must stay distinct(重要,別合錯)**:
- **dispatch-guard(pmctl `guard check`)** = role-based:檢查 brief 落點,與 runtime 無關。
- **PreToolUse hook** = runtime-specific:codex-executor 是薄 dispatcher(只准寫 `/tmp/brief-*.md`)vs claude-executor 自執行(改 work-dir,靠 harness/`--permission-mode`)。這層 key 在 `agent_type` 上,真的因 runtime 而異——**不可**一起收斂掉。

**Generalization(user 明確要求)**: 未來任何「會寫檔、需要 guard」的 agent 角色——spike、reviewer、doc-writer、feature-agent 等——都應**註冊成一個 ROLE**(role-keyed guard registry),而非每加一個 (role,runtime) 組合就在扁平清單塞一項。**新增 runtime 是 adapter 的事;新增角色才動 guard。**

**Scope / touch points**:
- `scripts/lib/pmctl-guard.sh`:`--profile` → `--role`;role → 政策對應(role-keyed);呼叫端遷移或向後相容別名。
- `agent_type` 慣例:釐清 (role,runtime) tuple 與 role 的關係;PreToolUse hooks 維持 runtime-specific。
- 測試:`test-pmctl-guard.sh` / `test-hooks.sh` 全綠;fail-closed 不可破。

**Risk**: 動到 [[CC-288]] battle-tested guard 面 + agent_type 慣例 → 需完整 guard/hook 測試覆蓋,且不可破 fail-closed。非阻塞 spine(P2);適合 spine 收尾後、或與 [[CC-233]](分層強制器,正好一起想 guard 的層界)一起做。

**Cross-link**: `[[CC-288]]` (guard surface), `[[CC-233]]` (layer boundaries), `[[CC-266]]` / `[[CC-289]]` (executor model).

## CC-300 — citation guard: verified file index injection + codex-dispatch allowlist bootstrap ✅ 2026-06-01

**See**: pr:#206

**Problem**: Implemented as the fix for `[[CC-208]]`. Gate reviewers cited hallucinated
documents because they had no verified file listing. Each false citation added ~1–2 min
manual verification overhead per gate run.

**Implemented in pr:#206**:
- `scripts/pr-gate.sh`: injects a verified file index (repo `.md` + changed files) into
  every gate brief preamble, giving reviewers a reference list to check citations against.
- `install.sh` + `scripts/doctor.sh`: adds four `Bash(codex-dispatch.sh:*)` and
  `Bash(adapters/codex/dispatch.sh:*)` permission entries to Claude `settings.json` on
  install; doctor validates their presence and fails with a remediation hint if absent.
- `scripts/test-pr-gate.sh`: coverage for citation-guard injection in sequential,
  per-reviewer parallel, and synthesis paths.

**Cross-link**: `[[CC-208]]`（original problem）、`[[CC-301]]`（chain coexistence fix landed same cycle）、`[[CC-302]]`（allowlist backup path follow-up）、`[[CC-303]]`（allowlist dedup follow-up）.

## CC-301 — cross-repo chain coexistence: multi-line statusline-chain.conf + uninstall allowlist removal ✅ 2026-06-01

**See**: pr:#207

**Problem**: Re-running `scripts/install-hooks.sh` (pm-dispatch) over an existing
`statusLine` command from another tool (e.g. claude-account-switcher) clobbered all
but the first chained hook. Root cause: `install-hooks.sh` and `hook-save-rate-limits.sh`
both read only the first line of `statusline-chain.conf` via `head -1` / single `read`.
Additionally, `uninstall-hooks.sh` did not remove the four dispatch `Bash(...:*)` allowlist
entries added by `install.sh`, leaving persistent permission expansions after uninstall.

**Implemented in pr:#207**:
- `scripts/install-hooks.sh`: added `write_statusline_chain()` that preserves all existing
  non-self chain entries when updating the chain conf.
- `scripts/hook-save-rate-limits.sh`: changed `head -1` to a while-loop so all chain lines
  are executed, skipping blank and `#` comment lines.
- `scripts/uninstall-hooks.sh`: removes the four managed Bash dispatch allowlist entries
  inside the same atomic jq transform used for hook and statusLine cleanup.
- Tests: multi-line chain execution order, chain preservation on re-install, allowlist
  removal and dry-run idempotency.

**Cross-link**: `[[CC-300]]`（same PR cycle）、`[[CC-302]]`（allowlist backup path）、`[[CC-303]]`（allowlist construction dedup）.

## CC-304 — hook-save-rate-limits.sh: _rate_tmp trap leak + stale temp startup cleanup ✅ closed (PR #209)

**Problem**: `_rate_tmp` (the atomic-write temp file for `~/.claude/rate-limits.json`) was
initialized inside a conditional block after the `trap 'rm -f "$_tmp"' EXIT` declaration,
so the trap never covered it. An interrupted hook invocation (timeout, SIGTERM, SIGKILL)
left behind `.rate-limits.json.tmp.*` files in `~/.claude/`. Observed: 19 stale files
spanning 2026-05-26 to 2026-06-01, still accumulating during normal use.

**Root cause (two parts)**:
1. `_rate_tmp` not in EXIT trap → orphaned on SIGTERM/unexpected exit
2. SIGKILL bypasses bash traps entirely → residue accumulates even with correct trap

**Fix (pr:TBD)**:
- Initialize `_rate_tmp=""` before the trap; extend trap to `rm -f "$_tmp" "${_rate_tmp:-}"`
- Add startup `find "$_config_dir" -maxdepth 1 -name '.rate-limits.json.tmp.*' -mmin +60 -delete` unconditionally (runs before early-return on empty payload), clearing residue from any prior interrupted run
- Tests: stale file deleted at startup; fresh file preserved

**Priority**: P2 — was actively accumulating, no data loss but adds noise to `doctor.sh` output.

**Cross-link**: `[[CC-301]]`（same hook, chain fix）、`[[CAS-hook]]`（mirror fix in claude-account-switcher）.
## CC-302 — install_dispatch_allowlist: add backup path before settings.json mutation ✅ closed 2026-06-01

**See**: pr:#211

**Cross-link**: `[[CC-300]]`、`[[CC-301]]`（context of the allowlist introduction）.

## CC-303 — allowlist entry construction duplicated in install.sh and doctor.sh — centralize ✅ closed 2026-06-01

**See**: pr:#211

**Cross-link**: `[[CC-300]]`、`[[CC-302]]`.

## CC-207 — Windows Git Bash symlink fallback: use mklink /J in install.sh ✅ 2026-06-03

**See**: pr:#220

**Resolution**: Implemented in PR #220 (the Windows-compatibility branch). `install.sh` now
installs directory targets (`agents/`, `skills/`, `commands/`, `adapters/`, `.pm`)
as Windows junctions via `make_junction_windows` / `install_dir_junction` on the
`windows` platform, with per-file copy as the last-resort fallback — exactly the
"detect Git Bash, use junctions instead of silently copying" branch this item
asked for. Junction & copy-aware coverage in `test-install.sh` / `test-uninstall.sh`.

**Problem**: On Git Bash (OSTYPE=msys/cygwin), `ln -s` silently falls back to file
copy rather than creating real symlinks. After pulling pm-dispatch updates, users
must re-run `bash install.sh` to sync the copies (83 files across agents/, commands/,
scripts/, .pm). This breaks the "pull = auto-sync" expectation that Linux/macOS/WSL2
users have.

**Why**: NTFS symlinks require Windows Developer Mode or `MSYS=winsymlinks:nativestrict`
which cannot be assumed for all users. Directory junctions (`mklink /J`) are available
without elevated privileges but require calling PowerShell from bash.
The current copy fallback is correct as a safety net; the missing piece is an explicit
Git Bash detection branch that uses junctions instead of silently falling back to copy.

**Requirement**:
1. `install.sh` detects Git Bash via `$OSTYPE == msys*` or `cygwin*`
2. Uses `powershell.exe -Command "cmd /c mklink /J ..."` for each per-file link target
   (`mklink /J` = directory junction; no admin or developer mode required)
3. Verified: junction survives PATH resolution and Claude Code session startup on Windows
4. `test-install.sh` gains a smoke test for the junction path (skip on non-Windows CI)
5. `docs/platform-support.md` updated to reflect auto-sync is restored

**Workaround**: after pulling updates, re-run `bash install.sh` to re-copy files.

## CC-260 — pr-gate.sh: dirty-worktree fail-loud preflight ✅ 2026-06-01

**See**: pr:#214

**Problem**: When a branch has committed changes, `scripts/pr-gate.sh` uses `git diff "$BASE"...HEAD` to build the reviewer brief stat. This silently omits uncommitted tracked changes (`git diff HEAD`) and untracked files. During CC-229 Gate 12, the brief stat did not include `install.sh` and `scripts/test-schema-task-mirrors-backlog.sh` which were in the dirty worktree but not yet committed.

**Why**: Gate reviewers can only assess what's in the brief. Silently omitting working-tree changes means new files and tracked modifications that haven't been committed are invisible to reviewers. This is especially impactful for long-running iterative gate sessions where fixes accumulate in the working tree before a final commit.

**Requirement**:
- Detect dirty worktree (tracked changes or non-gitignored untracked files) when the branch has committed `BASE...HEAD` changes.
- Without `--allow-dirty`, fail loud with exit 3 and guidance to commit first or opt into dirty review scope.
- With `--allow-dirty`, fold the working tree into scope: committed + uncommitted tracked changes via `git diff "$BASE"` and non-gitignored untracked files via `git ls-files --others --exclude-standard`.
- Preserve the existing dirty-only-no-commit behavior: no preflight failure because the working-tree fallback already reviews those changes.

**Acceptance**:
1. Committed `BASE...HEAD` changes + dirty worktree without `--allow-dirty` → exit 3 with guidance.
2. `--allow-dirty` folds committed + working-tree changes into review scope.
3. Dirty-only-no-commit worktrees are still reviewed by the existing fallback.
4. `bash scripts/test-pr-gate.sh` → exit 0.
5. `bash scripts/run-all-tests.sh` → exit 0.

**Milestone**: v0.3.x (post-M1); prioritize before the next multi-gate iterative fix session.

**Priority**: P2 — operational correctness for gate reviews; detected as real drift in CC-229 gate cycle.

---

## CC-262 — Executor isolation 抽象層：`isolation_level` 欄位 + adapter 轉譯契約 ✅ 2026-06-03

**See**: pr:#162/#175/#180

**Resolution (2026-06-03, CC-274 reconcile)**: All segments shipped. `core/policy/isolation-level.yaml`
defines **5** levels — `none | read-only | workspace-write | workspace-network | sandboxed` (M2/#175 added
`workspace-network`). `adapters/claude/isolation-map.yaml` (no-op, #162) and `adapters/codex/isolation-map.yaml`
(5-level native mapping, present) both exist; `scripts/codex-dispatch.sh` expands `isolation_level` before
dispatch (#175); `agents/project-pm.md` PM template uses `isolation_level:` (#180). `sandboxed` is **best-effort**
(Codex has no true ephemeral mode → maps to `workspace-write` with no network), not full isolation. The stale
planning text below is retained for history; the bracketed corrections inline reflect the as-built state.

**Problem**: 現行 brief schema 中 `sandbox`、`approval`、`skip_git_check` 是 Codex 原生欄位，直接出現在 PM 撰寫的 brief 裡。當 executor 為 `claude` 時，PM 必須填入 canonical no-op 值（`workspace-write` / `never` / `false`）——這是 leaky abstraction：brief 層洩漏了底層 executor 的實作細節。

**Why**: 用戶設計目標：「功能與執行環境分離」。Brief 應表達隔離 *意圖*（需要什麼程度的保護），adapter 層負責把意圖翻譯成各 executor 的原生機制。這樣未來加入新 executor（opencode、antigravity）只需新增一個 adapter map，不需改動 brief schema 或 PM 撰寫規則。與 v0.3.0 的 `adapters/` named-slot 架構完全吻合。

**Requirement**:
- `core/policy/`（CC-231 延伸）：新增 `isolation_level` enum，值為 `none | read-only | workspace-write | workspace-network | sandboxed`〔as-built: 5 值，M2/#175 補入 `workspace-network`〕，附語意定義（none=無限制；read-only=不寫 FS；workspace-write=僅寫 project dir；workspace-network=workspace-write + localhost TCP；sandboxed=〔as-built: best-effort 最強隔離，Codex→workspace-write 無網路〕）
- `adapters/codex/isolation-map.yaml`：每個 `isolation_level` 值 → Codex 原生 `sandbox` + `config_overrides` 對應表〔as-built: ✅ present，5 級映射〕
- `adapters/claude/isolation-map.yaml`：每個 `isolation_level` 值 → no-op（claude-executor 無 sandbox flags）（v0.3.0 M1 殘留，當前範圍）
- `agents/project-pm.md`：PM brief template 改寫 `isolation_level:` 取代三個原生欄位；說明三個原生欄位為 adapter-generated，PM 不直接填寫
- `scripts/codex-dispatch.sh`：dispatch 前讀取 `adapters/codex/isolation-map.yaml` 展開 `isolation_level` → 原生欄位；遇未知值 → 立即 exit 1 with error

**Acceptance (M1 scope — adapters/claude only)**:
1. `grep -q "isolation_level" core/policy/executor-enum.yaml` → match（或對應 policy 檔案）
2. `cat adapters/claude/isolation-map.yaml` → 檔案存在，包含 4 個 no-op 映射
3. `bash scripts/run-all-tests.sh` → exit 0

**Acceptance (M2 scope — ✅ landed #175/#180)**:
4. `grep "isolation_level" agents/project-pm.md` → 至少一個 match；`grep 'sandbox.*workspace-write' agents/project-pm.md` → PM brief template 區段無此行
5. `bash scripts/test-codex-dispatch.sh` → exit 0（含 isolation_level 展開測試）

**Acceptance (adapters/codex scope — ✅ landed)**:
6. `cat adapters/codex/isolation-map.yaml` → 包含全部 5 個 isolation_level 的映射〔as-built: present〕

**Scope revision 2026-05-25**: adapters/codex 原移至 v0.4.0。〔Superseded 2026-06-03: 已落地，見上方 Resolution。〕

**M1 shipped (2026-05-25, PR #162)**: `core/policy/isolation-level.yaml` and `adapters/claude/isolation-map.yaml` created. **M2 + adapters/codex shipped (PR #175/#180)** — see top Resolution; item closed 2026-06-03 via CC-274 reconcile.

---

## CC-274 — docs: reconcile CC-262 planning text with shipped isolation implementation ✅ 2026-06-03

**See**: pr:#175

**Resolution**: Reconciled 2026-06-03. CC-262 body's three stale points corrected inline
(enum now 5 values incl `workspace-network`; `sandboxed` = best-effort not 完整隔離; M2 +
adapters/codex acceptance marked landed #175/#180), CC-262 closed to match MILESTONES ✅,
and the stale "(adapters/codex isolation-map 仍 v0.4.0)" note removed from MILESTONES §M1.

**Problem**: CC-262 in BACKLOG.md has three stale areas flagged by Round 11 gate critic:
1. Requirement block lists only 4 enum values (`none | read-only | workspace-write | sandboxed`) — `workspace-network` (shipped in M2 / PR #175) is missing.
2. Sandboxed semantic still says "完整隔離" but the Codex adapter maps it to `workspace-write` (best-effort, no true ephemeral mode); `core/policy/isolation-level.yaml` and adapter comments now reflect this.
3. Acceptance (M2) and Acceptance (v0.4.0) still mark `codex-dispatch.sh` expansion and `adapters/codex/isolation-map.yaml` as "deferred" — both shipped in PR #175.

**Fix**:
- Update CC-262 Requirement block to list all 5 enum values including `workspace-network`.
- Correct sandboxed semantic to "best-effort strongest isolation; Codex maps to workspace-write".
- Mark M2 and v0.4.0 acceptance criteria as landed (PR #175).

**area**: docs
**Priority**: P2 — stale planning text causes confusion when reading the BACKLOG for future isolation work.

**Raised by**: critic [medium] × 3, Round 11 gate (feat/cc206-gate-hooks).

---

## CC-293 — [arch] lift default/config resolution into pmctl runtime ✅ 2026-06-02

**See**: pr:#216

**Problem**: `adapters/codex/dispatch.sh` owned default-model selection and `dispatch.default_model` config precedence — policy-like resolution in a thin adapter, flagged by critic + architecture-reviewer at CC-292 gate. Deferred until a second adapter needed the same config axis.

**Trigger met**: adding `adapters/claude/dispatch.sh` (CC-305 / pr:#216) created the second shared dispatch config axis, fulfilling the deferral condition.

**Resolution**: `scripts/lib/pmctl-config.sh` centralizes config parsing. `pmctl-dispatch.sh` calls `pm_config_load` in `pmctl_dispatch_run` and exports `PM_CFG_TIMEOUT` + `PM_CFG_DEFAULT_MODEL` to the adapter subprocess — adapters receive config values via env rather than sourcing the config file themselves. Both adapters dropped all config-loading code; their existing `elif [[ -n "${PM_CFG_TIMEOUT:-}" ]]` / `${PM_CFG_DEFAULT_MODEL:-}` branches now consume the exported values. Precedence maintained: `--timeout`/`--model` flags (parsed last) win over everything; adapter-specific env vars (`CODEX_DISPATCH_TIMEOUT`, `CLAUDE_DISPATCH_TIMEOUT`) are next; pmctl-exported config (`PM_CFG_TIMEOUT`, `PM_CFG_DEFAULT_MODEL`) is third; adapter built-in default (1200 / `default` alias) is fallback for direct invocations without pmctl.

**Cross-link**: `[[CC-292]]` (origin), `[[CC-289]]` (`pmctl dispatch run`), `[[CC-211]]` (v0.3.0 arch epic), `[[CC-305]]` (trigger).


## CC-297 — [arch] register `reviewer` as a guard role ✅ 2026-06-02

**See**: pr:#218 (open, gate GO 2026-06-02)

**Origin (user, 2026-06-01, during CC-291 work)**: 「pr-gate 應該也算是一種 role 你覺得呢」+ 隨後的挑論：reviewer 最多 5 個方向、不一定全用；又有 parallel/sequential 差異；user 傾向「**統一套用一條固定防範規則**」。對——pr-gate 的 reviewers + synthesis 是會寫檔、需要 guard 的 agent，正是 CC-291 generalization 的下一個具體實例，繼 `pm` / `executor` 之後。

**Design（定調 2026-06-01）— 一個 role、一條固定規則、綁目錄**：
- **一個 `reviewer` guard-role**，對應 5 個 reviewer agent-type + synthesis。漂亮示範 CC-291 的「role ≠ agent-type」：多 agent-type → 一個 guard-role。
- **固定規則 = 只能 Write 到 `.gate-results/` 目錄**。綁**目錄不綁檔名**：parallel 寫 `.gate-results/reviewer-<r>-<ts>.md`、sequential 寫 `.gate-results/gate-<ts>.md`，兩模式一條規則。
- **跨 tier-subset 統一**：用幾個 / 哪幾個 reviewer 是 tier/orchestration 的決定，guard 不列舉 reviewer。
- **brief 排除**：`.gate-briefs/` 由 pr-gate.sh / orchestrator 寫，不是 reviewer 寫，不放進 reviewer 規則。
- **兩條 dispatch 路徑均用顯式 `pmctl guard check`**（設計演進 2026-06-02）：codex-route 和 claude-route reviewer brief 都內嵌 `pmctl guard check --role reviewer --runtime ${EXECUTOR} --event pre-write --file ${OUTPUT_FILE}` 約束；**不走 auto PreToolUse hook**（CC-291 uniform explicit design）。
- **`--output` 覆寫例外**：operator 信任逃生口，文件化。

**Resolution（pr:#218）**:
- `scripts/hook-reviewer-write-guard.sh` — policy backing script，reviewer Write/Edit 必須落在 `.gate-results/`；`CLAUDE_HOOK_REVIEWER_GUARD=off` bypass；audit log
- `pmctl guard check` 新增 `--role reviewer`；所有 role（含 pm）現在都需要 `--runtime`；pm/reviewer runtime 驗 `codex|claude` enum
- Sequential + parallel reviewer brief 均內嵌顯式 `pmctl guard check` 約束
- `cli/pmctl` 修正 symlink REPO_ROOT 解析（loop-based resolver，覆蓋相對 symlink 路徑）
- `docs/spikes/fanout-dispatch-spike.md` — fan-out 架構 spike（推薦 v0.4.0 Approach B: `pmctl gate run`）
- Tests: test-hooks.sh 346/0, test-pmctl-guard.sh 57/0, test-pr-gate.sh 78/0; gate GO (standard tier)

**Cross-link**: `[[CC-291]]`（role-keyed registry）、`[[CC-288]]`（guard surface）、`[[CC-298]]`（brief 位置統一）。

## CC-298 — [arch] 統一 brief 落點 + 產物檔名去 runtime 化 ✅ 2026-06-02

**See**: pr:#216

**Resolution**: pr-gate brief output moved to `.gate-briefs/` (runtime-agnostic shared directory); brief filenames no longer carry runtime tokens (`pr-gate-<ts>.md` rather than `codex-pr-gate-<ts>.md`); `.codex-briefs/` runtime-named historical directory removed. Defense-in-depth enforcer extension (preventing re-introduction of runtime-named data paths under `scripts/`) captured as separate deferred follow-up in [[CC-306]].

**Origin (user, 2026-06-01, during CC-297 discussion)**: User flagged the runtime-named brief directory and runtime-tokenized artifact names; the target was one shared brief location for claude/codex and an in-file record of which model executed. This is CC-291（runtime 是 adapter 的事）/ CC-233（core 不放 CLI-named 檔）同一條界線，延伸到**資料產物**。

**現況（grounded）**:
- ✓ dispatch brief 已 runtime-agnostic：`adapters/codex/dispatch.sh` 與 `adapters/claude/dispatch.sh` 都收 `--brief-file`，guard 政策對兩者都是 `/tmp/brief-*.md`（讀取端已統一）。
- ✗ pr-gate：the old `BRIEF_DIR` used a runtime-named brief directory（`scripts/pr-gate.sh:360`），且 claude route 的 brief 檔名帶 runtime（combined/reviewer variants，L495/L684）。
- ✗ trace 檔名帶 runtime：`.agent-trace/codex-<ts>.{jsonl,last,stderr}`、`claude-<ts>.*`（消費端讀 `latest.*` symlink，已 agnostic）。

**Target**:
1. **brief 落點統一**：pr-gate 的 brief 目錄改成 runtime-agnostic 目錄（例如 `.gate-briefs/` 或與 dispatch 共用一個 `.pm-briefs/`）；brief 檔名去掉 `claude`/`codex` token。codex/claude 都從同一處讀。
2. **產物檔名去 runtime 化**：生成的資料產物（brief、gate result、reviewer output）檔名不帶 runtime；**執行的 model 記在檔案內容**（gate result frontmatter 已有 `reviewers:` / `mode:`，可加 per-artifact `executed_by:`；brief header 加一行）。

**Scope 邊界（別過度延伸）**:
- `adapters/<runtime>/` 腳本目錄本就 runtime-specific——它們**是** adapter，CC-233 明確允許 adapter 以 runtime 命名。不在此票。
- `scripts/codex-dispatch.sh` / `scripts/claude-dispatch.sh` 是 adapter 入口（shim 已由 [[CC-296]] 排程移除）——屬 adapter 名，不在此票。
- executor-internal **trace 格式**本就 runtime-specific（codex JSONL vs claude JSON）；trace **檔名**是否一併中性化待議——消費端已用 `latest.*`，價值較低，可作 forensic 保留 runtime 名或一併改。實作時定。

**防回歸（可選）**: 考慮把 [[CC-233]] 的 layer-boundary enforcer 擴及「`scripts/` 內以 runtime 命名的**資料路徑**」，避免日後又長出 `.codex-*` 資料目錄。

**Why deferred / P2**: 一致性清理，user-flagged；非阻塞當前流程，但會動到 pr-gate + trace 命名的多處 caller，需一次到位 + 測試。先讓 CC-291 落地。

**Cross-link**: `[[CC-291]]`（runtime=adapter concern）、`[[CC-233]]`（no CLI-named files）、`[[CC-289]]`（dispatch orchestrator）、`[[CC-297]]`（reviewer role，brief 排除）。

## CC-305 — [ops/gate] concurrent pmctl dispatch runs race on latest.* symlinks ✅ 2026-06-02

**See**: pr:#216

**Problem**: When two or more `pmctl dispatch run` calls target the same `<work_dir>/.agent-trace/` (e.g. pr-gate parallel reviewer fan-out), each adapter calls `ln -sfn <adapter>-<ts>.last latest.last` on finish. A second dispatch that finishes between the first adapter's end and its post-verify check silently overwrites `latest.*` → `dispatch-post-verify.sh` sees an empty or wrong `.last` → `latest.last is empty` false failure, or worse, verifies the wrong run's output.

Discovered 2026-06-01: concurrent codex + claude smoke test; codex exit 0 and correct output, but post-verify failed because the claude adapter had already overwritten `latest.last` with an empty file.

**Root cause**: `latest.*` is shared mutable global state per working directory. Any actor that touches it races with every concurrent dispatch.

**Resolution (#216, 2026-06-02)**: Implemented point 2 (pmctl owns the output contract) — the simpler sufficient fix. `pmctl dispatch run` now tees adapter stdout to a temp file, parses the per-run `last:` / `stderr:` footer lines, and passes them to `dispatch-post-verify.sh` via `--last`/`--stderr` flags. Post-verify uses explicit per-run paths; `latest.*` symlinks remain as human-observation convenience only. Per-run isolated subdirectory (point 1) deferred — not needed once pmctl consumes the explicit footer. Regression tests added: stale `latest.last` avoidance + tee `PIPESTATUS` propagation. `docs/executor-contract.md` updated with footer handoff subsection.

Also shipped in same PR: `scripts/lib/pmctl-config.sh` shared config loader + `sw_append_dispatch_run` shared run-row builder (eliminating ~100 LOC of adapter duplication), `pmctl_validate_adapter_name` regex fix (`^[a-z][a-z0-9_-]*$`), 5 new test cases.

**Acceptance** (all met):
- Stale `latest.last` no longer causes post-verify false failure (CC-305 regression case passes).
- Footer exit code propagated correctly through tee pipeline.
- `scripts/run-all-tests.sh`: 40 passed, 0 failed.

**Cross-link**: `[[CC-289]]` (pmctl dispatch run), `[[CC-299]]` (unified dispatch routes), `[[CC-264]]` (dispatch-post-verify.sh), `[[CC-293]]` (config dedup).

## CC-299 — [arch] 統一 executor dispatch 路徑 ✅ 2026-06-01

**See**: pr:#213

## CC-309 — single-writer: route Run/Event writes through pmctl ✅ 2026-06-04

**See**: pr:#223

**Problem**: machine state is written outside `pmctl` — adapters call `sw_append_dispatch_run` directly (`adapters/codex/dispatch.sh:369`, claude equivalent), the append primitives `printf '%s\n'` caller strings without compaction/validation (`state-writer.sh:96-129`), failures are silent (`return 0`), and `test-layer-boundaries.sh:20-23,161-172` *allows* adapter state writes.

**Plan**: move Run/Event writes into `pmctl dispatch run`; guard deny/warn emit Events via `pmctl`; harden the writer boundary (reject newline/NUL, `jq -c` compact, schema-validate); make canonical write failures loud (non-zero/surfaced); invert the layer-boundary test to forbid adapter/hook state writes (extends [[CC-306]]). v0.4.0 foundation Phase 1.

**Detail**: `docs/architecture/v0.4.0-state-first-foundation.md` §3, §10.B. Related: [[CC-310]], [[CC-306]].

## CC-310 — transactional Run+Event write + Run FSM lifecycle ✅ 2026-06-04

**See**: pr:#228

**Problem**: `runs_append`/`events_append` lock different files with no shared operation id, idempotency key, or reconciliation API (`state-writer.sh:104-129`); Run is recorded only at terminal adapter exit, so the `pending→dispatched→verifying→ok/partial/failed` FSM (`core/policy/run-states.yaml:15-28`) is never realized and a crashed `pmctl` leaves no in-flight Run.

**Plan**: a `pmctl`-owned record-dispatch op that writes the Run/Event pair under one operation id with the invariant "every terminal Run has exactly one terminal Event" (checkable/repairable on read); `pmctl` creates `pending`/`dispatched` before invoke, `verifying` after, then the terminal state, emitting an Event per transition.

**Detail**: scoping doc §9 D4, §10.A2/A3. Related: [[CC-309]], [[CC-312]].

## CC-311 — state store VERSION gating + migration ✅ 2026-06-05

**See**: pr:#230

**Problem**: `state_store_init` writes `1` back to `$STORE/VERSION` whenever it is not `1` (`state-writer.sh:85-90`); an older binary touching a future v2 store silently downgrades it.

**Plan**: create `VERSION` only when absent; if present and unsupported, fail loud with a migration command/path; never rewrite it down.

**Detail**: scoping doc §10.A1.

## CC-312 — state schema tightening + per-event payload & FSM-transition validation ✅ 2026-06-05

**See**: pr:#230

**Problem**: `run.schema.json` requires only id/schema_version/task_id/executor/state/created_ts — `trace_path`/`working_dir`/`exit_code`/`finished_ts` are optional (`core/schema/run.schema.json:22-59`), and Event `payload` is entirely loose (`core/schema/event.schema.json:18-47`), so a reader cannot tell `ok` from `partial` or validate a `from→to` transition.

**Scope note**: `finished_ts` was descoped from this ticket — `sw_build_run_json` does not write it. Requiring it in the schema would break all existing Run rows. Deferred to a future schema ticket.

**Plan**: a stricter dispatch-run shape (require the trace fields) + per-`kind` Event payload contracts carrying `from_state`/`to_state`/`run_id` or `task_id`, validated against the run/task FSMs on write. (Enum parity is already tested in `test-core-schemas.sh:171-218`; this adds transition + payload validation.)

**Detail**: scoping doc §10.A4. Related: [[CC-310]].

## CC-313 — project partition identity: repo.json + worktree/aliases + no-global ✅ 2026-06-05

**See**: pr:#232

**Problem**: `repo.json` is promised by `core/state/layout.yaml:36-39` but never written (`state_store_init` only mkdirs + VERSION), and `_sw_project_key` falls back to `global` outside git or on hash failure (`state-writer.sh:45-67`) — mixing unrelated work and making worktree / WSL↔Windows path identity unreconcilable.

**Plan**: write `repo.json` on first use (git top-level, `git common-dir`, worktree path, normalized + cygpath aliases); refuse the `global` partition for load-bearing project writes unless explicitly requested.

**Detail**: scoping doc §10.A5. (sha1 portability itself was fixed — `_portable_sha1`; this is identity semantics.)

**Implemented**: `_sw_write_repo_json` writes `repo.json` on first use (write-temp-then-rename, best-effort) with `repo_path`, `repo_name`, `git_common_dir`, `first_seen_ts`, optional `cygpath_alias`. `state_store_init` refuses the `global` partition (stderr + return 1) unless `_SW_ALLOW_GLOBAL_PARTITION=1`. Combined with CC-330 (fail-loud mkdir) in pr:#232.

## CC-318 — dispatch-post-verify: execute self_verify bash lines directly ✅ 2026-06-04

**See**: pr:#227

**Problem**: `scripts/dispatch-post-verify.sh` validates `self_verify:` items by searching for them as literal substrings in the executor's `latest.last` output (`grep -F "$item"`). This is a format contract between post-verify and the executor: the executor must reproduce the exact `self_verify:` text in its response, otherwise items are all reported MISSING. Codex writes `"Verification passed: ..."` instead of quoting each item verbatim, causing all self_verify checks to fail even when the executor actually ran the commands correctly. Tracked by `[[feedback_self_verify_format]]`.

**Plan**: split self_verify into two kinds instead of searching `latest.last`. The structured `- cmd: "<bash>"` form is the **machine-executable** check — post-verify runs it via `bash -c` in `$WORK_DIR` under a timeout (PASS=exit 0, FAIL=non-zero/timeout). Every other shape (named macros, prose, bare scalars) is a **semantic check the executor evaluates** — post-verify marks it `SKIP (executor-evaluated)` and never fails it. This removes the executor-output-format dependency for the verifiable checks while staying honest that judgment checks (UI, accuracy) need executor/PM review, not a shell. (Round-1 attempt executed *every* item as bash; pr-gate flagged that it broke valid macro/structured briefs — hence the two-kind split.)

**Acceptance**:
- A `- cmd: "<bash>"` item PASSes iff the command exits 0 (with quote-stripping for single/double-quoted and unquoted values); the documented `cmd:`+`expect:` structured form executes the cmd value.
- A non-`cmd:` item (macro/prose/bare scalar) is reported `SKIP (executor-evaluated)` and does not fail the gate.
- A timeout (`DISPATCH_SELF_VERIFY_TIMEOUT`, default 300s) reports FAIL.
- Contract docs (`docs/executor-contract.md`, `docs/dispatch-brief.md`, `commands/pm.md`, `agents/{codex,claude}-executor.md`) describe the cmd:/SKIP split.
- `dispatch-post-verify.sh` test coverage for cmd PASS/FAIL, quote forms, structured `expect:`, macro/bare-scalar SKIP, all-skipped OK, cwd, timeout, multi-check.

**Depends on**: [[CC-309]] merged (establishes executor boundary; self_verify format is a dispatch-level concern).

**Status**: implemented. Canonical self_verify shape (decided after pr-gate round 1 flagged a contract mismatch): the structured `- cmd: "<bash>"` form is the **machine-executable** check — post-verify runs it in `$WORK_DIR` under `DISPATCH_SELF_VERIFY_TIMEOUT` (default 300s); PASS=exit 0, FAIL=non-zero/timeout. Every other shape (named macros, prose, bare scalars) is a **semantic check the executor evaluates** — post-verify marks it `SKIP (executor-evaluated)`, never failing valid judgment-only briefs (e.g. UI/accuracy checks a shell cannot confirm). Contract docs (`docs/executor-contract.md`, `docs/dispatch-brief.md`, `commands/pm.md`) aligned; `test-dispatch-post-verify.sh` rewritten to cmd-exec PASS/FAIL + SKIP coverage (44/0). Index tracks to confirm merge.

## CC-319 — fix: reviewer guard cross-project — derive allowed dir from file path ✅ 2026-06-04

**See**: pr:#224

**Problem**: `scripts/hook-reviewer-write-guard.sh` bound the allowed write path to `$_SCRIPT_DIR/..` (the pm-dispatch install location). Running `pr-gate` on any project other than pm-dispatch caused the guard to deny the reviewer's output write with `"target is not <repo>/.gate-results"`, blocking both sequential and parallel gate modes.

**Plan**: replace the install-path binding with a directory-name check: `basename(dirname(file)) == ".gate-results"`. Remove `CLAUDE_HOOK_GATE_REPO_ROOT` entirely — no env var required in the brief constraint. Update all tests to remove `CLAUDE_HOOK_GATE_REPO_ROOT` usage.

**Status**: shipped in pr:#224. Index tracks to confirm merge.

**Cross-link**: [[CC-320]], [[CC-321]].

## CC-320 — fix: codex adapter auto-export work_dir git root to read roots ✅ 2026-06-04

**See**: pr:#224

**Problem**: `hook-codex-bash-guard.sh` defaults `CLAUDE_HOOK_CODEX_READ_ROOTS` to `$HOME/github:/tmp`. Codex dispatched to a repo outside `~/github/` cannot read source files — the guard blocks the read attempt. The default path is a historical convention, not a project-agnostic setting.

**Plan**: `adapters/codex/dispatch.sh` derives the git root of `$WORK_DIR` and prepends it to `CLAUDE_HOOK_CODEX_READ_ROOTS` before invoking codex. Exported composition is `<git_root>:/tmp[:<inherited>]`. The `/tmp` segment is intentional: setting the env var REPLACES the guard's default (`$HOME/github:/tmp`), so `/tmp` must be re-added or codex loses scratch/brief access under `/tmp` — this is a correctness baseline, not a policy widening. Any existing user-set value is preserved as trailing fallback. Non-pmctl codex invocations continue to use the `$HOME/github:/tmp` default.

**Status**: shipped in pr:#224. Index tracks to confirm merge.

**Cross-link**: [[CC-319]], [[CC-321]].

## CC-328 — docs+fix: executor-agnostic `light` model alias + claude default model contract ✅ 2026-06-05

**See**: pr:#229

**Problem**: `light` 是為 codex 設計的輕量 model alias（`codex-spark`），但缺乏 claude 端的對應定義與文件；claude adapter 也沒有 dispatch-vs-inline routing guide。同時，claude adapter 在 omit `--model` 時不走 alias table 而委給 claude CLI built-in default，與 codex adapter 行為不一致，形成文件與實際行為的合約落差。

**Resolution**:
1. 新增 `docs/model-tier-policy.md` — 文件化 `light` 為跨 executor 統一 alias：
   - codex → `gpt-5.3-codex-spark`（independent usage pool）
   - claude → `claude-haiku-4-5-20251001`
   - 附 routing 準則：`< 50 lines, ≤ 2 files, no new behavioral units`
2. `docs/dispatch-brief.md` 加入 dispatch-vs-inline routing guide
3. `share/claude-model-aliases.tsv` 補齊 alias 定義；`scripts/lint-model-aliases.sh` 擴充 claude 端 drift 偵測
4. `scripts/test-claude-dispatch.sh` 加入完整 alias coverage（light / default / haiku / sonnet / opus / unknown passthrough / malformed TSV / resolver-absent）及 lint failure cases
5. **修正 default model contract**：`adapters/claude/dispatch.sh` 加 `DEFAULT_DISPATCH_MODEL="default"` + 路由邏輯對齊 codex adapter，omit `--model` 現在一律走 alias table → `claude-sonnet-4-6`，不委給 CLI built-in；補 test `case_model_no_flag_resolves_default`

**PR-Gate**: full tier GO（advisory 於最終 commit 37ce2f6 修清；qa / security / risk 全 pass）

**Cross-link**: [[CC-293]]（config/default 解析），[[CC-321]]（PM_HOOK_* 重命名同脈絡）.

## CC-329 — arch: FSM transition table — extract to runtime-accessible policy helper ✅ 2026-06-05

**See**: pr:#232

**Status**: ✅ closed 2026-06-05

**Source**: CC-311/312 PR #230 gate advisory — critic + architecture-reviewer（medium）

**Implemented**: Added `run_transition_valid(from_state, to_state)` to `state-writer.sh` as the canonical policy source. `pmctl_dispatch_write_transition` now calls `run_transition_valid` instead of maintaining an inline transition table. `pmctl_dispatch_ensure_state_writer` is called at the top of `pmctl_dispatch_write_transition` to ensure the helper is loaded before use.

**Cross-link**: [[CC-311]], [[CC-312]], [[CC-313]], [[CC-330]].

## CC-330 — fix: state_store_init — propagate layout mkdir failure loud ✅ 2026-06-05

**See**: pr:#232

**Status**: ✅ closed 2026-06-05

**Source**: CC-311/312 PR #230 gate advisory — critic + architecture-reviewer（low）

**Problem**: `state_store_init` 在 VERSION check 通過後建立 project layout（`mkdir -p tasks/ reviews/ …`）仍用 `2>/dev/null || true` 靜默吞掉失敗。這與 VERSION 不支援時的 fail-loud 語意不一致：`state_store_init` 在 VERSION=1 但 `proj_dir` 目錄建立失敗時仍回 0，而後續的 `runs_append`/`events_append` 會因目錄不存在而失敗，且 error 難以追溯至 `state_store_init`。

**Plan**: 把 layout `mkdir -p` 的失敗從 `|| true` 改為 fail loud（stderr + return 1），與 VERSION 驗證 branch 的失敗語意對齊。

**Cross-link**: [[CC-311]], [[CC-312]].

---

## CC-331 — perf/ci: test-install CI 並行化 + jq batch + stub-based verify 架構 ✅ 2026-06-05

**See**: pr:#231

**Source**: PR #230 合入後 CI test-install 需花 ~4 min，用戶 2026-06-05 要求優化。

**Problem**: CI test-install 單一 sequential job 慢（~4 min），原因三：(1) 73 tests 全部串行；(2) `install_dispatch_allowlist` 每個 allowlist entry 跑 2 次 jq（check + write），6 entries × 42 invocations = 504 jq processes；(3) `test_verify_flag_runs_preflights` 以 `CLAUDE_CONFIG_TEST_INSTALL_RUNNING=1` escape hatch bypass 真實斷言（CI 從未真正驗證委派行為）。

**Solution**:

1. **CI 並行化**（`.github/workflows/lint.yml`）：`test-install.sh` 加 `--group <core|hooks>`，CI 拆成 `test-install-core`（34 tests）+ `test-install-hooks`（39 tests）並行；移除無用的 `git fetch --depth=1 origin main`。

2. **jq call batch**（`install.sh: install_dispatch_allowlist`）：一次讀取全部已有 entries（1 jq read），再計算 missing entries，最後一次寫入（1 conditional jq write）。

3. **Stub-based verify 架構**（`install.sh` + `scripts/test-install.sh`）：`install.sh --verify` 加 `_PM_DISPATCH_PREFLIGHT_RUNNER` 注入接縫（`bash "${_PM_DISPATCH_PREFLIGHT_RUNNER:-$REPO_ROOT/scripts/run-all-tests.sh}"`）；`test_verify_flag_runs_preflights` 改為動態從 `run-all-tests.sh --list` 產生 stub，注入後呼叫 `install.sh --verify --dry-run`；同時顯式設 `CLAUDE_CONFIG_TEST_INSTALL_RUNNING=0` 防 run-all-tests.sh 帶入的 env 觸發 install.sh 自身 escape hatch；CI 移除 `CLAUDE_CONFIG_TEST_INSTALL_RUNNING=1`。Suite 清單自動同步，無需手動維護。

**Files**: `install.sh`, `scripts/test-install.sh`, `.github/workflows/lint.yml`
## CC-027b — `tool-trace.jsonl` health signal 🚫 2026-06-07

**↪ 此票已合併入 CC-044。** 實作見 CC-044 Phase 2 — bounded error counter + downstream warning。以下原始需求保留供參考。
**See**: CC-044 (merged primary — tool-trace reliability bundle)

**Problem**: Trace collection failures are currently best-effort and audit-only. If append, parse, or rotation problems persist, downstream CC-025/CC-026 workflows may read incomplete `tool-trace.jsonl` data without a visible warning.
**Why**: The hook must stay non-blocking, but silent long-term degradation makes later skill-refine / skill-distill signals unreliable. A bounded local error counter can preserve non-blocking behavior while surfacing sustained failure to downstream commands.
**Requirement**: Add a bounded error counter for `tool-trace.jsonl` health and have downstream commands surface a warning when the error count exceeds N. Keep hook execution non-blocking and cap any health-state file growth.
**Source**: `2026-05-15 CC-027 PR-gate risk-reviewer finding`.

## CC-027c — `hook-tool-trace.sh` strict JSON validation 🚫 2026-06-07

**↪ 此票已合併入 CC-044。** 實作見 CC-044 Phase 3 — async post-validation strategy。以下原始需求保留供參考。
**See**: CC-044 (merged primary — tool-trace reliability bundle)

**Problem**: Brace-shaped malformed JSON (e.g. `{"cwd":"/x","tool_name":"Bash","tool_input":{` truncated mid-object) can pass the bash brace heuristic and produce a garbage line in `tool-trace.jsonl`. Identified by critic + qa-tester in CC-027 PR-gate.
**Why**: Strict validation via inline `jq -e .` costs ~25ms/call subprocess startup on this host — alone exceeds the entire per-call budget (8.2ms baseline). Inline strict mode is structurally incompatible with the hook performance contract.
**Requirement**: Explore async post-validation path: append first (non-blocking), validate sampled fraction asynchronously, or move strict validation to the downstream consumer (CC-025/026) where 25ms/call is amortized over rare reads instead of every tool invocation.
**Note**: Garbage line is data-quality concern only — no security/risk vector (the garbage doesn't leak content, doesn't crash, downstream consumers can skip malformed lines defensively).
**Source**: `2026-05-15 CC-027 PR-gate critic + qa-tester findings`.

## CC-213 — `install_dir_junction()` Windows-aware idempotency probe 🚫 2026-06-07

**↪ 此票已合併入 CC-212。** 實作見 CC-212 Requirement (B) — manifest-driven idempotency probe。以下原始需求保留供參考。
**See**: CC-212 (merged primary — Windows junction install hardening bundle)

**Problem**: The idempotent reinstall path checks `[[ -L "$dest_dir" ]]` + `readlink` to detect
an already-installed junction, but PowerShell-created Windows directory junctions may not appear
as `-L` in Git Bash (reparse points vs. Unix symlinks). A second `bash install.sh` run could
therefore treat the junction directory as a real directory, fall back to per-file copy, and
flush a manifest without the `junction` mode entry.

**Why**: Windows real-device verification confirmed idempotency passes in practice (PR #112), but
the `-L` assumption was flagged as insufficiently proven by critic + qa-tester in gate-20260521-115634
as [medium]. The QA block was overridden with Windows dogfood evidence; this ticket captures the
remaining automation gap.

**Requirement**: Add a manifest-driven idempotency probe: before the `-L` check, read the
existing manifest for the entry's `mode` field; if `mode == "junction"` treat the destination as
an existing junction regardless of whether Bash `-L` fires. Add a focused test that exercises
the "manifest says junction, `-L` is false" branch.

**Complements**: CC-207 (parent), CC-212 (path-passing — merged primary).

**Priority**: P3.

## CC-226 — lint-frontmatter: extract shared dq-escape validation helper 🚫 2026-06-07

**↪ 此票已合併入 CC-227。** shared helpers（dq-escape / adjacent-quote / empty-entry）直接住進 `scripts/lib/yaml-frontmatter.sh`，不需單獨 PR。以下原始需求保留供參考。
**See**: CC-227 (merged primary — yaml-frontmatter lib extraction bundle)

**Problem**: `scripts/lint-frontmatter.sh` repeats the same double-quoted escape whitelist regex and adjacent-quoted-scalar check across 4 separate collection branches (key-level flow seq, key-level flow mapping, list-item flow seq, list-item flow mapping). A future grammar fix applied to one branch can be missed in the others, causing a silent parity gap.

**Why**: Raised as medium advisory by critic + architecture-reviewer in gate-20260522-171123 (CC-058 gating). The current branch coverage is green and covers all 4 paths, so the risk is low now, but will grow as the grammar is extended.

**Requirement**: Extract the dq escape whitelist check, the adjacent-quoted-scalar check, and the empty-entry check into a shared bash helper or predicate function. Ensure a parity test (or single call site) prevents future per-branch divergence.

**Dependencies**: CC-058 (lint-frontmatter rewrite — merged)

**Priority**: P3 — maintainability; not blocking current workflows.

**Cross-link**: CC-224 (hook-profile inventory duplication — same class of debt), CC-227 (module extraction — merged primary)

## CC-268 — docs: run_in_background default async escalation undocumented 🚫 2026-06-07

**↪ 此票已合併入 CC-272。** 實作見 CC-272 — executor contract docs bundle Part (B)。以下原始需求保留供參考。
**See**: CC-272 (merged primary — executor contract docs bundle)

**Problem**: Agent tool called without `run_in_background:true` may silently promote the subagent to async mode and return `Async agent launched successfully` instead of blocking. Observed with `codex-executor` (ran ~3m45s async without the flag). Docs say "Claude decides" but give no criteria; callers cannot reliably predict whether the dispatch blocks the main thread.

**Priority**: P3 — docs clarity only; no functional impact on existing flows.

**Proposed fix**: Document in `commands/pm.md` or `docs/executor-contract.md` which subagent types always run async, and whether/when the default blocks.

**See**: issue:#166

## CC-269 — ops: hook-save-rate-limits.sh 應寫到 pm-dispatch 自己的 state 路徑 🚫 2026-06-07

**↪ 此票已合併入 CC-018。** 實作見 CC-018 Requirement 步驟 4-5 — rate-limit 路徑統一至 `~/.local/share/pm-dispatch/state/rate-limits.json`。以下原始需求保留供參考。
**See**: CC-018 (merged primary — rate-limit unification + Codex quota tracking)

**Problem**: `scripts/hook-save-rate-limits.sh` 寫到 `~/.claude/rate-limits.json`，與 claude-account-switcher 及其他工具共用同一檔名，多工具安裝時造成互相覆蓋。

**Why**: pm-dispatch 和 claude-account-switcher 是獨立工具，各自的 rate-limit 資料應存於各自的 state 目錄，不應依賴共用檔名作為「約定」。

**Requirement**:
- `scripts/hook-save-rate-limits.sh` 改寫到 `~/.local/share/pm-dispatch/state/rate-limits.json`（對齊 CC-230 state store 目錄）
- 更新所有讀取此路徑的腳本（doctor.sh、usage 相關腳本等）
- install.sh / uninstall.sh 同步更新 manifest（若有對應條目）
- 設計上：`~/.claude/rate-limits.json` 屬於 Claude Code / claude-account-switcher，pm-dispatch 不寫該路徑

**Context**: 2026-05-28 發現 — statusline-chain.conf 中 pm-dispatch hook 與 claude-account-switcher hook 同時寫到相同檔案。暫時從 chain 移除 pm-dispatch hook 以解除衝突；此票為正式修復。

**Dependencies**: CC-230（state store 目錄已建立）

**Priority**: P3 — 現有 workaround（從 chain 移除）可用；不阻斷其他工作。

## CC-314 — routing_log.md → events.jsonl migration + deprecate machine-write

**Problem**: deprecating the `routing_log.md` machine-write needs a real migration: the hook writes `kind` `bash-dispatch`/`agent-dispatch` (`hook-routing-log.sh:322-325`) which are **not** in the core Event enum (`event.schema.json:18-30`), and the existing `migrate-routing-log.sh` only migrates the old markdown shape.

**Plan**: build a `routing_log → events.jsonl` migration with explicit kind mapping (→ `run.dispatched` etc.) + a subject-id strategy; stop the hook's markdown machine-write; keep `migrate-routing-log.sh` as legacy-markdown cleanup only.

**Detail**: scoping doc §10.A6, §4 (D3 = deprecate).

**Outcome**: 2026-06-05 — shipped in pr:#234. `hook-routing-log.sh` deprecated (early-exit), `migrate-routing-to-events.sh` added with deterministic IDs and idempotency, `ROUTE_LOG_ENABLED=0` in `install-hooks.sh`.

**See**: pr:#234

## CC-315 — state read/query contract + pmctl trace

**Problem**: `state-writer.sh` is write-only and `cli/pmctl` has no read/query/trace subcommand (`cli/pmctl:35-78`); consumers would read state by ad-hoc JSONL grep, and a single-writer with no read contract is half a substrate.

**Plan**: `pmctl` owns read ops over state — by id / `task_id` / event `kind` / time-window — with `pmctl --json` output; define active+archive read semantics (ordering, corrupt-row tolerance, time-window, indexed vs streamed). `pmctl trace` is the first consumer.

**Detail**: scoping doc §3.7, §3.6, §10.B (D6). Related: [[CC-316]].

**Outcome**: 2026-06-06 — shipped in pr:#237. `scripts/lib/pmctl-trace.sh` adds `pmctl trace tail` over `events.jsonl` + `archive/events-*.jsonl.gz` (partition via the writer's `_sw_project_dir`); filters by id/kind/subject/time-window, merges active+archive chronologically (append order preserved on equal `ts`), skips malformed rows with a counted warning, streamed linear scan (indexing deferred). 12-case suite `test-pmctl-trace.sh`. Read-only — no writer/schema/layout touched.

**See**: pr:#237

## CC-316 — state store rotation implementation

**Problem**: `core/state/layout.yaml:46-63` specifies gz rotation (`archive/{runs,events}-$YYYYMM.jsonl.gz`) but no code implements it (`state_store_init` only mkdirs `archive/`), so `runs.jsonl`/`events.jsonl` grow unbounded; and the monthly path collides on >1 rotation/month.

**Plan**: implement rotation per layout with a monotonic segment suffix (`*-$YYYYMM-NNNN.jsonl.gz`); the reader (CC-315) merges active + archived segments.

**Detail**: scoping doc §3.8, §10.B (D7). Related: [[CC-315]].

**Outcome**: 2026-06-06 — shipped in pr:#238. Rotation in `scripts/lib/state-writer.sh` under the per-entity append lock: byte threshold (50 MB, `PM_DISPATCH_ROTATE_MAX_BYTES` override; 90-day trigger deferred), monotonic `archive/<entity>-$YYYYMM-$NNNN.jsonl.gz` segments, **destination-named `.staging`** for genuinely idempotent crash recovery (no duplicate rows in the publish→cleanup window), best-effort + loud (never fails the canonical append; degradation on stderr + `state-writer.err`). 13-case suite `test-state-store-rotation.sh`. layout/writer golden-parity test left to [[CC-317]].

**See**: pr:#238

## CC-317 — state store safety & robustness hardening

**Problem**: `_sw_store_root` trusts `PM_DISPATCH_STATE_ROOT`/`XDG_DATA_HOME` directly with plain `mkdir -p` (`state-writer.sh:32-90`) — no canonicalization, symlink-component rejection, world-writable check, or `0700` mode; `serialize_with_lock`'s mkdir fallback has no stale-owner protocol (`portable.sh:174-180`) — a killed writer on a flock-less FS blocks until timeout; and `layout.yaml` is "definitions only" while writer paths are hardcoded (drift-prone).

**Plan**: canonicalize + permission-check the store root (reject unsafe symlink/world-writable; `0700`); mkdir lock carries pid/host/start-time + cleanup trap + bounded stale reclaim + a UNC/9P preflight warning; make `layout.yaml` an executable source of truth (writer/reader consume it, or golden tests compare paths/locks/subdirs).

**Detail**: scoping doc §10.B.

**Outcome**: 2026-06-06 — shipped in pr:#239, completing the v0.4.0 state-first foundation. (A) `state_store_init` runs a store-root safety gate — non-mutating symlink-leaf + ownership checks reject before any mkdir/chmod, then `0700` + either-bit group/world-writable rejection; VERSION gate runs before the mutating repair; `PM_DISPATCH_ALLOW_UNSAFE_STATE_ROOT=1` escape hatch. (B) `mkdir_lock` carries pid/host/epoch owner metadata, reclaims only clearly-stale owners (same-host dead-PID never on age; remote by age ceiling) with ABA guard + bounded retries; `mkdir_unlock` documents release; subshell `EXIT` trap for kill-safety; non-fatal UNC/9P warning. (C) `scripts/test-state-layout-parity.sh` golden test binds layout.yaml ↔ writer. Suites: portable 41, state-store 63, layout-parity 3.

**See**: pr:#239

## CC-322 — docs: review-model.md — Relocating Rigor 哲學文件

**Problem**: pm-dispatch 已有 cross-context isolated reviewers（pr-gate sub-agents）、machine verification（`self_verify cmd:`）、上游 spec review（`/pre-impl`），但沒有文件把這些機制命名成一套完整的 Review Model，讓新接觸的維護者看不出設計意圖。

**Why**: 「Relocating Rigor」—— 嚴謹從中間逐行 review 搬到兩頭（上游 intention / 下游 verification）—— 是 pm-dispatch workflow 的核心哲學，值得正式成文。文件也是後續 CC-323–CC-327 實作的理念錨點。

**Requirement**:
1. 新增 `docs/review-model.md`，定義四層：
   - Layer 1（上游）：Intention & Spec review，在 agent 動手前確認方向
   - Layer 2（中層）：Cross-Context Isolation，reviewer 用乾淨 session 讀最終產物
   - Layer 3（下游）：Conceptual Map review，看架構不看每行 code
   - Layer 4（驗收）：Machine Verification，`self_verify cmd:` 強制執行
2. 說明 pm-dispatch 哪些現有機制對應哪一層
3. 說明逐行 code review 降級為 exception（agent 卡住 / 方向明確錯才人工介入）
4. 新增 cross-link：`docs/CONCEPTS.md`、`docs/dispatch-brief.md`、`docs/pr-gate-handover-schema.md`

**Non-goals**: 不改任何 script / skill / agent。

**Outcome**: 2026-06-05 — shipped in pr:#236. `docs/review-model.md` 落地（四層 Review Model + 逐行 review 降級為 exception + cross-links）；CHANGELOG [Unreleased] Added 記錄；Layer 1/Layer 3 的 planned 行為以 `> **Planned** (CC-323/CC-326)` blockquote 標示，與 backlog active 狀態對齊。

**See**: pr:#236

**Cross-link**: [[CC-323]], [[CC-324]], [[CC-326]], [[CC-327]].

---

## CC-323 — skill: 強化 /pre-impl 輸出 contract — Intention + Conceptual Map 必填

**Problem**: `/pre-impl` 目前是輔助命令，輸出格式鬆散；`/pm` 不會自動要求先跑。架構影響型任務缺乏強制的上游 intention / boundary review 關卡，導致 agent 實作方向可能在沒有人明確點頭的情況下就開始。

**Why**: 文章「Relocating Rigor」最核心的一點：在 agent 動手前，先把架構原型在腦袋裡（或文件裡）看過一遍再放它去做。這比事後逐行修正便宜得多。

**Requirement**:
1. 更新 `commands/pre-impl.md`，定義固定輸出 sections：
   - `## Intention` — 這次真正解決什麼問題
   - `## Non-goals` — 明確不做什麼
   - `## Bounded Context` — 可碰 / 不可碰的 module / script / command
   - `## Conceptual Map` — 純文字流程圖或結構圖（必填）
   - `## Acceptance Metrics` — 可驗收條件（非「works as expected」）
   - `## Verification Plan` — machine-check vs. semantic-check 分類
2. `agents/project-pm.md` 路由規則新增：`behavioral_units ≥ 3` 或 `architecture_impact ≠ none` → 自動要求先跑 `/pre-impl`，PM approve 後才進 dispatch brief
3. 輸出格式可直接銜接 dispatch brief schema（CC-324 的 `conceptual_map` 欄位）

**Acceptance**:
- `/pre-impl "<task>"` 輸出包含上述六個 sections
- PM 收到 architecture 影響任務時，在 brief 前先呼叫 `/pre-impl` 並等待確認

**Dependencies**: [[CC-322]]（文件錨點）；銜接 [[CC-324]]（brief schema）。

**Outcome**: 2026-06-07 — shipped in pr:#241. `commands/pre-impl.md` 升級為六個固定 sections（Intention / Non-goals / Bounded Context / Conceptual Map / Acceptance Metrics / Verification Plan）；Step 4 保留 design constraint list 可直接 paste 進 brief；`agents/project-pm.md` routing rule 擴大觸發條件（加 `architecture_impact ≠ none`）；docs/review-model.md Layer 1 移除 Planned blockquote。

**See**: pr:#241

---

## CC-324 — schema: dispatch brief 新增 conceptual_map + architecture_impact 欄位

**Problem**: dispatch brief schema 目前沒有方式表達「這次改動的架構影響程度」或「架構概念圖」，導致 architecture-reviewer 只能掃 source diff，而非先看概念圖。

**Why**: 讓 brief 攜帶 `architecture_impact` 與 `conceptual_map`，架構影響輕重就有明確的機器可讀欄位，後續 brief-validate（CC-325）與 tier 自動建議（CC-327）才有資料來源。

**Requirement**:
1. `docs/dispatch-brief.md` 加入新欄位說明：
   ```yaml
   architecture_impact: none | minor | major
   conceptual_map: |
     [純文字圖，architecture_impact != none 時必填]
   ```
2. `scripts/brief-validate.sh` 對新欄位做結構驗證（`architecture_impact` 必須是合法 enum 值）
3. `docs/dispatch-brief.md` 說明 `conceptual_map` 優先給 `architecture-reviewer` 用，非強制掃 source diff 的替代品

**Acceptance**:
- `brief-validate.sh` 對合法 `architecture_impact` 值 PASS、非法值 FAIL
- 文件有範例 brief 含 `conceptual_map`

**Dependencies**: [[CC-323]]（pre-impl 產出可填入此欄位）；銜接 [[CC-325]], [[CC-326]], [[CC-327]].

**Outcome**: 2026-06-07 — shipped in pr:#241. `docs/dispatch-brief.md` 加入 `architecture_impact`（`none|minor|major`）與 `conceptual_map` optional 欄位說明；含範例 YAML；`scripts/brief-validate.sh` 加入 enum 驗證函式與 `has_conceptual_map`。

**See**: pr:#241

---

## CC-325 — infra: brief-validate 強化 — Acceptance Metrics + conceptual_map 品質機器檢查

**Problem**: `brief-validate.sh` 目前只做結構檢查（欄位存在性、enum 合法性），不檢查「品質」。Acceptance Metrics 可以是空泛語（"works as expected"）、file-writing task 可以沒有任何 machine-checkable self_verify，這兩種情況都會讓 agent 有模糊空間偷懶或幻覺。

**Why**: 文章「Relocating Rigor」：Acceptance Metrics 一定要先寫清楚，指標含糊就會用最省力的方式交差。機器檢查可以把這條規則變成強制 policy，不靠人工審查。

**Requirement**:
- `brief-validate.sh` 新增品質規則：

| 條件 | 行為 |
|---|---|
| `acceptance` 含 "works as expected" / "passes tests" / "no errors" 等空泛語 | FAIL + 提示重寫 |
| file-writing task 無任何 `- cmd:"…"` self_verify | FAIL |
| `behavioral_units ≥ 3` 無 `qa_checklist` | WARN |
| `architecture_impact: major` 無 `conceptual_map` | FAIL |
| sensitive path + sequential pr-gate | WARN → 建議 `--parallel` |

- 加入對應測試 cases

**Non-goals**: 不改 brief 執行流程，只在驗證層加規則。

**Dependencies**: [[CC-324]]（`architecture_impact` 欄位需先定義）；[[CC-323]]（acceptance metrics 格式由 pre-impl contract 奠定）.

**Outcome**: 2026-06-07 — shipped in pr:#241. `scripts/brief-validate.sh` 加入品質規則：acceptance 含空泛語 → WARN；file-writing 無 `cmd:` self_verify → FAIL；`architecture_impact:major` 無 `conceptual_map` → FAIL；`behavioral_units ≥ 3` 無 `qa_checklist` → WARN；`scripts/test-brief-validate.sh` 加入 10 個新 test cases（32/32 pass）。

**See**: pr:#241

---

## CC-326 — agent: 更新 architecture-reviewer prompt — Conceptual Map 優先於 source diff

**Problem**: `agents/architecture-reviewer.md` 目前直接讀 source diff / file list，沒有指示「先看 conceptual_map」。即使 brief 有 conceptual_map，reviewer 也不保證會用它。

**Why**: 文章「Relocating Rigor」：「Architect / Editor，不是逐行 inspector」—— reviewer 看的是整個架構對不對，不是某行寫得漂不漂亮。只有在 conceptual_map 與 diff 不一致、或 risk surface 需要抽查時，才需要進入 source files。

**Requirement**:
1. `agents/architecture-reviewer.md` 在 review 指示開頭加入：
   - 若 brief 有 `conceptual_map`：優先讀 map，確認 bounded context / layer boundary，只在 map 與 diff 不一致或 risk surface 需抽查時才看 source files
   - 若 brief 無 `conceptual_map`：維持現行 source diff review，但在 finding 中 note「建議提供 conceptual_map」
2. 改動僅限 `agents/architecture-reviewer.md`，不影響其他 reviewer

**Acceptance**:
- `architecture-reviewer` prompt 包含 conceptual_map 優先讀取指示

**Cross-link**: [[CC-322]], [[CC-324]].

**Outcome**: 2026-06-07 — shipped in pr:#241. `agents/architecture-reviewer.md` Process 段落改為 conceptual_map-first（有 map 時先讀 map，source diff selectively）；無 map fallback 維持 diff review 並 note 缺失；docs/review-model.md Layer 3 移除 Planned blockquote。

**See**: pr:#241

---

## CC-327 — pr-gate: tier 定義改為 rigor level（而非 reviewer 數量）

**Problem**: `express / standard / full` 三個 tier 目前的語意是「reviewer 數量多寡」，沒有對應到「review 嚴謹程度」的概念，也沒有與 brief 的 `architecture_impact` 掛鉤。

**Why**: 文章「Relocating Rigor」：tier 應該反映「需要多嚴謹的 review」而不只是「幾個 reviewer」。與 brief 的 `architecture_impact` 掛鉤後，tier 選擇可以自動建議，減少人工判斷。

**Requirement**:
1. 更新 `scripts/pr-gate.sh` + 相關文件，重新定義 tier 語意：
   - `express`：hotfix / docs-only / `architecture_impact: none` → machine verification + combined session reviewer
   - `standard`：一般 feature / `architecture_impact: minor` → conceptual map 必要 + critic + qa + architecture
   - `full`：架構變動 / `architecture_impact: major` / sensitive path → parallel cross-context + security + risk hard gates + synthesis
2. `scripts/pr-gate.sh` 加入 tier 自動建議邏輯：若 brief 有 `architecture_impact`，啟動前 emit 建議 tier（user 仍可 override）
3. 更新 `docs/review-model.md`（CC-322）tier 說明段落

**Acceptance**:
- 文件中三個 tier 的語意對應到 rigor level，不只是 reviewer 數量
- 帶 `architecture_impact: major` 的 brief → gate 建議 `full` tier（emit warning，不強制）

**Cross-link**: [[CC-322]], [[CC-324]], [[CC-323]].

**Outcome**: 2026-06-07 — shipped in pr:#241. `scripts/pr-gate.sh` 加入 `--brief <file>` 選項與 tier advisory 邏輯（`architecture_impact:major` → suggest full；`minor` + express detected → suggest standard；advisory only，不強制）；`docs/review-model.md` 加入「pr-gate rigor tiers」章節；`skills/pr-gate-review/SKILL.md` tier 說明改為 rigor level 語意；移除 review-model.md 中的舊式 Planned blockquotes。

**See**: pr:#241

---

## CC-332 — docs/process: PM size-first dispatch routing policy

**Problem**: PM dispatch 的 model / route 選擇沒有以「任務大小」為一級判準，`docs/model-tier-policy.md` 與 `agents/project-pm.md` 對 Tiny / Small 任務的路由各說各話，存在 source-of-truth drift。

**Plan**: 將 §Implementation tasks 改寫為 size-first 路由表 — Tiny → 主線程 inline（不派發、不寫 brief）；Small → `model: light`（codex-spark / haiku）；Medium/Large → Codex `default`。同步更新 `agents/project-pm.md` 的 Dispatch model selection，使 PM 對 Tiny 給 inline 建議、對 Small 寫 `model: light` brief，並澄清 main-thread 與 PM routing 角色。

**Detail**: 純文件 / process change；不改腳本。

**Outcome**: 2026-06-05 — shipped in pr:#236. `docs/model-tier-policy.md` 與 `agents/project-pm.md` 路由表對齊，CHANGELOG [Unreleased] Added 記錄。

**See**: pr:#236

---
## CC-368 — Windows portability remediation bundle ✅ 2026-06-13

**See**: pr:#273

Six MSYS/Git-Bash-on-NTFS false-failures + one real bug, fixed in one PR without changing POSIX behavior: CRLF strip in `_yaml_get`; 0700 assert → capability-probe SKIP-with-reason; partition `_portable_canonical_path` (POSIX no-op); symlink-rejection `[[ -L ]]` SKIP; `--auto-pack` work-dir canonicalization; native-jq `--arg` MSYS path-conversion guard + stdin input. POSIX partition keys unchanged. Native Windows then **deferred** during core dev → [[CC-370]].

## CC-234 — memory v2: episodes + anomaly-event distillation（write-half of the memory loop；scope trimmed 2026-06-10）✅ 2026-06-11

**See**: pr:#265

**Problem**: The memory system is chat-derived — `episodes.jsonl` summarizes conversations. The durable *action* signal lives in `events.jsonl`, but inspection of the live stream (2026-06-10 arch review) shows it is run-FSM **lifecycle telemetry** (run.created → dispatched → verifying → completed, adapter + exit codes) — happy-path events carry almost no distillable semantics. A generic "distill all events" pass would be technically working machinery with nothing worth distilling.

**Why**: Memori's insight — memory from what agents *do* — holds where the action stream actually encodes knowledge: **anomalies**. A failed dispatch, a timeout, a gate block each encode a lesson ("briefs shaped like X hang codex") that chat summaries may under-report. This is the **write side** of the v0.5.0 memory read+write loop: semantic transformation lives here in `/mem-distill`, NOT in the read-side index (CC-354 stays an anchored TOC). Scope trimmed 2026-06-10: episodes remain the primary semantic source; events contribute only their anomaly slice; the generic event-tier schema is dropped from this slice (revisit with CC-340 if a richer action stream ever materialises).

**Requirement**:
- Point `/mem-distill` at `episodes.jsonl` (primary semantic source, unchanged) plus the **anomaly slice** of `events.jsonl` only: run failures / timeouts (`exit_code != 0`, timeout kinds) and gate blocks (blocked review verdicts). Happy-path lifecycle events are explicitly out of scope.
- Correlate an anomaly event with its episode (same session / run id) so the proposed card cites both: the episode line for the narrative, the event id for the machine evidence.
- The existing four-tier card system is unchanged; no new card tier, no separate memory engine, no generic event-tier schema.
- State store may be uninitialised → graceful fallback to episodes-only distillation (current behavior preserved).

**Acceptance**:
- `/mem-distill` run against a session containing **one real recorded failure** (e.g. a dispatch exit≠0 or gate block) proposes a card capturing the action-derived lesson, citing the source episode line AND event id; written only after user confirmation.
- A session with only happy-path lifecycle events proposes **no** event-derived card (no noise from telemetry).
- The card surfaces via the existing MEMORY.md auto-injection path (memory cards are NOT indexed into pmctl in v0.5.0 — see CC-354 scope boundary).
- Loop-level success metric (shared with CC-354): on a later similar task, the PM cites the card / anchors directly in the brief instead of re-deriving the background.

**Milestone**: v0.5.0 Phase 2 (memory read+write, write half).

**Priority**: P2.

**Cross-link**: [[CC-354]] (read side — anchored knowledge index), [[CC-356]] (repo-plane wiring, same wiring-as-acceptance principle), CC-230 (events.jsonl), CC-229 (event schema), [[CC-340]] (deferred home of any future generic event-tier schema), `commands/mem-distill.md` (modification target).

## CC-235 — Task lifecycle gate: tiered spec→design→plan ✅ 2026-06-11

**Problem**: The spec→design→plan discipline (`/pre-impl`, the `qa_checklist` rule) is advisory prose in `agents/project-pm.md` — not enforced. But a single uniform gate would over-burden trivial tasks — a typo fix should not need a design artifact.

**Why**: Enforcement should be **graded by task size**, consistent with pm-dispatch's existing tiered patterns: the pr-gate express/standard/full tiers and the sonnet-default / Opus-escalation model-tier policy. The gate's weight scales with the task.

**Shipped (warning mode)**: `pmctl task dispatch` checks `size_tier` / `behavioral_units` on the task JSON at claimed→in-progress. If tier is `substantial`: warn to stderr + emit `task.lifecycle.warn` event (best-effort telemetry; non-blocking). trivial/small/unknown: silent. New task fields: `behavioral_units` (int ≥ 0), `size_tier` (trivial/small/substantial). New event kind: `task.lifecycle.warn`. Hard-fail mode deferred to v0.6.0 when sufficient real-world usage data is available. 14 new tests, 63/63 pass.

**Cross-link**: CC-229 (Task schema/lifecycle), CC-022 (`/pre-impl`).

**See**: pr:#266

## CC-237 — context-enricher interface: context_hit_v1 + pmctl context pack ✅ 2026-06-09

**Problem**: The `context-pack` abstraction (CC-232) shipped a schema (#157) but has no concrete producer. v0.5.0 makes it the single interface that fuses the repo index (CC-338), memory search, and git into one dispatch-time context-pack.

**Why**: knowledge and repo are two different search planes with opposite lifecycles (curated/durable vs derived/rebuildable). They must be indexed separately but emitted through one interface so consumers (`/pm`, `/discover`, reuse-scan, `/mem-search`) read one shape. This is the spine of v0.5.0; it is also the comparison baseline for the codegraph spike (CC-209).

**Requirement** (shipped 2026-06-09):
- Extended CC-232 context-pack schema with `context_hit_v1` optional fields: `source_domain` (enum: knowledge / repo / state), `why_relevant` (string), `trust_level` (enum: high / medium / low), `refs` (string array). `schema_version` changed from `const:2` to `enum:[1,2]` for backward compat.
- `pmctl context index / update / query` (builtin-index backend). Pack assembler (`pmctl context pack`) is CC-239.
- FTS5 is optional; a `LIKE` / `grep` fallback is mandatory and tested (Windows Git Bash sqlite3 may lack FTS5).

**Milestone**: v0.5.0 Phase 1 (P1 spine).

**Priority**: P1.

**Cross-link**: [[CC-232]] (schema), [[CC-338]] (repo-index backend), [[CC-239]] (consumer), [[CC-209]] (codegraph spike).

**See**: pr:#254

## CC-239 — reuse-scan capability ✅ 2026-06-10

**Problem**: pm-dispatch carries recurring reuse debt — CC-200..204 are all "the same logic duplicated across scripts / hooks / tests". New work keeps re-creating helpers and patterns that already exist, because nothing surfaces "this already exists" before a brief is written. The maintainer asked whether a dedicated **reuse/refactor agent** should be added; it was analysed and is the wrong shape (see Why).

**Why**: A dedicated reuse/refactor *agent* is not the right abstraction:
- Subagents cannot spawn subagents, so a "refactor agent" could only be a *planner* — duplicating `project-pm`, which already owns task triage / decomposition / brief-writing.
- pm-dispatch agents split by **cognitive mode** (plan / execute / review), not by domain. Refactor is not a new mode — it is ordinary implementation. The spike agent (CC-220) earned a dedicated agent by being a genuinely distinct mode (uncertainty reduction); refactor is not.
- Refactor *expertise* is already placed: `architecture-reviewer` (coupling / abstraction fit), `risk-reviewer` (migration safety / reversibility) and `critic` (scope / convention drift) review every refactor PR, and `docs/dispatch-brief.md` already carries a `refactor` brief skeleton (semantic preservation, all-call-sites-updated, tests green). A refactor agent would duplicate those.
- The v0.3.0 synthesis already concluded "no separate reuse/refactor agent" — reuse work *is* ordinary briefed implementation (`docs/architecture/v0.3.0-synthesis.md`; the CC-200..204 extraction tickets are exactly this).

The genuinely-missing piece is the **front-end**: a reuse-scan that runs *before* briefing so the brief reuses rather than duplicates. That is a capability, not an agent — "split by goal, not by role".

**Requirement**: a reuse-scan **capability** (a skill / context step, not an agent), invoked by `project-pm` during briefing, that queries the codebase for prior art relevant to the task — similar functions, shared helpers, existing patterns — and emits a "reuse report" the dispatch brief incorporates. It is one consumer of the `context-pack` (CC-232) / context-enricher (CC-237) infrastructure and belongs in `skills/` (CC-061). Refactor *execution* stays on the existing brief → executor → gate path — no new execution agent.

*Provider dispatch architecture (tiered)*:
- Tier 0 (baseline): `rg` / `git grep` text search + `git log --oneline` for recently-touched files — zero setup, always available
- Tier 1 (builtin-index): `pmctl context query` via CC-338 repo-index (symbol + chunk search, FTS5/LIKE fallback) — available after first `pmctl context index`
- Tier 2 (cross-file refs): CC-346 `file_refs` layer (import/source call graph, 5 languages) — deepens relevance ranking
- Tier 3 (future): CC-209 codegraph — optional accelerator; same interface, richer output

Each tier is a **drop-in upgrade**: the consumer (`/pm` briefing, CC-239 reuse-scan) reads the same `context_hit_v1` shape regardless of which tier produced the hit.

*Output shape extensions (aligned with context_hit_v1, CC-237)*:
- `summary` (string): one-line description of the reuse candidate ("validates brief schema fields: schema_version, goal, …")
- `tags` (string array): searchable labels drawn from symbol kind / language / topic ("schema", "bash", "validation")
- `why_relevant` (string): reason this hit matches the current brief (filled by Tier 1+; may be absent for Tier 0 grep hits)

**Milestone**: v0.5.0 Phase 2 — the user-visible terminus of the context-pack spine; the first consumer of the repo index (CC-338) through the CC-237 interface.

**Priority**: P2 — depends on CC-338 (repo index) + CC-237 (interface) landing first.

**Cross-link**: CC-232 (context-pack schema), CC-237 (context-enricher baseline), CC-338 (builtin-index backend), CC-346 (cross-file refs), CC-209 (future codegraph), CC-061 (skills/), CC-200..CC-204 (the reuse debt this prevents recurring), `docs/architecture/v0.3.0-synthesis.md`.

**See**: pr:#256

## CC-255 — Spike infrastructure: rubric + brief template improvements ✅ 2026-06-11

**See**: pr:#267

**Problem**: CC-209 Phase 1 spike (PR #151) surfaced 2 spike-infrastructure gaps that caused codex to misapply the rubric:

1. **Verdict rubric ambiguity on "local env" scope**: rubric RED criterion 1 read "Install fails after a reasonable attempt and the failure is not a local env issue (e.g. peerDep that the user could resolve)". Codex hit a sandbox network block, classified it as "not local env" because the rubric only enumerated peerDep as a local-env class. Reality: sandbox isolation is the same conceptual class.
2. **Spike brief test-target ambiguity**: Phase 1 brief said "Angle A: pick one well-known symbol in pm-dispatch" — that sentence pre-committed pm-dispatch as the indexed test target. For language-aware tools (codegraph, semgrep, similar), the indexed target must match the tool's supported language set; the brief must commit to the right target, not let the executor pick.

**Why**: Both gaps caused codex to issue an inaccurate verdict (`RED` when the true verdict was `AMBER`). The errors weren't fabrications — codex executed honestly — but rubric + brief ambiguity made them analytically derivable from the prompt. Future spikes will repeat these unless the infrastructure is hardened.

**Requirement**:
- **Rubric template** (`/tmp/cc<NNN>-content/verdict-rubric.md` future spikes write): RED criterion 1 enumeration expanded to "(e.g. peerDep, sandbox network isolation, missing dev dependencies)". Add a sentence: "ANY constraint of the executor's local environment (sandbox, network, missing tools) counts as local-env — not a project quality signal."
- **Spike brief template** (in `docs/spikes/README.md` skeleton OR `docs/dispatch-brief.md`): add optional `test_target:` field to spike-brief schema. Required when the spike evaluates a language-aware tool (codegraph, AST-grep, semgrep, etc.); optional otherwise. Field commits to the representative target codebase the spike will exercise, distinct from the spike's working_dir.
- Update `agents/project-pm.md` brief-authoring guidance: when briefing a verdict-issuing spike for a language-aware tool, require `test_target:` in the brief output.

**Acceptance**:
- `docs/spikes/README.md` skeleton updated with `test_target:` field documented.
- `docs/dispatch-brief.md` schema adds `test_target:` as optional section.
- Reference verdict-rubric template enumerates sandbox-block as local-env example.
- `agents/project-pm.md` brief-authoring rules updated to require `test_target:` for language-aware-tool verdict spikes.
- Regression: re-author CC-209 Phase 2 brief (CC-253 work) using the new template; confirm it commits to `test_target:` with a user-chosen literal path explicitly.

**Priority**: P3 — process polish; affects every future spike but each individual cost is small.

**Co-implementation note**: CC-255 是 CC-253 的前置條件（CC-253 brief 必須使用 CC-255 更新的 `test_target:` 欄位）。若目標 codebase 已選定，建議 CC-255 + CC-253 同一 PR 實作，好處是 CC-255 有首個真實用例驗證。若 target repo 尚未選定，則先做 CC-255，等 target ready 再開 CC-253。CC-253 landing 後，CC-209 umbrella ticket 可一併關閉（標 superseded by CC-253）。

**Cross-link**: CC-209 (Phase 1 origin showing both gaps), CC-253 (Phase 2 dependent on these template improvements), `[[feedback_spike_pilot_required]]` (sibling spike-process rule), `[[feedback_spike_validation_mandatory]]` (sibling validation rule).

## CC-296 — [release] v0.3.0 deprecation sunset — remove after 2 official releases ✅ 2026-06-11

**See**: pr:#267

**Origin (user, 2026-06-01)**: 「這次 0.3.0 的版本有些需要 deprecate 的部分，請幫我在 2 次正式版本之後開始進行移除。」v0.3.0 引入的 back-compat 面要在經過兩個正式版本（v0.3.0 + v0.4.0）後、於 **v0.5.0** 移除。

**Removed**:
1. `pmctl guard check --profile <pm|codex|claude>` alias + back-compat tests (`deprecated-profile-*` / `profile-role-mutex`) from `scripts/test-pmctl-guard.sh`.
2. `scripts/codex-dispatch.sh` compatibility exec wrapper. All operational docs updated to `pmctl dispatch run --adapter codex`.

**Cross-link**: `[[CC-291]]` (`--profile` alias origin), `[[CC-289]]` (codex-dispatch shim origin).

## CC-321 — refactor: rename CLAUDE_HOOK_* env vars to PM_HOOK_* ✅ 2026-06-08

**Problem**: pm-dispatch hook configuration env vars use a `CLAUDE_HOOK_` prefix (`CLAUDE_HOOK_CODEX_READ_ROOTS`, `CLAUDE_HOOK_CODEX_GUARD`, `CLAUDE_HOOK_PM_GUARD`, `CLAUDE_HOOK_REVIEWER_GUARD`, `CLAUDE_HOOK_GATE_REPO_ROOT` (deleted), `CLAUDE_HOOK_DISPATCH_ABS`, `CLAUDE_HOOK_LOG_DIR`). The prefix creates a false coupling to the Claude Code agent system — these are pm-dispatch's own config knobs and should be in the `PM_HOOK_` or `PM_DISPATCH_` namespace.

**Plan**:
1. Rename each env var to `PM_HOOK_*` equivalent across all hooks, tests, and docs.
2. Add a shim period: if the old `CLAUDE_HOOK_*` name is set, emit a deprecation warning to stderr and honour it. Remove the shim after one release cycle.
3. Update `scripts/install-hooks.sh`, all `test-hooks.sh` / `test-pmctl-guard.sh` references, and `docs/`.

**Acceptance**: `grep -r CLAUDE_HOOK_ scripts/ adapters/ docs/` returns only the shim/deprecation-warning lines.

**Scope limit**: does NOT rename `CLAUDE_HOOK_LOG_DIR` if that conflicts with Claude Code's own log dir convention — verify first.

**Priority note**: breaking change; hold until CC-319/CC-320 are merged and no active PRs depend on the old names.

**Result**: All 7 `CLAUDE_HOOK_*` vars renamed to `PM_HOOK_*` across 15 files (6 hook scripts, 1 adapter, 3 test scripts, README, spike doc). Backward-compat shims added in all production hooks (removed after v0.5.0). `grep -r CLAUDE_HOOK_ scripts/ adapters/ docs/` returns only shim printf lines. 427 tests, 0 failures.

**Cross-link**: [[CC-319]], [[CC-320]].

**See**: pr:#243

---

## CC-338 — lightweight built-in repo index for context-pack（Bash+SQLite，無外部依賴）✅ 2026-06-09

**Renumbered**: 原 CC-328；與 PR #229 的 light-alias（已 ship，記於 MILESTONES v0.4.0 旁支修正）撞號，repo-index 改號至 CC-338。見 DECISIONS 2026-06-08。

**Problem**: pm-dispatch subagent 在 dispatch 前缺乏結構化的 repo context，只能透過重複 grep/read 探索相關檔案與 symbol，造成 token 浪費與 dispatch brief context 不穩定。現有方案不足：CC-237（context-enricher interface）需要外部 rg；CC-209（codegraph evaluation）評估的是 TypeScript external tool，已獲 AMBER——pm-dispatch 的 bash/markdown stack 不在其支援範圍內。

**Why**: 需要一個**內建**的 context layer，僅依賴 standard Unix toolchain（`bash / find / grep / awk / sed / sqlite3`），不引入任何需要另行安裝的 binary（如 ctags、rg、Node.js、Rust binary），在 dispatch 前產生 compact context pack（相關檔案 + approximate symbols + test hints），直接注入 dispatch brief，減少 subagent 盲目探索成本。此能力建在 v0.4.0 state-first 地基上（消費 Run/Event/trace 提供的 recently touched files、task history 等動態排序資料）；地基已落地，排入 v0.5.0 Phase 1。

**Requirement**:

*Phase 1 — MVP（Bash+SQLite only）*
1. `pmctl context index --source repo`：掃描 repo 建立 SQLite index（`files` / `symbols` / `file_chunks` 三張表）
2. `pmctl context update [path]`：增量更新（**mtime-only** 偵測變更；sha1 儲存供 debug 用，不參與 skip 判斷——content 變更但 mtime 保留時不會重新 index，此為 documented contract）
3. symbol 提取策略：Bash + awk/sed/grep 的 regex-based approximation，支援 Shell（function）、Go（func/type/struct/interface）、Python（def/class）、TypeScript/JavaScript（function/class/const arrow）；Markdown **以單一 chunk（前 2000 bytes）儲存**（heading-based chunking 延至後續 PR）
4. `pmctl context query "<query>"` — symbol + text 搜尋，格式對齊 `context_hit_v1`（CC-237）；`pmctl context pack` 組裝層屬 CC-239
5. FTS5 為 optional 加速層；缺 FTS5 時 fallback 到 `LIKE` / `grep` 並納入測試（Windows Git Bash sqlite3 未必含 FTS5）
6. 以 pm-dispatch 自身 repo 作為第一個 fixture，比較 3 個真實任務的 before/after dispatch brief

*SQLite schema（最小可行）*:
```sql
files(id, path, language, size_bytes, mtime, sha1, indexed_at)
symbols(id, file_id, name, kind, language, line_start, line_end, signature, backend, confidence)
file_chunks(id, file_id, heading, line_start, line_end, text, sha1)
```

*MVP 內建依賴*: `bash`, `find`, `grep`, `awk`, `sed`, `sqlite3`（不新增任何其他依賴）

*Optional backend（Phase 2 以後）*: ctags、ffts-grep、tree-sitter — 只作為加速層，MVP 無此需求

**Non-goals**:
- 精準 AST parsing / call graph
- LSP references / semantic embeddings
- MCP server / daemon / web UI
- 取代 CC-209 codegraph spike（兩者定位不同：CC-209 評估外部工具；CC-338 建內建 layer）
- 取代 CC-237 context-enricher（CC-237 是 interface；CC-338 是其 `--source builtin-index` backend）
- 重型 knowledge index（FTS over 全 memory）——與 `/mem-search` 重疊，延 v0.6.0

**Dependencies**:
- v0.4.0 Run/Event/trace state（CC-315 / CC-316）已穩定
- context pack 格式對齊 CC-232 context-pack schema + `context_hit_v1`（CC-237）
- 作為 CC-237 context-enricher 的 `--source builtin-index` backend；CC-239 reuse-scan 為第一個 consumer

**Milestone**: v0.5.0 Phase 1（P1 spine）。

**Priority**: P1.

**Cross-link**: [[CC-237]], [[CC-209]], [[CC-232]], [[CC-239]], [[CC-315]].

**See**: pr:#254

---

## CC-349 — repo-index: symbol index limited to code files only ✅ 2026-06-10

**Problem**: `pmctl context index` 把所有 Markdown heading 當成 symbol 建索引，但 Markdown heading 不是「可複用的程式碼符號」——shell function、Python function、JS/TS export 才是。任何含有大量 heading 的 Markdown 文件（不限 pm-dispatch 的 BACKLOG/CHANGELOG）都會在 reuse-scan 中佔據大多數命中，淹沒真正的 code symbol。

**Root cause**: `_ctx_extract_symbols` 的 `markdown)` case 讓 Markdown heading 和 shell function 走同一條 symbol 路徑。

**Solution（語言層級，不綁特定檔名）**: 從 `_ctx_extract_symbols`（`scripts/lib/pmctl-context.sh`）移除 `markdown)` case——Markdown/YAML/JSON/純文字等文件類型只建 file_chunks index，不建 symbol。程式碼語言（shell/python/js/ts/go）保留 symbol 提取。修改範圍：約 6 行刪除，0 新增。

**Expected outcome**: 任何 repo 上 reuse-scan 均以程式碼符號（函式、class、export）為主；文件標題不佔據排名。通用規則，不綁 pm-dispatch 特定檔案。

**Scope**: `_ctx_extract_symbols` markdown case 刪除 + 1 回歸測試（Markdown 檔案索引後 symbols table 為 0 row，file_chunks 有 1+ row）。

**Priority**: P2（直接影響 reuse-scan 核心 use case）。

**Cross-link**: [[CC-338]] (repo-index indexer), [[CC-239]] (reuse-scan consumer).

**See**: pr:#257

---

## CC-365 — context: lazy auto-build + pre-query incremental refresh ✅ 2026-06-13

**See**: pr:#271

`pmctl context query/pack/reuse-scan` now self-provision the repo index via `_ctx_ensure_fresh`: a missing db is auto-built when sqlite3 is available (one stderr notice), and an existing db gets an mtime-based incremental refresh before every read. Opt-outs: `PM_DISPATCH_CONTEXT_AUTOBUILD=0` / `PM_DISPATCH_CONTEXT_AUTOREFRESH=0`. The no-sqlite3 graceful-empty contract and zero-hit telemetry contract are unchanged; auto-build/refresh failures degrade to whatever the db state allows instead of failing the query.

---

## CC-366 — dispatch: auto-pack — reuse-scan pointer hits injected at dispatch run（opt-in） ✅ 2026-06-13

**See**: pr:#271

`pmctl dispatch run` gains step 3a: after brief-validate passes (and before guard), it runs reuse-scan on the brief's `goal:` and appends ≤5 pointer-only hits (`ref`/`why_relevant`/`confidence`, no chunk text) to an augmented brief copy at `<work_dir>/.pm-dispatch/ctx/packs/<run_id>.md`. The adapter argv receives the copy; guard and state transitions keep referencing the original authored brief. Activation: `--auto-pack` flag or config `dispatch.auto_pack = on` (default off; `--no-auto-pack` overrides config). Fail-open: any packing failure emits a stderr warning and proceeds with the original brief. Every auto-pack-on dispatch emits a `context.auto_packed` event (hits=0 included), making usage and hit quality measurable via `pmctl trace` — this generates the operational evidence CC-346's resume trigger requires. Design: DECISIONS 2026-06-13 `passive-context-v1-auto-pack-pointer-only-opt-in`.

---

## CC-367 — memory-plane hygiene: retire tool-trace hook + routing-log stub sunset ✅ 2026-06-13

**See**: pr:#271

`scripts/hook-tool-trace.sh` removed (write-only telemetry: zero consumers since shipping, no rotation, one forked process per tool call — violates the consumer-first principle). `scripts/hook-routing-log.sh` no-op deprecation stub removed. `install-hooks.sh` no longer registers either and now prunes both retired registrations from an existing `settings.json` on install while preserving all other entries. doctor inventories and the hooks/install/doctor test suites updated; `migrate-routing-to-events.sh` and its tests are unchanged (the migration path stays valid for old installs).

---

## CC-361 — context: repo-local db placement + graceful no-db degradation ✅ 2026-06-12

**See**: pr:#270

`_ctx_db_path()` now stores the context index at `<repo>/.pm-dispatch/ctx/context.db` instead of the global XDG path. `context index` auto-creates `.pm-dispatch/ctx/`, patches `.gitignore` on every index (idempotent; skips symlinked / hardlinked / non-regular `.gitignore` for path safety), and emits an error on mkdir failure. `query` / `pack` / `reuse-scan` return graceful empty results on missing db (acceleration path — no index = no context, not an error); `query` / `reuse-scan` still emit a zero-hit usage event in that case. Only the **DB location** ignores `PM_DISPATCH_STATE_ROOT`; context usage telemetry honors it like every other state write, and the test suite isolates all state into a throwaway root. All context unit tests pass.

---

## CC-363 — test: release-verify.sh Phase 3 external-repo-index smoke ✅ 2026-06-12

**See**: pr:#270

Phase 3 now runs four additional cases: `external-repo-index` (index a temp repo with dummy files), `external-repo-db-location` (assert `.pm-dispatch/ctx/context.db` inside target repo), `external-repo-query` (query returns hits), `context-no-db-graceful` (reuse-scan on repo with no index exits 0 with empty YAML). Only the context **DB location** ignores `PM_DISPATCH_STATE_ROOT` — it is always repo-local under `$REPO_ROOT/.pm-dispatch/`. Phase 3 itself redirects context usage telemetry to a throwaway `PM_DISPATCH_STATE_ROOT` (torn down before Phase 4) so the smoke never writes `context.*` events into the operator's real trace store. Operator note: indexing the real checkout leaves a repo-local derived cache at `$REPO_ROOT/.pm-dispatch/ctx/` (gitignored); `rm -rf .pm-dispatch` if a fully clean tree is required.

## CC-378 — hygiene: backlog close-state taxonomy 正規化 + archive sweep ✅ done 2026-06-14

**Problem**: 歸檔器 `archive-closed-backlog.sh` 只認 `✅ closed` / `🚫 dropped` 為 terminal，但實務上使用的關閉態是 `✅ done`（14）與 `🟢 superseded`（6），closed/dropped 各 0。結果 `--dry-run` 長期回 0、歸檔政策從不觸發，20+ 完成票堆在工作集。並有兩組 emoji 碰撞：`✅ closed` vs `✅ done`（同形、都「完成」），`🟢 someday`（active）vs `🟢 superseded`（terminal）。

**Decision**: 終態 = `done` / `closed` / `superseded` / `dropped`；非終態 = active / deferred / someday / `⚠️ partial`。`✅ done` 升為終態+可歸檔（退役「soft-close 留在 active」規則）。emoji 碰撞由「終態票歸檔後即離開 board」自然化解，不硬改 emoji。

**Change**: `archive-closed-backlog.sh` terminal predicate 改為精確 token/date 形式（含 `done`/`superseded`；前綴比對會誤收 `✅ done-ish` 等近似字串）+ header 指向 §2.3 為單一真理；`test-archive-closed-backlog.sh` 把 `case_soft_close_done_kept` 翻轉為 `case_done_and_superseded_archived`，並補 malformed near-miss 負向 case（驗 `🟢 someday`／近似字串不被掃，14/14 綠）；`pm/schema.md` §1/§2.3/§4/§5；BACKLOG legend + BACKLOG-ARCHIVE 前言重分組。跑一次 sweep：14 done + 6 superseded（含本票）移入 `BACKLOG-ARCHIVE.md`。

**See**: DECISIONS.md 2026-06-14 backlog-close-state-taxonomy-normalization。

---

## CC-104o — Windows Store python3 stub (superseded by CC-104t)

**See**: CC-104t

## CC-062 — codex-bash-guard policy test matrix 🟢 superseded 2026-06-14

**Superseded by [[CC-374]]**（v0.6.0 hook-guard wrapper 收口）：allow/deny JSON fixtures 是 guard 收口的驗證底座（policy 從「聰明 shell parser」變「可驗證 matrix」），併入 CC-374；原始範圍保留為 CC-374 sub-scope。

**Problem**: `hook-codex-bash-guard.sh` 的允許/拒絕邏輯非常複雜（newline 檢查、quote 檢查、shell metacharacters、background mode、git form allowlist、read path allowlist）。目前有 test-hooks.sh 的整合測試，但沒有結構化的 per-rule fixtures；policy 改動的影響面不透明。
**Why**: shell-based policy parser 有兩種失效模式：過度阻擋合法工作流，以及漏過某些 bypass。只有可讀的 allow/deny test matrix 能讓安全 policy 從「很聰明」變「可驗證」。
**Requirement**: 建立 `tests/policy/codex-bash-guard/` 目錄，以 JSON fixtures（每個 fixture 含 `input`、`expected: allow|deny`、`reason`）描述每條規則的 allow 和 deny case；`scripts/test-codex-bash-guard.sh` 讀 fixtures 執行；CI 加入此 job。

## CC-066 — [P2] Declarative policy.yml for hook allowlist 🟢 superseded 2026-06-14

**Superseded by [[CC-374]]**（v0.6.0 hook-guard wrapper 收口）：把 hook allowlist 從 shell logic 抽成宣告式 policy 是 guard 收口的一部分，併入 CC-374；原始範圍保留為 CC-374 sub-scope。

**Problem**: `hook-codex-bash-guard.sh` 的 git allowlist、read path allowlist、shell metacharacter blocklist 等 policy 直接寫在 shell script 邏輯中；per-repo override 不可能，policy 審計需要讀 shell code。
**Why**: policy-as-code 優於 policy-in-code：可 diff、可 review、可 override、可 lint。CC-204（hook framework reuse）完成後這條的實作成本大幅下降。
**Requirement**: `config/policy.yml`（repo 級預設）+ `~/.pm-dispatch/policy.yml`（user override）定義 git allowlist / read roots / metachar blocklist；hook 腳本 load + merge policy；CC-062 test matrix 讀 policy fixtures。依賴 CC-062、CC-204。

## CC-215 — pmctl — core CLI entrypoint ✅ 2026-06-09

**See**: pr:#252 (final slice); pr:#171, pr:#242 (prior slices)

**Status (2026-06-09)**: All planned pmctl state-ops shipped. **Shipped (PR #171)**: `adapter generate` + `dispatch run`. **Shipped (PR #242)**: `task list/show/create/update` + `decision add`. **Shipped (PR #252)**: `task claim/dispatch/status/review` + `safe bash` + `task.claimed/task.dispatched/task.reviewed` event kinds. `backlog view/sync` via CC-287, `guard check` via CC-288/CC-291, `trace` via CC-315 (stale references in body below).

**Milestone (2026-06-08)**: the genuinely-remaining pmctl state-ops — `task claim/dispatch/status/review` + `safe-bash` — are targeted for **v0.5.0 Phase 2** so the `⚠️ partial` does not float indefinitely. `pmctl validate` is split out as its own active ticket (CC-341).

**Problem**: pm-dispatch has no language-agnostic runtime binary. All orchestration logic is
reached through Claude-specific hooks and commands, preventing non-Claude CLIs from accessing
the same PM capabilities without duplicating logic.

**Why**: `pmctl` as a standalone binary makes pm-dispatch a proper tool layer: Claude hooks,
Codex wrappers, and MCP server all become thin callers into one well-defined CLI interface.
Guard logic and dispatch state move from Claude-only paths into `pmctl` so any CLI without hook
support can call `pmctl guard check` or `pmctl safe-bash`.

**Requirement** (full surface — all subcommands now shipped across PRs #171/#242/#252):
- Implement `cli/pmctl` with subcommand interface:
  - ✅ `pmctl task list/show/create/update` (PR #242)
  - ✅ `pmctl decision add` (PR #242)
  - ✅ `pmctl task claim|dispatch|status|review` (PR #252)
  - ✅ `pmctl validate brief` (PR #252, see CC-341)
  - ✅ `pmctl safe bash` (PR #252)
  - ✅ `pmctl backlog sync` (via CC-287)
  - ✅ `pmctl trace tail` (via CC-315)
  - ✅ `pmctl guard check --event <pre-write|pre-bash|post-task> --file/--command <val>` (via CC-288/CC-291)
  - ✅ `pmctl adapter generate <claude|codex|antigravity|opencode>` (PR #171)
- Claude adapter: `/pm task-123` → `pmctl task dispatch task-123 --agent claude`
- Guard logic migrates from Claude-only hooks into `pmctl` so hook is just a thin caller.
- `pmctl adapter generate` produces per-CLI config from core agent definitions.

**Depends on**: CC-211 (core layer extracted first).

**Complements**: CC-211 (architecture), CC-216 (MCP server wraps pmctl).

**Priority**: P1 within CC-211 roadmap. Evaluate at v0.3.0.

## CC-228 — BACKLOG validator-debt cleanup ✅ 2026-06-08

**See**: Superseded by CC-277 (pr:#183). `pm/scripts/validate.sh` now exits 0 on main with no E-codes — verified 2026-06-08. CC-228 described a real debt that CC-277 fully resolved in v0.3.0 BACKLOG Hygiene Track.

**Original problem**: `pm/scripts/validate.sh` exits 1 on `main` with ~31 pre-existing E-codes, none introduced by recent PRs. An always-red validator provides no signal — a real new error would be invisible.

**Why**: The debt accumulated as the schema tightened (CC-030 / CC-052 / CC-067) faster than existing rows were migrated.

**Requirement** (resolve per error class, dry-run `validate.sh` after each, target exit 0):
1. `E-INDEX-MISMATCH` — CC-104d/e/f/g/j/k/m/r/s have index rows but no body section. Add stub sections or drop the index rows (they were Windows-dogfood sub-items, mostly folded into shipped PRs).
2. `E-AREA-ENUM` — CC-052/060/104v/203/204 etc. use slash-combined or non-enum areas (`arch`, `config`, `schema`, `ops`, `hook`). Widen the `area` enum (adding `arch`/`ops` is additive and fixes the most rows) or rewrite the rows.
3. `E-REFS-PREFIX` — CC-059/060/061/064/066 carry bare `CC-NNN` refs; the Refs column requires a prefix. Move ticket cross-links into the section body.

**Priority**: P2 — not blocking, but should land before v0.3.0 M1 tightens the schema further.

**Cross-link**: surfaced during CC-222 close-out 2026-05-22.

## CC-272 — docs: executor contract cleanup bundle ✅ 2026-06-08

**Result**: `docs/dispatch-brief.md` 新增 §Commit delegation rule（含反例 + 正例）；§Style notes 補 commit 禁止條目。`docs/executor-contract.md` 新增 §Async dispatch behavior（sync vs async 判斷規則、per-scenario table 拆分 primary Bash 路徑 vs Agent fallback、diagnosis 指引）。新增 `pmctl gate run` 子命令（`cli/pmctl` + `scripts/lib/pmctl-gate.sh`）使 gate 走統一 pmctl 介面而非直呼腳本；`commands/pr-gate.md` Step 1/2 同步更新。消除 false partial 噪音來源，確立 pmctl 為 gate 唯一 public 介面。

**See**: pr:#245

兩個 executor 文件噪音問題合併成一個 docs PR：

### Part A — brief template: omit commit block; document main-thread commit delegation

**Problem**: Every brief ends with a `git add + git commit` block that `hook-codex-bash-guard` blocks. The executor marks the commit step as failed and reports `status: partial` in the output summary — even when all code changes are correct. The main thread must manually stage and commit after every dispatch. The brief template implicitly encourages adding a commit block, creating a permanent noise signal.

**Options**:
- **A (preferred)**: Remove the commit block from the brief template and document in `docs/dispatch-brief.md` that commit is always delegated to the main thread. Update `self_verify` template to stop including `git commit` as a success criterion.
- **B**: Add `git add` + `git commit` (without destructive flags) to `hook-codex-bash-guard` allowlist. Requires security review of hook policy (`[[CC-066]]`).
- **C**: `scripts/codex-dispatch.sh` reads a `.commit-msg` file written by the executor and performs the commit on its behalf; executor stays sandboxed.

**Impact**: Every dispatch shows false `status: partial`; creates a recurring manual step the main thread must remember.

**See**: issue:#173 (Pattern 3)

### Part B — run_in_background default async escalation (absorbed from CC-268)

**Problem**: Agent tool called without `run_in_background:true` may silently promote the subagent to async mode and return `Async agent launched successfully` instead of blocking. Observed with `codex-executor` (~3m45s async without the flag). Docs say "Claude decides" but give no criteria; callers cannot reliably predict whether the dispatch blocks the main thread.

**Proposed fix**: Document in `docs/executor-contract.md` which subagent types always run async, and whether/when the default blocks.

**See**: issue:#166

**Cross-link**: `[[CC-066]]` (declarative policy.yml for hook allowlist — relevant if Option B chosen for Part A)

**Priority**: P2 — Part A affects every dispatch; Option A is pure documentation with immediate noise reduction.

---

## CC-307 — [arch] pm role cross-runtime — guard 已 runtime-agnostic，但文件與 alias 仍暗示 pm = claude-only 🟢 superseded 2026-06-14

**Superseded by [[CC-374]]**（v0.6.0 hook-guard wrapper 收口）：移除「pm = claude-only」殘留（`--profile pm` 的 runtime=claude hardcode、`pmctl-guard.sh` 的「currently claude-only」說明、補 codex-as-pm dispatch smoke test）併入 CC-374；原始範圍保留為 CC-374 sub-scope。

**Problem**: CC-291 的兩軸設計（role ⊥ runtime）要求 pm guard policy 不能綁 runtime。`hook-pm-write-guard.sh` 已 runtime-agnostic ✓，`--role pm --runtime codex` CLI 路徑已可呼叫 ✓，但以下三點仍讓人誤以為 pm=claude-only 是設計決定：

1. **deprecated `--profile pm` alias** hardcode `runtime="claude"`（`scripts/lib/pmctl-guard.sh`）
2. **說明文字** 說「currently claude-only; no codex-as-pm」，未分清「guard 設計」與「現有部署」
3. **無 codex-as-pm end-to-end test** — 沒有驗證 `pmctl dispatch run --adapter codex` 配合 pm-role brief 可成功 dispatch

**Why it matters**: 若下一個 PM runtime（如 Gemini CLI / OpenCode）出現，工程師會誤以為 pm 不能跨 runtime 而重複發明輪子，而非直接走 `--role pm --runtime <new>` 路徑。兩軸設計的可擴展性在這裡被文件化的 false constraint 遮蔽。

**Fix scope**:
1. **alias** — `--profile` alias 已由 CC-296 移除，此項目已完成。
2. **說明文字** — 把「pm only ever runs on claude; no codex-as-pm」改為「pm guard policy is runtime-agnostic; claude is the currently deployed pm runtime, but other runtimes are supported by design」（`scripts/lib/pmctl-guard.sh`）
3. **integration test** — `scripts/test-pmctl-guard.sh` 加一個 smoke test: `pmctl guard check --role pm --runtime codex --event pre-write --file /tmp/brief-task.md` 確認 guard 路徑通（已有 claude 版，補 codex 版對稱）

**Acceptance**: 文件改完後，讀程式碼的工程師應能明確看出「pm role 是 runtime-agnostic 的設計，目前只有 claude 部署，但 codex-as-pm 不需改 guard 就能支援」。

**Cross-link**: `[[CC-291]]`（two-axis design），`[[CC-296]]`（alias sunset），`[[CC-215]]`（pmctl dispatch run）。

---

## CC-343 — skill: /discover — milestone seeder + opportunity scanner ✅ 2026-06-09

**See**: pr:#251

**Renumbered**: 原 CC-330；與 BACKLOG-ARCHIVE 已關閉的 state_store_init mkdir-failure 票（✅ 2026-06-05）撞號，未開工的 /discover 改號至 CC-343。撞號由 ticket-id lint 偵測，見 DECISIONS 2026-06-08。

**Problem**: project-pm 是**收斂模式**（reactive：收到任務 → 分解 → 派工），沒有內建的**發散模式**（proactive：讀 backlog + 近況 → 生成機會清單）。每次 milestone 規劃都靠對話即興，缺少系統性的「現在最值得做什麼」掃描。

**Why**: Brainstorm / ideation 的正確形狀是利用 PM 的既有 context（memory、DECISIONS、MILESTONES），而非隔離的新 agent。隔離反而要重新推導所有設計決策。正確形狀是：一個 **skill** 切換 PM 到發散模式，結構化地生成機會清單。

**Requirement**:
- `commands/discover.md` — `/discover [theme]` skill 定義：
  - 以指定 theme（可選）或預設「當前 repo 最高槓桿改善點」為提示
  - 讀取：backlog（`🟢 someday` + `⏸ deferred` 項目）+ DECISIONS + MILESTONES（next milestone 範圍）+ `git log --oneline -30`
  - 輸出：5–10 個機會項目，每項含 `{title, problem_in_one_line, why_now, estimated_size: XS/S/M/L}`，按槓桿高低排序
  - 不產出 dispatch brief，不承諾任何實作——純探索輸出
- 典型用法：`/discover v0.5.0 themes`、`/discover dispatch pipeline improvements`、`/discover`（全域）
- 結果由使用者決定是否轉為正式 ticket 或 milestone

**Non-goals**:
- 不取代 `/pm`（project-pm 收斂模式仍是主路徑）
- 不自動建立 ticket（由使用者判斷後手動開）
- 不是 standalone agent（PM 已有所需 context，不需要隔離）

**Relationship**:
- 使用 PM 發散模式消費 backlog + MILESTONES
- 未來可以接 CC-338 context index 強化 codebase 相關機會的偵測精度

**Milestone**: `🟢 someday` — 實作成本 XS（只需一個 commands/discover.md），可提前於其他 someday 項目。

**Cross-link**: [[CC-220]], [[CC-239]], [[CC-237]], [[CC-338]].

---

## CC-350 — bug: pmctl gate run SIGPIPE×pipefail — stdout pipe → 0-byte result + false-success exit 0 ✅ 2026-06-10

**Problem**: `scripts/pr-gate.sh` 在 dispatch reviewer 之前會 `printf` 多行 banner 到 stdout。當下游 consumer（`head -N`、`grep -q` 等早期關閉的 pipe）讀完後關閉 pipe，下一個 `printf` 寫入已關閉的 pipe → SIGPIPE；腳本 `set -o pipefail` 讓主流程在 dispatch 之前中斷；結果檔停在 `touch` 建立的 0 bytes；shell 對整條 pipeline 回報的 exit code 是最後一段（`head`）的 exit 0 → 整體誤報成功。false-success 比 false-failure 危險：自動化 caller（含 AI agent、CI）把空結果當成 gate 通過。

**Evidence**: issue:#255 記錄了 7 次相同 branch gate run：接 `| head` 全部 0-byte + exit 0；無 pipe 全部正常產出。

**Fix options（擇一或併用）**:
1. **結果完整性把關**：main 結尾在回報前驗證 OUTPUT_FILE 非空且含 `^Final: (GO|NO-GO)$`；不滿足則 exit 非 0。確保 0-byte 永遠不會誤報成功。
2. **stdout 容錯**：banner/progress 的 `printf` 對 SIGPIPE 容錯（`trap '' PIPE` 或 `|| true`），讓下游關 pipe 不中斷 gate 主流程。
3. **文件警告**：README / `pmctl gate run -h` 明示不得 pipe gate stdout；截斷輸出請用 `> file` 或讀 `.gate-results/`。

**Priority**: P2 — false-success 對自動化 caller 是靜默安全漏洞。

**Resolution**: 採 option 2（stdout 容錯）為主。第一次嘗試（`trap '' PIPE`）在 `set -e` 下不足——EPIPE 讓 `printf` 回傳非零，`set -e` 仍在 dispatch 前中止。完整修法兩處：(1) `say()` helper 包裝所有進度輸出（`printf … 2>/dev/null || true`），訊號 + set-e 雙重容錯；(2) sequential 與 synthesis 的 foreground `eval` 改 `>&2`，避免 dispatch 子程序繼承已關閉的 consumer pipe 而提前死亡。既有 per-route result-integrity 檢查維持為 exit code 權威。回歸測試 `test_piped_stdout_does_not_abort_gate`（接 `head -n1` 斷言結果檔完整）。

**See**: pr:#258, issue:#255

---

## CC-351 — codex-executor: brief schema validation must fail-fast before any file reads ✅ 2026-06-10

**Problem**: codex-executor 收到非 YAML brief（缺 schema_version/goal/files/self_verify 欄位）時行為不一致——同一 session、相同格式的兩個 brief，一個立即 REJECT，另一個進入無效 loop：讀 brief、嘗試 Bash edit（被 hook 擋）、循環找 Codex dispatch 路徑，耗費大量 token 後被外部 TaskStop 終止。行為分歧根因不明（可能是 session-state 差異或 prompt 快取邊界）。

**Requirement**: `agents/codex-executor.md` 的執行協議應把 brief schema validation 移到 **所有 file reads 之前的第一步**：若 brief 缺少必填欄位或無法解析為 YAML frontmatter，立即 REJECT 並輸出明確錯誤訊息，無論 dispatch 上下文或 session 狀態為何。

**Acceptance**:
1. 以純 Markdown prose brief（無 `schema_version`）dispatch codex-executor → 立即 REJECT，不讀任何 target file
2. REJECT 訊息含缺少的欄位名稱
3. 行為在同 session 多次 dispatch 下一致（不因快取狀態改變）

**Priority**: P2 — 每次格式錯誤 brief 都可能耗費數千 token；行為不可預測加劇除錯難度。

**Scope note (planning 2026-06-10)**: fix 對稱套用到**兩個 Agent fallback executor**。codex-executor 的 §0 gate 走 `pmctl dispatch run`（codex-bash-guard 擋 `bash` verb，無法直接呼叫 brief-validate），靠 `pmctl-dispatch.sh` 第 3 步 brief-validate 在 spawn codex 前 REJECT；claude-executor 的 §0 gate **直接** `bash scripts/brief-validate.sh <brief>`（claude 無 verb guard），exit 1 即 REJECT 且不讀 target file。兩者收斂到同一支 `scripts/brief-validate.sh`、同一 REJECT 訊息格式。兩檔都補回漏列的 `schema_version`。正規路徑（兩個 adapter 皆走 pmctl）本已有確定性 gate，僅 Agent fallback 需 prompt 硬化。

**Cross-link**: [[CC-045]] (brief timeout heuristic), [[CC-272]] (executor contract docs), [[CC-353]] (executor dispatch 統一，同 PR).

**See**: pr:#259, issue:#217

---

## CC-353 — unify executor dispatch: claude-executor symmetric to codex-executor ✅ 2026-06-10

**Problem**: 兩個 executor 的文件結構不對稱，難維護。`codex-executor.md` 已是完整的「pmctl 主路 + N-condition fallback allowlist + caller decision checklist」結構（lifecycle-leak 警告、§When NOT to use 5-condition 表、10-item checklist）；`claude-executor.md` 的 §When NOT to use 只是簡單 bullet list，沒有對稱的 fallback 結構。心智模型雙軌，每次改 executor 契約都要分別理解兩套敘述。

**Insight（planning 2026-06-10）**: claude 的「pmctl 優先」其實已是現行設計——`commands/pm.md` Route B 主路即 `pmctl dispatch run --adapter claude`，`Agent(claude-executor)` 已被文件化為「`claude --print` 不可用時」的窄 fallback。但 `Agent(claude-executor)` 不是純 legacy，有兩個真實職責：(1) 無 `claude` CLI 的主機上的 host-independent 逃生口（pmctl 路要 spawn 外部 `claude --print` binary，無 CLI 即失敗）；(2) `pr-gate` Route B 的 reviewer fan-out（in-session 並行 spawn，本來就該用 Agent）。因此**完全砍掉 Agent 路會損失能力 + 逼 pr-gate 重寫**——決議採對稱窄 fallback，不砍。

**Requirement**:
1. `agents/claude-executor.md` 重構成與 `agents/codex-executor.md` 鏡像的結構：頂部 lifecycle/fallback 框架、§When NOT to use 改成 N-condition fallback allowlist 表 + caller decision checklist。
2. 明定 `pmctl dispatch run --adapter claude` 為唯一文件化的檔案式主路；`Agent(claude-executor)` 為窄 fallback，條件清楚列出：①無 `claude` CLI ②main-thread context 壓力 ③sync sequencing ④pr-gate reviewer fan-out（標為**正當用途、非 fallback**，避免被誤砍）。
3. 窄幅對齊 `docs/dispatch-brief.md §Fallback`（claude fallback 表對稱於 codex）；如 `docs/executor-contract.md` 有不對稱敘述一併校準。

**Acceptance**:
1. `claude-executor.md` 與 `codex-executor.md` 的 fallback 段結構鏡像（同樣的 allowlist 表 + checklist 形狀）
2. 文件明確標示 pmctl 為主路、Agent 為窄 fallback，且 pr-gate fan-out 不被列為「不要用」
3. `bash scripts/lint-agents.sh` exit 0

**Effort**: prose-only，無 code 變更。

**Priority**: P2 — 維護性債；統一心智模型降低 executor 契約後續修改成本。

**Cross-link**: [[CC-351]] (fail-fast 驗證，同 PR 同 branch), [[CC-272]] (executor contract docs), [[CC-266]] (claude adapter).

**See**: pr:#259

---

## CC-334 — install: install-hooks.sh 安裝時自動 merge permissions.allow ✅ 2026-06-08

**Problem**: pr-gate 的 `--executor claude` 路由會透過 Agent tool 派生 reviewer subagents（Claude Code harness agents）。這些 subagents 需要明確的 `permissions.allow` 條目才能寫入 `.gate-results/` 並執行 `pmctl guard check`。現行 `install-hooks.sh` 只在 `~/.claude/settings.json` 寫入 hooks（PreToolUse/PostToolUse 條目），完全沒有補 `permissions.allow`，導致**安裝後 `/pr-gate` 仍無法正常運作**——需要使用者自行發現問題並手動補。對使用者而言等同工具無用。

**Root cause**: install-hooks.sh 的設計只考慮到 hooks 安裝，沒有考慮到 permissions 是同樣重要的執行前提。

**Required permissions** (reviewer subagents 需要):
- `Write(<workspace>/**/.gate-results/**)` — 寫 gate 結果
- `Bash(pmctl guard check:*)` — 執行 guard check
- `Bash(mkdir -p:*)` — 建目錄

**Design: 動態推算 workspace 路徑**

使用者的 repo 根目錄因人而異（`~/github/`, `~/projects/`, `~/code/` 等），不能 hardcode。策略：

1. **在安裝時偵測 workspace root**：取 pm-dispatch 安裝目錄的 **parent**（即 `dirname "$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"`）。如果使用者的 repos 都在同一資料夾，這個 parent 就是 workspace root。
2. **產生 glob**：`<workspace_root>/**/.gate-results/**`（例如 `/home/user/github/**/.gate-results/**`）。
3. **Fallback**：若偵測失敗（非 git repo、或 parent == HOME），改用 `$HOME/**/.gate-results/**`——仍然安全（限制在 `.gate-results` 子目錄）。
4. **Idempotent merge**：用 jq 讀現有 `permissions.allow` 陣列，若條目已存在則跳過，否則 append；避免重複安裝造成重複條目。

**Acceptance**:
- `bash install.sh` 完成後，`jq '.permissions.allow' ~/.claude/settings.json` 包含正確的 Write glob 和兩個 Bash 條目。
- 重複執行 `install.sh` 不重複寫入（idempotent）。
- 在 `/home/user/github/` 和 `/home/user/projects/` 兩種佈局下，glob 路徑都正確對應。
- 若 jq 不存在或 settings.json 格式損毀，印出清楚錯誤，不靜默失敗。

**Implementation location**: `scripts/install-hooks.sh` 尾段，在 hooks 安裝成功後執行；或抽為獨立函式 `install_permissions()`。

**Self-verify**:
- `cmd: "jq -e '.permissions.allow | map(select(test(\".gate-results\"))) | length > 0' ~/.claude/settings.json"`
- `cmd: "bash scripts/install-hooks.sh && bash scripts/install-hooks.sh; jq '.permissions.allow | length' ~/.claude/settings.json | diff - <(jq '.permissions.allow | length' ~/.claude/settings.json)"`（重複安裝長度不變）

**Cross-link**: [[CC-321]]（PM_HOOK 重命名，同一 install UX 修復脈絡）。

**Result**: `install-hooks.sh` 安裝後自動 idempotent merge 三個 reviewer permissions.allow 條目（Write glob、pmctl guard check、mkdir -p）。workspace root 從 pm-dispatch repo parent 動態推算，git 失敗或 parent==HOME 時 fallback 到 $HOME。`uninstall-hooks.sh` 同步移除這三個 managed entries。workspace 偵測邏輯抽出至 `scripts/lib/gate-workspace.sh` 供 install/uninstall 共用。9 個 gate-perms 測試案例，83 tests passed。

**See**: pr:#244

---

## CC-336 — dx: deprecated warnings + executor docs preferred path update ✅ 2026-06-08

三個變更確保呼叫舊路徑時有明確提示，且 agent/command 文件反映正確的 preferred path：

1. **`scripts/codex-dispatch.sh`** — 加 stderr `[deprecated]` 三行 warning，任何直接呼叫都能看到。
2. **`commands/pm.md`** — `executor: codex` 的 primary route label 從 `scripts/codex-dispatch.sh` 改為 `pmctl dispatch run --adapter codex`。
3. **`agents/codex-executor.md`** — Step 2 Bash 模板改為 `pmctl dispatch run --adapter codex ...`；Job 步驟和 §When NOT to use this agent 同步更新。

**Root cause**: PM 主線程 dispatch 時看到的 agent 文件仍指向 `codex-dispatch.sh`，導致 agent 讀到舊 instruction 後繼續走 deprecated 路徑（blocking main thread）。

**See**: pr:#246

---

## CC-337 — portability: Windows Git Bash skip-guards + doctor.sh auto-profile fix ✅ 2026-06-08

Windows v0.4.0 dogfood 發現三類問題，分 P1/P2/P3 修：

**P1 — `scripts/doctor.sh` auto-profile false FAIL**（release blocker）

`detect_hook_profile()` 的 `auto` case 只看 `codex_available`，不看平台。Windows Git Bash 若 PATH 有 codex CLI → 判定 `full` → 期待 codex hooks → FAIL。但 `install-hooks.sh` 在 Windows 正確安裝 `minimal`。

Fix：在 `check_hooks()` 的 `detect_hook_profile()` inner logic 中，先 `detect_platform == windows` → 強制 `_want_full=0`，再才看 `codex_available`。

**P2 — 測試套件缺 Windows skip-guards**（Windows CI 失敗）

| 套件 | 問題 | 修法 |
|---|---|---|
| `test-pr-gate-profile` | `create_runner` 用 `ln -sf` 建 system binary stubs | suite-level skip on windows |
| `test-claude-executor` case 5 | `ln -sfn` + `-L` check 在 MSYS 失敗 | case-level skip on windows |
| `test-dispatch-post-verify` 4 cases | `ln -sfn`/`ln -s` symlink security tests | case-level skip on windows |

**P3 — `uninstall.sh` 空目錄清理回饋**（UX）

pruning loop 改為：先 `-d` 判斷是否存在，成功 `rmdir` 後印 `pruned <dir>`，靜默略過非空目錄。

**See**: pr:#247


## CC-339 — lint: prevent duplicate CC id with divergent title ✅ 2026-06-08

**Problem**: The same CC id can silently map to two different tickets. CC-328 was assigned to the shipped light-alias work (#229, recorded in MILESTONES v0.4.0 旁支修正), then reused by the repo symbol-index ticket (#235) — only caught by manual reading during v0.5.0 planning. A knowledge/repo search index makes this worse: a recalled CC id that resolves to two meanings poisons the context-pack.

**Why**: canonical ticket metadata must be clean before it backs a search index. A divergent-title collision is mechanically detectable; relying on a human to notice it is the failure mode that produced this ticket.

**Requirement**: add a validator rule (in `pm/scripts/validate.sh` or a sibling wired into `lint.yml`) that asserts one CC id never maps to two different titles across the BACKLOG active body and MILESTONES tables. Emit an E-code on collision. The CC-328 → CC-338 renumber (DECISIONS 2026-06-08) is the first fixture.

**Amendment (DECISIONS 2026-06-08)**: the literal "compare title *strings* across BACKLOG/MILESTONES" above proved unworkable — all title surfaces are free-form and legitimately divergent (EN title vs ZH description; one id repeated per milestone). The shipped invariant is the string-comparison-free equivalent: one id never both **open on the active board** and **closed in the archive** (cross-lifecycle collision). This narrower-but-mechanical scope is intentional, not drift — see the Result note below and DECISIONS.

**Milestone**: v0.5.0 Phase 0 follow-up (hygiene; not blocking the spine).

**Priority**: P3.

**Result**: Shipped as `pm/scripts/lint-ticket-ids.sh` (sibling, not folded into `validate.sh`), wired into `lint.yml` as the `lint-ticket-ids` job. The literal "compare title strings across BACKLOG/MILESTONES" framing was unworkable (all title surfaces are free-form and legitimately divergent — EN title vs ZH description, ids repeated per-version), so the invariant was reinterpreted as a string-comparison-free **cross-lifecycle collision**: no id may be open (non-stub) on the active board while also closed in the archive. On first run it caught two pre-existing collisions — `debt-auditor` (CC-329) and `/discover` (CC-330) reusing closed archive ids — both renumbered to [[CC-342]] / [[CC-343]] in this PR. See DECISIONS 2026-06-08.

**Cross-link**: [[CC-338]] (renumber that motivated this), [[CC-342]], [[CC-343]] (collisions caught), [[CC-237]].

**See**: pr:#250

## CC-354 — anchored knowledge index + retrieval reflex ✅ 2026-06-10

**See**: pr:#263

Shipped per-format chunking (markdown heading-split / txt+yaml+json 40-line window), `--domain knowledge|repo` filtering, and the `docs/context-retrieval.md` query-before-grep contract. HTML is not scanned; semantic HTML chunking deferred to CC-355.

## CC-356 — wiring: context pack / reuse-scan 接進 dispatch 流程 + 使用可觀測 ✅ 2026-06-10

**See**: pr:#264

**Problem**: `pmctl context pack` 與 `pmctl context reuse-scan`（CC-239, #256）ship 後**操作面零 caller**——`agents/`、`skills/`、`commands/`、操作 docs（dispatch-brief.md 等）沒有任何一處指示在 brief 撰寫流程中呼叫它們（grep 驗證 2026-06-10，僅 architecture 規劃文件提及）。repo plane 正在重演 2026-06-10 重定錨對 memory 診斷的同一種病：能力存在但工作流不變，dispatch 行為沒有任何改變。

**Why**: pm-dispatch 的價值主張是「減少 main thread 重新解釋背景、減少付費模型浪費」。索引只有在 brief 撰寫流程實際引用它的輸出時才兌現這個價值。本票把「接線即驗收」原則落到 repo plane（CC-354 已涵蓋 knowledge plane 的 query-before-grep reflex）：工具被叫、輸出進 brief、使用次數可量測。這也是 CC-346 是否恢復的證據來源——先觀察 reuse-scan 實際使用，再決定要不要給它加 ref 資料層。

**Requirement**:
- **接線（platform-neutral，與 CC-354 同紀律）**：在中立 docs 契約（`docs/dispatch-brief.md` 或 CC-354 新立的 retrieval 契約文件）加入 brief-authoring 步驟——撰寫 `files:` / `context:` 前先跑 `pmctl context reuse-scan`（或對已知 term 跑 `context pack`）取 prior-art anchors；`agents/project-pm.md` 與 `skills/dispatch-brief/SKILL.md` 各放指標（不含票號，遵守 no-CC-in-operational-files 規則）。不寫 CLAUDE.md。
- **Brief 噪音上限**：`reuse_candidates` 輸出設 hit 上限（建議 ≤5）+ PM 人工篩選步驟；未經篩選不得整段貼進 brief（防 stop-word 抽詞噪音變成付費 executor 的 token 成本）。
- **使用可觀測**：`pmctl context query` / `reuse-scan` 每次呼叫 emit 一筆 event（既有 state-writer 機制，無新基建），使「索引被用了幾次」可由 `pmctl trace --kind` 查出。
- 不改 index 機制本身；純接線 + 可觀測。schema delta：`event.schema.json` 新增 `context.queried`、`context.reuse_scanned` event kinds 及 `context` subject_type。

**Acceptance**:
- 中立 docs 契約含 brief-authoring 的 reuse-scan / pack 步驟；`agents/project-pm.md` + `skills/dispatch-brief/SKILL.md` 有指標；CLAUDE.md 無新增。
- `reuse_candidates` 上限生效（fixture 驗證超量截斷）。
- `pmctl context query` / `reuse-scan` 呼叫後 `pmctl trace` 可查到對應 event（含 query term 與 hit 數）。
- **End-to-end**：一份真實 dispatch brief 的 `context:` 含 index-derived anchors（reuse candidate 或 section ref），且該次查詢在 trace 中可回溯。
- Loop-level success metric（與 CC-354 / CC-234 共用）：後續類似任務中，PM 直接引用 anchor 組 brief，main thread 不再重新推論背景。

**Non-goals**: 不動 ranking / 抽詞演算法（觀察使用後再評估）；不做 CC-346 ref 資料層（本票的使用證據是其 resume trigger）；不索引新資料來源。

**Milestone**: v0.5.0 Phase 2（與 CC-354 / CC-234 同屬 memory/context loop 的接線驗收）。

**Priority**: P2.

**Cross-link**: [[CC-239]] (the shipped, unwired capability), [[CC-354]] (knowledge-plane reflex counterpart), [[CC-234]] (write side), [[CC-346]] (resume trigger depends on this ticket's usage evidence), [[CC-237]] (context_hit_v1), `docs/dispatch-brief.md` + `skills/dispatch-brief/SKILL.md` + `agents/project-pm.md` (modification targets).

## CC-341 — pmctl validate: wire handover-validate framework into pmctl ✅ 2026-06-09

**See**: pr:#252

**Problem**: The handover-validator framework (CC-202) was extracted and shipped via PR #170, but the `pmctl validate` subcommand that exposes it was deferred ("→ pmctl validate 串接移 M3") and never landed. MILESTONES v0.5.0 was pointing at the **closed** CC-202 for this remaining wiring, leaving it without an active ticket — surfaced during v0.5.0 follow-up review 2026-06-08.

**Why**: CC-202 is closed (framework done); reusing a closed id for open work is the same divergent-reference hazard the CC-328 → CC-338 renumber fixed. The remaining wiring deserves its own active id.

**Shipped**: `scripts/lib/pmctl-validate.sh` with `pmctl_validate_brief` + `validate/brief` case in `cli/pmctl` + 6-case test suite (`test-pmctl-validate.sh`). Exit-code contract: 0 = valid, 1 = invalid block/metadata, 2 = usage error. Read-only by design (like `pmctl guard check`) — no events written; callers use the exit code to gate dispatch.

**Milestone**: v0.5.0 Phase 2.

**Priority**: P2.

**Cross-link**: [[CC-202]] (framework, closed), [[CC-215]] (pmctl subcommand surface), [[CC-237]].

## CC-360 — pr-gate Route B: migrate executor:claude to pmctl dispatch run 🟢 superseded 2026-06-14

**Superseded by [[CC-373]]**（v0.6.0 executor-router 資料驅動）：claude route 與 codex 對齊由 CC-373 的 manifest `dispatch_route` 自然得出；`pr-gate.sh` 端改呼叫 `pmctl dispatch run --adapter claude` 併入 CC-373 處理。原始範圍保留為 CC-373 sub-scope。

**Problem**: `scripts/pr-gate.sh --executor claude` 輸出 `pr-gate-handover_v1` block，由 `/pr-gate` skill 在 main thread fan-out `Agent(claude-executor)` per reviewer。Route A（codex）則在 `pr-gate.sh` 內直接呼叫 `pmctl dispatch run --adapter codex`。兩條路架構不對稱，skill 端的 fan-out 邏輯增加維護負擔，且與「pmctl 統一派發介面」方向矛盾。

**現況限制（本票未完成前持續存在）**: `scripts/test-e2e.sh` Phase C（pr-gate 結構驗證）固定使用 `--executor codex`，因為 claude route 是 handover-only，在 bash shell 環境下無法自行完成 review 並寫入結果檔。沒有 codex 的環境 Phase C 會自動 SKIP。這是已知架構缺口，不是 bug。

**Why**: `adapters/claude/dispatch.sh` 已建立，`pmctl dispatch run --adapter claude` 介面已穩定。現在可以讓 claude 路徑與 codex 路徑對稱，由 `pr-gate.sh` 直接派發，不需要 skill 介入 orchestration。完成後 `test-e2e.sh --adapter claude` 即可完整跑完 Phase B + Phase C，解除 codex 依賴。

**Requirement**:
- `executor-router.sh`：`dispatch_route_for "claude"` 回傳 `main_thread_bash_background`（與 codex 相同）；新增 `dispatch_via_claude()` 與 `dispatch_via_codex()` 對稱
- `pr-gate.sh`：claude 路徑改為直接呼叫 `pmctl dispatch run --adapter claude --brief-file <path>`；移除 handover block 輸出邏輯
- `scripts/test-e2e.sh`：Phase C 的 codex-only 限制解除，改為使用 `--adapter` 參數所指定的 executor
- `commands/pr-gate.md`：Route B 說明更新，移除 fan-out 步驟；`pr-gate-handover_v1` block 相關說明移除或保留為 legacy-only note
- `scripts/test-pr-gate-profile.sh`：executor-claude-* 測試全面改寫

## CC-362 — feat: add release verification scripts ✅ 2026-06-12

**Done**: Added four release-verification scripts: `release-verify.sh` (four-phase runner — offline prereqs, 54 suites, context smoke, live dispatch + pr-gate), `test-e2e.sh` (live dispatch + pr-gate smoke), `test-release-verify.sh` (unit tests for the runner), and `test-e2e-script.sh` (unit tests for the e2e script). PARTIAL GO exit 3/4 distinguishes an offline-only run from a full release sign-off.

**See**: pr:#268

---

## CC-372 — arch: adapter runner-kind manifest field ✅ 2026-06-14

**Problem**: 一個 adapter 的「執行拓樸」——是 `cli-subprocess`（thin dispatcher，bash/write 經 pm-dispatch hook 把關，如 codex）還是 `host-native`（self-executor，編輯交給 host harness 的 permission，如 Claude 當主線程時的 Agent()）——目前**隱式寫死三遍**：(a) `executor-router.sh` 的 `dispatch_route_for` case；(b) 哪些 `hook-*-guard.sh` 檔存在、以及 `install-hooks.sh` 把哪幾支接進 settings.json；(c) 每個 guard 腳本 header 的 threat-model 敘述。三者要靠人手對齊，新增 executor 時極易漂移。

**Why**: 這一個屬性同時決定 route-kind、write-guard 是「活 hook」還是「只撐 CLI」、以及需不需要 bash-guard。把它宣告一次、其餘衍生，是 [[CC-373]]/[[CC-374]]/[[CC-375]] 能做到「新增 adapter 零核心改動」的前提。`adapter.yaml` manifest 已有 `executor`/`runner_ref`/`dispatch_contract` 欄位，缺的是把 runner-kind 顯式化。

**Requirement**:
- `adapter.yaml` 新增 `runner_kind` 必填欄位，enum：`cli-subprocess` ｜ `host-native`。
- 由 `runner_kind` 衍生（manifest 內顯式記錄或 generator 推導，二擇一，impl 時定）：`dispatch_route`（`main_thread_bash_background` ｜ `agent_executor`）、`write_guard_mode`（`hook` ｜ `cli-only`）、`needs_bash_guard`（bool）。
- `pmctl adapter generate` 與 schema 驗證納入新欄位；既有 codex（`cli-subprocess`）/claude（`host-native`）兩份 manifest 回填且行為不變（純加法、不改現行 dispatch/guard 行為）。
- 測試：兩份既有 manifest 的衍生值與現況一致（codex→route main_thread_bash_background / write_guard hook / bash-guard yes；claude→route agent_executor / write_guard cli-only / bash-guard no）。

**Non-goals**: 不在本票改 router 或 guard 行為——本票只加宣告與衍生值，consumer 改動在 [[CC-373]]/[[CC-374]]。

**Resolution (2026-06-14)**: `runner_kind` 設為衍生值的 single primitive；`dispatch_route`/`write_guard_mode`/`needs_bash_guard` 在讀取時由 `scripts/lib/runner-kind.sh`（映射表唯一所在）衍生，非存進 manifest——解決 Requirement「顯式記錄或 generator 推導二擇一」。保留 per-flag override seam（`runner_kind_resolve_flag` 非空 override 勝過預設）：未來 `cli-subprocess` adapter 若不需 bash-guard 可宣告 `needs_bash_guard: false` 而零核心改動，使「真不對稱必宣告、不由檔案存在推斷」成立。衍生純函式無 PM-host 假設——不論 PM 為 claude 或 codex，驅動任一 executor 都讀同一 manifest、走同一路徑（host-agnostic）。

**Change**: 新增 `scripts/lib/runner-kind.sh`（`runner_kind_valid`/`runner_kind_default_flag`/`runner_kind_resolve_flag`/`runner_kind_manifest_field`）；回填 `adapters/codex/adapter.yaml`（`cli-subprocess`）、`adapters/claude/adapter.yaml`（`host-native`）；`pmctl adapter generate` 模板新增 `runner_kind`（必填 8→9）；`scripts/test-runner-kind.sh`（31 cases）+ 註冊進 `run-all-tests.sh`；`test-pmctl-adapter-generate.sh` 欄位數斷言 8→9。codex/claude dispatch/guard 行為位元不變。

**Dependencies**: 無（v0.6.0 地基，先行）。umbrella [[CC-333]]。

**See**: DECISIONS.md 2026-06-14 v0.6.0-theme-executor-abstraction；umbrella [[CC-333]]。

---

## CC-379 — fix: pr-gate 生成的 brief 過不了 brief-validate.sh ✅ 2026-06-14

**Problem**: 用 `--executor claude` 跑 pr-gate 時，reviewer executor 的第一動作 `scripts/brief-validate.sh`（CC-351）直接 REJECT 生成的 brief，review 從未執行。兩個獨立缺陷：(a) combined brief 的 `acceptance:` 縮排 2 空格，被 `self_verify:` block 吃成子鍵 → 「missing field 'acceptance'」；(b) 三處 brief 模板的 `self_verify` 只用自訂敘述鍵（`file-exists:`/`has-conclusion:`/`frontmatter-final-parity:`），無任何 `- cmd:` 機檢項 → 「file-writing brief self_verify has no 'cmd:' entry」。即整條 claude gate route 的 brief 必被擋。

**Root cause / 漏網**: `scripts/test-pr-gate.sh` 以 stub executor（`CODEX_GATE_*`）攔截 dispatch，從不對「生成的 brief」跑真正的 `brief-validate.sh`，所以 schema 漂移無人察覺。codex route 真實 dispatch 會在 preflight 跑 brief-validate，但實務上少有人跑真 gate 故未爆。

**Change**: `pr-gate.sh` — `acceptance:` 退回 column-0（與其餘兩處模板一致）；三處 `self_verify` 的 `- file-exists: <out>` → `- cmd: "test -f <out>"`（機檢，`dispatch-post-verify.sh` 會真執行，較原敘述更強）。`test-pr-gate.sh` 補三條回歸：對 combined / parallel-reviewer / synthesis 三種生成 brief 各跑一次 `brief-validate.sh` 斷言 exit 0（先紅後綠驗證）。pr-gate 88 綠（+3）、brief-validate 32 綠、post-verify 44 綠。

**Discovered**: CC-372 以 claude executor 跑 pr-gate 時。

**See**: 與 [[CC-351]]（brief-validate 為 executor 第一動作）契約對齊。

---

## CC-380 — fix: gate reviewer 的 `pmctl guard check` 允許項缺絕對/tilde 形式 ✅ 2026-06-14

**Problem**: `pmctl gate run --executor claude` 的 reviewer 是 in-session `Agent(claude-executor)`（pr-gate Route B）。它的乾淨 PATH（`/usr/local/sbin:…:/bin`）不含 `~/.local/bin`，所以 bare `pmctl` 找不到、改以絕對路徑 `/home/<user>/.local/bin/pmctl guard check` 呼叫。但 `install-hooks.sh`（CC-334）只把 **bare** 形式 `Bash(pmctl guard check:*)` 寫進 `permissions.allow`，沒有絕對/tilde 形式；背景 subagent 又無法跳互動式權限詢問 → 沒命中 allow-list 一律自動 DENY。reviewer 正確拒絕繞過被 mandate 的 guard，於是 `.gate-results/*.md` 寫不出（0 bytes）。與 [[CC-291]] 修過的 tilde-vs-absolute dispatch 缺口同類。

**Root cause**: guard 拓樸不對稱（[[guard-role-runtime]] / runner_kind）——codex 的 write/bash guard 由 settings.json 的 PreToolUse **hook 自動執行**（codex 從不主動呼叫 `pmctl guard check`，故不經權限層）；claude self-executes、`write_guard_mode=cli-only`、無活 hook，reviewer brief 要求它**自己呼叫** `pmctl guard check`——那個主動呼叫才會撞權限層。所以「claude 寫不出、codex 可以」正是 runner_kind 那張表的真實後果。

**Change**: `install-hooks.sh` 由單一 bare 形式改寫為 bare + 絕對（`${PMCTL_BIN_DIR:-$HOME/.local/bin}/pmctl`）+ tilde 三形式（空 tilde——bin dir 不在 HOME 下時——以 `map(select(. != ""))` 濾除）。`uninstall-hooks.sh` 鏡像移除三形式（install/uninstall 必對稱，[[CC-368]] 三方漂移教訓）。`test-install.sh` 三條 CC-334 case（fresh / idempotent / uninstall-removes）把 `HOME` 釘進 fixture 並補 abs+tilde 斷言。install 85 / hooks 301 / doctor 40 綠。手改 `~/.claude/settings.json` 已退回，改由 `install-hooks.sh` 寫入驗證（machine-state 單一寫入者）。

**Non-goals**: `doctor.sh` 目前不驗證 CC-334 reviewer perms（既有缺口，非本票造成）——若要 doctor 也檢這三形式，另開票。

**Discovered**: CC-372 以 claude executor 跑 pr-gate 時（[[claude-gate-route-guard-gap]]）。

**See**: 同類 [[CC-291]]（tilde-vs-absolute）、[[CC-334]]（reviewer perms 來源）、[[CC-368]]（install/uninstall/doctor 一致）。

---

## CC-382 — fix+feat: pr-gate 相對 `--output` 產生空結果 + `pmctl gate verify` ✅ 2026-06-14

**Problem**: 以相對 `--output`（或相對 `--cd` 預設）跑 `pmctl gate run` 時，`OUTPUT_FILE` 保持相對路徑並被原樣寫進 reviewer brief 的 `pmctl guard check … --file` 約束、`- new:`、`Only write` 與 `pr-gate-handover_v1` 的 `output_file`。reviewer write-guard（`hook-reviewer-write-guard.sh`）要求**絕對** `file_path`，handover schema 也要求絕對 `output_file` → guard 退非零、reviewer 依硬約束中止寫入 → 0-byte 結果，但 gate 回報成功（silent false-success）。**codex 與 claude handover 兩條路皆中**——先前因只在 claude 路觀察到而誤判為 claude 專屬（[[claude-gate-route-guard-gap]]）；以 codex 重跑同一相對 `--output` 指令同樣產空檔，才定位到是共用根因。

**Root cause**: `OUTPUT_FILE` 只有在省略 `--output` 時才是絕對（預設 `$WORK_DIR/.gate-results/…`）；使用者傳相對 `--output` 時未正規化。先前所有實際呼叫都用預設（已絕對）路徑，故漏網。

**Change**: (1) `pr-gate.sh` 在組 brief 前把 `OUTPUT_FILE` 正規化為絕對（`[[ $OUTPUT_FILE = /* ]] || OUTPUT_FILE="$PWD/$OUTPUT_FILE"`；`$PWD`＝`cd "$WORK_DIR"` 後的工作目錄）。(2) 完整性檢查（非空／恰一條純文字 `Final:`／frontmatter `final:` 與 body 一致／可選釘住 shell verdict）抽成單一真相來源 `scripts/lib/gate-result-verify.sh`，由 codex 同步路線、parallel synthesis、與新增 `pmctl gate verify <file>` 共用；`pr-gate.sh` 保留 source-if-present-else-inline 的 fallback 供 copy-mode（沿用 executor-router 慣例，copy-mode 測試實際走到 inline 版）。(3) 新增 `pmctl gate verify`（exit 0 有效／1 無效／2 用法錯）→ 給 claude host-native（handover 在 pr-gate.sh 之外寫檔）與 codex 同等的寫後檢查，結果可被 pmctl 確認追蹤，**不改 claude 運作模式**。(4) handover schema 文件補上「寫完用 `pmctl gate verify` 確認」。(5) 順帶把 [[CC-372]] 漏鏡像的 `test-runner-kind` 補進 `test-run-all-tests.sh`（55 vs 54 count drift；非 CI job）。

**Verification**: +1 `relative-output-normalized-to-absolute` pr-gate 回歸（斷言生成 brief 帶絕對 guard 路徑）、+5 `pmctl gate verify` 案例。test-pr-gate 89/0、test-pmctl-gate 10/0、test-run-all-tests 14/0、全本機套件綠。以相對 `--output` 重跑：codex gate 產 6481B 結果（GO/approve、`pmctl gate verify` OK）、claude gate（host handover）產 3806B 結果（GO/advise、verify OK）——即先前產 0-byte 的同一指令現在雙路皆寫出可驗證結果。

**Discovered**: CC-372 以 claude/codex executor 收尾 pr-gate 時。

**See**: 同家族 [[CC-379]]（brief-validate）、[[CC-380]]（guard allow-list）；[[guard-role-runtime]]（codex hook-auto vs claude cli-only 的寫後檢查不對稱）；[[CC-372]]（runner_kind）。

---

## CC-383 — arch: `pmctl gate --executor claude` 走獨立 headless `claude --print` ✅ 2026-06-14

**Problem**: `pmctl gate run --executor claude` 走 `agent_executor`：pr-gate.sh 印 `pr-gate-handover_v1` 交棒給 host，由 host(互動 session)或其 spawn 的 `Agent(claude-executor)` 子代理審查。前者等於 host 自我審查(非獨立)、後者撞子代理權限層([[claude-gate-route-guard-gap]])。結果 claude 這條從來不是「獨立 reviewer」。

**Change**: claude executor 改為**同步派發獨立 headless `claude --print` 子程序**(`adapters/claude/dispatch.sh`，獨立 OS 程序、全新 session、自跑 guard-check、自寫結果)，對稱 codex。新增 `dispatch_via_claude`(executor-router lib + pr-gate inline fallback，鏡像 `dispatch_via_codex`，sandbox/approval 接受但不轉發)。pr-gate 三處 dispatch 點(sequential/parallel/synthesis)改用 `dispatch_via_$EXECUTOR` 並 `gate_result_verify` 驗證；引入 `EXECUTOR_IS_SUBPROCESS` 旗標當「未來非 subprocess executor」的接縫。**退場** `pr-gate-handover_v1`：刪 `add_pr_gate_handover_entry`/`emit_pr_gate_handover_block`、修 claude 專屬殘留(post-gate 略過、NO-GO 不 exit)。新增 `--model <id>`(預設 `default`→adapter pinned：codex gpt-5.5 / claude sonnet；可覆寫)。`docs/pr-gate-handover-schema.md` 標 deprecated、`commands/pr-gate.md` 改寫(無 fan-out route)。inline fallback vs lib 加 `inline-fallback-matches-lib` parity 回歸([[CC-382]] 三方 reviewer 點到)。

**Verification**: test-pr-gate 90/0(+claude-subprocess +parity)、test-pr-gate-profile 10/0(handover 測試改 subprocess 斷言 + claude adapter stub)、executor-router 9/0、pmctl-gate 10/0。真實雙路 gate(working tree vs main)：codex GO/advise、**claude 經新 headless 路** GO/advise(sonnet-4-6、8.9KB、`pmctl gate verify` OK)——claude gate 自身即走新路,端到端證實。

**Non-goals / deferred**: runner_kind 的 `dispatch_route_for` 仍回 `agent_executor`(claude 當 host PM 的語意未動)；claude-as-executor=cli-subprocess 的正式 manifest 衍生留給 [[CC-373]]/[[CC-374]]。model tier 對齊(sonnet vs gpt-5.5；是否 opus)協調 review-model CC-323..327。

**See**: [[v0.6.0-claude-executor-headless]]、[[claude-gate-route-guard-gap]]、[[CC-382]](`gate_result_verify`/`pmctl gate verify`)、[[guard-role-runtime]]。umbrella [[CC-333]]。

---

## CC-385 — spike: dispatch 模型統一（brief 由可信代碼落地、executor 獨立子程序消費）✅ 2026-06-15

**完整 scope 在 `docs/spikes/CC-385-dispatch-model-unification-scope.md`**（含兩模型優缺點對照、user 框定、待解 D1–D5、驗收）。

**一句話**: 退場「子代理自寫 brief」路（codex 現況，需 live hook），統一成 `pmctl` 落地 brief → executor 獨立子程序消費（claude 經 [[CC-383]] 已是、`pmctl dispatch run` 既有）。live-hook write-guard 之所以存在，**唯一原因**就是 codex-executor 子代理自寫 brief；統一後 `write_guard_mode` 可一律 cli-only、live-hook 退役、guard 變 runtime-agnostic（[[CC-333]] layer 2 下一步）。

**User 框定（2026-06-14）**: (1) AUTH 預先登入好 → Model A 憑證繼承優勢不計；(2) 主線程已了解專案，分發子代理再重讀 = 重複 token，Model B 去中間人、brief 帶入消化過 context（關 [[CC-366]]）。

**待解**: D1 brief 由誰落地（不可 PM 經 Write，撞 pm-write-guard → pmctl）、D2 context-pack 進 brief、D3 executor 獨立 auth 前提與失敗模式、D4 是否全退子代理路（牴觸 [[dispatch-route-primary]]，或保留為無-CLI runtime 的 fallback）、D5 guard collapse 順序保持 fail-closed。

**Resolution (2026-06-15)**: 採用 Model B 為主路。[[CC-385a]] 真實 e2e 驗證 `pmctl dispatch run --adapter codex` 獨立子程序 exit 0、self-verify pass、無 subagent、無 live hook 觸發、既有 codex auth 足夠。D1 = pmctl 落地 brief；D3 = 預先登入前提確認、未登入 fail-loud（細化於 [[CC-389]]）；D4 = subagent 路保留為無-CLI runtime 明示 fallback、`pmctl dispatch run` 為文件化主路；D5 = codex `write_guard_mode: cli-only` 已落地 `adapters/codex/adapter.yaml`、live-hook 對所有現行 adapter 成 no-op；D2（context-pack）延後 [[CC-366]]。統一**實作**拆為 [[CC-386]]（post-verify 唯一驗證者，keystone）、[[CC-387]]（codex subagent 退場）、[[CC-388]]（claude 一般 executor）、[[CC-389]]（non-interactive 契約）。

**See**: DECISIONS.md 2026-06-15 dispatch-model-B-primary-codex-write-guard-cli-only、[[CC-374]]（地基：write_guard_mode manifest 化）、[[CC-383]]（claude 已此模型）、[[CC-366]]（auto-pack）、umbrella [[CC-333]]。pr:#283

---

## CC-373 — arch: executor-router 資料驅動 ✅ 2026-06-14

**Done**: `resolve_executor`/`dispatch_route_for` 改讀 on-disk manifest（`_er_adapter_manifest` strict-name + 非 symlink + 可讀 → `runner_kind_manifest_field`/`runner_kind_valid`），route 由 `runner_kind_resolve_flag <kind> dispatch_route <override>` 衍生（[[CC-372]] 單一映射表）。allowlist = 「有合法 manifest 的 adapter」，fail-closed。`dispatch_via_codex`/`_claude` 泛化成 `dispatch_via <executor> …`（依名字解析 `adapters/<executor>/dispatch.sh`；`--sandbox`/`--approval` 只對 `cli-subprocess` 轉發、host-native 丟；兩具名函式留薄 shim）。`pr-gate.sh` 三處 `dispatch_via_"$EXECUTOR"` → generic `dispatch_via "$EXECUTOR"`；copy-mode inline fallback 因無 `adapters/` 樹保留硬編碼 codex|claude（標註為刻意降級鏡像）。`pmctl-adapter` 產生器的「register in dispatch_route_for」指引改為「宣告合法 runner_kind 即可路由」。+10 `test-executor-router` cases。

**驗收**: fixture adapter（drop 目錄 + manifest）即可路由，無 `executor-router.sh` 改動——[[CC-376]]/[[CC-377]] 真 adapter 的抽象成敗驗收點。

**Deferred → [[CC-376]]**: `--sandbox`/`--approval`（codex-native）收進統一 `--isolation` 契約；目前由 `runner_kind == cli-subprocess` 衍生轉發，對兩個真 adapter 正確，opencode 的 flag 面由其 dispatch.sh adapter-local 決定（不需核心改動，保住驗收）。

**See**: [[CC-372]]（runner_kind 表）、吸收 [[CC-360]]（claude route 對齊）、[[guard-role-runtime]]（route 值在 pmctl-dispatch 僅作 allowlist+log，不驅動執行分支——故 claude 角色歧義不需在本票於 manifest 解）。

<details><summary>原始 scoping</summary>

**Problem**: `scripts/lib/executor-router.sh` 是 dispatch 抽象的最後一道硬編碼牆。`resolve_executor` 的 case 只收 `codex|claude|auto`、`dispatch_route_for` 只認 `codex`/`claude` 兩個寫死 route，`dispatch_via_codex` 是 codex 專屬 helper。`pmctl dispatch run --adapter <name>` 上層已經完全按名字泛用（header 不變式：唯一 executor 身分是 adapter 名字字串），但 router 仍以兩個常數 enum 把關——掉一個合法 `adapters/<name>/` 進去，router 不認得就 fail-closed 擋掉。

**Why**: 沒有這刀，「新增 executor = 放目錄 + manifest」不成立；CC-291 的「register a role, not (role,runtime)」精神在 dispatch 側無法貫穿。[[CC-376]]/[[CC-377]] 兩個真 adapter 是否需要改本檔，就是抽象成敗的驗收。

**Requirement**:
- `resolve_executor`/`dispatch_route_for` 改為讀 [[CC-372]] manifest：route 取自 `dispatch_route`；允許集合 = 「`adapters/*/adapter.yaml` 存在且 schema 合法」的 adapter 名。
- 泛化 `dispatch_via_codex` → `dispatch_via_adapter`（或確認 `pmctl-dispatch.sh` 已按名字泛用呼叫後移除 legacy helper）。
- **吸收 [[CC-360]]**：claude 路由與 codex 對齊由 manifest `dispatch_route` 自然得出（不再 hardcode 兩個分支）。
- allowlist 維持 **fail-closed**：未解析 / 無合法 manifest / schema 不符 → 拒絕。

**Security/risk gate（hard）**: allowlist 的信任邊界從「程式碼常數」放寬到「磁碟上的 manifest 內容」。必守：adapter 名 strict-identifier `^[a-z][a-z0-9_-]*$`（已有，續守）、manifest schema 驗證、路徑不可逃逸 `adapters/`。過 security-reviewer + risk-reviewer。

**Dependencies**: [[CC-372]]。umbrella [[CC-333]]。

</details>

---

## CC-374 — arch: hook-guard wrapper 收口 ✅ 2026-06-14

**Done**: codex-write/claude-write → 單一 `scripts/hook-executor-write-guard.sh`：read JSON → 由 `agent_type`(`<runtime>-executor`) 取 runtime → strict-name + 非 symlink manifest → `runner_kind`→`write_guard_mode`([[CC-372]] `runner-kind.sh`)。**live-hook vs cli-only 由 manifest 明宣告**（紅線2）：`PM_GUARD_CHECK_CLI`（`pmctl-guard.sh` 驅動 hook 時設）缺席=live context → `write_guard_mode != hook` 時 no-op（claude self-exec 不被 live hook 擋）；CLI 一律強制。CLI 路徑無合法 manifest=fail-closed(deny)，live=no-op。`pmctl-guard.sh` executor pre-write 改解析統一 wrapper。install/uninstall/doctor 改接 + install prune 退場的 per-runtime write-guard（concat 避開 doctor parity scanner）。`hook-codex-bash-guard.sh` 不動（紅線1，`needs_bash_guard`）。drop deprecated `CLAUDE_HOOK_*_WRITE_GUARD` shim（過 v0.5.0）。docs/executor-contract + dispatch-brief 更新。+13 測試（test-hooks runtime-asymmetry block、test-pmctl-guard、test-install prune）。

**[[CC-066]]**：collapse 本身=單一 policy 不再 per-runtime 複製，實質達成宣告式精神（未另抽 policy.yml）。**[[CC-062]] deferred**：bash-guard 未在本票收口（紅線1），其 test matrix 隨之延後。**[[CC-307]] 仍開、re-link [[CC-381]]**：pm 確實 claude-only 是**現況非殘留**（codex-as-pm 不存在），其 codex-as-pm smoke test 受阻於 [[CC-381]]（host-PM-aware）；`pmctl-guard.sh` 的 "claude-only" 註記為準確現況，未刪。

**No-hook 處理（user 提問釐清 2026-06-14）**：三層皆 fail-closed — hook 檔缺/不可執行→`pmctl guard check` `-x` deny；runtime 無 manifest→CLI deny / live no-op；host 無 hook 機制→cli-only 靠 dispatch flow 主動呼叫（doc 載）。**Codex 現已有 hook 機制（可能不完全，user）**→ doc 不再斷言「非 Claude host 無 PreToolUse 等價」；codex-host 接原生 hook 的能力勘查歸 [[CC-381]]。

**See**: [[CC-372]]（runner_kind/write_guard_mode 衍生表）、[[guard-role-runtime]]（codex hook-auto vs claude cli-only）、[[CC-375]]（install 接線由 manifest 衍生，下一張）、[[CC-381]]（host-PM-aware；codex 原生 hook）、umbrella [[CC-333]]。

<details><summary>原始 scoping</summary>

**Problem**: guard 核心 `pmctl guard check --event --role --runtime`（[[CC-291]] 兩軸）已是對的；但外圈 5 個 `scripts/hook-*-guard.sh` wrapper **沒走核心**，各自 source `hook-framework.sh`、各自 `hk_deny_message()`、各自做 path allow/deny。guard 決策因此存在兩份。`hook-codex-write-guard.sh` 與 `hook-claude-write-guard.sh` 實測剝掉執行器名後 ~95% 一模一樣，差異只有 env var 名、log 路徑、字串，加一個真語意差（見下）。

**Why**: 兩份政策會漂移——改一條規則要改 N 個檔。收成單一 role-參數化 wrapper、決策委派回 `pmctl guard check`，才讓 guard 真正 runtime-agnostic，新 adapter 不必各自手刻 guard。

**Requirement**:
- codex-write / claude-write 合成單一 `hook-executor-write-guard.sh`，行為由角色 + [[CC-372]] manifest 參數化；wrapper 只做 I/O（讀 hook JSON、寫 audit log、回 exit code），政策決策呼叫 `pmctl guard check`。
- **吸收 [[CC-066]]**（hook allowlist 抽成宣告式 policy）、**[[CC-062]]**（codex-bash-guard allow/deny test matrix fixtures）。
- **收尾 [[CC-307]]**：移除「pm = claude-only」殘留（deprecated `--profile pm` alias 的 `runtime=claude` hardcode 註記、`pmctl-guard.sh` 的「currently claude-only」說明、補 codex-as-pm dispatch smoke test）。

**不可壓平的兩個真不對稱（驗收紅線）**:
1. `hook-codex-bash-guard.sh`（447 行）是真 codex-only（codex 執行 bash 經此把關；claude 的 bash 走 harness permission）——它由 `needs_bash_guard` 旗標決定套不套，不是無條件套給所有 adapter。
2. 「live PreToolUse hook」（codex-write，thin dispatcher 只准寫 brief temp）vs「不接 settings.json、只撐 `pmctl guard check` CLI 面」（claude-write，self-executor）是**安全相關 bit**，收口後必由 manifest `write_guard_mode` **明宣告**，不能退化成「靠檔案存不存在」隱式表示。

**Security/risk gate（hard）**: 動的是安全邊界，過 security-reviewer + risk-reviewer。

**Dependencies**: [[CC-372]]。關聯 [[CC-258]]（pm-write-guard policy revision）。umbrella [[CC-333]]。

</details>

---

## CC-375 — install: hook 接線由 manifest 能力旗標衍生 ✅ 2026-06-15

**Done（CC-385a 縮範圍後）**: `install-hooks.sh` 改為掃 `adapters/*/adapter.yaml`，對每個 `needs_bash_guard=true` adapter 從 `adapters/<name>/bash-guard.sh` 接線（manifest-derived，`runner-kind.sh` 衍生）；退場 `hook-executor-write-guard.sh` 與 `hook-codex-bash-guard.sh`（scripts/ 形式）的 PreToolUse 接線（prune 進 jq retired 清單）。`doctor.sh` 同步：新增 `adapter_bg_present()`、stale 偵測擴展到 adapters/ 樹、`check_hooks()` 走 manifest 掃描。`hook-codex-bash-guard.sh` 加 symlink 解析（從 `adapters/codex/bash-guard.sh` 呼叫時正確找 `scripts/lib/`）。51 個 hooks 測試全過。三方一致（install/uninstall/doctor）。

**See**: [[CC-374]]（前置）、[[CC-385a]]（spike，決定縮範圍）。pr:#281

---

## CC-386 — arch: pmctl post-verify 成為 executor 結果的唯一驗證者 ✅ 2026-06-15

**Problem / 目標**: executor 全面轉獨立子程序（Model B，[[CC-385]] 決策）後，結果可信度不能再倚賴 executor 自報的自然語言結論——獨立子程序可能 exit 0 卻中途截斷、trace 不完整、或 self_verify 從未真跑。pmctl 必須成為唯一的結果裁決者。

**Requirement**:
- `pmctl dispatch run` 的 post-verify 強化為三重機檢，全過才判 PASS：
  - (1) executor process **exit code** 為 0（pmctl-dispatch.sh 既有：非零短路 failed、不跑 post-verify）。
  - (2) **trace 結構完整性**：`latest.jsonl`（經 footer `trace:` 以 `--jsonl` 傳入）存在、非空、`jq` 串流計數證明**至少解析出一個 JSON value**（抓截斷/orphan/whitespace-only），含 containment guard。**範圍切割**：per-adapter **語意**終止事件（codex `turn.completed` / claude `.result`，shape 不同）**明示延後 [[CC-389]]**——本票只做 adapter-agnostic 結構驗證（architecture-reviewer 背書此分層）。
  - (3) **self_verify 的 `- cmd:` 實跑**全綠（沿用 [[feedback_self_verify_format]]：機檢項 post-verify 真執行）。
- exit 0 但 trace 結構殘缺（背景 orphan、JSONL 截斷、whitespace-only）→ 判 **FAIL** 並透出明確訊息，不得靜默成功。
- 對齊既有真相來源 [[CC-382]] `scripts/lib/gate-result-verify.sh`（gate 結果完整性，異 artifact）——不重造。
- 測試矩陣涵蓋：完整 trace PASS、截斷 FAIL、whitespace-only FAIL、空 FAIL、supplied-missing FAIL、containment escape 拒、valid-but-non-terminal 結構 PASS（語意延後 CC-389）、footer `trace:`→`--jsonl` threading 勝過 stale latest.jsonl。

**驗收**: 一次真實 dispatch run 的 trace 被三重機檢判定；人為截斷 trace 後同一 run 由 PASS 翻 FAIL。

**Resolution (2026-06-15)**: 三重機檢落地。(1) exit code 已由 `scripts/lib/pmctl-dispatch.sh` 把關（exit≠0 → 短路標 failed、不跑 post-verify）；本票把 footer 的 `trace:` 路徑解析為 `_run_trace` 並以新 `--jsonl` 旗標傳入 post-verify。(2) `scripts/dispatch-post-verify.sh` 新增 **trace 結構完整性**：`--jsonl`／`latest.jsonl` 加 containment guard（real path 須在 `.agent-trace` 內）、非零檢查、並以 `jq -n 'reduce inputs ...'` 串流計數證明**至少一個 JSON value 被解析**（截斷／orphan→parse error 無計數→FAIL；whitespace-only→0→FAIL；真實→≥1→PASS）。**gate 抓出**：初版只用 `-s` + `jq empty`，但 `jq empty` 對 whitespace-only 也 exit 0（silent false-PASS）——full-tier gate 的 critic/qa-tester/risk-reviewer 三方同抓，改為計數 ≥1 並補 whitespace 回歸後修復。severity 對齊 `latest.stderr`：supplied `--jsonl` 缺檔 fail-closed（每次真實 dispatch 都帶）、positional 預設 `latest.jsonl` 缺檔容忍（legacy/fixture back-compat，`.last` 契約仍管）。(3) `self_verify - cmd:` 既有不動。**範圍切割**：per-adapter **語意**終止事件偵測（codex 的 `turn.completed` 事件 vs claude 的單一 `.result` 物件，shape 不同）歸 [[CC-389]] non-interactive 契約，本 keystone 只做 adapter-agnostic 結構檢查。與 [[CC-382]] `gate-result-verify.sh` 對齊：那是 gate 結果（markdown `Final:`）這是 dispatch trace（JSONL），異 artifact、未重造。+11 post-verify 測試（codex-shape 完整 PASS／claude-shape 單物件 blob PASS／截斷 FAIL／**whitespace-only FAIL**／空 FAIL／supplied-missing FAIL／default-absent 容忍／override-outside 拒／symlink-outside 拒／per-run override PASS／**valid-but-non-terminal 結構 PASS**＝語意延後 CC-389）＋ 1 pmctl-dispatch threading 測試（footer `trace:`→`--jsonl` 勝過 stale latest.jsonl），既有測試零回歸。

**Gate（full-tier，sequential，2026-06-15）**: R1 NO-GO — critic/qa/risk 三方同抓 `jq empty` 對 whitespace-only false-PASS → 改 `jq -n 'reduce inputs'` 計數 ≥1 value + 補 whitespace 回歸。R2 NO-GO — qa（footer-threading 缺直接測試）、risk（結構-only 放過 valid-but-non-terminal trace）、critic（票面 spec 仍寫 turn.completed 與 impl 落差）。**Path 1 裁決（user 2026-06-15）**：維持結構-only、語意終止事件留 [[CC-389]]（architecture-reviewer 背書此分層）；補 footer-threading 測試 + valid-but-non-terminal 結構 PASS 鎖定 + 票面 spec 對齊 + **[[CC-387]] 重排序為相依 [[CC-389]]**（退 codex 舊路前語意驗證須先到，閉合 risk 的定序顧慮）。**User risk override**：接受 CC-386 以結構-only 出貨、parseable-but-semantically-incomplete trace 在 [[CC-389]] 前可能 PASS。

**Dependencies**: [[CC-382]]（gate-result-verify 既有真相來源）。所有後續退場票（[[CC-387]]）的前置——先有可信驗證才退舊路。umbrella [[CC-333]]。

**See**: pr:#284。後續 [[CC-389]]（per-adapter 語意終止事件）、[[CC-387]]（依賴本票退 codex 舊路）。

---

## CC-387 — arch: codex 子代理自寫 brief 路退場 ✅ 2026-06-15

**Problem / 目標**: live-hook write-guard 存在的唯一原因是 `codex-executor` 子代理用 host Write 自寫 brief。[[CC-385a]] 已證 `pmctl dispatch run --adapter codex` 獨立子程序 exit 0。把 pmctl 路定為 codex **唯一** routine 路後，codex 不再有任何 routine 路持有 brief-write authority，live-hook 對 routine 全成 no-op。

**Requirement**:
- `pmctl dispatch run --adapter codex` 為 codex 唯一文件化 routine 路；`Agent(codex-executor)` 自寫 brief 降為「無 headless CLI runtime」明示 fallback（codex 有 CLI 故實質退役）。
- 同步操作文件不再呈現 subagent 自寫為一般路：`agents/codex-executor.md`（§Dispatch / §When NOT to use）、`skills/dispatch-brief`、`agents/project-pm.md` dispatch 段。
- 退場後確認 `hook-executor-write-guard.sh` live 分支只在明示 fallback 觸發、routine 路全 no-op，文件化並保持 **fail-closed**（cli-only 路徑無合法 manifest 仍拒）——收尾 [[CC-385]] D5。
- 不刪 `hook-executor-write-guard.sh` 腳本本體（fallback 仍需）；只退場其 routine 角色。

**驗收**: codex routine dispatch 走 pmctl、無 live hook 觸發、[[CC-386]] post-verify 判 PASS；fallback 路仍由 live-hook 把關（保留回歸）。

**Dependencies**: [[CC-386]]（結構驗證）、**[[CC-389]]（語意終止事件驗證——risk gate 2026-06-15 要求：退 codex 舊路前，驗證器不可只有結構檢查、須能判 trace 語意是否真正完成；故 CC-389 先於本票）**、[[CC-375]]（hook 接線已 manifest 化）。umbrella [[CC-333]]。

**Resolution (2026-06-15)**: 兩相依（[[CC-386]] 結構驗證、[[CC-389]] 語意終止驗證）皆先到，D5 的 manifest flip（codex `write_guard_mode: cli-only`）已隨 [[CC-389]] PR #285 落地，故本票為**正式退場 + 過時 guard 文件修正 + 回歸鎖 + 真實驗收 + 收尾**，無 core/manifest 程式碼變更。(1) **退場敘述定案**：`docs/dispatch-brief.md`、`agents/codex-executor.md` 收緊為「`pmctl dispatch run --adapter codex` 為唯一 routine 路；`Agent(codex-executor)` 為明示 fallback 且**不**自寫 brief（main thread 預寫、codex-executor 無 Write tool），任何 codex 路皆無 subagent 持有 brief-write authority」；`agents/project-pm.md`、`skills/dispatch-brief` 既已對齊（direct-Bash 預設、main thread 寫 brief），未改。(2) **過時 guard 文件修正**（`docs/executor-contract.md`）：guard 表把 `hook` mode 從「e.g. codex」改為「無 shipped adapter、保留給 no-CLI 自寫 fallback class」並補上「cli-subprocess + 顯式 override（codex）亦屬 cli-only」一列；「two dispatch entrypoints」段刪去「codex-executor agent 路 brief-write 由 live PreToolUse hook 把關」之**過時錯述**，更正為 cli-only → live hook no-op、實由 `pmctl guard check` 把關。(3) **回歸鎖**：`scripts/test-hooks.sh` 加註記說明 `write_guard_mode=hook` live-enforce 分支非死碼（unit-locked by `test-runner-kind.sh`），倖存於 no-CLI 自寫 fallback class，禁止簡化移除。(4) **真實驗收**：`pmctl dispatch run --adapter codex` 連續 6 次完整 dispatch（workspace-write）全綠——獨立子程序 exit 0、**無 live write-guard hook 觸發**、[[CC-386]] 三重機檢 PASS（結構 12 records + 語意 `turn.completed` + self_verify `cmd:` 實跑）。**附帶發現（不在本票範疇）**：codex 0.139.0 在本 session 最初 1–2 次冷啟動有 transient trace-capture flake（wrapper 繼承 FD 的 `.jsonl` 偶失）；經 8 次 run 證**非確定性**、且 **fail-closed 安全**（trace 缺失時 post-verify 正確判 FAIL，不誤判 PASS），與既有「codex silent startup 已知 transient」一致——歸後續 adapter 強化票，未塞入本 PR。

**See**: pr:#286。閉合 [[CC-385]] D5（guard collapse follow-through）。

---

## CC-389 — arch: non-interactive executor 契約 spec ✅ 2026-06-15

**Problem / 目標**: Model B 全面上路後，所有 executor 共享同一隱性契約，但它尚未被寫成單一可依循的 spec。第三方 adapter（[[CC-376]]/[[CC-377]]）需要一份明確基準，否則每個 adapter 各自詮釋「怎樣算正確落地」。

**Requirement**: 一份 `docs/` 契約文件釘死 Model B executor 的共同要求：
- brief 由 **pmctl 落地**（非 agent 經 Write）、executor 為**獨立子程序**、需 **headless CLI**。
- **auth 前提為預先登入**；未登入則 **fail-loud**（不靜默成功）；`doctor` 加 per-executor auth 探測。
- 輸出契約 = `.agent-trace/latest.last`；結果驗證 = [[CC-386]] 三重機檢（pmctl 為唯一裁決者）。
- **fallback policy**：無 headless CLI 的 runtime → subagent 路（live-hook guard 唯一存活理由），明示而非預設。
- **輸出格式優先串流**：executor CLI 同時支援串流與單一 blob 時，預設選串流（逐事件 JSONL）以利逐條確認（user 偏好，見 [[feedback_prefer_streaming_executor_output]]；claude 落地於 [[CC-388]]）。
- model-alias、isolation 翻譯沿用既有 adapter 慣例（[[CC-292]]）。

**驗收**: [[CC-376]]/[[CC-377]] 落地以本契約為基準；契約所列每條要求都有對應的 adapter 自檢或 doctor 檢查。

**Dependencies**: [[CC-386]]（驗證機制）。為 [[CC-376]]/[[CC-377]] 前置基準、[[CC-387]] 退舊路前置（語意驗證須先到）。umbrella [[CC-333]]。

**Resolution (2026-06-15)**: 契約落地 + 補上 [[CC-386]] 延後的語意層。(1) `docs/executor-contract.md` 新增「Non-interactive executor contract (Model B)」專章，釘死 6 項要求（pmctl 落地 brief、獨立子程序、headless CLI、auth 前提預先登入＋fail-loud、輸出契約＋三重機檢、無-CLI fallback subagent、串流優先）＋ per-adapter `terminal_event` 對照表。(2) **語意終止事件驗證**：`adapters/{codex,claude}/adapter.yaml` 宣告 `terminal_event`（codex `turn.completed`／claude `result`）；`scripts/dispatch-post-verify.sh` 新增 `--terminal-event` 旗標，以 `jq --arg ev` 計數 `.type == $ev` ≥1 證明語意完成，疊加於結構檢查之上（結構 FAIL 先短路）；predicate shape 固定為 `.type == $ev`、值經 `--arg` 注入（manifest 不得注入任意 jq）。flag-gated：無旗標的 positional/legacy caller 維持 structure-only（back-compat，保留既有 non-terminal 結構 PASS lock）。`scripts/lib/pmctl-dispatch.sh` 由 adapter manifest 讀 `terminal_event`（canonical `runner_kind_manifest_field`，防禦性 source）並 thread 進 post-verify。(3) **doctor auth 探測**：`scripts/doctor.sh` `check_codex`/`check_claude` 對 present-but-unauthenticated 的 executor CLI 改 **fail-loud**（憑證檔＋env 啟發式、非互動、不跑 CLI、不讀密文）；binary 缺維持 WARN。+8 測試（post-verify 5／pmctl 1／doctor 2），全套件綠、shellcheck 乾淨。**Gate（full-tier，2026-06-15）**：Final GO — critic advise（low：`.last` 措辭已補述 `.jsonl` 為機器驗證 load-bearing），qa-tester pass、architecture approve、security pass（`--arg` 注入安全）、risk pass（語意缺失 fail-closed、legacy structure-only 保留）。

**See**: pr:#285。後續 [[CC-387]]（依本票語意驗證退 codex 舊路）、[[CC-376]]/[[CC-377]]（以本契約為落地基準）。

---

## CC-394 — arch: 退場 agents/claude-executor.md（claude 收斂為 adapter-only） ✅ 2026-06-17

**Problem**: Model B（[[CC-385]]）後，claude 的 canonical 執行路是 headless `claude --print` 子程序（`adapters/claude/`，[[CC-388]]/[[CC-392]]）。`Agent(claude-executor)` 已被 DECISIONS 2026-06-13 明訂降級為「Claude 當 PM host 時的 same-host 最佳化」，pm.md Route B 進一步把它收成「`claude` CLI 不在 PATH 時」的窄 fallback。

**Why 退場**:
1. **零能力缺口** — claude-executor 與 claude adapter 做完全一樣的事，唯一觸發是「binary 缺席」；對比 codex-executor 補的是 bash route 拒絕的 `danger-full-access`（真功能）。
2. **這正是 [[CC-333]] 要拆的耦合** — `Agent()`-spawn = Claude-runtime 專屬執行模型；Model B/adapter 的重點就是讓執行成為與 host 無關的 CLI 子程序。
3. **持續維護稅** — [[CC-335]] 即因 trio 引用藏在此檔導致 gate 連兩輪 NO-GO；每次契約改動都要維持此檔一致。
4. **目標形狀已存在** — opencode（[[CC-376]]）就是 adapter-only、無 Agent；本票讓 claude 對齊它。

**決策前置**: 確認無「Claude 為 host、但 `claude` CLI 二進位缺席、卻仍需執行 claude brief」的真實環境（repo 哲學 [[CC-389]] 傾向 fail-loud 而非默默降級）。唯一反論 = 重視 same-host 免 spawn 子程序的最佳化（DECISIONS:245）；若採納則改為「保留但文件收斂成單一觸發條件」。

**退場 checklist**: 刪 `agents/claude-executor.md`；`pmctl-guard.sh` 的 `executor(claude)` 慣例分支；`install-hooks.sh`/`uninstall-hooks.sh`/`doctor.sh` 相關接線；`test-pmctl-guard.sh`/`test-install.sh`/`test-hook-framework.sh` 案例；文件收斂（`commands/pm.md` Route B、`docs/executor-contract.md` profiles、`docs/dispatch-brief.md` §Fallback）。

**Sequencing**: 機械性、零能力損失，可先於 [[CC-395]]。umbrella [[CC-333]]（in-session Agent executor 層）。

**See**: pr:#293

**See**: [[CC-395]]（codex 對稱退場）、[[CC-333]]、[[CC-388]]、[[CC-376]]。

---

## CC-395 — arch: 退場 agents/codex-executor.md + 決定 danger-full-access 去留 ✅ 2026-06-17

**See**: pr:#294

**Problem**: 對稱 [[CC-394]]，把 codex 也收斂為 adapter-only。`Agent(codex-executor)` 現存的唯一獨有能力是 `danger-full-access`（`isolation_level: none`）——`handover-validate.sh:330` hard-reject `none` 於 `main_thread_bash_background`（opencode 除外），只允許經 `agent_executor` route = 人為明示 `Agent(codex-executor)` spawn。退 agent 前必須先拍板 full-access 去留。

**DECISION (2026-06-17): 選 (A) — 砍掉 codex full-access。** codex 最高權限收斂為 `workspace-write` 真沙箱；任何 codex brief 帶 `isolation_level: none` 在**所有 route** fail-loud REJECT。決策依據見下方校正分析。未來若真有 full-access 需求，再以獨立明示旗標（原 (b) 形狀）deliberate 重新引入；現在不為零使用的能力背安全債。

**校正分析（取代原 (a)/(b) 二選一框架）**:
- **codex full-access 非 load-bearing**：codex 預設 `workspace-write` → `--sandbox workspace-write` 是可無人值守寫檔的真沙箱，正常 brief 完全不需要 `none`。砍掉 `none` 不影響任何現行 dispatch。
- **opencode 的 `none` 才是 load-bearing，不能砍**：opencode 無細粒度沙箱，`none` → `--dangerously-skip-permissions` 是它**唯一**的無人值守模式（CC-376）。所以「codex 擋 / opencode 放」的不對稱是**有原則的**（依 executor 是否具沙箱預設），不是要消除的 smell。本票只動 codex，opencode 不動。
- **零實際使用**：`git log -S "isolation_level: none"` 掃全史，`none` 只出現在退場/sweep/test commit，**無任何真實 brief 用過 codex full-access**。
- **Agent 閘是 Model A 遺產**：full-access 綁 `Agent(codex-executor)` 的設計源於子代理自寫 brief 時代；Model B（[[CC-385]]）後所有 brief 由 main thread 撰寫，此閘的原始威脅模型已位移。
- **claude 已在 A end-state**：[[CC-394]] 退 claude-executor 後，claude full-access 已無路可達（bash route reject `none` + 無 Agent route），且 claude `workspace-write` → `acceptEdits` 同樣是安全無人值守預設。決策 A 等於讓 codex 與 claude 現狀對齊——最終只剩 opencode 保留 `none`。

**退場 plan（A 形狀，零能力損失，同 [[CC-394]] 機械性）**:
1. **full-access 收口**：`handover-validate.sh` 將 `none` 對 codex 的 reject 從「僅 bash route」擴到**所有 route**（含 `agent_executor`）；codex `isolation-map.yaml` 移除 `none` 條目；訊息指向「codex max isolation = workspace-write」。opencode 的 `none` 豁免保留不動。實作可沿用現有 executor-name 特例，或更乾淨地由「adapter 是否具 sandboxed level」推導（thin-slice 不強制）。
2. **退 agent 檔**：刪 `agents/codex-executor.md` ＋ guard role-model 的 executor(codex) 慣例分支 ＋ install/uninstall 接線 ＋ `test-pmctl-guard`／`test-install`／`test-hook-framework`／`test-hooks` 相關案例。
3. **文件收斂**：`commands/pm.md`（移除 full-access 經 Agent fallback 的指引）、`docs/dispatch-brief.md` §Fallback（移除 full-access 列＋`agent_executor` full-access 描述）、`docs/executor-contract.md`、`docs/CONCEPTS.md`、`docs/review-model.md`。
4. **回歸鎖定**：新增 codex `none` 在所有 route 被 REJECT 的測試；opencode `none` on bash route 仍 accept 的既有測試保留。

**Sequencing**: 排在 [[CC-394]] 之後（已 MERGED main 185adfc）。決策已拍板，ready to implement。security/risk hard gate：本案是**收窄**權限（移除 full-access 出口），非放寬，過 gate 風險低。umbrella [[CC-333]]。

**claude 對稱（本票一併收）**: 收口邏輯改為「`none` 僅 opencode 允許，其餘 executor 全 route REJECT」，故 claude 的 `none`（bypassPermissions）亦同步變成全 route 明確拒絕（先前僅 bash route reject、agent route 未明確且已無 claude agent）。語義更清、與 codex 對稱，零行為風險（claude full-access 本就不可達）。

**衍生**: 退場工作中發現 operational 檔（scripts/adapters/cli/core）殘留設計沿革票號註解違反 No-CC-in-operational 慣例，拆 [[CC-396]] 專責清理（明確排除測試 fixture data 與 ID 格式範例）。

**See**: [[CC-394]]（claude 對稱、先行、已 MERGED）、[[CC-333]]、[[CC-385]]（Model B 使 brief 全由 main thread 撰寫，鬆動 Agent 閘）、[[CC-376]]（opencode load-bearing `none` 來源）、[[CC-387]]、[[CC-391]]（無 Agent 後 lifecycle 簡化）、[[CC-396]]（衍生清理票）。

---

## CC-397 — refactor: extract pmctl_dispatch_run executor tail + persist footer durably ✅ 2026-06-17

**Closed 2026-06-17**: Implemented Phase 7c-1 groundwork for detached-supervised dispatch. `pmctl_dispatch_run` keeps the existing guard/config preflight and delegates the post-preflight executor tail to `pmctl_dispatch_execute_tail`, preserving the foreground transition order and exit-code behavior. Adapter stdout footer capture now writes `<work_dir>/.agent-trace/<run_id>.footer` durably instead of a deleted `mktemp`, while post-verify still receives the footer-derived explicit `--last`/`--jsonl`/`--stderr` paths. No supervisor, detached lifecycle, start/wait command, or run schema surface was added.

**Problem / 目標**: [[CC-391]] 的 detached-supervised dispatch 軸需要 supervisor 之後重用 foreground dispatch 已驗證的 executor tail：adapter invocation → footer parse → verifying → post-verify → terminal state + [[CC-225]] durable record。現況 tail inline 在 `pmctl_dispatch_run`，且 footer 只存在於 `mktemp`，parse 後立即刪除；若未來 supervisor 在 adapter exit 後、post-verify 前崩潰，會丟失 [[CC-305]] explicit-path handoff 的 per-run artifact paths。

**Requirement**:
- Extract post-preflight tail into one shared internal function, behavior-identical for foreground dispatch: pending → dispatched → adapter pipeline → verifying → failed/ok, same exit propagation, same post-verify stdout/stderr, same record write semantics.
- Replace the ephemeral footer temp file with durable `<work_dir>/.agent-trace/<run_id>.footer`; create `.agent-trace/` defensively before `tee`; do not delete the footer.
- Preserve the explicit-path contract: footer `trace:`/`last:`/`stderr:` are still parsed and passed to `dispatch-post-verify.sh` as `--jsonl`/`--last`/`--stderr`; post-verify does not read `latest.*` when explicit paths are present.
- Keep Phase 7c-1 scoped to groundwork only: no `--lifecycle`, no supervisor process, no detach/start/wait command, no `run.schema.json` change.

**Verification**: `scripts/test-pmctl-dispatch.sh` covers durable footer persistence with per-run artifact paths and direct invocation of the extracted tail, including the foreground lifecycle order `pending,dispatched,verifying,ok`.

**See**: [[CC-391]], [[CC-225]], [[CC-305]], [[CC-333]].

---

## CC-398 — feat: dispatch lifecycle axis — `--lifecycle detached` + synchronous supervisor boundary ✅ 2026-06-17

**Closed 2026-06-17**: Implemented Phase 7c-2a of the detached-supervised dispatch axis. Adds the dispatch-time lifecycle choice without true process detachment yet, so the security boundary lands and gates on its own before the `setsid`/`nohup` mechanics (7c-2b, [[CC-399]]).

**Problem / 目標**: [[CC-391]] spike (partial-adopt) 的遷移順序 D7 steps 3–4：在真正 detach 之前，先把 lifecycle 作為派發當下的選擇引入、把 supervisor 邊界立起來、並讓「supervisor 不能成為 guard 旁路」這條紅線可獨立審查。eligibility 由 [[CC-372]] `runner_kind` 推導（非 manifest 欄位），符合 [[CC-391]] modeling red line。

**Requirement / 實作**:
- `runner_kind_detach_eligible <runner_kind>` in `scripts/lib/runner-kind.sh` (cli-subprocess→0 eligible, host-native→1, unknown→2; exported).
- `pmctl dispatch run --lifecycle foreground|detached` parsing (consumed by pmctl, never forwarded to the adapter) + `dispatch.lifecycle` config key → `PM_CFG_LIFECYCLE` (`scripts/lib/pmctl-config.sh`); precedence flag > config > foreground.
- `pmctl_dispatch_detach_eligible` rejects ineligible adapters BEFORE any executor launch; detached + `--print-cmd` and detached + auto-pack rejected pre-launch.
- Factored `pmctl_dispatch_resolve_adapter` (name + symlink/containment + route allowlist) and `pmctl_dispatch_validate_brief` (brief-validate) as shared preflight steps used by both `pmctl_dispatch_run` and the supervisor; existing error messages preserved.
- `pmctl_dispatch_write_runspec` writes a durable `<work_dir>/.agent-trace/<run_id>.runspec` (schema v2): `--cd`/`--brief-file` as trusted scalars + only the non-core adapter args as base64 passthrough (atomic mktemp+mv). `pmctl_dispatch_run_detached` splits the core args out of forward, records them as scalars, and asserts the forwarded brief equals the guarded brief.
- New `scripts/dispatch-supervisor.sh`: reads `--run-spec`, derives REPO_ROOT from its own path, rejects passthrough args smuggling a second `--cd`/`--brief-file`, RE-RUNS the full preflight (resolve_adapter → validate_brief → guard) on the SAME brief it will execute, rebuilds the adapter command from trusted scalars, then calls `pmctl_dispatch_execute_tail`. Not a bypass door — a tampered run-spec cannot reach an executor pmctl would refuse, nor execute a brief different from the one guarded/validated.
- 7c-2a scope only: supervisor invoked SYNCHRONOUSLY; no `setsid`/`nohup`, no `dispatch start`/`wait`, no `run.schema.json` change.

**Gate (full tier)**: first run NO-GO (5/5 reviewers) — supervisor skipped `brief-validate.sh` and the run-spec split trust between guarded scalars and opaque forward args (guard one brief, execute another). Fixed by run-spec v2 (trusted core scalars + non-core passthrough), supervisor brief-validate, smuggle rejection, and detached+auto-pack rejection. The medium log-hygiene finding was an artifact of the codex sandbox's own landlock denial on `~/.claude/logs` (our `hk_audit` is already best-effort silent), not a code defect.

**Verification**: `scripts/test-dispatch-lifecycle.sh` (21 cases in 7c-2a; extended in [[CC-399]] 7c-2b): detached is the built-in default for eligible adapters after [[CC-399]] (bare invocation returns run_id); foreground-explicit writes no run-spec; detached behavior-equivalent (+v2 run-spec, ok record); adapter-failure exit propagation; invalid `--lifecycle`; detached+`--print-cmd`; detached+auto-pack; ineligible adapter rejected pre-launch (no executor run); eligibility unit gate over cli-subprocess/host-native/missing/unknown; `dispatch.lifecycle=detached` config; flag beats config; supervisor rejects non-routable + path-traversal adapters, missing run-spec, malformed brief (before launch), and smuggled `--brief-file`. Existing `test-pmctl-dispatch.sh` / `test-dispatch-record.sh` / `test-runner-kind.sh` unchanged-green (foreground path identical).

**See**: [[CC-391]], [[CC-397]], [[CC-372]], [[CC-225]], [[CC-399]], [[CC-333]].

---

## CC-399 — feat: detached dispatch true detachment + `pmctl dispatch wait` ✅ 2026-06-18

**Closed 2026-06-18**: Implemented true detached dispatch for the 7c-2b supervisor slice. `pmctl dispatch run --lifecycle detached` now writes the run-spec, records the initial pending/dispatched FSM rows, launches `scripts/dispatch-supervisor.sh` via `setsid nohup ... &` (falling back to `nohup ... & disown` where `setsid` is unavailable), writes `.agent-trace/<run_id>.supervisor.pid` as advisory diagnostics, redirects supervisor output to `.agent-trace/<run_id>.supervisor.log`, prints only the `run_id`, and exits 0 without waiting for the adapter.

`pmctl dispatch wait <run_id> --cd <work_dir>` was added as the reattach surface. It requires explicit `--cd`, validates the run id, times out with 124, and exits with the recorded exit code once completion is signalled. **Wait completion authority**: the authoritative signal is the supervisor sentinel at `/tmp/pm-supervisor-sentinel-<run_id>-<nonce>` (not the workspace dispatch record); the nonce is generated by the parent, stored in a per-user private directory (mode 700), and passed to the supervisor via env (unset before exec-ing the adapter). If the sentinel key is absent (e.g., after a prior successful wait or temp cleanup), dispatch wait falls back to the durable `.dispatch-results/<run_id>.md` record for observability. Security gate decision for this slice: the detached supervisor inherits the same environment as foreground dispatch; no env unset/allowlist layer is added because the deployment uses login-authenticated CLIs rather than API keys in env.

**Problem / 目標**: Phase 7c-2b of [[CC-391]] — turn the 7c-2a ([[CC-398]]) synchronous supervisor into a genuinely detached one (D7 step 5). The boundary and run-spec already exist; this slice adds true process detachment and the reattach/wait surface.

**Requirement**:
- Launch `scripts/dispatch-supervisor.sh` via `setsid`/`nohup` with stdio redirected to a per-run supervisor log; the supervisor must survive the calling shell/session exiting and own + reap the executor child.
- `pmctl dispatch run --lifecycle detached` returns a `run_id` immediately, after writing `pending`/`dispatched`, instead of blocking on the tail.
- `pmctl dispatch wait <run_id>` resolves the terminal outcome via the supervisor sentinel (nonce-bearing `/tmp` path, authenticated by supervisor); falls back to the durable `.dispatch-results/<run_id>.md` record ([[CC-225]]) when the key is absent; identity is `run_id`, PID is advisory only.
- Security gate: inherit the foreground dispatch environment unchanged for detached supervisors; no env unset/allowlist layer in this deployment because executor CLIs use login auth, not API keys in env.
- Acceptance: one real eligible adapter detached run returns a run_id before completion, the original thread exits, and `dispatch wait` reports the terminal outcome from durable state with no orphaned child.

**Sequencing**: after [[CC-398]]; then 7c-3 = [[CC-238]] (generic supervisor timeout + per-child attribution, retire the pr-gate fan-out one-off). HARD security+risk gate passed for the env inheritance decision above.

**See**: [[CC-391]], [[CC-398]], [[CC-225]], [[CC-238]], [[CC-333]], `docs/spikes/CC-391-detached-supervised-dispatch-scope.md`, pr:#298.

---

## CC-388 — arch: claude adapter 作為一般 implementation executor ✅ 2026-06-15

**Problem / 目標**: [[CC-383]] 證明了 claude 獨立 headless `claude --print` 於 **gate route**，但「一般 implementation 派發」軸尚未驗證對稱。Model B 全面上路要求 `pmctl dispatch run --adapter claude` 能跑一般 implementation brief，非僅 gate 特例。

**Requirement**:
- 驗證並補齊 `pmctl dispatch run --adapter claude --brief-file … --cd …` 用於一般 implementation brief（含 file-writing brief）。
- 輸出契約 `.agent-trace/latest.last` 與 [[CC-386]] post-verify 對齊；claude 與 codex 在 implementation 軸的 dispatch/verify 路徑對稱。
- 釐清 claude 被派發為 executor 時的 isolation/permission（對比其當 host PM 時的 host-native 角色，[[guard-role-runtime]]）。

**串流/可觀察性 — 決定 (b)（user 2026-06-15）**: codex 用 `codex exec --json` = 逐事件 JSONL 串流（可逐條確認、有 `turn.completed`）；claude adapter 現用 `claude -p --output-format json` = 結尾單一 JSON blob（`.result`/`.is_error`，無逐步串流）。**決定：採串流**——claude adapter 改 `--output-format stream-json`（`--verbose` 視需要），取得逐事件 JSONL，與 codex 對稱可逐條確認（user 偏好：能串流就優先串流，見 [[feedback_prefer_streaming_executor_output]]）。實作要點：(1) `adapters/claude/dispatch.sh` 的 `--output-format json` → `stream-json`；(2) `.last` 萃取從「單物件 `.result`」改為「stream 末筆 `type==result` 事件的 `.result`」；(3) `is_error` 偵測改抓該 result 事件；(4) token usage 萃取同步調整。注意 [[CC-386]] 結構完整性檢查（`jq empty`）對單 blob 與 stream 兩種 shape 皆已成立，故此改動只增 observability，不影響 trace 驗證正確性、CC-386 零改動。

**驗收**: 一次真實 `pmctl dispatch run --adapter claude` implementation run，產出檔案、self_verify 通過、[[CC-386]] 三重機檢判 PASS。

**Dependencies**: [[CC-383]]、[[CC-386]]。umbrella [[CC-333]]。

**See**: pr:#287

---

## CC-376 — adapter: opencode executor ✅ 2026-06-16

**Problem / 目標**: 新增 opencode 作為第一個「第三方」executor adapter，驗證 v0.6.0 抽象：新增 executor 只需放 `adapters/opencode/`，不動核心。

**Requirement**:
- `adapters/opencode/`：`dispatch.sh`（叫起 opencode CLI，寫統一輸出契約 `.agent-trace/latest.last` + exit code）、`adapter.yaml`（含 [[CC-372]] `runner_kind`，opencode 為 CLI subprocess）、`isolation-map.yaml`（把統一 `--isolation` 翻成 opencode 的 sandbox/permission 旗標）。
- 主路 = `pmctl dispatch run --adapter opencode`；model-alias 解析按 [[CC-292]] executor-specific 約定（`default` alias → opencode 的 wire id）。
- 釐清 opencode 的 sandbox/permission 模型與 bash 攔截能力 → 決定 manifest 的 `needs_bash_guard`/`write_guard_mode`。

**驗收（抽象的證明）**: 落地過程若需修改 `executor-router.sh` 或 guard wrapper 核心，代表 [[CC-373]]/[[CC-374]] 抽象未竟——回頭補抽象，而非在 adapter 內 workaround。核心零改動已確認：`dispatch_route_for opencode` 純由 manifest 衍生。

**Additional**: `share/opencode-model-aliases.tsv`（6 個短 alias）；`fallback_chain` 宣告於 adapter.yaml；dispatch.sh 實作 sequential retry（5 free models，per-attempt timeout = total/N，min 120s）；三重錯誤偵測（exit code + session.error JSONL + step_finish 缺失）。

**Dependencies**: [[CC-373]]、[[CC-374]]。umbrella [[CC-333]]。

**See**: pr:#290

---

## CC-391 — arch(spike): detached-supervised dispatch — executor lifecycle ownership 軸 ✅ 2026-06-15

**Type**: design spike（決策-only；本票不實作）
**Status**: closed — 決策已記錄並 fold 進 v0.6.0 Phase 7；落地（7c）以新子票追蹤（見 MILESTONES Phase 7）。**See**: pr:#288
**Relates**: [[CC-333]]（runtime 解耦 umbrella）、[[CC-385]]（Model B 決策 — 前置）、[[CC-386]]/[[CC-389]]（pmctl 三重機檢 = 驗證層，重用）、[[CC-211]]/[[CC-216]]（run-FSM + events.jsonl + MCP task 抽象 = durable substrate）、[[CC-225]]（durable result 記錄）、[[CC-238]]（fan-out hardening = 症狀）、[[CC-273]]（lifecycle *hook event* spec — 正交、勿混）、[[CC-376]]/[[CC-377]]（真 adapter — 排序前置）

**Problem / why now**: Model B（[[CC-385]]/[[CC-386]]..[[CC-389]]）已交付四件事中的兩件半——brief 由可信代碼落地、executor 為獨立子程序、結果由 `pmctl` 三重機檢驗證（exit + 結構完整性 + 語意終止事件）。但派發本身仍是 **foreground-sync**：`pmctl dispatch run` 阻塞、在 process 內跑 post-verify、**main thread 是生命週期擁有者**。缺的是：(1) 啟動後誰持有 executor 生命週期、main 死了能否續活；(2) 結果如何 durable 化；(3) listener 還活著時如何通知。這三題不是「pm-dispatch 怎麼到達 executor」（[[CC-372]] runner_kind 解的），而是「executor 啟動後誰持有它的生命週期」——是一條**正交的新軸**。

**The axis（user 2026-06-15 分析）**:

```
runner_kind     executor 怎麼被呼叫？        cli-subprocess / host-native / future mcp-tool
lifecycle       啟動後誰持有/等待/收尾？      foreground-sync / detached-supervised
notify          完成怎麼提醒活著的主線程？     durable-outbox(load-bearing) / fifo|socket(選配)
verify          誰判定結果可信？              pmctl-post-verify（= CC-386/389，已是現貨）
```

**定位修正（與初版 user 寫法的差異，spike 要拍板）**: `runner_kind` 是 executor 的**內在屬性**（有沒有 CLI、是不是 host）；foreground vs detached 是**派發當下呼叫者的選擇**，不是 executor 屬性——同一個 codex 可前景派發（盯著看）或 detached 派發（射後不理）。因此：
- lifecycle **不作 manifest 欄位**，作派發旗標 `pmctl dispatch run --lifecycle <foreground|detached>` + `dispatch.lifecycle` config 預設（detached 證實前預設 foreground）。
- 可 detach 之**資格**由現有資訊推導（Model B headless-CLI executor 才可 detach；`host-native` 的 claude-as-host **不可** detach，因為它本身就是 main thread）——不需新欄位。
- 不引入 `lifecycle_mode`/`invoke_kind`/`guard_mode` 的 `schema_version: 2` 改名（會與 [[CC-384]] `hook-*`→`guard-*` 正面對撞）；manifest 詞彙整理集中到未來單一 schema bump，且須先值得。

**The new component — supervisor（監工）**:

```
pmctl dispatch start         # main：建 run 紀錄、落地 brief、setsid/nohup 起 supervisor、回 run-id、可離場
  └─ supervisor（detached）  # 持有 executor child；main 死也活（真 detach，非 run_in_background）
       ├─ 跑 executor
       ├─ post-verify        # 重用 CC-386/389
       ├─ 寫 durable run-state + result artifact   # = CC-225（復活並擴大到所有 executor）
       ├─ append events.jsonl（run FSM）           # = CC-211 substrate
       └─ best-effort 通知 listener                # = notify 軸（唯一真正新做的 channel）
pmctl runs / pmctl dispatch wait <id> / pmctl inbox  # reattach：新的 main 撈回結果
```

機制紅線：(1) **真 detach** 需 `setsid`/`nohup`——今天的 `run_in_background:true` child 仍在 session process group，session 死會 SIGHUP；(2) **notify** 以 **durable outbox/inbox 為 load-bearing**（死後存活、source of truth），live 通知（fifo/socket）僅 best-effort 疊加，永不 load-bearing。

**重用、不重開**:
- [[CC-225]]（claude-executor result observability）= durable-state 半，已 specced → 復活並**擴大到所有 executor**，作本軸的 durable 記錄。
- [[CC-238]]（pr-gate fan-out：無 timeout、attribution 弱、無測試）= **缺 supervisor 的症狀**；supervisor 的 timeout + per-child attribution 收掉它。
- [[CC-273]]（unified lifecycle *hook event* spec）= **不同軸**（tool-step hook 事件，非 process 生命週期）；保持分開、互連。
- [[CC-211]]/[[CC-216]] = supervisor 寫入的底層；不另開 store。

**Acceptance（spike 須輸出）**: 一個決策 **adopt / partial-adopt / defer**；若 adopt 另附——(1) detach 機制（setsid/nohup）與孤兒回收策略；(2) durable run-state 的 schema 與落點（對齊 [[CC-211]] FSM 與 [[CC-225]] `.gate-results/`-style）；(3) notify 的 outbox 契約與 `pmctl inbox`/`dispatch wait` 介面；(4) foreground→detached 遷移順序（任一時刻 guard fail-closed 不弱化）；(5) 一次真實 detached 派發證明結果與 foreground 等價。

**Sequencing**: 排 **v0.6.0 Phase 7**（executor 抽象的完成式），於真 adapter [[CC-376]]/[[CC-377]]（Phase 5）落地後——先在 N≥2 adapter 下證明 executor 抽象，再加 lifecycle 層，避免 supervisor 契約被 codex/claude 特例帶歪；屆時亦摸清 [[CC-381]]（host-PM-aware install）可一起設計通知。**理由**：`host-native` 把 executor 綁死在 host harness，detached-supervised 把它解開，正是 v0.6.0「runtime 解耦合」主題的完成式，且本票是 [[CC-385]] Model B 決策的直接續集，不宜分跨兩版。**逃生口**：若 v0.6.0 收尾時 Phase 7 未及，可單獨延 v0.6.x/v0.7.0（沿用 Phase 3 寫法），預設留 v0.6.0。**例外前拉**：若 [[CC-376]] 過程真的需要 durable result 記錄，只前拉 [[CC-225]] 的 durable-outbox 薄片，不前拉整個 supervisor。

**Non-goals**: 不在本票實作 supervisor；不改 Model B（CC-385..389）已上線行為；不解 [[CC-381]] host-PM install 軸（那是「誰當 host PM」軸，與本「executor 啟動後生命週期」軸亦正交）。

**Spike outcome（2026-06-15，codex 深入分析）**: 詳見 `docs/spikes/CC-391-detached-supervised-dispatch-scope.md`。判定 **partial-adopt** — 採納 lifecycle 為新派發軸、detached supervisor 為長期形狀，但「使用者可見 detached 派發」延後到兩個前提解決後：
1. **detach 資格不能單靠 runner_kind 推導**：`adapters/claude/adapter.yaml` 宣告 `runner_kind: host-native`，但 `adapters/claude/dispatch.sh` 實際跑 headless `claude --print`（CC-383/388 後的漂移）→ `runner_kind == cli-subprocess` 不是可信的資格謂詞。須先釐清 claude 分類（host-native vs cli-subprocess，或 claude-as-host / headless 兩 profile），或由「實際 adapter route/primitive」算資格＋測試。→ 已拆 [[CC-392]]（detach 落地前置）。
2. **footer/durable artifact 先行**：(a) 現行 `_footer_tmp` 為 `mktemp` parse 後即刪（`pmctl-dispatch.sh`）→ detached supervisor 崩潰會丟失 CC-305 防競態的 per-run footer handoff，須在 verify 前把 footer 持久化到 run 目錄；(b) state store 在 `~/.local/share/pm-dispatch/state`（user data），但 [[CC-225]] 要 repo-tracked `.gate-results/`-style → durable-outbox **不等於 events.jsonl**，須獨立 repo-local result/outbox artifact 為 load-bearing、再 mirror 到 state store。

遷移 fail-closed 順序（spike D7）：保持預設 foreground → 抽 executor tail（行為不變）→ foreground 模式先加 footer/result/outbox 持久化並驗 CC-305 仍成立 → supervisor foreground test 模式 → `--lifecycle detached` opt-in（ineligible adapter 啟動前拒絕）→ 才接 `setsid`/`nohup` + `dispatch wait`。紅線：不加 manifest `lifecycle_mode`；不讓 fifo/socket 成 load-bearing；supervisor 不得收未過 preflight 的 raw brief/adapter path。

**See**: [[CC-333]] umbrella、[[v0.6.0-planning]]、MILESTONES.md v0.6.0 Phase 7、`docs/spikes/CC-391-detached-supervised-dispatch-scope.md`。

---

## CC-392 — arch: claude adapter runner_kind 分類漂移 ✅ 2026-06-15

**Resolution**: `adapters/claude/adapter.yaml` set to `runner_kind: cli-subprocess` with overrides `write_guard_mode: cli-only` + `needs_bash_guard: false` — the three derived flags resolve behavior-identically (guard unchanged); `dispatch_route` now derives to `main_thread_bash_background` (label only, per [[CC-373]]). Stale `host-native`/`claude-as-host`/main-thread framing refreshed in `docs/executor-contract.md` (guard + profiles tables) and code comments. Regression added in `test-runner-kind.sh` (claude resolved flags + overrides) plus `test-executor-router.sh`/`test-hooks.sh` updates. pr-gate standard tier GO (advisories on stale profile rows cleared in-PR). Unblocks [[CC-391]] detach-eligibility. **See**: pr:#289.

**Problem**: `adapters/claude/adapter.yaml` 宣告 `runner_kind: host-native`（`adapters/claude/adapter.yaml:16`，註解述「claude-as-host self-executes its own edits gated by the host harness」），但自 [[CC-383]]（gate route 改走獨立 headless）+ [[CC-388]]（一般 implementation 對稱 codex）後，`adapters/claude/dispatch.sh` 實際是 `CMD=(claude -p --output-format stream-json …)`（`adapters/claude/dispatch.sh:5`、`:229`）的 **headless 獨立子程序**，由 `pmctl dispatch run --adapter claude` 驅動——行為上是 cli-subprocess / Model B。manifest 宣告與實際行為不一致，且 manifest 註解過時。發現於 [[CC-391]] 的 codex 深入分析（`docs/spikes/CC-391-*.md`，spike partial-adopt 前提 1）。

**Why now / 影響**: 今日尚未弄壞 dispatch——[[CC-373]] 的去風險結論是 `dispatch_route` 在 `pmctl-dispatch` 僅作 allowlist（zero/non-zero）+ log label、**不驅動 exec 分支**；而 `write_guard_mode` 對 `host-native` 與「`cli-subprocess` + cli-only override」恰好同值（cli-only），所以是「對的結論、錯的理由」。真正的問題是 `runner_kind` 因此成為**不可信謂詞**：任何由它衍生的判斷都不能盡信。具體卡點是 [[CC-391]] 的 **detach 資格推導**（「headless-CLI Model B executor 可 detach、host-native 不可」）——若照 manifest，claude 會被誤判為不可 detach，但它實際就是 headless subprocess。

**Decision needed**: claude 有兩執行模式——canonical headless `claude --print`（`pmctl dispatch run`，executor-contract 文件化主路）與 same-host `Agent(claude-executor)` 優化路。兩條路徑：
- (A) 把 canonical 定為 `runner_kind: cli-subprocess`，並 override `write_guard_mode: cli-only` + `needs_bash_guard: false` 以保持行為 byte-identical（比照 codex 用 per-flag override 偏離 runner-kind 預設的慣例，見 `scripts/lib/runner-kind.sh` override seam）。same-host Agent 路降為文件化 fallback。
- (B) 引入可表達「host-native fallback + cli-subprocess canonical」的機制（較重，可能踩 schema 改名，與 [[CC-384]] 衝突——不偏好）。
**傾向 (A)**：canonical route 就是 headless，manifest 應反映 canonical；[[CC-373]] 當時明確 defer 此 claude 角色歧義（因 dispatch 不靠它），[[CC-391]] 強制它收斂。

**Requirement**: manifest 的 `runner_kind`（＋必要 override）反映 canonical headless 路；`runner_kind_resolve_flag` 解析後三衍生旗標（`dispatch_route`/`write_guard_mode`/`needs_bash_guard`）對 claude 的**有效值與行為 byte-identical**（不得弱化 guard）；更新過時註解；加回歸測試鎖定（manifest 一致性 + 衍生旗標值）。**紅線**：這是 guard 安全邊界相關，security/risk hard gate；不得在 migration 中途弱化 claude 的 write guard。

**Dependencies / 關聯**: [[CC-391]]（detach 資格前置——本票須先收斂）、[[CC-373]]（曾 defer 此歧義）、[[CC-383]]/[[CC-388]]（造成漂移的兩 PR）、[[guard-role-runtime]]（role×runtime 兩軸）、[[CC-372]]（runner_kind manifest）。

**Priority**: P2 — `runner_kind` 可信度 + [[CC-391]] detach 落地前置；排 v0.6.0 Phase 7。

**See**: `docs/spikes/CC-391-detached-supervised-dispatch-scope.md`（Open questions：claude 最終分類）、umbrella [[CC-333]]。

---

## CC-225 — claude-executor result observability（done）

**Problem**: `claude-executor` task output is written to session-scoped `/tmp/` paths that are not tracked in the repo, cannot be reviewed across sessions, and are not recoverable after the shell exits. The main thread has no durable record of brief path, result summary, or exit status for completed executor tasks.

**Why**: Raised from gate-20260522-145444 (CC-058 gating). The observability gap was observed during the CC-058 session: claude-executor tasks ran but their outputs were opaque to the main thread with no git-diffable artifact. This blocks the CC-211/CC-216 MCP architecture extraction.

**Requirement**: After an executor task completes, the durable record — brief path, result summary, exit status, and post-verify verdict — must be written to a repo-tracked directory (format consistent with `.gate-results/`). **Scope broadened (2026-06-15)**: originally framed for `claude-executor`, but under Model B (CC-385..389) every executor now runs as an independent subprocess, so this is the **all-executor durable run-state** record, not a claude-specific one. It is the **durable-state half** of the detached-supervised dispatch axis ([[CC-391]]): the supervisor writes this record so a main thread that exited (or a fresh one) can recover the outcome. Prerequisite for the MCP task abstraction in CC-211/CC-216.

**Dependencies**: [[CC-211]] (MCP architecture / run-FSM substrate), [[CC-391]] (lifecycle spike — consumer of this record), CC-058 (doctor.sh merge — prerequisite)

**Priority**: P3 — design prerequisite; not blocking current workflows. May be pulled forward as a thin durable-outbox slice if [[CC-376]] (opencode adapter) needs it (see [[CC-391]] sequencing).

**Cross-link**: [[CC-391]] (detached-supervised dispatch), [[CC-211]] (run-FSM), [[CC-216]] (task abstraction)

**Closed 2026-06-17**: Implemented the foreground durable-state half for all `pmctl dispatch run` adapters. Each terminal foreground run writes `<work_dir>/.dispatch-results/<run_id>.md` with YAML frontmatter and a short verify summary, without changing the run schema or adding a `runs.jsonl` pointer. The artifact is repo-local and gitignored; write failures are soft and do not alter dispatch exit codes. The detached supervisor follow-up can write the same record format.

## CC-335 — release: deprecated surface registry + v0.6.0 removal sweep ✅ 2026-06-16

**See**: pr:#292

> **v0.6.0 Phase 4**：本票即 v0.6.0「executor abstraction」milestone 的 deprecation 清掃階段。其中 `--profile` alias（→ `--role`+`--runtime`）與 `codex-dispatch.sh` shim（→ `pmctl dispatch run --adapter codex`）正是 runtime-coupling cruft，與 [[CC-373]]/[[CC-374]] 抽象收口同期最自然。見 MILESTONES v0.6.0。

追蹤 v0.4.0/v0.5.0 期間標記為 deprecated 的 public surface，在 v0.6.0 統一移除。每個項目在移除前需先補 stderr deprecation warning（讓使用者有遷移週期）。

### Deprecated surfaces（v0.6.0 sweep 結果）

| Surface | Deprecated since | Replacement | Removal target | 狀態 |
|---|---|---|---|---|
| `bash scripts/pr-gate.sh` 直呼腳本 | v0.4.0 | `pmctl gate run` | doc-only | ✅ **降級為文件 deprecation**：pr-gate.sh 是 gate 實作本體（`pmctl-gate.sh` 以 `exec` 呼叫），且 standalone/copy-mode 是官方支援的 fallback；不刪檔、不加 runtime warning，僅文件建議 `pmctl gate run`。 |
| `scripts/codex-dispatch.sh` shim（legacy callers） | pre-v0.4.0 | `pmctl dispatch run --adapter codex` | v0.6.0 | ✅ shim 檔早於 v0.3.0 sunset（CC-296）刪除；本次清掃 allowlist/doctor/uninstall 內守衛永不存在檔的 dead-code 與殘留 stale 註解。 |
| `--profile <pm\|codex\|claude>` flag in `pmctl guard check` | pre-v0.4.0 | `--role` + `--runtime` flags | v0.6.0 | ✅ guard check 早已只接受 `--role`/`--runtime`；無殘留 shim（install/doctor 的 `--profile minimal\|full` 為不同 surface，非本票）。 |
| `sandbox` / `approval` / `skip_git_check` legacy metadata fields | pre-v0.4.0 | `isolation_level` field | v0.6.0 | ✅ **移除**：`handover-validate.sh` 刪除三個驗證函式、isolation_level 改必填、trio 欄位出現即 reject 並給遷移訊息；codex adapter 原生 `--sandbox/--approval`（isolation_level 翻譯目標）保留。 |
| `CLAUDE_HOOK_*` env vars（shims） | v0.4.0（CC-321） | `PM_HOOK_*` | v0.5.0 | ✅ **移除**：5 個 `hook-*.sh` 內 9 行向後相容 shim 全刪（0 測試依賴）。 |

### Work items（已完成）

1. ✅ trio / CLAUDE_HOOK_* 在 v0.5.0 前已有 stderr deprecation warning，遷移週期已過。
2. ✅ 移除實作後全測試套件綠燈（trio fixture 轉 isolation_level、刪 trio 函式測試、加 trio-rejected 測試）。
3. ✅ 清理文件（dispatch-brief.md / executor-contract.md）與 dead-code 殘留。

### How to add a new deprecated surface

在這個 body 的 table 新增一行，欄位：surface（exact invocation）、deprecated since（vX.Y.Z）、replacement（exact new invocation）、removal target（vX.Y.Z）。不需另開票。

---

## CC-384 — arch: guard 腳本術語脫鉤（`hook-*` → `guard-*`）✅ 2026-06-22

**Problem（user 2026-06-14）**: `scripts/hook-*.sh`（8 檔）、`scripts/lib/hook-framework.sh`、`hk_*`/`HK_*` 函式與變數、`PM_HOOK_*` env 都沿用 Claude 平台的「hook」術語。但它們本質是 **PreToolUse 協定的策略腳本**：輸入是 PreToolUse 形狀的 JSON、輸出是 exit code，可由 (a) Claude 活 PreToolUse 觸發，**或** (b) `pmctl guard check` 合成同樣的 JSON 餵入。後者（尤其 [[CC-374]] 收口後 claude 的 cli-only 路徑）**根本不是平台 hook**，只是被餵合成輸入的策略評估器——「hook」對這一半名實不符。

**Why**: 這是 [[CC-333]] layer 2（hook 機制）/ layer 6（術語）的硬耦合：Claude 平台詞漏進想做 runtime-agnostic 的核心。對齊 runner_kind/manifest 之後，命名也應該中性化。

**Requirement**:
- `hook-*.sh` → 平台中性 `guard-*`（如 `guard-executor-write.sh`、`guard-pm-write.sh`、`guard-codex-bash.sh`）；`hook-framework.sh` → `guard-framework.sh`；`hk_*`/`HK_*` → `g_*`/`G_*`（或等價）；`PM_HOOK_*` env 評估是否改名（保 deprecated alias）。
- **保留** settings.json 的 `PreToolUse` 鍵——那是 Claude 平台自有、不可改；被接進去的腳本對 Claude 而言確實是 hook。
- 三方一致：install/uninstall/doctor 接線 + doctor parity scanner + 測試 + 文件同步改。

**Non-goals / 切割**: 純命名/機械改動，**不可**與 guard 行為/安全邊界票混在同一 PR（會污染 security review）。獨立 PR。

**Sequencing**: 排在真 adapter [[CC-376]]/[[CC-377]] 之後；可與 [[CC-335]] deprecation 清掃同期評估。

**See**: pr:#310; [[CC-374]]（收口後讓 cli-only 名實不符浮現）、[[CC-372]]（runner_kind/write_guard_mode）、[[CC-335]]（deprecation sweep）、umbrella [[CC-333]]。

---

## CC-396 — chore: 清理 operational 檔內的 CC-provenance 註解 ✅ 2026-06-19

**Problem**: `scripts/`、`adapters/`、`cli/`、`core/` 等非文件檔殘留設計沿革票號註解（如 `scripts/lib/pmctl-guard.sh:3` `# Executor-agnostic guard-check front-end (CC-288; role×runtime keying CC-291)`），違反 No-CC-in-operational 慣例（票號只進 BACKLOG/MILESTONES/CHANGELOG/docs）。

**重要 scope 界定**: 原始 `grep -rE "CC-[0-9]+"` 在 operational 樹得數百筆，但**絕大多數非違規**：
- **測試 fixture data**（保留）—— `test-pmctl-task.sh`（228 筆）、`test-archive-closed-backlog.sh`（96 筆）等用 `CC-101`/`CC-103.json` 當 backlog/task 工具的測試輸入；刪了測試會壞。
- **ID 格式範例**（保留）—— `core/schema/task.schema.json` 的 `"e.g. CC-229, JS-106"` 是說明 ticket-id 文法。
- **provenance 註解**（本票目標）—— 程式碼註解裡記設計沿革的票號，應搬 docs/DECISIONS 或刪。

**做法**: 逐處判斷（非機械 sed 替換）；分類 fixture/範例/沿革，只動沿革子集。完成後加 lint 規則防回歸（選配，視子集大小）。

**Sequencing**: [[CC-395]] 合併後另開 PR，避免污染退場 diff。發現於 [[CC-395]] 退場工作。umbrella [[CC-333]]（衛生軸）。

**See**: pr:#303

---

## CC-371 — uninstall: prune empty `~/.claude/adapters/` dir ✅ 2026-06-19

**Problem**: `uninstall.sh` (via `uninstall-hooks.sh`) prunes the managed parent dirs `agents/`, `commands/`, `skills/`, `scripts/`, and `share/` once empty, but the prune list omits `adapters/`. After the `adapters/claude` + `adapters/codex` symlinks are removed, an empty `~/.claude/adapters/` directory is left behind.
**Why**: Cosmetic only — the directory is empty, there are no dangling symlinks, and nothing functional remains. The `docs/RELEASE_CHECKLIST.md` §2a "no leftover dir" intent (which it states explicitly for `share/`) is not fully met.
**Requirement**: Add `adapters` to the empty-dir prune list in the uninstall path so a clean uninstall leaves no managed parent dirs; extend the uninstall regression coverage with a leftover-dir assertion (no managed parent dir survives a full uninstall).
**Source**: surfaced during v0.5.0 release §2a manual verification (2026-06-13); `~/.claude/adapters/` observed empty after `uninstall.sh`, hand-cleaned to restore the test environment.
**See**: pr:#300

## CC-220 — spike agent + `/spike` skill ✅ 2026-06-19

**See**: pr:#302

**Corrected 2026-05-22**: the original "spike agent dispatches parallel sub-agents" is structurally impossible — **subagents cannot spawn subagents**. The spike agent is a *planner* (like `project-pm`); the **main thread** fans out one Agent per angle, modeled on `/pr-gate`'s reviewer fan-out. v0.3.0 M5.

**Problem**: Spike investigations are currently ad-hoc: the PM dispatches a mix of Explore
calls, the findings are summarized in conversation context, and nothing is committed to
the repo. Repeating a spike wastes tokens; the result is not reviewable.

**Why**: A dedicated spike agent with a structured workflow produces a committed, reviewable
result file. The parallel multi-angle dispatch matches how PM agent dispatches reviewers —
reusing the same agent/fan-out primitives for a different cognitive mode.

**Requirement**:
- `agents/spike.md` — spike agent definition:
  - Reads BACKLOG spike ticket for `Investigation scope` and `Done-when`
  - Plans 2–3 investigation angles (e.g., existing-coupling audit / interface draft / prior art)
  - Returns a `spike_plan` block (2–3 angles); the **main thread** fans out one `Agent` per angle — subagents cannot spawn subagents (same constraint as `project-pm`)
  - Synthesises findings into `docs/spikes/CC-NNN.md`
  - Updates BACKLOG body `Result log` field with the file pointer
- `commands/spike.md` — `/spike CC-NNN` skill invoking the agent
- Executor design: each executor type has its own model pool (codex: codex-default + lightweight variants; claude: haiku/sonnet/opus); dispatch layer picks executor+model from pool — no cross-pool model assignment
- Sandbox is orthogonal to executor type; future: both executor types should support sandbox on/off flag (tracked separately)
- Architecture spikes: dispatch 2–3 sub-agents with different angles for multi-perspective coverage

**Depends on**: CC-218 (spike type + docs/spikes/ directory must exist first). **✅ CC-218 已滿足** — `docs/spikes/` + `docs/spikes/README.md` + `spike` epic 均已存在，本票技術上可建。

**Complements**: CC-218 (infrastructure), CC-209 (first spike to run through the new agent).

**Decision rule (見 [[CC-408]] 三方統整 `docs/spikes/CC-408-next-step-router.md`)**: spike 在「候選已選定、但一般 impl brief 不負責任，因為須先做並 commit 一個 durable feasibility/API/architecture 決策」時用。`/discover` 選選項、`/research` 引入外部選項、spike 收斂出決策。觸發：spike-epic 票存在；PM 無法在不解 implementation-blocking 未知（API 形狀/schema 邊界/adapter 可行性/migration 策略/工具採用 verdict/跨層 ownership）下寫 brief；答案須 commit 進 `docs/spikes/CC-NNN.md`。非觸發：模糊「下一步」→ discover、「別人怎麼做」→ research、解釋程式碼 → Analysis、規劃已懂的票 → Planning/Brief。

**Status (2026-06-19)**: ✅ **closed — shipped in the agent-family bundle（pr:#302，見 [[CC-408]]）**。三方統整原建議 defer，但 user 拍板把 router/research/spike 三者併同一 PR 一次出。本 PR ship `agents/spike.md`（planner，回 `spike_plan_v1`、plan+synthesis 兩 pass、main-thread fan-out）+ `commands/spike.md`（`/spike` 編排），契約回歸鎖於 `scripts/test-commands.sh`。建構約束已落實：spike agent 為 planner + main-thread fan-out（不自行 spawn agents）。被 next-step router [[CC-408]] 路由觸發。[[CC-244]]（typed spike→brief schema）續 deferred 至 3+ spike docs 門檻觸發。

**Priority**: P3.

## CC-238 — /pr-gate parallel fan-out timeout + attribution ✅ 2026-06-19

**Problem**: CC-217 made the `/pr-gate` claude-executor reviewer and synthesis fan-out (`commands/pr-gate.md` Route B) run detached via `run_in_background: true`. The CC-217 gate (gate-20260523, express tier) raised three advisories on the new flow.

**Why**: A detached fan-out with no timeout can wait indefinitely if a reviewer agent never reports completion; a single fan-out step makes per-reviewer attribution weaker on partial failure; and the behavior change has no test artifact.

**Requirement**:
- Add a completion timeout / fallback for the background reviewer + synthesis agents — a non-reporting agent must degrade to a partial/fail result, not an indefinite wait.
- Preserve per-reviewer failure attribution when only one fan-out branch fails.
- Add test coverage for the claude-route background completion + relay ordering (`scripts/test-pr-gate.sh` or a `commands/`-contract test).

**Priority**: P3 — advisory follow-up; the CC-217 GO was not blocked on it.

**Note (2026-06-15)**: advisories (a) no-timeout / indefinite-wait and (b) weak per-reviewer attribution are **symptoms of the missing supervisor** — a detached fan-out with no process that owns each child's lifecycle. The detached-supervised dispatch spike ([[CC-391]]) subsumes both: the supervisor's completion timeout + per-child attribution is the general fix, of which this gate-route case is one instance.

**Design decision (2026-06-19)**: The general detached supervisor ([[CC-391]] spike + [[CC-399]] implementation) was delivered in v0.6.0 for `pmctl dispatch run --lifecycle detached`. However, `pr-gate.sh` parallel reviewer fan-out manages its subprocesses **directly inside `pr-gate.sh`** (via `eval "$DISPATCH_CMD" ... &`), not via `pmctl dispatch run` — so the supervisor lifecycle path does not apply here. This ticket is closed via a **local `pr-gate.sh` watchdog** (SIGTERM-based, covering both reviewer fan-out and synthesis), which is the correct ownership boundary for in-process subprocess management.

**Cross-link**: [[CC-391]] (supervisor spike), [[CC-399]] (supervisor implementation — different path), CC-217 (origin), `commands/pr-gate.md` Route B.
**See**: pr:#300

## CC-344 — skill: /research — grounded external research with internal context anchoring ✅ 2026-06-19

**See**: pr:#302

**Problem**: `/discover` 只掃內部 backlog——只能看到「我們已經想到但還沒做」的機會，完全沒有「我們還沒想到的事」這條路。每次想引入外部方法（競品設計、社群實作、學術技術）都要手動搜尋，且搜出來的結果缺乏內部設計 constraint 的過濾，噪音大。

**Why**: 有效的外部研究需要兩個錨：(a) 知道自己「已有什麼」避免重複；(b) 知道「為什麼之前沒做某些事」避免搜到被排除的路。這兩個錨都在內部 memory/decisions 裡，用完全隔離的 agent 搜尋反而丟掉了最有用的 context。正確形狀是：先讀內部建立錨定，再問一個定向問題，最後帶著 constraint 去搜。

**Requirement**:
- `commands/research.md` — `/research [topic]` skill 定義：
  1. **內部錨定**：檢索與 topic 相關的 memory cards + DECISIONS 段落，建立「已有什麼、哪些路已排除」的 baseline。今天即可用現有手段（DECISIONS 直讀 / 現有 `pmctl context` repo source + memory 目錄 grep / `MEMORY.md` 索引，比照 `/mem-search`）。**把錨定隔離成單一步驟並留 swap-point**：待 [[CC-403]]（`pmctl context --source memory|all`）落地後改走單一檢索入口，避免散落的 bespoke memory 搜尋（retrieval-first 整合，非阻塞）。
  2. **定向問題**：問使用者 1–2 個精準問題縮小搜尋查詢（例：「你說記憶優化，是指 recall 精度、token 壓縮、還是 episodic 連貫性？」）
  3. **外部搜尋**：派一個有 WebSearch 工具的 agent，帶著定向查詢抓取 3–5 個外部資訊點（實作、論文、社群討論）
  4. **過濾輸出**：主線程以內部 constraint 過濾，每個外部方法標記「可採用」或「與 [constraint X] 衝突，原因是 [decision Y]」
  5. **持久化詢問（persistence）**：流程結尾必須問使用者「是否把結果轉成 BACKLOG 票 / spike 票 / memory note」——`/research` 不自動開票，但若不問，外部研究又淪為一次性對話 artifact（正是本票要避免的失敗）。
- 輸出不是搜尋結果的 dump，而是「可行性評估清單」

**Non-goals**:
- 不自動開票（使用者決定是否跟進；但流程結尾須主動詢問持久化選項，見 Requirement 5）
- 不取代 `/discover`（兩者互補：discover 看內部機會，research 看外部方法）
- 不做完全自由的 web crawl——搜尋查詢必須由定向問題錨定

**Relationship**:
- 互補於 `/discover`（[[CC-343]]）——discover 是內部發散，research 是外部引入；兩者由 next-step router [[CC-408]] 路由觸發（research 為 external-method gap 的 auto-offer 第二層，掛在選定的 discover 候選上、不對裸問題盲 fire）。
- **前向整合 [[CC-403]]**（`pmctl context --source memory`，非阻塞）：內部錨定今天用現有手段即可（見 Requirement 1）；CC-403 落地後把 memory 錨定改走單一檢索入口。低號票不阻塞於高號票——CC-344 可先行實作。
- 未來可與 CC-338 repo index 整合：錨定時加入 repo 層的「已有哪些 helper/pattern」。

**Status (2026-06-19)**: ✅ **closed — shipped in the agent-family bundle（pr:#302，見 [[CC-408]]）**。`commands/research.md` 已實作：內部錨定（留 [[CC-403]] swap-point）→ 強制定向問題 → WebSearch agent 抓 3–5 點 → 內部 constraint 過濾 → 強制 persistence 詢問；不自動開票。契約回歸鎖於 `scripts/test-commands.sh`。由 next-step router [[CC-408]] auto-offer 觸發。CC-403 為前向整合而非前置阻塞。

**Cross-link**: [[CC-343]], [[CC-408]], [[CC-403]], [[CC-237]]. （原 [[CC-340]] 的 MVP 已被 [[CC-403]] supersede；memory 錨定的單一入口整合改參考 CC-403。）

---

## CC-345 — dx: claude adapter 即時進度串流（stream-json）✅ 2026-06-19

**See**: pr:#287 (CC-388: claude adapter stream-json executor)

> **SUPERSEDED 2026-06-19**: CC-388（PR#287，v0.6.0 Phase 4）已將 `adapters/claude/dispatch.sh` 切換至 `--output-format stream-json`，逐行 NDJSON events 輸出，CC-345 所描述的需求已完整實現。本票廢棄。

**Problem**: `adapters/claude/dispatch.sh` 使用 `--output-format json`，使 claude 的 stdout 完全 buffered 至 process 結束才 flush。dispatch 執行期間 trace file 為 0 bytes、git working tree 無變動，使用者無從判斷 executor 是在讀取、規劃還是寫檔，只能盲等。

**Why**: `claude -p` 支援 `--output-format stream-json`，逐行輸出 NDJSON events（tool_use、tool_result、assistant），包含 tool name 與路徑。切換後可同步解析 events，在 stderr banner 即時顯示進度：
- `[reading]  core/schema/context-pack.schema.json`
- `[writing]  scripts/lib/pmctl-context.sh`
- `[running]  bash scripts/test-pmctl-context.sh → exit 0`

讓使用者在 dispatch 進行中就能看到 executor 正在操作哪些檔案，不再盲等 15–30 分鐘。

**Requirement**:
- `adapters/claude/dispatch.sh` 改用 `--output-format stream-json`
- 以 `tee` 同步寫入 trace file 並 pipe 至 progress parser
- `scripts/lib/claude-progress.sh`（新建）：讀 NDJSON stream，解析 tool_use events 並輸出 `[reading]`、`[writing]`、`[running]` 進度行至 stderr
- stream-json 不輸出單一 `.result` 欄位；dispatch.sh 結尾改從 stream 末尾 assistant message 擷取 `.last` 內容
- 向後相容：stream-json 不可用時 fallback 到 json

**Non-goals**:
- 不解析 assistant 思考內容（只解析 tool_use / tool_result events）
- 不改變 `.last` / `.jsonl` 最終格式（post-verify 向後相容）
- 不加 TUI / 進度條，純 stderr 行輸出

**Milestone**: `🟢 someday` — 不影響正確性；排在 v0.5.0 P1 工作完成後。

**Priority**: P2.

**Cross-link**: [[CC-338]], [[CC-341]].

## CC-400 — retrieval-first: prompt/docs 檢索順序強制 ✅ 2026-06-20

**See**: pr:#308 (shipped with [[CC-401]])

**Problem**: `agents/project-pm.md` Principle 3 把 context retrieval 寫成「before grepping knowledge docs」的軟 reflex，且同一份 prompt 又要求 project-touching invocation 一開始直接讀 `project_<repo>.md` → agent 容易先用 memory file / Read / Grep，而非把 `pmctl context` 當第一入口。`docs/context-retrieval.md` 標題也只寫「Query before grep」，沒涵蓋 full-file Read。

**Why**: 行為要改，最便宜的第一步是把「檢索順序」講成 workflow invariant 而非建議——這是純文件改動、零程式風險，可獨立於本 milestone 提前落地，並為 [[CC-401]]（把它釘成被驗證的合約）鋪路。

**Requirement**:
- `agents/project-pm.md` Principle 3 改成硬性檢索順序：找既有票/決策/規則/prior-art/symbol 一律先 `pmctl context query`（knowledge/repo/未來 memory source）→ 拿到 ref 才 Read 對應段落；`# no hits` 才 fallback 到 targeted Grep/Read 並在 brief 註明 miss。
- `docs/context-retrieval.md` 把「Query before grep」升級為「Query before Read/Grep/full-file open」。
- 不動程式；測試面僅 `scripts/test-commands.sh` / agent-lint 既有檢查。

**Priority**: P2.


**Refs**: [[CC-401]]、[[CC-403]]（memory source 落地後檢索順序涵蓋 memory）、[[feedback_cut_capability_close_all_paths]]、`docs/context-retrieval.md`。

## CC-401 — retrieval-first: brief-validate `retrieval:` 證據 chokepoint ✅ 2026-06-20

**See**: pr:#308. **Shipped contract** (diverged from the original sketch above): evidence = non-empty `context:` block (or the `auto_context:` block `--auto-pack` appends), or non-empty `retrieval_skip_reason:`. `auto_pack: true` as a brief field was **dropped** as evidence — nothing at dispatch reads it (auto-pack is `--auto-pack`/`dispatch.auto_pack`-driven and appends `auto_context:`). Rollout knob `BRIEF_VALIDATE_RETRIEVAL=warn|fail` (default warn). fail-mode default flip = [[CC-402]].

**Problem**: `agents/project-pm.md` Principle 3 把 context retrieval 寫成「reflex」（軟提示），但本 repo 哲學是**在單一 chokepoint 強制**（[[feedback_cut_capability_close_all_paths]]）。軟提示在壓力下會退化成直接 grep / full-file Read，PM 重新推論背景而非引用 context refs——正是 v0.5.0 §Phase 2 驗收原則想避免的反模式。

**Why**: dispatch 路徑唯一的可信 chokepoint 是 `pmctl dispatch run` → `brief-validate.sh`。把「有沒有先檢索」變成**被驗證的 brief 欄位**，比要求 agent 記得 reflex 強得多，且天然可觀測（搭配既有 `context.queried` telemetry）。

**Requirement**:
- brief schema 新增選用 `retrieval:` 區段，非 trivial brief（`architecture_impact: minor|major`，或 `files:` 超過大小門檻）須滿足其一：`pmctl_context:`（query/reuse-scan/pack 的 refs）、`auto_pack: true`、或 `skip_reason:`（明確理由，如目標無可索引 repo / 任務極小）。
- `brief-validate.sh` 加檢查，**先 warn 後 fail**（rollout 期不立即擋現有 brief）。
- 非 `pmctl-context.sh` 範圍：動 brief schema + validator + `docs/dispatch-brief.md` + 測試。

**Non-goals**: 不強制每個 trivial 修補都附 refs（`skip_reason:` 即出口）；不取代 PM 判斷，只要求留下檢索證據。

**Sequencing**: 相依 [[CC-400]]（prompt/docs 先把檢索順序講清楚），之後本票把它釘成合約。retrieval epic 行為層最高槓桿。

**Priority**: P2.

**Cross-link**: [[CC-400]]、[[feedback_cut_capability_close_all_paths]]、[[feedback_pr_gate_fix_all]]、auto-pack 路徑 [[CC-402]]、`docs/context-retrieval.md` §Success metric。

## CC-402 — retrieval-first: auto-pack 與 detached lifecycle 相容 ✅ 2026-06-21

**Problem**: 目前唯一**結構性**的 context-first 機制是 dispatch `--auto-pack`（跑 reuse-scan、附 pointer-only `auto_context` block），但它 (a) 預設 off，(b) 與 v0.6.0 落地的**預設 detached lifecycle**（[[CC-398]]/[[CC-399]]）不相容——auto-pack 會 forward 一份 derived pack brief，與被 guard/validate 的 `/tmp` brief 分歧，故 detached + auto-pack 在 pre-launch 被直接 REJECT（見 `docs/dispatch-brief.md` §Dispatch lifecycle）。結果：最該預設開的機制，在預設派發路徑上反而開不了。

**Why**: 要讓「context-first」成為預設行為而非 opt-in，auto-pack 必須能在 detached 下運作，且不破壞 [[CC-398]] 的核心不變式（guarded == validated == executed == recorded 同一份 brief）。

**Requirement**:
- detached 下：先產 augmented brief（原 brief + `auto_context:`），把 augmented 路徑寫入 run-spec 作為 trusted `brief_file`，supervisor 重跑 preflight 時 guard/validate 的就是 augmented 那份。
- 維持 [[CC-398]] run-spec v2 的 trusted-scalar 契約，不得讓 passthrough 夾帶第二個 `--brief-file`。
- 解禁後評估把 `dispatch.auto_pack = on` 設為預設。

**Non-goals**: 不改 reuse-scan 內容（仍 repo-only，見 [[CC-403]]）；不改 auto-pack 的 pointer-only 上限（5 筆）。

**Sequencing**: 排在 [[CC-399]] detached 完成之後（已 done）。HARD security/risk gate（動 supervisor brief 來源）。

**Priority**: P3.

**Status (2026-06-21)**: ✅ **closed**. Shipped the full coherent slice (not just the compat unblock): (1) detached + auto-pack no longer rejected, and BOTH lifecycles land the augmented brief at the guardable `/tmp/brief-<run_id>.md` path so one brief is guarded == validated == executed == recorded — detached records it as the run-spec trusted `brief_file` and the supervisor re-guards it (no second `--brief-file` passthrough), foreground snapshots the pack to `/tmp`, guards it, and forwards it; the authored `--brief-file` is guarded first for path policy; (2) the dispatch gate now validates the **effective** (post-auto-pack) brief so an appended `auto_context:` block counts as evidence; (3) `dispatch.auto_pack` built-in default flipped off → on; (4) `BRIEF_VALIDATE_RETRIEVAL` default flipped warn → fail (CC-401's fail-flip). Honest edge kept: a file-writing brief with 0 reuse hits and no hand-authored `context:`/`retrieval_skip_reason:` is still rejected — auto-pack does not stamp empty evidence. Tests: `test-dispatch-lifecycle.sh` (augmented-snapshot + trusted-scalar), `test-pmctl-dispatch.sh` (default-on + `--no-auto-pack` override), `test-brief-validate.sh` (default-fail + explicit-warn). Docs: `docs/dispatch-brief.md`, `docs/context-retrieval.md`.

**Cross-link**: [[CC-398]]、[[CC-399]]、[[CC-391]]（lifecycle 軸）、[[CC-403]]（reuse-scan 隔離）、`docs/context-retrieval.md` §Dispatch auto-pack。

**See**: pr:#309、decisions:2026-06-21 retrieval-first-defaults-on-and-fail、[[CC-401]]（fail-flip 前置）、[[CC-398]]（trusted-scalar 契約）。

## CC-408 — next-step router: 自動把「下一步做什麼」送到 /discover · /research · spike ✅ 2026-06-19

**See**: pr:#302

**Problem**: `/discover`（[[CC-343]]，已建）、`/research`（[[CC-344]]，未建）、spike agent（[[CC-220]]，deferred）是三把處理「不確定性」的工具，但**沒有調度器**——只能由使用者手動打字呼叫。使用者問「下一步建議做什麼」時，PM 只能憑感覺讀一點 backlog 回答，三個能力都不會自動接線。`commands/discover.md` 輸出又是「給人看的 menu」，缺結構化欄位讓後續路由能接著用。

**Why**: 三方獨立分析（main-thread opus + codex gpt-5.5 + 外部 ChatGPT，見 `docs/spikes/CC-408-next-step-router.md`）一致認定真正缺口是 router，且純 prompt 軟 reflex 會退化（DECISIONS 鐵證：context-pack/reuse-scan 上線時無 caller，最後得靠 deterministic auto-pack 才有人用；同一失敗模式會打中這裡——見 [[feedback_cut_capability_close_all_paths]]）。自動觸發方向對，但 `/discover`（廉價/內部/非承諾）可條件式 auto-fire，`/research`（需 topic + 定向問題 + WebSearch fan-out）只能 auto-offer 並掛在選定的 discover 候選上，不能對裸問題盲 fire。

**Requirement**:
- `agents/project-pm.md` Classify 表新增「Uncertainty routing」路由（或鄰接小表）：
  - open-ended 專案級「下一步做什麼」且無 active scope（票/PR/bug）→ 自動跑 `/discover`。
  - external-method / prior-art / 「別人怎麼做」→ auto-offer `/research`，先問 CC-344 定向問題再跑。
  - 已選候選但卡在 durable 決策未知 → spike（確保/建立 spike 票後跑 `/spike CC-NNN`）。
  - 已 scoped 的實作 → Planning/Brief，不啟動 uncertainty mode。
- `commands/pm.md` 加 main-thread orchestration 規則：PM 回傳 route，**main thread** 跑 `/discover` 並把報告回灌給 PM 後才產最終建議（subagent 不能巢狀呼叫 agent，比照 `/pr-gate` fan-out）。
- `commands/discover.md` 輸出升級為 routing input：每個 pick 加 `suggested_next_action`（`Next` 欄：pm|spike|research|defer，此即該 pick 的 per-pick 路由決策）+ `refs`/anchors；**top-pick** 附一行 `Why not a direct brief`（全域，非每列一欄，避免表格過寬）。CC-343 已關閉，此升級併入本票。
- Done-when：問「下一步建議做什麼」會引用 `/discover` 輸出並明說下一步是 pm/spike/research/defer；active-scope guard 有測試（戰術型「這張票下一步」不得誤觸 auto-discover）。

**Non-goals**:
- 不自動開票、不自動 dispatch、未經使用者確認不改檔。
- 不強制每次都跑完整 pipeline——三者是 siblings 可組成 pipeline，非強制鏈（小工作 discover 完可直接 plan）。

**Status (2026-06-19, user-adjusted bundle)**: 原規劃 router 純文件先行、`/research`（[[CC-344]]）與 spike agent（[[CC-220]]）另案。**user 拍板把三者併入同一 PR（pr:#302）一次出**——本 PR 同時 ship router（`agents/project-pm.md` Uncertainty routing + `commands/pm.md` Discovery route + `commands/discover.md` Next/Refs 輸出）、`/research`（`commands/research.md`）、spike agent（`agents/spike.md` + `commands/spike.md`）。三票於本 PR 一併 closed。Done-when 的 active-scope guard 回歸鎖已落地於 `scripts/test-commands.sh`（含 tactical false-path 斷言）。

**Relationship**: 統御 [[CC-343]]（discover，輸出升級併入）、[[CC-344]]（research，本 PR 一併 ship）、[[CC-220]]（spike，本 PR 一併 ship）。CC-403 為 `/research` memory 錨定的前向整合（非阻塞）。

**Priority**: P2.

## CC-409 — test-infra: `run-all-tests` 並行執行 + dispatch-wait poll 可設定 ✅ 2026-06-22

**Problem**: `run-all-tests.sh` 以單迴圈順序執行 70 suite，整套約 10 分鐘。`test-dispatch-lifecycle.sh` 的 detached lifecycle 案例使用 `dispatch wait`，而 `dispatch wait` 內部 `sleep 2` 硬編使這些 case 每次至少等 2 秒——純 I/O 死時間。

**Fix**:
- `run-all-tests.sh` 加 `--jobs N` / `-j N`：背台 subshell pool 最多 N suite 並行，每 suite stdout/stderr 打入 temp file，完成即整塊印出（不混流）。預設 `JOBS=$(nproc)` 充分利用多核，`nproc` 不可用時 fallback 到 `1`（sequential）。
- `scripts/lib/pmctl-dispatch.sh` 的 dispatch wait `sleep 2` 改 `sleep "${PM_DISPATCH_WAIT_POLL_INTERVAL:-2}"`，讓測試環境可注入 0.1 等間隔。
- `scripts/test-dispatch-lifecycle.sh` 匯出 `PM_DISPATCH_WAIT_POLL_INTERVAL=0.1`，消除 lifecycle 案例的 polling dead time。
- 順帶修 CC-384 BACKLOG body 遺漏關閉標記（`pm/scripts/test` lint + `test-pmctl-backlog` 雙 suite 失敗根因）。

**Done-when**:
- `run-all-tests.sh --jobs 8` 成功跑完所有 suite 且 pass/fail 計數正確
- `run-all-tests.sh`（無 `--jobs`）預設以 `nproc` 並行執行，`nproc` 不可用時 fallback sequential，結果與序列執行一致
- `test-dispatch-lifecycle.sh` lifecycle 案例在 `PM_DISPATCH_WAIT_POLL_INTERVAL=0.1` 下正確通過

**See**: pr:#311

---

## CC-410 — hook: guard audit log 對唯讀 hooks.log fail-silent ✅ 2026-06-22

**Problem**: `scripts/lib/guard-framework.sh` 的 `g_audit` 以 `printf ... >> "$LOG_FILE" 2>/dev/null || true` 追加審計行。這是 bash 的經典陷阱：`2>/dev/null` 無法抑制「重導向開檔失敗」的錯誤——當 `>> "$LOG_FILE"` 因 `$LOG_FILE` 唯讀而開檔失敗時，bash 在重導向設定階段就把 `Permission denied` 印到 shell 的 stderr，`2>/dev/null` 來不及套用。在 codex sandbox（`~/.claude/logs/hooks.log` 唯讀）下，reviewer 的 `pmctl guard check` 因此洩漏一行警告到 guard 輸出，污染 gate reviewer 觀察到的訊號。CC-409 的 pr-gate 期間發現。

**Fix**:
- `g_audit` 的 append 改用 brace group：`{ printf ...; } 2>/dev/null || true`，把 `2>/dev/null` 套在外層，使「開檔失敗」也被靜默。審計為 best-effort，永不影響 allow/deny 決策或 guard 的 exit code。
- `scripts/test-guards.sh` 新增回歸案例 `rw_readonly_log_no_leak`：把 `hooks.log` 設唯讀後跑 reviewer guard 的 allow 路徑，斷言 exit 0 且 stderr 完全無洩漏。

**Done-when**:
- `$LOG_FILE` 唯讀時 reviewer guard check 仍 exit 0、決策不變、stderr 無 `Permission denied` 洩漏
- `test-guards.sh` 新增的唯讀 audit log 案例通過

**See**: pr:#311

---

## CC-003 — [artifact-relocation epic umbrella] dispatch/gate 副產物搬出 repo ✅ 2026-06-25

**See**: pr:#324

**Decision**: 見 DECISIONS.md 2026-06-23 `dispatch-gate-artifacts-relocate-out-of-repo`（五方分析統整裁決）。
**Problem**: dispatch 與 pr-gate 把 scratch artifact 寫進使用者 repo：`.agent-trace/`（adapter `TRACE_DIR=$WORK_DIR/.agent-trace` 寫死）、`.gate-briefs/`、`.gate-results/` + footer/runspec/supervisor log。(L1) pr-gate parallel integrity check（`pr-gate.sh:895/1093`）對 `git status --porcelain` 取 dispatch 前後 hash，gate 自己的寫入若未被 ignore 就改動 hash → 健康 repo 誤判 abort（原始症狀）。(L2) 即使 ignore，檔案仍實體污染 repo（本 repo 已累積 93MB；且跨所有被作用過的 repo）。
**Why**: 根因是 adapter 把「執行 cwd」與「trace 落點」綁死，gate reviewer 又走同一批 adapter，單改 gate 無法讓 repo 不被碰。out-of-repo state 慣例已存在於 `state-writer.sh`，應延伸而非新發明。
**Requirement**: D-wide——dispatch + gate 全部 artifact 搬到 `$PM_DISPATCH_STATE_ROOT/projects/<repo-sha1>/runs/<run_id>/`（複用 state-writer seam，保留 `.gate-results` 葉名）。分階段：CC-413（Phase 0 止血）、CC-414（seam）、CC-415（containment guard）、CC-416（gate 搬遷=原始 bug 修復）、CC-417（dispatch 搬遷）、CC-418（observer+可發現性）、CC-419（翻預設+GC+跨 repo 既有副產物遷移）。本 umbrella 在全部 phase 完成後關閉。

## CC-413 — Phase 0 止血：integrity check 排除 artifact 路徑 ✅ 2026-06-23

**See**: pr:#318

**Problem**: pr-gate parallel integrity check 把 gate 自身寫入的 artifact 目錄算進 status hash，在未 setup 的健康 repo 誤判 prompt-injection abort。
**Why**: 在完整搬遷（CC-416）落地前，使用者需要可立即合併的止血，且不引入 `.gitignore` mutation（既有不變量 `test_pr_gate_does_not_mutate_gitignore` 須保留）。
**Requirement**: `pr-gate.sh` 計算 `_PRE/_POST_DISPATCH_STATUS` 前，過濾掉 `.agent-trace/`、`.gate-briefs/`、`.gate-results/`（NUL-delimited porcelain 較安全）。修正 `:897-898/1091` 誤導性註解。零 `.gitignore` mutation、零行為預設改動、既有測試全綠 + 新增過濾測試。

## CC-414 — Phase 1：trace-root seam（adapter --trace-dir，預設不變）✅ 2026-06-24

**See**: pr:#319

**Problem**: 三個 adapter 寫死 `TRACE_DIR=$WORK_DIR/.agent-trace`，cwd 與 trace 落點綁死，無法把 trace 移出 repo。
**Why**: 這是真正解 L2 的地基；先引入 seam 而不改預設，可把結構改動與行為改動拆成可獨立 review 的 PR。
**Requirement**: 抽 `_sw_store_root`/`_sw_project_key` 成共用 lib（如 `state-paths.sh`）+ 公開 helper `sw_project_run_dir`；`adapters/{codex,claude,opencode}/dispatch.sh`、`dispatch_via`、`dispatch-post-verify.sh` 加 `--trace-dir <abs>` 與 `PM_DISPATCH_TRACE_DIR`（precedence flag > env > legacy `$WORK_DIR/.agent-trace`）。預設仍 in-repo。測試：precedence、絕對路徑驗證、snapshot re-exec 保留 flag。

## CC-415 — Phase 2：post-verify containment guard 重設計 ✅ 2026-06-24

**See**: pr:#320

**Problem**: `dispatch-post-verify.sh` 以「在 `$WORK_DIR` 內」為 trace 的 containment 信任邊界，trace 一旦移出 repo 此 guard 會誤殺。
**Why**: guard 目的（防 executor 把 trace symlink 重導到攻擊者路徑偽造成功）須保留，但邊界要從 repo 改成本次 run 的 trace dir。
**Requirement**: 加 `--run-dir <abs>`，canonical 化後對 `.agent-trace`（symlink 與 regular dir 均適用）做前綴比對，拒絕逃出 run-dir boundary 的情形。無 `--run-dir` 時退回 `$WORK_DIR` 邊界（行為不變）。純 refactor、behind in-repo 預設、加「拒絕逃逸」測試。Owner/group/world-writable 防護 deferred（另開票追蹤）。

## CC-416 — Phase 3a：gate artifacts 搬出 repo（原始 bug 修復本體） ✅ 2026-06-24

**Problem**: gate 的 briefs/results/trace 落在 repo，造成 L1 誤判與 L2 污染。
**Why**: 這是 CC-003 原始 ticket 的真正修復；依賴 CC-414 seam 與 CC-415 guard。
**Requirement**: `pmctl` 配 `runs/<run_id>/` 並把 `.gate-briefs`/`.gate-results`/reviewer trace 路由進去（保留 `.gate-results` 葉名）；integrity check 因 repo 天生乾淨而無需過濾（CC-413 的過濾可保留為防禦）；verdict 預設出 repo，stdout 印路徑 + `--output` 顯式匯回。更新假設「結果在 repo 內」的測試/docs。
**See**: pr:#321

## CC-417 — Phase 3b：normal dispatch artifacts 搬出 repo ✅ 2026-06-25

**Problem**: `pmctl dispatch run` 的 trace/footer/runspec/supervisor log 仍落在 repo `.agent-trace/`。
**Why**: 與 gate 共用同一 seam，避免「兩套 artifact 世界」。
**Requirement**: `pmctl-dispatch.sh` 配 run dir 傳 `--trace-dir`；footer/runspec/supervisor log（含 detached 監督路徑）改寫到 run dir；`dispatch-record.sh` 記錄新路徑。注意 detached supervisor recovery 不可因 runspec 移出 workspace 而失效。
**See**: pr:#322

## CC-418 — Phase 4：observer + 可發現性 ✅ 2026-06-25

**Problem**: 搬出 repo 後，`codex-watch.sh:24`（tail `$WORK_DIR/.agent-trace/latest.jsonl`）失效，使用者也無法再 `ls .gate-results`。
**Why**: 可發現性是搬遷的最大 UX 風險，須補齊。
**Requirement**: codex-watch 改由 pmctl 印出的 trace 路徑或 run-record 解析（加 `--trace <path>`/`--run <id>`）；gate 與 dispatch 結束印 `results:`/`trace:` 絕對路徑；新增 `pmctl artifacts list/show`（與 gate verdict 查看入口）。
**See**: pr:#323

## CC-419 — Phase 5：翻預設 + GC + 跨 repo 既有副產物遷移 ✅ 2026-06-25

**See**: pr:#324

**Problem**: 預設仍 in-repo；state store 無 GC 會無限增長；且各 repo 已有大量既有副產物（本 repo 93MB+）。
**Why**: 收尾——讓 out-of-repo 成預設並控管生命週期，同時清理歷史污染。
**Requirement**: out-of-repo 已為結構性預設（sw_project_run_dir 在所有 adapter 優先取用，legacy in-repo fallback 僅在 state-paths 不可用時觸發）；舊 PM_DISPATCH_TRACE_DIR 指向 work_dir 時一次性 stderr 提示（_SW_INREPO_NOTICE_EMITTED 防重複）；加 retention（keep last N / age-based）+ pmctl artifacts gc [--dry-run] [--keep-last N] [--max-age-days D] [--cd work_dir]；pmctl artifacts gc --all-repos [--repos-root dir] 掃 ~/github/*/ 清理既有副產物（勿在 active dispatch/gate 期間執行）；pmctl artifacts migrate 一次性遷移 in-repo 舊資料；全部 idempotent、dry-run 可見、絕不誤刪 .pm-dispatch/；PM_DISPATCH_GC_KEEP_LAST/PM_DISPATCH_GC_MAX_AGE_DAYS env 可設預設值。注意：--artifact-root/PM_DISPATCH_ARTIFACT_MODE env 切換未實作（不需要，結構性預設已達同等效果）。

## CC-403 — retrieval-first: `pmctl context --source memory`（supersede/吸收 [[CC-340]]）✅ 2026-06-22

**See**: pr:#313

**Problem**: `pmctl context` 的 index 只 `find "$repo_root"` 掃 repo 內檔（`scripts/lib/pmctl-context.sh` index 段），而 memory 住在 repo 外的 `~/.claude/projects/<id>/memory/`，**完全不在索引內**。因此對使用者最常找的「特定資料」——過去決策、規則、偏好——「優先用 `pmctl context`」在能力上不可能；`pack` 的 `"memories":[]` 與 schema description 把 memory 列為 pluggable source，是個**留了縫但沒蓋好的接縫**。

**Why**: memory 是與 repo **不同的檢索平面**，不是 repo 路徑類別。要讓「優先用 pmctl context 找決策/規則/偏好」成立，必須讓 memory 成為一等 source，且不能犧牲隱私或污染 repo prior-art 掃描。

**Requirement**:
- **新增 source 軸**而非 overload `--domain`：`pmctl context query --source repo|memory|all <term>`，`--domain knowledge|repo` 維持為 repo 平面內的路徑分類器。
- pack 結果分流：memory hits 進 `memories[]`（`source: memory-index`、`source_domain: memory`）；schema `source_domain` enum 目前是 `["knowledge","repo","state"]`，**須補 `memory`**（[[CC-376]] 先例：enum/schema 加值是 additive registration footprint，非 structural core change）。
- **reuse-scan 維持 repo-only**：它是 repo prior-art（給 executor 重用程式碼），memory（決策/偏好）混入會擠掉真正的 helper；若要含 memory 走獨立 `memory_candidates:` 或顯式 flag，預設 off。
- **隱私（load-bearing）**：不把私有 memory 明文複製進 repo-local `<repo>/.pm-dispatch/ctx/context.db`（即使 gitignored 仍在 checkout 內、可被工具/封存帶出）。memory 的衍生 DB 落 memory 目錄下（如 `~/.claude/projects/<id>/memory/.pm-dispatch/context.db`），重用既有 `find_memory_dir`（`scripts/lib/memory.sh`）解析；auto-pack 對 memory 只用 pointer-only ref，snippet 需顯式 flag。
- **MVP 範圍（吸收 [[CC-340]]）**：FTS5-optional + LIKE/grep fallback、trust-tier 標記（curated card > episode）、no embeddings。embeddings / 語意後端留 [[CC-340]] 作 follow-up。

**Acceptance**:
- `pmctl context query --source memory -- "<term>"` 能搜到 memory cards / MEMORY.md / episodes，輸出 `context_hit_v1`（含 `source_domain: memory`）。
- `--source all` 合併 repo + memory；`--source repo`（預設）行為與今天 byte-identical。
- memory DB **不**寫進 repo checkout；缺 memory dir 時 graceful（`# no hits`）。
- `reuse-scan` 輸出不含 memory hits（回歸鎖定）。
- schema 接受 `source_domain: memory`；pack `memories[]` 可被填值。

**Sequencing**: retrieval epic 能力層核心；解鎖 [[CC-406]]（/mem-search 改走它）。動 `pmctl-context.sh` + schema + 測試 + docs。

**Priority**: P2.

**Cross-link**: supersedes [[CC-340]]（吸收 MVP）、[[CC-338]]（repo-index 對稱）、[[CC-237]]（shared interface）、[[CC-232]]（pack schema）、[[CC-406]]（消費者）、[[CC-400]]/[[CC-401]]（行為層）。

## CC-404 — memory: MEMORY.md 注入預算 + priority metadata ✅ 2026-06-25

**Problem**: `scripts/hook-inject-memory.sh` 把 `MEMORY.md` 所有 `^- ` 行全注入，>=50 條才印警告，且 `scripts/test-hooks.sh` 明確斷言 60 條不截斷。結果：index bloat 必然發生，每個 session 都付 stale / 不相關條目的 token，與 memory「keep index short, high-signal」的設計目標相反。

**Why**: 注入是每 session 固定成本的最大來源；把它從「全注入」改成「預算 + 排序」是 memory 端最高 token 槓桿。但若無 priority metadata 直接截斷，可能蓋掉關鍵 user 約束——故須與 [[CC-405]] metadata 同捆或在其後。

**Requirement**:
- hook 加硬注入預算（max 條數 + max bytes）。
- 永遠注入固定前言（memory dir、條數、`/mem-search` 指令提示）+ `priority: always` / `scope: active` 條目。
- 其餘條目依 prompt-aware 廉價比對（title / hook text / tags）擇優注入。
- 超量印「N 條省略；用 `/mem-search <topic>`」而非全倒。
- 改現有 no-truncation 測試為「預算內 + always 條目必達 + 超量有省略提示」。

**Priority**: P3.

**See**: pr:#328

**Refs**: [[CC-405]]（priority metadata 來源）、`scripts/guard-inject-memory.sh`、`scripts/test-guards.sh`。

## CC-405 — memory: card frontmatter 標準化 + `/mem-doctor` 健檢 ✅ 2026-06-25

**Problem**: memory 檢索目前靠 filename tier（`feedback_`/`project_`/…）+ hook text 扛太多工作，缺結構化 metadata → 檢索精準度、staleness 偵測、跨專案分享都受限；也沒有便宜可常跑的健檢（`/memory-compress` 是手動重寫流程，需把卡片讀進對話）。

**Why**: 結構化 metadata 是 [[CC-404]] 注入排序與 [[CC-403]] memory 檢索 ranking 的共同前置；`/mem-doctor` 提供 read-only 可觀測面，讓 bloat / dead link / stale ref 在變成問題前被看到。

**Requirement**:
- card frontmatter 必填/建議：`topics`（檢索詞）、`priority`（always/normal/low）、`status`（active/stale/archived）、`updated_at`、optional `expires_at`、`repo_refs`（可被檢查的檔/函式/flag）。
- `/mem-distill`、`/memory-compress` 維護這些欄位；先 warn 後 enforce。
- 新增 read-only `/mem-doctor`（或 `pmctl memory doctor`）報告：MEMORY.md 條數/bytes、重複 hook、dead links、未被 MEMORY.md 引用的 card、stale `repo_refs`、episodes 大小與建議；預設不需讀全部卡片進對話。

**Priority**: P3.


**Result log**: design spike settled 4 blocking decisions → `docs/spikes/CC-405.md`（additive frontmatter GREEN／warn→enforce GREEN／repo_refs grammar GREEN／`pmctl memory doctor` subcommand+schema GREEN；外部 memory-graph 不透明為 decision 1 的 AMBER caveat）。Phase A 落地：read-only `pmctl memory doctor`（`scripts/lib/pmctl-memory.sh` + `memory/doctor` case + frozen schema/`--json schema_version:1`/exit 0-1-2 + `path:`/`fn:`/`flag:` staleness）＋ additive frontmatter schema docs（`docs/memory-system.md`）＋ fixture-isolated 測試（`scripts/test-pmctl-memory.sh`，正負控）。Phase B 落地：`/mem-distill` + `/memory-compress` Step 6 加入 write-time frontmatter enforce（缺欄位阻擋寫入並列出差缺欄位，參照 `docs/memory-system.md`）；33 張 live card backfill 完成，`pmctl memory doctor` 確認 `cards_missing_fields: (none)`, `issues_count: 0`。

**Refs**: [[CC-404]]（消費 priority/scope）、[[CC-403]]（消費 topics/trust ranking）、`docs/memory-system.md`、`docs/spikes/CC-405.md`。

**See**: pr:#315 pr:#327

## CC-406 — memory: `/mem-search` 改走 `pmctl context --source memory` ✅ 2026-06-25

**Problem**: `commands/mem-search.md` 自刻一套（Step 2 `rg`/`grep`、Step 3 semantic fallback），**完全不經 `pmctl context`** → 與「優先用內建 context 指令」的目標直接衝突，且檢索品質受 MEMORY.md index 手感影響過大。

**Why**: 要讓 `/mem-search` 誠實「優先用 pmctl context」，前提是 `pmctl context` 真的搜得到 memory——故本票**相依 [[CC-403]]**；在 CC-403 之前無法落地（pmctl context 根本沒有 memory source）。

**Requirement**:
- 改流程：定位 memory source → `pmctl context query --source memory -- "$ARGUMENTS"` → 只讀回傳的 card / episode refs → index 不可用才 fallback 直接 `rg`（保留現有 no-shell-injection 寫法）。
- 顯示 `memory:<card>:<section>` 之類 ref，而非整檔倒出。
- 更新 `scripts/test-commands.sh` 對 mem-search 的契約檢查。

**Priority**: P3.

**See**: pr:#325

**Refs**: 相依 [[CC-403]]、[[CC-400]]（檢索順序）、`commands/mem-search.md`。

## CC-407 — memory: episodes 衍生摘要/索引 + 歸檔策略 ✅ 2026-06-26

**See**: pr:#330

**Problem**: `episodes.jsonl` append-only 利於稽核但會無限長；`/mem-recall` 只讀最近 N 條非空摘要、`/mem-distill` 只讀最後 10 條 → 較舊的反覆模式除非已被 promote 否則不可見，Stop hook 又持續 append。

**Why**: 長期成長會稀釋 recall 訊號；衍生摘要/索引讓舊模式可被檢索，同時不破壞原始 append-only 稽核性（衍生物可重建）。優先度低於注入 bloat（[[CC-404]]）與檢索強制（[[CC-401]]）。

**Requirement**:
- 保留 `episodes.jsonl` 原始 append-only。
- 加可重建衍生物：`episodes.summary.md`（月摘要，由 `/mem-distill` 產）、`episodes.index.jsonl`（keyword / date / cwd / promoted 狀態）。
- 超過大小/年齡門檻 shard/archive；清理空 skeleton 或至少健檢警告（與 [[CC-405]] `/mem-doctor` 對接）。
- `/mem-recall` 讀「最近 + 相關摘要」而非只讀最近 N 條。

**Priority**: P3.

**Refs**: 延伸 [[CC-234]]（memory v2 寫側）、[[CC-405]]（mem-doctor 報告 episodes 大小）。

## CC-411 — test: context 測試並行安全隔離（拔除對活 repo 的耦合）✅ 2026-06-23

**See**: pr:#314

**Resolution**: 實際耦合僅 2 個 `*_on_real_repo` 案例（`case_context_query_on_real_repo`、`case_context_reuse_scan_on_real_repo`）——它們索引活 `$REPO_ROOT` 並寫共享 `.pm-dispatch/ctx/context.db`。`*_autorefresh_*` 案例已用隔離 fixture，未動。兩案改為把真實 lib 檔（`pmctl-validate.sh` / `pmctl-context.sh`）`cp` 進 `$tmp_root` fixture 後索引該 fixture，保留「真檔可被內容詞命中」的行為保證但不再碰活 DB；另加 `case_context_no_live_db_mutation` guard——套件起跑前快照活 DB fingerprint，末尾斷言未變，防任何案例未來再耦合活 repo。`case_context_index_unknown_flag` 順手改用 throwaway 路徑消除殘留 `$REPO_ROOT` 引用。89/0 綠，shellcheck 乾淨。

**Problem**: `scripts/test-pmctl-context.sh` 有一批案例（`case_context_query_on_real_repo`、`case_context_reuse_scan_on_real_repo`、`case_context_query_autorefresh_existing_db`、`case_context_reuse_scan_autorefresh_existing_db` 等）直接對**活的** `$REPO_ROOT` 做 `context index` / `query` / `reuse-scan`，因此讀寫**共享的** `<repo>/.pm-dispatch/ctx/context.db`。單獨跑時穩定（85/0），但在 [[CC-409]] 把 `run-all-tests.sh` 並行化（`--jobs nproc`）後，這些案例在 8-way 高 CPU/IO 負載下偶發失敗：對 180KB `BACKLOG.md` 的整包索引使 sqlite `busy_timeout=5000` 被觸發、`_ctx_fts_rebuild` 的 DROP+CREATE+INSERT 被 starve（錯誤被 `2>/dev/null` 吞），留下暫態不完整索引 → reuse-scan 找不到預期 ref。實測 `reuse-scan-on-real-repo` 在兩次相同 `run-all-tests` 間 fail→pass。這批案例同時也是單檔最慢的部分。

**Why**: 並行 flakiness 會間歇性污染 gate 的 qa-tester 訊號（flakiness 為 qa 硬閘），且每次都得重跑浪費時間。根因是測試 fixture 耦合活 repo 共享狀態，非生產程式碼問題（`pmctl-context.sh` repo 路徑乾淨）。

**Fix**（範圍界定，prefer additive）:
- 把上述案例改為索引**隔離的 temp fixture / repo 副本**（如 `cp` 必要檔到 `$tmp_root/real-repo-snapshot` 或既有 `make_fixture_repo` 擴充），不再讀寫共享的活 repo DB。保留行為斷言（reuse-scan/query 能由內容詞命中已知檔）。
- 加一條結構斷言（`test-commands.sh` 或 suite 內）禁止 context 測試對 `$REPO_ROOT` 做寫入型 context 操作，防回歸。
- 順帶確認加速效果（隔離後不再每案重索引全 repo）。

**Done-when**:
- `bash scripts/run-all-tests.sh`（並行預設）連續 ≥3 次無 `test-pmctl-context` flaky 失敗。
- 無 context 測試案例對活 `$REPO_ROOT` 寫入 `.pm-dispatch/ctx`。
- 單檔 `test-pmctl-context.sh` 執行時間較現況下降。

**Refs**: [[CC-403]]（發現處，無關其程式碼）、[[CC-409]]（並行化暴露此 flakiness）、`scripts/test-pmctl-context.sh`、`scripts/lib/pmctl-context.sh`。

---

## CC-424 — refactor: memory commands 去 python3 化 ✅ 2026-06-25

**Problem**: `commands/mem-log.md`、`commands/mem-recall.md`、`commands/mem-search.md`、`commands/memory-compress.md` 均含 `python3` 呼叫（memory dir walker 和 subprocess rg/grep）。`mem-distill.md` 已完成去 python3 化並有 `assert_not_contains "no python3 calls"` 斷言保護，其他 memory commands 未對齊。

**Why**: 減少外部直譯器依賴，與 mem-distill 已確立的純 bash 模式保持一致；bash `"$var"` + `--` 分隔符提供等效的 shell-injection 保護，不需要 Python subprocess。

**What was done**:
- 四個 command files 移除所有 python3 呼叫
- 新增 `pmctl memory dir` subcommand（封裝 canonical `find_memory_dir`）
- memory dir walker 解耦合 `CLAUDE_CONFIG_DIR`，command files 改呼叫 `pmctl memory dir`
- `mem-search` Step 2 改用 `$(pwd)` 直接傳給 `pmctl context query`，Step 3 改 bash find+rg/grep
- `test-commands.sh` 新增 mem-log/mem-recall/mem-search/memory-compress 結構斷言 + behavior-level contract assertions
- `test-pmctl-memory.sh` 新增 5 個 `pmctl memory dir` behavioral test cases

**See**: pr:#326

## CC-427 — memory: MEMORY.md 注入 usage-based recency+frequency 排序 ✅ 2026-06-26

**See**: pr:#329

**Problem**: [[CC-404]]（PR#328）落地了硬注入預算（20 條 / 3000 bytes）+ `priority: always` pin + prompt-keyword tier2 排序，但 tier1 條件 `priority: always || status: active` 在「33 張 live card 全 `status: active`」（[[CC-405]] backfill 結果）下 → 全部進 tier1 恆注入、不受預算，實測注入仍 33 條、零省略，**預算實質失效**。`status` 三分法（active/stale/archived）語意是生命週期，不是注入優先級，拿來當恆注入條件是誤用。

**Why**: 注入是每 prompt 固定 token 成本；要讓預算真正生效，需要能區分「該卡現在值不值得注入」的訊號。靜態 `status` 沒有區分度（全 active）；改用動態使用訊號——最近用過 / 常用 → 排前面（recency + frequency）。

**Decision direction**（`/research` 2026-06-25，見 memory `reference_memory_injection_ranking`）:
- tier1 只認 `priority: always`（手動 pin，核心規則恆置頂，與打分正交）；移除 `status: active` OR。
- normal 卡用 **Firefox bucketed frecency**：`score = access_count × age_bucket(last_access)`，bucket = 100/70/50/30/10（age ≤4d/14d/31d/90d/更舊）；純整數零浮點。
- **W-TinyLFU 老化**：週期性 `access_count >>= 1`，避免舊卡高頻霸榜。
- `status` 降為未來 staleness GC 用，不參與注入排序。
- 排除：HN-poly（需 pow）、MemGPT/Claude memory（LLM-judged）、embeddings/FTS（延 [[CC-340]]）。

**Phase 1 — committed 決策**（六-model 統整定案：主線程 + codex + opencode + ChatGPT/Gemini/Grok）:
- `access` 事件定義 → **keyword 命中（`_score>0`）即 +1**，在預算截斷前（冷門但相關卡也累積訊號）；純被注入不計，避免 self-reinforcing 霸榜。
- usage 計數寫回 → **sidecar TSV**（`memory_dir/.pm-dispatch/inject-usage.tsv`），markdown 維持 canonical、零 git diff 噪音、`serialize_with_lock` 原子寫回。
- 老化觸發 → **全域 event-counter**：`total_events` 累積命中達 `PM_MEMORY_DECAY_THRESHOLD`(256) → 全表 `access_count >>= 1` 並歸零（W-TinyLFU；age_bucket 已承擔 recency 軸，故老化綁操作次數而非時間）。
- frecency × keyword 結合 → **複合 sort key** `composite = score × WEIGHT(100000) + frecency`，frecency 鉗在 WEIGHT 以下 → keyword tier 主導、組內 frecency 排序（等價分層、單 pass）。

**Phase 2 — 實作**（✅ 完成）:
- `scripts/lib/memory.sh`：`memory_usage_sidecar_path` / `memory_age_bucket` / `memory_usage_commit`（鎖內 RMW + 全域減半）。
- `scripts/guard-inject-memory.sh`：tier1 只認 `priority: always`、normal 卡 frecency 複合排序、keyword 命中記 access、best-effort 寫回。
- 測試（`test-guards.sh`，6 新增全綠）：status:active 不再恆注入（20+5 omitted）、access 記錄、frecency 排序、keyword tier 主導、decay 減半、age_bucket 映射。

**Priority**: P2（✅ closed 2026-06-26，pr:#329）.

**Refs**: [[CC-404]]（預算+pin+tier2 骨架）、[[CC-405]]（frontmatter schema）、memory `reference_memory_injection_ranking`（research 結論）、`scripts/guard-inject-memory.sh`。

## CC-426 — release: `/pre-release` milestone 落地審查 ✅ 2026-06-26

**See**: pr:#334

**Problem**: BACKLOG/MILESTONES 只記錄「應該做的事」，但無法從文字層面確認每個 ticket 的改動是否完整落地——ticket 可能描述了 3 個要改的地方，commit 只改了 2 個；或 ticket 說「在 X 和 Y 都加 enforce」，只有 X 被改到。目前這個疏漏只能靠 gate 的 critic 隨機抓到（如 CC-405 的「仍待辦」文字）或人工回顧。

**Why**: release 前有一個系統性的落地確認，可以在 tag 之前找出：ticket 關閉但實作未完整、CHANGELOG 未反映實際 commit、milestone scope 聲稱完成但有 ticket body 顯示遺留工作。比 gate 的 per-PR 視角更寬，比人工回顧更可靠。

**Requirement**:

`/pre-release [milestone-id]`（或 `pmctl pre-release audit v0.7.0`）：

**Layer 1 — 結構檢查（機器可執行，高信心）**
- Check 1.1: 所有 milestone scope 內的 ticket 在 MILESTONES status 欄標 ✅ 且有 `pr:#NNN`（BACKLOG body 的 `**See**: pr:#NNN` 由 `lint-backlog` 負責，不在本工具範圍）
- Check 1.2: 所有 closed ticket body 無「仍待辦」/「待辦」/「TODO」殘留文字
- Check 1.3: CHANGELOG 有涵蓋 milestone commit range 內每個有 PR# 的 ticket
- Check 1.4: 所有 ticket 的 BACKLOG index status 與 body heading status 一致

**Layer 2 — 語義比對（未實作，移交 [[CC-430]]）**
- Layer 2 在本 ticket 範圍內刻意未實作。設計細節見 [[CC-430]]。

**Layer 3 — 盲點聲明（誠實邊界）**
- 明確列出工具能確認什麼、不能確認什麼
- 「我沒發現問題」≠「確定沒問題」，報告必須包含此聲明
- 特別標注：Layer 2 掃描不到「應該改但 ticket 沒提到的地方」（system topology 知識缺口）

**假設前提（相依 [[CC-404]] 完成後）**:
- 注入預算讓 agent 只拿到 priority:always + topic 相關的 memory cards（~7–10 張）
- 節省的 context window 可放 PR diff；主線程逐 ticket targeted read，不整份 diff 塞入

**Output format** (Layer 1 + Layer 3 delivered; Layer 2 → [[CC-430]]):
```
## /pre-release — <milestone-id> — <date>

### Layer 1 — Structural (machine checks)
✅ / ❌ per check with file:line reference

### Layer 3 — Blind spots
This scan cannot confirm: …

Summary: N structural issues, 0 semantic flags (Layer 2 not run), K blind spots declared.
```

**Constraints**:
- 不輸出 GO/NO-GO；輸出是報告，判斷留給人
- Layer 1 checks 必須 idempotent（不改任何檔案）
- Layer 2 每 ticket 用 targeted read，不整份 diff 塞進 context（主線程執行，見 [[CC-430]]）
- 工具名稱最終定案前暫用 `/pre-release`

**Priority**: P2（Layer 1+3 已交付；Layer 2 語義比對另開 [[CC-430]]）.

**Refs**: [[CC-404]]（注入預算 + context 效率）、[[CC-403]]（memory source query）、[[CC-405]]（card frontmatter 品質基礎）、[[CC-425]]（gate ref-pair，可複用 commit range 解析邏輯）、[[CC-430]]（Layer 2 語義比對，後續票）。

## CC-428 — memory: lifecycle validity gate for injection ranking ✅ 2026-06-26

**Goal**: Guard injection ranking against stale/superseded cards surfacing at high priority due to historical usage. A card with `status: stale` or `status: superseded` should never rank above healthy cards regardless of its frecency score.

**Context**: CC-427 introduced frecency-based sorting for MEMORY.md injection. The current sort key is `composite = keyword_tier × WEIGHT + frecency`, with `status` treated as "future staleness GC only, not injection-ranking input" (per Phase 1 committed decision). PaperGuru-Benchmark observes that lifecycle validity must gate before usage frequency — a frequently-used-but-expired card amplifies stale context. The CC-427 decision deferred this to a follow-up.

**Scope**:
- `scripts/guard-inject-memory.sh`: before computing frecency composite score, check each card's `status` field from its frontmatter; assign bucket=0 (or push to tail bucket) for `status: stale` or `status: superseded`; `status: active` and `status: archived` retain normal frecency.
- Test: add case asserting a stale card with high access_count is injected after an active card with lower frecency.
- Invariant: `priority: always` cards bypass this gate (they are always tier1 regardless of status).

**Refs**: [[CC-427]] (frecency base), [[CC-405]] (status field enforcement), PaperGuru-Benchmark lifecycle constraint.

**Priority**: P2.

**See**: pr:#332

---

## CC-429 — release: v0.7.0 closure — dogfood /pre-release + release notes ✅ 2026-06-29

**Goal**: Close the v0.7.0 release loop by using the `/pre-release` tool (CC-426) on v0.7.0 itself, fixing any drift found, and producing the final release artefacts.

**Context**: CC-426 builds the audit tool. CC-429 is the mandatory first real run of that tool — "eat your own dogfood." Without this ticket, the tool exists but is never exercised for the release it was built for. v0.5.0 surfaced the same pattern: capability present but never invoked at the right time.

**Scope**:
1. Run `/pre-release v0.7.0` (CC-426 Layer 1 + Layer 3) against the v0.7.0 milestone scope.
2. For each finding: fix CHANGELOG/MILESTONES/BACKLOG drift or document why it is acceptable.
3. Write release notes (what shipped, what was deferred, key decisions).
4. Tag `v0.7.0` and create GitHub Release.

**Non-goals**: Not a GO/NO-GO gate — CC-426 output is a report; release decision remains with the user.

**Depends on**: [[CC-426]] (/pre-release audit tool complete).

**Priority**: P1 (release blocking once CC-426 is done).

**See**: pr:#335

## CC-210 — uninstall.sh: reject managed-root exact path as deletion target ✅ 2026-06-29

**Problem**: `uninstall.sh` checks `[[ "$dst" == "$managed_root"* ]]` (startswith), which
allows `$managed_root` itself to pass. A malformed copy-mode manifest entry with a
destination equal to `$HOME/.claude` could cause the uninstaller to delete the entire
Claude config directory.

**Why**: Raised as [medium] advisory by risk-reviewer in PR #110 gate. Normal installer
manifests never create such entries, but defense-in-depth suggests rejecting the exact
root to align worst-case blast radius with "remove installed artifacts," not "remove all
Claude config."

**Requirement**: In `uninstall.sh`, before the `rm` / `unlink` call, add:
```bash
[[ "$dst" == "$managed_root" ]] && { warn "skipping managed root itself: $dst"; continue; }
```
Add a test case in `scripts/test-uninstall.sh`: manifest entry with dst == managed root
is skipped and a warning is emitted.

**Priority**: P3 — low urgency (normal manifests are safe). Fix before any public release.

**See**: pr:#340

## CC-224 — shared hook-profile inventory: doctor.sh ↔ install-guards.sh ✅ 2026-06-29

**Problem**: `scripts/doctor.sh` owns a second hardcoded minimal/full hook membership model (around line 240) that mirrors the one in `scripts/install-hooks.sh`. When a new hook is added or a profile boundary changes, it is easy to update one file and miss the other — this is a silent drift path with no compile-time check.

**Why**: Raised by critic and architecture-reviewer as [medium] advise in PR-gate `gate-20260522-100348`. The duplication became structurally significant once `--profile minimal|full|auto` was added and both files enumerate hooks by profile.

**Requirement**: Extract the managed hook list and profile classification into a shared shell helper (e.g. `scripts/hook-profile.sh`) sourced by both `doctor.sh` and `install-hooks.sh`. Alternatively, add a parity test (e.g. `test-hook-profile-parity.sh`) that parses both files and asserts the hook sets are identical for each profile tier.

**Dependencies**: CC-058（profile flag already landed）

**Priority**: P3 — maintainability; current duplication is limited to two well-known files.

**Cross-link**: CC-223（boundary fix; pair these if tackling doctor.sh again）, CC-204（hook/profile reuse debt）

**See**: pr:#341

## CC-240 — test-suite reliability follow-ups ✅ 2026-06-30

**Status**: Part (a) — suite-count derivation in `scripts/test-run-all-tests.sh` — closed via CC-219 (pr:#129); the assertions now derive expected pass/skip totals from `${#SUITE_NAMES[@]}`. Part (b) closed via this ticket.

**Problem (remaining)**: `scripts/test-portable.sh::case_mkdir_lock_contention` holds the lock with a fixed `sleep 1.2` to create contention overlap (pre-existing — not introduced by CC-203).

**Why**: Fixed-`sleep` async timing is flaky on slow / preempted CI hosts and conflicts with the qa-testing-rules AGENT.md red line on `sleep` for async synchronization — a flaky gate test erodes the gate's signal.

**Requirement**:
- `test-portable.sh::case_mkdir_lock_contention`: replace the fixed `sleep 1.2` lock-hold with an IPC / event-driven control path (e.g. a FIFO-gated holder, matching the pattern already used elsewhere in the portable-lock tests).

**Priority**: P3 — test-infra hardening; advisory follow-up, the CC-203 GO was not blocked on it.

**Cross-link**: CC-203 (origin), `scripts/test-run-all-tests.sh`, `scripts/test-portable.sh`.

**See**: pr:#344

## CC-258 — pm-write-guard hook policy revision ✅ 2026-06-29

**Problem**: `scripts/hook-pm-write-guard.sh` currently allows only `~/.claude/projects/<project>/memory/**`. Audit of 207 denies over 10 days identified 3 legitimate PM-author patterns being incorrectly denied (12 hits; the rest are red-team / regression-test traffic).

**Why**:
- `/tmp/<task-slug>/*.md` is the verbatim-as-attached-file pattern from `[[feedback_codex_brief_discipline]]` (Pattern 2). Current deny forces PM to fall back to inline embedding — the exact failure mode the pattern was written to avoid (apply_patch debug-loop hang).
- `<repo>/docs/spikes/*-scope.md` / `*-rfc.md` are PM-authorship territory; the inline-return → main-thread-write round-trip is a no-value transcription step.
- Memory writes through symlinked memory dir (`memory-private/` per `[[reference_memory_private_repo]]`) get denied because `realpath_m` chases the symlink before the allow-pattern match. Hook bug, not policy.

**Requirement**:
- Three new allow rules (A: `/tmp/[a-z][!/]*/[!/]*.md`, B: `*/docs/spikes/{CC-NNN*,*-scope,*-rfc}.md`, C: dual-normalization for symlinked memory dir via lex_path-vs-abs_path).
- New `realpath_m_lex` helper (or `realpath -s` flag) in `scripts/lib/portable.sh`.
- ~50 LoC in `hook-pm-write-guard.sh`, ~20 LoC in `portable.sh`, ~15 new test cases in `scripts/test-hooks.sh`.
- `BACKLOG.md`, `DECISIONS.md`, `agents/*.md`, `commands/*.md`, `scripts/**`, `/tmp/brief-*.md` continue to deny (verified by audit).

**Acceptance**:
- The 12 currently-denied legitimate writes succeed under the new rules.
- All 195 currently-denied non-legitimate writes (including all red-team test cases) continue to deny.
- New regression tests cover Rule A boundaries (no intermediate dir → deny, traversal → deny, nested subdirs → deny, non-.md → deny), Rule B boundaries (not under spikes/ → deny, no CC-/-scope/-rfc prefix-suffix → deny), Rule C (symlinked memory entry → allow, file-symlink-jump-out → deny).
- `pm/scripts/validate.sh` BACKLOG parity preserved.

**Milestone**: Post-M1 process tooling (not blocking M1 substrate work).

**Priority**: P3 — process improvement. Current friction is workable via inline-return + main-thread-write or `CLAUDE_HOOK_PM_GUARD=off` bypass.

**Open questions**: see spike doc §Open questions (Rule A pattern strictness — loose `[a-z]` vs require `-content` suffix; memory-private root configurability — hard-code vs env var; filename allowlist scope — pre-add `-design.md`/`-proposal.md` or wait for audit; bypass mechanism — single global vs per-rule; spike scope vs spike output split).

**See**: pr:#342; `docs/spikes/CC-258-pm-write-guard-policy.md` (full design, audit data table, code change sketch, test coverage sketch, risks + mitigations).

**Cross-link**: `[[feedback_codex_brief_discipline]]` (Pattern 2 origin), `[[feedback_spike_validation_mandatory]]` (why `/tmp/brief-*.md` stays denied), `[[reference_memory_private_repo]]` (symlink target).

---

## CC-285 — [ops] archiver safe-drop: don't drop a terminal row whose body exists nowhere ✅ 2026-06-30

**Problem**: `scripts/archive-closed-backlog.sh` drops a terminal index row (`✅ closed` / `🚫 dropped`) even when no body section accompanies it in BACKLOG.md and none already exists in BACKLOG-ARCHIVE.md. It emits a per-id stderr warning, but the row metadata is removed (recoverable only via git).

**Why**: In a valid backlog this cannot happen — `pm/scripts/validate.sh` enforces an index↔body 1:1 invariant, so a terminal row always has a body to archive. It only arises from malformed/partial state. Recorded as an accepted tradeoff in DECISIONS 2026-05-30. This ticket tracks the defense-in-depth improvement if that invariant ever weakens.

**Requirement**:
1. When a terminal row's body is found in neither BACKLOG.md (this run) nor BACKLOG-ARCHIVE.md, do NOT drop the row; keep it and emit a loud warning for manual reconciliation.
2. Regression fixture: terminal row + no body anywhere → row preserved + warning (not removed).

**Cross-link**: `[[CC-284]]` (working-set contract / archiver), pr-gate finding on PR #186.

**See**: pr:#343

## CC-420 — refactor: adapter 共用 model alias TSV 解析抽 lib ✅ 2026-06-30

**Problem**: claude/codex/opencode 三個 adapter 各自重複相同的 model alias TSV 解析邏輯（約 30 行 × 3）。

**Why**: 三份複製體確保任何欄位調整或 alias 格式變化都要改三處，且測試覆蓋分散——實際上三個 adapter 讀同一份 TSV 格式，解析邏輯 byte-identical。

**Requirement**: 抽 `scripts/lib/model-aliases.sh` 提供 `ma_resolve_alias <adapter> <alias>` 函式；三個 adapter source 該 lib 並刪除各自的重複邏輯；`test-model-aliases.sh` 直接測試 lib；現有 adapter 測試的 alias 行為路徑不得退化。不改 TSV schema 或 alias 語意。

**Acceptance**:
- `bash scripts/test-model-aliases.sh` 通過。
- 三個 adapter 的 model alias 行為與今天 byte-identical（現有 adapter 測試綠）。
- `lint-model-aliases.sh` 仍通過。

**See**: pr:#345

**Priority**: P3（someday）。

## CC-421 — refactor: adapter 共用 timeout 優先序邏輯抽 lib ✅ 2026-06-30

**Problem**: 三個 adapter 與 `dispatch-post-verify.sh` 均有相同的 timeout 優先序模式（flag > env > config > default），約 15 行 × 4 處重複。

**Why**: timeout 優先序若需調整（例如加 config 層級或改 default 值），須改 4 處且各處行為需保持一致；目前缺乏單一 source of truth。

**Requirement**: 抽 `scripts/lib/timeout-resolve.sh` 提供 `tr_resolve_timeout <flag_val> <env_var_name> <config_key> <default>` 函式；四個呼叫方改用此函式；現有測試的 timeout 行為路徑不得退化。不改 timeout 語意或預設值。

**Acceptance**:
- 四個呼叫方（claude/codex/opencode adapter + dispatch-post-verify）行為與今天 byte-identical。
- 新增 `test-timeout-resolve.sh` 覆蓋 flag > env > config > default 四層優先序。

**See**: pr:#346

**Priority**: P3（someday）。

## CC-422 — refactor: adapter 共用 dispatch 初始化邏輯抽 lib ✅ 2026-06-30

**Problem**: claude/codex 兩個 adapter 有約 200 行高度相似的 dispatch 初始化邏輯（snapshot、isolation map 解析、brief 讀取、run-dir 建立）。

**Why**: 兩份複製體讓 dispatch 核心流程改動需同步兩處，且介面不一致時 bug 只在一個 adapter 出現——歷史上 CC-414 的 trace-dir seam 就因此需要在三個 adapter 各自加一次。opencode 在此已有部分分歧（isolation 翻譯不同），須仔細界定共用邊界。

**Requirement**: 分析 claude/codex/opencode 三個 adapter 的 dispatch 初始化，識別可安全共用的部分（純 setup：snapshot、brief parse、run-dir 建立）與必須保持 per-adapter 的部分（isolation 翻譯、native flag 傳遞）；抽出前者到 `scripts/lib/dispatch-common.sh`；後者維持 per-adapter。不改任何可見行為。

**Acceptance**:
- 三個 adapter 的 dispatch 行為與今天 byte-identical（現有 adapter 測試全綠）。
- 新增 `test-dispatch-common.sh` 覆蓋被抽出的共用函式。
- `dispatch-common.sh` 不引入跨 adapter 的隱式耦合（isolation 翻譯仍 per-adapter）。

**Note**: dispatch-common 涉及 adapter 核心邏輯，重構前須先確認三個 adapter 的分歧點；建議在實作前做 spike 確認介面邊界。

**Priority**: P3（someday）。

**See**: pr:#347

## CC-430 — release: `/pre-release` Layer 2 — 語義比對 ✅ 2026-06-29

**Problem**: CC-426 Layer 1 只驗結構標記（✅/PR ref/CHANGELOG mention），無法確認 PR diff 是否真的滿足 ticket 的 Requirement——ticket 說改 X/Y/Z，diff 只改了 X/Y 的情況在 Layer 1 完全偵測不到。

**Why**: Layer 2 補上「需求 vs 實作」的語義比對層，讓 `/pre-release` 報告從「tracking hygiene 乾淨」升級到「實作覆蓋可追溯」。Layer 1 是必要前提（穩定的結構資料讓 diff mapping 可靠），Layer 2 是增值層。

**Requirement**:

承接 [[CC-426]] Layer 2 設計：

**主線程執行策略**
- 主線程逐 ticket 讀取 BACKLOG 的 Requirement 章節
- 對應 PR diff 摘要由主線程取（`gh pr diff <PR#>`）
- 主線程內聯分析覆蓋度，輸出 per-ticket 結論
- 可取 `pmctl context query --source memory` 相關 decision 背景輔助判斷

**Output 格式（追加至 Layer 1 + Layer 3 報告後）**：
```
### Layer 2 — Semantic coverage
| Ticket | Requirement summary | Diff coverage | Confidence | Flag |
```

**Constraints**:
- 主線程執行，不派發子 job（閱讀理解任務，主線程直接處理）
- PR diff 由主線程自行取，每 ticket targeted read，不整份 diff 一次塞入
- 不輸出 GO/NO-GO；報告判斷留給人

**Depends on**: [[CC-426]]（Layer 1 穩定基礎）、[[CC-403]]（memory context query）、[[CC-404]]（注入預算）。

**Priority**: P1（v0.7.1）. CC-429 dogfood run 完成後升 P1（2026-06-29）；CC-426 Layer 1 穩定、依賴 CC-403/CC-404 全 ✅。

**See**: pr:#339

## CC-276 — feat: persistent gate override declarations to reduce re-statement across rounds ✅ 2026-06-19

**See**: pr:#301 (2026-06-19) — delivered ahead of v0.8.0 Phase 2 planning; `--override-file`/auto-discovery, brief injection, and provenance audit all shipped with full test coverage in `scripts/test-pr-gate.sh` (override-file-autodiscovery, override-file-explicit-flag, override-file-missing-errors, override-file-injected-parallel-reviewer/synthesis, override-provenance-in-result, etc.)

**Problem**: Each `pr-gate.sh` run spawns fresh reviewer sessions with no memory of previous rounds. When users consciously accept a known risk (storage cleanup failure, Docker unavailable in sandbox, etc.) and provide an override declaration, Round N+1 reviewers see the same code with no context of the previous override and re-block. Users must re-state identical override declarations every round. Observed: 9+ rounds on a single PR primarily due to re-blocking on already-accepted known risks.

**Requirement**:
- `pr-gate.sh` accepts `--override-file <path>` flag (Option A) OR auto-discovers `.gate-overrides.md` at repo root (Option B)
- Override file format: freeform markdown with per-reviewer override declarations (see issue for example)
- Reviewer brief preamble injects override content with instruction: "Do not re-block on these specific items unless the diff changes the risk materially"
- When no override file is present, behaviour is unchanged (backward compatible)

**Override file example** (`.gate-overrides.md`):
```markdown
## Gate Overrides (permanent, owner-accepted)

- [security] I accept that storage cleanup may fail after DB anonymization.
  Accepted: 2026-05-20. Owner: @screenleon.
- [risk] Docker is unavailable in the gate sandbox; integration tests pass locally.
  Accepted: 2026-05-20. Owner: @screenleon.
```

**Acceptance**:
1. `bash scripts/pr-gate.sh --cd . --override-file .gate-overrides.md` — override content injected into all 5 reviewer prompts
2. Reviewers that previously blocked on an overridden item return pass/advise (not block) when the diff is unchanged
3. `bash scripts/test-pr-gate.sh` → exit 0 (new test covering override injection)
4. No override file → behaviour identical to today

**area**: gate/process
**Raised by**: issue:#174 (2026-05-28)
**Priority**: P2 — DX improvement; reduces friction on PRs with known-accepted risks across multi-round gate iteration.

## CC-412 — memory substrate 跨工具可攜（decouple from Claude-specific location + injection） ✅ 2026-07-01

**Problem**: 專案記憶目前綁兩處 Claude 專屬實作，使「跨 AI 工具/agent（codex、opencode、未來 host）共用同一份專案記憶」困難：(1) `find_memory_dir`（`scripts/lib/memory.sh`）的目錄慣例寫死 `CLAUDE_CONFIG_DIR/projects/<encode(cwd)>/memory/`；(2) MEMORY.md 的每-session 注入靠 Claude Code 的 UserPromptSubmit hook，其他工具沒有等價 hook，既無法定位也無法注入。

**Why / 決策分析（此 ticket 即 decision record）**:
- **已可攜的部分**（CC-405 剛強化，刻意做成工具中立）：卡片＝純 Markdown+YAML；`pmctl memory doctor`、`pmctl context --source memory`（[[CC-403]] 的中立檢索 API）；memory 衍生 DB；[[CC-405]] frontmatter schema（topics/priority/status/...）。標準化反而**降低** Claude 耦合——把記憶從「memory-graph 工具的不透明附屬品」變成 pmctl 可檢查、可檢索的結構化資料。
- **真正耦合僅兩處**：位置 resolver + 注入機制。`metadata.node_type`/`originSessionId` 是 Claude memory-graph 的 additive 標籤，YAML 忽略未知鍵，**不阻礙**其他工具（[[CC-405]] spike 已明訂禁止移除 `metadata` block，正是為了不鎖死）。
- **決策方向**：不打掉重練、不移除任何東西；**加兩個 seam**。

**Requirement**:
- **位置 seam**：`find_memory_dir` 支援顯式 `PM_MEMORY_DIR`（或 config `dispatch.memory_dir`）覆寫，解析優先序明確（env > config > `CLAUDE_CONFIG_DIR` 慣例）；`memory doctor` / `context --source memory` / `mem-*` 全部走同一解析。未設時行為與今天 byte-identical（向後相容 load-bearing）。
- **注入 adapter 化**：文件化「**可攜核心＝pmctl retrieval API**；注入＝per-tool adapter」。Claude UserPromptSubmit hook 為現成 adapter；其他工具不靠 hook，改主動呼叫 `pmctl context --source memory` 取記憶。
- 下游 [[CC-404]]/[[CC-406]]/[[CC-407]] 應建在 retrieval API 上、而非 Claude 注入機制上。

**Acceptance**:
- 設 `PM_MEMORY_DIR` 後 `pmctl memory doctor` / `pmctl context --source memory` 解析到該目錄；未設時與今天行為一致。
- docs 說明跨工具取記憶走 `pmctl context --source memory`（注入為 per-tool adapter）。
- 不破壞 Claude 路徑預設；`metadata` block 維持不動。

**Sequencing / relation**: 與 [[CC-011]]/[[CC-012]]（記憶**跨裝置** sync：symlink/pull）**正交**——那是同一份 memory 跨機器，本票是同一份 memory **跨工具**可攜；兩者可共用「位置不再硬綁 ~/.claude」這個 seam。建在 [[CC-403]] retrieval API 上。

**See**: pr:#352

**Priority**: P3（someday）。

## CC-423 — gate detached lifecycle ✅ 2026-07-01

**See**: pr:#353 — 全需求交付：`--lifecycle detached`（現為預設）+ `scripts/gate-supervisor.sh` + `pmctl gate wait` + result 完整性 fail-closed（GO/NO-GO sentinel 若缺 result 或 `gate_result_verify` 失敗即回報失敗，不可信的結果不會被誤判成功）+ `--cd` partition 綁定（`gate wait` 現在會驗證 `--cd` 是否真的擁有該 gate_id 的 run dir）+ `/pr-gate` 兩步流程（每個 Bash 呼叫皆自給自足，不依賴跨呼叫 shell 變數）。7 輪 pr-gate 迭代收斂，最終 full tier 5-reviewer 全數 approve/pass，零 finding。

**Problem**: `pmctl gate run` 目前以 foreground 模式執行（無 lifecycle 選項），透過 Claude Code harness 的 `run_in_background: true` 監控。Session interrupt 會讓 harness 遺失對 gate process 的追蹤，回報錯誤的 exit code（同 CC-418 之前 dispatch 的問題）。

**Why**: dispatch 已透過 `--lifecycle detached`（nohup/setsid + sentinel 機制）完全解耦，gate 應有對等能力。Gate 跑 3-5 分鐘，風險低於 dispatch（30+ 分鐘），但架構上仍是同一個缺陷：process 存活與否取決於 harness 是否在線。

**Requirement**:
- `pmctl gate run --lifecycle detached` 立即回傳 `gate_id`（格式：`gate-<ts>-<rand>`），exit 0
- `scripts/gate-supervisor.sh`：以 `nohup/setsid` 啟動 `pr-gate.sh`，完成後寫 sentinel（複用 dispatch sentinel 機制：`/tmp/pm-gate-sentinel-<gate_id>-<nonce>`）
- `pmctl gate wait <gate_id> --cd <work_dir>`：輪詢 sentinel，完成後輸出 `gate: <gate_id>  state: <GO/NO-GO>  exit: <N>`，exit 代碼等同 sentinel
- `/pr-gate` skill 改為兩步：(1) detached launch → gate_id，(2) `pmctl gate wait` in background
- 維持 `--lifecycle foreground` 作為 backward-compat 選項（預設改 detached）

**Acceptance**:
- `pmctl gate run --lifecycle detached` 回傳 gate_id 並立即退出
- Session interrupt 後 gate 繼續執行，`pmctl gate wait` 在新 session 中可重新等待結果
- gate result file 路徑仍從 gate run dir 讀取（已有 gate-20xxx 格式）
- `pmctl gate run --lifecycle foreground` 行為不變（backward-compat）

**See**: dispatch sentinel 實作於 `scripts/dispatch-supervisor.sh`、`scripts/lib/pmctl-dispatch.sh`（`pmctl_dispatch_run_detached`、`pmctl_dispatch_wait`）可參考複用。

**Priority**: P3（someday）.

## CC-425 — gate: 解除 PR 綁定，改以 base..head ref 對為輸入 ✅ 2026-07-02

**See**: pr:#355

**Resolution**: 盤點現有程式碼後發現票面描述的兩個問題中，一個已在先前重構中解決：`pmctl gate run`（detached lifecycle，CC-423）的 result 存放路徑早已改用 `gate_id`（`sw_project_run_dir`）而非 PR#；foreground 路徑的 `--output` 預設值也是 `.gate-results/gate-<ts>.md`（timestamp-based），並非 PR# key。`--base <ref>` 亦已存在且可在無 PR 情況下運作（`gh pr view` 失敗會 fallback 到 `origin/HEAD` symbolic-ref，不 hard-fail）。真正缺的是 `--head <ref>`：diff 邏輯之前寫死比對 `HEAD`（當前 checkout），無法比較兩個任意固定 ref（如 tag-to-tag、或未 checkout 的 branch）。

新增 `pr-gate.sh --head <ref>`：省略時維持現有行為（working tree / 當前分支 fallback）；指定時走獨立分支，採與既有 `--base` 相同的 merge-base（three-dot）語意 `git diff "$BASE"..."$HEAD_REF"`（比較 head 相對 merge-base 的變更，而非字面 two-dot tree diff——base 之後的獨立進展不會滲入 diff），不觸碰 working tree 或 dirty-preflight 邏輯，因此與 `--allow-dirty`（其存在目的是把 working tree 折入 scope）明確互斥並拒絕（exit 2）。Reviewer brief context block 在 `--head` 生效時額外顯示 `Head: <ref>` 一行。`pmctl gate run` 兩條路徑（foreground exec 與 `--lifecycle detached` 透過 `gate-supervisor.sh` 的 `--` passthrough）皆無需改動即可轉發 `--head`，因為都是把未知旗標原樣傳給 `pr-gate.sh`。`--help` usage block 與 unknown-arg 提示同步補上並釐清 three-dot 語意。

**Gate 第一輪 NO-GO（critic block-soft + qa-tester block）修復**：(1) 補 `--head` 缺 operand 的受控錯誤（原本會以 raw `unbound variable` crash，比照 `--override-file` 加 guard）；(2) 補 diverged base/head 拓樸測試（`test_head_override_merge_base_semantics`：main 與 feature 各自獨立前進，驗證 three-dot 只看 head 相對 merge-base 的變更、不含 base 的獨立進展）；(3) 全文（`--help`、code comment、本 resolution）統一明確標註 three-dot/merge-base 語意，避免與字面 `base..head` two-dot tree diff 混淆；(4) 修正 MILESTONES.md Phase 2 註記與已完成列矛盾的過期文字。第二輪 5 個 `--head` 測試（原 3 + 新 2）、`scripts/test-pr-gate.sh` 共 124 項全數通過；`test-gate-lifecycle.sh`/`test-pmctl-gate.sh`/`test-pr-gate-profile.sh` 無回歸。

**Priority**: P3（someday）.

## CC-432 — run-all-tests.sh 耗時調查：test-release-verify/test-pmctl-context 序列瓶頸 ✅ 2026-07-02

**See**: pr:#354

**Resolution**：三方獨立分析（主線程讀源碼＋codex read-only dispatch＋外部 ChatGPT 分析）收斂到票面 A/B 兩個候選之外的「方向 C」：`test-release-verify.sh` 的 12 個裸 `--no-suite` 測試函式各自獨立重跑完整 Phase 1+3+3b+3c smoke，只為斷言輸出裡不同子字串——改成 `rv_no_suite_once()` 懶初始化共用快取後，這 12 個測試改讀同一份快取結果（3 個 `--e2e` stub 變體維持獨立不受影響）。`release-verify.sh` 本體零改動，46 項既有斷言數量與行為不變。實測 `test-release-verify.sh` 耗時 380s → ~127s（降幅 ~66%）。
- 方向 A（Phase 3 smoke 改用隔離假 repo）：評估後**不採用**——`release-verify.sh` 的 `REPO_ROOT` 寫死自身腳本所在 repo 且無 override 參數，Phase 3 有專屬斷言 `external-repo-db-location` 驗證「pmctl context 在真實/大型 repo 上行為正確」，改用假 repo 會牴觸「release-verify.sh 不可弱化」的硬限制。
- `LIVE_DB_EXCLUSIVE`（`test-release-verify`/`test-pmctl-context` 因共用真實 repo `context.db` 被迫序列，合計 558s）本身的序列化耦合：評估後**擱置不追**——互斥窗是整個 `test-pmctl-context` 套件期間（guard 斷言只在套件中段跑一次，比對套件開始到該 case 之間的 fingerprint），要縮小窗口須拆分套件、改動 `run-all-tests.sh` 共用排程器，風險層級高於單一測試檔改動，效益（可再省的時間）不足以抵銷風險。未來若有需要可重新評估，非排入 someday backlog。

**Problem**: 使用者在 CC-423 pr-gate 迭代過程中反映 `scripts/run-all-tests.sh` 單次執行超過 10 分鐘，要求排查瓶頸。逐一計時全部 65 個套件（`bash <suite>.sh` 個別量測，非平行）後的實測數據：

| 套件 | 耗時 |
|---|---|
| `test-release-verify` | 380s |
| `test-pmctl-context` | 178s |
| `test-pmctl-dispatch` | 156s |
| `test-dispatch-lifecycle` | 100s |
| `test-install` | 75s |
| 其餘 60 個套件合計 | ~296s |

**根因分析**：`test-release-verify` 與 `test-pmctl-context` 兩者因共用真實 pm-dispatch repo 的 `.pm-dispatch/ctx/context.db`，被 `scripts/run-all-tests.sh` 的 `LIVE_DB_EXCLUSIVE` 機制強制序列（不可平行）——`test-pmctl-context` 斷言這份 DB 在整個套件執行期間不可變動，而 `test-release-verify` 的 Phase 3 會對同一個真實 repo 重新索引、重建同一份 DB，兩者並行會互踩。兩者合計 558 秒（9.3 分鐘），即使其餘 63 個套件在 8-way 平行下瞬間跑完，光這個序列鎖就佔滿使用者觀察到的整個等待時間。

`test-release-verify.sh` 對 `scripts/release-verify.sh` 呼叫 25 次（涵蓋各種旗標組合的行為驗證），其中多次即使帶 `--no-suite`，仍會執行 Phase 3（對真實 repo 跑 `pmctl context index/query/pack/reuse-scan`）；單次 `pmctl context index` 約 2.5 秒，乘以 20 幾次呼叫、每次多個子指令，疊加成 380 秒。

**Why P2 而非直接排入本 sprint 實作**：解法尚未定案，需要先深入分析利弊再規劃範圍，不應該在還沒釐清設計前就急著動手：
- 方向 A：讓 `test-release-verify.sh` 的 Phase 3 smoke 改用隔離的假 repo（而非真實 pm-dispatch repo 本身），移除與 `test-pmctl-context` 的互斥前提，兩者即可平行跑——但需確認 Phase 3 smoke「驗證 pmctl context 在真實/大型 repo 上行為正確」的目的是否會因改用假 repo 而打折扣。
- 方向 B：讓 25 次呼叫中大多數案例透過某種旗標跳過 Phase 3，只留真正需要驗證 Phase 3 行為的少數案例執行——需要盤點這 25 個案例各自實際在測什麼，避免跳過後產生覆蓋率死角。
- 也可能有方向 A/B 之外的做法（例如快取索引結果、降低 Phase 3 涉及的子指令數），需要實際盤點 `test-release-verify.sh` 的 25 個案例後才能收斂。

**Requirement**: 待分析完成後再具體化；預計走 `/pre-impl` 或 `/spike` 先收斂設計方向，再拆成實作票。

**Trigger**: CC-423（gate detached lifecycle）pr-gate 迭代過程中，使用者對「run-all-tests.sh 執行超過 10 分鐘」提出疑慮並要求逐一計時排查根因（2026-07-01）。

**area**: ops/test
**Priority**: P2 — 不阻塞 CC-423，但影響日常開發迭代速度，排在下一個 PR 優先分析規劃。

## CC-433 — detached lifecycle：抽共用 sentinel lib + wait 改主動通知 ✅ 2026-07-02

**See**: docs/spikes/CC-433.md

**Problem**：CC-423（gate detached lifecycle）實作時直接照抄 `scripts/dispatch-supervisor.sh` 的 setsid/nohup 啟動 + nonce-authenticated sentinel 寫入模式，寫出 `scripts/gate-supervisor.sh`，兩份檔案在「啟動 detached process + 寫 sentinel」這塊結構相同（`_write_sentinel`/`_die` 的形狀、`/tmp/pm-*-sentinel-<id>-<nonce>` 命名、per-user mode-700 key 目錄）卻各自重寫，沒有抽共用 lib。

另外，`pmctl dispatch wait <run_id>` 與 `pmctl gate wait <gate_id>` 目前都是輪詢實作：`while true; do [[ -f "$sentinel" ]] && ...; sleep "${POLL_INTERVAL:-2}"; done`。這代表 wait 呼叫平均要多等最多一個 poll interval 才能發現 supervisor 已完成，且長時間執行期間持續喚醒進程檢查檔案是否存在，而非讓 supervisor 完成時主動通知等待中的 wait。

**Why**：
- 重複程式碼：sentinel 寫入/驗證/清理邏輯目前有兩份幾乎相同的實作（`pmctl-dispatch.sh` 的 `_pmctl_sentinel_key_file`/`pmctl_dispatch_wait` 與 `pmctl-gate.sh` 的 `_pmctl_gate_sentinel_key_file`/`pmctl_gate_wait`），日後改其中一份的行為容易忘記同步另一份（已在 CC-423 實作中發生：gate 側的 result 完整性 fail-closed 邏輯是 dispatch 側原本沒有的，兩邊已經開始各自演化）。
- 輪詢的效率/延遲問題：poll interval 預設 2 秒，代表 wait 呼叫最多要多等 2 秒才會回報完成，且整個等待期間都在忙輪詢（即使是低成本的 `sleep`），而非事件驅動。

**Requirement**（待 `/pre-impl` 或 `/spike` 收斂，以下為方向候選，未定案）：
- 共用 lib 化：抽出 `scripts/lib/detached-launch.sh`（或類似命名），提供通用的 `write_sentinel`/`launch_under_setsid`/nonce-key-file 管理函式，讓 `dispatch-supervisor.sh`/`gate-supervisor.sh` 與 `pmctl_dispatch_wait`/`pmctl_gate_wait` 都基於同一套實作，各自只保留獨有邏輯（dispatch 的 adapter/guard preflight + `pmctl_dispatch_execute_tail`；gate 的直接 exec pr-gate.sh + result 完整性檢查）。
- 輪詢改主動通知：評估可行機制，例如 (a) named pipe/FIFO：supervisor 完成時寫入 FIFO，wait 用 blocking read 而非 `sleep` 迴圈喚醒；(b) `inotifywait`（若目標平台可穩定安裝該工具）監控 sentinel 檔案建立事件；(c) 其他 IPC 機制。需評估跨平台相容性（尤其 CI/macOS/WSL2）與現有 fail-closed／timeout／indeterminate（exit 3）語意是否受影響。
- 兩項改動涉及安全敏感的 supervisor 檔案（尤其 dispatch 側有完整 preflight 防禦），需謹慎規劃測試涵蓋範圍，避免共用化過程中意外弱化 dispatch 的安全邊界。

**Investigation scope**：
1. 共用 lib 邊界：比對 `scripts/dispatch-supervisor.sh` 與 `scripts/gate-supervisor.sh` 的 setsid/nohup 啟動 + sentinel 寫入/nonce-key-file 管理邏輯，界定可抽出到 `scripts/lib/detached-launch.sh` 的共用函式，以及各自必須保留的獨有邏輯（dispatch 的 adapter/guard preflight + `pmctl_dispatch_execute_tail`；gate 的直接 exec pr-gate.sh + result 完整性檢查），並確認抽出不弱化 dispatch 側現有 security preflight。
2. Poll→通知機制：評估 FIFO blocking read / `inotifywait` / 其他 IPC 在 CI、macOS、WSL2 三個目標平台的可行性與相容性，並確認選定機制下 `pmctl dispatch wait`/`pmctl gate wait` 既有的 fail-closed／timeout／indeterminate（exit 3）語意維持不變。

**Done-when**：`docs/spikes/CC-433.md` 對上述兩項各給出明確建議（含至少一個實際 call site 的 pilot walkthrough，建議先遷移 gate 側，blast radius 較低），並標註 GREEN/AMBER/RED 可行性判定；後續實作票依此結果撰寫。

**Result log**：完成，見 `docs/spikes/CC-433.md`（2026-07-02）。判定：共用 lib 抽取 **GREEN**（7/8 函式可乾淨抽取到 `scripts/lib/detached-launch.sh`，`resolve_repo_root` 因循環依賴保留 inline，邊界清楚、無安全弱化，建議開 CC-433a 實作）；poll→通知機制遷移 **AMBER**（mkfifo blocking read 技術可行且延遲大幅改善，但 multi-waiter 並發下有資料損毀風險，需先設計 single-waiter guard 才可採用，本輪維持輪詢）。

**Trigger**：CC-423（gate detached lifecycle）pr-gate 迭代後，使用者檢視 `scripts/gate-supervisor.sh` 與 `scripts/dispatch-supervisor.sh` 的重複程度，並注意到 wait 端目前是輪詢實作，要求記錄為後續改善票（2026-07-01）。

**area**: arch/gate
**Priority**: P3（someday）。
**Cross-link**: [[CC-423]]、[[CC-432]]、[[CC-434]]。

## CC-434 — detached lifecycle：抽共用 sentinel lib scripts/lib/detached-launch.sh ✅ 2026-07-02

**See**: pr:#356

**Problem**：CC-433 spike（`docs/spikes/CC-433.md`）判定共用 lib 抽取為 GREEN——`dispatch-supervisor.sh`/`gate-supervisor.sh` 在啟動 detached process + 寫 sentinel 這塊今天是逐位元組相同的實作，但各自重寫，維護成本已在 CC-423 實作中顯現。本票落地該建議。

**Requirement**（依 spike Pilot walkthrough 收斂，非待定案）：
- 新增 `scripts/lib/detached-launch.sh`：7 個共用函式（`detached_launch_generate_nonce`、`detached_launch_key_file`、`detached_launch_secure_key_dir`、`detached_launch_write_key_file`、`detached_launch_sentinel_path`、`detached_launch_under_setsid`、`detached_launch_write_sentinel`、`detached_launch_wait_for_sentinel`）。
- `resolve_repo_root`（symlink 解析）因 bootstrap 循環依賴（腳本要先解出 REPO_ROOT 才能 source lib）**保留 inline** 於 `dispatch-supervisor.sh`/`gate-supervisor.sh` 頂端；加一個 fixture 測試以 marker-comment 框住兩處區塊、逐字 diff，防止未來修改其中一份卻忘了同步另一份。
- `gate-supervisor.sh`/`pmctl_gate_wait`（`scripts/lib/pmctl-gate.sh`）與 `dispatch-supervisor.sh`/`pmctl_dispatch_wait`（`scripts/lib/pmctl-dispatch.sh`）都改用共用函式；wait 端沿用輪詢（`detached_launch_wait_for_sentinel`），不動 IPC 機制（CC-433 spike 判定 poll→通知遷移 AMBER，未收斂）。
- dispatch 側所有安全預檢查（native-arg 走私防護、adapter 解析、brief 驗證、guard check、run-spec schema 驗證、brief-snapshot 路徑相等性清理）**零改動**，不進共用 lib。
- gate 側特有邏輯（`gate_result_verify` 結構完整性檢查、`--cd`→run-dir 包含關係比對、timeout 提示文字）**零改動**，維持在 `pmctl-gate.sh`。
- sentinel 檔名/key-dir 路徑命名維持與現況位元組相同（`/tmp/pm-supervisor-sentinel-<run_id>-<nonce>`、`/tmp/pm-gate-sentinel-<gate_id>-<nonce>`、`pm-dispatch`/`pm-gate-dispatch` key-dir namespace），純委派實作、不改變任何對外行為。

**Done-when**：`scripts/lib/detached-launch.sh` 落地並被兩側 supervisor + wait 函式使用；REPO_ROOT inline 區塊漂移守衛測試存在且通過；既有 dispatch/gate lifecycle 測試套件（`test-dispatch-lifecycle.sh`、`test-gate-lifecycle.sh`、`test-pmctl-dispatch.sh`、`test-pmctl-gate.sh` 等）全數通過，無行為變化；`run-all-tests.sh` 全套綠燈。

**area**: arch/gate
**Priority**: P2。
**Cross-link**: [[CC-433]]、[[CC-423]]、[[CC-435]]。

## CC-381 — arch: install host-PM-aware ✅ 2026-07-02

**Problem**: `install.sh` / `install-hooks.sh` 把整個安裝面寫死成 claude harness：PreToolUse/SessionEnd 等 hook 接進 `~/.claude/settings.json`、reviewer 與 dispatch 的 `permissions.allow`、statusline、以及 `agents/` `commands/` 的 PM 介面，全部假設「claude 是 host PM」。一旦 codex（或未來 host）當主 PM，這些都不對：codex 的設定面是 `~/.codex/` ＋ `AGENTS.md` ＋自有 sandbox/approval 模型，沒有 `~/.claude` 那套 PreToolUse hook。[[CC-334]]/[[CC-380]] 把 reviewer guard 與 allow-list 寫進 `~/.claude/settings.json`——在 codex-host 下根本不載入，等於 codex-PM 安裝拿不到任何 gate/guard plumbing。

**這是哪條軸**: 「誰當 host PM」的軸，與目前 v0.6.0 在做的「PM→executor」軸（[[CC-373]]/[[CC-374]]）**正交**。runner_kind（[[CC-372]]）解的是「被驅動的 executor 怎麼到達」；本票解的是「驅動者（host PM runtime）的安裝/設定面」。對應 [[CC-333]] 七耦合的 **layer 4（install 路徑 `~/.claude/`）＋ layer 3/5（hook 機制／設定格式）**，memory 已標記為「later」。

**Requirement**:
- install 變 host-PM-aware：對每個支援當 PM 的 host runtime，由 manifest 衍生該 host 的等價設定 target＋format（hook/guard 接線、allow-list 或 sandbox/approval policy、PM 命令介面），而非寫死 `~/.claude/`。
- 與 [[CC-372]] runner_kind ＋ [[CC-375]]（manifest 衍生接線）對齊：host 的「設定面在哪、長怎樣」應是 manifest 宣告，不是程式碼常數。
- 每個 host 維持 install / uninstall / doctor 三方一致（[[CC-368]] 教訓），並各自有回歸測試。
- 釐清跨 host 的 guard 落點：claude-host 走 `~/.claude` PreToolUse hook；codex-host 需把對應 guard 放進 codex 的攔截點（或退回 cli-only 由 `pmctl guard check` 撐）。**Update 2026-06-14（user）**：Codex 現在已有 hook 機制（可能不完全）——所以 codex-host 不必只能走 cli-only fallback，可評估把 write/bash guard 接進 codex 原生 hook（對齊 [[CC-372]] `write_guard_mode=hook`），是本票把 install 變 host-aware 時要勘的能力。`docs/executor-contract.md` 已不再斷言「非 Claude host 無 PreToolUse 等價」。

**Non-goals**: 不是 executor 軸（[[CC-373]]/[[CC-374]] 已涵蓋 PM→codex/claude/opencode/agy 的 dispatch）；本票只管「host PM runtime 的安裝設定面」。不在本票決定 codex-host 的最終 hook 機制細節——先把 install 的 host 分派抽象出來。

**Sequencing**: 排在 v0.6.0 executor-abstraction 核心（[[CC-373]]..[[CC-377]]）之後；可能落在 v0.7.0（與 [[CC-333]] layer 1/7、MCP 同期評估）。

**Outcome**: v0.8.0 Phase 3 spike 完成並收斂（`docs/spikes/CC-381.md`）——三方獨立分析（主線程 BACKLOG/決策脈絡視角、codex read-only 對自身 hook runtime 的實測、chatgpt 外部架構視角）。guard 落點的最大不確定性已解：codex `PreToolUse` hook 經 codex 自己實測（`codex features list`/`codex doctor --json`/binary 字串）證實 stable 且 fail-closed，足以承接 write/bash guard，不必退回 cli-only fallback。本票收斂為三張後續票：[[CC-436]]（payload 驗證 probe，唯讀，第一刀）、[[CC-437]]（doctor 擴充切片，可與 CC-436 並行）、[[CC-438]]（host manifest schema v1 draft，依賴 CC-436）。`install.sh` write path 仍不動，留給後續票。
**See**: pr:#359

---

## CC-436 — codex-host PreToolUse payload 驗證 probe ✅ 2026-07-06

**Problem**: [[CC-381]] spike（`docs/spikes/CC-381.md`）已用唯讀證據（`codex features list`/`codex doctor --json`/binary 字串反查）確認 codex `PreToolUse` hook 是 stable 且會 fail-closed 阻擋，但尚未實際跑過一次 end-to-end 的 hook 阻擋，也不知道 payload 內容能否映射到 `pmctl guard check --file/--command` 需要的欄位。

**Why**: 這是 [[CC-381]] 收斂矩陣認定的「最小風險、最高信號」第一刀——payload 欄位不足會直接限制 codex-host guard binding 的設計空間（例如只能擋 command 不能擋 file path），必須在寫 host manifest schema（[[CC-438]]）前確認。

**Outcome**: probe 完成，實測結果見 `docs/spikes/CC-436.md`。關鍵發現：(1) hook 設定格式是 `$CODEX_HOME/hooks.json`，與 Claude Code `settings.json` hooks 區塊相容，不是獨立 `config.toml` schema；(2) command 與 file-write 兩種動作皆實測 fail-closed 阻擋成功；(3) Bash/command payload 欄位齊全可直接映射 `pmctl guard check --command`，但 `apply_patch`（file-write）payload 沒有獨立 `file_path` 欄位，路徑內嵌在 patch 文字裡，需要額外 parser；(4) headless `codex exec` 若不帶 `--dangerously-bypass-hook-trust` 會無限期掛起（非 fail-closed 拒絕），這個 flag 對 codex-host dispatch 路徑是必要參數而非可選。建議：往 [[CC-438]] 推進但 schema 需區分 command/file 兩種覆蓋度不對稱；繼續保留 `write_guard_mode: cli-only` 當 fallback。

**Dependencies**: 承接 [[CC-381]] spike 建議「第一刀」。umbrella [[CC-333]]。
**See**: `docs/spikes/CC-436.md`

---

## CC-437 — doctor 擴充切片：host-aware capability check ✅ 2026-07-06

**Problem**: `scripts/doctor.sh` 目前四處寫死 claude-host 路徑（`check_settings_file`/`check_hooks`/`check_dispatch_allowlist`/`check_manifest`），無法回答「目前 host 是 claude/codex/opencode？哪些能力有 wiring？哪些只能透過 pmctl 手動使用？」。

**Why**: [[CC-381]] spike 三方一致收斂：doctor 應以 capability（`command_guard`/`session_lifecycle`/`pm_command_interface`/`statusline` 等）為檢查單位，而非以 host 為單位；核心跑通用檢查、host-specific 邏輯外移，未來加新 host 才不必改 doctor 核心。此切片唯讀、風險最小，可與 [[CC-436]] 並行。

**Requirement**:
- `doctor.sh`（或 `pmctl doctor`）拆出通用核心檢查與 host-specific 檢查模組介面，新增 host 時只加模組、不改核心邏輯。
- 檢查結果以 capability 為單位呈現（provider/enforcement/coverage/stability 等，具體結構由實作時的 `/pre-impl` 收斂），而非「這個 host 設定對不對」的二元判斷。
- 至少涵蓋 claude-host 既有檢查（回歸不遺漏）與 codex-host 的對應能力探測。
- 唯讀：不改變 install 的 write path。

**Dependencies**: 承接 [[CC-381]] spike 建議，可與 [[CC-436]] 並行（不互相阻塞）。umbrella [[CC-333]]。

**Outcome**: `doctor.sh` 核心 host-agnostic 化——四個 claude-host 檢查逐字搬入 `scripts/lib/doctor-host-claude.sh`（slug 與 pass/fail 判準不變），泛型 `lib/doctor-host-*.sh` 模組 loader 動態載入，新增 host 只加模組檔。新增 `emit_capability` 結構化 capability 記錄（host/capability/provider/enforcement/coverage/stability/confidence 七欄位，對齊 [[CC-381]] capability object 設計）。codex-host 模組全唯讀（binary、`$CODEX_HOME/hooks.json` 存在性/有效性；coverage=partial 反映 [[CC-436]] file-write payload 需 patch parser 的實測）。模組 helper 私有化（`_doctor_host_<name>_*`），僅 `doctor_host_<name>_run` 公開。copy-mode（單檔安裝無 lib/）緊湊 fallback：settings-file/dispatch-allowlist/manifest 判準具體保留，hooks inventory 降級單一 WARN（唯一行為變更，僅 copy-mode）。gate 兩輪收斂（R1 qa block+arch advise → R2 全 GO）。capability 欄位命名與 [[CC-438]] schema 定案時對齊，模組介面 manifest-ready。
**See**: pr:#374
**Also**: `docs/spikes/CC-381.md` §Angle 1/2/3 doctor 段落、§Recommendation 步驟 3。

---

## CC-438 — host manifest schema v1：codex-host 設定面宣告化 ✅ 2026-07-06

**Problem**: install 目前把 codex-host 的設定 target/format 假設寫死在程式碼常數（若日後實作），而非宣告在 manifest；[[CC-381]] spike 已收斂出應與既有 executor adapter manifest（[[CC-372]] `runner_kind`）分離、互為姊妹結構的 host manifest 方向，但尚未有 schema v1 draft。

**Why**: 沒有 schema，[[CC-437]] 的 host-specific 檢查模組與未來 install write path 都無所依附；schema 需要先確認 [[CC-436]] 的 payload 驗證結果，才能把 `guard_bindings` 欄位定案。

**Requirement**:
- 產出 `hosts/codex/host.yaml` schema v1 draft：至少涵蓋 install target/format、hook surface、guard bindings、permissions surface、doctor/uninstall module 指標。
- 與 [[CC-372]] executor adapter manifest（`runner_kind`/`write_guard_mode`）保持姊妹結構，不合併語意——host manifest 描述「host PM 自身」軸，adapter manifest 描述「PM→executor」軸。
- schema 欄位需能表達「能力尚在演進」的狀態（例如 declared/probed/effective 或等價分層），不得假設所有 host 能力恆定。
- 不落地實際 `install.sh` write path 改動（留給後續票）。

**Dependencies**: 依賴 [[CC-436]]（payload 驗證結果決定 `guard_bindings` 欄位能表達什麼）。承接 [[CC-381]] spike。umbrella [[CC-333]]。

**Outcome**: schema v1 定案（`docs/host-contract.md`）+ 首個 manifest（`hosts/codex/host.yaml`）+ 結構驗證器（`scripts/test-host-manifest.sh`，82 案例含 33 個負向 mutation，已註冊 run-all-tests）。schema 同時吃進雙 probe 結果——codex（[[CC-436]]）與 opencode 階段 1（[[CC-448]]）：`binding_form: config-fragment`/`provider: host_policy`/`hook_surface: {}` 承接宣告式 config host，不假設 guard binding 是腳本；closure-of-all-paths 條款明文寫入兩個 host file guard 的同構缺口（codex `apply_patch` 無 file_path 欄位 + shell 重導向繞過、opencode `edit:deny` 被 bash 繞過），all-deny 掛起風險與 headless hook-trust flag 亦入契約；contract 內含 opencode worked example 供階段 2 直接對照。gate 兩輪收斂（R1 qa NO-GO → enum-value 驗證補強；R2 GO + critic/arch advisory）→ advisory 修畢：capability 完整枚舉規則——五個 capability 全數必列，`none` 兩態由 `confidence` 區分（probed=已評估不支援、assumed=尚未評估），validator 強制完整性含負向案例。write path 不動，留給 [[CC-445]]。
**See**: pr:#375；`docs/host-contract.md`

---

## CC-439 — `/ship <ticket-id>` command：明確票直接實作到開 PR ✅ 2026-07-03

**Problem**: 目前「拿到明確 backlog 票 → 直接實作 → 派 pr-gate → 修到 GO → 開 PR」這條路徑，只存在於 memory 與 `agents/project-pm.md` 的 Rules A/B 散落文字裡，主線程每次都要自己記得拼起來完整流程，且完全沒有「開工前先檢查跟已定案決策有沒有衝突」這一步。

**Why**: 參考 [ai-night-shift](https://github.com/JudyaiLab/ai-night-shift) 的自動化紀律（非其架構）：把「implement → gate → fix → PR」收斂成一個可重複呼叫的 command，讓「丟一張明確的票」到「開出 PR」變成單一動作；同時把唯一合法卡點（票跟 BACKLOG/DECISIONS 已定案內容根本性矛盾）做成明確、可執行的第一步檢查，而不是模糊的自我判斷。

**Requirement**:
- 新增 `commands/ship.md`（`/ship CC-NNN` 呼叫），依 `commands/pm.md`/`commands/spike.md` 既有格式撰寫，步驟：(0) pre-flight 一致性檢查：讀該票 `BACKLOG.md` body + grep `DECISIONS.md` `**Constraints introduced**`，若根本性矛盾或 `Dependencies` 未滿足，停止並回報，不開分支；(1) 開 `feat/CC-NNN` 分支；(2) 主線程直接 Read/Edit/Write 實作，不 dispatch codex 做實作；(3) gate 迴圈：`pmctl gate run --executor codex` → 讀 `Final:` → NO-GO 時交給 `project-pm` agent 依既有 Rule A/B synthesis → 修全部 finding → 重跑，直到 GO；停止條件只有兩種（根本性不一致、或 3-strike 審查後同批 diff-caused blocker 完全原地打轉）；(4) `git push` + `gh pr create`（title/body 模板：票號/摘要/跑幾輪 gate/最終 verdict）；(5) 收尾報告，GO 後不自動 merge。
- `scripts/test-commands.sh` 補結構斷言：pre-flight 段落存在、gate 迴圈段落引用 `Final:`/`pmctl gate run --executor codex`、停止條件段落明確列出兩種且只有兩種、PR 模板段落存在。
- 不新增 `open-pr.sh` 或 DECISIONS.md 解析腳本（一致性判斷是 LLM 語意工作，不做機械化）；不建背景 daemon/cron supervisor（維持互動 session 內執行）；不做批次掃描 BACKLOG 自動挑票。

**Dependencies**: 無阻塞依賴。
**See**: pr:#360

---

## CC-440 — spike: `/ship` 並行版可行性（spike） ✅ 2026-07-03

**Problem**: `/ship`（單票版）已合併，主線程一次跑一張票、實作留在主線程直接改（`feedback_development_workflow`）、分支用普通 `git checkout -b`。使用者指出這個模式在人不在場時效益有限——真正的槓桿是「同時跑 N 張票」，但這要求兩個核心假設同時改變：(1) 實作要從主線程直接改換成 dispatch 給 executor（`feedback_development_workflow` 的省 token 理由只在主線程與該票共享上下文時成立，N 張互相獨立的票之間沒有這個共享上下文，所以這條記憶的適用範圍本來就不包含這個情境，不是要推翻它）；(2) 分支要從 `git checkout -b` 換成 `pmctl worktree create`（CC-014 已交付）避免 N 條 pipeline 互踩同一個工作目錄。這兩個改變疊加後，還有更難的問題完全沒有答案：一條 lane 失敗（gate 卡住、dispatch 失敗、根本性不一致）要怎麼回報又不卡住其他 lane？gate 迴圈裡本來假設「主線程可以隨時插手判斷」，換成 dispatch 給 codex 之後誰來扮演這個角色？

**Why**: 在沒有答案的情況下直接開實作票，大概率會像 `/ship` 單票版一樣在 pr-gate 階段被 architecture-reviewer/critic 挑出設計層面的漏洞，且並行 orchestration 的 blast radius（多個 worktree/dispatch 同時跑）遠大於單票版，值得先用 spike 收斂設計決策，而不是邊做邊踩。

**Requirement**:
- Investigation scope:
  - lane 失敗隔離：一條 pipeline（worktree+dispatch+gate）失敗時，其他 lane 是否需要感知/暫停？回報機制長什麼樣（單一收尾報告彙總 N 條結果，還是逐條即時通知）？
  - gate 迴圈的人機分工：`/ship` 單票版的 NO-GO fix-loop 假設「主線程」讀 gate 結果、判斷、寫 fix brief；並行版把實作換成 dispatch 給 codex 之後，fix-loop 由誰驅動（主線程仍讀每條 lane 的 gate 結果並派 fix brief，還是要在 dispatch brief 裡把整個 fix-loop 交給 executor 自己跑）？
  - worktree 生命週期：`pmctl worktree create/remove/gc`（CC-014）在多條並行 lane 下的 create/remove 時機——PR 開出後、gate 迴圈完成後，還是要等使用者確認合併後才 remove？
  - 併發上限：N 的合理上限（token/並發 dispatch/gate reviewer 容量），以及是否需要像 `--parallel` gate 一樣的 reviewer 隔離考量。
- Done-when: 對上述四個問題，至少收斂出可執行的設計決策（不需要完整實作方案），足以支撐後續開一張明確的實作票。
- Result log: docs/spikes/CC-440.md

**Outcome**: 四題與使用者逐一討論收斂（未 fan-out 多視角，單一使用者判斷已足夠明確）：lane 失敗互不干擾、逐條即時通知；gate NO-GO fix-loop 交給 executor 自扛到卡住才喚醒使用者；worktree 等使用者確認合併後才 remove；N 為可調參數，天生結構隔離（獨立 worktree + run_id 分區 artifact store）不需選票/仲裁機制。討論過程中額外浮現的 git 鎖疑慮也一併收斂：不自訂鎖，僅並行執行期間關閉 `gc.auto`。詳見 `docs/spikes/CC-440.md`。後續實作票承接 [[CC-439]]。

**Dependencies**: 承接 [[CC-439]]（單票版 `/ship`，作為並行版要呼叫的最小工作單元）。用到 CC-014 已交付的 `pmctl worktree`。
**See**: pr:#361

---

## CC-441 — `/ship --parallel` N-lane orchestrator v1 ✅ 2026-07-03

**Problem**: [[CC-440]] spike 已收斂五項設計決策（lane 失敗隔離、gate 迴圈人機分工、worktree 生命週期、併發上限、git 鎖策略），但這些決策目前只存在 `docs/spikes/CC-440.md` 裡，尚未落地成任何可呼叫的 orchestrator。

**Why**: spike 的 Done-when 只要求「收斂出可執行的設計決策」，不含實作；決策已收斂完畢，直接照 spike 的 Recommendation 開實作票，避免決策成果停留在文件層沒有後續。

**Framing（開工前必讀，避免誤讀範圍）**：CC-441 是一個**建在 [[CC-014]] worktree lane 之上的薄 orchestrator，保留 [[CC-439]] `/ship` 的 ship 語意契約**——不是重寫一條新的 ship pipeline。CC-441 只負責「lane 建立/追蹤/通知/`gc.auto` 暫時覆寫/GO-未合併清單」這幾件事；ship 本身該做什麼（pre-flight 一致性檢查、gate 讀 `Final:`、NO-GO fix-loop 停止條件、GO 後 push+PR、GO 後不自動 merge）由每條 lane 內部沿用 CC-439 已定義的契約，只是把「主線程直接改」換成「dispatch 給 executor 在該 lane 的 worktree 裡跑」。禁止：(a) 發明新的 worktree 目錄慣例/鎖/cleanup 狀態——一律用 CC-014 已交付的 `pmctl worktree create/list/remove/gc` 與其 manifest；(b) 在未跟使用者確認前，變更或繞過 CC-439 定義的 ship 停止條件。

**Requirement**（對照 `docs/spikes/CC-440.md` Recommendation 五點）：
0. **開工前 checkpoint**：實作前先產出一份簡短 execution plan（用到哪些 CC-014 `pmctl worktree` API、每個 lane 的 dispatch brief 如何映射 CC-439 的六項 ship 契約、CC-440 五項決策各自在程式碼裡的落點），列給使用者確認一次；若途中發現必須偏離 CC-439 的 ship 契約才能做到並行，停止並詢問使用者，不自行決定。
1. Orchestrator 主迴圈：讀入 N 張票的清單 → 對每張票 `pmctl worktree create`（沿用 CC-014 既有 manifest/命名慣例，不新造）→ 產生**保留 CC-439 ship 契約**的 dispatch brief（pre-flight 檢查、gate `Final:` 讀取、NO-GO fix-loop 由 executor 自扛到卡住才喚醒使用者、GO 後 push+PR、不自動 merge 全部照搬）→ `pmctl dispatch run --lifecycle detached` 平行送出。
2. 執行前置/收尾：啟動時用 `git config --get gc.auto` 讀出目標 repo 現有值並記錄「該 key 原本是否存在」（存在存實際值，不存在記為未設定，不可用 git 預設 `256` 頂替），寫入 `git config gc.auto 0`；主迴圈結束時（不論全部成功、部分失敗、或整批中斷）一律還原——原本有值寫回原值，原本未設定則 `--unset`，不可寫回 `256`。
3. 失敗回報：每條 lane 的 dispatch/gate 狀態變化即時通知使用者，不等其他 lane、不互相干擾。
4. worktree 保留策略：GO 之後不自動 remove，維護一份「已 GO 但未合併」的追蹤清單；remove 只提供 manual command path（使用者確認合併後手動觸發 `pmctl worktree remove`），本票不做自動 remove。
5. N 不做程式碼硬上限，僅在文件/CLI help 提醒使用者依機器負載自行調整；不做選票/仲裁機制。
- **Done-when（v1 範圍刻意縮小，避免第一張票塞太多）**：用 2 條 low-risk/mock 票驗證端到端——可各自建立 CC-014 worktree lane、各自生成通過 CC-439 契約檢查的 ship brief、各自 detached dispatch 且狀態可追蹤、GO 的 lane 進入「待合併」清單。不要求 v1 就有自動 remove、完整 cleanup UX、或超過 2 條的併發驗證——這些留給後續迭代。

**Dependencies**: 承接 [[CC-440]]（spike 已收斂全部設計決策）與 [[CC-439]]（`/ship` 單票版，定義本票必須保留的 ship 契約）。必須使用 [[CC-014]] 已交付的 `pmctl worktree`，不得自造 worktree 管理機制。

**AS-BUILT**：`pmctl ship prepare/finish` 為 CC-439 ship 契約的可腳本化 bookend（票號驗證+開分支；單輪 gate+GO 後 push/PR，含 branch-identity/dirty-tree/HEAD-moved/gh-preflight 四道 guard）；`pmctl ship --parallel/status/list` 為建在 CC-014 worktree 之上的 N-lane orchestrator，每條 lane 的 brief 呼叫 `pmctl ship finish` 收斂 gate/PR，不重複實作 ship 契約。真實 e2e 驗收（CC-004、CC-214 兩張低風險票）過程中發現並修正多項真實問題：claude adapter headless Bash 核准缺口（改用 `pmctl` 前綴全收 allowlist）、isolation 預設值擋住巢狀 gate dispatch（改 `workspace-network`）、GO 判斷曾誤信自由文字（改為只信 `pmctl ship finish` 自己寫的 marker）、併發重複派發競態、票號前綴誤判、tracking 檔案未上鎖競態、push 成功但 PR 開失敗的靜默狀態（新增 `partial` 狀態）。pr-gate 歷經 8 輪收斂至全 GO。
**See**: pr:#363

---

## CC-442 — 統一 `pmctl ship <ticket-id>` 單一入口（取代 prepare/--parallel 兩條平行路徑）（spike）✅ 2026-07-04

**Problem**：[[CC-441]] 落地後，「開始處理一張票」存在兩條互不相通的路徑：
- `pmctl ship prepare`（[[CC-439]]/[[CC-441]]）：**原地** `git checkout -b`，完全沒用到 worktree，只能主線程直接接手實作。
- `pmctl worktree create`（[[CC-014]]）：只有 `pmctl ship --parallel` 的 lane 建立時才會呼叫，worktree 隔離必須綁著整個 N-lane dispatch 派工機制才能拿到。

如果使用者想要「單張票也要 worktree 隔離，但不想走整個 dispatch 派工機制」，或「單張票也想 dispatch 給 codex/claude，但不必湊到 `--parallel` 那種批次形式」，現在都沒有對應指令。

**Why**：不是真的重複實作——底層 dispatch 原語只有一份（`pmctl dispatch run`，被 `/pm`、`/spike`、`pr-gate`（經 `pmctl gate run`）、`ship`/`ship --parallel` 共同呼叫，非各自重造），`pmctl ship finish` 也是單一實作被 `--parallel` 的每條 lane 共用；但「怎麼開始一張票」這個概念層面，因為 `prepare`（單票、無隔離）與 `--parallel`（批次、必隔離、必 dispatch）綁死在一起，分裂成兩套心智模型。[[CC-441]] 開發完成後由使用者提出，票面 Framing 當時刻意把範圍限定在「N-lane 並行整合」，不碰單票 `ship prepare` 行為，故延後為獨立票；本票之後使用者與主線程進一步討論收斂出更具體的設計（見下）。

**設計方向（2026-07-03 使用者與主線程收斂，待細化為正式 Requirement）**：
不再保留獨立的 `prepare` 子命令名稱，改成單一入口 `pmctl ship <ticket-id> [--worktree] [--adapter <name>] [其他既有 --parallel 旗標如 --isolation/--model/--from/--auto-pack]`：

- `pmctl ship <ticket-id>`：主線程原地接手（不隔離），行為等同現在的 `ship prepare`——驗證票號 + 原地開分支，Step 2 實作仍由呼叫端（主線程）自己完成，之後仍需要某種「finish」動作跑 gate+PR（沿用現有 `ship finish`，或整合進同一入口下的第二段呼叫，待細化）。
- `pmctl ship <ticket-id> --worktree`：同上，但改用 [[CC-014]] `pmctl worktree create` 建立隔離 worktree，不自動 dispatch——回傳 lane 路徑，呼叫端自己決定要不要過去接手實作。
- `pmctl ship <ticket-id> --adapter <name>`：**只要出現 `--adapter`，就強制隱含 `--worktree`**（dispatch 一定要隔離，不提供「不隔離也能 dispatch」的組合）——驗證票號、建隔離 worktree、產生保留 ship 契約的 dispatch brief、`pmctl dispatch run --lifecycle detached` 派給指定 adapter 跑完整流程（implement + `pmctl ship finish`）。
- `pmctl ship --parallel <id1> <id2> ...`：不再是獨立實作，收斂成「對每張票呼叫 `ship <id> --worktree --adapter <X>` 並行送出」的語法糖，`status`/`list` 維持現有的 tracking/marker 機制不變。

**Requirement**：
- Investigation scope：收斂「設計方向」段落遺留的兩項未定架構決策，並以一個真實消費者遷移驗證新介面站得住腳：
  1. 單票「原地 / `--worktree`」模式下，Step 2 實作與 gate+PR 之間的呼叫介面要不要沿用現有 `ship finish`，還是也收斂進同一入口（例如同一個 `pmctl ship <ticket-id>` 呼叫兩次，或改用不同子動作字樣）？
  2. `--adapter` 強制隱含 `--worktree` 之後，`--worktree`（無 `--adapter`）與 `--adapter`（必隱含 `--worktree`）兩種模式的 lane 目錄/tracking 記錄是否需要區分（例如非 dispatch 的 worktree lane 要不要也寫進 `ship-parallel.jsonl` 這類 tracking 檔）？
  3. Pilot walkthrough：挑一個現有真實消費者（`pmctl ship --parallel` 內部呼叫）試接統一後的單票入口，寫出逐字 before/after diff，確認乾淨無 shim、無行為回歸。
- Done-when：上述 3 點都有明確答案（介面呼叫形狀 + tracking schema 決策 + pilot diff 佐證），足以回填一份有信心的實作 dispatch brief，且不破壞 [[CC-439]] 既有 `/ship` 單票契約。
- Result log: docs/spikes/CC-442.md

**Outcome**：3-angle fan-out（interface-draft × 2 + code-audit）收斂三項決策：(1) `pmctl ship finish` **保留為獨立、不變的動詞**——已是掛 allowlist（`pmctl ship finish:*`）、有 branch-identity guard/HEAD-drift guard/`.pm-dispatch-ship-finish.json` marker 的既有 primitive，`--worktree`/`--adapter` 在 finish 時語意上是空的，收斂進同一入口等於重造「guard-one-execute-another」反模式（v0.6.0/v0.7.0 已有的教訓）；`commands/ship.md`（CC-439 契約）本來就不呼叫 `ship finish`，故不受影響。(2) tracking schema 採「unified-schema-with-optional-run_id」——所有 `--worktree` lane（無論是否 `--adapter` dispatch）都寫入 `ship-parallel.jsonl`，非 dispatch lane 的 `run_id=""`；純 worktree manifest 不夠，會讓 `ship status`/`ship list` 看不到該 lane，重現本票想解決的分裂。(3) Pilot walkthrough 證實遷移乾淨無 shim：新增 `pmctl_ship_run`（吸收 brief-writer + worktree-create + dispatch-run 序列，`ship-parallel.jsonl` 的 tracking-append 收斂進函式內部而非留在呼叫端，確保任何呼叫點都不會漏寫）、`pmctl_ship_parallel_run` 改為對每張票呼叫一次。完整證據、reconciliation 與 pilot diff 見 `docs/spikes/CC-442.md`。**後續實作票待開立**（承接下方草案，帶入本次 3 項決策），依賴不變：[[CC-441]]／[[CC-439]]／[[CC-014]]。

**後續實作 Requirement 草案（spike 收斂後回填至新開的實作票）**：
1. 盤點 `pmctl ship prepare`、`pmctl worktree create`、`pmctl_ship_parallel_run` 三處目前個別的 ticket 驗證/branch 建立邏輯，確認統一後不產生行為回歸（尤其是 [[CC-439]] 既有 `/ship` 單票契約不能被破壞）。
2. 依 spike 決策收斂單票模式下 Step 2 實作與 gate+PR 的呼叫介面。
3. 依 spike 決策落實 `--worktree`/`--adapter` 兩種模式的 lane tracking 記錄語意。
4. `pmctl ship --parallel` 內部改為呼叫統一後的單票入口（帶 `--worktree --adapter`），避免兩份 worktree 建立/dispatch brief 生成邏輯分別維護。
5. 補齊對應的 `scripts/test-pmctl-ship.sh`/`scripts/test-pmctl-worktree.sh` 回歸測試，含「`--adapter` 隱含 `--worktree`」這條新規則的直接測試。

**Dependencies**：承接 [[CC-441]]（發現此縫隙並完成初版 `--parallel`）、[[CC-439]]（單票 ship 契約不可破壞）、[[CC-014]]（`pmctl worktree` 既有 API 不得重造）。
**See**: `docs/spikes/CC-442.md`

---

## CC-443 — 實作：統一 `pmctl ship <ticket-id>` start 入口（承接 CC-442 spike）✅ 2026-07-04

**Problem**：[[CC-442]] spike 已收斂三項架構決策（`ship finish` 保留獨立動詞、tracking 採 unified-schema-with-optional-run_id、pilot diff 證實 `pmctl_ship_run` 遷移乾淨無 shim），但尚未落地成程式碼。使用者對 spike 方向的外部（ChatGPT）review 也補強了幾個實作細節，本票一併吸收。

**Why**：spike 決策若不落地會過期失效；[[CC-441]] 之後「開始處理一張票」仍分裂成 `ship prepare`（原地）與 `worktree create`（僅 `--parallel` 用得到）兩條路，單票 worktree 隔離、或單票 dispatch 給 codex/claude，都沒有乾淨入口。

**Requirement**：
1. 新增 `pmctl_ship_run(repo_root, work_dir, ticket_id, [--worktree] [--adapter <name>] [--from <base>] [--isolation <level>] [--model <alias>] [--auto-pack|--no-auto-pack])`（`scripts/lib/pmctl-ship.sh`）：
   - 無 `--worktree`/`--adapter`：原地委派給既有 `pmctl_ship_prepare`（行為完全不變，無 tracking 記錄）。
   - `--worktree`（無 `--adapter`）：呼叫 [[CC-014]] `pmctl_worktree_create` 建隔離 worktree，不 dispatch，寫入 tracking（見 #3），回傳 lane 路徑。
   - `--adapter <name>`：強制隱含 `--worktree`；建 worktree、寫 dispatch brief（沿用既有 ship 契約，`_pmctl_ship_brief_write`）、`pmctl dispatch run --lifecycle detached`、寫入 tracking。
   - `--worktree --adapter <name>` 同時出現：合法，效果等同單獨 `--adapter <name>`（冗餘不報錯）。
2. `pmctl ship finish` **維持獨立、不變的動詞**，不收斂進 `pmctl_ship_run`（CC-442 spike 決策）。`pmctl ship prepare <id>` **保留為明確 alias**，不刪除（外部 review 補強：CC-439/441 既有腳本化 bookend 依賴，直接移除有回歸風險）。`pmctl_ship_usage` 需明確標註 `pmctl ship <id>` 是「開始一個手動 ship lane」而非完整 ship 到 PR，並提示下一步是 `pmctl ship finish`；同時列出完整 option matrix（裸呼叫 / `--worktree` / `--adapter` / 兩者同時 / `--parallel`），避免實作時邊做邊猜（外部 review 補強）。
3. Tracking 檔重新命名為 `ship-lanes.jsonl`（取代 `ship-parallel.jsonl`，反映此檔現在被手動 worktree lane 與 dispatch lane 共用，不再是 `--parallel` 專屬；外部 review 補強）：
   - 欄位沿用既有 6 個（ticket/branch/path/run_id/status/created_ts）+ 新增 `adapter`（manual lane 為空字串）。
   - 任何 `--worktree` lane（無論是否 dispatch）都寫入一筆，`run_id=""` 代表未 dispatch 的手動 lane（CC-442 spike 決策）。
   - Tracking-append 呼叫收斂進 `pmctl_ship_run` 內部，不留在呼叫端，確保任何呼叫點都不會漏寫（CC-442 spike reconciliation 建議）。
   - lane-status 判斷（原 `_pmctl_ship_parallel_lane_status`，改名 `_pmctl_ship_lane_status`）新增一條分支：`run_id` 為空字串且無 finish marker → 回傳 `prepared`（而非目前會落到的誤導性 `running`）。
4. `pmctl_ship_parallel_run`（`scripts/lib/pmctl-ship-parallel.sh`）內部改為對每張票呼叫 `pmctl_ship_run "$repo_root" "$work_dir" "$t" --worktree --adapter "$adapter" ...` 一次，取代目前直接呼叫 `pmctl_worktree_create` + brief-write + `pmctl dispatch run` 的重複邏輯。Batch 層既有的 pre-flight（重複票號檢查、in-flight 檢查、全票驗證）與 `gc.auto` save/restore trap **維持只在 batch wrapper 這一層**；`pmctl_ship_run` 本身完全不碰 `gc.auto`（外部 review 補強：避免 N 條 lane 各自 set/restore 造成 race，與現有實作已經正確的批次層 scoping 保持一致，不要在單票路徑上重造）。
5. `cli/pmctl` 新增 `ship/*` fallback 路由：`pmctl ship <ticket-id> [--worktree] [--adapter <name>] ...`（票號形狀的第一個 token，非既有保留字 `prepare`/`finish`/`status`/`list`/`--parallel`）呼叫 `pmctl_ship_run`。
6. 回歸測試（`scripts/test-pmctl-ship.sh`）：
   - `pmctl ship <id>` 裸呼叫行為等同 `ship prepare <id>`（無 worktree、無 tracking 記錄）。
   - `pmctl ship prepare <id>` 既有行為不變（回歸）。
   - `pmctl ship <id> --worktree`：建 worktree、不 dispatch、tracking 寫入 `run_id=""`/`adapter=""`，`ship status` 讀到 `prepared`（非誤導性 `running`）。
   - `pmctl ship <id> --adapter <name>`：隱含 `--worktree`、寫 dispatch brief、tracking 寫入 `run_id`+`adapter`。
   - `pmctl ship <id> --worktree --adapter <name>`：與純 `--adapter` 等價。
   - 單票（非 `--parallel`）in-flight 重複 dispatch 拒絕。
   - `pmctl ship --parallel` 端到端既有 case 全綠（含 tracking 檔案改名後路徑同步更新）。
7. `docs/spikes/CC-442.md` 不修改（維持歷史 spike 記錄原貌）。

**Outcome**：`pmctl_ship_run` 落地於 `scripts/lib/pmctl-ship.sh`，`pmctl_ship_parallel_run` 改為對每張票呼叫它（消除重複的 worktree-create/brief-write/dispatch 邏輯）。Tracking 檔改名 `ship-lanes.jsonl`，任何 `--worktree` lane 的每個終態（`prepared`/`dispatched`/`dispatch-failed`/`go`/`no-go`/`partial`/`failed`）都保證寫入一筆，tracking-append 失敗改為硬性錯誤。`ship finish`/`ship prepare` 維持不變。`cli/pmctl` 新增 `ship/*` fallback 路由。pr-gate 跑了 6 輪才 GO（過程中額外修正：brief 產生指令的 shell quoting 漏洞、測試環境 `XDG_RUNTIME_DIR` 未隔離、`--adapter`/`--from`/`--isolation`/`--model` 旗標值未驗證即產生副作用、重複 positional ticket 未拒絕、`ship-parallel.jsonl` 改名後舊檔案會靜默消失——改為印出明確警告，不做雙讀遷移）；`scripts/test-pmctl-ship.sh` 增至 57 案例全綠。PR #365。
**Dependencies**：承接 [[CC-442]] spike（三項決策）、[[CC-441]]（`--parallel` v1 需保持行為不回歸）、[[CC-439]]（單票 `/ship` 契約不可破壞）、[[CC-014]]（`pmctl_worktree_create` 不得重造）。
**See**: `docs/spikes/CC-442.md`、PR #365

---

## CC-444 — v0.8.0 release closure ✅ 2026-07-04

**Problem**：v0.8.0 四個 Phase（memory substrate 跨工具可攜、gate DX、CC-381 spike、CC-014 worktree）已全部完成，但尚未 tag——v0.7.1 之後已累積 17 commits，含五張計畫外交付的 ship 系列票（[[CC-439]]..[[CC-443]]）。拖延不 tag 會讓版本邊界與 CHANGELOG range 越來越糊（v0.5.0 曾因此 release-prep 補了 ~8 張票的 CHANGELOG）。

**Why**：這是 DECISIONS 2026-07-04（v1.0-public-roadmap-and-release-sequence）排定的第一步；v0.9.0（host 軸）要在乾淨的版本邊界上開工。

**Requirement**（mirror [[CC-429]] v0.7.0 closure 模式）：
1. 跑 `/pre-release v0.8.0`（Layer 1 結構檢查 + Layer 2 語義 diff 覆蓋 + Layer 3 盲點聲明），逐項處理報告 finding。
2. 修 release 文件：README 版本徽章 bump 至 target tag（RELEASE_CHECKLIST 政策——badge 僅於 release 時 bump，為唯一版本標記，開發期停在上一 release 非 drift）、MILESTONES.md v0.8.0 標頭（規劃中 → released）、v0.8.0 milestone 補 release-closure Phase 行、CHANGELOG v0.8.0 range 完整性（含計畫外 ship 系列 CC-439..443）。
3. 寫 release notes；PR 合併後 tag `v0.8.0` + GitHub Release。

**Done-when**：tag `v0.8.0` 存在且指向含 closure PR 的 main；GitHub Release 發佈；`/pre-release` 報告無未處置 finding。

**Outcome**（2026-07-04，pr:#367）：`/pre-release v0.8.0` Layer 1 抓到 8 個 structural findings，逐項處置——CHANGELOG 補全 6 票（CC-412/423/432/014/434 + docs 票；CC-276 判定 false positive，其 entry 本就在 [0.6.0] 段 gh-174 名下）+ ship 系列（CC-439..441；CC-442/443 已在）；MILESTONES CC-433 行過期狀態修正（spike done → lib 由 CC-434 pr:#356 落地、poll→notify 殘餘 → CC-435）；補 Phase 5（計畫外同期 ship 7 票）與 Phase 6（closure）；標頭改 released；README badge bump v0.8.0。Layer 2 語義覆蓋 7/7 Covered（High confidence）。收尾過程另發現並修復：**`test-pmctl-worktree` 未註冊進 `run-all-tests.sh`**（CC-014 交付的 36-case 套件從未被 aggregator 執行）——已補註冊並確認全綠；套件註冊完整性 lint 開 [[CC-449]] 防再漏。`release-verify.sh --e2e` 全套 sign-off 於 closure PR 前執行（結果見 PR）。

**Dependencies**：[[CC-426]]（Layer 1/3 工具）、[[CC-430]]（Layer 2）皆已交付。
**See**: DECISIONS.md 2026-07-04 v1.0-public-roadmap-and-release-sequence、pr:#367

## CC-470 — pr-gate sequential 模式逾時歸零風險 + 慢速測試套件優化 ✅ 2026-07-08

**Problem**（2026-07-08，CC-445 pr-gate 第 7 輪實測）：`scripts/pr-gate.sh` 的 sequential 模式（預設）用單一 codex/claude session 依序處理全部 reviewer，只在最後才把完整結果寫入 `${OUTPUT_FILE}`。若 qa-tester 在該 session 內選擇跑完整 `run-all-tests.sh`（~10 分鐘）並撞上共用的 dispatch timeout，`set -euo pipefail` 讓腳本立即中止、`gate_result_verify` 從未被呼叫，`${OUTPUT_FILE}` 停留在 0 bytes——即使其他 reviewer（critic/architecture-reviewer/security-reviewer/risk-reviewer）可能已經在同一個 session 裡完成推論，全部產出仍付諸東流，該輪只能整個重跑。

**Why**：這是「有 timeout 上限、all-or-nothing 的執行模型」本身的架構風險，跟測試套件多慢無關——即使全套壓到 3 分鐘，任何其他意外阻塞（codex CLI 卡住等）都會觸發同樣的全歸零。同時，深入量測發現兩個測試套件有具體、低風險的效能修復空間，值得一併處理。

**Requirement**：
1. **sequential 模式逐 reviewer 落地**：改 brief 指示（`scripts/pr-gate.sh` task 區塊）讓 session 在每個 reviewer 完成後立即把該 reviewer 的區塊附加寫入 `${OUTPUT_FILE}`，而非等到最後才一次寫入；dispatch 呼叫（`eval "$DISPATCH_CMD"`）改為捕捉 exit code 而非讓 `set -e` 直接中止腳本；逾時/失敗時比對 `${OUTPUT_FILE}` 已完成哪些 reviewer 區塊，回報「N of 5 完成：xxx；未完成：yyy」的 partial 結果，並保留 partial artifact 供人工追查（不視為 GO，仍 `exit 1`，pass/fail 語意不變）。
2. **`test-pmctl-dispatch.sh` poll interval 修復**：補上 `export PM_DISPATCH_WAIT_POLL_INTERVAL="${PM_DISPATCH_WAIT_POLL_INTERVAL:-0.1}"`（`test-dispatch-lifecycle.sh:48` 已驗證安全的既有模式），預期從 309s 省下 60-90s。
3. **`pmctl-context.sh` 的 `_ctx_fts5_available` 加快取**：目前每次呼叫都 fork 2 個 sqlite3 子行程探測 FTS5 支援，改為模組層級關聯陣列快取（FTS5 支援在同一 binary/process 生命週期內是靜態的），預期從 244s 省下 5-15s。
4. **測試套件執行與 reviewer session timeout 完全解耦**（2026-07-08 使用者進一步收斂）：Requirement 1 只是止血——只要 qa-tester 還在 dispatch session 內自己跑測試，測試耗時就會侵蝕跟其他 reviewer 共用的 `--timeout` 預算。改為在 dispatch 之前用純 bash 跑一次目標 repo 的測試指令，跟任何 reviewer 的 LLM 判斷完全脫鉤；結果（`test_suite: pass|fail|skipped`）機械寫入 frontmatter。`--test-timeout`（獨立於 `--timeout`）、`--skip-preflight-tests` 逃生閥。**只認明確 `--test-cmd`，不自動偵測任何路徑**（初版曾自動偵測 `scripts/run-all-tests.sh`，但 pr-gate.sh 設計上可被複製進任何 repo 獨立使用，不該寫死任何特定 repo 的慣例路徑，即使加了 `--allow-hooks` 信任閘門也一樣——2026-07-08 pr-gate 第一輪 NO-GO 後跟使用者對齊修正）。**FAIL 時 fail-fast、完全跳過 reviewer dispatch**（不是先跑完 5 個 reviewer 再事後覆寫——測試沒過本來就註定 NO-GO，花真實 token 審查一份已知會被打回票的程式碼沒有意義；2026-07-08 跟使用者對齊後由「dispatch 後覆寫」改為「dispatch 前短路」），直接機械合成 NO-GO 結果（含 redacted log 摘要），不呼叫任何 LLM。

**Non-goals**：不解析 `.agent-trace/*.jsonl` 做結構化 partial 回收（adapter 事件格式不統一，維護成本高，只當人工追查路徑指標）；不處理 `cli/pmctl` 每次呼叫 source 22 個 lib 檔案的系統性 ~0.5-0.7s 開銷（影響全產品所有 pmctl 呼叫路徑，需要更大規模的 lazy-loading/常駐行程重設計，風險/範圍都遠大於本票，另開票處理）；不把 `--parallel` 設為預設（成本 ×2，僅適合 auth/payment/migration 等高風險變更）；不做「iteration vs final round」測試分層啟發式；不新增 `.pr-gate.yml` 設定檔格式；不自動偵測任何 repo 特定測試指令路徑（見上）。

**Verification**：`scripts/test-pr-gate.sh` 新增 codex stub 分支模擬「2 of 5 reviewer 完成後逾時」，斷言 partial 結果訊息 + `${OUTPUT_FILE}` 內容在磁碟上不被清理掉；`test-pmctl-dispatch.sh`/`test-pmctl-context.sh` 改動前後量測 wall time 確認確實變快、案例數不變全綠；Requirement 4 共 13 個測試，含關鍵案例「pre-flight 失敗時 stub reviewer 就算被設定成回 GO 也絕對不會被呼叫（斷言 stdout/stderr 完全沒有 dispatch stub 的輸出）」、「即使 repo 內存在可執行的 `scripts/run-all-tests.sh` 也絕不會自動執行」、「fail-fast 合成的 log 摘要確實含真實內容且 redaction 有效（回歸鎖：早期版本 redaction 函式讀錯 `$1` 導致 pipe 內容整個被丟棄，shellcheck SC2119/SC2120 抓到）」、FTS5 快取邏輯本身（回歸鎖：早期版本快取命中分支比對值寫反，導致第二次呼叫永遠回報錯誤結果）。手動 smoke test 對 pm-dispatch 自己跑 `--test-cmd "exit 1"`，確認完全沒有 `codex-dispatch starting` 字樣、直接產出合成的 NO-GO 結果。

**Source**：CC-445 pr-gate 第 7 輪逾時實測 + 使用者要求優先處理、並在討論中收斂出機械化解耦設計（2026-07-08）；已用 Explore + Plan agent 交叉核實根因與改動點，並經 Ultraplan 雲端 session 精修 Requirement 4 的實作行號；送 pr-gate 第一輪 NO-GO（security/risk block 自動偵測信任邊界、qa-tester block FTS5 缺測試）後與使用者對齊修正方向並全數修復；修復過程中使用者進一步指出「pre-flight 本身就是送 gate 前的完整性檢查，不需要再手動跑一次 checkpoint」與「測試沒過就不該還花錢跑 reviewer」兩個洞見，收斂出 fail-fast 設計，見對話紀錄。

**Outcome**（2026-07-08）：Requirement 1-4 全數完成並驗證；`pmctl gate run --executor codex --test-cmd "bash scripts/run-all-tests.sh"` 收斂 GO（全部 5 個 reviewer approve/pass，`test_suite: pass`）；`scripts/test-pr-gate.sh` 135/135、`test-pmctl-context.sh` 109/109、`test-pmctl-dispatch.sh` 44/44 全綠；`bash scripts/run-all-tests.sh` 全套 checkpoint 71/71 clean。

**See**: pr:#383

---

## CC-455 — context plane repo_root 跟隨工作目錄（跨 repo 使用 context.db 打錯 repo）✅ 2026-07-06

**Problem**（2026-07-06 使用者回報 + 實測確認）: 在 pm-dispatch 以外的 repo 用 CLI 觸發 pm agent 時，目標 repo 的 context.db 不會被建立或刷新。根因鏈：
1. `cli/pmctl` 的 `REPO_ROOT` 從 pmctl 腳本自身路徑（穿過 `~/.local/bin` symlink）解析——**永遠指向 pm-dispatch 安裝 repo，與執行時的工作目錄無關**。
2. `pmctl_context_query` / `pmctl_context_reuse_scan` / `pmctl_context_index` 的 repo_root 參數為「可選第一個位置參數，未帶時 default `REPO_ROOT`」。
3. `agents/project-pm.md` 的 context retrieval reflex 指示 `pmctl context query --domain knowledge <term>` **不帶 repo 路徑**（僅 reuse-scan 帶 `<working_dir>`）。
三者疊加：跨 repo 的查詢全部打到 pm-dispatch 自己的 db（命中不相關內容），且既有的 auto-build/auto-refresh 機制（`_ctx_ensure_fresh`，預設開啟）一直刷新錯的 repo。實測：在外部目錄執行 `pmctl context query <term>`，該目錄不產生任何 ctx 檔案，pm-dispatch 的 context.db mtime 反而被更新。

**Why**: context retrieval 是 v0.7.0 epic 的核心能力，宣稱面是「per-repo 的本地 context 基底」；pm agent 的設計本來就是跨多個 repo 工作（任意位置的 repo，不限特定目錄佈局），此缺陷讓 context 能力在 pm-dispatch 以外的所有 repo 實質失效且靜默。

**Requirement**:
1. **CLI 層 chokepoint 修正**（優先）：context 家族子指令未帶路徑時，default 改為「呼叫時 CWD 的 git toplevel」（`git rev-parse --show-toplevel`），非 git 目錄再 fallback 既有 `REPO_ROOT` 行為並印 warning；在 pm-dispatch repo 內執行的行為不變（回歸鎖住）。
2. 盤點 context 家族以外是否有同型「default REPO_ROOT 但語意應為 target repo」的子指令（如 memory 平面已獨立解析、應不受影響——確認即可）。
3. `agents/project-pm.md` retrieval reflex 與 `docs/context-retrieval.md` 同步：明確「跨 repo 時查詢必帶 target repo root（或依賴修正後的 CWD default）」。
4. 回歸測試：外部 repo 內執行 query/reuse-scan → 在該 repo 建立/刷新 `.pm-dispatch/ctx/context.db`、不觸碰 pm-dispatch 自身 db。

**AS-BUILT**：新增共用 helper `_ctx_default_repo_root`（`scripts/lib/pmctl-context.sh`）：未帶路徑時先解析呼叫時 CWD 的 git toplevel，非 git 目錄才 fallback `REPO_ROOT` 並印一行 stderr warning；`index`/`update`/`query`/`pack`/`reuse-scan` 五個子指令全部改用（Requirement 1）。pr-gate 過程中另抓到 `pack`/`reuse-scan` 有「default 早於 explicit-repo 解析」的排序 bug（explicit repo 呼叫仍誤印 fallback warning），一併修正。`agents/project-pm.md` retrieval reflex 與 `docs/context-retrieval.md` 同步改為要求明確帶 `<working_dir>`（Requirement 3）。回歸測試新增 external-repo/no-git-fallback/pm-dispatch-tree-unchanged/live-db-untouched 等情境，共 99 案全綠（Requirement 4）。Requirement 2 抽查 worktree/dispatch/ship/task 等子指令：`repo_root`（install repo，供 lib/state 定位）與 `work_dir`/`--cd`（實際 target repo）本就是分離參數，`work_dir` 一律要求明確 `--cd`/positional 而非依賴 CWD 隱性 default，架構上與 context 的單一參數混用問題不同類，未發現同型缺陷。過程中順帶把 `commands/pr-gate.md`/`pre-release.md`/`ship.md` 的 pmctl 呼叫方式改為裸指令（原本的路徑解析 preamble 會讓指令永遠比對不到 `Bash(pmctl:*)` allowlist、每次都要提權）。
**See**: pr:#371

**Dependencies**: 無前置。v0.9.0。與 [[CC-453]]（auto-pack work_dir 驗證）同屬「路徑語意」修正面，可同批評估但不合票。
**Source**: 使用者 2026-07-06 回報「其他 repo 的 context.db 不會自動使用/刷新」；主線程實測確認。

## CC-457 — claude host manifest 化：`hosts/claude/host.yaml` reference instance ✅ 2026-07-07

**Problem**（2026-07-07 維護者指出）: [[CC-438]] 交付 host manifest schema v1 後，`hosts/` 只有 `hosts/codex/host.yaml`。claude 作為原生 host，install/uninstall 的檔案佈局（commands/agents/skills/hooks 寫入 `~/.claude/...`）仍散在 `install.sh` 硬編碼，doctor 側雖已有 `scripts/lib/doctor-host-claude.sh` host module（[[CC-437]]），但宣告面（capability/guard_bindings/install_targets/uninstall_module）沒有 claude instance。三 host（claude/codex/opencode）維護面不對齊：改 schema 或接線時 claude 永遠走特例路徑，後續每張 host 軸票都要為 claude 另寫一份心智模型。

**Why**: claude 是能力最完整、confidence 最高的 host（PreToolUse hook 原生、payload 欄位齊、fail-closed 已驗證），最適合當 schema 的 reference instance——先宣告它能回頭驗證 CC-438 schema 表達力是否足夠（吃得下最完整的 host 才算 schema 成立）。同時 [[CC-445]]（install write path host-generic：`hosts/*/host.yaml` 驅動、claude 路徑 byte-compatible）需要一份 claude manifest 作為 byte-compatible 驗收的 source of truth，否則「host-generic」實際上只涵蓋 codex/opencode，claude 仍是隱形特例。

**Requirement**:
1. `hosts/claude/host.yaml`：依 `docs/host-contract.md` schema v1 完整宣告 claude host——install_targets（commands/agents/skills/hooks 各寫入點，path 以 env-var 錨定）、capability（七欄位與 `doctor-host-claude.sh` emit_capability 對齊，confidence 反映原生實測）、guard_bindings（PreToolUse hook-script form）、uninstall_module、permissions_surface。
2. `scripts/test-host-manifest.sh` validator 納入 claude instance（含 claude 特有欄位組合的負向案例）；schema 表達力不足處回頭修 contract（版內允許，schema 尚未凍結）。
3. doctor capability 輸出與 manifest 宣告一致性檢核（宣告 vs 實測不符要可觀察，形式參照 CC-437 介面）。
4. **不動 install.sh write path**——接線歸 [[CC-445]]；本票只交付宣告面 + validator + 一致性檢核，CC-445 落地時以本 manifest 為 claude 驗收基準。

**Dependencies**: [[CC-438]] ✅（schema v1 已定案）。與 [[CC-445]] 同鏈：本票先行（純 additive、低風險），CC-445 接線時引用。v0.9.0 host 軸。
**Source**: 維護者 2026-07-07「claude 的 host 也需要調整成新的架構，不然後續維護會相對不對齊」。

**Outcome**（2026-07-07）: `hosts/claude/host.yaml` 依 schema v1 完整宣告（install_targets/capability/guard_bindings/uninstall_module/permissions_surface），claude 作為能力最完整的 host 通過 reference instance 驗收。`scripts/test-host-manifest.sh` 納入 claude 專屬正負案例（87 綠），`doctor-host-claude.sh` 加上宣告 vs 實測一致性檢核（test-doctor.sh 50 綠，含 drift 失敗案例）。不動 install.sh write path，接線留給 [[CC-445]]。Gate R1 GO（critic advise：uninstall_module 註解與 install.sh 尚未 manifest-driven 的事實矛盾）已修正並收斂。
**See**: pr:#381

---

## CC-458 — gate run/wait DX：--cd 預設、wait 指令可複製、verdict 可區分 ✅ 2026-07-07

**Problem**（2026-07-06 使用者指定優先；同一 session 內三個痛點全部實踩）:
1. `pmctl gate wait` 強制要求 `--cd <work_dir>`，漏帶直接 exit 2；但 run-dir 分割本可由呼叫者 CWD 推導（[[CC-455]] context plane 已有 CWD git-toplevel 預設先例）。
2. `pmctl gate run` 只在 stdout 印 gate id 一行，後續 wait 指令要手動拼 id + `--cd`，中間任何複製錯誤都是 usage error。
3. NO-GO 時 `gate wait` exit 1，在背景任務完成通知裡顯示成 "command failed"，與真正執行錯誤難以區分——verdict 的 source of truth 是 result 檔 `Final:` 行（[[feedback_gate_verdict_source_of_truth]]），wait 卻不印它。

**Requirement**:
1. **wait `--cd` 改選填**：缺席時預設 CWD git toplevel（非 git 目錄 fallback `$PWD`）；`gate run` 的 `--cd` 預設同步改為同一推導，確保 run/wait 兩端獨立重算出同一個 run-dir partition。顯式 `--cd` 行為不變。
2. **run 印可複製的 wait 指令**：detached 啟動後在 stderr 印一行完整的 `pmctl gate wait <gate_id> --cd <path>`（stdout 維持只印 gate_id 一行——ship/pr-gate 等既有消費者以 stdout 捕捉 id，契約不得破壞）。
3. **wait 印 verdict 摘要**：sentinel 完成且 result 通過 `gate_result_verify` 後，把 result 檔的 `Final: GO|NO-GO` 行原樣印到 stdout；NO-GO 時另在 stderr 明示這是 gate verdict（exit 1）而非執行錯誤。exit code 分層維持既有語意並在函式註解明文化：0=GO、1=NO-GO、2=usage/整全性錯誤、3=indeterminate、124=timeout。

**邊界**: 不動 sentinel/nonce 機制、不動 `gate_result_verify` 契約、不加新 flag；`commands/pr-gate.md` 的 wait 說明同步更新（不含票號）。

**Dependencies**: 無。獨立 PR（使用者 2026-07-06 指示）。
**Source**: 使用者 2026-07-06「pmctl gate wait 這段流程很容易執行錯誤，下一個 session 優先處理」。

**Outcome**（2026-07-07）: 三項 Requirement 全數交付於 `scripts/lib/pmctl-gate.sh`：(1) `_pmctl_gate_default_cd`（CWD git toplevel → `$PWD` fallback）同時供 run/wait 兩端推導，partition 重算一致，顯式 `--cd` 不變；(2) detached run 在 stderr 印完整可複製的 wait 指令，stdout 維持單行 gate_id 契約；(3) wait 在 `gate_result_verify` 通過後原樣印出 result `Final:` 行、NO-GO 加 stderr 註記與執行錯誤區分，exit code 分層（0/1/2/3/124）明文化於函式註解。`commands/pr-gate.md` 指引同步。測試：test-pmctl-gate 18 綠（含 git-subdir 爬升與非 git fallback 直接覆蓋）、test-gate-lifecycle 12 綠、test-pr-gate-profile 13 綠。gate R1 NO-GO（qa block：wait 預設 git-toplevel 分支缺直接測試）修畢後 R2 GO 零 advisory。本票 gate 流程本身即以新 DX 走完（dogfood）。

**See**: pr:#378

---

## CC-459 — context retrieval reflex 確定性化：prompt-scan 自動注入 + PM 編號步驟 ✅ 2026-07-07

**Problem**（2026-07-07 使用者實踩）: `agents/project-pm.md` 的 context retrieval reflex（Principles #3）目前是純 prose，無任何 runtime enforcement。實測跨 repo telemetry（`pmctl trace tail --kind context.queried`）證實：數日內對某目標 repo 的所有 /pm 工作階段，agent 一次都沒呼叫過 `pmctl context query`——唯一有強制力的點是 `BRIEF_VALIDATE_RETRIEVAL=fail`，只卡 file-writing brief 的 context 證據；Analysis / Status / 一般知識查詢完全沒 gate，agent 直接 Read/Grep knowledge docs 跳過 query。這正是 `agents/project-pm.md` 自述的「a prose reflex degrades exactly when the session is busy」同一模式——discover 路由已用 Classify branch 解掉，knowledge retrieval 還停在 prose。

**Why**: 本 repo 已兩次驗證「prose reflex → deterministic path」有效（dispatch auto-pack、discover Classify branch），另有 pm-write-guard 證明 hook 硬閘可行。與其要求 model「記得」查，不如讓 pipeline 自動查好注入——agent 開場就拿到 heading-anchored refs，跳過 query 的動機直接消失，telemetry 也天然回填。

**Requirement**:
1. **`pmctl context prompt-scan [<repo_root>] "<prompt text>"`**：以 `_ctx_extract_terms` 抽詞（沿用既有 change seam，不 inline）、每 term 對 repo plane 以 `--domain knowledge` 查詢、跨 term dedupe、輸出 pointer-only 的 `knowledge_hits:` YAML（上限 5 條）。發射**獨立事件 kind `context.prompt_scanned`**——不得混用 `context.queried`，否則自動掃描會污染「agent 是否主動查詢」的 telemetry 訊號。**Privacy hard rule**：事件 payload 的 query 欄位一律為**空**——原始 prompt 與 derived terms 皆不持久化（derived term 仍可能原樣重現 secret 形 token），只記 hit count；scrub 程序見 `docs/context-retrieval.md`。no-index / no-sqlite 皆優雅降級（空輸出 + 零 hit 事件）。
2. **`scripts/guard-inject-context.sh`**（UserPromptSubmit hook）：讀 payload `cwd`+`prompt` → 解析 git toplevel（非 git 目錄靜默退出）→ 以 `PM_DISPATCH_CONTEXT_AUTOBUILD=0` 呼叫 prompt-scan（不在互動 prompt 路徑觸發首次全量建索引；incremental refresh 保留）→ 僅在有 hits 時輸出 `=== auto-context ===` 區塊（含「更多請跑 pmctl context query」提示行）。永遠 exit 0（hook 絕不阻斷 prompt）；`PM_DISPATCH_DISABLE_PROMPT_CONTEXT=1` kill-switch；呼叫包 timeout 防慢 repo 拖累 prompt 延遲。
3. **`scripts/install-guards.sh`** 註冊新 hook 為 managed hook（presence check / path refresh / prune 與 guard-inject-memory 對稱）。
4. **`agents/project-pm.md`**：On invocation 於 Classify 前插入編號 Retrieve 步驟（knowledge 類請求先 query；若 prompt 已帶 auto-context hits 則直接引用、不重查），Principle #3 指向該步驟——prose 從原則段落升格為結構化步驟。
5. **`docs/context-retrieval.md`** 補 prompt-scan / auto-inject / `context.prompt_scanned` 文件；成功判準沿用既有 Success metric（下游引用 anchors，非 query count）。
6. 測試：`test-pmctl-context.sh`（prompt-scan：no-index、hits、knowledge-domain-only、dedupe、事件發射）、`test-guards.sh`（hook：happy path、非 git、零 hits 靜默、malformed payload、kill-switch）、`test-install.sh` 於 inject-memory 斷言點鏡像新 hook。

**Deferred（顯式非目標）**: 第 2 層 PreToolUse read-guard（Read/Grep/Bash 開 knowledge docs 前檢查本 session 是否 query 過）——待本票上線後以 telemetry 覆蓋率決定邊際價值再議；若做，須依 [[feedback_cut_capability_close_all_paths]] 同時關 Bash 路徑。

**Risk**: hook 會在每個 prompt 自動觸發 pmctl context 讀取路徑，與 [[feedback_no_pmctl_during_full_test_run]]（全套測試期間勿碰 live DB）存在自動化衝突——kill-switch 即為此而設，並在 docs 註記。

**Dependencies**: 無（context plane 既有能力之上純 additive）。
**Source**: 使用者 2026-07-07「context.db 沒刷新」誤報調查 → 根因是 reflex 從未被執行 → 「請幫我開票並實際規劃與實作」。

**Outcome**（2026-07-07）: 六項 Requirement 全數交付。gate 三輪收斂：R1 full NO-GO（no-sqlite 降級契約不符、telemetry 存原始 prompt、覆蓋缺口）→ R2 targeted NO-GO（security/risk 升級：derived terms 仍可能重現 secret 形 token）→ 最終方案為 `context.prompt_scanned` 事件 query payload **一律為空**（僅記 hit count），加 secret-shaped regression（state root 遞迴 grep 零殘留）與 events.jsonl scrub 程序 → R3 targeted GO 零 findings。修復前本機 live store 的 3 筆 prompt-derived 事件已現場 scrub。測試：test-pmctl-context 108、test-guards 203（含 timeout fail-open stub seam）、test-install 86、test-doctor 49、test-commands 269、全套 71 suites 綠。

**See**: pr:#379

---

## CC-471 — spike: codex `pm_command_interface` probe ✅ 2026-07-09

**Problem**：[[CC-445]] 送出 codex-host command-guard write path 並在第 21 輪 pr-gate GO 後，使用者問「如果我要在 codex 上安裝，還缺什麼」——盤點發現 `hosts/codex/host.yaml` 的 `pm_command_interface` capability 從未被評估過（`confidence: assumed`），也就是「codex 到底能不能像 Claude 的 `/pm` 一樣呼叫 project-pm」這件事完全沒驗證過。

**方法**：使用者直接啟動 codex 實測——focused suites（`test-host-write-codex.sh` 31、`test-pmctl-guard.sh --filter pm-prebash` 7、`test-doctor.sh --filter codex` 12、`test-guards.sh --filter pm-bash` 84）+ 全套 `run-all-tests.sh`（72 綠）+ 手動 smoke（臨時 CODEX_HOME 裝 hook、doctor 回報 wired、餵 payload 驗證 allow/deny）+ 真實 `~/.codex/hooks.json` 短暫接線後跑真實 `codex exec`（allow path 執行成功、deny path 被 PreToolUse hook 擋下），測完用 `uninstall-guards-codex.sh` 移除，repo 保持乾淨。

**Outcome**（`docs/spikes/CC-471.md`）：CC-445 的 command-guard write path 功能完全正確，無新 bug。但確認 codex CLI **沒有**等同 Claude Code Agent/subagent 呼叫的機制——`/pm` 依賴的「即時開一個 project-pm subagent、可暫停問澄清問題、再收 handover」這整套互動迴圈，codex 沒有對等入口。codex 目前能呼叫的只有底層 `pmctl dispatch run/wait`、`pmctl gate run`、`pmctl context query` 等既有 CLI 原語，不是 `/pm`-shaped 的體驗。`hosts/codex/host.yaml` 的 `pm_command_interface` 已改記為 `confidence: probed`（已評估、確認不支援，非未評估）。後續規劃見 [[CC-473]]。

**Dependencies**：承接 [[CC-445]] 的 host 安全防護實作；發現回饋進 [[CC-473]] 規劃票。

**See**: `docs/spikes/CC-471.md`

---

## CC-004 — test-pr-gate.sh docstring 格式統一 ✅ 2026-07-06

**Problem**: scripts/test-pr-gate.sh 新增的 shell test functions 使用散文註解描述行為，而非 pm-schema 規範的 structured behavior/Steps docstring 形式。
**Why**: tests 本身 behavior-named、deterministic，功能無虞，純為 audit-quality / 一致性問題。長期會讓新人讀測試時樣式不一。
**Requirement**: 把新增 test functions 的開頭註解改寫成與既有 hook tests 一致的 behavior/Steps docstring 結構。不改測試邏輯。
**AS-BUILT**：124 個 test function 全數補上 `# Behavior:`/`# Steps:` docstring，慣例說明加進 `scripts/lib/test-harness.sh` 頂部；新增 `scripts/lint-test-docstrings.sh` explicit-allowlist ratchet linter + 回歸測試，CI 掛勾守住已轉換檔案不再退化。其餘 9 檔 201 函式的跨檔 backfill 拆出為 [[CC-450]]。
**See**: pr:#369

## CC-014 — repo 通用 worktree 平行開發工具 ✅ 2026-07-02

**Status note (v0.8.0 planning 2026-07-02)**: Re-activated (was downgraded to ⏸ deferred by the CC-050 audit 2026-05-18 for lacking an open branch) — assigned to v0.8.0 Phase 4. Scope broadened 2026-07-02: 不再侷限於 pr-gate reviewer 隔離，改為 repo 層級通用 worktree 工具，讓任一 ticket/分支都能快速建立、切換、清理獨立 worktree 以支援多票並行開發。
**Problem**: 目前開發者（與 `--parallel` PR gate 各 reviewer）都在同一 working tree 上工作，跨票並行開發時彼此的未 commit 變更、build 產物會互相干擾；沒有標準化的方式建立/清理獨立 worktree。
**Why**: git worktree 讓每個工作串流（人或 subagent）在獨立環境工作，避免狀態污染；同時直接補強 CC-003 的解法方向，也可延伸解掉 `--parallel` gate 的 reviewer 隔離問題。
**Requirement**:
1. `scripts/worktree-*.sh`（或等效 `pmctl` 子指令）：為指定 ticket/分支建立、列出、清理 worktree，統一命名慣例與清理時機（避免孤兒 worktree 殘留）。
2. `commands/using-git-worktrees.md` skill：指導開發者（人或 dispatch executor）如何用這些工具做功能分支平行開發。
3. 評估 `--parallel` PR gate 是否可改用同一套工具為每個 reviewer 建立獨立 worktree（原票聚焦點，現列為本票子項而非全部範圍）。
**Outcome**: `pmctl worktree create/list/remove/gc` 落地，manifest 存於 state store（`sw_project_worktree_dir`，跨主 repo/linked worktree 同一 partition）；`commands/using-git-worktrees.md` skill 文件；36 個 focused test。`--parallel` gate reviewer 隔離（原需求 3）留待未來 follow-up ticket，未併入本次範圍。
**See**: pr:#358

## CC-214 — platform-support.md manual uninstall command anchoring ✅ 2026-07-03

**Problem**: The manual uninstall warning in `docs/platform-support.md` uses `bash uninstall.sh`
without anchoring to the repo path; running it from any other working directory silently fails.

**Why**: Raised by critic in gate-20260521-115634 as [low] advise. Other examples in the same
document already use the `"${PM_DISPATCH_REPO}/uninstall.sh"` form.

**Requirement**: Replace the bare `bash uninstall.sh` in the Windows uninstall warning block with
`bash "${PM_DISPATCH_REPO}/uninstall.sh"` (one-line change).

**Note**: Picked as one of two real, low-risk mock tickets for [[CC-441]]'s real e2e validation
(N-lane `pmctl ship --parallel` dispatch) — implemented by a dispatched claude executor inside a
CC-014 worktree lane, not by hand.
**See**: pr:#362

## CC-445 — install write path host-aware（CC-381 完整實作第一刀）✅ 2026-07-12

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

**Update 2026-07-12（implementation gate R2 GO）**：`gate-20260712-091848-e1da26` full-tier sequential、test suite pass；critic approve、qa-tester pass、architecture approve、security pass、risk pass，無 escalation，`Final: GO`。R1 的 security injection、partial multi-host install、generic failure coverage、Claude config-root split 均由 reviewer 逐項確認關閉。QA 唯一 non-blocking low（新 OpenCode test functions 的 `Behavior:`/`Steps:` docstring 一致性）已依維護者指示於 gate 後補齊；此變更僅為 comment，定向 docstring lint 與 OpenCode 13-case suite 綠，不重跑 PR gate。Draft PR #395 已開；維護者確認 CC-445/448 於 2026-07-12 terminal close/archive。

**Outcome**: 2026-07-12 CC-445 requirements complete：manifest-driven host dispatcher、Claude byte-compatible parity、usage-log host decoupling、failure-atomic host preflight 與 full-tier gate GO；交付於 pr:#395。

## CC-448 — opencode host support：probe → host manifest → install/doctor 接線（host 抽象 N=2 驗收）✅ 2026-07-12

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

**Update 2026-07-12（draft PR opened）**：與 [[CC-445]] 共用 draft PR #395；full-tier implementation gate 與 Claude/OpenCode live acceptance 均 GO。PR review 清理時移除已完成使命的 ticket-specific probe generator，將 runbook 改為歷史 probe record；正式重現面由 cross-host acceptance 文件與 OpenCode regression suite 承接，避免一次性 fixture 混入支援中的 script surface。維護者確認於 2026-07-12 terminal close/archive。

**Outcome**: 2026-07-12 CC-448 stages 1–3 complete：OpenCode manifest、doctor、reversible install/uninstall、native `/pm`、guard policy、Claude/OpenCode shared-memory live acceptance 與 full-tier gate GO；交付於 pr:#395。
**See**: DECISIONS.md 2026-07-04、DECISIONS.md 2026-07-06、`docs/spikes/CC-448.md`、`docs/spikes/CC-476.md`

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

## CC-477 — guard memory usage sidecar 並發遺失更新 ✅ 2026-07-13

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

**Resolution**: 根因是 `serialize_with_lock` 的 mkdir fallback 在子 shell `EXIT` trap 已釋放 lockdir 後，外層又做第二次 `mkdir_unlock`；兩次釋放之間下一個 waiter 可取得同一路徑，導致舊 owner 刪除新 owner 的 lock。改為由子 shell trap 作唯一釋放者。新增 25 writer、FIFO barrier、`flock`/`mkdir_lock` 兩後端各 4 rounds 的 contention matrix，失敗時保留 writer start/acquire/finish/exit evidence 與 lockdir cleanup assertion。同步 harden full runner 的 per-suite deadline、START/RUNNING diagnostics，以及 inject-memory case-level timeout，使 full-suite 壓力下能快速定位而不再靜默卡住。`gate-20260713-021703-6a233a` preflight PASS、Final GO。

**See**: pr:#396

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

## CC-481 — test runner contract：短迭代與 final evidence 分層 ✅ 2026-07-13

**Problem**: pm-dispatch 的完整 `scripts/run-all-tests.sh` 在真實 contention/full gate 下可超過 20 分鐘。若每次 reviewer gate 都把 full suite 放進 `--test-cmd`，外層 gate/supervisor timeout 與測試 runtime 耦合，修正迴圈仍要等完整套件後才得到失敗；但在 selector 尚無可信 transitive dependency graph 時，直接以 affected tests 取代 final full validation又會產生假綠。

**Contract**:
1. `scripts/run-tests.sh` 是 pm-dispatch 專屬的 iteration-only planner：依 changed paths 選 direct behavioral suites、明列 coverage gaps，高扇出 substrate 自動升級 full；不得宣稱 final sign-off。
2. `scripts/run-all-tests.sh` 是 `scripts/run-tests.sh --all` 的相容 wrapper；suite registry／repeatable positive selection／平行執行與 timeout 由共用 executor 持有。未知 suite 在任何執行前 fail-loud。
3. `pr-gate` 保持 repo-agnostic，不自動偵測或強綁任何 runner 名稱。caller 可透過既有通用 `--test-cmd` 明確注入 bounded iteration command；其他 repo 可提供自己的命令或完全不提供。
4. 在 pm-dispatch 自身的 maintainer delivery profile，full `run-all-tests.sh` 在 reviewer gate lifecycle 外獨立執行，避免消耗 gate timeout；同一份待交付狀態需 reviewer GO 與 full-suite PASS。這不是通用 gate 對其他 repo 的強制規則。
5. `pm_test_result_v1` 類型化 artifact 記錄 tree fingerprint、runner contract hash、suite set、status/timestamps；verifier 只接受同一 tree fingerprint 的 full artifact。Iteration PASS 不得冒充 full PASS。

**Acceptance**: affected direct mapping能在數秒內啟動所需 suites；unmapped path 顯式呈現；high-fanout path fail-safe 升級；`pr-gate.sh` 無任何 pm-dispatch runner path；focused regression 綠；full runner既有無參數行為不變。

**Source**: 2026-07-13 使用者回報：full suite 在 PR-gate 內超過 20 分鐘並觸發 timeout；要求 runner 分層，同時維持 pr-gate 的跨 repo 工具邊界。

**Implementation evidence (2026-07-13)**: `run-all-tests.sh` 已改為 `run-tests.sh --all` 薄 wrapper，registry/selection/parallel execution 共用同一 executor；iteration planner 顯示 direct mappings/coverage gaps 並對 high-fanout 變更 fail-safe 升級。Full run 產生 `pm_test_result_v1`，verifier 對比完整 suite set、no-skip、runner contract 與實際 working-tree fingerprint，測試中或測試後任何 tree 變動都會使 evidence stale。`release-verify` 作為 pm-dispatch 自身升版入口，Phase 2 強制 fresh full + artifact verify；通用 `pr-gate` 未綁定任何 runner。Regression：runner planner/artifact 12/12、full wrapper/meta-runner 34/34、release contract 47/47、core schema 50/50、script lint 117 files。Claude full-tier bounded affected gate `gate-20260713-054416-2b2bb7` 的 15 suites 0 fail/0 skip，五 reviewers 全數 approve/pass，verified Final GO；gate 內未執行 `run-all-tests.sh`。

**See**: Claude full-tier pr-gate `gate-20260713-054416-2b2bb7`（Final GO）

---

## CC-482 — Claude PR-gate reviewer definitions 最小讀取權限 ✅ 2026-07-13

**Problem**: `pmctl gate run --executor claude` 以 headless `claude --print --permission-mode acceptEdits` 執行。`pr-gate.sh` 雖由可信父程序確認 reviewer definitions 存在，卻把 `~/.claude/agents/{critic,qa-tester,architecture-reviewer,security-reviewer,risk-reviewer}.md` 原始 home 路徑寫入 brief。Detached subprocess 無互動 approver，明示在 scope 文字中的「使用者同意」也不會轉成 Claude permission grant；Claude 因此 exit 0 但不寫 result，`pmctl gate wait` 只能以 missing-result integrity failure fail-closed。

**Evidence**:
- `gate-20260713-005954-828160`：Claude 回報使用者拒絕五份 agent definitions，result 0 bytes，wait 以 NO-GO/missing artifact 拒絕。
- `gate-20260713-010121-bf8931`：scope 已明示授權讀取仍被 permission prompt 阻擋，證明 prompt authorization 不是 capability propagation。
- 現行 workaround `--isolation none` 映射 `bypassPermissions`，授權面遠大於只讀五份固定 definitions，不可作正式解。

**Requirement**:
1. Trusted gate parent 在 dispatch 前只針對本次選取 reviewers 建立 workspace 內、run-scoped、owner-read-only snapshot；brief 不再要求 executor 讀取 `~/.claude/agents/**`。
2. Snapshot 必須位於 gate artifact leaf、不得覆蓋 target source、不得跟隨 executor 任意指定路徑；成功、NO-GO、dispatch failure、timeout 都清除 transient definitions。
3. 不新增任意 `~/.claude/**` read allowlist，不使用 `bypassPermissions`，不改 Claude adapter 的一般 workspace-write 權限模型。
4. Installed definition 缺失／不可讀／snapshot 失敗時在 dispatch 前回傳明確 operational error，不產生 synthetic NO-GO/missing-result 組合。
5. Regression 覆蓋 sequential/parallel brief path confinement、snapshot 非空/唯讀/cleanup，以及 Claude route；真實 `claude --print` smoke 必須在 `acceptEdits` 下讀完五份 definitions 並寫出可由 `gate_result_verify` 驗證的非空 result。

**Acceptance**: 原兩個 gate 的權限阻擋不可重現；result integrity 通過；home read scope 未擴張；`--isolation none` 不再是 reviewer definitions 的必要 workaround。

**Implementation evidence (2026-07-13)**: selected definitions 在 dispatch 前複製到 target workspace 的 `.gate-briefs/reviewer-definitions-<timestamp>/`，directory mode 0700、files owner-read-only，sequential/parallel briefs 只引用 snapshot，EXIT cleanup 清除。Regression：`test-pr-gate.sh` 141/141（含 workspace confinement/non-empty/read-only/cleanup 與 minimal-PATH cases）。真實 `claude --print` smoke 使用 `permission: acceptEdits`、full tier 五 reviewers，寫出 `.gate-results/result.md`、Final GO，`pmctl gate verify` 通過；未使用 `--isolation none`。首次沙箱內 smoke 僅因 Claude API ConnectionRefused，經核准網路後重跑；另一次 output 指到 `.gate-results` 外被既有 reviewer guard 正確阻擋，改為合法 path 後成功，均非 reviewer-definition 權限回歸。Claude full-tier bounded gate `gate-20260713-054416-2b2bb7` 再次以 `acceptEdits` 讀取 run-scoped snapshots，五 reviewers 全數 approve/pass、result integrity 通過、verified Final GO，未重現原 permission block。

**Source**: 2026-07-13 使用者提供兩次 detached Claude gate failure、完整 supervisor output 與 acceptance criteria。

**See**: Claude full-tier pr-gate `gate-20260713-054416-2b2bb7`（Final GO）

---

## CC-483 — Codex workflow 優先使用 pmctl memory canonical substrate ✅ 2026-07-14

**Problem**: 現有 Codex workflow/host guidance 可能先使用 Codex 自身 memory surface，再把 `pmctl memory` 視為 fallback；但本專案的跨 host continuity 契約已由 [[CC-480]] 定義為 project-owned `pmctl memory`。若 provider priority 反轉，同一 repo 會產生兩套互不一致的記憶來源，Claude→Codex 切換表面成功、實際 retrieval/provenance 漂移。

**Requirement**:
1. 盤點 Codex host instructions、`pmctl pm prepare`、guard injection、context pack 與任何 native memory integration 的實際呼叫順序；以 runtime evidence 判斷目前誰先讀、誰能寫，不只檢查文件文字。
2. Codex PM/task workflow 的 canonical source 固定為 `pmctl memory resolve` + `pmctl context pack --source memory`；Codex native memory 若保留，只能是明示、可觀測、非衝突的輔助來源，不得靜默覆蓋 canonical cards。
3. 每次 preparation/dispatch artifact 要能看出 memory provider、canonical dir/project key、resolution source 與命中數；explicit invalid pmctl memory 仍依 CC-480 fail-closed，不可 fall through native memory。
4. 不把 memory location 放進 host manifest，不複製 canonical memory 到 Codex-owned directory，不破壞 Claude/OpenCode 對同一 project memory 的 continuity。
5. Live E2E：由 Claude/既有 pmctl memory 建立的辨識卡，在 Codex preparation 中由 pmctl 路徑命中；放置衝突的 Codex-native note 時不得取代 canonical constraint，artifact 清楚標示來源。

**Acceptance**: 使用者要求「使用 pmctl memory」時，runtime trace 可證明 pmctl 是第一且 canonical provider；不存在無聲 native-first/fallback；focused memory/pm/host tests 與跨 host E2E 通過。

**Dependencies**: [[CC-480]]（strict resolver + deterministic hydration，已完成）；與 [[CC-465]]/[[CC-467]] 的 retrieval quality/telemetry 正交，本票先修 provider authority。

**Source**: 2026-07-13 使用者明確指定目前應優先使用 `pmctl memory`，不是 Codex memory。

**Diagnostic evidence (2026-07-13)**: live `pmctl pm prepare --cd /home/screenleon/github/JapanJob --json` 已由 `pmctl memory resolve` 命中該 repo 的 canonical legacy memory dir/project key，且 `memory_context_status=hydrated`；pmctl coordinator 本身不是 native-first。缺口位於 Codex interactive host wiring：目前 live `~/.codex/hooks.json` 只有 Bash `PreToolUse` guard，沒有 prompt/session entry 將 preparation 固定導入 pmctl memory。拋棄式 `UserPromptSubmit` payload/injection probe 被中斷，未取得 runtime contract 前不先綁定未驗證 hook。

**Implementation handoff (session close, 2026-07-13)**: working tree 尚未 commit，CC-483 保持 active。已完成 host-neutral provenance（`provider=pmctl`、canonical project key/dir、resolution source、hit count/refs、native `auxiliary/unknown`）、Codex `UserPromptSubmit` 安裝、OpenCode `--host opencode` preparation、strict locked `pmctl memory append-episode`、Claude `/mem-log` 與 Stop skeleton writer 遷移、invalid explicit 讀寫 fail-closed、generic non-git resolver opt-in，以及 dispatch brief 的 canonical provenance。因目前 checkout/global `pmctl` 沒有 `simplify` 子命令，已用 Codex read-only simplify/reuse review 代行並依結果抽出共用 host enum、prepare/run hydration、resolver-owned generic fallback，且把 Stop 寫入納入同一 lock。Focused evidence：memory 67/67、pm 30/30、guards full 294/294（新增後 invalid-explicit 2/2、session-hook 11/11）、commands 277/277、Codex host 36/36、OpenCode host 13/13、Codex doctor 9/9；lint-scripts/agents/frontmatter/test-docstrings 均通過。Live isolated E2E 已實際驗證 Codex 0.144.1 prompt payload/injection 與 invalid explicit pre-model block、Claude Code 2.1.207 canonical injection、OpenCode 1.17.8 `/pm` preparation；後續不得再用 Claude 做 gate（使用者額度要求）。本 session 結束前 full suite 僅啟動後即依使用者要求停止，沒有 sign-off 結果；Codex-only PR gate 尚未執行。下一 session 先重跑 full suite，處理真正 regression（若有），再以 `pr-gate.sh --executor codex --allow-dirty` gate。direct-impact planner 自身的既有無輸出 exit 1 已拆為 [[CC-486]]，不可誤報為 CC-483 產品失敗。

**Outcome**: 2026-07-14 完成 Claude、Codex、OpenCode 共用 canonical `pmctl memory` resolver/writer、可觀測 provenance、Codex prompt/session hooks 與 symlink-safe atomic episode append。Full suite 77/77、Claude full-tier gate Final GO，PR CI 全數通過；CC-486 維持獨立 deferred，不併入本票。

**Post-close audit (2026-07-14)**: 上述「Codex prompt/session hooks」表述過廣。PR #399 的 Codex installer 已接上 `UserPromptSubmit` canonical read hook，但未安裝 `Stop` session writer；`hosts/codex/host.yaml` 也仍以 `session_lifecycle provider:none / confidence:assumed` 誠實標示。writer API 與 Claude Stop migration 已完成，不等於 Codex lifecycle write binding 已完成。此 closure gap、live install/config migration 與「更新 memory」自然語言路由的可測試契約改由 [[CC-488]] 承接，不重開本票。

**See**: pr:#399

---

## CC-487 — GitHub Actions `test-guards` 非確定性掛起與 bounded diagnostics ✅ 2026-07-14

**Problem**: main SHA `0b66f1f` 的 GitHub Actions run `29298816362` 中，`test-guards` job 從 2026-07-14 01:32:51Z 執行至 02:30:38Z，停留在 `== guard-inject-memory ==` 後沒有更多輸出，最後由使用者手動取消。runner cleanup 記錄兩個殘留 `bash` process。該區段不只包含 inject hook，亦包含 `memory-usage/concurrent-no-lost-updates` 與 `memory-usage/contention-matrix-flock-and-mkdir-fallback` 等背景 writer／`wait` 測試；CI 未啟用逐 case breadcrumb，現有 artifact 無法確定是哪一個 case 或 process 未收斂。

**Boundary**: 目前不能把這次取消判定為 canonical-memory 產品 regression。相同程式碼在乾淨 HOME 的本機完整 `scripts/test-guards.sh` 為 296/296，inject/context 範圍 50/50；contention matrix 連跑 12 次、concurrent update 連跑 20 次均通過。這是一張獨立 repo-wide CI hardening 票，不混入 CC-483、CC-486 或 maintainer workflow 內容。

**Requirement**:
1. GitHub Actions 的直接 `test-guards` job 必須輸出 `RUNNING test-guards/<case>`，取消或逾時時能從 log 唯一定位 active case。
2. 對含背景 writer／FIFO／`wait` 的 guard concurrency cases 加 case-level deadline、TERM→KILL 與 `EXIT` cleanup；任一 writer 失敗或未退出時輸出 backend、round、writer id、PID、lock state 與已完成計數，不得無界等待。
3. 對直接 CI job 加整體上限，且上限必須大於正常完整 suite 的合理波動、遠小於 57 分鐘；timeout 必須保留最後 case breadcrumb 與診斷，而非只留下 group heading。
4. 使用接近 GitHub `ubuntu-24.04` runner 的乾淨 HOME/PATH 重跑完整 suite 與 contention stress；不得靠放寬正確性斷言、降低 writer 數或跳過 mkdir fallback 來讓測試變綠。

**Acceptance**: (a) 正常 CI `test-guards` 完整通過；(b) 人工注入一個不退出 writer 時，在 bounded deadline 內非零結束、指出精確 case/writer 並清除所有 child process；(c) 不再可能讓單一 guard case 無輸出佔用 runner 近一小時；(d) focused contention stress、完整 `scripts/test-guards.sh`、`scripts/test-run-all-tests.sh` 與 `git diff --check` 全綠。

**Evidence**: GitHub Actions run `29298816362`, job `86978053691`；本機乾淨環境完整 296/296 通過，故根因仍需以新增 breadcrumb／bounded diagnostics 捕捉，不能從單次取消紀錄過度推論。

**Dependencies**: 承接 [[CC-477]] 已完成的 lock protocol 與 runner breadcrumbs；本票只處理仍存在的 CI hang 可診斷性與 bounded lifecycle。

**Closed 2026-07-14（Draft PR #402）**: Draft PR #402 已建立；standard implementation gate `gate-20260714-075600-a3affd` 與針對 busy-spin／nonzero-child coverage findings 的 targeted gate `gate-20260714-080619-5069e6` 均為 `Final: GO`。最終實作加入逐 case breadcrumb、tracked child registry、case deadline、TERM→KILL／EXIT cleanup、FIFO release 防阻塞與 hang/nonzero fault-injection regressions；`test-guards` 300/300、authoritative full suite 77/77 通過。依維護者流程於 PR #402 建立後 terminal close，合併該 PR 即完成交付。

**See**: pr:#402

---

## CC-488 — Codex canonical memory lifecycle 與更新路由收口 ✅ 2026-07-14

**Problem**: PR #399 已建立跨 host 的 strict resolver、locked `pmctl memory append-episode` writer API，並讓 Codex installer 能安裝 `UserPromptSubmit` canonical read hook；但目前 live `~/.codex/hooks.json` 仍只有 `PreToolUse`，Codex installer 尚未安裝 `Stop` writer，manifest 也未宣告已驗證的 `session_lifecycle`。此外，使用者以自然語言要求「更新專案 memory」時，仍可能由 agent 寫入 Codex 私有 `.codex/memories/...`，而不是 canonical `episodes.jsonl`；live resolver 亦仍為 `resolution_source: legacy`。因此資料面健康不代表 Codex 的讀、寫、選址與操作路由已形成可測試的 end-to-end contract。

**Boundary**:
1. [[CC-483]] 保持 closed；本票只承接其 post-close Codex lifecycle／routing closure，不重做 resolver、writer API 或 provider provenance。
2. live reinstall、`~/.pm-dispatch/config` 設定與錯誤私有紀錄遷移是部署／資料修復步驟，必須在 product contract 與 isolated tests 通過後執行，不能用手動修機器掩蓋 installer/doctor 缺口。
3. 不把 [[CC-486]] planner bug 或 [[CC-487]] CI hang 混入本票；它們各自維持獨立狀態。

**Requirement**:
1. 以拋棄式 `CODEX_HOME` 和真實 Codex hook payload probe 驗證 `Stop` 的 `cwd`、`session_id`、重複觸發與 headless trust 行為；證據不足前不得把 manifest capability 從 `assumed/none` 升級。
2. Codex install/uninstall 必須對稱管理 canonical session writer：保留 foreign hooks、exact checkout identity、含空白路徑可執行、重裝不重複、卸載只移除本 checkout 項目。共用 `guard-session-summary.sh` 不得有 Claude、Codex 或其他 CLI 預設值；必須由各 host-specific installer／薄 adapter 明示且驗證 provenance，避免目前或未來 host 的 episode 被錯誤歸因。
3. doctor 必須分別檢查 command guard、prompt read hook 與 Stop write hook；只有實際 wiring 加 live probe 通過後，`hosts/codex/host.yaml` 才能宣告 `session_lifecycle` 的 `host_hook` provider、coverage 與 confidence。
4. 為「更新專案 memory／請更新 memory」建立 Codex host instruction／command contract：canonical 目的地必須先由 repo project identity 解析，再由 Codex-owned adapter 明示實際 source host，呼叫 `pmctl memory append-episode --repo-root <repo> --host codex --summary ...`。此處 `codex` 是 adapter provenance，不是 canonical 預設；Claude、OpenCode 或未來 CLI 必須各自明示自己的 host。Codex native memory 只能是明示 auxiliary，不得作為 project memory 的寫入 fallback。若 Codex 沒有可安裝、可強制的 instruction surface，必須提供可機械呼叫的 wrapper/command seam 並把 unsupported 邊界寫進 doctor/contract；只補提醒文字不算完成。
5. 新增 filesystem-diff regression/live E2E：從自然語言「更新專案 memory」情境出發，確認 canonical `episodes.jsonl` 新增一筆 `host=codex` episode，Codex 私有 memory root 沒有新增或修改 project 記錄；invalid explicit config 必須 fail closed，不能轉寫 private/legacy store。
6. 將 live canonical dir 寫入 `~/.pm-dispatch/config` 的 `memory.projects.<project_key>.dir`，使 Claude、Codex、OpenCode 對同 repo 均回報 `resolution_source: config`、相同 project key/physical dir、readable/writable。此步必須先記錄現有 resolved path，禁止建立第二份 memory 或複製資料；失效 config 的跨 host probe 必須一致 fail closed。
7. 以「先 canonical、後刪除」順序遷移本次錯誤記錄：來源檔雖位於 Codex 私有 memory，但 canonical 目的地只由 repo project identity 決定，不由目前 CLI 決定。遷移時必須明示實際產生該事件的 source host（本次歷史事件可證明為 Codex；若 provenance 無法證明則拒絕猜測，改由操作者明示 `generic`），再用 `pmctl memory append-episode --repo-root <repo> --host <observed-host>` 寫入等價且可驗證的 episode。確認 canonical 成功與唯一性後，才移除 `.codex/memories/extensions/ad_hoc/notes/20260714-115550-pr400-merged-workflow.md`；保留遷移前後 evidence，失敗時不得先刪來源。這是一次 source-adapter cleanup，不代表 canonical memory 預設 host=codex。

**Acceptance**:
1. isolated install 產生 `PreToolUse`、`UserPromptSubmit`、`Stop` 三條預期 wiring；idempotent install、symmetric uninstall、foreign/sibling checkout preservation 與 spaced-path cases 全綠。
2. Codex Stop live smoke 只新增一次 canonical skeleton episode，`host=codex`、session id/cwd 正確；doctor 與 manifest declared/probed/effective 三層一致。
3. 「更新 memory」E2E 只有 canonical episodes 改變，Codex 私有 memory 無 project write；explicit invalid path 非零退出且兩邊都不寫。
4. live 三 host resolve 均為 `config` 且指向目前 75 筆、`issues_count: 0` 的同一實體 store；錯誤私有 note 已在 canonical append 驗證後清除。
5. focused Codex host/doctor/memory/guard/install tests、`./cli/pmctl backlog lint`、`git diff --check` 通過；涉及 hook concurrency 的驗證不以降低 [[CC-487]] 斷言或跳過 case 方式完成。

**Execution order**: (A) Stop payload/provenance probe → (B) installer/uninstaller/doctor/manifest + tests → (C) update-memory routing contract + filesystem-diff E2E → (D) isolated full host acceptance → (E) live reinstall → (F) explicit config 三 host verification → (G) canonical append 後清理私有 note。任何階段 fail closed 就停止，不進行後續 live mutation。

**Dependencies**: 建在 [[CC-480]] strict resolution 與 [[CC-483]] canonical writer/provider work 上；與 [[CC-452]] 的一般 guard hardening 共用安全約束，但不得等待其全部 hygiene scope 才修正 Codex host provenance。[[CC-487]] 若仍 active，只影響 full-suite/CI sign-off 的解讀，不改變本票 focused product acceptance。

**Source**: 2026-07-14 live audit：canonical doctor 75 entries、0 issues、read/write healthy；Codex live hook 缺 `UserPromptSubmit`/`Stop`，resolver source 為 legacy，且發現一筆誤寫到 Codex private memory 的 PR #400 workflow note。

**Outcome**: Codex installer 現在對稱管理 `PreToolUse` command guard、`UserPromptSubmit` canonical injection、`Stop` canonical skeleton writer，以及 `$CODEX_HOME/AGENTS.md` marker-delimited update-memory guidance；共享 Stop writer 要求明示 `--host`，沒有 CLI-specific 預設值，各 host adapter 必須注入自己的實際 provenance。explicit update seam 位於 manifest-owned `hosts/codex/bin/memory-update.sh`，因此該 Codex-owned adapter 明示委派 strict `pmctl memory append-episode --host codex`；其他 CLI 必須由自己的 adapter 明示 host，canonical store 仍只按 repo project identity 選址。invalid explicit path fail closed，filesystem-diff regression 證實不修改 Codex native memory。真實 Codex 0.144.3 headless probe 捕捉到 Stop payload 的 `session_id`/`cwd`/`hook_event_name`，manifest/doctor 因而可誠實宣告 `session_lifecycle host_hook/partial/probed`。Live installer 已重裝；`~/.pm-dispatch/config` 明示既有 canonical dir，Claude/Codex/OpenCode preparation 均回報同 project key、同實體路徑、`resolution_source=config`、readable/writable/hydrated。錯誤 PR #400 私有 note 的 canonical `writer_host=codex` 只記錄該歷史事件確由 Codex session 產生，不是系統預設；確認唯一落盤後才移除來源。Refactor/reuse audit 為 `CHANGED`：install/uninstall 重複的 Codex `AGENTS.md` marker strip、空白正規化與 contract render 已收斂到 host-owned `hosts/codex/lib/memory-contract.sh`，並新增 malformed-marker fail-closed 回歸。驗證：Codex host 41/41、host manifest 89/89、guards 297/297、memory 69/69、doctor 56/56、install 88/88、affected planner 4/4、lint-scripts、backlog lint、`git diff --check` 全綠；`~/.claude/statusline-chain.conf` 安裝前後 `cmp` 相同且 SHA-256 固定為 `6eec303a31b7f161fecec88eb6b8467f236d77c17ded09c3c85435090da9eeaf`。

**PR-gate R1（2026-07-14, NO-GO）**: Claude full-tier gate `gate-20260714-134455-1466632` 找到一個 blocking fixture-isolation gap：live `~/.pm-dispatch/config` 使 `test-guards.sh` 的 inject/session fixtures 誤解析到真實 canonical store，造成 263 pass / 34 fail，包含本票新增的 Codex Stop provenance case 實際寫入 0 筆。已修為 suite-level `PM_DISPATCH_CONFIG_FILE` missing-path isolation，重跑 297/297。architecture advise 同步處理：`lint-scripts.sh` 現掃描 `scripts/*.sh`、`hosts/*/bin/*.sh`、`hosts/*/lib/*.sh`（119 files），CI 另對 `./hosts` 執行 shellcheck。risk reviewer 指出的全域單值 config 跨 repo bleed 經 live read-only probe 確認：JapanJob 與 qa-testing-rules 會解析到 pm-dispatch memory；此 resolver/schema redesign 獨立列為 [[CC-490]]，不混入本票 host lifecycle diff。

**See**: [[CC-483]], [[CC-489]], [[CC-490]]

---

## CC-492 — Claude UserPromptSubmit context hook timeout envelope 與殘缺 DB 復原 ✅ 2026-07-15

**Problem**: Claude Code 的 `UserPromptSubmit` command hook 未明確設定 timeout，實際使用 30 秒預設值；但 `guard-inject-context.sh` 的既有索引刷新與初次建立預算分別為 45／120 秒。JapanJob live session 已觀察到 context hook 在 30.020 秒被外層終止，stdout 被丟棄；同時先前中斷留下「DB 檔存在但 files=0」的殘缺 cache，使 hook 誤判為既有索引並在後續 prompt 重複進入超時路徑。

**Requirement**:
1. Claude installer 必須為 managed `guard-inject-context.sh` 寫入明確、且大於內部最大預算並保留 cleanup 餘裕的 handler timeout；重複安裝要升級既有缺值／過短值，不得只處理新 hook。
2. context hook 必須辨識「DB 存在但沒有任何 committed file row」的未完成 initial build，沿用 initial-build timeout 與失敗清理，不得永久誤分類為 incremental cache。
3. doctor 必須診斷 managed context hook timeout 缺失或低於契約值；memory injection hook 與非 managed hook 不得被連帶改寫。
4. 回歸覆蓋 fresh install、existing-hook migration、idempotency、殘缺空 DB timeout cleanup、unrelated hook preservation，以及 handler/internal timeout envelope。
5. Claude permissions 使用其接受的 `Edit(<workspace>/**/.gate-results/**)`，installer 升級時移除舊 managed `Write(...)`；uninstaller 同時辨識並移除新 `Edit(...)` 與歷史 `Write(...)`。`/tmp/*` 權限不是 pm-dispatch installer 管理項，不得擅自新增或刪除。

**Acceptance**: sandbox install 後 context hook 具有明確 timeout，doctor 通過；模擬已存在的空 DB 與慢速 index 時，hook 在自身預算內 fail-open、清除殘缺 cache，且不再由 Claude 30 秒外層先行終止。permission upgrade 只留下 managed `Edit(.gate-results)`、不產生任何 `Write(...)`；uninstall 可清除新舊兩種 managed spelling 且保留 `/tmp/*` 等非 managed 權限。live Claude 設定升級後，JapanJob 下一次 prompt 不再出現 `UserPromptSubmit hook timed out after 30s`。

**Source**: 2026-07-15 JapanJob Claude session `30e97e81-4bcf-4308-aa1c-78c25d451ba3` live diagnosis。

**Closed 2026-07-15（Draft PR #403）**: managed context hook timeout 已提升為 150 秒，殘缺 files=0 DB 會重走 initial-build recovery；installer 與 uninstaller 已改用並對稱清理 managed `Edit(.gate-results)`，同時相容歷史 `Write(...)` 且保留非 managed `/tmp/*` 權限。Sequential full Codex gate `gate-20260715-003400-ab8888` 為 `Final: GO`，affected suites 全綠，live Claude doctor 26/26 通過，JapanJob prompt hook 12.77 秒完成並建立 1320-file index；受另一 session 並行刷新 live context DB 影響的 full-suite isolation 斷言，已獨立重跑 `test-pmctl-context` 114/114 通過。

**See**: pr:#403

---

## CC-484 — JapanJob／qa-testing-rules pmctl context refresh 失效 ✅ 2026-07-13

**Problem**: JapanJob 的 session 與 qa-testing-rules 實際工作流沒有順利用 `pmctl context` 刷新內容。[[CC-455]] 曾修正 context plane 預設 repo root 跟隨 caller CWD，但目前 live 行為仍可能在 repo-root resolution、worktree/project key、context.db 位置、mtime skip、session hook/prepare wiring 或 update/query 順序其中一層失效；只看 unit test 不能確認是哪一層。

**Investigation / Requirement**:
0. Capability gate：`sqlite3` 不在 PATH 時不執行 context hook／不建 DB，且 session 不失敗；`sqlite3` 可用且 DB 不存在時，第一次實際 context 使用必須自動建立 repo-local DB，不要求人工先跑 index。自動建立時須把 `.pm-dispatch/` 加入 repo `.gitignore`，且 context file discovery 本身必須排除整棵 `.pm-dispatch/`，避免 DB、WAL、pack 或 gate/runtime artifacts 被反向索引。
1. 分別在 `/home/screenleon/github/JapanJob` 與 `/home/screenleon/github/qa-testing-rules` 記錄 `pmctl context index/update/query/pack` 的 resolved repo root、DB absolute path、DB mtime/content fingerprint、indexed/changed/skipped counts與 query hit provenance。
2. JapanJob 必須涵蓋實際 session/PM preparation 入口，不只手動 CLI；確認 session 啟動後新內容是否進入同 repo 的 canonical DB，是否誤打 pm-dispatch 或另一 worktree DB。
3. qa-testing-rules 必須涵蓋 gate/reviewer 使用前的 refresh 路徑；確認 rules 更新後 context pack 能讀到新內容，且 gate artifact 不被誤索引為 knowledge/source。
4. 建立最小可逆 repro：新增唯一 marker → refresh → query/pack 命中 → 移除 marker → refresh → 不再命中；所有測試使用 temporary fixture/isolated state，除非 live wiring 驗證必要，不污染兩 repo committed content。
5. 依根因補 actionable diagnostics：輸出 resolved repo/DB/freshness，不允許「command exit 0 但刷新了別的 repo」；補跨 repo E2E 防止 CC-455 類回歸。

**Acceptance**: 兩 repo 的 marker round-trip 均通過；session/prepare/gate 實際入口與手動 CLI 使用同一 canonical context DB；錯誤 repo root 或 stale DB 可在單次診斷輸出中辨識；focused context tests 與 live smoke 有 artifact evidence。

**Dependencies**: [[CC-455]]（CWD git-toplevel default，已交付）、[[CC-480]]（canonical memory resolution）；先診斷 context refresh，不與 CC-483 provider priority 混修。

**Source**: 2026-07-13 使用者回報 JapanJob session 與 qa-testing-rules 均未順利刷新 context。

**Diagnostic / implementation evidence (2026-07-13)**: qa-testing-rules 原本沒有 DB，根因是 prompt hook 明確關閉 autobuild；JapanJob DB 則停在 2026-07-07，且每次 unchanged refresh 都無條件重建 FTS（live 29.870s，超過舊 10s hook timeout）。hook 現在先 capability-check `sqlite3`，缺少時完全不呼叫 pmctl；存在時首次 prompt 以 120s budget 自動建立 `<repo>/.pm-dispatch/ctx/context.db`，既有 DB 以 45s refresh，首次 timeout 只保留可確認有 committed rows 的 cache。unchanged refresh 保留 FTS，JapanJob live 降為 6.254s。indexer 與 Git 各自排除 `.pm-dispatch/`：live 查到 JapanJob 舊 DB 曾含 `pre-gate.sh`/`post-gate.sh` 兩筆自我索引，修正版 refresh reconciliation 後為 0；qa-testing-rules 亦為 0。`pmctl context status [repo] --json` 現可一次回報 resolved root、DB、sqlite capability、new/changed/deleted 與 freshness；prompt/session hook、`pmctl pm prepare` 與 pmctl gate wrapper 在各自 workflow boundary best-effort refresh，但 context 仍是可選 capability。Regression：context baseline 112/112 + workflow status focused 2/2、guards 294/294、pm prepare 27/27、gate wrapper 19/19。Live 可逆 marker E2E 已在 JapanJob 與 qa-testing-rules 各自完成 add → prompt/session hit → query/pack hit → prepare 同 DB → gate boundary refresh → remove → no-hit，canonical DB 分別為 `<repo>/.pm-dispatch/ctx/context.db`，final indexed files 1294/25，兩庫 `.pm-dispatch/%` 自我索引列數均為 0，marker/docs fixture 已清除。Full-tier gate `gate-20260713-054416-2b2bb7` Final GO 後，critic 指出 AUTOREFRESH=0 狀態過度回報；已修為 `skipped`，缺 sqlite 統一回報 `unavailable`。首次 targeted re-gate `gate-20260713-060112-1bfb0a` 因 unavailable 分支無直接測試 NO-GO；補 regression 後 `gate-20260713-060616-424cda` critic approve / qa pass，test_suite pass，verified Final GO。

**See**: Claude full-tier pr-gate `gate-20260713-054416-2b2bb7` 與 targeted re-gate `gate-20260713-060616-424cda`（Final GO）

---

## CC-485 — 工具能力與 maintainer policy 分離；固定本專案 release procedure ✅ 2026-07-13

**Problem**: pm-dispatch 維護者有自己的開發、PR 與 release 習慣，但 pm-dispatch 同時是通用工具。其他使用者可能只需 dispatch/context/test 其中一部分，甚至不使用 PR-gate；若把維護者習慣寫死在通用 command，就會破壞 repo-agnostic 邊界。另一方面，本專案自己的 release 必須只有一套固定且可驗證的 procedure，不能把開發期 affected feedback 混成 release phase，也不能重複要求 `release-verify.sh --e2e` 已內含的 full suite。

**Requirement**:
1. gate、`--test-cmd`、affected planner、full runner、artifact verifier 與 release verification 都保持可獨立調用；不得因安裝/使用 pmctl 而強制執行其中任何一項。
2. 不建立通用 workflow profile/orchestration engine；其他 repo 如何組合或完全不使用上述能力，由其自行決定，default 行為維持向後相容且不猜 runner 名稱。
3. affected suites 與可選 PR-gate 僅屬 pm-dispatch 的開發/PR feedback；它們不是固定 release phase，也不得被描述成其他使用者必須遵守的流程。
4. pm-dispatch 唯一固定 automated release 入口為 `scripts/release-verify.sh --e2e`：Phase 2 自行 fresh-run + verify `run-all-tests.sh` artifact，Phase 4 增加 live dispatch/gate；`--no-suite` 或任何 required skip 只能 PARTIAL GO。另完成 `docs/RELEASE_CHECKLIST.md` 的人工驗收後才可 tag。
5. release procedure 不額外要求 affected run 或第二次 standalone full suite；既有 development/PR evidence 不得替代 release command 內 fresh full evidence。

**Acceptance**: 現有 generic command 行為不變；使用者可選 test-only、gate-only、test+gate 或全部不用。文件與回歸清楚區分 development/PR policy 與 release procedure；`release-verify.sh --e2e` 保證仍執行並驗證 fresh full suite，release source 不出現 affected-selection phase，required skip 無法產生 GO。

**Source**: 2026-07-13 使用者澄清：目的只是提供工具，不強制其他人如何使用；個人開發流程不代表其他使用方式。pm-dispatch 自身 release procedure 則必須固定，且 `release-verify.sh --e2e` 已內含 `run-all-tests.sh`，release 不含固定 affected feedback。

**Implementation evidence (2026-07-13)**: `docs/test-runner-contract.md` 已把 affected suites／optional PR-gate 限定為 development/PR policy，另列唯一 automated release 入口 `scripts/release-verify.sh --e2e`；`docs/RELEASE_CHECKLIST.md` 明示 affected evidence 不屬 release phase、不得取代 command 內 fresh full。`release-verify.sh --help` 現直接聲明 `--e2e` 只增加 Phase 4、不取代或跳過 Phase 2 full suite；回歸鎖定 full-before-E2E、source 無 affected-selection invocation、required skip 僅 PARTIAL GO。Focused validation：release-verify 49/49、run-tests 12/12、docs freshness 21/21、pmctl backlog 18/18、backlog schema 與 shellcheck 通過。

**Resolution**: 通用工具維持自由組合且不提供 workflow profile engine；pm-dispatch development/PR feedback 與 release procedure 已分層，正式 automated release 固定使用 `scripts/release-verify.sh --e2e`，再完成 release checklist 的人工驗收。Claude full-tier gate `gate-20260713-072733-444879` verified Final GO。

**See**: pr:#398

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

## CC-489 — `scripts/` domain ownership 與 manifest-driven entrypoint 重整 ✅ 2026-07-17

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

**Phase 6 implementation and final refactor/reuse audit completed (2026-07-17)**: inventory 宣告的 shared runtime、test harness、tooling、ops/release 共 151 個 implementation/fixture path 已搬到 `runtime/`、`tests/`、`tools/`、`ops/` 並移除舊檔；`scripts/` 精確剩下 19 個 move-with-shim 相容入口，內部 consumer、CLI、CI、suite registry、changed-path planner、install source 與文件皆改用 owner path。installer 的 user-helper name/source/legacy-source 收斂到單一 spec table，精準 refresh 本 checkout 的舊 symlink 並保留 foreign target；三 host resolver 重複的 template 展開收斂到 host-neutral prefix-only helper，host env/default/alias 仍由各 host 擁有，且不再全域替換路徑後段的 token-shaped literal；inventory ratchet 新增 shim→declared target linkage 與 executable 驗證，存在但誤導向的相容層會 fail loud。late live audit 另補 Codex memory/session legacy hook 去重遷移，以及 Claude/Codex doctor 對 configured managed command target 的 existence/executable fail-loud 檢查。focused suites 通過 Codex host-write 49、doctor 67、install 92、uninstall 29、OpenCode host-write 15、host manifest 91、host parity 9、inventory 11；三 host live refresh 後 doctor 為 27 ok、0 warn、0 fail，重跑 dry-run 為 0 conflict 且全部 idempotent，OpenCode 1.18.2 resolved config 載入 checkout-specific pmctl allow、`/pm` command 與 `pm_prepare` permission。final sequential Claude gate `gate-20260717-092054` 以 explicit `--test-cmd 'tests/bin/run-all-tests.sh'` 取得同工作樹 structured evidence（79 passed、0 failed、0 timed out、0 skipped），critic=advise、qa=pass、architecture=approve、security=pass、risk=pass，Final GO；非阻擋 advise 已收斂 backlog 狀態與 upgrade/reinstall 文件。draft PR #415 建立後，table、heading 與 PR reference 已同步關票。

**Acceptance**: (a) architecture map 說明每類 executable 的 owner 與允許依賴方向，variable ledger 可機械或結構化盤點每個跨模組 input/default/precedence/propagation/side effect/test isolation；(b) relocated fixture 證明 module 不再依賴舊 `scripts/` 深度推導 repo root，direct legacy entrypoint 仍能經 shim 產生 byte/exit/side-effect-compatible 結果；(c) Codex、Claude、OpenCode install/doctor/uninstall 從各自 manifest 發現 module，shared dispatcher/resolver 不列 host-specific path、env 或 default；(d) staged migration 每一刀均通過 install parity、uninstall preservation、doctor、hostile-env/full-`HOME` sandbox、full runner 與 release smoke，filesystem diff 證明不觸碰 operator 真實 host config、pmctl symlink、canonical memory 與 repo 外狀態；(e) host/adapter/shared/test 變數 ownership 沒有跨軸漂移，legacy alias 衝突、default precedence、secret redaction 與 child env allowlist 的回歸全綠；(f) 最終 `scripts/` 只保留明確定義的相容入口或通用 ops entrypoints，不再作為所有 shell code 的默認垃圾桶。

**Boundary / sequencing**: 本票在 [[CC-488]] lifecycle product contract 完成後執行（CC-488 已於 2026-07-14 done，前置條件已清除）。CC-488 只遵守新檔案 placement 與 manifest discovery 原則，不藉機搬完既有 Codex/Claude/OpenCode scripts；避免把路徑遷移 regression 混入 canonical memory correctness。2026-07-15 三方（codex/opencode/fable）multi-model synthesis 一致建議 production relocation 排在 [[CC-451]]/[[CC-490]]/[[CC-491]] 核心 harness 收口票之後，避免路徑遷移與 state/schema/evidence 收口同時進行；Phase 0 contract inventory 可先行，但不得在前置契約仍變動時開始 production move。本票可收斂變數 owner/default 位置與模組傳遞契約，但不重新設計 [[CC-490]] 的 project-scoped config schema/resolver precedence，也不改變 [[CC-491]] evidence semantics。

**Current diagnostic evidence (2026-07-15)**: `scripts/` 現有 174 files（root shell entrypoints 119、`scripts/lib` shell modules 52、`test-*.sh` 76），host manifests 仍有 7 個 doctor/install/uninstall module refs 指向 `scripts/`。shared `scripts/lib/host-manifest.sh` 的 path expander 直接解析 `CODEX_HOME`、`CLAUDE_CONFIG_DIR`、`XDG_CONFIG_HOME` 與各自 `$HOME` default；Claude config-root canonical/legacy precedence 重複出現在 install/uninstall/guards/doctor；install/uninstall 另以 `${PMCTL_BIN_DIR:-$HOME/.local/bin}` 決定真實 symlink 寫入目標。既有回饋已證明測試只覆蓋 `CLAUDE_HOME`/`CODEX_HOME` 而漏掉 `HOME`/`PMCTL_BIN_DIR` 會刪改 operator 真實 `~/.local/bin/pmctl`，因此 full-environment isolation 與 filesystem-diff 是 blocker acceptance，不是可選 hardening。

**Source**: 2026-07-14 使用者指出所有 script 集中於 `scripts/` 造成後續維護困難，要求特定內容放回對應位置並統一讀取；2026-07-15 使用者進一步指出腳本內的特定變數、default/fallback 與環境傳遞也必須獨立歸位，不能將本票當成單純搬檔。

**See**: `CHANGELOG.md` CC-489 Phase 6、pr:#415、gate:`gate-20260717-092054`

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

## CC-333 — arch: pm-dispatch runtime 解耦合（v0.6.0 umbrella epic）✅ done 2026-07-17

**Outcome 2026-07-17**: umbrella 已完成其歷史協調責任並停止作為 active 執行結構。executor/host abstraction 已由 CC-372～376、CC-412、CC-436～438、CC-445、CC-448、CC-489 等 current-tree 交付承接；尚未排程的 CC-377、CC-390、CC-393 保留為獨立票，不再依賴本 umbrella 存活。未來若需要 post-v1.0 runtime abstraction，應以 current tree 另開新 epic。

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

## CC-431 — test-e2e.sh + release-verify.sh: opencode adapter support 🟢 superseded 2026-07-17

**Superseded by [[CC-449]]**：OpenCode adapter E2E/release evidence 與 suite registry、CI parity、ship/worktree smoke 修改同一 canonical evidence surface，統一由 CC-449 交付。

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
## CC-486 — direct-impact planner 未註冊 suite 觸發 `set -e` 提前退出 ✅ done 2026-07-14

**Problem**: `scripts/run-tests.sh --base origin/main --list` 在 changed paths 含 `agents/*.md` 或 `commands/*.md` 時，`map_path` 會呼叫 `add_suite lint-frontmatter`；但 `test-suite-runner.sh --list` 沒有註冊該 suite。`add_suite` 的最後一個條件式因此回傳 1，頂層 `set -e` 直接終止，沒有 planner diagnostics，exit 1。

**Acceptance**: 未註冊的 optional mapping 不得讓 planner 提前退出；應修正 mapping 名稱或讓 `add_suite` 明確 return 0，並新增包含 agent/command changed path 的 regression，確認 `--list` 輸出已選 suites、coverage gaps 與 exit 0。不得藉此弱化「沒有任何可用 suite 時 exit 2」的既有契約。

**Evidence**: CC-483 收尾時以 `bash -x scripts/run-tests.sh --base origin/main --list` 重現；trace 停在 `add_suite lint-frontmatter` 的 `[[ -n '' ]]`。同一批 CC-483 focused suites與 lint 均綠，故此項獨立追蹤，不視為 CC-483 產品 regression。

**Outcome**: PR #400 將 agent/command/skill mappings 全部改用 canonical registered suite `test-lint-frontmatter`，並為三種 path 各補 `--list` regression；unknown path 無 evidence 仍維持 exit 2。2026-07-17 在 canonical `tests/shell/test-run-tests.sh` 重驗 18 passed、0 failed。

**See**: pr:#400

---
## CC-497 — CC-489 遷移後收口：canonical paths、文件、backlog、CI ratchet ✅ closed 2026-07-17

**Problem**: CC-489 已完成 151 個 implementation/fixture path 遷移，但 README、core docs、MILESTONES、RELEASE_CHECKLIST、CI 與 active backlog 仍有搬遷前 `scripts/` implementation 假設。19 個 compatibility shims 暫時讓舊入口可跑，卻也掩蓋產品表面漂移。

**Requirement**:
1. 以 CC-489 domain inventory 為來源，掃描 README、`docs/`、active backlog、MILESTONES、CI、installer/doctor/help operational text。
2. current operational instructions 改指 canonical `runtime/`、`tests/`、`tools/`、`ops/`、`hosts/`；舊 implementation path 只允許出現在 archive/history、migration/compatibility 說明與 inventory-declared shim parity tests。
3. stale-path lint 必須能區分 repo 舊 `scripts/...` implementation、合法 `pm/scripts/...`、installed `~/.claude/scripts/...` 與 19 個明列 shims；不得用粗糙字串禁令製造誤報。
4. `RELEASE_CHECKLIST.md` 不再硬編 suite 數量，改引用 canonical registry/「全部 registered suites」契約。
5. 更新 MILESTONES、README layout、`core/README.md` writer layer 用詞與 active backlog path；terminal tickets 由 canonical archive tool 移出 working set。
6. 與 [[CC-454]] 分工：本票只保證 canonical path/reference coverage；ShellCheck 實際 domain coverage/ignore ratchet 由 CC-454 負責。

**Done-when**: operational surface 與 current tree 一致；注入 stale `scripts/lib/...` implementation reference 時 lint fail；合法 shim/history/installed-path fixture 不誤報；release suite 數量不再手工漂移。

**Priority/Milestone**: P1，v0.9.0 NOW。

**Outcome**: PR #417 將 operational docs、active backlog、milestone 與 release metadata 收斂到 canonical owner-domain paths；既有 inventory linter 新增 inventory-derived stale-reference ratchet 與 consumer-scoped compatibility allowlist，並納入 affected-suite planning 與 CI。首次 PR gate 前已完成重構／重用審查；最終 gate GO，full suite 79 passed、0 failed、0 skipped。

## CC-456 — 去除 maintainer-local `~/github/` 佈局假設（repos-root 參數化 + sweep + lint 防再犯）✅ closed 2026-07-17

**Problem**（2026-07-06 維護者自指出）: `~/github/` 是維護者本機的 repo 佈局習慣，卻已滲進多個操作性檔案成為隱含產品假設——其他使用者的 repo 可能在任何位置。盤點（2026-07-06）：
- `agents/project-pm.md`：agent description 寫死「repos under ~/github/」；工作流第一步 `ls ~/github/` 識別專案；brief schema 指向 `~/github/pm-dispatch/docs/dispatch-brief.md`（同時硬編了 pm-dispatch 的安裝位置）。
- `agents/qa-tester.md`：`QA_RULES_DIR` default `$HOME/github/qa-testing-rules`（有 env 覆寫，但 default 是 maintainer-local）。
- `commands/pm.md`：`--all-repos` 掃 `~/github/*/`（有 `--repos-root` 覆寫，default 同病）。
- `commands/skill-refine.md`：memory dir 範例假設 `-home-<user>-github` project slug。
- `runtime/hooks/guard-pm-write.sh`：deny 訊息內嵌 `~/github/pm-dispatch/docs/...` 路徑。
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

**Outcome**: PR #418 新增單一 repos-root resolver，以 explicit flag、`PM_DISPATCH_REPOS_ROOT`、`PM_DISPATCH_REPO` parent 與 checkout parent 建立可攜式 fallback chain；移除 operational surface 的 maintainer-local 路徑假設，並以零 allowlist lint、非標準 checkout 測試及 CI/canonical suite registration 防止回歸。最終 Codex gate GO，full suite 81 passed、0 failed、0 skipped。

---
## CC-460 — `pmctl` CLI discovery：root/area/leaf help + commands registry + 四方 parity ✅ 2026-07-18

**Problem**: 使用者無法由 CLI 自身可靠學會 `pmctl`：無參數只印一行 usage；`pmctl help`、`pmctl --help`、`pmctl <area> --help` 目前都視為 unknown command 並 exit 2；unknown command 沒有可用命令或建議。README 也只列完整 command surface 的一小部分。command/subcommand 的機器可讀清單不存在單一來源，router、help、README 各自漂移。

**Why**: v1.0 若宣稱 CLI 可用，使用者必須不讀原始碼即可發現入口、理解參數並找到下一步。[[CC-446]] 也需要完整且可驗證的 command inventory，才能凍結 stable/experimental surface。

**Requirement**:
1. **Slice A — help/registry**：支援 `pmctl help`、`pmctl --help`、`pmctl <area> --help`、`pmctl help <area> [subcommand]` 與 leaf help；help 成功一律 exit 0，且不得初始化外部依賴、解析 state store 或產生任何寫入副作用。
2. help 至少包含 summary、usage、主要 options、常見 examples、stability 標記與相關下一層 command；unknown command 顯示最接近建議及 root-help 指引。
3. 建立 canonical command registry，至少含 command path、summary、usage、stability、是否支援 JSON、是否 mutating。router 是「是否可執行」的權威；registry/help metadata 不得另造第二份 command existence 清單。
4. **Slice B — discovery/parity**：`pmctl commands --json` 列出 registry 全部 command/subcommand；README command index 由 registry 生成或機械核對。
5. **四方防漂移 lint**：router ↔ registry/`commands --json` ↔ help ↔ README 任一方向缺漏即 fail loud，接入 CI；包含新增 command 未進 help/README 與刪除 command 仍留文件的注入測試。

**Non-goals**: 不在本票重寫所有長篇教學；不覆蓋 skill/agent 的 coverage 分類（見 [[CC-449]]）。`pmctl version --json` 可作第二 slice 候選，但是否列 stable 由 [[CC-446]] 定案。

**Done-when**: 新使用者可只靠 root/area/leaf help 找到並正確組出主要 workflow；help path 全部 exit 0 且無副作用；`commands --json` 涵蓋全部已註冊 command；四方 parity lint 的正反向注入測試通過。

**Outcome**: `pmctl help` / `--help` / area and leaf help、canonical
`cli/commands.tsv`、`pmctl commands --json` 與 README command index 已落地；
router↔registry↔help↔README parity lint 與正反向 regression 已接入 CI/full
runner（pr:#421）。

**Dependencies**: 與 [[CC-446]]（stable CLI 分級表需要這份清單作為覆蓋範圍的事實依據，宜同批或先行）、[[CC-451]]（parity lint 設計參照）。v0.9.0 候選（契約凍結 Phase 3 的前置證據）。
**Source**: 2026-07-07 openyida（github.com/openyida/openyida）跨專案分析——`commands --json` manifest + `check:commands` 三方防漂移模式；承接 [[CC-033]] #4、[[CC-446]] #5a 兩個既有票內已記載的缺口。

## CC-454 — canonical ShellCheck domain coverage + ignore ratchet ✅ 2026-07-17

**Problem**: CC-489 已把 canonical implementation 搬到 `runtime/`、`tests/`、`tools/`、`ops/`、`hosts/`，但 `.github/workflows/lint.yml` 的 action-shellcheck 仍以 `scripts/` 為主要掃描入口，且保留大量搬遷前 `ignore_names`。問題已不只是 allowlist 太大，而是 canonical production/test domains 可能完全未受等價靜態檢查。

**Why**: compatibility shims 仍綠不能代表 canonical implementation 已被 lint。v1.0 前必須讓 CI 與 local lint 對 current tree 提供一致證據。

**Requirement**:
1. shellcheck 拆成語意獨立的 CI job，掃描 canonical `runtime/`、`tests/`、`tools/`、`ops/`、`hosts/` shell domains；`scripts/` compatibility shims 仍需 parity/basic validation。
2. CI 與 local lint 共用同一份 domain inventory；新增或搬移 shell implementation 不得因路徑改變而脫離掃描。
3. `ignore_names` 改為 current canonical path 的 explicit ratchet；每筆須有理由，新檔預設不得加入，搬遷前不存在的 ignore name 必須 fail。
4. 補 moved-path parity 與注入測試：在 canonical domain 新增違規 shell 時 CI/local lint 都能抓到；只掃舊 shim 不算通過。

**Dependencies**: 與 [[CC-497]] 的 stale-path/docs ratchet 分工；與 [[CC-449]] 協調 CI evidence parity，但本票獨立負責 ShellCheck domain coverage。v0.9.0。
**Source**: 2026-07-06 盲測程式碼稽核（測試/CI 角度）。
**See**: pr:#420

## CC-501 — v0.8.0→v0.9 candidate 一次性 upgrade smoke ✅ 2026-07-18

**Problem**: v0.8.0 之後完成 host manifest、151 個 script domain 搬遷、canonical memory continuity、portable repos-root 與 stale-path ratchet，但目前 release evidence 只驗 current tree 的 fresh install/unit behavior，沒有證明既有 v0.8.0 使用者重跑 v0.9 installer 時會把 managed targets refresh 到 canonical owner paths，也沒有證明 uninstall 不會誤傷 foreign config 或 canonical memory。

**Why**: 這是一次特殊的大型遷移風險，不能等到 [[CC-447]] 在 v0.12.0 建立通用 N-1 contract 才第一次驗證。另一方面，本票只驗 v0.8.0→v0.9 candidate，不提前吞入 CC-447 的 future-release automation、clean-machine onboarding 或 live dogfood。

**Requirement**:
1. 以 tag `v0.8.0` 與待發布 v0.9 candidate 的兩個獨立 checkout/worktree 執行；記錄兩端 commit SHA。
2. 測試環境必須覆蓋整個隔離 `HOME`，並顯式隔離 `CLAUDE_CONFIG_DIR`、`CODEX_HOME`、`XDG_CONFIG_HOME`、`PMCTL_BIN_DIR`、state/telemetry roots；不得只換 host home 後仍碰真實 `~/.local/bin/pmctl` 或 operator state。
3. v0.8.0 install 後建立代表性的 Claude/Codex/OpenCode managed config，同時在各 config 寫入 foreign marker；建立 project-scoped canonical memory fixture並保存 config、memory、使用者資料 checksum。
4. 以相同隔離環境切換到 v0.9 candidate 重跑 install；要求 `doctor --json` 0 FAIL、三 host managed target 指向 candidate canonical owner paths、retired `scripts/` implementation targets 不再被 active config 引用，第二次 dry-run 冪等。
5. 執行 candidate uninstall；只移除 manifest-owned artifacts，foreign hooks/config、canonical memory、使用者資料與非本專案 managed block 必須 byte-identical。
6. 產出可追溯 artifact，至少含 baseline/candidate SHA、每階段 exit status、doctor summary、old→new target assertion 與 preservation checksum；任一 FAIL 都阻擋 v0.9 release。

**Done-when**: v0.8.0→v0.9 candidate 在隔離環境完成 install→upgrade→doctor→uninstall，doctor 0 FAIL、所有 retired target 已 refresh、foreign config/canonical memory checksum 不變，且結果 artifact 可由 maintainer 重跑。

**Update 2026-07-18（pre-release rehearsal）**: 已新增
`ops/release/upgrade-smoke-v0.8-v0.9.sh`、canonical suite registration 與 release
checklist 入口。實跑 `v0.8.0` (`b5eb215`) → dirty candidate based on `746096c`
為 GO：doctor 0 FAIL、三 host old→new、retired target 0、dry-run 冪等，uninstall
後 foreign config／canonical memory／user data checksum 全保留。Smoke 暴露並補上
manifest-owned Claude/pmctl 跨 checkout transfer、stale dispatch allowlist cleanup、
Codex compatible-checkout identity refresh、OpenCode checksum-verified receipt transfer。
當時的 release acceptance 邊界是：這批變更提交後必須以 final clean
candidate SHA 完成驗收；dirty rehearsal 不得作 tagging evidence。

**Outcome**: upgrade harness 與跨 checkout ownership transfer 修復已由 pr:#424
合併；維護者於 2026-07-18 確認 final CC-501 acceptance 已完成，本票不再
重跑。此一次性 evidence 不取代 CC-447 的 future-release N-1 contract。

**Dependencies**: [[CC-454]] 與 [[CC-502]] 完成後執行最終 candidate smoke；[[CC-497]]、[[CC-456]] 已完成且只作 baseline，不重新開票。完成本票不取代 [[CC-447]]。P1，v0.9.0 release acceptance。

## CC-502 — shared gate/reviewer 去除 Claude-host 隱性前置 ✅ 2026-07-18

**Problem**: `runtime/bin/pr-gate.sh` 是 shared gate runtime，卻無條件從 `$HOME/.claude/agents` 載入 reviewer definitions；同一批 reviewer definition 會交給 Codex 與 Claude executor，但 `agents/critic.md`、`agents/architecture-reviewer.md` 又直接要求讀 `~/.claude/projects/<id>/memory/...`。結果是 Codex/OpenCode 作 PM host 或乾淨非 Claude HOME 即使具備 repo checkout、pmctl 與 executor auth，仍被 Claude installation tree 與 Claude memory layout 隱性綁住。

**Why**: v0.9 已把 host manifest、canonical memory 與 executor adapter 宣告成正交軸；shared gate 仍依賴 Claude host root，會讓該承諾在最重要的 release gate 路徑失真。這也是 [[CC-501]] upgrade smoke 若只在 maintainer HOME 通過就會漏掉的環境污染。

**Requirement**:
1. reviewer definitions 以 repo-owned source或明確 resolver/參數取得；shared gate 不得把 `$HOME/.claude/agents` 當 default 或 prerequisite。若需要 snapshot，仍只把本次選中的 immutable definitions 複製到 reviewed workspace artifact dir。
2. reviewer memory 指令改消費 gate/preparation 提供的 canonical memory provenance/context，或走 `pmctl memory/context` read surface；不得推導另一個 host-local path，也不得在 canonical resolution invalid 時 fallback。
3. 明確區分 host 與 executor：Claude executor 可保留 adapter-specific 行為，但選擇 Codex executor或 Codex/OpenCode PM host 不得要求 Claude config tree存在。
4. 新增 regression：使用沒有 `.claude/agents` 的隔離 HOME，從 repo checkout 執行 gate preparation/reviewer snapshot；驗證 Codex executor path 能讀 reviewer definitions與 canonical context，且不建立 Claude host目錄。
5. 新增 targeted content ratchet，阻止 shared gate/reviewer contract 再引入 Claude host config root；允許 executor enum/model/adapter文字，不採全 repo `claude` 字串禁令。

**Done-when**: `pmctl gate run --executor codex` 在非 Claude HOME 不再依賴 `.claude` asset/memory tree；Claude executor parity 保持；focused gate、reviewer、memory regression 與 full suite通過。

**Outcome**: `pr-gate` 預設從 product-owned `agents/` 解析 reviewer definitions；reviewed-workspace definitions 固定讀 trusted base revision，外部 trusted definitions 在 snapshot 前後驗證 identity。Gate 透過 shared runtime 取得 canonical memory provenance/context，invalid explicit selection 與 resolver/query failure 均 fail closed。Regression 由真實 `pmctl gate run --executor codex` 入口在隔離非 Claude HOME 驗證 production resolver、reviewer snapshot 與零 `.claude` side effect；Claude executor parity 與 full suite維持通過（PR #422）。

**Dependencies**: canonical memory基底由 [[CC-483]]/[[CC-490]] 提供；final candidate須先於 [[CC-501]]。P1，v0.9.0 release blocker。
**See**: pr:#422
