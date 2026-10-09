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

        let weatherStatus = app.descendants(matching: .any)["weather-status"]
        XCTAssertTrue(weatherStatus.waitForExistence(timeout: 3))
        XCTAssertEqual(weatherStatus.label, "Weather updated 10 min ago • Refresh available in 5 min")
        XCTAssertFalse(app.descendants(matching: .any)["refresh-status"].exists)
    }

    @MainActor
    func testDisplaysCachedResultWhileRefreshing() throws {
        let app = launch(scenario: "refreshing")

        XCTAssertTrue(
            app.descendants(matching: .any)["weather-status"].waitForExistence(timeout: 3)
        )
        XCTAssertEqual(
            app.descendants(matching: .any)["weather-status"].label,
            "Showing saved weather • Updating…"
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
    func testDisplaysExplicitFogReason() throws {
        let app = launch(scenario: "fog")

        XCTAssertTrue(app.staticTexts["Don’t wear"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Fog is expected."].exists)
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

        let appRow = settings.staticTexts["Can I Wear"]
        for _ in 0..<12 where !appRow.isHittable {
            settings.swipeUp()
        }
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
