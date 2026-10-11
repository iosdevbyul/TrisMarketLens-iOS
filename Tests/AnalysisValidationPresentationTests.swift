import XCTest
@testable import TrisMarketLens

final class AnalysisValidationPresentationTests: XCTestCase {
    func testVerifiedIsNotARealizedOutcome() {
        XCTAssertTrue(AnalysisValidationPresentation.explanation(for: "verified").contains("not a prediction outcome"))
    }

    func testPendingAndBlockedStayExplicit() {
        XCTAssertTrue(AnalysisValidationPresentation.explanation(for: "pending").contains("pending"))
        XCTAssertTrue(AnalysisValidationPresentation.explanation(for: "blocked").contains("blocked"))
    }

    func testUnknownStateNeverClaimsVerified() {
        XCTAssertTrue(AnalysisValidationPresentation.explanation(for: "unexpected").contains("No verified status"))
    }
}
