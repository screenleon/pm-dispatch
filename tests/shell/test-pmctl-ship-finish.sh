#!/usr/bin/env bash
# Regression tests for `pmctl ship finish` and its gate/publish-assessment/
# closure pipeline (including CC-584's dispatched-lane auto-commit). Split
# out of `test-pmctl-ship.sh` (the dispatch/lifecycle half) in CC-584 gate
# round 7 purely so each half completes within the QA harness's per-suite
# timeout; the two files share the same fixtures verbatim by design -- keep
# them in sync if a shared helper changes.
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

case_publish_assessment_binds_closure_and_full_suite() {
  local name="ship publish assessment: closure and full suite must bind to the Gate subject"
  should_run "$name" || return 0
  local dir gate assurance closure full assessment out err status=0
  dir="$tmp_root/publish-assessment-bind"
  mkdir -p "$dir"
  gate="$dir/gate.json"; assurance="$dir/gate.assurance.json"
  closure="$dir/closure.json"; full="$dir/full.json"; assessment="$dir/assessment.json"
  printf 'gate result\n' > "$dir/gate.md"
  jq -n --arg assurance "$assurance" --arg result "$dir/gate.md" '
    {kind:"gate_verification_v1",schema_version:1,result_file:$result,verdict:"GO",
     assurance:{status:"verified",kind:"gate_assurance_v3",file:$assurance},consumer:"embedded",
     axes:{artifact_valid:{status:"pass",reason_codes:[]},
       subject_current:{status:"pass",reason_codes:[],current:{repository_key:("a"*64),base_commit:("1"*40),head_commit:("2"*40),tree_fingerprint:("b"*64),observed_root:"/tmp/repo"}},
       policy_applicable:{status:"pass",reason_codes:[],consumer:"embedded",required_policy:"generic",preferred_policy:"generic",embedded_policy:"generic",policy_satisfaction:"preferred"}}}
  ' > "$gate"
  jq -n '{evidence:{scope_manifest:{sha256:("c"*64)}}}' > "$assurance"
  jq -n '{kind:"remediation_closure_v1",schema_version:1,state:"closed",final_assessment:{publish_authorized:true,subject_fingerprint:("b"*64)},final_subject:{tree_fingerprint:("b"*64)},targeted_confirmation:{status:"pass"}}' > "$closure"
  jq -n '{kind:"pm_test_result_v2",contract:"full",authoritative:true,status:"pass",aggregate:{status:"pass"},exit_code:0,tree_fingerprint:("b"*64)}' > "$full"
  out="$dir/out"; err="$dir/err"
  bash -c '
    repo_root="$1"; output="$2"; gate="$3"; closure="$4"; full="$5"
    gate_structural_schema_verify() { return 0; }
    gate_remediation_closure_verify() { return 0; }
    gate_digest_file() { sha256sum "$1" | awk '\''{print $1}'\''; }
    gate_policy_applicability_assess() {
      jq -n '\''{status:"pass",reason_codes:[],embedded_policy:"generic",required_policy:"generic",preferred_policy:"maintainer",policy_satisfaction:"baseline"}'\''
    }
    . "$repo_root/runtime/lib/gate-publish.sh"
    gate_publish_assessment_build "$output" "$gate" "$closure" "$full" CC-511
    gate_publish_assessment_verify "$output"
  ' _ "$REPO_ROOT" "$assessment" "$gate" "$closure" "$full" > "$out" 2> "$err" || status=$?
  if [[ "$status" -eq 0 ]] \
      && jq -e '.authorization.route == "primary_review_closure" and .policy.policy_satisfaction == "baseline" and .closure.targeted_confirmation == "pass"' "$assessment" >/dev/null 2>&1; then
    pass "$name"
  else
    fail "$name" "assessment builder failed: status=$status stdout=$(cat "$out") stderr=$(cat "$err")"
  fi
}

case_publish_assessment_route_follows_reviewed_subject() {
  local name="ship publish assessment: route follows the subject the primary review examined"
  should_run "$name" || return 0
  local final_fp same_fp other_fp row primary targeted expected actual dir n=0 bad=""
  final_fp="$(printf 'b%.0s' {1..64})"
  same_fp="$final_fp"
  other_fp="$(printf 'd%.0s' {1..64})"

  # primary-subject | targeted-confirmation | expected route
  #
  # Row 3 is the case a confirmation-derived label gets wrong: remediation that
  # closed entirely locally needs no targeted confirmation, yet the primary
  # review remains bound to the pre-remediation tree.
  for row in \
    "$same_fp|not_required|final_tree_review" \
    "$same_fp|pass|final_tree_review" \
    "$other_fp|not_required|primary_review_closure" \
    "$other_fp|pass|primary_review_closure"; do
    primary="${row%%|*}"; targeted="${row#*|}"; expected="${targeted#*|}"; targeted="${targeted%%|*}"
    n=$((n + 1))
    dir="$tmp_root/publish-route-matrix/$n"
    publish_assessment_fixture "$dir" "$primary" "$targeted"
    if ! run_real_publish_assessment_build "$dir" >/dev/null 2>"$dir/err"; then
      bad+=" row$n:build-failed($(tr -d '\n' < "$dir/err"))"
      continue
    fi
    actual="$(jq -r '.authorization.route' "$dir/assessment.json")"
    [[ "$actual" == "$expected" ]] || \
      bad+=" row$n:primary=${primary:0:1}*,targeted=$targeted expected=$expected actual=$actual"
  done

  if [[ -z "$bad" ]]; then pass "$name"; else fail "$name" "route mismatches:$bad"; fi
}

case_ship_subject_fingerprint_requires_canonical_helper() {
  local name="ship subject fingerprint requires canonical Gate helper"
  should_run "$name" || return 0
  local work="$tmp_root/ship-canonical-subject-helper" status=0
  make_work_repo "$work" "CC-9001"
  bash -c '
    repo_root="$1"; work_dir="$2"
    . "$repo_root/runtime/lib/pmctl-ship.sh"
    unset -f _gate_subject_tree_fingerprint
    _pmctl_ship_tree_fingerprint "$work_dir" committed_head HEAD
  ' _ "$REPO_ROOT" "$work" >/dev/null 2>&1 || status=$?
  if [[ "$status" -ne 0 ]]; then
    pass "$name"
  else
    fail "$name" "ship accepted a missing canonical subject helper"
  fi
}

case_ship_subject_fingerprint_matches_independent_gate_oracle() {
  local name="ship subject fingerprint matches independent Gate oracle and mutation contract"
  should_run "$name" || return 0
  local work head expected baseline mode_changed link_changed content_changed excluded status=0
  work="$tmp_root/ship-independent-subject-oracle"
  make_work_repo "$work" "CC-9001"
  printf 'regular fixture\n' > "$work/regular.txt"
  printf '#!/usr/bin/env bash\nprintf executable\\n\n' > "$work/run.sh"
  chmod +x "$work/run.sh"
  ln -s regular.txt "$work/link"
  printf '.gate-results/\n' >> "$work/.gitignore"
  git -C "$work" add .gitignore regular.txt run.sh link
  git -C "$work" -c user.email=test@example.com -c user.name=test commit -q -m subject-fixture
  head="$(git -C "$work" rev-parse HEAD)"
  expected="$(independent_fixed_tree_fingerprint "$work" "$head")"
  actual="$(_gate_subject_tree_fingerprint "$work" fixed_ref "$head")"
  if [[ "$actual" != "$expected" ]]; then
    fail "$name" "committed subject differs from independent oracle: expected=$expected actual=$actual"
    return 0
  fi

  baseline="$(_gate_subject_tree_fingerprint "$work" working_tree "$head")"
  chmod -x "$work/run.sh"
  mode_changed="$(_gate_subject_tree_fingerprint "$work" working_tree "$head")"
  chmod +x "$work/run.sh"
  rm -f -- "$work/link"
  ln -s run.sh "$work/link"
  link_changed="$(_gate_subject_tree_fingerprint "$work" working_tree "$head")"
  rm -f -- "$work/link"
  ln -s regular.txt "$work/link"
  printf 'changed fixture\n' > "$work/regular.txt"
  content_changed="$(_gate_subject_tree_fingerprint "$work" working_tree "$head")"
  printf 'regular fixture\n' > "$work/regular.txt"
  mkdir -p "$work/.gate-results"
  printf 'runtime artifact\n' > "$work/.gate-results/ignored.txt"
  excluded="$(_gate_subject_tree_fingerprint "$work" working_tree "$head")"
  if [[ "$mode_changed" == "$baseline" || "$link_changed" == "$baseline" ||
        "$content_changed" == "$baseline" || "$excluded" != "$baseline" ]]; then
    fail "$name" "mutation contract failed: baseline=$baseline mode=$mode_changed link=$link_changed content=$content_changed excluded=$excluded"
    return 0
  fi
  if _gate_subject_tree_fingerprint "$work" invalid_kind "$head" >/dev/null 2>&1; then
    fail "$name" "unsupported subject kind was accepted"
    return 0
  fi
  pass "$name"
}

case_publish_assessment_rejects_existing_destination() {
  local name="ship publish assessment: existing destination is not overwritten"
  should_run "$name" || return 0
  local dir status=0 before after
  dir="$tmp_root/publish-assessment-existing"
  publish_assessment_fixture "$dir"
  printf 'pre-existing immutable assessment\n' > "$dir/assessment.json"
  before="$(sha256sum "$dir/assessment.json" | awk '{print $1}')"
  run_real_publish_assessment_build "$dir" > "$dir/stdout" 2> "$dir/stderr" || status=$?
  after="$(sha256sum "$dir/assessment.json" | awk '{print $1}')"
  if [[ "$status" -ne 0 && "$before" == "$after" ]] \
      && grep -q 'assessment destination already exists' "$dir/stderr"; then
    pass "$name"
  else
    fail "$name" "expected no-replace refusal: status=$status before=$before after=$after stderr=$(cat "$dir/stderr")"
  fi
}

case_publish_assessment_and_closure_are_concurrent_no_replace() {
  local name="ship publish artifacts: concurrent writers have one immutable winner"
  should_run "$name" || return 0
  local assessment_dir closure_dir pid_a pid_b status_a status_b initial_success reuse_count
  assessment_dir="$tmp_root/publish-assessment-concurrent"
  publish_assessment_fixture "$assessment_dir"
  status_a=0; status_b=0
  run_real_publish_assessment_build "$assessment_dir" > "$assessment_dir/a.out" 2> "$assessment_dir/a.err" & pid_a=$!
  run_real_publish_assessment_build "$assessment_dir" > "$assessment_dir/b.out" 2> "$assessment_dir/b.err" & pid_b=$!
  wait "$pid_a" || status_a=$?
  wait "$pid_b" || status_b=$?
  initial_success=0
  if [[ "$status_a" -eq 0 ]] \
      && ! grep -q 'reusing unchanged assessment destination' "$assessment_dir/a.err"; then
    initial_success=$((initial_success + 1))
  fi
  if [[ "$status_b" -eq 0 ]] \
      && ! grep -q 'reusing unchanged assessment destination' "$assessment_dir/b.err"; then
    initial_success=$((initial_success + 1))
  fi
  reuse_count="$( {
    grep -h -c 'reusing unchanged assessment destination' "$assessment_dir/a.err" "$assessment_dir/b.err" 2>/dev/null || true
  } | awk '{sum += $1} END {print sum + 0}' )"
  if [[ "$initial_success" -ne 1 || "$reuse_count" -gt 1 || ! -f "$assessment_dir/assessment.json" ]] \
      || ! bash -c '. "$1/runtime/lib/gate-publish.sh"; gate_publish_assessment_verify "$2"' _ "$REPO_ROOT" "$assessment_dir/assessment.json" >/dev/null 2>&1; then
    fail "$name/assessment" "concurrent assessment publication was not one-winner/no-replace: statuses=$status_a,$status_b initial=$initial_success reuse=$reuse_count a_err=$(cat "$assessment_dir/a.err") b_err=$(cat "$assessment_dir/b.err")"
    return 1
  fi
  pass "$name/assessment"

  closure_dir="$tmp_root/closure-concurrent"
  mkdir -p "$closure_dir"
  printf 'Final: GO\n' > "$closure_dir/result.md"
  jq -n '{changes:{changed_paths:[],renamed_paths:[],untracked_paths:[]},diff:{binary_or_special_paths:[]}}' > "$closure_dir/scope.json"
  local closure_scope_sha
  closure_scope_sha="$(sha256sum "$closure_dir/scope.json" | awk '{print $1}')"
  jq -n --arg scope_sha "$closure_scope_sha" '{subject:{repository_key:("a"*64),base_commit:("b"*40),head_commit:("c"*40),tree_fingerprint:("d"*64),subject_kind:"committed_head"},evidence:{scope_manifest:{artifact:"scope.json",sha256:$scope_sha}}}' > "$closure_dir/result.md.assurance.json"
  status_a=0; status_b=0
  bash -c '
    repo_root="$1"; dir="$2"
    . "$repo_root/runtime/lib/gate-closure.sh"
    gate_remediation_closure_publish "$dir/result.md" "$dir/result.md.assurance.json" "$dir/closure.json" "" CC-511
  ' _ "$REPO_ROOT" "$closure_dir" > "$closure_dir/a.out" 2> "$closure_dir/a.err" & pid_a=$!
  bash -c '
    repo_root="$1"; dir="$2"
    . "$repo_root/runtime/lib/gate-closure.sh"
    gate_remediation_closure_publish "$dir/result.md" "$dir/result.md.assurance.json" "$dir/closure.json" "" CC-511
  ' _ "$REPO_ROOT" "$closure_dir" > "$closure_dir/b.out" 2> "$closure_dir/b.err" & pid_b=$!
  wait "$pid_a" || status_a=$?
  wait "$pid_b" || status_b=$?
  initial_success=0
  if [[ "$status_a" -eq 0 ]] \
      && ! grep -q 'reusing unchanged closure destination' "$closure_dir/a.err"; then
    initial_success=$((initial_success + 1))
  fi
  if [[ "$status_b" -eq 0 ]] \
      && ! grep -q 'reusing unchanged closure destination' "$closure_dir/b.err"; then
    initial_success=$((initial_success + 1))
  fi
  reuse_count="$( {
    grep -h -c 'reusing unchanged closure destination' "$closure_dir/a.err" "$closure_dir/b.err" 2>/dev/null || true
  } | awk '{sum += $1} END {print sum + 0}' )"
  if [[ "$initial_success" -ne 1 || "$reuse_count" -gt 1 || ! -f "$closure_dir/closure.json" ]] \
      || ! bash -c '. "$1/runtime/lib/gate-closure.sh"; gate_remediation_closure_verify "$2" "dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd" "$(sha256sum "$3" | awk '\''{print $1}'\'')"' _ "$REPO_ROOT" "$closure_dir/closure.json" "$closure_dir/scope.json" >/dev/null 2>&1; then
    fail "$name/closure" "concurrent closure publication was not one-winner/no-replace: statuses=$status_a,$status_b initial=$initial_success reuse=$reuse_count a_err=$(cat "$closure_dir/a.err") b_err=$(cat "$closure_dir/b.err")"
    return 1
  fi
  pass "$name/closure"
}

