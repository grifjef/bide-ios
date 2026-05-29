import XCTest

final class BideUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// Launch the app in UI-test mode: onboarding is skipped and module
    /// cards stay tappable in the simulator (which has no photo library),
    /// so navigation smoke tests can reach each module screen.
    private func launchInTestMode() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTesting"]
        app.launch()
        return app
    }

    // MARK: - Launch

    func test_appLaunches() throws {
        let app = launchInTestMode()
        XCTAssertTrue(
            app.navigationBars["Bide"].waitForExistence(timeout: 8),
            "Dashboard should appear with the Bide title"
        )
    }

    // MARK: - Per-module navigation smoke tests

    /// Each module card, tapped from the dashboard, should push a screen
    /// whose navigation bar carries the expected title. The modules show
    /// their empty states (no photos in the sim) — we're asserting the
    /// navigation wiring and that each screen renders without crashing.
    func test_navigateToEachModule() throws {
        let app = launchInTestMode()
        XCTAssertTrue(app.navigationBars["Bide"].waitForExistence(timeout: 8))

        let modules: [(card: String, title: String)] = [
            ("Exact duplicates", "Exact duplicates"),
            ("Screen recordings", "Screen recordings"),
            ("Large videos", "Large videos"),
            ("Screenshots", "Screenshots"),
            ("Live Photos", "Live Photos"),
            ("Similar photos", "Similar photos"),
            ("Blurry shots", "Blurry shots")
        ]

        for module in modules {
            let card = app.buttons.containing(
                NSPredicate(format: "label CONTAINS[c] %@", module.card)
            ).firstMatch

            // Scroll the card into view if needed, then tap.
            if !card.isHittable {
                app.swipeUp()
            }
            guard card.waitForExistence(timeout: 5) else {
                XCTFail("Card not found: \(module.card)")
                continue
            }
            card.tap()

            XCTAssertTrue(
                app.navigationBars[module.title].waitForExistence(timeout: 8),
                "Expected to land on \(module.title)"
            )

            app.navigationBars.buttons.element(boundBy: 0).tap() // back
            XCTAssertTrue(app.navigationBars["Bide"].waitForExistence(timeout: 8))

            // Reset scroll for the next lookup.
            app.swipeDown()
        }
    }

    // MARK: - Settings navigation

    func test_settingsAndAcknowledgementsNavigate() throws {
        let app = launchInTestMode()
        XCTAssertTrue(app.navigationBars["Bide"].waitForExistence(timeout: 8))

        // Open Settings via the gear toolbar button.
        app.buttons["Settings and privacy"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 8))

        // Acknowledgements lives in the About section near the bottom of
        // the list. Scroll it into view with a bounded loop before tapping
        // — robust against varying screen heights / Dynamic Type.
        let ack = app.buttons["Acknowledgements"].firstMatch
        var attempts = 0
        while !ack.isHittable && attempts < 6 {
            app.swipeUp()
            attempts += 1
        }
        XCTAssertTrue(ack.isHittable, "Acknowledgements row should be reachable by scrolling")
        ack.tap()
        XCTAssertTrue(app.navigationBars["Acknowledgements"].waitForExistence(timeout: 8))
    }
}
