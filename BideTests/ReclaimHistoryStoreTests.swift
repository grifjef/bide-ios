@testable import Bide
import SwiftData
import XCTest

@MainActor
final class ReclaimHistoryStoreTests: XCTestCase {
    private var container: ModelContainer!
    private var store: ReclaimHistoryStore!

    override func setUp() async throws {
        try await super.setUp()
        container = BideStore.makeInMemoryContainer()
        store = ReclaimHistoryStore(modelContext: container.mainContext)
    }

    override func tearDown() async throws {
        store = nil
        container = nil
        try await super.tearDown()
    }

    // MARK: - Empty

    func test_emptyStore_returnsZeroTotals() throws {
        XCTAssertEqual(try store.count(), 0)
        XCTAssertEqual(try store.lifetimeTotals(), .zero)
        XCTAssertTrue(try store.fetchAll().isEmpty)
    }

    // MARK: - Single session

    func test_record_insertsSession() throws {
        let session = try store.record(itemCount: 12, bytesReclaimed: 5_000_000)
        XCTAssertEqual(session.itemCount, 12)
        XCTAssertEqual(session.bytesReclaimed, 5_000_000)
        XCTAssertEqual(try store.count(), 1)
    }

    func test_lifetimeTotals_withOneSession_matchesThatSession() throws {
        let at = Date(timeIntervalSince1970: 1_700_000_000)
        try store.record(itemCount: 5, bytesReclaimed: 1_500_000, completedAt: at)
        let totals = try store.lifetimeTotals()
        XCTAssertEqual(totals.sessionCount, 1)
        XCTAssertEqual(totals.itemCount, 5)
        XCTAssertEqual(totals.bytes, 1_500_000)
        XCTAssertEqual(totals.firstSessionAt, at)
    }

    // MARK: - Multi-session aggregation

    func test_lifetimeTotals_aggregatesAcrossSessions() throws {
        try store.record(itemCount: 5, bytesReclaimed: 1_000_000, completedAt: Date(timeIntervalSince1970: 1_700_000_000))
        try store.record(itemCount: 7, bytesReclaimed: 2_000_000, completedAt: Date(timeIntervalSince1970: 1_700_000_010))
        try store.record(itemCount: 10, bytesReclaimed: 3_000_000, completedAt: Date(timeIntervalSince1970: 1_700_000_020))

        let totals = try store.lifetimeTotals()
        XCTAssertEqual(totals.sessionCount, 3)
        XCTAssertEqual(totals.itemCount, 22)
        XCTAssertEqual(totals.bytes, 6_000_000)
    }

    func test_lifetimeTotals_firstSessionIsOldest() throws {
        try store.record(itemCount: 1, bytesReclaimed: 100, completedAt: Date(timeIntervalSince1970: 1_700_000_500))
        try store.record(itemCount: 1, bytesReclaimed: 100, completedAt: Date(timeIntervalSince1970: 1_700_000_100))
        try store.record(itemCount: 1, bytesReclaimed: 100, completedAt: Date(timeIntervalSince1970: 1_700_000_300))

        let totals = try store.lifetimeTotals()
        XCTAssertEqual(totals.firstSessionAt, Date(timeIntervalSince1970: 1_700_000_100))
    }

    // MARK: - Ordering

    func test_fetchAll_returnsSessionsNewestFirst() throws {
        let early = try store.record(itemCount: 1, bytesReclaimed: 100, completedAt: Date(timeIntervalSince1970: 1_700_000_000))
        let mid = try store.record(itemCount: 2, bytesReclaimed: 200, completedAt: Date(timeIntervalSince1970: 1_700_000_500))
        let late = try store.record(itemCount: 3, bytesReclaimed: 300, completedAt: Date(timeIntervalSince1970: 1_700_001_000))

        let all = try store.fetchAll()
        XCTAssertEqual(all.count, 3)
        XCTAssertEqual(all[0].completedAt, late.completedAt)
        XCTAssertEqual(all[1].completedAt, mid.completedAt)
        XCTAssertEqual(all[2].completedAt, early.completedAt)
    }

    // MARK: - deleteAll

    func test_deleteAll_clearsHistoryAndResetsTotals() throws {
        try store.record(itemCount: 5, bytesReclaimed: 1_000_000)
        try store.record(itemCount: 7, bytesReclaimed: 2_000_000)
        XCTAssertEqual(try store.count(), 2)

        try store.deleteAll()
        XCTAssertEqual(try store.count(), 0)
        XCTAssertEqual(try store.lifetimeTotals(), .zero)
    }

    // MARK: - Formatting

    func test_lifetimeTotals_formattedBytesNonEmpty() throws {
        try store.record(itemCount: 1, bytesReclaimed: 1_500_000_000)
        let totals = try store.lifetimeTotals()
        XCTAssertFalse(totals.formattedBytes.isEmpty)
        XCTAssertTrue(totals.formattedBytes.contains("GB") || totals.formattedBytes.contains("MB"))
    }
}
