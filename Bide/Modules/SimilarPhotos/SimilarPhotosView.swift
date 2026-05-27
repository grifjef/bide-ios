import SwiftUI
import SwiftData

struct SimilarPhotosView: View {
    @Environment(PhotoLibraryService.self) private var photoLibrary
    @Environment(ReviewBasket.self) private var basket
    @Environment(\.modelContext) private var modelContext
    @State private var scanService: SimilarPhotosScanService?

    var body: some View {
        Group {
            if let scanService {
                content(for: scanService)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(BideTheme.background)
        .navigationTitle("Similar photos")
        .navigationBarTitleDisplayMode(.large)
        .task {
            if scanService == nil {
                let store = IndexedAssetStore(modelContext: modelContext)
                scanService = SimilarPhotosScanService(
                    photoLibrary: photoLibrary,
                    indexedAssetStore: store
                )
            }
            scanService?.startScanIfNeeded()
        }
    }

    @ViewBuilder
    private func content(for scan: SimilarPhotosScanService) -> some View {
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
            if scan.clusters.isEmpty {
                emptyState(scan: scan)
            } else {
                clusterList(scan: scan)
            }
        }
    }

    // MARK: - States

    private func scanningState(progress: Double, label: String, scan: SimilarPhotosScanService) -> some View {
        VStack(spacing: BideTheme.m) {
            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .tint(BideTheme.accent)
                .padding(.horizontal, BideTheme.xl)
            Text(label)
                .font(BideTheme.body())
                .foregroundStyle(BideTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, BideTheme.l)

            Button("Cancel scan") { scan.cancel() }
                .font(BideTheme.caption())
                .foregroundStyle(BideTheme.textTertiary)
                .padding(.top, BideTheme.m)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(BideTheme.l)
    }

    private func cancelledState(scan: SimilarPhotosScanService) -> some View {
        VStack(spacing: BideTheme.m) {
            Image(systemName: "pause.circle")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(BideTheme.textTertiary)
            Text("Scan cancelled")
                .font(BideTheme.cardTitle())
            Button("Start again") { scan.startScan() }
                .buttonStyle(.borderedProminent)
                .tint(BideTheme.accent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func failedState(message: String, scan: SimilarPhotosScanService) -> some View {
        VStack(spacing: BideTheme.m) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(BideTheme.warning)
            Text("Couldn't finish the scan")
                .font(BideTheme.cardTitle())
            Text(message)
                .font(BideTheme.body())
                .foregroundStyle(BideTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, BideTheme.xl)
            Button("Try again") { scan.startScan() }
                .buttonStyle(.borderedProminent)
                .tint(BideTheme.accent)
        }
        .padding(BideTheme.l)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func emptyState(scan: SimilarPhotosScanService) -> some View {
        VStack(spacing: BideTheme.m) {
            Image(systemName: "sparkles")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(BideTheme.primary)
            Text("No similar photos found")
                .font(BideTheme.cardTitle())
            Text("Bide checked \(scan.totalAssetsConsidered) photo\(scan.totalAssetsConsidered == 1 ? "" : "s") and didn't find any tight clusters. You can scan again later.")
                .font(BideTheme.body())
                .foregroundStyle(BideTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, BideTheme.xl)
            Button("Scan again") { scan.startScan() }
                .buttonStyle(.bordered)
                .tint(BideTheme.accent)
                .padding(.top, BideTheme.m)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Cluster list

    private func clusterList(scan: SimilarPhotosScanService) -> some View {
        ScrollView {
            VStack(spacing: BideTheme.m) {
                summaryHeader(scan)

                LazyVStack(spacing: BideTheme.s) {
                    ForEach(scan.clusters) { cluster in
                        NavigationLink {
                            ClusterReviewView(cluster: cluster)
                        } label: {
                            ClusterCard(cluster: cluster, basket: basket)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(BideTheme.m)
        }
    }

    private func summaryHeader(_ scan: SimilarPhotosScanService) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(scan.clusters.count) cluster\(scan.clusters.count == 1 ? "" : "s") to review")
                    .font(BideTheme.cardTitle())
                Text("Scanned \(scan.totalAssetsConsidered) photo\(scan.totalAssetsConsidered == 1 ? "" : "s")")
                    .font(BideTheme.caption())
                    .foregroundStyle(BideTheme.textSecondary)
                if scan.featurePrintsReused > 0 || scan.featurePrintsComputed > 0 {
                    Text(cacheStats(scan))
                        .font(BideTheme.caption())
                        .foregroundStyle(BideTheme.textTertiary)
                }
            }
            Spacer()
            Button("Scan again") { scan.startScan() }
                .font(BideTheme.caption().weight(.semibold))
                .buttonStyle(.bordered)
                .tint(BideTheme.accent)
                .controlSize(.small)
        }
    }

    private func cacheStats(_ scan: SimilarPhotosScanService) -> String {
        let parts: [String] = [
            scan.featurePrintsReused > 0 ? "\(scan.featurePrintsReused) reused" : nil,
            scan.featurePrintsComputed > 0 ? "\(scan.featurePrintsComputed) newly analyzed" : nil
        ].compactMap { $0 }
        return parts.joined(separator: " · ")
    }
}

// MARK: - ClusterCard

private struct ClusterCard: View {
    let cluster: PhotoCluster
    let basket: ReviewBasket

    private var previewCount: Int { min(cluster.candidates.count, 3) }
    private var previewStackWidth: CGFloat {
        let cell: CGFloat = 64
        let overlap = BideTheme.s
        return cell + CGFloat(max(previewCount - 1, 0)) * (cell - overlap)
    }

    var body: some View {
        HStack(alignment: .top, spacing: BideTheme.m) {
            // Up to 3 small previews stacked left-to-right
            HStack(spacing: -BideTheme.s) {
                ForEach(Array(cluster.candidates.prefix(previewCount))) { candidate in
                    ThumbnailView(localIdentifier: candidate.localIdentifier)
                        .frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: BideTheme.cornerSmall, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: BideTheme.cornerSmall, style: .continuous)
                                .strokeBorder(BideTheme.background, lineWidth: 2)
                        )
                }
            }
            .frame(width: previewStackWidth, height: 64, alignment: .leading)

            VStack(alignment: .leading, spacing: BideTheme.xs) {
                Text("\(cluster.candidates.count) similar photos")
                    .font(BideTheme.cardTitle())
                Text(formattedDate(cluster.representativeDate))
                    .font(BideTheme.caption())
                    .foregroundStyle(BideTheme.textSecondary)
                if cluster.potentialReclaimBytes > 0 {
                    Text("Up to \(cluster.formattedPotentialReclaim) reclaimable")
                        .font(BideTheme.caption())
                        .foregroundStyle(BideTheme.primary)
                }

                let inBasket = cluster.nonKeeperCandidates.filter { basket.contains(localIdentifier: $0.id) }
                if !inBasket.isEmpty {
                    Label("\(inBasket.count) in basket", systemImage: "tray.fill")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(BideTheme.accent)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.callout.weight(.semibold))
                .foregroundStyle(BideTheme.textTertiary)
        }
        .bideCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Double-tap to review this cluster")
    }

    private var accessibilityLabel: String {
        let count = cluster.candidates.count
        let date = formattedDate(cluster.representativeDate)
        let reclaim = cluster.formattedPotentialReclaim
        let inBasket = cluster.nonKeeperCandidates.filter { basket.contains(localIdentifier: $0.id) }.count
        var parts = ["\(count) similar photos from \(date)", "Up to \(reclaim) reclaimable"]
        if inBasket > 0 {
            parts.append("\(inBasket) already in basket")
        }
        return parts.joined(separator: ". ")
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
