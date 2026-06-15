<!-- pm-dispatch: backlog-archive 2026-06-15 -->
# pm-dispatch backlog — archive

Terminal (`✅ done` / `✅ closed` / `🟢 superseded` / `🚫 dropped`) tickets archived from
BACKLOG.md — both the index row and the body section (pm/schema.md §2.3 terminal set + §4
working-set model; CC-049, CC-279/280, CC-378).
BACKLOG.md keeps only non-terminal entries; no closed row or in-place stub remains there.
Last archived: 2026-06-15

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

