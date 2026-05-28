@testable import Bide
import XCTest

final class OnThisDayMatcherTests: XCTestCase {
    // MARK: - Basic matching

    func test_matchesSameDayPriorYear() {
        let target = makeDate(year: 2026, month: 5, day: 28)
        let priorYear = makeCandidate(id: "a", date: makeDate(year: 2025, month: 5, day: 28))
        let result = OnThisDayMatcher.groupsForToday(
            candidates: [priorYear],
            targetDate: target
        )
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.items.first?.id, "a")
        XCTAssertEqual(result.first?.title, "1 year ago")
    }

    func test_doesNotMatchDifferentDay() {
        let target = makeDate(year: 2026, month: 5, day: 28)
        let dayBefore = makeCandidate(id: "a", date: makeDate(year: 2025, month: 5, day: 27))
        let dayAfter = makeCandidate(id: "b", date: makeDate(year: 2025, month: 5, day: 29))
        let result = OnThisDayMatcher.groupsForToday(
            candidates: [dayBefore, dayAfter],
            targetDate: target
        )
        XCTAssertEqual(result.count, 0)
    }

    func test_doesNotMatchDifferentMonth() {
        let target = makeDate(year: 2026, month: 5, day: 28)
        let differentMonth = makeCandidate(id: "a", date: makeDate(year: 2025, month: 4, day: 28))
        let result = OnThisDayMatcher.groupsForToday(
            candidates: [differentMonth],
            targetDate: target
        )
        XCTAssertEqual(result.count, 0)
    }

    func test_doesNotMatchSameYear() {
        let target = makeDate(year: 2026, month: 5, day: 28)
        let sameYear = makeCandidate(id: "a", date: makeDate(year: 2026, month: 5, day: 28))
        let result = OnThisDayMatcher.groupsForToday(
            candidates: [sameYear],
            targetDate: target
        )
        XCTAssertEqual(result.count, 0)
    }

    func test_doesNotMatchFutureYear() {
        let target = makeDate(year: 2026, month: 5, day: 28)
        let future = makeCandidate(id: "a", date: makeDate(year: 2027, month: 5, day: 28))
        let result = OnThisDayMatcher.groupsForToday(
            candidates: [future],
            targetDate: target
        )
        XCTAssertEqual(result.count, 0)
    }

    // MARK: - Multi-year grouping

    func test_aggregatesAcrossYears_sortedNewestFirst() {
        let target = makeDate(year: 2026, month: 5, day: 28)
        let cands = [
            makeCandidate(id: "2024", date: makeDate(year: 2024, month: 5, day: 28)),
            makeCandidate(id: "2022", date: makeDate(year: 2022, month: 5, day: 28)),
            makeCandidate(id: "2025", date: makeDate(year: 2025, month: 5, day: 28))
        ]
        let result = OnThisDayMatcher.groupsForToday(candidates: cands, targetDate: target)

        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(result.map(\.id), [2025, 2024, 2022])
        XCTAssertEqual(result[0].title, "1 year ago")
        XCTAssertEqual(result[1].title, "2 years ago")
        XCTAssertEqual(result[2].title, "4 years ago")
    }

    func test_groupCountsMultipleItemsInSameYear() {
        let target = makeDate(year: 2026, month: 5, day: 28)
        let cands = [
            makeCandidate(id: "morning", date: makeDate(year: 2024, month: 5, day: 28, hour: 9)),
            makeCandidate(id: "evening", date: makeDate(year: 2024, month: 5, day: 28, hour: 19))
        ]
        let result = OnThisDayMatcher.groupsForToday(candidates: cands, targetDate: target)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].items.count, 2)
    }

    // MARK: - Within-year ordering

    func test_itemsSortedByTimeWithinYearGroup() {
        let target = makeDate(year: 2026, month: 5, day: 28)
        let cands = [
            makeCandidate(id: "late", date: makeDate(year: 2024, month: 5, day: 28, hour: 19)),
            makeCandidate(id: "early", date: makeDate(year: 2024, month: 5, day: 28, hour: 9)),
            makeCandidate(id: "noon", date: makeDate(year: 2024, month: 5, day: 28, hour: 12))
        ]
        let result = OnThisDayMatcher.groupsForToday(candidates: cands, targetDate: target)
        XCTAssertEqual(result[0].items.map(\.id), ["early", "noon", "late"])
    }

    // MARK: - Helpers

    func test_totalCount_sumsAcrossGroups() {
        let target = makeDate(year: 2026, month: 5, day: 28)
        let cands = [
            makeCandidate(id: "a", date: makeDate(year: 2024, month: 5, day: 28)),
            makeCandidate(id: "b", date: makeDate(year: 2023, month: 5, day: 28)),
            makeCandidate(id: "c", date: makeDate(year: 2023, month: 5, day: 28))
        ]
        let groups = OnThisDayMatcher.groupsForToday(candidates: cands, targetDate: target)
        XCTAssertEqual(OnThisDayMatcher.totalCount(groups), 3)
    }

    func test_totalCount_emptyIsZero() {
        XCTAssertEqual(OnThisDayMatcher.totalCount([]), 0)
    }

    // MARK: - Setup

    private func makeCandidate(id: String, date: Date) -> SimilarPhotoCandidate {
        SimilarPhotoCandidate(
            localIdentifier: id,
            creationDate: date,
            pixelWidth: 4000,
            pixelHeight: 3000,
            estimatedFileSize: 2_000_000,
            isFavorite: false,
            isHidden: false,
            isLivePhoto: false,
            hasBeenEdited: false,
            isInUserAlbum: false,
            burstIdentifier: nil
        )
    }

    private func makeDate(year: Int, month: Int, day: Int, hour: Int = 12) -> Date {
        var c = DateComponents()
        c.year = year
        c.month = month
        c.day = day
        c.hour = hour
        return Calendar.current.date(from: c)!
    }
}
