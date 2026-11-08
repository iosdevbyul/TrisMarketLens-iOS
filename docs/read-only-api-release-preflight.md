# Read-only API release preflight

The existing Operations diagnostics now includes validated operational market summary and stock-index GET routes plus the restricted historical portfolio archive. The historical archive probe is **never sent to non-loopback destinations**. On remote configurations it remains explicitly restricted.

A typed summary distinguishes:
- not checked or disconnected;
- source unavailable (no responding routes);
- partially available (one or more required routes missing, unconfigured or incompatible);
- required routes responding (each expected path returned a decodable payload).

Required paths include project status, stocks, models, evidence, operational summary and stock index, and operations runs. Individual optional backtest, screener, historical portfolio, alerts and forecast evaluation publication paths retain their own unavailable state and do not silently become green. Duplicate required path reports cannot pass.

**A fully responsive API is not release approval.** The preflight neither certifies raw KRX collection/source integrity nor historical point-in-time authorization, brokerage execution, physical device connectivity, privacy or signing. Run this against an explicitly configured, authorized read-only API. Do not expose the locally protected historical portfolio endpoints to remote clients.

XCTest covers all required and partial states, 503/unavailable, duplicate reports, demo/disconnected behavior and local-only restrictions. Device and operator evidence remain manual release gates.
