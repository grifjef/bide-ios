import SwiftUI

/// Live Photos carry a video sidecar alongside the still — typically a 1.5s
/// clip that adds ~40% to the asset's storage. Surface them as a separate
/// review list so users can decide which ones to keep as Live Photos and
/// which to remove entirely.
///
/// (A future "Convert to still" action — `PHAssetCreationRequest` for the
/// still + delete the Live Photo — is scoped for v0.6; the basic
/// list-and-review flow is the high-leverage first step.)
struct LivePhotosView: View {
    @Environment(PhotoLibraryService.self) private var photoLibrary
    @Environment(ReviewBasket.self) private var basket
    @State private var viewModel: LivePhotosViewModel?

    var body: some View {
        Group {
            if let viewModel {
                content(for: viewModel)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(BideTheme.background)
        .navigationTitle("Live Photos")
        .navigationBarTitleDisplayMode(.large)
        .task {
            if viewModel == nil {
                viewModel = LivePhotosViewModel(photoLibrary: photoLibrary)
            }
            await viewModel?.loadIfNeeded()
        }
    }

    @ViewBuilder
    private func content(for viewModel: LivePhotosViewModel) -> some View {
        switch viewModel.loadState {
        case .idle, .loading:
            loadingState
        case .failed(let message):
            failureState(message)
        case .loaded:
            if viewModel.livePhotos.isEmpty {
                emptyState
            } else {
                livePhotoList(viewModel.livePhotos)
            }
        }
    }

    private var loadingState: some View {
        VStack(spacing: BideTheme.m) {
            ProgressView().controlSize(.large)
            Text("Looking through your Live Photos…")
                .font(BideTheme.body())
                .foregroundStyle(BideTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func failureState(_ message: String) -> some View {
        VStack(spacing: BideTheme.m) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(BideTheme.warning)
            Text("Couldn't load Live Photos")
                .font(BideTheme.cardTitle())
            Text(message)
                .font(BideTheme.body())
                .foregroundStyle(BideTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(BideTheme.l)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: BideTheme.m) {
            Image(systemName: "livephoto.slash")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(BideTheme.textTertiary)
            Text("No Live Photos found")
                .font(BideTheme.cardTitle())
            Text("You don't have any Live Photos on this device. They'd show up here whenever you take one with the Live Photo capture enabled.")
                .font(BideTheme.body())
                .foregroundStyle(BideTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, BideTheme.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func livePhotoList(_ livePhotos: [LivePhotoSummary]) -> some View {
        ScrollView {
            VStack(spacing: BideTheme.s) {
                summaryHeader(livePhotos)
                LazyVStack(spacing: BideTheme.s) {
                    ForEach(livePhotos) { live in
                        LivePhotoRow(
                            live: live,
                            isSelected: basket.contains(localIdentifier: live.localIdentifier)
                        ) {
                            toggle(live)
                        }
                    }
                }
            }
            .padding(BideTheme.m)
        }
    }

    private func summaryHeader(_ livePhotos: [LivePhotoSummary]) -> some View {
        let totalBytes = livePhotos.reduce(Int64(0)) { $0 + $1.fileSize }
        let totalFormatted = ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
        return VStack(alignment: .leading, spacing: BideTheme.s) {
            Text(totalFormatted)
                .font(BideTheme.display())
                .foregroundStyle(BideTheme.primary)
            Text("\(livePhotos.count) Live Photo\(livePhotos.count == 1 ? "" : "s")")
                .font(BideTheme.body())
                .foregroundStyle(BideTheme.textSecondary)
            Text("Each Live Photo carries a short video alongside the still. Reviewing the largest ones first is a calm way to free space without losing the photos you keep.")
                .font(BideTheme.caption())
                .foregroundStyle(BideTheme.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .bideCard()
    }

    private func toggle(_ live: LivePhotoSummary) {
        guard !live.isProtected else { return }
        basket.toggle(
            ReviewBasket.Item(
                localIdentifier: live.localIdentifier,
                source: .largeVideos,
                estimatedBytes: live.fileSize,
                displayDate: live.formattedDate
            )
        )
    }
}

// MARK: - Row

private struct LivePhotoRow: View {
    let live: LivePhotoSummary
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .center, spacing: BideTheme.m) {
                ZStack {
                    ThumbnailView(localIdentifier: live.localIdentifier)
                        .frame(width: 88, height: 88)
                        .clipShape(RoundedRectangle(cornerRadius: BideTheme.cornerSmall, style: .continuous))
                    Image(systemName: "livephoto")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .padding(4)
                        .background(.black.opacity(0.5), in: Circle())
                }

                VStack(alignment: .leading, spacing: BideTheme.xs) {
                    Text(live.formattedSize)
                        .font(BideTheme.numeric())
                        .foregroundStyle(BideTheme.textPrimary)
                    Text(live.formattedDate)
                        .font(BideTheme.caption())
                        .foregroundStyle(BideTheme.textSecondary)
                    if live.isProtected {
                        Label(
                            live.isFavorite ? "Favorite — protected" : "Hidden — protected",
                            systemImage: "heart.fill"
                        )
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(BideTheme.warning)
                    }
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? BideTheme.accent : BideTheme.textTertiary)
            }
            .bideCard(padding: BideTheme.s)
        }
        .buttonStyle(.plain)
        .disabled(live.isProtected)
        .opacity(live.isProtected ? 0.55 : 1.0)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(isSelected ? "Selected for review basket" : "Not selected")
        .accessibilityHint(live.isProtected ? "" : "Double-tap to add to Review Basket")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var accessibilityLabel: String {
        let base = "Live Photo, \(live.formattedSize), from \(live.formattedDate)"
        if live.isProtected {
            let reason = live.isFavorite ? "favorite" : "hidden"
            return "\(base). Protected because it's a \(reason); cannot select."
        }
        return base
    }
}
