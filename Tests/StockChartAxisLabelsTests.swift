import XCTest
@testable import TrisMarketLens

final class StockChartAxisLabelsTests: XCTestCase {
    func testLabelsIncludeYearForLongPeriods() {
        XCTAssertEqual(StockChartAxisLabels.label(for: "2022-01-03", period: .all), "2022")
        XCTAssertEqual(StockChartAxisLabels.label(for: "2026-10-01", period: .all), "2026")
        XCTAssertEqual(StockChartAxisLabels.label(for: "2025-09-17", period: .year), "25-09")
        XCTAssertEqual(StockChartAxisLabels.label(for: "2026-10-01", period: .quarter), "10-01")
        XCTAssertEqual(StockChartAxisLabels.label(for: "invalid", period: .all), "invalid")
    }

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

    func testFourDateLabelsForEachMainPeriod() {
        for count in [22, 66, 252, 1160] {
            let dates = (0..<count).map { String(format: "2026-%04d", $0) }
            let labels = StockChartAxisLabels.dates(for: dates, maxLabels: 4)
            XCTAssertEqual(labels.count, 4)
            XCTAssertEqual(labels.first, dates.first)
            XCTAssertEqual(labels.last, dates.last)
        }
    }

    func testZeroAndSingleLabelLimits() {
        XCTAssertEqual(StockChartAxisLabels.dates(for: ["a", "b"], maxLabels: 0), [])
        XCTAssertEqual(StockChartAxisLabels.dates(for: ["a", "b"], maxLabels: 1), ["a"])
    }
}
