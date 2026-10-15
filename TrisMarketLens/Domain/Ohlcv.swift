import Foundation

/// Original unadjusted KRX sessions. Zero OHLC values may represent no-trade bars.
struct OhlcvBar: Codable, Hashable, Identifiable {
    let date: String
    let open: Int
    let high: Int
    let low: Int
    let close: Int
    let volume: Int

    var id: String { date }
}

struct OhlcvSeries: Codable {
    let ticker: String
    let bars: [OhlcvBar]
}
