import Foundation
import XCTest
import NetworkKit
@testable import TrisMarketLens

final class HTTPBaselineIntegrityTests: XCTestCase {
    private let valid = #"{"id":"baseline","title":"Baseline","state":"blocked","summary":"Pending","readiness":[{"label":"Source","state":"blocked","detail":"Unavailable"}],"timeline":[],"policyGroups":[{"title":"Policy","rules":[{"label":"Horizon","value":"10","detail":"Sessions"}]}],"fingerprints":[{"label":"Source hash","value":"unavailable"}],"performanceAvailable":false}"#

    private func source(_ body: String) throws -> HTTPBacktestingOperationsSource {
        let api = try ResearchAPIClient(
            baseURL: URL(string: "https://research.example.test")!,
            networkClient: BaselineFixtureClient(body: Data(body.utf8))
        )
        return HTTPBacktestingOperationsSource(client: api)
    }

    func testValidBlockedBaselinePreservesUnavailablePerformance() async throws {
        let baseline = try await source(valid).getBaseline()
        XCTAssertEqual(baseline?.id, "baseline")
        XCTAssertEqual(baseline?.state, .blocked)
        XCTAssertEqual(baseline?.performanceAvailable, false)
    }

    func testEmptyBaselineCollectionsRemainValid() async throws {
        let body = #"{"id":"baseline","title":"Baseline","state":"not_started","summary":"Pending","readiness":[],"timeline":[],"policyGroups":[],"fingerprints":[],"performanceAvailable":false}"#
        let baseline = try await source(body).getBaseline()
        XCTAssertTrue(baseline?.readiness.isEmpty == true)
    }

    func testRejectsBlankIdentityAndRepeatedLabels() async throws {
        let variants = [
            valid.replacingOccurrences(of: #""title":"Baseline""#, with: #""title":" ""#),
            valid.replacingOccurrences(of: #""id":"baseline""#, with: #""id":"""#),
            valid.replacingOccurrences(
                of: #""readiness":[{"label":"Source","state":"blocked","detail":"Unavailable"}]"#,
                with: #""readiness":[{"label":"Source","state":"blocked","detail":"Unavailable"},{"label":"Source","state":"blocked","detail":"Unavailable"}]"#
            ),
            valid.replacingOccurrences(
                of: #""fingerprints":[{"label":"Source hash","value":"unavailable"}]"#,
                with: #""fingerprints":[{"label":"Source hash","value":"unavailable"},{"label":"Source hash","value":"unavailable"}]"#
            ),
            valid.replacingOccurrences(
                of: #""rules":[{"label":"Horizon","value":"10","detail":"Sessions"}]"#,
                with: #""rules":[{"label":"Horizon","value":"10","detail":"Sessions"},{"label":"Horizon","value":"10","detail":"Sessions"}]"#
            )
        ]
        for body in variants {
            do {
                _ = try await source(body).getBaseline()
                XCTFail("Invalid baseline must be rejected")
            } catch ResearchAPIError.invalidPayload { }
        }
    }

    func testRejectsOversizedCollections() throws {
        let item = BacktestTimelineItem(label: "Same", value: "Value", detail: "")
        let fixture = try JSONDecoder().decode(BaselineBacktestSnapshot.self, from: Data(valid.utf8))
        let oversized = BaselineBacktestSnapshot(
            id: fixture.id, title: fixture.title, state: fixture.state, summary: fixture.summary,
            readiness: fixture.readiness, timeline: Array(repeating: item, count: 101),
            policyGroups: fixture.policyGroups, fingerprints: fixture.fingerprints,
            performanceAvailable: fixture.performanceAvailable
        )
        XCTAssertFalse(BaselinePayloadValidation.validate(oversized))
    }
}

private struct BaselineFixtureClient: NetworkClient {
    let body: Data
    func request<T: Decodable>(endpoint: any Endpoint, responseType: T.Type) async throws -> T {
        try JSONDecoder().decode(T.self, from: body)
    }
}
