# Worthhit delivery

Source: [consciontologic/worthhit](https://github.com/consciontologic/worthhit).
Static destination: [consciontologic/worthhit.com](https://github.com/consciontologic/worthhit.com).
Canonical site: [worthhit.com](https://worthhit.com).
Container: `ghcr.io/consciontologic/worthhit:<version>` (Linux amd64).

## 1.1.0 release preparation — 2026-10-20

The local gate passed 201 Flutter, 19 Node and 39 Python tests, compiled-JavaScript
pricing checks, analysis, formatting, repository hygiene and version consistency.
The public build and sealed web/container archives passed. The separately labeled
Docker Snap smoke passed with the existing limitation below; strict CI must pass.
Independent review findings were fixed and covered by regression tests.

Browser previews checked 390px phone, 850px tablet and 1440px desktop flows,
light/dark themes, Arabic glyphs/RTL and public information pages. A real worker
transition between two isolated candidate generations showed Update ready without
reloading the form, retained the action in Settings after Later, and loaded the
new generation only after Update while restoring a synthetic saved draft. No app
console warnings/errors were observed. Browser text highlighting was confirmed;
clipboard contents were verified through actual selection/copy/paste widget tests,
because the browser automation's virtual clipboard did not capture Flutter writes.
Controller failure/disposal and bootstrap lifecycle safeguards have deterministic
coverage. The browser-store timeout/listener cleanup was source-reviewed; this
browser run establishes successful activation, not induced timeout/disposal or a
real-device install claim.

Production remains 1.0.0 until the owner approves the new release workflow. The
release name and tag for this change are plain `1.1.0`.

## Verified publication — 2026-10-20

[Release 1.0.0](https://github.com/consciontologic/worthhit/releases/tag/1.0.0)
was published from `46bc4377b2f2ffca17f72e4a810588e725e3bcef` after
consciontologic approved
[production run 39471637467](https://github.com/consciontologic/worthhit/actions/runs/39471637467).
Feature and promotion PRs [#10](https://github.com/consciontologic/worthhit/pull/10) and
[#11](https://github.com/consciontologic/worthhit/pull/11), followed by the registry
fix and promotion [#12](https://github.com/consciontologic/worthhit/pull/12) and
[#13](https://github.com/consciontologic/worthhit/pull/13), are merged.
[Required CI](https://github.com/consciontologic/worthhit/actions/runs/39471127722)
passed, including the strict nginx smoke with `no-new-privileges`. Local verification
passed 167 Flutter, 13 Node and 38 Python tests, analysis and repository checks.

GitOps published website commit `4f02df0252a6147477f765c2f8ad1d01feed3f4a`.
All 67 public release files (65 manifest assets, the manifest and service worker)
passed byte-count and SHA-256 checks against the published release archive and
identity. The generation is
`4dd8b25748d2b85bbf75dbc774bc182466413e0d64347ab0d74c45d6e2113650`.
HTTP apex and HTTP/HTTPS www each redirect directly to `https://worthhit.com/`.
The root, About, Terms and Liability pages each contain exactly one Google tag
loader and configuration for `G-G4SYW37S81`, with correct canonical URLs.
Public version metadata and information-page footers show 1.0.0.
The live browser offered an explicit update from the cached 0.2.0 app and then
rendered the 1.0.0 footer without app console warnings/errors. Its Terms link opened
the published document in a separate tab while retaining the price-check workspace.
At 390px width, the navigation drawer showed version 1.0.0, GitHub and all three
information links in its compact Info menu.

All five GitHub release assets passed size/checksum verification. The anonymously
accessible Linux amd64 GHCR image has registry digest
`sha256:90e166cc453386a071c4fbdaf1fc6352c9a9176ab7ea4152b50393e3c3cbf147`;
its configuration matches the released container archive and retains UID/GID 101.
Google Analytics property receipt/configuration, search-engine indexing and
installation on physical devices are not established by these checks.

### Historical 0.2.0 publication

[Release 0.2.0](https://github.com/consciontologic/worthhit/releases/tag/0.2.0)
was published from `74db1e5277461329d89ff592d677817292898131` after the
owner approved [production run 39459449385](https://github.com/consciontologic/worthhit/actions/runs/39459449385).
Source PRs [#7](https://github.com/consciontologic/worthhit/pull/7) and
[#8](https://github.com/consciontologic/worthhit/pull/8) are merged; the
[required CI](https://github.com/consciontologic/worthhit/actions/runs/39458814513)
passed, including the strict nginx container smoke with `no-new-privileges`.

GitOps published website commit `07c0daacb54bf2fc92dcb3de4448e5d2f32f4fc3`.
HTTPS is enforced for worthhit.com; HTTP and www redirect to the canonical HTTPS
root. All 65 release files (63 manifest assets plus the manifest and service worker)
passed public byte-count and SHA-256 verification.
The public generation is
`ef541b79ea83edbcc4157061da168a6eae4079990a1da932eb2ae75dd0a53f03`.
The live browser rendered both themes without console warnings or errors.
The versioned GHCR image and its published archive match; it is anonymously pullable at registry digest
`sha256:2a4f5e2bfdf27223665df3d2d5016022c8e5d845898c77ee2e60f92d85694159`.

The 0.2.0 DNS check found three GitHub Pages A records; the documented fourth is
`185.199.111.153`. This did not prevent that verified HTTPS deployment; the A-record
count was not rechecked for 1.0.0.

## Release procedure

1. Follow [Gitflow](GITFLOW.md). Set the plain `MAJOR.MINOR.PATCH` in `pubspec.yaml`
   and add its dated `CHANGELOG.md` entry. Run `make version.sync` to update the
   Flutter identity and public document versions; `make verify` and public builds
   reject version drift. Publish validated source with `make git`.
2. Merge a reviewed feature/release PR into `develop` after **Verify** and **Security**.
   Verify includes Dart checks, public build, release packaging and an actual nginx
   container smoke. No CI job receives an OpenRouter key or sends an appraisal.
3. Promote the exact validated tree through a reviewed PR to `main`. Ordinary
   promotions do not repeat the quality/security jobs. Hotfix PRs to `main` run them.
4. Dispatch **Packages and release** (`pages.yml`) on `main`. A read-only source
   guard requires current main and successful prior PR **Verify**/**Security** jobs
   for exactly its tree; skipped jobs cannot authorize publication. The workflow
   builds the root-path static app and Linux amd64 image once, saves release
   archives/checksums, and uploads one source-specific artifact.
5. **consciontologic** approves the `production` deployment. Its only allowed branch
   is `main`, and its sole required reviewer is owner ID `339074048`. Agents may
   never approve or bypass it. Publication independently verifies the actual human
   receipt, workflow path, dispatch event, source SHA and environment policy.
6. The gated job downloads and verifies those exact bytes without rebuilding,
   rejects existing version conflicts, publishes GHCR, pushes managed website
   artifacts to `worthhit.com/main`, then publishes a Git tag and GitHub release
   both named exactly `MAJOR.MINOR.PATCH`, without a product-name or `v` prefix.
   Resumed drafts receive the same plain version name when finalized.
   The website repository's Pages branch deployment serves `/`.
7. Verify HTTPS/domain redirects, `release.json` plus all asset hashes, browser
   rendering and the package/release links. A green unit suite does not prove DNS,
   search-engine indexing or real-device PWA installation.

## One-time repository setup

Keep source `main` and `develop` PR-only, disallow force pushes/deletion and require
resolved review conversations. `develop` requires Verify and Security; ordinary
main promotions retain the source evidence already checked on develop. Production
requires the owner reviewer and a custom **main only** branch policy. Preserve
self-review eligibility for the sole human maintainer, never approval bypass.

Create the separate public `consciontologic/worthhit.com` artifact repository with
`main`. Configure GitHub Pages from **main / root** and custom domain `worthhit.com`.
The workflow owns the root `CNAME` and `.nojekyll`. An unrelated README is preserved;
pre-existing files at generated paths must be explicitly reconciled before first
publication. After successful DNS validation, enable Pages HTTPS enforcement.

Create a write-enabled SSH deploy key on **only worthhit.com**. Store its private
key as `WORTHHIT_DEPLOY_KEY` in the source repository's **production** environment.
No personal token is retained. The publisher uses a temporary 0600 key and explicit
known-hosts obtained from GitHub's HTTPS metadata API, strict host checking, no
ambient SSH configuration and no global credential changes. It verifies the
repository owner ID before cloning. See [GitHub's SSH host-key guidance](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/githubs-ssh-key-fingerprints).

GHCR and source release writes use the job-scoped `GITHUB_TOKEN` with
`packages: write` and `contents: write`; the build job is read-only. The image's OCI
source label links it to the source repository. On first publication, confirm the
package's visibility/access settings allow intended consumers; new GHCR packages
can begin private. See [GitHub Container registry](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry).

For DNS, `www` is a CNAME to **consciontologic.github.io**, without a repository or
`.git` suffix. The apex uses GitHub Pages A records (`185.199.108.153`,
`185.199.109.153`, `185.199.110.153`, `185.199.111.153`) or supported ALIAS/ANAME.
The repository's `CNAME` file contains **worthhit.com**. Verify the domain in the
GitHub owner account and confirm DNS/TLS propagation separately; DNS does not
publish application files. [Official Pages domain instructions](https://docs.github.com/en/pages/configuring-a-custom-domain-for-your-github-pages-site/managing-a-custom-domain-for-your-github-pages-site).

## Integrity, ownership and recovery

`make build.public` disables Flutter's generated worker, bundles rendering
resources locally, removes private build markers, and generates a SHA-256 static
manifest with source SHA and app version. The custom worker hashes every admitted
asset and never caches API calls, credentials, drafts or reports. Activation is
explicit during a session; existing controlled tabs retain their generation.

`make release.prepare` creates the deterministic web tarball, release notes,
source identity and checksum list. `make image` uses a generated context containing
only verified static files, three nginx configurations, Dockerfile and ignore
rules. The official nginx image is pinned by version and SHA-256 digest at
`docker.io/library/nginx`. This replaces the public ECR mirror, which returned
HTTP 429 “Data limit exceeded” during release builds. The version and digest are
unchanged, so only the download registry changes. [GitHub documents](https://docs.github.com/en/actions/reference/limits#docker-hubs-rate-limit-for-github-actions)
that hosted runners pulling public Docker Hub images are exempt from its pull-rate
limit; local/self-hosted runners and general registry outages remain separate limits.
The image runs as UID/GID 101 on port 8080; only GET/HEAD static requests are accepted.
Asset misses are real 404s, headers apply
also to errors, and access logs omit request URLs/queries. Native nginx error logging is
suppressed because its unstructured messages can expose request URLs; startup
and health checks report failures instead. There is no API proxy,
application server, database or embedded configuration. TLS is terminated by the
hosting platform or an operator's ingress.

The website ownership manifest records every managed path and its hash. Before
writing, the publisher checks all previous hashes, rejects symlinks, traversal,
unowned collisions, foreign ownership and manually edited managed files. Only
managed changes are staged; unrelated files survive. Source main is rechecked
before push. Destination races fail with a normal rejected push, never force.
The source repository still uses the guarded `make git` wrapper; generated website
commits are the explicitly authorized GitOps exception.

Plain SemVer tags, release assets and versioned image tags are never overwritten.
A matching partial draft can resume by uploading only missing assets; a conflicting
hash/source or incomplete published release fails closed. No floating `latest`
image is published. Publication spans separate GitHub services and is not atomic:
a later website/release failure may leave an already published image. Inspect the
failure, then rerun the **failed publish job in the same workflow run** so it reuses
the same approved artifact. Do not rebuild, move tags, replace assets or replay an
old source after main advances. Artifact retention is 14 days; an expired artifact
requires a new release version and normal approval. If a build fails before publication
and a source fix is required, validate and promote that fix normally, then start a
new release dispatch on current main. Do not rerun the old source after main has
advanced; the source guard rejects it. An unpublished version may be retained only
when the tag, release and package preflights find no conflict.

Local equivalents:

```sh
make verify
make build.public
make release.prepare
make image
make image.test
python3 tool/release.py verify
```

`make image.test` checks the real image with a read-only filesystem, dropped
capabilities and a bounded `/tmp` mount. To run a published image:

```sh
docker run --rm --read-only --cap-drop=ALL --security-opt=no-new-privileges \
  --tmpfs=/tmp:rw,noexec,nosuid,size=32m -p 127.0.0.1:8080:8080 \
  ghcr.io/consciontologic/worthhit:1.0.0
```

Local validation on 2026-10-20 found a workstation Docker Snap limitation:
`no-new-privileges` prevents execution even of `/bin/sh` with `operation not
permitted`. The separately labeled local HTTP smoke omits only that option while
retaining non-root, read-only and dropped-capability checks. The default CI smoke
retains it and must pass before release; the local variant is not evidence that
this option works on the workstation. No host security policy was changed.

Actions, Flutter and nginx are pinned. Dependency caches are scoped by OS, Flutter
version and lockfile, excluding keys/artifacts. Colorful grouped `tool/ci-step.sh`
output preserves command exit status; local `safe-run.sh` retains diagnostic logs.
Live provider evidence and accuracy limitations remain in [LIVE_EVAL.md](LIVE_EVAL.md).
The original Worthit Pages deployment and 41 verified assets are historical 0.1.0
evidence, not proof of this new domain/container release.
