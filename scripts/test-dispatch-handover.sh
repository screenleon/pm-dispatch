#!/usr/bin/env bash
# Regression tests for codex_dispatch_handover_v1 extraction and validation.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$REPO_ROOT/scripts/lib/handover-validate.sh"

PASS=0
FAIL=0

t_pass() { printf 'PASS: %s\n' "$1"; PASS=$((PASS+1)); }
t_fail() { printf 'FAIL: %s\n' "$1" >&2; FAIL=$((FAIL+1)); }

make_tmpdir() {
  mktemp -d -t dispatch-handover.XXXXXX
}

extract_handover() {
  local input_file=$1
  local meta_out=$2
  local body_out=$3

  : > "$meta_out"
  : > "$body_out"

  awk -v meta="$meta_out" -v body="$body_out" '
    BEGIN { in_block = 0; in_body = 0; found = 0 }
    /^```codex_dispatch_handover_v1$/ { in_block = 1; found = 1; next }
    in_block && /^```$/ { exit }
    in_block && !in_body && /^---$/ { in_body = 1; next }
    in_block && in_body { print > body; next }
    in_block { print > meta; next }
    END { if (!found) exit 0 }
  ' "$input_file"
}

meta_value() {
  local field=$1
  local meta_file=$2

  awk -F': ' -v key="$field" '$1 == key { print substr($0, length(key) + 3); exit }' "$meta_file"
}

body_working_dir() {
  local body_file=$1

  awk -F': ' '$1 == "working_dir" { print substr($0, length("working_dir") + 3); exit }' "$body_file"
}

validate_contract() {
  local meta_file=$1
  local body_file=$2
  local value
  local field
  local route
  local meta_wd
  local body_wd

  for field in handover_version dispatch_route working_dir brief_file sandbox approval timeout model skip_git_check fallback_allowed; do
    value="$(meta_value "$field" "$meta_file")"
    [[ -n "$value" ]] || { printf 'missing metadata field: %s\n' "$field" >&2; return 1; }
    handover_validate_metadata_value "$field" "$value" >/dev/null || return 1
  done

  route="$(meta_value dispatch_route "$meta_file")"
  case "$route" in
    main_thread_bash_background|agent_codex_executor) ;;
    *) printf 'unknown dispatch_route: %s\n' "$route" >&2; return 1;;
  esac

  meta_wd="$(meta_value working_dir "$meta_file")"
  body_wd="$(body_working_dir "$body_file")"
  [[ -n "$body_wd" ]] || { printf 'missing body working_dir\n' >&2; return 1; }
  [[ "$meta_wd" == "$body_wd" ]] || {
    printf 'working_dir mismatch: metadata=%s body=%s\n' "$meta_wd" "$body_wd" >&2
    return 1
  }
}

parse_footer() {
  local stdout_file=$1
  local out_file=$2

  awk '
    /^trace:[[:space:]]+/ { sub(/^trace:[[:space:]]+/, "trace="); print; next }
    /^last:[[:space:]]+/ { sub(/^last:[[:space:]]+/, "last="); print; next }
    /^stderr:[[:space:]]+/ { sub(/^stderr:[[:space:]]+/, "stderr="); print; next }
    /^exit:[[:space:]]+/ { sub(/^exit:[[:space:]]+/, "exit="); print; next }
  ' "$stdout_file" > "$out_file"
}

