import XCTest
@testable import TrisMarketLens

final class StockChartCandleWidthTests: XCTestCase {
    func testOneMonthUsesNormalBodyWidth() {
        XCTAssertEqual(StockChartCandleWidth.bodyWidth(for: 22), 6)
    }

    func testThreeMonthsUseNarrowBodyWidth() {
        XCTAssertEqual(StockChartCandleWidth.bodyWidth(for: 66), 3)
    }

    func testDenseThreshold() {
        XCTAssertEqual(StockChartCandleWidth.bodyWidth(for: 40), 6)
        XCTAssertEqual(StockChartCandleWidth.bodyWidth(for: 41), 3)
    }
}