case_publish_assessment_verify_rejects_malformed_artifacts() {
  local name="ship publish assessment: verifier rejects malformed required fields, unknown fields, and artifact paths"
  should_run "$name" || return 0
  local dir assessment mutation status=0 variant
  dir="$tmp_root/publish-assessment-verify-negative"
  publish_assessment_fixture "$dir"
  run_real_publish_assessment_build "$dir" >/dev/null 2>"$dir/build.err" || {
    fail "$name" "failed to build canonical assessment: $(cat "$dir/build.err")"
    return 0
  }
  assessment="$dir/assessment.json"
  if ! run_real_publish_assessment_verify "$assessment"; then
    fail "$name" "canonical assessment was rejected"
    return 0
  fi
  for variant in missing-required unknown-field malformed-path; do
    mutation="$dir/assessment-$variant.json"
    case "$variant" in
      missing-required)
        jq 'del(.closure)' "$assessment" > "$mutation"
        ;;
      unknown-field)
        jq '.unexpected_test_field = true' "$assessment" > "$mutation"
        ;;
      malformed-path)
        jq '.full_suite.artifact = "/tmp/pm-dispatch-missing-full-suite.json"' "$assessment" > "$mutation"
        ;;
    esac
    if run_real_publish_assessment_verify "$mutation"; then
      fail "$name" "malformed variant was accepted: $variant"
      status=1
    fi
  done
  [[ "$status" -eq 0 ]] && pass "$name"
}

case_targeted_closure_requires_initial_finding_ledger() {
  local name="ship closure: targeted GO must cover every initial blocker"
  should_run "$name" || return 0
  local dir initial target assurance scope full closure scope_sha status=0
  dir="$tmp_root/targeted-closure-ledger"
  mkdir -p "$dir"
  initial="$dir/initial.md"; target="$dir/target.md"; assurance="$dir/target.md.assurance.json"
  scope="$dir/scope.json"; full="$dir/full.json"; closure="$dir/closure.json"
  jq -n '{changes:{changed_paths:["runtime/lib/gate-closure.sh"],renamed_paths:[],untracked_paths:[]},diff:{binary_or_special_paths:[]}}' > "$scope"
  scope_sha="$(sha256sum "$scope" | awk '{print $1}')"
  {
    printf 'Final: NO-GO\n```synthesis_result_v1\n'
    jq -n '{kind:"gate_synthesis_result_v1",findings_union:[
      {id:"risk-reviewer-F001",origin:"diff_caused",hard_gate_class:"hard_block",source:{path:"runtime/lib/gate-closure.sh",line:145,symbol:"gate_remediation_closure_publish"}},
      {id:"qa-tester-F001",origin:"diff_caused",hard_gate_class:"hard_block",source:{path:"tests/shell/test-pmctl-ship.sh",line:1,symbol:"concurrency"}}],selected_reviewers:["risk-reviewer","qa-tester"]}'
    printf '```\n'
  } > "$initial"
  jq -n --arg scope_sha "$scope_sha" '{subject:{repository_key:("a"*64),base_commit:("b"*40),head_commit:("c"*40),tree_fingerprint:("d"*64),subject_kind:"committed_head"},evidence:{scope_manifest:{artifact:"scope.json",sha256:$scope_sha}}}' > "$initial.assurance.json"
  {
    printf 'Final: GO\n```synthesis_result_v1\n'
    jq -n '{kind:"gate_synthesis_result_v1",findings_union:[{id:"risk-reviewer-F001",origin:"diff_caused",hard_gate_class:"hard_block",source:{path:"runtime/lib/gate-closure.sh",line:145,symbol:"gate_remediation_closure_publish"}}],remediation_confirmations:[{finding_id:"risk-reviewer-F001",status:"confirmed",summary:"The targeted review confirmed the first fix.",evidence_refs:[{path:"runtime/lib/gate-closure.sh",line:145,symbol:"gate_remediation_closure_publish"}]}],selected_reviewers:["risk-reviewer"]}'
    printf '```\n'
  } > "$target"
  jq -n --arg scope_sha "$scope_sha" --arg initial "$initial" '{coordinates:{pass:{resolved:"targeted",initial_result:$initial}},subject:{repository_key:("a"*64),base_commit:("b"*40),head_commit:("c"*40),tree_fingerprint:("d"*64),subject_kind:"committed_head"},evidence:{scope_manifest:{artifact:"scope.json",sha256:$scope_sha}}}' > "$assurance"
  jq -n '{kind:"pm_test_result_v2",contract:"full",authoritative:true,status:"pass",aggregate:{status:"pass"},exit_code:0,tree_fingerprint:("d"*64)}' > "$full"
  bash -c '
    repo_root="$1"; target="$2"; assurance="$3"; closure="$4"; full="$5"
    . "$repo_root/runtime/lib/gate-closure.sh"
    gate_remediation_closure_publish "$target" "$assurance" "$closure" "$full" CC-511
  ' _ "$REPO_ROOT" "$target" "$assurance" "$closure" "$full" > "$dir/out" 2> "$dir/err" || status=$?
  if [[ "$status" -ne 0 && ! -e "$closure" ]] \
      && grep -q 'does not explicitly confirm initial blocking findings' "$dir/err"; then
    pass "$name"
  else
    fail "$name" "partial targeted closure was accepted: status=$status closure=$(cat "$closure" 2>/dev/null) stderr=$(cat "$dir/err")"
  fi
}

case_targeted_closure_rejects_initial_subject_mismatch() {
  local name="ship closure: targeted GO rejects initial subject provenance mismatch"
  should_run "$name" || return 0
  local dir initial target assurance scope full closure scope_sha status=0
  dir="$tmp_root/targeted-closure-subject-mismatch"
  mkdir -p "$dir"
  initial="$dir/initial.md"; target="$dir/target.md"; assurance="$dir/target.md.assurance.json"
  scope="$dir/scope.json"; full="$dir/full.json"; closure="$dir/closure.json"
  jq -n '{changes:{changed_paths:["runtime/lib/gate-closure.sh"],renamed_paths:[],untracked_paths:[]},diff:{binary_or_special_paths:[]}}' > "$scope"
  scope_sha="$(sha256sum "$scope" | awk '{print $1}')"
  {
    printf 'Final: NO-GO\n```synthesis_result_v1\n'
    jq -n '{kind:"gate_synthesis_result_v1",findings_union:[{id:"critic-F001",origin:"diff_caused",hard_gate_class:"soft_block",source:{path:"runtime/lib/gate-closure.sh",line:131,symbol:"gate_remediation_closure_publish"}}],selected_reviewers:["critic"]}'
    printf '```\n'
  } > "$initial"
  jq -n --arg scope_sha "$scope_sha" '{subject:{repository_key:("f"*64),base_commit:("b"*40),head_commit:("c"*40),tree_fingerprint:("d"*64),subject_kind:"committed_head"},evidence:{scope_manifest:{artifact:"scope.json",sha256:$scope_sha}}}' > "$initial.assurance.json"
  {
    printf 'Final: GO\n```synthesis_result_v1\n'
    jq -n '{kind:"gate_synthesis_result_v1",findings_union:[],remediation_confirmations:[{finding_id:"critic-F001",status:"confirmed",summary:"The targeted review confirmed the fix.",evidence_refs:[{path:"runtime/lib/gate-closure.sh",line:131,symbol:"gate_remediation_closure_publish"}]}],selected_reviewers:["critic"]}'
    printf '```\n'
  } > "$target"
  jq -n --arg scope_sha "$scope_sha" --arg initial "$initial" '{coordinates:{pass:{resolved:"targeted",initial_result:$initial}},subject:{repository_key:("a"*64),base_commit:("b"*40),head_commit:("c"*40),tree_fingerprint:("d"*64),subject_kind:"committed_head"},evidence:{scope_manifest:{artifact:"scope.json",sha256:$scope_sha}}}' > "$assurance"
  jq -n '{kind:"pm_test_result_v2",contract:"full",authoritative:true,status:"pass",aggregate:{status:"pass"},exit_code:0,tree_fingerprint:("d"*64)}' > "$full"
  bash -c '
    repo_root="$1"; target="$2"; assurance="$3"; closure="$4"; full="$5"
    . "$repo_root/runtime/lib/gate-closure.sh"
    gate_remediation_closure_publish "$target" "$assurance" "$closure" "$full" CC-511
  ' _ "$REPO_ROOT" "$target" "$assurance" "$closure" "$full" > "$dir/out" 2> "$dir/err" || status=$?
  if [[ "$status" -ne 0 && ! -e "$closure" ]] \
      && grep -q 'initial assurance provenance does not match targeted subject or scope' "$dir/err"; then
    pass "$name"
  else
    fail "$name" "mismatched targeted closure was accepted: status=$status closure=$(cat "$closure" 2>/dev/null) stderr=$(cat "$dir/err")"
  fi
}

case_targeted_closure_rejects_legacy_initial_without_immutable_evidence() {
  local name="ship closure: legacy targeted initial result is not publish-authorizing"
  should_run "$name" || return 0
  local dir initial target assurance scope full closure scope_sha status=0
  dir="$tmp_root/targeted-closure-legacy-initial"
  mkdir -p "$dir"
  initial="$dir/initial.md"; target="$dir/target.md"; assurance="$dir/target.md.assurance.json"
  scope="$dir/scope.json"; full="$dir/full.json"; closure="$dir/closure.json"
  printf 'Final: NO-GO\nlegacy gate result without synthesis\n' > "$initial"
  jq -n '{changes:{changed_paths:["runtime/lib/gate-closure.sh"],renamed_paths:[],untracked_paths:[]},diff:{binary_or_special_paths:[]}}' > "$scope"
  scope_sha="$(sha256sum "$scope" | awk '{print $1}')"
  {
    printf 'Final: GO\n```synthesis_result_v1\n'
    jq -n '{kind:"gate_synthesis_result_v1",findings_union:[],remediation_confirmations:[],selected_reviewers:["risk-reviewer"]}'
    printf '```\n'
  } > "$target"
  jq -n --arg scope_sha "$scope_sha" --arg initial "$initial" \
    '{coordinates:{pass:{resolved:"targeted",initial_result:$initial}},subject:{repository_key:("a"*64),base_commit:("b"*40),head_commit:("c"*40),tree_fingerprint:("d"*64),subject_kind:"committed_head"},evidence:{scope_manifest:{artifact:"scope.json",sha256:$scope_sha}}}' > "$assurance"
  jq -n '{kind:"pm_test_result_v2",contract:"full",authoritative:true,status:"pass",aggregate:{status:"pass"},exit_code:0,tree_fingerprint:("d"*64)}' > "$full"
  bash -c '
    repo_root="$1"; target="$2"; assurance="$3"; closure="$4"; full="$5"
    . "$repo_root/runtime/lib/gate-closure.sh"
    gate_remediation_closure_publish "$target" "$assurance" "$closure" "$full" CC-511
  ' _ "$REPO_ROOT" "$target" "$assurance" "$closure" "$full" > "$dir/out" 2> "$dir/err" || status=$?
  if [[ "$status" -ne 0 && ! -e "$closure" ]] &&
      grep -q 'initial immutable assurance sidecar' "$dir/err"; then
    pass "$name"
  else
    fail "$name" "legacy targeted closure was accepted: status=$status closure=$(cat "$closure" 2>/dev/null) stderr=$(cat "$dir/err")"
  fi
}

case_targeted_closure_accepts_clean_go_with_confirmations() {
  local name="ship closure: clean targeted GO closes initial blockers through confirmation ledger"
  should_run "$name" || return 0
  local dir initial target assurance scope full closure scope_sha status=0
  dir="$tmp_root/targeted-closure-confirmations"
  mkdir -p "$dir"
  initial="$dir/initial.md"; target="$dir/target.md"; assurance="$dir/target.md.assurance.json"
  scope="$dir/scope.json"; full="$dir/full.json"; closure="$dir/closure.json"
  jq -n '{changes:{changed_paths:["runtime/lib/gate-closure.sh","tests/shell/test-pmctl-ship.sh"],renamed_paths:[],untracked_paths:[]},diff:{binary_or_special_paths:[]}}' > "$scope"
  scope_sha="$(sha256sum "$scope" | awk '{print $1}')"
  {
    printf 'Final: NO-GO\n```synthesis_result_v1\n'
    jq -n '{kind:"gate_synthesis_result_v1",findings_union:[
      {id:"risk-reviewer-F001",origin:"diff_caused",hard_gate_class:"hard_block",source:{path:"runtime/lib/gate-closure.sh",line:145,symbol:"gate_remediation_closure_publish"}},
      {id:"qa-tester-F001",origin:"diff_caused",hard_gate_class:"soft_block",source:{path:"tests/shell/test-pmctl-ship.sh",line:1,symbol:"case_targeted_closure_accepts_clean_go_with_confirmations"}}],selected_reviewers:["risk-reviewer","qa-tester"]}'
    printf '```\n'
  } > "$initial"
  jq -n --arg scope_sha "$scope_sha" '{subject:{repository_key:("a"*64),base_commit:("b"*40),head_commit:("c"*40),tree_fingerprint:("d"*64),subject_kind:"committed_head"},evidence:{scope_manifest:{artifact:"scope.json",sha256:$scope_sha}}}' > "$initial.assurance.json"
  {
    printf 'Final: GO\n```synthesis_result_v1\n'
    jq -n '{kind:"gate_synthesis_result_v1",findings_union:[],remediation_confirmations:[
      {finding_id:"risk-reviewer-F001",status:"confirmed",summary:"Risk fix confirmed by targeted review.",evidence_refs:[{path:"runtime/lib/gate-closure.sh",line:145,symbol:"gate_remediation_closure_publish"}]},
      {finding_id:"qa-tester-F001",status:"confirmed",summary:"QA fix confirmed by targeted review.",evidence_refs:[{path:"tests/shell/test-pmctl-ship.sh",line:1,symbol:"case_targeted_closure_accepts_clean_go_with_confirmations"}]}],selected_reviewers:["risk-reviewer","qa-tester"]}'
    printf '```\n'
  } > "$target"
  jq -n --arg scope_sha "$scope_sha" --arg initial "$initial" '{coordinates:{pass:{resolved:"targeted",initial_result:$initial}},subject:{repository_key:("a"*64),base_commit:("b"*40),head_commit:("c"*40),tree_fingerprint:("d"*64),subject_kind:"committed_head"},evidence:{scope_manifest:{artifact:"scope.json",sha256:$scope_sha}}}' > "$assurance"
  jq -n '{kind:"pm_test_result_v2",contract:"full",authoritative:true,status:"pass",aggregate:{status:"pass"},exit_code:0,tree_fingerprint:("d"*64)}' > "$full"
  bash -c '
    repo_root="$1"; target="$2"; assurance="$3"; closure="$4"; full="$5"
    . "$repo_root/runtime/lib/gate-closure.sh"
    gate_remediation_closure_publish "$target" "$assurance" "$closure" "$full" CC-511
  ' _ "$REPO_ROOT" "$target" "$assurance" "$closure" "$full" > "$dir/out" 2> "$dir/err" || status=$?
  if [[ "$status" -eq 0 && -s "$closure" ]] \
      && jq -e '.state == "closed" and .final_assessment.publish_authorized == true and (.targeted_confirmation.finding_ids | sort) == ["qa-tester-F001","risk-reviewer-F001"]' "$closure" >/dev/null 2>&1; then
    pass "$name"
  else
    fail "$name" "clean targeted GO was not authorized: status=$status stderr=$(cat "$dir/err") closure=$(cat "$closure" 2>/dev/null)"
  fi
}

