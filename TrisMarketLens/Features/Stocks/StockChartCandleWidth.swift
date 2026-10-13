import Foundation

enum StockChartCandleWidth {
    static func bodyWidth(for sessionCount: Int) -> CGFloat {
        sessionCount > 40 ? 3 : 6
    }
}
