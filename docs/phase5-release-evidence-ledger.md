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