case_targeted_closure_accepts_uncertain_go_with_confirmation() {
  local name="ship closure: uncertain initial blocker closes only with matching targeted confirmation"
  should_run "$name" || return 0
  local dir initial target assurance scope full closure scope_sha status=0
  dir="$tmp_root/targeted-closure-uncertain-confirmation"
  mkdir -p "$dir"
  initial="$dir/initial.md"; target="$dir/target.md"; assurance="$dir/target.md.assurance.json"
  scope="$dir/scope.json"; full="$dir/full.json"; closure="$dir/closure.json"
  jq -n '{changes:{changed_paths:["runtime/lib/gate-closure.sh"],renamed_paths:[],untracked_paths:[]},diff:{binary_or_special_paths:[]}}' > "$scope"
  scope_sha="$(sha256sum "$scope" | awk '{print $1}')"
  {
    printf 'Final: NO-GO\n```synthesis_result_v1\n'
    jq -n '{kind:"gate_synthesis_result_v1",findings_union:[
      {id:"risk-reviewer-F001",origin:"uncertain",hard_gate_class:"hard_block",source:{path:"runtime/lib/gate-closure.sh",line:269,symbol:"gate_remediation_closure_publish"}}],selected_reviewers:["risk-reviewer"]}'
    printf '```\n'
  } > "$initial"
  jq -n --arg scope_sha "$scope_sha" '{subject:{repository_key:("a"*64),base_commit:("b"*40),head_commit:("c"*40),tree_fingerprint:("d"*64),subject_kind:"committed_head"},evidence:{scope_manifest:{artifact:"scope.json",sha256:$scope_sha}}}' > "$initial.assurance.json"
  {
    printf 'Final: GO\n```synthesis_result_v1\n'
    jq -n '{kind:"gate_synthesis_result_v1",findings_union:[],remediation_confirmations:[
      {finding_id:"risk-reviewer-F001",status:"confirmed",summary:"Uncertain blocker independently confirmed fixed.",evidence_refs:[{path:"runtime/lib/gate-closure.sh",line:269,symbol:"gate_remediation_closure_publish"}]}],selected_reviewers:["risk-reviewer"]}'
    printf '```\n'
  } > "$target"
  jq -n --arg scope_sha "$scope_sha" --arg initial "$initial" '{coordinates:{pass:{resolved:"targeted",initial_result:$initial}},subject:{repository_key:("a"*64),base_commit:("b"*40),head_commit:("c"*40),tree_fingerprint:("d"*64),subject_kind:"committed_head"},evidence:{scope_manifest:{artifact:"scope.json",sha256:$scope_sha}}}' > "$assurance"
  jq -n '{kind:"pm_test_result_v2",contract:"full",authoritative:true,status:"pass",aggregate:{status:"pass"},exit_code:0,tree_fingerprint:("d"*64)}' > "$full"
  bash -c '
    repo_root="$1"; target="$2"; assurance="$3"; closure="$4"; full="$5"
    . "$repo_root/runtime/lib/gate-closure.sh"
    gate_remediation_closure_publish "$target" "$assurance" "$closure" "$full" CC-511
  ' _ "$REPO_ROOT" "$target" "$assurance" "$closure" "$full" > "$dir/out" 2> "$dir/err" || status=$?
  if [[ "$status" -eq 0 && -s "$closure" ]] \
      && jq -e '.state == "closed" and .final_assessment.publish_authorized == true and .findings[0].disposition == "closed" and .findings[0].classification == "targeted_confirmation" and .targeted_confirmation.finding_ids == ["risk-reviewer-F001"]' "$closure" >/dev/null 2>&1; then
    pass "$name"
  else
    fail "$name" "matching uncertain confirmation was not authorized: status=$status stderr=$(cat "$dir/err") closure=$(cat "$closure" 2>/dev/null)"
  fi
}

case_publish_assessment_rejects_invalid_or_mismatched_evidence() {
  local name="ship publish assessment: invalid or mismatched evidence is rejected"
  should_run "$name" || return 0
  local mode dir status=0 failures=0
  for mode in closure-subject full-subject closure-authorization full-status; do
    dir="$tmp_root/publish-assessment-reject-$mode"
    publish_assessment_fixture "$dir"
    case "$mode" in
      closure-subject)
        jq '.final_assessment.subject_fingerprint = ("e"*64)' "$dir/closure.json" > "$dir/changed"
        mv -- "$dir/changed" "$dir/closure.json"
        ;;
      full-subject)
        jq '.tree_fingerprint = ("e"*64)' "$dir/full.json" > "$dir/changed"
        mv -- "$dir/changed" "$dir/full.json"
        ;;
      closure-authorization)
        jq '.final_assessment.publish_authorized = false' "$dir/closure.json" > "$dir/changed"
        mv -- "$dir/changed" "$dir/closure.json"
        ;;
      full-status)
        jq '.status = "fail" | .aggregate.status = "fail" | .exit_code = 1' "$dir/full.json" > "$dir/changed"
        mv -- "$dir/changed" "$dir/full.json"
        ;;
    esac
    status=0
    run_real_publish_assessment_build "$dir" > "$dir/stdout" 2> "$dir/stderr" || status=$?
    if [[ "$status" -eq 0 || -e "$dir/assessment.json" ]]; then
      fail "$name/$mode" "expected rejection; status=$status assessment=$(cat "$dir/assessment.json" 2>/dev/null) stderr=$(cat "$dir/stderr")"
      failures=$((failures + 1))
    else
      pass "$name/$mode"
    fi
  done
  [[ "$failures" -eq 0 ]]
}

case_publish_assessment_rejects_post_build_source_mutation() {
  local name="ship publish assessment: post-build source mutation is rejected before publication"
  should_run "$name" || return 0
  local source dir status=0 failures=0
  for source in gate assurance closure full_suite; do
    dir="$tmp_root/publish-assessment-mutation-$source"
    publish_assessment_fixture "$dir"
    status=0
    run_real_publish_assessment_build "$dir" > "$dir/build-stdout" 2> "$dir/build-stderr" || status=$?
    if [[ "$status" -ne 0 ]]; then
      fail "$name/$source" "fixture build failed: status=$status stderr=$(cat "$dir/build-stderr")"
      failures=$((failures + 1))
      continue
    fi
    case "$source" in
      gate) printf 'mutated after build\n' >> "$dir/gate-result.md" ;;
      assurance) printf '\n' >> "$dir/assurance.json" ;;
      closure) printf '\n' >> "$dir/closure.json" ;;
      full_suite) printf '\n' >> "$dir/full.json" ;;
    esac
    status=0
    bash -c '
      repo_root="$1"; assessment="$2"
      . "$repo_root/runtime/lib/gate-publish.sh"
      gate_publish_assessment_verify "$assessment"
    ' _ "$REPO_ROOT" "$dir/assessment.json" > "$dir/verify-stdout" 2> "$dir/verify-stderr" || status=$?
    if [[ "$status" -eq 0 ]]; then
      fail "$name/$source" "expected post-build digest rejection; stdout=$(cat "$dir/verify-stdout") stderr=$(cat "$dir/verify-stderr")"
      failures=$((failures + 1))
    else
      pass "$name/$source"
    fi
  done
  [[ "$failures" -eq 0 ]]
}

case_finish_real_publish_assessment_surfaces() {
  local name="ship finish: real publish assessment drives stdout, PR body, and marker"
  should_run "$name" || return 0
  local mode work gh_bin body out err status pushed expected_producer expected_satisfaction expected_preferred
  local marker_assessment producer satisfaction preferred assessment_json marker_producer marker_satisfaction
  local stdout_match body_match failures=0
  for mode in maintainer generic; do
    work="$tmp_root/work-real-publish-surfaces-$mode"
    make_work_repo "$work" "CC-9001"
    checkout_ticket_branch "$work" "CC-9001"
    add_bare_origin "$work"
    gh_bin="$tmp_root/fake-gh-real-publish-$mode"
    body="$tmp_root/real-publish-pr-body-$mode"
    install_fake_gh_capture_body "$gh_bin" "https://example.invalid/pr/real-publish-$mode"
    out="$tmp_root/out-real-publish-$mode"; err="$tmp_root/err-real-publish-$mode"
    status=0; pushed=0; stdout_match=0; body_match=0
    export GH_PR_URL="https://example.invalid/pr/real-publish-$mode" GH_PR_BODY_FILE="$body"
    PATH="$gh_bin:$PATH" run_finish_with_real_publish_assessment \
      "$work" "CC-9001" "$mode" "$body" > "$out" 2> "$err" || status=$?
    unset GH_PR_URL GH_PR_BODY_FILE
    git -C "$work.bare-origin.git" show-ref --quiet feat/CC-9001 2>/dev/null && pushed=1
    marker_assessment="$(jq -r '.publish_assessment // empty' "$work/.pm-dispatch-ship-finish.json" 2>/dev/null || true)"
    assessment_json="$(cat "$marker_assessment" 2>/dev/null || true)"
    producer="$(jq -r '.policy.embedded_policy // empty' <<<"$assessment_json")"
    satisfaction="$(jq -r '.policy.policy_satisfaction // empty' <<<"$assessment_json")"
    preferred="$(jq -r '.policy.preferred_policy // empty' <<<"$assessment_json")"
    marker_producer="$(jq -r '.publish_assurance.embedded_policy // empty' "$work/.pm-dispatch-ship-finish.json" 2>/dev/null || true)"
    marker_satisfaction="$(jq -r '.publish_assurance.policy_satisfaction // empty' "$work/.pm-dispatch-ship-finish.json" 2>/dev/null || true)"
    if [[ "$mode" == generic ]]; then
      expected_producer=generic expected_satisfaction=baseline expected_preferred=generic
    else
      expected_producer=maintainer expected_satisfaction=preferred expected_preferred=maintainer
    fi
    grep -Fq "publish assurance: producer=$producer satisfaction=$satisfaction preferred=$preferred" "$out" && stdout_match=1
    grep -Fq "Publish assurance: producer=$producer, satisfaction=$satisfaction (preferred=$preferred)" "$body" && body_match=1
    if [[ "$status" -eq 0 && "$pushed" -eq 1 \
        && "$producer" == "$expected_producer" && "$satisfaction" == "$expected_satisfaction" && "$preferred" == "$expected_preferred" \
        && -s "$body" && "$stdout_match" -eq 1 && "$body_match" -eq 1 \
        && "$marker_producer" == "$producer" && "$marker_satisfaction" == "$satisfaction" ]]; then
      pass "$name/$mode"
    else
      fail "$name/$mode" "real assessment surfaces disagreed: status=$status pushed=$pushed producer=$producer satisfaction=$satisfaction preferred=$preferred stdout=$(cat "$out") stderr=$(cat "$err") body=$(cat "$body" 2>/dev/null)"
      failures=$((failures + 1))
    fi
  done
  [[ "$failures" -eq 0 ]]
}

case_finish_real_targeted_publish_assessment_path() {
  local name="ship finish: targeted fallback uses real publish assessment and rejects invalid closure"
  should_run "$name" || return 0
  local gh_bin work_valid work_invalid body out err status=0 pushed=0
  gh_bin="$tmp_root/fake-gh-targeted-real"
  install_fake_gh_capture_body "$gh_bin" "https://example.invalid/pr/targeted-real"

  work_valid="$tmp_root/work-targeted-real-valid"
  make_work_repo "$work_valid" "CC-9001"
  checkout_ticket_branch "$work_valid" "CC-9001"
  add_bare_origin "$work_valid"
  body="$tmp_root/targeted-real-body"
  out="$tmp_root/out-targeted-real-valid"; err="$tmp_root/err-targeted-real-valid"
  export GH_PR_URL="https://example.invalid/pr/targeted-real" GH_PR_BODY_FILE="$body"
  PATH="$gh_bin:$PATH" run_finish_with_real_publish_assessment \
    "$work_valid" "CC-9001" targeted "$body" > "$out" 2> "$err" || status=$?
  unset GH_PR_URL GH_PR_BODY_FILE
  git -C "$work_valid.bare-origin.git" show-ref --quiet feat/CC-9001 2>/dev/null && pushed=1
  local route_valid
  route_valid="$(jq -r '.authorization.route // empty' "$(jq -r '.publish_assessment' "$work_valid/.pm-dispatch-ship-finish.json" 2>/dev/null)" 2>/dev/null)"
  if [[ "$status" -ne 0 || "$pushed" -ne 1 || "$route_valid" != primary_review_closure ]]; then
    fail "$name/valid" "expected targeted closure publication: status=$status pushed=$pushed route=$route_valid stdout=$(cat "$out") stderr=$(cat "$err")"
    return 1
  fi
  pass "$name/valid"

  work_invalid="$tmp_root/work-targeted-real-invalid"
  make_work_repo "$work_invalid" "CC-9001"
  checkout_ticket_branch "$work_invalid" "CC-9001"
  add_bare_origin "$work_invalid"
  out="$tmp_root/out-targeted-real-invalid"; err="$tmp_root/err-targeted-real-invalid"
  status=0
  PATH="$gh_bin:$PATH" run_finish_with_real_publish_assessment \
    "$work_invalid" "CC-9001" targeted-invalid "$body" > "$out" 2> "$err" || status=$?
  pushed=0
  git -C "$work_invalid.bare-origin.git" show-ref --quiet feat/CC-9001 2>/dev/null && pushed=1
  if [[ "$status" -eq 1 && "$pushed" -eq 0 \
      && ! -e "$work_invalid/.pm-dispatch-ship-finish.json" ]]; then
    pass "$name/invalid-closure"
  else
    fail "$name/invalid-closure" "expected refusal before push: status=$status pushed=$pushed stdout=$(cat "$out") stderr=$(cat "$err")"
  fi
}

case_finish_real_closure_verify_accepts_producer_output() {
  local name="ship finish: real closure producer output survives the real closure verifier"
  should_run "$name" || return 0
  local work gh_bin body out err status=0 pushed=0
  work="$tmp_root/work-real-closure-verify"
  make_work_repo "$work" "CC-9001"
  checkout_ticket_branch "$work" "CC-9001"
  add_bare_origin "$work"
  gh_bin="$tmp_root/fake-gh-real-closure-verify"
  install_fake_gh_capture_body "$gh_bin" "https://example.invalid/pr/real-closure-verify"
  body="$tmp_root/real-closure-verify-body"
  out="$tmp_root/out-real-closure-verify"; err="$tmp_root/err-real-closure-verify"
  export GH_PR_URL="https://example.invalid/pr/real-closure-verify" GH_PR_BODY_FILE="$body"
  PATH="$gh_bin:$PATH" run_finish_with_real_publish_assessment \
    "$work" "CC-9001" real-closure "$body" > "$out" 2> "$err" || status=$?
  unset GH_PR_URL GH_PR_BODY_FILE
  git -C "$work.bare-origin.git" show-ref --quiet feat/CC-9001 2>/dev/null && pushed=1
  local closure_path closure_reverify_status=1
  closure_path="$(jq -r '.remediation_closure // empty' "$work/.pm-dispatch-ship-finish.json" 2>/dev/null || true)"
  if [[ -n "$closure_path" && -f "$closure_path" ]]; then
    local subject_fp scope_sha
    subject_fp="$(jq -r '.subject.tree_fingerprint // empty' "$work/.pm-dispatch-ship-finish.json" 2>/dev/null || true)"
    scope_sha="$(jq -r '.scope_manifest_sha256 // empty' "$closure_path")"
    if bash -c '
        . "$1/runtime/lib/gate-closure.sh"
        gate_remediation_closure_verify "$2" "$3" "$4"
      ' _ "$REPO_ROOT" "$closure_path" "$subject_fp" "$scope_sha"; then
      closure_reverify_status=0
    fi
  fi
  if [[ "$status" -eq 0 && "$pushed" -eq 1 && "$closure_reverify_status" -eq 0 ]]; then
    pass "$name"
  else
    fail "$name" "expected real producer/consumer success: status=$status pushed=$pushed reverify=$closure_reverify_status stdout=$(cat "$out") stderr=$(cat "$err")"
  fi
}

