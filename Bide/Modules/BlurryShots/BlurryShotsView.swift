import SwiftUI

struct BlurryShotsView: View {
    @Environment(PhotoLibraryService.self) private var photoLibrary
    @Environment(ReviewBasket.self) private var basket
    @State private var scan: BlurryShotsScanService?

    var body: some View {
        Group {
            if let scan {
                content(for: scan)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(BideTheme.background)
        .navigationTitle("Blurry shots")
        .navigationBarTitleDisplayMode(.large)
        .task {
            if scan == nil {
                scan = BlurryShotsScanService(photoLibrary: photoLibrary)
            }
            scan?.startScanIfNeeded()
        }
    }

    @ViewBuilder
    private func content(for scan: BlurryShotsScanService) -> some View {
        switch scan.state {
        case .idle:
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        case .scanning(let progress, let label):
            scanningState(progress: progress, label: label, scan: scan)
        case .cancelled:
            cancelledState(scan: scan)
        case .failed(let message):
            failedState(message: message, scan: scan)
        case .completed:
            if scan.candidates.isEmpty {
                emptyState(scan: scan)
            } else {
                candidateList(scan)
            }
        }
    }

    // MARK: - States

    private func scanningState(progress: Double, label: String, scan: BlurryShotsScanService) -> some View {
        VStack(spacing: BideTheme.m) {
            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .tint(BideTheme.accent)
                .padding(.horizontal, BideTheme.xl)
            Text(label)
                .font(BideTheme.body())
                .foregroundStyle(BideTheme.textSecondary)
            Button("Cancel scan") { scan.cancel() }
                .font(BideTheme.caption())
                .foregroundStyle(BideTheme.textTertiary)
                .padding(.top, BideTheme.m)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(BideTheme.l)
    }

    private func cancelledState(scan: BlurryShotsScanService) -> some View {
        VStack(spacing: BideTheme.m) {
            Image(systemName: "pause.circle")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(BideTheme.textTertiary)
            Text("Scan cancelled").font(BideTheme.cardTitle())
            Button("Start again") { scan.startScan() }
                .buttonStyle(.borderedProminent).tint(BideTheme.accent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func failedState(message: String, scan: BlurryShotsScanService) -> some View {
        VStack(spacing: BideTheme.m) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle).foregroundStyle(BideTheme.warning)
            Text("Couldn't finish the scan").font(BideTheme.cardTitle())
            Text(message)
                .font(BideTheme.body()).foregroundStyle(BideTheme.textSecondary)
                .multilineTextAlignment(.center).padding(.horizontal, BideTheme.xl)
            Button("Try again") { scan.startScan() }
                .buttonStyle(.borderedProminent).tint(BideTheme.accent)
        }
        .padding(BideTheme.l)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func emptyState(scan: BlurryShotsScanService) -> some View {
        VStack(spacing: BideTheme.m) {
            Image(systemName: "sparkles")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(BideTheme.primary)
            Text("No blurry shots found")
                .font(BideTheme.cardTitle())
            Text("Bide checked \(scan.totalConsidered) photo\(scan.totalConsidered == 1 ? "" : "s") and didn't surface any blurry candidates. Conservative thresholds keep us from over-flagging — borderline shots stay in your library.")
                .font(BideTheme.body())
                .foregroundStyle(BideTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, BideTheme.xl)
            Button("Scan again") { scan.startScan() }
                .buttonStyle(.bordered).tint(BideTheme.accent)
                .padding(.top, BideTheme.m)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Candidate list

    private func candidateList(_ scan: BlurryShotsScanService) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BideTheme.m) {
                summaryHeader(scan)
                helpText
                LazyVStack(spacing: BideTheme.s) {
                    ForEach(scan.candidates) { candidate in
                        BlurryRow(
                            candidate: candidate,
                            isSelected: basket.contains(localIdentifier: candidate.id)
                        ) {
                            toggle(candidate)
                        }
                    }
                }
                Spacer(minLength: BideTheme.xxl)
            }
            .padding(BideTheme.m)
        }
    }

    private func summaryHeader(_ scan: BlurryShotsScanService) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(scan.candidates.count) candidate\(scan.candidates.count == 1 ? "" : "s")")
                    .font(BideTheme.cardTitle())
                Text("Scanned \(scan.totalConsidered) photo\(scan.totalConsidered == 1 ? "" : "s") · \(scan.protectedSkipped) protected and skipped")
                    .font(BideTheme.caption())
                    .foregroundStyle(BideTheme.textSecondary)
            }
            Spacer()
            Button("Scan again") { scan.startScan() }
                .font(BideTheme.caption().weight(.semibold))
                .buttonStyle(.bordered).tint(BideTheme.accent).controlSize(.small)
        }
    }

    private var helpText: some View {
        HStack(alignment: .top, spacing: BideTheme.s) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(BideTheme.primary)
                .imageScale(.small)
                .padding(.top, 2)
            Text("These are *candidates*, not bad photos. Review each one — Bide is intentionally conservative, but a blurry-looking shot can still be the only photo of a moment.")
                .font(BideTheme.caption())
                .foregroundStyle(BideTheme.textSecondary)
        }
    }

    private func toggle(_ candidate: BlurryCandidate) {
        let item = ReviewBasket.Item(
            localIdentifier: candidate.localIdentifier,
            source: .blurry,
            estimatedBytes: candidate.estimatedFileSize,
            displayDate: candidate.formattedDate
        )
        basket.toggle(item)
    }
}

// MARK: - BlurryRow

private struct BlurryRow: View {
    let candidate: BlurryCandidate
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .center, spacing: BideTheme.m) {
                ThumbnailView(localIdentifier: candidate.localIdentifier)
                    .frame(width: 88, height: 88)
                    .clipShape(RoundedRectangle(cornerRadius: BideTheme.cornerSmall, style: .continuous))

                VStack(alignment: .leading, spacing: BideTheme.xs) {
                    Text(candidate.confidenceLabel)
                        .font(BideTheme.cardTitle())
                        .foregroundStyle(BideTheme.textPrimary)
                    Text(candidate.formattedDate)
                        .font(BideTheme.caption())
                        .foregroundStyle(BideTheme.textSecondary)
                    HStack(spacing: BideTheme.xs) {
                        Text(candidate.formattedSize)
                        Text("·")
                        Text("score \(String(format: "%.0f", candidate.blurScore))")
                    }
                    .font(BideTheme.caption().monospaced())
                    .foregroundStyle(BideTheme.textTertiary)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? BideTheme.accent : BideTheme.textTertiary)
            }
            .bideCard(padding: BideTheme.s)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(isSelected ? "Selected for review basket" : "Not selected")
        .accessibilityHint("Double-tap to add to Review Basket")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var accessibilityLabel: String {
        "\(candidate.confidenceLabel) photo from \(candidate.formattedDate). \(candidate.formattedSize)."
    }
}
