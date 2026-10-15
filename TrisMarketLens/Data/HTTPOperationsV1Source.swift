import Foundation

struct HTTPOperationsV1Source: OperationsV1Source {
    let client: ResearchAPIClient

    private func query(offset: Int, limit: Int) throws -> [URLQueryItem] {
        guard offset >= 0, offset <= OperationsContract.maximumOffset,
              limit >= 1, limit <= 100 else { throw OperationsContractError.invalidPagination }
        return [.init(name: "offset", value: String(offset)), .init(name: "limit", value: String(limit))]
    }

    func getRuns(offset: Int, limit: Int = OperationsContract.pageLimit) async throws -> OperationsRunsPage {
        let page = try await client.fetch(OperationsRunsPage.self, path: ["api", "v1", "operations", "runs"], queryItems: query(offset: offset, limit: limit))
        try page.validate(requestedOffset: offset, requestedLimit: limit)
        return page
    }

    func getFreshness() async throws -> OperationsFreshnessResponse {
        let response = try await client.fetch(OperationsFreshnessResponse.self, path: ["api", "v1", "operations", "freshness"])
        try response.validate()
        return response
    }

    func getAlerts(offset: Int, limit: Int = OperationsContract.pageLimit) async throws -> OperationsAlertsPage {
        let page = try await client.fetch(OperationsAlertsPage.self, path: ["api", "v1", "operations", "alerts"], queryItems: query(offset: offset, limit: limit))
        try page.validate(requestedOffset: offset, requestedLimit: limit)
        return page
    }
}
