# HTTP stock response integrity

The native iOS HTTP stock source now validates data before exposing stock-list and stock-detail responses to SwiftUI.

- Stock list: reject duplicate tickers, malformed six-digit KRX identifiers, blank market labels and unbounded result lists (10,000-item safety limit).
- Stock detail: require a valid requested ticker, exact response-to-request ticker match, nonblank market and nonblank data-status strings.
- Nullable name and sector remain valid and render using the existing fallback labels.
- Existing HTTP 404 detail handling remains `nil`; other failures and malformed data remain errors, never synthetic results.

These are fail-closed client integrity checks, not independent verification of KRX source authorization, publication freshness, or trading eligibility. Device, real backend and release gates are still pending.
