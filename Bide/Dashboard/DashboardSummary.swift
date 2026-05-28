import Foundation
import Observation
import os
import Photos

/// Lightweight pre-scan that populates the dashboard's module-card headlines
/// with real counts and reclaimable bytes. Only runs the *cheap* scans —
/// Similar Photos and Blurry Shots are deferred to user-initiated scans
/// because they need Vision and thumbnails.
///
/// Computed at app launch (after permission grant) so the dashboard arrives
/// populated. Re-runs on demand when the user pulls to refresh or returns
/// from a module that may have deleted assets.
@Observable
@MainActor
final class DashboardSummary {
    struct LargeVideosCount: Equatable {
        let count: Int
        let totalBytes: Int64
        // swiftlint:disable:next empty_count
        var isEmpty: Bool { count == 0 }
        var formattedTotal: String {
            ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
        }
    }

    struct ScreenRecordingsCount: Equatable {
        let count: Int
        let totalBytes: Int64
        // swiftlint:disable:next empty_count
        var isEmpty: Bool { count == 0 }
        var formattedTotal: String {
            ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
        }
    }

    struct ScreenshotsCount: Equatable {
        let count: Int
        let estimatedBytes: Int64
        // swiftlint:disable:next empty_count
        var isEmpty: Bool { count == 0 }
        var formattedTotal: String {
            ByteCountFormatter.string(fromByteCount: estimatedBytes, countStyle: .file)
        }
    }

    struct DuplicatesCount: Equatable {
        let groupCount: Int
        let duplicateCount: Int
        let reclaimableBytes: Int64
        var isEmpty: Bool { duplicateCount == 0 }
        var formattedReclaim: String {
            ByteCountFormatter.string(fromByteCount: reclaimableBytes, countStyle: .file)
        }
    }

    struct LivePhotosCount: Equatable {
        let count: Int
        let totalBytes: Int64
        // swiftlint:disable:next empty_count
        var isEmpty: Bool { count == 0 }
        var formattedTotal: String {
            ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
        }
    }

    struct OnThisDayCount: Equatable {
        let totalCount: Int
        let yearsAgo: Int  // newest year-group's "N years ago" — for the headline
    }

    private(set) var largeVideos: LargeVideosCount?
    private(set) var screenRecordings: ScreenRecordingsCount?
    private(set) var screenshots: ScreenshotsCount?
    private(set) var duplicates: DuplicatesCount?
    private(set) var livePhotos: LivePhotosCount?
    private(set) var onThisDay: OnThisDayCount?
    private(set) var lastRefreshAt: Date?

    /// Surface for the freshness pill on the dashboard.
    var isRefreshing: Bool { coalescer.isRefreshing }

    private let photoLibrary: PhotoLibraryService
    private var currentTask: Task<Void, Never>?

    /// Pure-logic state machine for "rapid changes + mid-flight changes ==
    /// at-most-one refresh in flight, no missed events." Extracted so it's
    /// fully unit-tested without PhotoKit.
    private var coalescer = RefreshCoalescer()

    /// Listens to library changes so dashboard counts stay current when the
    /// user deletes things in a module and returns to the dashboard.
    private var libraryObserver: PhotoLibraryObserver?

    /// Coalesces rapid-fire library change events (a multi-asset delete fires
    /// once per asset). 750ms feels responsive without thrashing the scans.
    private var pendingChangeTask: Task<Void, Never>?
    private static let changeDebounceNanos: UInt64 = 750_000_000

    init(photoLibrary: PhotoLibraryService) {
        self.photoLibrary = photoLibrary
        Task { @MainActor [weak self] in
            self?.libraryObserver = PhotoLibraryObserver { [weak self] _ in
                Task { @MainActor in
                    self?.handleLibraryChange()
                }
            }
        }
    }

