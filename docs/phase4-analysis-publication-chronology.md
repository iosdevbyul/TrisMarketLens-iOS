# Phase 4 — Analysis publication chronology

This is a read-only local consistency review of the existing `StockAnalysisRecord` contract published by `/api/v1/stocks/{ticker}/analysis`.

- `analyzedAt` must parse as an offset-aware ISO 8601 instant (fractional seconds optional). The instant is compared by its UTC calendar day to the exact `dataThrough` YYYY-MM-DD.
- An invalid date, naive/invalid timestamp, or a `dataThrough` date *after* the UTC analysis date is flagged, not presented as a structurally consistent publication.
- Only a `verified` validation label may accompany a numeric score within [0,1]. `pending` and `blocked` records with no score remain internally consistent but are not approved.
- Both the stock research list and per-record detail show chronology status. A result labelled structurally consistent is **not** independently proven point-in-time availability, dataset custody, market session knowledge, model execution authorization, or trade performance.

The backend also validates publication records at startup. The native check is intentionally an additional presentation safeguard for contract drifts, not an assertion that raw KRX data were collected or source chronology cryptographically verified.

No new backend endpoint, provider access, simulation of records, mutation, paid operation or investment execution. Synthetic unit tests cover UTC offset crossing, invalid dates, missing timezone, future dataThrough, invalid score status and non-verified no-score records. CI Debug/Release builds and XCTest are required; real source timing approval and physical iPhone tests remain separate.
