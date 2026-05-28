import Foundation
import Observation

@Observable
@MainActor
final class ScreenshotsViewModel {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    struct MonthGroup: Identifiable, Equatable {
        let id: String          // "2026-05"
        let title: String       // "May 2026"
        let representativeDate: Date
        let items: [ScreenshotSummary]
    }

    /// Groups months by their year so the UI can offer "Select all from 2024"
    /// bulk actions at the year boundary. Years are sorted newest first.
    struct YearGroup: Identifiable, Equatable {
        let id: Int             // 2026
        let title: String       // "2026"
        let months: [MonthGroup]

        var totalItems: Int {
            months.reduce(0) { $0 + $1.items.count }
        }
    }

    enum ProtectionReason: Equatable {
        case favorite
        case hidden
        case recent      // within the recency threshold
    }

    private(set) var loadState: LoadState = .idle
    private(set) var groups: [MonthGroup] = []
    private(set) var yearGroups: [YearGroup] = []
    private(set) var totalCount: Int = 0
    private(set) var protectedCount: Int = 0

    /// Flat list of every loaded screenshot's local identifier. The view uses
    /// this to drive `PHCachingImageManager` prewarming so the grid scrolls
    /// without the per-row decode hitch.
    var allIdentifiers: [String] {
        groups.flatMap { $0.items.map(\.localIdentifier) }
    }

    /// Active filter — when non-nil, the view shows only screenshots whose
    /// stored category matches. Unanalyzed screenshots are always shown
    /// regardless of filter (we don't hide things we haven't OCR'd yet).
    var filter: ScreenshotCategory?

    /// Cached per-screenshot category lookup populated from `IndexedAssetStore`
    /// on each `reload`. Decoupled from the persistence layer so the View can
    /// read it without async hops.
    private(set) var cachedCategories: [String: ScreenshotCategory] = [:]

    /// Set to true when `classify(...)` is running. The view shows a progress
    /// indicator and disables the Sort button.
    private(set) var isClassifying: Bool = false
    private(set) var classifyProgress: Double = 0.0
    private(set) var classifiedCount: Int = 0

    private let photoLibrary: PhotoLibraryService
    private let vision = VisionService()
    private let now: Date
    private let recencyThreshold: TimeInterval

    /// Optional persistence layer. When provided, category results are
    /// cached so subsequent visits don't re-OCR. Production code injects
    /// the IndexedAssetStore; tests can pass nil for behavior-only tests.
    private let indexedAssetStore: IndexedAssetStore?

    init(
        photoLibrary: PhotoLibraryService,
        now: Date = Date(),
        recencyDays: Int = 30,
        indexedAssetStore: IndexedAssetStore? = nil
    ) {
        self.photoLibrary = photoLibrary
        self.now = now
        self.recencyThreshold = TimeInterval(recencyDays * 24 * 60 * 60)
        self.indexedAssetStore = indexedAssetStore
    }

    // MARK: - Loading

    func loadIfNeeded() async {
        guard loadState != .loaded && loadState != .loading else { return }
        await reload()
    }

    func reload() async {
        loadState = .loading
        let fetched = await photoLibrary.fetchScreenshots(limit: 1000)
        groups = Self.groupByMonth(fetched)
        yearGroups = Self.groupMonthsByYear(groups)
        totalCount = fetched.count
        protectedCount = fetched.filter { isProtected($0) }.count
        // Pull any previously-stored categories so the filter chips work
        // immediately without re-OCR.
        cachedCategories = loadCachedCategories(for: fetched)
        loadState = .loaded
    }

    private func loadCachedCategories(
        for screenshots: [ScreenshotSummary]
    ) -> [String: ScreenshotCategory] {
        guard let store = indexedAssetStore else { return [:] }
        var result: [String: ScreenshotCategory] = [:]
        for screenshot in screenshots {
            if let category = try? store.storedScreenshotCategory(for: screenshot.localIdentifier) {
                result[screenshot.localIdentifier] = category
            }
        }
        return result
    }

    /// Category of a screenshot — either from cache, or `.unanalyzed`.
    func category(for screenshot: ScreenshotSummary) -> ScreenshotCategory {
        cachedCategories[screenshot.localIdentifier] ?? .unanalyzed
    }

    /// True if the active filter matches this screenshot, or no filter is set.
    /// Unanalyzed screenshots pass any filter — we never hide things we
    /// haven't OCR'd.
    func passesFilter(_ screenshot: ScreenshotSummary) -> Bool {
        guard let filter else { return true }
        let cat = category(for: screenshot)
        if cat == .unanalyzed { return true }
        return cat == filter
    }

    // MARK: - Classification

