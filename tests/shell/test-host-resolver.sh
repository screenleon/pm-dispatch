#!/usr/bin/env bash
# Conformance tests for the shared host config-root resolver primitives.
#
# host_simple_config_root (runtime/lib/host-resolver.sh) is the parameterised
# body extracted from the byte-identical codex/grok/opencode *_host_config_root
# functions. These tests assert:
#   - the three simple hosts resolve identically modulo their (label, env,
#     subdir) parameters: primary env wins verbatim; else $HOME/<subdir>; else
#     exit 2 with a labelled diagnostic;
#   - the shared file never branches on a host name (no host-named case/literal);
#   - Claude keeps its own dual-var resolver (canonical/legacy conflict,
#     precedence, HOME fallback) and does NOT route through the shared primitive.
#
# Runs via: tests/shell/test-host-resolver.sh
# Filter:   tests/shell/test-host-resolver.sh --filter <pattern>
# List:     tests/shell/test-host-resolver.sh --list

set -euo pipefail
export LC_ALL=C.UTF-8

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=tests/lib/test-harness.sh disable=SC1091
. "$SCRIPT_DIR/../lib/test-harness.sh"
th_init "test-host-resolver" "$@"

# Suite-owned scratch dir for per-call stderr capture (mirrors the idiom in
# test-host-manifest.sh). Every helper writes diagnostics to a unique file
# under here so concurrent suite processes never share a capture path.
tmp_root="$(mktemp -d "${TMPDIR:-/tmp}/test-host-resolver-XXXXXX")"
trap 'rm -rf "$tmp_root"' EXIT

RESOLVER_LIB="$REPO_ROOT/runtime/lib/host-resolver.sh"
CLAUDE_RESOLVER="$REPO_ROOT/hosts/claude/lib/path-resolver.sh"

# Run one host_simple_config_root call in a clean subshell with a controlled
# environment. Args: <label> <env_name> <env_value|-> <home_value|-> <subdir>
# A value of "-" unsets that variable. Prints "rc<TAB>stdout<TAB>stderr".
_run_simple() {
  local label="$1" env_name="$2" env_val="$3" home_val="$4" subdir="$5"
  local out err rc=0
  local -a env_args=()
  if [[ "$env_val" == "-" ]]; then env_args+=("--unset=$env_name"); else env_args+=("$env_name=$env_val"); fi
  if [[ "$home_val" == "-" ]]; then env_args+=("--unset=HOME"); else env_args+=("HOME=$home_val"); fi
  local errfile
  errfile="$(mktemp "$tmp_root/hsr-err.XXXXXX")"
  # shellcheck disable=SC2016  # $1..$4 are for the inner `bash -c`, not this shell
  out="$(env "${env_args[@]}" bash -c '
    set -euo pipefail
    . "$1"
    host_simple_config_root "$2" "$3" "$4"
  ' _ "$RESOLVER_LIB" "$label" "$env_name" "$subdir" 2>"$errfile")" && rc=0 || rc=$?
  err="$(cat "$errfile" 2>/dev/null || true)"
  rm -f "$errfile"
  printf '%s\t%s\t%s' "$rc" "$out" "$err"
}

# --- simple-resolver parity: table-driven over the three simple hosts ---------
# label  env_name          default_subdir
SIMPLE_HOSTS=(
  "codex CODEX_HOME .codex"
  "grok GROK_HOME .grok"
  "opencode XDG_CONFIG_HOME .config"
)

