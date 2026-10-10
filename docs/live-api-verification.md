# A-3: Real DonghakStockVision API verification

The app includes NetworkKit-backed read-only diagnostics. This separate, optional
developer smoke check verifies whether a **running** API exposes the routes the
iOS client expects. It does not start the server, alter research artifacts or
declare AI results scientifically verified.

## Prerequisites

The API must already be running with a reviewed snapshot. According to
DonghakStockVision's research API documentation, local development defaults to
`http://127.0.0.1:8000`. That address works **only on the Mac hosting the API**;
an iPhone needs a separately configured reachable endpoint (e.g., secure private
network). Never commit a private IP, token or tunnel endpoint into the app.

```bash
python3 scripts/verify_research_api.py --base-url http://127.0.0.1:8000
python3 scripts/verify_research_api.py --base-url http://127.0.0.1:8000 --ticker 005930
```

The script uses only the Python standard library and makes GET requests.
It checks the actual health payload (`ok`, `DonghakStockVision`,
`read_only`) before attempting status, stocks, models, evidence,
baseline and screener. Optional stock checks cover detail, OHLCV and analysis.

## Interpreting results

- `REACHABLE` health: correct API identity, **not** proof data readers work.
- `OK` endpoint: HTTP 2xx with the expected top-level JSON type. Domain
  semantics must still be validated in the iOS adapters.
- `NOT_CONFIGURED`: 503; the API route exists but its reader/publication
  is unavailable.
- `MISSING`: 404; detail may be absent, or route unavailable.
- `INCOMPATIBLE`: invalid JSON or unexpected top-level payload.
- `UNAVAILABLE`: other HTTP or transport error.

Exit codes: 0 if all checked endpoints returned expected top-level JSON;
1 if one or more data endpoint checks failed; 2 if the health identity,
input configuration or core connection failed.

The backend currently has **no** HTTP routes for `/api/v1/operations` or
`/api/v1/stocks/{ticker}/evaluations`. Do not count these as completed
integrations. No production server availability has been established by
CI or by committing this script.

After a successful smoke check, set Xcode Run environment variables
`TRIS_DATA_MODE=http` and `TRIS_API_BASE_URL` to the reachable base URL.
Run on device and inspect the Operations API connectivity panel and the
individual research screens. Report any HTTP 503 or malformed response;
do not replace it with mock data.
