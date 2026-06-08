# pm-dispatch decisions

<!--
排序：按日期倒序（最新在上）。
H2 標題格式：## YYYY-MM-DD: <短描述>
每筆必含四節：Context / Decision / Alternatives considered / Constraints introduced
與 BACKLOG closure 對應的 entry，內文首行寫：Closes: BACKLOG.md#<PREFIX>-NNN
-->

## 2026-06-08: ticket-id-collision-lint-and-cc-329-330-renumber

Closes: BACKLOG.md#CC-339

Relates: CC-339, CC-342, CC-343, CC-338, CC-328

### Context

The CC-328 → CC-338 renumber (same date) filed CC-339 as a follow-up: a divergent-title id collision is mechanically detectable, so the one-id-one-ticket invariant should be enforced by tooling, not by manual reading. While implementing CC-339 the literal framing — "compare the *title string* of an id across BACKLOG active body and MILESTONES" — proved unworkable: all three title surfaces (BACKLOG index column, BACKLOG body heading, MILESTONES description) are free-form and legitimately divergent (English title vs Chinese description; MILESTONES repeats one id across version sections with different per-milestone text). A literal string-equality check would false-positive on nearly every shared row.

### Decision

Reinterpret the invariant as a **cross-lifecycle id collision**, which is the actual fingerprint of the CC-328 failure and is string-comparison-free: the active board and the archive partition the id space, so a non-stub ticket lives in exactly one of them. `pm/scripts/lint-ticket-ids.sh` asserts no id is simultaneously **open (non-stub) on the active board** and **closed in the archive**, emitting `E-ID-COLLISION`. A ✅/🚫 tombstone stub on the active board is the legitimate mirror of the same archived ticket and is excluded. The linter is a sibling script (not folded into `validate.sh`, whose CLI signature and large test baseline stay untouched) wired into `lint.yml` as a `lint-ticket-ids` job that runs against the real BACKLOG.md + BACKLOG-ARCHIVE.md, mirroring the existing `lint-backlog` job.

On first run the lint surfaced **two pre-existing collisions** that manual reading had missed: active `debt-auditor` reused **CC-329** (a closed FSM-transition-table ticket, ✅ 2026-06-05) and active `/discover` reused **CC-330** (a closed state_store_init fix, ✅ 2026-06-05). Per the CC-328 precedent, the closed/shipped tickets keep their immutable ids; the two unstarted forward tickets are renumbered to **CC-342** (debt-auditor) and **CC-343** (/discover). The renumber and the lint land in one PR so the new gate is green on merge.

### Alternatives considered

- **Literal title-string comparison across files** (as CC-339 was originally worded): rejected — no two title surfaces are comparable (EN title vs ZH description; per-version repetition), so it cannot be implemented without mass false positives.
- **Fold the check into `validate.sh`**: rejected — would change its `<BACKLOG> [DECISIONS] [CHANGELOG]` signature and disturb every call site and the validator baseline; the archive×active check is a distinct concern with a clean sibling boundary.
- **Land the lint in warning-mode and renumber later**: rejected — the whole value is a hard gate; bundling the renumber keeps the gate green immediately and follows the close-ticket-in-feature-PR discipline.
- **Renumber the closed/archived tickets instead**: rejected — their ids are referenced in shipped history (commits/PRs/MILESTONES done rows); moving an unstarted forward ticket is cheapest, per the CC-328 decision.

### Constraints introduced

- The active board and the archive must partition the id space: closing a ticket moves it to the archive (a ✅/🚫 stub may remain on the board as a pointer), and a forward ticket must never reuse a number already closed in the archive.
- New backlog/archive changes are gated by `lint-ticket-ids` in CI; a reused-across-lifecycle id now fails the build instead of surviving to a context-pack index.

---

## 2026-06-08: cc-328-collision-renumber-repo-index-to-cc-338

Relates: CC-338, CC-328, CC-237, CC-239, CC-343, CC-339

### Context

