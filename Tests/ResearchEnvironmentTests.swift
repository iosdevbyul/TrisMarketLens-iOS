import XCTest
@testable import TrisMarketLens

final class ResearchEnvironmentTests: XCTestCase {
    func testDefaultDeveloperModeIsMock() throws {
        let environment = try ResearchEnvironment(values: [:])
        XCTAssertEqual(environment.mode, .mock)
        XCTAssertNil(environment.client)
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

    func testUnsupportedModeRejected() {
        XCTAssertThrowsError(try ResearchEnvironment(values: ["TRIS_DATA_MODE": "production"]))
    }
}
