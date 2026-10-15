import XCTest
import Foundation
import NetworkKit
@testable import TrisMarketLens

final class OperationsV1Tests: XCTestCase {
    private let runs = """
    {"schemaVersion":"operations_v1","items":[{"id":"batch-0001","operationType":"dart_batch_acquisition",
    "startedAt":null,"completedAt":null,"executionStatus":"completed","evidenceStatus":"validated",
    "recordCount":25,"sourceType":"dart_ledger","semanticApproval":false,"blockingStatus":null,"diagnostic":null}],
    "total":1,"offset":0,"limit":25,"evidenceStatus":"validated","diagnostic":null}
    """
    private let freshness = """
    {"schemaVersion":"operations_v1","items":[{"sourceId":"market_snapshot",
    "latestVerifiedDataAt":null,"latestSuccessfulIngestionAt":null,"latestDataDate":"2026-10-01",
    "recordCount":1099255,"thresholdSeconds":null,
    "blockingReason":"timestamp_and_freshness_policy_unavailable","freshnessBasis":"unavailable",
    "freshnessStatus":"unknown","evidenceStatus":"partial"}]}
    """
    private let alerts = """
    {"schemaVersion":"operations_v1","items":[{"id":"corporate-actions","category":"pipeline_blocked",
    "severity":"error","basis":"recorded","sourceId":"corporate-actions",
    "diagnostic":"snapshot_pipeline_blocked","occurredAt":null,
    "verifiedCount":0,"requiredCount":993,"blockingStatus":"blocked"}],
    "total":1,"offset":0,"limit":25}
    """

    func testExactBackendExamplesDecodeAndPreserveNulls() throws {
        let run = try JSONDecoder().decode(OperationsRunsPage.self, from: Data(runs.utf8))
        try run.validate(requestedOffset: 0, requestedLimit: 25)
        XCTAssertNil(run.items[0].startedAt)
        XCTAssertFalse(run.items[0].semanticApproval)
        XCTAssertEqual(run.items[0].id, "batch-0001")
        let fresh = try JSONDecoder().decode(OperationsFreshnessResponse.self, from: Data(freshness.utf8))
        try fresh.validate()
        XCTAssertNil(fresh.items[0].latestSuccessfulIngestionAt)
        XCTAssertEqual(fresh.items[0].latestDataDate, "2026-10-01")
        XCTAssertEqual(fresh.items[0].freshnessStatus, "unknown")
        XCTAssertEqual(fresh.items[0].evidenceStatus, "partial")
        let alert = try JSONDecoder().decode(OperationsAlertsPage.self, from: Data(alerts.utf8))
        try alert.validate(requestedOffset: 0, requestedLimit: 25)
        XCTAssertEqual(alert.items[0].verifiedCount, 0)
        XCTAssertEqual(alert.items[0].requiredCount, 993)
        XCTAssertEqual(alert.items[0].basis, "recorded")
        XCTAssertNil(alert.items[0].occurredAt)
    }

    func testUnknownValuesAreNotReportedAsSuccess() throws {
        let json = runs.replacingOccurrences(of: "\"validated\"", with: "\"future_status\"")
        let page = try JSONDecoder().decode(OperationsRunsPage.self, from: Data(json.utf8))
        XCTAssertTrue(OperationsPresentation.title(page.items[0].evidenceStatus).contains("Unrecognized"))
        XCTAssertEqual(OperationsPresentation.title("partial"), "Partial evidence")
        XCTAssertEqual(OperationsPresentation.title("unknown"), "Unknown")
        XCTAssertEqual(OperationsPresentation.title("advisory"), "Advisory")
        XCTAssertEqual(OperationsPresentation.title("recorded"), "Recorded incident")
        XCTAssertTrue(OperationsPresentation.diagnostic("dart_evidence_busy").contains("temporarily"))
        XCTAssertEqual(OperationsPresentation.timestamp(nil), "Not available")
    }

    func testSchemaAndPaginationRejectUnsupportedValues() throws {
        let other = runs.replacingOccurrences(of: "operations_v1", with: "operations_v2")
        let decoded = try JSONDecoder().decode(OperationsRunsPage.self, from: Data(other.utf8))
        XCTAssertThrowsError(try decoded.validate(requestedOffset: 0, requestedLimit: 25))
        let page = try JSONDecoder().decode(OperationsRunsPage.self, from: Data(runs.utf8))
        XCTAssertThrowsError(try page.validate(requestedOffset: 25, requestedLimit: 25))
        let invalid = try JSONDecoder().decode(OperationsFreshnessResponse.self,
            from: Data(freshness.replacingOccurrences(of: "operations_v1", with: "v2").utf8))
        XCTAssertThrowsError(try invalid.validate())
    }

