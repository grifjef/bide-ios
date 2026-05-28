import SwiftUI

/// Shows photos from this date across past years. Each year is a horizontal
/// scroll of thumbnails — the user can tap to add to the basket, the same
/// way they would in any other module.
///
/// The point of this module isn't aggressive cleanup; it's a daily reason
/// to open Bide. A few minutes of nostalgic review per day is a much calmer
/// engagement loop than the typical "free up X GB" panic.
struct OnThisDayView: View {
    @Environment(PhotoLibraryService.self) private var photoLibrary
    @Environment(ReviewBasket.self) private var basket
    @State private var scan: OnThisDayService?

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
        .navigationTitle("On this day")
        .navigationBarTitleDisplayMode(.large)
        .task {
            if scan == nil {
                scan = OnThisDayService(photoLibrary: photoLibrary)
            }
            await scan?.loadIfNeeded()
        }
    }

    @ViewBuilder
    private func content(for scan: OnThisDayService) -> some View {
        switch scan.state {
        case .idle, .loading:
            VStack(spacing: BideTheme.m) {
                ProgressView().controlSize(.large)
                Text("Looking back…")
                    .font(BideTheme.body())
                    .foregroundStyle(BideTheme.textSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let message):
            VStack(spacing: BideTheme.m) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundStyle(BideTheme.warning)
                Text("Couldn't load past photos")
                    .font(BideTheme.cardTitle())
                Text(message)
                    .font(BideTheme.body())
                    .foregroundStyle(BideTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, BideTheme.xl)
            }
            .padding(BideTheme.l)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .loaded:
            if scan.groups.isEmpty {
                emptyState
            } else {
                yearScrolls(scan.groups)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: BideTheme.m) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(BideTheme.primary)
            Text("Nothing from this day yet")
                .font(BideTheme.cardTitle())
            Text("Bide didn't find photos from this calendar day in past years. Come back tomorrow — that's the whole idea.")
                .font(BideTheme.body())
                .foregroundStyle(BideTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, BideTheme.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func yearScrolls(_ groups: [OnThisDayMatcher.YearGroup]) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BideTheme.l) {
                ForEach(groups) { group in
                    yearSection(group)
                }
                Spacer(minLength: BideTheme.xxl)
            }
            .padding(BideTheme.m)
        }
    }

    private func yearSection(_ group: OnThisDayMatcher.YearGroup) -> some View {
        VStack(alignment: .leading, spacing: BideTheme.s) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(group.title)
                        .font(BideTheme.cardTitle())
                    Text("\(group.items.count) photo\(group.items.count == 1 ? "" : "s") from \(group.id)")
                        .font(BideTheme.caption())
                        .foregroundStyle(BideTheme.textSecondary)
                }
                Spacer()
            }

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: BideTheme.s) {
                    ForEach(group.items) { item in
                        Button {
                            toggle(item)
                        } label: {
                            ZStack(alignment: .topTrailing) {
                                ThumbnailView(localIdentifier: item.localIdentifier)
                                    .frame(width: 140, height: 140)
                                    .clipShape(RoundedRectangle(cornerRadius: BideTheme.cornerSmall, style: .continuous))
                                if basket.contains(localIdentifier: item.localIdentifier) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.title3)
                                        .foregroundStyle(BideTheme.accent)
                                        .padding(BideTheme.xs)
                                }
                                if item.isFavorite || item.isHidden {
                                    Image(systemName: "lock.fill")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(BideTheme.warning)
                                        .padding(BideTheme.xs)
                                        .background(.thinMaterial, in: Circle())
                                        .padding(BideTheme.xs)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(item.isFavorite || item.isHidden)
                        .accessibilityLabel(accessibilityLabel(for: item, in: group))
                        .accessibilityHint(item.isFavorite || item.isHidden ? "" : "Double-tap to add to Review Basket")
                    }
                }
                .padding(.horizontal, BideTheme.xs)
            }
        }
    }

    private func toggle(_ item: SimilarPhotoCandidate) {
        guard !item.isFavorite, !item.isHidden else { return }
        basket.toggle(
            ReviewBasket.Item(
                localIdentifier: item.localIdentifier,
                source: .similar,
                estimatedBytes: item.estimatedFileSize,
                displayDate: formattedDate(item.creationDate)
            )
        )
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private func accessibilityLabel(
        for item: SimilarPhotoCandidate,
        in group: OnThisDayMatcher.YearGroup
    ) -> String {
        let base = "Photo from \(group.title)"
        if item.isFavorite {
            return "\(base). Favorite, protected."
        }
        if item.isHidden {
            return "\(base). Hidden, protected."
        }
        return base
    }
}