case_publish_assessment_rejects_closure_mutated_after_real_publish() {
  local name="ship publish assessment: real verify rejects a closure mutated after real publication"
  should_run "$name" || return 0
  local dir="$tmp_root/real-closure-mutation-reject"
  mkdir -p "$dir"
  local out="$dir/out" err="$dir/err" status=0
  set +e
  bash -c '
      set -euo pipefail
      repo_root="$1"; dir="$2"
      . "$repo_root/runtime/lib/gate-closure.sh"
      . "$repo_root/runtime/lib/gate-publish.sh"
      head="1111111111111111111111111111111111111111"
      subject="$(printf "d%.0s" {1..64})"
      result_file="$dir/gate-result.md"
      assurance_file="$dir/gate-assurance.json"
      scope_file="$dir/scope-manifest.json"
      closure_file="$dir/closure.json"
      mutated_closure="$dir/closure-mutated.json"
      full_result="$dir/full-result.json"
      gate_report="$dir/gate-verification.json"
      printf "Final: GO\n" > "$result_file"
      jq -n '"'"'{changes:{changed_paths:[],renamed_paths:[],untracked_paths:[]},diff:{binary_or_special_paths:[]}}'"'"' > "$scope_file"
      jq -n --arg subject "$subject" --arg head "$head" '"'"'
        {subject:{repository_key:("a"*64),base_commit:("1"*40),head_commit:$head,tree_fingerprint:$subject,subject_kind:"committed_head"},
         evidence:{scope_manifest:{artifact:"scope-manifest.json",sha256:("c"*64)}}}'"'"' > "$assurance_file"
      scope_sha_actual="$(sha256sum "$scope_file" | awk "{print \$1}")"
      jq --arg sha "$scope_sha_actual" ".evidence.scope_manifest.sha256 = \$sha" "$assurance_file" > "$assurance_file.tmp"
      mv "$assurance_file.tmp" "$assurance_file"
      gate_remediation_closure_publish "$result_file" "$assurance_file" "$closure_file"
      jq ".unresolved_counts.total = 5" "$closure_file" > "$mutated_closure"
      jq -n --arg result "$result_file" --arg assurance "$assurance_file" --arg subject "$subject" --arg head "$head" '"'"'
        {kind:"gate_verification_v1",schema_version:1,result_file:$result,verdict:"GO",
         assurance:{status:"verified",kind:"gate_assurance_v3",file:$assurance},consumer:"embedded",
         axes:{artifact_valid:{status:"pass",reason_codes:[]},
           subject_current:{status:"pass",reason_codes:[],current:{repository_key:("a"*64),base_commit:("1"*40),head_commit:$head,tree_fingerprint:$subject,observed_root:"/tmp/repo"}},
           policy_applicable:{status:"pass",reason_codes:[],consumer:"embedded",required_policy:"generic",preferred_policy:"generic",embedded_policy:"generic",policy_satisfaction:"preferred"}}}'"'"' > "$gate_report"
      jq -n --arg subject "$subject" '"'"'{kind:"pm_test_result_v2",contract:"full",authoritative:true,status:"pass",aggregate:{status:"pass"},exit_code:0,tree_fingerprint:$subject}'"'"' > "$full_result"
      gate_policy_applicability_assess() {
        jq -n '"'"'{status:"pass",reason_codes:[],embedded_policy:"generic",required_policy:"generic",preferred_policy:"generic",policy_satisfaction:"preferred"}'"'"'
      }
      gate_publish_assessment_build "$dir/assessment.json" "$gate_report" "$mutated_closure" "$full_result" CC-511
    ' _ "$REPO_ROOT" "$dir" > "$out" 2> "$err"
  status=$?
  set -e
  if [[ "$status" -ne 0 ]] \
      && grep -qF 'remediation closure is not valid for the current Gate subject' "$err"; then
    pass "$name"
  else
    fail "$name" "expected the real verify to reject the mutated closure: status=$status stdout=$(cat "$out") stderr=$(cat "$err")"
  fi
}

case_finish_post_assessment_drift_refuses_publish() {
  local name="ship finish: post-assessment HEAD/tree drift refuses push"
  should_run "$name" || return 0
  local mutation work gh_bin out err status pushed failures=0
  for mutation in head tree; do
    work="$tmp_root/work-finish-post-assessment-$mutation"
    make_work_repo "$work" "CC-9001"
    checkout_ticket_branch "$work" "CC-9001"
    add_bare_origin "$work"
    gh_bin="$tmp_root/fake-gh-post-assessment-$mutation"
    install_fake_gh "$gh_bin" "https://example.invalid/pr/post-assessment-$mutation"
    out="$tmp_root/out-post-assessment-$mutation"; err="$tmp_root/err-post-assessment-$mutation"
    status=0; pushed=0
    PM_TEST_ASSESSMENT_MUTATE="$mutation" PATH="$gh_bin:$PATH" \
      run_finish_with_fake_gate "$work" "CC-9001" GO > "$out" 2> "$err" || status=$?
    unset PM_TEST_ASSESSMENT_MUTATE
    git -C "$work.bare-origin.git" show-ref --quiet feat/CC-9001 2>/dev/null && pushed=1
    if [[ "$status" -eq 1 && "$pushed" -eq 0 ]] \
        && { grep -q 'tree became dirty before push' "$err" || grep -q 'HEAD moved before push' "$err"; }; then
      pass "$name/$mutation"
    else
      fail "$name/$mutation" "expected final subject guard to refuse publication: status=$status pushed=$pushed stdout=$(cat "$out") stderr=$(cat "$err")"
      failures=$((failures + 1))
    fi
  done
  [[ "$failures" -eq 0 ]]
}

case_finish_assessment_replacement_after_verification_refuses_publish() {
  local name="ship finish: assessment replacement after verification refuses push"
  should_run "$name" || return 0
  local work gh_bin out err status=0 pushed=0
  work="$tmp_root/work-finish-assessment-replacement"
  make_work_repo "$work" "CC-9001"
  checkout_ticket_branch "$work" "CC-9001"
  add_bare_origin "$work"
  gh_bin="$tmp_root/fake-gh-assessment-replacement"
  install_fake_gh "$gh_bin" "https://example.invalid/pr/assessment-replacement"
  out="$tmp_root/out-assessment-replacement"; err="$tmp_root/err-assessment-replacement"
  PM_TEST_ASSESSMENT_REPLACE=1 PATH="$gh_bin:$PATH" \
    run_finish_with_fake_gate "$work" "CC-9001" GO > "$out" 2> "$err" || status=$?
  git -C "$work.bare-origin.git" show-ref --quiet feat/CC-9001 2>/dev/null && pushed=1
  if [[ "$status" -eq 1 && "$pushed" -eq 0 ]] &&
      grep -q 'assessment changed after verification' "$err"; then
    pass "$name"
  else
    fail "$name" "expected assessment TOCTOU refusal: status=$status pushed=$pushed stdout=$(cat "$out") stderr=$(cat "$err")"
  fi
}

case_finish_pushes_only_assessed_head_when_branch_advances_at_push() {
  local name="ship finish: branch advance at push cannot publish an unassessed commit"
  should_run "$name" || return 0
  local work gh_bin hook_bin marker out err status=0 real_git assessed_head local_head remote_head
  work="$tmp_root/work-finish-push-race"
  make_work_repo "$work" "CC-9001"
  checkout_ticket_branch "$work" "CC-9001"
  add_bare_origin "$work"
  assessed_head="$(git -C "$work" rev-parse HEAD)"
  gh_bin="$tmp_root/fake-gh-push-race"
  install_fake_gh "$gh_bin" "https://example.invalid/pr/push-race"
  hook_bin="$tmp_root/fake-git-push-race"
  marker="$tmp_root/fake-git-push-race.marker"
  real_git="$(command -v git)"
  mkdir -p "$hook_bin"
  cat > "$hook_bin/git" <<'FAKEOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "-C" && "${3:-}" == "push" \
    && -n "${PM_TEST_PUSH_RACE_WORK:-}" \
    && ! -e "${PM_TEST_PUSH_RACE_MARKER:-}" ]]; then
  printf 'unassessed branch advance\n' > "$PM_TEST_PUSH_RACE_WORK/push-race.txt"
  "$PM_TEST_REAL_GIT" -C "$PM_TEST_PUSH_RACE_WORK" add push-race.txt
  "$PM_TEST_REAL_GIT" -C "$PM_TEST_PUSH_RACE_WORK" \
    -c user.email=test@example.com -c user.name=test commit -q -m push-race
  : > "$PM_TEST_PUSH_RACE_MARKER"
fi
exec "$PM_TEST_REAL_GIT" "$@"
FAKEOF
  chmod +x "$hook_bin/git"
  out="$tmp_root/out-finish-push-race"
  err="$tmp_root/err-finish-push-race"
  PM_TEST_PUSH_RACE_WORK="$work" PM_TEST_PUSH_RACE_MARKER="$marker" \
    PM_TEST_REAL_GIT="$real_git" PATH="$hook_bin:$gh_bin:$PATH" \
    run_finish_with_fake_gate "$work" "CC-9001" GO > "$out" 2> "$err" || status=$?
  local_head="$(git -C "$work" rev-parse HEAD)"
  remote_head="$(git --git-dir="$work.bare-origin.git" rev-parse refs/heads/feat/CC-9001 2>/dev/null || true)"
  if [[ "$status" -eq 0 && "$local_head" != "$assessed_head" \
      && "$remote_head" == "$assessed_head" ]]; then
    pass "$name"
  else
    fail "$name" "expected assessed head only: status=$status assessed=$assessed_head local=$local_head remote=$remote_head stdout=$(cat "$out") stderr=$(cat "$err")"
  fi
}

case_finish_requires_ticket() {
  local name="ship finish: missing ticket-id exits 2"
  should_run "$name" || return 0
  local store work out err status=0
  store="$tmp_root/state-finish-noarg"
  work="$tmp_root/work-finish-noarg"
  make_work_repo "$work" "CC-9001"
  out="$tmp_root/out-finish-noarg"; err="$tmp_root/err-finish-noarg"
  PM_DISPATCH_STATE_ROOT="$store" "$PMCTL" ship finish --cd "$work" > "$out" 2> "$err" || status=$?
  assert_exit "$name" "$status" 2 && \
    assert_file_contains "$name" "$err" "<ticket-id> is required" && \
    pass "$name"
}

case_finish_no_go_does_not_push() {
  local name="ship finish: NO-GO exits 1, prints the result path, and never pushes"
  should_run "$name" || return 0
  local work out err status=0
  work="$tmp_root/work-finish-nogo"
  make_work_repo "$work" "CC-9001"
  checkout_ticket_branch "$work" "CC-9001"
  add_bare_origin "$work"
  out="$tmp_root/out-finish-nogo"; err="$tmp_root/err-finish-nogo"
  run_finish_with_fake_gate "$work" "CC-9001" "NO-GO" > "$out" 2> "$err" || status=$?
  local pushed=0
  git -C "$work.bare-origin.git" show-ref --quiet feat/CC-9001 2>/dev/null && pushed=1
  if [[ "$status" -eq 1 ]] && grep -q "NO-GO" "$err" && [[ "$pushed" -eq 0 ]]; then
    pass "$name"
  else
    fail "$name" "expected exit 1 + no push; got status=$status pushed=$pushed stderr=$(cat "$err")"
  fi
}

case_finish_missing_result_file() {
  local name="ship finish: a gate that never prints a result: line exits 1 with a clear message"
  should_run "$name" || return 0
  local work out err status=0
  work="$tmp_root/work-finish-noresult"
  make_work_repo "$work" "CC-9001"
  checkout_ticket_branch "$work" "CC-9001"
  out="$tmp_root/out-finish-noresult"; err="$tmp_root/err-finish-noresult"
  run_finish_with_no_result_line "$work" "CC-9001" > "$out" 2> "$err" || status=$?
  assert_exit "$name" "$status" 1 && \
    assert_file_contains "$name" "$err" "could not locate gate result file" && \
    pass "$name"
}

case_finish_missing_shared_verifier_refuses_publish() {
  local name="ship finish: missing shared gate verifier fails closed"
  should_run "$name" || return 0
  local work out err status=0
  work="$tmp_root/work-finish-missing-verifier"
  make_work_repo "$work" "CC-9001"
  checkout_ticket_branch "$work" "CC-9001"
  out="$tmp_root/out-finish-missing-verifier"
  err="$tmp_root/err-finish-missing-verifier"
  run_finish_with_broken_shared_verifier "$work" "CC-9001" missing \
    > "$out" 2> "$err" || status=$?
  if [[ "$status" -eq 2 ]] \
      && grep -q "shared gate verifier is unavailable" "$err"; then
    pass "$name"
  else
    fail "$name" "expected exit 2 fail-closed; status=$status stderr=$(cat "$err")"
  fi
}

case_finish_malformed_shared_assessment_refuses_publish() {
  local name="ship finish: malformed shared gate assessment fails closed"
  should_run "$name" || return 0
  local work out err status=0
  work="$tmp_root/work-finish-malformed-verifier"
  make_work_repo "$work" "CC-9001"
  checkout_ticket_branch "$work" "CC-9001"
  out="$tmp_root/out-finish-malformed-verifier"
  err="$tmp_root/err-finish-malformed-verifier"
  run_finish_with_broken_shared_verifier "$work" "CC-9001" malformed \
    > "$out" 2> "$err" || status=$?
  if [[ "$status" -eq 1 ]] \
      && grep -q "returned no structured assessment" "$err"; then
    pass "$name"
  else
    fail "$name" "expected exit 1 fail-closed; status=$status stderr=$(cat "$err")"
  fi
}

case_finish_go_stale_subject_does_not_push() {
  local name="ship finish: GO with stale subject exits 1 before push"
  should_run "$name" || return 0
  local work out err status=0
  work="$tmp_root/work-finish-stale-subject"
  make_work_repo "$work" "CC-9001"
  checkout_ticket_branch "$work" "CC-9001"
  add_bare_origin "$work"
  out="$tmp_root/out-finish-stale-subject"
  err="$tmp_root/err-finish-stale-subject"
  PM_TEST_GATE_SUBJECT_STATUS=fail \
    run_finish_with_fake_gate "$work" "CC-9001" "GO" \
      > "$out" 2> "$err" || status=$?
  local pushed=0
  git -C "$work.bare-origin.git" show-ref --quiet feat/CC-9001 \
    2>/dev/null && pushed=1
  if [[ "$status" -eq 1 ]] \
      && grep -q "invalid, stale, or below the publish policy baseline" "$err" \
      && [[ "$pushed" -eq 0 ]]; then
    pass "$name"
  else
    fail "$name" "expected exit 1 + no push; got status=$status pushed=$pushed stderr=$(cat "$err")"
  fi
}

