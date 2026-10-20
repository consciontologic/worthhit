# Worthit delivery plan

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
- [ ] Complete human-approved production deployment and public checks.

## Risks
Live providers may reject a schema or be unavailable; preserve drafts and allow explicit retry/model choice. Search snippets may lack real sold comparables; abstain and request evidence. Browser storage is origin-local and may be cleared; surface save failures and export reports. Pages publication requires protection-compliant source promotion and human production approval.

## Publication status
Source PR [#1](https://github.com/consciontologic/worthit/pull/1) and exact-tree promotion [#2](https://github.com/consciontologic/worthit/pull/2) are merged. Main is `b12b6475d11725e9c8d571cdfc3cc4ce1a27f1dc`. [Release run](https://github.com/consciontologic/worthit/actions/runs/39437847160) was dispatched; production still requires the human owner’s approval and public verification.
