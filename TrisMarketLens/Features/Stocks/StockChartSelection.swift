import Foundation

enum StockChartSelection {
    static func bar(for selectedDate: String?, in visibleBars: [OhlcvBar]) -> OhlcvBar? {
        guard let selectedDate else { return nil }
        return visibleBars.first { $0.date == selectedDate }
    }
}
