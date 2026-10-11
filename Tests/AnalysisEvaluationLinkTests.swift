import XCTest
@testable import TrisMarketLens

final class AnalysisEvaluationLinkTests: XCTestCase {
    func testOnlyMatchingAnalysisAndTickerAreLinked() {
        let record = StockAnalysisRecord(
            id: "analysis-1", ticker: "005930",
            analyzedAt: "2026-10-01T00:00:00Z", dataThrough: "2026-09-30",
            modelId: "model-1", modelVersion: "1",
            direction: "up", score: nil, validation: "pending", explanation: nil
        )
        let matching = evaluation(id: "match", analysisId: "analysis-1", ticker: "005930")
        let otherAnalysis = evaluation(id: "other-analysis", analysisId: "analysis-2", ticker: "005930")
        let otherTicker = evaluation(id: "other-ticker", analysisId: "analysis-1", ticker: "000660")
        XCTAssertEqual(
            record.matchingEvaluations(in: [otherAnalysis, matching, otherTicker]).map(\.id),
            ["match"]
        )
        XCTAssertTrue(record.matchingEvaluations(in: []).isEmpty)
    }

    private func evaluation(id: String, analysisId: String, ticker: String) -> PredictionEvaluation {
        PredictionEvaluation(
            id: id, analysisId: analysisId, ticker: ticker,
            evaluatedAt: nil, horizonSessions: 5, referenceDate: "2026-09-30",
            referencePrice: nil, evaluationDate: nil, evaluationPrice: nil,
            realizedReturn: nil, verdict: "pending", policyId: "policy",
            explanation: nil
        )
    }
}