for row in "${SIMPLE_HOSTS[@]}"; do
  # shellcheck disable=SC2086
  set -- $row
  label="$1" env_name="$2" subdir="$3"

  name="host-resolver: $label — primary env is returned verbatim"
  if should_run "$name"; then
    res="$(_run_simple "$label" "$env_name" "/custom/$label/root" "/home/u" "$subdir")"
    rc="${res%%$'\t'*}"; rest="${res#*$'\t'}"; out="${rest%%$'\t'*}"
    if [[ "$rc" == "0" && "$out" == "/custom/$label/root" ]]; then
      pass "$name"
    else
      fail "$name" "rc=$rc out=$out (expected 0 / /custom/$label/root)"
    fi
  fi

  name="host-resolver: $label — falls back to \$HOME/$subdir when env unset"
  if should_run "$name"; then
    res="$(_run_simple "$label" "$env_name" "-" "/home/u" "$subdir")"
    rc="${res%%$'\t'*}"; rest="${res#*$'\t'}"; out="${rest%%$'\t'*}"
    if [[ "$rc" == "0" && "$out" == "/home/u/$subdir" ]]; then
      pass "$name"
    else
      fail "$name" "rc=$rc out=$out (expected 0 / /home/u/$subdir)"
    fi
  fi

  name="host-resolver: $label — exit 2 with labelled diagnostic when env and HOME unset"
  if should_run "$name"; then
    res="$(_run_simple "$label" "$env_name" "-" "-" "$subdir")"
    rc="${res%%$'\t'*}"; rest="${res#*$'\t'}"; err="${rest#*$'\t'}"
    if [[ "$rc" == "2" && "$err" == "$label path resolver: HOME is required when $env_name is unset or empty" ]]; then
      pass "$name"
    else
      fail "$name" "rc=$rc err=[$err]"
    fi
  fi

  name="host-resolver: $label — empty env string is treated as unset"
  if should_run "$name"; then
    res="$(_run_simple "$label" "$env_name" "" "/home/u" "$subdir")"
    rc="${res%%$'\t'*}"; rest="${res#*$'\t'}"; out="${rest%%$'\t'*}"
    if [[ "$rc" == "0" && "$out" == "/home/u/$subdir" ]]; then
      pass "$name"
    else
      fail "$name" "rc=$rc out=$out (expected 0 / /home/u/$subdir)"
    fi
  fi
done

# --- structural: shared file must not branch on a host name ------------------
name="host-resolver: shared file names no host in code"
if should_run "$name"; then
  # Strip comments, then look for a host literal or a case statement.
  code="$(grep -vE '^\s*#' "$RESOLVER_LIB" || true)"
  if grep -qE '\b(codex|grok|opencode|claude|generic)\b' <<<"$code" \
     || grep -qE '(^|\s)case\s' <<<"$code"; then
    fail "$name" "host-resolver.sh branches on a host name or uses case; it must stay fully parameterised"
  else
    pass "$name"
  fi
fi

# --- Claude keeps its own dual-var resolver ---------------------------------
name="host-resolver: claude resolver does not call host_simple_config_root"
if should_run "$name"; then
  if grep -q 'host_simple_config_root' "$CLAUDE_RESOLVER"; then
    fail "$name" "claude must keep its canonical/legacy dual-var algorithm (CC-538 Req 1)"
  else
    pass "$name"
  fi
fi

_run_claude() {
  # args: <CLAUDE_CONFIG_DIR|-> <CLAUDE_HOME|-> <HOME|->  -> "rc<TAB>out<TAB>err"
  local ccd="$1" chome="$2" home="$3" out err rc=0
  local -a env_args=()
  [[ "$ccd" == "-" ]] && env_args+=("--unset=CLAUDE_CONFIG_DIR") || env_args+=("CLAUDE_CONFIG_DIR=$ccd")
  [[ "$chome" == "-" ]] && env_args+=("--unset=CLAUDE_HOME") || env_args+=("CLAUDE_HOME=$chome")
  [[ "$home" == "-" ]] && env_args+=("--unset=HOME") || env_args+=("HOME=$home")
  local errfile
  errfile="$(mktemp "$tmp_root/hcr-err.XXXXXX")"
  # shellcheck disable=SC2016  # $1 is for the inner `bash -c`, not this shell
  out="$(env "${env_args[@]}" bash -c '
    set -euo pipefail
    . "$1"
    claude_host_config_root
  ' _ "$CLAUDE_RESOLVER" 2>"$errfile")" && rc=0 || rc=$?
  err="$(cat "$errfile" 2>/dev/null || true)"
  rm -f "$errfile"
  printf '%s\t%s\t%s' "$rc" "$out" "$err"
}

