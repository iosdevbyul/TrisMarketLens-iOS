import XCTest
@testable import TrisMarketLens

final class OperationsEvidenceTraceTests: XCTestCase {
    func testStagesRemainIndependentAndOrdered() {
        XCTAssertEqual(OperationsTraceStage.allCases.map(\.rawValue), [
            "execution", "freshness", "incidents", "researchPublication", "evidence"
        ])
    }

    func testDemoNeverCertifiesAnyPublishedSource() {
        let snapshot = OperationsTraceSnapshot(
            runCount: 3, runEvidenceStatus: "validated",
            freshnessCount: 2, alertCount: 0, alertTotal: 0,
            screenerCount: 4, evidenceCount: 5
        )
        for stage in OperationsTraceStage.allCases {
            XCTAssertEqual(snapshot.state(for: stage, isHTTP: false), .demonstration)
        }
    }

    func testEmptyAndUnavailableRemainDifferent() {
        var snapshot = OperationsTraceSnapshot(
            runCount: 0, freshnessCount: 0,
            alertCount: 0, alertTotal: 0, screenerCount: 0, evidenceCount: 0
        )
        for stage in OperationsTraceStage.allCases {
            XCTAssertEqual(snapshot.state(for: stage, isHTTP: true), .empty)
        }

        snapshot.alertTotal = nil
        XCTAssertEqual(snapshot.state(for: .incidents, isHTTP: true), .unavailable)
        snapshot.failures.insert(.researchPublication)
        XCTAssertEqual(snapshot.state(for: .researchPublication, isHTTP: true), .unavailable)
    }

    func testRecordedRunIsNotAutomaticApproval() {
        var snapshot = OperationsTraceSnapshot(
            runCount: 1, runEvidenceStatus: "validated", runsWithBlockers: 1
        )
        XCTAssertEqual(snapshot.state(for: .execution, isHTTP: true), .blocked)
        snapshot.runsWithBlockers = 0
        XCTAssertEqual(snapshot.state(for: .execution, isHTTP: true), .observed)
        XCTAssertTrue(OperationsTraceStage.execution.limitation.contains("not independent"))
    }

    func testIndependentResearchPublicationDoesNotCertifyOperations() {
        var snapshot = OperationsTraceSnapshot(
            runCount: nil, screenerCount: 10, evidenceCount: 3
        )
        XCTAssertEqual(snapshot.state(for: .execution, isHTTP: true), .unavailable)
        XCTAssertEqual(snapshot.state(for: .researchPublication, isHTTP: true), .observed)
        XCTAssertEqual(snapshot.state(for: .evidence, isHTTP: true), .observed)

        snapshot.evidenceWithBlockers = 1
        snapshot.freshnessCount = 1
        snapshot.freshnessWithBlockers = 1
        snapshot.alertCount = 1
        snapshot.alertTotal = 5
        XCTAssertEqual(snapshot.state(for: .evidence, isHTTP: true), .blocked)
        XCTAssertEqual(snapshot.state(for: .freshness, isHTTP: true), .blocked)
        XCTAssertEqual(snapshot.state(for: .incidents, isHTTP: true), .blocked)
    }
}
