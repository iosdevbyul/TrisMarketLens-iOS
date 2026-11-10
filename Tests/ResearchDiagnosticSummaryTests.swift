import XCTest
@testable import TrisMarketLens

final class ResearchDiagnosticSummaryTests: XCTestCase {
    private let reachable = ResearchConnectionReport(
        state: .reachable, detail: "Private endpoint: https://private.example.test?token=secret"
    )

    private func endpoint(_ path: String, _ state: ResearchEndpointState, detail: String = "") -> ResearchEndpointResult {
        .init(name: "Example", path: path, state: state, detail: detail)
    }

    func testNoChecksRemainNotCheckedAndNeverClaimApproval() {
        let report = ResearchDiagnosticSummary.render(connection: .notConfigured, results: [])
        XCTAssertTrue(report.contains("Required API status: Not checked"))
        XCTAssertTrue(report.contains("NOT VERIFIED"))
        XCTAssertTrue(report.contains("NOT GRANTED"))
        XCTAssertFalse(report.contains("Routes responding: 1 /"))
    }

    func testCompleteRouteResponsesStillDoNotGrantRelease() {
        let routes = ResearchReleasePreflight.requiredPaths.sorted().map {
            endpoint($0, .available)
        }
        let report = ResearchDiagnosticSummary.render(connection: reachable, results: routes)
        XCTAssertTrue(report.contains("Required routes not responding: 0"))
        XCTAssertTrue(report.contains("Routes responding: \(routes.count) / \(routes.count)"))
        XCTAssertTrue(report.contains("release not approved"))
        XCTAssertTrue(report.contains("Live collection and trading approval: NOT GRANTED"))
    }

    func testMissingAndIncompatibleRoutesRemainExplicitBlockers() {
        let routes = [
            endpoint("/api/v1/stocks", .available),
            endpoint("/api/v1/project/status", .incompatible),
        ]
        let report = ResearchDiagnosticSummary.render(connection: reachable, results: routes)
        XCTAssertTrue(report.contains("/api/v1/project/status: Incompatible"))
        XCTAssertTrue(report.contains("Required routes not responding:"))
        XCTAssertTrue(report.contains("/api/v1/models"))
    }

    func testOutputIsDeterministicAndExcludesPrivateDetails() {
        let secret = "Bearer confidential-token private.example.test"
        let routes = [
            endpoint("/api/v1/stocks", .available, detail: secret),
            endpoint("/api/v1/evidence", .notConfigured, detail: secret),
        ]
        let left = ResearchDiagnosticSummary.render(connection: reachable, results: routes)
        let right = ResearchDiagnosticSummary.render(connection: reachable, results: routes.reversed())
        XCTAssertEqual(left, right)
        XCTAssertFalse(left.contains("private.example.test"))
        XCTAssertFalse(left.contains("confidential-token"))
        XCTAssertFalse(left.contains("token=secret"))
        XCTAssertTrue(left.contains("/api/v1/evidence: Not configured"))
    }

    func testUnexpectedPrivateRouteCannotBeSharedVerbatim() {
        let report = ResearchDiagnosticSummary.render(connection: reachable, results: [
            endpoint("https://internal.example.test/?api_key=secret", .available)
        ])
        XCTAssertTrue(report.contains("[unrecognized route]"))
        XCTAssertFalse(report.contains("api_key"))
        XCTAssertFalse(report.contains("internal.example.test"))
    }
}
