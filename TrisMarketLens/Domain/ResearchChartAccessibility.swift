import Foundation

/// VoiceOver descriptions for already published chart values.
/// These strings never add an estimated session or synthesize missing prices.
enum ResearchChartAccessibility {
    static func history(_ days: [DailyAnalysisSummary]) -> String {
        guard let first = days.first, let last = days.last else {
            return "No published research activity dates."
        }
        let count = days.reduce(0) { $0 + $1.records }
        return "\(days.count) observed research dates from \(first.date) through \(last.date). \(count) published analyses. Missing calendar dates are not treated as zero."
    }

    static func day(_ day: DailyAnalysisSummary) -> String {
        "\(day.date). \(day.records) published analyses across \(day.securities) securities. \(day.up) up, \(day.down) down, \(day.neutral) neutral. \(day.verified) verified, \(day.pending) pending, \(day.blocked) blocked. Latest analysis \(day.latestAnalyzedAt)."
    }

    static func prices(_ bars: [OhlcvBar]) -> String {
        guard let first = bars.first, let last = bars.last else {
            return "No published price observations."
        }
        return "\(bars.count) published daily price observations from \(first.date) through \(last.date). First close \(first.close), last close \(last.close). This chart does not certify source provenance."
    }

    static func volume(_ bars: [OhlcvBar]) -> String {
        guard let first = bars.first, let last = bars.last else {
            return "No published volume observations."
        }
        return "\(bars.count) published daily volume observations from \(first.date) through \(last.date). Detailed volumes are listed by selected session."
    }
}
