# Research Path: operational-market custody boundary (Phase 4)

## Scope
Connect the existing Research Path collection stage to the independent read-only operational-market summary API, following PR #92. Its response reports observationCount, tickerCount, firstTradingDate, lastTradingDate and evidenceStatus=unreviewed. The stage distinguishes unavailable / no observations / records observed / demo. It allows navigation to the existing offline-snapshot operational catalog.

## Safety and semantics
A response marked unreviewed is an observation count, not verified exchange coverage, raw provider custody, an independently confirmed SHA, AI model eligibility, historical ticker identity, PIT/OOS validity or trading approval. The response does not contain the pinned artifact SHA or raw capture receipts: these are marked unavailable rather than guessed. Independent research universe, AI records and historical portfolio stages are never upgraded by the number of collected bars.

The backend only serves an operator-configured SHA-pinned **offline snapshot** through its read-only HTTP API. The app does not connect to active collection databases, copy artifacts or start collection. No new backend route or hosted access is introduced.

## Tests and release gate
Unit tests cover absent evidence, empty, positive unreviewed observations, unexpected approval labels, endpoint failures and demo. GitHub CI must verify both simulator build configurations and XCTest. No real KRX acquisition, raw provenance pin, authorized deployment or physical device verification has been performed by this UI integration.
