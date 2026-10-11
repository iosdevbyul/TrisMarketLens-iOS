import XCTest
@testable import TrisMarketLens

final class StockChartDisplayModeTests: XCTestCase {
    func testShortSeriesUsesOHLCVCandles() {
        XCTAssertEqual(StockChartDisplayMode.mode(sessionCount: 0), .candles)
        XCTAssertEqual(StockChartDisplayMode.mode(sessionCount: 22), .candles)
        XCTAssertEqual(StockChartDisplayMode.mode(sessionCount: 120), .candles)
    }

    func testLongSeriesUsesClosingLine() {
        XCTAssertEqual(StockChartDisplayMode.mode(sessionCount: 121), .closingLine)
        XCTAssertEqual(StockChartDisplayMode.mode(sessionCount: 252), .closingLine)
        XCTAssertEqual(StockChartDisplayMode.mode(sessionCount: 2500), .closingLine)
    }
}
