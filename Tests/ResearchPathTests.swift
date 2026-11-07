import XCTest
@testable import TrisMarketLens

final class ResearchPathTests: XCTestCase {
    func testUnpublishedCollectionAndPortfolioNeverLookSuccessful() {
        let snapshot = ResearchPathSnapshot(
            stockCount: 10, modelCount: 2, analysisCount: 1,
            evidenceCount: 3, operationsCount: 4
        )
        XCTAssertEqual(snapshot.status(for: .collection, isHTTP: true, hasTicker: true), .unavailable)
        XCTAssertEqual(snapshot.status(for: .portfolio, isHTTP: true, hasTicker: true), .unavailable)
        XCTAssertEqual(snapshot.status(for: .identity, isHTTP: true, hasTicker: false), .observed)
        XCTAssertEqual(snapshot.status(for: .models, isHTTP: true, hasTicker: false), .observed)
        XCTAssertEqual(snapshot.status(for: .analysis, isHTTP: true, hasTicker: true), .observed)
        XCTAssertEqual(snapshot.status(for: .validation, isHTTP: true, hasTicker: true), .observed)
        XCTAssertEqual(snapshot.status(for: .operations, isHTTP: true, hasTicker: true), .observed)
    }

    func testDemoCannotCertifyAnySource() {
        let snapshot = ResearchPathSnapshot(stockCount: 4, modelCount: 2, analysisCount: 1, evidenceCount: 2, operationsCount: 1)
        for stage in ResearchPathStage.allCases {
            XCTAssertEqual(snapshot.status(for: stage, isHTTP: false, hasTicker: true), .demo)
        }
    }

    func testEmptyUnconfiguredAndBlockedStatesStayDistinct() {
        var snapshot = ResearchPathSnapshot(stockCount: 0, modelCount: 0, evidenceCount: 0, operationsCount: 0)
        XCTAssertEqual(snapshot.status(for: .identity, isHTTP: true, hasTicker: false), .empty)
        XCTAssertEqual(snapshot.status(for: .models, isHTTP: true, hasTicker: false), .empty)
        XCTAssertEqual(snapshot.status(for: .analysis, isHTTP: true, hasTicker: false), .unavailable)
        XCTAssertEqual(snapshot.status(for: .validation, isHTTP: true, hasTicker: true), .empty)
        snapshot.stockCount = 12
        snapshot.includesTicker = false
        snapshot.hasEvidenceBlockers = true
        XCTAssertEqual(snapshot.status(for: .identity, isHTTP: true, hasTicker: true), .blocked)
        XCTAssertEqual(snapshot.status(for: .validation, isHTTP: true, hasTicker: true), .blocked)
        snapshot.errorStages.insert(.models)
        XCTAssertEqual(snapshot.status(for: .models, isHTTP: true, hasTicker: true), .unavailable)
    }

    func testOperationsResponseIsNotSemanticApproval() {
        let snapshot = ResearchPathSnapshot(operationsCount: 1)
        XCTAssertEqual(snapshot.status(for: .operations, isHTTP: true, hasTicker: false), .observed)
        XCTAssertTrue(ResearchPathStage.operations.limitation.contains("does not establish semantic approval"))
    }

    func testStagesFollowCollectionToOperationsResearchOrder() {
        XCTAssertEqual(ResearchPathStage.allCases.map(\.rawValue), [
            "collection", "identity", "models", "analysis",
            "validation", "portfolio", "operations"
        ])
    }
}
