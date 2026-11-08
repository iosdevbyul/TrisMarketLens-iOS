import Foundation

/// Comparison retains the backend's recorded values and expressly unavailable evidence.
struct HistoricalComparisonBasis: Decodable {
    let timestamp: String?
    let stage: String?
    let observedMarkFields: [String]?
    let policy: String?
    let unavailable: [String: String]

    func validate() throws {
        guard policy == nil else { throw ResearchAPIError.invalidPayload }
    }
}

struct HistoricalComparisonItem: Decodable, Identifiable {
    let summary: HistoricalPortfolioSummary
    let tickerCount: Int
    let signalEvidenceScopes: [String]
    let valuationBasis: HistoricalComparisonBasis

    var id: String { summary.reportId }

    init(from decoder: Decoder) throws {
        summary = try HistoricalPortfolioSummary(from: decoder)
        let fields = try decoder.container(keyedBy: CodingKeys.self)
        tickerCount = try fields.decode(Int.self, forKey: .tickerCount)
        signalEvidenceScopes = try fields.decode([String].self, forKey: .signalEvidenceScopes)
        valuationBasis = try fields.decode(HistoricalComparisonBasis.self, forKey: .valuationBasis)
    }

    private enum CodingKeys: String, CodingKey {
        case tickerCount, signalEvidenceScopes, valuationBasis
    }

    func validate(reportID: String) throws {
        try summary.validate(expectedReportID: reportID)
        guard tickerCount == summary.tickers.count,
              tickerCount == 5, signalEvidenceScopes.allSatisfy({ !$0.isEmpty }) else {
            throw ResearchAPIError.invalidPayload
        }
        try valuationBasis.validate()
    }
}

struct HistoricalComparability: Decodable {
    let periodsDiffer: Bool
    let valuationTimestampsDiffer: Bool?
    let observedMarkFieldsDiffer: Bool?
    let valuationPolicyComparison: String
    let unavailable: [String: String]
    let notices: [String]

    func validate() throws {
        guard valuationPolicyComparison == "unavailable",
              notices.contains("no_ranking_or_recommendation"),
              notices.contains("valuation_policy_not_in_published_projection") else {
            throw ResearchAPIError.invalidPayload
        }
    }
}

struct HistoricalPortfolioComparison: Decodable {
    let schemaVersion: String
    let researchOnly: Bool
    let operationalEligible: Bool
    let executable: Bool
    let pitVerified: Bool
    let oosVerified: Bool
    let investmentSuitabilityVerified: Bool
    let brokerageEligible: Bool
    let items: [HistoricalComparisonItem]
    let comparability: HistoricalComparability

    func validate(selected reportIDs: [String]) throws {
        try HistoricalComparisonContract.validateSelection(reportIDs)
        guard schemaVersion == "historical_portfolio_comparison_v1",
              researchOnly, !operationalEligible, !executable,
              !pitVerified, !oosVerified, !investmentSuitabilityVerified, !brokerageEligible,
              items.map(\.id) == reportIDs else { throw ResearchAPIError.invalidPayload }
        for (item, id) in zip(items, reportIDs) {
            try item.validate(reportID: id)
        }
        try comparability.validate()
    }
}

enum HistoricalComparisonContract {
    static func validateSelection(_ reportIDs: [String]) throws {
        guard (2...5).contains(reportIDs.count),
              Set(reportIDs).count == reportIDs.count,
              reportIDs.allSatisfy(HistoricalPortfolioContract.validReportID) else {
            throw ResearchAPIError.invalidConfiguration
        }
    }
}
