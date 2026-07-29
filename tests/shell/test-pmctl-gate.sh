#!/usr/bin/env bash
# Regression tests for `pmctl gate run` — routing shim that delegates to
# runtime/bin/pr-gate.sh with --cd defaulting.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PMCTL="$REPO_ROOT/cli/pmctl"

# shellcheck source=tests/lib/test-harness.sh
. "$SCRIPT_DIR/../lib/test-harness.sh"
# shellcheck source=tests/lib/test-pmctl-fixture.sh
. "$SCRIPT_DIR/../lib/test-pmctl-fixture.sh"
# shellcheck source=runtime/lib/pmctl-operation.sh
. "$REPO_ROOT/runtime/lib/pmctl-operation.sh"
# shellcheck source=runtime/lib/pmctl-dispatch.sh
. "$REPO_ROOT/runtime/lib/pmctl-dispatch.sh"
# shellcheck source=runtime/lib/gate-result-verify.sh
. "$REPO_ROOT/runtime/lib/gate-result-verify.sh"
th_init "$@"

# Isolate the detached-gate sentinel key dir for this suite's cli/pmctl fixture
# cases, mirroring tests/shell/test-gate-lifecycle.sh's isolation, so they are
# deterministic and never collide with a real gate run on this host.
_GATE_CLI_XDG_RUNTIME_DIR="$tmp_root/gate-cli-xdg-runtime"
mkdir -p "$_GATE_CLI_XDG_RUNTIME_DIR" && chmod 700 "$_GATE_CLI_XDG_RUNTIME_DIR"
_GATE_VERIFY_REPO="$tmp_root/gate-verify-repo"
_GATE_VERIFY_STATE_ROOT="$tmp_root/gate-verify-state"
mkdir -p "$_GATE_VERIFY_REPO" "$_GATE_VERIFY_STATE_ROOT"
git -C "$_GATE_VERIFY_REPO" init -q
git -C "$_GATE_VERIFY_REPO" config user.email test@example.com
git -C "$_GATE_VERIFY_REPO" config user.name "Gate Verify Test"
printf 'fixture\n' > "$_GATE_VERIFY_REPO/input.txt"
git -C "$_GATE_VERIFY_REPO" add input.txt
git -C "$_GATE_VERIFY_REPO" commit -qm fixture
git -C "$_GATE_VERIFY_REPO" branch main

# shellcheck source=runtime/lib/state-paths.sh
. "$REPO_ROOT/runtime/lib/state-paths.sh"
# shellcheck source=runtime/lib/detached-launch.sh
. "$REPO_ROOT/runtime/lib/detached-launch.sh"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Match the runtime cancellation contract: a zombie remains visible to
# `kill -0` but cannot execute and is treated as gone by
# detached_launch_verify_identity.
_gate_test_pid_stopped() {
  local pid="$1" snapshot line state=""
  snapshot="$(detached_launch_capture_identity "$pid" 2>/dev/null)" || return 0
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" == state=* ]] && state="${line#state=}"
  done <<<"$snapshot"
  [[ "$state" == Z || "$state" == X ]]
}

# Install a fake pr-gate.sh into fixture/runtime/bin that writes a structurally
# valid gate result under --run-dir (so gate_result_verify accepts it -- the
# detached wait path now requires this, per CC-423's result-integrity fix)
# and prints `result: <path>`, then exits with the given code.
_mk_fake_gate_with_result() {
  local fixture="$1" code="$2"
  mkdir -p "$fixture/runtime/bin"
  cat > "$fixture/runtime/bin/pr-gate.sh" <<FAKEGATE
#!/usr/bin/env bash
rd=""
while [[ \$# -gt 0 ]]; do
  case "\$1" in
    --run-dir) rd="\$2"; shift 2 ;;
    *) shift ;;
  esac
done
if [[ -n "\$rd" ]]; then
  mkdir -p "\$rd"
  cat > "\$rd/result.md" <<RESULT
---
gate_result_version: pr_gate_result_v1
final: $([[ $code -eq 0 ]] && printf GO || printf NO-GO)
tier: express
mode: sequential
most_severe: approve
---

# PR-Gate Result

## Gate Conclusion
Final: $([[ $code -eq 0 ]] && printf GO || printf NO-GO)
RESULT
  printf 'result: %s\n' "\$rd/result.md"
fi
exit $code
FAKEGATE
  chmod +x "$fixture/runtime/bin/pr-gate.sh"
}

# Install a fake pr-gate.sh into fixture/runtime/bin that echoes its args and
# exits with the given code.
_mk_fake_gate() {
  local fixture="$1" code="$2"
  mkdir -p "$fixture/runtime/bin"
  cat > "$fixture/runtime/bin/pr-gate.sh" <<FAKEGATE
#!/usr/bin/env bash
printf 'fake-gate-args: %s\n' "\$*"
exit $code
FAKEGATE
  chmod +x "$fixture/runtime/bin/pr-gate.sh"
}

# Copy the real pmctl-gate.sh lib into a fixture so we can drive it with a
# controlled REPO_ROOT that points at a fake gate script.
_mk_gate_wrapper() {
  local fixture="$1" out="$2"
  mkdir -p "$fixture/runtime/lib" "$fixture/runtime/bin"
  cp "$REPO_ROOT/runtime/lib/pmctl-gate.sh" "$fixture/runtime/lib/pmctl-gate.sh"
  cp "$REPO_ROOT/runtime/lib/detached-launch.sh" "$fixture/runtime/lib/detached-launch.sh"
  cat > "$out" <<WRAPPER
#!/usr/bin/env bash
set -euo pipefail
. "$fixture/runtime/lib/pmctl-gate.sh"
pmctl_gate_run "$fixture" "\$@"
WRAPPER
  chmod +x "$out"
}

# Build a fixture repo that carries the REAL cli/pmctl binary (so its own
# gate/run + gate/wait routing-table entries are exercised, not a hand-rolled
# wrapper) plus the minimal lib set gate/run and gate/wait need. cli/pmctl
# resolves REPO_ROOT from its own script location, so copying it into the
# fixture makes it treat the fixture as REPO_ROOT.
_mk_gate_cli_fixture() {
  local fixture="$1"
  mkdir -p "$fixture/runtime/bin"
  pmctl_fixture_copy_spine "$REPO_ROOT" "$fixture"
  for _lib in pmctl-gate gate-result-verify state-paths portable detached-launch; do
    cp "$REPO_ROOT/runtime/lib/$_lib.sh" "$fixture/runtime/lib/$_lib.sh"
  done
  cp "$REPO_ROOT/runtime/bin/gate-supervisor.sh" "$fixture/runtime/bin/gate-supervisor.sh"
  chmod +x "$fixture/runtime/bin/gate-supervisor.sh"
}

# ---- 1: explicit --cd is passed through unchanged ----------------------------
case_explicit_cd_passthrough() {
  # Verifies that pmctl_gate_run passes an explicit --cd value through to
  # pr-gate.sh without modification.
  #
  # Steps:
  #   1. Install a fake pr-gate.sh that echoes its argv.
  #   2. Call pmctl_gate_run with --cd /tmp and --tier express.
  #   3. Assert both flags appear in the echoed output.
  local name="gate/run: explicit --cd passed through to pr-gate.sh"
  should_run "$name" || return 0

  local fixture="$tmp_root/f1" wrapper="$tmp_root/b1/wrapper"
  mkdir -p "$(dirname "$wrapper")"
  _mk_fake_gate "$fixture" 0
  _mk_gate_wrapper "$fixture" "$wrapper"

  local out code
  set +e; out="$("$wrapper" --cd /tmp --lifecycle foreground --tier express 2>&1)"; code=$?; set -e

  if [[ "$code" -eq 0 ]] \
     && [[ "$out" == *"--cd /tmp"* ]] \
     && [[ "$out" == *"--tier express"* ]]; then
    pass "$name"
  else
    fail "$name" "code=$code out=$out"
  fi
}

case_gate_run_refreshes_context_before_dispatch() {
  # Verifies the pmctl wrapper refreshes generic repo context before launching
  # pr-gate, while the gate implementation remains unaware of sqlite/content.
  # Steps: inject a refresh stub that records its repo, run a foreground fake
  # gate, and assert refresh ordering/diagnostic plus unchanged gate argv.
  local name="gate/run: refreshes pmctl context before repo-agnostic pr-gate dispatch"
  should_run "$name" || return 0
  local fixture="$tmp_root/gate-context-fixture" wrapper="$tmp_root/gate-context-wrapper" marker="$tmp_root/gate-context-marker"
  local target="$tmp_root/gate-context-target" out code=0
  mkdir -p "$fixture/runtime/lib" "$target"
  git -C "$target" init -q
  _mk_fake_gate "$fixture" 0
  cp "$REPO_ROOT/runtime/lib/pmctl-gate.sh" "$fixture/runtime/lib/pmctl-gate.sh"
  cat > "$wrapper" <<WRAPPER
#!/usr/bin/env bash
set -euo pipefail
. "$fixture/runtime/lib/pmctl-gate.sh"
pmctl_context_workflow_refresh() {
  printf '%s\n' "\$1" > "$marker"
  jq -cn --arg repo "\$1" --arg db "\$1/.pm-dispatch/ctx/context.db" '{refresh_status:"refreshed",freshness:"fresh",resolved_repo_root:\$repo,db_path:\$db}'
}
pmctl_gate_run "$fixture" "\$@"
WRAPPER
  chmod +x "$wrapper"
  out="$("$wrapper" --cd "$target" --lifecycle foreground --tier express 2>&1)" || code=$?
  if [[ "$code" -eq 0 && "$(<"$marker")" == "$target" ]] \
    && [[ "$out" == *"pmctl gate context: status=refreshed repo=$target db=$target/.pm-dispatch/ctx/context.db"* ]] \
    && [[ "$out" == *"fake-gate-args:"*"--cd $target"*"--tier express"* ]]; then
    pass "$name"
  else
    fail "$name" "code=$code marker=$(cat "$marker" 2>/dev/null || true) out=$out"
  fi
}

# ---- 2: missing --cd defaults to the CWD git toplevel (then $PWD) ------------
case_default_cd_injected() {
  # Verifies that pmctl_gate_run derives --cd from the caller's CWD when
  # omitted: the git toplevel when inside a worktree (so a run launched from
  # a repo subdir lands in the same partition a wait from the repo root
  # recomputes), falling back to $PWD outside any git repo.
  #
  # Steps:
  #   1. Install a fake pr-gate.sh that echoes its argv.
  #   2. Call pmctl_gate_run without --cd from a git repo SUBDIR; assert the
  #      echoed --cd is the repo toplevel, not the subdir.
  #   3. Call it again from a non-git directory; assert --cd is that $PWD.
  local name="gate/run: --cd defaults to CWD git toplevel, \$PWD outside git"
  should_run "$name" || return 0

  local fixture="$tmp_root/f2" wrapper="$tmp_root/b2/wrapper"
  mkdir -p "$(dirname "$wrapper")"
  _mk_fake_gate "$fixture" 0
  _mk_gate_wrapper "$fixture" "$wrapper"

  local gitrepo="$tmp_root/f2-gitrepo" nongit="$tmp_root/f2-nongit"
  mkdir -p "$gitrepo/subdir" "$nongit"
  git -C "$gitrepo" init -q

  local expected_toplevel out code
  expected_toplevel="$(git -C "$gitrepo/subdir" rev-parse --show-toplevel)"
  set +e
  out="$(cd "$gitrepo/subdir" && "$wrapper" --lifecycle foreground --tier express 2>&1)"
  code=$?
  set -e
  if [[ "$code" -ne 0 ]] || [[ "$out" != *"--cd $expected_toplevel"* ]]; then
    fail "$name" "git subdir: code=$code out=$out (expected --cd $expected_toplevel)"
    return
  fi

  local expected_pwd out2 code2
  set +e
  out2="$(cd "$nongit" && "$wrapper" --lifecycle foreground --tier express 2>&1)"
  code2=$?
  expected_pwd="$(cd "$nongit" && pwd)"
  set -e
  if [[ "$code2" -eq 0 ]] && [[ "$out2" == *"--cd $expected_pwd"* ]]; then
    pass "$name"
  else
    fail "$name" "non-git: code=$code2 out=$out2 (expected --cd $expected_pwd)"
  fi
}

# ---- 3: non-zero exit from pr-gate.sh is propagated --------------------------
case_exit_propagated() {
  # Verifies that pmctl_gate_run propagates the exit code from pr-gate.sh
  # so callers can detect gate failures without parsing output.
  #
  # Steps:
  #   1. Install a fake pr-gate.sh that exits 2.
  #   2. Call pmctl_gate_run with --cd /tmp.
  #   3. Assert the wrapper exits with the same code (2).
  local name="gate/run: non-zero exit from pr-gate.sh is propagated"
  should_run "$name" || return 0

  local fixture="$tmp_root/f3" wrapper="$tmp_root/b3/wrapper"
  mkdir -p "$(dirname "$wrapper")"
  _mk_fake_gate "$fixture" 2
  _mk_gate_wrapper "$fixture" "$wrapper"

  local code
  set +e; "$wrapper" --cd /tmp --lifecycle foreground >/dev/null 2>&1; code=$?; set -e

  if [[ "$code" -eq 2 ]]; then
    pass "$name"
  else
    fail "$name" "expected exit 2, got $code"
  fi
}

# ---- 4: gate script not found exits 2 ----------------------------------------
case_missing_gate_script() {
  # Verifies that pmctl_gate_run exits 2 with an error message when
  # runtime/bin/pr-gate.sh is absent from the fixture repo root, so the failure
  # is explicit rather than a confusing exec error.
  #
  # Steps:
  #   1. Create a fixture with the pmctl-gate.sh lib but no pr-gate.sh.
  #   2. Call the wrapper with --cd /tmp.
  #   3. Assert exit code is 2 and stderr contains "not found" or "not executable".
  local name="gate/run: missing pr-gate.sh exits 2"
  should_run "$name" || return 0

  local fixture="$tmp_root/f4" wrapper="$tmp_root/b4/wrapper"
  mkdir -p "$(dirname "$wrapper")" "$fixture/runtime/lib"
  cp "$REPO_ROOT/runtime/lib/pmctl-gate.sh" "$fixture/runtime/lib/pmctl-gate.sh"
  cat > "$wrapper" <<WRAPPER
#!/usr/bin/env bash
set -euo pipefail
. "$fixture/runtime/lib/pmctl-gate.sh"
pmctl_gate_run "$fixture" "\$@"
WRAPPER
  chmod +x "$wrapper"

  local err code
  set +e; err="$("$wrapper" --cd /tmp 2>&1)"; code=$?; set -e

  if [[ "$code" -eq 2 ]] && [[ "$err" == *"not found"* || "$err" == *"not executable"* ]]; then
    pass "$name"
  else
    fail "$name" "code=$code err=$err"
  fi
}

# ---- 4b: --cd with no value is a usage error, not "use $PWD" ----------------
case_cd_missing_value_rejected() {
  # CC-423 pr-gate finding (critic/qa-tester, high): the --cd extraction loop
  # only checked array bounds, not whether --cd actually had a following
  # value, so a trailing `--cd` (or `--cd` immediately followed by another
  # flag, which is what remains after --lifecycle is stripped) silently fell
  # back to $PWD instead of erroring. Under the default (detached) lifecycle
  # this meant a malformed `pmctl gate run --cd --lifecycle detached` still
  # returned a "successful" gate_id for a supervisor launched against the
  # wrong directory. Both lifecycles must reject it explicitly.
  local name="gate/run: --cd with no value is rejected (exit 2)"
  should_run "$name" || return 0

  local fixture="$tmp_root/f4b"
  _mk_fake_gate "$fixture" 0

  local wrapper="$tmp_root/b4b/wrapper"
  mkdir -p "$(dirname "$wrapper")"
  _mk_gate_wrapper "$fixture" "$wrapper"

  local err code
  set +e; err="$("$wrapper" --cd 2>&1)"; code=$?; set -e
  if [[ "$code" -ne 2 ]] || [[ "$err" != *"missing value for --cd"* ]]; then
    fail "$name" "foreground (default detached, bare --cd): code=$code err=$err"
    return
  fi

  set +e; err="$("$wrapper" --lifecycle foreground --cd 2>&1)"; code=$?; set -e
  if [[ "$code" -ne 2 ]] || [[ "$err" != *"missing value for --cd"* ]]; then
    fail "$name" "explicit foreground, bare --cd: code=$code err=$err"
    return
  fi

  set +e; err="$("$wrapper" --lifecycle detached --cd 2>&1)"; code=$?; set -e
  if [[ "$code" -ne 2 ]] || [[ "$err" != *"missing value for --cd"* ]]; then
    fail "$name" "explicit detached, bare --cd: code=$code err=$err"
    return
  fi

  pass "$name"
}

# ---- 5: pmctl binary routes gate/run without error ---------------------------
case_pmctl_routing() {
  # Verifies that the top-level cli/pmctl binary recognises the gate/run
  # subcommand and delegates to runtime/bin/pr-gate.sh, confirming the routing
  # table entry and lib load are both present.
  #
  # Steps:
  #   1. Call pmctl gate run --lifecycle foreground --help against the real
  #      repo binary (foreground forced explicitly: default lifecycle is
  #      detached (CC-423), which would fork a real background supervisor
  #      instead of forwarding --help synchronously).
  #   2. Assert exit code is 0 (pr-gate.sh --help exits 0).
  #   3. Assert stdout contains "--cd" (confirming pr-gate.sh usage was reached).
  local name="gate/run: pmctl cli routes gate/run subcommand"
  should_run "$name" || return 0

  local out code
  set +e; out="$("$PMCTL" gate run --lifecycle foreground --help 2>&1)"; code=$?; set -e

  if [[ "$code" -eq 0 ]] && [[ "$out" == *"--cd"* ]]; then
    pass "$name"
  else
    fail "$name" "code=$code out=$(printf '%s' "$out" | head -3)"
  fi
}

# ---- 5b: --help stays synchronous even with the default (detached) lifecycle
case_help_bypasses_detached_default() {
  # CC-423 pr-gate finding (critic, medium): flipping the default lifecycle
  # to detached silently turned `pmctl gate run --help` (no --lifecycle flag)
  # into a detached launch instead of synchronous usage output. Verifies the
  # fix: -h/--help always forwards synchronously regardless of lifecycle.
  local name="gate/run: --help forwards synchronously under the default (detached) lifecycle"
  should_run "$name" || return 0

  local out code
  set +e; out="$("$PMCTL" gate run --help 2>&1)"; code=$?; set -e

  if [[ "$code" -eq 0 ]] && [[ "$out" == *"--cd"* ]] && [[ "$out" != gate-* ]]; then
    pass "$name"
  else
    fail "$name" "code=$code out=$(printf '%s' "$out" | head -3) (expected synchronous usage text, not a bare gate_id)"
  fi
}

# Write a structurally valid pr_gate_result_v1 file. Optional overrides:
#   $2 body Final: value (default GO)   $3 frontmatter final: value (default = $2)
_mk_gate_result() {
  local path="$1" body_final="${2:-GO}" fm_final="${3:-${2:-GO}}"
  mkdir -p "$(dirname "$path")"
  cat > "$path" <<RESULT
---
gate_result_version: pr_gate_result_v1
final: ${fm_final}
tier: express
mode: sequential
most_severe: approve
---

# PR-Gate Result

## stub-reviewer -- approve
- ok

## Gate Conclusion
Final: ${body_final}
RESULT
}

_mk_gate_result_v2() {
  local path="$1" result_sha
  _mk_gate_result "$path" GO
  sed -i \
    -e 's/^gate_result_version: pr_gate_result_v1$/gate_result_version: pr_gate_result_v2/' \
    -e '/^gate_result_version:/a gate_assurance: result.md.assurance.json' \
    "$path"
  result_sha="$(sha256sum "$path" | awk '{print $1}')"
  jq -n --arg result_sha "$result_sha" '{
    kind:"gate_assurance_v2",
    schema_version:2,
    result:{final:"GO"},
    bindings:{
      result_sha256:$result_sha,
      repo_root:"/tmp/repo",
      repo_identity:("b" * 64),
      base_commit:("c" * 40),
      head_commit:("d" * 40),
      subject_fingerprint:("e" * 64)
    },
    coordinates:{
      tier:{requested:"auto",resolved:"express",evidence_floor:"reviewer-verdicts"},
      mode:{requested:"default",resolved:"sequential",topology:"combined-session",synthesis:"inline"},
      pass:{requested:"initial",resolved:"initial",scope:"comprehensive",initial_result:null},
      coverage:{requested:null,selected:["critic","qa-tester"],skipped:[],
        vocabulary:["critic","qa-tester"]},
      independence:{implementation_context_isolated:null,
        reviewer_topology:"combined-session",per_reviewer_independent:null,
        evidence_status:"unavailable"}
    },
    policy:{
      kind:"gate_policy_resolution_v1",
      schema_version:1,
      consumer_policy:"generic",
      policy_source:"canonical",
      scope_fingerprint:("f" * 64),
      request:{tier:"auto",mode:"default",pass_kind:"initial",reviewers:null},
      classification:{
        architecture_impact:"unknown",
        line_changes:1,
        binary_or_unknown_count:0,
        layer_roots:[]
      },
      resolution:{
        minimum_tier:"express",
        required_reviewers:["critic","qa-tester"],
        recommended_mode:"sequential",
        mode_selection_source:"policy",
        mode_recommendation_overridden:false,
        downgrade_requested:false,
        downgrade_allowed:false
      },
      matched_signals:[
        {
          id:"consumer-policy",
          source:"consumer-policy",
          matches:["generic:initial"],
          minimum_tier:"express",
          required_reviewers:["critic","qa-tester"],
          recommended_mode:"sequential"
        },
        {
          id:"docs-only",
          source:"classification",
          matches:["README.md"],
          minimum_tier:"express",
          required_reviewers:[],
          recommended_mode:"sequential"
        }
      ],
      resolved:{
        tier:"express",
        mode:"sequential",
        reviewers:["critic","qa-tester"]
      },
      enforcement:{status:"pass",violations:[]},
      override:{
        status:"not_provided",source:null,sha256:null,reason:null,approver:null
      },
      reviewer_override:{status:"not_provided",source:null,sha256:null}
    },
    dispatch:{outcomes:[{role:"combined",reviewer:null,status:"passed",
      run_id:null,evidence_status:"unavailable"}]},
    provenance:{producer:"pr-gate.sh",policy_source:"canonical",attestation:null}
  }' > "${path}.assurance.json"
}

