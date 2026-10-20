# wfform patterns retained in Worthit

Source audited: `consciontologic/wfform`, commit
`eb0c3f0` (read-only, 2026-10-20). CodeGraph reported no index for the checkout;
direct source and test inspection supplied the evidence. This audit does not claim
the inspected tests were executed during the audit.

| Concern | wfform behavior | Worthit decision |
|---|---|---|
| Discovery | `lib/features/models/catalog.dart:294`: public `/models`, bounded same-origin pagination, duplicate/loop/completeness checks | Typed bounded adapter; public requests carry no API key |
| Schema changes | `catalog.dart:56`, `model.dart:379`: unknown additions tolerated; malformed known fields quarantined; invalid envelopes retain last good data | Contain drift, never claim automatic repair; new breaking schemas need fixture-backed adapter changes |
| Price policy | `model.dart:310`: exact decimal zero checks prevent tiny-number underflow; unknown fees fail closed | Free inference admission plus server price caps; web search remains a separately disclosed opt-in charge |
| Refresh | `catalog.dart:229,436`: cache-first, deduplicated refresh, timestamp retained after failure | Stale display remains available, but fresh catalog required before inference |
| Endpoints | `health.dart:565`: selected-model endpoint metadata, byte/TTL bounds | Inspect only the selected model; do not mistake metadata for successful valuation |
| Health | `health.dart:377,460`: selected-only tiny probes; bounded concurrency; first useful output proves responsiveness | Avoid bulk scans/probes and extra inference; actual appraisal validates completion and schema |
| Cooldown | `health.dart:135,698`: model backoff, account-wide 429 cooldown, server Retry-After precedence | Explicit retry with account-local admission cooldown; no silent resend |
| Fallback | `chat_api.dart:51`: exact model, zero caps, provider fallback disabled | Fallback is last-good catalog display or explicit user model choice, not automatic content replay |
| Transport | `transport.dart:51,158`: owned cancellation, redirects disabled, bounded data/deadlines | Abortable bounded requests; atomic non-streamed JSON appraisal |
| Streaming | `sse.dart:7`, `chat_api.dart:217`: incremental framing, DONE required, partial failure retained | Appraisal publishes only complete validated JSON; non-streaming avoids showing a half-formed price |
| Diagnostics | `diagnostics.dart:88,256`: sanitized typed errors, no prompt/response logs | Separate HTTP status from upstream code; safe recovery text |

The existing app does not provide current market comparables or factual valuation.
A successful inference probe is not a correctness test. Its TTL does not itself
schedule refresh or prohibit stale sends; Worthit deliberately tightens admission.
There is no distributed circuit breaker, cross-tab deduplication, conditional
ETag refresh or autonomous schema repair to extract.

Adaptive principles from `lib/presentation/studio_app.dart:63,229,318,478`: preserve
controllers/focus while changing the interaction structure; react to keyboard and
text scale as well as width; maintain selection and visible recovery states.
Worthit uses guided phone steps, tablet focus navigation and a desktop workbench.

PWA principles from `web/service_worker.js:27,147` and
`lib/app/studio_state.dart:1491`: verify the static shell, exclude API/private data,
and activate updates explicitly after saving. Worthit's worker follows this
boundary with its own cache identity.

Publication cannot be copied blindly: wfform hardcodes its destination repository,
domain and analytics in `deploy/scripts/publish-website.sh:21,52`,
`tool/prepare_website.dart:91,128`, and `web/index.html:5,19`. Worthit has its own
repository, Pages base path, assets and no copied analytics.

Inspected test families: `test/models/{catalog,health,health_cache}_test.dart`,
`test/chat/{chat_api,sse}_test.dart`, `test/shared/{phase_timeout,transport_redirect}_test.dart`,
`test/presentation/{compact_chrome,keyboard_lifecycle,composer_focus,sidebar_resize}_test.dart`,
`test/shared/pwa_worker_test.mjs`, and `test/deploy/website_publication_test.dart`.
Worthit tests its own behavior; copied design intent is not execution evidence.
