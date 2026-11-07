# Historical Portfolio Native Catalog — 2026-11-08

## Backend contract and access restriction
This read-only iOS integration uses the existing DonghakStockVision routes:
- GET /api/v1/research/historical-portfolios?offset=0&limit=10
- GET /api/v1/research/historical-portfolios/{report_id}

The backend historical publication reader is explicitly **loopback-only**, operator-pinned, and opt-in. iOS rejects remote endpoints before requesting an archive. A loopback URL on a physical iPhone refers to the phone itself and **does not** reach the developer's Mac; no reverse proxy, LAN bypass, tunnel or remote exposure is authorized by this change.

The client checks the versioned published_historical_portfolio_v1 envelope, all seven eligibility restrictions, approved archive/replay verification labels, report identity, exact five-ticker universe and pagination, retaining decimal string values, unknown/null financial values, source-provided limitations and original provenance hashes.

The catalog and detail preserve the distinction between offline archived historical research and verified PIT/OOS/live or brokerage performance. Neither source availability nor a copied return signifies trading eligibility or a predicted profit. HTTP 403, 404, 503, malformed JSON, schema changes and transport failure remain errors rather than synthetic portfolio fallback.

## Work completed
- Native searchable navigation entry for Historical Portfolios
- Typed catalog paging (10 per page), detail with immutable source hashes and explicit unavailable financial fields
- Loopback-only DataSource; disconnected and remote modes fail closed
- XCTest for version, eligibility, offset, ticker/report-ID validation, nullable values and remote-request prohibition

## Deferred integration
- POST /compare is read-only but requires a reviewed POST transport contract and 2–5 ID comparison validation, not covered here
- Paginated trade and ticker episodes, detailed operations traces and operational-market publications are follow-on Phase 3 work
- Real archive access depends on approved local operator publication and pin configuration; no runtime server or physical-device verification is asserted
