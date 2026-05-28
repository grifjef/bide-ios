import Foundation
import Photos
import Observation
import UIKit

/// Wraps PhotoKit. Keeps PhotoKit types contained to a thin layer so the rest
/// of the app talks in value types (`LargeVideoSummary`, `ScreenshotSummary`).
@Observable
@MainActor
final class PhotoLibraryService {

    private(set) var authStatus: PHAuthorizationStatus

    init() {
        self.authStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    /// Re-read the PhotoKit authorization status. Call this when the app returns
    /// to the foreground — the user may have granted permission in Settings
    /// while we were backgrounded, and we want the dashboard to reflect that
    /// immediately rather than after an app restart.
    func refreshAuthStatus() {
        let current = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if current != authStatus {
            authStatus = current
        }
    }

    // MARK: - Authorization

    @discardableResult
    func requestAuthorization() async -> PHAuthorizationStatus {
        let status = await withCheckedContinuation { (continuation: CheckedContinuation<PHAuthorizationStatus, Never>) in
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                continuation.resume(returning: status)
            }
        }
        self.authStatus = status
        return status
    }

    /// True if we can read enough of the library to be useful.
    var hasReadAccess: Bool {
        authStatus == .authorized || authStatus == .limited
    }

    // MARK: - Fetching

    /// Fetch video assets sorted by file size descending.
    ///
    /// Strategy (per CLAUDE.md gotcha — `PHAssetResource.fileSize` is per-asset
    /// expensive, so don't iterate everything):
    ///   1. Pass 1: enumerate ALL videos, compute a cheap byte ESTIMATE from
    ///      `pixelWidth × pixelHeight × duration` via a bitrate heuristic.
    ///   2. Sort by estimate descending, take top `limit`.
    ///   3. Pass 2: for the top `limit` only, query `PHAssetResource.fileSize`
    ///      to get the real bytes. Fall back to the estimate if real bytes
    ///      come back zero (iCloud-not-downloaded etc).
    ///   4. Re-sort by actual bytes.
    ///
    /// For a library of 2 000 videos we now do ~2 000 cheap enumerations plus
    /// ~`limit` (default 200) expensive resource lookups, instead of 2 000
    /// expensive lookups. ~10× faster on large libraries.
    func fetchLargeVideos(limit: Int = 200) async -> [LargeVideoSummary] {
        await Task.detached(priority: .userInitiated) {
            let options = PHFetchOptions()
            options.predicate = NSPredicate(
                format: "mediaType == %d",
                PHAssetMediaType.video.rawValue
            )
            options.sortDescriptors = [
                NSSortDescriptor(key: "creationDate", ascending: false)
            ]

            let fetched = PHAsset.fetchAssets(with: options)

            // Pass 1: cheap enumeration with size estimate.
            // Screen recordings get their own module — keep them out of Large Videos
            // so the user has a clear mental model for which list contains what.
            struct PreliminaryRow {
                let asset: PHAsset
                let estimate: Int64
            }
            var prelim: [PreliminaryRow] = []
            prelim.reserveCapacity(fetched.count)
            fetched.enumerateObjects { asset, _, _ in
                guard !asset.mediaSubtypes.contains(.videoScreenRecording) else { return }
                let estimate = Self.estimatedVideoBytes(
                    pixelWidth: asset.pixelWidth,
                    pixelHeight: asset.pixelHeight,
                    duration: asset.duration
                )
                prelim.append(PreliminaryRow(asset: asset, estimate: estimate))
            }

            // Pass 2: take top N by estimate, fetch real fileSize for those only
            let topCandidates = prelim
                .sorted { $0.estimate > $1.estimate }
                .prefix(limit)

            var summaries: [LargeVideoSummary] = []
            summaries.reserveCapacity(topCandidates.count)
            for row in topCandidates {
                let asset = row.asset
                let realSize = Self.fileSize(of: asset)
                let bytes = realSize > 0 ? realSize : row.estimate

                summaries.append(
                    LargeVideoSummary(
                        localIdentifier: asset.localIdentifier,
                        creationDate: asset.creationDate,
                        duration: asset.duration,
                        pixelWidth: asset.pixelWidth,
                        pixelHeight: asset.pixelHeight,
                        fileSize: bytes,
                        isFavorite: asset.isFavorite,
                        isHidden: asset.isHidden,
                        sourceTypeIsCamera: asset.sourceType == .typeUserLibrary,
                        isScreenRecording: false
                    )
                )
            }

            // Real sizes may shuffle the order slightly vs. estimate-sort
            return summaries.sorted { $0.fileSize > $1.fileSize }
        }.value
    }

