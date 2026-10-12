import XCTest
@testable import TrisMarketLens

final class OperationsStatusPresentationTests: XCTestCase {
    func testConnectionStatusDoesNotAssumeUnknownMeansDisconnected() {
        XCTAssertEqual(OperationsStatusPresentation.connectionTitle("connected"), "Connected")
        XCTAssertEqual(OperationsStatusPresentation.connectionTitle("degraded"), "Degraded")
        XCTAssertEqual(OperationsStatusPresentation.connectionTitle("not_connected"), "Not connected")
        XCTAssertEqual(OperationsStatusPresentation.connectionTitle("future_state"), "Unknown connection state: future_state")
    }

    func testRunStatusDoesNotInferSuccessFromUnknownOrIncompleteStates() {
        XCTAssertEqual(OperationsStatusPresentation.runStateTitle("completed"), "Completed")
        XCTAssertEqual(OperationsStatusPresentation.runStateTitle("in_progress"), "In progress")
        XCTAssertEqual(OperationsStatusPresentation.runStateTitle("blocked"), "Blocked")
        XCTAssertEqual(OperationsStatusPresentation.runStateTitle("new_state"), "Unknown: new_state")
    }
}
