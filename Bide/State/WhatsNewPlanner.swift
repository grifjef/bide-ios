import Foundation

/// Pure decision: should the "What's new in X.Y" sheet appear on this
/// app launch? Three rules:
///   1. Never during onboarding.
///   2. Fresh installs (no recorded prior version) don't see it — they're
///      already meeting the whole app for the first time.
///   3. Returning users see it once per version change.
///
/// Tested without UIKit, SwiftUI, or `Bundle.main` so we can pin the
/// boundaries on the gating logic.
enum WhatsNewPlanner {
    static func shouldShow(
        currentVersion: String,
        lastSeenVersion: String?,
        hasCompletedOnboarding: Bool
    ) -> Bool {
        guard hasCompletedOnboarding else { return false }
        guard let lastSeenVersion, !lastSeenVersion.isEmpty else { return false }
        return lastSeenVersion != currentVersion
    }
}
