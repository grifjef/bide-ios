import Foundation

/// Single source of truth for "are we running under XCUITest?" Detected
/// from a launch argument the UI test bundle passes. Used to skip
/// onboarding and keep module cards tappable in the simulator (which has
/// no photo library and no granted authorization), so navigation smoke
/// tests can reach each module screen.
///
/// Deliberately tiny and read-only: test mode never changes app behavior
/// beyond making the UI reachable. It does NOT fake scan results — the
/// modules still show their genuine empty states in the sim.
enum UITestMode {
    /// Pass `-uiTesting` in the test bundle's `launchArguments`.
    static let isActive = ProcessInfo.processInfo.arguments.contains("-uiTesting")
}
