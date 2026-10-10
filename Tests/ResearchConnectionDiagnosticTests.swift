import XCTest
import NetworkKit
@testable import TrisMarketLens

final class ResearchConnectionDiagnosticTests: XCTestCase {
    func testExpectedReadOnlyHealthIsReachable() async throws {
        let report = await ResearchConnectionDiagnostic(client: try client(#"{"status":"ok","service":"DonghakStockVision","mode":"read_only"}"#)).check()
        XCTAssertEqual(report.state, .reachable)
        XCTAssertTrue(report.detail.contains("not yet verified"))
    }

    func testUnexpectedServiceFailsClosed() async throws {
        let report = await ResearchConnectionDiagnostic(client: try client(#"{"status":"ok","service":"Other","mode":"read_only"}"#)).check()
        XCTAssertEqual(report.state, .incompatible)
    }

    func testUnhealthyStatusIsNotConnected() async throws {
        let report = await ResearchConnectionDiagnostic(client: try client(#"{"status":"error","service":"DonghakStockVision","mode":"read_only"}"#)).check()
        XCTAssertEqual(report.state, .unhealthy)
    }

    func testMalformedPayloadIsIncompatible() async throws {
        let report = await ResearchConnectionDiagnostic(client: try client(#"{"status":"ok"}"#)).check()
        XCTAssertEqual(report.state, .incompatible)
    }

    func testHTTP503DoesNotClaimConnectivity() async throws {
        let network = DiagnosticFixtureClient(payload: Data(), errorCode: 503)
        let api = try ResearchAPIClient(baseURL: URL(string: "https://example.test")!, networkClient: network)
        let report = await ResearchConnectionDiagnostic(client: api).check()
        XCTAssertEqual(report.state, .unavailable)
        XCTAssertTrue(report.detail.contains("503"))
    }

    private func client(_ json: String) throws -> ResearchAPIClient {
        try ResearchAPIClient(
            baseURL: URL(string: "https://example.test")!,
            networkClient: DiagnosticFixtureClient(payload: Data(json.utf8), errorCode: nil)
        )
    }
}

private struct DiagnosticFixtureClient: NetworkClient {
    let payload: Data
    let errorCode: Int?

    func request<T: Decodable>(endpoint: any Endpoint, responseType: T.Type) async throws -> T {
        guard endpoint.path == "api/v1/health", endpoint.method == .get else {
            throw NetworkError.invalidURL
        }
        if let errorCode { throw NetworkError.serverError(errorCode) }
        do {
            return try JSONDecoder().decode(T.self, from: payload)
        } catch {
            throw NetworkError.decodingFailed(error)
        }
    }
}
