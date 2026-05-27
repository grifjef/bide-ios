import Foundation
import Photos
import Vision
import UIKit
import Observation

/// Orchestrates the similar-photo scan:
///   1. Fetch candidates from PhotoKit
///   2. Time-bucket them so we only generate feature prints for buckets with ≥2 items
///   3. For each candidate in a multi-item bucket, request a small thumbnail and
///      compute its Vision feature print
///   4. Hand the (candidate, feature print) pairs to `SimilarityClusterer`
///
/// Heavy work runs off the main actor. Progress is observable so the UI can show
/// a "scanning…" state.
@Observable
@MainActor
final class SimilarPhotosScanService {

    enum ScanState: Equatable {
        case idle
        case scanning(progress: Double, label: String)
        case completed
        case cancelled
        case failed(String)
    }

    private(set) var state: ScanState = .idle
    private(set) var clusters: [PhotoCluster] = []
    private(set) var lastCompletedAt: Date?
    private(set) var totalAssetsConsidered: Int = 0
    private(set) var bucketsConsidered: Int = 0
    private(set) var featurePrintsComputed: Int = 0
    private(set) var featurePrintsReused: Int = 0
    private(set) var indexedEntriesReconciled: Int = 0

    private let photoLibrary: PhotoLibraryService
    private let vision = VisionService()

    /// Optional persistent index. When provided, scans reuse feature prints
    /// whose stored revision matches Vision's current revision instead of
    /// recomputing. Production code passes the app's `IndexedAssetStore`;
    /// tests can pass nil to fall back to the v0.2 behavior.
    private let indexedAssetStore: IndexedAssetStore?

    /// Lower this to make scans faster on first launch; raise it for completeness.
    /// In v0.2 we cap at 500 to keep first-scan latency low; v0.3 will store the
    /// feature-print index in SwiftData and resume incrementally.
    let scanLimit: Int

    /// Vision feature-print thumbnails are small — 256×256 is plenty for similarity
    /// signal and dramatically faster than full-resolution fetches.
    private let thumbnailSize = CGSize(width: 256, height: 256)

    private var currentTask: Task<Void, Never>?

    /// Subscribes to library changes so we can invalidate stale clusters when
    /// the user (or iCloud) modifies the library while we're scanning or while
    /// the user is reviewing.
    private var libraryObserver: PhotoLibraryObserver?

    init(
        photoLibrary: PhotoLibraryService,
        scanLimit: Int = 500,
        indexedAssetStore: IndexedAssetStore? = nil
    ) {
        self.photoLibrary = photoLibrary
        self.scanLimit = scanLimit
        self.indexedAssetStore = indexedAssetStore
        // Register an observer that drops cached clusters when the underlying
        // assets change. We don't auto-rescan — we just mark the results stale.
        Task { @MainActor in
            self.libraryObserver = PhotoLibraryObserver { [weak self] change in
                Task { @MainActor in
                    self?.handleLibraryChange(change)
                }
            }
        }
    }

    /// Public entry point so the UI can react too (e.g. "Library changed, rescan?").
    private(set) var libraryHasChangedSinceLastScan: Bool = false

    private func handleLibraryChange(_ change: PHChange) {
        // Remove any cluster whose suggested keeper or members were deleted.
        // Keep everything else — the user might still be reviewing the cluster.
        let identifiers = Set(clusters.flatMap { $0.candidates.map(\.id) })
        guard !identifiers.isEmpty else { return }

        let assets = PHAsset.fetchAssets(withLocalIdentifiers: Array(identifiers), options: nil)
        var stillPresent = Set<String>()
        assets.enumerateObjects { asset, _, _ in
            stillPresent.insert(asset.localIdentifier)
        }

        let removed = identifiers.subtracting(stillPresent)
        if removed.isEmpty {
            // The library changed but our assets are intact. Mark stale so the
            // user can choose to rescan.
            libraryHasChangedSinceLastScan = true
            return
        }

        // Drop clusters where the keeper is gone; trim others' candidate lists.
        var updated: [PhotoCluster] = []
        for cluster in clusters {
            if removed.contains(cluster.suggestedKeeperId) {
                continue
            }
            let remaining = cluster.candidates.filter { !removed.contains($0.id) }
            // A cluster needs at least 2 members to be useful.
            if remaining.count < 2 { continue }
            updated.append(
                PhotoCluster(
                    id: cluster.id,
                    representativeDate: cluster.representativeDate,
                    candidates: remaining,
                    suggestedKeeperId: cluster.suggestedKeeperId,
                    suggestedKeeperReason: cluster.suggestedKeeperReason
                )
            )
        }
        clusters = updated
        libraryHasChangedSinceLastScan = true
    }

    // MARK: - Public API

    func startScanIfNeeded() {
        if case .scanning = state { return }
        if case .completed = state { return }
        startScan()
    }