case_finish_valid_supplied_gate_result_publishes_without_new_gate() {
  local name="ship finish: valid absolute supplied Gate result is verified for publish without a new Gate"
  should_run "$name" || return 0
  local work out err marker verify_argv status=0
  work="$tmp_root/work-finish-gate-supplied"
  marker="$tmp_root/finish-gate-supplied-run"
  verify_argv="$tmp_root/finish-gate-supplied-verify-argv"
  make_work_repo "$work" "CC-9001"
  checkout_ticket_branch "$work" "CC-9001"
  add_bare_origin "$work"
  mkdir -p "$work/evidence"
  printf 'Final: GO\n' > "$work/evidence/gate.md"
  git -C "$work" add evidence/gate.md
  git -C "$work" commit -q -m supplied-gate-result
  local gh_bin="$tmp_root/fake-gh-gate-supplied-bin"
  install_fake_gh "$gh_bin" "https://example.invalid/pr/gate-supplied"
  out="$tmp_root/out-finish-gate-supplied"
  err="$tmp_root/err-finish-gate-supplied"
  PM_TEST_GATE_RUN_MARKER="$marker" \
    PM_TEST_GATE_VERIFY_ARGV="$verify_argv" \
    PATH="$gh_bin:$PATH" \
    run_finish_with_fake_gate "$work" "CC-9001" "GO" \
      --gate-result "$work/evidence/gate.md" > "$out" 2> "$err" || status=$?
  local pushed=0
  git -C "$work.bare-origin.git" show-ref --quiet feat/CC-9001 \
    2>/dev/null && pushed=1
  if [[ "$status" -eq 0 && "$pushed" -eq 1 && ! -e "$marker" ]] \
      && grep -Fxq "$work/evidence/gate.md" "$verify_argv" \
      && grep -Fxq -- '--consumer' "$verify_argv" \
      && grep -Fxq 'publish' "$verify_argv"; then
    pass "$name"
  else
    fail "$name" "status=$status pushed=$pushed gate_called=$([[ -e "$marker" ]] && echo yes || echo no) verify=$(cat "$verify_argv" 2>/dev/null) stderr=$(cat "$err")"
  fi
}

case_finish_missing_supplied_gate_result_reports_artifact_path() {
  local name="ship finish: missing supplied Gate result reports the artifact path"
  should_run "$name" || return 0
  local work out err marker status=0
  work="$tmp_root/work-finish-gate-missing"
  marker="$tmp_root/finish-gate-missing-run"
  make_work_repo "$work" "CC-9001"
  checkout_ticket_branch "$work" "CC-9001"
  add_bare_origin "$work"
  local gh_bin="$tmp_root/fake-gh-gate-missing-bin"
  install_fake_gh "$gh_bin" "https://example.invalid/pr/gate-missing"
  out="$tmp_root/out-finish-gate-missing"
  err="$tmp_root/err-finish-gate-missing"
  PM_TEST_GATE_RUN_MARKER="$marker" PATH="$gh_bin:$PATH" \
    run_finish_with_fake_gate "$work" "CC-9001" "GO" \
      --gate-result evidence/missing.md > "$out" 2> "$err" || status=$?
  local pushed=0
  git -C "$work.bare-origin.git" show-ref --quiet feat/CC-9001 \
    2>/dev/null && pushed=1
  if [[ "$status" -eq 1 && "$pushed" -eq 0 && ! -e "$marker" ]] \
      && grep -Fq \
        "supplied --gate-result artifact not found: $work/evidence/missing.md" \
        "$err" \
      && ! grep -Fq 'gate exit 0' "$err"; then
    pass "$name"
  else
    fail "$name" "status=$status pushed=$pushed gate_called=$([[ -e "$marker" ]] && echo yes || echo no) stderr=$(cat "$err")"
  fi
}

case_finish_stale_supplied_gate_result_refuses_publish() {
  local name="ship finish: stale supplied Gate result refuses publication"
  should_run "$name" || return 0
  local work out err status=0
  work="$tmp_root/work-finish-gate-stale"
  make_work_repo "$work" "CC-9001"
  checkout_ticket_branch "$work" "CC-9001"
  add_bare_origin "$work"
  printf 'Final: GO\n' > "$work/gate.md"
  git -C "$work" add gate.md
  git -C "$work" commit -q -m stale-gate-result
  local gh_bin="$tmp_root/fake-gh-gate-stale-bin"
  install_fake_gh "$gh_bin" "https://example.invalid/pr/gate-stale"
  out="$tmp_root/out-finish-gate-stale"
  err="$tmp_root/err-finish-gate-stale"
  PM_TEST_GATE_SUBJECT_STATUS=fail PATH="$gh_bin:$PATH" \
    run_finish_with_fake_gate "$work" "CC-9001" "GO" \
      --gate-result gate.md > "$out" 2> "$err" || status=$?
  local pushed=0
  git -C "$work.bare-origin.git" show-ref --quiet feat/CC-9001 \
    2>/dev/null && pushed=1
  if [[ "$status" -eq 1 && "$pushed" -eq 0 ]] \
      && grep -q "invalid, stale, or below the publish policy baseline" "$err"; then
    pass "$name"
  else
    fail "$name" "status=$status pushed=$pushed stderr=$(cat "$err")"
  fi
}

case_finish_invalid_supplied_gate_result_refuses_publish() {
  local name="ship finish: invalid supplied Gate result refuses publication"
  should_run "$name" || return 0
  local work out err status=0
  work="$tmp_root/work-finish-gate-invalid"
  make_work_repo "$work" "CC-9001"
  checkout_ticket_branch "$work" "CC-9001"
  add_bare_origin "$work"
  printf 'tampered\n' > "$work/gate.md"
  git -C "$work" add gate.md
  git -C "$work" commit -q -m invalid-gate-result
  local gh_bin="$tmp_root/fake-gh-gate-invalid-bin"
  install_fake_gh "$gh_bin" "https://example.invalid/pr/gate-invalid"
  out="$tmp_root/out-finish-gate-invalid"
  err="$tmp_root/err-finish-gate-invalid"
  PM_TEST_GATE_ARTIFACT_STATUS=fail PATH="$gh_bin:$PATH" \
    run_finish_with_fake_gate "$work" "CC-9001" "GO" \
      --gate-result gate.md > "$out" 2> "$err" || status=$?
  local pushed=0
  git -C "$work.bare-origin.git" show-ref --quiet feat/CC-9001 \
    2>/dev/null && pushed=1
  if [[ "$status" -eq 1 && "$pushed" -eq 0 ]] \
      && grep -q "invalid, stale, or below the publish policy baseline" "$err"; then
    pass "$name"
  else
    fail "$name" "status=$status pushed=$pushed stderr=$(cat "$err")"
  fi
}

case_finish_gate_result_rejects_reviewers() {
  local name="ship finish: supplied Gate result rejects reviewers"
  should_run "$name" || return 0
  local work out err status=0
  work="$tmp_root/work-finish-gate-reviewers"
  make_work_repo "$work" "CC-9001"
  out="$tmp_root/out-finish-gate-reviewers"
  err="$tmp_root/err-finish-gate-reviewers"
  "$PMCTL" ship finish CC-9001 --cd "$work" \
    --gate-result result.md --reviewers critic > "$out" 2> "$err" || status=$?
  if [[ "$status" -eq 2 ]] \
      && grep -q -- '--gate-result cannot be combined with --reviewers' "$err"; then
    pass "$name"
  else
    fail "$name" "status=$status stderr=$(cat "$err")"
  fi
}

case_finish_help_names_artifact_options() {
  local name="ship finish: help names the artifact-reuse options"
  should_run "$name" || return 0
  local out status=0 missing=""
  out="$tmp_root/out-finish-help"
  "$PMCTL" ship finish --help > "$out" 2>&1 || status=$?
  local flag
  for flag in --gate-result --full-result; do
    grep -q -- "$flag" "$out" || missing+=" $flag"
  done
  if [[ "$status" -eq 0 && -z "$missing" ]]; then
    pass "$name"
  else
    fail "$name" "status=$status missing:$missing help=$(cat "$out")"
  fi
}

case_finish_go_dirty_tree_refuses_push() {
  local name="ship finish: GO with an uncommitted (dirty) tree refuses to push -- committed-diff guard"
  should_run "$name" || return 0
  local work out err status=0
  work="$tmp_root/work-finish-dirty"
  make_work_repo "$work" "CC-9001"
  checkout_ticket_branch "$work" "CC-9001"
  add_bare_origin "$work"
  printf 'uncommitted\n' > "$work/dirty.txt"
  out="$tmp_root/out-finish-dirty"; err="$tmp_root/err-finish-dirty"
  run_finish_with_fake_gate "$work" "CC-9001" "GO" > "$out" 2> "$err" || status=$?
  local pushed=0
  git -C "$work.bare-origin.git" show-ref --quiet feat/CC-9001 2>/dev/null && pushed=1
  if [[ "$status" -eq 1 ]] && grep -q "tree is dirty" "$err" && [[ "$pushed" -eq 0 ]]; then
    pass "$name"
  else
    fail "$name" "expected exit 1 + no push; got status=$status pushed=$pushed stderr=$(cat "$err")"
  fi
}

case_finish_dispatched_lane_auto_commits_before_gate() {
  local name="ship finish: an --adapter-dispatched lane's uncommitted output is staged and committed before gating (CC-584) -- pm-dispatch bookkeeping paths excluded"
  should_run "$name" || return 0
  local store work out err status=0
  store="$tmp_root/state-finish-autocommit"
  work="$tmp_root/work-finish-autocommit"
  make_work_repo "$work" "CC-9001" "produce OUTPUT.md with the deliverable text."
  checkout_ticket_branch "$work" "CC-9001"
  add_bare_origin "$work"
  write_dispatched_lane_tracking_entry "$store" "$work" "CC-9001" "codex" "OUTPUT.md"
  local pre_head
  pre_head="$(git -C "$work" rev-parse HEAD)"
  # Simulated dispatch output: a real deliverable file, plus pm-dispatch's own
  # bookkeeping directories that must never enter the ticket's commit.
  printf 'dispatched output\n' > "$work/OUTPUT.md"
  mkdir -p "$work/.dispatch-results" "$work/.pm-dispatch-state"
  printf 'bookkeeping\n' > "$work/.dispatch-results/fake.md"
  printf 'bookkeeping\n' > "$work/.pm-dispatch-state/fake.json"
  local gh_bin="$tmp_root/fake-gh-autocommit-bin"
  install_fake_gh "$gh_bin" "https://example.invalid/pr/autocommit"
  out="$tmp_root/out-finish-autocommit"; err="$tmp_root/err-finish-autocommit"
  PM_DISPATCH_STATE_ROOT="$store" PATH="$gh_bin:$PATH" run_finish_with_fake_gate "$work" "CC-9001" "GO" > "$out" 2> "$err" || status=$?
  local post_head committed_files commit_subject pushed=0
  post_head="$(git -C "$work" rev-parse HEAD 2>/dev/null || true)"
  committed_files="$(git -C "$work" diff --name-only "$pre_head" "$post_head" 2>/dev/null || true)"
  commit_subject="$(git -C "$work" log -1 --format=%s "$post_head" 2>/dev/null || true)"
  git -C "$work.bare-origin.git" show-ref --quiet feat/CC-9001 2>/dev/null && pushed=1
  if [[ "$status" -eq 0 ]] \
    && [[ "$post_head" != "$pre_head" ]] \
    && [[ "$committed_files" == *"OUTPUT.md"* ]] \
    && [[ "$committed_files" != *".dispatch-results"* ]] \
    && [[ "$committed_files" != *".pm-dispatch-state"* ]] \
    && [[ "$pushed" -eq 1 ]] \
    && [[ "$commit_subject" == "ship: CC-9001 dispatched implementation -- produce OUTPUT.md with the deliverable text." ]] \
    && grep -q "committed dispatched changes for CC-9001" "$err"; then
    pass "$name"
  else
    fail "$name" "status=$status pushed=$pushed pre=$pre_head post=$post_head committed_files=[$committed_files] subject=[$commit_subject] stderr=$(cat "$err")"
  fi
}

case_finish_manual_lane_still_refuses_on_dirty_tree_when_not_dispatched() {
  local name="ship finish: a manual/in-place lane (no adapter tracking entry) keeps refusing on a dirty tree -- CC-584's auto-commit never fires without dispatch provenance"
  should_run "$name" || return 0
  local store work out err status=0
  store="$tmp_root/state-finish-manual-dirty"
  work="$tmp_root/work-finish-manual-dirty"
  make_work_repo "$work" "CC-9001"
  checkout_ticket_branch "$work" "CC-9001"
  add_bare_origin "$work"
  # No tracking entry written at all -- _pmctl_ship_lane_was_dispatched must
  # find nothing and the pre-existing dirty-tree refusal must still apply.
  printf 'uncommitted\n' > "$work/dirty.txt"
  out="$tmp_root/out-finish-manual-dirty"; err="$tmp_root/err-finish-manual-dirty"
  PM_DISPATCH_STATE_ROOT="$store" run_finish_with_fake_gate "$work" "CC-9001" "GO" > "$out" 2> "$err" || status=$?
  local pushed=0
  git -C "$work.bare-origin.git" show-ref --quiet feat/CC-9001 2>/dev/null && pushed=1
  if [[ "$status" -eq 1 ]] && grep -q "tree is dirty" "$err" && [[ "$pushed" -eq 0 ]]; then
    pass "$name"
  else
    fail "$name" "expected exit 1 + no push; got status=$status pushed=$pushed stderr=$(cat "$err")"
  fi
}

case_finish_dispatched_lane_refuses_undeclared_collateral_file() {
  local name="ship finish: an --adapter-dispatched lane refuses to auto-commit when it touched a file outside its declared allowlist (CC-584)"
  should_run "$name" || return 0
  local store work out err status=0
  store="$tmp_root/state-finish-collateral"
  work="$tmp_root/work-finish-collateral"
  make_work_repo "$work" "CC-9001"
  checkout_ticket_branch "$work" "CC-9001"
  add_bare_origin "$work"
  # Declares only OUTPUT.md -- COLLATERAL.md is real, non-bookkeeping, and
  # never declared, so finish must refuse before staging/committing/pushing
  # anything at all, not just silently drop the one undeclared file.
  write_dispatched_lane_tracking_entry "$store" "$work" "CC-9001" "codex" "OUTPUT.md"
  local pre_head
  pre_head="$(git -C "$work" rev-parse HEAD)"
  printf 'dispatched output\n' > "$work/OUTPUT.md"
  printf 'not part of the ticket\n' > "$work/COLLATERAL.md"
  out="$tmp_root/out-finish-collateral"; err="$tmp_root/err-finish-collateral"
  PM_DISPATCH_STATE_ROOT="$store" run_finish_with_fake_gate "$work" "CC-9001" "GO" > "$out" 2> "$err" || status=$?
  local post_head pushed=0
  post_head="$(git -C "$work" rev-parse HEAD 2>/dev/null || true)"
  git -C "$work.bare-origin.git" show-ref --quiet feat/CC-9001 2>/dev/null && pushed=1
  if [[ "$status" -eq 1 && "$post_head" == "$pre_head" && "$pushed" -eq 0 ]] \
    && grep -q "undeclared path" "$err" && grep -q "COLLATERAL.md" "$err"; then
    pass "$name"
  else
    fail "$name" "expected exit 1, no new commit, no push; got status=$status pre=$pre_head post=$post_head pushed=$pushed stderr=$(cat "$err")"
  fi
}

