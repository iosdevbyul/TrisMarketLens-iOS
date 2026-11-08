import Foundation
import XCTest
@testable import TrisMarketLens

final class HistoricalPortfolioTimelineTests: XCTestCase {
    private let reportID = String(repeating: "a", count: 64)
    private let eventID = String(repeating: "b", count: 64)

    private var evidence: String {
        """
        {"opportunity_id":"\(eventID)","ticker":"005930","trading_date":"2020-05-21",
        "action":"HOLD","selected_rule":null,"decision_id":null,"decision_at":null,
        "model_id":"model","signal_evidence_scope":"synthetic_fixture",
        "source":{"historical_input_hash":"\(reportID)","point_hash":null,"run_hash":"\(reportID)"},
        "unavailable":{"signal_status":"aggregate_signal_status_not_recorded"}}
        """
    }

    private var restrictions: String {
        """
        "schemaVersion":"published_historical_portfolio_v1","researchOnly":true,
        "operationalEligible":false,"executable":false,"pitVerified":false,
        "oosVerified":false,"investmentSuitabilityVerified":false,"brokerageEligible":false
        """
    }

    private func tradesPage(ticker: String = "005930", reportID: String? = nil, classification: String = "no_order") -> String {
        """
        {\(restrictions),"reportId":"\(reportID ?? self.reportID)",
        "items":[{"eventId":"\(eventID)","classification":"\(classification)",
        "terminalStatus":null,"evidence":\(evidence.replacingOccurrences(of: "\"ticker\":\"005930\"", with: "\"ticker\":\"\(ticker)\""))}],
        "total":1,"offset":0,"limit":10}
        """
    }

    private func tickerPage(ticker: String = "005930", offset: Int = 0) -> String {
        """
        {\(restrictions),"reportId":"\(reportID)","ticker":"\(ticker)",
        "modelId":"recorded_model","modelReferences":{},
        "positions":[],"realizedNetPnl":null,"valuation":null,
        "unavailable":{"realizedNetPnl":"ticker_realized_pnl_not_recorded"},
        "timeline":[\(evidence)],"total":1,"offset":\(offset),"limit":10}
        """
    }

    func testDecodesSourceEvidenceWithoutInventingTerminalOrRealizedValue() throws {
        let page = try JSONDecoder().decode(HistoricalPortfolioTradesPage.self, from: Data(tradesPage().utf8))
        try page.validate(reportID: reportID, ticker: nil, offset: 0)
        XCTAssertEqual(page.items.first?.classification, "no_order")
        XCTAssertNil(page.items.first?.terminalStatus)
        XCTAssertEqual(page.items.first?.evidence.unavailable?["signal_status"], "aggregate_signal_status_not_recorded")

        let ticker = try JSONDecoder().decode(HistoricalPortfolioTickerPage.self, from: Data(tickerPage().utf8))
        try ticker.validate(reportID: reportID, ticker: "005930", offset: 0)
        XCTAssertNil(ticker.realizedNetPnl)
        XCTAssertEqual(ticker.unavailable["realizedNetPnl"], "ticker_realized_pnl_not_recorded")
    }

    func testRejectsTradeSourceMismatchAndUnsupportedClassifications() throws {
        let wrongReport = try JSONDecoder().decode(HistoricalPortfolioTradesPage.self, from: Data(tradesPage(reportID: String(repeating: "c", count: 64)).utf8))
        XCTAssertThrowsError(try wrongReport.validate(reportID: reportID, ticker: nil, offset: 0))

        let invalidCategory = try JSONDecoder().decode(HistoricalPortfolioTradesPage.self, from: Data(tradesPage(classification: "live_trade").utf8))
        XCTAssertThrowsError(try invalidCategory.validate(reportID: reportID, ticker: nil, offset: 0))

        let wrongTicker = try JSONDecoder().decode(HistoricalPortfolioTradesPage.self, from: Data(tradesPage().utf8))
        XCTAssertThrowsError(try wrongTicker.validate(reportID: reportID, ticker: "000660", offset: 0))
    }

    func testTickerPageRejectsInvalidPaginationAndTickerMismatch() throws {
        let wrongOffset = try JSONDecoder().decode(HistoricalPortfolioTickerPage.self, from: Data(tickerPage(offset: 10).utf8))
        XCTAssertThrowsError(try wrongOffset.validate(reportID: reportID, ticker: "005930", offset: 0))

        let wrongIdentity = try JSONDecoder().decode(HistoricalPortfolioTickerPage.self, from: Data(tickerPage(ticker: "000660").utf8))
        XCTAssertThrowsError(try wrongIdentity.validate(reportID: reportID, ticker: "005930", offset: 0))
    }

    func testRemoteURLsAndUnsafeQueryValuesCannotRequestTimelines() async throws {
        let remote = try HTTPHistoricalPortfolioSource(client: ResearchAPIClient(baseURL: URL(string: "https://example.test")!))
        do {
            _ = try await remote.getTrades(reportID: reportID, ticker: nil, offset: 0)
            XCTFail("Remote archive requests must fail")
        } catch ResearchAPIError.invalidConfiguration {}

        let local = try HTTPHistoricalPortfolioSource(client: ResearchAPIClient(baseURL: URL(string: "http://127.0.0.1:8877")!))
        do {
            _ = try await local.getTicker(reportID: reportID, ticker: "../bad", offset: 0)
            XCTFail("Unsafe ticker must fail")
        } catch ResearchAPIError.invalidConfiguration {}
        do {
            _ = try await local.getTrades(reportID: reportID, ticker: nil, offset: -1)
            XCTFail("Invalid pagination must fail")
        } catch ResearchAPIError.invalidConfiguration {}
    }
}
