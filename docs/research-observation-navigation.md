# Research observation navigation — 2026-11-08

## Scope
The AI Screener screen already reads `GET /api/v1/analysis/screener` through `HTTPScreenerSource` in HTTP mode. Analysis History aggregates the same published source; it is not a separate historical predictions API.

This change adds an interactive native SwiftUI drill-down from a screener entry to `GET /api/v1/stocks/{ticker}/analysis`. The detail is **only** displayed when exactly one record corroborates the screener index's ticker, analysis ID, model ID/version, date, publication timestamp, direction, validation and score. If no record matches, the UI presents a provenance mismatch rather than showing a different analysis. Server/transport/JSON errors remain errors with Retry; no mock substitution occurs.

The existing `StockAnalysisDetailView` is reused. Prediction evaluation remains explicitly unavailable because the backend does not publish the legacy stock evaluations route. This is **not** an investment signal or a claim of profitable forecasts.

## Tests and outstanding verification
`ResearchObservationMatchTests` covers exact identity, cross-ticker mismatch, model/version or validation mismatch, missing and duplicate publication. The existing API contract and HTTP failure tests remain in the repository CI.

Pending independent validation: a running approved backend with a populated screener and individual published analyses, simulator navigation inspection, and physical-device QA. Research Workbench, historical portfolio comparison and full provenance graph are follow-on phases, not claimed here.
