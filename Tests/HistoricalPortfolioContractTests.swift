import Foundation
import XCTest
@testable import TrisMarketLens

final class HistoricalPortfolioContractTests: XCTestCase {
    private let reportHash = String(repeating: "a", count: 64)

    private func itemJSON() -> String {
        """
        {"reportId":"\(reportHash)","publishedAt":"2026-10-19T07:52:20Z","modelFamily":"linear",
        "tickers":["000075","00088K","00104K","005930","035420"],"period":{"start":"2020-05-05","end":"2020-06-04"},
        "initialVirtualCash":"1500","evidenceScope":"synthetic_fixture","portfolioValuationAvailable":true,
        "archiveVerification":"integrity_verified","reportVerification":"offline_authoritative_replay_passed",
        "researchOnly":true,"operationalEligible":false,"executable":false,"pitVerified":false,
        "oosVerified":false,"investmentSuitabilityVerified":false,"brokerageEligible":false}
        """
    }
    private func pageJSON() -> String {
        """
        {"schemaVersion":"published_historical_portfolio_v1","researchOnly":true,
        "operationalEligible":false,"executable":false,"pitVerified":false,"oosVerified":false,
        "investmentSuitabilityVerified":false,"brokerageEligible":false,
        "items":[\(itemJSON())],"total":1,"offset":0,"limit":10}
        """
    }
    private func summaryJSON() -> String {
        """
        {"schemaVersion":"published_historical_portfolio_v1","researchOnly":true,"operationalEligible":false,
        "executable":false,"pitVerified":false,"oosVerified":false,"investmentSuitabilityVerified":false,
        "brokerageEligible":false,"reportId":"\(reportHash)","publishedAt":"2026-10-19T07:52:20Z",
        "modelFamily":"linear","modelId":"model","tickers":["000075","00088K","00104K","005930","035420"],
        "period":{"start":"2020-05-05","end":"2020-06-04"},"initialVirtualCash":"1500",
        "finalTotalCash":"759.73","availableCash":"759.73","reservedCash":"0",
        "finalPortfolioEquity":null,"realizedNetPnl":"170.55","unrealizedPnl":null,
        "portfolioReturn":null,"decisionCount":15,"acceptedOrderCount":3,
        "fillCount":3,"completedPositionCount":1,"pendingOrderCount":0,
        "portfolioValuationAvailable":false,"archiveTransportHash":"\(reportHash)",
        "resultHash":"\(reportHash)","reportHash":"\(reportHash)","runHash":"\(reportHash)",
        "performanceHash":"\(reportHash)","evidenceScope":"synthetic_fixture",
        "dataOrigin":"synthetic","limitations":["not_live_trading"],
        "unavailable":{"portfolioReturn":"valuation_incomplete"},
        "archiveVerification":"integrity_verified","reportVerification":"offline_authoritative_replay_passed"}
        """
    }

    func testPagePreservesNullableFinancialMeaningAndRestrictions() throws {
        let page = try JSONDecoder().decode(HistoricalPortfolioPage.self, from: Data(pageJSON().utf8))
        try page.validate(offset: 0, limit: 10)
        XCTAssertEqual(page.items.first?.reportId, reportHash)
        XCTAssertEqual(page.items.first?.tickers[1], "00088K")

        let summary = try JSONDecoder().decode(HistoricalPortfolioSummary.self, from: Data(summaryJSON().utf8))
        try summary.validate(expectedReportID: reportHash)
        XCTAssertNil(summary.portfolioReturn)
        XCTAssertEqual(summary.unavailable["portfolioReturn"], "valuation_incomplete")
    }

    func testRejectsWrongPageVersionPaginationAndEligibility() throws {
        let original = pageJSON()
        let fixtures = [
            original.replacingOccurrences(of: "published_historical_portfolio_v1", with: "unknown_v2"),
            original.replacingOccurrences(of: "\"offset\":0", with: "\"offset\":12"),
            original.replacingOccurrences(of: "\"researchOnly\":true", with: "\"researchOnly\":false"),
            original.replacingOccurrences(of: "\"executable\":false", with: "\"executable\":true"),
            original.replacingOccurrences(of: "\"archiveVerification\":\"integrity_verified\"", with: "\"archiveVerification\":\"unverified\"")
        ]
        for fixture in fixtures {
            let page = try JSONDecoder().decode(HistoricalPortfolioPage.self, from: Data(fixture.utf8))
            XCTAssertThrowsError(try page.validate(offset: 0, limit: 10))
        }
    }

    func testRejectsUnsafeReportIdentifiersAndWrongSummaryIdentity() throws {
        for value in ["", "../" + reportHash, String(repeating: "A", count: 64), "abc", reportHash + "x"] {
            XCTAssertFalse(HistoricalPortfolioContract.validReportID(value))
        }
        let summary = try JSONDecoder().decode(HistoricalPortfolioSummary.self, from: Data(summaryJSON().utf8))
        XCTAssertThrowsError(try summary.validate(expectedReportID: String(repeating: "b", count: 64)))
    }

    func testRemoteOrInvalidRequestsFailBeforeTransport() async throws {
        let remote = try HTTPHistoricalPortfolioSource(client: ResearchAPIClient(baseURL: URL(string: "https://example.test")!))
        do {
            _ = try await remote.getPage(offset: 0)
            XCTFail("Remote access must not be attempted")
        } catch ResearchAPIError.invalidConfiguration {}
        do {
            _ = try await remote.getSummary(reportID: reportHash)
            XCTFail("Remote report access must not be attempted")
        } catch ResearchAPIError.invalidConfiguration {}
        let local = try HTTPHistoricalPortfolioSource(client: ResearchAPIClient(baseURL: URL(string: "http://127.0.0.1:8877")!))
        do {
            _ = try await local.getPage(offset: -1)
            XCTFail("Invalid pagination must not be attempted")
        } catch ResearchAPIError.invalidConfiguration {}
        do {
            _ = try await local.getSummary(reportID: "../bad")
            XCTFail("Invalid report ID must not be requested")
        } catch ResearchAPIError.invalidConfiguration {}
    }

    func testUnavailableSourceNeverSubstitutesDemoArchives() async throws {
        let source = UnavailableHistoricalPortfolioSource()
        do {
            _ = try await source.getPage(offset: 0)
            XCTFail("Disconnected source must fail")
        } catch ResearchAPIError.invalidConfiguration {}
    }
}
