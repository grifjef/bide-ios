import XCTest
import SwiftData
@testable import Bide

/// Tests for `IndexedAssetStore` using the Vision-agnostic `Data`-based API.
/// We use synthetic 32-byte payloads as stand-ins for real feature prints; the
/// store doesn't care about the payload format, only that it pairs with a
/// version for staleness checks. The Vision serialization round-trip itself
/// is tested separately on-device.
@MainActor
final class IndexedAssetStoreTests: XCTestCase {

    private var container: ModelContainer!
    private var store: IndexedAssetStore!

    override func setUp() async throws {
        try await super.setUp()
        container = BideStore.makeInMemoryContainer()
        store = IndexedAssetStore(modelContext: container.mainContext)
    }

    override func tearDown() async throws {
        store = nil
        container = nil
        try await super.tearDown()
    }

    // MARK: - Fetch / count

    func test_emptyStoreHasZeroCount() throws {
        XCTAssertEqual(try store.count(), 0)
        XCTAssertNil(try store.fetch(localIdentifier: "nope"))
    }

    func test_fetchAll_returnsAllEntries() throws {
        try store.upsertFeaturePrint(for: candidate(id: "a"), featurePrintData: payload("a"), version: 1)
        try store.upsertFeaturePrint(for: candidate(id: "b"), featurePrintData: payload("b"), version: 1)

        let all = try store.fetchAll()
        XCTAssertEqual(all.count, 2)
        XCTAssertEqual(Set(all.map(\.localIdentifier)), Set(["a", "b"]))
    }

    // MARK: - Upsert

    func test_upsert_insertsNewEntry() throws {
        let result = try store.upsertFeaturePrint(
            for: candidate(id: "new"),
            featurePrintData: payload("new"),
            version: 1
        )
        XCTAssertEqual(result.localIdentifier, "new")
        XCTAssertEqual(result.featurePrintVersion, 1)
        XCTAssertEqual(result.featurePrintData, payload("new"))
        XCTAssertEqual(try store.count(), 1)
    }

    func test_upsert_updatesExistingEntry() throws {
        try store.upsertFeaturePrint(
            for: candidate(id: "existing", isFavorite: false),
            featurePrintData: payload("v1"),
            version: 1
        )
        XCTAssertEqual(try store.count(), 1)

        // Now the candidate flips to favorited and we re-upsert with a new version
        try store.upsertFeaturePrint(
            for: candidate(id: "existing", isFavorite: true),
            featurePrintData: payload("v2"),
            version: 2
        )

        XCTAssertEqual(try store.count(), 1) // upsert, not insert
        let fetched = try store.fetch(localIdentifier: "existing")
        XCTAssertNotNil(fetched)
        XCTAssertTrue(fetched!.isFavorite)
        XCTAssertEqual(fetched!.featurePrintVersion, 2)
        XCTAssertEqual(fetched!.featurePrintData, payload("v2"))
    }

    // MARK: - storedFeaturePrintData

    func test_storedData_returnsBytesWhenVersionMatches() throws {
        try store.upsertFeaturePrint(
            for: candidate(id: "a"),
            featurePrintData: payload("a"),
            version: 5
        )
        XCTAssertEqual(try store.storedFeaturePrintData(for: "a", requiredVersion: 5), payload("a"))
    }

    func test_storedData_returnsNilWhenVersionMismatch() throws {
        try store.upsertFeaturePrint(
            for: candidate(id: "a"),
            featurePrintData: payload("a"),
            version: 5
        )
        XCTAssertNil(try store.storedFeaturePrintData(for: "a", requiredVersion: 6))
        XCTAssertNil(try store.storedFeaturePrintData(for: "a", requiredVersion: 4))
    }

    func test_storedData_returnsNilForUnknownIdentifier() throws {
        XCTAssertNil(try store.storedFeaturePrintData(for: "ghost", requiredVersion: 1))
    }

    // MARK: - Reconciliation

    func test_reconcile_dropsAbsentEntries() throws {
        try store.upsertFeaturePrint(for: candidate(id: "kept"), featurePrintData: payload("k"), version: 1)
        try store.upsertFeaturePrint(for: candidate(id: "removed"), featurePrintData: payload("r"), version: 1)

        let dropped = try store.reconcile(against: Set(["kept"]))
        XCTAssertEqual(dropped, 1)
        XCTAssertEqual(try store.count(), 1)
        XCTAssertNil(try store.fetch(localIdentifier: "removed"))
        XCTAssertNotNil(try store.fetch(localIdentifier: "kept"))
    }

    func test_reconcile_keepsAllWhenSetMatches() throws {
        try store.upsertFeaturePrint(for: candidate(id: "a"), featurePrintData: payload("a"), version: 1)
        let dropped = try store.reconcile(against: Set(["a"]))
        XCTAssertEqual(dropped, 0)
        XCTAssertEqual(try store.count(), 1)
    }

    func test_reconcile_emptySetDropsEverything() throws {
        try store.upsertFeaturePrint(for: candidate(id: "a"), featurePrintData: payload("a"), version: 1)
        try store.upsertFeaturePrint(for: candidate(id: "b"), featurePrintData: payload("b"), version: 1)

        let dropped = try store.reconcile(against: Set<String>())
        XCTAssertEqual(dropped, 2)
        XCTAssertEqual(try store.count(), 0)
    }

    // MARK: - deleteAll

    func test_deleteAll_clearsStore() throws {
        try store.upsertFeaturePrint(for: candidate(id: "a"), featurePrintData: payload("a"), version: 1)
        XCTAssertEqual(try store.count(), 1)

        try store.deleteAll()
        XCTAssertEqual(try store.count(), 0)
    }

    // MARK: - FeaturePrintCoder (decode only — no Vision needed)

    func test_featurePrintCoder_decodeReturnsNilForGarbage() {
        let garbage = Data([0x00, 0x01, 0x02, 0x03, 0x04])
        XCTAssertNil(FeaturePrintCoder.decode(garbage))
    }

    func test_featurePrintCoder_decodeReturnsNilForEmpty() {
        XCTAssertNil(FeaturePrintCoder.decode(Data()))
    }

    // MARK: - Helpers

    private func candidate(
        id: String,
        date: Date = Date(),
        pixelWidth: Int = 4000,
        pixelHeight: Int = 3000,
        isFavorite: Bool = false,
        isHidden: Bool = false
    ) -> SimilarPhotoCandidate {
        SimilarPhotoCandidate(
            localIdentifier: id,
            creationDate: date,
            pixelWidth: pixelWidth,
            pixelHeight: pixelHeight,
            estimatedFileSize: 3_000_000,
            isFavorite: isFavorite,
            isHidden: isHidden,
            isLivePhoto: false,
            hasBeenEdited: false,
            isInUserAlbum: false,
            burstIdentifier: nil
        )
    }

    /// Synthetic feature-print payload — the store treats it as opaque bytes,
    /// so any deterministic Data works for testing the storage layer.
    private func payload(_ marker: String) -> Data {
        Data(marker.utf8) + Data(repeating: 0xAB, count: 32)
    }
}
