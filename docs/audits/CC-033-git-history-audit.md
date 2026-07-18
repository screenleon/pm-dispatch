# CC-033 — Git history exposure audit

**Status**: audit slice complete

**Audit date**: 2026-07-18

**Baseline**: `b7799c31a459c2d69151c7c45b6ba1f4501fb5b7`

**Scope**: every commit reachable from local heads, remotes, and tags (`git rev-list --all`)

## Purpose and boundary

The repository was already public when CC-033 was rescoped. This audit checks
the complete reachable history for exposed credentials, maintainer-local paths,
and accidentally committed runtime artifacts. It does not change README copy or
GitHub collaboration settings; those remain in the v0.14.0 public-surface slice.

The baseline contained 493 reachable commits and 5,606 reachable objects across
31 refs. Of those commits, 450 were created on or after 2026-05-15, the date of
the previous pre-public review.

## Method

The scan was performed from a clean `main` worktree. All content searches used
`git grep` over `$(git rev-list --all)`, so deleted and superseded versions were
included rather than only the current tree. Matching commands emitted file paths
or redacted/hash summaries, never candidate secret values.

The checks covered:

- private-key headers;
- AWS, GitHub, OpenAI-style, Slack, and Google provider-token shapes;
- JWTs and credential-bearing URLs;
- credential-like assignments for API keys, client secrets, access tokens, and
  passwords;
- sensitive or runtime-artifact filenames such as `.env`, private-key files,
  `credentials`, `settings.json`, `.agent-trace`, gate/dispatch results,
  `events.jsonl`, `runs.jsonl`, and context databases;
- blobs larger than 1 MiB;
- maintainer-specific `/home/screenleon` and `/Users/screenleon` paths;
- author-email uniqueness across all reachable commits.

GitHub state was checked read-only with:

```sh
gh repo view --json nameWithOwner,isPrivate,url
gh api 'repos/screenleon/pm-dispatch/secret-scanning/alerts?state=open&per_page=100'
```

For a future rerun, use the same baseline-independent primitives:

```sh
revs=$(git rev-list --all)
git grep -I -l -E '<secret-shape-regex>' $revs --
git log --all --name-only --format= | sed '/^$/d' | sort -u
git rev-list --objects --all |
  git cat-file --batch-check='%(objecttype) %(objectsize) %(rest)'
git log --all --format='%ae' | sort -u
```

Candidate values must be reviewed locally and redacted before they are copied
into an issue, PR, or audit report.

## Results and disposition

| Area | Result | Disposition |
|------|--------|-------------|
| High-confidence credentials | No private-key header, JWT, credential URL, or credential-like assignment matched. | No rotation or history rewrite required by this scan. |
| Provider-token shapes | Eight unique `sk-`-shaped strings appeared across six historical paths. Redacted line review showed only secret-redaction test fixtures and a `task-...` filename substring false positive. | Keep: synthetic regression data is intentional and no candidate is a live credential. |
| Sensitive filenames | No sensitive credential filename or repo-local runtime/state artifact filename was found in history. | No cleanup required. Existing ignore rules remain the prevention layer. |
| Large blobs | No historical blob exceeded 1 MiB. | No artifact purge required. |
| Maintainer-local paths | 2,147 revision/path matches across 16 historical paths; the baseline tree retains eight files. Current matches are historical spike/backlog evidence plus one synthetic install fixture, not credentials. | Do not rewrite public history: that would be disruptive without removing an active secret. Retain provenance; public-copy cleanup may replace non-load-bearing examples during CC-033's v0.14.0 slice. |
| Commit email | All 493 commits use one personal Gmail author address. | Treat as public identity metadata, not a credential. The maintainer should decide before the next commit whether to switch future commits to the GitHub no-reply address; rewriting published history is not justified by this audit alone. |
| GitHub secret scanning | Repository visibility is public, but the alerts endpoint reports that secret scanning is disabled. | Add enablement/verification to the v0.14.0 GitHub-settings checklist. Until then, this local audit is point-in-time evidence, not continuous protection. |

## Residual risk

Regex scanning cannot prove the absence of an unknown or unstructured secret,
and GitHub secret scanning was unavailable as an independent signal because it
is disabled. The result therefore means “no actionable exposure found by the
documented full-history checks,” not an absolute guarantee that history is
secret-free.

No destructive history rewrite, credential rotation, or GitHub setting mutation
was performed. If a future scanner produces a concrete credential finding, stop
publication work, revoke/rotate the credential first, then assess whether a
history rewrite is worth the disruption; deletion alone never unexposes a
credential that has already been public.
