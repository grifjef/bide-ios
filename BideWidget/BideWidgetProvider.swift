import WidgetKit

/// Timeline provider for every Bide widget family. The data source is the
/// App Group snapshot (`WidgetSharedStore`), refreshed hourly. Bide's
/// numbers change at most once per cleanup session, so an hourly cadence
/// is generous — WidgetKit also refreshes opportunistically when the app
/// writes new data and calls `WidgetCenter.shared.reloadAllTimelines()`.
struct BideWidgetProvider: TimelineProvider {

    /// Shown in the widget gallery and while real data loads. Uses a
    /// representative non-zero value so the gallery preview looks alive
    /// rather than showing "0 B".
    func placeholder(in context: Context) -> BideWidgetEntry {
        BideWidgetEntry(
            date: Date(),
            data: WidgetSharedData(
                lifetimeBytes: 4_600_000_000,
                sessionCount: 6,
                itemCount: 412,
                lastSessionAt: nil
            ),
            isPlaceholder: true
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (BideWidgetEntry) -> Void) {
        let entry: BideWidgetEntry
        if context.isPreview {
            entry = placeholder(in: context)
        } else {
            entry = BideWidgetEntry(date: Date(), data: WidgetSharedStore.read(), isPlaceholder: false)
        }
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BideWidgetEntry>) -> Void) {
        let now = Date()
        let snapshot = WidgetSharedStore.read()
        // A single-entry timeline — the value only changes when the app
        // writes — with an hourly refresh as a backstop. The app also
        // explicitly reloads timelines on session completion, so the
        // hourly policy is just belt-and-suspenders.
        let entry = BideWidgetEntry(date: now, data: snapshot, isPlaceholder: false)
        let next = TimelineRefresh.nextHourlyDate(from: now)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

/// One timeline entry: the shared snapshot plus a placeholder flag the
/// views use to dim "live" affordances during gallery preview.
struct BideWidgetEntry: TimelineEntry {
    let date: Date
    let data: WidgetSharedData
    let isPlaceholder: Bool
}

/// Pure helper for the next refresh instant — extracted so it's unit
/// testable without WidgetKit.
enum TimelineRefresh {
    static let intervalSeconds: TimeInterval = 60 * 60

    static func nextHourlyDate(from reference: Date) -> Date {
        reference.addingTimeInterval(intervalSeconds)
    }
}