    /// Fetch screen-recording video assets sorted by file size descending.
    /// Mirrors `fetchLargeVideos` exactly, but with the inverse media-subtype
    /// filter. Screen recordings tend to be much larger than camera videos so
    /// they're worth surfacing as their own module.
    func fetchScreenRecordings(limit: Int = 200) async -> [LargeVideoSummary] {
        await Task.detached(priority: .userInitiated) {
            let options = PHFetchOptions()
            options.predicate = NSPredicate(
                format: "mediaType == %d AND (mediaSubtypes & %d) != 0",
                PHAssetMediaType.video.rawValue,
                PHAssetMediaSubtype.videoScreenRecording.rawValue
            )
            options.sortDescriptors = [
                NSSortDescriptor(key: "creationDate", ascending: false)
            ]

            let fetched = PHAsset.fetchAssets(with: options)

            struct PreliminaryRow {
                let asset: PHAsset
                let estimate: Int64
            }
            var prelim: [PreliminaryRow] = []
            prelim.reserveCapacity(fetched.count)
            fetched.enumerateObjects { asset, _, _ in
                let estimate = Self.estimatedVideoBytes(
                    pixelWidth: asset.pixelWidth,
                    pixelHeight: asset.pixelHeight,
                    duration: asset.duration
                )
                prelim.append(PreliminaryRow(asset: asset, estimate: estimate))
            }

            let topCandidates = prelim
                .sorted { $0.estimate > $1.estimate }
                .prefix(limit)

            var summaries: [LargeVideoSummary] = []
            summaries.reserveCapacity(topCandidates.count)
            for row in topCandidates {
                let asset = row.asset
                let realSize = Self.fileSize(of: asset)
                let bytes = realSize > 0 ? realSize : row.estimate

                summaries.append(
                    LargeVideoSummary(
                        localIdentifier: asset.localIdentifier,
                        creationDate: asset.creationDate,
                        duration: asset.duration,
                        pixelWidth: asset.pixelWidth,
                        pixelHeight: asset.pixelHeight,
                        fileSize: bytes,
                        isFavorite: asset.isFavorite,
                        isHidden: asset.isHidden,
                        sourceTypeIsCamera: asset.sourceType == .typeUserLibrary,
                        isScreenRecording: true
                    )
                )
            }

            return summaries.sorted { $0.fileSize > $1.fileSize }
        }.value
    }

    /// Cheap bitrate-based estimate of an H.264/HEVC video's byte size.
    /// Conservative — undershoots slightly so we don't promise more storage
    /// reclaim than the user will see. Public so the LargeVideos module can
    /// label estimated rows in the UI if needed.
    ///
    /// Heuristic (approx Apple's modern HEVC defaults):
    ///   - 4K-ish (≥ 3.5 Mpx): ~6 MB/s
    ///   - 1080p-ish (≥ 1.5 Mpx): ~1.5 MB/s
    ///   - 720p or lower: ~0.6 MB/s
    /// Cheap estimate for a screenshot's byte size. HEIC compression on
    /// UI-flat content (lots of solid color, text) hits ~0.15 bytes/pixel.
    /// Used for dashboard summary stats where exact size doesn't matter.
    nonisolated static func estimatedScreenshotBytes(
        pixelWidth: Int,
        pixelHeight: Int
    ) -> Int64 {
        guard pixelWidth > 0, pixelHeight > 0 else { return 0 }
        return Int64(Double(pixelWidth * pixelHeight) * 0.15)
    }

    nonisolated static func estimatedVideoBytes(
        pixelWidth: Int,
        pixelHeight: Int,
        duration: TimeInterval
    ) -> Int64 {
        guard duration > 0, pixelWidth > 0, pixelHeight > 0 else { return 0 }
        let pixels = pixelWidth * pixelHeight
        let bytesPerSec: Int64
        if pixels >= 3_500_000 {
            bytesPerSec = 6_000_000
        } else if pixels >= 1_500_000 {
            bytesPerSec = 1_500_000
        } else {
            bytesPerSec = 600_000
        }
        return Int64(Double(bytesPerSec) * duration)
    }

    /// Result type for chunked streaming enumeration. `totalCount` is the
    /// up-front count for progress UI; `chunks` yields slices of candidates
    /// as the scan reads them, allowing cancellation between chunks and a
    /// "X of Y" progress label while the read phase runs.
    struct PhotoCandidatesStream {
        let totalCount: Int
        let chunks: AsyncStream<[SimilarPhotoCandidate]>
    }