_mk_gate_result_v2_verified() {
  local path="$1" bound_repo="${2:-/tmp/repo}" sidecar="${1}.assurance.json"
  local result_parent run_root project_dir attestation assurance_sha
  _mk_gate_result_v2 "$path"
  result_parent="$(dirname "$path")"
  run_root="$(dirname "$result_parent")"
  project_dir="$(dirname "$(dirname "$run_root")")"
  attestation="$run_root/gate-assurance-20260727-000000.attestation.json"
  mkdir -p "$run_root/.agent-trace" "$project_dir"
  printf 'trace\n' > "$run_root/.agent-trace/test.last"
  jq --arg bound_repo "$bound_repo" '
    .bindings.repo_root = $bound_repo |
    .coordinates.independence = {
      implementation_context_isolated:true,
      reviewer_topology:"combined-session",
      per_reviewer_independent:false,
      evidence_status:"verified"
    } |
    .dispatch.outcomes = [{
      role:"combined",reviewer:null,status:"passed",
      run_id:"run-20260727T000000Z-aaaaaa",evidence_status:"verified"
    }] |
    .provenance.attestation = "gate-assurance-20260727-000000.attestation.json"
  ' "$sidecar" > "${sidecar}.tmp"
  mv "${sidecar}.tmp" "$sidecar"
  jq -nc --arg trace "$run_root/.agent-trace/test.last" \
    --arg bound_repo "$bound_repo" '{
    schema_version:3,id:"run-20260727T000000Z-aaaaaa",task_id:"UNKN-0",
    executor:"codex",state:"ok",exit_code:0,model:"default",
    brief_file:"/tmp/brief.md",working_dir:$bound_repo,trace_path:$trace,
    created_ts:"2026-07-27T00:00:00Z",operation_id:"op-20260727T000000Z-aaaaaa"
  }' > "$project_dir/runs.jsonl"
  assurance_sha="$(sha256sum "$sidecar" | awk '{print $1}')"
  jq -n --arg assurance_sha "$assurance_sha" --slurpfile a "$sidecar" '
    $a[0] as $sidecar | {
      kind:"gate_assurance_attestation_v1",
      schema_version:1,
      result_sha256:$sidecar.bindings.result_sha256,
      assurance_sha256:$assurance_sha,
      repo_root:$sidecar.bindings.repo_root,
      repo_identity:$sidecar.bindings.repo_identity,
      base_commit:$sidecar.bindings.base_commit,
      head_commit:$sidecar.bindings.head_commit,
      subject_fingerprint:$sidecar.bindings.subject_fingerprint,
      run_ids:[$sidecar.dispatch.outcomes[].run_id]
    }
  ' > "$attestation"
}

_mk_gate_result_v3_verified() {
  local path="$1" bound_repo="${2:-$_GATE_VERIFY_REPO}"
  local base_ref="${3:-main}" sidecar="${1}.assurance.json"
  local result_parent run_root
  local created initial subject
  _mk_gate_result_v2_verified "$path" "$bound_repo"
  result_parent="$(dirname "$path")"
  run_root="$(dirname "$result_parent")"
  created="2026-07-27T00:00:00Z"
  initial="$(
    gate_subject_snapshot "$bound_repo" "$base_ref" HEAD committed_head \
      require_clean "$created"
  )"
  subject="$(jq -nc --argjson initial "$initial" '{
    kind:"gate_subject_v1",
    schema_version:1,
    repository:$initial.repository,
    observed:$initial.observed,
    base:$initial.base,
    head:$initial.head,
    tree_fingerprint:$initial.tree_fingerprint,
    subject_kind:$initial.subject_kind,
    dirty_policy:$initial.dirty_policy,
    created_at:$initial.captured_at,
    finished_at:$initial.captured_at,
    observed_at_finish:{
      repository_key:$initial.repository.key,
      base_commit:$initial.base.commit,
      head_commit:$initial.head.commit,
      tree_fingerprint:$initial.tree_fingerprint
    }
  }')"
  jq --argjson subject "$subject" '
    .kind = "gate_assurance_v3" |
    .schema_version = 3 |
    .bindings.repo_identity = $subject.repository.key |
    .bindings.base_commit = $subject.base.commit |
    .bindings.head_commit = $subject.head.commit |
    .bindings.subject_fingerprint = $subject.tree_fingerprint |
    .subject = $subject |
    .evidence = {
      preflight:{
        status:"not_run",outcome:null,artifact:null,sha256:null,
        subject_fingerprint:null
      },
      scope_manifest:{
        status:"unavailable",artifact:null,sha256:null,subject_fingerprint:null
      },
      closure:{
        status:"unavailable",artifact:null,sha256:null,subject_fingerprint:null
      }
    }
  ' "$sidecar" > "${sidecar}.tmp"
  mv "${sidecar}.tmp" "$sidecar"
  _attach_gate_scope_manifest_v3 "$path"
  _refresh_gate_result_v3_attestation "$path"
}

