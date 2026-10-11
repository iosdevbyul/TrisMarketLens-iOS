import Foundation

struct ScreenerEntry: Codable, Identifiable, Equatable {
    let ticker: String
    let name: String?
    let analysisId: String
    let modelId: String
    let modelVersion: String
    let direction: String
    let score: Double?
    let validation: String
    let dataThrough: String
    let analyzedAt: String

    var id: String { "\(ticker):\(analysisId)" }
    var displayName: String { name?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? name! : ticker }
}

struct ScreenerSnapshot: Codable {
    let entries: [ScreenerEntry]
}

enum ScreenerSort: String, CaseIterable, Identifiable {
    case score, date, ticker
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

struct ScreenerFilter {
    var query = ""
    var direction = "all"
    var validation = "all"
    var sort: ScreenerSort = .score

    var isDefault: Bool {
        query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        direction == "all" && validation == "all" && sort == .score
    }

    mutating func reset() {
        self = ScreenerFilter()
    }

    func apply(to entries: [ScreenerEntry]) -> [ScreenerEntry] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let matching = entries.filter { item in
            let textMatch = query.isEmpty ||
                [item.ticker, item.name ?? "", item.modelId].contains { $0.localizedStandardContains(query) }
            return textMatch &&
                (direction == "all" || direction == item.direction) &&
                (validation == "all" || validation == item.validation)
        }
        return matching.sorted { lhs, rhs in
            switch sort {
            case .ticker:
                return lhs.ticker == rhs.ticker ? lhs.analysisId < rhs.analysisId : lhs.ticker < rhs.ticker
            case .date:
                return lhs.analyzedAt == rhs.analyzedAt ? lhs.ticker < rhs.ticker : lhs.analyzedAt > rhs.analyzedAt
            case .score:
                if (lhs.score ?? -1) == (rhs.score ?? -1) { return lhs.ticker < rhs.ticker }
                return (lhs.score ?? -1) > (rhs.score ?? -1)
            }
        }
    }
}
