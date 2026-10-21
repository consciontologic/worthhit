# Changelog

## [Unreleased]

## [2.0.0] - 2026-10-21

- Estimate a product’s fair price from product, currency and condition, with optional
  notes. Remove required evidence boxes and the multi-step evidence workflow.
- Calculate a clearly labeled model-based estimate when suitable researched sales
  are unavailable, while preserving stricter provenance for researched comparisons.
- Choose free models directly on the homepage with visible text, image/video support,
  context limits and optional research compatibility.
- Attach supported images or MP4 video using capability-gated controls, bounded local
  reads and direct provider uploads. Files remain in memory for the current session.
- Preserve existing drafts and reports, eight languages, explicit paid-search opt-in,
  free inference, safe previews and human-approved deployment.

## [1.1.4] - 2026-10-21

- Start manual releases with only a version; CI checks SemVer progression and stops
  for unpromoted develop changes while allowing content-neutral backmerges. Empty
  version builds artifacts only; production still requires owner approval.

## [1.1.3] - 2026-10-21

- Replace buy/sell modes with one neutral product-worth check; older saved drafts and reports remain readable.
- Read About, Terms and conditions, and Liability within the app, with browser history and preserved workspace/settings state.

## [1.1.2] - 2026-10-20

- Open information pages directly from mobile navigation while preserving the active price check.
- Compress bundled language fonts without removing glyphs, omit unused renderer files and start offline preparation after the first app frame.

## [1.1.1] - 2026-10-20

- Open directly into the price-check workspace without flashing the promotional startup page.

## [1.1.0] - 2026-10-20

- Make phone and tablet navigation more compact while retaining accessible touch targets and large-text layouts.
- Add a Worthhit icon family and contextual help to reduce repeated interface copy.
- Enable selection and copying across the workspace, settings, help, hints and reports without disrupting form input.
- Discover remote app updates while the app is open and offer a dismissible, explicit update action that protects drafts.

- Use plain SemVer for GitHub release names, including resumed drafts; existing release names were normalized without changing tags or assets.

## [1.0.0] - 2026-10-20

- Fetch the pinned official nginx base from Docker Hub to avoid the public ECR mirror quota on GitHub-hosted release runners.
- Add About, Terms and conditions, Liability and GitHub links in the desktop footer and compact navigation drawer.
- Publish readable information pages with matching light/dark styling and offline navigation.
- Add the owner's Google Analytics tag to every public page, with advertising features disabled and updated data-use disclosures.
- Display the release version consistently in the app and public information pages.

## [0.2.0] - 2026-10-20

- Rename the app to Worthhit and prepare the canonical worthhit.com website.
- Add a more restrained neo-brutalist identity, system/light/dark appearance and localized workflows.
- Add browser language negotiation and a manual language choice.
- Add crawler-readable metadata, a sitemap and light/dark icon variants.
- Publish immutable SemVer web archives and a static-only non-root nginx container through GitHub Packages.
- Add guarded GitOps publication to the separate worthhit.com repository, preserving human deployment approval and validated-source Gitflow.

## [0.1.0] - 2026-10-20

- Initial client-only Worthit Flutter PWA, adaptive valuation workflow, direct OpenRouter discovery and bounded inference.
- Evidence-based local price arithmetic, explicit uncertainty, drafts and hash-verified static shell.
- The initial release was published before SemVer tags were introduced; this entry documents it without retroactively creating a tag.
