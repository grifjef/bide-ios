import Foundation
import Observation

@Observable
@MainActor
final class LivePhotosViewModel {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    /// One-shot state for the most recent conversion attempt. Drives the
    /// inline confirmation/error UI on the view.
    enum ConversionState: Equatable {
        case idle
        case inProgress(localIdentifier: String)
        case succeeded(localIdentifier: String, bytesReclaimed: Int64)
        case failed(localIdentifier: String, message: String)
    }

    private(set) var loadState: LoadState = .idle
    private(set) var livePhotos: [LivePhotoSummary] = []
    private(set) var conversionState: ConversionState = .idle

    /// Cumulative bytes saved across all successful conversions this session.
    /// Lets the summary header reflect real reclaim without re-fetching.
    private(set) var sessionBytesReclaimed: Int64 = 0

    private let photoLibrary: PhotoLibraryService
    private let historyStore: ReclaimHistoryStore?

    init(photoLibrary: PhotoLibraryService, historyStore: ReclaimHistoryStore? = nil) {
        self.photoLibrary = photoLibrary
        self.historyStore = historyStore
    }

    func loadIfNeeded() async {
        guard loadState != .loaded && loadState != .loading else { return }
        await reload()
    }

    func reload() async {
        loadState = .loading
        let fetched = await photoLibrary.fetchLivePhotos(limit: 200)
        livePhotos = fetched.filter { $0.fileSize > 0 }
        loadState = .loaded
    }

    func clearConversionState() {
        conversionState = .idle
    }

    /// Convert a single Live Photo to a still. Drops the row out of the
    /// in-memory list on success so the UI feels immediate. On failure the
    /// row remains so the user can try again.
    func convertToStill(_ live: LivePhotoSummary) async {
        guard !live.isProtected else { return }
        conversionState = .inProgress(localIdentifier: live.localIdentifier)
        do {
            let result = try await photoLibrary.convertLivePhotoToStill(
                localIdentifier: live.localIdentifier
            )
            // Drop the converted row from the in-memory list so the user sees
            // immediate feedback. The actual library change will also be
            // reported via PHPhotoLibraryChangeObserver on next reload.
            livePhotos.removeAll { $0.localIdentifier == live.localIdentifier }
            sessionBytesReclaimed += result.bytesReclaimedEstimate
            // Best-effort: log this as a 1-item lifetime reclaim so it shows
            // up in Settings → Lifetime totals. Conversion failures upstream
            // never reach here, so writing is safe.
            _ = try? historyStore?.record(
                itemCount: 1,
                bytesReclaimed: result.bytesReclaimedEstimate
            )
            conversionState = .succeeded(
                localIdentifier: live.localIdentifier,
                bytesReclaimed: result.bytesReclaimedEstimate
            )
        } catch let error as PhotoLibraryService.LivePhotoConversionError {
            conversionState = .failed(
                localIdentifier: live.localIdentifier,
                message: error.errorDescription ?? "Conversion failed."
            )
        } catch {
            conversionState = .failed(
                localIdentifier: live.localIdentifier,
                message: error.localizedDescription
            )
        }
    }
}
