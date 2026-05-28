@testable import Bide
import UIKit
import XCTest

final class BlurDetectorTests: XCTestCase {
    // MARK: - laplacianVariance (pure math)

    func test_laplacianVariance_uniformImageIsZero() {
        // A uniform gray image has zero Laplacian everywhere → variance == 0
        let bytes = [UInt8](repeating: 128, count: 8 * 8)
        let variance = BlurDetector.laplacianVariance(bytes, width: 8, height: 8)
        XCTAssertNotNil(variance)
        XCTAssertEqual(variance!, 0.0, accuracy: 0.01)
    }

    func test_laplacianVariance_checkerboardIsHigh() {
        // A high-contrast checkerboard has strong Laplacian response everywhere
        var bytes = [UInt8](repeating: 0, count: 8 * 8)
        for y in 0..<8 {
            for x in 0..<8 {
                bytes[y * 8 + x] = ((x + y) % 2 == 0) ? 0 : 255
            }
        }
        let variance = BlurDetector.laplacianVariance(bytes, width: 8, height: 8)
        XCTAssertNotNil(variance)
        XCTAssertGreaterThan(variance!, 100_000) // checkerboard generates huge response
    }

    func test_laplacianVariance_singleEdgeHasModerateVariance() {
        // A vertical edge — half black, half white
        var bytes = [UInt8](repeating: 0, count: 16 * 16)
        for y in 0..<16 {
            for x in 0..<16 {
                bytes[y * 16 + x] = (x < 8) ? 0 : 255
            }
        }
        let variance = BlurDetector.laplacianVariance(bytes, width: 16, height: 16)
        XCTAssertNotNil(variance)
        // One bright vertical line of Laplacian response among many zeros
        XCTAssertGreaterThan(variance!, 1_000)
        XCTAssertLessThan(variance!, 100_000)
    }

    func test_laplacianVariance_returnsNilForTooSmallImage() {
        let bytes = [UInt8](repeating: 0, count: 2 * 2)
        let variance = BlurDetector.laplacianVariance(bytes, width: 2, height: 2)
        XCTAssertNil(variance) // (w-2)*(h-2) == 0
    }

    func test_laplacianVariance_returnsNilForMalformedInput() {
        // Bytes count doesn't match width × height
        let bytes = [UInt8](repeating: 0, count: 5)
        let variance = BlurDetector.laplacianVariance(bytes, width: 8, height: 8)
        XCTAssertNil(variance)
    }

    // MARK: - analyze (full pipeline)

    func test_analyze_uniformColorImageHasZeroVariance() {
        // A solid red image should have variance ~0 (no edges)
        let image = makeSolidColorImage(width: 128, height: 128, color: .red)
        let score = BlurDetector.analyze(image)
        XCTAssertNotNil(score)
        XCTAssertEqual(score!, 0.0, accuracy: 1.0) // allow for tiny float drift from CG resampling
    }

    func test_analyze_highContrastPatternHasHighVariance() {
        // A black-and-white striped pattern should score very high
        let image = makeStripedImage(width: 128, height: 128, stripeWidth: 4)
        let score = BlurDetector.analyze(image)
        XCTAssertNotNil(score)
        XCTAssertGreaterThan(score!, 1_000)
    }

    func test_isLikelyBlurry_uniformImageIsBlurry() {
        let image = makeSolidColorImage(width: 128, height: 128, color: .gray)
        XCTAssertTrue(BlurDetector.isLikelyBlurry(image))
    }

    func test_isLikelyBlurry_stripedImageIsNotBlurry() {
        let image = makeStripedImage(width: 128, height: 128, stripeWidth: 4)
        XCTAssertFalse(BlurDetector.isLikelyBlurry(image))
    }

    func test_isLikelyBlurry_respectsCustomThreshold() {
        let image = makeStripedImage(width: 128, height: 128, stripeWidth: 4)
        // A very high threshold should classify even the sharp striped image as "blurry"
        XCTAssertTrue(BlurDetector.isLikelyBlurry(image, threshold: 1_000_000))
    }

    // MARK: - Helpers

    private func makeSolidColorImage(width: Int, height: Int, color: UIColor) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))
        return renderer.image { ctx in
            color.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
    }

    private func makeStripedImage(width: Int, height: Int, stripeWidth: Int) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))
        return renderer.image { ctx in
            for x in stride(from: 0, to: width, by: stripeWidth * 2) {
                UIColor.black.setFill()
                ctx.fill(CGRect(x: x, y: 0, width: stripeWidth, height: height))
                UIColor.white.setFill()
                ctx.fill(CGRect(x: x + stripeWidth, y: 0, width: stripeWidth, height: height))
            }
        }
    }
}
