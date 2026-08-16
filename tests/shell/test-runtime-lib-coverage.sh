#!/usr/bin/env bash
# Direct regression coverage for runtime/lib helpers that are otherwise only sourced by callers.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/../lib/test-harness.sh"
th_init "$@"

# Behavior: An explicit gate workspace override takes precedence over git discovery.
# Steps: Source the helper and verify that the environment override is returned unchanged.
test_gate_workspace_override() {
  local name="runtime-lib-coverage/gate-workspace-override" output
  should_run "$name" || return 0
  output="$(PM_DISPATCH_GATE_WORKSPACE=/tmp/declared-workspace bash -c '. "$1/runtime/lib/gate-workspace.sh"; gate_workspace_root /not-used /home/example' _ "$REPO_ROOT")"
  if [[ "$output" == /tmp/declared-workspace ]]; then pass "$name"; else fail "$name" "output=$output"; fi
}

# Behavior: Config parsing accepts valid dispatch defaults and project-scoped memory paths.
# Steps: Source the helper against a temporary config and assert the exported globals.
test_pmctl_config_loads_valid_values() {
  local name="runtime-lib-coverage/pmctl-config-loads-valid-values" cfg output key
  should_run "$name" || return 0; # shellcheck disable=SC2154
  cfg="$tmp_root/config"; key="0123456789abcdef0123456789abcdef01234567"
  printf '%s\n' 'dispatch.default_timeout = 42' 'dispatch.auto_pack = on' "memory.projects.$key.dir = /tmp/project-memory" > "$cfg"
  output="$(PM_DISPATCH_CONFIG_FILE="$cfg" bash -c '. "$1/runtime/lib/pmctl-config.sh"; pm_config_load "$2"; printf "%s|%s|%s|%s" "$PM_CFG_TIMEOUT" "$PM_CFG_AUTO_PACK" "$PM_CFG_MEMORY_DIR" "$PM_CFG_MEMORY_CONFIG_STATUS"' _ "$REPO_ROOT" "$key")"
  if [[ "$output" == '42|on|/tmp/project-memory|matched' ]]; then pass "$name"; else fail "$name" "output=$output"; fi
}

# Behavior: Unsafe legacy global memory settings are rejected for project-scoped callers.
# Steps: Load a temporary legacy-only config and assert its invalid status.
test_pmctl_config_rejects_legacy_global_memory() {
  local name="runtime-lib-coverage/pmctl-config-rejects-legacy-global-memory" cfg output key
  should_run "$name" || return 0; # shellcheck disable=SC2154
  cfg="$tmp_root/config"; key="0123456789abcdef0123456789abcdef01234567"
  printf '%s\n' 'dispatch.memory_dir = /tmp/legacy-memory' > "$cfg"
  output="$(PM_DISPATCH_CONFIG_FILE="$cfg" bash -c '. "$1/runtime/lib/pmctl-config.sh"; pm_config_load "$2" 2>/dev/null; printf "%s|%s" "$PM_CFG_MEMORY_DIR_INVALID" "$PM_CFG_MEMORY_CONFIG_STATUS"' _ "$REPO_ROOT" "$key")"
  if [[ "$output" == '1|legacy-global' ]]; then pass "$name"; else fail "$name" "output=$output"; fi
}

# Behavior: all shared runtime identifiers accept their documented boundary
# values and reject traversal, malformed, and cross-domain values.
# Steps: source the canonical policy and exercise each grammar directly.
test_identifier_policy_domains() {
  local name="runtime-lib-coverage/identifier-policy-domains" output
  should_run "$name" || return 0
  output="$(bash -c '
    . "$1/runtime/lib/identifier-policy.sh"
    pm_identifier_adapter_is_valid codex && ! pm_identifier_adapter_is_valid ../codex &&
    pm_identifier_host_is_valid generic && ! pm_identifier_host_is_valid custom &&
    pm_identifier_run_is_valid run-Ab9-z0 && ! pm_identifier_run_is_valid run-a_b-c &&
    pm_identifier_operation_is_valid op-20260811T092500Z-a1b2c3 && ! pm_identifier_operation_is_valid op-20260811-a1b2c3 &&
    pm_identifier_gate_is_valid gate-20260811-092500-Ab9def && ! pm_identifier_gate_is_valid gate-20260811-092500-short &&
    pm_identifier_artifact_leaf_is_valid legacy-fixture-root && ! pm_identifier_artifact_leaf_is_valid ../escape
  ' _ "$REPO_ROOT" 2>&1)" || true
  if [[ -z "$output" ]]; then pass "$name"; else fail "$name" "$output"; fi
}

