import XCTest

final class ItemHomeUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    func testStandardSelectorShowsAllItemsAndFooterWithoutScrolling() {
        let app = launch("items-setup", flags: ["-ui-test-reset-selection"])
        let confirm = app.buttons["confirm-item-selection"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        let first = app.buttons["select-item-leatherJacket"]
        let viewport = app.frame.insetBy(dx: 0, dy: 44)
        for item in ["leatherJacket", "warmCoat", "sweater", "raincoat", "sunglasses", "shorts", "gloves"] {
            let row = app.buttons["select-item-\(item)"]
            XCTAssertTrue(row.exists)
            XCTAssertEqual(row.frame.height, first.frame.height, accuracy: 1)
            XCTAssertGreaterThanOrEqual(row.frame.height, 44)
            XCTAssertTrue(viewport.contains(row.frame), "\(item) must be fully visible before scrolling: \(row.frame)")
            XCTAssertLessThanOrEqual(row.frame.maxY, confirm.frame.minY)
        }
        let hint = app.staticTexts["You can change these anytime using the gear on Home."]
        XCTAssertTrue(viewport.contains(hint.frame), "The setup hint must be visible without scrolling")
        // Accessibility frames can be clipped to the scroll view and still pass a bounds check.
        XCTAssertGreaterThanOrEqual(hint.frame.height, app.staticTexts["selection-count"].frame.height - 1,
                                    "The hint must retain at least one complete footnote line")
        XCTAssertLessThanOrEqual(hint.frame.maxY, app.staticTexts["selection-count"].frame.minY)
        XCTAssertTrue(viewport.contains(confirm.frame))
        XCTAssertFalse(confirm.isEnabled)
        capture(app, "Item selector — standard text, no scrolling")
        app.buttons["select-item-gloves"].tap()
        XCTAssertTrue(confirm.isEnabled)
        XCTAssertEqual(app.staticTexts["selection-count"].label, "1 selected")
    }

