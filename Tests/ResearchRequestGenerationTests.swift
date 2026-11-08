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

    func testReloadClearsPreviousStateBeforeNewResponse() {
        var gate = ResearchRequestGeneration()
        var shownRecords = ["old published record"]
        var loading = false
        let first = gate.begin()
        loading = true
        shownRecords = []
        XCTAssertTrue(loading)
        XCTAssertTrue(shownRecords.isEmpty)
        let second = gate.begin()
        // An older response is not allowed to repopulate a refreshed screen.
        if gate.accepts(first) {
            shownRecords = ["old response"]
            loading = false
        }
        XCTAssertTrue(loading)
        XCTAssertTrue(shownRecords.isEmpty)
        if gate.accepts(second) {
            shownRecords = ["fresh response"]
            loading = false
        }
        XCTAssertFalse(loading)
        XCTAssertEqual(shownRecords, ["fresh response"])
    }

    func testCancelledRequestCannotResetNewerLoadingIndicator() {
        var gate = ResearchRequestGeneration()
        let original = gate.begin()
        let current = gate.begin()
        var isLoading = true
        if gate.accepts(original, cancelled: true) { isLoading = false }
        XCTAssertTrue(isLoading)
        if gate.accepts(original) { isLoading = false }
        XCTAssertTrue(isLoading)
        if gate.accepts(current) { isLoading = false }
        XCTAssertFalse(isLoading)
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