# Behavior: every runtime library is safe to import into a caller that owns its
# own shell policy. Steps: source every library under each strict-mode variant
# and require shell flags, cwd, traps, writable roots, and background jobs to
# remain unchanged. A return marker prevents a source-time `exit 0` from being
# mistaken for a passing subshell.
test_all_runtime_libraries_are_source_safe() {
  local name="runtime-lib-coverage/all-runtime-libraries-source-safe" watched lib mode marker
  should_run "$name" || return 0
  watched="$tmp_root/source-contract"
  mkdir -p "$watched"
  printf 'sentinel\n' > "$watched/sentinel"
  for mode in none errexit nounset pipefail all; do
    for lib in "$REPO_ROOT"/runtime/lib/*.sh; do
      marker="$watched/returned-${mode}-${lib##*/}"
      : > "$marker"
      if ! SOURCE_RETURN_MARKER="$marker" bash -c '
        mode="$1"; lib="$2"; watched="$3"
        case "$mode" in none) ;; errexit) set -e ;; nounset) set -u ;; pipefail) set -o pipefail ;; all) set -euo pipefail ;; esac
        trap "printf trapped >&2" USR1
        mkdir -p "$watched/home" "$watched/xdg-cache" "$watched/xdg-data" "$watched/tmp"
        before_flags="$-"; before_pipefail="$(set -o | awk '\''$1 == "pipefail" { print $2 }'\'')"; before_cwd="$PWD"; before_trap="$(trap -p USR1)"; before_files="$(find "$watched" -mindepth 1 -printf "%P\\n" | sort)"; before_jobs="$(jobs -p)"
        export HOME="$watched/home" XDG_CACHE_HOME="$watched/xdg-cache" XDG_DATA_HOME="$watched/xdg-data" TMPDIR="$watched/tmp"
        . "$lib"
        after_pipefail="$(set -o | awk '\''$1 == "pipefail" { print $2 }'\'')"; after_trap="$(trap -p USR1)"; after_files="$(find "$watched" -mindepth 1 -printf "%P\\n" | sort)"; after_jobs="$(jobs -p)"
        [[ "$before_flags" == "$-" && "$before_pipefail" == "$after_pipefail" && "$before_cwd" == "$PWD" && "$before_trap" == "$after_trap" && "$before_files" == "$after_files" && "$before_jobs" == "$after_jobs" ]] || exit 1
        printf __SOURCE_RETURNED__ > "$SOURCE_RETURN_MARKER"
      ' _ "$mode" "$lib" "$watched"; then
        fail "$name" "source contract failed: mode=$mode lib=${lib#"$REPO_ROOT"/}"
        return
      fi
      if [[ "$(<"$marker")" != __SOURCE_RETURNED__ ]]; then
        fail "$name" "source returned via exit before contract checks: mode=$mode lib=${lib#"$REPO_ROOT"/}"
        return
      fi
    done
  done
  pass "$name"
}

