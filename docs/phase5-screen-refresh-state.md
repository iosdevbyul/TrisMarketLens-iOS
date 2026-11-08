# Phase 5 — Research screen refresh state consistency

Overview, Stocks, AI Screener and Analysis History use the shared latest-request generation guard. Each new user refresh or explicit retry begins by invalidating the previous request and clearing the previous visible records before loading, instead of allowing a prior publication to remain on screen as if it belonged to the new request.

Only the latest, non-cancelled request can update its results, error message or loading flag. Optional stock-name metadata remains best effort: a missing metadata response cannot create a false publication or replace the current stock list. Successful requests receive only the returned records; failed requests do not fall back to mock data.

This is a consistency safeguard for rapidly repeated refreshes and navigation. It does **not** add automatic retries, persistent caching, a background polling loop, live market claims or backend write access.

Deterministic XCTest covers repeated refresh, stale success, cancellation and stale loading state changes using the shared request-generation primitive. Simulator CI build and XCTest are required. Slow network, accessibility and physical iPhone testing remain separate manual Phase 5 release gates.
