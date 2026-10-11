import XCTest
@testable import TrisMarketLens

final class StockAnalysisOrderingTests: XCTestCase {
    func testNewestFirstWithStableIdentityTieBreak() {
        let snapshot = StockAnalysisSnapshot(ticker: "005930", records: [
            makeRecord(id: "z", analyzedAt: "2026-10-10T00:00:00Z"),
            makeRecord(id: "b", analyzedAt: "2026-10-11T00:00:00Z"),
            makeRecord(id: "a", analyzedAt: "2026-10-11T00:00:00Z")
        ])
        XCTAssertEqual(snapshot.newestFirst.map(\.id), ["a", "b", "z"])
    }

    func testEmptyRecordsRemainEmpty() {
        XCTAssertTrue(StockAnalysisSnapshot(ticker: "005930", records: []).newestFirst.isEmpty)
    }

    private func makeRecord(id: String, analyzedAt: String) -> StockAnalysisRecord {
        StockAnalysisRecord(
            id: id, ticker: "005930", analyzedAt: analyzedAt,
            dataThrough: "2026-10-10", modelId: "model",
            modelVersion: "1", direction: "neutral", score: nil,
            validation: "pending", explanation: nil
        )
    }
}
