import XCTest
@testable import Bide

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
}
