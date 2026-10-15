import XCTest
@testable import TrisMarketLens

final class StockOHLCVTests: XCTestCase {
    func testDecodesOriginalSessionValuesWithoutAdjustment() throws {
        let json = """
        {"ticker":"005930","bars":[{"date":"2025-06-30","open":0,"high":0,"low":0,"close":58000,"volume":0}]}
        """
        let result = try JSONDecoder().decode(OhlcvSeries.self, from: Data(json.utf8))
        XCTAssertEqual(result.ticker, "005930")
        XCTAssertEqual(result.bars.first?.open, 0)
        XCTAssertEqual(result.bars.first?.close, 58000)
        XCTAssertEqual(result.bars.first?.volume, 0)
    }

    func testDemoDoesNotFabricateHistoricalBars() async throws {
        XCTAssertNil(try await MockStockSource().getOHLCV(ticker: "000001"))
    }
}
