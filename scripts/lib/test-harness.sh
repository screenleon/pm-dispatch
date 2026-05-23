#!/usr/bin/env bash
#
# Shared test harness for scripts/test-*.sh
# Provides a common argument parser, counting helpers, tmp directory lifecycle,
# and summary reporting used by modern-style shell test scripts.

th_init() {
  FILTER=""
  LIST=false
  FORMAT="colon-flat"
  FAIL_FAST=false
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --filter)
        FILTER="${2:-}"
        shift 2
        ;;
      --list)
        LIST=true
        shift
        ;;
      --format=*)
        FORMAT="${1#*=}"
        case "$FORMAT" in
          colon-flat|colon-mixed|indent-1sp|indent-2sp|indent-2sp-quiet)
            ;;
          *)
            printf 'error: unknown --format value %s (valid values: colon-flat, colon-mixed, indent-1sp, indent-2sp, indent-2sp-quiet)\n' "$FORMAT" >&2
            exit 1
            ;;
        esac
        shift
        ;;
      --fail-fast)
        FAIL_FAST=true
        shift
        ;;
      *)
        shift
        ;;
    esac
  done

  tmp_root="$(mktemp -d)"
  trap 'rm -rf "$tmp_root"' EXIT

  PASS=0
  FAIL=0
  FAILED_CASES=()
  ALL_CASES=()
}

should_run() {
  if $LIST; then
    ALL_CASES+=("$1")
    return 1
  fi
  [[ -z "$FILTER" || "$1" == *"$FILTER"* ]]
}

pass() {
  case "$FORMAT" in
    colon-flat|colon-mixed)
      printf 'PASS: %s\n' "$1"
      ;;
    indent-2sp)
      printf '  PASS  %s\n' "$1"
      ;;
    indent-1sp)
      ${VERBOSE:+printf '  PASS %s\n' "$1"}
      ;;
    indent-2sp-quiet)
      ${VERBOSE:+printf '  PASS  %s\n' "$1"}
      ;;
  esac
  PASS=$((PASS + 1))
}

fail() {
  case "$FORMAT" in
    colon-flat)
      printf 'FAIL: %s: %s\n' "$1" "$2"
      ;;
    colon-mixed|indent-2sp)
      printf '  FAIL  %s\n' "$1"
      [[ -n "${2:-}" ]] && printf '        %s\n' "$2"
      ;;
    indent-1sp)
      printf '  FAIL %s\n' "$1"
      [[ -n "${2:-}" ]] && printf '        %s\n' "$2"
      ;;
    indent-2sp-quiet)
      printf '  FAIL  %s\n' "$1"
      [[ -n "${2:-}" ]] && printf '%s\n' "$2"
      ;;
  esac
  FAIL=$((FAIL + 1))
  FAILED_CASES+=("$1")
  if $FAIL_FAST; then
    th_summary
  fi
}

th_summary() {
  if $LIST; then
    printf '%s\n' "${ALL_CASES[@]}"
    exit 0
  fi

  if [[ -n "$FILTER" && $((PASS + FAIL)) -eq 0 ]]; then
    printf 'no tests matched filter %s\n' "$FILTER" >&2
    exit 1
  fi

  printf '%s passed, %s failed\n' "$PASS" "$FAIL"
  if [[ "${#FAILED_CASES[@]}" -gt 0 ]]; then
    printf 'failed cases: %s\n' "${FAILED_CASES[*]}" >&2
  fi

  if [[ "$FAIL" -gt 0 ]]; then
    exit 1
  fi
  exit 0
}
