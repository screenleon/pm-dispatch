#!/usr/bin/env bash
# Run ShellCheck over the canonical shell domains and bounded compatibility shims.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
list_only=0

usage() {
  printf 'usage: %s [--repo <path>] [--list]\n' "$0"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)
      [[ $# -ge 2 && -n "$2" ]] || { usage >&2; exit 2; }
      repo_root="$2"
      shift 2
      ;;
    --list)
      list_only=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'lint-shellcheck: unknown argument: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

domains="$repo_root/tools/lint/shellcheck-domains.tsv"
ignores="$repo_root/tools/lint/shellcheck-ignores.tsv"
expected_domains=$'root\trole\nruntime\tcanonical\ntests\tcanonical\ntools\tcanonical\nops\tcanonical\nhosts\tcanonical\nscripts\tcompatibility'

[[ -f "$domains" ]] || { printf 'lint-shellcheck: missing tools/lint/shellcheck-domains.tsv\n' >&2; exit 1; }
[[ -f "$ignores" ]] || { printf 'lint-shellcheck: missing tools/lint/shellcheck-ignores.tsv\n' >&2; exit 1; }
[[ "$(cat "$domains")" == "$expected_domains" ]] || {
  printf 'lint-shellcheck: domain inventory must contain the five canonical roots and scripts compatibility root\n' >&2
  exit 1
}
[[ "$(head -n1 "$ignores")" == $'path\tcodes\treason' ]] || {
  printf 'lint-shellcheck: ignore inventory header must be path<TAB>codes<TAB>reason\n' >&2
  exit 1
}

declare -A ignored=()
ignore_errors=0
while IFS=$'\t' read -r path codes reason extra; do
  [[ "$path" != path ]] || continue
  if [[ -z "$path" || -z "$codes" || -z "$reason" || -n "${extra:-}" ]]; then
    printf 'lint-shellcheck: every ignore must be an exact path with codes and one reason slug\n' >&2
    ignore_errors=$((ignore_errors + 1))
    continue
  fi
  case "$path" in
    runtime/*.sh|tests/*.sh|tools/*.sh|ops/*.sh|hosts/*.sh) ;;
    *)
      printf 'lint-shellcheck: ignore is not a canonical shell path: %s\n' "$path" >&2
      ignore_errors=$((ignore_errors + 1))
      continue
      ;;
  esac
  if [[ ! "$codes" =~ ^SC[0-9]{4}(,SC[0-9]{4})*$ ]]; then
    printf 'lint-shellcheck: invalid ignore codes for %s: %s\n' "$path" "$codes" >&2
    ignore_errors=$((ignore_errors + 1))
  elif [[ ! "$reason" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
    printf 'lint-shellcheck: invalid ignore reason for %s: %s\n' "$path" "$reason" >&2
    ignore_errors=$((ignore_errors + 1))
  elif [[ ! -f "$repo_root/$path" ]]; then
    printf 'lint-shellcheck: stale ignore path does not exist: %s\n' "$path" >&2
    ignore_errors=$((ignore_errors + 1))
  elif [[ -n "${ignored[$path]:-}" ]]; then
    printf 'lint-shellcheck: duplicate ignore path: %s\n' "$path" >&2
    ignore_errors=$((ignore_errors + 1))
  else
    ignored["$path"]="$codes"
  fi
done < "$ignores"
[[ "$ignore_errors" -eq 0 ]] || exit 1

declare -a all_files=()
while IFS=$'\t' read -r root _; do
  [[ "$root" != root ]] || continue
  [[ -d "$repo_root/$root" ]] || {
    printf 'lint-shellcheck: missing domain root: %s\n' "$root" >&2
    exit 1
  }
  while IFS= read -r -d '' file; do
    all_files+=("$file")
  done < <(find "$repo_root/$root" -type f -name '*.sh' -print0 | sort -z)
done < "$domains"

[[ "${#all_files[@]}" -gt 0 ]] || {
  printf 'lint-shellcheck: no shell files discovered\n' >&2
  exit 1
}

if [[ "$list_only" -eq 1 ]]; then
  for file in "${all_files[@]}"; do
    printf '%s\n' "${file#"$repo_root"/}"
  done
  exit 0
fi

command -v shellcheck >/dev/null 2>&1 || {
  printf 'lint-shellcheck: shellcheck is required\n' >&2
  exit 2
}

jobs="${PM_DISPATCH_SHELLCHECK_JOBS:-2}"
[[ "$jobs" =~ ^[1-8]$ ]] || {
  printf 'lint-shellcheck: PM_DISPATCH_SHELLCHECK_JOBS must be an integer from 1 to 8\n' >&2
  exit 2
}

shellcheck_file() {
  local file="$1" relative codes
  relative="${file#"$repo_root"/}"
  codes="${ignored[$relative]:-}"
  if [[ -n "$codes" ]]; then
    (cd "$repo_root" && shellcheck --severity=style --exclude="$codes" "$file")
  else
    (cd "$repo_root" && shellcheck --severity=style "$file")
  fi
}

declare -a worker_pids=()
failures=0
for file in "${all_files[@]}"; do
  shellcheck_file "$file" &
  worker_pids+=("$!")
  if [[ "${#worker_pids[@]}" -ge "$jobs" ]]; then
    if ! wait "${worker_pids[0]}"; then failures=$((failures + 1)); fi
    worker_pids=("${worker_pids[@]:1}")
  fi
done
for worker_pid in "${worker_pids[@]}"; do
  if ! wait "$worker_pid"; then failures=$((failures + 1)); fi
done
[[ "$failures" -eq 0 ]] || exit 1
printf 'lint-shellcheck: OK (%s shell files checked, %s code-scoped suppressions)\n' \
  "${#all_files[@]}" "${#ignored[@]}"