_attach_gate_scope_manifest_v3() {
  local path="$1" sidecar="${1}.assurance.json"
  local manifest manifest_digest manifest_sha
  manifest="$(dirname "$path")/gate-scope-manifest-fixture.json"
  jq -n --slurpfile assurance "$sidecar" '
    $assurance[0].subject as $subject | {
      kind:"gate_scope_manifest_v1",
      schema_version:1,
      status:"complete",
      subject:{
        repository_key:$subject.repository.key,
        base_commit:$subject.base.commit,
        head_commit:$subject.head.commit,
        tree_fingerprint:$subject.tree_fingerprint,
        subject_kind:$subject.subject_kind
      },
      selection:{
        diff_kind:(
          if $subject.subject_kind == "fixed_ref" then "fixed-head"
          elif $subject.subject_kind == "working_tree" then "working-tree"
          else "committed"
          end
        ),
        base_ref:$subject.base.ref,
        head_ref:$subject.head.ref,
        include_untracked:($subject.subject_kind == "working_tree")
      },
      changes:{
        entries:[{
          status:"modified",
          old_path:null,
          new_path:"README.md",
          similarity:null
        }],
        changed_paths:["README.md"],
        renamed_paths:[],
        untracked_paths:[]
      },
      diff:{
        hunks:[{
          path:"README.md",
          source:"tracked",
          old_start:1,
          old_lines:1,
          new_start:1,
          new_lines:1,
          header:"@@ -1 +1 @@"
        }],
        binary_or_special_paths:[]
      },
      paired_tests:[],
      sensitive_signals:[],
      flags:{
        public_interface:{matched:true,paths:["README.md"]},
        schema:{matched:false,paths:[]},
        config:{matched:false,paths:[]},
        install:{matched:false,paths:[]},
        ci:{matched:false,paths:[]},
        release:{matched:false,paths:[]},
        migration:{matched:false,paths:[]}
      },
      expansion:{
        claim:"bounded-hints-not-complete-call-graph",
        entries:[],
        included_paths:[]
      },
      truncation:{
        occurred:false,
        budgets:{
          diff_hunks:512,
          expansion_source_paths:256,
          symbols_per_source:1024,
          matches_per_query:64,
          expansion_entries:512
        },
        omitted:{
          diff_hunks:0,
          expansion_source_paths:0,
          symbols_per_source:0,
          matches_per_query:0,
          expansion_entries:0
        },
        reasons:[],
        acceptance:{required:false,accepted:false,source:null}
      },
      content:{
        digest_algorithm:"sha256-canonical-json-without-content-digest",
        digest:""
      }
    }
  ' > "${manifest}.tmp"
  manifest_digest="$(jq -cS 'del(.content.digest)' "${manifest}.tmp" \
    | sha256sum | awk '{print $1}')"
  jq --arg digest "$manifest_digest" '.content.digest = $digest' \
    "${manifest}.tmp" > "$manifest"
  rm -f "${manifest}.tmp"
  manifest_sha="$(sha256sum "$manifest" | awk '{print $1}')"
  jq --arg artifact "$(basename "$manifest")" \
    --arg sha "$manifest_sha" '
      .evidence.scope_manifest = {
        status:"verified",
        artifact:$artifact,
        sha256:$sha,
        subject_fingerprint:.subject.tree_fingerprint
      }
    ' "$sidecar" > "${sidecar}.tmp"
  mv "${sidecar}.tmp" "$sidecar"
}

_refresh_gate_result_v3_attestation() {
  local path="$1" sidecar="${1}.assurance.json"
  local run_root attestation assurance_sha subject_sha
  run_root="$(dirname "$(dirname "$path")")"
  attestation="$run_root/gate-assurance-20260727-000000.attestation.json"
  assurance_sha="$(sha256sum "$sidecar" | awk '{print $1}')"
  subject_sha="$(jq -cS '.subject' "$sidecar" | sha256sum | awk '{print $1}')"
  jq -n --arg assurance_sha "$assurance_sha" --arg subject_sha "$subject_sha" \
    --slurpfile a "$sidecar" '
    $a[0] as $sidecar | {
      kind:"gate_assurance_attestation_v2",
      schema_version:2,
      result_sha256:$sidecar.bindings.result_sha256,
      assurance_sha256:$assurance_sha,
      repo_root:$sidecar.bindings.repo_root,
      repo_identity:$sidecar.bindings.repo_identity,
      base_commit:$sidecar.bindings.base_commit,
      head_commit:$sidecar.bindings.head_commit,
      subject_fingerprint:$sidecar.bindings.subject_fingerprint,
      repository_key:$sidecar.subject.repository.key,
      subject_sha256:$subject_sha,
      run_ids:[$sidecar.dispatch.outcomes[].run_id]
    }
  ' > "$attestation"
}

_gate_verify_result_path() {
  local slug="$1" run_root
  run_root="$(
    PM_DISPATCH_STATE_ROOT="$_GATE_VERIFY_STATE_ROOT" \
      _SW_REPO_ROOT="$_GATE_VERIFY_REPO" \
      sw_project_run_dir "gate-$slug"
  )"
  printf '%s/.gate-results/result.md\n' "$run_root"
}

_run_canonical_gate_verify() {
  local result="$1"; shift
  (
    cd "$_GATE_VERIFY_REPO"
    PM_DISPATCH_STATE_ROOT="$_GATE_VERIFY_STATE_ROOT" \
      "$PMCTL" gate verify "$result" "$@"
  )
}

_mk_gate_result_v2_legacy_assurance() {
  local path="$1" sidecar="${1}.assurance.json"
  _mk_gate_result_v2 "$path"
  jq '
    .kind = "gate_assurance_v1" |
    .schema_version = 1 |
    del(.bindings, .policy) |
    .coordinates.independence = {
      implementation_context_isolated:true,
      reviewer_topology:"combined-session",
      per_reviewer_independent:false,
      evidence_status:"verified"
    } |
    .dispatch.outcomes = [{
      role:"combined",reviewer:null,status:"passed",
      run_id:"run-20260727T000000Z-aaaaaa",evidence_status:"verified"
    }] |
    .provenance = {producer:"pr-gate.sh",policy_source:"canonical"}
  ' "$sidecar" > "${sidecar}.tmp"
  mv "${sidecar}.tmp" "$sidecar"
}

# ---- 6: gate verify accepts a structurally valid result ----------------------
case_verify_valid() {
  local name="gate/verify: valid result exits 0"
  should_run "$name" || return 0
  local result="$tmp_root/v6/result.md"
  _mk_gate_result "$result" GO
  local out code
  set +e; out="$("$PMCTL" gate verify "$result" 2>&1)"; code=$?; set -e
  if [[ "$code" -eq 0 ]] && [[ "$out" == *"gate result OK"* ]] \
      && [[ "$out" == *"assurance: unavailable"* ]]; then
    pass "$name"
  else
    fail "$name" "code=$code out=$out"
  fi
}

case_verify_v2_assurance() {
  local name="gate/verify: v2 machine assurance exits 0"
  should_run "$name" || return 0
  local result="$tmp_root/v2-assurance/result.md" out code
  _mk_gate_result_v2 "$result"
  set +e; out="$("$PMCTL" gate verify "$result" 2>&1)"; code=$?; set -e
  if [[ "$code" -eq 0 && "$out" == *"assurance: verified"* \
      && "$out" == *"assurance file:"* ]]; then
    pass "$name"
  else
    fail "$name" "code=$code out=$out"
  fi
}

case_verify_v2_without_policy_remains_readable() {
  local name="gate/verify: pre-policy v2 assurance remains readable"
  should_run "$name" || return 0
  local result="$tmp_root/v2-pre-policy/result.md" out code
  _mk_gate_result_v2 "$result"
  jq 'del(.policy)' "${result}.assurance.json" > "${result}.assurance.tmp"
  mv "${result}.assurance.tmp" "${result}.assurance.json"
  set +e; out="$("$PMCTL" gate verify "$result" 2>&1)"; code=$?; set -e
  if [[ "$code" -eq 0 && "$out" == *"assurance: verified"* ]]; then
    pass "$name"
  else
    fail "$name" "code=$code out=$out"
  fi
}

case_verify_v2_named_consumer_is_not_authorizing() {
  local name="gate/verify: v2 named consumer reports applicability unavailable"
  should_run "$name" || return 0
  local result="$tmp_root/v2-named-consumer/result.md" out code
  _mk_gate_result_v2 "$result"
  set +e
  out="$("$PMCTL" gate verify "$result" --consumer embedded --json 2>&1)"
  code=$?
  set -e
  if [[ "$code" -eq 1 ]] && jq -e '
      .axes.artifact_valid.status == "pass" and
      .axes.policy_applicable.status == "unavailable" and
      (.axes.policy_applicable.reason_codes |
        index("consumer_applicability_unavailable")) != null
    ' <<<"$out" >/dev/null; then
    pass "$name"
  else
    fail "$name" "code=$code out=$out"
  fi
}

case_verify_v2_canonical_authorization() {
  local name="gate/verify: v2 protected attestation and canonical runs exit 0"
  should_run "$name" || return 0
  local result
  local out code
  result="$(_gate_verify_result_path auth)"
  _mk_gate_result_v2_verified "$result" "$_GATE_VERIFY_REPO"
  set +e; out="$(_run_canonical_gate_verify "$result" 2>&1)"; code=$?; set -e
  if [[ "$code" -eq 0 && "$out" == *"assurance: verified"* ]]; then
    pass "$name"
  else
    fail "$name" "code=$code out=$out"
  fi
}

case_verify_v3_three_axes_current() {
  # Behavior: a current immutable subject with verified generic review evidence
  # passes all three independently reported axes.
  local name="gate/verify: v3 current generic artifact passes all three JSON axes"
  should_run "$name" || return 0
  local result out code
  result="$(_gate_verify_result_path v3-current)"
  _mk_gate_result_v3_verified "$result" "$_GATE_VERIFY_REPO"
  set +e
  out="$(_run_canonical_gate_verify "$result" --consumer generic --json 2>&1)"
  code=$?
  set -e
  if [[ "$code" -eq 0 ]] \
      && jq -e '
        .kind == "gate_verification_v1" and
        .assurance.kind == "gate_assurance_v3" and
        .axes.artifact_valid.status == "pass" and
        .axes.subject_current.status == "pass" and
        .axes.policy_applicable.status == "pass" and
        .axes.policy_applicable.required_policy == "generic"
      ' <<<"$out" >/dev/null; then
    pass "$name"
  else
    fail "$name" "code=$code out=$out"
  fi
}

case_verify_v3_producer_drift_reason_codes() {
  local name="gate/verify: v3 producer-finish drift reasons are observable"
  should_run "$name" || return 0
  local field reason value result sidecar out code slug
  while IFS='|' read -r field reason; do
    slug="${field//_/-}"
    result="$(_gate_verify_result_path "v3-producer-$slug")"
    sidecar="${result}.assurance.json"
    _mk_gate_result_v3_verified "$result" "$_GATE_VERIFY_REPO"
    case "$field" in
      repository_key|tree_fingerprint) value="$(printf '%064d' 0)" ;;
      base_commit|head_commit) value="$(printf '%040d' 0)" ;;
    esac
    jq --arg field "$field" --arg value "$value" \
      '.subject.observed_at_finish[$field] = $value' \
      "$sidecar" > "${sidecar}.tmp"
    mv "${sidecar}.tmp" "$sidecar"
    _refresh_gate_result_v3_attestation "$result"
    set +e
    out="$(_run_canonical_gate_verify "$result" --consumer generic --json 2>&1)"
    code=$?
    set -e
    if [[ "$code" -ne 1 ]] || ! jq -e --arg reason "$reason" '
        .axes.artifact_valid.status == "pass" and
        .axes.subject_current.status == "fail" and
        (.axes.subject_current.reason_codes | index($reason)) != null
      ' <<<"$out" >/dev/null; then
      fail "$name" "$field code=$code out=$out"
      return
    fi
  done <<'CASES'
repository_key|producer_repository_drift
base_commit|producer_base_drift
head_commit|producer_head_drift
tree_fingerprint|producer_tree_drift
CASES
  pass "$name"
}

case_verify_v3_policy_reason_codes() {
  local name="gate/verify: v3 policy-applicability failure reasons are covered"
  should_run "$name" || return 0
  local result sidecar fixture mutation reason consumer axis
  result="$(_gate_verify_result_path v3-policy-reasons)"
  sidecar="${result}.assurance.json"
  _mk_gate_result_v3_verified "$result" "$_GATE_VERIFY_REPO"
  while IFS='|' read -r mutation reason consumer; do
    fixture="$tmp_root/policy-reason-${reason}.json"
    case "$mutation" in
      verdict)
        jq '.result.final = "NO-GO"' "$sidecar" > "$fixture"
        ;;
      no-policy)
        jq 'del(.policy)' "$sidecar" > "$fixture"
        ;;
      enforcement)
        jq '.policy.enforcement.status = "fail"' "$sidecar" > "$fixture"
        ;;
      independence)
        jq '.coordinates.independence.evidence_status = "unavailable"' \
          "$sidecar" > "$fixture"
        ;;
      dispatch)
        jq '.dispatch.outcomes[0].run_id = null' "$sidecar" > "$fixture"
        ;;
      closure)
        jq '.policy.consumer_policy = "maintainer"' "$sidecar" > "$fixture"
        ;;
      scope)
        jq '.evidence.scope_manifest = {
          status:"unavailable",
          artifact:null,
          sha256:null,
          subject_fingerprint:null
        }' "$sidecar" > "$fixture"
        ;;
    esac
    axis="$(
      gate_policy_applicability_assess "$fixture" "$consumer" verified
    )"
    if ! jq -e --arg reason "$reason" '
        .status == "fail" and (.reason_codes | index($reason)) != null
      ' <<<"$axis" >/dev/null; then
      fail "$name" "$mutation axis=$axis"
      return
    fi
    if [[ "$consumer" == publish ]] && ! jq -e '
        .consumer == "publish" and .required_policy == "maintainer" and
        .embedded_policy == "maintainer"
      ' <<<"$axis" >/dev/null; then
      fail "$name" "publish policy mapping is not self-describing: $axis"
      return
    fi
  done <<'CASES'
verdict|verdict_not_go|generic
no-policy|policy_resolution_unavailable|generic
enforcement|policy_enforcement_failed|generic
independence|review_independence_unverified|generic
dispatch|review_dispatch_evidence_incomplete|generic
scope|scope_manifest_unavailable|generic
closure|closure_evidence_unavailable|publish
CASES
  pass "$name"
}

