import Foundation

/// Never associate an evaluation with an analysis from another ticker or ID.
/// Returns only explicitly linked evaluations; no inferred verdicts.
enum AnalysisEvaluationLinkage {
    static func matches(_ evaluation: PredictionEvaluation, record: StockAnalysisRecord) -> Bool {
        evaluation.analysisId == record.id && evaluation.ticker == record.ticker
    }

    static func linked(to record: StockAnalysisRecord, from evaluations: [PredictionEvaluation]) -> [PredictionEvaluation] {
        evaluations.filter { matches($0, record: record) }
            .sorted {
                if $0.horizonSessions != $1.horizonSessions {
                    return $0.horizonSessions < $1.horizonSessions
                }
                return $0.id < $1.id
            }
    }
}
