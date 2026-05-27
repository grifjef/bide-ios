import XCTest
@testable import Bide

final class PhotoLibraryEstimatorTests: XCTestCase {

    // MARK: - estimatedVideoBytes

    func test_estimate_4kVideoHas4KTier() {
        // 3840×2160 = 8.3 Mpx → 4K tier (6 MB/s)
        let bytes = PhotoLibraryService.estimatedVideoBytes(
            pixelWidth: 3840,
            pixelHeight: 2160,
            duration: 10
        )
        XCTAssertEqual(bytes, 60_000_000) // 10s × 6 MB/s
    }

    func test_estimate_1080pVideoHas1080pTier() {
        // 1920×1080 = 2.07 Mpx → 1080p tier (1.5 MB/s)
        let bytes = PhotoLibraryService.estimatedVideoBytes(
            pixelWidth: 1920,
            pixelHeight: 1080,
            duration: 60
        )
        XCTAssertEqual(bytes, 90_000_000) // 60s × 1.5 MB/s
    }

    func test_estimate_720pVideoHasLowTier() {
        // 1280×720 = 0.92 Mpx → 720p-or-lower tier (0.6 MB/s)
        let bytes = PhotoLibraryService.estimatedVideoBytes(
            pixelWidth: 1280,
            pixelHeight: 720,
            duration: 30
        )
        XCTAssertEqual(bytes, 18_000_000) // 30s × 0.6 MB/s
    }

    func test_estimate_zeroDurationIsZero() {
        let bytes = PhotoLibraryService.estimatedVideoBytes(
            pixelWidth: 1920,
            pixelHeight: 1080,
            duration: 0
        )
        XCTAssertEqual(bytes, 0)
    }

    func test_estimate_negativeDurationIsZero() {
        let bytes = PhotoLibraryService.estimatedVideoBytes(
            pixelWidth: 1920,
            pixelHeight: 1080,
            duration: -5
        )
        XCTAssertEqual(bytes, 0)
    }

    func test_estimate_zeroDimensionsAreZero() {
        XCTAssertEqual(
            PhotoLibraryService.estimatedVideoBytes(pixelWidth: 0, pixelHeight: 1080, duration: 60),
            0
        )
        XCTAssertEqual(
            PhotoLibraryService.estimatedVideoBytes(pixelWidth: 1920, pixelHeight: 0, duration: 60),
            0
        )
    }

    func test_estimate_orderingPreserved() {
        // Longer 1080p video > shorter 4K video at sensible bounds:
        // a 4K video at 1 second ≈ 6 MB vs a 1080p video at 60 seconds ≈ 90 MB
        let short4k = PhotoLibraryService.estimatedVideoBytes(
            pixelWidth: 3840, pixelHeight: 2160, duration: 1
        )
        let long1080p = PhotoLibraryService.estimatedVideoBytes(
            pixelWidth: 1920, pixelHeight: 1080, duration: 60
        )
        XCTAssertGreaterThan(long1080p, short4k)
    }

    func test_estimate_tierBoundaryAt35Mpx() {
        // Right at the 4K threshold (3.5 Mpx). The "1080p-ish" tier should
        // be selected for anything strictly below — and the 4K tier at or above.
        let just4k = PhotoLibraryService.estimatedVideoBytes(
            pixelWidth: 2000, pixelHeight: 1750, duration: 1
        ) // 3.5 Mpx exactly → 4K tier
        XCTAssertEqual(just4k, 6_000_000)

        let just1080 = PhotoLibraryService.estimatedVideoBytes(
            pixelWidth: 2000, pixelHeight: 1749, duration: 1
        ) // 3.498 Mpx → 1080p tier
        XCTAssertEqual(just1080, 1_500_000)
    }
}
