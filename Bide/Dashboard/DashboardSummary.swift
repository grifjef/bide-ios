import Foundation
import Photos
import Observation

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
        var formattedTotal: String {
            ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
        }
    }

    struct ScreenRecordingsCount: Equatable {
        let count: Int
        let totalBytes: Int64
        var formattedTotal: String {
            ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
        }
    }

    struct ScreenshotsCount: Equatable {
        let count: Int
        let estimatedBytes: Int64
        var formattedTotal: String {
            ByteCountFormatter.string(fromByteCount: estimatedBytes, countStyle: .file)
        }
    }

    struct DuplicatesCount: Equatable {
        let groupCount: Int
        let duplicateCount: Int
        let reclaimableBytes: Int64
        var formattedReclaim: String {
            ByteCountFormatter.string(fromByteCount: reclaimableBytes, countStyle: .file)
        }
    }

    struct LivePhotosCount: Equatable {
        let count: Int
        let totalBytes: Int64
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
    private(set) var isRefreshing: Bool = false
    private(set) var lastRefreshAt: Date?

    private let photoLibrary: PhotoLibraryService
    private var currentTask: Task<Void, Never>?

    /// Listens to library changes so dashboard counts stay current when the
    /// user deletes things in a module and returns to the dashboard. Without
    /// this, the headlines would lie until the next pull-to-refresh.
    private var libraryObserver: PhotoLibraryObserver?

    /// Coalesces rapid-fire library change events (a multi-asset delete fires
    /// once per asset). 750ms feels responsive without thrashing the scans.
    private var pendingChangeTask: Task<Void, Never>?
    private static let changeDebounceNanos: UInt64 = 750_000_000

    /// Set when a library change arrives mid-refresh. After the current
    /// refresh finishes we re-run so the post-change state lands.
    private var refreshDirty: Bool = false

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

    /// Coalesce-and-refresh hook. PhotoKit fires the observer on a background
    /// queue per asset change; we ride out the burst, then re-scan once.
    /// If a refresh is already underway, mark dirty so the in-flight task
    /// re-runs after it finishes — never miss a post-deletion update.
    private func handleLibraryChange() {
        pendingChangeTask?.cancel()
        pendingChangeTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: Self.changeDebounceNanos)
            guard !Task.isCancelled, let self else { return }
            if self.isRefreshing {
                self.refreshDirty = true
            } else {
                self.refreshIfNeeded()
            }
        }
    }

    /// Refresh all three quick-scan summaries. Existing values stay visible
    /// until each section's new value lands — no flicker to "—".
    func refreshIfNeeded() {
        guard photoLibrary.hasReadAccess else { return }
        guard !isRefreshing else { return }
        currentTask?.cancel()
        isRefreshing = true

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
            self.isRefreshing = false
            self.lastRefreshAt = Date()
            // If a library change arrived while we were scanning, re-scan
            // once more so the latest deletions are reflected.
            if self.refreshDirty {
                self.refreshDirty = false
                self.refreshIfNeeded()
            }
        }
    }

    func cancel() {
        currentTask?.cancel()
        isRefreshing = false
    }

    // MARK: - Section refreshes

    private func refreshLargeVideos(photoLibrary: PhotoLibraryService) async {
        let videos = await photoLibrary.fetchLargeVideos(limit: 200)
        // We only count videos above a meaningful size threshold so the headline
        // matches what a user would actually act on — 100 MB minimum.
        let actionable = videos.filter { $0.fileSize > 100_000_000 }
        let total = actionable.reduce(Int64(0)) { $0 + $1.fileSize }
        largeVideos = LargeVideosCount(count: actionable.count, totalBytes: total)
    }

    private func refreshScreenRecordings(photoLibrary: PhotoLibraryService) async {
        let recordings = await photoLibrary.fetchScreenRecordings(limit: 200)
        // Show everything — screen recordings are usually disposable regardless of size
        let total = recordings.reduce(Int64(0)) { $0 + $1.fileSize }
        screenRecordings = ScreenRecordingsCount(count: recordings.count, totalBytes: total)
    }

    private func refreshScreenshots(photoLibrary: PhotoLibraryService) async {
        let shots = await photoLibrary.fetchScreenshots(limit: 5_000)
        let estimated = shots.reduce(Int64(0)) { sum, item in
            sum + PhotoLibraryService.estimatedScreenshotBytes(
                pixelWidth: item.pixelWidth,
                pixelHeight: item.pixelHeight
            )
        }
        screenshots = ScreenshotsCount(count: shots.count, estimatedBytes: estimated)
    }

    private func refreshLivePhotos(photoLibrary: PhotoLibraryService) async {
        let photos = await photoLibrary.fetchLivePhotos(limit: 200)
        let total = photos.reduce(Int64(0)) { $0 + $1.fileSize }
        livePhotos = LivePhotosCount(count: photos.count, totalBytes: total)
    }

    private func refreshOnThisDay(photoLibrary: PhotoLibraryService) async {
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

    private func refreshDuplicates(photoLibrary: PhotoLibraryService) async {
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
