# Delivery

Source: [consciontologic/worthit](https://github.com/consciontologic/worthit).
Pages destination: [consciontologic.github.io/worthit](https://consciontologic.github.io/worthit/).
The corrected human-approved deployment completed on 2026-10-20.
No custom domain is configured.

## Verified release
[Run 39440088378](https://github.com/consciontologic/worthit/actions/runs/39440088378)
successfully deployed source `d314ef56c9b6f2f6a59c885b9c30b15de4d0cae9`
after the approval receipt identified `consciontologic` and `production`.
Public release generation:
`47b35b34791a9581f29f05ae24d1b7a0a7bbbb2214ff3a6b7b5c0c751ea46389`.
All 41 manifest assets (42,471,679 bytes) returned HTTP 200 and matched their
recorded size and SHA-256. The standalone manifest and versioned worker were
available. The first release included `.last_build_id`, which Pages omits;
the corrected manifest excludes hidden paths and retains strict integrity checks.

The public browser rendered the app, refreshed 19 free OpenRouter models, and
restored its saved synthetic report after reloading the corrected release.
No browser warnings or errors were captured. Phone, tablet and desktop flows
were separately checked in the local production build. Local verification passed
127 Flutter tests, the compiled JavaScript pricing regression, 8 worker tests and
10 Python build/release tests. Independent review and an archive-level check
using the pinned Pages action's exclusions passed.

Worker tests and public asset verification do not establish real-device
installation, airplane-mode operation or the full browser update lifecycle;
those checks remain unverified. Live OpenRouter outcomes and their limitations
are recorded separately in [LIVE_EVAL.md](LIVE_EVAL.md).

## Release procedure

1. Work on a `codex/feature/*` or `codex/bugfix/*` branch from `develop`.
2. Run `make verify` and `make build.public`. Append a conventional completion
   row with `xops/agent/tracking_append.sh`, inspect all changed files, stage them,
   and run `make git.dry` then `make git`.
3. Open a PR to `develop`. **Verify** analyzes/tests/builds; **Security** checks
   publication boundaries and credential patterns. CI has no model or user keys.
   Review and resolve conversations before merging.
4. Promote the exact validated source tree to `main` through a reviewed PR.
   Main/develop reject direct pushes, force pushes and deletion. Configured human
   approval count is zero; independent code review still belongs in the evidence.
5. Dispatch **Publish Worthit** on `main`. Its read-only source guard verifies
   a successful prior PR run for the exact tree. It builds the public static
   artifact; it does not repeat quality/security pipelines during promotion.
6. **consciontologic** approves the `production` deployment. Only `main` is
   eligible. Agents must never approve or bypass this gate. A read-only guard
   checks the actual human approval receipt, not merely the absence of a wait.
7. Verify the deployed app, static manifest, browser layout and offline shell.

The workflows pin actions and Flutter. Cache keys include OS, Flutter and the
lockfile; model keys and release artifacts are not dependency-cache inputs.
Pages uses the built-in scoped workflow token and OIDC. Temporary chat credentials
are never stored as permanent GitHub secrets or copied into CI/browser assets.

`make build.public` disables the generated Flutter worker, bundles rendering
resources locally, creates a SHA-256 manifest and injects a distinct Worthit shell
generation. It scans the source and build for credential patterns. The worker
does not intercept authenticated requests, non-GET requests, external URLs or
configuration paths. It admits only manifest-listed static bytes.

Updates are prepared in the background. In-session activation requires an
explicit app action after the draft is saved; the browser can also activate a
waiting worker after all controlled tabs close. An incomplete/corrupt shell is
removed. Older tab generations are retained until safe cleanup. Stored reports
are dated observations, not automatically refreshed market prices.

Validation evidence must distinguish deterministic tests, actual browser checks,
bounded authenticated OpenRouter evaluations and public deployment checks. A green
mocked test suite is not evidence of current provider availability or resale-price
accuracy. Real-device installation/virtual keyboard behavior needs device testing.
