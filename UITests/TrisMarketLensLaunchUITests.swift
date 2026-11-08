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

    func testDisconnectedOverviewManualRetryRemainsFailClosed() {
        let app = XCUIApplication()
        app.launchEnvironment["TRIS_DATA_MODE"] = "disconnected"
        app.launchEnvironment["TRIS_API_BASE_URL"] = ""
        app.launch()

        let retry = app.buttons["Retry request"]
        XCTAssertTrue(retry.waitForExistence(timeout: 20))
        XCTAssertTrue(app.staticTexts["Research status unavailable"].exists)
        retry.tap()

        XCTAssertTrue(retry.waitForExistence(timeout: 20))
        XCTAssertTrue(app.staticTexts["Research status unavailable"].exists)
        XCTAssertFalse(app.staticTexts["Mock data · Not live research"].exists)
        XCTAssertFalse(app.staticTexts["Synthetic demo data — not live market coverage"].exists)
    }

    func testExplicitMockModeHasVisibleDemoWarning() {
        let app = XCUIApplication()
        app.launchEnvironment["TRIS_DATA_MODE"] = "mock"
        app.launchEnvironment["TRIS_API_BASE_URL"] = ""
        app.launch()

        XCTAssertTrue(app.staticTexts["Mock data · Not live research"].waitForExistence(timeout: 20))
        XCTAssertFalse(app.staticTexts["Invalid research configuration"].exists)
    }

    func testDisconnectedNavigationShowsNoPublishedResearch() {
        let app = XCUIApplication()
        app.launchEnvironment["TRIS_DATA_MODE"] = "disconnected"
        app.launchEnvironment["TRIS_API_BASE_URL"] = ""
        app.launch()

        XCTAssertTrue(app.staticTexts["Research dashboard"].waitForExistence(timeout: 15))
        let screener = app.staticTexts["navigation.screener"]
        if !screener.isHittable {
            // On a compact iPhone split view, the detail screen hides the sidebar.
            let back = app.navigationBars.buttons.firstMatch
            XCTAssertTrue(back.waitForExistence(timeout: 10))
            back.tap()
        }
        XCTAssertTrue(screener.waitForExistence(timeout: 10))
        screener.tap()
        XCTAssertTrue(app.staticTexts["Not connected · No investment recommendations"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.staticTexts["Mock data · Not live research"].exists)
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
