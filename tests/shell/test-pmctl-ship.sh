#!/usr/bin/env bash
# Regression tests for `pmctl ship prepare/run/--parallel/status/list/
# worktree/operation` -- the dispatch-and-lifecycle half of the ship
# surface. `finish`/gate/publish-assessment/closure coverage lives in the
# sibling suite `test-pmctl-ship-finish.sh` (split out in CC-584 gate
# round 7 purely so each half completes within the QA harness's per-suite
# timeout; the two files share the same fixtures verbatim by design --
# keep them in sync if a shared helper changes).
# shellcheck disable=SC2154  # tmp_root supplied by sourced test-harness
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PMCTL="$REPO_ROOT/cli/pmctl"

# shellcheck source=tests/lib/test-harness.sh
# shellcheck disable=SC1091
. "$SCRIPT_DIR/../lib/test-harness.sh"
# shellcheck source=runtime/lib/pmctl-operation.sh disable=SC1091
. "$REPO_ROOT/runtime/lib/pmctl-operation.sh"
# shellcheck source=runtime/lib/pmctl-dispatch.sh disable=SC1091
. "$REPO_ROOT/runtime/lib/pmctl-dispatch.sh"
# shellcheck source=runtime/lib/gate-subject.sh disable=SC1091
. "$REPO_ROOT/runtime/lib/gate-subject.sh"
th_init "$@"

# Isolate XDG_RUNTIME_DIR for this suite's detached dispatch launches --
# same pattern as test-dispatch-lifecycle.sh/test-gate-lifecycle.sh/
# test-pmctl-gate.sh. Without this, detached-launch's key_file (used to
# secure the sentinel used by `pmctl dispatch wait`) falls back to whatever
# the ambient $XDG_RUNTIME_DIR/pm-dispatch resolves to; on a shared or
# differently-permissioned runtime dir that directory can fail its
# ownership/mode check ("failed to secure private key directory"),
# making this suite's result depend on host environment instead of being
# hermetic.
_TEST_XDG_RUNTIME_DIR="$tmp_root/xdg-runtime"
mkdir -p "$_TEST_XDG_RUNTIME_DIR" && chmod 700 "$_TEST_XDG_RUNTIME_DIR"
export XDG_RUNTIME_DIR="$_TEST_XDG_RUNTIME_DIR"
# The finish fixtures intentionally use command substitutions.  Bash runs the
# EXIT trap in those subshells too; only the owning suite shell may remove the
# shared fixture root.
trap 'if [[ "${BASHPID:-}" == "$$" ]]; then rm -rf "$tmp_root"; fi' EXIT

# Fake codex AND claude on PATH so `pmctl ship --parallel` (detached
# dispatch; default adapter is `claude`, overridable with --adapter) never
# shells out to a REAL executor CLI during this suite -- CC-441's lanes
# launch a detached background supervisor that execs the adapter binary a
# moment after `run` returns, so a real binary on PATH would spend real API
# budget and leave orphaned processes once this suite's tmp_root is deleted.
# Mirrors test-pmctl-dispatch.sh's `_install_fake_codex` and
# test-claude-dispatch.sh's `_install_fake_claude`. Lives for the whole
# suite (not per-case) since the detached supervisor's exec can race a
# per-case cleanup.
# Placed under $tmp_root (th_init already registers its own `rm -rf
# "$tmp_root"` EXIT trap) so this doesn't need a second EXIT trap that would
# otherwise clobber that one.
FAKE_CODEX_BINDIR="$tmp_root/fake-codex-bin"
mkdir -p "$FAKE_CODEX_BINDIR"
cat > "$FAKE_CODEX_BINDIR/codex" <<'FAKEOF'
#!/usr/bin/env bash
_last=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --output-last-message) _last="$2"; shift 2;;
    *) shift;;
  esac
done
[[ -n "$_last" ]] && printf 'dispatch complete (fake codex)\n' > "$_last"
printf '%s\n' '{"type":"turn.completed","usage":{"input_tokens":10,"output_tokens":5}}'
exit 0
FAKEOF
chmod +x "$FAKE_CODEX_BINDIR/codex"
cat > "$FAKE_CODEX_BINDIR/claude" <<'FAKEOF'
#!/usr/bin/env bash
cat >/dev/null
printf '%s\n' '{"type":"system","subtype":"init","session_id":"fake","model":"claude-test"}'
printf '%s\n' '{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"work done"}]},"session_id":"fake"}'
printf '%s\n' '{"type":"result","subtype":"success","result":"work done","is_error":false,"usage":{"input_tokens":100,"output_tokens":50},"session_id":"fake","num_turns":1}'
exit 0
FAKEOF
chmod +x "$FAKE_CODEX_BINDIR/claude"
export PATH="$FAKE_CODEX_BINDIR:$PATH"

make_work_repo() {
  local path="$1" ticket="${2:-CC-9001}" requirement="${3:-none}" problem="${4:-test fixture.}"
  mkdir -p "$path"
  git init -q "$path"
  git -C "$path" config user.email test@example.com
  git -C "$path" config user.name test
  {
    printf '## %s -- mock ticket for ship-parallel tests %s\n\n' "$ticket" "🔵 active"
    printf 'Problem: %s\n\nRequirement: %s\n\nDependencies: none.\n' "$problem" "$requirement"
  } > "$path/BACKLOG.md"
  printf '.pm-dispatch/\n' > "$path/.gitignore"
  mkdir -p "$path/tests/bin"
  cat > "$path/tests/bin/run-tests.sh" <<'FAKEOF'
#!/usr/bin/env bash
set -euo pipefail
[[ -z "${PM_TEST_RUNNER_LOG:-}" ]] || printf '%s\n' "$*" >> "$PM_TEST_RUNNER_LOG"
case "${1:-}" in
  --all)
    [[ "${2:-}" == "--result-file" && -n "${3:-}" ]] || exit 2
    mkdir -p "$(dirname "$3")"
    printf '{"fake":"full-result"}\n' > "$3"
    if [[ "${PM_TEST_FULL_RUN_MUTATE:-}" == "head" ]]; then
      printf 'post-suite mutation\n' > suite-drift.txt
      git add suite-drift.txt
      git -c user.email=test@example.com -c user.name=test commit -q -m post-suite-mutation
    fi
    exit "${PM_TEST_FULL_RUN_STATUS:-0}"
    ;;
  --verify-full)
    [[ -n "${2:-}" ]] || exit 2
    exit "${PM_TEST_FULL_VERIFY_STATUS:-0}"
    ;;
esac
exit 2
FAKEOF
  chmod +x "$path/tests/bin/run-tests.sh"
  git -C "$path" add BACKLOG.md .gitignore tests/bin/run-tests.sh
  git -C "$path" commit -q -m seed
}

add_bare_origin() {
  local work="$1" bare="$1.bare-origin.git"
  git init -q --bare "$bare"
  git -C "$work" remote add origin "$bare"
}

checkout_ticket_branch() {
  local work="$1" ticket_id="$2"
  git -C "$work" checkout -q -b "feat/$ticket_id"
}

install_fake_gh() {
  local bindir="$1" pr_url="$2"
  mkdir -p "$bindir"
  cat > "$bindir/gh" <<FAKEOF
#!/usr/bin/env bash
if [[ "\$1 \$2" == "pr create" ]]; then
  printf '%s\n' "$pr_url"
  exit 0
fi
exit 1
FAKEOF
  chmod +x "$bindir/gh"
}

install_fake_gh_capture_body() {
  local bindir="$1" pr_url="$2"
  mkdir -p "$bindir"
  cat > "$bindir/gh" <<'FAKEOF'
#!/usr/bin/env bash
if [[ "$1 $2" == "pr create" ]]; then
  shift 2
  while [[ $# -gt 0 ]]; do
    if [[ "$1" == "--body" && -n "${2:-}" ]]; then
      [[ -z "${GH_PR_BODY_FILE:-}" ]] || printf '%s' "$2" > "$GH_PR_BODY_FILE"
      shift 2
      continue
    fi
    shift
  done
  printf '%s\n' "${GH_PR_URL:?}"
  exit 0
fi
exit 1
FAKEOF
  chmod +x "$bindir/gh"
}

install_fake_gh_pr_create_fails() {
  local bindir="$1"
  mkdir -p "$bindir"
  cat > "$bindir/gh" <<'FAKEOF'
#!/usr/bin/env bash
if [[ "$1 $2" == "pr create" ]]; then
  echo "gh: simulated network/auth failure" >&2
  exit 1
fi
exit 1
FAKEOF
  chmod +x "$bindir/gh"
}

install_fake_gh_pr_create_fails_once() {
  local bindir="$1" marker="$2" pr_url="$3"
  mkdir -p "$bindir"
  cat > "$bindir/gh" <<FAKEOF
#!/usr/bin/env bash
if [[ "\$1 \$2" == "pr create" ]]; then
  if [[ ! -e "$marker" ]]; then
    : > "$marker"
    echo "gh: simulated first-attempt network/auth failure" >&2
    exit 1
  fi
  printf '%s\n' "$pr_url"
  exit 0
fi
exit 1
FAKEOF
  chmod +x "$bindir/gh"
}

make_cli_fixture_with_fake_gate() {
  local path="$1"
  mkdir -p "$path/cli" "$path/runtime"
  cp "$PMCTL" "$path/cli/pmctl"
  cp "$REPO_ROOT/cli/commands.tsv" "$path/cli/commands.tsv"
  cp -R "$REPO_ROOT/runtime/lib" "$path/runtime/lib"
  # The sed program must keep the CLI's $cmd/$sub anchors literal.
  # shellcheck disable=SC2016
  sed -i '/^case "\$cmd\/\$sub" in$/i\
pmctl_gate_run() {\
  local result_file\
  result_file="$(mktemp)"\
  printf "Final: GO\\n" > "$result_file"\
  printf "result: %s\\n" "$result_file"\
}\
pmctl_gate_verify() {\
  jq -n '"'"'{kind:"gate_verification_v1",verdict:"GO",axes:{artifact_valid:{status:"pass",reason_codes:[]},subject_current:{status:"pass",reason_codes:[]},policy_applicable:{status:"pass",reason_codes:[]}}}'"'"'\
}\
' "$path/cli/pmctl"
  # These CLI fixtures replace the external Gate path, so replace its closure
  # publisher too. The real publisher is covered by pr-gate integration tests.
  cat >> "$path/runtime/lib/pmctl-ship.sh" <<'FIXTURE'
gate_remediation_closure_publish() {
  printf '%s\n' '{}' > "$3"
  printf '%s\n' "$3"
}

gate_publish_assessment_build() {
  local output="$1" head tree
  head="$(git -C "$work_dir" rev-parse HEAD)"
  tree="$(_pmctl_ship_tree_fingerprint "$work_dir" committed_head "$head")"
  jq -n --arg head "$head" --arg tree "$tree" '
    {kind:"gate_publish_assessment_v1",schema_version:1,ticket:"CC-9001",
     subject:{repository_key:("a"*64),base_commit:("b"*40),head_commit:$head,tree_fingerprint:$tree},
     authorization:{status:"authorized",route:"final_tree_review",reason_codes:[]},
     policy:{embedded_policy:"maintainer",required_policy:"generic",preferred_policy:"maintainer",policy_satisfaction:"preferred"},
     gate:{result_file:"/tmp/gate.md",assurance_file:"/tmp/gate.assurance.json",verdict:"GO",subject_fingerprint:$tree,artifact_sha256:("e"*64),assurance_sha256:("f"*64)},
     closure:{artifact:"/tmp/closure.json",sha256:("f"*64),state:"closed",subject_fingerprint:$tree,targeted_confirmation:"not_required"},
     full_suite:{artifact:"/tmp/full.json",sha256:("0"*64),status:"pass",subject_fingerprint:$tree}}' > "$output"
  printf '%s\n' "$1"
}

gate_publish_assessment_verify() { return 0; }
FIXTURE
  chmod +x "$path/cli/pmctl"
}

run_finish_with_fake_gate() {
  local work_dir="$1" ticket_id="$2" verdict="$3"
  shift 3
  bash -c '
    repo_root="$1"; work_dir="$2"; ticket_id="$3"; verdict="$4"; shift 4
    artifact_status="${PM_TEST_GATE_ARTIFACT_STATUS:-pass}"
    subject_status="${PM_TEST_GATE_SUBJECT_STATUS:-pass}"
    policy_status="${PM_TEST_GATE_POLICY_STATUS:-pass}"
    pmctl_gate_run() {
      if [[ -n "${PM_TEST_GATE_RUN_MARKER:-}" ]]; then
        : > "$PM_TEST_GATE_RUN_MARKER"
      fi
      local result_file
      result_file="$(mktemp)"
      printf "Final: %s\n" "$verdict" > "$result_file"
      printf "result: %s\n" "$result_file"
      [[ "$verdict" == "GO" ]]
    }
    pmctl_gate_verify() {
      if [[ -n "${PM_TEST_GATE_VERIFY_ARGV:-}" ]]; then
        printf "%s\n" "$@" > "$PM_TEST_GATE_VERIFY_ARGV"
      fi
      jq -n \
        --arg verdict "$verdict" \
        --arg artifact_status "$artifact_status" \
        --arg subject_status "$subject_status" \
        --arg policy_status "$policy_status" \
        '"'"'{
          kind:"gate_verification_v1",
          verdict:$verdict,
          axes:{
            artifact_valid:{
              status:$artifact_status,
              reason_codes:(if $artifact_status == "pass" then [] else ["artifact_integrity_failed"] end)
            },
            subject_current:{
              status:$subject_status,
              reason_codes:(if $subject_status == "pass" then [] else ["tree_drift"] end)
            },
            policy_applicable:{
              status:$policy_status,
              reason_codes:(if $policy_status == "pass" then [] else ["consumer_policy_below_minimum"] end)
            }
          }
        }'"'"'
      [[ "$verdict" == "GO" && "$artifact_status" == "pass" \
        && "$subject_status" == "pass" && "$policy_status" == "pass" ]]
    }
  gate_remediation_closure_publish() {
    printf "%s\\n" "{}" > "$3"
    printf "%s\\n" "$3"
  }
  gate_publish_assessment_build() {
      local output="$1" head tree
      head="$(git -C "$work_dir" rev-parse HEAD)"
      tree="$(_pmctl_ship_tree_fingerprint "$work_dir" committed_head "$head")"
      jq -n --arg output "$output" --arg head "$head" --arg tree "$tree" -f /dev/stdin <<\JQ > "$output"
        {kind:"gate_publish_assessment_v1",schema_version:1,ticket:"CC-9001",
         subject:{repository_key:("a"*64),base_commit:("b"*40),head_commit:$head,tree_fingerprint:$tree},
         authorization:{status:"authorized",route:"final_tree_review",reason_codes:[]},
         policy:{embedded_policy:"maintainer",required_policy:"generic",preferred_policy:"maintainer",policy_satisfaction:"preferred"},
         gate:{result_file:"/tmp/gate.md",assurance_file:"/tmp/gate.assurance.json",verdict:"GO",subject_fingerprint:$tree,artifact_sha256:("e"*64),assurance_sha256:("f"*64)},
         closure:{artifact:"/tmp/closure.json",sha256:("f"*64),state:"closed",subject_fingerprint:$tree,targeted_confirmation:"not_required"},
         full_suite:{artifact:"/tmp/full.json",sha256:("0"*64),status:"pass",subject_fingerprint:$tree}}
JQ
      printf "%s\\n" "$output"
    }
    gate_publish_assessment_verify() {
      case "${PM_TEST_ASSESSMENT_MUTATE:-}" in
        head)
          printf "post-assessment HEAD mutation\\n" > "$work_dir/post-assessment-head.txt"
          git -C "$work_dir" add post-assessment-head.txt
          git -C "$work_dir" -c user.email=test@example.com -c user.name=test commit -q -m post-assessment-head
          ;;
        tree)
          printf "post-assessment tree mutation\\n" > "$work_dir/post-assessment-tree.txt"
          ;;
      esac
      return 0
    }
    pmctl_ship_after_assessment_verify() {
      [[ "${PM_TEST_ASSESSMENT_REPLACE:-}" == 1 ]] || return 0
      printf "post-verification assessment replacement\n" > "$work_dir/post-assessment-replacement.txt"
      git -C "$work_dir" add post-assessment-replacement.txt
      git -C "$work_dir" -c user.email=test@example.com -c user.name=test commit -q -m post-assessment-replacement
      local forged_head forged_tree replacement
      forged_head="$(git -C "$work_dir" rev-parse HEAD)"
      forged_tree="$(_pmctl_ship_tree_fingerprint "$work_dir" committed_head "$forged_head")"
      replacement="$1.replacement"
      jq --arg head "$forged_head" --arg tree "$forged_tree" \
        '"'"' .subject.head_commit=$head | .subject.tree_fingerprint=$tree '"'"' "$1" > "$replacement" &&
        mv -- "$replacement" "$1"
    }
    . "$repo_root/runtime/lib/pmctl-ship.sh"
    if [[ "${PM_TEST_FAIL_RECOVERY_RECORD:-}" == 1 ]]; then
      _pmctl_ship_partial_record_write() { return 1; }
    fi
    pmctl_ship_finish "$repo_root" "$work_dir" "$ticket_id" "$@"
  ' _ "$REPO_ROOT" "$work_dir" "$ticket_id" "$verdict" "$@"
}

