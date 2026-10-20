# Delivery

Source: [consciontologic/worthit](https://github.com/consciontologic/worthit).
Pages destination: [consciontologic.github.io/worthit](https://consciontologic.github.io/worthit/).
The first human-approved deployment completed on 2026-10-20. Public checks found
a hidden build metadata file missing from the Pages archive; the follow-up build
excludes hidden paths from the offline manifest. Verify all listed assets after
the corrected deployment. No custom domain is configured.

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
removed. Older tab generations are retained until safe cleanup. Stored reports are dated observations, not
automatically refreshed market prices.

Validation evidence must distinguish deterministic tests, actual browser checks,
bounded authenticated OpenRouter evaluations and public deployment checks. A green
mocked test suite is not evidence of current provider availability or resale-price
accuracy. Real-device installation/virtual keyboard behavior needs device testing.
