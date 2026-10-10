import XCTest
@testable import TrisMarketLens

final class ProjectStatusTests: XCTestCase {
    func testMockSourceIsExplicitlyNonLive() async throws {
        let result = try await MockProjectStatusSource().getProjectStatus()
        XCTAssertTrue(result.sourceLabel.contains("Mock"))
        XCTAssertEqual(result.metrics.count, 4)
        XCTAssertEqual(result.baseline.first?.state, .notStarted)
    }

    func testProjectStatusDecodesWebContract() throws {
        let json = """
        {
          "productName":"TrisMarketLens",
          "sourceLabel":"Mock",
          "metrics":[{"label":"Universe","value":"993","detail":"Sample"}],
          "evidence":[{"label":"Corporate actions","state":"in_progress","detail":"Review"}],
          "baseline":[{"label":"Historical backtest","state":"not_started","detail":"Pending"}]
        }
        """
        let status = try JSONDecoder().decode(ProjectStatus.self, from: Data(json.utf8))
        XCTAssertEqual(status.evidence.first?.state, .inProgress)
        XCTAssertEqual(status.baseline.first?.state, .notStarted)
    }
}
