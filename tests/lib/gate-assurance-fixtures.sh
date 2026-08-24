#!/usr/bin/env bash
# Shared gate_assurance_v2/v3 JSON fixture builders, used by both
# test-core-schemas.sh (schema-shape validation) and
# test-gate-assurance-verify.sh (gate_assurance_verify cross-field/external
# behavior). One canonical "what does a valid assurance document look like"
# definition — see reuse finding on CC-533: two independently hand-rolled
# copies silently drift out of sync with core/schema/gate-assurance.schema.json
# without anyone noticing, exactly the skew CC-533 exists to eliminate.

_gate_assurance_valid_instance() {
  jq -n '{
    kind:"gate_assurance_v2",
    schema_version:2,
    result:{final:"GO"},
    bindings:{
      result_sha256:("a" * 64),
      repo_root:"/tmp/repo",
      repo_identity:("b" * 64),
      base_commit:("c" * 40),
      head_commit:("d" * 40),
      subject_fingerprint:("e" * 64)
    },
    coordinates:{
      tier:{requested:"standard",resolved:"standard",evidence_floor:"critic plus QA"},
      mode:{
        requested:"sequential",
        resolved:"sequential",
        topology:"combined-session",
        synthesis:"inline"
      },
      pass:{
        requested:"initial",
        resolved:"initial",
        scope:"comprehensive",
        initial_result:null
      },
      coverage:{
        requested:null,
        selected:["critic","qa-tester","architecture-reviewer"],
        skipped:["security"],
        vocabulary:["critic","qa-tester","architecture-reviewer","security"]
      },
      independence:{
        implementation_context_isolated:null,
        reviewer_topology:"combined-session",
        per_reviewer_independent:null,
        evidence_status:"unavailable"
      }
    },
    policy:{
      kind:"gate_policy_resolution_v1",
      schema_version:1,
      consumer_policy:"generic",
      policy_source:"canonical",
      scope_fingerprint:("f" * 64),
      request:{
        tier:"standard",
        mode:"sequential",
        pass_kind:"initial",
        reviewers:null
      },
      classification:{
        architecture_impact:"unknown",
        line_changes:120,
        binary_or_unknown_count:0,
        layer_roots:["runtime"]
      },
      resolution:{
        minimum_tier:"standard",
        required_reviewers:["critic","qa-tester","architecture-reviewer"],
        recommended_mode:"parallel",
        mode_selection_source:"user",
        mode_recommendation_overridden:true,
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
          id:"medium-change",
          source:"classification",
          matches:["changed-lines:120"],
          minimum_tier:"standard",
          required_reviewers:["architecture-reviewer"],
          recommended_mode:"parallel"
        }
      ],
      resolved:{
        tier:"standard",
        mode:"sequential",
        reviewers:["critic","qa-tester","architecture-reviewer"]
      },
      enforcement:{status:"pass",violations:[]},
      override:{
        status:"not_provided",
        source:null,
        sha256:null,
        reason:null,
        approver:null
      },
      reviewer_override:{status:"not_provided",source:null,sha256:null}
    },
    dispatch:{
      outcomes:[{
        role:"combined",
        reviewer:null,
        status:"passed",
        run_id:null,
        evidence_status:"unavailable"
      }]
    },
    provenance:{producer:"pr-gate.sh",policy_source:"canonical",attestation:null}
  }'
}

_gate_assurance_v3_valid_instance() {
  _gate_assurance_valid_instance |
    jq '
      .kind = "gate_assurance_v3" |
      .schema_version = 3 |
      .coordinates.tier.selection_basis = "explicit" |
      .coordinates.coverage.selection_basis = "policy-default" |
      .subject = {
        kind:"gate_subject_v1",
        schema_version:1,
        repository:{
          key:("b" * 64),
          git_common_dir_identity:("1" * 64),
          remote_identity:null
        },
        observed:{root:"/tmp/repo",git_common_dir:"/tmp/repo/.git"},
        base:{ref:"main",commit:("c" * 40)},
        head:{ref:"HEAD",commit:("d" * 40)},
        tree_fingerprint:("e" * 64),
        subject_kind:"committed_head",
        dirty_policy:"require_clean",
        created_at:"2026-07-28T00:00:00Z",
        finished_at:"2026-07-28T00:01:00Z",
        observed_at_finish:{
          repository_key:("b" * 64),
          base_commit:("c" * 40),
          head_commit:("d" * 40),
          tree_fingerprint:("e" * 64)
        }
      } |
      .evidence = {
        preflight:{
          status:"linked",
          outcome:"pass",
          artifact:"preflight-evidence-20260728-000000.json",
          sha256:("2" * 64),
          subject_fingerprint:("e" * 64)
        },
        scope_manifest:{
          status:"unavailable",
          artifact:null,
          sha256:null,
          subject_fingerprint:null
        },
        closure:{
          status:"unavailable",
          artifact:null,
          sha256:null,
          subject_fingerprint:null
        }
      }
    '
}
