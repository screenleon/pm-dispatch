#!/usr/bin/env bash
# pmctl ship <id>/prepare/finish -- the deterministic, scriptable bookends of
# the ship contract (commands/ship.md, CC-439): Step 0 (ticket-id validate +
# consistency-check surface) and Step 1 (branch) live in `prepare` (and its
# unified-entry equivalent, `pmctl_ship_run`); Step 3 (one gate round) and
# Step 4 (PR on GO) live in `finish`. Step 2 (implement) is NOT scriptable --
# it requires an agent (this session, or a dispatched executor) to actually
# read/write code -- so it is never a pmctl subcommand; it happens between
# one start call and one-or-more `finish` calls (finish is re-invoked after
# each round of fixes, same NO-GO loop discipline `/ship` already uses, just
# with the mechanical parts scripted).
#
# `pmctl_ship_run` (CC-442/CC-443) is the unified START entry point and the
# SOLE canonical implementation of every path below -- older names redirect
# INTO it, never the reverse, so a future decision to retire one of them
# only ever touches one call site:
#   pmctl ship <ticket-id>                       -- manual, in place (pmctl ship prepare <id> is a thin alias for this)
#   pmctl ship <ticket-id> --worktree             -- manual, isolated worktree, no dispatch
#   pmctl ship <ticket-id> --adapter <name>       -- dispatch; --adapter always implies --worktree
#   pmctl ship <ticket-id> --worktree --adapter <name>  -- legal, identical to --adapter alone
#   pmctl ship --parallel <id...> --adapter <name>      -- batch sugar: pmctl-ship-parallel.sh
#                                                            calls pmctl_ship_run once per ticket
# `pmctl ship finish` is deliberately NOT folded into this entry point (CC-442
# spike decision): it is a hardened, allowlisted primitive (branch-identity
# guard, gh preflight, pre/post-gate HEAD-drift guard) with its own explicit
# verb, and `--worktree`/`--adapter` have no meaning once a lane already
# exists. `pmctl ship prepare <id>` also stays as an explicit, permanent
# alias for the in-place case -- not deprecated, not removed.

if ! declare -F pm_identifier_operation_is_valid >/dev/null 2>&1; then
  _pmctl_ship_lib_dir="${BASH_SOURCE[0]%/*}"
  [[ "$_pmctl_ship_lib_dir" == "${BASH_SOURCE[0]}" ]] && _pmctl_ship_lib_dir=.
  # shellcheck source=runtime/lib/identifier-policy.sh
  # shellcheck disable=SC1091
  . "$_pmctl_ship_lib_dir/identifier-policy.sh"
  unset _pmctl_ship_lib_dir
fi

if ! declare -F gate_publish_assessment_build >/dev/null 2>&1; then
  # shellcheck source=runtime/lib/gate-publish.sh
  # shellcheck disable=SC1091
  . "${BASH_SOURCE[0]%/*}/gate-publish.sh"
fi
# Test seams may replace the publish builder before this library is sourced.
# Load the small canonical Gate subject owner independently so those seams
# cannot accidentally select a weaker fingerprint implementation or import
# unrelated result-verifier producers.
if ! declare -F _gate_subject_tree_fingerprint >/dev/null 2>&1; then
  # shellcheck source=runtime/lib/gate-subject.sh
  # shellcheck disable=SC1091
  . "${BASH_SOURCE[0]%/*}/gate-subject.sh"
fi
# The final publication check also recomputes the Gate subject fingerprint.
# gate-publish.sh loads the canonical Gate subject implementation; there is no
# weaker local fallback because publication must never use a different subject
# fingerprint algorithm merely because a shared helper was not loaded.
_pmctl_ship_tree_fingerprint() {
  local work_dir="$1" subject_kind="$2" head_commit="$3"
  if ! declare -F _gate_subject_tree_fingerprint >/dev/null 2>&1; then
    printf 'pmctl ship: canonical Gate subject fingerprint helper is unavailable\n' >&2
    return 2
  fi
  _gate_subject_tree_fingerprint "$work_dir" "$subject_kind" "$head_commit"
}

_pmctl_ship_worktree_status() {
  # The finish marker is an intentionally untracked runtime state artifact.
  # Exclude only that exact root path; every source or user change remains
  # visible to the publication guards.
  git -C "$1" status --porcelain -- . ':(exclude).pm-dispatch-ship-finish.json' 2>/dev/null
}

pmctl_ship_usage() {
  printf 'usage: pmctl ship <ticket-id> [--worktree] [--adapter <name>] [--from <base>] [--isolation <level>] [--model <alias>] [--auto-pack|--no-auto-pack] [--cd <work_dir>]\n' >&2
  printf '           Start a manual ship lane. Bare: in the current worktree (alias: prepare). --worktree: isolated worktree, no dispatch. --adapter: dispatch (implies --worktree).\n' >&2
  printf '           After implementation, run: pmctl ship finish <ticket-id>\n' >&2
  printf '       pmctl ship prepare <ticket-id> [--cd <work_dir>]\n' >&2
  printf '       pmctl ship finish  <ticket-id> [--cd <work_dir>] [--reviewers <r,...> | --gate-result <artifact>] [--full-result <artifact>]\n' >&2
  printf '       pmctl ship --parallel <ticket-id> [<ticket-id>...] [--from <base>] [--adapter <name>] [--isolation <level>] [--model <alias>] [--cd <work_dir>]\n' >&2
  printf '       pmctl ship status [--cd <work_dir>] [--json]\n' >&2
  printf '       pmctl ship list   [--cd <work_dir>] [--json]\n' >&2
}

# _pmctl_ship_id_shape_ok <ticket_id>
_pmctl_ship_id_shape_ok() {
  [[ "$1" =~ ^[A-Z][A-Z0-9]*-[0-9]+$ ]]
}

# _pmctl_ship_heading_exists <file> <ticket_id>
# The ONE shared "does `## <ticket_id>` exist as its own heading" check --
# used by both `pmctl ship prepare` and `pmctl ship --parallel`'s pre-flight
# (previously duplicated in pmctl-ship-parallel.sh and had independently
# drifted into the same bug: a literal/prefix substring match on the
# ticket id, e.g. checking id `CC-90` would match a heading `## CC-9001 —
# ...` because "## CC-9001" starts with the literal substring "## CC-90").
# Exact-matches the ticket id token: requires it be followed immediately by
# either end-of-line or a non-alnum character (space, em dash, etc.), not
# another digit/letter that would make it a DIFFERENT, longer ticket id.
# Callers MUST validate shape first (_pmctl_ship_id_shape_ok) -- this
# function does not re-check shape, only exact-match existence.
_pmctl_ship_heading_exists() {
  local file="$1" ticket_id="$2"
  [[ -f "$file" ]] || return 1
  awk -v want="## $ticket_id" '
    {
      prefix = substr($0, 1, length(want))
      if (prefix == want) {
        next_char = substr($0, length(want) + 1, 1)
        if (next_char == "" || next_char !~ /[A-Za-z0-9]/) { found = 1 }
      }
    }
    END { exit !found }
  ' "$file"
}

