@testable import Bide
import XCTest

/// Performance + memory benchmarks for the pure scan algorithms against a
/// synthetic 10k-candidate library. These guard against accidental
/// O(n²) regressions in the hot paths and give a memory baseline.
///
/// `measure` blocks record wall-clock by default; the memory tests add
/// `XCTMemoryMetric`. Baselines aren't pinned in CI (machine-dependent) —
/// these run as smoke + local-comparison benchmarks. They also serve as
/// correctness checks at scale: a 10k run that crashes or hangs fails
/// loudly.
final class ScanPerformanceTests: XCTestCase {
    private static let largeCount = 10_000

    // MARK: - Exact duplicates

    func test_exactDuplicateDetection_10k_performance() {
        let candidates = SyntheticLibrary.candidates(count: Self.largeCount)
        measure {
            _ = ExactDuplicateDetector.detect(candidates)
        }
    }

    func test_exactDuplicateDetection_10k_memory() {
        let candidates = SyntheticLibrary.candidates(count: Self.largeCount)
        measure(metrics: [XCTMemoryMetric()]) {
            _ = ExactDuplicateDetector.detect(candidates)
        }
    }

    func test_exactDuplicateDetection_10k_findsExpectedGroups() {
        // Correctness-at-scale: with duplicateFraction 0.15 we expect a
        // meaningful number of groups, and the run must complete.
        let candidates = SyntheticLibrary.candidates(count: Self.largeCount)
        let groups = ExactDuplicateDetector.detect(candidates)
        XCTAssertFalse(groups.isEmpty, "synthetic library should produce duplicate groups")
    }

    // MARK: - Similar-photo clustering (pure pipeline, stub distance)

    func test_similarityClustering_10k_performance() {
        let candidates = SyntheticLibrary.candidates(count: Self.largeCount)
        // Stub feature print + distance: identity-by-resolution so the
        // union-find + time-bucketing run at full scale without Vision.
        measure {
            _ = SimilarityClusterer.cluster(
                candidates,
                featurePrint: { _ in NSObject() },
                distance: { _, _ in 5.0 } // below threshold → clusters form
            )
        }
    }

    func test_timeBucketing_10k_performance() {
        let candidates = SyntheticLibrary.candidates(count: Self.largeCount)
        measure {
            _ = SimilarityClusterer.timeBuckets(candidates, date: { $0.creationDate })
        }
    }

    // MARK: - Burst grouping

    func test_burstGrouping_10k_performance() {
        let candidates = SyntheticLibrary.candidates(count: Self.largeCount)
        measure {
            _ = SimilarityClusterer.burstGroups(candidates)
        }
    }

    // MARK: - On This Day matching

    func test_onThisDayMatching_10k_performance() {
        let candidates = SyntheticLibrary.candidates(count: Self.largeCount)
        let target = Date(timeIntervalSince1970: 1_700_000_000)
        measure {
            _ = OnThisDayMatcher.groupsForToday(candidates: candidates, targetDate: target)
        }
    }
}
