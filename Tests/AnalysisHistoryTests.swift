import XCTest
@testable import TrisMarketLens

final class AnalysisHistoryTests: XCTestCase {
    func testObservedDatesAndCounts() {
        let entries: [ScreenerEntry] = [
            .init(ticker: "001", name: nil, analysisId: "a", modelId: "m", modelVersion: "v1", direction: "up", score: nil, validation: "verified", dataThrough: "2026-10-01", analyzedAt: "2026-10-02T00:00:00Z"),
            .init(ticker: "001", name: nil, analysisId: "b", modelId: "m", modelVersion: "v1", direction: "down", score: nil, validation: "pending", dataThrough: "2026-10-01", analyzedAt: "2026-10-02T01:00:00Z"),
            .init(ticker: "002", name: nil, analysisId: "c", modelId: "m", modelVersion: "v1", direction: "neutral", score: nil, validation: "blocked", dataThrough: "2026-10-03", analyzedAt: "2026-10-03T01:00:00Z")
        ]
        let history = DailyAnalysisSummary.summarize(entries)
        XCTAssertEqual(history.map(\.date), ["2026-10-01", "2026-10-03"])
        XCTAssertEqual(history[0].records, 2)
        XCTAssertEqual(history[0].securities, 1)
        XCTAssertEqual(history[0].up, 1)
        XCTAssertEqual(history[0].down, 1)
        XCTAssertEqual(history[0].latestAnalyzedAt, "2026-10-02T01:00:00Z")
        XCTAssertEqual(history[1].blocked, 1)
    }

    func testDisconnectedHistoryIsEmpty() async throws {
        let snapshot = try await DisconnectedScreenerSource().getScreener()
        XCTAssertTrue(DailyAnalysisSummary.summarize(snapshot.entries).isEmpty)
    }
    func testRangeLimitsObservedDatesWithoutSynthesizingMissingDates() {
        let entries = (1...35).map { index in
            ScreenerEntry(
                ticker: "001", name: nil, analysisId: "a\(index)",
                modelId: "model", modelVersion: "v1", direction: "up",
                score: nil, validation: "verified",
                dataThrough: String(format: "2026-09-%02d", index),
                analyzedAt: "2026-10-01T00:00:00Z"
            )
        }
        let history = DailyAnalysisSummary.summarize(entries)
        XCTAssertEqual(AnalysisHistoryRange.recent7.apply(to: history).count, 7)
        XCTAssertEqual(AnalysisHistoryRange.recent30.apply(to: history).count, 30)
        XCTAssertEqual(AnalysisHistoryRange.all.apply(to: history).count, 35)
        XCTAssertEqual(AnalysisHistoryRange.recent7.apply(to: []).count, 0)
    }

}
