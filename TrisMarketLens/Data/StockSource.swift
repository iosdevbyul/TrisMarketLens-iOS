import Foundation

protocol StockSource {
    func getStocks() async throws -> [StockSummary]
    func getStock(ticker: String) async throws -> StockDetail?
    func getOHLCV(ticker: String) async throws -> OhlcvSeries?
}

/// Synthetic fixtures. No price, prediction, or performance data is generated.
struct MockStockSource: StockSource {
    private let stocks: [StockSummary] = [
        .init(ticker: "000001", name: "Example Alpha", market: "KOSPI", sector: nil),
        .init(ticker: "000002", name: nil, market: "KOSPI", sector: nil),
        .init(ticker: "000003", name: "Example Beta", market: "KOSPI", sector: "Sample sector")
    ]

    func getStocks() async throws -> [StockSummary] { stocks }

    func getOHLCV(ticker: String) async throws -> OhlcvSeries? { nil }

    func getStock(ticker: String) async throws -> StockDetail? {
        guard let stock = stocks.first(where: { $0.ticker == ticker }) else { return nil }
        return StockDetail(
            ticker: stock.ticker,
            name: stock.name,
            market: stock.market,
            sector: stock.sector,
            dataStatus: "mock",
            latestDataDate: "Unavailable",
            availableFrom: "Unavailable",
            evidenceNote: "Synthetic demo record. No verified lifecycle evidence loaded.",
            chartNote: "No validated OHLCV price series loaded."
        )
    }
}
