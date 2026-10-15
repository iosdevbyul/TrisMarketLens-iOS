import Foundation

enum ResearchEnvironmentError: Error, Equatable {
    case unsupportedMode
    case missingBaseURL
    case invalidBaseURL
}

struct ResearchEnvironment {
    let mode: ResearchDataMode
    let client: ResearchAPIClient?

    #if DEBUG
    private static let defaultMode = "mock"
    #else
    private static let defaultMode = "disconnected"
    #endif

    init(values: [String: String]) throws {
        guard let mode = ResearchDataMode(rawValue: values["TRIS_DATA_MODE"] ?? Self.defaultMode) else {
            throw ResearchEnvironmentError.unsupportedMode
        }
        #if !DEBUG
        guard mode != .mock else { throw ResearchEnvironmentError.unsupportedMode }
        #endif
        self.mode = mode
        if mode == .http {
            guard let raw = values["TRIS_API_BASE_URL"], !raw.isEmpty else {
                throw ResearchEnvironmentError.missingBaseURL
            }
            guard let url = URL(string: raw),
                  let client = try? ResearchAPIClient(baseURL: url) else {
                throw ResearchEnvironmentError.invalidBaseURL
            }
            self.client = client
        } else {
            self.client = nil
        }
    }

    static func fromProcess() throws -> ResearchEnvironment {
        try ResearchEnvironment(values: ProcessInfo.processInfo.environment)
    }

    func project() -> any ProjectStatusSource {
        if let client { return HTTPProjectStatusSource(client: client) }
        if mode == .mock { return MockProjectStatusSource() }
        return UnavailableProjectStatusSource()
    }

    func stocks() -> any StockSource {
        if let client { return HTTPStockSource(client: client) }
        if mode == .mock { return MockStockSource() }
        return UnavailableStockSource()
    }

    func screener() -> any ScreenerSource {
        if let client { return HTTPScreenerSource(client: client) }
        return DisconnectedScreenerSource()
    }

    func stockResearch() -> any StockResearchSource {
        if let client { return HTTPStockResearchSource(client: client) }
        return DisconnectedStockResearchSource()
    }

    func catalog() -> any ResearchCatalogSource {
        if let client { return HTTPResearchCatalogSource(client: client) }
        return DisconnectedResearchCatalogSource()
    }

    func operationsV1() -> any OperationsV1Source {
        if let client { return HTTPOperationsV1Source(client: client) }
        return UnavailableOperationsV1Source()
    }

    func operations() -> any BacktestingOperationsSource {
        if let client { return HTTPBacktestingOperationsSource(client: client) }
        return DisconnectedBacktestingOperationsSource()
    }
}

private enum UnavailableResearchError: Error { case disconnected }

private struct UnavailableProjectStatusSource: ProjectStatusSource {
    func getProjectStatus() async throws -> ProjectStatus {
        throw UnavailableResearchError.disconnected
    }
}

private struct UnavailableStockSource: StockSource {
    func getStocks() async throws -> [StockSummary] {
        throw UnavailableResearchError.disconnected
    }
    func getStock(ticker: String) async throws -> StockDetail? {
        throw UnavailableResearchError.disconnected
    }
}
