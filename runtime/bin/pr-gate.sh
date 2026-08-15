#!/usr/bin/env bash
set -euo pipefail
trap '' PIPE

GATE_CANCELLED=false
GATE_ACTIVE_PREFLIGHT_PID=""
GATE_ACTIVE_PREFLIGHT_PGID=""
GATE_REVIEWER_OVERRIDE_SNAPSHOT=""

gate_cleanup_reviewer_override_snapshot() {
  local snapshot="${GATE_REVIEWER_OVERRIDE_SNAPSHOT:-}"
  [[ -n "$snapshot" ]] || return 0
  rm -f -- "$snapshot" 2>/dev/null || true
  GATE_REVIEWER_OVERRIDE_SNAPSHOT=""
}

# The full gate cleanup is installed only after result/brief paths exist.  This
# early trap covers the reviewer-override snapshot created before that point;
# gate_exit_cleanup() calls the same helper after it replaces this trap.
gate_early_exit_cleanup() {
  local gate_status=$?
  gate_cleanup_reviewer_override_snapshot
  return "$gate_status"
}
trap gate_early_exit_cleanup EXIT

gate_stop_active_preflight() {
  local pid="${GATE_ACTIVE_PREFLIGHT_PID:-}" pgid="${GATE_ACTIVE_PREFLIGHT_PGID:-}"
  [[ "$pid" =~ ^[1-9][0-9]*$ && "$pgid" =~ ^[1-9][0-9]*$ ]] || return 0

  # Operation-owned preflight runs in its own session so timeout and its
  # managed command share one killable group during cancellation. Stop and
  # reap that group before pr-gate exits; the parent operation only
  # reaches `cancelled` after this producer process is gone.
  detached_launch_kill_process_group "$pgid" 1 || true
  wait "$pid" 2>/dev/null || true
  GATE_ACTIVE_PREFLIGHT_PID=""
  GATE_ACTIVE_PREFLIGHT_PGID=""
}

gate_cancel_signal() {
  GATE_CANCELLED=true
  gate_stop_active_preflight
  gate_cleanup_reviewer_override_snapshot
  exit 130
}
trap gate_cancel_signal TERM INT

# say -- emit a progress/diagnostic line on stdout that tolerates a closed pipe.
#
# A consumer that reads a prefix of our stdout and closes the pipe early
# (`pmctl gate run | head`, `| grep -q`, ...) makes the next stdout write fail
# with EPIPE. `trap '' PIPE` keeps the SIGPIPE from killing us, but under
# `set -e` the EPIPE write still makes printf return nonzero and aborts the
# script BEFORE dispatch -- leaving a 0-byte result file while the pipeline
# reports the consumer's exit 0 (silent false-success). The `|| true` here
# absorbs that nonzero so the gate always runs to completion and the per-route
# result-integrity checks remain the authority on the exit code. All human
# progress output must go through say(); only the result file and the
# machine-read handover block are gate "data".
# shellcheck disable=SC2059  # printf passthrough wrapper: the caller owns the format string
say() { printf "$@" 2>/dev/null || true; }

# CC-532: resolve the deployment layout once before parsing options. The
# bootstrap only locates and sources gate-layout.sh; all subsequent module and
# policy paths come from its canonical PR_GATE_* roots.
_gate_bootstrap_entry="$0"
while [[ -L "$_gate_bootstrap_entry" ]]; do
  _gate_bootstrap_link_dir="$(cd "$(dirname "$_gate_bootstrap_entry")" && pwd)"
  _gate_bootstrap_entry="$(readlink "$_gate_bootstrap_entry")"
  [[ "$_gate_bootstrap_entry" == /* ]] || \
    _gate_bootstrap_entry="$_gate_bootstrap_link_dir/$_gate_bootstrap_entry"
done
_gate_bootstrap_dir="$(cd "$(dirname "$_gate_bootstrap_entry")" && pwd -P)"
if [[ "${_gate_bootstrap_dir##*/}" == bin \
    && "${_gate_bootstrap_dir%/*}" != "$_gate_bootstrap_dir" \
    && "${_gate_bootstrap_dir%/*}" == */runtime ]]; then
  _gate_bootstrap_dir="$_gate_bootstrap_dir/../lib"
else
  _gate_bootstrap_dir="$_gate_bootstrap_dir/lib"
fi
if [[ ! -r "$_gate_bootstrap_dir/gate-layout.sh" ]]; then
  printf 'pr-gate: canonical layout module unavailable: %s\n' \
    "$_gate_bootstrap_dir/gate-layout.sh" >&2
  exit 2
fi
# shellcheck source=runtime/lib/gate-layout.sh
. "$_gate_bootstrap_dir/gate-layout.sh"
gate_layout_resolve "$_gate_bootstrap_entry" || {
  printf 'pr-gate: unable to resolve the gate deployment layout\n' >&2
  exit 2
}

for _gate_bootstrap_module in gate-digest.sh gate-options.sh; do
  if [[ ! -r "$PR_GATE_LIB_DIR/$_gate_bootstrap_module" ]]; then
    printf 'pr-gate: canonical module unavailable: %s\n' \
      "$PR_GATE_LIB_DIR/$_gate_bootstrap_module" >&2
    exit 2
  fi
  # shellcheck disable=SC1090  # path is selected by gate-layout.sh
  . "$PR_GATE_LIB_DIR/$_gate_bootstrap_module"
done
unset _gate_bootstrap_dir _gate_bootstrap_entry _gate_bootstrap_link_dir \
  _gate_bootstrap_module

# _kill_process_tree <pid> [signal] -- signal a process AND all its descendants.
# A plain `kill <pid>` only reaches the `eval` subshell / dispatch.sh wrapper we
# backgrounded; the grandchild executor (`codex exec`, or a test `sleep` stub)
# lives in the same call chain but survives as an orphan reparented to init. The
# parallel reviewer/synthesis watchdogs must reap the whole tree or a timed-out
# gate leaks live executor processes. Walk children depth-first via `pgrep -P`
# (leaves before parents) so each layer is signaled before its parent disappears.
_kill_process_tree() {
  local _pid="$1" _sig="${2:-TERM}" _child
  for _child in $(pgrep -P "$_pid" 2>/dev/null || true); do
    _kill_process_tree "$_child" "$_sig"
  done
  kill -"$_sig" "$_pid" 2>/dev/null || true
}

# pr-gate-help:start
# pr-gate.sh -- PR-gate review via a dispatched session
#
# SINGLE-SESSION (--mode sequential; --sequential is compatible):
#   All reviewers run in order inside ONE combined dispatch session.
#   Lower token cost. All reviewer findings appear in a single output file.
#   Use this for most routine changes.
#
# MULTI-SESSION (--mode parallel; --parallel is compatible):
#   Each reviewer runs in its own INDEPENDENT dispatch session, followed by a
#   separate PM synthesis session. Reviewers share no context window, which
#   eliminates anchoring bias across reviewers.
#   Higher token cost. Use for auth/payment/migration paths or when reviewer
#   independence is worth the extra cost.
#
# Explicit user mode always wins. When mode is omitted, policy automatically
# selects its recommendation from the consumer and matched risk signals.
#
# Adjacent test files (not in the diff but directly paired to a changed source
# file) are automatically added to every reviewer brief so coverage gaps in
# unchanged test files are visible to the gate.
#
# Usage:
#   pr-gate.sh --cd <dir> [options]
#
# Options:
#   --cd <dir>           working directory (required)
#   --tier <tier>        express|standard|full -- overrides auto-detection
#   --mode <mode>        sequential|parallel; omitted mode follows the policy recommendation
#   --brief <file>       dispatch brief; trusted architecture_impact contributes to policy resolution
#   --policy <name>      generic|maintainer consumer policy (default: generic)
#   --pass <kind>        initial|targeted review-pass scope; targeted requires --reviewers and --initial-result
#   --reviewers <list>   comma-separated requested coverage; does not change tier or pass kind
#   --targeted <list>    compatibility shorthand for --pass targeted --reviewers <list>
#   --initial-result <f> initial gate result referenced by a targeted pass; relative to --cd
#   --reviewer-dir <dir> explicit reviewer-definition source; defaults to the repo-owned agents/ directory
#   --scope <text>       context hint passed into the review brief
#   --base <branch>      base branch for diff (default: origin/HEAD → main)
#   --head <ref>         head ref for diff (default: HEAD / working tree); pass a fixed ref
#                        (branch, tag, commit) to review it without a PR or working tree
#                        involved -- e.g. review a branch before opening a PR, or diff one
#                        tag against another (v0.6.0..v0.7.0). Uses the SAME merge-base
#                        (three-dot) semantics as the default HEAD path: reviews what
#                        changed on head since it diverged from base, not a literal
#                        two-dot tree diff. Incompatible with --allow-dirty.
#   --run-dir <abs>      out-of-repo dir for gate artifacts (briefs/results/trace); optional,
#                        defaults to in-repo paths under --cd when absent (backward compat)
#   --output <path>      result file (default: .gate-results/gate-<ts>.md)
#   --executor <mode>    codex|claude|auto (default: auto; auto uses `command -v codex`)
#   --model <id>         dispatch model (default: "default" → adapter's pinned default,
#                        e.g. codex gpt-5.6-terra / claude sonnet; pass a concrete id to override)
#   --effort <level>     low|medium|high (default: omit → adapter resolves medium unless
#                        the model alias carries its own valid value; see
#                        runtime/lib/reasoning-effort.sh). Independent of --model — use
#                        this to dial reasoning depth up/down without switching models.
#   --isolation <level>  isolation level: none|read-only|workspace-write|workspace-network|sandboxed
#   --timeout <secs>     dispatch timeout per session (default: 1200)
#   --parallel           compatibility spelling for --mode parallel
#   --sequential         compatibility spelling for --mode sequential
#   --allow-hooks        execute repo-local .pm-dispatch hook scripts (trusted branches only)
#   --allow-dirty        review the working tree as-is instead of failing on a dirty tree atop committed changes
#   --accept-scope-truncation
#                        explicitly accept declared scope-manifest omissions caused by bounded
#                        hunk/expansion budgets; otherwise truncation stops before reviewer dispatch
#   --override-file <f>  inject accepted-risk overrides into every reviewer brief; auto-discovered
#                        from .gate-overrides.md at repo root when this flag is omitted. A relative
#                        <f> is resolved against the working dir (--cd), not the caller's CWD, since
#                        the file is loaded after the gate cd's into the work dir. It must be readable,
#                        non-empty, regular, NUL-free, and have a non-symlink final component (including
#                        no dangling link); legacy inputs that violate this fail before dispatch. The loader
#                        snapshots and rechecks source identity on Linux/WSL2, but cannot defend a
#                        malicious concurrent writer using the same OS uid. Accepted snapshot source and
#                        content are recorded in the gate result (## Gate Overrides Applied).
#   --policy-override <f> explicit gate_policy_override_v1 JSON for a scope-bound policy
#                        downgrade. It is never auto-discovered and requires recorded user approval.
#   --test-cmd <cmd>     pre-flight test command run in plain bash BEFORE dispatch, independent of
#                        --timeout. A subject-valid structured assertion failure forces NO-GO;
#                        timeout, environment, opaque nonzero, stale, or invalid evidence stop as
#                        INCOMPLETE/non-authorizing rather than being misreported as a test failure.
#                        Any command works unchanged and receives basic opaque/advisory evidence.
#                        A compatible runner may write structured suite evidence to the result path
#                        exposed in PM_DISPATCH_PREFLIGHT_TEST_RESULT; only current structured PASS
#                        suites receive the no-duplicate reuse policy.
#                        No auto-detection -- pr-gate.sh is copy-mode portable (see header) and must
#                        not assume any repo-specific test command or path convention; the caller
#                        supplies one explicitly (e.g. `bash scripts/test.sh`). Long-running full
#                        suites should run outside the gate lifecycle; --test-cmd is best suited to
#                        a bounded iteration check chosen by the target repo's caller. Omitting
#                        this flag skips the pre-flight check entirely (reviewers judge test status
#                        themselves, as before this feature existed).
#   --test-timeout <s>   timeout for --test-cmd (default: 3600), decoupled from --timeout so a slow
#                        test suite can never cause a reviewer dispatch session to time out.
#                        Evidence produced outside this local gate is deliberately
#                        non-authorizing.  A digest supplied by the same operator can
#                        prove transport integrity, not who executed the test.  Remote
#                        evidence will be accepted only after a CI-provider attestation
#                        verifier is introduced.
#   --skip-preflight-tests   force-disable the pre-flight test check even if --test-cmd is passed.
# pr-gate-help:end

WORK_DIR=""
GATE_RUN_DIR_OVERRIDE=""   # out-of-repo artifact root; set via --run-dir from pmctl-gate
TIER_OVERRIDE=""
TIER_REQUESTED="auto"
TIER_SELECTION_BASIS="policy"
REVIEWERS_OVERRIDE=""
REVIEWERS_OPTION_SOURCE=""
MODE_REQUESTED="default"
MODE_OPTION_SEEN=false
# shellcheck disable=SC2034 # consumed by the sourced canonical option module
MODE_OPTION_SPELLING=""
PASS_KIND_REQUESTED="initial"
# shellcheck disable=SC2034 # consumed by the sourced canonical option module
PASS_OPTION_SEEN=false
# shellcheck disable=SC2034 # consumed by the sourced canonical option module
PASS_OPTION_SPELLING=""
# shellcheck disable=SC2034 # consumed by the canonical assurance module
PASS_SYNTAX_SOURCE="default"
INITIAL_RESULT_INPUT=""
INITIAL_RESULT_OPTION_SEEN=false
REVIEWERS_EXPLICIT_INPUT=""
REVIEWERS_SHORTHAND_INPUT=""
REVIEWERS_EXPLICIT_SEEN=false
REVIEWERS_SHORTHAND_SEEN=false
COVERAGE_SYNTAX_SOURCE="default"
COVERAGE_SELECTION_BASIS="policy-default"
POLICY_CONSUMER="generic"
POLICY_OVERRIDE_FILE=""
REVIEWER_DIR_OVERRIDE=""
SCOPE=""
BASE_OVERRIDE=""
HEAD_OVERRIDE=""
OUTPUT_OVERRIDE=""
TIMEOUT="1200"
EXECUTOR_OPTION="auto"
ALLOW_HOOKS=false   # hooks require explicit --allow-hooks opt-in (security)
ALLOW_DIRTY=false   # gate refuses a dirty tree atop committed changes unless this opt-in
ACCEPT_SCOPE_TRUNCATION=false
OVERRIDE_FILE=""
# "default" → omit --model → the executor adapter applies its own pinned default
# (for codex, resolved via share/codex-model-aliases.tsv; decoupled from ~/.codex/config.toml).
# The gate is analysis-heavy and must run on a full model, never the spark variant;
# spark is opt-in only.
DISPATCH_MODEL="default"
DISPATCH_SANDBOX="workspace-write"
DISPATCH_ISOLATION=""   # isolation_level; empty = use codex default (workspace-write)
DISPATCH_APPROVAL="never"
# "" → omit --effort → the adapter resolves its own default (medium unless the
# model alias carries its own valid low/medium/high value; see
# runtime/lib/reasoning-effort.sh). Validated inline (not sourced from the lib)
# so copy-mode pr-gate.sh has no extra file dependency for this flag.
DISPATCH_EFFORT=""
INPUT_BRIEF_FILE=""
TEST_CMD_OVERRIDE=""   # --test-cmd: explicit pre-flight test command (see CC-470 Part 3)
TEST_TIMEOUT="3600"    # --test-timeout: independent of --timeout (dispatch budget)
SKIP_PREFLIGHT_TESTS=false

