import BackgroundTasks
import Foundation
import os

/// Wires Bide to `BGTaskScheduler` so the dashboard pre-scan can run
/// overnight without the user opening the app. When they tap the icon in
/// the morning, the headlines are already current.
///
/// Design notes:
/// - One identifier: `com.bidephoto.bide.dashboardRefresh`. We don't carve
///   out separate identifiers per module because the dashboard refresh
///   already coordinates the six section scans in parallel.
/// - Uses `BGAppRefreshTask` (lightweight, ~30s) not `BGProcessingTask`.
///   Our scan is fast and shouldn't require Power-Connected. The user
///   pays no battery cost we couldn't pay them back in usability.
/// - The actual decision of when-to-fire is delegated to
///   `BackgroundRefreshScheduler` so the policy is unit-tested without
///   `BGTaskScheduler`.
/// - We never crash a missed schedule. iOS may throttle background tasks
///   to once-per-day or skip them entirely if the device is low-power;
///   that's expected and the foreground refresh path covers any gap.
@MainActor
final class BackgroundRefreshService {
    /// Reverse-DNS task identifier. Must match the entry in the app's
    /// `BGTaskSchedulerPermittedIdentifiers` Info.plist key.
    static let taskIdentifier = "com.bidephoto.bide.dashboardRefresh"

    private static let log = OSLog(
        subsystem: BideSignposts.subsystem,
        category: "background-refresh"
    )

    /// Bound at app launch via `register(summary:photoLibrary:)`. Strong
    /// references are fine — these are app-lifetime singletons.
    private let summary: DashboardSummary
    private let photoLibrary: PhotoLibraryService

    init(summary: DashboardSummary, photoLibrary: PhotoLibraryService) {
        self.summary = summary
        self.photoLibrary = photoLibrary
    }

    /// Must be called once during `BideApp.init()` *before* the app
    /// finishes launching — `BGTaskScheduler.register` requires that.
    func registerTaskHandler() {
        let registered = BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.taskIdentifier,
            using: nil
        ) { [weak self] task in
            guard let task = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            Task { @MainActor [weak self] in
                await self?.handle(task: task)
            }
        }

        if registered {
            os_log("BG refresh task handler registered: %{public}@",
                   log: Self.log, type: .info, Self.taskIdentifier)
        } else {
            os_log("BG refresh task handler registration failed for %{public}@",
                   log: Self.log, type: .error, Self.taskIdentifier)
        }
    }

    /// Submit the next background-refresh request to iOS. Caller invokes
    /// this on app foreground/background transitions (the user's session
    /// is the most reliable "we're alive" signal). Idempotent — iOS
    /// replaces any pending request with the same identifier.
    func scheduleNext(now: Date = Date()) {
        guard let earliestBegin = BackgroundRefreshScheduler.nextFireDate(
            lastSuccessAt: summary.lastRefreshAt,
            now: now,
            hasReadAccess: photoLibrary.hasReadAccess
        ) else {
            // No access yet — don't schedule; we'll try again after the
            // user grants permission.
            return
        }

        let request = BGAppRefreshTaskRequest(identifier: Self.taskIdentifier)
        request.earliestBeginDate = earliestBegin

        do {
            try BGTaskScheduler.shared.submit(request)
            os_log("BG refresh scheduled for %{public}@",
                   log: Self.log, type: .info, "\(earliestBegin)")
        } catch BGTaskScheduler.Error.notPermitted {
            // Happens when running on a simulator or if entitlement is
            // missing — log + continue. Not fatal.
            os_log("BG refresh scheduling not permitted in this environment",
                   log: Self.log, type: .default)
        } catch BGTaskScheduler.Error.tooManyPendingTaskRequests {
            // iOS limits each app to a small number of pending requests.
            // We re-submit on every app-lifecycle transition, so the user
            // can never get stuck without one queued.
            os_log("BG refresh: too many pending requests; will retry next cycle",
                   log: Self.log, type: .default)
        } catch {
            os_log("BG refresh schedule failed: %{public}@",
                   log: Self.log, type: .error, "\(error)")
        }
    }

    // MARK: - Task body

    private func handle(task: BGAppRefreshTask) async {
        // Schedule the *next* refresh immediately. iOS doesn't auto-chain
        // — if we skip this, we never run again.
        scheduleNext()

        // Cancellation: iOS gives BGAppRefreshTask ~30s. If we run over,
        // it kills the process. Wire the expiration handler to set our
        // sentinel so the dashboard task can bail cleanly.
        let runFinished = TaskBox<Bool>(false)
        task.expirationHandler = {
            // We can't touch `summary` from this closure safely — iOS may
            // fire it on any queue. Just flag so the body sees it next
            // checkpoint.
            runFinished.value = true
        }

        let shouldRun = BackgroundRefreshScheduler.shouldRunNow(
            lastSuccessAt: summary.lastRefreshAt,
            now: Date(),
            hasReadAccess: photoLibrary.hasReadAccess
        )

        guard shouldRun else {
            // Throttled — nothing to do this cycle. Reporting success so
            // iOS keeps trusting us with future windows.
            task.setTaskCompleted(success: true)
            return
        }

        summary.refreshIfNeeded()

        // Poll until either the refresh ends or iOS warns us we're out of
        // time. The dashboard refresh is fast (typically <5s on a 10k-asset
        // library) so the polling loop is cheap.
        while summary.isRefreshing && !runFinished.value {
            try? await Task.sleep(nanoseconds: 200_000_000)
        }

        task.setTaskCompleted(success: !runFinished.value)
    }
}

/// Trivial reference wrapper so non-isolated closures can flip a flag the
/// MainActor body observes. `Bool` would be copied; we want shared state.
@MainActor
private final class TaskBox<Value: Sendable>: @unchecked Sendable {
    var value: Value
    init(_ value: Value) { self.value = value }
}
