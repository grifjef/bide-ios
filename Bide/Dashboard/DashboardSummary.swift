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

    private(set) var largeVideos: LargeVideosCount?
    private(set) var screenRecordings: ScreenRecordingsCount?
    private(set) var screenshots: ScreenshotsCount?
    private(set) var duplicates: DuplicatesCount?
    private(set) var isRefreshing: Bool = false
    private(set) var lastRefreshAt: Date?

    private let photoLibrary: PhotoLibraryService
    private var currentTask: Task<Void, Never>?

    init(photoLibrary: PhotoLibraryService) {
        self.photoLibrary = photoLibrary
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
            }
            self.isRefreshing = false
            self.lastRefreshAt = Date()
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
