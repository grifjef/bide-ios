import Foundation
import Photos
import UIKit
import Vision

/// Wraps `VNGenerateImageFeaturePrintRequest` for computing image similarity
/// hashes. We use Vision's built-in feature print rather than a custom Core ML
/// model — it's tuned by Apple, runs locally, and the output (`VNFeaturePrintObservation`)
/// supports `computeDistance(_:to:)` directly.
///
/// All work happens off the main actor. Callers await results and hop back to
/// `@MainActor` themselves if they need to update UI.
struct VisionService: Sendable {

    /// The version of the feature print model we computed against. If Apple
    /// updates the model in a future iOS, we re-cluster from scratch rather
    /// than mixing prints across versions.
    static let currentRevision: Int = VNGenerateImageFeaturePrintRequest.currentRevision

    /// Compute a feature print for a single image. Returns `nil` if Vision
    /// couldn't process the image (e.g. iCloud-only asset that isn't downloaded).
    nonisolated func featurePrint(for image: UIImage) async -> VNFeaturePrintObservation? {
        await withCheckedContinuation { (continuation: CheckedContinuation<VNFeaturePrintObservation?, Never>) in
            guard let cgImage = image.cgImage else {
                continuation.resume(returning: nil)
                return
            }
            let request = VNGenerateImageFeaturePrintRequest()
            request.imageCropAndScaleOption = .scaleFill
            request.revision = Self.currentRevision
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
                let observation = request.results?.first as? VNFeaturePrintObservation
                continuation.resume(returning: observation)
            } catch {
                continuation.resume(returning: nil)
            }
        }
    }

    /// Distance between two feature prints. Lower = more similar.
    /// Vision's `computeDistance` returns a non-negative scalar; in practice
    /// near-duplicates land below ~10, related-but-distinct shots are 10–25,
    /// and unrelated images are 25+. We treat the threshold as conservative
    /// (cluster only when distance < 12) — see `SimilarityClusterer.defaultThreshold`.
    nonisolated func distance(
        from a: VNFeaturePrintObservation,
        to b: VNFeaturePrintObservation
    ) -> Float? {
        var distance: Float = 0
        do {
            try a.computeDistance(&distance, to: b)
            return distance
        } catch {
            return nil
        }
    }

    /// Detect the number of faces in an image. Used by Blurry Shots to
    /// protect portraits (slightly blurry photos of people are still worth
    /// keeping). Returns 0 on detection failure — we never auto-flag an
    /// image we couldn't analyze.
    ///
    /// Uses rectangle detection (no recognition / no identity). We don't ID
    /// who is in the photo, just count detected face bounding boxes.
    nonisolated func faceCount(in image: UIImage) async -> Int {
        await withCheckedContinuation { (continuation: CheckedContinuation<Int, Never>) in
            guard let cgImage = image.cgImage else {
                continuation.resume(returning: 0)
                return
            }
            let request = VNDetectFaceRectanglesRequest()
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
                continuation.resume(returning: request.results?.count ?? 0)
            } catch {
                continuation.resume(returning: 0)
            }
        }
    }
}