case_finish_dispatched_lane_refuses_executor_authored_gitignore() {
  local name="ship finish: an --adapter-dispatched lane refuses to auto-commit when the EXECUTOR (not the host) already modified .gitignore before dispatch finished (CC-584)"
  should_run "$name" || return 0
  local store work out err status=0
  store="$tmp_root/state-finish-gitignore-executor"
  work="$tmp_root/work-finish-gitignore-executor"
  make_work_repo "$work" "CC-9001"
  checkout_ticket_branch "$work" "CC-9001"
  add_bare_origin "$work"
  # Declares only OUTPUT.md -- .gitignore is NOT declared. Unlike the host's
  # own later patch (_pmctl_ship_ensure_gitignore), this .gitignore change
  # is already dirty BEFORE finish runs, simulating an executor that
  # rewrote it (e.g. to hide further collateral output from porcelain
  # status) -- it must be treated exactly like any other undeclared file,
  # not exempted as bookkeeping.
  write_dispatched_lane_tracking_entry "$store" "$work" "CC-9001" "codex" "OUTPUT.md"
  local pre_head
  pre_head="$(git -C "$work" rev-parse HEAD)"
  printf 'dispatched output\n' > "$work/OUTPUT.md"
  printf '.pm-dispatch/\nsecret-output/\n' > "$work/.gitignore"
  out="$tmp_root/out-finish-gitignore-executor"; err="$tmp_root/err-finish-gitignore-executor"
  PM_DISPATCH_STATE_ROOT="$store" run_finish_with_fake_gate "$work" "CC-9001" "GO" > "$out" 2> "$err" || status=$?
  local post_head pushed=0
  post_head="$(git -C "$work" rev-parse HEAD 2>/dev/null || true)"
  git -C "$work.bare-origin.git" show-ref --quiet feat/CC-9001 2>/dev/null && pushed=1
  if [[ "$status" -eq 1 && "$post_head" == "$pre_head" && "$pushed" -eq 0 ]] \
    && grep -q "undeclared path" "$err" && grep -q "\.gitignore" "$err"; then
    pass "$name"
  else
    fail "$name" "expected exit 1, no new commit, no push; got status=$status pre=$pre_head post=$post_head pushed=$pushed stderr=$(cat "$err")"
  fi
}

case_finish_dispatched_lane_refuses_with_no_declared_allowlist() {
  local name="ship finish: an --adapter-dispatched lane with no declared edit-path allowlist refuses to auto-commit at all (CC-584)"
  should_run "$name" || return 0
  local store work out err status=0
  store="$tmp_root/state-finish-no-allowlist"
  work="$tmp_root/work-finish-no-allowlist"
  make_work_repo "$work" "CC-9001"
  checkout_ticket_branch "$work" "CC-9001"
  add_bare_origin "$work"
  # No trailing declared_path args -- entry's declared_paths is [].
  write_dispatched_lane_tracking_entry "$store" "$work" "CC-9001" "codex"
  local pre_head
  pre_head="$(git -C "$work" rev-parse HEAD)"
  printf 'dispatched output\n' > "$work/OUTPUT.md"
  out="$tmp_root/out-finish-no-allowlist"; err="$tmp_root/err-finish-no-allowlist"
  PM_DISPATCH_STATE_ROOT="$store" run_finish_with_fake_gate "$work" "CC-9001" "GO" > "$out" 2> "$err" || status=$?
  local post_head pushed=0
  post_head="$(git -C "$work" rev-parse HEAD 2>/dev/null || true)"
  git -C "$work.bare-origin.git" show-ref --quiet feat/CC-9001 2>/dev/null && pushed=1
  if [[ "$status" -eq 1 && "$post_head" == "$pre_head" && "$pushed" -eq 0 ]] \
    && grep -q "no declared edit-path allowlist" "$err"; then
    pass "$name"
  else
    fail "$name" "expected exit 1, no new commit, no push; got status=$status pre=$pre_head post=$post_head pushed=$pushed stderr=$(cat "$err")"
  fi
}

case_finish_dispatched_lane_bookkeeping_only_reports_explicitly_and_gates_old_head() {
  local name="ship finish: an --adapter-dispatched lane whose only dirty paths are pm-dispatch bookkeeping reports explicitly and never claims a ticket deliverable was committed (CC-584)"
  should_run "$name" || return 0
  local store work out err status=0
  store="$tmp_root/state-finish-bookkeeping-only"
  work="$tmp_root/work-finish-bookkeeping-only"
  make_work_repo "$work" "CC-9001"
  checkout_ticket_branch "$work" "CC-9001"
  add_bare_origin "$work"
  write_dispatched_lane_tracking_entry "$store" "$work" "CC-9001" "codex" "OUTPUT.md"
  local pre_head
  pre_head="$(git -C "$work" rev-parse HEAD)"
  # Only bookkeeping paths are dirty -- no OUTPUT.md, nothing declared was
  # touched. Must be reported explicitly (not silently passed through) and
  # must never claim a "dispatched implementation" was committed; a lone
  # .gitignore bookkeeping-patch commit is the one exception allowed to
  # land on HEAD (needed so the tree is clean for gate/push), and its own
  # message says so rather than pretending it is the ticket's deliverable.
  mkdir -p "$work/.dispatch-results"
  printf 'bookkeeping\n' > "$work/.dispatch-results/fake.md"
  local gh_bin="$tmp_root/fake-gh-bookkeeping-only-bin"
  install_fake_gh "$gh_bin" "https://example.invalid/pr/bookkeeping-only"
  out="$tmp_root/out-finish-bookkeeping-only"; err="$tmp_root/err-finish-bookkeeping-only"
  PM_DISPATCH_STATE_ROOT="$store" PATH="$gh_bin:$PATH" run_finish_with_fake_gate "$work" "CC-9001" "GO" > "$out" 2> "$err" || status=$?
  local post_head pushed=0 committed_files
  post_head="$(git -C "$work" rev-parse HEAD 2>/dev/null || true)"
  committed_files="$(git -C "$work" diff --name-only "$pre_head" "$post_head" 2>/dev/null || true)"
  git -C "$work.bare-origin.git" show-ref --quiet feat/CC-9001 2>/dev/null && pushed=1
  if [[ "$status" -eq 0 && "$pushed" -eq 1 ]] \
    && [[ "$committed_files" == ".gitignore" || -z "$committed_files" ]] \
    && grep -q "only pm-dispatch bookkeeping changes" "$err" \
    && ! grep -q "committed dispatched changes for CC-9001" "$err"; then
    pass "$name"
  else
    fail "$name" "expected exit 0, pushed, only .gitignore (if anything) committed; got status=$status pre=$pre_head post=$post_head committed_files=[$committed_files] pushed=$pushed stderr=$(cat "$err")"
  fi
}

case_finish_go_head_moved_refuses_push() {
  local name="ship finish: GO but HEAD moved during the gate run refuses to push an un-gated commit"
  should_run "$name" || return 0
  local work out err status=0
  work="$tmp_root/work-finish-headmoved"
  make_work_repo "$work" "CC-9001"
  checkout_ticket_branch "$work" "CC-9001"
  add_bare_origin "$work"
  out="$tmp_root/out-finish-headmoved"; err="$tmp_root/err-finish-headmoved"
  # Stub gate that ALSO makes an extra, never-reviewed commit as a side
  # effect -- simulates something landing on HEAD during the gate window.
  bash -c '
    repo_root="$1"; work_dir="$2"; ticket_id="$3"
    pmctl_gate_run() {
      printf "sneaky\n" > "'"$work"'/sneaky.txt"
      git -C "'"$work"'" add sneaky.txt
      git -C "'"$work"'" commit -q -m sneaky
      local result_file
      result_file="$(mktemp)"
      printf "Final: GO\n" > "$result_file"
      printf "result: %s\n" "$result_file"
      return 0
    }
    pmctl_gate_verify() {
      jq -n '"'"'{
        kind:"gate_verification_v1",
        verdict:"GO",
        axes:{
          artifact_valid:{status:"pass",reason_codes:[]},
          subject_current:{status:"pass",reason_codes:[]},
          policy_applicable:{status:"pass",reason_codes:[]}
        }
      }'"'"'
    }
    . "$repo_root/runtime/lib/pmctl-ship.sh"
    pmctl_ship_finish "$repo_root" "$work_dir" "$ticket_id"
  ' _ "$REPO_ROOT" "$work" "CC-9001" > "$out" 2> "$err" || status=$?
  local pushed=0
  git -C "$work.bare-origin.git" show-ref --quiet feat/CC-9001 2>/dev/null && pushed=1
  if [[ "$status" -eq 1 ]] && grep -q "HEAD moved during the gate run" "$err" && [[ "$pushed" -eq 0 ]]; then
    pass "$name"
  else
    fail "$name" "expected exit 1 + no push; got status=$status pushed=$pushed stderr=$(cat "$err")"
  fi
}

case_finish_supplied_gate_result_head_moved_refuses_push() {
  local name="ship finish: supplied Gate result reports HEAD drift without claiming a Gate ran"
  should_run "$name" || return 0
  local work out err status=0
  work="$tmp_root/work-finish-supplied-headmoved"
  make_work_repo "$work" "CC-9001"
  checkout_ticket_branch "$work" "CC-9001"
  add_bare_origin "$work"
  printf 'Final: GO\n' > "$work/gate.md"
  git -C "$work" add gate.md
  git -C "$work" commit -q -m supplied-gate-result
  local gh_bin="$tmp_root/fake-gh-supplied-headmoved-bin"
  install_fake_gh "$gh_bin" "https://example.invalid/pr/supplied-headmoved"
  out="$tmp_root/out-finish-supplied-headmoved"
  err="$tmp_root/err-finish-supplied-headmoved"
  PATH="$gh_bin:$PATH" bash -c '
    repo_root="$1"; work_dir="$2"; ticket_id="$3"
    pmctl_gate_run() {
      printf "unexpected Gate run\n" >&2
      return 99
    }
    pmctl_gate_verify() {
      printf "sneaky\n" > "$work_dir/sneaky.txt"
      git -C "$work_dir" add sneaky.txt
      git -C "$work_dir" commit -q -m sneaky
      jq -n '"'"'{
        kind:"gate_verification_v1",
        verdict:"GO",
        axes:{
          artifact_valid:{status:"pass",reason_codes:[]},
          subject_current:{status:"pass",reason_codes:[]},
          policy_applicable:{status:"pass",reason_codes:[]}
        }
      }'"'"'
    }
    . "$repo_root/runtime/lib/pmctl-ship.sh"
    pmctl_ship_finish "$repo_root" "$work_dir" "$ticket_id" \
      --gate-result "$work_dir/gate.md"
  ' _ "$REPO_ROOT" "$work" "CC-9001" > "$out" 2> "$err" || status=$?
  local pushed=0
  git -C "$work.bare-origin.git" show-ref --quiet feat/CC-9001 \
    2>/dev/null && pushed=1
  if [[ "$status" -eq 1 && "$pushed" -eq 0 ]] \
      && grep -q "HEAD moved while verifying supplied --gate-result" "$err" \
      && ! grep -q "HEAD moved during the gate run" "$err" \
      && ! grep -q "unexpected Gate run" "$err"; then
    pass "$name"
  else
    fail "$name" "status=$status pushed=$pushed stderr=$(cat "$err")"
  fi
}

case_finish_gh_missing_refuses_before_gate_or_push() {
  local name="ship finish: gh unavailable refuses before the gate even runs -- no push, no gate round spent"
  should_run "$name" || return 0
  local work out err status=0
  work="$tmp_root/work-finish-nogh"
  make_work_repo "$work" "CC-9001"
  checkout_ticket_branch "$work" "CC-9001"
  add_bare_origin "$work"
  out="$tmp_root/out-finish-nogh"; err="$tmp_root/err-finish-nogh"
  # A curated PATH containing symlinks to exactly the tools finish needs
  # (git/jq/bash/coreutils) but NOT `gh` -- simulates "gh unavailable"
  # without the earlier approach's bug (removing whole real-PATH dirs that
  # happen to contain `gh` alongside `git`/`jq` on this host removed those
  # too, so `command -v git` etc. failed with 127 -- a false "gh missing"
  # signal for the wrong reason).
  local nogh_bin="$tmp_root/nogh-bin"
  mkdir -p "$nogh_bin"
  local tool tool_path
  for tool in git jq bash mktemp awk sed grep date dirname basename cat mv rm mkdir; do
    tool_path="$(command -v "$tool" 2>/dev/null)" || continue
    ln -sf "$tool_path" "$nogh_bin/$tool"
  done
  # gate_call_marker: the stub pmctl_gate_run touches this if it is ever
  # invoked -- proves finish refused BEFORE spending a gate round, per the
  # risk-reviewer fix (preflight gh before the gate runs, not just before
  # push), not merely before push.
  local gate_call_marker="$tmp_root/gate-was-called"
  rm -f "$gate_call_marker"
  PATH="$nogh_bin" bash -c '
    repo_root="$1"; work_dir="$2"; ticket_id="$3"; gate_call_marker="$4"
    pmctl_gate_run() { touch "$gate_call_marker"; printf "result: /dev/null\n"; return 1; }
    . "$repo_root/runtime/lib/pmctl-ship.sh"
    pmctl_ship_finish "$repo_root" "$work_dir" "$ticket_id"
  ' _ "$REPO_ROOT" "$work" "CC-9001" "$gate_call_marker" > "$out" 2> "$err" || status=$?
  local pushed=0
  git -C "$work.bare-origin.git" show-ref --quiet feat/CC-9001 2>/dev/null && pushed=1
  if [[ "$status" -eq 1 ]] && grep -q "gh.*unavailable" "$err" && [[ "$pushed" -eq 0 ]] && [[ ! -f "$gate_call_marker" ]]; then
    pass "$name"
  else
    fail "$name" "expected exit 1 + no push + no gate call; got status=$status pushed=$pushed gate_called=$([[ -f "$gate_call_marker" ]] && echo yes || echo no) stderr=$(cat "$err")"
  fi
}

case_finish_wrong_branch_refuses_before_gate_or_push() {
  local name="ship finish: checked-out branch not matching feat/<ticket-id> refuses before the gate runs -- branch/ticket-identity guard"
  should_run "$name" || return 0
  local work out err status=0
  work="$tmp_root/work-finish-wrongbranch"
  make_work_repo "$work" "CC-9001"
  # Deliberately checked out on a DIFFERENT branch than feat/CC-9001 --
  # simulates a wrong --cd, stale worktree, or confused executor call.
  git -C "$work" checkout -q -b some-other-branch
  add_bare_origin "$work"
  out="$tmp_root/out-finish-wrongbranch"; err="$tmp_root/err-finish-wrongbranch"
  local gate_call_marker="$tmp_root/gate-was-called-wrongbranch"
  rm -f "$gate_call_marker"
  bash -c '
    repo_root="$1"; work_dir="$2"; ticket_id="$3"; gate_call_marker="$4"
    pmctl_gate_run() { touch "$gate_call_marker"; printf "result: /dev/null\n"; return 1; }
    . "$repo_root/runtime/lib/pmctl-ship.sh"
    pmctl_ship_finish "$repo_root" "$work_dir" "$ticket_id"
  ' _ "$REPO_ROOT" "$work" "CC-9001" "$gate_call_marker" > "$out" 2> "$err" || status=$?
  local pushed=0
  git -C "$work.bare-origin.git" show-ref --quiet some-other-branch 2>/dev/null && pushed=1
  if [[ "$status" -eq 1 ]] && grep -q "does not match the ticket" "$err" && [[ "$pushed" -eq 0 ]] && [[ ! -f "$gate_call_marker" ]]; then
    pass "$name"
  else
    fail "$name" "expected exit 1 + no push + no gate call; got status=$status pushed=$pushed gate_called=$([[ -f "$gate_call_marker" ]] && echo yes || echo no) stderr=$(cat "$err")"
  fi
}

