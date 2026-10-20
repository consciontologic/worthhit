# Worthhit

**Know the range. Make a fair deal.** A Flutter PWA for evidence-led second-hand price
checks, designed for buyers and sellers. Phone users get guided steps, tablets get
a focused editing surface, and desktops get a comparison workbench.

Worthhit runs in your browser and calls OpenRouter directly with your own key.
There is no Worthhit API server or remote database. Model inference is restricted
to explicitly free routes. Web research is a separate, optional paid OpenRouter
search. Keys remain in memory and are cleared when the tab closes.

The application extracts comparable observations, validates their provenance and
computes the accepted sold-price minimum, median and maximum locally. With fewer
than three suitable recent sold comparables, it asks for evidence instead of
inventing a price. User-supplied excerpts are not independently verified. The
range is an estimate from observed comparables, not a guaranteed selling price.

The built-in example is explicitly synthetic and cannot be submitted as a real
appraisal. Replace its evidence before checking a real item. Prohibited and unsafe
goods are outside scope. The model considers ownership attachment, anchoring,
urgency and remote trust without applying invented psychological premiums or
encouraging manipulation.

## Run

Requires Flutter **3.47.3**, Dart **3.13.3**, Python 3 and Node.js. No global
packages or backend services are needed.

```sh
make deps
make verify
make build.public
make serve
```

Open `http://127.0.0.1:8766/`. The shell works offline after a complete
installation; new research and model requests require an internet connection.
Drafts and the most recent matching report are stored on this device. Browser
site-data clearing can remove them; download reports to keep a copy.

## Guides

- [Architecture and data boundaries](docs/ARCHITECTURE.md)
- [Appraisal theory, instructions and evidence rules](docs/APPRAISAL.md)
- [wfform API and UX audit](docs/research/WFFORM_AUDIT.md)
- [Bounded live evaluation](docs/LIVE_EVAL.md)
- [Delivery and human deployment approval](docs/DEPLOYMENT.md)
- [Delivery checklist](docs/planning/ROADMAP.md)

No analytics, account system, marketplace transactions, payment collection, or
shared embedded API credential. Product facts and evidence leave your device
only when you explicitly request an appraisal; then OpenRouter, its selected
provider and optional search provider process them under their own policies.
Do not include secrets, personal records or confidential documents in listings.

MIT-licensed tooling and verified-shell patterns adapted from
[wfform](https://github.com/consciontologic/wfform); bundled Space Grotesk and Noto fonts retain their OFL licenses in `assets/fonts/`.

## Worthhit 0.2.0

The app supports system/light/dark appearance and English, Turkish, German, French,
Spanish, Portuguese, Arabic and Simplified Chinese. Browser language negotiation
and manual overrides work without an IP lookup. Original evidence remains verbatim.
This pre-1.0 release may evolve its interface; saved report protocols remain compatible.

Production is [worthhit.com](https://worthhit.com/). Reviewed source changes flow
through `develop` and exact-tree promotion to `main`; the owner approves each
versioned release. Static assets publish to `consciontologic/worthhit.com` and
nginx images to `ghcr.io/consciontologic/worthhit:<version>`. See the
[Gitflow guide](docs/GITFLOW.md), [deployment guide](docs/DEPLOYMENT.md),
[brand system](DESIGN.md), and [changelog](CHANGELOG.md).

The old project URL and worthhit.com have different browser storage origins.
Export important reports from the old site before switching; storage cannot
automatically move across domains. No API keys are carried over.