run_finish_with_real_publish_assessment() {
  local work_dir="$1" ticket_id="$2" mode="$3" body_file="$4"
  bash -c '
    repo_root="$1"; work_dir="$2"; ticket_id="$3"; mode="$4"; body_file="$5"
    . "$repo_root/runtime/lib/gate-result-verify.sh"
    head="$(git -C "$work_dir" rev-parse HEAD)"
    subject="$(_gate_subject_tree_fingerprint "$work_dir" committed_head "$head")"
    result_file="$work_dir/.pm-dispatch/test-results/gate-result.md"
    assurance_file="$work_dir/.pm-dispatch/test-results/gate-assurance.json"
    scope_file="$work_dir/.pm-dispatch/test-results/scope-manifest.json"
    mkdir -p "$(dirname "$result_file")"
    if [[ "$mode" == real-closure ]]; then
      printf "Final: GO\n" > "$result_file"
      jq -n '\''{changes:{changed_paths:[],renamed_paths:[],untracked_paths:[]},diff:{binary_or_special_paths:[]}}'\'' > "$scope_file"
    else
      printf "gate result\n" > "$result_file"
    fi
    jq -n --arg result "$result_file" --arg assurance "$assurance_file" --arg subject "$subject" --arg head "$head" '\''
      {kind:"gate_verification_v1",schema_version:1,result_file:$result,verdict:"GO",
       assurance:{status:"verified",kind:"gate_assurance_v3",file:$assurance},consumer:"embedded",
       axes:{artifact_valid:{status:"pass",reason_codes:[]},
         subject_current:{status:"pass",reason_codes:[],current:{repository_key:("a"*64),base_commit:("1"*40),head_commit:$head,tree_fingerprint:$subject,observed_root:"/tmp/repo"}},
         policy_applicable:{status:"pass",reason_codes:[],consumer:"embedded",required_policy:"generic",preferred_policy:"maintainer",embedded_policy:"maintainer",policy_satisfaction:"preferred"}}}
    '\'' > "$work_dir/.pm-dispatch/test-results/gate-verification.json"
    if [[ "$mode" == real-closure ]]; then
      jq -n --arg artifact "$(basename "$scope_file")" --arg subject "$subject" --arg head "$head" '\''
        {subject:{repository_key:("a"*64),base_commit:("1"*40),head_commit:$head,tree_fingerprint:$subject,subject_kind:"committed_head"},
         evidence:{scope_manifest:{artifact:$artifact,sha256:("c"*64)}}}'\'' > "$assurance_file"
    else
      jq -n '\''{evidence:{scope_manifest:{sha256:("c"*64)}}}'\'' > "$assurance_file"
    fi

    pmctl_gate_run() {
      printf "Final: GO\nresult: %s\n" "$result_file"
    }
    pmctl_gate_verify() {
      local consumer=""
      local embedded=maintainer preferred=maintainer satisfaction=preferred
      while [[ $# -gt 0 ]]; do
        if [[ "$1" == "--consumer" ]]; then consumer="$2"; shift 2; else shift; fi
      done
      if [[ "$mode" == generic ]]; then
        embedded=generic preferred=generic satisfaction=baseline
      fi
      if [[ "$mode" == targeted && "$consumer" == publish ]]; then
        jq -n --arg result "$result_file" --arg assurance "$assurance_file" --arg subject "$subject" --arg head "$head" '\''
          {kind:"gate_verification_v1",schema_version:1,result_file:$result,verdict:"NO-GO",
           assurance:{status:"verified",kind:"gate_assurance_v3",file:$assurance},consumer:"publish",
           axes:{artifact_valid:{status:"pass",reason_codes:[]},
             subject_current:{status:"pass",reason_codes:[],current:{repository_key:("a"*64),base_commit:("1"*40),head_commit:$head,tree_fingerprint:$subject,observed_root:"/tmp/repo"}},
             policy_applicable:{status:"fail",reason_codes:["comprehensive_review_required"],consumer:"publish",required_policy:"generic",preferred_policy:"maintainer",embedded_policy:"maintainer",policy_satisfaction:"baseline"}}}
        '\''
        return 1
      fi
      jq -n --arg result "$result_file" --arg assurance "$assurance_file" --arg subject "$subject" --arg head "$head" \
        --arg embedded "$embedded" --arg preferred "$preferred" --arg satisfaction "$satisfaction" '\''
        {kind:"gate_verification_v1",schema_version:1,result_file:$result,verdict:"GO",
         assurance:{status:"verified",kind:"gate_assurance_v3",file:$assurance},consumer:"embedded",
         axes:{artifact_valid:{status:"pass",reason_codes:[]},
           subject_current:{status:"pass",reason_codes:[],current:{repository_key:("a"*64),base_commit:("1"*40),head_commit:$head,tree_fingerprint:$subject,observed_root:"/tmp/repo"}},
             policy_applicable:{status:"pass",reason_codes:[],consumer:"embedded",required_policy:"generic",preferred_policy:$preferred,embedded_policy:$embedded,policy_satisfaction:$satisfaction}}}
      '\''
    }

    . "$repo_root/runtime/lib/pmctl-ship.sh"
    pmctl_ship_verify_full_suite() {
      local full="$work_dir/.pm-dispatch/test-results/full-result.json"
      jq -n --arg subject "$subject" '\''{kind:"pm_test_result_v2",contract:"full",authoritative:true,status:"pass",aggregate:{status:"pass"},exit_code:0,tree_fingerprint:$subject}'\'' > "$full"
      PMCTL_SHIP_FULL_RESULT_FILE="$full"
    }
    # real-closure mode leaves the real gate_remediation_closure_verify (sourced
    # transitively via gate-publish.sh above) live, so this harness proves the
    # closure producer and its consumer inside gate_publish_assessment_build
    # actually interoperate on a real subject -- every other mode still stubs
    # it, since they exercise unrelated seams (policy/route/surface parity).
    if [[ "$mode" != real-closure ]]; then
      gate_remediation_closure_verify() { return 0; }
    fi
    gate_policy_applicability_assess() {
      local embedded=maintainer preferred=maintainer satisfaction=preferred
      if [[ "$mode" == generic ]]; then
        embedded=generic preferred=generic satisfaction=baseline
      fi
      jq -n --arg embedded "$embedded" --arg preferred "$preferred" --arg satisfaction "$satisfaction" '\''
        {status:"pass",reason_codes:[],embedded_policy:$embedded,required_policy:"generic",preferred_policy:$preferred,policy_satisfaction:$satisfaction}'\''
    }
    if [[ "$mode" != real-closure ]]; then
      gate_remediation_closure_publish() {
        local output="$3" authorized=true
        [[ "$mode" == targeted-invalid ]] && authorized=false
        jq -n --arg subject "$subject" --arg scope "$(jq -r .evidence.scope_manifest.sha256 "$assurance_file")" --argjson authorized "$authorized" -f /dev/stdin <<\JQ > "$output"
          {kind:"remediation_closure_v1",schema_version:1,state:"closed",scope_manifest_sha256:$scope,
           final_assessment:{publish_authorized:$authorized,subject_fingerprint:$subject},
           final_subject:{tree_fingerprint:$subject},targeted_confirmation:{status:(if $authorized then "pass" else "not_required" end)}}
JQ
        printf "%s\n" "$output"
      }
    fi
    pmctl_ship_finish "$repo_root" "$work_dir" "$ticket_id"
  ' _ "$REPO_ROOT" "$work_dir" "$ticket_id" "$mode" "$body_file"
}

publish_assessment_fixture() {
  local dir="$1" gate="$1/gate.json" assurance="$1/assurance.json"
  local gate_result="$1/gate-result.md" closure="$1/closure.json" full="$1/full.json"
  local primary_fp="${2:-}" targeted="${3:-pass}"
  mkdir -p "$dir"
  printf 'gate result\n' > "$gate_result"
  jq -n --arg assurance "$assurance" --arg result "$gate_result" '
    {kind:"gate_verification_v1",schema_version:1,result_file:$result,verdict:"GO",
     assurance:{status:"verified",kind:"gate_assurance_v3",file:$assurance},consumer:"embedded",
     axes:{artifact_valid:{status:"pass",reason_codes:[]},
       subject_current:{status:"pass",reason_codes:[],current:{repository_key:("a"*64),base_commit:("1"*40),head_commit:("2"*40),tree_fingerprint:("b"*64),observed_root:"/tmp/repo"}},
       policy_applicable:{status:"pass",reason_codes:[],consumer:"embedded",required_policy:"generic",preferred_policy:"generic",embedded_policy:"generic",policy_satisfaction:"preferred"}}}
  ' > "$gate"
  jq -n '{evidence:{scope_manifest:{sha256:("c"*64)}}}' > "$assurance"
  jq -n --arg primary "$primary_fp" --arg targeted "$targeted" '
    {kind:"remediation_closure_v1",schema_version:1,state:"closed",
     final_assessment:{publish_authorized:true,subject_fingerprint:("b"*64)},
     final_subject:{tree_fingerprint:("b"*64)},
     targeted_confirmation:{status:$targeted}}
    + (if $primary == "" then {} else {primary:{subject:{tree_fingerprint:$primary}}} end)
  ' > "$closure"
  jq -n '{kind:"pm_test_result_v2",contract:"full",authoritative:true,status:"pass",aggregate:{status:"pass"},exit_code:0,tree_fingerprint:("b"*64)}' > "$full"
}

run_real_publish_assessment_build() {
  local dir="$1"
  bash -c '
    repo_root="$1"; dir="$2"
    gate_structural_schema_verify() { return 0; }
    gate_remediation_closure_verify() { return 0; }
    gate_policy_applicability_assess() {
      jq -n '\''{status:"pass",reason_codes:[],embedded_policy:"generic",required_policy:"generic",preferred_policy:"maintainer",policy_satisfaction:"baseline"}'\''
    }
    . "$repo_root/runtime/lib/gate-publish.sh"
    gate_publish_assessment_build "$dir/assessment.json" "$dir/gate.json" "$dir/closure.json" "$dir/full.json" CC-511
  ' _ "$REPO_ROOT" "$dir"
}

run_real_publish_assessment_verify() {
  local assessment="$1"
  bash -c '
    repo_root="$1"; assessment="$2"
    . "$repo_root/runtime/lib/gate-publish.sh"
    gate_publish_assessment_verify "$assessment"
  ' _ "$REPO_ROOT" "$assessment"
}

independent_fixed_tree_fingerprint() {
  local repo_root="$1" head_commit="$2" manifest entry metadata path mode object digest
  manifest="$(mktemp "${TMPDIR:-/tmp}/ship-independent-tree.XXXXXX")" || return 2
  while IFS= read -r -d '' entry; do
    metadata="${entry%%$'\t'*}"
    path="${entry#*$'\t'}"
    mode="${metadata%% *}"
    object="${metadata##* }"
    case "$mode" in
      120000|100644|100755)
        digest="$(git -C "$repo_root" cat-file blob "$object" | sha256sum | awk '{print $1}')" || {
          rm -f -- "$manifest"
          return 2
        }
        ;;
      *)
        rm -f -- "$manifest"
        return 2
        ;;
    esac
    case "$mode" in
      120000)
        printf '%s\tsymlink\tfalse\t%s\n' "$(printf '%q' "$path")" "$digest" >> "$manifest"
        ;;
      100755)
        printf '%s\tfile\ttrue\t%s\n' "$(printf '%q' "$path")" "$digest" >> "$manifest"
        ;;
      100644)
        printf '%s\tfile\tfalse\t%s\n' "$(printf '%q' "$path")" "$digest" >> "$manifest"
        ;;
    esac
  done < <(git -C "$repo_root" ls-tree -r -z --full-tree "$head_commit")
  LC_ALL=C sort "$manifest" | sha256sum | awk '{print $1}'
  local status=$?
  rm -f -- "$manifest"
  return "$status"
}

