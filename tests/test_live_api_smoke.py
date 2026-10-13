"""Offline contract tests for the read-only live API smoke checker."""
import importlib.util
import io
import json
from pathlib import Path
import unittest
from unittest.mock import patch
import urllib.error

SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "verify_research_api.py"
spec = importlib.util.spec_from_file_location("verify_research_api", SCRIPT)
checker = importlib.util.module_from_spec(spec)
spec.loader.exec_module(checker)


class FakeResponse:
    def __init__(self, body):
        self.body = body

    def __enter__(self):
        return self

    def __exit__(self, *args):
        return False

    def read(self, size):
        return self.body[:size]


class LiveAPISmokeTests(unittest.TestCase):
    def test_health_and_all_supported_routes(self):
        def urlopen(request, timeout):
            path = request.full_url.split(".test", 1)[-1]
            self.assertEqual(request.get_method(), "GET")
            self.assertEqual(request.get_header("Accept"), "application/json")
            if path == "/api/v1/health":
                data = {"status": "ok", "service": "DonghakStockVision", "mode": "read_only"}
            elif path in ("/api/v1/stocks", "/api/v1/models", "/api/v1/evidence"):
                data = []
            elif path == "/api/v1/project/status":
                data = {"productName": "Research", "sourceLabel": "source", "metrics": [], "evidence": [], "baseline": []}
            elif path == "/api/v1/analysis/screener":
                data = {"entries": []}
            elif path.endswith("/ohlcv"):
                data = {"ticker": "005930", "bars": []}
            elif path.endswith("/analysis"):
                data = {"ticker": "005930", "records": []}
            else:
                data = {}
            return FakeResponse(json.dumps(data).encode())

        with patch.object(checker.urllib.request, "urlopen", side_effect=urlopen):
            with patch("sys.stdout", new_callable=io.StringIO) as output:
                self.assertEqual(checker.verify("https://research.test", 2, "005930"), 0)
                self.assertIn("Health: REACHABLE", output.getvalue())


    def test_missing_required_keys_fail_contract(self):
        def urlopen(request, timeout):
            if request.full_url.endswith("/health"):
                return FakeResponse(b'{"status":"ok","service":"DonghakStockVision","mode":"read_only"}')
            return FakeResponse(b'{}')

        with patch.object(checker.urllib.request, "urlopen", side_effect=urlopen):
            with patch("sys.stdout", new_callable=io.StringIO) as output:
                self.assertEqual(checker.verify("https://research.test", 2, "005930"), 1)
                self.assertIn("Missing fields:", output.getvalue())

    def test_ohlcv_validates_prices_and_volume_without_fabricating_data(self):
        good = {"ticker": "005930", "bars": [
            {"date": "2026-10-12", "open": 100, "high": 105, "low": 95, "close": 102, "volume": 200}
        ]}
        self.assertIsNone(checker.validate_ohlcv(good, "005930"))
        variants = [
            {**good, "ticker": "000660"},
            {**good, "bars": [{}]},
            {**good, "bars": [dict(good["bars"][0], high=99)]},
            {**good, "bars": [dict(good["bars"][0], volume=-1)]},
            {**good, "bars": [dict(good["bars"][0], close=float("nan"))]},
            {**good, "bars": good["bars"] * 2},
        ]
        for payload in variants:
            with self.subTest(payload=repr(payload)):
                self.assertIsNotNone(checker.validate_ohlcv(payload, "005930"))

    def test_ohlcv_invalid_nested_data_causes_failed_smoke_check(self):
        def urlopen(request, timeout):
            path = request.full_url.split(".test", 1)[-1]
            if path == "/api/v1/health":
                data = {"status": "ok", "service": "DonghakStockVision", "mode": "read_only"}
            elif path == "/api/v1/project/status":
                data = {"productName": "Research", "sourceLabel": "source", "metrics": [], "evidence": [], "baseline": []}
            elif path == "/api/v1/analysis/screener":
                data = {"entries": []}
            elif path.endswith("/ohlcv"):
                data = {"ticker": "005930", "bars": [{"date": "2026-10-12"}]}
            elif path.endswith("/analysis"):
                data = {"ticker": "005930", "records": []}
            elif path in ("/api/v1/stocks", "/api/v1/models", "/api/v1/evidence"):
                data = []
            else:
                data = {}
            return FakeResponse(json.dumps(data).encode())
        with patch.object(checker.urllib.request, "urlopen", side_effect=urlopen):
            with patch("sys.stdout", new_callable=io.StringIO) as output:
                self.assertEqual(checker.verify("https://research.test", 2, "005930"), 1)
                self.assertIn("missing OHLCV fields", output.getvalue())

    def test_503_reader_is_not_success(self):
        def urlopen(request, timeout):
            if request.full_url.endswith("/health"):
                return FakeResponse(b'{"status":"ok","service":"DonghakStockVision","mode":"read_only"}')
            raise urllib.error.HTTPError(request.full_url, 503, "unconfigured", {}, None)

        with patch.object(checker.urllib.request, "urlopen", side_effect=urlopen):
            with patch("sys.stdout", new_callable=io.StringIO) as output:
                self.assertEqual(checker.verify("https://research.test", 2, None), 1)
                self.assertIn("NOT_CONFIGURED", output.getvalue())

    def test_wrong_health_identity_blocks_all_other_requests(self):
        calls = []

        def urlopen(request, timeout):
            calls.append(request.full_url)
            return FakeResponse(b'{"status":"ok","service":"Unknown","mode":"read_only"}')

        with patch.object(checker.urllib.request, "urlopen", side_effect=urlopen):
            with patch("sys.stdout", new_callable=io.StringIO):
                self.assertEqual(checker.verify("https://research.test", 2, None), 2)
        self.assertEqual(len(calls), 1)

    def test_malformed_json_is_incompatible(self):
        with patch.object(checker.urllib.request, "urlopen", return_value=FakeResponse(b'not-json')):
            state, _ = checker.request("https://research.test", "/api/v1/health", 2)
        self.assertEqual(state, "INCOMPATIBLE")

    def test_invalid_ticker_is_rejected_before_any_network_request(self):
        invalid = ("../etc", "abc", "ABC/12", "한글1234", "abc123", "ＡＢＣ１２３")
        with patch.object(checker.urllib.request, "urlopen") as urlopen:
            with patch("sys.stderr", new_callable=io.StringIO):
                for ticker in invalid:
                    with self.subTest(ticker=ticker):
                        self.assertEqual(checker.verify("https://research.test", 2, ticker), 2)
        urlopen.assert_not_called()

    def test_rejects_base_path_before_network_connection(self):
        invalid_bases = (
            "https://research.test/api",
            "https://research.test/api/v1/",
            "https://research.test/other",
        )
        with patch.object(checker.urllib.request, "urlopen") as urlopen:
            with patch("sys.stderr", new_callable=io.StringIO):
                for base in invalid_bases:
                    with self.subTest(base=base):
                        self.assertEqual(checker.verify(base, 2, None), 2)
        urlopen.assert_not_called()

    def test_rejects_untrusted_base_url_parameters(self):
        with patch("sys.stderr", new_callable=io.StringIO):
            self.assertEqual(checker.verify("https://name:pass@research.test", 2, None), 2)
            self.assertEqual(checker.verify("file:///tmp", 2, None), 2)


if __name__ == "__main__":
    unittest.main()
