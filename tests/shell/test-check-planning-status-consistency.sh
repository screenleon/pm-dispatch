#!/usr/bin/env bash
# Regression tests for the BACKLOG<->MILESTONES status-drift checker.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CHECKER="$REPO_ROOT/tools/lint/check-planning-status-consistency.sh"

# shellcheck source=tests/lib/test-harness.sh
# shellcheck disable=SC1091
. "$SCRIPT_DIR/../lib/test-harness.sh"
th_init "$@"

# Build a fixture with a BACKLOG index and a MILESTONES ticket table.
# $1 = fixture name; $2 = the MILESTONES status cell for CC-002 (the row under test).
make_fixture() {
  local name="$1" cc2_cell="$2" root
  # shellcheck disable=SC2154  # tmp_root is initialized by th_init.
  root="$tmp_root/$name"
  mkdir -p "$root"
  cat > "$root/BACKLOG.md" <<'EOF'
# backlog

## Index

| #  | Status | 主題 | 影響面 | 首次記錄 | Refs | Priority | Epic |
|----|--------|------|--------|----------|------|----------|------|
| CC-001 | 🔵 active | live one | ops | 2026-01-01 | — | P2 | — |
| CC-002 | ✅ done | shipped one | ops | 2026-01-01 | pr:#10 | P2 | — |
| CC-003 | 🟢 someday | parked one | ops | 2026-01-01 | — | P3 | — |
EOF
  cat > "$root/MILESTONES.md" <<EOF
# milestones

## v0.9.0 (delivered)

| 票 | 摘要 | 狀態 |
|----|------|------|
| CC-900 | archived history row | ✅ pr:#5 |

## v0.11.0 (live)

| 票 | 摘要 | 狀態 |
|----|------|------|
| CC-001 | live one | 🔵 |
| CC-002 | shipped one | ${cc2_cell} |
| CC-003 | parked one | ⏸ deferred |
EOF
  printf '%s' "$root"
}

run_checker() { bash "$CHECKER" --repo-root "$1" 2>&1; }

name="planning-status/consistent tree passes"
if should_run "$name"; then
  root="$(make_fixture consistent '✅ pr:#10')"
  if out="$(run_checker "$root")" && [[ "$out" == *"3 live MILESTONES ticket rows agree"* ]]; then
    pass "$name"
  else
    fail "$name" "rc=$? out=$out"
  fi
fi

name="planning-status/BACKLOG done but MILESTONES partial fails"
if should_run "$name"; then
  root="$(make_fixture drift-partial '⚠️ partial (pr:#10)')"
  if out="$(run_checker "$root")"; then
    fail "$name" "expected failure, got pass: $out"
  elif [[ "$out" == *"CC-002 is terminal (done/closed/dropped/superseded) in BACKLOG.md but MILESTONES.md still shows"* ]]; then
    pass "$name"
  else
    fail "$name" "wrong diagnostic: $out"
  fi
fi

name="planning-status/BACKLOG done but MILESTONES active fails"
if should_run "$name"; then
  root="$(make_fixture drift-active '🔵')"
  if run_checker "$root" >/dev/null 2>&1; then
    fail "$name" "expected failure, got pass"
  else
    pass "$name"
  fi
fi

name="planning-status/MILESTONES done but BACKLOG open fails"
if should_run "$name"; then
  root="$(make_fixture drift-reverse '✅ pr:#10')"
  # flip CC-002 to open in BACKLOG so MILESTONES ✅ overclaims
  sed -i 's/| CC-002 | ✅ done |/| CC-002 | 🔵 active |/' "$root/BACKLOG.md"
  if out="$(run_checker "$root")"; then
    fail "$name" "expected failure, got pass: $out"
  elif [[ "$out" == *"MILESTONES claims completion the authority does not"* ]]; then
    pass "$name"
  else
    fail "$name" "wrong diagnostic: $out"
  fi
fi

name="planning-status/✅ slice is not treated as completion"
if should_run "$name"; then
  root="$(make_fixture slice-ok '✅ slice (#10)')"
  sed -i 's/| CC-002 | ✅ done |/| CC-002 | ⏸ deferred |/' "$root/BACKLOG.md"
  if run_checker "$root" >/dev/null 2>&1; then
    pass "$name"
  else
    fail "$name" "slice row should not trip the overclaim rule"
  fi
fi

name="planning-status/archived MILESTONES rows are skipped"
if should_run "$name"; then
  # CC-900 is ✅ in MILESTONES history and absent from the BACKLOG index — must not error.
  root="$(make_fixture archived '✅ pr:#10')"
  if out="$(run_checker "$root")" && [[ "$out" != *"CC-900"* ]]; then
    pass "$name"
  else
    fail "$name" "archived row was not skipped: $out"
  fi
fi

name="planning-status/missing input file exits non-zero"
if should_run "$name"; then
  root="$tmp_root/no-milestones"; mkdir -p "$root"
  printf '# backlog\n' > "$root/BACKLOG.md"
  if run_checker "$root" >/dev/null 2>&1; then
    fail "$name" "expected non-zero for missing MILESTONES.md"
  else
    pass "$name"
  fi
fi

