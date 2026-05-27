import Foundation
import UIKit
import CoreGraphics

/// Laplacian-variance blur detector. Pure CPU compute on a small grayscale buffer —
/// no actor isolation, no Vision/Core ML dependency. Tests can call this directly
/// with synthetic `UIImage` inputs.
///
/// Algorithm:
///   1. Downscale to 128×128 grayscale (fixed buffer, ~16KB)
///   2. Apply a 3×3 Laplacian kernel (`[[0,-1,0], [-1,4,-1], [0,-1,0]]`)
///   3. Return the variance of the convolution result
///
/// **Interpretation:**
///   - `variance < ~150` → likely blurry (use this as the candidate threshold)
///   - `variance > ~500` → definitely sharp
///   - Numbers in between are ambiguous; we don't surface those by default
///
/// **Conservative defaults:** the threshold is deliberately low. False positives
/// destroy trust more than missed blurry shots. Tune up only after testing
/// against a labeled set of real photos.
enum BlurDetector {

    /// Default threshold below which we consider a photo a "maybe blurry" candidate.
    /// See `analyze(_:)` for the score interpretation.
    static let defaultBlurThreshold: Float = 150.0

    /// Fixed downscale size for the detection buffer. Small enough to be cheap,
    /// large enough to preserve edge structure.
    static let analysisSize = CGSize(width: 128, height: 128)

    /// Returns the Laplacian variance of the image. Higher = sharper, lower = blurrier.
    /// Returns `nil` if the image can't be downscaled or converted to grayscale
    /// (e.g. corrupt asset, iCloud-only and not downloaded).
    static func analyze(_ image: UIImage) -> Float? {
        guard let grayBytes = downscaleToGrayscale(image, size: analysisSize) else {
            return nil
        }
        let width = Int(analysisSize.width)
        let height = Int(analysisSize.height)
        return laplacianVariance(grayBytes, width: width, height: height)
    }

    /// True if `image` is more blurry than `threshold` (lower variance than threshold).
    /// Returns `false` if analysis fails — never auto-flag something we can't measure.
    static func isLikelyBlurry(_ image: UIImage, threshold: Float = defaultBlurThreshold) -> Bool {
        guard let score = analyze(image) else { return false }
        return score < threshold
    }

    // MARK: - Internals

    /// Render `image` into a small grayscale bitmap and return the raw bytes.
    /// One byte per pixel, row-major, no alignment padding (bytesPerRow == width).
    static func downscaleToGrayscale(_ image: UIImage, size: CGSize) -> [UInt8]? {
        let width = Int(size.width)
        let height = Int(size.height)
        guard width > 2, height > 2 else { return nil }

        var bytes = [UInt8](repeating: 0, count: width * height)
        let colorSpace = CGColorSpaceCreateDeviceGray()
        // CGImageAlphaInfo.none with grayscale isn't supported on all systems;
        // .noneSkipLast is rejected for grayscale too. Use the no-alpha grayscale path:
        let bitmapInfo: UInt32 = CGImageAlphaInfo.none.rawValue
        guard let context = CGContext(
            data: &bytes,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else { return nil }

        context.interpolationQuality = .medium
        guard let cgImage = image.cgImage else { return nil }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return bytes
    }

    /// Apply a 3×3 Laplacian kernel and return the variance of the result.
    /// Border pixels are skipped (only the inner `(w-2) × (h-2)` region is sampled).
    static func laplacianVariance(_ bytes: [UInt8], width: Int, height: Int) -> Float? {
        let innerW = width - 2
        let innerH = height - 2
        let count = innerW * innerH
        guard count > 0, bytes.count == width * height else { return nil }

        var sum: Double = 0
        var sumSquares: Double = 0

        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) {
                let idx = y * width + x
                let center = Int(bytes[idx])
                let up = Int(bytes[idx - width])
                let down = Int(bytes[idx + width])
                let left = Int(bytes[idx - 1])
                let right = Int(bytes[idx + 1])
                let laplacian = Double(4 * center - up - down - left - right)
                sum += laplacian
                sumSquares += laplacian * laplacian
            }
        }

        let mean = sum / Double(count)
        let variance = (sumSquares / Double(count)) - (mean * mean)
        return Float(max(variance, 0))
    }
}
