# TrisMarketLens (iOS)

Native SwiftUI companion to [TrisMarketLens Web](https://github.com/iosdevbyul/TrisMarketLens), backed eventually by [DonghakStockVision](https://github.com/iosdevbyul/DonghakStockVision).

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

## Current scope

The first milestone implements the application shell and navigation matching the **eight actual web sidebar sections**: Overview, Stocks, AI Screener, AI Analysis History, Models, Evidence, Backtesting, and Operations. Section content is explicitly placeholder-only, **not actual AI output or investment performance**.

The web has additional detail routes under Stocks, Models, Evidence and Backtesting. These belong to later milestones.

## Architecture and data safety

- UI: SwiftUI; native navigation.
- Source of truth: DonghakStockVision read-only research API contracts, as surfaced in the web repository.
- Separate mock and HTTP data sources in future milestones.
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
| `TRIS_DATA_MODE` | `mock`, `disconnected`, `http` | `mock` |
| `TRIS_API_BASE_URL` | Base HTTP(S) URL (required only for `http`) | unset |

- **mock**: local demonstration fixtures on Overview and Stocks; other research views remain disconnected.
- **disconnected**: no sample research data on Overview or Stocks.
- **http**: Overview, Stocks, Models, Evidence, Backtesting and Operations use typed HTTP adapters. An invalid/missing URL produces a configuration error instead of silently switching to mock data.
- AI Screener, Analysis History and per-stock OHLCV/analysis/evaluation remain disconnected until their HTTP sources are wired in a follow-up PR.
- A configured HTTP URL does not imply the server is reachable or responses are verified. Do not enter real trading credentials in scheme variables.

The app remains iOS 17+, and uses WakTrainerDesignSystem.


## NetworkKit transport

Research HTTP calls now flow through the reusable [TrisNetworkKit](https://github.com/iosdevbyul/TrisNetworkKit) Swift package. `ResearchAPIClient` keeps its typed `fetch(_:path:)` contract for existing research data-source adapters while translating NetworkKit errors into the established `ResearchAPIError` cases.

The package revision is pinned until the compatibility change is CI-tested and merged in TrisNetworkKit. Merge the NetworkKit compatibility PR before the app integration PR; prefer a tested release tag later. `TRIS_DATA_MODE` and `TRIS_API_BASE_URL` remain unchanged. API mode never falls back to mock research outputs.
