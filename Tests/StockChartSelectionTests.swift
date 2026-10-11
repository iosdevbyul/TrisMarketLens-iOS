import XCTest
@testable import TrisMarketLens

final class StockChartSelectionTests: XCTestCase {
    private let bars = [
        OhlcvBar(date: "2026-10-07", open: 10, high: 12, low: 9, close: 11, volume: 100),
        OhlcvBar(date: "2026-10-08", open: 11, high: 13, low: 10, close: 12, volume: 200)
    ]

    func testSelectedVisibleSession() {
        let bar = StockChartSelection.bar(for: "2026-10-08", in: bars)
        XCTAssertEqual(bar?.close, 12)
        XCTAssertEqual(bar?.volume, 200)
    }

    func testNoSelectionAndOutOfRangeSelection() {
        XCTAssertNil(StockChartSelection.bar(for: nil, in: bars))
        XCTAssertNil(StockChartSelection.bar(for: "2026-10-06", in: bars))
        XCTAssertNil(StockChartSelection.bar(for: "2026-10-08", in: []))
    }
}