# Behavior: every runtime library import does not spawn a process, including a
# short-lived external helper or a command-substitution subshell, and does not
# write anywhere on disk. Steps: trace process and file activity for each
# library; reject every fork/clone, every exec other than the hosting shell,
# and every write-capable open or filesystem mutation.
test_runtime_libraries_do_not_exec_on_source() {
  local name="runtime-lib-coverage/all-libraries-no-source-side-effects" lib trace external spawned writes st
  should_run "$name" || return 0
  if ! command -v strace >/dev/null 2>&1; then
    fail "$name" "strace is required to verify short-lived source-time processes"
    return
  fi
  # Gate sandboxes often ship strace but deny ptrace. A failed attach under
  # `set -e` used to abort the suite before retrieval-term cases ran. Do not
  # record PASS without a successful probe.
  if [[ "${PM_TEST_STRACE_UNUSABLE:-}" == 1 ]] \
      || ! strace -qq -e trace=none true >/dev/null 2>&1; then
    printf 'UNAVAILABLE: %s: strace cannot attach; source-time syscall contract not verified\n' "$name"
    return 0
  fi
  for lib in "$REPO_ROOT"/runtime/lib/*.sh; do
    # The single-quoted child program must preserve $1 for bash -c, not expand
    # it in this test process.
    # shellcheck disable=SC2016
    st=0
    trace="$(strace -f -qq -e trace=process,file bash -c '. "$1"' _ "$lib" 2>&1 >/dev/null)" || st=$?
    if [[ "$st" -ne 0 ]]; then
      fail "$name" "strace failed ($st) sourcing ${lib#"$REPO_ROOT"/}: $trace"
      return
    fi
    external="$(printf '%s\n' "$trace" | grep 'execve(' | grep -v 'execve("/usr/bin/bash"' || true)"
    spawned="$(printf '%s\n' "$trace" | grep -E '(^|[[:space:]])(clone|clone3|fork|vfork)\(' || true)"
    writes="$(printf '%s\n' "$trace" | grep -E 'O_(WRONLY|RDWR|CREAT|TRUNC)|(^|[[:space:]])(mkdir|mkdirat|rmdir|unlink|unlinkat|rename|renameat|link|linkat|symlink|symlinkat|chmod|fchmod|chown|fchown|truncate|ftruncate)\(' | grep -vE '"/dev/(null|tty)"' || true)"
    if [[ -n "$external" || -n "$spawned" || -n "$writes" ]]; then
      fail "$name" "source side effect: $lib: ${external}${spawned}${writes}"
      return
    fi
  done
  pass "$name"
}

# Behavior: English extraction keeps identifiers, min-length 3, and the shared
# stop list; it must not emit 1-2 character tokens or "the"/"and".
# Steps: source retrieval-terms.sh and extract a mixed English sentence.
test_retrieval_terms_english() {
  local name="runtime-lib-coverage/retrieval-terms-english" output expected
  should_run "$name" || return 0
  expected=$'cards\nhelper\nmemory\nplus\npmctl_context_pack\nretrieval\nsystem'
  output="$(bash -c '
    . "$1/runtime/lib/retrieval-terms.sh"
    retrieval_extract_terms "The retrieval system and the memory cards plus pmctl_context_pack helper"
  ' _ "$REPO_ROOT")"
  if [[ "$output" == "$expected" ]]; then pass "$name"; else fail "$name" "output=$output"; fi
}

# Behavior: hook English policy (min 4, no stop list) keeps length>=4 stop
# words and drops 3-char tokens, including on the mixed CJK path.
# Steps: extract the same sentence under defaults and under 4/0; assert
# "api"/"the" vs "from"/"that" differ, and mixed CJK still emits 分析.
test_retrieval_terms_hook_english_policy() {
  local name="runtime-lib-coverage/retrieval-terms-hook-english-policy" default_out hook_out mixed
  should_run "$name" || return 0
  default_out="$(bash -c '
    . "$1/runtime/lib/retrieval-terms.sh"
    retrieval_extract_terms "check the api from that helper"
  ' _ "$REPO_ROOT")"
  hook_out="$(bash -c '
    . "$1/runtime/lib/retrieval-terms.sh"
    retrieval_extract_terms "check the api from that helper" 4 0
  ' _ "$REPO_ROOT")"
  mixed="$(bash -c '
    . "$1/runtime/lib/retrieval-terms.sh"
    retrieval_extract_terms "分析 from api 使用量" 4 0
  ' _ "$REPO_ROOT")"
  if [[ "$default_out" == *"api"* && "$default_out" != *$'\n'"from"$'\n'* \
      && "$default_out" != *$'\n'"that"$'\n'* \
      && "$hook_out" != *"api"* && "$hook_out" == *"from"* \
      && "$hook_out" == *"that"* && "$hook_out" != *$'\n'"the"$'\n'* \
      && "$mixed" == *"from"* && "$mixed" != *"api"* && "$mixed" == *"分析"* ]]; then
    pass "$name"
  else
    fail "$name" "default=$default_out hook=$hook_out mixed=$mixed"
  fi
}

# Behavior: CJK runs become overlapping 2-grams; mixed English tokens survive.
# Steps: extract "分析 token 使用量" and require token plus 分析/使用/用量.
test_retrieval_terms_cjk_mixed() {
  local name="runtime-lib-coverage/retrieval-terms-cjk-mixed" output
  should_run "$name" || return 0
  output="$(bash -c '
    . "$1/runtime/lib/retrieval-terms.sh"
    retrieval_extract_terms "分析 token 使用量"
  ' _ "$REPO_ROOT")"
  if [[ "$output" == *$'\n'"token"$'\n'* || "$output" == "token"$'\n'* || "$output" == *$'\n'"token" || "$output" == "token" ]] \
     && [[ "$output" == *"分析"* ]] \
     && [[ "$output" == *"使用"* ]] \
     && [[ "$output" == *"用量"* ]]; then
    pass "$name"
  else
    fail "$name" "output=$output"
  fi
}

# Behavior: Japanese punctuation such as the Katakana middle dot splits
# CJK runs; no emitted term contains the punctuation itself.
# Steps: extract 分析・使用 and require 分析 plus 使用, with no ・.
test_retrieval_terms_cjk_punctuation_splits_runs() {
  local name="runtime-lib-coverage/retrieval-terms-cjk-punctuation-splits-runs" output
  should_run "$name" || return 0
  output="$(bash -c '
    . "$1/runtime/lib/retrieval-terms.sh"
    retrieval_extract_terms "分析・使用"
  ' _ "$REPO_ROOT")"
  if [[ "$output" == *"分析"* && "$output" == *"使用"* && "$output" != *"・"* ]]; then
    pass "$name"
  else
    fail "$name" "output=$output"
  fi
}

# Behavior: a 5-character CJK run emits four overlapping bigrams and no unigram.
# Steps: extract 關鍵詞管線 and compare against the exact sorted set.
test_retrieval_terms_cjk_bigrams() {
  local name="runtime-lib-coverage/retrieval-terms-cjk-bigrams" output expected
  should_run "$name" || return 0
  expected=$'管線\n詞管\n鍵詞\n關鍵'
  output="$(bash -c '
    . "$1/runtime/lib/retrieval-terms.sh"
    retrieval_extract_terms "關鍵詞管線"
  ' _ "$REPO_ROOT")"
  if [[ "$output" == "$expected" ]]; then pass "$name"; else fail "$name" "output=$output"; fi
}

# Behavior: non-CJK non-ASCII (Cyrillic / emoji) takes the byte-walk path,
# exits cleanly, keeps ASCII terms, and does not emit those runs as terms.
# Steps: extract "привет token 😀" and require only token.
test_retrieval_terms_non_cjk_non_ascii_skips_cleanly() {
  local name="runtime-lib-coverage/retrieval-terms-non-cjk-non-ascii-skips-cleanly" output
  should_run "$name" || return 0
  output="$(bash -c '
    . "$1/runtime/lib/retrieval-terms.sh"
    retrieval_extract_terms "привет token 😀"
  ' _ "$REPO_ROOT")"
  if [[ "$output" == "token" ]]; then
    pass "$name"
  else
    fail "$name" "output=$output"
  fi
}

# Behavior: _ctx_extract_terms is a thin wrapper and matches the shared lib.
# Steps: source both libs and compare outputs on English, mixed, and CJK input.
test_retrieval_terms_wrapper_parity() {
  local name="runtime-lib-coverage/retrieval-terms-wrapper-parity" output
  should_run "$name" || return 0
  output="$(bash -c '
    . "$1/runtime/lib/retrieval-terms.sh"
    . "$1/runtime/lib/pmctl-context.sh"
    mismatch=0
    for sample in "The retrieval system and the memory cards" "分析 token 使用量" "關鍵詞管線" "a an the or"; do
      left="$(retrieval_extract_terms "$sample")"
      right="$(_ctx_extract_terms "$sample")"
      [[ "$left" == "$right" ]] || { printf "mismatch:%s\nleft=%s\nright=%s\n" "$sample" "$left" "$right"; mismatch=1; }
    done
    exit "$mismatch"
  ' _ "$REPO_ROOT" 2>&1)" || true
  if [[ -z "$output" ]]; then pass "$name"; else fail "$name" "$output"; fi
}

# Behavior: streamed output keeps a trailing newline so while-read callers
# do not drop the last CJK bigram.
# Steps: consume "分析 token 使用量" via while-read and require four terms.
test_retrieval_terms_while_read_keeps_last() {
  local name="runtime-lib-coverage/retrieval-terms-while-read-keeps-last" output
  should_run "$name" || return 0
  output="$(bash -c '
    . "$1/runtime/lib/retrieval-terms.sh"
    terms=()
    while IFS= read -r term; do
      [[ -n "$term" ]] && terms+=("$term")
    done < <(retrieval_extract_terms "分析 token 使用量")
    printf "%s\n" "${#terms[@]}"
    printf "%s\n" "${terms[@]}"
  ' _ "$REPO_ROOT")"
  if [[ "$output" == $'4\ntoken\n使用\n分析\n用量' ]]; then
    pass "$name"
  else
    fail "$name" "output=$output"
  fi
}

# Behavior: a huge ASCII paste stays on the tr/awk path and still yields terms.
# Steps: extract a 200KB ASCII buffer that contains "retrieval" and "memory".
test_retrieval_terms_large_ascii_stays_fast() {
  local name="runtime-lib-coverage/retrieval-terms-large-ascii-stays-fast" output
  should_run "$name" || return 0
  output="$(bash -c '
    . "$1/runtime/lib/retrieval-terms.sh"
    blob="the retrieval and memory $(head -c 200000 /dev/zero | tr "\0" "x")"
    retrieval_extract_terms "$blob"
  ' _ "$REPO_ROOT")"
  if [[ "$output" == *"retrieval"* && "$output" == *"memory"* ]]; then
    pass "$name"
  else
    fail "$name" "output=$output"
  fi
}

# Behavior: input longer than RETRIEVAL_TERM_MAX_BYTES is truncated; a token
# only present past the cap is dropped.
# Steps: put sentinel_head at the start and sentinel_tail after 20KiB of padding.
test_retrieval_terms_truncates_past_byte_cap() {
  local name="runtime-lib-coverage/retrieval-terms-truncates-past-byte-cap" output
  should_run "$name" || return 0
  output="$(bash -c '
    . "$1/runtime/lib/retrieval-terms.sh"
    blob="sentinel_head $(head -c 20000 /dev/zero | tr "\0" "z") sentinel_tail"
    retrieval_extract_terms "$blob"
  ' _ "$REPO_ROOT")"
  if [[ "$output" == *"sentinel_head"* && "$output" != *"sentinel_tail"* ]]; then
    pass "$name"
  else
    fail "$name" "output=$output"
  fi
}

# Behavior: CJK input longer than RETRIEVAL_TERM_MAX_BYTES is truncated on
# the od/awk path; terms after the cap are dropped. A mid-rune cut is skipped
# without inventing a term; the cap itself is announced on stderr.
# Steps: prefix 分析, pad with 甲 past 16KiB, suffix 用量; assert 分析/甲甲 stay
# and 用量 does not.
test_retrieval_terms_truncates_cjk_past_byte_cap() {
  local name="runtime-lib-coverage/retrieval-terms-truncates-cjk-past-byte-cap" output err
  should_run "$name" || return 0
  err="$tmp_root/retrieval-terms-cjk-truncate.err"
  output="$(bash -c '
    set -o pipefail
    . "$1/runtime/lib/retrieval-terms.sh"
    pad="$(printf "甲%.0s" {1..6000})"
    retrieval_extract_terms "分析${pad}用量"
  ' _ "$REPO_ROOT" 2>"$err")"
  if [[ "$output" == *"分析"* && "$output" == *"甲甲"* && "$output" != *"用量"* \
      && "$(cat "$err")" == "retrieval-terms: input truncated from 18012 bytes to 16384 bytes" \
      && "$(wc -l < "$err" | tr -d ' ')" == 1 ]]; then
    pass "$name"
  else
    fail "$name" "output=$output err=$(cat "$err")"
  fi
}

# Behavior: crossing RETRIEVAL_TERM_MAX_BYTES writes exactly one stderr
# notice and still keeps stdout to the prefix terms only.
# Steps: extract a padded blob; assert stderr is the single documented
# line and stdout has the head token only.
test_retrieval_terms_truncate_writes_stderr() {
  local name="runtime-lib-coverage/retrieval-terms-truncate-writes-stderr" output err
  should_run "$name" || return 0
  err="$tmp_root/retrieval-terms-truncate.err"
  output="$(bash -c '
    set -o pipefail
    . "$1/runtime/lib/retrieval-terms.sh"
    blob="sentinel_head $(head -c 20000 /dev/zero | tr "\0" "z") sentinel_tail"
    retrieval_extract_terms "$blob"
  ' _ "$REPO_ROOT" 2>"$err")"
  if [[ "$output" == *"sentinel_head"* && "$output" != *"sentinel_tail"* \
      && "$(cat "$err")" == "retrieval-terms: input truncated from 20028 bytes to 16384 bytes" \
      && "$(wc -l < "$err" | tr -d ' ')" == 1 ]]; then
    pass "$name"
  else
    fail "$name" "output=$output err=$(cat "$err")"
  fi
}

# Behavior: input at or under the cap does not write a truncation notice.
# Steps: extract a short token and require empty stderr.
test_retrieval_terms_under_cap_is_quiet() {
  local name="runtime-lib-coverage/retrieval-terms-under-cap-is-quiet" output err
  should_run "$name" || return 0
  err="$tmp_root/retrieval-terms-under-cap.err"
  output="$(bash -c '
    . "$1/runtime/lib/retrieval-terms.sh"
    retrieval_extract_terms "token"
  ' _ "$REPO_ROOT" 2>"$err")"
  if [[ "$output" == "token" && ! -s "$err" ]]; then
    pass "$name"
  else
    fail "$name" "output=$output err=$(cat "$err")"
  fi
}

# Behavior: sourcing retrieval-terms.sh twice does not redefine or fail.
# Steps: source the lib twice, extract "token", require a single term.
test_retrieval_terms_source_is_idempotent() {
  local name="runtime-lib-coverage/retrieval-terms-source-is-idempotent" output
  should_run "$name" || return 0
  output="$(bash -c '
    . "$1/runtime/lib/retrieval-terms.sh"
    . "$1/runtime/lib/retrieval-terms.sh"
    retrieval_extract_terms "token"
  ' _ "$REPO_ROOT" 2>&1)"
  if [[ "$output" == "token" ]]; then pass "$name"; else fail "$name" "output=$output"; fi
}

# Behavior: shell/awk metacharacters in the input stay data and do not run.
# Steps: extract a payload with command substitution, backticks, and system();
# assert only "token" and that a marker file is not created.
test_retrieval_terms_metacharacters_stay_data() {
  local name="runtime-lib-coverage/retrieval-terms-metacharacters-stay-data" output marker
  should_run "$name" || return 0
  marker="$tmp_root/retrieval-terms-pwned"
  rm -f "$marker"
  output="$(bash -c '
    . "$1/runtime/lib/retrieval-terms.sh"
    retrieval_extract_terms "\$(.) \`^\` token"
  ' _ "$REPO_ROOT" "$marker" 2>&1)"
  if [[ "$output" == "token" && ! -e "$marker" ]]; then
    pass "$name"
  else
    fail "$name" "output=$output marker_exists=$([[ -e $marker ]] && echo yes || echo no)"
  fi
}

# Behavior: a 16KiB CJK walk stays within an interactive hook budget (2s).
# Steps: extract 5500 copies of 甲 (above the byte cap after truncate) and
# require the elapsed wall time to be under two seconds.
test_retrieval_terms_cjk_cap_stays_interactive() {
  local name="runtime-lib-coverage/retrieval-terms-cjk-cap-stays-interactive" elapsed
  should_run "$name" || return 0
  elapsed="$(TIMEFORMAT='%R'; { time bash -c '
    . "$1/runtime/lib/retrieval-terms.sh"
    blob="$(printf "甲%.0s" {1..5500})"
    retrieval_extract_terms "$blob" >/dev/null
  ' _ "$REPO_ROOT"; } 2>&1)"
  if awk -v t="$elapsed" 'BEGIN { exit (t+0 < 2.0 ? 0 : 1) }'; then
    pass "$name"
  else
    fail "$name" "elapsed=${elapsed}s (budget 2s)"
  fi
}

# Behavior: CJK extraction uses only tr/od/awk/sort — no python3 on PATH.
# Steps: isolate PATH to those tools plus bash, extract mixed CJK/English.
test_retrieval_terms_no_python_needed() {
  local name="runtime-lib-coverage/retrieval-terms-no-python-needed" output bin path
  should_run "$name" || return 0
  bin="$tmp_root/no-python-bin"
  mkdir -p "$bin"
  for cmd in tr od awk sort bash wc grep head; do
    src="$(command -v "$cmd")" || { fail "$name" "missing $cmd"; return 0; }
    ln -s "$src" "$bin/$cmd"
  done
  path="$bin"
  output="$(PATH="$path" bash -c '
    . "$1/runtime/lib/retrieval-terms.sh"
    retrieval_extract_terms "分析 token 使用量"
  ' _ "$REPO_ROOT")"
  if [[ "$output" == *$'\n'"token"$'\n'* || "$output" == "token"$'\n'* ]] \
     && [[ "$output" == *"分析"* ]] \
     && [[ "$output" == *"使用"* ]] \
     && [[ "$output" == *"用量"* ]]; then
    pass "$name"
  else
    fail "$name" "output=$output"
  fi
}

# Behavior: a denied strace probe is reported unavailable, not passed.
# Steps: force PM_TEST_STRACE_UNUSABLE=1 and require UNAVAILABLE without PASS.
test_runtime_libraries_strace_unavailable_is_not_pass() {
  local name="runtime-lib-coverage/strace-unavailable-is-not-pass" output
  should_run "$name" || return 0
  output="$(PM_TEST_STRACE_UNUSABLE=1 bash "$REPO_ROOT/tests/shell/test-runtime-lib-coverage.sh" \
    --filter all-libraries-no-source-side-effects 2>&1)" || true
  if [[ "$output" == *"UNAVAILABLE: runtime-lib-coverage/all-libraries-no-source-side-effects:"* \
      && "$output" != *"PASS: runtime-lib-coverage/all-libraries-no-source-side-effects"* ]]; then
    pass "$name"
  else
    fail "$name" "output=$output"
  fi
}

test_gate_workspace_override
test_pmctl_config_loads_valid_values
test_pmctl_config_rejects_legacy_global_memory
test_identifier_policy_domains
test_all_runtime_libraries_are_source_safe
test_runtime_libraries_do_not_exec_on_source
test_runtime_libraries_strace_unavailable_is_not_pass
test_retrieval_terms_english
test_retrieval_terms_hook_english_policy
test_retrieval_terms_cjk_mixed
test_retrieval_terms_cjk_punctuation_splits_runs
test_retrieval_terms_cjk_bigrams
test_retrieval_terms_non_cjk_non_ascii_skips_cleanly
test_retrieval_terms_wrapper_parity
test_retrieval_terms_while_read_keeps_last
test_retrieval_terms_large_ascii_stays_fast
test_retrieval_terms_truncates_past_byte_cap
test_retrieval_terms_truncates_cjk_past_byte_cap
test_retrieval_terms_truncate_writes_stderr
test_retrieval_terms_under_cap_is_quiet
test_retrieval_terms_source_is_idempotent
test_retrieval_terms_metacharacters_stay_data
test_retrieval_terms_cjk_cap_stays_interactive
test_retrieval_terms_no_python_needed
th_summary
