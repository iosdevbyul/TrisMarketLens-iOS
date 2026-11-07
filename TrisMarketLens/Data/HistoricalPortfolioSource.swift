import Foundation

protocol HistoricalPortfolioSource {
    func getPage(offset: Int) async throws -> HistoricalPortfolioPage
    func getSummary(reportID: String) async throws -> HistoricalPortfolioSummary
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
}

struct UnavailableHistoricalPortfolioSource: HistoricalPortfolioSource {
    func getPage(offset: Int) async throws -> HistoricalPortfolioPage {
        throw ResearchAPIError.invalidConfiguration
    }
    func getSummary(reportID: String) async throws -> HistoricalPortfolioSummary {
        throw ResearchAPIError.invalidConfiguration
    }
}
