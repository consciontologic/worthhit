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
- [x] Complete human-approved production deployment and public checks.

## Risks
Live providers may reject a schema or be unavailable; preserve drafts and allow explicit retry/model choice. Search snippets may lack real sold comparables; abstain and request evidence. Browser storage is origin-local and may be cleared; surface save failures and export reports. Pages publication requires protection-compliant source promotion and human production approval.

## Publication status
[Worthit is live](https://consciontologic.github.io/worthit/). Source PRs [#1](https://github.com/consciontologic/worthit/pull/1) and [#3](https://github.com/consciontologic/worthit/pull/3), and exact-tree promotions [#2](https://github.com/consciontologic/worthit/pull/2) and [#4](https://github.com/consciontologic/worthit/pull/4), are merged. The first deployment exposed a hidden-file archive mismatch; the corrected [release run](https://github.com/consciontologic/worthit/actions/runs/39440088378) deployed `d314ef56c9b6f2f6a59c885b9c30b15de4d0cae9` after the owner's production approval. All 41 published manifest assets passed size/hash verification, and the public UI restored its saved example after reload. See [deployment evidence and limits](../DEPLOYMENT.md) and [live evaluation](../LIVE_EVAL.md).
