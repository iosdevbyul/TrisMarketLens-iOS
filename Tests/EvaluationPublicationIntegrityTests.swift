import XCTest
@testable import TrisMarketLens

final class EvaluationPublicationIntegrityTests: XCTestCase {
    private func analysis(id: String = "a1", ticker: String = "005930",
                          date: String = "2026-10-01") -> StockAnalysisRecord {
        .init(id: id, ticker: ticker, analyzedAt: "2026-10-02T02:00:00Z",
              dataThrough: date, modelId: "model", modelVersion: "v1",
              direction: "up", score: 0.6, validation: "verified", explanation: nil)
    }

    private func evaluation(id: String = "e1", analysisId: String = "a1", ticker: String = "005930",
                            referenceDate: String = "2026-10-01",
                            evaluationDate: String? = nil,
                            evaluatedAt: String? = nil,
                            verdict: String = "pending",
                            referencePrice: Double? = nil,
                            evaluationPrice: Double? = nil,
                            realizedReturn: Double? = nil,
                            horizon: Int = 5) -> PredictionEvaluation {
        .init(id: id, analysisId: analysisId, ticker: ticker,
              evaluatedAt: evaluatedAt, horizonSessions: horizon,
              referenceDate: referenceDate, referencePrice: referencePrice,
              evaluationDate: evaluationDate, evaluationPrice: evaluationPrice,
              realizedReturn: realizedReturn, verdict: verdict,
              policyId: "evaluation_v1", explanation: nil)
    }

    func testOnlyExactlyLinkedPendingPublicationIsRetained() {
        let record = analysis()
        XCTAssertEqual(EvaluationPublicationIntegrity.assess(evaluation(), against: [record]), .pending)
        XCTAssertEqual(EvaluationPublicationIntegrity.assess(evaluation(analysisId: "other"), against: [record]), .inconsistent)
        XCTAssertEqual(EvaluationPublicationIntegrity.assess(evaluation(ticker: "000660"), against: [record]), .inconsistent)
        XCTAssertEqual(EvaluationPublicationIntegrity.assess(evaluation(referenceDate: "2026-10-02"), against: [record]), .inconsistent)
        XCTAssertEqual(EvaluationPublicationIntegrity.assess(evaluation(horizon: 0), against: [record]), .inconsistent)
        XCTAssertEqual(EvaluationPublicationIntegrity.assess(evaluation(), against: [record, record]), .inconsistent)
    }

    func testPendingRecordCannotClaimReturn() {
        let result = evaluation(realizedReturn: 0.1)
        XCTAssertEqual(EvaluationPublicationIntegrity.assess(result, against: [analysis()]), .inconsistent)
    }

    func testEvaluatedResultMustHaveDatesAndFinitePrices() {
        let valid = evaluation(evaluationDate: "2026-10-09",
                               evaluatedAt: "2026-10-10T00:00:00Z",
                               verdict: "positive", referencePrice: 100,
                               evaluationPrice: 110, realizedReturn: 0.1)
        XCTAssertEqual(EvaluationPublicationIntegrity.assess(valid, against: [analysis()]), .structurallyLinked)
        let futureTimestamp = evaluation(evaluationDate: "2026-10-09",
                                         evaluatedAt: "2026-10-08T23:59:59Z",
                                         verdict: "positive", referencePrice: 100,
                                         evaluationPrice: 110, realizedReturn: 0.1)
        XCTAssertEqual(EvaluationPublicationIntegrity.assess(futureTimestamp, against: [analysis()]), .inconsistent)
        let badPrice = evaluation(evaluationDate: "2026-10-09",
                                  evaluatedAt: "2026-10-10T00:00:00Z",
                                  verdict: "positive", referencePrice: 0,
                                  evaluationPrice: 110, realizedReturn: 0.1)
        XCTAssertEqual(EvaluationPublicationIntegrity.assess(badPrice, against: [analysis()]), .inconsistent)
        let impossibleDay = evaluation(evaluationDate: "2026-02-30",
                                       evaluatedAt: "2026-10-10T00:00:00Z",
                                       verdict: "positive", referencePrice: 100,
                                       evaluationPrice: 110, realizedReturn: 0.1)
        XCTAssertEqual(EvaluationPublicationIntegrity.assess(impossibleDay, against: [analysis()]), .inconsistent)
    }

    func testStaleAnalysisChronologyCannotAuthorizeEvaluation() {
        let stale = analysis(date: "2026-10-05")
        XCTAssertEqual(EvaluationPublicationIntegrity.assess(evaluation(referenceDate: "2026-10-05"), against: [stale]), .inconsistent)
    }

    func testWithholdsUnlinkedAndInconsistentReturns() {
        let results = [
            evaluation(id: "pending"),
            evaluation(id: "other", analysisId: "missing",
                       evaluationDate: "2026-10-09", evaluatedAt: "2026-10-10T00:00:00Z",
                       verdict: "positive", referencePrice: 100, evaluationPrice: 110,
                       realizedReturn: 0.1)
        ]
        XCTAssertEqual(EvaluationPublicationIntegrity.visible(results, analyses: [analysis()]).map(\.id), ["pending"])
        XCTAssertTrue(EvaluationPublicationIntegrity.visible(results, analyses: []).isEmpty)
    }
}
