import Foundation

/// Pure state machine that coalesces rapid library-change events into
/// at-most-one in-flight refresh while guaranteeing that no change is
/// lost — if a change arrives mid-refresh, the coalescer remembers it
/// and asks the caller to schedule a follow-up after the in-flight scan
/// finishes.
///
/// The coalescer is intentionally PhotoKit-free so it can be unit-tested
/// in isolation. Production callers (DashboardSummary) translate the
/// outcomes into concrete `Task { ... }` invocations.
///
/// Lifecycle:
/// ```
///   processDebouncedChange()  →  .noop | .startRefresh
///   tryBeginRefresh()         →  Bool  (false if already refreshing)
///   completeRefresh()         →  .done | .startFollowupRefresh
/// ```
struct RefreshCoalescer: Equatable {

    /// Outcome of receiving a library-change tick *after the debounce*.
    enum ChangeOutcome: Equatable {
        /// A refresh is already in flight. The coalescer remembered the
        /// change; caller does nothing.
        case noop
        /// No refresh in flight. Caller should kick off a refresh now.
        case startRefresh
    }

    /// Outcome of a refresh completing.
    enum EndOutcome: Equatable {
        /// Nothing pending. Caller can rest.
        case done
        /// A library change landed mid-refresh. Caller should kick off
        /// another refresh.
        case startFollowupRefresh
    }

    /// True while a refresh task is running.
    private(set) var isRefreshing: Bool = false
    /// True when a change arrived during an in-flight refresh.
    private(set) var dirty: Bool = false

    /// Called from the change-debounce timer. Returns whether the caller
    /// should kick off a refresh now or just set the dirty flag.
    mutating func processDebouncedChange() -> ChangeOutcome {
        if isRefreshing {
            dirty = true
            return .noop
        }
        isRefreshing = true
        return .startRefresh
    }

    /// Called from the user/programmatic refresh entry points (foreground,
    /// pull-to-refresh, .task). Returns `true` if the caller should run
    /// the refresh, `false` if one is already in flight.
    mutating func tryBeginRefresh() -> Bool {
        if isRefreshing { return false }
        isRefreshing = true
        return true
    }

    /// Called when a refresh task finishes. Returns whether a follow-up
    /// refresh is needed (i.e. a change arrived mid-flight). If so the
    /// coalescer immediately re-enters the refreshing state so a
    /// concurrent debounce tick won't double-start.
    mutating func completeRefresh() -> EndOutcome {
        if dirty {
            dirty = false
            // isRefreshing stays true — we're starting the follow-up.
            return .startFollowupRefresh
        }
        isRefreshing = false
        return .done
    }

    /// Reset to baseline. Useful for tests and for the rare case where the
    /// caller wants to cancel a refresh entirely.
    mutating func reset() {
        isRefreshing = false
        dirty = false
    }
}
