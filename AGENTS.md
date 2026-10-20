# Worthit working rules

Worthit is a separate Flutter PWA. All product logic is Dart, and requests go directly to OpenRouter. No application server or remote database. Read docs/planning/ROADMAP.md and docs/ARCHITECTURE.md before changing behavior. Keep API keys in memory; never embed, commit or log credentials or user content.

Use isolated `codex/feature/*`, `codex/bugfix/*` or release work branches from develop. Source main/develop are PR-only. Parent publishes validated work via `make git.dry` then `make git`; no direct source commit/push, force push or protection bypass. Only the human owner may approve the production deployment. Delegates do not stage, track or publish. Preserve other agents' edits.

Write behavior tests first; capture long commands through xops/agent/safe-run.sh. Read failed logs before fixing and retrying. Run `pwd` before build/test/git commands. `make verify` is the gate. Deterministic, browser, live-provider and deployment evidence are separate. Use append-only tracking via xops/agent/tracking_append.sh. Existing wfform rules supplied by the user remain applicable to this session.
