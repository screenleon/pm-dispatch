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
| CC-013 | ✅ closed 2026-05-18 | `/caveman` token 壓縮 skill：lite/full/ultra 模式，長 session 降低 token 消耗 Removed in CC-265. | ux | 2026-05-14 | pr:#82 | — | — |
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
| CC-025b | ✅ closed 2026-05-18 | `/skill-refine` M1+M2 advisory follow-ups：M1 usage-guard tests + `CLAUDE_MEMORY_DIR` 環境契約文件化/repo-default fallback | ux/memory | 2026-05-17 | pr:#83 | — | oss |
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
| CC-047 | ✅ closed 2026-05-17 | `scripts/codex-dispatch.sh` model alias mapping：`--model codex-spark` 透傳給 codex CLI 後得到 400 invalid_request_error（API 只認 `gpt-5.3-codex-spark`），需要 alias 表把短名映射到 codex CLI 接受的全名 + reasoning effort | ops | 2026-05-17 | pr:#69 | — | — |
| CC-100 | ✅ closed 2026-05-17 | **[CC-OSS Phase 1]** Sanitize personal paths + OSS-baseline docs：拔 `/home/<user>` 硬編碼 → `${PM_DISPATCH_REPO}` env contract；新增 `CONTRIBUTING.md` + `CODE_OF_CONDUCT.md`；LICENSE 已存在 | process/docs | 2026-05-17 | pr:#71 | — | oss |
| CC-101 | ✅ closed 2026-05-17 | **[CC-OSS Phase 2 spike]** Executor-contract schema + adapter design：brief schema 加 `executor:` 欄位；`docs/executor-contract.md`；CC-040 schema rename 延伸 | arch/process | 2026-05-17 | pr:#72 | — | oss |
| CC-102 | ✅ closed 2026-05-17 | **[CC-OSS Phase 2 impl]** `claude-executor` agent + `install.sh --profile minimal\|full`：minimal profile 跳過 codex hooks，預設 executor=claude；既有 codex flow 全 regression pass | arch/install | 2026-05-17 | pr:#73 | — | oss |
| CC-102b | ✅ closed 2026-05-17 | CC-102 PR-gate advisory follow-ups：(a) 直接 e2e regression test 覆蓋 `install.sh --profile minimal\|full` + auto-detect；(b) install-hooks.sh minimal profile downgrade — fold-in 進 CC-102 同 PR（qa-tester r2 升 block；都已修） | ops/install | 2026-05-17 | pr:#73 | — | oss |
| CC-103 | ✅ closed 2026-05-17 | **[CC-OSS Phase 3]** `scripts/lib/portable.sh` shim（`realpath_m` / `safe_tmpdir` / `mkdir_lock` / `file_size_bytes`）+ `docs/platform-support.md`；改寫 3 個 hook 用 shim；`install-hooks.sh` 偵測 platform 跳過 Linux-only hook | ops/portability | 2026-05-17 | pr:#74 | — | oss |
| CC-103b | ✅ closed 2026-05-17 | CC-103 follow-up: `/pr-gate` executor split — `--executor codex\|claude\|auto`; mirror CC-102 `/pm` route split so minimal-profile users can run the gate | arch/install | 2026-05-17 | pr:#75 | — | oss |
| CC-104 | ✅ closed 2026-05-17 | **[CC-OSS Phase 4]** Onboarding docs batch：README intro rewrite + `docs/GETTING_STARTED.md` + `docs/memory-system.md` + 7 個 `commands/*.md` 補 what/when/example 三段（pm.md / pr-gate.md 已含 Route A/B 故跳過） | docs/ux | 2026-05-17 | pr:#76 | — | oss |
| CC-105 | ✅ closed 2026-05-17 | **[CC-OSS Phase 5]** v0.1.0 release：`CHANGELOG.md` [0.1.0] section + BACKLOG status flip + private→public visibility + tag v0.1.0 + GitHub release + main branch protection（require linear history） | process/release | 2026-05-17 | pr:#77 | — | oss |
| CC-104b | ✅ closed 2026-05-17 | **[Windows dogfood r1 fixes]** install-hooks jq error → platform-aware install hints | ops/install | 2026-05-17 | pr:#79 | P2 | oss |
| CC-104c | ✅ closed 2026-05-17 | **[Windows dogfood r1 fixes]** install.sh `link()` → `link_or_copy()`: try `ln -s` + `[[ -L ]]` post-check (catches Git Bash silent-copy disguise); fall back to `cp -p` + warn-to-stderr; manifest at `~/.claude/.pm-dispatch/install-manifest.json` (manifest_version=1, atomic mktemp+mv write); sha256 idempotency for copy-mode entries; FAKE_SYMLINK_UNSUPPORTED / FAKE_SYMLINK_BOGUS test shims. OUT: `--update` (CC-104d), `--uninstall` (CC-104e), mkdir_lock (CC-104k), Experimental→Supported doc flip (separate doc PR after CC-104c + CC-104k both merge) | arch/install | 2026-05-18 | pr:#89 | — | oss |
| CC-104d | 🟡 deferred | **[Windows dogfood r1 findings]** Hardcoded `$HOME/github` read root default in `hook-codex-bash-guard.sh:54`; `CLAUDE_HOOK_CODEX_READ_ROOTS` env override exists but default is wrong on Windows where repos live under `~/Documents/github/` or arbitrary paths. Should be derived from `PM_DISPATCH_REPO` parent or removed | ops | 2026-05-17 | — | — | oss |
| CC-104e | 🟡 deferred | **[Windows dogfood r1 findings]** WSL ↔ Windows `~/.claude/projects/<project-id>/memory/` divergence: project ID is path-sanitization of working dir. Same repo cloned at `~/github/pm-dispatch` (WSL) and `C:\Users\<user>\Documents\github\pm-dispatch` (Windows) produces different IDs → memory partitioned. Harness-level (Claude Code) issue; document workaround (symlink, or PM_DISPATCH_PROJECT_ID override) | ux/memory | 2026-05-17 | — | — | oss |
| CC-104f | 🟡 deferred | **[Windows dogfood r1 findings]** jq is hard-dep for hooks layer. Options: vendor static `gojq` binary (3 MB × 3 platforms), or expose `--no-hooks` install mode that skips hook wiring entirely (lightweight install for jq-less users). Latter preferred — keeps "no auto-install of system pkgs" principle | arch/install | 2026-05-17 | — | — | oss |
| CC-104g | ⚠️ partial 2026-05-17 | **[Windows dogfood r1 fixes]** portable.sh test fixes: symlink test SKIP + detect_platform host_native PASS on Windows ✅; mkdir_lock FIFO sync ✅ but underlying `mkdir` on Git Bash still allows second concurrent acquire — real Windows portability bug, NOT test sync issue. See CC-104k | ops/test | 2026-05-17 | pr:#80 | — | oss |
| CC-104h | ✅ closed 2026-05-17 | **[Windows dogfood r1 fixes]** `handover-validate.sh` brief_file validator now accepts paths under `/tmp` + `$TMPDIR / $TEMP / $TMP` (POSIX or MSYS forward-slash form). Windows backslash paths still rejected at metadata-metachar level — documented limitation | ops/test | 2026-05-17 | pr:#80 | — | oss |
| CC-104i | ✅ closed 2026-05-17 | **[Windows dogfood r1 fixes]** `.gitattributes` forces LF — verified `file install.sh ... portable.sh` no CRLF after checkout on Windows | ops | 2026-05-17 | pr:#80 | — | oss |
| CC-104j | 🟡 deferred | **[Windows dogfood r1 r2 finding]** `test-dispatch-handover.sh:674-685` `brief_file_symlink_rejects_case` uses `ln -s` for fixture setup; on Git Bash falls back to copy → validator treats as regular file → test fails. Same skip-if-not-symlink pattern as CC-104g case (a) — `[[ -L "$link" ]]` precondition → SKIP | ops/test | 2026-05-17 | — | — | oss |
| CC-104k | 🟡 deferred | **[UNC/9P filesystem caveat — re-scoped from `mkdir_lock` atomicity claim]** Race test on Windows Git Bash 5.2.15 (Windows 11) confirmed `mkdir` IS atomic on **local NTFS** (`C:\...\Temp` — Git Bash's `/tmp`); 20/20 rounds × 50 parallel = exactly 1 winner each. Original CC-037 regression failure on Windows was specifically when running pm-dispatch from `\\\\wsl.localhost\\Ubuntu\\...` (9P UNC bridging WSL FS to Windows) — 9P protocol or its Windows client does not preserve mkdir atomicity. Not a code bug; install-on-local-disk caveat. See **CC-104r** for the install-time UNC path detect / docs warn follow-up. If a third filesystem ever surfaces `mkdir`-non-atomic, revisit with `set -C` + `: > file` primitive (already race-tested as atomic on tested FS) | ops/portability | 2026-05-18 | — | — | oss |
| CC-104l | ✅ closed 2026-05-21 | **[Windows dogfood r1 r2 finding]** jq install hint visibility: install-hooks.sh shows the platform-aware hint per CC-104b (#79), BUT install.sh preflight runs `test-hooks` FIRST which fails with bare "jq missing" repeated 200+ times before hitting install-hooks.sh. Add (a) jq prerequisite check at top of install.sh BEFORE preflight (one-line hint), (b) jq install command at top of README "Install" section so first-time readers see it before clicking through to platform-support.md | ops/install | 2026-05-17 | pr:#116 | — | oss |
| CC-104m | 🟡 deferred | **[Platform layout — post-v0.1.0]** pm-dispatch staging dir + multi-target projection: introduce `~/.pm-dispatch/content/` as canonical view, then symlink-project to `~/.claude/` and (future) `~/.codex/` etc. Today pm-dispatch is Claude-only by virtue of where install.sh lands; this re-shapes it as a tool-agnostic content platform. Touches install.sh, manifest schema (v0 → v1 with `target` field), uninstall semantics. Decided 2026-05-18 (CC-104c scope discussion, Path Y). Open until clear Codex/Cursor/Aider integration need surfaces | arch/install | 2026-05-18 | — | — | oss |
| CC-104n | ✅ closed 2026-05-19 | **[CC-104c risk-reviewer advise]** install.sh preflight hard-fail (`--verify` block) converts optional/local validation issues into full install blockers; transient or environment-specific tooling gaps (e.g. missing optional bin) abort entire install. Pre-existing behavior surfaced by CC-104c gate. Mitigation: gate non-essential preflight checks behind a best-effort path OR add explicit `--skip-preflight=<name>` opt-out switch. **Design direction**: extract `scripts/run-all-tests.sh` as standalone test aggregator (make-check / make-install boundary); install.sh `--verify` becomes a thin wrapper around it; folds CC-104q | ops/install | 2026-05-18 | pr:#101 | P2 | oss |
| CC-104o | 🟢 superseded 2026-05-20 | **[Windows dogfood r3 finding]** Microsoft Store python3 reparse-point stub (`/c/Users/<user>/AppData/Local/Microsoft/WindowsApps/python3.exe`) returns exit 49 in non-interactive contexts → 36 preflight cases FAIL (every `inject-hook/*`, `session-hook/*`, `rl-hook/*`, `stop_*`, `mem-recall/format-validator`, `cross-cmd/*` because hook scripts internally call python3). Fix: install.sh / install-hooks.sh preflight detects the MS Store stub via `python3 -c 'pass'` exit-49 probe, hard-fail with platform-aware hint (`winget install Python.Python.3.12` + "remove WindowsApps stub from PATH or order real Python first"). Required before Windows = Supported flag flip — fork users on Windows hit this on first install. Superseded by CC-104t which eliminates python3 entirely via jq rewrite. | ops | 2026-05-18 | — | — | oss |
| CC-104p | ✅ closed 2026-05-21 | **[Windows dogfood r3 finding]** `flock` is Linux-only — Git Bash has no flock binary; `hook-routing-log.sh` directly calls flock (bypassing portable.sh abstraction) → 2 cases FAIL on Windows (`routing: rotation failure audits and skips append`, `routing: concurrent appends keep every row`). Strong dependency on **CC-104k** (mkdir_lock Git Bash atomicity) — fix should be one combined PR: (a) fix mkdir_lock atomicity per CC-104k, (b) add `scripts/lib/portable.sh::serialize_with_lock <path> <cmd>` shim that prefers `flock` when present else falls back to `mkdir_lock`, (c) rewrite hook-routing-log.sh to use shim. **Blocker** because CC-036's main-thread background dispatch makes concurrent routing-log appends real (no longer theoretical) → Windows row-loss = silent data corruption | arch/portability | 2026-05-18 | pr:#114 | — | oss |
| CC-104q | ✅ closed 2026-05-19 | **[Windows dogfood r3 finding]** test-hooks preflight runs codex-dispatch cases (`cxw: Write to existing symlink /tmp/brief-*.md → deny`, `dispatch_brief_file_reads_file`) even when codex is not on PATH → 2 cases FAIL with `codex: command not found`. `install.sh --profile minimal` skips codex hooks but preflight still tests them. Fix: test-hooks should SKIP (not FAIL) codex-* cases when `command -v codex` is false. Folds well with **CC-104n** preflight `--skip-preflight=<name>` mechanism — could land in same PR | ops/test | 2026-05-18 | — | — | oss |
| CC-104r | ⏸ deferred | **[Windows dogfood r3 finding]** `hook-tool-trace.sh` performance_budget assertion: 27990 ms actual vs 3500 ms budget on Windows native filesystem (WSL UNC path `\\wsl.localhost\...` is ~8× slower than local disk). Not a pm-dispatch bug — physical filesystem characteristic. Fix is two-part: (a) `docs/platform-support.md` warns "install on local disk, avoid cross-WSL/native FS boundaries"; (b) preflight detects UNC path → prints warning and skips budget assertion (10 lines). Polish, not blocker | docs/ops | 2026-05-18 | — | — | oss |
| CC-104s | 🟡 deferred | **[Windows dogfood r3 finding]** `hook-tool-trace.sh:195` `read_home_path_basename_only` returns `first_arg_or_skill:null` on Windows because case-glob `"$HOME"/*` uses forward slashes (`/c/Users/Lien Chen`) but harness sends `file_path` with backslashes (`C:\Users\Lien Chen\...`); both case branches miss. Fix: normalize input path via `cygpath`/string-replace (`\\` → `/`, `C:\Users\...` → `/c/Users/...`) before case-match. Polish — affects trace JSON observability only, not functionality | ops/portability | 2026-05-18 | — | — | oss |
| CC-104t | ✅ closed 2026-05-20 | **[python→jq replacement — supersedes CC-104o]** Hook scripts call `python3` in 4 places (`hook-log-claude-usage.sh` 2 heredocs; `hook-inject-memory.sh`, `hook-session-summary.sh`, `hook-save-rate-limits.sh` 1 each) for JSON/JSONL parsing + simple date arithmetic. Rewrite to use jq (already a required dep) + bash filesystem walking, eliminating python3 entirely. Pros: (a) closes 36 Windows hook FAILs caused by Microsoft Store python3 reparse-point stub (root cause, not workaround), (b) shrinks install footprint to jq-only, (c) consistent with CC-104b jq-as-canonical-dep direction, (d) no Claude Code session-restart required when PATH changes. Cons: ~250 LoC refactor across 4 hooks; date arithmetic via `jq fromdateiso8601` (1.6+) or `date -d` shim. **Required ≥4 behavioral units → `/pre-impl` mandatory.** Once landed, mark CC-104o `🟢 superseded by CC-104t` | arch/portability | 2026-05-18 | pr:#107 | P2 | oss |
| CC-104u | ✅ closed 2026-05-19 | **[Windows dogfood r4 finding]** `install.sh` `link()` semantics bug on existing-directory dst: when `dst` is already a directory (e.g. `~/.claude/.pm` is a real dir from a prior install or manual setup), `ln -s "$src" "$dst"` is interpreted as "create link inside the dir named $(basename "$src")" → produces `dst/basename(src)` (e.g. `.pm/pm`) instead of failing cleanly. CC-104c's link_or_copy inherits this from `ln`. Observed: `ln: failed to create symbolic link '/c/Users/Lien Chen/.claude/.pm/pm': File exists`. Copy fallback masked the symptom but `manifest` records a wrong dst. Fix: `link_or_copy` should `[[ -d "$dst" && ! -L "$dst" ]]` precheck → return CONFLICT (rc=2) with clear message, OR use `ln -sn` (no-dereference) consistently. Also audit `pm-schema` install block path-handling | ops/install | 2026-05-18 | pr:#100 | P2 | oss |
| CC-104v | ✅ closed 2026-05-21 | **[Windows dogfood r4 — docs]** Document copy-mode install snapshot semantics: when `link_or_copy` falls back to copy (Git Bash without dev-mode), changes to source repo do NOT propagate to install dst — user must re-run `install.sh` after any source edit. Currently surfaced only via per-file `portable: fallback copy path ... symlink post-check failed` stderr. Add a single summary banner at end of install when copy-mode entries > 0 (`N files installed via copy fallback; source edits will require re-install`). Also add section to `docs/platform-support.md` Windows page. UX, not correctness | docs/install | 2026-05-18 | pr:#116 | — | oss |
| CC-200 | ✅ closed 2026-05-28 | **[Reuse debt]** `scripts/lib/executor-router.sh` — 抽出共用 codex/claude routing logic（目前 `/pm`、`/pr-gate` 各寫一套，未來 N=3 consumer 痛點） | arch/reuse | 2026-05-17 | pr:#170 | — | reuse-debt |
| CC-201 | ✅ closed 2026-05-23 | **[Reuse debt]** `detect_executor_profile()` shim 進 `scripts/lib/portable.sh` — `install-hooks.sh` + `pr-gate.sh` 各自重複 `command -v codex` 判斷 | arch/reuse | 2026-05-17 | pr:#123 | — | reuse-debt |
| CC-202 | ✅ closed 2026-05-28 | **[Reuse debt]** handover validator framework — `dispatch_handover_v1` 與 `pr-gate-handover_v1` 共用 fence/metadata/body validator 抽象；future handover schemas 不再手刻 | arch/reuse | 2026-05-17 | pr:#170 | — | reuse-debt |
| CC-203 | ✅ closed 2026-05-24 | **[Reuse debt]** `scripts/lib/test-harness.sh` — 8+ `test-*.sh` 各寫 `--filter`/`--list`/`should_run()`/PASS-FAIL counter/scratch dir setup；source-able 共用 lib 統一。Incremental：PR #127 建 harness + 2 pilot、PR #128 遷 test-install/test-claude-executor、PR #135-#140 遷 GROUP-B 16 file（751 cases preserved）、PR #142 加 `--format`/`--fail-fast` options、PR #152 (CC-249 PR-B.2 v2) 完成 assert_* migration。22/23 test-*.sh 已上 harness；剩 test-run-all-tests.sh (orchestrator) per [[feedback_test_migration_format_preservation]] 評估後 out-of-scope；test-test-harness/test-hooks 的 assert_* 殘餘走 CC-256。 | ops/test | 2026-05-17 | pr:#127,pr:#128,pr:#135,pr:#136,pr:#137,pr:#138,pr:#139,pr:#140,pr:#142,pr:#152 | P2 | reuse-debt |
| CC-204 | ✅ closed 2026-05-28 | **[Reuse debt]** hook framework — pm-write-guard/codex-bash-guard/codex-write-guard/routing-log 共通 stdin-json-parse → decision-matrix → audit-log 結構；目前 copy-paste-modify | arch/reuse | 2026-05-17 | pr:#172 | — | reuse-debt |
| CC-205 | ⏸ deferred | `/pm` dual-executor planning: `--executor auto/codex/claude` flag（與 pr-gate 介面對齊）+ `dispatch_handover_v1` 加 `executor` 欄位；加 `--parallel-plan` mode — PM 偵測 arch/multi-subsystem/first-design 特徵時，在 dispatch 前暫停並詢問用戶是否啟用；確認後 codex 與 claude 各自獨立規劃，current model 合成一份 best-of 計劃輸出；`/pm --parallel-plan` flag 可跳過確認步驟直接 parallel dispatch | process | 2026-05-20 | — | P2 | design |
| CC-206 | ✅ closed 2026-05-29 | **[gate lifecycle hooks + sandbox limitations guide]** `pr-gate.sh` 加入 `.pm-dispatch/pre-gate.sh` / `.pm-dispatch/post-gate.sh` hook 點，讓主線程在 dispatch 前後執行 repo-level infra 操作（Docker 啟動、DB seed 等）；新增 `docs/sandbox-limitations.md` 說明 sandbox 能力邊界與各類解法（Docker Compose pre-gate、Go `GOCACHE` 重導等）；吸收 CC-271 的文件範圍 | gate/docs | 2026-05-20 | pr:#175 | P1 | — |
| CC-207 | 🟡 deferred | **[Windows dogfood r3 finding]** `install.sh` on Git Bash (OSTYPE=msys/cygwin) falls back to copying files instead of symlinking (`ln -s` does not work); 83 files copied across agents/, commands/, scripts/, .pm — after pm-dispatch updates users must re-run `bash install.sh` to sync. Fix: detect Git Bash, use PowerShell `mklink /J` (directory junction, no admin required) for each target. | ops/portability | 2026-05-20 | — | P2 | oss |
| CC-208 | 🔵 active | **[Gate reviewer hallucination]** Gate reviewers cite non-existent docs in findings — observed: "AGENT.md §3" (does not exist). Reviewers invent plausible-sounding citations because they don't receive the real file list. Fix: (a) inject verified file index into gate brief preamble, or (b) add "do not cite unconfirmed docs" constraint to each reviewer agent definition. Recurs on ~30% of gate runs; each occurrence adds ~1–2 min manual verification overhead. | ops/process | 2026-05-20 | — | P3 | — |
| CC-209 | 🟢 someday | **[context-enrichment spike: codegraph evaluation]** Evaluate colbymchenry/codegraph (MIT, TypeScript, 18.8k★, active) as a **context-pack** source (CC-232). Phase 1 spike `docs/spikes/cc209-codegraph-phase1.md` (2026-05-24): codex returned RED on misapplied rubric; **main-thread validation amended to AMBER** — install ✓, license MIT ✓, API works ✓, BUT pm-dispatch is not codegraph's intended target (bash/markdown stack not supported). Phase 2 (benchmark) deferred until brief re-specifies target as TS/JS/Python/Go codebase. Process lessons: rubric must enumerate sandbox-block as local-env; spike brief must specify test target separately from working directory; main-thread validation mandatory for verdict-issuing spikes. | ops/token | 2026-05-21 | pr:TBD | P3 | spike |
| CC-210 | ⏸ deferred | **[uninstall blast-radius guard]** `uninstall.sh` currently allows `$HOME/.claude` itself to pass the managed-root safety guard (dst must start with managed root); a malformed or tampered copy-mode manifest entry matching the directory hash could remove the entire Claude config tree. Fix: add an explicit `[[ "$dst" == "$managed_root" ]]` rejection check before the startswith guard, so only strict descendants of the managed root are deletable. Raised by risk-reviewer in PR #110 gate as [medium] advisory. | ops | 2026-05-21 | pr:#110 | P3 | hygiene |
| CC-211 | ⏸ deferred | **[v0.3.0 architecture epic]** Restructure pm-dispatch into a schema-first / state-first / adapter-thin PM runtime — four layers: `core/` (data + policy) → `runtime/` (`pmctl` spine) → `adapters/` (delivery) → `mcp/` (bridge, v0.4.0). Absorbs Multica / Memori / Superpowers / AI Night Shift concepts into one state substrate. Broken into milestones M0–M5 — see docs/architecture/v0.3.0-synthesis.md and MILESTONES.md v0.3.0. Umbrella epic for CC-229..CC-237 + existing CC-059/060/061/200-204/215/217-220. | arch/portability | 2026-05-21 | — | P1 | design |
| CC-215 | 🔵 active | **[pmctl — core CLI entrypoint]** Implement `cli/pmctl` as the language-agnostic runtime for pm-dispatch. Interface: `pmctl task create/claim/dispatch/status/review`, `pmctl decision add`, `pmctl backlog sync`, `pmctl trace tail`, `pmctl guard check --event <pre-write\|pre-bash\|post-task> --file/--command <val>`, `pmctl adapter generate <claude\|codex\|antigravity\|opencode>`. AI CLI adapters become thin wrappers: Claude `/pm task-123` → `pmctl task dispatch task-123 --agent claude`; Codex equivalent calls the same binary. Guard logic moves from Claude-only hooks into pmctl so any CLI without hook support can call `pmctl guard check` from a command wrapper or `pmctl safe-bash "cmd"`. Adapter generator (`pmctl adapter generate`) produces per-CLI config from core agent definitions — prevents 4-way drift. Depends on CC-211. | arch/portability | 2026-05-21 | — | — | design |
| CC-216 | ⏸ deferred | **[MCP server — pm-dispatch-server]** **Deferred to v0.4.0** — v0.3.0 ships only `mcp/README.md` (the intended tool surface, as a `pmctl` interface design constraint); the server is built once `pmctl` is stable. Implement `mcp/pm-dispatch-server` exposing pm-dispatch operations as MCP tools: pm_list_tasks, pm_read_task, pm_create_task, pm_update_status, pm_add_decision, pm_request_review, pm_dispatch_to_agent, pm_read_trace, pm_guard_check. Enables Claude Code, OpenCode, Antigravity CLI, and any future MCP-capable AI tool to share one PM system without per-tool command wiring. MCP becomes the universal bridge; adapters handle only auth / config / format differences. Implementation path: thin Node.js or Python wrapper over pmctl subprocesses (avoids duplicating logic), or native bash MCP server once spec stabilises. Depends on CC-211, CC-215 (pmctl stable before wrapping). | arch/portability | 2026-05-21 | — | — | design |
| CC-217 | ✅ closed 2026-05-23 | **[claude-executor background dispatch]** `Agent(subagent_type:claude-executor)` calls in `/pm` Route B and `/pr-gate` Route B currently block the main thread (missing `run_in_background:true`), inconsistent with the codex-executor pattern. Fix: add `run_in_background:true` to all claude-executor dispatch sites in commands and gate scripts; update completion handling to receive the async notification rather than blocking inline. | DX/gate | 2026-05-21 | pr:#124 | P2 | oss |
| CC-218 | ✅ closed 2026-05-23 | **[spike tracking infrastructure]** Add `spike` as a valid epic type in `pm/scripts/validate.sh`. Define spike body structure: `Investigation scope` / `Done-when` criteria / `Result log` pointer to `docs/spikes/CC-NNN.md`. Create `docs/spikes/` directory with README describing format. Convert CC-209 epic from `design` → `spike`. Spike results must be committed to the repo — ephemeral findings are treated as a gap. | process | 2026-05-21 | pr:#125 | P2 | design |
| CC-219 | ✅ closed 2026-05-23 | **[pre-milestone doc freshness gate]** Before each milestone release, verify docs are current: README, MILESTONES.md, BACKLOG.md (open tickets with TBD refs), `docs/` directory. Implement as a `scripts/check-docs-freshness.sh` checklist that prints stale indicators and exits non-zero if blocking gaps exist. Should run as part of the milestone closure checklist. | process/gate | 2026-05-21 | pr:#129 | P3 | hygiene |
| CC-220 | ⏸ deferred | **[spike agent + `/spike` skill]** Implement `agents/spike.md` and `commands/spike.md`. Spike agent is a **planner** (like `project-pm`): reads a BACKLOG spike ticket, plans 2–3 investigation angles, returns a `spike_plan` block; the **main thread** fans out one Agent per angle (subagents cannot spawn subagents); the spike agent is re-invoked to synthesise findings into `docs/spikes/CC-NNN.md` and update the `Result log`. Modeled on `/pr-gate`'s reviewer fan-out. v0.3.0 M5. Depends on CC-218. | process/DX | 2026-05-21 | — | P3 | design |
| CC-221 | ✅ closed 2026-05-21 | **[copy-mode refresh semantics]** `link_or_copy` idempotency check compares dst sha256 against manifest (old src sha), so re-running `install.sh` does NOT refresh a copied file whose source changed — it matches the stale copy against the old manifest sha and returns ok. Fix: compare `sha256(src)` vs `sha256(dst)` directly; if different and mode=copy, re-copy and update manifest. Surfaced during CC-104v gate review; current behaviour documented as uninstall+reinstall workaround. | ops | 2026-05-21 | pr:#117 | P3 | oss |
| CC-212 | ⏸ deferred | **[CC-207 advise follow-up]** `make_junction_windows()` 仍用 inline PowerShell 字串傳路徑（`-Path '$win_src' -Target '$win_dst'`），但 `remove_junction_windows()` 已改用 `PM_DISPATCH_RM_DST` env var；兩者路徑傳遞慣例不一致，且 inline 字串在路徑含單引號時會壞掉。修正：改用 `PM_DISPATCH_MAKE_SRC` / `PM_DISPATCH_MAKE_DST` env var 傳入，統一 PowerShell 邊界慣例。Raised by critic + architecture-reviewer in gate-20260521-115634 as [medium] advise. | ops/portability | 2026-05-21 | pr:#112 | P3 | oss |
| CC-213 | ⏸ deferred | **[CC-207 advise follow-up]** `install_dir_junction()` 的 idempotency 邏輯用 Bash `[[ -L "$dest_dir" ]]` + `readlink` 判斷已安裝 junction，但 PowerShell 建立的 Windows directory junction 在 Git Bash 下不一定呈現為 `-L`；重新執行 `bash install.sh` 可能把 junction 目錄誤認為真實目錄而 fallback 到 per-file copy 並覆蓋 manifest。修正：加 Windows-aware junction probe（讀 manifest `mode` 欄位作 idempotency 判斷，或 `powershell.exe [System.IO.File]::GetAttributes`）。Raised by critic + qa-tester in gate-20260521-115634 as [medium]. | ops/portability | 2026-05-21 | pr:#112 | P3 | oss |
| CC-214 | ⏸ deferred | **[CC-207 advise follow-up]** `docs/platform-support.md` 手動 uninstall 說明使用裸 `bash uninstall.sh`，在非 repo-root 工作目錄下執行會找不到腳本；應改為 `bash "${PM_DISPATCH_REPO}/uninstall.sh"` 形式（與文件其他範例一致）。Raised by critic in gate-20260521-115634 as [low] advise. | ops/DX | 2026-05-21 | pr:#112 | P3 | oss |
| CC-222 | ✅ closed 2026-05-22 | **[v0.2.0 release prep]** Close the v0.2.0 milestone: confirm all Planned tickets ✅, Windows Git Bash smoke-test pass, write CHANGELOG.md [0.2.0] section, update MILESTONES.md (close v0.2.0), docs freshness sweep (doctor.sh 記錄於 GETTING_STARTED + platform-support), BACKLOG status flip, git tag v0.2.0 + GitHub Release. | process/release | 2026-05-22 | pr:#120 | P2 | oss |
| CC-225 | ⏸ deferred | **[claude-executor result observability]** `claude-executor` task output 寫入 session-scoped `/tmp/` 路徑，不進 REPO、不可跨 session 回溯，且無法 git diff 追蹤執行歷史。設計目標：主線程在 claude-executor 完成後把 brief 路徑、result 摘要、exit status 寫入 REPO 固定目錄（格式與 `.gate-results/` 一致），作為 CC-211 / CC-216 MCP 架構抽離的前提。sub-concern of CC-211. | ops | 2026-05-22 | — | P3 | design |
| CC-226 | ⏸ deferred | **[lint-frontmatter: extract shared dq-escape validation helper]** `check_frontmatter()` 內有 4 個 collection branch 各自重複相同的 dq escape whitelist regex、adjacent-quote check、empty-entry check，未來修改一個 branch 容易遺漏其他三個，造成 parity gap。建議抽取成 shared bash helper，或以 parity test 確保 4 個 branch 永遠同步。Raised as [medium] advisory in gate-20260522-171123. | arch/reuse | 2026-05-22 | pr:#119 | P3 | oss |
| CC-227 | ⏸ deferred | **[lint-frontmatter: extract YAML subset parser into lib/yaml-frontmatter.sh]** `lint-frontmatter.sh` 同時包含 CLI 解析、frontmatter 邊界偵測、~150 行 YAML subset parser，三個職責混在同一檔案。建議將 `check_frontmatter()` 搬到 `scripts/lib/yaml-frontmatter.sh`，讓 `lint-frontmatter.sh` 成為薄 CLI 包裝，`doctor.sh` 可 source lib 取代 fork subprocess，與 CC-226 建議合併進行。User feedback after CC-058 gating. | arch/reuse | 2026-05-22 | pr:#119 | P3 | oss |
| CC-228 | ⏸ deferred | **[BACKLOG validator-debt cleanup]** `pm/scripts/validate.sh` exits 1 on `main` with ~31 pre-existing E-codes: E-INDEX-MISMATCH (CC-104d/e/f/g/j/k/m/r/s in index but no body section), E-AREA-ENUM (slash-combined / non-enum areas e.g. `arch`/`config`/`schema` on CC-052/060/104v/203/204), E-REFS-PREFIX (bare `CC-NNN` refs on CC-059/060/061/064/066). Resolve per class: add missing sections or drop index rows; widen the area enum (e.g. add `arch`) or rewrite rows; fix ref prefixes. Surfaced during CC-222 close-out. | process | 2026-05-22 | roadmap:CC-277 | P2 | hygiene |
| CC-229 | ✅ closed 2026-05-25 | **[v0.3.0 M1: core schemas]** Create `core/schema/{task,run,event,review,decision}.schema.json` — the five first-class PM-runtime entities (docs/architecture/v0.3.0-synthesis.md §5.2). Re-home `pm/schema.md` (BACKLOG grammar) under `core/`. Ships no behavior change; schema locked at end of M1. **Spike phase landed via PR #156** (`docs/spikes/CC-229-substrate-{scope,claude,codex,synthesis}.md`); Q2/Q7/Q8 resolved 2026-05-24 (per-project partitioning / dual-write routing_log / `schema_version` field-only). Schema-only impl PR ready to author once PR #156 merges. | process | 2026-05-24 | pr:#156,pr:#157 | — | design |
| CC-230 | ✅ closed 2026-05-25 | **[v0.3.0 M1: state store]** Build the `~/.local/share/pm-dispatch/state/` runtime state store — single-writer JSONL (`runs.jsonl`, `events.jsonl`) + index, guarded by `serialize_with_lock()`. Migrate the machine-written `routing_log.md` auto-block to `runs.jsonl` (kills the machine-written-Markdown-table anti-pattern). `pmctl` is the only writer. | process | 2026-05-22 | pr:#159 | P1 | design |
| CC-231 | ✅ closed 2026-05-25 | **[v0.3.0 M1: core policy extraction]** Extract `core/policy/` declarative tables — reviewer-policy (the gate matrix now prose-only in `agents/project-pm.md`), executor-enum (closed: codex/claude), dispatch-states (the dispatch state machine). Pure definitions, zero behavior. | process | 2026-05-22 | pr:#157 | — | design |
| CC-232 | ✅ closed 2026-05-25 | **[v0.3.0 M1: context-pack schema]** Define `core/schema/context-pack.schema.json` + the context-enricher interface — a pluggable pre-dispatch context bundle (files/symbols/memories/risks) assembled from sources. Decouples context enrichment from `codex-dispatch.sh`; consumed via `pmctl context build`. | process | 2026-05-22 | pr:#157 | — | design |
| CC-233 | ⏸ deferred | **[v0.3.0 M3: layer-boundary test]** Add `scripts/test-layer-boundaries.sh` enforcing the four-layer dependency discipline — grep `core/` for forbidden tokens (CLI names, `~/.claude`, bash), grep `adapters/` for state-mutation calls. Cheap structural guard against architecture drift. | test | 2026-05-22 | — | P3 | design |
| CC-234 | ⏸ deferred | **[v0.3.0 M4: memory v2 — event-derived]** Point `/mem-distill` at `events.jsonl` (the action stream) alongside `episodes.jsonl` — memory derived from what agents do (tool calls, decisions, gate verdicts), not just chat (Memori-inspired). Four-tier card system unchanged; gives the event tier a schema. | memory | 2026-05-22 | — | P2 | design |
| CC-235 | ⏸ deferred | **[v0.3.0 M4: tiered lifecycle gate]** Make the spec→design→plan discipline (today advisory in `commands/pre-impl.md` + `agents/project-pm.md`) a `pmctl`-enforced Task lifecycle gate **graded by task size** (mirrors the pr-gate express/standard/full tiers): trivial/mechanical → no gate; small → one-line intent+acceptance; substantial (≥3 behavioral units, or touches a shared module, or new interface) → full `/pre-impl` design artifact before `claimed→in-progress`. Superpowers-inspired. | process | 2026-05-22 | — | P2 | design |
| CC-236 | 🟢 someday | **[pmctl report — away-from-keyboard state roll-up]** A `pmctl report` rolling up state since last invocation (open tasks, blockers, last gate verdict, recent runs). Deprioritized 2026-05-22: the maintainer does not run agents unattended, so a "morning report" time-gap framing has low current need; on-demand status is already part of the `pmctl` surface (CC-215). Revisit if the workflow ever includes overnight / away dispatch. | ux | 2026-05-22 | — | — | design |
| CC-237 | ⏸ deferred | **[v0.3.0 M4: context-enricher baseline]** Implement the context-enricher baseline sources — rg / `git ls-files` / `git diff` / memory search — producing a context-pack (CC-232) before dispatch. codegraph is evaluated separately as the CC-209 spike. `pmctl context build`. | ux | 2026-05-22 | — | P3 | design |
| CC-238 | ⏸ deferred | **[/pr-gate claude-route fan-out hardening]** CC-217 made the `/pr-gate` claude-executor reviewer/synthesis fan-out run detached (`run_in_background`). Gate advisories on the new flow (CC-217 gate, gate-20260523): (a) no timeout/fallback if a reviewer agent never reports completion → indefinite wait; (b) single fan-out step weakens per-reviewer failure attribution on partial failure; (c) no test artifact validates background completion / relay ordering. Add a completion timeout + partial-failure attribution + test coverage for the claude-route fan-out. | gate | 2026-05-23 | pr:#124 | P3 | oss |
| CC-239 | ⏸ deferred | **[reuse-scan capability]** New work keeps duplicating existing helpers / scripts / patterns (the recurring CC-200..204 reuse debt) because nothing surfaces "this already exists" before a brief is written. A dedicated reuse/refactor *agent* was considered and rejected (subagents cannot dispatch → it would only duplicate `project-pm`; refactor is not a distinct cognitive mode; refactor expertise already lives in architecture/risk/critic reviewers + the `dispatch-brief.md` refactor skeleton). The right shape is a **reuse-scan capability** invoked during PM briefing — queries the codebase for prior art and emits a reuse report the brief incorporates. Builds on CC-232 / CC-237 / CC-061. | reuse | 2026-05-23 | — | P3 | design |
| CC-240 | ⏸ deferred | **[test-suite reliability follow-ups]** Part (a) — suite-count derivation in `scripts/test-run-all-tests.sh` — closed via CC-219 (pr:#129). Remaining: `[low]` `scripts/test-portable.sh::case_mkdir_lock_contention` holds the lock with a fixed `sleep 1.2` (pre-existing; conflicts with the qa AGENT.md red line on `sleep` for async sync) → CI-timing flakiness. Fix with an IPC / event-driven lock-hold. | test | 2026-05-23 | pr:#127 | P3 | oss |
| CC-241 | ✅ closed 2026-05-23 | **[v0.2.0 doc-drift cleanup]** The CC-219 doc-freshness gate, run against `main`, surfaces three real drifts that pre-date this PR: (a) `[FAIL]` `BACKLOG.md:81` CC-104p shows `✅ closed 2026-05-21` but `pr:TBD` — the actual merged PR is #114 (`feat(cc-104p): add serialize_with_lock portable shim`); update the row to `pr:#114`. (b) `[FAIL]` `MILESTONES.md` `## v0.2.0` section status is marked 規劃中/planned but git tag `v0.2.0` was cut 2026-05-22 — flip status to released and add closing notes consistent with the `## v0.1.0` section. (c) `[WARN]` `README.md` has no `vN.N.N` version reference; add a current-version footer or version-table to satisfy U1 of the gate (warning only — non-blocking). Single PR; data-only commit; expected diff < 20 lines. | process/docs | 2026-05-23 | — | P3 | hygiene |
| CC-242 | ✅ closed 2026-05-23 | **[Spike — codex-dispatch param extraction survey + design decisions]** Survey all hardcoded codex-dispatch params (sandbox / approval / timeout / model alias) across scripts, validators, hooks, docs, agent templates, and test fixtures; classify each by invariant source (validator / hook / contract / doc / test) and configurability verdict; design timeout-axis PoC (env + `~/.pm-dispatch/config` precedence chain) and model-alias SoT extraction path; resolve open Q1 (scope) and Q2 (config file location). Output: `docs/spikes/CC-060.md`. Decisions: Q1=B (timeout + model-SoT bundled into one CC-060 impl PR), Q2=A (introduce `~/.pm-dispatch/config` as the first user-config precedent in the repo, optional / user-managed / never installer-created). Feeds directly into the CC-060 impl brief on this same branch. | process | 2026-05-23 | — | — | spike |
| CC-243 | ✅ closed 2026-05-23 | **[pm-prep-snapshot — state-snapshot前置給PM agent]** New `scripts/pm-prep-snapshot.sh` runs from main thread before any PM-agent spawn and writes `/tmp/pm-snapshot-<ts>-<unique>.md` containing branch_base (`origin/main` HEAD + current branch HEAD, with fallback to local main + warn-line when origin/main unresolved), recently_merged (last 5 `gh pr list --state merged`), backlog_next_id (derived from highest CC-N in `BACKLOG.md`), focus_tickets (full row + body section for any caller-named ticket IDs), project_tooling (three fixed boolean probes today: `makefile`, `backlog_render_target`, `has_validate_sh`; map is extensible — add new keys as projects diverge). PM brief always cites the snapshot path as ground truth; PM is instructed to prefer snapshot over caller-claimed commit/ID. Solves the two HALT classes observed in CC-242 (stale main commit, ticket-ID collision). Schema-like keys (`branch_base:`, `ticket_ids_consumed:`, `project_tooling:`) chosen now to ease future upgrade to typed `spike_v1` pipeline (see CC-244). | ops | 2026-05-23 | pr:#132 | P2 | design |
| CC-244 | 🟢 someday | **[Typed artifact pipeline — spike → brief → handover schema]** Define `spike_v1` schema mirroring existing `dispatch_handover_v1`: frontmatter (`spike_id`, `status`, `decisions_resolved`, `branch_base`, `ticket_ids_consumed`, `project_tooling`) + named sections (`scope`, `findings`, `constraints`, `decisions`, `phase3_handover`). Add `scripts/spike-validate.sh` (mirror `handover-validate.sh`) + `scripts/gen-brief-from-spike.sh` (mechanical brief extraction). Reduces main-thread courier cost, makes spike→brief authoring mechanical, gives invariant checkpoints (`decisions_resolved=true` ⇒ no re-asking Q1/Q2). Defer until 3+ spike docs exist and the brief-extraction pattern repeats; only one spike (CC-060) today, so schema would be premature overhead. CC-243 field names chosen to align with this future schema (no re-wash needed at upgrade time). | arch | 2026-05-23 | — | — | design |
| CC-245 | ✅ closed 2026-05-23 | **[Wire pm-prep-snapshot into /pm flow]** `commands/pm.md` now instructs the main thread to run `scripts/pm-prep-snapshot.sh` (built in CC-243) before invoking the `project-pm` agent, parse any `CC-\d+` IDs from `$ARGUMENTS` as `--focus`, and include the resulting `snapshot_file: <abs-path>` in the PM brief. Graceful degrade: if the script errors (no BACKLOG.md in non-pm-dispatch repos), skip the snapshot and proceed with dispatch. Realizes CC-243's value end-to-end — without this, the snapshot script existed in main but no caller invoked it. | ops | 2026-05-23 | pr:#133 | P2 | design |
| CC-246 | ✅ closed 2026-05-23 | **[pm-prep-snapshot echo OUT_PATH to stdout]** Smoke test of CC-245 caught a usability gap: `scripts/pm-prep-snapshot.sh` writes to `OUT_PATH` but doesn't echo the path on success, so callers (`/pm` skill + future automation) have to scan `/tmp` to find their snapshot. One-line fix: `printf '%s\n' "$OUT_PATH"` after the atomic `mv`. Update `commands/pm.md` to use `SNAPSHOT_FILE="$(bash ... pm-prep-snapshot.sh ...)"` capture pattern. Plus 2 new tests (stdout echoes --out path, stdout echoes default path) and one test made resilient (backlog_next_id assertion regex'd from literal `CC-245` to `CC-[0-9]+`). | ops | 2026-05-23 | pr:#134 | P3 | design |
| CC-224 | ⏸ deferred | **[shared hook-profile inventory: doctor.sh ↔ install-hooks.sh]** `doctor.sh` owns a second hardcoded minimal/full hook membership model alongside `install-hooks.sh`, creating a silent drift path when hooks are added or profile semantics change. Extract the hook-profile list into a shared shell helper (e.g. `scripts/hook-profile.sh`) or add a parity test asserting both files expect the same hook set. Raised by critic + architecture-reviewer as [medium] advise in gate-20260522-100348. | arch/reuse | 2026-05-22 | — | P3 | oss |
| CC-049 | ✅ closed 2026-05-18 | Archive closed ticket sections → BACKLOG-ARCHIVE.md | process/docs | 2026-05-17 | pr:#87 | — | hygiene |
| CC-050 | ✅ closed 2026-05-18 | Audit stale deferred tickets CC-011/012/014/015 | process/docs | 2026-05-17 | pr:#87 | — | hygiene |
| CC-051 | ✅ closed 2026-05-18 | **[BACKLOG hygiene Tier 1]** Add schema convention preamble at top of BACKLOG.md: ID convention (`CC-NNN` sequential except `CC-1NN` = CC-OSS epic markers, `CC-2NN` = reuse-debt markers — semantic groupings, not numeric ranges), sub-letter convention (`CC-NNNa/b/c` = follow-ups to parent ticket), status emoji legend (✅ closed / 🟡 deferred / 🔵 active / ⚠️ partial / ⏸ deferred-low-pri). Without this docs, fork users see "weird gaps" and don't know the conventions | process/docs | 2026-05-17 | — | — | hygiene |
| CC-052 | ✅ closed 2026-05-19 | **[BACKLOG schema upgrade]** `pm-schema v1.1`：index table 新增 `priority` 欄（P1/P2/P3）+ `epic:` 欄（正交分組取代 ID gap 慣例）；validator 同步更新；全列補欄。CC-051（preamble）先行；CC-052 在 CC-051 落地後啟動 | process/docs | 2026-05-17 | pr:#93 | — | hygiene |
| CC-053 | ✅ closed 2026-05-18 | `test-commands.sh` CLI self-test coverage | test | 2026-05-18 | pr:#84 | — | hygiene |
| CC-054 | ⏸ deferred | CC-025 M2 — `/skill-refine` diff generation and Claude-assisted refinement；scope deferred when CC-025b was closed in `feat/cc039-cc025b-v2` | ux/memory | 2026-05-18 | pr:#67 | — | — |
| CC-055 | ✅ closed 2026-05-18 | `commands/pr-gate.md` frontmatter YAML syntax error fixed | ops/DX | 2026-05-18 | pr:#86 | — | hygiene |
| CC-056 | ✅ closed 2026-05-18 | `scripts/lint-frontmatter.sh` + CI job + 12 regression tests | ops/test | 2026-05-18 | pr:#86 | — | hygiene |
| CC-057 | ✅ closed 2026-05-18 | README `skills/` layout row + `update-config` ref removed | docs/DX | 2026-05-18 | pr:#86 | — | hygiene |
| CC-058 | ✅ closed 2026-05-22 | `scripts/doctor.sh`：安裝前後環境健康檢查（claude/codex/jq 存在、hooks 已裝、memory dir、scripts executable、frontmatter lint）；每項失敗給出可操作修復步驟 | ops/DX | 2026-05-18 | pr:#119 | P3 | — |
| CC-059 | ⏸ deferred | Thin `/pm.md` command：把 brief 建立 / handover validation / dispatch / BashOutput tracking / diff verify 等 runtime 邏輯移入 `scripts/pm-dispatch-runner.sh` 等腳本；pm.md 只保留意圖描述與行為約束 | arch/ops | 2026-05-18 | roadmap:CC-200 | — | design |
| CC-060 | ✅ closed 2026-05-23 | Extract codex-dispatch hardcoded params (timeout + model alias SoT) behind config layer; adds `~/.pm-dispatch/config` user-config precedent | arch/ops | 2026-05-18 | pr:#131 | P2 | design |
| CC-061 | ⏸ deferred | 建立 `skills/` 目錄 + 2–3 個 starter SKILL.md：`dispatch-brief/SKILL.md`、`pr-gate-review/SKILL.md`（對齊 Anthropic Skills spec；README 已聲稱支援但目錄不存在）；與 CC-014/CC-015/CC-026 技能定義解耦，這條處理目錄結構 | arch/ux | 2026-05-18 | roadmap:CC-057 | — | — |
| CC-062 | ⏸ deferred | codex-bash-guard policy test matrix：建立 `tests/policy/codex-bash-guard/` 結構化 allow/deny JSON fixtures；讓安全 policy 從「很聰明的 shell parser」變「可驗證的 test matrix」 | ops/security | 2026-05-18 | — | — | — |
| CC-063 | 🟡 deferred | Trace / token / gate metrics dashboard：`.agent-trace/*.jsonl` + `rate-limits*.json` + `.gate-results/*.md` 已有足夠資料；可視化 per-session token、gate pass rate、routing_log 校準趨勢 | ux/ops | 2026-05-18 | — | P3 | — |
| CC-064 | 🟡 deferred | **[P2]** Project bootstrap wizard：互動式 `scripts/setup-project.sh --init` 引導新 repo 建立 memory、rules、PM schema；取代目前「手讀 GETTING_STARTED.md 再手跑指令」流程 | ux | 2026-05-18 | roadmap:CC-031 | P2 | — |
| CC-065 | 🟡 deferred | Per-repo configurable gate pipeline：不同 repo 可設定不同 reviewer 組合與 tier 預設（例如 `.pm-dispatch/gate.toml`）；現在所有 repo 共用同一 gate config | ops/gate | 2026-05-18 | — | P3 | — |
| CC-066 | 🟡 deferred | Declarative `policy.yml` for hook allowlist：把 `hook-codex-bash-guard.sh` 的允許/拒絕清單從 shell logic 抽成 `config/policy.yml`；hook 讀 policy 而非 hardcode；可 per-repo override | arch/security | 2026-05-18 | roadmap:CC-204 | P3 | design |
| CC-067 | ✅ closed 2026-05-19 | **[schema cleanup]** 廢棄 ID gap 慣例：移除 schema.md + BACKLOG preamble 中 CC-1NN/CC-2NN 保留範圍說明；改以 v1.1 `epic` 欄位為唯一分組依據；補 DECISIONS.md 決策記錄 | process | 2026-05-19 | decisions:#2026-05-19-deprecate-id-gap-convention | P2 | hygiene |
| CC-247 | ✅ closed 2026-05-23 | **[Reuse debt]** `th_init --format=<preset>` — extract the surviving per-file `pass`/`fail` print-format overrides into 5 named harness presets (`colon-flat`, `colon-mixed`, `indent-1sp`, `indent-2sp`, `indent-2sp-quiet`). Mechanical; no behavior change. Shipped in pr:#142; consumers adopted incrementally via PR-B.2 v2 (#152) — all 10 migrated test-*.sh files now use `th_init --format=...` or default `colon-flat`; zero per-file `pass`/`fail` overrides remain. | ops/test | 2026-05-23 | pr:#142 | P2 | reuse-debt |
| CC-248 | ✅ closed 2026-05-23 | **[Reuse debt]** `th_init --fail-fast` — promote the 3 fail-fast test scripts (test-usage-weekly, test-usage-tracker, test-skill-refine) from per-script `exit 1` overrides to a first-class harness option. Shipped in pr:#142; all 3 consumers adopted in PR-B.2 v2 (#152) via `th_init --format=... --fail-fast`; zero per-script `fail()` overrides remain. | ops/test | 2026-05-23 | pr:#142 | P3 | reuse-debt |
| CC-249 | ✅ closed 2026-05-24 | **[Reuse debt]** Consolidate divergent `assert_*` helpers in `scripts/lib/test-harness.sh` (3-way `assert_contains` divergence + `assert_exit` arg-order conflict). Spike `docs/spikes/CC-249.md` decided Q1-Q5 (#146); PR-B.1 added unified helpers (#148); CC-254 removed auto-pass (#149); PR-B.2 v2 migrated 10/13 consumers (#152, −114 LoC). 3 excluded files (test-test-harness / test-run-all-tests / test-hooks) deferred to CC-256. | ops/test | 2026-05-23 | pr:#148,pr:#149,pr:#152 | P3 | reuse-debt |
| CC-250 | ✅ closed 2026-05-23 | **[/pr-gate v2: machine-readable result + escalation]** Bundle: (A) YAML frontmatter on every gate result file (`gate_result_version: pr_gate_result_v1` + final/tier/mode/most_severe/reviewers/escalation), (B) `## Escalation` body section emitted by both sequential + parallel synthesis briefs (recommended=true requires sensitive-path AND non-fatal-uncertain reviewer verdict), (C) `--base` fallback prepends `gh pr view --json baseRefName` when available, (D) `## Override policy` section in each of the 5 reviewer agent .md files consolidating override discipline already prose-scattered. Preserves `^Final: GO\|NO-GO$` line for validate.sh + downstream parser back-compat. Out-of-scope: structured `verdict:` enum (CC-231), backlog_candidates output (CC-215), auto-escalation execution. | gate/ops | 2026-05-23 | pr:#144 | P2 | oss |
| CC-251 | ✅ closed 2026-05-24 | **[brief-authoring discipline for multi-file dispatches]** 3 patterns added to `agents/project-pm.md` + `docs/dispatch-brief.md` to prevent codex apply_patch debug-loop hang on > 4 files OR > 50 lines verbatim briefs: (1) apply_patch retry-cap (HALT after 2nd consecutive failure on same file, no 3rd retry), (2) verbatim-as-attached-file (write embedded content to /tmp/<task>-content/*.md, brief references path), (3) `expected_head_sha` state pin (40-char sha + self_verify check). Memory `[[feedback_codex_brief_discipline]]` documents the CC-247/248 + CC-250 retro evidence. Long-term resolution: CC-235 tiered lifecycle gate enforces split + CC-244 typed schema. | process | 2026-05-23 | pr:#145 | P3 | oss |
| CC-252 | ✅ closed 2026-05-24 | **[/pr-gate brief template: harden `Final:` line emission]** Discovered while running /pr-gate on CC-249 spike (#146 area): the CC-250 (#144) brief template asks codex to write `Final: GO\|NO-GO` in `## Gate Conclusion`, but codex applied prose markdown emphasis (`**Final: GO**`), which fails pr-gate.sh's `^Final: (GO\|NO-GO)$` parity grep → false-negative exit-1 even though the verdict is GO. Fix: the brief template in `scripts/pr-gate.sh` MUST tell codex the `Final:` line is **exact format, no bold, no leading/trailing markup, at start-of-line**, and add a frontmatter-vs-Final-line parity self-check to the template (the verdict in frontmatter `final:` must match the Final line). Discovered as a CC-250 follow-up; the verdict-extraction works, only the back-compat regex fails. | gate/ops | 2026-05-23 | pr:#147 | P3 | oss |
| CC-253 | 🔵 active | **[CC-209 Phase 2: codegraph benchmark on representative target codebase]** Phase 1 (PR #151) verdict AMBER — codegraph install ✓ license MIT ✓ API ✓, but pm-dispatch (bash/markdown) isn't a valid test target (`62 unsupported language`). Phase 2 re-scope: user picks a TS/JS/Python/Go target codebase at brief time, index it via codegraph, run 3 representative queries against rg/git baseline, measure token + latency delta. Output: append `## Phase 2` section to `docs/spikes/cc209-codegraph-phase1.md` OR new sibling doc. Verdict per original CC-209 ticket: adopt / defer / reject for context-pack source (CC-232 / CC-237). | ops/token | 2026-05-24 | pr:TBD | P3 | spike |
| CC-255 | 🔵 active | **[Spike infrastructure: rubric + brief template improvements]** PR #151 codegraph Phase 1 surfaced 2 spike-infra gaps that misled codex: (a) verdict rubric must enumerate sandbox-block as a "local env" example alongside peerDep (codex misapplied RED criterion because sandbox isolation wasn't an explicit local-env class in the rubric); (b) spike brief template must specify test target as a separate field from working directory — when target language-aware tools (e.g. codegraph) are evaluated, the brief must commit to a representative target codebase, not let codex pick on its own (Phase 1 brief said "pick a symbol in pm-dispatch" which pre-committed wrong target). Touch points: `/tmp/cc<NNN>-content/verdict-rubric.md` templates, `docs/spikes/README.md` skeleton, `docs/dispatch-brief.md` schema add optional `test_target:` field for spike briefs. | process | 2026-05-24 | pr:TBD | P3 | spike |
| CC-254 | ✅ closed 2026-05-24 | **[CC-249 PR-B.1 amendment: harness assert_* helpers no auto-pass]** PR-B.1 (#148) harness helpers auto-called `pass "$name"` on success. PR-B.2 (consumer migration) attempted dispatch 2026-05-24 surfaced design conflict: existing 13 consumers follow `assert_X "$name" && pass "$name"` pattern (assert is check, consumer calls pass) — pure rename would cause double-count. Codex defensively shadowed harness by re-defining 4 helpers locally in each consumer (violating Q3 break-and-rewrite rule). Real fix: remove auto-pass from harness; consumers keep explicit `pass` (unchanged behavior on success, helper still calls `fail` on failure). Self-tests amended to call pass explicitly after assert. After this lands, PR-B.2 reverts to pure rename + delete local defs (the simple migration spike originally envisioned). | ops/test | 2026-05-24 | pr:#149 | P2 | reuse-debt |
| CC-256 | ✅ closed 2026-05-25 | **[CC-249 reuse-debt tail: assert_* migration for the 3 excluded test files]** PR-B.2 v2 (CC-249 consumer migration) deliberately excluded 3 files from the unified `assert_*` rename: `test-test-harness.sh` (tests the harness itself — cyclic dependency on `assert_string_contains`/`assert_file_contains`/`assert_exit`/`assert_file_matches`; 13 helper call-sites), `test-run-all-tests.sh` (orchestrator with `assert_*` self-checks of a different shape; 2 call-sites), `test-hooks.sh` (assertion-style file with 0 unified-helper call-sites — likely no migration needed beyond audit). Defer rationale: each needs its own per-file analysis (cyclic test-vs-system-under-test for test-test-harness, orchestrator-vs-case-runner for test-run-all-tests, drift confirmation for test-hooks) — not a mechanical rename batch. CC-249 epic closes as scoped (10/13 consumers); this ticket carries the residual. Filed in pr:#152. | ops/test | 2026-05-24 | pr:#152,pr:#161 | P3 | reuse-debt |
| CC-257 | ✅ closed 2026-05-24 | **[pr-gate.sh stderr noise: 7× `final::` command-not-found per invocation]** Every `/pr-gate` run emitted 7 shell errors at `scripts/pr-gate.sh:362` (heredoc opening line for the codex brief construction). Root cause: unquoted heredoc delimiter (`<< BRIEF_EOF`) → bash performed command substitution on the 7 backticked `` `Final:` ``/`` `final:` `` tokens added by CC-252 (#147); identical 3-line block also present in synthesis-brief heredoc (SBRIEF_P2). Verdict + result file still emitted correctly so this was stderr noise only — but it obscured real shell errors and hit every PR. Fix: escape the 7 backtick pairs (`` ` `` → `` \` ``) in the 3 unique lines (each appearing in both BRIEF_EOF and SBRIEF_P2 = 6 line edits). Regression test `test_brief_construction_emits_no_shell_errors` asserts stderr contains zero `command not found` AND the brief still carries the cautionary tokens. | gate/ops | 2026-05-24 | pr:#154 | P3 | oss |
| CC-258 | ⏸ deferred | **[pm-write-guard hook policy revision]** Current `scripts/hook-pm-write-guard.sh` denies 3 legitimate PM-author patterns (12/207 deny audit hits over 10 days): (A) `/tmp/<task-slug>/*.md` verbatim-as-attached-file (Pattern 2 of `[[feedback_codex_brief_discipline]]`), (B) `<repo>/docs/spikes/{CC-NNN*,*-scope,*-rfc}.md` PM-author surface, (C) memory writes that resolve through the `memory-private/` symlink (`realpath_m` chases the symlink before the allow-pattern match — hook bug). Three new allow rules + `realpath_m_lex` (or `-s`) helper + ~15 new test cases in `scripts/test-hooks.sh`. Not blocking M1; deferred until user prioritizes. | process | 2026-05-24 | pr:#156 | P3 | hygiene |
| CC-259 | 🟢 someday | **[yaml.sh lib extraction]** Extract `_yaml_get` bash/awk helper and `case_yaml_parse` structural validator from `scripts/test-core-schemas.sh` into `scripts/lib/yaml.sh` for reuse across test scripts; add independent test file `scripts/test-yaml-lib.sh` and wire into `run-all-tests.sh` + CI. Currently only used in `test-core-schemas.sh`; extraction deferred from CC-229 M1 PR to reduce gate surface. Trigger: second consumer in a new test script. | ops/test | 2026-05-25 | pr:TBD | P3 | — |
| CC-260 | 🟢 someday | **[pr-gate.sh: include dirty-worktree diff in review scope]** When a branch has committed changes, `git diff "$BASE"...HEAD` silently omits uncommitted (dirty) tracked and untracked files, so gate briefs may miss in-progress working-tree changes. Fix: merge `git diff HEAD` (dirty tracked) + untracked listing into the brief stat, or add a clear dirty-tree warning that tells the reviewer the brief is incomplete. Flagged by critic [medium] in CC-229 Gate 12. | gate/ops | 2026-05-25 | pr:TBD | P2 | — |
| CC-261 | ✅ closed 2026-05-25 | **[v0.3.x 前瞻文字更新]** `core/README.md` 的 "will read…(runtime consumer deferred; M1 ships schema definitions only)" 及 `agents/project-pm.md` 的 "v0.3.x runtime PR" 在 v0.3.0 runtime 落地後變成誤導性描述；前者改現在式並移除括號說明，後者改版本無關的 "a future runtime PR"。自 v0.3.0 release prep 的 self_verify 步驟觸發。 | docs/process | 2026-05-25 | pr:#162 | P3 | hygiene |
| CC-262 | ⚠️ partial 2026-05-25 | **[Executor isolation 抽象層]** M1 ✅（PR #162）：`core/policy/isolation-level.yaml` + `adapters/claude/isolation-map.yaml`。M2 ⏳：`codex-dispatch.sh` dispatch 前展開 isolation_level。M3 ⏳：`agents/project-pm.md` PM brief template 改寫 `isolation_level:` 取代三個原生欄位。v0.4.0 ⏳：`adapters/codex/isolation-map.yaml`。 | arch/process | 2026-05-25 | pr:#162 (M1) | P2 | design |
| CC-263 | ✅ closed 2026-05-25 | **[state-writer: portable SHA-1 hash for project partitioning]** `_sw_project_key` uses `sha1sum` (GNU coreutils only); platforms without it silently fall back to `global` partition, mixing all project state into a single directory. Fix: add a `_portable_sha1` helper to `scripts/lib/portable.sh` (try `sha1sum`, then `shasum -a 1`, then fail loudly) and consume it from `_sw_project_key`; add a no-`sha1sum` PATH regression in `test-state-store.sh`. Raised as [medium] by critic, architecture-reviewer, and risk-reviewer in CC-230 gate 5. | ops/process | 2026-05-25 | pr:#159,pr:#162 | P3 | — |
| CC-264 | ✅ closed 2026-05-28 | **[dispatch overhead reduction + executor-agnostic output contract]** `codex-executor` subagent 2.5x overhead → shell pipeline；同時統一 output contract（所有 executor 寫 `.agent-trace/latest.last`）讓 post-verify executor-agnostic。PR A：`brief-validate.sh` + 測試 + CI；PR B：output contract（executor-contract.md + claude-executor.md）+ `dispatch-post-verify.sh` + 測試 + CI。 | arch/process | 2026-05-26 | pr:#163,pr:#164,pr:#167 | P2 | — |
| CC-265 | ✅ closed 2026-05-26 | Remove `/caveman` and `/caveman-commit` commands. | process | 2026-05-26 | — | P2 | hygiene |
| CC-266 | 🟡 deferred | **[adapters/claude: shell-level dispatch for Codex-as-PM → Claude-as-executor path]** 當主線程是 Codex（PM 在 Codex 環境執行）、想派發 Claude 作為 executor 時，`agents/claude-executor.md`（假設 Claude 是主線程）無法被直接呼叫。`adapters/claude/` 需補 dispatch 側：定義如何從 Codex 環境透過 CLI（`claude --print ...` 或等效呼叫）啟動 Claude executor，並讓它仍寫 `.agent-trace/latest.last` 滿足 output contract。M3 階段實作 `adapters/claude/dispatch.sh`（或等效）時的關鍵設計考量。 | arch | 2026-05-26 | — | P3 | design |
| CC-267 | ✅ closed 2026-05-28 | **[bug: executor:claude gate path — Write blocked in background subagent]** `pr-gate.sh --executor claude` 派出的 background `claude-executor` subagent 需要 Write gate result file，但 background mode 下 Write 新檔案被拒 → result 靜默丟失。Fix：在 `pr-gate.sh` emit handover block 前先 `mkdir -p` + `touch "$output_file"`，讓 agent 改用 `Edit`（允許）。 | gate/ops | 2026-05-28 | pr:#169 | P2 | oss |
| CC-268 | 🟡 deferred | **[docs: run_in_background default async escalation undocumented]** Agent tool 未設 `run_in_background:true` 時，harness 可能靜默升格為 async 並回傳 `Async agent launched successfully`（codex-executor 已觀察到此行為）。需文件化哪些 subagent 類型永遠 async、預設行為保證。| docs/DX | 2026-05-28 | — | P3 | — |
| CC-269 | 🟡 deferred | **[ops: pm-dispatch hook-save-rate-limits.sh 應寫到自己的 state 路徑]** 目前 `scripts/hook-save-rate-limits.sh` 寫到 `~/.claude/rate-limits.json`，與 claude-account-switcher 等其他工具使用同一檔名，造成多工具衝突。應改寫到 `~/.local/share/pm-dispatch/state/rate-limits.json`（對齊 CC-230 state store 位置），並同步更新所有讀取此路徑的腳本。 | ops/install | 2026-05-28 | — | P3 | — |
| CC-270 | 🟡 deferred | **[test: concurrent pmctl adapter generate guard]** Two simultaneous `pmctl adapter generate <same-name>` runs can race: the precheck+mkdir+trap sequence is not atomic. Blast radius: one run may delete another's partial output; reproducible by deleting `adapters/<name>` and rerunning. Deferred — single-developer workflow makes this low-probability; fix with atomic mkdir using `mkdir` exit-code guard when needed. | test/ops | 2026-05-28 | — | P3 | — |
| CC-271 | ✅ closed 2026-05-29 | **[process: Go build cache redirect — sandbox limitations guide]** Go GOCACHE 說明文件範圍已折入 CC-206（`docs/sandbox-limitations.md`）；CC-206 ship 後同步關閉。根本原因：sandbox `/home` 唯讀，`GOCACHE=/tmp/go-cache` 是最小正確解法（不切斷 module source 存取）。 | process/DX | 2026-05-28 | pr:#175 | P2 | — |
| CC-272 | 🟡 deferred | **[process: brief template — omit commit block; document main-thread commit delegation]** 每個 brief 末尾的 `git add + git commit` 均被 `hook-codex-bash-guard` 擋住，executor 回報 `status: partial`（即使程式碼正確），主線程每次都必須手動 commit。推薦 Option A：從 brief template 移除 commit block，在 `docs/dispatch-brief.md` 明文「commit 永遠委派主線程」。Option B：hook allowlist 加入無破壞性 git add/commit。 | process/DX | 2026-05-28 | — | P2 | — |
| CC-273 | 🟡 deferred | **[arch: unified lifecycle hook event spec]** CC-206 只在 gate 層加了 pre/post-gate hooks。如果未來多個工具（dispatch、validate 等）都需要 hook 點，應定義統一的 lifecycle event 命名規範（如 `.pm-dispatch/hooks/<event>.sh`）和呼叫合約，而非在每個腳本各自加 pre/post block。目前無需求，等有第二個 hook 點需求時再設計。 | arch/gate | 2026-05-28 | — | P3 | — |
| CC-274 | 🟡 deferred | **[docs: reconcile CC-262 planning text with shipped isolation implementation]** CC-262 entry 有三處過時：(1) enum 只列 4 值，缺 workspace-network；(2) sandboxed 語義仍寫「完整隔離」，實為 best-effort workspace-write；(3) M2/v0.4.0 仍標 deferred，均已在 PR #175 落地。 | docs | 2026-05-29 | pr:#175 | P2 | — |
| CC-275 | ✅ closed 2026-05-29 | **[bug: pr-gate.sh exits 127 after result write — em dash bytes misinterpreted as command]** Full-tier gate 完成後 exit 127（`$'\200\224': command not found`）；result file 正確，只有 exit code 錯誤。em dash（U+2014）在某些 bash locale 下後兩 bytes 被解析成命令。Fix：把所有 `—` 換成 ASCII `--`。 | gate | 2026-05-29 | pr:#179 | P1 | — |
| CC-276 | 🟡 deferred | **[feat: persistent gate override declarations]** 每輪 gate 重開 fresh session，已接受的 risk override 必須重新聲明。支援 `--override-file` 或自動探索 `.gate-overrides.md`，inject 到 reviewer prompt 前置脈絡，避免已接受的 block 重複出現。 | gate/process | 2026-05-29 | — | P2 | — |
| CC-277 | ✅ closed 2026-05-30 | **[backlog hygiene: fix CC-228 E-codes — reach validate.sh exit 0 on main]** Correct all pre-existing validator errors in BACKLOG.md: invalid area values, bare CC-NNN refs (add valid prefix), stale active status rows (CC-200/202/204/262/275 closed but still active). Prerequisite for wiring validate.sh into CI. | process | 2026-05-29 | pr:#183 | P1 | hygiene |
| CC-278 | ✅ closed 2026-05-30 | **[ops: wire validate.sh into CI lint.yml — warn-only then enforce]** Add a lint.yml job that runs `pm/scripts/validate.sh BACKLOG.md`; Phase 1: warn-only (`\|\| true`) with an error-count summary step; Phase 2: hard-fail after CC-277 lands and validator exits 0 on main. | ops/test | 2026-05-29 | pr:#184 | P2 | hygiene |
| CC-279 | ✅ closed 2026-05-30 | **[ops: write scripts/archive-closed-backlog.sh — standalone bloat-policy executor]** Implement an idempotent shell script that applies pm-schema §4 bloat policy: find all ✅ closed / 🚫 dropped body sections in BACKLOG.md, append compressed entries to BACKLOG-ARCHIVE.md, replace body with `**See**: BACKLOG-ARCHIVE.md` stub, update archive header timestamp. No pmctl dependency — pmctl will call this script when it lands. | ops/process | 2026-05-29 | pr:#184 | P2 | hygiene |
| CC-280 | ✅ closed 2026-05-30 | **[process: run archive-closed-backlog.sh to collapse current bloat]** Execute CC-279 script against the current repo state. BACKLOG.md currently exceeds the 500-line policy threshold and >50% of rows are terminal — both bloat-policy triggers are active. Deferred until CC-279 script exists. | process | 2026-05-29 | pr:#185 | P2 | hygiene |
| CC-281 | 🟡 deferred | **[process/docs: split BACKLOG index into Active and Terminal sub-sections]** Insert a comment delimiter (`<!-- active items above \| terminal items below -->`) between active/deferred rows and terminal (closed/dropped/superseded) rows in the index table. Active rows float to top, improving PM agent scan efficiency. Use comment delimiter (not H2 header) to preserve PM agent index parsing contract (pm-schema §6.1). Deferred until CC-280 (archive run) completes to minimize churn. | process/docs | 2026-05-29 | — | P3 | hygiene |
| CC-282 | 🟡 deferred | **[DX: pmctl backlog sync — SQLite derived query layer]** Add `pmctl backlog sync` subcommand that imports BACKLOG.md into a local SQLite database (backlog.db, gitignored). Enables fast indexed queries (`pmctl backlog view --status active`, `--area ops`, `--milestone M3`). SQLite is a derived store — BACKLOG.md remains the human-editable source of truth. Depends on CC-215 pmctl core landing (M3/M4). | DX/product | 2026-05-29 | — | P3 | — |
| CC-283 | 🟡 deferred | **[bug: archive-closed-backlog.sh sentinel false-negative]** The archiver's `has_see` guard scans a section body for `**See**:.*BACKLOG-ARCHIVE` to decide whether it is already stubbed. Any closed ticket whose body *quotes* that sentinel (e.g. CC-279, which documents the stubbing behavior) is mis-read as already-archived and silently skipped — it can never be collapsed, and a closed-but-unstubbed section then trips `E-CLOSURE-NO-SEE`. Surfaced during CC-280 (CC-279 had to be archived by hand). Fix: anchor stub detection to the section's first content line / exact stub match, not a substring-anywhere scan. | ops | 2026-05-30 | — | P3 | hygiene |

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

**Removed in CC-265** -- `commands/caveman.md` and `commands/caveman-commit.md` deleted; `test-commands.sh` caveman sections removed.

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

**See**: BACKLOG-ARCHIVE.md

## CC-104u — link_or_copy real-directory dst CONFLICT fix ✅ 2026-05-19

**See**: BACKLOG-ARCHIVE.md

## CC-104b — platform-aware install hints when jq is missing ✅ 2026-05-17

**See**: BACKLOG-ARCHIVE.md

## CC-104c — link_or_copy() + install manifest for symlink-unavailable hosts ✅ 2026-05-17

**See**: BACKLOG-ARCHIVE.md

## CC-104l — install.sh jq prerequisite check ✅ 2026-05-21

**See**: BACKLOG-ARCHIVE.md

## CC-104t — python3→jq hook refactor; extract scripts/lib/memory.sh ✅ 2026-05-20

**See**: BACKLOG-ARCHIVE.md

## CC-104o — Windows Store python3 stub (superseded by CC-104t)

**See**: CC-104t

## CC-104p — serialize_with_lock routing-log shim ✅ 2026-05-21

**See**: BACKLOG-ARCHIVE.md

## CC-104v — copy-mode install summary banner ✅ 2026-05-21

**See**: BACKLOG-ARCHIVE.md

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

**See**: BACKLOG-ARCHIVE.md

## CC-031 — 開源前置：CONTRIBUTING.md + SECURITY.md + README 工作語言聲明 ✅ 2026-05-19

**See**: BACKLOG-ARCHIVE.md

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

## CC-046 — validate.sh + run-tests.sh dedup ✅ 2026-05-19

**See**: BACKLOG-ARCHIVE.md

## CC-049 — BACKLOG hygiene Tier 1 archive closed detail sections ✅ 2026-05-18

**See**: BACKLOG-ARCHIVE.md

## CC-050 — BACKLOG hygiene Tier 1 stale deferred audit ✅ 2026-05-18

**See**: BACKLOG-ARCHIVE.md

## CC-051 — BACKLOG schema convention preamble ✅ 2026-05-18

**See**: BACKLOG-ARCHIVE.md

## CC-052 — `pm-schema v1.1` BACKLOG schema upgrade ✅ 2026-05-19

**See**: BACKLOG-ARCHIVE.md

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

**See**: BACKLOG-ARCHIVE.md

## CC-059 — Thin /pm.md：把 runtime 執行邏輯移入 scripts

**Problem**: `commands/pm.md` 包含 brief file 建立、handover validation、Codex dispatch、background mode、BashOutput tracking、stderr parsing、git diff verify、exit 124 retry 等大量流程邏輯。markdown command 逐漸變成「半程式碼、半 prompt、半 policy」的混合體。
**Why**: 當 Codex CLI、Claude Code hooks 或 scripts 行為改變時，markdown command 很容易與實際腳本 drift。script 有測試；markdown 沒有。
**Requirement**: 識別 pm.md 中可搬到 shell script 的 runtime 步驟（特別是 handover extraction + validation + dispatch 命令組裝）；移入 `scripts/pm-dispatch-runner.sh`（或直接加強 `scripts/lib/`）；pm.md 只保留「什麼情境呼叫什麼腳本」的意圖描述與 trigger 條件。依賴 CC-200（executor-router.sh）。

## CC-060 — Codex model/config 外部化 ✅ 2026-05-23

**See**: BACKLOG-ARCHIVE.md

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

**See**: BACKLOG-ARCHIVE.md

## CC-104n — install/test boundary ✅ 2026-05-19

**See**: BACKLOG-ARCHIVE.md

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

## CC-206 — gate lifecycle hooks + sandbox limitations guide ✅ 2026-05-29

**See**: BACKLOG-ARCHIVE.md

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

## CC-215 — pmctl — core CLI entrypoint（active）

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
  - `pmctl adapter generate <claude|codex|antigravity|opencode>`
- Claude adapter: `/pm task-123` → `pmctl task dispatch task-123 --agent claude`
- Guard logic migrates from Claude-only hooks into `pmctl` so hook is just a thin caller.
- `pmctl adapter generate` produces per-CLI config from core agent definitions.

**Depends on**: CC-211 (core layer extracted first).

**Complements**: CC-211 (architecture), CC-216 (MCP server wraps pmctl).

**Priority**: P1 within CC-211 roadmap. Evaluate at v0.3.0.

## CC-216 — MCP server — pm-dispatch-server（deferred）

**v0.4.0** (updated 2026-05-22): deferred to v0.4.0 per the v0.3.0 synthesis — MCP must wrap a stable `pmctl`, never an immature one. v0.3.0 ships only `mcp/README.md` defining the tool surface as a `pmctl` interface design constraint. See [`docs/architecture/v0.3.0-synthesis.md`](../docs/architecture/v0.3.0-synthesis.md) §5.4.

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

## CC-217 — claude-executor background dispatch ✅ 2026-05-23

**See**: BACKLOG-ARCHIVE.md

## CC-218 — spike tracking infrastructure ✅ 2026-05-23

**See**: BACKLOG-ARCHIVE.md

## CC-219 — pre-milestone doc freshness gate ✅ 2026-05-23

**See**: BACKLOG-ARCHIVE.md

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

## CC-200 — Reuse debt: `scripts/lib/executor-router.sh` ✅ 2026-05-28
**See**: BACKLOG-ARCHIVE.md

**Problem**: `/pm` and `/pr-gate` each encode codex/claude routing logic separately.
**Why**: A third consumer would turn the duplicated route logic into a maintenance cost and make executor behavior easier to drift.
**Requirement**: Extract shared codex/claude routing into `scripts/lib/executor-router.sh`, preserving existing CLI behavior for current callers.

## CC-201 — Reuse debt: `detect_executor_profile()` shim ✅ 2026-05-23

**See**: BACKLOG-ARCHIVE.md

## CC-202 — Reuse debt: handover validator framework ✅ 2026-05-28
**See**: BACKLOG-ARCHIVE.md

**Problem**: `dispatch_handover_v1` and `pr-gate-handover_v1` validators duplicate fence, metadata, and body validation structure.
**Why**: Future handover schemas should not require hand-written validation boilerplate for every shared grammar rule.
**Requirement**: Extract a reusable handover validator framework that schema-specific validators can configure.

## CC-203 — Reuse debt: `scripts/lib/test-harness.sh` ✅ 2026-05-24

**See**: BACKLOG-ARCHIVE.md

## CC-204 — Reuse debt: hook framework ✅ 2026-05-28
**See**: BACKLOG-ARCHIVE.md

**Problem**: pm-write-guard, codex-bash-guard, and codex-write-guard repeat stdin JSON parsing, decision matrix, and audit-log structure.
**Why**: The guard hook layer has enough shared behavior that copy-paste-modify makes policy and logging drift likely.
**Requirement**: Extract a shared hook framework (`scripts/lib/hook-framework.sh`) for stdin JSON parsing, policy decisions, and audit logging, while preserving hook-specific policy rules.
**Scope note**: `hook-routing-log.sh` is intentionally excluded — it uses custom jq-free JSON parsing and structured JSONL audit logging with rotation/locking, fundamentally different from the guard hook pattern. It remains independent.

## CC-221 — copy-mode refresh semantics ✅ 2026-05-21

**See**: BACKLOG-ARCHIVE.md

## CC-222 — v0.2.0 release prep ✅ 2026-05-22

**See**: BACKLOG-ARCHIVE.md

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

## CC-229 — core/schema: task/run/event/review/decision schemas ✅ 2026-05-25

**See**: BACKLOG-ARCHIVE.md

## CC-230 — state store: ~/.local/share/pm-dispatch/state/ (XDG) ✅ 2026-05-25

**See**: BACKLOG-ARCHIVE.md

## CC-231 — core/policy extraction ✅ 2026-05-25

**See**: BACKLOG-ARCHIVE.md

## CC-232 — context-pack schema + context-enricher interface ✅ 2026-05-25

**See**: BACKLOG-ARCHIVE.md

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

## CC-235 — Task lifecycle gate: tiered spec→design→plan（deferred）

**Problem**: The spec→design→plan discipline (`/pre-impl`, the `qa_checklist` rule) is advisory prose in `agents/project-pm.md` — not enforced. But a single uniform gate would over-burden trivial tasks — a typo fix should not need a design artifact.

**Why**: Enforcement should be **graded by task size**, consistent with pm-dispatch's existing tiered patterns: the pr-gate express/standard/full tiers and the sonnet-default / Opus-escalation model-tier policy. The gate's weight scales with the task.

**Requirement**: `pmctl` enforces a tiered gate on the `claimed → in-progress` transition:
- **Trivial** — 1 mechanical unit (typo, rename, doc tweak, dep bump): no gate; dispatch directly.
- **Small** — ~2 units, localized: lightweight — a one-line intent + acceptance in the brief; no `/pre-impl` artifact.
- **Substantial** — ≥3 behavioral units, OR touches a shared module/schema, OR introduces a new interface: full spec→design→plan; a `/pre-impl` design artifact is required before the transition.
The ≥3-units threshold and the shared-module / new-interface triggers already exist in `agents/project-pm.md`; this ticket makes them a graded state-machine gate rather than advisory prose.

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

## CC-238 — /pr-gate claude-route background fan-out hardening（deferred）

**Problem**: CC-217 made the `/pr-gate` claude-executor reviewer and synthesis fan-out (`commands/pr-gate.md` Route B) run detached via `run_in_background: true`. The CC-217 gate (gate-20260523, express tier) raised three advisories on the new flow.

**Why**: A detached fan-out with no timeout can wait indefinitely if a reviewer agent never reports completion; a single fan-out step makes per-reviewer attribution weaker on partial failure; and the behavior change has no test artifact.

**Requirement**:
- Add a completion timeout / fallback for the background reviewer + synthesis agents — a non-reporting agent must degrade to a partial/fail result, not an indefinite wait.
- Preserve per-reviewer failure attribution when only one fan-out branch fails.
- Add test coverage for the claude-route background completion + relay ordering (`scripts/test-pr-gate.sh` or a `commands/`-contract test).

**Priority**: P3 — advisory follow-up; the CC-217 GO was not blocked on it.

**Cross-link**: CC-217 (origin), `commands/pr-gate.md` Route B.

## CC-239 — reuse-scan capability（deferred）

**Problem**: pm-dispatch carries recurring reuse debt — CC-200..204 are all "the same logic duplicated across scripts / hooks / tests". New work keeps re-creating helpers and patterns that already exist, because nothing surfaces "this already exists" before a brief is written. The maintainer asked whether a dedicated **reuse/refactor agent** should be added; it was analysed and is the wrong shape (see Why).

**Why**: A dedicated reuse/refactor *agent* is not the right abstraction:
- Subagents cannot spawn subagents, so a "refactor agent" could only be a *planner* — duplicating `project-pm`, which already owns task triage / decomposition / brief-writing.
- pm-dispatch agents split by **cognitive mode** (plan / execute / review), not by domain. Refactor is not a new mode — it is ordinary implementation. The spike agent (CC-220) earned a dedicated agent by being a genuinely distinct mode (uncertainty reduction); refactor is not.
- Refactor *expertise* is already placed: `architecture-reviewer` (coupling / abstraction fit), `risk-reviewer` (migration safety / reversibility) and `critic` (scope / convention drift) review every refactor PR, and `docs/dispatch-brief.md` already carries a `refactor` brief skeleton (semantic preservation, all-call-sites-updated, tests green). A refactor agent would duplicate those.
- The v0.3.0 synthesis already concluded "no separate reuse/refactor agent" — reuse work *is* ordinary briefed implementation (`docs/architecture/v0.3.0-synthesis.md`; the CC-200..204 extraction tickets are exactly this).

The genuinely-missing piece is the **front-end**: a reuse-scan that runs *before* briefing so the brief reuses rather than duplicates. That is a capability, not an agent — "split by goal, not by role".

**Requirement**: a reuse-scan **capability** (a skill / context step, not an agent), invoked by `project-pm` during briefing, that queries the codebase for prior art relevant to the task — similar functions, shared helpers, existing patterns (`rg` / `git grep` baseline; symbol / AST sources later) — and emits a "reuse report" the dispatch brief incorporates. It is one consumer of the `context-pack` (CC-232) / context-enricher (CC-237) infrastructure and belongs in `skills/` (CC-061). Refactor *execution* (mechanical or semantic) stays on the existing brief → executor → gate path with the `dispatch-brief.md` refactor skeleton — no new execution agent.

**Priority**: P3 — quality-of-life capability; depends on the M1/M4 context infrastructure (CC-232 / CC-237), so evaluate for v0.3.0 M4 or later.

**Cross-link**: CC-232 (context-pack schema), CC-237 (context-enricher baseline), CC-061 (skills/), CC-200..CC-204 (the reuse debt this prevents recurring), `docs/architecture/v0.3.0-synthesis.md`.

## CC-240 — test-suite reliability follow-ups（deferred — partial）

**Status**: Part (a) — suite-count derivation in `scripts/test-run-all-tests.sh` — closed via CC-219 (pr:#129); the assertions now derive expected pass/skip totals from `${#SUITE_NAMES[@]}`. Part (b) below remains open.

**Problem (remaining)**: `scripts/test-portable.sh::case_mkdir_lock_contention` holds the lock with a fixed `sleep 1.2` to create contention overlap (pre-existing — not introduced by CC-203).

**Why**: Fixed-`sleep` async timing is flaky on slow / preempted CI hosts and conflicts with the qa-testing-rules AGENT.md red line on `sleep` for async synchronization — a flaky gate test erodes the gate's signal.

**Requirement**:
- `test-portable.sh::case_mkdir_lock_contention`: replace the fixed `sleep 1.2` lock-hold with an IPC / event-driven control path (e.g. a FIFO-gated holder, matching the pattern already used elsewhere in the portable-lock tests).

**Priority**: P3 — test-infra hardening; advisory follow-up, the CC-203 GO was not blocked on it.

**Cross-link**: CC-203 (origin), `scripts/test-run-all-tests.sh`, `scripts/test-portable.sh`.

## CC-241 — v0.2.0 doc-drift cleanup ✅ 2026-05-23

**See**: BACKLOG-ARCHIVE.md

## CC-242 — Spike: codex-dispatch param extraction survey ✅ 2026-05-23

**See**: BACKLOG-ARCHIVE.md

## CC-243 — pm-prep-snapshot: state-snapshot前置給PM agent ✅ 2026-05-23

**See**: BACKLOG-ARCHIVE.md

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

**Trigger conditions to promote from someday → active**:
- 3+ spike documents under `docs/spikes/` with similar phase-1/phase-2/phase-3 structure
- Two consecutive brief-authoring rounds where PM essentially copy-pastes the same fields out of spike prose
- Or: an automation use case (e.g. CI-side spike-stage tracking) that requires structured spike state

**See**: CC-243 (snapshot fields already aligned).

## CC-245 — Wire pm-prep-snapshot into /pm flow ✅ 2026-05-23

**See**: BACKLOG-ARCHIVE.md

## CC-246 — pm-prep-snapshot echo OUT_PATH ✅ 2026-05-23

**See**: BACKLOG-ARCHIVE.md

## CC-247 — `th_init --format=<preset>`: 5-preset enum for residual print-format overrides ✅ 2026-05-23

**See**: BACKLOG-ARCHIVE.md

## CC-248 — `th_init --fail-fast`: promote fail-fast to harness option ✅ 2026-05-23

**See**: BACKLOG-ARCHIVE.md

## CC-249 — Consolidate divergent `assert_*` helpers in `scripts/lib/test-harness.sh` ✅ 2026-05-24

**See**: BACKLOG-ARCHIVE.md

## CC-250 — `/pr-gate v2`: machine-readable result + escalation hint ✅ 2026-05-23

**See**: BACKLOG-ARCHIVE.md

## CC-251 — Brief-authoring discipline for multi-file dispatches ✅ 2026-05-24

**See**: BACKLOG-ARCHIVE.md

## CC-252 — `/pr-gate` brief template: harden `Final:` line emission ✅ 2026-05-24

**See**: BACKLOG-ARCHIVE.md

## CC-254 — CC-249 PR-B.1 amendment: harness assert_* no auto-pass ✅ 2026-05-24

**See**: BACKLOG-ARCHIVE.md

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

## CC-255 — Spike infrastructure: rubric + brief template improvements（active）

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

**Cross-link**: CC-209 (Phase 1 origin showing both gaps), CC-253 (Phase 2 dependent on these template improvements), `[[feedback_spike_pilot_required]]` (sibling spike-process rule), `[[feedback_spike_validation_mandatory]]` (sibling validation rule).

## CC-257 — pr-gate.sh stderr noise: `final::` command-not-found ×7 per invocation ✅ 2026-05-24

**See**: BACKLOG-ARCHIVE.md

## CC-256 — CC-249 reuse-debt tail: 3 excluded test files ✅ 2026-05-25

**See**: BACKLOG-ARCHIVE.md

## CC-258 — pm-write-guard hook policy revision（deferred）

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

**See**: `docs/spikes/CC-258-pm-write-guard-policy.md` (full design, audit data table, code change sketch, test coverage sketch, risks + mitigations).

**Cross-link**: `[[feedback_codex_brief_discipline]]` (Pattern 2 origin), `[[feedback_spike_validation_mandatory]]` (why `/tmp/brief-*.md` stays denied), `[[reference_memory_private_repo]]` (symlink target).

---

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

## CC-260 — pr-gate.sh: include dirty-worktree diff in review scope（someday）

**Problem**: When a branch has committed changes, `scripts/pr-gate.sh` uses `git diff "$BASE"...HEAD` to build the reviewer brief stat. This silently omits uncommitted tracked changes (`git diff HEAD`) and untracked files. During CC-229 Gate 12, the brief stat did not include `install.sh` and `scripts/test-schema-task-mirrors-backlog.sh` which were in the dirty worktree but not yet committed.

**Why**: Gate reviewers can only assess what's in the brief. Silently omitting working-tree changes means new files and tracked modifications that haven't been committed are invisible to reviewers. This is especially impactful for long-running iterative gate sessions where fixes accumulate in the working tree before a final commit.

**Requirement**:
- Detect dirty worktree (tracked changes or untracked relevant files) when building gate briefs
- Either include `git diff HEAD` output alongside `git diff "$BASE"...HEAD`, or emit a visible warning: `# warn: N dirty tracked / M untracked files excluded from brief — commit first for complete review`
- Prefer the warning approach to avoid inflating brief size; the warning should appear in the brief header section

**Acceptance**:
1. When working tree has uncommitted tracked changes, gate brief includes either the full diff or a "dirty-tree" warning line
2. `bash scripts/test-pr-gate.sh` → exit 0 (includes regression for dirty-tree warning)
3. `bash scripts/run-all-tests.sh` → exit 0

**Milestone**: v0.3.x (post-M1); prioritize before the next multi-gate iterative fix session.

**Priority**: P2 — operational correctness for gate reviews; detected as real drift in CC-229 gate cycle.

---

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

## CC-262 — Executor isolation 抽象層：`isolation_level` 欄位 + adapter 轉譯契約（deferred）

**Problem**: 現行 brief schema 中 `sandbox`、`approval`、`skip_git_check` 是 Codex 原生欄位，直接出現在 PM 撰寫的 brief 裡。當 executor 為 `claude` 時，PM 必須填入 canonical no-op 值（`workspace-write` / `never` / `false`）——這是 leaky abstraction：brief 層洩漏了底層 executor 的實作細節。

**Why**: 用戶設計目標：「功能與執行環境分離」。Brief 應表達隔離 *意圖*（需要什麼程度的保護），adapter 層負責把意圖翻譯成各 executor 的原生機制。這樣未來加入新 executor（opencode、antigravity）只需新增一個 adapter map，不需改動 brief schema 或 PM 撰寫規則。與 v0.3.0 的 `adapters/` named-slot 架構完全吻合。

**Requirement**:
- `core/policy/`（CC-231 延伸）：新增 `isolation_level` enum，值為 `none | read-only | workspace-write | sandboxed`，附語意定義（none=無限制；read-only=不寫 FS；workspace-write=僅寫 project dir；sandboxed=完整隔離）
- `adapters/codex/isolation-map.yaml`：每個 `isolation_level` 值 → `{sandbox, approval, skip_git_check}` 原生欄位的對應表（v0.4.0，暫緩）
- `adapters/claude/isolation-map.yaml`：每個 `isolation_level` 值 → no-op（claude-executor 無 sandbox flags）（v0.3.0 M1 殘留，當前範圍）
- `agents/project-pm.md`：PM brief template 改寫 `isolation_level:` 取代三個原生欄位；說明三個原生欄位為 adapter-generated，PM 不直接填寫
- `scripts/codex-dispatch.sh`：dispatch 前讀取 `adapters/codex/isolation-map.yaml` 展開 `isolation_level` → 原生欄位；遇未知值 → 立即 exit 1 with error

**Acceptance (M1 scope — adapters/claude only)**:
1. `grep -q "isolation_level" core/policy/executor-enum.yaml` → match（或對應 policy 檔案）
2. `cat adapters/claude/isolation-map.yaml` → 檔案存在，包含 4 個 no-op 映射
3. `bash scripts/run-all-tests.sh` → exit 0

**Acceptance (M2 scope — deferred)**:
4. `grep "isolation_level" agents/project-pm.md` → 至少一個 match；`grep 'sandbox.*workspace-write' agents/project-pm.md` → PM brief template 區段無此行
5. `bash scripts/test-codex-dispatch.sh` → exit 0（含 isolation_level 展開測試）

**Acceptance (v0.4.0 scope — adapters/codex deferred)**:
6. `cat adapters/codex/isolation-map.yaml` → 包含全部 4 個 isolation_level 的映射

**Scope revision 2026-05-25**: adapters/codex 移至 v0.4.0；當前範圍為 M1（core/policy/ enum + adapters/claude/ no-op map）。

**M1 shipped (2026-05-25, PR #162)**: `core/policy/isolation-level.yaml` and `adapters/claude/isolation-map.yaml` created. M2 (codex-dispatch.sh expansion) and v0.4.0 (adapters/codex) remain deferred.

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

## CC-264 — Dispatch overhead reduction + executor-agnostic output contract ✅ 2026-05-28

**See**: BACKLOG-ARCHIVE.md

## CC-265 — Remove /caveman and /caveman-commit commands ✅ 2026-05-26

**See**: BACKLOG-ARCHIVE.md

## CC-266 — adapters/claude: Codex-as-PM → Claude-as-executor shell dispatch（deferred, M3）

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

**Priority**: P3 — deferred to M3；Codex-as-PM 路徑未啟用前不阻塞任何流程。

**Cross-link**: `[[CC-262]]`（isolation 抽象，M1/M2）、`[[CC-264]]`（output contract）、`[[CC-036]]`（dispatch ergonomics）。

---

## CC-267 — bug: executor:claude gate path — Write blocked in background subagent ✅ 2026-05-28

**See**: BACKLOG-ARCHIVE.md

## CC-268 — docs: run_in_background default async escalation undocumented（deferred）

**Problem**: Agent tool called without `run_in_background:true` may silently promote the subagent to async mode and return `Async agent launched successfully` instead of blocking. Observed with `codex-executor` (ran ~3m45s async without the flag). Docs say "Claude decides" but give no criteria; callers cannot reliably predict whether the dispatch blocks the main thread.

**Priority**: P3 — docs clarity only; no functional impact on existing flows.

**Proposed fix**: Document in `commands/pm.md` or `docs/executor-contract.md` which subagent types always run async, and whether/when the default blocks.

**See**: issue:#166

## CC-269 — ops: hook-save-rate-limits.sh 應寫到 pm-dispatch 自己的 state 路徑（deferred）

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

## CC-271 — process: Go build cache redirect — sandbox limitations guide ✅ 2026-05-29

**See**: BACKLOG-ARCHIVE.md

## CC-272 — process: brief template — omit commit block; document main-thread commit delegation（deferred）

**Problem**: Every brief ends with a `git add + git commit` block that `hook-codex-bash-guard` blocks. The executor marks the commit step as failed and reports `status: partial` in the output summary — even when all code changes are correct. The main thread must manually stage and commit after every dispatch. The brief template implicitly encourages adding a commit block, creating a permanent noise signal.

**Options**:
- **A (preferred)**: Remove the commit block from the brief template and document in `docs/dispatch-brief.md` that commit is always delegated to the main thread. Update `self_verify` template to stop including `git commit` as a success criterion.
- **B**: Add `git add` + `git commit` (without destructive flags) to `hook-codex-bash-guard` allowlist. Requires security review of hook policy (`[[CC-066]]`).
- **C**: `scripts/codex-dispatch.sh` reads a `.commit-msg` file written by the executor and performs the commit on its behalf; executor stays sandboxed.

**Impact**: Every dispatch shows false `status: partial`; creates a recurring manual step the main thread must remember.

**See**: issue:#173 (Pattern 3)

**Cross-link**: `[[CC-066]]` (declarative policy.yml for hook allowlist — relevant if Option B chosen)

**Priority**: P2 — every dispatch affected; Option A is pure documentation with immediate noise reduction.

---

## CC-273 — arch: unified lifecycle hook event spec（deferred）

**Problem**: CC-206 added `pre-gate.sh` / `post-gate.sh` hooks directly into `scripts/pr-gate.sh`. If future tools (e.g., `codex-dispatch.sh`, `brief-validate.sh`) also need hook points, each script will independently add its own pre/post blocks — resulting in inconsistent naming, invocation contracts, and user documentation.

**Proposed direction**: Define a shared lifecycle event spec:
- Convention: `.pm-dispatch/hooks/<event>.sh` (e.g., `hooks/pre-gate.sh`, `hooks/post-dispatch.sh`)
- Single call site in a helper (e.g., `lib/run-lifecycle-hook.sh <event>`)
- Consistent contract: runs from project root as main thread; non-zero aborts the triggering operation
- Single `docs/lifecycle-hooks.md` covering all events (supersedes the pattern docs in `sandbox-limitations.md`)

**When to activate**: When a **second** hook point is requested (not gate). Design cost before that point exceeds the benefit.

**Cross-link**: `[[CC-206]]` (first hook point — gate pre/post)

**Priority**: P3 — no current requirement; activate when second hook point emerges.

---

## CC-274 — docs: reconcile CC-262 planning text with shipped isolation implementation

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

## CC-275 — bug: pr-gate.sh exits 127 after result write due to em dash bytes misinterpreted as command ✅ 2026-05-29

**See**: BACKLOG-ARCHIVE.md

## CC-276 — feat: persistent gate override declarations to reduce re-statement across rounds

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

## CC-104d — [Windows dogfood r1] hook-codex-bash-guard.sh hardcoded read-root 🟡 deferred

**Problem**: `hook-codex-bash-guard.sh:54` defaults read-root to `$HOME/github`; repos under `~/Documents/github/` or arbitrary Windows paths are not covered. `CLAUDE_HOOK_CODEX_READ_ROOTS` env override exists but the wrong default silently restricts hooks.
**Fix**: Derive from `PM_DISPATCH_REPO` parent or remove the hardcoded default.

## CC-104e — [Windows dogfood r1] WSL ↔ Windows memory path divergence 🟡 deferred

**Problem**: Project ID is path-sanitized working dir. Same repo at `~/github/pm-dispatch` (WSL) and `C:\Users\...\github\pm-dispatch` (Windows) produces different IDs → memory is partitioned across environments.
**Fix**: Document workaround (symlink, or `PM_DISPATCH_PROJECT_ID` override); harness-level issue upstream.

## CC-104f — [Windows dogfood r1] jq hard-dependency in hooks layer 🟡 deferred

**Problem**: Hooks layer hard-depends on `jq`. Options: vendor static `gojq` binary (3 MB × 3 platforms), or expose `--no-hooks` install mode for jq-less users.
**Decision**: `--no-hooks` preferred — keeps no-auto-install principle.

## CC-104g — [Windows dogfood r1] portable.sh test fixes ⚠️ partial 2026-05-17

**Problem**: `mkdir_lock` FIFO sync passes ✅ but underlying `mkdir` on Git Bash allows second concurrent acquire — real Windows portability bug. See CC-104k for the UNC/9P root cause.
**See**: pr:#80

## CC-104j — [Windows dogfood r1/r2] test-dispatch-handover.sh symlink fixture on Git Bash 🟡 deferred

**Problem**: `brief_file_symlink_rejects_case` uses `ln -s` for fixture; on Git Bash falls back to copy → validator treats as regular file → test fails. Fix: add `[[ -L "$link" ]]` precondition → SKIP.

## CC-104k — [Windows dogfood] UNC/9P filesystem mkdir atomicity caveat 🟡 deferred

**Problem**: `mkdir` is atomic on local NTFS but NOT on `\\wsl.localhost\...` (9P UNC). Running pm-dispatch from a WSL UNC path on Windows breaks concurrent lock semantics.
**Fix**: Document install-on-local-disk caveat; add preflight UNC path detection + warning. See CC-104r for the docs/warning follow-up.

## CC-104m — [Windows dogfood] Platform layout — multi-target projection 🟡 deferred

**Problem**: pm-dispatch is currently Claude-only by install.sh target. Introduce `~/.pm-dispatch/content/` as canonical view with symlink-project to `~/.claude/` and future tool targets.
**Scope**: Post-v0.1.0, deferred until Codex/Cursor/Aider integration need surfaces.

## CC-104r — [Windows dogfood r3] hook-tool-trace.sh performance budget on Windows ⏸ deferred

**Problem**: Actual: 27990 ms vs 3500 ms budget on WSL UNC path (9P is ~8× slower than local disk). Not a pm-dispatch code bug.
**Fix**: (a) `docs/platform-support.md` warn; (b) preflight detects UNC path → skips budget assertion.

## CC-104s — [Windows dogfood r3] hook-tool-trace.sh path normalization on Git Bash 🟡 deferred

**Problem**: `read_home_path_basename_only` case-glob fails on Windows backslash paths. Fix: normalize via `cygpath`/string-replace before case-match. Affects trace JSON observability only.

## CC-277 — [backlog hygiene] fix CC-228 E-codes — reach validate.sh exit 0 ✅ 2026-05-30

**See**: BACKLOG-ARCHIVE.md

## CC-278 — [ops] validate.sh in CI — warn-only then enforce ✅ 2026-05-30

**See**: BACKLOG-ARCHIVE.md

## CC-279 — [ops] scripts/archive-closed-backlog.sh — idempotent bloat-policy executor ✅ 2026-05-30

**See**: BACKLOG-ARCHIVE.md

## CC-280 — [process] run archive-closed-backlog.sh to collapse current BACKLOG bloat ✅ 2026-05-30

**See**: BACKLOG-ARCHIVE.md

## CC-281 — [process/docs] split BACKLOG index into Active and Terminal sub-sections 🟡 deferred

**Problem**: The index table mixes 19 active/deferred rows with 99+ terminal rows. PM agents scanning the index for "what's next" must parse the entire table. Readers and agents both benefit from active rows floating to the top.

**Why**: Deferred until CC-280 (archive run) completes. Doing the split before archiving creates a larger diff and more merge risk.

**Requirement**:
1. Insert `<!-- active items above | terminal items below -->` comment between the last active/deferred row and the first terminal (✅/🚫/superseded) row.
2. Do NOT use an H2 header as the delimiter — it would break PM agent index parsing (pm-schema §6.1 assumes a single contiguous index table).
3. Update pm-schema §6.1 comment to note the comment delimiter convention.

**Cross-link**: `[[CC-280]]` (prerequisite), `[[CC-278]]` (CI enforcement keeps the split honest).

## CC-282 — [DX/product] pmctl backlog sync — SQLite derived query layer 🟡 deferred

**Problem**: Querying BACKLOG.md requires awk/grep. No fast indexed access exists for "show all active items in area:ops" or "list all M3 items". The current workaround is manual grep or reading the full index.

**Why**: Deferred until CC-215 pmctl core (M3/M4) provides the CLI entry point. SQLite as a derived store (not source of truth) enables rich queries without changing the human-editable markdown contract.

**Requirement**:
1. `pmctl backlog sync` subcommand: parses BACKLOG.md index table, writes rows to `backlog.db` (SQLite, gitignored).
2. `pmctl backlog view [--status active|deferred|closed] [--area AREA] [--milestone M3]`: queries backlog.db and renders a filtered markdown table to stdout.
3. BACKLOG.md remains the source of truth; `backlog.db` is a derived artifact (not committed).
4. `pmctl backlog sync` is idempotent and can be called by `archive-closed-backlog.sh` post-run.

**Cross-link**: `[[CC-215]]` (pmctl core), `[[CC-279]]` (archive script).

## CC-283 — [bug] archive-closed-backlog.sh sentinel false-negative 🟡 deferred

**Problem**: `scripts/archive-closed-backlog.sh` decides whether a `## CC-NNN — … ✅/🚫` section is already archived by scanning its entire body for the regex `**See**:.*BACKLOG-ARCHIVE`. A closed ticket whose body legitimately *quotes* that stub sentinel — e.g. CC-279, whose requirement text describes the stubbing behavior — matches the guard and is silently skipped. The section can never be collapsed, and once it is marked closed the validator flags `E-CLOSURE-NO-SEE` (closed section with no See stub), so a green validator now requires a manual archive of that one ticket.

**Why**: Surfaced during CC-280 (the first operational archive run): the script archived CC-275/277/278 but skipped CC-279, which had to be moved to `BACKLOG-ARCHIVE.md` by hand. Low severity (rare — only closed tickets that quote the sentinel), but it makes the archiver non-self-healing for exactly the tickets that document it.

**Requirement**:
1. Anchor stub detection so it only matches a section that *is* a stub, not one that mentions the sentinel — e.g. treat a section as already-stubbed only when its first non-empty content line is `**See**: BACKLOG-ARCHIVE.md`.
2. Add a regression fixture: a closed section whose body contains the literal string `**See**: BACKLOG-ARCHIVE.md` must still be archived exactly once.

**Cross-link**: `[[CC-279]]` (the archiver script), `[[CC-280]]` (run that surfaced it).
