"""Offline contract tests for the read-only live API smoke checker."""
import importlib.util
import copy
import sys
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

    def test_ohlcv_rejects_invalid_calendar_dates(self):
        base = {"date": "2026-10-12", "open": 100, "high": 105,
                "low": 95, "close": 102, "volume": 200}
        invalid = ("2026-02-29", "2026-04-31", "2026-13-01",
                   "2026-00-01", "2026-1-01", "20261012",
                   "2026-10-12T00:00:00Z", " 2026-10-12", "", None, 20261012)
        for date_value in invalid:
            with self.subTest(date=date_value):
                payload = {"ticker": "005930", "bars": [dict(base, date=date_value)]}
                self.assertIsNotNone(checker.validate_ohlcv(payload, "005930"))

    def test_ohlcv_accepts_leap_day_and_does_not_assume_sort_order(self):
        base = {"open": 100, "high": 105, "low": 95, "close": 102, "volume": 200}
        payload = {"ticker": "005930", "bars": [
            dict(base, date="2024-02-29"),
            dict(base, date="2024-02-28"),
        ]}
        self.assertIsNone(checker.validate_ohlcv(payload, "005930"))

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
        ReleaseEvidenceReportTests.setUpClass()
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


class ManualEvidenceSubmissionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        ReleaseEvidenceReportTests.setUpClass()
        cls.module = ReleaseEvidenceReportTests.module
        cls.sha = "a" * 40

    def setUp(self):
        self.report = self.module.build_report(
            self.sha, [], "2026-11-09T00:00:00+00:00"
        )
        self.submission = {
            "commit": self.sha,
            "entries": [{
                "gate": "physical_iphone_and_ipad_navigation",
                "evidence_id": "QA-iphone-001",
                "commit": self.sha,
                "observed_at_utc": "2026-11-09T03:00:00Z",
                "outcome": "pass",
            }],
        }

    def attach(self, entries=None):
        if entries is not None:
            self.submission["entries"] = entries
        return self.module.attach_manual_submissions(
            self.report, self.submission
        )

    def test_submitted_pass_remains_unverified_and_blocked(self):
        report = self.attach()
        gate = report["manual_gates"]["physical_iphone_and_ipad_navigation"]
        self.assertEqual(gate["status"], "not_verified")
        self.assertEqual(gate["evidence"], "submitted_for_review:QA-iphone-001")
        self.assertEqual(report["manual_review_state"], "pending_independent_review")
        self.assertFalse(report["release_approved"])
        self.assertEqual(report["readiness"], "blocked")
        self.assertEqual(report["manual_evidence_submissions"][0]["outcome"], "pass")

    def test_submitted_fail_and_blocked_cannot_approve(self):
        for outcome in ("fail", "blocked"):
            with self.subTest(outcome=outcome):
                entry = dict(self.submission["entries"][0], outcome=outcome)
                report = self.attach([entry])
                self.assertFalse(report["release_approved"])
                self.assertEqual(report["manual_gates"][entry["gate"]]["status"], "not_verified")

    def test_commit_mismatch_rejected_at_both_levels(self):
        wrong = "b" * 40
        self.submission["commit"] = wrong
        with self.assertRaises(ValueError):
            self.attach()
        self.submission["commit"] = self.sha
        self.submission["entries"][0]["commit"] = wrong
        with self.assertRaises(ValueError):
            self.attach()

    def test_unknown_gate_and_private_url_rejected(self):
        for field, bad in (
            ("gate", "all_release_checks"),
            ("evidence_id", "https://private.example/evidence"),
            ("evidence_id", "x"),
            ("outcome", "approved"),
        ):
            with self.subTest(field=field):
                entry = dict(self.submission["entries"][0], **{field: bad})
                with self.assertRaises(ValueError):
                    self.attach([entry])

    def test_extra_fields_and_duplicate_claims_rejected(self):
        entry = self.submission["entries"][0]
        for bad in (
            [dict(entry, token="secret")],
            [entry, dict(entry, evidence_id="QA-iphone-002")],
            [entry, dict(entry, gate="network_loss_recovery_and_request_cancellation")],
        ):
            with self.assertRaises(ValueError):
                self.attach(bad)

    def test_timestamp_requires_explicit_utc(self):
        for timestamp in ("2026-11-09T03:00:00+09:00", "yesterday", ""):
            with self.subTest(timestamp=timestamp):
                entry = dict(self.submission["entries"][0], observed_at_utc=timestamp)
                with self.assertRaises(ValueError):
                    self.attach([entry])

    def test_missing_entries_rejected_and_report_not_modified(self):
        for bad in ([], "no", None):
            with self.assertRaises(ValueError):
                self.attach(bad)
        self.assertNotIn("manual_evidence_submissions", self.report)
        self.assertTrue(all(v["status"] == "not_verified" for v in self.report["manual_gates"].values()))



class ReleaseReportIntegrityTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        import sys
        script_dir = Path(__file__).resolve().parents[1] / "scripts"
        sys.path.insert(0, str(script_dir))
        try:
            spec = importlib.util.spec_from_file_location(
                "verify_release_report", script_dir / "verify_release_report.py"
            )
            cls.verifier = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(cls.verifier)
        finally:
            sys.path.remove(str(script_dir))
        ReleaseEvidenceReportTests.setUpClass()
        cls.builder = ReleaseEvidenceReportTests.module

    def setUp(self):
        self.sha = "f" * 40
        self.report = self.builder.build_report(
            self.sha, [], "2026-11-09T00:00:00+00:00"
        )

    def test_unverified_candidate_structure_is_consistent(self):
        self.assertEqual(self.verifier.check(self.report, self.sha), [])

    def test_approval_or_verified_manual_gate_is_rejected(self):
        self.report["release_approved"] = True
        self.assertTrue(self.verifier.check(self.report))
        self.report["release_approved"] = False
        self.report["manual_gates"]["apple_signing_and_testflight_distribution"]["status"] = "verified"
        self.assertTrue(self.verifier.check(self.report))

    def test_missing_ci_cannot_claim_pass(self):
        self.report["automated_gates"]["simulator_ui_tests"]["status"] = "passed"
        self.assertTrue(self.verifier.check(self.report))

    def test_candidate_commit_repository_and_schema_are_bound(self):
        self.assertTrue(self.verifier.check(self.report, "e" * 40))
        self.report["repository"] = "untrusted/repository"
        self.assertTrue(self.verifier.check(self.report))
        self.report["repository"] = "iosdevbyul/TrisMarketLens-iOS"
        self.report["schema_version"] = 2
        self.assertTrue(self.verifier.check(self.report))

    def test_source_audit_failure_cannot_be_marked_pass(self):
        self.report["configuration_findings"] = ["tracked signing secret"]
        self.assertTrue(self.verifier.check(self.report))

    def test_ci_run_and_named_steps_must_match(self):
        url = "https://github.com/iosdevbyul/TrisMarketLens-iOS/actions/runs/123"
        self.report["ci_evidence"] = {"run_id": 123, "head_sha": self.sha, "url": url}
        self.report["scope"] = "offline_source_audit_and_ci_observations"
        for gate, name in self.builder.CI_STEPS.items():
            self.report["automated_gates"][gate] = {
                "status": "passed",
                "evidence": f"{url} (step: {name}; SHA: {self.sha})",
            }
        self.assertEqual(self.verifier.check(self.report), [])
        self.report["ci_evidence"]["head_sha"] = "e" * 40
        self.assertTrue(self.verifier.check(self.report))

    def test_manual_submission_remains_review_pending_and_bound(self):
        entry = {
            "gate": "physical_iphone_and_ipad_navigation",
            "evidence_id": "QA-device-001",
            "commit": self.sha,
            "observed_at_utc": "2026-11-09T03:00:00Z",
            "outcome": "pass",
        }
        self.report["manual_evidence_submissions"] = [entry]
        self.report["manual_review_state"] = "pending_independent_review"
        self.report["manual_gates"][entry["gate"]]["evidence"] = "submitted_for_review:QA-device-001"
        self.assertEqual(self.verifier.check(self.report), [])
        self.report["manual_gates"][entry["gate"]]["evidence"] = "approved"
        self.assertTrue(self.verifier.check(self.report))

    def test_invalid_or_incomplete_report_is_rejected(self):
        self.assertTrue(self.verifier.check({}))
        self.assertTrue(self.verifier.check([]))
        del self.report["manual_gates"]["approved_krx_source_and_custody"]
        self.assertTrue(self.verifier.check(self.report))



class GithubCIEvidenceCollectorTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        import sys
        script_dir = Path(__file__).resolve().parents[1] / "scripts"
        sys.path.insert(0, str(script_dir))
        try:
            spec = importlib.util.spec_from_file_location(
                "collect_ci_evidence", script_dir / "collect_ci_evidence.py"
            )
            cls.collector = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(cls.collector)
        finally:
            sys.path.remove(str(script_dir))
        ReleaseEvidenceReportTests.setUpClass()
        cls.evidence = ReleaseEvidenceReportTests.module

    def setUp(self):
        self.sha = "a" * 40
        self.run = {
            "id": 123,
            "name": "iOS CI",
            "head_sha": self.sha,
            "status": "completed",
            "conclusion": "success",
            "event": "pull_request",
            "head_repository": {"full_name": "iosdevbyul/TrisMarketLens-iOS"},
            "html_url": "https://github.com/iosdevbyul/TrisMarketLens-iOS/actions/runs/123",
            "sensitive_extra": "do-not-export",
        }
        names = ["Test read-only API verification script", *self.evidence.CI_STEPS.values()]
        self.jobs = [{
            "name": "build-and-test", "status": "completed", "conclusion": "success",
            "steps": [
                {"name": name, "status": "completed", "conclusion": "success"}
                for name in names
            ],
            "sensitive_extra": "do-not-export",
        }]

    def fetch(self, endpoint):
        if endpoint.endswith("/jobs?per_page=100"):
            return {"total_count": 1, "jobs": self.jobs}
        return self.run

    def test_collects_exact_success_and_removes_unnecessary_api_fields(self):
        output = self.collector.collect(123, self.sha, fetch=self.fetch)
        self.assertEqual(output["run"]["head_sha"], self.sha)
        self.assertEqual(output["jobs"][0]["steps"][-1]["conclusion"], "success")
        self.assertNotIn("sensitive_extra", json.dumps(output))
        report = self.evidence.build_report(self.sha, [], "2026-11-09T00:00:00+00:00")
        self.evidence.attach_ci_evidence(report, output["run"], output["jobs"])
        self.assertFalse(report["release_approved"])

    def test_rejects_wrong_commit_before_writing_evidence(self):
        self.run["head_sha"] = "b" * 40
        with self.assertRaises(ValueError):
            self.collector.collect(123, self.sha, fetch=self.fetch)

    def test_rejects_failed_job_or_missing_step(self):
        for change in ("failed", "missing"):
            with self.subTest(change=change):
                jobs = json.loads(json.dumps(self.jobs))
                if change == "failed":
                    jobs[0]["conclusion"] = "failure"
                else:
                    jobs[0]["steps"].pop()
                def fetch(endpoint):
                    return {"total_count": 1, "jobs": jobs} if endpoint.endswith("/jobs?per_page=100") else self.run
                with self.assertRaises(ValueError):
                    self.collector.collect(123, self.sha, fetch=fetch)

    def test_rejects_incomplete_or_paginated_jobs(self):
        for count in (0, 2, None, True):
            with self.subTest(total=count):
                def fetch(endpoint):
                    return {"total_count": count, "jobs": self.jobs} if endpoint.endswith("/jobs?per_page=100") else self.run
                with self.assertRaises(ValueError):
                    self.collector.collect(123, self.sha, fetch=fetch)

    def test_rejects_invalid_run_identity(self):
        for run_id, sha in ((0, self.sha), (True, self.sha), (123, "abc"), (123, "G" * 40)):
            with self.subTest(run_id=run_id, sha=sha):
                with self.assertRaises(ValueError):
                    self.collector.collect(run_id, sha, fetch=self.fetch)

    def test_rejects_mismatched_or_invalid_fetched_run_id(self):
        for invalid in (124, True, "123", None):
            with self.subTest(returned_id=invalid):
                run = dict(self.run, id=invalid)
                def fetch(endpoint):
                    if endpoint.endswith("/jobs?per_page=100"):
                        return {"total_count": 1, "jobs": self.jobs}
                    return run
                with self.assertRaises(ValueError):
                    self.collector.collect(123, self.sha, fetch=fetch)

    def test_mismatched_run_id_rejected_before_jobs_fetch(self):
        endpoints = []
        def fetch(endpoint):
            endpoints.append(endpoint)
            return dict(self.run, id=124)
        with self.assertRaises(ValueError):
            self.collector.collect(123, self.sha, fetch=fetch)
        self.assertEqual(endpoints, [
            "repos/iosdevbyul/TrisMarketLens-iOS/actions/runs/123"
        ])

    def test_uses_fixed_repository_and_get_only_endpoints(self):
        endpoints = []
        def fetch(endpoint):
            endpoints.append(endpoint)
            return self.fetch(endpoint)
        self.collector.collect(123, self.sha, fetch=fetch)
        self.assertEqual(endpoints, [
            "repos/iosdevbyul/TrisMarketLens-iOS/actions/runs/123",
            "repos/iosdevbyul/TrisMarketLens-iOS/actions/runs/123/jobs?per_page=100",
        ])



class CleanReleaseCheckoutTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        ReleaseEvidenceReportTests.setUpClass()
        cls.module = ReleaseEvidenceReportTests.module

    def test_clean_checkout_is_accepted(self):
        with patch.object(self.module.subprocess, "check_output", return_value=""):
            self.module.ensure_clean_checkout(Path("/tmp/source"))

    def test_modified_staged_and_untracked_files_are_rejected_without_path_leak(self):
        for git_status in (
            " M project.yml\n",
            "M  TrisMarketLens/Data/ResearchEnvironment.swift\n",
            "?? private-token-file.txt\n",
            " D docs/release-readiness.md\n",
            "R  docs/old.md -> docs/new.md\n",
        ):
            with self.subTest(status=git_status):
                with patch.object(self.module.subprocess, "check_output", return_value=git_status):
                    with self.assertRaises(ValueError) as caught:
                        self.module.ensure_clean_checkout(Path("/tmp/source"))
                    self.assertNotIn("private-token-file", str(caught.exception))
                    self.assertIn("clean Git checkout", str(caught.exception))

    def test_git_status_failure_cannot_be_assumed_clean(self):
        with patch.object(
            self.module.subprocess, "check_output", side_effect=OSError("git unavailable")
        ):
            with self.assertRaises(ValueError):
                self.module.ensure_clean_checkout(Path("/tmp/source"))

    def test_git_command_checks_all_untracked_files_without_mutation(self):
        with patch.object(self.module.subprocess, "check_output", return_value="") as call:
            self.module.ensure_clean_checkout(Path("/tmp/source"))
        args, kwargs = call.call_args
        self.assertEqual(args[0], [
            "git", "-C", "/tmp/source", "status", "--porcelain=v1", "--untracked-files=all"
        ])
        self.assertEqual(kwargs["text"], True)


sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
from release_evidence import build_report
from manual_release_evidence import attach_manual_submissions
from verify_release_report import check

class ReleaseReportHardeningTests(unittest.TestCase):
    def setUp(self):
        self.sha = "a" * 40
        self.report = build_report(self.sha, [], "2026-11-09T00:00:00+00:00")
        self.entry = {
            "gate": "physical_iphone_and_ipad_navigation",
            "evidence_id": "QA-iphone-001",
            "commit": self.sha,
            "observed_at_utc": "2026-11-09T03:00:00Z",
            "outcome": "pass",
        }

    def with_manual(self):
        attach_manual_submissions(self.report, {
            "commit": self.sha, "entries": [self.entry],
        })

    def test_valid_offline_and_manual_reports(self):
        self.assertEqual(check(self.report, self.sha), [])
        self.with_manual()
        self.assertEqual(check(self.report, self.sha), [])

    def test_rejects_wrong_scope_and_creation_time(self):
        for scope in ("bogus", "offline_source_audit_and_ci_observations", None):
            with self.subTest(scope=scope):
                report = copy.deepcopy(self.report)
                report["scope"] = scope
                self.assertTrue(check(report, self.sha))
        for value in ("yesterday", "2026-11-09T09:00:00+09:00", None):
            with self.subTest(value=value):
                report = copy.deepcopy(self.report)
                report["created_at_utc"] = value
                self.assertTrue(check(report, self.sha))

    def test_rejects_invalid_source_findings(self):
        for findings in (["valid", 123], [None], "not a list"):
            with self.subTest(findings=findings):
                report = copy.deepcopy(self.report)
                report["configuration_findings"] = findings
                self.assertTrue(check(report, self.sha))

    def test_rejects_tampered_manual_fields(self):
        self.with_manual()
        for field, value in (
            ("evidence_id", "https://private.example/token"),
            ("evidence_id", ["invalid"]),
            ("observed_at_utc", "not UTC"),
            ("outcome", "approved"),
            ("outcome", ["pass"]),
            ("gate", ["physical_iphone_and_ipad_navigation"]),
        ):
            with self.subTest(field=field, value=value):
                report = copy.deepcopy(self.report)
                report["manual_evidence_submissions"][0][field] = value
                self.assertTrue(check(report, self.sha))

    def test_rejects_duplicate_evidence_id_and_extra_fields(self):
        self.with_manual()
        duplicate = dict(self.entry, gate="network_loss_recovery_and_request_cancellation")
        report = copy.deepcopy(self.report)
        report["manual_evidence_submissions"].append(duplicate)
        report["manual_gates"][duplicate["gate"]]["evidence"] = "submitted_for_review:QA-iphone-001"
        self.assertTrue(check(report, self.sha))
        report = copy.deepcopy(self.report)
        report["manual_evidence_submissions"][0]["secret"] = "do-not-include"
        self.assertTrue(check(report, self.sha))

    def test_rejects_orphaned_manual_evidence_reference(self):
        self.report["manual_gates"][self.entry["gate"]]["evidence"] = "submitted_for_review:QA-iphone-001"
        self.assertTrue(check(self.report, self.sha))
        self.with_manual()
        report = copy.deepcopy(self.report)
        report["manual_gates"]["apple_signing_and_testflight_distribution"]["evidence"] = "submitted_for_review:QA-other-001"
        self.assertTrue(check(report, self.sha))


if __name__ == "__main__":
    unittest.main()
