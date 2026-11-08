import XCTest

/// Real app launch smoke checks. No live API, publisher proof or simulated
/// investment results are required or implied by these tests.
final class TrisMarketLensLaunchUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testDisconnectedLaunchDoesNotPresentMockResults() {
        let app = XCUIApplication()
        app.launchEnvironment["TRIS_DATA_MODE"] = "disconnected"
        app.launchEnvironment["TRIS_API_BASE_URL"] = ""
        app.launch()

        XCTAssertTrue(app.staticTexts["Research dashboard"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.staticTexts["Mock data · Not live research"].exists)
        XCTAssertFalse(app.staticTexts["Synthetic demo data — not live market coverage"].exists)
        XCTAssertFalse(app.staticTexts["Invalid research configuration"].exists)
    }

    func testInvalidModeBlocksApplicationContent() {
        let app = XCUIApplication()
        app.launchEnvironment["TRIS_DATA_MODE"] = "unsupported-ui-test"
        app.launchEnvironment["TRIS_API_BASE_URL"] = "https://example.invalid"
        app.launch()

        XCTAssertTrue(app.staticTexts["Invalid research configuration"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["Check TRIS_DATA_MODE and TRIS_API_BASE_URL. No automatic mock fallback."].exists)
        XCTAssertFalse(app.staticTexts["Research dashboard"].exists)
    }

    func testHTTPModeWithoutBaseURLFailsClosed() {
        let app = XCUIApplication()
        app.launchEnvironment["TRIS_DATA_MODE"] = "http"
        app.launchEnvironment["TRIS_API_BASE_URL"] = ""
        app.launch()

        XCTAssertTrue(app.staticTexts["Invalid research configuration"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.staticTexts["Research dashboard"].exists)
    }
}
