import Foundation
import XCTest
@testable import TrisMarketLens

final class ResearchRequestGenerationTests: XCTestCase {
    func testOnlyNewestTokenCanUpdatePresentedState() {
        var gate = ResearchRequestGeneration()
        let first = gate.begin()
        XCTAssertTrue(gate.accepts(first))
        let second = gate.begin()
        XCTAssertFalse(gate.accepts(first))
        XCTAssertTrue(gate.accepts(second))
    }

    func testCancellationDiscardsEvenLatestResponse() {
        var gate = ResearchRequestGeneration()
        let token = gate.begin()
        XCTAssertTrue(gate.accepts(token, cancelled: false))
        XCTAssertFalse(gate.accepts(token, cancelled: true))
    }

    func testOldFailureCannotOverwriteNewerSuccess() {
        var gate = ResearchRequestGeneration()
        let failedAttempt = gate.begin()
        let successfulAttempt = gate.begin()
        var visibleResult = "loading"
        if gate.accepts(successfulAttempt) { visibleResult = "latest response" }
        if gate.accepts(failedAttempt) { visibleResult = "old error" }
        XCTAssertEqual(visibleResult, "latest response")
    }

    func testIndependentRequestDomainsDoNotInvalidateEachOther() {
        var summaries = ResearchRequestGeneration()
        var bars = ResearchRequestGeneration()
        let summary = summaries.begin()
        let firstBars = bars.begin()
        _ = bars.begin()
        XCTAssertTrue(summaries.accepts(summary))
        XCTAssertFalse(bars.accepts(firstBars))
    }
}
