import SwiftUI

/// Live Photos carry a video sidecar alongside the still — typically a 1.5s
/// clip that adds ~40% to the asset's storage. This view offers two paths:
///
/// 1. **Convert to still** — keep the moment, drop the video sidecar.
///    Writes the original still resource as a new asset and moves the Live
///    Photo to Recently Deleted. The big-feel feature of the module.
/// 2. **Add to Review Basket** — tap-to-select for full removal in the
///    batch flow shared with the other modules.
struct LivePhotosView: View {
    @Environment(PhotoLibraryService.self) private var photoLibrary
    @Environment(ReviewBasket.self) private var basket
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: LivePhotosViewModel?
    @State private var pendingConversion: LivePhotoSummary?

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
                viewModel = LivePhotosViewModel(
                    photoLibrary: photoLibrary,
                    historyStore: ReclaimHistoryStore(modelContext: modelContext)
                )
            }
            await viewModel?.loadIfNeeded()
        }
        .alert("Convert to still photo?", isPresented: pendingConversionBinding) {
            Button("Cancel", role: .cancel) {
                pendingConversion = nil
            }
            Button("Convert") {
                if let live = pendingConversion {
                    Task { await viewModel?.convertToStill(live) }
                }
                pendingConversion = nil
            }
        } message: {
            if let live = pendingConversion {
                Text("Bide will save the still photo from this Live Photo, then move the Live Photo to Recently Deleted. You'll reclaim about \(live.formattedPairedVideoSize) — the size of the video sidecar.\n\nYou can recover the Live Photo from Recently Deleted within 30 days.")
            } else {
                Text("")
            }
        }
    }

    private var pendingConversionBinding: Binding<Bool> {
        Binding(
            get: { pendingConversion != nil },
            set: { if !$0 { pendingConversion = nil } }
        )
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
                livePhotoList(viewModel)
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

    private func livePhotoList(_ viewModel: LivePhotosViewModel) -> some View {
        ScrollView {
            VStack(spacing: BideTheme.s) {
                summaryHeader(viewModel)
                conversionToast(viewModel)
                LazyVStack(spacing: BideTheme.s) {
                    ForEach(viewModel.livePhotos) { live in
                        LivePhotoRow(
                            live: live,
                            isSelected: basket.contains(localIdentifier: live.localIdentifier),
                            isConverting: isConverting(live, viewModel: viewModel),
                            onToggleBasket: { toggle(live) },
                            onConvertToStill: { pendingConversion = live }
                        )
                    }
                }
            }
            .padding(BideTheme.m)
        }
    }

    private func isConverting(_ live: LivePhotoSummary, viewModel: LivePhotosViewModel) -> Bool {
        if case .inProgress(let identifier) = viewModel.conversionState,
           identifier == live.localIdentifier {
            return true
        }
        return false
    }

    @ViewBuilder
    private func conversionToast(_ viewModel: LivePhotosViewModel) -> some View {
        switch viewModel.conversionState {
        case .idle, .inProgress:
            EmptyView()
        case .succeeded(_, let bytes):
            let bytesFormatted = ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
            HStack(alignment: .top, spacing: BideTheme.s) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(BideTheme.primary)
                    .imageScale(.large)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Saved still · Live Photo moved to Recently Deleted")
                        .font(BideTheme.cardTitle())
                    Text("Reclaimed \(bytesFormatted). You have 30 days to recover the Live Photo if you change your mind.")
                        .font(BideTheme.caption())
                        .foregroundStyle(BideTheme.textSecondary)
                }
                Spacer(minLength: 0)
                Button {
                    viewModel.clearConversionState()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(BideTheme.textTertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss")
            }
            .padding(BideTheme.s)
            .background(BideTheme.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: BideTheme.cornerSmall, style: .continuous))
            .accessibilityElement(children: .combine)

        case .failed(_, let message):
            HStack(alignment: .top, spacing: BideTheme.s) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(BideTheme.warning)
                    .imageScale(.large)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Couldn't convert")
                        .font(BideTheme.cardTitle())
                    Text(message)
                        .font(BideTheme.caption())
                        .foregroundStyle(BideTheme.textSecondary)
                }
                Spacer(minLength: 0)
                Button {
                    viewModel.clearConversionState()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(BideTheme.textTertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss")
            }
            .padding(BideTheme.s)
            .background(BideTheme.warning.opacity(0.08), in: RoundedRectangle(cornerRadius: BideTheme.cornerSmall, style: .continuous))
            .accessibilityElement(children: .combine)
        }
    }

    private func summaryHeader(_ viewModel: LivePhotosViewModel) -> some View {
        let livePhotos = viewModel.livePhotos
        let totalBytes = livePhotos.reduce(Int64(0)) { $0 + $1.fileSize }
        let totalFormatted = ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
        let reclaimedFormatted = ByteCountFormatter.string(
            fromByteCount: viewModel.sessionBytesReclaimed,
            countStyle: .file
        )
        return VStack(alignment: .leading, spacing: BideTheme.s) {
            Text(totalFormatted)
                .font(BideTheme.display())
                .foregroundStyle(BideTheme.primary)
            Text("\(livePhotos.count) Live Photo\(livePhotos.count == 1 ? "" : "s")")
                .font(BideTheme.body())
                .foregroundStyle(BideTheme.textSecondary)
            if viewModel.sessionBytesReclaimed > 0 {
                Text("Reclaimed \(reclaimedFormatted) this session by converting to still.")
                    .font(BideTheme.caption())
                    .foregroundStyle(BideTheme.primary)
            }
            Text("Each Live Photo carries a short video alongside the still. You can convert one to a still to keep the photo without the video sidecar, or remove it entirely.")
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
                source: .livePhotos,
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
    let isConverting: Bool
    let onToggleBasket: () -> Void
    let onConvertToStill: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: BideTheme.s) {
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
                    Text("Video sidecar: \(live.formattedPairedVideoSize)")
                        .font(.caption2)
                        .foregroundStyle(BideTheme.textTertiary)
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

                if isConverting {
                    ProgressView()
                        .controlSize(.regular)
                        .accessibilityLabel("Converting")
                } else {
                    Button(action: onToggleBasket) {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.title2)
                            .foregroundStyle(isSelected ? BideTheme.accent : BideTheme.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .disabled(live.isProtected)
                    .accessibilityLabel(isSelected ? "Remove from Review Basket" : "Add to Review Basket")
                }
            }

            if !live.isProtected {
                Button(action: onConvertToStill) {
                    Label("Convert to still photo", systemImage: "photo")
                        .font(BideTheme.caption().weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(BideTheme.primary)
                .disabled(isConverting)
                .accessibilityHint("Saves the still photo and moves the Live Photo to Recently Deleted")
            }
        }
        .bideCard(padding: BideTheme.s)
        .opacity(live.isProtected ? 0.55 : 1.0)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(isSelected ? "Selected for review basket" : "Not selected")
    }

    private var accessibilityLabel: String {
        let base = "Live Photo, \(live.formattedSize), from \(live.formattedDate). Video sidecar \(live.formattedPairedVideoSize)."
        if live.isProtected {
            let reason = live.isFavorite ? "favorite" : "hidden"
            return "\(base) Protected because it's a \(reason); cannot select."
        }
        return base
    }
}
