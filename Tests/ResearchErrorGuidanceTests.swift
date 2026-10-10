import XCTest
@testable import TrisMarketLens

final class ResearchErrorGuidanceTests: XCTestCase {
    func testHTTPStatusGuidance() {
        XCTAssertTrue(ResearchErrorGuidance.message(for: ResearchAPIError.httpStatus(401)).contains("authentication"))
        XCTAssertTrue(ResearchErrorGuidance.message(for: ResearchAPIError.httpStatus(403)).contains("denied"))
        XCTAssertTrue(ResearchErrorGuidance.message(for: ResearchAPIError.httpStatus(404)).contains("not found"))
        XCTAssertTrue(ResearchErrorGuidance.message(for: ResearchAPIError.httpStatus(429)).contains("Too many"))
        XCTAssertTrue(ResearchErrorGuidance.message(for: ResearchAPIError.httpStatus(503)).contains("503"))
    }

    func testInvalidPayloadNeverImpliesVerifiedResearch() {
        let message = ResearchErrorGuidance.message(for: ResearchAPIError.invalidPayload)
        XCTAssertTrue(message.contains("No unverified results"))
    }

    func testTransportAndConfigurationMessages() {
        XCTAssertTrue(ResearchErrorGuidance.message(for: ResearchAPIError.transport).contains("connection"))
        XCTAssertTrue(ResearchErrorGuidance.message(for: ResearchAPIError.invalidConfiguration).contains("base URL"))
    }
}
