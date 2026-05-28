import XCTest
@testable import Bide

@MainActor
final class ScreenshotsViewModelTests: XCTestCase {

    // MARK: - Grouping

    func test_groupByMonth_sortsNewestMonthFirst() {
        let may = makeSummary(id: "may", date: dateFor(year: 2026, month: 5, day: 10))
        let april = makeSummary(id: "april", date: dateFor(year: 2026, month: 4, day: 15))
        let march = makeSummary(id: "march", date: dateFor(year: 2026, month: 3, day: 20))

        let groups = ScreenshotsViewModel.groupByMonth([april, march, may])

        XCTAssertEqual(groups.map(\.id), ["2026-05", "2026-04", "2026-03"])
    }

    func test_groupByMonth_combinesSameMonthItems() {
        let may10 = makeSummary(id: "a", date: dateFor(year: 2026, month: 5, day: 10))
        let may20 = makeSummary(id: "b", date: dateFor(year: 2026, month: 5, day: 20))
        let may01 = makeSummary(id: "c", date: dateFor(year: 2026, month: 5, day: 1))

        let groups = ScreenshotsViewModel.groupByMonth([may10, may20, may01])

        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups.first?.items.count, 3)
        XCTAssertEqual(groups.first?.id, "2026-05")
    }

    func test_groupByMonth_skipsItemsWithoutCreationDate() {
        let dated = makeSummary(id: "a", date: dateFor(year: 2026, month: 5, day: 10))
        let undated = makeSummary(id: "b", date: nil)

        let groups = ScreenshotsViewModel.groupByMonth([dated, undated])

        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups.first?.items.count, 1)
        XCTAssertEqual(groups.first?.items.first?.localIdentifier, "a")
    }

    func test_groupByMonth_handlesCrossYearBoundary() {
        let dec2025 = makeSummary(id: "a", date: dateFor(year: 2025, month: 12, day: 30))
        let jan2026 = makeSummary(id: "b", date: dateFor(year: 2026, month: 1, day: 2))

        let groups = ScreenshotsViewModel.groupByMonth([dec2025, jan2026])

        XCTAssertEqual(groups.map(\.id), ["2026-01", "2025-12"])
    }

    func test_groupByMonth_emptyInputReturnsEmpty() {
        XCTAssertEqual(ScreenshotsViewModel.groupByMonth([]), [])
    }

    // MARK: - Year grouping

    func test_groupMonthsByYear_aggregatesAcrossMonthsOfSameYear() {
        let may2026 = makeSummary(id: "a", date: dateFor(year: 2026, month: 5, day: 10))
        let april2026 = makeSummary(id: "b", date: dateFor(year: 2026, month: 4, day: 15))
        let dec2025 = makeSummary(id: "c", date: dateFor(year: 2025, month: 12, day: 1))

        let months = ScreenshotsViewModel.groupByMonth([may2026, april2026, dec2025])
        let years = ScreenshotsViewModel.groupMonthsByYear(months)

        XCTAssertEqual(years.count, 2)
        XCTAssertEqual(years.map(\.id), [2026, 2025])
        XCTAssertEqual(years[0].months.count, 2)
        XCTAssertEqual(years[0].totalItems, 2)
        XCTAssertEqual(years[1].months.count, 1)
        XCTAssertEqual(years[1].totalItems, 1)
    }

    func test_groupMonthsByYear_sortsNewestYearFirst() {
        let items = [
            makeSummary(id: "a", date: dateFor(year: 2023, month: 1, day: 1)),
            makeSummary(id: "b", date: dateFor(year: 2026, month: 1, day: 1)),
            makeSummary(id: "c", date: dateFor(year: 2024, month: 1, day: 1))
        ]
        let months = ScreenshotsViewModel.groupByMonth(items)
        let years = ScreenshotsViewModel.groupMonthsByYear(months)

        XCTAssertEqual(years.map(\.id), [2026, 2024, 2023])
    }

    func test_groupMonthsByYear_emptyInputReturnsEmpty() {
        XCTAssertEqual(ScreenshotsViewModel.groupMonthsByYear([]), [])
    }

    func test_selectableItemsInYear_excludesProtectedAcrossMonths() {
        let vm = makeViewModel(now: dateFor(year: 2026, month: 5, day: 27), recencyDays: 30)
        let monthA = makeSummary(id: "a", date: dateFor(year: 2024, month: 3, day: 10))
        let monthB = makeSummary(id: "b", date: dateFor(year: 2024, month: 6, day: 15), isFavorite: true)
        let monthC = makeSummary(id: "c", date: dateFor(year: 2024, month: 6, day: 20))

        let groups = ScreenshotsViewModel.groupByMonth([monthA, monthB, monthC])
        let years = ScreenshotsViewModel.groupMonthsByYear(groups)
        XCTAssertEqual(years.count, 1)

        let selectable = vm.selectableItems(in: years[0])
        XCTAssertEqual(Set(selectable.map(\.localIdentifier)), Set(["a", "c"]))
    }

    // MARK: - Protection

    func test_protectionReason_favoriteIsProtected() {
        let vm = makeViewModel()
        let favorite = makeSummary(
            id: "a",
            date: dateFor(year: 2025, month: 1, day: 1),
            isFavorite: true
        )
        XCTAssertEqual(vm.protectionReason(favorite), .favorite)
        XCTAssertTrue(vm.isProtected(favorite))
    }

    func test_protectionReason_hiddenIsProtected() {
        let vm = makeViewModel()
        let hidden = makeSummary(
            id: "a",
            date: dateFor(year: 2025, month: 1, day: 1),
            isHidden: true
        )
        XCTAssertEqual(vm.protectionReason(hidden), .hidden)
    }

    func test_protectionReason_recentIsProtected() {
        // "now" is 2026-05-27 and recencyDays is 30 → 2026-04-27 onwards is recent
        let vm = makeViewModel(now: dateFor(year: 2026, month: 5, day: 27), recencyDays: 30)
        let recent = makeSummary(id: "a", date: dateFor(year: 2026, month: 5, day: 15))
        XCTAssertEqual(vm.protectionReason(recent), .recent)
        XCTAssertTrue(vm.isProtected(recent))
    }

    func test_protectionReason_olderThan30DaysNotProtected() {
        let vm = makeViewModel(now: dateFor(year: 2026, month: 5, day: 27), recencyDays: 30)
        let old = makeSummary(id: "a", date: dateFor(year: 2025, month: 11, day: 1))
        XCTAssertNil(vm.protectionReason(old))
        XCTAssertFalse(vm.isProtected(old))
    }

    func test_protectionReason_favoriteTakesPrecedenceOverRecent() {
        let vm = makeViewModel(now: dateFor(year: 2026, month: 5, day: 27), recencyDays: 30)
        let recentFavorite = makeSummary(
            id: "a",
            date: dateFor(year: 2026, month: 5, day: 20),
            isFavorite: true
        )
        XCTAssertEqual(vm.protectionReason(recentFavorite), .favorite)
    }

    func test_protectionReason_undatedItemNotProtectedByRecency() {
        // Undated items can't be evaluated for recency, so they're not auto-protected for that reason
        let vm = makeViewModel()
        let undated = makeSummary(id: "a", date: nil)
        XCTAssertNil(vm.protectionReason(undated))
    }

    // MARK: - selectableItems

    func test_selectableItems_excludesProtected() {
        let vm = makeViewModel(now: dateFor(year: 2026, month: 5, day: 27), recencyDays: 30)
        let old = makeSummary(id: "old", date: dateFor(year: 2024, month: 1, day: 1))
        let recent = makeSummary(id: "recent", date: dateFor(year: 2026, month: 5, day: 20))
        let favorite = makeSummary(
            id: "fav",
            date: dateFor(year: 2024, month: 1, day: 1),
            isFavorite: true
        )

        let group = ScreenshotsViewModel.MonthGroup(
            id: "2024-01",
            title: "January 2024",
            representativeDate: dateFor(year: 2024, month: 1, day: 1),
            items: [old, recent, favorite]
        )

        let selectable = vm.selectableItems(in: group)
        XCTAssertEqual(selectable.map(\.localIdentifier), ["old"])
    }

    // MARK: - Helpers

    private func makeViewModel(
        now: Date = Date(),
        recencyDays: Int = 30
    ) -> ScreenshotsViewModel {
        ScreenshotsViewModel(
            photoLibrary: PhotoLibraryService(),
            now: now,
            recencyDays: recencyDays
        )
    }

    private func makeSummary(
        id: String,
        date: Date?,
        isFavorite: Bool = false,
        isHidden: Bool = false
    ) -> ScreenshotSummary {
        ScreenshotSummary(
            localIdentifier: id,
            creationDate: date,
            pixelWidth: 1170,
            pixelHeight: 2532,
            isFavorite: isFavorite,
            isHidden: isHidden
        )
    }

    private func dateFor(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 12
        return Calendar.current.date(from: components)!
    }
}
