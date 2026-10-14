import Foundation
import XCTest
import NetworkKit
@testable import TrisMarketLens

/// Exercises the app's real NetworkKit error mapping without contacting a live backend.
final class ResearchFailureRetryIntegrationTests: XCTestCase {
    func testStatusFailuresArePreservedWithoutFallback() async throws {
        for code in [404, 429, 503] {
            let client = try ResearchAPIClient(
                baseURL: URL(string: "https://example.test")!,
                networkClient: FailureScriptClient(outcomes: [.http(code)])
            )
            do {
                _ = try await client.fetch(ProjectStatus.self, path: ["api", "v1", "project", "status"])
                XCTFail("HTTP \\(code) must not become a successful snapshot")
            } catch ResearchAPIError.httpStatus(let status) {
                XCTAssertEqual(status, code)
            }
        }
    }

    func testTimeoutReportsTransportAndExplicitRetryCanRecover() async throws {
        let script = FailureScriptClient(outcomes: [.timeout, .success])
        let client = try ResearchAPIClient(
            baseURL: URL(string: "https://example.test")!,
            networkClient: script
        )

        do {
            _ = try await client.fetch(ProjectStatus.self, path: ["api", "v1", "project", "status"])
            XCTFail("Expected initial transport error")
        } catch ResearchAPIError.transport {
            XCTAssertTrue(ResearchErrorGuidance.message(for: ResearchAPIError.transport).contains("connection"))
        }

        let recovered = try await client.fetch(ProjectStatus.self, path: ["api", "v1", "project", "status"])
        XCTAssertEqual(recovered.productName, "Recovered")
        let count = await script.callCount
        XCTAssertEqual(count, 2, "Retry must be explicit, not an implicit second request")
    }

    func testMalformedResponseDoesNotBecomePublishedData() async throws {
        let client = try ResearchAPIClient(
            baseURL: URL(string: "https://example.test")!,
            networkClient: FailureScriptClient(outcomes: [.invalidPayload])
        )
        do {
            _ = try await client.fetch(ProjectStatus.self, path: ["api", "v1", "project", "status"])
            XCTFail("Malformed response must fail closed")
        } catch ResearchAPIError.invalidPayload {
            XCTAssertTrue(ResearchErrorGuidance.message(for: ResearchAPIError.invalidPayload).contains("No unverified results"))
        }
    }

    func testPathValidationRejectsTraversalWithoutCallingNetwork() async throws {
        let script = FailureScriptClient(outcomes: [.success])
        let client = try ResearchAPIClient(
            baseURL: URL(string: "https://example.test")!,
            networkClient: script
        )
        do {
            _ = try await client.fetch(ProjectStatus.self, path: ["api", "..", "status"])
            XCTFail("Expected invalid path")
        } catch ResearchAPIError.invalidConfiguration {}
        let count = await script.callCount
        XCTAssertEqual(count, 0)
    }
}

private actor FailureScriptClient: NetworkClient {
    enum Outcome {
        case http(Int)
        case timeout
        case invalidPayload
        case success
    }

    private var outcomes: [Outcome]
    private(set) var callCount = 0

    init(outcomes: [Outcome]) {
        self.outcomes = outcomes
    }

    func request<T: Decodable>(endpoint: any Endpoint, responseType: T.Type) async throws -> T {
        callCount += 1
        let outcome = outcomes.isEmpty ? .success : outcomes.removeFirst()
        switch outcome {
        case .http(let status):
            throw NetworkError.serverError(status)
        case .timeout:
            throw NetworkError.unknown(URLError(.timedOut))
        case .invalidPayload:
            throw NetworkError.decodingFailed(
                DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "fixture"))
            )
        case .success:
            let json = #"{"productName":"Recovered","sourceLabel":"Fixture","metrics":[],"evidence":[],"baseline":[]}"#
            return try JSONDecoder().decode(T.self, from: Data(json.utf8))
        }
    }
}
