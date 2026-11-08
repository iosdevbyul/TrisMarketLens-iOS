# Phase 5 — Network recovery and explicit retry UX

The native research client distinguishes network **timeout** and **offline/interrupted connectivity** from generic transport errors. The same NetworkKit error classification is used for both read-only GET and the restricted JSON POST operations. The existing HTTP 401/403/404/429/503 and incompatible-payload categories remain separate.

Overview, Stocks, AI Screener and Analysis History now show a reusable accessible failure panel with an error-specific recovery instruction and an **explicit Retry request** button. Retry triggers exactly one new user-initiated request. In-flight duplicate retry on the Stocks loading view has been removed. Overview clears the old status before loading again, so a stale dashboard does not remain visible as though it were refreshed.

No automatic retries, background polling, cached success fallback, mock substitution or new write paths are introduced. A 503 caused by a missing operator-approved snapshot is not treated as connectivity success. Authorization failures do not imply a retry can bypass access control.

Synthetic XCTest with injected NetworkKit clients verifies a timeout/connection-lost request does not retry silently, then recovers only on explicit second invocation; POST follows the same mapping, and malformed responses remain rejected. Error guidance and retry advice are tested independently.

CI covers Debug/Release simulator build and XCTest; manual Airplane Mode, poor connectivity, large Dynamic Type and real physical iPhone checks are still pending.
