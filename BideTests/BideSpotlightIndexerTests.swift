@testable import Bide
import XCTest

/// Tests for the Spotlight catalog. Pins the stable identifiers (renames
/// break Spotlight cache continuity), verifies the equivalentShortcut
/// mapping for the three modules already wired to the ShortcutAction
/// pipeline, and confirms every entry has non-empty copy.
final class BideSpotlightIndexerTests: XCTestCase {
    // MARK: - Module catalog

    func test_everyModuleHasNonEmptyTitleAndSummary() {
        for entry in ModuleSpotlight.allCases {
            XCTAssertFalse(entry.title.isEmpty, "title empty for \(entry.rawValue)")
            XCTAssertFalse(entry.summary.isEmpty, "summary empty for \(entry.rawValue)")
            XCTAssertFalse(entry.keywords.isEmpty, "keywords empty for \(entry.rawValue)")
        }
    }

    func test_moduleIdentifiersAreStable() {
        // Spotlight uses these as primary keys — a rename invalidates user
        // search history. Pin the raw values explicitly.
        XCTAssertEqual(ModuleSpotlight.findClutter.identifier, "com.bidephoto.bide.spotlight.module.findClutter")
        XCTAssertEqual(ModuleSpotlight.exactDuplicates.identifier, "com.bidephoto.bide.spotlight.module.exactDuplicates")
        XCTAssertEqual(ModuleSpotlight.screenRecordings.identifier, "com.bidephoto.bide.spotlight.module.screenRecordings")
        XCTAssertEqual(ModuleSpotlight.largeVideos.identifier, "com.bidephoto.bide.spotlight.module.largeVideos")
        XCTAssertEqual(ModuleSpotlight.screenshots.identifier, "com.bidephoto.bide.spotlight.module.screenshots")
        XCTAssertEqual(ModuleSpotlight.livePhotos.identifier, "com.bidephoto.bide.spotlight.module.livePhotos")
        XCTAssertEqual(ModuleSpotlight.similarPhotos.identifier, "com.bidephoto.bide.spotlight.module.similarPhotos")
        XCTAssertEqual(ModuleSpotlight.blurryShots.identifier, "com.bidephoto.bide.spotlight.module.blurryShots")
        XCTAssertEqual(ModuleSpotlight.onThisDay.identifier, "com.bidephoto.bide.spotlight.module.onThisDay")
        XCTAssertEqual(ModuleSpotlight.reviewBasket.identifier, "com.bidephoto.bide.spotlight.module.reviewBasket")
    }

    func test_moduleIdentifiersAreUnique() {
        let ids = ModuleSpotlight.allCases.map(\.identifier)
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    // MARK: - Shortcut mapping

    func test_findClutterMapsToShortcut() {
        XCTAssertEqual(ModuleSpotlight.findClutter.equivalentShortcut, .findClutter)
    }

    func test_onThisDayMapsToShortcut() {
        XCTAssertEqual(ModuleSpotlight.onThisDay.equivalentShortcut, .onThisDay)
    }

    func test_reviewBasketMapsToShortcut() {
        XCTAssertEqual(ModuleSpotlight.reviewBasket.equivalentShortcut, .reviewBasket)
    }

    func test_modulesWithoutDeepLinkReturnNilShortcut() {
        XCTAssertNil(ModuleSpotlight.exactDuplicates.equivalentShortcut)
        XCTAssertNil(ModuleSpotlight.screenRecordings.equivalentShortcut)
        XCTAssertNil(ModuleSpotlight.largeVideos.equivalentShortcut)
        XCTAssertNil(ModuleSpotlight.screenshots.equivalentShortcut)
        XCTAssertNil(ModuleSpotlight.livePhotos.equivalentShortcut)
        XCTAssertNil(ModuleSpotlight.similarPhotos.equivalentShortcut)
        XCTAssertNil(ModuleSpotlight.blurryShots.equivalentShortcut)
    }

    // MARK: - Help catalog

    func test_everyHelpEntryHasNonEmptyContent() {
        for entry in HelpSpotlight.allCases {
            XCTAssertFalse(entry.title.isEmpty)
            XCTAssertFalse(entry.summary.isEmpty)
            XCTAssertFalse(entry.keywords.isEmpty)
        }
    }

    func test_helpIdentifiersAreUnique() {
        let ids = HelpSpotlight.allCases.map(\.identifier)
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    func test_helpAndModuleIdentifiersDontCollide() {
        let moduleIDs = Set(ModuleSpotlight.allCases.map(\.identifier))
        let helpIDs = Set(HelpSpotlight.allCases.map(\.identifier))
        XCTAssertTrue(moduleIDs.isDisjoint(with: helpIDs))
    }

    // MARK: - Domain

    func test_spotlightDomainIsStable() {
        XCTAssertEqual(BideSpotlightIndexer.domain, "com.bidephoto.bide.spotlight")
    }
}
