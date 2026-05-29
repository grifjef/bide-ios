import SwiftUI

struct ExactDuplicatesView: View {
    @Environment(PhotoLibraryService.self) private var photoLibrary
    @Environment(ReviewBasket.self) private var basket
    @State private var scan: ExactDuplicatesScanService?
    @State private var showHelp: Bool = false

    var body: some View {
        Group {
            if let scan {
                content(for: scan)
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(BideTheme.background)
        .navigationTitle("Exact duplicates")
        .navigationBarTitleDisplayMode(.large)
        .helpButton(isPresented: $showHelp)
        .task {
            if scan == nil {
                scan = ExactDuplicatesScanService(photoLibrary: photoLibrary)
            }
            scan?.startScanIfNeeded()
        }
    }

    @ViewBuilder
    private func content(for scan: ExactDuplicatesScanService) -> some View {
        switch scan.state {
        case .idle:
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        case .scanning:
            scanningState
        case .cancelled:
            cancelledState(scan)
        case .failed(let message):
            failureState(message: message, scan: scan)
        case .completed:
            if scan.groups.isEmpty {
                emptyState(scan)
            } else {
                groupList(scan)
            }
        }
    }

    private var scanningState: some View {
        VStack(spacing: BideTheme.m) {
            ProgressView().controlSize(.large)
            Text("Looking for exact duplicates…")
                .font(BideTheme.body())
                .foregroundStyle(BideTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func cancelledState(_ scan: ExactDuplicatesScanService) -> some View {
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

    private func failureState(message: String, scan: ExactDuplicatesScanService) -> some View {
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

    private func emptyState(_ scan: ExactDuplicatesScanService) -> some View {
        VStack(spacing: BideTheme.m) {
            Image(systemName: "sparkles")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(BideTheme.primary)
            Text("No duplicates found")
                .font(BideTheme.cardTitle())
            Text("Bide checked \(scan.totalAssetsConsidered) photo\(scan.totalAssetsConsidered == 1 ? "" : "s") and didn't find any byte-for-byte duplicates. Try Similar Photos for near-duplicates instead.")
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

    private func groupList(_ scan: ExactDuplicatesScanService) -> some View {
        ScrollView {
            VStack(spacing: BideTheme.m) {
                summaryCard(scan)
                LazyVStack(spacing: BideTheme.s) {
                    ForEach(scan.groups) { group in
                        DuplicateGroupCard(group: group) {
                            addAllDuplicates(group)
                        }
                    }
                }
                Spacer(minLength: BideTheme.xxl)
            }
            .padding(BideTheme.m)
        }
    }

    private func summaryCard(_ scan: ExactDuplicatesScanService) -> some View {
        let s = scan.summary
        return VStack(alignment: .leading, spacing: BideTheme.s) {
            Text(scan.formattedReclaim)
                .font(BideTheme.display())
                .foregroundStyle(BideTheme.primary)
            Text("\(s.duplicateCount) duplicate copies across \(s.groupCount) group\(s.groupCount == 1 ? "" : "s")")
                .font(BideTheme.body())
                .foregroundStyle(BideTheme.textSecondary)
            Text("These are byte-for-byte identical to another photo in your library. The oldest copy is kept; the rest go to your Review Basket when you tap a card.")
                .font(BideTheme.caption())
                .foregroundStyle(BideTheme.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .bideCard()
    }

    private func addAllDuplicates(_ group: ExactDuplicateGroup) {
        for duplicate in group.duplicates {
            if basket.contains(localIdentifier: duplicate.id) { continue }
            basket.add(
                ReviewBasket.Item(
                    localIdentifier: duplicate.id,
                    source: .exactDuplicates,
                    estimatedBytes: duplicate.estimatedFileSize,
                    displayDate: dateFormatter.string(from: duplicate.creationDate)
                )
            )
        }
    }
}

private let dateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateStyle = .medium
    f.timeStyle = .short
    return f
}()

// MARK: - DuplicateGroupCard

private struct DuplicateGroupCard: View {
    let group: ExactDuplicateGroup
    let onAddAll: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: BideTheme.s) {
            HStack(alignment: .top) {
                if let keeper = group.keeper {
                    ThumbnailView(localIdentifier: keeper.localIdentifier)
                        .frame(width: 72, height: 72)
                        .clipShape(RoundedRectangle(cornerRadius: BideTheme.cornerSmall, style: .continuous))
                }
                VStack(alignment: .leading, spacing: BideTheme.xs) {
                    Text("\(group.assets.count) identical copies")
                        .font(BideTheme.cardTitle())
                    if let keeper = group.keeper {
                        Text("Original from \(dateFormatter.string(from: keeper.creationDate))")
                            .font(BideTheme.caption())
                            .foregroundStyle(BideTheme.textSecondary)
                    }
                    Text("Reclaim \(group.formattedReclaim)")
                        .font(BideTheme.caption().weight(.semibold))
                        .foregroundStyle(BideTheme.primary)
                }
                Spacer()
            }

            Button(action: onAddAll) {
                Label(
                    "Add \(group.duplicates.count) duplicate\(group.duplicates.count == 1 ? "" : "s") to basket",
                    systemImage: "tray.and.arrow.down"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(BideTheme.accent)
            .controlSize(.regular)
        }
        .bideCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(group.assets.count) identical copies. Reclaim \(group.formattedReclaim).")
        .accessibilityHint("Double-tap the button to add all duplicates to the Review Basket.")
    }
}
