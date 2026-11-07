# Native Research Path — 2026-11-08

## Scope
Research Path presents seven conceptual stages, like the web. An HTTP source returning records does not mean research approval, investment advice, performance or executed trading.

## Reviewed read-only source mappings

| Stage | Backend source | Native status |
| --- | --- | --- |
| Collection | Separate operational-market publication | Unavailable pending reviewed API contract |
| Identity | GET /api/v1/stocks | Current ticker listing, not historical continuity |
| Models | GET /api/v1/models | Global qualifications, not security-specific predictions |
| Analysis | GET /api/v1/analysis/screener and GET /api/v1/stocks/{ticker}/analysis | Count exact publication cross-matches |
| Evidence | GET /api/v1/evidence | Layer count and unresolved blockers |
| Portfolio | Historical portfolio router | Unavailable pending versioned HTTP/pagination contract |
| Operations | GET /api/v1/operations/runs?offset=0&limit=25 | First-page recorded run count only |

Only a six-character validated ticker is queried. The existing ResearchObservationMatch requires exactly matched ticker, analysis ID, model/version, dates, direction, score and validation. Missing/duplicate/mismatched publications are not corroborated.

Existing ResearchEnvironment controls HTTP, demo and disconnected modes. HTTP errors are displayed instead of mock fallback. Collection and historical portfolios explicitly remain unavailable until reviewed interfaces are implemented. This view cannot certify KRX live publication, research approval or financial return.

## Coverage and omissions
ResearchPathTests checks seven-stage order, demonstration isolation, empty/blocked/unavailable distinctions, unknown collection/portfolio stages and operation count limitations. Existing API payload/integrity tests remain applicable. Device QA, runtime publication, operational snapshot, historical portfolios and Phase 6 custody remain pending. No backend mutations or paid services.
