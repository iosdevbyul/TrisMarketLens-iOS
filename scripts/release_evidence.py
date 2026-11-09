"""Generate a conservative local release evidence report, never an approval.

No live requests are made and a successful script exit does not mean
the iOS application is signed, distributable or connected to approved data.
"""
import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import re
import subprocess

from audit_release_config import audit, tracked_files

ROOT = Path(__file__).resolve().parents[1]
MANUAL_GATES = (
    "approved_krx_source_and_custody",
    "authorized_live_api_and_contracts",
    "physical_iphone_and_ipad_navigation",
    "network_loss_recovery_and_request_cancellation",
    "voiceover_dynamic_type_and_localization",
    "privacy_manifest_and_data_practices_review",
    "apple_signing_and_testflight_distribution",
)
AUTOMATED_GATES = (
    "release_source_configuration",
    "debug_simulator_build",
    "release_simulator_build",
    "swift_unit_tests",
    "release_swift_unit_tests",
    "simulator_ui_tests",
)


def revision(root: Path) -> str:
    return subprocess.check_output(
        ["git", "-C", str(root), "rev-parse", "HEAD"], text=True
    ).strip()


def build_report(commit: str, config_issues: list[str], now: str) -> dict:
    if not re.fullmatch(r"[a-fA-F0-9]{40}", commit):
        raise ValueError("A full Git commit SHA is required")
    gates = {name: {"status": "not_checked", "evidence": None} for name in AUTOMATED_GATES}
    gates["release_source_configuration"] = {
        "status": "passed" if not config_issues else "failed",
        "evidence": "scripts/audit_release_config.py (offline source checks)",
    }
    manual = {name: {"status": "not_verified", "evidence": None} for name in MANUAL_GATES}
    return {
        "schema_version": 1,
        "repository": "iosdevbyul/TrisMarketLens-iOS",
        "commit": commit.lower(),
        "created_at_utc": now,
        "release_approved": False,
        "readiness": "blocked",
        "scope": "offline_source_audit_only",
        "automated_gates": gates,
        "manual_gates": manual,
        "configuration_findings": config_issues,
        "note": (
            "This report does not import CI job results or independently verify "
            "signing, privacy, physical devices, live API or KRX provenance."
        ),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, help="Write report JSON to a local file")
    args = parser.parse_args()
    issues = audit(
        (ROOT / "project.yml").read_text(encoding="utf-8"),
        tracked_files(ROOT),
    )
    report = build_report(
        revision(ROOT), issues, datetime.now(timezone.utc).isoformat()
    )
    payload = json.dumps(report, indent=2, ensure_ascii=False, sort_keys=True) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(payload, encoding="utf-8")
    else:
        print(payload, end="")
    return 1 if issues else 0


if __name__ == "__main__":
    raise SystemExit(main())
