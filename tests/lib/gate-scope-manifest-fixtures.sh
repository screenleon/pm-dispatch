#!/usr/bin/env bash
# Shared gate_scope_manifest_v1 JSON fixture builder, used by both
# test-core-schemas.sh (schema-shape validation) and
# test-gate-scope-manifest-verify.sh (gate_scope_manifest_verify cross-field/
# external behavior). One canonical "what does a valid scope manifest look
# like" definition, per the same reuse lesson as CC-533's gate_assurance_verify
# fixtures: two independently hand-rolled copies silently drift out of sync
# with core/schema/gate-scope-manifest.schema.json without anyone noticing.

_gate_scope_manifest_valid_instance() {
  jq -n '{
    kind:"gate_scope_manifest_v1",
    schema_version:1,
    status:"complete",
    subject:{
      repository_key:("a" * 64),
      base_commit:("b" * 40),
      head_commit:("c" * 40),
      tree_fingerprint:("d" * 64),
      subject_kind:"committed_head"
    },
    selection:{
      diff_kind:"committed",
      base_ref:"main",
      head_ref:"HEAD",
      include_untracked:false
    },
    changes:{
      entries:[{
        status:"modified",
        old_path:null,
        new_path:"runtime/bin/example.sh",
        similarity:null
      }],
      changed_paths:["runtime/bin/example.sh"],
      renamed_paths:[],
      untracked_paths:[]
    },
    diff:{
      hunks:[{
        path:"runtime/bin/example.sh",
        source:"tracked",
        old_start:10,
        old_lines:1,
        new_start:10,
        new_lines:2,
        header:"@@ -10 +10,2 @@"
      }],
      binary_or_special_paths:[]
    },
    paired_tests:[{
      source_path:"runtime/bin/example.sh",
      test_path:"tests/shell/test-example.sh",
      reason:"language-convention"
    }],
    sensitive_signals:[{
      id:"public-contract",
      source:"path-regex",
      matches:["runtime/bin/example.sh"],
      minimum_tier:"standard",
      required_reviewers:["architecture-reviewer"],
      recommended_mode:"parallel"
    }],
    flags:{
      public_interface:{matched:false,paths:[]},
      schema:{matched:false,paths:[]},
      config:{matched:false,paths:[]},
      install:{matched:false,paths:[]},
      ci:{matched:false,paths:[]},
      release:{matched:false,paths:[]},
      migration:{matched:false,paths:[]}
    },
    expansion:{
      claim:"bounded-hints-not-complete-call-graph",
      entries:[{
        path:"tests/shell/test-example.sh",
        reason:"same-stem-peer",
        source:"runtime/bin/example.sh",
        evidence:"peer-convention",
        limit:{kind:"per-source",maximum:64}
      }],
      included_paths:["tests/shell/test-example.sh"]
    },
    reference_index:{
      claim:"declared-review-reference-set",
      entries:[
        {
          path:"runtime/bin/example.sh",
          snapshot:"subject",
          line_count:40,
          sha256:("f" * 64)
        },
        {
          path:"tests/shell/test-example.sh",
          snapshot:"subject",
          line_count:80,
          sha256:("0" * 64)
        }
      ]
    },
    truncation:{
      occurred:false,
      budgets:{
        diff_hunks:512,
        expansion_source_paths:256,
        symbols_per_source:1024,
        matches_per_query:64,
        contract_consumers_per_source:128,
        expansion_entries:512
      },
      omitted:{
        diff_hunks:0,
        expansion_source_paths:0,
        symbols_per_source:0,
        matches_per_query:0,
        contract_consumers_per_source:0,
        expansion_entries:0
      },
      reasons:[],
      acceptance:{required:false,accepted:false,source:null}
    },
    content:{
      digest_algorithm:"sha256-canonical-json-without-content-digest",
      digest:("e" * 64)
    }
  }'
}
