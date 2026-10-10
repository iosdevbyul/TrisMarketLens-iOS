#!/usr/bin/env python3
"""Read-only live API smoke check. No credentials, mutations, or fake success."""
import argparse
import json
import sys
import urllib.error
import urllib.parse
import urllib.request

PATHS = (
    ("Project status", "/api/v1/project/status", dict),
    ("Stocks", "/api/v1/stocks", list),
    ("Models", "/api/v1/models", list),
    ("Evidence", "/api/v1/evidence", list),
    ("Baseline", "/api/v1/backtests/baseline", dict),
    ("Screener", "/api/v1/analysis/screener", dict),
)


def request(base: str, path: str, timeout: float):
    request_url = base.rstrip("/") + path
    req = urllib.request.Request(request_url, headers={"Accept": "application/json"}, method="GET")
    try:
        with urllib.request.urlopen(req, timeout=timeout) as response:
            data = response.read(5_000_001)
            if len(data) > 5_000_000:
                return "INCOMPATIBLE", "Response exceeded 5 MB"
            try:
                return "OK", json.loads(data)
            except (json.JSONDecodeError, UnicodeDecodeError):
                return "INCOMPATIBLE", "Not valid JSON"
    except urllib.error.HTTPError as error:
        if error.code == 503:
            return "NOT_CONFIGURED", "HTTP 503 (snapshot or publication unavailable)"
        if error.code == 404:
            return "MISSING", "HTTP 404"
        return "UNAVAILABLE", f"HTTP {error.code}"
    except (urllib.error.URLError, TimeoutError, OSError) as error:
        return "UNAVAILABLE", type(error).__name__


def verify(base: str, timeout: float, ticker: str | None) -> int:
    parsed = urllib.parse.urlsplit(base)
    if parsed.scheme not in ("http", "https") or not parsed.hostname or parsed.username or parsed.password or parsed.query or parsed.fragment:
        print("Invalid API base URL. Expected http(s)://host[:port] without credentials or query.", file=sys.stderr)
        return 2
    status, health = request(base, "/api/v1/health", timeout)
    if status != "OK" or not isinstance(health, dict) or (
        health.get("status"), health.get("service"), health.get("mode")
    ) != ("ok", "DonghakStockVision", "read_only"):
        print(f"Health: FAILED ({status}) — not a verified DonghakStockVision read-only service")
        return 2
    print("Health: REACHABLE (read-only service; data publication not yet established)")
    paths = list(PATHS)
    if ticker is not None:
        if len(ticker) != 6 or not ticker.isalnum() or ticker.upper() != ticker:
            print("Ticker must be exactly six uppercase letters/digits.", file=sys.stderr)
            return 2
        paths.extend((
            ("Stock detail", f"/api/v1/stocks/{ticker}", dict),
            ("OHLCV", f"/api/v1/stocks/{ticker}/ohlcv", dict),
            ("Stock analysis", f"/api/v1/stocks/{ticker}/analysis", dict),
        ))
    failures = 0
    for label, path, expected in paths:
        state, result = request(base, path, timeout)
        if state == "OK":
            if not isinstance(result, expected):
                state, result = "INCOMPATIBLE", f"Expected {expected.__name__} JSON"
            else:
                result = "JSON shape checked; domain validation still required"
        if state != "OK":
            failures += 1
        print(f"{label:16} {state:16} {path} — {result}")
    print("Known backend-unimplemented endpoints: /api/v1/operations, /api/v1/stocks/{ticker}/evaluations")
    print("HTTP and top-level JSON checks do not establish published research integrity.")
    return 0 if failures == 0 else 1


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base-url", required=True, help="Reachable DonghakStockVision API URL")
    parser.add_argument("--ticker", help="Optional six-character stock identifier for detailed routes")
    parser.add_argument("--timeout", type=float, default=10.0)
    args = parser.parse_args()
    if not 0 < args.timeout <= 60:
        parser.error("--timeout must be between 0 and 60")
    sys.exit(verify(args.base_url, args.timeout, args.ticker))


if __name__ == "__main__":
    main()
