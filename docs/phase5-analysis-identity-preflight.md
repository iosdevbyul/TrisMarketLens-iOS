# Read-only analysis identity preflight

`scripts/verify_research_api.py` checks the requested stock ticker against the analysis response ticker and each returned record.
Every record must contain a nonblank ID and required string metadata; duplicate IDs, missing score fields, nonfinite or nonnumeric non-null scores, and malformed explanation values fail as `INCOMPATIBLE`.
Empty `records` is valid and means no published analysis was returned; it must not be presented as an actual prediction.

These are structural checks only. They do not establish model quality, original observations, approved KRX provenance, publication chronology, or permission to distribute.
Live backend and device QA remain independent manual gates.
