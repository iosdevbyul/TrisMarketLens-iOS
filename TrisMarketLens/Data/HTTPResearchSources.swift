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
        let stocks = try await client.fetch([StockSummary].self, path: ["api", "v1", "stocks"])
        guard stocks.count <= 10_000 else { throw ResearchAPIError.invalidPayload }
        var tickers = Set<String>()
        for stock in stocks {
            guard ResearchPayloadIntegrity.ticker(stock.ticker),
                  !stock.market.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  tickers.insert(stock.ticker).inserted else {
                throw ResearchAPIError.invalidPayload
            }
        }
        return stocks
    }
    func getStock(ticker: String) async throws -> StockDetail? {
        do {
            let detail = try await client.fetch(StockDetail.self, path: ["api", "v1", "stocks", ticker])
            guard ResearchPayloadIntegrity.ticker(ticker),
                  detail.ticker == ticker,
                  !detail.market.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !detail.dataStatus.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw ResearchAPIError.invalidPayload
            }
            return detail
        } catch ResearchAPIError.httpStatus(404) {
            return nil
        }
    }
}

struct HTTPResearchCatalogSource: ResearchCatalogSource {
    let client: ResearchAPIClient
    func getModels() async throws -> [ModelSummary] {
        let models = try await client.fetch([ModelSummary].self, path: ["api", "v1", "models"])
        guard ResearchCatalogPayloadValidation.models(models) else { throw ResearchAPIError.invalidPayload }
        return models
    }
    func getModel(id: String) async throws -> ModelDetail? {
        do {
            let model = try await client.fetch(ModelDetail.self, path: ["api", "v1", "models", id])
            guard ResearchCatalogPayloadValidation.model(model, requestedID: id) else { throw ResearchAPIError.invalidPayload }
            return model
        } catch ResearchAPIError.httpStatus(404) {
            return nil
        }
    }
    func getEvidenceLayers() async throws -> [EvidenceLayerSummary] {
        let layers = try await client.fetch([EvidenceLayerSummary].self, path: ["api", "v1", "evidence"])
        guard ResearchCatalogPayloadValidation.layers(layers) else { throw ResearchAPIError.invalidPayload }
        return layers
    }
    func getEvidenceLayer(id: String) async throws -> EvidenceDetail? {
        do {
            let layer = try await client.fetch(EvidenceDetail.self, path: ["api", "v1", "evidence", id])
            guard ResearchCatalogPayloadValidation.layer(layer, requestedID: id) else { throw ResearchAPIError.invalidPayload }
            return layer
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
        // The backend exposes versioned runs/freshness/alerts, not /api/v1/operations.
        // OperationsV1Dashboard uses HTTPOperationsV1Source independently.
        throw ResearchAPIError.invalidConfiguration
    }
}