case_verify_v3_dirty_drift_is_stale_not_invalid() {
  # Behavior: post-finalization working-tree drift keeps result/sidecar integrity
  # valid but makes the committed-head subject stale.
  local name="gate/verify: v3 dirty drift is subject fail while artifact stays valid"
  should_run "$name" || return 0
  local result out code
  result="$(_gate_verify_result_path v3-dirty)"
  _mk_gate_result_v3_verified "$result" "$_GATE_VERIFY_REPO"
  printf 'dirty\n' > "$_GATE_VERIFY_REPO/untracked.txt"
  set +e
  out="$(_run_canonical_gate_verify "$result" --consumer generic --json 2>&1)"
  code=$?
  set -e
  rm -f "$_GATE_VERIFY_REPO/untracked.txt"
  if [[ "$code" -eq 1 ]] \
      && jq -e '
        .axes.artifact_valid.status == "pass" and
        .axes.subject_current.status == "fail" and
        (.axes.subject_current.reason_codes | index("tree_drift")) != null
      ' <<<"$out" >/dev/null; then
    pass "$name"
  else
    fail "$name" "code=$code out=$out"
  fi
}

case_verify_v3_head_moved_is_stale() {
  # Behavior: moving HEAD after finalization is freshness failure, not artifact
  # forgery. Restore the disposable fixture ref after the assertion.
  local name="gate/verify: v3 moved HEAD reports head_moved without invalidating artifact"
  should_run "$name" || return 0
  local result out code old_head
  result="$(_gate_verify_result_path v3-head-moved)"
  _mk_gate_result_v3_verified "$result" "$_GATE_VERIFY_REPO"
  old_head="$(git -C "$_GATE_VERIFY_REPO" rev-parse HEAD)"
  printf 'moved\n' > "$_GATE_VERIFY_REPO/input.txt"
  git -C "$_GATE_VERIFY_REPO" add input.txt
  git -C "$_GATE_VERIFY_REPO" commit -qm moved
  set +e
  out="$(_run_canonical_gate_verify "$result" --consumer generic --json 2>&1)"
  code=$?
  set -e
  git -C "$_GATE_VERIFY_REPO" reset --hard -q "$old_head"
  if [[ "$code" -eq 1 ]] \
      && jq -e '
        .axes.artifact_valid.status == "pass" and
        (.axes.subject_current.reason_codes | index("head_moved")) != null
      ' <<<"$out" >/dev/null; then
    pass "$name"
  else
    fail "$name" "code=$code out=$out"
  fi
}

case_verify_v3_base_advanced_is_stale() {
  # Behavior: advancing the named base ref without moving the reviewed HEAD
  # reports base_advanced and keeps the artifact digest valid.
  local name="gate/verify: v3 advanced base is stale rather than invalid"
  should_run "$name" || return 0
  local result out code old_base tree new_base
  result="$(_gate_verify_result_path v3-base-advanced)"
  _mk_gate_result_v3_verified "$result" "$_GATE_VERIFY_REPO"
  old_base="$(git -C "$_GATE_VERIFY_REPO" rev-parse refs/heads/main)"
  tree="$(git -C "$_GATE_VERIFY_REPO" rev-parse 'HEAD^{tree}')"
  new_base="$(printf 'base advance\n' \
    | git -C "$_GATE_VERIFY_REPO" commit-tree "$tree" -p "$old_base")"
  git -C "$_GATE_VERIFY_REPO" update-ref refs/heads/main "$new_base"
  set +e
  out="$(_run_canonical_gate_verify "$result" --consumer generic --json 2>&1)"
  code=$?
  set -e
  git -C "$_GATE_VERIFY_REPO" update-ref refs/heads/main "$old_base"
  if [[ "$code" -eq 1 ]] \
      && jq -e '
        .axes.artifact_valid.status == "pass" and
        (.axes.subject_current.reason_codes | index("base_advanced")) != null
      ' <<<"$out" >/dev/null; then
    pass "$name"
  else
    fail "$name" "code=$code out=$out"
  fi
}

case_verify_v3_fixed_ref_ignores_working_tree() {
  # Behavior: a fixed-ref subject is immutable and deliberately ignores
  # unrelated working-tree dirt while still binding repository/base/head.
  local name="gate/verify: v3 fixed ref remains current across working-tree dirt"
  should_run "$name" || return 0
  local result sidecar snapshot subject out code
  result="$(_gate_verify_result_path v3-fixed-ref)"
  sidecar="${result}.assurance.json"
  _mk_gate_result_v3_verified "$result" "$_GATE_VERIFY_REPO"
  snapshot="$(
    gate_subject_snapshot "$_GATE_VERIFY_REPO" main \
      "$(git -C "$_GATE_VERIFY_REPO" rev-parse HEAD)" \
      fixed_ref ignore_working_tree "2026-07-27T00:00:00Z"
  )"
  subject="$(jq -nc --argjson snapshot "$snapshot" '{
    kind:"gate_subject_v1",
    schema_version:1,
    repository:$snapshot.repository,
    observed:$snapshot.observed,
    base:$snapshot.base,
    head:$snapshot.head,
    tree_fingerprint:$snapshot.tree_fingerprint,
    subject_kind:$snapshot.subject_kind,
    dirty_policy:$snapshot.dirty_policy,
    created_at:$snapshot.captured_at,
    finished_at:$snapshot.captured_at,
    observed_at_finish:{
      repository_key:$snapshot.repository.key,
      base_commit:$snapshot.base.commit,
      head_commit:$snapshot.head.commit,
      tree_fingerprint:$snapshot.tree_fingerprint
    }
  }')"
  jq --argjson subject "$subject" '
    .subject = $subject |
    .bindings.repo_identity = $subject.repository.key |
    .bindings.base_commit = $subject.base.commit |
    .bindings.head_commit = $subject.head.commit |
    .bindings.subject_fingerprint = $subject.tree_fingerprint
  ' "$sidecar" > "${sidecar}.tmp"
  mv "${sidecar}.tmp" "$sidecar"
  _attach_gate_scope_manifest_v3 "$result"
  _refresh_gate_result_v3_attestation "$result"
  printf 'unrelated dirt\n' > "$_GATE_VERIFY_REPO/untracked.txt"
  set +e
  out="$(_run_canonical_gate_verify "$result" --consumer generic --json 2>&1)"
  code=$?
  set -e
  rm -f "$_GATE_VERIFY_REPO/untracked.txt"
  if [[ "$code" -eq 0 ]] \
      && jq -e '
        .axes.artifact_valid.status == "pass" and
        .axes.subject_current.status == "pass" and
        .axes.policy_applicable.status == "pass"
      ' <<<"$out" >/dev/null; then
    pass "$name"
  else
    fail "$name" "code=$code out=$out"
  fi
}

case_verify_v3_linked_worktree_path_is_current() {
  # Behavior: another linked worktree has the same Git common-dir identity; its
  # different observed path alone does not stale the subject.
  local name="gate/verify: v3 linked worktree path difference keeps subject current"
  should_run "$name" || return 0
  local result linked out code
  result="$(_gate_verify_result_path v3-linked-worktree)"
  linked="$tmp_root/gate-verify-linked"
  _mk_gate_result_v3_verified "$result" "$_GATE_VERIFY_REPO"
  git -C "$_GATE_VERIFY_REPO" worktree add -q --detach "$linked" HEAD
  set +e
  out="$(
    PM_DISPATCH_STATE_ROOT="$_GATE_VERIFY_STATE_ROOT" \
      "$PMCTL" gate verify "$result" --cd "$linked" --json 2>&1
  )"
  code=$?
  set -e
  git -C "$_GATE_VERIFY_REPO" worktree remove -f "$linked"
  if [[ "$code" -eq 0 ]] \
      && jq -e --arg original "$_GATE_VERIFY_REPO" '
        .axes.artifact_valid.status == "pass" and
        .axes.subject_current.status == "pass" and
        .axes.subject_current.current.observed_root != $original
      ' <<<"$out" >/dev/null; then
    pass "$name"
  else
    fail "$name" "code=$code out=$out"
  fi
}

case_verify_v3_different_repo_same_content_is_stale() {
  # Behavior: equal files and commits in a separate repository do not satisfy
  # the stable common-dir repository identity.
  local name="gate/verify: v3 different repository reports repository_mismatch"
  should_run "$name" || return 0
  local result other out code
  result="$(_gate_verify_result_path v3-other-repo)"
  other="$tmp_root/gate-verify-other"
  _mk_gate_result_v3_verified "$result" "$_GATE_VERIFY_REPO"
  git clone -q "$_GATE_VERIFY_REPO" "$other"
  git -C "$other" branch main origin/main
  set +e
  out="$(
    PM_DISPATCH_STATE_ROOT="$_GATE_VERIFY_STATE_ROOT" \
      "$PMCTL" gate verify "$result" --cd "$other" --consumer generic --json 2>&1
  )"
  code=$?
  set -e
  if [[ "$code" -eq 1 ]] \
      && jq -e '
        .axes.artifact_valid.status == "pass" and
        (.axes.subject_current.reason_codes | index("repository_mismatch")) != null
      ' <<<"$out" >/dev/null; then
    pass "$name"
  else
    fail "$name" "code=$code out=$out"
  fi
}

case_verify_v3_copy_replay_is_valid_but_not_authorizing() {
  # Behavior: copying the self-contained result/sidecar/evidence set preserves
  # content validity and subject freshness, but protected dispatch
  # applicability does not travel outside the canonical run partition.
  local name="gate/verify: v3 copied artifact set is valid/current but not policy-authorizing"
  should_run "$name" || return 0
  local result copied out code
  result="$(_gate_verify_result_path v3-copy-source)"
  copied="$tmp_root/v3-copy/result.md"
  _mk_gate_result_v3_verified "$result" "$_GATE_VERIFY_REPO"
  mkdir -p "$(dirname "$copied")"
  cp "$result" "$copied"
  cp "${result}.assurance.json" "${copied}.assurance.json"
  cp "$(dirname "$result")/$(jq -r '.evidence.scope_manifest.artifact' \
    "${result}.assurance.json")" "$(dirname "$copied")/"
  set +e
  out="$(
    PM_DISPATCH_STATE_ROOT="$_GATE_VERIFY_STATE_ROOT" \
      "$PMCTL" gate verify "$copied" --cd "$_GATE_VERIFY_REPO" \
        --consumer generic --json 2>&1
  )"
  code=$?
  set -e
  if [[ "$code" -eq 1 ]] \
      && jq -e '
        .axes.artifact_valid.status == "pass" and
        .axes.subject_current.status == "pass" and
        .axes.policy_applicable.status == "fail" and
        (.axes.policy_applicable.reason_codes |
          index("canonical_dispatch_evidence_unavailable")) != null
      ' <<<"$out" >/dev/null; then
    pass "$name"
  else
    fail "$name" "code=$code out=$out"
  fi
}

case_verify_v3_valid_but_policy_insufficient() {
  # Behavior: a generic-policy artifact remains valid/current but cannot satisfy
  # the stronger maintainer consumer.
  local name="gate/verify: v3 generic artifact is insufficient for maintainer consumer"
  should_run "$name" || return 0
  local result out code
  result="$(_gate_verify_result_path v3-policy-insufficient)"
  _mk_gate_result_v3_verified "$result" "$_GATE_VERIFY_REPO"
  set +e
  out="$(_run_canonical_gate_verify "$result" --consumer maintainer --json 2>&1)"
  code=$?
  set -e
  if [[ "$code" -eq 1 ]] \
      && jq -e '
        .axes.artifact_valid.status == "pass" and
        .axes.subject_current.status == "pass" and
        (.axes.policy_applicable.reason_codes |
          index("consumer_policy_mismatch")) != null
      ' <<<"$out" >/dev/null; then
    pass "$name"
  else
    fail "$name" "code=$code out=$out"
  fi
}

case_verify_v3_linked_evidence_digest_tamper_is_invalid() {
  # Behavior: a linked evidence digest is part of artifact integrity, distinct
  # from whether the otherwise immutable subject is still current.
  local name="gate/verify: v3 malformed linked-evidence digest invalidates artifact"
  should_run "$name" || return 0
  local result sidecar evidence evidence_sha out report code
  result="$(_gate_verify_result_path v3-evidence-tamper)"
  sidecar="${result}.assurance.json"
  evidence="$(dirname "$result")/preflight-evidence-20260727-000000.json"
  _mk_gate_result_v3_verified "$result" "$_GATE_VERIFY_REPO"
  printf '{"kind":"fixture","status":"pass"}\n' > "$evidence"
  evidence_sha="$(sha256sum "$evidence" | awk '{print $1}')"
  jq --arg artifact "$(basename "$evidence")" --arg sha "$evidence_sha" '
    .evidence.preflight = {
      status:"linked",
      outcome:"pass",
      artifact:$artifact,
      sha256:$sha,
      subject_fingerprint:.subject.tree_fingerprint
    }
  ' "$sidecar" > "${sidecar}.tmp"
  mv "${sidecar}.tmp" "$sidecar"
  _refresh_gate_result_v3_attestation "$result"
  printf 'tampered\n' >> "$evidence"
  set +e
  out="$(_run_canonical_gate_verify "$result" --consumer generic --json 2>&1)"
  code=$?
  set -e
  report="$(tail -n 1 <<<"$out")"
  if [[ "$code" -eq 1 ]] \
      && jq -e '
        .axes.artifact_valid.status == "fail" and
        (.axes.artifact_valid.reason_codes |
          index("artifact_integrity_failed")) != null
      ' <<<"$report" >/dev/null; then
    pass "$name"
  else
    fail "$name" "code=$code out=$out"
  fi
}

