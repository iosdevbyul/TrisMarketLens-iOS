# Native Archived Portfolio Timelines — 2026-11-08

## Contract
Continues the restricted read-only archival feature from PR #88, using existing operator-pinned local-only backend GET endpoints:

- GET /api/v1/research/historical-portfolios/{report_id}/trades?offset=N&limit=10
- GET /api/v1/research/historical-portfolios/{report_id}/tickers/{ticker}?offset=N&limit=10

The archive is loopback-only and only usable by locally authorized processes. A physical iPhone's localhost does not address the developer Mac. The client rejects remote API bases, invalid 64-character report IDs, invalid six-character uppercase tickers and out-of-range offsets before any HTTP request. All responses must carry the published_historical_portfolio_v1 restrictions, immutable matching report/ticker identities and exact page offset/limit, with unique event/opportunity identifiers. Missing/null evidence is retained as unavailable rather than synthesized.

## UI
Archived report details now navigate to the read-only recorded opportunity timeline and five per-ticker decision histories. Historical categories are taken from server-published classifications (filled, pending, accepted, rejected, no_order), not reconstructed from actions. Paged data retains source date, chosen rule, original opportunity ID, run source hash and published evidence scope. Displayed fills are offline simulated backtest mechanics, not independently verified exchange executions.

## Tests and omissions
HistoricalPortfolioTimelineTests cover valid decoding, source identity mismatch, unsupported classifications, ticker/page mismatch and remote/invalid-request rejection.

Comparison POST, global operational snapshot publication, live runtime archive access, operator authorization migration, physical-device testing, and investment suitability remain out of scope. No backend mutation or fee-bearing services are introduced.
