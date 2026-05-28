import Foundation

/// Pure planner for Bide's background-refresh schedule. Decides when the
/// next `BGAppRefreshTask` should fire given the current state (last
/// successful refresh, current time, whether the user has read access).
/// Kept side-effect-free so the unit tests don't need BGTaskScheduler or
/// any iOS framework state.
///
/// Caller wraps this in `BackgroundRefreshService`, which translates the
/// planner's output into `BGTaskScheduler.shared.submit` calls.
enum BackgroundRefreshScheduler {

    /// Minimum gap between successful refreshes. Pulled from product spec
    /// §17 — we want at most one background scan per night, not throughout
    /// the day, since the value proposition is "open Bide in the morning,
    /// numbers are already current."
    static let minimumIntervalSeconds: TimeInterval = 8 * 60 * 60

    /// Returns the earliest date the next background refresh should fire,
    /// or `nil` if no schedule should be set (no read access, etc.).
    ///
    /// - Parameters:
    ///   - lastSuccessAt: when the dashboard last completed a scan, or `nil`
    ///     if it never has.
    ///   - now: the reference clock — injected so tests can pin behavior at
    ///     arbitrary instants.
    ///   - hasReadAccess: whether PhotoKit grants us at least Limited
    ///     access. When `false` we never schedule, since a background
    ///     refresh with no library access does nothing.
    static func nextFireDate(
        lastSuccessAt: Date?,
        now: Date,
        hasReadAccess: Bool
    ) -> Date? {
        guard hasReadAccess else { return nil }

        guard let lastSuccessAt else {
            // No prior scan recorded — let iOS schedule the first BG refresh
            // at its convenience. Earliest beginning *now* is fine; iOS
            // gates it behind battery/network heuristics anyway.
            return now
        }

        let earliestNextFire = lastSuccessAt.addingTimeInterval(minimumIntervalSeconds)
        return max(now, earliestNextFire)
    }

    /// Should the BG task body actually do a refresh right now, or is the
    /// last scan still recent enough that we should just reschedule and
    /// finish cheap? Answers "yes" when no prior scan exists or the gap
    /// has elapsed.
    static func shouldRunNow(
        lastSuccessAt: Date?,
        now: Date,
        hasReadAccess: Bool
    ) -> Bool {
        guard hasReadAccess else { return false }
        guard let lastSuccessAt else { return true }
        return now.timeIntervalSince(lastSuccessAt) >= minimumIntervalSeconds
    }
}
