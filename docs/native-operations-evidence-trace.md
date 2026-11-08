# Native Operations Evidence Trace — 2026-11-08

## Native scope
A new Operations Trace sidebar destination presents five independently retrieved read-only evidence projections using existing vetted adapters:

| Trace stage | Backend source | Trust boundary |
| --- | --- | --- |
| Recorded execution | GET /api/v1/operations/runs?offset=0&limit=25 | Execution result, evidence validity and semantic approval are distinct |
| Source freshness | GET /api/v1/operations/freshness | Recent ingestion does not prove complete collection or source custody |
| Operational incidents | GET /api/v1/operations/alerts?offset=0&limit=25 | Alerts may be unreviewed; no inferred linkage by matching source label |
| Research publication | GET /api/v1/analysis/screener | Independently published AI records do not prove operational source provenance |
| Research evidence | GET /api/v1/evidence | Evidence layer status is not inferred trading approval |

The trace reuses OperationsV1Source, ScreenerSource and ResearchCatalogSource. Requests remain isolated: one failure is never silently hidden behind another endpoint's success. Unavailable, empty, blocked, observed and demo/disconnected are distinct. A positive run count establishes only a recorded projection. A recorded alert, missing approval, blocked run, stale freshness or evidence layer blocks positive interpretation.

## UI and test coverage
- A source-specific stage summary with expanded first-page run/alert details and source freshness details, diagnostics, timestamps and original run/alert IDs.
- The existing Operations dashboard remains the authoritative pagination UX for additional recorded runs and alerts.
- Explicit no-join interpretation: operational collection rows, approved KRX snapshots, scheduler evidence and model research may have distinct provenances; this view makes no unsupported linkage.
- Unit tests for stage order, disconnected demo isolation, blocked/unavailable/empty distinction, independent research publication and no inferred approval.

## Out of scope and unfinished verification
No new backend routes or server writes. A dedicated operational-market snapshot reader, pinned raw capture proof, scheduler diagnostics adapter, independently verified acquisition-to-analysis lineage and physical iPhone validation remain separate Phase 3/4 work. This is not complete KRX custody, PIT/OOS qualification, financial model approval or brokerage evidence.

CI Debug/Release build and XCTest must pass before merging. No actual remote KRX publication or end-to-end real-device verification is claimed.
