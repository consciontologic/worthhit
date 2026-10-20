# Worthhit architecture

Worthhit runs entirely in the browser. Flutter/Dart owns forms, evidence admission,
arithmetic, API requests and recovery. GitHub Pages serves static assets. There is
no Go service, application proxy or hosted database; this follows the user's
explicit runtime decision on 2026-10-20.

| Boundary | Responsibility |
|---|---|
| `lib/api/` | Public model discovery, exact-zero price eligibility, endpoint metadata, bounded/cancellable OpenRouter completion, typed safe failures |
| `lib/domain/` | Versioned appraisal schema, exclusions, source provenance and recency, same-currency comparable gates, deterministic observed range and median |
| `lib/app/` | Request admission, draft/result ownership, explicit model selection, persistence and recovery |
| `lib/ui/` | Phone guided flow, tablet focus view, desktop comparison workbench; keyboard, large text and selection |
| `lib/platform/` | Origin-local browser storage, report download, PWA update port |
| `web/`, `tool/` | Hash-verified static shell; build identity and safe publication |

The model extracts evidence and suggests short explanations; it does not control
the displayed numeric range. Dart accepts three distinct recent exact-match sold
comparables in the requested currency and a consistent price basis, then computes
their observed minimum, median and maximum. This is an estimate derived from those
observations, not a calibrated confidence interval or guaranteed transaction price.
User-pasted evidence is labeled as supplied, not independently verified. Provider
citations require supporting content. A search request alone is not evidence.

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
Locally bundled fonts cover Latin, Arabic and Simplified Chinese without a font CDN.

Public About, Terms and Liability documents are static HTML, available through the
desktop footer and compact drawer without discarding the active appraisal session.
Their visible version and the Flutter footer derive from `pubspec.yaml`; source
checks and public builds reject stale generated identities.

The custom Worthhit icon font and matching transparent SVGs share reproducible
vector geometry in `tool/generate_icons.py`. Icons inherit theme colors and keep
localized labels/tooltips. Phone navigation uses a compact action and step row;
large text can expand it instead of clipping labels or reducing touch targets.
Optional explanations live in contextual help; fees, data transmission and
estimate limitations remain visible where decisions are made.

Selection areas belong below each route’s overlay, with independent scopes for
the workspace, drawer, settings sheets, help dialogs, menus and hints. This enables touch copy
toolbars and prevents Select all in a dialog from including background drafts.
Editable fields retain their own selection and paste handling.

The bootstrap checks for a remote worker at startup, every five visible/online
minutes and on focus/reconnection, with a shared 30-second cooldown and one request
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
