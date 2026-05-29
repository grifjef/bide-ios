@testable import Bide
import XCTest

/// Tests for the home-screen Quick Action enum. Pins the raw values that
/// iOS persists in `UIApplication.shared.shortcutItems`, so renames are
/// caught early — a stale shortcut on a user's springboard would stop
/// matching if we lost a raw value.
final class ShortcutActionTests: XCTestCase {
    func test_rawValuesAreStable() {
        XCTAssertEqual(ShortcutAction.findClutter.rawValue, "com.bidephoto.bide.shortcut.findClutter")
        XCTAssertEqual(ShortcutAction.onThisDay.rawValue, "com.bidephoto.bide.shortcut.onThisDay")
        XCTAssertEqual(ShortcutAction.reviewBasket.rawValue, "com.bidephoto.bide.shortcut.reviewBasket")
    }

    func test_rawValueRoundTrip() {
        let cases: [ShortcutAction] = [.findClutter, .onThisDay, .reviewBasket]
        for action in cases {
            XCTAssertEqual(ShortcutAction(rawValue: action.rawValue), action)
        }
    }

    func test_titlesAreNonEmpty() {
        XCTAssertFalse(ShortcutAction.findClutter.title.isEmpty)
        XCTAssertFalse(ShortcutAction.onThisDay.title.isEmpty)
        XCTAssertFalse(ShortcutAction.reviewBasket.title.isEmpty)
    }

    func test_unknownRawValueIsNil() {
        XCTAssertNil(ShortcutAction(rawValue: "com.bidephoto.bide.shortcut.notARealOne"))
    }

    func test_toShortcutItemPreservesType() {
        let item = ShortcutAction.findClutter.toShortcutItem()
        XCTAssertEqual(item.type, ShortcutAction.findClutter.rawValue)
        XCTAssertEqual(item.localizedTitle, ShortcutAction.findClutter.title)
    }
}
