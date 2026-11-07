# TrisMarketLens (iOS)

Native SwiftUI companion to [TrisMarketLens Web](https://github.com/iosdevbyul/TrisMarketLens), using the read-only research API contracts of [DonghakStockVision](https://github.com/iosdevbyul/DonghakStockVision).

**Display name:** TrisMarketLens  
**Repository:** TrisMarketLens-iOS  
**Minimum iOS:** 17.0  
**Language:** English-first, with localization planned.

## Getting started

Requires Xcode with an iOS 17+ SDK and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
brew install xcodegen
xcodegen generate
open TrisMarketLens.xcodeproj
```

The project file is generated from `project.yml` and is intentionally not committed. CI generates it on each run.

## Current scope (November 2026)

The native SwiftUI app provides eight navigation sections: Overview, Stocks, AI Screener, AI Analysis History, Models, Evidence, Backtesting and Operations. Existing typed sources cover approved snapshot research, stock analysis, OHLCV and Operations v1. These integrations are **not evidence** that a live publication is configured, and mock fixtures are never real research.

See [the 2026-11-08 API contract audit](docs/api-contract-audit-2026-11-08.md) for the endpoint matrix, backend unsupported routes, outstanding features, and verification gates.

## Architecture and data safety

- UI: SwiftUI; native navigation.
- Source of truth: DonghakStockVision read-only research API contracts, as surfaced in the web repository.
- Separate mock, disconnected and HTTP data sources; HTTP failures never fall back to mock.
- Do not synthesize market performance or silently replace network failures with simulated research results.
- Production/research readiness is determined by backend data, not frontend assumptions.
- No direct PostgreSQL access or hardcoded Tailscale IP in the client.
- Tailscale access is an optional **private development connection**, not an internet-facing production API.

## Development workflow

Feature branch → tests → commit → push → PR → CI → merge to main. Do not work directly on main.

## Next milestones

1. Shared design tokens and localized text resources.
2. Typed read-only data-source interfaces and fixture-driven tests.
3. Overview and Stocks screens matching web behavior.
4. Models, Evidence, Screener, History, Backtesting, Operations.
5. Secure HTTP transport and error states against verified snapshots.


## Research data source configuration

Set the following environment variables in the Xcode scheme (Run → Arguments → Environment Variables):

| Variable | Values | Default |
|---|---|---|
| `TRIS_DATA_MODE` | Debug: `mock`, `disconnected`, `http`; Release: `disconnected`, `http` | Debug: `mock`; Release: `disconnected` |
| `TRIS_API_BASE_URL` | Base HTTP(S) URL (required only for `http`) | unset |

- **mock**: Debug builds only; local demonstration fixtures on Overview and Stocks. Release builds reject explicit `mock` and never default to demo fixtures.
- **disconnected**: no sample research data on Overview or Stocks.
- **http**: Overview, Stocks, Models, Evidence, Backtesting and Operations use typed HTTP adapters. An invalid/missing URL produces a configuration error instead of silently switching to mock data.
- AI Screener, per-stock OHLCV and stock analysis have HTTP adapters. The backend does not publish the prediction evaluations endpoint, which fails closed without a request. Analysis History availability depends on a reviewed analysis publication.
- A configured HTTP URL does not imply the server is reachable or responses are verified. Do not enter real trading credentials in scheme variables.

The app remains iOS 17+, and uses WakTrainerDesignSystem.


## NetworkKit transport

Research HTTP calls now flow through the reusable [TrisNetworkKit](https://github.com/iosdevbyul/TrisNetworkKit) Swift package. `ResearchAPIClient` keeps its typed `fetch(_:path:)` contract for existing research data-source adapters while translating NetworkKit errors into the established `ResearchAPIError` cases.

The package revision is pinned until the compatibility change is CI-tested and merged in TrisNetworkKit. Merge the NetworkKit compatibility PR before the app integration PR; prefer a tested release tag later. `TRIS_DATA_MODE` and `TRIS_API_BASE_URL` remain unchanged. API mode never falls back to mock research outputs.


## Backend endpoint diagnostic (A-3)

In HTTP mode, the Operations screen first checks `GET /api/v1/health`, then probes the supported read-only endpoints using existing typed data-source adapters. A healthy service is **not** interpreted as proof that data publication is configured. A 503 is reported as a missing backend reader/publication; malformed payloads remain incompatible, not verified.

The backend FastAPI router currently does not expose `/api/v1/operations` or `/api/v1/stocks/{ticker}/evaluations`. These are displayed as unsupported in the diagnostic rather than fabricated successes. Stock-specific analysis and OHLCV should be checked with an actual ticker as a later step. Endpoint reports reflect only the results at the time of the check.

The app does not boot or mutate the backend. To run a real connectivity check, configure `TRIS_DATA_MODE=http` and `TRIS_API_BASE_URL` in the Xcode scheme and ensure the target device can reach the server through a secure development connection.


### Live read-only API smoke check

For an actual running DonghakStockVision server, see [A-3 verification instructions](docs/live-api-verification.md) and run `python3 scripts/verify_research_api.py --base-url <reachable-base-url>`. This checks endpoint readiness; CI does not prove a live server is reachable.


## Release-readiness checklist (C-1)

See [the release-readiness gates](docs/release-readiness.md) before treating CI success or a configured API URL as production readiness. Live connectivity, absent backend routes, device behavior, localization, and distribution checks remain manual gates until verified with evidence.
