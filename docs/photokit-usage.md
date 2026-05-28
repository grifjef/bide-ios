# PhotoKit usage

> The patterns Bide uses for every PhotoKit operation, plus the rules of the road. If you're touching `Photos.framework` in this project, read this first.

PhotoKit access is concentrated in `Bide/Services/PhotoLibraryService.swift` and `Bide/Services/PhotoLibraryObserver.swift`. The rest of the app talks in Sendable value types and never imports `Photos`.

---

## Authorization

We request `.readWrite` access (we need to read for clustering and write for `deleteAssets`):

```swift
PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in … }
```

Wrapped as `async` in `PhotoLibraryService.requestAuthorization()` and called once from `OnboardingView` after the user taps "Give Bide photo access".

Authorization status is re-read whenever the app returns to foreground (`BideApp.onChange(of: scenePhase) { … }`), so toggling permission in iOS Settings shows up immediately without an app restart.

`Info.plist` keys (set in `project.yml` as `INFOPLIST_KEY_*`):

- `NSPhotoLibraryUsageDescription`: "Bide reads your photo library on this device to find clutter — large videos, screenshots, and similar shots — so you can review and clear what you want. Nothing is uploaded by us."
- `NSPhotoLibraryAddUsageDescription`: requested as a fallback only; Bide never writes.

### Status branching

```swift
switch photoLibrary.authStatus {
case .authorized, .limited:
    // hasReadAccess == true; modules are enabled
case .denied, .restricted:
    // Show "Open Settings" CTA; no scan attempts
case .notDetermined:
    // User hasn't been prompted yet — kick OnboardingView
@unknown default:
    // Treat as denied
}
```

`PhotoLibraryService.hasReadAccess` returns `true` for `.authorized || .limited`. Use this everywhere rather than checking `.authorized` alone — limited-library users still see partial scan results, which is the right experience.

---

## Fetching assets

Always use `PHFetchOptions` with a predicate. Never iterate without one.

### Fetch video assets

```swift
let options = PHFetchOptions()
options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.video.rawValue)
options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
let fetched = PHAsset.fetchAssets(with: options)
```

### Fetch screenshots (by media subtype)

```swift
options.predicate = NSPredicate(
    format: "(mediaSubtypes & %d) != 0",
    PHAssetMediaSubtype.photoScreenshot.rawValue
)
```

### Fetch generic photos for similar/blurry scans

```swift
options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
options.fetchLimit = 500   // cap on first scan
```

### Always enumerate inside the adapter

PhotoKit fetch results are lazy; the underlying objects can change when the library mutates. Our convention: enumerate fully inside the adapter and copy into Sendable structs. Once the values escape the adapter, they're stable.

```swift
fetched.enumerateObjects { asset, _, _ in
    // build a value struct from `asset`, append to a local array
}
```