run_finish_with_no_result_line() {
  local work_dir="$1" ticket_id="$2"
  bash -c '
    repo_root="$1"; work_dir="$2"; ticket_id="$3"
    pmctl_gate_run() { printf "some unrelated gate output, no result line\n"; return 1; }
    . "$repo_root/runtime/lib/pmctl-ship.sh"
    pmctl_ship_finish "$repo_root" "$work_dir" "$ticket_id"
  ' _ "$REPO_ROOT" "$work_dir" "$ticket_id"
}

run_finish_with_broken_shared_verifier() {
  local work_dir="$1" ticket_id="$2" verifier_mode="$3"
  bash -c '
    repo_root="$1"; work_dir="$2"; ticket_id="$3"; verifier_mode="$4"
    pmctl_gate_run() {
      local result_file
      result_file="$(mktemp)"
      printf "Final: GO\n" > "$result_file"
      printf "result: %s\n" "$result_file"
    }
    . "$repo_root/runtime/lib/pmctl-ship.sh"
    if [[ "$verifier_mode" == malformed ]]; then
      pmctl_gate_verify() { printf "{\"kind\":\"unexpected\"}\n"; }
    else
      unset -f pmctl_gate_verify 2>/dev/null || true
    fi
    pmctl_ship_finish "$repo_root" "$work_dir" "$ticket_id"
  ' _ "$REPO_ROOT" "$work_dir" "$ticket_id" "$verifier_mode"
}

run_ship_parallel_capture_dispatch_argv() {
  local store="$1" work_dir="$2" ticket_id="$3"
  shift 3
  local argv_file="$tmp_root/captured-dispatch-argv.$$"
  rm -f "$argv_file"
  PM_DISPATCH_STATE_ROOT="$store" ARGV_CAPTURE_FILE="$argv_file" bash -c '
    repo_root="$1"; work_dir="$2"; ticket_id="$3"; shift 3
    for lib in portable state-writer state-paths pmctl-worktree pmctl-ship pmctl-ship-parallel; do
      # shellcheck disable=SC1090
      . "$repo_root/runtime/lib/$lib.sh"
    done
    pmctl_dispatch_run() {
      shift
      printf "%s\n" "$@" > "$ARGV_CAPTURE_FILE"
      # Preserve the public detached-run identifier contract: ship now records
      # the returned id as an operation child, so a deliberately malformed
      # mock id would correctly be rejected before it reaches tracking.
      printf "run-20260724T000000Z-abcdef\n"
    }
    pmctl_ship_parallel_run "$repo_root" "$work_dir" "$ticket_id" "$@"
  ' _ "$REPO_ROOT" "$work_dir" "$ticket_id" "$@"
  cat "$argv_file" 2>/dev/null
}

reg_dir_for() {
  local store="$1" work="$2"
  PM_DISPATCH_STATE_ROOT="$store" bash -c \
    '. "$1/runtime/lib/state-paths.sh" && sw_project_worktree_dir "$2"' \
    _ "$REPO_ROOT" "$work"
}

seed_dispatch_record() {
  local lane_path="$1" run_id="$2" final_state="$3" summary="$4"
  bash -c '
    repo_root="$1"; lane_path="$2"; run_id="$3"; final_state="$4"; summary="$5"
    . "$repo_root/runtime/lib/dispatch-record.sh"
    dispatch_record_write "$run_id" "task" "codex" "default" "/tmp/brief-x.md" \
      "$lane_path" 0 "$final_state" "$summary" "" "" "" "2026-01-01T00:00:00Z" "2026-01-01T00:01:00Z"
  ' _ "$REPO_ROOT" "$lane_path" "$run_id" "$final_state" "$summary"
}

