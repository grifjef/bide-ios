import SwiftUI

struct LargeVideosView: View {
    @Environment(PhotoLibraryService.self) private var photoLibrary
    @Environment(ReviewBasket.self) private var basket
    @State private var viewModel: LargeVideosViewModel?
    @State private var showHelp: Bool = false

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
        .navigationTitle("Large videos")
        .navigationBarTitleDisplayMode(.large)
        .helpButton(isPresented: $showHelp)
        .task {
            if viewModel == nil {
                viewModel = LargeVideosViewModel(photoLibrary: photoLibrary)
            }
            await viewModel?.loadIfNeeded()
        }
    }

    @ViewBuilder
    private func content(for viewModel: LargeVideosViewModel) -> some View {
        switch viewModel.loadState {
        case .idle, .loading:
            loadingState
        case .failed(let message):
            failureState(message)
        case .loaded:
            if viewModel.videos.isEmpty {
                emptyState
            } else {
                videoList(viewModel.videos)
            }
        }
    }

    private var loadingState: some View {
        VStack(spacing: BideTheme.m) {
            ProgressView()
                .controlSize(.large)
            Text("Looking through your videos…")
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
            Text("Couldn't load videos")
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
            Image(systemName: "video.slash")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(BideTheme.textTertiary)
            Text("No videos found")
                .font(BideTheme.cardTitle())
            Text("Your library has no videos right now, or they're stored in iCloud and not downloaded.")
                .font(BideTheme.body())
                .foregroundStyle(BideTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, BideTheme.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func videoList(_ videos: [LargeVideoSummary]) -> some View {
        ScrollView {
            VStack(spacing: BideTheme.s) {
                summaryHeader(videos)

                LazyVStack(spacing: BideTheme.s) {
                    ForEach(videos) { video in
                        VideoRow(
                            video: video,
                            isSelected: basket.contains(localIdentifier: video.localIdentifier)
                        ) {
                            toggle(video)
                        }
                    }
                }
            }
            .padding(BideTheme.m)
        }
    }

    private func summaryHeader(_ videos: [LargeVideoSummary]) -> some View {
        let totalBytes = videos.reduce(Int64(0)) { $0 + $1.fileSize }
        let totalFormatted = ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(videos.count) videos")
                    .font(BideTheme.cardTitle())
                Text("\(totalFormatted) total")
                    .font(BideTheme.caption())
                    .foregroundStyle(BideTheme.textSecondary)
            }
            Spacer()
            Text("Largest first")
                .font(BideTheme.caption())
                .foregroundStyle(BideTheme.textTertiary)
        }
        .padding(.horizontal, BideTheme.s)
        .padding(.vertical, BideTheme.s)
    }

    private func toggle(_ video: LargeVideoSummary) {
        guard !video.isProtected else { return }
        basket.toggle(
            ReviewBasket.Item(
                localIdentifier: video.localIdentifier,
                source: .largeVideos,
                estimatedBytes: video.fileSize,
                displayDate: video.formattedDate
            )
        )
    }
}

// MARK: - Row

private struct VideoRow: View {
    let video: LargeVideoSummary
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .center, spacing: BideTheme.m) {
                ThumbnailView(localIdentifier: video.localIdentifier)
                    .frame(width: 88, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: BideTheme.cornerSmall, style: .continuous))

                VStack(alignment: .leading, spacing: BideTheme.xs) {
                    HStack(spacing: BideTheme.s) {
                        Text(video.formattedSize)
                            .font(BideTheme.numeric())
                            .foregroundStyle(BideTheme.textPrimary)

                        Text("·")
                            .foregroundStyle(BideTheme.textTertiary)

                        Text(video.formattedDuration)
                            .font(BideTheme.caption())
                            .foregroundStyle(BideTheme.textSecondary)
                    }
                    Text(video.formattedDate)
                        .font(BideTheme.caption())
                        .foregroundStyle(BideTheme.textSecondary)
                    if video.isProtected {
                        Label(video.isFavorite ? "Favorite — protected" : "Hidden — protected", systemImage: "heart.fill")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(BideTheme.warning)
                    } else if video.isRecentCapture() {
                        RecentCaptureBadge()
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
        .disabled(video.isProtected)
        .opacity(video.isProtected ? 0.55 : 1.0)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
        .accessibilityHint(accessibilityHint ?? "")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var accessibilityLabel: String {
        let base = "Video, \(video.formattedSize), \(video.formattedDuration), from \(video.formattedDate)"
        if video.isProtected {
            let reason = video.isFavorite ? "favorite" : "hidden"
            return "\(base). Protected because it's a \(reason); cannot select."
        }
        return base
    }

    private var accessibilityValue: String {
        isSelected ? "Selected for review basket" : "Not selected"
    }

    private var accessibilityHint: String? {
        video.isProtected ? nil : "Double-tap to add to Review Basket"
    }
}
