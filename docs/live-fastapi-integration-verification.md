# Live FastAPI integration verification

Backend reference: `iosdevbyul/DonghakStockVision` at `256c793beae7f3f8d6ac30ff0ecca96fe64d4093` (read-only inspection). iOS baseline: `a7e7721e2bbaea0d4e5ca6e20d995c109537a19e`.

## Local Mac-only checks

Run on the Mac where FastAPI is running, **not** GitHub Actions or a remote machine:

```sh
git status --short
git fetch origin
git rev-parse origin/main
curl -i http://127.0.0.1:8000/api/v1/health
python3 scripts/verify_research_api.py --base-url http://127.0.0.1:8000 --ticker 005930
```

Exit code 0 means all checked routes returned compatible *top-level* JSON, **not** that nested research data or iOS rendering is verified. Exit code 1 indicates at least one data route failed or is incompatible. HTTP 503 is an unconfigured reader/publication and is **not** a test success. 404 is missing, network exceptions are unavailable, invalid JSON/required fields are incompatible. The tool does not invoke any writes.

Backend `app.py` declares health, project/status, stocks, stock detail, OHLCV, analysis, screener, models, evidence, baseline plus research/coverage. It **does not** declare `/api/v1/operations` or `/api/v1/stocks/{ticker}/evaluations`: keep those unsupported, do not emulate them.

## iOS Simulator

Set the **Debug scheme Run** environment variables:

```
TRIS_DATA_MODE=http
TRIS_API_BASE_URL=http://127.0.0.1:8000
```

This loopback address applies only to a simulator running on the same Mac as the API. Do not use it for physical iPhones. Keep Release in disconnected/secure mode. iOS networking uses TrisNetworkKit; there is no mock fallback when HTTP mode is selected.

**ATS review:** `project.yml` currently generates Info.plist and does not configure an ATS exception. Plain HTTP might therefore be denied by App Transport Security. A request failure here does not prove backend unavailability. A **Debug-only, narrowly scoped** local networking exception must be configured and validated on the user's Xcode/simulator environment if ATS blocks the request; do not globally disable ATS or relax Release security. This PR intentionally does not introduce an unverified broad ATS exemption.

Open Overview, Stocks, Stock Detail, OHLCV, AI Analysis, AI Screener, Models, Evidence, Backtesting, Operations diagnostics. Record actual GET status, decoded/failed JSON, and visible state for each. No device or live-simulator verification can be claimed from a remote GitHub connector. The iOS app does not have access to the Mac's loopback socket through GitHub Actions.

## Evidence matrix

| Route | FastAPI main | Mac HTTP | iOS simulator |
|---|---|---|---|
| /api/v1/health | Registered | Not executed here | Not executed |
| /api/v1/project/status | Registered, requires reader | Not executed | Not executed |
| /api/v1/stocks | Registered, requires reader | Not executed | Not executed |
| /api/v1/stocks/005930 | Registered, requires reader | Not executed | Not executed |
| /api/v1/stocks/005930/ohlcv | Registered, requires OHLCV reader | Not executed | Not executed |
| /api/v1/stocks/005930/analysis | Registered, requires publisher | Not executed | Not executed |
| /api/v1/analysis/screener | Registered, requires publisher | Not executed | Not executed |
| /api/v1/models | Registered, requires reader | Not executed | Not executed |
| /api/v1/evidence | Registered, requires reader | Not executed | Not executed |
| /api/v1/backtests/baseline | Registered, requires reader | Not executed | Not executed |
| /api/v1/operations | Not registered | Unsupported | Unsupported |
| /api/v1/stocks/005930/evaluations | Not registered | Unsupported | Unsupported |

GitHub CI exercises synthetic HTTP fixtures and builds/tests; this is not a live Mac network run. Stock OHLCV bar order, dates, timezone, and individual analysis IDs still require checks against real published payloads. The backend's date fields are ISO-like strings and iOS currently displays server date strings without timezone conversion.