# shellcheck disable=SC2034 # ACCEPT_SCOPE_TRUNCATION is consumed by gate-scope.sh
while [[ $# -gt 0 ]]; do
  case "$1" in
    --cd)
      [[ $# -ge 2 && -n "$2" && "$2" != --* ]] || { printf 'Error: --cd requires a directory\n' >&2; exit 2; }
      WORK_DIR="$2"; shift 2;;
    --run-dir)
      [[ $# -ge 2 && -n "$2" && "$2" != --* ]] || { printf 'Error: --run-dir requires a directory\n' >&2; exit 2; }
      GATE_RUN_DIR_OVERRIDE="$2"; shift 2;;
    --tier)
      [[ $# -ge 2 && -n "$2" && "$2" != --* ]] || { printf 'Error: --tier requires a value\n' >&2; exit 2; }
      TIER_OVERRIDE="$2"; TIER_REQUESTED="$2"; shift 2;;
    --mode)
      [[ $# -ge 2 && -n "$2" && "$2" != --* ]] || { printf 'Error: --mode requires sequential or parallel\n' >&2; exit 2; }
      _gate_set_mode_requested "$2" "--mode" || exit 2
      shift 2;;
    --brief)
      [[ $# -ge 2 && -n "$2" && "$2" != --* ]] || { printf 'Error: --brief requires a file path\n' >&2; exit 2; }
      INPUT_BRIEF_FILE="$2"; shift 2;;
    --policy)
      [[ $# -ge 2 && -n "$2" && "$2" != --* ]] || { printf 'Error: --policy requires generic or maintainer\n' >&2; exit 2; }
      case "$2" in
        generic|maintainer) POLICY_CONSUMER="$2" ;;
        *) printf 'Error: --policy must be generic or maintainer (got: %s)\n' "$2" >&2; exit 2 ;;
      esac
      shift 2;;
    --pass)
      [[ $# -ge 2 && -n "$2" && "$2" != --* ]] || { printf 'Error: --pass requires initial or targeted\n' >&2; exit 2; }
      _gate_set_pass_requested "$2" "--pass" "explicit" || exit 2
      shift 2;;
    --reviewers)
      [[ $# -ge 2 && -n "$2" && "$2" != --* ]] || { printf 'Error: --reviewers requires a reviewer list\n' >&2; exit 2; }
      [[ "$REVIEWERS_EXPLICIT_SEEN" == false ]] || {
        printf 'Error: --reviewers may only be provided once\n' >&2
        exit 2
      }
      REVIEWERS_EXPLICIT_INPUT="$2"; REVIEWERS_EXPLICIT_SEEN=true; shift 2;;
    --targeted)
      [[ $# -ge 2 && -n "$2" && "$2" != --* ]] || { printf 'Error: --targeted requires a reviewer list\n' >&2; exit 2; }
      [[ "$REVIEWERS_SHORTHAND_SEEN" == false ]] || {
        printf 'Error: --targeted may only be provided once\n' >&2
        exit 2
      }
      REVIEWERS_SHORTHAND_INPUT="$2"; REVIEWERS_SHORTHAND_SEEN=true
      _gate_set_pass_requested "targeted" "--targeted" "targeted-shorthand" || exit 2
      shift 2;;
    --initial-result)
      [[ $# -ge 2 && -n "$2" && "$2" != --* ]] || { printf 'Error: --initial-result requires a result path\n' >&2; exit 2; }
      [[ "$INITIAL_RESULT_OPTION_SEEN" == false ]] || {
        printf 'Error: --initial-result may only be provided once\n' >&2
        exit 2
      }
      INITIAL_RESULT_INPUT="$2"; INITIAL_RESULT_OPTION_SEEN=true; shift 2;;
    --reviewer-dir)
      [[ $# -ge 2 ]] || { printf 'Error: --reviewer-dir requires a directory\n' >&2; exit 2; }
      REVIEWER_DIR_OVERRIDE="$2"; shift 2;;
    --scope)      SCOPE="$2";              shift 2;;
    --base)       BASE_OVERRIDE="$2";      shift 2;;
    --head)
      # Guard the operand explicitly: under `set -u` a bare `--head` with no
      # following arg would abort with a raw "unbound variable" instead of the
      # script's controlled CLI error style (mirrors --override-file below).
      [[ $# -ge 2 ]] || { printf 'Error: --head requires a ref\n' >&2; exit 2; }
      HEAD_OVERRIDE="$2";      shift 2;;
    --output)     OUTPUT_OVERRIDE="$2";    shift 2;;
    --executor)   EXECUTOR_OPTION="$2";    shift 2;;
    --model)      DISPATCH_MODEL="$2";     shift 2;;
    --effort)
      case "$2" in
        low|medium|high) ;;
        *) printf 'Error: --effort must be one of: low medium high (got: %s)\n' "$2" >&2; exit 2;;
      esac
      DISPATCH_EFFORT="$2"; shift 2;;
    --isolation)  DISPATCH_ISOLATION="$2"; shift 2;;
    --timeout)    TIMEOUT="$2";            shift 2;;
    --parallel)
      _gate_set_mode_requested "parallel" "--parallel" || exit 2
      shift;;
    --sequential)
      _gate_set_mode_requested "sequential" "--sequential" || exit 2
      shift;;
    --allow-hooks) ALLOW_HOOKS=true;       shift;;
    --allow-dirty) ALLOW_DIRTY=true;       shift;;
    --accept-scope-truncation) ACCEPT_SCOPE_TRUNCATION=true; shift;;
    --override-file)
      # Guard the operand explicitly: under `set -u` a bare `--override-file` with
      # no following arg would abort with a raw "unbound variable" instead of the
      # script's controlled CLI error style.
      [[ $# -ge 2 ]] || { printf 'Error: --override-file requires a file path\n' >&2; exit 2; }
      OVERRIDE_FILE="$2";  shift 2;;
    --policy-override)
      [[ $# -ge 2 && -n "$2" && "$2" != --* ]] || { printf 'Error: --policy-override requires a JSON file path\n' >&2; exit 2; }
      POLICY_OVERRIDE_FILE="$2"; shift 2;;
    --test-cmd)
      [[ $# -ge 2 ]] || { printf 'Error: --test-cmd requires a shell command\n' >&2; exit 2; }
      TEST_CMD_OVERRIDE="$2"; shift 2;;
    --test-timeout)
      [[ $# -ge 2 ]] || { printf 'Error: --test-timeout requires a number of seconds\n' >&2; exit 2; }
      TEST_TIMEOUT="$2";   shift 2;;
    --skip-preflight-tests) SKIP_PREFLIGHT_TESTS=true; shift;;
    -h|--help)
      awk '
        /^# pr-gate-help:start$/ { help=1; next }
        /^# pr-gate-help:end$/ { exit }
        help {
          line=$0
          sub(/^# ?/, "", line)
          print line
        }
      ' "$0"
      exit 0;;
    *)
      printf 'Unknown arg: %s\n' "$1" >&2
      printf 'Accepted: --cd --run-dir --tier --mode --brief --policy --pass --reviewers --targeted --initial-result --reviewer-dir --scope --base --head --output --executor --model --effort --isolation --timeout --parallel --sequential --allow-hooks --allow-dirty --accept-scope-truncation --override-file --policy-override --test-cmd --test-timeout --skip-preflight-tests (-h for help)\n' >&2
      exit 2;;
  esac
done

if [[ -z "$WORK_DIR" ]]; then
  printf 'Error: --cd <dir> is required\n' >&2; exit 2
fi
if [[ ! -d "$WORK_DIR" ]]; then
  printf 'Error: working dir not found: %s\n' "$WORK_DIR" >&2; exit 2
fi
# Trust-boundary comparisons and every derived artifact path must use the same
# physical workspace identity. A raw relative or symlink-bearing --cd value can
# otherwise make an in-workspace reviewer directory look external and trusted.
WORK_DIR="$(cd "$WORK_DIR" && pwd -P)"
if [[ -n "$GATE_RUN_DIR_OVERRIDE" && "$GATE_RUN_DIR_OVERRIDE" != /* ]]; then
  printf 'Error: --run-dir must be an absolute path: %s\n' "$GATE_RUN_DIR_OVERRIDE" >&2; exit 2
fi

# CC-532: load the remaining domain modules only after argument parsing can
# finish. Their paths are still resolved from the one layout authority loaded
# by the early bootstrap above.
_gate_scope_module="$PR_GATE_LIB_DIR/gate-scope.sh"
_gate_subject_module="$PR_GATE_LIB_DIR/gate-subject.sh"
for _gate_domain_module in "$_gate_scope_module" "$_gate_subject_module"; do
  if [[ ! -r "$_gate_domain_module" ]]; then
    printf "pr-gate: canonical domain module unavailable: %s\n" \
      "$_gate_domain_module" >&2
    exit 2
  fi
  # shellcheck disable=SC1090  # path is derived by gate-layout.sh
  . "$_gate_domain_module"
done
unset _gate_scope_module _gate_subject_module _gate_domain_module

# _gate_lib_unavailable -- fail closed on a bundle that lost a canonical library.
#
# A gate bundle is a directory contract, not a single file: the entrypoint is
# only runnable beside lib/, core/policy/, agents/ and adapters/. Missing
# libraries are therefore a damaged bundle, never a supported topology to
# degrade into. Must be called from top level so `exit` leaves the gate.
#
# Load sites that already publish a tested, dependency-specific diagnostic
# (executor router, gate memory runtime, policy reader) keep it rather than
# adopting this wording: their messages and exit codes are existing contracts.
# This helper is the default for load sites that have no such contract.
_gate_lib_unavailable() {
  printf 'pr-gate: canonical library unavailable for %s layout: %s\n' \
    "$PR_GATE_LAYOUT" "$1" >&2
  printf 'pr-gate: a gate bundle must carry lib/ beside the entrypoint\n' >&2
  exit 2
}

# QA rules dir resolution for reviewer dispatch (CC-541): a codex-dispatched
# qa-tester reviewer runs in its own subprocess and has no access to this
# orchestrator's shell environment except what's exported into it. Its own
# boot logic (agents/qa-tester.md step 1) already says "if QA_RULES_DIR is
# set, use it directly" -- so resolving and exporting it here, using the same
# repos-root convention agents/qa-tester.md documents and
# runtime/lib/repo-layout.sh's pm_dispatch_repos_root() already implements
# (PM_DISPATCH_REPOS_ROOT -> dirname(PM_DISPATCH_REPO) -> dirname(WORK_DIR)),
# makes that existing fallback fire deterministically with zero
# prompt-contract change. A live smoke dispatch confirmed the codex sandbox
# does not block reads outside --cd; the prior failure was simply that
# nothing ever told the reviewer where to look. Left unset when genuinely
# absent so CC-447's clean-machine stop-and-ask path is untouched, and the
# host-confirmed marker lets downstream diagnostics distinguish "rules exist
# but reviewer still reported missing" from "rules genuinely absent" instead
# of sharing one ambiguous message.
# pm_dispatch_repos_root is called in a subshell (command substitution),
# consistent with this script's stated policy of not importing runtime lib
# namespaces into its own long-lived top-level shell (see
# pmctl_gate_dispatch_lib_load below).
if [[ -z "${QA_RULES_DIR:-}" ]]; then
  _qa_repo_layout_path="$PR_GATE_LIB_DIR/repo-layout.sh"
  if [[ -r "$_qa_repo_layout_path" ]]; then
    # shellcheck source=runtime/lib/repo-layout.sh
    _qa_repos_root="$(. "$_qa_repo_layout_path" && pm_dispatch_repos_root "$WORK_DIR")" || _qa_repos_root=""
  else
    # Copy-mode bundle without runtime/lib/ present: fall back to the same
    # precedence inline (mirrors the gate-result-verify.sh fallback below).
    _qa_repos_root="${PM_DISPATCH_REPOS_ROOT:-${PM_DISPATCH_REPO:+$(dirname "$PM_DISPATCH_REPO")}}"
    _qa_repos_root="${_qa_repos_root:-$(dirname "$WORK_DIR")}"
  fi
  unset _qa_repo_layout_path
  if [[ -n "$_qa_repos_root" ]]; then
    _qa_rules_dir="${_qa_repos_root}/qa-testing-rules"
    _qa_rules_entry="${QA_RULES_ENTRY:-AGENT.md}"
    if [[ -d "$_qa_rules_dir" && -r "$_qa_rules_dir/$_qa_rules_entry" ]]; then
      export QA_RULES_DIR="$_qa_rules_dir"
      # Read by gate_reviewer_protocol_verify in runtime/lib/gate-result-verify.sh,
      # which this entrypoint sources; ShellCheck cannot see across that boundary.
      # shellcheck disable=SC2034
      PM_DISPATCH_QA_RULES_DIR_HOST_CONFIRMED=1
    fi
    unset _qa_rules_dir _qa_rules_entry
  fi
  unset _qa_repos_root
fi

GATE_RESULT_VERIFY_PATH="$PR_GATE_LIB_DIR/gate-result-verify.sh"
[[ -r "$GATE_RESULT_VERIFY_PATH" ]] || _gate_lib_unavailable "$GATE_RESULT_VERIFY_PATH"
# shellcheck source=runtime/lib/gate-result-verify.sh
# shellcheck disable=SC1090  # path is derived from the classified topology
. "$GATE_RESULT_VERIFY_PATH"

# CC-532: assurance path validation and machine sidecar publication have one
# canonical source owner; the entrypoint only composes the module and invokes it.
GATE_ASSURANCE_MODULE="$PR_GATE_LIB_DIR/gate-assurance.sh"
[[ -r "$GATE_ASSURANCE_MODULE" ]] || _gate_lib_unavailable "$GATE_ASSURANCE_MODULE"
# shellcheck source=runtime/lib/gate-assurance.sh
# shellcheck disable=SC1090  # path is derived from the classified topology
. "$GATE_ASSURANCE_MODULE"
unset GATE_ASSURANCE_MODULE

# CC-532: policy and reviewer contract modules share the same composition root.
for _gate_contract_module in \
    "$PR_GATE_LIB_DIR/gate-policy.sh" \
    "$PR_GATE_LIB_DIR/gate-reviewer-contract.sh"; do
  if [[ ! -r "$_gate_contract_module" ]]; then
    printf "pr-gate: canonical contract module unavailable: %s\n" \
      "$_gate_contract_module" >&2
    exit 2
  fi
  # shellcheck disable=SC1090  # path is derived by gate-layout.sh
  . "$_gate_contract_module"
done
unset _gate_contract_module

if ! command -v jq >/dev/null 2>&1; then
  printf 'Error: pr-gate requires jq on PATH to produce and verify gate assurance\n' >&2
  exit 2
fi

# ── Resolve assurance policy coordinates ─────────────────────────────────────
# These are resolved before any executor routing or dispatch. The LLM receives
# the resolved values as read-only context; it does not choose or infer them.
if ! GATE_TIER_VALUES="$(_gate_assurance_policy_values tiers tier)"; then
  printf 'Error: invalid gate tier policy source\n' >&2
  exit 2
fi
if ! GATE_MODE_VALUES="$(_gate_assurance_policy_values modes mode)"; then
  printf 'Error: invalid gate mode policy source\n' >&2
  exit 2
fi
if ! GATE_PASS_KIND_VALUES="$(_gate_assurance_policy_values pass-kinds pass_kind)"; then
  printf 'Error: invalid gate pass-kind policy source\n' >&2
  exit 2
fi

if ! GATE_PASS_KIND_DEFAULT="$(_gate_assurance_policy_lookup pass-kinds is_default true pass_kind)"; then
  printf 'Error: gate pass-kind policy must declare exactly one default\n' >&2
  exit 2
fi
if [[ "$GATE_PASS_KIND_DEFAULT" != "initial" ]]; then
  printf 'Error: gate pass-kind policy default must remain initial\n' >&2
  exit 2
fi

if [[ -n "$TIER_OVERRIDE" ]] \
    && ! _gate_assurance_policy_lookup tiers tier "$TIER_OVERRIDE" default_reviewers >/dev/null; then
  printf 'Error: --tier must be one of: %s (got: %s)\n' \
    "$(printf '%s\n' "$GATE_TIER_VALUES" | awk 'BEGIN{ORS=" "} {print} END{print "\n"}' | sed 's/[[:space:]]*$//')" \
    "$TIER_OVERRIDE" >&2
  exit 2
fi

if [[ "$MODE_OPTION_SEEN" == true ]] \
    && ! _gate_assurance_policy_lookup modes mode "$MODE_REQUESTED" topology >/dev/null; then
  printf 'Error: --mode must be one of: %s (got: %s)\n' \
    "$(printf '%s\n' "$GATE_MODE_VALUES" | awk 'BEGIN{ORS=" "} {print} END{print "\n"}' | sed 's/[[:space:]]*$//')" \
    "$MODE_REQUESTED" >&2
  exit 2
fi

PASS_KIND_RESOLVED="$PASS_KIND_REQUESTED"
if ! PASS_SCOPE="$(_gate_assurance_policy_lookup pass-kinds pass_kind "$PASS_KIND_RESOLVED" scope)" \
    || ! PASS_REQUIRES_INITIAL="$(_gate_assurance_policy_lookup pass-kinds pass_kind "$PASS_KIND_RESOLVED" requires_initial_result)"; then
  printf 'Error: gate pass kind must be one of: %s (got: %s)\n' \
    "$(printf '%s\n' "$GATE_PASS_KIND_VALUES" | awk 'BEGIN{ORS=" "} {print} END{print "\n"}' | sed 's/[[:space:]]*$//')" \
    "$PASS_KIND_RESOLVED" >&2
  exit 2
fi
case "$PASS_REQUIRES_INITIAL" in
  true)
    if [[ -z "$INITIAL_RESULT_INPUT" ]]; then
      printf 'Error: --pass targeted requires --initial-result <path>\n' >&2
      exit 2
    fi
    ;;
  false)
    if [[ -n "$INITIAL_RESULT_INPUT" ]]; then
      printf 'Error: --initial-result is only valid with --pass targeted\n' >&2
      exit 2
    fi
    ;;
  *)
    printf 'Error: invalid requires_initial_result value for pass kind %s: %s\n' \
      "$PASS_KIND_RESOLVED" "$PASS_REQUIRES_INITIAL" >&2
    exit 2
    ;;
esac

INITIAL_RESULT_RESOLVED=""
if [[ -n "$INITIAL_RESULT_INPUT" ]]; then
  _initial_result_candidate="$INITIAL_RESULT_INPUT"
  [[ "$_initial_result_candidate" == /* ]] \
    || _initial_result_candidate="$WORK_DIR/$_initial_result_candidate"
  if [[ ! -f "$_initial_result_candidate" || ! -r "$_initial_result_candidate" \
      || ! -s "$_initial_result_candidate" ]]; then
    printf 'Error: --initial-result must name a readable, non-empty file: %s\n' \
      "$INITIAL_RESULT_INPUT" >&2
    exit 2
  fi
  _initial_result_parent="$(cd "$(dirname "$_initial_result_candidate")" && pwd -P)" || {
    printf 'Error: cannot resolve --initial-result parent: %s\n' "$INITIAL_RESULT_INPUT" >&2
    exit 2
  }
  INITIAL_RESULT_RESOLVED="$_initial_result_parent/$(basename "$_initial_result_candidate")"
  if ! gate_result_verify "$INITIAL_RESULT_RESOLVED" "" "targeted initial result"; then
    printf 'Error: --initial-result is not a structurally valid gate result: %s\n' \
      "$INITIAL_RESULT_INPUT" >&2
    exit 2
  fi
  # The initial result proves this is a remediation pass, but it never
  # authorizes reuse of an earlier gate's tier or conclusion. This invocation
  # resolves rigor from its own immutable subject and current policy.
  unset _initial_result_candidate _initial_result_parent
fi

# Build the closed reviewer vocabulary from tier defaults in source order.
# This is a vocabulary only: a tier default is not actual selected coverage.
ALL_REVIEWERS=""
while IFS= read -r _policy_tier; do
  _policy_reviewers="$(_gate_assurance_policy_lookup tiers tier "$_policy_tier" default_reviewers)" || {
    printf 'Error: invalid default_reviewers for gate tier: %s\n' "$_policy_tier" >&2
    exit 2
  }
  _gate_assurance_policy_lookup tiers tier "$_policy_tier" evidence_floor >/dev/null || {
    printf 'Error: missing evidence_floor for gate tier: %s\n' "$_policy_tier" >&2
    exit 2
  }
  for _policy_reviewer in $(printf '%s' "$_policy_reviewers" | tr ',' ' '); do
    if [[ ! "$_policy_reviewer" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
      printf 'Error: invalid reviewer name in gate tier policy: %s\n' "$_policy_reviewer" >&2
      exit 2
    fi
    if [[ " $ALL_REVIEWERS " != *" $_policy_reviewer "* ]]; then
      ALL_REVIEWERS="${ALL_REVIEWERS:+$ALL_REVIEWERS }$_policy_reviewer"
    fi
  done
done <<< "$GATE_TIER_VALUES"
unset _policy_tier _policy_reviewers _policy_reviewer
if [[ -z "$ALL_REVIEWERS" ]]; then
  printf 'Error: gate tier policy did not declare any reviewers\n' >&2
  exit 2
fi
_gate_policy_validate_sources "$ALL_REVIEWERS" || exit 2

# --reviewers owns the coverage coordinate and --targeted is its compatibility
# spelling. Normalize both only after the policy vocabulary is available, so
# equal reviewer sets remain compatible even when their input order differs.
if [[ "$REVIEWERS_EXPLICIT_SEEN" == true ]]; then
  _explicit_reviewers="$(_gate_policy_normalize_reviewer_list \
    "$REVIEWERS_EXPLICIT_INPUT" "$ALL_REVIEWERS" "--reviewers")" || exit 2
fi
if [[ "$REVIEWERS_SHORTHAND_SEEN" == true ]]; then
  _shorthand_reviewers="$(_gate_policy_normalize_reviewer_list \
    "$REVIEWERS_SHORTHAND_INPUT" "$ALL_REVIEWERS" "--targeted")" || exit 2
fi
if [[ "$REVIEWERS_EXPLICIT_SEEN" == true && "$REVIEWERS_SHORTHAND_SEEN" == true ]]; then
  if [[ "$(printf '%s\n' $_explicit_reviewers | LC_ALL=C sort)" \
      != "$(printf '%s\n' $_shorthand_reviewers | LC_ALL=C sort)" ]]; then
    printf 'Error: --reviewers and --targeted request different reviewer coverage\n' >&2
    exit 2
  fi
  REVIEWERS_OVERRIDE="$REVIEWERS_EXPLICIT_INPUT"
  REVIEWERS_OPTION_SOURCE="--reviewers/--targeted"
  COVERAGE_SYNTAX_SOURCE="mixed"
elif [[ "$REVIEWERS_EXPLICIT_SEEN" == true ]]; then
  REVIEWERS_OVERRIDE="$REVIEWERS_EXPLICIT_INPUT"
  REVIEWERS_OPTION_SOURCE="--reviewers"
  COVERAGE_SYNTAX_SOURCE="explicit"
elif [[ "$REVIEWERS_SHORTHAND_SEEN" == true ]]; then
  REVIEWERS_OVERRIDE="$REVIEWERS_SHORTHAND_INPUT"
  REVIEWERS_OPTION_SOURCE="--targeted"
  COVERAGE_SYNTAX_SOURCE="targeted-shorthand"
fi
unset _explicit_reviewers _shorthand_reviewers

case "$COVERAGE_SYNTAX_SOURCE" in
  default) COVERAGE_SELECTION_BASIS="policy-default" ;;
  explicit) COVERAGE_SELECTION_BASIS="explicit" ;;
  targeted-shorthand) COVERAGE_SELECTION_BASIS="targeted-shorthand" ;;
  mixed) COVERAGE_SELECTION_BASIS="mixed" ;;
esac

if [[ "$PASS_KIND_REQUESTED" == targeted && -z "$REVIEWERS_OVERRIDE" ]]; then
  printf 'Error: --pass targeted requires --reviewers <list> (or --targeted <list>)\n' >&2
  exit 2
fi

_gate_policy_source_count=0
for _gate_policy_table in tiers modes pass-kinds consumers signals; do
  if _gate_assurance_policy_path "$_gate_policy_table" >/dev/null; then
    _gate_policy_source_count=$((_gate_policy_source_count + 1))
  fi
done
case "$_gate_policy_source_count" in
  5) GATE_ASSURANCE_POLICY_SOURCE="canonical" ;;
  0) GATE_ASSURANCE_POLICY_SOURCE="generated-snapshot" ;;
  *) GATE_ASSURANCE_POLICY_SOURCE="mixed" ;;
esac
unset _gate_policy_source_count _gate_policy_table

# Every topology sources the same executor router. The explicit-root API keeps
# the library reusable when lib/ is directly beneath a copy bundle instead of
# <root>/runtime/lib. Missing router/reader dependencies are hard failures; the
# gate never reconstructs a conventional dispatch.sh path or sources a router
# from outside the classified topology.
EXECUTOR_ROUTER_PATH="$PR_GATE_LIB_DIR/executor-router.sh"
if [[ ! -r "$EXECUTOR_ROUTER_PATH" ]]; then
  printf 'pr-gate: canonical executor router unavailable for %s layout: %s\n' \
    "$PR_GATE_LAYOUT" "$EXECUTOR_ROUTER_PATH" >&2
  exit 2
fi
# shellcheck source=runtime/lib/executor-router.sh
# shellcheck disable=SC1090  # path is selected from the classified topology
if ! . "$EXECUTOR_ROUTER_PATH"; then
  printf 'pr-gate: failed to load canonical executor router: %s\n' \
    "$EXECUTOR_ROUTER_PATH" >&2
  exit 2
fi
for _gate_router_fn in resolve_executor_at dispatch_via_at \
  adapter_manifest_dispatch_path adapter_manifest_runner_kind; do
  if ! declare -F "$_gate_router_fn" >/dev/null 2>&1; then
    printf 'pr-gate: canonical executor router dependency unavailable: %s\n' \
      "$_gate_router_fn" >&2
    exit 2
  fi
done
unset _gate_router_fn

ARTIFACT_PATHS_PATH="$PR_GATE_LIB_DIR/artifact-paths.sh"
[[ -r "$ARTIFACT_PATHS_PATH" ]] || _gate_lib_unavailable "$ARTIFACT_PATHS_PATH"
# shellcheck source=runtime/lib/artifact-paths.sh
# shellcheck disable=SC1090  # path is derived from the classified topology
. "$ARTIFACT_PATHS_PATH"

# Executor-name validation is delegated to canonical resolve_executor_at: it is
# the single, data-driven authority — `auto` autodetects and any other value must
# be a routable Adapter in the classified root, fail-closed on unknown. A local
# enum pre-check would silently reject a manifest-only Adapter before the router.

_validate_isolation_level() {
  local level="$1" policy_file="$2"
  local policy_lib="$PR_GATE_LIB_DIR/pmctl-policy.sh"
  if ! declare -F pmctl_policy_contains >/dev/null 2>&1; then
    if [[ ! -r "$policy_lib" ]]; then
      printf 'Error: policy reader is unavailable: %s\n' "$policy_lib" >&2
      return 2
    fi
    # shellcheck source=runtime/lib/pmctl-policy.sh
    . "$policy_lib"
  fi
  if [[ -r "$policy_file" ]]; then
    if ! pmctl_policy_contains "$policy_file" "$level" values; then
      local valid_levels
      valid_levels="$(pmctl_policy_values "$policy_file" values | tr '\n' ' ' | sed 's/ $//')"
      printf "Error: --isolation must be one of: %s (got: %s)\n" "$valid_levels" "$level" >&2
      return 2
    fi
  else
    printf "Error: isolation policy source is unavailable: %s\n" "$policy_file" >&2
    return 2
  fi
}

if [[ -n "$DISPATCH_ISOLATION" ]]; then
  ISOLATION_POLICY_FILE="$(gate_layout_policy_file isolation-level.yaml)"
  _validate_isolation_level "$DISPATCH_ISOLATION" "$ISOLATION_POLICY_FILE" || exit 2
fi

EXECUTOR="$(resolve_executor_at "$PR_GATE_EXECUTOR_ROOT" "$EXECUTOR_OPTION")" || exit 2

# Reviewer briefs instruct the dispatched session to call `pmctl guard check`
# before writing its output file. For a claude reviewer, that instruction must
# stay a bare `pmctl` invocation -- claude's own PreToolUse permission-allow
# list matches the literal `Bash(pmctl ...)` prefix, and any wrapping (command
# substitution, absolute-path rewrite) breaks that match and stalls headless
# dispatch on an unanswerable permission prompt (see feedback_pmctl_bare_invocation).
# A codex reviewer has no such prefix-allowlist (approval_policy=never governs
# it instead), and has been observed twice (2026-07-07) failing to resolve the
# bare `pmctl` command inside its sandboxed exec environment (CC-469) -- cause
# unconfirmed, but codex's own PATH resolution for the command is not reliable.
# Resolve the absolute path once, in pr-gate's own environment, and embed
# that instead of the bare word for codex reviewer briefs specifically.
# Best-effort: PATH lookup first (the normal install), falling back to the
# sibling cli/pmctl next to this script (source checkouts without a PATH
# symlink). If neither resolves -- e.g. a test fixture that copies pr-gate.sh
# standalone without cli/pmctl alongside it -- fall back to the bare word so
# behavior is unchanged rather than fail-closing the whole gate on it.
GUARD_PMCTL_CMD="pmctl"
if [[ "$EXECUTOR" == "codex" ]]; then
  # Prefer an explicit transport bundled beside a copy-mode gate before the
  # host PATH.  A standalone copied gate must not accidentally bind to an
  # unrelated installed pmctl when its fixture/deployment provides bin/pmctl.
  _guard_pmctl_abs=""
  if [[ -n "$PR_GATE_INSTALLED_COPY_ROOT" ]]; then
    # The official installed topology does not carry cli/ below scripts/. Use
    # its installer-managed PATH entry (or retain the bare fail-loud command)
    # and never probe foreign ~/cli or ~/.claude/scripts/{cli,bin} candidates.
    _guard_pmctl_abs="$(command -v pmctl 2>/dev/null || true)"
  elif [[ -x "$PR_GATE_BUNDLE_ROOT/cli/pmctl" ]]; then
    _guard_pmctl_abs="$PR_GATE_BUNDLE_ROOT/cli/pmctl"
  elif [[ -x "$PR_GATE_BUNDLE_ROOT/bin/pmctl" ]]; then
    _guard_pmctl_abs="$PR_GATE_BUNDLE_ROOT/bin/pmctl"
  else
    _guard_pmctl_abs="$(command -v pmctl 2>/dev/null || true)"
  fi
  [[ -n "$_guard_pmctl_abs" ]] && GUARD_PMCTL_CMD="$_guard_pmctl_abs"
  unset _guard_pmctl_abs
fi

# Gate reviewers are producer children, not opaque adapter processes.  Resolve
# the dispatch lifecycle as a SHARED RUNTIME dependency, not as a callback into
# the public CLI: docs/architecture/script-domain-ownership.md requires
# dependencies to flow cli/pmctl -> shared runtime -> adapter, so a producer
# entrypoint under runtime/bin must reach `pmctl_dispatch_run` through
# runtime/lib rather than by re-entering `cli/pmctl`.
#
# Only the repo layout can take this route. The parent-operation libraries still
# derive their shared runtime root from <root>/runtime/lib; installed and
# standalone copies intentionally keep direct Adapter dispatch even though the
# executor router itself now supports their explicit bundle roots.
PMCTL_DISPATCH_LIB_DIR=""
PMCTL_DISPATCH_ROOT=""
if [[ "$PR_GATE_LAYOUT" == repo \
    && -r "$PR_GATE_LIB_DIR/pmctl-dispatch.sh" \
    && -d "$PR_GATE_BUNDLE_ROOT/adapters" ]]; then
  PMCTL_DISPATCH_LIB_DIR="$PR_GATE_LIB_DIR"
  PMCTL_DISPATCH_ROOT="$PR_GATE_EXECUTOR_ROOT"
fi
if [[ -z "$PMCTL_DISPATCH_LIB_DIR" && ( "$EXECUTOR" == codex || "$EXECUTOR" == claude ) ]]; then
  printf 'pr-gate: parent-operation tracking unavailable for this deployment layout; using compatible direct reviewer dispatch\n' >&2
fi

# Libraries are sourced per dispatch inside a subshell rather than at this
# script's top level.  The gate's own shell is long-lived: it evaluates reviewer
# commands, runs a parallel watchdog, and parses results, so importing pmctl's
# whole global namespace into it would trade one coupling problem for a worse
# one.  A subshell keeps the previous process-level isolation while the
# dependency direction stays runtime -> runtime.
pmctl_gate_dispatch_lib_load() {
  local _lib
  for _lib in identifier-policy runner-kind adapter-manifest repo-layout \
    detached-launch pmctl-policy pmctl-fs pmctl-adapter pmctl-guard \
    executor-router pmctl-dispatch pmctl-operation; do
    # shellcheck disable=SC1090
    [[ -r "$PMCTL_DISPATCH_LIB_DIR/$_lib.sh" ]] && . "$PMCTL_DISPATCH_LIB_DIR/$_lib.sh"
  done
  declare -F pmctl_dispatch_run >/dev/null || return 1
  return 0
}

_gate_dispatch_capture() {
  local brief_file="$1" run_id="$2" status="$3"
  local brief_base role=combined reviewer="" capture_file capture_tmp r
  [[ -n "${GATE_ASSURANCE_CAPTURE_DIR:-}" ]] || return 0
  brief_base="$(basename "$brief_file")"
  if [[ "$brief_base" == *-synthesis.md ]]; then
    role=synthesis
  else
    for r in ${REVIEWERS:-}; do
      if [[ "$brief_base" == *-"$r".md ]]; then
        role=reviewer
        reviewer="$r"
        break
      fi
    done
  fi
  capture_file="$GATE_ASSURANCE_CAPTURE_DIR/${role}${reviewer:+-$reviewer}.json"
  capture_tmp="$(mktemp "$GATE_ASSURANCE_CAPTURE_DIR/.capture.XXXXXX")" || {
    printf 'Error: unable to create private gate dispatch capture\n' >&2
    return 1
  }
  if ! jq -n --arg role "$role" --arg reviewer "$reviewer" --arg status "$status" \
    --arg run_id "$run_id" \
    '{role:$role,reviewer:(if $reviewer == "" then null else $reviewer end),
      status:$status,run_id:$run_id,evidence_status:"verified"}' > "$capture_tmp"; then
    rm -f -- "$capture_tmp"
    return 1
  fi
  _gate_assurance_destination_check "$capture_file" || {
    rm -f -- "$capture_tmp"
    return 1
  }
  mv -- "$capture_tmp" "$capture_file" || {
    rm -f -- "$capture_tmp"
    return 1
  }
}

# Gate reviewers are producer children, not opaque adapter processes.  Route
# each invocation through pmctl's detached dispatch lifecycle, then wait for
# its authenticated terminal sentinel.  The optional parent id is injected by
# `pmctl gate run`; without it this remains a compatible standalone gate path.
pmctl_gate_dispatch_and_wait() {
  local executor="$1" brief_file="$2" working_dir="$3" model="$4" sandbox="$5" approval="$6" timeout="$7" isolation_level="${8:-}" effort="${9:-}"
  # pmctl dispatch enforces the executor write boundary at `/tmp/brief-*.md`.
  # Gate briefs are intentionally retained under the private run directory, so
  # copy each one to a one-shot guardable snapshot before handing it to pmctl.
  # Detached dispatch snapshots that input again before its supervisor starts;
  # removing this intermediate copy after `dispatch run` returns is therefore
  # safe and keeps the gate's durable source of truth inside the run directory.
  local dispatch_brief dispatch_brief_name rc
  dispatch_brief="$(mktemp -p /tmp "brief-gate-XXXXXX.md")" || {
    printf 'pr-gate: failed to create guardable dispatch brief\n' >&2
    return 1
  }
  # Preserve the source basename (notably the `-synthesis.md` role suffix)
  # across the guarded /tmp snapshot.  Adapters may use the brief role to
  # select their result contract; a generic mktemp basename erased it.
  dispatch_brief_name="${dispatch_brief%.md}-$(basename "$brief_file")"
  if ! command -p mv "$dispatch_brief" "$dispatch_brief_name"; then
    rm -f "$dispatch_brief"
    printf 'pr-gate: failed to name guardable dispatch brief\n' >&2
    return 1
  fi
  dispatch_brief="$dispatch_brief_name"
  if ! cp "$brief_file" "$dispatch_brief"; then
    rm -f "$dispatch_brief"
    printf 'pr-gate: failed to snapshot reviewer brief for dispatch\n' >&2
    return 1
  fi
  local -a args=(--adapter "$executor" --cd "$working_dir" --brief-file "$dispatch_brief" --lifecycle detached --timeout "$timeout")
  [[ -n "$model" && "$model" != default ]] && args+=(--model "$model")
  [[ -n "$isolation_level" ]] && args+=(--isolation "$isolation_level")
  [[ -n "$effort" ]] && args+=(--effort "$effort")
  [[ -n "${PM_DISPATCH_TRACE_DIR:-}" ]] && args+=(--trace-dir "$PM_DISPATCH_TRACE_DIR")
  [[ "$executor" == codex ]] && args+=(--sandbox "$sandbox" --approval "$approval")
  [[ -n "${PM_GATE_PARENT_OPERATION:-}" ]] && args+=(--parent-operation "$PM_GATE_PARENT_OPERATION")
  local run_id
  run_id="$(
    pmctl_gate_dispatch_lib_load || exit 2
    pmctl_dispatch_run "$PMCTL_DISPATCH_ROOT" "${args[@]}"
  )" || {
    rc=$?
    rm -f "$dispatch_brief"
    return "$rc"
  }
  run_id="$(printf '%s\n' "$run_id" | tail -1 | tr -d '[:space:]')"
  if ! (
    pmctl_gate_dispatch_lib_load || exit 2
    pm_identifier_run_is_valid "$run_id"
  ); then
    rm -f "$dispatch_brief"
    printf 'pr-gate: dispatch returned invalid run id\n' >&2
    return 2
  fi
  local dispatch_status=passed
  rc=0
  (
    pmctl_gate_dispatch_lib_load || exit 2
    pmctl_dispatch_wait "$PMCTL_DISPATCH_ROOT" "$run_id" --cd "$working_dir" --timeout "$timeout"
  ) || {
    rc=$?
    dispatch_status=failed
  }
  _gate_dispatch_capture "$brief_file" "$run_id" "$dispatch_status" || {
    rm -f "$dispatch_brief"
    return 1
  }
  rm -f "$dispatch_brief"
  return "$rc"
}

# Format direct Adapter dispatch through the canonical explicit-root router.
# The repo-layout branch overrides this Gate-level transport seam only; it does
# not replace any executor detection, manifest routing, or argv construction.
# Call sites receive a safely-quoted command string, preserving the parallel
# watchdog/eval structure while moving repo-layout lifecycle ownership to pmctl.
gate_dispatch_command() {
  if [[ -n "$PMCTL_DISPATCH_LIB_DIR" ]]; then
    local first=1 arg
    for arg in pmctl_gate_dispatch_and_wait "$@"; do
      if [[ "$first" -eq 1 ]]; then first=0; else printf ' '; fi
      printf '%q' "$arg"
    done
    printf '\n'
  else
    dispatch_via_at "$PR_GATE_EXECUTOR_ROOT" "$@"
  fi
}

# Every supported executor now dispatches an INDEPENDENT subprocess (codex `codex
# exec`, claude headless `claude --print`) and writes the result in-process, which
# the gate then integrity-checks. This flag is the seam where a future
# non-subprocess (e.g. host-handover) executor would branch; both current
# executors take the subprocess path.
EXECUTOR_IS_SUBPROCESS=true

unset EXECUTOR_ROUTER_PATH

cd "$WORK_DIR"

# ── Load gate overrides ───────────────────────────────────────────────────────
# Load a free-form reviewer override into memory only after its final path
# component and the bytes copied to a private snapshot agree.  Bash has no
# O_NOFOLLOW open primitive, so this is deliberately a bounded Linux/WSL2
# check/use protocol rather than a claim of protection from a same-uid writer.
# It protects the reviewer channel from ordinary symlink redirects and from a
# replacement observed while this loader is running; dispatches consume only
# GATE_OVERRIDES_CONTENT, never the source path again.
gate_load_reviewer_override() {
  local caller_input="$1" candidate="$2" parent source snapshot
  local identity_before identity_after identity_final snapshot_sha source_sha
  local mode permissions snapshot_size nul_stripped_size

  _gate_reviewer_override_error() {
    printf 'Error: reviewer override must name a readable, non-empty, NUL-free regular non-symlink file: %s (%s)\n' \
      "$caller_input" "$1" >&2
  }

  if [[ -L "$candidate" ]]; then
    _gate_reviewer_override_error 'final path component is a symlink'
    return 2
  fi
  if [[ ! -e "$candidate" ]]; then
    _gate_reviewer_override_error 'file does not exist'
    return 2
  fi
  if [[ ! -f "$candidate" ]]; then
    _gate_reviewer_override_error 'not a regular file'
    return 2
  fi
  if [[ ! -r "$candidate" ]]; then
    _gate_reviewer_override_error 'file is not readable'
    return 2
  fi
  if [[ ! -s "$candidate" ]]; then
    _gate_reviewer_override_error 'file is empty'
    return 2
  fi
  if ! command -v stat >/dev/null 2>&1; then
    _gate_reviewer_override_error 'required file identity primitive (stat) is unavailable'
    return 2
  fi
  # `-c` is the supported GNU stat interface on Linux and WSL2.  Checking a
  # readable permission bit avoids root making a chmod 000 fixture look usable.
  mode="$(stat -Lc '%a' -- "$candidate" 2>/dev/null)" || {
    _gate_reviewer_override_error 'cannot inspect file identity'
    return 2
  }
  if [[ ! "$mode" =~ ^[0-7]{1,4}$ ]]; then
    _gate_reviewer_override_error 'cannot interpret file permission bits'
    return 2
  fi
  permissions="00$mode"
  permissions="${permissions: -3}"
  if [[ "$permissions" != *[4567]* ]]; then
    _gate_reviewer_override_error 'file is not readable'
    return 2
  fi
  parent="$(cd "$(dirname "$candidate")" && pwd -P)" || {
    _gate_reviewer_override_error 'parent directory cannot be resolved'
    return 2
  }
  source="$parent/$(basename "$candidate")"
  identity_before="$(stat -Lc '%d:%i:%s:%Y:%Z:%f' -- "$source" 2>/dev/null)" || {
    _gate_reviewer_override_error 'cannot capture file identity'
    return 2
  }
  snapshot="$(mktemp "${TMPDIR:-/tmp}/pr-gate-reviewer-override.XXXXXX")" || {
    _gate_reviewer_override_error 'cannot create private content snapshot'
    return 2
  }
  GATE_REVIEWER_OVERRIDE_SNAPSHOT="$snapshot"
  if ! cat -- "$source" > "$snapshot"; then
    gate_cleanup_reviewer_override_snapshot
    _gate_reviewer_override_error 'file could not be read into a private snapshot'
    return 2
  fi
  if [[ -L "$candidate" || ! -f "$candidate" || ! -r "$candidate" || ! -s "$candidate" ]]; then
    gate_cleanup_reviewer_override_snapshot
    _gate_reviewer_override_error 'file changed or was redirected while being read'
    return 2
  fi
  identity_after="$(stat -Lc '%d:%i:%s:%Y:%Z:%f' -- "$source" 2>/dev/null)" || {
    gate_cleanup_reviewer_override_snapshot
    _gate_reviewer_override_error 'file identity disappeared while being read'
    return 2
  }
  if [[ "$identity_before" != "$identity_after" ]]; then
    gate_cleanup_reviewer_override_snapshot
    _gate_reviewer_override_error 'file identity changed while being read'
    return 2
  fi
  snapshot_size="$(stat -Lc '%s' -- "$snapshot" 2>/dev/null)" || {
    gate_cleanup_reviewer_override_snapshot
    _gate_reviewer_override_error 'cannot inspect private content snapshot'
    return 2
  }
  nul_stripped_size="$(LC_ALL=C tr -d '\000' < "$snapshot" | wc -c)" || {
    gate_cleanup_reviewer_override_snapshot
    _gate_reviewer_override_error 'cannot validate override text bytes'
    return 2
  }
  nul_stripped_size="${nul_stripped_size//[[:space:]]/}"
  if [[ "$snapshot_size" != "$nul_stripped_size" ]]; then
    gate_cleanup_reviewer_override_snapshot
    _gate_reviewer_override_error 'file contains a NUL byte'
    return 2
  fi
  snapshot_sha="$(_gate_result_sha256_file "$snapshot")" || {
    gate_cleanup_reviewer_override_snapshot
    return 2
  }
  source_sha="$(_gate_result_sha256_file "$source")" || {
    gate_cleanup_reviewer_override_snapshot
    _gate_reviewer_override_error 'file could not be rechecked after snapshot'
    return 2
  }
  if [[ "$snapshot_sha" != "$source_sha" ]]; then
    gate_cleanup_reviewer_override_snapshot
    _gate_reviewer_override_error 'file content changed while being read'
    return 2
  fi
  if [[ -L "$candidate" || -L "$source" ]]; then
    gate_cleanup_reviewer_override_snapshot
    _gate_reviewer_override_error 'file was redirected after its content was checked'
    return 2
  fi
  identity_final="$(stat -Lc '%d:%i:%s:%Y:%Z:%f' -- "$source" 2>/dev/null)" || {
    gate_cleanup_reviewer_override_snapshot
    _gate_reviewer_override_error 'file identity disappeared after content validation'
    return 2
  }
  if [[ "$identity_before" != "$identity_final" ]]; then
    gate_cleanup_reviewer_override_snapshot
    _gate_reviewer_override_error 'file identity changed after content validation'
    return 2
  fi

  OVERRIDE_FILE="$source"
  # Keep the legacy content-normalization contract: Bash command substitution
  # strips trailing newlines.  The source is never reread; both normalized
  # prompt content and the full-byte provenance digest come from this snapshot.
  if ! GATE_OVERRIDES_CONTENT="$(cat -- "$snapshot")"; then
    gate_cleanup_reviewer_override_snapshot
    _gate_reviewer_override_error 'private content snapshot could not be loaded'
    return 2
  fi
  if ! REVIEWER_OVERRIDE_PROVENANCE_JSON="$(jq -nc \
    --arg source "$source" --arg sha256 "$snapshot_sha" \
    '{status:"provided",source:$source,sha256:$sha256}')"; then
    gate_cleanup_reviewer_override_snapshot
    printf 'Error: cannot record accepted reviewer override provenance\n' >&2
    return 2
  fi
  gate_cleanup_reviewer_override_snapshot
}

# Auto-discover .gate-overrides.md when --override-file is not specified.
# Overrides are injected into every reviewer brief so accepted-risk items are
# not re-blocked across rounds without a material change to the reviewed code.
if [[ -z "$OVERRIDE_FILE" && ( -e "$WORK_DIR/.gate-overrides.md" || -L "$WORK_DIR/.gate-overrides.md" ) ]]; then
  OVERRIDE_FILE="$WORK_DIR/.gate-overrides.md"
  say 'pr-gate: discovered override file: .gate-overrides.md\n'
fi
GATE_OVERRIDES_CONTENT=""
REVIEWER_OVERRIDE_PROVENANCE_JSON='{"status":"not_provided","source":null,"sha256":null}'
if [[ -n "$OVERRIDE_FILE" ]]; then
  _override_caller_input="$OVERRIDE_FILE"
  gate_load_reviewer_override "$_override_caller_input" "$OVERRIDE_FILE" || exit $?
  unset _override_caller_input
  say 'pr-gate: override file loaded: %s (%d bytes)\n' "$OVERRIDE_FILE" "${#GATE_OVERRIDES_CONTENT}"
fi
if [[ -n "$POLICY_OVERRIDE_FILE" ]]; then
  _policy_override_candidate="$POLICY_OVERRIDE_FILE"
  [[ "$_policy_override_candidate" == /* ]] \
    || _policy_override_candidate="$WORK_DIR/$_policy_override_candidate"
  if [[ ! -f "$_policy_override_candidate" || ! -r "$_policy_override_candidate" \
      || ! -s "$_policy_override_candidate" || -L "$_policy_override_candidate" ]]; then
    printf 'Error: --policy-override must name a readable, non-empty, regular non-symlink JSON file: %s\n' \
      "$POLICY_OVERRIDE_FILE" >&2
    exit 2
  fi
  _policy_override_parent="$(cd "$(dirname "$_policy_override_candidate")" && pwd -P)" \
    || exit 2
  POLICY_OVERRIDE_FILE="$_policy_override_parent/$(basename "$_policy_override_candidate")"
  unset _policy_override_candidate _policy_override_parent
fi

# ── Detect base branch ────────────────────────────────────────────────────────
if [[ -n "$BASE_OVERRIDE" ]]; then
  BASE="$BASE_OVERRIDE"
else
  if command -v gh >/dev/null 2>&1; then
    if GH_BASE=$(gh pr view --json baseRefName -q .baseRefName 2>/dev/null); then
      if [[ -n "$GH_BASE" ]]; then
        BASE="$GH_BASE"
        say 'pr-gate: base detected from gh pr view: %s\n' "$BASE"
      else
        BASE=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || true)
        : "${BASE:=main}"
      fi
    else
      BASE=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || true)
      : "${BASE:=main}"
    fi
  else
    BASE=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || true)
    : "${BASE:=main}"
  fi
fi
if ! git rev-parse --verify "$BASE" > /dev/null 2>&1; then
  printf 'Error: base ref not found: %s\n' "$BASE" >&2
  exit 1
fi

# ── Detect head ref ────────────────────────────────────────────────────────
# Default HEAD keeps the existing working-tree/branch-diff behavior below.
# A fixed --head ref (branch, tag, commit) diffs base..head_ref directly with
# no working tree involved, so it is incompatible with --allow-dirty (which
# exists specifically to fold uncommitted working-tree state into scope).
HEAD_REF="HEAD"
if [[ -n "$HEAD_OVERRIDE" ]]; then
  if [[ "$ALLOW_DIRTY" == true ]]; then
    printf 'Error: --head and --allow-dirty are incompatible (--head diffs a fixed ref pair; --allow-dirty folds in local working-tree changes)\n' >&2
    exit 2
  fi
  HEAD_REF="$HEAD_OVERRIDE"
  if ! git rev-parse --verify "$HEAD_REF" > /dev/null 2>&1; then
    printf 'Error: head ref not found: %s\n' "$HEAD_REF" >&2
    exit 1
  fi
fi
# Surfaced in reviewer brief context blocks (Base: ${BASE}${HEAD_METADATA_LINE})
# only when a fixed --head ref is in play; a plain HEAD comparison omits the
# line entirely since it would just say "Head: HEAD" (no information).
HEAD_METADATA_LINE=""
if [[ "$HEAD_REF" != "HEAD" ]]; then
  HEAD_METADATA_LINE=$'\n  Head: '"${HEAD_REF}"
fi

# Resolve canonical memory once through the shared runtime boundary and pass
# the resulting provenance/context to every reviewer. Ref/argument validation
# intentionally precedes runtime loading so malformed invocations remain
# diagnosable even for a deliberately minimal copied gate.
_gate_memory_lib="$PR_GATE_LIB_DIR/gate-memory-context.sh"
if [[ ! -r "$_gate_memory_lib" ]]; then
  printf 'Error: shared gate memory runtime not found: %s\n' "$_gate_memory_lib" >&2
  exit 1
fi
# shellcheck source=runtime/lib/gate-memory-context.sh
# shellcheck disable=SC1090
. "$_gate_memory_lib"
gate_memory_context_hydrate "$WORK_DIR" "${SCOPE:-PR gate review}" || exit 1
printf -v MEMORY_CONTEXT_BLOCK \
  '  Canonical memory provenance:\n    provider: pmctl\n    authority: canonical\n    resolution_status: %s\n    resolution_source: %s\n    project_key: %s\n    context_status: %s\n' \
  "$GATE_MEMORY_STATUS" "$GATE_MEMORY_SOURCE" "${GATE_MEMORY_PROJECT_KEY:-none}" "$GATE_MEMORY_CONTEXT_STATUS"
if [[ -n "$GATE_MEMORY_CONTEXT" ]]; then
  printf -v _gate_memory_context_rendered \
    '  Canonical memory context (read-only JSON; do not infer another path):\n    %s\n' \
    "${GATE_MEMORY_CONTEXT//$'\n'/$'\n    '}"
  MEMORY_CONTEXT_BLOCK+="$_gate_memory_context_rendered"
fi
unset _gate_memory_lib _gate_memory_context_rendered

_worktree_is_dirty() {
  # uncommitted tracked changes (staged or unstaged) ...
  if ! git diff --quiet HEAD 2>/dev/null; then return 0; fi
  # ... or any non-gitignored untracked file
  [[ -n "$(git ls-files --others --exclude-standard)" ]]
}

# ── dirty-worktree preflight ─────────────────────────────────────────────────
# When the branch has committed changes, the brief below is built from
# "$BASE"...HEAD and silently omits uncommitted tracked + untracked files
# (a prior gate missed install.sh this exact way). Fail loud so the user
# commits first for a complete, reproducible review -- unless they explicitly
# opt into reviewing the working tree as-is. A dirty-only tree with NO
# committed changes is handled by the working-tree fallback below and is NOT
# failed here (nothing is omitted in that case). Skipped entirely for a fixed
# --head ref: that path never reads the working tree.
if [[ "$HEAD_REF" == "HEAD" ]] && ! git diff "$BASE"...HEAD --quiet 2>/dev/null && _worktree_is_dirty; then
  if [[ "$ALLOW_DIRTY" != true ]]; then
    _dt=$(git diff HEAD --name-only 2>/dev/null | { grep -c . || true; })
    _du=$(git ls-files --others --exclude-standard | { grep -c . || true; })
    {
      printf 'Error: working tree is dirty while the branch has committed changes against %s.\n' "$BASE"
      printf '  The review brief is built from %s...HEAD and would silently omit:\n' "$BASE"
      printf '    %s uncommitted tracked file(s), %s untracked file(s).\n' "$_dt" "$_du"
      printf '  Commit them first for a complete, reproducible review,\n'
      printf '  or pass --allow-dirty to fold the working tree into the review scope.\n'
    } >&2
    exit 3
  fi
  printf 'pr-gate: --allow-dirty set -- folding uncommitted working-tree changes into review scope\n' >&2
fi

# ── Collect diff and policy inputs ────────────────────────────────────────────
# Keep the status-bearing form until policy resolution so renamed and untracked
# inputs remain machine-visible. Use --numstat to detect binary files
# (shown as -\t-\t<file>).
UNTRACKED_PATHS=""
if [[ "$HEAD_REF" != "HEAD" ]]; then
  # Fixed head ref (e.g. tag-to-tag, or a branch reviewed before a PR exists)
  # -- no working tree involved, so no dirty/fallback branches apply. Three-dot
  # (merge-base) diff, matching the default HEAD path below: reviews what
  # changed on HEAD_REF since it diverged from BASE, not a literal two-dot
  # tree diff -- so BASE moving forward independently does not appear here.
  DIFF_NAME_STATUS="$(git diff "$BASE"..."$HEAD_REF" --name-status)"
  DIFF_STAT=$(git diff "$BASE"..."$HEAD_REF" --stat)
  BINARY_HIT=$(git diff "$BASE"..."$HEAD_REF" --numstat | { grep -c $'^-\t-\t' || true; })
  POLICY_DIFF_KIND="fixed-head"
  POLICY_SCOPE_INCLUDE_UNTRACKED=false
  LINES=$(git diff "$BASE"..."$HEAD_REF" --numstat | awk '
    /^-\t-\t/ { next }
    { s += $1 + $2 }
    END { print s+0 }
  ')
elif [[ "$ALLOW_DIRTY" == true ]] && _worktree_is_dirty; then
  # --allow-dirty: fold the working tree into scope. Two-dot diff vs BASE
  # captures committed + uncommitted tracked changes; untracked listed separately.
  UNTRACKED_PATHS="$(git ls-files --others --exclude-standard)"
  DIFF_NAME_STATUS="$(
    git diff "$BASE" --name-status
    printf '%s\n' "$UNTRACKED_PATHS" | awk 'NF { print "?\t" $0 }'
  )"
  DIFF_STAT=$(git diff "$BASE" --stat)
  BINARY_HIT=$(git diff "$BASE" --numstat | { grep -c $'^-\t-\t' || true; })
  POLICY_DIFF_KIND="allow-dirty"
  POLICY_SCOPE_INCLUDE_UNTRACKED=true
  LINES=$(git diff "$BASE" --numstat | awk '
    /^-\t-\t/ { next }
    { s += $1 + $2 }
    END { print s+0 }
  ')
  UNTRACKED_NONDOC=$(git ls-files --others --exclude-standard | \
    { grep -cvE '\.(md|jsonl|txt)$|^\.gitignore$|^audits/|^docs/' || true; })
  BINARY_HIT=$((BINARY_HIT + UNTRACKED_NONDOC))
elif ! git diff "$BASE"...HEAD --quiet 2>/dev/null; then
  # For renames (R* status lines), emit both old and new path so sensitive
  # keywords in the old name (e.g. auth.ts → login.ts) are not lost.
  DIFF_NAME_STATUS="$(git diff "$BASE"...HEAD --name-status)"
  DIFF_STAT=$(git diff "$BASE"...HEAD --stat)
  BINARY_HIT=$(git diff "$BASE"...HEAD --numstat | { grep -c $'^-\t-\t' || true; })
  POLICY_DIFF_KIND="committed"
  POLICY_SCOPE_INCLUDE_UNTRACKED=false
  LINES=$(git diff "$BASE"...HEAD --numstat | awk '
    /^-\t-\t/ { next }
    { s += $1 + $2 }
    END { print s+0 }
  ')
else
  # No branch commits -- fall back to working tree changes
  UNTRACKED_PATHS="$(git ls-files --others --exclude-standard)"
  DIFF_NAME_STATUS="$(
    git diff HEAD --name-status
    printf '%s\n' "$UNTRACKED_PATHS" | awk 'NF { print "?\t" $0 }'
  )"
  DIFF_STAT=$(git diff HEAD --stat)
  BINARY_HIT=$(git diff HEAD --numstat | { grep -c $'^-\t-\t' || true; })
  POLICY_DIFF_KIND="working-tree"
  POLICY_SCOPE_INCLUDE_UNTRACKED=true
  LINES=$(git diff HEAD --numstat | awk '
    /^-\t-\t/ { next }
    { s += $1 + $2 }
    END { print s+0 }
  ')
  # Untracked non-doc files are not included in git diff HEAD --numstat, so
  # BINARY_HIT and LINES would both be 0, silently routing to express.
  # Treat each untracked non-doc file as a binary (unknown size) to prevent
  # under-tiering.
  UNTRACKED_NONDOC=$(git ls-files --others --exclude-standard | \
    { grep -cvE '\.(md|jsonl|txt)$|^\.gitignore$|^audits/|^docs/' || true; })
  BINARY_HIT=$((BINARY_HIT + UNTRACKED_NONDOC))
fi

DIFF_FILES="$(printf '%s\n' "$DIFF_NAME_STATUS" | awk -F '\t' '
  $1 ~ /^[RC]/ { print $2; print $3; next }
  $1 ~ /^[AMDCT?]/ { print $2 }
' | awk 'NF && !seen[$0]++')"
if [[ -z "$DIFF_FILES" ]]; then
  printf 'Error: no changed files detected against %s\n' "$BASE" >&2; exit 1
fi

# Preserve the complete status-derived policy inputs. Scope-manifest expansion
# remains a later concern; this resolver records only deterministic facts it
# owns and a fingerprint over the complete status stream.
RENAMED_PATHS="$(printf '%s\n' "$DIFF_NAME_STATUS" | awk -F '\t' '
  $1 ~ /^R/ { print $2; print $3 }
' | awk 'NF && !seen[$0]++')"
[[ -n "$UNTRACKED_PATHS" ]] || UNTRACKED_PATHS="$(printf '%s\n' "$DIFF_NAME_STATUS" \
  | awk -F '\t' '$1 == "?" { print $2 }')"
GENERATED_PATHS=""
while IFS= read -r _policy_path; do
  [[ -n "$_policy_path" ]] || continue
  case "$_policy_path" in
    generated/*|*/generated/*|dist/*|*/dist/*|vendor/*|*/vendor/*|*.generated.*)
      GENERATED_PATHS="${GENERATED_PATHS:+$GENERATED_PATHS$'\n'}$_policy_path"
      continue
      ;;
  esac
  if [[ -f "$WORK_DIR/$_policy_path" ]] \
      && head -n 8 "$WORK_DIR/$_policy_path" 2>/dev/null \
        | grep -qiE 'do not edit.*generated|generated.*do not edit'; then
    GENERATED_PATHS="${GENERATED_PATHS:+$GENERATED_PATHS$'\n'}$_policy_path"
  fi
done <<< "$DIFF_FILES"

NON_DOCS="$(printf '%s\n' "$DIFF_FILES" \
  | grep -vE '\.(md|jsonl|txt)$|^\.gitignore$|^audits/|^docs/' || true)"
LAYER_ROOTS="$(printf '%s\n' "$NON_DOCS" | awk -F/ '
  $1 ~ /^(core|runtime|cli|adapters|hosts|commands|skills)$/ { print $1; next }
  $1 ~ /^(install|uninstall)\.sh$/ { print $1 }
' | LC_ALL=C sort -u)"
LAYER_ROOT_COUNT="$(printf '%s\n' "$LAYER_ROOTS" | grep -c '[^[:space:]]' || true)"

ARCHITECTURE_IMPACT="unknown"
if [[ -n "$INPUT_BRIEF_FILE" ]]; then
  _input_brief_candidate="$INPUT_BRIEF_FILE"
  [[ "$_input_brief_candidate" == /* ]] \
    || _input_brief_candidate="$WORK_DIR/$_input_brief_candidate"
  if [[ ! -f "$_input_brief_candidate" || ! -r "$_input_brief_candidate" ]]; then
    printf 'Error: --brief must name a readable file: %s\n' "$INPUT_BRIEF_FILE" >&2
    exit 2
  fi
  _input_brief_parent="$(cd "$(dirname "$_input_brief_candidate")" && pwd -P)" || exit 2
  INPUT_BRIEF_FILE="$_input_brief_parent/$(basename "$_input_brief_candidate")"
  ARCHITECTURE_IMPACT="$(gate_subject_architecture_impact "$INPUT_BRIEF_FILE")" || exit 2
  : "${ARCHITECTURE_IMPACT:=unknown}"
  unset _input_brief_candidate _input_brief_parent
fi

DIFF_FILES_JSON="$(printf '%s\n' "$DIFF_FILES" | _gate_policy_lines_json)"
NON_DOCS_JSON="$(printf '%s\n' "$NON_DOCS" | _gate_policy_lines_json)"
RENAMED_PATHS_JSON="$(printf '%s\n' "$RENAMED_PATHS" | _gate_policy_lines_json)"
UNTRACKED_PATHS_JSON="$(printf '%s\n' "$UNTRACKED_PATHS" | _gate_policy_lines_json)"
GENERATED_PATHS_JSON="$(printf '%s\n' "$GENERATED_PATHS" | _gate_policy_lines_json)"
LAYER_ROOTS_JSON="$(printf '%s\n' "$LAYER_ROOTS" | _gate_policy_lines_json)"
_policy_docs_only=false
[[ -z "$NON_DOCS" ]] && _policy_docs_only=true
_policy_cross_boundary=false
[[ "$LAYER_ROOT_COUNT" -gt 1 ]] && _policy_cross_boundary=true
CLASSIFICATIONS_JSON="$(jq -nc \
  --argjson docs_only "$_policy_docs_only" \
  --argjson changed_paths "$DIFF_FILES_JSON" --argjson non_docs "$NON_DOCS_JSON" \
  --argjson renamed "$RENAMED_PATHS_JSON" --argjson untracked "$UNTRACKED_PATHS_JSON" \
  --argjson generated "$GENERATED_PATHS_JSON" --argjson layer_roots "$LAYER_ROOTS_JSON" \
  --argjson cross_boundary "$_policy_cross_boundary" \
  --argjson lines "$LINES" --argjson binary_or_unknown "${BINARY_HIT:-0}" '[
    if $docs_only then {id:"docs-only",matches:$changed_paths}
    else {id:"bounded-runtime",matches:$non_docs} end,
    if $lines > 500 then {id:"large-change",matches:[("changed-lines:" + ($lines|tostring))]}
    elif $lines >= 100 then {id:"medium-change",matches:[("changed-lines:" + ($lines|tostring))]}
    else empty end,
    if $binary_or_unknown > 0 then {
      id:"binary-change",matches:[("binary-or-unknown:" + ($binary_or_unknown|tostring))]
    } else empty end,
    if ($renamed|length) > 0 then {id:"renamed",matches:$renamed} else empty end,
    if ($untracked|length) > 0 then {id:"untracked",matches:$untracked} else empty end,
    if ($generated|length) > 0 then {id:"generated",matches:$generated} else empty end,
    if $cross_boundary then {id:"cross-boundary",matches:$layer_roots} else empty end
  ]')"
POLICY_SCOPE_CONTENT_DIGEST="$(
  _gate_policy_scope_content_digest \
    "$POLICY_DIFF_KIND" "$BASE" "$HEAD_REF" "$POLICY_SCOPE_INCLUDE_UNTRACKED"
)" || exit 2
POLICY_SCOPE_FINGERPRINT="$(
  {
    printf 'policy=%s\npass=%s\narchitecture_impact=%s\nlines=%s\nbinary_or_unknown=%s\ncontent=%s\n' \
      "$POLICY_CONSUMER" "$PASS_KIND_RESOLVED" "$ARCHITECTURE_IMPACT" \
      "$LINES" "${BINARY_HIT:-0}" "$POLICY_SCOPE_CONTENT_DIGEST"
    printf '%s\n' "$DIFF_NAME_STATUS"
  } | gate_digest_stream
)" || exit 2

REQUESTED_REVIEWERS_JSON=null
if [[ -n "$REVIEWERS_OVERRIDE" ]]; then
  _requested_reviewer_words="$(_gate_policy_normalize_reviewer_list \
    "$REVIEWERS_OVERRIDE" "$ALL_REVIEWERS" "$REVIEWERS_OPTION_SOURCE")" || exit 2
  REQUESTED_REVIEWERS_JSON="$(_gate_policy_words_json "$_requested_reviewer_words")"
  COVERAGE_REQUESTED_DISPLAY="$(printf '%s' "$_requested_reviewer_words" | tr ' ' ',')"
  unset _requested_reviewer_words
else
  COVERAGE_REQUESTED_DISPLAY="default"
fi

GATE_POLICY_INPUT="$(jq -nc \
  --arg policy "$POLICY_CONSUMER" --arg policy_source "$GATE_ASSURANCE_POLICY_SOURCE" \
  --arg scope_fingerprint "$POLICY_SCOPE_FINGERPRINT" \
  --arg tier "$TIER_REQUESTED" --arg mode "$MODE_REQUESTED" \
  --arg pass_kind "$PASS_KIND_RESOLVED" \
  --argjson reviewers "$REQUESTED_REVIEWERS_JSON" \
  --argjson vocabulary "$(_gate_policy_words_json "$ALL_REVIEWERS")" \
  --arg architecture_impact "$ARCHITECTURE_IMPACT" \
  --argjson line_changes "$LINES" \
  --argjson binary_or_unknown "${BINARY_HIT:-0}" \
  --argjson layer_roots "$LAYER_ROOTS_JSON" \
  --argjson classifications "$CLASSIFICATIONS_JSON" \
  --argjson changed_paths "$DIFF_FILES_JSON" \
  --argjson reviewer_override "$REVIEWER_OVERRIDE_PROVENANCE_JSON" '{
    policy:$policy,
    policy_source:$policy_source,
    scope_fingerprint:$scope_fingerprint,
    requested:{tier:$tier,mode:$mode,pass_kind:$pass_kind,reviewers:$reviewers},
    reviewer_vocabulary:$vocabulary,
    changed_paths:$changed_paths,
    classifications:$classifications,
    classification:{
      architecture_impact:$architecture_impact,
      line_changes:$line_changes,
      binary_or_unknown_count:$binary_or_unknown,
      layer_roots:$layer_roots
    },
    reviewer_override:$reviewer_override
  }')"
GATE_POLICY_RESOLUTION="$(_gate_policy_resolve \
  "$GATE_POLICY_INPUT" "$POLICY_OVERRIDE_FILE")" || exit 2
if [[ "$(jq -r '.enforcement.status' <<<"$GATE_POLICY_RESOLUTION")" != pass ]]; then
  {
    printf 'Error: requested gate assurance is below the canonical %s policy floor.\n' \
      "$POLICY_CONSUMER"
    printf '  policy scope fingerprint: %s\n' "$POLICY_SCOPE_FINGERPRINT"
    jq -r '.enforcement.violations[] |
      "  - " + .coordinate + ": requested=" + (.requested|tostring) +
      " required=" + (.required|tostring)' <<<"$GATE_POLICY_RESOLUTION"
    printf '  A downgrade requires an explicit --policy-override gate_policy_override_v1 JSON\n'
    printf '  bound to this exact scope and carrying recorded user approval.\n'
    if [[ -n "$POLICY_OVERRIDE_FILE" ]]; then
      printf '  supplied override status: %s\n' \
        "$(jq -r '.override.status' <<<"$GATE_POLICY_RESOLUTION")"
    fi
  } >&2
  exit 3
fi

TIER_RESOLVED="$(jq -r '.resolved.tier' <<<"$GATE_POLICY_RESOLUTION")"
[[ -n "$TIER_OVERRIDE" ]] && TIER_SELECTION_BASIS="explicit"
TIER="$TIER_RESOLVED"
TIER_EVIDENCE_FLOOR="$(_gate_assurance_policy_lookup tiers tier "$TIER" evidence_floor)" || {
  printf 'Error: gate tier policy has no evidence floor for: %s\n' "$TIER" >&2
  exit 2
}
MODE_RESOLVED="$(jq -r '.resolved.mode' <<<"$GATE_POLICY_RESOLUTION")"
MODE_TOPOLOGY="$(_gate_assurance_policy_lookup modes mode "$MODE_RESOLVED" topology)" \
  || exit 2
MODE_SYNTHESIS="$(_gate_assurance_policy_lookup modes mode "$MODE_RESOLVED" synthesis)" \
  || exit 2
case "$MODE_TOPOLOGY:$MODE_SYNTHESIS" in
  combined-session:inline) SEQUENTIAL=true ;;
  per-reviewer-sessions:separate-session) SEQUENTIAL=false ;;
  *)
    printf 'Error: unsupported gate mode topology for %s: %s + %s\n' \
      "$MODE_RESOLVED" "$MODE_TOPOLOGY" "$MODE_SYNTHESIS" >&2
    exit 2
    ;;
esac
REVIEWERS="$(jq -r '.resolved.reviewers | join(" ")' <<<"$GATE_POLICY_RESOLUTION")"
[[ -n "$REVIEWERS" ]] || {
  printf 'Error: gate policy resolved empty reviewer coverage\n' >&2
  exit 2
}

REVIEWER_DISPLAY=$(printf '%s' "$REVIEWERS" | tr ' ' ',')
NUM_REVIEWERS=$(printf '%s\n' "$REVIEWERS" | awk '{print NF}')

# Compute skipped dimensions
SKIPPED=""
SKIPPED_WORDS=""
for r in $ALL_REVIEWERS; do
  if ! printf '%s' "$REVIEWERS" | grep -qw "$r"; then
    SKIPPED="${SKIPPED:+$SKIPPED, }$r"
    SKIPPED_WORDS="${SKIPPED_WORDS:+$SKIPPED_WORDS }$r"
  fi
done
SKIPPED_DISPLAY="${SKIPPED:-none}"
SYNTHESIS_SELECTED_JSON="$(
  jq -cn --arg reviewers "$REVIEWERS" \
    '$reviewers | split(" ") | map(select(length > 0))'
)" || exit 2
SYNTHESIS_SKIPPED_JSON="$(
  jq -cn --arg reviewers "$SKIPPED_WORDS" \
    '$reviewers | split(" ") | map(select(length > 0))'
)" || exit 2
COVERAGE_SELECTED_DISPLAY="$REVIEWER_DISPLAY"
COVERAGE_SKIPPED_DISPLAY="$SKIPPED_DISPLAY"

# ── Resolve reviewer definitions ─────────────────────────────────────────────
# Definitions outside the reviewed workspace are trusted installation assets.
# A definition directory inside the reviewed workspace is attacker-controlled,
# so read it from the trusted base revision rather than from the working tree.
AGENT_DIR="$REVIEWER_DIR_OVERRIDE"
if [[ -z "$AGENT_DIR" ]]; then
  # Reviewer definitions share the already-classified trust root with Adapter
  # manifests. Missing assets fail below instead of probing another topology.
  AGENT_DIR="$PR_GATE_EXECUTOR_ROOT/agents"
fi
if [[ ! -d "$AGENT_DIR" ]]; then
  printf 'Error: reviewer definition directory not found; use --reviewer-dir: %s\n' "${AGENT_DIR:-unset}" >&2; exit 1
fi
AGENT_DIR="$(cd "$AGENT_DIR" && pwd -P)"
REVIEWER_SOURCE_MODE="trusted-directory"
REVIEWER_BASE_REL=""
case "$AGENT_DIR" in
  "$WORK_DIR"/*)
    REVIEWER_SOURCE_MODE="base-pinned"
    REVIEWER_BASE_REL="${AGENT_DIR#"$WORK_DIR"/}"
    ;;
esac
say 'pr-gate: reviewer definition source: %s (%s)\n' "$REVIEWER_SOURCE_MODE" "$AGENT_DIR"

# Validate all reviewer agent files exist before doing any work
for r in $REVIEWERS; do
  if [[ "$REVIEWER_SOURCE_MODE" == "base-pinned" ]]; then
    if ! git cat-file -e "$BASE:$REVIEWER_BASE_REL/${r}.md" 2>/dev/null; then
      printf 'Error: reviewer agent file not found in trusted base %s: %s/%s.md\n' \
        "$BASE" "$REVIEWER_BASE_REL" "$r" >&2
      exit 1
    fi
  else
    AGENT_PATH="$AGENT_DIR/${r}.md"
    if [[ ! -f "$AGENT_PATH" ]]; then
      printf 'Error: reviewer agent file not found: %s\n' "$AGENT_PATH" >&2
      exit 1
    fi
  fi
done

# ── Prepare output paths ─────────────────────────────────────────────────────
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
_ARTIFACT_ROOT="${GATE_RUN_DIR_OVERRIDE:-$WORK_DIR}"
BRIEF_DIR="$_ARTIFACT_ROOT/.gate-briefs"
mkdir -p "$BRIEF_DIR"
GATE_ASSURANCE_CAPTURE_DIR="$(mktemp -d "/tmp/pm-gate-assurance-${TIMESTAMP}.XXXXXX")" || {
  printf 'Error: unable to create private gate assurance capture directory\n' >&2
  exit 1
}
command -p chmod 700 "$GATE_ASSURANCE_CAPTURE_DIR" || exit 1
# Route executor traces (adapter JSONL/last/stderr) to the run dir when provided.
# PM_DISPATCH_TRACE_DIR is read by the canonical router to forward --trace-dir
# to the Adapter, so the Adapter's own trace files follow the run dir.
if [[ -n "$GATE_RUN_DIR_OVERRIDE" ]]; then
  export PM_DISPATCH_TRACE_DIR="$GATE_RUN_DIR_OVERRIDE/.agent-trace"
fi

# OUTPUT_FILE must be in WORK_DIR so the executor (codex/claude, workspace-write sandbox)
# can write it. After final verification the gate moves it to _ARTIFACT_ROOT if a run dir
# was supplied. --output explicit override is always used verbatim, no move.
OUTPUT_FILE="${OUTPUT_OVERRIDE:-$WORK_DIR/.gate-results/gate-${TIMESTAMP}.md}"
# Normalize to an absolute path. The reviewer write-guard (guard-reviewer-write.sh)
# requires an absolute file_path, and the pr-gate-handover_v1 schema mandates an absolute
# output_file. A relative --output (or a relative --cd default) would otherwise be embedded
# verbatim into the reviewer brief's `pmctl guard check` constraint, making the guard exit
# nonzero and the reviewer abort the write -- the 0-byte-result failure mode, for any executor.
# Ordering dependency: this relies on the earlier `cd "$WORK_DIR"` having already run, so $PWD
# here IS the absolute working dir and a relative OUTPUT_FILE resolves to an absolute path under it.
[[ "$OUTPUT_FILE" = /* ]] || OUTPUT_FILE="$PWD/$OUTPUT_FILE"
mkdir -p "$(dirname "$OUTPUT_FILE")"
_output_parent="$(cd "$(dirname "$OUTPUT_FILE")" && pwd -P)"
OUTPUT_FILE="$_output_parent/$(basename "$OUTPUT_FILE")"
unset _output_parent
ASSURANCE_FILE="${OUTPUT_FILE}.assurance.json"
# shellcheck disable=SC2034 # consumed by the canonical assurance module
ASSURANCE_POINTER="$(basename "$ASSURANCE_FILE")"
ASSURANCE_ATTESTATION_FILE=""
ASSURANCE_ATTESTATION_POINTER=""
GATE_ASSURANCE_RUNS_FILE=""
if [[ -n "$GATE_RUN_DIR_OVERRIDE" && -n "$PMCTL_DISPATCH_LIB_DIR" ]]; then
  ASSURANCE_ATTESTATION_POINTER="gate-assurance-${TIMESTAMP}.attestation.json"
  # shellcheck disable=SC2034 # consumed by the canonical assurance module
  ASSURANCE_ATTESTATION_FILE="$GATE_RUN_DIR_OVERRIDE/$ASSURANCE_ATTESTATION_POINTER"
  # shellcheck disable=SC2034 # consumed by the canonical assurance module
  GATE_ASSURANCE_RUNS_FILE="$(
    # shellcheck source=runtime/lib/state-paths.sh
    . "$PMCTL_DISPATCH_LIB_DIR/state-paths.sh"
    cd "$WORK_DIR" || exit 1
    _SW_REPO_ROOT="$WORK_DIR" _sw_project_dir
  )runs.jsonl"
fi


if [[ -n "$INITIAL_RESULT_RESOLVED" \
    && ( "$OUTPUT_FILE" == "$INITIAL_RESULT_RESOLVED" \
      || ( -e "$OUTPUT_FILE" && "$OUTPUT_FILE" -ef "$INITIAL_RESULT_RESOLVED" ) ) ]]; then
  printf 'Error: --output must not overwrite the referenced --initial-result: %s\n' \
    "$INITIAL_RESULT_RESOLVED" >&2
  exit 2
fi
if [[ -n "$INITIAL_RESULT_RESOLVED" \
    && ( "$ASSURANCE_FILE" == "$INITIAL_RESULT_RESOLVED" \
      || ( -e "$ASSURANCE_FILE" && "$ASSURANCE_FILE" -ef "$INITIAL_RESULT_RESOLVED" ) ) ]]; then
  printf 'Error: the assurance sidecar must not overwrite the referenced --initial-result: %s\n' \
    "$INITIAL_RESULT_RESOLVED" >&2
  exit 2
fi
_gate_assurance_destination_check "$ASSURANCE_FILE" || exit 2
GATE_OUTPUT_EXISTED=false
[[ -e "$OUTPUT_FILE" ]] && GATE_OUTPUT_EXISTED=true
touch "$OUTPUT_FILE"
REVIEWER_PROTOCOL_COMPLETE=false
SYNTHESIS_PROTOCOL_COMPLETE=false

# Track all brief files for EXIT cleanup
BRIEF_FILES=()
REVIEWER_DEFINITION_DIR=""
cleanup_briefs() {
  # Every executor now dispatches a subprocess (codex `codex exec`, claude headless
  # `claude --print`), so generated briefs are always transient and cleaned on exit.
  for bf in "${BRIEF_FILES[@]:-}"; do
    rm -f "$bf"
  done
  if [[ -n "${REVIEWER_DEFINITION_DIR:-}" ]]; then
    rm -rf -- "$REVIEWER_DEFINITION_DIR"
    rmdir "$WORK_DIR/.gate-briefs" 2>/dev/null || true
  fi
  rm -rf -- "${GATE_ASSURANCE_CAPTURE_DIR:-}"
}

# Relocate gate result artifacts out of the repo when a run dir was supplied.
# OUTPUT_FILE (and parallel reviewer outputs) must be written under WORK_DIR for the
# executor's workspace-write sandbox, so they start repo-local. This helper moves them
# to $GATE_RUN_DIR_OVERRIDE/.gate-results and drops the now-empty in-repo dir.
# Idempotent and safe to call repeatedly:
#   - no-op in legacy mode (no --run-dir) or with an explicit --output override, so the
#     in-repo default path and verbatim --output behavior are preserved (backward compat);
#   - no-op once WORK_DIR/.gate-results has been drained.
# Called BOTH on the success path (before the result: print, so the printed path and the
# NO-GO grep read the relocated copy) AND from the EXIT trap (so every failure path that
# already created the in-repo result relocates it out instead of leaking repo artifacts).
relocate_gate_artifacts() {
  [[ -n "$GATE_RUN_DIR_OVERRIDE" && -z "$OUTPUT_OVERRIDE" ]] || return 0
  [[ -d "$WORK_DIR/.gate-results" ]] || return 0
  local _result_dest_dir="$GATE_RUN_DIR_OVERRIDE/.gate-results" _rf
  mkdir -p "$_result_dest_dir"
  # Move only this run's artifacts (all carry $TIMESTAMP in the filename) so a concurrent
  # gate run sharing WORK_DIR/.gate-results keeps its own in-flight files.
  for _rf in "$WORK_DIR/.gate-results/"*"${TIMESTAMP}"*; do
    [[ -e "$_rf" ]] || continue
    mv "$_rf" "$_result_dest_dir/"
  done
  # Repoint OUTPUT_FILE to the relocated primary result so later reads (result: print,
  # NO-GO grep) follow it out of the repo.
  if [[ "$OUTPUT_FILE" == "$WORK_DIR/.gate-results/"* ]]; then
    OUTPUT_FILE="$_result_dest_dir/$(basename "$OUTPUT_FILE")"
  fi
  # Drop the in-repo dir only if now empty (tolerate a concurrent run's files).
  rmdir "$WORK_DIR/.gate-results" 2>/dev/null || true
}

gate_exit_cleanup() {
  local _gate_exit_status=$?
  gate_cleanup_reviewer_override_snapshot
  # CC-522 Slice B: a killed reviewer cannot be trusted to write a final
  # result. Preserve the host-owned QA checkpoint/log pointer as an explicit
  # non-authorizing partial artifact before any run-dir relocation.
  qa_execution_finalize "$_gate_exit_status" || true
  # Relocate first (preserves the result artifact out-of-repo for post-mortem on failure
  # paths), then drop transient briefs. Both are idempotent / no-ops on the success path
  # where relocation already ran inline.
  if [[ "$GATE_CANCELLED" == true ]]; then
    # Cancellation is an operation terminal, not a reviewer verdict.  Do not
    # publish an empty/partial result that a later consumer could mistake for a
    # late gate outcome; operation state remains the cancellation evidence.
    rm -f -- "$WORK_DIR/.gate-results/"*"${TIMESTAMP}"* 2>/dev/null || true
    if [[ "$GATE_OUTPUT_EXISTED" != true ]]; then
      rm -f -- "$OUTPUT_FILE"
    fi
    rmdir "$WORK_DIR/.gate-results" 2>/dev/null || true
  else
    # An interrupted synthesis used to relocate the placeholder created before
    # dispatch as a 0-byte "result". Preserve an explicit non-verdict record
    # instead, so artifact inspection distinguishes publication failure from a
    # missing or successful gate result. SIGKILL remains inherently
    # uncatchable; its absence is still surfaced by the supervisor/wait path.
    if [[ "$_gate_exit_status" -ne 0 && "${GATE_OUTPUT_EXISTED:-false}" != true \
        && -n "${OUTPUT_FILE:-}" && -e "$OUTPUT_FILE" && ! -s "$OUTPUT_FILE" ]]; then
      {
        printf '# PR-Gate Result Publication Failure\n\n'
        printf 'The gate stopped before a verified synthesis result was published.\n\n'
        printf 'Final: INCOMPLETE\n'
      } > "$OUTPUT_FILE" 2>/dev/null || true
    fi
    relocate_gate_artifacts
  fi
  # Preserve the post-mortem artifact path even when protocol validation fails
  # before the normal `result:` handoff. Detached gate wait can then surface a
  # failed, inspectable artifact instead of leaving callers with only an exit 2.
  if [[ "$_gate_exit_status" -ne 0 && -n "${OUTPUT_FILE:-}" && -e "${OUTPUT_FILE:-}" ]]; then
    printf 'failure-result: %s\n' "$OUTPUT_FILE"
  fi
  cleanup_briefs
  return "$_gate_exit_status"
}
trap gate_exit_cleanup EXIT

gate_result_staging_normalize() {
  local result_file="$1" route_label="${2:-gate}"
  local version version_count pointer_count result_tmp

  [[ -s "$result_file" ]] || {
    printf 'Error: %s did not produce a staging gate result: %s\n' \
      "$route_label" "$result_file" >&2
    return 1
  }
  version_count="$(awk '
    /^\+?---$/ {
      if (fence == 0) { fence=1; next }
      if (fence == 1) { fence=2; next }
    }
    fence == 1 && $1 == "gate_result_version:" { count++ }
    END { print count+0 }
  ' "$result_file")"
  pointer_count="$(awk '
    /^\+?---$/ {
      if (fence == 0) { fence=1; next }
      if (fence == 1) { fence=2; next }
    }
    fence == 1 && $1 == "gate_assurance:" { count++ }
    END { print count+0 }
  ' "$result_file")"
  if [[ "$version_count" -ne 1 ]]; then
    printf 'Error: %s staging frontmatter must contain exactly one gate_result_version (found %d): %s\n' \
      "$route_label" "$version_count" "$result_file" >&2
    return 1
  fi
  if [[ "$pointer_count" -gt 1 ]]; then
    printf 'Error: %s staging frontmatter contains multiple model-authored gate_assurance pointers: %s\n' \
      "$route_label" "$result_file" >&2
    return 1
  fi
  version="$(awk '
    /^\+?---$/ { if (fence == 0) { fence=1; next } if (fence == 1) exit }
    fence == 1 && $1 == "gate_result_version:" { print $2; exit }
  ' "$result_file")"
  case "$version" in
    pr_gate_result_v1 | pr_gate_result_v2 | pr_gate_result_v3 | pr_gate_result_v4 | pr_gate_result_v5) ;;
    *)
      printf 'Error: unsupported model-authored staging gate_result_version (%s): %s\n' \
        "${version:-missing}" "$result_file" >&2
      return 1
      ;;
  esac

  result_tmp="$(mktemp "${result_file}.staging-tmp.XXXXXX")" || return 1
  if ! awk '
    /^\+?---$/ {
      if (fence < 2) {
        fence++
        print "---"
      } else {
        print
      }
      next
    }
    fence == 1 && $1 == "gate_result_version:" {
      print "gate_result_version: pr_gate_result_v1"
      next
    }
    fence == 1 && $1 == "gate_assurance:" { next }
    { print }
  ' "$result_file" > "$result_tmp"; then
    rm -f -- "$result_tmp"
    return 1
  fi
  mv -- "$result_tmp" "$result_file"
}


SYNTHESIS_BRIEF="$BRIEF_DIR/pr-gate-${TIMESTAMP}-synthesis.md"
BRIEF_FILES+=("$SYNTHESIS_BRIEF")

# Build a compact index of verified reference files (agents/, commands/, docs/, skills/)
# for injection into gate brief preambles. Reviewers may cite docs/sections
# that don't exist; the index provides ground truth so they can verify before citing.
_build_repo_ref_index() {
  local work_dir="$1" out=""
  for d in agents commands docs skills; do
    [[ -d "$work_dir/$d" ]] || continue
    while IFS= read -r f; do
      out="${out}    ${f#"$work_dir/"}"$'\n'
    done < <(find "$work_dir/$d" -maxdepth 2 -name "*.md" 2>/dev/null | sort)
  done
  printf '%s' "$out"
}


# The scope manifest producer below owns paired-test discovery. Keep the
# pre-manifest list to the actual diff, then merge its declared pairs and
# bounded expansions once the immutable subject is available.
ALL_REVIEW_FILES="$DIFF_FILES"

DIFF_STAT_INDENTED=$(printf '%s\n' "$DIFF_STAT" | sed 's/^/    /')
REPO_REF_INDEX="$(_build_repo_ref_index "$WORK_DIR")"

# Render the accepted-risk override context block injected into EVERY reviewer
# and synthesis brief. Single source of truth: all three brief templates
# (sequential, parallel reviewer, parallel synthesis) reference the one
# ${GATE_OVERRIDES_CONTEXT_BLOCK} this produces, so an override-rendering change
# lands in exactly one place. Emits the empty string when there are no overrides.
# (render_test_evidence_block() below follows this same single-source-of-truth
# shape for the pre-flight test evidence block -- see CC-470 Part 3.)
render_gate_overrides_block() {
  local content="$1" indented
  [[ -z "$content" ]] && return 0
  indented=$(printf '%s\n' "$content" | sed 's/^/  /')
  printf '  Accepted-risk overrides (do NOT re-block these unless the diff materially\n  changes the accepted risk -- re-raising an already-accepted override when the\n  code has not changed is a false-positive that must be suppressed):\n%s\n' "$indented"
}

# Pre-format the override block for heredoc injection (empty when no overrides).
GATE_OVERRIDES_CONTEXT_BLOCK="$(render_gate_overrides_block "$GATE_OVERRIDES_CONTENT")"

INITIAL_RESULT_DISPLAY="${INITIAL_RESULT_RESOLVED:-none}"
TARGETED_REMEDIATION_CONTEXT_BLOCK=""
if [[ "$PASS_KIND_RESOLVED" == targeted && -n "$INITIAL_RESULT_RESOLVED" ]]; then
  _targeted_initial_synthesis="$(mktemp "${TMPDIR:-/tmp}/pr-gate-targeted-initial.XXXXXX.json")"
  _targeted_initial_ids='[]'
  awk '
    /^```synthesis_result_v1[[:space:]]*$/ { inside=1; next }
    inside && /^```[[:space:]]*$/ { exit }
    inside { print }
  ' "$INITIAL_RESULT_RESOLVED" > "$_targeted_initial_synthesis"
  if [[ -s "$_targeted_initial_synthesis" ]]; then
    _targeted_initial_ids="$(jq -c '[.findings_union[]? |
      select(.origin == "diff_caused" or .origin == "uncertain") | .id] | sort' \
      "$_targeted_initial_synthesis" 2>/dev/null || printf '[]')"
  fi
  TARGETED_REMEDIATION_CONTEXT_BLOCK="Targeted remediation context (machine-checked):
  - This is a targeted delta pass. The initial diff-caused/uncertain finding IDs that must be independently confirmed are:
    $_targeted_initial_ids
  - Put one remediation_confirmations entry with status=confirmed and current evidence_refs for each of those IDs. A clean targeted GO normally has findings_union=[]; do not retain a fixed blocker there.
"
  rm -f -- "$_targeted_initial_synthesis"
  unset _targeted_initial_synthesis _targeted_initial_ids
fi
POLICY_REQUIRED_REVIEWERS_DISPLAY="$(jq -r \
  '.resolution.required_reviewers | if length == 0 then "none" else join(",") end' \
  <<<"$GATE_POLICY_RESOLUTION")"
POLICY_MODE_SELECTION_SOURCE="$(jq -r '.resolution.mode_selection_source' \
  <<<"$GATE_POLICY_RESOLUTION")"
POLICY_MODE_RECOMMENDATION_OVERRIDDEN="$(jq -r \
  '.resolution.mode_recommendation_overridden' <<<"$GATE_POLICY_RESOLUTION")"
POLICY_ESCALATION_SIGNALS_DISPLAY="$(jq -c '[
  .matched_signals[]
  | select(.source != "consumer-policy")
  | select((.required_reviewers | length) > 0 or .recommended_mode == "parallel")
  | {
      id,
      required_reviewers,
      recommended_mode
    }
]' <<<"$GATE_POLICY_RESOLUTION")"
printf -v GATE_ASSURANCE_CONTEXT_BLOCK \
  '  Assurance coordinates (resolved by the gate shell; do not reinterpret):\n    tier.requested: %s\n    tier.resolved: %s\n    tier.evidence_floor: %s\n    tier.selection_basis: %s\n    mode.requested: %s\n    mode.resolved: %s\n    mode.topology: %s\n    mode.synthesis: %s\n    mode.selection_source: %s\n    mode.recommendation_overridden: %s\n    pass.requested: %s\n    pass.resolved: %s\n    pass.scope: %s\n    pass.initial_result: %s\n    coverage.requested: %s\n    coverage.selected: %s\n    coverage.skipped: %s\n    coverage.selection_basis: %s\n    policy.consumer: %s\n    policy.minimum_tier: %s\n    policy.required_reviewers: %s\n    policy.recommended_mode: %s\n    policy.escalation_signals: %s\n    policy.scope_fingerprint: %s\n    policy.source: %s\n' \
  "$TIER_REQUESTED" "$TIER_RESOLVED" "$TIER_EVIDENCE_FLOOR" "$TIER_SELECTION_BASIS" \
  "$MODE_REQUESTED" "$MODE_RESOLVED" "$MODE_TOPOLOGY" "$MODE_SYNTHESIS" \
  "$POLICY_MODE_SELECTION_SOURCE" "$POLICY_MODE_RECOMMENDATION_OVERRIDDEN" \
  "$PASS_KIND_REQUESTED" "$PASS_KIND_RESOLVED" "$PASS_SCOPE" "$INITIAL_RESULT_DISPLAY" \
  "$COVERAGE_REQUESTED_DISPLAY" \
  "$COVERAGE_SELECTED_DISPLAY" "$COVERAGE_SKIPPED_DISPLAY" "$COVERAGE_SELECTION_BASIS" \
  "$POLICY_CONSUMER" "$(jq -r '.resolution.minimum_tier' <<<"$GATE_POLICY_RESOLUTION")" \
  "$POLICY_REQUIRED_REVIEWERS_DISPLAY" \
  "$(jq -r '.resolution.recommended_mode' <<<"$GATE_POLICY_RESOLUTION")" \
  "$POLICY_ESCALATION_SIGNALS_DISPLAY" \
  "$POLICY_SCOPE_FINGERPRINT" \
  "$GATE_ASSURANCE_POLICY_SOURCE"

say 'pr-gate: tier %s -> %s; mode %s -> %s; pass %s -> %s\n' \
  "$TIER_REQUESTED" "$TIER_RESOLVED" "$MODE_REQUESTED" "$MODE_RESOLVED" \
  "$PASS_KIND_REQUESTED" "$PASS_KIND_RESOLVED"
say 'pr-gate: coverage requested=%s selected=%s skipped=%s; policy=%s/%s\n' \
  "$COVERAGE_REQUESTED_DISPLAY" "$COVERAGE_SELECTED_DISPLAY" \
  "$COVERAGE_SKIPPED_DISPLAY" "$POLICY_CONSUMER" "$GATE_ASSURANCE_POLICY_SOURCE"
say 'pr-gate: policy minimum-tier=%s required-reviewers=%s recommended-mode=%s mode-source=%s recommendation-overridden=%s scope=%s\n' \
  "$(jq -r '.resolution.minimum_tier' <<<"$GATE_POLICY_RESOLUTION")" \
  "$POLICY_REQUIRED_REVIEWERS_DISPLAY" \
  "$(jq -r '.resolution.recommended_mode' <<<"$GATE_POLICY_RESOLUTION")" \
  "$POLICY_MODE_SELECTION_SOURCE" "$POLICY_MODE_RECOMMENDATION_OVERRIDDEN" \
  "$POLICY_SCOPE_FINGERPRINT"
say 'result will be written to: %s\n\n' "$OUTPUT_FILE"

# ── Pre-gate hook ──────────────────────────────────────────────────────────
_PRE_GATE_HOOK="$WORK_DIR/.pm-dispatch/pre-gate.sh"
if [[ "$ALLOW_HOOKS" != "true" ]]; then
  if [[ -f "$_PRE_GATE_HOOK" ]]; then
    printf 'Warning: .pm-dispatch/pre-gate.sh present but skipped -- pass --allow-hooks to execute repo-local hook scripts\n' >&2
  fi
elif [[ -f "$_PRE_GATE_HOOK" && ! -x "$_PRE_GATE_HOOK" ]]; then
  printf 'Warning: .pm-dispatch/pre-gate.sh exists but is not executable -- skipping\n' >&2
elif [[ -x "$_PRE_GATE_HOOK" ]]; then
  say 'Running pre-gate hook: .pm-dispatch/pre-gate.sh\n'
  if ! (cd "$WORK_DIR" && bash "$_PRE_GATE_HOOK"); then
    printf 'Error: pre-gate hook failed -- gate aborted\n' >&2
    exit 1
  fi
  say 'pre-gate hook completed.\n\n'
fi

# ── Pre-flight test suite (mechanical, decoupled from reviewer --timeout budget) ──
# Runs BEFORE any dispatch, in plain bash, with its own independent timeout
# (--test-timeout, default 3600s) -- however long the target repo's test suite
# takes, it can never cause a reviewer session to hit --timeout, because it has
# already finished by the time dispatch starts. Shared by both sequential and
# --parallel modes (computed once here, injected into whichever brief(s) follow).
# A FAIL short-circuits dispatch entirely (see the fail-fast branch below) --
# reviewing code that is already guaranteed NO-GO wastes reviewer tokens for
# no benefit. A PASS is tagged onto the real dispatch result afterward
# (gate_apply_preflight_pass_tag). Either way this is enforced mechanically,
# NOT by asking a reviewer LLM to correctly interpret and relay it. See
# CC-470 Part 3.
PREFLIGHT_STATUS="skipped"
PREFLIGHT_LOG_PATH=""
PREFLIGHT_EVIDENCE_PATH=""
PREFLIGHT_EVIDENCE_DIGEST=""
PREFLIGHT_RICH_RESULT_PATH=""

# relocate_gate_artifacts() (below) moves everything under $WORK_DIR/.gate-results
# carrying $TIMESTAMP -- including the pre-flight log -- out to $GATE_RUN_DIR_OVERRIDE
# AFTER dispatch completes. Any log path baked into persisted text (the brief's
# evidence block, the mechanical override note in the result body) must point at
# where the file will actually BE by the time a human reads it, not where it
# started -- otherwise --run-dir runs leave a stale pointer into a directory the
# EXIT trap already emptied. This mirrors relocate_gate_artifacts' own
# OUTPUT_FILE-repointing logic (same condition) without needing to relocate the
# log file itself any earlier than dispatch allows.
_preflight_log_display_path() {
  local path="$1"
  if [[ -n "$path" && -n "$GATE_RUN_DIR_OVERRIDE" && -z "$OUTPUT_OVERRIDE" ]]; then
    printf '%s/.gate-results/%s' "$GATE_RUN_DIR_OVERRIDE" "$(basename "$path")"
  else
    printf '%s' "$path"
  fi
}

_preflight_sha256_file() {
  gate_digest_file "$1"
}

# Copy-mode portable content identity. It binds tracked and non-ignored
# untracked content (including executable bits and symlink targets), while
# excluding only gate-owned runtime artifacts created by this invocation.
_preflight_tree_fingerprint() {
  _gate_subject_tree_fingerprint "$WORK_DIR" working_tree \
    "$(git -C "$WORK_DIR" rev-parse HEAD 2>/dev/null)"
}

_preflight_repo_identity() {
  local remote
  remote="$(git -C "$WORK_DIR" config --get remote.origin.url 2>/dev/null || true)"
  printf '%s\n%s\n' "$WORK_DIR" "$remote" | gate_digest_stream
}

GATE_BINDING_REPO_IDENTITY="$(_preflight_repo_identity)" || exit 2
GATE_BINDING_BASE_COMMIT="$(git rev-parse "${BASE}^{commit}")" || exit 2
GATE_BINDING_HEAD_COMMIT="$(git rev-parse "${HEAD_REF}^{commit}")" || exit 2
GATE_SUBJECT_CREATED_AT="$(date -u +'%Y-%m-%dT%H:%M:%SZ' 2>/dev/null \
  || date +'%Y-%m-%dT%H:%M:%SZ')"
if [[ "$HEAD_REF" != "HEAD" ]]; then
  GATE_SUBJECT_KIND=fixed_ref
  GATE_SUBJECT_DIRTY_POLICY=ignore_working_tree
elif _worktree_is_dirty; then
  GATE_SUBJECT_KIND=working_tree
  GATE_SUBJECT_DIRTY_POLICY=include_working_tree
else
  GATE_SUBJECT_KIND=committed_head
  GATE_SUBJECT_DIRTY_POLICY=require_clean
fi
GATE_SUBJECT_INITIAL="$(
  gate_subject_snapshot "$WORK_DIR" "$BASE" "$HEAD_REF" "$GATE_SUBJECT_KIND" \
    "$GATE_SUBJECT_DIRTY_POLICY" "$GATE_SUBJECT_CREATED_AT"
)" || {
  printf 'Error: unable to capture immutable gate subject\n' >&2
  exit 2
}
# shellcheck disable=SC2034 # consumed by the canonical assurance module
GATE_SUBJECT_REPOSITORY_KEY="$(jq -r '.repository.key' <<<"$GATE_SUBJECT_INITIAL")"
GATE_BINDING_SUBJECT_FINGERPRINT="$(
  jq -r '.tree_fingerprint' <<<"$GATE_SUBJECT_INITIAL"
)"

# ── Immutable declared review scope ──────────────────────────────────────────
# Build one machine-owned manifest before any reviewer dispatch. The artifact
# is read-only reviewer context; its digest, not prompt prose, proves that
# sequential and parallel reviewers received the same declared scope.
mkdir -p "$WORK_DIR/.gate-results"
SCOPE_MANIFEST_PATH="$WORK_DIR/.gate-results/gate-scope-manifest-${TIMESTAMP}.json"
SCOPE_CHANGE_ENTRIES_JSON="$(_gate_scope_changes_collect)" || {
  printf 'Error: unable to collect the gate scope change set\n' >&2
  exit 2
}
if [[ "$(jq -r 'length' <<<"$SCOPE_CHANGE_ENTRIES_JSON")" -eq 0 ]]; then
  printf 'Error: gate scope manifest found no changed paths\n' >&2
  exit 2
fi
_gate_assurance_destination_check "$SCOPE_MANIFEST_PATH" || exit 2
_gate_scope_manifest_write "$SCOPE_MANIFEST_PATH" \
  "$SCOPE_CHANGE_ENTRIES_JSON" "$GATE_POLICY_RESOLUTION" || {
    printf 'Error: unable to create gate scope manifest\n' >&2
    exit 2
  }
SCOPE_MANIFEST_DIGEST="$(_gate_result_sha256_file "$SCOPE_MANIFEST_PATH")" || exit 2
QA_EXECUTION_EVIDENCE_PATH=""
QA_EXECUTION_HELPER_PATH=""
QA_EXECUTION_CONTEXT_BLOCK=""

# CC-522 Slice B.  The reviewer cannot make a watchdog-safe test execution
# record by writing prose after a command returns: a timeout may prevent that
# write forever.  This host-created helper commits a checkpoint before it
# execs the requested command, owns stdout/stderr, and leaves a non-authorizing
# partial record when its parent reviewer is killed.
qa_execution_prepare() {
  [[ " $REVIEWERS " == *" qa-tester "* ]] || return 0
  QA_EXECUTION_EVIDENCE_PATH="$WORK_DIR/.gate-results/qa-execution-${TIMESTAMP}.json"
  QA_EXECUTION_HELPER_PATH="$WORK_DIR/.gate-results/qa-test-attempt-${TIMESTAMP}.sh"
  local created_at
  created_at="$(date -u +'%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date +'%Y-%m-%dT%H:%M:%SZ')"
  jq -n --arg subject "$GATE_BINDING_SUBJECT_FINGERPRINT" \
    --arg scope "$SCOPE_MANIFEST_DIGEST" --arg created_at "$created_at" '
      {kind:"qa_execution_evidence_v1",schema_version:1,reviewer:"qa-tester",
       subject_fingerprint:$subject,scope_manifest_sha256:$scope,created_at:$created_at,
       status:"awaiting_checkpoint",
       checkpoint:{status:"missing",matrix_audit:"not_recorded",command_identity:null,
         timeout_seconds:null,created_at:null},
       attempt:{status:"not_started",exit_status:null,started_at:null,finished_at:null,
         log:{path:null,sha256:null}},host_finalization:null}' > "$QA_EXECUTION_EVIDENCE_PATH" || return 1
  cat > "$QA_EXECUTION_HELPER_PATH" <<'QA_ATTEMPT_EOF'
#!/usr/bin/env bash
set -euo pipefail
checkpoint=""; log=""; timeout_seconds=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --checkpoint) checkpoint="${2:?missing checkpoint}"; shift 2 ;;
    --log) log="${2:?missing log}"; shift 2 ;;
    --timeout) timeout_seconds="${2:?missing timeout}"; shift 2 ;;
    --) shift; break ;;
    *) printf 'qa-test-attempt: unknown argument: %s\n' "$1" >&2; exit 2 ;;
  esac
done
[[ -n "$checkpoint" && -n "$log" && "$timeout_seconds" =~ ^[1-9][0-9]*$ && $# -gt 0 ]] || {
  printf 'qa-test-attempt: usage: --checkpoint FILE --log FILE --timeout SEC -- COMMAND...\n' >&2; exit 2; }
[[ -f "$checkpoint" && ! -L "$checkpoint" ]] || { printf 'qa-test-attempt: checkpoint must be a regular file\n' >&2; exit 2; }
sha_stream() {
  if command -v sha256sum >/dev/null 2>&1 \
      && printf '' | sha256sum >/dev/null 2>&1; then
    sha256sum | awk '{print $1}'
    return 0
  fi
  if command -v shasum >/dev/null 2>&1 \
      && printf '' | shasum -a 256 >/dev/null 2>&1; then
    shasum -a 256 | awk '{print $1}'
    return 0
  fi
  printf 'qa-test-attempt: no sha256sum or shasum found\n' >&2
  return 2
}
sha_file() { sha_stream < "$1"; }
command_digest="$(printf '%q\037' "$@" | sha_stream)" || exit 2
command_identity="sha256:${command_digest}"
started="$(date -u +'%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date +'%Y-%m-%dT%H:%M:%SZ')"
tmp="$(mktemp "${checkpoint}.tmp.XXXXXX")"
jq --arg command_identity "$command_identity" --argjson timeout "$timeout_seconds" --arg started "$started" --arg log "$log" '
  .status="running" | .checkpoint={status:"present",matrix_audit:"completed",
    command_identity:$command_identity,timeout_seconds:$timeout,created_at:$started} |
  .attempt={status:"running",exit_status:null,started_at:$started,finished_at:null,
    log:{path:$log,sha256:null}} | .host_finalization=null' "$checkpoint" > "$tmp"
mv "$tmp" "$checkpoint"
set +e
timeout --kill-after=15 "$timeout_seconds" "$@" > "$log" 2>&1
rc=$?
set -e
finished="$(date -u +'%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date +'%Y-%m-%dT%H:%M:%SZ')"
if [[ "$rc" -eq 0 ]]; then status=pass; overall=completed
elif [[ "$rc" -eq 124 || "$rc" -eq 137 ]]; then status=timeout; overall=inconclusive
else status=nonzero; overall=inconclusive; fi
log_sha="$(sha_file "$log")" || exit 2
tmp="$(mktemp "${checkpoint}.tmp.XXXXXX")"
jq --arg status "$status" --arg overall "$overall" --argjson rc "$rc" \
  --arg finished "$finished" --arg log_sha "$log_sha" '
  .status=$overall | .attempt.status=$status | .attempt.exit_status=$rc |
  .attempt.finished_at=$finished | .attempt.log.sha256=$log_sha' "$checkpoint" > "$tmp"
mv "$tmp" "$checkpoint"
exit "$rc"
QA_ATTEMPT_EOF
  chmod 0700 "$QA_EXECUTION_HELPER_PATH" || return 1
  printf -v QA_EXECUTION_CONTEXT_BLOCK \
    '  QA execution evidence (qa-tester only):\n    checkpoint: %s\n    helper: %s\n    Contract: before every supplemental test command, invoke the host helper as\n      %s --checkpoint %s --log %s --timeout <seconds> -- <command>\n    The helper flushes a checkpoint before execution and owns the command log. Do not run\n    a supplemental test directly. If no supplemental test is needed, leave this artifact\n    untouched and explain that in Evidence Accounting.\n' \
    "$QA_EXECUTION_EVIDENCE_PATH" "$QA_EXECUTION_HELPER_PATH" "$QA_EXECUTION_HELPER_PATH" \
    "$QA_EXECUTION_EVIDENCE_PATH" "$WORK_DIR/.gate-results/qa-test-attempt-${TIMESTAMP}.log"
}

qa_execution_finalize() {
  local exit_status="${1:-0}" now tmp terminal
  [[ -n "$QA_EXECUTION_EVIDENCE_PATH" && -f "$QA_EXECUTION_EVIDENCE_PATH" ]] || return 0
  terminal="$(jq -r '.status // empty' "$QA_EXECUTION_EVIDENCE_PATH" 2>/dev/null || true)"
  [[ "$terminal" == completed || "$terminal" == inconclusive || "$terminal" == not_run ]] && return 0
  now="$(date -u +'%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date +'%Y-%m-%dT%H:%M:%SZ')"
  tmp="$(mktemp "${QA_EXECUTION_EVIDENCE_PATH}.tmp.XXXXXX")" || return 0
  # `not_run` is truthful only when the helper never wrote its early
  # checkpoint.  A `running` record proves that supplemental execution was
  # requested; if its writer disappears before the terminal update, retain it
  # as non-authorizing inconclusive evidence even when the overall gate exits
  # successfully.
  if [[ "$exit_status" -eq 0 && "$terminal" == awaiting_checkpoint ]]; then
    if jq --arg now "$now" '.status="not_run" | .host_finalization={reason:"no supplemental QA command requested",at:$now}' \
        "$QA_EXECUTION_EVIDENCE_PATH" > "$tmp"; then
      mv "$tmp" "$QA_EXECUTION_EVIDENCE_PATH" || rm -f "$tmp"
    else
      rm -f "$tmp"
    fi
  else
    if jq --arg now "$now" --argjson exit_status "$exit_status" --arg terminal "$terminal" \
        '.status="inconclusive" | .host_finalization={reason:(if $terminal == "running" then "QA test attempt ended before it reached a terminal state" else "reviewer session ended before QA evidence reached a terminal state" end),at:$now,gate_exit_status:$exit_status}' \
        "$QA_EXECUTION_EVIDENCE_PATH" > "$tmp"; then
      mv "$tmp" "$QA_EXECUTION_EVIDENCE_PATH" || rm -f "$tmp"
    else
      rm -f "$tmp"
    fi
  fi
}
PROTOCOL_RECOVERY_PATH="$WORK_DIR/.gate-results/gate-protocol-attempts-${TIMESTAMP}.jsonl"
_gate_protocol_attempt_record() {
  local role="$1" reviewer="$2" attempt="$3" outcome="$4" reason="$5" artifact="$6"
  jq -nc \
    --arg role "$role" --arg reviewer "$reviewer" --argjson attempt "$attempt" \
    --arg outcome "$outcome" --arg reason "$reason" --arg artifact "$artifact" \
    --arg scope_sha "$SCOPE_MANIFEST_DIGEST" \
    --arg subject_fingerprint "$GATE_BINDING_SUBJECT_FINGERPRINT" '{
      kind:"gate_protocol_attempt_v1",schema_version:1,
      role:$role,
      reviewer:(if $reviewer == "" then null else $reviewer end),
      attempt:$attempt,outcome:$outcome,reason:$reason,artifact:$artifact,
      scope_manifest_sha256:$scope_sha,
      subject_fingerprint:$subject_fingerprint
    }' >> "$PROTOCOL_RECOVERY_PATH"
}
SCOPE_MANIFEST_CONTENT_DIGEST="$(jq -r '.content.digest' "$SCOPE_MANIFEST_PATH")"
SCOPE_MANIFEST_STATUS="$(jq -r '.status' "$SCOPE_MANIFEST_PATH")"
SCOPE_MANIFEST_EXPANSION_COUNT="$(jq -r '.expansion.entries | length' \
  "$SCOPE_MANIFEST_PATH")"
ADJACENT_TEST_FILES="$(jq -r '
  . as $manifest |
  .paired_tests[] |
  .test_path as $test |
  select(($manifest.changes.changed_paths | index($test)) == null) |
  $test
' "$SCOPE_MANIFEST_PATH")"
ADJ_COUNT="$(printf '%s\n' "$ADJACENT_TEST_FILES" \
  | grep -c '[^[:space:]]' 2>/dev/null || true)"

SCOPE_DECLARED_REVIEW_FILES="$(jq -r '[
  .changes.entries[] | .new_path // empty
] + [.paired_tests[].test_path] + [.expansion.included_paths[]] |
  unique | sort | .[]' "$SCOPE_MANIFEST_PATH")"
ALL_REVIEW_FILES="$(printf '%s\n%s\n' "$ALL_REVIEW_FILES" \
  "$SCOPE_DECLARED_REVIEW_FILES" | awk 'NF && !seen[$0]++')"
DIFF_FILE_ENTRIES=""
while IFS= read -r f; do
  [[ -n "$f" ]] || continue
  fp="$WORK_DIR/$f"
  [[ -f "$fp" && ! -L "$fp" ]] \
    && DIFF_FILE_ENTRIES="${DIFF_FILE_ENTRIES}  - read: ${fp}"$'\n'
done <<< "$ALL_REVIEW_FILES"
DIFF_FILE_ENTRIES="${DIFF_FILE_ENTRIES}  - read: ${SCOPE_MANIFEST_PATH}"$'\n'

printf -v SCOPE_MANIFEST_CONTEXT_BLOCK \
  '  Declared scope manifest (machine-owned; use this digest in every coverage claim):\n    status: %s\n    artifact: %s\n    artifact_sha256: %s\n    content_digest: %s\n    subject_fingerprint: %s\n    expansion_claim: bounded-hints-not-complete-call-graph\n    reference_claim: declared-review-reference-set\n' \
  "$SCOPE_MANIFEST_STATUS" "$SCOPE_MANIFEST_PATH" "$SCOPE_MANIFEST_DIGEST" \
  "$SCOPE_MANIFEST_CONTENT_DIGEST" "$GATE_BINDING_SUBJECT_FINGERPRINT"
say 'pr-gate: scope manifest status=%s sha256=%s expansions=%s artifact=%s\n' \
  "$SCOPE_MANIFEST_STATUS" "$SCOPE_MANIFEST_DIGEST" \
  "$SCOPE_MANIFEST_EXPANSION_COUNT" \
  "$(_preflight_log_display_path "$SCOPE_MANIFEST_PATH")"
[[ "$ADJ_COUNT" -gt 0 ]] \
  && say '  adjacent test files added: %d\n' "$ADJ_COUNT"

if [[ "$SCOPE_MANIFEST_STATUS" == incomplete ]]; then
  {
    printf 'INCOMPLETE: declared scope exceeded bounded manifest budgets before reviewer dispatch.\n'
    printf '  manifest: %s\n' "$(_preflight_log_display_path "$SCOPE_MANIFEST_PATH")"
    printf '  omitted: %s\n' \
      "$(jq -c '.truncation.omitted' "$SCOPE_MANIFEST_PATH")"
    printf '  reasons: %s\n' \
      "$(jq -c '.truncation.reasons' "$SCOPE_MANIFEST_PATH")"
    printf '  Inspect the manifest, then rerun with --accept-scope-truncation only if those omissions are acceptable.\n'
  } >&2
  if [[ "$GATE_OUTPUT_EXISTED" != true ]]; then
    rm -f -- "$OUTPUT_FILE"
  fi
  exit 3
fi

REVIEWER_PROTOCOL_SURFACES="$(
  _gate_reviewer_protocol_surfaces | awk '
    NR == 1 { out=$0; next }
    { out=out "," $0 }
    END { print out }
  '
)" || exit 2
REVIEWER_REFERENCE_LINE_BOUNDS="$({
  jq -r '.reference_index.entries[] | "    \(.path): max-line=\(.line_count)"' \
    "$SCOPE_MANIFEST_PATH"
  printf '    .gate-results/%s: max-line=%s\n' \
    "$(basename "$SCOPE_MANIFEST_PATH")" \
    "$(awk 'END { print NR+0 }' "$SCOPE_MANIFEST_PATH")"
} 2>/dev/null)" || exit 2
# shellcheck disable=SC2016 # Literal Markdown fence delimiters in reviewer prose.
printf -v REVIEWER_PROTOCOL_INSTRUCTIONS \
  '%s\n' \
  '  Selected-reviewer protocol (mandatory; protocol completeness is machine-validated):' \
  '  - Emit exactly one JSON block opened by ```reviewer_result_v1 and closed by ```.' \
  '  - kind=gate_reviewer_result_v1, schema_version=1, reviewer=<current reviewer>.' \
  '  - The JSON object has exactly these ten top-level keys: kind, schema_version,' \
  '    reviewer, scope_manifest_sha256, coverage_claim, coverage, findings, test_gaps, verdict,' \
  '    rationale. No role-specific or legacy top-level keys are allowed.' \
  "  - scope_manifest_sha256=${SCOPE_MANIFEST_DIGEST}." \
  '  - Every evidence_refs[].path and finding source.path must be either a path in' \
  '    reference_index.entries[] from the declared scope manifest or the manifest' \
  "    reference .gate-results/$(basename "$SCOPE_MANIFEST_PATH")." \
  '    A line reference must not exceed that index entry line_count. Arbitrary,' \
  '    nonexistent, or out-of-scope repository paths make the protocol INCOMPLETE.' \
  '  - Reference line bounds (do not cite beyond these immutable snapshot limits):' \
  "$REVIEWER_REFERENCE_LINE_BOUNDS" \
  '  - coverage_claim=declared-scope-checklist-not-review-completeness.' \
  "  - coverage contains each surface exactly once: ${REVIEWER_PROTOCOL_SURFACES}." \
  '  - Every coverage entry has surface, status=examined|not_applicable|uncertain,' \
  '    evidence_refs, and a non-empty reason. Every evidence ref has a relative path' \
  '    plus line or symbol (both are allowed). examined requires at least one ref;' \
  '    never use silence for not_applicable or uncertain.' \
  '  - Continue through every coverage surface after finding a blocker; do not early-stop.' \
  '  - test_gaps is non-empty. qa-tester audits every applicable test dimension; any' \
  '    reviewer that identifies a behavior gap records it. Each row has id=<reviewer>-TGNNN,' \
  '    reviewer, status=gap|no_gap, affected_behavior, contract, existing_evidence,' \
  '    coverage_dimensions (happy|boundary|negative|regression|concurrency|security|' \
  '    migration|rollback), missing_layer, scenario, oracle, failure_signal, and' \
  '    suggested_command. coverage_dimensions permits only those eight enum tokens;' \
  '    contract is a missing_layer value, never a coverage_dimensions value.' \
  '    A gap uses missing_layer=unit|integration|contract|e2e|' \
  '    manual|operational and non-empty scenario/oracle/failure_signal/command.' \
  '    Sufficient coverage uses no_gap, missing_layer=none, null scenario/oracle/' \
  '    failure_signal/suggested_command, and concrete existing_evidence.' \
  '    existing_evidence MUST be a non-empty JSON array of evidence-ref objects,' \
  '    for example [{"path":"tests/shell/test-example.sh","line":42}]; never' \
  '    use a string or Markdown citation. Every object needs path plus line or' \
  '    symbol, and must appear in the verified reference index.' \
  '    Every finding must have a status=gap row with the exact same' \
  '    affected_behavior so its test direction remains mechanically traceable.' \
  '  - findings is an array. Each finding requires id=<reviewer>-FNNN, reviewer,' \
  '    using the exact prefix critic-FNNN, qa-tester-FNNN,' \
  '    architecture-reviewer-FNNN, security-reviewer-FNNN, or' \
  '    risk-reviewer-FNNN. Abbreviations such as risk-F001 are invalid.' \
  '    severity=critical|high|medium|low, hard_gate_class=none|soft_block|hard_block,' \
  '    origin=diff_caused|pre_existing|uncertain|caution, source={path,line,symbol},' \
  '    affected_behavior, why_it_matters, failure_mode, minimum_fix_boundary, and' \
  '    verification_expectation. source needs path plus line or symbol.' \
  '  - soft_block/hard_block findings require severity=critical|high and' \
  '    origin=diff_caused|uncertain. medium/low and pre_existing/caution findings' \
  '    must use hard_gate_class=none.' \
  '  - block-soft needs a soft_block finding; block needs a hard_block finding;' \
  '    approve/advise may contain only hard_gate_class=none.' \
  '  - verdict is exactly approve|advise|block-soft|block. Map legacy pass and' \
  '    pass-not-applicable to approve; map needs-tests to block. Never put pass,' \
  '    pass-not-applicable, needs-tests, or prose in verdict; prose belongs in rationale.' \
  '  - Legacy fields such as status, summary, matrix, run, audit_findings, over_scope,' \
  '    missed, alignment, reversibility, and override_path must not appear at top level.' \
  '  - Do not claim semantic completeness or coverage for an unselected reviewer.'

# shellcheck disable=SC2016 # Literal Markdown fence delimiters in synthesis prose.
printf -v SYNTHESIS_PROTOCOL_INSTRUCTIONS \
  '%s\n' \
  '  Synthesis protocol (mandatory; parity with reviewer JSON is machine-validated):' \
  '  - Emit exactly one JSON block opened by ```synthesis_result_v1 and closed by ```.' \
  '  - The JSON object has exactly these eighteen top-level keys: kind,' \
  '    schema_version, scope_manifest_sha256, selected_reviewers,' \
  '    not_reviewed_dimensions, coverage_matrix, reviewer_finding_inventory,' \
  '    findings_union, remediation_confirmations, root_cause_groups, disagreements,' \
  '    uncertainties, cautions,' \
  '    test_gap_matrix, operational_cautions, user_cautions, verification_plan,' \
  '    remediation_seed. Do not add wrapper objects or arrays.' \
  '  - kind=gate_synthesis_result_v1, schema_version=1, and' \
  "    scope_manifest_sha256=${SCOPE_MANIFEST_DIGEST}." \
  "  - selected_reviewers is exactly ${SYNTHESIS_SELECTED_JSON} in that order." \
  "  - not_reviewed_dimensions is exactly ${SYNTHESIS_SKIPPED_JSON} in that order." \
  '  - coverage_matrix copies every reviewer coverage cell without changing reviewer,' \
  '    surface, status, evidence_refs, or reason.' \
  '  - reviewer_finding_inventory copies every stable ID, reviewer, severity,' \
  '    hard_gate_class, origin, and verification_expectation.' \
  '  - findings_union preserves every original finding field and adds only' \
  '    root_cause_group_id=RCG-NNN plus disposition=pending. Never drop a lower' \
  '    severity, caution, uncertainty, disagreement input, or test expectation.' \
  '  - remediation_confirmations is [] for an initial pass. For a targeted pass,' \
  '    emit one {finding_id,status,summary,evidence_refs} object with status=confirmed' \
  '    for every initial diff-caused/uncertain finding listed in the targeted' \
  '    remediation context below. This is a separate confirmation ledger; do not' \
  '    copy fixed findings into findings_union just to prove they were reviewed.' \
  '  - root_cause_groups partitions every finding ID exactly once. Different reviewers' \
  '    may share a group only when they describe the same root cause; different issues' \
  '    in the same file remain distinct. With no findings, emit an empty group array.' \
  '  - disagreements is an array of {id:D-NNN,summary,finding_ids}; use [] when none.' \
  '  - uncertainties is exactly one object, never an array:' \
  '    {finding_ids:[...],coverage_cells:[{reviewer,surface,reason},...]}.' \
  '    Its two arrays exactly match uncertain findings and coverage statuses.' \
  '  - cautions is the complete stable-ID list whose origin is caution.' \
  '  - test_gap_matrix copies every reviewer test_gaps row byte-for-byte by field;' \
  '    never drop a row. operational_cautions and user_cautions are unique strings.' \
  '  - verification_plan is {focused,manual,full}. focused is exactly the unique' \
  '    suggested_command set from status=gap rows; manual is a unique string array;' \
  '    full is a non-empty unique string array naming the final broad verification.' \
  '  - remediation_seed is {kind:remediation_closure_v1,schema_version:1,state:seed,' \
  '    scope_manifest_sha256,entries}. It contains one pending entry per finding with' \
  '    finding_id, reviewer, root_cause_group_id, disposition, and' \
  '    verification_expectation. This is a seed, never a closure or final-tree GO claim.' \
  '  - The consolidated human result contains exactly one section each named:' \
  '    ## Must-Fix Order; ## Advisory and Cautions;' \
  '    ## Coverage Gaps and Uncertainties; ## Test Coverage to Add or Strengthen;' \
  '    ## Operational and User Cautions; ## Post-Fix Verification Plan;' \
  '    ## Recommended Verification.' \
  '  - Raw reviewer_result_v1 blocks remain authoritative and traceable. The synthesis' \
  '    contract proves union/parity only; it does not claim defect or model-recall completeness.'

if [[ "$SKIP_PREFLIGHT_TESTS" != "true" && -n "$TEST_CMD_OVERRIDE" ]]; then
  # pr-gate.sh is designed to be copied standalone into any repo (copy-mode --
  # see the file header), so it must not hardcode any repo-specific test
  # command or path convention. --test-cmd is the ONLY way to opt in: the
  # caller (a human, or the /pr-gate skill, which already knows this repo's
  # own convention) supplies it explicitly for this invocation -- that
  # explicit act IS the consent, so no additional --allow-hooks gate applies
  # (contrast with .pm-dispatch/pre-gate.sh above, whose content is arbitrary
  # and repo-supplied, not operator-supplied).
  mkdir -p "$WORK_DIR/.gate-results"
  PREFLIGHT_LOG_PATH="$WORK_DIR/.gate-results/preflight-tests-${TIMESTAMP}.log"
  PREFLIGHT_EVIDENCE_PATH="$WORK_DIR/.gate-results/preflight-evidence-${TIMESTAMP}.json"
  PREFLIGHT_RICH_RESULT_PATH="$WORK_DIR/.gate-results/preflight-rich-result-${TIMESTAMP}.json"
  _preflight_command_digest="$(printf '%s' "$TEST_CMD_OVERRIDE" | gate_digest_stream)" || exit 2
  _preflight_before="$(_preflight_tree_fingerprint)" || exit 2
  _preflight_repo_id="$GATE_BINDING_REPO_IDENTITY"
  _preflight_base_commit="$GATE_BINDING_BASE_COMMIT"
  _preflight_head_commit="$GATE_BINDING_HEAD_COMMIT"
  _preflight_started="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
  say 'pr-gate: running pre-flight test suite (timeout %ss, command sha256:%s)\n' \
    "$TEST_TIMEOUT" "${_preflight_command_digest:0:12}"
  _preflight_rc=0
  if [[ -n "${PM_GATE_PARENT_OPERATION:-}" ]]; then
    _detached_launch_lib="$PR_GATE_LIB_DIR/detached-launch.sh"
    if ! declare -F detached_launch_kill_process_group >/dev/null 2>&1; then
      # shellcheck disable=SC1090,SC1091 # resolved repo-relative runtime library.
      [[ -r "$_detached_launch_lib" ]] && . "$_detached_launch_lib"
    fi
    declare -F detached_launch_kill_process_group >/dev/null 2>&1 || {
      printf 'Error: operation-owned pre-flight cleanup helper is unavailable\n' >&2
      exit 2
    }
    command -v setsid >/dev/null 2>&1 || {
      printf 'Error: operation-owned pre-flight isolation requires setsid\n' >&2
      exit 2
    }
    (
      cd "$WORK_DIR"
      export PM_DISPATCH_PREFLIGHT_TEST_RESULT="$PREFLIGHT_RICH_RESULT_PATH"
      export PM_DISPATCH_PREFLIGHT_SUBJECT_FINGERPRINT="$_preflight_before"
      export PM_DISPATCH_PREFLIGHT_BASE_COMMIT="$_preflight_base_commit"
      export PM_DISPATCH_PREFLIGHT_HEAD_COMMIT="$_preflight_head_commit"
      export PM_DISPATCH_TEST_COMMAND_IDENTITY="sha256:${_preflight_command_digest}"
      # The test command is a subject of this gate, not another producer owned
      # by the same parent operation.  Do not let nested pmctl/pr-gate fixtures
      # attach themselves to or infer ownership from the outer gate.
      unset PM_GATE_PARENT_OPERATION
      exec setsid timeout --kill-after=15 "$TEST_TIMEOUT" bash -c "$TEST_CMD_OVERRIDE"
    ) > "$PREFLIGHT_LOG_PATH" 2>&1 &
    GATE_ACTIVE_PREFLIGHT_PID=$!
    GATE_ACTIVE_PREFLIGHT_PGID=$!
    wait "$GATE_ACTIVE_PREFLIGHT_PID" || _preflight_rc=$?
    GATE_ACTIVE_PREFLIGHT_PID=""
    GATE_ACTIVE_PREFLIGHT_PGID=""
  else
    ( cd "$WORK_DIR" && PM_DISPATCH_PREFLIGHT_TEST_RESULT="$PREFLIGHT_RICH_RESULT_PATH" \
        PM_DISPATCH_PREFLIGHT_SUBJECT_FINGERPRINT="$_preflight_before" \
        PM_DISPATCH_PREFLIGHT_BASE_COMMIT="$_preflight_base_commit" \
        PM_DISPATCH_PREFLIGHT_HEAD_COMMIT="$_preflight_head_commit" \
        PM_DISPATCH_TEST_COMMAND_IDENTITY="sha256:${_preflight_command_digest}" \
        timeout --kill-after=15 "$TEST_TIMEOUT" bash -c "$TEST_CMD_OVERRIDE" ) \
      > "$PREFLIGHT_LOG_PATH" 2>&1 || _preflight_rc=$?
  fi
  _preflight_finished="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
  _preflight_after="$(_preflight_tree_fingerprint)" || exit 2
  _preflight_log_digest="$(_preflight_sha256_file "$PREFLIGHT_LOG_PATH")" || exit 2
  _preflight_status=unclassified-nonzero
  _preflight_execution=nonzero
  _preflight_test_verdict=not_available
  _preflight_authorization=non_authorizing
  if [[ "$_preflight_rc" -eq 0 ]]; then
    _preflight_status=pass
    _preflight_execution=pass
    _preflight_test_verdict=pass
    _preflight_authorization=eligible
  elif [[ "$_preflight_rc" -eq 124 || "$_preflight_rc" -eq 137 ]]; then
    _preflight_status=timeout
    _preflight_execution=timeout
    _preflight_test_verdict=inconclusive
  elif [[ "$_preflight_rc" -eq 126 || "$_preflight_rc" -eq 127 ]]; then
    _preflight_status=environment-error
    _preflight_test_verdict=inconclusive
  fi
  if [[ "$_preflight_before" != "$_preflight_after" ]]; then
    _preflight_status=stale
    _preflight_test_verdict=inconclusive
    _preflight_authorization=non_authorizing
  fi
  _preflight_coverage='{"type":"opaque","reuse_policy":"advisory"}'
  _preflight_evidence_richness=opaque
  _preflight_rich_digest=""
  if [[ -s "$PREFLIGHT_RICH_RESULT_PATH" ]]; then
    _preflight_rich_digest="$(_preflight_sha256_file "$PREFLIGHT_RICH_RESULT_PATH")" || exit 2
    if jq -e --arg repo "$WORK_DIR" --arg repo_id "$_preflight_repo_id" \
      --arg tree_before "$_preflight_before" --arg tree_after "$_preflight_after" \
      --arg head "$_preflight_head_commit" --argjson rc "$_preflight_rc" '
        .kind == "pm_test_result_v2" and .schema_version == 2 and
        .repo_root == $repo and .repo_identity == $repo_id and
        .tree_fingerprint == $tree_before and .observed_tree_fingerprint_after == $tree_after and
        .head_commit == $head and .exit_code == $rc and
        (.runner_contract_hash | type == "string" and test("^[a-f0-9]{64}$")) and
        (.selection_mode | type == "string" and length > 0) and
        ((.changed_paths | type) == "array") and
        (.suite_set | type == "array" and length > 0) and
        ((.suite_results | type) == "array") and
        ((.suite_results | length) == (.suite_set | length)) and
        ([.suite_results[].name] == .suite_set) and
        (all(.suite_results[];
          (.name | type == "string" and length > 0) and
          (.status == "pass" or .status == "fail" or .status == "timeout" or .status == "skip") and
          (.exit_code | type == "number" and . >= 0 and floor == .) and
          (.duration_seconds | type == "number" and . >= 0 and floor == .))) and
        (.aggregate.status == .status) and
        (.aggregate.selected == (.suite_results | length)) and
        (.aggregate.passed == ([.suite_results[] | select(.status == "pass")] | length)) and
        (.aggregate.failed == ([.suite_results[] | select(.status == "fail")] | length)) and
        (.aggregate.timed_out == ([.suite_results[] | select(.status == "timeout")] | length)) and
        (.aggregate.skipped == ([.suite_results[] | select(.status == "skip")] | length)) and
        (($rc == 0 and .status == "pass") or ($rc != 0 and (.status == "fail" or .status == "stale")))
      ' "$PREFLIGHT_RICH_RESULT_PATH" >/dev/null 2>&1; then
      _preflight_coverage="$(jq -c --arg path "$(_preflight_log_display_path "$PREFLIGHT_RICH_RESULT_PATH")" \
        --arg digest "$_preflight_rich_digest" \
        '{type:"structured",reuse_policy:"no-duplicate-current-pass",
          artifact_path:$path,artifact_sha256:$digest,selection_mode,
          changed_paths,suite_set,suite_results,aggregate}' "$PREFLIGHT_RICH_RESULT_PATH")" || exit 2
      _preflight_evidence_richness=structured
      if [[ "$_preflight_status" != stale ]]; then
        if jq -e '.status == "fail" and .aggregate.failed > 0' \
            "$PREFLIGHT_RICH_RESULT_PATH" >/dev/null 2>&1; then
          _preflight_status=test-fail
          _preflight_test_verdict=fail
        elif jq -e '.status == "stale"' "$PREFLIGHT_RICH_RESULT_PATH" >/dev/null 2>&1; then
          _preflight_status=stale
          _preflight_test_verdict=inconclusive
        elif jq -e '.aggregate.timed_out > 0' "$PREFLIGHT_RICH_RESULT_PATH" >/dev/null 2>&1; then
          _preflight_status=timeout
          _preflight_execution=timeout
          _preflight_test_verdict=inconclusive
        fi
      fi
    else
      _preflight_status=invalid-evidence
      _preflight_test_verdict=inconclusive
      _preflight_authorization=non_authorizing
      _preflight_evidence_richness=invalid
      _preflight_coverage="$(jq -nc --arg path "$(_preflight_log_display_path "$PREFLIGHT_RICH_RESULT_PATH")" \
        --arg digest "$_preflight_rich_digest" \
        '{type:"invalid",reuse_policy:"none",artifact_path:$path,artifact_sha256:$digest}')"
    fi
  fi
  _preflight_log_display="$(_preflight_log_display_path "$PREFLIGHT_LOG_PATH")"
  _preflight_evidence_display="$(_preflight_log_display_path "$PREFLIGHT_EVIDENCE_PATH")"
  jq -n --arg kind pr_gate_preflight_v1 --argjson schema_version 1 \
    --arg command_identity "sha256:${_preflight_command_digest}" --arg status "$_preflight_status" \
    --argjson exit_status "$_preflight_rc" --argjson timeout_seconds "$TEST_TIMEOUT" \
    --arg execution "$_preflight_execution" --arg test_verdict "$_preflight_test_verdict" \
    --arg evidence_richness "$_preflight_evidence_richness" --arg authorization "$_preflight_authorization" \
    --arg started_at "$_preflight_started" --arg finished_at "$_preflight_finished" \
    --arg repo_root "$WORK_DIR" --arg repo_identity "$_preflight_repo_id" \
    --arg base_ref "$BASE" --arg base_commit "$_preflight_base_commit" \
    --arg head_ref "$HEAD_REF" --arg head_commit "$_preflight_head_commit" \
    --arg tree_before "$_preflight_before" --arg tree_after "$_preflight_after" \
    --arg log_path "$_preflight_log_display" --arg log_sha256 "$_preflight_log_digest" \
    --argjson coverage "$_preflight_coverage" \
    '{kind:$kind,schema_version:$schema_version,command_identity:$command_identity,
      status:$status,exit_status:$exit_status,
      outcome:{execution:$execution,test_verdict:$test_verdict,
        evidence_richness:$evidence_richness,authorization:$authorization},
      timeout_seconds:$timeout_seconds,
      started_at:$started_at,finished_at:$finished_at,
      subject:{kind:"workspace",reusable:true,
        fingerprint_before:$tree_before,fingerprint_after:$tree_after},
      provenance:{repo_root:$repo_root,repo_identity:$repo_identity,base_ref:$base_ref,
        base_commit:$base_commit,head_ref:$head_ref,head_commit:$head_commit,
        provider:"git"},
      log:{path:$log_path,sha256:$log_sha256},coverage:$coverage}' > "$PREFLIGHT_EVIDENCE_PATH" || exit 2
  jq -e '.kind == "pr_gate_preflight_v1" and .schema_version == 1 and
    (.command_identity | test("^sha256:[a-f0-9]{64}$")) and
    .subject.reusable == true and
    (.subject.fingerprint_before | test("^[a-f0-9]{64}$")) and
    (.subject.fingerprint_after | test("^[a-f0-9]{64}$")) and
    (.log.sha256 | test("^[a-f0-9]{64}$")) and
    (.status | IN("pass","test-fail","timeout","environment-error","stale","invalid-evidence","unclassified-nonzero")) and
    (.outcome.execution | IN("pass","nonzero","timeout")) and
    (.outcome.test_verdict | IN("pass","fail","not_available","inconclusive")) and
    (.outcome.evidence_richness | IN("opaque","structured","invalid")) and
    (.outcome.authorization | IN("eligible","non_authorizing")) and
    (.coverage.type == "opaque" or .coverage.type == "structured" or .coverage.type == "invalid")' \
    "$PREFLIGHT_EVIDENCE_PATH" >/dev/null || { printf 'Error: invalid pre-flight evidence envelope\n' >&2; exit 2; }
  PREFLIGHT_EVIDENCE_DIGEST="$(_preflight_sha256_file "$PREFLIGHT_EVIDENCE_PATH")" || exit 2
  PREFLIGHT_STATUS="$_preflight_status"
  say 'pr-gate: pre-flight test suite: %s (evidence: %s)\n\n' "$_preflight_status" "$PREFLIGHT_EVIDENCE_PATH"
fi

# Best-effort redaction of common secret shapes before a failed pre-flight
# log excerpt is copied into a reviewer brief -- a non-hermetic test suite's
# stdout/stderr can legitimately contain API keys, bearer tokens, or
# password/token values from the environment it ran in. Mirrors the proven
# pattern in runtime/hooks/guard-pm-bash.sh's _redact_secrets (same threat: don't
# let secret-shaped substrings reach a place they get displayed/persisted).
# Not a complete secret scanner -- closes the common cases, not every one.
_preflight_redact_secrets() {
  # Reads from stdin (used as a pipe filter: `tail ... | _preflight_redact_secrets`),
  # not an argument -- an earlier version took "$1" here, which meant the
  # piped log content was silently discarded and the function only ever
  # processed an empty string. Caught by shellcheck (SC2119/SC2120) before ship.
  sed -E \
    -e 's/sk-[A-Za-z0-9_-]{16,}/***REDACTED***/g' \
    -e 's/gh[ps]_[A-Za-z0-9]{20,}/***REDACTED***/g' \
    -e 's/AKIA[0-9A-Z]{16}/***REDACTED***/g' \
    -e 's/([Bb]earer[[:space:]]+)[A-Za-z0-9._-]+/\1***REDACTED***/g' \
    -e 's/(-{0,2}[A-Za-z0-9][A-Za-z0-9_-]*)?([Pp]assword|[Tt]oken|[Ss]ecret|[Cc]redential|[Aa][Pp][Ii]_?[Kk][Ee][Yy])([A-Za-z0-9_-]*)([=:[:space:]])[^[:space:]]+/\1\2\3\4***REDACTED***/g'
}

# Render the pre-flight evidence block for brief injection. Informational
# context only for reviewers -- NOT the enforcement mechanism (see above).
render_test_evidence_block() {
  local status="$1" log_path="$2" tail display_path evidence_display coverage_type
  [[ "$status" == "skipped" ]] && return 0
  evidence_display="$(_preflight_log_display_path "$PREFLIGHT_EVIDENCE_PATH")"
  coverage_type="$(jq -r '.coverage.type' "$PREFLIGHT_EVIDENCE_PATH")"
  printf '  Pre-flight evidence (machine-verified pr_gate_preflight_v1):\n'
  printf '    Status: %s\n    Artifact: %s\n    Artifact sha256: %s\n' "$status" "$evidence_display" "$PREFLIGHT_EVIDENCE_DIGEST"
  printf '    Subject fingerprint: %s\n    Coverage: %s (%s)\n' \
    "$(jq -r '.subject.fingerprint_before' "$PREFLIGHT_EVIDENCE_PATH")" "$coverage_type" \
    "$(jq -r '.coverage.reuse_policy' "$PREFLIGHT_EVIDENCE_PATH")"
  if [[ "$coverage_type" == structured ]]; then
    printf '    Selection mode: %s\n' "$(jq -r '.coverage.selection_mode' "$PREFLIGHT_EVIDENCE_PATH")"
    printf '    Changed paths: %s\n' "$(jq -r '.coverage.changed_paths | join(", ")' "$PREFLIGHT_EVIDENCE_PATH")"
    printf '    Selected suite results:\n'
    jq -r '.coverage.suite_results[] | "      - \(.name): \(.status) (exit=\(.exit_code), duration=\(.duration_seconds)s)"' "$PREFLIGHT_EVIDENCE_PATH"
  else
    printf '    Selected suites: unavailable (generic command coverage is opaque)\n'
    printf '    QA may run the minimum repo-native validation needed when behavioral coverage\n'
    printf '    cannot be established; record the gap, reason, command, and new evidence.\n'
  fi
  if [[ "$status" == "test-fail" && -n "$log_path" ]]; then
    # Read from the CURRENT (still in-repo) path -- relocation hasn't happened
    # yet at this point in the script -- but DISPLAY the path it will live at
    # once relocate_gate_artifacts moves it, so any reviewer that quotes this
    # verbatim into the persisted result doesn't leave a stale pointer.
    display_path="$(_preflight_log_display_path "$log_path")"
    printf '    Log: %s\n  Last ~40 lines (secret-shaped substrings redacted):\n' "$display_path"
    tail=$(tail -n 40 "$log_path" 2>/dev/null | _preflight_redact_secrets | sed 's/^/    /')
    printf '%s\n' "$tail"
  fi
  printf '  Evidence reuse contract:\n'
  printf '    - First map each behavioral unit in the diff to existing suite evidence above.\n'
  printf '    - Do not rerun a suite with current PASS evidence. Supplemental execution is allowed only\n'
  printf '      for an uncovered behavioral gap, stale/invalid evidence, or a concrete flake suspicion.\n'
  printf '    - Record every supplemental command, gap/reason, new artifact, and duplicate-suite count.\n'
  printf '      Use the repo runner selection/parallelism contract; do not use handwritten for/&& suite\n'
  printf '      lists and do not create test output in the source working tree.\n'
  printf '    - The qa-tester written section must include an Evidence Accounting block with: reused\n'
  printf '      artifact/suites, supplemental executions (gap, reason, command, artifact), and an exact\n'
  printf '      Duplicate suite count. Preserve this block even when the gate later becomes partial/timeout.\n'
}
TEST_EVIDENCE_CONTEXT_BLOCK="$(render_test_evidence_block "$PREFLIGHT_STATUS" "$PREFLIGHT_LOG_PATH")"

# Fail-fast: a failed pre-flight test run already determines Final: NO-GO
# mechanically (see _write_preflight_failure_result below) regardless of what
# any reviewer would say -- so dispatching 5 reviewer LLM sessions to review code that
# is guaranteed to be rejected anyway is pure wasted cost (token spend + wall
# clock) for a result that changes nothing. Skip dispatch entirely and
# synthesize the NO-GO result directly. If the pre-flight fix later turns out
# to also need a code-review pass, that happens on the NEXT gate run after the
# tests are fixed, not blocked from ever happening.
_write_preflight_failure_result() {
  local result_file="$1" log_path="$2" display_path reviewer_lines=""
  local final=test_suite_label conclusion reason
  if [[ "$PREFLIGHT_STATUS" == test-fail ]]; then
    final=NO-GO
    test_suite_label=fail
    conclusion='The structured pre-flight result contains a subject-valid assertion/test failure.'
    reason='Fix the reported failing tests, then re-run pr-gate.'
  else
    final=INCOMPLETE
    test_suite_label=inconclusive
    conclusion='The pre-flight command did not yield authorizing test evidence; this is not a claim that the diff caused a product defect.'
    reason='Follow the recovery instructions below and re-run or supply subject-matching structured evidence.'
  fi
  display_path="$(_preflight_log_display_path "$log_path")"
  local r
  for r in $REVIEWERS; do
    reviewer_lines="${reviewer_lines}  ${r}: skipped"$'\n'
  done
  local excerpt
  excerpt=$(tail -n 40 "$log_path" 2>/dev/null | _preflight_redact_secrets | sed 's/^/    /')
  cat > "$result_file" << PREFLIGHT_FAIL_EOF
---
gate_result_version: pr_gate_result_v1
final: ${final}
tier: ${TIER}
mode: ${MODE_RESOLVED}
most_severe: block
reviewers:
${reviewer_lines}escalation:
  recommended: false
  reviewers: []
  reason: []
test_suite: ${test_suite_label}
test_evidence: $(_preflight_log_display_path "$PREFLIGHT_EVIDENCE_PATH")
test_evidence_sha256: ${PREFLIGHT_EVIDENCE_DIGEST}
---

# PR-Gate Result -- pre-flight ${test_suite_label} (${EXECUTOR} mode)
**Date**: $(date '+%Y-%m-%d')
**Reviewers**: ${REVIEWER_DISPLAY}
**Not reviewed**: all (pre-flight test suite failed; reviewer dispatch was skipped)

## Pre-flight Test Evidence
${conclusion}
Full log: ${display_path}
Evidence artifact: $(_preflight_log_display_path "$PREFLIGHT_EVIDENCE_PATH")
Evidence sha256: ${PREFLIGHT_EVIDENCE_DIGEST}
Last ~40 lines (secret-shaped substrings redacted):
${excerpt}

Reviewer dispatch was skipped because this pre-flight result is non-authorizing.
For INCOMPLETE, inspect the command log, run the same command externally if the
reviewer environment is unsuitable, and provide only subject- and command-matching
structured evidence. Do not infer a test failure from an opaque nonzero exit.

## Gate Conclusion
**Overall verdict**: ${final}
**Most severe individual verdict**: ${test_suite_label}
Final: ${final}
Required action: ${reason}

## Escalation
**Recommended**: false
**Reviewers**: none
**Reason**:
- none
PREFLIGHT_FAIL_EOF
}

if [[ "$PREFLIGHT_STATUS" != "pass" && "$PREFLIGHT_STATUS" != "skipped" ]]; then
  say 'pr-gate: pre-flight status=%s -- skipping reviewer dispatch (%s)\n' \
    "$PREFLIGHT_STATUS" \
    "$([[ "$PREFLIGHT_STATUS" == test-fail ]] && printf 'test NO-GO' || printf 'non-authorizing INCOMPLETE')"
  _write_preflight_failure_result "$OUTPUT_FILE" "$PREFLIGHT_LOG_PATH"
  gate_result_verify "$OUTPUT_FILE" "" "preflight-fail-fast" || exit 1
else

qa_execution_prepare || { printf 'Error: unable to prepare QA execution evidence\n' >&2; exit 2; }

# Snapshot only the selected repo-owned definitions into an artifact-only
# directory inside the reviewed workspace. Both Claude and Codex can read these
# immutable local copies without broad host-home access; cleanup_briefs removes
# them on every success/failure path.
REVIEWER_DEFINITION_DIR="$WORK_DIR/.gate-briefs/reviewer-definitions-${TIMESTAMP}"
mkdir -m 700 -p -- "$REVIEWER_DEFINITION_DIR"
for r in $REVIEWERS; do
  _reviewer_source="$AGENT_DIR/${r}.md"
  _reviewer_snapshot="$REVIEWER_DEFINITION_DIR/${r}.md"
  # umask makes a newly copied definition owner-read-only without depending on
  # chmod being present in the executor test PATH (some gate portability tests
  # deliberately expose only the commands pr-gate strictly needs).
  if [[ "$REVIEWER_SOURCE_MODE" == "base-pinned" ]]; then
    _reviewer_source="$BASE:$REVIEWER_BASE_REL/${r}.md"
    (umask 0377; git show "$_reviewer_source" > "$_reviewer_snapshot") || {
      printf 'Error: failed to snapshot base-pinned reviewer definition: %s\n' "$_reviewer_source" >&2
      exit 1
    }
  else
    if [[ ! -f "$_reviewer_source" || -L "$_reviewer_source" ]]; then
      printf 'Error: trusted reviewer agent file must be a regular non-symlink: %s\n' "$_reviewer_source" >&2
      exit 1
    fi
    _reviewer_nlink="$(stat -c '%h' "$_reviewer_source" 2>/dev/null || stat -f '%l' "$_reviewer_source" 2>/dev/null || printf '1')"
    if [[ "$_reviewer_nlink" =~ ^[0-9]+$ ]] && (( _reviewer_nlink > 1 )); then
      printf 'Error: trusted reviewer agent file must not be hardlinked: %s\n' "$_reviewer_source" >&2
      exit 1
    fi
    _reviewer_source_hash="$(_preflight_sha256_file "$_reviewer_source")" || exit 1
    if ! (umask 0377; cp -P -- "$_reviewer_source" "$_reviewer_snapshot"); then
      printf 'Error: failed to snapshot reviewer definition: %s\n' "$_reviewer_source" >&2
      exit 1
    fi
    _reviewer_nlink="$(stat -c '%h' "$_reviewer_source" 2>/dev/null || stat -f '%l' "$_reviewer_source" 2>/dev/null || printf '1')"
    if [[ -L "$_reviewer_source" || -L "$_reviewer_snapshot" || ! -f "$_reviewer_source" \
        || ( "$_reviewer_nlink" =~ ^[0-9]+$ && "$_reviewer_nlink" -gt 1 ) \
        || "$(_preflight_sha256_file "$_reviewer_source")" != "$_reviewer_source_hash" ]]; then
      printf 'Error: trusted reviewer agent changed during snapshot: %s\n' "$_reviewer_source" >&2
      exit 1
    fi
  fi
  [[ -s "$_reviewer_snapshot" ]] || {
    printf 'Error: reviewer definition snapshot is empty: %s\n' "$_reviewer_snapshot" >&2
    exit 1
  }
done
unset _reviewer_source _reviewer_snapshot _reviewer_nlink _reviewer_source_hash

# ── Dispatch ─────────────────────────────────────────────────────────────────
if [[ "$SEQUENTIAL" == "true" ]]; then

  # ── Sequential mode (default: all reviewers in one combined codex session) ──
  AGENT_FILE_ENTRIES=""
  for r in $REVIEWERS; do
    AGENT_PATH="$REVIEWER_DEFINITION_DIR/${r}.md"
    AGENT_FILE_ENTRIES="${AGENT_FILE_ENTRIES}  - read: ${AGENT_PATH}"$'\n'
  done

  BRIEF_FILE="$BRIEF_DIR/pr-gate-${TIMESTAMP}.md"
  BRIEF_FILES+=("$BRIEF_FILE")

  cat > "$BRIEF_FILE" << BRIEF_EOF
schema_version: 1
working_dir: ${WORK_DIR}

goal: Sequential ${TIER}-tier PR-gate review. Apply each reviewer's criteria to the changed files and write a structured verdict to ${OUTPUT_FILE}.

files:
${AGENT_FILE_ENTRIES}${DIFF_FILE_ENTRIES}  - new:  ${OUTPUT_FILE}

constraints:
  - Do NOT modify any source file.
  - Only write ${OUTPUT_FILE}. The qa-tester alone may additionally invoke the
    host-created QA helper named in its context; that helper is the only allowed
    writer of its pre-created checkpoint and log under .gate-results/.
  - Before your FIRST write to ${OUTPUT_FILE} in this session, call: ${GUARD_PMCTL_CMD} guard check --role reviewer --runtime ${EXECUTOR} --event pre-write --file ${OUTPUT_FILE}
    If that call exits nonzero, abort and report the guard denial -- do NOT write the file.
    You will write to this same file multiple times in this session (once per reviewer, then once for synthesis) -- that is expected. Do not create or write any other file.
  - If you need to test the PM Bash denylist with a command string containing
    destructive syntax, construct that string from shell variables before
    passing it as data to pmctl. Never place a literal destructive invocation
    in the outer Bash command, and never execute the probe itself.
  - Create parent directories for ${OUTPUT_FILE} if needed (mkdir -p).
  - Only cite files in the verified reference index or the diff list. Read a file before citing its sections; do not invent citations.
  - reviewer_result_v1.verdict is the only machine verdict. Markdown reviewer
    headings are presentation only; do not rely on their count or wording.
  - Write a self-contained staging frontmatter with exactly
    gate_result_version: pr_gate_result_v1 and no gate_assurance field. The gate
    shell owns the final result version and bounded assurance pointer and
    publishes them only after reviewer and synthesis verification.

context:
  Tier: ${TIER}
  Executor: ${EXECUTOR}
  Reviewers: ${REVIEWER_DISPLAY}
  Not reviewed: ${SKIPPED_DISPLAY}
  Base: ${BASE}${HEAD_METADATA_LINE}
  Scope: ${SCOPE:-none}
  Date: $(date '+%Y-%m-%d')
${GATE_ASSURANCE_CONTEXT_BLOCK}${SCOPE_MANIFEST_CONTEXT_BLOCK}${GATE_OVERRIDES_CONTEXT_BLOCK}${TEST_EVIDENCE_CONTEXT_BLOCK}${QA_EXECUTION_CONTEXT_BLOCK}
${REVIEWER_PROTOCOL_INSTRUCTIONS}
${SYNTHESIS_PROTOCOL_INSTRUCTIONS}
${MEMORY_CONTEXT_BLOCK}
  Verified reference files (exist in working tree -- check before citing):
${REPO_REF_INDEX}
  Diff (${LINES} changed lines):
${DIFF_STAT_INDENTED}

task:
  Process each reviewer IN ORDER: ${REVIEWER_DISPLAY}

  For EACH reviewer:
  1. Read their agent definition file (listed above). Follow any boot instructions
     and internalize their specific review criteria and verdict scale.
  2. Review the changed files from that reviewer's perspective only.
  3. Produce a structured findings block:
     - The complete mandatory reviewer_result_v1 coverage/finding JSON block
     - Explicit verdict: approve | advise | block-soft | block
  4. IMMEDIATELY write/append that reviewer's "## {reviewer} -- {verdict}" section to
     ${OUTPUT_FILE} before moving to the next reviewer. On the FIRST reviewer, create the
     file starting with the "# PR-Gate Result" header block (date/reviewers/not-reviewed
     lines -- these do not depend on any reviewer's findings), then that reviewer's
     section. On subsequent reviewers, append only that reviewer's section. Do NOT write
     the YAML frontmatter yet -- its fields (final, most_severe, per-reviewer verdicts)
     are only known after synthesis; it is added in step 9 below. Do NOT hold all reviewer
     content in-context until the end -- write each section as soon as it is done, so a
     later reviewer's slowness (e.g. a long test run) cannot destroy earlier reviewers'
     already-completed verdicts if this session is later interrupted or times out.
     The JSON verdict inside reviewer_result_v1 is canonical even if a Markdown
     heading is accidentally duplicated or omitted.

  After all reviewers, synthesize as project-pm would:
  5. Before writing ANY synthesis text or fence, re-read ${OUTPUT_FILE} and verify it
     contains exactly ${NUM_REVIEWERS} reviewer_result_v1 blocks, one for each selected
     reviewer in the listed order. If any reviewer block is missing, append the missing
     reviewer section first. The synthesis_result_v1 block MUST appear only after the
     final reviewer block; never place it inside or before a reviewer section.
  6. Build the deterministic finding inventory, coverage matrix, and test-gap
     matrix from every reviewer_result_v1 block. Preserve all IDs, rows, and
     verification expectations.
  7. Group findings by root cause without dropping or merging stable IDs, and record
     disagreements, uncertainties, cautions, and not-reviewed dimensions.
  8. Emit the complete synthesis_result_v1 JSON block and remediation seed.
  9. Overall verdict = most severe individual verdict. Final GO (no blocks) /
     NO-GO (any block or block-soft), with rationale and override path if applicable.
  10. Now that the final verdict is known: PREPEND the YAML frontmatter block to the very
     top of ${OUTPUT_FILE} (before the header already written in step 4), then APPEND the
     synthesis protocol block and human sections to the bottom. The frontmatter is the
     self-contained v1 staging form described above; do not add gate_assurance. Do not
     rewrite the reviewer sections already written in step 4.

output_format: |
  ---
  gate_result_version: pr_gate_result_v1
  final: GO|NO-GO
  tier: ${TIER}
  mode: ${MODE_RESOLVED}
  most_severe: approve|advise|block-soft|block
  reviewers:
    critic: approve|advise|block-soft|skipped
    qa-tester: pass|needs-tests|block|skipped
    architecture-reviewer: approve|advise|block-soft|skipped
    security-reviewer: pass|block|pass-not-applicable|skipped
    risk-reviewer: pass|block|pass-not-applicable|skipped
  escalation:
    recommended: true|false
    reviewers: []
    reason: []
  ---

  # PR-Gate Result -- ${TIER} tier (${EXECUTOR} mode)
  **Date**: $(date '+%Y-%m-%d')
  **Reviewers**: ${REVIEWER_DISPLAY}
  **Not reviewed**: ${SKIPPED_DISPLAY}

  ## {reviewer-name} -- {verdict}
  \`\`\`reviewer_result_v1
  {one JSON object satisfying the selected-reviewer protocol above}
  \`\`\`

  (repeat for each reviewer in order)

  \`\`\`synthesis_result_v1
  {one JSON object satisfying the synthesis protocol above}
  \`\`\`

  ## Cross-Reviewer Overlaps
  {list issues raised by >1 reviewer; "none" if clean}

  ## Must-Fix Order
  {ordered blocking findings by stable ID; "none" if clean}

  ## Advisory and Cautions
  {all non-blocking findings and cautions by stable ID; "none" if clean}

  ## Coverage Gaps and Uncertainties
  **Dimensions not covered**: ${SKIPPED_DISPLAY}
  {all uncertain coverage cells/findings; "none" if complete}

  ## Test Coverage to Add or Strengthen
  {every status=gap test-gap row, grouped by missing layer; "none" if all rows are no_gap}

  ## Operational and User Cautions
  {render operational_cautions and user_cautions separately; "none" for an empty array}

  ## Post-Fix Verification Plan
  {render focused, manual, and full commands/checks separately}

  ## Recommended Verification
  {verification expectations grouped without dropping any stable finding ID;
  "none" if there are no findings}

  ## Gate Conclusion
  **Overall verdict**: {most severe}
  **Most severe individual verdict**: {most severe}
  Final: GO|NO-GO
  {required fixes if NO-GO; override path if any block-soft}

  CRITICAL -- the Final: line above MUST be emitted EXACTLY in this shape:
  - plain text, no markdown emphasis (NO surrounding **, NO backticks, NO italic)
  - at start of line (no leading whitespace)
  - literal token GO or NO-GO (uppercase, hyphen for NO-GO)
  - matched by the regex ^Final: (GO|NO-GO)\$
  - the value MUST equal the frontmatter \`final:\` field (case-sensitive)
  Examples that BREAK the parser and MUST NOT be emitted: \`**Final: GO**\`, \`Final: **GO**\`, \` Final: GO\`, \`Final: Go\`.

  ## Escalation
  **Recommended**: true|false
  **Reviewers**: <comma-list or "none">
  **Reason**:
  - <bullet> (or "none" when recommended=false)

  Escalation is recommended when:
  (a) policy.escalation_signals above is non-empty; use this canonical resolver
      output and do not re-match paths with a separate regex
  (b) at least one reviewer returned advise|block-soft.

self_verify:
  - cmd: "test -f ${OUTPUT_FILE}"
  - has-conclusion: grep -cE '^Final: (GO|NO-GO)\$' ${OUTPUT_FILE} should be exactly 1
  - frontmatter-final-parity: the value after \`final:\` in the YAML frontmatter MUST equal the value after \`Final:\` in Gate Conclusion (case-sensitive)

acceptance:
  - ${OUTPUT_FILE} exists with a verdict section for each of the ${NUM_REVIEWERS} reviewers
  - exactly one synthesis_result_v1 block preserves reviewer finding and coverage parity
  - Must-Fix Order / Advisory and Cautions / Coverage Gaps and Uncertainties /
    Test Coverage to Add or Strengthen / Operational and User Cautions /
    Post-Fix Verification Plan / Recommended Verification sections are present exactly once
  - "Final: GO" or "Final: NO-GO" is present in Gate Conclusion (plain text, no markdown emphasis)
BRIEF_EOF

  # Every executor dispatches an independent subprocess (codex `codex exec`, claude
  # headless `claude --print`). The Gate transport seam takes the executor name
  # first; direct copy layouts delegate argv construction to dispatch_via_at,
  # while repo layout retains parent-operation lifecycle tracking.
  DISPATCH_CMD="$(gate_dispatch_command "$EXECUTOR" "$BRIEF_FILE" "$WORK_DIR" "$DISPATCH_MODEL" "$DISPATCH_SANDBOX" "$DISPATCH_APPROVAL" "$TIMEOUT" "$DISPATCH_ISOLATION" "$DISPATCH_EFFORT")" || exit 2
  # Send the dispatch child's stdout to our stderr: it is diagnostic chatter,
  # not gate data (the verdict lands in the result file). If it inherited our
  # stdout and a consumer closed that pipe (`gate run | head`), the child's
  # first write would hit EPIPE and -- with SIGPIPE ignored + set -e -- exit
  # nonzero before writing the result, killing the gate before its integrity
  # checks could fire. Parallel reviewers already redirect to a log.
  #
  # Capture the exit code instead of letting `set -e` abort here: a sequential
  # session that times out partway through (e.g. qa-tester stuck running a
  # long test suite) must not discard whatever earlier reviewers already
  # wrote to ${OUTPUT_FILE} per the brief's per-reviewer append instruction
  # (task step 4 above) -- see the partial-result branch below.
  SEQ_DISPATCH_EXIT=0
  eval "$DISPATCH_CMD" >&2 || SEQ_DISPATCH_EXIT=$?

  if [[ "$SEQ_DISPATCH_EXIT" -ne 0 ]]; then
    if [[ "$SEQ_DISPATCH_EXIT" -eq 124 ]]; then
      printf 'Timeout: sequential dispatch did not complete within %ss.\n' "$TIMEOUT" >&2
    else
      printf 'Error: sequential dispatch exited %d.\n' "$SEQ_DISPATCH_EXIT" >&2
    fi
    if [[ -s "$OUTPUT_FILE" ]]; then
      _SEQ_COMPLETED=() _SEQ_INCOMPLETE=()
      for r in $REVIEWERS; do
        if _gate_reviewer_protocol_verdict_extract \
            "$OUTPUT_FILE" "$r" >/dev/null 2>&1; then
          _SEQ_COMPLETED+=("$r")
        else
          _SEQ_INCOMPLETE+=("$r")
        fi
      done
      printf 'Partial result: %d of %d reviewer(s) completed before the session stopped: %s\n' \
        "${#_SEQ_COMPLETED[@]}" "$NUM_REVIEWERS" "${_SEQ_COMPLETED[*]:-none}" >&2
      printf 'Not completed: %s\n' "${_SEQ_INCOMPLETE[*]:-none}" >&2
      printf 'Partial artifact (no Final: verdict -- inconclusive, do NOT treat as GO) preserved at: %s\n' "$OUTPUT_FILE" >&2
      printf 'Raw session trace (for post-mortem): %s\n' "${PM_DISPATCH_TRACE_DIR:-$WORK_DIR/.agent-trace}" >&2
    else
      printf 'Gate aborted -- no reviewer sections were written before the session stopped: %s\n' "$OUTPUT_FILE" >&2
    fi
    exit 1
  fi

  # Validate single-session output via the shared contract (must exist, be
  # non-empty, carry exactly one Final: GO|NO-GO line that agrees with the
  # frontmatter final: field). Same checks the parallel synthesis route and
  # `pmctl gate verify` enforce.
  gate_reviewer_protocol_verify \
    "$OUTPUT_FILE" "$REVIEWERS" "$SCOPE_MANIFEST_DIGEST" \
    "$SCOPE_MANIFEST_PATH" true || exit 1
  gate_synthesis_protocol_verify \
    "$OUTPUT_FILE" "$REVIEWERS" "$SKIPPED_WORDS" \
    "$SCOPE_MANIFEST_DIGEST" true || exit 1
  SEQ_PROTOCOL_FINAL="$(
    _gate_reviewer_protocol_final_extract "$OUTPUT_FILE"
  )" || exit 1
  # shellcheck disable=SC2034 # consumed by the canonical assurance module
  REVIEWER_PROTOCOL_COMPLETE=true
  # shellcheck disable=SC2034 # consumed by the canonical assurance module
  SYNTHESIS_PROTOCOL_COMPLETE=true
  # Executors author an unbound staging document only. Normalize a model that
  # anticipated the final v4 contract back to v1 before the verdict verifier
  # could dereference an assurance sidecar that the shell has not published.
  # Protocol verification intentionally precedes this rewrite so malformed or
  # partial sequential output retains its precise protocol diagnostic.
  gate_result_staging_normalize "$OUTPUT_FILE" "sequential gate" || exit 1
  gate_result_verify \
    "$OUTPUT_FILE" "$SEQ_PROTOCOL_FINAL" "sequential gate" || exit 1

else

  # ── Multi-session mode (--parallel): one independent dispatch per reviewer + synthesis ──
  # Each reviewer runs in its own session with no shared context -- eliminates
  # anchoring bias that can occur when all reviewers share one session window.
  # Followed by a PM synthesis session that consolidates all individual results.
  # Higher token cost vs single-session; suitable for auth/payment/migration paths.

  REVIEWER_OUTPUT_FILES=()
  DISPATCH_PIDS=()
  REVIEWER_NAMES=()

  mkdir -p "$_ARTIFACT_ROOT/.agent-trace"

  # Resolve a portable hash command; fail-closed if none is available or usable.
  # sha256sum (GNU coreutils) is preferred; shasum -a 256 covers macOS/BSD.
  # Both presence (command -v) AND usability (echo | cmd) are verified so a
  # broken stub or wrong-architecture binary is caught before the integrity guard.
  _HASH_CMD=""
  if command -v sha256sum > /dev/null 2>&1 && printf '' | sha256sum > /dev/null 2>&1; then
    _HASH_CMD="sha256sum"
  elif command -v shasum > /dev/null 2>&1 && printf '' | shasum -a 256 > /dev/null 2>&1; then
    _HASH_CMD="shasum -a 256"
  fi
  if [[ -z "$_HASH_CMD" ]]; then
    printf 'Error: no sha256sum or shasum found -- cannot fingerprint worktree for injection detection.\n' >&2
    exit 1
  fi

  # Capture working-tree content fingerprints before dispatch.
  # git diff HEAD: content-level changes to tracked files (catches already-dirty mutations).
  # git status --porcelain -z: new untracked source files. The gate's own artifacts
  # (.agent-trace/ .gate-briefs/ .gate-results/) are excluded explicitly via
  # artifact_filter_porcelain -- the canonical artifact-leaf source of truth in
  # runtime/lib/artifact-paths.sh -- so a repo that has NOT had these paths gitignored
  # is not misread as prompt-injected. NUL-delimited (-z) so special filenames survive.
  _PRE_DISPATCH_DIFF=$(git diff HEAD 2>/dev/null | $_HASH_CMD)
  _PRE_DISPATCH_STATUS=$(git status --porcelain -z 2>/dev/null | artifact_filter_porcelain | $_HASH_CMD)

  for r in $REVIEWERS; do
    AGENT_PATH="$REVIEWER_DEFINITION_DIR/${r}.md"
    REVIEWER_OUTPUT="$WORK_DIR/.gate-results/reviewer-${r}-${TIMESTAMP}.md"
    REVIEWER_BRIEF="$BRIEF_DIR/pr-gate-${TIMESTAMP}-${r}.md"
    DISPATCH_LOG="$_ARTIFACT_ROOT/.agent-trace/gate-${TIMESTAMP}-${r}.log"

    BRIEF_FILES+=("$REVIEWER_BRIEF")
    REVIEWER_OUTPUT_FILES+=("$REVIEWER_OUTPUT")
    REVIEWER_NAMES+=("$r")

    cat > "$REVIEWER_BRIEF" << RBRIEF_EOF
schema_version: 1
working_dir: ${WORK_DIR}

goal: You are acting as the ${r} reviewer. Read your agent definition, apply your specific review criteria to the changed files, and write your structured findings to ${REVIEWER_OUTPUT}.

files:
  - read: ${AGENT_PATH}
${DIFF_FILE_ENTRIES}  - new:  ${REVIEWER_OUTPUT}

constraints:
  - Do NOT modify any source file.
  - Only write ${REVIEWER_OUTPUT}. If and only if Reviewer=qa-tester, you may
    invoke the host-created QA helper named in context; do not write its
    checkpoint or log directly and do not run supplemental tests directly.
  - Before writing ${REVIEWER_OUTPUT}, call: ${GUARD_PMCTL_CMD} guard check --role reviewer --runtime ${EXECUTOR} --event pre-write --file ${REVIEWER_OUTPUT}
    If that call exits nonzero, abort and report the guard denial -- do NOT write the file.
  - If you need to test the PM Bash denylist with a command string containing
    destructive syntax, construct that string from shell variables (for
    example, separate command and flag variables) before passing it as data to
    pmctl. Never place a literal destructive invocation in the outer Bash
    command, and never execute the probe itself.
  - Create parent directories if needed (mkdir -p).
  - Only cite files in the verified reference index or the diff list. Read a file before citing its sections; do not invent citations.
  - reviewer_result_v1.verdict is the only machine verdict. A Markdown heading
    is optional presentation and may not act as a second output contract.

context:
  Tier: ${TIER}
  Executor: ${EXECUTOR}
  Reviewer: ${r}
  Base: ${BASE}${HEAD_METADATA_LINE}
  Scope: ${SCOPE:-none}
  Date: $(date '+%Y-%m-%d')
${GATE_ASSURANCE_CONTEXT_BLOCK}${SCOPE_MANIFEST_CONTEXT_BLOCK}${GATE_OVERRIDES_CONTEXT_BLOCK}${TEST_EVIDENCE_CONTEXT_BLOCK}${QA_EXECUTION_CONTEXT_BLOCK}
${REVIEWER_PROTOCOL_INSTRUCTIONS}
${MEMORY_CONTEXT_BLOCK}
  Verified reference files (exist in working tree -- check before citing):
${REPO_REF_INDEX}
  Diff (${LINES} changed lines):
${DIFF_STAT_INDENTED}

task:
  1. Read your agent definition (${AGENT_PATH}). Follow its boot instructions
     and internalize your specific review criteria and verdict scale.
  2. Review the changed files strictly from the ${r} perspective only.
     Do not attempt to cover other reviewer dimensions.
  3. Write a structured findings block with:
     - The complete mandatory reviewer_result_v1 coverage/finding JSON block
     - Optionally one human-readable heading:
       ## ${r} -- approve | advise | block-soft | block
     - One-sentence rationale for your verdict

  Write your complete review to ${REVIEWER_OUTPUT}.

output_format: |
  ## ${r} -- {verdict}
  \`\`\`reviewer_result_v1
  {one JSON object satisfying the selected-reviewer protocol above}
  \`\`\`

  The JSON verdict is canonical. Do not emit an upper-case Verdict: marker.

self_verify:
  - cmd: "test -f ${REVIEWER_OUTPUT}"

acceptance:
  - ${REVIEWER_OUTPUT} exists with exactly one reviewer_result_v1 JSON block
RBRIEF_EOF

    REVIEWER_DISPATCH_CMD="$(gate_dispatch_command "$EXECUTOR" "$REVIEWER_BRIEF" "$WORK_DIR" "$DISPATCH_MODEL" "$DISPATCH_SANDBOX" "$DISPATCH_APPROVAL" "$TIMEOUT" "$DISPATCH_ISOLATION" "$DISPATCH_EFFORT")" || exit 2
    eval "$REVIEWER_DISPATCH_CMD" > "$DISPATCH_LOG" 2>&1 &
    DISPATCH_PIDS+=($!)
    say '  [parallel] launched %s (pid %d)\n' "$r" "$!"
  done

  # Subprocess executors launched the reviewers as background children above;
  # wait for them, validate each output, then synthesize (all in-process).
  if [[ "$EXECUTOR_IS_SUBPROCESS" == true ]]; then
    say '\n  waiting for %d reviewer session(s)...\n' "${#DISPATCH_PIDS[@]}"

    # Watchdog: kill any reviewer subprocess that hasn't exited after the fan-out
    # timeout. Defense-in-depth: pmctl already passes --timeout to the executor,
    # but if pmctl itself hangs the inner timeout never fires. Watchdog timeout =
    # per-reviewer TIMEOUT + 60s overhead; override via _PM_DISPATCH_GATE_WATCHDOG_TIMEOUT.
    _GATE_WATCHDOG_TIMEOUT="${_PM_DISPATCH_GATE_WATCHDOG_TIMEOUT:-$((TIMEOUT + 60))}"
    (
      command -p sleep "$_GATE_WATCHDOG_TIMEOUT"
      for _wpid in "${DISPATCH_PIDS[@]}"; do
        _kill_process_tree "$_wpid" TERM
      done
    ) &
    _GATE_WATCHDOG_PID=$!

    # Wait for all reviewer sessions. Any non-zero exit aborts the gate -- an
    # incomplete review cannot certify a valid gate result.
    # Hash each reviewer output immediately after its PID exits so we capture
    # the content before any concurrently-running reviewer session can modify it.
    # Exit code > 128 means killed by signal (SIGTERM=143); attribute these as
    # timeouts (watchdog fired) rather than clean executor failures.
    FAILED_REVIEWERS=()
    TIMED_OUT_REVIEWERS=()
    REVIEWER_POST_WAIT_HASHES=()
    for i in "${!DISPATCH_PIDS[@]}"; do
      pid="${DISPATCH_PIDS[$i]}"
      r="${REVIEWER_NAMES[$i]}"
      rf="${REVIEWER_OUTPUT_FILES[$i]}"
      _wait_exit=0
      wait "$pid" || _wait_exit=$?
      if [[ "$_wait_exit" -ne 0 ]]; then
        [[ "$_wait_exit" -gt 128 ]] && TIMED_OUT_REVIEWERS+=("$r")
        FAILED_REVIEWERS+=("$r")
        REVIEWER_POST_WAIT_HASHES+=("none")
      else
        REVIEWER_POST_WAIT_HASHES+=("$(cat "$rf" 2>/dev/null | $_HASH_CMD || echo 'missing')")
      fi
    done

    # Kill watchdog if reviewers finished before the deadline.
    kill "$_GATE_WATCHDOG_PID" 2>/dev/null || true
    wait "$_GATE_WATCHDOG_PID" 2>/dev/null || true

    if [[ "${#TIMED_OUT_REVIEWERS[@]}" -gt 0 ]]; then
      printf 'Timeout: %d reviewer session(s) did not complete within %ds: %s\n' \
        "${#TIMED_OUT_REVIEWERS[@]}" "$_GATE_WATCHDOG_TIMEOUT" "${TIMED_OUT_REVIEWERS[*]}" >&2
    fi
    if [[ "${#FAILED_REVIEWERS[@]}" -gt 0 ]]; then
      printf 'Error: %d reviewer session(s) failed: %s\n' \
        "${#FAILED_REVIEWERS[@]}" "${FAILED_REVIEWERS[*]}" >&2
      printf 'The failed reviewer session(s) are eligible for one bounded recovery attempt.\n' >&2
    fi

    # Verify every reviewer wrote a non-empty output file -- a codex session can
    # exit 0 without completing its task, which would leave the synthesis brief
    # with nothing to consolidate and could produce a spurious GO.
    MISSING_OUTPUTS=()
    for i in "${!REVIEWER_OUTPUT_FILES[@]}"; do
      rf="${REVIEWER_OUTPUT_FILES[$i]}"
      r="${REVIEWER_NAMES[$i]}"
      if [[ ! -s "$rf" ]]; then
        MISSING_OUTPUTS+=("$r")
      fi
    done
    if [[ "${#MISSING_OUTPUTS[@]}" -gt 0 ]]; then
      printf 'Error: reviewer output missing or empty for: %s\n' "${MISSING_OUTPUTS[*]}" >&2
      printf 'A reviewer session may have exited 0 without writing its findings file.\n' >&2
      printf 'The missing reviewer output(s) are eligible for one bounded recovery attempt.\n' >&2
    fi

    # Validate the schema-complete reviewer contract before synthesis and read
    # its JSON verdict. Markdown headings are presentation only: duplicate or
    # omitted headings cannot turn a completed review into a protocol failure.
    PROTOCOL_INVALID_OUTPUTS=()
    PROTOCOL_INVALID_REASONS=()
    REVIEWER_VERDICTS=()
    for i in "${!REVIEWER_OUTPUT_FILES[@]}"; do
      rf="${REVIEWER_OUTPUT_FILES[$i]}"
      r="${REVIEWER_NAMES[$i]}"
      # CC-545: gate_reviewer_protocol_verify only clears/sets this global when
      # it reaches per-document verification; several of its own earlier
      # failure paths (duplicate reviewer, unclosed/missing block, ...) return
      # before ever touching it. Reset before each call so a prior reviewer's
      # leftover reason in this same loop can never be misattributed to this
      # one -- otherwise PROTOCOL_INVALID_REASONS below could wrongly read as
      # "evidence reference contract" and make an unrelated failure eligible
      # for the CC-545 corrective retry.
      GATE_REVIEWER_PROTOCOL_DOCUMENT_ERROR=""
      if [[ " ${FAILED_REVIEWERS[*]:-} " == *" $r "* ]]; then
        PROTOCOL_INVALID_OUTPUTS+=("$r")
        PROTOCOL_INVALID_REASONS+=("transport failure")
        _gate_protocol_attempt_record reviewer "$r" 1 retryable-failure \
          "transport failure" "$rf" || exit 2
      elif [[ ! -s "$rf" ]]; then
        PROTOCOL_INVALID_OUTPUTS+=("$r")
        PROTOCOL_INVALID_REASONS+=("missing reviewer result")
        _gate_protocol_attempt_record reviewer "$r" 1 retryable-failure \
          "missing reviewer result" "$rf" || exit 2
      elif gate_reviewer_protocol_verify \
          "$rf" "$r" "$SCOPE_MANIFEST_DIGEST" "$SCOPE_MANIFEST_PATH" true \
          && reviewer_verdict="$(
            _gate_reviewer_protocol_verdict_extract "$rf" "$r"
          )"; then
        REVIEWER_VERDICTS+=("$reviewer_verdict")
        _gate_protocol_attempt_record reviewer "$r" 1 accepted ok "$rf" || exit 2
      else
        PROTOCOL_INVALID_OUTPUTS+=("$r")
        PROTOCOL_INVALID_REASONS+=("${GATE_REVIEWER_PROTOCOL_DOCUMENT_ERROR:-<other>}")
        _gate_protocol_attempt_record reviewer "$r" 1 retryable-failure \
          "${GATE_REVIEWER_PROTOCOL_DOCUMENT_ERROR:-<other>}" "$rf" || exit 2
      fi
    done

    # CC-521: retry exactly once for transport-shaped or machine-contract
    # failures. Never retry stale subject binding or analysis uncertainty: the
    # former invalidates the immutable review subject and the latter is valid
    # review evidence that synthesis must preserve.
    _GATE_RETRYABLE_PROTOCOL_REASONS=(
      "invalid evidence reference contract"
      "transport failure"
      "invalid JSON document"
      "malformed reviewer result fence"
      "truncated reviewer result"
      "missing reviewer result"
      "invalid reviewer binding"
      "missing selected reviewer"
      "invalid top-level or binding contract"
      "invalid coverage contract"
      "invalid finding contract"
      "invalid test-gap matrix contract"
      "finding lacks actionable test-gap row"
      "invalid verdict contract"
    )
    if [[ "${#PROTOCOL_INVALID_OUTPUTS[@]}" -gt 0 ]]; then
      _RETRY_ELIGIBLE=true
      for _reason in "${PROTOCOL_INVALID_REASONS[@]}"; do
        _reason_retryable=false
        for _retryable in "${_GATE_RETRYABLE_PROTOCOL_REASONS[@]}"; do
          [[ "$_reason" == "$_retryable" ]] && { _reason_retryable=true; break; }
        done
        [[ "$_reason_retryable" == true ]] || { _RETRY_ELIGIBLE=false; break; }
      done
      if [[ "$_RETRY_ELIGIBLE" == true ]]; then
        say '\n  %d reviewer(s) failed a retryable reviewer protocol contract; retrying once with a corrective note: %s\n' \
          "${#PROTOCOL_INVALID_OUTPUTS[@]}" "${PROTOCOL_INVALID_OUTPUTS[*]}"
        _RETRY_REF_INDEX_JSON="$(
          _gate_reviewer_protocol_reference_index_json \
            "$SCOPE_MANIFEST_PATH" "$SCOPE_MANIFEST_DIGEST" 2>/dev/null
        )" || _RETRY_REF_INDEX_JSON=null

        _RETRY_PIDS=()
        _RETRY_NAMES=()
        _RETRY_OUTPUT_FILES=()
        _RETRY_POST_WAIT_HASHES=()
        for r in "${PROTOCOL_INVALID_OUTPUTS[@]}"; do
          # Find this reviewer's already-failed output file to extract its
          # specific bad citation(s); best-effort only -- an extraction
          # failure still retries, just with the generic reminder alone.
          _retry_orig_rf=""
          for i in "${!REVIEWER_NAMES[@]}"; do
            [[ "${REVIEWER_NAMES[$i]}" == "$r" ]] && { _retry_orig_rf="${REVIEWER_OUTPUT_FILES[$i]}"; break; }
          done
          _retry_bad_citations=""
          if [[ -n "$_retry_orig_rf" && "$_RETRY_REF_INDEX_JSON" != null ]]; then
            _retry_bad_citations="$(
              _gate_reviewer_protocol_documents "$_retry_orig_rf" 2>/dev/null | jq -rs --argjson refs "$_RETRY_REF_INDEX_JSON" '
                def bound($r):
                  ($r.path) as $p | ($r.line // null) as $ln |
                  (($refs[] | select(.path == $p)) // null) as $e |
                  { path: $p, line: $ln, ok: ( ($e != null) and ($ln == null or $ln <= $e.line_count) ) };
                (.[0] // {}) as $d |
                [ ($d.coverage[]?.evidence_refs[]? // empty), ($d.findings[]?.source? // empty) ]
                | map(bound(.)) | map(select(.ok == false))
                | map("    - " + .path + (if .line then (":" + (.line|tostring)) else "" end) +
                    " is not in the declared scope manifest reference index (or exceeds its recorded line count)")
                | .[]
              ' 2>/dev/null
            )" || _retry_bad_citations=""
          fi

          _RETRY_TS="${TIMESTAMP}-retry1"
          _RETRY_OUTPUT="$WORK_DIR/.gate-results/reviewer-${r}-${_RETRY_TS}.md"
          _RETRY_BRIEF="$BRIEF_DIR/pr-gate-${_RETRY_TS}-${r}.md"
          _RETRY_LOG="$_ARTIFACT_ROOT/.agent-trace/gate-${_RETRY_TS}-${r}.log"
          AGENT_PATH="$REVIEWER_DEFINITION_DIR/${r}.md"

          cat > "$_RETRY_BRIEF" << RETRY_RBRIEF_EOF
schema_version: 1
working_dir: ${WORK_DIR}

goal: You are acting as the ${r} reviewer. This is a corrective retry of a
  prior review that failed a machine-validated output contract -- your job is
  the same review, done carefully enough to satisfy that contract this time.
  Read your agent definition, apply your specific review criteria to the
  changed files, and write your structured findings to ${_RETRY_OUTPUT}.

correction: |
  Your previous submission for this diff failed the mandatory reviewer
  protocol (${GATE_REVIEWER_PROTOCOL_DOCUMENT_ERROR:-schema failure}). Re-emit
  the complete result from the same immutable subject. In particular, every
  coverage evidence_refs[], test_gaps[].existing_evidence[], and finding
  source must cite a path that is EXACTLY one of the declared scope-manifest
  reference-index paths below (not merely a real file on disk -- an in-scope
  or adjacent-but-undeclared file is still a protocol failure), and any line
  number must not exceed that path's recorded line count.
${_retry_bad_citations:+  Specifically rejected citation(s) from your previous submission:
$_retry_bad_citations
}
  Before writing each citation this time, re-read the exact path spelling
  character-by-character against the reference index -- similarly-named
  files in this diff (e.g. run-tests.sh vs run-all-tests.sh, or
  test-run-tests.sh vs test-run-all-tests.sh) are a known source of this
  mistake.

files:
  - read: ${AGENT_PATH}
${DIFF_FILE_ENTRIES}  - new:  ${_RETRY_OUTPUT}

constraints:
  - Do NOT modify any source file.
  - Only write ${_RETRY_OUTPUT}. If and only if Reviewer=qa-tester, you may
    invoke the host-created QA helper named in context; do not write its
    checkpoint or log directly and do not run supplemental tests directly.
  - Before writing ${_RETRY_OUTPUT}, call: ${GUARD_PMCTL_CMD} guard check --role reviewer --runtime ${EXECUTOR} --event pre-write --file ${_RETRY_OUTPUT}
    If that call exits nonzero, abort and report the guard denial -- do NOT write the file.
  - Create parent directories if needed (mkdir -p).
  - Only cite files in the verified reference index or the diff list. Read a file before citing its sections; do not invent citations.
  - reviewer_result_v1.verdict is the only machine verdict. A Markdown heading
    is optional presentation and may not act as a second output contract.

context:
  Tier: ${TIER}
  Executor: ${EXECUTOR}
  Reviewer: ${r}
  Base: ${BASE}${HEAD_METADATA_LINE}
  Scope: ${SCOPE:-none}
  Date: $(date '+%Y-%m-%d')
${GATE_ASSURANCE_CONTEXT_BLOCK}${SCOPE_MANIFEST_CONTEXT_BLOCK}${GATE_OVERRIDES_CONTEXT_BLOCK}${TEST_EVIDENCE_CONTEXT_BLOCK}${QA_EXECUTION_CONTEXT_BLOCK}
${REVIEWER_PROTOCOL_INSTRUCTIONS}
${MEMORY_CONTEXT_BLOCK}
  Verified reference files (exist in working tree -- check before citing):
${REPO_REF_INDEX}
  Diff (${LINES} changed lines):
${DIFF_STAT_INDENTED}

task:
  1. Read your agent definition (${AGENT_PATH}). Follow its boot instructions
     and internalize your specific review criteria and verdict scale.
  2. Review the changed files strictly from the ${r} perspective only.
     Do not attempt to cover other reviewer dimensions.
  3. Write a structured findings block with:
     - The complete mandatory reviewer_result_v1 coverage/finding JSON block
     - Optionally one human-readable heading:
       ## ${r} -- approve | advise | block-soft | block
     - One-sentence rationale for your verdict

  Write your complete review to ${_RETRY_OUTPUT}.

output_format: |
  ## ${r} -- {verdict}
  \`\`\`reviewer_result_v1
  {one JSON object satisfying the selected-reviewer protocol above}
  \`\`\`

  The JSON verdict is canonical. Do not emit an upper-case Verdict: marker.

self_verify:
  - cmd: "test -f ${_RETRY_OUTPUT}"

acceptance:
  - ${_RETRY_OUTPUT} exists with exactly one reviewer_result_v1 JSON block
RETRY_RBRIEF_EOF

          _RETRY_DISPATCH_CMD="$(gate_dispatch_command "$EXECUTOR" "$_RETRY_BRIEF" "$WORK_DIR" "$DISPATCH_MODEL" "$DISPATCH_SANDBOX" "$DISPATCH_APPROVAL" "$TIMEOUT" "$DISPATCH_ISOLATION" "$DISPATCH_EFFORT")" || exit 2
          eval "$_RETRY_DISPATCH_CMD" > "$_RETRY_LOG" 2>&1 &
          _RETRY_PIDS+=($!)
          _RETRY_NAMES+=("$r")
          _RETRY_OUTPUT_FILES+=("$_RETRY_OUTPUT")
          say '  [retry] launched %s (pid %d)\n' "$r" "$!"
        done

        _RETRY_WATCHDOG_TIMEOUT="${_PM_DISPATCH_GATE_WATCHDOG_TIMEOUT:-$((TIMEOUT + 60))}"
        (
          command -p sleep "$_RETRY_WATCHDOG_TIMEOUT"
          for _wpid in "${_RETRY_PIDS[@]}"; do
            _kill_process_tree "$_wpid" TERM
          done
        ) &
        _RETRY_WATCHDOG_PID=$!

        _RETRY_FAILED_PIDS=()
        for i in "${!_RETRY_PIDS[@]}"; do
          _retry_wait_exit=0
          wait "${_RETRY_PIDS[$i]}" || _retry_wait_exit=$?
          if [[ "$_retry_wait_exit" -ne 0 ]]; then
            _RETRY_FAILED_PIDS+=("${_RETRY_NAMES[$i]}")
            _RETRY_POST_WAIT_HASHES+=("none")
          else
            _RETRY_POST_WAIT_HASHES+=("$(cat "${_RETRY_OUTPUT_FILES[$i]}" 2>/dev/null | $_HASH_CMD || echo 'missing')")
          fi
        done
        kill "$_RETRY_WATCHDOG_PID" 2>/dev/null || true
        wait "$_RETRY_WATCHDOG_PID" 2>/dev/null || true

        _retry_artifact_check_args=()
        for i in "${!_RETRY_OUTPUT_FILES[@]}"; do
          _retry_artifact_check_args+=("${_RETRY_NAMES[$i]}" "${_RETRY_OUTPUT_FILES[$i]}" "${_RETRY_POST_WAIT_HASHES[$i]}")
        done
        mapfile -t _RETRY_TAMPERED < <(verify_reviewer_artifact_hashes "$_HASH_CMD" "${_retry_artifact_check_args[@]}")

        # Re-verify the retry batch and fold recovered reviewers back into
        # the main REVIEWER_OUTPUT_FILES/REVIEWER_VERDICTS bookkeeping so the
        # rest of the pipeline (worktree integrity, synthesis) sees one
        # consistent set. A reviewer that still fails -- even after retry --
        # falls through to the same INCOMPLETE exit as before, unretried.
        PROTOCOL_INVALID_OUTPUTS=()
        for i in "${!_RETRY_OUTPUT_FILES[@]}"; do
          r="${_RETRY_NAMES[$i]}"
          rf="${_RETRY_OUTPUT_FILES[$i]}"
          if [[ " ${_RETRY_FAILED_PIDS[*]:-} " == *" $r "* ]] || \
             [[ " ${_RETRY_TAMPERED[*]:-} " == *" $r "* ]] || \
             [[ ! -s "$rf" ]] || \
             ! gate_reviewer_protocol_verify \
               "$rf" "$r" "$SCOPE_MANIFEST_DIGEST" "$SCOPE_MANIFEST_PATH" true \
             || ! reviewer_verdict="$(_gate_reviewer_protocol_verdict_extract "$rf" "$r")"; then
            PROTOCOL_INVALID_OUTPUTS+=("$r")
            _gate_protocol_attempt_record reviewer "$r" 2 exhausted \
              "${GATE_REVIEWER_PROTOCOL_DOCUMENT_ERROR:-transport or protocol failure}" "$rf" || exit 2
            printf 'Error: retry still failed for %s\n' "$r" >&2
            continue
          fi
          REVIEWER_VERDICTS+=("$reviewer_verdict")
          for j in "${!REVIEWER_NAMES[@]}"; do
            if [[ "${REVIEWER_NAMES[$j]}" == "$r" ]]; then
              REVIEWER_OUTPUT_FILES[j]="$rf"
              # The cross-tamper check below compares REVIEWER_POST_WAIT_HASHES
              # against a fresh re-hash of REVIEWER_OUTPUT_FILES; since that now
              # points at the retry file, its baseline must move to the retry's
              # own post-wait hash, or an untampered recovered reviewer would
              # always appear "modified after completion" against the original
              # (now-superseded) attempt's hash.
              REVIEWER_POST_WAIT_HASHES[j]="${_RETRY_POST_WAIT_HASHES[$i]}"
              break
            fi
          done
          say '  [retry] %s recovered on retry.\n' "$r"
          _gate_protocol_attempt_record reviewer "$r" 2 recovered ok "$rf" || exit 2
        done
      fi
    fi

    if [[ "${#PROTOCOL_INVALID_OUTPUTS[@]}" -gt 0 ]]; then
      printf 'Error: reviewer protocol INCOMPLETE for: %s\n' \
        "${PROTOCOL_INVALID_OUTPUTS[*]}" >&2
      printf 'Every selected reviewer must complete the declared-surface checklist and actionable finding contract.\n' >&2
      exit 1
    fi

    # Cross-reviewer artifact tamper detection: re-hash every reviewer output and
    # compare with the hash captured immediately after that reviewer's PID exited.
    # A mismatch means a concurrently-running reviewer session modified this file
    # after it was completed -- fail closed before synthesis can run on tainted data.
    _artifact_check_args=()
    for i in "${!REVIEWER_OUTPUT_FILES[@]}"; do
      rf="${REVIEWER_OUTPUT_FILES[$i]}"
      r="${REVIEWER_NAMES[$i]}"
      expected="${REVIEWER_POST_WAIT_HASHES[$i]}"
      _artifact_check_args+=("$r" "$rf" "$expected")
    done
    mapfile -t CROSS_TAMPERED < <(verify_reviewer_artifact_hashes "$_HASH_CMD" "${_artifact_check_args[@]}")
    if [[ "${#CROSS_TAMPERED[@]}" -gt 0 ]]; then
      printf 'Error: reviewer artifact modified after that reviewer session completed: %s\n' "${CROSS_TAMPERED[*]}" >&2
      printf 'Possible cross-reviewer artifact tampering in --parallel mode. Gate aborted.\n' >&2
      exit 1
    fi

  # Worktree integrity check -- detect prompt-injected tracked-file modifications.
  # Content-hash catches mutations to already-dirty tracked files; status hash
  # catches new untracked source files. Gate artifacts are excluded explicitly via
  # artifact_filter_porcelain (runtime/lib/artifact-paths.sh) -- the pre/post sides
  # MUST use the same filter or the hashes can never match. -z keeps special filenames intact.
  _POST_DISPATCH_DIFF=$(git diff HEAD 2>/dev/null | $_HASH_CMD)
  _POST_DISPATCH_STATUS=$(git status --porcelain -z 2>/dev/null | artifact_filter_porcelain | $_HASH_CMD)
  if [[ "$_PRE_DISPATCH_DIFF" != "$_POST_DISPATCH_DIFF" || "$_PRE_DISPATCH_STATUS" != "$_POST_DISPATCH_STATUS" ]]; then
    printf 'Error: reviewer sessions modified working tree -- possible prompt injection.\n' >&2
    printf 'Gate aborted. Inspect the reviewer dispatch logs under .agent-trace/ for details.\n' >&2
    exit 1
  fi

  # Reviewer artifact integrity -- snapshot each reviewer output file content now,
  # before synthesis, to detect synthesis-side tampering of reviewer artifacts.
  # Reviewer outputs are gitignored and not covered by the worktree hash above.
  REVIEWER_ARTIFACT_HASHES=()
  for rf in "${REVIEWER_OUTPUT_FILES[@]}"; do
    REVIEWER_ARTIFACT_HASHES+=("$(cat "$rf" | $_HASH_CMD)")
  done

  say '  all reviewer sessions done.\n\n'

  # Compute the final verdict deterministically in shell before synthesis.
  # Synthesis is treated as prose-only; the shell verdict is the authoritative gate result.
  SHELL_VERDICT="approve"
  for rv in "${REVIEWER_VERDICTS[@]}"; do
    case "$rv" in
      block) SHELL_VERDICT="block" ;;
      block-soft) [[ "$SHELL_VERDICT" != "block" ]] && SHELL_VERDICT="block-soft" ;;
      advise) [[ "$SHELL_VERDICT" == "approve" ]] && SHELL_VERDICT="advise" ;;
    esac
  done
  if [[ "$SHELL_VERDICT" == "approve" || "$SHELL_VERDICT" == "advise" ]]; then
    SHELL_FINAL="GO"
  else
    SHELL_FINAL="NO-GO"
  fi

  # ── PM synthesis ─────────────────────────────────────────────────────────────

  # Write synthesis brief in segments so reviewer content is appended with `cat`
  # (no heredoc expansion) rather than embedded in an unquoted heredoc.
  # This also removes `read:` file paths from the brief, preventing the synthesis
  # session from discovering or targeting reviewer output file locations.

  cat > "$SYNTHESIS_BRIEF" << SBRIEF_P1
schema_version: 1
working_dir: ${WORK_DIR}

goal: You are project-pm. Synthesize the reviewer findings provided in the context below and write a final consolidated PR-gate result at ${OUTPUT_FILE}.

files:
  - new:  ${OUTPUT_FILE}

constraints:
  - Do NOT modify any source file.
  - Only write ${OUTPUT_FILE}.
  - Before your FIRST write to ${OUTPUT_FILE} in this session, call: ${GUARD_PMCTL_CMD} guard check --role reviewer --runtime ${EXECUTOR} --event pre-write --file ${OUTPUT_FILE}
    If that call exits nonzero, abort and report the guard denial -- do NOT write the file.
  - Create parent directories if needed (mkdir -p).
  - The Gate Conclusion MUST contain exactly: Final: ${SHELL_FINAL}
    This is pre-computed from the reviewer verdicts and must not be overridden.
  - Only cite files in the verified reference index or reviewer findings; do not invent citations.
  - Do not emit or copy any reviewer_result_v1 fenced block. The gate shell
    validates and appends the original reviewer protocol blocks after synthesis.
  - Write a self-contained staging frontmatter with exactly
    gate_result_version: pr_gate_result_v1 and no gate_assurance field. The gate
    shell owns the final result version and bounded assurance pointer and
    publishes them only after reviewer and synthesis verification.

context:
  Tier: ${TIER}
  Executor: ${EXECUTOR}
  Reviewers: ${REVIEWER_DISPLAY}
  Not reviewed: ${SKIPPED_DISPLAY}
  Base: ${BASE}${HEAD_METADATA_LINE}
  Scope: ${SCOPE:-none}
  Date: $(date '+%Y-%m-%d')
${GATE_ASSURANCE_CONTEXT_BLOCK}${SCOPE_MANIFEST_CONTEXT_BLOCK}${GATE_OVERRIDES_CONTEXT_BLOCK}${TEST_EVIDENCE_CONTEXT_BLOCK}
${SYNTHESIS_PROTOCOL_INSTRUCTIONS}
${TARGETED_REMEDIATION_CONTEXT_BLOCK}
  Verified reference files (exist in working tree -- check before citing):
${REPO_REF_INDEX}
  Reviewer findings (embedded -- do NOT attempt to read any external reviewer output file):
SBRIEF_P1

  for i in "${!REVIEWER_OUTPUT_FILES[@]}"; do
    rf="${REVIEWER_OUTPUT_FILES[$i]}"
    r="${REVIEWER_NAMES[$i]}"
    printf '  --- %s findings ---\n' "$r" >> "$SYNTHESIS_BRIEF"
    if [[ -s "$rf" ]]; then
      cat "$rf" >> "$SYNTHESIS_BRIEF"
    else
      printf '  (reviewer output unavailable)\n' >> "$SYNTHESIS_BRIEF"
    fi
    printf '\n' >> "$SYNTHESIS_BRIEF"
  done

  cat >> "$SYNTHESIS_BRIEF" << SBRIEF_P2

task:
  1. Use the reviewer findings embedded in the context above.
  2. Build the deterministic finding inventory, coverage matrix, and test-gap
     matrix from every reviewer_result_v1 block. Preserve all IDs, rows, and
     verification expectations.
  3. Group findings by root cause without dropping or merging stable IDs, and record
     disagreements, uncertainties, cautions, and not-reviewed dimensions.
  4. Emit the complete synthesis_result_v1 JSON block and remediation seed.
  5. Determine the overall verdict: most severe individual verdict across all reviewers
     (approve < advise < block-soft < block).
  6. State Final: GO or NO-GO.
     - GO:    no reviewer returned block or block-soft.
     - NO-GO: any reviewer returned block or block-soft. List required fixes and
              any applicable override path.
  7. Write the complete consolidated result to ${OUTPUT_FILE}.

output_format: |
  ---
  gate_result_version: pr_gate_result_v1
  final: GO|NO-GO
  tier: ${TIER}
  mode: ${MODE_RESOLVED}
  most_severe: approve|advise|block-soft|block
  reviewers:
    critic: approve|advise|block-soft|skipped
    qa-tester: pass|needs-tests|block|skipped
    architecture-reviewer: approve|advise|block-soft|skipped
    security-reviewer: pass|block|pass-not-applicable|skipped
    risk-reviewer: pass|block|pass-not-applicable|skipped
  escalation:
    recommended: true|false
    reviewers: []
    reason: []
  ---

  # PR-Gate Result -- ${TIER} tier (parallel ${EXECUTOR} mode)
  **Date**: $(date '+%Y-%m-%d')
  **Reviewers**: ${REVIEWER_DISPLAY}
  **Not reviewed**: ${SKIPPED_DISPLAY}

  \`\`\`synthesis_result_v1
  {one JSON object satisfying the synthesis protocol above}
  \`\`\`

  ## {reviewer-name} -- {verdict}
  {Summarize findings from that reviewer, one bullet per finding with stable ID,
  severity, and file:line. Do not copy the reviewer_result_v1 fenced block.}

  Verdict: {verdict from reviewer findings}. {rationale}

  (repeat for each reviewer in order)

  ## Cross-Reviewer Overlaps
  {list issues raised by more than one reviewer; "none" if clean}

  ## Must-Fix Order
  {ordered blocking findings by stable ID; "none" if clean}

  ## Advisory and Cautions
  {all non-blocking findings and cautions by stable ID; "none" if clean}

  ## Coverage Gaps and Uncertainties
  **Dimensions not covered**: ${SKIPPED_DISPLAY}
  {all uncertain coverage cells/findings; "none" if complete}

  ## Test Coverage to Add or Strengthen
  {every status=gap test-gap row, grouped by missing layer; "none" if all rows are no_gap}

  ## Operational and User Cautions
  {render operational_cautions and user_cautions separately; "none" for an empty array}

  ## Post-Fix Verification Plan
  {render focused, manual, and full commands/checks separately}

  ## Recommended Verification
  {verification expectations grouped without dropping any stable finding ID;
  "none" if there are no findings}

  ## Gate Conclusion
  **Overall verdict**: {most severe across all reviewers}
  **Most severe individual verdict**: {most severe}
  Final: GO|NO-GO
  {required fixes if NO-GO; override path if any block or block-soft}

  CRITICAL -- the Final: line above MUST be emitted EXACTLY in this shape:
  - plain text, no markdown emphasis (NO surrounding **, NO backticks, NO italic)
  - at start of line (no leading whitespace)
  - literal token GO or NO-GO (uppercase, hyphen for NO-GO)
  - matched by the regex ^Final: (GO|NO-GO)\$
  - the value MUST equal the frontmatter \`final:\` field (case-sensitive)
  Examples that BREAK the parser and MUST NOT be emitted: \`**Final: GO**\`, \`Final: **GO**\`, \` Final: GO\`, \`Final: Go\`.

  ## Escalation
  **Recommended**: true|false
  **Reviewers**: <comma-list or "none">
  **Reason**:
  - <bullet> (or "none" when recommended=false)

  Escalation is recommended when:
  (a) policy.escalation_signals above is non-empty; use this canonical resolver
      output and do not re-match paths with a separate regex
  (b) at least one reviewer returned advise|block-soft.

  Recommended follow-ups:
  {non-blocking improvements from advise-level findings, if any}

  Rationale: {1-2 sentences explaining the final verdict}

self_verify:
  - cmd: "test -f ${OUTPUT_FILE}"
  - has-final: grep -cE '^Final: (GO|NO-GO)\$' ${OUTPUT_FILE} should be exactly 1
  - frontmatter-final-parity: the value after \`final:\` in the YAML frontmatter MUST equal the value after \`Final:\` in Gate Conclusion (case-sensitive)
  - all-reviewers-present: output must contain a section header for each of: ${REVIEWER_DISPLAY}

acceptance:
  - ${OUTPUT_FILE} exists with a section for each of the ${NUM_REVIEWERS} reviewers
  - exactly one synthesis_result_v1 block preserves reviewer finding and coverage parity
  - Must-Fix Order / Advisory and Cautions / Coverage Gaps and Uncertainties /
    Test Coverage to Add or Strengthen / Operational and User Cautions /
    Post-Fix Verification Plan / Recommended Verification sections are present exactly once
  - "Final: GO" or "Final: NO-GO" is present in Gate Conclusion (plain text, no markdown emphasis)
SBRIEF_P2

  _SYNTHESIS_COMPLETE=false
  for _synthesis_attempt in 1 2; do
    if [[ "$_synthesis_attempt" -eq 2 ]]; then
      cat >> "$SYNTHESIS_BRIEF" <<'SYNTHESIS_RETRY_EOF'

correction_retry: |
  The first synthesis attempt failed a transport, malformed-output, schema, or
  parity check. Rebuild the complete staging result from the same embedded,
  immutable reviewer_result_v1 documents. Do not omit any test_gap_matrix row.
SYNTHESIS_RETRY_EOF
    fi
    say '  [synthesis attempt %d] running PM consolidation...\n' "$_synthesis_attempt"
    SYNTHESIS_DISPATCH_CMD="$(gate_dispatch_command "$EXECUTOR" "$SYNTHESIS_BRIEF" "$WORK_DIR" "$DISPATCH_MODEL" "$DISPATCH_SANDBOX" "$DISPATCH_APPROVAL" "$TIMEOUT" "$DISPATCH_ISOLATION" "$DISPATCH_EFFORT")" || exit 2
    eval "$SYNTHESIS_DISPATCH_CMD" >&2 &
    _SYNTHESIS_PID=$!
    _GATE_SYNTHESIS_WATCHDOG_TIMEOUT="${_PM_DISPATCH_GATE_SYNTHESIS_WATCHDOG_TIMEOUT:-$((TIMEOUT + 60))}"
    (
      command -p sleep "$_GATE_SYNTHESIS_WATCHDOG_TIMEOUT"
      _kill_process_tree "$_SYNTHESIS_PID" TERM
    ) &
    _SYNTHESIS_WATCHDOG_PID=$!
    _synthesis_exit=0
    wait "$_SYNTHESIS_PID" || _synthesis_exit=$?
    kill "$_SYNTHESIS_WATCHDOG_PID" 2>/dev/null || true
    wait "$_SYNTHESIS_WATCHDOG_PID" 2>/dev/null || true

    # A retryable synthesis failure must never mask reviewer-artifact or
    # working-tree tampering. Check those immutable inputs after every attempt.
    TAMPERED_ARTIFACTS=()
    for i in "${!REVIEWER_OUTPUT_FILES[@]}"; do
      rf="${REVIEWER_OUTPUT_FILES[$i]}"
      r="${REVIEWER_NAMES[$i]}"
      current_hash="$(cat "$rf" | $_HASH_CMD)"
      if [[ "${REVIEWER_ARTIFACT_HASHES[$i]}" != "$current_hash" ]]; then
        TAMPERED_ARTIFACTS+=("$r")
      fi
    done
    if [[ "${#TAMPERED_ARTIFACTS[@]}" -gt 0 ]]; then
      printf 'Error: reviewer artifact(s) modified after review phase -- synthesis-side tampering detected: %s\n' \
        "${TAMPERED_ARTIFACTS[*]}" >&2
      exit 1
    fi
    _POST_SYNTHESIS_DIFF=$(git diff HEAD 2>/dev/null | $_HASH_CMD)
    _POST_SYNTHESIS_STATUS=$(git status --porcelain -z 2>/dev/null | artifact_filter_porcelain | $_HASH_CMD)
    if [[ "$_POST_DISPATCH_DIFF" != "$_POST_SYNTHESIS_DIFF" || "$_POST_DISPATCH_STATUS" != "$_POST_SYNTHESIS_STATUS" ]]; then
      printf 'Error: synthesis session modified working tree -- possible prompt injection.\n' >&2
      exit 1
    fi

    _synthesis_reason=""
    if [[ "$_synthesis_exit" -gt 128 ]]; then
      _synthesis_reason="transport timeout"
      printf 'Timeout: synthesis attempt %d did not complete within %ds\n' \
        "$_synthesis_attempt" "$_GATE_SYNTHESIS_WATCHDOG_TIMEOUT" >&2
    elif [[ "$_synthesis_exit" -ne 0 ]]; then
      _synthesis_reason="transport failure"
      printf 'Error: synthesis attempt %d failed (exit %d)\n' \
        "$_synthesis_attempt" "$_synthesis_exit" >&2
    elif ! gate_result_staging_normalize "$OUTPUT_FILE" "PM synthesis"; then
      _synthesis_reason="malformed staging result"
    elif ! gate_result_verify "$OUTPUT_FILE" "$SHELL_FINAL" "PM synthesis"; then
      _synthesis_reason="invalid staging result"
    else
      _gate_reviewer_protocol_append_blocks \
        "$OUTPUT_FILE" "${REVIEWER_OUTPUT_FILES[@]}" || exit 1
      gate_reviewer_protocol_verify \
        "$OUTPUT_FILE" "$REVIEWERS" "$SCOPE_MANIFEST_DIGEST" \
        "$SCOPE_MANIFEST_PATH" true || exit 1
      if gate_synthesis_protocol_verify \
          "$OUTPUT_FILE" "$REVIEWERS" "$SKIPPED_WORDS" \
          "$SCOPE_MANIFEST_DIGEST" true; then
        _SYNTHESIS_COMPLETE=true
      else
        _synthesis_reason="${GATE_SYNTHESIS_PROTOCOL_ERROR:-synthesis parity failure}"
      fi
    fi

    if [[ "$_SYNTHESIS_COMPLETE" == true ]]; then
      _gate_protocol_attempt_record synthesis "" "$_synthesis_attempt" \
        accepted ok "$OUTPUT_FILE" || exit 2
      break
    fi
    if [[ "$_synthesis_reason" == "stale subject binding" ]]; then
      _gate_protocol_attempt_record synthesis "" "$_synthesis_attempt" stale \
        "$_synthesis_reason" "$OUTPUT_FILE" || exit 2
      printf 'Error: synthesis subject is stale; refusing protocol retry\n' >&2
      exit 1
    fi
    if [[ "$_synthesis_attempt" -eq 1 ]]; then
      _gate_protocol_attempt_record synthesis "" 1 retryable-failure \
        "$_synthesis_reason" "$OUTPUT_FILE" || exit 2
      say '  [synthesis] retrying once after %s.\n' "$_synthesis_reason"
    else
      _gate_protocol_attempt_record synthesis "" 2 exhausted \
        "$_synthesis_reason" "$OUTPUT_FILE" || exit 2
      printf 'Error: synthesis recovery exhausted after %s\n' "$_synthesis_reason" >&2
      exit 1
    fi
  done
  # shellcheck disable=SC2034 # consumed by the canonical assurance module
  REVIEWER_PROTOCOL_COMPLETE=true
  # shellcheck disable=SC2034 # consumed by the canonical assurance module
  SYNTHESIS_PROTOCOL_COMPLETE=true
  fi

fi

fi

# ── Pre-flight test result: mechanical override (CC-470 Part 3) ────────────────
# Applies AFTER dispatch (sequential or parallel) and its own gate_result_verify
# have already succeeded -- this is the single point where both routes converge,
# so the tagging logic lives here once instead of duplicated per route (same
# shape as the override provenance block immediately below, which is the
# established precedent for "shared post-dispatch bash processing of OUTPUT_FILE").
# Only ever called with status=pass: a FAIL never reaches dispatch at all (see
# the fail-fast short-circuit above, which synthesizes its own NO-GO result and
# never invokes any reviewer) -- this just tags the mechanical fact "pre-flight
# already confirmed the suite passes" onto whatever the reviewers produced,
# without touching final:/Final: (reviewers' own verdict stands).
verify_preflight_artifacts_current() {
  local current_evidence current_log expected_log coverage_type current_tree rich_path expected_rich current_rich
  current_evidence="$(_preflight_sha256_file "$PREFLIGHT_EVIDENCE_PATH")" || return 1
  [[ "$current_evidence" == "$PREFLIGHT_EVIDENCE_DIGEST" ]] || {
    printf 'Error: pre-flight evidence artifact was modified after verification\n' >&2; return 1;
  }
  expected_log="$(jq -r '.log.sha256' "$PREFLIGHT_EVIDENCE_PATH")"
  current_log="$(_preflight_sha256_file "$PREFLIGHT_LOG_PATH")" || return 1
  [[ "$current_log" == "$expected_log" ]] || {
    printf 'Error: pre-flight log artifact was modified after verification\n' >&2; return 1;
  }
  coverage_type="$(jq -r '.coverage.type' "$PREFLIGHT_EVIDENCE_PATH")"
  if [[ "$coverage_type" == structured ]]; then
    rich_path="$PREFLIGHT_RICH_RESULT_PATH"
    expected_rich="$(jq -r '.coverage.artifact_sha256' "$PREFLIGHT_EVIDENCE_PATH")"
    current_rich="$(_preflight_sha256_file "$rich_path")" || return 1
    [[ "$current_rich" == "$expected_rich" ]] || {
      printf 'Error: structured pre-flight result was modified after verification\n' >&2; return 1;
    }
  fi
  current_tree="$(_preflight_tree_fingerprint)" || return 1
  [[ "$current_tree" == "$(jq -r '.subject.fingerprint_before' "$PREFLIGHT_EVIDENCE_PATH")" ]] || {
    printf 'Error: pre-flight evidence is stale for the current subject\n' >&2; return 1;
  }
}

gate_apply_preflight_pass_tag() {
  local result_file="$1" evidence_path
  evidence_path="$(_preflight_log_display_path "$PREFLIGHT_EVIDENCE_PATH")"
  awk -v evidence_path="$evidence_path" -v evidence_digest="$PREFLIGHT_EVIDENCE_DIGEST" '
    /^---$/ {
      if (fence < 2) fence++
      if (fence == 2 && !ts_done) {
        print "test_suite: pass"
        print "test_evidence: " evidence_path
        print "test_evidence_sha256: " evidence_digest
        ts_done=1
      }
      print; next
    }
    { print }
  ' "$result_file" > "${result_file}.preflight-tmp"
  mv "${result_file}.preflight-tmp" "$result_file"

  # Self-check: if this rewrite corrupted frontmatter/body parity, fail closed
  # rather than let a broken result file out the door.
  gate_result_verify "$result_file" "" "preflight-pass-tag" || {
    printf 'Error: internal -- gate_apply_preflight_pass_tag corrupted frontmatter/body parity\n' >&2
    exit 1
  }
}

if [[ "$PREFLIGHT_STATUS" == "pass" ]]; then
  verify_preflight_artifacts_current || exit 1
  gate_apply_preflight_pass_tag "$OUTPUT_FILE"
fi

# ── Override provenance (audit record) ─────────────────────────────────────────
# When accepted-risk overrides were injected, the gate result must say so: which
# file they came from and exactly what was suppressed. Without this, an override
# silently turns a would-be block into a GO with no trace in the result. The block
# is appended deterministically by the gate (not the executor) so the audit record
# is independent of what the reviewer chose to echo. It is written on both GO and
# NO-GO -- the audit is about what was offered for suppression, not the outcome.
# Lines are indented (markdown code block) so this section can never introduce a
# spurious top-level `Final:` line or a frontmatter `---` fence that would trip
# gate_result_verify / `pmctl gate verify`.
if [[ -n "$GATE_OVERRIDES_CONTENT" ]]; then
  # shellcheck disable=SC2016  # literal markdown backticks in the format string, not a command substitution
  {
    printf '\n## Gate Overrides Applied\n'
    printf 'Accepted-risk overrides were loaded from `%s` and injected into every\n' "$OVERRIDE_FILE"
    printf 'reviewer and synthesis brief for this run. Reviewers were instructed not to\n'
    printf 're-block these items unless the diff materially changed the accepted risk.\n'
    printf 'This block is the audit record of what was offered for suppression.\n\n'
    printf '%s\n' "$GATE_OVERRIDES_CONTENT" | sed 's/^/    /'
  } >> "$OUTPUT_FILE"
  say 'pr-gate: override provenance recorded in result\n'
  # Re-verify after appending: the provenance block is written post-verification,
  # so re-run the same integrity contract to prove the appended (indented) content
  # did not introduce a second Final: line or break frontmatter parity -- a
  # parser-hostile override file (containing `Final: GO` / `---`) must stay neutralized.
  gate_result_verify "$OUTPUT_FILE" "" "post-provenance-append" || exit 1
fi

# ── Post-gate hook ─────────────────────────────────────────────────────────
# Both executors complete the gate in-process now, so post-gate fires at true
# gate completion regardless of executor. It runs only when --allow-hooks is set
# AND the gate result is GO -- a success-only side-effect hook, not a teardown hook.
_POST_GATE_HOOK="$WORK_DIR/.pm-dispatch/post-gate.sh"
if [[ "$ALLOW_HOOKS" != "true" ]]; then
  if [[ -f "$_POST_GATE_HOOK" ]]; then
    printf 'Warning: .pm-dispatch/post-gate.sh present but skipped -- pass --allow-hooks to execute repo-local hook scripts\n' >&2
  fi
elif [[ -f "$_POST_GATE_HOOK" && ! -x "$_POST_GATE_HOOK" ]]; then
  printf 'Warning: .pm-dispatch/post-gate.sh exists but is not executable -- skipping\n' >&2
elif [[ -x "$_POST_GATE_HOOK" ]]; then
  _GATE_FINAL=$(grep -m1 '^Final: ' "$OUTPUT_FILE" 2>/dev/null | awk '{print $2}' || true)
  if [[ "$_GATE_FINAL" != "GO" ]]; then
    say '\nSkipping post-gate hook: gate result is %s (post-gate runs only on GO)\n' "${_GATE_FINAL:-unknown}"
  else
    say '\nRunning post-gate hook: .pm-dispatch/post-gate.sh\n'
    # Keep this teardown path free of a subshell conditional.  Some deployed
    # gate copies reached this branch through an incompatible parser and
    # reported a syntax error after a valid GO artifact had already been
    # written.  Save/restore explicitly so the hook still runs in WORK_DIR.
    _POST_GATE_HOOK_RC=0
    _POST_GATE_PREV_DIR="$PWD"
    cd "$WORK_DIR" || _POST_GATE_HOOK_RC=$?
    if [[ "$_POST_GATE_HOOK_RC" -eq 0 ]]; then
      bash "$_POST_GATE_HOOK" || _POST_GATE_HOOK_RC=$?
    fi
    cd "$_POST_GATE_PREV_DIR" || exit 2
    if [[ "$_POST_GATE_HOOK_RC" -ne 0 ]]; then
      printf '\n## Post-Gate Hook Failure\n**post-gate.sh exited nonzero -- this gate run is INCOMPLETE despite Final: GO above. Re-run after fixing the hook.**\n' >> "$OUTPUT_FILE"
      printf 'Error: post-gate hook failed\n' >&2
      exit 1
    fi
    say 'post-gate hook completed.\n'
  fi
fi

# Publish a deterministic human-readable coordinate block before the result
# digest is bound.  Reviewer prose is not an authority for tier, pass scope, or
# coverage, so the shell states the resolved axes explicitly.  In particular,
# a full-rigor targeted pass must not be mistaken for a comprehensive review.
gate_append_truthful_coordinate_label() {
  local result_file="$1" pass_label pass_note coverage_label
  pass_label="$PASS_KIND_RESOLVED"
  pass_note="$PASS_SCOPE"
  if [[ "$PASS_KIND_RESOLVED" == targeted ]]; then
    pass_note="$PASS_SCOPE only; this artifact is not a comprehensive review"
  fi
  coverage_label="${COVERAGE_SELECTED_DISPLAY:-none}"
  {
    printf '\n## Gate Coordinates (machine-resolved)\n'
    printf '%s\n' \
      "- Tier (rigor): \`$TIER_RESOLVED\` (basis: \`$TIER_SELECTION_BASIS\`)"
    printf '%s\n' "- Pass scope: \`$pass_label\` — $pass_note"
    printf '%s\n' \
      "- Reviewer coverage: \`$coverage_label\` (basis: \`$COVERAGE_SELECTION_BASIS\`)"
    printf '%s\n' "- Execution mode: \`$MODE_RESOLVED\`"
    if [[ "$PASS_KIND_RESOLVED" == targeted ]]; then
      printf '%s\n' \
        "- Initial result (remediation context): \`$INITIAL_RESULT_DISPLAY\`"
    fi
  } >> "$result_file"
}

gate_append_truthful_coordinate_label "$OUTPUT_FILE"

# Replace the executor-authored staging frontmatter with a bound pointer and
# write the machine-owned assurance sidecar only after every deterministic
# rewrite and explicitly enabled post-gate hook is complete. Completed reviewer
# routes publish result v4; historical reviewer-only routes remain readable as
# v3, while pre-dispatch fail-fast routes without reviewer protocol remain v2.
# The shared verifier then checks result/pointer/envelope
# parity before publication or relocation.
gate_finalize_assurance "$OUTPUT_FILE" "$ASSURANCE_FILE" || exit 2

# ── Finalize QA evidence before relocation ──────────────────────────────────
# The EXIT trap also finalizes QA evidence, but a successful run relocates its
# per-run artifacts before that trap fires.  Finalize here while the checkpoint
# still resides under WORK_DIR; otherwise a killed QA helper can leave a stale
# `running` record in the relocated run directory indefinitely.
qa_execution_finalize 0 || true

# ── Relocate result to run dir (post-verification) ───────────────────────────
# OUTPUT_FILE was written by the executor in WORK_DIR (workspace-write sandbox
# constraint). Now that it is verified, move it (and any parallel reviewer outputs,
# already read by synthesis) to _ARTIFACT_ROOT/.gate-results/ if a run dir was supplied.
# Relocation is centralized in relocate_gate_artifacts(), which the EXIT trap also calls
# so failure paths relocate too; calling it here updates OUTPUT_FILE before the prints
# below, and the trap's later call is then a no-op. --output overrides are never moved.
# CC-541: gate_reviewer_protocol_verify already flagged (from the parsed
# structured qa-tester document, not a markdown re-scan) that this
# orchestrator host-confirmed QA_RULES_DIR while the reviewer's own block
# verdict still cited it as missing. Surface that distinction here --
# informational only, does not alter the verdict or the schema.
if [[ -n "${PM_DISPATCH_QA_RULES_DIR_REVIEWER_GAP_DETECTED:-}" ]]; then
  printf '[reviewer-sandbox-visibility] host confirmed QA_RULES_DIR=%s exists and is readable, but the qa-tester reviewer still reported it missing/unreadable in its block verdict -- this is a reviewer-visibility gap, not a genuinely absent rules source (see CC-541).\n' "${QA_RULES_DIR:-<unset>}" >&2
fi

relocate_gate_artifacts

# ── Print result path for caller ─────────────────────────────────────────────
# The result was written by the dispatched subprocess and already integrity-checked
# in-process (gate_result_verify above). `pmctl gate verify "$OUTPUT_FILE"` re-runs
# the same contract on demand for callers that want to re-confirm out of band.
say '\nresult: %s\n' "$OUTPUT_FILE"
if [[ -n "${GATE_RUN_DIR_OVERRIDE:-}" ]]; then
  say 'run-dir: %s\n' "${GATE_RUN_DIR_OVERRIDE:-}"
fi

_FINAL_EXIT_VERDICT=$(grep -m1 '^Final: ' "$OUTPUT_FILE" 2>/dev/null | awk '{print $2}' || true)
if [[ "$_FINAL_EXIT_VERDICT" == "NO-GO" ]]; then
  exit 1
fi
if [[ "$_FINAL_EXIT_VERDICT" == "INCOMPLETE" ]]; then
  exit 3
fi