    func testIndependentEndpointFailureAndNetworkRetry() async throws {
        let network = OperationsScriptClient(runs: Data(runs.utf8), freshness: Data(freshness.utf8), alerts: Data(alerts.utf8))
        let client = try ResearchAPIClient(baseURL: URL(string: "https://example.test")!, networkClient: network)
        let source = HTTPOperationsV1Source(client: client)
        let first = try await source.getRuns(offset: 0, limit: 25)
        XCTAssertEqual(first.items.count, 1)
        do {
            _ = try await source.getFreshness()
            XCTFail("Expected first freshness attempt to fail")
        } catch ResearchAPIError.transport {}
        let retry = try await source.getFreshness()
        XCTAssertEqual(retry.items.first?.sourceId, "market_snapshot")
        let alertPage = try await source.getAlerts(offset: 0, limit: 25)
        XCTAssertEqual(alertPage.items.first?.id, "corporate-actions")
        let attempts = await network.freshnessAttempts
        XCTAssertEqual(attempts, 2)
    }

    func testBoundedRequestRejectedBeforeNetworkCall() async throws {
        let network = OperationsScriptClient(runs: Data(runs.utf8), freshness: Data(freshness.utf8), alerts: Data(alerts.utf8))
        let client = try ResearchAPIClient(baseURL: URL(string: "https://example.test")!, networkClient: network)
        do {
            _ = try await HTTPOperationsV1Source(client: client).getRuns(offset: -1, limit: 101)
            XCTFail("Expected invalid pagination")
        } catch OperationsContractError.invalidPagination {}
    }

    func testOperationsPresentationUsesFriendlySourceNamesAndFreshnessSemantics() {
        XCTAssertEqual(OperationsPresentation.title("corporate-actions"), "Corporate Actions")
        XCTAssertEqual(OperationsPresentation.title("runner-tail"), "Runner Tail")
        XCTAssertEqual(OperationsPresentation.title("run-input-freeze"), "Run Input Freeze")
        XCTAssertEqual(OperationsPresentation.freshnessBasis("unavailable"), "Freshness policy unavailable")
        XCTAssertEqual(OperationsPresentation.freshnessBasis("acquisition_age"), "Acquisition age")
        XCTAssertTrue(OperationsPresentation.diagnostic("freshness_policy_or_timestamp_unavailable").contains("policy"))
        XCTAssertTrue(OperationsPresentation.diagnostic("acquisition_timestamp_or_policy_unavailable").contains("acquisition"))
    }

    func testOperationsTimestampsAreLocalizedWithoutInventingNullDates() {
        let utc = TimeZone(secondsFromGMT: 0)!
        let korea = TimeZone(secondsFromGMT: 9 * 3600)!
        let timestamp = "2026-10-14T05:26:22.811769Z"
        let utcValue = OperationsPresentation.timestamp(timestamp, timeZone: utc)
        let koreanValue = OperationsPresentation.timestamp(timestamp, timeZone: korea)
        XCTAssertNotEqual(utcValue, koreanValue)
        XCTAssertTrue(utcValue.contains("05:26:22") || utcValue.contains("5:26:22"))
        XCTAssertEqual(OperationsPresentation.timestamp(nil), "Not available")
        XCTAssertEqual(OperationsPresentation.timestamp("bad timestamp"), "Invalid timestamp")
    }

    func testMalformedJSONFailsClosed() {
        XCTAssertThrowsError(try JSONDecoder().decode(OperationsAlertsPage.self, from: Data("{".utf8)))
    }
}

private actor OperationsScriptClient: NetworkClient {
    let runs: Data
    let freshness: Data
    let alerts: Data
    private(set) var freshnessAttempts = 0

    init(runs: Data, freshness: Data, alerts: Data) {
        self.runs = runs
        self.freshness = freshness
        self.alerts = alerts
    }

    func request<T: Decodable>(endpoint: any Endpoint, responseType: T.Type) async throws -> T {
        let data: Data
        if endpoint.path.hasSuffix("/runs") { data = runs }
        else if endpoint.path.hasSuffix("/alerts") { data = alerts }
        else if endpoint.path.hasSuffix("/freshness") {
            freshnessAttempts += 1
            if freshnessAttempts == 1 { throw NetworkError.unknown(URLError(.timedOut)) }
            data = freshness
        } else { throw NetworkError.serverError(404) }
        return try JSONDecoder().decode(T.self, from: data)
    }
}