    /// PhotoKit fires the observer on a background queue per asset change;
    /// we ride out the burst, then ask the coalescer what to do.
    private func handleLibraryChange() {
        pendingChangeTask?.cancel()
        pendingChangeTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: Self.changeDebounceNanos)
            guard !Task.isCancelled, let self else { return }
            switch self.coalescer.processDebouncedChange() {
            case .noop:
                break
            case .startRefresh:
                // Coalescer already flipped to isRefreshing. Spin up the work.
                self.startRefreshTask()
            }
        }
    }

    /// Refresh all section summaries. Existing values stay visible until
    /// each section's new value lands — no flicker to "—". No-op if a
    /// refresh is already in flight (the coalescer enforces this).
    func refreshIfNeeded() {
        guard photoLibrary.hasReadAccess else { return }
        guard coalescer.tryBeginRefresh() else { return }
        startRefreshTask()
    }

    /// Internal entry point used by both `refreshIfNeeded` and the
    /// library-change debounce path. Assumes the coalescer is already in
    /// the refreshing state.
    private func startRefreshTask() {
        currentTask?.cancel()
        let signpostID = BideSignposts.scansSignposter.makeSignpostID()
        let state = BideSignposts.scansSignposter.beginInterval(
            "dashboard.refresh",
            id: signpostID
        )

        currentTask = Task { [weak self, photoLibrary] in
            guard let self else { return }
            await withTaskGroup(of: Void.self) { group in
                group.addTask { await self.refreshLargeVideos(photoLibrary: photoLibrary) }
                group.addTask { await self.refreshScreenRecordings(photoLibrary: photoLibrary) }
                group.addTask { await self.refreshScreenshots(photoLibrary: photoLibrary) }
                group.addTask { await self.refreshDuplicates(photoLibrary: photoLibrary) }
                group.addTask { await self.refreshLivePhotos(photoLibrary: photoLibrary) }
                group.addTask { await self.refreshOnThisDay(photoLibrary: photoLibrary) }
            }
            BideSignposts.scansSignposter.endInterval("dashboard.refresh", state)
            self.lastRefreshAt = Date()
            // Hand off to the coalescer to decide whether a follow-up is
            // needed (a library change arrived mid-flight).
            switch self.coalescer.completeRefresh() {
            case .done:
                break
            case .startFollowupRefresh:
                self.startRefreshTask()
            }
        }
    }

    func cancel() {
        currentTask?.cancel()
        coalescer.reset()
    }

    // MARK: - Section refreshes

    /// Helper: wrap an async section refresh in an OSSignpost interval so
    /// each phase shows up independently in Instruments. The signpost name
    /// is a `StaticString` per OSSignposter requirements.
    private func signposted<T>(_ name: StaticString, _ work: () async -> T) async -> T {
        let id = BideSignposts.scansSignposter.makeSignpostID()
        let state = BideSignposts.scansSignposter.beginInterval(name, id: id)
        let result = await work()
        BideSignposts.scansSignposter.endInterval(name, state)
        return result
    }

    private func refreshLargeVideos(photoLibrary: PhotoLibraryService) async {
        await signposted("dashboard.largeVideos") {
            let videos = await photoLibrary.fetchLargeVideos(limit: 200)
            // We only count videos above a meaningful size threshold so the headline
            // matches what a user would actually act on — 100 MB minimum.
            let actionable = videos.filter { $0.fileSize > 100_000_000 }
            let total = actionable.reduce(Int64(0)) { $0 + $1.fileSize }
            largeVideos = LargeVideosCount(count: actionable.count, totalBytes: total)
        }
    }

    private func refreshScreenRecordings(photoLibrary: PhotoLibraryService) async {
        await signposted("dashboard.screenRecordings") {
            let recordings = await photoLibrary.fetchScreenRecordings(limit: 200)
            // Show everything — screen recordings are usually disposable regardless of size
            let total = recordings.reduce(Int64(0)) { $0 + $1.fileSize }
            screenRecordings = ScreenRecordingsCount(count: recordings.count, totalBytes: total)
        }
    }

    private func refreshScreenshots(photoLibrary: PhotoLibraryService) async {
        await signposted("dashboard.screenshots") {
            let shots = await photoLibrary.fetchScreenshots(limit: 5_000)
            let estimated = shots.reduce(Int64(0)) { sum, item in
                sum + PhotoLibraryService.estimatedScreenshotBytes(
                    pixelWidth: item.pixelWidth,
                    pixelHeight: item.pixelHeight
                )
            }
            screenshots = ScreenshotsCount(count: shots.count, estimatedBytes: estimated)
        }
    }

    private func refreshLivePhotos(photoLibrary: PhotoLibraryService) async {
        await signposted("dashboard.livePhotos") {
            let photos = await photoLibrary.fetchLivePhotos(limit: 200)
            let total = photos.reduce(Int64(0)) { $0 + $1.fileSize }
            livePhotos = LivePhotosCount(count: photos.count, totalBytes: total)
        }
    }

    private func refreshOnThisDay(photoLibrary: PhotoLibraryService) async {
        await signposted("dashboard.onThisDay") {
            let candidates = await photoLibrary.fetchPhotoCandidates(limit: 5_000)
            let groups = OnThisDayMatcher.groupsForToday(
                candidates: candidates,
                targetDate: Date()
            )
            let calendar = Calendar.current
            let targetYear = calendar.component(.year, from: Date())
            let yearsAgo = groups.first.map { targetYear - $0.id } ?? 0
            onThisDay = OnThisDayCount(
                totalCount: OnThisDayMatcher.totalCount(groups),
                yearsAgo: yearsAgo
            )
        }
    }

    private func refreshDuplicates(photoLibrary: PhotoLibraryService) async {
        await signposted("dashboard.duplicates") {
            let candidates = await photoLibrary.fetchPhotoCandidates(limit: 5_000)
            let groups = ExactDuplicateDetector.detect(candidates)
            let summary = ExactDuplicateDetector.summary(groups)
            duplicates = DuplicatesCount(
                groupCount: summary.groupCount,
                duplicateCount: summary.duplicateCount,
                reclaimableBytes: summary.reclaimableBytes
            )
        }
    }
}
