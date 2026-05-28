@testable import Bide
import XCTest

@MainActor
final class ReviewBasketTests: XCTestCase {
    func test_emptyBasket_initialState() {
        let basket = ReviewBasket()
        XCTAssertTrue(basket.isEmpty)
        XCTAssertEqual(basket.count, 0)
        XCTAssertEqual(basket.totalBytes, 0)
    }

    func test_add_appendsItem_andUpdatesTotals() {
        let basket = ReviewBasket()
        basket.add(.init(localIdentifier: "vid1", source: .largeVideos, estimatedBytes: 1_500_000))
        basket.add(.init(localIdentifier: "vid2", source: .largeVideos, estimatedBytes: 500_000))

        XCTAssertEqual(basket.count, 2)
        XCTAssertEqual(basket.totalBytes, 2_000_000)
        XCTAssertFalse(basket.isEmpty)
    }

    func test_add_isIdempotent_byLocalIdentifier() {
        let basket = ReviewBasket()
        basket.add(.init(localIdentifier: "vid1", source: .largeVideos, estimatedBytes: 1_000))
        basket.add(.init(localIdentifier: "vid1", source: .largeVideos, estimatedBytes: 1_000))

        XCTAssertEqual(basket.count, 1)
    }

    func test_remove_dropsItem_andUpdatesTotals() {
        let basket = ReviewBasket()
        basket.add(.init(localIdentifier: "vid1", source: .largeVideos, estimatedBytes: 1_500_000))
        basket.add(.init(localIdentifier: "vid2", source: .largeVideos, estimatedBytes: 500_000))
        basket.remove(localIdentifier: "vid1")

        XCTAssertEqual(basket.count, 1)
        XCTAssertEqual(basket.totalBytes, 500_000)
    }

    func test_toggle_adds_thenRemoves() {
        let basket = ReviewBasket()
        let item = ReviewBasket.Item(localIdentifier: "vid1", source: .largeVideos, estimatedBytes: 1_000)
        basket.toggle(item)
        XCTAssertEqual(basket.count, 1)
        basket.toggle(item)
        XCTAssertEqual(basket.count, 0)
    }

    func test_itemsFromSource_filtersCorrectly() {
        let basket = ReviewBasket()
        basket.add(.init(localIdentifier: "vid1", source: .largeVideos, estimatedBytes: 100))
        basket.add(.init(localIdentifier: "ss1", source: .screenshots, estimatedBytes: 50))

        XCTAssertEqual(basket.items(from: .largeVideos).count, 1)
        XCTAssertEqual(basket.items(from: .screenshots).count, 1)
        XCTAssertEqual(basket.items(from: .similar).count, 0)
    }

    func test_clear_emptiesBasket() {
        let basket = ReviewBasket()
        basket.add(.init(localIdentifier: "vid1", source: .largeVideos, estimatedBytes: 100))
        basket.add(.init(localIdentifier: "vid2", source: .largeVideos, estimatedBytes: 200))
        basket.clear()

        XCTAssertTrue(basket.isEmpty)
        XCTAssertEqual(basket.totalBytes, 0)
    }

    // MARK: - Source enum coverage

    func test_everySourceHasNonEmptyDisplayName() {
        for source in ReviewBasket.Source.allCases {
            XCTAssertFalse(
                source.displayName.isEmpty,
                "Source \(source.rawValue) must have a displayName"
            )
        }
    }

    func test_newerModuleSourcesAreDistinct() {
        // Regression guard: the v0.5 + v0.6 modules used to reuse old source
        // values, which made items appear under the wrong section in the
        // Review Basket. The new cases must be distinct from the legacy four.
        let allCases = ReviewBasket.Source.allCases
        let raws = Set(allCases.map(\.rawValue))
        XCTAssertEqual(raws.count, allCases.count, "Source raw values must be unique")
        XCTAssertTrue(raws.contains("screenRecordings"))
        XCTAssertTrue(raws.contains("livePhotos"))
        XCTAssertTrue(raws.contains("exactDuplicates"))
        XCTAssertTrue(raws.contains("onThisDay"))
    }

    func test_itemsAreGroupedByExactSource() {
        let basket = ReviewBasket()
        basket.add(.init(localIdentifier: "lv", source: .largeVideos, estimatedBytes: 1))
        basket.add(.init(localIdentifier: "sr", source: .screenRecordings, estimatedBytes: 1))
        basket.add(.init(localIdentifier: "lp", source: .livePhotos, estimatedBytes: 1))
        basket.add(.init(localIdentifier: "xd", source: .exactDuplicates, estimatedBytes: 1))
        basket.add(.init(localIdentifier: "od", source: .onThisDay, estimatedBytes: 1))

        XCTAssertEqual(basket.items(from: .largeVideos).map(\.id), ["lv"])
        XCTAssertEqual(basket.items(from: .screenRecordings).map(\.id), ["sr"])
        XCTAssertEqual(basket.items(from: .livePhotos).map(\.id), ["lp"])
        XCTAssertEqual(basket.items(from: .exactDuplicates).map(\.id), ["xd"])
        XCTAssertEqual(basket.items(from: .onThisDay).map(\.id), ["od"])
    }
}
