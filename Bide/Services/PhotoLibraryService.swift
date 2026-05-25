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
    /// Note: fileSize lookup is somewhat expensive (per-asset), so we cap at `limit`.
    func fetchLargeVideos(limit: Int = 200) async -> [LargeVideoSummary] {
        await Task.detached(priority: .userInitiated) {
            let options = PHFetchOptions()
            options.predicate = NSPredicate(
                format: "mediaType == %d",
                PHAssetMediaType.video.rawValue
            )
            // Sort by date first to give us a stable iteration order.
            options.sortDescriptors = [
                NSSortDescriptor(key: "creationDate", ascending: false)
            ]

            let fetched = PHAsset.fetchAssets(with: options)
            var summaries: [LargeVideoSummary] = []
            summaries.reserveCapacity(min(fetched.count, 1000))

            fetched.enumerateObjects { asset, _, _ in
                let size = Self.fileSize(of: asset)
                summaries.append(
                    LargeVideoSummary(
                        localIdentifier: asset.localIdentifier,
                        creationDate: asset.creationDate,
                        duration: asset.duration,
                        pixelWidth: asset.pixelWidth,
                        pixelHeight: asset.pixelHeight,
                        fileSize: size,
                        isFavorite: asset.isFavorite,
                        isHidden: asset.isHidden,
                        sourceTypeIsCamera: asset.sourceType == .typeUserLibrary
                    )
                )
            }

            return Array(
                summaries
                    .sorted { $0.fileSize > $1.fileSize }
                    .prefix(limit)
            )
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
