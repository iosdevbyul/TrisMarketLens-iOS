# Phase 5 — Secure research client launch and Release URL policy

The generated Xcode scheme now starts in `TRIS_DATA_MODE=disconnected` by default, without a hard-coded localhost HTTP API base URL. This avoids presenting a local development endpoint as if it were a configured production source.

The app-level `ResearchEnvironment` restricts **Release** HTTP mode to `https://` base URLs. A plaintext `http://` URL in a Release build is rejected with `insecureReleaseURL` and the app shows its fail-closed invalid-configuration state instead of attempting a request. Debug builds may continue to use plaintext HTTP, including local loopback, for development. The policy applies at application environment construction, not to independently injected mock transport in unit tests.

Debug and Release XCTest verify that insecure remote HTTP and loopback HTTP are rejected in Release, accepted in Debug, and that HTTPS can still configure the research client. The existing XCUITest suite continues checking disconnected and invalid configuration launch states.

This is an **app-configuration guard**, not a certificate of backend TLS, data custody, Apple signing, App Store privacy compliance, KRX authorization, live API access or release approval. Manual signed-device and HTTPS certificate chain checks remain outstanding.
