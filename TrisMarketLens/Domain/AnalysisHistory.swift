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
        let grouped = Dictionary(grouping: entries, by: { $0.dataThrough })
        var summaries: [DailyAnalysisSummary] = []
        summaries.reserveCapacity(grouped.count)

        for (date, records) in grouped {
            var tickers = Set<String>()
            var up = 0
            var down = 0
            var neutral = 0
            var verified = 0
            var pending = 0
            var blocked = 0
            var latestAnalyzedAt = ""

            for record in records {
                tickers.insert(record.ticker)
                switch record.direction {
                case "up": up += 1
                case "down": down += 1
                case "neutral": neutral += 1
                default: break
                }

                switch record.validation {
                case "verified": verified += 1
                case "pending": pending += 1
                case "blocked": blocked += 1
                default: break
                }

                if record.analyzedAt > latestAnalyzedAt {
                    latestAnalyzedAt = record.analyzedAt
                }
            }

            let summary = DailyAnalysisSummary(
                date: date,
                records: records.count,
                securities: tickers.count,
                up: up,
                down: down,
                neutral: neutral,
                verified: verified,
                pending: pending,
                blocked: blocked,
                latestAnalyzedAt: latestAnalyzedAt
            )
            summaries.append(summary)
        }

        return summaries.sorted { $0.date < $1.date }
    }
}

enum AnalysisHistoryRange: String, CaseIterable, Identifiable {
    case recent7 = "Last 7 dates"
    case recent30 = "Last 30 dates"
    case all = "All dates"

    var id: String { rawValue }

    func apply(to history: [DailyAnalysisSummary]) -> [DailyAnalysisSummary] {
        switch self {
        case .recent7: return Array(history.suffix(7))
        case .recent30: return Array(history.suffix(30))
        case .all: return history
        }
    }
}
