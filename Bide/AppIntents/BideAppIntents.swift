import AppIntents
import Foundation

// Bide's surface in the iOS Shortcuts app, Spotlight suggestions, and
// "Hey Siri." All three intents below open the app to the right
// destination by piggybacking on the same notification pipeline Quick
// Actions use (`ShortcutAction` + `Notification.bideShortcutAction`),
// so there's exactly one routing layer to maintain.
//
// Each intent's `perform()` opens the app (`openAppWhenRun = true`)
// and posts the matching `ShortcutAction`. `BideAppDelegate` /
// `DashboardView` already know how to handle those.
//
// We deliberately don't return a custom dialog or value — the user
// asked Siri/Shortcuts to "open Bide here," and the answer is "Bide
// is open here." A snippet would just delay the navigation they wanted.

// MARK: - Intent: Find clutter

struct FindClutterIntent: AppIntent {
    static let title: LocalizedStringResource = "Find clutter"
    static let description = IntentDescription(
        "Open Bide and refresh the dashboard so the latest cleanup candidates appear."
    )
    static let openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        await BideAppIntents.broadcast(.findClutter)
        return .result()
    }
}

// MARK: - Intent: On this day

struct OnThisDayIntent: AppIntent {
    static let title: LocalizedStringResource = "On this day in Bide"
    static let description = IntentDescription(
        "Open Bide to the On This Day list — photos taken on today's calendar day in past years."
    )
    static let openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        await BideAppIntents.broadcast(.onThisDay)
        return .result()
    }
}

// MARK: - Intent: Review basket

struct ReviewBasketIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Review Basket"
    static let description = IntentDescription(
        "Open Bide directly into the Review Basket so you can confirm or back out of items you've selected."
    )
    static let openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        await BideAppIntents.broadcast(.reviewBasket)
        return .result()
    }
}

// MARK: - Shared helper

enum BideAppIntents {
    /// Post the matching `ShortcutAction` on the main actor. The
    /// notification feeds straight into the existing `AppState`
    /// subscription, so the rest of the app reacts the same way it
    /// would for a Home Screen Quick Action.
    @MainActor
    static func broadcast(_ action: ShortcutAction) {
        NotificationCenter.default.post(
            name: .bideShortcutAction,
            object: nil,
            userInfo: ["action": action]
        )
    }
}

// MARK: - Shortcuts surface

/// Registers the three intents with iOS so they appear in the Shortcuts
/// app's gallery, in Spotlight suggestions, and as "Hey Siri" candidates.
/// Phrases are the natural-language alternates users can say.
struct BideAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: FindClutterIntent(),
            phrases: [
                "Find clutter in \(.applicationName)",
                "Scan with \(.applicationName)",
                "Refresh \(.applicationName)"
            ],
            shortTitle: "Find clutter",
            systemImageName: "magnifyingglass"
        )

        AppShortcut(
            intent: OnThisDayIntent(),
            phrases: [
                "On this day in \(.applicationName)",
                "Show my memories in \(.applicationName)",
                "\(.applicationName) on this day"
            ],
            shortTitle: "On this day",
            systemImageName: "calendar.badge.clock"
        )

        AppShortcut(
            intent: ReviewBasketIntent(),
            phrases: [
                "Open Review Basket in \(.applicationName)",
                "Show my \(.applicationName) basket"
            ],
            shortTitle: "Review basket",
            systemImageName: "tray.fill"
        )
    }
}
