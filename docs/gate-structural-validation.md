# Gate structural validation

Gate JSON artifacts use the schemas under `core/schema/gate-*.schema.json` as
their structural authority. The runtime copy-mode bundle is generated with:

```sh
tools/generate/gate-structural-validator.sh
```

The generator writes `runtime/lib/gate-structural-schemas.json`, which travels
with copied Gate runtime libraries. CI and release checks verify that the
checked-in bundle is current:

```sh
tools/generate/gate-structural-validator.sh --check
```

`runtime/lib/gate-structural-validator.jq` is a generic interpreter for the
JSON Schema vocabulary used by the Gate schemas: references, types, required
and closed object properties, arrays, enums, constants, patterns, numeric and
length bounds, composition, and the current conditional vocabulary. It does
not contain Gate field names or enum values.

The interpreter also owns the unknown-schema case: given a name the bundle does
not contain, it writes `unknown schema: <name>` and exits 9, and the shell
wrapper turns that into an execution failure. This keeps a wrong schema name
distinct from a schema violation — falling through to validation would report
it as `invalid schema node`, blaming the caller's instance — and it does so
without a second jq process probing the bundle for a name the validating pass
already receives.

`runtime/lib/gate-structural-verify.sh` exposes
`gate_structural_schema_verify <schema-name> <json-file>`. Gate result
verification calls it for policy overrides, scope manifests, assurance
envelopes, reviewer blocks, and synthesis blocks. The surrounding verifier
continues to own only claims that require multiple artifacts or runtime state:
scope/digest binding, reviewer selection, evidence membership and line bounds,
finding parity, dispatch evidence, and subject/policy consistency.
