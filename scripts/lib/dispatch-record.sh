#!/usr/bin/env bash
# Durable per-run dispatch result writer.

dispatch_record_write() {
  local run_id="${1:-}" task_id="${2:-}" executor="${3:-}" model="${4:-}" brief_file="${5:-}"
  local working_dir="${6:-}" exit_code="${7:-}" final_state="${8:-}" verify_summary="${9:-}"
  local last_path="${10:-}" trace_path="${11:-}" stderr_path="${12:-}"
  local created_ts="${13:-}" finished_ts="${14:-}"
  local result_dir result_path tmp
  local q_run_id q_task_id q_executor q_model q_brief_file q_working_dir
  local q_final_state q_verify_summary q_last_path q_trace_path q_stderr_path
  local q_created_ts q_finished_ts

  [[ -n "$run_id" ]] || return 1
  [[ -n "$working_dir" ]] || return 1
  [[ "$exit_code" =~ ^-?[0-9]+$ ]] || return 1
  case "$final_state" in ok|failed|partial) : ;; *) return 1 ;; esac

  result_dir="$working_dir/.dispatch-results"
  result_path="$result_dir/$run_id.md"
  mkdir -p "$result_dir" || return 1
  tmp="$(mktemp "$result_dir/.$run_id.tmp.XXXXXX")" || return 1

  q_run_id="$(printf '%s' "$run_id" | jq -Rs .)" || { rm -f "$tmp"; return 1; }
  q_task_id="$(printf '%s' "$task_id" | jq -Rs .)" || { rm -f "$tmp"; return 1; }
  q_executor="$(printf '%s' "$executor" | jq -Rs .)" || { rm -f "$tmp"; return 1; }
  q_model="$(printf '%s' "$model" | jq -Rs .)" || { rm -f "$tmp"; return 1; }
  q_brief_file="$(printf '%s' "$brief_file" | jq -Rs .)" || { rm -f "$tmp"; return 1; }
  q_working_dir="$(printf '%s' "$working_dir" | jq -Rs .)" || { rm -f "$tmp"; return 1; }
  q_final_state="$(printf '%s' "$final_state" | jq -Rs .)" || { rm -f "$tmp"; return 1; }
  q_verify_summary="$(printf '%s' "$verify_summary" | jq -Rs .)" || { rm -f "$tmp"; return 1; }
  q_last_path="$(printf '%s' "$last_path" | jq -Rs .)" || { rm -f "$tmp"; return 1; }
  q_trace_path="$(printf '%s' "$trace_path" | jq -Rs .)" || { rm -f "$tmp"; return 1; }
  q_stderr_path="$(printf '%s' "$stderr_path" | jq -Rs .)" || { rm -f "$tmp"; return 1; }
  q_created_ts="$(printf '%s' "$created_ts" | jq -Rs .)" || { rm -f "$tmp"; return 1; }
  q_finished_ts="$(printf '%s' "$finished_ts" | jq -Rs .)" || { rm -f "$tmp"; return 1; }

  # Backticks in the printf format strings below are literal Markdown code spans,
  # not command substitution — single quotes keep them literal as intended.
  # shellcheck disable=SC2016
  {
    printf '%s\n' '---'
    printf 'schema_version: 1\n'
    printf 'run_id: %s\n' "$q_run_id"
    printf 'task_id: %s\n' "$q_task_id"
    printf 'executor: %s\n' "$q_executor"
    printf 'model: %s\n' "$q_model"
    printf 'brief_file: %s\n' "$q_brief_file"
    printf 'working_dir: %s\n' "$q_working_dir"
    printf 'exit_code: %s\n' "$exit_code"
    printf 'final_state: %s\n' "$q_final_state"
    printf 'verify_summary: %s\n' "$q_verify_summary"
    printf 'last_path: %s\n' "$q_last_path"
    printf 'trace_path: %s\n' "$q_trace_path"
    printf 'stderr_path: %s\n' "$q_stderr_path"
    printf 'created_ts: %s\n' "$q_created_ts"
    printf 'finished_ts: %s\n' "$q_finished_ts"
    printf '%s\n\n' '---'
    printf '# Dispatch Result\n\n'
    printf 'Run `%s` finished with state `%s` and exit code `%s`.\n\n' "$run_id" "$final_state" "$exit_code"
    printf -- '- Task: `%s`\n' "${task_id:-}"
    printf -- '- Executor: `%s`\n' "$executor"
    printf -- '- Model: `%s`\n' "${model:-}"
    printf -- '- Brief: `%s`\n' "$brief_file"
    printf -- '- Last: `%s`\n' "${last_path:-}"
    printf -- '- Trace: `%s`\n' "${trace_path:-}"
    printf -- '- Stderr: `%s`\n\n' "${stderr_path:-}"
    printf '## Verify Summary\n\n'
    if [[ -n "$verify_summary" ]]; then
      printf '%s\n' "$verify_summary"
    else
      printf '(not run)\n'
    fi
  } > "$tmp" || { rm -f "$tmp"; return 1; }

  mv -f "$tmp" "$result_path" || { rm -f "$tmp"; return 1; }
}
