# Research API contract audit — 2026-11-08

This is a **static source audit**, not a live backend integration or device QA result.

## Source revisions

- iOS base main: `0ab959e9b9742089742801b03352f664ce2e0fb0`
- DonghakStockVision main: `77890ea2d517f09ca01c94fc0f03eff92af1742c`
- TrisMarketLens web main: `0fd3a01affeefc1a5f069734d2b86bc3ecf7f6e9`

Reviewed backend `src/donghak_stock_vision/api/app.py`, iOS sources in `TrisMarketLens/Data`, the stock research and operations views, and web `docs/backend-api-gap-audit-2026-10-30.md`.

## Endpoint mapping

| Backend GET route | iOS integration | Assessment |
| --- | --- | --- |
| `/api/v1/health` | ResearchConnectionDiagnostic | Implemented, runtime unverified |
| `/api/v1/project/status` | HTTPProjectStatusSource | Implemented, runtime unverified |
| `/api/v1/research/coverage` | Research catalog / project adapters (review further) | Partial; verify dedicated consumer |
| `/api/v1/models`, `/api/v1/models/{direction}` | HTTPResearchCatalogSource | Implemented |
| `/api/v1/evidence`, `/api/v1/evidence/{layer}` | HTTPResearchCatalogSource | Implemented |
| `/api/v1/backtests/baseline` | HTTPBacktestingOperationsSource | Implemented |
| `/api/v1/stocks`, `/api/v1/stocks/{ticker}` | HTTPStockSource | Implemented |
| `/api/v1/security-metadata`, `/api/v1/security-metadata/{ticker}` | HTTPSecurityMetadataSource | Implemented |
| `/api/v1/analysis/screener` | HTTPScreenerSource | Implemented; requires reviewed publication |
| `/api/v1/stocks/{ticker}/ohlcv` | HTTPStockResearchSource | Implemented; requires market reader |
| `/api/v1/stocks/{ticker}/analysis` | HTTPStockResearchSource | Implemented; requires analysis publication |
| `/api/v1/operations/runs` | HTTPOperationsV1Source | Implemented; version/pagination validated |
| `/api/v1/operations/freshness` | HTTPOperationsV1Source | Implemented |
| `/api/v1/operations/alerts` | HTTPOperationsV1Source | Implemented |
| `/api/v1/operations/krx-scheduler/diagnostics` | No dedicated iOS consumer | Not implemented in iOS |
| `/api/v1/operational/summary`, `/api/v1/operational/stocks`, `/api/v1/operational/stocks/{ticker}/ohlcv` | No dedicated iOS consumer | Not implemented in iOS |
| `/api/v1/research/historical-portfolios/*` | No dedicated iOS consumer | Not implemented in iOS; inspect backend router contract before implementation |
| `/api/v1/operations` | Legacy HTTPBacktestingOperationsSource | **Backend API unsupported**; fail closed in this change |
| `/api/v1/stocks/{ticker}/evaluations` | Legacy HTTPStockResearchSource | **Backend API unsupported**; fail closed in this change |

The web also uses the supported `/api/v1/operations/runs?offset=0&limit=25`; its audit is not evidence of live data. iOS already has a separate `OperationsV1Dashboard` and verified pagination DTOs. No synthetic or speculative evaluation endpoint is introduced here.

## Feature classification and planned follow-up

| Feature | iOS status | Dependency / next verification |
| --- | --- | --- |
| Overview, Stocks, Models, Evidence, baseline backtesting | Implemented | Reconfirm current response schemas and actual server payloads |
| AI Screener | Implemented HTTP adapter and UI | Reviewed analysis publication; 503 is not an empty success |
| AI Analysis History / stock analysis | Partially integrated | Verify actual backend publication and history UI coverage |
| Research Workbench and provenance drill-down | Not yet established by iOS audit | Check web flows and backend published read-only endpoints |
| Historical portfolio reports and comparison | Not implemented | Existing backend historical portfolio router; strict pagination/provenance |
| Operations runs, freshness, alerts | Implemented v1 | Verify runtime version and evidence status |
| KRX scheduler and operational snapshot detail | Not implemented | Optional backend configuration/read-only contracts |
| Prediction evaluation detail | Backend API unsupported | Do not request/fabricate evaluations until a reviewed contract exists |
| Phase 6 custody/original forward evidence | Not implemented | Dedicated approved read-only publication contract, if offered |
| Real KRX data and physical-device QA | Unverified | User-approved backend runtime and simulator/device verification |

## Failure behavior

In HTTP mode errors remain errors, with no fallback to mock: 404 for unsupported detail/list behavior as specified by adapters; 503 for unconfigured publication; invalid JSON and payload integrity failures; transport failures. This change adds tests that unsupported legacy routes cause **zero HTTP requests**, plus additional 503 and malformed screener response checks. Existing endpoint, source provenance, operational pagination, and cancellation tests remain in CI.

CI passes do not establish live publication, financial validity, direct KRX connectivity, or physical-device success. No backend stores, models, research evidence, or infrastructure are modified.
