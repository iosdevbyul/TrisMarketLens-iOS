import Foundation
import XCTest
import NetworkKit
@testable import TrisMarketLens

final class ResearchEndpointDiagnosticTests: XCTestCase {
    func testUnavailableReadersDoNotCountAsSuccessfulEndpoints() async throws {
        let api = try ResearchAPIClient(
            baseURL: URL(string: "https://example.test")!,
            networkClient: EndpointFixtureClient()
        )
        let results = await ResearchEndpointDiagnostic(client: api).check()
        XCTAssertEqual(results.count, 8)
        XCTAssertEqual(results.first?.state, .notConfigured)
        XCTAssertEqual(results.first?.path, "/api/v1/project/status")
        XCTAssertEqual(results.last?.state, .missing)
        XCTAssertEqual(results.last?.path, "/api/v1/stocks/{ticker}/evaluations")
        XCTAssertFalse(results.contains { $0.state == .available })
    }
}

private struct EndpointFixtureClient: NetworkClient {
    func request<T: Decodable>(endpoint: any Endpoint, responseType: T.Type) async throws -> T {
        throw NetworkError.serverError(503)
    }
}
