@testable import Bide
import XCTest

/// Pure tests for the `StorageHealth.Snapshot` value type. The disk-read
/// path goes through `URLResourceValues`, which isn't testable without
/// real filesystem state — but the math + formatting on a snapshot is
/// trivially pinnable.
final class StorageHealthTests: XCTestCase {
    func test_usedBytesEqualsTotalMinusFree() {
        let snap = StorageHealth.Snapshot(
            freeBytes: 100_000_000_000,
            totalBytes: 256_000_000_000
        )
        XCTAssertEqual(snap.usedBytes, 156_000_000_000)
    }

    func test_usedBytesClampsToZeroIfFreeExceedsTotal() {
        // Defensive: iOS occasionally rounds available > total when
        // optimization shifts. The denominator should still be sane.
        let snap = StorageHealth.Snapshot(
            freeBytes: 300_000_000_000,
            totalBytes: 256_000_000_000
        )
        XCTAssertEqual(snap.usedBytes, 0)
    }

    func test_freeFractionWithKnownValues() {
        let snap = StorageHealth.Snapshot(
            freeBytes: 50_000_000_000,
            totalBytes: 200_000_000_000
        )
        XCTAssertEqual(snap.freeFraction, 0.25, accuracy: 0.0001)
    }

    func test_freeFractionIsZeroForZeroTotal() {
        let snap = StorageHealth.Snapshot(freeBytes: 0, totalBytes: 0)
        XCTAssertEqual(snap.freeFraction, 0)
    }

    func test_formattedBytesAreNonEmptyAndHuman() {
        let snap = StorageHealth.Snapshot(
            freeBytes: 100_000_000_000,
            totalBytes: 256_000_000_000
        )
        XCTAssertFalse(snap.formattedFree.isEmpty)
        XCTAssertFalse(snap.formattedTotal.isEmpty)
        // GB or TB tier expected for typical iPhone capacities.
        XCTAssertTrue(snap.formattedFree.contains("GB") || snap.formattedFree.contains("TB"))
        XCTAssertTrue(snap.formattedTotal.contains("GB") || snap.formattedTotal.contains("TB"))
    }
}