name="planning-status/readable BACKLOG with no CC rows fails closed"
if should_run "$name"; then
  # The BACKLOG parse guard must be mutation-sensitive: a present, readable
  # BACKLOG.md that yields zero CC rows is a format break, not "nothing to check".
  root="$(make_fixture no-cc-rows '✅ pr:#10')"
  printf '# backlog\n\n## Index\n\n| # | Status |\n|---|---|\n' > "$root/BACKLOG.md"
  if out="$(run_checker "$root")"; then
    fail "$name" "expected non-zero, got pass: $out"
  elif [[ "$out" == *"parsed no CC rows from BACKLOG.md index"* ]]; then
    pass "$name"
  else
    fail "$name" "wrong diagnostic: $out"
  fi
fi

name="planning-status/unrecognised MILESTONES marker on open ticket fails"
if should_run "$name"; then
  root="$(make_fixture bad-marker 'pending')"   # CC-002 open in BACKLOG, unknown marker here
  sed -i 's/| CC-002 | ✅ done |/| CC-002 | 🔵 active |/' "$root/BACKLOG.md"
  if out="$(run_checker "$root")"; then
    fail "$name" "expected non-zero, got pass: $out"
  elif [[ "$out" == *"CC-002 has an unrecognised MILESTONES status marker"* ]]; then
    pass "$name"
  else
    fail "$name" "wrong diagnostic: $out"
  fi
fi

name="planning-status/every terminal BACKLOG status vs an open milestone row fails"
if should_run "$name"; then
  ok=1
  # pm/schema.md terminal set — each must be treated as "done" authority.
  for bstat in '✅ done' '✅ closed 2026-01-01' '🚫 dropped 2026-01-01' '🟢 superseded 2026-01-01'; do
    root="$(make_fixture "term-$RANDOM" '🔵')"   # MILESTONES CC-002 is open
    sed -i "s/| CC-002 | ✅ done |/| CC-002 | ${bstat} |/" "$root/BACKLOG.md"
    if out="$(run_checker "$root")"; then
      ok=0; fail "$name" "[$bstat] not treated as terminal: $out"; break
    elif [[ "$out" != *"terminal"* ]]; then
      ok=0; fail "$name" "[$bstat] wrong diagnostic: $out"; break
    fi
  done
  # ...and 🟢 superseded must NOT be confused with the open 🟢 someday form
  root="$(make_fixture someday-open '🔵')"
  sed -i 's/| CC-002 | ✅ done |/| CC-002 | 🟢 someday |/' "$root/BACKLOG.md"
  run_checker "$root" >/dev/null 2>&1 || { ok=0; fail "$name" "🟢 someday (open) mis-classified as terminal"; }
  [[ "$ok" -eq 1 ]] && pass "$name"
fi

name="planning-status/unrecognised BACKLOG status fails closed"
if should_run "$name"; then
  root="$(make_fixture bad-backlog '✅ pr:#10')"
  sed -i 's/| CC-002 | ✅ done |/| CC-002 | ⏳ waiting |/' "$root/BACKLOG.md"
  if out="$(run_checker "$root")"; then
    fail "$name" "expected non-zero, got pass: $out"
  elif [[ "$out" == *"unrecognised BACKLOG.md index status"* ]]; then
    pass "$name"
  else
    fail "$name" "wrong diagnostic: $out"
  fi
fi

name="planning-status/malformed CLI invocation exits 2 with usage"
if should_run "$name"; then
  ok=1
  # Each malformed form must exit 2, print usage, and never reach repo parsing.
  good="$(make_fixture cli-good '✅ pr:#10')"
  run_argv() {  # prints "rc<TAB>out"
    local out rc
    out="$(bash "$CHECKER" "$@" 2>&1)"; rc=$?
    printf '%s\t%s' "$rc" "$out"
  }
  declare -a res=(); i=0
  res[i++]="$(run_argv --repo-root)"                 # missing value
  res[i++]="$(run_argv --repo-root '')"              # empty value
  res[i++]="$(run_argv --repo-root "$good" extra)"   # extra argument
  res[i++]="$(run_argv --bogus "$good")"             # unknown option
  for r in "${res[@]}"; do
    rc="${r%%$'\t'*}"; out="${r#*$'\t'}"
    if [[ "$rc" -ne 2 ]] || [[ "$out" != *"usage:"* ]] || [[ "$out" == *"MILESTONES ticket rows agree"* ]]; then
      ok=0; fail "$name" "rc=$rc out=$out"; break
    fi
  done
  [[ "$ok" -eq 1 ]] && pass "$name"
fi

name="planning-status/every documented open/done/dropped/slice marker is accepted"
if should_run "$name"; then
  ok=1
  for m in '🔵' '⚠️ partial (pr:#10)' '⏸ deferred' '🟡 someday' '✅ slice (#10)'; do
    root="$(make_fixture "marker-$RANDOM" "$m")"
    sed -i 's/| CC-002 | ✅ done |/| CC-002 | 🔵 active |/' "$root/BACKLOG.md"
    run_checker "$root" >/dev/null 2>&1 || { ok=0; fail "$name" "open-form marker [$m] rejected"; break; }
  done
  for m in '✅ pr:#10' '✅ 2026-08-01' '🚫 dropped 2026-01-01'; do
    root="$(make_fixture "marker-$RANDOM" "$m")"   # CC-002 stays ✅ done in BACKLOG
    run_checker "$root" >/dev/null 2>&1 || { ok=0; fail "$name" "done-form marker [$m] rejected"; break; }
  done
  [[ "$ok" -eq 1 ]] && pass "$name"
fi

th_summary

