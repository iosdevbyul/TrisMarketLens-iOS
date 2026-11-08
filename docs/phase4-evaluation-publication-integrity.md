# Phase 4 — Prediction evaluation publication integrity

This change protects the existing optional iOS evaluation presentation from showing a published verdict or return with no structural link to an original research record. The current backend read-only app explicitly publishes analyses but does **not** currently provide an approved evaluation route; an unavailable/404 evaluation service remains unavailable, and no synthetic outcome is produced.

The client accepts a pending evaluation for display only when exactly one original record matches both analysis ID and ticker, the record's UTC chronology is structurally consistent, the reference date equals the original data-through date, and the horizon/policy fields are valid. A pending item must not carry a result/date/return.

A non-pending reported outcome is only **structurally linked** when it also has an evaluation date after the reference date, valid positive finite reference/evaluation prices, finite reported return, and an evaluation timestamp on or after the evaluation date. The client does not recompute fees, validate market calendar sessions, certify a policy or verify original price receipts. Therefore even structurally linked reported results remain **unverified**, not live investment performance.

Mismatched, orphaned, ambiguous, stale or inconsistent items are withheld from lists and details, with explicit counts/alerts. When the analysis endpoint fails, no evaluation can appear as linked. Original read-only source publications are not mutated.

Tests use synthetic records and cover missing identities, duplicate analyses, invalid horizons, future-date links, missing prices, pending returns, invalid chronology and unmatched records. This change introduces no paid services, broker execution, API write surface or KRX collection. Real operator-approved source custody, evaluation publishing and physical iPhone testing remain separate release gates.
