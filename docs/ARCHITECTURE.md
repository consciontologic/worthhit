# Worthhit architecture

Worthhit runs entirely in the browser. Flutter/Dart owns simple product input, evidence admission,
arithmetic, API requests and recovery. GitHub Pages serves static assets. There is
no Go service, application proxy or hosted database; this follows the user's
explicit runtime decision on 2026-10-20.

| Boundary | Responsibility |
|---|---|
| `lib/api/` | Public model discovery, exact-zero price eligibility, endpoint metadata, bounded/cancellable OpenRouter completion, typed safe failures |
| `lib/domain/` | Versioned appraisal schema, exclusions, source provenance and recency, same-currency comparable gates, local observed and model-estimate arithmetic |
| `lib/app/` | Request admission, draft/result ownership, explicit model selection, persistence and recovery |
| `lib/ui/` | Simple adaptive product editor, homepage model dropdown and reports; keyboard, large text, RTL and selection |
| `lib/platform/` | Origin-local browser storage, bounded session-only file picker, report download, PWA update port |
| `web/`, `tool/` | Hash-verified static shell; build identity and safe publication |

The homepage requires only product, currency and condition; arbitrary notes and
supported images/video are optional. Legacy location/evidence fields remain readable
in stored drafts but are not required or presented as a workflow step.

The versioned appraisal parser separates researched comparisons from model estimates.
With three accepted recent exact-match sales in the requested currency, Dart computes
their minimum, median and maximum. Without sufficient verified comparables, a bounded
reference value, condition adjustment and uncertainty can produce a clearly labeled
unverified estimate. The UI must never describe that fallback as current market
research. Neither range is a calibrated confidence interval or guaranteed sale price.
Legacy reports retain their original interpretation and do not become new appraisals.
Provider citations need supporting content; a search request alone is not evidence.

Media validation checks count, byte limits, signatures and the selected model’s
usable modalities at admission and dispatch. Selected files remain session-only and
are never placed in browser-local drafts or service-worker caches. Incompatible
model changes retain the files for explicit removal or model reselection. The browser
picker reads bounded local files and the API sends structured image/video content
parts directly to OpenRouter. No arbitrary media URLs, transcoding or execution.

Free-model inference is admitted only from a freshly validated catalog. Unknown
pricing fails closed. No automatic provider/model fallback or content resend.
Catalog errors preserve the last good display; a stale catalog cannot authorize
inference. Endpoint metadata is diagnostic, not proof of model correctness.
No single-flight deduplication spans different browsers or tabs.

Live web search is opt-in and separately chargeable. The request bounds the search
tool, pins its engine and caps tool calls. Current provider fees are informational
and may change. Default requests use no search. Only an explicit action sends
product facts/evidence to OpenRouter and its downstream providers.

Keys are memory-only. Draft, catalog and the last report use origin-local browser
storage, which can be cleared or denied. Storage failures are visible. Shell caches
contain verified static files only: never keys, API responses, input or reports.
Downloaded reports are plain JSON data. Listing text and model output are never
executed as HTML, scripts or commands.

The source project uses work-branch PRs, secret-free CI and explicit deployment
dispatch. The production environment requires the owner's approval. Static GitOps publishes the verified root-path shell to `worthhit.com`; the same sealed bytes ship in a non-root nginx container. No application proxy is added. See `DEPLOYMENT.md` for versioning and approval boundaries.

Preferences use `worthhit.preferences.v1`; prior `worthit.*.v1` storage and report
protocol identifiers are intentionally preserved for compatibility. Browser locale
negotiation selects one of eight supported languages, with explicit persistent
overrides and Arabic RTL. Model explanatory language comes from a trusted fixed
allowlist; protocol keys, enums, ISO fields and source quotations remain canonical.
Locally bundled WOFF2 fonts cover Latin, Arabic and Simplified Chinese without a
font CDN or glyph subsetting. Source TTFs and OFL licenses remain in the repository;
`tool/font_assets.py` audits the decompressed rendering tables, characters and
variable axes, and CI fingerprints the committed exports. The public build keeps
full and Chromium CanvasKit variants, rejects unknown renderer configurations and
omits known unselected renderer binaries/symbols before sealing the offline manifest.
It clears only its owned `build/web` output before compilation, so incremental
builds cannot retain obsolete assets; sources and compiler caches are preserved.

About, Terms and Liability open as Flutter information pages above the retained
workspace and settings. A Router maintains browser history through hash URLs so
Back/Forward and in-app return preserve the editing session without loading a new
document. Canonical static HTML remains available for crawlers and direct links;
the in-app English prose is generated by `make information.sync` and checked by
`make verify` and public builds. Its direction/language remain English while
navigation chrome follows the selected UI locale. Only public route/section names
enter hash URLs and browser history; no draft content or keys enter them.
Only external links use the synchronous `noopener noreferrer` anchor and copyable
fallback. Keys remain in memory across internal navigation and clear on a full
reload; persisted drafts/preferences restore after reload. Visible versions derive
from `pubspec.yaml`; source checks and public builds reject stale identities.

The custom Worthhit icon font and matching transparent SVGs share reproducible
vector geometry in `tool/generate_icons.py`. Icons inherit theme colors and keep
localized labels/tooltips. Phone navigation uses compact input and estimate controls;
large text can expand it instead of clipping labels or reducing touch targets.
Optional explanations live in contextual help; fees, data transmission and
estimate limitations remain visible where decisions are made.

Selection areas belong below each route’s overlay, with independent scopes for
the workspace, drawer, settings sheets, help dialogs, menus and hints. This enables touch copy
toolbars and prevents Select all in a dialog from including background drafts.
Editable fields retain their own selection and paste handling.

The bootstrap waits for Flutter’s first rendered frame before registering or
checking for a remote worker. Ordered deferred scripts install the listener before
Flutter can emit that event. It then checks every five visible/online minutes and
on focus/reconnection, with a shared 30-second cooldown and one request
in flight. Discovery never activates it. Waiting-worker checks run independently
of the model catalogue. A dismissible notice and Settings offer explicit update;
active appraisals block it, the draft must save first, and activation times out
with a recoverable message after 15 seconds. Disposal removes the listener and
prevents a delayed reload. The in-memory key must be entered again after reload.

Normal startup has no visible landing page: the theme-matched document remains
empty until Flutter displays the workspace. Root metadata and public information
pages remain available. JavaScript-disabled visitors receive a concise fallback;
caught Flutter startup failures expose recovery only when needed.

The owner's Google Analytics tag runs independently of Flutter on public pages.
The app defines no analytics events containing inputs, keys, evidence or reports.
Initial page configuration uses canonical page URLs, blank referrers and disabled
advertising signals. Google property settings control additional automatic
measurement; code settings alone do not establish a privacy/compliance guarantee.
Google requests bypass the static PWA cache, and a blocked tag must not stop the app.
