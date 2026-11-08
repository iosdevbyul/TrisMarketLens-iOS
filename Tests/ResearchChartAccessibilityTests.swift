import Foundation
import XCTest
@testable import TrisMarketLens

final class ResearchChartAccessibilityTests: XCTestCase {
    func testNoFakeDatesOrPricesAreAnnouncedForEmptySource() {
        XCTAssertEqual(ResearchChartAccessibility.history([]), "No published research activity dates.")
        XCTAssertEqual(ResearchChartAccessibility.prices([]), "No published price observations.")
        XCTAssertEqual(ResearchChartAccessibility.volume([]), "No published volume observations.")
    }

    func testPublishedHistoryIsReadAsCountsAndObservedDates() {
        let entries: [ScreenerEntry] = [
            .init(ticker: "005930", name: nil, analysisId: "a", modelId: "m", modelVersion: "v1",
                  direction: "up", score: nil, validation: "pending",
                  dataThrough: "2026-10-01", analyzedAt: "2026-10-02T01:00:00Z"),
            .init(ticker: "005930", name: nil, analysisId: "b", modelId: "m", modelVersion: "v1",
                  direction: "down", score: nil, validation: "blocked",
                  dataThrough: "2026-10-01", analyzedAt: "2026-10-02T02:00:00Z"),
            .init(ticker: "000660", name: nil, analysisId: "c", modelId: "m", modelVersion: "v1",
                  direction: "neutral", score: nil, validation: "verified",
                  dataThrough: "2026-10-03", analyzedAt: "2026-10-04T00:00:00Z")
        ]
        let history = DailyAnalysisSummary.summarize(entries)
        let summary = ResearchChartAccessibility.history(history)
        XCTAssertTrue(summary.contains("2 observed research dates"))
        XCTAssertTrue(summary.contains("3 published analyses"))
        XCTAssertTrue(summary.contains("Missing calendar dates"))
        let day = ResearchChartAccessibility.day(history[0])
        XCTAssertTrue(day.contains("2 published analyses across 1 securities"))
        XCTAssertTrue(day.contains("1 pending"))
        XCTAssertTrue(day.contains("1 blocked"))
    }

    func testPriceAndVolumeDescriptionsUseOnlySuppliedSessions() {
        let bars: [OhlcvBar] = [
            .init(date: "2026-10-01", open: 90, high: 105, low: 85, close: 100, volume: 1200),
            .init(date: "2026-10-03", open: 100, high: 115, low: 95, close: 110, volume: 1400)
        ]
        let prices = ResearchChartAccessibility.prices(bars)
        XCTAssertTrue(prices.contains("2 published daily price observations"))
        XCTAssertTrue(prices.contains("First close 100.0, last close 110.0"))
        XCTAssertTrue(prices.contains("does not certify source provenance"))
        let volume = ResearchChartAccessibility.volume(bars)
        XCTAssertTrue(volume.contains("2026-10-01 through 2026-10-03"))
        XCTAssertFalse(volume.contains("2026-10-02"))
    }
}
