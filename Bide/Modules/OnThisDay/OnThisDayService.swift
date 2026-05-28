import Foundation
import Observation

/// Fetches photo candidates from PhotoKit and groups them by past years on
/// the same calendar day as `now`. Wraps `OnThisDayMatcher` with the
/// async PhotoKit fetch.
@Observable
@MainActor
final class OnThisDayService {

    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    private(set) var state: LoadState = .idle
    private(set) var groups: [OnThisDayMatcher.YearGroup] = []

    private let photoLibrary: PhotoLibraryService
    private let now: Date

    init(photoLibrary: PhotoLibraryService, now: Date = Date()) {
        self.photoLibrary = photoLibrary
        self.now = now
    }

    func loadIfNeeded() async {
        guard state != .loaded && state != .loading else { return }
        await reload()
    }

    func reload() async {
        state = .loading
        // Cap at 5,000 candidates — same as Similar Photos. Far enough back
        // to surface multi-year memories without scanning the whole library.
        let candidates = await photoLibrary.fetchPhotoCandidates(limit: 5_000)
        groups = OnThisDayMatcher.groupsForToday(candidates: candidates, targetDate: now)
        state = .loaded
    }

    var totalCount: Int {
        OnThisDayMatcher.totalCount(groups)
    }
}
