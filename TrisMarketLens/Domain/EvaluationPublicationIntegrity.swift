import Foundation

/// Checks structural linkage and chronology only. The backend does not yet expose
/// an approved evaluation publication API, so no evaluation establishes live returns.
enum EvaluationPublicationIntegrity: Equatable {
    case pending
    case structurallyLinked
    case inconsistent

    var label: String {
        switch self {
        case .pending: "Pending; no observed outcome"
        case .structurallyLinked: "Structurally linked; outcome not independently verified"
        case .inconsistent: "Inconsistent or unlinked publication"
        }
    }

    static func assess(_ evaluation: PredictionEvaluation, against records: [StockAnalysisRecord]) -> Self {
        let candidates = records.filter {
            $0.id == evaluation.analysisId && $0.ticker == evaluation.ticker
        }
        guard candidates.count == 1, let analysis = candidates.first,
              AnalysisPublicationChronology.assess(analysis) == .consistent,
              evaluation.referenceDate == analysis.dataThrough,
              evaluation.horizonSessions > 0,
              !evaluation.policyId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              validDate(evaluation.referenceDate) else {
            return .inconsistent
        }
        if evaluation.verdict == "pending" {
            guard evaluation.evaluatedAt == nil, evaluation.evaluationDate == nil,
                  evaluation.evaluationPrice == nil, evaluation.realizedReturn == nil else {
                return .inconsistent
            }
            return .pending
        }
        guard let evaluationDate = evaluation.evaluationDate,
              validDate(evaluationDate),
              evaluationDate > evaluation.referenceDate,
              let reference = evaluation.referencePrice, reference.isFinite, reference > 0,
              let price = evaluation.evaluationPrice, price.isFinite, price > 0,
              let result = evaluation.realizedReturn, result.isFinite,
              let evaluatedAt = evaluation.evaluatedAt,
              let instant = parseInstant(evaluatedAt),
              let date = parseDate(evaluationDate),
              instant >= date else {
            return .inconsistent
        }
        return .structurallyLinked
    }

    static func visible(_ evaluations: [PredictionEvaluation], analyses: [StockAnalysisRecord]) -> [PredictionEvaluation] {
        evaluations.filter { assess($0, against: analyses) != .inconsistent }
    }

    private static func parseDate(_ value: String) -> Date? {
        guard value.utf8.count == 10 else { return nil }
        let parser = ISO8601DateFormatter()
        parser.timeZone = TimeZone(secondsFromGMT: 0)!
        parser.formatOptions = [.withFullDate]
        guard let date = parser.date(from: value), parser.string(from: date) == value else { return nil }
        return date
    }

    private static func validDate(_ value: String) -> Bool { parseDate(value) != nil }

    private static func parseInstant(_ value: String) -> Date? {
        let parser = ISO8601DateFormatter()
        parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = parser.date(from: value) { return date }
        parser.formatOptions = [.withInternetDateTime]
        return parser.date(from: value)
    }
}
