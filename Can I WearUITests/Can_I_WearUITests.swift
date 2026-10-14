import XCTest

final class Can_I_WearUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testDisplaysOrderedRecommendationPeriods() throws {
        let app = launch(scenario: "periods")

        let wear = app.descendants(matching: .any)["period-0"]
        let caution = app.descendants(matching: .any)["period-1"]
        let avoid = app.descendants(matching: .any)["period-3"]
        XCTAssertTrue(avoid.waitForExistence(timeout: 3))
        XCTAssertTrue(wear.exists)
        XCTAssertTrue(caution.exists)
        XCTAssertTrue(avoid.label.contains("Night"))
        XCTAssertTrue(wear.label.contains("Morning"))
        XCTAssertTrue(caution.label.contains("Afternoon"))
        XCTAssertTrue(avoid.label.contains("AVOID"))
        XCTAssertFalse(avoid.label.contains("Precipitation"))
        XCTAssertTrue(wear.label.contains("OK"))
        XCTAssertTrue(caution.label.contains("CAUTION"))
        let hero = app.descendants(matching: .any)["recommendation-hero"]
        XCTAssertTrue(hero.label.contains("Leather Jacket, today: AVOID"))
        XCTAssertTrue(hero.label.contains("Precipitation could damage leather."))
        XCTAssertTrue(app.descendants(matching: .any)["hour-0"].label.contains("06:00"))
        XCTAssertTrue(app.descendants(matching: .any)["hour-17"].label.contains("AVOID"))
        capture(app, name: "Home — mixed periods")
    }

    @MainActor
    func testUsesConciseWeatherAttribution() throws {
        let app = launch(scenario: "cached")

        XCTAssertTrue(app.staticTexts["Weather provided by Open-Meteo"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.descendants(matching: .any)["weather-status"].exists)
    }

    @MainActor
    func testDoesNotAddVerboseRefreshingStatus() throws {
        let app = launch(scenario: "refreshing")

        XCTAssertTrue(app.descendants(matching: .any)["recommendation-hero"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.descendants(matching: .any)["weather-status"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["refresh-status"].exists)
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
    func testDisplaysExplicitFogReason() throws {
        let app = launch(scenario: "fog")

        let hero = app.descendants(matching: .any)["recommendation-hero"]
        XCTAssertTrue(hero.waitForExistence(timeout: 3))
        XCTAssertTrue(hero.label.contains("AVOID"))
        XCTAssertTrue(hero.label.contains("Fog is expected."))
    }

    @MainActor
    func testDiagnosticsIsHiddenByDefault() throws {
        let app = launch(scenario: "periods")

        XCTAssertFalse(app.buttons["diagnostics-button"].exists)
    }

    @MainActor
    func testEnabledDiagnosticsCanOpenCopyAndDismiss() throws {
        let app = launch(scenario: "diagnostics")
        let diagnostics = app.buttons["diagnostics-button"]
        XCTAssertTrue(diagnostics.waitForExistence(timeout: 3))
        for _ in 0..<4 where !diagnostics.isHittable { app.swipeUp() }

        diagnostics.tap()
        XCTAssertTrue(app.descendants(matching: .any)["diagnostics-sheet"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Place used for weather"].exists)
        XCTAssertFalse(app.staticTexts["This place is included if you copy the report. Exact coordinates are not shown."].exists)

        let copy = app.buttons["copy-diagnostics-report"]
        for _ in 0..<8 where !copy.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(copy.isHittable)
        copy.tap()
        XCTAssertTrue(app.buttons["Report Copied"].exists)
        app.buttons["Done"].tap()
        XCTAssertFalse(app.descendants(matching: .any)["diagnostics-sheet"].exists)
    }

    @MainActor
    func testSystemSettingsToggleIsReflectedWhenAppBecomesActive() throws {
        let app = launch(scenario: "periods")
        XCTAssertFalse(app.buttons["diagnostics-button"].exists)

        let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
        settings.launch()
        let apps = settings.staticTexts["Apps"]
        for _ in 0..<5 where !apps.exists {
            let back = settings.navigationBars.buttons.element(boundBy: 0)
            if back.exists {
                back.tap()
            }
        }
        for _ in 0..<12 where !apps.isHittable {
            settings.swipeUp()
        }
        XCTAssertTrue(apps.isHittable)
        apps.tap()

        // Search rather than swiping past the C section while Settings loads its app list.
        let appSearch = settings.searchFields.firstMatch
        XCTAssertTrue(appSearch.waitForExistence(timeout: 10))
        appSearch.tap()
        appSearch.typeText("Can I Wear")
        let appRow = settings.cells.containing(.staticText, identifier: "Can I Wear").firstMatch
        XCTAssertTrue(appRow.waitForExistence(timeout: 10))
        XCTAssertTrue(appRow.isHittable)
        appRow.tap()

        let debugSwitch = settings.switches["Debug Enabled"]
        XCTAssertTrue(debugSwitch.waitForExistence(timeout: 5))
        if switchIsOn(debugSwitch) {
            toggle(debugSwitch)
        }
        XCTAssertFalse(switchIsOn(debugSwitch))
        toggle(debugSwitch)
        XCTAssertTrue(switchIsOn(debugSwitch), "Switch value: \(String(describing: debugSwitch.value))")

        app.activate()
        XCTAssertTrue(app.buttons["diagnostics-button"].waitForExistence(timeout: 5))

        settings.activate()
        XCTAssertTrue(debugSwitch.waitForExistence(timeout: 5))
        if switchIsOn(debugSwitch) {
            toggle(debugSwitch)
        }

        app.activate()
        let diagnostics = app.buttons["diagnostics-button"]
        let disappeared = NSPredicate(format: "exists == false")
        expectation(for: disappeared, evaluatedWith: diagnostics)
        waitForExpectations(timeout: 5)
    }

    private func switchIsOn(_ element: XCUIElement) -> Bool {
        guard let rawValue = element.value else { return false }
        if let number = rawValue as? NSNumber {
            return number.boolValue
        }
        let value = String(describing: rawValue).lowercased()
        return value == "1" || value == "on" || value == "aan" || value == "true"
    }

    private func toggle(_ element: XCUIElement) {
        element.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
    }

    @MainActor
    func testFailureAndLoadingStatesNeverShowSuitability() {
        for scenario in ["loading", "denied", "unavailable", "incomplete"] {
            let app = launch(scenario: scenario)
            XCTAssertFalse(app.descendants(matching: .any)["recommendation-hero"].exists)
            XCTAssertFalse(app.descendants(matching: .any)["hourly-timeline"].exists)
            if scenario == "loading" {
                XCTAssertTrue(app.descendants(matching: .any)["loading-status"].waitForExistence(timeout: 3))
            } else {
                XCTAssertTrue(app.staticTexts["failure-title"].exists)
                XCTAssertTrue(app.buttons["Try Again"].exists)
            }
        }
    }

    @MainActor
    func testFourDayPartsAndHourlyStatusesHaveNonColorMeaning() {
        let app = launch(scenario: "okay")
        XCTAssertTrue(app.descendants(matching: .any)["recommendation-hero"].label.contains("today: OK"))
        XCTAssertTrue(app.descendants(matching: .any)["period-0"].label.contains("OK"))
        XCTAssertTrue(app.descendants(matching: .any)["period-3"].label.contains("OK"))
        XCTAssertTrue(app.descendants(matching: .any)["hour-0"].label.contains("OK. Dry and cool enough."))
        capture(app, name: "Home — OK")
    }

    @MainActor
    func testLargestDynamicTypeUsesAReadableTwoColumnDayPartGrid() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-test-scenario", "many-periods", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        let hero = app.descendants(matching: .any)["recommendation-hero"]
        XCTAssertTrue(hero.waitForExistence(timeout: 3))
        XCTAssertLessThanOrEqual(hero.frame.width, app.frame.width)
        capture(app, name: "Home — accessibility text")
        let last = app.descendants(matching: .any)["period-3"]
        for _ in 0..<8 where !last.isHittable { app.swipeUp() }
        XCTAssertTrue(last.isHittable)
        XCTAssertTrue(last.label.contains("AVOID"))
        let attribution = app.staticTexts["Weather provided by Open-Meteo"]
        for _ in 0..<8 where !attribution.isHittable { app.swipeUp() }
        XCTAssertTrue(attribution.isHittable)
    }

    @MainActor
    private func capture(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
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
