import XCTest

/// Bounded accessibility-size and orientation smoke checks on a real simulator app.
/// No live backend, external authorization, or accessibility hardware audit is implied.
final class TrisMarketLensLayoutUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    override func tearDownWithError() throws {
        XCUIDevice.shared.orientation = .portrait
    }

    func testLargeTextDisconnectedDashboardRetainsRetryAndSourceWarning() {
        let app = disconnectedApp(largeText: true)
        app.launch()

        XCTAssertTrue(app.staticTexts["Research dashboard"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.staticTexts["Configured research source"].exists)
        XCTAssertTrue(app.buttons["Retry request"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.staticTexts["Research status unavailable"].exists)
        XCTAssertFalse(app.staticTexts["Mock data · Not live research"].exists)
    }

    func testLandscapeConfigurationErrorRemainsVisible() {
        let app = XCUIApplication()
        app.launchEnvironment["TRIS_DATA_MODE"] = "not-a-data-mode"
        app.launchEnvironment["TRIS_API_BASE_URL"] = ""
        app.launch()
        XCTAssertTrue(app.staticTexts["Invalid research configuration"].waitForExistence(timeout: 20))
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(app.staticTexts["Invalid research configuration"].waitForExistence(timeout: 20))
        XCTAssertFalse(app.staticTexts["Research dashboard"].exists)
    }

    func testDisconnectedStocksShowsRetryWithoutMockUniverse() {
        let app = disconnectedApp(largeText: false)
        app.launch()
        XCTAssertTrue(app.staticTexts["Research dashboard"].waitForExistence(timeout: 20))

        let stocks = app.staticTexts["navigation.stocks"]
        if !stocks.isHittable {
            let sidebarButton = app.navigationBars.buttons.firstMatch
            XCTAssertTrue(sidebarButton.waitForExistence(timeout: 10))
            sidebarButton.tap()
        }
        XCTAssertTrue(stocks.waitForExistence(timeout: 15))
        stocks.tap()

        let retry = app.buttons["Retry request"]
        XCTAssertTrue(retry.waitForExistence(timeout: 20), "Stocks must expose a manual retry when the source is disconnected. UI: \(app.debugDescription)")
        XCTAssertTrue(app.staticTexts["Configured research source"].exists)
        XCTAssertFalse(app.staticTexts["Synthetic demo data — not live market coverage"].exists)
    }

    private func disconnectedApp(largeText: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["TRIS_DATA_MODE"] = "disconnected"
        app.launchEnvironment["TRIS_API_BASE_URL"] = ""
        if largeText {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityM"]
        }
        return app
    }
}
