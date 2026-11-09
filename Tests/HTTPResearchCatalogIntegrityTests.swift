import Foundation
import XCTest
import NetworkKit
@testable import TrisMarketLens

final class HTTPResearchCatalogIntegrityTests: XCTestCase {
    private func source(_ body: String) throws -> HTTPResearchCatalogSource {
        let api = try ResearchAPIClient(
            baseURL: URL(string: "https://research.example.test")!,
            networkClient: CatalogFixtureClient(body: Data(body.utf8))
        )
        return HTTPResearchCatalogSource(client: api)
    }

    func testModelListRejectsDuplicateIDsAndNonfiniteOrOutOfRangeMetrics() async throws {
        let valid = #"{"id":"up","direction":"Up","modelName":"HGB","role":"research_only","validationAveragePrecision":0.3,"oosAveragePrecision":0.4,"note":"Example"}"#
        let duplicate = "[\(valid),\(valid)]"
        let invalidMetric = valid.replacingOccurrences(of: #""oosAveragePrecision":0.4"#, with: #""oosAveragePrecision":1.3"#)
        for body in [duplicate, "[\(invalidMetric)]"] {
            do {
                _ = try await source(body).getModels()
                XCTFail("Malformed models must not reach the UI")
            } catch ResearchAPIError.invalidPayload { }
        }
        let models = try await source("[\(valid)]").getModels()
        XCTAssertEqual(models.map(\.id), ["up"])
    }

    func testEvidenceListRejectsDuplicateIDsAndBlankTitles() async throws {
        let valid = #"{"id":"calendar","title":"Calendar","state":"blocked","summary":"Pending","sourceLabel":"Source"}"#
        let blank = valid.replacingOccurrences(of: #""title":"Calendar""#, with: #""title":" ""#)
        for body in ["[\(valid),\(valid)]", "[\(blank)]"] {
            do {
                _ = try await source(body).getEvidenceLayers()
                XCTFail("Malformed evidence layers must not reach the UI")
            } catch ResearchAPIError.invalidPayload { }
        }
        let layers = try await source("[\(valid)]").getEvidenceLayers()
        XCTAssertEqual(layers.count, 1)
    }

    func testEvidenceDetailRejectsMismatchedIDAndDuplicateMetricLabels() async throws {
        let valid = #"{"id":"calendar","title":"Calendar","state":"blocked","summary":"Pending","sourceLabel":"Source","metrics":[],"findings":[],"blocker":null,"fingerprint":null,"sourceScope":"Market"}"#
        let wrong = valid.replacingOccurrences(of: #""id":"calendar""#, with: #""id":"other""#)
        let duplicated = valid.replacingOccurrences(of: #""metrics":[]"#, with: #""metrics":[{"label":"A","value":"1","detail":""},{"label":"A","value":"2","detail":""}]"#)
        for body in [wrong, duplicated] {
            do {
                _ = try await source(body).getEvidenceLayer(id: "calendar")
                XCTFail("Malformed detail must not reach the UI")
            } catch ResearchAPIError.invalidPayload { }
        }
        let detail = try await source(valid).getEvidenceLayer(id: "calendar")
        XCTAssertEqual(detail?.state, .blocked)
    }

    func testEmptyCatalogsStayEmptyWithoutFabricatedResearch() async throws {
        let models = try await source("[]").getModels()
        let layers = try await source("[]").getEvidenceLayers()
        XCTAssertTrue(models.isEmpty)
        XCTAssertTrue(layers.isEmpty)
    }
}

private struct CatalogFixtureClient: NetworkClient {
    let body: Data
    func request<T: Decodable>(endpoint: any Endpoint, responseType: T.Type) async throws -> T {
        try JSONDecoder().decode(T.self, from: body)
    }
}