write_dispatched_lane_tracking_entry() {
  local store="$1" work_dir="$2" ticket_id="$3" adapter="$4" reg_dir declared_paths_json
  shift 4
  reg_dir="$(reg_dir_for "$store" "$work_dir")"
  mkdir -p "$reg_dir"
  if [[ $# -gt 0 ]]; then
    declared_paths_json="$(jq -cn '$ARGS.positional' --args "$@")"
  else
    declared_paths_json='[]'
  fi
  jq -cn --arg ticket "$ticket_id" --arg branch "feat/$ticket_id" --arg path "$work_dir" \
    --arg adapter "$adapter" --argjson declared_paths "$declared_paths_json" \
    '{ticket:$ticket,branch:$branch,path:$path,run_id:"run-test-fixture",
      operation_id:"",operation_work_dir:"",adapter:$adapter,status:"running",
      created_ts:"2026-01-01T00:00:00Z",lane_id:"lane-test-fixture",
      declared_paths:$declared_paths}' \
    >> "$reg_dir/ship-lanes.jsonl"
}

case_run_requires_ticket() {
  local name="ship-parallel run: no ticket-id exits non-zero with usage"
  should_run "$name" || return 0
  local store work out err status=0
  store="$tmp_root/state-run-noarg"
  work="$tmp_root/work-run-noarg"
  make_work_repo "$work"
  out="$tmp_root/out-run-noarg"; err="$tmp_root/err-run-noarg"
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" ship --parallel --no-auto-pack --cd "$work" > "$out" 2> "$err" || status=$?
  assert_exit "$name" "$status" 2 && \
    assert_file_contains "$name" "$err" "at least one <ticket-id> is required" && \
    pass "$name"
}

case_run_rejects_unknown_ticket() {
  local name="ship-parallel run: unknown ticket-id is rejected before any worktree is created"
  should_run "$name" || return 0
  local store work out err status=0
  store="$tmp_root/state-run-unknown"
  work="$tmp_root/work-run-unknown"
  make_work_repo "$work" "CC-9001"
  out="$tmp_root/out-run-unknown"; err="$tmp_root/err-run-unknown"
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" ship --parallel --no-auto-pack CC-9999 --cd "$work" > "$out" 2> "$err" || status=$?
  assert_exit "$name" "$status" 1 && \
    assert_file_contains "$name" "$err" "not an active BACKLOG.md ticket" && \
    pass "$name"
}

case_run_rejects_regex_metachar_ticket_id() {
  local name="ship-parallel run: a ticket-id with regex metacharacters is rejected as malformed shape, not treated as a live grep pattern"
  should_run "$name" || return 0
  local store work out err status=0
  store="$tmp_root/state-run-regexmeta"
  work="$tmp_root/work-run-regexmeta"
  make_work_repo "$work" "CC-9001"
  out="$tmp_root/out-run-regexmeta"; err="$tmp_root/err-run-regexmeta"
  # If the ticket-active check ever regressed to an unvalidated `grep`, this
  # id ("CC-." -- "." matches any char) would false-match the real
  # "## CC-9001" heading and the batch would proceed to create a worktree.
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" ship --parallel --no-auto-pack "CC-." --cd "$work" > "$out" 2> "$err" || status=$?
  local reg_dir
  reg_dir="$(reg_dir_for "$store" "$work")"
  if [[ "$status" -eq 1 ]] && grep -q "not an active BACKLOG.md ticket" "$err" && [[ ! -d "$reg_dir/checkouts/CC-." ]]; then
    pass "$name"
  else
    fail "$name" "expected rejection + no worktree created; got status=$status stderr=$(cat "$err")"
  fi
}

case_run_rejects_prefix_collision_ticket_id() {
  local name="ship-parallel run: a ticket-id that is a PREFIX of a real heading (CC-90 vs CC-9001) is rejected, not treated as a match"
  should_run "$name" || return 0
  local store work out err status=0
  store="$tmp_root/state-run-prefix"
  work="$tmp_root/work-run-prefix"
  make_work_repo "$work" "CC-9001"
  out="$tmp_root/out-run-prefix"; err="$tmp_root/err-run-prefix"
  # "## CC-9001 -- ..." starts with the literal substring "## CC-90", so an
  # unanchored-on-the-right heading check would wrongly treat CC-90 as
  # existing and dispatch a lane for a ticket that was never asked for.
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" ship --parallel --no-auto-pack "CC-90" --cd "$work" > "$out" 2> "$err" || status=$?
  local reg_dir
  reg_dir="$(reg_dir_for "$store" "$work")"
  if [[ "$status" -eq 1 ]] && grep -q "not an active BACKLOG.md ticket" "$err" && [[ ! -d "$reg_dir/checkouts/CC-90" ]]; then
    pass "$name"
  else
    fail "$name" "expected rejection + no worktree created; got status=$status stderr=$(cat "$err")"
  fi
}

case_prepare_rejects_prefix_collision_ticket_id() {
  local name="ship prepare: a ticket-id that is a PREFIX of a real heading (CC-90 vs CC-9001) is rejected as no-such-ticket"
  should_run "$name" || return 0
  local store work out err status=0
  store="$tmp_root/state-prep-prefix"
  work="$tmp_root/work-prep-prefix"
  make_work_repo "$work" "CC-9001"
  out="$tmp_root/out-prep-prefix"; err="$tmp_root/err-prep-prefix"
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" ship prepare "CC-90" --cd "$work" > "$out" 2> "$err" || status=$?
  assert_exit "$name" "$status" 1 && \
    assert_file_contains "$name" "$err" "no such ticket" && \
    pass "$name"
}

case_run_rejects_duplicate_ticket_in_batch() {
  local name="ship-parallel run: a ticket-id repeated in the same batch is rejected before any worktree is created"
  should_run "$name" || return 0
  local store work out err status=0
  store="$tmp_root/state-run-dup"
  work="$tmp_root/work-run-dup"
  make_work_repo "$work" "CC-9001"
  out="$tmp_root/out-run-dup"; err="$tmp_root/err-run-dup"
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" ship --parallel --no-auto-pack CC-9001 CC-9001 --cd "$work" > "$out" 2> "$err" || status=$?
  local reg_dir
  reg_dir="$(reg_dir_for "$store" "$work")"
  if [[ "$status" -eq 1 ]] && grep -q "appears more than once" "$err" && [[ ! -d "$reg_dir/checkouts/CC-9001" ]]; then
    pass "$name"
  else
    fail "$name" "expected rejection + no worktree created; got status=$status stderr=$(cat "$err")"
  fi
}

case_run_bad_ticket_leaves_no_worktree() {
  local name="ship-parallel run: rejecting one ticket in a batch creates no worktree for either"
  should_run "$name" || return 0
  local store work status=0
  store="$tmp_root/state-run-batch-bad"
  work="$tmp_root/work-run-batch-bad"
  make_work_repo "$work" "CC-9001"
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" ship --parallel --no-auto-pack CC-9001 CC-9999 --cd "$work" \
    > "$tmp_root/out-batch-bad" 2> "$tmp_root/err-batch-bad" || status=$?
  local reg_dir
  reg_dir="$(reg_dir_for "$store" "$work")"
  if [[ "$status" -eq 1 && ! -d "$reg_dir/checkouts/CC-9001" ]]; then
    pass "$name"
  else
    fail "$name" "expected exit 1 and no checkouts/CC-9001 dir; got status=$status reg_dir=$reg_dir"
  fi
}

case_run_refuses_redispatch_while_in_flight() {
  local name="ship-parallel run: refuses to re-dispatch a ticket whose prior lane is still running"
  should_run "$name" || return 0
  local store work status=0
  store="$tmp_root/state-run-inflight"
  work="$tmp_root/work-run-inflight"
  make_work_repo "$work" "CC-9001"

  # A fake claude that blocks on a named-pipe read until explicitly
  # released -- no sleep anywhere (qa-tester's red line is against
  # sleep-based synchronization, including bounded polling loops, not just
  # fixed-duration sleeps). No "process has started" signal is needed: the
  # first `ship --parallel` call is DETACHED and returns as soon as the
  # supervisor launches (before the fake claude process even runs), so the
  # second `ship --parallel` call below -- issued immediately after, with
  # no gap -- reliably observes "no dispatch record written yet" (the fake
  # process is still blocked on the fifo read) regardless of exact process
  # scheduling. The fifo's only job is to keep the first lane alive long
  # enough for that second call to run before the first one can finish.
  local release_fifo="$tmp_root/inflight-release.fifo"
  rm -f "$release_fifo"
  mkfifo "$release_fifo"
  local slow_bin="$tmp_root/slow-claude-bin"
  mkdir -p "$slow_bin"
  cat > "$slow_bin/claude" <<FAKEOF
#!/usr/bin/env bash
cat >/dev/null
read -r _ < "$release_fifo"
printf '%s\n' '{"type":"result","subtype":"success","result":"work done","is_error":false,"usage":{"input_tokens":1,"output_tokens":1},"session_id":"fake","num_turns":1}'
exit 0
FAKEOF
  chmod +x "$slow_bin/claude"

  PATH="$slow_bin:$PATH" PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" ship --parallel --no-auto-pack CC-9001 --cd "$work" \
    > "$tmp_root/out-inflight-1" 2> "$tmp_root/err-inflight-1"

  local out2 err2 status2=0
  out2="$tmp_root/out-inflight-2"; err2="$tmp_root/err-inflight-2"
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" ship --parallel --no-auto-pack CC-9001 --cd "$work" \
    > "$out2" 2> "$err2" || status2=$?

  # Opening a FIFO for write blocks until a reader connects -- the fake
  # process's `read -r _ < "$release_fifo"` is that reader, so this
  # unblocks it (no sleep needed on either side). Bounded via `timeout` in
  # case the fake process already exited some other way.
  # shellcheck disable=SC2016  # $1 is the spawned bash -c's own positional arg, deferred by design.
  timeout 30 bash -c 'printf release > "$1"' _ "$release_fifo" 2>/dev/null || true

  if [[ "$status2" -eq 1 ]] && grep -q "already has an in-flight lane" "$err2"; then
    pass "$name"
  else
    fail "$name" "expected exit 1 + in-flight refusal message; got status=$status2 stderr=$(cat "$err2")"
  fi
}

case_run_flag_adapter_reaches_dispatch() {
  local name="ship-parallel run: --adapter reaches pmctl dispatch run's argv"
  should_run "$name" || return 0
  local store work
  store="$tmp_root/state-flag-adapter"
  work="$tmp_root/work-flag-adapter"
  make_work_repo "$work" "CC-9001"
  local argv
  argv="$(run_ship_parallel_capture_dispatch_argv "$store" "$work" "CC-9001" --no-auto-pack --adapter codex)"
  if grep -q -- '--adapter' <<<"$argv" && grep -Fxq 'codex' <<<"$argv"; then
    pass "$name"
  else
    fail "$name" "expected --adapter codex in captured argv, got: $argv"
  fi
}

case_run_flag_isolation_reaches_dispatch() {
  local name="ship-parallel run: --isolation reaches pmctl dispatch run's argv"
  should_run "$name" || return 0
  local store work
  store="$tmp_root/state-flag-isolation"
  work="$tmp_root/work-flag-isolation"
  make_work_repo "$work" "CC-9001"
  local argv
  argv="$(run_ship_parallel_capture_dispatch_argv "$store" "$work" "CC-9001" --no-auto-pack --isolation read-only)"
  if grep -q -- '--isolation' <<<"$argv" && grep -Fxq 'read-only' <<<"$argv"; then
    pass "$name"
  else
    fail "$name" "expected --isolation read-only in captured argv, got: $argv"
  fi
}

case_run_flag_model_reaches_dispatch() {
  local name="ship-parallel run: --model reaches pmctl dispatch run's argv"
  should_run "$name" || return 0
  local store work
  store="$tmp_root/state-flag-model"
  work="$tmp_root/work-flag-model"
  make_work_repo "$work" "CC-9001"
  local argv
  argv="$(run_ship_parallel_capture_dispatch_argv "$store" "$work" "CC-9001" --no-auto-pack --model light)"
  if grep -q -- '--model' <<<"$argv" && grep -Fxq 'light' <<<"$argv"; then
    pass "$name"
  else
    fail "$name" "expected --model light in captured argv, got: $argv"
  fi
}

case_run_flag_no_auto_pack_reaches_dispatch() {
  local name="ship-parallel run: --no-auto-pack reaches pmctl dispatch run's argv"
  should_run "$name" || return 0
  local store work
  store="$tmp_root/state-flag-noautopack"
  work="$tmp_root/work-flag-noautopack"
  make_work_repo "$work" "CC-9001"
  local argv
  argv="$(run_ship_parallel_capture_dispatch_argv "$store" "$work" "CC-9001" --no-auto-pack)"
  if grep -q -- '--no-auto-pack' <<<"$argv"; then
    pass "$name"
  else
    fail "$name" "expected --no-auto-pack in captured argv, got: $argv"
  fi
}

case_run_flag_auto_pack_reaches_dispatch() {
  local name="ship-parallel run: --auto-pack reaches pmctl dispatch run's argv"
  should_run "$name" || return 0
  local store work
  store="$tmp_root/state-flag-autopack"
  work="$tmp_root/work-flag-autopack"
  make_work_repo "$work" "CC-9001"
  local argv
  argv="$(run_ship_parallel_capture_dispatch_argv "$store" "$work" "CC-9001" --auto-pack)"
  if grep -q -- '--auto-pack' <<<"$argv"; then
    pass "$name"
  else
    fail "$name" "expected --auto-pack in captured argv, got: $argv"
  fi
}

case_run_flag_from_sets_worktree_base() {
  local name="ship-parallel run: --from creates the lane's branch off the named base, not the default HEAD"
  should_run "$name" || return 0
  local store work
  store="$tmp_root/state-flag-from"
  work="$tmp_root/work-flag-from"
  make_work_repo "$work" "CC-9001"
  git -C "$work" checkout -q -b side-base
  printf 'only-on-side-base\n' > "$work/side-marker.txt"
  git -C "$work" add side-marker.txt
  git -C "$work" commit -q -m "side base marker"
  git -C "$work" checkout -q master 2>/dev/null || git -C "$work" checkout -q main
  run_ship_parallel_capture_dispatch_argv "$store" "$work" "CC-9001" --no-auto-pack --from side-base >/dev/null
  local reg_dir lane_path
  reg_dir="$(reg_dir_for "$store" "$work")"
  lane_path="$reg_dir/checkouts/CC-9001"
  if [[ -f "$lane_path/side-marker.txt" ]]; then
    pass "$name"
  else
    fail "$name" "expected lane worktree branched from side-base (side-marker.txt present); lane_path=$lane_path"
  fi
}

case_run_dispatches_and_tracks() {
  local name="ship-parallel run: valid ticket creates a lane worktree, dispatches, and records tracking"
  should_run "$name" || return 0
  local store work out err status=0
  store="$tmp_root/state-run-ok"
  work="$tmp_root/work-run-ok"
  make_work_repo "$work" "CC-9001"
  out="$tmp_root/out-run-ok"; err="$tmp_root/err-run-ok"
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" ship --parallel --no-auto-pack CC-9001 --cd "$work" > "$out" 2> "$err" || status=$?

  local reg_dir tracking
  reg_dir="$(reg_dir_for "$store" "$work")"
  tracking="$reg_dir/ship-lanes.jsonl"

  if [[ "$status" -ne 0 ]]; then
    fail "$name" "run exited $status; stderr: $(cat "$err")"
    return
  fi
  if [[ ! -d "$reg_dir/checkouts/CC-9001" ]]; then
    fail "$name" "lane worktree missing at $reg_dir/checkouts/CC-9001"
    return
  fi
  if [[ ! -f "$tracking" ]]; then
    fail "$name" "tracking file missing at $tracking"
    return
  fi
  local ticket run_id operation_id lane_status
  ticket="$(jq -r '.ticket' "$tracking")"
  run_id="$(jq -r '.run_id' "$tracking")"
  operation_id="$(jq -r '.operation_id // ""' "$tracking")"
  lane_status="$(jq -r '.status' "$tracking")"
  if [[ "$ticket" == "CC-9001" && -n "$run_id" && "$run_id" != null \
        && "$operation_id" =~ ^op-[0-9]{8}T[0-9]{6}Z-[a-f0-9]{6}$ && "$lane_status" == "dispatched" ]]; then
    pass "$name"
  else
    fail "$name" "unexpected tracking entry: $(cat "$tracking")"
  fi
}

case_run_brief_preserves_ship_contract() {
  local name="ship-parallel run: lane brief re-states the ship contract, no branch switch, no worktree remove"
  should_run "$name" || return 0
  local store work status=0
  store="$tmp_root/state-run-brief"
  work="$tmp_root/work-run-brief"
  make_work_repo "$work" "CC-9001"
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" ship --parallel --no-auto-pack CC-9001 --cd "$work" \
    > "$tmp_root/out-brief" 2> "$tmp_root/err-brief" || status=$?
  local reg_dir tracking run_id brief
  reg_dir="$(reg_dir_for "$store" "$work")"
  tracking="$reg_dir/ship-lanes.jsonl"
  run_id="$(jq -r '.run_id' "$tracking" 2>/dev/null || true)"
  brief="/tmp/brief-$run_id.md"
  # Backticks below are literal Markdown code spans in the assertion text, not command substitution.
  # shellcheck disable=SC2016
  if [[ "$status" -eq 0 && -f "$brief" ]] \
    && grep -q 'Do not run `git checkout -b`' "$brief" \
    && grep -q 'Do not run `pmctl worktree remove`' "$brief" \
    && grep -q 'Do NOT run `git add`, `git commit`, `pmctl ship finish`, or `pmctl gate run`' "$brief"; then
    pass "$name"
  else
    fail "$name" "brief missing expected ship-contract constraints (status=$status, brief=$brief)"
  fi
}

case_run_restores_gc_auto_previously_set() {
  local name="ship-parallel run: restores a pre-existing gc.auto value on exit"
  should_run "$name" || return 0
  local store work status=0
  store="$tmp_root/state-run-gcset"
  work="$tmp_root/work-run-gcset"
  make_work_repo "$work" "CC-9001"
  git -C "$work" config gc.auto 128
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" ship --parallel --no-auto-pack CC-9001 --cd "$work" \
    > "$tmp_root/out-gcset" 2> "$tmp_root/err-gcset" || status=$?
  local restored
  restored="$(git -C "$work" config --get gc.auto 2>/dev/null || true)"
  if [[ "$restored" == "128" ]]; then
    pass "$name"
  else
    fail "$name" "expected gc.auto restored to 128, got '$restored'"
  fi
}

case_run_restores_gc_auto_previously_unset() {
  local name="ship-parallel run: leaves gc.auto unset (not 256) when it started unset"
  should_run "$name" || return 0
  local store work status=0
  store="$tmp_root/state-run-gcunset"
  work="$tmp_root/work-run-gcunset"
  make_work_repo "$work" "CC-9001"
  git -C "$work" config --unset gc.auto 2>/dev/null || true
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" ship --parallel --no-auto-pack CC-9001 --cd "$work" \
    > "$tmp_root/out-gcunset" 2> "$tmp_root/err-gcunset" || status=$?
  local restored=0
  if git -C "$work" config --get gc.auto 2>/dev/null; then
    restored=1
  fi
  if [[ "$restored" -eq 0 ]]; then
    pass "$name"
  else
    fail "$name" "expected gc.auto to remain unset, but it is now set to $(git -C "$work" config --get gc.auto)"
  fi
}

case_status_never_reports_go_from_free_text_without_marker() {
  local name="ship-parallel status: a dispatch record containing literal 'Final: GO' text WITHOUT a finish marker never surfaces as status=go"
  should_run "$name" || return 0
  local store work status=0
  store="$tmp_root/state-status-go"
  work="$tmp_root/work-status-go"
  make_work_repo "$work" "CC-9001"
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" ship --parallel --no-auto-pack CC-9001 --cd "$work" \
    > "$tmp_root/out-status-go" 2> "$tmp_root/err-status-go" || status=$?
  local reg_dir tracking run_id lane_path operation_id operation_state
  reg_dir="$(reg_dir_for "$store" "$work")"
  tracking="$reg_dir/ship-lanes.jsonl"
  run_id="$(jq -r '.run_id' "$tracking")"
  operation_id="$(jq -r '.operation_id // ""' "$tracking")"
  lane_path="$(jq -r '.path' "$tracking")"
  # No .pm-dispatch-ship-finish.json marker is written here -- only the
  # dispatch record's free-text summary claims "Final: GO". Since the
  # marker is the ONLY source of truth for status=go (gate round 6 fix),
  # this must NOT surface as go even though the old text-grep heuristic
  # would have matched it.
  seed_dispatch_record "$lane_path" "$run_id" ok "Final: GO"
  local json
  json="$(PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" ship status --cd "$work" --json)"
  if [[ "$(jq -r '.[0].status' <<<"$json")" == "no-go" ]]; then
    pass "$name"
  else
    fail "$name" "expected status=no-go (no marker present), got $json"
  fi
}

case_status_reports_go_from_finish_marker_even_without_final_go_text() {
  local name="ship-parallel status: pmctl ship finish's own GO marker wins even when the executor's free-text summary never says literal 'Final: GO'"
  should_run "$name" || return 0
  local store work status=0
  store="$tmp_root/state-status-marker-go"
  work="$tmp_root/work-status-marker-go"
  make_work_repo "$work" "CC-9001"
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" ship --parallel --no-auto-pack CC-9001 --cd "$work" \
    > "$tmp_root/out-status-marker-go" 2> "$tmp_root/err-status-marker-go" || status=$?
  local reg_dir tracking run_id lane_path operation_id operation_state
  reg_dir="$(reg_dir_for "$store" "$work")"
  tracking="$reg_dir/ship-lanes.jsonl"
  run_id="$(jq -r '.run_id' "$tracking")"
  operation_id="$(jq -r '.operation_id // ""' "$tracking")"
  lane_path="$(jq -r '.path' "$tracking")"
  # Simulates a real observed failure mode: the executor's own summary
  # reports the verdict in prose ("Gate 通過（GO）"), not the literal
  # "Final: GO" string the old heuristic grepped for.
  seed_dispatch_record "$lane_path" "$run_id" ok "Gate 通過（GO）。PR 已開啟。"
  printf '{"ticket":"CC-9001","verdict":"GO","branch":"feat/CC-9001","pr_url":"https://example/pr/1"}' \
    > "$lane_path/.pm-dispatch-ship-finish.json"
  local json
  json="$(PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" ship status --cd "$work" --json)"
  if [[ "$(jq -r '.[0].status' <<<"$json")" == "go" ]]; then
    pass "$name"
  else
    fail "$name" "expected status=go from marker file despite no literal 'Final: GO' text, got $json"
  fi
}

case_status_reports_no_go_from_final_line() {
  local name="ship-parallel status: an ok record without Final: GO surfaces as status=no-go"
  should_run "$name" || return 0
  local store work status=0
  store="$tmp_root/state-status-nogo"
  work="$tmp_root/work-status-nogo"
  make_work_repo "$work" "CC-9001"
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" ship --parallel --no-auto-pack CC-9001 --cd "$work" \
    > "$tmp_root/out-status-nogo" 2> "$tmp_root/err-status-nogo" || status=$?
  local reg_dir tracking run_id lane_path operation_id operation_state
  reg_dir="$(reg_dir_for "$store" "$work")"
  tracking="$reg_dir/ship-lanes.jsonl"
  run_id="$(jq -r '.run_id' "$tracking")"
  operation_id="$(jq -r '.operation_id // ""' "$tracking")"
  lane_path="$(jq -r '.path' "$tracking")"
  seed_dispatch_record "$lane_path" "$run_id" ok "Final: NO-GO"
  local json
  json="$(PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" ship status --cd "$work" --json)"
  operation_state="$(jq -r .state "$(dirname "$reg_dir")/operations/$operation_id.json" 2>/dev/null || true)"
  # The detached test supervisor can race our seeded record and replace its
  # terminal evidence; either trusted completion or an explicit indeterminate
  # terminal state proves status invoked parent reconciliation (never stale
  # running).
  if [[ "$(jq -r '.[0].status' <<<"$json")" == "no-go" && "$operation_state" =~ ^(completed|indeterminate)$ ]]; then
    pass "$name"
  else
    fail "$name" "expected status=no-go + terminal parent, operation=$operation_id state=$operation_state got $json"
  fi
}

