import Foundation

/// Approved offline historical research only; never an executable or investment-eligible portfolio.
struct HistoricalPortfolioRestrictions: Decodable {
    let schemaVersion: String
    let researchOnly: Bool
    let operationalEligible: Bool
    let executable: Bool
    let pitVerified: Bool
    let oosVerified: Bool
    let investmentSuitabilityVerified: Bool
    let brokerageEligible: Bool

    func validate() throws {
        guard schemaVersion == "published_historical_portfolio_v1",
              researchOnly, !operationalEligible, !executable,
              !pitVerified, !oosVerified, !investmentSuitabilityVerified, !brokerageEligible else {
            throw ResearchAPIError.invalidPayload
        }
    }
}

struct HistoricalPortfolioItem: Decodable, Identifiable {
    let reportId: String
    let publishedAt: String
    let modelFamily: String
    let tickers: [String]
    let period: [String: String]
    let initialVirtualCash: String
    let evidenceScope: String
    let portfolioValuationAvailable: Bool
    let archiveVerification: String
    let reportVerification: String
    let researchOnly: Bool
    let operationalEligible: Bool
    let executable: Bool
    let pitVerified: Bool
    let oosVerified: Bool
    let investmentSuitabilityVerified: Bool
    let brokerageEligible: Bool

    var id: String { reportId }

    func validate() throws {
        guard HistoricalPortfolioContract.validReportID(reportId),
              ["linear", "hgb"].contains(modelFamily),
              tickers.count == 5, Set(tickers).count == 5,
              tickers.allSatisfy({ HistoricalPortfolioContract.validTicker($0) }),
              !publishedAt.isEmpty, !evidenceScope.isEmpty,
              !initialVirtualCash.isEmpty,
              archiveVerification == "integrity_verified",
              reportVerification == "offline_authoritative_replay_passed",
              researchOnly, !operationalEligible, !executable,
              !pitVerified, !oosVerified, !investmentSuitabilityVerified, !brokerageEligible else {
            throw ResearchAPIError.invalidPayload
        }
    }
}

struct HistoricalPortfolioPage: Decodable {
    let schemaVersion: String
    let researchOnly: Bool
    let operationalEligible: Bool
    let executable: Bool
    let pitVerified: Bool
    let oosVerified: Bool
    let investmentSuitabilityVerified: Bool
    let brokerageEligible: Bool
    let items: [HistoricalPortfolioItem]
    let total: Int
    let offset: Int
    let limit: Int

    func validate(offset expectedOffset: Int, limit expectedLimit: Int) throws {
        try HistoricalPortfolioContract.validateRestrictions(
            schemaVersion: schemaVersion, researchOnly: researchOnly,
            operationalEligible: operationalEligible, executable: executable,
            pitVerified: pitVerified, oosVerified: oosVerified,
            investmentSuitabilityVerified: investmentSuitabilityVerified,
            brokerageEligible: brokerageEligible
        )
        guard offset == expectedOffset, limit == expectedLimit,
              total >= 0, total <= 128,
              items.count <= limit, items.count <= max(0, total - offset),
              Set(items.map(\.reportId)).count == items.count else {
            throw ResearchAPIError.invalidPayload
        }
        try items.forEach { try $0.validate() }
    }
}

/// Explicitly typed display fields; nullable financial results are not coerced to zero.
struct HistoricalPortfolioSummary: Decodable {
    let schemaVersion: String
    let researchOnly: Bool
    let operationalEligible: Bool
    let executable: Bool
    let pitVerified: Bool
    let oosVerified: Bool
    let investmentSuitabilityVerified: Bool
    let brokerageEligible: Bool
    let reportId: String
    let publishedAt: String
    let modelFamily: String
    let modelId: String
    let tickers: [String]
    let period: [String: String]
    let initialVirtualCash: String
    let finalTotalCash: String
    let availableCash: String
    let reservedCash: String
    let finalPortfolioEquity: String?
    let realizedNetPnl: String
    let unrealizedPnl: String?
    let portfolioReturn: String?
    let decisionCount: Int
    let acceptedOrderCount: Int
    let fillCount: Int
    let completedPositionCount: Int
    let pendingOrderCount: Int
    let portfolioValuationAvailable: Bool
    let archiveTransportHash: String
    let resultHash: String
    let reportHash: String
    let runHash: String
    let performanceHash: String
    let evidenceScope: String
    let dataOrigin: String
    let limitations: [String]
    let unavailable: [String: String]
    let archiveVerification: String
    let reportVerification: String

    func validate(expectedReportID: String) throws {
        try HistoricalPortfolioContract.validateRestrictions(
            schemaVersion: schemaVersion, researchOnly: researchOnly,
            operationalEligible: operationalEligible, executable: executable,
            pitVerified: pitVerified, oosVerified: oosVerified,
            investmentSuitabilityVerified: investmentSuitabilityVerified,
            brokerageEligible: brokerageEligible
        )
        guard reportId == expectedReportID,
              HistoricalPortfolioContract.validReportID(reportId),
              ["linear", "hgb"].contains(modelFamily),
              tickers.count == 5, Set(tickers).count == 5,
              tickers.allSatisfy({ HistoricalPortfolioContract.validTicker($0) }),
              archiveVerification == "integrity_verified",
              reportVerification == "offline_authoritative_replay_passed",
              [archiveTransportHash, resultHash, reportHash, runHash, performanceHash].allSatisfy(HistoricalPortfolioContract.validReportID),
              decisionCount >= 0, acceptedOrderCount >= 0, fillCount >= 0,
              completedPositionCount >= 0, pendingOrderCount >= 0 else {
            throw ResearchAPIError.invalidPayload
        }
    }
}

enum HistoricalPortfolioContract {
    static let pageLimit = 10
    static let maximumOffset = 100_000

    static func validReportID(_ value: String) -> Bool {
        value.utf8.count == 64 && value.utf8.allSatisfy {
            (48...57).contains($0) || (97...102).contains($0)
        }
    }

    static func validTicker(_ value: String) -> Bool {
        value.utf8.count == 6 && value.utf8.allSatisfy {
            (48...57).contains($0) || (65...90).contains($0)
        }
    }

    static func validateRestrictions(
        schemaVersion: String, researchOnly: Bool, operationalEligible: Bool,
        executable: Bool, pitVerified: Bool, oosVerified: Bool,
        investmentSuitabilityVerified: Bool, brokerageEligible: Bool
    ) throws {
        guard schemaVersion == "published_historical_portfolio_v1",
              researchOnly, !operationalEligible, !executable,
              !pitVerified, !oosVerified, !investmentSuitabilityVerified, !brokerageEligible else {
            throw ResearchAPIError.invalidPayload
        }
    }
}
