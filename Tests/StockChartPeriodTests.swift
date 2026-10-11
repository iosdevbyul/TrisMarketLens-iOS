import XCTest
@testable import TrisMarketLens

final class StockChartPeriodTests: XCTestCase {
    func testSessionWindowLengths() {
        let bars = (0..<300).map { index in
            OhlcvBar(date: String(format: "%04d", index), open: 1, high: 2, low: 1, close: 2, volume: index)
        }
        XCTAssertEqual(StockChartPeriod.month.filter(bars).count, 22)
        XCTAssertEqual(StockChartPeriod.quarter.filter(bars).count, 66)
        XCTAssertEqual(StockChartPeriod.year.filter(bars).count, 252)
        XCTAssertEqual(StockChartPeriod.all.filter(bars).count, 300)
        XCTAssertEqual(StockChartPeriod.month.filter(bars).first?.volume, 278)
        XCTAssertEqual(StockChartPeriod.all.filter(bars).first?.volume, 0)
    }

    func testShortAndEmptySeriesArePreserved() {
        let bars = [OhlcvBar(date: "2026-10-01", open: 1, high: 2, low: 1, close: 2, volume: 4)]
        for period in StockChartPeriod.allCases {
            XCTAssertEqual(period.filter(bars).count, 1)
            XCTAssertTrue(period.filter([]).isEmpty)
        }
    }
}
