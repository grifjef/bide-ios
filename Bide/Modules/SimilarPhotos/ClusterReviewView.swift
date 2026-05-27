import SwiftUI

/// Detail view for a single similar-photo cluster. The user reviews each candidate
/// and explicitly adds the ones they don't want to the Review Basket. The "suggested
/// keeper" is highlighted but never auto-selected for deletion.
struct ClusterReviewView: View {
    let cluster: PhotoCluster
    @Environment(ReviewBasket.self) private var basket

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BideTheme.m) {
                suggestedKeeperCard

                Text("Other photos in this cluster")
                    .font(BideTheme.cardTitle())
                    .padding(.top, BideTheme.s)

                Text("Tap any photo to add it to the Review Basket. Nothing is deleted until you confirm.")
                    .font(BideTheme.caption())
                    .foregroundStyle(BideTheme.textSecondary)

                LazyVStack(spacing: BideTheme.s) {
                    ForEach(cluster.nonKeeperCandidates) { candidate in
                        CandidateRow(
                            candidate: candidate,
                            isSelected: basket.contains(localIdentifier: candidate.id),
                            onToggle: { toggle(candidate) }
                        )
                    }
                }

                Spacer(minLength: BideTheme.xxl)
            }
            .padding(BideTheme.m)
        }
        .background(BideTheme.background)
        .navigationTitle("Review cluster")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var suggestedKeeperCard: some View {
        VStack(alignment: .leading, spacing: BideTheme.s) {
            HStack {
                Text("Suggested keeper")
                    .font(BideTheme.cardTitle())
                Spacer()
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(BideTheme.primary)
            }

            if let keeper = cluster.suggestedKeeper {
                ThumbnailView(localIdentifier: keeper.localIdentifier)
                    .aspectRatio(CGFloat(keeper.pixelWidth) / CGFloat(keeper.pixelHeight), contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: BideTheme.cornerMedium, style: .continuous))

                HStack {
                    Text(formattedDate(keeper.creationDate))
                    Spacer()
                    Text("\(keeper.pixelWidth) × \(keeper.pixelHeight)")
                }
                .font(BideTheme.caption())
                .foregroundStyle(BideTheme.textSecondary)
            }

            Text(cluster.suggestedKeeperReason)
                .font(BideTheme.body())
                .foregroundStyle(BideTheme.textSecondary)
                .padding(.top, BideTheme.xs)
        }
        .bideCard()
    }

    private func toggle(_ candidate: SimilarPhotoCandidate) {
        let item = ReviewBasket.Item(
            localIdentifier: candidate.localIdentifier,
            source: .similar,
            estimatedBytes: candidate.estimatedFileSize,
            displayDate: formattedDate(candidate.creationDate)
        )
        basket.toggle(item)
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - CandidateRow

private struct CandidateRow: View {
    let candidate: SimilarPhotoCandidate
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(alignment: .center, spacing: BideTheme.m) {
                ThumbnailView(localIdentifier: candidate.localIdentifier)
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: BideTheme.cornerSmall, style: .continuous))

                VStack(alignment: .leading, spacing: BideTheme.xs) {
                    Text(formattedDate(candidate.creationDate))
                        .font(BideTheme.cardTitle())
                    Text("\(candidate.pixelWidth) × \(candidate.pixelHeight) · \(formattedSize(candidate.estimatedFileSize))")
                        .font(BideTheme.caption())
                        .foregroundStyle(BideTheme.textSecondary)
                    if candidate.isFavorite {
                        Label("Favorite — protected", systemImage: "heart.fill")
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
        .disabled(candidate.isFavorite || candidate.isHidden)
        .opacity(candidate.isFavorite || candidate.isHidden ? 0.55 : 1.0)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(isSelected ? "Selected for review basket" : "Not selected")
        .accessibilityHint(candidate.isFavorite || candidate.isHidden ? "" : "Double-tap to add to Review Basket")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var accessibilityLabel: String {
        let date = formattedDate(candidate.creationDate)
        let dims = "\(candidate.pixelWidth) by \(candidate.pixelHeight)"
        let size = formattedSize(candidate.estimatedFileSize)
        var parts = ["Photo from \(date)", dims, size]
        if candidate.isFavorite {
            parts.append("Favorite, protected")
        } else if candidate.isHidden {
            parts.append("Hidden, protected")
        }
        return parts.joined(separator: ". ")
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formattedSize(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
