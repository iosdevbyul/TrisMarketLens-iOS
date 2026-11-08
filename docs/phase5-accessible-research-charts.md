# Phase 5 — Accessible research charts

The stock OHLCV, volume, and daily analysis activity charts now provide explicit VoiceOver summaries derived exclusively from the currently displayed, backend-supplied observations.

The chart descriptions announce actual start/end dates, record counts and price bounds (only where present). Individual history dates announce direction and review counts without implying that skipped days are zero. Missing/empty data receive dedicated descriptions rather than synthetic series.

Both stock chart panes and the history chart use SwiftUI ScaledMetric heights. The history and price-period pickers use an accessible menu instead of a segmented control that can clip when Dynamic Type is large. Existing per-bar details, date selection and explanatory source disclaimers remain available as visible text. VoiceOver descriptions are *not* a replacement for the selected-session readout.

## Verification gates

- XCTest fixtures cover empty data, known recorded sessions, gaps in research dates and actual counts, without fabricating additional sessions.
- CI must validate Debug/Release iOS Simulator builds and XCTest.
- VoiceOver rotor navigation, Switch Control, Dynamic Type at accessibility sizes, chart gestures and physical-device contrast are **manual QA still required**. No hardware UI test has been performed by this PR.

Charts display only research publications and do not certify raw KRX custody, forecast performance, or trading permission.
