import XCTest
@testable import Bide

/// Pure unit tests for the dashboard's refresh-coalescing state machine.
/// Lives at file scope (no PhotoKit, no MainActor) so the tests run in
/// the Espresso-free simulator runner without issues.
final class RefreshCoalescerTests: XCTestCase {

    // MARK: - Cold-start

    func test_initialState_isIdleAndClean() {
        let c = RefreshCoalescer()
        XCTAssertFalse(c.isRefreshing)
        XCTAssertFalse(c.dirty)
    }

    // MARK: - Programmatic refresh path

    func test_tryBeginRefresh_succeedsFromIdle() {
        var c = RefreshCoalescer()
        XCTAssertTrue(c.tryBeginRefresh())
        XCTAssertTrue(c.isRefreshing)
    }

    func test_tryBeginRefresh_returnsFalseWhenAlreadyRefreshing() {
        var c = RefreshCoalescer()
        _ = c.tryBeginRefresh()
        XCTAssertFalse(c.tryBeginRefresh())
    }

    func test_completeRefresh_returnsDoneWhenClean() {
        var c = RefreshCoalescer()
        _ = c.tryBeginRefresh()
        XCTAssertEqual(c.completeRefresh(), .done)
        XCTAssertFalse(c.isRefreshing)
        XCTAssertFalse(c.dirty)
    }

    // MARK: - Library-change debounce path

    func test_debouncedChange_fromIdle_startsRefresh() {
        var c = RefreshCoalescer()
        XCTAssertEqual(c.processDebouncedChange(), .startRefresh)
        XCTAssertTrue(c.isRefreshing)
        XCTAssertFalse(c.dirty)
    }

    func test_debouncedChange_whileRefreshing_setsDirty() {
        var c = RefreshCoalescer()
        _ = c.tryBeginRefresh()
        XCTAssertEqual(c.processDebouncedChange(), .noop)
        XCTAssertTrue(c.isRefreshing)
        XCTAssertTrue(c.dirty)
    }

    // MARK: - Mid-refresh change → follow-up

    func test_changeMidRefresh_followupIsTriggeredOnComplete() {
        var c = RefreshCoalescer()
        _ = c.tryBeginRefresh()
        // Library change arrives mid-flight.
        _ = c.processDebouncedChange()
        XCTAssertEqual(c.completeRefresh(), .startFollowupRefresh)
        // After signalling follow-up, the coalescer remains in the
        // refreshing state so a concurrent debounce tick can't double-start.
        XCTAssertTrue(c.isRefreshing)
        XCTAssertFalse(c.dirty)
    }

    func test_followupRefresh_canItselfReceiveAnotherChange() {
        var c = RefreshCoalescer()
        _ = c.tryBeginRefresh()
        _ = c.processDebouncedChange()             // arrived during 1st refresh
        XCTAssertEqual(c.completeRefresh(), .startFollowupRefresh)
        _ = c.processDebouncedChange()             // arrived during 2nd refresh
        XCTAssertEqual(c.completeRefresh(), .startFollowupRefresh)
        // Now drain.
        XCTAssertEqual(c.completeRefresh(), .done)
        XCTAssertFalse(c.isRefreshing)
    }

    // MARK: - Multiple changes coalesce

    func test_manyDebouncedChangesWhileRefreshing_collapseToOneDirty() {
        var c = RefreshCoalescer()
        _ = c.tryBeginRefresh()
        for _ in 0..<10 {
            XCTAssertEqual(c.processDebouncedChange(), .noop)
        }
        // Ten changes ≡ one dirty flag ≡ exactly one follow-up.
        XCTAssertEqual(c.completeRefresh(), .startFollowupRefresh)
        XCTAssertEqual(c.completeRefresh(), .done)
    }

    func test_changeAfterCompletionStartsFreshRefresh() {
        var c = RefreshCoalescer()
        _ = c.tryBeginRefresh()
        XCTAssertEqual(c.completeRefresh(), .done)
        // Idle again — next change starts a refresh outright.
        XCTAssertEqual(c.processDebouncedChange(), .startRefresh)
    }

    // MARK: - Reset

    func test_reset_returnsToIdle() {
        var c = RefreshCoalescer()
        _ = c.tryBeginRefresh()
        _ = c.processDebouncedChange()
        c.reset()
        XCTAssertFalse(c.isRefreshing)
        XCTAssertFalse(c.dirty)
    }
}