    func startScan() {
        currentTask?.cancel()
        clusters = []
        totalAssetsConsidered = 0
        bucketsConsidered = 0
        featurePrintsComputed = 0
        featurePrintsReused = 0
        indexedEntriesReconciled = 0
        state = .scanning(progress: 0, label: "Looking through your photos…")

        currentTask = Task { [photoLibrary, vision, scanLimit, thumbnailSize] in
            await self.runScan(
                photoLibrary: photoLibrary,
                vision: vision,
                scanLimit: scanLimit,
                thumbnailSize: thumbnailSize
            )
        }
    }

    func cancel() {
        currentTask?.cancel()
        state = .cancelled
    }

    // MARK: - Internals

    private func runScan(
        photoLibrary: PhotoLibraryService,
        vision: VisionService,
        scanLimit: Int,
        thumbnailSize: CGSize
    ) async {
        // 1. Fetch candidates
        let candidates = await photoLibrary.fetchPhotoCandidates(limit: scanLimit)
        totalAssetsConsidered = candidates.count

        if Task.isCancelled { state = .cancelled; return }

        guard candidates.count >= 2 else {
            state = .completed
            lastCompletedAt = Date()
            return
        }

        // 2. Reconcile the persistent index against present identifiers — drop
        //    any indexed entries whose underlying PhotoKit asset no longer exists.
        //    Cheap (only deletes), and keeps the cache from growing unbounded.
        if let store = indexedAssetStore {
            let present = Set(candidates.map(\.localIdentifier))
            indexedEntriesReconciled = (try? store.reconcile(against: present)) ?? 0
        }

        // 3. Time-bucket the candidates
        let buckets = SimilarityClusterer.timeBuckets(
            candidates,
            date: { $0.creationDate },
            window: SimilarityClusterer.defaultTimeWindowSeconds
        )
        let multiBuckets = buckets.filter { $0.count >= 2 }
        bucketsConsidered = multiBuckets.count

        if multiBuckets.isEmpty {
            state = .completed
            lastCompletedAt = Date()
            return
        }

        let totalToProcess = multiBuckets.reduce(0) { $0 + $1.count }
        var processed = 0
        let currentVisionRevision = VisionService.currentRevision

        // 4. For each multi-bucket, build (candidate, featurePrint) pairs —
        //    reusing stored prints where possible, computing + persisting new ones.
        var allClusters: [PhotoCluster] = []
        for bucket in multiBuckets {
            if Task.isCancelled { state = .cancelled; return }

            var bucketPairs: [(candidate: SimilarPhotoCandidate, featurePrint: VNFeaturePrintObservation)] = []
            for candidate in bucket {
                if Task.isCancelled { state = .cancelled; return }
                processed += 1

                // 4a. Try the index first. If we have a print at the current
                //     Vision revision, skip all the expensive work.
                if let store = indexedAssetStore,
                   let stored = try? store.storedFeaturePrint(
                       for: candidate.localIdentifier,
                       requiredVersion: currentVisionRevision
                   ) {
                    bucketPairs.append((candidate, stored))
                    featurePrintsReused += 1
                    state = .scanning(
                        progress: Double(processed) / Double(totalToProcess),
                        label: "Comparing photos from \(formatted(candidate.creationDate))…"
                    )
                    continue
                }

                // 4b. Miss — fetch a thumbnail, compute a print, persist it.
                state = .scanning(
                    progress: Double(processed) / Double(totalToProcess),
                    label: "Analyzing new photos from \(formatted(candidate.creationDate))…"
                )

                guard let image = await photoLibrary.requestThumbnail(
                    for: candidate.localIdentifier,
                    targetSize: thumbnailSize
                ) else { continue }

                if Task.isCancelled { state = .cancelled; return }

                guard let fp = await vision.featurePrint(for: image) else { continue }
                bucketPairs.append((candidate, fp))
                featurePrintsComputed += 1

                // Best-effort persist. Don't fail the scan on a store error.
                if let store = indexedAssetStore {
                    _ = try? store.upsertFeaturePrint(
                        for: candidate,
                        featurePrint: fp,
                        version: currentVisionRevision
                    )
                }
            }

            guard bucketPairs.count >= 2 else { continue }

            // 5. Cluster within this bucket. We bypass the public time-bucketing
            //    (we already bucketed) and go straight to distance clustering.
            let groups = SimilarityClusterer.clusterByDistance(
                bucketPairs,
                distance: { a, b in vision.distance(from: a.featurePrint, to: b.featurePrint) },
                threshold: SimilarityClusterer.defaultDistanceThreshold
            )

            for group in groups where group.count >= 2 {
                let cands = group.map(\.candidate)
                let keeper = SimilarityClusterer.pickKeeper(cands)
                let reason = SimilarityClusterer.keeperReason(cands, keeperId: keeper.id)
                allClusters.append(
                    PhotoCluster(
                        id: UUID(),
                        representativeDate: cands.map(\.creationDate).min() ?? Date(),
                        candidates: cands.sorted { $0.creationDate < $1.creationDate },
                        suggestedKeeperId: keeper.id,
                        suggestedKeeperReason: reason
                    )
                )
            }
        }

        clusters = allClusters.sorted { $0.representativeDate > $1.representativeDate }
        state = .completed
        lastCompletedAt = Date()
    }

    private nonisolated func formatted(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
