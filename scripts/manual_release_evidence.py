"""Validate local manual QA evidence references; never self-approve a release.

Accepts only safe evidence IDs and SHA-scoped metadata, not private URLs,
credentials, device identifiers, raw KRX data or personal information.
"""
from datetime import datetime, timezone
import re

GATE_ID = re.compile(r"^[a-z][a-z0-9_]{2,79}$")
EVIDENCE_ID = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_.-]{3,79}$")
COMMIT = re.compile(r"^[a-f0-9]{40}$")
EXPECTED_FIELDS = {"gate", "evidence_id", "commit", "observed_at_utc", "outcome"}
OUTCOMES = {"pass", "fail", "blocked"}


def _utc_timestamp(value: str) -> datetime:
    if not isinstance(value, str) or not value.endswith("Z"):
        raise ValueError("Evidence timestamp must be an explicit UTC Z timestamp")
    try:
        parsed = datetime.fromisoformat(value[:-1] + "+00:00")
    except ValueError as error:
        raise ValueError("Invalid UTC timestamp") from error
    if parsed.utcoffset() != timezone.utc.utcoffset(parsed):
        raise ValueError("Evidence timestamp must be UTC")
    return parsed


def attach_manual_submissions(report: dict, submission: dict) -> dict:
    """Record claims for independent review without marking any gate verified."""
    if not isinstance(submission, dict) or set(submission) != {"commit", "entries"}:
        raise ValueError("Expected only commit and entries")
    target = report.get("commit")
    if not isinstance(target, str) or not COMMIT.fullmatch(target):
        raise ValueError("Report commit must be a full lowercase SHA")
    if submission["commit"] != target:
        raise ValueError("Manual QA evidence must match the exact report commit")
    entries = submission.get("entries")
    if not isinstance(entries, list) or not entries:
        raise ValueError("Manual QA entries must be a nonempty list")
    seen_gates = set()
    seen_ids = set()
    sanitized = []
    for entry in entries:
        if not isinstance(entry, dict) or set(entry) != EXPECTED_FIELDS:
            raise ValueError("Unexpected manual QA evidence fields")
        gate = entry["gate"]
        eid = entry["evidence_id"]
        if not isinstance(gate, str) or gate not in report["manual_gates"] or not GATE_ID.fullmatch(gate):
            raise ValueError("Unknown manual release gate")
        if not isinstance(eid, str) or not EVIDENCE_ID.fullmatch(eid):
            raise ValueError("Evidence ID must be an opaque safe identifier (no URLs or secrets)")
        if entry["commit"] != target:
            raise ValueError("Individual evidence must match the report commit")
        if entry["outcome"] not in OUTCOMES:
            raise ValueError("Unknown QA outcome")
        _utc_timestamp(entry["observed_at_utc"])
        if gate in seen_gates or eid in seen_ids:
            raise ValueError("Duplicate gate or evidence ID")
        seen_gates.add(gate)
        seen_ids.add(eid)
        sanitized.append(dict(entry))

    report["manual_evidence_submissions"] = sanitized
    for entry in sanitized:
        # All manual statuses are intentionally left UNVERIFIED. Evidence is merely
        # submitted for independent human review, including when outcome='pass'.
        report["manual_gates"][entry["gate"]]["evidence"] = (
            f"submitted_for_review:{entry['evidence_id']}"
        )
    report["manual_review_state"] = "pending_independent_review"
    report["release_approved"] = False
    report["readiness"] = "blocked"
    return report
