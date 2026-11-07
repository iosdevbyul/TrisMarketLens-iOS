# Native Research Workbench — 2026-11-08

## Source contracts
This feature reuses existing published read-only routes and source adapters:
- GET /api/v1/models and /api/v1/models/{direction}, via ResearchCatalogSource
- GET /api/v1/evidence and /api/v1/evidence/{layer}, via ResearchCatalogSource
- GET /api/v1/analysis/screener, via ScreenerSource
- GET /api/v1/stocks/{ticker}/analysis, via StockResearchSource

No new backend route, database write, API credential or paid service is introduced. Models are global directional qualifications, **not** a verified mapping to a ticker's analysis artifact. Evidence layers are research-wide statuses, **not** per-security evidence approval.

## Native journey
The sidebar includes Research Workbench. The user chooses Up/Down model qualification and enters a validated six-character ticker. Distinct panels report global model qualification, evidence blockers and a per-ticker analysis cross-check. Ticker records are shown only when an exactly matching published screener record can be resolved with ResearchObservationMatch, independently of a model qualification. Navigation reuses StockAnalysisDetailView; evaluation remains unavailable.

HTTP errors from each source are visible individually. Absence of a publication, duplicate IDs, mismatched model metadata or invalid tickers do not generate an inferred result. Mock/disconnected modes never certify HTTP publication; a configured HTTP transport alone does not prove live server reachability.

## Coverage
Tests verify ticker normalization, missing/duplicate/cross-ticker publication, genuine HTTP matching, and demo-mode non-certification. Existing API and research tests continue running under GitHub CI.

## Deliberate omissions
Actual KRX collection and runtime access, historical ticker identity provenance, comprehensive research path with operational snapshots and historical portfolios, Phase 6 source custody, physical-device QA and release readiness remain unverified and belong to later increments. No investment recommendation or realized return is implied.
