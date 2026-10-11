import XCTest
@testable import TrisMarketLens

final class BacktestingOperationsTests: XCTestCase {
    func testDisconnectedStateDoesNotClaimSuccessfulRuns() async throws {
        let source = DisconnectedBacktestingOperationsSource()
        let baseline = try await source.getBaseline()
        let operations = try await source.getOperations()
        XCTAssertNil(baseline)
        XCTAssertEqual(operations.connection, "not_connected")
        XCTAssertTrue(operations.runs.isEmpty)
    }

    func testOperationsResponseContract() throws {
        let json = #"{"connection":"connected","checkedAt":null,"latestDataThrough":"2026-10-01","nextScheduledRun":null,"runs":[{"id":"r1","pipeline":"daily","state":"succeeded","startedAt":null,"finishedAt":null,"dataThrough":"2026-10-01","summary":null}]}"#
        let decoded = try JSONDecoder().decode(OperationsSnapshot.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.runs.first?.state, "succeeded")
    }

    func testBlockedBaselineContractDoesNotInventPerformance() throws {
        let json = #"{"id":"baseline","title":"Baseline","state":"blocked","summary":"Pending","readiness":[],"timeline":[],"policyGroups":[],"fingerprints":[],"performanceAvailable":false}"#
        let decoded = try JSONDecoder().decode(BaselineBacktestSnapshot.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.state, .blocked)
        XCTAssertFalse(decoded.performanceAvailable)
    }
    func testRunHistoryOrdersLatestFirstAndMissingStartLast() {
        let snapshot = OperationsSnapshot(
            connection: "connected", checkedAt: nil,
            latestDataThrough: nil, nextScheduledRun: nil,
            runs: [
                .init(id: "unknown", pipeline: "daily", state: "pending", startedAt: nil, finishedAt: nil, dataThrough: nil, summary: nil),
                .init(id: "old", pipeline: "daily", state: "succeeded", startedAt: "2026-10-01T00:00:00Z", finishedAt: nil, dataThrough: nil, summary: nil),
                .init(id: "b", pipeline: "daily", state: "succeeded", startedAt: "2026-10-10T00:00:00Z", finishedAt: nil, dataThrough: nil, summary: nil),
                .init(id: "a", pipeline: "daily", state: "running", startedAt: "2026-10-10T00:00:00Z", finishedAt: nil, dataThrough: nil, summary: nil)
            ]
        )
        XCTAssertEqual(snapshot.newestRunsFirst.map(\.id), ["a", "b", "old", "unknown"])
    }

    func testEmptyRunHistoryRemainsEmpty() {
        XCTAssertTrue(OperationsSnapshot.disconnected.newestRunsFirst.isEmpty)
    }

}