    /// Run OCR on any screenshot we haven't classified yet and persist the
    /// result. Resumable — re-running it only processes the remaining
    /// unanalyzed items.
    func classifyUnanalyzed() async {
        guard !isClassifying else { return }
        guard let store = indexedAssetStore else { return }

        let allItems = groups.flatMap(\.items)
        let toScan = allItems.filter { cachedCategories[$0.localIdentifier] == nil }
        guard !toScan.isEmpty else { return }

        isClassifying = true
        classifyProgress = 0
        classifiedCount = 0
        defer { isClassifying = false }

        let thumbnailSize = CGSize(width: 256, height: 256)
        for (idx, item) in toScan.enumerated() {
            if Task.isCancelled { return }
            guard let image = await photoLibrary.requestThumbnail(
                for: item.localIdentifier,
                targetSize: thumbnailSize
            ) else { continue }

            let chars = await vision.textCharacterCount(in: image)
            let category = OCRClassifier.classify(textCharacterCount: chars)
            cachedCategories[item.localIdentifier] = category
            _ = try? store.upsertScreenshotCategory(
                localIdentifier: item.localIdentifier,
                textCharacterCount: chars,
                category: category
            )
            classifiedCount += 1
            classifyProgress = Double(idx + 1) / Double(toScan.count)
        }
    }

    /// Distribution of cached categories — used in the filter sheet for
    /// "N visual · M text-heavy".
    var categoryCounts: [ScreenshotCategory: Int] {
        var counts: [ScreenshotCategory: Int] = [:]
        for cat in cachedCategories.values {
            counts[cat, default: 0] += 1
        }
        return counts
    }

    // MARK: - Protection logic

    func isProtected(_ item: ScreenshotSummary) -> Bool {
        protectionReason(item) != nil
    }

    func protectionReason(_ item: ScreenshotSummary) -> ProtectionReason? {
        if item.isFavorite { return .favorite }
        if item.isHidden { return .hidden }
        if let date = item.creationDate, now.timeIntervalSince(date) < recencyThreshold {
            return .recent
        }
        return nil
    }

    // MARK: - Grouping

    static func groupByMonth(_ items: [ScreenshotSummary]) -> [MonthGroup] {
        let calendar = Calendar.current
        let titleFormatter = DateFormatter()
        titleFormatter.dateFormat = "MMMM yyyy"

        struct Bucket {
            var key: String
            var title: String
            var date: Date
            var items: [ScreenshotSummary] = []
        }

        var buckets: [String: Bucket] = [:]

        for item in items {
            guard let date = item.creationDate else { continue }
            let comps = calendar.dateComponents([.year, .month], from: date)
            let key = String(format: "%04d-%02d", comps.year ?? 0, comps.month ?? 0)
            if buckets[key] == nil {
                let bucketDate = calendar.date(from: comps) ?? date
                buckets[key] = Bucket(
                    key: key,
                    title: titleFormatter.string(from: date),
                    date: bucketDate
                )
            }
            buckets[key]?.items.append(item)
        }

        return buckets.values
            .sorted { $0.date > $1.date } // newest month first
            .map { bucket in
                MonthGroup(
                    id: bucket.key,
                    title: bucket.title,
                    representativeDate: bucket.date,
                    items: bucket.items
                )
            }
    }

    // MARK: - Grouping (year)

    /// Aggregate month groups into year groups. Years are sorted newest first
    /// (matching the month sort), and within each year months are already in
    /// newest-first order from `groupByMonth`.
    static func groupMonthsByYear(_ months: [MonthGroup]) -> [YearGroup] {
        let calendar = Calendar.current
        var bucket: [Int: [MonthGroup]] = [:]
        for month in months {
            let year = calendar.component(.year, from: month.representativeDate)
            bucket[year, default: []].append(month)
        }
        return bucket
            .map { (year, months) -> YearGroup in
                YearGroup(id: year, title: "\(year)", months: months)
            }
            .sorted { $0.id > $1.id }
    }

    // MARK: - Basket helpers

    /// All non-protected items in a single month group.
    func selectableItems(in group: MonthGroup) -> [ScreenshotSummary] {
        group.items.filter { !isProtected($0) }
    }

    /// All non-protected items across every month in a year group.
    /// Used by the "Select all from YYYY" quick-clear affordance.
    func selectableItems(in year: YearGroup) -> [ScreenshotSummary] {
        year.months.flatMap { selectableItems(in: $0) }
    }
}

extension ScreenshotsViewModel.ProtectionReason {
    var displayName: String {
        switch self {
        case .favorite: return "Favorite"
        case .hidden:   return "Hidden"
        case .recent:   return "Recent"
        }
    }

    var iconName: String {
        switch self {
        case .favorite: return "heart.fill"
        case .hidden:   return "eye.slash.fill"
        case .recent:   return "clock.fill"
        }
    }
}