case_status_no_record_yet_is_running() {
  local name="ship-parallel status: a lane with no dispatch record yet is status=running"
  should_run "$name" || return 0
  local store work status=0
  store="$tmp_root/state-status-running"
  work="$tmp_root/work-status-running"
  make_work_repo "$work" "CC-9001"
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" ship --parallel --no-auto-pack CC-9001 --cd "$work" \
    > "$tmp_root/out-status-run" 2> "$tmp_root/err-status-run" || status=$?
  local json
  json="$(PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" ship status --cd "$work" --json)"
  local lane_status
  lane_status="$(jq -r '.[0].status' <<<"$json")"
  if [[ "$lane_status" == "running" || "$lane_status" == "dispatched" || "$lane_status" == "failed" ]]; then
    # "failed" is an acceptable observed outcome in a sandbox with no codex
    # binary installed -- the supervisor may have already written a failed
    # record by the time status runs. Any of these three is "not silently GO".
    pass "$name"
  else
    fail "$name" "expected running/dispatched/failed, got $lane_status"
  fi
}

case_list_filters_to_go_only() {
  local name="ship-parallel list: only GO lanes appear, pending-merge tracking"
  should_run "$name" || return 0
  local store work status=0
  store="$tmp_root/state-list-go"
  work="$tmp_root/work-list-go"
  make_work_repo "$work" "CC-9001"
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" ship --parallel --no-auto-pack CC-9001 --cd "$work" \
    > "$tmp_root/out-list-go" 2> "$tmp_root/err-list-go" || status=$?
  local reg_dir tracking run_id lane_path
  reg_dir="$(reg_dir_for "$store" "$work")"
  tracking="$reg_dir/ship-lanes.jsonl"
  run_id="$(jq -r '.run_id' "$tracking")"
  lane_path="$(jq -r '.path' "$tracking")"
  seed_dispatch_record "$lane_path" "$run_id" ok "Final: GO"
  # status=go requires the finish marker (gate round 6 fix) -- a dispatch
  # record's free text is no longer sufficient on its own.
  printf '{"ticket":"CC-9001","verdict":"GO","branch":"feat/CC-9001","pr_url":"https://example/pr/1"}' \
    > "$lane_path/.pm-dispatch-ship-finish.json"
  local json
  json="$(PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" ship list --cd "$work" --json)"
  if [[ "$(jq 'length' <<<"$json")" -eq 1 && "$(jq -r '.[0].ticket' <<<"$json")" == "CC-9001" ]]; then
    pass "$name"
  else
    fail "$name" "expected exactly one GO lane (CC-9001), got $json"
  fi
}

case_list_empty_when_none_go() {
  local name="ship-parallel list: empty when no lane has reached GO"
  should_run "$name" || return 0
  local store work status=0
  store="$tmp_root/state-list-empty"
  work="$tmp_root/work-list-empty"
  make_work_repo "$work" "CC-9001"
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" ship --parallel --no-auto-pack CC-9001 --cd "$work" \
    > "$tmp_root/out-list-empty" 2> "$tmp_root/err-list-empty" || status=$?
  local json
  json="$(PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" ship list --cd "$work" --json)"
  if [[ "$(jq 'length' <<<"$json")" -eq 0 ]]; then
    pass "$name"
  else
    fail "$name" "expected empty GO list, got $json"
  fi
}

case_status_no_tracked_lanes() {
  local name="ship-parallel status: no tracked lanes prints a plain message, exits 0"
  should_run "$name" || return 0
  local store work out status=0
  store="$tmp_root/state-status-none"
  work="$tmp_root/work-status-none"
  make_work_repo "$work" "CC-9001"
  out="$tmp_root/out-status-none"
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" ship status --cd "$work" > "$out" 2>&1 || status=$?
  assert_exit "$name" "$status" 0 && \
    assert_file_contains "$name" "$out" "No tracked ship lanes." && \
    pass "$name"
}

case_prepare_empty_argument() {
  local name="ship prepare: empty ticket-id exits 1 with 'empty argument'"
  should_run "$name" || return 0
  local store work out err status=0
  store="$tmp_root/state-prep-empty"
  work="$tmp_root/work-prep-empty"
  make_work_repo "$work" "CC-9001"
  out="$tmp_root/out-prep-empty"; err="$tmp_root/err-prep-empty"
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" ship prepare --cd "$work" > "$out" 2> "$err" || status=$?
  assert_exit "$name" "$status" 1 && \
    assert_file_contains "$name" "$err" "empty argument" && \
    pass "$name"
}

case_prepare_malformed_shape() {
  local name="ship prepare: malformed ticket-id shape exits 1"
  should_run "$name" || return 0
  local store work out err status=0
  store="$tmp_root/state-prep-shape"
  work="$tmp_root/work-prep-shape"
  make_work_repo "$work" "CC-9001"
  out="$tmp_root/out-prep-shape"; err="$tmp_root/err-prep-shape"
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" ship prepare not-a-ticket --cd "$work" > "$out" 2> "$err" || status=$?
  assert_exit "$name" "$status" 1 && \
    assert_file_contains "$name" "$err" "malformed shape" && \
    pass "$name"
}

case_prepare_no_such_ticket() {
  local name="ship prepare: unknown ticket-id exits 1 with 'no such ticket'"
  should_run "$name" || return 0
  local store work out err status=0
  store="$tmp_root/state-prep-nosuch"
  work="$tmp_root/work-prep-nosuch"
  make_work_repo "$work" "CC-9001"
  out="$tmp_root/out-prep-nosuch"; err="$tmp_root/err-prep-nosuch"
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" ship prepare CC-9999 --cd "$work" > "$out" 2> "$err" || status=$?
  assert_exit "$name" "$status" 1 && \
    assert_file_contains "$name" "$err" "no such ticket" && \
    pass "$name"
}

case_prepare_archived_ticket() {
  local name="ship prepare: an archived ticket-id exits 1 with 'already archived', not 'no such ticket'"
  should_run "$name" || return 0
  local store work out err status=0
  store="$tmp_root/state-prep-archived"
  work="$tmp_root/work-prep-archived"
  make_work_repo "$work" "CC-9001"
  printf '## CC-8000 -- archived mock ticket ✅ 2026-01-01\n' > "$work/BACKLOG-ARCHIVE.md"
  out="$tmp_root/out-prep-archived"; err="$tmp_root/err-prep-archived"
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" ship prepare CC-8000 --cd "$work" > "$out" 2> "$err" || status=$?
  assert_exit "$name" "$status" 1 && \
    assert_file_contains "$name" "$err" "already archived" && \
    pass "$name"
}

case_prepare_dirty_tree_refused() {
  local name="ship prepare: a dirty tree is refused, never stashed/committed silently"
  should_run "$name" || return 0
  local store work out err status=0
  store="$tmp_root/state-prep-dirty"
  work="$tmp_root/work-prep-dirty"
  make_work_repo "$work" "CC-9001"
  printf 'uncommitted\n' > "$work/dirty.txt"
  out="$tmp_root/out-prep-dirty"; err="$tmp_root/err-prep-dirty"
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" ship prepare CC-9001 --cd "$work" > "$out" 2> "$err" || status=$?
  if [[ "$status" -eq 1 ]] && grep -q "tree is dirty" "$err" && [[ -f "$work/dirty.txt" ]]; then
    pass "$name"
  else
    fail "$name" "expected exit 1 + dirty.txt preserved; status=$status, dirty.txt exists=$([[ -f "$work/dirty.txt" ]] && echo yes || echo no)"
  fi
}

case_prepare_happy_path_creates_branch() {
  local name="ship prepare: a clean, active ticket creates feat/<ticket-id> and prints it"
  should_run "$name" || return 0
  local store work out status=0
  store="$tmp_root/state-prep-ok"
  work="$tmp_root/work-prep-ok"
  make_work_repo "$work" "CC-9001"
  out="$tmp_root/out-prep-ok"
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" ship prepare CC-9001 --cd "$work" > "$out" 2> "$tmp_root/err-prep-ok" || status=$?
  local branch current
  branch="$(tail -1 "$out")"
  current="$(git -C "$work" rev-parse --abbrev-ref HEAD)"
  if [[ "$status" -eq 0 && "$branch" == "feat/CC-9001" && "$current" == "feat/CC-9001" ]]; then
    pass "$name"
  else
    fail "$name" "expected exit 0 + branch feat/CC-9001, got status=$status branch=$branch current=$current"
  fi
}

case_status_ignores_stale_fallback_from_replaced_lane() {
  local name="ship status: ignores stale same-ticket fallback from a replaced lane"
  should_run "$name" || return 0
  local store work old_lane new_lane reg_dir tracking old_head old_tree old_payload json
  store="$tmp_root/state-status-stale-fallback"
  work="$tmp_root/work-status-stale-fallback"
  old_lane="$tmp_root/old-lane-status-stale"
  new_lane="$tmp_root/new-lane-status-stale"
  make_work_repo "$work" "CC-9001"
  git -C "$work" worktree add -q -b stale-old "$old_lane" HEAD
  git -C "$work" worktree add -q -b stale-new "$new_lane" HEAD
  reg_dir="$(reg_dir_for "$store" "$work")"
  mkdir -p "$reg_dir"
  old_head="$(git -C "$old_lane" rev-parse HEAD)"
  old_tree="$(_gate_subject_tree_fingerprint "$old_lane" committed_head "$old_head")"
  old_payload="$(jq -nc --arg lane_id old-lane-id --arg head "$old_head" --arg tree "$old_tree" \
    '{schema_version:2,ticket:"CC-9001",verdict:"GO",lane_id:$lane_id,
      subject:{head_commit:$head,tree_fingerprint:$tree}}')"
  printf '%s\n' "$old_payload" > "$reg_dir/ship-partial-CC-9001.json"
  tracking="$reg_dir/ship-lanes.jsonl"
  jq -cn --arg path "$new_lane" --arg lane_id new-lane-id \
    '{ticket:"CC-9001",branch:"feat/CC-9001",path:$path,run_id:"",operation_id:"",
      operation_work_dir:"",adapter:"",status:"prepared",created_ts:"2026-08-15T15:00:00Z",lane_id:$lane_id}' \
    > "$tracking"
  json="$(PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" ship status --cd "$work" --json)"
  if [[ "$(jq -r '.[0].status' <<<"$json")" == prepared \
      && "$(jq -r '.[0].lane_id' <<<"$json")" == new-lane-id ]]; then
    pass "$name"
  else
    fail "$name" "expected prepared/new-lane-id, got $json"
  fi
}

case_status_reports_partial_for_pushed_pr_failed() {
  local name="ship-parallel status: a PUSHED_PR_FAILED marker surfaces as status=partial, distinct from no-go"
  should_run "$name" || return 0
  local store work status=0
  store="$tmp_root/state-status-partial"
  work="$tmp_root/work-status-partial"
  make_work_repo "$work" "CC-9001"
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" ship --parallel --no-auto-pack CC-9001 --cd "$work" \
    > "$tmp_root/out-status-partial" 2> "$tmp_root/err-status-partial" || status=$?
  local reg_dir tracking lane_path
  reg_dir="$(reg_dir_for "$store" "$work")"
  tracking="$reg_dir/ship-lanes.jsonl"
  lane_path="$(jq -r '.path' "$tracking")"
  printf '{"ticket":"CC-9001","verdict":"PUSHED_PR_FAILED","branch":"feat/CC-9001","pr_url":null}' \
    > "$lane_path/.pm-dispatch-ship-finish.json"
  local json
  json="$(PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" ship status --cd "$work" --json)"
  if [[ "$(jq -r '.[0].status' <<<"$json")" == "partial" ]]; then
    pass "$name"
  else
    fail "$name" "expected status=partial, got $json"
  fi
}

case_ship_bare_start_behaves_like_prepare() {
  local name="ship <id>: bare call behaves like prepare -- branch only, no worktree, no tracking entry"
  should_run "$name" || return 0
  local store work out status=0
  store="$tmp_root/state-bare-start"
  work="$tmp_root/work-bare-start"
  make_work_repo "$work" "CC-9001"
  out="$tmp_root/out-bare-start"
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" ship CC-9001 --cd "$work" > "$out" 2>&1 || status=$?
  local branch reg_dir
  branch="$(git -C "$work" rev-parse --abbrev-ref HEAD 2>/dev/null)"
  reg_dir="$(reg_dir_for "$store" "$work")"
  if [[ "$status" -eq 0 && "$branch" == "feat/CC-9001" && ! -d "$reg_dir/checkouts/CC-9001" && ! -f "$reg_dir/ship-lanes.jsonl" ]]; then
    pass "$name"
  else
    fail "$name" "expected branch feat/CC-9001, no worktree, no tracking; got status=$status branch=$branch out=$(cat "$out")"
  fi
}

case_ship_worktree_flag_creates_isolated_lane_no_dispatch() {
  local name="ship <id> --worktree: creates isolated worktree, no dispatch, tracked with run_id/adapter empty, status=prepared"
  should_run "$name" || return 0
  local store work out status=0
  store="$tmp_root/state-worktree-only"
  work="$tmp_root/work-worktree-only"
  make_work_repo "$work" "CC-9001"
  out="$tmp_root/out-worktree-only"
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" ship CC-9001 --worktree --cd "$work" > "$out" 2>&1 || status=$?
  local reg_dir tracking
  reg_dir="$(reg_dir_for "$store" "$work")"
  tracking="$reg_dir/ship-lanes.jsonl"
  if [[ "$status" -ne 0 ]]; then
    fail "$name" "run exited $status: $(cat "$out")"
    return
  fi
  if [[ ! -d "$reg_dir/checkouts/CC-9001" ]]; then
    fail "$name" "lane worktree missing at $reg_dir/checkouts/CC-9001"
    return
  fi
  if [[ ! -f "$tracking" ]]; then
    fail "$name" "tracking file missing at $tracking"
    return
  fi
  local ticket run_id adapter lane_status
  ticket="$(jq -r '.ticket' "$tracking")"
  run_id="$(jq -r '.run_id' "$tracking")"
  adapter="$(jq -r '.adapter' "$tracking")"
  lane_status="$(jq -r '.status' "$tracking")"
  if [[ "$ticket" == "CC-9001" && -z "$run_id" && -z "$adapter" && "$lane_status" == "prepared" ]]; then
    pass "$name"
  else
    fail "$name" "unexpected tracking entry: $(cat "$tracking")"
  fi
}

