@testable import Bide
import XCTest

final class SimilarityClustererTests: XCTestCase {
    // MARK: - Time bucketing

    func test_timeBuckets_groupsWithinWindow() {
        // Three photos taken within 1 hour
        let items = [
            cand(id: "a", date: at(hour: 12, minute: 0)),
            cand(id: "b", date: at(hour: 12, minute: 15)),
            cand(id: "c", date: at(hour: 12, minute: 45))
        ]
        let buckets = SimilarityClusterer.timeBuckets(items, date: \.creationDate, window: 60 * 60)

        XCTAssertEqual(buckets.count, 1)
        XCTAssertEqual(buckets[0].map(\.id), ["a", "b", "c"])
    }

    func test_timeBuckets_splitsAcrossWindow() {
        let items = [
            cand(id: "morning", date: at(hour: 9, minute: 0)),
            cand(id: "noon", date: at(hour: 12, minute: 0)),
            cand(id: "evening", date: at(hour: 18, minute: 0))
        ]
        let buckets = SimilarityClusterer.timeBuckets(items, date: \.creationDate, window: 60 * 60)

        XCTAssertEqual(buckets.count, 3)
        XCTAssertEqual(buckets.map { $0.map(\.id) }, [["morning"], ["noon"], ["evening"]])
    }

    func test_timeBuckets_handlesOutOfOrderInput() {
        // Items come in random order — bucketing should sort first
        let items = [
            cand(id: "c", date: at(hour: 12, minute: 45)),
            cand(id: "a", date: at(hour: 12, minute: 0)),
            cand(id: "b", date: at(hour: 12, minute: 15))
        ]
        let buckets = SimilarityClusterer.timeBuckets(items, date: \.creationDate, window: 60 * 60)

        XCTAssertEqual(buckets.count, 1)
        XCTAssertEqual(buckets[0].map(\.id), ["a", "b", "c"])
    }

    func test_timeBuckets_emptyInput() {
        let buckets = SimilarityClusterer.timeBuckets(
            [SimilarPhotoCandidate](),
            date: \.creationDate
        )
        XCTAssertEqual(buckets.count, 0)
    }

    func test_timeBuckets_windowBoundaryInclusive() {
        // Items exactly 1 hour apart should be in the same bucket (boundary <=)
        let items = [
            cand(id: "a", date: at(hour: 12, minute: 0)),
            cand(id: "b", date: at(hour: 13, minute: 0))
        ]
        let buckets = SimilarityClusterer.timeBuckets(items, date: \.creationDate, window: 60 * 60)
        XCTAssertEqual(buckets.count, 1)
    }

    // MARK: - Distance clustering

    func test_clusterByDistance_groupsItemsBelowThreshold() {
        let items = ["a", "b", "c", "d"]
        // a-b: 5 (similar), c-d: 3 (similar), b-c: 30 (not)
        let dist: (String, String) -> Float? = { x, y in
            let pair = Set([x, y])
            if pair == Set(["a", "b"]) { return 5 }
            if pair == Set(["c", "d"]) { return 3 }
            return 30
        }
        let groups = SimilarityClusterer.clusterByDistance(items, distance: dist, threshold: 12)

        let sortedGroups = groups.map { Set($0) }.sorted { $0.first! < $1.first! }
        XCTAssertEqual(sortedGroups, [Set(["a", "b"]), Set(["c", "d"])])
    }

    func test_clusterByDistance_singletonsKept() {
        let items = ["a", "b"]
        let groups = SimilarityClusterer.clusterByDistance(
            items,
            distance: { _, _ in 30 },
            threshold: 12
        )
        XCTAssertEqual(groups.count, 2)
        XCTAssertEqual(Set(groups.map { Set($0) }), Set([Set(["a"]), Set(["b"])]))
    }

    func test_clusterByDistance_transitivelyMerges() {
        // a-b similar, b-c similar, a-c not directly checked → all 3 in one cluster
        let items = ["a", "b", "c"]
        let dist: (String, String) -> Float? = { x, y in
            let pair = Set([x, y])
            if pair == Set(["a", "b"]) { return 5 }
            if pair == Set(["b", "c"]) { return 5 }
            return 30
        }
        let groups = SimilarityClusterer.clusterByDistance(items, distance: dist, threshold: 12)
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(Set(groups[0]), Set(["a", "b", "c"]))
    }

