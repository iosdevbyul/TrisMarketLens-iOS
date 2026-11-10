# Sharing the iOS research API diagnostic summary

Operations > API connectivity and endpoint diagnostics provides **Share API diagnostic summary** after an actual connectivity check. Sharing opens the iOS system share sheet and does not upload anything by itself.

## Report contents

- Deterministic v1 text representation of the connection result and the existing required-route preflight assessment.
- Number of routes checked/responding and an ordered list of required unavailable endpoints.
- Known, allowlisted API route templates and their read-only response states.
- Explicit unresolved conditions: independently authorized KRX origin/custody, real device verification, signing, and live collection/trading permission.

## Deliberate omissions

The export does not include the configured server host or base URL, raw response bodies, endpoint diagnostic detail strings, credentials, locally stored tokens, or fabricated run timestamps. Unknown route paths are replaced with `[unrecognized route]`. A green endpoint check never means approved market research publication or release readiness.

Results describe a snapshot of the most recently completed in-app diagnostics; a recipient should not treat them as independent proof of source identity or successful live-data collection. When diagnostics have not run, the summary explicitly says `Not checked`.

Offline XCTest coverage tests deterministic output, known failure states, omitted private text, and non-promotion of API reachability to approval. Actual device-share-sheet behavior remains a manual QA task.