    /// Stream photo candidates in chunks. Lets scan services show accurate
    /// progress, cancel between chunks, and (for memory-bounded use cases)
    /// process incrementally without holding the whole library in memory.
    ///
    /// - `maxTotal`: hard ceiling on the number of candidates we'll process,
    ///   for safety on absurdly large libraries (default 50_000 — covers
    ///   the upper 99.9th percentile of real-world camera rolls).
    /// - `chunkSize`: how many candidates to yield per chunk (default 500).
    ///
    /// Sorted by `creationDate` ascending so time-bucketing downstream is
    /// deterministic.
    func fetchPhotoCandidatesStream(
        maxTotal: Int = 50_000,
        chunkSize: Int = 500
    ) -> PhotoCandidatesStream {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(
            format: "mediaType == %d",
            PHAssetMediaType.image.rawValue
        )
        options.sortDescriptors = [
            NSSortDescriptor(key: "creationDate", ascending: true)
        ]
        options.fetchLimit = maxTotal

        let fetched = PHAsset.fetchAssets(with: options)
        let totalCount = fetched.count

        let chunks = AsyncStream<[SimilarPhotoCandidate]> { continuation in
            Task.detached(priority: .userInitiated) {
                var buffer: [SimilarPhotoCandidate] = []
                buffer.reserveCapacity(chunkSize)

                // Enumerate with PhotoKit's lazy iterator — never materializes
                // the full result array.
                fetched.enumerateObjects { asset, _, stop in
                    guard let creationDate = asset.creationDate else { return }
                    let resources = PHAssetResource.assetResources(for: asset)
                    let size = resources.first.flatMap {
                        ($0.value(forKey: "fileSize") as? NSNumber)?.int64Value
                    } ?? 0

                    let mediaSubtypes = asset.mediaSubtypes
                    let isLive = mediaSubtypes.contains(.photoLive)
                    let edited: Bool = {
                        guard let mod = asset.modificationDate else { return false }
                        return mod.timeIntervalSince(creationDate) > 1.0
                    }()

                    buffer.append(
                        SimilarPhotoCandidate(
                            localIdentifier: asset.localIdentifier,
                            creationDate: creationDate,
                            pixelWidth: asset.pixelWidth,
                            pixelHeight: asset.pixelHeight,
                            estimatedFileSize: size,
                            isFavorite: asset.isFavorite,
                            isHidden: asset.isHidden,
                            isLivePhoto: isLive,
                            hasBeenEdited: edited,
                            isInUserAlbum: false,
                            burstIdentifier: asset.burstIdentifier
                        )
                    )

                    if buffer.count >= chunkSize {
                        continuation.yield(buffer)
                        buffer.removeAll(keepingCapacity: true)
                    }
                }

                if !buffer.isEmpty {
                    continuation.yield(buffer)
                }
                continuation.finish()
            }
        }

        return PhotoCandidatesStream(totalCount: totalCount, chunks: chunks)
    }

    /// Fetch photo candidates for similar-photo clustering. Returns lightweight value
    /// types with the metadata needed for keeper-scoring. Sorted by date ascending so
    /// that time-bucketing is deterministic.
    ///
    /// Most callers should prefer `fetchPhotoCandidatesStream(maxTotal:chunkSize:)`
    /// which scales to whole libraries with progress reporting. This one-shot
    /// fetch is kept for tests and the small-library fast path.
    func fetchPhotoCandidates(limit: Int = 1000) async -> [SimilarPhotoCandidate] {
        await Task.detached(priority: .userInitiated) {
            let options = PHFetchOptions()
            options.predicate = NSPredicate(
                format: "mediaType == %d",
                PHAssetMediaType.image.rawValue
            )
            options.sortDescriptors = [
                NSSortDescriptor(key: "creationDate", ascending: true)
            ]
            options.fetchLimit = limit

            let fetched = PHAsset.fetchAssets(with: options)
            var result: [SimilarPhotoCandidate] = []
            result.reserveCapacity(fetched.count)

            fetched.enumerateObjects { asset, _, _ in
                guard let creationDate = asset.creationDate else { return }
                let resources = PHAssetResource.assetResources(for: asset)
                let size = resources.first.flatMap {
                    ($0.value(forKey: "fileSize") as? NSNumber)?.int64Value
                } ?? 0

                let mediaSubtypes = asset.mediaSubtypes
                let isLive = mediaSubtypes.contains(.photoLive)
                // PHAsset doesn't expose hasBeenEdited directly; modificationDate
                // strictly greater than creationDate is the standard heuristic.
                let edited: Bool = {
                    guard let mod = asset.modificationDate else { return false }
                    return mod.timeIntervalSince(creationDate) > 1.0
                }()

                result.append(
                    SimilarPhotoCandidate(
                        localIdentifier: asset.localIdentifier,
                        creationDate: creationDate,
                        pixelWidth: asset.pixelWidth,
                        pixelHeight: asset.pixelHeight,
                        estimatedFileSize: size,
                        isFavorite: asset.isFavorite,
                        isHidden: asset.isHidden,
                        isLivePhoto: isLive,
                        hasBeenEdited: edited,
                        // We deliberately skip the album-membership lookup here — it
                        // requires a fetch per asset and the keeper-scoring pipeline
                        // treats this as a soft preference. The scan service can
                        // populate it for tight-cluster cases later.
                        isInUserAlbum: false,
                        burstIdentifier: asset.burstIdentifier
                    )
                )
            }

            return result
        }.value
    }

