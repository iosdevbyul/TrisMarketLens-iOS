import Foundation

/// Aggregates only observed data-through dates. Missing dates are not zero-activity days.
struct DailyAnalysisSummary: Identifiable, Equatable {
    let date: String
    let records: Int
    let securities: Int
    let up: Int
    let down: Int
    let neutral: Int
    let verified: Int
    let pending: Int
    let blocked: Int
    let latestAnalyzedAt: String

    var id: String { date }

    static func summarize(_ entries: [ScreenerEntry]) -> [DailyAnalysisSummary] {
        Dictionary(grouping: entries, by: \.dataThrough)
            .map { date, records in
                DailyAnalysisSummary(
                    date: date,
                    records: records.count,
                    securities: Set(records.map(\.ticker)).count,
                    up: records.filter { $0.direction == "up" }.count,
                    down: records.filter { $0.direction == "down" }.count,
                    neutral: records.filter { $0.direction == "neutral" }.count,
                    verified: records.filter { $0.validation == "verified" }.count,
                    pending: records.filter { $0.validation == "pending" }.count,
                    blocked: records.filter { $0.validation == "blocked" }.count,
                    latestAnalyzedAt: records.map(\.analyzedAt).max() ?? ""
                )
            }
            .sorted { $0.date < $1.date }
    }
}