# _pmctl_ship_ticket_section_body <file> <ticket_id>
# Prints the body of BACKLOG.md's `## <ticket_id>` section -- every line
# from that heading (exclusive) to the next `## ` heading or the `---`
# divider that closes it (exclusive). Shared by both
# _pmctl_ship_ticket_declared_paths and _pmctl_ship_ticket_goal_summary
# (CC-584) so the two never drift on what counts as "this ticket's text".
# Prints nothing (not an error) when the heading doesn't exist.
_pmctl_ship_ticket_section_body() {
  local file="$1" ticket_id="$2"
  [[ -f "$file" ]] || return 0
  awk -v want="## $ticket_id" '
    {
      prefix = substr($0, 1, length(want))
      if (in_section && ($0 == "---" || $0 ~ /^## /)) { exit }
      if (prefix == want) {
        next_char = substr($0, length(want) + 1, 1)
        if (next_char == "" || next_char !~ /[A-Za-z0-9]/) { in_section = 1; next }
      }
      if (in_section) { print }
    }
  ' "$file"
}

# _pmctl_ship_ticket_requirement_body <file> <ticket_id>
# Prints ONLY the ticket's `Requirement`/`**Requirement**` sub-section --
# from that label line (inclusive) to the next bold-labeled line (e.g.
# `**Non-goals**：`, `**Done-when**：`, `**See**:`) or plain-labeled line
# (e.g. the test fixtures' `Dependencies: none.`), exclusive. Shared by
# _pmctl_ship_ticket_declared_paths and _pmctl_ship_ticket_goal_summary
# (CC-584) so the two never drift on what counts as "the declared scope".
# Deliberately narrower than the whole ticket section
# (_pmctl_ship_ticket_section_body): CC-584 gate round 6 -- all five
# reviewers converged -- caught that scanning the WHOLE section let a path
# merely CITED in Problem/Why prose (for context, not as an edit target)
# be treated as commit-authorized; only Requirement is an edit declaration.
# Prints nothing (not an error) when the ticket or the label doesn't exist.
_pmctl_ship_ticket_requirement_body() {
  local file="$1" ticket_id="$2" body
  body="$(_pmctl_ship_ticket_section_body "$file" "$ticket_id")"
  [[ -n "$body" ]] || return 0
  awk '
    /^\*{0,2}Requirement\*{0,2}[:：]/ { in_req = 1 }
    in_req && !/^\*{0,2}Requirement\*{0,2}[:：]/ && /^\*{0,2}[A-Za-z][A-Za-z0-9 _-]*\*{0,2}[:：]/ { exit }
    in_req { print }
  ' <<<"$body"
}

# _pmctl_ship_ticket_declared_paths <file> <ticket_id>
# Prints every backtick-quoted, path-shaped token found in the ticket's
# Requirement sub-section (see _pmctl_ship_ticket_requirement_body) -- one
# repo-relative path per line, deduped -- as this ticket's declared
# edit-path allowlist (CC-584). `pmctl_ship_finish` stages only these paths
# (plus its own bookkeeping ignore-list) for a dispatched lane's
# auto-commit, refusing anything else the executor touched. "Path-shaped"
# requires a trailing `.<ext>` (so a bare command name like `git commit`,
# which has neither a dot nor -- unlike a real deliverable -- any reason to
# be a declared edit target, never matches); a `/` is NOT required, since a
# ticket legitimately declares a repository-ROOT deliverable (the CC-584
# ticket's own real-dogfood evidence: `SECOND.md`). The path need not
# already exist on disk -- a ticket's Requirement legitimately names a file
# the dispatch is about to create. Prints nothing (not an error) when the
# Requirement sub-section has no such token -- callers decide how to treat
# an empty allowlist.
_pmctl_ship_ticket_declared_paths() {
  local file="$1" ticket_id="$2"
  # shellcheck disable=SC2016 # the grep pattern below is a literal backtick match, not an unexpanded variable
  _pmctl_ship_ticket_requirement_body "$file" "$ticket_id" \
    | grep -oE '`[A-Za-z0-9_./-]+\.[A-Za-z0-9]+`' \
    | tr -d '`' \
    | sort -u \
    || true
  # `grep -oE` with zero matches (a legitimate outcome -- see the doc
  # comment above) exits 1, and with `pipefail` (this file's callers all run
  # under `set -e -o pipefail`) that makes the WHOLE pipeline's status 1 too
  # -- unguarded, that would abort the caller instead of just yielding an
  # empty allowlist. `|| true` is appended to this SAME pipeline statement
  # deliberately: `set -e` aborts as soon as a simple command fails, so a
  # guard on any later, separate statement would never run.
}

# _pmctl_ship_ticket_goal_summary <file> <ticket_id>
# Prints a short (<=72 char), single-line summary of the ticket's stated
# goal -- the text following the `Requirement:` label in its Requirement
# sub-section (see _pmctl_ship_ticket_requirement_body), truncated -- for
# the dispatched-lane auto-commit's subject line (CC-584 gate finding
# critic-F001: a bare "ship: <ticket-id>" message wasn't traceable to which
# deliverable it was without reopening the ticket). Prints nothing when the
# ticket has no Requirement label.
_pmctl_ship_ticket_goal_summary() {
  local file="$1" ticket_id="$2" body summary
  body="$(_pmctl_ship_ticket_requirement_body "$file" "$ticket_id")"
  [[ -n "$body" ]] || return 0
  # Line 1 of this body IS the label line (see
  # _pmctl_ship_ticket_requirement_body): strip the label to get any
  # same-line content.
  summary="$(sed -nE '1s/^\*{0,2}Requirement\*{0,2}[:：][[:space:]]*//p' <<<"$body")"
  if [[ -z "$summary" ]]; then
    # The label line carries nothing after the colon (this project's own
    # ticket convention: the label sits alone, the content is the next
    # line(s), often a `- ` bulleted list) -- fall back to the first
    # non-empty line after it, with any leading bullet marker stripped.
    local total_lines i next_line
    total_lines="$(wc -l <<<"$body")"
    for ((i = 2; i <= total_lines; i++)); do
      next_line="$(sed -n "${i}p" <<<"$body")"
      next_line="$(sed -E 's/^[[:space:]]*[-*][[:space:]]+//' <<<"$next_line")"
      [[ -n "${next_line//[[:space:]]/}" ]] && { summary="$next_line"; break; }
    done
  fi
  # Collapse any leading/trailing whitespace left after the substitutions
  # above (a Requirement line/next-line can still start with blank/indent
  # noise the regexes didn't anticipate).
  summary="$(sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//' <<<"$summary")"
  [[ -n "$summary" ]] || return 0
  if [[ "${#summary}" -gt 72 ]]; then
    summary="${summary:0:69}..."
  fi
  printf '%s\n' "$summary"
}

# pmctl_ship_prepare <repo_root> <work_dir> <ticket-id>
# Explicit, permanent CLI-facing alias for pmctl_ship_run's in-place path
# (no --worktree, no --adapter) -- kept for CC-439/CC-441 script callers and
# muscle memory (`pmctl ship prepare <id>`), NOT deprecated, NOT removed.
# pmctl_ship_run is the sole canonical implementation of this logic; this
# alias only forwards to it (not the other way around), so a future
# decision to retire the `prepare` name has exactly one place to change.
pmctl_ship_prepare() {
  pmctl_ship_run "${1:-}" "${2:-}" "${3:-}"
}

# pmctl_ship_verify_full_suite <work_dir> [full-result-artifact]
# Runs or verifies the canonical, tree-bound authoritative full-suite evidence
# required before an official ship path may publish. A supplied artifact is
# never trusted by name or exit code: the canonical verifier checks its full
# contract, suite registry, zero-skip status, and current-tree fingerprints.
pmctl_ship_verify_full_suite() {
  local work_dir="${1:-}" supplied_result="${2:-}"
  local runner result_file
  PMCTL_SHIP_FULL_RESULT_FILE=""
  runner="$work_dir/tests/bin/run-tests.sh"
  if [[ ! -x "$runner" ]]; then
    printf 'pmctl ship finish: canonical full-suite runner is unavailable: %s\n' "$runner" >&2
    return 2
  fi

  if [[ -n "$supplied_result" ]]; then
    if [[ "$supplied_result" == /* ]]; then
      result_file="$supplied_result"
    else
      result_file="$work_dir/$supplied_result"
    fi
  else
    result_file="$work_dir/.pm-dispatch/test-results/ship-full-$(git -C "$work_dir" rev-parse HEAD 2>/dev/null).json"
    mkdir -p "$(dirname "$result_file")" || return 2
    printf 'pmctl ship finish: running authoritative full suite for the current tree\n' >&2
    if ! (cd "$work_dir" && "$runner" --all --result-file "$result_file"); then
      printf 'pmctl ship finish: authoritative full suite failed; refusing to push or open a PR\n' >&2
      return 1
    fi
  fi

  if ! (cd "$work_dir" && "$runner" --verify-full "$result_file"); then
    printf 'pmctl ship finish: authoritative full-suite evidence is not valid for the current tree; refusing to push or open a PR\n' >&2
    return 1
  fi
  PMCTL_SHIP_FULL_RESULT_FILE="$result_file"
  printf 'pmctl ship finish: verified current-tree authoritative full-suite PASS: %s\n' "$result_file" >&2
}

# pmctl_ship_finish <repo_root> <work_dir> <ticket-id>
#                   [--reviewers <r,...> | --gate-result <artifact>]
#                   [--full-result <artifact>]
# By default, runs ONE maintainer-policy gate round in work_dir. A caller may
# instead supply one explicit, current-tree gate result; finish never guesses or
# scans for a "latest" result. An accepted GO continues to the full-suite and
# publication boundaries. NO-GO prints the verdict/result path and exits 1.
pmctl_ship_finish() {
  local repo_root="${1:-}" work_dir="${2:-}" ticket_id="${3:-}"
  shift 3 || true
  [[ -n "$work_dir" ]] || work_dir="$repo_root"
  local reviewers="" gate_result="" full_result="" args=("$@") i=0
  while [[ $i -lt ${#args[@]} ]]; do
    case "${args[$i]}" in
      --reviewers)
        [[ -n "${args[$((i+1))]:-}" ]] || { printf 'pmctl ship finish: --reviewers requires a value\n' >&2; return 2; }
        reviewers="${args[$((i+1))]}"; i=$((i+2)) ;;
      --gate-result)
        [[ -n "${args[$((i+1))]:-}" ]] || { printf 'pmctl ship finish: --gate-result requires an artifact path\n' >&2; return 2; }
        gate_result="${args[$((i+1))]}"; i=$((i+2)) ;;
      --full-result)
        [[ -n "${args[$((i+1))]:-}" ]] || { printf 'pmctl ship finish: --full-result requires an artifact path\n' >&2; return 2; }
        full_result="${args[$((i+1))]}"; i=$((i+2)) ;;
      -h|--help) pmctl_ship_usage; return 0 ;;
      *) printf 'pmctl ship finish: unknown option: %s\n' "${args[$i]}" >&2; return 2 ;;
    esac
  done

  if [[ -z "$ticket_id" ]]; then
    printf 'pmctl ship finish: <ticket-id> is required\n' >&2
    return 2
  fi
  if [[ -n "$gate_result" && -n "$reviewers" ]]; then
    printf 'pmctl ship finish: --gate-result cannot be combined with --reviewers; reviewers only apply to a new Gate run\n' >&2
    return 2
  fi
  if [[ -z "$gate_result" ]] && ! declare -F pmctl_gate_run >/dev/null; then
    printf 'pmctl ship finish: pmctl gate unavailable\n' >&2
    return 2
  fi

  # Branch/ticket-identity guard, checked BEFORE the gate even runs: the
  # `pmctl ship finish:*` Bash allowlist entry (runtime/lib/allowlist.sh)
  # pre-approves this whole command for a headless, unattended executor --
  # without this check, `finish` would push/PR WHATEVER branch happens to
  # be checked out in work_dir, regardless of the ticket_id argument. A
  # wrong `--cd`, a stale worktree, or a confused model call could then
  # publish an unrelated branch after a GO verdict that reviewed something
  # else entirely. Every lane is created by `pmctl worktree create` /
  # `pmctl ship prepare` on exactly `feat/<ticket-id>` (CC-439/CC-441
  # contract), so this is not a new constraint -- it is making an existing
  # invariant enforced instead of assumed.
  local expected_branch current_branch
  expected_branch="feat/$ticket_id"
  current_branch="$(git -C "$work_dir" rev-parse --abbrev-ref HEAD 2>/dev/null)"
  if [[ "$current_branch" != "$expected_branch" ]]; then
    printf 'pmctl ship finish: refusing -- checked-out branch (%s) does not match the ticket (%s expects %s). This lane may be pointed at the wrong worktree.\n' \
      "${current_branch:-unknown}" "$ticket_id" "$expected_branch" >&2
    return 1
  fi

  # CC-584: an --adapter-dispatched lane's executor can implement the ticket
  # but can never itself `git add`/`git commit` -- codex's workspace-write
  # sandbox refuses ANY write under .git/ (confirmed: `git commit` there fails
  # with "Unable to create .../.git/index.lock: Read-only file system", even
  # in a plain non-worktree clone), matching docs/sandbox-limitations.md
  # Pattern 4's rule that commit is always the main thread's job. `finish`
  # running here, on the host, outside any executor sandbox, IS that main
  # thread -- so for a lane this process itself dispatched, stage and commit
  # any pending lane changes before gating, instead of requiring the caller to
  # have already committed. Gated on lane provenance (ship-lanes.jsonl's
  # tracked adapter for this exact ticket+path) so a manual/in-place lane --
  # where the existing "commit before finish" contract already holds and is
  # covered by case_finish_go_dirty_tree_refuses_push -- is never affected.
  if _pmctl_ship_lane_was_dispatched "$repo_root" "$work_dir" "$ticket_id"; then
    local pre_ensure_status
    # `--untracked-files=all` is required here, not merely the default
    # (`normal`) mode: without it, git collapses an entirely-new untracked
    # directory into a single `?? dir/` porcelain line instead of listing
    # the individual file(s) inside it, so a declared path like
    # `notes/output.md` created fresh (its parent directory is new too)
    # would never exact-match anything in the per-path allowlist check
    # below -- it would show up only as the undeclared-looking `notes/`.
    pre_ensure_status="$(git -C "$work_dir" status --porcelain --untracked-files=all 2>/dev/null)"
    if [[ -n "$pre_ensure_status" ]]; then
      # Whether `.gitignore` was ALREADY dirty before the host's own patch
      # below -- i.e. the executor itself modified it -- decides whether it
      # gets the "host-authored bookkeeping" staging exception further down
      # (CC-584 gate finding, all five reviewers converged: an unconditional
      # `.gitignore` exception let an executor-authored ignore-rule change
      # slip past the declared-path allowlist and hide collateral output
      # from the very porcelain status this staging decision reads).
      local gitignore_pre_dirty=0
      grep -qE '^.. \.gitignore$' <<<"$pre_ensure_status" && gitignore_pre_dirty=1
      _pmctl_ship_ensure_gitignore "$work_dir"
      local dirty_status
      # Same `--untracked-files=all` requirement as pre_ensure_status above.
      dirty_status="$(git -C "$work_dir" status --porcelain --untracked-files=all 2>/dev/null)"
      if [[ -z "$dirty_status" ]]; then
        # Every dirty path was pm-dispatch's own bookkeeping and is now
        # gitignored -- explicit, not silent (CC-584 gate finding qa-F002):
        # a truly empty dispatch result must be distinguishable from one
        # that produced a real, committed deliverable.
        printf 'pmctl ship finish: dispatched lane for %s had only pm-dispatch bookkeeping changes (now gitignored) -- no ticket deliverable to commit; continuing to gate the existing HEAD.\n' "$ticket_id" >&2
      else
        # Stage only the ticket's declared edit-path allowlist (CC-584 gate
        # findings critic-F001/qa-F001/architecture-F001/security-F001):
        # `git add -A` would hand a dispatched executor unbounded commit
        # authority over the whole worktree, including any unrelated,
        # sensitive, or ambiently-present file. Refuse outright, before
        # staging anything, on any dirty path this lane did not declare.
        local declared_paths declared_line
        declared_paths="$(_pmctl_ship_lane_declared_paths "$repo_root" "$work_dir" "$ticket_id")"
        if [[ -z "$declared_paths" ]]; then
          # Backticks below are literal Markdown code spans, not command substitution.
          # shellcheck disable=SC2016
          printf 'pmctl ship finish: refusing to auto-commit dispatched changes for %s -- this lane recorded no declared edit-path allowlist (BACKLOG.md'\''s `## %s` section had no backtick-quoted file path to derive one from). Commit the intended files manually, or add explicit backtick-quoted paths to the ticket'\''s Requirement section and re-dispatch, then re-run finish.\n' \
            "$ticket_id" "$ticket_id" >&2
          return 1
        fi
        local -A _declared_set=()
        while IFS= read -r declared_line; do
          [[ -n "$declared_line" ]] && _declared_set["$declared_line"]=1
        done <<<"$declared_paths"
        local status_line status_path to_add=() undeclared=()
        while IFS= read -r status_line; do
          [[ -n "$status_line" ]] || continue
          status_path="${status_line:3}"
          # A rename/copy status line is "R  old -> new" (or "C  ..."); the
          # path actually landing in the tree -- the one that must be
          # declared -- is the new (right-hand) side.
          [[ "$status_path" == *" -> "* ]] && status_path="${status_path##* -> }"
          if [[ -n "${_declared_set[$status_path]:-}" \
              || ( "$status_path" == ".gitignore" && "$gitignore_pre_dirty" -eq 0 ) ]]; then
            # `.gitignore` gets the host-authored-bookkeeping exception ONLY
            # when it was clean before `_pmctl_ship_ensure_gitignore` ran --
            # i.e. every byte of its current diff is the host's own patch.
            # It cannot itself be gitignored to exclude it the way the other
            # bookkeeping paths are, so this path-name check is the only
            # gate; if the executor already dirtied it, that diff mixes
            # host and executor bytes and must be declared like any other
            # touched file, not exempted.
            to_add+=("$status_path")
          else
            undeclared+=("$status_path")
          fi
        done <<<"$dirty_status"
        if [[ "${#undeclared[@]}" -gt 0 ]]; then
          local undeclared_list
          undeclared_list="$(printf '%s, ' "${undeclared[@]}")"
          undeclared_list="${undeclared_list%, }"
          printf 'pmctl ship finish: refusing to auto-commit dispatched changes for %s -- touched undeclared path(s) outside the ticket'\''s declared edit scope: %s. Review manually; either amend the ticket'\''s Requirement section (and re-dispatch) or commit by hand, then re-run finish.\n' \
            "$ticket_id" "$undeclared_list" >&2
          return 1
        fi
        # `.gitignore` staged alone (no declared deliverable dirty) is still
        # bookkeeping, not a ticket deliverable -- it must still be committed
        # (left dirty, it would trip the post-gate/post-suite dirty-tree
        # guards below), but say so plainly rather than claiming "committed
        # dispatched changes" for what is, from the ticket's perspective, an
        # empty dispatch (RCG-002).
        local only_gitignore=0
        if [[ "${#to_add[@]}" -eq 1 && "${to_add[0]}" == ".gitignore" ]]; then
          only_gitignore=1
        fi
        if [[ "${#to_add[@]}" -eq 0 ]]; then
          printf 'pmctl ship finish: dispatched lane for %s had only pm-dispatch bookkeeping changes (now gitignored) -- no ticket deliverable to commit; continuing to gate the existing HEAD.\n' "$ticket_id" >&2
        elif ! git -C "$work_dir" add -- "${to_add[@]}" 2>&1; then
          printf 'pmctl ship finish: failed to stage dispatched lane changes for %s\n' "$ticket_id" >&2
          return 1
        elif git -C "$work_dir" diff --cached --quiet 2>/dev/null; then
          printf 'pmctl ship finish: dispatched lane for %s staged no net change (declared paths matched byte-for-byte HEAD) -- nothing to commit; continuing to gate the existing HEAD.\n' "$ticket_id" >&2
        elif [[ "$only_gitignore" -eq 1 ]]; then
          if ! git -C "$work_dir" commit -q -m "ship: $ticket_id pm-dispatch bookkeeping .gitignore patch" 2>&1; then
            printf 'pmctl ship finish: failed to commit the bookkeeping .gitignore patch for %s\n' "$ticket_id" >&2
            return 1
          fi
          printf 'pmctl ship finish: dispatched lane for %s had only pm-dispatch bookkeeping changes (patched .gitignore only) -- no ticket deliverable; committed the bookkeeping patch alone so the tree is clean for gate.\n' "$ticket_id" >&2
        else
          # Traceable subject (CC-584 gate finding critic-F001): a bare
          # "ship: <ticket-id>" message can't tell which deliverable a
          # dispatched-lane auto-commit carries without reopening the
          # ticket. Fall back to the old bare form only if the ticket's
          # section has no Requirement label to summarize.
          local goal_summary commit_subject
          goal_summary="$(_pmctl_ship_ticket_goal_summary "$work_dir/BACKLOG.md" "$ticket_id")"
          if [[ -n "$goal_summary" ]]; then
            commit_subject="ship: $ticket_id dispatched implementation -- $goal_summary"
          else
            commit_subject="ship: $ticket_id dispatched implementation"
          fi
          if ! git -C "$work_dir" commit -q -m "$commit_subject" 2>&1; then
            printf 'pmctl ship finish: failed to commit dispatched lane changes for %s\n' "$ticket_id" >&2
            return 1
          fi
          printf 'pmctl ship finish: committed dispatched changes for %s\n' "$ticket_id" >&2
        fi
      fi
    fi
  fi

  # Preflight `gh` before the gate even runs (not merely before push) --
  # finding out post-GO, after a push already happened, is the exact
  # PUSHED_NO_PR partial state risk-reviewer flagged. Fail fast instead.
  if ! command -v gh >/dev/null 2>&1; then
    # Backtick below is a literal Markdown code span, not command substitution.
    # shellcheck disable=SC2016
    printf 'pmctl ship finish: `gh` is unavailable -- refusing before spending a gate round on a finish that cannot open a PR. Install/configure gh, or push and open the PR manually after a manual gate check.\n' >&2
    return 1
  fi

  # Captured BEFORE the gate runs so the post-gate guard below can prove the
  # commit about to be pushed is the exact commit the gate reviewed -- not a
  # later, un-reviewed commit that happened to land while `finish` was
  # running, and not a working tree that drifted dirty in between.
  local pre_gate_head
  pre_gate_head="$(git -C "$work_dir" rev-parse HEAD 2>/dev/null)"

  local result_path gate_out="" gate_status=0
  if [[ -n "$gate_result" ]]; then
    if [[ "$gate_result" == /* ]]; then
      result_path="$gate_result"
    else
      result_path="$work_dir/$gate_result"
    fi
    printf 'pmctl ship finish: verifying supplied Gate result: %s\n' "$result_path"
  else
    # Maintainer remains the preferred producer policy for a fresh ship Gate.
    # Generic remains the public Gate default and is accepted as a publish
    # baseline when the caller supplies its exact current-tree artifact.
    local gate_args=(--executor codex --policy maintainer --cd "$work_dir" --lifecycle foreground)
    [[ -n "$reviewers" ]] && gate_args+=(--reviewers "$reviewers")
    gate_out="$(pmctl_gate_run "$repo_root" "${gate_args[@]}" 2>&1)" || gate_status=$?
    printf '%s\n' "$gate_out"
    result_path="$(printf '%s\n' "$gate_out" | grep -m1 '^result: ' | sed 's/^result: *//')"
  fi

  # Source of truth is the shared three-axis gate assessment, not the captured
  # exit code, stdout prose, or a local grep of `Final:`. pr-gate.sh prints the
  # result path; the verifier binds it to the current repository subject and
  # publish consumer policy before publication can continue.
  local final_verdict gate_verification gate_verification_status=0
  if [[ -z "$result_path" || ! -f "$result_path" ]]; then
    if [[ -n "$gate_result" ]]; then
      printf 'pmctl ship finish: supplied --gate-result artifact not found: %s\n' \
        "$result_path" >&2
    else
      printf 'pmctl ship finish: could not locate gate result file (gate exit %s) -- see output above\n' "$gate_status" >&2
    fi
    return 1
  fi
  if ! declare -F pmctl_gate_verify >/dev/null 2>&1; then
    printf 'pmctl ship finish: shared gate verifier is unavailable; refusing publication\n' >&2
    return 2
  fi
  gate_verification="$(
    pmctl_gate_verify "$repo_root" "$result_path" --cd "$work_dir" \
      --consumer publish --json
  )" || gate_verification_status=$?
  # A targeted confirmation is not independently publish-authorizing, but a
  # valid remediation closure can authorize the final tree. Re-read that
  # current Gate artifact in embedded mode so the publish assessment can bind
  # the closure without weakening the normal publish policy path.
  if [[ "$gate_verification_status" -ne 0 ]] \
      && jq -e '.axes.policy_applicable.reason_codes | index("comprehensive_review_required")' \
        <<<"$gate_verification" >/dev/null 2>&1; then
    gate_verification_status=0
    gate_verification="$(
      pmctl_gate_verify "$repo_root" "$result_path" --cd "$work_dir" \
        --consumer embedded --json
    )" || gate_verification_status=$?
  fi
  if ! jq -e '.kind == "gate_verification_v1"' \
      <<<"$gate_verification" >/dev/null 2>&1; then
    printf 'pmctl ship finish: shared gate verifier returned no structured assessment; refusing publication\n' >&2
    return 1
  fi
  final_verdict="$(jq -r '.verdict' <<<"$gate_verification")"
  if [[ "$final_verdict" != "GO" ]]; then
    printf 'pmctl ship finish: %s -- fix findings and re-run finish. Result: %s\n' "${final_verdict:-NO VERDICT}" "$result_path" >&2
    return 1
  fi
  if [[ "$gate_verification_status" -ne 0 ]]; then
    printf 'pmctl ship finish: GO artifact is invalid, stale, or below the publish policy baseline; refusing publication: %s\n' \
      "$(jq -c '.axes' <<<"$gate_verification")" >&2
    return 1
  fi

  # Committed-diff guard: GO only proves the gate reviewed SOME state of
  # work_dir -- prove that state is exactly what is about to be pushed
  # before pushing anything. Two ways this can drift: (a) the tree picked
  # up uncommitted changes after the gate ran (those changes would then be
  # silently absent from the pushed branch/PR -- the PR would look
  # reviewed but not contain what was actually reviewed), or (b) a new
  # commit landed on HEAD after the gate ran (that commit was never gated
  # at all, yet would ride along in the same push). Refuse push/PR in
  # either case rather than publish content the gate verdict does not
  # actually cover.
  if [[ -n "$(_pmctl_ship_worktree_status "$work_dir")" ]]; then
    printf 'pmctl ship finish: GO, but the tree is dirty -- refusing to push/PR content the gate did not review. Commit or discard the uncommitted changes and re-run finish.\n' >&2
    return 1
  fi
  local post_gate_head
  post_gate_head="$(git -C "$work_dir" rev-parse HEAD 2>/dev/null)"
  if [[ -z "$pre_gate_head" || "$post_gate_head" != "$pre_gate_head" ]]; then
    if [[ -n "$gate_result" ]]; then
      printf 'pmctl ship finish: GO, but HEAD moved while verifying supplied --gate-result (%s -> %s) -- refusing to push/PR a commit the artifact does not cover. Supply a Gate result for the current HEAD.\n' \
        "${pre_gate_head:-unknown}" "${post_gate_head:-unknown}" >&2
    else
      printf 'pmctl ship finish: GO, but HEAD moved during the gate run (%s -> %s) -- refusing to push/PR a commit the gate never reviewed. Re-run finish against the current HEAD.\n' \
        "${pre_gate_head:-unknown}" "${post_gate_head:-unknown}" >&2
    fi
    return 1
  fi

  # A gate GO is review evidence, not publication authorization by itself.
  # Verify (or freshly create and verify) the authoritative full-suite result
  # for this exact, still-clean tree before any remote mutation.
  local full_suite_status=0
  pmctl_ship_verify_full_suite "$work_dir" "$full_result" || full_suite_status=$?
  if [[ "$full_suite_status" -ne 0 ]]; then
    return "$full_suite_status"
  fi
  full_result="${PMCTL_SHIP_FULL_RESULT_FILE:-$full_result}"

  # The authoritative result proves the tree as it existed while the suite
  # ran, not whatever state happens to exist after the runner returns. Keep
  # the same publication boundary used after the gate: no dirty content and
  # no new commit may cross from verified evidence into the remote mutation.
  if [[ -n "$(_pmctl_ship_worktree_status "$work_dir")" ]]; then
    printf 'pmctl ship finish: full suite passed, but the tree is dirty -- refusing to push/PR content outside the verified evidence. Commit or discard the uncommitted changes and re-run finish.\n' >&2
    return 1
  fi
  local post_suite_head
  post_suite_head="$(git -C "$work_dir" rev-parse HEAD 2>/dev/null)"
  if [[ -z "$post_suite_head" || "$post_suite_head" != "$post_gate_head" ]]; then
    printf 'pmctl ship finish: full suite passed, but HEAD moved after the gate (%s -> %s) -- refusing to push/PR a commit without matching gate and full-suite evidence. Re-run finish against the current HEAD.\n' \
      "${post_gate_head:-unknown}" "${post_suite_head:-unknown}" >&2
    return 1
  fi

  # Both Gate and ship are producers of the same immutable closure contract.
  # Gate publishes the focused, non-authorizing closure; ship enriches it with
  # the verified full-suite artifact before any remote mutation. Keeping the
  # builder shared prevents the two publication paths from inventing divergent
  # finding dispositions or evidence semantics.
  if ! declare -F gate_remediation_closure_publish >/dev/null 2>&1; then
    printf 'pmctl ship finish: remediation closure publisher is unavailable; refusing publication\n' >&2
    return 2
  fi
  local remediation_closure gate_verification_file publish_assessment
  local producer_policy policy_satisfaction preferred_policy lane_identity subject_json
  remediation_closure="$work_dir/.pm-dispatch/test-results/ship-remediation-closure-${ticket_id}-${post_suite_head}.json"
  mkdir -p "$(dirname "$remediation_closure")" || {
    printf 'pmctl ship finish: unable to create remediation closure directory\n' >&2
    return 1
  }
  if ! gate_remediation_closure_publish \
      "$result_path" \
      "$(jq -r '.assurance.file // empty' <<<"$gate_verification")" \
      "$remediation_closure" \
      "$full_result" \
      "$ticket_id"; then
    printf 'pmctl ship finish: unable to publish remediation closure; refusing publication\n' >&2
    return 1
  fi
  printf 'pmctl ship finish: remediation closure: %s\n' "$remediation_closure"

  # This is the only publication assessment consumed below. It binds the
  # already verified Gate, closure, and full-suite artifacts to one subject;
  # stdout, the PR body, and the finish marker all read their assurance fields
  # from this same JSON document.
  if ! declare -F gate_publish_assessment_build >/dev/null 2>&1 \
      || ! declare -F gate_publish_assessment_verify >/dev/null 2>&1; then
    printf 'pmctl ship finish: shared publish assessment verifier is unavailable; refusing publication\n' >&2
    return 2
  fi
  gate_verification_file="$(mktemp "${TMPDIR:-/tmp}/pm-ship-gate-verification.XXXXXX.json")" || return 2
  printf '%s\n' "$gate_verification" > "$gate_verification_file"
  publish_assessment="$work_dir/.pm-dispatch/test-results/ship-publish-assessment-${ticket_id}-${post_suite_head}.json"
  if ! gate_publish_assessment_build \
      "$publish_assessment" "$gate_verification_file" "$remediation_closure" \
      "$full_result" "$ticket_id"; then
    rm -f -- "$gate_verification_file"
    printf 'pmctl ship finish: verified publish assessment could not be built; refusing publication\n' >&2
    return 1
  fi
  rm -f -- "$gate_verification_file"
  if ! gate_publish_assessment_verify "$publish_assessment"; then
    printf 'pmctl ship finish: verified publish assessment failed self-verification; refusing publication\n' >&2
    return 1
  fi
  # Bind every later consumer to the exact bytes that passed verification.
  # A test seam models a concurrent replacement between verification and the
  # snapshot; the digest comparison below must fail closed before any push.
  local assessment_sha assessment_snapshot assessment_snapshot_sha
  assessment_sha="$(gate_digest_file "$publish_assessment")" || {
    printf 'pmctl ship finish: unable to digest the verified publish assessment; refusing publication\n' >&2
    return 1
  }
  if declare -F pmctl_ship_after_assessment_verify >/dev/null 2>&1; then
    pmctl_ship_after_assessment_verify "$publish_assessment" || {
      printf 'pmctl ship finish: assessment post-verification hook failed; refusing publication\n' >&2
      return 1
    }
  fi
  assessment_snapshot="$(mktemp "${TMPDIR:-/tmp}/pm-ship-publish-assessment.XXXXXX.json")" || return 2
  if ! cp -- "$publish_assessment" "$assessment_snapshot"; then
    rm -f -- "$assessment_snapshot"
    printf 'pmctl ship finish: unable to snapshot the verified publish assessment; refusing publication\n' >&2
    return 1
  fi
  assessment_snapshot_sha="$(gate_digest_file "$assessment_snapshot")" || {
    rm -f -- "$assessment_snapshot"
    return 1
  }
  if [[ "$assessment_snapshot_sha" != "$assessment_sha" ]]; then
    rm -f -- "$assessment_snapshot"
    printf 'pmctl ship finish: publish assessment changed after verification; refusing publication\n' >&2
    return 1
  fi
  producer_policy="$(jq -r '.policy.embedded_policy' "$assessment_snapshot")"
  policy_satisfaction="$(jq -r '.policy.policy_satisfaction' "$assessment_snapshot")"
  preferred_policy="$(jq -r '.policy.preferred_policy' "$assessment_snapshot")"
  subject_json="$(jq -c '.subject' "$assessment_snapshot")" || {
    rm -f -- "$assessment_snapshot"
    printf 'pmctl ship finish: publish assessment subject could not be serialized; refusing publication\n' >&2
    return 1
  }
  lane_identity="$(_pmctl_ship_lane_identity_for_finish "$repo_root" "$work_dir" "$ticket_id" 2>/dev/null || true)"
  if [[ -z "$lane_identity" ]]; then
    rm -f -- "$assessment_snapshot"
    printf 'pmctl ship finish: current lane has no immutable tracking identity; refusing fallback recovery publication\n' >&2
    return 1
  fi
  printf 'pmctl ship finish: publish assurance: producer=%s satisfaction=%s preferred=%s\n' \
    "$producer_policy" "$policy_satisfaction" "$preferred_policy"
  printf 'pmctl ship finish: publish assessment: %s\n' "$publish_assessment"

  # Re-check the exact immutable subject immediately before resolving the
  # branch and pushing. The earlier guards protect the gate/full-suite
  # transitions; this last check closes the remaining interval in which a
  # concurrent commit or file change could otherwise cross the irreversible
  # remote-mutation boundary after assessment self-verification.
  local verified_head verified_tree current_head current_tree
  if [[ -n "$(_pmctl_ship_worktree_status "$work_dir")" ]]; then
    printf 'pmctl ship finish: publish assessment verified, but the tree became dirty before push -- refusing publication. Re-run finish against the current tree.\n' >&2
    return 1
  fi
  verified_head="$(jq -r '.subject.head_commit // empty' "$assessment_snapshot")"
  verified_tree="$(jq -r '.subject.tree_fingerprint // empty' "$assessment_snapshot")"
  current_head="$(git -C "$work_dir" rev-parse HEAD 2>/dev/null)"
  if [[ -z "$verified_head" || "$current_head" != "$verified_head" ]]; then
    printf 'pmctl ship finish: publish assessment verified, but HEAD moved before push (%s -> %s) -- refusing publication. Re-run finish against the current HEAD.\n' \
      "${verified_head:-unknown}" "${current_head:-unknown}" >&2
    return 1
  fi
  current_tree="$(_pmctl_ship_tree_fingerprint "$work_dir" committed_head "$current_head")" || {
    printf 'pmctl ship finish: unable to recompute the current tree fingerprint before push -- refusing publication.\n' >&2
    return 1
  }
  if [[ -z "$verified_tree" || "$current_tree" != "$verified_tree" ]]; then
    printf 'pmctl ship finish: publish assessment verified, but the tree fingerprint changed before push -- refusing publication. Re-run finish against the current tree.\n' >&2
    return 1
  fi

  local branch
  branch="$(git -C "$work_dir" rev-parse --abbrev-ref HEAD 2>/dev/null)"
  if [[ -z "$branch" || "$branch" == HEAD ]]; then
    printf 'pmctl ship finish: cannot resolve current branch in %s\n' "$work_dir" >&2
    return 1
  fi
  # Push the immutable assessed commit, not the movable local branch name.
  # A concurrent local commit after the final check must never become the
  # remote publication merely because the branch advanced before git resolved
  # the refspec.
  if ! git -C "$work_dir" push -u origin "$verified_head:refs/heads/$branch"; then
    printf 'pmctl ship finish: git push failed for %s\n' "$branch" >&2
    return 1
  fi
  # Durable, structured marker inside work_dir -- this is what `pmctl ship
  # status`/`list` (pmctl-ship-parallel.sh) read to detect a lane's state.
  # Grepping a dispatched executor's own free-text summary for "Final: GO"
  # is unreliable (an executor may report the verdict in prose/another
  # language, e.g. "Gate 通過（GO）" -- confirmed to false-negative during
  # CC-441's real e2e validation); this file is written by `pmctl ship
  # finish` ITSELF only on a confirmed gate GO, so its mere presence (with
  # the right verdict field) is the source of truth.
  local marker
  marker="$work_dir/.pm-dispatch-ship-finish.json"
  if ! command -v gh >/dev/null 2>&1; then
    # Backtick below is a literal Markdown code span, not command substitution.
    # shellcheck disable=SC2016
    printf 'pmctl ship finish: pushed %s, but `gh` is unavailable -- open the PR manually\n' "$branch" >&2
    if ! _pmctl_ship_finish_write_recovery_record \
        "$repo_root" "$work_dir" "$ticket_id" "$marker" "PUSHED_NO_PR" "$branch" \
        "$remediation_closure" "$publish_assessment" "$producer_policy" \
        "$policy_satisfaction" "$preferred_policy" "$lane_identity" "$subject_json"; then
      printf 'pmctl ship finish: partial-publication recovery record was not persisted.\n' >&2
    fi
    # Nonzero: gate passed and the branch is pushed, but the ship contract
    # (gate GO -> PR opened) is not yet complete -- the caller must open the
    # PR manually and this is not a state `pmctl ship status` should report
    # as a plain "go".
    return 1
  fi
  # Body follows commands/ship.md's PR template shape (Gate section with
  # verdict + result file, Ticket line) -- "Rounds" and a human summary
  # line are intentionally omitted: `finish` is a single mechanical
  # gate-round wrapper with no memory of prior rounds and no access to a
  # human-authored summary, unlike the full `/ship` prose flow this
  # mirrors. The caller (main thread or dispatched executor) can pass a
  # richer body via a future --summary flag if that gap matters in
  # practice; not adding one speculatively here.
  local pr_url pr_status=0
  pr_url="$(cd "$work_dir" && gh pr create --title "chore(${ticket_id}): ship" \
    --body "$(printf '## Gate\n- Final verdict: GO\n- Result file: %s\n- Remediation closure: %s\n- Publish assessment: %s\n- Publish assurance: producer=%s, satisfaction=%s (preferred=%s)\n- Full suite: %s\n\nTicket: %s\n' "$result_path" "$remediation_closure" "$publish_assessment" "$producer_policy" "$policy_satisfaction" "$preferred_policy" "$full_result" "$ticket_id")")" || pr_status=$?
  printf '%s\n' "$pr_url"
  if [[ "$pr_status" -ne 0 ]]; then
    # `gh` was confirmed present at the earlier preflight, but `gh pr
    # create` itself can still fail at RUNTIME (network, expired auth, API
    # rate limit, etc.) -- a genuinely different failure mode than "gh
    # missing", occurring AFTER the push already succeeded. Without a
    # marker here this partial-publish state (branch live on origin, no
    # PR, no record of why) is indistinguishable from an ordinary no-go/
    # failed lane to `pmctl ship status`/`list` -- exactly the silent
    # partial-publish gap critic/qa-tester/architecture-reviewer/
    # risk-reviewer converged on.
    if ! _pmctl_ship_finish_write_recovery_record \
        "$repo_root" "$work_dir" "$ticket_id" "$marker" "PUSHED_PR_FAILED" "$branch" \
        "$remediation_closure" "$publish_assessment" "$producer_policy" \
        "$policy_satisfaction" "$preferred_policy" "$lane_identity" "$subject_json" "${pr_url:-}" "${result_path:-}"; then
      printf 'pmctl ship finish: partial-publication recovery record was not persisted.\n' >&2
    fi
    return "$pr_status"
  fi

  if ! _pmctl_ship_finish_write_recovery_record \
      "$repo_root" "$work_dir" "$ticket_id" "$marker" "GO" "$branch" \
      "$remediation_closure" "$publish_assessment" "$producer_policy" \
      "$policy_satisfaction" "$preferred_policy" "$lane_identity" "$subject_json" "$pr_url" "$result_path"; then
    printf 'pmctl ship finish: CRITICAL: publication completed, but no durable recovery record was persisted; recover the pushed branch and PR manually.\n' >&2
    rm -f -- "$assessment_snapshot"
    return 1
  fi
  rm -f -- "$assessment_snapshot"
}

# ---------------------------------------------------------------------------
# Shared lane-tracking substrate (CC-442/CC-443). Was `ship-parallel.jsonl` /
# `_pmctl_ship_parallel_*`, --parallel-only. Now lives here, named
# ship-lanes.jsonl / _pmctl_ship_lane[s]_*, because ANY `--worktree` lane --
# manual or dispatched, batch or single-ticket -- is tracked here, not just
# `--parallel` lanes. pmctl-ship-parallel.sh's status/list commands read the
# same file; only the naming moved to stop implying --parallel-exclusivity.
# ---------------------------------------------------------------------------

# _pmctl_ship_lanes_reg_dir <repo_root> <work_dir>
# Same partition CC-014's `pmctl worktree` uses (sw_project_worktree_dir) --
# lane tracking is a sibling file under it, not a new state root.
_pmctl_ship_lanes_reg_dir() {
  local repo_root="$1" work_dir="$2"
  if ! declare -F sw_project_worktree_dir >/dev/null 2>&1; then
    # Direct library consumers (including ship finish's focused tests) may
    # source this file without the CLI's usual state-paths bootstrap.
    # Resolve the same canonical partition rather than losing fallback state.
    # shellcheck source=runtime/lib/state-paths.sh
    # shellcheck disable=SC1091
    . "${BASH_SOURCE[0]%/*}/state-paths.sh"
  fi
  pmctl_worktree_ensure_state_paths "$repo_root" >/dev/null 2>&1 || true
  sw_project_worktree_dir "$work_dir"
}

# _pmctl_ship_partial_record_path <repo_root> <work_dir> <ticket-id>
# Keep a structured partial-publication verdict in the canonical lane
# registry when the lane-local finish marker cannot be written.
_pmctl_ship_partial_record_path() {
  local repo_root="$1" work_dir="$2" ticket_id="$3" reg_dir
  reg_dir="$(_pmctl_ship_lanes_reg_dir "$repo_root" "$work_dir")" || return 1
  printf '%s/ship-partial-%s.json\n' "$reg_dir" "$ticket_id"
}

# A fallback record is project-wide because the lane-local marker may be
# unavailable.  It therefore needs a lane identity that survives a later
# same-ticket lane being created.  Tracked lanes receive a unique identity at
# creation time; direct/library callers without a tracking entry use a
# deterministic legacy identity so the finish-focused library tests retain a
# queryable fallback without weakening tracked-lane isolation.
_pmctl_ship_legacy_lane_identity() {
  local work_dir="$1" ticket_id="$2" canonical
  canonical="$(cd "$work_dir" 2>/dev/null && pwd -P)" || return 1
  printf 'ship-lane-legacy-v1\n%s\n%s\n' "$ticket_id" "$canonical" \
    | gate_digest_stream
}

_pmctl_ship_lane_identity_for_finish() {
  local repo_root="$1" work_dir="$2" ticket_id="$3" reg_dir tracking_file
  local canonical_path line tracked_ticket tracked_path tracked_identity
  canonical_path="$(cd "$work_dir" 2>/dev/null && pwd -P)" || return 1
  reg_dir="$(_pmctl_ship_lanes_reg_dir "$repo_root" "$work_dir")" || return 1
  tracking_file="$(_pmctl_ship_lanes_tracking_file "$reg_dir")"
  if [[ -f "$tracking_file" ]]; then
    while IFS= read -r line; do
      [[ -n "$line" ]] || continue
      tracked_ticket="$(jq -r '.ticket // empty' <<<"$line")"
      [[ "$tracked_ticket" == "$ticket_id" ]] || continue
      tracked_path="$(jq -r '.path // empty' <<<"$line")"
      [[ "$(cd "$tracked_path" 2>/dev/null && pwd -P || true)" == "$canonical_path" ]] || continue
      tracked_identity="$(jq -r '.lane_id // empty' <<<"$line")"
      [[ -n "$tracked_identity" ]] || return 1
      printf '%s\n' "$tracked_identity"
      return 0
    done < "$tracking_file"
  fi
  _pmctl_ship_legacy_lane_identity "$work_dir" "$ticket_id"
}

# _pmctl_ship_lane_was_dispatched <repo_root> <work_dir> <ticket-id>
# True (exit 0) when ship-lanes.jsonl's tracked entry for this exact
# (ticket_id, canonical work_dir) pair carries a non-empty adapter -- i.e. this
# lane was created via `pmctl ship <id> --adapter <name>` (CC-584), not the
# manual/in-place or `--worktree`-without-`--adapter` paths. Same match logic
# as _pmctl_ship_lane_identity_for_finish (ticket + canonical path), kept as a
# separate small loop rather than widening that function's single-purpose
# lane_id-only return contract for its existing callers.
_pmctl_ship_lane_was_dispatched() {
  local repo_root="$1" work_dir="$2" ticket_id="$3" reg_dir tracking_file
  local canonical_path line tracked_ticket tracked_path tracked_adapter
  canonical_path="$(cd "$work_dir" 2>/dev/null && pwd -P)" || return 1
  reg_dir="$(_pmctl_ship_lanes_reg_dir "$repo_root" "$work_dir")" || return 1
  tracking_file="$(_pmctl_ship_lanes_tracking_file "$reg_dir")"
  [[ -f "$tracking_file" ]] || return 1
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    tracked_ticket="$(jq -r '.ticket // empty' <<<"$line")"
    [[ "$tracked_ticket" == "$ticket_id" ]] || continue
    tracked_path="$(jq -r '.path // empty' <<<"$line")"
    [[ "$(cd "$tracked_path" 2>/dev/null && pwd -P || true)" == "$canonical_path" ]] || continue
    tracked_adapter="$(jq -r '.adapter // empty' <<<"$line")"
    [[ -n "$tracked_adapter" ]] && return 0
  done < "$tracking_file"
  return 1
}

# _pmctl_ship_lane_declared_paths <repo_root> <work_dir> <ticket-id>
# Prints this lane's declared edit-path allowlist (CC-584), one
# repo-relative path per line, as recorded in ship-lanes.jsonl's
# `declared_paths` field at dispatch time -- same (ticket_id, canonical
# work_dir) match as _pmctl_ship_lane_was_dispatched. Prints nothing and
# returns 1 when no matching tracking entry exists; prints nothing (exit 0)
# when a matching entry exists but recorded no declared paths -- callers
# must tell the two apart via their own dirty-tree/adapter checks, not this
# function's exit code alone.
_pmctl_ship_lane_declared_paths() {
  local repo_root="$1" work_dir="$2" ticket_id="$3" reg_dir tracking_file
  local canonical_path line tracked_ticket tracked_path
  canonical_path="$(cd "$work_dir" 2>/dev/null && pwd -P)" || return 1
  reg_dir="$(_pmctl_ship_lanes_reg_dir "$repo_root" "$work_dir")" || return 1
  tracking_file="$(_pmctl_ship_lanes_tracking_file "$reg_dir")"
  [[ -f "$tracking_file" ]] || return 1
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    tracked_ticket="$(jq -r '.ticket // empty' <<<"$line")"
    [[ "$tracked_ticket" == "$ticket_id" ]] || continue
    tracked_path="$(jq -r '.path // empty' <<<"$line")"
    [[ "$(cd "$tracked_path" 2>/dev/null && pwd -P || true)" == "$canonical_path" ]] || continue
    jq -r '.declared_paths // [] | .[]' <<<"$line"
    return 0
  done < "$tracking_file"
  return 1
}

_pmctl_ship_partial_record_write() {
  local repo_root="$1" work_dir="$2" ticket_id="$3" payload="$4"
  local record record_dir tmp
  record="$(_pmctl_ship_partial_record_path "$repo_root" "$work_dir" "$ticket_id")" || return 1
  record_dir="$(dirname "$record")"
  mkdir -p "$record_dir" || return 1
  tmp="$(mktemp "$record_dir/.ship-partial.XXXXXX")" || return 1
  if ! printf '%s\n' "$payload" > "$tmp" || ! mv -f -- "$tmp" "$record"; then
    rm -f -- "$tmp"
    return 1
  fi
  printf '%s\n' "$record"
}

# Try the lane-local marker first.  If it fails, atomically publish the same
# verdict in the canonical registry and emit an explicit recovery signal.
_pmctl_ship_finish_write_recovery_record() {
  local repo_root="$1" work_dir="$2" ticket_id="$3" marker="$4" verdict="$5" branch="$6"
  local remediation_closure="$7" publish_assessment="$8" producer_policy="$9"
  local policy_satisfaction="${10}" preferred_policy="${11}" lane_identity="${12}" subject_json="${13}" payload record
  local pr_url result_path
  shift 13
  pr_url="${1:-}"
  result_path="${2:-}"
  payload="$(jq -nc --arg ticket "$ticket_id" --arg branch "$branch" \
    --arg verdict "$verdict" --arg remediation_closure "$remediation_closure" \
    --arg publish_assessment "$publish_assessment" --arg producer_policy "$producer_policy" \
    --arg policy_satisfaction "$policy_satisfaction" --arg preferred_policy "$preferred_policy" \
    --arg lane_id "$lane_identity" --argjson subject "$subject_json" \
    --arg pr_url "$pr_url" --arg result_path "$result_path" \
    --arg finished_ts "$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date)" \
    '{schema_version:2,ticket:$ticket,verdict:$verdict,branch:$branch,
      lane_id:$lane_id,subject:$subject,
      remediation_closure:$remediation_closure,publish_assessment:$publish_assessment,
      publish_assurance:{embedded_policy:$producer_policy,preferred_policy:$preferred_policy,
        policy_satisfaction:$policy_satisfaction},
      pr_url:(if $pr_url == "" then null else $pr_url end),
      result_path:(if $result_path == "" then null else $result_path end),finished_ts:$finished_ts}')" || return 1
  if printf '%s\n' "$payload" > "$marker" 2>/dev/null; then
    return 0
  fi
  if record="$(_pmctl_ship_partial_record_write "$repo_root" "$work_dir" "$ticket_id" "$payload")"; then
    printf 'pmctl ship finish: WARNING: lane marker %s was not writable; durable publication recovery record: %s\n' \
      "$marker" "$record" >&2
    return 0
  fi
  printf 'pmctl ship finish: CRITICAL: remote branch %s was pushed, but neither the lane marker nor the durable publication recovery record could be written; recover the branch and open the PR manually.\n' \
    "$branch" >&2
  return 1
}

