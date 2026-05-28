import Foundation
import Observation

/// Fast (no Vision, no thumbnails) duplicate scan. Reuses
/// `PhotoLibraryService.fetchPhotoCandidates` and runs `ExactDuplicateDetector`
/// on the result. Runs in well under a second on a 5k library — small enough
/// that we don't bother with a scanning progress UI for the dashboard call.
@Observable
@MainActor
final class ExactDuplicatesScanService {

    enum ScanState: Equatable {
        case idle
        case scanning
        case completed
        case cancelled
        case failed(String)
    }

    private(set) var state: ScanState = .idle
    private(set) var groups: [ExactDuplicateGroup] = []
    private(set) var totalAssetsConsidered: Int = 0
    private(set) var lastCompletedAt: Date?

    private let photoLibrary: PhotoLibraryService

    /// We can scan much deeper than the Similar Photos engine because we don't
    /// touch thumbnails or Vision — purely metadata work.
    let scanLimit: Int

    private var currentTask: Task<Void, Never>?

    init(photoLibrary: PhotoLibraryService, scanLimit: Int = 5_000) {
        self.photoLibrary = photoLibrary
        self.scanLimit = scanLimit
    }

    func startScanIfNeeded() {
        if case .scanning = state { return }
        if case .completed = state { return }
        startScan()
    }

    func startScan() {
        currentTask?.cancel()
        groups = []
        totalAssetsConsidered = 0
        state = .scanning

        currentTask = Task { [photoLibrary, scanLimit] in
            await self.runScan(photoLibrary: photoLibrary, scanLimit: scanLimit)
        }
    }

    func cancel() {
        currentTask?.cancel()
        state = .cancelled
    }

    var summary: (groupCount: Int, duplicateCount: Int, reclaimableBytes: Int64) {
        ExactDuplicateDetector.summary(groups)
    }

    var formattedReclaim: String {
        ByteCountFormatter.string(fromByteCount: summary.reclaimableBytes, countStyle: .file)
    }

    private func runScan(
        photoLibrary: PhotoLibraryService,
        scanLimit: Int
    ) async {
        let candidates = await photoLibrary.fetchPhotoCandidates(limit: scanLimit)
        totalAssetsConsidered = candidates.count

        if Task.isCancelled { state = .cancelled; return }

        let detected = ExactDuplicateDetector.detect(candidates)
        groups = detected
        state = .completed
        lastCompletedAt = Date()
    }
}
