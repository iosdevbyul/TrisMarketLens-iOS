import Foundation

enum StockChartPeriod: String, CaseIterable, Identifiable {
    case month = "1M"
    case quarter = "3M"
    case year = "1Y"
    case all = "All"

    var id: String { rawValue }

    var sessionLimit: Int? {
        switch self {
        case .month: 22
        case .quarter: 66
        case .year: 252
        case .all: nil
        }
    }

    func filter(_ bars: [OhlcvBar]) -> [OhlcvBar] {
        guard let sessionLimit else { return bars }
        return Array(bars.suffix(sessionLimit))
    }
}
