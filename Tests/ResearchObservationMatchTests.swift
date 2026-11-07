import Foundation
import XCTest
@testable import TrisMarketLens

final class ResearchObservationMatchTests: XCTestCase {
    private let entry = ScreenerEntry(
        ticker: "005930", name: "Example", analysisId: "analysis-1",
        modelId: "model-A", modelVersion: "v2", direction: "up",
        score: 0.7, validation: "pending", dataThrough: "2026-11-01",
        analyzedAt: "2026-11-02T02:00:00Z"
    )

    private func record(
        id: String = "analysis-1", ticker: String = "005930",
        version: String = "v2", validation: String = "pending"
    ) -> StockAnalysisRecord {
        StockAnalysisRecord(
            id: id, ticker: ticker, analyzedAt: "2026-11-02T02:00:00Z",
            dataThrough: "2026-11-01", modelId: "model-A",
            modelVersion: version, direction: "up", score: 0.7,
            validation: validation, explanation: "Observed source record"
        )
    }

    func testExactPublishedRecordMatches() {
        let snapshot = StockAnalysisSnapshot(ticker: "005930", records: [record()])
        XCTAssertEqual(ResearchObservationMatch.resolve(entry, in: snapshot)?.id, "analysis-1")
    }

    func testNoFallbackToDifferentAnalysisOrTicker() {
        XCTAssertNil(ResearchObservationMatch.resolve(entry, in: .init(ticker: "005930", records: [record(id: "other")])))
        XCTAssertNil(ResearchObservationMatch.resolve(entry, in: .init(ticker: "000660", records: [record()])))
        XCTAssertNil(ResearchObservationMatch.resolve(entry, in: .init(ticker: "005930", records: [record(ticker: "000660")])))
    }

    func testChangedModelOrValidationRejectsStaleIndex() {
        XCTAssertNil(ResearchObservationMatch.resolve(entry, in: .init(ticker: "005930", records: [record(version: "v3")])))
        XCTAssertNil(ResearchObservationMatch.resolve(entry, in: .init(ticker: "005930", records: [record(validation: "verified")])))
    }

    func testDuplicateOrMissingPublicationCannotBeDisplayed() {
        XCTAssertNil(ResearchObservationMatch.resolve(entry, in: .init(ticker: "005930", records: [])))
        XCTAssertNil(ResearchObservationMatch.resolve(entry, in: .init(ticker: "005930", records: [record(), record()])))
    }
}
