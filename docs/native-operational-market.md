# Native Operational Market — read-only pinned snapshot

## Verified backend routes
- GET /api/v1/operational/summary -> operational_snapshot_summary_v1: observationCount, tickerCount, tradingDayCount, firstTradingDate, lastTradingDate; evidenceStatus=unreviewed
- GET /api/v1/operational/stocks?offset=N&limit=25 -> operational_market_v1, stable ticker and latestDataDate
- GET /api/v1/operational/stocks/{ticker}/ohlcv -> separate existing OhlcvSeries, at most 2,500 chronological bars

The operational source is an **offline, SHA-256-pinned SQLite copy** configured by an operator. It must not query the actively written collection database. An unconfigured backend returns 503, which remains an unavailable state in iOS. The backend's summary counts are observed rows/tickers/days, not guaranteed 940 tickers or verified exchange coverage. The operational series must not be substituted for the independent reviewed research /api/v1/stocks contract.

## Native implementation
Native Operational Market sidebar presents summary, paginated observed ticker catalog and detail OHLCV chart/list with explicit unreviewed status. All data is sourced through existing ResearchAPIClient and has no mock fallback. Client validates version/evidence labels, paging, ticker code, date shape, chronological bars and OHLCV numeric boundaries before accepting a response. A source failure is surfaced independently, including when coverage works but catalog does not.

Backend may be hosted behind an operator-reviewed authenticated gateway; the app does not add authentication or authorization, and never asserts production access has been approved. No KRX credentials, active SQLite access, predictions, recommendations or trading functions are introduced.

## Verification and follow-up
Tests include valid and invalid schema, evidence state, counts, dates, tickers, paging, bars and missing-source behavior. GitHub Actions simulator builds and XCTest are required before merging. Physical device, real KRX capture, raw provenance, operator snapshot startup and deployment gateway are not verified. Approval of real-data acquisition remains an explicit separate workflow.