write_valid_handover() {
  local out=$1
  local work_dir=$2
  local brief_file=$3

  cat > "$out" <<EOF
PM summary outside fence.

\`\`\`codex_dispatch_handover_v1
handover_version: 1
dispatch_route: main_thread_bash_background
working_dir: $work_dir
brief_file: $brief_file
sandbox: workspace-write
approval: never
timeout: 1200
model: default
skip_git_check: false
fallback_allowed: true
---
working_dir: $work_dir
goal: Confirm handover extraction.
files:
  - read: README.md
acceptance:
  - Handover extracts cleanly.
\`\`\`
EOF
}

# ---- 1: valid handover extracts metadata and body ----
tmp1="$(make_tmpdir)"
input1="$tmp1/input.md"
meta1="$tmp1/meta.txt"
body1="$tmp1/body.md"
write_valid_handover "$input1" "$REPO_ROOT" "/tmp/brief-pm-dispatch-test-1.md"
extract_handover "$input1" "$meta1" "$body1"
if [[ "$(meta_value working_dir "$meta1")" == "$REPO_ROOT" ]] \
  && [[ "$(meta_value brief_file "$meta1")" == "/tmp/brief-pm-dispatch-test-1.md" ]] \
  && grep -q '^goal: Confirm handover extraction\.$' "$body1" \
  && validate_contract "$meta1" "$body1" >/dev/null 2>&1; then
  t_pass "handover/valid block extracts metadata and body"
else
  t_fail "handover/valid block extraction failed"
fi
rm -rf "$tmp1"

# ---- 2: metadata/body working_dir mismatch rejects ----
tmp2="$(make_tmpdir)"
input2="$tmp2/input.md"
meta2="$tmp2/meta.txt"
body2="$tmp2/body.md"
write_valid_handover "$input2" "$REPO_ROOT" "/tmp/brief-pm-dispatch-test-2.md"
sed -i '0,/^working_dir: /! s|^working_dir: .*|working_dir: /tmp/other|' "$input2"
extract_handover "$input2" "$meta2" "$body2"
if ! validate_contract "$meta2" "$body2" >/dev/null 2>&1; then
  t_pass "handover/working_dir mismatch rejects"
else
  t_fail "handover/working_dir mismatch accepted"
fi
rm -rf "$tmp2"

# ---- 3: shell metacharacters in working_dir reject ----
bad_wd_ok=1
for bad in "/tmp/x'bad" "/tmp/x;bad" '/tmp/x$bad'; do
  if handover_validate_metadata_value working_dir "$bad" >/dev/null 2>&1; then
    bad_wd_ok=0
  fi
done
if [[ "$bad_wd_ok" -eq 1 ]]; then
  t_pass "handover/working_dir shell metacharacters reject"
else
  t_fail "handover/working_dir shell metacharacter accepted"
fi

# ---- 4: shell metacharacter in brief_file rejects ----
if ! handover_validate_metadata_value brief_file '/tmp/brief-pm-dispatch-test;touch-pwned.md' >/dev/null 2>&1; then
  t_pass "handover/brief_file shell metacharacter rejects"
else
  t_fail "handover/brief_file shell metacharacter accepted"
fi

# ---- 5: unknown dispatch_route rejects ----
tmp5="$(make_tmpdir)"
input5="$tmp5/input.md"
meta5="$tmp5/meta.txt"
body5="$tmp5/body.md"
write_valid_handover "$input5" "$REPO_ROOT" "/tmp/brief-pm-dispatch-test-5.md"
sed -i 's/^dispatch_route: .*/dispatch_route: mystery_route/' "$input5"
extract_handover "$input5" "$meta5" "$body5"
if ! validate_contract "$meta5" "$body5" >/dev/null 2>&1; then
  t_pass "handover/unknown dispatch_route rejects"
else
  t_fail "handover/unknown dispatch_route accepted"
fi
rm -rf "$tmp5"

# ---- 6: missing handover block extracts empty files ----
tmp6="$(make_tmpdir)"
input6="$tmp6/input.md"
meta6="$tmp6/meta.txt"
body6="$tmp6/body.md"
printf 'ordinary PM summary with no fenced handover\n' > "$input6"
extract_handover "$input6" "$meta6" "$body6"
if [[ ! -s "$meta6" && ! -s "$body6" ]]; then
  t_pass "handover/missing block yields empty extraction"
else
  t_fail "handover/missing block produced content"
fi
rm -rf "$tmp6"

# ---- 7: safe argv quoting round-trips an internal space ----
safe_value="/tmp/normal path"
safe_argv="$(handover_safe_argv working_dir "$safe_value")"
round_trip="$(bash -c "printf '%s' $safe_argv")"
if [[ "$round_trip" == "$safe_value" && "$safe_argv" == "/tmp/normal\\ path" ]]; then
  t_pass "handover/safe argv quoting round-trips"
else
  t_fail "handover/safe argv quoting failed — argv=$safe_argv round_trip=$round_trip"
fi

# ---- 8: footer parse fixture extracts paths and exit code ----
tmp8="$(make_tmpdir)"
stdout8="$tmp8/stdout.txt"
parsed8="$tmp8/footer.env"
cat > "$stdout8" <<EOF
[2026-05-15T00:00:00+00:00] codex-dispatch finished
---
trace:  /repo/.agent-trace/codex-20260515-000000-123.jsonl
last:   /repo/.agent-trace/codex-20260515-000000-123.last
stderr: /repo/.agent-trace/codex-20260515-000000-123.stderr
exit:   0
---
EOF
parse_footer "$stdout8" "$parsed8"
if grep -qx 'trace=/repo/.agent-trace/codex-20260515-000000-123.jsonl' "$parsed8" \
  && grep -qx 'last=/repo/.agent-trace/codex-20260515-000000-123.last' "$parsed8" \
  && grep -qx 'stderr=/repo/.agent-trace/codex-20260515-000000-123.stderr' "$parsed8" \
  && grep -qx 'exit=0' "$parsed8"; then
  t_pass "handover/footer parse extracts trace last stderr exit"
else
  t_fail "handover/footer parse failed — parsed=$(tr '\n' ';' < "$parsed8")"
fi
rm -rf "$tmp8"

echo "----"
echo "$PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
