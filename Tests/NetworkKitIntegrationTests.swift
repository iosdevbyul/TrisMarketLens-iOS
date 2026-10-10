import XCTest
import NetworkKit
@testable import TrisMarketLens

final class NetworkKitIntegrationTests: XCTestCase {
    func testSuccessfulResponseThroughNetworkClient() async throws {
        let client = try ResearchAPIClient(
            baseURL: URL(string: "https://example.test")!,
            networkClient: FixtureNetworkClient(mode: .success)
        )
        let payload = try await client.fetch(ProjectStatus.self, path: ["api", "v1", "project", "status"])
        XCTAssertEqual(payload.productName, "NetworkKit")
    }

    func testNetworkKitHTTPStatusMappingPreserves404() async throws {
        let client = try ResearchAPIClient(
            baseURL: URL(string: "https://example.test")!,
            networkClient: FixtureNetworkClient(mode: .missing)
        )
        let item = try await HTTPStockSource(client: client).getStock(ticker: "005930")
        XCTAssertNil(item)
    }

    func testNetworkKitDecodingFailureDoesNotFallBack() async throws {
        let client = try ResearchAPIClient(
            baseURL: URL(string: "https://example.test")!,
            networkClient: FixtureNetworkClient(mode: .invalidPayload)
        )
        do {
            _ = try await client.fetch(ProjectStatus.self, path: ["api", "v1", "project", "status"])
            XCTFail("Expected invalid payload")
        } catch ResearchAPIError.invalidPayload {}
    }
}

private struct FixtureNetworkClient: NetworkClient {
    enum Mode { case success, missing, invalidPayload }
    let mode: Mode

    func request<T: Decodable>(endpoint: any Endpoint, responseType: T.Type) async throws -> T {
        switch mode {
        case .missing: throw NetworkError.serverError(404)
        case .invalidPayload: throw NetworkError.decodingFailed(DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "fixture")))
        case .success:
            let json = #"{"productName":"NetworkKit","sourceLabel":"Test","metrics":[],"evidence":[],"baseline":[]}"#
            return try JSONDecoder().decode(T.self, from: Data(json.utf8))
        }
    }
}