case_ship_adapter_flag_implies_worktree_and_dispatches() {
  local name="ship <id> --adapter: implies --worktree, dispatches, tracked with run_id+adapter, status=dispatched"
  should_run "$name" || return 0
  local store work out status=0
  store="$tmp_root/state-adapter-only"
  work="$tmp_root/work-adapter-only"
  make_work_repo "$work" "CC-9001"
  out="$tmp_root/out-adapter-only"
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" ship CC-9001 --adapter claude --no-auto-pack --cd "$work" > "$out" 2>&1 || status=$?
  local reg_dir tracking
  reg_dir="$(reg_dir_for "$store" "$work")"
  tracking="$reg_dir/ship-lanes.jsonl"
  if [[ "$status" -ne 0 ]]; then
    fail "$name" "run exited $status: $(cat "$out")"
    return
  fi
  if [[ ! -d "$reg_dir/checkouts/CC-9001" ]]; then
    fail "$name" "lane worktree missing at $reg_dir/checkouts/CC-9001"
    return
  fi
  local run_id adapter lane_status
  run_id="$(jq -r '.run_id' "$tracking")"
  adapter="$(jq -r '.adapter' "$tracking")"
  lane_status="$(jq -r '.status' "$tracking")"
  if [[ -n "$run_id" && "$run_id" != null && "$adapter" == "claude" && "$lane_status" == "dispatched" ]]; then
    pass "$name"
  else
    fail "$name" "unexpected tracking entry: $(cat "$tracking")"
  fi
}

case_ship_worktree_and_adapter_together_dispatches_same_as_adapter_alone() {
  local name="ship <id> --worktree --adapter: legal, behaves identically to --adapter alone"
  should_run "$name" || return 0
  local store work out status=0
  store="$tmp_root/state-both-flags"
  work="$tmp_root/work-both-flags"
  make_work_repo "$work" "CC-9001"
  out="$tmp_root/out-both-flags"
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" ship CC-9001 --worktree --adapter claude --no-auto-pack --cd "$work" > "$out" 2>&1 || status=$?
  local reg_dir tracking run_id adapter lane_status
  reg_dir="$(reg_dir_for "$store" "$work")"
  tracking="$reg_dir/ship-lanes.jsonl"
  run_id="$(jq -r '.run_id' "$tracking" 2>/dev/null || true)"
  adapter="$(jq -r '.adapter' "$tracking" 2>/dev/null || true)"
  lane_status="$(jq -r '.status' "$tracking" 2>/dev/null || true)"
  if [[ "$status" -eq 0 && -n "$run_id" && "$run_id" != null && "$adapter" == "claude" && "$lane_status" == "dispatched" ]]; then
    pass "$name"
  else
    fail "$name" "expected dispatched tracking entry; status=$status tracking=$(cat "$tracking" 2>/dev/null)"
  fi
}

case_ship_run_to_finish_declared_allowlist_flows_end_to_end() {
  local name="ship run->finish: a ticket's declared edit paths agree, unchanged, across BACKLOG parsing, the generated brief, the tracking record, and finish's staging enforcement (CC-584)"
  should_run "$name" || return 0
  local store work status=0
  local ticket="CC-9042"
  store="$tmp_root/state-e2e-allowlist"
  work="$tmp_root/work-e2e-allowlist"
  # A distinct ticket id (not CC-9001, used by many sibling cases) so this
  # case's brief file -- mktemp'd under /tmp keyed by ticket id, never
  # cleaned up by pmctl_ship_run itself -- can be found unambiguously by
  # glob below without racing another case's leftover CC-9001 brief.
  # Backtick below is a literal Markdown code span in the ticket text, not
  # command substitution.
  # shellcheck disable=SC2016
  make_work_repo "$work" "$ticket" 'create `notes/output.md` with the summary.'
  local out="$tmp_root/out-e2e-allowlist"
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" ship "$ticket" --adapter claude --no-auto-pack --cd "$work" > "$out" 2>&1 || status=$?
  if [[ "$status" -ne 0 ]]; then
    fail "$name" "dispatch failed: status=$status $(cat "$out")"
    return
  fi
  local reg_dir tracking lane_path
  reg_dir="$(reg_dir_for "$store" "$work")"
  tracking="$reg_dir/ship-lanes.jsonl"
  lane_path="$reg_dir/checkouts/$ticket"
  # 1) BACKLOG parsing -> brief propagation: the generated brief's `edit:`
  # bullet must contain the exact ticket-declared path.
  local brief_glob brief_file=""
  brief_glob="/tmp/brief-ship-${ticket}-*.md"
  # shellcheck disable=SC2086 # deliberate glob expansion, ticket id is fixed alnum/dash
  for f in $brief_glob; do [[ -f "$f" ]] && brief_file="$f" && break; done
  if [[ -z "$brief_file" ]] || ! grep -qF '  - edit: notes/output.md' "$brief_file"; then
    fail "$name" "brief missing declared-path edit bullet: brief=${brief_file:-<none>} $(cat "${brief_file:-/dev/null}" 2>/dev/null)"
    return
  fi
  # 2) BACKLOG parsing -> durable tracking persistence: the SAME path, as
  # actually written to ship-lanes.jsonl by _pmctl_ship_lanes_tracking_write.
  local tracked_declared
  tracked_declared="$(jq -r --arg t "$ticket" 'select(.ticket == $t) | .declared_paths[]?' "$tracking" 2>/dev/null)"
  if [[ "$tracked_declared" != "notes/output.md" ]]; then
    fail "$name" "tracking declared_paths mismatch: got=[$tracked_declared] tracking=$(cat "$tracking" 2>/dev/null)"
    return
  fi
  # 3) Persistence -> finish enforcement: simulate the dispatched executor's
  # real output (the fake claude/codex binaries installed for this whole
  # suite never touch the worktree) -- one declared file, one undeclared
  # collateral file -- and prove finish enforces exactly the SAME allowlist
  # that was parsed from the ticket and persisted above, not a hand-crafted
  # test fixture's own copy of it.
  mkdir -p "$lane_path/notes"
  printf 'summary\n' > "$lane_path/notes/output.md"
  printf 'not declared\n' > "$lane_path/COLLATERAL.md"
  add_bare_origin "$lane_path"
  local finish_out="$tmp_root/out-e2e-allowlist-finish" finish_err="$tmp_root/err-e2e-allowlist-finish"
  local finish_status=0
  PM_DISPATCH_STATE_ROOT="$store" run_finish_with_fake_gate "$lane_path" "$ticket" "GO" \
    > "$finish_out" 2> "$finish_err" || finish_status=$?
  if [[ "$finish_status" -eq 1 ]] && grep -q "undeclared path" "$finish_err" && grep -q "COLLATERAL.md" "$finish_err"; then
    pass "$name"
  else
    fail "$name" "expected the SAME parsed/persisted allowlist to refuse the undeclared collateral file; finish_status=$finish_status stderr=$(cat "$finish_err")"
  fi
}

case_ship_run_to_finish_declared_root_level_file_commits_pre_gate() {
  local name="ship run->finish: a ticket declaring a repository-ROOT deliverable (no directory component) flows through parsing, brief, tracking, and finish to a real pre-gate commit (CC-584)"
  should_run "$name" || return 0
  local store work status=0
  local ticket="CC-9043"
  store="$tmp_root/state-e2e-root-file"
  work="$tmp_root/work-e2e-root-file"
  # Root-level (no `/`) declared path -- the exact shape of the real
  # dogfood evidence that motivated this whole ticket (`SECOND.md`,
  # documented in BACKLOG.md's `## CC-584` section).
  # shellcheck disable=SC2016
  make_work_repo "$work" "$ticket" 'produce `SECOND.md` at the repository root.'
  local out="$tmp_root/out-e2e-root-file"
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" ship "$ticket" --adapter claude --no-auto-pack --cd "$work" > "$out" 2>&1 || status=$?
  if [[ "$status" -ne 0 ]]; then
    fail "$name" "dispatch failed: status=$status $(cat "$out")"
    return
  fi
  local reg_dir tracking lane_path
  reg_dir="$(reg_dir_for "$store" "$work")"
  tracking="$reg_dir/ship-lanes.jsonl"
  lane_path="$reg_dir/checkouts/$ticket"
  local tracked_declared
  tracked_declared="$(jq -r --arg t "$ticket" 'select(.ticket == $t) | .declared_paths[]?' "$tracking" 2>/dev/null)"
  if [[ "$tracked_declared" != "SECOND.md" ]]; then
    fail "$name" "tracking declared_paths mismatch: got=[$tracked_declared] tracking=$(cat "$tracking" 2>/dev/null)"
    return
  fi
  printf 'the deliverable\n' > "$lane_path/SECOND.md"
  add_bare_origin "$lane_path"
  local pre_head
  pre_head="$(git -C "$lane_path" rev-parse HEAD)"
  local gh_bin="$tmp_root/fake-gh-e2e-root-file-bin"
  install_fake_gh "$gh_bin" "https://example.invalid/pr/e2e-root-file"
  local finish_out="$tmp_root/out-e2e-root-file-finish" finish_err="$tmp_root/err-e2e-root-file-finish"
  local finish_status=0
  PM_DISPATCH_STATE_ROOT="$store" PATH="$gh_bin:$PATH" run_finish_with_fake_gate "$lane_path" "$ticket" "GO" \
    > "$finish_out" 2> "$finish_err" || finish_status=$?
  local post_head committed_files pushed=0
  post_head="$(git -C "$lane_path" rev-parse HEAD 2>/dev/null || true)"
  committed_files="$(git -C "$lane_path" diff --name-only "$pre_head" "$post_head" 2>/dev/null || true)"
  git -C "$lane_path.bare-origin.git" show-ref --quiet "feat/$ticket" 2>/dev/null && pushed=1
  if [[ "$finish_status" -eq 0 && "$post_head" != "$pre_head" ]] \
    && [[ "$committed_files" == *"SECOND.md"* ]] && [[ "$pushed" -eq 1 ]]; then
    pass "$name"
  else
    fail "$name" "expected the root-level declared file to be committed pre-gate and pushed; finish_status=$finish_status pre=$pre_head post=$post_head committed_files=[$committed_files] pushed=$pushed stderr=$(cat "$finish_err")"
  fi
}

case_ship_run_to_finish_ignores_paths_cited_outside_requirement() {
  local name="ship run->finish: a path merely CITED in Problem/Why prose (not the Requirement section) never enters the declared allowlist, brief, or tracking (CC-584 gate round 6)"
  should_run "$name" || return 0
  local store work status=0
  local ticket="CC-9044"
  store="$tmp_root/state-e2e-prose-citation"
  work="$tmp_root/work-e2e-prose-citation"
  # Problem cites a real-looking path for CONTEXT only; Requirement declares
  # a completely different, actual deliverable. Only the latter may ever
  # become commit-authorized.
  # shellcheck disable=SC2016
  make_work_repo "$work" "$ticket" \
    'create `notes/output.md` with the summary.' \
    'the bug lives near `docs/sandbox-limitations.md` for reference.'
  local out="$tmp_root/out-e2e-prose-citation"
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" ship "$ticket" --adapter claude --no-auto-pack --cd "$work" > "$out" 2>&1 || status=$?
  if [[ "$status" -ne 0 ]]; then
    fail "$name" "dispatch failed: status=$status $(cat "$out")"
    return
  fi
  local reg_dir tracking lane_path
  reg_dir="$(reg_dir_for "$store" "$work")"
  tracking="$reg_dir/ship-lanes.jsonl"
  lane_path="$reg_dir/checkouts/$ticket"
  # 1) The cited-but-not-declared path never enters the brief's `edit:`
  # list -- NOT "never appears anywhere in the brief": the brief's own
  # boilerplate sandbox-limitations constraint legitimately cites
  # `docs/sandbox-limitations.md` by name (Pattern 4's explanation), so
  # that generic mention must not be confused with an edit declaration.
  local brief_glob brief_file=""
  brief_glob="/tmp/brief-ship-${ticket}-*.md"
  # shellcheck disable=SC2086 # deliberate glob expansion, ticket id is fixed alnum/dash
  for f in $brief_glob; do [[ -f "$f" ]] && brief_file="$f" && break; done
  if [[ -z "$brief_file" ]] || grep -qF '  - edit: docs/sandbox-limitations.md' "$brief_file"; then
    fail "$name" "brief must not declare the Problem-cited path as an edit target: brief=${brief_file:-<none>} $(cat "${brief_file:-/dev/null}" 2>/dev/null)"
    return
  fi
  # 2) Nor the durable tracking record.
  local tracked_declared
  tracked_declared="$(jq -r --arg t "$ticket" 'select(.ticket == $t) | .declared_paths[]?' "$tracking" 2>/dev/null)"
  if [[ "$tracked_declared" != "notes/output.md" ]]; then
    fail "$name" "tracking declared_paths mismatch: got=[$tracked_declared] tracking=$(cat "$tracking" 2>/dev/null)"
    return
  fi
  # 3) If the executor DID touch the cited path, finish refuses exactly like
  # any other undeclared collateral file.
  mkdir -p "$lane_path/notes" "$lane_path/docs"
  printf 'summary\n' > "$lane_path/notes/output.md"
  printf 'unrelated edit\n' > "$lane_path/docs/sandbox-limitations.md"
  add_bare_origin "$lane_path"
  local finish_out="$tmp_root/out-e2e-prose-citation-finish" finish_err="$tmp_root/err-e2e-prose-citation-finish"
  local finish_status=0
  PM_DISPATCH_STATE_ROOT="$store" run_finish_with_fake_gate "$lane_path" "$ticket" "GO" \
    > "$finish_out" 2> "$finish_err" || finish_status=$?
  if [[ "$finish_status" -eq 1 ]] && grep -q "undeclared path" "$finish_err" && grep -q "sandbox-limitations.md" "$finish_err"; then
    pass "$name"
  else
    fail "$name" "expected the cited-only path to be refused as undeclared; finish_status=$finish_status stderr=$(cat "$finish_err")"
  fi
}

case_ship_status_reports_prepared_for_manual_worktree_lane() {
  local name="ship status: a manual --worktree lane (no dispatch, no finish marker) surfaces as status=prepared, not running"
  should_run "$name" || return 0
  local store work status=0
  store="$tmp_root/state-status-prepared"
  work="$tmp_root/work-status-prepared"
  make_work_repo "$work" "CC-9001"
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" ship CC-9001 --worktree --cd "$work" \
    > "$tmp_root/out-status-prepared" 2> "$tmp_root/err-status-prepared" || status=$?
  local json
  json="$(PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" ship status --cd "$work" --json)"
  if [[ "$(jq -r '.[0].status' <<<"$json")" == "prepared" ]]; then
    pass "$name"
  else
    fail "$name" "expected status=prepared, got $json"
  fi
}

