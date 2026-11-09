"""Collect GitHub Actions run evidence using an authenticated local gh CLI.

No credentials, private source data or tokens are written to the output.
The collector does not approve release readiness or validate original KRX data.
"""
import argparse
import json
from pathlib import Path
import re
import subprocess

from release_evidence import attach_ci_evidence, build_report

REPOSITORY = "iosdevbyul/TrisMarketLens-iOS"
FULL_SHA = re.compile(r"^[a-f0-9]{40}$")


def github_json(endpoint: str) -> dict:
    command = ["gh", "api", "--method", "GET", endpoint]
    try:
        result = subprocess.run(
            command, check=True, capture_output=True, text=True, timeout=30,
        )
    except (OSError, subprocess.CalledProcessError, subprocess.TimeoutExpired) as error:
        raise ValueError("GitHub CLI request failed; check gh auth and network access") from error
    try:
        value = json.loads(result.stdout)
    except json.JSONDecodeError as error:
        raise ValueError("GitHub CLI returned invalid JSON") from error
    if not isinstance(value, dict):
        raise ValueError("GitHub CLI response must be an object")
    return value


def collect(run_id: int, sha: str, fetch=github_json) -> dict:
    if not isinstance(run_id, int) or isinstance(run_id, bool) or run_id <= 0:
        raise ValueError("Run ID must be a positive integer")
    if not isinstance(sha, str) or not FULL_SHA.fullmatch(sha):
        raise ValueError("Candidate must be an exact 40-character lowercase commit SHA")

    base = f"repos/{REPOSITORY}/actions/runs/{run_id}"
    run = fetch(base)
    jobs_response = fetch(base + "/jobs?per_page=100")
    if not isinstance(jobs_response, dict):
        raise ValueError("Invalid jobs response")
    jobs = jobs_response.get("jobs")
    total = jobs_response.get("total_count")
    if not isinstance(total, int) or isinstance(total, bool) or total != 1:
        raise ValueError("Expected exactly one CI job; paginated/incomplete results rejected")
    report = build_report(sha, [], "1970-01-01T00:00:00+00:00")
    attach_ci_evidence(report, run, jobs)
    # Output only the essential fields required by the release evidence importer.
    # Never write complete GitHub API objects, which may contain extra metadata.
    allowed_run = ("id", "name", "head_sha", "status", "conclusion",
                   "event", "head_repository", "html_url")
    sanitized_run = {key: run[key] for key in allowed_run}
    sanitized_run["head_repository"] = {"full_name": REPOSITORY}
    sanitized_jobs = [{
        "name": job["name"],
        "status": job["status"],
        "conclusion": job["conclusion"],
        "steps": [
            {"name": step["name"], "status": step["status"], "conclusion": step["conclusion"]}
            for step in job["steps"] if isinstance(step, dict)
        ],
    } for job in jobs]
    return {"run": sanitized_run, "jobs": sanitized_jobs}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run-id", type=int, required=True)
    parser.add_argument("--sha", required=True, help="Exact 40-character candidate commit SHA")
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    try:
        data = collect(args.run_id, args.sha)
    except (ValueError, KeyError, TypeError) as error:
        parser.error(str(error))
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"Captured verified CI observations for {args.sha}; release remains unapproved")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
