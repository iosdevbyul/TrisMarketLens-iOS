import Foundation

/// An exact cross-check of the screener index against its read-only ticker publication.
/// This is evidence of source correspondence, not model validity or trade readiness.
enum WorkbenchPublicationState: Equatable {
    case corroborated
    case notConfirmed
    case unavailable
    case demonstration
}

enum ResearchWorkbenchEvidence {
    static func normalizedTicker(_ text: String) -> String? {
        let ticker = text.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard ticker.utf8.count == 6,
              ticker.utf8.allSatisfy({ (48...57).contains($0) || (65...90).contains($0) }) else {
            return nil
        }
        return ticker
    }

    static func verify(
        ticker: String,
        entries: [ScreenerEntry]?,
        snapshot: StockAnalysisSnapshot?,
        isHTTP: Bool
    ) -> WorkbenchPublicationState {
        guard normalizedTicker(ticker) == ticker,
              let entries, let snapshot, snapshot.ticker == ticker else {
            return .unavailable
        }
        if !isHTTP { return .demonstration }
        let index = entries.filter { $0.ticker == ticker }
        // Every match must refer to exactly one individual stock publication.
        let matched = index.contains { ResearchObservationMatch.resolve($0, in: snapshot) != nil }
        return matched ? .corroborated : .notConfirmed
    }
}