case_verify_v3_subject_binding_mismatch_is_invalid() {
  # Behavior: even a freshly re-attested sidecar cannot separate the legacy
  # binding field from the immutable v3 subject it claims to summarize.
  local name="gate/verify: v3 binding fingerprint must match immutable subject"
  should_run "$name" || return 0
  local result sidecar out report code
  result="$(_gate_verify_result_path v3-binding-subject-mismatch)"
  sidecar="${result}.assurance.json"
  _mk_gate_result_v3_verified "$result" "$_GATE_VERIFY_REPO"
  jq '.bindings.subject_fingerprint = ("f" * 64)' "$sidecar" > "${sidecar}.tmp"
  mv "${sidecar}.tmp" "$sidecar"
  _refresh_gate_result_v3_attestation "$result"
  set +e
  out="$(_run_canonical_gate_verify "$result" --consumer generic --json 2>&1)"
  code=$?
  set -e
  report="$(tail -n 1 <<<"$out")"
  if [[ "$code" -eq 1 ]] \
      && [[ "$out" == *"structural/claim verification"* ]] \
      && jq -e '.axes.artifact_valid.status == "fail"' \
        <<<"$report" >/dev/null; then
    pass "$name"
  else
    fail "$name" "code=$code out=$out"
  fi
}

case_verify_v3_linked_preflight_subject_claim_mismatch_is_invalid() {
  # Behavior: the sidecar cannot attach a digest-valid preflight artifact to a
  # different subject by writing the desired subject only in the link record.
  local name="gate/verify: v3 linked preflight subject must match evidence claim"
  should_run "$name" || return 0
  local result sidecar evidence evidence_sha out report code
  result="$(_gate_verify_result_path v3-preflight-subject-mismatch)"
  sidecar="${result}.assurance.json"
  evidence="$(dirname "$result")/preflight-evidence-20260727-000001.json"
  _mk_gate_result_v3_verified "$result" "$_GATE_VERIFY_REPO"
  jq -n '{
    kind:"pr_gate_preflight_v1",
    status:"pass",
    subject:{
      fingerprint_before:("f" * 64),
      fingerprint_after:("f" * 64)
    }
  }' > "$evidence"
  evidence_sha="$(sha256sum "$evidence" | awk '{print $1}')"
  jq --arg artifact "$(basename "$evidence")" --arg sha "$evidence_sha" '
    .evidence.preflight = {
      status:"linked",
      outcome:"pass",
      artifact:$artifact,
      sha256:$sha,
      subject_fingerprint:.subject.tree_fingerprint
    }
  ' "$sidecar" > "${sidecar}.tmp"
  mv "${sidecar}.tmp" "$sidecar"
  _refresh_gate_result_v3_attestation "$result"
  set +e
  out="$(_run_canonical_gate_verify "$result" --consumer generic --json 2>&1)"
  code=$?
  set -e
  report="$(tail -n 1 <<<"$out")"
  if [[ "$code" -eq 1 ]] \
      && [[ "$out" == *"linked preflight evidence subject claim mismatch"* ]] \
      && jq -e '.axes.artifact_valid.status == "fail"' \
        <<<"$report" >/dev/null; then
    pass "$name"
  else
    fail "$name" "code=$code out=$out"
  fi
}

case_verify_v2_forged_state_tree_rejected() {
  local name="gate/verify: self-consistent noncanonical state tree exits 1"
  should_run "$name" || return 0
  local result="$tmp_root/forged/projects/key/runs/gate-forged/.gate-results/result.md"
  local out code
  _mk_gate_result_v2_verified "$result" "$_GATE_VERIFY_REPO"
  set +e; out="$(_run_canonical_gate_verify "$result" 2>&1)"; code=$?; set -e
  if [[ "$code" -eq 1 \
      && "$out" == *"outside the invoking repository canonical state partition"* ]]; then
    pass "$name"
  else
    fail "$name" "code=$code out=$out"
  fi
}

case_verify_v2_repo_binding_rejected() {
  local name="gate/verify: canonical state with wrong repository binding exits 1"
  should_run "$name" || return 0
  local result out code
  result="$(_gate_verify_result_path repo-binding)"
  _mk_gate_result_v2_verified "$result" "/tmp/not-the-invoking-repo"
  set +e; out="$(_run_canonical_gate_verify "$result" 2>&1)"; code=$?; set -e
  if [[ "$code" -eq 1 \
      && "$out" == *"repository binding does not match the invoking repository"* ]]; then
    pass "$name"
  else
    fail "$name" "code=$code out=$out"
  fi
}

case_verify_v2_legacy_assurance_is_unavailable() {
  local name="gate/verify: unbound v1 envelope remains readable but unavailable"
  should_run "$name" || return 0
  local result="$tmp_root/v2-legacy-envelope/result.md" out code
  _mk_gate_result_v2_legacy_assurance "$result"
  set +e; out="$("$PMCTL" gate verify "$result" 2>&1)"; code=$?; set -e
  if [[ "$code" -eq 0 && "$out" == *"assurance: unavailable"* ]]; then
    pass "$name"
  else
    fail "$name" "code=$code out=$out"
  fi
}

case_verify_v2_claim_mismatch() {
  local name="gate/verify: v2 coverage partition mismatch exits 1"
  should_run "$name" || return 0
  local result="$tmp_root/v2-mismatch/result.md" out code
  _mk_gate_result_v2 "$result"
  jq '.coordinates.coverage.selected = ["critic"]' "${result}.assurance.json" \
    > "${result}.assurance.tmp"
  mv "${result}.assurance.tmp" "${result}.assurance.json"
  set +e; out="$("$PMCTL" gate verify "$result" 2>&1)"; code=$?; set -e
  if [[ "$code" -eq 1 && "$out" == *"structural/claim verification"* ]]; then
    pass "$name"
  else
    fail "$name" "code=$code out=$out"
  fi
}

case_verify_v2_policy_claim_tamper() {
  local name="gate/verify: v2 policy coordinate tamper exits 1"
  should_run "$name" || return 0
  local result="$tmp_root/v2-policy-tamper/result.md" out code
  _mk_gate_result_v2 "$result"
  jq '.policy.resolved.reviewers = ["critic"]' "${result}.assurance.json" \
    > "${result}.assurance.tmp"
  mv "${result}.assurance.tmp" "${result}.assurance.json"
  set +e; out="$("$PMCTL" gate verify "$result" 2>&1)"; code=$?; set -e
  if [[ "$code" -eq 1 && "$out" == *"structural/claim verification"* ]]; then
    pass "$name"
  else
    fail "$name" "code=$code out=$out"
  fi
}

case_verify_v2_surplus_topology_record() {
  local name="gate/verify: v2 surplus topology record exits 1"
  should_run "$name" || return 0
  local result="$tmp_root/v2-surplus/result.md" out code
  _mk_gate_result_v2 "$result"
  jq '.dispatch.outcomes += [{
    role:"synthesis",reviewer:null,status:"passed",
    run_id:null,evidence_status:"unavailable"
  }]' "${result}.assurance.json" > "${result}.assurance.tmp"
  mv "${result}.assurance.tmp" "${result}.assurance.json"
  set +e; out="$("$PMCTL" gate verify "$result" 2>&1)"; code=$?; set -e
  if [[ "$code" -eq 1 && "$out" == *"structural/claim verification"* ]]; then
    pass "$name"
  else
    fail "$name" "code=$code out=$out"
  fi
}

case_verify_v2_unknown_fields_rejected() {
  local name="gate/verify: v2 unknown top-level and nested fields exit 1"
  should_run "$name" || return 0
  local variant result out code
  for variant in top-level nested; do
    result="$tmp_root/v2-unknown-$variant/result.md"
    _mk_gate_result_v2 "$result"
    if [[ "$variant" == top-level ]]; then
      jq '.unexpected = true' "${result}.assurance.json" > "${result}.assurance.tmp"
    else
      jq '.coordinates.tier.unexpected = true' "${result}.assurance.json" \
        > "${result}.assurance.tmp"
    fi
    mv "${result}.assurance.tmp" "${result}.assurance.json"
    set +e; out="$("$PMCTL" gate verify "$result" 2>&1)"; code=$?; set -e
    if [[ "$code" -ne 1 || "$out" != *"structural/claim verification"* ]]; then
      fail "$name" "$variant code=$code out=$out"
      return
    fi
  done
  pass "$name"
}

case_verify_v2_result_binding_tamper() {
  local name="gate/verify: v2 changed result digest exits 1"
  should_run "$name" || return 0
  local result="$tmp_root/v2-result-tamper/projects/key/runs/gate-test/.gate-results/result.md"
  local out code
  _mk_gate_result_v2_verified "$result"
  printf '\npost-finalization mutation\n' >> "$result"
  set +e; out="$("$PMCTL" gate verify "$result" 2>&1)"; code=$?; set -e
  if [[ "$code" -eq 1 && "$out" == *"structural/claim verification"* ]]; then
    pass "$name"
  else
    fail "$name" "code=$code out=$out"
  fi
}

case_verify_v2_sidecar_attestation_tamper() {
  local name="gate/verify: v2 substituted sidecar exits 1"
  should_run "$name" || return 0
  local result
  local out code sidecar
  result="$(_gate_verify_result_path sidecar-tamper)"
  sidecar="${result}.assurance.json"
  _mk_gate_result_v2_verified "$result" "$_GATE_VERIFY_REPO"
  jq '.coordinates.tier.evidence_floor = "forged"' "$sidecar" > "${sidecar}.tmp"
  mv "${sidecar}.tmp" "$sidecar"
  set +e; out="$(_run_canonical_gate_verify "$result" 2>&1)"; code=$?; set -e
  if [[ "$code" -eq 1 && "$out" == *"protected attestation mismatch"* ]]; then
    pass "$name"
  else
    fail "$name" "code=$code out=$out"
  fi
}

case_verify_v2_subject_binding_tamper() {
  local name="gate/verify: v2 changed subject fingerprint exits 1"
  should_run "$name" || return 0
  local result
  local out code sidecar
  result="$(_gate_verify_result_path subject-tamper)"
  sidecar="${result}.assurance.json"
  _mk_gate_result_v2_verified "$result" "$_GATE_VERIFY_REPO"
  jq '.bindings.subject_fingerprint = ("f" * 64)' "$sidecar" > "${sidecar}.tmp"
  mv "${sidecar}.tmp" "$sidecar"
  set +e; out="$(_run_canonical_gate_verify "$result" 2>&1)"; code=$?; set -e
  if [[ "$code" -eq 1 && "$out" == *"protected attestation mismatch"* ]]; then
    pass "$name"
  else
    fail "$name" "code=$code out=$out"
  fi
}

case_verify_v2_canonical_run_mismatch() {
  local name="gate/verify: v2 unresolvable canonical run exits 1"
  should_run "$name" || return 0
  local result
  local out code run_root project_dir
  result="$(_gate_verify_result_path run-tamper)"
  _mk_gate_result_v2_verified "$result" "$_GATE_VERIFY_REPO"
  run_root="$(dirname "$(dirname "$result")")"
  project_dir="$(dirname "$(dirname "$run_root")")"
  jq '.state = "failed" | .exit_code = 1' "$project_dir/runs.jsonl" \
    > "$project_dir/runs.tmp"
  mv "$project_dir/runs.tmp" "$project_dir/runs.jsonl"
  set +e; out="$(_run_canonical_gate_verify "$result" 2>&1)"; code=$?; set -e
  if [[ "$code" -eq 1 && "$out" == *"canonical run records"* ]]; then
    pass "$name"
  else
    fail "$name" "code=$code out=$out"
  fi
}

case_verify_v2_publication_race_retries() {
  local name="gate/verify: canonical v2 publication race retries"
  should_run "$name" || return 0
  local result sidecar staged out code publisher
  result="$(_gate_verify_result_path publication-race)"
  sidecar="${result}.assurance.json"
  staged="${sidecar}.staged"
  _mk_gate_result_v2 "$result"
  mv "$sidecar" "$staged"
  (
    sleep 0.2
    mv "$staged" "$sidecar"
  ) &
  publisher=$!
  set +e; out="$(_run_canonical_gate_verify "$result" 2>&1)"; code=$?; set -e
  wait "$publisher"
  if [[ "$code" -eq 0 && "$out" == *"gate result OK"* ]]; then
    pass "$name"
  else
    fail "$name" "code=$code out=$out"
  fi
}

case_verify_v2_attestation_publication_race_retries() {
  local name="gate/verify: canonical v2 attestation publication race retries"
  should_run "$name" || return 0
  local result run_root attestation staged out code publisher
  result="$(_gate_verify_result_path attestation-race)"
  _mk_gate_result_v2_verified "$result" "$_GATE_VERIFY_REPO"
  run_root="$(dirname "$(dirname "$result")")"
  attestation="$run_root/gate-assurance-20260727-000000.attestation.json"
  staged="${attestation}.staged"
  mv "$attestation" "$staged"
  (
    sleep 0.2
    mv "$staged" "$attestation"
  ) &
  publisher=$!
  set +e; out="$(_run_canonical_gate_verify "$result" 2>&1)"; code=$?; set -e
  wait "$publisher"
  if [[ "$code" -eq 0 && "$out" == *"assurance: verified"* ]]; then
    pass "$name"
  else
    fail "$name" "code=$code out=$out"
  fi
}

case_verify_v2_pointer_escape() {
  local name="gate/verify: v2 sidecar pointer escape exits 1"
  should_run "$name" || return 0
  local result="$tmp_root/v2-pointer/result.md" out code
  _mk_gate_result_v2 "$result"
  sed -i 's|^gate_assurance:.*|gate_assurance: ../outside.json|' "$result"
  set +e; out="$("$PMCTL" gate verify "$result" 2>&1)"; code=$?; set -e
  if [[ "$code" -eq 1 && "$out" == *"bounded sibling"* ]]; then
    pass "$name"
  else
    fail "$name" "code=$code out=$out"
  fi
}

case_verify_v2_missing_sidecar() {
  local name="gate/verify: v2 missing assurance sidecar exits 1"
  should_run "$name" || return 0
  local result="$tmp_root/v2-missing-sidecar/result.md" out code
  _mk_gate_result_v2 "$result"
  rm -f "${result}.assurance.json"
  set +e; out="$("$PMCTL" gate verify "$result" 2>&1)"; code=$?; set -e
  if [[ "$code" -eq 1 && "$out" == *"sidecar missing or empty"* ]]; then
    pass "$name"
  else
    fail "$name" "code=$code out=$out"
  fi
}