`fetchLargeVideos` does a two-pass version of this — enumerate-with-estimate first, then targeted real-size lookups on the top N candidates. See `Bide/Services/PhotoLibraryService.swift` and the [byte size estimation](#byte-size-estimation) section below.

---

## Thumbnails

We use `PHImageManager.default()` directly (no caching manager yet) because thumbnails are fetched once per visible row and cached by SwiftUI's view system. If you need a true `PHCachingImageManager`, hold it on the service and `startCachingImages` / `stopCachingImages` as the scroll view ranges change.

```swift
let options = PHImageRequestOptions()
options.deliveryMode = .opportunistic
options.isNetworkAccessAllowed = false   // critical — see "iCloud Photos" below
options.isSynchronous = false
options.resizeMode = .fast

PHImageManager.default().requestImage(
    for: asset,
    targetSize: CGSize(width: 256, height: 256),  // scaled up by UIScreen.main.scale internally
    contentMode: .aspectFill,
    options: options
) { image, info in
    let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
    // opportunistic delivers low-res then high-res — only resume once on the final
}
```

`PhotoLibraryService.requestThumbnail` is `nonisolated` so the scan services and `ThumbnailView` can call it without main-actor hopping.

---

## iCloud Photos

This is the most important rule in this file: **`isNetworkAccessAllowed = false` is the default**.

- An iCloud-only asset that isn't downloaded locally returns `nil` from a thumbnail request when `isNetworkAccessAllowed = false`. Callers handle that by showing a placeholder and skipping further processing.
- If we set `isNetworkAccessAllowed = true`, scanning a large library will silently kick off iCloud downloads in the background. That burns the user's cellular data and battery and is exactly the kind of "trust violation" Bide is built to avoid.

If a future feature needs full-res for an asset (e.g. on-demand feature print refresh), make it user-initiated and explicit: the UI tap *is* the consent.

---

## Deletion

Always inside a `performChanges` block:

```swift
try await PHPhotoLibrary.shared().performChanges {
    PHAssetChangeRequest.deleteAssets(assets as NSArray)
}
```

iOS shows a system confirmation sheet automatically. If the user denies the sheet, the `performChanges` throws with `PHPhotosErrorDomain code 3072` — that's a *user cancel*, not an error. The `ReviewBasketView` distinguishes:

```swift
catch {
    let nsError = error as NSError
    if nsError.domain == "PHPhotosErrorDomain" && nsError.code == 3072 {
        deletionResult = .cancelled            // show "Nothing was deleted"
    } else {
        deletionResult = .failed(message)      // show the actual error
    }
}
```

Deleted assets land in Photos > Albums > Recently Deleted with the standard 30-day recovery window. Bide never reaches into Recently Deleted itself — emptying that album is Photos.app's job.

### Live Photo → still conversion

The Live Photos module offers a "Convert to still" action — keep the photo, drop the video sidecar. Implementation in `PhotoLibraryService.convertLivePhotoToStill(localIdentifier:)`:

1. Find the `.photo` resource on the Live Photo's `PHAssetResource` list.
2. `PHAssetResourceManager.default().writeData(for:toFile:options:)` into a temp file, with `isNetworkAccessAllowed = true` so iCloud-only Live Photos round-trip cleanly.
3. Inside `performChanges`:
   ```swift
   let creation = PHAssetCreationRequest.forAsset()
   creation.creationDate = source.creationDate
   creation.location = source.location
   let options = PHAssetResourceCreationOptions()
   options.originalFilename = stillResource.originalFilename
   creation.addResource(with: .photo, fileURL: tmpURL, options: options)
   ```
4. A *second* `performChanges` runs `deleteAssets([source])` to move the original Live Photo to Recently Deleted.

We split into two `performChanges` calls (not one) so the user sees the system confirmation sheet for the deletion specifically — the "save still" step is silent because it's purely additive and reversible (they can remove the new still from Recently Deleted just like anything else).

Bytes attributed to the conversion come from the paired-video resource's `fileSize`, surfaced via `LivePhotoSummary.pairedVideoSize`. When PhotoKit returns 0 (iCloud-not-downloaded), we fall back to a 40% estimate so the UI still shows an honest number.

---

## Library change observation

`PHPhotoLibraryChangeObserver` notifies us when the library mutates — other apps editing, the user editing in Photos, new captures, iCloud syncing down deletions, etc.

`Bide/Services/PhotoLibraryObserver.swift` wraps the protocol in a Sendable closure-based API:

```swift
final class PhotoLibraryObserver: NSObject, PHPhotoLibraryChangeObserver {
    private let onChange: @Sendable (PHChange) -> Void
    init(_ onChange: @escaping @Sendable (PHChange) -> Void) { … }
    deinit { PHPhotoLibrary.shared().unregisterChangeObserver(self) }
}
```

`SimilarPhotosScanService` registers one and reconciles its cluster list against the change set:

- If a cluster's `suggestedKeeperId` was deleted, drop the cluster.
- If some cluster members were deleted but the keeper survives, trim. If the cluster drops below 2 members, drop it.
- Set `libraryHasChangedSinceLastScan = true` so the UI can offer "Library changed — scan again?".

We do not auto-rescan — the user is in the middle of reviewing.

---

## Byte size estimation

`PHAssetResource.fileSize` is the only way to get exact bytes, and it triggers a per-asset Core Data join. For a 2 000-video library that's slow (~5+ seconds blocking).

`fetchLargeVideos` uses a two-pass strategy:

1. **Pass 1 (cheap):** Enumerate every video, compute an estimated byte count from `pixelWidth × pixelHeight × duration` via a bitrate-tier heuristic (`PhotoLibraryService.estimatedVideoBytes`):
   - ≥ 3.5 Mpx (4K-ish): 6 MB/s
   - ≥ 1.5 Mpx (1080p-ish): 1.5 MB/s
   - Otherwise: 0.6 MB/s
2. **Pass 2 (targeted):** Take top `limit` by estimate (default 200), then call the real `PHAssetResource.fileSize` only for those.
3. Re-sort by actual bytes (some shuffling is normal — estimate is rough).

For iCloud-only assets where `fileSize` returns 0, we fall back to the estimate so the basket total stays sensible.

The estimator is `nonisolated static` so other modules can reuse it. It's covered by `PhotoLibraryEstimatorTests`.

---

## Limited library access

When `authStatus == .limited`, the user picked a subset of photos via the system picker. Bide treats this as full access for the UI's purposes (`hasReadAccess` is true) but only the selected assets appear in fetch results. Reviews on those will be partial — that's the user's choice.

Future v0.3 work: show an in-app banner explaining limited mode and offering `PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: vc)` to expand the selection.

---

## What we deliberately don't do

These are choices, not omissions:

- **No `requestImageDataAndOrientation`** outside deletion flows. We never load full-resolution image data into memory. 256×256 thumbnails are enough for similarity (Vision feature prints) and blur detection.
- **No HEIF transcoding.** We accept the file format the asset is stored in.
- **No background photo fetches.** Scans only run while the app is foregrounded with a user-initiated tap. BGTask scheduling is on the v1.1 list.
- **No iCloud Shared Library API.** Bide is single-user. If a user shares a library, we operate on their personal portion only.
- **No `PHCachingImageManager` startCaching/stopCaching dance.** Once we hit performance issues on 50k+ libraries (v0.3 work), we'll add it — until then, the default manager is fine.
