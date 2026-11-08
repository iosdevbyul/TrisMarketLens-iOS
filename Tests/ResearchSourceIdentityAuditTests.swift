import Foundation
import XCTest
@testable import TrisMarketLens

final class ResearchSourceIdentityAuditTests: XCTestCase {
    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try JSONDecoder().decode(type, from: Data(json.utf8))
    }

    private let hash = String(repeating: "a", count: 64)

    private func evidenceSummary() throws -> EvidenceLayerSummary {
        try decode(EvidenceLayerSummary.self, """
        {"id":"calendar","title":"Calendar","state":"in_progress",
        "summary":"Coverage pending","sourceLabel":"KRX"}
        """)
    }

    private func evidenceDetail(_ fingerprint: String?) throws -> EvidenceDetail {
        let hashJSON = fingerprint.map { "\"" + $0 + "\"" } ?? "null"
        return try decode(EvidenceDetail.self, """
        {"id":"calendar","title":"Calendar","state":"in_progress",
        "summary":"Coverage pending","sourceLabel":"KRX",
        "metrics":[],"findings":[],"blocker":"Unresolved",
        "fingerprint":\(hashJSON),"sourceScope":"Published research snapshot"}
        """)
    }

    func testPublishedEvidenceFingerprintNeverMeansAuthenticatedSource() throws {
        let result = ResearchSourceIdentityAudit.evidence(
            summary: try evidenceSummary(), detail: try evidenceDetail(hash)
        )
        XCTAssertEqual(result.state, .present)
        XCTAssertTrue(result.reason.contains("not obtained or hashed original bytes"))
        XCTAssertEqual(result.publishedFingerprint, hash)
    }

    func testMissingAndMalformedEvidenceFingerprintRemainUnavailable() throws {
        for fingerprint in [nil, "unknown", String(repeating: "A", count: 64)] as [String?] {
            let result = ResearchSourceIdentityAudit.evidence(
                summary: try evidenceSummary(), detail: try evidenceDetail(fingerprint)
            )
            XCTAssertEqual(result.state, .missing)
        }
    }

    func testMismatchedEvidenceIndexAndDetailFailClosed() throws {
        let source = try evidenceSummary()
        let wrong = try decode(EvidenceDetail.self, """
        {"id":"dart","title":"Calendar","state":"in_progress",
        "summary":"Coverage pending","sourceLabel":"KRX",
        "metrics":[],"findings":[],"blocker":null,
        "fingerprint":"\(hash)","sourceScope":"Published research snapshot"}
        """)
        let result = ResearchSourceIdentityAudit.evidence(summary: source, detail: wrong)
        XCTAssertEqual(result.state, .inconsistent)
    }

    func testMissingEvidenceDetailDoesNotBecomeEmptySuccess() throws {
        XCTAssertEqual(
            ResearchSourceIdentityAudit.evidence(summary: try evidenceSummary(), detail: nil).state,
            .missing
        )
    }

    func testModelDetailMissingAndMalformedFingerprintFailClosed() throws {
        let source = try decode(ModelSummary.self, """
        {"id":"up","direction":"Up","modelName":"HGB",
        "role":"research_only","validationAveragePrecision":0.3,
        "oosAveragePrecision":0.4,"note":"Synthetic"}
        """)
        XCTAssertEqual(ResearchSourceIdentityAudit.model(summary: source, detail: nil).state, .missing)
        let modelJSON = """
        {"id":"up","direction":"Up","modelName":"HGB","role":"research_only",
        "validationAveragePrecision":0.3,"oosAveragePrecision":0.4,"note":"Synthetic",
        "selectionMeanAveragePrecision":0.32,"selectionStdAveragePrecision":0.04,
        "validation":{"sampleCount":20,"precision":0.5,"recall":0.4,"f1":0.44,"averagePrecision":0.3,"brier":0.2},
        "oos":{"sampleCount":20,"precision":0.5,"recall":0.4,"f1":0.44,"averagePrecision":0.4,"brier":0.2},
        "provenance":{"artifactSha256":"\(hash)","featureSet":"study_v1","label":"direction",
        "horizonSessions":5,"threshold":0.5,"maxLeafNodes":10,"learningRate":0.1,
        "maxIterations":40,"minSamplesLeaf":5,"l2Regularization":0.0,"maxBins":255,
        "classWeight":"balanced","earlyStopping":false,"randomSeed":7}}
        """
        let detail = try decode(ModelDetail.self, modelJSON)
        let result = ResearchSourceIdentityAudit.model(summary: source, detail: detail)
        XCTAssertEqual(result.state, .present)
        XCTAssertTrue(result.reason.contains("not been independently verified"))
        let malformed = modelJSON.replacingOccurrences(of: hash, with: "not-a-hash")
        let invalid = try decode(ModelDetail.self, malformed)
        XCTAssertEqual(ResearchSourceIdentityAudit.model(summary: source, detail: invalid).state, .inconsistent)
    }

    func testSHA256ValidationIsStrict() {
        XCTAssertTrue(ResearchSourceIdentityAudit.validSHA256(hash))
        XCTAssertFalse(ResearchSourceIdentityAudit.validSHA256(hash.uppercased()))
        XCTAssertFalse(ResearchSourceIdentityAudit.validSHA256(String(repeating: "a", count: 63)))
        XCTAssertFalse(ResearchSourceIdentityAudit.validSHA256(String(repeating: "g", count: 64)))
    }
}
