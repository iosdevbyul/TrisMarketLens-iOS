import XCTest
@testable import TrisMarketLens

final class StockTests: XCTestCase {
    func testStockSearchUsesTickerNameAndSector() {
        let stock = StockSummary(ticker: "000001", name: "Example Alpha", market: "KOSPI", sector: "Demo sector")
        XCTAssertTrue(stock.matches("000001"))
        XCTAssertTrue(stock.matches("alpha"))
        XCTAssertTrue(stock.matches("sector"))
        XCTAssertTrue(stock.matches("  "))
        XCTAssertFalse(stock.matches("unknown"))
    }

    func testNullMetadataFallsBackWithoutInventingCompanyName() throws {
        let json = """
        {"ticker":"000002","name":null,"market":"KOSPI","sector":null}
        """
        let stock = try JSONDecoder().decode(StockSummary.self, from: Data(json.utf8))
        XCTAssertEqual(stock.displayName, "000002")
        XCTAssertEqual(stock.sectorLabel, "Sector unavailable")
    }

    func testMockStockDetailIsExplicitlySynthetic() async throws {
        let source = MockStockSource()
        let items = try await source.getStocks()
        XCTAssertEqual(items.count, 3)
        let fetched = try await source.getStock(ticker: "000001")
        let detail = try XCTUnwrap(fetched)
        XCTAssertEqual(detail.dataStatus, "mock")
        XCTAssertEqual(detail.latestDataDate, "Unavailable")
        let missing = try await source.getStock(ticker: "999999")
        XCTAssertNil(missing)
    }

}
