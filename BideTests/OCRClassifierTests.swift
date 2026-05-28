@testable import Bide
import SwiftData
import XCTest

/// Tests for the pure character-count → category mapping and the round-trip
/// through `IndexedAssetStore`. We don't invoke Vision here — same Espresso
/// constraint as the IndexedAssetStore tests.
final class OCRClassifierTests: XCTestCase {
    // MARK: - Pure classification

    func test_zeroCharsIsVisual() {
        XCTAssertEqual(OCRClassifier.classify(textCharacterCount: 0), .visual)
    }

    func test_justBelowVisualBoundaryIsVisual() {
        XCTAssertEqual(
            OCRClassifier.classify(textCharacterCount: OCRClassifier.visualMaxChars - 1),
            .visual
        )
    }

    func test_atVisualBoundaryIsMixed() {
        XCTAssertEqual(
            OCRClassifier.classify(textCharacterCount: OCRClassifier.visualMaxChars),
            .mixed
        )
    }

    func test_justBelowMixedBoundaryIsMixed() {
        XCTAssertEqual(
            OCRClassifier.classify(textCharacterCount: OCRClassifier.mixedMaxChars - 1),
            .mixed
        )
    }

    func test_atMixedBoundaryIsTextHeavy() {
        XCTAssertEqual(
            OCRClassifier.classify(textCharacterCount: OCRClassifier.mixedMaxChars),
            .textHeavy
        )
    }

    func test_largeCountIsTextHeavy() {
        XCTAssertEqual(OCRClassifier.classify(textCharacterCount: 10_000), .textHeavy)
    }

    // MARK: - Category metadata

    func test_displayNamesAreNonEmpty() {
        for category in ScreenshotCategory.allCases {
            XCTAssertFalse(category.displayName.isEmpty)
            XCTAssertFalse(category.iconName.isEmpty)
            XCTAssertFalse(category.explanation.isEmpty)
        }
    }

    func test_categoryRawValueRoundTrip() {
        for category in ScreenshotCategory.allCases {
            let restored = ScreenshotCategory(rawValue: category.rawValue)
            XCTAssertEqual(restored, category)
        }
    }

    // MARK: - Store round-trip

    @MainActor
    func test_upsertScreenshotCategory_insertsAndReadsBack() async throws {
        let container = BideStore.makeInMemoryContainer()
        let store = IndexedAssetStore(modelContext: container.mainContext)

        try store.upsertScreenshotCategory(
            localIdentifier: "shot-1",
            textCharacterCount: 400,
            category: .textHeavy
        )

        let read = try store.storedScreenshotCategory(for: "shot-1")
        XCTAssertEqual(read, .textHeavy)
    }

    @MainActor
    func test_upsertScreenshotCategory_updatesExistingRow() async throws {
        let container = BideStore.makeInMemoryContainer()
        let store = IndexedAssetStore(modelContext: container.mainContext)

        try store.upsertScreenshotCategory(
            localIdentifier: "shot-1",
            textCharacterCount: 10,
            category: .visual
        )
        try store.upsertScreenshotCategory(
            localIdentifier: "shot-1",
            textCharacterCount: 400,
            category: .textHeavy
        )

        XCTAssertEqual(try store.count(), 1)
        XCTAssertEqual(try store.storedScreenshotCategory(for: "shot-1"), .textHeavy)
    }

    @MainActor
    func test_storedScreenshotCategory_returnsNilForUnknown() async throws {
        let container = BideStore.makeInMemoryContainer()
        let store = IndexedAssetStore(modelContext: container.mainContext)
        XCTAssertNil(try store.storedScreenshotCategory(for: "nothing-here"))
    }
}