case_ship_run_refuses_redispatch_while_in_flight_standalone() {
  local name="ship <id> --adapter (standalone, no --parallel): refuses to re-dispatch a ticket whose prior lane is still running"
  should_run "$name" || return 0
  local store work status=0
  store="$tmp_root/state-standalone-inflight"
  work="$tmp_root/work-standalone-inflight"
  make_work_repo "$work" "CC-9001"

  # Same FIFO-blocking convention as case_run_refuses_redispatch_while_in_flight
  # -- no sleep anywhere, the fake claude blocks until explicitly released.
  local release_fifo="$tmp_root/standalone-inflight-release.fifo"
  rm -f "$release_fifo"
  mkfifo "$release_fifo"
  local slow_bin="$tmp_root/slow-claude-bin-standalone"
  mkdir -p "$slow_bin"
  cat > "$slow_bin/claude" <<FAKEOF
#!/usr/bin/env bash
cat >/dev/null
read -r _ < "$release_fifo"
printf '%s\n' '{"type":"result","subtype":"success","result":"work done","is_error":false,"usage":{"input_tokens":1,"output_tokens":1},"session_id":"fake","num_turns":1}'
exit 0
FAKEOF
  chmod +x "$slow_bin/claude"

  PATH="$slow_bin:$PATH" PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" ship CC-9001 --adapter claude --no-auto-pack --cd "$work" \
    > "$tmp_root/out-standalone-inflight-1" 2> "$tmp_root/err-standalone-inflight-1"

  local err2 status2=0
  err2="$tmp_root/err-standalone-inflight-2"
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" ship CC-9001 --adapter claude --no-auto-pack --cd "$work" \
    > "$tmp_root/out-standalone-inflight-2" 2> "$err2" || status2=$?

  # shellcheck disable=SC2016
  timeout 30 bash -c 'printf release > "$1"' _ "$release_fifo" 2>/dev/null || true

  if [[ "$status2" -eq 1 ]] && grep -q "already has an in-flight lane" "$err2"; then
    pass "$name"
  else
    fail "$name" "expected exit 1 + in-flight refusal message; got status=$status2 stderr=$(cat "$err2")"
  fi
}

case_ship_dispatch_failure_after_worktree_records_dispatch_failed_lane() {
  local name="ship <id> --adapter: a dispatch-run failure AFTER worktree creation still writes a ship-lanes.jsonl entry (status=dispatch-failed), not an untracked orphan"
  should_run "$name" || return 0
  local store work out status=0
  store="$tmp_root/state-dispatchfail"
  work="$tmp_root/work-dispatchfail"
  make_work_repo "$work" "CC-9001"
  out="$tmp_root/out-dispatchfail"
  # An adapter name with no adapters/<name>/dispatch.sh fails fast inside
  # `pmctl dispatch run` itself (unknown adapter), well AFTER
  # `pmctl_worktree_create` has already run inside `pmctl_ship_run` --
  # exactly the failure-after-worktree-creation path the gate review flagged
  # as producing an untracked, invisible-to-`ship status` orphan lane.
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" ship CC-9001 --adapter totally-bogus-adapter --cd "$work" > "$out" 2>&1 || status=$?
  local reg_dir tracking
  reg_dir="$(reg_dir_for "$store" "$work")"
  tracking="$reg_dir/ship-lanes.jsonl"
  if [[ "$status" -eq 0 ]]; then
    fail "$name" "expected nonzero exit for a bogus adapter; got 0"
    return
  fi
  if [[ ! -d "$reg_dir/checkouts/CC-9001" ]]; then
    fail "$name" "expected the worktree to still exist (created before dispatch was attempted); missing at $reg_dir/checkouts/CC-9001"
    return
  fi
  if [[ ! -f "$tracking" ]]; then
    fail "$name" "tracking file missing entirely -- the orphan-lane bug the gate review flagged; expected at $tracking"
    return
  fi
  local run_id lane_status operation_id operation_state
  run_id="$(jq -r '.run_id' "$tracking")"
  lane_status="$(jq -r '.status' "$tracking")"
  operation_id="$(find "$(dirname "$reg_dir")/operations" -maxdepth 1 -name 'op-*.json' -type f -printf '%f\n' 2>/dev/null | sed 's/\.json$//' | head -1)"
  operation_state="$(jq -r .state "$(dirname "$reg_dir")/operations/$operation_id.json" 2>/dev/null || true)"
  if [[ -z "$run_id" && "$lane_status" == "dispatch-failed" && "$operation_state" == failed ]]; then
    pass "$name"
  else
    fail "$name" "expected run_id empty + status=dispatch-failed + failed parent; operation=$operation_id state=$operation_state tracking=$(cat "$tracking")"
  fi
}

case_ship_status_preserves_dispatch_failed_across_refresh() {
  local name="ship status: a dispatch-failed lane stays dispatch-failed on refresh, not downgraded back to prepared"
  should_run "$name" || return 0
  local store work status=0
  store="$tmp_root/state-dispatchfail-refresh"
  work="$tmp_root/work-dispatchfail-refresh"
  make_work_repo "$work" "CC-9001"
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" ship CC-9001 --adapter totally-bogus-adapter --cd "$work" \
    > "$tmp_root/out-dispatchfail-refresh" 2>&1 || status=$?
  local json
  json="$(PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" ship status --cd "$work" --json)"
  if [[ "$(jq -r '.[0].status' <<<"$json")" == "dispatch-failed" ]]; then
    pass "$name"
  else
    fail "$name" "expected status=dispatch-failed after refresh, got $json"
  fi
}

case_ship_tracking_append_failure_is_hard_failure() {
  local name="ship <id> --worktree: tracking-append failure is a hard failure (nonzero exit), not a swallowed warning"
  should_run "$name" || return 0
  local store work status=0
  store="$tmp_root/state-trackfail"
  work="$tmp_root/work-trackfail"
  make_work_repo "$work" "CC-9001"
  # Stub `pmctl_ship_lanes_tracking_append` to always fail -- simulates a
  # disk-full / lock-timeout / permission failure in the state store
  # independent of worktree creation (which must still have succeeded by
  # the time this stub is reached).
  local out err
  out="$tmp_root/out-trackfail"; err="$tmp_root/err-trackfail"
  PM_DISPATCH_STATE_ROOT="$store" bash -c '
    repo_root="$1"; work_dir="$2"; ticket_id="$3"
    for lib in portable state-writer state-paths pmctl-worktree pmctl-ship pmctl-ship-parallel; do
      # shellcheck disable=SC1090
      . "$repo_root/runtime/lib/$lib.sh"
    done
    pmctl_ship_lanes_tracking_append() { return 1; }
    pmctl_ship_run "$repo_root" "$work_dir" "$ticket_id" --worktree
  ' _ "$REPO_ROOT" "$work" "CC-9001" > "$out" 2> "$err" || status=$?
  if [[ "$status" -ne 0 ]] && grep -q "CRITICAL" "$err" && grep -q "tracking-append failed" "$err"; then
    pass "$name"
  else
    fail "$name" "expected nonzero exit + CRITICAL tracking-append message; got status=$status stderr=$(cat "$err")"
  fi
}

case_ship_adapter_missing_value_fails_before_any_side_effect() {
  local name="ship <id> --adapter: an option-shaped (or missing) operand is rejected before any worktree/tracking side effect"
  should_run "$name" || return 0
  local store work out status=0
  store="$tmp_root/state-adapter-badvalue"
  work="$tmp_root/work-adapter-badvalue"
  make_work_repo "$work" "CC-9001"
  out="$tmp_root/out-adapter-badvalue"
  # `--no-auto-pack` immediately follows `--adapter` -- a naive parser takes
  # it as --adapter's VALUE (not as its own flag), silently creating a
  # worktree with adapter="--no-auto-pack" before dispatch ever validates
  # the (bogus) adapter name. This must fail fast, before touching anything.
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" ship CC-9001 --adapter --no-auto-pack --cd "$work" > "$out" 2>&1 || status=$?
  local reg_dir
  reg_dir="$(reg_dir_for "$store" "$work")"
  if [[ "$status" -eq 2 ]] && grep -q -- "--adapter requires a value" "$out" \
     && [[ ! -d "$reg_dir/checkouts/CC-9001" ]] && [[ ! -f "$reg_dir/ship-lanes.jsonl" ]]; then
    pass "$name"
  else
    fail "$name" "expected exit 2 + 'requires a value' + no worktree/tracking; got status=$status out=$(cat "$out") reg_dir=$reg_dir"
  fi
}

case_ship_adapter_trailing_flag_missing_value_fails() {
  local name="ship <id> --adapter: a trailing --adapter with no operand at all is rejected"
  should_run "$name" || return 0
  local store work out status=0
  store="$tmp_root/state-adapter-trailing"
  work="$tmp_root/work-adapter-trailing"
  make_work_repo "$work" "CC-9001"
  out="$tmp_root/out-adapter-trailing"
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" ship CC-9001 --cd "$work" --adapter > "$out" 2>&1 || status=$?
  local reg_dir
  reg_dir="$(reg_dir_for "$store" "$work")"
  if [[ "$status" -eq 2 ]] && grep -q -- "--adapter requires a value" "$out" \
     && [[ ! -d "$reg_dir/checkouts/CC-9001" ]]; then
    pass "$name"
  else
    fail "$name" "expected exit 2 + 'requires a value' + no worktree; got status=$status out=$(cat "$out") reg_dir=$reg_dir"
  fi
}

case_ship_status_warns_on_legacy_tracking_file() {
  local name="ship status: a leftover legacy ship-parallel.jsonl (pre-rename) triggers an explicit notice instead of a silent 'no tracked lanes'"
  should_run "$name" || return 0
  local store work
  store="$tmp_root/state-legacy-tracking"
  work="$tmp_root/work-legacy-tracking"
  make_work_repo "$work" "CC-9001"
  local reg_dir
  reg_dir="$(reg_dir_for "$store" "$work")"
  mkdir -p "$reg_dir"
  printf '{"ticket":"CC-9001","branch":"feat/CC-9001","path":"/tmp/nonexistent","run_id":"old-run","status":"dispatched","created_ts":"2026-01-01T00:00:00Z"}\n' \
    > "$reg_dir/ship-parallel.jsonl"
  local err
  err="$(PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" ship status --cd "$work" 2>&1 >/dev/null)"
  if grep -q "legacy ship-parallel.jsonl" <<<"$err"; then
    pass "$name"
  else
    fail "$name" "expected a legacy-file notice on stderr, got: $err"
  fi
}

case_ship_rejects_duplicate_positional_ticket() {
  local name="ship <id>: a second positional ticket-id is rejected, not silently overwritten"
  should_run "$name" || return 0
  local store work out status=0
  store="$tmp_root/state-dup-positional"
  work="$tmp_root/work-dup-positional"
  make_work_repo "$work" "CC-9001"
  printf '## CC-9002 -- mock ticket %s\n\nProblem: test fixture.\n\nRequirement: none.\n\nDependencies: none.\n' "🔵 active" >> "$work/BACKLOG.md"
  out="$tmp_root/out-dup-positional"
  # A mistyped second ticket id must never silently pick one over the other
  # -- it must fail before touching either ticket's worktree.
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" ship CC-9001 CC-9002 --worktree --cd "$work" > "$out" 2>&1 || status=$?
  local reg_dir
  reg_dir="$(reg_dir_for "$store" "$work")"
  if [[ "$status" -eq 2 ]] && grep -q "unexpected extra positional argument" "$out" \
     && [[ ! -d "$reg_dir/checkouts/CC-9001" ]] && [[ ! -d "$reg_dir/checkouts/CC-9002" ]]; then
    pass "$name"
  else
    fail "$name" "expected exit 2 + rejection message + no worktree for either ticket; got status=$status out=$(cat "$out")"
  fi
}

case_ship_single_ticket_isolation_and_model_reach_real_dispatch() {
  local name="ship <id> --adapter (single-ticket route, not --parallel): --isolation and --model, forwarded by cli/pmctl's OWN parser, reach the real adapter invocation"
  should_run "$name" || return 0
  local store work
  store="$tmp_root/state-single-isolation-model"
  work="$tmp_root/work-single-isolation-model"
  make_work_repo "$work" "CC-9001"
  # A dedicated fake `claude` that captures its OWN argv -- proves --isolation
  # and --model survive cli/pmctl's ship/* parsing + pmctl_ship_run's own
  # forwarding all the way to the real adapter exec, not just pmctl_ship_run's
  # internals (which the --parallel-focused flag tests exercise via a stubbed
  # pmctl_dispatch_run call that bypasses cli/pmctl's own parser entirely).
  local argv_capture="$tmp_root/single-isolation-model-argv"
  rm -f "$argv_capture"
  local capture_bin="$tmp_root/capture-claude-bin-im"
  mkdir -p "$capture_bin"
  cat > "$capture_bin/claude" <<FAKEOF
#!/usr/bin/env bash
cat >/dev/null
printf '%s\n' "\$@" > "$argv_capture"
printf '%s\n' '{"type":"result","subtype":"success","result":"work done","is_error":false,"usage":{"input_tokens":1,"output_tokens":1},"session_id":"fake","num_turns":1}'
exit 0
FAKEOF
  chmod +x "$capture_bin/claude"

  local status=0
  PATH="$capture_bin:$PATH" PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" ship CC-9001 --adapter claude --isolation read-only --model sonnet --no-auto-pack --cd "$work" \
    > "$tmp_root/out-single-im" 2> "$tmp_root/err-single-im" || status=$?

  # Dispatch is --lifecycle detached: the ship command above returns as soon
  # as the supervisor is launched, before the (fake) adapter necessarily runs
  # -- reading argv_capture immediately would race it. run_id/lane path are
  # already durable (tracking-append is synchronous, before ship returns);
  # `pmctl dispatch wait` is the real blocking primitive for "has the
  # detached process actually finished", not a sleep/poll loop.
  local reg_dir tracking run_id lane_path
  reg_dir="$(reg_dir_for "$store" "$work")"
  tracking="$reg_dir/ship-lanes.jsonl"
  run_id="$(jq -r '.run_id // ""' "$tracking" 2>/dev/null || true)"
  lane_path="$(jq -r '.path // ""' "$tracking" 2>/dev/null || true)"
  if [[ -n "$run_id" && -n "$lane_path" ]]; then
    PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" dispatch wait "$run_id" --cd "$lane_path" >/dev/null 2>&1 || true
  fi

  local argv=""
  [[ -f "$argv_capture" ]] && argv="$(cat "$argv_capture" 2>/dev/null || true)"
  # --isolation read-only maps to permission_mode=default (adapters/claude/isolation-map.yaml).
  if [[ "$status" -eq 0 ]] && grep -q -- '--permission-mode' <<<"$argv" && grep -Fxq 'default' <<<"$argv" && grep -q -- '--model' <<<"$argv"; then
    pass "$name"
  else
    fail "$name" "expected --permission-mode default (from --isolation read-only) and --model in the real adapter argv; status=$status argv=$argv"
  fi
}

