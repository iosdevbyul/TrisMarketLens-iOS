import XCTest
@testable import TrisMarketLens

final class StockPriceAxisTests: XCTestCase {
    func testPriceAxisIsNotAnchoredToZero() throws {
        let bars = [OhlcvBar(date: "2026-10-01", open: 266500, high: 276000, low: 264500, close: 276000, volume: 13741073)]
        let domain = try XCTUnwrap(StockPriceAxis.domain(for: bars))
        XCTAssertGreaterThan(domain.lowerBound, 0)
        XCTAssertLessThan(domain.lowerBound, 264500)
        XCTAssertGreaterThan(domain.upperBound, 276000)
    }

    func testNoTradeZeroValuesDoNotCompressValidPrices() throws {
        let bars = [OhlcvBar(date: "2026-10-01", open: 0, high: 0, low: 0, close: 150, volume: 0)]
        let domain = try XCTUnwrap(StockPriceAxis.domain(for: bars))
        XCTAssertGreaterThan(domain.lowerBound, 0)
        XCTAssertTrue(domain.contains(150))
    }

    func testEmptyOrAllZeroSeriesHaveNoRange() {
        XCTAssertNil(StockPriceAxis.domain(for: []))
        let bar = OhlcvBar(date: "2026-10-01", open: 0, high: 0, low: 0, close: 0, volume: 0)
        XCTAssertNil(StockPriceAxis.domain(for: [bar]))
    }
}
