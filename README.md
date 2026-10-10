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
