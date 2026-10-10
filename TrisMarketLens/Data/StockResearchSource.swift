import Foundation

protocol StockResearchSource {
    func getOhlcv(ticker: String) async throws -> OhlcvSeries
    func getAnalysis(ticker: String) async throws -> StockAnalysisSnapshot
    func getEvaluations(ticker: String) async throws -> PredictionEvaluationSnapshot
}

/// Uses empty records until verified research APIs are connected.
/// Never generates artificial prices or predictions.
struct DisconnectedStockResearchSource: StockResearchSource {
    func getOhlcv(ticker: String) async throws -> OhlcvSeries {
        OhlcvSeries(ticker: ticker, bars: [])
    }

    func getAnalysis(ticker: String) async throws -> StockAnalysisSnapshot {
        StockAnalysisSnapshot(ticker: ticker, records: [])
    }

    func getEvaluations(ticker: String) async throws -> PredictionEvaluationSnapshot {
        PredictionEvaluationSnapshot(ticker: ticker, evaluations: [])
    }
}
