# Worthhit Gitflow

Use the wfform delivery model with the web-only Worthhit checks and release targets.

| Work | Base | Work branch | PR target |
|---|---|---|---|
| Feature or bug fix | develop | `codex/feature/*` / `codex/bugfix/*` | develop |
| Release preparation | develop | `release/MAJOR.MINOR.PATCH` | develop |
| Production hotfix | main | `hotfix/*` / `codex/hotfix/*` | main, then back-merge to develop |
| Exact-source promotion | validated develop | develop | main |

`claude/` prefixes are also supported for feature, bugfix and hotfix branches.
Never implement or directly publish source on `main` or `develop`. Preserve dirty
work and concurrent edits. Do not force push, bypass protections, move an existing
release tag or replace release assets.

After relevant tests, full `make verify`, public build and review, the coordinating
parent appends a conventional completion row through
`xops/agent/tracking_append.sh`, inspects the complete staging set, runs
`git add -A`, reviews `make git.dry`, then uses `make git`. Delegates return evidence
and do not stage/publish. Open or update a reviewed PR and report its commit,
tracking run ID and checks. A published branch is not a merged release.

**Verify** and **Security** run for PRs into develop and hotfix PRs into main.
Other main promotions preserve the exact tested source tree and do not repeat
those jobs. The release authorizer independently verifies the previous successful
jobs, preventing a skipped promotion run from being used as quality evidence.
Ordinary pushes do not publish or trigger quality pipelines.

Release versions are plain SemVer in `pubspec.yaml`, with dated entries in
`CHANGELOG.md`. Both the Git tag and GitHub release name must exactly match
`MAJOR.MINOR.PATCH` (for example, `1.0.0`), without a product-name or `v` prefix.
The explicit **Packages and release** dispatch on main builds one
artifact, then waits for the human owner's production approval before tags,
releases, GHCR or website publication. See [deployment](DEPLOYMENT.md) for the
required source evidence, environment, key scope and recovery rules.

The website repository is a generated artifact destination. The approved release
publisher may commit/push only its hash-verified managed paths there; this exception
does not authorize direct source commits. Other destination content is preserved.
