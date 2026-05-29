import UIKit

/// Centralized haptic feedback for Bide. One place to tune intensity, one
/// place to gate against Reduce Motion (Apple's HIG: respect the
/// "Reduce Motion" setting for haptics that aren't directly tied to a
/// user touch).
///
/// Usage:
/// ```
/// BideHaptics.selection()
/// BideHaptics.success()
/// BideHaptics.warning()
/// ```
///
/// Each call is fire-and-forget. The generators are recreated per-call
/// because UIKit's docs warn against retaining feedback generators long
/// term — keeping them alive holds the Taptic engine warm and drains
/// battery measurably.
enum BideHaptics {
    /// Light tap — used for selection toggles in module rows and basket
    /// add/remove. The most common Bide haptic.
    static func selection() {
        guard !isReduceMotionOn() else { return }
        let g = UISelectionFeedbackGenerator()
        g.prepare()
        g.selectionChanged()
    }

    /// Soft impact — used when an item moves into the Review Basket from
    /// a long-press or bulk-add path. Distinct from `selection()` so the
    /// user feels the basket act differently than a row toggle.
    static func basketAdd() {
        guard !isReduceMotionOn() else { return }
        let g = UIImpactFeedbackGenerator(style: .soft)
        g.prepare()
        g.impactOccurred()
    }

    /// Success notification — used on session completion (deletion
    /// confirmed) and Live Photo conversion success. The system success
    /// pattern is recognizable iOS-wide; no need to invent our own.
    static func success() {
        guard !isReduceMotionOn() else { return }
        let g = UINotificationFeedbackGenerator()
        g.prepare()
        g.notificationOccurred(.success)
    }

    /// Warning notification — used when a user tries an action that
    /// fails non-fatally (e.g. Live Photo conversion blocked by an
    /// iCloud-only resource). The system warning pattern.
    static func warning() {
        guard !isReduceMotionOn() else { return }
        let g = UINotificationFeedbackGenerator()
        g.prepare()
        g.notificationOccurred(.warning)
    }

    /// Read the "Reduce Motion" accessibility setting. UIKit's
    /// `UIAccessibility.isReduceMotionEnabled` is the source of truth;
    /// the SwiftUI `@Environment(\.accessibilityReduceMotion)` value
    /// is plumbed from here.
    private static func isReduceMotionOn() -> Bool {
        UIAccessibility.isReduceMotionEnabled
    }
}