name="host-resolver: claude — canonical CLAUDE_CONFIG_DIR wins"
if should_run "$name"; then
  res="$(_run_claude /a/config /a/config /home/u)"
  rc="${res%%$'\t'*}"; rest="${res#*$'\t'}"; out="${rest%%$'\t'*}"
  if [[ "$rc" == "0" && "$out" == "/a/config" ]]; then pass "$name"; else fail "$name" "rc=$rc out=$out"; fi
fi

name="host-resolver: claude — legacy CLAUDE_HOME used when canonical unset"
if should_run "$name"; then
  res="$(_run_claude - /legacy/home /home/u)"
  rc="${res%%$'\t'*}"; rest="${res#*$'\t'}"; out="${rest%%$'\t'*}"
  if [[ "$rc" == "0" && "$out" == "/legacy/home" ]]; then pass "$name"; else fail "$name" "rc=$rc out=$out"; fi
fi

name="host-resolver: claude — disagreeing canonical and legacy vars fail with exit 2"
if should_run "$name"; then
  res="$(_run_claude /a/config /b/home /home/u)"
  rc="${res%%$'\t'*}"; rest="${res#*$'\t'}"; err="${rest#*$'\t'}"
  if [[ "$rc" == "2" && "$err" == *"disagree"* ]]; then pass "$name"; else fail "$name" "rc=$rc err=[$err]"; fi
fi

name="host-resolver: claude — \$HOME/.claude fallback when both vars unset"
if should_run "$name"; then
  res="$(_run_claude - - /home/u)"
  rc="${res%%$'\t'*}"; rest="${res#*$'\t'}"; out="${rest%%$'\t'*}"
  if [[ "$rc" == "0" && "$out" == "/home/u/.claude" ]]; then pass "$name"; else fail "$name" "rc=$rc out=$out"; fi
fi

name="host-resolver: claude — exit 2 when both vars and HOME unset"
if should_run "$name"; then
  res="$(_run_claude - - -)"
  rc="${res%%$'\t'*}"; rest="${res#*$'\t'}"; err="${rest#*$'\t'}"
  if [[ "$rc" == "2" && "$err" == *"HOME is required"* ]]; then pass "$name"; else fail "$name" "rc=$rc err=[$err]"; fi
fi

# --- concurrency: overlapping missing-HOME failures keep isolated diagnostics -
# Regression guard against a shared stderr-capture path. Fan out N background
# subshells, each running the codex exit-2 branch (env + HOME both unset); each
# writes "<rc>|<diagnostic>" to its own file. Every file must show rc 2 and the
# codex label only — never a blank capture or another job's message.
name="host-resolver: concurrent missing-HOME failures keep isolated diagnostics"
if should_run "$name"; then
  cdir="$(mktemp -d "$tmp_root/conc.XXXXXX")"
  ji=0
  while [[ "$ji" -lt 12 ]]; do
    ji=$((ji + 1))
    (
      res="$(_run_simple codex CODEX_HOME - - .codex)"
      jrc="${res%%$'\t'*}"; jerr="${res##*$'\t'}"
      printf '%s|%s' "$jrc" "$jerr" > "$cdir/job-$ji"
    ) &
  done
  wait
  bad=""
  for f in "$cdir"/job-*; do
    line="$(cat "$f")"
    jrc="${line%%|*}"; jerr="${line#*|}"
    if [[ "$jrc" != "2" ]]; then bad="rc=$jrc in ${f##*/}"; break; fi
    if [[ "$jerr" != "codex path resolver: HOME is required when CODEX_HOME is unset or empty" ]]; then
      bad="wrong/blank diagnostic [$jerr] in ${f##*/}"; break
    fi
  done
  if [[ -z "$bad" ]]; then pass "$name"; else fail "$name" "$bad"; fi
fi

th_summary
