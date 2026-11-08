# Native Historical Portfolio Comparison — 2026-11-08

The native Historical Portfolios catalog supports selecting 2–5 distinct operator-pinned historical reports for read-only comparison. This mirrors DonghakStockVision's POST /api/v1/research/historical-portfolios/compare. The POST is **read-only** on the backend and is not model execution, report publication, brokerage action or trading.

## Access and contract
- Backend comparison is opt-in, loopback-only, locally operator authorized. The iOS adapter rejects non-loopback HTTP bases before requests, as with existing archived GET routes.
- NetworkKit's existing Endpoint supports POST plus an Encodable JSON body; the ResearchAPIClient now supports bounded application/json requests without changing GET behavior.
- The selection contains 2–5 distinct 64-character lowercase hexadecimal IDs only. No user-provided paths or archive locators.
- Response schema is historical_portfolio_comparison_v1. Validate all research-only/forbidden execution and investment eligibility flags and exact, ordered ID correspondence to requested reports.
- Each summary must pass existing published_historical_portfolio_v1 provenance, source hash, five-ticker and restrictions checks. Nullable cash/equity/return fields remain unavailable rather than estimated.
- Comparison notices must explicitly include no ranking/recommendation and unavailable valuation policy, even if periods or observed market fields appear equal.

## UX and limits
Native catalog has report selection and a side-by-side-equivalent, sequential report-details comparison view with preserved selection order and server-published comparability notices. No numeric rank, return sort, trading recommendation or implicit valuation policy equivalence is computed.

Tests exercise valid/invalid report IDs, duplicate/oversize selections, out-of-order responses, invalid approval and missing policy, nullable values and remote access rejection.

Physical iPhone localhost cannot reach a Mac's loopback endpoint. No external tunnel, proxy, production archive access, actual data publish, device QA, exchange execution or PIT/OOS validation is claimed.
