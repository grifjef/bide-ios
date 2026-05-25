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

    private let defaults: UserDefaults
    private static let onboardingKey = "bide.hasCompletedOnboarding"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.phase = defaults.bool(forKey: Self.onboardingKey) ? .ready : .onboarding
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
