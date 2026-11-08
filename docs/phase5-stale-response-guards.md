# Phase 5 — stale-response and cancellation guards

The native client now uses latest-request tokens in the screener-to-analysis detail navigation and operational snapshot summary/OHLCV views. A response or failure from an older user retry/refresh cannot replace a newer request's state, even when the underlying source ignores cancellation.

Stock details also clear previous metadata before loading another ticker, apply independent cancellation/latest-generation checks both after the stock request and after optional metadata, and retain the validated stock detail if optional metadata fails.

The generation helper requires exact UUID identity and accepts an explicit cancellation state. Tests cover latest-result wins, stale error suppression, cancellation, and independent concurrent request domains. These are synthetic deterministic tests, not proof of correct behavior on actual network conditions or physical devices.

No new backend API, write operation, automatic retry, mock fallback or source data assertion. The CI simulator build and XCTest are required; physical device tap/race navigation QA and approved live server remain separate gates.
