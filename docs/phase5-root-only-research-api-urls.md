# Root-only research API URL configuration

The iOS research HTTP client accepts only an `http(s)://host[:port]` base URL with an empty or single-slash root path. The existing `api/v1/...` request paths are appended by the client; specifying a base URL ending in `/api` or `/api/v1` can duplicate route prefixes and produce misleading 404 responses.

Both client initializers reject embedded credentials, query parameters, fragments, and non-root base paths. The environment wrapper fails configuration instead of falling back to mock research data. Release builds separately require HTTPS; Debug loopback policy remains unchanged.

This is an offline configuration guard, not a successful connection to the backend, authorized source verification, device QA or release approval.