case_verify_v2_empty_sidecar() {
  local name="gate/verify: v2 empty assurance sidecar exits 1"
  should_run "$name" || return 0
  local result="$tmp_root/v2-empty-sidecar/result.md" out code
  _mk_gate_result_v2 "$result"
  : > "${result}.assurance.json"
  set +e; out="$("$PMCTL" gate verify "$result" 2>&1)"; code=$?; set -e
  if [[ "$code" -eq 1 && "$out" == *"sidecar missing or empty"* ]]; then
    pass "$name"
  else
    fail "$name" "code=$code out=$out"
  fi
}

# ---- 7: gate verify rejects an empty (0-byte) result -------------------------
case_verify_empty() {
  # The exact failure mode pmctl gate verify exists to catch: a session that
  # exited 0 without writing a verdict.
  local name="gate/verify: empty result exits 1"
  should_run "$name" || return 0
  local result="$tmp_root/v7/result.md"
  mkdir -p "$(dirname "$result")"; : > "$result"
  local out code
  set +e; out="$("$PMCTL" gate verify "$result" 2>&1)"; code=$?; set -e
  if [[ "$code" -eq 1 ]] && [[ "$out" == *"did not produce the result file"* ]]; then
    pass "$name"
  else
    fail "$name" "code=$code out=$out"
  fi
}

# ---- 8: gate verify rejects a result with no Final line ----------------------
case_verify_no_final() {
  local name="gate/verify: result without a Final line exits 1"
  should_run "$name" || return 0
  local result="$tmp_root/v8/result.md"
  mkdir -p "$(dirname "$result")"
  printf 'no verdict here\n' > "$result"
  local out code
  set +e; out="$("$PMCTL" gate verify "$result" 2>&1)"; code=$?; set -e
  if [[ "$code" -eq 1 ]] && [[ "$out" == *"must contain exactly one Final"* ]]; then
    pass "$name"
  else
    fail "$name" "code=$code out=$out"
  fi
}

# ---- 9: gate verify rejects frontmatter/body Final disagreement --------------
case_verify_parity_mismatch() {
  local name="gate/verify: frontmatter/body Final mismatch exits 1"
  should_run "$name" || return 0
  local result="$tmp_root/v9/result.md"
  _mk_gate_result "$result" GO NO-GO   # body GO, frontmatter NO-GO
  local out code
  set +e; out="$("$PMCTL" gate verify "$result" 2>&1)"; code=$?; set -e
  if [[ "$code" -eq 1 ]] && [[ "$out" == *"does not match body Final"* ]]; then
    pass "$name"
  else
    fail "$name" "code=$code out=$out"
  fi
}

# ---- 10: gate verify with no file argument is a usage error ------------------
case_verify_usage() {
  local name="gate/verify: missing file argument exits 2"
  should_run "$name" || return 0
  local out code
  set +e; out="$("$PMCTL" gate verify 2>&1)"; code=$?; set -e
  if [[ "$code" -eq 2 ]] && [[ "$out" == *"usage: pmctl gate verify"* ]]; then
    pass "$name"
  else
    fail "$name" "code=$code out=$out"
  fi
}

case_verify_argument_errors() {
  local name="gate/verify: new flag parser rejects malformed arguments"
  should_run "$name" || return 0
  local result="$tmp_root/verify-args/result.md" variant expected out code
  _mk_gate_result "$result" GO
  while IFS='|' read -r variant expected; do
    set +e
    case "$variant" in
      consumer)
        out="$("$PMCTL" gate verify "$result" --consumer bogus 2>&1)"
        code=$?
        ;;
      cd)
        out="$("$PMCTL" gate verify "$result" --cd 2>&1)"
        code=$?
        ;;
      option)
        out="$("$PMCTL" gate verify "$result" --bogus 2>&1)"
        code=$?
        ;;
      positional)
        out="$("$PMCTL" gate verify "$result" "$result" 2>&1)"
        code=$?
        ;;
    esac
    set -e
    if [[ "$code" -ne 2 || "$out" != *"$expected"* ]]; then
      fail "$name" "$variant code=$code out=$out"
      return
    fi
  done <<'CASES'
consumer|requires embedded, generic, maintainer, or publish
cd|requires a repository path
option|unknown option
positional|unexpected argument
CASES
  pass "$name"
}

# ---- 11: pmctl gate run forwards --run-dir to pr-gate.sh --------------------
case_run_dir_forwarded_to_gate() {
  # Verifies that pmctl_gate_run computes a run dir keyed to the --cd target repo
  # and passes it as --run-dir <abs> to pr-gate.sh, and that different --cd targets
  # produce different run dir partitions (proving the key is target-repo-specific).
  #
  # Steps:
  #   1. Install a fake pr-gate.sh that echoes its argv.
  #   2. Copy state-paths.sh and its dependencies into the fixture lib dir.
  #   3. Call pmctl_gate_run with --cd <dir1> and --cd <dir2> separately.
  #   4. Assert both echoed arg sets contain --run-dir <abs>.
  #   5. Assert the two --run-dir values differ (different partition keys).
  local name="gate/run: --run-dir forwarded keyed to target repo partition"
  should_run "$name" || return 0

  local fixture="$tmp_root/f11" wrapper="$tmp_root/b11/wrapper"
  mkdir -p "$(dirname "$wrapper")"
  _mk_fake_gate "$fixture" 0
  _mk_gate_wrapper "$fixture" "$wrapper"

  # Provide the real state-paths lib (and its dependencies) so sw_project_run_dir is available.
  mkdir -p "$fixture/runtime/lib"
  for _lib in state-paths.sh portable.sh; do
    if [[ -f "$REPO_ROOT/runtime/lib/$_lib" ]]; then
      cp "$REPO_ROOT/runtime/lib/$_lib" "$fixture/runtime/lib/$_lib"
    fi
  done

  local dir1 dir2; dir1="$(mktemp -d)"; dir2="$(mktemp -d)"
  local out1 out2 code1 code2
  set +e
  out1="$("$wrapper" --cd "$dir1" --lifecycle foreground 2>&1)"; code1=$?
  out2="$("$wrapper" --cd "$dir2" --lifecycle foreground 2>&1)"; code2=$?
  set -e
  rm -rf "$dir1" "$dir2"

  if [[ "$code1" -ne 0 || "$code2" -ne 0 ]]; then
    fail "$name" "wrapper failed (code1=$code1 code2=$code2)"
    return
  fi
  if [[ "$out1" != *"--run-dir /"* || "$out2" != *"--run-dir /"* ]]; then
    fail "$name" "expected --run-dir <abs> in both calls; out1=$out1 out2=$out2"
    return
  fi
  # Extract the --run-dir values and verify they differ (different partition keys).
  local rundir1 rundir2
  rundir1="$(printf '%s\n' "$out1" | grep -o -- '--run-dir [^ ]*' | awk '{print $2}' || true)"
  rundir2="$(printf '%s\n' "$out2" | grep -o -- '--run-dir [^ ]*' | awk '{print $2}' || true)"
  if [[ "$rundir1" == "$rundir2" ]]; then
    fail "$name" "--run-dir values are identical for different --cd targets: $rundir1"
    return
  fi
  pass "$name"
}

# ---- 12: omitting --lifecycle defaults to detached (CC-423) ------------------
case_default_lifecycle_is_detached() {
  # Verifies that pmctl_gate_run with no --lifecycle flag now takes the
  # detached path (returns a bare gate_id, does not synchronously exec
  # pr-gate.sh), mirroring dispatch's default. tests/shell/test-gate-lifecycle.sh
  # covers the detached mechanics (supervisor, wait, sentinel) in depth; this
  # case only proves the default routing decision.
  local name="gate/run: omitting --lifecycle defaults to detached"
  should_run "$name" || return 0

  local fixture="$tmp_root/f12" wrapper="$tmp_root/b12/wrapper" work="$tmp_root/f12-work"
  mkdir -p "$(dirname "$wrapper")" "$work"
  _mk_fake_gate "$fixture" 0
  _mk_gate_wrapper "$fixture" "$wrapper"
  cp "$REPO_ROOT/runtime/bin/gate-supervisor.sh" "$fixture/runtime/bin/gate-supervisor.sh"
  chmod +x "$fixture/runtime/bin/gate-supervisor.sh"
  for _lib in state-paths.sh portable.sh; do
    cp "$REPO_ROOT/runtime/lib/$_lib" "$fixture/runtime/lib/$_lib"
  done

  local out code err_file="$tmp_root/f12-run.err"
  PM_DISPATCH_STATE_ROOT="$tmp_root/f12-state" XDG_RUNTIME_DIR="$tmp_root/f12-xdg"
  mkdir -p "$XDG_RUNTIME_DIR"; chmod 700 "$XDG_RUNTIME_DIR"
  set +e
  out="$(PM_DISPATCH_STATE_ROOT="$PM_DISPATCH_STATE_ROOT" XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" \
    "$wrapper" --cd "$work" 2>"$err_file")"
  code=$?
  set -e

  # stdout must stay a single bare gate_id line (callers capture it with
  # command substitution); the copy-paste wait hint goes to stderr only.
  local err_out key_file nonce ready_sentinel terminal_sentinel cleanup_ok=true
  err_out="$(cat "$err_file" 2>/dev/null)"
  if [[ "$out" =~ ^gate-[0-9]{8}-[0-9]{6}-[A-Za-z0-9]{6,}$ ]]; then
    key_file="$XDG_RUNTIME_DIR/pm-gate-dispatch/$out"
    nonce="$(cat "$key_file" 2>/dev/null || true)"
    if [[ -n "$nonce" ]]; then
      ready_sentinel="$(detached_launch_sentinel_path "pm-gate-ready" "$out" "$nonce")"
      terminal_sentinel="$(detached_launch_sentinel_path "pm-gate" "$out" "$nonce")"
      PM_DISPATCH_STATE_ROOT="$PM_DISPATCH_STATE_ROOT" XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" \
        PM_GATE_WAIT_POLL_INTERVAL=0.01 \
        bash -c '. "$1/runtime/lib/pmctl-gate.sh"; pmctl_gate_wait "$1" "$2" --cd "$3" --timeout 5' \
        _ "$fixture" "$out" "$work" >/dev/null 2>&1 || true
    else
      cleanup_ok=false
    fi
    if [[ "$cleanup_ok" == true ]] \
      && [[ -e "$key_file" || -e "$ready_sentinel" || -e "$terminal_sentinel" ]]; then
      cleanup_ok=false
    fi
  fi
  if [[ "$code" -eq 0 ]] \
     && [[ "$out" =~ ^gate-[0-9]{8}-[0-9]{6}-[A-Za-z0-9]{6,}$ ]] \
     && [[ "$err_out" == *"pmctl gate wait $out --cd"* ]] \
     && [[ "$cleanup_ok" == true ]]; then
    pass "$name"
  else
    fail "$name" "code=$code cleanup_ok=$cleanup_ok out=$out err=$err_out (expected bare gate_id on stdout + wait hint on stderr)"
  fi
}

# ---- 13/14: gate/wait routed through the REAL cli/pmctl binary (GO/NO-GO) ----
# tests/shell/test-gate-lifecycle.sh drives pmctl_gate_run_detached/pmctl_gate_wait
# by sourcing pmctl-gate.sh directly, which never exercises cli/pmctl's own
# `case "$cmd/$sub" in gate/wait) ...` routing-table entry -- that entry could
# regress (typo, wrong function name) while the lifecycle-library tests still
# pass. These two cases copy the REAL cli/pmctl into a fixture (cli/pmctl
# resolves REPO_ROOT from its own script location, so this makes it treat the
# fixture as REPO_ROOT) and drive `gate run --lifecycle detached` +
# `gate wait` end to end through it for both a GO and a NO-GO outcome.
_run_gate_cli_route_case() {
  local name="$1" gate_code="$2" expect_state="$3" expect_exit="$4"
  should_run "$name" || return 0

  local fixture="$tmp_root/${name//[^A-Za-z0-9]/-}/fixture"
  local work="$tmp_root/${name//[^A-Za-z0-9]/-}/work"
  local state="$tmp_root/${name//[^A-Za-z0-9]/-}/state"
  mkdir -p "$work"
  _mk_gate_cli_fixture "$fixture"
  _mk_fake_gate_with_result "$fixture" "$gate_code"

  local cli_pmctl="$fixture/cli/pmctl"
  local gate_id out1 code1
  set +e
  gate_id="$(PM_DISPATCH_STATE_ROOT="$state" XDG_RUNTIME_DIR="$_GATE_CLI_XDG_RUNTIME_DIR" \
    PM_GATE_WAIT_POLL_INTERVAL=0.1 \
    "$cli_pmctl" gate run --cd "$work" --lifecycle detached 2>/dev/null)"
  code1=$?
  set -e
  if [[ "$code1" -ne 0 ]] || ! [[ "$gate_id" =~ ^gate-[0-9]{8}-[0-9]{6}-[A-Za-z0-9]{6,}$ ]]; then
    fail "$name" "gate run --lifecycle detached via cli/pmctl failed: code=$code1 out=$gate_id"
    return
  fi

  local out2 code2
  set +e
  out2="$(PM_DISPATCH_STATE_ROOT="$state" XDG_RUNTIME_DIR="$_GATE_CLI_XDG_RUNTIME_DIR" \
    PM_GATE_WAIT_POLL_INTERVAL=0.1 \
    "$cli_pmctl" gate wait "$gate_id" --cd "$work" --timeout 30 2>&1)"
  code2=$?
  set -e

  # The wait must also surface the verdict itself: the result file's Final:
  # line echoed to stdout, and for NO-GO an explicit "not an execution error"
  # note so exit 1 is distinguishable from a genuine failure in harness output.
  if [[ "$code2" -eq "$expect_exit" ]] \
     && [[ "$out2" == *"state: $expect_state"* ]] \
     && [[ "$out2" == *"Final: $expect_state"* ]]; then
    if [[ "$expect_state" == "NO-GO" && "$out2" != *"not an execution error"* ]]; then
      fail "$name" "NO-GO wait missing the verdict-vs-error note: out2=$out2"
      return
    fi
    pass "$name"
  else
    fail "$name" "code1=$code1 gate_id=$gate_id code2=$code2 (expected $expect_exit) out2=$out2"
  fi
}

