# Worthhit

**Know the range. Make a fair deal.** A Flutter PWA for simple second-hand price
estimates. Enter a **product**, **currency** and **condition**, add any optional notes,
and request an estimate. No evidence collection or multi-step form is required.

Use **Models** on the homepage to choose a free OpenRouter model and inspect its
text, image/video capabilities and limits. **Images** and **Video** become available
only when the chosen model supports the input under the app’s free-price rules.
Media stays in memory until removed or the page reloads; only submitting sends it.

Worthhit runs in your browser and calls OpenRouter directly with your own key.
There is no Worthhit API server or remote database. Model inference remains
restricted to explicitly free routes. Web research is a separate optional billed
OpenRouter search, requiring explicit opt-in. Keys remain in memory.

When enough suitable researched sales exist, Worthhit validates their provenance
and calculates their minimum, median and maximum locally. Otherwise it can calculate
a clearly labeled **model estimate** from a reference value, condition adjustment
and uncertainty. That fallback is not verified against current market sales.
The app never treats a search request alone as evidence or invents sources to fill
gaps. Neither result is a guaranteed selling price or a certified appraisal.

Prohibited and unsafe goods remain outside scope. Existing drafts and reports stay
readable, including older evidence-based reports. Descriptions and model output are
data: the app never executes uploaded/generated code, HTML or scripts.

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

Google Analytics measures website use through the owner's tag `G-G4SYW37S81`.
The site does not add custom events containing API keys, item descriptions,
evidence or reports; advertising signals are disabled. Google's cookies,
identifiers and automatic measurements also depend on property/browser settings.
Blocking analytics does not prevent use of the app. See [About](https://worthhit.com/about/)
and [Terms](https://worthhit.com/terms/) for data-use details.

There is no account system, marketplace transaction/payment service or shared
embedded API credential. Appraisal requests send product facts, optional notes and attached media
directly to OpenRouter, its selected provider and optional search provider.
Do not include secrets, personal records or confidential documents in listings.

MIT-licensed tooling and verified-shell patterns adapted from
[wfform](https://github.com/consciontologic/wfform); bundled Space Grotesk and Noto fonts retain their OFL licenses in `assets/fonts/`.

## App experience

The app supports system/light/dark appearance and English, Turkish, German, French,
Spanish, Portuguese, Arabic and Simplified Chinese. Browser language negotiation
and manual overrides work without an IP lookup. Original evidence remains verbatim.
Saved report protocols remain compatible. About, Terms and conditions, Liability,
the source repository and the release version are available from the desktop
footer and the smaller-screen drawer. Information opens within the app; Back returns
to the previous workspace or settings without restarting the session. Existing
buy/sell drafts remain readable, but new checks and requests use no trading role.
Phone and tablet controls use a compact layout and the project’s own icons, with
contextual help for longer explanations. Visible content supports selection/copy;
input fields retain normal copy/paste. Available app updates appear in a dismissible
notice and can also be opened from Settings. Updates require an explicit action,
save the draft first and clear the memory-only key when the page reloads.

`pubspec.yaml` owns the release version. After updating it and the dated changelog,
run `make version.sync`; `make verify` and public builds reject visible version drift.
After editing public information prose, run `make information.sync` to refresh
the in-app copy; the same gates reject stale generated content.

Production is [worthhit.com](https://worthhit.com/). Reviewed source changes flow
through `develop` and exact-tree promotion to `main`; the owner approves each
versioned release. Static assets publish to `consciontologic/worthhit.com` and
nginx images to `ghcr.io/consciontologic/worthhit:<version>`. See the
[Gitflow guide](docs/GITFLOW.md), [deployment guide](docs/DEPLOYMENT.md),
[brand system](DESIGN.md), and [changelog](CHANGELOG.md).

The old project URL and worthhit.com have different browser storage origins.
Export important reports from the old site before switching; storage cannot
automatically move across domains. No API keys are carried over.
