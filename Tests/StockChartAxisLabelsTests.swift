import XCTest
@testable import TrisMarketLens

final class StockChartAxisLabelsTests: XCTestCase {
    func testEmptyAndSingleSession() {
        XCTAssertEqual(StockChartAxisLabels.dates(for: []), [])
        XCTAssertEqual(StockChartAxisLabels.dates(for: ["2026-10-01"]), ["2026-10-01"])
    }

    func testShortPeriodsRetainDates() {
        let dates = ["2026-09-28", "2026-09-29", "2026-10-01"]
        XCTAssertEqual(StockChartAxisLabels.dates(for: dates), dates)
    }

    func testSixtySixSessionsUseOnlyFiveVisibleTicks() {
        let dates = (0..<66).map { String(format: "session-%02d", $0) }
        let labels = StockChartAxisLabels.dates(for: dates)
        XCTAssertEqual(labels.count, 5)
        XCTAssertEqual(labels.first, dates.first)
        XCTAssertEqual(labels.last, dates.last)
        XCTAssertEqual(labels, ["session-00", "session-16", "session-32", "session-48", "session-65"])
    }

    func testZeroAndSingleLabelLimits() {
        XCTAssertEqual(StockChartAxisLabels.dates(for: ["a", "b"], maxLabels: 0), [])
        XCTAssertEqual(StockChartAxisLabels.dates(for: ["a", "b"], maxLabels: 1), ["a"])
    }
}
