<!-- pm-dispatch: backlog-archive 2026-05-31 -->
# pm-dispatch backlog — archive

Terminal (`✅ closed` / `🚫 dropped`) tickets archived from BACKLOG.md — both the
index row and the body section (pm/schema.md §4 working-set model; CC-049, CC-279/280).
BACKLOG.md keeps only non-terminal entries; no closed row or in-place stub remains there.
Last archived: 2026-05-31

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

**Closed**: M4 的最後一票。原票（2026-05-18）要求「把 runtime 邏輯移入 `scripts/pm-dispatch-runner.sh`」的前提已過時：M0–M3 的抽取（CC-200 executor-router、CC-202 handover-validate、CC-289 dispatch run…）早已把 brief/handover/dispatch 邏輯搬進 `scripts/lib/`，`commands/pm.md` 現在只剩 65 行（意圖 + 行為約束 + 腳本指標）。pm.md 殘留的步驟 1–10 是**主執行緒 tool-call 編排**（`Agent` spawn、`BashOutput` 讀取、exit-124 retry），本質上塞不進 shell，因此不寫 `pm-dispatch-runner.sh`。真正的殘留（approach B「複用抽取」）是步驟 4–8 的 post-verify 驗證程序仍以散文重複，而 `scripts/dispatch-post-verify.sh`（CC-264b）已實作同邏輯且有測試。交付：(1) 把 `dispatch-post-verify.sh` 參數化吃 `--last/--stderr/--brief-file`（footer 給的 per-run 路徑，race-safe；省略時 fallback `latest.*`，保住 `pmctl dispatch run` + codex-executor 既有呼叫者）+ 對 flag 路徑套用既有 `.agent-trace` 圍堵 guard；(2) `commands/pm.md` 驗證主體塌縮成單一 `dispatch-post-verify.sh` 呼叫；JSONL `command_execution` 證據交叉檢查（證明每個 `self_verify:` 真的有跑,vs 腳本的 final-message `cmd: pass` 宣稱）**保留**為主執行緒步驟（executor-agnostic 腳本無法做）；(3) flag parser 對 value-taking flag 加 missing/flag-shaped value 防呆（`--last --stderr X` 報 usage 而非後段 not-found）；`test-dispatch-post-verify.sh` +11 cases（override OK、圍堵拒絕、fallback、--brief-file、ambiguous、unknown flag、missing-value、flag-as-value），21→32 全綠。Merged via PR #204。

**Problem**: `commands/pm.md` 包含 brief file 建立、handover validation、Codex dispatch、background mode、BashOutput tracking、stderr parsing、git diff verify、exit 124 retry 等大量流程邏輯。markdown command 逐漸變成「半程式碼、半 prompt、半 policy」的混合體。
**Why**: 當 Codex CLI、Claude Code hooks 或 scripts 行為改變時，markdown command 很容易與實際腳本 drift。script 有測試；markdown 沒有。
**Requirement**: 識別 pm.md 中可搬到 shell script 的 runtime 步驟（特別是 handover extraction + validation + dispatch 命令組裝）；移入 `scripts/pm-dispatch-runner.sh`（或直接加強 `scripts/lib/`）；pm.md 只保留「什麼情境呼叫什麼腳本」的意圖描述與 trigger 條件。依賴 CC-200（executor-router.sh）。

