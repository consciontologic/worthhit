# Worthhit delivery plan

## Worthhit identity, internationalization and releases — 2026-10-20

Goal: launch Worthhit at worthhit.com with a mature neo-brutalist light/dark UI,
localized workflows, adaptable identity, and reproducible static/container releases.

Boundaries: all application logic remains in Flutter; nginx serves static bytes.
Keep canonical appraisal schemas, legacy storage keys, explicit API actions and
human production approval. Browser language preferences replace IP geolocation.

Touched files: `lib/ui`, `lib/l10n`, preferences/controller integration, assets,
`web`, build/release/container tools, workflows, matching tests and existing guides.

Test plan: locale negotiation/override/RTL/numbers and persistence; theme changes
with retained drafts; phone/tablet/desktop light/dark screenshots; metadata and
public asset integrity; version/changelog/source/approval checks; ownership-safe
website publication; nginx static-only and immutable GHCR release checks.

- [x] Rename application/package/repository references to Worthhit without breaking stored data.
- [x] Add persisted system/light/dark preference and redesign adaptive interfaces.
- [x] Add translated UI, browser language negotiation, manual selection and RTL.
- [x] Deliver transparent identity, small-size favicon and non-white app-icon variants.
- [x] Add canonical metadata, crawler-readable content, sitemap and robots.
- [x] Implement SemVer, changelog, protected Gitflow and grouped release logging.
- [x] Implement ownership-safe GitOps publication to separate worthhit.com repository.
- [x] Build and verify a static-only non-root nginx image and GHCR release workflow.
- [x] Run independent review, required tests and bounded browser verification.
- [x] Publish protected source PRs, obtain human release approval and verify domain/package/release.

Reference: the supplied image was blocked by browser safety policy. The user approved an independent graphite, warm-neutral and lime editorial direction; no claim is made that the image was analyzed. A destination-only deployment key is configured. Domain TLS propagation is external. Local
browser data stays at its old origin; exports remain available. All validation limits
must distinguish local tests, live domain checks and actual package publication.

## Goal
Deliver a secure client-only Flutter PWA that turns evidenced second-hand comparables into an explainable estimate and fair negotiation guidance.

## Scope boundaries
No Go service, hosted database, shared API secret, autonomous purchases or unsupported custom domain. No claim that an LLM can establish an exact true price.

## Files
`lib/api/` owns OpenRouter; `lib/domain/` and `assets/appraisal_system_v1.txt` own appraisal; `lib/app/`, `lib/ui/`, `lib/platform/` own adaptive state and local storage. `web/`, `tool/`, `.github/workflows/`, documentation and tests own release and verification.

## Test plan
Test schema drift/zero prices/refresh/error/cancel boundaries; prohibited and insufficient-evidence appraisals; three adaptive layouts and state continuity; static-only worker and public artifact integrity. Run a separately bounded live evaluation and real browser checks. CI analyzes/tests/builds with no model credentials. Review source before guarded work-branch publication.

## Checklist
- [x] Record wfform API/UX audit and runtime decision.
- [x] Implement versioned appraisal instructions, schema and deterministic evidence gates with adversarial tests.
- [x] Implement bounded OpenRouter catalogue, endpoint metadata and completion client with failure tests.
- [x] Implement phone/tablet/desktop workflows, draft persistence and recoverable errors with widget tests.
- [x] Build verified PWA assets and secret-free GitHub CI/deployment workflow.
- [x] Complete independent review, verification, browser checks and bounded live evaluation.
- [x] Publish work branch and PR; complete protected promotion.
- [x] Complete human-approved production deployment and public checks.

## Risks
Live providers may reject a schema or be unavailable; preserve drafts and allow explicit retry/model choice. Search snippets may lack real sold comparables; abstain and request evidence. Browser storage is origin-local and may be cleared; surface save failures and export reports. Pages publication requires protection-compliant source promotion and human production approval.

## Publication status
[Worthhit 0.2.0 is live](https://worthhit.com), with enforced HTTPS and canonical
www/HTTP redirects. Source PRs [#7](https://github.com/consciontologic/worthhit/pull/7)
and [#8](https://github.com/consciontologic/worthhit/pull/8) are merged; the owner-approved
[release run](https://github.com/consciontologic/worthhit/actions/runs/39459449385)
published the matching GitHub release, public GHCR image and GitOps website.
All 65 public release files passed byte-count/hash checks. See
[publication evidence and limits](../DEPLOYMENT.md#verified-publication--2026-10-20).

### Historical 0.1.0 deployment

[Worthit was published](https://consciontologic.github.io/worthit/). Source PRs [#1](https://github.com/consciontologic/worthit/pull/1) and [#3](https://github.com/consciontologic/worthit/pull/3), and exact-tree promotions [#2](https://github.com/consciontologic/worthit/pull/2) and [#4](https://github.com/consciontologic/worthit/pull/4), are merged. The first deployment exposed a hidden-file archive mismatch; the corrected [release run](https://github.com/consciontologic/worthit/actions/runs/39440088378) deployed `d314ef56c9b6f2f6a59c885b9c30b15de4d0cae9` after the owner's production approval. All 41 published manifest assets passed size/hash verification, and the public UI restored its saved example after reload. See [deployment evidence and limits](../DEPLOYMENT.md) and [live evaluation](../LIVE_EVAL.md).