case_ship_single_ticket_from_and_auto_pack_flags_reach_dispatch() {
  local name="ship <id> --adapter (single-ticket route, not --parallel): --from sets the lane's branch base, and --auto-pack/--no-auto-pack are accepted by cli/pmctl's own parser without error"
  should_run "$name" || return 0
  local store work
  store="$tmp_root/state-single-from-autopack"
  work="$tmp_root/work-single-from-autopack"
  make_work_repo "$work" "CC-9001"
  git -C "$work" checkout -q -b side-base
  printf 'only-on-side-base\n' > "$work/side-marker.txt"
  git -C "$work" add side-marker.txt
  git -C "$work" commit -q -m "side base marker"
  git -C "$work" checkout -q master 2>/dev/null || git -C "$work" checkout -q main

  local status=0
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" ship CC-9001 --adapter claude --from side-base --no-auto-pack --cd "$work" \
    > "$tmp_root/out-single-from" 2> "$tmp_root/err-single-from" || status=$?

  local reg_dir lane_path
  reg_dir="$(reg_dir_for "$store" "$work")"
  lane_path="$reg_dir/checkouts/CC-9001"
  if [[ "$status" -eq 0 && -f "$lane_path/side-marker.txt" ]]; then
    pass "$name"
  else
    fail "$name" "expected lane worktree branched from side-base (side-marker.txt present) and exit 0; status=$status lane=$lane_path"
  fi
}

case_ship_brief_quotes_metacharacter_lane_path() {
  local name="ship brief writer: a lane path with shell metacharacters is safely quoted in every generated command (self_verify), and never instructs the executor to commit/finish (CC-584)"
  should_run "$name" || return 0
  local evil_path="$tmp_root/evil dir; touch pwned-marker"
  local brief_path="$tmp_root/brief-metachar-test.md"
  bash -c '
    repo_root="$1"; ticket_id="$2"; lane_work_dir="$3"; branch="$4"; out_path="$5"
    . "$repo_root/runtime/lib/pmctl-ship.sh"
    _pmctl_ship_brief_write "$repo_root" "$ticket_id" "$lane_work_dir" "$branch" "$out_path"
  ' _ "$REPO_ROOT" "CC-9001" "$evil_path" "feat/CC-9001" "$brief_path"
  local quoted self_verify_line
  quoted="$(printf '%q' "$evil_path")"
  self_verify_line="$(grep -m1 '^  - cmd: ' "$brief_path")"
  # self_verify's `cmd:` is the ONLY line in this brief that generates a shell
  # command referencing the lane path (CC-584 removed the export/finish
  # instructions entirely -- the executor's sandbox cannot reach either, since
  # it cannot commit; see the "Do NOT run git add..." constraint). It must use
  # the shell-escaped form -- a raw, unescaped semicolon would let the
  # executor's shell reinterpret it as two commands instead of one argument.
  # (The plain `working_dir:` YAML metadata field legitimately keeps the raw
  # path -- it is read as data, never executed as a shell command.)
  if [[ "$self_verify_line" == *"$quoted"* ]] && [[ "$self_verify_line" != *"$evil_path"* ]] \
     && ! grep -q 'export PM_DISPATCH_STATE_ROOT=' "$brief_path" \
     && ! grep -q '^  - Gate + PR: run' "$brief_path"; then
    pass "$name"
  else
    fail "$name" "expected self_verify to use the shell-escaped form ($quoted) and no export/finish instruction; self_verify_line=$self_verify_line brief=$(cat "$brief_path")"
  fi
}

case_run_tracks_adapter_field() {
  local name="ship-parallel run: tracking entry includes adapter field matching the dispatched adapter"
  should_run "$name" || return 0
  local store work status=0
  store="$tmp_root/state-run-adapterfield"
  work="$tmp_root/work-run-adapterfield"
  make_work_repo "$work" "CC-9001"
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" ship --parallel --no-auto-pack --adapter claude CC-9001 --cd "$work" \
    > "$tmp_root/out-adapterfield" 2> "$tmp_root/err-adapterfield" || status=$?
  local reg_dir tracking adapter
  reg_dir="$(reg_dir_for "$store" "$work")"
  tracking="$reg_dir/ship-lanes.jsonl"
  adapter="$(jq -r '.adapter' "$tracking" 2>/dev/null || true)"
  if [[ "$status" -eq 0 && "$adapter" == "claude" ]]; then
    pass "$name"
  else
    fail "$name" "expected adapter=claude in tracking entry; status=$status tracking=$(cat "$tracking" 2>/dev/null)"
  fi
}

case_ship_operation_routes_via_cli() {
  local name="ship operation CLI: cancel and reconcile route with positional operation id and --cd"
  should_run "$name" || return 0
  local work="$tmp_root/ship-operation-cli-work" state="$tmp_root/ship-operation-cli-state" cancel_op reconcile_op run_id out
  mkdir -p "$work"; git -C "$work" init -q
  cancel_op="$(PM_DISPATCH_STATE_ROOT="$state" pmctl_operation_create "$REPO_ROOT" "$work" ship codex)"
  out="$(PM_DISPATCH_STATE_ROOT="$state" "$PMCTL" ship cancel "$cancel_op" --cd "$work")"
  reconcile_op="$(PM_DISPATCH_STATE_ROOT="$state" pmctl_operation_create "$REPO_ROOT" "$work" ship codex)"
  run_id="run-20260724T000070Z-aaaaaa"
  PM_DISPATCH_STATE_ROOT="$state" pmctl_operation_attach_child "$REPO_ROOT" "$work" "$reconcile_op" "$run_id" "$work"
  PM_DISPATCH_STATE_ROOT="$state" _pmctl_dispatch_try_terminal_claim "$work" "$run_id" ok supervisor
  out+=" $(PM_DISPATCH_STATE_ROOT="$state" "$PMCTL" ship reconcile "$reconcile_op" --cd "$work")"
  if [[ "$out" == *"state: cancelled"* && "$out" == *"state: completed"* ]]; then pass "$name"; else fail "$name" "out=$out"; fi
}

case_ship_operation_cli_unavailable_fallbacks() {
  local name="ship operation CLI: cancel and reconcile report unavailable without operation library"
  should_run "$name" || return 0
  local fixture="$tmp_root/ship-operation-cli-missing" cancel_out reconcile_out cancel_rc=0 reconcile_rc=0
  mkdir -p "$fixture/cli" "$fixture/runtime/lib"
  cp "$REPO_ROOT/cli/pmctl" "$fixture/cli/pmctl"; chmod +x "$fixture/cli/pmctl"
  cp "$REPO_ROOT/runtime/lib/pmctl-command-catalog.sh" "$fixture/runtime/lib/pmctl-command-catalog.sh"
  cancel_out="$("$fixture/cli/pmctl" ship cancel op-20260724T000071Z-aaaaaa --cd /tmp 2>&1)" || cancel_rc=$?
  reconcile_out="$("$fixture/cli/pmctl" ship reconcile op-20260724T000071Z-aaaaaa --cd /tmp 2>&1)" || reconcile_rc=$?
  if [[ "$cancel_rc" -eq 2 && "$reconcile_rc" -eq 2 && "$cancel_out" == *"ship cancel unavailable"* && "$reconcile_out" == *"ship reconcile unavailable"* ]]; then pass "$name"; else fail "$name" "cancel=$cancel_rc:$cancel_out reconcile=$reconcile_rc:$reconcile_out"; fi
}

case_ship_standalone_source_loads_identifier_policy_for_terminal_reconciliation() {
  local name="ship tracking refresh: standalone pmctl-ship import reconciles a valid terminal operation"
  should_run "$name" || return 0
  local fixture="$tmp_root/ship-standalone-policy" tracking="$tmp_root/ship-standalone-policy/ship-lanes.jsonl"
  local marker="$tmp_root/ship-standalone-policy/reconciled" status=0
  mkdir -p "$fixture"
  printf '%s\n' '{"ticket":"CC-9001","branch":"feat/CC-9001","path":"/tmp/ship-standalone-lane","run_id":"run-20260811T000000Z-abcdef","operation_id":"op-20260811T000000Z-a1b2c3","operation_work_dir":"/tmp","status":"dispatched"}' > "$tracking"
  bash -c '
    repo_root="$1"; tracking="$2"; marker="$3"
    . "$repo_root/runtime/lib/pmctl-ship.sh"
    _pmctl_ship_lane_status() { printf "failed\\n"; }
    pmctl_operation_reconcile() { printf "%s\\n" "$3" > "$marker"; }
    _pmctl_ship_lanes_tracking_refresh_inner "$repo_root" "$tracking" 1 >/dev/null
    test "$(cat "$marker")" = "op-20260811T000000Z-a1b2c3"
  ' _ "$REPO_ROOT" "$tracking" "$marker" || status=$?
  if [[ "$status" -eq 0 ]]; then pass "$name"; else fail "$name" "standalone refresh did not reconcile the terminal operation"; fi
}


case_status_ignores_stale_fallback_from_replaced_lane
case_status_reports_partial_for_pushed_pr_failed
case_prepare_empty_argument
case_prepare_malformed_shape
case_prepare_no_such_ticket
case_prepare_archived_ticket
case_prepare_dirty_tree_refused
case_prepare_happy_path_creates_branch
case_run_requires_ticket
case_run_rejects_unknown_ticket
case_run_rejects_regex_metachar_ticket_id
case_run_rejects_prefix_collision_ticket_id
case_prepare_rejects_prefix_collision_ticket_id
case_run_rejects_duplicate_ticket_in_batch
case_run_bad_ticket_leaves_no_worktree
case_run_refuses_redispatch_while_in_flight
case_run_flag_adapter_reaches_dispatch
case_run_flag_isolation_reaches_dispatch
case_run_flag_model_reaches_dispatch
case_run_flag_no_auto_pack_reaches_dispatch
case_run_flag_auto_pack_reaches_dispatch
case_run_flag_from_sets_worktree_base
case_run_dispatches_and_tracks
case_run_brief_preserves_ship_contract
case_run_restores_gc_auto_previously_set
case_run_restores_gc_auto_previously_unset
case_status_never_reports_go_from_free_text_without_marker
case_status_reports_go_from_finish_marker_even_without_final_go_text
case_status_reports_no_go_from_final_line
case_status_no_record_yet_is_running
case_list_filters_to_go_only
case_list_empty_when_none_go
case_status_no_tracked_lanes
case_ship_bare_start_behaves_like_prepare
case_ship_worktree_flag_creates_isolated_lane_no_dispatch
case_ship_adapter_flag_implies_worktree_and_dispatches
case_ship_worktree_and_adapter_together_dispatches_same_as_adapter_alone
case_ship_run_to_finish_declared_allowlist_flows_end_to_end
case_ship_run_to_finish_declared_root_level_file_commits_pre_gate
case_ship_run_to_finish_ignores_paths_cited_outside_requirement
case_ship_status_reports_prepared_for_manual_worktree_lane
case_ship_run_refuses_redispatch_while_in_flight_standalone
case_ship_dispatch_failure_after_worktree_records_dispatch_failed_lane
case_ship_status_preserves_dispatch_failed_across_refresh
case_ship_tracking_append_failure_is_hard_failure
case_ship_status_warns_on_legacy_tracking_file
case_ship_rejects_duplicate_positional_ticket
case_ship_single_ticket_isolation_and_model_reach_real_dispatch
case_ship_single_ticket_from_and_auto_pack_flags_reach_dispatch
case_ship_brief_quotes_metacharacter_lane_path
case_ship_adapter_missing_value_fails_before_any_side_effect
case_ship_adapter_trailing_flag_missing_value_fails
case_run_tracks_adapter_field
case_ship_operation_routes_via_cli
case_ship_operation_cli_unavailable_fallbacks
case_ship_standalone_source_loads_identifier_policy_for_terminal_reconciliation

# Detached dispatch supervisors from the fake-codex/claude runs above can
# still be mid-write (dispatch record, trace files) a moment after their
# `pmctl ship --parallel` call returned. These are daemonized (setsid) --
# no longer child processes of this shell -- so plain `wait` cannot block
# on them; `tail --pid=<pid> -f /dev/null` is the sleep-free blocking
# primitive used instead: it blocks on that PID's actual exit (real
# process-exit notification, not a timed poll), bounded per-PID via
# `timeout` so a stuck fake process cannot hang the suite. Best-effort
# cleanup courtesy, not a correctness dependency for any case above (every
# case already asserts its own outcome before this point).
_lingering_pid=""
for _lingering_pid in $(pgrep -f -- "$tmp_root" 2>/dev/null); do
  if ! timeout 5 tail --pid="$_lingering_pid" -f /dev/null < /dev/null > /dev/null 2>&1; then
    # A detached supervisor that outlives its bounded grace period would race
    # the harness EXIT cleanup and recreate files beneath tmp_root. Reap its
    # descendants first, then the supervisor; all processes here are suite
    # fixtures discovered by the tmp_root path filter above.
    _ship_reap_tree() {
      local pid="$1" child
      for child in $(pgrep -P "$pid" 2>/dev/null || true); do
        _ship_reap_tree "$child"
      done
      kill -TERM "$pid" 2>/dev/null || true
    }
    _ship_reap_tree "$_lingering_pid"
    timeout 2 tail --pid="$_lingering_pid" -f /dev/null < /dev/null > /dev/null 2>&1 || \
      kill -KILL "$_lingering_pid" 2>/dev/null || true
  fi
done
unset _lingering_pid

th_summary
