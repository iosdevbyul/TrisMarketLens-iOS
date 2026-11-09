"""Offline structural verifier for release evidence reports.

This verifies consistency, not origin authenticity, signing or release approval.
"""
import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import re

from release_evidence import AUTOMATED_GATES, MANUAL_GATES, CI_STEPS
from manual_release_evidence import EVIDENCE_ID, EXPECTED_FIELDS, OUTCOMES, _utc_timestamp

SHA = re.compile(r"^[a-f0-9]{40}$")
CI_PREFIX = "https://github.com/iosdevbyul/TrisMarketLens-iOS/actions/runs/"


def check(report: dict, expected_sha: str | None = None) -> list[str]:
    problems = []
    if not isinstance(report, dict):
        return ["Report must be a JSON object"]
    sha = report.get("commit")
    if not isinstance(sha, str) or not SHA.fullmatch(sha):
        return ["Report commit is not a full lowercase SHA"]
    if expected_sha is not None and sha != expected_sha:
        problems.append("Report SHA differs from expected candidate")
    if report.get("repository") != "iosdevbyul/TrisMarketLens-iOS":
        problems.append("Repository identity mismatch")
    if report.get("schema_version") != 1:
        problems.append("Unsupported report schema")
    created = report.get("created_at_utc")
    try:
        if not isinstance(created, str):
            raise ValueError("Missing UTC timestamp")
        parsed = datetime.fromisoformat(created.replace("Z", "+00:00"))
        if parsed.utcoffset() != timezone.utc.utcoffset(parsed):
            raise ValueError("Not UTC")
    except ValueError:
        problems.append("Invalid report UTC creation time")
    expected_scope = ("offline_source_audit_and_ci_observations"
                      if report.get("ci_evidence") is not None else "offline_source_audit_only")
    if report.get("scope") != expected_scope:
        problems.append("Report scope conflicts with CI evidence")
    if report.get("release_approved") is not False or report.get("readiness") != "blocked":
        problems.append("Report illegally indicates release approval/readiness")
    if (not isinstance(report.get("configuration_findings"), list)
            or any(not isinstance(item, str) for item in report["configuration_findings"])):
        problems.append("Configuration audit findings missing")
    automated = report.get("automated_gates")
    if not isinstance(automated, dict) or set(automated) != set(AUTOMATED_GATES):
        problems.append("Missing or unexpected automated gates")
        automated = {}
    manual = report.get("manual_gates")
    if not isinstance(manual, dict) or set(manual) != set(MANUAL_GATES):
        problems.append("Missing or unexpected manual gates")
        manual = {}
    for gate in MANUAL_GATES:
        row = manual.get(gate)
        if not isinstance(row, dict) or row.get("status") != "not_verified":
            problems.append(f"Manual gate must remain unverified: {gate}")

    findings = report.get("configuration_findings")
    config = automated.get("release_source_configuration")
    expected_config = "passed" if findings == [] else "failed"
    if not isinstance(config, dict) or config.get("status") != expected_config:
        problems.append("Source configuration status conflicts with findings")
    ci = report.get("ci_evidence")
    if ci is None:
        for gate in CI_STEPS:
            row = automated.get(gate)
            if not isinstance(row, dict) or row.get("status") != "not_checked" or row.get("evidence") is not None:
                problems.append(f"CI gate falsely marked checked without evidence: {gate}")
    else:
        if (not isinstance(ci, dict)
                or not isinstance(ci.get("run_id"), int)
                or isinstance(ci.get("run_id"), bool)
                or ci.get("run_id", 0) <= 0
                or ci.get("head_sha") != sha
                or ci.get("url") != f"{CI_PREFIX}{ci.get('run_id')}"):
            problems.append("CI evidence does not identify the exact run and SHA")
        for gate, step in CI_STEPS.items():
            row = automated.get(gate)
            if (not isinstance(row, dict)
                    or row.get("status") != "passed"
                    or row.get("evidence") != f"{ci.get('url') if isinstance(ci, dict) else ''} (step: {step}; SHA: {sha})"):
                problems.append(f"CI gate inconsistent with recorded run: {gate}")

    submissions = report.get("manual_evidence_submissions")
    if submissions is not None:
        if not isinstance(submissions, list) or not submissions:
            problems.append("Manual evidence submissions must be nonempty")
        elif report.get("manual_review_state") != "pending_independent_review":
            problems.append("Manual evidence has no pending review state")
        else:
            seen_gates = set()
            seen_ids = set()
            for row in submissions:
                if (not isinstance(row, dict)
                        or set(row) != EXPECTED_FIELDS
                        or row.get("gate") not in MANUAL_GATES
                        or row.get("commit") != sha):
                    problems.append("Manual evidence mismatched or unknown gate")
                    continue
                gate = row["gate"]
                eid = row["evidence_id"]
                if not isinstance(eid, str) or not EVIDENCE_ID.fullmatch(eid):
                    problems.append("Invalid manual evidence ID")
                if row["outcome"] not in OUTCOMES:
                    problems.append("Invalid manual QA outcome")
                try:
                    _utc_timestamp(row["observed_at_utc"])
                except ValueError:
                    problems.append("Invalid manual evidence UTC timestamp")
                if gate in seen_gates or eid in seen_ids:
                    problems.append("Duplicate manual gate or evidence ID")
                seen_gates.add(gate)
                seen_ids.add(eid)
                claimed = manual.get(gate)
                if not isinstance(claimed, dict) or claimed.get("evidence") != f"submitted_for_review:{eid}":
                    problems.append(f"Manual evidence reference mismatch: {gate}")
            for gate in MANUAL_GATES:
                if (gate not in seen_gates and isinstance(manual.get(gate), dict)
                        and manual[gate].get("evidence") is not None):
                    problems.append(f"Unsubmitted manual evidence reference: {gate}")
    else:
        if "manual_review_state" in report:
            problems.append("Manual review state exists without submitted evidence")
        for gate in MANUAL_GATES:
            if isinstance(manual.get(gate), dict) and manual[gate].get("evidence") is not None:
                problems.append(f"Manual evidence without submission: {gate}")
    return problems


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("report", type=Path)
    parser.add_argument("--expected-sha", help="Exact 40-character candidate SHA")
    args = parser.parse_args()
    if args.expected_sha is not None and not SHA.fullmatch(args.expected_sha):
        parser.error("--expected-sha requires full lowercase commit SHA")
    try:
        report = json.loads(args.report.read_text(encoding="utf-8"))
    except (OSError, ValueError) as error:
        parser.error(f"Cannot read report: {error}")
    issues = check(report, expected_sha=args.expected_sha)
    for issue in issues:
        print("RELEASE REPORT INTEGRITY:", issue)
    if issues:
        return 1
    print("RELEASE REPORT INTEGRITY: structural checks passed; independent approval remains required")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
