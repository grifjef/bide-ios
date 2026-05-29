import SwiftUI

/// Screen recordings are usually the single biggest disposable files in a
/// camera roll — Apple's "Hold Power+Volume to record" workflow produces a
/// 200 MB file in 20 seconds. We give them their own module to surface that
/// reclaim potential without forcing the user to dig through Large Videos.
struct ScreenRecordingsView: View {
    @Environment(PhotoLibraryService.self) private var photoLibrary
    @Environment(ReviewBasket.self) private var basket
    @State private var viewModel: ScreenRecordingsViewModel?
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
        .navigationTitle("Screen recordings")
        .navigationBarTitleDisplayMode(.large)
        .helpButton(isPresented: $showHelp)
        .task {
            if viewModel == nil {
                viewModel = ScreenRecordingsViewModel(photoLibrary: photoLibrary)
            }
            await viewModel?.loadIfNeeded()
        }
    }

    @ViewBuilder
    private func content(for viewModel: ScreenRecordingsViewModel) -> some View {
        switch viewModel.loadState {
        case .idle, .loading:
            loadingState
        case .failed(let message):
            failureState(message)
        case .loaded:
            if viewModel.recordings.isEmpty {
                emptyState
            } else {
                recordingList(viewModel.recordings)
            }
        }
    }

    private var loadingState: some View {
        VStack(spacing: BideTheme.m) {
            ProgressView().controlSize(.large)
            Text("Looking through your screen recordings…")
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
            Text("Couldn't load screen recordings")
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
            Image(systemName: "record.circle.slash")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(BideTheme.textTertiary)
            Text("No screen recordings found")
                .font(BideTheme.cardTitle())
            Text("You don't have any screen recordings on this device. They'd show up here when you take one — typically Hold Power+Volume Up.")
                .font(BideTheme.body())
                .foregroundStyle(BideTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, BideTheme.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func recordingList(_ recordings: [LargeVideoSummary]) -> some View {
        ScrollView {
            VStack(spacing: BideTheme.s) {
                summaryHeader(recordings)
                LazyVStack(spacing: BideTheme.s) {
                    ForEach(recordings) { recording in
                        ScreenRecordingRow(
                            recording: recording,
                            isSelected: basket.contains(localIdentifier: recording.localIdentifier)
                        ) {
                            toggle(recording)
                        }
                    }
                }
            }
            .padding(BideTheme.m)
        }
    }

    private func summaryHeader(_ recordings: [LargeVideoSummary]) -> some View {
        let totalBytes = recordings.reduce(Int64(0)) { $0 + $1.fileSize }
        let totalFormatted = ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
        return VStack(alignment: .leading, spacing: BideTheme.s) {
            Text(totalFormatted)
                .font(BideTheme.display())
                .foregroundStyle(BideTheme.primary)
            Text("\(recordings.count) screen recording\(recordings.count == 1 ? "" : "s")")
                .font(BideTheme.body())
                .foregroundStyle(BideTheme.textSecondary)
            Text("Screen recordings are usually one-time-use. Move what you no longer need to Recently Deleted — recover anything within 30 days.")
                .font(BideTheme.caption())
                .foregroundStyle(BideTheme.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .bideCard()
    }

    private func toggle(_ recording: LargeVideoSummary) {
        guard !recording.isProtected else { return }
        basket.toggle(
            ReviewBasket.Item(
                localIdentifier: recording.localIdentifier,
                source: .screenRecordings,
                estimatedBytes: recording.fileSize,
                displayDate: recording.formattedDate
            )
        )
    }
}

// MARK: - Row

private struct ScreenRecordingRow: View {
    let recording: LargeVideoSummary
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .center, spacing: BideTheme.m) {
                ZStack {
                    ThumbnailView(localIdentifier: recording.localIdentifier)
                        .frame(width: 88, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: BideTheme.cornerSmall, style: .continuous))
                    Image(systemName: "record.circle")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .padding(4)
                        .background(.black.opacity(0.5), in: Circle())
                }

                VStack(alignment: .leading, spacing: BideTheme.xs) {
                    HStack(spacing: BideTheme.s) {
                        Text(recording.formattedSize)
                            .font(BideTheme.numeric())
                            .foregroundStyle(BideTheme.textPrimary)

                        Text("·")
                            .foregroundStyle(BideTheme.textTertiary)

                        Text(recording.formattedDuration)
                            .font(BideTheme.caption())
                            .foregroundStyle(BideTheme.textSecondary)
                    }
                    Text(recording.formattedDate)
                        .font(BideTheme.caption())
                        .foregroundStyle(BideTheme.textSecondary)
                    if recording.isProtected {
                        Label(recording.isFavorite ? "Favorite — protected" : "Hidden — protected", systemImage: "heart.fill")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(BideTheme.warning)
                    } else if recording.isRecentCapture() {
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
        .disabled(recording.isProtected)
        .opacity(recording.isProtected ? 0.55 : 1.0)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(isSelected ? "Selected for review basket" : "Not selected")
        .accessibilityHint(recording.isProtected ? "" : "Double-tap to add to Review Basket")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var accessibilityLabel: String {
        let base = "Screen recording, \(recording.formattedSize), \(recording.formattedDuration), from \(recording.formattedDate)"
        if recording.isProtected {
            let reason = recording.isFavorite ? "favorite" : "hidden"
            return "\(base). Protected because it's a \(reason); cannot select."
        }
        return base
    }
}