_pmctl_ship_lanes_tracking_file() {
  printf '%s/ship-lanes.jsonl\n' "$1"
}

# _pmctl_ship_lanes_tracking_append_inner <json_line> <tracking_file>
# Runs inside serialize_with_lock -- same locked-append primitive shape as
# pmctl_worktree_manifest_append (pmctl-worktree.sh).
_pmctl_ship_lanes_tracking_append_inner() {
  local json_line="$1" tracking_file="$2" compact
  compact="$(_sw_compact_json_line "$json_line")" || return $?
  printf '%s\n' "$compact" >> "$tracking_file"
}

# pmctl_ship_lanes_tracking_append <reg_dir> <json_line>
# The ONLY way a lane-creating call should append a new entry -- serialized
# against `pmctl_ship_lanes_tracking_refresh` so a concurrent status
# refresh's read-modify-write can never observe a half-written line nor
# silently drop an append that lands mid-refresh.
pmctl_ship_lanes_tracking_append() {
  local reg_dir="$1" json_line="$2" tracking_file
  mkdir -p "$reg_dir" 2>/dev/null || { printf 'pmctl ship: mkdir failed: %s\n' "$reg_dir" >&2; return 1; }
  tracking_file="$(_pmctl_ship_lanes_tracking_file "$reg_dir")"
  serialize_with_lock "$reg_dir/ship-lanes" _pmctl_ship_lanes_tracking_append_inner "$json_line" "$tracking_file"
}

