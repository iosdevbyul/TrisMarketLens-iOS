import Foundation

enum StockChartAxisLabels {
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
