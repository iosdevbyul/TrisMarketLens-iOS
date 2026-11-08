import Foundation
import XCTest
@testable import TrisMarketLens

final class HistoricalPortfolioComparisonTests: XCTestCase {
    private let idA = String(repeating: "a", count: 64)
    private let idB = String(repeating: "b", count: 64)

    private func report(_ id: String) -> String {
        """
        {"schemaVersion":"published_historical_portfolio_v1",
        "researchOnly":true,"operationalEligible":false,"executable":false,
        "pitVerified":false,"oosVerified":false,"investmentSuitabilityVerified":false,
        "brokerageEligible":false,"reportId":"\(id)","publishedAt":"2026-10-19T07:52:20Z",
        "modelFamily":"linear","modelId":"model","tickers":["000075","00088K","00104K","005930","035420"],
        "period":{"start":"2020-05-05","end":"2020-06-04"},
        "initialVirtualCash":"1500","finalTotalCash":"759.73","availableCash":"759.73",
        "reservedCash":"0","finalPortfolioEquity":null,"realizedNetPnl":"170.55",
        "unrealizedPnl":null,"portfolioReturn":null,"decisionCount":15,
        "acceptedOrderCount":3,"fillCount":3,"completedPositionCount":1,
        "pendingOrderCount":0,"portfolioValuationAvailable":false,
        "archiveTransportHash":"\(id)","resultHash":"\(id)",
        "reportHash":"\(id)","runHash":"\(id)","performanceHash":"\(id)",
        "evidenceScope":"synthetic_fixture","dataOrigin":"synthetic",
        "limitations":["not_live_trading"],"unavailable":{"portfolioReturn":"valuation_incomplete"},
        "archiveVerification":"integrity_verified",
        "reportVerification":"offline_authoritative_replay_passed",
        "tickerCount":5,"signalEvidenceScopes":["controlled_mechanics_test_double"],
        "valuationBasis":{"timestamp":null,"stage":null,"observedMarkFields":null,
        "policy":null,"unavailable":{"policy":"valuation_policy_not_in_published_projection"}}}
        """
    }

    private func comparison(_ ids: [String]) -> String {
        """
        {"schemaVersion":"historical_portfolio_comparison_v1",
        "researchOnly":true,"operationalEligible":false,"executable":false,
        "pitVerified":false,"oosVerified":false,"investmentSuitabilityVerified":false,
        "brokerageEligible":false,"items":[\(ids.map(report).joined(separator: ","))],
        "comparability":{"periodsDiffer":false,"valuationTimestampsDiffer":null,
        "observedMarkFieldsDiffer":null,"valuationPolicyComparison":"unavailable",
        "unavailable":{"policy":"valuation_policy_not_in_published_projection"},
        "notices":["no_ranking_or_recommendation","valuation_policy_not_in_published_projection"]}}
        """
    }

    func testSelectionRequiresTwoToFiveUniqueLowercaseHashes() throws {
        XCTAssertNoThrow(try HistoricalComparisonContract.validateSelection([idA, idB]))
        for selection in [[idA], [idA, idA], [idA, "invalid"], [String(repeating: "A", count: 64), idB]] {
            XCTAssertThrowsError(try HistoricalComparisonContract.validateSelection(selection))
        }
        XCTAssertThrowsError(try HistoricalComparisonContract.validateSelection(
            (0..<6).map { String(repeating: String($0), count: 64) }
        ))
    }

    func testComparisonPreservesNullableValuesAndMissingValuationPolicy() throws {
        let ids = [idA, idB]
        let result = try JSONDecoder().decode(HistoricalPortfolioComparison.self, from: Data(comparison(ids).utf8))
        try result.validate(selected: ids)
        XCTAssertNil(result.items[0].summary.portfolioReturn)
        XCTAssertNil(result.items[0].valuationBasis.timestamp)
        XCTAssertNil(result.items[0].valuationBasis.policy)
        XCTAssertEqual(result.comparability.valuationPolicyComparison, "unavailable")
    }

    func testResponseMustMatchSelectionOrderAndRestrictions() throws {
        let result = try JSONDecoder().decode(
            HistoricalPortfolioComparison.self, from: Data(comparison([idA, idB]).utf8)
        )
        XCTAssertThrowsError(try result.validate(selected: [idB, idA]))
        let invalid = comparison([idA, idB]).replacingOccurrences(
            of: "\"valuationPolicyComparison\":\"unavailable\"",
            with: "\"valuationPolicyComparison\":\"verified\""
        )
        let badPolicy = try JSONDecoder().decode(HistoricalPortfolioComparison.self, from: Data(invalid.utf8))
        XCTAssertThrowsError(try badPolicy.validate(selected: [idA, idB]))
        let executable = comparison([idA, idB]).replacingOccurrences(
            of: "\"executable\":false", with: "\"executable\":true"
        )
        let badEligibility = try JSONDecoder().decode(HistoricalPortfolioComparison.self, from: Data(executable.utf8))
        XCTAssertThrowsError(try badEligibility.validate(selected: [idA, idB]))
    }

    func testComparisonBlocksRemoteAndInvalidSelectionsBeforeNetwork() async throws {
        let remote = try HTTPHistoricalPortfolioSource(client: ResearchAPIClient(baseURL: URL(string: "https://example.test")!))
        do {
            _ = try await remote.compare(reportIDs: [idA, idB])
            XCTFail("Remote historical comparison must be blocked")
        } catch ResearchAPIError.invalidConfiguration {}

        let local = try HTTPHistoricalPortfolioSource(client: ResearchAPIClient(baseURL: URL(string: "http://127.0.0.1:8877")!))
        do {
            _ = try await local.compare(reportIDs: [idA, idA])
            XCTFail("Duplicate selections must fail")
        } catch ResearchAPIError.invalidConfiguration {}
    }
}
