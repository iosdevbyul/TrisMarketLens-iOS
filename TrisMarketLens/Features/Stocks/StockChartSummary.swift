import Foundation

struct StockChartSummary: Equatable {
    let firstDate: String
    let lastDate: String
    let firstOpen: Double
    let lastClose: Double
    let highest: Double
    let lowest: Double
    let totalVolume: Int64
    let changePercent: Double?

    init?(bars: [OhlcvBar]) {
        guard let first = bars.first, let last = bars.last else { return nil }
        firstDate = first.date
        lastDate = last.date
        firstOpen = first.open
        lastClose = last.close
        highest = bars.map(\.high).max() ?? last.high
        lowest = bars.map(\.low).min() ?? first.low
        totalVolume = bars.reduce(Int64(0)) { $0 + Int64($1.volume) }
        changePercent = first.open > 0 ? (last.close - first.open) / first.open * 100 : nil
    }
}
