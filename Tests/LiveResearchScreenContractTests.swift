import Foundation
import XCTest
@testable import TrisMarketLens

/// Offline payload contracts based on DonghakStockVision's FastAPI response models.
/// These fixtures are NOT live server responses or investment research results.
final class LiveResearchScreenContractTests: XCTestCase {
    func testOverviewSnapshotNestedFieldsAndResearchStates() throws {
        let json = """
        {"productName":"DonghakStockVision","sourceLabel":"Read-only snapshot",
         "metrics":[{"label":"Universe","value":"993","detail":"Published coverage"}],
         "evidence":[{"label":"Calendar","state":"verified","detail":"Reviewed"}],
         "baseline":[{"label":"Baseline","state":"blocked","detail":"Not executed"}]}
        """
        let status = try JSONDecoder().decode(ProjectStatus.self, from: Data(json.utf8))
        XCTAssertEqual(status.metrics.first?.detail, "Published coverage")
        XCTAssertEqual(status.evidence.first?.state, .verified)
        XCTAssertEqual(status.baseline.first?.state, .blocked)
    }

    func testModelsListAndFullModelDetailsDecode() throws {
        let list = """
        [{"id":"up","direction":"Up","modelName":"HGB","role":"research_only",
          "validationAveragePrecision":0.35,"oosAveragePrecision":0.31,"note":"Research only"}]
        """
        let models = try JSONDecoder().decode([ModelSummary].self, from: Data(list.utf8))
        XCTAssertEqual(models.first?.id, "up")

        let detail = """
        {"id":"up","direction":"Up","modelName":"HGB","role":"research_only",
         "validationAveragePrecision":0.35,"oosAveragePrecision":0.31,"note":"Research only",
         "selectionMeanAveragePrecision":0.34,"selectionStdAveragePrecision":0.01,
         "validation":{"sampleCount":100,"precision":0.5,"recall":0.4,"f1":0.44,"averagePrecision":0.35,"brier":0.2},
         "oos":{"sampleCount":40,"precision":0.4,"recall":0.3,"f1":0.34,"averagePrecision":0.31,"brier":0.21},
         "provenance":{"artifactSha256":"abc","featureSet":"v1","label":"up",
           "horizonSessions":5,"threshold":0.5,"maxLeafNodes":31,"learningRate":0.1,
           "maxIterations":100,"minSamplesLeaf":20,"l2Regularization":0,
           "maxBins":255,"classWeight":"balanced","earlyStopping":true,"randomSeed":42}}
        """
        let model = try JSONDecoder().decode(ModelDetail.self, from: Data(detail.utf8))
        XCTAssertEqual(model.provenance.horizonSessions, 5)
        XCTAssertEqual(model.oos.sampleCount, 40)
    }

    func testEvidenceDetailNullableProvenanceAndBlockedState() throws {
        let json = """
        {"id":"calendar","title":"Calendar","state":"blocked","summary":"Review pending",
         "sourceLabel":"KRX","metrics":[{"label":"Rows","value":"0","detail":"Not published"}],
         "findings":[],"blocker":"Pending review","fingerprint":null,"sourceScope":"KOSPI"}
        """
        let detail = try JSONDecoder().decode(EvidenceDetail.self, from: Data(json.utf8))
        XCTAssertEqual(detail.state, .blocked)
        XCTAssertNil(detail.fingerprint)
        XCTAssertEqual(detail.metrics.first?.detail, "Not published")
    }

    func testBacktestBaselineExplicitlyHasNoPerformance() throws {
        let json = """
        {"id":"baseline","title":"Baseline","state":"blocked","summary":"Not executed",
         "readiness":[{"label":"Policy","state":"blocked","detail":"Unverified"}],
         "timeline":[{"label":"Start","value":"Pending","detail":"No run initiated"}],
         "policyGroups":[{"title":"Risk","rules":[{"label":"Exposure","value":"Locked","detail":"Policy only"}]}],
         "fingerprints":[{"label":"Policy hash","value":"abc"}],"performanceAvailable":false}
        """
        let baseline = try JSONDecoder().decode(BaselineBacktestSnapshot.self, from: Data(json.utf8))
        XCTAssertFalse(baseline.performanceAvailable)
        XCTAssertEqual(baseline.readiness.first?.state, .blocked)
        XCTAssertEqual(baseline.timeline.first?.detail, "No run initiated")
    }

    func testContractRejectsMissingNestedRequiredField() {
        let incomplete = """
        {"productName":"DonghakStockVision","sourceLabel":"Source",
         "metrics":[{"label":"Universe","value":"993"}],"evidence":[],"baseline":[]}
        """
        XCTAssertThrowsError(try JSONDecoder().decode(ProjectStatus.self, from: Data(incomplete.utf8)))
    }
}
