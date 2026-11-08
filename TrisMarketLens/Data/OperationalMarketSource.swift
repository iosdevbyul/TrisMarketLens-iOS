import Foundation

protocol OperationalMarketSource {
    func getSummary() async throws -> OperationalMarketSummary
    func getStocks(offset: Int) async throws -> OperationalMarketPage
    func getBars(ticker: String) async throws -> OhlcvSeries
}

struct HTTPOperationalMarketSource: OperationalMarketSource {
    let client: ResearchAPIClient

    func getSummary() async throws -> OperationalMarketSummary {
        let result = try await client.fetch(
            OperationalMarketSummary.self,
            path: ["api", "v1", "operational", "summary"]
        )
        try result.validate()
        return result
    }

    func getStocks(offset: Int) async throws -> OperationalMarketPage {
        guard (0...OperationalMarketContract.maximumOffset).contains(offset) else {
            throw ResearchAPIError.invalidConfiguration
        }
        let result = try await client.fetch(
            OperationalMarketPage.self,
            path: ["api", "v1", "operational", "stocks"],
            queryItems: [
                URLQueryItem(name: "offset", value: String(offset)),
                URLQueryItem(name: "limit", value: String(OperationalMarketContract.pageLimit))
            ]
        )
        try result.validate(offset: offset)
        return result
    }

    func getBars(ticker: String) async throws -> OhlcvSeries {
        guard HistoricalPortfolioContract.validTicker(ticker) else {
            throw ResearchAPIError.invalidConfiguration
        }
        let result = try await client.fetch(
            OhlcvSeries.self,
            path: ["api", "v1", "operational", "stocks", ticker, "ohlcv"]
        )
        try OperationalMarketContract.validateBars(result, ticker: ticker)
        return result
    }
}

struct UnavailableOperationalMarketSource: OperationalMarketSource {
    func getSummary() async throws -> OperationalMarketSummary {
        throw ResearchAPIError.invalidConfiguration
    }
    func getStocks(offset: Int) async throws -> OperationalMarketPage {
        throw ResearchAPIError.invalidConfiguration
    }
    func getBars(ticker: String) async throws -> OhlcvSeries {
        throw ResearchAPIError.invalidConfiguration
    }
}
