# Phase 5 — Large Text, rotation and disconnected research UI smoke

Extends the existing simulator XCUITest suite with three bounded real-app UI scenarios:

1. Launch with accessibility-size Dynamic Type (using the standard `UIPreferredContentSizeCategoryName` launch preference) in disconnected mode. The dashboard must retain its source indicator, failure guidance and explicit Retry action, without replacing research results with mock values.
2. Launch with invalid configuration, rotate to landscape, and verify the invalid-configuration gate still displays and no research dashboard appears.
3. Navigate to Stocks in disconnected mode from the compact iPhone sidebar. The UI must show an explicit error and Retry rather than a synthetic investment universe.

The tests restore portrait orientation afterward, use existing stable sidebar accessibility identifiers, avoid paid or external endpoints and do not fabricate market observations. CI runs the existing UI smoke scheme alongside Debug/Release builds and unit tests.

**Still manual:** VoiceOver spoken reading order and rotor navigation, real physical iPhone/iPad rotation, contrast at maximum text sizes, authenticated/approved source API testing, signing and TestFlight distribution. Simulator presence assertions do not certify complete accessibility compliance.
