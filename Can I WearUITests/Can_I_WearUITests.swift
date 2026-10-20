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
        let avoid = app.descendants(matching: .any)["period-2"]
        XCTAssertTrue(avoid.waitForExistence(timeout: 3))
        XCTAssertTrue(wear.exists)
        XCTAssertTrue(caution.exists)
        XCTAssertTrue(avoid.label.contains("Evening"))
        XCTAssertTrue(avoid.label.contains("18–24"))
        XCTAssertTrue(wear.label.contains("Morning"))
        XCTAssertTrue(caution.label.contains("Afternoon"))
        XCTAssertTrue(avoid.label.contains("NO"))
        XCTAssertFalse(avoid.label.contains("Precipitation"))
        XCTAssertTrue(wear.label.contains("YES"))
        XCTAssertTrue(caution.label.contains("MAYBE"))
        let hero = app.descendants(matching: .any)["recommendation-hero"]
        XCTAssertTrue(hero.label.contains("Leather Jacket. Avoid during wet weather"))
        XCTAssertTrue(hero.label.contains("Wet weather is expected and could damage leather."))
        XCTAssertTrue(app.descendants(matching: .any)["hour-0"].label.contains("06:00"))
        XCTAssertTrue(app.descendants(matching: .any)["hour-17"].label.contains("NO"))
        capture(app, name: "Home — mixed periods")
    }

    @MainActor
    func testUsesConciseWeatherAttribution() throws {
        let app = launch(scenario: "cached")

        let attribution = weatherAttribution(in: app)
        for _ in 0..<6 where !attribution.exists { app.swipeUp() }
        XCTAssertTrue(attribution.waitForExistence(timeout: 3))
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
        XCTAssertTrue(hero.label.contains("Avoid during fog or mist"))
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
        let app = XCUIApplication()
        app.launchArguments = ["-ui-test-scenario", "periods"]
        app.launch()
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
        let guidedHomeSwitch = settings.switches["Guided Home"]
        XCTAssertTrue(guidedHomeSwitch.waitForExistence(timeout: 5))
        let introductionSwitch = settings.switches["Show How It Works"]
        XCTAssertTrue(introductionSwitch.waitForExistence(timeout: 5))
        if switchIsOn(introductionSwitch) {
            toggle(introductionSwitch)
        }
        if switchIsOn(guidedHomeSwitch) {
            toggle(guidedHomeSwitch)
        }
        if switchIsOn(debugSwitch) {
            toggle(debugSwitch)
        }
        XCTAssertFalse(switchIsOn(debugSwitch))

        app.activate()
        XCTAssertTrue(app.descendants(matching: .any)["recommendation-hero"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["How it works"].exists)
        XCTAssertFalse(app.staticTexts["home-purpose"].exists)
        XCTAssertFalse(app.staticTexts["day-parts-heading"].exists)

        settings.activate()
        XCTAssertTrue(introductionSwitch.waitForExistence(timeout: 5))
        XCTAssertTrue(guidedHomeSwitch.waitForExistence(timeout: 5))
        XCTAssertFalse(switchIsOn(guidedHomeSwitch))
        toggle(introductionSwitch)
        toggle(debugSwitch)
        XCTAssertTrue(switchIsOn(debugSwitch), "Switch value: \(String(describing: debugSwitch.value))")

        app.activate()
        XCTAssertTrue(app.buttons["diagnostics-button"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["How it works"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["home-purpose"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["day-parts-heading"].waitForExistence(timeout: 5))

        settings.activate()
        XCTAssertTrue(debugSwitch.waitForExistence(timeout: 5))
        XCTAssertTrue(guidedHomeSwitch.waitForExistence(timeout: 5))
        XCTAssertTrue(introductionSwitch.waitForExistence(timeout: 5))
        XCTAssertTrue(switchIsOn(guidedHomeSwitch))
        XCTAssertTrue(switchIsOn(introductionSwitch))
        toggle(guidedHomeSwitch)

        app.activate()
        let heading = app.staticTexts["day-parts-heading"]
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: heading)
        waitForExpectations(timeout: 5)
        XCTAssertFalse(app.staticTexts["home-purpose"].exists)
        XCTAssertFalse(app.staticTexts["How it works"].exists)

        settings.activate()
        XCTAssertTrue(guidedHomeSwitch.waitForExistence(timeout: 5))
        XCTAssertTrue(introductionSwitch.waitForExistence(timeout: 5))
        XCTAssertFalse(switchIsOn(guidedHomeSwitch))
        XCTAssertFalse(switchIsOn(introductionSwitch))
        if !switchIsOn(guidedHomeSwitch) {
            toggle(guidedHomeSwitch)
        }
        if switchIsOn(debugSwitch) {
            toggle(debugSwitch)
        }

        app.activate()
        let diagnostics = app.buttons["diagnostics-button"]
        let disappeared = NSPredicate(format: "exists == false")
        expectation(for: disappeared, evaluatedWith: diagnostics)
        waitForExpectations(timeout: 5)
        XCTAssertTrue(app.staticTexts["day-parts-heading"].waitForExistence(timeout: 5))
        verifyItemSetupReset(app: app, settings: settings)
    }

    @MainActor
    private func verifyItemSetupReset(app: XCUIApplication, settings: XCUIApplication) {
        app.buttons["configure-items"].tap()
        XCTAssertTrue(app.buttons["Cancel"].waitForExistence(timeout: 5))
        settings.activate()
        let reset = settings.switches["Reset Item Setup"]
        for _ in 0..<5 where !reset.isHittable { settings.swipeUp() }
        XCTAssertTrue(reset.isHittable)
        XCTAssertFalse(switchIsOn(reset))
        toggle(reset)
        XCTAssertTrue(switchIsOn(reset))

        app.activate()
        let confirm = app.buttons["confirm-item-selection"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        XCTAssertEqual(confirm.label, "Continue")
        XCTAssertFalse(app.buttons["Cancel"].exists)
        XCTAssertFalse(confirm.isEnabled)
        XCTAssertEqual(app.buttons["select-item-leatherJacket"].value as? String, "Not selected")
        let replay = XCTAttachment(screenshot: app.screenshot())
        replay.name = "Settings reset — first item setup"
        replay.lifetime = .keepAlways
        add(replay)
        app.buttons["select-item-leatherJacket"].tap()
        XCTAssertTrue(confirm.isEnabled)
        confirm.tap()
        XCTAssertTrue(app.buttons["configure-items"].waitForExistence(timeout: 5))

        settings.activate()
        XCTAssertTrue(reset.waitForExistence(timeout: 5))
        XCTAssertFalse(switchIsOn(reset))
        app.activate()
        XCTAssertTrue(app.buttons["configure-items"].waitForExistence(timeout: 5))
        XCTAssertFalse(confirm.exists)

        app.terminate()
        settings.activate()
        toggle(reset)
        XCTAssertTrue(switchIsOn(reset))
        app.launchArguments += ["-ui-test-preserve-selection"]
        app.launch()
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        XCTAssertEqual(confirm.label, "Continue")
        XCTAssertFalse(confirm.isEnabled)
        XCTAssertEqual(app.buttons["select-item-leatherJacket"].value as? String, "Not selected")
        app.buttons["select-item-leatherJacket"].tap()
        XCTAssertTrue(confirm.isEnabled)
        confirm.tap()
        XCTAssertTrue(app.buttons["configure-items"].waitForExistence(timeout: 5))
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["configure-items"].waitForExistence(timeout: 5))
        XCTAssertFalse(confirm.exists)
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
    func testThreeDayPartsAndHourlyStatusesHaveNonColorMeaning() {
        let app = launch(scenario: "okay")
        XCTAssertTrue(app.descendants(matching: .any)["recommendation-hero"].label.contains("Good for the rest of today"))
        XCTAssertTrue(app.descendants(matching: .any)["period-0"].label.contains("YES"))
        XCTAssertTrue(app.descendants(matching: .any)["period-2"].label.contains("YES"))
        XCTAssertTrue(app.descendants(matching: .any)["hour-0"].label.contains("YES. Dry weather and suitable temperatures."))
        capture(app, name: "Home — YES")
    }

    @MainActor
    func testGuidedHomeExplainsTheResultAndPersistsGotIt() {
        let app = launch(scenario: "okay", homeMode: "guided", resetIntroduction: true)

        let introduction = app.staticTexts["How it works"]
        XCTAssertTrue(introduction.waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["home-purpose"].exists)
        XCTAssertFalse(app.staticTexts["Skip it today."].exists)
        XCTAssertTrue(app.staticTexts["day-parts-heading"].exists)
        let relationshipExplanation = app.staticTexts.matching(NSPredicate(
            format: "label CONTAINS %@ AND label CONTAINS %@",
            "main result covers today",
            "reason explains why"
        )).firstMatch
        XCTAssertTrue(relationshipExplanation.exists)

        let gotIt = app.buttons["home-introduction-got-it"]
        for _ in 0..<4 where !gotIt.isHittable { app.swipeUp() }
        XCTAssertTrue(gotIt.isHittable)
        gotIt.tap()
        XCTAssertFalse(introduction.exists)

        app.terminate()
        app.launchArguments = ["-ui-test-scenario", "okay", "-ui-test-home-mode", "guided"]
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["recommendation-hero"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["How it works"].exists)

        app.terminate()
        app.launchArguments.append("-ui-test-reset-home-introduction")
        app.launch()
        XCTAssertTrue(app.staticTexts["How it works"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testCompactHomeOmitsGuidedContent() {
        let app = launch(scenario: "okay", homeMode: "compact", resetIntroduction: true)

        XCTAssertTrue(app.descendants(matching: .any)["recommendation-hero"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["How it works"].exists)
        XCTAssertFalse(app.staticTexts["home-purpose"].exists)
        XCTAssertFalse(app.staticTexts["day-parts-heading"].exists)
    }

    @MainActor
    func testCompactHomeFitsWithoutScrollingAtStandardText() {
        let app = launch(scenario: "okay", homeMode: "compact")

        XCTAssertTrue(app.descendants(matching: .any)["recommendation-hero"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.descendants(matching: .any)["period-2"].isHittable)
        XCTAssertTrue(app.descendants(matching: .any)["hourly-timeline"].isHittable)
        XCTAssertTrue(weatherAttribution(in: app).isHittable)
    }

    @MainActor
    func testLargestDynamicTypeUsesAReadableTwoColumnDayPartGrid() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-ui-test-scenario", "many-periods",
            "-ui-test-home-mode", "compact",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
        ]
        app.launch()
        let hero = app.descendants(matching: .any)["recommendation-hero"]
        XCTAssertTrue(hero.waitForExistence(timeout: 3))
        XCTAssertLessThanOrEqual(hero.frame.width, app.frame.width)
        capture(app, name: "Home — accessibility text")
        let last = app.descendants(matching: .any)["period-2"]
        for _ in 0..<8 where !last.isHittable { app.swipeUp() }
        XCTAssertTrue(last.isHittable)
        XCTAssertTrue(last.label.contains("NO"))
        let attribution = weatherAttribution(in: app)
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

    private func weatherAttribution(in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(
            format: "label == %@",
            "Weather provided by Open-Meteo"
        )).firstMatch
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
    private func launch(
        scenario: String,
        homeMode: String = "compact",
        resetIntroduction: Bool = false
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-ui-test-scenario", scenario,
            "-ui-test-home-mode", homeMode
        ]
        if resetIntroduction {
            app.launchArguments.append("-ui-test-reset-home-introduction")
        }
        app.launch()
        return app
    }
}