# _pmctl_ship_lanes_tracking_refresh_inner <repo_root> <tracking_file> <json_out>
# Runs inside serialize_with_lock: re-reads the CURRENT file content (not a
# snapshot taken before acquiring the lock), recomputes each line's status,
# and writes the result back atomically (tmp + mv). This is the ONLY code
# path that should overwrite ship-lanes.jsonl wholesale -- doing the
# read+recompute+write inside one locked critical section is what makes it
# safe against a concurrent append (pmctl_ship_lanes_tracking_append above),
# which is serialized against the SAME lock. Prints the recomputed content on
# stdout (caller captures it for --json rendering) and prints one
# human-readable line per lane to stderr, matching the un-locked version's
# prior behavior.
_pmctl_ship_lanes_tracking_refresh_inner() {
  local repo_root="$1" tracking_file="$2" json_out="$3" tmp content line updated=""
  content=""
  [[ -f "$tracking_file" ]] && content="$(cat "$tracking_file")"
  [[ -n "$content" ]] || return 0
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    local ticket branch path run_id operation_id operation_work_dir lane_id cur_status new_status
    ticket="$(jq -r '.ticket' <<<"$line")"
    branch="$(jq -r '.branch' <<<"$line")"
    path="$(jq -r '.path' <<<"$line")"
    run_id="$(jq -r '.run_id' <<<"$line")"
    operation_id="$(jq -r '.operation_id // ""' <<<"$line")"
    operation_work_dir="$(jq -r '.operation_work_dir // ""' <<<"$line")"
    lane_id="$(jq -r '.lane_id // ""' <<<"$line")"
    cur_status="$(jq -r '.status' <<<"$line")"
    new_status="$(_pmctl_ship_lane_status "$path" "$run_id" "$cur_status" "$ticket" "$lane_id")"
    if pm_identifier_operation_is_valid "$operation_id" \
          && [[ "$operation_work_dir" == /* \
          && "$new_status" =~ ^(go|no-go|partial|failed)$ \
          && "$(type -t pmctl_operation_reconcile 2>/dev/null)" == function ]]; then
      pmctl_operation_reconcile "$repo_root" ship "$operation_id" --cd "$operation_work_dir" >&2 || true
    fi
    line="$(jq -c --arg s "$new_status" '.status = $s' <<<"$line")"
    updated="${updated}${line}
"
    if [[ "$json_out" -eq 0 ]]; then
      printf '[%s] %-12s branch=%-20s run_id=%s operation_id=%s\n' "$ticket" "$new_status" "$branch" "$run_id" "${operation_id:-none}" >&2
    fi
  done <<<"$content"
  tmp="$(mktemp "$(dirname "$tracking_file")/.ship-lanes.XXXXXX")" || return 1
  printf '%s' "$updated" > "$tmp"
  mv -f "$tmp" "$tracking_file"
  printf '%s' "$updated"
}

# pmctl_ship_lanes_tracking_refresh <repo-root> <reg_dir> <json_out 0|1>
pmctl_ship_lanes_tracking_refresh() {
  local repo_root="$1" reg_dir="$2" json_out="$3" tracking_file
  tracking_file="$(_pmctl_ship_lanes_tracking_file "$reg_dir")"
  [[ -f "$tracking_file" ]] || return 0
  serialize_with_lock "$reg_dir/ship-lanes" _pmctl_ship_lanes_tracking_refresh_inner "$repo_root" "$tracking_file" "$json_out"
}

# _pmctl_ship_recovery_subject_matches_lane <lane_path> <record>
# A fallback record must describe the same immutable subject currently present
# in the lane.  This is the second guard after lane_id: it prevents a reused
# lane path or a manually replaced checkout from inheriting an old verdict.
_pmctl_ship_recovery_subject_matches_lane() {
  local lane_path="$1" record="$2" record_head record_tree current_head current_tree
  record_head="$(jq -r '.subject.head_commit // empty' <<<"$record")"
  record_tree="$(jq -r '.subject.tree_fingerprint // empty' <<<"$record")"
  [[ "$record_head" =~ ^[a-f0-9]{40}$ && "$record_tree" =~ ^[a-f0-9]{64}$ ]] || return 1
  current_head="$(git -C "$lane_path" rev-parse HEAD 2>/dev/null)" || return 1
  [[ "$current_head" == "$record_head" ]] || return 1
  current_tree="$(_pmctl_ship_tree_fingerprint "$lane_path" committed_head "$current_head")" || return 1
  [[ "$current_tree" == "$record_tree" ]]
}

# _pmctl_ship_lane_status <lane_path> <run_id> [<current_status>] [<ticket-id>] [<lane-id>]
# Prints one of: prepared | dispatch-failed | dispatched | running | go | no-go | partial | failed
#
# GO detection reads ONLY `pmctl ship finish`'s own structured marker file
# (.pm-dispatch-ship-finish.json, written INSIDE lane_path only on a
# confirmed GO+PR) -- never the dispatched executor's free-text summary.
# Grepping DISPATCH_RECORD_SUMMARY for "Final: GO" was the original
# heuristic; a real CC-441 e2e run (claude executor) reported the verdict as
# prose ("Gate 通過（**GO**）") instead of that literal string, producing a
# false "no-go" for a lane that had actually reached GO and opened a PR --
# fixed by adding the marker as a first check, but an EARLIER version of
# that fix still fell back to the same free-text grep when the marker was
# ABSENT, which is unsafe in the other direction: an executor whose own
# narration happens to contain the string "Final: GO" (echoing the gate
# result verbatim, translating it, or the model simply mentioning it) could
# be reported as `go` even though `pmctl ship finish` never actually ran to
# completion and never wrote the marker -- exactly the "reported ready
# without proof" failure mode critic/architecture-reviewer/risk-reviewer
# converged on in gate round 6. No marker file == not go, full stop; the
# free-text branch below only distinguishes no-go/failed/running, never go.
_pmctl_ship_lane_status() {
  local lane_path="$1" run_id="$2" current_status="${3:-}" ticket_id="${4:-}" expected_lane_id="${5:-}"
  if [[ -f "$lane_path/.pm-dispatch-ship-finish.json" ]]; then
    # `pmctl ship finish` also writes this marker with verdict=PUSHED_NO_PR
    # when the gate passed and the branch pushed but `gh` was unavailable to
    # open the PR -- that is NOT a complete "go" (ship contract = gate GO
    # *and* PR opened), so only the literal GO verdict maps to status=go.
    local marker_verdict
    marker_verdict="$(jq -r '.verdict // ""' "$lane_path/.pm-dispatch-ship-finish.json" 2>/dev/null)"
    case "$marker_verdict" in
      GO) printf 'go\n' ;;
      # Distinct from plain no-go: the branch IS live on origin (a real,
      # recoverable remote side effect) even though no PR exists yet --
      # operationally different from "gate never passed, nothing pushed"
      # and needs its own recovery action (open the PR manually / retry),
      # not the ship contract's default "fix findings and re-run".
      PUSHED_NO_PR|PUSHED_PR_FAILED) printf 'partial\n' ;;
      *) printf 'no-go\n' ;;
    esac
    return 0
  fi
  # If the lane-local marker could not be written after a remote push, finish
  # persists the same verdict in the canonical registry partition. Treat it
  # as authoritative for status/list, but only for the tracked ticket.
  if [[ -n "$ticket_id" ]]; then
    local lane_repo partial_record partial_verdict partial_payload partial_lane_id
    lane_repo="$(git -C "$lane_path" rev-parse --show-toplevel 2>/dev/null || true)"
    if [[ -n "$lane_repo" ]]; then
      partial_record="$(_pmctl_ship_partial_record_path "$lane_repo" "$lane_path" "$ticket_id" 2>/dev/null || true)"
      if [[ -f "$partial_record" ]]; then
        partial_payload="$(cat "$partial_record" 2>/dev/null || true)"
        partial_lane_id="$(jq -r '.lane_id // empty' <<<"$partial_payload" 2>/dev/null || true)"
        if [[ -z "$expected_lane_id" ]]; then
          expected_lane_id="$(_pmctl_ship_legacy_lane_identity "$lane_path" "$ticket_id" 2>/dev/null || true)"
        fi
        if [[ -n "$expected_lane_id" && "$partial_lane_id" == "$expected_lane_id" ]] \
            && _pmctl_ship_recovery_subject_matches_lane "$lane_path" "$partial_payload"; then
          partial_verdict="$(jq -r '.verdict // ""' <<<"$partial_payload" 2>/dev/null || true)"
          case "$partial_verdict" in
            GO) printf 'go\n'; return 0 ;;
            PUSHED_NO_PR|PUSHED_PR_FAILED) printf 'partial\n'; return 0 ;;
          esac
        fi
      fi
    fi
  fi
  # A lane with no run_id either (a) was never dispatched at all (manual
  # `--worktree`, no --adapter), or (b) had a dispatch ATTEMPT that failed
  # before a run_id ever existed (mktemp/dispatch-run failure after the
  # worktree was already created). Both look identical from (lane_path,
  # run_id) alone -- `dispatch-failed` is a terminal, no-process-ever-ran
  # verdict that must survive repeated refreshes, so preserve it from the
  # tracking file's own current status rather than recompute it back down
  # to `prepared` every time (the marker-file check above still runs first,
  # so a human who manually finishes a dispatch-failed lane still resolves
  # correctly to go/no-go/partial).
  if [[ -z "$run_id" ]]; then
    if [[ "$current_status" == "dispatch-failed" ]]; then
      printf 'dispatch-failed\n'
    else
      printf 'prepared\n'
    fi
    return 0
  fi
  if ! declare -F dispatch_record_read_state >/dev/null; then
    printf 'dispatched\n'
    return 0
  fi
  if ! dispatch_record_read_state "$lane_path" "$run_id" >/dev/null 2>&1; then
    printf 'running\n'
    return 0
  fi
  case "$DISPATCH_RECORD_STATE" in
    # `ok` here means the DISPATCH (the executor process) exited cleanly --
    # it says nothing about whether the SHIP contract (gate GO + PR opened)
    # was satisfied. Without the marker checked above, that is never
    # provable from this record alone, so it is always no-go, regardless of
    # what the executor's own free-text summary claims.
    ok) printf 'no-go\n' ;;
    partial) printf 'no-go\n' ;;
    failed) printf 'failed\n' ;;
    *) printf 'running\n' ;;
  esac
}

# _pmctl_ship_ensure_gitignore <lane_work_dir>
# Best-effort: patch the lane's .gitignore so pm-dispatch's own bookkeeping
# directories (dispatch results, gate results/briefs, agent traces, the
# repo-local state root) never enter a ticket's commit when CC-584's
# post-dispatch auto-commit stages the lane. Mirrors the safety guards in
# _ctx_ensure_gitignore (runtime/lib/pmctl-context.sh): only ever read/write a
# real, single-linked regular file; skip (never touch) a symlink, non-regular
# path, or hardlinked file. Idempotent -- only appends patterns not already
# present, verbatim or with a trailing slash.
_pmctl_ship_ensure_gitignore() {
  local lane_work_dir="$1"
  local gitignore="$lane_work_dir/.gitignore"
  if [[ -L "$gitignore" || ( -e "$gitignore" && ! -f "$gitignore" ) ]]; then
    printf 'pmctl ship finish: .gitignore is not a regular file; skipping auto-patch\n' >&2
    return 0
  fi
  if [[ -f "$gitignore" ]]; then
    local nlink
    nlink="$(stat -c '%h' "$gitignore" 2>/dev/null || stat -f '%l' "$gitignore" 2>/dev/null || printf '1')"
    if [[ "$nlink" =~ ^[0-9]+$ && "$nlink" -gt 1 ]]; then
      printf 'pmctl ship finish: .gitignore is hardlinked (shared inode); skipping auto-patch\n' >&2
      return 0
    fi
  fi
  local pattern added=()
  for pattern in .dispatch-results .gate-results .gate-briefs .agent-trace .pm-dispatch-state .pm-dispatch; do
    if [[ -f "$gitignore" ]] \
      && { grep -qxF "$pattern" "$gitignore" 2>/dev/null || grep -qxF "$pattern/" "$gitignore" 2>/dev/null; }; then
      continue
    fi
    printf '%s\n' "$pattern" >> "$gitignore"
    added+=("$pattern")
  done
  if [[ "${#added[@]}" -gt 0 ]]; then
    printf 'pmctl ship finish: added %s to .gitignore\n' "${added[*]}" >&2
  fi
  return 0
}

# _pmctl_ship_brief_write <repo_root> <ticket_id> <lane_work_dir> <branch> <out_path> [declared_paths]
# Writes a dispatch brief scoped to /ship's Step 2 (implement) only -- the
# executor cannot reach Step 2.5 onward itself (git add/commit is refused by
# the executor sandbox; see the "Do NOT run git add..." constraint below and
# CC-584). Step 1 (branch) is also dropped -- the caller already created and
# checked out <branch> via `pmctl worktree create`. <declared_paths>, if
# given, is a newline-separated list (as from _pmctl_ship_ticket_declared_paths)
# of this ticket's declared edit-path allowlist -- the SAME list
# `pmctl_ship_finish` later enforces when staging this lane's auto-commit,
# so the brief and the host's enforcement never drift apart.
_pmctl_ship_brief_write() {
  local repo_root="$1" ticket_id="$2" lane_work_dir="$3" branch="$4" out_path="$5" declared_paths="${6:-}"
  # Backticks below are literal Markdown code spans, not command substitution.
  # shellcheck disable=SC2016
  {
    # Shell-quote lane_work_dir before embedding it in ANY generated shell
    # command string in this brief (self_verify's cmd:) -- a state-store path
    # containing a space or shell metacharacter would otherwise change the
    # command the executor is instructed to run, or split into multiple
    # `git -C` arguments.
    local quoted_lane_work_dir
    printf -v quoted_lane_work_dir '%q' "$lane_work_dir"
    printf 'schema_version: 1\n'
    printf 'working_dir: %s\n' "$lane_work_dir"
    printf 'goal: Implement %s inside this pre-created worktree lane. Do not commit, gate, or open a PR -- those run on the host after this dispatch finishes (see constraints).\n' "$ticket_id"
    printf 'context:\n'
    printf -- '  - This lane was created as an isolated ship worktree. The branch `%s` is already checked out here (i.e. `pmctl ship prepare`'\''s equivalent step already ran); do not create or switch branches.\n' "$branch"
    printf -- '  - The ship contract this brief draws its scope from is defined in `commands/ship.md` (CC-439) -- read its Step 2/2.5 guidance for what "implement" covers here; the gate-loop and PR steps described there do NOT apply to this dispatch (see constraints).\n'
    printf 'files:\n'
    printf -- '  - read: BACKLOG.md (section `## %s`) for Problem/Requirement/Dependencies\n' "$ticket_id"
    if [[ -n "$declared_paths" ]]; then
      local _declared_path_line
      while IFS= read -r _declared_path_line; do
        [[ -n "$_declared_path_line" ]] || continue
        printf -- '  - edit: %s\n' "$_declared_path_line"
      done <<<"$declared_paths"
    else
      printf -- '  - edit: files named by the ticket'\''s own Requirement section (none could be auto-derived as backtick-quoted paths -- name every file you touch explicitly in your report)\n'
    fi
    printf 'constraints:\n'
    printf -- '  - The host stages and commits ONLY the `edit:` paths declared above (plus its own pm-dispatch bookkeeping ignore-list) before gating -- it will refuse to commit anything else you create or modify, leaving it uncommitted until a human resolves it. Do not touch files outside that list; if the ticket genuinely requires it, stop and report instead of proceeding.\n'
    printf -- '  - Re-run the ticket-id consistency check yourself (Dependencies terminal-state, DECISIONS.md conflict scan) before implementing -- the orchestrator only did the cheap active-heading check, not this.\n'
    printf -- '  - Do not run `git checkout -b` or otherwise switch branches; `%s` is already checked out.\n' "$branch"
    printf -- '  - Do not run `pmctl worktree remove` or otherwise touch worktree lifecycle -- that is manual, user-triggered, and out of this lane'\''s scope.\n'
    printf -- '  - Do NOT run `git add`, `git commit`, `pmctl ship finish`, or `pmctl gate run`. This sandbox cannot write under `.git/` (workspace-write denies it, confirmed: `git commit` fails with '\''Unable to create .../.git/index.lock: Read-only file system'\'') -- per docs/sandbox-limitations.md Pattern 4, commit is always the main thread'\''s job, never the executor'\''s. Leave the implementation uncommitted in the working tree; the host stages, commits, gates, and (on GO) opens the PR after this dispatch completes.\n'
    printf -- '  - Stop and report instead of continuing only if the ticket'\''s own premise turns out wrong, or a fix would require contradicting a DECISIONS.md constraint.\n'
    printf 'self_verify:\n'
    printf -- '  - cmd: "git -C %s rev-parse --abbrev-ref HEAD | grep -qx %s"\n' "$quoted_lane_work_dir" "$branch"
    printf -- '  - git-status no-collateral-damage\n'
    printf 'acceptance:\n'
    printf -- '  - Working tree matches the ticket'\''s Requirement section, left uncommitted\n'
    printf -- '  - self_verify all pass\n'
  } > "$out_path"
}

# _pmctl_ship_lane_in_flight <reg_dir> <ticket_id>
# Prints "<run_id> <live_status>" and returns 0 if ticket_id already has a
# live (dispatched|running) lane recorded in ship-lanes.jsonl; returns 1
# (nothing printed) otherwise. Shared single-ticket guard -- used by both
# `pmctl_ship_run` (this file) and, independently, `pmctl_ship_parallel_run`'s
# own batch-wide pre-flight loop (pmctl-ship-parallel.sh keeps its own
# all-tickets-up-front variant of this check; not replaced here to avoid
# touching that already-tested batch error-message path).
_pmctl_ship_lane_in_flight() {
  local reg_dir="$1" ticket_id="$2" tracking_file
  tracking_file="$(_pmctl_ship_lanes_tracking_file "$reg_dir")"
  [[ -f "$tracking_file" ]] || return 1
  local line
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    local tracked_ticket tracked_status tracked_run_id tracked_path tracked_lane_id
    tracked_ticket="$(jq -r '.ticket' <<<"$line")"
    [[ "$tracked_ticket" == "$ticket_id" ]] || continue
    tracked_status="$(jq -r '.status' <<<"$line")"
    case "$tracked_status" in
      dispatched|running)
        tracked_run_id="$(jq -r '.run_id' <<<"$line")"
        tracked_path="$(jq -r '.path' <<<"$line")"
        tracked_lane_id="$(jq -r '.lane_id // ""' <<<"$line")"
        local live_status
        live_status="$(_pmctl_ship_lane_status "$tracked_path" "$tracked_run_id" "" "$ticket_id" "$tracked_lane_id")"
        if [[ "$live_status" == dispatched || "$live_status" == running ]]; then
          printf '%s %s\n' "$tracked_run_id" "$live_status"
          return 0
        fi
        ;;
    esac
  done < "$tracking_file"
  return 1
}

# _pmctl_ship_lanes_tracking_write <reg_dir> <ticket_id> <branch> <lane_path>
#                                   <run_id> <adapter> <status> <created_ts> [operation_id] [operation_work_dir] [lane_id]
# The ONE call shape `pmctl_ship_run` uses to append a ship-lanes.jsonl entry
# -- every terminal outcome after a successful `pmctl_worktree_create` goes
# through this (prepared / dispatch-failed / dispatched), never just the
# happy path, so a lane can never exist on disk without a corresponding
# tracking record (CC-442/CC-443 gate finding).
_pmctl_ship_lanes_tracking_write() {
  local reg_dir="$1" ticket_id="$2" branch="$3" lane_path="$4" run_id="$5" adapter="$6" status="$7" created_ts="$8" operation_id="${9:-}" operation_work_dir="${10:-}" lane_id="${11:-}" declared_paths_json="${12:-[]}"
  local json_line
  [[ -n "$lane_id" ]] || lane_id="$(printf 'ship-lane-v1\n%s\n%s\n%s\n' "$ticket_id" "$lane_path" "$created_ts" | gate_digest_stream)"
  # A malformed caller-supplied JSON array must never abort tracking-append
  # (the lane would then be invisible to `ship status`/`list` -- see the
  # CRITICAL warnings at this function's call sites) -- fail closed to an
  # empty allowlist instead, which `pmctl_ship_finish` already treats as
  # "refuse to auto-commit", never as "commit everything".
  jq -e 'type == "array"' <<<"$declared_paths_json" >/dev/null 2>&1 || declared_paths_json='[]'
  json_line="$(printf '{"ticket":%s,"branch":%s,"path":%s,"run_id":%s,"operation_id":%s,"operation_work_dir":%s,"adapter":%s,"status":%s,"created_ts":%s}' \
    "$(jq -Rn --arg v "$ticket_id" '$v')" \
    "$(jq -Rn --arg v "$branch" '$v')" \
    "$(jq -Rn --arg v "$lane_path" '$v')" \
    "$(jq -Rn --arg v "$run_id" '$v')" \
    "$(jq -Rn --arg v "$operation_id" '$v')" \
    "$(jq -Rn --arg v "$operation_work_dir" '$v')" \
    "$(jq -Rn --arg v "$adapter" '$v')" \
    "$(jq -Rn --arg v "$status" '$v')" \
    "$(jq -Rn --arg v "$created_ts" '$v')")"
  json_line="$(jq -c --arg lane_id "$lane_id" --argjson declared_paths "$declared_paths_json" \
    '. + {lane_id:$lane_id, declared_paths:$declared_paths}' <<<"$json_line")"
  pmctl_ship_lanes_tracking_append "$reg_dir" "$json_line"
}

# pmctl_ship_run <repo_root> <work_dir> <ticket-id> [--worktree] [--adapter <name>]
#                [--from <base>] [--isolation <level>] [--model <alias>]
#                [--auto-pack|--no-auto-pack]
# Unified START entry (CC-442/CC-443) -- see the option matrix in the file
# header comment. Does NOT touch git config gc.auto: that guard is owned
# exclusively by the batch wrapper (pmctl_ship_parallel_run), which already
# brackets its whole loop with a save/restore pair; a second per-call guard
# here would race against / clobber that outer one when this function runs
# inside the loop, and is unnecessary for a single `git worktree add`
# outside a batch.
#
# On success sets (single-ticket callers, e.g. pmctl_ship_parallel_run's
# loop, read these instead of parsing multi-line stdout):
#   PMCTL_SHIP_RUN_LANE_PATH, PMCTL_SHIP_RUN_ID (empty for a manual,
#   non-dispatched lane), PMCTL_SHIP_RUN_BRANCH
pmctl_ship_run() {
  local repo_root="${1:-}" work_dir="${2:-}" ticket_id="${3:-}"
  shift 3 2>/dev/null || true
  [[ -n "$work_dir" ]] || work_dir="$repo_root"
  # The parallel caller reads these documented globals after each invocation.
  # Clear stale values before any early/manual return.
  PMCTL_SHIP_OPERATION_ID=""

  local from="" isolation="workspace-network" model="" auto_pack_flag=""
  local adapter="" want_worktree=0 args=("$@") i=0
  # Reject a missing OR option-shaped (starts with `-`) operand for every
  # value-taking flag BEFORE any worktree/tracking/dispatch side effect --
  # without this, `pmctl ship <id> --adapter --no-auto-pack` would silently
  # swallow `--no-auto-pack` as the adapter NAME (defaulting missing values
  # to "claude" masked the bug further), creating a worktree and a
  # dispatch-failed tracking entry before dispatch validation ever caught
  # the malformed adapter (gate review finding, CC-443).
  while [[ $i -lt ${#args[@]} ]]; do
    case "${args[$i]}" in
      --worktree) want_worktree=1; i=$((i+1)) ;;
      --adapter)
        [[ $((i+1)) -lt ${#args[@]} && "${args[$((i+1))]}" != -* ]] || { printf 'pmctl ship: --adapter requires a value\n' >&2; return 2; }
        adapter="${args[$((i+1))]}"; want_worktree=1; i=$((i+2)) ;;
      --from)
        [[ $((i+1)) -lt ${#args[@]} && "${args[$((i+1))]}" != -* ]] || { printf 'pmctl ship: --from requires a value\n' >&2; return 2; }
        from="${args[$((i+1))]}"; i=$((i+2)) ;;
      --isolation)
        [[ $((i+1)) -lt ${#args[@]} && "${args[$((i+1))]}" != -* ]] || { printf 'pmctl ship: --isolation requires a value\n' >&2; return 2; }
        isolation="${args[$((i+1))]}"; i=$((i+2)) ;;
      --model)
        [[ $((i+1)) -lt ${#args[@]} && "${args[$((i+1))]}" != -* ]] || { printf 'pmctl ship: --model requires a value\n' >&2; return 2; }
        model="${args[$((i+1))]}"; i=$((i+2)) ;;
      --no-auto-pack) auto_pack_flag="--no-auto-pack"; i=$((i+1)) ;;
      --auto-pack) auto_pack_flag="--auto-pack"; i=$((i+1)) ;;
      -h|--help) pmctl_ship_usage; return 0 ;;
      *) i=$((i+1)) ;;
    esac
  done

  # Step 0 (id validation only -- the DECISIONS.md/Dependencies consistency
  # judgment stays the CALLER's job; that is PM-level judgment, not a
  # deterministic bash check, per commands/ship.md Step 0). Checked ONCE
  # here, shared by both the in-place and worktree/dispatch paths below
  # (previously duplicated: one copy inside the now-removed delegation to
  # pmctl_ship_prepare, a second copy for the worktree path).
  if [[ -z "$ticket_id" ]]; then
    printf 'pmctl ship: empty argument\n' >&2
    return 1
  fi
  if ! _pmctl_ship_id_shape_ok "$ticket_id"; then
    printf 'pmctl ship: malformed shape: %s\n' "$ticket_id" >&2
    return 1
  fi
  if ! _pmctl_ship_heading_exists "$work_dir/BACKLOG.md" "$ticket_id"; then
    if _pmctl_ship_heading_exists "$work_dir/BACKLOG-ARCHIVE.md" "$ticket_id"; then
      printf 'pmctl ship: ticket already archived: %s\n' "$ticket_id" >&2
    else
      printf 'pmctl ship: no such ticket: %s\n' "$ticket_id" >&2
    fi
    return 1
  fi

  # In-place mode (no --worktree, no --adapter): Step 1 (dirty-tree
  # precondition + branch), IN PLACE in work_dir -- no worktree, no tracking
  # entry (matches `ship prepare`'s historical behavior, which was never
  # tracked in ship-lanes.jsonl either). This IS the canonical
  # implementation -- `pmctl_ship_prepare` is a thin alias that calls back
  # into this function, not the reverse.
  if [[ "$want_worktree" -eq 0 ]]; then
    if [[ -n "$(git -C "$work_dir" status --porcelain 2>/dev/null)" ]]; then
      printf 'pmctl ship: tree is dirty -- commit or stash before preparing %s\n' "$ticket_id" >&2
      return 1
    fi
    local branch="feat/$ticket_id"
    if ! git -C "$work_dir" checkout -b "$branch" 2>&1; then
      printf 'pmctl ship: branch checkout failed for %s\n' "$branch" >&2
      return 1
    fi
    printf '%s\n' "$branch"
    return 0
  fi

  if ! declare -F pmctl_worktree_create >/dev/null; then
    printf 'pmctl ship: pmctl worktree unavailable\n' >&2
    return 2
  fi

  local reg_dir
  reg_dir="$(_pmctl_ship_lanes_reg_dir "$repo_root" "$work_dir")" || {
    printf 'pmctl ship: cannot resolve worktree registry dir from %s\n' "$work_dir" >&2
    return 1
  }

  # Same in-flight refusal `pmctl_ship_parallel_run`'s batch pre-flight
  # enforces for a batch -- applied here too so a standalone `pmctl ship
  # <id> --adapter X` (outside --parallel) gets the same protection against
  # racing a still-live prior lane for the same ticket (CC-442 spike a3
  # explicitly flagged this as a gap in the pilot draft).
  local inflight
  if inflight="$(_pmctl_ship_lane_in_flight "$reg_dir" "$ticket_id")"; then
    local inflight_run_id inflight_status
    inflight_run_id="${inflight%% *}"
    inflight_status="${inflight#* }"
    # Backtick below is a literal Markdown code span, not command substitution.
    # shellcheck disable=SC2016
    printf 'pmctl ship: %s already has an in-flight lane (run_id=%s, status=%s) -- refusing to re-dispatch. Check `pmctl ship status`; only retry after it reaches a terminal state (go/no-go/failed).\n' \
      "$ticket_id" "$inflight_run_id" "$inflight_status" >&2
    return 1
  fi

  local branch="feat/$ticket_id" create_out lane_path
  # `pmctl_worktree_create` prints the resolved worktree path as its LAST
  # stdout line (`git worktree add`'s own progress chatter precedes it,
  # uncaptured/unsuppressed by that function).
  if ! create_out="$(pmctl_worktree_create "$repo_root" "$work_dir" "$branch" ${from:+--from "$from"} --name "$ticket_id")"; then
    printf 'pmctl ship: %s worktree create failed\n' "$ticket_id" >&2
    return 1
  fi
  lane_path="$(printf '%s\n' "$create_out" | tail -1)"

  local created_ts run_id=""
  created_ts="$(date -Is 2>/dev/null || date)"

  if [[ -z "$adapter" ]]; then
    # --worktree, no --adapter: manual lane, no dispatch. Caller decides
    # whether to implement there themselves.
    if ! _pmctl_ship_lanes_tracking_write "$reg_dir" "$ticket_id" "$branch" "$lane_path" "" "" "prepared" "$created_ts"; then
      # Backticks below are literal Markdown code spans, not command substitution.
      # shellcheck disable=SC2016
      printf 'pmctl ship: %s CRITICAL -- worktree lane created at %s but tracking-append failed; `pmctl ship status`/`list` cannot see it. Recover manually via `pmctl worktree list`.\n' \
        "$ticket_id" "$lane_path" >&2
      return 1
    fi
    printf '%s\n' "$lane_path"
    # See the shellcheck disable=SC2034 note at this function's other return
    # point -- same cross-file (pmctl-ship-parallel.sh) consumer.
    # shellcheck disable=SC2034
    PMCTL_SHIP_RUN_LANE_PATH="$lane_path"
    # shellcheck disable=SC2034
    PMCTL_SHIP_RUN_ID=""
    # shellcheck disable=SC2034
    PMCTL_SHIP_RUN_BRANCH="$branch"
    return 0
  fi

  # --adapter (with or without an explicit --worktree): dispatch. From this
  # point on, the worktree already exists -- EVERY exit path below (mktemp
  # fail, dispatch fail, dispatch success) must record a ship-lanes.jsonl
  # entry before returning, never just the success path. A worktree that
  # exists but was never tracked is an orphaned lane invisible to `pmctl
  # ship status`/`list` -- exactly the operational blind spot critic,
  # architecture-reviewer, and risk-reviewer converged on in gate review.
  local brief_path
  brief_path="$(mktemp -p /tmp "brief-ship-$ticket_id-XXXXXX.md")" || {
    _pmctl_ship_lanes_tracking_write "$reg_dir" "$ticket_id" "$branch" "$lane_path" "" "$adapter" "dispatch-failed" "$created_ts" || true
    printf 'pmctl ship: %s mktemp failed for brief -- lane worktree stays at %s for manual inspection, tracked as dispatch-failed\n' "$ticket_id" "$lane_path" >&2
    return 1
  }
  chmod 0600 "$brief_path" 2>/dev/null || true
  # CC-584: derive the declared edit-path allowlist ONCE, from the ticket
  # text as it stood at dispatch time, and thread the SAME list into both
  # the brief the executor reads and the tracking record `finish` later
  # enforces against -- so what the executor was told it may touch and what
  # the host will actually let it commit never drift apart.
  local declared_paths declared_paths_json
  declared_paths="$(_pmctl_ship_ticket_declared_paths "$work_dir/BACKLOG.md" "$ticket_id")"
  declared_paths_json="$(jq -Rn '[inputs | select(length > 0)]' <<<"$declared_paths" 2>/dev/null)"
  [[ -n "$declared_paths_json" ]] || declared_paths_json='[]'
  _pmctl_ship_brief_write "$repo_root" "$ticket_id" "$lane_path" "$branch" "$brief_path" "$declared_paths"

  local dispatch_args=(--adapter "$adapter" --cd "$lane_path" --isolation "$isolation" --lifecycle detached --brief-file "$brief_path")
  [[ -n "$model" ]] && dispatch_args+=(--model "$model")
  [[ -n "$auto_pack_flag" ]] && dispatch_args+=("$auto_pack_flag")

  # A dispatched ship lane is a producer-owned operation, not merely a loose
  # worktree plus a child run.  Create its durable parent before launch so a
  # failed launch is still explainable; attach the child only after dispatch
  # has returned its authoritative run id.
  local operation_id=""
  # Ship is also used as a standalone library by its focused fixture.  The CLI
  # loads pmctl-operation before pmctl-ship, but retain this one compatibility
  # import for that supported library entry point; all readiness validation then
  # goes through the operation layer's shared helper.
  if ! declare -F _pmctl_operation_ensure_loaded >/dev/null 2>&1; then
    local _operation_lib="$repo_root/runtime/lib/pmctl-operation.sh"
    # shellcheck disable=SC1090,SC1091 # repo-root-relative runtime library
    [[ -r "$_operation_lib" ]] && . "$_operation_lib"
  fi
  if declare -F _pmctl_operation_ensure_loaded >/dev/null 2>&1 \
      && _pmctl_operation_ensure_loaded "$repo_root"; then
    operation_id="$(pmctl_operation_create "$repo_root" "$work_dir" ship "$adapter")" || {
      _pmctl_ship_lanes_tracking_write "$reg_dir" "$ticket_id" "$branch" "$lane_path" "" "$adapter" "dispatch-failed" "$created_ts" || true
      printf 'pmctl ship: %s could not create its parent operation record; refusing to dispatch an unowned lane\n' "$ticket_id" >&2
      return 1
    }
  else
    printf 'pmctl ship: parent-operation control library unavailable; refusing to dispatch an unowned lane\n' >&2
    return 2
  fi
  # dispatch run attaches this child before invoking the detached executor.
  # Passing the parent explicitly makes an attach failure a launch failure,
  # instead of leaving a running but unowned ship lane behind.
  dispatch_args+=(--parent-operation "$operation_id" --parent-operation-cd "$work_dir")

  if ! run_id="$(pmctl_dispatch_run "$repo_root" "${dispatch_args[@]}")"; then
    # Terminalize the producer now so ship status, doctor, and the lane record
    # agree on the known failure rather than leaving a stale running operation.
    # Two distinct failure shapes reach here: dispatch failed before reserving a
    # child (childless -> failed), or it reserved one and then failed at the
    # launch boundary.  The latter cannot be terminalized by the childless path,
    # so converge it through reconcile, which reads the failed terminal claim
    # dispatch wrote for the child that never launched.
    if ! pmctl_operation_fail_if_childless "$repo_root" ship "$operation_id" "$work_dir" >&2; then
      pmctl_operation_reconcile "$repo_root" ship "$operation_id" --cd "$work_dir" >&2 || true
    fi
    _pmctl_ship_lanes_tracking_write "$reg_dir" "$ticket_id" "$branch" "$lane_path" "" "$adapter" "dispatch-failed" "$created_ts" || true
    printf 'pmctl ship: %s dispatch run failed -- lane worktree stays at %s for manual inspection, tracked as dispatch-failed\n' "$ticket_id" "$lane_path" >&2
    return 1
  fi
  run_id="$(printf '%s\n' "$run_id" | tail -1 | tr -d '[:space:]')"

  if ! _pmctl_ship_lanes_tracking_write "$reg_dir" "$ticket_id" "$branch" "$lane_path" "$run_id" "$adapter" "dispatched" "$created_ts" "$operation_id" "$work_dir" "" "$declared_paths_json"; then
    # Backticks below are literal Markdown code spans, not command substitution.
    # shellcheck disable=SC2016
    printf 'pmctl ship: %s CRITICAL -- dispatched (run_id=%s) at %s but tracking-append failed; the executor IS running but `pmctl ship status`/`list` cannot see it. Recover manually via `pmctl worktree list` / `pmctl artifacts show %s`.\n' \
      "$ticket_id" "$run_id" "$lane_path" "$run_id" >&2
    return 1
  fi

  printf 'dispatched: operation_id=%s run_id=%s lane=%s\n' "$operation_id" "$run_id" "$lane_path"
  # These three globals are this function's documented single-ticket return
  # channel (see the header comment above) -- read by pmctl_ship_parallel_run
  # in the sibling file pmctl-ship-parallel.sh, which shellcheck (run per-file
  # here) cannot see across the source boundary.
  # shellcheck disable=SC2034
  PMCTL_SHIP_RUN_LANE_PATH="$lane_path"
  # shellcheck disable=SC2034
  PMCTL_SHIP_RUN_ID="$run_id"
  # shellcheck disable=SC2034
  PMCTL_SHIP_OPERATION_ID="$operation_id"
  # shellcheck disable=SC2034
  PMCTL_SHIP_RUN_BRANCH="$branch"
  return 0
}