    /// Fetch Live Photos sorted by file size descending. Live Photos carry a
    /// video sidecar that typically adds ~40% to file size — meaningful when
    /// reviewing for storage reclaim.
    ///
    /// Uses the two-pass estimate-then-real-bytes strategy that
    /// `fetchLargeVideos` uses, since Live Photos can also be large and
    /// per-asset fileSize calls are expensive on big libraries.
    func fetchLivePhotos(limit: Int = 200) async -> [LivePhotoSummary] {
        await Task.detached(priority: .userInitiated) {
            let options = PHFetchOptions()
            options.predicate = NSPredicate(
                format: "mediaType == %d AND (mediaSubtypes & %d) != 0",
                PHAssetMediaType.image.rawValue,
                PHAssetMediaSubtype.photoLive.rawValue
            )
            options.sortDescriptors = [
                NSSortDescriptor(key: "creationDate", ascending: false)
            ]

            let fetched = PHAsset.fetchAssets(with: options)

            // Pass 1: cheap enumeration with estimate. Live Photo bytes
            // estimator is roughly the still HEIC + a short H.264 video.
            struct PreliminaryRow {
                let asset: PHAsset
                let estimate: Int64
            }
            var prelim: [PreliminaryRow] = []
            prelim.reserveCapacity(fetched.count)
            fetched.enumerateObjects { asset, _, _ in
                let stillEstimate = Self.estimatedScreenshotBytes(
                    pixelWidth: asset.pixelWidth,
                    pixelHeight: asset.pixelHeight
                )
                // Live Photo video portion: ~1.5 seconds at modest H.264 ≈ 2 MB
                let videoEstimate: Int64 = 2_000_000
                prelim.append(PreliminaryRow(asset: asset, estimate: stillEstimate + videoEstimate))
            }

            let topCandidates = prelim
                .sorted { $0.estimate > $1.estimate }
                .prefix(limit)

            var summaries: [LivePhotoSummary] = []
            summaries.reserveCapacity(topCandidates.count)
            for row in topCandidates {
                let asset = row.asset
                let realSize = Self.fileSize(of: asset)
                let bytes = realSize > 0 ? realSize : row.estimate

                summaries.append(
                    LivePhotoSummary(
                        localIdentifier: asset.localIdentifier,
                        creationDate: asset.creationDate,
                        pixelWidth: asset.pixelWidth,
                        pixelHeight: asset.pixelHeight,
                        fileSize: bytes,
                        isFavorite: asset.isFavorite,
                        isHidden: asset.isHidden
                    )
                )
            }

            return summaries.sorted { $0.fileSize > $1.fileSize }
        }.value
    }

    /// Fetch screenshot assets (most recent first).
    func fetchScreenshots(limit: Int = 1000) async -> [ScreenshotSummary] {
        await Task.detached(priority: .userInitiated) {
            let options = PHFetchOptions()
            options.predicate = NSPredicate(
                format: "(mediaSubtypes & %d) != 0",
                PHAssetMediaSubtype.photoScreenshot.rawValue
            )
            options.sortDescriptors = [
                NSSortDescriptor(key: "creationDate", ascending: false)
            ]
            options.fetchLimit = limit

            let fetched = PHAsset.fetchAssets(with: options)
            var summaries: [ScreenshotSummary] = []
            summaries.reserveCapacity(fetched.count)

            fetched.enumerateObjects { asset, _, _ in
                summaries.append(
                    ScreenshotSummary(
                        localIdentifier: asset.localIdentifier,
                        creationDate: asset.creationDate,
                        pixelWidth: asset.pixelWidth,
                        pixelHeight: asset.pixelHeight,
                        isFavorite: asset.isFavorite,
                        isHidden: asset.isHidden
                    )
                )
            }

            return summaries
        }.value
    }

