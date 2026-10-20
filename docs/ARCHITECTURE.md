# Worthit architecture

Worthit runs entirely in the browser. Flutter/Dart owns forms, evidence admission,
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
dispatch. The production environment requires the owner's approval. No custom
domain is asserted; the initial base path is `/worthit/`.
