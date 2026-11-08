# Phase 4 — Research publication readiness gate

## Goal and sources
The native Research Path now presents a **fail-closed evidence checklist** across existing read-only backend projections:

- SHA-pinned offline operational-market summary (operational_snapshot_summary_v1), explicitly labeled `unreviewed`
- Published research evidence layers (state labels are server data, not independent custody verification)
- Published model qualification summaries (model metrics and `research_only` roles are not model-use authorization)
- Operations v1 runs (executionStatus, evidenceStatus, blockingStatus remain separate dimensions)

Each collection is independently fetched and can fail without borrowing success from another source.

## Contract interpretation
A known failed run, blocked operation, invalid evidence or unresolved research layer yields **Blocked by recorded evidence**. Missing evidence yields **Not independently authorized**. Even when every *available* evidence layer is labeled verified and a run reports completed, the native client **never reports eligible or approved**. The current APIs do not establish an authenticated origin for captured KRX raw bytes, artifact SHA lineage to the research snapshot, independently certified point-in-time validity, live execution permission or investor suitability.

Observation counts are not raw capture receipts; operation rows are not semantic source approval; model qualification metrics are not real profit. No cross-source ID matching or data lineage is invented.

## Tests and rollout
Synthetic XCTest fixtures verify contradictory positive labels cannot override blockers, valid but incomplete publications cannot authorize usage, operations failures remain blockers, and demo/disconnected mode is unverified.

This is read-only UI interpretation of existing versioned contracts. It makes no requests for KRX data, opens no external write surface, does not mutate the operational snapshot and introduces no model execution or brokerage controls. Real approved KRX captures, operator-reviewed provenance and physical iPhone connectivity require separate validation.
