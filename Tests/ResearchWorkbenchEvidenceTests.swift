import Foundation
import XCTest
@testable import TrisMarketLens

final class ResearchWorkbenchEvidenceTests: XCTestCase {
    private let entry = ScreenerEntry(
        ticker: "005930", name: nil, analysisId: "a-1", modelId: "model",
        modelVersion: "v1", direction: "up", score: nil,
        validation: "pending", dataThrough: "2026-11-01",
        analyzedAt: "2026-11-02T00:00:00Z"
    )
    private var record: StockAnalysisRecord {
        .init(id: "a-1", ticker: "005930", analyzedAt: "2026-11-02T00:00:00Z",
              dataThrough: "2026-11-01", modelId: "model", modelVersion: "v1",
              direction: "up", score: nil, validation: "pending", explanation: nil)
    }

    func testTickerNormalizationRejectsUnsafeValues() {
        XCTAssertEqual(ResearchWorkbenchEvidence.normalizedTicker(" 005930 "), "005930")
        XCTAssertEqual(ResearchWorkbenchEvidence.normalizedTicker("ab12cd"), "AB12CD")
        for ticker in ["", "00593", "0059300", "00/930", "００５９３０", "ab-123"] {
            XCTAssertNil(ResearchWorkbenchEvidence.normalizedTicker(ticker))
        }
    }

    func testHTTPOnlyCorroboratesExactIndependentPublication() {
        let snapshot = StockAnalysisSnapshot(ticker: "005930", records: [record])
        XCTAssertEqual(
            ResearchWorkbenchEvidence.verify(ticker: "005930", entries: [entry], snapshot: snapshot, isHTTP: true),
            .corroborated
        )
        XCTAssertEqual(
            ResearchWorkbenchEvidence.verify(ticker: "005930", entries: [entry], snapshot: snapshot, isHTTP: false),
            .demonstration
        )
    }

    func testMissingOrMismatchedPublicationFailsClosed() {
        let snapshot = StockAnalysisSnapshot(ticker: "005930", records: [record])
        XCTAssertEqual(
            ResearchWorkbenchEvidence.verify(ticker: "005930", entries: [], snapshot: snapshot, isHTTP: true),
            .notConfirmed
        )
        XCTAssertEqual(
            ResearchWorkbenchEvidence.verify(ticker: "005930", entries: [entry], snapshot: .init(ticker: "005930", records: []), isHTTP: true),
            .notConfirmed
        )
        XCTAssertEqual(
            ResearchWorkbenchEvidence.verify(ticker: "005930", entries: [entry], snapshot: .init(ticker: "000660", records: [record]), isHTTP: true),
            .unavailable
        )
        XCTAssertEqual(
            ResearchWorkbenchEvidence.verify(ticker: "005930", entries: [entry], snapshot: .init(ticker: "005930", records: [record, record]), isHTTP: true),
            .notConfirmed
        )
        XCTAssertEqual(
            ResearchWorkbenchEvidence.verify(ticker: "005930", entries: nil, snapshot: snapshot, isHTTP: true),
            .unavailable
        )
        XCTAssertEqual(
            ResearchWorkbenchEvidence.verify(ticker: "005930", entries: [entry], snapshot: nil, isHTTP: true),
            .unavailable
        )
    }
}
