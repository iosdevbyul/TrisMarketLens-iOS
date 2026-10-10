import XCTest
@testable import TrisMarketLens

final class ResearchCatalogTests: XCTestCase {
    func testResearchCatalogStartsDisconnected() async throws {
        let source = DisconnectedResearchCatalogSource()
        let models = try await source.getModels()
        let evidence = try await source.getEvidenceLayers()
        XCTAssertTrue(models.isEmpty)
        XCTAssertTrue(evidence.isEmpty)
        let model = try await source.getModel(id: "up")
        let layer = try await source.getEvidenceLayer(id: "calendar")
        XCTAssertNil(model)
        XCTAssertNil(layer)
    }

    func testEvidenceStateAndNullableBlockerDecode() throws {
        let data = Data(#"{"id":"calendar","title":"Calendar","state":"in_progress","summary":"Pending","sourceLabel":"KRX","metrics":[],"findings":[],"blocker":null,"fingerprint":null,"sourceScope":"Market"}"#.utf8)
        let detail = try JSONDecoder().decode(EvidenceDetail.self, from: data)
        XCTAssertEqual(detail.state, .inProgress)
        XCTAssertNil(detail.blocker)
    }

    func testModelSummaryMatchesWebResponse() throws {
        let data = Data(#"{"id":"up","direction":"Up","modelName":"HGB","role":"research_only","validationAveragePrecision":0.3,"oosAveragePrecision":0.4,"note":"Example"}"#.utf8)
        let model = try JSONDecoder().decode(ModelSummary.self, from: data)
        XCTAssertEqual(model.id, "up")
        XCTAssertEqual(model.oosAveragePrecision, 0.4)
    }
}