    // MARK: - Thumbnails

    /// Outcome of a thumbnail request, with enough metadata for the UI to
    /// distinguish "nothing here" from "in iCloud, not downloaded yet".
    struct ThumbnailResult: Sendable {
        let image: UIImage?
        /// True when PhotoKit reports the asset has cloud-only resources and
        /// we couldn't fulfill the request without network. UI can render a
        /// "tap to download" affordance.
        let isCloudOnly: Bool
    }

    /// Request a thumbnail. `isNetworkAccessAllowed` defaults to `false` so we
    /// never silently download iCloud assets in the background. Returns `nil`
    /// for cloud-only assets — callers should handle that gracefully.
    nonisolated func requestThumbnail(
        for identifier: String,
        targetSize: CGSize,
        contentMode: PHImageContentMode = .aspectFill
    ) async -> UIImage? {
        await requestThumbnailWithMetadata(
            for: identifier,
            targetSize: targetSize,
            contentMode: contentMode
        ).image
    }

    /// Same as `requestThumbnail` but also reports whether the failure (if any)
    /// is because the asset is in iCloud and not downloaded. Used by
    /// `ThumbnailView` to choose between the generic placeholder and the
    /// download-affordance state.
    nonisolated func requestThumbnailWithMetadata(
        for identifier: String,
        targetSize: CGSize,
        contentMode: PHImageContentMode = .aspectFill
    ) async -> ThumbnailResult {
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        guard let asset = assets.firstObject else {
            return ThumbnailResult(image: nil, isCloudOnly: false)
        }

        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.isNetworkAccessAllowed = false
        options.isSynchronous = false
        options.resizeMode = .fast

        return await withCheckedContinuation { (continuation: CheckedContinuation<ThumbnailResult, Never>) in
            var resumed = false
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: contentMode,
                options: options
            ) { image, info in
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                if !isDegraded && !resumed {
                    resumed = true
                    let isCloudOnly = (info?[PHImageResultIsInCloudKey] as? Bool) ?? false
                    continuation.resume(returning: ThumbnailResult(
                        image: image,
                        isCloudOnly: image == nil && isCloudOnly
                    ))
                }
            }
        }
    }

    /// Request a thumbnail with iCloud download permitted. Use **only** on
    /// explicit user action (tap-to-load), never as a default — silent
    /// downloads burn the user's cellular data and battery and violate the
    /// "no hidden cloud" promise.
    nonisolated func requestThumbnailAllowingDownload(
        for identifier: String,
        targetSize: CGSize,
        contentMode: PHImageContentMode = .aspectFill
    ) async -> UIImage? {
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        guard let asset = assets.firstObject else { return nil }

        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false
        options.resizeMode = .fast

        return await withCheckedContinuation { (continuation: CheckedContinuation<UIImage?, Never>) in
            var resumed = false
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: contentMode,
                options: options
            ) { image, info in
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                if !isDegraded && !resumed {
                    resumed = true
                    continuation.resume(returning: image)
                }
            }
        }
    }

    // MARK: - Deletion

    /// Delete the assets matching these identifiers. Triggers the iOS system
    /// confirmation sheet. Items go to Recently Deleted for 30 days.
    func delete(identifiers: [String]) async throws {
        let assets = resolveAssets(for: identifiers)
        guard !assets.isEmpty else { return }

        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets(assets as NSArray)
        }
    }

    // MARK: - Private helpers

    private func resolveAssets(for identifiers: [String]) -> [PHAsset] {
        guard !identifiers.isEmpty else { return [] }
        let fetched = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
        var result: [PHAsset] = []
        result.reserveCapacity(fetched.count)
        fetched.enumerateObjects { asset, _, _ in
            result.append(asset)
        }
        return result
    }

    nonisolated private static func fileSize(of asset: PHAsset) -> Int64 {
        let resources = PHAssetResource.assetResources(for: asset)
        for resource in resources {
            if let size = resource.value(forKey: "fileSize") as? NSNumber {
                return size.int64Value
            }
        }
        return 0
    }
}
