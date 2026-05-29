import Foundation
import Observation

/// Top-level app state — owns the navigation phase (onboarding vs. ready).
/// Auth status lives on PhotoLibraryService; AppState only reads it.
@Observable
@MainActor
final class AppState {
    enum Phase: Equatable {
        case onboarding
        case ready
    }

    var phase: Phase

    /// Set when iOS hands us a Quick Action (cold launch or warm).
    /// `DashboardView` consumes and clears it on `.task` / `.onChange`.
    var pendingShortcut: ShortcutAction?

    private let defaults: UserDefaults
    private static let onboardingKey = "bide.hasCompletedOnboarding"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // Under XCUITest, skip onboarding so the dashboard is reachable
        // for navigation smoke tests without driving the system photo
        // permission dialog.
        if UITestMode.isActive {
            self.phase = .ready
        } else {
            self.phase = defaults.bool(forKey: Self.onboardingKey) ? .ready : .onboarding
        }
    }

    /// Wire `NotificationCenter` to flip `pendingShortcut` when the app
    /// delegate broadcasts a shortcut tap. Called once from `BideApp.init`.
    func subscribeToShortcuts() {
        NotificationCenter.default.addObserver(
            forName: .bideShortcutAction,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let action = note.userInfo?["action"] as? ShortcutAction else { return }
            Task { @MainActor in
                self?.pendingShortcut = action
            }
        }
    }

    func consumePendingShortcut() -> ShortcutAction? {
        let action = pendingShortcut
        pendingShortcut = nil
        return action
    }

    func completeOnboarding() {
        defaults.set(true, forKey: Self.onboardingKey)
        withAnimationCompat {
            phase = .ready
        }
    }

    func resetForTesting() {
        defaults.removeObject(forKey: Self.onboardingKey)
        phase = .onboarding
    }
}

// Tiny shim so we can animate without importing SwiftUI in the state layer.
@MainActor
private func withAnimationCompat(_ body: () -> Void) {
    body()
}
