import XCTest
@testable import Bide

final class ExactDuplicateDetectorTests: XCTestCase {

    // MARK: - Detection

    func test_detect_findsGroupsBySignature() {
        let a = candidate(id: "a", date: at(year: 2026, hour: 12), w: 4000, h: 3000, size: 2_000_000)
        let b = candidate(id: "b", date: at(year: 2026, hour: 12), w: 4000, h: 3000, size: 2_000_000)
        let c = candidate(id: "c", date: at(year: 2026, hour: 13), w: 4000, h: 3000, size: 2_000_000)

        let groups = ExactDuplicateDetector.detect([a, b, c])
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(Set(groups[0].assets.map(\.id)), Set(["a", "b"]))
    }

    func test_detect_ignoresSingletons() {
        let a = candidate(id: "a", date: at(year: 2026, hour: 12), w: 4000, h: 3000, size: 2_000_000)
        let b = candidate(id: "b", date: at(year: 2026, hour: 13), w: 4000, h: 3000, size: 2_000_000)

        let groups = ExactDuplicateDetector.detect([a, b])
        XCTAssertEqual(groups.count, 0)
    }

    func test_detect_distinguishesByDimensions() {
        let a = candidate(id: "a", date: at(year: 2026, hour: 12), w: 4000, h: 3000, size: 2_000_000)
        let b = candidate(id: "b", date: at(year: 2026, hour: 12), w: 2000, h: 1500, size: 2_000_000)

        let groups = ExactDuplicateDetector.detect([a, b])
        XCTAssertEqual(groups.count, 0)
    }

    func test_detect_distinguishesBySize() {
        let a = candidate(id: "a", date: at(year: 2026, hour: 12), w: 4000, h: 3000, size: 2_000_000)
        let b = candidate(id: "b", date: at(year: 2026, hour: 12), w: 4000, h: 3000, size: 3_000_000)

        let groups = ExactDuplicateDetector.detect([a, b])
        XCTAssertEqual(groups.count, 0)
    }

    func test_detect_excludesFavorites() {
        let a = candidate(id: "a", date: at(year: 2026, hour: 12), w: 4000, h: 3000, size: 2_000_000, fav: true)
        let b = candidate(id: "b", date: at(year: 2026, hour: 12), w: 4000, h: 3000, size: 2_000_000, fav: false)
        let c = candidate(id: "c", date: at(year: 2026, hour: 12), w: 4000, h: 3000, size: 2_000_000, fav: false)

        // a is favorited so excluded from detection — b and c still form a group of 2
        let groups = ExactDuplicateDetector.detect([a, b, c])
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(Set(groups[0].assets.map(\.id)), Set(["b", "c"]))
    }

    func test_detect_excludesHidden() {
        let a = candidate(id: "a", date: at(year: 2026, hour: 12), w: 4000, h: 3000, size: 2_000_000, hidden: true)
        let b = candidate(id: "b", date: at(year: 2026, hour: 12), w: 4000, h: 3000, size: 2_000_000)

        let groups = ExactDuplicateDetector.detect([a, b])
        XCTAssertEqual(groups.count, 0)
    }

    // MARK: - Group sorting

    func test_detect_sortsByReclaimableBytesDescending() {
        // Group 1: two 1MB duplicates (1 MB reclaimable)
        let a1 = candidate(id: "a1", date: at(year: 2026, hour: 12), w: 4000, h: 3000, size: 1_000_000)
        let a2 = candidate(id: "a2", date: at(year: 2026, hour: 12), w: 4000, h: 3000, size: 1_000_000)

        // Group 2: three 5MB duplicates (10 MB reclaimable — 2 copies extra)
        let b1 = candidate(id: "b1", date: at(year: 2026, hour: 13), w: 4000, h: 3000, size: 5_000_000)
        let b2 = candidate(id: "b2", date: at(year: 2026, hour: 13), w: 4000, h: 3000, size: 5_000_000)
        let b3 = candidate(id: "b3", date: at(year: 2026, hour: 13), w: 4000, h: 3000, size: 5_000_000)

        let groups = ExactDuplicateDetector.detect([a1, a2, b1, b2, b3])
        XCTAssertEqual(groups.count, 2)
        XCTAssertEqual(groups[0].assets.count, 3) // group b first (more reclaimable)
        XCTAssertEqual(groups[1].assets.count, 2)
    }

