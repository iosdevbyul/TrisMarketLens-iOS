import Foundation

/// Timeline values are copies of offline-validated source evidence, not exchange confirmations.
struct HistoricalTimelineEvidence: Decodable {
    let opportunity_id: String
    let ticker: String
    let trading_date: String
    let action: String?
    let selected_rule: String?
    let decision_id: String?
    let decision_at: String?
    let model_id: String?
    let signal_evidence_scope: String?
    let source: HistoricalTimelineSource?
    let unavailable: [String: String]?

    func validate(ticker expectedTicker: String?) throws {
        guard HistoricalPortfolioContract.validTicker(ticker),
              expectedTicker == nil || ticker == expectedTicker,
              HistoricalPortfolioContract.validReportID(opportunity_id),
              !trading_date.isEmpty else {
            throw ResearchAPIError.invalidPayload
        }
        if let source { try source.validate() }
    }
}

struct HistoricalTimelineSource: Decodable {
    let historical_input_hash: String?
    let point_hash: String?
    let run_hash: String?

    func validate() throws {
        for value in [historical_input_hash, point_hash, run_hash].compactMap({ $0 }) {
            guard HistoricalPortfolioContract.validReportID(value) else {
                throw ResearchAPIError.invalidPayload
            }
        }
    }
}

struct HistoricalPortfolioTrade: Decodable, Identifiable {
    let eventId: String
    let classification: String
    let terminalStatus: String?
    let evidence: HistoricalTimelineEvidence

    var id: String { eventId }

    func validate(ticker: String?) throws {
        guard HistoricalPortfolioContract.validReportID(eventId),
              ["filled", "pending", "accepted", "rejected", "no_order"].contains(classification) else {
            throw ResearchAPIError.invalidPayload
        }
        try evidence.validate(ticker: ticker)
    }
}

struct HistoricalPortfolioTradesPage: Decodable {
    let schemaVersion: String
    let researchOnly: Bool
    let operationalEligible: Bool
    let executable: Bool
    let pitVerified: Bool
    let oosVerified: Bool
    let investmentSuitabilityVerified: Bool
    let brokerageEligible: Bool
    let reportId: String
    let items: [HistoricalPortfolioTrade]
    let total: Int
    let offset: Int
    let limit: Int

    func validate(reportID: String, ticker: String?, offset expectedOffset: Int) throws {
        try HistoricalPortfolioContract.validateRestrictions(
            schemaVersion: schemaVersion, researchOnly: researchOnly,
            operationalEligible: operationalEligible, executable: executable,
            pitVerified: pitVerified, oosVerified: oosVerified,
            investmentSuitabilityVerified: investmentSuitabilityVerified,
            brokerageEligible: brokerageEligible
        )
        guard self.reportId == reportID,
              offset == expectedOffset,
              limit == HistoricalPortfolioContract.pageLimit,
              total >= 0,
              items.count <= limit,
              items.count <= max(0, total - offset),
              Set(items.map(\.eventId)).count == items.count else {
            throw ResearchAPIError.invalidPayload
        }
        try items.forEach { try $0.validate(ticker: ticker) }
    }
}

struct HistoricalPortfolioTickerPage: Decodable {
    let schemaVersion: String
    let researchOnly: Bool
    let operationalEligible: Bool
    let executable: Bool
    let pitVerified: Bool
    let oosVerified: Bool
    let investmentSuitabilityVerified: Bool
    let brokerageEligible: Bool
    let reportId: String
    let ticker: String
    let modelId: String
    let realizedNetPnl: String?
    let unavailable: [String: String]
    let timeline: [HistoricalTimelineEvidence]
    let total: Int
    let offset: Int
    let limit: Int

    func validate(reportID: String, ticker expectedTicker: String, offset expectedOffset: Int) throws {
        try HistoricalPortfolioContract.validateRestrictions(
            schemaVersion: schemaVersion, researchOnly: researchOnly,
            operationalEligible: operationalEligible, executable: executable,
            pitVerified: pitVerified, oosVerified: oosVerified,
            investmentSuitabilityVerified: investmentSuitabilityVerified,
            brokerageEligible: brokerageEligible
        )
        guard self.reportId == reportID, ticker == expectedTicker,
              HistoricalPortfolioContract.validTicker(ticker),
              !modelId.isEmpty, offset == expectedOffset,
              limit == HistoricalPortfolioContract.pageLimit,
              total >= 0, timeline.count <= limit,
              timeline.count <= max(0, total - offset),
              Set(timeline.map(\.opportunity_id)).count == timeline.count else {
            throw ResearchAPIError.invalidPayload
        }
        try timeline.forEach { try $0.validate(ticker: ticker) }
    }
}
