import XCTest
@testable import Bide

/// Pure tests for the "What's new" gate. Pins the three rules:
/// onboarding-state respect, fresh-install suppression, and the
/// version-mismatch trigger.
final class WhatsNewPlannerTests: XCTestCase {

    // MARK: - Onboarding gate

    func test_doesNotShowDuringOnboarding_evenWithVersionMismatch() {
        XCTAssertFalse(
            WhatsNewPlanner.shouldShow(
                currentVersion: "1.1.0",
                lastSeenVersion: "1.0.0",
                hasCompletedOnboarding: false
            )
        )
    }

    func test_doesNotShowDuringOnboarding_evenForFreshInstall() {
        XCTAssertFalse(
            WhatsNewPlanner.shouldShow(
                currentVersion: "1.1.0",
                lastSeenVersion: nil,
                hasCompletedOnboarding: false
            )
        )
    }

    // MARK: - Fresh install suppression

    func test_freshInstall_neverShowsSheet() {
        XCTAssertFalse(
            WhatsNewPlanner.shouldShow(
                currentVersion: "1.1.0",
                lastSeenVersion: nil,
                hasCompletedOnboarding: true
            )
        )
    }

    func test_emptyLastSeen_isTreatedAsFreshInstall() {
        // The @AppStorage default is "" — equivalent to nil semantically.
        XCTAssertFalse(
            WhatsNewPlanner.shouldShow(
                currentVersion: "1.1.0",
                lastSeenVersion: "",
                hasCompletedOnboarding: true
            )
        )
    }

    // MARK: - Version mismatch

    func test_versionChange_triggersSheet() {
        XCTAssertTrue(
            WhatsNewPlanner.shouldShow(
                currentVersion: "1.1.0",
                lastSeenVersion: "1.0.0",
                hasCompletedOnboarding: true
            )
        )
    }

    func test_sameVersion_suppressesSheet() {
        XCTAssertFalse(
            WhatsNewPlanner.shouldShow(
                currentVersion: "1.1.0",
                lastSeenVersion: "1.1.0",
                hasCompletedOnboarding: true
            )
        )
    }

    func test_downgrade_alsoTriggersSheet() {
        // Downgrades happen when a TestFlight tester rolls back. Treat
        // any difference as "new to this user from this build" — the sheet
        // copy is informational, never harmful to over-trigger.
        XCTAssertTrue(
            WhatsNewPlanner.shouldShow(
                currentVersion: "1.0.0",
                lastSeenVersion: "1.1.0",
                hasCompletedOnboarding: true
            )
        )
    }

    func test_patchBumpTriggersSheet() {
        // A patch bump (1.1.0 → 1.1.1) ships in App Store updates too.
        // Showing the sheet on each patch may feel noisy but is harmless;
        // we'd add a separate "major-or-minor only" gate when we hit one.
        XCTAssertTrue(
            WhatsNewPlanner.shouldShow(
                currentVersion: "1.1.1",
                lastSeenVersion: "1.1.0",
                hasCompletedOnboarding: true
            )
        )
    }
}
