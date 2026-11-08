import Foundation
import XCTest
@testable import TrisMarketLens

final class OperationalMarketTests: XCTestCase {
    private let summary = """
    {"schemaVersion":"operational_snapshot_summary_v1","evidenceStatus":"unreviewed",
    "observationCount":2,"tickerCount":1,"tradingDayCount":2,
    "firstTradingDate":"2026-10-28","lastTradingDate":"2026-10-29"}
    """
    private let page = """
    {"schemaVersion":"operational_market_v1","evidenceStatus":"unreviewed",
    "items":[{"ticker":"005930","latestDataDate":"2026-10-29"}],
    "total":1,"offset":0,"limit":25}
    """

    func testDecodesUnreviewedSnapshotAndStockPage() throws {
        let coverage = try JSONDecoder().decode(OperationalMarketSummary.self, from: Data(summary.utf8))
        try coverage.validate()
        XCTAssertEqual(coverage.observationCount, 2)
        XCTAssertEqual(coverage.evidenceStatus, "unreviewed")
        let catalog = try JSONDecoder().decode(OperationalMarketPage.self, from: Data(page.utf8))
        try catalog.validate(offset: 0)
        XCTAssertEqual(catalog.items.map(\.ticker), ["005930"])
    }

    func testRejectsApprovedOrUnsupportedSummaryAndInvalidCounts() throws {
        for fixture in [
            summary.replacingOccurrences(of: "unreviewed", with: "verified"),
            summary.replacingOccurrences(of: "operational_snapshot_summary_v1", with: "unknown"),
            summary.replacingOccurrences(of: "\"observationCount\":2", with: "\"observationCount\":0"),
            summary.replacingOccurrences(of: "2026-10-29", with: "2026-02-30")
        ] {
            let result = try JSONDecoder().decode(OperationalMarketSummary.self, from: Data(fixture.utf8))
            XCTAssertThrowsError(try result.validate())
        }
    }

    func testRejectsUnsafeCatalogAndOutOfOrderBarEvidence() throws {
        for fixture in [
            page.replacingOccurrences(of: "unreviewed", with: "validated"),
            page.replacingOccurrences(of: "\"offset\":0", with: "\"offset\":25"),
            page.replacingOccurrences(of: "\"ticker\":\"005930\"", with: "\"ticker\":\"../bad\"")
        ] {
            let result = try JSONDecoder().decode(OperationalMarketPage.self, from: Data(fixture.utf8))
            XCTAssertThrowsError(try result.validate(offset: 0))
        }
        let bar = OhlcvBar(date: "2026-10-29", open: 100, high: 110, low: 90, close: 105, volume: 100)
        try OperationalMarketContract.validateBars(OhlcvSeries(ticker: "005930", bars: [bar]), ticker: "005930")
        XCTAssertThrowsError(try OperationalMarketContract.validateBars(
            OhlcvSeries(ticker: "005930", bars: [bar, bar]), ticker: "005930"
        ))
        XCTAssertThrowsError(try OperationalMarketContract.validateBars(
            OhlcvSeries(ticker: "000660", bars: [bar]), ticker: "005930"
        ))
        XCTAssertThrowsError(try OperationalMarketContract.validateBars(
            OhlcvSeries(ticker: "005930", bars: [OhlcvBar(date: bar.date, open: 100, high: 90, low: 80, close: 105, volume: 1)]),
            ticker: "005930"
        ))
    }

    func testInvalidQueriesFailWithoutSendingRequests() async throws {
        let api = try ResearchAPIClient(baseURL: URL(string: "https://example.test")!)
        let source = HTTPOperationalMarketSource(client: api)
        do {
            _ = try await source.getStocks(offset: -1)
            XCTFail("Negative offset must be rejected")
        } catch ResearchAPIError.invalidConfiguration {}
        do {
            _ = try await source.getBars(ticker: "../bad")
            XCTFail("Unsafe ticker must be rejected")
        } catch ResearchAPIError.invalidConfiguration {}
    }

    func testDisconnectedSourceDoesNotInventOperationalObservations() async throws {
        let source = UnavailableOperationalMarketSource()
        do {
            _ = try await source.getSummary()
            XCTFail("Missing source must fail closed")
        } catch ResearchAPIError.invalidConfiguration {}
    }
}
