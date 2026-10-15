import Foundation

enum StockChartAxisLabels {
    static func label(for date: String, period: StockChartPeriod) -> String {
        guard date.count == 10, date[date.index(date.startIndex, offsetBy: 4)] == "-" else { return date }
        switch period {
        case .month, .quarter: return String(date.suffix(5))
        case .year: return String(date.dropFirst(2).prefix(5))
        case .all: return String(date.prefix(4))
        }
    }

    /// Sample a handful of actual trading sessions for categorical date axes.
    /// Swift Charts does not honor automatic desiredCount for String categories.
    static func dates(for dates: [String], maxLabels: Int = 5) -> [String] {
        guard !dates.isEmpty, maxLabels > 0 else { return [] }
        guard dates.count > maxLabels else { return dates }
        guard maxLabels > 1 else { return [dates[0]] }

        let last = dates.count - 1
        return (0..<maxLabels).map { index in
            dates[index * last / (maxLabels - 1)]
        }
    }
}
