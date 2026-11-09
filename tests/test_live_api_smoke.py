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




AUDIT_SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "audit_release_config.py"
audit_spec = importlib.util.spec_from_file_location("audit_release_config", AUDIT_SCRIPT)
release_audit = importlib.util.module_from_spec(audit_spec)
audit_spec.loader.exec_module(release_audit)


class ReleaseConfigurationAuditTests(unittest.TestCase):
    def setUp(self):
        self.good = (
            'deploymentTarget:\n'
            '  iOS: "17.0"\n'
            '  PRODUCT_BUNDLE_IDENTIFIER: com.iosdevbyul.TrisMarketLens\n'
            '  TRIS_DATA_MODE: disconnected\n'
        )

    def test_repository_release_configuration_audit(self):
        root = Path(__file__).resolve().parents[1]
        self.assertEqual(
            release_audit.audit(
                (root / "project.yml").read_text(encoding="utf-8"),
                release_audit.tracked_files(root),
            ), [],
        )

    def test_detects_debug_local_url_or_production_like_launch(self):
        self.assertTrue(release_audit.audit(
            self.good + "  TRIS_API_BASE_URL: http://127.0.0.1:8000\n", []
        ))
        self.assertTrue(release_audit.audit(
            self.good.replace("disconnected", "http"), []
        ))

    def test_detects_ats_exceptions(self):
        self.assertTrue(release_audit.audit(
            self.good + "  NSAllowsArbitraryLoads: YES\n", []
        ))
        self.assertTrue(release_audit.audit(
            self.good + "  NSExceptionAllowsInsecureHTTPLoads: true\n", []
        ))

    def test_detects_tracked_secrets_and_signing_assets(self):
        for path in (".env", "Certificates/Distribution.p12",
                     "Profiles/app.mobileprovision", "keys/AuthKey_ABCD.p8"):
            with self.subTest(path=path):
                self.assertTrue(release_audit.audit(self.good, [path]))

    def test_nonsecret_examples_are_allowed(self):
        self.assertEqual(release_audit.audit(
            self.good, [".env.example", "README.md", "docs/privacy-policy.md"]
        ), [])


class ReleaseEvidenceReportTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        import sys
        script_dir = Path(__file__).resolve().parents[1] / "scripts"
        sys.path.insert(0, str(script_dir))
        try:
            spec = importlib.util.spec_from_file_location(
                "release_evidence", script_dir / "release_evidence.py"
            )
            cls.module = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(cls.module)
        finally:
            sys.path.remove(str(script_dir))

    def test_offline_report_cannot_claim_release_approved(self):
        report = self.module.build_report("a" * 40, [], "2026-11-09T00:00:00+00:00")
        self.assertFalse(report["release_approved"])
        self.assertEqual(report["readiness"], "blocked")
        self.assertEqual(report["scope"], "offline_source_audit_only")
        self.assertEqual(report["automated_gates"]["release_source_configuration"]["status"], "passed")
        for key, gate in report["manual_gates"].items():
            with self.subTest(gate=key):
                self.assertEqual(gate["status"], "not_verified")
                self.assertIsNone(gate["evidence"])

    def test_unobserved_ci_jobs_are_never_inferred_from_source_audit(self):
        report = self.module.build_report("b" * 40, [], "2026-11-09T00:00:00+00:00")
        for key, gate in report["automated_gates"].items():
            if key != "release_source_configuration":
                with self.subTest(job=key):
                    self.assertEqual(gate["status"], "not_checked")

    def test_failed_source_audit_does_not_approve_release(self):
        report = self.module.build_report(
            "c" * 40, ["Tracked signing material detected"], "2026-11-09T00:00:00+00:00"
        )
        self.assertEqual(report["automated_gates"]["release_source_configuration"]["status"], "failed")
        self.assertEqual(report["configuration_findings"], ["Tracked signing material detected"])
        self.assertFalse(report["release_approved"])

    def test_partial_or_invalid_revision_cannot_be_recorded(self):
        for sha in ("abc123", "", "not-a-commit", "g" * 40):
            with self.subTest(sha=sha):
                with self.assertRaises(ValueError):
                    self.module.build_report(sha, [], "2026-11-09T00:00:00+00:00")

    def test_report_schema_serializes_without_credentials_or_fake_evidence(self):
        report = self.module.build_report("d" * 40, [], "2026-11-09T00:00:00+00:00")
        restored = json.loads(json.dumps(report))
        self.assertEqual(restored["schema_version"], 1)
        self.assertEqual(restored["commit"], "d" * 40)
        self.assertNotIn("token", restored)
        self.assertNotIn("approved", restored["readiness"])



class CIEvidenceAttachmentTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.module = ReleaseEvidenceReportTests.module
        cls.sha = "e" * 40

    def setUp(self):
        self.report = self.module.build_report(self.sha, [], "2026-11-09T00:00:00+00:00")
        self.run = {
            "id": 12345,
            "name": "iOS CI",
            "head_sha": self.sha,
            "status": "completed",
            "conclusion": "success",
            "event": "pull_request",
            "head_repository": {"full_name": "iosdevbyul/TrisMarketLens-iOS"},
            "html_url": "https://github.com/iosdevbyul/TrisMarketLens-iOS/actions/runs/12345",
        }
        names = ["Test read-only API verification script", *self.module.CI_STEPS.values()]
        self.jobs = [{
            "name": "build-and-test",
            "status": "completed",
            "conclusion": "success",
            "steps": [{"name": n, "status": "completed", "conclusion": "success"} for n in names],
        }]

    def test_exact_successful_sha_records_ci_steps_but_never_approves(self):
        report = self.module.attach_ci_evidence(self.report, self.run, self.jobs)
        for gate in self.module.CI_STEPS:
            self.assertEqual(report["automated_gates"][gate]["status"], "passed")
            self.assertIn(self.sha, report["automated_gates"][gate]["evidence"])
        self.assertFalse(report["release_approved"])
        self.assertEqual(report["readiness"], "blocked")
        self.assertTrue(all(x["status"] == "not_verified" for x in report["manual_gates"].values()))

    def test_different_commit_is_rejected(self):
        self.run["head_sha"] = "f" * 40
        with self.assertRaises(ValueError):
            self.module.attach_ci_evidence(self.report, self.run, self.jobs)

    def test_incomplete_or_failed_run_is_rejected(self):
        for field, value in (("status", "in_progress"), ("conclusion", "failure"),
                             ("event", "workflow_dispatch"), ("name", "Other CI")):
            with self.subTest(field=field):
                run = dict(self.run, **{field: value})
                with self.assertRaises(ValueError):
                    self.module.attach_ci_evidence(self.report, run, self.jobs)

    def test_failed_or_missing_ui_step_is_rejected(self):
        for bad in ("failure", "skipped", None):
            with self.subTest(outcome=bad):
                jobs = json.loads(json.dumps(self.jobs))
                step = jobs[0]["steps"][-1]
                if bad is None:
                    jobs[0]["steps"].pop()
                else:
                    step["conclusion"] = bad
                with self.assertRaises(ValueError):
                    self.module.attach_ci_evidence(self.report, self.run, jobs)

    def test_wrong_repository_or_evidence_url_is_rejected(self):
        for field, value in (
            ("head_repository", {"full_name": "untrusted/repo"}),
            ("html_url", "https://example.com/actions/runs/12345"),
        ):
            with self.subTest(field=field):
                with self.assertRaises(ValueError):
                    self.module.attach_ci_evidence(self.report, dict(self.run, **{field: value}), self.jobs)

    def test_missing_or_duplicate_job_evidence_is_rejected(self):
        for jobs in ([], self.jobs * 2):
            with self.assertRaises(ValueError):
                self.module.attach_ci_evidence(self.report, self.run, jobs)
        duplicate = json.loads(json.dumps(self.jobs))
        duplicate[0]["steps"].append(dict(duplicate[0]["steps"][0]))
        with self.assertRaises(ValueError):
            self.module.attach_ci_evidence(self.report, self.run, duplicate)

if __name__ == "__main__":
    unittest.main()
