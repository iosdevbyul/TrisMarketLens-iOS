# Operations API v1 — iOS integration

Backend source of truth: `DonghakStockVision/docs/operations-api.md`.
Backend PRs #104 and #105 implement three read-only routes.

## Connection

Debug simulator run scheme is configured in `project.yml` with `TRIS_DATA_MODE=http` and `TRIS_API_BASE_URL=http://127.0.0.1:8000`. Start the locally configured backend with its snapshot and operations evidence root to obtain actual records. Neither a real iPhone nor a remote machine can access the Mac's localhost at that address. A secure authenticated deployment or permitted network access and TLS is needed for real devices; no ATS relaxation is included.

## Mapping

The Operations page retains existing health and endpoint readiness probes, and consumes independent `GET /api/v1/operations/runs`, `/freshness` and `/alerts` through the existing ResearchAPIClient/NetworkKit stack. Backtesting remains on `GET /api/v1/backtests/baseline`, unchanged.

All responses require `schemaVersion = operations_v1`. Runs and alerts use explicit bounded offset/limit (default 25, max 100 per call, offset max 100000); the UI loads another page only by user action. Missing/unsupported versions and invalid page metadata fail closed rather than silently showing empty successful data. The server determines run and alert ordering and stable IDs. No automatic unbounded fetching occurs.

## Evidence and freshness

Execution status (`completed`, `incomplete`, `failed`, `interrupted`, `not_started`) is independent of evidence status (`validated`, `partial`, `invalid`, `unavailable`). Validated only means local contractual integrity, not independent authentication. DART acquisitions are not corporate action semantic approval. Unapproved session Drafts are not projected by the backend. `semanticApproval` is displayed separately.

Freshness is per source (`market_snapshot` and `dart_acquisition`), with `fresh`, `stale`, `unknown` or `blocked` and separate evidence status. Date-only `latestDataDate` stays date-only. Null timestamps are shown as unavailable, never substituted with approval or current time. Only backend-defined thresholds are displayed. DART acquisition recency does not establish publication completeness.

Alerts distinguish recorded incidents from advisory warnings. Unknown codes remain explicitly unrecognized; the UI must never convert unknown states to success. `dart_evidence_busy` means temporary writer lock unavailability, not historical data corruption. Counts are always from API fields, never hardcoded. HTTP 200 is not evidence validation by itself.

## Failures, testing and limitations

Each section has independent loading/error/retry handling. A failing source must not replace successful data in other sections. There is no mock-data fallback for HTTP mode. Offline tests use synthetic JSON model fixtures and a scripted NetworkKit client; they do not access OpenDART or validate real operational evidence.

Simulator: run localhost backend with configured snapshot and operations root, navigate to Operations, check all three sections and endpoint readiness, load next runs/alerts pages when totals permit, stop/restart the backend and retry. Review long IDs, Dynamic Type, VoiceOver, light/dark themes. **CI builds and decoding tests do not constitute simulator visual verification.**

Known limitations: no push feed, no public authenticated Operations deployment, and no independently reviewed generic pipeline/backtest execution registry. The API does not authorize backtesting or live DART sessions.
