import XCTest
@testable import Bide

/// Pure tests for `RecencyRule.isRecent` — the shared <30d helper used by
/// the soft "Recent capture" badge in Large Videos, Screen Recordings, and
/// Live Photos. Boundary tests pin the inclusive/exclusive ends so a future
/// off-by-one doesn't quietly mark a 31-day-old asset as recent.
final class RecencyRuleTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_700_000_000) // arbitrary fixed instant

    func test_nilDateIsNotRecent() {
        XCTAssertFalse(RecencyRule.isRecent(nil, now: now))
    }

    func test_capturedJustNowIsRecent() {
        let date = now.addingTimeInterval(-1)
        XCTAssertTrue(RecencyRule.isRecent(date, now: now))
    }

    func test_capturedOneDayAgoIsRecent() {
        let date = now.addingTimeInterval(-86_400)
        XCTAssertTrue(RecencyRule.isRecent(date, now: now))
    }

    func test_capturedTwentyNineDaysAgoIsRecent() {
        let date = now.addingTimeInterval(-86_400 * 29)
        XCTAssertTrue(RecencyRule.isRecent(date, now: now))
    }

    func test_capturedExactly30DaysAgoIsNotRecent() {
        // 30 days is the *exclusive* upper bound — anything older than that
        // sheds the "recent" tag. Matches the Screenshots/Blurry hard rule.
        let date = now.addingTimeInterval(-86_400 * 30)
        XCTAssertFalse(RecencyRule.isRecent(date, now: now))
    }

    func test_capturedFortyDaysAgoIsNotRecent() {
        let date = now.addingTimeInterval(-86_400 * 40)
        XCTAssertFalse(RecencyRule.isRecent(date, now: now))
    }

    func test_futureDateIsNotRecent() {
        // Photo with creation date in the future (clock skew, time zone bug)
        // is not "recent" — we shouldn't promote it just because the math is
        // ambiguous.
        let date = now.addingTimeInterval(86_400)
        XCTAssertFalse(RecencyRule.isRecent(date, now: now))
    }

    func test_customWindowRespectsConfiguredDays() {
        let date = now.addingTimeInterval(-86_400 * 8)
        XCTAssertTrue(RecencyRule.isRecent(date, now: now, days: 14))
        XCTAssertFalse(RecencyRule.isRecent(date, now: now, days: 7))
    }

    // MARK: - Summary integration

    func test_largeVideoSummary_recentCaptureUsesRecencyRule() {
        let recent = LargeVideoSummary(
            localIdentifier: "v1",
            creationDate: now.addingTimeInterval(-86_400 * 5),
            duration: 60,
            pixelWidth: 1920,
            pixelHeight: 1080,
            fileSize: 500_000_000,
            isFavorite: false,
            isHidden: false,
            sourceTypeIsCamera: true,
            isScreenRecording: false
        )
        let old = LargeVideoSummary(
            localIdentifier: "v2",
            creationDate: now.addingTimeInterval(-86_400 * 365),
            duration: 60,
            pixelWidth: 1920,
            pixelHeight: 1080,
            fileSize: 500_000_000,
            isFavorite: false,
            isHidden: false,
            sourceTypeIsCamera: true,
            isScreenRecording: false
        )
        XCTAssertTrue(recent.isRecentCapture(now: now))
        XCTAssertFalse(old.isRecentCapture(now: now))
    }

    func test_livePhotoSummary_recentCaptureUsesRecencyRule() {
        let recent = LivePhotoSummary(
            localIdentifier: "lp1",
            creationDate: now.addingTimeInterval(-86_400 * 2),
            pixelWidth: 4032,
            pixelHeight: 3024,
            fileSize: 5_000_000,
            pairedVideoSize: 2_000_000,
            isFavorite: false,
            isHidden: false
        )
        let old = LivePhotoSummary(
            localIdentifier: "lp2",
            creationDate: now.addingTimeInterval(-86_400 * 90),
            pixelWidth: 4032,
            pixelHeight: 3024,
            fileSize: 5_000_000,
            pairedVideoSize: 2_000_000,
            isFavorite: false,
            isHidden: false
        )
        XCTAssertTrue(recent.isRecentCapture(now: now))
        XCTAssertFalse(old.isRecentCapture(now: now))
    }
}
