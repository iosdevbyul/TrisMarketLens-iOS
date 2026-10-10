import XCTest
@testable import TrisMarketLens

final class StockResearchTests: XCTestCase {
    func testDisconnectedResearchDoesNotManufactureMarketData() async throws {
        let source = DisconnectedStockResearchSource()
        let ohlcv = try await source.getOhlcv(ticker: "000001")
        let analysis = try await source.getAnalysis(ticker: "000001")
        let evaluation = try await source.getEvaluations(ticker: "000001")
        XCTAssertTrue(ohlcv.bars.isEmpty)
        XCTAssertTrue(analysis.records.isEmpty)
        XCTAssertTrue(evaluation.evaluations.isEmpty)
    }

    func testOHLCVDecodesWebResponseShape() throws {
        let data = Data(#"{"ticker":"000001","bars":[{"date":"2025-06-30","open":100,"high":105,"low":98,"close":102,"volume":1000}]}"#.utf8)
        let decoded = try JSONDecoder().decode(OhlcvSeries.self, from: data)
        XCTAssertEqual(decoded.bars.first?.close, 102)
    }

    func testAnalysisDecodesNullableScore() throws {
        let data = Data(#"{"ticker":"000001","records":[{"id":"x","ticker":"000001","analyzedAt":"2026-10-01T00:00:00Z","dataThrough":"2026-10-01","modelId":"demo","modelVersion":"v1","direction":"neutral","score":null,"validation":"pending","explanation":null}]}"#.utf8)
        let decoded = try JSONDecoder().decode(StockAnalysisSnapshot.self, from: data)
        XCTAssertNil(decoded.records.first?.score)
    }
}
