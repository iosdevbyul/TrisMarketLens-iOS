# C-1: Release readiness gates

This checklist records verifiable conditions for the iOS research client. It does **not** certify model accuracy, live API availability, or completed backtests.

## Automated gates (CI)

- XcodeGen project generation, iOS Simulator build and XCTest suite must succeed.
- Read-only API smoke-check script unit tests must pass. These test the script, **not a live server**.
- Environment tests verify explicit HTTP configuration, unsupported modes, and disconnected behavior.
- UI must never silently substitute demo fixtures after an HTTP error.

## Manual gates (before any externally distributed build)

| Gate | Verification | Status |
| --- | --- | --- |
| Live API reachability | Run `python3 scripts/verify_research_api.py --base-url <URL> --ticker <TICKER>` against a running reviewed server | NOT VERIFIED |
| Device access | Use secure private connectivity for development; verify on a physical iPhone | NOT VERIFIED |
| Endpoint coverage | Confirm all expected read-only endpoints and document 404/503; operations and evaluation routes are currently unavailable | BLOCKED |
| Research payload | Inspect ticker, timestamps, OHLCV, validation, model identity, and source freshness against backend publications | NOT VERIFIED |
| Data mode | Use `TRIS_DATA_MODE=http` with a reachable URL; confirm no mock data fallback | NOT VERIFIED |
| Error and cancellation behavior | Test retry, refresh, network loss, switching tickers, and slow responses on device | NOT VERIFIED |
| Accessibility and localization | VoiceOver, Dynamic Type, English copy, and language switching | NOT VERIFIED |
| Signing and distribution | Review bundle ID, signing, secrets, privacy requirements and TestFlight workflow | NOT VERIFIED |

## Interpretation

- A green PR or main CI run means the checked build/tests passed, **not** that the app is production-ready.
- Default `TRIS_DATA_MODE` is `mock` for development: do not treat a normal launch as a live-data verification.
- Unknown/unpublished outcomes must remain unavailable, not inferred.
- See [live API verification](live-api-verification.md) for commands and response interpretation.
- Advance the manual gates only after collecting run-specific evidence. Do not mark a gate complete from unit tests alone.
