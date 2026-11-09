# Native project-status response integrity

The iOS HTTP project-status source rejects malformed status payloads rather than presenting them as verified research.

- Require nonblank project and source labels. A reachable endpoint is not independently authenticated market data.
- Bound each metrics, evidence, and baseline collection to 100 entries.
- Require nonblank metric labels and values, and reject repeated metric labels.
- Reject blank or duplicated checkpoint labels within each evidence or baseline collection; the two sections remain independent.
- Preserve empty sections as empty, without inventing baseline results, source evidence or fallback demo values.

This protects read-only display integrity. It does not confirm KRX access, issuer authority, live publications, device QA or release approval.
