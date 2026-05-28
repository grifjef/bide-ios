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

    private let photoLibrary: PhotoLibraryService
    private let now: Date
    private let recencyThreshold: TimeInterval

    init(
        photoLibrary: PhotoLibraryService,
        now: Date = Date(),
        recencyDays: Int = 30
    ) {
        self.photoLibrary = photoLibrary
        self.now = now
        self.recencyThreshold = TimeInterval(recencyDays * 24 * 60 * 60)
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
        loadState = .loaded
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
