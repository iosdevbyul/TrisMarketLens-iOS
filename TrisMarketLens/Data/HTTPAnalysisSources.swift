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
            guard !entry.ticker.isEmpty,
                  !entry.analysisId.isEmpty,
                  !entry.modelId.isEmpty,
                  ["up", "down", "neutral"].contains(entry.direction),
                  ["verified", "pending", "blocked"].contains(entry.validation),
                  entry.score.map({ $0.isFinite && (0...1).contains($0) }) ?? true,
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
            let noTrade = bar.open == 0 && bar.high == 0 && bar.low == 0 && bar.close > 0 && bar.volume == 0
            let ordinary = bar.open > 0 && bar.close > 0 && bar.low > 0 &&
                bar.high >= max(bar.open, bar.close, bar.low) &&
                bar.low <= min(bar.open, bar.close)
            guard bar.date > previous,
                  bar.open.isFinite, bar.high.isFinite,
                  bar.low.isFinite, bar.close.isFinite,
                  bar.volume >= 0, (ordinary || noTrade) else {
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
                  ["up", "down", "neutral"].contains(item.direction),
                  ["verified", "pending", "blocked"].contains(item.validation),
                  item.score.map({ $0.isFinite && (0...1).contains($0) }) ?? true else {
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
            guard item.ticker == ticker, !item.id.isEmpty,
                  ids.insert(item.id).inserted,
                  (1...1000).contains(item.horizonSessions),
                  ["correct", "incorrect", "inconclusive", "pending"].contains(item.verdict),
                  item.referencePrice.map({ $0.isFinite && $0 > 0 }) ?? true,
                  item.evaluationPrice.map({ $0.isFinite && $0 > 0 }) ?? true,
                  item.realizedReturn.map(\.isFinite) ?? true else {
                throw ResearchAPIError.invalidPayload
            }
        }
        return snapshot
    }
}
