import Foundation

struct HTTPScreenerSource: ScreenerSource {
    let client: ResearchAPIClient

    func getScreener() async throws -> ScreenerSnapshot {
        let snapshot = try await client.fetch(
            ScreenerSnapshot.self,
            path: ["api", "v1", "analysis", "screener"]
        )
        guard snapshot.entries.count <= 5000 else {
            throw ResearchAPIError.invalidPayload
        }
        var seen = Set<String>()
        for entry in snapshot.entries {
            guard !entry.analysisId.isEmpty,
                  ResearchPayloadIntegrity.analysisFields(
                      ticker: entry.ticker, modelId: entry.modelId,
                      modelVersion: entry.modelVersion, date: entry.dataThrough,
                      analyzedAt: entry.analyzedAt, direction: entry.direction,
                      validation: entry.validation, score: entry.score
                  ),
                  seen.insert(entry.id).inserted else {
                throw ResearchAPIError.invalidPayload
            }
        }
        return snapshot
    }
}

struct HTTPStockResearchSource: StockResearchSource {
    let client: ResearchAPIClient

    func getOhlcv(ticker: String) async throws -> OhlcvSeries {
        let series = try await client.fetch(
            OhlcvSeries.self,
            path: ["api", "v1", "stocks", ticker, "ohlcv"]
        )
        guard series.ticker == ticker, series.bars.count <= 2500 else {
            throw ResearchAPIError.invalidPayload
        }
        var previous = ""
        for bar in series.bars {
            guard ResearchPayloadIntegrity.bar(bar, after: previous) else {
                throw ResearchAPIError.invalidPayload
            }
            previous = bar.date
        }
        return series
    }

    func getAnalysis(ticker: String) async throws -> StockAnalysisSnapshot {
        let snapshot = try await client.fetch(
            StockAnalysisSnapshot.self,
            path: ["api", "v1", "stocks", ticker, "analysis"]
        )
        guard snapshot.ticker == ticker, snapshot.records.count <= 500 else {
            throw ResearchAPIError.invalidPayload
        }
        var ids = Set<String>()
        for item in snapshot.records {
            guard item.ticker == ticker, !item.id.isEmpty,
                  ids.insert(item.id).inserted,
                  ResearchPayloadIntegrity.analysisFields(
                      ticker: item.ticker, modelId: item.modelId,
                      modelVersion: item.modelVersion, date: item.dataThrough,
                      analyzedAt: item.analyzedAt, direction: item.direction,
                      validation: item.validation, score: item.score
                  ) else {
                throw ResearchAPIError.invalidPayload
            }
        }
        return snapshot
    }

    func getEvaluations(ticker: String) async throws -> PredictionEvaluationSnapshot {
        let snapshot = try await client.fetch(
            PredictionEvaluationSnapshot.self,
            path: ["api", "v1", "stocks", ticker, "evaluations"]
        )
        guard snapshot.ticker == ticker, snapshot.evaluations.count <= 500 else {
            throw ResearchAPIError.invalidPayload
        }
        var ids = Set<String>()
        for item in snapshot.evaluations {
            guard item.ticker == ticker,
                  ids.insert(item.id).inserted,
                  ResearchPayloadIntegrity.evaluation(item) else {
                throw ResearchAPIError.invalidPayload
            }
        }
        return snapshot
    }
}
