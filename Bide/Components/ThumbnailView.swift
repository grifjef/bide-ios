import SwiftUI

/// Async PhotoKit thumbnail with three honest states:
///   1. Loading — show a subtle placeholder while the request is in-flight
///   2. Loaded — render the image
///   3. Cloud-only — show a tap-to-download affordance with a cloud icon
///
/// The cloud-only state is the trust-critical one. We *never* silently kick
/// off an iCloud download (it'd burn the user's cellular data and battery
/// and violate the "no hidden cloud" promise). The user has to tap to
/// authorize the network fetch for that specific asset.
struct ThumbnailView: View {
    let localIdentifier: String
    var targetSize: CGSize = CGSize(width: 220, height: 220)

    @Environment(PhotoLibraryService.self) private var photoLibrary

    @State private var image: UIImage?
    @State private var state: LoadState = .loading

    enum LoadState: Equatable {
        case loading
        case loaded
        case cloudOnly
        case downloading
        case failed
    }

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                stateOverlay
            }
        }
        .clipped()
        .task {
            guard state == .loading else { return }
            let result = await photoLibrary.requestThumbnailWithMetadata(
                for: localIdentifier,
                targetSize: targetSize
            )
            if let img = result.image {
                image = img
                state = .loaded
            } else if result.isCloudOnly {
                state = .cloudOnly
            } else {
                state = .failed
            }
        }
    }

    @ViewBuilder
    private var stateOverlay: some View {
        switch state {
        case .loading:
            BideTheme.secondaryBackground.overlay {
                ProgressView()
                    .controlSize(.small)
                    .tint(BideTheme.textTertiary)
            }
        case .cloudOnly:
            Button {
                Task { await downloadFromCloud() }
            } label: {
                BideTheme.secondaryBackground.overlay {
                    VStack(spacing: 2) {
                        Image(systemName: "icloud.and.arrow.down")
                            .font(.title3)
                        Text("Tap to load")
                            .font(.caption2.weight(.medium))
                    }
                    .foregroundStyle(BideTheme.accent)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Photo in iCloud, not downloaded yet")
            .accessibilityHint("Double-tap to download from iCloud")
        case .downloading:
            BideTheme.secondaryBackground.overlay {
                ProgressView()
                    .controlSize(.small)
                    .tint(BideTheme.accent)
            }
            .accessibilityLabel("Downloading from iCloud")
        case .failed:
            BideTheme.secondaryBackground.overlay {
                Image(systemName: "photo")
                    .foregroundStyle(BideTheme.textTertiary)
            }
        case .loaded:
            // `image` is non-nil so this branch is unreachable, but keep
            // the placeholder for completeness.
            BideTheme.secondaryBackground
        }
    }

    private func downloadFromCloud() async {
        state = .downloading
        let downloaded = await photoLibrary.requestThumbnailAllowingDownload(
            for: localIdentifier,
            targetSize: targetSize
        )
        if let downloaded {
            image = downloaded
            state = .loaded
        } else {
            state = .failed
        }
    }
}
