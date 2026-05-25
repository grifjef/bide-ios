import SwiftUI

/// Async PhotoKit thumbnail with a graceful placeholder.
/// Caches by identifier within the view body (sufficient for our use).
struct ThumbnailView: View {
    let localIdentifier: String
    var targetSize: CGSize = CGSize(width: 220, height: 220)

    @Environment(PhotoLibraryService.self) private var photoLibrary
    @State private var image: UIImage?
    @State private var didLoad = false

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                placeholder
            }
        }
        .clipped()
        .task {
            guard !didLoad else { return }
            didLoad = true
            image = await photoLibrary.requestThumbnail(
                for: localIdentifier,
                targetSize: targetSize
            )
        }
    }

    private var placeholder: some View {
        BideTheme.secondaryBackground.overlay {
            Image(systemName: "photo")
                .foregroundStyle(BideTheme.textTertiary)
        }
    }
}
