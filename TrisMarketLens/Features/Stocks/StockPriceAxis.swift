import Foundation

enum StockPriceAxis {
    /// Compute a readable axis from observed positive prices only.
    /// KRX no-trade bars can contain zero OHLC; those are not valid range endpoints.
    static func domain(for bars: [OhlcvBar]) -> ClosedRange<Double>? {
        let prices = bars.flatMap { [$0.open, $0.high, $0.low, $0.close] }
            .filter { $0.isFinite && $0 > 0 }
        guard let minimum = prices.min(), let maximum = prices.max() else { return nil }
        let spread = maximum - minimum
        let padding = max(spread * 0.08, maximum * 0.01)
        return max(0, minimum - padding)...(maximum + padding)
    }
}
