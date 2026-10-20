# Worthhit delivery plan

## Worthhit 1.1.0 compact and usable interface — 2026-10-20

Goal: give phone/tablet users more working space, concise icon-led controls,
selectable content and a clear, safe notification when a new app release is ready.

Boundaries: retain the graphite/neutral/lime identity, eight languages, accessible
touch targets, financial/privacy disclosures, direct APIs and explicit update
activation. No automatic reload, private-content clipboard writes or API resends.

Files: adaptive workspace/editor/results/settings/footer, shared icons and theme,
translations, update controller/browser bridge/bootstrap, matching tests and
brand assets; version/changelog and existing architecture/deployment guides.

Test plan: compact control heights at phone/tablet sizes, keyboard/large-text/RTL
usability, selection and copy of visible content, preserved form editing, icon
contrast/semantics, remote update discovery and offline/retry/busy/save failures,
full local gate/public build, independent review and browser checks.

- [x] Add a cohesive Worthhit vector icon family and integrate action/navigation symbols.
- [x] Compact phone/tablet controls and reduce repeated guidance through contextual help.
- [x] Enable selection/copy across app content, dialogs and reports without breaking input.
- [x] Discover remote releases and show an accessible dismissible update notice.
- [x] Set 1.1.0, finish localization, documentation, tests and browser validation.
- [x] Publish protected source/promotion and prepare 1.1.0 for owner production approval.
- [x] After owner approval, verify the live release, package and PWA update.

Risks: overly small controls harm touch access; retain at least 44px hit targets
and let large text expand. Icon-only actions need tooltips/semantics. Update discovery
must be bounded and must not discard unsaved work or interrupt an active request.

## Worthhit 1.0.0 information and analytics — 2026-10-20

Goal: publish version 1.0.0 with Google tag G-G4SYW37S81, useful public information
pages and wfform-style adaptive footer/drawer navigation.

Boundaries: static client-only hosting, existing valuation/provider contracts and
human production approval stay intact; no custom analytics events for user content,
credentials or reports, and no invented legal jurisdiction or compliance guarantees.

Files: Flutter footer/workspace/platform link helpers and translations; static About,
Terms and Liability pages, analytics/CSP/sitemap/PWA worker; version identity and
release tooling, tests, changelog, README and delivery documentation.

Tests: visible footer/drawer and link failures at compact/large text layouts, retained
drafts, one configured tag per page, CSP hashes/hosts, metadata/cross-links/version
consistency, offline directory documents, unchanged API behavior and nginx delivery.

- [x] Add shared adaptive footer/drawer information, source and version links.
- [x] Complete About, Terms and Liability pages with accurate data/analytics disclosures.
- [x] Integrate the single Google tag on every page and keep startup/offline caching independent.
- [x] Set and verify the single 1.0.0 release identity and dated changelog.
- [x] Complete tests, independent review, public build and browser/container checks.
- [x] Publish protected source PR/promotion, obtain owner production approval and verify live 1.0.0.

Registry recovery completed: the official Docker Hub source replaces only the
public ECR mirror at the same nginx version/digest, protected by a regression check.
The full gate, image build and strict CI smoke passed; the tested tree was promoted
and published through a fresh, owner-approved 1.0.0 dispatch.

Risks: external analytics can be blocked or configured independently in Google;
app functionality must remain available. Registry availability can block CI. Preserve
prior closeout evidence/blocked tracking while carrying it into this release work.

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
[Worthhit 1.1.0 is live](https://worthhit.com), with HTTPS and canonical
www/HTTP redirects. Feature [#17](https://github.com/consciontologic/worthhit/pull/17)
and promotion [#18](https://github.com/consciontologic/worthhit/pull/18) are merged;
the owner-approved
[release run](https://github.com/consciontologic/worthhit/actions/runs/39481827330)
published the matching GitHub release, public GHCR image and GitOps website.
All 68 public release files passed byte-count/hash checks, and the browser updated
from cached 1.0.0 to 1.1.0.
See [publication evidence and limits](../DEPLOYMENT.md#verified-110-publication--2026-10-20).

### Historical 0.1.0 deployment

[Worthit was published](https://consciontologic.github.io/worthit/). Source PRs [#1](https://github.com/consciontologic/worthit/pull/1) and [#3](https://github.com/consciontologic/worthit/pull/3), and exact-tree promotions [#2](https://github.com/consciontologic/worthit/pull/2) and [#4](https://github.com/consciontologic/worthit/pull/4), are merged. The first deployment exposed a hidden-file archive mismatch; the corrected [release run](https://github.com/consciontologic/worthit/actions/runs/39440088378) deployed `d314ef56c9b6f2f6a59c885b9c30b15de4d0cae9` after the owner's production approval. All 41 published manifest assets passed size/hash verification, and the public UI restored its saved example after reload. See [deployment evidence and limits](../DEPLOYMENT.md) and [live evaluation](../LIVE_EVAL.md).