case_gate_wait_go_route_via_cli() {
  _run_gate_cli_route_case "gate/wait: GO routed through real cli/pmctl" 0 "GO" 0
}

case_gate_wait_nogo_route_via_cli() {
  _run_gate_cli_route_case "gate/wait: NO-GO routed through real cli/pmctl" 1 "NO-GO" 1
}

# ---- 15: /pr-gate's documented run/wait handoff survives a REAL process boundary
# CC-423 pr-gate finding (critic/qa-tester/architecture-reviewer/risk-reviewer,
# high, all four converged on the same root cause): commands/pr-gate.md's
# worked example captured `GATE_ID="$(...)"` in one Bash code block and reused
# `"$GATE_ID"` in a separate one, but each Bash tool call is an independent
# subprocess -- shell variables do not survive across calls, so the wait would
# receive an empty gate_id. The fix: read the captured stdout, substitute the
# LITERAL value into the next command (matching commands/pm.md's <run_id>
# convention). This case proves that literal-substitution handoff actually
# works by launching `gate run` and `gate wait` as two genuinely separate
# `bash -c` processes -- run's stdout is captured to a FILE (never a shell
# variable), and wait receives the id only via a substituted argv token, with
# no environment or variable inheritance connecting the two processes.
case_run_wait_handoff_survives_separate_process() {
  local name="gate/run+wait: documented literal-gate_id handoff survives a real process boundary"
  should_run "$name" || return 0

  local fixture="$tmp_root/f15/fixture" work="$tmp_root/f15/work" state="$tmp_root/f15/state"
  mkdir -p "$work"
  _mk_gate_cli_fixture "$fixture"
  _mk_fake_gate_with_result "$fixture" 0
  local cli_pmctl="$fixture/cli/pmctl"

  # "Bash call 1": run detached, capture stdout to a file only (the harness's
  # equivalent -- never assign to a variable this test could accidentally
  # smuggle into the next process).
  local id_file="$tmp_root/f15/gate_id.txt"
  env -i PATH="$PATH" HOME="$HOME" \
    PM_DISPATCH_STATE_ROOT="$state" XDG_RUNTIME_DIR="$_GATE_CLI_XDG_RUNTIME_DIR" \
    PM_GATE_WAIT_POLL_INTERVAL=0.1 \
    bash -c '"$1" gate run --cd "$2" --lifecycle detached' _ "$cli_pmctl" "$work" \
    > "$id_file" 2>"$tmp_root/f15/run.err"
  local run_code=$?
  local gate_id; gate_id="$(cat "$id_file" 2>/dev/null)"
  if [[ "$run_code" -ne 0 ]] || ! [[ "$gate_id" =~ ^gate-[0-9]{8}-[0-9]{6}-[A-Za-z0-9]{6,}$ ]]; then
    fail "$name" "run failed or produced no gate_id: code=$run_code gate_id=$gate_id err=$(cat "$tmp_root/f15/run.err" 2>/dev/null)"
    return
  fi

  # "Bash call 2": a BRAND NEW process (env -i: no inherited variables at
  # all) that only knows the gate_id because it was substituted into the
  # command string as a literal argv token -- exactly what the agent does
  # when it reads call 1's stdout and writes call 2's command.
  local out code
  set +e
  out="$(env -i PATH="$PATH" HOME="$HOME" \
    PM_DISPATCH_STATE_ROOT="$state" XDG_RUNTIME_DIR="$_GATE_CLI_XDG_RUNTIME_DIR" \
    PM_GATE_WAIT_POLL_INTERVAL=0.1 \
    bash -c "\"$cli_pmctl\" gate wait $gate_id --cd \"$work\" --timeout 30" 2>&1)"
  code=$?
  set -e

  if [[ "$code" -eq 0 ]] && [[ "$out" == *"state: GO"* ]]; then
    pass "$name"
  else
    fail "$name" "gate_id=$gate_id code=$code out=$out"
  fi
}

# ---- 16: gate wait without --cd defaults to the caller's CWD -----------------
case_wait_default_cd() {
  # Verifies that `pmctl gate wait <gate_id>` with no --cd derives the work
  # dir from the caller's CWD (git toplevel, then $PWD) using the SAME
  # derivation `gate run` uses, so a wait launched from the gate's work dir
  # recomputes the identical run-dir partition and resolves the verdict.
  #
  # Steps:
  #   1. Launch a detached GO gate with an explicit --cd <work> (non-git),
  #      then run `gate wait <gate_id>` (no --cd) with CWD = <work>,
  #      exercising the $PWD fallback of the shared default.
  #   2. Launch a second gate with --cd <git repo toplevel>, then wait (no
  #      --cd) from a SUBDIRECTORY of that repo, exercising the
  #      git-toplevel branch: the wait must climb to the toplevel to
  #      recompute the same partition the run derived.
  #   3. Assert exit 0, state GO, and the echoed Final: GO line for both.
  local name="gate/wait: --cd defaults to caller CWD when omitted"
  should_run "$name" || return 0

  local fixture="$tmp_root/f16/fixture" work="$tmp_root/f16/work" state="$tmp_root/f16/state"
  mkdir -p "$work"
  _mk_gate_cli_fixture "$fixture"
  _mk_fake_gate_with_result "$fixture" 0
  local cli_pmctl="$fixture/cli/pmctl"

  local gate_id code1
  set +e
  gate_id="$(PM_DISPATCH_STATE_ROOT="$state" XDG_RUNTIME_DIR="$_GATE_CLI_XDG_RUNTIME_DIR" \
    PM_GATE_WAIT_POLL_INTERVAL=0.1 \
    "$cli_pmctl" gate run --cd "$work" --lifecycle detached 2>/dev/null)"
  code1=$?
  set -e
  if [[ "$code1" -ne 0 ]] || ! [[ "$gate_id" =~ ^gate-[0-9]{8}-[0-9]{6}-[A-Za-z0-9]{6,}$ ]]; then
    fail "$name" "gate run failed: code=$code1 out=$gate_id"
    return
  fi

  local out code
  set +e
  out="$(cd "$work" && PM_DISPATCH_STATE_ROOT="$state" XDG_RUNTIME_DIR="$_GATE_CLI_XDG_RUNTIME_DIR" \
    PM_GATE_WAIT_POLL_INTERVAL=0.1 \
    "$cli_pmctl" gate wait "$gate_id" --timeout 30 2>&1)"
  code=$?
  set -e

  if [[ "$code" -ne 0 ]] || [[ "$out" != *"state: GO"* ]] || [[ "$out" != *"Final: GO"* ]]; then
    fail "$name" "non-git \$PWD fallback: code=$code out=$out (expected default-cd wait to resolve GO)"
    return
  fi

  # Git-toplevel branch: run keyed to the repo toplevel, wait from a subdir.
  # The repo path is created physical (pwd -P) so the toplevel git reports
  # matches the partition key the run derived from the literal --cd value.
  local gitwork
  mkdir -p "$tmp_root/f16/gitwork/subdir"
  gitwork="$(cd "$tmp_root/f16/gitwork" && pwd -P)"
  git -C "$gitwork" init -q

  local gate_id2 code2
  set +e
  gate_id2="$(PM_DISPATCH_STATE_ROOT="$state" XDG_RUNTIME_DIR="$_GATE_CLI_XDG_RUNTIME_DIR" \
    PM_GATE_WAIT_POLL_INTERVAL=0.1 \
    "$cli_pmctl" gate run --cd "$gitwork" --lifecycle detached 2>/dev/null)"
  code2=$?
  set -e
  if [[ "$code2" -ne 0 ]] || ! [[ "$gate_id2" =~ ^gate-[0-9]{8}-[0-9]{6}-[A-Za-z0-9]{6,}$ ]]; then
    fail "$name" "gate run (git toplevel) failed: code=$code2 out=$gate_id2"
    return
  fi

  local out2 wcode2
  set +e
  out2="$(cd "$gitwork/subdir" && PM_DISPATCH_STATE_ROOT="$state" XDG_RUNTIME_DIR="$_GATE_CLI_XDG_RUNTIME_DIR" \
    PM_GATE_WAIT_POLL_INTERVAL=0.1 \
    "$cli_pmctl" gate wait "$gate_id2" --timeout 30 2>&1)"
  wcode2=$?
  set -e

  if [[ "$wcode2" -eq 0 ]] && [[ "$out2" == *"state: GO"* ]] && [[ "$out2" == *"Final: GO"* ]]; then
    pass "$name"
  else
    fail "$name" "git-subdir default: code=$wcode2 out=$out2 (expected wait from subdir to climb to toplevel and resolve GO)"
  fi
}

case_foreground_gate_reconciles_parent_operation() {
  local name="gate/run foreground: parent operation is terminal after the gate returns"
  should_run "$name" || return 0
  local fixture="$tmp_root/foreground-operation-fixture" target="$tmp_root/foreground-operation-target"
  local wrapper="$tmp_root/foreground-operation-wrapper" state="$tmp_root/foreground-operation-state" out code=0 record
  mkdir -p "$fixture/runtime/lib" "$fixture/core/schema" "$target"
  git -C "$target" init -q
  _mk_fake_gate "$fixture" 0
  for lib in pmctl-gate pmctl-operation portable detached-launch state-writer state-paths state-compat; do
    cp "$REPO_ROOT/runtime/lib/$lib.sh" "$fixture/runtime/lib/$lib.sh"
  done
  cp "$REPO_ROOT/core/schema/operation.schema.json" "$fixture/core/schema/operation.schema.json"
  cat > "$wrapper" <<WRAPPER
#!/usr/bin/env bash
set -euo pipefail
. "$fixture/runtime/lib/pmctl-gate.sh"
pmctl_gate_run "$fixture" "\$@"
WRAPPER
  chmod +x "$wrapper"
  out="$(PM_DISPATCH_STATE_ROOT="$state" "$wrapper" --cd "$target" --lifecycle foreground 2>&1)" || code=$?
  record="$(find "$state" -path '*/operations/op-*.json' -type f | head -1)"
  if [[ "$code" -eq 0 && -n "$record" && "$(jq -r .state "$record")" == failed ]] \
     && [[ "$out" == *"state: failed"* ]]; then
    pass "$name"
  else
    fail "$name" "code=$code record=$record state=$(jq -r .state "$record" 2>/dev/null || true) out=$out"
  fi
}

case_detached_launcher_failure_terminalizes_childless_parent() {
  # The parent is created before either lifecycle path starts, so a detached
  # launcher that fails before its supervisor exists (missing gate-supervisor.sh
  # here) owns no child at all.  That is a known producer failure, not an
  # abandoned operation: it must reach a terminal state instead of leaving a
  # `running` record that only doctor reports.
  local name="gate/run detached: launcher failure terminalizes the childless parent operation"
  should_run "$name" || return 0
  local fixture="$tmp_root/detached-childless-fixture" target="$tmp_root/detached-childless-target"
  local wrapper="$tmp_root/detached-childless-wrapper" state="$tmp_root/detached-childless-state" out code=0 record
  mkdir -p "$fixture/runtime/lib" "$fixture/core/schema" "$target"
  git -C "$target" init -q
  _mk_fake_gate "$fixture" 0
  for lib in pmctl-gate pmctl-operation portable detached-launch state-writer state-paths state-compat; do
    cp "$REPO_ROOT/runtime/lib/$lib.sh" "$fixture/runtime/lib/$lib.sh"
  done
  cp "$REPO_ROOT/core/schema/operation.schema.json" "$fixture/core/schema/operation.schema.json"
  # Deliberately absent: $fixture/runtime/bin/gate-supervisor.sh
  cat > "$wrapper" <<WRAPPER
#!/usr/bin/env bash
set -euo pipefail
. "$fixture/runtime/lib/pmctl-gate.sh"
pmctl_gate_run "$fixture" "\$@"
WRAPPER
  chmod +x "$wrapper"
  out="$(PM_DISPATCH_STATE_ROOT="$state" "$wrapper" --cd "$target" --lifecycle detached 2>&1)" || code=$?
  record="$(find "$state" -path '*/operations/op-*.json' -type f | head -1)"
  if [[ "$code" -ne 0 && -n "$record" && "$(jq -r .state "$record")" == failed ]]; then
    pass "$name"
  else
    fail "$name" "code=$code record=$record state=$(jq -r .state "$record" 2>/dev/null || true) out=$out"
  fi
}

case_gate_operation_routes_via_cli() {
  local name="gate operation CLI: cancel and reconcile route with positional operation id and --cd"
  should_run "$name" || return 0
  local work="$tmp_root/gate-operation-cli-work" state="$tmp_root/gate-operation-cli-state" cancel_op reconcile_op run_id out
  mkdir -p "$work"; git -C "$work" init -q
  cancel_op="$(PM_DISPATCH_STATE_ROOT="$state" pmctl_operation_create "$REPO_ROOT" "$work" gate codex)"
  out="$(PM_DISPATCH_STATE_ROOT="$state" "$PMCTL" gate cancel "$cancel_op" --cd "$work")"
  reconcile_op="$(PM_DISPATCH_STATE_ROOT="$state" pmctl_operation_create "$REPO_ROOT" "$work" gate codex)"
  run_id="run-20260724T000060Z-aaaaaa"
  PM_DISPATCH_STATE_ROOT="$state" pmctl_operation_attach_child "$REPO_ROOT" "$work" "$reconcile_op" "$run_id" "$work"
  PM_DISPATCH_STATE_ROOT="$state" _pmctl_dispatch_try_terminal_claim "$work" "$run_id" ok supervisor
  out+=" $(PM_DISPATCH_STATE_ROOT="$state" "$PMCTL" gate reconcile "$reconcile_op" --cd "$work")"
  if [[ "$out" == *"state: cancelled"* && "$out" == *"state: completed"* ]]; then pass "$name"; else fail "$name" "out=$out"; fi
}

