---
name: photokit-snippets
description: Common PhotoKit patterns for the Bide app — permission flow, asset fetching, change observation, safe deletion. Use when writing code that touches PhotoKit, debugging photo-library issues, or reviewing PhotoKit-related PRs.
---

# photokit-snippets

Patterns and gotchas for working with PhotoKit in Bide.

## Permission flow

`Info.plist` keys (required — without these the app crashes on first access):

```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>Bide reads your photo library on this device to find clutter — large videos, screenshots, and similar shots — so you can review and clear what you want. Nothing is uploaded.</string>

<key>NSPhotoLibraryAddUsageDescription</key>
<string>Bide does not add photos. This permission is requested as a fallback only; you can deny it without affecting features.</string>
```

Request authorization for **read+write** so we can delete:

```swift
import Photos

func requestAuthorization() async -> PHAuthorizationStatus {
    return await withCheckedContinuation { continuation in
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
            continuation.resume(returning: status)
        }
    }
}
```

Statuses to handle:

- `.authorized` — full library access
- `.limited` — user picked a subset of photos (iOS 14+). Still usable but scan results are partial.
- `.denied` / `.restricted` — show "enable in Settings" UI
- `.notDetermined` — call `requestAuthorization` again

## Fetching assets

**Don't fetch full image data when listing.** Fetch metadata-only via `PHAsset` properties:

```swift
let options = PHFetchOptions()
options.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.video.rawValue)
options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

let assets = PHAsset.fetchAssets(with: options)
assets.enumerateObjects { asset, _, _ in
    // asset.duration, asset.pixelWidth, asset.pixelHeight,
    // asset.creationDate, asset.localIdentifier — all free
}
```

For screenshots:

```swift
let options = PHFetchOptions()
options.predicate = NSPredicate(
    format: "mediaSubtypes & %d != 0",
    PHAssetMediaSubtype.photoScreenshot.rawValue
)
```

## Thumbnails — use PHCachingImageManager

For grid views (where you scroll past many thumbnails), use `PHCachingImageManager` and **never** request full-res images:

```swift
let manager = PHCachingImageManager()
let targetSize = CGSize(width: 300, height: 300) // scale up for retina via UIScreen.main.scale

let options = PHImageRequestOptions()
options.deliveryMode = .opportunistic
options.isNetworkAccessAllowed = false // ⚠️ critical for iCloud-only assets
options.isSynchronous = false

manager.requestImage(
    for: asset,
    targetSize: targetSize,
    contentMode: .aspectFill,
    options: options
) { image, info in
    // image is nil if asset is iCloud-only and not downloaded
    // info[PHImageResultIsDegradedKey] indicates if this is a thumb vs. full
}
```

**`isNetworkAccessAllowed = false` is the right default.** If you set it `true`, scanning a large library will silently start downloading iCloud assets and burn the user's data + battery.

## File size — sample, don't iterate

`PHAsset` doesn't expose file size directly. The reliable path is `PHAssetResource.assetResources(for:)[0].value(forKey: "fileSize")` — but iterating every asset is expensive.

**Strategy:** sample 100 random assets to estimate average size per asset type, then multiply by count. Show exact size only for items the user is about to delete (Review Basket).

```swift
extension PHAsset {
    var estimatedFileSize: Int64? {
        let resources = PHAssetResource.assetResources(for: self)
        guard let first = resources.first else { return nil }
        return (first.value(forKey: "fileSize") as? NSNumber)?.int64Value
    }
}
```

## Deletion — always inside a change block

```swift
import Photos

func delete(_ assets: [PHAsset]) async throws {
    try await PHPhotoLibrary.shared().performChanges {
        PHAssetChangeRequest.deleteAssets(assets as NSArray)
    }
}
```

iOS automatically shows a system confirmation sheet for deletion. Items go to **Recently Deleted** — recoverable for 30 days. Always communicate this in our UI.

## Change observation

The user (or other apps) can modify the library during our scan. Observe and invalidate stale results:

```swift
final class PhotoLibraryObserver: NSObject, PHPhotoLibraryChangeObserver {
    private let onChange: (PHChange) -> Void

    init(_ onChange: @escaping (PHChange) -> Void) {
        self.onChange = onChange
        super.init()
        PHPhotoLibrary.shared().register(self)
    }

    deinit {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }

    func photoLibraryDidChange(_ change: PHChange) {
        onChange(change)
    }
}

// Usage in an @Observable view model:
// invalidate any cluster that contains an asset present in change.changeDetails(for:).removedObjects
```

## Limited library access

When `authorizationStatus == .limited`, we only see the photos the user explicitly granted. The user can change the selection from Settings, but we can also surface it in-app:

```swift
PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: viewController)
```

Show a clear in-app banner explaining that limited mode means partial scan results.

## Common gotchas

| Gotcha | Mitigation |
|---|---|
| iCloud-only assets return nil image data | Set `isNetworkAccessAllowed = false` for thumbs; surface "needs download" state |
| Burst photos look like duplicates | Use `asset.burstIdentifier` to group them as bursts, not similars |
| Live Photos vs. still — both have `.image` media type | Check `asset.mediaSubtypes.contains(.photoLive)` |
| Hidden album not visible by default | Use `PHFetchOptions().includeHiddenAssets = true` (we don't, by design — hidden = protected) |
| Screenshots can include screen recordings (video) | Filter `mediaSubtype` for `.photoScreenshot` AND skip videos in screenshot module |
| `localIdentifier` can change if asset is re-imported | Use as primary key but reconcile via creation date + dimensions on mismatch |
| Deletion can fail silently if user denies the confirmation sheet | `performChanges` throws — handle the error gracefully |

## Modeling assets locally

Don't try to mirror PHAsset perfectly. Store the metadata we need for clustering/UI, and re-fetch from PHAsset when displaying:

```swift
@Model
final class IndexedAsset {
    @Attribute(.unique) var localIdentifier: String
    var creationDate: Date?
    var mediaType: Int
    var mediaSubtypes: Int
    var pixelWidth: Int
    var pixelHeight: Int
    var duration: TimeInterval
    var isFavorite: Bool
    var isHidden: Bool
    var estimatedFileSize: Int64?
    var burstIdentifier: String?
    var sourceType: Int
    var lastAnalyzedAt: Date?
    var clusterID: UUID?
    var riskLevel: Int  // 0 low, 1 medium, 2 high

    // ... see docs/architecture.md for the full schema
}
```
