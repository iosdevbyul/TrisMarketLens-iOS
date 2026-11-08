import Foundation

protocol HistoricalPortfolioSource {
    func getPage(offset: Int) async throws -> HistoricalPortfolioPage
    func getSummary(reportID: String) async throws -> HistoricalPortfolioSummary
    func getTrades(reportID: String, ticker: String?, offset: Int) async throws -> HistoricalPortfolioTradesPage
    func getTicker(reportID: String, ticker: String, offset: Int) async throws -> HistoricalPortfolioTickerPage
}

/// The backend limits historical publications to trusted loopback callers.
/// A remote URL must fail before sending credentials or making an HTTP request.
struct HTTPHistoricalPortfolioSource: HistoricalPortfolioSource {
    let client: ResearchAPIClient

    private func guardLocal() throws {
        let components = URLComponents(url: client.baseURL, resolvingAgainstBaseURL: false)
        guard components?.scheme?.lowercased() == "http",
              let host = components?.host?.lowercased(),
              ["localhost", "127.0.0.1", "::1"].contains(host) else {
            throw ResearchAPIError.invalidConfiguration
        }
    }

    func getPage(offset: Int) async throws -> HistoricalPortfolioPage {
        try guardLocal()
        guard offset >= 0, offset <= HistoricalPortfolioContract.maximumOffset else {
            throw ResearchAPIError.invalidConfiguration
        }
        let page = try await client.fetch(
            HistoricalPortfolioPage.self,
            path: ["api", "v1", "research", "historical-portfolios"],
            queryItems: [
                .init(name: "offset", value: String(offset)),
                .init(name: "limit", value: String(HistoricalPortfolioContract.pageLimit))
            ]
        )
        try page.validate(offset: offset, limit: HistoricalPortfolioContract.pageLimit)
        return page
    }

    func getSummary(reportID: String) async throws -> HistoricalPortfolioSummary {
        try guardLocal()
        guard HistoricalPortfolioContract.validReportID(reportID) else {
            throw ResearchAPIError.invalidConfiguration
        }
        let summary = try await client.fetch(
            HistoricalPortfolioSummary.self,
            path: ["api", "v1", "research", "historical-portfolios", reportID]
        )
        try summary.validate(expectedReportID: reportID)
        return summary
    }

    private func validatedTimelineRequest(reportID: String, ticker: String?, offset: Int) throws {
        try guardLocal()
        guard HistoricalPortfolioContract.validReportID(reportID),
              offset >= 0, offset <= HistoricalPortfolioContract.maximumOffset,
              ticker == nil || HistoricalPortfolioContract.validTicker(ticker!) else {
            throw ResearchAPIError.invalidConfiguration
        }
    }

    func getTrades(reportID: String, ticker: String?, offset: Int) async throws -> HistoricalPortfolioTradesPage {
        try validatedTimelineRequest(reportID: reportID, ticker: ticker, offset: offset)
        var query = [
            URLQueryItem(name: "offset", value: String(offset)),
            URLQueryItem(name: "limit", value: String(HistoricalPortfolioContract.pageLimit))
        ]
        if let ticker { query.append(URLQueryItem(name: "ticker", value: ticker)) }
        let result = try await client.fetch(
            HistoricalPortfolioTradesPage.self,
            path: ["api", "v1", "research", "historical-portfolios", reportID, "trades"],
            queryItems: query
        )
        try result.validate(reportID: reportID, ticker: ticker, offset: offset)
        return result
    }

    func getTicker(reportID: String, ticker: String, offset: Int) async throws -> HistoricalPortfolioTickerPage {
        try validatedTimelineRequest(reportID: reportID, ticker: ticker, offset: offset)
        let result = try await client.fetch(
            HistoricalPortfolioTickerPage.self,
            path: ["api", "v1", "research", "historical-portfolios", reportID, "tickers", ticker],
            queryItems: [
                URLQueryItem(name: "offset", value: String(offset)),
                URLQueryItem(name: "limit", value: String(HistoricalPortfolioContract.pageLimit))
            ]
        )
        try result.validate(reportID: reportID, ticker: ticker, offset: offset)
        return result
    }

}

struct UnavailableHistoricalPortfolioSource: HistoricalPortfolioSource {
    func getPage(offset: Int) async throws -> HistoricalPortfolioPage {
        throw ResearchAPIError.invalidConfiguration
    }
    func getSummary(reportID: String) async throws -> HistoricalPortfolioSummary {
        throw ResearchAPIError.invalidConfiguration
    }
    func getTrades(reportID: String, ticker: String?, offset: Int) async throws -> HistoricalPortfolioTradesPage {
        throw ResearchAPIError.invalidConfiguration
    }
    func getTicker(reportID: String, ticker: String, offset: Int) async throws -> HistoricalPortfolioTickerPage {
        throw ResearchAPIError.invalidConfiguration
    }

}
