@testable import Bide
import XCTest

@MainActor
final class AppStateTests: XCTestCase {
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        let suiteName = "bide.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults = nil
        super.tearDown()
    }

    func test_initialState_isOnboarding_whenNoFlagSet() {
        let state = AppState(defaults: defaults)
        XCTAssertEqual(state.phase, .onboarding)
    }

    func test_initialState_isReady_whenOnboardingPreviouslyCompleted() {
        defaults.set(true, forKey: "bide.hasCompletedOnboarding")
        let state = AppState(defaults: defaults)
        XCTAssertEqual(state.phase, .ready)
    }

    func test_completeOnboarding_movesToReady_andPersistsFlag() {
        let state = AppState(defaults: defaults)
        state.completeOnboarding()
        XCTAssertEqual(state.phase, .ready)
        XCTAssertTrue(defaults.bool(forKey: "bide.hasCompletedOnboarding"))
    }

    func test_resetForTesting_movesBackToOnboarding() {
        let state = AppState(defaults: defaults)
        state.completeOnboarding()
        state.resetForTesting()
        XCTAssertEqual(state.phase, .onboarding)
        XCTAssertFalse(defaults.bool(forKey: "bide.hasCompletedOnboarding"))
    }
}
