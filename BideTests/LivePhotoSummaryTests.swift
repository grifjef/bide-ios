import XCTest
@testable import Bide

/// Tests the pure derived properties on `LivePhotoSummary` that drive the
/// "Convert to still" UI copy and accessibility labels. We can't run the
/// PhotoKit-backed conversion in tests, but we can pin down the math the UI
/// shows the user.
final class LivePhotoSummaryTests: XCTestCase {

    private func make(
        fileSize: Int64,
        pairedVideoSize: Int64,
        isFavorite: Bool = false,
        isHidden: Bool = false
    ) -> LivePhotoSummary {
        LivePhotoSummary(
            localIdentifier: "test",
            creationDate: Date(timeIntervalSince1970: 1_700_000_000),
            pixelWidth: 4032,
            pixelHeight: 3024,
            fileSize: fileSize,
            pairedVideoSize: pairedVideoSize,
            isFavorite: isFavorite,
            isHidden: isHidden
        )
    }

    // MARK: - estimatedVideoSidecarBytes

    func test_usesRealPairedVideoBytesWhenAvailable() {
        let summary = make(fileSize: 5_000_000, pairedVideoSize: 1_800_000)
        XCTAssertEqual(summary.estimatedVideoSidecarBytes, 1_800_000)
    }

    func test_fallsBackTo40PercentWhenPairedVideoUnknown() {
        let summary = make(fileSize: 5_000_000, pairedVideoSize: 0)
        // 40% of 5MB = 2MB
        XCTAssertEqual(summary.estimatedVideoSidecarBytes, 2_000_000)
    }

    func test_zeroPairedVideoBytesIsTreatedAsUnknown() {
        // A real-world iCloud-not-downloaded Live Photo can return 0 for both.
        // We default to 40% of fileSize regardless of whether fileSize is also
        // small — the UI then shows e.g. "0 bytes" which is honest.
        let summary = make(fileSize: 0, pairedVideoSize: 0)
        XCTAssertEqual(summary.estimatedVideoSidecarBytes, 0)
    }

    func test_largeLivePhotoSidecarEstimate() {
        // A 4K Live Photo can be ~10MB with a ~4MB sidecar.
        let summary = make(fileSize: 10_000_000, pairedVideoSize: 4_200_000)
        XCTAssertEqual(summary.estimatedVideoSidecarBytes, 4_200_000)
    }

    // MARK: - Protection rules

    func test_favoriteIsProtected() {
        let summary = make(fileSize: 1_000_000, pairedVideoSize: 400_000, isFavorite: true)
        XCTAssertTrue(summary.isProtected)
    }

    func test_hiddenIsProtected() {
        let summary = make(fileSize: 1_000_000, pairedVideoSize: 400_000, isHidden: true)
        XCTAssertTrue(summary.isProtected)
    }

    func test_normalLivePhotoIsNotProtected() {
        let summary = make(fileSize: 1_000_000, pairedVideoSize: 400_000)
        XCTAssertFalse(summary.isProtected)
    }

    // MARK: - Formatting

    func test_formattedPairedVideoSizeIsHumanReadable() {
        let summary = make(fileSize: 5_000_000, pairedVideoSize: 1_800_000)
        // ByteCountFormatter on macOS/iOS renders this as e.g. "1.8 MB".
        // We don't pin the exact string (locale-sensitive) — just that it's
        // non-empty and not the raw byte count.
        let formatted = summary.formattedPairedVideoSize
        XCTAssertFalse(formatted.isEmpty)
        XCTAssertFalse(formatted.contains("1800000"))
    }

    func test_formattedDateRespectsAbsentCreationDate() {
        let summary = LivePhotoSummary(
            localIdentifier: "no-date",
            creationDate: nil,
            pixelWidth: 4032,
            pixelHeight: 3024,
            fileSize: 1_000_000,
            pairedVideoSize: 400_000,
            isFavorite: false,
            isHidden: false
        )
        XCTAssertEqual(summary.formattedDate, "")
    }
}
