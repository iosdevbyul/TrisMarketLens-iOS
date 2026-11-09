# Native research catalog HTTP integrity

Models and evidence are read-only research artifacts. The native client must not render structurally malformed remote records as supported research.

## Runtime validation

- Model lists reject duplicated/empty IDs, blank model names, nonfinite or out-of-range validation/out-of-sample average precision, and payloads with more than 5,000 models.
- Model detail responses must match the requested model ID; summary precision values and selection mean must be finite in the range 0–1, and selection deviation finite and nonnegative.
- Evidence lists reject duplicate/blank IDs, blank titles and payloads over 5,000 items.
- Evidence detail responses require exact requested ID, nonblank title, at most 200 metrics and 1,000 findings, and unique nonblank metric labels.
- Empty model and evidence lists are valid and remain empty. HTTP 404 detail still means a missing detail; 503 and malformed responses remain failures.

These are limited structural checks rather than proof that a model is scientifically valid, its observations are independently authenticated, or a live KRX feed is authorized. Existing offline/disconnected and release restrictions remain unchanged.
