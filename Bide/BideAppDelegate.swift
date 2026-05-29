import CoreSpotlight
import UIKit

/// Tiny `UIApplicationDelegate` bridge for the things SwiftUI's `App`
/// protocol doesn't expose cleanly yet — Quick Actions registration
/// and delivery, Spotlight indexing on cold launch, and the
/// continue-user-activity continuation for Spotlight taps.
///
/// Bound via `@UIApplicationDelegateAdaptor(BideAppDelegate.self)` in
/// `BideApp`. Keep this file small; reach for it only when the system
/// requires `UIApplicationDelegate` semantics specifically.
final class BideAppDelegate: NSObject, UIApplicationDelegate {
    /// Set when iOS launches Bide directly from a Quick Action tap. Drained
    /// by `BideApp` on first scene activation.
    var coldLaunchShortcut: UIApplicationShortcutItem?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Register the three Quick Action menu items. Runtime registration
        // (rather than Info.plist's `UIApplicationShortcutItems`) lets us
        // keep using xcodegen's GENERATE_INFOPLIST_FILE and still have
        // shortcuts. The first cold launch installs them; they persist on
        // the springboard from then on.
        application.shortcutItems = [
            ShortcutAction.findClutter.toShortcutItem(),
            ShortcutAction.onThisDay.toShortcutItem(),
            ShortcutAction.reviewBasket.toShortcutItem()
        ]

        // Cold launch via shortcut: iOS passes the item through
        // launchOptions and does NOT call `performActionFor` separately.
        // Stash for `BideApp` to consume.
        if let shortcut = launchOptions?[.shortcutItem] as? UIApplicationShortcutItem {
            coldLaunchShortcut = shortcut
        }

        // Refresh the Spotlight index. Idempotent — Spotlight dedupes on
        // uniqueIdentifier — so re-running on every cold launch keeps
        // copy edits propagating without a one-shot migration.
        Task { @MainActor in
            BideSpotlightIndexer.indexAll()
        }
        return true
    }

    /// Continuation path: user tapped a Bide result in Spotlight.
    /// `userActivity.uniqueIdentifier` carries the same value we used in
    /// `CSSearchableItem.uniqueIdentifier`, so decoding the right
    /// destination is a single dictionary lookup.
    func application(
        _ application: UIApplication,
        continue userActivity: NSUserActivity,
        restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
    ) -> Bool {
        guard userActivity.activityType == CSSearchableItemActionType,
              let identifier = userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String
        else { return false }

        // Map back to a ShortcutAction when the Spotlight result is one of
        // the three we already deep-link from Quick Actions. Anything else
        // just opens Bide — the dashboard is the right landing for those.
        if let module = ModuleSpotlight(rawValue: identifier),
           let action = module.equivalentShortcut {
            NotificationCenter.default.post(
                name: .bideShortcutAction,
                object: nil,
                userInfo: ["action": action]
            )
        }
        return true
    }

    /// Warm-launch path: app already running, user taps a Quick Action.
    /// iOS calls this on the foreground transition.
    func application(
        _ application: UIApplication,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        let success = handle(shortcutItem: shortcutItem)
        completionHandler(success)
    }

    /// Decode the platform shortcut into our enum and broadcast. Returns
    /// `true` when we recognized the action, `false` otherwise.
    @discardableResult
    func handle(shortcutItem: UIApplicationShortcutItem) -> Bool {
        guard let action = ShortcutAction(rawValue: shortcutItem.type) else {
            return false
        }
        NotificationCenter.default.post(
            name: .bideShortcutAction,
            object: nil,
            userInfo: ["action": action]
        )
        return true
    }
}
