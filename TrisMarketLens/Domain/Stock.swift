import Foundation

struct StockSummary: Codable, Identifiable, Hashable {
    let ticker: String
    let name: String?
    let market: String
    let sector: String?

    var id: String { ticker }
    var displayName: String { name?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? ticker }
    var sectorLabel: String { sector?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "Sector unavailable" }

    func matches(_ query: String) -> Bool {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }
        return [ticker, name, sector]
            .compactMap { $0 }
            .contains { $0.localizedStandardContains(query) }
    }
}

struct StockDetail: Codable {
    let ticker: String
    let name: String?
    let market: String
    let sector: String?
    let dataStatus: String
    let latestDataDate: String
    let availableFrom: String
    let evidenceNote: String
    let chartNote: String

    var displayName: String { name?.nilIfEmpty ?? ticker }
    var sectorLabel: String { sector?.nilIfEmpty ?? "Sector unavailable" }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
