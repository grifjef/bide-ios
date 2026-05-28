import XCTest
@testable import Bide

/// Pure tests for the background-refresh planner — no BGTaskScheduler,
/// no PhotoKit. Pins the "once per night" policy and the access-gated
/// scheduling behavior.
final class BackgroundRefreshSchedulerTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_700_000_000) // arbitrary fixed
    private let eightHours: TimeInterval = 8 * 60 * 60

    // MARK: - nextFireDate

    func test_noAccess_returnsNil() {
        XCTAssertNil(
            BackgroundRefreshScheduler.nextFireDate(
                lastSuccessAt: now.addingTimeInterval(-3600),
                now: now,
                hasReadAccess: false
            )
        )
    }

    func test_firstEver_schedulesImmediately() {
        let fire = BackgroundRefreshScheduler.nextFireDate(
            lastSuccessAt: nil,
            now: now,
            hasReadAccess: true
        )
        XCTAssertEqual(fire, now)
    }

    func test_recentSuccess_pushesFireToEarliestAllowed() {
        let lastSuccess = now.addingTimeInterval(-3600) // one hour ago
        let fire = BackgroundRefreshScheduler.nextFireDate(
            lastSuccessAt: lastSuccess,
            now: now,
            hasReadAccess: true
        )
        // Earliest is lastSuccess + 8h. That's 7h in the future from now.
        XCTAssertEqual(fire, lastSuccess.addingTimeInterval(eightHours))
    }

    func test_staleSuccess_schedulesForNow() {
        let lastSuccess = now.addingTimeInterval(-eightHours * 2)
        let fire = BackgroundRefreshScheduler.nextFireDate(
            lastSuccessAt: lastSuccess,
            now: now,
            hasReadAccess: true
        )
        // The earliest by minimum-interval is 8h ago. max(now, that) = now.
        XCTAssertEqual(fire, now)
    }

    func test_successExactlyEightHoursAgo_schedulesForNow() {
        let lastSuccess = now.addingTimeInterval(-eightHours)
        let fire = BackgroundRefreshScheduler.nextFireDate(
            lastSuccessAt: lastSuccess,
            now: now,
            hasReadAccess: true
        )
        XCTAssertEqual(fire, now)
    }

    // MARK: - shouldRunNow

    func test_shouldRunNow_noAccess_isFalse() {
        XCTAssertFalse(
            BackgroundRefreshScheduler.shouldRunNow(
                lastSuccessAt: nil,
                now: now,
                hasReadAccess: false
            )
        )
    }

    func test_shouldRunNow_noPriorRun_isTrue() {
        XCTAssertTrue(
            BackgroundRefreshScheduler.shouldRunNow(
                lastSuccessAt: nil,
                now: now,
                hasReadAccess: true
            )
        )
    }

    func test_shouldRunNow_recentRun_isFalse() {
        XCTAssertFalse(
            BackgroundRefreshScheduler.shouldRunNow(
                lastSuccessAt: now.addingTimeInterval(-3600),
                now: now,
                hasReadAccess: true
            )
        )
    }

    func test_shouldRunNow_eightHourBoundaryIsTrue() {
        // Boundary is inclusive — at exactly 8h, the policy says run.
        XCTAssertTrue(
            BackgroundRefreshScheduler.shouldRunNow(
                lastSuccessAt: now.addingTimeInterval(-eightHours),
                now: now,
                hasReadAccess: true
            )
        )
    }

    func test_shouldRunNow_oneSecondShortOfBoundary_isFalse() {
        XCTAssertFalse(
            BackgroundRefreshScheduler.shouldRunNow(
                lastSuccessAt: now.addingTimeInterval(-(eightHours - 1)),
                now: now,
                hasReadAccess: true
            )
        )
    }

    func test_shouldRunNow_wellPastBoundary_isTrue() {
        XCTAssertTrue(
            BackgroundRefreshScheduler.shouldRunNow(
                lastSuccessAt: now.addingTimeInterval(-86_400),
                now: now,
                hasReadAccess: true
            )
        )
    }

    // MARK: - Constants

    func test_minimumIntervalIsEightHours() {
        XCTAssertEqual(BackgroundRefreshScheduler.minimumIntervalSeconds, eightHours)
    }
}
