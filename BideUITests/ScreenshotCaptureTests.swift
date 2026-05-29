import XCTest

/// Drives the app through the screens that don't require photo-library
/// content and saves each as a test attachment. Run explicitly to refresh
/// the in-repo preview screenshots:
///
///   xcodebuild test -scheme Bide \
///     -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
///     -only-testing:BideUITests/ScreenshotCaptureTests
///
/// Attachments land in the .xcresult bundle; a helper script copies them
/// into assets/screenshots-v1.2/. These are honest captures of the real
/// chrome — the seeded-library marketing set (with overlay text) is the
/// separate design pass described in docs/app-store-screenshots-v1.1.md.
final class ScreenshotCaptureTests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func capture(_ app: XCUIApplication, name: String) {
        let shot = app.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func test_captureKeyScreens() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTesting"]
        app.launch()
        XCTAssertTrue(app.navigationBars["Bide"].waitForExistence(timeout: 8))

        capture(app, name: "01-dashboard")

        // Settings.
        app.buttons["Settings and privacy"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 8))
        capture(app, name: "02-settings")

        // How Bide works.
        app.buttons["How Bide works"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["How Bide works"].waitForExistence(timeout: 8))
        capture(app, name: "03-how-bide-works")
        app.navigationBars.buttons.element(boundBy: 0).tap()

        // Acknowledgements.
        let ack = app.buttons["Acknowledgements"].firstMatch
        var attempts = 0
        while !ack.isHittable && attempts < 6 {
            app.swipeUp()
            attempts += 1
        }
        if ack.isHittable {
            ack.tap()
            XCTAssertTrue(app.navigationBars["Acknowledgements"].waitForExistence(timeout: 8))
            capture(app, name: "04-acknowledgements")
        }
    }
}
