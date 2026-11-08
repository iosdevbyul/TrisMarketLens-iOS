# Phase 5 — Simulator app launch UI smoke checks

An isolated `TrisMarketLensUITests` XCUITest bundle now launches the actual iOS application. `TrisMarketLensUI` is a separate XcodeGen scheme so existing Debug and Release XCTest runs remain unchanged. CI invokes the UI scheme once on the prepared iPhone simulator, with parallel testing disabled.

Current bounded smoke coverage:
1. `TRIS_DATA_MODE=disconnected`: root research dashboard appears without a synthetic/demo-data badge.
2. Unsupported `TRIS_DATA_MODE`: invalid-configuration screen appears and application research UI does not.
3. `TRIS_DATA_MODE=http` without `TRIS_API_BASE_URL`: application fails closed on configuration.

The tests do not call a running FastAPI server, connect to brokerage services, certify raw KRX custody, evaluate model quality, or validate physical iPhone behavior. A green simulator test is evidence of UI launch and basic configuration handling only.

Remaining manual release gates: VoiceOver and Dynamic Type, navigation at compact/regular size, Airplane Mode and latency recovery, real authorized backend access, signing, and device distribution. CI must pass Debug and Release builds, existing XCTest, and new UI tests before merge.
