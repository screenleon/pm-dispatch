<!-- pm-dispatch: backlog-archive 2026-05-18 -->
# pm-dispatch backlog — archive

Closed ticket detail sections archived from BACKLOG.md (CC-049).
Index entries with ✅ status and PR refs remain in BACKLOG.md for scanning.
Last archived: 2026-05-18

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
