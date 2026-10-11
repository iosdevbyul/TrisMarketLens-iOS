import Foundation

enum StockChartDisplayMode: Equatable {
    case candles
    case closingLine

    static func mode(sessionCount: Int) -> Self {
        sessionCount > 120 ? .closingLine : .candles
    }
}
