import Foundation
import Observation
import Photos
import UIKit

/// Orchestrates the blurry-shots scan:
///   1. Fetch all photo candidates from PhotoKit (same source as Similar Photos)
///   2. Filter out items that are protected by default (favorited, hidden, recent)
///   3. For each remaining candidate, fetch a thumbnail and compute `BlurDetector.analyze`
///   4. Surface anything below the threshold as a `BlurryCandidate` for manual review
///
/// Per spec §8.4 — "Do not call them 'bad photos.' Call them 'Review blurry shots.'"
/// We never auto-add to the basket. The user reviews each one individually.
@Observable
@MainActor
final class BlurryShotsScanService {
    enum ScanState: Equatable {
        case idle
        case scanning(progress: Double, label: String)
        case completed
        case cancelled
        case failed(String)
    }

    private(set) var state: ScanState = .idle
    private(set) var candidates: [BlurryCandidate] = []
    private(set) var totalConsidered: Int = 0
    private(set) var protectedSkipped: Int = 0
    private(set) var faceProtectedSkipped: Int = 0
    private(set) var lastCompletedAt: Date?

    private let photoLibrary: PhotoLibraryService
    private let vision = VisionService()
    private let now: Date
    private let recencyThreshold: TimeInterval
    private let blurThreshold: Float

    /// Upper bound on candidates per scan. Blur detection is per-image work
    /// (Laplacian variance on a downscaled grayscale) so the cost is linear
    /// in the candidate count. 2,000 covers the typical user comfortably;
    /// power users with much larger libraries can raise this.
    let scanLimit: Int

    private let thumbnailSize = CGSize(width: 256, height: 256)
    private var currentTask: Task<Void, Never>?

    init(
        photoLibrary: PhotoLibraryService,
        scanLimit: Int = 2_000,
        blurThreshold: Float = BlurDetector.defaultBlurThreshold,
        now: Date = Date(),
        recencyDays: Int = 30
    ) {
        self.photoLibrary = photoLibrary
        self.scanLimit = scanLimit
        self.blurThreshold = blurThreshold
        self.now = now
        self.recencyThreshold = TimeInterval(recencyDays * 24 * 60 * 60)
    }

    // MARK: - Public

    func startScanIfNeeded() {
        if case .scanning = state { return }
        if case .completed = state { return }
        startScan()
    }

    func startScan() {
        currentTask?.cancel()
        candidates = []
        totalConsidered = 0
        protectedSkipped = 0
        faceProtectedSkipped = 0
        state = .scanning(progress: 0, label: "Looking for blurry shots…")

        currentTask = Task { [photoLibrary, vision, scanLimit, thumbnailSize, blurThreshold] in
            await self.runScan(
                photoLibrary: photoLibrary,
                vision: vision,
                scanLimit: scanLimit,
                thumbnailSize: thumbnailSize,
                blurThreshold: blurThreshold
            )
        }
    }

    func cancel() {
        currentTask?.cancel()
        state = .cancelled
    }

    // MARK: - Protection check

    /// True if this candidate should never be flagged as blurry per our conservative defaults.
    /// (Favorited / hidden / recent are protected; rare photos around major dates are too,
    /// but we don't have that signal at the asset level yet — v0.3 work.)
    private func isProtected(_ summary: SimilarPhotoCandidate) -> Bool {
        if summary.isFavorite { return true }
        if summary.isHidden { return true }
        if now.timeIntervalSince(summary.creationDate) < recencyThreshold { return true }
        return false
    }

    // MARK: - Internals

    private func runScan(
        photoLibrary: PhotoLibraryService,
        vision: VisionService,
        scanLimit: Int,
        thumbnailSize: CGSize,
        blurThreshold: Float
    ) async {
        // Stream-read the candidate pool with progress.
        let stream = photoLibrary.fetchPhotoCandidatesStream(maxTotal: scanLimit)
        let plannedTotal = stream.totalCount
        var pool: [SimilarPhotoCandidate] = []
        pool.reserveCapacity(min(plannedTotal, scanLimit))

        for await chunk in stream.chunks {
            if Task.isCancelled { state = .cancelled; return }
            pool.append(contentsOf: chunk)
            let readFraction = Double(pool.count) / Double(max(plannedTotal, 1))
            state = .scanning(
                progress: readFraction * 0.15, // 15% for read phase
                label: "Reading library… \(pool.count) of \(plannedTotal)"
            )
        }
        totalConsidered = pool.count

        if Task.isCancelled { state = .cancelled; return }

        // Filter out protected items first. Saves us thumbnail+detector work
        // on the things we'd never surface anyway.
        let toScan = pool.filter { !isProtected($0) }
        protectedSkipped = pool.count - toScan.count

        guard !toScan.isEmpty else {
            state = .completed
            lastCompletedAt = Date()
            return
        }

        var found: [BlurryCandidate] = []
        let total = toScan.count

        for (idx, item) in toScan.enumerated() {
            if Task.isCancelled { state = .cancelled; return }
            let frac = Double(idx + 1) / Double(max(total, 1))
            state = .scanning(
                progress: 0.15 + frac * 0.85,
                label: "Checking \(idx + 1) of \(total)…"
            )

            guard let thumb = await photoLibrary.requestThumbnail(
                for: item.localIdentifier,
                targetSize: thumbnailSize
            ) else { continue }

            if Task.isCancelled { state = .cancelled; return }

            guard let score = BlurDetector.analyze(thumb) else { continue }
            guard score < blurThreshold else { continue }

            // Face protection — a slightly blurry portrait is still worth
            // keeping. We use Vision's lightweight rectangle detection
            // (no recognition, no identity). If detection fails, we err on
            // the side of NOT flagging — silent zero is a deliberate choice
            // in VisionService.faceCount.
            let faces = await vision.faceCount(in: thumb)
            if faces > 0 {
                faceProtectedSkipped += 1
                continue
            }

            found.append(
                BlurryCandidate(
                    localIdentifier: item.localIdentifier,
                    creationDate: item.creationDate,
                    pixelWidth: item.pixelWidth,
                    pixelHeight: item.pixelHeight,
                    estimatedFileSize: item.estimatedFileSize,
                    isFavorite: item.isFavorite,
                    isHidden: item.isHidden,
                    blurScore: score
                )
            )
        }

        // Sort by blurriest first — most confident candidates appear at the top.
        candidates = found.sorted { $0.blurScore < $1.blurScore }
        state = .completed
        lastCompletedAt = Date()
    }
}
