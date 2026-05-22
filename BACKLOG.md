<!-- pm-schema: v1.2 -->
# pm-dispatch backlog

<!--
ID PREFIX: CC
CC-001/CC-002 were consumed by PR #24 fix bundle inline, with no standalone entries; this file starts at CC-003.
-->

## Index

| #  | Status | 主題 | 影響面 | 首次記錄 | Refs | Priority | Epic |
|----|--------|------|--------|----------|------|----------|------|
| CC-003 | 🔵 active | parallel-gate artifact-ignore 前置檢查 | ops/arch | 2026-05-12 | pr:#38 | P3 | — |
| CC-004 | 🔵 active | test-pr-gate.sh docstring 格式統一 | ops | 2026-05-12 | pr:#38 | P3 | — |
| CC-005 | ✅ closed 2026-05-18 | install.sh preflight 改為 opt-in via `--verify` | ops | 2026-05-12 | pr:#85 | — | — |
| CC-006 | ✅ closed 2026-05-13 | statusLine hook 自動寫入 rate-limits，`--remaining` 免手動輸入 | ux | 2026-05-13 | pr:#42 | — | — |
| CC-007 | ✅ closed 2026-05-13 | brief qa_checklist 指引寫入 docs/codex-brief.md + agents/project-pm.md | process | 2026-05-13 | pr:#42 | — | — |
| CC-008 | ✅ closed 2026-05-13 | Spark routing 判斷標準寫入 agents/project-pm.md | arch | 2026-05-13 | pr:#41 | — | — |
| CC-009 | ✅ closed 2026-05-14 | UserPromptSubmit hook 自動 inject MEMORY.md 防止 auto-compact 遺忘 | ux/memory | 2026-05-14 | pr:#44 | — | — |
| CC-010 | ✅ closed 2026-05-14 | `/memory-compress` 指令：壓縮 MEMORY.md 條目減少 inject token 量 | ux/memory | 2026-05-14 | pr:#45 | — | — |
| CC-011 | 🟢 someday | sync-memory.sh + install 選項：symlink memory 到雲端資料夾實現跨裝置共用 | ux/memory | 2026-05-14 | — | — | — |
| CC-012 | 🟢 someday | SessionStart hook：session 啟動時 pull 最新 memory（git/rsync）確保跨裝置同步 | ux/memory | 2026-05-14 | — | — | — |
| CC-013 | ✅ closed 2026-05-18 | `/caveman` token 壓縮 skill：lite/full/ultra 模式，長 session 降低 token 消耗 | ux | 2026-05-14 | pr:#82 | — | — |
| CC-014 | 🟡 deferred | `using-git-worktrees` skill：parallel PR gate 隔離開發環境 | arch | 2026-05-14 | — | — | — |
| CC-015 | 🟡 deferred | `systematic-debugging` skill：結構化偵錯工作流 | ux | 2026-05-14 | — | — | — |
| CC-016 | ✅ closed 2026-05-14 | gate NO-GO fix-loop 效率：PM brief 撰寫策略（discovery + --targeted + source-first） | process | 2026-05-14 | pr:#43 | — | — |
| CC-017 | ✅ closed 2026-05-14 | 前端 UI 實作前置流程：提供圖片時需先讀取確認再 brief | process/ux | 2026-05-14 | pr:#43 | — | — |
| CC-018 | 🔵 active | Codex quota 自動追蹤：codex-dispatch 後查詢剩餘 quota 寫入 rate-limits-codex.json | ux/token | 2026-05-14 | — | P3 | — |
| CC-019 | ✅ closed 2026-05-14 | Episodic memory 層：Stop hook metadata + `/mem-log` + `/mem-recall` + `/mem-distill` | ux/memory | 2026-05-14 | pr:#45 | — | — |
| CC-020 | ✅ closed 2026-05-14 | `/mem-search`：`rg` 關鍵字過濾 + Claude 語意理解，跨 memory 檔搜尋 | ux/memory | 2026-05-14 | pr:#45 | — | — |
| CC-021 | ✅ closed 2026-05-14 | test scripts 支援 `--filter <pattern>` + `--list` 只跑/列出名稱匹配的 test case | ops/test | 2026-05-14 | pr:#45 | — | — |
| CC-022 | ✅ closed 2026-05-14 | `/pre-impl` 指令：開發前設計評審，強制定義邊界/依賴/變動點，減少事後重構 | ux/arch | 2026-05-14 | pr:#46 | — | — |
| CC-023 | ⏸ deferred | `coupling-reviewer`：PR gate 加入語言感知耦合分析（dependency-cruiser/gocyclo/coca） | ops/gate | 2026-05-14 | — | — | — |
| CC-024 | ✅ closed 2026-05-15 | `test-usage-weekly.sh` 加入 GitHub Actions CI（lint.yml 新增 job） | ops/test | 2026-05-14 | pr:#57 | — | — |
| CC-025 | ✅ closed 2026-05-18 | `/skill-refine`：讀 skill 執行 episodes + 後續更正訊號，提 diff 自我精修 | ux/memory | 2026-05-15 | pr:#67,pr:#68 | — | — |
| CC-025b | ✅ closed 2026-05-18 | `/skill-refine` M1+M2 advisory follow-ups：M1 usage-guard tests + `CLAUDE_MEMORY_DIR` 環境契約文件化/repo-default fallback | ux/memory/test | 2026-05-17 | pr:#83 | — | oss |
| CC-026 | 🔵 active | `/skill-distill`：偵測重複工作流，產出草稿 skill .md | ux/memory | 2026-05-15 | — | P3 | — |
| CC-027 | ✅ closed 2026-05-15 | PreToolUse `hook-tool-trace.sh`：tool/skill 觸發落 tool-trace.jsonl（CC-025/CC-026 前置） | ux/memory | 2026-05-15 | pr:#54 | — | — |
| CC-027b | 🟡 deferred | `tool-trace.jsonl` health signal：bounded error counter + downstream warning | ux/memory | 2026-05-15 | — | — | — |
| CC-027c | 🟡 deferred | `hook-tool-trace.sh` strict JSON validation：jq inline cost ~25ms/call 超 budget；探索 async post-validation 或 sampled fraction | ux/memory | 2026-05-15 | — | — | — |
| CC-028 | ✅ closed 2026-05-15 | PostToolUse `hook-routing-log.sh`：codex-dispatch 自動 append routing_log 記錄 Q1/Q2/Q3 校準資料 | ux/memory | 2026-05-15 | pr:#55 | — | — |
| CC-029 | ✅ closed 2026-05-15 | `test-codex-dispatch.sh` 加入 CI（與 CC-024 並行做 lint.yml 補完） | ops/test | 2026-05-15 | pr:#57 | — | — |
| CC-030 | ✅ closed 2026-05-19 | `pm/scripts/validate.sh` 補 Index ↔ Section 雙向一致性 + CHANGELOG drift 檢查 | ops/process | 2026-05-15 | decisions:#2026-05-19-cc030-validate-bidirectional | P1 | — |
| CC-031 | ✅ closed 2026-05-19 | 開源前置：`CONTRIBUTING.md` + `SECURITY.md` + README 工作語言聲明 | process/DX | 2026-05-15 | pr:#102 | P2 | — |
| CC-032 | 🔵 active | `[[feedback_*]]` cross-link 公開化：抽到 `docs/policies/` glossary 避免 dead link | process/DX | 2026-05-15 | — | P3 | — |
| CC-033 | 🔵 active | Public flip checklist：Issues/Discussions 設定、CITATION.cff（選配）、後續觀察期 | process | 2026-05-15 | — | P3 | — |
| CC-034 | ✅ closed 2026-05-15 | `install-hooks.sh` 改名/移動 checkout 後 append-not-replace bug：以 hook script basename 取代 full-path 比對 | ops | 2026-05-15 | pr:#53 | — | — |
| CC-035 | 🔵 active | install/uninstall-hooks basename+scripts/ heuristic：未覆蓋另一工具也在 scripts/ 下同名 hook 的 collision edge case | ops | 2026-05-15 | pr:#53 | P3 | — |
| CC-036 | ✅ closed 2026-05-18 | `/pm` dispatch async ergonomics restore：classify+brief 仍走 subagent；execute 改 main-thread `Bash(codex-dispatch.sh, run_in_background:true)` 直派；恢復 dispatch + 完成通知並行 | ux/process | 2026-05-15 | pr:#58 | — | — |
| CC-037 | ✅ closed 2026-05-18 | `hook-routing-log.sh` concurrent append race：並行 PostToolUse 可能 silent-drop routing row | ux/memory | 2026-05-15 | pr:#56 | — | — |
| CC-038 | ⏸ deferred | Windows / cross-platform 鎖機制：`flock` Linux-only，未來支援 Windows/macOS 需替代方案 | ops/portability | 2026-05-15 | — | — | — |
| CC-039 | ✅ closed 2026-05-18 | shared-schema brief enrichment + `/pre-impl` Q4 repo-rule audit + 每輪 fix brief next-layer sweep（JS-110、CC-013 兩次 7 輪 gate 後驗證） | process | 2026-05-15 | pr:#83 | — | — |
| CC-036b | ✅ closed 2026-05-16 | dispatch handover authorized-override reconciliation：spec 允許 caller-authorized `skip_git_check:true` / `sandbox:danger-full-access` / `approval:on-request`，但 validator 預設 hard-reject 無 override channel；docs/commands example 也需 default-safe 化 | arch/process | 2026-05-16 | pr:#59 | — | oss |
| CC-040 | ✅ closed 2026-05-16 | agent-agnostic dispatch schema rename：`docs/codex-brief.md` → `docs/dispatch-brief.md` + `codex_dispatch_handover_v1` → `dispatch_handover_v1` + `executor:` 欄位（為未來非 codex executor 預留） | arch/process | 2026-05-15 | pr:#66 | — | — |
| CC-044 | ⏸ deferred | `tool-trace.jsonl` rotation/retention policy（max sessions vs bytes vs archive） | ux/memory | 2026-05-15 | — | — | — |
| CC-045 | ⏸ deferred | brief timeout heuristic：依 target repo playbook depth 設 timeout，不能只看 edit size；brief context 可加「skip playbook re-read」短路指令；codex-dispatch.sh 可選 warn 當 repo 有 `rules/`/`AGENTS.md` 且 timeout < 900s | process/DX | 2026-05-16 | — | — | — |
| CC-046 | ✅ closed 2026-05-19 | validate.sh + run-tests.sh dedup：(a) 第二個 awk pass (changelog drift) 重複解析 backlog index status / refs，shared parsing 抽出；(b) `run_validate_case_multi` 與 `run_validate_case` assertion body 高度重複，改 varargs 單一 helper | ops/test | 2026-05-16 | decisions:#cc046-validate-dedup | P2 | — |
| CC-047 | ✅ closed 2026-05-17 | `scripts/codex-dispatch.sh` model alias mapping：`--model codex-spark` 透傳給 codex CLI 後得到 400 invalid_request_error（API 只認 `gpt-5.3-codex-spark`），需要 alias 表把短名映射到 codex CLI 接受的全名 + reasoning effort | ops/dispatch | 2026-05-17 | pr:#69 | — | — |
| CC-100 | ✅ closed 2026-05-17 | **[CC-OSS Phase 1]** Sanitize personal paths + OSS-baseline docs：拔 `/home/<user>` 硬編碼 → `${PM_DISPATCH_REPO}` env contract；新增 `CONTRIBUTING.md` + `CODE_OF_CONDUCT.md`；LICENSE 已存在 | process/docs | 2026-05-17 | pr:#71 | — | oss |
| CC-101 | ✅ closed 2026-05-17 | **[CC-OSS Phase 2 spike]** Executor-contract schema + adapter design：brief schema 加 `executor:` 欄位；`docs/executor-contract.md`；CC-040 schema rename 延伸 | arch/process | 2026-05-17 | pr:#72 | — | oss |
| CC-102 | ✅ closed 2026-05-17 | **[CC-OSS Phase 2 impl]** `claude-executor` agent + `install.sh --profile minimal\|full`：minimal profile 跳過 codex hooks，預設 executor=claude；既有 codex flow 全 regression pass | arch/install | 2026-05-17 | pr:#73 | — | oss |
| CC-102b | ✅ closed 2026-05-17 | CC-102 PR-gate advisory follow-ups：(a) 直接 e2e regression test 覆蓋 `install.sh --profile minimal\|full` + auto-detect；(b) install-hooks.sh minimal profile downgrade — fold-in 進 CC-102 同 PR（qa-tester r2 升 block；都已修） | ops/install | 2026-05-17 | pr:#73 | — | oss |
| CC-103 | ✅ closed 2026-05-17 | **[CC-OSS Phase 3]** `scripts/lib/portable.sh` shim（`realpath_m` / `safe_tmpdir` / `mkdir_lock` / `file_size_bytes`）+ `docs/platform-support.md`；改寫 3 個 hook 用 shim；`install-hooks.sh` 偵測 platform 跳過 Linux-only hook | ops/portable | 2026-05-17 | pr:#74 | — | oss |
| CC-103b | ✅ closed 2026-05-17 | CC-103 follow-up: `/pr-gate` executor split — `--executor codex\|claude\|auto`; mirror CC-102 `/pm` route split so minimal-profile users can run the gate | arch/install | 2026-05-17 | pr:#75 | — | oss |
| CC-104 | ✅ closed 2026-05-17 | **[CC-OSS Phase 4]** Onboarding docs batch：README intro rewrite + `docs/GETTING_STARTED.md` + `docs/memory-system.md` + 7 個 `commands/*.md` 補 what/when/example 三段（pm.md / pr-gate.md 已含 Route A/B 故跳過） | docs/ux | 2026-05-17 | pr:#76 | — | oss |
| CC-105 | ✅ closed 2026-05-17 | **[CC-OSS Phase 5]** v0.1.0 release：`CHANGELOG.md` [0.1.0] section + BACKLOG status flip + private→public visibility + tag v0.1.0 + GitHub release + main branch protection（require linear history） | process/release | 2026-05-17 | pr:#77 | — | oss |
| CC-104b | ✅ closed 2026-05-17 | **[Windows dogfood r1 fixes]** install-hooks jq error → platform-aware install hints | ops/install | 2026-05-17 | pr:#79 | P2 | oss |
| CC-104c | ✅ closed 2026-05-17 | **[Windows dogfood r1 fixes]** install.sh `link()` → `link_or_copy()`: try `ln -s` + `[[ -L ]]` post-check (catches Git Bash silent-copy disguise); fall back to `cp -p` + warn-to-stderr; manifest at `~/.claude/.pm-dispatch/install-manifest.json` (manifest_version=1, atomic mktemp+mv write); sha256 idempotency for copy-mode entries; FAKE_SYMLINK_UNSUPPORTED / FAKE_SYMLINK_BOGUS test shims. OUT: `--update` (CC-104d), `--uninstall` (CC-104e), mkdir_lock (CC-104k), Experimental→Supported doc flip (separate doc PR after CC-104c + CC-104k both merge) | arch/install | 2026-05-18 | pr:#89 | — | oss |
| CC-104d | 🟡 deferred | **[Windows dogfood r1 findings]** Hardcoded `$HOME/github` read root default in `hook-codex-bash-guard.sh:54`; `CLAUDE_HOOK_CODEX_READ_ROOTS` env override exists but default is wrong on Windows where repos live under `~/Documents/github/` or arbitrary paths. Should be derived from `PM_DISPATCH_REPO` parent or removed | ops/hook | 2026-05-17 | — | — | oss |
| CC-104e | 🟡 deferred | **[Windows dogfood r1 findings]** WSL ↔ Windows `~/.claude/projects/<project-id>/memory/` divergence: project ID is path-sanitization of working dir. Same repo cloned at `~/github/pm-dispatch` (WSL) and `C:\Users\<user>\Documents\github\pm-dispatch` (Windows) produces different IDs → memory partitioned. Harness-level (Claude Code) issue; document workaround (symlink, or PM_DISPATCH_PROJECT_ID override) | ux/memory | 2026-05-17 | — | — | oss |
| CC-104f | 🟡 deferred | **[Windows dogfood r1 findings]** jq is hard-dep for hooks layer. Options: vendor static `gojq` binary (3 MB × 3 platforms), or expose `--no-hooks` install mode that skips hook wiring entirely (lightweight install for jq-less users). Latter preferred — keeps "no auto-install of system pkgs" principle | arch/dep | 2026-05-17 | — | — | oss |
| CC-104g | ⚠️ partial 2026-05-17 | **[Windows dogfood r1 fixes]** portable.sh test fixes: symlink test SKIP + detect_platform host_native PASS on Windows ✅; mkdir_lock FIFO sync ✅ but underlying `mkdir` on Git Bash still allows second concurrent acquire — real Windows portability bug, NOT test sync issue. See CC-104k | ops/test | 2026-05-17 | pr:#80 | — | oss |
| CC-104h | ✅ closed 2026-05-17 | **[Windows dogfood r1 fixes]** `handover-validate.sh` brief_file validator now accepts paths under `/tmp` + `$TMPDIR / $TEMP / $TMP` (POSIX or MSYS forward-slash form). Windows backslash paths still rejected at metadata-metachar level — documented limitation | ops/validator | 2026-05-17 | pr:#80 | — | oss |
| CC-104i | ✅ closed 2026-05-17 | **[Windows dogfood r1 fixes]** `.gitattributes` forces LF — verified `file install.sh ... portable.sh` no CRLF after checkout on Windows | ops/repo | 2026-05-17 | pr:#80 | — | oss |
| CC-104j | 🟡 deferred | **[Windows dogfood r1 r2 finding]** `test-dispatch-handover.sh:674-685` `brief_file_symlink_rejects_case` uses `ln -s` for fixture setup; on Git Bash falls back to copy → validator treats as regular file → test fails. Same skip-if-not-symlink pattern as CC-104g case (a) — `[[ -L "$link" ]]` precondition → SKIP | ops/test | 2026-05-17 | — | — | oss |
| CC-104k | 🟡 deferred | **[UNC/9P filesystem caveat — re-scoped from `mkdir_lock` atomicity claim]** Race test on Windows Git Bash 5.2.15 (Windows 11) confirmed `mkdir` IS atomic on **local NTFS** (`C:\...\Temp` — Git Bash's `/tmp`); 20/20 rounds × 50 parallel = exactly 1 winner each. Original CC-037 regression failure on Windows was specifically when running pm-dispatch from `\\\\wsl.localhost\\Ubuntu\\...` (9P UNC bridging WSL FS to Windows) — 9P protocol or its Windows client does not preserve mkdir atomicity. Not a code bug; install-on-local-disk caveat. See **CC-104r** for the install-time UNC path detect / docs warn follow-up. If a third filesystem ever surfaces `mkdir`-non-atomic, revisit with `set -C` + `: > file` primitive (already race-tested as atomic on tested FS) | filesystem/caveat | 2026-05-18 | — | — | oss |
| CC-104l | ✅ closed 2026-05-21 | **[Windows dogfood r1 r2 finding]** jq install hint visibility: install-hooks.sh shows the platform-aware hint per CC-104b (#79), BUT install.sh preflight runs `test-hooks` FIRST which fails with bare "jq missing" repeated 200+ times before hitting install-hooks.sh. Add (a) jq prerequisite check at top of install.sh BEFORE preflight (one-line hint), (b) jq install command at top of README "Install" section so first-time readers see it before clicking through to platform-support.md | ops/install | 2026-05-17 | pr:#116 | — | oss |
| CC-104m | 🟡 deferred | **[Platform layout — post-v0.1.0]** pm-dispatch staging dir + multi-target projection: introduce `~/.pm-dispatch/content/` as canonical view, then symlink-project to `~/.claude/` and (future) `~/.codex/` etc. Today pm-dispatch is Claude-only by virtue of where install.sh lands; this re-shapes it as a tool-agnostic content platform. Touches install.sh, manifest schema (v0 → v1 with `target` field), uninstall semantics. Decided 2026-05-18 (CC-104c scope discussion, Path Y). Open until clear Codex/Cursor/Aider integration need surfaces | arch/install | 2026-05-18 | — | — | oss |
| CC-104n | ✅ closed 2026-05-19 | **[CC-104c risk-reviewer advise]** install.sh preflight hard-fail (`--verify` block) converts optional/local validation issues into full install blockers; transient or environment-specific tooling gaps (e.g. missing optional bin) abort entire install. Pre-existing behavior surfaced by CC-104c gate. Mitigation: gate non-essential preflight checks behind a best-effort path OR add explicit `--skip-preflight=<name>` opt-out switch. **Design direction**: extract `scripts/run-all-tests.sh` as standalone test aggregator (make-check / make-install boundary); install.sh `--verify` becomes a thin wrapper around it; folds CC-104q | ops/install | 2026-05-18 | pr:#101 | P2 | oss |
| CC-104o | 🟢 superseded 2026-05-20 | **[Windows dogfood r3 finding]** Microsoft Store python3 reparse-point stub (`/c/Users/<user>/AppData/Local/Microsoft/WindowsApps/python3.exe`) returns exit 49 in non-interactive contexts → 36 preflight cases FAIL (every `inject-hook/*`, `session-hook/*`, `rl-hook/*`, `stop_*`, `mem-recall/format-validator`, `cross-cmd/*` because hook scripts internally call python3). Fix: install.sh / install-hooks.sh preflight detects the MS Store stub via `python3 -c 'pass'` exit-49 probe, hard-fail with platform-aware hint (`winget install Python.Python.3.12` + "remove WindowsApps stub from PATH or order real Python first"). Required before Windows = Supported flag flip — fork users on Windows hit this on first install. Superseded by CC-104t which eliminates python3 entirely via jq rewrite. | ops | 2026-05-18 | — | — | oss |
| CC-104p | ✅ closed 2026-05-21 | **[Windows dogfood r3 finding]** `flock` is Linux-only — Git Bash has no flock binary; `hook-routing-log.sh` directly calls flock (bypassing portable.sh abstraction) → 2 cases FAIL on Windows (`routing: rotation failure audits and skips append`, `routing: concurrent appends keep every row`). Strong dependency on **CC-104k** (mkdir_lock Git Bash atomicity) — fix should be one combined PR: (a) fix mkdir_lock atomicity per CC-104k, (b) add `scripts/lib/portable.sh::serialize_with_lock <path> <cmd>` shim that prefers `flock` when present else falls back to `mkdir_lock`, (c) rewrite hook-routing-log.sh to use shim. **Blocker** because CC-036's main-thread background dispatch makes concurrent routing-log appends real (no longer theoretical) → Windows row-loss = silent data corruption | arch/portable | 2026-05-18 | pr:TBD | — | oss |
| CC-104q | ✅ closed 2026-05-19 | **[Windows dogfood r3 finding]** test-hooks preflight runs codex-dispatch cases (`cxw: Write to existing symlink /tmp/brief-*.md → deny`, `dispatch_brief_file_reads_file`) even when codex is not on PATH → 2 cases FAIL with `codex: command not found`. `install.sh --profile minimal` skips codex hooks but preflight still tests them. Fix: test-hooks should SKIP (not FAIL) codex-* cases when `command -v codex` is false. Folds well with **CC-104n** preflight `--skip-preflight=<name>` mechanism — could land in same PR | ops/test/ux | 2026-05-18 | — | — | oss |
| CC-104r | ⏸ deferred | **[Windows dogfood r3 finding]** `hook-tool-trace.sh` performance_budget assertion: 27990 ms actual vs 3500 ms budget on Windows native filesystem (WSL UNC path `\\wsl.localhost\...` is ~8× slower than local disk). Not a pm-dispatch bug — physical filesystem characteristic. Fix is two-part: (a) `docs/platform-support.md` warns "install on local disk, avoid cross-WSL/native FS boundaries"; (b) preflight detects UNC path → prints warning and skips budget assertion (10 lines). Polish, not blocker | docs/ops | 2026-05-18 | — | — | oss |
| CC-104s | 🟡 deferred | **[Windows dogfood r3 finding]** `hook-tool-trace.sh:195` `read_home_path_basename_only` returns `first_arg_or_skill:null` on Windows because case-glob `"$HOME"/*` uses forward slashes (`/c/Users/Lien Chen`) but harness sends `file_path` with backslashes (`C:\Users\Lien Chen\...`); both case branches miss. Fix: normalize input path via `cygpath`/string-replace (`\\` → `/`, `C:\Users\...` → `/c/Users/...`) before case-match. Polish — affects trace JSON observability only, not functionality | ops/trace/portability | 2026-05-18 | — | — | oss |
| CC-104t | ✅ closed 2026-05-20 | **[python→jq replacement — supersedes CC-104o]** Hook scripts call `python3` in 4 places (`hook-log-claude-usage.sh` 2 heredocs; `hook-inject-memory.sh`, `hook-session-summary.sh`, `hook-save-rate-limits.sh` 1 each) for JSON/JSONL parsing + simple date arithmetic. Rewrite to use jq (already a required dep) + bash filesystem walking, eliminating python3 entirely. Pros: (a) closes 36 Windows hook FAILs caused by Microsoft Store python3 reparse-point stub (root cause, not workaround), (b) shrinks install footprint to jq-only, (c) consistent with CC-104b jq-as-canonical-dep direction, (d) no Claude Code session-restart required when PATH changes. Cons: ~250 LoC refactor across 4 hooks; date arithmetic via `jq fromdateiso8601` (1.6+) or `date -d` shim. **Required ≥4 behavioral units → `/pre-impl` mandatory.** Once landed, mark CC-104o `🟢 superseded by CC-104t` | arch/hook/portability | 2026-05-18 | pr:#107 | P2 | oss |
| CC-104u | ✅ closed 2026-05-19 | **[Windows dogfood r4 finding]** `install.sh` `link()` semantics bug on existing-directory dst: when `dst` is already a directory (e.g. `~/.claude/.pm` is a real dir from a prior install or manual setup), `ln -s "$src" "$dst"` is interpreted as "create link inside the dir named $(basename "$src")" → produces `dst/basename(src)` (e.g. `.pm/pm`) instead of failing cleanly. CC-104c's link_or_copy inherits this from `ln`. Observed: `ln: failed to create symbolic link '/c/Users/Lien Chen/.claude/.pm/pm': File exists`. Copy fallback masked the symptom but `manifest` records a wrong dst. Fix: `link_or_copy` should `[[ -d "$dst" && ! -L "$dst" ]]` precheck → return CONFLICT (rc=2) with clear message, OR use `ln -sn` (no-dereference) consistently. Also audit `pm-schema` install block path-handling | ops/install | 2026-05-18 | pr:#100 | P2 | oss |
| CC-104v | ✅ closed 2026-05-21 | **[Windows dogfood r4 — docs]** Document copy-mode install snapshot semantics: when `link_or_copy` falls back to copy (Git Bash without dev-mode), changes to source repo do NOT propagate to install dst — user must re-run `install.sh` after any source edit. Currently surfaced only via per-file `portable: fallback copy path ... symlink post-check failed` stderr. Add a single summary banner at end of install when copy-mode entries > 0 (`N files installed via copy fallback; source edits will require re-install`). Also add section to `docs/platform-support.md` Windows page. UX, not correctness | docs/install/ux | 2026-05-18 | pr:#116 | — | oss |
| CC-200 | ⏸ deferred | **[Reuse debt]** `scripts/lib/executor-router.sh` — 抽出共用 codex/claude routing logic（目前 `/pm`、`/pr-gate` 各寫一套，未來 N=3 consumer 痛點） | arch/reuse | 2026-05-17 | — | — | reuse-debt |
| CC-201 | ⏸ deferred | **[Reuse debt]** `detect_executor_profile()` shim 進 `scripts/lib/portable.sh` — `install-hooks.sh` + `pr-gate.sh` 各自重複 `command -v codex` 判斷 | arch/reuse | 2026-05-17 | — | — | reuse-debt |
| CC-202 | ⏸ deferred | **[Reuse debt]** handover validator framework — `dispatch_handover_v1` 與 `pr-gate-handover_v1` 共用 fence/metadata/body validator 抽象；future handover schemas 不再手刻 | arch/reuse | 2026-05-17 | — | — | reuse-debt |
| CC-203 | ⏸ deferred | **[Reuse debt]** `scripts/lib/test-harness.sh` — 8+ 個 `test-*.sh` 都各寫 `--filter/--list`/`should_run()`/PASS-FAIL counter/scratch dir setup；source-able 共用 lib 統一 | ops/test/reuse | 2026-05-17 | — | — | reuse-debt |
| CC-204 | ⏸ deferred | **[Reuse debt]** hook framework — pm-write-guard/codex-bash-guard/codex-write-guard/routing-log 共通 stdin-json-parse → decision-matrix → audit-log 結構；目前 copy-paste-modify | arch/hook/reuse | 2026-05-17 | — | — | reuse-debt |
| CC-205 | ⏸ deferred | `/pm` dual-executor planning: `--executor auto/codex/claude` flag（與 pr-gate 介面對齊）+ `dispatch_handover_v1` 加 `executor` 欄位；加 `--parallel-plan` mode — PM 偵測 arch/multi-subsystem/first-design 特徵時，在 dispatch 前暫停並詢問用戶是否啟用；確認後 codex 與 claude 各自獨立規劃，current model 合成一份 best-of 計劃輸出；`/pm --parallel-plan` flag 可跳過確認步驟直接 parallel dispatch | process | 2026-05-20 | — | P2 | design |
| CC-206 | ⏸ deferred | gate lifecycle hook：`.pm-dispatch/pre-gate.sh` / `.pm-dispatch/post-gate.sh` — 主線程在 dispatch 前後執行 repo-level 腳本（Docker 啟動、DB seed 等 Codex sandbox 無法執行的 infra 操作）；hook 不存在時 gate 行為不變 | ops/gate | 2026-05-20 | — | P2 | design |
| CC-207 | 🟡 deferred | **[Windows dogfood r3 finding]** `install.sh` on Git Bash (OSTYPE=msys/cygwin) falls back to copying files instead of symlinking (`ln -s` does not work); 83 files copied across agents/, commands/, scripts/, .pm — after pm-dispatch updates users must re-run `bash install.sh` to sync. Fix: detect Git Bash, use PowerShell `mklink /J` (directory junction, no admin required) for each target. | ops/portability | 2026-05-20 | — | P2 | oss |
| CC-208 | 🔵 active | **[Gate reviewer hallucination]** Gate reviewers cite non-existent docs in findings — observed: "AGENT.md §3" (does not exist). Reviewers invent plausible-sounding citations because they don't receive the real file list. Fix: (a) inject verified file index into gate brief preamble, or (b) add "do not cite unconfirmed docs" constraint to each reviewer agent definition. Recurs on ~30% of gate runs; each occurrence adds ~1–2 min manual verification overhead. | ops/process | 2026-05-20 | — | P3 | — |
| CC-209 | ⏸ deferred | **[context-enrichment spike: codegraph evaluation]** Evaluate colbymchenry/codegraph (MIT, TypeScript) as the first **context-pack** source (CC-232) — not a direct codex-dispatch integration. Investigation: install model, query API, whether output maps to context-pack v1, token/accuracy delta vs the rg/git baseline (CC-237). Runs as the first formal `/spike` in v0.3.0 M5; output is docs/spikes/CC-209.md with an adopt/defer/reject recommendation. | ops/token | 2026-05-21 | — | P3 | spike |
| CC-210 | ⏸ deferred | **[uninstall blast-radius guard]** `uninstall.sh` currently allows `$HOME/.claude` itself to pass the managed-root safety guard (dst must start with managed root); a malformed or tampered copy-mode manifest entry matching the directory hash could remove the entire Claude config tree. Fix: add an explicit `[[ "$dst" == "$managed_root" ]]` rejection check before the startswith guard, so only strict descendants of the managed root are deletable. Raised by risk-reviewer in PR #110 gate as [medium] advisory. | ops | 2026-05-21 | pr:#110 | P3 | hygiene |
| CC-211 | ⏸ deferred | **[v0.3.0 architecture epic]** Restructure pm-dispatch into a schema-first / state-first / adapter-thin PM runtime — four layers: `core/` (data + policy) → `runtime/` (`pmctl` spine) → `adapters/` (delivery) → `mcp/` (bridge, v0.4.0). Absorbs Multica / Memori / Superpowers / AI Night Shift concepts into one state substrate. Broken into milestones M0–M5 — see docs/architecture/v0.3.0-synthesis.md and MILESTONES.md v0.3.0. Umbrella epic for CC-229..CC-237 + existing CC-059/060/061/200-204/215/217-220. | arch/portability | 2026-05-21 | — | P1 | design |
| CC-215 | ⏸ deferred | **[pmctl — core CLI entrypoint]** Implement `cli/pmctl` as the language-agnostic runtime for pm-dispatch. Interface: `pmctl task create/claim/dispatch/status/review`, `pmctl decision add`, `pmctl backlog sync`, `pmctl trace tail`, `pmctl guard check --event <pre-write\|pre-bash\|post-task> --file/--command <val>`, `pmctl adapter generate <claude\|codex\|gemini\|opencode>`. AI CLI adapters become thin wrappers: Claude `/pm task-123` → `pmctl task dispatch task-123 --agent claude`; Codex equivalent calls the same binary. Guard logic moves from Claude-only hooks into pmctl so any CLI without hook support can call `pmctl guard check` from a command wrapper or `pmctl safe-bash "cmd"`. Adapter generator (`pmctl adapter generate`) produces per-CLI config from core agent definitions — prevents 4-way drift. Depends on CC-211. | arch/portability | 2026-05-21 | — | — | design |
| CC-216 | ⏸ deferred | **[MCP server — pm-dispatch-server]** **Deferred to v0.4.0** — v0.3.0 ships only `mcp/README.md` (the intended tool surface, as a `pmctl` interface design constraint); the server is built once `pmctl` is stable. Implement `mcp/pm-dispatch-server` exposing pm-dispatch operations as MCP tools: pm_list_tasks, pm_read_task, pm_create_task, pm_update_status, pm_add_decision, pm_request_review, pm_dispatch_to_agent, pm_read_trace, pm_guard_check. Enables Claude Code, OpenCode, Gemini CLI, and any future MCP-capable AI tool to share one PM system without per-tool command wiring. MCP becomes the universal bridge; adapters handle only auth / config / format differences. Implementation path: thin Node.js or Python wrapper over pmctl subprocesses (avoids duplicating logic), or native bash MCP server once spec stabilises. Depends on CC-211, CC-215 (pmctl stable before wrapping). | arch/portability | 2026-05-21 | — | — | design |
| CC-217 | ⏸ deferred | **[claude-executor background dispatch]** `Agent(subagent_type:claude-executor)` calls in `/pm` Route B and `/pr-gate` Route B currently block the main thread (missing `run_in_background:true`), inconsistent with the codex-executor pattern. Fix: add `run_in_background:true` to all claude-executor dispatch sites in commands and gate scripts; update completion handling to receive the async notification rather than blocking inline. | DX/gate | 2026-05-21 | — | P2 | oss |
| CC-218 | ⏸ deferred | **[spike tracking infrastructure]** Add `spike` as a valid epic type in `pm/scripts/validate.sh`. Define spike body structure: `Investigation scope` / `Done-when` criteria / `Result log` pointer to `docs/spikes/CC-NNN.md`. Create `docs/spikes/` directory with README describing format. Convert CC-209 epic from `design` → `spike`. Spike results must be committed to the repo — ephemeral findings are treated as a gap. | process | 2026-05-21 | — | P2 | design |
| CC-219 | ⏸ deferred | **[pre-milestone doc freshness gate]** Before each milestone release, verify docs are current: README, MILESTONES.md, BACKLOG.md (open tickets with TBD refs), `docs/` directory. Implement as a `scripts/check-docs-freshness.sh` checklist that prints stale indicators and exits non-zero if blocking gaps exist. Should run as part of the milestone closure checklist. | process/gate | 2026-05-21 | — | P3 | hygiene |
| CC-220 | ⏸ deferred | **[spike agent + `/spike` skill]** Implement `agents/spike.md` and `commands/spike.md`. Spike agent is a **planner** (like `project-pm`): reads a BACKLOG spike ticket, plans 2–3 investigation angles, returns a `spike_plan` block; the **main thread** fans out one Agent per angle (subagents cannot spawn subagents); the spike agent is re-invoked to synthesise findings into `docs/spikes/CC-NNN.md` and update the `Result log`. Modeled on `/pr-gate`'s reviewer fan-out. v0.3.0 M5. Depends on CC-218. | process/DX | 2026-05-21 | — | P3 | design |
| CC-221 | ✅ closed 2026-05-21 | **[copy-mode refresh semantics]** `link_or_copy` idempotency check compares dst sha256 against manifest (old src sha), so re-running `install.sh` does NOT refresh a copied file whose source changed — it matches the stale copy against the old manifest sha and returns ok. Fix: compare `sha256(src)` vs `sha256(dst)` directly; if different and mode=copy, re-copy and update manifest. Surfaced during CC-104v gate review; current behaviour documented as uninstall+reinstall workaround. | ops | 2026-05-21 | pr:#117 | P3 | oss |
| CC-212 | ⏸ deferred | **[CC-207 advise follow-up]** `make_junction_windows()` 仍用 inline PowerShell 字串傳路徑（`-Path '$win_src' -Target '$win_dst'`），但 `remove_junction_windows()` 已改用 `PM_DISPATCH_RM_DST` env var；兩者路徑傳遞慣例不一致，且 inline 字串在路徑含單引號時會壞掉。修正：改用 `PM_DISPATCH_MAKE_SRC` / `PM_DISPATCH_MAKE_DST` env var 傳入，統一 PowerShell 邊界慣例。Raised by critic + architecture-reviewer in gate-20260521-115634 as [medium] advise. | ops/portability | 2026-05-21 | pr:#112 | P3 | oss |
| CC-213 | ⏸ deferred | **[CC-207 advise follow-up]** `install_dir_junction()` 的 idempotency 邏輯用 Bash `[[ -L "$dest_dir" ]]` + `readlink` 判斷已安裝 junction，但 PowerShell 建立的 Windows directory junction 在 Git Bash 下不一定呈現為 `-L`；重新執行 `bash install.sh` 可能把 junction 目錄誤認為真實目錄而 fallback 到 per-file copy 並覆蓋 manifest。修正：加 Windows-aware junction probe（讀 manifest `mode` 欄位作 idempotency 判斷，或 `powershell.exe [System.IO.File]::GetAttributes`）。Raised by critic + qa-tester in gate-20260521-115634 as [medium]. | ops/portability | 2026-05-21 | pr:#112 | P3 | oss |
| CC-214 | ⏸ deferred | **[CC-207 advise follow-up]** `docs/platform-support.md` 手動 uninstall 說明使用裸 `bash uninstall.sh`，在非 repo-root 工作目錄下執行會找不到腳本；應改為 `bash "${PM_DISPATCH_REPO}/uninstall.sh"` 形式（與文件其他範例一致）。Raised by critic in gate-20260521-115634 as [low] advise. | ops/DX | 2026-05-21 | pr:#112 | P3 | oss |
| CC-222 | ✅ closed 2026-05-22 | **[v0.2.0 release prep]** Close the v0.2.0 milestone: confirm all Planned tickets ✅, Windows Git Bash smoke-test pass, write CHANGELOG.md [0.2.0] section, update MILESTONES.md (close v0.2.0), docs freshness sweep (doctor.sh 記錄於 GETTING_STARTED + platform-support), BACKLOG status flip, git tag v0.2.0 + GitHub Release. | process/release | 2026-05-22 | pr:#120 | P2 | oss |
| CC-225 | ⏸ deferred | **[claude-executor result observability]** `claude-executor` task output 寫入 session-scoped `/tmp/` 路徑，不進 REPO、不可跨 session 回溯，且無法 git diff 追蹤執行歷史。設計目標：主線程在 claude-executor 完成後把 brief 路徑、result 摘要、exit status 寫入 REPO 固定目錄（格式與 `.gate-results/` 一致），作為 CC-211 / CC-216 MCP 架構抽離的前提。sub-concern of CC-211. | ops | 2026-05-22 | — | P3 | design |
| CC-226 | ⏸ deferred | **[lint-frontmatter: extract shared dq-escape validation helper]** `check_frontmatter()` 內有 4 個 collection branch 各自重複相同的 dq escape whitelist regex、adjacent-quote check、empty-entry check，未來修改一個 branch 容易遺漏其他三個，造成 parity gap。建議抽取成 shared bash helper，或以 parity test 確保 4 個 branch 永遠同步。Raised as [medium] advisory in gate-20260522-171123. | arch/reuse | 2026-05-22 | pr:#119 | P3 | oss |
| CC-227 | ⏸ deferred | **[lint-frontmatter: extract YAML subset parser into lib/yaml-frontmatter.sh]** `lint-frontmatter.sh` 同時包含 CLI 解析、frontmatter 邊界偵測、~150 行 YAML subset parser，三個職責混在同一檔案。建議將 `check_frontmatter()` 搬到 `scripts/lib/yaml-frontmatter.sh`，讓 `lint-frontmatter.sh` 成為薄 CLI 包裝，`doctor.sh` 可 source lib 取代 fork subprocess，與 CC-226 建議合併進行。User feedback after CC-058 gating. | arch/reuse | 2026-05-22 | pr:#119 | P3 | oss |
| CC-228 | ⏸ deferred | **[BACKLOG validator-debt cleanup]** `pm/scripts/validate.sh` exits 1 on `main` with ~31 pre-existing E-codes: E-INDEX-MISMATCH (CC-104d/e/f/g/j/k/m/r/s in index but no body section), E-AREA-ENUM (slash-combined / non-enum areas e.g. `arch`/`config`/`schema` on CC-052/060/104v/203/204), E-REFS-PREFIX (bare `CC-NNN` refs on CC-059/060/061/064/066). Resolve per class: add missing sections or drop index rows; widen the area enum (e.g. add `arch`) or rewrite rows; fix ref prefixes. Surfaced during CC-222 close-out. | process | 2026-05-22 | — | P2 | hygiene |
| CC-229 | ⏸ deferred | **[v0.3.0 M1: core schemas]** Create `core/schema/{task,run,event,review,decision}.schema.json` — the five first-class PM-runtime entities (docs/architecture/v0.3.0-synthesis.md §5.2). Re-home `pm/schema.md` (BACKLOG grammar) under `core/`. Ships no behavior change; schema locked at end of M1. | process | 2026-05-22 | — | P1 | design |
| CC-230 | ⏸ deferred | **[v0.3.0 M1: state store]** Build the `~/.claude/.pm/state/` runtime state store — single-writer JSONL (`runs.jsonl`, `events.jsonl`) + index, guarded by `serialize_with_lock()`. Migrate the machine-written `routing_log.md` auto-block to `runs.jsonl` (kills the machine-written-Markdown-table anti-pattern). `pmctl` is the only writer. | process | 2026-05-22 | — | P1 | design |
| CC-231 | ⏸ deferred | **[v0.3.0 M1: core policy extraction]** Extract `core/policy/` declarative tables — reviewer-policy (the gate matrix now prose-only in `agents/project-pm.md`), executor-enum (closed: codex/claude), dispatch-states (the dispatch state machine). Pure definitions, zero behavior. | process | 2026-05-22 | — | P2 | design |
| CC-232 | ⏸ deferred | **[v0.3.0 M1: context-pack schema]** Define `core/schema/context-pack.schema.json` + the context-enricher interface — a pluggable pre-dispatch context bundle (files/symbols/memories/risks) assembled from sources. Decouples context enrichment from `codex-dispatch.sh`; consumed via `pmctl context build`. | process | 2026-05-22 | — | P2 | design |
| CC-233 | ⏸ deferred | **[v0.3.0 M3: layer-boundary test]** Add `scripts/test-layer-boundaries.sh` enforcing the four-layer dependency discipline — grep `core/` for forbidden tokens (CLI names, `~/.claude`, bash), grep `adapters/` for state-mutation calls. Cheap structural guard against architecture drift. | test | 2026-05-22 | — | P3 | design |
| CC-234 | ⏸ deferred | **[v0.3.0 M4: memory v2 — event-derived]** Point `/mem-distill` at `events.jsonl` (the action stream) alongside `episodes.jsonl` — memory derived from what agents do (tool calls, decisions, gate verdicts), not just chat (Memori-inspired). Four-tier card system unchanged; gives the event tier a schema. | memory | 2026-05-22 | — | P2 | design |
| CC-235 | ⏸ deferred | **[v0.3.0 M4: lifecycle gate]** Make the spec→design→plan discipline (today advisory in `commands/pre-impl.md` + `agents/project-pm.md`) a `pmctl`-enforced Task lifecycle gate — a Task ≥3 behavioral units cannot transition `claimed→in-progress` without a design artifact (Superpowers-inspired). | process | 2026-05-22 | — | P2 | design |
| CC-236 | 🟢 someday | **[pmctl report — away-from-keyboard state roll-up]** A `pmctl report` rolling up state since last invocation (open tasks, blockers, last gate verdict, recent runs). Deprioritized 2026-05-22: the maintainer does not run agents unattended, so a "morning report" time-gap framing has low current need; on-demand status is already part of the `pmctl` surface (CC-215). Revisit if the workflow ever includes overnight / away dispatch. | ux | 2026-05-22 | — | — | design |
| CC-237 | ⏸ deferred | **[v0.3.0 M4: context-enricher baseline]** Implement the context-enricher baseline sources — rg / `git ls-files` / `git diff` / memory search — producing a context-pack (CC-232) before dispatch. codegraph is evaluated separately as the CC-209 spike. `pmctl context build`. | ux | 2026-05-22 | — | P3 | design |
| CC-224 | ⏸ deferred | **[shared hook-profile inventory: doctor.sh ↔ install-hooks.sh]** `doctor.sh` owns a second hardcoded minimal/full hook membership model alongside `install-hooks.sh`, creating a silent drift path when hooks are added or profile semantics change. Extract the hook-profile list into a shared shell helper (e.g. `scripts/hook-profile.sh`) or add a parity test asserting both files expect the same hook set. Raised by critic + architecture-reviewer as [medium] advise in gate-20260522-100348. | arch/reuse | 2026-05-22 | — | P3 | oss |
| CC-049 | ✅ closed 2026-05-18 | Archive closed ticket sections → BACKLOG-ARCHIVE.md | process/docs | 2026-05-17 | pr:#87 | — | hygiene |
| CC-050 | ✅ closed 2026-05-18 | Audit stale deferred tickets CC-011/012/014/015 | process/docs | 2026-05-17 | pr:#87 | — | hygiene |
| CC-051 | ✅ closed 2026-05-18 | **[BACKLOG hygiene Tier 1]** Add schema convention preamble at top of BACKLOG.md: ID convention (`CC-NNN` sequential except `CC-1NN` = CC-OSS epic markers, `CC-2NN` = reuse-debt markers — semantic groupings, not numeric ranges), sub-letter convention (`CC-NNNa/b/c` = follow-ups to parent ticket), status emoji legend (✅ closed / 🟡 deferred / 🔵 active / ⚠️ partial / ⏸ deferred-low-pri). Without this docs, fork users see "weird gaps" and don't know the conventions | process/docs | 2026-05-17 | — | — | hygiene |
| CC-052 | ✅ closed 2026-05-19 | **[BACKLOG schema upgrade]** `pm-schema v1.1`：index table 新增 `priority` 欄（P1/P2/P3）+ `epic:` 欄（正交分組取代 ID gap 慣例）；validator 同步更新；全列補欄。CC-051（preamble）先行；CC-052 在 CC-051 落地後啟動 | process/schema | 2026-05-17 | pr:#93 | — | hygiene |
| CC-053 | ✅ closed 2026-05-18 | `test-commands.sh` CLI self-test coverage | test | 2026-05-18 | pr:#84 | — | hygiene |
| CC-054 | ⏸ deferred | CC-025 M2 — `/skill-refine` diff generation and Claude-assisted refinement；scope deferred when CC-025b was closed in `feat/cc039-cc025b-v2` | ux/memory | 2026-05-18 | pr:#67 | — | — |
| CC-055 | ✅ closed 2026-05-18 | `commands/pr-gate.md` frontmatter YAML syntax error fixed | ops/DX | 2026-05-18 | pr:#86 | — | hygiene |
| CC-056 | ✅ closed 2026-05-18 | `scripts/lint-frontmatter.sh` + CI job + 12 regression tests | ops/test | 2026-05-18 | pr:#86 | — | hygiene |
| CC-057 | ✅ closed 2026-05-18 | README `skills/` layout row + `update-config` ref removed | docs/DX | 2026-05-18 | pr:#86 | — | hygiene |
| CC-058 | ✅ closed 2026-05-22 | `scripts/doctor.sh`：安裝前後環境健康檢查（claude/codex/jq 存在、hooks 已裝、memory dir、scripts executable、frontmatter lint）；每項失敗給出可操作修復步驟 | ops/DX | 2026-05-18 | pr:#119 | P3 | — |
| CC-059 | ⏸ deferred | Thin `/pm.md` command：把 brief 建立 / handover validation / dispatch / BashOutput tracking / diff verify 等 runtime 邏輯移入 `scripts/pm-dispatch-runner.sh` 等腳本；pm.md 只保留意圖描述與行為約束 | arch/ops | 2026-05-18 | CC-200 | — | design |
| CC-060 | ⏸ deferred | Codex model/config 外部化：把 hardcoded 模型名稱、sandbox policy、approval policy 抽到 config file（`defaults/codex.toml` 或 `.env.defaults`）；commands 與 scripts 讀 config 而非寫死 | arch/config | 2026-05-18 | CC-047 | — | — |
| CC-061 | ⏸ deferred | 建立 `skills/` 目錄 + 2–3 個 starter SKILL.md：`dispatch-brief/SKILL.md`、`pr-gate-review/SKILL.md`（對齊 Anthropic Skills spec；README 已聲稱支援但目錄不存在）；與 CC-014/CC-015/CC-026 技能定義解耦，這條處理目錄結構 | arch/ux | 2026-05-18 | CC-057 | — | — |
| CC-062 | ⏸ deferred | codex-bash-guard policy test matrix：建立 `tests/policy/codex-bash-guard/` 結構化 allow/deny JSON fixtures；讓安全 policy 從「很聰明的 shell parser」變「可驗證的 test matrix」 | ops/security | 2026-05-18 | — | — | — |
| CC-063 | 🟡 deferred | Trace / token / gate metrics dashboard：`.agent-trace/*.jsonl` + `rate-limits*.json` + `.gate-results/*.md` 已有足夠資料；可視化 per-session token、gate pass rate、routing_log 校準趨勢 | ux/ops | 2026-05-18 | — | P3 | — |
| CC-064 | 🟡 deferred | **[P2]** Project bootstrap wizard：互動式 `scripts/setup-project.sh --init` 引導新 repo 建立 memory、rules、PM schema；取代目前「手讀 GETTING_STARTED.md 再手跑指令」流程 | ux | 2026-05-18 | CC-031 | P2 | — |
| CC-065 | 🟡 deferred | Per-repo configurable gate pipeline：不同 repo 可設定不同 reviewer 組合與 tier 預設（例如 `.pm-dispatch/gate.toml`）；現在所有 repo 共用同一 gate config | ops/gate | 2026-05-18 | — | P3 | — |
| CC-066 | 🟡 deferred | Declarative `policy.yml` for hook allowlist：把 `hook-codex-bash-guard.sh` 的允許/拒絕清單從 shell logic 抽成 `config/policy.yml`；hook 讀 policy 而非 hardcode；可 per-repo override | arch/security | 2026-05-18 | CC-204 | P3 | design |
| CC-067 | ✅ closed 2026-05-19 | **[schema cleanup]** 廢棄 ID gap 慣例：移除 schema.md + BACKLOG preamble 中 CC-1NN/CC-2NN 保留範圍說明；改以 v1.1 `epic` 欄位為唯一分組依據；補 DECISIONS.md 決策記錄 | process | 2026-05-19 | decisions:#2026-05-19-deprecate-id-gap-convention | P2 | hygiene |

---

## Convention

**ID scheme**: `CC-NNN` sequential. ID gaps are normal — use the `epic` column (see `pm/schema.md §2.4.5`) for semantic grouping instead of ID ranges. The `CC-1NN`/`CC-2NN` range-reservation convention is deprecated (see `DECISIONS.md#2026-05-19-deprecate-id-gap-convention`).

**Sub-letter IDs**: `CC-NNNa`, `CC-NNNb`, `CC-NNNc` are follow-up tickets to a parent `CC-NNN`, with independent lifecycles.

**Status legend**:
- `🔵 active` — in backlog (not-started / in-progress / blocked)
- `✅ closed YYYY-MM-DD` — shipped; body collapsed to closed stub
- `🚫 dropped YYYY-MM-DD` — will not do; body stubs to DECISIONS
- `✅ done` — soft-close; no PR or date needed
- `⏸ deferred` / `🟡 deferred` — waiting on external condition, not scheduled
- `🟢 someday` — valid idea, no expected schedule
- `🟢 superseded YYYY-MM-DD` — superseded by a later item; body stubs to successor CC-NNN
- `⚠️ partial YYYY-MM-DD` — partially shipped; sub-items remain open (see body)

**Closed stubs**: When inflation policy triggers, closed bodies move to `BACKLOG-ARCHIVE.md`; index row + `**See**: BACKLOG-ARCHIVE.md` stub remain here.

**Priority column**: `P1`（本週必做）/ `P2`（本 sprint）/ `P3`（排隊）/ `—`（未設）。
**Epic column**: `oss`（CC-OSS 公開源碼系列）/ `reuse-debt`（技術債重用）/ `hygiene`（流程維護）/ `design`（新功能架構設計與 interface 決策）/ `spike`（調查類任務）/ `—`（其他）。
向下相容：v1.1/v1.2 file 中缺此兩欄的列只 emit 警告（不阻斷 gate）。

<!-- archived stubs — full text in BACKLOG-ARCHIVE.md -->

## CC-005 — install.sh preflight 改為 opt-in via `--verify` ✅ 2026-05-18

**See**: BACKLOG-ARCHIVE.md

## CC-006 — statusLine hook 自動寫入 rate-limits ✅ 2026-05-13

**See**: BACKLOG-ARCHIVE.md

## CC-007 — brief qa_checklist 指引 ✅ 2026-05-13

**See**: BACKLOG-ARCHIVE.md

## CC-008 — Spark routing 判斷標準 ✅ 2026-05-13

**See**: BACKLOG-ARCHIVE.md

## CC-009 — UserPromptSubmit hook inject MEMORY.md ✅ 2026-05-14

**See**: BACKLOG-ARCHIVE.md

## CC-010 — `/memory-compress` 指令 ✅ 2026-05-14

**See**: BACKLOG-ARCHIVE.md

## CC-013 — `/caveman` token 壓縮 skill ✅ 2026-05-18

**See**: BACKLOG-ARCHIVE.md

## CC-016 — gate NO-GO fix-loop 效率 ✅ 2026-05-14

**See**: BACKLOG-ARCHIVE.md

## CC-017 — 前端 UI 實作前置流程 ✅ 2026-05-14

**See**: BACKLOG-ARCHIVE.md

## CC-019 — Episodic memory 層 ✅ 2026-05-14

**See**: BACKLOG-ARCHIVE.md

## CC-020 — `/mem-search` 跨 memory 搜尋 ✅ 2026-05-14

**See**: BACKLOG-ARCHIVE.md

## CC-021 — test scripts `--filter` / `--list` ✅ 2026-05-14

**See**: BACKLOG-ARCHIVE.md

## CC-022 — `/pre-impl` 開發前設計評審 ✅ 2026-05-14

**See**: BACKLOG-ARCHIVE.md

## CC-025 — `/skill-refine` skill 自我精修 ✅ 2026-05-18

**See**: BACKLOG-ARCHIVE.md

## CC-025b — `/skill-refine` M1+M2 advisory follow-ups ✅ 2026-05-18

**See**: BACKLOG-ARCHIVE.md

## CC-027 — PreToolUse `hook-tool-trace.sh` ✅ 2026-05-15

**See**: BACKLOG-ARCHIVE.md

## CC-028 — PostToolUse `hook-routing-log.sh` ✅ 2026-05-15

**See**: BACKLOG-ARCHIVE.md

## CC-029 — `test-codex-dispatch.sh` 加入 CI ✅ 2026-05-15

**See**: BACKLOG-ARCHIVE.md

## CC-034 — `install-hooks.sh` 改名/移動 bug ✅ 2026-05-15

**See**: BACKLOG-ARCHIVE.md

## CC-036 — `/pm` dispatch async ergonomics restore ✅ 2026-05-18

**See**: BACKLOG-ARCHIVE.md

## CC-036b — dispatch handover authorized-override reconciliation ✅ 2026-05-16

**See**: BACKLOG-ARCHIVE.md

## CC-037 — `hook-routing-log.sh` concurrent append race ✅ 2026-05-18

**See**: BACKLOG-ARCHIVE.md

## CC-039 — shared-schema brief enrichment + `/pre-impl` Q4 audit ✅ 2026-05-18

**See**: BACKLOG-ARCHIVE.md

## CC-040 — agent-agnostic dispatch schema rename ✅ 2026-05-16

**See**: BACKLOG-ARCHIVE.md

## CC-047 — `scripts/codex-dispatch.sh` model alias mapping ✅ 2026-05-17

**See**: BACKLOG-ARCHIVE.md

## CC-053 — `test-commands.sh` CLI self-test coverage ✅ 2026-05-18

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

## CC-102b — CC-102 PR-gate advisory follow-ups ✅ 2026-05-17

**See**: BACKLOG-ARCHIVE.md

## CC-103 — [CC-OSS Phase 3] Portability shim ✅ 2026-05-17

**See**: BACKLOG-ARCHIVE.md

## CC-103b — /pr-gate executor split ✅ 2026-05-17

**See**: BACKLOG-ARCHIVE.md

## CC-104 — [CC-OSS Phase 4] Onboarding docs batch ✅ 2026-05-17

**See**: BACKLOG-ARCHIVE.md

## CC-104h — CC-104 handover schema docs ✅ 2026-05-17

**See**: BACKLOG-ARCHIVE.md

## CC-104i — CC-104 install.sh profile docs ✅ 2026-05-17

**See**: BACKLOG-ARCHIVE.md

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

## CC-104o — Windows Store python3 stub (superseded by CC-104t)

**See**: CC-104t

## CC-104p — serialize_with_lock routing-log shim ✅ 2026-05-21

**Outcome**: `scripts/lib/portable.sh` now exposes `serialize_with_lock()`, preferring `flock` when available and falling back to `mkdir_lock` via `FAKE_FLOCK_MISSING=1`-testable path. `hook-routing-log.sh` routes append serialization through the shim. Portable and routing tests cover both lock paths and rc propagation.
**See**: pr:TBD

## CC-104v — copy-mode install summary banner ✅ 2026-05-21

**Outcome**: `install.sh` counts `link_or_copy` rc=1 copy fallbacks and prints one non-dry-run summary banner explaining that source edits do not propagate automatically. Windows Git Bash docs now call out copied helper scripts and the need to re-run `bash install.sh` after updates.
**See**: pr:#116

## CC-105 — [CC-OSS Phase 5] BACKLOG cleanup + v0.1.0 release ✅ 2026-05-17

**See**: BACKLOG-ARCHIVE.md

## CC-003 — parallel-gate artifact-ignore 前置檢查

**Problem**: scripts/pr-gate.sh parallel mode 在 line 410/414 對 git status --porcelain 取 fingerprint，但 fingerprint 取樣後 gate 本身會寫入 .agent-trace/ / .codex-briefs/ / .gate-results/。若 target repo 沒跑過 setup-project.sh 或這三個路徑未在 .gitignore，gate 自己的寫入就會改動 status hash，觸發 line 575 的 fail-closed integrity check，在原本健康的 repo 卡住 PR review。
**Why**: parallel mode 整體假設「gate 執行期間 git status 不會被 gate 自己污染」。這假設只在 .gitignore 已含三個 artifact 路徑時成立，但 setup-project.sh 是否跑過、是否完整，gate 沒有 preflight 驗證。Cross-reviewer overlap (qa-tester + risk-reviewer 同點)，代表不是單一 reviewer 視角偏見。Loud + reversible (不會默默過 gate)，但屬於把工作流卡死的 ops 問題。
**Requirement**: parallel mode 啟動時必須能在 target repo 確認 gate artifact 路徑已被 ignore，或結構性排除這些路徑使其不影響 integrity check。可接受任一方向：preflight ignore-coverage 檢查（缺則明確指引跑 setup-project.sh）；或 integrity check 計算 status hash 時排除 known gate artifact paths；或文件 + test 明示 setup-project.sh 是 parallel mode precondition，並讓未滿足時的失敗訊息直接指向修復步驟。

## CC-004 — test-pr-gate.sh docstring 格式統一

**Problem**: scripts/test-pr-gate.sh 新增的 shell test functions 使用散文註解描述行為，而非 pm-schema 規範的 structured behavior/Steps docstring 形式。
**Why**: tests 本身 behavior-named、deterministic，功能無虞，純為 audit-quality / 一致性問題。長期會讓新人讀測試時樣式不一。
**Requirement**: 把新增 test functions 的開頭註解改寫成與既有 hook tests 一致的 behavior/Steps docstring 結構。不改測試邏輯。

## CC-011 — sync-memory.sh + 跨裝置共用（deferred）

**Problem**: `~/.claude/projects/*/memory/` 為本機路徑，多台電腦之間 memory 各自獨立，無法共用。
**Why**: 用戶目前不急，但設計上若以 symlink 指向 Dropbox/iCloud/OneDrive 資料夾，可以零維護代價實現跨裝置共用，且完全相容現有 file-based memory 架構。
**Requirement**: `scripts/sync-memory.sh --setup <cloud-path>` 把 memory 資料夾 symlink 到雲端同步路徑；`install.sh` 加入 opt-in 步驟。
**Status note (CC-050 audit 2026-05-18)**: Downgraded from ⏸ deferred to 🟢 someday — concept valid, no active plan. Re-evaluate if cross-device sync interest grows.

## CC-012 — SessionStart hook pull memory（deferred）

**Problem**: 若多台電腦透過 CC-011 共用同一雲端 memory 資料夾，session 啟動時不保證已取得最新版本。
**Why**: 輕量方式是 SessionStart hook 觸發一次 rsync/git pull，確保 memory 是最新版。
**Requirement**: `scripts/hook-sync-memory.sh` SessionStart hook；支援 git pull 和 rsync 兩種模式；失敗時靜默降級。
**Note**: 依賴 CC-011。
**Status note (CC-050 audit 2026-05-18)**: Downgraded from ⏸ deferred to 🟢 someday — depends on CC-011; no active plan. Re-evaluate together with CC-011.

## CC-014 — `using-git-worktrees` skill

**Status note (CC-050 audit 2026-05-18)**: Downgraded from 🔵 active — no open branch. Re-activate when work begins.
**Problem**: `--parallel` PR gate 各 reviewer 在同一 working tree 執行，reviewer 寫入可能互相干擾。
**Why**: git worktree 讓每個 subagent 在獨立環境工作，避免狀態污染，也直接補強 CC-003 的解法方向。
**Requirement**: `commands/using-git-worktrees.md` skill，指導平行開發中使用 git worktree；評估 `--parallel` gate 是否可為每個 reviewer 建立獨立 worktree。

## CC-015 — `systematic-debugging` skill

**Status note (CC-050 audit 2026-05-18)**: Downgraded from 🔵 active — no open branch. Re-activate when work begins.
**Problem**: debug 工作流目前無標準化流程，每次偵錯方式不一致，容易遺漏根本原因分析。
**Why**: 結構化偵錯步驟（reproduce → isolate → hypothesize → verify → fix → regression test）有助於複雜 bug 分析。
**Requirement**: `commands/systematic-debugging.md` slash command，提供結構化偵錯步驟。

## CC-018 — Codex quota 自動追蹤

**Problem**: CC-006 解決了 Claude 5h rate-limit 自動讀取，但 Codex 無等效 hook 機制；目前 Codex 使用量只靠 `log-usage.sh` 手動寫入，用戶無法即時得知剩餘額度。
**Why**: Codex 走 OpenAI API 路徑，quota 資訊需要主動查詢（response header 或 `/v1/organization/usage`），架構不同於 Claude StatusLine hook。
**Requirement**:
1. 研究 Codex API response headers（`x-ratelimit-remaining-requests` / `x-ratelimit-remaining-tokens`）
2. 若有：`scripts/codex-dispatch.sh` dispatch 後解析 headers，寫入 `~/.claude/rate-limits-codex.json`
3. 若無：呼叫 `/v1/organization/usage` 或記錄技術限制
4. `token-usage.sh` 加入 Codex pool 剩餘顯示
**Note**: 實作前需先手動驗證 Codex API header 行為。

## CC-024 — `test-usage-weekly.sh` 加入 GitHub Actions CI ✅ 2026-05-15

**See**: BACKLOG-ARCHIVE.md

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

## CC-032 — `[[feedback_*]]` cross-link 公開化（dead-link 防護）

**Problem**: BACKLOG.md（含本次 CC-025..CC-030 新條目）多處引用 `[[feedback_undocumented_harness_payload]]`、`[[feedback_known_bug_backlog]]`、`[[feedback_codex_routing]]`、`[[routing_log]]` 等 — 這些 memory 檔**不在 repo 內**（在 `~/.claude/projects/<proj>/memory/`，純本地）。轉公開後，外部讀者點不開、不知道內容、cross-link 形同 dead link。
**Why**: 公開要兼容「沒有 user memory 的讀者」。兩條路：(a) 把這些 feedback rules 中真正屬於 repo 政策的部分抽到 `docs/policies/*.md` 並改 link 指向新位置；(b) 在每次第一次引用時 inline 引述兩三行。前者乾淨且可被 search engine 索引、後者侵入度低但容易過時。建議 (a)，配合 schema 規則：所有 BACKLOG 條目的 `[[name]]` 必須對應 `docs/policies/<name>.md` 存在。
**Requirement**:
1. 盤點所有 BACKLOG.md / docs/ 中 `[[feedback_*]]` 與 `[[*_log]]` 出現位置。
2. 把屬於「repo 適用政策」（非個人偏好）的 rule 抽寫至 `docs/policies/<slug>.md`，每篇含：摘要、原因、實作守則、reference。
3. 更新所有 `[[name]]` 改為 `[docs/policies/<slug>.md](docs/policies/<slug>.md)` 或 `[[<slug>]]`（若決定保留 wikilink 風格、配合 CC-030 validator 擴充驗證 link target 存在）。
4. 個人偏好類 feedback memory（不適合公開）留 local memory 不對外。
**Note**: 與 CC-030 schema validator 設計協同 — 可同 PR 加上「`[[name]]` link target 必須存在」的 validation。Blocks **CC-033**。
**Source**: 2026-05-15 對話 — 公開前置盤點 #3（Explore 未抓到的盲點）。

## CC-033 — Public flip checklist 與後續觀察

**Problem**: 完成 CC-031/CC-032 後，public flip 本身仍涉及多個 GitHub repo 設定決策（Issues 開關、Discussions 開關、template、labels、release tagging policy），需要明確 checklist 避免「按下 public 後才發現某設定不對」。
**Why**: 公開是 one-way door — 翻成 public 之後 commit history 全部對外（雖然 git history 已審 clean）；issue 也會公開。所以 flip 本身需要清單化，並決定先試水溫的 setting（Discussions only vs 全開）。
**Requirement**:
1. 決策清單：(a) Issues 開關（建議先關，僅 Discussions），(b) Discussions categories 規劃，(c) PR template，(d) release tagging（已有 1.1.0，是否設 GitHub Releases），(e) 是否加 CITATION.cff。
2. 觀察期：flip 後 2-4 週評估 — 若有有效 use case 出現再開 Issues。
3. Flip 動作本身為 1 行：`gh repo edit --visibility public`。
**Note**: 依賴 **CC-031**, **CC-032** 完成；本條為「最後一哩」與後續評估。
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

## CC-044 — `tool-trace.jsonl` rotation/retention policy upgrade（deferred）

**Current baseline (shipped in CC-027)**: 4 MiB single-archive rotation — when `tool-trace.jsonl` exceeds 4 MiB, it is renamed to `tool-trace.jsonl.1` (overwriting any prior `.1`) and a fresh main file is started. Retention semantics: "current file plus one overwritten archive". Constant-time stat check, non-blocking on rotation failure.
**Problem**: The 4 MiB single-archive baseline bounds growth (clears the unbounded-growth risk) but overwrites prior trace history on each rotation. For long-running projects or post-hoc analysis of CC-025/CC-026 signals, multi-window retention may be needed.
**Why**: Multi-tier retention needs a separate design choice: retain by last N sessions, gzip/archive windows, or time-based eviction. The MVP baseline keeps blast radius low while CC-025/026 consumers are not yet implemented.
**Requirement**: Design and implement the upgrade from "current + one overwritten archive" to a multi-window retention policy (proposal: N rotated archives with gzip, or daily archive directory). Include tests for boundary behavior, archive integrity, and non-blocking failure.
**Source**: 2026-05-15 CC-027 implementation brief + PR-gate critic/arch/risk advise on rotation/retention contract clarification.

## CC-027b — `tool-trace.jsonl` health signal（deferred）

**Problem**: Trace collection failures are currently best-effort and audit-only. If append, parse, or rotation problems persist, downstream CC-025/CC-026 workflows may read incomplete `tool-trace.jsonl` data without a visible warning.
**Why**: The hook must stay non-blocking, but silent long-term degradation makes later skill-refine / skill-distill signals unreliable. A bounded local error counter can preserve non-blocking behavior while surfacing sustained failure to downstream commands.
**Requirement**: Add a bounded error counter for `tool-trace.jsonl` health and have downstream commands surface a warning when the error count exceeds N. Keep hook execution non-blocking and cap any health-state file growth.
**Source**: `2026-05-15 CC-027 PR-gate risk-reviewer finding`.

## CC-027c — `hook-tool-trace.sh` strict JSON validation（deferred）

**Problem**: Brace-shaped malformed JSON (e.g. `{"cwd":"/x","tool_name":"Bash","tool_input":{` truncated mid-object) can pass the bash brace heuristic and produce a garbage line in `tool-trace.jsonl`. Identified by critic + qa-tester in CC-027 PR-gate.
**Why**: Strict validation via inline `jq -e .` costs ~25ms/call subprocess startup on this host — alone exceeds the entire per-call budget (8.2ms baseline). Inline strict mode is structurally incompatible with the hook performance contract.
**Requirement**: Explore async post-validation path: append first (non-blocking), validate sampled fraction asynchronously, or move strict validation to the downstream consumer (CC-025/026) where 25ms/call is amortized over rare reads instead of every tool invocation.
**Note**: Garbage line is data-quality concern only — no security/risk vector (the garbage doesn't leak content, doesn't crash, downstream consumers can skip malformed lines defensively).
**Source**: `2026-05-15 CC-027 PR-gate critic + qa-tester findings`.

## CC-023 — `coupling-reviewer` PR gate 耦合分析（deferred）

**Problem**: PR gate 的 architecture-reviewer 依賴 Claude 主觀判斷耦合問題，沒有客觀量化基線。
**Why**: 量化耦合指標（afferent/efferent coupling、循環複雜度）可提供客觀基線；coca/dependency-cruiser/gocyclo 等工具已成熟。
**Requirement**: `scripts/coupling-check.sh` 語言偵測 + 工具呼叫，只分析 changed files；PR gate 加入可選 `--coupling` flag；閾值超過 → block-soft。
**Note**: 依賴 CC-022 建立設計評審文化後再推進。

## CC-045 — brief timeout heuristic + playbook-depth short-circuit（deferred）

**Problem**: Brief author 目前對 `timeout` 沒有明確啟發法 — 多半以 edit size 為單一估算依據。但 Codex 預設行為是先吃完整個 target repo 的 onboarding chain（AGENTS.md / rules/global / rules/domain / 跨 repo playbook docs）再動工。對 playbook 深的 repo 即使只改 ~10 行也會在 prelude 階段燒掉 200s+，超薄 timeout 直接 SIGKILL 在 research 階段。
**Why**: 2026-05-16 japanese-site `chore/js-100-split-js-113` 修 yml/md parity（~10 yml + 4 md 行 mechanical sync）走 codex-dispatch.sh `--timeout 240`，exit 124；trace 顯示 11 個 `command_execution` 全是 doc read（`prompt-budget.yml`、`../agent-playbook-template/docs/{rules-quickstart,operating-rules,agent-playbook}.md`、`DECISIONS.md`、`project/project-manifest.md`、`rules/global/{security-baseline,prompt-injection}.md`、`rules/domain/*.md`），未進編輯階段。**根因**：brief author 把「edit 14 行 ≈ 240s」推估時未把 playbook depth 算進去。
**Requirement**:
1. `docs/dispatch-brief.md` brief schema 文件加 `timeout` 啟發法 guidance：
   - flat repo（無 `rules/`、無 `AGENTS.md`、無 cross-repo playbook 連結）：mechanical edit 240–600s OK
   - shallow playbook（單一 `AGENTS.md` 或 `<10` 條 rules）：mechanical edit 600–900s
   - deep playbook（`rules/global` + `rules/domain` 或跨 repo playbook refs，例：japanese-site）：mechanical edit **最低 900s**；judgment-heavy（editorial / schema）1500s+
2. brief context 加可選短路 clause 模板：`"Constraints captured in this brief; do NOT re-read AGENTS.md / rules/ / playbook docs"` — 對 self-contained brief + mechanical edit 直接砍 5–10 個 read 命令。需在 `docs/dispatch-brief.md` 給範例。
3. （可選 / 第二階段）`scripts/codex-dispatch.sh` 啟動時偵測 `<working_dir>/rules/` 或 `<working_dir>/AGENTS.md` 存在且 `--timeout < 900` 時 emit stderr WARNING（不阻擋），surface author 設置錯誤於 SIGKILL 之前。
4. 觀察 N≥2 次 cross-session 重現後，promote 為 `feedback_brief_timeout_playbook_depth` memory（[[known-bug backlog rule]] + [[Codex routing preferences]] 衍生）。
**Source**: 2026-05-16 cross-session diagnostic — japanese-site dispatch exit 124 with 240s timeout，trace `.agent-trace/codex-20260516-193626-47431.jsonl`。
**Note**: 立即 workaround 是 brief author 對 deep playbook repo 預設 timeout=1500s；本條 ticket 是把這條 workaround 升級為文件化規則 + 可選 wrapper-side warning。
**Cross-link**: [[Codex routing preferences]] 路由表 / [[known-bug backlog rule]] 補登原則。

## CC-046 — validate.sh + run-tests.sh dedup ✅ 2026-05-19

**See**: decisions:#cc046-validate-dedup

**Outcome**: (a) validate.sh 兩個 awk pass 合併為單一 awk 程式；`parse_status()` / `row_kind[]` 成為唯一的 status 解析路徑，CHANGELOG drift check 直接 consume 同一份 state。`note_index_refs()` 與 `status_kind()` 均刪除。(b) `run_validate_case_multi` 刪除，統一為 varargs `run_validate_case`，34 個 call site 全部遷移。38 tests pass。
**Deferred**: structured behavior/Steps docstring 注解（原 Requirement 3，低優先）— 未做，不影響正確性。如後續認為值得補，可作為獨立 hygiene PR。

## CC-049 — BACKLOG hygiene Tier 1 archive closed detail sections ✅ 2026-05-18

**See**: BACKLOG-ARCHIVE.md

## CC-050 — BACKLOG hygiene Tier 1 stale deferred audit ✅ 2026-05-18

**See**: BACKLOG-ARCHIVE.md

## CC-051 — BACKLOG schema convention preamble ✅ 2026-05-18

**See**: BACKLOG-ARCHIVE.md

## CC-052 — `pm-schema v1.1` BACKLOG schema upgrade ✅ 2026-05-19

**Outcome**: pm-schema v1.1 shipped — `Priority` + `Epic` index columns, validator checks (E-PRIORITY-ENUM / E-EPIC-ENUM / W-MISSING-COLS), all rows backfilled. 36 tests pass.
**See**: pr:#93

## CC-054 — CC-025 M2 `/skill-refine` diff generation（deferred）

**Problem**: CC-025 delivered the M1 read-only signal bundle and CC-025b closed the usage-guard plus `CLAUDE_MEMORY_DIR` contract follow-ups, but the original M2 scope for `/skill-refine` diff generation remains unimplemented.
**Why**: The useful product loop is not complete until the tool can turn skill feedback signals into a reviewable refinement diff. Closing CC-025b without a separate M2 tracker would make that deferred scope easy to lose.
**Requirement**:
1. Extend `/skill-refine` so it can generate a proposed diff for the target skill or command from curated memory/feedback signals.
2. Keep the default behavior review-first: emit the diff for user or main-thread approval rather than directly rewriting skill files.
3. Include Claude-assisted refinement guidance in `commands/skill-refine.md`, with clear dry-run and apply boundaries.
4. Add contract tests for diff-generation behavior and no-direct-write safety.
**Source**: PR #67 CC-025 M1 implementation and 2026-05-18 CC-025b closure decision in `feat/cc039-cc025b-v2`.

## CC-058 — scripts/doctor.sh：環境健康檢查 ✅ 2026-05-22

**See**: PR #119

**Problem**: 沒有單一指令能驗證「pm-dispatch 能否正常工作」。使用者需要逐一排查 claude/codex/jq 是否安裝、hooks 是否已 wire、memory dir 是否存在、scripts 是否 executable、frontmatter 是否合法。
**Why**: install.sh 處理「安裝」，但不處理「診斷」；新用戶在環境不完整時只能看到含糊的錯誤訊息。`scripts/doctor.sh` 是標準 toolchain 慣例（Homebrew `doctor`、Volta `doctor` 等）。
**Requirement**: `scripts/doctor.sh` 逐項檢查：(1) `claude` 是否在 PATH；(2) `codex` 是否在 PATH（warn 非 error）；(3) `jq` 是否存在；(4) hooks 是否 installed（讀 settings.json hooks 欄位）；(5) `~/.claude/projects/.../memory/` 目錄是否存在；(6) `scripts/*.sh` 是否 executable；(7) frontmatter lint（呼叫 CC-056）。每項 OK / WARN / FAIL 附修復指令。整體 exit 0（OK/WARN only）或 exit 1（any FAIL）。

## CC-059 — Thin /pm.md：把 runtime 執行邏輯移入 scripts

**Problem**: `commands/pm.md` 包含 brief file 建立、handover validation、Codex dispatch、background mode、BashOutput tracking、stderr parsing、git diff verify、exit 124 retry 等大量流程邏輯。markdown command 逐漸變成「半程式碼、半 prompt、半 policy」的混合體。
**Why**: 當 Codex CLI、Claude Code hooks 或 scripts 行為改變時，markdown command 很容易與實際腳本 drift。script 有測試；markdown 沒有。
**Requirement**: 識別 pm.md 中可搬到 shell script 的 runtime 步驟（特別是 handover extraction + validation + dispatch 命令組裝）；移入 `scripts/pm-dispatch-runner.sh`（或直接加強 `scripts/lib/`）；pm.md 只保留「什麼情境呼叫什麼腳本」的意圖描述與 trigger 條件。依賴 CC-200（executor-router.sh）。

## CC-060 — Codex model/config 外部化

**Problem**: Codex model 名稱（`gpt-5.3-codex-spark`）、sandbox policy（`workspace-write`）、approval policy（`never`）、timeout（1200s）等參數分散硬碼在 commands/*.md 與 scripts 中。Codex CLI model alias 已在 CC-047 修過一次；未來 OpenAI/Anthropic 改動 API 時又要逐一搜改。
**Why**: config drift 是 toolchain maintenance 的主要成本之一；config file + script 讀取比 grep-and-replace 更可靠。
**Requirement**: 建立 `defaults/codex.toml`（或 `.env.defaults`）收納模型名稱、sandbox、approval、timeout；scripts/codex-dispatch.sh 讀 config；commands 只引用語意名稱（`codex_spark`），不寫死 API 字串。依賴 CC-047（已關）。

## CC-061 — 建立 skills/ 目錄 + starter SKILL.md

**Problem**: README 和 CC-057 指出 `skills/` 目錄不存在，但 Anthropic Skills spec 定義 SKILL.md 為可重用能力包（只在需要時載入 context）。現有 `commands/pm.md`、`commands/pr-gate.md` 有大量重用邏輯，天然適合轉成 skills。CC-014（using-git-worktrees）、CC-015（systematic-debugging）、CC-026（/skill-distill）均等待 skills/ 基礎建設。
**Why**: skills 比 commands 更輕量（context on-demand），且是 Anthropic 現在主推的擴展方式。建立 2–3 個 starter skills 能讓 CC-014/015/026 有落地路徑，也修正 README 現有聲明。
**Requirement**: 建立 `skills/dispatch-brief/SKILL.md`（封裝 brief 建立 + handover validate 流程）和 `skills/pr-gate-review/SKILL.md`（封裝 reviewer 派發流程）；在 install.sh 的 helper scripts 區段加入 `skills/` symlink；README skills/ 目錄說明改為實際有內容。先行條件：CC-057 (A) 完成後執行此條。

## CC-062 — codex-bash-guard policy test matrix

**Problem**: `hook-codex-bash-guard.sh` 的允許/拒絕邏輯非常複雜（newline 檢查、quote 檢查、shell metacharacters、background mode、git form allowlist、read path allowlist）。目前有 test-hooks.sh 的整合測試，但沒有結構化的 per-rule fixtures；policy 改動的影響面不透明。
**Why**: shell-based policy parser 有兩種失效模式：過度阻擋合法工作流，以及漏過某些 bypass。只有可讀的 allow/deny test matrix 能讓安全 policy 從「很聰明」變「可驗證」。
**Requirement**: 建立 `tests/policy/codex-bash-guard/` 目錄，以 JSON fixtures（每個 fixture 含 `input`、`expected: allow|deny`、`reason`）描述每條規則的 allow 和 deny case；`scripts/test-codex-bash-guard.sh` 讀 fixtures 執行；CI 加入此 job。

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

## CC-066 — [P2] Declarative policy.yml for hook allowlist

**Problem**: `hook-codex-bash-guard.sh` 的 git allowlist、read path allowlist、shell metacharacter blocklist 等 policy 直接寫在 shell script 邏輯中；per-repo override 不可能，policy 審計需要讀 shell code。
**Why**: policy-as-code 優於 policy-in-code：可 diff、可 review、可 override、可 lint。CC-204（hook framework reuse）完成後這條的實作成本大幅下降。
**Requirement**: `config/policy.yml`（repo 級預設）+ `~/.pm-dispatch/policy.yml`（user override）定義 git allowlist / read roots / metachar blocklist；hook 腳本 load + merge policy；CC-062 test matrix 讀 policy fixtures。依賴 CC-062、CC-204。

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

## CC-206 — gate lifecycle hook（deferred）

**Problem**: Codex sandbox 無法存取 Docker socket，導致需要 Docker backed services（Postgres、Redis 等）的整合測試在 gate 中無法執行。主線程（Claude Code session）有 Docker 權限，但 pr-gate.sh 目前無法讓主線程在 dispatch 前後執行 repo-specific 操作。

**Why**: 這是「主線程有能力 X，Codex sandbox 沒有」的通用問題，不只是 Docker。若直接在 pr-gate.sh 加 `--compose-file` flag 會把 Docker 耦合進 PM 工具；正確的分層是 pm-dispatch 提供 hook 點、repo 實作內容（與 git hooks 設計哲學相同）。

**Requirement**:
1. `pr-gate.sh` 在 dispatch reviewers 前，若 `.pm-dispatch/pre-gate.sh` 存在則執行（主線程）
2. `pr-gate.sh` 在所有 reviewer sessions 完成後，若 `.pm-dispatch/post-gate.sh` 存在則執行（主線程）
3. hook 執行失敗（exit non-zero）時 gate 中止並報錯，不繼續 dispatch
4. hook 不存在時 gate 行為完全不變（backward compatible）
5. 文件說明 hook 慣例，範例：Docker Compose 啟動/停止

**Acceptance criteria**:
- [ ] `.pm-dispatch/pre-gate.sh` 存在且可執行 → gate 在 dispatch 前執行它（主線程）
- [ ] `.pm-dispatch/post-gate.sh` 存在 → gate 在所有 reviewer 完成後執行它
- [ ] pre-gate hook exit 1 → gate 中止，不 dispatch reviewer
- [ ] 兩個 hook 均不存在 → gate 行為與現行相同（無 regression）
- [ ] CONTRIBUTING.md 或 docs/ 有使用範例（Docker Compose 場景）

**See**: issue #103

## CC-207 — Windows Git Bash symlink fallback: use mklink /J in install.sh（deferred）

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

## CC-208 — Gate reviewer hallucination: document citation without verification（active）

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

## CC-210 — uninstall.sh: reject managed-root exact path as deletion target（deferred）

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

## CC-211 — multi-CLI platform architecture（deferred）

**v0.3.0 epic** (updated 2026-05-22): umbrella epic for the v0.3.0 PM-runtime restructure. The original P0–P5 ordering below is **superseded** — see [`docs/architecture/v0.3.0-synthesis.md`](../docs/architecture/v0.3.0-synthesis.md) for the M0–M5 milestone breakdown and `MILESTONES.md` v0.3.0 for ticket assignment. MCP (CC-216) and non-Claude adapters are deferred to v0.4.0.

**Problem**: pm-dispatch is currently framed as "Claude Code personal config + Codex dispatch
wrapper". As Codex CLI, Gemini CLI, OpenCode, and other AI tools mature, this framing creates
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
| `adapters/` | `adapters/claude/`, `adapters/codex/`, `adapters/gemini/`, `adapters/opencode/` | Format conversion only; each adapter translates CLI-specific calls into `pmctl` invocations |
| `mcp/` | `mcp/pm-dispatch-server` | MCP tool bridge; any MCP-capable CLI (Claude Code, OpenCode, Gemini CLI) shares one server |

**Key design rules**:
- `core/` never changes per CLI; no `~/.claude/` assumptions.
- Guard engine lives in `pmctl`; Claude hooks are one delivery path, not the definition.
- Adapters own zero business logic.
- `pmctl adapter generate <claude|codex|gemini|opencode>` produces per-CLI config from core agent definitions to prevent 4-way drift.

**Priority order**: P0 extract `core/schemas/` (lock data format across CLIs) → P1 pmctl CLI (CC-215) → P2 Claude commands call pmctl → P3 Codex adapter formalised → P4 MCP server (CC-216) → P5 Gemini/OpenCode adapters.

**Complements**: CC-059 (thin `/pm.md` script-layer), CC-215 (pmctl), CC-216 (MCP server).

**Priority**: P4 — long-term direction. Evaluate at v0.3.0 milestone planning.

## CC-212 — `make_junction_windows()` env-var path-passing standardization（deferred）

**Problem**: `make_junction_windows()` passes the source and destination paths as inline PowerShell
command-string arguments (`-Path '$win_src' -Target '$win_dst'`), but `remove_junction_windows()`
already uses `PM_DISPATCH_RM_DST` env var. Paths containing single quotes break the inline form.
Two different conventions in the same portability layer increase maintenance risk.

**Why**: Raised by critic (path quoting) and architecture-reviewer (convention inconsistency) in
gate-20260521-115634 as [medium] advise on PR #112.

**Requirement**: Replace inline PowerShell path arguments in `make_junction_windows()` with
`PM_DISPATCH_MAKE_SRC` and `PM_DISPATCH_MAKE_DST` env vars (matching the pattern already
used by `remove_junction_windows()`). Update `test_install_dir_junction_manifest_entry` fake
powershell.exe to assert both env vars.

**Complements**: CC-207 (parent), CC-213 (idempotency).

**Priority**: P3.

## CC-213 — `install_dir_junction()` Windows-aware idempotency probe（deferred）

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

**Complements**: CC-207 (parent), CC-212 (path-passing).

**Priority**: P3.

## CC-214 — platform-support.md manual uninstall command anchoring（deferred）

**Problem**: The manual uninstall warning in `docs/platform-support.md` uses `bash uninstall.sh`
without anchoring to the repo path; running it from any other working directory silently fails.

**Why**: Raised by critic in gate-20260521-115634 as [low] advise. Other examples in the same
document already use the `"${PM_DISPATCH_REPO}/uninstall.sh"` form.

**Requirement**: Replace the bare `bash uninstall.sh` in the Windows uninstall warning block with
`bash "${PM_DISPATCH_REPO}/uninstall.sh"` (one-line change).

**Priority**: P3 — tiny fix, fold into next docs PR.

## CC-215 — pmctl — core CLI entrypoint（deferred）

**Problem**: pm-dispatch has no language-agnostic runtime binary. All orchestration logic is
reached through Claude-specific hooks and commands, preventing non-Claude CLIs from accessing
the same PM capabilities without duplicating logic.

**Why**: `pmctl` as a standalone binary makes pm-dispatch a proper tool layer: Claude hooks,
Codex wrappers, and MCP server all become thin callers into one well-defined CLI interface.
Guard logic and dispatch state move from Claude-only paths into `pmctl` so any CLI without hook
support can call `pmctl guard check` or `pmctl safe-bash`.

**Requirement**:
- Implement `cli/pmctl` with subcommand interface:
  - `pmctl task create|claim|dispatch|status|review`
  - `pmctl decision add`
  - `pmctl backlog sync`
  - `pmctl trace tail`
  - `pmctl guard check --event <pre-write|pre-bash|post-task> --file/--command <val>`
  - `pmctl adapter generate <claude|codex|gemini|opencode>`
- Claude adapter: `/pm task-123` → `pmctl task dispatch task-123 --agent claude`
- Guard logic migrates from Claude-only hooks into `pmctl` so hook is just a thin caller.
- `pmctl adapter generate` produces per-CLI config from core agent definitions.

**Depends on**: CC-211 (core layer extracted first).

**Complements**: CC-211 (architecture), CC-216 (MCP server wraps pmctl).

**Priority**: P1 within CC-211 roadmap. Evaluate at v0.3.0.

## CC-216 — MCP server — pm-dispatch-server（deferred）

**v0.4.0** (updated 2026-05-22): deferred to v0.4.0 per the v0.3.0 synthesis — MCP must wrap a stable `pmctl`, never an immature one. v0.3.0 ships only `mcp/README.md` defining the tool surface as a `pmctl` interface design constraint. See [`docs/architecture/v0.3.0-synthesis.md`](../docs/architecture/v0.3.0-synthesis.md) §5.4.

**Problem**: Each AI CLI (Claude Code, OpenCode, Gemini CLI) needs separate command/hook wiring
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

## CC-217 — claude-executor background dispatch（deferred）

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

## CC-218 — spike tracking infrastructure（deferred）

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

## CC-219 — pre-milestone doc freshness gate（deferred）

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

## CC-220 — spike agent + `/spike` skill（deferred）

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

**Depends on**: CC-218 (spike type + docs/spikes/ directory must exist first).

**Complements**: CC-218 (infrastructure), CC-209 (first spike to run through the new agent).

**Priority**: P3. Implement after CC-218.

## CC-200 — Reuse debt: `scripts/lib/executor-router.sh`（deferred）

**Problem**: `/pm` and `/pr-gate` each encode codex/claude routing logic separately.
**Why**: A third consumer would turn the duplicated route logic into a maintenance cost and make executor behavior easier to drift.
**Requirement**: Extract shared codex/claude routing into `scripts/lib/executor-router.sh`, preserving existing CLI behavior for current callers.

## CC-201 — Reuse debt: `detect_executor_profile()` shim（deferred）

**Problem**: `install-hooks.sh` and `pr-gate.sh` both repeat `command -v codex` style executor-profile detection.
**Why**: Profile detection should be consistent across install and dispatch paths.
**Requirement**: Move executor-profile detection into a shared shim, likely `scripts/lib/portable.sh` or a focused executor helper, and update both consumers.

## CC-202 — Reuse debt: handover validator framework（deferred）

**Problem**: `dispatch_handover_v1` and `pr-gate-handover_v1` validators duplicate fence, metadata, and body validation structure.
**Why**: Future handover schemas should not require hand-written validation boilerplate for every shared grammar rule.
**Requirement**: Extract a reusable handover validator framework that schema-specific validators can configure.

## CC-203 — Reuse debt: `scripts/lib/test-harness.sh`（deferred）

**Problem**: Eight or more `test-*.sh` scripts each implement their own `--filter`, `--list`, `should_run()`, pass/fail counter, and scratch-dir handling.
**Why**: Test harness behavior should be consistent, and fixes to CLI test behavior should not require repeated edits across scripts.
**Requirement**: Create a source-able `scripts/lib/test-harness.sh` and migrate test scripts incrementally.

## CC-204 — Reuse debt: hook framework（deferred）

**Problem**: pm-write-guard, codex-bash-guard, codex-write-guard, and routing-log hooks repeat stdin JSON parsing, decision matrix, and audit-log structure.
**Why**: The hook layer has enough shared behavior that copy-paste-modify makes policy and logging drift likely.
**Requirement**: Extract a shared hook framework for stdin JSON parsing, policy decisions, and audit logging, while preserving hook-specific policy rules.

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

## CC-224 — shared hook-profile inventory: doctor.sh ↔ install-hooks.sh（deferred）

**Problem**: `scripts/doctor.sh` owns a second hardcoded minimal/full hook membership model (around line 240) that mirrors the one in `scripts/install-hooks.sh`. When a new hook is added or a profile boundary changes, it is easy to update one file and miss the other — this is a silent drift path with no compile-time check.

**Why**: Raised by critic and architecture-reviewer as [medium] advise in PR-gate `gate-20260522-100348`. The duplication became structurally significant once `--profile minimal|full|auto` was added and both files enumerate hooks by profile.

**Requirement**: Extract the managed hook list and profile classification into a shared shell helper (e.g. `scripts/hook-profile.sh`) sourced by both `doctor.sh` and `install-hooks.sh`. Alternatively, add a parity test (e.g. `test-hook-profile-parity.sh`) that parses both files and asserts the hook sets are identical for each profile tier.

**Dependencies**: CC-058（profile flag already landed）

**Priority**: P3 — maintainability; current duplication is limited to two well-known files.

**Cross-link**: CC-223（boundary fix; pair these if tackling doctor.sh again）, CC-204（hook/profile reuse debt）

## CC-225 — claude-executor result observability（deferred）

**Problem**: `claude-executor` task output is written to session-scoped `/tmp/` paths that are not tracked in the repo, cannot be reviewed across sessions, and are not recoverable after the shell exits. The main thread has no durable record of brief path, result summary, or exit status for completed executor tasks.

**Why**: Raised from gate-20260522-145444 (CC-058 gating). The observability gap was observed during the CC-058 session: claude-executor tasks ran but their outputs were opaque to the main thread with no git-diffable artifact. This blocks the CC-211/CC-216 MCP architecture extraction.

**Requirement**: After a claude-executor task completes, the main thread should write the brief path, result summary, and exit status to a repo-tracked directory (format consistent with `.gate-results/`). This serves as the prerequisite for the MCP task abstraction in CC-211/CC-216.

**Dependencies**: CC-211 (MCP architecture design), CC-058 (doctor.sh merge — prerequisite)

**Priority**: P3 — design prerequisite; not blocking current workflows.

**Cross-link**: CC-211 (MCP architecture), CC-216 (task abstraction)

## CC-226 — lint-frontmatter: extract shared dq-escape validation helper（deferred）

**Problem**: `scripts/lint-frontmatter.sh` repeats the same double-quoted escape whitelist regex and adjacent-quoted-scalar check across 4 separate collection branches (key-level flow seq, key-level flow mapping, list-item flow seq, list-item flow mapping). A future grammar fix applied to one branch can be missed in the others, causing a silent parity gap.

**Why**: Raised as medium advisory by critic + architecture-reviewer in gate-20260522-171123 (CC-058 gating). The current branch coverage is green and covers all 4 paths, so the risk is low now, but will grow as the grammar is extended.

**Requirement**: Extract the dq escape whitelist check, the adjacent-quoted-scalar check, and the empty-entry check into a shared bash helper or predicate function. Ensure a parity test (or single call site) prevents future per-branch divergence.

**Dependencies**: CC-058 (lint-frontmatter rewrite — merged)

**Priority**: P3 — maintainability; not blocking current workflows.

**Cross-link**: CC-224 (hook-profile inventory duplication — same class of debt), CC-227 (module extraction — can be done together)

## CC-227 — lint-frontmatter: extract YAML subset parser into lib/yaml-frontmatter.sh（deferred）

**Problem**: `scripts/lint-frontmatter.sh` mixes CLI parsing, frontmatter boundary detection, and a ~150-line hand-rolled YAML subset parser in a single file. The parser logic (`check_frontmatter()`) has no stable call boundary, making it hard to reuse from other scripts (e.g., `doctor.sh` currently forks a subprocess to call the linter), hard to test in isolation, and hard to extend without touching the CLI script.

**Why**: User feedback after CC-058 gating: splitting the YAML validation into a dedicated library file would improve long-term maintainability. Relates to the CC-226 shared-helper advisory — if both are done together, the grammar contract becomes a first-class lib with clear ownership.

**Requirement**:
1. Move `check_frontmatter()` and all YAML-subset validation helpers into `scripts/lib/yaml-frontmatter.sh`
2. `scripts/lint-frontmatter.sh` becomes a thin CLI wrapper that sources the lib
3. `doctor.sh` can optionally source the lib directly instead of fork-execing the linter
4. Tests can source the lib and call `check_frontmatter()` directly, reducing tmp-file overhead
5. If done together with CC-226: shared dq-escape/adjacent-quote/empty-entry helpers live in the lib

**Dependencies**: CC-058 (lint-frontmatter rewrite — merged), CC-226 (shared helpers — can be combined)

**Priority**: P3 — maintainability; not blocking current workflows.

**Cross-link**: CC-226 (shared validation helpers — recommend combining), CC-224 (hook-profile lib extraction — same pattern)

**Cross-link**: CC-211 (MCP architecture), CC-216 (task abstraction)

## CC-228 — BACKLOG validator-debt cleanup（deferred）

**Problem**: `pm/scripts/validate.sh` exits 1 on `main` with ~31 pre-existing E-codes, none introduced by recent PRs. An always-red validator provides no signal — a real new error would be invisible.

**Why**: The debt accumulated as the schema tightened (CC-030 / CC-052 / CC-067) faster than existing rows were migrated.

**Requirement** (resolve per error class, dry-run `validate.sh` after each, target exit 0):
1. `E-INDEX-MISMATCH` — CC-104d/e/f/g/j/k/m/r/s have index rows but no body section. Add stub sections or drop the index rows (they were Windows-dogfood sub-items, mostly folded into shipped PRs).
2. `E-AREA-ENUM` — CC-052/060/104v/203/204 etc. use slash-combined or non-enum areas (`arch`, `config`, `schema`, `ops`, `hook`). Widen the `area` enum (adding `arch`/`ops` is additive and fixes the most rows) or rewrite the rows.
3. `E-REFS-PREFIX` — CC-059/060/061/064/066 carry bare `CC-NNN` refs; the Refs column requires a prefix. Move ticket cross-links into the section body.

**Priority**: P2 — not blocking, but should land before v0.3.0 M1 tightens the schema further.

**Cross-link**: surfaced during CC-222 close-out 2026-05-22.

## CC-229 — core/schema: task/run/event/review/decision schemas（deferred）

**Problem**: pm-dispatch has no state model — tasks are `BACKLOG.md` rows, runs are trace files, reviews are `.gate-results/` files, and nothing links them.

**Why**: The v0.3.0 PM runtime needs a canonical data contract before any runtime code can be written (see [`docs/architecture/v0.3.0-synthesis.md`](../docs/architecture/v0.3.0-synthesis.md) §5.2).

**Requirement**:
- Create `core/schema/{task,run,event,review,decision}.schema.json` — JSON Schema for the five first-class entities and their lifecycles.
- Re-home `pm/schema.md` (the BACKLOG grammar) under `core/`.
- Ships with no behavior depending on it (de-risking); schema locked at end of M1.

**Milestone**: v0.3.0 M1.

**Priority**: P1 — every downstream layer references the schema.

**Cross-link**: CC-211 (epic), CC-230 (state store consumes these schemas).

## CC-230 — state store: ~/.claude/.pm/state/（deferred）

**Problem**: Run/event state is scattered — `.agent-trace/*.jsonl` plus a machine-written Markdown table in `routing_log.md` that nothing reads structurally (worst-of-both-worlds).

**Why**: A single state store with one writer makes the substrate trustworthy and queryable.

**Requirement**:
- Build `~/.claude/.pm/state/` — single-writer JSONL (`runs.jsonl`, `events.jsonl`) + a small index, guarded by `serialize_with_lock()` (CC-104p).
- Migrate the `routing_log.md` auto-block to `runs.jsonl` (the one budgeted migration; kills the machine-written-Markdown-table anti-pattern).
- `pmctl` is the only writer; no hook/command/agent writes state files directly.

**Milestone**: v0.3.0 M1.

**Priority**: P1 — the runtime mutates this store.

**Cross-link**: CC-229 (schemas), CC-215 (pmctl writes here).

## CC-231 — core/policy extraction（deferred）

**Problem**: Reviewer-gate policy, the executor enum, and the dispatch state machine live as prose scattered across `agents/project-pm.md` and command files — no single source.

**Why**: `core/` should own these as declarative, behavior-free definitions consumed by the runtime.

**Requirement**: Extract `core/policy/` — `reviewer-policy` (critic/arch/security/risk/qa gate matrix), `executor-enum` (closed: codex, claude), `dispatch-states` (the dispatch state machine). Pure definitions, zero behavior.

**Milestone**: v0.3.0 M1.

**Priority**: P2.

**Cross-link**: CC-211 (epic), CC-204 (guard engine consumes policy).

## CC-232 — context-pack schema + context-enricher interface（deferred）

**Problem**: Brief context is hand-listed (`files:`); incomplete lists cost the executor exploration tokens. There is no abstraction for "assembled pre-dispatch context".

**Why**: A `context-pack` decouples context enrichment from any one executor or source; it serves spike, reuse/refactor, and (later) MCP resources alike.

**Requirement**: Define `core/schema/context-pack.schema.json` (files / symbols / memories / risks, each with a source + confidence) + the context-enricher interface (pluggable sources). Consumed via `pmctl context build`.

**Milestone**: v0.3.0 M1.

**Priority**: P2.

**Cross-link**: CC-237 (baseline sources), CC-209 (codegraph as a source — spiked).

## CC-233 — scripts/test-layer-boundaries.sh（deferred）

**Problem**: The four-layer architecture is only a discipline; nothing enforces the dependency direction.

**Why**: One cheap structural test prevents slow architecture drift (the cost the layering exists to avoid).

**Requirement**: Add `scripts/test-layer-boundaries.sh` — grep `core/` for forbidden tokens (CLI product names, `~/.claude`, bash invocations), grep `adapters/` for state-mutation calls. Wire into CI.

**Milestone**: v0.3.0 M3.

**Priority**: P3.

**Cross-link**: CC-211 (epic).

## CC-234 — memory v2: event-derived distillation（deferred）

**Problem**: The memory system is chat-derived — `episodes.jsonl` summarizes conversations. The durable signal is the action stream (tool calls, decisions, gate verdicts).

**Why**: Memori's insight — memory from what agents *do*, not just what they say. The Event log (CC-230) is that action stream.

**Requirement**: Point `/mem-distill` at `events.jsonl` as an input alongside `episodes.jsonl`. The existing four-tier card system is unchanged; this gives the `event` tier a schema. No separate memory engine.

**Milestone**: v0.3.0 M4.

**Priority**: P2.

**Cross-link**: CC-230 (events.jsonl), CC-229 (event schema).

## CC-235 — Task lifecycle gate: spec→design→plan enforcement（deferred）

**Problem**: The spec→design→plan discipline (`/pre-impl`, the `qa_checklist` rule) is advisory prose in `agents/project-pm.md` — not enforced.

**Why**: Superpowers' principle: clarify/spec/design/plan before implementing. Making it a state-machine gate moves it from prose to structural enforcement.

**Requirement**: `pmctl` enforces that a Task of ≥3 behavioral units cannot transition `claimed → in-progress` without a design artifact. The threshold already exists in `project-pm.md`.

**Milestone**: v0.3.0 M4.

**Priority**: P2.

**Cross-link**: CC-229 (Task schema/lifecycle), CC-022 (`/pre-impl`).

## CC-236 — pmctl report: away-from-keyboard state roll-up（someday）

**Deprioritized 2026-05-22**: the original "morning report" framing assumed unattended / overnight agent runs. In actual practice the maintainer does not run agents away from the computer, so a time-gap roll-up has low current need. Demoted from v0.3.0 M4 to `🟢 someday`. On-demand state queries are already part of the `pmctl` surface (CC-215); this ticket is specifically the *periodic / since-you-were-away* report.

**Problem** (conditional): if unattended or overnight dispatch ever becomes part of the workflow, there is no single command to see what happened while away.

**Why**: A read-only roll-up over the state substrate (CC-230) would answer that without hand-reconstruction. The idea is sound; the need is gated on a workflow change.

**Requirement** (if revived): `pmctl report` — open tasks, blockers, last gate verdict per active task, runs since last invocation. Read-only query over the CC-230 store.

**Revisit when**: the workflow includes overnight / away-from-keyboard agent runs.

**Cross-link**: CC-230 (state store), CC-211 (epic); AI Night Shift mapping — docs/architecture/v0.3.0-synthesis.md §5.3.

## CC-237 — context-enricher baseline: rg/git/memory sources（deferred）

**Problem**: The `context-pack` abstraction (CC-232) needs concrete sources before it is useful.

**Why**: A baseline of always-available sources (no external dependency) proves the abstraction and is the comparison point for the codegraph spike (CC-209).

**Requirement**: Implement context-enricher sources — `rg`, `git ls-files`, `git diff`, memory search — producing a `context-pack` before dispatch. `pmctl context build`. codegraph is NOT a baseline source; it is evaluated separately (CC-209).

**Milestone**: v0.3.0 M4.

**Priority**: P3.

**Cross-link**: CC-232 (schema/interface), CC-209 (codegraph spike).
