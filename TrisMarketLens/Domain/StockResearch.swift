import Foundation

struct OhlcvBar: Codable, Identifiable {
    let date: String
    let open: Double
    let high: Double
    let low: Double
    let close: Double
    let volume: Int

    var id: String { date }
}

struct OhlcvSeries: Codable {
    let ticker: String
    let bars: [OhlcvBar]
}

struct StockAnalysisRecord: Codable, Identifiable {
    let id: String
    let ticker: String
    let analyzedAt: String
    let dataThrough: String
    let modelId: String
    let modelVersion: String
    let direction: String
    let score: Double?
    let validation: String
    let explanation: String?
}

struct StockAnalysisSnapshot: Codable {
    let ticker: String
    let records: [StockAnalysisRecord]
}

struct PredictionEvaluation: Codable, Identifiable {
    let id: String
    let analysisId: String
    let ticker: String
    let evaluatedAt: String?
    let horizonSessions: Int
    let referenceDate: String
    let referencePrice: Double?
    let evaluationDate: String?
    let evaluationPrice: Double?
    let realizedReturn: Double?
    let verdict: String
    let policyId: String
    let explanation: String?
}

struct PredictionEvaluationSnapshot: Codable {
    let ticker: String
    let evaluations: [PredictionEvaluation]
}

extension StockAnalysisRecord {
    func matchingEvaluations(in evaluations: [PredictionEvaluation]) -> [PredictionEvaluation] {
        evaluations.filter { $0.analysisId == id && $0.ticker == ticker }
    }
}
