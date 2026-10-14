import XCTest
@testable import TrisMarketLens

final class StockValueFormatterTests: XCTestCase {
    func testPriceKeepsUsefulFractionalPrecision() {
        XCTAssertEqual(StockValueFormatter.price(1200), 1200.formatted(.number.grouping(.automatic).precision(.fractionLength(0...2))))
        XCTAssertEqual(StockValueFormatter.price(1200.5), 1200.5.formatted(.number.grouping(.automatic).precision(.fractionLength(0...2))))
    }

    func testVolumesSupportDailyAndAggregatedCounts() {
        XCTAssertEqual(StockValueFormatter.volume(1000), 1000.formatted(.number.grouping(.automatic)))
        XCTAssertEqual(StockValueFormatter.volume(Int64(3_000_000_000)), Int64(3_000_000_000).formatted(.number.grouping(.automatic)))
    }

    func testPercentageSignAndFixedPrecision() {
        XCTAssertTrue(StockValueFormatter.changePercent(2.5).hasPrefix("+"))
        XCTAssertTrue(StockValueFormatter.changePercent(-2.5).hasPrefix("-"))
        XCTAssertFalse(StockValueFormatter.changePercent(0).hasPrefix("+"))
        XCTAssertTrue(StockValueFormatter.changePercent(2.5).hasSuffix("%"))
    }
}
