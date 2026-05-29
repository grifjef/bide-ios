import Foundation
import UIKit

/// Stable identifiers for Bide's home-screen Quick Actions (long-press
/// app icon). The raw value is what iOS persists in
/// `UIApplication.shared.shortcutItems`, so renaming a case is a
/// migration — old shortcuts already on the user's springboard would
/// stop matching. Add new cases freely; keep existing raw values.
enum ShortcutAction: String, Sendable {
    case findClutter   = "com.bidephoto.bide.shortcut.findClutter"
    case onThisDay     = "com.bidephoto.bide.shortcut.onThisDay"
    case reviewBasket  = "com.bidephoto.bide.shortcut.reviewBasket"

    /// Display string. Localizable later (step 14 of the plan).
    var title: String {
        switch self {
        case .findClutter:  return "Find clutter"
        case .onThisDay:    return "On this day"
        case .reviewBasket: return "Review basket"
        }
    }

    /// iOS-provided icon glyph. We use the system shortcut icon set so the
    /// glyphs match the iOS visual language (and so we don't need to ship
    /// new assets at launch).
    var systemIconType: UIApplicationShortcutIcon.IconType {
        switch self {
        case .findClutter:  return .search
        case .onThisDay:    return .date
        case .reviewBasket: return .invitation
        }
    }

    /// Materialize as the platform type for `UIApplication.shortcutItems`.
    func toShortcutItem() -> UIApplicationShortcutItem {
        UIApplicationShortcutItem(
            type: rawValue,
            localizedTitle: title,
            localizedSubtitle: nil,
            icon: UIApplicationShortcutIcon(type: systemIconType),
            userInfo: nil
        )
    }
}

/// Notification name fired when iOS asks us to perform a shortcut action.
/// `AppState` listens; `DashboardView` reads `AppState.pendingShortcut`
/// to deep-link.
extension Notification.Name {
    static let bideShortcutAction = Notification.Name("bide.shortcutAction")
}