case_gate_operation_cli_unavailable_fallbacks() {
  local name="gate operation CLI: cancel and reconcile report unavailable without operation library"
  should_run "$name" || return 0
  local fixture="$tmp_root/gate-operation-cli-missing" cancel_out reconcile_out cancel_rc=0 reconcile_rc=0
  mkdir -p "$fixture/cli" "$fixture/runtime/lib"
  cp "$REPO_ROOT/cli/pmctl" "$fixture/cli/pmctl"; chmod +x "$fixture/cli/pmctl"
  cp "$REPO_ROOT/runtime/lib/pmctl-command-catalog.sh" "$fixture/runtime/lib/pmctl-command-catalog.sh"
  cancel_out="$("$fixture/cli/pmctl" gate cancel op-20260724T000061Z-aaaaaa --cd /tmp 2>&1)" || cancel_rc=$?
  reconcile_out="$("$fixture/cli/pmctl" gate reconcile op-20260724T000061Z-aaaaaa --cd /tmp 2>&1)" || reconcile_rc=$?
  if [[ "$cancel_rc" -eq 2 && "$reconcile_rc" -eq 2 && "$cancel_out" == *"gate cancel unavailable"* && "$reconcile_out" == *"gate reconcile unavailable"* ]]; then pass "$name"; else fail "$name" "cancel=$cancel_rc:$cancel_out reconcile=$reconcile_rc:$reconcile_out"; fi
}

case_foreground_cancel_stops_preflight_process_tree() {
  local name="gate cancel: foreground preflight process tree stops before cancelled terminal"
  should_run "$name" || return 0
  local work="$tmp_root/foreground-cancel-work" state="$tmp_root/foreground-cancel-state"
  local ready="$tmp_root/foreground-cancel-ready" release="$tmp_root/foreground-cancel-release"
  local runner="$tmp_root/foreground-cancel-runner" pids="$tmp_root/foreground-cancel-pids"
  local out="$tmp_root/foreground-cancel-out" err="$tmp_root/foreground-cancel-err"
  local test_cmd operation record op_dir gate_pid gate_rc=0 cancel_out cancel_rc=0
  local ready_value producer_pid descendant_pid started elapsed
  mkdir -p "$work"
  git -C "$work" init -q
  git -C "$work" config user.email test@example.com
  git -C "$work" config user.name "Gate Test"
  printf '.pm-dispatch/\n' > "$work/.gitignore"
  printf 'base\n' > "$work/input.txt"
  git -C "$work" add .gitignore input.txt
  git -C "$work" commit -qm base
  printf 'changed\n' > "$work/input.txt"
  git -C "$work" add input.txt
  git -C "$work" commit -qm changed
  mkfifo "$ready" "$release"
  cat > "$runner" <<'RUNNER'
#!/usr/bin/env bash
set -euo pipefail
ready="$1"; release="$2"; pids="$3"
sleep 300 &
descendant=$!
printf '%s %s\n' "$BASHPID" "$descendant" > "$pids"
printf 'ready\n' > "$ready"
IFS= read -r _ < "$release"
wait "$descendant"
RUNNER
  chmod +x "$runner"
  printf -v test_cmd 'test -z "${PM_GATE_PARENT_OPERATION:-}" && bash %q %q %q %q' \
    "$runner" "$ready" "$release" "$pids"

  PM_DISPATCH_STATE_ROOT="$state" XDG_RUNTIME_DIR="$_GATE_CLI_XDG_RUNTIME_DIR" \
    "$PMCTL" gate run --lifecycle foreground --cd "$work" --base HEAD~1 \
      --tier express --mode sequential --reviewers critic,qa-tester \
      --executor codex --test-timeout 120 --test-cmd "$test_cmd" \
      >"$out" 2>"$err" &
  gate_pid=$!

  ready_value="$(timeout 60 cat "$ready")" || {
    kill "$gate_pid" 2>/dev/null || true
    wait "$gate_pid" 2>/dev/null || true
    fail "$name" "preflight never reached deterministic readiness; err=$(cat "$err" 2>/dev/null || true)"
    return
  }
  operation="$(sed -n 's/.*parent operation: \(op-[0-9TZ-]*[a-f0-9]\{6\}\).*/\1/p' "$err" | tail -1)"
  if [[ "$ready_value" != ready || ! "$operation" =~ ^op-[0-9]{8}T[0-9]{6}Z-[a-f0-9]{6}$ ]]; then
    kill "$gate_pid" 2>/dev/null || true
    wait "$gate_pid" 2>/dev/null || true
    fail "$name" "invalid readiness/operation: ready=$ready_value operation=$operation err=$(cat "$err" 2>/dev/null || true)"
    return
  fi

  started=$SECONDS
  cancel_out="$(PM_DISPATCH_STATE_ROOT="$state" "$PMCTL" gate cancel "$operation" --cd "$work" --grace 2 2>&1)" || cancel_rc=$?
  elapsed=$((SECONDS - started))
  wait "$gate_pid" || gate_rc=$?
  read -r producer_pid descendant_pid < "$pids"
  record="$(find "$state" -path "*/operations/$operation.json" -type f | head -1)"
  op_dir="${record%.json}"

  if [[ "$cancel_rc" -eq 0 && "$gate_rc" -eq 130 && "$elapsed" -lt 10 ]] \
     && [[ -n "$record" && "$(jq -r .state "$record")" == cancelled ]] \
     && [[ "$(jq -r .producer.status "$record")" == stopped ]] \
     && _gate_test_pid_stopped "$producer_pid" \
     && _gate_test_pid_stopped "$descendant_pid" \
     && [[ ! -s "$op_dir/children.jsonl" ]] \
     && ! find "$state" -type f -name 'gate-result-*.md' -print -quit 2>/dev/null | grep -q . \
     && { [[ ! -d "$work/.gate-results" ]] \
       || ! find "$work/.gate-results" -type f -name 'gate-result-*.md' -print -quit 2>/dev/null | grep -q .; } \
     && [[ "$cancel_out" == *"producer_failures: 0"* ]] \
     && [[ "$(cat "$err")" == *"foreground producer stopped (exit 130)"* ]]; then
    pass "$name"
  else
    fail "$name" "cancel=$cancel_rc:$cancel_out gate_rc=$gate_rc elapsed=$elapsed record=$(jq -c . "$record" 2>/dev/null || true) pids=$producer_pid,$descendant_pid err=$(cat "$err" 2>/dev/null || true)"
  fi
}

case_detached_cancel_surfaces_cancelled_wait_terminal() {
  local name="gate cancel: detached supervisor publishes cancelled wait terminal"
  should_run "$name" || return 0
  local fixture="$tmp_root/detached-cancel-fixture" work="$tmp_root/detached-cancel-work"
  local state="$tmp_root/detached-cancel-state" ready="$tmp_root/detached-cancel-ready"
  local release="$tmp_root/detached-cancel-release" pids="$tmp_root/detached-cancel-pids"
  local err="$tmp_root/detached-cancel-err" gate_id operation cancel_out wait_out
  local cancel_rc=0 wait_rc=0 producer_pid descendant_pid record op_dir
  mkdir -p "$fixture/core/schema" "$work"
  _mk_gate_cli_fixture "$fixture"
  for lib in pmctl-operation state-writer state-compat; do
    cp "$REPO_ROOT/runtime/lib/$lib.sh" "$fixture/runtime/lib/$lib.sh"
  done
  cp "$REPO_ROOT/core/schema/operation.schema.json" "$fixture/core/schema/operation.schema.json"
  cat > "$fixture/runtime/bin/pr-gate.sh" <<'FAKE_GATE'
#!/usr/bin/env bash
set -euo pipefail
sleep 300 &
descendant=$!
printf '%s %s\n' "$BASHPID" "$descendant" > "$TEST_GATE_PIDS"
printf 'ready\n' > "$TEST_GATE_READY_FIFO"
IFS= read -r _ < "$TEST_GATE_RELEASE_FIFO"
wait "$descendant"
FAKE_GATE
  chmod +x "$fixture/runtime/bin/pr-gate.sh"
  git -C "$work" init -q
  mkfifo "$ready" "$release"

  gate_id="$(PM_DISPATCH_STATE_ROOT="$state" XDG_RUNTIME_DIR="$_GATE_CLI_XDG_RUNTIME_DIR" \
    TEST_GATE_READY_FIFO="$ready" TEST_GATE_RELEASE_FIFO="$release" TEST_GATE_PIDS="$pids" \
    "$fixture/cli/pmctl" gate run --lifecycle detached --cd "$work" 2>"$err")"
  if [[ "$(timeout 60 cat "$ready")" != ready ]]; then
    fail "$name" "detached producer never reached readiness; gate=$gate_id err=$(cat "$err" 2>/dev/null || true)"
    return
  fi
  operation="$(sed -n 's/.*parent operation: \(op-[0-9TZ-]*[a-f0-9]\{6\}\).*/\1/p' "$err" | tail -1)"
  if ! [[ "$operation" =~ ^op-[0-9]{8}T[0-9]{6}Z-[a-f0-9]{6}$ ]]; then
    fail "$name" "detached operation id was not published: gate=$gate_id operation=$operation err=$(cat "$err" 2>/dev/null || true)"
    return
  fi
  cancel_out="$(PM_DISPATCH_STATE_ROOT="$state" XDG_RUNTIME_DIR="$_GATE_CLI_XDG_RUNTIME_DIR" \
    "$fixture/cli/pmctl" gate cancel "$operation" --cd "$work" --grace 2 2>&1)" || cancel_rc=$?
  wait_out="$(PM_DISPATCH_STATE_ROOT="$state" XDG_RUNTIME_DIR="$_GATE_CLI_XDG_RUNTIME_DIR" \
    PM_GATE_WAIT_POLL_INTERVAL=0.1 \
    "$fixture/cli/pmctl" gate wait "$gate_id" --cd "$work" --timeout 20 2>&1)" || wait_rc=$?
  read -r producer_pid descendant_pid < "$pids"
  record="$(find "$state" -path "*/operations/$operation.json" -type f | head -1)"
  op_dir="${record%.json}"

  if [[ "$cancel_rc" -eq 0 && "$wait_rc" -eq 130 ]] \
     && [[ "$wait_out" == *"state: cancelled"* && "$wait_out" == *"exit: 130"* ]] \
     && [[ -n "$record" && "$(jq -r .state "$record")" == cancelled ]] \
     && [[ "$(jq -r .producer.status "$record")" == stopped ]] \
     && _gate_test_pid_stopped "$producer_pid" \
     && _gate_test_pid_stopped "$descendant_pid" \
     && [[ ! -s "$op_dir/children.jsonl" ]] \
     && [[ "$cancel_out" == *"producer_failures: 0"* ]]; then
    pass "$name"
  else
    fail "$name" "cancel=$cancel_rc:$cancel_out wait=$wait_rc:$wait_out gate=$gate_id operation=$operation record=$(jq -c . "$record" 2>/dev/null || true) pids=$producer_pid,$descendant_pid err=$(cat "$err" 2>/dev/null || true)"
  fi
}

case_explicit_cd_passthrough
case_gate_run_refreshes_context_before_dispatch
case_default_cd_injected
case_exit_propagated
case_missing_gate_script
case_cd_missing_value_rejected
case_pmctl_routing
case_help_bypasses_detached_default
case_verify_valid
case_verify_v2_assurance
case_verify_v2_without_policy_remains_readable
case_verify_v2_named_consumer_is_not_authorizing
case_verify_v2_canonical_authorization
case_verify_v3_three_axes_current
case_verify_v3_producer_drift_reason_codes
case_verify_v3_policy_reason_codes
case_verify_v3_dirty_drift_is_stale_not_invalid
case_verify_v3_head_moved_is_stale
case_verify_v3_base_advanced_is_stale
case_verify_v3_fixed_ref_ignores_working_tree
case_verify_v3_linked_worktree_path_is_current
case_verify_v3_different_repo_same_content_is_stale
case_verify_v3_copy_replay_is_valid_but_not_authorizing
case_verify_v3_valid_but_policy_insufficient
case_verify_v3_linked_evidence_digest_tamper_is_invalid
case_verify_v3_subject_binding_mismatch_is_invalid
case_verify_v3_linked_preflight_subject_claim_mismatch_is_invalid
case_verify_v2_forged_state_tree_rejected
case_verify_v2_repo_binding_rejected
case_verify_v2_legacy_assurance_is_unavailable
case_verify_v2_claim_mismatch
case_verify_v2_policy_claim_tamper
case_verify_v2_surplus_topology_record
case_verify_v2_unknown_fields_rejected
case_verify_v2_result_binding_tamper
case_verify_v2_sidecar_attestation_tamper
case_verify_v2_subject_binding_tamper
case_verify_v2_canonical_run_mismatch
case_verify_v2_publication_race_retries
case_verify_v2_attestation_publication_race_retries
case_verify_v2_pointer_escape
case_verify_v2_missing_sidecar
case_verify_v2_empty_sidecar
case_verify_empty
case_verify_no_final
case_verify_parity_mismatch
case_verify_usage
case_verify_argument_errors
case_run_dir_forwarded_to_gate
case_default_lifecycle_is_detached
case_gate_wait_go_route_via_cli
case_gate_wait_nogo_route_via_cli
case_run_wait_handoff_survives_separate_process
case_wait_default_cd
case_foreground_gate_reconciles_parent_operation
case_detached_launcher_failure_terminalizes_childless_parent
case_gate_operation_routes_via_cli
case_gate_operation_cli_unavailable_fallbacks
case_foreground_cancel_stops_preflight_process_tree
case_detached_cancel_surfaces_cancelled_wait_terminal

th_summary
