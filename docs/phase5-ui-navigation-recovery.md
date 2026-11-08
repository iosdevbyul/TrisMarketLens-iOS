# Phase 5 — UI navigation and retry smoke coverage

The real iPhone Simulator XCUITest suite expands beyond cold-launch configuration checks.

Additional bounded scenarios:
- A disconnected Overview exposes a manual **Retry request** action; tapping it does not manufacture successful research or silently switch to mock data.
- Explicit Debug mock mode visibly labels its records as mock research, rather than presenting them as live publications.
- From the disconnected Overview, the test enters the native NavigationSplitView sidebar (including compact-width back navigation) and opens AI Screener. The screen must say the research API is not connected and must not show a demo-data badge as evidence.

Stable accessibility identifiers for sidebar sections use `navigation.<AppSection.rawValue>` rather than screen coordinates, so the tests avoid fixed-layout tap positions.

All cases run on the existing iPhone Simulator UI smoke scheme, without an external backend, actual investment signals, or writes. They do **not** prove network latency recovery, authentic KRX custody, UI behavior on physical iPhone or all VoiceOver rotor paths. Those remain manual QA and external release gates.
