# CC-521 live test-gap evaluation fixture

Use `multi-gap-v1.json` as the seeded scenario inventory for repeated live
review runs, then analyze two or more resulting Gate Markdown artifacts:

```bash
tools/eval/gate-test-gap-live-eval.sh \
  --fixture tests/fixtures/gate-live-eval/multi-gap-v1.json \
  --result /path/to/run-1.md \
  --result /path/to/run-2.md \
  --output /tmp/cc521-live-report.json
```

The report records per-run detected/missed seeds, mean recall, range, variance,
and an optional regression observation against `--baseline`. Its
`correctness_gate` field is always `false`: model recall is observable quality,
not a deterministic CI pass/fail invariant.
