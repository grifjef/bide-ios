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

    private(set) var loadState: LoadState = .idle
    private(set) var livePhotos: [LivePhotoSummary] = []

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
        let fetched = await photoLibrary.fetchLivePhotos(limit: 200)
        livePhotos = fetched.filter { $0.fileSize > 0 }
        loadState = .loaded
    }
}