    @MainActor
    func testLargestTextSelectorKeepsAllChoicesAndConfirmationAccessible() {
        let app = launch("items-setup", flags: [
            "-ui-test-reset-selection",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
        ])
        let confirm = app.buttons["confirm-item-selection"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        XCTAssertFalse(confirm.isEnabled)
        capture(app, "Item selector — largest text, initial viewport")
        for item in ["leatherJacket", "warmCoat", "sweater", "raincoat", "sunglasses", "shorts", "gloves"] {
            let row = app.buttons["select-item-\(item)"]
            reveal(row, in: app)
            XCTAssertTrue(row.isHittable)
            XCTAssertLessThanOrEqual(row.frame.width, app.frame.width)
            row.tap()
            XCTAssertEqual(row.value as? String, "Selected")
        }
        XCTAssertTrue(confirm.isHittable)
        XCTAssertTrue(confirm.isEnabled)
        XCTAssertEqual(app.staticTexts["selection-count"].label, "7 selected")
        capture(app, "Item selector — largest text, final choice")
        confirm.tap()
        XCTAssertTrue(app.buttons["item-card-leatherJacket"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testFreshSelectionDraftValidationSaveCancelPersistenceAndReplay() {
        let app = launch("items-setup", flags: ["-ui-test-reset-selection"])
        let confirm = app.buttons["confirm-item-selection"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        XCTAssertFalse(confirm.isEnabled)
        XCTAssertFalse(app.descendants(matching: .any)["loading-status"].exists)
        app.buttons["select-item-leatherJacket"].tap()
        XCTAssertTrue(confirm.isEnabled)
        confirm.tap()
        XCTAssertTrue(app.descendants(matching: .any)["recommendation-hero"].waitForExistence(timeout: 5))

        app.buttons["configure-items"].tap()
        app.buttons["select-item-leatherJacket"].tap()
        XCTAssertFalse(confirm.isEnabled)
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["recommendation-hero"].exists)
        app.buttons["configure-items"].tap()
        let sun = app.buttons["select-item-sunglasses"]
        reveal(sun, in: app)
        sun.tap()
        confirm.tap()
        XCTAssertTrue(app.buttons["item-card-leatherJacket"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["item-card-sunglasses"].exists)
        XCTAssertFalse(app.buttons["item-card-raincoat"].exists)
        capture(app, "Selected items — Home A")

        app.terminate()
        app.launchArguments = ["-ui-test-scenario", "items-setup", "-ui-test-home-mode", "compact", "-ui-test-preserve-selection"]
        app.launch()
        XCTAssertTrue(app.buttons["item-card-leatherJacket"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["item-card-sunglasses"].exists)

        app.terminate()
        app.launchArguments += ["-item_selection_completed", "NO"]
        app.launch()
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        XCTAssertTrue(confirm.isEnabled) // Replay preserves selection, not a fresh-install reset.
        XCTAssertEqual(app.buttons["select-item-leatherJacket"].value as? String, "Selected")
        XCTAssertEqual(app.buttons["select-item-sunglasses"].value as? String, "Selected")
    }

    @MainActor
    func testMixedAdviceCardsOpenMatchingFullDetail() {
        let app = launch("items-mixed")
        let jacket = app.buttons["item-card-leatherJacket"]
        XCTAssertTrue(jacket.waitForExistence(timeout: 5))
        XCTAssertTrue(jacket.label.contains("Avoid during wet weather"))
        XCTAssertTrue(jacket.label.contains("15:00–18:00"))
        let sunglasses = app.buttons["item-card-sunglasses"]
        reveal(sunglasses, in: app)
        XCTAssertTrue(sunglasses.label.contains("Useful today"))
        XCTAssertTrue(sunglasses.label.contains("12:00–15:00"))
        sunglasses.tap()
        let detail = app.scrollViews["item-detail"]
        XCTAssertTrue(detail.waitForExistence(timeout: 5))
        XCTAssertTrue(detail.descendants(matching: .any)["recommendation-hero"].label.contains("Sunglasses. Useful today"))
        XCTAssertTrue(detail.descendants(matching: .any)["item-period-sunglasses-1"].label.contains("12:00–15:00, Useful"))
        XCTAssertFalse(app.staticTexts["hourly-grouping-note"].exists)
        capture(app, "Sunglasses — full detail")
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["configure-items"].exists)
    }

    @MainActor
    func testLandscapeSelectionCancelRestoresSavedDraftBeforeReopening() {
        let app = launch("items-setup", flags: ["-ui-test-reset-selection"])
        XCUIDevice.shared.orientation = .landscapeLeft
        let confirm = app.buttons["confirm-item-selection"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        app.buttons["select-item-leatherJacket"].tap()
        confirm.tap()
        XCTAssertTrue(app.descendants(matching: .any)["recommendation-hero"].waitForExistence(timeout: 5))
        app.buttons["configure-items"].tap()
        app.buttons["select-item-leatherJacket"].tap()
        XCTAssertFalse(confirm.isEnabled)
        app.buttons["Cancel"].tap()
        app.buttons["configure-items"].tap()
        XCTAssertEqual(app.buttons["select-item-leatherJacket"].value as? String, "Selected")
        let sun = app.buttons["select-item-sunglasses"]
        reveal(sun, in: app)
        sun.tap()
        capture(app, "Landscape selector — draft before save")
        confirm.tap()
        XCTAssertTrue(app.buttons["item-card-leatherJacket"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["item-card-sunglasses"].exists)
    }

    @MainActor
    func testBriefSeparatedBorderlineAndUncertainAdviceInSingleItemHome() {
        for (scenario, item, title, time) in [
            ("items-brief", "sunglasses", "Briefly useful", "12:00–13:00"),
            ("items-separated", "sunglasses", "Useful today", "12:00–13:00 · 14:00–15:00"),
            ("items-borderline", "raincoat", "May be useful", "14:00–16:00"),
            ("items-uncertain", "sunglasses", "Forecast uncertain", "14:00–15:00")
        ] {
            let app = launch(scenario, flags: ["-ui-test-items", item])
            let hero = app.descendants(matching: .any)["recommendation-hero"]
            XCTAssertTrue(hero.waitForExistence(timeout: 5))
            XCTAssertTrue(hero.label.contains(title), hero.label)
            XCTAssertTrue(hero.label.contains(time), hero.label)
            XCTAssertFalse(app.buttons["item-card-\(item)"].exists)
            XCTAssertTrue(app.descendants(matching: .any)["item-hourly-timeline"].exists)
            capture(app, scenario)
            app.terminate()
        }
    }

    @MainActor
    func testUnavailableItemDoesNotDisableOthersOrShowInventedAdvice() {
        let app = launch("items-unavailable", flags: ["-ui-test-items", "leatherJacket,sunglasses"])
        XCTAssertTrue(app.buttons["item-card-leatherJacket"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["item-card-leatherJacket"].label.contains("Good for the rest of today"))
        let sunglasses = app.buttons["item-card-sunglasses"]
        reveal(sunglasses, in: app)
        XCTAssertTrue(sunglasses.label.contains("Not enough forecast data"))
        XCTAssertFalse(sunglasses.label.contains("Not needed"))
        sunglasses.tap()
        let detail = app.scrollViews["item-detail"]
        XCTAssertTrue(detail.waitForExistence(timeout: 5))
        XCTAssertFalse(detail.descendants(matching: .any)["item-hourly-timeline"].exists)
        XCTAssertFalse(detail.descendants(matching: .any)["item-period-sunglasses-0"].exists)
        capture(app, "Sunglasses — missing data")
        app.terminate()

        let independent = launch("items-no-jacket")
        XCTAssertTrue(independent.buttons["item-card-leatherJacket"].waitForExistence(timeout: 5))
        XCTAssertTrue(independent.buttons["item-card-leatherJacket"].label.contains("Not enough forecast data"))
        let raincoat = independent.buttons["item-card-raincoat"]
        reveal(raincoat, in: independent)
        XCTAssertTrue(raincoat.label.contains("Useful today"))
    }

    @MainActor
    func testGuidedSingleItemIntroductionRemainsSeparateFromSelection() {
        let app = launch("items-brief", flags: ["-ui-test-items", "sunglasses", "-ui-test-reset-home-introduction"], mode: "guided")
        XCTAssertTrue(app.staticTexts["How it works"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["home-purpose"].exists)
        app.buttons["home-introduction-got-it"].tap()
        app.terminate()
        app.launchArguments = ["-ui-test-scenario", "items-brief", "-ui-test-home-mode", "guided", "-ui-test-preserve-selection"]
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["recommendation-hero"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["How it works"].exists)
        XCTAssertTrue(app.staticTexts["day-parts-heading"].exists)
    }

    @MainActor
    func testLargestTextKeepsMultiItemCardsAndDetailsReadable() {
        let app = launch("items-separated", flags: [
            "-ui-test-items", "leatherJacket,sunglasses",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
        ])
        let jacket = app.buttons["item-card-leatherJacket"]
        XCTAssertTrue(jacket.waitForExistence(timeout: 5))
        XCTAssertLessThanOrEqual(jacket.frame.width, app.frame.width)
        capture(app, "Multi-item Home — accessibility text")
        let sunglasses = app.buttons["item-card-sunglasses"]
        reveal(sunglasses, in: app)
        XCTAssertTrue(sunglasses.isHittable)
        XCTAssertLessThanOrEqual(sunglasses.frame.width, app.frame.width)
        sunglasses.tap()
        let detail = app.scrollViews["item-detail"]
        XCTAssertTrue(detail.waitForExistence(timeout: 5))
        let finalPeriod = detail.descendants(matching: .any)["item-period-sunglasses-4"]
        reveal(finalPeriod, in: app)
        XCTAssertTrue(finalPeriod.isHittable)
        capture(app, "Sunglasses detail — accessibility text")
    }

    @MainActor
    private func launch(_ scenario: String, flags: [String] = [], mode: String = "compact") -> XCUIApplication {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["-ui-test-scenario", scenario, "-ui-test-home-mode", mode] + flags
        app.launch()
        return app
    }

    @MainActor
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<16 {
            var viewport = app.frame.insetBy(dx: 8, dy: 60)
            let confirm = app.buttons["confirm-item-selection"]
            if confirm.exists {
                viewport.size.height = max(0, min(viewport.maxY, confirm.frame.minY - 24) - viewport.minY)
            }
            if element.exists, element.isHittable,
               viewport.contains(CGPoint(x: element.frame.midX, y: element.frame.midY)) { return }
            // Hittability alone is insufficient for off-screen controls in landscape.
            // Drag inside the visible scroll region, not over a sticky footer or sheet chrome.
            let from = app.coordinate(withNormalizedOffset: CGVector(
                dx: 0.5, dy: (viewport.minY + viewport.height * 0.8 - app.frame.minY) / app.frame.height
            ))
            let to = app.coordinate(withNormalizedOffset: CGVector(
                dx: 0.5, dy: (viewport.minY + viewport.height * 0.2 - app.frame.minY) / app.frame.height
            ))
            from.press(forDuration: 0.05, thenDragTo: to)
        }
    }

    @MainActor
    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
