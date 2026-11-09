"""Offline structural verifier for release evidence reports.

This verifies consistency, not origin authenticity, signing or release approval.
"""
import argparse
import json
from pathlib import Path
import re

from release_evidence import AUTOMATED_GATES, MANUAL_GATES, CI_STEPS

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
    if report.get("release_approved") is not False or report.get("readiness") != "blocked":
        problems.append("Report illegally indicates release approval/readiness")
    if not isinstance(report.get("configuration_findings"), list):
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
            seen = set()
            for row in submissions:
                if not isinstance(row, dict) or row.get("gate") not in MANUAL_GATES or row.get("commit") != sha:
                    problems.append("Manual evidence mismatched or unknown gate")
                    continue
                gate = row["gate"]
                if gate in seen:
                    problems.append("Duplicate manual gate evidence")
                seen.add(gate)
                claimed = manual.get(gate)
                if not isinstance(claimed, dict) or claimed.get("evidence") != f"submitted_for_review:{row.get('evidence_id')}":
                    problems.append(f"Manual evidence reference mismatch: {gate}")
    elif "manual_review_state" in report:
        problems.append("Manual review state exists without submitted evidence")
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
