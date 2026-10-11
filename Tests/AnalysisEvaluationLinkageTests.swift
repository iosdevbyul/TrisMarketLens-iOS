import XCTest
@testable import TrisMarketLens

final class AnalysisEvaluationLinkageTests: XCTestCase {
    private let record = StockAnalysisRecord(
        id: "analysis-1", ticker: "005930", analyzedAt: "2026-10-01T00:00:00Z",
        dataThrough: "2026-09-30", modelId: "m1", modelVersion: "v1",
        direction: "neutral", score: nil, validation: "pending", explanation: nil
    )

    private func evaluation(_ id: String, analysisID: String = "analysis-1",
                            ticker: String = "005930", horizon: Int = 5) -> PredictionEvaluation {
        PredictionEvaluation(
            id: id, analysisId: analysisID, ticker: ticker, evaluatedAt: nil,
            horizonSessions: horizon, referenceDate: "2026-09-30",
            referencePrice: nil, evaluationDate: nil, evaluationPrice: nil,
            realizedReturn: nil, verdict: "pending", policyId: "policy",
            explanation: nil
        )
    }

    func testLinkageRequiresExactAnalysisAndTicker() {
        let items = [
            evaluation("match"),
            evaluation("other-analysis", analysisID: "analysis-2"),
            evaluation("other-ticker", ticker: "000660")
        ]
        XCTAssertEqual(record.matchingEvaluations(in: items).map(\.id), ["match"])
    }

    func testLinkedEvaluationsSortByHorizonThenID() {
        let items = [evaluation("z", horizon: 10), evaluation("b", horizon: 5),
                     evaluation("a", horizon: 5)]
        XCTAssertEqual(record.matchingEvaluations(in: items).map(\.id), ["a", "b", "z"])
    }

    func testEmptyInputDoesNotCreateEvaluation() {
        XCTAssertTrue(record.matchingEvaluations(in: []).isEmpty)
    }
}
