import Foundation
import Observation

@Observable
@MainActor
final class LargeVideosViewModel {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    private(set) var loadState: LoadState = .idle
    private(set) var videos: [LargeVideoSummary] = []

    private let photoLibrary: PhotoLibraryService

    init(photoLibrary: PhotoLibraryService) {
        self.photoLibrary = photoLibrary
    }

    func loadIfNeeded() async {
        guard loadState != .loaded && loadState != .loading else { return }
        await reload()
    }

    func reload() async {
        loadState = .loading
        let fetched = await photoLibrary.fetchLargeVideos(limit: 200)
        // Filter out zero-byte rows — usually means we couldn't read the
        // resource for some reason (cloud-only, permissions, etc.).
        let usable = fetched.filter { $0.fileSize > 0 }
        videos = usable
        loadState = .loaded
    }
}
