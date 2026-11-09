# Phase 5 — Release candidate evidence ledger

A green CI run means that automated checks passed for a specific commit. It is **not** permission to distribute research data or proof that a model is live, licensed, scientifically validated or suitable for trading.

## Prepare a candidate locally

From a checked-out candidate commit:

```bash
python3 scripts/audit_release_config.py
python3 scripts/release_evidence.py --output /tmp/trismarketlens-release-evidence.json
```

The report records the **40-character git SHA**, UTC creation time, offline source audit findings, CI gates as `not_checked` (unless independently populated by an authorized verifier), and outstanding manual gates as `not_verified`. Release approval is always `false`; readiness is `blocked`. A script success exit merely indicates that this local configuration audit did not find a known source-level issue.

Use the GitHub Actions commit-specific run URL separately to verify simulator builds, Swift unit tests, XCUITest, and offline Python tests. **Do not** replace `not_checked` in this automatically generated report by assuming that the latest green result belongs to the recorded SHA.

## Optional exact-commit GitHub Actions evidence import

To attach verified automated gate observations without inventing a release approval, capture the GitHub Actions **workflow-run JSON and jobs JSON** for the exact commit. The combined local input must have the form:

```json
{
  "run": {
    "id": 12345,
    "name": "iOS CI",
    "head_sha": "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
    "status": "completed",
    "conclusion": "success",
    "event": "pull_request",
    "head_repository": {"full_name": "iosdevbyul/TrisMarketLens-iOS"},
    "html_url": "https://github.com/iosdevbyul/TrisMarketLens-iOS/actions/runs/12345"
  },
  "jobs": [{
    "name": "build-and-test",
    "status": "completed",
    "conclusion": "success",
    "steps": [
      {"name": "Test read-only API verification script", "status": "completed", "conclusion": "success"},
      {"name": "Build for iOS Simulator", "status": "completed", "conclusion": "success"},
      {"name": "Build Release configuration for iOS Simulator", "status": "completed", "conclusion": "success"},
      {"name": "Run unit tests", "status": "completed", "conclusion": "success"},
      {"name": "Run Release unit tests", "status": "completed", "conclusion": "success"},
      {"name": "Run application launch UI smoke tests", "status": "completed", "conclusion": "success"}
    ]
  }]
}
```

The example is illustrative, **not a real run**. Use an actual full SHA and matching run ID. A reviewer can retrieve run details with `gh api repos/iosdevbyul/TrisMarketLens-iOS/actions/runs/RUN_ID` and job details with `gh api repos/iosdevbyul/TrisMarketLens-iOS/actions/runs/RUN_ID/jobs` and combine the `run` object with the API response's `jobs` array into one local JSON file. The script validates the exact commit, repository, run identity, successful job, and each required successful named step before marking automated CI gates as passed.

```bash
python3 scripts/release_evidence.py --ci-evidence /tmp/trismarketlens-ci-run.json --output /tmp/trismarketlens-release-evidence.json
```

An unmatched, incomplete, failed, skipped, duplicate, or wrong-repository run is rejected. Locally supplied API JSON is evidence input, not independently authenticated; reviewers must validate the original GitHub Actions URL themselves. This does not approve a release, verify live API, or change any manual gate status.

## Manual QA submissions (review pending only)

A QA operator may submit **opaque, non-sensitive evidence IDs** scoped to the candidate's exact full commit SHA. These are review requests, not independent confirmations or approvals. Example local JSON (illustrative only):

```json
{
  "commit": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "entries": [
    {
      "gate": "physical_iphone_and_ipad_navigation",
      "evidence_id": "QA-device-001",
      "commit": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
      "observed_at_utc": "2026-11-09T03:00:00Z",
      "outcome": "pass"
    }
  ]
}
```

After collecting the actual evidence outside the repository:

```bash
python3 scripts/release_evidence.py \
  --manual-evidence /tmp/trismarketlens-manual-qa.json \
  --output /tmp/trismarketlens-release-evidence.json
```

You can also pass `--ci-evidence` alongside `--manual-evidence`. Inputs must contain only recognized gate names, safe evidence IDs (letters, numbers, dots, dashes and underscores), outcomes `pass`/`fail`/`blocked`, a UTC timestamp and matching full commit SHA. Duplicated gates/IDs, unknown fields, private URLs, embedded tokens and mismatched commits are rejected.

A submitted `pass` does **not** change a gate's `not_verified` status; its evidence field is only `submitted_for_review:<ID>`. `release_approved` remains `false` and readiness remains `blocked`. A separate authorized reviewer must examine the underlying evidence through a secure channel; this tool has no approval mechanism. Never include device identifiers, raw private endpoints, API keys, unpublished research artifacts, or personal data in the report.

## Manual sign-off evidence (not automated)

| Gate | Evidence the reviewer must collect |
| --- | --- |
| Approved KRX source and custody | Source owner/permission, immutable raw material identity, SHA-256 and data lineage |
| Live API and contracts | Reviewed HTTPS endpoint identity, GET-only routes, valid/invalid payloads, 404/503 evidence |
| Physical device | iPhone and iPad navigation, rotation, recovery, connection path and device OS/build |
| Network failures | Loss, timeout, cancellation, repeated refresh and ticker-switch behavior |
| Accessibility/localization | VoiceOver reading order, accessibility text sizes, English/Korean and contrast |
| Privacy/data practices | First- and third-party SDK privacy review, applicable privacy manifests and App Store declarations |
| Signing/distribution | Apple team, bundle identifier, provisioning, signed archive and TestFlight installation |

Keep the evidence outside the repository when it contains private endpoints, credentials, personal data or unpublished research sources. Reference only safe, redacted evidence IDs and reviewed commit hashes in the release checklist.

**Do not distribute an externally facing build until every required gate has independent, reviewed evidence.** No script here attests to device signing, an authorized source, KRX custody, App Store privacy compliance or production readiness.
