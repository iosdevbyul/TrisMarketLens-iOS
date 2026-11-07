import Foundation

/// The screener is a discovery index, not the authoritative analysis detail.
enum ResearchObservationMatch {
    static func resolve(_ entry: ScreenerEntry, in snapshot: StockAnalysisSnapshot) -> StockAnalysisRecord? {
        guard snapshot.ticker == entry.ticker else { return nil }
        let matches = snapshot.records.filter {
            $0.ticker == entry.ticker &&
            $0.id == entry.analysisId &&
            $0.modelId == entry.modelId &&
            $0.modelVersion == entry.modelVersion &&
            $0.dataThrough == entry.dataThrough &&
            $0.analyzedAt == entry.analyzedAt &&
            $0.direction == entry.direction &&
            $0.validation == entry.validation &&
            $0.score == entry.score
        }
        return matches.count == 1 ? matches[0] : nil
    }
}
