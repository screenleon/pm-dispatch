#!/usr/bin/env bash
# Source-safe Gate CLI option helpers.
#
# Sourcing defines functions only. The composition root calls
# gate_options_init, gate_options_parse, then gate_options_require_workdir
# before any policy, subject, or dispatch module is loaded.

_gate_set_mode_requested() {
  local candidate="$1" spelling="$2"
  if [[ "$MODE_OPTION_SEEN" == false ]]; then
    MODE_REQUESTED="$candidate"
    MODE_OPTION_SEEN=true
    MODE_OPTION_SPELLING="$spelling"
    return 0
  fi
  if [[ "$MODE_REQUESTED" != "$candidate" ]]; then
    printf 'Error: conflicting gate mode options: %s requested %s, but %s requested %s\n' \
      "$MODE_OPTION_SPELLING" "$MODE_REQUESTED" "$spelling" "$candidate" >&2
    return 2
  fi
  return 0
}

_gate_set_pass_requested() {
  local candidate="$1" spelling="$2" syntax_source="$3"
  if [[ "$PASS_OPTION_SEEN" == false ]]; then
    PASS_KIND_REQUESTED="$candidate"
    PASS_OPTION_SEEN=true
    PASS_OPTION_SPELLING="$spelling"
    PASS_SYNTAX_SOURCE="$syntax_source"
    return 0
  fi
  if [[ "$PASS_KIND_REQUESTED" != "$candidate" ]]; then
    printf 'Error: conflicting gate pass options: %s requested %s, but %s requested %s\n' \
      "$PASS_OPTION_SPELLING" "$PASS_KIND_REQUESTED" "$spelling" "$candidate" >&2
    return 2
  fi
  if [[ "$PASS_OPTION_SPELLING" != "$spelling" ]]; then
    # shellcheck disable=SC2034  # Consumed by the entrypoint after parsing.
    PASS_SYNTAX_SOURCE="mixed"
  fi
  return 0
}

# shellcheck disable=SC2034 # caller-facing globals consumed by pr-gate.sh
gate_options_init() {
  WORK_DIR=""
  GATE_RUN_DIR_OVERRIDE=""   # out-of-repo artifact root; set via --run-dir from pmctl-gate
  TIER_OVERRIDE=""
  TIER_REQUESTED="auto"
  TIER_SELECTION_BASIS="policy"
  REVIEWERS_OVERRIDE=""
  REVIEWERS_OPTION_SOURCE=""
  MODE_REQUESTED="default"
  MODE_OPTION_SEEN=false
  # shellcheck disable=SC2034 # consumed by later coordinate resolution
  MODE_OPTION_SPELLING=""
  PASS_KIND_REQUESTED="initial"
  # shellcheck disable=SC2034 # consumed by later coordinate resolution
  PASS_OPTION_SEEN=false
  # shellcheck disable=SC2034 # consumed by later coordinate resolution
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
  # runtime/lib/reasoning-effort.sh).
  DISPATCH_EFFORT=""
  INPUT_BRIEF_FILE=""
  TEST_CMD_OVERRIDE=""   # --test-cmd: explicit pre-flight test command (see CC-470 Part 3)
  TEST_TIMEOUT="3600"    # --test-timeout: independent of --timeout (dispatch budget)
  SKIP_PREFLIGHT_TESTS=false
}

gate_options_print_help() {
  local help_source="${1:-$0}"
  awk '
    /^# pr-gate-help:start$/ { help=1; next }
    /^# pr-gate-help:end$/ { exit }
    help {
      line=$0
      sub(/^# ?/, "", line)
      print line
    }
  ' "$help_source"
}

# shellcheck disable=SC2034 # ACCEPT_SCOPE_TRUNCATION is consumed by gate-scope.sh
gate_options_parse() {
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
        gate_options_print_help "$0"
        exit 0;;
      *)
        printf 'Unknown arg: %s\n' "$1" >&2
        printf 'Accepted: --cd --run-dir --tier --mode --brief --policy --pass --reviewers --targeted --initial-result --reviewer-dir --scope --base --head --output --executor --model --effort --isolation --timeout --parallel --sequential --allow-hooks --allow-dirty --accept-scope-truncation --override-file --policy-override --test-cmd --test-timeout --skip-preflight-tests (-h for help)\n' >&2
        exit 2;;
    esac
  done
}

gate_options_require_workdir() {
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
}

# gate_options_require_initial_result <requires_initial> <initial_result_input> <pass_kind_label>
#   Cross-option check between --initial-result and the resolved pass kind. The
#   caller passes the policy table's requires_initial_result value for the
#   resolved pass kind (true|false); anything else is a policy-integrity error.
#   Prints the canonical CLI message and exits 2 on a mismatch; returns 0 when
#   --initial-result's presence matches what the pass kind requires. This is a
#   pure comparator -- it reads no option globals, policy tables, or env; the
#   caller computes both inputs.
gate_options_require_initial_result() {
  local requires_initial="$1" initial_result_input="$2" pass_kind_label="$3"
  case "$requires_initial" in
    true)
      if [[ -z "$initial_result_input" ]]; then
        printf 'Error: --pass targeted requires --initial-result <path>\n' >&2
        exit 2
      fi
      ;;
    false)
      if [[ -n "$initial_result_input" ]]; then
        printf 'Error: --initial-result is only valid with --pass targeted\n' >&2
        exit 2
      fi
      ;;
    *)
      printf 'Error: invalid requires_initial_result value for pass kind %s: %s\n' \
        "$pass_kind_label" "$requires_initial" >&2
      exit 2
      ;;
  esac
}

# gate_options_reviewer_coverage_agrees <normalized_explicit> <normalized_shorthand>
#   Both args are already vocabulary-normalized, space-separated reviewer lists
#   (--reviewers and its --targeted compatibility spelling). Order-insensitive
#   set compare; prints the canonical message and exits 2 when the sets differ,
#   returns 0 when they agree. Pure comparator; the caller runs the
#   normalization and the "both spellings seen" guard.
gate_options_reviewer_coverage_agrees() {
  local explicit="$1" shorthand="$2"
  # shellcheck disable=SC2086  # deliberate word-split of the normalized space lists
  if [[ "$(printf '%s\n' $explicit | LC_ALL=C sort)" \
      != "$(printf '%s\n' $shorthand | LC_ALL=C sort)" ]]; then
    printf 'Error: --reviewers and --targeted request different reviewer coverage\n' >&2
    exit 2
  fi
}
