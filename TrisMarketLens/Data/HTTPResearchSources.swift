import Foundation

struct HTTPProjectStatusSource: ProjectStatusSource {
    let client: ResearchAPIClient
    func getProjectStatus() async throws -> ProjectStatus {
        try await client.fetch(ProjectStatus.self, path: ["api", "v1", "project", "status"])
    }
}

struct HTTPStockSource: StockSource {
    let client: ResearchAPIClient
    func getStocks() async throws -> [StockSummary] {
        try await client.fetch([StockSummary].self, path: ["api", "v1", "stocks"])
    }
    func getStock(ticker: String) async throws -> StockDetail? {
        do {
            return try await client.fetch(StockDetail.self, path: ["api", "v1", "stocks", ticker])
        } catch ResearchAPIError.httpStatus(404) {
            return nil
        }
    }
}

struct HTTPResearchCatalogSource: ResearchCatalogSource {
    let client: ResearchAPIClient
    func getModels() async throws -> [ModelSummary] {
        try await client.fetch([ModelSummary].self, path: ["api", "v1", "models"])
    }
    func getModel(id: String) async throws -> ModelDetail? {
        do {
            return try await client.fetch(ModelDetail.self, path: ["api", "v1", "models", id])
        } catch ResearchAPIError.httpStatus(404) {
            return nil
        }
    }
    func getEvidenceLayers() async throws -> [EvidenceLayerSummary] {
        try await client.fetch([EvidenceLayerSummary].self, path: ["api", "v1", "evidence"])
    }
    func getEvidenceLayer(id: String) async throws -> EvidenceDetail? {
        do {
            return try await client.fetch(EvidenceDetail.self, path: ["api", "v1", "evidence", id])
        } catch ResearchAPIError.httpStatus(404) {
            return nil
        }
    }
}

struct HTTPBacktestingOperationsSource: BacktestingOperationsSource {
    let client: ResearchAPIClient
    func getBaseline() async throws -> BaselineBacktestSnapshot? {
        do {
            return try await client.fetch(BaselineBacktestSnapshot.self, path: ["api", "v1", "backtests", "baseline"])
        } catch ResearchAPIError.httpStatus(404) {
            return nil
        }
    }
    func getOperations() async throws -> OperationsSnapshot {
        try await client.fetch(OperationsSnapshot.self, path: ["api", "v1", "operations"])
    }
}
