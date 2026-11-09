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
from manual_release_evidence import attach_manual_submissions

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


def ensure_clean_checkout(root: Path) -> None:
    """Do not attribute uncommitted source or newly created files to HEAD."""
    try:
        output = subprocess.check_output(
            ["git", "-C", str(root), "status", "--porcelain=v1", "--untracked-files=all"],
            text=True,
        )
    except (OSError, subprocess.CalledProcessError) as error:
        raise ValueError("Cannot verify clean release candidate checkout") from error
    if output.strip():
        # Do not print paths: untracked filenames may themselves be sensitive.
        raise ValueError("Release evidence requires a clean Git checkout (commit or remove local changes)")


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


# Exact GitHub Actions step names from the read-only iOS CI workflow.
CI_STEPS = {
    "debug_simulator_build": "Build for iOS Simulator",
    "release_simulator_build": "Build Release configuration for iOS Simulator",
    "swift_unit_tests": "Run unit tests",
    "release_swift_unit_tests": "Run Release unit tests",
    "simulator_ui_tests": "Run application launch UI smoke tests",
}


def attach_ci_evidence(report: dict, run: dict, jobs: list[dict]) -> dict:
    """Attach only exact-commit, completed successful iOS CI job observations.

    Evidence must be captured from GitHub's run and jobs APIs independently.
    Never infer release approval, even when every automated gate is green.
    """
    target = report["commit"]
    if (run.get("head_sha") != target
            or run.get("name") != "iOS CI"
            or run.get("status") != "completed"
            or run.get("conclusion") != "success"
            or run.get("event") not in ("push", "pull_request")
            or not isinstance(run.get("head_repository"), dict)
            or run["head_repository"].get("full_name") != report["repository"]
            or not isinstance(run.get("id"), int)
            or isinstance(run.get("id"), bool)
            or run["id"] < 1):
        raise ValueError("CI run is incomplete, untrusted, failed or for another commit")

    if not isinstance(jobs, list) or len(jobs) != 1:
        raise ValueError("Exactly one successful build-and-test CI job is required")
    job = jobs[0]
    if (job.get("name") != "build-and-test"
            or job.get("status") != "completed"
            or job.get("conclusion") != "success"
            or not isinstance(job.get("steps"), list)):
        raise ValueError("CI job missing, failed or incomplete")
    step_names = [item.get("name") for item in job["steps"] if isinstance(item, dict)]
    if len(step_names) != len(set(step_names)):
        raise ValueError("Duplicate CI step names invalidate evidence")
    steps = {item.get("name"): item for item in job["steps"] if isinstance(item, dict)}
    mandatory = ["Test read-only API verification script", *CI_STEPS.values()]
    for name in mandatory:
        step = steps.get(name)
        if (not step
                or step.get("status") != "completed"
                or step.get("conclusion") != "success"):
            raise ValueError(f"Required CI check not successful: {name}")

    url = run.get("html_url")
    expected = f"https://github.com/{report['repository']}/actions/runs/{run['id']}"
    if url != expected:
        raise ValueError("Unexpected CI evidence URL")
    for gate, step_name in CI_STEPS.items():
        report["automated_gates"][gate] = {
            "status": "passed",
            "evidence": f"{url} (step: {step_name}; SHA: {target})",
        }
    report["ci_evidence"] = {"run_id": run["id"], "head_sha": target, "url": url}
    report["scope"] = "offline_source_audit_and_ci_observations"
    # These fields are never unlocked by CI, regardless of the outcome.
    report["release_approved"] = False
    report["readiness"] = "blocked"
    return report


def load_ci_evidence(path: Path) -> tuple[dict, list[dict]]:
    record = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(record, dict) or not isinstance(record.get("run"), dict):
        raise ValueError("Expected an object with run and jobs fields")
    return record["run"], record.get("jobs")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, help="Write report JSON to a local file")
    parser.add_argument("--ci-evidence", type=Path, help="Offline GitHub Actions run+jobs JSON captured for this exact commit")
    parser.add_argument("--manual-evidence", type=Path, help="Offline SHA-bound manual QA evidence IDs submitted for review")
    args = parser.parse_args()
    try:
        ensure_clean_checkout(ROOT)
    except ValueError as error:
        parser.error(str(error))
    issues = audit(
        (ROOT / "project.yml").read_text(encoding="utf-8"),
        tracked_files(ROOT),
    )
    report = build_report(
        revision(ROOT), issues, datetime.now(timezone.utc).isoformat()
    )
    if args.ci_evidence:
        try:
            run, jobs = load_ci_evidence(args.ci_evidence)
            attach_ci_evidence(report, run, jobs)
        except (OSError, ValueError, TypeError, KeyError) as error:
            parser.error(f"Rejected CI evidence: {error}")
    if args.manual_evidence:
        try:
            submission = json.loads(args.manual_evidence.read_text(encoding="utf-8"))
            attach_manual_submissions(report, submission)
        except (OSError, ValueError, TypeError, KeyError) as error:
            parser.error(f"Rejected manual evidence: {error}")
    payload = json.dumps(report, indent=2, ensure_ascii=False, sort_keys=True) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(payload, encoding="utf-8")
    else:
        print(payload, end="")
    return 1 if issues else 0


if __name__ == "__main__":
    raise SystemExit(main())
