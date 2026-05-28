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

            // Pass 1: cheap enumeration with size estimate
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
                        sourceTypeIsCamera: asset.sourceType == .typeUserLibrary
                    )
                )
            }

            // Real sizes may shuffle the order slightly vs. estimate-sort
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

    /// Fetch photo candidates for similar-photo clustering. Returns lightweight value
    /// types with the metadata needed for keeper-scoring. Sorted by date ascending so
    /// that time-bucketing is deterministic.
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

    /// Request a thumbnail. `isNetworkAccessAllowed` defaults to `false` so we
    /// never silently download iCloud assets in the background. Returns `nil`
    /// for cloud-only assets — callers should handle that gracefully.
    nonisolated func requestThumbnail(
        for identifier: String,
        targetSize: CGSize,
        contentMode: PHImageContentMode = .aspectFill
    ) async -> UIImage? {
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        guard let asset = assets.firstObject else { return nil }

        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.isNetworkAccessAllowed = false
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
                // Opportunistic delivery can call us twice (low-res, then high-res).
                // We only want the final one; check the degraded flag.
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
