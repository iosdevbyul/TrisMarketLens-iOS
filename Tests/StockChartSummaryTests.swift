import XCTest
@testable import TrisMarketLens

final class StockChartSummaryTests: XCTestCase {
    func testSummaryUsesOnlyProvidedSessions() {
        let bars = [
            OhlcvBar(date: "2026-10-07", open: 100, high: 115, low: 95, close: 110, volume: 10),
            OhlcvBar(date: "2026-10-08", open: 110, high: 120, low: 108, close: 115, volume: 20),
            OhlcvBar(date: "2026-10-09", open: 115, high: 116, low: 101, close: 105, volume: 30)
        ]
        let summary = StockChartSummary(bars: bars)
        XCTAssertEqual(summary?.firstDate, "2026-10-07")
        XCTAssertEqual(summary?.lastDate, "2026-10-09")
        XCTAssertEqual(summary?.highest, 120)
        XCTAssertEqual(summary?.lowest, 95)
        XCTAssertEqual(summary?.totalVolume, 60)
        XCTAssertEqual(summary?.changePercent ?? 0, 5, accuracy: 0.0001)
    }

    func testEmptySeriesIsNotSummarized() {
        XCTAssertNil(StockChartSummary(bars: []))
    }

    func testZeroReferencePriceDoesNotInventPerformance() {
        let bars = [OhlcvBar(date: "2026-10-07", open: 0, high: 10, low: 0, close: 8, volume: 0)]
        XCTAssertNil(StockChartSummary(bars: bars)?.changePercent)
    }
}
