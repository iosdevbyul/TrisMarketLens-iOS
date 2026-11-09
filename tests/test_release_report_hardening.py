"""Regression tests for strict offline release-report verification."""
import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
from release_evidence import build_report, attach_ci_evidence
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
