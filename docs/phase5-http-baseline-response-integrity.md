# Native baseline backtest response integrity

The read-only iOS baseline adapter now validates the structure of a decoded baseline snapshot before exposing it to SwiftUI.

Validation requires nonblank baseline identity/title, bounds readiness/timeline/policy groups/fingerprints to 100 entries each, bounds rules within each policy group to 100, and rejects duplicate or blank labels in each independent collection. Policy-group titles must also be unique.

Legitimate empty collections remain empty. HTTP 404 continues to mean no published baseline, while an incompatible 200 response is an error, not synthetic evidence.

These checks do not validate any historical performance claim, independently authenticate a source, establish real KRX permissions or approve prospective execution. Device and live API verification remain manual release gates.
