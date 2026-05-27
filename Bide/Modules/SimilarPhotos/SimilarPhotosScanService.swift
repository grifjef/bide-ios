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

    private let photoLibrary: PhotoLibraryService
    private let vision = VisionService()

    /// Lower this to make scans faster on first launch; raise it for completeness.
    /// In v0.2 we cap at 500 to keep first-scan latency low; v0.3 will store the
    /// feature-print index in SwiftData and resume incrementally.
    let scanLimit: Int

    /// Vision feature-print thumbnails are small — 256×256 is plenty for similarity
    /// signal and dramatically faster than full-resolution fetches.
    private let thumbnailSize = CGSize(width: 256, height: 256)

    private var currentTask: Task<Void, Never>?

    init(photoLibrary: PhotoLibraryService, scanLimit: Int = 500) {
        self.photoLibrary = photoLibrary
        self.scanLimit = scanLimit
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

        // 2. Time-bucket the candidates
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

        // 3. For each multi-bucket, fetch thumbnails + feature prints, then cluster
        var allClusters: [PhotoCluster] = []
        for bucket in multiBuckets {
            if Task.isCancelled { state = .cancelled; return }

            var bucketPairs: [(candidate: SimilarPhotoCandidate, featurePrint: VNFeaturePrintObservation)] = []
            for candidate in bucket {
                if Task.isCancelled { state = .cancelled; return }
                processed += 1
                state = .scanning(
                    progress: Double(processed) / Double(totalToProcess),
                    label: "Comparing photos from \(formatted(candidate.creationDate))…"
                )

                guard let image = await photoLibrary.requestThumbnail(
                    for: candidate.localIdentifier,
                    targetSize: thumbnailSize
                ) else { continue }

                if Task.isCancelled { state = .cancelled; return }

                guard let fp = await vision.featurePrint(for: image) else { continue }
                bucketPairs.append((candidate, fp))
                featurePrintsComputed += 1
            }

            guard bucketPairs.count >= 2 else { continue }

            // 4. Cluster within this bucket. We bypass the public time-bucketing
            // (we already bucketed) and go straight to distance clustering.
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
