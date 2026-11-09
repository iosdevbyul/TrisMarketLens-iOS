#!/usr/bin/env python3
"""Read-only live API smoke check. No credentials, mutations, or fake success."""
import argparse
from datetime import date
import re
import json
import math
import sys
import urllib.error
import urllib.parse
import urllib.request

REQUIRED_FIELDS = {
    "/api/v1/project/status": {"productName", "sourceLabel", "metrics", "evidence", "baseline"},
    "/api/v1/analysis/screener": {"entries"},
    "/api/v1/stocks/{ticker}/ohlcv": {"ticker", "bars"},
    "/api/v1/stocks/{ticker}/analysis": {"ticker", "records"},
}

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



def validate_ohlcv(payload: dict, ticker: str):
    """Check only structural OHLCV invariants; do not certify source integrity."""
    if payload.get("ticker") != ticker or not isinstance(payload.get("bars"), list):
        return "Ticker mismatch or bars is not a list"
    seen = set()
    for index, bar in enumerate(payload["bars"]):
        if not isinstance(bar, dict):
            return f"Bar {index} is not an object"
        required = ("date", "open", "high", "low", "close", "volume")
        if any(key not in bar for key in required):
            return f"Bar {index} missing OHLCV fields"
        date_text = bar["date"]
        if not isinstance(date_text, str) or not re.fullmatch(r"[0-9]{4}-[0-9]{2}-[0-9]{2}", date_text):
            return f"Bar {index} has invalid date"
        try:
            date.fromisoformat(date_text)
        except ValueError:
            return f"Bar {index} has invalid calendar date"
        if bar["date"] in seen:
            return f"Bar {index} repeats date"
        seen.add(bar["date"])
        values = [bar[key] for key in ("open", "high", "low", "close")]
        if any(type(value) not in (int, float) or not __import__("math").isfinite(value) or value < 0 for value in values):
            return f"Bar {index} has invalid price"
        opening, high, low, closing = values
        if low > min(opening, closing) or high < max(opening, closing) or high < low:
            return f"Bar {index} violates OHLC bounds"
        if type(bar["volume"]) is not int or bar["volume"] < 0:
            return f"Bar {index} has invalid volume"
    return None

def validate_stock_detail(payload: dict, ticker: str):
    """Check the StockDetail decoding contract, not live source authenticity."""
    if payload.get("ticker") != ticker:
        return "Stock detail ticker mismatch"
    required = ("market", "dataStatus", "latestDataDate", "availableFrom", "evidenceNote", "chartNote")
    if any(not isinstance(payload.get(key), str) for key in required):
        return "Stock detail has missing or invalid required string fields"
    if not payload["market"].strip() or not payload["dataStatus"].strip():
        return "Stock detail market or dataStatus is blank"
    for optional in ("name", "sector"):
        if optional in payload and payload[optional] is not None and not isinstance(payload[optional], str):
            return f"Stock detail has invalid {optional}"
    return None


def validate_analysis(payload: dict, ticker: str):
    """Check analysis identity and record structure, not model performance."""
    if payload.get("ticker") != ticker or not isinstance(payload.get("records"), list):
        return "Analysis ticker mismatch or records is not a list"
    seen = set()
    required = ("id", "ticker", "analyzedAt", "dataThrough", "modelId", "modelVersion", "direction", "validation")
    for index, record in enumerate(payload["records"]):
        if not isinstance(record, dict):
            return f"Analysis record {index} is not an object"
        if any(not isinstance(record.get(key), str) or not record[key].strip() for key in required):
            return f"Analysis record {index} has invalid required fields"
        if record["ticker"] != ticker:
            return f"Analysis record {index} ticker mismatch"
        if record["id"] in seen:
            return f"Analysis record {index} repeats ID"
        seen.add(record["id"])
        if "score" not in record:
            return f"Analysis record {index} missing score"
        score = record["score"]
        if score is not None and (type(score) not in (int, float) or not math.isfinite(score)):
            return f"Analysis record {index} has invalid score"
        if record.get("explanation") is not None and not isinstance(record["explanation"], str):
            return f"Analysis record {index} has invalid explanation"
    return None


def verify(base: str, timeout: float, ticker: str | None) -> int:
    parsed = urllib.parse.urlsplit(base)
    if parsed.scheme not in ("http", "https") or not parsed.hostname or parsed.username or parsed.password or parsed.query or parsed.fragment or parsed.path not in ("", "/"):
        print("Invalid API base URL. Expected http(s)://host[:port] without credentials, path, query or fragment.", file=sys.stderr)
        return 2
    if ticker is not None and (len(ticker) != 6 or not ticker.isascii() or not ticker.isalnum() or ticker.upper() != ticker):
        print("Ticker must be exactly six uppercase ASCII letters/digits.", file=sys.stderr)
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
                canonical = path.replace(ticker, "{ticker}") if ticker else path
                required = REQUIRED_FIELDS.get(canonical, set())
                missing = required.difference(result) if isinstance(result, dict) else set()
                if missing:
                    state, result = "INCOMPATIBLE", "Missing fields: " + ", ".join(sorted(missing))
                elif ticker and canonical == "/api/v1/stocks/{ticker}" and (issue := validate_stock_detail(result, ticker)):
                    state, result = "INCOMPATIBLE", issue
                elif ticker and canonical == "/api/v1/stocks/{ticker}/ohlcv" and (issue := validate_ohlcv(result, ticker)):
                    state, result = "INCOMPATIBLE", issue
                elif ticker and canonical == "/api/v1/stocks/{ticker}/analysis" and (issue := validate_analysis(result, ticker)):
                    state, result = "INCOMPATIBLE", issue
                else:
                    result = "JSON contract checked; source integrity still requires independent verification"
        if state != "OK":
            failures += 1
        print(f"{label:16} {state:16} {path} — {result}")
    print("UNSUPPORTED /api/v1/operations (not a registered backend route)")
    print("UNSUPPORTED /api/v1/stocks/{ticker}/evaluations (not a registered backend route)")
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
