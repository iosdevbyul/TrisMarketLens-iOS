import XCTest
@testable import TrisMarketLens

final class ResearchPayloadIntegrityTests: XCTestCase {
    func testRejectsInvalidCalendarDates() {
        XCTAssertTrue(ResearchPayloadIntegrity.date("2026-10-11"))
        XCTAssertFalse(ResearchPayloadIntegrity.date("2026-02-30"))
        XCTAssertFalse(ResearchPayloadIntegrity.date("2026-13-01"))
        XCTAssertFalse(ResearchPayloadIntegrity.date("2026-1-01"))
    }

    func testTimestampRequiresExplicitTimezone() {
        XCTAssertTrue(ResearchPayloadIntegrity.timestamp("2026-10-11T12:30:00Z"))
        XCTAssertTrue(ResearchPayloadIntegrity.timestamp("2026-10-11T12:30:00+09:00"))
        XCTAssertFalse(ResearchPayloadIntegrity.timestamp("2026-10-11T12:30:00"))
        XCTAssertFalse(ResearchPayloadIntegrity.timestamp("not-a-time"))
    }

    func testAnalysisFieldsRejectInvalidStatusAndScore() {
        XCTAssertTrue(ResearchPayloadIntegrity.analysisFields(
            ticker: "005930", modelId: "m", modelVersion: "1",
            date: "2026-10-11", analyzedAt: "2026-10-11T12:30:00Z",
            direction: "up", validation: "verified", score: 0.8
        ))
        XCTAssertFalse(ResearchPayloadIntegrity.analysisFields(
            ticker: "005930", modelId: "m", modelVersion: "1",
            date: "2026-10-11", analyzedAt: "2026-10-11T12:30:00Z",
            direction: "up", validation: "unreviewed", score: 0.8
        ))
        XCTAssertFalse(ResearchPayloadIntegrity.score(Double.nan))
        XCTAssertFalse(ResearchPayloadIntegrity.ticker("00593X"))
    }

    func testBarDateAndRange() {
        let good = OhlcvBar(date: "2026-10-10", open: 100, high: 105, low: 99, close: 103, volume: 10)
        XCTAssertTrue(ResearchPayloadIntegrity.bar(good, after: "2026-10-09"))
        XCTAssertFalse(ResearchPayloadIntegrity.bar(good, after: "2026-10-10"))
        let invalid = OhlcvBar(date: "2026-02-30", open: 100, high: 105, low: 99, close: 103, volume: 10)
        XCTAssertFalse(ResearchPayloadIntegrity.bar(invalid, after: ""))
    }

    func testPendingEvaluationCannotClaimRealizedReturn() {
        let item = PredictionEvaluation(
            id: "e1", analysisId: "a1", ticker: "005930",
            evaluatedAt: nil, horizonSessions: 10, referenceDate: "2026-10-01",
            referencePrice: 100, evaluationDate: nil, evaluationPrice: nil,
            realizedReturn: 0.12, verdict: "pending", policyId: "p1", explanation: nil
        )
        XCTAssertFalse(ResearchPayloadIntegrity.evaluation(item))
    }
}