case_finish_go_pushes_and_opens_pr() {
  local name="ship finish: GO + clean tree + gh available pushes, opens PR, writes GO marker with the pr_url"
  should_run "$name" || return 0
  local work out err status=0
  work="$tmp_root/work-finish-go"
  make_work_repo "$work" "CC-9001"
  checkout_ticket_branch "$work" "CC-9001"
  add_bare_origin "$work"
  local gh_bin="$tmp_root/fake-gh-bin"
  install_fake_gh "$gh_bin" "https://example.invalid/pr/99"
  out="$tmp_root/out-finish-go"; err="$tmp_root/err-finish-go"
  PATH="$gh_bin:$PATH" run_finish_with_fake_gate "$work" "CC-9001" "GO" > "$out" 2> "$err" || status=$?
  local pushed=0
  git -C "$work.bare-origin.git" show-ref --quiet feat/CC-9001 2>/dev/null && pushed=1
  local marker_verdict marker_pr marker_schema marker_satisfaction marker_assessment assurance_line=0
  marker_verdict="$(jq -r '.verdict // ""' "$work/.pm-dispatch-ship-finish.json" 2>/dev/null)"
  marker_pr="$(jq -r '.pr_url // ""' "$work/.pm-dispatch-ship-finish.json" 2>/dev/null)"
  marker_schema="$(jq -r '.schema_version // ""' "$work/.pm-dispatch-ship-finish.json" 2>/dev/null)"
  marker_satisfaction="$(jq -r '.publish_assurance.policy_satisfaction // ""' "$work/.pm-dispatch-ship-finish.json" 2>/dev/null)"
  marker_assessment="$(jq -r '.publish_assessment // ""' "$work/.pm-dispatch-ship-finish.json" 2>/dev/null)"
  grep -Fq 'publish assurance: producer=maintainer satisfaction=preferred' "$out" && assurance_line=1
  if [[ "$status" -eq 0 && "$pushed" -eq 1 && "$marker_verdict" == "GO" \
      && "$marker_pr" == "https://example.invalid/pr/99" \
      && "$marker_schema" == "2" && "$marker_satisfaction" == "preferred" \
      && "$marker_assessment" == *ship-publish-assessment-CC-9001-* \
      && "$assurance_line" -eq 1 ]]; then
    pass "$name"
  else
    fail "$name" "expected GO marker plus verified assurance; got status=$status pushed=$pushed marker=$marker_verdict pr=$marker_pr schema=$marker_schema satisfaction=$marker_satisfaction assessment=$marker_assessment stdout=$(cat "$out")"
  fi
}

case_finish_runs_and_verifies_current_tree_full_suite_before_publish() {
  # Behavior: a successful finish produces and verifies current-tree full-suite evidence before publishing.
  # Steps: run a GO fixture with a recording runner, then require both full-run and verify calls plus a pushed branch.
  local name="ship finish: fresh current-tree full suite is run and canonically verified before push/PR"
  should_run "$name" || return 0
  local work out err log status=0
  work="$tmp_root/work-finish-full-auto"
  log="$tmp_root/finish-full-auto.log"
  make_work_repo "$work" "CC-9001"
  checkout_ticket_branch "$work" "CC-9001"
  add_bare_origin "$work"
  local gh_bin="$tmp_root/fake-gh-full-auto-bin"
  install_fake_gh "$gh_bin" "https://example.invalid/pr/full-auto"
  out="$tmp_root/out-finish-full-auto"; err="$tmp_root/err-finish-full-auto"
  PM_TEST_RUNNER_LOG="$log" PATH="$gh_bin:$PATH" run_finish_with_fake_gate "$work" "CC-9001" "GO" > "$out" 2> "$err" || status=$?
  local pushed=0
  git -C "$work.bare-origin.git" show-ref --quiet feat/CC-9001 2>/dev/null && pushed=1
  if [[ "$status" -eq 0 && "$pushed" -eq 1 ]] \
    && grep -q '^--all --result-file ' "$log" \
    && grep -q '^--verify-full ' "$log"; then
    pass "$name"
  else
    fail "$name" "expected fresh full run + verify before publish; status=$status pushed=$pushed log=$(cat "$log" 2>/dev/null) stderr=$(cat "$err")"
  fi
}

case_finish_invalid_supplied_full_result_refuses_publish() {
  # Behavior: supplied evidence cannot bypass canonical full-result verification.
  # Steps: make the runner reject a caller artifact and require no remote branch is created.
  local name="ship finish: invalid caller-supplied full result fails closed before push/PR"
  should_run "$name" || return 0
  local work out err log artifact status=0
  work="$tmp_root/work-finish-full-invalid"
  log="$tmp_root/finish-full-invalid.log"
  artifact="$tmp_root/invalid-full-result.json"
  printf '{"not":"authoritative"}\n' > "$artifact"
  make_work_repo "$work" "CC-9001"
  checkout_ticket_branch "$work" "CC-9001"
  add_bare_origin "$work"
  local gh_bin="$tmp_root/fake-gh-full-invalid-bin"
  install_fake_gh "$gh_bin" "https://example.invalid/pr/full-invalid"
  out="$tmp_root/out-finish-full-invalid"; err="$tmp_root/err-finish-full-invalid"
  PM_TEST_RUNNER_LOG="$log" PM_TEST_FULL_VERIFY_STATUS=1 PATH="$gh_bin:$PATH" \
    run_finish_with_fake_gate "$work" "CC-9001" "GO" --full-result "$artifact" > "$out" 2> "$err" || status=$?
  local pushed=0
  git -C "$work.bare-origin.git" show-ref --quiet feat/CC-9001 2>/dev/null && pushed=1
  if [[ "$status" -eq 1 && "$pushed" -eq 0 ]] \
    && grep -Fxq -- "--verify-full $artifact" "$log" \
    && ! grep -q '^--all ' "$log" \
    && grep -q 'evidence is not valid for the current tree' "$err"; then
    pass "$name"
  else
    fail "$name" "expected fail-closed supplied artifact rejection; status=$status pushed=$pushed log=$(cat "$log" 2>/dev/null) stderr=$(cat "$err")"
  fi
}

case_finish_failed_full_suite_refuses_publish() {
  # Behavior: a fresh full-suite failure blocks all publication side effects.
  # Steps: force the recording runner's full invocation to fail and require no remote branch is created.
  local name="ship finish: failed fresh full suite refuses push/PR"
  should_run "$name" || return 0
  local work out err log status=0
  work="$tmp_root/work-finish-full-failed"
  log="$tmp_root/finish-full-failed.log"
  make_work_repo "$work" "CC-9001"
  checkout_ticket_branch "$work" "CC-9001"
  add_bare_origin "$work"
  local gh_bin="$tmp_root/fake-gh-full-failed-bin"
  install_fake_gh "$gh_bin" "https://example.invalid/pr/full-failed"
  out="$tmp_root/out-finish-full-failed"; err="$tmp_root/err-finish-full-failed"
  PM_TEST_RUNNER_LOG="$log" PM_TEST_FULL_RUN_STATUS=1 PATH="$gh_bin:$PATH" \
    run_finish_with_fake_gate "$work" "CC-9001" "GO" > "$out" 2> "$err" || status=$?
  local pushed=0
  git -C "$work.bare-origin.git" show-ref --quiet feat/CC-9001 2>/dev/null && pushed=1
  if [[ "$status" -eq 1 && "$pushed" -eq 0 ]] \
    && grep -q '^--all --result-file ' "$log" \
    && ! grep -q '^--verify-full ' "$log" \
    && grep -q 'authoritative full suite failed' "$err"; then
    pass "$name"
  else
    fail "$name" "expected failed suite to block publish; status=$status pushed=$pushed log=$(cat "$log" 2>/dev/null) stderr=$(cat "$err")"
  fi
}

case_finish_post_suite_head_drift_refuses_publish() {
  # Behavior: publication rejects a commit created after the gate and during an otherwise-successful full suite.
  # Steps: make the runner commit a fixture mutation, then require the post-suite HEAD guard and no remote branch.
  local name="ship finish: HEAD changed while a full suite ran refuses push/PR despite runner success"
  should_run "$name" || return 0
  local work out err log status=0
  work="$tmp_root/work-finish-full-head-drift"
  log="$tmp_root/finish-full-head-drift.log"
  make_work_repo "$work" "CC-9001"
  checkout_ticket_branch "$work" "CC-9001"
  add_bare_origin "$work"
  local gh_bin="$tmp_root/fake-gh-full-head-drift-bin"
  install_fake_gh "$gh_bin" "https://example.invalid/pr/full-head-drift"
  out="$tmp_root/out-finish-full-head-drift"; err="$tmp_root/err-finish-full-head-drift"
  PM_TEST_RUNNER_LOG="$log" PM_TEST_FULL_RUN_MUTATE=head PATH="$gh_bin:$PATH" \
    run_finish_with_fake_gate "$work" "CC-9001" "GO" > "$out" 2> "$err" || status=$?
  local pushed=0
  git -C "$work.bare-origin.git" show-ref --quiet feat/CC-9001 2>/dev/null && pushed=1
  if [[ "$status" -eq 1 && "$pushed" -eq 0 ]] \
    && grep -q '^--verify-full ' "$log" \
    && grep -q 'HEAD moved after the gate' "$err"; then
    pass "$name"
  else
    fail "$name" "expected post-suite HEAD drift to block publish; status=$status pushed=$pushed log=$(cat "$log" 2>/dev/null) stderr=$(cat "$err")"
  fi
}

case_finish_valid_supplied_full_result_publishes() {
  # Behavior: a canonically accepted caller full-result artifact may satisfy the publish evidence requirement.
  # Steps: supply a relative artifact path to a passing recording verifier and require verification plus a pushed branch.
  local name="ship finish: valid supplied full result is resolved against --cd, verified, and permits publish"
  should_run "$name" || return 0
  local work out err log status=0
  work="$tmp_root/work-finish-full-supplied"
  log="$tmp_root/finish-full-supplied.log"
  make_work_repo "$work" "CC-9001"
  checkout_ticket_branch "$work" "CC-9001"
  add_bare_origin "$work"
  mkdir -p "$work/evidence"
  printf '{"fake":"supplied-full-result"}\n' > "$work/evidence/full.json"
  git -C "$work" add evidence/full.json
  git -C "$work" commit -q -m supplied-full-result
  local gh_bin="$tmp_root/fake-gh-full-supplied-bin"
  install_fake_gh "$gh_bin" "https://example.invalid/pr/full-supplied"
  out="$tmp_root/out-finish-full-supplied"; err="$tmp_root/err-finish-full-supplied"
  PM_TEST_RUNNER_LOG="$log" PATH="$gh_bin:$PATH" \
    run_finish_with_fake_gate "$work" "CC-9001" "GO" --full-result evidence/full.json > "$out" 2> "$err" || status=$?
  local pushed=0
  git -C "$work.bare-origin.git" show-ref --quiet feat/CC-9001 2>/dev/null && pushed=1
  if [[ "$status" -eq 0 && "$pushed" -eq 1 ]] \
    && grep -Fxq -- "--verify-full $work/evidence/full.json" "$log" \
    && ! grep -q '^--all ' "$log"; then
    pass "$name"
  else
    fail "$name" "expected verified supplied evidence to publish; status=$status pushed=$pushed log=$(cat "$log" 2>/dev/null) stderr=$(cat "$err")"
  fi
}

case_finish_cli_forwards_full_result_option() {
  # Behavior: the public CLI recognizes --full-result rather than rejecting it as an unknown finish option.
  # Steps: invoke the real CLI with a missing option value and require the finish-specific argument diagnostic.
  local name="ship finish CLI: --full-result is forwarded to the finish contract"
  should_run "$name" || return 0
  local work out err status=0
  work="$tmp_root/work-finish-cli-full-result"
  make_work_repo "$work" "CC-9001"
  out="$tmp_root/out-finish-cli-full-result"; err="$tmp_root/err-finish-cli-full-result"
  "$PMCTL" ship finish CC-9001 --full-result --cd "$work" > "$out" 2> "$err" || status=$?
  if [[ "$status" -eq 2 ]] && grep -q -- '--full-result requires an artifact path' "$err"; then
    pass "$name"
  else
    fail "$name" "expected finish-specific --full-result diagnostic; status=$status stderr=$(cat "$err")"
  fi
}

case_finish_cli_forwards_gate_result_option() {
  local name="ship finish CLI: --gate-result is forwarded to the finish contract"
  should_run "$name" || return 0
  local work out err status=0
  work="$tmp_root/work-finish-cli-gate-result"
  make_work_repo "$work" "CC-9001"
  out="$tmp_root/out-finish-cli-gate-result"
  err="$tmp_root/err-finish-cli-gate-result"
  "$PMCTL" ship finish CC-9001 --gate-result --cd "$work" \
    > "$out" 2> "$err" || status=$?
  if [[ "$status" -eq 2 ]] \
      && grep -q -- '--gate-result requires an artifact path' "$err"; then
    pass "$name"
  else
    fail "$name" "status=$status stderr=$(cat "$err")"
  fi
}

case_finish_cli_valid_gate_result_publishes() {
  local name="ship finish CLI: valid --gate-result reaches publish verification"
  should_run "$name" || return 0
  local work product out err status=0
  work="$tmp_root/work-finish-cli-gate-success"
  product="$tmp_root/product-cli-gate-success"
  make_work_repo "$work" "CC-9001"
  checkout_ticket_branch "$work" "CC-9001"
  add_bare_origin "$work"
  mkdir -p "$work/evidence"
  printf 'Final: GO\n' > "$work/evidence/gate.md"
  git -C "$work" add evidence/gate.md
  git -C "$work" commit -q -m cli-supplied-gate-result
  make_cli_fixture_with_fake_gate "$product"
  local gh_bin="$tmp_root/fake-gh-cli-gate-success-bin"
  install_fake_gh "$gh_bin" "https://example.invalid/pr/cli-gate-success"
  out="$tmp_root/out-finish-cli-gate-success"
  err="$tmp_root/err-finish-cli-gate-success"
  PATH="$gh_bin:$PATH" \
    "$product/cli/pmctl" ship finish CC-9001 --cd "$work" \
      --gate-result evidence/gate.md > "$out" 2> "$err" || status=$?
  local pushed=0
  git -C "$work.bare-origin.git" show-ref --quiet feat/CC-9001 \
    2>/dev/null && pushed=1
  if [[ "$status" -eq 0 && "$pushed" -eq 1 ]] \
      && grep -q "verifying supplied Gate result: $work/evidence/gate.md" "$out"; then
    pass "$name"
  else
    fail "$name" "status=$status pushed=$pushed stderr=$(cat "$err")"
  fi
}

case_finish_cli_valid_full_result_publishes() {
  # Behavior: a valid public --full-result invocation reaches the real finish verifier and publish path.
  # Steps: invoke a minimal real CLI/runtime fixture with a post-load fake gate, then require resolved verification and push.
  local name="ship finish CLI: valid --full-result reaches verifier and permits publish"
  should_run "$name" || return 0
  local work product out err log status=0
  work="$tmp_root/work-finish-cli-full-success"
  product="$tmp_root/product-cli-full-success"
  log="$tmp_root/finish-cli-full-success.log"
  make_work_repo "$work" "CC-9001"
  checkout_ticket_branch "$work" "CC-9001"
  add_bare_origin "$work"
  mkdir -p "$work/evidence"
  printf '{"fake":"cli-supplied-full-result"}\n' > "$work/evidence/full.json"
  git -C "$work" add evidence/full.json
  git -C "$work" commit -q -m cli-supplied-full-result
  make_cli_fixture_with_fake_gate "$product"
  local gh_bin="$tmp_root/fake-gh-cli-full-success-bin"
  install_fake_gh "$gh_bin" "https://example.invalid/pr/cli-full-success"
  out="$tmp_root/out-finish-cli-full-success"; err="$tmp_root/err-finish-cli-full-success"
  PM_TEST_RUNNER_LOG="$log" PATH="$gh_bin:$PATH" \
    "$product/cli/pmctl" ship finish CC-9001 --cd "$work" --full-result evidence/full.json > "$out" 2> "$err" || status=$?
  local pushed=0
  git -C "$work.bare-origin.git" show-ref --quiet feat/CC-9001 2>/dev/null && pushed=1
  if [[ "$status" -eq 0 && "$pushed" -eq 1 ]] \
    && grep -Fxq -- "--verify-full $work/evidence/full.json" "$log"; then
    pass "$name"
  else
    fail "$name" "expected valid CLI artifact to verify and publish; status=$status pushed=$pushed log=$(cat "$log" 2>/dev/null) stderr=$(cat "$err")"
  fi
}

