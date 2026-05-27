# Bide architecture

> **Status:** Reflects v0.2 (post-launch refactor of Screenshots + Similar Photos + Blurry Shots).

This document describes the actual code as it exists today. If you change the architecture, update this file in the same PR.

---

## Goals

1. **All work happens on-device.** No backend. No third-party SDKs that touch user data.
2. **PhotoKit and Vision are contained in thin adapters** (`PhotoLibraryService`, `VisionService`). The rest of the app talks in Sendable value types — easy to test, easy to move across actor boundaries.
3. **Algorithms are pure where possible.** Clustering and blur detection are pure functions; the orchestration services are thin layers on top.
4. **Nothing deletes until the Review Basket confirms.** The basket is the trust mechanism.

---

## Layers

```
┌──────────────────────────────────────────────────────────────┐
│  UI (SwiftUI)                                                │
│   RootView → OnboardingView | DashboardView                  │
│   DashboardView → LargeVideosView                            │
│                 → ScreenshotsView                            │
│                 → SimilarPhotosView → ClusterReviewView      │
│                 → BlurryShotsView                            │
│   ReviewBasketView, SettingsView                             │
└──────────────────────────────────────────────────────────────┘
                            ↑
                            │ @Environment / @Observable
                            ↓
┌──────────────────────────────────────────────────────────────┐
│  State (MainActor)                                           │
│   AppState           — onboarding vs. ready phase            │
│   ReviewBasket       — items pending deletion                │
│   *ScanService /     — per-module scan orchestration         │
│   *ViewModel           (LargeVideos, Screenshots,            │
│                         SimilarPhotos, BlurryShots)          │
└──────────────────────────────────────────────────────────────┘
                            ↑
                            │ async / non-isolated
                            ↓
┌──────────────────────────────────────────────────────────────┐
│  Pure logic                                                  │
│   SimilarityClusterer  — time bucketing + union-find + scoring│
│   BlurDetector         — Laplacian variance                  │
│   PhotoLibraryService.estimatedVideoBytes — bitrate heuristic│
└──────────────────────────────────────────────────────────────┘
                            ↑
                            ↓
┌──────────────────────────────────────────────────────────────┐
│  Adapters                                                    │
│   PhotoLibraryService  — wraps PHPhotoLibrary, PHAsset       │
│   VisionService        — wraps VNGenerateImageFeaturePrint   │
│   PhotoLibraryObserver — PHPhotoLibraryChangeObserver        │
│   BideStore            — SwiftData container                 │
└──────────────────────────────────────────────────────────────┘
                            ↑
                            ↓
                  PhotoKit · Vision · SwiftData · MetricKit
```

### Where actor isolation matters

- **`@MainActor`**: anything published to SwiftUI (`AppState`, `ReviewBasket`, the four scan services / view models, `PhotoLibraryService` for auth status and basic fetches).
- **`nonisolated`**: pure helpers (`SimilarityClusterer`, `BlurDetector`, `PhotoLibraryService.estimatedVideoBytes`, `PhotoLibraryService.requestThumbnail`). Tests can call these directly without `@MainActor`.
- **`Task.detached`**: heavy work inside `PhotoLibraryService` (PhotoKit fetches that block on Core Data joins) runs detached so the main thread stays responsive.

---

## Value types

The boundary between PhotoKit and the rest of the app is a set of Sendable value structs. Each module has the value type it needs:

| Type | Fields | Producer |
|---|---|---|
| `LargeVideoSummary` | id, date, duration, dims, bytes, isFavorite, isHidden | `PhotoLibraryService.fetchLargeVideos` |
| `ScreenshotSummary` | id, date, dims, isFavorite, isHidden | `PhotoLibraryService.fetchScreenshots` |
| `SimilarPhotoCandidate` | id, date, dims, bytes, isFavorite, isHidden, isLivePhoto, hasBeenEdited, isInUserAlbum | `PhotoLibraryService.fetchPhotoCandidates` |
| `BlurryCandidate` | id, date, dims, bytes, isFavorite, isHidden, blurScore | `BlurryShotsScanService` (after running BlurDetector) |
| `PhotoCluster` | id, repDate, candidates, suggestedKeeperId, reason | `SimilarPhotosScanService` (after running SimilarityClusterer) |

