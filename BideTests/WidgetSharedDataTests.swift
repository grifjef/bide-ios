@testable import Bide
import XCTest

/// Tests for the widget's shared data layer. `WidgetSharedData` + the
/// round-trip through `WidgetSharedStore` are pure value logic — the
/// App Group fallback means the store works against `.standard` in the
/// test runner without any group provisioning.
final class WidgetSharedDataTests: XCTestCase {
    override func setUp() {
        super.setUp()
        // Start each test from a clean slate. The store uses the App Group
        // suite (which genuinely works in the sim), so clearing must go
        // through the store, not UserDefaults.standard.
        WidgetSharedStore.clear()
    }

    override func tearDown() {
        WidgetSharedStore.clear()
        super.tearDown()
    }

    func test_emptyHasZeroedFields() {
        let empty = WidgetSharedData.empty
        XCTAssertEqual(empty.lifetimeBytes, 0)
        XCTAssertEqual(empty.sessionCount, 0)
        XCTAssertEqual(empty.itemCount, 0)
        XCTAssertNil(empty.lastSessionAt)
    }

    func test_formattedLifetimeBytesIsHuman() {
        let data = WidgetSharedData(lifetimeBytes: 4_600_000_000)
        let formatted = data.formattedLifetimeBytes
        XCTAssertFalse(formatted.isEmpty)
        XCTAssertTrue(formatted.contains("GB") || formatted.contains("TB"))
    }

    func test_codableRoundTrip() throws {
        let original = WidgetSharedData(
            lifetimeBytes: 12_345_678,
            sessionCount: 7,
            itemCount: 89,
            lastSessionAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(WidgetSharedData.self, from: encoded)
        XCTAssertEqual(decoded, original)
    }

    func test_storeWriteThenReadReturnsSameValue() {
        let data = WidgetSharedData(
            lifetimeBytes: 999_000_000,
            sessionCount: 3,
            itemCount: 41,
            lastSessionAt: Date(timeIntervalSince1970: 1_650_000_000)
        )
        WidgetSharedStore.write(data)
        let readBack = WidgetSharedStore.read()
        XCTAssertEqual(readBack, data)
    }

    func test_storeReadReturnsEmptyWhenNothingWritten() {
        WidgetSharedStore.clear()
        XCTAssertEqual(WidgetSharedStore.read(), .empty)
    }

    func test_clearRemovesWrittenData() {
        WidgetSharedStore.write(WidgetSharedData(lifetimeBytes: 123, sessionCount: 1))
        WidgetSharedStore.clear()
        XCTAssertEqual(WidgetSharedStore.read(), .empty)
    }

    func test_appGroupIdentifierIsStable() {
        XCTAssertEqual(WidgetSharedStore.appGroupID, "group.com.bidephoto.bide")
    }
}