case_finish_gh_pr_create_runtime_failure_writes_pushed_pr_failed_marker() {
  local name="ship finish: gh pr create fails at runtime after a successful push -- writes PUSHED_PR_FAILED marker, exits nonzero"
  should_run "$name" || return 0
  local work out err status=0
  work="$tmp_root/work-finish-prfail"
  make_work_repo "$work" "CC-9001"
  checkout_ticket_branch "$work" "CC-9001"
  add_bare_origin "$work"
  local gh_bin="$tmp_root/fake-gh-prfail-bin"
  install_fake_gh_pr_create_fails "$gh_bin"
  out="$tmp_root/out-finish-prfail"; err="$tmp_root/err-finish-prfail"
  PATH="$gh_bin:$PATH" run_finish_with_fake_gate "$work" "CC-9001" "GO" > "$out" 2> "$err" || status=$?
  local pushed=0
  git -C "$work.bare-origin.git" show-ref --quiet feat/CC-9001 2>/dev/null && pushed=1
  local marker_verdict
  marker_verdict="$(jq -r '.verdict // ""' "$work/.pm-dispatch-ship-finish.json" 2>/dev/null)"
  if [[ "$status" -ne 0 && "$pushed" -eq 1 && "$marker_verdict" == "PUSHED_PR_FAILED" ]]; then
    pass "$name"
  else
    fail "$name" "expected nonzero exit + pushed + PUSHED_PR_FAILED marker; got status=$status pushed=$pushed marker=$marker_verdict"
  fi
}

case_finish_pr_failure_persists_fallback_when_marker_write_fails() {
  local name="ship finish: PR failure persists queryable fallback when marker write fails"
  should_run "$name" || return 0
  local store work gh_bin out err status=0 pushed=0 reg_dir partial partial_verdict lane_status
  store="$tmp_root/state-finish-prfail-fallback"
  work="$tmp_root/work-finish-prfail-fallback"
  make_work_repo "$work" "CC-9001"
  checkout_ticket_branch "$work" "CC-9001"
  add_bare_origin "$work"
  mkdir -p "$work/.pm-dispatch-ship-finish.json"
  gh_bin="$tmp_root/fake-gh-prfail-fallback-bin"
  install_fake_gh_pr_create_fails "$gh_bin"
  out="$tmp_root/out-finish-prfail-fallback"; err="$tmp_root/err-finish-prfail-fallback"
  PM_DISPATCH_STATE_ROOT="$store" PATH="$gh_bin:$PATH" \
    run_finish_with_fake_gate "$work" "CC-9001" "GO" > "$out" 2> "$err" || status=$?
  git -C "$work.bare-origin.git" show-ref --quiet feat/CC-9001 2>/dev/null && pushed=1
  reg_dir="$(reg_dir_for "$store" "$work")"
  partial="$reg_dir/ship-partial-CC-9001.json"
  partial_verdict="$(jq -r '.verdict // ""' "$partial" 2>/dev/null || true)"
  lane_status="$(PM_DISPATCH_STATE_ROOT="$store" bash -c '
    . "$1/runtime/lib/pmctl-ship.sh"
    _pmctl_ship_lane_status "$2" "" "" CC-9001
  ' _ "$REPO_ROOT" "$work" 2>/dev/null || true)"
  if [[ "$status" -ne 0 && "$pushed" -eq 1 && "$partial_verdict" == "PUSHED_PR_FAILED" \
      && "$lane_status" == "partial" ]] \
      && grep -q 'durable publication recovery record' "$err"; then
    pass "$name"
  else
    fail "$name" "expected durable fallback + partial status; status=$status pushed=$pushed partial=$partial_verdict lane_status=$lane_status stderr=$(cat "$err")"
  fi
}

case_finish_go_persists_fallback_when_marker_write_fails() {
  local name="ship finish: GO persists recovery record when marker write fails"
  should_run "$name" || return 0
  local store work gh_bin out err status=0 pushed=0 reg_dir recovery recovery_verdict lane_status
  store="$tmp_root/state-finish-go-fallback"
  work="$tmp_root/work-finish-go-fallback"
  make_work_repo "$work" "CC-9001"
  checkout_ticket_branch "$work" "CC-9001"
  add_bare_origin "$work"
  mkdir -p "$work/.pm-dispatch-ship-finish.json"
  gh_bin="$tmp_root/fake-gh-go-fallback"
  install_fake_gh "$gh_bin" "https://example.invalid/pr/go-fallback"
  out="$tmp_root/out-finish-go-fallback"; err="$tmp_root/err-finish-go-fallback"
  PM_DISPATCH_STATE_ROOT="$store" PATH="$gh_bin:$PATH" \
    run_finish_with_fake_gate "$work" "CC-9001" GO > "$out" 2> "$err" || status=$?
  git -C "$work.bare-origin.git" show-ref --quiet feat/CC-9001 2>/dev/null && pushed=1
  reg_dir="$(reg_dir_for "$store" "$work")"
  recovery="$reg_dir/ship-partial-CC-9001.json"
  recovery_verdict="$(jq -r '.verdict // ""' "$recovery" 2>/dev/null || true)"
  lane_status="$(PM_DISPATCH_STATE_ROOT="$store" bash -c '
    . "$1/runtime/lib/pmctl-ship.sh"
    _pmctl_ship_lane_status "$2" "" "" CC-9001
  ' _ "$REPO_ROOT" "$work" 2>/dev/null || true)"
  if [[ "$status" -eq 0 && "$pushed" -eq 1 && "$recovery_verdict" == GO \
      && "$lane_status" == go ]] && grep -q 'durable publication recovery record' "$err"; then
    pass "$name"
  else
    fail "$name" "expected durable GO fallback + go status; status=$status pushed=$pushed verdict=$recovery_verdict lane_status=$lane_status stderr=$(cat "$err")"
  fi
}

case_finish_go_fails_when_all_recovery_sinks_fail() {
  local name="ship finish: GO returns partial failure when all recovery sinks fail"
  should_run "$name" || return 0
  local store work gh_bin out err status=0 pushed=0 lane_status
  store="$tmp_root/state-finish-go-recovery-failure"
  work="$tmp_root/work-finish-go-recovery-failure"
  make_work_repo "$work" "CC-9001"
  checkout_ticket_branch "$work" "CC-9001"
  add_bare_origin "$work"
  mkdir -p "$work/.pm-dispatch-ship-finish.json"
  gh_bin="$tmp_root/fake-gh-go-recovery-failure"
  install_fake_gh "$gh_bin" "https://example.invalid/pr/go-recovery-failure"
  out="$tmp_root/out-finish-go-recovery-failure"; err="$tmp_root/err-finish-go-recovery-failure"
  PM_DISPATCH_STATE_ROOT="$store" PM_TEST_FAIL_RECOVERY_RECORD=1 PATH="$gh_bin:$PATH" \
    run_finish_with_fake_gate "$work" "CC-9001" GO > "$out" 2> "$err" || status=$?
  git -C "$work.bare-origin.git" show-ref --quiet feat/CC-9001 2>/dev/null && pushed=1
  lane_status="$(PM_DISPATCH_STATE_ROOT="$store" bash -c '
    . "$1/runtime/lib/pmctl-ship.sh"
    _pmctl_ship_lane_status "$2" "" "" CC-9001
  ' _ "$REPO_ROOT" "$work" 2>/dev/null || true)"
  if [[ "$status" -ne 0 && "$pushed" -eq 1 && "$lane_status" != go ]] \
      && grep -q 'no durable recovery record was persisted' "$err" \
      && grep -q 'recover the pushed branch and PR manually' "$err"; then
    pass "$name"
  else
    fail "$name" "expected nonzero recovery failure; status=$status pushed=$pushed lane_status=$lane_status stderr=$(cat "$err")"
  fi
}

case_finish_retries_after_pr_create_failure() {
  local name="ship finish: retry after PR-create failure reuses verified assessment"
  should_run "$name" || return 0
  local work gh_bin first_marker body out1 err1 out2 err2 status1=0 status2=0 pushed=0 marker_verdict
  work="$tmp_root/work-finish-pr-retry"
  make_work_repo "$work" "CC-9001"
  checkout_ticket_branch "$work" "CC-9001"
  add_bare_origin "$work"
  gh_bin="$tmp_root/fake-gh-pr-retry-bin"
  first_marker="$tmp_root/fake-gh-pr-retry-first-attempt"
  install_fake_gh_pr_create_fails_once "$gh_bin" "$first_marker" "https://example.invalid/pr/retry"
  body="$tmp_root/real-publish-pr-retry-body"
  out1="$tmp_root/out-finish-pr-retry-first"; err1="$tmp_root/err-finish-pr-retry-first"
  export GH_PR_URL="https://example.invalid/pr/retry" GH_PR_BODY_FILE="$body"
  PATH="$gh_bin:$PATH" run_finish_with_real_publish_assessment \
    "$work" "CC-9001" real-closure "$body" > "$out1" 2> "$err1" || status1=$?
  out2="$tmp_root/out-finish-pr-retry-second"; err2="$tmp_root/err-finish-pr-retry-second"
  PATH="$gh_bin:$PATH" run_finish_with_real_publish_assessment \
    "$work" "CC-9001" real-closure "$body" > "$out2" 2> "$err2" || status2=$?
  unset GH_PR_URL GH_PR_BODY_FILE
  git -C "$work.bare-origin.git" show-ref --quiet feat/CC-9001 2>/dev/null && pushed=1
  marker_verdict="$(jq -r '.verdict // empty' "$work/.pm-dispatch-ship-finish.json" 2>/dev/null || true)"
  if [[ "$status1" -ne 0 && "$status2" -eq 0 && "$pushed" -eq 1 \
      && "$marker_verdict" == GO ]] \
      && grep -q 'reusing unchanged assessment' "$err2"; then
    pass "$name"
  else
    fail "$name" "expected retry recovery: status1=$status1 status2=$status2 pushed=$pushed marker=$marker_verdict first_err=$(cat "$err1") second_out=$(cat "$out2") second_err=$(cat "$err2")"
  fi
}

case_finish_reviewers_flag_reaches_gate_call() {
  local name="ship finish: --reviewers reaches pmctl_gate_run's argv"
  should_run "$name" || return 0
  local work
  work="$tmp_root/work-finish-reviewers"
  make_work_repo "$work" "CC-9001"
  checkout_ticket_branch "$work" "CC-9001"
  local argv_file="$tmp_root/finish-reviewers-argv"
  rm -f "$argv_file"
  bash -c '
    repo_root="$1"; work_dir="$2"; ticket_id="$3"; argv_file="$4"
    pmctl_gate_run() {
      shift
      printf "%s\n" "$@" > "$argv_file"
      local result_file
      result_file="$(mktemp)"
      printf "Final: NO-GO\n" > "$result_file"
      printf "result: %s\n" "$result_file"
      return 1
    }
    . "$repo_root/runtime/lib/pmctl-ship.sh"
    pmctl_ship_finish "$repo_root" "$work_dir" "$ticket_id" --reviewers critic,qa-tester
  ' _ "$REPO_ROOT" "$work" "CC-9001" "$argv_file" >/dev/null 2>&1 || true
  local argv
  argv="$(cat "$argv_file" 2>/dev/null)"
  if grep -q -- '--reviewers' <<<"$argv" \
      && grep -Fxq 'critic,qa-tester' <<<"$argv" \
      && grep -q -- '--policy' <<<"$argv" \
      && grep -Fxq 'maintainer' <<<"$argv"; then
    pass "$name"
  else
    fail "$name" "expected maintainer policy plus --reviewers critic,qa-tester in captured gate argv, got: $argv"
  fi
}


case_finish_no_go_does_not_push
case_finish_missing_result_file
case_finish_missing_shared_verifier_refuses_publish
case_finish_malformed_shared_assessment_refuses_publish
case_finish_go_stale_subject_does_not_push
case_finish_valid_supplied_gate_result_publishes_without_new_gate
case_finish_missing_supplied_gate_result_reports_artifact_path
case_finish_stale_supplied_gate_result_refuses_publish
case_finish_invalid_supplied_gate_result_refuses_publish
case_finish_gate_result_rejects_reviewers
case_finish_help_names_artifact_options
case_finish_go_dirty_tree_refuses_push
case_finish_dispatched_lane_auto_commits_before_gate
case_finish_manual_lane_still_refuses_on_dirty_tree_when_not_dispatched
case_finish_dispatched_lane_refuses_undeclared_collateral_file
case_finish_dispatched_lane_refuses_executor_authored_gitignore
case_finish_dispatched_lane_refuses_with_no_declared_allowlist
case_finish_dispatched_lane_bookkeeping_only_reports_explicitly_and_gates_old_head
case_finish_go_head_moved_refuses_push
case_finish_supplied_gate_result_head_moved_refuses_push
case_finish_gh_missing_refuses_before_gate_or_push
case_finish_wrong_branch_refuses_before_gate_or_push
case_finish_go_pushes_and_opens_pr
case_finish_runs_and_verifies_current_tree_full_suite_before_publish
case_finish_invalid_supplied_full_result_refuses_publish
case_finish_failed_full_suite_refuses_publish
case_finish_post_suite_head_drift_refuses_publish
case_finish_valid_supplied_full_result_publishes
case_finish_cli_forwards_full_result_option
case_finish_cli_forwards_gate_result_option
case_finish_cli_valid_gate_result_publishes
case_finish_cli_valid_full_result_publishes
case_ship_subject_fingerprint_requires_canonical_helper
case_publish_assessment_binds_closure_and_full_suite
case_publish_assessment_route_follows_reviewed_subject
case_publish_assessment_rejects_existing_destination
case_publish_assessment_and_closure_are_concurrent_no_replace
case_publish_assessment_verify_rejects_malformed_artifacts
case_targeted_closure_requires_initial_finding_ledger
case_targeted_closure_rejects_initial_subject_mismatch
case_targeted_closure_rejects_legacy_initial_without_immutable_evidence
case_targeted_closure_accepts_clean_go_with_confirmations
case_targeted_closure_accepts_uncertain_go_with_confirmation
case_ship_subject_fingerprint_matches_independent_gate_oracle
case_publish_assessment_rejects_invalid_or_mismatched_evidence
case_publish_assessment_rejects_post_build_source_mutation
case_finish_real_publish_assessment_surfaces
case_finish_real_targeted_publish_assessment_path
case_finish_real_closure_verify_accepts_producer_output
case_publish_assessment_rejects_closure_mutated_after_real_publish
case_finish_post_assessment_drift_refuses_publish
case_finish_assessment_replacement_after_verification_refuses_publish
case_finish_pushes_only_assessed_head_when_branch_advances_at_push
case_finish_gh_pr_create_runtime_failure_writes_pushed_pr_failed_marker
case_finish_pr_failure_persists_fallback_when_marker_write_fails
case_finish_go_persists_fallback_when_marker_write_fails
case_finish_go_fails_when_all_recovery_sinks_fail
case_finish_retries_after_pr_create_failure
case_finish_reviewers_flag_reaches_gate_call
case_finish_requires_ticket

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