No `PHAsset` references leak past the adapter. This is what makes the rest of the app trivially Sendable and testable.

---

## Data flow: a Similar Photos scan (end to end)

The most architecturally interesting flow. Other modules follow simpler versions of the same pattern.

```
User taps "Similar photos"
   │
   ▼
SimilarPhotosView.task { … }
   │   creates SimilarPhotosScanService(photoLibrary:)
   │   calls startScanIfNeeded()
   ▼
SimilarPhotosScanService.runScan()  (Task, MainActor → detached for I/O)
   │
   ├── PhotoLibraryService.fetchPhotoCandidates(limit: 500)
   │      Task.detached → PHFetchResult enumeration → [SimilarPhotoCandidate]
   │
   ├── SimilarityClusterer.timeBuckets(_, date:, window: 3600)   ← PURE
   │      adjacency-by-date with windowed gap; sorts buckets ↑
   │
   ├── For each multi-item bucket:
   │     ├── PhotoLibraryService.requestThumbnail(id, 256×256)   ← nonisolated
   │     │     PHImageManager + isNetworkAccessAllowed = false
   │     │
   │     ├── VisionService.featurePrint(for: UIImage)            ← nonisolated
   │     │     VNGenerateImageFeaturePrintRequest, current revision
   │     │
   │     └── SimilarityClusterer.clusterByDistance(_,             ← PURE
   │              distance: { vision.distance(from:, to:) },
   │              threshold: 12.0)
   │           union-find with injected distance fn
   │
   ├── For each cluster:
   │     ├── SimilarityClusterer.pickKeeper(_)                    ← PURE
   │     │     favorite > edited > inAlbum > LivePhoto > res > newer
   │     └── SimilarityClusterer.keeperReason(_, keeperId:)        ← PURE
   │           plain-English explanation
   │
   └── publish clusters → SimilarPhotosView re-renders
```

**Cancellation**: every `await` point in `runScan` is preceded by `if Task.isCancelled { state = .cancelled; return }`. The user's "Cancel scan" button calls `currentTask?.cancel()`.

**Library mutations during scan**: `PhotoLibraryObserver` registers a `PHPhotoLibraryChangeObserver`. When a change fires, `handleLibraryChange` runs the cluster list through the change set and drops any cluster whose suggested keeper was deleted, trims members that were deleted from clusters that still have ≥2 members, and sets `libraryHasChangedSinceLastScan = true` so the UI can show "Library changed — scan again?".

---

## Persistence

Current state: **SwiftData container exists, but only the `IndexedAsset` model is defined**. We don't actually persist anything yet — every scan re-fetches from PhotoKit. This is intentional for v0.2; the in-memory results are small enough.

v0.3 work: write feature prints + cluster IDs to `IndexedAsset` so subsequent scans are incremental rather than from-scratch. The schema is already in place — see `Bide/Models/IndexedAsset.swift`.

---

## SwiftData schema (defined but unused in v0.2)

`IndexedAsset` carries the local-index fields from spec §12. Fields:

- `localIdentifier` (unique) — primary key, matches PHAsset
- `creationDate`, `modificationDate` — for time bucketing
- `mediaType`, `mediaSubtypes` — for filtering
- `pixelWidth`, `pixelHeight`, `duration` — for keeper scoring + estimates
- `isFavorite`, `isHidden` — for protection rules
- `estimatedFileSize` — for sort by size
- `burstIdentifier` — for burst-mode grouping (future)
- `sourceType` — PHAssetSourceType.rawValue
- `lastAnalyzedAt` — incremental scan trigger
- `riskLevelRaw` — 0/1/2 = low/medium/high
- `clusterIdentifier` — UUID of the PhotoCluster this belongs to

When we wire this up (v0.3), the rule is: cluster IDs are stable across runs as long as the same set of assets produces the same cluster — but if the user adds new photos in the cluster's time window, we re-cluster the bucket. Feature prints are tagged with `featurePrintVersion = VNGenerateImageFeaturePrintRequest.currentRevision` so that an iOS update with a new revision triggers a full re-cluster.

---

## Crash + diagnostics

**MetricKit only.** No Sentry, Firebase, Crashlytics. Apple writes diagnostic payloads to a system framework; we don't currently subscribe to them in-app (v0.3) but Apple's Organizer in Xcode reads them server-side.

