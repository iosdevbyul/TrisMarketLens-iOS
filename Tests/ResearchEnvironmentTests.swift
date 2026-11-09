import XCTest
@testable import TrisMarketLens

final class ResearchEnvironmentTests: XCTestCase {
    func testDefaultModeIsSafeForBuildConfiguration() throws {
        let environment = try ResearchEnvironment(values: [:])
        #if DEBUG
        XCTAssertEqual(environment.mode, .mock)
        #else
        XCTAssertEqual(environment.mode, .disconnected)
        #endif
        XCTAssertNil(environment.client)
    }

    func testExplicitMockAllowedOnlyInDebugBuilds() throws {
        #if DEBUG
        XCTAssertEqual(try ResearchEnvironment(values: ["TRIS_DATA_MODE": "mock"]).mode, .mock)
        #else
        XCTAssertThrowsError(try ResearchEnvironment(values: ["TRIS_DATA_MODE": "mock"])) { error in
            XCTAssertEqual(error as? ResearchEnvironmentError, .unsupportedMode)
        }
        #endif
    }

    func testDisconnectedModeNeverLoadsStockFixtures() async throws {
        let environment = try ResearchEnvironment(values: ["TRIS_DATA_MODE": "disconnected"])
        XCTAssertEqual(environment.mode, .disconnected)
        do {
            _ = try await environment.stocks().getStocks()
            XCTFail("Disconnected mode must not return demo stocks")
        } catch {
            // Expected explicit disconnected error.
        }
    }

    func testHTTPRequiresConfiguredBaseURL() {
        XCTAssertThrowsError(try ResearchEnvironment(values: ["TRIS_DATA_MODE": "http"])) { error in
            XCTAssertEqual(error as? ResearchEnvironmentError, .missingBaseURL)
        }
        XCTAssertThrowsError(try ResearchEnvironment(values: [
            "TRIS_DATA_MODE": "http",
            "TRIS_API_BASE_URL": "file:///tmp"
        ]))
    }

    func testHTTPCanBeSelectedWithoutStartingNetworkTraffic() throws {
        let environment = try ResearchEnvironment(values: [
            "TRIS_DATA_MODE": "http",
            "TRIS_API_BASE_URL": "https://example.test"
        ])
        XCTAssertEqual(environment.mode, .http)
        XCTAssertNotNil(environment.client)
    }

    func testReleaseRejectsPlaintextResearchServers() throws {
        let values = [
            "TRIS_DATA_MODE": "http",
            "TRIS_API_BASE_URL": "http://example.test:8000"
        ]
        #if DEBUG
        XCTAssertNotNil(try ResearchEnvironment(values: values).client)
        #else
        XCTAssertThrowsError(try ResearchEnvironment(values: values)) { error in
            XCTAssertEqual(error as? ResearchEnvironmentError, .insecureReleaseURL)
        }
        #endif
    }

    func testLoopbackPlaintextOnlyPermittedInDebug() throws {
        let values = [
            "TRIS_DATA_MODE": "http",
            "TRIS_API_BASE_URL": "http://127.0.0.1:8000"
        ]
        #if DEBUG
        XCTAssertEqual(try ResearchEnvironment(values: values).mode, .http)
        #else
        XCTAssertThrowsError(try ResearchEnvironment(values: values)) { error in
            XCTAssertEqual(error as? ResearchEnvironmentError, .insecureReleaseURL)
        }
        #endif
    }

    func testHTTPSRemainsAvailableInReleaseAndDebug() throws {
        let environment = try ResearchEnvironment(values: [
            "TRIS_DATA_MODE": "http",
            "TRIS_API_BASE_URL": "https://research.example.test"
        ])
        XCTAssertEqual(environment.mode, .http)
        XCTAssertNotNil(environment.client)
    }

    func testUnsupportedModeRejected() {
        XCTAssertThrowsError(try ResearchEnvironment(values: ["TRIS_DATA_MODE": "production"]))
    }
}
