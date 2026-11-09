# Research API request-path safety

The iOS research client treats `fetch` and restricted `post` path entries as individual logical identifier segments, not as URL syntax.

Both request methods reject empty segments, `.` / `..`, slash and backslash separators, raw percent encoding, query/fragment separators, whitespace, and control characters before dispatching a network request. Query parameters must instead be passed via the explicit `queryItems` argument on GET.

The check protects URL construction against accidental path rewriting and reserved-character injection. It does not change existing backend endpoints, supply authentication, authorize live publication, or approve a release. Offline XCTest cases cover GET and POST rejection; GitHub CI remains the validation gate.
