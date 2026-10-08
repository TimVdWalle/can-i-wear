import XCTest

final class Can_I_WearUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testDisplaysOrderedRecommendationPeriods() throws {
        let app = launch(scenario: "periods")

        let avoid = app.descendants(matching: .any)["period-0"]
        let wear = app.descendants(matching: .any)["period-1"]
        let caution = app.descendants(matching: .any)["period-2"]
        XCTAssertTrue(avoid.waitForExistence(timeout: 3))
        XCTAssertTrue(wear.exists)
        XCTAssertTrue(caution.exists)
        XCTAssertTrue(avoid.label.contains("–"))
        XCTAssertTrue(wear.label.contains("–"))
        XCTAssertTrue(caution.label.contains("–"))
        XCTAssertTrue(avoid.label.contains("Don’t wear"))
        XCTAssertTrue(avoid.label.contains("Precipitation is expected"))
        XCTAssertTrue(wear.label.contains("Wear"))
        XCTAssertTrue(caution.label.contains("Maybe"))
    }

    @MainActor
    func testDisplaysCachedAgeAfterFailedRefresh() throws {
        let app = launch(scenario: "cached")

        let cacheStatus = app.descendants(matching: .any)["cache-status"]
        XCTAssertTrue(cacheStatus.waitForExistence(timeout: 3))
        XCTAssertEqual(cacheStatus.label, "Cached • Updated 10 minutes ago")
        XCTAssertFalse(app.descendants(matching: .any)["refresh-status"].exists)
    }

    @MainActor
    func testDisplaysCachedResultWhileRefreshing() throws {
        let app = launch(scenario: "refreshing")

        XCTAssertTrue(
            app.descendants(matching: .any)["cache-status"].waitForExistence(timeout: 3)
        )
        XCTAssertTrue(app.descendants(matching: .any)["refresh-status"].exists)
    }

    @MainActor
    func testExplainsWhenSavedForecastIsExpired() throws {
        let app = launch(scenario: "expired")

        let title = app.staticTexts["failure-title"]
        let message = app.staticTexts["failure-message"]
        XCTAssertTrue(title.waitForExistence(timeout: 3))
        XCTAssertEqual(title.label, "Weather unavailable")
        XCTAssertEqual(
            message.label,
            "The saved forecast is too old to use. Connect to the internet and try again."
        )
        XCTAssertTrue(app.buttons["Try Again"].exists)
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            let app = XCUIApplication()
            app.launchArguments = ["-ui-test-scenario", "periods"]
            app.launch()
        }
    }

    @MainActor
    private func launch(scenario: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-test-scenario", scenario]
        app.launch()
        return app
    }
}