    func test_clusterByDistance_emptyInput() {
        let groups = SimilarityClusterer.clusterByDistance(
            [String](),
            distance: { _, _ in nil },
            threshold: 12
        )
        XCTAssertEqual(groups.count, 0)
    }

    // MARK: - Keeper selection

    func test_pickKeeper_favoriteAlwaysWins() {
        let plain = cand(id: "plain", date: at(hour: 12, minute: 0), pixelWidth: 4000, pixelHeight: 3000)
        let favorite = cand(id: "fav", date: at(hour: 12, minute: 0), pixelWidth: 1000, pixelHeight: 1000, isFavorite: true)
        let edited = cand(id: "edited", date: at(hour: 12, minute: 0), pixelWidth: 4000, pixelHeight: 3000, hasBeenEdited: true)

        XCTAssertEqual(
            SimilarityClusterer.pickKeeper([plain, favorite, edited]).id,
            "fav"
        )
    }

    func test_pickKeeper_editedBeatsResolution() {
        let highRes = cand(id: "hires", date: at(hour: 12, minute: 0), pixelWidth: 4000, pixelHeight: 3000)
        let edited = cand(id: "edited", date: at(hour: 12, minute: 0), pixelWidth: 2000, pixelHeight: 1500, hasBeenEdited: true)

        XCTAssertEqual(
            SimilarityClusterer.pickKeeper([highRes, edited]).id,
            "edited"
        )
    }

    func test_pickKeeper_albumBeatsLivePhoto() {
        let live = cand(id: "live", date: at(hour: 12, minute: 0), isLivePhoto: true)
        let inAlbum = cand(id: "album", date: at(hour: 12, minute: 0), isInUserAlbum: true)

        XCTAssertEqual(
            SimilarityClusterer.pickKeeper([live, inAlbum]).id,
            "album"
        )
    }

    func test_pickKeeper_higherResolutionTiebreaker() {
        let low = cand(id: "low", date: at(hour: 12, minute: 0), pixelWidth: 1000, pixelHeight: 1000)
        let high = cand(id: "high", date: at(hour: 12, minute: 0), pixelWidth: 4000, pixelHeight: 4000)

        XCTAssertEqual(
            SimilarityClusterer.pickKeeper([low, high]).id,
            "high"
        )
    }

    func test_pickKeeper_newerWhenAllElseEqual() {
        let older = cand(id: "older", date: at(hour: 12, minute: 0))
        let newer = cand(id: "newer", date: at(hour: 12, minute: 30))

        XCTAssertEqual(
            SimilarityClusterer.pickKeeper([older, newer]).id,
            "newer"
        )
    }

    func test_pickKeeper_singleCandidateReturnsItself() {
        let only = cand(id: "only", date: at(hour: 12, minute: 0))
        XCTAssertEqual(SimilarityClusterer.pickKeeper([only]).id, "only")
    }

    // MARK: - Keeper reason

    func test_keeperReason_favoriteFlagged() {
        let plain = cand(id: "plain", date: at(hour: 12, minute: 0))
        let fav = cand(id: "fav", date: at(hour: 12, minute: 0), isFavorite: true)
        let reason = SimilarityClusterer.keeperReason([plain, fav], keeperId: "fav")
        XCTAssertTrue(reason.lowercased().contains("favorited"), "got: \(reason)")
    }

    func test_keeperReason_editedFlagged() {
        let plain = cand(id: "plain", date: at(hour: 12, minute: 0))
        let edited = cand(id: "edited", date: at(hour: 12, minute: 0), hasBeenEdited: true)
        let reason = SimilarityClusterer.keeperReason([plain, edited], keeperId: "edited")
        XCTAssertTrue(reason.lowercased().contains("edited"), "got: \(reason)")
    }

    func test_keeperReason_highestResolutionWhenTiebreaker() {
        let low = cand(id: "low", date: at(hour: 12, minute: 0), pixelWidth: 1000, pixelHeight: 1000)
        let high = cand(id: "high", date: at(hour: 12, minute: 0), pixelWidth: 4000, pixelHeight: 4000)
        let reason = SimilarityClusterer.keeperReason([low, high], keeperId: "high")
        XCTAssertTrue(reason.lowercased().contains("resolution"), "got: \(reason)")
    }