When v0.3 wires `MXMetricManagerSubscriber`, the data stays on-device; we only act on it (e.g. write to a local log) — no telemetry leaves.

---

## Testing strategy

- **Unit tests** in `BideTests/` — pure logic and small services. 60 tests as of v0.2:
  - `AppStateTests` — onboarding phase persistence
  - `ReviewBasketTests` — add/remove/toggle/clear semantics
  - `ScreenshotsViewModelTests` — month grouping, protection rules
  - `SimilarityClustererTests` — time bucketing, union-find clustering, keeper selection, reason strings
  - `BlurDetectorTests` — Laplacian variance + downscale pipeline against synthetic UIImages
  - `PhotoLibraryEstimatorTests` — bitrate-tier heuristic boundaries
- **UI tests** in `BideUITests/` — launch smoke test only for v0.2. Phase 1 of v0.3 should add basket→delete flow and onboarding pass-through tests with photo-library fixtures.

To keep tests fast (≤0.1s total currently), we never instantiate PhotoKit in unit tests. The scan services depend on `PhotoLibraryService` directly today; making that a protocol would be the next step if tests for the scan services themselves are needed.

---

## File layout

```
Bide/
├── BideApp.swift                       — @main, scene phase → auth refresh
├── RootView.swift                      — onboarding vs ready
├── State/
│   └── AppState.swift                  — onboarding phase persistence
├── Theme/
│   └── BideTheme.swift                 — colors, spacing, typography
├── Components/
│   └── ThumbnailView.swift             — PhotoKit thumbnail with placeholder
├── Onboarding/
│   └── OnboardingView.swift            — 3-page TabView + permission request
├── Dashboard/
│   ├── DashboardView.swift             — module cards + review-basket bar
│   └── ModuleCard.swift                — reusable card
├── Modules/
│   ├── LargeVideos/
│   │   ├── LargeVideosView.swift
│   │   └── LargeVideosViewModel.swift
│   ├── Screenshots/
│   │   ├── ScreenshotsView.swift
│   │   └── ScreenshotsViewModel.swift
│   ├── SimilarPhotos/
│   │   ├── SimilarPhotoCandidate.swift  — value types
│   │   ├── SimilarityClusterer.swift    — pure algorithm
│   │   ├── SimilarPhotosScanService.swift — orchestration
│   │   ├── SimilarPhotosView.swift      — cluster list
│   │   └── ClusterReviewView.swift      — cluster detail
│   └── BlurryShots/
│       ├── BlurryCandidate.swift
│       ├── BlurryShotsScanService.swift
│       └── BlurryShotsView.swift
├── Models/
│   ├── AssetSummaries.swift            — LargeVideoSummary, ScreenshotSummary
│   └── IndexedAsset.swift              — SwiftData model
├── Services/
│   ├── PhotoLibraryService.swift       — PhotoKit adapter
│   ├── PhotoLibraryObserver.swift      — PHPhotoLibraryChangeObserver wrapper
│   ├── VisionService.swift             — Vision adapter
│   └── BlurDetector.swift              — pure Laplacian variance
├── Persistence/
│   └── BideStore.swift                 — SwiftData container factory
├── ReviewBasket/
│   ├── ReviewBasket.swift              — basket state
│   └── ReviewBasketView.swift          — basket UI + delete confirmation
├── Settings/
│   └── SettingsView.swift              — privacy promise, GitHub link
└── Assets.xcassets, Preview Content/
```

---

## What this architecture explicitly does NOT do

These are choices, not gaps. Listed here so future contributors don't accidentally undo them.

- **No `Combine` Publishers.** `@Observable` + `async` covers our needs and avoids the cancellation/threading complexity of `AnyCancellable`.
- **No `UIViewControllerRepresentable`.** Everything is SwiftUI. `PhotoLibraryService.requestThumbnail` returns `UIImage` only because PhotoKit's API requires it; the SwiftUI side wraps it in an `Image`.
- **No CoreData → SwiftData migration.** We started on SwiftData; no legacy to bridge.
- **No third-party packages.** Zero SPM dependencies. Every line is either ours or first-party Apple.
- **No `UserDefaults` for app data.** Only for the onboarding-completed flag. Everything else lives in SwiftData (or, in v0.2, in-memory).