CC-328 was assigned twice. First to the executor-agnostic `light` model-alias work (shipped via PR #229, recorded in MILESTONES v0.4.0 旁支修正); then reused by the lightweight built-in repo symbol-index ticket added in PR #235. Both labels are in git history. The collision surfaced during v0.5.0 planning, while restructuring the milestone around a dual-index (knowledge + repo) context-pack spine — a search index over BACKLOG/MILESTONES makes a divergent-title CC id actively harmful, not just untidy.

### Decision

**The shipped light-alias keeps CC-328** (its history is immutable); **the repo-index ticket is renumbered to CC-338** (a forward, not-yet-started ticket — cheapest to move). BACKLOG index row + body, MILESTONES v0.5.0, and cross-links are updated to CC-338; the v0.4.0 light-alias row gets a disambiguation note. A follow-up lint (CC-339) is filed to assert one CC id never maps to two titles across BACKLOG/MILESTONES, catching the next collision at lint time. v0.5.0 is re-scoped to the thin vertical slice `repo index (CC-338) → context-pack interface (CC-237) → reuse-scan (CC-239)`; the heavy standalone knowledge index (overlaps `/mem-search`) is deferred to v0.6.0.

### Alternatives considered

- **Renumber the shipped light-alias instead**: rejected — it is referenced in shipped commit/PR/CHANGELOG history; renumbering immutable history is more disruptive than moving an unstarted ticket.
- **Keep both as CC-328, disambiguate by context**: rejected — defeats the point of a stable id and is exactly what a search index cannot tolerate.
- **Implement the dedup lint now as part of the fix**: deferred to CC-339 — the lint is real code + tests + gate and does not belong in a docs/hygiene change; the renumber stands on its own.

### Constraints introduced

- CC-338 is the canonical id for the built-in repo index from now on; CC-328 refers only to the historical light-alias work.
- Until CC-339 lands, the one-id-one-title invariant is maintained by review, not by tooling.

---

## 2026-06-03: v0.4.0-state-first-foundation-commit

Relates: CC-211, CC-215, CC-230, CC-306

### Context

v0.3.0 shipped the spine (schema + pmctl runtime + thin adapters) but is only partially state-first. Of the 5 entities only `Run` is written, and it is written **by the adapters** (`sw_append_dispatch_run`, `adapters/codex/dispatch.sh:369`) rather than by pmctl; `events_append`/`task_upsert` exist in `scripts/lib/state-writer.sh` but have **no production caller**; `routing_log.md` is still machine-written by `hook-routing-log.sh` as a parallel markdown surface. The single-writer rule (`docs/architecture/v0.3.0-synthesis.md` Conformance §B) is unmet. Two independent brainstorms (Claude main-thread + a read-only codex pass) both recommended completing state-first next. Full scoping: `docs/architecture/v0.4.0-state-first-foundation.md`.

### Decision

**v0.4.0 headline = the state-first single-writer foundation** (CC-211 committed). pmctl becomes the sole machine-state writer; the dispatch path emits Run + Event through pmctl; `routing_log.md` machine-writes are **deprecated** in favour of `pmctl trace`. First state consumer = **`pmctl trace`** — cheap observability over `events.jsonl` to prove the stream — with the CC-235 task-lifecycle gate next. De-risked by a timeboxed **thin vertical slice** (one `pmctl dispatch run` writes Run+Event via pmctl, `routing_log.md` no longer machine-written); if it cannot land cleanly without broad rewrites, fall back to incremental DX. MCP (CC-216) and the capability layer (CC-234/237) are explicitly deferred until the foundation lands. The maintainer accepts the low short-term user-visible payoff — the current user base is small, so substrate correctness outranks shipping features.

### Alternatives considered

- **B — incremental DX first, defer state-first**: faster visible wins, but leaves the single-writer drift festering and keeps memory/task-gate/context-enricher blocked. Rejected — with few users, substrate correctness outranks visible features.
- **First consumer = CC-235 task gate**: more product-meaningful (codex's lean), but heavier and surfaces substrate problems late/expensively. Deferred to second.
- **routing_log render-on-demand projection**: backward-compatible, but keeps a second representation to maintain and risks drift vs. the event stream. Rejected for the cleaner single-source end state.

### Constraints introduced

- Adapters and hooks must NOT write machine state directly; pmctl is the only writer. CC-306 layer-enforcer to be extended to guard re-introduction.
- Run+Event writes are append-only; the Event is written after the Run with a `run_id` back-reference, so a partial pair (Run without terminal Event) is detectable/recoverable.
- `routing_log.md` deprecation needs a migration / back-compat path (precedent: `scripts/migrate-routing-log.sh`).
- **Foundation scope is the full substrate, not just writes** (2026-06-03 follow-up): pmctl validates appends against `core/schema/*` (D-validate); owns the **read/query** path — by id/task/kind/time-window (D6); implements **rotation** to gz archives per `layout.yaml` so the append-only stores stay bounded (D7); and **canonical write failures surface** (non-zero/visible) instead of silent best-effort (D8). Sidecar telemetry (`rate-limits.json`, `usage-tracker.jsonl`) classification — state vs exempt — is deferred (D5).

---

## 2026-05-30: pmctl-spine-scope-and-host-independent-executor

### Context

pmctl was a ~1.2KB stub (CC-215 ⚠️ partial): only `adapter generate` + a `dispatch run` stub shipped. The maintainer's goal: a maintainable architecture with the upper (adapter) and lower (runtime) layers separated, such that switching between claude and codex changes **only the executor** — all other logic is shared. A second requirement surfaced: the current claude executor relies on `Agent()` (only available when Claude is the main thread), so codex-as-PM cannot dispatch claude-as-executor — the 4-cell PM×executor matrix is broken.

### Decision

**pmctl enters v0.3.0 as the runtime spine**, scoped to three load-bearing subcommands; the rest defer to v0.4.0.

1. **Host-independent executor**: the canonical executor invocation is a **CLI subprocess** (`claude --print`, `codex exec`), driven uniformly by `pmctl dispatch run --adapter <X>`, independent of which tool is the PM/host. `Agent()`-spawn (`agents/claude-executor.md`) is demoted to a same-host optimization for when Claude is the PM. This makes all 4 PM×executor cells work.
2. **Approach B (thin adapters)**: pmctl OWNS the shared dispatch flow (brief → guard → route → invoke → read output contract → post-verify), composing the M2-extracted libs. Adapters (`adapters/{claude,codex}/dispatch.sh`) are thin: executor invocation + `.agent-trace/latest.last` glue only. The 475-line `codex-dispatch.sh` is slimmed into `adapters/codex/dispatch.sh`. Rejected approach A (pmctl wraps the fat script) because the claude adapter would re-implement shared logic → drift, breaking "only the executor differs".
3. **v0.3.0 spine = `pmctl backlog` (CC-287) + `pmctl guard check` (CC-288) + `pmctl dispatch run` (CC-289)** + the two thin adapters (CC-289 codex, CC-266 claude) + the layer-boundary test (CC-233). These three surfaces = PM + security + execution.
4. **Milestone restructure**: pmctl spine inserted as M3 (runtime sits below adapters architecturally); the old "Claude adapter" M3 → M4 (Claude command/skill surface: CC-059, CC-061); concept-absorption M4 → M5; spike+release M5 → M6.

### Alternatives considered

- **Approach A** (pmctl wraps fat codex-dispatch.sh): faster, but adapters stay fat and drift — rejected (fails the maintainability/separation goal).
- **Full pmctl in v0.3.0** (task/decision/trace/validate/safe-bash too): too large for a single maintainer; those are state-ops/niceties, not load-bearing for the host-independence thesis — deferred to v0.4.0.
- **Keep claude-executor `Agent()`-only**: leaves codex-as-PM → claude-executor permanently broken — rejected.

### Constraints introduced

- Guard trigger is necessarily per-adapter (Claude PreToolUse auto-hook vs explicit `pmctl guard check`); only the guard **logic** is shared. Accepted as inherent CLI-capability difference.
- CC-266 must begin with a Phase-1 feasibility check: headless `claude -p` must satisfy the executor output contract before full implementation; if it cannot, the claude-executor mechanism needs rethinking.
- `scripts/test-layer-boundaries.sh` (CC-233) is the executable enforcer that keeps thin adapters from re-absorbing shared logic.

## 2026-05-30: backlog-working-set-contract

Closes: BACKLOG.md#CC-284

### Context

`pm/schema.md` §4 intentionally kept terminal tickets in `BACKLOG.md` forever:
closed/dropped body sections were collapsed to a `**See**: BACKLOG-ARCHIVE.md`
stub but **index rows were never removed** (old §4: "index row 保留、不移除").
`BACKLOG.md` therefore grew monotonically — at the time of this decision 87 of
158 index rows (>50%) were terminal, and ~400 lines were dead stubs + rows. Two
independent analyses (Claude main thread + Codex gpt-5.4) converged: the root
cause of growth is historical ballast retained in the working file, and a query
layer (`pmctl backlog`, CC-282) would sit on top of the mess without removing it.

### Decision

`BACKLOG.md` becomes a **working set**: it carries only non-terminal tickets
(active / deferred / someday / ⚠️ partial / `✅ done` soft-close). A terminal
ticket — index status `✅ closed YYYY-MM-DD` or `🚫 dropped YYYY-MM-DD` — has
**both its index row and its body section removed**; the body moves to
`BACKLOG-ARCHIVE.md` with **no `**See**:` stub** left behind. Status is read
from the index Status column (§6.1). `scripts/archive-closed-backlog.sh` was
rewritten to implement this (and the rewrite dissolves the CC-283 sentinel
false-negative, since dedup now matches archived headings rather than scanning
body prose for `**See**:`). This is a §4 policy + archiver change, not a parse
change, so the `<!-- pm-schema: v1.2 -->` file marker is unchanged and
validate.sh is untouched.

Closed-ticket lookup is by `grep BACKLOG-ARCHIVE.md` (headings carry id / status
/ date) or git history (full row metadata). This PR ships the mechanism +
contract only; the one-time migration of the existing 87 terminal rows is a
follow-up (PR-B).

### Alternatives considered

- **Split index into Active/Terminal in-place (CC-281)**: readability patch
  only; does not bound file growth. Rejected as insufficient.
- **`pmctl backlog sync` → SQLite (CC-282)**: ergonomics/query layer; leaves the
  markdown source bloated. Deferred — it now sits on the stabilized shape.
- **Rebuild a full index table inside BACKLOG-ARCHIVE.md**: preserves row
  metadata but adds archive-structure complexity and migration risk. Rejected
  for PR-A; row metadata is recoverable from git history, and a derived archive
  index can be generated later by `pmctl backlog`.
- **Keep stubs, just drop rows**: leaves orphan `**See**:` bodies with no index
  entry, tripping the validator's index↔body 1:1 invariant. Rejected.

### Constraints introduced

- The archiver determines terminal status from the **index** row, not the body
  heading; a future tool that closes a ticket must update the index Status
  column for archival to pick it up.
- Backward compatibility is preserved: pre-existing `**See**:` stubs remain
  valid input (swept on next run); `validate.sh` is unchanged and treats both
  "ticket absent" and "ticket stubbed" as passing, so other pm-schema repos are
  not broken until they choose to run the new archiver.
- Full closed-ticket index metadata (area/refs/priority) is no longer in the
  live file; it lives in git history and the archived body heading.
- Accepted tradeoff: the archiver drops a terminal index row even when no body
  section accompanies it. In a valid backlog this cannot happen (validate.sh
  enforces index↔body 1:1); it only arises from malformed/partial state, is
  git-recoverable, and the archiver emits a per-id stderr warning rather than
  removing it silently. Not treated as a hard data-loss path.

## 2026-05-25: state-root-xdg

### Context

The original state-store default path was `~/.claude/.pm/state/` — chosen because
`~/.claude/` was already installer-managed. The `core/README.md` invariant #2 prohibits
CLI product names as path segments (`claude` qualifies), creating a self-contradiction.

### Decision

Default state root changed to `~/.local/share/pm-dispatch/state/` (XDG Base Directory
spec). Override env var renamed `CLAUDE_PM_STATE_ROOT` → `PM_DISPATCH_STATE_ROOT`.
Added `store_root_xdg_subpath: "pm-dispatch/state"` to `core/state/layout.yaml` so
the runtime writer can apply XDG_DATA_HOME precedence without hardcoding paths.

Resolution order (runtime writer must implement):
1. `$PM_DISPATCH_STATE_ROOT` (explicit override)
2. `$XDG_DATA_HOME/pm-dispatch/state` (if XDG_DATA_HOME set)
3. `~/.local/share/pm-dispatch/state` (fallback)

### Alternatives considered

- Keep `~/.claude/.pm/state/` with a documented exception to invariant #2 — rejected:
  defeats the CLI-agnostic goal and forces future forks to carry the exception.
- `~/.pm-dispatch/state` — simpler but adds a new dotdir; XDG path is more
  standard on Linux and avoids home-dir clutter.

### Constraints introduced

- `CC-230` (`state-writer.sh`) must implement the 3-level resolution order.
- Any docs/spikes referencing `~/.claude/.pm/state/` are historical artifacts of
  the pre-decision design; authoritative path is now in `core/state/layout.yaml`.

## 2026-05-19: cc030-validate-bidirectional

Closes: BACKLOG.md#CC-030

### Context

validate.sh 原本只做 Index→Body 的單向一致性檢查（index row 有對應 body section 才合法）。
Body→Index 方向（孤立 section 沒有 index row）、closure date 對齊（E-CLOSURE-DATE-MISMATCH）、以及 CHANGELOG drift（E-CHANGELOG-DRIFT）均已在 PR #93（CC-052）前後陸續實作。

CC-030 的目標是確認雙向一致性全覆蓋，並補充缺漏的 fixture。

### Decision

透過程式結構驗證（validate.sh）實施雙向 Index↔Section 一致性，而不依賴 reviewer 紀律。
補充 `bad-orphan-section` fixture 驗證 direction (b)：body section 存在但 index row 缺失 → E-INDEX-MISMATCH。
38 tests pass（含新 fixture）。

### Alternatives considered

- 只文件化規範、靠 PM agent 紀律維持 — 無法在 CI 被偵測，drift 會隨時間累積。
- 在 PM agent 提示詞加 lint 提醒 — prompt 層 enforcement 不可靠，結構 validator 是唯一穩固邊界。

### Constraints introduced

- validate.sh E-INDEX-MISMATCH 同時涵蓋兩個方向；fixture 需兩者皆有對應測試案例。
- 新 fixture 命名規範：`bad-orphan-section`（body-only 孤立 section）、`bad-index-mismatch`（index-only 孤立 row）。

## 2026-05-19: Deprecate ID-gap convention

Closes: BACKLOG.md#CC-067

### Context

pm-schema v1.1（CC-052，PR #93）在 BACKLOG index table 引入顯式 `epic` 欄位（`oss` / `reuse-debt` / `hygiene` / `—`），提供機器可讀的分組依據。在此之前，pm-dispatch BACKLOG 以 ID 保留範圍慣例（CC-1NN = OSS epic、CC-2NN = reuse-debt）作為語義分組 workaround。隨著 ticket 數量自然增長至 CC-100 以上，流水號與保留範圍的邊界衝突將成為現實問題。

### Decision

廢棄 ID gap 慣例。從此以後 `epic` 欄位是唯一權威分組訊號；新增 ticket 統一以「目前最大號 + 1」遞增，不再為語義分組跳號或保留 ID 空間。既有 CC-1NN/CC-2NN 的 ticket ID 維持不動（歷史穩定）。`pm/schema.md §2.4.5` 和 BACKLOG.md Convention 章節移除 ID gap 文件說明。

### Alternatives considered

- 維持 ID gap 慣例 — 隨著 ticket 數量增長，合法流水號將進入「保留」範圍，製造歧義；且 `epic` 欄已提供更好的替代。
- 重排既有 ID（將 CC-1NN/CC-2NN 重編） — 違反 ID 永久穩定原則，git history 引用也需同步更新，成本高風險大。

### Constraints introduced

- 新增 ticket 不可為語義分組跳號或保留 ID 空間；`epic` 欄位是唯一分組機制。
- 若未來需要新增 epic 類型，依 `pm/schema.md §2.4.5` 規定更新 schema 並 bump patch version。

---

## 2026-05-19: cc046-validate-dedup

Closes: CC-046

**Context**: validate.sh Pass 2 (`note_index_refs`) re-implemented the
status emoji→kind mapping that Pass 1's `parse_status()` already covers.
`run_validate_case_multi` in run-tests.sh was a copy-paste of
`run_validate_case` with only arg-order differences.

**Decision**: Extract `status_kind()` helper in Pass 2's awk block; merge
`run_validate_case_multi` into a varargs `run_validate_case` and migrate
all 34 call sites. No behavior change — pure dedup.

**Amendment (2026-05-19)**: Gate advisory (critic + arch-reviewer) correctly identified
that `status_kind()` as a Pass-2-local function still left two independent awk programs
with separate status classifiers. Fix: merged Pass 1 and Pass 2 into a single awk
invocation. `parse_status()` (Pass 1) now sets `row_kind[id]`; `parse_index_row()`
reuses `row_kind[id]` for PR-token drift tracking. `note_index_refs()` and
`status_kind()` are both removed. No behavior change.

**Constraints**: Tests (run-tests.sh) must remain green; no new fixtures
needed; no schema version bump.
