import SwiftUI

struct ScreenshotsView: View {
    @Environment(PhotoLibraryService.self) private var photoLibrary
    @Environment(ReviewBasket.self) private var basket
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: ScreenshotsViewModel?

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
        .navigationTitle("Screenshots")
        .navigationBarTitleDisplayMode(.large)
        .task {
            if viewModel == nil {
                let store = IndexedAssetStore(modelContext: modelContext)
                viewModel = ScreenshotsViewModel(
                    photoLibrary: photoLibrary,
                    indexedAssetStore: store
                )
            }
            await viewModel?.loadIfNeeded()
            // Once the load completes we know the identifier set — kick
            // PhotoKit's caching manager so scrolling the (potentially
            // thousands-deep) grid is smooth instead of redecode-per-tile.
            if let identifiers = viewModel?.allIdentifiers, !identifiers.isEmpty {
                photoLibrary.startPrewarmingThumbnails(
                    for: identifiers,
                    targetSize: Self.gridThumbnailSize
                )
            }
        }
        .onDisappear {
            if let identifiers = viewModel?.allIdentifiers, !identifiers.isEmpty {
                photoLibrary.stopPrewarmingThumbnails(
                    for: identifiers,
                    targetSize: Self.gridThumbnailSize
                )
            }
        }
    }

    /// Target thumbnail size shared by `.task` prewarm hook and the row
    /// rendering. Keep in sync with `ScreenshotGridCell`'s `ThumbnailView`
    /// `targetSize` so the cache key matches.
    private static let gridThumbnailSize = CGSize(width: 220, height: 220)

    @ViewBuilder
    private func content(for viewModel: ScreenshotsViewModel) -> some View {
        switch viewModel.loadState {
        case .idle, .loading:
            loadingState
        case .failed(let message):
            failureState(message)
        case .loaded:
            if viewModel.groups.isEmpty {
                emptyState
            } else {
                screenshotList(viewModel)
            }
        }
    }

    // MARK: - States

    private var loadingState: some View {
        VStack(spacing: BideTheme.m) {
            ProgressView()
                .controlSize(.large)
            Text("Looking through your screenshots…")
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
            Text("Couldn't load screenshots")
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
            Image(systemName: "doc.on.doc")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(BideTheme.textTertiary)
            Text("No screenshots found")
                .font(BideTheme.cardTitle())
            Text("Your library has no screenshots right now, or they're stored in iCloud and not downloaded.")
                .font(BideTheme.body())
                .foregroundStyle(BideTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, BideTheme.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Main list

    private func screenshotList(_ viewModel: ScreenshotsViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BideTheme.m) {
                summaryHeader(viewModel)
                LazyVStack(alignment: .leading, spacing: BideTheme.l, pinnedViews: [.sectionHeaders]) {
                    ForEach(viewModel.yearGroups) { year in
                        yearHeader(year, viewModel: viewModel)
                        ForEach(year.months) { month in
                            Section {
                                grid(for: month, viewModel: viewModel)
                            } header: {
                                sectionHeader(for: month, viewModel: viewModel)
                            }
                        }
                    }
                }
            }
            .padding(BideTheme.m)
        }
    }

    private func yearHeader(
        _ year: ScreenshotsViewModel.YearGroup,
        viewModel: ScreenshotsViewModel
    ) -> some View {
        let selectable = viewModel.selectableItems(in: year)
        let selected = selectable.filter { basket.contains(localIdentifier: $0.localIdentifier) }
        let allInBasket = !selectable.isEmpty && selected.count == selectable.count

        return HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(year.title)
                    .font(BideTheme.display())
                Text("\(year.totalItems) screenshot\(year.totalItems == 1 ? "" : "s")")
                    .font(BideTheme.caption())
                    .foregroundStyle(BideTheme.textSecondary)
            }
            Spacer()
            if !selectable.isEmpty {
                Button {
                    toggleYear(year, viewModel: viewModel, allInBasket: allInBasket)
                } label: {
                    Text(allInBasket
                         ? "Deselect \(selectable.count)"
                         : "Select all \(selectable.count)")
                        .font(BideTheme.caption().weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(BideTheme.accent)
                .controlSize(.small)
                .accessibilityLabel(allInBasket
                    ? "Deselect all \(selectable.count) selectable screenshots from \(year.title)"
                    : "Select all \(selectable.count) selectable screenshots from \(year.title)")
            }
        }
        .padding(.top, BideTheme.s)
        .accessibilityElement(children: .contain)
    }

    private func toggleYear(
        _ year: ScreenshotsViewModel.YearGroup,
        viewModel: ScreenshotsViewModel,
        allInBasket: Bool
    ) {
        for item in viewModel.selectableItems(in: year) {
            if allInBasket {
                basket.remove(localIdentifier: item.localIdentifier)
            } else if !basket.contains(localIdentifier: item.localIdentifier) {
                basket.add(
                    ReviewBasket.Item(
                        localIdentifier: item.localIdentifier,
                        source: .screenshots,
                        estimatedBytes: estimatedScreenshotBytes(item),
                        displayDate: item.formattedDate
                    )
                )
            }
        }
    }

    private func summaryHeader(_ viewModel: ScreenshotsViewModel) -> some View {
        VStack(alignment: .leading, spacing: BideTheme.s) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(viewModel.totalCount) screenshot\(viewModel.totalCount == 1 ? "" : "s")")
                        .font(BideTheme.cardTitle())
                    if viewModel.protectedCount > 0 {
                        Text("\(viewModel.protectedCount) protected (favorited or recent)")
                            .font(BideTheme.caption())
                            .foregroundStyle(BideTheme.textSecondary)
                    }
                }
                Spacer()
                sortButton(viewModel)
            }

            if !viewModel.cachedCategories.isEmpty || viewModel.isClassifying {
                filterChips(viewModel)
            }
        }
    }

    @ViewBuilder
    private func sortButton(_ viewModel: ScreenshotsViewModel) -> some View {
        if viewModel.isClassifying {
            HStack(spacing: BideTheme.xs) {
                ProgressView()
                    .controlSize(.mini)
                Text("\(viewModel.classifiedCount) sorted")
                    .font(BideTheme.caption())
            }
            .foregroundStyle(BideTheme.textSecondary)
        } else {
            let totalUnanalyzed = viewModel.groups
                .flatMap(\.items)
                .filter { viewModel.category(for: $0) == .unanalyzed }
                .count
            if totalUnanalyzed > 0 {
                Button {
                    Task { await viewModel.classifyUnanalyzed() }
                } label: {
                    Label("Sort by type", systemImage: "text.viewfinder")
                        .font(BideTheme.caption().weight(.semibold))
                }
                .buttonStyle(.bordered)
                .tint(BideTheme.accent)
                .controlSize(.small)
            }
        }
    }

    private func filterChips(_ viewModel: ScreenshotsViewModel) -> some View {
        @Bindable var bindableVM = viewModel
        let counts = viewModel.categoryCounts
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: BideTheme.s) {
                chip(
                    label: "All",
                    iconName: "circle.grid.2x2",
                    isSelected: bindableVM.filter == nil
                ) { bindableVM.filter = nil }

                ForEach([ScreenshotCategory.textHeavy, .mixed, .visual]) { category in
                    let count = counts[category] ?? 0
                    if count > 0 {
                        chip(
                            label: "\(category.displayName) · \(count)",
                            iconName: category.iconName,
                            isSelected: bindableVM.filter == category
                        ) {
                            bindableVM.filter = (bindableVM.filter == category) ? nil : category
                        }
                    }
                }
            }
            .padding(.horizontal, BideTheme.xs)
        }
    }

    private func chip(
        label: String,
        iconName: String,
        isSelected: Bool,
        onTap: @escaping () -> Void
    ) -> some View {
        Button(action: onTap) {
            Label(label, systemImage: iconName)
                .font(BideTheme.caption().weight(.semibold))
                .padding(.horizontal, BideTheme.m)
                .padding(.vertical, BideTheme.s)
                .background(
                    Capsule().fill(isSelected ? BideTheme.accent : BideTheme.surface)
                )
                .foregroundStyle(isSelected ? .white : BideTheme.textPrimary)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func sectionHeader(for group: ScreenshotsViewModel.MonthGroup, viewModel: ScreenshotsViewModel) -> some View {
        let selectable = viewModel.selectableItems(in: group)
        let selectedInGroup = selectable.filter { basket.contains(localIdentifier: $0.localIdentifier) }
        let allInBasket = !selectable.isEmpty && selectedInGroup.count == selectable.count

        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(group.title)
                    .font(BideTheme.cardTitle())
                Text("\(group.items.count) screenshot\(group.items.count == 1 ? "" : "s")")
                    .font(BideTheme.caption())
                    .foregroundStyle(BideTheme.textSecondary)
            }
            Spacer()
            if !selectable.isEmpty {
                Button {
                    toggleGroup(group, viewModel: viewModel, allInBasket: allInBasket)
                } label: {
                    Text(allInBasket ? "Deselect all" : "Select all")
                        .font(BideTheme.caption().weight(.semibold))
                }
                .buttonStyle(.bordered)
                .tint(BideTheme.accent)
                .controlSize(.small)
            }
        }
        .padding(.vertical, BideTheme.s)
        .padding(.horizontal, BideTheme.xs)
        .background(BideTheme.background)
    }

    private func grid(for group: ScreenshotsViewModel.MonthGroup, viewModel: ScreenshotsViewModel) -> some View {
        let columns = [
            GridItem(.flexible(), spacing: BideTheme.s),
            GridItem(.flexible(), spacing: BideTheme.s),
            GridItem(.flexible(), spacing: BideTheme.s)
        ]
        let filteredItems = group.items.filter { viewModel.passesFilter($0) }
        return LazyVGrid(columns: columns, spacing: BideTheme.s) {
            ForEach(filteredItems) { item in
                ScreenshotTile(
                    item: item,
                    protection: viewModel.protectionReason(item),
                    isSelected: basket.contains(localIdentifier: item.localIdentifier)
                ) {
                    toggle(item, viewModel: viewModel)
                }
            }
        }
    }

    // MARK: - Actions

    private func toggle(_ item: ScreenshotSummary, viewModel: ScreenshotsViewModel) {
        guard !viewModel.isProtected(item) else { return }
        basket.toggle(
            ReviewBasket.Item(
                localIdentifier: item.localIdentifier,
                source: .screenshots,
                estimatedBytes: estimatedScreenshotBytes(item),
                displayDate: item.formattedDate
            )
        )
    }

    private func toggleGroup(
        _ group: ScreenshotsViewModel.MonthGroup,
        viewModel: ScreenshotsViewModel,
        allInBasket: Bool
    ) {
        for item in viewModel.selectableItems(in: group) {
            if allInBasket {
                basket.remove(localIdentifier: item.localIdentifier)
            } else if !basket.contains(localIdentifier: item.localIdentifier) {
                basket.add(
                    ReviewBasket.Item(
                        localIdentifier: item.localIdentifier,
                        source: .screenshots,
                        estimatedBytes: estimatedScreenshotBytes(item),
                        displayDate: item.formattedDate
                    )
                )
            }
        }
    }

    /// Estimate screenshot byte size from pixel dimensions. PHAssetResource.fileSize
    /// is expensive per-asset; estimating is fine for the basket total preview.
    /// Real bytes are computed at deletion time by iOS itself.
    private func estimatedScreenshotBytes(_ item: ScreenshotSummary) -> Int64 {
        // Heuristic: ~0.15 bytes per pixel for HEIC screenshots, ~0.3 for PNG.
        // We assume HEIC (iOS default since iOS 11) — slightly under-estimate is safer.
        let pixels = Int64(item.pixelWidth) * Int64(item.pixelHeight)
        return Int64(Double(pixels) * 0.15)
    }
}

