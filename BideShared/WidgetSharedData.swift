import Foundation

/// The small slice of state Bide shares with its widget. Written by the
/// main app whenever lifetime totals change; read by the widget's
/// timeline provider. Compiled into BOTH the `Bide` app target and the
/// `BideWidget` extension target (xcodegen lists this path in both).
///
/// Transport is an App Group `UserDefaults` suite. If the App Group
/// isn't provisioned yet (e.g. running before the Apple Developer
/// Portal step is done), `sharedDefaults` falls back to
/// `.standard` so nothing crashes — the widget just won't see the
/// main app's writes until the group is live, which is the correct
/// degradation.
public struct WidgetSharedData: Codable, Equatable, Sendable {

    /// Lifetime bytes reclaimed across all sessions.
    public var lifetimeBytes: Int64
    /// Lifetime count of sessions.
    public var sessionCount: Int
    /// Lifetime count of items moved to Recently Deleted.
    public var itemCount: Int
    /// When the most recent session completed, if any.
    public var lastSessionAt: Date?

    public init(
        lifetimeBytes: Int64 = 0,
        sessionCount: Int = 0,
        itemCount: Int = 0,
        lastSessionAt: Date? = nil
    ) {
        self.lifetimeBytes = lifetimeBytes
        self.sessionCount = sessionCount
        self.itemCount = itemCount
        self.lastSessionAt = lastSessionAt
    }

    /// A zeroed value — what the widget shows before the user has done
    /// any cleanup, and the placeholder for the widget gallery.
    public static let empty = WidgetSharedData()

    public var formattedLifetimeBytes: String {
        ByteCountFormatter.string(fromByteCount: lifetimeBytes, countStyle: .file)
    }
}

/// Reads + writes `WidgetSharedData` to the App Group suite.
public enum WidgetSharedStore {

    /// App Group identifier. MUST be registered in the Apple Developer
    /// Portal (Identifiers → App Groups) and added to both the app and
    /// widget App IDs before TestFlight, or the suite silently falls
    /// back to `.standard` and the widget won't reflect the app's data
    /// on device.
    public static let appGroupID = "group.com.bidephoto.bide"

    private static let storageKey = "bide.widget.sharedData"

    /// The shared suite, or `.standard` if the App Group isn't available.
    /// We don't force-unwrap `UserDefaults(suiteName:)` — a missing group
    /// returns nil, and we degrade rather than crash.
    private static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    /// Persist the latest snapshot. Called by the main app after a
    /// session is recorded. Encoding failures are swallowed — a widget
    /// that lags by one update is better than a crash in the delete path.
    public static func write(_ data: WidgetSharedData) {
        guard let encoded = try? JSONEncoder().encode(data) else { return }
        defaults.set(encoded, forKey: storageKey)
    }

    /// Read the latest snapshot, or `.empty` if nothing's been written.
    public static func read() -> WidgetSharedData {
        guard let raw = defaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode(WidgetSharedData.self, from: raw)
        else { return .empty }
        return decoded
    }

    /// Remove the stored snapshot. After this, `read()` returns `.empty`.
    /// Used by tests and available for a future "reset statistics" action.
    public static func clear() {
        defaults.removeObject(forKey: storageKey)
    }
}