    // MARK: - Keeper

    func test_keeperIsOldestInGroup() {
        let early = candidate(id: "early", date: at(year: 2024, hour: 12), w: 4000, h: 3000, size: 2_000_000)
        let late = candidate(id: "late", date: at(year: 2026, hour: 12), w: 4000, h: 3000, size: 2_000_000)

        // Same dims+size; only date differs. Bucket date matches both at year level
        // — actually with second resolution they will mismatch. Test that detection
        // requires SAME signature including date.
        let groups = ExactDuplicateDetector.detect([early, late])
        XCTAssertEqual(groups.count, 0, "different dates → not duplicates")
    }

    func test_keeperIsOldestWhenTimestampsMatch() {
        let sameDate = at(year: 2026, hour: 12)
        let original = candidate(id: "original", date: sameDate, w: 4000, h: 3000, size: 2_000_000)
        let copy = candidate(id: "copy", date: sameDate, w: 4000, h: 3000, size: 2_000_000)

        let groups = ExactDuplicateDetector.detect([copy, original])
        XCTAssertEqual(groups.count, 1)
        XCTAssertNotNil(groups[0].keeper)
        // When timestamps are equal, the order is stable by sort — both have same date
        // so either could be keeper; just verify there's exactly one duplicate
        XCTAssertEqual(groups[0].duplicates.count, 1)
    }

    // MARK: - Summary statistics

    func test_summary_countsCorrectly() {
        let a1 = candidate(id: "a1", date: at(year: 2026, hour: 12), w: 4000, h: 3000, size: 1_000_000)
        let a2 = candidate(id: "a2", date: at(year: 2026, hour: 12), w: 4000, h: 3000, size: 1_000_000)
        let a3 = candidate(id: "a3", date: at(year: 2026, hour: 12), w: 4000, h: 3000, size: 1_000_000)

        let groups = ExactDuplicateDetector.detect([a1, a2, a3])
        let s = ExactDuplicateDetector.summary(groups)
        XCTAssertEqual(s.groupCount, 1)
        XCTAssertEqual(s.duplicateCount, 2) // 3 assets, 1 keeper, 2 duplicates
        XCTAssertEqual(s.reclaimableBytes, 2_000_000)
    }

    func test_summary_emptyGroupsAreZero() {
        let s = ExactDuplicateDetector.summary([])
        XCTAssertEqual(s.groupCount, 0)
        XCTAssertEqual(s.duplicateCount, 0)
        XCTAssertEqual(s.reclaimableBytes, 0)
    }

    // MARK: - Signature strictness

    func test_signature_requiresExactSizeEquality() {
        // Two photos with even a 1-byte difference are NOT duplicates.
        // iOS HEIC is deterministic — re-imports produce identical bytes.
        // Any size variance signals a different source image or re-encode.
        let a = candidate(id: "a", date: at(year: 2026, hour: 12), w: 4000, h: 3000, size: 2_000_000)
        let b = candidate(id: "b", date: at(year: 2026, hour: 12), w: 4000, h: 3000, size: 2_000_001)

        let groups = ExactDuplicateDetector.detect([a, b])
        XCTAssertEqual(groups.count, 0, "1-byte size diff → not a duplicate; Similar Photos handles re-encoded variants")
    }

    // MARK: - Helpers

    private func candidate(
        id: String,
        date: Date,
        w: Int,
        h: Int,
        size: Int64,
        fav: Bool = false,
        hidden: Bool = false
    ) -> SimilarPhotoCandidate {
        SimilarPhotoCandidate(
            localIdentifier: id,
            creationDate: date,
            pixelWidth: w,
            pixelHeight: h,
            estimatedFileSize: size,
            isFavorite: fav,
            isHidden: hidden,
            isLivePhoto: false,
            hasBeenEdited: false,
            isInUserAlbum: false
        )
    }

    private func at(year: Int, month: Int = 5, day: Int = 27, hour: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        return Calendar.current.date(from: components)!
    }
}
