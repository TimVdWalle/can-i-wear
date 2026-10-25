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
    func testSingleJacketHeroKeepsAdviceAndDaypartsInInitialViewport() {
        for (scenario, title) in [
            ("okay", "Good for the rest of today"),
            ("periods", "Avoid during wet weather"),
            ("fog", "Avoid during fog or mist")
        ] {
            let app = launch(scenario, flags: ["-home_introduction_visible", "NO"], mode: "guided")
            let hero = app.descendants(matching: .any)["recommendation-hero"]
            XCTAssertTrue(hero.waitForExistence(timeout: 5))
            XCTAssertTrue(hero.label.contains(title), hero.label)
            XCTAssertFalse(hero.label.contains("06:00–24:00"), "Do not repeat the full-day schedule")
            let viewport = app.frame.insetBy(dx: 0, dy: 44)
            XCTAssertTrue(viewport.contains(hero.frame))
            XCTAssertLessThanOrEqual(hero.frame.height, 230, "Standard-size advice should remain compact")
            for index in 0..<3 {
                let daypart = app.descendants(matching: .any)["period-\(index)"]
                XCTAssertTrue(daypart.exists)
                XCTAssertTrue(viewport.contains(daypart.frame), "Dayparts must fit before scrolling")
            }
            capture(app, "Single jacket hero — \(scenario)")
            app.terminate()
        }
    }

    @MainActor
    func testLargestTextSingleJacketRetainsCompleteAdviceAndScrolling() {
        let app = launch("periods", flags: [
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
        ])
        let hero = app.descendants(matching: .any)["recommendation-hero"]
        XCTAssertTrue(hero.waitForExistence(timeout: 5))
        XCTAssertTrue(hero.label.contains("Leather Jacket. NO. Avoid during wet weather"))
        XCTAssertTrue(hero.label.contains("could damage leather"))
        XCTAssertLessThanOrEqual(hero.frame.width, app.frame.width - 32)
        capture(app, "Single jacket hero — largest text")
        let timeline = app.staticTexts["hourly-timeline"]
        reveal(timeline, in: app)
        XCTAssertTrue(timeline.isHittable)
    }

    @MainActor
    func testQualifiersHighlightLateEveningAndEarlyMorningExceptions() {
        for (scenario, answer, qualifier, evening) in [
            ("items-late-evening", "YES", "Suitable 22:00–24:00", "NO"),
            ("items-early-morning", "NO", "Avoid 00:00–06:00", "YES")
        ] {
            let app = launch(scenario, flags: [
                "-ui-test-items", "leatherJacket", "-home_introduction_visible", "NO"
            ], mode: "guided")
            let hero = app.descendants(matching: .any)["recommendation-hero"]
            XCTAssertTrue(hero.waitForExistence(timeout: 5))
            XCTAssertTrue(hero.label.contains("Leather Jacket. \(answer)."))
            XCTAssertTrue(hero.label.contains(qualifier), hero.label)
            XCTAssertTrue(app.descendants(matching: .any)["period-2"].label.contains(evening))
            XCTAssertEqual(app.staticTexts["day-parts-heading"].label, "When can I wear it?")
            capture(app, "Single jacket — \(scenario) exception")
            app.terminate()
        }
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
    func testOverviewFitsTwoCompleteCardsWithReadableTimePreviews() {
        let app = launch("items-mixed", flags: [
            "-ui-test-items", "leatherJacket,sunglasses", "-home_introduction_visible", "NO"
        ], mode: "guided")
        let jacket = app.buttons["item-card-leatherJacket"]
        XCTAssertTrue(jacket.waitForExistence(timeout: 5))
        let sun = app.buttons["item-card-sunglasses"]
        let viewport = app.frame.insetBy(dx: 0, dy: 44)
        for card in [jacket, sun] {
            XCTAssertTrue(viewport.contains(card.frame), "Two complete standard-size cards should fit without scrolling")
            XCTAssertLessThanOrEqual(card.frame.height, 250, "Compact jacket-style cards must be shorter than the previous layout")
        }
        XCTAssertTrue(jacket.label.contains("Avoid during wet weather"))
        XCTAssertTrue(jacket.label.hasPrefix("Leather Jacket. NO."))
        XCTAssertTrue(jacket.label.contains("15:00–18:00"))
        XCTAssertTrue(sun.label.contains("Useful today"))
        XCTAssertTrue(sun.label.hasPrefix("Sunglasses. YES."))
        XCTAssertTrue(sun.label.contains("12:00–15:00"))
        capture(app, "Multi-item Home — compact cards and time previews")
        jacket.tap()
        let detail = app.scrollViews["item-detail"]
        XCTAssertTrue(detail.waitForExistence(timeout: 5))
        XCTAssertTrue(detail.descendants(matching: .any)["recommendation-hero"].label.contains("Leather Jacket. NO."))
        XCTAssertTrue(detail.descendants(matching: .any)["period-1"].label.contains("Afternoon"))
    }

    @MainActor
    func testThreeMiniHeroesFitInitialViewportInGuidedAndCompactModes() {
        for mode in ["guided", "compact"] {
            let app = launch("items-mixed", flags: [
                "-ui-test-items", "leatherJacket,sunglasses,sweater", "-home_introduction_visible", "NO",
                "-AppleInterfaceStyle", mode == "guided" ? "Light" : "Dark"
            ], mode: mode)
            XCTAssertTrue(app.buttons["item-card-leatherJacket"].waitForExistence(timeout: 5))
            XCTAssertTrue(app.descendants(matching: .any)["item-mini-heroes"].exists)
            let viewport = app.frame.insetBy(dx: 0, dy: 44)
            var previousBottom: CGFloat = 0
            // Saved order is catalog order, not the order in the launch argument.
            for item in ["leatherJacket", "sweater", "sunglasses"] {
                let card = app.buttons["item-card-\(item)"]
                XCTAssertTrue(viewport.contains(card.frame), "Three complete cards must fit: \(item) \(card.frame)")
                XCTAssertGreaterThanOrEqual(card.frame.minY, previousBottom)
                XCTAssertGreaterThanOrEqual(card.frame.height, 150, "Keep artwork and daypart context, not compressed rows")
                previousBottom = card.frame.maxY
            }
            capture(app, "D-075 — three mini heroes, \(mode)")
            app.terminate()
        }
    }

    @MainActor
    func testFourAndSevenItemsUseTwoColumnGalleryAndEveryCardOpensMatchingDetail() {
        let catalog = ["leatherJacket", "warmCoat", "sweater", "raincoat", "sunglasses", "shorts", "gloves"]
        for count in [4, 7] {
            let items = Array(catalog.prefix(count))
            let app = launch("items-mixed", flags: [
                "-ui-test-items", items.joined(separator: ","), "-home_introduction_visible", "NO",
                "-AppleInterfaceStyle", count == 4 ? "Light" : "Dark"
            ])
            let first = app.buttons["item-card-leatherJacket"]
            XCTAssertTrue(first.waitForExistence(timeout: 5))
            XCTAssertTrue(app.descendants(matching: .any)["item-gallery"].exists)
            let second = app.buttons["item-card-warmCoat"]
            let third = app.buttons["item-card-sweater"]
            XCTAssertEqual(first.frame.minY, second.frame.minY, accuracy: 1)
            XCTAssertEqual(first.frame.width, second.frame.width, accuracy: 1)
            XCTAssertGreaterThan(second.frame.minX, first.frame.maxX)
            XCTAssertGreaterThanOrEqual(third.frame.minY, first.frame.maxY)
            XCTAssertEqual(third.frame.minX, first.frame.minX, accuracy: 1)
            capture(app, "D-075 — \(count)-item gallery")
            XCTAssertTrue(app.frame.insetBy(dx: 0, dy: 44).contains(app.buttons["item-card-raincoat"].frame),
                          "Four ordinary gallery cards must be readable in the initial viewport: \(app.buttons["item-card-raincoat"].frame)")
            for item in items {
                let card = app.buttons["item-card-\(item)"]
                reveal(card, in: app)
                XCTAssertTrue(card.isHittable)
                card.tap()
                let detail = app.scrollViews["item-detail"]
                XCTAssertTrue(detail.waitForExistence(timeout: 5))
                let hero = detail.descendants(matching: .any)["recommendation-hero"]
                XCTAssertTrue(hero.label.hasPrefix(cardName(item) + "."), hero.label)
                app.buttons["Done"].tap()
            }
            app.terminate()
        }
    }

    @MainActor
    func testSelectionEditsCrossSingleMiniHeroAndGalleryBoundariesWithoutLosingSelection() {
        let app = launch("items-mixed", flags: ["-ui-test-items", "leatherJacket", "-home_introduction_visible", "NO"])
        XCTAssertTrue(app.descendants(matching: .any)["recommendation-hero"].waitForExistence(timeout: 5))
        for (item, count) in [("warmCoat", 2), ("sweater", 3), ("raincoat", 4), ("raincoat", 3)] {
            app.buttons["configure-items"].tap()
            app.buttons["select-item-\(item)"].tap()
            XCTAssertEqual(app.staticTexts["selection-count"].label, "\(count) selected")
            app.buttons["confirm-item-selection"].tap()
            let identifier = count >= 4 ? "item-gallery" : "item-mini-heroes"
            XCTAssertTrue(app.descendants(matching: .any)[identifier].waitForExistence(timeout: 5))
            XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'item-card-'")).count, count)
        }
        app.terminate()
        app.launchArguments = ["-ui-test-scenario", "items-mixed", "-ui-test-home-mode", "compact", "-ui-test-preserve-selection"]
        app.launch()
        XCTAssertTrue(app.buttons["item-card-sweater"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["item-card-raincoat"].exists)
    }

    @MainActor
    func testGalleryAdaptsColumnCountToViewportWidth() {
        let app = launch("items-mixed", flags: [
            "-ui-test-items", "leatherJacket,warmCoat,sweater,raincoat", "-home_introduction_visible", "NO"
        ])
        let first = app.buttons["item-card-leatherJacket"]
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        let second = app.buttons["item-card-warmCoat"]
        if app.frame.width < 382 {
            XCTAssertEqual(first.frame.width, app.frame.width - 32, accuracy: 1)
            XCTAssertGreaterThanOrEqual(second.frame.minY, first.frame.maxY)
        } else {
            XCTAssertEqual(first.frame.minY, second.frame.minY, accuracy: 1)
            XCTAssertGreaterThan(second.frame.minX, first.frame.maxX)
        }
        capture(app, "D-075 — gallery viewport adaptation")
        let final = app.buttons["item-card-raincoat"]
        reveal(final, in: app)
        XCTAssertTrue(final.isHittable)
        final.tap()
        XCTAssertTrue(app.scrollViews["item-detail"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testOverviewReadabilityWithPhoneSelectionAndLargerGalleryText() {
        let app = launch("items-mixed", flags: [
            "-ui-test-items", "leatherJacket,sunglasses,gloves", "-home_introduction_visible", "NO"
        ])
        XCTAssertTrue(app.buttons["item-card-leatherJacket"].waitForExistence(timeout: 5))
        let viewport = app.frame.insetBy(dx: 0, dy: 44)
        for item in ["leatherJacket", "sunglasses", "gloves"] {
            let card = app.buttons["item-card-\(item)"]
            XCTAssertTrue(viewport.contains(card.frame), "The phone's three items must remain fully visible")
            assertNamedDayparts(in: card, finishedParts: 0)
        }
        capture(app, "Restored icons and larger copy — phone selection")
        app.terminate()

        let larger = launch("items-uncertain", flags: [
            "-ui-test-items", "leatherJacket,sweater,raincoat,sunglasses", "-home_introduction_visible", "NO",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryXXXL"
        ])
        let first = larger.buttons["item-card-leatherJacket"]
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        XCTAssertEqual(first.frame.width, larger.frame.width - 32, accuracy: 1)
        let sun = larger.buttons["item-card-sunglasses"]
        reveal(sun, in: larger)
        XCTAssertTrue(sun.isHittable)
        XCTAssertTrue(sun.label.contains("One forecast hour is uncertain"))
        XCTAssertLessThanOrEqual(sun.frame.width, larger.frame.width - 32)
        assertNamedDayparts(in: sun, finishedParts: 0)
        capture(larger, "Restored icons and larger copy — XXXL gallery reflow")
        sun.tap()
        XCTAssertTrue(larger.scrollViews["item-detail"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testGalleryReflowsAtLargestTextAndRetainsQualifiersAndUnavailableAdvice() {
        for (scenario, expected) in [("items-brief", "Briefly useful"), ("items-uncertain", "One forecast hour is uncertain"),
                                     ("items-unavailable", "Not enough forecast data")] {
            let app = launch(scenario, flags: [
                "-ui-test-items", "leatherJacket,sweater,raincoat,sunglasses", "-home_introduction_visible", "NO",
                "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
            ])
            let first = app.buttons["item-card-leatherJacket"]
            XCTAssertTrue(first.waitForExistence(timeout: 5))
            XCTAssertTrue(app.descendants(matching: .any)["item-gallery"].exists)
            XCTAssertEqual(first.frame.width, app.frame.width - 32, accuracy: 1)
            let sun = app.buttons["item-card-sunglasses"]
            reveal(sun, in: app)
            XCTAssertTrue(sun.isHittable)
            XCTAssertTrue(sun.label.contains(expected), sun.label)
            XCTAssertLessThanOrEqual(sun.frame.width, app.frame.width - 32)
            if scenario == "items-unavailable" {
                XCTAssertFalse(sun.label.contains("Sunglasses. NO."))
                XCTAssertFalse(sun.descendants(matching: .any)["period-0"].exists)
            } else {
                XCTAssertTrue(sun.descendants(matching: .any)["period-2"].exists)
            }
            capture(app, "D-075 — largest text gallery, \(scenario)")
            app.terminate()
        }
    }

    @MainActor
    func testGalleryRemainsScrollableInDarkLandscape() {
        let app = launch("items-last-hour", flags: [
            "-ui-test-items", "leatherJacket,warmCoat,sweater,raincoat,sunglasses,shorts,gloves",
            "-home_introduction_visible", "NO", "-AppleInterfaceStyle", "Dark"
        ])
        XCTAssertTrue(app.buttons["item-card-leatherJacket"].waitForExistence(timeout: 5))
        capture(app, "D-075 — dark gallery at night")
        XCUIDevice.shared.orientation = .landscapeLeft
        let gloves = app.buttons["item-card-gloves"]
        reveal(gloves, in: app)
        XCTAssertTrue(gloves.isHittable)
        XCTAssertLessThanOrEqual(gloves.frame.width, app.frame.width)
        capture(app, "D-075 — dark landscape gallery, final item")
        gloves.tap()
        XCTAssertTrue(app.scrollViews["item-detail"].waitForExistence(timeout: 5))
    }

    private func cardName(_ item: String) -> String {
        ["leatherJacket": "Leather Jacket", "warmCoat": "Warm Coat", "sweater": "Sweater", "raincoat": "Raincoat",
         "sunglasses": "Sunglasses", "shorts": "Shorts", "gloves": "Gloves"][item] ?? item
    }

    @MainActor
    func testAllDayPeriodsRemainVisibleAtNightWithPastPeriodsMarkedFinished() {
        let app = launch("items-last-hour", flags: [
            "-ui-test-items", "leatherJacket,sunglasses", "-home_introduction_visible", "NO"
        ], mode: "guided")
        let jacket = app.buttons["item-card-leatherJacket"]
        XCTAssertTrue(jacket.waitForExistence(timeout: 5))
        for (index, name, range) in [(0, "Morning", "06–12"), (1, "Afternoon", "12–18"), (2, "Evening", "18–24")] {
            let daypart = jacket.descendants(matching: .any)["period-\(index)"]
            XCTAssertTrue(daypart.label.contains(name))
            XCTAssertTrue(daypart.label.contains(range))
            XCTAssertEqual(daypart.label.contains("finished for today"), index < 2)
        }
        XCTAssertFalse(jacket.descendants(matching: .any)["period-3"].exists)
        let sunglasses = app.buttons["item-card-sunglasses"]
        for (index, name) in ["Morning", "Afternoon", "Evening"].enumerated() {
            let tile = sunglasses.descendants(matching: .any)["period-\(index)"]
            XCTAssertTrue(tile.label.contains(name))
            XCTAssertEqual(tile.label.contains("finished for today"), index < 2)
        }
        XCTAssertTrue(app.buttons["item-card-sunglasses"].label.contains("Not needed today"))
        capture(app, "Multi-item Home — full day retained at 23:30")
        app.buttons["item-card-sunglasses"].tap()
        let detail = app.scrollViews["item-detail"]
        XCTAssertTrue(detail.waitForExistence(timeout: 5))
        let afternoon = detail.descendants(matching: .any)["period-1"]
        XCTAssertTrue(afternoon.label.contains("Afternoon, 12–18, YES"))
        XCTAssertTrue(afternoon.label.contains("12:00–15:00, Useful"))
        XCTAssertTrue(afternoon.label.contains("finished for today"))
        XCTAssertTrue(detail.descendants(matching: .any)["recommendation-hero"].label.contains("Sunglasses. NO."))
        capture(app, "Sunglasses detail — full day retained at 23:30")
    }

    @MainActor
    func testJacketKeepsExactlyThreeNamedDaypartsEvenWhenWeatherHasFourPeriods() {
        let app = launch("items-jacket-four-periods", flags: [
            "-ui-test-items", "leatherJacket,sunglasses", "-home_introduction_visible", "NO"
        ], mode: "guided")
        let jacket = app.buttons["item-card-leatherJacket"]
        XCTAssertTrue(jacket.waitForExistence(timeout: 5))
        for (index, name) in ["Morning", "Afternoon", "Evening"].enumerated() {
            XCTAssertTrue(jacket.descendants(matching: .any)["period-\(index)"].label.contains(name))
        }
        XCTAssertFalse(jacket.descendants(matching: .any)["period-3"].exists)
        capture(app, "Leather Jacket overview — exactly three dayparts")
        jacket.tap()
        let detail = app.scrollViews["item-detail"]
        XCTAssertTrue(detail.waitForExistence(timeout: 5))
        for (index, name) in ["Morning", "Afternoon", "Evening"].enumerated() {
            XCTAssertTrue(detail.descendants(matching: .any)["period-\(index)"].label.contains(name))
        }
        XCTAssertFalse(detail.descendants(matching: .any)["period-3"].exists)
        capture(app, "Leather Jacket detail — exactly three dayparts")
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
        XCTAssertTrue(detail.descendants(matching: .any)["recommendation-hero"].label.contains("Sunglasses. YES. Useful today"))
        XCTAssertTrue(detail.descendants(matching: .any)["period-1"].label.contains("12:00–15:00, Useful"))
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
            for range in time.components(separatedBy: " · ") {
                let period = app.descendants(matching: .any).matching(NSPredicate(
                    format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "period-", range
                )).firstMatch
                XCTAssertTrue(period.exists, "Detailed timing remains in the periods: \(range)")
            }
            if scenario == "items-brief" {
                XCTAssertTrue(hero.label.contains("MAYBE. Briefly useful"))
                XCTAssertTrue(hero.label.contains(time))
            } else {
                XCTAssertFalse(hero.label.contains(time), "Do not duplicate the period schedule in the hero")
            }
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
        XCTAssertFalse(detail.descendants(matching: .any)["period-0"].exists)
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
        let finalPeriod = detail.descendants(matching: .any)["period-2"]
        reveal(finalPeriod, in: app)
        XCTAssertTrue(finalPeriod.isHittable)
        capture(app, "Sunglasses detail — accessibility text")
    }

    @MainActor
    func testEveryItemUsesThreeNamedDaypartsOnSingleHomeOverviewAndDetail() {
        let items = ["leatherJacket", "warmCoat", "sweater", "raincoat", "sunglasses", "shorts", "gloves"]
        for item in items {
            let app = launch("items-last-hour", flags: ["-ui-test-items", item, "-home_introduction_visible", "NO"])
            XCTAssertTrue(app.descendants(matching: .any)["recommendation-hero"].waitForExistence(timeout: 5))
            assertNamedDayparts(in: app)
            assertCompactTimeline(in: app, item: item)
            capture(app, "\(item) single Home — three dayparts at night")
            app.terminate()
        }
        let app = launch("items-evening-sun", flags: [
            "-ui-test-items", items.joined(separator: ","), "-home_introduction_visible", "NO"
        ])
        XCTAssertTrue(app.buttons["item-card-leatherJacket"].waitForExistence(timeout: 5))
        for item in items {
            let card = app.buttons["item-card-\(item)"]
            reveal(card, in: app)
            assertNamedDayparts(in: card)
            card.tap()
            let detail = app.scrollViews["item-detail"]
            XCTAssertTrue(detail.waitForExistence(timeout: 5))
            assertNamedDayparts(in: detail)
            assertCompactTimeline(in: detail, item: item)
            if item == "sunglasses" {
                let evening = detail.descendants(matching: .any)["period-2"]
                XCTAssertTrue(evening.label.contains("Evening, 18–24, YES"))
                XCTAssertTrue(evening.label.contains("18:00–19:00, Useful"))
                XCTAssertTrue(evening.label.contains("19:00–24:00, Not needed"))
                capture(app, "Sunglasses screenshot regression — three named cards")
            }
            app.buttons["Done"].tap()
        }
    }

    @MainActor
    private func assertCompactTimeline(in scope: XCUIElement, item: String) {
        let prefix = item == "leatherJacket" ? "hour" : "item-hour"
        let first = scope.descendants(matching: .any)["\(prefix)-0"]
        XCTAssertTrue(first.exists)
        for index in 0..<18 {
            let hour = scope.descendants(matching: .any)["\(prefix)-\(index)"]
            XCTAssertTrue(hour.exists)
            XCTAssertEqual(hour.frame.minY, first.frame.minY, accuracy: 1)
            XCTAssertLessThanOrEqual(hour.frame.width, 24, "Raw hours must be compact segments, not large tiles")
            XCTAssertLessThanOrEqual(hour.frame.height, 70)
        }
        XCTAssertFalse(scope.descendants(matching: .any)["\(prefix)-18"].exists)
    }

    @MainActor
    private func assertNamedDayparts(in scope: XCUIElement, finishedParts: Int = 2) {
        let first = scope.descendants(matching: .any)["period-0"]
        for (index, name, range) in [(0, "Morning", "06–12"), (1, "Afternoon", "12–18"), (2, "Evening", "18–24")] {
            let part = scope.descendants(matching: .any)["period-\(index)"]
            XCTAssertTrue(part.exists)
            XCTAssertTrue(part.label.contains("\(name), \(range)"), part.label)
            XCTAssertEqual(part.label.contains("finished for today"), index < finishedParts)
            XCTAssertEqual(part.frame.minY, first.frame.minY, accuracy: 1, "The three dayparts must share one row")
            XCTAssertEqual(part.frame.width, first.frame.width, accuracy: 1)
            XCTAssertLessThanOrEqual(part.frame.height, 150, "Standard-size dayparts must not expand into unused screen space")
        }
        XCTAssertFalse(scope.descendants(matching: .any)["period-3"].exists)
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