    func test_keeperReason_genericFallback() {
        // All candidates identical → no reason to distinguish
        let a = cand(id: "a", date: at(hour: 12, minute: 0))
        let b = cand(id: "b", date: at(hour: 12, minute: 0))
        let reason = SimilarityClusterer.keeperReason([a, b], keeperId: "a")
        XCTAssertTrue(reason.lowercased().contains("suggested keeper"), "got: \(reason)")
    }

    // MARK: - Burst grouping

    func test_burstGroups_groupsByBurstIdentifier() {
        let a = cand(id: "a", date: at(hour: 12, minute: 0), burstId: "burst-1")
        let b = cand(id: "b", date: at(hour: 12, minute: 0), burstId: "burst-1")
        let c = cand(id: "c", date: at(hour: 13, minute: 0), burstId: "burst-2")
        let d = cand(id: "d", date: at(hour: 14, minute: 0), burstId: nil)

        let groups = SimilarityClusterer.burstGroups([a, b, c, d])
        XCTAssertEqual(groups.count, 1, "burst-1 has 2 members; burst-2 only has 1; non-burst ignored")
        XCTAssertEqual(Set(groups[0].map(\.id)), Set(["a", "b"]))
    }

    func test_burstGroups_ignoresSingletonBursts() {
        let a = cand(id: "a", date: at(hour: 12, minute: 0), burstId: "burst-1")
        let groups = SimilarityClusterer.burstGroups([a])
        XCTAssertEqual(groups.count, 0)
    }

    func test_burstGroups_ignoresNilBurstIdentifier() {
        let a = cand(id: "a", date: at(hour: 12, minute: 0), burstId: nil)
        let b = cand(id: "b", date: at(hour: 12, minute: 0), burstId: nil)
        let groups = SimilarityClusterer.burstGroups([a, b])
        XCTAssertEqual(groups.count, 0)
    }

    func test_burstGroups_sortsMembersByDate() {
        let early = cand(id: "early", date: at(hour: 12, minute: 0), burstId: "burst-1")
        let mid = cand(id: "mid", date: at(hour: 12, minute: 1), burstId: "burst-1")
        let late = cand(id: "late", date: at(hour: 12, minute: 2), burstId: "burst-1")

        // Input order is shuffled
        let groups = SimilarityClusterer.burstGroups([late, early, mid])
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].map(\.id), ["early", "mid", "late"])
    }

    func test_makeBurstCluster_buildsCluster() {
        let a = cand(id: "a", date: at(hour: 12, minute: 0), burstId: "burst-1")
        let b = cand(id: "b", date: at(hour: 12, minute: 0), pixelWidth: 4000, pixelHeight: 4000, burstId: "burst-1")
        let cluster = SimilarityClusterer.makeBurstCluster([a, b])
        XCTAssertEqual(cluster.candidates.count, 2)
        XCTAssertEqual(cluster.suggestedKeeperId, "b") // higher resolution wins
        XCTAssertTrue(cluster.suggestedKeeperReason.lowercased().contains("burst"))
    }

    func test_burstKeeperReason_favoriteWins() {
        let plain = cand(id: "plain", date: at(hour: 12, minute: 0), burstId: "b")
        let favorite = cand(id: "fav", date: at(hour: 12, minute: 0), isFavorite: true, burstId: "b")
        let reason = SimilarityClusterer.burstKeeperReason([plain, favorite], keeperId: "fav")
        XCTAssertTrue(reason.lowercased().contains("favorited"))
        XCTAssertTrue(reason.lowercased().contains("burst"))
    }

    // MARK: - Helpers

    private func cand(
        id: String,
        date: Date,
        pixelWidth: Int = 4000,
        pixelHeight: Int = 3000,
        estimatedFileSize: Int64 = 3_000_000,
        isFavorite: Bool = false,
        isHidden: Bool = false,
        isLivePhoto: Bool = false,
        hasBeenEdited: Bool = false,
        isInUserAlbum: Bool = false,
        burstId: String? = nil
    ) -> SimilarPhotoCandidate {
        SimilarPhotoCandidate(
            localIdentifier: id,
            creationDate: date,
            pixelWidth: pixelWidth,
            pixelHeight: pixelHeight,
            estimatedFileSize: estimatedFileSize,
            isFavorite: isFavorite,
            isHidden: isHidden,
            isLivePhoto: isLivePhoto,
            hasBeenEdited: hasBeenEdited,
            isInUserAlbum: isInUserAlbum,
            burstIdentifier: burstId
        )
    }

    private func at(hour: Int, minute: Int) -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 5
        components.day = 27
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components)!
    }
}
