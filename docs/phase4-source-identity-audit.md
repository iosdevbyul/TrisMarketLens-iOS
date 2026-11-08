# Phase 4 — Published source identity audit

The native Research Path links to a read-only inspection of versioned model and Evidence publication details. The screen uses the existing ResearchCatalogSource to load index and detail records independently.

For each evidence layer, it requires the detail's id, title, sourceLabel, state and summary to match the index. For models it verifies published summary fields and that artifactSha256 is 64 lowercase hex characters. Evidence fingerprints, when supplied, must also have valid SHA-256 syntax. Missing detail, absent fingerprints, mismatched metadata, and malformed hashes remain unavailable/inconsistent rather than successful.

**Important:** A syntactically valid published hash is NOT cryptographic source verification performed by the iOS app. Neither the raw KRX captured bytes nor signed custodian approval is provided to this client, and the separate operational-market API does not expose its underlying snapshot pin. Accordingly no cross-source hash equality, research snapshot lineage, PIT/OOS status, brokerage execution eligibility or live return is inferred. Published identifiers cannot be treated as operator authorization.

The screen retains missing source or per-record fetch errors and never substitutes demo payloads in HTTP mode. It does not download archives or access active operational storage. There are no write operations, new API routes or paid services.

Unit tests cover observed published hashes, malformed or absent fingerprints, mismatched list/detail identities, missing model detail and model SHA requirements. CI Debug/Release simulator builds and XCTest must pass before merge; real KRX source custody and physical iPhone testing remain separate gates.
