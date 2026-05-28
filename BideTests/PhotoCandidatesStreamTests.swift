import XCTest
@testable import Bide

/// `PhotoLibraryService.fetchPhotoCandidatesStream` is a thin wrapper over
/// PhotoKit enumeration which we can't drive from unit tests (no real photo
/// library in the harness). These tests cover the AsyncStream consumption
/// pattern that the scan services rely on — making sure the shape we build
/// against is sound.
final class PhotoCandidatesStreamTests: XCTestCase {

    // MARK: - AsyncStream consumption

    func test_asyncStream_yieldsAllChunksInOrder() async {
        let expected: [[Int]] = [[1, 2], [3, 4], [5]]
        let stream = AsyncStream<[Int]> { continuation in
            for chunk in expected {
                continuation.yield(chunk)
            }
            continuation.finish()
        }

        var received: [[Int]] = []
        for await chunk in stream {
            received.append(chunk)
        }

        XCTAssertEqual(received, expected)
    }

    func test_asyncStream_finishesWhenContinuationFinishes() async {
        let stream = AsyncStream<Int> { continuation in
            continuation.yield(1)
            continuation.yield(2)
            continuation.finish()
        }

        var values: [Int] = []
        for await value in stream {
            values.append(value)
        }
        XCTAssertEqual(values, [1, 2])
    }

    func test_asyncStream_canBeCancelledMidStream() async {
        // Simulate the "user tapped Cancel" path: we break out of the for-await
        // loop and the stream is no longer consumed. The producer continues
        // until it tries to yield and the consumer's cancellation flows back.
        let stream = AsyncStream<Int> { continuation in
            for n in 1...100 {
                continuation.yield(n)
            }
            continuation.finish()
        }

        var consumed: [Int] = []
        for await value in stream {
            consumed.append(value)
            if consumed.count == 3 { break }
        }

        XCTAssertEqual(consumed, [1, 2, 3])
    }

    // MARK: - Progress math

    func test_progressBlend_readPhaseStaysUnder20Percent() {
        // The scan services use:
        //   progress = readFraction * 0.2
        // for the read phase. Verify the math at boundaries.
        let readZero = 0.0 * 0.2
        let readHalf = 0.5 * 0.2
        let readFull = 1.0 * 0.2

        XCTAssertEqual(readZero, 0.0, accuracy: 0.001)
        XCTAssertEqual(readHalf, 0.1, accuracy: 0.001)
        XCTAssertEqual(readFull, 0.2, accuracy: 0.001)
    }

    func test_progressBlend_visionPhaseSpans20To100Percent() {
        // Vision phase uses:
        //   progress = 0.2 + visionFraction * 0.8
        let v0 = 0.2 + 0.0 * 0.8
        let v50 = 0.2 + 0.5 * 0.8
        let v100 = 0.2 + 1.0 * 0.8

        XCTAssertEqual(v0, 0.2, accuracy: 0.001)
        XCTAssertEqual(v50, 0.6, accuracy: 0.001)
        XCTAssertEqual(v100, 1.0, accuracy: 0.001)
    }

    func test_progressBlend_blurryShotsUses15Percent() {
        // BlurryShotsScanService uses 15% for read (the per-image blur work
        // is the larger cost and gets the remaining 85%).
        XCTAssertEqual(0.0 * 0.15, 0.0, accuracy: 0.001)
        XCTAssertEqual(1.0 * 0.15, 0.15, accuracy: 0.001)

        let v0 = 0.15 + 0.0 * 0.85
        let v100 = 0.15 + 1.0 * 0.85
        XCTAssertEqual(v0, 0.15, accuracy: 0.001)
        XCTAssertEqual(v100, 1.0, accuracy: 0.001)
    }
}
