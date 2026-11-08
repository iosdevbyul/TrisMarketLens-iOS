import Foundation
import XCTest
@testable import TrisMarketLens

final class ResearchPublicationGateTests: XCTestCase {
    private func parse<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try JSONDecoder().decode(type, from: Data(json.utf8))
    }

    private var operational: OperationalMarketSummary {
        get throws {
            try parse(OperationalMarketSummary.self, """
            {"schemaVersion":"operational_snapshot_summary_v1","evidenceStatus":"unreviewed",
            "observationCount":1520,"tickerCount":25,"tradingDayCount":20,
            "firstTradingDate":"2026-09-01","lastTradingDate":"2026-10-01"}
            """)
        }
    }

    private var models: [ModelSummary] {
        get throws {
            try parse([ModelSummary].self, """
            [{"id":"up","direction":"up","modelName":"HGB","role":"research_only",
              "validationAveragePrecision":0.3,"oosAveragePrecision":0.4,"note":"Synthetic test"}]
            """)
        }
    }

    private var verifiedLayers: [EvidenceLayerSummary] {
        get throws {
            try parse([EvidenceLayerSummary].self, """
            [{"id":"calendar","title":"Calendar","state":"verified",
              "summary":"Synthetic test","sourceLabel":"Research snapshot"}]
            """)
        }
    }

    private var blockedLayers: [EvidenceLayerSummary] {
        get throws {
            try parse([EvidenceLayerSummary].self, """
            [{"id":"calendar","title":"Calendar","state":"in_progress",
              "summary":"Coverage incomplete","sourceLabel":"Research snapshot"}]
            """)
        }
    }

    private var completedRuns: OperationsRunsPage {
        get throws {
            try parse(OperationsRunsPage.self, """
            {"schemaVersion":"operations_v1","items":[{"id":"batch-0001",
              "operationType":"dart_batch_acquisition","startedAt":null,"completedAt":null,
              "executionStatus":"completed","evidenceStatus":"validated","recordCount":2,
              "sourceType":"dart_ledger","semanticApproval":false,
              "blockingStatus":null,"diagnostic":null}],
              "total":1,"offset":0,"limit":25,"evidenceStatus":"validated","diagnostic":null}
            """)
        }
    }

    func testEvenAllPresentedEvidenceCannotCreateApproval() throws {
        let gate = ResearchPublicationGate.evaluate(
            isHTTP: true, observations: try operational,
            evidenceLayers: try verifiedLayers, models: try models,
            runs: try completedRuns
        )
        XCTAssertEqual(gate.status, .insufficientEvidence)
        XCTAssertEqual(gate.checks.first(where: { $0.id == "authorization" })?.outcome, .unavailable)
        XCTAssertTrue(gate.checks.contains { $0.id == "operational" && $0.outcome == .unavailable })
        XCTAssertTrue(gate.checks.contains { $0.id == "operations" && $0.outcome == .observed })
    }

    func testUnreviewedCollectionCannotQualifyWithoutResearchProof() throws {
        let gate = ResearchPublicationGate.evaluate(
            isHTTP: true, observations: try operational,
            evidenceLayers: nil, models: nil, runs: nil
        )
        XCTAssertEqual(gate.status, .insufficientEvidence)
        XCTAssertEqual(gate.checks.first(where: { $0.id == "evidence" })?.outcome, .unavailable)
    }

    func testExplicitEvidenceBlockerCannotBeOverriddenByObservations() throws {
        let gate = ResearchPublicationGate.evaluate(
            isHTTP: true, observations: try operational,
            evidenceLayers: try blockedLayers, models: try models,
            runs: try completedRuns
        )
        XCTAssertEqual(gate.status, .blocked)
        XCTAssertEqual(gate.checks.first(where: { $0.id == "evidence" })?.outcome, .blocker)
    }

    func testFailedOperationCannotBeUpgradedToResearchApproval() throws {
        let json = """
        {"schemaVersion":"operations_v1","items":[{"id":"batch-0002",
          "operationType":"dart_batch_acquisition","startedAt":null,"completedAt":null,
          "executionStatus":"failed","evidenceStatus":"partial","recordCount":null,
          "sourceType":"dart_ledger","semanticApproval":false,
          "blockingStatus":"blocked","diagnostic":"acquisition_failure"}],
          "total":1,"offset":0,"limit":25,"evidenceStatus":"partial","diagnostic":null}
        """
        let runs = try parse(OperationsRunsPage.self, json)
        let gate = ResearchPublicationGate.evaluate(
            isHTTP: true, observations: try operational,
            evidenceLayers: try verifiedLayers, models: try models, runs: runs
        )
        XCTAssertEqual(gate.status, .blocked)
        XCTAssertEqual(gate.checks.first(where: { $0.id == "operations" })?.outcome, .blocker)
    }

    func testDisconnectedModeNeverReportsApproval() throws {
        let gate = ResearchPublicationGate.evaluate(
            isHTTP: false, observations: try operational,
            evidenceLayers: try verifiedLayers, models: try models,
            runs: try completedRuns
        )
        XCTAssertEqual(gate.status, .insufficientEvidence)
        XCTAssertEqual(gate.checks.count, 1)
        XCTAssertEqual(gate.checks[0].id, "transport")
    }
}