// MARK: - ScreenshotTile

private struct ScreenshotTile: View {
    let item: ScreenshotSummary
    let protection: ScreenshotsViewModel.ProtectionReason?
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .topTrailing) {
                ThumbnailView(localIdentifier: item.localIdentifier)
                    .aspectRatio(9/19.5, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: BideTheme.cornerSmall, style: .continuous))
                    .overlay {
                        if isSelected {
                            RoundedRectangle(cornerRadius: BideTheme.cornerSmall, style: .continuous)
                                .strokeBorder(BideTheme.accent, lineWidth: 3)
                        }
                        if protection != nil {
                            RoundedRectangle(cornerRadius: BideTheme.cornerSmall, style: .continuous)
                                .fill(BideTheme.background.opacity(0.5))
                        }
                    }

                // Selection indicator
                if protection == nil {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(isSelected ? BideTheme.accent : .white.opacity(0.9))
                        .background(Circle().fill(isSelected ? .white : .black.opacity(0.35)).scaleEffect(0.85))
                        .padding(BideTheme.xs)
                }

                // Protection badge
                if let protection {
                    HStack(spacing: 2) {
                        Image(systemName: protection.iconName)
                        Text(protection.displayName)
                    }
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, BideTheme.s)
                    .padding(.vertical, 2)
                    .foregroundStyle(BideTheme.warning)
                    .background(.thinMaterial, in: Capsule())
                    .padding(BideTheme.xs)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(protection != nil)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
        .accessibilityHint(accessibilityHint)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var accessibilityLabel: String {
        let base = "Screenshot from \(item.formattedDate)"
        if let protection {
            return "\(base). Protected: \(protection.displayName.lowercased())."
        }
        return base
    }

    private var accessibilityValue: String {
        isSelected ? "Selected for review basket" : "Not selected"
    }

    private var accessibilityHint: String {
        protection != nil ? "" : "Double-tap to add to Review Basket"
    }
}
